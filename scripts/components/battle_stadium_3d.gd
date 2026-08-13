class_name BattleStadium3D
extends Node3D

## Estadio 3D estavel para a batalha em retrato.
## A geometria e o horizonte nao se movem; apenas LEDs e publico pulsam de leve.

const SEGMENTOS_ARQUIBANCADA := 18
const PUBLICO_POR_ANEL := 32
const CODIGO_PISO := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;
uniform vec3 cor_base : source_color = vec3(0.016, 0.025, 0.070);
uniform vec3 cor_grade : source_color = vec3(0.20, 0.64, 1.00);
uniform vec3 cor_acento : source_color = vec3(0.75, 0.22, 1.00);
void fragment() {
	vec2 p = UV - vec2(0.5);
	float raio = length(p);
	float circulo = 1.0 - smoothstep(0.32, 0.325, abs(raio - 0.265));
	vec2 grade_uv = fract(UV * vec2(18.0, 24.0));
	float linha_x = 1.0 - smoothstep(0.025, 0.055, min(grade_uv.x, 1.0 - grade_uv.x));
	float linha_y = 1.0 - smoothstep(0.025, 0.055, min(grade_uv.y, 1.0 - grade_uv.y));
	float grade = max(linha_x, linha_y) * smoothstep(0.56, 0.08, raio);
	float centro = smoothstep(0.52, 0.0, raio);
	ALBEDO = cor_base + cor_grade * grade * 0.42;
	ALBEDO += cor_acento * (circulo * 0.38 + centro * 0.11);
	ALPHA = 1.0;
}
"""

var _leds: Array[StandardMaterial3D] = []
var _publico: Array[StandardMaterial3D] = []
var _marcadores: Array = [[], []]
var _tempo := 0.0
var _cor_p1 := Color("6ef8ff")
var _cor_p2 := Color("ff55c6")


func _ready() -> void:
	set_process(true)


func configurar(cor_p1: Color, cor_p2: Color) -> void:
	_cor_p1 = cor_p1
	_cor_p2 = cor_p2
	_montar_piso()
	_montar_arquibancadas()
	_montar_publico()
	_montar_luzes()
	_montar_faixas()


func _process(delta: float) -> void:
	_tempo += delta
	# Movimento ambiental limitado a emissao. Nada altera posicao/horizonte.
	for indice in range(_leds.size()):
		var material: StandardMaterial3D = _leds[indice]
		var pulso := 1.45 + sin(_tempo * 1.35 + float(indice) * 0.72) * 0.30
		material.emission_energy_multiplier = pulso
	for indice in range(_publico.size()):
		var material: StandardMaterial3D = _publico[indice]
		var brilho := 0.72 + sin(_tempo * 1.70 + float(indice) * 0.83) * 0.20
		material.emission_energy_multiplier = brilho


func _montar_piso() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(22.0, 30.0)
	var shader := Shader.new()
	shader.code = CODIGO_PISO
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cor_grade", Vector3(_cor_p1.r, _cor_p1.g, _cor_p1.b))
	material.set_shader_parameter("cor_acento", Vector3(_cor_p2.r, _cor_p2.g, _cor_p2.b))
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


func _montar_faixas() -> void:
	for jogador in range(2):
		var z := 1.28 if jogador == 0 else -4.88
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
	var centro := -0.55 if jogador == 0 else 0.40
	var passo := 0.74 if jogador == 0 else 0.58
	return centro + float(faixa) * passo


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
