extends RefCounted
const Studio = preload("res://scripts/room/studio_world.gd")
var checks := 0
var failures: Array[String] = []

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run(tree: SceneTree) -> Dictionary:
	var world := Studio.new()
	tree.root.add_child(world)
	await tree.process_frame
	_check(world.get_node_or_null("Neighborhood") != null, "actual courtyard exists")
	for zone in ["room", "courtyard"]:
		var spawn: Transform3D = world.get_zone_spawn(zone)
		_check(is_equal_approx(world.to_local(spawn.origin).y, 1.63), "spawn is camera eye height " + zone)
		var still: Vector3 = world.move_in_zone(spawn.origin, Vector3.ZERO, zone)
		_check(still.is_equal_approx(spawn.origin), "spawn is inside walkable zone " + zone)
		var end: Vector3 = world.move_in_zone(spawn.origin, Vector3(50, 0, 50), zone)
		var local: Vector3 = world.to_local(end)
		_check(world.zone_bounds(zone).has_point(Vector2(local.x - 0.001, local.z - 0.001)), "large movement stays bounded " + zone)
		_check(is_equal_approx(local.y, 1.63), "movement preserves eye height " + zone)
	var start := Vector3(0, 1.63, 0)
	var blocked: Vector3 = world.move_in_zone(start, Vector3(0, 0, -8), "room")
	_check(blocked.z > -0.2, "large movement cannot tunnel through chair and desk")
	var slide: Vector3 = world.move_in_zone(Vector3(1.0, 1.63, -0.7), Vector3(0.8, 0, -1.0), "room")
	_check(slide.x > 1.7 and slide.z > -1.0, "diagonal movement slides along desk front")
	var cabinet := Vector3(4.3, 1.2, 15.0)
	var viewer := Vector3(4.3, 1.63, 16.5)
	_check(world.interaction_at(viewer, cabinet - viewer, "courtyard").get("id") == "network_cabinet", "cabinet reachable when facing it")
	_check(world.interaction_at(viewer, viewer - cabinet, "courtyard").is_empty(), "looking away does not interact")
	_check(world.interaction_at(Vector3(4.3, 1.63, 20), Vector3.FORWARD, "courtyard").is_empty(), "cabinet cannot activate remotely")
	_check(world.interaction_at(viewer, cabinet - viewer, "room").is_empty(), "another zone cannot borrow interaction")
	var approaches := [
		{"id": "computer", "zone": "room", "viewer": Vector3(0, 1.63, 0), "target": world.computer_position},
		{"id": "room_exit", "zone": "room", "viewer": Vector3(2.5, 1.63, 1.88), "target": Vector3(3.6, 1.45, 1.88)},
		{"id": "courtyard_enter", "zone": "courtyard", "viewer": Vector3(0, 1.63, 21.2), "target": Vector3(0, 1.45, 22.5)},
		{"id": "delivery_locker", "zone": "courtyard", "viewer": Vector3(-3.5, 1.63, 15.9), "target": Vector3(-4.35, 1.25, 15.9)},
		{"id": "noticeboard", "zone": "courtyard", "viewer": Vector3(0, 1.63, 14.8), "target": Vector3(0, 1.55, 13.45)},
		{"id": "network_cabinet", "zone": "courtyard", "viewer": Vector3(4.3, 1.63, 16.5), "target": Vector3(4.3, 1.2, 15)},
		{"id": "bench", "zone": "courtyard", "viewer": Vector3(3.6, 1.63, 20.8), "target": Vector3(3.6, 1, 19.45)}]
	for approach in approaches:
		_check(world.interaction_at(approach.viewer, approach.target - approach.viewer, approach.zone).get("id") == approach.id, "authored interaction is reachable: " + str(approach.id))
		var local_obstacles: Array = []
		if approach.zone == "room": local_obstacles.assign(Studio.ROOM_OBSTACLES)
		else:
			for rect in world.Neighborhood.OBSTACLES: local_obstacles.append(Rect2(rect.position + Vector2(0, 18), rect.size))
		_check(not world._blocked(Vector2(approach.viewer.x, approach.viewer.z), local_obstacles), "interaction approach is outside collision: " + str(approach.id))
	world.apply_habitat({"equipped": {"keyboard": "keyboard_ivory", "monitor": "monitor_dual", "lamp": "lamp_cool"}, "lighting": "dawn", "ready_delivery_count": 1, "job": {"route": "approved_relay", "locked": true}})
	var equipment: Node = world.get_node("DeskEquipment")
	var monitors := 0
	for child in equipment.get_children():
		if str(child.name).begins_with("MonitorScreen") or (child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(0.81, 0.65, 0.008))): monitors += 1
	_check(monitors == 2, "dual monitor changes actual screen geometry")
	var keyboard: MeshInstance3D = equipment.get_node("KeyboardBody")
	_check(keyboard.material_override.albedo_color.is_equal_approx(Color("e4d9bd")), "ivory keyboard changes actual material")
	_check(world._desk_light.light_color.is_equal_approx(Color("a5d4ff")), "cool lamp changes actual light")
	_check(world._environment.ambient_light_energy > 0.5, "dawn changes actual environment")
	var count := world.get_child_count()
	world.apply_habitat({"equipped": {"keyboard": "keyboard_ivory", "monitor": "monitor_dual", "lamp": "lamp_cool"}})
	_check(world.get_child_count() == count, "repeated visual application does not accumulate geometry")
	world.position = Vector3(17, 2, -11)
	world.rotation.y = 0.4
	var moved_spawn: Transform3D = world.get_zone_spawn("room")
	_check(world.to_local(moved_spawn.origin).is_equal_approx(Vector3(0, 1.63, 0.25)), "spawn supports transformed studio")
	var moved: Vector3 = world.move_in_zone(moved_spawn.origin, world.global_basis * Vector3(0.3, 0, 0), "room")
	_check(world.to_local(moved).is_equal_approx(Vector3(0.3, 1.63, 0.25)), "movement accepts global delta with transformed studio")
	var local_camera := Vector3(2.2, 1.63, 1.88)
	var local_target := Vector3(3.6, 1.45, 1.88)
	var target: Dictionary = world.interaction_at(world.to_global(local_camera), world.global_basis * (local_target - local_camera), "room")
	_check(target.get("id") == "room_exit" and target.get("position", Vector3.ZERO).is_equal_approx(world.to_global(local_target)), "interaction uses global positions in transformed studio")
	world.queue_free()
	await tree.process_frame
	return {"suite": "neighborhood", "checks": checks, "failures": failures}
