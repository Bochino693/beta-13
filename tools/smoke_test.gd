extends Node

## SMOKE TEST DO JOGO INTEIRO — roda com:
##   godot --headless --path . res://tools/smoke_test.tscn
##
## Existe por um motivo especifico: os erros deste projeto apareciam UM DE
## CADA VEZ, porque so estouravam quando a tela em questao era aberta a mao.
## Consertava-se um, abria-se a proxima tela, aparecia outro. Aqui tudo e
## exercitado de uma vez — as sete cenas, a hierarquia elemental, as 30
## Beasts com seus cinco golpes, a raridade, a caderneta e um fim de
## batalha real — entao a lista inteira de problemas sai numa passada so.
##
## Precisa ser CENA, nao `--script`: autoload nao carrega em modo script, e
## e justamente nos autoloads que mora a maior parte das regras.
##
## Sai com codigo 0 e imprime SMOKE_DONE quando termina. Qualquer
## `push_error` aparece na saida com o rastro de onde veio.

const SCENES := [
	"res://scenes/brand_intro.tscn",
	"res://scenes/opening.tscn",
	"res://scenes/mode_select.tscn",
	"res://scenes/power_guide.tscn",
	"res://scenes/team_select.tscn",
	"res://scenes/battle.tscn",
	"res://scenes/results.tscn",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== AUTOLOADS ===")
	print("CreatureDB: ", CreatureDB.creatures.size(), " criaturas, ", CreatureDB.ELEMENTS.size(), " elementos")
	print("MoveDB: ", MoveDB.moves.size(), " golpes")
	print("ArenaDB: ", ArenaDB.all().size(), " arenas")

	print("=== API HIERARQUIA ===")
	for element: String in CreatureDB.ELEMENTS:
		var a: Array = MoveDB.strongest_against(element)
		var b: Array[String] = MoveDB.vulnerable_to(element)
		var c: Array = CreatureDB.strong_against(element)
		var d: Array = CreatureDB.weak_against(element)
		print("  %s: vence %d, perde %d (%d/%d)" % [element, a.size(), b.size(), c.size(), d.size()])
	print("  rival_pairs: ", CreatureDB.rival_pairs())

	print("=== API CRIATURAS ===")
	for creature in CreatureDB.all():
		var id: String = creature["id"]
		var fighter: Dictionary = CreatureDB.make_fighter(id)
		var _hp: int = MoveDB.max_hp(creature)
		var moves: Array[Dictionary] = MoveDB.moves_for_creature(creature)
		if moves.size() != 5:
			push_error("criatura %s tem %d golpes" % [id, moves.size()])
		for m in moves:
			var _cd: float = MoveDB.effective_cooldown(m, creature)
			var _g: String = MoveDB.power_grade(m)
			var _dmg: int = MoveDB.damage_preview(fighter, fighter, m)

	print("=== RARIDADE ===")
	print("  faixas: ", CreatureDB.RARITIES)
	print("  contagem: ", CreatureDB.rarity_counts())
	for creature in CreatureDB.all():
		var r: String = CreatureDB.rarity_of(creature)
		if r not in CreatureDB.RARITIES:
			push_error("raridade invalida em %s: %s" % [creature["id"], r])
		var _lbl: String = CreatureDB.rarity_label(r)
		var _col: Color = CreatureDB.rarity_color(r)
		var _rank: int = CreatureDB.rarity_rank(r)
	for rarity: String in CreatureDB.RARITIES:
		var lista: Array[Dictionary] = CreatureDB.creatures_of_rarity(rarity)
		print("  %s: %d" % [rarity, lista.size()])
	for i in 50:
		var _sorteio: String = CreatureDB.random_rarity()

	print("=== CADERNETA ===")
	BeastRecords.reset_all()
	var time_a: Array[String] = CreatureDB.random_team(3)
	var time_b: Array[String] = CreatureDB.random_team(3, time_a)
	BeastRecords.record_battle(time_a, time_b, [time_b[0]])
	BeastRecords.record_battle(time_a, time_b)
	print("  campea %s: %d vitorias em %d batalhas (%.0f%%)" % [
		time_a[0], BeastRecords.wins(time_a[0]), BeastRecords.battles(time_a[0]),
		BeastRecords.win_rate(time_a[0]) * 100.0])
	print("  perdedora %s: %d vitorias, %d derrotas" % [
		time_b[0], BeastRecords.wins(time_b[0]), BeastRecords.losses(time_b[0])])
	print("  total: %d vitorias / %d batalhas" % [BeastRecords.total_wins(), BeastRecords.total_battles()])
	print("  ranking: ", BeastRecords.ranking(3).size(), " linhas")
	print("  por raridade: ", BeastRecords.wins_by_rarity())
	if BeastRecords.wins(time_a[0]) != 2 or BeastRecords.losses(time_b[0]) != 2:
		push_error("caderneta nao somou corretamente")
	if BeastRecords.record_for(time_a[0])["best_streak"] != 2:
		push_error("sequencia de vitorias errada")

	print("=== BATALHA SIMULADA ===")
	_simulate_battle()

	print("=== CENAS ===")
	for path in SCENES:
		await _load_scene(path)

	print("=== FIM DE BATALHA REAL (_encerrar -> caderneta) ===")
	await _test_encerrar()

	await get_tree().create_timer(0.2).timeout
	print("SMOKE_DONE")
	get_tree().quit(0)


func _simulate_battle() -> void:
	var a := CreatureDB.random_team(3)
	var b := CreatureDB.random_team(3, a)
	GameState.begin_mode("pvp")
	GameState.set_team(0, a)
	GameState.set_team(1, b)
	GameState.resolve_arena_for_battle()
	var t0: Array[Dictionary] = GameState.runtime_team(0)
	var t1: Array[Dictionary] = GameState.runtime_team(1)
	var atk: Dictionary = t0[0]
	var def: Dictionary = t1[0]
	var turns := 0
	while not bool(def.get("ko", false)) and turns < 200:
		turns += 1
		MoveDB.begin_fighter_turn(atk)
		MoveDB.reduce_cooldowns(atk)
		var moves: Array[Dictionary] = MoveDB.moves_for_creature(atk["data"])
		var used := false
		for m in moves:
			if MoveDB.can_use(atk, m):
				var dmg: int = MoveDB.damage_preview(atk, def, m)
				def["hp"] = int(def["hp"]) - dmg
				MoveDB.set_cooldown(atk, m)
				used = true
				break
		if not used and MoveDB.can_guard(atk):
			MoveDB.activate_guard(atk)
		if int(def["hp"]) <= 0:
			def["ko"] = true
		var tmp := atk
		atk = def
		def = tmp
	print("  batalha resolvida em %d turnos (%d vs %d)" % [turns, t0.size(), t1.size()])


func _load_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("cena ausente: " + path)
		return
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("falhou ao carregar: " + path)
		return
	var node: Node = packed.instantiate()
	get_tree().root.add_child(node)
	for i in 12:
		await get_tree().process_frame
	node.queue_free()
	await get_tree().process_frame
	print("  OK ", path)


## Exercita o caminho REAL de fim de batalha: e ele que grava a caderneta.
## Carregar a cena sem terminar a luta nao passava por `_encerrar()`.
func _test_encerrar() -> void:
	BeastRecords.reset_all()
	var a := CreatureDB.random_team(3)
	var b := CreatureDB.random_team(3, a)
	GameState.begin_mode("cpu")
	GameState.set_team(0, a)
	GameState.set_team(1, b)
	GameState.resolve_arena_for_battle()

	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	for i in 20:
		await get_tree().process_frame

	battle.call("_encerrar", 0)
	for i in 10:
		await get_tree().process_frame

	var venceu := 0
	for creature_id in a:
		if BeastRecords.wins(str(creature_id)) == 1:
			venceu += 1
	var perdeu := 0
	for creature_id in b:
		if BeastRecords.losses(str(creature_id)) == 1:
			perdeu += 1
	print("  vencedores anotados: %d/3 | perdedores anotados: %d/3" % [venceu, perdeu])
	if venceu != 3 or perdeu != 3:
		push_error("_encerrar nao gravou a caderneta corretamente")
	if BeastRecords.total_battles() != 6:
		push_error("caderneta contou %d participacoes; esperado 6" % BeastRecords.total_battles())
	battle.queue_free()
	await get_tree().process_frame
