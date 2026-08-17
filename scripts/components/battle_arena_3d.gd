class_name BattleArena3D
extends Node3D

## Cenario 3D da batalha.
##
## Substitui o estadio antigo, que desenhava arquibancada, publico e treliça
## aerea em geometria procedural E AINDA por cima colava um recorte da arte
## da arena la no fundo. Eram dois cenarios concorrentes no mesmo espaço: a
## arte dizia uma coisa, os cilindros diziam outra, e a arte apanhava — ela
## entrava recortada num pedaço de 941x790 px, atras de um muro de caixas.
##
## Aqui a ARTE DA ARENA E O CENARIO. A imagem de `data/arenas.json` cobre
## todo o campo de visao da camera e e ela que define ceu, arquitetura,
## publico e horizonte. A geometria que sobra e so a que a Beast precisa
## para existir num lugar: o piso onde ela pisa, a linha de horizonte que
## costura piso e arte, as luzes que a acendem e os aneis de reacao do
## impacto.

const ALTURA_DO_HORIZONTE := 0.0

## Distancia do painel de fundo. Longe o bastante para nunca ser atravessado
## por um avanço de Beast ou por um poder, perto o bastante para nao sofrer
## com a precisao do buffer de profundidade.
const DISTANCIA_DO_FUNDO := 26.0

## Sobra do painel alem do enquadramento. A arte SEMPRE cobre a tela com
## folga; nunca aparece barra preta na borda quando a camera treme.
const FOLGA_DO_FUNDO := 1.14

var _cor_p1 := Color("6ef8ff")
var _cor_p2 := Color("ff55c6")
var _caminho_do_fundo := ""

var _fundo: MeshInstance3D
var _material_fundo: StandardMaterial3D
var _piso: MeshInstance3D
var _material_piso: ShaderMaterial
var _costura: MeshInstance3D
var _material_costura: StandardMaterial3D
var _holofotes: Array[SpotLight3D] = []
var _marcadores: Array = [[], []]
var _tempo := 0.0
var _pulso := 1.0
var _energia_do_impacto := 0.0
var _cor_do_impacto := Color("6ef8ff")

## Piso: circulo central, eixo e vinheta, tingidos pelas cores dos dois
## jogadores. Nada aqui compete com a arte do fundo — o piso e escuro e so
## marca onde as Beasts pisam.
const CODIGO_DO_PISO := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec3 cor_base : source_color = vec3(0.012, 0.020, 0.055);
uniform vec3 cor_p1 : source_color = vec3(0.43, 0.97, 1.00);
uniform vec3 cor_p2 : source_color = vec3(1.00, 0.33, 0.78);
uniform vec3 cor_impacto : source_color = vec3(1.0, 1.0, 1.0);
uniform float energia_impacto = 0.0;
uniform float tempo = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float raio = length(p);

	// Meia-quadra de cada jogador: quem esta perto da camera (v > 0.5) e o
	// jogador local; o fundo e do rival.
	float lado = smoothstep(0.46, 0.54, UV.y);
	vec3 cor_do_lado = mix(cor_p2, cor_p1, lado);

	float circulo = 1.0 - smoothstep(0.30, 0.315, abs(raio - 0.30));
	float miolo = 1.0 - smoothstep(0.115, 0.125, abs(raio - 0.115));
	float eixo = 1.0 - smoothstep(0.0015, 0.005, abs(p.y));
	float vinheta = smoothstep(0.72, 0.05, raio);

	// A luz do piso morre na direcao do horizonte, entao o chao se dissolve
	// na arte do fundo em vez de terminar numa borda reta.
	float dissolve = smoothstep(0.0, 0.42, UV.y);

	vec3 cor = cor_base;
	cor += cor_do_lado * (circulo * 0.30 + miolo * 0.20 + eixo * 0.07) * vinheta;
	cor += cor_do_lado * vinheta * 0.045;

	float onda = 1.0 - smoothstep(0.0, 0.34, abs(raio - fract(tempo * 0.55) * 0.9));
	cor += cor_impacto * onda * energia_impacto * 0.55;

	ALBEDO = cor * dissolve;
	ALPHA = dissolve;
}
"""


func _ready() -> void:
	set_process(true)


## Monta o cenario. `caminho_do_fundo` vem de `data/arenas.json`; e o unico
## lugar de onde sai a aparencia da arena.
func configurar(
	cor_p1: Color,
	cor_p2: Color,
	_tipo_p1: String = "",
	_tipo_p2: String = "",
	caminho_do_fundo: String = ""
) -> void:
	_cor_p1 = cor_p1
	_cor_p2 = cor_p2
	_caminho_do_fundo = caminho_do_fundo
	_montar_fundo()
	_montar_piso()
	_montar_costura()
	_montar_luzes()
	_montar_marcadores()


## Dimensiona o painel de fundo para COBRIR exatamente o que a camera ve.
##
## Chamada depois que a camera existe, porque o tamanho do painel depende do
## campo de visao e da proporcao do viewport. E isto que faz a arte "ser
## tudo": ela nao e um adereço no fundo, ela e a moldura inteira da cena.
func alinhar_camera(camera: Camera3D, tamanho_do_viewport: Vector2) -> void:
	if camera == null or _fundo == null:
		return

	var proporcao := tamanho_do_viewport.x / maxf(1.0, tamanho_do_viewport.y)
	var altura_visivel := 2.0 * DISTANCIA_DO_FUNDO * tan(deg_to_rad(camera.fov) * 0.5)
	var largura_visivel := altura_visivel * proporcao

	var textura := _material_fundo.albedo_texture
	var proporcao_da_arte := 1.0
	if textura != null:
		proporcao_da_arte = float(textura.get_width()) / maxf(1.0, float(textura.get_height()))

	## Cobrir, nunca encaixar: usamos a maior das duas escalas, entao a arte
	## transborda pela borda mais folgada em vez de deixar faixa vazia.
	var altura := altura_visivel * FOLGA_DO_FUNDO
	var largura := altura * proporcao_da_arte
	if largura < largura_visivel * FOLGA_DO_FUNDO:
		largura = largura_visivel * FOLGA_DO_FUNDO
		altura = largura / proporcao_da_arte

	var plano := _fundo.mesh as QuadMesh
	plano.size = Vector2(largura, altura)

	## Posiciona o painel a DISTANCIA_DO_FUNDO a frente da camera, no eixo
	## de visao dela, e o deixa de frente para a camera.
	var direcao := -camera.global_transform.basis.z.normalized()
	_fundo.global_position = camera.global_position + direcao * DISTANCIA_DO_FUNDO
	_fundo.global_rotation = camera.global_rotation


func _montar_fundo() -> void:
	if _caminho_do_fundo.is_empty() or not ResourceLoader.exists(_caminho_do_fundo):
		push_error("BattleArena3D: arte da arena ausente -> " + _caminho_do_fundo)
		return

	_material_fundo = StandardMaterial3D.new()
	_material_fundo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_fundo.albedo_texture = load(_caminho_do_fundo) as Texture2D
	_material_fundo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_material_fundo.cull_mode = BaseMaterial3D.CULL_DISABLED
	## Opaco e COM profundidade normal.
	##
	## Nao usar `no_depth_test` aqui: ele desliga o teste de profundidade e o
	## painel passa a pintar por cima de tudo, inclusive das Beasts. Foi
	## exatamente o que aconteceu — as criaturas viravam silhuetas escuras,
	## porque o fundo era desenhado depois delas e as cobria.
	##
	## Como painel esta a 26 unidades da camera e as Beasts a menos de 13, o
	## teste de profundidade normal ja resolve a ordem: tudo que estiver na
	## arena aparece na frente dele.
	_material_fundo.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_material_fundo.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_material_fundo.no_depth_test = false

	_fundo = MeshInstance3D.new()
	_fundo.mesh = QuadMesh.new()
	_fundo.material_override = _material_fundo
	_fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fundo.extra_cull_margin = 64.0
	add_child(_fundo)


func _montar_piso() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(24.0, 26.0)
	plano.subdivide_width = 1
	plano.subdivide_depth = 1

	var shader := Shader.new()
	shader.code = CODIGO_DO_PISO
	_material_piso = ShaderMaterial.new()
	_material_piso.shader = shader
	_material_piso.set_shader_parameter("cor_p1", Vector3(_cor_p1.r, _cor_p1.g, _cor_p1.b))
	_material_piso.set_shader_parameter("cor_p2", Vector3(_cor_p2.r, _cor_p2.g, _cor_p2.b))
	_material_piso.set_shader_parameter("energia_impacto", 0.0)
	_material_piso.set_shader_parameter("tempo", 0.0)

	_piso = MeshInstance3D.new()
	_piso.mesh = plano
	_piso.material_override = _material_piso
	_piso.position = Vector3(0.0, ALTURA_DO_HORIZONTE, -2.4)
	_piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_piso)


## Costura entre o piso e a arte: uma faixa horizontal de luz baixa, na cor
## da arena, exatamente na linha do horizonte. Sem ela o chao termina numa
## aresta dura e a arena volta a parecer um adesivo atras de um tabuleiro.
func _montar_costura() -> void:
	_material_costura = StandardMaterial3D.new()
	_material_costura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_costura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_costura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material_costura.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_costura.albedo_color = Color(_cor_p2.r, _cor_p2.g, _cor_p2.b, 0.16)
	_material_costura.emission_enabled = true
	_material_costura.emission = _cor_p2
	_material_costura.emission_energy_multiplier = 1.4

	var quad := QuadMesh.new()
	quad.size = Vector2(26.0, 1.5)

	_costura = MeshInstance3D.new()
	_costura.mesh = quad
	_costura.material_override = _material_costura
	_costura.position = Vector3(0.0, 0.30, -14.6)
	_costura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_costura)


func _montar_luzes() -> void:
	for indice in 2:
		var cor := _cor_p1 if indice == 0 else _cor_p2
		var foco := SpotLight3D.new()
		foco.light_color = cor
		foco.light_energy = 1.5
		foco.spot_range = 20.0
		foco.spot_angle = 40.0
		foco.shadow_enabled = false
		foco.position = Vector3(
			-4.6 if indice == 0 else 4.6, 7.4, 1.2 if indice == 0 else -4.4
		)
		foco.look_at_from_position(
			foco.position, Vector3(0.0, 0.4, 0.6 if indice == 0 else -3.8), Vector3.UP
		)
		add_child(foco)
		_holofotes.append(foco)


## Tres marcas de faixa por jogador. Sao elas que mostram para onde a Beast
## pode se deslocar e qual faixa esta ocupada.
func _montar_marcadores() -> void:
	for jogador in 2:
		_marcadores[jogador] = []
		for faixa in range(-1, 2):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			var cor := _cor_p1 if jogador == 0 else _cor_p2
			material.albedo_color = Color(cor.r, cor.g, cor.b, 0.10)
			material.emission_enabled = true
			material.emission = cor

			var anel := TorusMesh.new()
			anel.inner_radius = 0.50
			anel.outer_radius = 0.56
			anel.rings = 24
			anel.ring_segments = 5

			var marca := MeshInstance3D.new()
			marca.mesh = anel
			marca.material_override = material
			marca.position = Vector3(
				_x_da_faixa(jogador, faixa), 0.018, 0.30 if jogador == 0 else -4.35
			)
			marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(marca)
			(_marcadores[jogador] as Array).append(marca)


func _x_da_faixa(jogador: int, faixa: int) -> float:
	var centro := -1.32 if jogador == 0 else 1.18
	var passo := 0.56 if jogador == 0 else 0.48
	return centro + float(clampi(faixa, -1, 1)) * passo


func _process(delta: float) -> void:
	_tempo += delta
	_pulso = move_toward(_pulso, 1.0, delta * 5.0)
	_energia_do_impacto = move_toward(_energia_do_impacto, 0.0, delta * 1.9)

	if _material_piso != null:
		_material_piso.set_shader_parameter("tempo", _tempo)
		_material_piso.set_shader_parameter("energia_impacto", _energia_do_impacto)
		_material_piso.set_shader_parameter(
			"cor_impacto",
			Vector3(_cor_do_impacto.r, _cor_do_impacto.g, _cor_do_impacto.b)
		)

	if _material_costura != null:
		## Respiro atmosferico. So a EMISSAO oscila: o horizonte nunca se
		## move, senao a arena inteira parece flutuar.
		_material_costura.emission_energy_multiplier = (
			1.25 + sin(_tempo * 0.62) * 0.22
		) * _pulso

	if _material_fundo != null:
		var atmosfera := 0.965 + sin(_tempo * 0.34) * 0.022
		_material_fundo.albedo_color = Color(
			atmosfera, atmosfera, minf(1.0, atmosfera + 0.022)
		)

	for indice in range(_holofotes.size()):
		var foco := _holofotes[indice]
		foco.light_energy = (1.35 + sin(_tempo * 1.35 + float(indice) * 0.9) * 0.28) * _pulso


func impacto(cor: Color, forca: float = 1.0) -> void:
	_cor_do_impacto = cor
	_energia_do_impacto = clampf(forca, 0.0, 1.4)
	_pulso = 1.0 + forca * 0.85


## Reacao do cenario ao golpe: onda no piso, clarao na costura do horizonte
## e um anel expandindo no ponto de impacto, todos na cor do elemento.
func reagir_golpe(
	_golpe: Dictionary, cor: Color, forca: float = 1.0, ponto: Vector3 = Vector3.ZERO
) -> void:
	impacto(cor, forca)
	if _material_costura != null:
		_material_costura.emission = cor
		_material_costura.albedo_color = Color(cor.r, cor.g, cor.b, 0.16 + forca * 0.14)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(cor.r, cor.g, cor.b, 0.60)
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = 2.4

	var anel := TorusMesh.new()
	anel.inner_radius = 0.16
	anel.outer_radius = 0.22
	anel.rings = 26
	anel.ring_segments = 5

	var onda := MeshInstance3D.new()
	onda.mesh = anel
	onda.material_override = material
	onda.rotation_degrees.x = 8.0
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Entra na arvore ANTES de receber posicao global: fora da arvore o no
	## nao tem transformada global e o valor seria descartado, deixando o
	## anel de impacto na origem em vez de no ponto atingido.
	add_child(onda)
	onda.global_position = Vector3(ponto.x, maxf(0.05, ponto.y * 0.30), ponto.z)

	var escala_final := 3.4 + forca * 2.4
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(onda, "scale", Vector3.ONE * escala_final, 0.46).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(material, "albedo_color:a", 0.0, 0.46)
	t.chain().tween_callback(onda.queue_free)


## Acende a faixa ocupada e apaga as outras. `ameacada` acende em vermelho a
## faixa que vai ser atingida, quando o combate quiser avisar o jogador.
func definir_faixa(jogador: int, faixa: int, ameacada: int = 99) -> void:
	if jogador < 0 or jogador > 1:
		return
	var lista: Array = _marcadores[jogador]
	for indice in range(lista.size()):
		var marca := lista[indice] as MeshInstance3D
		if marca == null:
			continue
		var material := marca.material_override as StandardMaterial3D
		var esta_faixa := indice - 1
		var cor := _cor_p1 if jogador == 0 else _cor_p2
		var ocupada := esta_faixa == clampi(faixa, -1, 1)
		if esta_faixa == ameacada:
			cor = Color("ff4a48")
		material.emission = cor
		material.albedo_color = Color(cor.r, cor.g, cor.b, 0.34 if ocupada else 0.09)
		material.emission_energy_multiplier = 2.2 if ocupada else 0.7
