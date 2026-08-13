extends Node3D
class_name BattleEncenacao

# ---------------------------------------------------------------------------
# BattleEncenacao — enquadramento e vida da arena.
#
# 1. ENQUADRAMENTO
#    O problema: com a camera em (0, 2.18, 5.45) e o aliado em z=1.30 com
#    altura 3.00, ele ocupava 97% da altura da tela e a faixa horizontal dele
#    [0.10, 0.66] engolia inteira a do inimigo [0.45, 0.62]. O oponente ficava
#    100% coberto, e 3.27x menor.
#
#    A solucao foi calculada projetando as duas silhuetas na tela:
#      camera  y=2.00  z=6.50  rotX=-10  fov=52
#      aliado  x=-2.10 y=-0.40 z=0.40   altura 2.80  -> 52% da tela, x[0.10,0.39]
#      inimigo x= 2.00 y= 1.10 z=-1.50  altura 2.90  -> 37% da tela, x[0.57,0.78]
#    Sobreposicao: zero. O aliado fica 1.38x maior, cortado embaixo, canto
#    inferior esquerdo. O inimigo fica inteiro, elevado, a direita.
#
# 2. VIDA
#    Sombra no chao, plataforma flutuante sob o inimigo, poeira nos pes,
#    explosao de impacto, congelamento de quadro no golpe e poeira de entrada.
#    Tudo por codigo: nenhuma arte nova.
#
# Uso:
#   var enc := BattleEncenacao.new()
#   viewport.add_child(enc)
#   enc.registrar(0, rig_aliado, cor_aliado)
#   enc.registrar(1, rig_inimigo, cor_inimigo)
#   enc.impacto(1, cor)          # inimigo levou o golpe
# ---------------------------------------------------------------------------

# --- Enquadramento resolvido -----------------------------------------------
const CAMERA_POS := Vector3(0.0, 2.00, 6.50)
const CAMERA_ROT := Vector3(-10.0, 0.0, 0.0)
const CAMERA_FOV := 52.0
const CAMERA_FOV_PESADO := 40.0

const ALIADO_POS := Vector3(-2.10, -0.40, 0.40)
const ALIADO_ALTURA := 2.80
const ALIADO_PASSO := 0.62      # deslocamento lateral da esquiva

const INIMIGO_POS := Vector3(2.00, 1.10, -1.50)
const INIMIGO_ALTURA := 2.90
const INIMIGO_PASSO := 0.52

const CODIGO_SOMBRA := """
shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never;

uniform float forca = 0.75;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float s = smoothstep(1.0, 0.15, d);
	// blend_mul: 1.0 nao muda nada, 0.0 escurece tudo.
	ALBEDO = vec3(1.0 - s * forca);
}
"""

const CODIGO_PLATAFORMA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 cor : source_color = vec3(0.3, 0.7, 1.0);
uniform float tempo = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;

	// Disco cheio, desbotando para fora.
	float disco = smoothstep(1.0, 0.55, d) * 0.28;

	// Dois aneis girando em ritmos diferentes.
	float anel1 = smoothstep(0.06, 0.0, abs(d - 0.72 - sin(tempo * 0.9) * 0.03));
	float anel2 = smoothstep(0.04, 0.0, abs(d - 0.46 + sin(tempo * 1.4) * 0.02));

	// Raios saindo do centro.
	float ang = atan(UV.y - 0.5, UV.x - 0.5);
	float raios = pow(max(0.0, sin(ang * 12.0 + tempo * 0.7)), 8.0)
		* smoothstep(0.85, 0.25, d) * 0.5;

	float total = disco + anel1 * 0.9 + anel2 * 0.6 + raios;
	ALBEDO = cor * total;
	ALPHA = clamp(total, 0.0, 1.0);
}
"""

var _sombras: Array = [null, null]
var _plataforma: MeshInstance3D
var _mat_plataforma: ShaderMaterial
var _poeira: Array = [null, null]
var _estouro: Array = [null, null]
var _rigs: Array = [null, null]
var _tempo := 0.0
var _congelado := false


func _ready() -> void:
	_montar_plataforma()
	for lado in 2:
		_sombras[lado] = _montar_sombra()
		_poeira[lado] = _montar_poeira()
		_estouro[lado] = _montar_estouro()
	set_process(true)


func _process(delta: float) -> void:
	_tempo += delta
	if _mat_plataforma != null:
		_mat_plataforma.set_shader_parameter("tempo", _tempo)

	# A sombra acompanha a Beast: e o que gruda ela no chao.
	for lado in 2:
		var rig = _rigs[lado]
		var sombra: MeshInstance3D = _sombras[lado]
		if rig == null or not is_instance_valid(rig) or sombra == null:
			continue
		var p: Vector3 = rig.global_position
		sombra.global_position = Vector3(p.x, 0.02, p.z)
		# Quanto mais alto o corpo, menor e mais fraca a sombra.
		var altura := maxf(0.0, p.y)
		var escala := 1.0 / (1.0 + altura * 0.35)
		sombra.scale = Vector3(escala, 1.0, escala)
		var mat := sombra.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("forca", 0.72 * escala)


# ===========================================================================
# API
# ===========================================================================

## Aplica o enquadramento resolvido na camera.
static func aplicar_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = CAMERA_FOV
	camera.position = CAMERA_POS
	camera.rotation_degrees = CAMERA_ROT
	camera.near = 0.05
	camera.far = 90.0


## Posicao de base da Beast. faixa vai de -1 a 1 (esquiva lateral).
static func posicao(jogador: int, faixa: int = 0) -> Vector3:
	var base := ALIADO_POS if jogador == 0 else INIMIGO_POS
	var passo := ALIADO_PASSO if jogador == 0 else INIMIGO_PASSO
	return base + Vector3(float(clampi(faixa, -1, 1)) * passo, 0.0, 0.0)


static func altura(jogador: int) -> float:
	return ALIADO_ALTURA if jogador == 0 else INIMIGO_ALTURA


## Liga uma Beast a sua sombra, poeira e plataforma.
func registrar(jogador: int, rig: Node3D, cor: Color) -> void:
	_rigs[jogador] = rig
	if jogador == 1 and _plataforma != null:
		_plataforma.global_position = Vector3(
			rig.global_position.x, rig.global_position.y - 0.06, rig.global_position.z
		)
		if _mat_plataforma != null:
			_mat_plataforma.set_shader_parameter("cor", cor)
	_ajustar_cor(_poeira[jogador], cor)
	_ajustar_cor(_estouro[jogador], cor)


## Poeira levantada quando a Beast entra ou pisa firme.
func pisar(jogador: int) -> void:
	var p: GPUParticles3D = _poeira[jogador]
	var rig = _rigs[jogador]
	if p == null or rig == null or not is_instance_valid(rig):
		return
	p.global_position = Vector3(rig.global_position.x, rig.global_position.y + 0.05, rig.global_position.z)
	p.restart()
	p.emitting = true


## Estouro no ponto de impacto + congelamento curto de quadro.
func impacto(jogador: int, cor: Color, pesado: bool = false) -> void:
	var e: GPUParticles3D = _estouro[jogador]
	var rig = _rigs[jogador]
	if e != null and rig != null and is_instance_valid(rig):
		_ajustar_cor(e, cor)
		e.global_position = rig.global_position + Vector3(0.0, altura(jogador) * 0.45, 0.25)
		e.amount = 46 if pesado else 26
		e.restart()
		e.emitting = true
	pisar(jogador)
	congelar(0.12 if pesado else 0.06)


## Hit stop: o quadro trava por um instante no impacto. E o truque mais barato
## que existe para um golpe parecer que tem peso.
func congelar(duracao: float) -> void:
	if _congelado:
		return
	_congelado = true
	Engine.time_scale = 0.06
	await get_tree().create_timer(duracao * 0.06, true, false, true).timeout
	Engine.time_scale = 1.0
	_congelado = false


# ===========================================================================
# Montagem
# ===========================================================================

func _material(codigo: String) -> ShaderMaterial:
	var s := Shader.new()
	s.code = codigo
	var m := ShaderMaterial.new()
	m.shader = s
	return m


func _montar_sombra() -> MeshInstance3D:
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.3, 1.6)

	var no := MeshInstance3D.new()
	no.mesh = plano
	no.material_override = _material(CODIGO_SOMBRA)
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.sorting_offset = 1.0
	add_child(no)
	return no


func _montar_plataforma() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(3.6, 3.6)

	_mat_plataforma = _material(CODIGO_PLATAFORMA)

	_plataforma = MeshInstance3D.new()
	_plataforma.mesh = plano
	_plataforma.material_override = _mat_plataforma
	_plataforma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plataforma.sorting_offset = 2.0
	add_child(_plataforma)


func _particulas(quantidade: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = quantidade
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.92
	p.local_coords = false

	var malha := QuadMesh.new()
	malha.size = Vector2(0.16, 0.16)
	p.draw_pass_1 = malha

	var visual := StandardMaterial3D.new()
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	visual.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	visual.vertex_color_use_as_albedo = true
	visual.albedo_color = Color(1, 1, 1)
	p.material_override = visual

	add_child(p)
	return p


func _montar_poeira() -> GPUParticles3D:
	var p := _particulas(18)
	p.lifetime = 0.75

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.55
	m.direction = Vector3(0, 1, 0)
	m.spread = 62.0
	m.initial_velocity_min = 0.7
	m.initial_velocity_max = 1.9
	m.gravity = Vector3(0, -2.4, 0)
	m.damping_min = 1.2
	m.damping_max = 2.6
	m.scale_min = 0.4
	m.scale_max = 1.1
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.2))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var textura := CurveTexture.new()
	textura.curve = curva
	m.scale_curve = textura
	p.process_material = m
	return p


func _montar_estouro() -> GPUParticles3D:
	var p := _particulas(30)
	p.lifetime = 0.55

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.30
	m.direction = Vector3(0, 0, 1)
	m.spread = 180.0
	m.initial_velocity_min = 3.2
	m.initial_velocity_max = 7.5
	m.gravity = Vector3(0, -1.2, 0)
	m.damping_min = 5.0
	m.damping_max = 9.0
	m.scale_min = 0.7
	m.scale_max = 1.8
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var textura := CurveTexture.new()
	textura.curve = curva
	m.scale_curve = textura
	p.process_material = m
	return p


func _ajustar_cor(particulas: GPUParticles3D, cor: Color) -> void:
	if particulas == null:
		return
	var m := particulas.process_material as ParticleProcessMaterial
	if m == null:
		return
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(cor.r, cor.g, cor.b, 1.0))
	gradiente.set_color(1, Color(cor.r * 0.4, cor.g * 0.4, cor.b * 0.4, 0.0))
	var textura := GradientTexture1D.new()
	textura.gradient = gradiente
	m.color_ramp = textura
