extends Control

var _element_index := 0
var _element_icon: TypeEmblem
var _element_title: Label
var _relations: Label
var _move_rows: VBoxContainer


func _ready() -> void:
	_build_screen()
	_show_element()
	AudioSynth.start_music("menu")


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/selection_archive.png", Color.WHITE, 0.42)
	var title := UIFactory.title("GUIA DE PODERES", 40, Color.WHITE)
	title.position = Vector2(35, 28)
	title.size = Vector2(650, 54)
	add_child(title)
	var subtitle := UIFactory.label("80 GOLPES • PODER • RECARGA • OBJETIVO", 15, Color("8ff5ff"), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.position = Vector2(35, 82)
	subtitle.size = Vector2(650, 32)
	add_child(subtitle)

	var element_panel := UIFactory.panel(Color("09122be0"), Color("6ef8ff88"), 26)
	element_panel.position = Vector2(30, 130)
	element_panel.size = Vector2(660, 190)
	add_child(element_panel)
	_element_icon = TypeEmblem.new()
	_element_icon.position = Vector2(22, 20)
	_element_icon.size = Vector2(150, 150)
	_element_icon.destaque = 1.0
	element_panel.add_child(_element_icon)
	_element_title = UIFactory.title("", 34, Color.WHITE)
	_element_title.position = Vector2(180, 25)
	_element_title.size = Vector2(440, 52)
	element_panel.add_child(_element_title)
	_relations = UIFactory.label("", 16, Color("dce9ff"))
	_relations.position = Vector2(200, 82)
	_relations.size = Vector2(400, 80)
	_relations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	element_panel.add_child(_relations)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 340)
	scroll.size = Vector2(660, 795)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_move_rows = VBoxContainer.new()
	_move_rows.custom_minimum_size = Vector2(640, 0)
	_move_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_move_rows)

	var footer := UIFactory.label("ARQUIVO ELEMENTAL • 10 GOLPES POR CATEGORIA", 15, Color("e4edff"), HORIZONTAL_ALIGNMENT_CENTER)
	footer.position = Vector2(35, 1185)
	footer.size = Vector2(650, 40)
	add_child(footer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_left") or event.is_action_pressed("p2_left"):
		_element_index = wrapi(_element_index - 1, 0, CreatureDB.ELEMENTS.size())
		_show_element()
		AudioSynth.ui_move()
	elif event.is_action_pressed("p1_right") or event.is_action_pressed("p2_right") or event.is_action_pressed("filter_next"):
		_element_index = wrapi(_element_index + 1, 0, CreatureDB.ELEMENTS.size())
		_show_element()
		AudioSynth.ui_move()
	elif event.is_action_pressed("p1_cancel") or event.is_action_pressed("p2_cancel"):
		AudioSynth.ui_cancel()
		Transition.go_to(GameState.MODE_SCENE, "VOLTANDO AOS MODOS")


func _show_element() -> void:
	var element: String = CreatureDB.ELEMENTS[_element_index]
	var color := CreatureDB.color_for_type(element)
	_element_icon.element = element
	_element_title.text = "%s  %d/8" % [element.to_upper(), _element_index + 1]
	_element_title.add_theme_color_override("font_color", color)
	## Num par reciproco o mesmo elemento aparece nas DUAS listas (forte
	## contra e vulneravel a). Sem aviso isso pareceria erro de tela, entao a
	## rivalidade ganha uma linha propria.
	var rivais: Array[String] = []
	for outro: String in CreatureDB.strong_against(element):
		if CreatureDB.are_rivals(element, outro):
			rivais.append(outro.to_upper())

	var texto := "FORTE CONTRA: %s\nVULNERÁVEL A: %s" % [
		", ".join(MoveDB.strongest_against(element)),
		", ".join(MoveDB.vulnerable_to(element)),
	]
	if not rivais.is_empty():
		texto += "\nRIVAL DE %s — os dois se vencem." % ", ".join(rivais)
	_relations.text = texto
	for child in _move_rows.get_children():
		child.queue_free()
	for move in MoveDB.moves:
		if str(move["element"]) != element:
			continue
		var row := UIFactory.panel(Color("0a1229e2"), Color(color, 0.68), 18)
		row.custom_minimum_size = Vector2(640, 118)
		_move_rows.add_child(row)
		var icon := TextureRect.new()
		icon.position = Vector2(10, 10)
		icon.size = Vector2(98, 98)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(str(move["icon"])) as Texture2D
		row.add_child(icon)
		var move_name := UIFactory.label("%02d  %s" % [move["slot"], move["name"]], 18, Color.WHITE)
		move_name.position = Vector2(120, 10)
		move_name.size = Vector2(480, 32)
		row.add_child(move_name)
		var data := UIFactory.label("GRAU %s  •  PODER %02d  •  RECARGA %.2f  •  %s" % [MoveDB.power_grade(move), move["power"], move["cooldown"], str(move["role"]).to_upper()], 14, color)
		data.position = Vector2(120, 44)
		data.size = Vector2(490, 27)
		row.add_child(data)
		var objective := UIFactory.label(str(move["objective"]), 13, Color("cedbf2"))
		objective.position = Vector2(120, 74)
		objective.size = Vector2(490, 30)
		row.add_child(objective)
