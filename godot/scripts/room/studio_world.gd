extends Node3D
## Original procedural set; every object is an authored primitive composition.

var rain_material: ShaderMaterial
var computer_position := Vector3(0.2, 1.35, -1.95)
var materials: Dictionary = {}


func _ready() -> void:
	materials = {
		"wall": _mat(Color("202e38"), 0.92), "trim": _mat(Color("131e25"), 0.45, 0.6),
		"metal": _mat(Color("293c44"), 0.38, 0.7), "paper": _mat(Color("c1b69e"), 0.95),
		"linen": _mat(Color("657274"), 0.9), "leaf": _mat(Color("355b48"), 0.8),
		"pot": _mat(Color("65514a"), 0.94), "rubber": _mat(Color("10181d"), 0.95),
		"cyan": _mat(Color("4fadb2"), 0.45, 0.0, Color("4fadb2"), 1.5),
		"amber": _mat(Color("e0aa69"), 0.5, 0.0, Color("e0aa69"), 1.8),
	}
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://assets/room/wood.gdshader")
	materials["wood"] = wood
	_build_architecture()
	_build_city()
	_build_desk()
	_build_board()
	_build_shelf()
	_build_plant(Vector3(-3.25, 0, -2.4), 1.0)
	_build_plant(Vector3(2.25, 0.93, -2.1), 0.35)
	_lighting()


func set_reduced_motion(value: bool) -> void:
	if rain_material != null:
		rain_material.set_shader_parameter("still", value)


func _mat(color: Color, roughness: float, metallic := 0.0, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	result.emission_enabled = energy > 0.0
	result.emission = emission
	result.emission_energy_multiplier = energy
	return result


func _box(label: String, size: Vector3, at: Vector3, material: Material, collide := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
	return node


func _cylinder(label: String, radius: float, height: float, at: Vector3, material: Material, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _rod(label: String, start: Vector3, end: Vector3, radius: float, material: Material) -> void:
	var direction := end - start
	var node := _cylinder(label, radius, direction.length(), (start + end) * 0.5, material)
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _build_architecture() -> void:
	_box("OakFloor", Vector3(8, 0.16, 7), Vector3(0, -0.08, 0), materials["wood"], true)
	_box("Ceiling", Vector3(8, 0.12, 7), Vector3(0, 3.52, 0), materials["wall"])
	for x in range(-7, 8):
		_box("FloorJoint", Vector3(0.008, 0.003, 7), Vector3(x * 0.5, 0.006, 0), materials["trim"])
	_box("LeftWall", Vector3(0.18, 3.5, 7), Vector3(-4, 1.75, 0), materials["wall"], true)
	_box("RightWall", Vector3(0.18, 3.5, 7), Vector3(4, 1.75, 0), materials["wall"], true)
	_box("BackWallRight", Vector3(2.5, 3.5, 0.18), Vector3(2.75, 1.75, -3.5), materials["wall"], true)
	_box("BackWallLow", Vector3(5.5, 0.55, 0.18), Vector3(-1.25, 0.275, -3.5), materials["wall"], true)
	_box("BackWallTop", Vector3(5.5, 0.5, 0.18), Vector3(-1.25, 3.25, -3.5), materials["wall"])
	for x in [-3.85, -1.9, 0.0, 1.45]:
		_box("WindowMullion", Vector3(0.07, 2.55, 0.12), Vector3(x, 1.78, -3.43), materials["trim"])
	for y in [0.55, 2.95]:
		_box("WindowFrame", Vector3(5.4, 0.07, 0.25), Vector3(-1.2, y, -3.4), materials["metal"])
	_box("WindowSill", Vector3(5.5, 0.08, 0.42), Vector3(-1.2, 0.55, -3.35), materials["wood"])
	rain_material = ShaderMaterial.new()
	rain_material.shader = preload("res://assets/room/rain.gdshader")
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(5.4, 2.35)
	glass.mesh = quad
	glass.material_override = rain_material
	glass.position = Vector3(-1.2, 1.78, -3.39)
	add_child(glass)
	_box("Rug", Vector3(3.2, 0.015, 2.4), Vector3(0.3, 0.012, 0.3), _mat(Color("293c45"), 1.0))
	for side in [-1, 1]:
		_box("RugBorder", Vector3(0.025, 0.004, 2.3), Vector3(0.3 + side * 1.48, 0.022, 0.3), materials["linen"])


func _build_city() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 93211
	for i in range(23):
		var x := -12.0 + i * 1.05
		var h := random.randf_range(1.5, 8.0)
		var z := random.randf_range(-12.0, -7.0)
		_box("Skyline", Vector3(0.8, h, 0.8), Vector3(x, h * 0.5 - 1.5, z), _mat(Color("172834"), 0.95))
		for level in range(int(h * 2.0)):
			if random.randf() < 0.38:
				continue
			var color := Color("779da2") if random.randf() < 0.7 else Color("b7a17f")
			_box("DistantWindow", Vector3(0.11, 0.15, 0.015), Vector3(x + random.randf_range(-0.25, 0.25), level * 0.42 - 1.0, z + 0.41), _mat(color, 0.9, 0, color, 0.8))


func _build_desk() -> void:
	_box("DeskTop", Vector3(3.6, 0.12, 1.3), Vector3(0, 0.92, -1.95), materials["wood"], true)
	for x in [-1.6, 1.6]:
		for z in [-2.45, -1.45]:
			_box("DeskLeg", Vector3(0.055, 0.88, 0.055), Vector3(x, 0.44, z), materials["metal"])
	_box("MonitorBody", Vector3(1.28, 0.76, 0.065), Vector3(0.15, 1.49, -2.25), materials["trim"])
	_box("MonitorScreen", Vector3(1.17, 0.65, 0.008), Vector3(0.15, 1.49, -2.21), _mat(Color("173848"), 0.5, 0, Color("38788a"), 0.55))
	_box("MonitorStem", Vector3(0.055, 0.26, 0.055), Vector3(0.15, 1.08, -2.25), materials["metal"])
	_box("MonitorFoot", Vector3(0.52, 0.025, 0.25), Vector3(0.15, 0.995, -2.18), materials["metal"])
	for row in range(5):
		_box("ScreenLine", Vector3(0.25 + row * 0.07, 0.009, 0.003), Vector3(-0.23 + row * 0.03, 1.64 - row * 0.055, -2.202), materials["cyan"])
	_box("Keyboard", Vector3(0.85, 0.035, 0.3), Vector3(0.05, 1.0, -1.68), materials["rubber"])
	for row in range(4):
		for col in range(14):
			_box("Key", Vector3(0.042, 0.008, 0.043), Vector3(-0.32 + col * 0.052, 1.022, -1.79 + row * 0.062), materials["metal"])
	_box("DeskMat", Vector3(1.4, 0.008, 0.6), Vector3(0.25, 0.988, -1.7), materials["linen"])
	_box("Mouse", Vector3(0.095, 0.04, 0.15), Vector3(0.75, 1.02, -1.65), materials["rubber"])
	_cylinder("LampBase", 0.18, 0.035, Vector3(-1.25, 1.0, -2.1), materials["metal"])
	_rod("LampArm", Vector3(-1.25, 1.0, -2.1), Vector3(-1.2, 1.75, -2.12), 0.025, materials["metal"])
	_cylinder("LampShade", 0.23, 0.22, Vector3(-1.2, 1.8, -2.12), materials["metal"], 0.12)
	_cylinder("LampDiffuser", 0.205, 0.012, Vector3(-1.2, 1.69, -2.12), materials["amber"])
	_cylinder("Mug", 0.075, 0.15, Vector3(-0.78, 1.065, -1.6), materials["paper"])
	_rod("CableA", Vector3(0.15, 0.9, -2.25), Vector3(0.4, 0.3, -2.6), 0.014, materials["rubber"])
	_rod("CableB", Vector3(0.4, 0.3, -2.6), Vector3(1.6, 0.1, -2.55), 0.014, materials["rubber"])
	_box("ComputerTower", Vector3(0.32, 0.55, 0.5), Vector3(1.5, 0.29, -2.0), materials["trim"])
	_box("PowerIndicator", Vector3(0.012, 0.055, 0.008), Vector3(1.52, 0.45, -1.745), materials["cyan"])
	_box("ChairSeat", Vector3(0.6, 0.12, 0.58), Vector3(0.2, 0.48, -0.7), materials["linen"])
	_box("ChairBack", Vector3(0.6, 0.68, 0.09), Vector3(0.2, 0.86, -0.42), materials["linen"])
	_cylinder("ChairStem", 0.045, 0.42, Vector3(0.2, 0.23, -0.7), materials["metal"])
	for x in [-0.24, 0.24]:
		_rod("ChairFoot", Vector3(0.2, 0.08, -0.7), Vector3(0.2 + x, 0.07, -0.45), 0.025, materials["metal"])


func _build_board() -> void:
	_box("EvidenceFrame", Vector3(1.65, 1.35, 0.075), Vector3(2.65, 1.95, -3.3), materials["wood"])
	_box("EvidenceCork", Vector3(1.54, 1.24, 0.02), Vector3(2.65, 1.95, -3.25), _mat(Color("695b47"), 1.0))
	for i in range(6):
		var note := _box("UnmarkedRecord", Vector3(0.32, 0.4, 0.012), Vector3(2.14 + (i % 3) * 0.49, 2.23 - (i / 3) * 0.52, -3.22), materials["paper"])
		note.rotation.z = (-0.07 if i % 2 == 0 else 0.05)
		_cylinder("Pin", 0.015, 0.012, note.position + Vector3(0, 0.16, 0.017), materials["amber"]).rotation.x = PI * 0.5
	for i in range(3):
		_rod("EvidenceThread", Vector3(2.15 + i * 0.48, 2.13, -3.19), Vector3(2.65, 1.75, -3.19), 0.005, materials["cyan"])


func _build_shelf() -> void:
	for y in [0.18, 0.95, 1.72]:
		_box("Shelf", Vector3(0.7, 0.06, 1.7), Vector3(3.48, y, -1.2), materials["wood"])
	for z in [-1.95, -0.45]:
		_box("ShelfSupport", Vector3(0.055, 1.8, 0.055), Vector3(3.7, 0.9, z), materials["metal"])
	for i in range(7):
		var color: Color = [Color("8f7e63"), Color("435f66"), Color("808884")][i % 3]
		_box("Book", Vector3(0.4, 0.24 + (i % 3) * 0.06, 0.075), Vector3(3.42, 1.11, -1.8 + i * 0.09), _mat(color, 0.95))
	_box("Radio", Vector3(0.45, 0.25, 0.45), Vector3(3.42, 1.87, -1.3), materials["trim"])
	_box("RadioDial", Vector3(0.018, 0.035, 0.22), Vector3(3.18, 1.91, -1.27), materials["amber"])
	for i in range(6):
		_box("RadioGrille", Vector3(0.012, 0.008, 0.18), Vector3(3.18, 1.78 + i * 0.018, -1.27), materials["metal"])


func _build_plant(at: Vector3, scale_value: float) -> void:
	_cylinder("CeramicPot", 0.25 * scale_value, 0.42 * scale_value, at + Vector3.UP * 0.21 * scale_value, materials["pot"], 0.31 * scale_value)
	for i in range(9):
		var angle := i * TAU / 9.0
		var tip := at + Vector3(cos(angle) * 0.46, 0.8 + (i % 3) * 0.15, sin(angle) * 0.46) * scale_value
		_rod("PlantStem", at + Vector3.UP * 0.35 * scale_value, tip, 0.009 * scale_value, materials["leaf"])
		var leaf := _box("Leaf", Vector3(0.13, 0.025, 0.36) * scale_value, tip, materials["leaf"])
		leaf.rotation = Vector3(0.45, -angle, 0.28)


func _lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070e17")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91a8bd")
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("182b3c")
	environment.fog_density = 0.025
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, -30, 0)
	moon.light_color = Color("7eabc7")
	moon.light_energy = 0.2
	moon.shadow_enabled = true
	add_child(moon)
	var desk_light := OmniLight3D.new()
	desk_light.position = Vector3(-1.2, 1.62, -2.1)
	desk_light.light_color = Color("ffca8d")
	desk_light.light_energy = 3.0
	desk_light.omni_range = 3.7
	desk_light.shadow_enabled = true
	add_child(desk_light)
	var window_fill := OmniLight3D.new()
	window_fill.position = Vector3(-1.5, 2.0, -2.8)
	window_fill.light_color = Color("688da9")
	window_fill.light_energy = 0.65
	window_fill.omni_range = 5.0
	add_child(window_fill)
	var monitor := OmniLight3D.new()
	monitor.position = Vector3(0.15, 1.5, -1.95)
	monitor.light_color = Color("71c5d0")
	monitor.light_energy = 0.42
	monitor.omni_range = 2.8
	add_child(monitor)
