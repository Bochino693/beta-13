class_name UIFactory
extends RefCounted


static func style_box(color: Color, border_color: Color = Color.TRANSPARENT, radius: int = 18, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = border_color
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


static func panel(color: Color = Color("d9101732"), border_color: Color = Color("556ef8ff"), radius: int = 20) -> PanelContainer:
	var output := PanelContainer.new()
	output.add_theme_stylebox_override("panel", style_box(color, border_color, radius, 2))
	return output


static func label(text_value: String, font_size: int = 24, color: Color = Color.WHITE, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var output := Label.new()
	output.text = text_value
	output.add_theme_font_size_override("font_size", font_size)
	output.add_theme_color_override("font_color", color)
	output.horizontal_alignment = alignment
	output.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	output.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return output


static func title(text_value: String, font_size: int = 40, color: Color = Color.WHITE) -> Label:
	var output := label(text_value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	output.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	output.add_theme_constant_override("shadow_offset_x", 3)
	output.add_theme_constant_override("shadow_offset_y", 3)
	return output


static func button(text_value: String, accent: Color = Color("31d7e0"), min_size: Vector2 = Vector2(220, 74)) -> Button:
	var output := Button.new()
	output.text = text_value
	output.custom_minimum_size = min_size
	output.focus_mode = Control.FOCUS_ALL
	output.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	output.add_theme_font_size_override("font_size", 21)
	output.add_theme_color_override("font_color", Color("f4fbff"))
	output.add_theme_color_override("font_hover_color", Color.WHITE)
	output.add_theme_color_override("font_pressed_color", Color.WHITE)
	output.add_theme_color_override("font_focus_color", Color.WHITE)
	output.add_theme_stylebox_override("normal", style_box(Color("e5121838"), accent.darkened(0.25), 16, 2))
	output.add_theme_stylebox_override("hover", style_box(Color("f3263460"), accent, 16, 3))
	output.add_theme_stylebox_override("focus", style_box(Color("f3263460"), accent, 16, 3))
	output.add_theme_stylebox_override("pressed", style_box(accent.darkened(0.55), Color.WHITE, 16, 3))
	return output


static func badge(text_value: String, color: Color) -> Label:
	var output := label(text_value, 16, Color("081020"), HORIZONTAL_ALIGNMENT_CENTER)
	output.custom_minimum_size = Vector2(92, 30)
	output.add_theme_stylebox_override("normal", style_box(color, color.lightened(0.25), 12, 1))
	return output


static func spacer(width: float = 0.0, height: float = 0.0) -> Control:
	var output := Control.new()
	output.custom_minimum_size = Vector2(width, height)
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0.0 else Control.SIZE_FILL
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL if height == 0.0 else Control.SIZE_FILL
	return output
