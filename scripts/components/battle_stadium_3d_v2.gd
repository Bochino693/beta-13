class_name BattleStadium3DV2
extends Node3D

## Arena V2: área de jogo maior, fundo em 3 camadas,
## mistura de elementos programáveis com imagem/vídeo HD.

signal arena_pronta

const CODIGO_CHAO := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform sampler2D albedo : source_color;
uniform float brilho = 1.0;
uniform float tempo = 0.0;

void fragment() {
 vec4 tex = texture(albedo, UV);
 float pulso = 0.92 + sin(tempo * 1.2 + UV.x * 6.283) * 0.08;
 ALBEDO = tex.rgb * brilho * pulso;
 ALPHA = tex.a;
}
"""

const CODIGO_NEBLINA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.4, 0.6, 0.9);
uniform float tempo = 0.0;
uniform float densidade = 0.5;

float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 float a = hash(i);
 float b = hash(i + vec2(1.0, 0.0));
 float c = hash(i + vec2(0.0, 1.0));
 float d = hash(i + vec2(1.0, 1.0));
 return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
 vec2 uv = UV * 3.0;
 float n = noise(uv + tempo * 0.15) * 0.5 + noise(uv * 2.0 - tempo * 0.08) * 0.25;
 float mask = smoothstep(0.2, 0.8, n) * densidade;
 ALBEDO = cor * mask;
 ALPHA = mask * 0.35;
}
"""

const CODIGO_GRID := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.2, 0.5, 1.0);
uniform float tempo = 0.0;

void fragment() {
 vec2 grid = abs(fract(UV * 40.0 - 0.5) - 0.5) / fwidth(UV * 40.0);
 float linha = min(grid.x, grid.y);
 float glow = 1.0 - smoothstep(0.0, 1.5, linha);
 float pulso = 0.7 + sin(tempo * 2.0 + UV.y * 10.0) * 0.3;
 ALBEDO = cor * glow * pulso * 0.15;
 ALPHA = glow * pulso * 0.15;
}
"""

var _tempo := 0.0
var _mat_chao: ShaderMaterial
var _mat_neblina: ShaderMaterial
var _mat_grid: ShaderMaterial
var _viewport: SubViewport
var _camera: Camera3D
var _encenacao: BattleEncenacao

## Camadas de fundo
var _fundo_hd: MeshInstance3D
var _fundo_parallax_1: MeshInstance3D  ## camada distante (montanhas/horizonte)
var _fundo_parallax_2: MeshInstance3D  ## camada média (árvores/ruínas)
var _fundo_parallax_3: MeshInstance3D  ## camada próxima (névoa/efeitos)

func _ready() -> void:
	set_process(true)

func montar(viewport: SubViewport, camera: Camera3D) -> void:
	_viewport = viewport
	_camera = camera

	## === EXPANDE A ÁREA DE JOGO ===
	## Arena maior: antes ~6x4, agora ~12x8 com profundidade
	var arena_largura := 14.0
	var arena_profundidade := 10.0

	## === CHÃO PROGRAMÁVEL ===
	var chao := MeshInstance3D.new()
	var malha_chao := PlaneMesh.new()
	malha_chao.size = Vector2(arena_largura, arena_profundidade)
	malha_chao.subdivide_width = 8
	malha_chao.subdivide_depth = 8
	chao.mesh = malha_chao
	chao.rotation_degrees.x = -90
	chao.position.y = -0.02

	var shader_chao := Shader.new()
	shader_chao.code = CODIGO_CHAO
	_mat_chao = ShaderMaterial.new()
	_mat_chao.shader = shader_chao
	## Tenta carregar textura de chão HD
	var tex_chao := _carregar_textura("res://assets/battle/stadium/ground_hd.png")
	if tex_chao != null:
		_mat_chao.set_shader_parameter("albedo", tex_chao)
	else:
		## Fallback: cor sólida com gradiente procedural
		_mat_chao.set_shader_parameter("albedo", _criar_gradiente_chao())
	_mat_chao.set_shader_parameter("brilho", 0.85)
	chao.material_override = _mat_chao
	add_child(chao)

	## === GRID DE BATALHA ===
	var grid := MeshInstance3D.new()
	var malha_grid := PlaneMesh.new()
	malha_grid.size = Vector2(arena_largura * 0.85, arena_profundidade * 0.85)
	grid.mesh = malha_grid
	grid.rotation_degrees.x = -90
	grid.position.y = 0.005

	var shader_grid := Shader.new()
	shader_grid.code = CODIGO_GRID
	_mat_grid = ShaderMaterial.new()
	_mat_grid.shader = shader_grid
	_mat_grid.set_shader_parameter("cor", Color(0.3, 0.6, 1.0))
	grid.material_override = _mat_grid
	add_child(grid)

	## === CAMADAS DE FUNDO (PARALLAX) ===
	## Camada 1: Horizonte distante (imagem HD ou vídeo)
	_fundo_parallax_1 = _criar_camada_fundo(
		arena_largura * 2.5, arena_profundidade * 1.5,
		-8.0, 3.5, 0.02,  ## z profundo, y alto, velocidade parallax lenta
		"res://assets/battle/stadium/horizon_hd.png",
		Color(0.15, 0.25, 0.45)
	)
	add_child(_fundo_parallax_1)

	## Camada 2: Elementos médios (árvores, ruínas, rochas)
	_fundo_parallax_2 = _criar_camada_fundo(
		arena_largura * 1.8, arena_profundidade * 1.2,
		-5.0, 2.0, 0.05,
		"res://assets/battle/stadium/midground_hd.png",
		Color(0.20, 0.30, 0.50)
	)
	add_child(_fundo_parallax_2)

	## Camada 3: Névina próxima (shader procedural)
	_fundo_parallax_3 = _criar_neblina(arena_largura * 1.2, arena_profundidade * 1.2, -2.0, 0.5)
	add_child(_fundo_parallax_3)

	## === VÍDEO DE FUNDO (opcional) ===
	var video := _criar_video_fundo()
	if video != null:
		add_child(video)

	## === ENQUADRAMENTO DA CÂMERA ===
	BattleEncenacao.aplicar_camera(camera)

	## === ENCEENAÇÃO ===
	_encenacao = BattleEncenacao.new()
	add_child(_encenacao)

	arena_pronta.emit()

func _criar_camada_fundo(largura: float, altura: float, z: float, y: float, velocidade: float, caminho: String, cor_fallback: Color) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(largura, altura)
	instancia.mesh = malha
	instancia.position = Vector3(0.0, y, z)
	instancia.rotation_degrees.x = -5  ## leve inclinação para profundidade

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D albedo : source_color;
uniform float alpha = 0.85;
uniform float desfoque = 0.0;
void fragment() {
 vec4 tex = texture(albedo, UV);
 ALBEDO = tex.rgb;
 ALPHA = tex.a * alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader

	var tex := _carregar_textura(caminho)
	if tex != null:
		mat.set_shader_parameter("albedo", tex)
		mat.set_shader_parameter("alpha", 0.85)
	else:
		## Fallback: gradiente procedural
		mat.set_shader_parameter("albedo", _criar_gradiente_silhueta(cor_fallback))
		mat.set_shader_parameter("alpha", 0.60)

	instancia.material_override = mat
	instancia.set_meta("velocidade_parallax", velocidade)
	instancia.set_meta("posicao_original", instancia.position)
	return instancia

func _criar_neblina(largura: float, profundidade: float, z: float, y: float) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(largura, profundidade)
	instancia.mesh = malha
	instancia.position = Vector3(0.0, y, z)
	instancia.rotation_degrees.x = -90

	var shader := Shader.new()
	shader.code = CODIGO_NEBLINA
	_mat_neblina = ShaderMaterial.new()
	_mat_neblina.shader = shader
	_mat_neblina.set_shader_parameter("cor", Color(0.4, 0.6, 0.9))
	_mat_neblina.set_shader_parameter("densidade", 0.35)
	instancia.material_override = _mat_neblina
	instancia.set_meta("velocidade_parallax", 0.12)
	instancia.set_meta("posicao_original", instancia.position)
	return instancia

func _criar_video_fundo() -> Node3D:
	var caminho := "res://assets/battle/stadium/arena_loop.ogv"
	if not ResourceLoader.exists(caminho):
		return null

	var player := VideoStreamPlayer.new()
	var stream := load(caminho) as VideoStream
	if stream == null:
		return null
	player.stream = stream
	player.autoplay = true
	player.loop = true
	player.expand = true
	player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	## Renderiza vídeo em textura 3D
	var subviewport := SubViewport.new()
	subviewport.size = Vector2i(1920, 1080)
	subviewport.transparent_bg = true
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.size = Vector2(1920, 1080)
	rect.add_child(player)
	subviewport.add_child(rect)

	var instancia := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(20.0, 11.25)
	instancia.mesh = malha
	instancia.position = Vector3(0.0, 4.0, -10.0)
	instancia.rotation_degrees.x = -2

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = subviewport.get_texture()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.70)
	instancia.material_override = mat

	add_child(subviewport)
	return instancia

func _carregar_textura(caminho: String) -> Texture2D:
	if ResourceLoader.exists(caminho):
		return load(caminho) as Texture2D
	return null

func _criar_gradiente_chao() -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(0.08, 0.12, 0.25))
	gradiente.set_color(1, Color(0.15, 0.22, 0.40))
	var tex := GradientTexture2D.new()
	tex.gradient = gradiente
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 512
	tex.height = 512
	return tex

func _criar_gradiente_silhueta(cor: Color) -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.set_color(0, cor)
	gradiente.set_color(1, Color(cor.r * 0.3, cor.g * 0.3, cor.b * 0.3, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradiente
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 512
	tex.height = 256
	return tex

func _process(delta: float) -> void:
	_tempo += delta

	if _mat_chao != null:
		_mat_chao.set_shader_parameter("tempo", _tempo)
	if _mat_neblina != null:
		_mat_neblina.set_shader_parameter("tempo", _tempo)
	if _mat_grid != null:
		_mat_grid.set_shader_parameter("tempo", _tempo)

	## === PARALLAX BASEADO NA CÂMERA ===
	if _camera != null:
		var offset_x := _camera.global_position.x * 0.5
		var offset_y := _camera.global_position.y * 0.3

		for camada in [_fundo_parallax_1, _fundo_parallax_2, _fundo_parallax_3]:
			if camada == null:
				continue
			var vel: float = camada.get_meta("velocidade_parallax", 0.0)
			var orig: Vector3 = camada.get_meta("posicao_original", camada.position)
			camada.position.x = orig.x + offset_x * vel
			camada.position.y = orig.y + offset_y * vel * 0.5

## API pública
func registrar(jogador: int, rig: Node3D, cor: Color) -> void:
	if _encenacao != null:
		_encenacao.registrar(jogador, rig, cor)

func pisar(jogador: int) -> void:
	if _encenacao != null:
		_encenacao.pisar(jogador)

func impacto(jogador: int, cor: Color, pesado: bool = false) -> void:
	if _encenacao != null:
		_encenacao.impacto(jogador, cor, pesado)

func congelar(duracao: float) -> void:
	if _encenacao != null:
		_encenacao.congelar(duracao)
