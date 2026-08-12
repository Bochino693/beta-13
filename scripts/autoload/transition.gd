extends CanvasLayer

var _veil: ColorRect
var _title: Label
var _changing := false


func _ready() -> void:
	layer = 200
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.005, 0.008, 0.025, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-210, -28)
	_title.size = Vector2(420, 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("6ef8ff"))
	_title.text = ""
	_title.modulate.a = 0.0
	_veil.add_child(_title)


func go_to(scene_path: String, message: String = "PREPARANDO A ARENA") -> void:
	if _changing:
		return
	_changing = true
	_title.text = message
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(_veil, "color:a", 1.0, 0.22)
	fade_out.tween_property(_title, "modulate:a", 1.0, 0.16)
	await fade_out.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(_veil, "color:a", 0.0, 0.28)
	fade_in.tween_property(_title, "modulate:a", 0.0, 0.18)
	await fade_in.finished
	_changing = false
