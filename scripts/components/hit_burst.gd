class_name HitBurst
extends Control

var center := Vector2.ZERO
var burst_color := Color.WHITE
var caption := ""
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func burst(at_position: Vector2, color: Color, text_value: String = "") -> void:
	center = at_position
	burst_color = color
	caption = text_value
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	queue_free()


func _draw() -> void:
	var fade := 1.0 - progress
	for ray in 18:
		var angle := TAU * float(ray) / 18.0 + float(ray % 3) * 0.12
		var inner := 20.0 + progress * 34.0
		var outer := 42.0 + progress * (90.0 + ray % 4 * 8.0)
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * inner, center + direction * outer, Color(burst_color, fade), 3.0 + float(ray % 3))
	for ring in 3:
		draw_arc(center, 18.0 + progress * (58.0 + ring * 18.0), 0, TAU, 56, Color(burst_color.lightened(0.22), fade * (0.8 - ring * 0.18)), 5.0 - ring)
	draw_circle(center, maxf(0.0, 30.0 * (1.0 - progress)), Color.WHITE)
	if not caption.is_empty() and progress < 0.72:
		var font := ThemeDB.fallback_font
		var font_size := 23
		var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, -80 - progress * 24), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(burst_color.lightened(0.28), fade))
