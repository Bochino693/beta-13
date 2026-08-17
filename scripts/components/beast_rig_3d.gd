class_name BeastRig3D
extends Node3D

## Rig 3D da Beast em combate.
##
## Substitui o rig antigo, que pegava UM retrato estatico
## (`assets/creatures_hd/<id>.png`), deformava a malha por seno e ligava
## `billboard`. Aquilo tinha tres defeitos que impediam a leitura 3D:
##
##  1. `billboard` gira o quadrilatero para encarar a camera todo quadro e
##     `billboard_keep_scale` cancela a reducao por distancia. O resultado e
##     um recorte colado na tela: a Beast do fundo tinha o mesmo tamanho
##     aparente da da frente e nada parecia estar DENTRO da arena.
##  2. `no_depth_test` + `depth_draw_disabled` tiravam a Beast do buffer de
##     profundidade, entao poder nenhum passava atras dela e a sombra nao
##     tinha em que se apoiar.
##  3. A "vista de costas" era o UV espelhado (`1.0 - u`) do MESMO desenho de
##     frente. A Beast do jogador continuava encarando o jogador, so que
##     invertida.
##
## Aqui a vista vem DESENHADA no atlas de combate: `back_*` para a Beast do
## jogador (que fica de costas, em primeiro plano) e `front_*` para a rival
## (que encara o jogador, ao fundo). O movimento e quadro a quadro pelo
## `BeastPoseAtlas`, e a coreografia de avanco/salto/recuo continua sendo
## tween no espaco 3D — as duas coisas somadas dao a interpretacao de
## movimento real.

signal animacao_terminou(nome: String)

const POSE_ATLAS := preload("res://scripts/components/beast_pose_atlas.gd")

## Passada de quadros fixa, independente da taxa de renderizacao.
## O avanco de pose acontece num relogio proprio: a 60 ou a 144 fps a Beast
## respira na mesma velocidade. Antes a malha era reconstruida a 30 Hz com
## 625 vertices por Beast, o que fazia a batalha oscilar sozinha.
const PASSO_MINIMO := 1.0 / 60.0

## Corte de alfa. Mantem a Beast no buffer de profundidade (poder passa
## atras, sombra se apoia) sem serrilhar a borda: a arte tem margem
## transparente de 22 px e antisserrilhado proprio.
const CORTE_ALFA := 0.12

## Quanto o quadrilatero se inclina para tras para acompanhar o mergulho da
## camera. 0 = placa em pe (fica achatada vista de cima); 1 = encara a
## camera (volta a ser adesivo). O meio-termo mantem a Beast legivel e ainda
## presa ao chao.
const COMPENSACAO_DE_PITCH := 0.62

## Giro de leitura: cada Beast vira um pouco para dentro, na direcao da
## adversaria, em vez das duas ficarem paralelas ao plano da tela.
const GIRO_DE_LEITURA_GRAUS := 7.0

const MOVIMENTO: Dictionary = {
	"ave": {"ritmo": 3.7, "flutua": 0.060, "balanco": 0.020},
	"dragao": {"ritmo": 2.3, "flutua": 0.025, "balanco": 0.022},
	"felpudo": {"ritmo": 1.8, "flutua": 0.004, "balanco": 0.016},
	"reptil": {"ritmo": 1.5, "flutua": 0.002, "balanco": 0.012},
	"planta": {"ritmo": 1.2, "flutua": 0.006, "balanco": 0.030},
	"mineral": {"ritmo": 0.9, "flutua": 0.001, "balanco": 0.006},
	"aquatico": {"ritmo": 2.1, "flutua": 0.070, "balanco": 0.042},
	"espectro": {"ritmo": 2.8, "flutua": 0.088, "balanco": 0.044},
	"padrao": {"ritmo": 1.8, "flutua": 0.010, "balanco": 0.018},
}

const FAMILIA_POR_ID: Dictionary = {
	"lumari": "espectro", "helionce": "felpudo", "prismara": "ave",
	"impavor": "espectro", "nocturna": "espectro", "abissarca": "dragao",
	"brasalam": "reptil", "vulcora": "mineral", "cinzibora": "espectro",
	"pyrocondor": "ave", "voltalho": "felpudo", "raiarraia": "aquatico",
	"teslouro": "mineral", "arcdrake": "dragao", "pedrilho": "felpudo",
	"geodrilo": "reptil", "monolito": "mineral", "fossatroz": "reptil",
	"medulux": "aquatico", "crustarka": "aquatico", "torpescama": "aquatico",
	"marevante": "dragao", "floraphex": "ave", "brotoxi": "planta",
	"musgurso": "felpudo", "arborion": "planta", "brispulo": "felpudo",
	"nimbaleia": "aquatico", "ciclorn": "ave", "tempestral": "dragao",
}

const LOCOMOCAO_POR_ID: Dictionary = {
	"lumari": "voador", "prismara": "voador", "nocturna": "voador",
	"abissarca": "voador", "pyrocondor": "voador", "arcdrake": "voador",
	"monolito": "voador", "brispulo": "voador", "nimbaleia": "voador",
	"tempestral": "voador", "raiarraia": "aquatico", "medulux": "aquatico",
	"torpescama": "aquatico", "marevante": "aquatico",
}

var _id_beast := ""
var _familia := "padrao"
var _locomocao := "terrestre"
var _de_costas := false
var _vista := POSE_ATLAS.VISTA_FRENTE
var _altura := 2.5
var _cor_elemento := Color("6ef8ff")
var _golpe_preparado: Dictionary = {}

var _atlas: BeastPoseAtlas
var _corpo: Node3D
var _sprite: MeshInstance3D
var _material_sprite: StandardMaterial3D
var _sombra: MeshInstance3D
var _material_sombra: StandardMaterial3D
var _aura: OmniLight3D
var _anel: MeshInstance3D
var _material_anel: StandardMaterial3D

## Estado da sequencia de quadros em curso.
var _estado := "idle"
var _quadros := PackedStringArray()
var _quadro := 0
var _fps := 8.0
var _em_loop := true
var _preso := false
var _relogio_quadro := 0.0

var _tempo := 0.0
var _tween: Tween
var _ocupado := false
var _pesado_pendente := false
var _brilho := 0.0
var _realce := 1.0
var _pitch_camera := 0.0


func _ready() -> void:
	_tempo = randf() * 8.0
	set_process(true)


static func familia_de(data: Dictionary) -> String:
	var explicito := str(data.get("familia_anim", ""))
	if MOVIMENTO.has(explicito):
		return explicito
	return str(FAMILIA_POR_ID.get(str(data.get("id", "")), "padrao"))


static func locomocao_de(data: Dictionary) -> String:
	return str(LOCOMOCAO_POR_ID.get(str(data.get("id", "")), "terrestre"))


## Monta o rig. Devolve false quando falta o atlas de combate: a batalha
## trata isso como erro de conteudo e nao desenha substituto.
func configurar(
	id_beast: String,
	altura_no_mundo: float,
	familia: String,
	locomocao: String,
	de_costas: bool,
	cor_elemento: Color
) -> bool:
	_atlas = POSE_ATLAS.abrir(id_beast)
	if _atlas == null or not _atlas.valido():
		return false

	_id_beast = id_beast
	_altura = altura_no_mundo
	_familia = familia if MOVIMENTO.has(familia) else "padrao"
	_locomocao = (
		locomocao if locomocao in ["voador", "terrestre", "aquatico"] else "terrestre"
	)
	_de_costas = de_costas
	## A vista NAO e espelhamento: sao linhas diferentes do atlas.
	_vista = POSE_ATLAS.VISTA_COSTAS if de_costas else POSE_ATLAS.VISTA_FRENTE
	_cor_elemento = cor_elemento

	if _atlas.total_de_quadros(_vista, "idle") <= 0:
		push_error(
			"BeastRig3D: atlas de %s nao tem poses de idle na vista %s"
			% [id_beast, _vista]
		)
		return false

	_corpo = Node3D.new()
	add_child(_corpo)

	_sprite = _criar_sprite()
	_corpo.add_child(_sprite)

	_criar_sombra()
	_criar_presenca()
	_aplicar_estado("idle", true)
	return true


## Escala em metros por pixel para que a pose de referencia meca exatamente
## `_altura` no mundo. Sempre calculada pelo idle, nunca pela pose corrente:
## senao a Beast encolheria ao cair e cresceria ao comemorar.
func _pixel_size() -> float:
	var altura_px := _atlas.altura_de_referencia(_vista)
	return _altura / maxf(1.0, altura_px)


## Material da Beast.
##
## E um StandardMaterial3D EXPLICITO, nao o material implicito do Sprite3D.
##
## O Sprite3D monta o proprio material a partir dos seus sinalizadores e, no
## renderizador GL Compatibility, o que saiu dali foi uma Beast SOMBREADA:
## como a arena so tem luz ambiente azul e dois holofotes laterais, a
## criatura aparecia como uma silhueta azul-escura com o contorno dourado
## aparecendo — a arte inteira apagada. Declarando o material aqui, o modo
## nao-sombreado e uma garantia, nao um efeito colateral de sinalizador.
##
## Declarar o material tambem da o que o combate precisa: `albedo_color` e o
## tingimento de carga e de dano (antes era `modulate`, que o Sprite3D
## resolve por cor de vertice) e o recorte do quadro vira deslocamento de UV.
func _criar_material(sombra: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	## Recorte por alfa: mantem a Beast no buffer de profundidade, entao o
	## poder passa na frente ou atras dela e a sombra tem em que se apoiar.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = CORTE_ALFA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = _atlas.textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	## Nada de billboard: e o que devolve a perspectiva. A Beast do jogador
	## esta perto da camera e ocupa mais tela; a rival esta longe e recua
	## para o fundo, como qualquer outro objeto 3D.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	if sombra:
		material.albedo_color = Color(0.004, 0.008, 0.020, 0.42)
		material.render_priority = 0
	else:
		material.albedo_color = Color.WHITE
		material.render_priority = 2 if _de_costas else 1
	return material


func _criar_sprite() -> MeshInstance3D:
	_material_sprite = _criar_material(false)
	var visual := MeshInstance3D.new()
	visual.mesh = QuadMesh.new()
	visual.material_override = _material_sprite
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


## Sombra projetada: o MESMO quadro da Beast, deitado no piso e escurecido.
## Acompanha a pose, entao quando a criatura salta a sombra encolhe e se
## afasta — e isso que prende o corpo ao chao.
func _criar_sombra() -> void:
	_material_sombra = _criar_material(true)
	_sombra = MeshInstance3D.new()
	_sombra.mesh = QuadMesh.new()
	_sombra.material_override = _material_sombra
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Deitada no piso e comprimida em profundidade.
	_sombra.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_sombra.scale = Vector3(0.94, 0.52, 1.0)
	add_child(_sombra)


func _criar_presenca() -> void:
	_material_anel = StandardMaterial3D.new()
	_material_anel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_anel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_anel.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material_anel.albedo_color = Color(
		_cor_elemento.r, _cor_elemento.g, _cor_elemento.b, 0.24
	)
	_material_anel.emission_enabled = true
	_material_anel.emission = _cor_elemento

	var torus := TorusMesh.new()
	torus.inner_radius = _altura * 0.30
	torus.outer_radius = _altura * 0.34
	torus.rings = 28
	torus.ring_segments = 6

	_anel = MeshInstance3D.new()
	_anel.mesh = torus
	_anel.material_override = _material_anel
	_anel.position.y = 0.022
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anel)

	_aura = OmniLight3D.new()
	_aura.light_color = _cor_elemento
	_aura.light_energy = 0.40
	_aura.omni_range = _altura * 1.8
	_aura.position.y = _altura * 0.52
	_aura.shadow_enabled = false
	add_child(_aura)


## Alinha o quadrilatero a camera da arena UMA vez, no inicio da luta.
##
## Nao e billboard: nao roda por quadro e nao cancela a perspectiva. So
## inclina a placa para tras na medida do mergulho da camera, para a Beast
## nao aparecer achatada vista de cima, e vira cada uma um pouco para dentro
## na direcao da adversaria.
func alinhar_camera(camera: Camera3D) -> void:
	if camera == null or _corpo == null:
		return
	_pitch_camera = camera.global_rotation.x
	var giro := deg_to_rad(GIRO_DE_LEITURA_GRAUS) * (1.0 if _de_costas else -1.0)
	rotation.y = giro
	_corpo.rotation.x = -_pitch_camera * COMPENSACAO_DE_PITCH
	if _sombra != null:
		## A sombra segue o giro do corpo, mas continua deitada no piso.
		_sombra.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


# ===========================================================================
# QUADROS
# ===========================================================================

## Troca a sequencia em execucao.
##
## `preso` mantem o ultimo quadro parado no fim (carga, guarda, KO); sem ele
## a sequencia volta para idle e avisa quem esta esperando.
func _aplicar_estado(estado: String, em_loop: bool, fps: float = 0.0, preso: bool = false) -> void:
	var quadros := _atlas.sequencia(_vista, estado)
	if quadros.is_empty():
		return
	_estado = estado
	_quadros = quadros
	_quadro = 0
	_em_loop = em_loop
	_preso = preso
	_fps = fps if fps > 0.0 else _fps_do_estado(estado, quadros.size())
	_relogio_quadro = 0.0
	_desenhar_quadro()


## Ritmo de cada estado. O idle sai da familia (mineral respira devagar, ave
## bate asa rapido); os estados de acao tem ritmo proprio porque precisam
## bater junto com a coreografia do tween.
func _fps_do_estado(estado: String, total: int) -> float:
	if total <= 1:
		return 1.0
	match estado:
		"idle":
			var ritmo := float((MOVIMENTO[_familia] as Dictionary)["ritmo"])
			return clampf(ritmo * 2.6, 5.0, 15.0)
		"light_charge", "heavy_charge":
			return 11.0
		"light_impact", "heavy_release", "heavy_impact":
			return 16.0
		"damage":
			return 14.0
		"dodge_left", "dodge_right":
			return 16.0
		"victory":
			return 7.0
		"ko":
			return 5.0
		_:
			return 10.0


## Troca o quadro visivel.
##
## Trocar de pose e so mover a janela de UV sobre o atlas e redimensionar o
## quadrilatero. Nada e recarregado, recortado ou realocado por quadro — o
## atlas ja esta na GPU inteiro desde a montagem do rig.
func _desenhar_quadro() -> void:
	if _quadros.is_empty() or _sprite == null or _atlas.textura == null:
		return
	var nome := _quadros[clampi(_quadro, 0, _quadros.size() - 1)]
	var regiao := _atlas.regiao(nome)
	var ancora := _atlas.ancora(nome)
	var escala := _pixel_size()

	var largura_atlas := float(_atlas.textura.get_width())
	var altura_atlas := float(_atlas.textura.get_height())
	var janela := Vector3(
		regiao.size.x / largura_atlas, regiao.size.y / altura_atlas, 1.0
	)
	var canto := Vector3(
		regiao.position.x / largura_atlas, regiao.position.y / altura_atlas, 0.0
	)

	var largura := regiao.size.x * escala
	var altura := regiao.size.y * escala

	_material_sprite.uv1_scale = janela
	_material_sprite.uv1_offset = canto
	(_sprite.mesh as QuadMesh).size = Vector2(largura, altura)

	## O QuadMesh nasce centrado na origem. Deslocamos para que a ANCORA da
	## pose (por contrato, (0.5, 1.0) = o pe da criatura) caia exatamente na
	## origem do rig. Assim uma pose mais alta cresce para cima em vez de
	## afundar no chao, e o KO deitado continua apoiado.
	_sprite.position = Vector3(
		-(ancora.x - 0.5) * largura, (ancora.y - 0.5) * altura, 0.0
	)

	if _sombra != null:
		_material_sombra.uv1_scale = janela
		_material_sombra.uv1_offset = canto
		(_sombra.mesh as QuadMesh).size = Vector2(largura, altura)
		## Deitada no piso: o quadrilatero foi girado -90° em X, entao o que
		## era altura vira profundidade. A sombra nasce no pe e se estende
		## para tras.
		_sombra.position = Vector3(
			-(ancora.x - 0.5) * largura, 0.012, (ancora.y - 0.5) * altura
		)


func _avancar_quadro() -> void:
	if _quadros.size() <= 1:
		return
	if _quadro + 1 < _quadros.size():
		_quadro += 1
		_desenhar_quadro()
		return
	if _em_loop:
		_quadro = 0
		_desenhar_quadro()
	elif not _preso:
		_voltar_ao_idle()


func _voltar_ao_idle() -> void:
	_aplicar_estado("idle", true)


func _process(delta: float) -> void:
	_tempo += delta

	## Passada de quadros em relogio fixo. O acumulador so gasta o tempo que
	## couber em passos inteiros, entao a animacao nao acelera quando a taxa
	## de renderizacao sobe nem trava quando ela cai.
	if _quadros.size() > 1 and _fps > 0.0:
		var intervalo := 1.0 / _fps
		_relogio_quadro += minf(delta, 0.25)
		var passos := 0
		while _relogio_quadro >= intervalo and passos < 4:
			_relogio_quadro -= intervalo
			_avancar_quadro()
			passos += 1

	if _corpo != null and not _ocupado:
		var motion: Dictionary = MOVIMENTO[_familia]
		var ritmo := float(motion["ritmo"])
		if _locomocao == "terrestre":
			_corpo.position.y = absf(sin(_tempo * ritmo)) * 0.012
		else:
			_corpo.position.y = sin(_tempo * ritmo * 0.72) * maxf(0.035, float(motion["flutua"]))
		_corpo.rotation.z = sin(_tempo * ritmo * 0.41) * float(motion["balanco"]) * 0.42

	_atualizar_presenca(delta)


func _atualizar_presenca(delta: float) -> void:
	_realce = move_toward(_realce, 1.0, delta * 4.0)
	if _anel != null:
		_anel.rotation.y = _tempo * 0.34
	var pulso := 0.5 + sin(_tempo * 2.1) * 0.5
	if _material_anel != null:
		_material_anel.emission_energy_multiplier = (0.7 + pulso * 1.10) * _realce
	if _aura != null:
		_aura.light_energy = (0.26 + pulso * 0.22) * _realce
	if _sombra != null:
		## A sombra some conforme a Beast sobe: quem flutua nao pinta o chao
		## igual a quem esta apoiado nele.
		var altura_atual := (_corpo.position.y if _corpo != null else 0.0) + position.y
		var opacidade := clampf(0.42 - altura_atual * 0.26, 0.06, 0.42)
		_material_sombra.albedo_color.a = opacidade
		var espalha := clampf(1.0 + altura_atual * 0.30, 1.0, 1.55)
		_sombra.scale = Vector3(0.94 * espalha, 0.52 * espalha, 1.0)


# ===========================================================================
# API DE COMBATE
# ===========================================================================

func preparar_golpe(golpe: Dictionary) -> void:
	_golpe_preparado = golpe.duplicate(true)


func definir_cor_elemento(cor: Color) -> void:
	_cor_elemento = cor
	if _aura != null:
		_aura.light_color = cor
	if _material_anel != null:
		_material_anel.emission = cor
		_material_anel.albedo_color = Color(cor.r, cor.g, cor.b, 0.24)


## De onde o poder sai. Na vista de costas o poder parte para o fundo da
## arena; na de frente, para a camera.
func ponto_emissao() -> Vector3:
	var frente := -0.20 if _de_costas else 0.20
	return global_position + Vector3(0.0, _altura * 0.62, frente)


func ponto_impacto() -> Vector3:
	return global_position + Vector3(0.0, _altura * 0.54, 0.0)


func _novo_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _tween


func entrar(duracao: float = 0.70) -> void:
	if _corpo == null:
		return
	_ocupado = true
	_realce = 3.4
	_corpo.scale = Vector3(0.84, 0.84, 1.0)
	_corpo.position.y = -0.10
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(_corpo, "scale", Vector3.ONE, duracao).set_trans(Tween.TRANS_BACK)
	t.tween_property(_corpo, "position:y", 0.0, duracao * 0.76)
	t.chain().tween_callback(_encerrar_estado.bind("entrar"))


func carregar(duracao: float = 0.85) -> void:
	_ocupado = true
	_pesado_pendente = true
	_realce = 4.8
	## O quadro de carga fica PRESO ate a soltura: e a antecipacao do golpe
	## pesado, o jogador precisa ver a Beast se armando.
	_aplicar_estado("heavy_charge", false, 0.0, true)
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_method(_definir_brilho, 0.0, 0.85, duracao * 0.58)
	t.tween_property(_corpo, "scale", Vector3(1.07, 0.90, 1.0), duracao * 0.58)
	t.chain().set_parallel(true)
	t.tween_property(_corpo, "scale", Vector3.ONE, duracao * 0.30).set_trans(Tween.TRANS_BACK)
	t.chain().tween_callback(_encerrar_estado.bind("carregar", false))


func atacar(duracao: float = 0.62) -> void:
	_ocupado = true
	_aplicar_estado(
		"heavy_release" if _pesado_pendente else "light_charge", false, 0.0, true
	)
	if _pesado_pendente and _id_beast == "pedrilho":
		_ataque_por_baixo(duracao)
	elif _locomocao == "voador":
		_ataque_aereo(duracao)
	elif _locomocao == "aquatico":
		_ataque_aquatico(duracao)
	elif str(_golpe_preparado.get("travel_style", "")) in ["beam", "cone", "arc", "overhead"]:
		_ataque_conjurado(duracao)
	else:
		_ataque_avanco(duracao)


## Sinal do "para frente" da Beast em profundidade. A do jogador esta de
## costas em primeiro plano: avancar e ir para o fundo (-Z). A rival esta ao
## fundo encarando a camera: avancar e vir para a frente (+Z).
func _sentido() -> float:
	return -1.0 if _de_costas else 1.0


func _ataque_avanco(duracao: float) -> void:
	var inicio := position
	var sentido := _sentido()
	var distancia := 1.24 if _pesado_pendente else 0.82
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:z", inicio.z - sentido * 0.14, duracao * 0.22)
	t.tween_property(_corpo, "scale", Vector3(1.05, 0.93, 1.0), duracao * 0.22)
	t.chain().set_parallel(true)
	t.tween_property(self, "position:z", inicio.z + sentido * distancia, duracao * 0.25).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_corpo, "scale", Vector3(0.96, 1.07, 1.0), duracao * 0.25)
	t.chain().tween_callback(_emitir_impacto)
	t.set_parallel(true)
	t.tween_property(self, "position", inicio, duracao * 0.38)
	t.tween_property(_corpo, "scale", Vector3.ONE, duracao * 0.38)
	t.chain().tween_callback(_encerrar_estado.bind("atacar"))


func _ataque_conjurado(duracao: float) -> void:
	var inclinacao := -0.11 * _sentido()
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(_corpo, "position:y", 0.10, duracao * 0.40).set_trans(Tween.TRANS_BACK)
	t.tween_property(_corpo, "rotation:z", inclinacao, duracao * 0.40)
	t.tween_method(_definir_brilho, 0.2, 0.85, duracao * 0.40)
	t.chain().tween_callback(_emitir_impacto)
	t.set_parallel(true)
	t.tween_property(_corpo, "position", Vector3.ZERO, duracao * 0.42)
	t.tween_property(_corpo, "rotation:z", 0.0, duracao * 0.42)
	t.tween_method(_definir_brilho, 0.85, 0.0, duracao * 0.42)
	t.chain().tween_callback(_encerrar_estado.bind("atacar"))


func _ataque_aereo(duracao: float) -> void:
	var inicio := position
	var sentido := _sentido()
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", inicio.y + 0.62, duracao * 0.30)
	t.tween_property(_corpo, "rotation:z", sentido * 0.15, duracao * 0.30)
	t.chain().set_parallel(true)
	t.tween_property(self, "position", inicio + Vector3(0.0, 0.10, sentido * 0.70), duracao * 0.22).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_corpo, "rotation:z", -sentido * 0.18, duracao * 0.22)
	t.chain().tween_callback(_emitir_impacto)
	t.set_parallel(true)
	t.tween_property(self, "position", inicio, duracao * 0.34)
	t.tween_property(_corpo, "rotation:z", 0.0, duracao * 0.34)
	t.chain().tween_callback(_encerrar_estado.bind("atacar"))


func _ataque_aquatico(duracao: float) -> void:
	var inicio := position
	var sentido := _sentido()
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", inicio.y + 0.28, duracao * 0.32)
	t.tween_property(self, "position:z", inicio.z + sentido * 0.34, duracao * 0.32)
	t.chain().tween_callback(_emitir_impacto)
	t.set_parallel(true)
	t.tween_property(self, "position", inicio, duracao * 0.40)
	t.chain().tween_callback(_encerrar_estado.bind("atacar"))


func _ataque_por_baixo(duracao: float) -> void:
	var inicio := position
	var sentido := _sentido()
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", inicio.y - 0.58, duracao * 0.27)
	t.tween_property(_corpo, "scale:y", 0.18, duracao * 0.27)
	t.chain().tween_property(self, "position:z", inicio.z + sentido * 1.45, duracao * 0.22).set_trans(Tween.TRANS_EXPO)
	t.set_parallel(true)
	t.tween_property(self, "position:y", inicio.y + 0.12, duracao * 0.20).set_trans(Tween.TRANS_BACK)
	t.tween_property(_corpo, "scale", Vector3(1.08, 1.08, 1.0), duracao * 0.20)
	t.chain().tween_callback(_emitir_impacto)
	t.set_parallel(true)
	t.tween_property(self, "position", inicio, duracao * 0.32)
	t.tween_property(_corpo, "scale", Vector3.ONE, duracao * 0.32)
	t.chain().tween_callback(_encerrar_estado.bind("atacar"))


## Momento exato do contato. O quadro de impacto entra AQUI, junto do sinal
## que libera o dano e o efeito — nunca antes.
func _emitir_impacto() -> void:
	_realce = 5.6
	_aplicar_estado(
		"heavy_impact" if _pesado_pendente else "light_impact", false, 0.0, true
	)
	animacao_terminou.emit("impacto")


func levar_dano(cor: Color = Color(1.0, 0.35, 0.35), duracao: float = 0.42) -> void:
	_ocupado = true
	_aplicar_estado("damage", false, 0.0, true)
	var inicio := position
	var t := _novo_tween()
	for indice in range(4):
		var sentido := -1.0 if indice % 2 == 0 else 1.0
		t.tween_property(self, "position:x", inicio.x + sentido * 0.13, duracao * 0.11)
		t.parallel().tween_method(_definir_flash.bind(cor), 0.0, 1.0, duracao * 0.08)
	t.set_parallel(true)
	t.tween_property(self, "position", inicio, duracao * 0.28)
	t.tween_method(_definir_flash.bind(cor), 1.0, 0.0, duracao * 0.28)
	t.chain().tween_callback(_encerrar_estado.bind("dano"))


func esquivar(sentido: int, duracao: float = 0.38) -> void:
	if sentido == 0 or _corpo == null:
		return
	_ocupado = true
	_aplicar_estado(
		"dodge_right" if sentido > 0 else "dodge_left", false, 0.0, true
	)
	var inicio := position
	var destino := inicio + Vector3(float(signi(sentido)) * 0.72, 0.0, 0.0)
	var t := _novo_tween()
	t.tween_method(
		_posicionar_esquiva.bind(inicio, destino, signi(sentido)), 0.0, 1.0, duracao
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_encerrar_esquiva.bind(destino))


func _posicionar_esquiva(progresso: float, inicio: Vector3, destino: Vector3, sentido: int) -> void:
	position = inicio.lerp(destino, progresso)
	position.y = inicio.y + sin(progresso * PI) * (0.08 if _locomocao == "terrestre" else 0.18)
	_corpo.rotation.z = -float(sentido) * sin(progresso * PI) * 0.16
	_corpo.scale = Vector3(
		1.0 - sin(progresso * PI) * 0.06, 1.0 + sin(progresso * PI) * 0.05, 1.0
	)


func _encerrar_esquiva(destino: Vector3) -> void:
	position = destino
	_corpo.rotation = Vector3(-_pitch_camera * COMPENSACAO_DE_PITCH, 0.0, 0.0)
	_corpo.scale = Vector3.ONE
	_encerrar_estado("esquiva")


func comemorar(duracao: float = 1.05) -> void:
	_ocupado = true
	_realce = 4.2
	_aplicar_estado("victory", true)
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(_corpo, "position:y", 0.24, duracao * 0.36).set_trans(Tween.TRANS_BACK)
	t.tween_property(_corpo, "scale", Vector3(1.10, 1.10, 1.0), duracao * 0.36)
	t.chain().set_parallel(true)
	t.tween_property(_corpo, "position:y", 0.0, duracao * 0.36)
	t.tween_property(_corpo, "scale", Vector3.ONE, duracao * 0.36)
	t.chain().tween_callback(_encerrar_estado.bind("comemorar"))


## Queda. O quadro de KO fica PRESO: a Beast derrotada nao volta a respirar.
func tombar(duracao: float = 0.95) -> void:
	_ocupado = true
	_aplicar_estado("ko", false, 0.0, true)
	var queda := 1.18 * _sentido() * -1.0
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(_corpo, "rotation:z", queda, duracao * 0.72).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_corpo, "position:y", -0.10, duracao * 0.72)
	t.chain().tween_callback(_encerrar_estado.bind("tombar", false))


func guardar(rodadas: int = 1) -> void:
	_ocupado = true
	_realce = 4.0
	_aplicar_estado("guard", false, 0.0, true)
	var t := _novo_tween()
	t.set_parallel(true)
	t.tween_property(_corpo, "scale", Vector3(1.04, 1.04, 1.0), 0.18).set_trans(Tween.TRANS_BACK)
	t.tween_method(_definir_brilho, 0.0, 0.60, 0.18)
	t.chain().tween_callback(_avisar_guarda_pronta.bind(rodadas))


func _avisar_guarda_pronta(rodadas: int) -> void:
	animacao_terminou.emit("guardar_%d" % rodadas)


func encerrar_guarda() -> void:
	_ocupado = false
	if _corpo != null:
		_corpo.scale = Vector3.ONE
	_definir_brilho(0.0)
	_realce = 1.0
	_voltar_ao_idle()


func _definir_brilho(valor: float) -> void:
	_brilho = valor
	if _material_sprite != null:
		_material_sprite.albedo_color = Color.WHITE.lerp(
			_cor_elemento.lightened(0.35), valor * 0.30
		)


func _definir_flash(valor: float, cor: Color) -> void:
	if _material_sprite != null:
		_material_sprite.albedo_color = Color.WHITE.lerp(
			cor.lightened(0.30), valor * 0.70
		)


func _encerrar_estado(nome: String, voltar_ao_idle: bool = true) -> void:
	if voltar_ao_idle and _corpo != null:
		_corpo.position = Vector3.ZERO
		_corpo.rotation = Vector3(-_pitch_camera * COMPENSACAO_DE_PITCH, 0.0, 0.0)
		_corpo.scale = Vector3.ONE
		_definir_brilho(0.0)
		_definir_flash(0.0, _cor_elemento)
		_voltar_ao_idle()
	if nome == "atacar":
		_pesado_pendente = false
	_ocupado = false
	_realce = 1.0
	animacao_terminou.emit(nome)
