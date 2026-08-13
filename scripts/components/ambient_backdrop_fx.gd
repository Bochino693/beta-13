class_name AmbientBackdropFX
extends Control

## Movimento ambiental discreto. O cenário nunca muda de posição ou escala;
## somente luz, poeira e estrelas variam, evitando o fundo "balançando".

var accent := Color("6ef8ff")
var energy := 0.55
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	for particle_index in 42:
		var seed_x := fmod(float(particle_index * 97 + 31), 997.0) / 997.0
		var seed_y := fmod(float(particle_index * 53 + 17), 431.0) / 431.0
		var pulse := 0.35 + sin(_time * (0.42 + float(particle_index % 7) * 0.08) + float(particle_index)) * 0.22
		var point := Vector2(seed_x * size.x, seed_y * size.y)
		var radius := 0.8 + float(particle_index % 3) * 0.55
		draw_circle(point, radius, Color(accent, maxf(0.04, pulse * energy)))

	var sweep := fmod(_time * 34.0, size.x + 360.0) - 180.0
	var beam_points := PackedVector2Array([
		Vector2(sweep - 120.0, 0.0),
		Vector2(sweep + 20.0, 0.0),
		Vector2(sweep + 260.0, size.y),
		Vector2(sweep + 80.0, size.y),
	])
	draw_colored_polygon(beam_points, Color(accent, 0.022 * energy))

	var horizon_y := size.y * 0.62
	for ring_index in 3:
		var radius_x := size.x * (0.20 + float(ring_index) * 0.12)
		var alpha := (0.075 - float(ring_index) * 0.016) * energy
		draw_arc(
			Vector2(size.x * 0.5, horizon_y),
			radius_x,
			PI + 0.12,
			TAU - 0.12,
			64,
			Color(accent, alpha),
			2.0
		)

