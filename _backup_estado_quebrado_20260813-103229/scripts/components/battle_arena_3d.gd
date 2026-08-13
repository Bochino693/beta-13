class_name BattleArena3D
extends Node3D

## Arena volumétrica da batalha. Não usa background plano: piso, arquibancada,
## público, telão, luzes e marcadores de posição existem no World3D.

const LANE_X := [-2.35, 0.0, 2.35]
const PLAYER_Z := 2.35
const OPPONENT_Z := -4.10

var camera: Camera3D
var _time := 0.0
var _screen_material: StandardMaterial3D
var _lane_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_stands()
	_build_crowd()
	_build_lights_and_screen()
	_build_lane_markers()
	_build_camera()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if camera:
		camera.position.x = sin(_time * 0.26) * 0.055
		camera.position.y = 4.78 + sin(_time * 0.48) * 0.035
		camera.look_at(Vector3(0.0, 1.15, -1.55), Vector3.UP)
	if _screen_material:
		var pulse := 1.45 + sin(_time * 1.8) * 0.22
		_screen_material.emission_energy_multiplier = pulse


func lane_position(player: int, lane: int) -> Vector3:
	return Vector3(LANE_X[clampi(lane, 0, 2)], 0.08, PLAYER_Z if player == 0 else OPPONENT_Z)


func effect_origin(player: int, lane: int) -> Vector3:
	var point := lane_position(player, lane)
	point.y = 1.42 if player == 0 else 1.22
	point.z += -0.58 if player == 0 else 0.58
	return point


func impact_point(player: int, lane: int) -> Vector3:
	var point := lane_position(player, lane)
	point.y = 1.20 if player == 0 else 1.08
	return point


func highlight_lane(player: int, lane: int, active: bool, danger: bool = false) -> void:
	var index := player * 3 + clampi(lane, 0, 2)
	if index < 0 or index >= _lane_materials.size():
		return
	var material := _lane_materials[index]
	material.emission = Color("ff3f62") if danger else Color("5ae9ff")
	material.emission_energy_multiplier = 3.4 if active else 0.75
	material.albedo_color.a = 0.50 if active else 0.18


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("020713")
	sky_material.sky_horizon_color = Color("17244a")
	sky_material.ground_bottom_color = Color("01030a")
	sky_material.ground_horizon_color = Color("101c38")
	sky_material.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_bloom = 0.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_floor() -> void:
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 7.4
	floor_mesh.bottom_radius = 7.4
	floor_mesh.height = 0.18
	floor_mesh.radial_segments = 64
	var floor_material := _material(Color("07142b"), Color("183a73"), 0.68, 0.36)
	_add_mesh("ArenaFloor", floor_mesh, Vector3(0, -0.09, -1.2), Vector3.ONE, floor_material)

	for ring in 4:
		var radius := 1.75 + float(ring) * 1.45
		for segment in 48:
			var angle := TAU * float(segment) / 48.0
			var bar := BoxMesh.new()
			bar.size = Vector3(0.035, 0.018, TAU * radius / 48.0 * 0.88)
			var node := _add_mesh(
				"FloorRing",
				bar,
				Vector3(sin(angle) * radius, 0.015, cos(angle) * radius - 1.2),
				Vector3.ONE,
				_material(Color("17365b"), Color("43b9ff"), 0.1, 1.65)
			)
			node.rotation.y = angle

	var center := CylinderMesh.new()
	center.top_radius = 1.18
	center.bottom_radius = 1.18
	center.height = 0.025
	center.radial_segments = 48
	_add_mesh(
		"CenterSeal", center, Vector3(0, 0.025, -1.2), Vector3.ONE,
		_material(Color("2b174b"), Color("b966ff"), 0.2, 2.0)
	)


func _build_stands() -> void:
	var stand_material := _material(Color("081124"), Color("12254d"), 0.72, 0.18)
	for side in [-1.0, 1.0]:
		for tier in 4:
			var stand := BoxMesh.new()
			stand.size = Vector3(1.25, 0.65, 13.5)
			_add_mesh(
				"SideStand",
				stand,
				Vector3(side * (7.2 + tier * 0.60), 0.45 + tier * 0.55, -1.8),
				Vector3.ONE,
				stand_material
			)
	for tier in 4:
		var back := BoxMesh.new()
		back.size = Vector3(12.8 - tier * 0.5, 0.62, 1.15)
		_add_mesh(
			"BackStand", back,
			Vector3(0, 0.48 + tier * 0.55, -8.15 - tier * 0.48),
			Vector3.ONE, stand_material
		)


func _build_crowd() -> void:
	var crowd_mesh := BoxMesh.new()
	crowd_mesh.size = Vector3(0.11, 0.22, 0.11)
	var crowd_material := _material(Color("101b39"), Color("6f88ff"), 0.35, 1.1)
	crowd_mesh.material = crowd_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = crowd_mesh
	multimesh.instance_count = 144
	for index in multimesh.instance_count:
		var side := -1.0 if index % 2 == 0 else 1.0
		var row := int(index / 48)
		var slot := int(index / 2) % 24
		var z := -7.15 + float(slot) * 0.47
		var x := side * (6.72 + row * 0.52)
		var y := 0.48 + row * 0.54 + sin(float(index) * 1.73) * 0.06
		multimesh.set_instance_transform(index, Transform3D(Basis(), Vector3(x, y, z)))
	var crowd := MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.multimesh = multimesh
	add_child(crowd)


func _build_lights_and_screen() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("dce8ff")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.shadow_enabled = true
	add_child(key)

	for side in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(side * 4.7, 6.2, -1.0)
		spot.light_color = Color("54c9ff") if side < 0 else Color("dc5cff")
		spot.light_energy = 5.2
		spot.spot_range = 15.0
		spot.spot_angle = 38.0
		spot.shadow_enabled = true
		add_child(spot)
		spot.look_at(Vector3(0, 0.6, -1.3), Vector3.UP)

	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(5.6, 2.3, 0.18)
	_screen_material = _material(Color("101632"), Color("6f57ff"), 0.18, 1.6)
	_add_mesh("ArenaScreen", screen_mesh, Vector3(0, 4.0, -9.05), Vector3.ONE, _screen_material)

	for segment in 24:
		var angle := TAU * float(segment) / 24.0
		var lamp_mesh := SphereMesh.new()
		lamp_mesh.radius = 0.09
		lamp_mesh.height = 0.18
		var lamp_color := Color("51dfff") if segment % 2 == 0 else Color("e85bff")
		_add_mesh(
			"RoofLamp", lamp_mesh,
			Vector3(sin(angle) * 6.0, 6.25, cos(angle) * 7.1 - 1.4),
			Vector3.ONE, _material(lamp_color, lamp_color, 0.1, 3.0)
		)


func _build_lane_markers() -> void:
	for player in 2:
		for lane in 3:
			var marker_mesh := CylinderMesh.new()
			marker_mesh.top_radius = 0.73
			marker_mesh.bottom_radius = 0.73
			marker_mesh.height = 0.018
			marker_mesh.radial_segments = 32
			var color := Color("245f78") if player == 0 else Color("6b275d")
			var material := _material(Color(color, 0.18), color, 0.25, 0.75)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_lane_materials.append(material)
			var point := lane_position(player, lane)
			point.y = 0.035
			_add_mesh("Lane_%d_%d" % [player, lane], marker_mesh, point, Vector3.ONE, material)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "BattleCamera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = 45.0
	camera.near = 0.08
	camera.far = 80.0
	camera.position = Vector3(0.0, 4.78, 9.20)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.15, -1.55), Vector3.UP)
	camera.make_current()


func _material(
	albedo: Color,
	emission: Color,
	roughness: float,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.18
	material.emission_enabled = emission_energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	return material


func _add_mesh(
	node_name: String,
	primitive: PrimitiveMesh,
	world_position: Vector3,
	scale_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = primitive
	instance.position = world_position
	instance.scale = scale_value
	instance.material_override = material
	add_child(instance)
	return instance
