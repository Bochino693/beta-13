extends Control

const COLUMNS := 3
const FILTERS := ["TODOS", "Luz", "Escuridão", "Fogo", "Choque", "Terra", "Água", "Natureza", "Vento"]
const CATEGORY_HINTS := {
	"TODOS":"30 Beasts HD", "Luz":"celestiais e prismáticos", "Escuridão":"demônios e espectros",
	"Fogo":"ígneos e vulcânicos", "Choque":"condutores e plasma", "Terra":"fósseis e minerais",
	"Água":"seres oceânicos", "Natureza":"insetos, flora e fungos", "Vento":"planadores e seres aéreos"
}

var _catalog: Array[Dictionary] = []
var _card_buttons: Array[Button] = []
var _filter_buttons: Array[Button] = []
var _visible_indices: Array[int] = []
var _active_filter := "TODOS"
var _cursor := 0
var _current_player := 0
var _selected_teams: Array = [[], []]
var _scroll: ScrollContainer
var _preview_avatar: CreatureAvatar
var _preview_name: Label
var _preview_title: Label
var _preview_type: Label
var _preview_details: Label
var _preview_moves: Label
var _team_slots: HBoxContainer
var _phase_label: Label
var _category_hint: Label
var _instruction: Label
var _ready_button: Button
var _locked := false


func _ready() -> void:
	_catalog = CreatureDB.all()
	for creature_index in _catalog.size():
		_visible_indices.append(creature_index)
	_build_screen()
	if not CardRegistry.card_scanned.is_connected(_on_card_scanned):
		CardRegistry.card_scanned.connect(_on_card_scanned)
	_refresh_all(false)
	AudioSynth.start_music("menu")


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/selection_archive.png", Color.WHITE, 0.43)

	var header := UIFactory.panel(Color("e4081028"), Color("776ef8ff"), 24)
	header.position = Vector2(20, 18)
	header.size = Vector2(680, 112)
	add_child(header)
	_phase_label = UIFactory.label("", 27, Color("6ef8ff"))
	_phase_label.position = Vector2(18, 8)
	_phase_label.size = Vector2(410, 42)
	header.add_child(_phase_label)
	_category_hint = UIFactory.label("", 14, Color("d4e1f5"))
	_category_hint.position = Vector2(20, 48)
	_category_hint.size = Vector2(395, 30)
	header.add_child(_category_hint)
	_team_slots = HBoxContainer.new()
	_team_slots.position = Vector2(420, 18)
	_team_slots.size = Vector2(240, 76)
	_team_slots.add_theme_constant_override("separation", 5)
	header.add_child(_team_slots)

	var filter_grid := GridContainer.new()
	filter_grid.columns = 3
	filter_grid.position = Vector2(25, 145)
	filter_grid.size = Vector2(670, 155)
	filter_grid.add_theme_constant_override("h_separation", 7)
	filter_grid.add_theme_constant_override("v_separation", 7)
	add_child(filter_grid)
	for element_name in FILTERS:
		var filter_button := Button.new()
		filter_button.custom_minimum_size = Vector2(218, 47)
		filter_button.focus_mode = Control.FOCUS_NONE
		filter_button.text = element_name.to_upper()
		filter_button.add_theme_font_size_override("font_size", 13)
		filter_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		filter_button.pressed.connect(_set_filter.bind(element_name))
		filter_grid.add_child(filter_button)
		_filter_buttons.append(filter_button)

	var catalog_panel := UIFactory.panel(Color("e2091129"), Color("556ef8ff"), 23)
	catalog_panel.position = Vector2(20, 312)
	catalog_panel.size = Vector2(680, 520)
	add_child(catalog_panel)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(10, 10)
	_scroll.size = Vector2(660, 500)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_panel.add_child(_scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.custom_minimum_size = Vector2(640, 0)
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(grid)

	for creature_index in _catalog.size():
		var creature: Dictionary = _catalog[creature_index]
		var type_color := CreatureDB.color_for_type(str(creature["type"]))
		var card := Button.new()
		card.custom_minimum_size = Vector2(208, 96)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.text = "%s\n%s • %s" % [creature["name"], creature["type"], _weight_short(str(creature["weight_class"]))]
		var icon_path := "res://assets/creatures_hd/%s.png" % creature["id"]
		if ResourceLoader.exists(icon_path):
			card.icon = load(icon_path) as Texture2D
		else:
			push_error("Retrato HD obrigatório ausente: %s" % icon_path)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_theme_constant_override("icon_max_width", 68)
		card.add_theme_constant_override("h_separation", 3)
		card.add_theme_font_size_override("font_size", 12)
		card.add_theme_color_override("font_color", Color("f0f7ff"))
		card.add_theme_stylebox_override("normal", UIFactory.style_box(Color("e7111934"), Color(type_color, 0.62), 13, 2))
		card.add_theme_stylebox_override("hover", UIFactory.style_box(Color("f3263458"), type_color, 13, 3))
		card.mouse_entered.connect(_hover_card.bind(creature_index))
		card.pressed.connect(_toggle_current.bind(creature_index))
		grid.add_child(card)
		_card_buttons.append(card)
	_update_filter_buttons()

	var preview_panel := UIFactory.panel(Color("ed09122d"), Color("77ff4fc8"), 24)
	preview_panel.position = Vector2(20, 848)
	preview_panel.size = Vector2(680, 292)
	add_child(preview_panel)
	_preview_avatar = CreatureAvatar.new()
	_preview_avatar.position = Vector2(8, 30)
	_preview_avatar.size = Vector2(235, 245)
	_preview_avatar.selected_glow = true
	preview_panel.add_child(_preview_avatar)
	_preview_type = UIFactory.badge("", Color.WHITE)
	_preview_type.position = Vector2(22, 12)
	_preview_type.size = Vector2(125, 30)
	preview_panel.add_child(_preview_type)
	_preview_name = UIFactory.label("", 27, Color.WHITE)
	_preview_name.position = Vector2(245, 15)
	_preview_name.size = Vector2(405, 40)
	preview_panel.add_child(_preview_name)
	_preview_title = UIFactory.label("", 14, Color("ffde5b"))
	_preview_title.position = Vector2(245, 52)
	_preview_title.size = Vector2(410, 28)
	preview_panel.add_child(_preview_title)
	_preview_details = UIFactory.label("", 14, Color("dbe8fb"))
	_preview_details.position = Vector2(245, 82)
	_preview_details.size = Vector2(410, 80)
	_preview_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_panel.add_child(_preview_details)
	_preview_moves = UIFactory.label("", 12, Color("b9f7ff"))
	_preview_moves.position = Vector2(245, 164)
	_preview_moves.size = Vector2(410, 105)
	_preview_moves.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_panel.add_child(_preview_moves)

	_instruction = UIFactory.label("", 13, Color("d5e0f3"), HORIZONTAL_ALIGNMENT_CENTER)
	_instruction.position = Vector2(25, 1142)
	_instruction.size = Vector2(670, 32)
	add_child(_instruction)
	_ready_button = UIFactory.button("CONFIRMAR EQUIPE", Color("ff4fc8"), Vector2(650, 76))
	_ready_button.position = Vector2(35, 1180)
	_ready_button.size = Vector2(650, 76)
	_ready_button.pressed.connect(_confirm_team)
	add_child(_ready_button)


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	var prefix := "p1_" if _current_player == 0 else "p2_"
	if event.is_action_pressed("filter_next"):
		_cycle_filter()
	elif event.is_action_pressed(prefix + "left"):
		_move_cursor(-1)
	elif event.is_action_pressed(prefix + "right"):
		_move_cursor(1)
	elif event.is_action_pressed(prefix + "up"):
		_move_cursor(-COLUMNS)
	elif event.is_action_pressed(prefix + "down"):
		_move_cursor(COLUMNS)
	elif event.is_action_pressed(prefix + "confirm"):
		_toggle_current(_cursor)
	elif event.is_action_pressed(prefix + "ready") or event.is_action_pressed("start"):
		_confirm_team()
	elif event.is_action_pressed(prefix + "cancel"):
		_cancel_or_back()


func _move_cursor(delta: int) -> void:
	if _visible_indices.is_empty():
		return
	var visible_position := _visible_indices.find(_cursor)
	if visible_position < 0:
		visible_position = 0
	_cursor = _visible_indices[wrapi(visible_position + delta, 0, _visible_indices.size())]
	AudioSynth.ui_move()
	_refresh_all(false)
	_scroll.ensure_control_visible(_card_buttons[_cursor])


func _cycle_filter() -> void:
	var filter_index := FILTERS.find(_active_filter)
	_set_filter(FILTERS[wrapi(filter_index + 1, 0, FILTERS.size())])


func _set_filter(element_name: String) -> void:
	_active_filter = element_name
	_visible_indices.clear()
	for creature_index in _catalog.size():
		if element_name == "TODOS" or str(_catalog[creature_index]["type"]) == element_name:
			_visible_indices.append(creature_index)
	if not _visible_indices.has(_cursor) and not _visible_indices.is_empty():
		_cursor = _visible_indices[0]
	_update_filter_buttons()
	AudioSynth.ui_move()
	_refresh_all(false)


func _update_filter_buttons() -> void:
	for button_index in _filter_buttons.size():
		var filter_name: String = FILTERS[button_index]
		var active := filter_name == _active_filter
		var color := Color("6ef8ff") if filter_name == "TODOS" else CreatureDB.color_for_type(filter_name)
		_filter_buttons[button_index].add_theme_stylebox_override("normal", UIFactory.style_box(Color(color, 0.34 if active else 0.13), color, 11, 3 if active else 1))
		_filter_buttons[button_index].add_theme_color_override("font_color", Color.WHITE if active else color.lightened(0.15))


func _hover_card(index: int) -> void:
	if _cursor != index:
		_cursor = index
		_refresh_all(false)


func _toggle_current(index: int) -> void:
	var selected: Array = _selected_teams[_current_player]
	var creature_id: String = _catalog[index]["id"]
	if creature_id in selected:
		selected.erase(creature_id)
		AudioSynth.ui_cancel()
	elif selected.size() < 5:
		selected.append(creature_id)
		AudioSynth.ui_confirm()
		_preview_avatar.play_celebration()
	else:
		AudioSynth.ui_cancel()
		_instruction.text = "Equipe completa: remova uma Beast antes de adicionar outra."
	_refresh_all(false)


func _on_card_scanned(creature_id: String, _card_code: String) -> void:
	for index in _catalog.size():
		if str(_catalog[index]["id"]) == creature_id:
			_cursor = index
			_set_filter(str(_catalog[index]["type"]))
			_toggle_current(index)
			_instruction.text = "CARTA RECONHECIDA • %s" % _catalog[index]["name"]
			return


func _cancel_or_back() -> void:
	if not _selected_teams[_current_player].is_empty():
		_selected_teams[_current_player].pop_back()
		AudioSynth.ui_cancel()
		_refresh_all(false)
	elif _current_player == 1:
		_current_player = 0
		AudioSynth.ui_cancel()
		_refresh_all(false)
	else:
		AudioSynth.ui_cancel()
		Transition.go_to(GameState.MODE_SCENE, "VOLTANDO AOS MODOS")


func _confirm_team() -> void:
	if _selected_teams[_current_player].size() != 5:
		AudioSynth.ui_cancel()
		_instruction.text = "Faltam %d Beasts para completar a equipe." % (5 - _selected_teams[_current_player].size())
		return
	AudioSynth.ui_confirm()
	GameState.set_team(_current_player, _selected_teams[_current_player])
	if _current_player == 0 and GameState.mode == "pvp":
		_current_player = 1
		_cursor = 0
		_set_filter("TODOS")
		return
	if GameState.mode == "cpu":
		GameState.set_team(1, CreatureDB.random_team(5, _selected_teams[0]))
	else:
		GameState.set_team(1, _selected_teams[1])
	_locked = true
	Transition.go_to(GameState.BATTLE_SCENE, "ENTRANDO NA ARENA")


func _refresh_all(play_sound: bool = false) -> void:
	_update_header()
	_update_cards()
	_update_preview()
	_update_slots()
	if play_sound:
		AudioSynth.ui_move()


func _update_header() -> void:
	var player_name := "JOGADOR 1" if _current_player == 0 else "JOGADOR 2"
	var player_color := Color("6ef8ff") if _current_player == 0 else Color("ff4fc8")
	_phase_label.text = "%s • EQUIPE 5 × 5" % player_name
	_phase_label.add_theme_color_override("font_color", player_color)
	_category_hint.text = "%s • %s" % [_active_filter.to_upper(), CATEGORY_HINTS[_active_filter]]
	var ready_key := "E" if _current_player == 0 else "M"
	_instruction.text = "DIREÇÕES • CONFIRMAR • TAB FILTRA • %s FINALIZA • CARTA COMPATÍVEL" % ready_key
	_ready_button.text = "CONFIRMAR EQUIPE [%s]  •  %d/5" % [ready_key, _selected_teams[_current_player].size()]
	_ready_button.disabled = _selected_teams[_current_player].size() != 5


func _update_cards() -> void:
	var selected: Array = _selected_teams[_current_player]
	for card_index in _card_buttons.size():
		var data: Dictionary = _catalog[card_index]
		_card_buttons[card_index].visible = card_index in _visible_indices
		var type_color: Color = CreatureDB.color_for_type(str(data["type"]))
		var is_cursor: bool = card_index == _cursor
		var is_selected: bool = selected.has(str(data["id"]))
		var border_color: Color = Color.WHITE if is_selected else type_color
		var background_color: Color = Color(type_color, 0.35) if is_selected else (Color("f3263458") if is_cursor else Color("e7111934"))
		_card_buttons[card_index].add_theme_stylebox_override("normal", UIFactory.style_box(background_color, border_color, 13, 4 if is_cursor or is_selected else 2))
		_card_buttons[card_index].modulate = Color.WHITE if is_cursor or is_selected else Color(0.80, 0.84, 0.94, 0.92)
		var marker := "✓ " if is_selected else ""
		_card_buttons[card_index].text = "%s%s\n%s • %s" % [marker, data["name"], data["type"], _weight_short(str(data["weight_class"]))]


func _update_preview() -> void:
	var creature: Dictionary = _catalog[_cursor]
	var color := CreatureDB.color_for_type(str(creature["type"]))
	_preview_avatar.setup(creature, 1.0)
	_preview_name.text = creature["name"]
	_preview_title.text = "%s • %.1f kg • %s" % [creature["title"], creature["weight_kg"], creature["weight_class"]]
	_preview_type.text = creature["type"].to_upper()
	_preview_type.add_theme_stylebox_override("normal", UIFactory.style_box(color, color.lightened(0.3), 12, 1))
	var strong := ", ".join(MoveDB.strongest_against(str(creature["type"])))
	var weak := ", ".join(MoveDB.vulnerable_to(str(creature["type"])))
	_preview_details.text = "HP %d  •  ATQ %d  DEF %d  RES %d  VEL %d\nFORTE: %s  •  RISCO: %s" % [MoveDB.max_hp(creature), creature["attack"], creature["defense"], creature["resistance"], creature["speed"], strong, weak]
	var move_lines: Array[String] = []
	for move in MoveDB.moves_for_creature(creature):
		move_lines.append("%s [%s/P%02d/R%.1f]" % [move["name"], MoveDB.power_grade(move), move["power"], MoveDB.effective_cooldown(move, creature)])
	_preview_moves.text = "5 GOLPES • 1 PESADO\n" + "  •  ".join(move_lines)


func _update_slots() -> void:
	for child in _team_slots.get_children():
		child.queue_free()
	var selected: Array = _selected_teams[_current_player]
	for slot_index in 5:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(44, 66)
		var color := Color("25304f")
		var label_text := str(slot_index + 1)
		if slot_index < selected.size():
			var creature := CreatureDB.get_creature(selected[slot_index])
			color = CreatureDB.color_for_type(str(creature["type"]))
			label_text = str(creature["name"]).left(3)
		slot.add_theme_stylebox_override("panel", UIFactory.style_box(Color(color, 0.30), color, 10, 2))
		_team_slots.add_child(slot)
		var label := UIFactory.label(label_text, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(label)


func _weight_short(weight_class: String) -> String:
	return {"Ultra Leve":"UL", "Leve":"L", "Médio":"M", "Pesado":"P", "Colossal":"C"}.get(weight_class, "M")
