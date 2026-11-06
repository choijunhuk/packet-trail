extends "res://tests/headless/test_desktop_shell.gd"
## Presentation operations never grant facts or change challenge rules.


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	tree = scene_tree
	var before := _fingerprints()
	test_root = "user://tests/workbench_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(test_root)
	var desktop := await _new_desktop("defender", "standard", "workbench")
	if desktop != null:
		var snapshot: Dictionary = desktop.game.export_snapshot()
		desktop._clear_children(desktop.tool_obs_box)
		desktop._model_table("UI_RESPONSE_HISTORY", [], true)
		var empty: Control = desktop.tool_obs_box.get_child(0)
		var toggle: Button = empty.get_child(0)
		var content: Control = empty.get_child(1)
		_check(not content.visible and not toggle.button_pressed, "empty auxiliary records begin collapsed")
		_check(toggle.icon != null, "collapsed section has a persistent disclosure indicator")
		toggle.button_pressed = true
		_check(content.visible and content.get_child_count() == 1, "empty records remain explicitly inspectable")
		_check(toggle.icon != null, "expanded section retains a persistent disclosure indicator")
		var record := {"id": "record-1", "label": "Observed request", "window_index": 2, "can_advance": true, "source_id": "sensor-a"}
		desktop._model_table("UI_OBSERVATION_SENSORS", [record], false)
		var primary: Control = desktop.tool_obs_box.get_child(1)
		var primary_content: Control = primary.get_child(1)
		_check(primary_content.visible, "nonempty primary observation begins expanded")
		var table: Tree = primary_content.get_child(0)
		var row := table.get_root().get_first_child()
		_check(row.get_metadata(0) == record and table.columns == record.size(), "all public record fields remain in the table and detail metadata")
		row.select(0)
		table.item_selected.emit()
		var detail: Label = primary_content.get_child(1)
		_check(detail.text.contains("sensor-a") and detail.text.contains("record-1"), "row detail exposes source and identifier without losing fields")
		_check(desktop.tool_action_scroll.is_ancestor_of(desktop.tool_input_box) and desktop.tool_action_scroll.is_ancestor_of(desktop.tool_run_btn), "inputs and Run share the independent action pane")
		_check(not desktop.tool_detail_scroll.is_ancestor_of(desktop.tool_input_box), "long observation tables cannot push inputs down their own scroll pane")
		desktop._open_current_board()
		_check(desktop.active_id == "board" and desktop.bd_selected == desktop.get_game_view().mission_id, "objective action opens the actual current case board")
		_check(desktop.game.export_snapshot() == snapshot, "viewing records and goals leaves all core state unchanged")
		for id in desktop.wins:
			desktop._close(id)
		desktop._update_support(desktop.last_view)
		_check(desktop.support_card.visible, "first-action test has the actual support card visible")
		desktop._toast("Saved notice", Color.WHITE)
		_check(not desktop.toast_panel.visible and desktop.notification_button.tooltip_text == "Saved notice", "automatic notice compacts while first-action card is visible")
		desktop._toggle_notification()
		desktop._update_support(desktop.last_view)
		_check(desktop.toast_panel.visible, "explicit bell inspection survives support layout refresh")
		desktop._dismiss_notification()
		_check(not desktop.toast_panel.visible, "explicit notification remains dismissible")
		_check(desktop.game.export_snapshot() == snapshot, "notification operations cannot mutate the simulated world")
		var save_path: String = desktop.game.get("_save_path")
		_check(save_path.begins_with(test_root + "/"), "save-failure fixture is inside this test's owned directory")
		DirAccess.remove_absolute(save_path)
		DirAccess.make_dir_absolute(save_path)
		tree.root.gui_release_focus()
		desktop._manual_save()
		_check(desktop.toast_panel.visible and not desktop.status_label.text.is_empty(), "actual save failure remains visible beside first guidance without opening the bell")
		desktop._layout_notifications()
		_check(desktop.toast_panel.visible, "important failure survives subsequent support layout")
		desktop._open_terminal(0)
		await tree.process_frame
		desktop._manual_save()
		_check(not desktop.toast_panel.visible and not desktop.notification_button.disabled and not desktop.status_label.text.is_empty(), "editing protection compacts failures but leaves status and bell discoverable")
		desktop.queue_free()
		await tree.process_frame
	await _disclosure_refresh()
	await _typed_control_drafts()
	var challenge := Catalog.get_pack("challenge")
	_check(not challenge.is_empty() and challenge.start_mission == "X01", "challenge is an authored independent pack")
	var store := Settings.new(test_root + "/preferences.json")
	var panel := SettingsPanel.new()
	tree.root.add_child(panel)
	panel.setup(store)
	await tree.process_frame
	_check(panel.controls.has("support_challenge"), "challenge has a presentation-only support preference")
	panel.queue_free()
	await tree.process_frame
	_check(_fingerprints() == before, "workbench keeps real user preferences and save paths unchanged")
	_remove_owned(test_root)
	return {"suite": "workbench", "checks": checks, "failures": failures.duplicate(), "protected_paths": before.size(), "limit": "Functional scene and isolated state checks; rendered keyboard, pixels and human acceptance are separate."}


func _select_value(control: OptionButton, value: Variant) -> bool:
	for index in control.item_count:
		var candidate: Variant = control.get_item_metadata(index)
		if typeof(candidate) == typeof(value) and candidate == value:
			control.select(index)
			control.item_selected.emit(index)
			return true
	return false


func _typed_control_drafts() -> void:
	var desktop := await _new_desktop("challenge", "standard", "typed_drafts")
	if desktop == null:
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/challenge_solutions.json"))
	for action in fixture.packs.challenge.missions.X01.paths[0].actions:
		var result := {}
		match str(action.kind):
			"command": result = desktop.game.execute(str(action.line))
			"password": result = desktop.game.submit_password(str(action.value))
			"tool": result = desktop.game.use_tool(str(action.tool_id), action.params)
		_check(result.get("ok", false), "actual authored X01 action unlocks typed-control regression")
	_check(desktop.game.choose_mission("X02").get("ok", false), "actual completion unlocks X02 without progress injection")
	desktop.game.execute("ssh investigator@x02.challenge.packet.test")
	_check(desktop.game.submit_password("source-custody").get("ok", false), "X02 authenticates through the public API")
	desktop._refresh_all()
	desktop.tool_selected = "ch1_x02_response"
	desktop._tool_show(desktop._tool_current(), true)
	for choice in [{"control_id": "job_groups", "value": ["jobs", "deploy"]}, {"control_id": "directory_mode", "value": "750"}, {"control_id": "job_groups", "value": ["jobs"]}]:
		_check(_select_value(desktop.tool_inputs.action, "set_control"), "actual action picker rebuilds typed fields across draft types")
		_check(_select_value(desktop.tool_inputs.control_id, choice.control_id), "actual control picker retains canonical control id")
		_check(_select_value(desktop.tool_inputs.value, choice.value), "actual value picker selects canonical array or scalar")
		var params: Dictionary = desktop._tool_params()
		_check(typeof(params.get("value")) == typeof(choice.value) and params.get("value") == choice.value, "submitted params preserve the chosen value type")
		desktop._tool_run()
		var model: Dictionary = desktop.game.export_snapshot().current_world.model_states.ch1_x02_response
		var actual: Variant = model.group_overrides.get("ch1_x02_desk:notifier") if choice.control_id == "job_groups" else model.file_overrides.get("ch1_x02_desk", {}).get("/deploy", {}).get("mode")
		_check(typeof(actual) == typeof(choice.value) and actual == choice.value, "Run applies the selected array or scalar in the actual model")
		desktop._tool_save_draft()
		_check(_select_value(desktop.tool_inputs.action, "set_control"), "same action rebuild does not compare incompatible draft and option types")
		var restored: Dictionary = desktop._tool_params()
		_check(typeof(restored.get("value")) == typeof(choice.value) and restored.get("value") == choice.value, "valid same-control typed draft survives rebuilding")
	desktop.queue_free()
	await tree.process_frame


func _section(desktop: Control, key: String) -> Control:
	for group in desktop.tool_obs_box.get_children():
		if group.get_meta("observation_section", "") == key:
			return group
	return null


func _disclosure_refresh() -> void:
	var desktop := await _new_desktop("defender", "standard", "disclosure")
	if desktop == null:
		return
	desktop.game.execute("ssh operator@d01.defender.packet.test")
	_check(desktop.game.submit_password("night-duty").get("ok", false), "disclosure fixture authenticates through actual API")
	desktop._refresh_all()
	desktop.tool_selected = "df1_d01_response"
	desktop._tool_show(desktop._tool_current(), true)
	var controls := _section(desktop, "UI_RESPONSE_CONTROLS")
	var receipts := _section(desktop, "UI_RESPONSE_HISTORY")
	_check(controls != null and receipts != null, "actual defender tool exposes primary and auxiliary observation sections")
	if controls == null or receipts == null:
		desktop.queue_free()
		await tree.process_frame
		return
	var table: Tree = controls.get_child(1).get_child(0)
	var selected := table.get_root().get_first_child()
	var expected: Dictionary = selected.get_metadata(0)
	selected.select(0)
	table.item_selected.emit()
	controls.get_child(0).button_pressed = false
	receipts.get_child(0).button_pressed = true
	_check(_select_value(desktop.tool_inputs.action, "probe") and _select_value(desktop.tool_inputs.case_id, "own_a"), "actual probe fields selected before refresh")
	desktop._tool_run()
	controls = _section(desktop, "UI_RESPONSE_CONTROLS")
	receipts = _section(desktop, "UI_RESPONSE_HISTORY")
	_check(not controls.get_child(0).button_pressed and receipts.get_child(0).button_pressed, "real Run refresh preserves collapsed primary and expanded auxiliary sections")
	table = controls.get_child(1).get_child(0)
	_check(table.get_selected() != null and table.get_selected().get_metadata(0) == expected, "unchanged selected record is restored from fresh current rows")
	_check(controls.get_child(1).get_child(1).text.contains(str(expected.id)), "restored selected-record detail contains current record identity")
	desktop._on_tool_selected(1)
	desktop._on_tool_selected(0)
	controls = _section(desktop, "UI_RESPONSE_CONTROLS")
	_check(not controls.get_child(0).button_pressed, "per-tool disclosure survives switching away and back")
	var changed := expected.duplicate(true)
	changed["label"] = "Changed current row"
	desktop._clear_children(desktop.tool_obs_box)
	desktop._model_table("UI_RESPONSE_CONTROLS", [changed])
	controls = _section(desktop, "UI_RESPONSE_CONTROLS")
	table = controls.get_child(1).get_child(0)
	_check(table.get_selected() == null and not controls.get_child(1).get_child(1).text.contains(str(expected.id)), "changed row invalidates remembered detail instead of showing old data")
	_check(desktop._begin_new().get("ok", false), "actual new-world replacement succeeds")
	controls = _section(desktop, "UI_RESPONSE_CONTROLS")
	receipts = _section(desktop, "UI_RESPONSE_HISTORY")
	_check(controls.get_child(0).button_pressed and not receipts.get_child(0).button_pressed, "new world restores authored default disclosure states")
	desktop.queue_free()
	await tree.process_frame
