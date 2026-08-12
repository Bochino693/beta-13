class_name CreatureAvatar
extends Control

enum MotionState { IDLE, ATTACK, HIT, CELEBRATE, DEFEAT }

const FRAME_SIZE := Vector2(320, 320)
const STATE_FRAMES := {
	MotionState.IDLE: [0, 1, 2, 3],
	MotionState.ATTACK: [4, 5, 6, 7],
	MotionState.HIT: [8, 9, 10, 11],
	MotionState.CELEBRATE: [12, 13, 14, 13],
	MotionState.DEFEAT: [15]
}
const STATE_FPS := {
	MotionState.IDLE: 5.5,
	MotionState.ATTACK: 11.0,
	MotionState.HIT: 12.0,
	MotionState.CELEBRATE: 8.0,
	MotionState.DEFEAT: 1.0
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
var _sheet: Texture2D
var _frames: Array[AtlasTexture] = []
var _sprite: TextureRect
var _fx_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_sprite()
	set_process(true)


func setup(data: Dictionary, face_direction: float = 1.0) -> void:
	creature = data.duplicate(true)
	facing = face_direction
	_load_hd_sprite_sheet()
	_set_motion_state(MotionState.IDLE)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_state_time += delta
	damage_shake = move_toward(damage_shake, 0.0, delta * 60.0)
	flash = move_toward(flash, 0.0, delta * 4.5)
	celebration = move_toward(celebration, 0.0, delta)
	_update_animation_frame()
	_update_sprite_transform()
	if _fx_material:
		_fx_material.set_shader_parameter("hit_flash", flash)
		_fx_material.set_shader_parameter("aura_strength", 1.0 if selected_glow or celebration > 0.0 else 0.24)
	queue_redraw()


func _ensure_sprite() -> void:
	if _sprite:
		return
	_sprite = TextureRect.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)


func _load_hd_sprite_sheet() -> void:
	_sheet = null
	_frames.clear()
	_fx_material = null
	if creature.is_empty():
		return
	var creature_id := str(creature.get("id", ""))
	var sheet_path := "res://assets/sprites/beasts/%s.png" % creature_id
	if not ResourceLoader.exists(sheet_path):
		push_error("Spritesheet HD obrigatório ausente: %s" % sheet_path)
		_sprite.visible = false
		return
	_sheet = load(sheet_path) as Texture2D
	for frame_index in 16:
		var frame := AtlasTexture.new()
		frame.atlas = _sheet
		frame.region = Rect2(Vector2(frame_index % 4, floori(frame_index / 4.0)) * FRAME_SIZE, FRAME_SIZE)
		_frames.append(frame)
	var material_path := "res://assets/materials/creatures/%s.tres" % creature_id
	if ResourceLoader.exists(material_path):
		var loaded_material := load(material_path) as ShaderMaterial
		if loaded_material:
			_fx_material = loaded_material.duplicate() as ShaderMaterial
	_sprite.material = _fx_material
	_sprite.visible = true
	_update_animation_frame()


func _set_motion_state(next_state: MotionState) -> void:
	_state = next_state
	_state_time = 0.0
	_update_animation_frame()


func _update_animation_frame() -> void:
	if not _sprite or _frames.size() != 16:
		return
	var sequence: Array = STATE_FRAMES[_state]
	var sequence_index := 0
	if sequence.size() > 1:
		sequence_index = int(floor(_state_time * float(STATE_FPS[_state]))) % sequence.size()
	_sprite.texture = _frames[int(sequence[sequence_index])]


func _update_sprite_transform() -> void:
	if not _sprite or _sheet == null or size.x <= 1.0:
		return
	var center := size * Vector2(0.5, 0.54)
	var avatar_size := minf(size.x, size.y) * 1.02
	var depth_breathe := 1.0 + sin(_time * 2.2 + float(creature.get("seed", 0))) * 0.007
	var depth_bob := sin(_time * 1.9 + float(creature.get("seed", 0))) * 1.8
	var shake_x := sin(_time * 52.0) * damage_shake
	_sprite.size = Vector2.ONE * avatar_size
	_sprite.position = center + animation_offset + Vector2(shake_x, depth_bob) - _sprite.size * 0.5
	_sprite.pivot_offset = _sprite.size * 0.5
	_sprite.scale = Vector2(facing * depth_breathe * squash.x, depth_breathe * squash.y)
	_sprite.rotation = sin(_time * 1.35 + float(creature.get("seed", 0))) * 0.006


func play_attack() -> void:
	_set_motion_state(MotionState.ATTACK)
	var direction := 54.0 * facing
	var tween := create_tween()
	tween.tween_property(self, "animation_offset:x", -direction * 0.15, 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "animation_offset:x", direction, 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "animation_offset:x", 0.0, 0.20).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_damage() -> void:
	_set_motion_state(MotionState.HIT)
	flash = 1.0
	damage_shake = 12.0
	var tween := create_tween()
	tween.tween_property(self, "squash", Vector2(1.13, 0.86), 0.09)
	tween.tween_property(self, "squash", Vector2(0.94, 1.08), 0.11)
	tween.tween_property(self, "squash", Vector2.ONE, 0.16)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_celebration() -> void:
	_set_motion_state(MotionState.CELEBRATE)
	celebration = 1.8
	var tween := create_tween()
	for jump in 2:
		tween.tween_property(self, "animation_offset:y", -30.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "animation_offset:y", 0.0, 0.21).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_set_motion_state(MotionState.IDLE)


func play_defeat() -> void:
	defeated = true
	_set_motion_state(MotionState.DEFEAT)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", facing * 0.16, 0.4)
	tween.tween_property(self, "modulate", Color(0.48, 0.51, 0.66, 0.72), 0.4)
	tween.tween_property(self, "animation_offset:y", 24.0, 0.4)
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
	_draw_oval(center, Vector2(size.x * 0.26 * shadow_scale, size.y * 0.035), Color(0, 0, 0, 0.46))
	_draw_oval(center - Vector2(0, 2), Vector2(size.x * 0.18, size.y * 0.018), Color(accent, 0.14))
	if selected_glow or celebration > 0.0:
		for ring in 3:
			draw_arc(center - Vector2(0, size.y * 0.20), size.x * (0.25 + ring * 0.04), 0, TAU, 64, Color(accent, 0.36 - ring * 0.09), 3.0)


func _draw_oval(center: Vector2, radii: Vector2, color: Color, segments: int = 48) -> void:
	var points := PackedVector2Array()
	for point_index in segments:
		var angle := TAU * float(point_index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
