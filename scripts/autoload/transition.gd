extends CanvasLayer

const LOADING_BACKGROUND := "res://assets/ui/loading/elemental_loading_backdrop_v2.png"
const BRAND_ICON := "res://assets/branding/elemental_beasts_icon.png"
const MINIMUM_LOADING_SECONDS := 1.25
const BATTLE_TIPS := [
	"VANTAGEM ELEMENTAL aumenta o dano. Compare o elemento do golpe com o tipo da Beast rival.",
	"GOLPES PESADOS causam mais impacto, mas exigem preparação e têm recarga maior.",
	"DEFENDER reduz o próximo dano em 52%. O escudo precisa recarregar antes de voltar.",
	"Mude de faixa para reduzir em 28% o próximo dano recebido.",
	"VOADORES ganham altura; TERRESTRES avançam pelo piso; AQUÁTICOS ondulam e deslizam.",
	"Trocar de Beast preserva vida e deixa as recargas da equipe avançarem.",
]

var _veil: ColorRect
var _title: Label
var _loading_root: Control
var _loading_status: Label
var _loading_tip: Label
var _loading_percent: Label
var _loading_progress: ProgressBar
var _changing := false


func _ready() -> void:
	layer = 200
	_build_loading_screen()
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.005, 0.008, 0.025, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-210, -28)
	_title.size = Vector2(420, 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("6ef8ff"))
	_title.text = ""
	_title.modulate.a = 0.0
	_veil.add_child(_title)


func go_to(scene_path: String, message: String = "PREPARANDO A ARENA") -> void:
	if _changing:
		return
	_changing = true
	if scene_path == GameState.BATTLE_SCENE:
		await _go_to_battle(scene_path, message)
	else:
		await _go_to_simple(scene_path, message)
	_changing = false


func _build_loading_screen() -> void:
	_loading_root = Control.new()
	_loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_root.visible = false
	_loading_root.modulate.a = 0.0
	add_child(_loading_root)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load(LOADING_BACKGROUND) as Texture2D
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(background)

	var icon := TextureRect.new()
	icon.position = Vector2(306, 20)
	icon.size = Vector2(108, 108)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(BRAND_ICON) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(icon)

	var game_title := _loading_label("ELEMENTAL BEASTS", 42, Color.WHITE)
	game_title.position = Vector2(30, 126)
	game_title.size = Vector2(660, 58)
	game_title.add_theme_color_override("font_outline_color", Color("1b0b3f"))
	game_title.add_theme_constant_override("outline_size", 8)
	_loading_root.add_child(game_title)

	var game_subtitle := _loading_label("ARENA ELEMENTAL", 22, Color("ffd34f"))
	game_subtitle.position = Vector2(30, 184)
	game_subtitle.size = Vector2(660, 38)
	_loading_root.add_child(game_subtitle)

	var tip_heading := _loading_label("DICA DE BATALHA", 17, Color("6ef8ff"))
	tip_heading.position = Vector2(72, 570)
	tip_heading.size = Vector2(576, 32)
	_loading_root.add_child(tip_heading)

	_loading_tip = _loading_label("", 21, Color("eef6ff"))
	_loading_tip.position = Vector2(78, 620)
	_loading_tip.size = Vector2(564, 174)
	_loading_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_root.add_child(_loading_tip)

	_loading_status = _loading_label("PREPARANDO A ARENA", 17, Color("c9dcff"))
	_loading_status.position = Vector2(50, 1090)
	_loading_status.size = Vector2(620, 34)
	_loading_root.add_child(_loading_status)

	_loading_progress = ProgressBar.new()
	_loading_progress.position = Vector2(62, 1134)
	_loading_progress.size = Vector2(596, 30)
	_loading_progress.min_value = 0.0
	_loading_progress.max_value = 100.0
	_loading_progress.show_percentage = false
	_loading_progress.add_theme_stylebox_override("background", _progress_style(Color("d90a1023"), Color("6b83b7"), 2))
	_loading_progress.add_theme_stylebox_override("fill", _progress_style(Color("6ef8ff"), Color("f9dd55"), 2))
	_loading_root.add_child(_loading_progress)

	_loading_percent = _loading_label("0%", 19, Color.WHITE)
	_loading_percent.position = Vector2(62, 1170)
	_loading_percent.size = Vector2(596, 32)
	_loading_root.add_child(_loading_percent)

	var footer := _loading_label("DOMINE OS ELEMENTOS  •  PROTEJA SUA EQUIPE  •  CONQUISTE A ARENA", 12, Color("a8bedc"))
	footer.position = Vector2(38, 1220)
	footer.size = Vector2(644, 30)
	_loading_root.add_child(footer)


func _go_to_battle(scene_path: String, message: String) -> void:
	_loading_root.visible = true
	_loading_root.modulate.a = 0.0
	_loading_status.text = message
	_loading_tip.text = str(BATTLE_TIPS[randi() % BATTLE_TIPS.size()])
	_set_loading_progress(0.0)
	var reveal := create_tween()
	reveal.tween_property(_loading_root, "modulate:a", 1.0, 0.28)
	await reveal.finished

	var paths := _battle_resources(scene_path)
	var requested: Array[String] = []
	for path in paths:
		var error := ResourceLoader.load_threaded_request(path)
		if error == OK or error == ERR_BUSY:
			requested.append(path)

	var started := Time.get_ticks_msec()
	var failed := false
	while true:
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var total_progress := 0.0
		var loaded_count := 0
		for path in requested:
			var item_progress: Array = []
			var status := ResourceLoader.load_threaded_get_status(path, item_progress)
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				failed = true
			elif status == ResourceLoader.THREAD_LOAD_LOADED:
				loaded_count += 1
				total_progress += 1.0
			elif not item_progress.is_empty():
				total_progress += clampf(float(item_progress[0]), 0.0, 1.0)
		var resource_progress := total_progress / float(requested.size()) if not requested.is_empty() else 1.0
		var minimum_progress := clampf(elapsed / MINIMUM_LOADING_SECONDS, 0.0, 1.0)
		_set_loading_progress(minf(resource_progress, minimum_progress))
		_loading_status.text = _loading_stage(resource_progress, loaded_count, requested.size())
		if failed or (loaded_count == requested.size() and elapsed >= MINIMUM_LOADING_SECONDS):
			break
		await get_tree().process_frame

	var packed: PackedScene
	if not failed:
		for path in requested:
			var resource := ResourceLoader.load_threaded_get(path)
			if path == scene_path:
				packed = resource as PackedScene
	_set_loading_progress(1.0)
	_loading_status.text = "ARENA PRONTA"
	await get_tree().create_timer(0.20).timeout
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var hide := create_tween()
	hide.tween_property(_loading_root, "modulate:a", 0.0, 0.32)
	await hide.finished
	_loading_root.visible = false


func _battle_resources(scene_path: String) -> Array[String]:
	var paths: Array[String] = [scene_path]
	var arena_path := str(ArenaDB.get_arena(GameState.arena_id).get("path", ""))
	if ResourceLoader.exists(arena_path):
		paths.append(arena_path)
	for player in range(2):
		for creature_id_value in GameState.team_ids[player]:
			var creature_id := str(creature_id_value)
			var combat_art := "res://assets/creatures_hd/%s.png" % creature_id
			if ResourceLoader.exists(combat_art):
				paths.append(combat_art)
			var creature := CreatureDB.get_creature(creature_id)
			for move in MoveDB.moves_for_creature(creature):
				var fx := str(move.get("sprite_sheet", ""))
				if ResourceLoader.exists(fx):
					paths.append(fx)
	var unique: Array[String] = []
	for path in paths:
		if not unique.has(path):
			unique.append(path)
	return unique


func _loading_stage(progress: float, loaded: int, total: int) -> String:
	if progress < 0.22:
		return "PREPARANDO AS BEASTS"
	if progress < 0.52:
		return "SINCRONIZANDO GOLPES E MOVIMENTOS"
	if progress < 0.82:
		return "ILUMINANDO A ARENA  •  %d/%d RECURSOS" % [loaded, total]
	return "POSICIONANDO CÂMERA E LUTADORES"


func _set_loading_progress(value: float) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	_loading_progress.value = normalized * 100.0
	_loading_percent.text = "%d%%" % roundi(normalized * 100.0)


func _go_to_simple(scene_path: String, message: String) -> void:
	_title.text = message
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(_veil, "color:a", 1.0, 0.22)
	fade_out.tween_property(_title, "modulate:a", 1.0, 0.16)
	await fade_out.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(_veil, "color:a", 0.0, 0.28)
	fade_in.tween_property(_title, "modulate:a", 0.0, 0.18)
	await fade_in.finished


func _loading_label(text_value: String, size_value: int, color_value: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color_value)
	return label


func _progress_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	return style
