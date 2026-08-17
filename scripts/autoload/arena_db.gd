extends Node

const DATA_PATH := "res://data/arenas.json"
const AUTO_ID := "auto"

var _arenas: Dictionary = {}
var _order: Array[String] = []


func _ready() -> void:
	_load_arenas()


func _load_arenas() -> void:
	_arenas.clear()
	_order.clear()
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("ArenaDB: arquivo ausente: " + DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("ArenaDB: JSON invalido.")
		return
	for entry in parsed.get("arenas", []):
		if not entry is Dictionary:
			continue
		var arena: Dictionary = entry.duplicate(true)
		var arena_id := str(arena.get("id", ""))
		var path := str(arena.get("path", ""))
		if arena_id.is_empty() or not ResourceLoader.exists(path):
			push_error("ArenaDB: arena invalida: " + arena_id)
			continue
		_arenas[arena_id] = arena
		_order.append(arena_id)


func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for arena_id in _order:
		result.append(get_arena(arena_id))
	return result


func has_arena(arena_id: String) -> bool:
	return _arenas.has(arena_id)


func get_arena(arena_id: String) -> Dictionary:
	if _arenas.has(arena_id):
		return (_arenas[arena_id] as Dictionary).duplicate(true)
	if not _order.is_empty():
		return (_arenas[_order[0]] as Dictionary).duplicate(true)
	return {}


func random_id() -> String:
	if _order.is_empty():
		return ""
	return _order[randi_range(0, _order.size() - 1)]


func resolve_id(requested_id: String) -> String:
	if requested_id != AUTO_ID and has_arena(requested_id):
		return requested_id
	return random_id()


func color(arena_id: String, field: String = "accent") -> Color:
	var arena := get_arena(arena_id)
	return Color(str(arena.get(field, "6ef8ff")))
