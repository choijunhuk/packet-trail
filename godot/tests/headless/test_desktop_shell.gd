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
	await _site_presentation()
	await _interaction_quality()
	await _settings_cancel()
	Localization.set_locale(locale)
	_check(profiles.size() == 9, "all three support modes were exercised for each public pack")
	_check(_fingerprints() == before, "default campaign/settings/sidecars and progress folders remain unchanged")
	_remove_owned(test_root)
	return {"suite": "desktop_shell", "checks": checks, "failures": failures.duplicate(), "profiles": profiles,
		"protected_paths": before.size(), "limit": "Functional scene/core methods, preference IO and synthesized viewport key dispatch. Not native rendering, OS input, physical IME, hearing, or visual design acceptance."}


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


func _site_presentation() -> void:
	var desktop := await _new_desktop("intruder", "standard", "site")
	if desktop == null:
		return
	desktop._launch_app("browser")
	var home := str(desktop.get_game_view().browser_home)
	desktop._br_navigate(home, true)
	var first_host: String = desktop.br_site_host.text
	_check(first_host == home.get_slice("://", 1).get_slice("/", 0), "site identity comes from rendered virtual URL")
	_check(desktop.br_site_host.selection_enabled and not desktop.br_site_host.bbcode_enabled and desktop.br_body.selection_enabled and not desktop.br_body.bbcode_enabled, "site host and body remain selectable plain text without markup interpretation")
	var response: Dictionary = desktop._browser_states[0].response.duplicate(true)
	_check(desktop.br_body.get_parsed_text() == str(response.get("body", response.get("text", ""))), "site presentation preserves actual response body bytes")
	desktop.br_addr.text = "https://unsubmitted.packet.test/draft"
	_check(desktop.br_site_host.text == first_host, "editing address does not relabel the displayed response site")
	var world: Dictionary = desktop.game.export_snapshot()
	desktop._browser_new_tab()
	_check(desktop.br_site_host.text.is_empty() and not desktop.br_site_host.visible, "empty tab clears previous site identity")
	desktop._br_render({"ok": false, "status": 404, "body": "[b]literal failure[/b]"}, "https://missing.packet.test/not-found", false, true)
	_check(desktop.br_site_host.text == "missing.packet.test" and desktop.br_body.get_parsed_text() == "[b]literal failure[/b]", "error response uses attempted site identity and literal body")
	desktop.browser_tabs.current_tab = 0
	_check(desktop.br_site_host.text == first_host and desktop.br_site_host.tooltip_text == home, "cached tab restores displayed response host instead of unsent address")
	_check(desktop.game.export_snapshot() == world, "presentation and cached tab restoration never grant rights or make a request")
	desktop._br_fit_document()
	_check(desktop.br_site_margin.get_theme_constant("margin_left") >= 18, "site document keeps readable inner padding")
	_check(desktop.br_body.fit_content and not desktop.br_body.scroll_active and desktop.br_site_page.size_flags_vertical == Control.SIZE_SHRINK_BEGIN, "document content height belongs to the outer response scroller")
	_check(desktop.br_response_scroll.follow_focus and desktop.br_response_scroll.is_ancestor_of(desktop.br_form_box) and desktop.br_response_scroll.is_ancestor_of(desktop.br_status), "page forms and footer share one focus-following response scroll")
	_check(not desktop.br_response_scroll.is_ancestor_of(desktop.br_stale_row) and not desktop.br_response_scroll.is_ancestor_of(desktop.browser_tabs), "historical response warning and browser tabs remain outside scrolling content")
	_check(desktop.top_host.tooltip_text == desktop.top_host.text and desktop.top_host.custom_minimum_size.x >= 250, "full session identity is available while essential header space is reserved")
	_check(desktop.top_alert.tooltip_text == desktop.top_alert.text, "alert tooltip describes the actual current advisory state")
	var tools: Array = desktop.last_view.get("tools", [])
	if not tools.is_empty():
		_check(desktop.tool_list.get_item_tooltip(0).contains(str(tools[0].get("name", tools[0].id))), "tool list tooltip exposes human-readable name")
	if tools.size() > 1:
		desktop._open_app("tools", true)
		await tree.process_frame
		desktop.tool_detail_scroll.scroll_vertical = 100
		desktop._on_tool_selected(1)
		_check(desktop.tool_detail_scroll.scroll_vertical == 0, "selecting another tool resets detail scroll to its introduction")
	desktop._br_reset()
	_check(desktop.br_site_host.text.is_empty(), "world/browser reset clears site identity")
	desktop.queue_free()
	await tree.process_frame
	await tree.process_frame


func _key(code: Key, alt := false, ctrl := false, meta := false, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.alt_pressed = alt
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	event.shift_pressed = shift
	return event


func _dispatch_key(event: InputEventKey) -> void:
	tree.root.push_input(event, true)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	tree.root.push_input(release, true)


func _interaction_quality() -> void:
	var desktop := await _new_desktop("intruder", "standard", "interaction")
	if desktop == null:
		return
	desktop._open_terminal(0)
	var input: LineEdit = desktop.terms[0].input
	desktop.terms[0].history = ["cat /desk/a", "ls", "cat /desk/b", "pwd"]
	input.text = "cat "
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "cat /desk/b", "Up finds newest history matching the draft prefix")
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "cat /desk/a", "Up skips unrelated history entries")
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "cat /desk/a", "Up at oldest matching entry preserves that entry")
	desktop._open_terminal(1)
	var other: LineEdit = desktop.terms[1].input
	desktop.terms[1].history = ["other-command"]
	desktop._on_term_key(_key(KEY_UP), 1)
	_check(other.text == "other-command" and input.text == "cat /desk/a", "terminal history cursors and prefixes remain independent")
	desktop._on_term_key(_key(KEY_DOWN), 0)
	_check(input.text == "cat /desk/b", "Down traverses only the original prefix matches")
	desktop._on_term_key(_key(KEY_DOWN), 0)
	_check(input.text == "cat " and desktop.terms[0].hist_idx == -1, "Down beyond newest match restores the exact draft")
	desktop._on_term_key(_key(KEY_DOWN), 0)
	_check(input.text == "cat ", "Down outside history leaves the draft intact")
	input.text = "no-such-prefix"
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "no-such-prefix" and desktop.terms[0].hist_idx == -1, "unmatched prefix preserves the input and remains outside history")
	input.clear()
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "pwd", "empty draft retains unfiltered newest history")
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "cat /desk/b", "empty draft retains unfiltered backward navigation")
	input.text = "ls"
	desktop._on_term_key(_key(KEY_UP), 0)
	_check(input.text == "ls" and desktop.terms[0].draft == "ls", "editing a recalled command starts a fresh prefix search")
	desktop._on_term_key(_key(KEY_DOWN), 0)
	_check(input.text == "ls" and desktop.terms[0].hist_idx == -1, "edited recall draft returns after its newest match")
	desktop.terms[0].pw = true
	input.secret = true
	input.text = "never-store-secret"
	var history_before: Dictionary = {"history": desktop.terms[0].history.duplicate(), "draft": desktop.terms[0].draft}
	desktop._on_term_key(_key(KEY_UP), 0)
	desktop._on_term_key(_key(KEY_DOWN), 0)
	desktop._on_term_key(_key(KEY_TAB), 0)
	_check(input.text == "never-store-secret" and desktop.terms[0].history == history_before.history and desktop.terms[0].draft == history_before.draft, "secret entry cannot enter history navigation or completion")
	desktop.terms[0].pw = false
	input.secret = false
	input.clear()

	desktop._launch_app("browser")
	var home := str(desktop.get_game_view().browser_home)
	desktop._br_navigate(home, true)
	desktop._br_navigate(home + "/notice", true)
	desktop.br_addr.grab_focus()
	await tree.process_frame
	_dispatch_key(_key(KEY_LEFT, true))
	_check(desktop.br_cursor == 0 and desktop.br_url == home, "input dispatch Alt+Left visits the previous browser page")
	_dispatch_key(_key(KEY_RIGHT, true))
	_check(desktop.br_cursor == 1 and desktop.br_url == home + "/notice", "input dispatch Alt+Right visits the next browser page")
	_dispatch_key(_key(KEY_RIGHT, true))
	_check(desktop.br_cursor == 1, "forward at browser history boundary is harmless")
	for event in [_key(KEY_LEFT, true, true), _key(KEY_LEFT, true, false, true), _key(KEY_LEFT, true, false, false, true)]:
		_dispatch_key(event)
		_check(desktop.br_cursor == 1, "Alt navigation ignores additional command/control/shift modifiers")
	var nav_before: Array = desktop.br_history.duplicate()
	for event in [_key(KEY_R, false, true), _key(KEY_R, false, not OS.has_feature("macos"), OS.has_feature("macos")), _key(KEY_F5)]:
		desktop._browser_states[0].response = {}
		desktop.br_addr.text = home + "/unsubmitted-draft"
		_dispatch_key(event)
		_check(not desktop._browser_states[0].response.is_empty() and desktop.br_url == home + "/notice" and desktop.br_history == nav_before, "input refresh re-requests loaded page without adding history or submitting address draft")
	desktop._open_terminal(0)
	desktop._browser_states[0].response = {}
	for event in [_key(KEY_LEFT, true), _key(KEY_RIGHT, true), _key(KEY_R, false, true), _key(KEY_F5)]:
		_dispatch_key(event)
	_check(desktop.br_cursor == 1 and desktop._browser_states[0].response.is_empty(), "browser shortcuts do nothing while a terminal is active")
	desktop._launch_app("browser")
	desktop.br_form_box.show()
	desktop.br_pass.grab_focus()
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == desktop.br_pass, "password guard dispatch test owns the focused secret field")
	desktop.br_pass.text = "private-browser-draft"
	for event in [_key(KEY_LEFT, true), _key(KEY_RIGHT, true), _key(KEY_R, false, true), _key(KEY_F5)]:
		_dispatch_key(event)
	_check(desktop.br_cursor == 1 and desktop._browser_states[0].response.is_empty() and desktop.br_pass.text == "private-browser-draft", "focused password blocks browser navigation and refresh dispatch")
	desktop.br_addr.grab_focus()
	desktop._ask("Shortcut guard", func(): callbacks += 1)
	await tree.process_frame
	for event in [_key(KEY_LEFT, true), _key(KEY_RIGHT, true), _key(KEY_R, false, true), _key(KEY_F5)]:
		_dispatch_key(event)
	_check(desktop.confirm.visible and desktop.br_cursor == 1 and desktop._browser_states[0].response.is_empty(), "confirmation modal blocks browser navigation and refresh dispatch")
	desktop.confirm.hide()
	desktop.confirm_action = Callable()
	desktop._set_paused(true)
	_dispatch_key(_key(KEY_F5))
	_check(desktop._browser_states[0].response.is_empty(), "pause blocks browser refresh dispatch")
	desktop._set_paused(false)
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
