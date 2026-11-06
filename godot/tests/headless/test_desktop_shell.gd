extends RefCounted
## Functional product-scene methods and isolated IO; native input/pixels have a separate suite.

const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const SettingsPanel = preload("res://scripts/presentation/settings_panel.gd")
const Settings = preload("res://scripts/presentation/settings_store.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const Localization = preload("res://scripts/presentation/localization.gd")

var checks := 0
var failures: Array[String] = []
var profiles: Array[Dictionary] = []
var tree: SceneTree
var test_root := ""
var callbacks := 0


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	profiles.clear()
	callbacks = 0
	tree = scene_tree
	var before := _fingerprints()
	var locale := TranslationServer.get_locale()
	test_root = "user://tests/desktop_shell_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(not DirAccess.dir_exists_absolute(test_root), "functional tests use a fresh owned directory")
	DirAccess.make_dir_recursive_absolute(test_root)
	await _profile_and_window_lifetime()
	await _browser_and_replacement()
	await _settings_cancel()
	Localization.set_locale(locale)
	_check(profiles.size() == 9, "all three support modes were exercised for each public pack")
	_check(_fingerprints() == before, "default campaign/settings/sidecars and progress folders remain unchanged")
	_remove_owned(test_root)
	return {"suite": "desktop_shell", "checks": checks, "failures": failures.duplicate(), "profiles": profiles,
		"protected_paths": before.size(), "limit": "Functional scene/core methods, preference IO and settings Cancel Enter. Not native rendering, OS input, physical IME, hearing, or visual design acceptance."}


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _new_desktop(pack: String, level: String, suffix: String) -> Control:
	var desktop: Control = DesktopScene.instantiate()
	var path := test_root + "/" + pack + "_" + suffix + ".json"
	desktop.pack_id = pack
	desktop.save_slot_path = path
	tree.root.add_child(desktop)
	await tree.process_frame
	var isolated: bool = desktop.game.get("_save_path") == path and desktop.game.get("_pack_id") == pack
	_check(isolated, "actual core preserves the injected test slot before any write")
	if not isolated:
		desktop.queue_free()
		await tree.process_frame
		return null
	desktop.apply_settings({"support_" + pack: level})
	var result: Dictionary = desktop.start_session("new")
	_check(result.get("ok", false), "real new session starts: " + pack + "/" + level)
	await tree.process_frame
	await tree.process_frame
	return desktop


func _visible_windows(desktop: Control) -> Array[String]:
	var result: Array[String] = []
	for id in desktop.wins:
		if desktop.wins[id].win.visible:
			result.append(id)
	return result


func _profile_and_window_lifetime() -> void:
	for pack in ["intruder", "defender", "tracker"]:
		var canonical := {}
		for level in ["guided", "standard", "independent"]:
			var desktop := await _new_desktop(pack, level, level)
			if desktop == null:
				continue
			var snapshot: Dictionary = desktop.game.export_snapshot()
			if canonical.is_empty():
				canonical = snapshot.duplicate(true)
			_check(snapshot == canonical, "support never changes canonical snapshot/goals: " + pack + "/" + level)
			var expected: Array = ["mail"] if level == "guided" else []
			_check(_visible_windows(desktop) == expected, "support has only its declared automatic window policy: " + level)
			if level == "guided":
				_check(desktop.hints_revealed == 1 and desktop.bd_hint_text.visible, "guided shows only the first public hint")
			else:
				_check(desktop.hints_revealed == 0, "non-guided mode does not consume a hint")
			profiles.append({"pack": pack, "support": level, "open_windows": _visible_windows(desktop), "canonical_equal": snapshot == canonical})
			for id in desktop.wins:
				if desktop.wins[id].win.visible:
					desktop._close(id)
			desktop.start_session("continue")
			await tree.process_frame
			_check(_visible_windows(desktop).is_empty(), "closing all apps then Continue never reopens three panels")
			desktop._open_terminal(0)
			var input: LineEdit = desktop.terms[0].input
			input.text = "retained-shell-draft"
			var win: Control = desktop.wins.term0.win
			var rect := Rect2(win.position, win.size)
			desktop._minimize("term0")
			_check(not win.visible and desktop.task_buttons.term0.visible, "minimize preserves a running taskbar entry")
			desktop._task_activate("term0")
			_check(win.visible and input.text == "retained-shell-draft", "taskbar restores the same draft")
			desktop._toggle_max("term0")
			desktop._toggle_max("term0")
			_check(Rect2(win.position, win.size).is_equal_approx(rect), "maximize/restore preserves placement")
			desktop._close("term0")
			_check(not desktop.task_buttons.term0.visible, "closed apps leave the running taskbar")
			desktop._launch_app("terminal")
			_check(desktop.terms[0].input == input and input.text == "retained-shell-draft", "app launch reuses its Control and draft")
			input.grab_focus()
			desktop.hide()
			await tree.process_frame
			desktop.show()
			await tree.process_frame
			await tree.process_frame
			_check(tree.root.gui_get_focus_owner() == input, "visibility resume restores exact terminal focus with its draft")
			_check(desktop.game.export_snapshot() == snapshot, "window operations preserve core world and goals")
			desktop.queue_free()
			await tree.process_frame
			await tree.process_frame


func _browser_and_replacement() -> void:
	var desktop := await _new_desktop("intruder", "standard", "tabs")
	if desktop == null:
		return
	var home := str(desktop.get_game_view().browser_home)
	desktop._launch_app("browser")
	desktop._br_navigate(home, true)
	var response: Dictionary = desktop._browser_states[0].response.duplicate(true)
	desktop.br_addr.text = home + "/unsent-address"
	desktop.br_method.select(1)
	desktop.br_field.text = "field_a"
	desktop.br_value.text = "value_a"
	desktop.br_user.text = "user_a"
	desktop.br_pass.text = "never-persist-browser-secret"
	desktop._browser_new_tab()
	_check(desktop.browser_tabs.tab_count == 2 and desktop.br_pass.text.is_empty(), "new tab clears only the ephemeral browser password")
	desktop._br_navigate(home + "/notice", true)
	var before_switch: Dictionary = desktop.game.export_snapshot()
	desktop.browser_tabs.current_tab = 0
	_check(desktop.br_addr.text == home + "/unsent-address" and desktop.br_history == [home], "tab restores editable address and independent navigation history")
	_check(desktop.br_method.selected == 1 and desktop.br_field.text == "field_a" and desktop.br_value.text == "value_a" and desktop.br_user.text == "user_a", "tab restores non-secret form state")
	_check(desktop._browser_states[0].response == response, "tab restores its historical response without replacing it")
	_check(desktop.game.export_snapshot() == before_switch, "tab switching does not make a virtual HTTP request")
	_check(not JSON.stringify(desktop._browser_states).contains("never-persist-browser-secret"), "no tab model retains a browser password")
	desktop._open_terminal(3)
	var pending: Dictionary = desktop.game.execute("ssh guest@archive.packet.test", 3)
	_check(pending.get("needs_password", false), "actual core SSH establishes an independent pending terminal")
	desktop._refresh_all()
	desktop.terms[3].input.text = "unsubmitted-terminal-secret"
	desktop._open_terminal(1)
	desktop._launch_app("browser")
	desktop._br_navigate(home, true)
	_check(desktop._browser_states[desktop._browser_index].response_terminal == 1, "new browser response records the explicit active terminal")
	_check(desktop.game.get_view(3).password_pending and desktop.terms[3].input.secret and desktop.terms[3].input.text == "unsubmitted-terminal-secret", "browser requests preserve another terminal's pending secret")
	for index in range(10):
		desktop._browser_new_tab()
	_check(desktop.browser_tabs.tab_count == 8 and desktop.browser_new_tab_button.disabled, "browser enforces the public eight-tab limit")
	for index in range(8):
		desktop._browser_close_tab(0)
	_check(not desktop.wins.browser.win.visible and desktop.browser_tabs.tab_count == 1, "last tab close hides browser and leaves a fresh empty tab")
	desktop._ask("Previous-world prompt", func(): callbacks += 1)
	var generation: int = desktop.session_generation
	desktop.start_session("new")
	await tree.process_frame
	_check(desktop.session_generation > generation and not desktop.confirm.visible and not desktop.confirm_action.is_valid(), "new world invalidates the previous modal generation")
	desktop._on_confirmed()
	_check(callbacks == 0, "late prior-world confirmation cannot invoke its callback")
	_check(desktop.browser_tabs.tab_count == 1 and desktop._browser_states[0].response.is_empty(), "new world discards browser responses and tabs")
	_check(not desktop.game.get_view(3).password_pending and desktop.terms[3].input.text.is_empty() and not desktop.terms[3].input.secret, "new world clears pending secrets before plain input")
	desktop.queue_free()
	await tree.process_frame
	await tree.process_frame


func _settings_cancel() -> void:
	var path := test_root + "/preferences.json"
	var store := Settings.new(path)
	_check(store.get("_path") == path, "functional settings store retains exact injected path")
	if store.get("_path") != path:
		return
	_check(store.update_settings({"music_volume": .44}).get("ok", false), "initial settings write stays inside test tree")
	var before := FileAccess.get_sha256(path)
	var values := store.get_values()
	var panel := SettingsPanel.new()
	tree.root.add_child(panel)
	panel.setup(store)
	panel.controls.music_volume.value = .11
	panel.controls.support_intruder.select(0)
	var closed: Array[bool] = []
	panel.closed.connect(func(): closed.append(true))
	panel.cancel_button.grab_focus()
	await tree.process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	panel.cancel_button.get_viewport().push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	panel.cancel_button.get_viewport().push_input(event, true)
	await tree.process_frame
	_check(closed.size() == 1 and FileAccess.get_sha256(path) == before and store.get_values() == values, "actual Cancel Enter emits once without applying values or prefs")
	_check(panel.tabs.get_tab_count() == 4, "functional settings has all four categories")
	panel.queue_free()
	await tree.process_frame


func _fingerprints() -> Dictionary:
	var result := {}
	var paths: Array[String] = [Settings.PATH, Catalog.LEGACY_SOURCE, "user://saves/slot_01.json"]
	for pack in Catalog.list_packs(true):
		paths.append(Catalog.default_slot(pack.id))
	for path in paths:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			result[path + suffix] = FileAccess.get_sha256(path + suffix) if FileAccess.file_exists(path + suffix) else "MISSING"
	for path in ["user://saves", "user://progress"]:
		_fingerprint_folder(path, result)
	return result


func _fingerprint_folder(path: String, result: Dictionary) -> void:
	var dir := DirAccess.open(path)
	result[path] = "DIRECTORY" if dir != null else "MISSING"
	if dir == null:
		return
	for file in dir.get_files():
		result[path.path_join(file)] = "SYMLINK" if dir.is_link(file) else FileAccess.get_sha256(path.path_join(file))
	for folder in dir.get_directories():
		if dir.is_link(folder):
			result[path.path_join(folder)] = "SYMLINK"
		else:
			_fingerprint_folder(path.path_join(folder), result)


func _remove_owned(path: String) -> void:
	if test_root.is_empty() or not test_root.begins_with("user://tests/") or not (path == test_root or path.begins_with(test_root + "/")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for folder in dir.get_directories():
		if dir.is_link(folder):
			DirAccess.remove_absolute(path.path_join(folder))
		else:
			_remove_owned(path.path_join(folder))
	DirAccess.remove_absolute(path)
