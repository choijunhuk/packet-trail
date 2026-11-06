extends "res://tests/headless/test_desktop_shell.gd"

const FullScene = preload("res://scenes/full_game.tscn")
const Habitat = preload("res://scripts/core/habitat_store.gd")


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	tree = scene_tree
	var protected := _fingerprints()
	var habitat_files := _habitat_fingerprints()
	test_root = "user://tests/habitat_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(test_root)
	var full := FullScene.instantiate()
	full.save_slot_path = test_root + "/campaign.json"
	tree.root.add_child(full)
	await tree.process_frame
	await tree.process_frame
	var room = full.room
	_check(room.habitat_path.begins_with(test_root + "/"), "full game derives an isolated household path")
	_check(not FileAccess.file_exists(room.habitat_path), "loading a missing household save does not create a file")
	room.open_desktop("new", "intruder", "independent")
	var main: Control = room.desktop
	var main_world: Dictionary = main.game.export_snapshot()
	var balance: int = room.habitat_view().balance
	main._open_deskshop()
	_check(room.habitat_panel != null and main._room_settings_open(), "desktop launcher opens a modal local desk store")
	_check(room.habitat_panel.content.find_children("*", "Button", true, false).size() >= 8, "all eight authored products have an ownership/order action")
	var f10 := InputEventKey.new()
	f10.keycode = KEY_F10
	f10.pressed = true
	room._input(f10)
	_check(room._in_desktop, "F10 cannot leave the computer while a room panel protects focus")
	var original_visual: String = room.studio._equipment_signature
	var buy := _product_button(room.habitat_panel, "keyboard_ivory")
	_check(buy != null and not buy.disabled, "an affordable keyboard can be ordered")
	buy.pressed.emit()
	_check(room.habitat_view().balance == balance - Habitat.CATALOG.keyboard_ivory.price and room.habitat_view().ready_delivery_count == 1, "order deducts the catalog price only after it is persisted")
	_check(not room.habitat_view().owned.has("keyboard_ivory") and room.studio._equipment_signature == original_visual, "pending orders cannot equip or change the real desk")
	room._close_habitat_panel()
	room.return_to_room()
	room._change_zone("courtyard")
	_check(room.current_zone == "courtyard" and room.camera.global_position.is_equal_approx(room.studio.get_zone_spawn("courtyard").origin), "door travel uses the global camera-eye spawn without a doubled camera offset")
	var courtyard_pose: Transform3D = room.player.global_transform
	room.show_main_menu()
	room.return_to_room()
	_check(room.current_zone == "courtyard" and room.player.global_transform.is_equal_approx(courtyard_pose), "menu round trip preserves zone and player pose")
	room.show_habitat("delivery_locker")
	room.habitat_panel.controls.collect_delivery.pressed.emit()
	_check(room.habitat_view().owned.has("keyboard_ivory") and room.habitat_view().ready_delivery_count == 0, "locker pickup changes ready orders into owned items")
	room._close_habitat_panel()
	room.show_habitat("shop")
	_product_button(room.habitat_panel, "keyboard_ivory").pressed.emit()
	_check(room.habitat_view().equipped.keyboard == "keyboard_ivory" and room.studio._equipment_signature != original_visual, "equipping an owned item changes the actual 3D equipment")
	room._close_habitat_panel()
	var before_io: Dictionary = room.habitat_store.export_snapshot()
	var visual_before_io: String = room.studio._equipment_signature
	DirAccess.make_dir_absolute(room.habitat_path + ".tmp")
	room.show_habitat("shop")
	_product_button(room.habitat_panel, "lamp_cool").pressed.emit()
	_check(room.habitat_store.export_snapshot() == before_io and room.studio._equipment_signature == visual_before_io, "failed IO cannot optimistically change wallet, ownership or desk meshes")
	_check(not room.habitat_panel.feedback.text.is_empty(), "failed order is visibly explained")
	room._close_habitat_panel()
	DirAccess.remove_absolute(room.habitat_path + ".tmp")
	room.show_habitat("noticeboard")
	room.habitat_panel.controls.accept_job.pressed.emit()
	_check(room.habitat_view().job.accepted, "optional outdoor job is accepted at the noticeboard")
	room._close_habitat_panel()
	room.show_habitat("network_cabinet")
	room.habitat_panel.controls.inspect_cabinet.pressed.emit()
	_check(room.habitat_view().job.inspected, "cabinet must be inspected before changing its configuration")
	_configure(room.habitat_panel, "off", true)
	room.habitat_panel.controls.verify_job.pressed.emit()
	_check(not room.habitat_view().job.current_check.normal_telemetry and not room.habitat_view().job.rewarded, "turning everything off fails normal work and earns no reward")
	_configure(room.habitat_panel, "service", true)
	var pre_reward: int = room.habitat_view().balance
	room.habitat_panel.controls.verify_job.pressed.emit()
	_check(room.habitat_view().job.current_check.normal_telemetry and not room.habitat_view().job.current_check.unauthorized_access and room.habitat_view().job.current_check.passed, "actual cabinet settings preserve telemetry and deny unauthorized access")
	_check(room.habitat_view().balance == pre_reward + Habitat.JOB_REWARD, "successful optional job credits the authored one-time reward")
	room.habitat_panel.controls.verify_job.pressed.emit()
	_check(room.habitat_view().balance == pre_reward + Habitat.JOB_REWARD, "repeated verification cannot farm room credits")
	room._close_habitat_panel()
	room.show_habitat("bench")
	room.habitat_panel.controls.set_lighting.pressed.emit()
	_check(room.habitat_view().lighting == "dawn", "optional bench rest changes and saves atmosphere without gameplay stats")
	room._close_habitat_panel()
	room._change_zone("room")
	room.open_desktop("continue", "intruder")
	_check(room.desktop == main and main.game.export_snapshot() == main_world, "all shopping, outdoor work and decorating leave the main campaign untouched")
	var reload = Habitat.new(room.habitat_path)
	_check(reload.load_state().ok and reload.export_snapshot() == room.habitat_store.export_snapshot(), "persisted decoration, wallet and job receipts reload exactly")
	var backup_before_corruption := FileAccess.get_file_as_bytes(room.habitat_path + ".bak")
	var damaged := "preserve-mid-session-corruption"
	var damaged_file := FileAccess.open(room.habitat_path, FileAccess.WRITE)
	damaged_file.store_string(damaged)
	damaged_file.close()
	main._open_deskshop()
	_product_button(room.habitat_panel, "lamp_cool").pressed.emit()
	_check(not room.habitat_view().ready and room.habitat_view().get("recovery_available", false), "same-session corruption changes the live room panel into recoverable read-only state")
	_check(_product_button(room.habitat_panel, "keyboard_coral").disabled and FileAccess.get_file_as_string(room.habitat_path) == damaged and FileAccess.get_file_as_bytes(room.habitat_path + ".bak") == backup_before_corruption, "recovery-required panel disables purchases and preserves both damaged original and good backup")
	var recover_button: Button = null
	for button in room.habitat_panel.content.find_children("*", "Button", true, false):
		if not button.has_meta("product_id"): recover_button = button
	_check(recover_button != null and not recover_button.disabled, "recovery button becomes enabled immediately without restarting the room")
	if recover_button != null:
		recover_button.pressed.emit()
		_check(room.habitat_panel.recovery.visible, "recoverable mid-session error opens the actual confirmation dialog")
		room.habitat_panel.recovery.confirmed.emit()
		_check(room.habitat_view().ready and not room.habitat_view().get("recovery_available", true), "explicit UI recovery restores writable state and clears its recovery flag")
	room._close_habitat_panel()
	await _free_full(full)
	var corrupt_path := test_root + "/corrupt_habitat.json"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("preserve-corrupt-original")
	file.close()
	var corrupt_before := FileAccess.get_file_as_bytes(corrupt_path)
	var readonly := FullScene.instantiate()
	readonly.save_slot_path = test_root + "/readonly.json"
	tree.root.add_child(readonly)
	await tree.process_frame
	await tree.process_frame
	# Reconfigure only this owned test path, then use the real panel's read-only state.
	readonly.room.habitat_store = Habitat.new(corrupt_path)
	readonly.room.habitat_load_result = readonly.room.habitat_store.load_state()
	readonly.room.return_to_room()
	readonly.room.show_habitat("shop")
	_check(not readonly.room.habitat_view().ready and _product_button(readonly.room.habitat_panel, "keyboard_coral").disabled, "corrupt household data is read-only instead of silently reset")
	_check(FileAccess.get_file_as_bytes(corrupt_path) == corrupt_before, "opening a corrupt save preserves the original bytes")
	await _free_full(readonly)
	_check(_fingerprints() == protected and _habitat_fingerprints() == habitat_files, "all real campaign, preferences and household files remain unchanged")
	_remove_owned(test_root)
	return {"suite": "habitat_ui", "checks": checks, "failures": failures.duplicate(), "limit": "Actual scenes, UI signals and isolated disk; native input and visible 3D effects use separate rendered tests."}


func _product_button(panel: Control, id: String) -> Button:
	for button in panel.content.find_children("*", "Button", true, false):
		if button.get_meta("product_id", "") == id: return button
	return null


func _configure(panel: Control, route: String, locked: bool) -> void:
	for index in panel.controls.route.item_count:
		if panel.controls.route.get_item_metadata(index) == route: panel.controls.route.select(index)
	panel.controls.locked.button_pressed = locked
	panel.controls.configure.pressed.emit()


func _habitat_fingerprints() -> Dictionary:
	var result := {}
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = Habitat.PATH + suffix
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result


func _free_full(full: Node) -> void:
	full.process_mode = Node.PROCESS_MODE_DISABLED
	var players: Array[Node] = full.audio.find_children("*", "AudioStreamPlayer", true, false)
	for player in players: player.stop()
	for index in range(3): await tree.process_frame
	for player in players: player.stream = null
	await tree.create_timer(0.15).timeout
	full.queue_free()
	await tree.process_frame
	await tree.process_frame
