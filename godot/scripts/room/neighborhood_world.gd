extends Node3D
## Authored compact courtyard; all interactions are routed by Room to the habitat model.

const OBSTACLES := [Rect2(-5.5, -3.4, 1.1, 2.3), Rect2(3.65, -3.9, 1.7, 1.1), Rect2(2.4, 1.1, 2.7, 0.8), Rect2(-4.1, 1.3, 1.1, 1.1)]
const INTERACTIONS := [
	{"id": "courtyard_enter", "label_key": "HAB_INTERACT_ENTER", "position": Vector3(0, 1.45, 4.5)},
	{"id": "delivery_locker", "label_key": "HAB_INTERACT_PICKUP", "position": Vector3(-4.35, 1.25, -2.1)},
	{"id": "noticeboard", "label_key": "HAB_INTERACT_NOTICEBOARD", "position": Vector3(0.0, 1.55, -4.55)},
	{"id": "network_cabinet", "label_key": "HAB_INTERACT_CABINET", "position": Vector3(4.3, 1.2, -3.0)},
	{"id": "bench", "label_key": "HAB_INTERACT_REST", "position": Vector3(3.6, 1.0, 1.45)}]
var _delivery_indicator: MeshInstance3D
var _cabinet_indicator: MeshInstance3D
var _cabinet_latch: MeshInstance3D
var _cabinet_route: MeshInstance3D

func _ready() -> void:
	var stone := _material(Color("41494c"))
	var plaster := _material(Color("777b73"))
	var trim := _material(Color("222c30"))
	var copper := _material(Color("b27652"))
	var wood := _material(Color("66513f"))
	_box("CourtyardGround", Vector3(12, 0.2, 10), Vector3(0, -0.1, 0), stone)
	for index in range(-5, 6):
		_box("PavingJoint", Vector3(0.015, 0.005, 10), Vector3(index, 0.006, 0), trim)
	for side in [-1, 1]:
		_box("CourtyardSide", Vector3(0.25, 3.5, 10), Vector3(side * 6, 1.75, 0), plaster)
		for index in range(4):
			_box("ApartmentWindow", Vector3(0.025, 0.9, 0.9), Vector3(side * 5.86, 2.25, -3.6 + index * 2.0), _material(Color("c5ac77"), 0.55))
	_box("StreetBoundary", Vector3(12, 1.0, 0.2), Vector3(0, 0.5, -5), plaster)
	_box("EntryWallLeft", Vector3(4.7, 3.5, 0.25), Vector3(-3.65, 1.75, 5), plaster)
	_box("EntryWallRight", Vector3(4.7, 3.5, 0.25), Vector3(3.65, 1.75, 5), plaster)
	_box("EntryDoor", Vector3(1.6, 2.7, 0.12), Vector3(0, 1.35, 4.85), _material(Color("405a54")))
	_box("EntryLamp", Vector3(0.45, 0.12, 0.2), Vector3(0, 2.95, 4.65), _material(Color("efc88e"), 1.8))
	_box("DeliveryLocker", Vector3(1.0, 1.8, 2.0), Vector3(-5.0, 0.9, -2.25), trim)
	for index in range(3):
		_box("LockerDoor", Vector3(0.025, 0.5, 1.75), Vector3(-4.48, 0.33 + index * 0.56, -2.25), _material(Color("8e6f51")))
		_box("LockerPull", Vector3(0.04, 0.04, 0.2), Vector3(-4.44, 0.33 + index * 0.56, -1.8), copper)
	_delivery_indicator = _box("DeliveryReady", Vector3(0.04, 0.09, 0.11), Vector3(-4.43, 1.68, -2.25), trim)
	_box("NoticeBoardFrame", Vector3(2.5, 1.5, 0.18), Vector3(0, 1.7, -4.72), wood)
	_box("NoticeBoardBacking", Vector3(2.3, 1.3, 0.04), Vector3(0, 1.7, -4.61), _material(Color("75664c")))
	for index in range(3):
		_box("MaintenanceNotice", Vector3(0.59, 0.87, 0.015), Vector3(-0.77 + index * 0.77, 1.7, -4.57), _material(Color("e4d8b9")))
		_box("NoticeHeader", Vector3(0.42, 0.055, 0.008), Vector3(-0.77 + index * 0.77, 2.02, -4.55), copper)
	_box("ServiceCabinet", Vector3(1.5, 1.9, 0.85), Vector3(4.45, 0.95, -3.65), trim)
	_box("CabinetInset", Vector3(1.29, 1.65, 0.025), Vector3(4.45, 0.98, -3.2), _material(Color("536166")))
	for index in range(3):
		_box("ServiceModule", Vector3(0.88, 0.2, 0.035), Vector3(4.3, 1.48 - index * 0.34, -3.17), trim)
	_cabinet_indicator = _box("TelemetryIndicator", Vector3(0.08, 0.08, 0.02), Vector3(4.86, 1.47, -3.14), trim)
	_cabinet_latch = _box("CabinetLatch", Vector3(0.08, 0.3, 0.07), Vector3(5.02, 0.95, -3.14), copper)
	_cabinet_route = _box("RouteCable", Vector3(0.035, 0.66, 0.035), Vector3(3.85, 0.95, -3.13), copper)
	for index in range(3):
		_box("BenchSlat", Vector3(2.4, 0.065, 0.17), Vector3(3.65, 0.52, 1.28 + index * 0.2), wood)
	for x in [2.65, 4.65]:
		_box("BenchLeg", Vector3(0.08, 0.5, 0.65), Vector3(x, 0.25, 1.48), trim)
	_box("Planter", Vector3(0.9, 0.6, 0.9), Vector3(-3.6, 0.3, 1.8), _material(Color("735949")))
	for index in range(5):
		var leaf := _box("PlanterLeaf", Vector3(0.17, 0.7, 0.45), Vector3(-3.6 + sin(index) * 0.25, 0.85, 1.8 + cos(index) * 0.2), _material(Color("466a4f")))
		leaf.rotation.y = float(index)
	var light := OmniLight3D.new()
	light.position = Vector3(-1.0, 3.1, 1.0)
	light.light_color = Color("ffd4a0")
	light.light_energy = 2.0
	light.omni_range = 9.0
	add_child(light)
	apply_habitat({})

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.emission_enabled = emission > 0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material

func _box(label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node

func apply_habitat(view: Dictionary) -> void:
	if _delivery_indicator == null: return
	_delivery_indicator.material_override = _material(Color("f3c873") if int(view.get("ready_delivery_count", 0)) > 0 else Color("46555b"), 1.0)
	var job: Dictionary = view.get("job", {})
	var route := str(job.get("route", "public"))
	var available := route in ["service", "approved_relay", "public"]
	_cabinet_indicator.material_override = _material(Color("8fd1b6") if available else Color("46555b"), 1.0)
	_cabinet_latch.rotation.z = 0.0 if bool(job.get("locked", false)) else -0.55
	_cabinet_route.material_override = _material(Color("dd987a") if route == "public" else (Color("bda6e0") if route == "approved_relay" else Color("82bfc6")), 0.3)
	_cabinet_route.visible = route != "off"
