class_name ElementSkillFX
extends Control

const FRAME_SIZE := Vector2(192, 192)

var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var move_data: Dictionary = {}
var element_color := Color.WHITE
var progress := 0.0:
	set(value):
		progress = value
		_update_fx_frame()
		queue_redraw()
var _sheet: Texture2D
var _frames: Array[AtlasTexture] = []
var _sprite: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite = TextureRect.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.size = FRAME_SIZE
	_sprite.pivot_offset = FRAME_SIZE * 0.5
	add_child(_sprite)


func launch(from: Vector2, to: Vector2, selected_move: Dictionary) -> void:
	start_point = from
	end_point = to
	move_data = selected_move.duplicate(true)
	element_color = CreatureDB.color_for_type(str(move_data.get("element", "")))
	_load_sprite_sheet()
	var duration := 0.36
	match str(move_data.get("role", "técnico")):
		"rápido":
			duration = 0.27
		"controle":
			duration = 0.46
		"pesado":
			duration = 0.58
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	queue_free()


func _load_sprite_sheet() -> void:
	_frames.clear()
	var path := str(move_data.get("sprite_sheet", ""))
	if not ResourceLoader.exists(path):
		push_error("Spritesheet do golpe ausente: %s" % path)
		_sprite.visible = false
		return
	_sheet = load(path) as Texture2D
	for frame_index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = _sheet
		frame.region = Rect2(Vector2(frame_index, 0) * FRAME_SIZE, FRAME_SIZE)
		_frames.append(frame)
	_update_fx_frame()


func _update_fx_frame() -> void:
	if not _sprite or _frames.size() != 8:
		return
	var frame_index := clampi(floori(progress * 8.0), 0, 7)
	_sprite.texture = _frames[frame_index]
	var eased := smoothstep(0.0, 1.0, progress)
	var current := start_point.lerp(end_point, eased)
	_sprite.position = current - FRAME_SIZE * 0.5
	var pulse := 0.78 + sin(progress * PI) * (0.34 if str(move_data.get("role", "")) == "pesado" else 0.18)
	_sprite.scale = Vector2.ONE * pulse
	_sprite.rotation = progress * (1.2 if int(move_data.get("slot", 0)) % 2 == 0 else -1.2)


func _draw() -> void:
	var eased := smoothstep(0.0, 1.0, progress)
	var direction := (end_point - start_point).normalized()
	var normal := Vector2(-direction.y, direction.x)
	for trail_index in 9:
		var trail_progress := clampf(eased - trail_index * 0.035, 0.0, 1.0)
		var trail_point := start_point.lerp(end_point, trail_progress)
		var wave := normal * sin(progress * 14.0 + trail_index) * (4.0 + trail_index)
		var alpha := maxf(0.0, 0.44 - trail_index * 0.042) * (1.0 - progress * 0.35)
		draw_circle(trail_point + wave, maxf(2.0, 13.0 - trail_index), Color(element_color, alpha))
	if str(move_data.get("role", "")) == "pesado":
		var current := start_point.lerp(end_point, eased)
		draw_arc(current, 62.0 + sin(progress * PI) * 24.0, 0, TAU, 64, Color(element_color, 0.55), 5.0)
