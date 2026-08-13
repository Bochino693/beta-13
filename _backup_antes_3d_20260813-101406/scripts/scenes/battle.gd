extends Control

# ---------------------------------------------------------------------------
# BATALHA 2.5D — substituicao completa de scripts/scenes/battle.gd
#
# Mantem 100% das regras de combate originais: dano, recarga, peso, guarda,
# troca, KO, pontuacao, CPU e ida para o resultado. Nada de balanceamento
# mudou.
#
# O que mudou e a apresentacao:
#   - As Beasts vivem num SubViewport 3D real, com chao em perspectiva.
#   - A Beast do jogador aparece de costas, grande, no primeiro plano.
#   - Animacao por deformacao de malha (BeastRig3D), nao spritesheet falso.
#   - O sprite do golpe (assets/moves_fx) toca em 3D, no momento do impacto.
#   - Layout em faixas verticais exclusivas: nada encosta em nada.
#
# NAO precisa mexer em battle.tscn: a raiz continua sendo Control.
# Requer scripts/components/beast_rig_3d.gd.
# ---------------------------------------------------------------------------

const MOVE_COUNT := 5
const GUARD_ACTION := 5
const SWITCH_ACTION := 6
const ACTION_COUNT := 7

# --- Grade de faixas do retrato 720x1280 -----------------------------------
# Ver docs/LAYOUT_RETRATO.md. Nenhum elemento cruza a fronteira da faixa.
const MARGEM := 24.0
const LARGURA := 720.0
const ALTURA := 1280.0

const Y_TOPO := 20.0        # placar + turno
const H_TOPO := 48.0
const Y_HUD_INIMIGO := 78.0
const H_HUD := 120.0
const Y_ARENA := 208.0
const H_ARENA := 478.0
const Y_HUD_ALIADO := 696.0
const Y_MENSAGEM := 826.0
const H_MENSAGEM := 60.0
const Y_ACOES := 896.0

const COR_P1 := Color("6ef8ff")
const COR_P2 := Color("ff55c6")

const CODIGO_CHAO := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec3 cor_base : source_color = vec3(0.03, 0.05, 0.13);
uniform vec3 cor_grade : source_color = vec3(0.25, 0.55, 1.00);
uniform vec3 cor_centro : source_color = vec3(0.55, 0.35, 1.00);
uniform float tempo = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 g = fract(uv * 14.0 + vec2(0.0, tempo * 0.05));
	float linha = min(
		smoothstep(0.0, 0.035, g.x) * smoothstep(0.0, 0.035, 1.0 - g.x),
		smoothstep(0.0, 0.035, g.y) * smoothstep(0.0, 0.035, 1.0 - g.y)
	);
	linha = 1.0 - linha;

	float dist = distance(uv, vec2(0.5, 0.5));
	float halo = smoothstep(0.52, 0.06, dist);
	float pulso = 0.75 + 0.25 * sin(tempo * 1.6 - dist * 9.0);

	vec3 cor = cor_base;
	cor += cor_grade * linha * 0.55 * halo;
	cor += cor_centro * halo * halo * 0.32 * pulso;
	cor = mix(cor, cor_base, smoothstep(0.32, 0.0, uv.y) * 0.9);

	ALBEDO = cor;
	ALPHA = 1.0;
}
"""

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
var _material_chao: ShaderMaterial
var _rigs: Array = [null, null]
var _fx: Array = [null, null]
var _tempo := 0.0

# --- HUD -------------------------------------------------------------------
var _nome_labels: Array[Label] = []
var _tipo_labels: Array[Label] = []
var _peso_labels: Array[Label] = []
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _reservas: Array[HBoxContainer] = []
var _placar: Label
var _turno_label: Label
var _mensagem: Label
var _botoes: Array[Button] = []
var _camada_numeros: Control


func _ready() -> void:
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
	_trocar_rig(0)
	_trocar_rig(1)

	_turn = 0 if _lutador(0)["data"]["speed"] >= _lutador(1)["data"]["speed"] else 1
	AudioSynth.start_music("battle")
	_atualizar_ui()
	_sequencia_de_entrada()
	set_process(true)


func _process(delta: float) -> void:
	_tempo += delta
	if _material_chao != null:
		_material_chao.set_shader_parameter("tempo", _tempo)
	if _camera != null:
		# Respiro lento da camera. Camera parada mata a sensacao de 3D.
		_camera.position.y = 2.00 + sin(_tempo * 0.55) * 0.030
		_camera.position.x = sin(_tempo * 0.31) * 0.040


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

	var shader := Shader.new()
	shader.code = CODIGO_CHAO
	_material_chao = ShaderMaterial.new()
	_material_chao.shader = shader

	var plano := PlaneMesh.new()
	plano.size = Vector2(30.0, 38.0)
	var chao := MeshInstance3D.new()
	chao.mesh = plano
	chao.material_override = _material_chao
	chao.position = Vector3(0.0, 0.0, -6.0)
	chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(chao)

	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = 44.0
	_camera.position = Vector3(0.0, 2.00, 5.20)
	_camera.rotation_degrees = Vector3(-8.5, 0.0, 0.0)
	_camera.near = 0.05
	_camera.far = 90.0
	_viewport.add_child(_camera)
	_camera.make_current()

	# Camada 2D para numeros de dano, alinhada exatamente sobre a faixa.
	_camada_numeros = Control.new()
	_camada_numeros.position = Vector2(0.0, Y_ARENA)
	_camada_numeros.size = Vector2(LARGURA, H_ARENA)
	_camada_numeros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_numeros.clip_contents = true
	add_child(_camada_numeros)


## Constroi (ou reconstroi) o rig da Beast ativa do jogador informado.
func _trocar_rig(jogador: int) -> void:
	if _rigs[jogador] != null and is_instance_valid(_rigs[jogador]):
		_rigs[jogador].queue_free()
	if _fx[jogador] != null and is_instance_valid(_fx[jogador]):
		_fx[jogador].queue_free()

	var dados: Dictionary = _lutador(jogador)["data"]
	var id_beast := str(dados.get("id", ""))
	var de_costas := jogador == 0

	var textura := _textura_da_beast(id_beast, de_costas)
	if textura == null:
		push_error("Batalha: sem textura para " + id_beast)
		return

	var tem_costas := ResourceLoader.exists("res://assets/creatures_back/%s.png" % id_beast)
	var cor := CreatureDB.color_for_type(str(dados.get("type", "Luz")))

	var rig := BeastRig3D.new()
	_viewport.add_child(rig)
	rig.position = Vector3(-0.55, 0.0, 1.30) if de_costas else Vector3(0.40, 0.0, -4.90)
	rig.configurar(
		textura,
		2.85 if de_costas else 2.25,
		BeastRig3D.familia_de(dados),
		de_costas and not tem_costas,
		cor
	)
	if de_costas and tem_costas:
		rig.definir_contraluz(0.25)
	rig.entrar()
	_rigs[jogador] = rig

	# A camada de efeito fica sobre o ALVO, nao sobre o atacante.
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 8
	sprite.pixel_size = 0.0090 if de_costas else 0.0048
	sprite.position = rig.position + Vector3(0.0, 1.25 if not de_costas else 1.45, 0.30)
	sprite.visible = false
	_viewport.add_child(sprite)
	_fx[jogador] = sprite


func _textura_da_beast(id_beast: String, de_costas: bool) -> Texture2D:
	if de_costas:
		var costas := "res://assets/creatures_back/%s.png" % id_beast
		if ResourceLoader.exists(costas):
			return load(costas) as Texture2D
	var frente := "res://assets/creatures_hd/%s.png" % id_beast
	if ResourceLoader.exists(frente):
		return load(frente) as Texture2D
	return null


func _tocar_fx_do_golpe(alvo_jogador: int, golpe: Dictionary) -> void:
	var sprite: Sprite3D = _fx[alvo_jogador]
	if sprite == null or not is_instance_valid(sprite):
		return
	var caminho := str(golpe.get("sprite_sheet", ""))
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		return

	var textura := load(caminho) as Texture2D
	if textura == null:
		return

	# A tira e horizontal e os quadros sao quadrados: quadros = largura/altura.
	var tam := textura.get_size()
	var quadros := maxi(1, roundi(tam.x / maxf(1.0, tam.y)))

	sprite.texture = textura
	sprite.hframes = quadros
	sprite.vframes = 1
	sprite.frame = 0
	sprite.modulate = CreatureDB.color_for_type(str(golpe.get("element", "Luz")))
	sprite.visible = true

	var t := create_tween()
	t.tween_method(
		_definir_quadro_fx.bind(sprite, quadros),
		0.0,
		float(quadros),
		0.050 * float(quadros)
	)
	t.tween_callback(_esconder_fx.bind(sprite))


func _definir_quadro_fx(valor: float, sprite: Sprite3D, quadros: int) -> void:
	if is_instance_valid(sprite):
		sprite.frame = clampi(int(valor), 0, quadros - 1)


func _esconder_fx(sprite: Sprite3D) -> void:
	if is_instance_valid(sprite):
		sprite.visible = false


func _sacudir_camera(forca: float) -> void:
	if _camera == null:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	for i in 6:
		var d := forca * (1.0 - float(i) / 6.0) * 3.0
		t.tween_property(_camera, "rotation_degrees:z", randf_range(-d, d), 0.045)
	t.tween_property(_camera, "rotation_degrees:z", 0.0, 0.10)


func _empurrar_camera() -> void:
	if _camera == null:
		return
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_camera, "fov", 34.0, 0.45)
	t.tween_property(_camera, "fov", 44.0, 0.45)


## Converte a posicao 3D da Beast em coordenada de tela dentro da faixa.
func _tela_da_beast(jogador: int) -> Vector2:
	var rig = _rigs[jogador]
	if rig == null or not is_instance_valid(rig) or _camera == null:
		return Vector2(LARGURA * 0.5, H_ARENA * 0.5)
	var ponto: Vector2 = _camera.unproject_position(rig.global_position + Vector3(0.0, 1.3, 0.0))
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

	_turno_label = _rotulo("", 20, COR_P1)
	_turno_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_turno_label)

	_placar = _rotulo("", 20, Color("ffdf47"), HORIZONTAL_ALIGNMENT_RIGHT)
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

	var margem_msg := _margem(12)
	painel_msg.add_child(margem_msg)
	_mensagem = _rotulo("PREPARE-SE!", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_mensagem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margem_msg.add_child(_mensagem)

	# Faixa 5 — acoes
	var painel := _painel(Color(0.03, 0.05, 0.14, 0.94), Color(0.43, 0.61, 1.0, 0.55))
	painel.position = Vector2(MARGEM, Y_ACOES)
	painel.size = Vector2(util, ALTURA - Y_ACOES - MARGEM)
	add_child(painel)

	var margem := _margem(16)
	painel.add_child(margem)

	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 16)
	grade.add_theme_constant_override("v_separation", 13)
	margem.add_child(grade)

	for indice in ACTION_COUNT:
		var cor := Color("bf6cff")
		if indice == GUARD_ACTION:
			cor = Color("59d7ff")
		elif indice == SWITCH_ACTION:
			cor = Color("59e98b")

		var botao := Button.new()
		botao.custom_minimum_size = Vector2(0, 72)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.focus_mode = Control.FOCUS_NONE
		botao.clip_text = false
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.expand_icon = true
		botao.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.add_theme_font_size_override("font_size", 17)
		botao.add_theme_color_override("font_color", Color.WHITE)
		botao.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.60))
		botao.add_theme_constant_override("icon_max_width", 44)
		botao.add_theme_constant_override("h_separation", 10)
		botao.add_theme_stylebox_override("normal", _estilo_botao(cor, 0.12))
		botao.add_theme_stylebox_override("hover", _estilo_botao(cor, 0.24))
		botao.add_theme_stylebox_override("pressed", _estilo_botao(cor, 0.34))
		botao.add_theme_stylebox_override("disabled", _estilo_botao(Color(0.35, 0.38, 0.5), 0.08))
		botao.pressed.connect(_escolher_acao.bind(indice))
		grade.add_child(botao)
		_botoes.append(botao)


func _montar_bloco_vida(jogador: int, y: float, cor: Color) -> void:
	var painel := _painel(Color(0.03, 0.05, 0.15, 0.90), Color(cor.r, cor.g, cor.b, 0.55))
	painel.position = Vector2(MARGEM, y)
	painel.size = Vector2(LARGURA - MARGEM * 2.0, H_HUD)
	add_child(painel)

	var margem := _margem(14)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	margem.add_child(coluna)

	# Linha 1: quem e + tipo
	var linha1 := HBoxContainer.new()
	linha1.add_theme_constant_override("separation", 10)
	coluna.add_child(linha1)

	var titulo := "JOGADOR %d" % (jogador + 1)
	if not GameState.is_human_player(jogador):
		titulo = "CPU TÁTICA"
	var quem := _rotulo(titulo, 14, cor)
	quem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha1.add_child(quem)

	var tipo := _rotulo("", 14, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	tipo.custom_minimum_size = Vector2(132, 24)
	tipo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha1.add_child(tipo)
	_tipo_labels.append(tipo)

	# Linha 2: nome + peso
	var linha2 := HBoxContainer.new()
	linha2.add_theme_constant_override("separation", 10)
	coluna.add_child(linha2)

	var nome := _rotulo("", 26, Color.WHITE)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha2.add_child(nome)
	_nome_labels.append(nome)

	var peso := _rotulo("", 13, Color("ffdf73"), HORIZONTAL_ALIGNMENT_RIGHT)
	peso.custom_minimum_size = Vector2(300, 0)
	peso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha2.add_child(peso)
	_peso_labels.append(peso)

	# Linha 3: barra + numero
	var linha3 := HBoxContainer.new()
	linha3.add_theme_constant_override("separation", 12)
	coluna.add_child(linha3)

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 22)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_theme_stylebox_override("background", _estilo_barra(Color(0.06, 0.07, 0.13)))
	linha3.add_child(barra)
	_hp_bars.append(barra)

	var hp := _rotulo("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	hp.custom_minimum_size = Vector2(150, 0)
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha3.add_child(hp)
	_hp_labels.append(hp)

	# Linha 4: reservas
	var reservas := HBoxContainer.new()
	reservas.add_theme_constant_override("separation", 9)
	coluna.add_child(reservas)
	_reservas.append(reservas)


func _rotulo(
	texto: String,
	tamanho: int,
	cor: Color,
	alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alinhamento
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
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
	_mensagem.text = "COMEÇA %s • MAIOR VELOCIDADE" % _lutador(_turn)["data"]["name"]
	_busy = false
	_atualizar_ui()
	_talvez_rodar_cpu()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _battle_over or not GameState.is_human_player(_turn):
		return
	var prefixo := "p1_" if _turn == 0 else "p2_"
	if event.is_action_pressed(prefixo + "left"):
		_mover_cursor(-1)
	elif event.is_action_pressed(prefixo + "right"):
		_mover_cursor(1)
	elif event.is_action_pressed(prefixo + "up"):
		_mover_cursor(-2)
	elif event.is_action_pressed(prefixo + "down"):
		_mover_cursor(2)
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
	_busy = true
	await _executar_acao(indice)
	if _battle_over:
		return
	_passar_turno()


func _passar_turno() -> void:
	_turn = 1 - _turn
	MoveDB.reduce_cooldowns(_lutador(_turn))
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
	if bool(defensor["guard"]):
		dano = maxi(4, roundi(dano * 0.48))
		defensor["guard"] = false
	MoveDB.set_cooldown(atacante, golpe)

	var pesado := str(golpe.get("role", "")) == "pesado"
	_mensagem.text = "%s USA %s" % [atacante["data"]["name"], str(golpe["name"]).to_upper()]

	var rig_atacante = _rigs[_turn]
	var rig_alvo = _rigs[alvo_jogador]

	if pesado:
		_empurrar_camera()
		rig_atacante.carregar(0.80)
		await rig_atacante.animacao_terminou

	rig_atacante.atacar(0.78 if pesado else 0.60)
	await rig_atacante.animacao_terminou  # sinal "impacto"

	# Efeito e dano acontecem exatamente no impacto, nunca antes.
	_tocar_fx_do_golpe(alvo_jogador, golpe)
	rig_alvo.levar_dano(CreatureDB.color_for_type(str(golpe["element"])))
	_sacudir_camera(0.42 if pesado else 0.20)

	defensor["hp"] = maxi(0, int(defensor["hp"]) - dano)
	defensor["round_damage"] = int(defensor["round_damage"]) + dano
	GameState.scores[_turn] += dano * (2 if pesado else 1)

	_numero_de_dano(
		alvo_jogador,
		CreatureDB.color_for_type(str(golpe["element"])),
		"%d • %s" % [dano, CreatureDB.effectiveness_text(multiplicador)]
	)

	if pesado:
		AudioSynth.special_hit()
	else:
		AudioSynth.hit(clampf(float(dano) / 45.0, 0.7, 1.25))

	await get_tree().create_timer(0.55).timeout
	_atualizar_ui()

	if int(defensor["hp"]) <= 0:
		await _nocaute(alvo_jogador)
	else:
		await get_tree().create_timer(0.20).timeout


func _defender() -> void:
	var lutador := _lutador(_turn)
	lutador["guard"] = true
	_mensagem.text = "%s ERGUEU UMA BARREIRA" % lutador["data"]["name"]
	AudioSynth.guard()
	_rigs[_turn].definir_cor_elemento(Color("59d7ff"))
	_rigs[_turn].comemorar(0.5)
	await get_tree().create_timer(0.55).timeout
	_rigs[_turn].definir_cor_elemento(
		CreatureDB.color_for_type(str(lutador["data"]["type"]))
	)


func _trocar_beast() -> void:
	var proximo := _proximo_vivo(_turn, _active[_turn])
	if proximo == -1 or proximo == _active[_turn]:
		_mensagem.text = "NÃO HÁ OUTRA BEAST DISPONÍVEL"
		AudioSynth.ui_cancel()
		await get_tree().create_timer(0.42).timeout
		return
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
	_mensagem.text = "%s VENCEU A BATALHA!" % _titulo_do_jogador(vencedor)
	AudioSynth.stop_music()
	AudioSynth.victory()
	_rigs[vencedor].comemorar(1.2)
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
	if randf() < 0.10:
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
	return melhor if melhor >= 0 else GUARD_ACTION


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

		_tipo_labels[jogador].text = str(dados["type"]).to_upper()
		var selo := StyleBoxFlat.new()
		selo.bg_color = cor_tipo
		selo.set_corner_radius_all(12)
		selo.content_margin_left = 8
		selo.content_margin_right = 8
		_tipo_labels[jogador].add_theme_stylebox_override("normal", selo)

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
			estado = "RECARGA %d" % MoveDB.cooldown_turns(recarga)
		_botoes[indice].text = "%s\n%s • P%02d • %s" % [
			str(golpe["name"]).to_upper(),
			MoveDB.power_grade(golpe),
			golpe["power"],
			estado
		]
		var caminho_icone := str(golpe.get("icon", ""))
		if ResourceLoader.exists(caminho_icone):
			_botoes[indice].icon = load(caminho_icone) as Texture2D
		_botoes[indice].disabled = recarga > 0.001

	_botoes[GUARD_ACTION].text = "DEFENDER\nREDUZ 52% DO DANO"
	_botoes[SWITCH_ACTION].text = "TROCAR\nPRÓXIMA BEAST"
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
