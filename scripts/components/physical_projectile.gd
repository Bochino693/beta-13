class_name PhysicalProjectile
extends Node3D

## Projétil físico 3D: nasce no ponto de emissão da Beast,
## voa em trajetória curva até o alvo, e explode no impacto.
## Substitui o sistema antigo de Sprite3D que aparecia só no alvo.

signal impacto_alcancado

var _viewport: Viewport
var _sprite: AnimatedSprite3D
var _rastro: GPUParticles3D
var _explosao: GPUParticles3D
var _tween: Tween
var _cor: Color
var _pesado: bool
var _quadros: int

func _ready() -> void:
	pass

## Configura e dispara o projétil.
## @param viewport: o SubViewport da arena 3D
## @param origem: posição 3D de onde o poder sai (ponto_emissao() da Beast)
## @param destino: posição 3D do alvo
## @param textura: spritesheet do golpe (horizontal, quadros quadrados)
## @param cor: cor do elemento
## @param pesado: true se for golpe pesado (trajetória mais lenta e dramática)
func disparar(
	viewport: Viewport,
	origem: Vector3,
	destino: Vector3,
	textura: Texture2D,
	cor: Color,
	pesado: bool
) -> void:
	_viewport = viewport
	_cor = cor
	_pesado = pesado

	## Calcula quantidade de quadros na tira horizontal
	var tam := textura.get_size()
	_quadros = maxi(1, roundi(tam.x / maxf(1.0, tam.y)))

	## === SPRITE DO PROJÉTIL ===
	_sprite = AnimatedSprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.transparent = true
	_sprite.no_depth_test = false
	_sprite.render_priority = 9
	_sprite.pixel_size = 0.0044 if pesado else 0.0055
	_sprite.modulate = cor

	## Cria SpriteFrames do projétil
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_loop("fly", true)
	frames.set_animation_speed("fly", 12.0 if pesado else 18.0)

	var largura_quadro := tam.x / float(_quadros)
	var altura_quadro := tam.y
	for i in range(_quadros):
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(float(i) * largura_quadro, 0.0, largura_quadro, altura_quadro)
		atlas.filter_clip = true
		frames.add_frame("fly", atlas)

	_sprite.sprite_frames = frames
	_sprite.play("fly")
	_sprite.position = origem
	viewport.add_child(self)
	add_child(_sprite)

	## === RASTRO DE PARTÍCULAS ===
	_rastro = _criar_rastro()
	add_child(_rastro)

	## === ANIMAÇÃO DE VOO ===
	var duracao := 0.55 if pesado else 0.38
	var altura_arco := 0.85 if pesado else 0.55
	var desvio_lateral := -0.28 if origem.x < destino.x else 0.28

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	## Fase 1: aceleração inicial
	_tween.tween_method(
		_posicionar_curvo.bind(origem, destino, altura_arco * 0.3, desvio_lateral * 0.5),
		0.0, 0.25, duracao * 0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	## Fase 2: voo principal com arco
	_tween.tween_method(
		_posicionar_curvo.bind(origem, destino, altura_arco, desvio_lateral),
		0.25, 1.0, duracao * 0.75
	)

	## Fase 3: impacto
	_tween.tween_callback(_explodir.bind(destino))
	_tween.tween_interval(0.08)
	_tween.tween_callback(_finalizar)

func _posicionar_curvo(progresso: float, origem: Vector3, destino: Vector3, altura: float, desvio: float) -> void:
	if not is_instance_valid(self):
		return
	var posicao := origem.lerp(destino, progresso)
	var arco := sin(progresso * PI)
	posicao.y += arco * altura
	posicao.x += arco * desvio
	position = posicao

	## Rotação dinâmica baseada na direção
	var direcao := destino - origem
	if direcao.length() > 0.01:
		_sprite.rotation.z = atan2(direcao.y, direcao.x) * 0.3 * sin(progresso * PI)
		_sprite.rotation.y = progresso * TAU * 0.15

func _explodir(destino: Vector3) -> void:
	if not is_instance_valid(self):
		return

	## Esconde o sprite do projétil
	_sprite.visible = false
	_rastro.emitting = false

	## Cria explosão no ponto de impacto
	_explosao = _criar_explosao()
	add_child(_explosao)
	_explosao.global_position = destino
	_explosao.emitting = true

	impacto_alcancado.emit()

	## Som de impacto
	if _pesado:
		AudioSynth.special_hit()
	else:
		AudioSynth.hit(0.9)

func _finalizar() -> void:
	if is_instance_valid(self):
		queue_free()

func _criar_rastro() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 20
	p.one_shot = false
	p.emitting = true
	p.lifetime = 0.35
	p.local_coords = false
	p.explosiveness = 0.0

	var malha := QuadMesh.new()
	malha.size = Vector2(0.06, 0.06)
	p.draw_pass_1 = malha

	var visual := StandardMaterial3D.new()
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	visual.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	visual.albedo_color = _cor
	p.material_override = visual

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.08
	m.direction = Vector3(0, 0, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.4
	m.gravity = Vector3(0, 0, 0)
	m.scale_min = 0.3
	m.scale_max = 0.8
	p.process_material = m
	return p

func _criar_explosao() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 35 if _pesado else 22
	p.one_shot = true
	p.emitting = false
	p.lifetime = 0.45
	p.local_coords = false
	p.explosiveness = 0.95

	var malha := QuadMesh.new()
	malha.size = Vector2(0.10, 0.10) if _pesado else Vector2(0.07, 0.07)
	p.draw_pass_1 = malha

	var visual := StandardMaterial3D.new()
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	visual.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	visual.albedo_color = Color.WHITE
	p.material_override = visual

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 2.5 if _pesado else 1.8
	m.initial_velocity_max = 5.5 if _pesado else 3.5
	m.gravity = Vector3(0, -3.0, 0)
	m.damping_min = 3.0
	m.damping_max = 6.0
	m.scale_min = 0.5
	m.scale_max = 1.5

	## Gradiente de cor
	var gradiente := Gradient.new()
	gradiente.set_color(0, _cor)
	gradiente.set_color(1, Color(_cor.r * 0.3, _cor.g * 0.3, _cor.b * 0.3, 0.0))
	var tex_grad := GradientTexture1D.new()
	tex_grad.gradient = gradiente
	m.color_ramp = tex_grad

	p.process_material = m
	return p
