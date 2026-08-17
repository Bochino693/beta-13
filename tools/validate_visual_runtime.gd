extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_rig("brispulo", "ave", "voador", false)
	await _test_rig("pedrilho", "felpudo", "terrestre", true)
	await _test_rig("medulux", "aquatico", "aquatico", false)
	await _test_all_rig_assets()
	await _test_projectile_families()
	await _test_stadium()
	await create_timer(0.20).timeout
	if _failures.is_empty():
		print("VISUAL_RUNTIME_OK: rigs voador/terrestre/aquatico, projétil e arena")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_rig(id_beast: String, family: String, locomotion: String, heavy: bool) -> void:
	var rig := StableBeastRig3D.new()
	root.add_child(rig)
	var configured := rig.configurar(id_beast, 2.2, family, locomotion, false, Color("6ef8ff"))
	if not configured:
		_failures.append("Falha ao configurar rig: " + id_beast)
		rig.queue_free()
		return
	rig.preparar_golpe({
		"role": "pesado" if heavy else "leve",
		"travel_style": "ground" if heavy else "arc",
	})
	rig.entrar(0.02)
	await rig.animacao_terminou
	if heavy:
		rig.carregar(0.03)
		await rig.animacao_terminou
	rig.atacar(0.04)
	await rig.animacao_terminou
	rig.esquivar(1, 0.03)
	await rig.animacao_terminou
	rig.levar_dano(Color("ff6633"), 0.03)
	await rig.animacao_terminou
	rig.queue_free()


func _test_all_rig_assets() -> void:
	var file := FileAccess.open("res://data/creatures.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for data: Dictionary in parsed.get("creatures", []):
		var rig := StableBeastRig3D.new()
		root.add_child(rig)
		var configured := rig.configurar(
			str(data["id"]),
			2.0,
			StableBeastRig3D.familia_de(data),
			StableBeastRig3D.locomocao_de(data),
			false,
			Color("6ef8ff")
		)
		if not configured:
			_failures.append("Arte mestre não configurou: " + str(data["id"]))
		rig.queue_free()
		await process_frame


func _test_projectile_families() -> void:
	var file := FileAccess.open("res://data/moves.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	var tested: Dictionary = {}
	for move: Dictionary in parsed.get("moves", []):
		var family := str(move.get("effect_family", "orb"))
		if tested.has(family):
			continue
		tested[family] = true
		var path := str(move.get("sprite_sheet", ""))
		var texture := load(path) as Texture2D
		if texture == null:
			_failures.append("FX de validação ausente: " + path)
			continue
		var projectile := PhysicalProjectile.new()
		projectile.disparar(
			root,
			Vector3(-1.0, 1.0, 0.0),
			Vector3(1.0, 1.0, -3.0),
			texture,
			Color("ffb347"),
			false,
			move
		)
		await projectile.impacto_alcancado
		await create_timer(0.09).timeout
	print("PROJECTILE_FAMILIES_OK: %d famílias" % tested.size())


func _test_stadium() -> void:
	var arena_db_script := load("res://scripts/autoload/arena_db.gd") as Script
	var arena_db: Variant = arena_db_script.new()
	root.add_child(arena_db as Node)
	await process_frame
	var arena: Dictionary = arena_db.get_arena("nexus_elemental")
	var stadium := BattleStadium3D.new()
	root.add_child(stadium)
	stadium.configurar(
		Color("6ef8ff"), Color("ff55c6"), "", "", str(arena.get("path", ""))
	)
	stadium.reagir_golpe(
		{"effect_family": "fissure", "scene_reaction": "lava_crack"},
		Color("ff632e"),
		1.0,
		Vector3(0.0, 0.0, -2.0)
	)
