extends "res://tests/headless/test_desktop_shell.gd"

const FullScene = preload("res://scenes/full_game.tscn")
const HabitatPanel = preload("res://scripts/presentation/habitat_panel.gd")
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
	await _panel_regressions(room.habitat_view())
	await _confirmation_geometry(room.habitat_view())
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
	var applied_before: Dictionary = room.habitat_store.export_snapshot()
	var saved_before := FileAccess.get_file_as_bytes(room.habitat_path)
	room.habitat_panel.controls.route.select(1)
	room.habitat_panel.controls.route.item_selected.emit(1)
	room.habitat_panel.controls.locked.button_pressed = true
	_check(room.habitat_panel.controls.verify_job.disabled, "the real room blocks checking unapplied cabinet selections")
	_check(room.habitat_store.export_snapshot() == applied_before and FileAccess.get_file_as_bytes(room.habitat_path) == saved_before, "draft selection changes neither household memory nor saved bytes")
	_configure(room.habitat_panel, "off", true)
	_check(not room.habitat_panel.controls.verify_job.disabled and not room.habitat_panel.controls.unapplied_changes.visible, "applying a cabinet draft clears the pending marker and enables checking")
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
	var recover_button: Button = room.habitat_panel.controls.get("recover")
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
	var fresh_button: Button = readonly.room.habitat_panel.controls.get("fresh")
	_check(fresh_button != null and not fresh_button.disabled, "a corrupt household without a backup offers explicit fresh recovery")
	if fresh_button != null:
		fresh_button.pressed.emit()
		var fresh_dialog: ConfirmationDialog = readonly.room.habitat_panel.get("fresh")
		_check(fresh_dialog != null and fresh_dialog.visible, "fresh household recovery opens a separate confirmation")
		if fresh_dialog != null:
			fresh_dialog.canceled.emit()
			fresh_dialog.hide()
			_check(FileAccess.get_file_as_bytes(corrupt_path) == corrupt_before and not readonly.room.habitat_view().ready, "canceling fresh recovery leaves corrupt bytes and household state unchanged")
			fresh_button.pressed.emit()
			fresh_dialog.confirmed.emit()
			_check(readonly.room.habitat_view().ready and readonly.room.habitat_view().balance == Habitat.STARTING_CREDITS, "confirmed fresh household recovery restores playable defaults")
			_check(_has_preserved_corruption(corrupt_path, corrupt_before), "fresh household recovery preserves the damaged original separately")
	await _free_full(readonly)
	_check(_fingerprints() == protected and _habitat_fingerprints() == habitat_files, "all real campaign, preferences and household files remain unchanged")
	_remove_owned(test_root)
	return {"suite": "habitat_ui", "checks": checks, "failures": failures.duplicate(), "limit": "Actual scenes, UI signals and isolated disk; native input and visible 3D effects use separate rendered tests."}


func _panel_regressions(base_view: Dictionary) -> void:
	var panel := HabitatPanel.new()
	tree.root.add_child(panel)
	var view := base_view.duplicate(true)
	view.job.accepted = true
	view.job.inspected = true
	panel.setup(view, "network_cabinet")
	await tree.process_frame
	await tree.process_frame
	var focused := tree.root.gui_get_focus_owner()
	_check(focused != null and panel.is_ancestor_of(focused), "opening a habitat modal places keyboard focus inside it")
	_check(not panel.controls.verify_job.disabled, "applied inspected cabinet settings can be verified")
	var raw_tooltip := false
	for index in panel.controls.route.item_count:
		if not panel.controls.route.get_item_tooltip(index).is_empty(): raw_tooltip = true
	_check(not raw_tooltip, "localized route choices do not expose raw internal IDs as tooltips")
	panel.controls.route.grab_focus()
	panel.controls.route.select(1)
	panel.controls.route.item_selected.emit(1)
	_check(panel.controls.verify_job.disabled, "changing a route disables verification until the draft is applied")
	var pending: Label = panel.controls.get("unapplied_changes")
	_check(pending != null and pending.visible, "an edited cabinet visibly reports unapplied changes")
	panel.controls.route.select(0)
	panel.controls.route.item_selected.emit(0)
	_check(not panel.controls.verify_job.disabled and (pending == null or not pending.visible), "returning draft controls to applied values restores verification")
	panel.controls.locked.button_pressed = true
	_check(panel.controls.verify_job.disabled, "changing the lock alone also disables verification")
	panel.render(view)
	await tree.process_frame
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	_check(focused == panel.controls.route, "cabinet render restores focus to the same semantic control")
	panel.queue_free()
	await tree.process_frame
	panel = HabitatPanel.new()
	tree.root.add_child(panel)
	panel.setup(view, "shop", 1.6)
	await tree.process_frame
	await tree.process_frame
	var button := _product_button(panel, "lamp_cool")
	button.grab_focus()
	await tree.process_frame
	var scroll: ScrollContainer = panel.content.get_parent()
	var scroll_before := scroll.scroll_vertical
	view.owned.append("lamp_cool")
	panel.render(view)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	_check(focused == _product_button(panel, "lamp_cool") and not focused.disabled, "order to equip render keeps focus on the same product")
	_check(scroll.scroll_vertical == scroll_before, "shop refresh preserves the current scroll position")
	view.equipped.lamp = "lamp_cool"
	panel.render(view)
	await tree.process_frame
	await tree.process_frame
	focused = tree.root.gui_get_focus_owner()
	_check(focused != null and panel.is_ancestor_of(focused) and not focused.disabled, "disabled product action falls back to an enabled modal control")
	panel.queue_free()
	await tree.process_frame
	panel = HabitatPanel.new()
	tree.root.add_child(panel)
	panel.setup(view, "bench")
	var night: Button = panel.controls.get("set_lighting_night")
	var dawn: Button = panel.controls.get("set_lighting_dawn")
	_check(night != null and dawn != null and night.disabled and not dawn.disabled, "bench exposes both lighting choices and disables the current night setting")
	view.lighting = "dawn"
	panel.render(view)
	night = panel.controls.get("set_lighting_night")
	dawn = panel.controls.get("set_lighting_dawn")
	_check(night != null and dawn != null and not night.disabled and dawn.disabled, "bench disables the current dawn setting after refresh")
	panel.queue_free()
	await tree.process_frame


func _confirmation_geometry(base_view: Dictionary) -> void:
	var previous_size := tree.root.size
	var previous_locale := PacketLocalization.get_locale()
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var physical_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var viewport_to_screen := tree.root.get_final_transform()
	_check(physical_rect.size == Vector2(1280, 720), "confirmation geometry fixture uses an actual 1280 by 720 root window with production viewport scaling")
	for language in ["ko", "de"]:
		PacketLocalization.set_locale(language)
		var panel := HabitatPanel.new()
		tree.root.add_child(panel)
		var view := base_view.duplicate(true)
		view.ready = false
		view.recovery_available = true
		view.fresh_available = true
		panel.setup(view, "shop", 1.6)
		for control_key in ["recover", "fresh"]:
			panel.controls[control_key].pressed.emit()
			await tree.process_frame
			await tree.process_frame
			var dialog: ConfirmationDialog = panel.recovery if control_key == "recover" else panel.fresh
			var prefix: String = language + " 1.6 " + control_key
			_check(physical_rect.encloses(viewport_to_screen * Rect2(Vector2(dialog.position), Vector2(dialog.size))), prefix + " confirmation fits within the actual viewport")
			for button in [dialog.get_cancel_button(), dialog.get_ok_button()]:
				var button_rect: Rect2 = button.get_global_rect()
				button_rect.position += Vector2(dialog.position)
				_check(physical_rect.encloses(viewport_to_screen * button_rect), prefix + " confirmation button remains fully inside the viewport: " + button.text)
			dialog.hide()
		panel.queue_free()
		await tree.process_frame
	PacketLocalization.set_locale(previous_locale)
	tree.root.size = previous_size
	await tree.process_frame


func _product_button(panel: Control, id: String) -> Button:
	for button in panel.content.find_children("*", "Button", true, false):
		if button.get_meta("product_id", "") == id: return button
	return null


func _configure(panel: Control, route: String, locked: bool) -> void:
	for index in panel.controls.route.item_count:
		if panel.controls.route.get_item_metadata(index) == route: panel.controls.route.select(index)
	panel.controls.locked.button_pressed = locked
	panel.controls.configure.pressed.emit()


func _has_preserved_corruption(path: String, before: PackedByteArray) -> bool:
	for file_name in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(path.get_file().trim_suffix(".json") + ".damaged_"):
			if FileAccess.get_file_as_bytes(path.get_base_dir().path_join(file_name)) == before: return true
	return false


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
