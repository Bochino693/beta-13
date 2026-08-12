extends Node

signal card_scanned(creature_id: String, card_code: String)
signal scan_rejected(raw_code: String)

var _creature_by_code: Dictionary = {}


func _ready() -> void:
	call_deferred("_rebuild_index")


func _rebuild_index() -> void:
	_creature_by_code.clear()
	for creature in CreatureDB.creatures:
		var card_code := str(creature.get("card_code", "")).strip_edges().to_upper()
		if not card_code.is_empty():
			_creature_by_code[card_code] = str(creature["id"])


func submit_scan(raw_code: String) -> bool:
	var normalized := raw_code.strip_edges().to_upper()
	if normalized.begins_with("LAZERBEASTS:"):
		var parts := normalized.split(":")
		if parts.size() >= 2:
			normalized = parts[1]
	if not _creature_by_code.has(normalized):
		scan_rejected.emit(raw_code)
		return false
	card_scanned.emit(str(_creature_by_code[normalized]), normalized)
	return true


func creature_for_code(card_code: String) -> Dictionary:
	var normalized := card_code.strip_edges().to_upper()
	if not _creature_by_code.has(normalized):
		return {}
	return CreatureDB.get_creature(str(_creature_by_code[normalized]))
