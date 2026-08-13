class_name CreatureAvatar
extends Control

enum MotionState { IDLE, ATTACK, HIT, CELEBRATE, DEFEAT }

const STATE_FPS: Dictionary = {
	MotionState.IDLE: 2.2,
	MotionState.ATTACK: 8.5,
	MotionState.HIT: 7.0,
	MotionState.CELEBRATE: 5.5,
	MotionState.DEFEAT: 1.0,
}

var creature: Dictionary = {}
var facing := 1.0
var animation_offset := Vector2.ZERO
var squash := Vector2.ONE
var flash := 0.0
var damage_shake := 0.0
var celebration := 0.0
var defeated := false
var selected_glow := false

var _time := 0.0
var _state_time := 0.0
var _state := MotionState.IDLE
var _frames: Array[AtlasTexture] = []
var _sprite_active: TextureRect
var _sprite_previous: TextureRect
var _current_frame := -1
var _frame_blend := 1.0
var _fx_material: ShaderMaterial
var _family := "ground"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_ensure_sprites()
	set_process(true)


func setup(data: Dictionary, face_direction: float = 1.0) -> void:
	# setup() também pode ser chamado antes de o nó entrar na SceneTree.
	# Não dependa de _ready() para criar os dois planos de crossfade.
	_ensure_sprites()
	creature = data.duplicate(true)
	facing = face_direction
	_family = _family_for(str(creature.get("id", "")))
	_load_combat_sheet()
	_set_motion_state(MotionState.IDLE)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_state_time += delta
	damage_shake = move_toward(damage_shake, 0.0, delta * 60.0)
	flash = move_toward(flash, 0.0, delta * 4.5)
	celebration = move_toward(celebration, 0.0, delta)
	_frame_blend = minf(1.0, _frame_blend + delta * 9.5)
	_update_animation_frame()
	_update_sprite_transform()
	_update_crossfade()
	if _fx_material != null:
		_fx_material.set_shader_parameter("hit_flash", flash)
		_fx_material.set_shader_parameter(
			"aura_strength", 1.0 if selected_glow or celebration > 0.0 else 0.22
		)
	queue_redraw()


func _ensure_sprites() -> void:
	if _sprite_active != null:
		return
	_sprite_previous = _new_sprite()
	add_child(_sprite_previous)
	_sprite_active = _new_sprite()
	add_child(_sprite_active)


func _new_sprite() -> TextureRect:
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return sprite


func _load_combat_sheet() -> void:
	_frames.clear()
	_fx_material = null
	_current_frame = -1
	if creature.is_empty():
		return
	var creature_id := str(creature.get("id", ""))
	var sheet_path := "res://assets/sprites_combat/%s.png" % creature_id
	if not ResourceLoader.exists(sheet_path):
		sheet_path = "res://assets/sprites/beasts/%s.png" % creature_id
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		push_error("Spritesheet HD obrigatório ausente: %s" % sheet_path)
		_sprite_active.visible = false
		_sprite_previous.visible = false
		return
	var frame_size := Vector2(
		sheet.get_width() / 4.0,
		sheet.get_height() / 4.0
	)
	for frame_index in 16:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			Vector2(frame_index % 4, floori(frame_index / 4.0)) * frame_size,
			frame_size
		)
		_frames.append(frame)
	var material_path := "res://assets/materials/creatures/%s.tres" % creature_id
	if ResourceLoader.exists(material_path):
		var loaded_material := load(material_path) as ShaderMaterial
		if loaded_material != null:
			_fx_material = loaded_material.duplicate() as ShaderMaterial
	if _sprite_active != null and _sprite_previous != null:
		_sprite_active.material = _fx_material
		_sprite_previous.material = _fx_material
	_sprite_active.visible = true
	_sprite_previous.visible = true


func _state_sequence() -> Array[int]:
	match _state:
		MotionState.IDLE:
			return [8, 9]
		MotionState.ATTACK:
			return [10, 11, 11, 9]
		MotionState.HIT:
			return [12, 12, 9]
		MotionState.CELEBRATE:
			return [14, 9, 14, 9]
		MotionState.DEFEAT:
			return [15]
	return [8]


func _set_motion_state(next_state: MotionState) -> void:
	_state = next_state
	_state_time = 0.0
	_update_animation_frame()


func _update_animation_frame() -> void:
	if _sprite_active == null or _frames.size() != 16:
		return
	var sequence: Array[int] = _state_sequence()
	var sequence_index := 0
	if sequence.size() > 1:
		var fps: float = float(STATE_FPS[_state])
		sequence_index = int(floor(_state_time * fps)) % sequence.size()
	_set_frame(sequence[sequence_index])


func _set_frame(frame_index: int) -> void:
	if frame_index == _current_frame or frame_index < 0 or frame_index >= _frames.size():
		return
	var old_active := _sprite_active
	_sprite_active = _sprite_previous
	_sprite_previous = old_active
	_sprite_active.texture = _frames[frame_index]
	_sprite_active.modulate.a = 0.0
	_sprite_previous.modulate.a = 1.0
	_current_frame = frame_index
	_frame_blend = 0.0


func _update_crossfade() -> void:
	if _sprite_active == null or _sprite_previous == null:
		return
	var eased := smoothstep(0.0, 1.0, _frame_blend)
	_sprite_active.modulate.a = eased
	_sprite_previous.modulate.a = 1.0 - eased


func _update_sprite_transform() -> void:
	if _sprite_active == null or size.x <= 1.0:
		return
	var motion_seed := float(creature.get("seed", 0))
	var motion := _motion_profile()
	var center := size * Vector2(0.5, float(motion["center_y"]))
	var avatar_size := minf(size.x, size.y) * float(motion["fit"])
	var breath := 1.0 + sin(_time * float(motion["speed"]) + motion_seed) * float(motion["breath"])
	var bob := sin(_time * float(motion["bob_speed"]) + motion_seed) * float(motion["bob"])
	var sway := sin(_time * float(motion["sway_speed"]) + motion_seed) * float(motion["sway"])
	var shake_x := sin(_time * 52.0) * damage_shake
	for sprite in [_sprite_previous, _sprite_active]:
		if sprite == null:
			continue
		sprite.size = Vector2.ONE * avatar_size
		sprite.position = center + animation_offset + Vector2(shake_x, bob) - sprite.size * 0.5
		sprite.pivot_offset = sprite.size * Vector2(0.5, 0.68)
		sprite.scale = Vector2(facing * breath * squash.x, breath * squash.y)
		sprite.rotation = sway


func _motion_profile() -> Dictionary:
	match _family:
		"winged":
			return {"fit":0.86, "center_y":0.53, "speed":3.0, "breath":0.012, "bob":4.0, "bob_speed":2.8, "sway":0.012, "sway_speed":1.7}
		"floating":
			return {"fit":0.84, "center_y":0.52, "speed":2.2, "breath":0.016, "bob":6.0, "bob_speed":1.8, "sway":0.018, "sway_speed":1.3}
		"massive":
			return {"fit":0.82, "center_y":0.55, "speed":1.4, "breath":0.010, "bob":1.0, "bob_speed":1.2, "sway":0.004, "sway_speed":1.0}
		_:
			return {"fit":0.84, "center_y":0.54, "speed":2.0, "breath":0.014, "bob":2.0, "bob_speed":1.7, "sway":0.007, "sway_speed":1.2}


func _family_for(creature_id: String) -> String:
	if creature_id in ["pyrocondor", "prismara", "ciclorn", "floraphex", "raiarraia"]:
		return "winged"
	if creature_id in ["lumari", "impavor", "nocturna", "medulux", "nimbaleia", "tempestral", "marevante"]:
		return "floating"
	if creature_id in ["monolito", "vulcora", "teslouro", "arborion", "musgurso"]:
		return "massive"
	return "ground"


func play_attack() -> void:
	_set_motion_state(MotionState.ATTACK)
	var direction := 48.0 * facing
	var tween := create_tween()
	tween.tween_property(self, "animation_offset:x", -direction * 0.18, 0.10).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "animation_offset:x", direction, 0.16).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "animation_offset:x", 0.0, 0.24).set_trans(Tween.TRANS_BACK)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_damage() -> void:
	_set_motion_state(MotionState.HIT)
	flash = 1.0
	damage_shake = 10.0
	var tween := create_tween()
	tween.tween_property(self, "squash", Vector2(1.10, 0.88), 0.09)
	tween.tween_property(self, "squash", Vector2(0.96, 1.06), 0.12)
	tween.tween_property(self, "squash", Vector2.ONE, 0.18)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_celebration() -> void:
	_set_motion_state(MotionState.CELEBRATE)
	celebration = 1.8
	var tween := create_tween()
	for jump_index in 2:
		tween.tween_property(self, "animation_offset:y", -24.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "animation_offset:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_defeat() -> void:
	defeated = true
	_set_motion_state(MotionState.DEFEAT)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", facing * 0.10, 0.42)
	tween.tween_property(self, "modulate", Color(0.48, 0.51, 0.66, 0.72), 0.42)
	tween.tween_property(self, "animation_offset:y", 20.0, 0.42)
	await tween.finished


func reset_pose() -> void:
	defeated = false
	rotation = 0.0
	modulate = Color.WHITE
	animation_offset = Vector2.ZERO
	squash = Vector2.ONE
	_set_motion_state(MotionState.IDLE)


func _draw() -> void:
	if creature.is_empty():
		return
	var center := size * Vector2(0.5, 0.80)
	var accent := Color(str(creature.get("accent", "#ffffff")))
	var shadow_scale := 1.0 + absf(animation_offset.y) / 180.0
	_draw_oval(
		center,
		Vector2(size.x * 0.24 * shadow_scale, size.y * 0.030),
		Color(0, 0, 0, 0.48)
	)
	_draw_oval(center - Vector2(0, 2), Vector2(size.x * 0.16, size.y * 0.014), Color(accent, 0.16))
	if selected_glow or celebration > 0.0:
		for ring_index in 3:
			draw_arc(
				center - Vector2(0, size.y * 0.20),
				size.x * (0.23 + float(ring_index) * 0.035),
				0,
				TAU,
				64,
				Color(accent, 0.34 - float(ring_index) * 0.08),
				3.0
			)


func _draw_oval(
	center: Vector2,
	radii: Vector2,
	color: Color,
	segments: int = 48
) -> void:
	var points := PackedVector2Array()
	for point_index in segments:
		var angle := TAU * float(point_index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
