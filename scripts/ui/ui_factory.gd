class_name UIFactory
extends RefCounted

## ORDEM DAS CORES EM HEXA: o Godot le `Color("...")` de oito digitos como
## **RRGGBBAA** — o alfa vem por ULTIMO.
##
## As telas estavam escritas em AARRGGBB (alfa primeiro), como em CSS/Android.
## O resultado era cor errada E alfa errado ao mesmo tempo: `Color("e8101732")`
## era para ser um azul-marinho a 91% de opacidade e virava um vermelho a 20%.
## Por isso todas as placas apareciam lavadas, avermelhadas e deixando a arte
## de fundo atravessar o texto.
##
## Ao escrever uma cor nova: `Color("101732e8")`, nao `Color("e8101732")`.
## Na duvida, use a forma numerica — `Color(0.06, 0.09, 0.20, 0.91)` — que nao
## tem ambiguidade de ordem.

const DISPLAY_FONT_PATH := "res://assets/battle/fonts/URWGothic-Demi.otf"
const BODY_FONT_PATH := "res://assets/battle/fonts/URWGothic-Book.otf"

static var _display_font: Font
static var _body_font: Font


static func display_font() -> Font:
	if _display_font == null and ResourceLoader.exists(DISPLAY_FONT_PATH):
		_display_font = load(DISPLAY_FONT_PATH) as Font
	return _display_font


static func body_font() -> Font:
	if _body_font == null and ResourceLoader.exists(BODY_FONT_PATH):
		_body_font = load(BODY_FONT_PATH) as Font
	if _body_font == null:
		_body_font = display_font()
	return _body_font


static func apply_font(control: Control, use_display_font: bool = false) -> void:
	var chosen_font: Font = display_font() if use_display_font else body_font()
	if chosen_font != null:
		control.add_theme_font_override("font", chosen_font)


static func style_box(
	color: Color,
	border_color: Color = Color.TRANSPARENT,
	radius: int = 18,
	border: int = 0,
	shadow: bool = false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = border_color
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	if shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0.0, 5.0)
	return style


## Placa de fundo das telas.
##
## Devolve um `Panel`, NAO um `PanelContainer`.
##
## `PanelContainer` e um container: ele reposiciona e redimensiona TODO filho
## para preencher o proprio retangulo, a cada passe de layout. Como as telas
## montam o conteudo com posicao absoluta — `nome.position = Vector2(20, 15)`,
## `selo.position = Vector2(205, 68)` e assim por diante — o container apagava
## essas posicoes e empilhava tudo no mesmo ponto. Era isso que imprimia nome,
## selo, peso e atributos uns por cima dos outros no guia de poderes, na tela
## de resultado, na abertura e na montagem de equipe.
##
## `Panel` desenha a mesma moldura e nao mexe nos filhos: a posicao que a tela
## pede e a posicao que aparece.
##
## Quando o conteudo for um container que DEVE preencher a placa (uma grade,
## uma lista rolavel), use `fill_panel()` em vez de adicionar o filho direto.
static func panel(
	color: Color = Color("101732e8"),
	border_color: Color = Color("6ef8ff66"),
	radius: int = 20
) -> Panel:
	var output := Panel.new()
	output.add_theme_stylebox_override(
		"panel", style_box(color, border_color, radius, 2, true)
	)
	return output


## Ancora um filho para preencher a placa inteira, com margem.
##
## E o substituto explicito do preenchimento que o `PanelContainer` fazia
## sozinho: quem realmente quer um filho ocupando a placa pede aqui, em vez de
## todo mundo receber esse comportamento sem querer.
static func fill_panel(parent: Control, child: Control, margin: float = 16.0) -> Control:
	parent.add_child(child)
	child.set_anchors_preset(Control.PRESET_FULL_RECT)
	child.offset_left = margin
	child.offset_top = margin
	child.offset_right = -margin
	child.offset_bottom = -margin
	return child


static func label(
	text_value: String,
	font_size: int = 24,
	color: Color = Color.WHITE,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var output := Label.new()
	output.text = text_value
	output.add_theme_font_size_override("font_size", font_size)
	output.add_theme_color_override("font_color", color)
	output.horizontal_alignment = alignment
	output.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	output.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	apply_font(output)
	return output


static func title(
	text_value: String,
	font_size: int = 40,
	color: Color = Color.WHITE
) -> Label:
	var output := label(text_value, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	apply_font(output, true)
	output.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	output.add_theme_constant_override("shadow_offset_x", 3)
	output.add_theme_constant_override("shadow_offset_y", 4)
	output.add_theme_constant_override("outline_size", 2)
	output.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.08, 0.92))
	return output


static func button(
	text_value: String,
	accent: Color = Color("31d7e0"),
	min_size: Vector2 = Vector2(220, 74)
) -> Button:
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
	output.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.07, 0.95))
	output.add_theme_constant_override("outline_size", 3)
	output.add_theme_stylebox_override(
		"normal", style_box(Color("111936ed"), Color(accent, 0.68), 18, 2, true)
	)
	output.add_theme_stylebox_override(
		"hover", style_box(Color("213158f5"), accent, 18, 3, true)
	)
	output.add_theme_stylebox_override(
		"focus", style_box(Color("213158f5"), accent, 18, 3, true)
	)
	output.add_theme_stylebox_override(
		"pressed", style_box(Color(accent, 0.38), Color.WHITE, 18, 3, false)
	)
	## Estado desabilitado tambem precisa de moldura.
	##
	## Sem este override o botao caia no tema padrao do Godot e ficava SEM
	## fundo e SEM borda: o "CONFIRMAR EQUIPE" da montagem de equipe, que
	## nasce desabilitado ate a quinta Beast entrar, aparecia como um texto
	## cinza solto no rodape — parecia fonte quebrada, nao botao inativo.
	output.add_theme_stylebox_override(
		"disabled", style_box(Color("0a0f1ec0"), Color(accent, 0.30), 18, 2, false)
	)
	output.add_theme_color_override("font_disabled_color", Color("7d8aa6"))
	apply_font(output, true)
	return output


static func badge(text_value: String, color: Color) -> Label:
	var output := label(text_value, 16, Color("081020"), HORIZONTAL_ALIGNMENT_CENTER)
	output.custom_minimum_size = Vector2(92, 30)
	output.add_theme_stylebox_override(
		"normal", style_box(color, color.lightened(0.25), 12, 1, false)
	)
	apply_font(output, true)
	return output


static func spacer(width: float = 0.0, height: float = 0.0) -> Control:
	var output := Control.new()
	output.custom_minimum_size = Vector2(width, height)
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0.0 else Control.SIZE_FILL
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL if height == 0.0 else Control.SIZE_FILL
	return output
