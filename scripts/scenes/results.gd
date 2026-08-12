extends Control

var _buttons: Array[Button] = []
var _selected := 0
var _locked := false


func _ready() -> void:
	_build_screen()
	AudioSynth.start_music("victory")
	_update_selection(false)


func _build_screen() -> void:
	var winner: int = GameState.winner
	var winner_color := Color("6ef8ff") if winner == 0 else Color("ff55c6")
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/victory_stage.png", Color.WHITE, 0.25)

	var top := UIFactory.label("RESULTADO OFICIAL DA ARENA", 16, Color("ffdf47"), HORIZONTAL_ALIGNMENT_CENTER)
	top.position = Vector2(40, 28)
	top.size = Vector2(640, 34)
	add_child(top)
	var winner_name := "JOGADOR %d" % (winner + 1) if GameState.is_human_player(winner) else "CPU"
	var champion := UIFactory.title("%s VENCEU!" % winner_name, 45, Color.WHITE)
	champion.position = Vector2(35, 68)
	champion.size = Vector2(650, 62)
	champion.add_theme_color_override("font_outline_color", winner_color.darkened(0.35))
	champion.add_theme_constant_override("outline_size", 7)
	add_child(champion)

	var creature_id := str(GameState.battle_summary.get("winner_creature", GameState.team_ids[winner][0]))
	var creature := CreatureDB.get_creature(creature_id)
	var avatar := CreatureAvatar.new()
	add_child(avatar)
	avatar.position = Vector2(100, 145)
	avatar.size = Vector2(520, 500)
	avatar.setup(creature, 1.0)
	avatar.selected_glow = true
	avatar.play_celebration()

	var info_panel := UIFactory.panel(Color("ed09132e"), Color(winner_color, 0.86), 26)
	info_panel.position = Vector2(45, 625)
	info_panel.size = Vector2(630, 320)
	add_child(info_panel)
	var creature_name := UIFactory.title(str(creature["name"]), 36, winner_color)
	creature_name.position = Vector2(20, 15)
	creature_name.size = Vector2(590, 48)
	info_panel.add_child(creature_name)
	var type_badge := UIFactory.badge(str(creature["type"]).to_upper(), CreatureDB.color_for_type(str(creature["type"])))
	type_badge.position = Vector2(205, 68)
	type_badge.size = Vector2(220, 36)
	info_panel.add_child(type_badge)
	var weight := UIFactory.label("%s • %.1f kg • VIDA MÁXIMA %d" % [creature["weight_class"], creature["weight_kg"], MoveDB.max_hp(creature)], 15, Color("ffe27a"), HORIZONTAL_ALIGNMENT_CENTER)
	weight.position = Vector2(35, 112)
	weight.size = Vector2(560, 32)
	info_panel.add_child(weight)
	var stats := UIFactory.label("PONTUAÇÃO J1  %05d     PONTUAÇÃO J2  %05d\nTURNOS  %02d     BEASTS RESTANTES  %d\nCARTA  %s" % [GameState.scores[0], GameState.scores[1], GameState.battle_summary.get("rounds", 0), GameState.battle_summary.get("remaining", 0), creature["card_code"]], 17, Color("eaf2ff"), HORIZONTAL_ALIGNMENT_CENTER)
	stats.position = Vector2(35, 152)
	stats.size = Vector2(560, 132)
	stats.add_theme_stylebox_override("normal", UIFactory.style_box(Color("b8080d20"), Color("4c6481aa"), 16, 1))
	info_panel.add_child(stats)

	var options := [["REVANCHE", winner_color], ["NOVAS EQUIPES", Color("ffdf47")], ["MENU PRINCIPAL", Color("a878ff")]]
	var column := VBoxContainer.new()
	column.position = Vector2(55, 975)
	column.size = Vector2(610, 240)
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	for button_index in options.size():
		var button := UIFactory.button(options[button_index][0], options[button_index][1], Vector2(610, 70))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_choose.bind(button_index))
		column.add_child(button)
		_buttons.append(button)

	var footer := UIFactory.label("▲/▼ ESCOLHER • CONFIRMAR", 13, Color("d3deef"), HORIZONTAL_ALIGNMENT_CENTER)
	footer.position = Vector2(70, 1225)
	footer.size = Vector2(580, 30)
	add_child(footer)


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("p1_up") or event.is_action_pressed("p2_up") or event.is_action_pressed("p1_left") or event.is_action_pressed("p2_left"):
		_selected = wrapi(_selected - 1, 0, _buttons.size())
		_update_selection()
	elif event.is_action_pressed("p1_down") or event.is_action_pressed("p2_down") or event.is_action_pressed("p1_right") or event.is_action_pressed("p2_right"):
		_selected = wrapi(_selected + 1, 0, _buttons.size())
		_update_selection()
	elif event.is_action_pressed("p1_confirm") or event.is_action_pressed("p2_confirm") or event.is_action_pressed("start"):
		_choose(_selected)


func _update_selection(play_sound: bool = true) -> void:
	for button_index in _buttons.size():
		_buttons[button_index].modulate = Color.WHITE if button_index == _selected else Color(0.66, 0.70, 0.84)
		_buttons[button_index].scale = Vector2(1.018, 1.018) if button_index == _selected else Vector2.ONE
	if play_sound:
		AudioSynth.ui_move()


func _choose(option: int) -> void:
	if _locked:
		return
	_locked = true
	AudioSynth.ui_confirm()
	match option:
		0:
			GameState.scores = [0, 0]
			GameState.winner = 0
			GameState.battle_summary = {}
			Transition.go_to(GameState.BATTLE_SCENE, "REVANCHE")
		1:
			if GameState.mode == "training":
				GameState.scores = [0, 0]
				GameState.winner = 0
				GameState.battle_summary = {}
				GameState.set_team(0, CreatureDB.random_team())
				GameState.set_team(1, CreatureDB.random_team(5, GameState.team_ids[0]))
				Transition.go_to(GameState.BATTLE_SCENE, "NOVO SORTEIO")
			else:
				GameState.reset_match()
				Transition.go_to(GameState.TEAM_SCENE, "NOVAS EQUIPES")
		_:
			GameState.reset_match()
			Transition.go_to(GameState.OPENING_SCENE, "VOLTANDO AO INÍCIO")
