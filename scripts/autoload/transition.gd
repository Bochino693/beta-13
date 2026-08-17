extends CanvasLayer

## Troca de tela e carregamento da batalha.
##
## A tela de carregamento da batalha nao e um vazio decorado: ela e o
## briefing da partida. Enquanto o jogo carrega de verdade, o jogador ve
## QUAL arena vai jogar, QUEM sao as duas equipes, QUANTO falta (barra,
## porcentagem, contagem de recursos e tempo real em segundos) e COMO se
## joga (comandos e regras da partida) — inclusive a hierarquia elemental do
## confronto, com o par rival destacado.

const LOADING_BACKGROUND := "res://assets/ui/loading/elemental_loading_backdrop_v2.png"
const BRAND_ICON := "res://assets/branding/elemental_beasts_icon.png"

## Tempo minimo de exibicao. Existe para o briefing poder ser LIDO: sem ele,
## num gabinete com SSD, a tela pisca e some antes de qualquer leitura.
const MINIMUM_LOADING_SECONDS := 2.60

## Instrucoes da partida. Ficam visiveis o tempo todo, nao rodam em sorteio:
## sao o que o jogador precisa saber para o primeiro turno.
const MATCH_INSTRUCTIONS := [
	["MOVER / ESCOLHER", "P1: W A S D    P2: SETAS"],
	["CONFIRMAR GOLPE", "P1: ESPAÇO    P2: ENTER"],
	["EQUIPE", "5 Beasts • troca preserva a vida"],
	["ESCUDO", "-52% no próximo dano • 1 a 3 rodadas"],
	["MUDAR DE FAIXA", "esquerda/direita • -28% no próximo dano"],
]

## Dicas de rodizio. Complementam as instrucoes fixas acima.
const BATTLE_TIPS := [
	"GOLPES PESADOS causam mais impacto, mas exigem preparação e têm recarga maior.",
	"A recarga só anda quando a vez daquela Beast volta: Beasts leves reusam técnicas antes.",
	"VOADORES ganham altura; TERRESTRES avançam pelo piso; AQUÁTICOS ondulam e deslizam.",
	"Golpe do mesmo elemento da Beast alvo perde força: guarde a cobertura técnica.",
	"Sua Beast luta de costas, em primeiro plano. A rival encara você do fundo da arena.",
]

var _veil: ColorRect
var _title: Label
var _loading_root: Control
var _loading_backdrop: TextureRect
var _loading_arena_name: Label
var _loading_arena_subtitle: Label
var _loading_matchup: Label
var _loading_hierarchy: Label
var _loading_instructions: VBoxContainer
var _loading_status: Label
var _loading_tip: Label
var _loading_percent: Label
var _loading_elapsed: Label
var _loading_progress: ProgressBar
var _changing := false
var _fonte_titulo: Font
var _fonte_corpo: Font


func _ready() -> void:
	layer = 200
	_carregar_fontes()
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


func _carregar_fontes() -> void:
	var titulo := "res://assets/battle/fonts/URWGothic-Demi.otf"
	if ResourceLoader.exists(titulo):
		_fonte_titulo = load(titulo) as Font
	var corpo := "res://assets/battle/fonts/URWGothic-Book.otf"
	if ResourceLoader.exists(corpo):
		_fonte_corpo = load(corpo) as Font


func go_to(scene_path: String, message: String = "PREPARANDO A ARENA") -> void:
	if _changing:
		return
	_changing = true
	if scene_path == GameState.BATTLE_SCENE:
		await _go_to_battle(scene_path, message)
	else:
		await _go_to_simple(scene_path, message)
	_changing = false


# ===========================================================================
# TELA DE CARREGAMENTO
# ===========================================================================

func _build_loading_screen() -> void:
	_loading_root = Control.new()
	_loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_root.visible = false
	_loading_root.modulate.a = 0.0
	add_child(_loading_root)

	## O fundo e a ARTE DA ARENA que vai ser jogada — trocada a cada partida
	## em `_preparar_briefing`. A arte fixa de `assets/ui/loading` so entra
	## quando a arena nao tem imagem propria.
	_loading_backdrop = TextureRect.new()
	_loading_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loading_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_loading_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(_loading_backdrop)

	## Veu escuro por cima da arte: sem ele o texto branco some numa arena
	## clara (Templo Celeste, Santuario do Eter).
	var veu := ColorRect.new()
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.color = Color(0.004, 0.010, 0.032, 0.74)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(veu)

	var icon := TextureRect.new()
	icon.position = Vector2(306, 18)
	icon.size = Vector2(108, 108)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(BRAND_ICON):
		icon.texture = load(BRAND_ICON) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(icon)

	var game_title := _loading_label("ELEMENTAL BEASTS", 40, Color.WHITE, true)
	game_title.position = Vector2(30, 124)
	game_title.size = Vector2(660, 54)
	_loading_root.add_child(game_title)

	# --- Arena da partida --------------------------------------------------
	_loading_arena_name = _loading_label("", 26, Color("ffd34f"), true)
	_loading_arena_name.position = Vector2(30, 184)
	_loading_arena_name.size = Vector2(660, 38)
	_loading_root.add_child(_loading_arena_name)

	_loading_arena_subtitle = _loading_label("", 16, Color("c9dcff"))
	_loading_arena_subtitle.position = Vector2(30, 222)
	_loading_arena_subtitle.size = Vector2(660, 28)
	_loading_root.add_child(_loading_arena_subtitle)

	# --- Confronto ---------------------------------------------------------
	_loading_matchup = _loading_label("", 15, Color("eef6ff"))
	_loading_matchup.position = Vector2(40, 262)
	_loading_matchup.size = Vector2(640, 96)
	_loading_matchup.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_loading_matchup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_root.add_child(_loading_matchup)

	# --- Hierarquia elemental do confronto ---------------------------------
	var hierarchy_heading := _loading_label("HIERARQUIA ELEMENTAL", 15, Color("6ef8ff"), true)
	hierarchy_heading.position = Vector2(40, 366)
	hierarchy_heading.size = Vector2(640, 26)
	_loading_root.add_child(hierarchy_heading)

	_loading_hierarchy = _loading_label("", 14, Color("d8e6ff"))
	_loading_hierarchy.position = Vector2(40, 394)
	_loading_hierarchy.size = Vector2(640, 92)
	_loading_hierarchy.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_loading_hierarchy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_root.add_child(_loading_hierarchy)

	# --- Instrucoes da partida --------------------------------------------
	var instructions_heading := _loading_label("COMO SE JOGA", 15, Color("6ef8ff"), true)
	instructions_heading.position = Vector2(40, 498)
	instructions_heading.size = Vector2(640, 26)
	_loading_root.add_child(instructions_heading)

	_loading_instructions = VBoxContainer.new()
	_loading_instructions.position = Vector2(46, 528)
	_loading_instructions.size = Vector2(628, 216)
	_loading_instructions.add_theme_constant_override("separation", 6)
	_loading_instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_root.add_child(_loading_instructions)

	for entrada: Array in MATCH_INSTRUCTIONS:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var rotulo := _loading_label(str(entrada[0]), 14, Color("ffd34f"), true)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rotulo.custom_minimum_size = Vector2(220, 22)
		linha.add_child(rotulo)

		var valor := _loading_label(str(entrada[1]), 14, Color("dfe9ff"))
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(valor)

		_loading_instructions.add_child(linha)

	# --- Dica --------------------------------------------------------------
	var tip_heading := _loading_label("DICA DE BATALHA", 15, Color("6ef8ff"), true)
	tip_heading.position = Vector2(40, 760)
	tip_heading.size = Vector2(640, 26)
	_loading_root.add_child(tip_heading)

	_loading_tip = _loading_label("", 18, Color("eef6ff"))
	_loading_tip.position = Vector2(46, 790)
	_loading_tip.size = Vector2(628, 108)
	_loading_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_root.add_child(_loading_tip)

	# --- Progresso real ----------------------------------------------------
	_loading_status = _loading_label("PREPARANDO A ARENA", 17, Color("c9dcff"), true)
	_loading_status.position = Vector2(40, 1092)
	_loading_status.size = Vector2(640, 32)
	_loading_root.add_child(_loading_status)

	_loading_progress = ProgressBar.new()
	_loading_progress.position = Vector2(62, 1132)
	_loading_progress.size = Vector2(596, 28)
	_loading_progress.min_value = 0.0
	_loading_progress.max_value = 100.0
	_loading_progress.show_percentage = false
	_loading_progress.add_theme_stylebox_override(
		"background", _progress_style(Color("0d101f"), Color("6b83b7"), 2)
	)
	_loading_progress.add_theme_stylebox_override(
		"fill", _progress_style(Color("6ef8ff"), Color("f9dd55"), 2)
	)
	_loading_root.add_child(_loading_progress)

	## Porcentagem a esquerda e TEMPO REAL decorrido a direita, na mesma
	## linha. O tempo e cronometrado de verdade (Time.get_ticks_msec), nao e
	## uma animacao fingindo carregamento.
	_loading_percent = _loading_label("0%", 19, Color.WHITE, true)
	_loading_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_loading_percent.position = Vector2(62, 1166)
	_loading_percent.size = Vector2(280, 30)
	_loading_root.add_child(_loading_percent)

	_loading_elapsed = _loading_label("0.0 s", 19, Color("9fb6dd"))
	_loading_elapsed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loading_elapsed.position = Vector2(378, 1166)
	_loading_elapsed.size = Vector2(280, 30)
	_loading_root.add_child(_loading_elapsed)

	var footer := _loading_label(
		"DOMINE OS ELEMENTOS  •  PROTEJA SUA EQUIPE  •  CONQUISTE A ARENA",
		12,
		Color("a8bedc")
	)
	footer.position = Vector2(38, 1216)
	footer.size = Vector2(644, 28)
	_loading_root.add_child(footer)


## Preenche o briefing com os dados REAIS desta partida.
func _preparar_briefing() -> void:
	GameState.resolve_arena_for_battle()
	var arena := ArenaDB.get_arena(GameState.arena_id)

	var caminho_arte := str(arena.get("path", ""))
	if not ResourceLoader.exists(caminho_arte):
		caminho_arte = LOADING_BACKGROUND
	if ResourceLoader.exists(caminho_arte):
		_loading_backdrop.texture = load(caminho_arte) as Texture2D

	_loading_arena_name.text = str(arena.get("name", "ARENA ELEMENTAL")).to_upper()
	_loading_arena_subtitle.text = str(arena.get("subtitle", ""))
	var destaque := Color(str(arena.get("accent", "ffd34f")))
	_loading_arena_name.add_theme_color_override("font_color", destaque)

	_loading_matchup.text = _texto_do_confronto()
	_loading_hierarchy.text = _texto_da_hierarquia()
	_loading_tip.text = str(BATTLE_TIPS[randi() % BATTLE_TIPS.size()])


## As duas equipes, com o elemento de cada Beast.
func _texto_do_confronto() -> String:
	var linhas: Array[String] = []
	for jogador in 2:
		var titulo := "VOCÊ" if jogador == 0 else (
			"JOGADOR 2" if GameState.is_human_player(1) else "CPU"
		)
		var nomes: Array[String] = []
		for id_valor in GameState.team_ids[jogador]:
			var beast := CreatureDB.get_creature(str(id_valor))
			if beast.is_empty():
				continue
			nomes.append("%s (%s)" % [str(beast.get("name", "?")), str(beast.get("type", "?"))])
		if nomes.is_empty():
			continue
		linhas.append("%s: %s" % [titulo, ", ".join(nomes)])
	return "\n".join(linhas)


## Hierarquia lida do CreatureDB — que por sua vez le `data/elements.json`.
## Nenhuma tabela e reescrita aqui: se a hierarquia mudar no dado, esta tela
## muda junto.
func _texto_da_hierarquia() -> String:
	var linhas: Array[String] = []
	for par: Array in CreatureDB.rival_pairs():
		linhas.append(
			"RIVAIS: %s e %s se vencem MUTUAMENTE — não existe lado seguro."
			% [str(par[0]).to_upper(), str(par[1]).to_upper()]
		)

	## So os elementos presentes nesta partida, para o texto caber e ser
	## util: a tabela inteira vive no guia de poderes.
	var presentes: Array[String] = []
	for jogador in 2:
		for id_valor in GameState.team_ids[jogador]:
			var beast := CreatureDB.get_creature(str(id_valor))
			var tipo := str(beast.get("type", ""))
			if not tipo.is_empty() and tipo not in presentes:
				presentes.append(tipo)

	for elemento: String in presentes:
		var vence: Array = CreatureDB.strong_against(elemento)
		if vence.is_empty():
			continue
		linhas.append("%s vence %s" % [elemento.to_upper(), ", ".join(vence)])
	return "\n".join(linhas)


func _go_to_battle(scene_path: String, message: String) -> void:
	_preparar_briefing()
	_loading_root.visible = true
	_loading_root.modulate.a = 0.0
	_loading_status.text = message
	_set_loading_progress(0.0)
	_loading_elapsed.text = "0.0 s"

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
	var elapsed := 0.0
	while true:
		elapsed = float(Time.get_ticks_msec() - started) / 1000.0
		var total_progress := 0.0
		var loaded_count := 0
		for path in requested:
			var item_progress: Array = []
			var status := ResourceLoader.load_threaded_get_status(path, item_progress)
			if status == ResourceLoader.THREAD_LOAD_FAILED \
					or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				failed = true
			elif status == ResourceLoader.THREAD_LOAD_LOADED:
				loaded_count += 1
				total_progress += 1.0
			elif not item_progress.is_empty():
				total_progress += clampf(float(item_progress[0]), 0.0, 1.0)

		var resource_progress := (
			total_progress / float(requested.size()) if not requested.is_empty() else 1.0
		)
		var minimum_progress := clampf(elapsed / MINIMUM_LOADING_SECONDS, 0.0, 1.0)
		_set_loading_progress(minf(resource_progress, minimum_progress))
		_loading_elapsed.text = "%.1f s • %d/%d" % [elapsed, loaded_count, requested.size()]
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
	_loading_elapsed.text = "%.1f s • pronto" % elapsed
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


## Tudo que a batalha vai precisar em disco. O progresso da barra e a soma
## real desta lista, nao um numero inventado.
func _battle_resources(scene_path: String) -> Array[String]:
	var paths: Array[String] = [scene_path]
	var arena_path := str(ArenaDB.get_arena(GameState.arena_id).get("path", ""))
	if ResourceLoader.exists(arena_path):
		paths.append(arena_path)
	for player in range(2):
		for creature_id_value in GameState.team_ids[player]:
			var creature_id := str(creature_id_value)
			## O atlas de combate e o que a batalha desenha: e ele que traz
			## as poses de costas e de frente.
			var atlas := "res://assets/sprites_combat/%s.png" % creature_id
			if ResourceLoader.exists(atlas):
				paths.append(atlas)
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
		return "CARREGANDO AS POSES DAS BEASTS"
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


func _loading_label(
	text_value: String, size_value: int, color_value: Color, titulo: bool = false
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color_value)
	## Contorno em tudo: o fundo agora e a arte da arena, que tem areas
	## claras e escuras na mesma tela.
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.09))
	label.add_theme_constant_override("outline_size", 5)
	var fonte := _fonte_titulo if titulo else _fonte_corpo
	if fonte != null:
		label.add_theme_font_override("font", fonte)
	return label


func _progress_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	return style
