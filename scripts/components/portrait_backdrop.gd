class_name PortraitBackdrop
extends Control

var _texture_rect: TextureRect
var _shade: ColorRect
var _ambient: AmbientBackdropFX


func setup(
	texture_path: String,
	tint: Color = Color.WHITE,
	shade_alpha: float = 0.28
) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if ResourceLoader.exists(texture_path):
		_texture_rect.texture = load(texture_path) as Texture2D
	else:
		push_error("Cenário vertical ausente: %s" % texture_path)
	_texture_rect.modulate = tint
	add_child(_texture_rect)

	_ambient = AmbientBackdropFX.new()
	_ambient.accent = Color("70dfff")
	_ambient.energy = 0.62
	add_child(_ambient)

	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.018, 0.07, shade_alpha)
	add_child(_shade)
