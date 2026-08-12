extends Node

const DATA_PATH := "res://data/moves.json"

const WEIGHT_PROFILES := {
	"Ultra Leve": {"cooldown": 0.70, "hp_bonus": 0, "damage": 1.08, "label": "RECARGA RELÂMPAGO"},
	"Leve": {"cooldown": 0.82, "hp_bonus": 8, "damage": 1.05, "label": "RECARGA RÁPIDA"},
	"Médio": {"cooldown": 1.00, "hp_bonus": 16, "damage": 1.00, "label": "EQUILIBRADO"},
	"Pesado": {"cooldown": 1.16, "hp_bonus": 22, "damage": 0.96, "label": "ALTA RESISTÊNCIA"},
	"Colossal": {"cooldown": 1.30, "hp_bonus": 24, "damage": 0.92, "label": "VIDA MÁXIMA"}
}

var moves: Array[Dictionary] = []
var moves_by_id: Dictionary = {}


func _ready() -> void:
	_load_catalog()


func _load_catalog() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de golpes não encontrado: %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("moves"):
		push_error("Catálogo de golpes inválido.")
		return
	moves.clear()
	moves_by_id.clear()
	for entry in parsed["moves"]:
		var move: Dictionary = entry.duplicate(true)
		moves.append(move)
		moves_by_id[move["id"]] = move
	if moves.size() != 80:
		push_error("Eram esperados 80 golpes; foram carregados %d." % moves.size())


func get_move(move_id: String) -> Dictionary:
	if not moves_by_id.has(move_id):
		return {}
	return moves_by_id[move_id].duplicate(true)


func moves_for_creature(creature: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for move_id in creature.get("moves", []):
		var move := get_move(str(move_id))
		if not move.is_empty():
			result.append(move)
	return result


func weight_profile(creature: Dictionary) -> Dictionary:
	return WEIGHT_PROFILES.get(str(creature.get("weight_class", "Médio")), WEIGHT_PROFILES["Médio"])


func max_hp(creature: Dictionary) -> int:
	var resistance := float(creature.get("resistance", 60))
	var profile := weight_profile(creature)
	return roundi(145.0 + resistance * 1.55 + float(profile["hp_bonus"]))


func effective_cooldown(move: Dictionary, creature: Dictionary) -> float:
	var base := float(move.get("cooldown", 1.0))
	var factor := float(weight_profile(creature)["cooldown"])
	return snappedf(maxf(0.35, base * factor), 0.05)


func cooldown_turns(value: float) -> int:
	return maxi(0, ceili(value - 0.001))


func reduce_cooldowns(fighter: Dictionary, amount: float = 1.0) -> void:
	var current: Dictionary = fighter.get("cooldowns", {})
	for move_id in current.keys():
		current[move_id] = maxf(0.0, float(current[move_id]) - amount)
	fighter["cooldowns"] = current


func set_cooldown(fighter: Dictionary, move: Dictionary) -> void:
	var current: Dictionary = fighter.get("cooldowns", {})
	current[str(move["id"])] = effective_cooldown(move, fighter["data"])
	fighter["cooldowns"] = current


func cooldown_left(fighter: Dictionary, move_id: String) -> float:
	return float(fighter.get("cooldowns", {}).get(move_id, 0.0))


func can_use(fighter: Dictionary, move: Dictionary) -> bool:
	return cooldown_left(fighter, str(move["id"])) <= 0.001


func damage_preview(attacker: Dictionary, defender: Dictionary, move: Dictionary) -> int:
	var attack_data: Dictionary = attacker["data"]
	var defense_data: Dictionary = defender["data"]
	var attack_ratio := pow(float(attack_data["attack"]) / maxf(42.0, float(defense_data["defense"])), 0.62)
	var resistance_factor := 1.0 - clampf(float(defense_data["resistance"]) / 590.0, 0.06, 0.17)
	var type_factor := CreatureDB.type_multiplier(str(move["element"]), str(defense_data["type"]))
	var weight_factor := float(weight_profile(attack_data)["damage"])
	return maxi(6, roundi(float(move["power"]) * attack_ratio * resistance_factor * type_factor * weight_factor))


func power_grade(move: Dictionary) -> String:
	var power := int(move.get("power", 0))
	if power >= 45:
		return "S"
	if power >= 38:
		return "A"
	if power >= 31:
		return "B"
	return "C"


func strongest_against(element: String) -> Array:
	return CreatureDB.STRONG_AGAINST.get(element, []).duplicate()


func vulnerable_to(element: String) -> Array[String]:
	var result: Array[String] = []
	for attacker in CreatureDB.ELEMENTS:
		if element in CreatureDB.STRONG_AGAINST.get(attacker, []):
			result.append(attacker)
	return result
