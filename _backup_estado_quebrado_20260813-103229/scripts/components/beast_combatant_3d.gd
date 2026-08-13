class_name BeastCombatant3D
extends Node3D

## Corpo de combate estritamente 3D.
##
## Em produção, carrega assets/models/beasts/<id>/<id>.glb, com esqueleto e
## animações. Enquanto um GLB ainda não existe, usa um proxy VOLUMÉTRICO por
## família anatômica. O proxy serve para testar câmera, posições, projéteis e
## regras; nunca usa o retrato frontal como plano ou billboard.

signal attack_released

const MODEL_ROOT := "res://assets/models/beasts"
const FAMILIES := {
	"lumari": "specter", "helionce": "quadruped", "prismara": "bird",
	"impavor": "biped", "nocturna": "bird", "abissarca": "dragon",
	"brasalam": "biped", "vulcora": "quadruped", "cinzibora": "serpent",
	"pyrocondor": "bird", "voltalho": "quadruped", "raiarraia": "aquatic",
	"teslouro": "biped", "arcdrake": "dragon", "pedrilho": "quadruped",
	"geodrilo": "quadruped", "monolito": "mineral", "fossatroz": "biped",
	"medulux": "specter", "crustarka": "biped", "torpescama": "aquatic",
	"marevante": "serpent", "floraphex": "insect", "brotoxi": "quadruped",
	"musgurso": "quadruped", "arborion": "plant", "brispulo": "biped",
	"nimbaleia": "aquatic", "ciclorn": "bird", "tempestral": "dragon"
}

const IMPORTED_ANIMATIONS := {
	"idle": ["Idle", "idle", "IDLE"],
	"attack_light": ["AttackLight", "attack_light", "Attack", "attack"],
	"attack_heavy": ["AttackHeavy", "attack_heavy", "Special", "special"],
	"hit": ["Hit", "hit", "Damage", "damage"],
	"win": ["Win", "win", "Victory", "victory"],
	"ko": ["KO", "ko", "Defeat", "defeat"],
	"dodge_left": ["DodgeLeft", "dodge_left", "Dodge", "dodge"],
	"dodge_right": ["DodgeRight", "dodge_right", "Dodge", "dodge"],
}

var creature: Dictionary = {}
var player_index := 0
var lane_index := 1
var uses_development_proxy := false
var selected_glow := false

var _arena: BattleArena3D
var _visual_root: Node3D
var _motion_root: Node3D
var _animation_player: AnimationPlayer
var _fx_origin_marker: Marker3D
var _hit_target_marker: Marker3D
var _wing_left: Node3D
var _wing_right: Node3D
var _tail: Node3D
var _materials: Array[StandardMaterial3D] = []
var _base_visual_y := 0.0
var _time := 0.0
var _defeated := false
var _manual_motion := false
var _active_tween: Tween


func setup(data: Dictionary, side: int, arena: BattleArena3D) -> void:
	creature = data.duplicate(true)
	player_index = side
	_arena = arena
	lane_index = 1
	_defeated = false
	_clear_visual()
	_build_visual()
	position = _arena.lane_position(player_index, lane_index)
	rotation.y = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not _motion_root or _defeated or _manual_motion:
		return
	_time += delta
	var speed_seed := float(creature.get("seed", 0)) * 0.031
	var floating := family() in ["specter", "aquatic", "serpent"]
	var bob := sin(_time * (1.65 + speed_seed) + speed_seed) * (0.07 if floating else 0.025)
	_motion_root.position.y = _base_visual_y + bob
	_motion_root.scale.y = 1.0 + sin(_time * 2.05 + speed_seed) * 0.018
	if _wing_left and _wing_right:
		var flap_speed := 6.0 if family() in ["bird", "insect"] else 2.7
		var flap := sin(_time * flap_speed) * (0.40 if family() == "bird" else 0.22)
		_wing_left.rotation.z = -0.36 - flap
		_wing_right.rotation.z = 0.36 + flap
	if _tail:
		_tail.rotation.y = sin(_time * 1.6 + speed_seed) * 0.16
	for material in _materials:
		material.emission_energy_multiplier = 2.1 if selected_glow else 0.72


func family() -> String:
	return str(FAMILIES.get(str(creature.get("id", "")), "biped"))


func model_path() -> String:
	var creature_id := str(creature.get("id", ""))
	return "%s/%s/%s.glb" % [MODEL_ROOT, creature_id, creature_id]


func has_final_model() -> bool:
	return ResourceLoader.exists(model_path())


func set_lane(next_lane: int, duration: float = 0.22) -> bool:
	next_lane = clampi(next_lane, 0, 2)
	if next_lane == lane_index or abs(next_lane - lane_index) > 1:
		return false
	var previous := lane_index
	lane_index = next_lane
	_play_imported("dodge_left" if next_lane < previous else "dodge_right")
	var target := _arena.lane_position(player_index, lane_index)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target.x, duration)
	return true


func play_entrance() -> void:
	if not _visual_root:
		return
	_visual_root.scale = Vector3.ONE * 0.06
	var target_scale := _model_scale()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual_root, "scale", target_scale, 0.54).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", _arena.lane_position(player_index, lane_index).y, 0.54).from(1.5)
	await tween.finished
	_play_imported("idle")


func play_attack(role: String = "rápido") -> void:
	if not _motion_root:
		return
	_manual_motion = true
	var heavy := role == "pesado"
	_play_imported("attack_heavy" if heavy else "attack_light")
	_kill_tween()
	_active_tween = create_tween()
	var direction := -1.0 if player_index == 0 else 1.0
	var charge_time := 0.42 if heavy else 0.13
	_active_tween.tween_property(_motion_root, "position:z", -direction * (0.28 if heavy else 0.12), charge_time)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3(0.94, 1.05, 0.94), charge_time)
	_active_tween.tween_property(_motion_root, "position:z", direction * (0.72 if heavy else 0.46), 0.18).set_trans(Tween.TRANS_BACK)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3.ONE * 1.07, 0.18)
	_active_tween.tween_callback(func() -> void: attack_released.emit())
	_active_tween.tween_interval(0.08)
	_active_tween.tween_property(_motion_root, "position:z", 0.0, 0.24)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3.ONE, 0.24)
	await _active_tween.finished
	_manual_motion = false
	_play_imported("idle")


func play_damage() -> void:
	if not _motion_root:
		return
	_manual_motion = true
	_play_imported("hit")
	_kill_tween()
	_active_tween = create_tween()
	var recoil := -0.24 if player_index == 0 else 0.24
	_active_tween.tween_property(_motion_root, "rotation:z", recoil, 0.09)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3(1.12, 0.88, 1.08), 0.09)
	_active_tween.tween_property(_motion_root, "rotation:z", -recoil * 0.35, 0.11)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3(0.96, 1.06, 0.96), 0.11)
	_active_tween.tween_property(_motion_root, "rotation:z", 0.0, 0.15)
	_active_tween.parallel().tween_property(_motion_root, "scale", Vector3.ONE, 0.15)
	await _active_tween.finished
	_manual_motion = false
	_play_imported("idle")


func play_celebration() -> void:
	if not _motion_root:
		return
	_manual_motion = true
	_play_imported("win")
	_kill_tween()
	_active_tween = create_tween()
	for jump in 2:
		_active_tween.tween_property(_motion_root, "position:y", _base_visual_y + 0.34, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(_motion_root, "position:y", _base_visual_y, 0.21).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await _active_tween.finished
	_manual_motion = false
	_play_imported("idle")


func play_defeat() -> void:
	if not _motion_root:
		return
	_defeated = true
	_manual_motion = true
	_play_imported("ko")
	_kill_tween()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_motion_root, "rotation:z", -1.22 if player_index == 0 else 1.22, 0.72)
	_active_tween.tween_property(_motion_root, "position:y", -0.22, 0.72)
	_active_tween.tween_property(_motion_root, "scale", Vector3.ONE * 0.72, 0.72)
	await _active_tween.finished


func reset_pose() -> void:
	_defeated = false
	_manual_motion = false
	if _motion_root:
		_motion_root.rotation = Vector3.ZERO
		_motion_root.position = Vector3.ZERO
		_motion_root.scale = Vector3.ONE
	_play_imported("idle")


func get_effect_origin() -> Vector3:
	if is_instance_valid(_fx_origin_marker):
		return _fx_origin_marker.global_position
	return _arena.effect_origin(player_index, lane_index)


func get_hit_target(lane_override: int = -1) -> Vector3:
	var lane := lane_index if lane_override < 0 else lane_override
	if lane == lane_index and is_instance_valid(_hit_target_marker):
		return _hit_target_marker.global_position
	return _arena.impact_point(player_index, lane)


func _clear_visual() -> void:
	for child in get_children():
		child.queue_free()
	_visual_root = null
	_motion_root = null
	_animation_player = null
	_fx_origin_marker = null
	_hit_target_marker = null
	_wing_left = null
	_wing_right = null
	_tail = null
	_materials.clear()


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	_motion_root = Node3D.new()
	_motion_root.name = "MotionRoot"
	_visual_root.add_child(_motion_root)
	if has_final_model():
		uses_development_proxy = false
		var packed := load(model_path()) as PackedScene
		if packed:
			var model := packed.instantiate()
			model.name = "FinalModel"
			_motion_root.add_child(model)
			_animation_player = _find_animation_player(model)
			_fx_origin_marker = _find_marker(model, "FX_Origin")
			_hit_target_marker = _find_marker(model, "Hit_Target")
			_visual_root.scale = _model_scale()
			_visual_root.rotation.y = 0.0 if player_index == 0 else PI
			_play_imported("idle")
			return
	uses_development_proxy = true
	_build_volumetric_proxy()
	_add_proxy_markers()
	_visual_root.scale = _model_scale()
	_visual_root.rotation.y = 0.0 if player_index == 0 else PI


func _model_scale() -> Vector3:
	var weight_class := str(creature.get("weight_class", "Médio"))
	var scale_value: float = float({
		"Ultra Leve": 0.80, "Leve": 0.90, "Médio": 1.0,
		"Pesado": 1.12, "Colossal": 1.25,
	}.get(weight_class, 1.0))
	if player_index == 1:
		scale_value *= 0.92
	return Vector3.ONE * float(scale_value)


func _build_volumetric_proxy() -> void:
	var body := Color(str(creature.get("body", "#777777")))
	var accent := Color(str(creature.get("accent", "#ffffff")))
	var detail := Color(str(creature.get("detail", "#66ddff")))
	var body_mat := _make_material(body, body.lightened(0.16), 0.56, 0.42)
	var accent_mat := _make_material(accent, accent, 0.32, 0.92)
	var detail_mat := _make_material(detail, detail, 0.22, 1.45)
	var dark_mat := _make_material(body.darkened(0.45), accent.darkened(0.15), 0.72, 0.30)
	var family_name := family()

	match family_name:
		"bird":
			_build_bird(body_mat, accent_mat, detail_mat, dark_mat)
		"dragon":
			_build_dragon(body_mat, accent_mat, detail_mat, dark_mat)
		"quadruped":
			_build_quadruped(body_mat, accent_mat, detail_mat, dark_mat)
		"aquatic":
			_build_aquatic(body_mat, accent_mat, detail_mat, dark_mat)
		"serpent":
			_build_serpent(body_mat, accent_mat, detail_mat, dark_mat)
		"mineral":
			_build_mineral(body_mat, accent_mat, detail_mat, dark_mat)
		"plant":
			_build_plant(body_mat, accent_mat, detail_mat, dark_mat)
		"insect":
			_build_insect(body_mat, accent_mat, detail_mat, dark_mat)
		"specter":
			_build_specter(body_mat, accent_mat, detail_mat, dark_mat)
		_:
			_build_biped(body_mat, accent_mat, detail_mat, dark_mat)


func _build_bird(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Torso", Vector3(0, 1.12, 0), Vector3(0.62, 0.78, 0.58), body)
	_add_sphere("Head", Vector3(0, 1.95, -0.20), Vector3(0.42, 0.42, 0.44), accent)
	_add_cone("Beak", Vector3(0, 1.87, -0.68), Vector3(0.22, 0.24, 0.42), dark, Vector3(90, 0, 0))
	_wing_left = _wing("WingLeft", -1.0, body, accent)
	_wing_right = _wing("WingRight", 1.0, body, accent)
	_add_leg(-0.25, dark)
	_add_leg(0.25, dark)
	_tail = _add_cone("Tail", Vector3(0, 0.76, 0.66), Vector3(0.44, 0.72, 0.44), accent, Vector3(-90, 0, 0))
	_add_core(detail)


func _build_dragon(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Torso", Vector3(0, 1.00, 0), Vector3(0.72, 0.90, 0.75), body)
	_add_sphere("Head", Vector3(0, 1.78, -0.55), Vector3(0.48, 0.38, 0.62), accent)
	_wing_left = _wing("WingLeft", -1.0, dark, accent)
	_wing_right = _wing("WingRight", 1.0, dark, accent)
	for side in [-0.42, 0.42]:
		_add_leg(side, dark)
	_tail = _add_capsule("Tail", Vector3(0, 0.66, 0.88), Vector3(0.27, 0.75, 0.27), accent, Vector3(70, 0, 0))
	_add_horns(dark)
	_add_core(detail)


func _build_quadruped(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Torso", Vector3(0, 0.95, 0), Vector3(0.70, 0.66, 1.08), body, Vector3(90, 0, 0))
	_add_sphere("Head", Vector3(0, 1.18, -1.02), Vector3(0.53, 0.50, 0.58), accent)
	for x in [-0.46, 0.46]:
		for z in [-0.58, 0.58]:
			_add_capsule("Leg", Vector3(x, 0.43, z), Vector3(0.21, 0.46, 0.21), dark)
	_tail = _add_capsule("Tail", Vector3(0, 0.92, 1.08), Vector3(0.20, 0.62, 0.20), accent, Vector3(72, 0, 0))
	_add_horns(detail)


func _build_biped(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Torso", Vector3(0, 1.20, 0), Vector3(0.58, 0.78, 0.52), body)
	_add_sphere("Head", Vector3(0, 2.02, -0.08), Vector3(0.44, 0.44, 0.46), accent)
	for side in [-1.0, 1.0]:
		_add_capsule("Arm", Vector3(side * 0.58, 1.24, -0.04), Vector3(0.17, 0.56, 0.17), dark, Vector3(0, 0, side * 24.0))
		_add_capsule("Leg", Vector3(side * 0.26, 0.45, 0), Vector3(0.22, 0.52, 0.22), dark)
	_add_horns(detail)
	_add_core(detail)


func _build_aquatic(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Body", Vector3(0, 1.25, 0), Vector3(0.62, 0.70, 1.28), body, Vector3(90, 0, 0))
	_add_sphere("Head", Vector3(0, 1.25, -1.00), Vector3(0.56, 0.48, 0.62), accent)
	_wing_left = _fin("FinLeft", -1.0, detail)
	_wing_right = _fin("FinRight", 1.0, detail)
	_tail = _fin("Tail", 0.0, accent, Vector3(0, 1.25, 1.35), Vector3(0, 0, 90))
	_base_visual_y = 0.28
	_add_core(detail)


func _build_serpent(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	for segment in 6:
		var t := float(segment) / 5.0
		_add_sphere(
			"BodySegment", Vector3(sin(t * 3.5) * 0.23, 1.25 - t * 0.58, -0.55 + t * 1.35),
			Vector3.ONE * (0.48 - t * 0.045), body if segment % 2 == 0 else accent
		)
	_add_sphere("Head", Vector3(0, 1.55, -0.90), Vector3(0.52, 0.43, 0.62), accent)
	_add_horns(detail)
	_base_visual_y = 0.30


func _build_mineral(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_sphere("Core", Vector3(0, 1.15, 0), Vector3(0.58, 0.72, 0.54), detail)
	for index in 7:
		var angle := TAU * float(index) / 7.0
		_add_box(
			"Armor", Vector3(cos(angle) * 0.63, 1.17 + sin(angle * 2.0) * 0.25, sin(angle) * 0.56),
			Vector3(0.46, 0.52, 0.34), body if index % 2 == 0 else accent,
			Vector3(index * 17.0, index * 29.0, index * 11.0)
		)
	for side in [-1.0, 1.0]:
		_add_box("Arm", Vector3(side * 0.92, 1.05, 0), Vector3(0.38, 0.78, 0.42), dark, Vector3(0, 0, side * 17.0))
		_add_box("Leg", Vector3(side * 0.34, 0.40, 0), Vector3(0.38, 0.64, 0.42), dark)


func _build_plant(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Trunk", Vector3(0, 1.00, 0), Vector3(0.58, 0.92, 0.55), dark)
	_add_sphere("Canopy", Vector3(0, 1.92, -0.05), Vector3(0.85, 0.64, 0.72), body)
	for side in [-1.0, 1.0]:
		_add_capsule("Branch", Vector3(side * 0.68, 1.30, 0), Vector3(0.20, 0.72, 0.20), accent, Vector3(0, 0, side * 52.0))
		_add_capsule("Root", Vector3(side * 0.28, 0.36, 0), Vector3(0.24, 0.46, 0.24), dark)
	_add_core(detail)


func _build_insect(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_capsule("Thorax", Vector3(0, 1.25, 0), Vector3(0.48, 0.64, 0.48), body)
	_add_sphere("Head", Vector3(0, 1.92, -0.28), Vector3(0.38, 0.34, 0.40), accent)
	_add_sphere("Abdomen", Vector3(0, 0.75, 0.35), Vector3(0.46, 0.62, 0.48), dark)
	_wing_left = _wing("WingLeft", -1.0, detail, accent)
	_wing_right = _wing("WingRight", 1.0, detail, accent)
	for side in [-1.0, 1.0]:
		for row in 3:
			_add_capsule("Leg", Vector3(side * (0.48 + row * 0.12), 0.85 + row * 0.24, 0.15), Vector3(0.08, 0.55, 0.08), dark, Vector3(0, 0, side * (48.0 + row * 12.0)))
	_base_visual_y = 0.22


func _build_specter(body: Material, accent: Material, detail: Material, dark: Material) -> void:
	_add_sphere("Head", Vector3(0, 1.75, -0.08), Vector3(0.52, 0.50, 0.50), accent)
	_add_capsule("Spirit", Vector3(0, 1.02, 0.18), Vector3(0.58, 0.82, 0.58), body)
	for side in [-1.0, 1.0]:
		_add_capsule("Arm", Vector3(side * 0.58, 1.18, 0), Vector3(0.15, 0.58, 0.15), dark, Vector3(0, 0, side * 45.0))
	_tail = _add_cone("VaporTail", Vector3(0, 0.28, 0.24), Vector3(0.42, 0.85, 0.42), detail, Vector3(0, 0, 180))
	_base_visual_y = 0.32
	_add_core(detail)


func _wing(name_value: String, side: float, body: Material, accent: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_value
	pivot.position = Vector3(side * 0.46, 1.48, 0.10)
	_motion_root.add_child(pivot)
	for feather in 4:
		var part := _add_capsule(
			"Feather", Vector3(side * (0.38 + feather * 0.26), -feather * 0.05, feather * 0.04),
			Vector3(0.20, 0.52 + feather * 0.09, 0.10), accent if feather % 2 else body,
			Vector3(0, 0, side * (62.0 + feather * 4.0)), pivot
		)
		part.rotation.y = side * 0.08
	return pivot


func _fin(
	name_value: String, side: float, material: Material,
	custom_position: Vector3 = Vector3.ZERO,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> Node3D:
	var position_value := custom_position if custom_position != Vector3.ZERO else Vector3(side * 0.70, 1.20, 0.0)
	return _add_box(
		name_value, position_value, Vector3(0.58, 0.09, 0.72), material,
		rotation_degrees_value if rotation_degrees_value != Vector3.ZERO else Vector3(0, 0, side * 18.0)
	)


func _add_leg(x: float, material: Material) -> void:
	_add_capsule("Leg", Vector3(x, 0.43, -0.02), Vector3(0.18, 0.50, 0.18), material)
	_add_box("Foot", Vector3(x, 0.12, -0.16), Vector3(0.30, 0.12, 0.42), material)


func _add_horns(material: Material) -> void:
	var count := clampi(int(creature.get("horns", 0)), 0, 3)
	for index in count:
		var x := (float(index) - float(count - 1) * 0.5) * 0.28
		_add_cone("Horn", Vector3(x, 2.33, 0), Vector3(0.12, 0.38, 0.12), material)


func _add_core(material: Material) -> void:
	_add_sphere("ElementCore", Vector3(0, 1.30, -0.52), Vector3.ONE * 0.18, material)


func _add_proxy_markers() -> void:
	_fx_origin_marker = Marker3D.new()
	_fx_origin_marker.name = "FX_Origin"
	_fx_origin_marker.position = Vector3(0, 1.52, -0.72)
	_motion_root.add_child(_fx_origin_marker)
	_hit_target_marker = Marker3D.new()
	_hit_target_marker.name = "Hit_Target"
	_hit_target_marker.position = Vector3(0, 1.20, 0)
	_motion_root.add_child(_hit_target_marker)


func _add_sphere(name_value: String, position_value: Vector3, scale_value: Vector3, material: Material, parent: Node3D = null) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return _add_part(name_value, mesh, position_value, scale_value, material, Vector3.ZERO, parent)


func _add_capsule(name_value: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_degrees_value: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return _add_part(name_value, mesh, position_value, scale_value, material, rotation_degrees_value, parent)


func _add_box(name_value: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_degrees_value: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	return _add_part(name_value, mesh, position_value, scale_value, material, rotation_degrees_value, parent)


func _add_cone(name_value: String, position_value: Vector3, scale_value: Vector3, material: Material, rotation_degrees_value: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	return _add_part(name_value, mesh, position_value, scale_value, material, rotation_degrees_value, parent)


func _add_part(
	name_value: String,
	mesh: PrimitiveMesh,
	position_value: Vector3,
	scale_value: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	parent: Node3D = null
) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = material
	(parent if parent else _motion_root).add_child(instance)
	return instance


func _make_material(albedo: Color, emission: Color, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.16
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	_materials.append(material)
	return material


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_marker(node: Node, marker_name: String) -> Marker3D:
	if node is Marker3D and node.name == marker_name:
		return node as Marker3D
	for child in node.get_children():
		var found := _find_marker(child, marker_name)
		if found:
			return found
	return null


func _play_imported(state: String) -> void:
	if not _animation_player or not IMPORTED_ANIMATIONS.has(state):
		return
	for animation_name in IMPORTED_ANIMATIONS[state]:
		if _animation_player.has_animation(animation_name):
			_animation_player.play(animation_name, 0.12)
			return


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
