class_name ElementPower3D
extends Node3D

## O poder viajando pela arena.
##
## Substitui o projetil antigo. A trajetoria, a geometria por familia de
## golpe, o rastro e a explosao continuam iguais — aquilo ja estava certo. O
## que muda e COMO a arte do golpe aparece.
##
## Antes: um `AnimatedSprite3D` com a tira de `assets/moves_fx/` em mistura
## normal e `modulate = cor`. Mistura normal significa que o preto da tira
## PINTA de preto o que esta atras, entao o poder chegava como um decalque
## opaco grudado na frente da Beast — a "textura grossa".
##
## Agora a tira entra num quadrilatero com mistura ADITIVA. Em aditivo o
## preto nao pinta nada (soma zero) e o claro acende: o que sobra na tela e
## so a luz do desenho. E o mesmo desenho, lido como energia. Sobre ele vao
## duas camadas de luz — nucleo e halo — que dao a borda definida e o miolo
## quente que faltavam.
##
## O quadro da tira NAO e trocado por `frame`: e o retangulo de UV que
## desliza, num relogio fixo. Assim a passada de quadros do poder e a mesma
## a 60 e a 144 fps.

signal impacto_alcancado

## Passada de quadros da tira do golpe, em quadros por segundo.
const FPS_DA_TIRA := 18.0
const FPS_DA_TIRA_PESADO := 12.0

var _cor := Color.WHITE
var _pesado := false
var _quadros := 1
var _quadro := 0
var _fps := FPS_DA_TIRA
var _relogio := 0.0

var _familia := "orb"
var _viagem := "direct"
var _reacao := "energy"

var _placa: MeshInstance3D
var _material_placa: StandardMaterial3D
var _nucleo: MeshInstance3D
var _halo: MeshInstance3D
var _geometria: Node3D
var _rastro: GPUParticles3D
var _explosao: GPUParticles3D
var _tween: Tween
var _viajando := false


func _ready() -> void:
	set_process(true)


## Clarao do golpe SOBRE o alvo, no momento do contato.
##
## E a mesma tira de `assets/moves_fx/`, tambem em mistura aditiva, tocada
## uma vez em cima da Beast atingida. Antes isto era um `Sprite3D` fixo com
## mistura normal que a batalha mantinha vivo o combate inteiro; virava um
## decalque escuro colado na frente da Beast e precisava ser escondido a
## mao. Agora nasce no impacto, toca e se apaga sozinho.
## `pai` e o no que hospeda o mundo 3D — na batalha e o proprio SubViewport,
## que e Viewport e nao Node3D. Por isso o tipo aqui e Node.
static func clarao_de_impacto(
	pai: Node,
	posicao: Vector3,
	textura: Texture2D,
	cor: Color,
	pesado: bool
) -> void:
	if pai == null or textura == null or not is_instance_valid(pai):
		return

	var tamanho := textura.get_size()
	var quadros := maxi(1, roundi(tamanho.x / maxf(1.0, tamanho.y)))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = textura
	material.albedo_color = Color(cor.r, cor.g, cor.b, 1.0)
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = 3.2 if pesado else 2.3
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = true
	material.render_priority = 14
	material.uv1_scale = Vector3(1.0 / float(quadros), 1.0, 1.0)

	var lado := 2.20 if pesado else 1.70
	var quad := QuadMesh.new()
	quad.size = Vector2(lado, lado)

	var placa := MeshInstance3D.new()
	placa.mesh = quad
	placa.material_override = material
	placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(placa)
	placa.global_position = posicao

	var duracao := 0.055 * float(quadros)
	var t := pai.create_tween()
	t.tween_method(
		func(valor: float) -> void:
			if is_instance_valid(material):
				var quadro := clampi(int(valor), 0, quadros - 1)
				material.uv1_offset = Vector3(float(quadro) / float(quadros), 0.0, 0.0),
		0.0,
		float(quadros),
		duracao
	)
	t.parallel().tween_property(placa, "scale", Vector3.ONE * 1.35, duracao)
	t.tween_property(material, "albedo_color:a", 0.0, 0.14)
	t.tween_callback(placa.queue_free)


## Dispara o poder da Beast atacante ate a Beast alvo.
##
## `textura` e a tira horizontal de `assets/moves_fx/<move_id>.png`: quadros
## quadrados lado a lado, entao a contagem sai de largura/altura.
func disparar(
	viewport: Viewport,
	origem: Vector3,
	destino: Vector3,
	textura: Texture2D,
	cor: Color,
	pesado: bool,
	golpe: Dictionary = {}
) -> void:
	_cor = cor
	_pesado = pesado
	_familia = str(golpe.get("effect_family", "orb"))
	_viagem = str(golpe.get("travel_style", "direct"))
	_reacao = str(golpe.get("scene_reaction", "energy"))
	_fps = FPS_DA_TIRA_PESADO if pesado else FPS_DA_TIRA
	position = origem

	var tamanho := textura.get_size()
	_quadros = maxi(1, roundi(tamanho.x / maxf(1.0, tamanho.y)))

	viewport.add_child(self)

	_montar_halo()
	_montar_placa(textura, tamanho)
	_montar_nucleo()

	_geometria = _criar_geometria()
	add_child(_geometria)

	_rastro = _criar_rastro()
	add_child(_rastro)

	_viajando = true
	_voar(origem, destino)


## A tira do golpe, em mistura aditiva.
##
## O quadrilatero e orientado pela camera (billboard) — para um efeito de
## luz isso e correto: fogo e raio nao tem "costas". Quem NAO pode ser
## billboard e a Beast, que precisa da perspectiva.
func _montar_placa(textura: Texture2D, tamanho: Vector2) -> void:
	_material_placa = StandardMaterial3D.new()
	_material_placa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_placa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	## Aditivo: o escuro da tira nao apaga o cenario, so o claro acende.
	_material_placa.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material_placa.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_placa.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material_placa.albedo_texture = textura
	_material_placa.albedo_color = Color(_cor.r, _cor.g, _cor.b, 1.0)
	_material_placa.emission_enabled = true
	_material_placa.emission = _cor
	_material_placa.emission_energy_multiplier = 2.6 if _pesado else 1.9
	_material_placa.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	## Nao escreve profundidade: energia nao recorta energia. Continua com
	## teste de profundidade ligado, entao a Beast a esconde quando passa na
	## frente dela.
	_material_placa.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material_placa.no_depth_test = false
	_material_placa.render_priority = 10

	## Recorta um quadro da tira pela UV, nao pela textura: trocar de quadro
	## fica sendo so mover um offset.
	_material_placa.uv1_scale = Vector3(1.0 / float(_quadros), 1.0, 1.0)
	_material_placa.uv1_offset = Vector3.ZERO

	var lado := (tamanho.y / maxf(1.0, tamanho.y)) * (1.55 if _pesado else 1.20)
	var quad := QuadMesh.new()
	quad.size = Vector2(lado, lado)

	_placa = MeshInstance3D.new()
	_placa.mesh = quad
	_placa.material_override = _material_placa
	_placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_placa)


## Miolo quente. Um disco pequeno, quase branco, que da o "centro" do poder
## — sem ele a tira aditiva fica difusa e o golpe parece fumaça.
func _montar_nucleo() -> void:
	var material := _material_de_energia(_cor.lightened(0.62), 6.4, 0.95)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30) * (1.35 if _pesado else 1.0)

	_nucleo = MeshInstance3D.new()
	_nucleo.mesh = quad
	_nucleo.material_override = material
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nucleo)


## Halo externo: define a silhueta do poder contra o fundo da arena. E a
## camada que faz o golpe ter BORDA em vez de derreter no cenario.
func _montar_halo() -> void:
	var material := _material_de_energia(_cor, 1.5, 0.34)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.92, 0.92) * (1.45 if _pesado else 1.0)

	_halo = MeshInstance3D.new()
	_halo.mesh = quad
	_halo.material_override = material
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)


func _process(delta: float) -> void:
	if not _viajando:
		return

	## Passada de quadros da tira em relogio fixo.
	if _quadros > 1 and _material_placa != null:
		_relogio += minf(delta, 0.25)
		var intervalo := 1.0 / _fps
		while _relogio >= intervalo:
			_relogio -= intervalo
			_quadro = (_quadro + 1) % _quadros
			_material_placa.uv1_offset = Vector3(
				float(_quadro) / float(_quadros), 0.0, 0.0
			)

	## Respiro do nucleo e do halo. O poder pulsa enquanto viaja em vez de
	## atravessar a arena como um adesivo rigido.
	var pulso := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.10
	if _nucleo != null:
		_nucleo.scale = Vector3.ONE * pulso
	if _halo != null:
		_halo.scale = Vector3.ONE * (2.0 - pulso)


func _voar(origem: Vector3, destino: Vector3) -> void:
	var duracao := _duracao_da_viagem()
	var altura_do_arco := 0.85 if _pesado else 0.55
	var desvio := -0.28 if origem.x < destino.x else 0.28

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(
		_posicionar.bind(origem, destino, altura_do_arco * 0.3, desvio * 0.5),
		0.0, 0.25, duracao * 0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(
		_posicionar.bind(origem, destino, altura_do_arco, desvio),
		0.25, 1.0, duracao * 0.75
	)
	_tween.tween_callback(_explodir.bind(destino))
	_tween.tween_interval(0.08)
	_tween.tween_callback(_finalizar)


func _posicionar(
	progresso: float, origem: Vector3, destino: Vector3, altura: float, desvio: float
) -> void:
	if not is_instance_valid(self):
		return
	var ponto := origem.lerp(destino, progresso)
	var arco := sin(progresso * PI)
	match _viagem:
		"ground", "seeking_ground":
			var piso := 0.16
			if progresso < 0.18:
				ponto.y = lerpf(origem.y, piso, progresso / 0.18)
			elif progresso > 0.82:
				ponto.y = lerpf(piso, destino.y, (progresso - 0.82) / 0.18)
			else:
				ponto.y = piso + sin(progresso * PI * 7.0) * 0.035
		"overhead":
			ponto.y += arco * (2.55 if _pesado else 1.90)
			ponto.x += sin(progresso * TAU) * 0.18
		"zigzag":
			ponto.x += sin(progresso * PI * 10.0) * 0.22
			ponto.y += sin(progresso * PI * 7.0) * 0.12
		"spiral":
			ponto.x += sin(progresso * TAU * 2.2) * (1.0 - progresso) * 0.48
			ponto.y += cos(progresso * TAU * 2.2) * (1.0 - progresso) * 0.32 + arco * 0.25
		"wave":
			ponto.y += sin(progresso * PI * 4.0) * 0.18 + arco * 0.15
		"dive":
			ponto.y += arco * 1.45
			ponto.x += arco * desvio
		"drift", "sweeping":
			ponto.x += sin(progresso * PI * 3.0) * desvio
			ponto.y += arco * 0.30
		_:
			ponto.y += arco * altura
			ponto.x += arco * desvio
	position = ponto

	## O poder cresce ao se aproximar do alvo: aproximacao lida como
	## aceleracao, nao como um objeto de tamanho fixo deslizando.
	var ganho := 1.0 + progresso * (0.42 if _pesado else 0.26)
	if _placa != null:
		_placa.scale = Vector3.ONE * ganho
	if _geometria != null:
		_geometria.rotation.z += get_process_delta_time() * (5.0 if _pesado else 7.0)
		_geometria.scale = Vector3.ONE * (1.0 + sin(progresso * PI * 5.0) * 0.08)


func _explodir(destino: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_viajando = false
	if _placa != null:
		_placa.visible = false
	if _nucleo != null:
		_nucleo.visible = false
	if _halo != null:
		_halo.visible = false
	if _geometria != null:
		_geometria.visible = false
	if _rastro != null:
		_rastro.emitting = false

	_explosao = _criar_explosao()
	add_child(_explosao)
	_explosao.global_position = destino
	_explosao.emitting = true
	_criar_impacto()

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


func _material_de_energia(
	cor: Color, energia: float, alpha: float = 0.88
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
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


## Corpo tridimensional do golpe, escolhido pela familia do efeito. E o que
## da VOLUME ao poder: a tira sozinha continuaria sendo um plano.
func _criar_geometria() -> Node3D:
	var raiz := Node3D.new()
	var escala := 1.24 if _pesado else 1.0
	var principal := _material_de_energia(_cor, 3.7 if _pesado else 2.7)
	var brilho := _material_de_energia(_cor.lightened(0.42), 5.2, 0.82)

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
			var no := _adicionar_malha(
				raiz, lamina, principal, Vector3((indice - 1) * 0.12, 0.0, 0.0)
			)
			no.rotation_degrees = Vector3(18.0, 0.0, 48.0 + indice * 7.0)
	elif _familia in ["ring", "field", "sigil", "wall", "shell", "prison", "net", "chains"]:
		for indice in range(3):
			_adicionar_anel(
				raiz, (0.20 + indice * 0.065) * escala, principal,
				Vector3(90.0, indice * 42.0, 0.0)
			)
	elif _familia in ["whip", "coil", "root", "spiral", "tornado", "vortex"]:
		for indice in range(7):
			var angulo := float(indice) * 1.35
			_adicionar_esfera(
				raiz, (0.066 + indice * 0.006) * escala, principal,
				Vector3(cos(angulo) * 0.13, sin(angulo) * 0.13, -indice * 0.10)
			)
		_adicionar_anel(raiz, 0.25 * escala, brilho, Vector3(90.0, 0.0, 0.0))
	elif _familia in [
		"ground_wave", "fissure", "pillar", "eruption", "caldera", "forest",
		"fossil", "mycelium", "water_throne", "monolith", "meteor"
	]:
		for indice in range(5 if _pesado else 3):
			var fragmento := BoxMesh.new()
			fragmento.size = Vector3(0.12, 0.20 + indice * 0.035, 0.12) * escala
			var no := _adicionar_malha(
				raiz, fragmento, principal,
				Vector3((indice - 2) * 0.11, sin(indice) * 0.07, -indice * 0.07)
			)
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


func _criar_impacto() -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	var material := _material_de_energia(_cor, 4.8 if _pesado else 3.4)
	var tamanho := 1.35 if _pesado else 1.0

	if _familia in ["ground_wave", "fissure", "pillar", "eruption", "caldera", "root"] \
			or _reacao in ["crater", "earthquake", "lava_crack", "forest_rise"]:
		var pontas := 7 if _pesado else 5
		for indice in range(pontas):
			var angulo := TAU * float(indice) / float(pontas)
			var estilhaco := BoxMesh.new()
			estilhaco.size = Vector3(0.11, 0.48, 0.12) * tamanho
			var no := _adicionar_malha(
				raiz, estilhaco, material,
				Vector3(cos(angulo) * 0.38, -0.20, sin(angulo) * 0.38)
			)
			no.rotation_degrees = Vector3(18.0, rad_to_deg(angulo), 14.0)
	elif _familia in ["prison", "net", "chains", "field", "sigil"]:
		for indice in range(4):
			_adicionar_anel(
				raiz, (0.32 + indice * 0.09) * tamanho, material,
				Vector3(indice * 42.0, indice * 31.0, 0.0)
			)
	else:
		_adicionar_esfera(raiz, 0.30 * tamanho, material)
		_adicionar_anel(raiz, 0.45 * tamanho, material, Vector3(90.0, 0.0, 0.0))

	raiz.scale = Vector3.ONE * 0.18
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(raiz, "scale", Vector3.ONE * tamanho, 0.22).set_trans(Tween.TRANS_BACK)
	t.tween_property(raiz, "rotation:y", PI * 1.6, 0.48)
	t.chain().tween_property(raiz, "scale", Vector3.ZERO, 0.24)


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
	p.material_override = _material_de_energia(_cor, 2.2, 0.85)
	(p.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.08
	m.direction = Vector3.ZERO
	m.spread = 180.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.4
	m.gravity = Vector3.ZERO
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
	p.material_override = _material_de_energia(Color.WHITE, 3.0, 0.95)
	(p.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 180.0
	m.initial_velocity_min = 2.5 if _pesado else 1.8
	m.initial_velocity_max = 5.5 if _pesado else 3.5
	m.gravity = Vector3(0.0, -3.0, 0.0)
	m.damping_min = 3.0
	m.damping_max = 6.0
	m.scale_min = 0.5
	m.scale_max = 1.5

	var gradiente := Gradient.new()
	gradiente.set_color(0, _cor)
	gradiente.set_color(1, Color(_cor.r * 0.3, _cor.g * 0.3, _cor.b * 0.3, 0.0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = gradiente
	m.color_ramp = rampa

	p.process_material = m
	return p
