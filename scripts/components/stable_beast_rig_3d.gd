class_name StableBeastRig3D
extends Node3D

## Rig 2.5D contínuo que preserva a arte mestre da Beast.
##
## Uma única textura RGBA é aplicada a uma malha subdividida. Respiração,
## asas, flutuação, esquiva e golpes deformam a própria malha; não existem
## atlas, troca de fotografias, crossfade ou alteração de alpha no idle.

signal animacao_terminou(nome: String)

const GRID_SEGMENTS := 24
const UPDATE_INTERVAL := 1.0 / 30.0

const MOTION: Dictionary = {
	"ave": {"rhythm": 3.7, "breathe": 0.020, "sway": 0.020, "wing": 0.082, "hover": 0.060},
	"dragao": {"rhythm": 2.3, "breathe": 0.030, "sway": 0.022, "wing": 0.050, "hover": 0.025},
	"felpudo": {"rhythm": 1.8, "breathe": 0.042, "sway": 0.016, "wing": 0.010, "hover": 0.004},
	"reptil": {"rhythm": 1.5, "breathe": 0.027, "sway": 0.012, "wing": 0.007, "hover": 0.002},
	"planta": {"rhythm": 1.2, "breathe": 0.035, "sway": 0.030, "wing": 0.014, "hover": 0.006},
	"mineral": {"rhythm": 0.9, "breathe": 0.013, "sway": 0.006, "wing": 0.003, "hover": 0.001},
	"aquatico": {"rhythm": 2.1, "breathe": 0.030, "sway": 0.042, "wing": 0.025, "hover": 0.070},
	"espectro": {"rhythm": 2.8, "breathe": 0.043, "sway": 0.044, "wing": 0.029, "hover": 0.088},
	"padrao": {"rhythm": 1.8, "breathe": 0.030, "sway": 0.018, "wing": 0.013, "hover": 0.010},
}

const FAMILY_BY_ID: Dictionary = {
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

const LOCOMOTION_BY_ID: Dictionary = {
	"lumari": "voador", "prismara": "voador", "nocturna": "voador",
	"abissarca": "voador", "pyrocondor": "voador", "arcdrake": "voador",
	"monolito": "voador", "brispulo": "voador", "nimbaleia": "voador",
	"tempestral": "voador", "raiarraia": "aquatico", "medulux": "aquatico",
	"torpescama": "aquatico", "marevante": "aquatico",
}

var _id_beast := ""
var _family := "padrao"
var _locomotion := "terrestre"
var _back_view := false
var _height := 2.5
var _element_color := Color("6ef8ff")
var _prepared_move: Dictionary = {}

var _body: Node3D
var _visual: MeshInstance3D
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _outer_ring: MeshInstance3D
var _inner_ring: MeshInstance3D
var _light: OmniLight3D

var _base_vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _active_tween: Tween
var _time := 0.0
var _deform_accumulator := 0.0
var _busy := false
var _heavy_pending := false
var _action_value := 0.0
var _charge_value := 0.0
var _flash_value := 0.0
var _presence_boost := 1.0


func _ready() -> void:
	_time = randf() * 8.0
	set_process(true)


static func familia_de(data: Dictionary) -> String:
	var explicit := str(data.get("familia_anim", ""))
	if MOTION.has(explicit):
		return explicit
	return str(FAMILY_BY_ID.get(str(data.get("id", "")), "padrao"))


static func locomocao_de(data: Dictionary) -> String:
	return str(LOCOMOTION_BY_ID.get(str(data.get("id", "")), "terrestre"))


func configurar(
	id_beast: String,
	height_world: float,
	family: String,
	locomotion: String,
	back_view: bool,
	element_color: Color
) -> bool:
	var path := "res://assets/creatures_hd/%s.png" % id_beast
	if not ResourceLoader.exists(path):
		push_error("StableBeastRig3D: arte mestre ausente: " + path)
		return false
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("StableBeastRig3D: textura invalida: " + path)
		return false

	_id_beast = id_beast
	_height = height_world
	_family = family if MOTION.has(family) else "padrao"
	_locomotion = locomotion if locomotion in ["voador", "terrestre", "aquatico"] else "terrestre"
	_back_view = back_view
	_element_color = element_color

	_body = Node3D.new()
	add_child(_body)
	var aspect := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
	_mesh = _build_grid_mesh(height_world, aspect)
	_material = _create_material(texture)
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.material_override = _material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_visual)
	_create_presence()
	return true


func _build_grid_mesh(height_world: float, aspect: float) -> ArrayMesh:
	_base_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_uvs = PackedVector2Array()
	_indices = PackedInt32Array()
	var width := height_world * aspect
	for row in range(GRID_SEGMENTS + 1):
		var v := float(row) / float(GRID_SEGMENTS)
		for column in range(GRID_SEGMENTS + 1):
			var u := float(column) / float(GRID_SEGMENTS)
			_base_vertices.append(Vector3((u - 0.5) * width, (1.0 - v) * height_world, 0.0))
			_normals.append(Vector3(0.0, 0.0, 1.0))
			_uvs.append(Vector2(1.0 - u if _back_view else u, v))
	for row in range(GRID_SEGMENTS):
		for column in range(GRID_SEGMENTS):
			var a := row * (GRID_SEGMENTS + 1) + column
			var b := a + 1
			var c := a + GRID_SEGMENTS + 1
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	return _mesh_from_vertices(_base_vertices)


func _mesh_from_vertices(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _create_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.render_priority = 4
	return material


func _process(delta: float) -> void:
	_time += delta
	_deform_accumulator += delta
	_presence_boost = move_toward(_presence_boost, 1.0, delta * 4.0)
	if _body != null and not _busy:
		var motion: Dictionary = MOTION[_family]
		var rhythm := float(motion["rhythm"])
		if _locomotion == "terrestre":
			_body.position.y = absf(sin(_time * rhythm)) * 0.010
		else:
			_body.position.y = sin(_time * rhythm * 0.72) * maxf(0.035, float(motion["hover"]))
		_body.rotation.z = sin(_time * rhythm * 0.41) * float(motion["sway"]) * 0.42
	if _deform_accumulator >= UPDATE_INTERVAL:
		_deform_accumulator = 0.0
		_update_deformed_mesh()
	_update_presence()


func _update_deformed_mesh() -> void:
	if _mesh == null or _base_vertices.is_empty():
		return
	var motion: Dictionary = (MOTION[_family] as Dictionary).duplicate()
	if _locomotion == "voador":
		motion["wing"] = maxf(float(motion["wing"]), 0.064)
		motion["hover"] = maxf(float(motion["hover"]), 0.055)
	elif _locomotion == "aquatico":
		motion["sway"] = maxf(float(motion["sway"]), 0.042)
	var rhythm := float(motion["rhythm"])
	var breathe := float(motion["breathe"])
	var sway := float(motion["sway"])
	var wing := float(motion["wing"])
	var pulse := sin(_time * rhythm)
	var slow := sin(_time * rhythm * 0.43 + 1.7)
	var vertices := PackedVector3Array()
	vertices.resize(_base_vertices.size())
	for index in range(_base_vertices.size()):
		var row := floori(float(index) / float(GRID_SEGMENTS + 1))
		var column := index % (GRID_SEGMENTS + 1)
		var u := float(column) / float(GRID_SEGMENTS)
		var v := float(row) / float(GRID_SEGMENTS)
		var h := 1.0 - v
		var point := _base_vertices[index]
		var torso := _smooth_band(h, 0.16, 0.44, 0.72, 0.94)
		var ground_lock := _smooth01(h, 0.05, 0.24)
		var edge := _smooth01(absf(u - 0.5), 0.18, 0.48)
		var upper := _smooth_band(h, 0.28, 0.48, 0.88, 1.0)
		var side := -1.0 if u < 0.5 else 1.0
		var wing_wave := sin(_time * rhythm * 1.55 + absf(u - 0.5) * 7.0)
		point.x *= 1.0 + pulse * breathe * torso
		point.x += slow * sway * _height * h * ground_lock
		point.y += pulse * breathe * _height * 0.38 * torso
		point.x += side * wing_wave * wing * _height * edge * upper
		point.y += wing_wave * wing * _height * 0.22 * edge * upper
		point.z += wing_wave * wing * _height * 0.34 * edge * upper
		var plume := sin(_time * rhythm * 1.18 + u * 11.0) * edge * h
		point.x += plume * sway * _height * 0.24
		point.y += plume * sway * _height * 0.12
		if _locomotion == "aquatico":
			point.x += sin(_time * rhythm + v * 7.0) * sway * _height * h * 0.72
			point.z += cos(_time * rhythm + v * 6.0) * sway * _height * 0.38
		point.y += _action_value * sin(h * PI) * _height * 0.045
		point.x += _action_value * side * edge * _height * 0.030
		point.z -= _charge_value * torso * _height * 0.028
		vertices[index] = point
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _smooth01(value: float, start: float, finish: float) -> float:
	var t := clampf((value - start) / maxf(0.0001, finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _smooth_band(value: float, a: float, b: float, c: float, d: float) -> float:
	return _smooth01(value, a, b) * (1.0 - _smooth01(value, c, d))


func _create_presence() -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = _height * 0.34
	shadow_mesh.bottom_radius = _height * 0.38
	shadow_mesh.height = 0.018
	shadow_mesh.radial_segments = 40
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(0.002, 0.004, 0.012, 0.34)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = shadow_mesh
	_shadow.material_override = _shadow_material
	_shadow.position.y = 0.018
	_shadow.scale.z = 0.34
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	_outer_ring = _create_ring(_height * 0.39, 0.17)
	_inner_ring = _create_ring(_height * 0.27, 0.29)
	_outer_ring.position.y = 0.025
	_inner_ring.position.y = 0.032
	add_child(_outer_ring)
	add_child(_inner_ring)
	_light = OmniLight3D.new()
	_light.light_color = _element_color
	_light.light_energy = 0.42
	_light.omni_range = _height * 1.8
	_light.position.y = _height * 0.54
	_light.shadow_enabled = false
	add_child(_light)


func _create_ring(radius: float, alpha: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.018
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 7
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(_element_color.r, _element_color.g, _element_color.b, alpha)
	material.emission_enabled = true
	material.emission = _element_color
	material.emission_energy_multiplier = 1.1
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = material
	return ring


func _update_presence() -> void:
	if _outer_ring == null:
		return
	_outer_ring.rotation.y = _time * 0.32
	_inner_ring.rotation.y = -_time * 0.51
	var pulse := 0.5 + sin(_time * 2.1) * 0.5
	for ring: MeshInstance3D in [_outer_ring, _inner_ring]:
		var material := ring.material_override as StandardMaterial3D
		material.emission_energy_multiplier = (0.7 + pulse * 1.15) * _presence_boost
	_light.light_energy = (0.28 + pulse * 0.24) * _presence_boost
	_shadow_material.albedo_color.a = 0.34 - pulse * 0.07


func _new_tween() -> Tween:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _active_tween


func preparar_golpe(move: Dictionary) -> void:
	_prepared_move = move.duplicate(true)


func definir_cor_elemento(color: Color) -> void:
	_element_color = color
	if _light != null:
		_light.light_color = color
	for ring: MeshInstance3D in [_outer_ring, _inner_ring]:
		if ring != null:
			var material := ring.material_override as StandardMaterial3D
			material.emission = color


func ponto_emissao() -> Vector3:
	return global_position + Vector3(0.0, _height * 0.64, -0.16 if _back_view else 0.16)


func ponto_impacto() -> Vector3:
	return global_position + Vector3(0.0, _height * 0.55, 0.0)


func entrar(duration: float = 0.70) -> void:
	if _body == null:
		return
	_busy = true
	_body.scale = Vector3(0.84, 0.84, 0.84)
	_body.position.y = -0.10
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_body, "position:y", 0.0, duration * 0.76)
	tween.chain().tween_callback(_finish_state.bind("entrar"))


func carregar(duration: float = 0.85) -> void:
	_busy = true
	_heavy_pending = true
	_presence_boost = 4.8
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_charge, 0.0, 1.0, duration * 0.58)
	tween.tween_method(_set_action, 0.0, 0.72, duration * 0.58)
	tween.tween_property(_body, "scale", Vector3(1.07, 0.90, 1.0), duration * 0.58)
	tween.chain().set_parallel(true)
	tween.tween_property(_body, "scale", Vector3.ONE, duration * 0.30).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_action, 0.72, 0.25, duration * 0.30)
	tween.chain().tween_callback(_finish_state.bind("carregar", false))


func atacar(duration: float = 0.62) -> void:
	_busy = true
	if _heavy_pending and _id_beast == "pedrilho":
		_attack_burrow(duration)
	elif _locomotion == "voador":
		_attack_flying(duration)
	elif _locomotion == "aquatico":
		_attack_aquatic(duration)
	elif str(_prepared_move.get("travel_style", "")) in ["beam", "cone", "arc", "overhead"]:
		_attack_cast(duration)
	else:
		_attack_advance(duration)


func _attack_advance(duration: float) -> void:
	var start := position
	var direction := -1.0 if _back_view else 1.0
	var distance := 1.24 if _heavy_pending else 0.82
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:z", start.z - direction * 0.12, duration * 0.22)
	tween.tween_property(_body, "scale", Vector3(1.05, 0.93, 1.0), duration * 0.22)
	tween.tween_method(_set_action, 0.0, 0.70, duration * 0.22)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position:z", start.z + direction * distance, duration * 0.25).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_body, "scale", Vector3(0.96, 1.07, 1.0), duration * 0.25)
	tween.chain().tween_callback(_emit_impact)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start, duration * 0.38)
	tween.tween_property(_body, "scale", Vector3.ONE, duration * 0.38)
	tween.tween_method(_set_action, 0.70, 0.0, duration * 0.38)
	tween.chain().tween_callback(_finish_state.bind("atacar"))


func _attack_cast(duration: float) -> void:
	var lean := -0.11 if _back_view else 0.11
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "position:y", 0.10, duration * 0.40).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_body, "rotation:z", lean, duration * 0.40)
	tween.tween_method(_set_action, 0.0, 1.0, duration * 0.40)
	tween.tween_method(_set_charge, 0.2, 0.85, duration * 0.40)
	tween.chain().tween_callback(_emit_impact)
	tween.set_parallel(true)
	tween.tween_property(_body, "position", Vector3.ZERO, duration * 0.42)
	tween.tween_property(_body, "rotation", Vector3.ZERO, duration * 0.42)
	tween.tween_method(_set_action, 1.0, 0.0, duration * 0.42)
	tween.tween_method(_set_charge, 0.85, 0.0, duration * 0.42)
	tween.chain().tween_callback(_finish_state.bind("atacar"))


func _attack_flying(duration: float) -> void:
	var start := position
	var direction := -1.0 if _back_view else 1.0
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start.y + 0.62, duration * 0.30)
	tween.tween_property(_body, "rotation:z", direction * 0.15, duration * 0.30)
	tween.tween_method(_set_action, 0.0, 0.92, duration * 0.30)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", start + Vector3(0.0, 0.10, direction * 0.70), duration * 0.22).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_body, "rotation:z", -direction * 0.18, duration * 0.22)
	tween.chain().tween_callback(_emit_impact)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start, duration * 0.34)
	tween.tween_property(_body, "rotation", Vector3.ZERO, duration * 0.34)
	tween.tween_method(_set_action, 0.92, 0.0, duration * 0.34)
	tween.chain().tween_callback(_finish_state.bind("atacar"))


func _attack_aquatic(duration: float) -> void:
	var start := position
	var direction := -1.0 if _back_view else 1.0
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start.y + 0.28, duration * 0.32)
	tween.tween_property(self, "position:z", start.z + direction * 0.34, duration * 0.32)
	tween.tween_method(_set_action, 0.0, 1.0, duration * 0.32)
	tween.chain().tween_callback(_emit_impact)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start, duration * 0.40)
	tween.tween_method(_set_action, 1.0, 0.0, duration * 0.40)
	tween.chain().tween_callback(_finish_state.bind("atacar"))


func _attack_burrow(duration: float) -> void:
	var start := position
	var direction := -1.0 if _back_view else 1.0
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start.y - 0.58, duration * 0.27)
	tween.tween_property(_body, "scale:y", 0.18, duration * 0.27)
	tween.chain().tween_property(self, "position:z", start.z + direction * 1.45, duration * 0.22).set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start.y + 0.12, duration * 0.20).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_body, "scale", Vector3(1.08, 1.08, 1.0), duration * 0.20)
	tween.chain().tween_callback(_emit_impact)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start, duration * 0.32)
	tween.tween_property(_body, "scale", Vector3.ONE, duration * 0.32)
	tween.chain().tween_callback(_finish_state.bind("atacar"))


func _emit_impact() -> void:
	_presence_boost = 5.6
	animacao_terminou.emit("impacto")


func levar_dano(color: Color = Color(1.0, 0.35, 0.35), duration: float = 0.42) -> void:
	_busy = true
	var start := position
	var tween := _new_tween()
	for index in range(4):
		var direction := -1.0 if index % 2 == 0 else 1.0
		tween.tween_property(self, "position:x", start.x + direction * 0.13, duration * 0.11)
		tween.parallel().tween_method(_set_flash.bind(color), 0.0, 1.0, duration * 0.08)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start, duration * 0.28)
	tween.tween_method(_set_flash.bind(color), 1.0, 0.0, duration * 0.28)
	tween.chain().tween_callback(_finish_state.bind("dano"))


func esquivar(direction: int, duration: float = 0.38) -> void:
	if direction == 0 or _body == null:
		return
	_busy = true
	var start := position
	var destination := start + Vector3(float(signi(direction)) * 0.72, 0.0, 0.0)
	var tween := _new_tween()
	tween.tween_method(_position_dodge.bind(start, destination, signi(direction)), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_finish_dodge.bind(destination))


func _position_dodge(progress: float, start: Vector3, destination: Vector3, direction: int) -> void:
	position = start.lerp(destination, progress)
	position.y = start.y + sin(progress * PI) * (0.08 if _locomotion == "terrestre" else 0.18)
	_body.rotation.z = -float(direction) * sin(progress * PI) * 0.16
	_body.scale = Vector3(1.0 - sin(progress * PI) * 0.06, 1.0 + sin(progress * PI) * 0.05, 1.0)
	_set_action(sin(progress * PI))


func _finish_dodge(destination: Vector3) -> void:
	position = destination
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE
	_set_action(0.0)
	_finish_state("esquiva")


func comemorar(duration: float = 1.05) -> void:
	_busy = true
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "position:y", 0.24, duration * 0.36).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_body, "scale", Vector3(1.10, 1.10, 1.0), duration * 0.36)
	tween.tween_method(_set_action, 0.0, 1.0, duration * 0.36)
	tween.chain().set_parallel(true)
	tween.tween_property(_body, "position", Vector3.ZERO, duration * 0.36)
	tween.tween_property(_body, "scale", Vector3.ONE, duration * 0.36)
	tween.tween_method(_set_action, 1.0, 0.0, duration * 0.36)
	tween.chain().tween_callback(_finish_state.bind("comemorar"))


func tombar(duration: float = 0.95) -> void:
	_busy = true
	var fall_direction := -1.18 if _back_view else 1.18
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "rotation:z", fall_direction, duration * 0.72).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "position:y", -0.10, duration * 0.72)
	tween.tween_property(_body, "scale", Vector3(0.96, 0.70, 1.0), duration * 0.72)
	tween.chain().tween_callback(_finish_state.bind("tombar", false))


func guardar(rounds: int = 1) -> void:
	_busy = true
	_presence_boost = 4.0
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "scale", Vector3(1.04, 1.04, 1.0), 0.18).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_set_charge, 0.0, 0.72, 0.18)
	tween.chain().tween_callback(_emit_guard_ready.bind(rounds))


func _emit_guard_ready(rounds: int) -> void:
	animacao_terminou.emit("guardar_%d" % rounds)


func encerrar_guarda() -> void:
	_busy = false
	if _body != null:
		_body.scale = Vector3.ONE
	_set_charge(0.0)
	_presence_boost = 1.0


func _set_action(value: float) -> void:
	_action_value = value


func _set_charge(value: float) -> void:
	_charge_value = value
	if _material != null:
		_material.albedo_color = Color.WHITE.lerp(_element_color.lightened(0.35), value * 0.20)


func _set_flash(value: float, color: Color) -> void:
	_flash_value = value
	if _material != null:
		_material.albedo_color = Color.WHITE.lerp(color.lightened(0.30), value * 0.68)


func _finish_state(name: String, return_idle: bool = true) -> void:
	if return_idle and _body != null:
		_body.position = Vector3.ZERO
		_body.rotation = Vector3.ZERO
		_body.scale = Vector3.ONE
		_set_action(0.0)
		_set_flash(0.0, _element_color)
		if name == "atacar":
			_set_charge(0.0)
	if name == "atacar":
		_heavy_pending = false
	_busy = false
	_presence_boost = 1.0
	animacao_terminou.emit(name)
