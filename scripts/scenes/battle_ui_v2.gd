class_name BattleUIV2
extends Control

## HUD V2: sem abreviações, informações organizadas, design limpo.
## Substitui a montagem manual de botões da battle.gd original.

signal acao_escolhida(indice: int)

const MOVE_COUNT := 5
const GUARD_ACTION := 5
const SWITCH_ACTION := 6
const ACTION_COUNT := 7

const COR_P1 := Color("6ef8ff")
const COR_P2 := Color("ff55c6")
const COR_ESCUDO := Color("59d7ff")
const COR_TROCA := Color("59e98b")

var _nome_labels: Array[Label] = []
var _tipo_labels: Array[Label] = []
var _peso_labels: Array[Label] = []
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _reservas: Array[HBoxContainer] = []
var _placar: Label
var _turno_label: Label
var _mensagem: Label
var _detalhe_acao: Label
var _botoes: Array[Button] = []
var _fonte_batalha: Font
var _fonte_corpo: Font

var _action_cursor := 0
var _liberado := false

func _ready() -> void:
	var caminho_fonte := "res://assets/battle/fonts/URWGothic-Demi.otf"
	if ResourceLoader.exists(caminho_fonte):
		_fonte_batalha = load(caminho_fonte) as Font
	var caminho_corpo := "res://assets/battle/fonts/URWGothic-Book.otf"
	if ResourceLoader.exists(caminho_corpo):
		_fonte_corpo = load(caminho_corpo) as Font

## Monta toda a interface em faixas.
func montar() -> void:
	var MARGEM := 24.0
	var LARGURA := 720.0
	var ALTURA := 1280.0
	var Y_TOPO := 12.0
	var H_TOPO := 36.0
	var Y_HUD_INIMIGO := 58.0
	var H_HUD := 72.0
	var Y_ARENA := 140.0
	var H_ARENA := 738.0
	var Y_HUD_ALIADO := 888.0
	var Y_MENSAGEM := 970.0
	var H_MENSAGEM := 38.0
	var Y_ACOES := 1018.0
	var util := LARGURA - MARGEM * 2.0

	## Faixa 0 — turno e placar
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

	## Faixas de vida
	_montar_bloco_vida(0, Y_HUD_ALIADO, COR_P1)
	_montar_bloco_vida(1, Y_HUD_INIMIGO, COR_P2)

	## Faixa de mensagem
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

	## Faixa de ações
	var painel := _painel(Color(0.03, 0.05, 0.14, 0.94), Color(0.43, 0.61, 1.0, 0.55))
	painel.position = Vector2(MARGEM, Y_ACOES)
	painel.size = Vector2(util, ALTURA - Y_ACOES - MARGEM)
	add_child(painel)

	var margem := _margem(8)
	painel.add_child(margem)

	var coluna_acoes := VBoxContainer.new()
	coluna_acoes.add_theme_constant_override("separation", 6)
	margem.add_child(coluna_acoes)

	## Barra de detalhe superior
	var faixa_detalhe := PanelContainer.new()
	faixa_detalhe.custom_minimum_size = Vector2(0, 40)
	faixa_detalhe.add_theme_stylebox_override("panel", _estilo_botao(Color("7d8cff"), 0.10))
	coluna_acoes.add_child(faixa_detalhe)
	var margem_detalhe := _margem(5)
	faixa_detalhe.add_child(margem_detalhe)
	_detalhe_acao = _rotulo("", 13, Color("edf3ff"), HORIZONTAL_ALIGNMENT_CENTER)
	_detalhe_acao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detalhe_acao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margem_detalhe.add_child(_detalhe_acao)

	## Grade de botões: 2 colunas para golpes, 1 coluna para ações especiais
	var container_principal := HBoxContainer.new()
	container_principal.add_theme_constant_override("separation", 8)
	coluna_acoes.add_child(container_principal)

	## Coluna esquerda: 5 golpes em grade 1x5
	var coluna_golpes := VBoxContainer.new()
	coluna_golpes.add_theme_constant_override("separation", 5)
	coluna_golpes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_principal.add_child(coluna_golpes)

	for indice in MOVE_COUNT:
		var botao := _criar_botao_golpe(indice)
		coluna_golpes.add_child(botao)
		_botoes.append(botao)

	## Coluna direita: ações especiais (escudo + trocar)
	var coluna_especiais := VBoxContainer.new()
	coluna_especiais.add_theme_constant_override("separation", 5)
	coluna_especiais.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_principal.add_child(coluna_especiais)

	var botao_escudo := _criar_botao_especial(GUARD_ACTION, "ESCUDO", COR_ESCUDO, "reduz 52% do dano")
	coluna_especiais.add_child(botao_escudo)
	_botoes.append(botao_escudo)

	var botao_trocar := _criar_botao_especial(SWITCH_ACTION, "TROCAR BEAST", COR_TROCA, "preserva vida e recargas")
	coluna_especiais.add_child(botao_trocar)
	_botoes.append(botao_trocar)

func _criar_botao_golpe(indice: int) -> Button:
	var botao := Button.new()
	botao.custom_minimum_size = Vector2(0, 52)
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.focus_mode = Control.FOCUS_NONE
	botao.clip_text = false
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao.expand_icon = true
	botao.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.add_theme_font_size_override("font_size", 13)
	if _fonte_batalha != null:
		botao.add_theme_font_override("font", _fonte_batalha)
	botao.add_theme_color_override("font_color", Color.WHITE)
	botao.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.60))
	botao.add_theme_constant_override("icon_max_width", 28)
	botao.add_theme_constant_override("h_separation", 6)
	botao.pressed.connect(_on_acao_pressed.bind(indice))
	return botao

func _criar_botao_especial(indice: int, titulo: String, cor: Color, subtitulo: String) -> Button:
	var botao := Button.new()
	botao.custom_minimum_size = Vector2(0, 80)
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	botao.focus_mode = Control.FOCUS_NONE
	botao.clip_text = false
	botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
	botao.add_theme_font_size_override("font_size", 15)
	if _fonte_batalha != null:
		botao.add_theme_font_override("font", _fonte_batalha)
	botao.add_theme_color_override("font_color", Color.WHITE)
	botao.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.60))
	botao.add_theme_constant_override("icon_max_width", 32)
	botao.text = "%s
%s" % [titulo, subtitulo]

	botao.add_theme_stylebox_override("normal", _estilo_botao(cor, 0.14))
	botao.add_theme_stylebox_override("hover", _estilo_botao(cor, 0.26))
	botao.add_theme_stylebox_override("pressed", _estilo_botao(cor, 0.38))
	botao.add_theme_stylebox_override("disabled", _estilo_botao(Color(0.35, 0.38, 0.5), 0.08))
	botao.pressed.connect(_on_acao_pressed.bind(indice))
	return botao

func _on_acao_pressed(indice: int) -> void:
	if _liberado:
		acao_escolhida.emit(indice)

func _montar_bloco_vida(jogador: int, y: float, cor: Color) -> void:
	var painel := _painel(Color(0.03, 0.05, 0.15, 0.90), Color(cor.r, cor.g, cor.b, 0.55))
	painel.position = Vector2(24.0, y)
	painel.size = Vector2(720.0 - 48.0, 72.0)
	add_child(painel)

	var margem := _margem(6)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 1)
	margem.add_child(coluna)

	## Linha 1: nome + elemento
	var linha1 := HBoxContainer.new()
	linha1.add_theme_constant_override("separation", 10)
	coluna.add_child(linha1)

	var nome := _rotulo("", 20, Color.WHITE)
	nome.add_theme_color_override("font_outline_color", Color("080c1d"))
	nome.add_theme_constant_override("outline_size", 4)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha1.add_child(nome)
	_nome_labels.append(nome)

	var tipo := _rotulo("", 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	tipo.custom_minimum_size = Vector2(104, 18)
	tipo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha1.add_child(tipo)
	_tipo_labels.append(tipo)

	## Linha 2: barra + valor
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
	hp.custom_minimum_size = Vector2(140, 0)
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha2.add_child(hp)
	_hp_labels.append(hp)

	## Linha 3: reservas + peso
	var linha3 := HBoxContainer.new()
	linha3.add_theme_constant_override("separation", 8)
	coluna.add_child(linha3)
	var reservas := HBoxContainer.new()
	reservas.add_theme_constant_override("separation", 7)
	reservas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha3.add_child(reservas)
	_reservas.append(reservas)

	var peso := _rotulo("", 11, Color("ffdf73"), HORIZONTAL_ALIGNMENT_RIGHT)
	peso.custom_minimum_size = Vector2(340, 0)
	peso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha3.add_child(peso)
	_peso_labels.append(peso)

func atualizar_vida(jogador: int, lutador: Dictionary, dados: Dictionary, cor_tipo: Color) -> void:
	_nome_labels[jogador].text = str(dados["name"])

	_tipo_labels[jogador].text = str(dados["type"]).to_upper()
	var selo := StyleBoxFlat.new()
	selo.bg_color = cor_tipo
	selo.set_corner_radius_all(12)
	selo.content_margin_left = 8
	selo.content_margin_right = 8
	_tipo_labels[jogador].add_theme_stylebox_override("normal", selo)

	_peso_labels[jogador].text = "%s  ·  %.1f kg  ·  %s" % [
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
	_hp_labels[jogador].text = "VIDA  %d / %d" % [lutador["hp"], lutador["max_hp"]]

func atualizar_reservas(jogador: int, equipe: Array, ativo: int) -> void:
	for filho in _reservas[jogador].get_children():
		filho.queue_free()
	for indice in equipe.size():
		var lutador: Dictionary = equipe[indice]
		var ponto := Label.new()
		ponto.text = "◆" if indice == ativo else "●"
		ponto.add_theme_font_size_override("font_size", 16)
		var cor := Color("ff506c")
		if not bool(lutador["ko"]):
			cor = CreatureDB.color_for_type(str(lutador["data"]["type"]))
		ponto.add_theme_color_override("font_color", cor)
		_reservas[jogador].add_child(ponto)

func atualizar_acoes(
	turno: int,
	lutador: Dictionary,
	golpes: Array[Dictionary],
	proximo_vivo: bool,
	busy: bool,
	battle_over: bool,
	humano: bool,
	action_cursor: int
) -> void:
	_action_cursor = action_cursor
	_liberado = not busy and not battle_over and humano

	## Atualiza 5 golpes
	for indice in MOVE_COUNT:
		var botao := _botoes[indice]
		if indice >= golpes.size():
			botao.text = "—"
			botao.disabled = true
			continue

		var golpe := golpes[indice]
		var recarga := MoveDB.cooldown_left(lutador, str(golpe["id"]))
		var dano_previsto := MoveDB.damage_preview(lutador, lutador, golpe)  ## placeholder, passar rival depois

		## TEXTO SEM ABREVIAÇÕES
		var estado := "PRONTO"
		if recarga > 0.001:
			var turnos := MoveDB.cooldown_turns(recarga)
			estado = "RECARGA: %d TURNO" % turnos
			if turnos > 1:
				estado += "S"

		var elemento := str(golpe["element"]).to_upper()
		var poder := int(golpe["power"])
		var papel := str(golpe["role"]).to_upper()

		botao.text = "%s
ELEMENTO: %s  ·  DANO: %d  ·  PODER: %d  ·  %s" % [
			str(golpe["name"]).to_upper(),
			elemento,
			dano_previsto,
			poder,
			estado
		]

		var cor_golpe := CreatureDB.color_for_type(str(golpe["element"]))
		botao.add_theme_stylebox_override("normal", _estilo_botao(cor_golpe, 0.14))
		botao.add_theme_stylebox_override("hover", _estilo_botao(cor_golpe, 0.26))
		botao.add_theme_stylebox_override("pressed", _estilo_botao(cor_golpe, 0.38))

		var caminho_icone := str(golpe.get("icon", ""))
		if ResourceLoader.exists(caminho_icone):
			botao.icon = load(caminho_icone) as Texture2D

		botao.disabled = recarga > 0.001

	## Atualiza ESCUDO
	var recarga_escudo := int(lutador.get("guard_cooldown", 0))
	var botao_escudo := _botoes[GUARD_ACTION]
	if recarga_escudo > 0:
		botao_escudo.text = "ESCUDO
RECARGA: %d TURNO" % recarga_escudo
		if recarga_escudo > 1:
			botao_escudo.text += "S"
	else:
		var duracao := MoveDB.guard_duration(lutador)
		botao_escudo.text = "ESCUDO
DURAÇÃO: %d TURNO" % duracao
		if duracao > 1:
			botao_escudo.text += "S"
		botao_escudo.text += "  ·  REDUZ 52% DO DANO"
	botao_escudo.disabled = recarga_escudo > 0 or bool(lutador.get("guard", false))

	## Atualiza TROCAR
	var botao_trocar := _botoes[SWITCH_ACTION]
	if proximo_vivo:
		botao_trocar.text = "TROCAR BEAST
PRESERVA VIDA E RECARGAS"
	else:
		botao_trocar.text = "REAGRUPAR
AVANÇA TURNO SEM TROCAR"
	botao_trocar.disabled = false

	## Destaque do cursor
	for indice in _botoes.size():
		var selecionado := indice == action_cursor
		_botoes[indice].modulate = Color.WHITE if selecionado else Color(0.86, 0.88, 0.95)
		_botoes[indice].mouse_filter = Control.MOUSE_FILTER_STOP if _liberado else Control.MOUSE_FILTER_IGNORE

func atualizar_detalhe(action_cursor: int, lutador: Dictionary, golpes: Array[Dictionary]) -> void:
	if _detalhe_acao == null:
		return

	if action_cursor < MOVE_COUNT and action_cursor < golpes.size():
		var golpe := golpes[action_cursor]
		var dano := MoveDB.damage_preview(lutador, lutador, golpe)
		var recarga := MoveDB.cooldown_left(lutador, str(golpe["id"]))
		var estado := "PRONTO" if recarga <= 0.001 else "RECARGA: %d TURNO(S)" % MoveDB.cooldown_turns(recarga)

		_detalhe_acao.text = "%s  ·  %s  ·  DANO: %d  ·  PODER: %d  ·  RECARGA BASE: %.1fs  ·  %s" % [
			str(golpe["name"]).to_upper(),
			str(golpe["element"]).to_upper(),
			dano,
			int(golpe["power"]),
			float(golpe["cooldown"]),
			estado
		]
	elif action_cursor == GUARD_ACTION:
		_detalhe_acao.text = "ESCUDO  ·  REDUZ 52% DO DANO RECEBIDO  ·  DURA 1–3 TURNOS  ·  RECARGA ALTA"
	else:
		_detalhe_acao.text = "TROCAR BEAST  ·  PRESERVA VIDA ATUAL E RECARGAS  ·  PRÓXIMA BEAST ENTRA NA ARENA"

func definir_mensagem(texto: String) -> void:
	_mensagem.text = texto

func definir_turno(rodada: int, titulo: String, cor: Color) -> void:
	_turno_label.text = "TURNO %02d  ·  %s" % [rodada, titulo]
	_turno_label.add_theme_color_override("font_color", cor)

func definir_placar(p1: int, p2: int) -> void:
	_placar.text = "JOGADOR 1  %05d    ×    %05d  JOGADOR 2" % [p1, p2]

func _rotulo(texto: String, tamanho: int, cor: Color, alinhamento: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
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
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(18)
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	estilo.shadow_size = 8
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", estilo)
	return p

func _estilo_botao(cor: Color, alfa: float) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(cor.r, cor.g, cor.b, alfa)
	e.border_color = Color(cor.r, cor.g, cor.b, 0.70)
	e.set_border_width_all(1)
	e.set_corner_radius_all(13)
	e.content_margin_left = 9
	e.content_margin_right = 9
	e.content_margin_top = 6
	e.content_margin_bottom = 6
	return e

func _estilo_barra(cor: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = cor
	e.set_corner_radius_all(11)
	return e
