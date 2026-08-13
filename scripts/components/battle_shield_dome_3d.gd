class_name BattleShieldDome3D
extends Node3D

## Redoma de guarda: esfera holografica, anel, contador e ruptura no impacto.

const CODIGO_REDOMA := """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;
uniform vec3 cor : source_color = vec3(0.35, 0.84, 1.0);
uniform float tempo = 0.0;
uniform float intensidade = 1.0;
void fragment() {
	float borda = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float linhas = smoothstep(0.82, 1.0, sin((UV.y * 13.0 + tempo * 2.0) * 3.14159) * 0.5 + 0.5);
	float energia = borda * 0.68 + linhas * 0.22;
	ALBEDO = cor;
	EMISSION = cor * (1.4 + energia * 2.0) * intensidade;
	ALPHA = energia * 0.54 * intensidade;
}
"""

var _material: ShaderMaterial
var _anel: MeshInstance3D
var _rotulo: Label3D
var _tempo := 0.0
var _cor := Color("59d7ff")
var _escala_base := Vector3.ONE


func _ready() -> void:
	set_process(true)
	_montar()
	_escala_base = scale


func _process(delta: float) -> void:
	_tempo += delta
	if _material != null:
		_material.set_shader_parameter("tempo", _tempo)
	if _anel != null:
		_anel.rotation_degrees.y += delta * 42.0
		var pulso := 1.0 + sin(_tempo * 4.0) * 0.045
		_anel.scale = Vector3(pulso, pulso, pulso)


func _montar() -> void:
	var esfera_mesh := SphereMesh.new()
	esfera_mesh.radius = 1.22
	esfera_mesh.height = 2.44
	esfera_mesh.radial_segments = 48
	esfera_mesh.rings = 24
	var esfera := MeshInstance3D.new()
	esfera.mesh = esfera_mesh
	var shader := Shader.new()
	shader.code = CODIGO_REDOMA
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("cor", Vector3(_cor.r, _cor.g, _cor.b))
	esfera.material_override = _material
	add_child(esfera)

	var anel_mesh := TorusMesh.new()
	anel_mesh.inner_radius = 1.18
	anel_mesh.outer_radius = 1.24
	anel_mesh.rings = 48
	anel_mesh.ring_segments = 12
	_anel = MeshInstance3D.new()
	_anel.mesh = anel_mesh
	_anel.rotation_degrees.x = 64.0
	_anel.material_override = _material_anel(_cor)
	add_child(_anel)

	_rotulo = Label3D.new()
	_rotulo.text = "GUARDA • 1 IMPACTO"
	_rotulo.font_size = 32
	_rotulo.outline_size = 8
	_rotulo.modulate = Color.WHITE
	_rotulo.outline_modulate = Color(0.01, 0.04, 0.12, 0.96)
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.no_depth_test = true
	_rotulo.position = Vector3(0.0, 1.55, 0.0)
	add_child(_rotulo)


func ativar(cor: Color = Color("59d7ff")) -> void:
	_cor = cor
	visible = true
	_material.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	_material.set_shader_parameter("intensidade", 1.0)
	(_anel.material_override as StandardMaterial3D).emission = cor
	_rotulo.text = "GUARDA • 1 IMPACTO"
	_rotulo.modulate.a = 1.0
	scale = _escala_base * 0.16
	var tween := create_tween()
	tween.tween_property(self, "scale", _escala_base, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func romper() -> void:
	if not visible:
		return
	_rotulo.text = "BLOQUEIO CONSUMIDO"
	var tween := create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(_definir_intensidade, 1.0, 2.8, 0.10)
	tween.tween_property(self, "scale", _escala_base * 1.24, 0.12)
	tween.chain().tween_method(_definir_intensidade, 2.8, 0.0, 0.22)
	tween.parallel().tween_property(self, "scale", _escala_base * 1.55, 0.22)
	tween.parallel().tween_property(_rotulo, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(_ocultar)


func _definir_intensidade(valor: float) -> void:
	if _material != null:
		_material.set_shader_parameter("intensidade", valor)


func _ocultar() -> void:
	visible = false


func _material_anel(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(cor.r, cor.g, cor.b, 0.65)
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = 2.3
	return material
