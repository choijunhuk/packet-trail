extends "res://tools/capture_full_game.gd"
## Public-pack render regression. Base input/capture primitives are reused without editing the old suite.

const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const ORIGINAL_PACK_IDS := ["intruder", "defender", "tracker"]
const PACK_IDS := ["intruder", "defender", "tracker", "challenge"]
const STRUCTURED := ["response_lab", "observation_case", "branch_vm"]
const CASE_COUNTS := {"intruder": 28, "defender": 8, "tracker": 8, "challenge": 3}

var test_base := ""
var active_pack := ""
var pack_slots: Dictionary = {}
var pack_snapshots: Dictionary = {}
var pack_disk_hashes: Dictionary = {}
var pack_desktops: Dictionary = {}
var pack_endings: Array[Dictionary] = []
var selected_packs: Array[String] = []
var typed_runs: Array[Dictionary] = []
var form_views: Array[Dictionary] = []
var native_actions := 0
var password_actions := 0
var auth_cancel_checked := false
var manual_save_checked: Dictionary = {}
var legacy_source_probe: Dictionary = {}
var fixture_packs: Dictionary = {}
var preferences_path := ""
# Expected presentation intent comes from the actual test actions, never bootstrap's private cue flag.
var expected_ending_context := false


func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	not_run.append("Legacy campaign GUI and alternate GUI solution routes are outside this public-pack A-route suite; legacy/backend validation is separate.")
	if OS.get_cmdline_user_args().has("--ci-render-smoke"):
		profile = "ci-render-smoke"
		not_run.append("Smoke completes only intruder M01 (1/47); remaining46 case GUI solutions and all four endings are NOT_RUN. Full headless campaign evidence is separate.")
		not_run.append("Smoke views only typed forms exposed by each pack's real first case; later branch_vm forms and model actions are NOT_RUN.")
	_run.call_deferred()
	create_timer(240.0 if profile == "ci-render-smoke" else 600.0).timeout.connect(func():
		if not finished:
			failures.append("%s rendered_perspectives timed out" % profile)
			_finish())


func _boot_product() -> bool:
	before_files = _fingerprints()
	if DisplayServer.get_name() == "headless":
		_check(false, "rendered_perspectives needs actual rendered pixels; headless is not a substitute")
		return false
	output_dir = ProjectSettings.globalize_path("res://../.omx/artifacts/desktop-native/").path_join(profile).simplify_path()
	_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "perspectives artifact directory is writable")
	if not _load_fixtures():
		return false
	test_base = "user://tests/desktop_ui_%d_%d.json" % [Time.get_ticks_usec(), get_instance_id()]
	for pack in Catalog.list_packs(true):
		var id := str(pack.id)
		var path := Catalog.test_slot(test_base, id)
		_check(not path.is_empty() and path.begins_with("user://tests/"), "catalog creates an isolated test slot: " + id)
		_check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "test slot does not overwrite existing bytes: " + id)
		if path.is_empty() or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			return false
		pack_slots[id] = path
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/full_game.tscn") as PackedScene
	_check(scene != null, "actual three-perspective product scene exists")
	if scene == null:
		return false
	full = scene.instantiate()
	if not _require_fields(full, ["save_slot_path", "room", "audio"]):
		full.free()
		return false
	full.set("save_slot_path", test_base)
	root.add_child(full)
	current_scene = full
	await _frames(10)
	room = full.get("room")
	if room == null or not _require_fields(room, ["campaign_buttons", "support_picker", "campaign_slots", "selected_pack_id", "desktop", "menu", "menu_box", "settings_path"]):
		_check(false, "real campaign-aware room booted")
		return false
	_check(room.get("campaign_slots") == pack_slots, "all five slot overrides arrive before any desktop exists")
	if room.get("campaign_slots") != pack_slots:
		return false
	preferences_path = test_base.get_basename() + "_preferences.json"
	_check(room.settings_path == preferences_path and room.settings_store.get("_path") == preferences_path,
		"actual settings store is isolated before any UI preference action")
	if room.settings_path != preferences_path or room.settings_store.get("_path") != preferences_path:
		return false
	_check(room.get("selected_pack_id") == "intruder" and room.get("desktop") == null, "public default is intruder without an implicit session")
	_check(full.get("audio").get("current_mood") == "home", "menu uses home music")
	var probe := Campaign.new(pack_slots["legacy_intruder"], "legacy_intruder")
	legacy_source_probe = probe.get_save_status(false)
	_check(not legacy_source_probe.get("legacy_sources_checked", true) and not legacy_source_probe.get("legacy_available", true)
		and not legacy_source_probe.get("legacy_source_available", true), "test override performs an actual false legacy-source probe")
	_check(not room.get("legacy_continue_button").visible, "empty test legacy slot does not expose real old-save continuation")
	return true


func _run() -> void:
	if not (await _boot_product()):
		_finish()
		return
	await _capture("menu-selector.png")
	await _settings_cancel()
	for id in PACK_IDS:
		if not (await _select_pack(id)) or not (await _start_new_pack(id)):
			_finish()
			return
		await _view_first_forms()
		await _capture("opening.png")
		if id == "intruder":
			await _common_input_checks()
			await _request_lab_checks()
		if profile == "ci-render-smoke":
			if id == "intruder":
				if not (await _replay_case("M01")):
					_finish()
					return
				await _room_resume_checks()
				await _locale_audio_checks()
				_checkpoint_pack()
		else:
			if not (await _replay_pack()):
				_finish()
				return
			await _choose_pack_ending()
			_checkpoint_pack()
		await _check_other_pack_isolation()
	for id in PACK_IDS:
		if not (await _select_pack(id)):
			_finish()
			return
		if pack_snapshots.has(id):
			await _continue_pack(id)
			_check(desktop.game.export_snapshot() == pack_snapshots[id], "cached pack reentry retains its own canonical ending/progress: " + id)
			if profile == "full":
				await _load_pack_from_ui()
	if profile == "full":
		var original_cases := campaign_cases.filter(func(row: Dictionary): return row.pack_id in ORIGINAL_PACK_IDS)
		var challenge_cases := campaign_cases.filter(func(row: Dictionary): return row.pack_id == "challenge")
		var original_endings := pack_endings.filter(func(row: Dictionary): return row.pack_id in ORIGINAL_PACK_IDS)
		var challenge_endings := pack_endings.filter(func(row: Dictionary): return row.pack_id == "challenge")
		_check(original_cases.size() == 44 and original_endings.size() == 3, "preserved original44 cases and three endings actually replay")
		_check(challenge_cases.size() == 3 and challenge_endings.size() == 1, "new challenge3 cases and one ending actually replay")
		_check(campaign_cases.size() == 47 and pack_endings.size() == 4, "aggregate47 cases and four endings reconcile")
		for kind in STRUCTURED:
			_check(typed_runs.any(func(row: Dictionary): return row.kind == kind), "real basic form executed for model kind: " + kind)
	else:
		_check(campaign_cases.size() == 1 and campaign_cases[0].pack_id == "intruder" and campaign_cases[0].mission_id == "M01",
			"smoke reports exactly one actually completed case out of47")
		_check(pack_endings.is_empty(), "smoke does not claim ending GUI validation")
	_finish()


func _load_fixtures() -> bool:
	var path := "res://tests/fixtures/perspectives_solutions.json"
	_check(FileAccess.file_exists(path), "perspective fixtures have actually been authored")
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary and parsed.get("packs", {}) is Dictionary, "perspective fixture schema parses")
	if not parsed is Dictionary or not parsed.get("packs", {}) is Dictionary:
		return false
	fixture_packs = parsed.packs.duplicate(true)
	var challenge_path := "res://tests/fixtures/challenge_solutions.json"
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(challenge_path))
	_check(extra is Dictionary and extra.get("packs") is Dictionary and extra.packs.keys() == ["challenge"], "separate challenge fixture schema is exact")
	if not extra is Dictionary or not extra.get("packs") is Dictionary or extra.packs.keys() != ["challenge"]:
		return false
	for id in extra.packs:
		_check(not fixture_packs.has(id), "fixture merge rejects duplicate pack identity: " + id)
		if fixture_packs.has(id):
			return false
		fixture_packs[id] = extra.packs[id]
	for id in PACK_IDS:
		_check(fixture_packs.has(id) and fixture_packs[id].get("missions", {}).size() == CASE_COUNTS[id], "real fixture inventory matches pack scope: " + id)
		if not fixture_packs.has(id) or fixture_packs[id].get("missions", {}).size() != CASE_COUNTS[id]:
			return false
	return true


func _metadata_button(node: Node, key: String, value: String) -> Button:
	if node is Button and str(node.get_meta(key, "")) == value:
		return node
	for child in node.get_children():
		var found := _metadata_button(child, key, value)
		if found != null:
			return found
	return null


func _settings_cancel() -> void:
	var button := _metadata_button(room.menu_box, "lobby_action", "settings")
	_check(button != null, "real lobby metadata opens settings")
	if button == null:
		return
	var before := _path_fingerprint(preferences_path)
	await _click(button)
	_check(room.settings_panel != null, "native lobby click opens settings")
	var cancel := _metadata_button(room.settings_panel, "settings_action", "cancel")
	_check(cancel != null, "real settings metadata exposes cancel")
	if cancel != null:
		await _click(cancel)
	_check(room.settings_panel == null and _path_fingerprint(preferences_path) == before, "native settings Cancel preserves isolated preferences")


func _menu() -> void:
	if room.get("_in_desktop"):
		await _key(KEY_F10)
	if not room.get("menu").visible:
		await _key(KEY_ESCAPE)
	_check(room.get("menu").visible, "actual F10/Escape reach the campaign menu")
	_check(full.get("audio").get("current_mood") == "home", "room/menu transition selects home cue")
	expected_ending_context = false


func _select_pack(id: String) -> bool:
	await _menu()
	var card: Button = room.campaign_buttons.get(id)
	_check(card != null and str(card.get_meta("scenario_id", "")) == id, "actual scenario card exposes canonical id: " + id)
	if card == null:
		return false
	await _focus_and_click(card)
	_check(room.selected_pack_id == id and card.button_pressed, "actual card input selects scenario: " + id)
	if room.selected_pack_id != id:
		return false
	if not selected_packs.has(id):
		selected_packs.append(id)
	return true


func _accept_option(control: OptionButton, value: Variant, label: String) -> bool:
	var index := -1
	for item in range(control.item_count):
		if _enum_value_matches(control.get_item_metadata(item), value):
			index = item
	_check(index >= 0, "public option metadata is available: " + label)
	if index < 0:
		return false
	control.grab_focus()
	await _key(KEY_SPACE)
	var popup := control.get_popup()
	_check(popup.visible, "actual keyboard opens option popup: " + label)
	if not popup.visible:
		return false
	# Canonical row highlight is setup; embedder Enter performs actual acceptance.
	popup.set_focused_item(index)
	var accepted: Array[int] = []
	popup.id_pressed.connect(func(value_id: int): accepted.append(value_id), CONNECT_ONE_SHOT)
	await _key(KEY_ENTER)
	_check(accepted == [index], "actual Enter accepts option once: " + label)
	return accepted == [index]


func _start_new_pack(id: String) -> bool:
	var button := _metadata_button(room.menu_box, "lobby_action", "new")
	_check(button != null, "selected pack has a real New Game action")
	if button == null:
		return false
	await _click(button)
	_check(room.get("confirm").visible, "selected pack New Game opens confirmation")
	await _confirm_dialog(room.get("confirm"))
	await _frames(4)
	return _attach_desktop(id)


func _continue_pack(id: String) -> bool:
	_check(not room.get("continue_button").disabled, "selected cached/saved pack enables Continue: " + id)
	await _click(room.get("continue_button"))
	await _frames(3)
	return _attach_desktop(id)


func _attach_desktop(id: String) -> bool:
	desktop = room.get("desktop")
	_check(desktop != null, "pack starts its actual desktop: " + id)
	if desktop == null or not _require_fields(desktop, ["game", "pack_id", "save_slot_path", "terms", "tool_inputs"]):
		return false
	active_pack = id
	slot = str(pack_slots[id])
	_check(desktop.get("pack_id") == id and desktop.get("save_slot_path") == slot, "desktop owns the exact injected pack slot: " + id)
	if desktop.get("pack_id") != id or desktop.get("save_slot_path") != slot:
		return false
	_check(desktop.game.get("_save_path") == slot and desktop.game.get("_pack_id") == id, "authoritative game owns the same pack/test slot: " + id)
	var view: Dictionary = desktop.get_game_view()
	_check(view.get("ready", false) and view.get("campaign", {}).get("id") == id, "actual campaign view is ready and identifies its pack: " + id)
	if not view.get("ready", false):
		return false
	if not pack_desktops.has(id):
		pack_desktops[id] = desktop
		desktop.action_performed.connect(func(result: Dictionary): action_result = result.duplicate(true))
	else:
		_check(pack_desktops[id] == desktop, "pack reuses its exact cached desktop instance: " + id)
	# Reentry preserves historical ending data without explicitly reopening credits.
	expected_ending_context = false
	_assert_mood(view, "opened " + id)
	return true


func _common_input_checks() -> void:
	_check(desktop.terms.size() == 4, "all four real terminal controls exist")
	for index in range(4):
		var result := await _submit("pwd", index)
		_check(result.get("ok", false), "actual native Enter executes terminal %d" % index)
		desktop.terms[index]["input"].text = "pack-draft-%d" % index
	await _open_terminal(0)
	var input: LineEdit = desktop.terms[0]["input"]
	await _key(KEY_UP)
	_check(input.text == "pack-draft-0" and desktop.terms[0]["hist_idx"] == -1, "native Up preserves a draft without a matching command")
	input.clear()
	await _key(KEY_UP)
	_check(input.text == "pwd", "native Up recalls this terminal's real command history")
	await _key(KEY_DOWN)
	_check(input.text.is_empty(), "native Down restores the empty unfiltered draft")
	input.text = "pack-draft-0"
	var old_size: int = desktop.ui_size
	await _click(desktop.font_down_btn)
	_check(desktop.ui_size == old_size - 1, "actual held mouse click activates font decrease")
	var larger: Button = desktop.font_up_btn
	_check(larger != null, "actual font increase control exists")
	if larger != null:
		await _click(larger)
	_check(desktop.ui_size == old_size and input.text == "pack-draft-0", "font click pair restores size and preserves command draft")
	_check(root.gui_get_focus_owner() == input, "toolbar mouse completion restores terminal focus after activation")
	input.clear()
	input.grab_focus()
	await _key(KEY_NONE, false, false, "한".unicode_at(0))
	_check(input.text == "한", "actual Unicode InputEvent commits CJK text without a fake IME-composition flag")
	await _open_app("mail")
	_check(input.text == "한", "native app shortcut preserves committed CJK draft")
	await _key(KEY_3, true, false, 0, true)
	_check(desktop.active_id == "mail", "echo input cannot repeat an app shortcut")
	_check(FileAccess.get_file_as_string("res://scripts/apps/campaign_desktop.gd").contains("has_ime_text()"),
		"source retains platform IME guard; physical composition remains NOT_RUN")
	await _key(KEY_F6)
	_check(root.gui_get_focus_owner() == desktop.launcher_button, "F6 reaches persistent launcher")
	await _key(KEY_F6, false, true)
	_check(root.gui_get_focus_owner() == desktop.font_down_btn, "Shift F6 reaches font control")
	await _open_terminal(1)
	var before: Dictionary = desktop.game.export_snapshot()
	var retained: LineEdit = desktop.terms[1]["input"]
	var close: Button = desktop.wins["term1"]["actions"]["close"]
	_check(close != null, "terminal has a real close action")
	if close != null:
		await _click(close)
		await _open_terminal(1)
		_check(desktop.terms[1]["input"] == retained and retained.text == "pack-draft-1", "close/reopen preserves the terminal object and draft")
		_check(desktop.game.export_snapshot() == before, "closing a terminal never logs out/replaces world state")
	await _open_terminal(0)
	input.clear()


func _use_tool(id: String, params: Dictionary) -> Dictionary:
	await _open_terminal(int(params.get("terminal_id", 0)))
	var kind := ""
	for row in desktop.get_game_view().get("tools", []):
		if row.get("id") == id:
			kind = str(row.get("kind", ""))
	if not kind in STRUCTURED:
		return await super._use_tool(id, params)
	if not (await _select_tool(id)):
		return {"ok": false, "code": "UI_TOOL_NOT_LISTED"}
	var values: Variant = params.get("input", params)
	_check(values is Dictionary and values.has("action"), "structured fixture supplies its public action and fields")
	if not values is Dictionary or not values.has("action"):
		return {"ok": false, "code": "STRUCTURED_FIXTURE_INVALID"}
	if not (await _fill_basic_form(values)):
		return {"ok": false, "code": "STRUCTURED_FORM_UNAVAILABLE"}
	var result := await _run_selected_tool()
	typed_runs.append({"pack_id": active_pack, "mission_id": desktop.get_game_view().get("mission_id", ""),
		"tool_id": id, "kind": kind, "action": values.action, "field_setup": "typed widget API; action OptionButton change signal",
		"execution": "native mouse press/held frame/return motion/release on real Run", "code": result.get("code", "")})
	return result


func _fixture_action(action: Dictionary) -> Dictionary:
	if str(action.get("kind", "")) in ["browse", "request", "collect_web"]:
		await _open_terminal(int(action.get("terminal_id", 0)))
	return await super._fixture_action(action)


func _open_app(id: String) -> void:
	await super._open_app(id)
	expected_ending_context = id == "ending"


func _open_terminal(index: int) -> void:
	await super._open_terminal(index)
	expected_ending_context = false


func _fill_basic_form(values: Dictionary) -> bool:
	var action: OptionButton = desktop.tool_inputs.get("action")
	var action_found: bool = action != null and _select_option(action, values.action)
	_check(action_found, "public action metadata is available")
	if not action_found:
		return false
	action.item_selected.emit(action.selected)
	await _frames(2)
	for key in desktop.tool_inputs:
		if key == "action":
			continue
		var control = desktop.tool_inputs[key]
		if control is LineEdit:
			control.clear()
		elif control is CheckBox:
			control.button_pressed = false
		elif control is SpinBox:
			control.value = control.min_value
		elif control is OptionButton:
			control.select(0)
		elif control is ItemList:
			control.deselect_all()
	var leaves := _flatten_fields(values)
	for key in leaves:
		if key == "action":
			continue
		var control = desktop.tool_inputs.get(key)
		_check(is_instance_valid(control), "public typed field exists: " + key)
		if not is_instance_valid(control):
			return false
		var value: Variant = leaves[key]
		if control is OptionButton:
			var found: bool = _select_option(control, value)
			_check(found, "enum metadata represents canonical value: " + key)
			if not found:
				return false
		elif control is CheckBox:
			control.button_pressed = bool(value)
		elif control is SpinBox:
			control.value = float(value)
			_check(is_equal_approx(control.value, float(value)), "integer field does not clamp fixture value: " + key)
		elif control is LineEdit:
			control.text = str(value)
		elif control is ItemList:
			control.deselect_all()
			_check(control.select_mode == ItemList.SELECT_MULTI, "array field is an actual multi-selection widget: " + key)
			_check(value is Array, "multi-value field receives an array: " + key)
			if not value is Array:
				return false
			for requested in value:
				var found := false
				for index in range(control.item_count):
					if _enum_value_matches(control.get_item_metadata(index), requested):
						control.select(index, false)
						found = true
				_check(found, "multi-value metadata contains requested canonical id: " + key)
				if not found:
					return false
		else:
			_check(false, "unsupported real typed widget: " + key)
			return false
	var collected := _flatten_fields(desktop._tool_params())
	for key in leaves:
		var matches: bool = collected.has(key)
		if matches and leaves[key] is Array:
			var expected_values: Array = leaves[key].duplicate()
			var actual_values: Array = collected[key].duplicate()
			expected_values.sort()
			actual_values.sort()
			matches = expected_values == actual_values
		elif matches:
			matches = collected[key] == leaves[key]
		_check(matches, "typed form serializes the canonical fixture field: " + key)
		if not matches:
			return false
	return true


func _enum_value_matches(actual: Variant, expected: Variant) -> bool:
	# Registered controls can expose arrays, strings and booleans in one enum.
	if typeof(actual) != typeof(expected) and not (typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]):
		return false
	return actual == expected


func _select_option(control: OptionButton, value: Variant) -> bool:
	for index in range(control.item_count):
		if _enum_value_matches(control.get_item_metadata(index), value):
			control.select(index)
			return true
	return false


func _flatten_fields(values: Dictionary, prefix := "") -> Dictionary:
	var result := {}
	for key in values:
		var path := str(key) if prefix.is_empty() else prefix + "." + str(key)
		if values[key] is Dictionary:
			result.merge(_flatten_fields(values[key], path))
		else:
			result[path] = values[key]
	return result


func _view_first_forms() -> void:
	var seen: Array[String] = []
	for row in desktop.get_game_view().get("tools", []):
		var kind := str(row.get("kind", ""))
		if not kind in STRUCTURED or seen.has(kind):
			continue
		seen.append(kind)
		if not (await _select_tool(str(row.id))):
			continue
		var actions: OptionButton = desktop.tool_inputs.get("action")
		_check(actions != null and actions.item_count > 0, "real first-case model exposes public basic-form actions: " + kind)
		if actions == null:
			continue
		# Representative public forms are stable even when another action is inserted before them.
		var action_id := str({"response_lab": "set_control", "observation_case": "collect"}.get(kind, ""))
		if action_id.is_empty():
			for action in row.get("actions", []):
				if not action.get("fields", []).is_empty():
					action_id = str(action.id)
					break
		var selected := not action_id.is_empty() and _select_option(actions, action_id)
		_check(selected, "first-case model has its representative public basic form: " + kind + "/" + action_id)
		if not selected:
			continue
		actions.item_selected.emit(actions.selected)
		await _frames(2)
		var fields := {}
		for key in desktop.tool_inputs:
			fields[key] = desktop.tool_inputs[key].get_class()
		form_views.append({"pack_id": active_pack, "mission_id": desktop.get_game_view().get("mission_id", ""),
			"tool_id": row.id, "kind": kind, "action": action_id, "typed_widgets": fields, "model_run": false})
		# The real app scroll follows focus; expose the form/Run region for its screenshot.
		desktop.tool_run_btn.grab_focus()
		await _frames(3)
		await _capture("first-form-%s.png" % kind)
	if profile == "ci-render-smoke" and active_pack in ["defender", "tracker", "challenge"]:
		_check(not seen.is_empty(), "new public perspective has a real first-case basic form: " + active_pack)


func _replay_pack() -> bool:
	var mains: Array[String] = []
	var optional: Array[String] = []
	for mission in desktop.get_game_view().get("missions", []):
		if mission.get("optional", false):
			optional.append(str(mission.id))
		else:
			mains.append(str(mission.id))
	_check(mains.size() + optional.size() == CASE_COUNTS[active_pack], "actual board inventory matches pack scope: " + active_pack)
	if mains.size() + optional.size() != CASE_COUNTS[active_pack]:
		return false
	for index in range(mains.size()):
		var id := mains[index]
		_check(desktop.get_game_view().get("mission_id") == id, "real Next navigation reaches " + active_pack + "/" + id)
		if desktop.get_game_view().get("mission_id") != id or not (await _replay_case(id)):
			return false
		if index == 0:
			await _room_resume_checks()
			await _locale_audio_checks()
		if index in [0, mains.size() / 2, mains.size() - 1]:
			await _capture("%s-complete.png" % id)
		if index + 1 < mains.size():
			await _open_app("board")
			_check(desktop.bd_next_btn.visible and not desktop.bd_next_btn.disabled, "real completed case exposes Next: " + id)
			await _focus_and_click(desktop.bd_next_btn)
			await _frames(2)
			await _mail_matches_current()
			_assert_mood(desktop.get_game_view(), "new " + mains[index + 1])
	for id in optional:
		if not (await _select_case(id)) or not (await _replay_case(id)):
			return false
	if desktop.get_game_view().get("mission_id") != mains.back():
		return await _select_case(mains.back())
	return true


func _replay_case(id: String) -> bool:
	var definition: Dictionary = fixture_packs[active_pack].missions.get(id, {})
	var paths: Array = definition.get("paths", [])
	_check(not paths.is_empty() and not paths[0].get("actions", []).is_empty(), "authored A route has actual actions: " + active_pack + "/" + id)
	if paths.is_empty() or paths[0].get("actions", []).is_empty():
		return false
	var route: Dictionary = paths[0]
	var count := 0
	for action in route.actions:
		if finished:
			return false
		var before: Dictionary = desktop.game.export_snapshot()
		var disk_before := _path_fingerprint(slot)
		if not manual_save_checked.get(active_pack, false):
			desktop.autosave_suspended = true
		var terminal := int(action.get("terminal_id", 0))
		if str(action.get("kind", "")) == "password":
			_check(desktop.terms[terminal]["input"].secret and desktop.game.get_view(terminal).get("password_pending", false), "actual password submission is masked")
		var result: Dictionary = await _fixture_action(action)
		if finished:
			return false
		native_actions += 1
		var expected: Dictionary = action.get("expect", {"ok": true})
		for field in expected:
			_check(result.get(field) == expected[field], "%s/%s A-step%d expected %s=%s got %s (%s)" %
				[active_pack, id, count, field, str(expected[field]), str(result.get(field)), str(result.get("code", "missing"))])
			if result.get(field) != expected[field]:
				return false
		var after: Dictionary = desktop.game.export_snapshot()
		if not manual_save_checked.get(active_pack, false) and after != before:
			_check(_path_fingerprint(slot) == disk_before, "suspended test autosave leaves this pack's real dirty state unsaved")
			await _click(desktop.save_btn)
			_check(not desktop.autosave_suspended and _path_fingerprint(slot) != disk_before, "actual Save click commits dirty state and resumes saving: " + active_pack)
			var probe := Campaign.new(slot, active_pack)
			var loaded: Dictionary = probe.load_game()
			_check(loaded.get("ok", false) and probe.export_snapshot() == after, "manual pack save round-trips actual domain state")
			manual_save_checked[active_pack] = true
		if str(action.get("kind", "")) == "password":
			password_actions += 1
			_check(not desktop.terms[terminal]["history"].has(str(action.value)), "submitted password stays out of this terminal's history")
		if not auth_cancel_checked and str(action.get("kind", "")) == "command" and desktop.game.get_view(terminal).get("password_pending", false):
			await _check_auth_cancel(action, terminal)
			if finished:
				return false
		count += 1
	var view: Dictionary = desktop.get_game_view()
	_check(view.get("completed", false), "real A actions complete all current goals/constraints: " + active_pack + "/" + id)
	if not view.get("completed", false):
		return false
	for fact in route.get("expected", {}).get("facts", []):
		_check(view.get("facts", []).has(fact), "real route establishes required fact: " + str(fact))
	await _open_app("board")
	_check(not str(view.get("mission_goal", "")).is_empty() and desktop.bd_goal.text.contains(str(view.mission_goal)), "actual case goal appears in board")
	_check(not view.get("objectives", []).is_empty() and desktop.bd_objectives.get_child_count() == view.objectives.size(), "board renders authoritative objectives")
	await _mail_matches_current()
	_assert_mood(view, "completed " + active_pack + "/" + id)
	campaign_cases.append({"pack_id": active_pack, "mission_id": id, "route_id": route.get("id", ""),
		"actions": count, "completed": bool(view.get("completed", false)), "alert_level": view.get("alert_level", 0), "archive_records": view.get("archive", []).size()})
	return true


func _check_auth_cancel(action: Dictionary, terminal: int) -> void:
	var input: LineEdit = desktop.terms[terminal]["input"]
	var snapshot: Dictionary = desktop.game.export_snapshot()
	input.text = "unsubmitted-perspectives-canary"
	var exit := _button_text(desktop.wins["term%d" % terminal]["win"], desktop._t("UI_TERM_EXIT"))
	_check(exit != null, "actual Exit control can cancel pending authentication")
	if exit != null:
		await _focus_and_click(exit)
	_check(input.text.is_empty() and not input.secret and not desktop.game.get_view(terminal).get("password_pending", true), "native Exit clears unsubmitted secret before unmasking")
	_check(int(desktop.terms[terminal]["hist_idx"]) == -1 and str(desktop.terms[terminal]["draft"]).is_empty(), "Exit resets password-mode history cursor and draft")
	_check(not desktop.terms[terminal]["history"].has("unsubmitted-perspectives-canary"), "unsubmitted secret never reaches command history")
	_check(not desktop.terms[terminal]["out"].get_parsed_text().contains("unsubmitted-perspectives-canary"), "unsubmitted secret never reaches terminal output")
	_check(desktop.game.export_snapshot() == snapshot, "authentication cancellation preserves canonical world")
	await _fixture_action(action)
	input.grab_focus()
	await _key(KEY_ESCAPE)
	_check(not input.secret and not desktop.game.get_view(terminal).get("password_pending", true) and not desktop.paused, "native focused Escape cancels auth without pause")
	await _fixture_action(action)
	auth_cancel_checked = true


func _room_resume_checks() -> void:
	await _open_terminal(0)
	var input: LineEdit = desktop.terms[0]["input"]
	input.text = active_pack + "-room-draft"
	var same := desktop
	var snapshot: Dictionary = desktop.game.export_snapshot()
	var focus_before := str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "NONE"
	await _key(KEY_F10)
	_check(not room.get("_in_desktop") and not same.visible, "native F10 returns to 3D room")
	_check(room.get("studio").visible and room.get("camera").current, "real 3D studio/camera are restored")
	_check(full.get("audio").get("current_mood") == "home", "room return has home music")
	await _capture("room-return.png")
	await _key(KEY_ESCAPE)
	await _continue_pack(active_pack)
	_check(desktop == same and desktop.game.export_snapshot() == snapshot and input.text == active_pack + "-room-draft", "same pack room round-trip preserves world/desktop/draft")
	var focus_after := str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "NONE"
	print("ROOM_FOCUS ", JSON.stringify({"before": focus_before, "after": focus_after, "active_id": desktop.active_id,
		"expected": str(input.get_path()), "same_input": root.gui_get_focus_owner() == input}))
	_check(root.gui_get_focus_owner() == input, "room reentry restores exact input focus")
	_assert_mood(desktop.get_game_view(), "same pack room resume")


func _choose_pack_ending() -> void:
	await _open_app("board")
	_check(desktop.bd_ending_btn.visible, "actual pack completion exposes ending screen")
	await _focus_and_click(desktop.bd_ending_btn)
	var choice: Button
	for child in desktop.en_choices.get_children():
		if child is Button and not child.disabled:
			choice = child
			break
	_check(choice != null, "actual pack facts allow an ending")
	if choice == null:
		return
	await _focus_and_click(choice)
	_check(desktop.confirm.visible, "native ending click opens confirmation")
	await _confirm_dialog(desktop.confirm)
	await _frames(2)
	var ending: Dictionary = desktop.get_game_view().get("ending", {})
	_check(not ending.is_empty() and desktop.en_chosen_title.text == str(ending.get("title", "")), "actual selected pack ending/title are displayed")
	if ending.is_empty():
		return
	_check(desktop.active_id == "ending", "actual ending choice presents foreground credits")
	expected_ending_context = true
	_check(desktop.en_chosen_text.text == str(ending.get("text", "")) and desktop.en_credits.visible, "pack narrative outcome and credits are displayed")
	_assert_mood(desktop.get_game_view(), "chosen " + active_pack + " ending")
	var player: AudioStreamPlayer = full.get("audio").get("_music")[full.get("audio").get("_active")]
	_check(not player.stream.loop, "actual ending UI selects the one-shot soundtrack edit")
	pack_endings.append({"pack_id": active_pack, "ending_id": ending.get("id", ""), "chosen_from_real_facts": not ending.is_empty()})
	await _capture("ending-credits.png")
	await _click(desktop.save_btn)
	var probe := Campaign.new(slot, active_pack)
	var loaded: Dictionary = probe.load_game()
	_check(loaded.get("ok", false) and probe.get_view().get("ending", {}).get("id") == ending.get("id"), "selected ending survives this pack's isolated disk load")


func _checkpoint_pack() -> void:
	pack_snapshots[active_pack] = desktop.game.export_snapshot()
	pack_disk_hashes[active_pack] = _path_fingerprint(slot)


func _check_other_pack_isolation() -> void:
	var mood: String = full.get("audio").get("current_mood")
	for id in pack_snapshots:
		if id == active_pack:
			continue
		var cached: Control = room.call("get_cached_desktop", id)
		_check(cached != null and not cached.visible and cached.process_mode == Node.PROCESS_MODE_DISABLED, "inactive pack desktop is hidden and disabled: " + str(id))
		_check(cached.game.export_snapshot() == pack_snapshots[id] and _path_fingerprint(pack_slots[id]) == pack_disk_hashes[id], "another pack cannot mutate cached/disk progress: " + str(id))
		cached._refresh_all()
		_check(full.get("audio").get("current_mood") == mood and room.get("desktop") == desktop, "inactive real view signal cannot override foreground audio or desktop")


func _load_pack_from_ui() -> void:
	var expected: Dictionary = pack_snapshots[active_pack]
	await _click(desktop.load_btn)
	_check(desktop.confirm.visible, "real pack Load action opens confirmation")
	await _confirm_dialog(desktop.confirm)
	await _frames(3)
	_check(desktop.get("pack_id") == active_pack and desktop.game.export_snapshot() == expected, "actual Load restores exactly this pack's saved ending/state")
	expected_ending_context = false
	_assert_mood(desktop.get_game_view(), "loaded historical ending " + active_pack)


func _assert_mood(view: Dictionary, label: String) -> void:
	var expected := "investigate"
	var mission := str(view.get("mission_id", ""))
	if expected_ending_context and not view.get("ending", {}).is_empty():
		expected = "ending"
	elif int(view.get("alert_level", 0)) > 0:
		expected = "alert"
	elif view.get("completed", false):
		expected = "flow"
	elif mission in ["M01", "M02", "D01", "T01"]:
		expected = "intro"
	elif mission in ["M12", "M16", "M20", "M24", "D04", "D07", "D08", "T04", "T07", "T08"]:
		expected = "reveal"
	elif mission in ["M05", "M06", "M07", "M08", "M13", "M14", "M15", "D02", "D03", "D05", "D06", "T03", "T05"]:
		expected = "flow"
	_check(full.get("audio").get("current_mood") == expected, "actual pack mood priority: " + label + " → " + expected)


func _capture(filename: String) -> void:
	await super._capture((active_pack + "-" if not active_pack.is_empty() else "") + filename)


func _fingerprints() -> Dictionary:
	var result := super._fingerprints()
	var paths: Array[String] = ["user://settings.json", Catalog.LEGACY_SOURCE, "user://saves/slot_01.json"]
	for pack in Catalog.list_packs(true):
		var path := Catalog.default_slot(str(pack.id))
		if not paths.has(path):
			paths.append(path)
	for path in paths:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			result[path + suffix] = _path_fingerprint(path + suffix)
	for folder in ["user://saves", "user://progress"]:
		_fingerprint_tree(folder, result)
	var directory := DirAccess.open("user://")
	if directory != null:
		for filename in directory.get_files():
			if ".json" in filename:
				result["user://" + filename] = "SYMLINK" if directory.is_link(filename) else _path_fingerprint("user://" + filename)
	return result


func _fingerprint_tree(path: String, result: Dictionary) -> void:
	result[path] = _path_fingerprint(path)
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		var child := path.path_join(filename)
		result[child] = "SYMLINK" if directory.is_link(filename) else _path_fingerprint(child)
	for name in directory.get_directories():
		var child := path.path_join(name)
		if directory.is_link(name):
			result[child] = "SYMLINK"
		else:
			_fingerprint_tree(child, result)


func _render_suite() -> String:
	return "rendered_perspectives"


func _render_ui_observations() -> Array:
	return []


func _render_expected_scope() -> Dictionary:
	return {"packs_selected": 4, "cases": 1 if profile == "ci-render-smoke" else 47,
		"original_cases": 1 if profile == "ci-render-smoke" else 44, "challenge_cases": 0 if profile == "ci-render-smoke" else 3,
		"endings": 0 if profile == "ci-render-smoke" else 4,
		"case_counts": {"intruder": 1, "defender": 0, "tracker": 0, "challenge": 0} if profile == "ci-render-smoke" else CASE_COUNTS,
		"locales": Localization.LOCALES}


func _path_fingerprint(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_sha256(path)
	return "DIRECTORY" if DirAccess.dir_exists_absolute(path) else "MISSING"


func _cleanup_and_report() -> void:
	# Same proven stop/free/frame order as base; its report is coupled to the old 28-case suite.
	if is_instance_valid(full):
		full.set_process_input(false)
		full.process_mode = Node.PROCESS_MODE_DISABLED
		var players := full.find_children("*", "AudioStreamPlayer", true, false)
		for player in players:
			player.stop()
		for index in range(3):
			await process_frame
		for player in players:
			if is_instance_valid(player):
				player.stream = null
		current_scene = null
		full.queue_free()
		full = null
		room = null
		desktop = null
		pack_desktops.clear()
		for index in range(4):
			await process_frame
		await create_timer(.2).timeout
	var protected_after := _fingerprints()
	var protected_unchanged: bool = protected_after == before_files
	_check(protected_unchanged, "all default slots/backups/preferences bytes remain unchanged")
	if profile == "full" and (campaign_cases.size() < 47 or pack_endings.size() < 4):
		not_run.append("Full replay stopped with %d/47 case completions and %d/4 ending screens; remaining %d case solutions and %d endings are GUI NOT_RUN." %
			[campaign_cases.size(), pack_endings.size(), 47 - campaign_cases.size(), 4 - pack_endings.size()])
	var status := "pass" if failures.is_empty() else ("partial_failure" if not campaign_cases.is_empty() else "failed")
	print(JSON.stringify({"suite": _render_suite(), "interface_revision": "challenge-workbench", "profile": profile, "status": status, "checks": checks, "failures": failures,
		"expected_scope": _render_expected_scope(), "selected_packs": selected_packs, "ui_observations": _render_ui_observations(),
		"actual_case_count": campaign_cases.size(), "actual_ending_count": pack_endings.size(),
		"original_case_count": campaign_cases.filter(func(row: Dictionary): return row.pack_id in ORIGINAL_PACK_IDS).size(),
		"challenge_case_count": campaign_cases.filter(func(row: Dictionary): return row.pack_id == "challenge").size(),
		"campaign_cases": campaign_cases, "pack_endings": pack_endings, "typed_basic_runs": typed_runs, "first_case_form_views": form_views,
		"native_fixture_actions": native_actions, "password_actions": password_actions,
		"setup_api_scope": "Text/number/bool/enum/array assignment, ItemList/Tree selection, action-change signals and isolated test preference IO are setup. Run, save, picker accept, confirmation and lifecycle use actual InputEvents.",
		"capture_dir": output_dir, "captures": captures, "capture_metrics": capture_metrics,
		"test_preferences_path": preferences_path, "test_slot_base": test_base, "pack_test_slots": pack_slots, "legacy_source_probe": legacy_source_probe,
		"protected_file_count": before_files.size(), "protected_files_unchanged": protected_unchanged,
		"elapsed_seconds": float(Time.get_ticks_msec() - started_ms) / 1000.0,
		"not_run": not_run, "limit": "Actual source scenes and GPU readback with injected engine input. OS cursor/window/physical IME/hearing and alternate GUI solutions are separate."}))
	quit.call_deferred(0 if failures.is_empty() else 1)
