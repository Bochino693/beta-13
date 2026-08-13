extends MeshInstance3D
class_name BeastRig3D

# ---------------------------------------------------------------------------
# BeastRig3D
# Transforma UMA ilustracao HD estatica em uma criatura viva dentro do 3D.
# Nao usa spritesheet: a deformacao acontece nos vertices, em tempo real.
#
# Resolve o problema real do beta-13: os "spritesheets de animacao" atuais sao
# a mesma imagem parada com tinta e contorno por cima. Nada se move.
# Aqui a malha e subdividida (32x32) e o shader empurra os vertices:
# respiracao no torso, batida de asa nas extremidades, ondulacao de pelo na
# silhueta, avanco no ataque, tremor no dano e tombamento na derrota.
#
# Uso minimo:
#   var rig := BeastRig3D.new()
#   add_child(rig)
#   rig.configurar(load("res://assets/creatures_hd/abissarca.png"), 2.4, "reptil")
#   rig.atacar()
# ---------------------------------------------------------------------------

const SUBDIVISOES := 32

# Perfis de movimento por familia anatomica. A chave vai no creatures.json,
# campo "familia_anim". Sem perfil, cai em "padrao".
const PERFIS := {
	"ave": {
		"asa": 0.085, "asa_vel": 5.4, "pelo": 0.006,
		"respiro": 0.010, "respiro_vel": 2.6, "balanco": 0.010, "flutua": 0.055
	},
	"dragao": {
		"asa": 0.055, "asa_vel": 2.2, "pelo": 0.009,
		"respiro": 0.018, "respiro_vel": 1.3, "balanco": 0.008, "flutua": 0.030
	},
	"felpudo": {
		"asa": 0.0, "asa_vel": 0.0, "pelo": 0.020,
		"respiro": 0.024, "respiro_vel": 2.1, "balanco": 0.011, "flutua": 0.0
	},
	"reptil": {
		"asa": 0.0, "asa_vel": 0.0, "pelo": 0.005,
		"respiro": 0.020, "respiro_vel": 1.5, "balanco": 0.007, "flutua": 0.0
	},
	"planta": {
		"asa": 0.018, "asa_vel": 1.1, "pelo": 0.016,
		"respiro": 0.012, "respiro_vel": 0.9, "balanco": 0.014, "flutua": 0.0
	},
	"mineral": {
		"asa": 0.0, "asa_vel": 0.0, "pelo": 0.002,
		"respiro": 0.007, "respiro_vel": 0.8, "balanco": 0.004, "flutua": 0.0
	},
	"aquatico": {
		"asa": 0.040, "asa_vel": 1.8, "pelo": 0.014,
		"respiro": 0.016, "respiro_vel": 1.2, "balanco": 0.016, "flutua": 0.045
	},
	"espectro": {
		"asa": 0.030, "asa_vel": 1.4, "pelo": 0.022,
		"respiro": 0.014, "respiro_vel": 1.0, "balanco": 0.020, "flutua": 0.070
	},
	"padrao": {
		"asa": 0.020, "asa_vel": 2.0, "pelo": 0.010,
		"respiro": 0.016, "respiro_vel": 1.6, "balanco": 0.008, "flutua": 0.020
	}
}

const CODIGO_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque, shadows_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform vec2 passo_textura = vec2(0.004, 0.004);
uniform float meia_altura = 1.0;
uniform float tempo_local = 0.0;

uniform float respiro_intensidade = 0.016;
uniform float respiro_velocidade = 1.6;
uniform float asa_intensidade = 0.020;
uniform float asa_velocidade = 2.0;
uniform float pelo_intensidade = 0.010;
uniform float balanco_intensidade = 0.008;
uniform float flutuacao = 0.020;

uniform float avanco = 0.0;
uniform float impacto = 0.0;
uniform float queda = 0.0;
uniform float encolher = 0.0;

uniform float espelhar = 0.0;
uniform float contraluz = 0.0;
uniform float flash = 0.0;
uniform vec3 cor_flash : source_color = vec3(1.0, 1.0, 1.0);
uniform float contorno_forca = 0.0;
uniform vec3 cor_contorno : source_color = vec3(0.35, 0.85, 1.0);
uniform float dissolucao = 0.0;
uniform float brilho = 1.0;

varying float v_altura;

void vertex() {
	float u = UV.x - 0.5;
	float h = 1.0 - UV.y;
	v_altura = h;

	float base = -meia_altura;
	float dy = VERTEX.y - base;

	// Respiracao: o torso infla, a cabeca acompanha de leve, os pes ficam presos.
	float r = sin(tempo_local * respiro_velocidade) * respiro_intensidade;
	float torso = smoothstep(0.05, 0.45, h) * (1.0 - smoothstep(0.58, 0.98, h));
	VERTEX.x += VERTEX.x * r * (0.55 + torso * 1.10);
	VERTEX.y = base + dy * (1.0 + r * (0.75 + torso * 0.70));

	// Batida de asa: so as extremidades laterais, com atraso na ponta.
	float mascara_asa = smoothstep(0.24, 0.50, abs(u)) * smoothstep(0.08, 0.55, h);
	float bat = sin(tempo_local * asa_velocidade - abs(u) * 4.6);
	VERTEX.z += bat * mascara_asa * asa_intensidade * meia_altura * 3.0;
	VERTEX.y += bat * mascara_asa * asa_intensidade * meia_altura * 1.2;

	// Pelo e franjas: ruido rapido apenas na silhueta e no topo.
	float borda = smoothstep(0.28, 0.50, abs(u)) + smoothstep(0.62, 1.00, h) * 0.6;
	float ruido = sin(tempo_local * 3.1 + h * 13.0) * 0.6
		+ sin(tempo_local * 4.7 + u * 21.0) * 0.4;
	VERTEX.x += ruido * borda * pelo_intensidade * meia_altura;
	VERTEX.z += ruido * borda * pelo_intensidade * meia_altura * 0.5;

	// Balanco de peso e flutuacao dos que nao tocam o chao.
	VERTEX.x += sin(tempo_local * 0.9) * balanco_intensidade * meia_altura * h;
	VERTEX.y += sin(tempo_local * 1.27 + 0.6) * flutuacao * meia_altura;

	// Avanco do ataque: inclina para frente pivotando na base.
	VERTEX.z -= avanco * h * meia_altura * 1.6;
	VERTEX.y -= avanco * h * meia_altura * 0.18;

	// Impacto do dano: tremor curto e alto na frequencia.
	VERTEX.x += sin(tempo_local * 58.0) * impacto * meia_altura * 0.07;
	VERTEX.z += cos(tempo_local * 47.0) * impacto * meia_altura * 0.05;

	// Encolhimento de recuo.
	VERTEX.x *= 1.0 - encolher * 0.10;
	VERTEX.y = base + (VERTEX.y - base) * (1.0 - encolher * 0.10);

	// Tombamento da derrota, rotacionando na base.
	if (queda > 0.001) {
		float ang = queda * 1.35;
		float c = cos(ang);
		float s = sin(ang);
		float py = VERTEX.y - base;
		float px = VERTEX.x;
		VERTEX.x = px * c - py * s;
		VERTEX.y = base + px * s + py * c;
	}
}

void fragment() {
	vec2 uv = UV;
	uv.x = mix(uv.x, 1.0 - uv.x, step(0.5, espelhar));

	vec4 tex = texture(textura, uv);
	float a = tex.a;

	// Halo de contorno lido da propria silhueta, sem asset extra.
	float viz = 0.0;
	viz = max(viz, texture(textura, uv + vec2(passo_textura.x, 0.0)).a);
	viz = max(viz, texture(textura, uv - vec2(passo_textura.x, 0.0)).a);
	viz = max(viz, texture(textura, uv + vec2(0.0, passo_textura.y)).a);
	viz = max(viz, texture(textura, uv - vec2(0.0, passo_textura.y)).a);
	viz = max(viz, texture(textura, uv + passo_textura).a);
	viz = max(viz, texture(textura, uv - passo_textura).a);
	float halo = clamp(viz - a, 0.0, 1.0) * contorno_forca;

	vec3 cor = tex.rgb * brilho;

	// Modo de costas: corpo escurece, a borda continua acesa pela luz da arena.
	if (contraluz > 0.001) {
		float rim = smoothstep(0.55, 1.0, 1.0 - a) + halo;
		cor = mix(cor * (1.0 - contraluz * 0.55), cor, clamp(rim, 0.0, 1.0));
		cor += cor_contorno * halo * contraluz * 0.8;
	}

	cor = mix(cor, cor_flash, flash);
	cor = mix(cor, cor_contorno, halo * 0.85);

	float alfa = max(a, halo);

	if (dissolucao > 0.001) {
		float n = fract(sin(dot(uv * 37.0, vec2(12.9898, 78.233))) * 43758.5453);
		float limite = dissolucao * 1.15 - v_altura * 0.15;
		alfa *= step(limite, n);
	}

	ALBEDO = cor;
	ALPHA = alfa;
}
"""

signal animacao_terminou(nome: String)

# Familia de animacao de cada uma das 30 Beasts do beta-13, definida a partir
# da anatomia descrita em data/creatures.json. Editavel aqui, num lugar so.
# Se voce adicionar o campo "familia_anim" no JSON, ele tem prioridade.
const FAMILIA_POR_ID := {
	"lumari": "espectro",     # espirito-lanterna sem pernas
	"helionce": "felpudo",    # juba cristalina
	"prismara": "ave",        # penas prismaticas
	"impavor": "espectro",    # demonio que some entre pisadas
	"nocturna": "espectro",   # desliza no ar, nao bate asa
	"abissarca": "dragao",    # leviata alado
	"brasalam": "reptil",     # salamandra bipede
	"vulcora": "mineral",     # casco com crateras
	"cinzibora": "espectro",  # serpente que vira fumaca
	"pyrocondor": "ave",      # ave de rapina
	"voltalho": "felpudo",    # corredor de pernas elasticas
	"raiarraia": "aquatico",  # arraia flutuante
	"teslouro": "mineral",    # lutador revestido de bobinas
	"arcdrake": "dragao",     # dragao com turbinas
	"pedrilho": "felpudo",    # tatu-toupeira
	"geodrilo": "reptil",     # crocodiliano de cristais
	"monolito": "mineral",    # lajes orbitando um nucleo
	"fossatroz": "reptil",    # fossil teropode
	"medulux": "aquatico",    # agua-viva
	"crustarka": "aquatico",  # crustaceo de pincas
	"torpescama": "aquatico", # peixe-espada
	"marevante": "dragao",    # dragao-marinho
	"floraphex": "ave",       # inseto-orquidea, asas rapidas
	"brotoxi": "planta",      # anfibio e planta carnivora
	"musgurso": "felpudo",    # urso coberto de musgo
	"arborion": "planta",     # arvore humanoide
	"brispulo": "felpudo",    # bipede de orelhas-vela
	"nimbaleia": "aquatico",  # baleia-nuvem
	"ciclorn": "ave",         # ave corredora
	"tempestral": "dragao"    # serpente celeste de quatro asas
}


## Descobre a familia de animacao a partir do dicionario da criatura.
## Ordem: campo explicito no JSON -> tabela por id -> deducao pela anatomia.
static func familia_de(dados: Dictionary) -> String:
	var explicito := str(dados.get("familia_anim", ""))
	if not explicito.is_empty() and PERFIS.has(explicito):
		return explicito

	var id_beast := str(dados.get("id", ""))
	if FAMILIA_POR_ID.has(id_beast):
		return str(FAMILIA_POR_ID[id_beast])

	# Deducao para Beasts novas que ainda nao estao na tabela.
	if bool(dados.get("wings", false)):
		return "ave"
	var tipo := str(dados.get("type", ""))
	if tipo == "Água":
		return "aquatico"
	if tipo == "Natureza":
		return "planta"
	if tipo == "Terra":
		return "mineral"
	if tipo == "Escuridão":
		return "espectro"
	return "padrao"

var _material: ShaderMaterial
var _tempo := 0.0
var _perfil: Dictionary = PERFIS["padrao"]
var _tween_ativo: Tween
var _de_costas := false
var _cor_elemento := Color(0.35, 0.85, 1.0)


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _material == null:
		return
	_tempo += delta
	_material.set_shader_parameter("tempo_local", _tempo)


# ---------------------------------------------------------------------------
# Configuracao
# ---------------------------------------------------------------------------

## textura: PNG HD da Beast (assets/creatures_hd/<id>.png)
## altura_mundo: altura em metros no espaco 3D (2.0 a 3.2 e a faixa util)
## familia: chave de PERFIS, vinda de creatures.json -> "familia_anim"
## de_costas: true para a Beast do jogador, vista por tras na arena
func configurar(
	textura: Texture2D,
	altura_mundo: float = 2.4,
	familia: String = "padrao",
	de_costas: bool = false,
	cor_elemento: Color = Color(0.35, 0.85, 1.0)
) -> void:
	if textura == null:
		push_error("BeastRig3D: textura nula.")
		return

	_de_costas = de_costas
	_cor_elemento = cor_elemento
	_perfil = PERFIS.get(familia, PERFIS["padrao"])

	var tam := textura.get_size()
	var proporcao: float = 1.0 if tam.y <= 0.0 else tam.x / tam.y

	var plano := PlaneMesh.new()
	plano.orientation = PlaneMesh.FACE_Z
	plano.size = Vector2(altura_mundo * proporcao, altura_mundo)
	plano.subdivide_width = SUBDIVISOES
	plano.subdivide_depth = SUBDIVISOES
	mesh = plano

	var shader := Shader.new()
	shader.code = CODIGO_SHADER

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("textura", textura)
	_material.set_shader_parameter("meia_altura", altura_mundo * 0.5)
	_material.set_shader_parameter("passo_textura", Vector2(1.4 / tam.x, 1.4 / tam.y))
	_material.set_shader_parameter("cor_contorno", cor_elemento)
	_material.set_shader_parameter("espelhar", 1.0 if de_costas else 0.0)
	_material.set_shader_parameter("contraluz", 0.85 if de_costas else 0.0)
	_material.set_shader_parameter("brilho", 0.92 if de_costas else 1.0)
	_aplicar_perfil()

	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Desfase para duas Beasts nunca respirarem em sincronia.
	_tempo = randf() * 8.0


func _aplicar_perfil() -> void:
	_material.set_shader_parameter("respiro_intensidade", _perfil["respiro"])
	_material.set_shader_parameter("respiro_velocidade", _perfil["respiro_vel"])
	_material.set_shader_parameter("asa_intensidade", _perfil["asa"])
	_material.set_shader_parameter("asa_velocidade", _perfil["asa_vel"])
	_material.set_shader_parameter("pelo_intensidade", _perfil["pelo"])
	_material.set_shader_parameter("balanco_intensidade", _perfil["balanco"])
	_material.set_shader_parameter("flutuacao", _perfil["flutua"])


func definir_cor_elemento(cor: Color) -> void:
	_cor_elemento = cor
	if _material != null:
		_material.set_shader_parameter("cor_contorno", cor)


## Ajusta o escurecimento de contraluz da vista de costas.
## 0.85 = silhueta (sem arte de costas). 0.25 = arte de costas real.
func definir_contraluz(valor: float) -> void:
	if _material != null:
		_material.set_shader_parameter("contraluz", clampf(valor, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Estados de animacao
# ---------------------------------------------------------------------------

func _novo_tween() -> Tween:
	if _tween_ativo != null and _tween_ativo.is_valid():
		_tween_ativo.kill()
	_tween_ativo = create_tween()
	_tween_ativo.set_ease(Tween.EASE_OUT)
	return _tween_ativo


func _p(nome: String, valor: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(nome, valor)


## Retorna ao repouso, cancelando qualquer estado ativo.
func repousar() -> void:
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_method(func(v: float) -> void: _p("avanco", v), _valor("avanco"), 0.0, 0.20)
	t.tween_method(func(v: float) -> void: _p("impacto", v), _valor("impacto"), 0.0, 0.15)
	t.tween_method(func(v: float) -> void: _p("queda", v), _valor("queda"), 0.0, 0.25)
	t.tween_method(func(v: float) -> void: _p("encolher", v), _valor("encolher"), 0.0, 0.20)
	t.tween_method(func(v: float) -> void: _p("flash", v), _valor("flash"), 0.0, 0.15)
	t.tween_method(func(v: float) -> void: _p("dissolucao", v), _valor("dissolucao"), 0.0, 0.25)
	t.tween_method(func(v: float) -> void: _p("contorno_forca", v), _valor("contorno_forca"), 0.0, 0.20)


func _valor(nome: String) -> float:
	if _material == null:
		return 0.0
	var v: Variant = _material.get_shader_parameter(nome)
	return 0.0 if v == null else float(v)


## Recuo, avanco e retorno. Emite "animacao_terminou" no ponto de impacto,
## que e onde a cena deve disparar o sprite do golpe.
func atacar(duracao: float = 0.62) -> void:
	var t := _novo_tween()
	t.tween_method(func(v: float) -> void: _p("encolher", v), 0.0, 0.55, duracao * 0.28)
	t.parallel().tween_method(func(v: float) -> void: _p("contorno_forca", v), 0.0, 0.9, duracao * 0.28)
	t.tween_method(func(v: float) -> void: _p("encolher", v), 0.55, 0.0, duracao * 0.12)
	t.parallel().tween_method(func(v: float) -> void: _p("avanco", v), 0.0, 0.42, duracao * 0.12)
	t.tween_callback(func() -> void: animacao_terminou.emit("impacto"))
	t.tween_interval(duracao * 0.14)
	t.tween_method(func(v: float) -> void: _p("avanco", v), 0.42, 0.0, duracao * 0.46)
	t.parallel().tween_method(func(v: float) -> void: _p("contorno_forca", v), 0.9, 0.0, duracao * 0.46)
	t.tween_callback(func() -> void: animacao_terminou.emit("atacar"))


## Carrega energia para o golpe pesado. Chame antes de atacar().
func carregar(duracao: float = 0.9) -> void:
	var t := _novo_tween()
	t.tween_method(func(v: float) -> void: _p("contorno_forca", v), 0.0, 1.4, duracao * 0.7)
	t.parallel().tween_method(func(v: float) -> void: _p("encolher", v), 0.0, 0.30, duracao * 0.7)
	t.tween_interval(duracao * 0.3)
	t.tween_callback(func() -> void: animacao_terminou.emit("carregar"))


func levar_dano(cor: Color = Color(1.0, 0.35, 0.35), duracao: float = 0.42) -> void:
	_p("cor_flash", Vector3(cor.r, cor.g, cor.b))
	var t := _novo_tween()
	t.tween_method(func(v: float) -> void: _p("flash", v), 0.0, 0.85, duracao * 0.12)
	t.parallel().tween_method(func(v: float) -> void: _p("impacto", v), 0.0, 1.0, duracao * 0.12)
	t.tween_method(func(v: float) -> void: _p("flash", v), 0.85, 0.0, duracao * 0.35)
	t.parallel().tween_method(func(v: float) -> void: _p("impacto", v), 1.0, 0.0, duracao * 0.60)
	t.tween_callback(func() -> void: animacao_terminou.emit("dano"))


func comemorar(duracao: float = 1.1) -> void:
	var t := _novo_tween()
	t.set_loops(2)
	t.tween_method(func(v: float) -> void: _p("avanco", v), 0.0, -0.20, duracao * 0.25)
	t.tween_method(func(v: float) -> void: _p("avanco", v), -0.20, 0.10, duracao * 0.25)
	t.tween_method(func(v: float) -> void: _p("avanco", v), 0.10, 0.0, duracao * 0.20)


func tombar(duracao: float = 1.0) -> void:
	var t := _novo_tween()
	t.tween_method(func(v: float) -> void: _p("queda", v), 0.0, 1.0, duracao * 0.55)
	t.parallel().tween_method(func(v: float) -> void: _p("flash", v), 0.0, 0.0, 0.01)
	t.tween_method(func(v: float) -> void: _p("dissolucao", v), 0.0, 1.0, duracao * 0.45)
	t.tween_callback(func() -> void: animacao_terminou.emit("tombar"))


## Entrada da Beast na arena, com o corpo surgindo pela dissolucao.
func entrar(duracao: float = 0.7) -> void:
	_p("dissolucao", 1.0)
	_p("contorno_forca", 1.6)
	var t := _novo_tween()
	t.tween_method(func(v: float) -> void: _p("dissolucao", v), 1.0, 0.0, duracao)
	t.parallel().tween_method(func(v: float) -> void: _p("contorno_forca", v), 1.6, 0.0, duracao * 1.2)
	t.tween_callback(func() -> void: animacao_terminou.emit("entrar"))
