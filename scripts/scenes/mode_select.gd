extends Control

const MODES := [
	{"id":"pvp", "title":"DUELO LOCAL", "tag":"2 JOGADORES", "description":"Cada jogador lê ou escolhe 5 Beasts. Estratégia, recarga e trocas cara a cara.", "color":Color("ff4fc8"), "icon":"⚔"},
	{"id":"cpu", "title":"DESAFIO CPU", "tag":"1 JOGADOR", "description":"Monte sua equipe e enfrente um bot que avalia peso, recarga e vantagem elemental.", "color":Color("6ef8ff"), "icon":"◆"},
	{"id":"training", "title":"BATALHA RÁPIDA", "tag":"TREINO", "description":"Equipes sorteadas e combate imediato para aprender os 80 golpes e oito elementos.", "color":Color("ffdf47"), "icon":"▶"},
	{"id":"guide", "title":"GUIA DE PODERES", "tag":"ENCICLOPÉDIA", "description":"Veja os dez golpes de cada elemento, poder, recarga, função, forças e fraquezas.", "color":Color("a970ff"), "icon":"◎"}
]

var _cards: Array[Button] = []
var _selected := 0
var _locked := false


func _ready() -> void:
	_build_screen()
	_update_selection(false)
	AudioSynth.start_music("menu")


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/selection_archive.png", Color.WHITE, 0.32)

	var title := UIFactory.title("ESCOLHA O MODO", 42, Color.WHITE)
	title.position = Vector2(40, 32)
	title.size = Vector2(640, 58)
	add_child(title)
	var subtitle := UIFactory.label("ARCADE VERTICAL • SISTEMAS ATÔMICOS", 16, Color("89eefa"), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.position = Vector2(40, 90)
	subtitle.size = Vector2(640, 34)
	add_child(subtitle)

	var column := VBoxContainer.new()
	column.position = Vector2(35, 150)
	column.size = Vector2(650, 960)
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	for mode_index in MODES.size():
		var mode_data: Dictionary = MODES[mode_index]
		var card := Button.new()
		card.custom_minimum_size = Vector2(650, 220)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal", UIFactory.style_box(Color("e30f1733"), Color(mode_data["color"], 0.62), 28, 3))
		card.add_theme_stylebox_override("hover", UIFactory.style_box(Color("f21b2852"), mode_data["color"], 28, 5))
		card.add_theme_stylebox_override("pressed", UIFactory.style_box(Color(mode_data["color"], 0.30), Color.WHITE, 28, 5))
		card.pressed.connect(_choose.bind(mode_index))
		column.add_child(card)
		_cards.append(card)

		var icon := UIFactory.title(str(mode_data["icon"]), 58, mode_data["color"])
		icon.position = Vector2(18, 35)
		icon.size = Vector2(120, 120)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var mode_title := UIFactory.label(str(mode_data["title"]), 27, Color.WHITE)
		mode_title.position = Vector2(145, 28)
		mode_title.size = Vector2(455, 42)
		mode_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(mode_title)
		var badge := UIFactory.badge(str(mode_data["tag"]), mode_data["color"])
		badge.position = Vector2(145, 76)
		badge.size = Vector2(190, 32)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		var description := UIFactory.label(str(mode_data["description"]), 16, Color("e1ebff"))
		description.position = Vector2(145, 118)
		description.size = Vector2(455, 74)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(description)

	var help := UIFactory.label("▲/▼ NAVEGAR  •  CONFIRMAR  •  Q VOLTAR", 15, Color("d4e0f3"), HORIZONTAL_ALIGNMENT_CENTER)
	help.position = Vector2(45, 1182)
	help.size = Vector2(630, 42)
	add_child(help)


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("p1_up") or event.is_action_pressed("p2_up") or event.is_action_pressed("p1_left") or event.is_action_pressed("p2_left"):
		_selected = wrapi(_selected - 1, 0, MODES.size())
		_update_selection()
	elif event.is_action_pressed("p1_down") or event.is_action_pressed("p2_down") or event.is_action_pressed("p1_right") or event.is_action_pressed("p2_right"):
		_selected = wrapi(_selected + 1, 0, MODES.size())
		_update_selection()
	elif event.is_action_pressed("p1_confirm") or event.is_action_pressed("p2_confirm") or event.is_action_pressed("start"):
		_choose(_selected)
	elif event.is_action_pressed("p1_cancel") or event.is_action_pressed("p2_cancel"):
		AudioSynth.ui_cancel()
		Transition.go_to(GameState.OPENING_SCENE, "VOLTANDO")


func _update_selection(play_sound: bool = true) -> void:
	for card_index in _cards.size():
		var mode_data: Dictionary = MODES[card_index]
		var selected := card_index == _selected
		_cards[card_index].scale = Vector2(1.018, 1.018) if selected else Vector2.ONE
		_cards[card_index].modulate = Color.WHITE if selected else Color(0.68, 0.73, 0.88, 0.88)
		_cards[card_index].add_theme_stylebox_override("normal", UIFactory.style_box(Color("f11b2852") if selected else Color("e30f1733"), mode_data["color"] if selected else Color(mode_data["color"], 0.48), 28, 5 if selected else 2))
	if play_sound:
		AudioSynth.ui_move()


func _choose(mode_index: int) -> void:
	if _locked:
		return
	_locked = true
	_selected = mode_index
	_update_selection(false)
	AudioSynth.ui_confirm()
	var selected_mode := str(MODES[mode_index]["id"])
	if selected_mode == "guide":
		Transition.go_to(GameState.POWER_GUIDE_SCENE, "ABRINDO O GUIA")
		return
	GameState.begin_mode(selected_mode)
	if selected_mode == "training":
		GameState.set_team(0, CreatureDB.random_team())
		GameState.set_team(1, CreatureDB.random_team(5, GameState.team_ids[0]))
		Transition.go_to(GameState.BATTLE_SCENE, "BATALHA RÁPIDA")
	else:
		Transition.go_to(GameState.TEAM_SCENE, "MONTE SUA EQUIPE")
