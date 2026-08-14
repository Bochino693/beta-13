extends Node

## Battle V2: integra CinematicBeastSprite3DV5V5 V5, PhysicalProjectile,
## BattleUIV2 e BattleStadium3DV2.
## Substitui a battle.gd original mantendo a lógica de estado.

const ARENA_SCENE := "res://scenes/battle/arena_3d.tscn"
const MOVE_COUNT := 5
const GUARD_ACTION := 5
const SWITCH_ACTION := 6
const ACTION_COUNT := 7

const COR_P1 := Color("6ef8ff")
const COR_P2 := Color("ff55c6")

var _arena: Node3D
var _viewport: SubViewport
var _camera: Camera3D
var _stadium: BattleStadium3DV2
var _encenacao: BattleEncenacao

var _rigs: Array = [null, null]
var _sprites: Array = [null, null]
var _ui: BattleUIV2

var _lutadores: Array = [[], []]
var _ativo: Array = [0, 0]
var _hp: Array = [0, 0]
var _max_hp: Array = [0, 0]
var _guarda: Array = [false, false]
var _guarda_duracao: Array = [0, 0]
var _guarda_recarga: Array = [0, 0]
var _cooldowns: Array = [{}, {}]
var _pontos: Array = [0, 0]
var _rodada: int = 1
var _fim: bool = false

var _busy: bool = false
var _action_cursor: int = 0
var _humano: bool = true

func _ready() -> void:
	_carregar_arena()

func _carregar_arena() -> void:
	var cena := load(ARENA_SCENE) as PackedScene
	if cena == null:
		push_error("BattleV2: arena nao carregada!")
		return
	_arena = cena.instantiate()
	add_child(_arena)
	_viewport = _arena.get_node("SubViewport") as SubViewport
	_camera = _viewport.get_node("Camera3D") as Camera3D

	## Monta estádio V2
	_stadium = BattleStadium3DV2.new()
	_viewport.add_child(_stadium)
	_stadium.montar(_viewport, _camera)
	_stadium.arena_pronta.connect(_iniciar_batalha)

func _iniciar_batalha() -> void:
	## Carrega times do GameState
	_lutadores[0] = _preparar_equipe(GameState.player_team)
	_lutadores[1] = _preparar_equipe(GameState.enemy_team)

	## Monta UI V2
	_ui = BattleUIV2.new()
	_ui.acao_escolhida.connect(_on_acao_escolhida)
	add_child(_ui)
	_ui.montar()
	_ui.definir_placar(_pontos[0], _pontos[1])
	_ui.definir_turno(_rodada, "BATALHA INICIADA", COR_P1)
	_ui.definir_mensagem("A BATALHA COMEÇOU! PREPARE SUA ESTRATÉGIA.")

	## Entra com as primeiras Beasts
	await _trocar_beast(0, 0, false)
	await _trocar_beast(1, 0, false)

	_ui.atualizar_vida(0, _lutadores[0][_ativo[0]], _lutadores[0][_ativo[0]]["data"], COR_P1)
	_ui.atualizar_vida(1, _lutadores[1][_ativo[1]], _lutadores[1][_ativo[1]]["data"], COR_P2)
	_ui.atualizar_reservas(0, _lutadores[0], _ativo[0])
	_ui.atualizar_reservas(1, _lutadores[1], _ativo[1])

	_ui.definir_turno(_rodada, "ESCOLHA SUA AÇÃO", COR_P1)
	_ui.definir_mensagem("ESCOLHA UM GOLPE, ESCUDO OU TROCAR BEAST.")
	_ui.liberado = true

func _preparar_equipe(equipe: Array) -> Array:
	var resultado := []
	for dados in equipe:
		var lutador := {
			"data": dados,
			"hp": dados["base_stats"]["hp"],
			"max_hp": dados["base_stats"]["hp"],
			"ko": false,
			"guard": false,
			"guard_duration": 0,
			"guard_cooldown": 0,
			"cooldowns": {},
			"moves": dados["moves"],
		}
		resultado.append(lutador)
	return resultado

func _trocar_beast(jogador: int, indice: int, animado: bool = true) -> void:
	## Remove sprite anterior
	if _sprites[jogador] != null and is_instance_valid(_sprites[jogador]):
		_sprites[jogador].queue_free()
		_sprites[jogador] = null

	_ativo[jogador] = indice
	var lutador: Dictionary = _lutadores[jogador][indice]
	var dados: Dictionary = lutador["data"]
	var id := str(dados["id"])
	var altura := float(dados["height_m"])
	var familia := CinematicBeastSprite3DV5V5.familia_de(dados)
	var de_costas := (jogador == 0)
	var cor := CreatureDB.color_for_type(str(dados["type"]))

	## Cria sprite V5 com tipo de locomoção
	var sprite := CinematicBeastSprite3DV5V5.new()
	var sucesso := sprite.configurar(id, altura, familia, de_costas, cor)
	if not sucesso:
		push_warning("BattleV2: falha ao carregar sprite de " + id)
		return

	var pos := BattleEncenacao.posicao(jogador)
	if de_costas:
		sprite.position = pos
	else:
		sprite.position = pos
		## Inimigo começa invisível
		sprite.modulate.a = 0.0

	_viewport.add_child(sprite)
	_sprites[jogador] = sprite
	_rigs[jogador] = sprite

	## Registra na encenação
	_stadium.registrar(jogador, sprite, cor)

	## Animação de entrada
	if animado:
		if de_costas:
			await sprite.entrar(0.70)
		else:
			## Fade in do inimigo
			var tween := create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, 0.55)
			await tween.finished
			sprite.repousar()
	else:
		if not de_costas:
			sprite.modulate.a = 1.0
			sprite.repousar()

## === SISTEMA DE AÇÃO ===
func _on_acao_escolhida(indice: int) -> void:
	if _busy or _fim:
		return
	_busy = true
	_ui.liberado = false

	var lutador := _lutadores[0][_ativo[0]]
	var rival := _lutadores[1][_ativo[1]]

	match indice:
		0, 1, 2, 3, 4:
			## Golpe
			if indice >= lutador["moves"].size():
				_busy = false
				_ui.liberado = true
				return
			var golpe_id := str(lutador["moves"][indice])
			var golpe := MoveDB.get_move(golpe_id)
			if golpe == null:
				_busy = false
				_ui.liberado = true
				return
			await _executar_golpe(0, lutador, rival, golpe)

		GUARD_ACTION:
			await _executar_escudo(0, lutador)

		SWITCH_ACTION:
			await _executar_troca(0, lutador)

	if _fim:
		return

	## Turno do inimigo (IA simples)
	await _turno_inimigo()

	## Atualiza UI
	_rodada += 1
	_ui.definir_placar(_pontos[0], _pontos[1])
	_ui.definir_turno(_rodada, "ESCOLHA SUA AÇÃO", COR_P1)
	_ui.definir_mensagem("ESCOLHA UM GOLPE, ESCUDO OU TROCAR BEAST.")
	_ui.atualizar_vida(0, lutador, lutador["data"], COR_P1)
	_ui.atualizar_vida(1, rival, rival["data"], COR_P2)
	_ui.atualizar_reservas(0, _lutadores[0], _ativo[0])
	_ui.atualizar_reservas(1, _lutadores[1], _ativo[1])
	_ui.liberado = true
	_busy = false

func _executar_golpe(atacante: int, lutador: Dictionary, alvo: Dictionary, golpe: Dictionary) -> void:
	var defensor := 1 if atacante == 0 else 0
	var sprite_atacante: CinematicBeastSprite3DV5V5 = _sprites[atacante]
	var sprite_defensor: CinematicBeastSprite3DV5V5 = _sprites[defensor]

	_ui.definir_mensagem("%s USA %s!" % [lutador["data"]["name"], golpe["name"]])

	## Carga
	await sprite_atacante.carregar(0.85)

	## === PROJÉTIL FÍSICO ===
	var pesado := int(golpe["power"]) >= 80
	var origem := sprite_atacante.ponto_emissao()
	var destino := sprite_defensor.ponto_emissao()

	## Carrega textura do golpe
	var tex_golpe: Texture2D = null
	var caminho_golpe := str(golpe.get("projectile_texture", ""))
	if ResourceLoader.exists(caminho_golpe):
		tex_golpe = load(caminho_golpe) as Texture2D
	else:
		## Fallback: usa cor do elemento como projétil sólido
		tex_golpe = _criar_textura_projetil(CreatureDB.color_for_type(str(golpe["element"])))

	## Dispara projétil
	var proj := PhysicalProjectile.new()
	proj.impacto_alcancado.connect(_on_impacto_projetil.bind(defensor, lutador, alvo, golpe, pesado))
	proj.disparar(_viewport, origem, destino, tex_golpe, CreatureDB.color_for_type(str(golpe["element"])), pesado)

	## Animação de ataque do atacante
	await sprite_atacante.atacar(0.62)

	## Aguarda impacto do projétil (sinal conectado acima)
	await proj.impacto_alcancado

func _on_impacto_projetil(defensor: int, lutador: Dictionary, alvo: Dictionary, golpe: Dictionary, pesado: bool) -> void:
	var sprite_defensor: CinematicBeastSprite3DV5V5 = _sprites[defensor]

	## Calcula dano
	var dano := MoveDB.calculate_damage(lutador, alvo, golpe)

	## Aplica guarda
	if bool(alvo.get("guard", false)):
		dano = int(roundf(float(dano) * 0.48))

	alvo["hp"] = maxi(0, alvo["hp"] - dano)

	## Efeitos visuais
	_stadium.impacto(defensor, CreatureDB.color_for_type(str(golpe["element"])), pesado)
	_stadium.congelar(0.08 if pesado else 0.05)

	## Animação de dano no defensor
	await sprite_defensor.levar_dano(CreatureDB.color_for_type(str(golpe["element"])), 0.42)

	## Verifica KO
	if alvo["hp"] <= 0:
		alvo["ko"] = true
		await sprite_defensor.tombar(0.95)
		_ui.definir_mensagem("%s FOI DERROTADO!" % alvo["data"]["name"])

		## Pontuação
		_pontos[0 if defensor == 1 else 1] += 100 + int(golpe["power"])

		## Verifica fim de batalha
		if _verificar_fim_batalha():
			return

		## Troca automática do defensor
		var proximo := _proximo_vivo(defensor)
		if proximo >= 0:
			await _trocar_beast(defensor, proximo, true)
	else:
		## Recupera posição
		sprite_defensor.repousar()

func _executar_escudo(jogador: int, lutador: Dictionary) -> void:
	var sprite: CinematicBeastSprite3DV5V5 = _sprites[jogador]
	_ui.definir_mensagem("%s LEVANTA O ESCUDO!" % lutador["data"]["name"])

	lutador["guard"] = true
	lutador["guard_duration"] = MoveDB.guard_duration(lutador)
	lutador["guard_cooldown"] = 3

	await sprite.guardar(lutador["guard_duration"])

func _executar_troca(jogador: int, lutador: Dictionary) -> void:
	var proximo := _proximo_vivo(jogador)
	if proximo < 0:
		_ui.definir_mensagem("NENHUMA BEAST DISPONÍVEL!")
		return

	_ui.definir_mensagem("%s VOLTA!" % lutador["data"]["name"])
	var sprite: CinematicBeastSprite3DV5V5 = _sprites[jogador]

	## Fade out
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await tween.finished

	await _trocar_beast(jogador, proximo, true)
	_ui.definir_mensagem("%s ENTRA NA ARENA!" % _lutadores[jogador][proximo]["data"]["name"])

func _turno_inimigo() -> void:
	var lutador := _lutadores[1][_ativo[1]]
	var rival := _lutadores[0][_ativo[0]]

	## IA simples: escolhe golpe mais forte disponível
	var melhor_indice := -1
	var melhor_poder := -1
	for i in range(min(MOVE_COUNT, lutador["moves"].size())):
		var gid := str(lutador["moves"][i])
		var g := MoveDB.get_move(gid)
		if g == null:
			continue
		var recarga := MoveDB.cooldown_left(lutador, gid)
		if recarga > 0.001:
			continue
		if int(g["power"]) > melhor_poder:
			melhor_poder = int(g["power"])
			melhor_indice = i

	if melhor_indice >= 0:
		var golpe := MoveDB.get_move(str(lutador["moves"][melhor_indice]))
		await _executar_golpe(1, lutador, rival, golpe)
	else:
		## Sem golpes disponíveis, tenta escudo
		if lutador["guard_cooldown"] <= 0 and not lutador["guard"]:
			await _executar_escudo(1, lutador)
		else:
			_ui.definir_mensagem("O INIMIGO HESITA...")
			await get_tree().create_timer(0.8).timeout

func _proximo_vivo(jogador: int) -> int:
	for i in range(_lutadores[jogador].size()):
		if i == _ativo[jogador]:
			continue
		if not _lutadores[jogador][i]["ko"]:
			return i
	return -1

func _verificar_fim_batalha() -> bool:
	var p1_vivo := false
	var p2_vivo := false
	for l in _lutadores[0]:
		if not l["ko"]:
			p1_vivo = true
			break
	for l in _lutadores[1]:
		if not l["ko"]:
			p2_vivo = true
			break

	if not p1_vivo:
		_fim = true
		_ui.definir_mensagem("DERROTA...")
		_ui.definir_turno(_rodada, "BATALHA ENCERRADA", Color("ff506c"))
		return true
	if not p2_vivo:
		_fim = true
		_ui.definir_mensagem("VITÓRIA!")
		_ui.definir_turno(_rodada, "BATALHA ENCERRADA", Color("52e788"))
		return true
	return false

func _criar_textura_projetil(cor: Color) -> Texture2D:
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	## Desenha 4 quadros de projétil sólido
	for frame in range(4):
		var cx := 32 + frame * 64
		var cy := 32
		for x in range(256):
			for y in range(64):
				var dx := float(x - cx)
				var dy := float(y - cy)
				var dist := sqrt(dx * dx + dy * dy)
				var raio := 22.0 + sin(float(frame) * 1.57) * 4.0
				if dist < raio:
					var alpha := 1.0 - smoothstep(0.0, raio, dist)
					img.set_pixel(x, y, Color(cor.r, cor.g, cor.b, alpha))

	var tex := ImageTexture.create_from_image(img)
	return tex


