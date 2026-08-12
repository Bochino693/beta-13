class_name NeonBackground
extends Control

@export var arena_mode := false
@export var accent := Color("6ef8ff")
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("050922"))
	for band in 10:
		var band_y := viewport_size.y * float(band) / 10.0
		var band_color := Color("0c1640").lerp(Color("24104b"), float(band) / 10.0)
		draw_rect(Rect2(0, band_y, viewport_size.x, viewport_size.y / 10.0 + 1.0), band_color)
	for star in 64:
		var seed_x := fmod(float(star * 127 + 43), 997.0) / 997.0
		var seed_y := fmod(float(star * 73 + 19), 431.0) / 431.0
		var pulse := 0.42 + sin(_time * (0.8 + float(star % 5) * 0.17) + star) * 0.24
		var point := Vector2(seed_x * viewport_size.x, seed_y * viewport_size.y * 0.67)
		draw_circle(point, 1.0 + float(star % 3), Color(0.65, 0.9, 1.0, pulse))
	var horizon := viewport_size.y * (0.64 if arena_mode else 0.76)
	for line in 11:
		var factor := float(line) / 10.0
		var y := lerpf(horizon, viewport_size.y, factor * factor)
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), Color(accent, 0.08 + factor * 0.14), 1.5)
	for column in 17:
		var x_bottom := viewport_size.x * float(column) / 16.0
		var x_horizon := viewport_size.x * 0.5 + (x_bottom - viewport_size.x * 0.5) * 0.18
		draw_line(Vector2(x_horizon, horizon), Vector2(x_bottom, viewport_size.y), Color(accent, 0.12), 1.2)
	if arena_mode:
		var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.67)
		for ring in 4:
			var radius_x := viewport_size.x * (0.20 + ring * 0.10)
			var radius_y := 38.0 + ring * 19.0
			draw_arc(center, radius_x, 0, TAU, 96, Color(accent, 0.30 - ring * 0.045), 2.0)
			draw_arc(center, radius_y, 0, TAU, 48, Color(1, 0.25, 0.7, 0.13), 1.0)
	var glow_position := Vector2(viewport_size.x * (0.18 + 0.04 * sin(_time * 0.2)), viewport_size.y * 0.28)
	for glow in range(8, 0, -1):
		draw_circle(glow_position, glow * 22.0, Color(accent, 0.004 * glow))
