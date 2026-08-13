class_name MoveProjectile3D
extends Node3D

## Projétil espacial que reproduz o spritesheet exclusivo de cada golpe.
## A imagem representa a ENERGIA do poder, não o corpo da Beast, e viaja no
## World3D com luz, núcleo volumétrico e rastro.

var _move: Dictionary
var _sprite: Sprite3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _trail: Array[MeshInstance3D] = []
var _texture: Texture2D
var _frames := 1
var _elapsed := 0.0
var _duration := 0.5
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _control := Vector3.ZERO
var _active := false
var _element_color := Color.WHITE


func launch(from: Vector3, to: Vector3, move: Dictionary) -> void:
	_move = move.duplicate(true)
	_from = from
	_to = to
	_element_color = CreatureDB.color_for_type(str(move.get("element", "Luz")))
	var role := str(move.get("role", "rápido"))
	_duration = {
		"rápido": 0.30,
		"técnico": 0.44,
		"controle": 0.58,
		"pesado": 0.72,
	}.get(role, 0.44)
	var side_curve := 0.34 if from.x <= to.x else -0.34
	_control = (_from + _to) * 0.5 + Vector3(side_curve, 0.92 if role == "pesado" else 0.48, 0.0)
	_build_visual(role)
	position = _from
	_active = true
	set_process(true)
	await get_tree().create_timer(_duration).timeout
	await _impact(role)
	queue_free()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var previous := position
	var inverse := 1.0 - progress
	position = inverse * inverse * _from + 2.0 * inverse * progress * _control + progress * progress * _to
	var direction := position - previous
	if direction.length_squared() > 0.0001:
		look_at(position + direction, Vector3.UP)
	if _sprite:
		_sprite.frame = clampi(floori(progress * float(_frames)), 0, _frames - 1)
		_sprite.rotation.z += delta * 1.35
	_update_trail()


func _build_visual(role: String) -> void:
	var sprite_path := str(_move.get("sprite_sheet", ""))
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		push_error("Golpe sem spritesheet 3D: %s" % str(_move.get("id", "desconhecido")))
	else:
		_texture = load(sprite_path) as Texture2D
	if _texture:
		var texture_size := _texture.get_size()
		_frames = maxi(1, roundi(texture_size.x / maxf(texture_size.y, 1.0)))

	_sprite = Sprite3D.new()
	_sprite.name = "MoveSprite_%s" % str(_move.get("id", "move"))
	_sprite.texture = _texture
	_sprite.hframes = _frames
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.transparent = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.render_priority = 4
	_sprite.pixel_size = {
		"rápido": 0.0048,
		"técnico": 0.0063,
		"controle": 0.0075,
		"pesado": 0.0094,
	}.get(role, 0.0063)
	_sprite.modulate = Color(_element_color, 0.94)
	add_child(_sprite)

	var sphere := SphereMesh.new()
	sphere.radius = 0.16 if role == "rápido" else (0.30 if role == "pesado" else 0.22)
	sphere.height = sphere.radius * 2.0
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(_element_color, 0.38)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.emission_enabled = true
	core_material.emission = _element_color
	core_material.emission_energy_multiplier = 3.4 if role == "pesado" else 2.1
	core_material.roughness = 0.18
	_core = MeshInstance3D.new()
	_core.mesh = sphere
	_core.material_override = core_material
	add_child(_core)

	_light = OmniLight3D.new()
	_light.light_color = _element_color
	_light.light_energy = 2.8 if role == "pesado" else 1.5
	_light.omni_range = 3.8 if role == "pesado" else 2.2
	_light.shadow_enabled = false
	add_child(_light)

	for index in 7:
		var trail_mesh := SphereMesh.new()
		trail_mesh.radius = 0.075 * (1.0 - float(index) * 0.075)
		trail_mesh.height = trail_mesh.radius * 2.0
		var trail_instance := MeshInstance3D.new()
		trail_instance.mesh = trail_mesh
		trail_instance.material_override = core_material
		get_parent().add_child(trail_instance)
		trail_instance.global_position = _from
		_trail.append(trail_instance)


func _update_trail() -> void:
	var follow := global_position
	for index in _trail.size():
		var trail_node := _trail[index]
		if not is_instance_valid(trail_node):
			continue
		var old := trail_node.global_position
		trail_node.global_position = trail_node.global_position.lerp(follow, 0.46 - float(index) * 0.025)
		follow = old


func _impact(role: String) -> void:
	_active = false
	for trail_node in _trail:
		if is_instance_valid(trail_node):
			trail_node.queue_free()
	_trail.clear()
	var tween := create_tween()
	tween.set_parallel(true)
	if _sprite:
		tween.tween_property(_sprite, "scale", Vector3.ONE * (2.4 if role == "pesado" else 1.75), 0.16)
		tween.tween_property(_sprite, "modulate:a", 0.0, 0.20)
	if _core:
		tween.tween_property(_core, "scale", Vector3.ONE * (3.0 if role == "pesado" else 2.1), 0.18)
		tween.tween_property(_core, "transparency", 1.0, 0.18)
	if _light:
		tween.tween_property(_light, "light_energy", 0.0, 0.20)
	await tween.finished
