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
	var rig := BeastRig3D.new()
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


## Toda Beast tem de montar nas DUAS vistas, e cada vista precisa ter todas
## as poses que o combate pede. E aqui que uma arte incompleta aparece,
## antes de chegar ao gabinete.
func _test_all_rig_assets() -> void:
	var estados_exigidos: Array[String] = [
		"idle", "light_charge", "light_impact", "heavy_charge", "heavy_impact",
		"damage", "dodge_left", "dodge_right", "victory", "ko", "guard",
	]
	var file := FileAccess.open("res://data/creatures.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for data: Dictionary in parsed.get("creatures", []):
		var id_beast := str(data["id"])

		var atlas: BeastPoseAtlas = BeastPoseAtlas.abrir(id_beast)
		if not atlas.valido():
			_failures.append("Atlas de combate inválido: " + id_beast)
			continue
		for vista: String in [BeastPoseAtlas.VISTA_COSTAS, BeastPoseAtlas.VISTA_FRENTE]:
			for estado: String in estados_exigidos:
				if atlas.total_de_quadros(vista, estado) <= 0:
					_failures.append(
						"Pose ausente: %s • vista %s • estado %s" % [id_beast, vista, estado]
					)

		## As duas vistas montam de verdade: a de costas e a Beast do
		## jogador, a de frente e a do adversario.
		for de_costas: bool in [true, false]:
			var rig := BeastRig3D.new()
			root.add_child(rig)
			var configured := rig.configurar(
				id_beast,
				2.0,
				BeastRig3D.familia_de(data),
				BeastRig3D.locomocao_de(data),
				de_costas,
				Color("6ef8ff")
			)
			if not configured:
				_failures.append(
					"Rig não configurou: %s (de_costas=%s)" % [id_beast, de_costas]
				)
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
		var projectile := ElementPower3D.new()
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


## Toda arena do catalogo tem de montar e se alinhar a camera. E o
## alinhamento que dimensiona a arte para cobrir o enquadramento; se ele
## falhar, a arena aparece com faixa vazia na borda.
func _test_stadium() -> void:
	var arena_db_script := load("res://scripts/autoload/arena_db.gd") as Script
	var arena_db: Variant = arena_db_script.new()
	root.add_child(arena_db as Node)
	await process_frame

	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(0.0, 3.25, 7.65)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 1.12, -2.15), Vector3.UP)
	await process_frame

	for arena: Dictionary in arena_db.all():
		var caminho := str(arena.get("path", ""))
		if not ResourceLoader.exists(caminho):
			_failures.append("Arte de arena ausente: " + str(arena.get("id", "?")))
			continue
		var palco := BattleArena3D.new()
		root.add_child(palco)
		palco.configurar(Color("6ef8ff"), Color("ff55c6"), "", "", caminho)
		palco.alinhar_camera(camera, Vector2(720.0, 710.0))
		palco.reagir_golpe(
			{"effect_family": "fissure", "scene_reaction": "lava_crack"},
			Color("ff632e"),
			1.0,
			Vector3(0.0, 0.0, -2.0)
		)
		await process_frame
		palco.queue_free()
	camera.queue_free()
