extends Control

var _skipped := false
var _logo_group: Control


func _ready() -> void:
	_build_screen()
	AudioSynth.start_music("intro")
	_run_intro()


func _build_screen() -> void:
	var background := PortraitBackdrop.new()
	add_child(background)
	background.setup("res://assets/backgrounds/opening_portal.png", Color(0.72, 0.82, 1.0), 0.46)

	_logo_group = Control.new()
	_logo_group.position = Vector2(35, 285)
	_logo_group.size = Vector2(650, 600)
	_logo_group.pivot_offset = _logo_group.size * 0.5
	_logo_group.modulate.a = 0.0
	_logo_group.scale = Vector2(0.72, 0.72)
	add_child(_logo_group)

	var plate := UIFactory.panel(Color("d9081028"), Color("aa6ef8ff"), 36)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo_group.add_child(plate)

	var top_line := UIFactory.title("UMA EXPERIÊNCIA", 24, Color("73f7ff"))
	top_line.position = Vector2(0, 55)
	top_line.size = Vector2(650, 42)
	_logo_group.add_child(top_line)

	var lazer := UIFactory.title("LAZER", 84, Color("ffdf3f"))
	lazer.position = Vector2(0, 105)
	lazer.size = Vector2(650, 110)
	_logo_group.add_child(lazer)

	var ampersand := UIFactory.title("&", 48, Color("ff4fc8"))
	ampersand.position = Vector2(0, 215)
	ampersand.size = Vector2(650, 60)
	_logo_group.add_child(ampersand)

	var sport := UIFactory.title("SPORT", 84, Color("70f4ff"))
	sport.position = Vector2(0, 270)
	sport.size = Vector2(650, 110)
	_logo_group.add_child(sport)

	var line := ColorRect.new()
	line.color = Color("ff4fc8")
	line.position = Vector2(145, 414)
	line.size = Vector2(360, 5)
	_logo_group.add_child(line)

	var footer := UIFactory.title("DIVERSÃO QUE VIRA MEMÓRIA", 20, Color("e4f0ff"))
	footer.position = Vector2(0, 440)
	footer.size = Vector2(650, 48)
	_logo_group.add_child(footer)

	var edition := UIFactory.badge("ARCADE VERTICAL • 2.5D", Color("ffdf47"))
	edition.position = Vector2(180, 515)
	edition.size = Vector2(290, 42)
	_logo_group.add_child(edition)

	var skip := UIFactory.label("PRESSIONE QUALQUER BOTÃO PARA PULAR", 14, Color("c8d5ee"), HORIZONTAL_ALIGNMENT_CENTER)
	skip.position = Vector2(80, 1195)
	skip.size = Vector2(560, 38)
	add_child(skip)
	var blink := create_tween().set_loops()
	blink.tween_property(skip, "modulate:a", 0.30, 0.7)
	blink.tween_property(skip, "modulate:a", 1.0, 0.7)


func _run_intro() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_logo_group, "modulate:a", 1.0, 0.62)
	tween.tween_property(_logo_group, "scale", Vector2.ONE, 0.82).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo_group, "position:y", 315.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event is InputEventMouseMotion:
		_finish()


func _finish() -> void:
	if _skipped:
		return
	_skipped = true
	AudioSynth.ui_confirm()
	Transition.go_to(GameState.OPENING_SCENE, "ABRINDO O PORTAL")
