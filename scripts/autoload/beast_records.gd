extends Node

## CADERNETA DA ARENA — quantas batalhas cada Beast disputou e venceu.
##
## Fica separada do combate de proposito. `move_db.gd` e `creature_db.gd`
## decidem dano, vida e recarga; aqui so se ANOTA o que ja aconteceu. Uma
## Beast com 200 vitorias bate exatamente igual a uma recem-tirada do
## pacote: se o historico entrasse na conta, quem jogasse mais teria
## vantagem permanente e `tools/simulate_balance.py` deixaria de descrever
## o jogo instalado.
##
## O arquivo vive em `user://`, entao sobrevive ao fechar o jogo sem sujar
## `data/` (que e catalogo versionado, nao progresso de jogador).

const RECORDS_PATH := "user://lazer_beasts_records.json"
const VERSION := 1

## Emitido depois que uma batalha inteira foi anotada, para as telas
## atualizarem contadores sem ficar consultando a cada quadro.
signal records_updated

var _records: Dictionary = {}


func _ready() -> void:
	_load()


## --- LEITURA -------------------------------------------------------------


func record_for(creature_id: String) -> Dictionary:
	var entrada: Dictionary = _records.get(creature_id, {})
	return {
		"battles": int(entrada.get("battles", 0)),
		"wins": int(entrada.get("wins", 0)),
		"losses": int(entrada.get("losses", 0)),
		"knockouts": int(entrada.get("knockouts", 0)),
		"best_streak": int(entrada.get("best_streak", 0)),
		"streak": int(entrada.get("streak", 0)),
	}


func wins(creature_id: String) -> int:
	return int(_records.get(creature_id, {}).get("wins", 0))


func battles(creature_id: String) -> int:
	return int(_records.get(creature_id, {}).get("battles", 0))


func losses(creature_id: String) -> int:
	return int(_records.get(creature_id, {}).get("losses", 0))


## Aproveitamento em 0..1. Sem batalha nenhuma devolve 0.0 em vez de dividir
## por zero — a tela mostra "—" nesse caso.
func win_rate(creature_id: String) -> float:
	var total := battles(creature_id)
	if total <= 0:
		return 0.0
	return float(wins(creature_id)) / float(total)


func has_history(creature_id: String) -> bool:
	return battles(creature_id) > 0


func total_wins() -> int:
	var soma := 0
	for creature_id: String in _records.keys():
		soma += wins(creature_id)
	return soma


func total_battles() -> int:
	var soma := 0
	for creature_id: String in _records.keys():
		soma += battles(creature_id)
	return soma


## Beasts com mais vitorias, da maior para a menor. Empate desempata pelo
## aproveitamento e depois pelo id, para a ordem nao mudar sozinha entre
## duas aberturas do jogo.
func ranking(limit: int = 5) -> Array[Dictionary]:
	var linhas: Array[Dictionary] = []
	for creature in CreatureDB.creatures:
		var creature_id := str(creature["id"])
		if not has_history(creature_id):
			continue
		var linha := record_for(creature_id)
		linha["id"] = creature_id
		linha["name"] = str(creature.get("name", creature_id))
		linha["rarity"] = CreatureDB.rarity_of(creature)
		linha["win_rate"] = win_rate(creature_id)
		linhas.append(linha)
	linhas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["wins"]) != int(b["wins"]):
				return int(a["wins"]) > int(b["wins"])
			if not is_equal_approx(float(a["win_rate"]), float(b["win_rate"])):
				return float(a["win_rate"]) > float(b["win_rate"])
			return str(a["id"]) < str(b["id"])
	)
	if limit <= 0:
		return linhas
	return linhas.slice(0, mini(limit, linhas.size()))


## Quantas Beasts distintas de cada raridade ja venceram ao menos uma vez.
func wins_by_rarity() -> Dictionary:
	var contagem: Dictionary = {}
	for rarity: String in CreatureDB.RARITIES:
		contagem[rarity] = 0
	for creature in CreatureDB.creatures:
		var creature_id := str(creature["id"])
		if wins(creature_id) <= 0:
			continue
		var rarity := CreatureDB.rarity_of(creature)
		if contagem.has(rarity):
			contagem[rarity] = int(contagem[rarity]) + 1
	return contagem


## --- ESCRITA -------------------------------------------------------------


## Anota uma batalha inteira: todo mundo que entrou soma uma participacao,
## o time vencedor soma vitoria e o perdedor soma derrota. Chamada UMA vez,
## no fim da batalha, para uma revanche nao contar duas vezes.
func record_battle(winner_ids: Array, loser_ids: Array, knockout_ids: Array = []) -> void:
	for creature_id: Variant in winner_ids:
		_apply(str(creature_id), true)
	for creature_id: Variant in loser_ids:
		_apply(str(creature_id), false)
	for creature_id: Variant in knockout_ids:
		var entrada := _entry(str(creature_id))
		entrada["knockouts"] = int(entrada.get("knockouts", 0)) + 1
	_save()
	records_updated.emit()


func reset_all() -> void:
	_records.clear()
	_save()
	records_updated.emit()


func _apply(creature_id: String, venceu: bool) -> void:
	if creature_id.is_empty():
		return
	var entrada := _entry(creature_id)
	entrada["battles"] = int(entrada.get("battles", 0)) + 1
	if venceu:
		entrada["wins"] = int(entrada.get("wins", 0)) + 1
		entrada["streak"] = int(entrada.get("streak", 0)) + 1
		entrada["best_streak"] = maxi(
			int(entrada.get("best_streak", 0)), int(entrada["streak"])
		)
	else:
		entrada["losses"] = int(entrada.get("losses", 0)) + 1
		entrada["streak"] = 0


func _entry(creature_id: String) -> Dictionary:
	if not _records.has(creature_id):
		_records[creature_id] = {
			"battles": 0, "wins": 0, "losses": 0,
			"knockouts": 0, "streak": 0, "best_streak": 0,
		}
	return _records[creature_id]


## --- PERSISTENCIA --------------------------------------------------------


func _save() -> void:
	var file := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível gravar a caderneta: %s" % RECORDS_PATH)
		return
	file.store_string(JSON.stringify({"version": VERSION, "records": _records}, "\t"))


func _load() -> void:
	_records.clear()
	if not FileAccess.file_exists(RECORDS_PATH):
		return
	var file := FileAccess.open(RECORDS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Caderneta ilegível; começando do zero.")
		return
	var guardados: Variant = (parsed as Dictionary).get("records", {})
	if not guardados is Dictionary:
		return
	## So aceita ids que ainda existem no catalogo: uma Beast removida nao
	## deve ressuscitar como entrada fantasma no ranking.
	for creature_id: Variant in (guardados as Dictionary).keys():
		var id_texto := str(creature_id)
		if not CreatureDB.creatures_by_id.has(id_texto):
			continue
		var bruto: Variant = (guardados as Dictionary)[creature_id]
		if not bruto is Dictionary:
			continue
		var entrada: Dictionary = bruto as Dictionary
		_records[id_texto] = {
			"battles": maxi(0, int(entrada.get("battles", 0))),
			"wins": maxi(0, int(entrada.get("wins", 0))),
			"losses": maxi(0, int(entrada.get("losses", 0))),
			"knockouts": maxi(0, int(entrada.get("knockouts", 0))),
			"streak": maxi(0, int(entrada.get("streak", 0))),
			"best_streak": maxi(0, int(entrada.get("best_streak", 0))),
		}
