class_name PortraitBackdrop
extends Control

var _texture_rect: TextureRect
var _shade: ColorRect
var _time := 0.0
var _drift_strength := 12.0


func setup(texture_path: String, tint: Color = Color.WHITE, shade_alpha: float = 0.28) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.offset_left = -24
	_texture_rect.offset_top = -24
	_texture_rect.offset_right = 24
	_texture_rect.offset_bottom = 24
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if ResourceLoader.exists(texture_path):
		_texture_rect.texture = load(texture_path) as Texture2D
	else:
		push_error("Cenário vertical ausente: %s" % texture_path)
	_texture_rect.modulate = tint
	add_child(_texture_rect)
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.018, 0.07, shade_alpha)
	add_child(_shade)


func _process(delta: float) -> void:
	_time += delta
	if _texture_rect:
		_texture_rect.position = Vector2(sin(_time * 0.11), cos(_time * 0.09)) * _drift_strength - Vector2.ONE * 24.0
		_texture_rect.scale = Vector2.ONE * (1.015 + sin(_time * 0.08) * 0.004)
