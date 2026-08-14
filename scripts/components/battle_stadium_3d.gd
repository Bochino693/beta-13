class_name BattleStadium3D
extends Node3D

## Estadio 3D estavel para a batalha em retrato.
## A geometria e o horizonte nao se movem; apenas LEDs e publico pulsam de leve.

const SEGMENTOS_ARQUIBANCADA := 18
const PUBLICO_POR_ANEL := 32
const VARIANTE_COLISEU := "coliseu"
const VARIANTE_FORJA := "forja"
const VARIANTE_CELESTE := "celeste"
const VARIANTE_ETER := "eter"
const VARIANTE_OBSIDIANA := "obsidiana"
const FUNDOS: Dictionary = {
	VARIANTE_COLISEU: "res://assets/battle/arena/lazer_coliseum_backplate.png",
	VARIANTE_FORJA: "res://assets/battle/arena/obsidian_forge_backplate.png",
	VARIANTE_CELESTE: "res://assets/battle/arena/sky_temple_backplate.png",
	VARIANTE_ETER: "res://assets/battle/arena/aether_sanctum_backplate.png",
	VARIANTE_OBSIDIANA: "res://assets/battle/arena/obsidian_foundry_backplate.png",
}
const CODIGO_PISO := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;
uniform vec3 cor_base : source_color = vec3(0.016, 0.025, 0.070);
uniform vec3 cor_primaria : source_color = vec3(0.20, 0.64, 1.00);
uniform vec3 cor_acento : source_color = vec3(0.75, 0.22, 1.00);
uniform vec3 cor_borda : source_color = vec3(0.05, 0.14, 0.30);
void fragment() {
	vec2 p = UV - vec2(0.5);
	float raio = length(p);
	float limite = 1.0 - smoothstep(0.38, 0.385, abs(raio - 0.315));
	float anel_interno = 1.0 - smoothstep(0.18, 0.185, abs(raio - 0.145));
	float eixo = 1.0 - smoothstep(0.002, 0.006, abs(p.x));
	float vinheta = smoothstep(0.64, 0.06, raio);
	float borda = smoothstep(0.39, 0.48, raio) * (1.0 - smoothstep(0.48, 0.50, raio));
	ALBEDO = cor_base + cor_primaria * (limite * 0.32 + eixo * 0.08) * vinheta;
	ALBEDO += cor_acento * (anel_interno * 0.24 + vinheta * 0.055);
	ALBEDO += cor_borda * borda * 0.72;
	ALPHA = 1.0;
}
"""

var _leds: Array[StandardMaterial3D] = []
var _publico: Array[StandardMaterial3D] = []
var _marcadores: Array = [[], []]
var _holofotes: Array[SpotLight3D] = []
var _tempo := 0.0
var _pulso_impacto := 1.0
var _cor_p1 := Color("6ef8ff")
var _cor_p2 := Color("ff55c6")
var _variante := VARIANTE_COLISEU


func _ready() -> void:
	set_process(true)


static func variante_para_tipos(tipo_p1: String, tipo_p2: String) -> String:
	var tipos := [tipo_p1, tipo_p2]
	if "Fogo" in tipos or "Escuridão" in tipos:
		return VARIANTE_OBSIDIANA
	if "Terra" in tipos or "Natureza" in tipos:
		return VARIANTE_FORJA
	if "Luz" in tipos or "Vento" in tipos:
		return VARIANTE_ETER
	if "Água" in tipos:
		return VARIANTE_CELESTE
	return VARIANTE_COLISEU


func configurar(
	cor_p1: Color,
	cor_p2: Color,
	tipo_p1: String = "",
	tipo_p2: String = ""
) -> void:
	_cor_p1 = cor_p1
	_cor_p2 = cor_p2
	_variante = (
		tipo_p1 if FUNDOS.has(tipo_p1) and tipo_p2.is_empty()
		else variante_para_tipos(tipo_p1, tipo_p2)
	)
	_montar_fundo_cinematografico()
	_montar_piso()
	_montar_arquibancadas()
	_montar_publico()
	_montar_luzes()
	_montar_estrutura_aerea()
	_montar_faixas()


func _montar_fundo_cinematografico() -> void:
	var caminho: String = str(FUNDOS[_variante])
	if not ResourceLoader.exists(caminho):
		return
	var fundo := Sprite3D.new()
	fundo.texture = load(caminho) as Texture2D
	fundo.centered = true
	fundo.shaded = false
	fundo.transparent = false
	fundo.no_depth_test = false
	fundo.render_priority = -8
	fundo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# A arena ocupa uma faixa horizontal; recortamos o miolo do concept vertical.
	fundo.region_enabled = true
	var recorte_y := 160.0 if _variante != VARIANTE_COLISEU else 205.0
	fundo.region_rect = Rect2(0.0, recorte_y, 941.0, 790.0)
	fundo.pixel_size = 0.026
	fundo.position = Vector3(0.0, 5.45, -17.0)
	fundo.modulate = (
		Color(0.90, 0.94, 1.0)
		if _variante in [VARIANTE_CELESTE, VARIANTE_ETER]
		else Color(0.84, 0.86, 0.94)
	)
	add_child(fundo)


func _process(delta: float) -> void:
	_tempo += delta
	_pulso_impacto = move_toward(_pulso_impacto, 1.0, delta * 5.0)
	# Movimento ambiental limitado a emissao. Nada altera posicao/horizonte.
	for indice in range(_leds.size()):
		var material: StandardMaterial3D = _leds[indice]
		var pulso := 1.45 + sin(_tempo * 1.35 + float(indice) * 0.72) * 0.30
		pulso *= _pulso_impacto
		material.emission_energy_multiplier = pulso
	for indice in range(_publico.size()):
		var material: StandardMaterial3D = _publico[indice]
		var onda := sin(_tempo * 2.15 - float(indice) * 0.19)
		var brilho := (0.72 + onda * 0.24) * _pulso_impacto
		material.emission_energy_multiplier = brilho
	for indice in range(_holofotes.size()):
		var foco := _holofotes[indice]
		var lado := -1.0 if indice == 0 else 1.0
		var alvo := Vector3(
			sin(_tempo * 0.48 + float(indice) * 1.7) * 2.1,
			0.15,
			-2.7 + cos(_tempo * 0.36 + float(indice)) * 1.5
		)
		foco.look_at(alvo, Vector3.UP)
		foco.light_energy = (2.0 + sin(_tempo * 1.2 + lado) * 0.25) * _pulso_impacto


func _montar_piso() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(22.0, 30.0)
	var shader := Shader.new()
	shader.code = CODIGO_PISO
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cor_primaria", Vector3(_cor_p1.r, _cor_p1.g, _cor_p1.b))
	material.set_shader_parameter("cor_acento", Vector3(_cor_p2.r, _cor_p2.g, _cor_p2.b))
	var quente := _variante in [VARIANTE_FORJA, VARIANTE_OBSIDIANA]
	var cor_borda := Color("3d1209") if quente else Color("102a57")
	material.set_shader_parameter("cor_borda", Vector3(cor_borda.r, cor_borda.g, cor_borda.b))
	var piso := MeshInstance3D.new()
	piso.mesh = plano
	piso.material_override = material
	piso.position = Vector3(0.0, -0.04, -5.3)
	piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piso)

	# Plataforma central elevada, dando volume sob as Beasts.
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 5.5
	base_mesh.bottom_radius = 5.9
	base_mesh.height = 0.14
	base_mesh.radial_segments = 64
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.position = Vector3(0.0, -0.09, -3.7)
	base.material_override = _material_metal(Color("111b3c"), Color("2b61a8"), 0.35)
	add_child(base)

	# Três corredores gravados tornam as posições de esquiva imediatamente
	# legíveis sem ocupar a interface. Eles são geometria fixa no piso.
	for jogador in range(2):
		var z := 0.30 if jogador == 0 else -4.35
		var cor := _cor_p1 if jogador == 0 else _cor_p2
		for faixa in range(-1, 2):
			var trilho_mesh := BoxMesh.new()
			trilho_mesh.size = Vector3(0.035, 0.012, 1.05)
			var trilho := MeshInstance3D.new()
			trilho.mesh = trilho_mesh
			trilho.position = Vector3(_x_da_faixa(jogador, faixa), 0.012, z)
			trilho.material_override = _material_emissivo(Color(cor, 0.46), 0.38)
			add_child(trilho)


func _montar_arquibancadas() -> void:
	for nivel in range(3):
		var raio := 7.0 + float(nivel) * 1.15
		var altura := 0.55 + float(nivel) * 0.55
		for indice in range(SEGMENTOS_ARQUIBANCADA):
			var angulo := lerpf(-2.72, -0.42, float(indice) / float(SEGMENTOS_ARQUIBANCADA - 1))
			var bloco_mesh := BoxMesh.new()
			bloco_mesh.size = Vector3(1.15, 0.42, 1.35)
			var bloco := MeshInstance3D.new()
			bloco.mesh = bloco_mesh
			bloco.position = Vector3(cos(angulo) * raio, altura, sin(angulo) * raio - 2.5)
			bloco.rotation_degrees.y = -rad_to_deg(angulo) - 90.0
			bloco.material_override = _material_metal(
				Color("10152d").lightened(float(nivel) * 0.035),
				_cor_p1 if indice % 2 == 0 else _cor_p2,
				0.09
			)
			add_child(bloco)

	# Fita LED curva sugerida por segmentos, estavel e sem textura rolando.
	for indice in range(SEGMENTOS_ARQUIBANCADA):
		var angulo := lerpf(-2.72, -0.42, float(indice) / float(SEGMENTOS_ARQUIBANCADA - 1))
		var fita_mesh := BoxMesh.new()
		fita_mesh.size = Vector3(1.16, 0.08, 0.09)
		var fita := MeshInstance3D.new()
		fita.mesh = fita_mesh
		fita.position = Vector3(cos(angulo) * 6.72, 1.42, sin(angulo) * 6.72 - 2.5)
		fita.rotation_degrees.y = -rad_to_deg(angulo) - 90.0
		var cor := _cor_p1 if indice < SEGMENTOS_ARQUIBANCADA / 2.0 else _cor_p2
		var led := _material_emissivo(cor, 1.6)
		fita.material_override = led
		_leds.append(led)
		add_child(fita)


func _montar_publico() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 0.045
	esfera.height = 0.09
	esfera.radial_segments = 8
	esfera.rings = 4
	for anel in range(3):
		var raio := 7.0 + float(anel) * 1.15
		for indice in range(PUBLICO_POR_ANEL):
			var t := float(indice) / float(PUBLICO_POR_ANEL - 1)
			var angulo := lerpf(-2.70, -0.45, t)
			var pessoa := MeshInstance3D.new()
			pessoa.mesh = esfera
			pessoa.position = Vector3(
				cos(angulo) * raio,
				0.88 + float(anel) * 0.55 + sin(float(indice) * 2.1) * 0.05,
				sin(angulo) * raio - 2.5
			)
			var cor := _cor_p1.lerp(_cor_p2, fmod(float(indice * 7 + anel * 3), 17.0) / 16.0)
			var material := _material_emissivo(cor, 1.15)
			pessoa.material_override = material
			_publico.append(material)
			add_child(pessoa)


func _montar_luzes() -> void:
	for lado in [-1.0, 1.0]:
		var poste_mesh := CylinderMesh.new()
		poste_mesh.top_radius = 0.05
		poste_mesh.bottom_radius = 0.08
		poste_mesh.height = 4.8
		var poste := MeshInstance3D.new()
		poste.mesh = poste_mesh
		poste.position = Vector3(lado * 5.7, 2.35, -7.8)
		poste.material_override = _material_metal(Color("182139"), Color("4c6da8"), 0.15)
		add_child(poste)

		var holofote := SpotLight3D.new()
		holofote.light_color = _cor_p1 if lado < 0.0 else _cor_p2
		holofote.light_energy = 2.0
		holofote.spot_range = 14.0
		holofote.spot_angle = 32.0
		holofote.position = Vector3(lado * 5.7, 4.65, -7.8)
		holofote.rotation_degrees = Vector3(-62.0, 0.0, -24.0 * lado)
		holofote.shadow_enabled = false
		add_child(holofote)
		_holofotes.append(holofote)


func _montar_estrutura_aerea() -> void:
	# Arco superior e totens laterais dão profundidade sem uma imagem de fundo móvel.
	var arco_mesh := TorusMesh.new()
	arco_mesh.inner_radius = 6.65
	arco_mesh.outer_radius = 6.78
	arco_mesh.rings = 72
	arco_mesh.ring_segments = 10
	var arco := MeshInstance3D.new()
	arco.mesh = arco_mesh
	arco.position = Vector3(0.0, 4.85, -6.1)
	arco.rotation_degrees.x = 78.0
	var material_arco := _material_emissivo(_cor_p1.lerp(_cor_p2, 0.5), 0.75)
	arco.material_override = material_arco
	_leds.append(material_arco)
	add_child(arco)

	for lado in [-1.0, 1.0]:
		var corpo_mesh := BoxMesh.new()
		corpo_mesh.size = Vector3(0.34, 3.6, 0.28)
		var totem := MeshInstance3D.new()
		totem.mesh = corpo_mesh
		totem.position = Vector3(lado * 5.05, 2.0, -5.7)
		var cor := _cor_p1 if lado < 0.0 else _cor_p2
		totem.material_override = _material_metal(Color("111a36"), cor, 0.52)
		add_child(totem)

		for faixa_led in range(5):
			var led_mesh := BoxMesh.new()
			led_mesh.size = Vector3(0.39, 0.08, 0.31)
			var led := MeshInstance3D.new()
			led.mesh = led_mesh
			led.position = Vector3(
				lado * 5.05,
				0.65 + float(faixa_led) * 0.68,
				-5.54
			)
			var material := _material_emissivo(cor, 1.35)
			led.material_override = material
			_leds.append(material)
			add_child(led)


func _montar_faixas() -> void:
	for jogador in range(2):
		var z := 0.30 if jogador == 0 else -4.35
		var cor := _cor_p1 if jogador == 0 else _cor_p2
		for faixa in range(-1, 2):
			var anel_mesh := TorusMesh.new()
			anel_mesh.inner_radius = 0.36
			anel_mesh.outer_radius = 0.42
			anel_mesh.rings = 24
			anel_mesh.ring_segments = 10
			var anel := MeshInstance3D.new()
			anel.mesh = anel_mesh
			anel.position = Vector3(_x_da_faixa(jogador, faixa), 0.015, z)
			anel.scale = Vector3(1.35, 0.55, 1.0)
			anel.material_override = _material_emissivo(cor, 0.42)
			add_child(anel)
			(_marcadores[jogador] as Array).append(anel)
	definir_faixa(0, 0)
	definir_faixa(1, 0)


func _x_da_faixa(jogador: int, faixa: int) -> float:
	var centro := -1.32 if jogador == 0 else 1.18
	var passo := 0.56 if jogador == 0 else 0.48
	return centro + float(faixa) * passo


func impacto(cor: Color, forca: float = 1.0) -> void:
	_pulso_impacto = maxf(_pulso_impacto, 1.0 + forca * 1.8)
	for foco in _holofotes:
		foco.light_color = foco.light_color.lerp(cor, 0.72)
	var tween := create_tween()
	tween.tween_interval(0.16)
	tween.tween_callback(_restaurar_cores_de_luz)


func _restaurar_cores_de_luz() -> void:
	if _holofotes.size() >= 2:
		_holofotes[0].light_color = _cor_p1
		_holofotes[1].light_color = _cor_p2


func definir_faixa(jogador: int, faixa: int, ameacada: int = 99) -> void:
	for indice in range(3):
		var anel: MeshInstance3D = (_marcadores[jogador] as Array)[indice]
		var valor_faixa: int = indice - 1
		var material := anel.material_override as StandardMaterial3D
		if valor_faixa == ameacada:
			material.emission = Color("ff405f")
			material.emission_energy_multiplier = 2.8
		elif valor_faixa == faixa:
			material.emission = _cor_p1 if jogador == 0 else _cor_p2
			material.emission_energy_multiplier = 2.1
		else:
			material.emission = Color("314469")
			material.emission_energy_multiplier = 0.28


func _material_emissivo(cor: Color, energia: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = cor
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = energia
	return material


func _material_metal(base: Color, emissao: Color, energia: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.metallic = 0.82
	material.roughness = 0.31
	material.emission_enabled = true
	material.emission = emissao
	material.emission_energy_multiplier = energia
	return material
