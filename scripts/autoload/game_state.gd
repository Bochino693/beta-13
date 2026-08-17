extends Node

const BRAND_SCENE := "res://scenes/brand_intro.tscn"
const OPENING_SCENE := "res://scenes/opening.tscn"
const MODE_SCENE := "res://scenes/mode_select.tscn"
const TEAM_SCENE := "res://scenes/team_select.tscn"
const BATTLE_SCENE := "res://scenes/battle.tscn"
const RESULTS_SCENE := "res://scenes/results.tscn"
const POWER_GUIDE_SCENE := "res://scenes/power_guide.tscn"
const SETTINGS_PATH := "user://lazer_beasts_settings.json"

var mode := "pvp"
var arena_id := "auto"
var team_ids: Array = [[], []]
var winner := 0
var scores := [0, 0]
var battle_summary: Dictionary = {}
var credits := 0
var free_play := true
var sound_enabled := true


func _ready() -> void:
	_ensure_input_map()
	_load_settings()


func reset_match() -> void:
	team_ids = [[], []]
	arena_id = "auto"
	winner = 0
	scores = [0, 0]
	battle_summary = {}


func begin_mode(selected_mode: String) -> void:
	reset_match()
	mode = selected_mode


func set_team(player_index: int, ids: Array) -> void:
	team_ids[player_index] = ids.duplicate()


func set_arena(selected_arena_id: String) -> void:
	arena_id = selected_arena_id if ArenaDB.has_arena(selected_arena_id) else ArenaDB.AUTO_ID


func resolve_arena_for_battle() -> String:
	arena_id = ArenaDB.resolve_id(arena_id)
	return arena_id


func runtime_team(player_index: int) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for creature_id in team_ids[player_index]:
		output.append(CreatureDB.make_fighter(creature_id))
	return output


func is_human_player(player_index: int) -> bool:
	if player_index == 0:
		return true
	return mode == "pvp"


func add_credit(amount: int = 1) -> void:
	credits += amount
	AudioSynth.coin()


func can_start() -> bool:
	return free_play or credits > 0


func consume_credit() -> bool:
	if free_play:
		return true
	if credits <= 0:
		return false
	credits -= 1
	return true


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"free_play": free_play,
			"sound_enabled": sound_enabled
		}, "\t"))


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		free_play = bool(parsed.get("free_play", true))
		sound_enabled = bool(parsed.get("sound_enabled", true))


func _ensure_input_map() -> void:
	_add_key("start", KEY_1)
	_add_key("coin", KEY_5)
	_add_key("operator_free_play", KEY_F10)
	_add_key("operator_sound", KEY_F11)
	_add_key("operator_fullscreen", KEY_F12)
	_add_key("filter_next", KEY_TAB)
	_add_key("p1_up", KEY_W)
	_add_key("p1_down", KEY_S)
	_add_key("p1_left", KEY_A)
	_add_key("p1_right", KEY_D)
	_add_key("p1_confirm", KEY_SPACE)
	_add_key("p1_cancel", KEY_Q)
	_add_key("p1_ready", KEY_E)
	_add_key("p2_up", KEY_UP)
	_add_key("p2_down", KEY_DOWN)
	_add_key("p2_left", KEY_LEFT)
	_add_key("p2_right", KEY_RIGHT)
	_add_key("p2_confirm", KEY_ENTER)
	_add_key("p2_cancel", KEY_N)
	_add_key("p2_ready", KEY_M)
	_add_joy_button("start", 0, JOY_BUTTON_START)
	_add_joy_button("p1_confirm", 0, JOY_BUTTON_A)
	_add_joy_button("p1_cancel", 0, JOY_BUTTON_B)
	_add_joy_button("p1_ready", 0, JOY_BUTTON_Y)
	_add_joy_button("filter_next", 0, JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("p1_up", 0, JOY_BUTTON_DPAD_UP)
	_add_joy_button("p1_down", 0, JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("p1_left", 0, JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("p1_right", 0, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("p2_confirm", 1, JOY_BUTTON_A)
	_add_joy_button("p2_cancel", 1, JOY_BUTTON_B)
	_add_joy_button("p2_ready", 1, JOY_BUTTON_Y)
	_add_joy_button("filter_next", 1, JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("p2_up", 1, JOY_BUTTON_DPAD_UP)
	_add_joy_button("p2_down", 1, JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("p2_left", 1, JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("p2_right", 1, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_motion("p1_left", 0, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("p1_right", 0, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_motion("p1_up", 0, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_motion("p1_down", 0, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_motion("p2_left", 1, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion("p2_right", 1, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_motion("p2_up", 1, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_motion("p2_down", 1, JOY_AXIS_LEFT_Y, 1.0)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.45)


func _add_key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_joy_button(action: StringName, device: int, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_motion(action: StringName, device: int, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("coin"):
		add_credit()
	elif event.is_action_pressed("operator_free_play"):
		free_play = not free_play
		save_settings()
		AudioSynth.ui_confirm()
		print("ELEMENTAL BEASTS • Modo livre: ", "LIGADO" if free_play else "DESLIGADO")
	elif event.is_action_pressed("operator_sound"):
		sound_enabled = not sound_enabled
		save_settings()
		AudioSynth.set_enabled(sound_enabled)
		if sound_enabled:
			AudioSynth.ui_confirm()
		print("ELEMENTAL BEASTS • Som: ", "LIGADO" if sound_enabled else "DESLIGADO")
	elif event.is_action_pressed("operator_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
