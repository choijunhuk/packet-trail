extends "res://tools/capture_perspectives.gd"
## First-look proof uses actual product UI and engine input. Never a substitute for full47 or OS input.

var observations: Array[Dictionary] = []


func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	profile = "desktop-preview"
	not_run.append("Preview completes intruder M01 only (1/47); remaining46 and four endings are GUI NOT_RUN.")
	not_run.append("Functional shell tests, prior full47, physical OS input and visual acceptance are separate evidence.")
	_run.call_deferred()
	create_timer(240.0).timeout.connect(func():
		if not finished:
			failures.append("desktop preview timed out")
			_finish())


func _run() -> void:
	if not (await _boot_product()):
		_finish()
		return
	await _capture("lobby-1600.png")
	await _settings_pages()
	await _lobby_small_viewport()
	if not (await _select_pack("intruder")):
		_finish()
		return
	await _support_confirmation_cancel()
	if not (await _accept_option(room.support_picker, "standard", "intruder standard")) or not (await _start_new_pack("intruder")):
		_finish()
		return
	_check(_open_windows().is_empty(), "standard starts with a real empty desktop")
	_check(desktop.launcher_button.visible and desktop.desktop_icons.size() >= 6, "empty desktop exposes launcher and original app icons")
	observations.append({"stage": "empty_desktop", "support": desktop.support_mode, "open_windows": _open_windows()})
	await _capture("empty-desktop.png")
	await _launcher_and_windows()
	await _browser_tabs()
	await _browser_large_font()
	await _close_all_and_resume()
	await _common_input_checks()
	await _request_lab_checks()
	if not (await _replay_case("M01")):
		_finish()
		return
	await _capture("M01-real-complete.png")
	await _room_resume_checks()
	# Old assumptions about automatic mail/terminal opening are replaced by explicit launches.
	await _open_app("mail")
	await _locale_audio_checks()
	for id in ["defender", "tracker", "challenge"]:
		if not (await _select_pack(id)) or not (await _start_new_pack(id)):
			_finish()
			return
		_check(_open_windows().is_empty(), "new standard scenario keeps desktop empty: " + id)
		await _capture("empty-desktop.png")
		await _view_first_forms()
		await _workbench_large_view()
	await _guided_goals_and_notifications()
	_check(selected_packs.size() == 4 and campaign_cases.size() == 1, "preview reports four real selections and exactly one completed case")
	_finish()


func _open_windows() -> Array[String]:
	var ids: Array[String] = []
	for id in desktop.wins:
		if desktop.wins[id].win.visible:
			ids.append(id)
	return ids


func _support_confirmation_cancel() -> void:
	var before := _path_fingerprint(preferences_path)
	for level in ["guided", "standard", "independent"]:
		if not (await _accept_option(room.support_picker, level, "support " + level)):
			return
		await _click(_metadata_button(room.menu_box, "lobby_action", "new"))
		_check(room.confirm.visible and room._pending_support == level, "New confirmation captures the actual support choice: " + level)
		await _capture("support-confirm-%s.png" % level)
		var cancel: Button = room.confirm.get_cancel_button()
		cancel.grab_focus()
		await _key(KEY_ENTER, false, false, 0, false, cancel.get_viewport())
		_check(not room.confirm.visible and room.desktop == null and _path_fingerprint(preferences_path) == before,
			"Cancel never starts a world or saves support: " + level)
		observations.append({"stage": "support_cancel", "level": level, "preferences_unchanged": _path_fingerprint(preferences_path) == before})


func _settings_pages(prefix := "") -> void:
	var values: Dictionary = room.settings_store.get_values()
	var before := _path_fingerprint(preferences_path)
	await _click(_metadata_button(room.menu_box, "lobby_action", "settings"))
	var panel: Control = room.settings_panel
	_check(panel != null and panel.tabs.get_tab_count() == 4, "settings exposes four real categories")
	if panel == null:
		return
	var category_count: int = panel.tabs.get_tab_count()
	var bar: TabBar = panel.tabs.get_tab_bar()
	for index in range(4):
		if prefix.is_empty():
			await _click_local(bar, bar.get_tab_rect(index).get_center())
		else:
			bar.grab_focus()
			for attempt in range(4):
				if panel.tabs.current_tab == index:
					break
				await _key(KEY_RIGHT if panel.tabs.current_tab < index else KEY_LEFT)
		_check(panel.tabs.current_tab == index, "actual tab input opens settings page %d" % index)
		await _capture(prefix + "settings-%d.png" % index)
		if not prefix.is_empty():
			var page_keys: Array = [["support_intruder", "support_defender", "support_tracker", "support_challenge"],
				["locale", "font_scale", "fullscreen", "reduced_motion"],
				["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "keyboard_volume", "tool_volume", "notification_volume", "background_audio"],
				["mouse_sensitivity", "comfort_mode"]][index]
			for key in page_keys:
				await _require_reachable(panel.controls[key], "settings-large/" + str(key))
			await _require_reachable(panel.apply_button, "settings-large/apply")
			await _require_reachable(panel.cancel_button, "settings-large/cancel")
			await _capture(prefix + "settings-%d-reached.png" % index)
	panel.controls["music_volume"].value = .23
	_select_option(panel.controls["support_intruder"], "guided")
	await _click(panel.cancel_button)
	var cancelled: bool = room.settings_panel == null and room.settings_store.get_values() == values and _path_fingerprint(preferences_path) == before
	_check(cancelled,
		"settings Cancel discards edited controls and preserves prefs")
	await _click(_metadata_button(room.menu_box, "lobby_action", "settings"))
	panel = room.settings_panel
	panel.controls["music_volume"].value = .31
	await _click(panel.apply_button)
	_check(room.settings_panel == null and is_equal_approx(room.settings_store.get_values().music_volume, .31), "actual Apply persists only the isolated settings path")
	var restored := Settings.new(preferences_path)
	var reloaded: bool = restored.load_settings().get("ok", false) and is_equal_approx(restored.get_values().music_volume, .31)
	_check(reloaded, "applied preferences survive real test-path reload")
	await _click(_metadata_button(room.menu_box, "lobby_action", "settings"))
	panel = room.settings_panel
	panel.controls["music_volume"].value = values.music_volume
	await _click(panel.apply_button)
	_check(room.settings_store.get_values() == values, "actual Apply restores original test preference values")
	observations.append({"stage": "settings", "categories": category_count, "cancel_preserved": cancelled, "isolated_apply_reload": reloaded})


func _launcher_and_windows() -> void:
	var snapshot: Dictionary = desktop.game.export_snapshot()
	await _click(desktop.launcher_button)
	_check(desktop.launcher_panel.visible, "actual launcher button opens application discovery")
	await _capture("launcher-all.png")
	await _launcher_small_viewport()
	desktop.launcher_search.grab_focus()
	for letter in "terminal":
		await _key(KEY_NONE, false, false, letter.unicode_at(0))
	_check(desktop.launcher_search.text == "terminal", "actual key events type the launcher search")
	await _key(KEY_ENTER)
	_check(desktop.active_id == "term0" and not desktop.launcher_panel.visible, "actual launcher search Enter opens terminal")
	var input: LineEdit = desktop.terms[0].input
	input.text = "desktop-unsent-draft"
	var draft_before: String = input.text
	var draft_caret: int = input.caret_column
	var win: Control = desktop.wins.term0.win
	var old_rect := Rect2(win.position, win.size)
	await _click(desktop.wins.term0.actions.maximize)
	_check(win.size.x > old_rect.size.x, "actual maximize expands the terminal")
	await _key(KEY_NONE, false, false, "x".unicode_at(0))
	observations.append({"stage": "maximize_typed_character", "draft_before": draft_before, "caret_before": draft_caret,
		"expected_after": draft_before.insert(draft_caret, "x"), "actual_after": input.text,
		"focus_is_command_input": root.gui_get_focus_owner() == input})
	_check(root.gui_get_focus_owner() == input and input.text == draft_before.insert(draft_caret, "x"),
		"mouse maximize restores editable command focus before the next typed character")
	input.text = "desktop-unsent-draft" # Setup restores the unsent draft for the window-lifetime checks.
	await _click(desktop.wins.term0.actions.maximize)
	_check(Rect2(win.position, win.size).is_equal_approx(old_rect), "second maximize action restores placement")
	await _drag_window(desktop.wins.term0.bar, Vector2(150, 15), Vector2(38, 26))
	_check(win.position.distance_to(old_rect.position) > 10.0, "actual held pointer motion moves a window")
	await _capture("terminal.png")
	await _click(desktop.wins.term0.actions.minimize)
	_check(not win.visible and desktop.task_buttons.term0.visible, "minimized app remains in running taskbar")
	await _click(desktop.task_buttons.term0)
	_check(win.visible and input.text == "desktop-unsent-draft", "taskbar restores the same window and draft")
	await _click(desktop.wins.term0.actions.close)
	_check(not win.visible and not desktop.task_buttons.term0.visible, "closed app leaves the running taskbar")
	await _click(desktop.desktop_icons.terminal)
	_check(desktop.terms[0].input == input and input.text == "desktop-unsent-draft", "desktop icon reopens the same terminal object")
	_check(desktop.game.export_snapshot() == snapshot, "all window actions preserve canonical world and goals")
	input.clear()
	observations.append({"stage": "windows", "launch": "search Enter + desktop icon", "lifetime": "same Control/core", "world_unchanged": desktop.game.export_snapshot() == snapshot})
	await _maximized_notification_input()


func _maximized_notification_input() -> void:
	var input: LineEdit = desktop.terms[0].input
	await _click(desktop.wins.term0.actions.maximize)
	await _click(desktop.save_btn)
	_check(not desktop.notification_button.disabled and not desktop._notification_text.is_empty(),
		"actual Save creates an inspectable notification in the maximized terminal")
	_check(not desktop.toast_panel.visible and root.gui_get_focus_owner() == input,
		"automatic notification is compact while maximized command entry stays focused")
	await _capture("terminal-maximized.png")
	var bell_trace := {"stage": "notification_pointer_trace", "input_source": "Window.push_input mouse motion/down/up",
		"focus_before": str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "NONE",
		"toast_before": desktop.toast_panel.visible}
	# Observe the actual button callback before deferred focus restoration; never emit it.
	var observe_bell := func():
		bell_trace["toast_after_actual_pressed_callback"] = desktop.toast_panel.visible
		bell_trace["focus_after_actual_pressed_callback"] = str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "NONE"
	desktop.notification_button.pressed.connect(observe_bell)
	await _click(desktop.notification_button)
	desktop.notification_button.pressed.disconnect(observe_bell)
	bell_trace["toast_after_settled_input"] = desktop.toast_panel.visible
	bell_trace["focus_after_settled_input"] = str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "NONE"
	observations.append(bell_trace)
	print("NOTIFICATION_POINTER ", JSON.stringify(bell_trace))
	_check(desktop.toast_panel.visible, "actual taskbar notification click explicitly opens the saved message")
	await _capture("terminal-maximized-notification-read.png")
	await _click(input)
	_check(not desktop.toast_panel.visible and root.gui_get_focus_owner() == input,
		"pointer return to command input compacts the notification")
	for letter in "pwd":
		await _key(KEY_NONE, false, false, letter.unicode_at(0))
	_check(input.text == "pwd", "actual character input edits the maximized terminal after reading its notification")
	action_result = {}
	await _key(KEY_ENTER)
	_check(action_result.get("ok", false) and input.text.is_empty() and not desktop.terms[0].history.is_empty() and desktop.terms[0].history.back() == "pwd",
		"actual Enter executes the typed command after notification inspection without a focus repair")
	await _capture("terminal-maximized-input-resumed.png")
	observations.append({"stage": "maximized_notification_input", "notification_source": "actual Save button",
		"automatic_toast_compact": not desktop.toast_panel.visible, "notification_reopen": not desktop.notification_button.disabled,
		"input_rect": _rect_values(input.get_global_rect()), "typed_command": "pwd", "command_ok": action_result.get("ok", false),
		"focus_is_command_input": root.gui_get_focus_owner() == input})
	await _click(desktop.wins.term0.actions.maximize)


func _drag_window(control: Control, local_point: Vector2, delta: Vector2) -> void:
	var point := control.get_global_transform_with_canvas() * local_point
	var viewport := control.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = point
	button.global_position = point
	button.pressed = true
	viewport.push_input(button, true)
	await _frames(1)
	motion = motion.duplicate() as InputEventMouseMotion
	motion.position = point + delta
	motion.global_position = point + delta
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	await _frames(1)
	viewport.push_input(motion, true)
	button = button.duplicate() as InputEventMouseButton
	button.position = point + delta
	button.global_position = point + delta
	button.pressed = false
	viewport.push_input(button, true)
	await _frames(2)


func _browser_tabs() -> void:
	await _click(desktop.desktop_icons.browser)
	var home := str(desktop.get_game_view().browser_home)
	await _browse(home)
	desktop.br_addr.text = home + "/edited-address"
	desktop.br_field.text = "tab_a_field"
	desktop.br_value.text = "tab_a_value"
	desktop.br_pass.text = "unsaved-browser-password"
	var first_id: int = desktop.browser_tabs.get_tab_metadata(0).id
	await _click(desktop.browser_new_tab_button)
	_check(desktop.browser_tabs.tab_count == 2 and desktop.br_pass.text.is_empty(), "actual new-tab click creates an independent tab and clears password")
	await _browse(home + "/notice")
	var second_url: String = desktop.br_addr.text
	var before: Dictionary = desktop.game.export_snapshot()
	var bar: TabBar = desktop.browser_tabs
	await _click_local(bar, bar.get_tab_rect(0).get_center())
	_check(desktop.browser_tabs.get_tab_metadata(0).id == first_id and desktop.br_addr.text == home + "/edited-address", "actual tab input restores the first editable address")
	_check(desktop.br_field.text == "tab_a_field" and desktop.br_value.text == "tab_a_value" and desktop.br_history == [home], "first tab preserves its own form and history")
	_check(not JSON.stringify(desktop._browser_states).contains("unsaved-browser-password"), "browser tabs never retain password text")
	_check(desktop.game.export_snapshot() == before, "tab switching does not invoke HTTP or mutate the world")
	await _capture("nightfox-two-tabs.png")
	await _click_local(bar, bar.get_tab_rect(1).get_center())
	_check(desktop.br_addr.text == second_url and desktop.br_field.text != "tab_a_field", "second tab restores its separate address and form")
	await _open_terminal(1)
	await _open_app("browser")
	var response_terminal: int = desktop._browser_states[desktop._browser_index].response_terminal
	_check(desktop.active_term == 1 and response_terminal == 0 and desktop.br_stale.visible,
		"current browser terminal changes while its prior response retains terminal0 provenance")
	_check(desktop.br_meta.text.contains("2") and desktop.br_meta.text.contains("1"), "browser displays distinct current and response terminal numbers")
	await _capture("nightfox-current-and-past.png")
	observations.append({"stage": "browser", "tabs": desktop.browser_tabs.tab_count, "switch_world_unchanged": desktop.game.export_snapshot() == before,
		"response_terminal": response_terminal, "current_terminal": desktop.active_term,
		"password_persisted": JSON.stringify(desktop._browser_states).contains("unsaved-browser-password")})


func _browser_large_font() -> void:
	var original: Dictionary = room.settings_store.get_values()
	var world: Dictionary = desktop.game.export_snapshot()
	root.size = Vector2i(1280, 720)
	for locale in ["ko", "de"]:
		var large := original.duplicate(true)
		large.font_scale = 1.6
		large.fullscreen = false
		large.locale = locale
		if not _set_test_settings(large):
			break
		await _frames(4)
		await _open_app("browser")
		if locale == "ko":
			await _click(desktop.wins.browser.actions.maximize)
		if not desktop.br_form_box.visible:
			await _require_reachable(desktop.br_form_toggle, "browser-large/" + locale + "/toggle-before-expand")
			await _click(desktop.br_form_toggle)
		_check(root.size == Vector2i(1280, 720) and is_equal_approx(desktop.font_scale, 1.6), "browser large-font proof uses the actual 1280 viewport")
		_check(desktop.active_id == "browser" and desktop.br_form_box.visible, "expanded browser form stays in the foreground: " + locale)
		_check(_visible_rect(desktop.br_site_page).size.x > 100.0 and _visible_rect(desktop.br_site_page).size.y > 100.0,
			"browser document retains a visible reading region with form expanded: " + locale)
		await _capture("nightfox-1280-large-%s-form-top.png" % locale)
		await _require_reachable(desktop.br_addr, "browser-large/" + locale + "/address")
		await _require_reachable(desktop.br_form_toggle, "browser-large/" + locale + "/form-toggle")
		var interactive: Array = desktop.br_form_box.find_children("*", "Control", true, false)
		var reachable := 0
		for control in interactive:
			if control.is_visible_in_tree() and (control is LineEdit or control is BaseButton or control is OptionButton):
				await _require_reachable(control, "browser-large/" + locale + "/form-" + str(reachable))
				reachable += 1
		_check(reachable >= 7, "expanded browser exposes all form and login input controls: " + locale)
		for attempt in range(12):
			if _visible_rect(desktop.br_status).size.y > 0.0:
				break
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.factor = 1.0
			wheel.position = desktop.br_response_scroll.get_global_rect().get_center()
			wheel.global_position = wheel.position
			wheel.pressed = true
			root.push_input(wheel, true)
			await _frames(2)
			wheel.pressed = false
			root.push_input(wheel, true)
		_check(_visible_rect(desktop.br_status).size.x > 100.0 and _visible_rect(desktop.br_status).size.y > 0.0,
			"browser status remains visible under expanded form: " + locale)
		await _capture("nightfox-1280-large-%s-form-reached.png" % locale)
		_check(desktop.game.export_snapshot() == world, "large browser locale/layout proof preserves canonical world: " + locale)
	root.size = Vector2i(1600, 900)
	_set_test_settings(original)
	await _frames(3)
	await _click(desktop.wins.browser.actions.maximize)


func _close_all_and_resume() -> void:
	var before: Dictionary = desktop.game.export_snapshot()
	for attempt in range(desktop.wins.size()):
		var open := _open_windows()
		if open.is_empty():
			break
		var id: String = desktop.active_id
		if not open.has(id):
			id = open.back()
			await _click(desktop.task_buttons[id])
		await _click(desktop.wins[id].actions.close)
		_check(not desktop.wins[id].win.visible, "actual foreground Close hides its own window: " + id)
	_check(_open_windows().is_empty(), "all real windows can be closed")
	var same := desktop
	await _key(KEY_F10)
	await _key(KEY_ESCAPE)
	await _continue_pack("intruder")
	_check(desktop == same and _open_windows().is_empty(), "F10/menu Continue respects the empty desktop without opening three panels")
	_check(desktop.game.export_snapshot() == before, "empty-desktop resume preserves world and goals")
	await _capture("empty-desktop-resumed.png")


func _render_suite() -> String:
	return "rendered_desktop_preview"


func _render_expected_scope() -> Dictionary:
	return {"packs_selected": 4, "cases": 1, "endings": 0, "support_confirm_cancel": 3,
		"settings_categories": 4, "browser_tabs": 2, "locales": Localization.LOCALES,
		"small_viewport": {"width": 1280, "height": 720, "font_scale": 1.6, "lobby_roles": 4, "settings_tabs": 4, "launcher_open": true},
		"limit": "First-look preview; full47 and OS acceptance are separate."}


func _render_ui_observations() -> Array:
	return observations


func _rect_values(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _visible_rect(control: Control) -> Rect2:
	var clipped := control.get_global_rect().intersection(control.get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and (parent.clip_contents or parent is ScrollContainer):
			clipped = clipped.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return clipped


func _require_reachable(control: Control, label: String) -> bool:
	_check(is_instance_valid(control), "required UI control exists: " + label)
	if not is_instance_valid(control):
		return false
	var disabled: bool = control is BaseButton and control.disabled
	if not disabled:
		control.grab_focus()
		await _frames(3) # Product ScrollContainer.follow_focus performs normal navigation.
	var rect := control.get_global_rect()
	var clip := _visible_rect(control)
	var fitted: bool = control.is_visible_in_tree() and rect.size.x > 0 and rect.size.y > 0 and clip.size.x >= rect.size.x - 1 and clip.size.y >= rect.size.y - 1
	var focused: bool = control.get_viewport().gui_get_focus_owner() == control
	_check(fitted, "control fits its actual viewport/scroll clipping after normal focus: " + label)
	_check(disabled or focused, "keyboard focus reaches enabled UI control: " + label)
	var clips: Array[Dictionary] = []
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and (parent.clip_contents or parent is ScrollContainer):
			clips.append({"class": parent.get_class(), "rect": _rect_values(parent.get_global_rect())})
		parent = parent.get_parent()
	observations.append({"stage": "viewport_reachability", "target": label, "rect": _rect_values(rect), "visible_intersection": _rect_values(clip),
		"viewport": _rect_values(control.get_viewport().get_visible_rect()), "clipping_ancestors": clips,
		"visible": control.is_visible_in_tree(), "disabled": disabled, "focused": focused, "fully_reachable": fitted and (disabled or focused)})
	return fitted and (disabled or focused)


func _lobby_small_viewport() -> void:
	var original: Dictionary = room.settings_store.get_values()
	var large := original.duplicate(true)
	large.font_scale = 1.6
	large.fullscreen = false
	root.size = Vector2i(1280, 720)
	if not _set_test_settings(large):
		return
	await _frames(4)
	_check(root.size == Vector2i(1280, 720) and is_equal_approx(room.settings_store.get_values().font_scale, 1.6), "lobby proof uses real1280 viewport and font1.6")
	for id in PACK_IDS:
		var card: Button = room.campaign_buttons.get(id)
		await _require_reachable(card, "lobby-large/scenario/" + id)
		await _key(KEY_ENTER)
		_check(room.selected_pack_id == id, "actual keyboard selects the large lobby scenario: " + id)
		await _capture("lobby-1280-large-%s.png" % id)
	await _require_reachable(room.support_picker, "lobby-large/support")
	await _accept_option(room.support_picker, "independent", "large lobby support")
	await _require_reachable(room.continue_button, "lobby-large/continue")
	var new_button := _metadata_button(room.menu_box, "lobby_action", "new")
	await _require_reachable(new_button, "lobby-large/new")
	await _key(KEY_ENTER)
	_check(room.confirm.visible, "large lobby New CTA opens a real confirmation")
	if room.confirm.visible:
		await _capture("support-confirm-1280-large.png")
		var cancel: Button = room.confirm.get_cancel_button()
		cancel.grab_focus()
		await _key(KEY_ENTER, false, false, 0, false, cancel.get_viewport())
	await _settings_pages("1280-large-")
	root.size = Vector2i(1600, 900)
	_set_test_settings(original)
	await _frames(3)


func _launcher_small_viewport() -> void:
	var original: Dictionary = room.settings_store.get_values()
	var world: Dictionary = desktop.game.export_snapshot()
	var large := original.duplicate(true)
	large.font_scale = 1.6
	large.fullscreen = false
	root.size = Vector2i(1280, 720)
	if not _set_test_settings(large):
		return
	await _frames(4)
	_check(root.size == Vector2i(1280, 720) and is_equal_approx(desktop.font_scale, 1.6) and desktop.launcher_panel.visible,
		"large launcher proof uses actual1280 viewport/font1.6 and an open launcher")
	await _capture("launcher-1280-large.png")
	await _require_reachable(desktop.launcher_search, "launcher-large/search")
	for id in desktop.launcher_buttons:
		if not desktop.launcher_buttons[id].disabled:
			await _require_reachable(desktop.launcher_buttons[id], "launcher-large/" + str(id))
	await _capture("launcher-1280-large-reached.png")
	_check(desktop.game.export_snapshot() == world, "large launcher layout and focus preserve canonical world")
	root.size = Vector2i(1600, 900)
	_set_test_settings(original)
	await _frames(3)


func _workbench_large_view() -> void:
	var original: Dictionary = room.settings_store.get_values()
	var large := original.duplicate(true)
	large.font_scale = 1.6
	large.fullscreen = false
	root.size = Vector2i(1280, 720)
	if not _set_test_settings(large): return
	await _open_app("tools")
	await _frames(4)
	var win: Control = desktop.wins["tools"].win
	if not Rect2(win.position, win.size).is_equal_approx(Rect2(Vector2.ZERO, desktop._desk_size())):
		await _focus_and_click(desktop.wins["tools"].actions.maximize)
	await _frames(3)
	for key in desktop.tool_inputs:
		var control: Control = desktop.tool_inputs[key]
		if control.visible and control.focus_mode != Control.FOCUS_NONE:
			await _require_reachable(control, active_pack + "/workbench-large/input/" + str(key))
	await _require_reachable(desktop.tool_run_btn, active_pack + "/workbench-large/run")
	await _capture("workbench-1280-large-actions.png")
	for group in desktop.tool_obs_box.get_children():
		if not group.has_meta("observation_section") or group.get_child_count() < 2: continue
		var heading := group.get_child(0) as Button
		if heading == null: continue
		await _require_reachable(heading, active_pack + "/workbench-large/section/" + str(group.get_meta("observation_section")))
		if not heading.button_pressed:
			await _key(KEY_ENTER)
		await _frames(2)
		var content: Node = group.get_child(1)
		_check(content.visible, "native keyboard opens all public workbench record sections")
		var table: Tree = null
		for child in content.get_children():
			if child is Tree: table = child; break
		if table != null and table.get_root() != null and table.get_root().get_first_child() != null:
			await _require_reachable(table, active_pack + "/workbench-large/records")
			await _key(KEY_DOWN)
			await _frames(2)
			var selected := table.get_selected()
			_check(selected != null, "native keyboard selects a public record row")
			if selected != null:
				var detail: Label = content.get_child(content.get_child_count() - 1) as Label
				var record: Dictionary = selected.get_metadata(0)
				var complete := detail != null and not record.is_empty()
				if detail != null:
					for field in record:
						complete = complete and detail.text.contains(desktop._field_name(str(field)) + ": " + desktop._model_value(record[field], str(field)))
				_check(complete, "selected public record exposes every actual field beyond clipped table columns")
	await _capture("workbench-1280-large-records.png")
	var record_memory := _record_memory()
	if await _fill_basic_form({"action": "inspect"}):
		var actual: Dictionary = await _run_selected_tool()
		_check(actual.has("ok"), "native workbench memory check actually submits a registered model action")
		_check(_record_memory() == record_memory, "public record disclosure and exact selected rows survive actual Run refresh")
	await _capture("workbench-1280-large-records-after-run.png")
	root.size = Vector2i(1600, 900)
	_set_test_settings(original)
	await _frames(3)


func _guided_goals_and_notifications() -> void:
	if not (await _select_pack("challenge")): return
	if not (await _accept_option(room.support_picker, "guided", "challenge guided notification check")): return
	if not (await _start_new_pack("challenge")): return
	await _frames(6)
	_check(desktop.support_mode == "guided" and desktop.support_card.visible, "fresh guided challenge visibly presents actual first-case direction")
	_check(not desktop.toast_panel.visible and not desktop.notification_button.disabled, "automatic save notice is compact while first-case card is visible")
	await _capture("guided-card-compact-notification.png")
	await _focus_and_click(desktop.notification_button)
	await _frames(2)
	_check(desktop.toast_panel.visible, "explicit bell still opens full notification over guided state")
	await _capture("guided-card-explicit-bell.png")
	await _focus_and_click(desktop.notification_button)
	var snapshot: Dictionary = desktop.game.export_snapshot()
	var hints: int = desktop.hints_revealed
	await _focus_and_click(desktop.top_progress)
	await _frames(2)
	_check(desktop.active_id == "board" and desktop.game.export_snapshot() == snapshot and desktop.hints_revealed == hints, "actual goal button opens current board without changing evidence or revealing a new hint")
	await _capture("goal-button-current-board.png")
	var blocker := slot + ".tmp"
	_check(blocker.begins_with("user://tests/") and not FileAccess.file_exists(blocker) and not DirAccess.dir_exists_absolute(blocker), "save-failure blocker belongs to an absent isolated test sidecar")
	if blocker.begins_with("user://tests/") and not FileAccess.file_exists(blocker) and not DirAccess.dir_exists_absolute(blocker):
		var created := DirAccess.make_dir_recursive_absolute(blocker)
		_check(created == OK, "actual isolated temporary-sidecar directory blocks atomic save")
		if created == OK:
			var disk_before := _path_fingerprint(slot)
			var world_before: Dictionary = desktop.game.export_snapshot()
			await _focus_and_click(desktop.save_btn)
			await _frames(2)
			_check(desktop.support_card.visible and desktop.toast_panel.visible, "important actual save failure stays visible alongside first-case guidance")
			_check(desktop._notification_important and desktop.game.export_snapshot() == world_before and _path_fingerprint(slot) == disk_before, "failed actual Save reports importance and preserves both disk and canonical world")
			await _capture("guided-card-important-save-failure.png")
			_check(DirAccess.remove_absolute(blocker) == OK, "only the owned empty temporary-sidecar blocker is removed")


func _record_memory() -> Dictionary:
	var memory := {}
	for group in desktop.tool_obs_box.get_children():
		if not group.has_meta("observation_section") or group.get_child_count() < 2: continue
		var heading := group.get_child(0) as Button
		if heading == null: continue
		var row := ""
		for child in group.get_child(1).get_children():
			if child is Tree and child.get_selected() != null:
				row = JSON.stringify(child.get_selected().get_metadata(0), "", true)
		memory[str(group.get_meta("observation_section"))] = {"open": heading.button_pressed, "selected": row}
	return memory
