extends SceneTree
## Own-scope smoke/visual helper; not part of the exported game.

const Store = preload("res://scripts/presentation/settings_store.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")
	create_timer(15.0).timeout.connect(func():
		print(JSON.stringify({"suite": "room_settings", "checks": checks, "failures": ["room helper timed out"]}))
		quit(1))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _run() -> void:
	var store := Store.new()
	_check(store.validate_values(Store.DEFAULTS)["ok"], "default settings validate")
	for bad in [{"master_volume": -0.1}, {"font_scale": "1"}, {"locale": "unsupported"}, {"fullscreen": 1}, {"mouse_sensitivity": INF}, {"unknown": true}, {"keyboard_volume": 1.01}, {"tool_volume": -0.1}, {"notification_volume": NAN}]:
		_check(not store.validate_values(bad)["ok"], "invalid settings rejected")
	var room = load("res://scenes/room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	_check(room.menu.visible, "main menu visible")
	_check(room.import_button.disabled, "legacy import unavailable until parent validation")
	room.set_legacy_session_available(true)
	_check(not room.import_button.disabled, "validated legacy import becomes available")
	room._confirm_import()
	_check(room.confirm.visible and room._pending_action == "import", "legacy import requires confirmation")
	room.confirm.hide()
	_check(room.studio.get_child_count() > 150, "studio authored objects present")
	room.return_to_room()
	_check(not room.menu.visible and room.camera.current, "room entry switches camera")
	room.player.position.z = 0.45
	_check(room._can_use_computer(), "computer can be used from desk approach")
	room.show_main_menu()
	_check(room.menu.visible and room.menu_camera.current, "menu restores camera")
	room.show_settings()
	_check(room.settings_panel != null, "settings opens")
	room.settings_panel.closed.emit()
	await process_frame
	_check(room.settings_panel == null, "settings closes")
	room.desktop = Control.new()
	room.desktop_layer.add_child(room.desktop)
	var app_window := Window.new()
	app_window.size = Vector2i(240, 160)
	room.desktop.add_child(app_window)
	room.open_desktop("continue")
	_check(room._in_desktop and room.desktop.visible, "desktop opens without replacing campaign state")
	var original_desktop: Control = room.desktop
	var return_key := InputEventKey.new()
	return_key.keycode = KEY_F10
	return_key.pressed = true
	room._input(return_key)
	_check(room.desktop == original_desktop and not room.desktop.visible, "desktop instance survives room return")
	_check(not app_window.visible, "embedded desktop windows hide on F10")
	room.open_desktop("continue")
	_check(app_window.visible, "embedded desktop windows resume with the same instance")
	room.show_main_menu()
	_check(not app_window.visible and not room.continue_button.disabled, "menu hides embedded windows and allows memory resume")
	for locale in Store.LOCALES:
		room.Localization.set_locale(locale)
		room._rebuild_menu()
		_check(room.continue_button.text != "CONTINUE", "translated menu key: " + locale)
	room.Localization.set_locale("ko")
	room._rebuild_menu()
	if DisplayServer.get_name() != "headless":
		var width := 1024 if OS.get_environment("PACKET_TRAIL_ROOM_NARROW") == "1" else 1600
		root.size = Vector2i(width, 720 if width == 1024 else 900)
		var locale := OS.get_environment("PACKET_TRAIL_ROOM_LOCALE")
		if locale in Store.LOCALES:
			room.settings_store._values["locale"] = locale
		if OS.get_environment("PACKET_TRAIL_ROOM_LARGE_TEXT") == "1":
			room.settings_store._values["font_scale"] = 1.6
		room._apply_settings(room.settings_store.get_values())
		await process_frame
		if OS.get_environment("PACKET_TRAIL_ROOM_VIEW") == "settings":
			room.show_settings()
			var focus_key := OS.get_environment("PACKET_TRAIL_ROOM_FOCUS")
			if room.settings_panel.controls.has(focus_key):
				await process_frame
				room.settings_panel.controls[focus_key].grab_focus()
		elif OS.get_environment("PACKET_TRAIL_ROOM_VIEW") == "room":
			room.return_to_room()
		elif OS.get_environment("PACKET_TRAIL_ROOM_VIEW") == "new_confirm":
			room._confirm_new()
		elif OS.get_environment("PACKET_TRAIL_ROOM_VIEW") == "import_confirm":
			room._confirm_import()
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("PACKET_TRAIL_ROOM_CAPTURE")
		if not path.is_empty():
			var error := root.get_texture().get_image().save_png(path)
			_check(error == OK, "capture written")
	print(JSON.stringify({"suite": "room_settings", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
