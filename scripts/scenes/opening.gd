extends Control

var _start_button: Button
var _credit_label: Label
var _warning_label: Label
var _starting := false


func _ready() -> void:
	_build_screen()
	AudioSynth.start_music("menu")


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/opening_portal.png", Color.WHITE, 0.28)

	var brand := UIFactory.label("LAZER & SPORT  •  APRESENTA", 16, Color("ffdd47"), HORIZONTAL_ALIGNMENT_CENTER)
	brand.position = Vector2(30, 20)
	brand.size = Vector2(660, 38)
	add_child(brand)

	var title_plate := UIFactory.panel(Color("081028d6"), Color("75ecffaa"), 28)
	title_plate.position = Vector2(35, 58)
	title_plate.size = Vector2(650, 222)
	add_child(title_plate)
	var game_icon := TextureRect.new()
	game_icon.position = Vector2(275, 10)
	game_icon.size = Vector2(100, 100)
	game_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_icon.texture = load("res://assets/branding/elemental_beasts_icon.png") as Texture2D
	title_plate.add_child(game_icon)
	var title := UIFactory.title("ELEMENTAL BEASTS", 46, Color("f8fbff"))
	title.position = Vector2(0, 105)
	title.size = Vector2(650, 60)
	title.add_theme_color_override("font_outline_color", Color("762bca"))
	title.add_theme_constant_override("outline_size", 7)
	title_plate.add_child(title)
	var subtitle := UIFactory.title("ARENA ELEMENTAL", 24, Color("ffe14c"))
	subtitle.position = Vector2(0, 160)
	subtitle.size = Vector2(650, 36)
	title_plate.add_child(subtitle)
	var summary := UIFactory.label("30 BEASTS  •  8 ELEMENTOS  •  EQUIPES 5 × 5", 13, Color("80f6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	summary.position = Vector2(0, 194)
	summary.size = Vector2(650, 24)
	title_plate.add_child(summary)

	var showcase := [
		["pyrocondor", Vector2(-18, 322), Vector2(300, 350), 1.0, 0.92],
		["helionce", Vector2(155, 300), Vector2(410, 390), 1.0, 1.0],
		["prismara", Vector2(446, 320), Vector2(292, 350), -1.0, 0.92]
	]
	for item in showcase:
		var avatar := CreatureAvatar.new()
		add_child(avatar)
		avatar.position = item[1]
		avatar.size = item[2]
		avatar.modulate.a = item[4]
		avatar.setup(CreatureDB.get_creature(item[0]), item[3])

	var types_panel := UIFactory.panel(Color("071025bd"), Color("6ef8ff55"), 22)
	types_panel.position = Vector2(30, 700)
	types_panel.size = Vector2(660, 164)
	add_child(types_panel)
	var type_grid := GridContainer.new()
	type_grid.columns = 8
	type_grid.position = Vector2(12, 18)
	type_grid.size = Vector2(636, 126)
	type_grid.add_theme_constant_override("h_separation", 5)
	types_panel.add_child(type_grid)
	## Emblema desenhado em vetor, sem o quadrado opaco e sem o nome
	## queimado na imagem que os PNGs de type_icons carregavam.
	for element in CreatureDB.ELEMENTS:
		var coluna := VBoxContainer.new()
		coluna.custom_minimum_size = Vector2(74, 112)
		coluna.add_theme_constant_override("separation", 2)
		coluna.tooltip_text = element
		type_grid.add_child(coluna)

		var emblema := TypeEmblem.new()
		emblema.element = element
		emblema.custom_minimum_size = Vector2(74, 74)
		coluna.add_child(emblema)

		var nome := UIFactory.label(
			element.to_upper(), 10, CreatureDB.color_for_type(element).lightened(0.30),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		nome.custom_minimum_size = Vector2(74, 20)
		coluna.add_child(nome)

	_start_button = UIFactory.button("ENTRAR NA ARENA", Color("ff4fc8"), Vector2(620, 108))
	_start_button.position = Vector2(50, 895)
	_start_button.size = Vector2(620, 108)
	_start_button.add_theme_font_size_override("font_size", 28)
	_start_button.pressed.connect(_try_start)
	add_child(_start_button)
	## O foco so existe dentro da arvore: pedir antes do add_child derrubava
	## "Condition !is_inside_tree() is true" e deixava a tela sem foco algum.
	_start_button.grab_focus()
	var pulse := create_tween().set_loops()
	pulse.tween_property(_start_button, "modulate", Color(1, 1, 1, 0.60), 0.55)
	pulse.tween_property(_start_button, "modulate", Color.WHITE, 0.55)

	_warning_label = UIFactory.label("", 18, Color("ff708f"), HORIZONTAL_ALIGNMENT_CENTER)
	_warning_label.position = Vector2(55, 1010)
	_warning_label.size = Vector2(610, 38)
	add_child(_warning_label)
	_credit_label = UIFactory.label("", 17, Color("9cefff"), HORIZONTAL_ALIGNMENT_CENTER)
	_credit_label.position = Vector2(40, 1060)
	_credit_label.size = Vector2(640, 40)
	add_child(_credit_label)
	_update_credit_label()

	var controls := UIFactory.label("MONTE SUA EQUIPE • DOMINE OS ELEMENTOS • VENÇA A ARENA", 14, Color("d7e2f5"), HORIZONTAL_ALIGNMENT_CENTER)
	controls.position = Vector2(40, 1165)
	controls.size = Vector2(640, 34)
	add_child(controls)
	var edition := UIFactory.label("ARCADE VERTICAL • BATALHAS CINEMATOGRÁFICAS", 13, Color("ffdf47"), HORIZONTAL_ALIGNMENT_CENTER)
	edition.position = Vector2(40, 1205)
	edition.size = Vector2(640, 34)
	add_child(edition)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("coin"):
		call_deferred("_update_credit_label")
		return
	if event.is_action_pressed("operator_free_play"):
		call_deferred("_update_credit_label")
		return
	if event.is_action_pressed("start") or event.is_action_pressed("p1_confirm"):
		_try_start()
		get_viewport().set_input_as_handled()


func _try_start() -> void:
	if _starting:
		return
	if not GameState.can_start():
		_warning_label.text = "INSIRA UMA FICHA PARA JOGAR"
		AudioSynth.ui_cancel()
		var warning_tween := create_tween()
		warning_tween.tween_property(_warning_label, "modulate:a", 0.25, 0.18)
		warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.18)
		return
	GameState.consume_credit()
	_starting = true
	_start_button.disabled = true
	_start_button.text = "ABRINDO A ARENA..."
	AudioSynth.ui_confirm()
	Transition.go_to(GameState.MODE_SCENE, "ESCOLHA O SEU DESAFIO")


func _update_credit_label() -> void:
	if GameState.free_play:
		_credit_label.text = "MODO LIVRE • ARENA ABERTA"
	else:
		_credit_label.text = "CRÉDITOS DISPONÍVEIS: %02d" % GameState.credits
