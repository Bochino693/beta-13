extends Node

const DATA_PATH := "res://data/creatures.json"
const ELEMENTS := ["Luz", "Escuridão", "Fogo", "Choque", "Terra", "Água", "Natureza", "Vento"]

var creatures: Array[Dictionary] = []
var creatures_by_id: Dictionary = {}

const TYPE_COLORS := {
	"Luz": Color("ffe477"),
	"Escuridão": Color("a856ff"),
	"Fogo": Color("ff5733"),
	"Choque": Color("ffdb32"),
	"Terra": Color("c58b52"),
	"Água": Color("27bcff"),
	"Natureza": Color("50d35a"),
	"Vento": Color("9cf4e8")
}

const STRONG_AGAINST := {
	"Luz": ["Escuridão", "Natureza"],
	"Escuridão": ["Vento", "Água"],
	"Fogo": ["Luz", "Natureza"],
	"Choque": ["Água", "Vento"],
	"Terra": ["Choque", "Fogo"],
	"Água": ["Fogo", "Terra"],
	"Natureza": ["Terra", "Água"],
	"Vento": ["Natureza", "Luz"]
}


func _ready() -> void:
	_load_catalog()


func _load_catalog() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de criaturas não encontrado: %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("creatures"):
		push_error("Catálogo de criaturas inválido.")
		return
	creatures.clear()
	creatures_by_id.clear()
	for entry in parsed["creatures"]:
		var creature: Dictionary = entry.duplicate(true)
		if str(creature.get("type", "")) not in ELEMENTS:
			push_error("Elemento inválido em %s: %s" % [creature.get("id", "?"), creature.get("type", "?")])
		creatures.append(creature)
		creatures_by_id[creature["id"]] = creature
	if creatures.size() != 30:
		push_warning("O catálogo deveria ter 30 criaturas; foram carregadas %d." % creatures.size())


func all() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for creature in creatures:
		output.append(creature.duplicate(true))
	return output


func get_creature(creature_id: String) -> Dictionary:
	if not creatures_by_id.has(creature_id):
		return {}
	return creatures_by_id[creature_id].duplicate(true)


func color_for_type(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color.WHITE)


func type_multiplier(attack_type: String, defender_type: String) -> float:
	if attack_type == defender_type:
		return 0.82
	if defender_type in STRONG_AGAINST.get(attack_type, []):
		return 1.45
	if attack_type in STRONG_AGAINST.get(defender_type, []):
		return 0.68
	return 1.0


func effectiveness_text(multiplier: float) -> String:
	if multiplier >= 1.4:
		return "SUPER EFETIVO!"
	if multiplier <= 0.7:
		return "RESISTIU AO TIPO"
	if multiplier < 0.9:
		return "MESMO TIPO: DANO REDUZIDO"
	return "ACERTO LIMPO"


func max_hp(data: Dictionary) -> int:
	return MoveDB.max_hp(data)


func make_fighter(creature_id: String) -> Dictionary:
	var data := get_creature(creature_id)
	var hp := max_hp(data)
	return {
		"id": creature_id,
		"data": data,
		"hp": hp,
		"max_hp": hp,
		"energy": 0,
		"cooldowns": {},
		"guard": false,
		"guard_turns": 0,
		"guard_cooldown": 0,
		"ko": false,
		"round_damage": 0
	}


func random_team(team_size: int = 5, excluded: Array = []) -> Array[String]:
	var pool: Array[String] = []
	for creature in creatures:
		var creature_id: String = creature["id"]
		if creature_id not in excluded:
			pool.append(creature_id)
	pool.shuffle()
	return pool.slice(0, mini(team_size, pool.size()))
