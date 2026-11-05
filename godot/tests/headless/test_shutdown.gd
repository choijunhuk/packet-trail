extends RefCounted
## Runs inside its own externally timed Godot process. The product performs the actual quit.

var checks := 0
var failures: Array[String] = []
var _tree: SceneTree
var _before: Dictionary = {}
var _mode := "menu"


func run(tree: SceneTree, mode := "menu") -> void:
	_tree = tree
	_mode = mode
	_before = _fingerprints()
	_check(mode in ["menu", "window"], "known shutdown route")
	var scene = load("res://scenes/full_game.tscn") as PackedScene
	_check(scene != null, "actual product main scene loads")
	if scene == null:
		_report("setup_failed")
		_tree.quit(1)
		return
	var full: Node = scene.instantiate()
	full.set("save_slot_path", "user://tests/shutdown_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	_tree.root.add_child(full)
	for index in range(8):
		await _tree.process_frame
	await _tree.create_timer(0.25).timeout
	var room: Node = full.get("room")
	_check(room != null, "actual room is ready")
	var players := full.find_children("*", "AudioStreamPlayer", true, false)
	var playing := 0
	for player in players:
		if player.playing:
			playing += 1
	_check(playing >= 2, "real music and ambience are playing before quit")
	if mode == "window":
		_check(not _tree.auto_accept_quit, "product routes WM close instead of implicit engine quit")
		_report("window_close_requested")
		# Official WM notification route; two requests exercise the production duplicate guard.
		_tree.root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_tree.root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	var button: Button
	for child in room.get("menu_box").get_children():
		if child is Button and child.text == room.call("_text", "QUIT"):
			button = child
			break
	_check(button != null and button.is_visible_in_tree(), "actual menu Quit button is reachable")
	if button == null:
		_report("setup_failed")
		_tree.quit(1)
		return
	button.grab_focus()
	await _tree.process_frame
	_check(_tree.root.gui_get_focus_owner() == button, "actual menu Quit owns keyboard focus")
	button.pressed.connect(func():
		_check(true, "actual menu button activated by engine keyboard input")
		_report("menu_quit_activated"))
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		_tree.root.push_input(key, true)
		await _tree.process_frame


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _report(stage: String) -> void:
	_check(_fingerprints() == _before, "default settings and saves/backups unchanged before product exit")
	print(JSON.stringify({"suite": "shutdown", "checks": checks, "failures": failures,
		"mode": _mode, "stage": stage, "protected_paths": _before.size(),
		"renderer": DisplayServer.get_name(), "user_data_dir": OS.get_user_data_dir(),
		"limit": "Dedicated source-engine process and real product scene. Menu uses injected engine keyboard input; window propagates the standard WM close notification twice. External wrapper must verify deadline, actual process exit and all teardown logs. No forced-CLI or physical OS acceptance claim."}))


func _fingerprints() -> Dictionary:
	var result := {}
	var paths: Array[String] = ["user://settings.json", "user://saves/campaign_01.json", "user://saves/slot_01.json",
		"user://saves/intruder_v2_01.json", "user://saves/defender_01.json", "user://saves/tracker_01.json", "user://saves/legacy_continue_01.json"]
	for path in paths:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var full: String = path + suffix
			result[full] = FileAccess.get_sha256(full) if FileAccess.file_exists(full) else "MISSING"
	var directory := DirAccess.open("user://saves")
	if directory != null:
		for filename in directory.get_files():
			result["user://saves/" + filename] = "SYMLINK" if directory.is_link(filename) else FileAccess.get_sha256("user://saves/" + filename)
	return result
