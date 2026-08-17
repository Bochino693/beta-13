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
var _familia := "orb"
var _viagem := "direct"
var _reacao := "energy"
var _geometria: Node3D

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
	pesado: bool,
	golpe: Dictionary = {}
) -> void:
	_viewport = viewport
	_cor = cor
	_pesado = pesado
	_familia = str(golpe.get("effect_family", "orb"))
	_viagem = str(golpe.get("travel_style", "direct"))
	_reacao = str(golpe.get("scene_reaction", "energy"))
	position = origem

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
	_sprite.position = Vector3.ZERO
	viewport.add_child(self)
	add_child(_sprite)
	_geometria = _criar_geometria_3d()
	add_child(_geometria)

	## === RASTRO DE PARTÍCULAS ===
	_rastro = _criar_rastro()
	add_child(_rastro)

	## === ANIMAÇÃO DE VOO ===
	var duracao := _duracao_da_viagem()
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
	match _viagem:
		"ground", "seeking_ground":
			var piso := 0.16
			if progresso < 0.18:
				posicao.y = lerpf(origem.y, piso, progresso / 0.18)
			elif progresso > 0.82:
				posicao.y = lerpf(piso, destino.y, (progresso - 0.82) / 0.18)
			else:
				posicao.y = piso + sin(progresso * PI * 7.0) * 0.035
		"overhead":
			posicao.y += arco * (2.55 if _pesado else 1.90)
			posicao.x += sin(progresso * TAU) * 0.18
		"zigzag":
			posicao.x += sin(progresso * PI * 10.0) * 0.22
			posicao.y += sin(progresso * PI * 7.0) * 0.12
		"spiral":
			posicao.x += sin(progresso * TAU * 2.2) * (1.0 - progresso) * 0.48
			posicao.y += cos(progresso * TAU * 2.2) * (1.0 - progresso) * 0.32 + arco * 0.25
		"wave":
			posicao.y += sin(progresso * PI * 4.0) * 0.18 + arco * 0.15
		"dive":
			posicao.y += arco * 1.45
			posicao.x += arco * desvio
		"drift", "sweeping":
			posicao.x += sin(progresso * PI * 3.0) * desvio
			posicao.y += arco * 0.30
		_:
			posicao.y += arco * altura
			posicao.x += arco * desvio
	position = posicao

	## Rotação dinâmica baseada na direção
	var direcao := destino - origem
	if direcao.length() > 0.01:
		_sprite.rotation.z = atan2(direcao.y, direcao.x) * 0.3 * sin(progresso * PI)
		_sprite.rotation.y = progresso * TAU * 0.15
	if _geometria != null:
		_geometria.rotation.z += get_process_delta_time() * (5.0 if _pesado else 7.0)
		var pulso := 1.0 + sin(progresso * PI * 5.0) * 0.08
		_geometria.scale = Vector3.ONE * pulso

func _explodir(destino: Vector3) -> void:
	if not is_instance_valid(self):
		return

	## Esconde o sprite do projétil
	_sprite.visible = false
	if _geometria != null:
		_geometria.visible = false
	_rastro.emitting = false

	## Cria explosão no ponto de impacto
	_explosao = _criar_explosao()
	add_child(_explosao)
	_explosao.global_position = destino
	_explosao.emitting = true
	_criar_impacto_3d()

	impacto_alcancado.emit()

func _finalizar() -> void:
	if is_instance_valid(self):
		queue_free()


func _duracao_da_viagem() -> float:
	if _viagem == "blink":
		return 0.22
	if _viagem in ["overhead", "seeking_ground", "spiral"]:
		return 0.68 if _pesado else 0.54
	if _familia in ["beam", "breath", "lightning", "gust"]:
		return 0.40 if _pesado else 0.30
	return 0.58 if _pesado else 0.40


func _material_energia(cor: Color, energia: float, alpha: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(cor.r, cor.g, cor.b, alpha)
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = energia
	return material


func _adicionar_malha(
	pai: Node3D, malha: Mesh, material: Material, deslocamento: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	instancia.mesh = malha
	instancia.material_override = material
	instancia.position = deslocamento
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(instancia)
	return instancia


func _adicionar_esfera(
	pai: Node3D, raio: float, material: Material, deslocamento: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var malha := SphereMesh.new()
	malha.radius = raio
	malha.height = raio * 2.0
	malha.radial_segments = 18
	malha.rings = 10
	return _adicionar_malha(pai, malha, material, deslocamento)


func _adicionar_anel(
	pai: Node3D, raio: float, material: Material, rotacao: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var malha := TorusMesh.new()
	malha.inner_radius = raio - 0.022
	malha.outer_radius = raio
	malha.rings = 28
	malha.ring_segments = 7
	var instancia := _adicionar_malha(pai, malha, material)
	instancia.rotation_degrees = rotacao
	return instancia


func _criar_geometria_3d() -> Node3D:
	var raiz := Node3D.new()
	var escala := 1.24 if _pesado else 1.0
	var principal := _material_energia(_cor, 3.7 if _pesado else 2.7)
	var brilho := _material_energia(_cor.lightened(0.42), 5.2, 0.82)

	if _familia in ["beam", "breath", "gust", "lightning", "spear", "shard", "torpedo"]:
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.025 if _familia in ["spear", "shard"] else 0.08
		cilindro.bottom_radius = 0.16 if _familia == "breath" else 0.075
		cilindro.height = (0.96 if _familia in ["beam", "breath", "gust"] else 0.66) * escala
		cilindro.radial_segments = 16
		var corpo := _adicionar_malha(raiz, cilindro, principal)
		corpo.rotation_degrees.x = 90.0
	elif _familia in ["slash", "claw", "maw"]:
		var quantidade := 3 if _familia != "slash" else 2
		for indice in range(quantidade):
			var lamina := BoxMesh.new()
			lamina.size = Vector3(0.045, 0.68 * escala, 0.18)
			var no := _adicionar_malha(raiz, lamina, principal, Vector3((indice - 1) * 0.12, 0.0, 0.0))
			no.rotation_degrees = Vector3(18.0, 0.0, 48.0 + indice * 7.0)
	elif _familia in ["ring", "field", "sigil", "wall", "shell", "prison", "net", "chains"]:
		for indice in range(3):
			_adicionar_anel(raiz, (0.20 + indice * 0.065) * escala, principal, Vector3(90.0, indice * 42.0, 0.0))
	elif _familia in ["whip", "coil", "root", "spiral", "tornado", "vortex"]:
		for indice in range(7):
			var angulo := float(indice) * 1.35
			_adicionar_esfera(
				raiz, (0.066 + indice * 0.006) * escala, principal,
				Vector3(cos(angulo) * 0.13, sin(angulo) * 0.13, -indice * 0.10)
			)
		_adicionar_anel(raiz, 0.25 * escala, brilho, Vector3(90.0, 0.0, 0.0))
	elif _familia in ["ground_wave", "fissure", "pillar", "eruption", "caldera", "forest", "fossil", "mycelium", "water_throne", "monolith", "meteor"]:
		for indice in range(5 if _pesado else 3):
			var fragmento := BoxMesh.new()
			fragmento.size = Vector3(0.12, 0.20 + indice * 0.035, 0.12) * escala
			var no := _adicionar_malha(raiz, fragmento, principal, Vector3((indice - 2) * 0.11, sin(indice) * 0.07, -indice * 0.07))
			no.rotation = Vector3(indice * 0.42, indice * 0.73, indice * 0.31)
	else:
		_adicionar_esfera(raiz, 0.18 * escala, principal)
		_adicionar_anel(raiz, 0.25 * escala, brilho, Vector3(90.0, 0.0, 0.0))

	var luz := OmniLight3D.new()
	luz.light_color = _cor
	luz.light_energy = 2.1 if _pesado else 1.25
	luz.omni_range = 2.6 if _pesado else 1.8
	luz.shadow_enabled = false
	raiz.add_child(luz)
	return raiz


func _criar_impacto_3d() -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	var material := _material_energia(_cor, 4.8 if _pesado else 3.4)
	var tamanho := 1.35 if _pesado else 1.0
	if _familia in ["ground_wave", "fissure", "pillar", "eruption", "caldera", "root"] or _reacao in ["crater", "earthquake", "lava_crack", "forest_rise"]:
		for indice in range(7 if _pesado else 5):
			var angulo := TAU * float(indice) / float(7 if _pesado else 5)
			var estilhaco := BoxMesh.new()
			estilhaco.size = Vector3(0.11, 0.48, 0.12) * tamanho
			var no := _adicionar_malha(raiz, estilhaco, material, Vector3(cos(angulo) * 0.38, -0.20, sin(angulo) * 0.38))
			no.rotation_degrees = Vector3(18.0, rad_to_deg(angulo), 14.0)
	elif _familia in ["prison", "net", "chains", "field", "sigil"]:
		for indice in range(4):
			_adicionar_anel(raiz, (0.32 + indice * 0.09) * tamanho, material, Vector3(indice * 42.0, indice * 31.0, 0.0))
	else:
		_adicionar_esfera(raiz, 0.30 * tamanho, material)
		_adicionar_anel(raiz, 0.45 * tamanho, material, Vector3(90.0, 0.0, 0.0))
	raiz.scale = Vector3.ONE * 0.18
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(raiz, "scale", Vector3.ONE * tamanho, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(raiz, "rotation:y", PI * 1.6, 0.48)
	tween.chain().tween_property(raiz, "scale", Vector3.ZERO, 0.24)

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
