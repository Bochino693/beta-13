extends Control

# Batalha retrato: arte mestre em malha contínua, estadio e HUD em faixas.

const MOVE_COUNT := 5
const GUARD_ACTION := 5
const SWITCH_ACTION := 6
const ACTION_COUNT := 7

# --- Grade de faixas do retrato 720x1280 -----------------------------------
# Ver docs/LAYOUT_RETRATO.md. Nenhum elemento cruza a fronteira da faixa.
const MARGEM := 24.0
const LARGURA := 720.0
const ALTURA := 1280.0

const Y_TOPO := 16.0        # placar + turno
const H_TOPO := 42.0
const Y_HUD_INIMIGO := 68.0
const H_HUD := 78.0
const Y_ARENA := 156.0
const H_ARENA := 710.0
const Y_HUD_ALIADO := 876.0
const Y_MENSAGEM := 964.0
const H_MENSAGEM := 38.0
const Y_ACOES := 1012.0

const COR_P1 := Color("6ef8ff")
const COR_P2 := Color("ff55c6")

# --- Estado de combate (identico ao original) ------------------------------
var _teams: Array = [[], []]
var _active := [0, 0]
var _turn := 0
var _round := 1
var _busy := true
var _battle_over := false
var _action_cursor := 0

# --- 3D --------------------------------------------------------------------
var _viewport: SubViewport
var _camera: Camera3D
var _camera_home_position := Vector3.ZERO
var _camera_home_rotation := Vector3.ZERO
var _camera_home_fov := 50.0
var _rigs: Array[BeastRig3D] = [null, null]
var _escudos: Array[BattleShieldDome3D] = [null, null]
var _arena: BattleArena3D
var _faixas: Array[int] = [0, 0]
var _esquiva_pronta: Array[bool] = [false, false]
var _tempo := 0.0
var _audio_batalha: BattleAudioDirector

# --- HUD -------------------------------------------------------------------
var _nome_labels: Array[Label] = []
var _tipo_labels: Array[Label] = []
var _tipo_emblemas: Array[TypeEmblem] = []
var _peso_labels: Array[Label] = []
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _reservas: Array[HBoxContainer] = []
var _placar: Label
var _turno_label: Label
var _mensagem: Label
var _botoes: Array[Button] = []
var _camada_numeros: Control
var _fonte_batalha: Font
var _fonte_corpo: Font


func _ready() -> void:
	var caminho_fonte := "res://assets/battle/fonts/URWGothic-Demi.otf"
	if ResourceLoader.exists(caminho_fonte):
		_fonte_batalha = load(caminho_fonte) as Font
	var caminho_corpo := "res://assets/battle/fonts/URWGothic-Book.otf"
	if ResourceLoader.exists(caminho_corpo):
		_fonte_corpo = load(caminho_corpo) as Font
	_teams[0] = GameState.runtime_team(0)
	_teams[1] = GameState.runtime_team(1)
	if _teams[0].is_empty() or _teams[1].is_empty():
		GameState.begin_mode("training")
		GameState.set_team(0, CreatureDB.random_team())
		GameState.set_team(1, CreatureDB.random_team(5, GameState.team_ids[0]))
		_teams[0] = GameState.runtime_team(0)
		_teams[1] = GameState.runtime_team(1)

	_montar_arena_3d()
	_montar_hud()
	var rig_aliado_ok := _trocar_rig(0)
	var rig_rival_ok := _trocar_rig(1)
	if not rig_aliado_ok or not rig_rival_ok:
		push_error("Batalha: não foi possível construir os rigs visuais.")
		return

	_turn = 0 if _lutador(0)["data"]["speed"] >= _lutador(1)["data"]["speed"] else 1
	AudioSynth.start_music("battle")
	_audio_batalha = BattleAudioDirector.new()
	add_child(_audio_batalha)
	_atualizar_ui()
	_sequencia_de_entrada()
	set_process(true)


func _process(delta: float) -> void:
	_tempo += delta
	# O horizonte e o FOV permanecem estáveis durante toda a luta.


# ===========================================================================
# ARENA 3D
# ===========================================================================

func _montar_arena_3d() -> void:
	var caixa := SubViewportContainer.new()
	caixa.stretch = true
	caixa.position = Vector2(0.0, Y_ARENA)
	caixa.size = Vector2(LARGURA, H_ARENA)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caixa)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(LARGURA), int(H_ARENA))
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	caixa.add_child(_viewport)

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.008, 0.012, 0.035)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.35, 0.42, 0.70)
	ambiente.ambient_light_energy = 0.8
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	_viewport.add_child(mundo)

	_arena = BattleArena3D.new()
	_viewport.add_child(_arena)
	GameState.resolve_arena_for_battle()
	var arena := ArenaDB.get_arena(GameState.arena_id)
	_arena.configurar(COR_P1, COR_P2, "", "", str(arena.get("path", "")))

	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = _camera_home_fov
	_camera.position = Vector3(0.0, 3.25, 7.65)
	_camera.near = 0.05
	_camera.far = 90.0
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.12, -2.15), Vector3.UP)
	_camera_home_position = _camera.position
	_camera_home_rotation = _camera.rotation
	_camera.make_current()

	## A arte da arena so pode ser dimensionada depois que a camera existe:
	## o painel e recortado para COBRIR exatamente o campo de visao dela.
	_arena.alinhar_camera(_camera, Vector2(LARGURA, H_ARENA))

	# Camada 2D para numeros de dano, alinhada exatamente sobre a faixa.
	_camada_numeros = Control.new()
	_camada_numeros.position = Vector2(0.0, Y_ARENA)
	_camada_numeros.size = Vector2(LARGURA, H_ARENA)
	_camada_numeros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_numeros.clip_contents = true
	add_child(_camada_numeros)


## Constroi (ou reconstroi) o rig da Beast ativa do jogador informado.
func _trocar_rig(jogador: int) -> bool:
	if _rigs[jogador] != null and is_instance_valid(_rigs[jogador]):
		_rigs[jogador].queue_free()
	if _escudos[jogador] != null and is_instance_valid(_escudos[jogador]):
		_escudos[jogador].queue_free()

	var dados: Dictionary = _lutador(jogador)["data"]
	var id_beast: String = str(dados.get("id", ""))

	## ESTA e a regra de camera do jogo, e ela vale a luta inteira:
	## o jogador 0 e SEMPRE visto de costas, em primeiro plano, e o
	## adversario SEMPRE de frente, ao fundo. Nao e espelhamento da mesma
	## arte — sao linhas diferentes do atlas de combate (`back_*` e
	## `front_*`), desenhadas separadamente.
	var de_costas: bool = jogador == 0

	var cor: Color = CreatureDB.color_for_type(str(dados.get("type", "Luz")))
	var familia: String = BeastRig3D.familia_de(dados)
	var locomocao: String = BeastRig3D.locomocao_de(dados)

	var rig := BeastRig3D.new()
	_viewport.add_child(rig)
	rig.position = Vector3(_x_da_faixa(jogador, _faixas[jogador]), 0.0, 0.30) \
		if de_costas else Vector3(_x_da_faixa(jogador, _faixas[jogador]), 0.0, -4.35)
	var configurado: bool = rig.configurar(
		id_beast,
		2.12 if de_costas else 2.62,
		familia,
		locomocao,
		de_costas,
		cor
	)
	if not configurado:
		rig.queue_free()
		_rigs[jogador] = null
		push_error("Batalha: atlas de combate ausente para " + id_beast)
		return false
	_rigs[jogador] = rig
	rig.alinhar_camera(_camera)
	rig.entrar()

	var escudo := BattleShieldDome3D.new()
	escudo.position = rig.position + Vector3(0.0, 0.96 if de_costas else 1.17, 0.0)
	escudo.scale = Vector3(0.88, 0.88, 0.88) if de_costas else Vector3(1.02, 1.02, 1.02)
	escudo.visible = false
	_viewport.add_child(escudo)
	_escudos[jogador] = escudo
	return true


func _x_da_faixa(jogador: int, faixa: int) -> float:
	# Diagonal de leitura: aliado embaixo/esquerda, rival em cima/direita.
	var centro := -1.32 if jogador == 0 else 1.18
	var passo := 0.56 if jogador == 0 else 0.48
	return centro + float(clampi(faixa, -1, 1)) * passo


func _mover_faixa(jogador: int, direcao: int) -> void:
	if _rigs[jogador] == null or not is_instance_valid(_rigs[jogador]):
		return
	var nova_faixa := clampi(_faixas[jogador] + signi(direcao), -1, 1)
	if nova_faixa == _faixas[jogador]:
		AudioSynth.ui_cancel()
		return
	var anterior := _faixas[jogador]
	_faixas[jogador] = nova_faixa
	_esquiva_pronta[jogador] = true
	_rigs[jogador].esquivar(signi(nova_faixa - anterior))
	if _escudos[jogador] != null:
		var tween := create_tween()
		tween.tween_property(_escudos[jogador], "position:x", _x_da_faixa(jogador, nova_faixa), 0.28)
	_arena.definir_faixa(jogador, nova_faixa)
	_mensagem.text = "%s • FAIXA %s • PROXIMO DANO -28%%" % [
		str(_lutador(jogador)["data"]["name"]),
		["ESQUERDA", "CENTRO", "DIREITA"][nova_faixa + 1]
	]
	_audio_batalha.esquivar()
	AudioSynth.ui_move()


func _recentralizar_faixa(jogador: int) -> void:
	if _faixas[jogador] == 0:
		_esquiva_pronta[jogador] = false
		return
	var direcao := -signi(_faixas[jogador])
	_faixas[jogador] = 0
	_esquiva_pronta[jogador] = false
	if _rigs[jogador] != null and is_instance_valid(_rigs[jogador]):
		_rigs[jogador].esquivar(direcao, 0.32)
	if _escudos[jogador] != null:
		var tween := create_tween()
		tween.tween_property(_escudos[jogador], "position:x", _x_da_faixa(jogador, 0), 0.26)
	_arena.definir_faixa(jogador, 0)


## Dispara o poder do atacante e espera ele CHEGAR no alvo.
##
## Quem chama espera esta funcao: o dano so e aplicado depois do impacto,
## nunca no instante em que o botao e apertado.
func _tocar_fx_do_golpe(
	alvo_jogador: int, golpe: Dictionary, atacante_jogador: int
) -> void:
	var caminho := str(golpe.get("sprite_sheet", ""))
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		return
	var textura := load(caminho) as Texture2D
	if textura == null:
		return
	if _rigs[atacante_jogador] == null or _rigs[alvo_jogador] == null:
		return

	var cor_fx: Color = CreatureDB.color_for_type(str(golpe.get("element", "Luz")))
	var pesado: bool = str(golpe.get("role", "")) == "pesado"

	## O poder nasce na Beast atacante e atravessa a arena em 3D.
	var poder := ElementPower3D.new()
	poder.disparar(
		_viewport,
		_rigs[atacante_jogador].ponto_emissao(),
		_rigs[alvo_jogador].ponto_impacto(),
		textura,
		cor_fx,
		pesado,
		golpe
	)
	await poder.impacto_alcancado

	## Clarao sobre o alvo, no contato. Nasce e se apaga sozinho.
	ElementPower3D.clarao_de_impacto(
		_viewport, _rigs[alvo_jogador].ponto_impacto(), textura, cor_fx, pesado
	)


func _sacudir_camera(forca: float) -> void:
	if _camera == null:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	for indice in 6:
		var d := forca * (1.0 - float(indice) / 6.0) * 3.0
		t.tween_property(
			_camera,
			"rotation:z",
			_camera_home_rotation.z + deg_to_rad(randf_range(-d, d)),
			0.045
		)
	t.tween_property(_camera, "rotation", _camera_home_rotation, 0.10)


## Converte a posicao 3D da Beast em coordenada de tela dentro da faixa.
func _tela_da_beast(jogador: int) -> Vector2:
	var rig = _rigs[jogador]
	if rig == null or not is_instance_valid(rig) or _camera == null:
		return Vector2(LARGURA * 0.5, H_ARENA * 0.5)
	var altura := 1.06 if jogador == 0 else 1.38
	var ponto: Vector2 = _camera.unproject_position(rig.global_position + Vector3(0.0, altura, 0.0))
	return ponto


# ===========================================================================
# HUD EM FAIXAS
# ===========================================================================

func _montar_hud() -> void:
	var util := LARGURA - MARGEM * 2.0

	# Faixa 0 — turno e placar
	var topo := HBoxContainer.new()
	topo.position = Vector2(MARGEM, Y_TOPO)
	topo.size = Vector2(util, H_TOPO)
	add_child(topo)

	_turno_label = _rotulo("", 22, COR_P1)
	_turno_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_turno_label)

	_placar = _rotulo("", 22, Color("ffdf47"), HORIZONTAL_ALIGNMENT_RIGHT)
	_placar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_placar)

	# Faixa 1 — HUD do oponente / Faixa 3 — HUD do jogador.
	# Ordem de criacao = ordem dos arrays. A posicao Y e que define a faixa.
	_montar_bloco_vida(0, Y_HUD_ALIADO, COR_P1)
	_montar_bloco_vida(1, Y_HUD_INIMIGO, COR_P2)

	# Faixa 4 — mensagem
	var painel_msg := _painel(Color(0.03, 0.05, 0.15, 0.92), Color(1.0, 0.87, 0.28, 0.55))
	painel_msg.position = Vector2(MARGEM, Y_MENSAGEM)
	painel_msg.size = Vector2(util, H_MENSAGEM)
	add_child(painel_msg)

	var margem_msg := _margem(5)
	painel_msg.add_child(margem_msg)
	_mensagem = _rotulo("PREPARE-SE!", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_mensagem.add_theme_color_override("font_outline_color", Color("090d20"))
	_mensagem.add_theme_constant_override("outline_size", 5)
	_mensagem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margem_msg.add_child(_mensagem)

	# Faixa 5 — acoes
	var painel := _painel(Color(0.03, 0.05, 0.14, 0.94), Color(0.43, 0.61, 1.0, 0.55))
	painel.position = Vector2(MARGEM, Y_ACOES)
	painel.size = Vector2(util, ALTURA - Y_ACOES - MARGEM)
	add_child(painel)

	var margem := _margem(8)
	painel.add_child(margem)

	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 6)
	margem.add_child(grade)

	for indice in ACTION_COUNT:
		var cor := Color("bf6cff")
		if indice == GUARD_ACTION:
			cor = Color("59d7ff")
		elif indice == SWITCH_ACTION:
			cor = Color("59e98b")

		var botao := Button.new()
		botao.custom_minimum_size = Vector2(0, 50)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.focus_mode = Control.FOCUS_NONE
		botao.clip_text = false
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.expand_icon = true
		botao.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.add_theme_font_size_override("font_size", 15)
		if _fonte_batalha != null:
			botao.add_theme_font_override("font", _fonte_batalha)
		botao.add_theme_color_override("font_color", Color.WHITE)
		botao.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.60))
		botao.add_theme_constant_override("icon_max_width", 34)
		botao.add_theme_constant_override("h_separation", 7)
		botao.add_theme_stylebox_override("normal", _estilo_botao(cor, 0.12))
		botao.add_theme_stylebox_override("hover", _estilo_botao(cor, 0.24))
		botao.add_theme_stylebox_override("pressed", _estilo_botao(cor, 0.34))
		botao.add_theme_stylebox_override("disabled", _estilo_botao(Color(0.35, 0.38, 0.5), 0.08))
		botao.pressed.connect(_escolher_acao.bind(indice))
		grade.add_child(botao)
		_botoes.append(botao)


func _montar_bloco_vida(_jogador: int, y: float, cor: Color) -> void:
	var painel := _painel(Color(0.03, 0.05, 0.15, 0.90), Color(cor.r, cor.g, cor.b, 0.55))
	painel.position = Vector2(MARGEM, y)
	painel.size = Vector2(LARGURA - MARGEM * 2.0, H_HUD)
	add_child(painel)

	var margem := _margem(6)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 1)
	margem.add_child(coluna)

	# Linha 1: nome dominante + selo de elemento.
	var linha1 := HBoxContainer.new()
	linha1.add_theme_constant_override("separation", 10)
	coluna.add_child(linha1)

	var nome := _rotulo("", 20, Color.WHITE)
	nome.add_theme_color_override("font_outline_color", Color("080c1d"))
	nome.add_theme_constant_override("outline_size", 4)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha1.add_child(nome)
	_nome_labels.append(nome)

	## Elemento entra como EMBLEMA, nao como pilula de texto. O simbolo e
	## lido de relance no meio da luta; a palavra "ESCURIDAO" escrita em 11 px
	## dentro de uma pilula preta, nao.
	var selo_tipo := HBoxContainer.new()
	selo_tipo.add_theme_constant_override("separation", 5)
	linha1.add_child(selo_tipo)

	var emblema := TypeEmblem.new()
	emblema.custom_minimum_size = Vector2(26, 26)
	emblema.enfeitado = false
	selo_tipo.add_child(emblema)
	_tipo_emblemas.append(emblema)

	var tipo := _rotulo("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	tipo.custom_minimum_size = Vector2(86, 26)
	tipo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tipo.add_theme_color_override("font_outline_color", Color("080c1d"))
	tipo.add_theme_constant_override("outline_size", 4)
	selo_tipo.add_child(tipo)
	_tipo_labels.append(tipo)

	# Linha 2: barra larga + valor legivel.
	var linha2 := HBoxContainer.new()
	linha2.add_theme_constant_override("separation", 10)
	coluna.add_child(linha2)

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 14)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_theme_stylebox_override("background", _estilo_barra(Color(0.06, 0.07, 0.13)))
	linha2.add_child(barra)
	_hp_bars.append(barra)

	var hp := _rotulo("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	hp.custom_minimum_size = Vector2(116, 0)
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha2.add_child(hp)
	_hp_labels.append(hp)

	# Linha 3: reservas + classe de peso.
	var linha3 := HBoxContainer.new()
	linha3.add_theme_constant_override("separation", 8)
	coluna.add_child(linha3)
	var reservas := HBoxContainer.new()
	reservas.add_theme_constant_override("separation", 7)
	reservas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha3.add_child(reservas)
	_reservas.append(reservas)

	var peso := _rotulo("", 11, Color("ffdf73"), HORIZONTAL_ALIGNMENT_RIGHT)
	peso.custom_minimum_size = Vector2(320, 0)
	peso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha3.add_child(peso)
	_peso_labels.append(peso)


func _rotulo(
	texto: String,
	tamanho: int,
	cor: Color,
	alinhamento: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alinhamento
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	var fonte := _fonte_batalha if tamanho >= 20 else _fonte_corpo
	if fonte != null:
		l.add_theme_font_override("font", fonte)
	return l


func _margem(valor: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", valor)
	m.add_theme_constant_override("margin_right", valor)
	m.add_theme_constant_override("margin_top", valor)
	m.add_theme_constant_override("margin_bottom", valor)
	return m


func _painel(fundo: Color, borda: Color) -> PanelContainer:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(20)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", estilo)
	return p


func _estilo_botao(cor: Color, alfa: float) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(cor.r, cor.g, cor.b, alfa)
	e.border_color = Color(cor.r, cor.g, cor.b, 0.70)
	e.set_border_width_all(2)
	e.set_corner_radius_all(16)
	e.content_margin_left = 12
	e.content_margin_right = 12
	e.content_margin_top = 8
	e.content_margin_bottom = 8
	return e


func _estilo_barra(cor: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = cor
	e.set_corner_radius_all(11)
	return e


# ===========================================================================
# ENTRADA E FLUXO DE TURNO (regras originais preservadas)
# ===========================================================================

func _sequencia_de_entrada() -> void:
	_busy = true
	_mensagem.text = "AS BEASTS ENTRAM NA ARENA"
	await get_tree().create_timer(0.85).timeout
	_rigs[_turn].comemorar()
	_audio_batalha.rugir(str(_lutador(_turn)["data"]["id"]))
	_mensagem.text = "COMEÇA %s • MAIOR VELOCIDADE" % _lutador(_turn)["data"]["name"]
	_busy = false
	_atualizar_ui()
	_talvez_rodar_cpu()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _battle_over or not GameState.is_human_player(_turn):
		return
	var prefixo := "p1_" if _turn == 0 else "p2_"
	if event.is_action_pressed(prefixo + "left"):
		_mover_faixa(_turn, -1)
	elif event.is_action_pressed(prefixo + "right"):
		_mover_faixa(_turn, 1)
	elif event.is_action_pressed(prefixo + "up"):
		_mover_cursor(-1)
	elif event.is_action_pressed(prefixo + "down"):
		_mover_cursor(1)
	elif event.is_action_pressed(prefixo + "confirm"):
		_escolher_acao(_action_cursor)


func _mover_cursor(passo: int) -> void:
	_action_cursor = wrapi(_action_cursor + passo, 0, ACTION_COUNT)
	AudioSynth.ui_move()
	_atualizar_acoes()


func _escolher_acao(indice: int) -> void:
	if _busy or _battle_over:
		return
	if indice < MOVE_COUNT:
		var golpe := _golpe_da_acao(_turn, indice)
		if golpe.is_empty() or not MoveDB.can_use(_lutador(_turn), golpe):
			var faltam := MoveDB.cooldown_turns(
				MoveDB.cooldown_left(_lutador(_turn), str(golpe.get("id", "")))
			)
			_mensagem.text = "GOLPE EM RECARGA • AGUARDE %d TURNO(S)" % faltam
			AudioSynth.ui_cancel()
			return
	elif indice == GUARD_ACTION and not MoveDB.can_guard(_lutador(_turn)):
		var recarga_escudo := int(_lutador(_turn).get("guard_cooldown", 0))
		_mensagem.text = "ESCUDO INDISPONÍVEL • RECARGA %d" % recarga_escudo
		AudioSynth.ui_cancel()
		return
	_busy = true
	await _executar_acao(indice)
	if _battle_over:
		return
	_passar_turno()


func _passar_turno() -> void:
	_turn = 1 - _turn
	MoveDB.reduce_cooldowns(_lutador(_turn))
	var estado_escudo: Dictionary = MoveDB.begin_fighter_turn(_lutador(_turn))
	if bool(estado_escudo["expired"]):
		if _escudos[_turn] != null:
			_escudos[_turn].desativar()
		if _rigs[_turn] != null:
			_rigs[_turn].encerrar_guarda()
	elif bool(_lutador(_turn).get("guard", false)) and _escudos[_turn] != null:
		_escudos[_turn].atualizar_rodadas(int(estado_escudo["turns"]))
	_round += 1
	_action_cursor = 0
	_busy = false
	_atualizar_ui()
	_talvez_rodar_cpu()


func _executar_acao(indice: int) -> void:
	if indice < MOVE_COUNT:
		await _atacar(indice)
	elif indice == GUARD_ACTION:
		await _defender()
	else:
		await _trocar_beast()


func _atacar(indice_golpe: int) -> void:
	var atacante := _lutador(_turn)
	var alvo_jogador := 1 - _turn
	var defensor := _lutador(alvo_jogador)
	var golpe := _golpe_da_acao(_turn, indice_golpe)

	var multiplicador := CreatureDB.type_multiplier(
		str(golpe["element"]), str(defensor["data"]["type"])
	)
	var dano := maxi(5, MoveDB.damage_preview(atacante, defensor, golpe) + randi_range(-2, 2))
	var esquivou := _esquiva_pronta[alvo_jogador]
	if esquivou:
		dano = maxi(4, roundi(dano * 0.72))
		_esquiva_pronta[alvo_jogador] = false
	var protegido := bool(defensor.get("guard", false))
	if protegido:
		dano = maxi(4, roundi(dano * MoveDB.GUARD_DAMAGE_FACTOR))
		if _escudos[alvo_jogador] != null:
			_escudos[alvo_jogador].absorver_impacto(
				int(defensor.get("guard_turns", 1))
			)
	MoveDB.set_cooldown(atacante, golpe)

	var pesado := str(golpe.get("role", "")) == "pesado"
	_mensagem.text = "%s USA %s" % [atacante["data"]["name"], str(golpe["name"]).to_upper()]

	var rig_atacante = _rigs[_turn]
	var rig_alvo = _rigs[alvo_jogador]
	if rig_atacante == null or rig_alvo == null:
		push_error("Batalha: tentativa de ataque sem rig válido.")
		return
	rig_atacante.preparar_golpe(golpe)

	if pesado:
		rig_atacante.carregar(0.80)
		await rig_atacante.animacao_terminou

	rig_atacante.atacar(0.78 if pesado else 0.60)
	await rig_atacante.animacao_terminou  # sinal "impacto"

	# Efeito e dano acontecem exatamente no impacto, nunca antes.
	await _tocar_fx_do_golpe(alvo_jogador, golpe, _turn)
	var cor_impacto := CreatureDB.color_for_type(str(golpe["element"]))
	rig_alvo.levar_dano(cor_impacto)
	_arena.reagir_golpe(
		golpe, cor_impacto, 1.0 if pesado else 0.55, rig_alvo.ponto_impacto()
	)
	_sacudir_camera(0.42 if pesado else 0.20)

	defensor["hp"] = maxi(0, int(defensor["hp"]) - dano)
	defensor["round_damage"] = int(defensor["round_damage"]) + dano
	GameState.scores[_turn] += dano * (2 if pesado else 1)

	_numero_de_dano(
		alvo_jogador,
		CreatureDB.color_for_type(str(golpe["element"])),
		"%d • %s%s" % [
			dano,
			CreatureDB.effectiveness_text(
				multiplicador, str(golpe["element"]), str(defensor["data"]["type"])
			),
			(" • ESQUIVA -28%" if esquivou else "")
			+ (" • ESCUDO -52%" if protegido else "")
		]
	)

	if pesado:
		AudioSynth.special_hit()
	else:
		AudioSynth.hit(clampf(float(dano) / 45.0, 0.7, 1.25))

	await get_tree().create_timer(0.55).timeout
	if esquivou:
		_recentralizar_faixa(alvo_jogador)
	_atualizar_ui()

	if int(defensor["hp"]) <= 0:
		await _nocaute(alvo_jogador)
	else:
		await get_tree().create_timer(0.20).timeout


func _defender() -> void:
	var lutador := _lutador(_turn)
	var duracao := MoveDB.activate_guard(lutador)
	if duracao <= 0:
		_mensagem.text = "ESCUDO EM RECARGA • %d RODADA(S)" % int(lutador["guard_cooldown"])
		await get_tree().create_timer(0.35).timeout
		return
	_mensagem.text = "%s ERGUEU ESCUDO POR %d RODADA(S)" % [
		lutador["data"]["name"], duracao
	]
	AudioSynth.guard()
	_rigs[_turn].definir_cor_elemento(Color("59d7ff"))
	_rigs[_turn].guardar(duracao)
	if _escudos[_turn] != null:
		_escudos[_turn].ativar(Color("59d7ff"), duracao)
	await get_tree().create_timer(0.55).timeout
	_rigs[_turn].definir_cor_elemento(
		CreatureDB.color_for_type(str(lutador["data"]["type"]))
	)


func _trocar_beast() -> void:
	var proximo := _proximo_vivo(_turn, _active[_turn])
	if proximo == -1 or proximo == _active[_turn]:
		_mensagem.text = "REAGRUPANDO • RECARGAS AVANÇAM"
		AudioSynth.ui_confirm()
		await get_tree().create_timer(0.42).timeout
		return
	MoveDB.cancel_guard(_lutador(_turn))
	if _escudos[_turn] != null:
		_escudos[_turn].desativar()
	_active[_turn] = proximo
	_trocar_rig(_turn)
	_mensagem.text = "%s ENTRA NA ARENA" % _lutador(_turn)["data"]["name"]
	AudioSynth.ui_confirm()
	await get_tree().create_timer(0.75).timeout


func _nocaute(derrotado: int) -> void:
	var lutador := _lutador(derrotado)
	lutador["ko"] = true
	GameState.scores[1 - derrotado] += 250
	_mensagem.text = "%s FORA DE COMBATE!" % lutador["data"]["name"]
	AudioSynth.knockout()

	_rigs[derrotado].tombar(1.0)
	await _rigs[derrotado].animacao_terminou

	var proximo := _proximo_vivo(derrotado, _active[derrotado])
	if proximo == -1:
		await _encerrar(1 - derrotado)
		return

	_active[derrotado] = proximo
	_trocar_rig(derrotado)
	_mensagem.text = "%s ASSUME O DUELO" % _lutador(derrotado)["data"]["name"]
	_atualizar_ui()
	await get_tree().create_timer(0.80).timeout


func _encerrar(vencedor: int) -> void:
	_battle_over = true
	_busy = true
	GameState.winner = vencedor
	GameState.scores[vencedor] += 1000
	GameState.battle_summary = {
		"rounds": _round,
		"remaining": _quantidade_viva(vencedor),
		"winner_creature": _lutador(vencedor)["id"]
	}
	_anotar_caderneta(vencedor)
	_mensagem.text = "%s VENCEU A BATALHA!" % _titulo_do_jogador(vencedor)
	AudioSynth.stop_music()
	_audio_batalha.parar()
	AudioSynth.victory()
	_rigs[vencedor].comemorar(1.2)
	_audio_batalha.rugir(str(_lutador(vencedor)["data"]["id"]))
	await get_tree().create_timer(1.60).timeout
	Transition.go_to(GameState.RESULTS_SCENE, "RESULTADO DA ARENA")


func _talvez_rodar_cpu() -> void:
	if _battle_over or GameState.is_human_player(_turn):
		return
	_busy = true
	_mensagem.text = "CPU CALCULANDO PESO, TIPO E RECARGA..."
	_rodar_cpu()


func _rodar_cpu() -> void:
	await get_tree().create_timer(0.62).timeout
	await _executar_acao(_escolha_da_cpu())
	if _battle_over:
		return
	_passar_turno()


func _escolha_da_cpu() -> int:
	var cpu := _lutador(_turn)
	var rival := _lutador(1 - _turn)
	if float(cpu["hp"]) / float(cpu["max_hp"]) < 0.24 \
			and _proximo_vivo(_turn, _active[_turn]) != -1 and randf() < 0.34:
		return SWITCH_ACTION
	if randf() < 0.10 and MoveDB.can_guard(cpu):
		return GUARD_ACTION

	var melhor := -1
	var melhor_nota := -9999.0
	for indice in MOVE_COUNT:
		var golpe := _golpe_da_acao(_turn, indice)
		if golpe.is_empty() or not MoveDB.can_use(cpu, golpe):
			continue
		var dano := float(MoveDB.damage_preview(cpu, rival, golpe))
		var penalidade := MoveDB.effective_cooldown(golpe, cpu) * 1.7
		var bonus := 14.0 if dano >= float(rival["hp"]) else 0.0
		var nota := dano - penalidade + bonus + randf_range(-1.8, 1.8)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = indice
	if melhor >= 0:
		return melhor
	if MoveDB.can_guard(cpu):
		return GUARD_ACTION
	return SWITCH_ACTION


# ===========================================================================
# CONSULTAS
# ===========================================================================

func _lutador(jogador: int) -> Dictionary:
	return _teams[jogador][_active[jogador]]


func _golpe_da_acao(jogador: int, indice: int) -> Dictionary:
	var ids: Array = _lutador(jogador)["data"].get("moves", [])
	if indice < 0 or indice >= ids.size():
		return {}
	return MoveDB.get_move(str(ids[indice]))


func _proximo_vivo(jogador: int, depois_de: int) -> int:
	for passo in range(1, _teams[jogador].size() + 1):
		var indice: int = (depois_de + passo) % _teams[jogador].size()
		if not bool(_teams[jogador][indice]["ko"]):
			return indice
	return -1


## Manda a batalha para a caderneta. Chamada so daqui, uma vez por batalha:
## anotar a cada nocaute faria uma revanche inflar o historico. A caderneta
## nao devolve nada ao combate — ver `beast_records.gd`.
func _anotar_caderneta(vencedor: int) -> void:
	var perdedor := 1 - vencedor
	var caidos: Array[String] = []
	for jogador in 2:
		for lutador in _teams[jogador]:
			if bool(lutador.get("ko", false)):
				caidos.append(str(lutador["id"]))
	BeastRecords.record_battle(
		_ids_do_time(vencedor), _ids_do_time(perdedor), caidos
	)


func _ids_do_time(jogador: int) -> Array[String]:
	var ids: Array[String] = []
	for lutador in _teams[jogador]:
		ids.append(str(lutador["id"]))
	return ids


func _quantidade_viva(jogador: int) -> int:
	var total := 0
	for lutador in _teams[jogador]:
		if not bool(lutador["ko"]):
			total += 1
	return total


func _titulo_do_jogador(jogador: int) -> String:
	if GameState.is_human_player(jogador):
		return "JOGADOR %d" % (jogador + 1)
	return "CPU"


# ===========================================================================
# NUMERO DE DANO FLUTUANTE
# ===========================================================================

func _numero_de_dano(alvo: int, cor: Color, texto: String) -> void:
	var ponto := _tela_da_beast(alvo)
	var l := _rotulo(texto, 30, cor, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(420, 44)
	l.position = ponto - Vector2(210.0, 22.0)
	_camada_numeros.add_child(l)

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "position:y", l.position.y - 78.0, 0.85)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.85).set_delay(0.30)
	t.tween_callback(l.queue_free)


# ===========================================================================
# ATUALIZACAO DE INTERFACE
# ===========================================================================

func _atualizar_ui() -> void:
	for jogador in 2:
		var lutador := _lutador(jogador)
		var dados: Dictionary = lutador["data"]
		var cor_tipo := CreatureDB.color_for_type(str(dados["type"]))

		_nome_labels[jogador].text = str(dados["name"])

		_tipo_emblemas[jogador].element = str(dados["type"])
		_tipo_labels[jogador].text = str(dados["type"]).to_upper()
		_tipo_labels[jogador].add_theme_color_override(
			"font_color", cor_tipo.lightened(0.30)
		)

		_peso_labels[jogador].text = "%s • %.1f kg • %s" % [
			dados["weight_class"],
			dados["weight_kg"],
			MoveDB.weight_profile(dados)["label"]
		]

		_hp_bars[jogador].max_value = lutador["max_hp"]
		_hp_bars[jogador].value = lutador["hp"]
		var proporcao := float(lutador["hp"]) / float(lutador["max_hp"])
		var cor_hp := Color("52e788")
		if proporcao <= 0.22:
			cor_hp = Color("ff536d")
		elif proporcao <= 0.5:
			cor_hp = Color("ffca47")
		_hp_bars[jogador].add_theme_stylebox_override("fill", _estilo_barra(cor_hp))
		_hp_labels[jogador].text = "VIDA %d/%d" % [lutador["hp"], lutador["max_hp"]]

		_atualizar_reservas(jogador)

	_turno_label.text = "TURNO %02d • %s" % [_round, _titulo_do_jogador(_turn)]
	_turno_label.add_theme_color_override("font_color", COR_P1 if _turn == 0 else COR_P2)
	_placar.text = "P1 %05d × %05d P2" % [GameState.scores[0], GameState.scores[1]]
	_atualizar_acoes()


func _atualizar_reservas(jogador: int) -> void:
	for filho in _reservas[jogador].get_children():
		filho.queue_free()
	for indice in _teams[jogador].size():
		var lutador: Dictionary = _teams[jogador][indice]
		var ponto := Label.new()
		ponto.text = "◆" if indice == _active[jogador] else "●"
		ponto.add_theme_font_size_override("font_size", 16)
		var cor := Color("ff506c")
		if not bool(lutador["ko"]):
			cor = CreatureDB.color_for_type(str(lutador["data"]["type"]))
		ponto.add_theme_color_override("font_color", cor)
		_reservas[jogador].add_child(ponto)


func _atualizar_acoes() -> void:
	if _botoes.is_empty():
		return
	var lutador := _lutador(_turn)

	for indice in MOVE_COUNT:
		var golpe := _golpe_da_acao(_turn, indice)
		if golpe.is_empty():
			_botoes[indice].text = "—"
			_botoes[indice].disabled = true
			continue
		var recarga := MoveDB.cooldown_left(lutador, str(golpe["id"]))
		var estado := "PRONTO"
		if recarga > 0.001:
			estado = "REC %d" % MoveDB.cooldown_turns(recarga)
		var dano_previsto := MoveDB.damage_preview(lutador, _lutador(1 - _turn), golpe)
		_botoes[indice].text = "%s\nDANO %02d • P%02d • %s" % [
			str(golpe["name"]).to_upper(),
			dano_previsto,
			golpe["power"],
			estado
		]
		var cor_golpe := CreatureDB.color_for_type(str(golpe["element"]))
		_botoes[indice].add_theme_stylebox_override("normal", _estilo_botao(cor_golpe, 0.14))
		_botoes[indice].add_theme_stylebox_override("hover", _estilo_botao(cor_golpe, 0.26))
		_botoes[indice].add_theme_stylebox_override("pressed", _estilo_botao(cor_golpe, 0.38))
		var caminho_icone := str(golpe.get("icon", ""))
		if ResourceLoader.exists(caminho_icone):
			_botoes[indice].icon = load(caminho_icone) as Texture2D
		_botoes[indice].disabled = recarga > 0.001

	var recarga_escudo := int(lutador.get("guard_cooldown", 0))
	_botoes[GUARD_ACTION].text = (
		"ESCUDO\nRECARGA %d" % recarga_escudo
		if recarga_escudo > 0
		else "ESCUDO\n1–3 RODADAS • -52%"
	)
	_botoes[GUARD_ACTION].disabled = (
		recarga_escudo > 0 or bool(lutador.get("guard", false))
	)
	var pode_trocar := _proximo_vivo(_turn, _active[_turn]) != -1
	_botoes[SWITCH_ACTION].text = (
		"TROCAR\nPRÓXIMA BEAST" if pode_trocar else "REAGRUPAR\nPASSAR TURNO"
	)
	_botoes[SWITCH_ACTION].disabled = false
	if ResourceLoader.exists("res://assets/actions/guard.svg"):
		_botoes[GUARD_ACTION].icon = load("res://assets/actions/guard.svg") as Texture2D
	if ResourceLoader.exists("res://assets/actions/switch.svg"):
		_botoes[SWITCH_ACTION].icon = load("res://assets/actions/switch.svg") as Texture2D

	var liberado := not _busy and not _battle_over and GameState.is_human_player(_turn)
	for indice in _botoes.size():
		var selecionado := indice == _action_cursor
		_botoes[indice].modulate = Color.WHITE if selecionado else Color(0.72, 0.76, 0.88)
		_botoes[indice].mouse_filter = (
			Control.MOUSE_FILTER_STOP if liberado else Control.MOUSE_FILTER_IGNORE
		)
