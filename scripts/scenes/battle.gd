extends Control

const MOVE_COUNT := 5
const GUARD_ACTION := 5
const SWITCH_ACTION := 6
const ACTION_COUNT := 7

var _teams: Array = [[], []]
var _active := [0, 0]
var _turn := 0
var _round := 1
var _busy := true
var _battle_over := false
var _action_cursor := 0
var _avatars: Array[CreatureAvatar] = []
var _name_labels: Array[Label] = []
var _type_labels: Array[Label] = []
var _weight_labels: Array[Label] = []
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _reserve_rows: Array[HBoxContainer] = []
var _score_label: Label
var _turn_label: Label
var _message_label: Label
var _action_buttons: Array[Button] = []


func _ready() -> void:
	_teams[0] = GameState.runtime_team(0)
	_teams[1] = GameState.runtime_team(1)
	if _teams[0].is_empty() or _teams[1].is_empty():
		GameState.begin_mode("training")
		GameState.set_team(0, CreatureDB.random_team())
		GameState.set_team(1, CreatureDB.random_team(5, GameState.team_ids[0]))
		_teams[0] = GameState.runtime_team(0)
		_teams[1] = GameState.runtime_team(1)
	_build_screen()
	_turn = 0 if _fighter(0)["data"]["speed"] >= _fighter(1)["data"]["speed"] else 1
	AudioSynth.start_music("battle")
	_refresh_ui()
	_intro_sequence()


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/battle_arena.png", Color.WHITE, 0.18)

	var top_bar := UIFactory.panel(Color("e8070e26"), Color("775fe6ff"), 18)
	top_bar.position = Vector2(12, 12)
	top_bar.size = Vector2(696, 64)
	add_child(top_bar)
	_turn_label = UIFactory.label("", 18, Color("ffdf47"))
	_turn_label.position = Vector2(14, 8)
	_turn_label.size = Vector2(330, 45)
	top_bar.add_child(_turn_label)
	_score_label = UIFactory.label("", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.position = Vector2(340, 8)
	_score_label.size = Vector2(340, 45)
	top_bar.add_child(_score_label)

	for player in 2:
		var avatar := CreatureAvatar.new()
		add_child(avatar)
		avatar.position = Vector2(350, 196) if player == 1 else Vector2(10, 505)
		avatar.size = Vector2(350, 355) if player == 1 else Vector2(390, 370)
		avatar.setup(_fighter(player)["data"], -1.0 if player == 1 else 1.0)
		_avatars.append(avatar)

	var versus := UIFactory.title("VS", 34, Color("ffdf47"))
	versus.position = Vector2(300, 475)
	versus.size = Vector2(120, 60)
	add_child(versus)
	_build_hud(0, Vector2(20, 735), Color("59e9ff"))
	_build_hud(1, Vector2(20, 88), Color("ff55c6"))

	var message_panel := UIFactory.panel(Color("ef091128"), Color("66ffdf47"), 16)
	message_panel.position = Vector2(20, 865)
	message_panel.size = Vector2(680, 60)
	add_child(message_panel)
	_message_label = UIFactory.label("PREPARE-SE!", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_panel.add_child(_message_label)

	var action_panel := UIFactory.panel(Color("f5070e24"), Color("886ef8ff"), 20)
	action_panel.position = Vector2(20, 938)
	action_panel.size = Vector2(680, 322)
	add_child(action_panel)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.position = Vector2(12, 12)
	action_grid.size = Vector2(656, 298)
	action_grid.add_theme_constant_override("h_separation", 9)
	action_grid.add_theme_constant_override("v_separation", 8)
	action_panel.add_child(action_grid)
	for action_index in ACTION_COUNT:
		var color := Color("bf6cff") if action_index < MOVE_COUNT else (Color("59d7ff") if action_index == GUARD_ACTION else Color("59e98b"))
		var button := UIFactory.button("", color, Vector2(323, 68))
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_theme_constant_override("icon_max_width", 54)
		button.add_theme_constant_override("h_separation", 4)
		button.pressed.connect(_choose_action.bind(action_index))
		action_grid.add_child(button)
		_action_buttons.append(button)


func _build_hud(player: int, at_position: Vector2, accent: Color) -> void:
	var panel := UIFactory.panel(Color("f00a1430"), Color(accent, 0.82), 18)
	panel.position = at_position
	panel.size = Vector2(680, 122)
	add_child(panel)
	var player_label := UIFactory.label("JOGADOR %d" % (player + 1) if GameState.is_human_player(player) else "CPU TÁTICA", 12, accent)
	player_label.position = Vector2(14, 7)
	player_label.size = Vector2(140, 22)
	panel.add_child(player_label)
	var name_label := UIFactory.label("", 23, Color.WHITE)
	name_label.position = Vector2(14, 28)
	name_label.size = Vector2(285, 34)
	panel.add_child(name_label)
	_name_labels.append(name_label)
	var type_label := UIFactory.badge("", accent)
	type_label.position = Vector2(500, 11)
	type_label.size = Vector2(150, 31)
	panel.add_child(type_label)
	_type_labels.append(type_label)
	var weight_label := UIFactory.label("", 12, Color("ffdf73"), HORIZONTAL_ALIGNMENT_RIGHT)
	weight_label.position = Vector2(330, 45)
	weight_label.size = Vector2(320, 24)
	panel.add_child(weight_label)
	_weight_labels.append(weight_label)
	var hp_bar := ProgressBar.new()
	hp_bar.position = Vector2(14, 72)
	hp_bar.size = Vector2(490, 25)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", UIFactory.style_box(Color("e5070b1c"), Color("465675"), 9, 1))
	panel.add_child(hp_bar)
	_hp_bars.append(hp_bar)
	var hp_label := UIFactory.label("", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	hp_label.position = Vector2(505, 68)
	hp_label.size = Vector2(145, 31)
	panel.add_child(hp_label)
	_hp_labels.append(hp_label)
	var reserve := HBoxContainer.new()
	reserve.position = Vector2(14, 100)
	reserve.size = Vector2(300, 18)
	reserve.add_theme_constant_override("separation", 8)
	panel.add_child(reserve)
	_reserve_rows.append(reserve)


func _intro_sequence() -> void:
	_busy = true
	_avatars[0].modulate.a = 0.0
	_avatars[1].modulate.a = 0.0
	_message_label.text = "BEASTS ENTRANDO NA ARENA 2.5D"
	var entrance := create_tween()
	entrance.set_parallel(true)
	entrance.tween_property(_avatars[0], "modulate:a", 1.0, 0.42)
	entrance.tween_property(_avatars[0], "position:x", 10.0, 0.48).from(-170.0).set_trans(Tween.TRANS_BACK)
	entrance.tween_property(_avatars[1], "modulate:a", 1.0, 0.42).set_delay(0.16)
	entrance.tween_property(_avatars[1], "position:x", 350.0, 0.52).from(690.0).set_delay(0.16).set_trans(Tween.TRANS_BACK)
	await entrance.finished
	await _avatars[_turn].play_celebration()
	_message_label.text = "COMEÇA %s • MAIOR VELOCIDADE" % _fighter(_turn)["data"]["name"]
	_busy = false
	_refresh_ui()
	_maybe_run_cpu()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _battle_over or not GameState.is_human_player(_turn):
		return
	var prefix := "p1_" if _turn == 0 else "p2_"
	if event.is_action_pressed(prefix + "left"):
		_action_cursor = wrapi(_action_cursor - 1, 0, ACTION_COUNT)
		AudioSynth.ui_move()
		_refresh_actions()
	elif event.is_action_pressed(prefix + "right"):
		_action_cursor = wrapi(_action_cursor + 1, 0, ACTION_COUNT)
		AudioSynth.ui_move()
		_refresh_actions()
	elif event.is_action_pressed(prefix + "up"):
		_action_cursor = wrapi(_action_cursor - 2, 0, ACTION_COUNT)
		AudioSynth.ui_move()
		_refresh_actions()
	elif event.is_action_pressed(prefix + "down"):
		_action_cursor = wrapi(_action_cursor + 2, 0, ACTION_COUNT)
		AudioSynth.ui_move()
		_refresh_actions()
	elif event.is_action_pressed(prefix + "confirm"):
		_choose_action(_action_cursor)


func _choose_action(action_index: int) -> void:
	if _busy or _battle_over:
		return
	if action_index < MOVE_COUNT:
		var move := _move_for_action(_turn, action_index)
		if move.is_empty() or not MoveDB.can_use(_fighter(_turn), move):
			var left := MoveDB.cooldown_turns(MoveDB.cooldown_left(_fighter(_turn), str(move.get("id", ""))))
			_message_label.text = "GOLPE EM RECARGA • AGUARDE %d TURNO(S)" % left
			AudioSynth.ui_cancel()
			return
	_busy = true
	await _execute_action(action_index)
	if _battle_over:
		return
	_turn = 1 - _turn
	MoveDB.reduce_cooldowns(_fighter(_turn))
	_round += 1
	_action_cursor = 0
	_busy = false
	_refresh_ui()
	_maybe_run_cpu()


func _execute_action(action_index: int) -> void:
	if action_index < MOVE_COUNT:
		await _attack_with_move(action_index)
	elif action_index == GUARD_ACTION:
		await _defend()
	else:
		await _switch_creature()


func _attack_with_move(move_index: int) -> void:
	var attacker := _fighter(_turn)
	var target_player := 1 - _turn
	var defender := _fighter(target_player)
	var move := _move_for_action(_turn, move_index)
	var multiplier := CreatureDB.type_multiplier(str(move["element"]), str(defender["data"]["type"]))
	var damage := maxi(5, MoveDB.damage_preview(attacker, defender, move) + randi_range(-2, 2))
	if bool(defender["guard"]):
		damage = maxi(4, roundi(damage * 0.48))
		defender["guard"] = false
	MoveDB.set_cooldown(attacker, move)
	_message_label.text = "%s USA %s" % [attacker["data"]["name"], str(move["name"]).to_upper()]
	await _avatars[_turn].play_attack()
	await _spawn_skill_effect(_turn, target_player, move)
	defender["hp"] = maxi(0, int(defender["hp"]) - damage)
	defender["round_damage"] = int(defender["round_damage"]) + damage
	GameState.scores[_turn] += damage * (2 if str(move["role"]) == "pesado" else 1)
	var effectiveness := CreatureDB.effectiveness_text(multiplier)
	_spawn_hit(target_player, CreatureDB.color_for_type(str(move["element"])), "%d • %s" % [damage, effectiveness])
	if str(move["role"]) == "pesado":
		AudioSynth.special_hit()
	else:
		AudioSynth.hit(clampf(float(damage) / 45.0, 0.7, 1.25))
	await _avatars[target_player].play_damage()
	_refresh_ui()
	if int(defender["hp"]) <= 0:
		await _handle_knockout(target_player)
	else:
		await get_tree().create_timer(0.22).timeout


func _defend() -> void:
	var fighter := _fighter(_turn)
	fighter["guard"] = true
	_message_label.text = "%s ERGUEU UMA BARREIRA" % fighter["data"]["name"]
	AudioSynth.guard()
	_avatars[_turn].selected_glow = true
	await get_tree().create_timer(0.48).timeout
	_avatars[_turn].selected_glow = false


func _switch_creature() -> void:
	var next_index := _next_alive(_turn, _active[_turn])
	if next_index == -1 or next_index == _active[_turn]:
		_message_label.text = "NÃO HÁ OUTRA BEAST DISPONÍVEL"
		AudioSynth.ui_cancel()
		await get_tree().create_timer(0.42).timeout
		return
	_active[_turn] = next_index
	var new_fighter := _fighter(_turn)
	_avatars[_turn].reset_pose()
	_avatars[_turn].setup(new_fighter["data"], 1.0 if _turn == 0 else -1.0)
	_message_label.text = "%s ENTRA NA ARENA" % new_fighter["data"]["name"]
	AudioSynth.ui_confirm()
	await _avatars[_turn].play_celebration()


func _handle_knockout(defeated_player: int) -> void:
	var defeated_fighter := _fighter(defeated_player)
	defeated_fighter["ko"] = true
	GameState.scores[1 - defeated_player] += 250
	_message_label.text = "%s FORA DE COMBATE!" % defeated_fighter["data"]["name"]
	AudioSynth.knockout()
	await _avatars[defeated_player].play_defeat()
	var next_index := _next_alive(defeated_player, _active[defeated_player])
	if next_index == -1:
		await _finish_battle(1 - defeated_player)
		return
	_active[defeated_player] = next_index
	var next_fighter := _fighter(defeated_player)
	_avatars[defeated_player].reset_pose()
	_avatars[defeated_player].setup(next_fighter["data"], 1.0 if defeated_player == 0 else -1.0)
	_message_label.text = "%s ASSUME O DUELO" % next_fighter["data"]["name"]
	_refresh_ui()
	await _avatars[defeated_player].play_celebration()


func _finish_battle(winner_player: int) -> void:
	_battle_over = true
	_busy = true
	GameState.winner = winner_player
	GameState.scores[winner_player] += 1000
	GameState.battle_summary = {"rounds":_round, "remaining":_remaining_count(winner_player), "winner_creature":_fighter(winner_player)["id"]}
	_message_label.text = "%s VENCEU A BATALHA!" % _player_title(winner_player)
	AudioSynth.stop_music()
	AudioSynth.victory()
	await _avatars[winner_player].play_celebration()
	await get_tree().create_timer(0.75).timeout
	Transition.go_to(GameState.RESULTS_SCENE, "RESULTADO DA ARENA")


func _maybe_run_cpu() -> void:
	if _battle_over or GameState.is_human_player(_turn):
		return
	_busy = true
	_message_label.text = "CPU CALCULANDO PESO, TIPO E RECARGA..."
	_run_cpu_turn()


func _run_cpu_turn() -> void:
	await get_tree().create_timer(0.62).timeout
	var choice := _cpu_choice()
	await _execute_action(choice)
	if _battle_over:
		return
	_turn = 1 - _turn
	MoveDB.reduce_cooldowns(_fighter(_turn))
	_round += 1
	_action_cursor = 0
	_busy = false
	_refresh_ui()


func _cpu_choice() -> int:
	var cpu := _fighter(_turn)
	var opponent := _fighter(1 - _turn)
	if float(cpu["hp"]) / float(cpu["max_hp"]) < 0.24 and _next_alive(_turn, _active[_turn]) != -1 and randf() < 0.34:
		return SWITCH_ACTION
	if randf() < 0.10:
		return GUARD_ACTION
	var best_index := -1
	var best_score := -9999.0
	for move_index in MOVE_COUNT:
		var move := _move_for_action(_turn, move_index)
		if not MoveDB.can_use(cpu, move):
			continue
		var damage := float(MoveDB.damage_preview(cpu, opponent, move))
		var cooldown_penalty := MoveDB.effective_cooldown(move, cpu) * 1.7
		var finisher_bonus := 14.0 if damage >= float(opponent["hp"]) else 0.0
		var score := damage - cooldown_penalty + finisher_bonus + randf_range(-1.8, 1.8)
		if score > best_score:
			best_score = score
			best_index = move_index
	return best_index if best_index >= 0 else GUARD_ACTION


func _fighter(player: int) -> Dictionary:
	return _teams[player][_active[player]]


func _move_for_action(player: int, action_index: int) -> Dictionary:
	var move_ids: Array = _fighter(player)["data"].get("moves", [])
	if action_index < 0 or action_index >= move_ids.size():
		return {}
	return MoveDB.get_move(str(move_ids[action_index]))


func _next_alive(player: int, after_index: int) -> int:
	for step in range(1, _teams[player].size() + 1):
		var index: int = (after_index + step) % _teams[player].size()
		if not bool(_teams[player][index]["ko"]):
			return index
	return -1


func _remaining_count(player: int) -> int:
	var count := 0
	for fighter in _teams[player]:
		if not bool(fighter["ko"]):
			count += 1
	return count


func _player_title(player: int) -> String:
	return "JOGADOR %d" % (player + 1) if GameState.is_human_player(player) else "CPU"


func _spawn_hit(target_player: int, color: Color, caption: String) -> void:
	var burst := HitBurst.new()
	add_child(burst)
	var hit_position := _avatars[target_player].position + _avatars[target_player].size * Vector2(0.5, 0.48)
	burst.burst(hit_position, color, caption)


func _spawn_skill_effect(attacker_player: int, target_player: int, move: Dictionary) -> void:
	var effect := ElementSkillFX.new()
	add_child(effect)
	var from := _avatars[attacker_player].position + _avatars[attacker_player].size * Vector2(0.5, 0.45)
	var to := _avatars[target_player].position + _avatars[target_player].size * Vector2(0.5, 0.46)
	await effect.launch(from, to, move)


func _refresh_ui() -> void:
	for player in 2:
		var fighter := _fighter(player)
		var data: Dictionary = fighter["data"]
		_name_labels[player].text = data["name"]
		var type_color := CreatureDB.color_for_type(str(data["type"]))
		_type_labels[player].text = str(data["type"]).to_upper()
		_type_labels[player].add_theme_stylebox_override("normal", UIFactory.style_box(type_color, type_color.lightened(0.28), 12, 1))
		_weight_labels[player].text = "%s • %.1f kg • %s" % [data["weight_class"], data["weight_kg"], MoveDB.weight_profile(data)["label"]]
		_hp_bars[player].max_value = fighter["max_hp"]
		_hp_bars[player].value = fighter["hp"]
		var hp_ratio := float(fighter["hp"]) / float(fighter["max_hp"])
		var hp_color := Color("52e788") if hp_ratio > 0.5 else (Color("ffca47") if hp_ratio > 0.22 else Color("ff536d"))
		_hp_bars[player].add_theme_stylebox_override("fill", UIFactory.style_box(hp_color, hp_color.lightened(0.25), 9, 1))
		_hp_labels[player].text = "VIDA %d/%d" % [fighter["hp"], fighter["max_hp"]]
		_refresh_reserves(player)
	_turn_label.text = "TURNO %02d • %s" % [_round, _player_title(_turn)]
	_turn_label.add_theme_color_override("font_color", Color("6ef8ff") if _turn == 0 else Color("ff55c6"))
	_score_label.text = "P1 %05d  ×  %05d P2" % [GameState.scores[0], GameState.scores[1]]
	_refresh_actions()


func _refresh_reserves(player: int) -> void:
	for child in _reserve_rows[player].get_children():
		child.queue_free()
	for fighter_index in _teams[player].size():
		var fighter: Dictionary = _teams[player][fighter_index]
		var dot := Label.new()
		dot.text = "◆" if fighter_index == _active[player] else "●"
		dot.add_theme_font_size_override("font_size", 14)
		var color := Color("ff506c") if fighter["ko"] else CreatureDB.color_for_type(str(fighter["data"]["type"]))
		dot.add_theme_color_override("font_color", color)
		_reserve_rows[player].add_child(dot)


func _refresh_actions() -> void:
	if _action_buttons.is_empty():
		return
	var fighter := _fighter(_turn)
	for move_index in MOVE_COUNT:
		var move := _move_for_action(_turn, move_index)
		var cooldown := MoveDB.cooldown_left(fighter, str(move["id"]))
		var status := "PRONTO" if cooldown <= 0.001 else "CD %d" % MoveDB.cooldown_turns(cooldown)
		_action_buttons[move_index].text = "%s\n%s • P%02d • %s" % [str(move["name"]).to_upper(), MoveDB.power_grade(move), move["power"], status]
		_action_buttons[move_index].icon = load(str(move["icon"])) as Texture2D
		_action_buttons[move_index].disabled = cooldown > 0.001
	_action_buttons[GUARD_ACTION].text = "DEFENDER\nREDUZ 52% DO DANO"
	_action_buttons[GUARD_ACTION].icon = load("res://assets/actions/guard.svg") as Texture2D
	_action_buttons[SWITCH_ACTION].text = "TROCAR\nPRÓXIMA BEAST"
	_action_buttons[SWITCH_ACTION].icon = load("res://assets/actions/switch.svg") as Texture2D
	for action_index in _action_buttons.size():
		var selected := action_index == _action_cursor
		_action_buttons[action_index].modulate = Color.WHITE if selected else Color(0.70, 0.75, 0.88)
		_action_buttons[action_index].scale = Vector2(1.018, 1.018) if selected else Vector2.ONE
	var controls_enabled := not _busy and not _battle_over and GameState.is_human_player(_turn)
	for button in _action_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if controls_enabled else Control.MOUSE_FILTER_IGNORE
