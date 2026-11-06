extends "res://tools/capture_perspectives.gd"

var life_observations: Array = []
const QA_OUTPUT := "res://../.omx/artifacts/claude-rereview-20261106/native"
func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	profile = "optional-life"
	not_run.append("Camera approach positions and text/option selection are setup; actual E, buttons and tool Run use InputEvents. Physical OS/IME and main47 full replay are separate.")
	_run.call_deferred()
	create_timer(300).timeout.connect(func():
		if not finished:
			failures.append("optional-life capture exceeded300s")
			_finish())

func _render_suite() -> String:
	return "rendered_optional_life"

func _render_ui_observations() -> Array:
	return life_observations

func _render_expected_scope() -> Dictionary:
	return {"main_choices":4, "main_case_solutions":0, "optional_cases":2, "optional_route_witnesses":2, "endings":0, "household":"order/pickup/equip/outdoor job/rest", "camera_approaches":"explicit setup; actual E/buttons/Run"}

func _run() -> void:
	if not (await _boot_product()):
		_finish(); return
	output_dir = ProjectSettings.globalize_path(QA_OUTPUT).simplify_path()
	_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "optional life QA output is writable")
	_check(room.habitat_path.begins_with("user://tests/"), "household path isolated before Room ready")
	_check(not FileAccess.file_exists(room.habitat_path), "native boot creates no real or test household save implicitly")
	await _capture("main-four-choices.png")
	if not (await _select_pack("intruder")) or not (await _start_new_pack("intruder")):
		_finish(); return
	var main = desktop
	var main_before: Dictionary = main.game.export_snapshot()
	await _open_app("board")
	await _click(desktop.commission_entry_button)
	await _capture("optional-chooser.png")
	var start := _metadata_button(desktop.commission_list, "commission_id", "I02")
	_check(start != null, "I02 optional card is directly selectable")
	if start == null: _finish(); return
	await _scroll_click(start); await _frames(5)
	if not _attach_desktop("investigation"):
		_finish(); return
	_check(desktop.pack_id == "investigation" and desktop.game.get_view().mission_id == "I02", "actual card starts independentI02")
	await _optional_computer_resume()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/investigation_solutions.json"))
	var route: Dictionary = fixture.packs.investigation.missions.I02.paths[1]
	for action in route.actions:
		var result: Dictionary = await _fixture_action(action)
		_check(result.get("ok", false), "actual optional action: " + str(action.get("kind")) + "/" + str(result.get("code")))
		if not result.get("ok", false): _finish(); return
	await _capture("release-report-followup.png")
	_check(desktop.game.get_view().completed, "actual typedrelease/report/followup completes optionalI02")
	if desktop.game.get_view().completed:
		campaign_cases.append({"pack_id":"investigation","mission_id":"I02","completed":true,"route":"B"})
	await _br_open_page()
	await _open_app("board")
	await _click(desktop.commission_return_button); await _frames(4)
	desktop = room.desktop; active_pack = "intruder"
	_check(desktop == main and main.game.export_snapshot() == main_before, "return restores exact untouched main world")
	await _click(desktop.commission_entry_button)
	var iam_start := _metadata_button(desktop.commission_list, "commission_id", "I01")
	_check(iam_start != null, "I01 optional card remains independently selectable afterI02")
	if iam_start == null: _finish(); return
	await _scroll_click(iam_start); await _frames(4)
	if not _attach_desktop("investigation"):
		_finish(); return
	for action in fixture.packs.investigation.missions.I01.paths[1].actions:
		var iam_result: Dictionary = await _fixture_action(action)
		_check(iam_result.get("ok", false), "actual IAM widget/action: " + str(iam_result.get("code")))
		if not iam_result.get("ok", false): _finish(); return
	_check(desktop.game.get_view().completed, "actual IAM alternate role/credential route completes optionalI01")
	if desktop.game.get_view().completed:
		campaign_cases.append({"pack_id":"investigation","mission_id":"I01","completed":true,"route":"B"})
	await _capture("iam-current-proof.png")
	await _iam_stale_reproof(fixture.packs.investigation.missions.I01.paths[1].actions)
	await _open_app("board"); await _click(desktop.commission_return_button); await _frames(4)
	desktop = room.desktop; active_pack = "intruder"
	_check(desktop == main and main.game.export_snapshot() == main_before, "both optional cases leave cached main untouched")
	desktop._open_deskshop(); await _frames(3)
	await _capture("deskshop.png")
	await _product("keyboard_ivory")
	await _product("monitor_dual")
	_check(room.habitat_view().ready_delivery_count == 2, "native purchase stores two ready deliveries")
	await _close_panel()
	await _key(KEY_F10); await _frames(3)
	await _capture("room-starter.png")
	await _world_e("room_exit", Vector3(2.25,1.63,1.88), Vector3(3.6,1.45,1.88))
	_check(room.current_zone == "courtyard", "actual E exits room")
	await _capture("courtyard-overview.png")
	await _world_e("delivery_locker", Vector3(-3.1,1.63,15.9), Vector3(-4.35,1.25,15.9))
	await _click(room.habitat_panel.controls.collect_delivery)
	_check(room.habitat_view().ready_delivery_count == 0, "actual locker button collects deliveries")
	await _capture("locker-collected.png"); await _close_panel()
	await _world_e("noticeboard", Vector3(0,1.63,14.75), Vector3(0,1.55,13.45))
	await _click(room.habitat_panel.controls.accept_job)
	await _capture("optional-physical-job.png"); await _close_panel()
	await _world_e("network_cabinet", Vector3(2.9,1.63,15), Vector3(4.3,1.2,15))
	await _click(room.habitat_panel.controls.inspect_cabinet)
	await _habitat_focus("inspect cabinet")
	var applied_job: Dictionary = room.habitat_view().job.duplicate(true)
	await _accept_option(room.habitat_panel.controls.route, "off", "cabinetrouteoff")
	await _click(room.habitat_panel.controls.locked)
	_check(room.habitat_view().job == applied_job, "route/lock InputEvents preserve applied cabinet state before Apply")
	_check(room.habitat_panel.controls.unapplied_changes.visible and room.habitat_panel.controls.verify_job.disabled,
		"dirty cabinet draft exposes pending label and disables Verify")
	await _capture("cabinet-unapplied-draft.png")
	await _click(room.habitat_panel.controls.configure)
	_check(not room.habitat_panel.controls.unapplied_changes.visible and not room.habitat_panel.controls.verify_job.disabled,
		"actual Apply commits cabinet draft and enables Verify")
	await _habitat_focus("apply off cabinet")
	await _capture("cabinet-applied-draft.png")
	await _click(room.habitat_panel.controls.verify_job)
	await _habitat_focus("verify failed cabinet")
	_check(not room.habitat_view().job.current_check.passed, "all-off cabinet fails normal telemetry")
	await _capture("cabinet-failed.png")
	await _accept_option(room.habitat_panel.controls.route, "approved_relay", "cabinetapprovedroute")
	await _click(room.habitat_panel.controls.configure)
	await _habitat_focus("apply approved relay")
	await _click(room.habitat_panel.controls.verify_job)
	var balance: int = room.habitat_view().balance
	_check(room.habitat_view().job.current_check.passed and room.habitat_view().earned == 200, "actual physicaljob safe route rewards once")
	await _click(room.habitat_panel.controls.verify_job)
	_check(room.habitat_view().balance == balance, "actual repeat verify does not duplicate reward")
	await _capture("cabinet-secured.png"); await _close_panel()
	await _world_e("bench", Vector3(3.6,1.63,18.2), Vector3(3.6,1,19.45))
	_check(room.habitat_panel.controls.set_lighting_night.disabled and not room.habitat_panel.controls.set_lighting_dawn.disabled,
		"bench disables the current night lighting and enables dawn")
	_check(room.habitat_panel.controls.set_lighting == room.habitat_panel.controls.set_lighting_dawn,
		"bench retains the legacy set_lighting dawn alias")
	await _click(room.habitat_panel.controls.set_lighting)
	await _habitat_focus("bench lighting")
	_check(room.habitat_view().lighting == "dawn" and room.habitat_panel.controls.set_lighting_dawn.disabled
		and not room.habitat_panel.controls.set_lighting_night.disabled, "actual dawn button disables current dawn and enables night")
	await _capture("bench-rest.png"); await _close_panel()
	await _world_e("courtyard_enter", Vector3(0,1.63,21), Vector3(0,1.45,22.5))
	_check(room.current_zone == "room", "actual E returns home")
	room.show_habitat("shop"); await _frames(2)
	await _product("keyboard_ivory"); await _product("monitor_dual")
	await _close_panel()
	_check(room.habitat_view().equipped.monitor == "monitor_dual", "actual equip button selects collected monitor")
	await _capture("room-decorated.png")
	_check(main.game.export_snapshot() == main_before, "shopping/outside/decor never changes main world")
	await _large_optional_controls()
	life_observations.append({"optional_cases":["I02","I01"],"typed_runs":typed_runs.size(),"physical_job":room.habitat_view().job.current_check,"equipment":room.habitat_view().equipped,"setup":"Explicit camera approach placements; actual E and UI InputEvents."})
	await _fresh_no_backup(main, main_before)
	_finish()

func _iam_stale_reproof(actions: Array) -> void:
	_check(_iam_current_count() > 0 and not _iam_stale_notice(), "completed IAM displays only current request evidence")
	var advanced: Dictionary = await _use_tool("iv1_i01_iam", {"action":"advance", "ticks":1})
	_check(advanced.get("ok", false), "actual IAM advance widget changes evidence basis by one tick")
	_check(_iam_current_count() == 0 and _iam_stale_notice(), "actual IAM advance exposes stale evidence notice")
	await _capture("iam-stale-after-advance.png")
	var probes := 0
	for action in actions:
		if action.get("kind") != "tool" or action.get("params", {}).get("action") != "probe": continue
		var result: Dictionary = await _fixture_action(action)
		_check(result.get("ok", false), "actual IAM re-probe refreshes request: " + str(action.params.request_id))
		probes += 1
	_check(probes > 0 and _iam_current_count() == probes and not _iam_stale_notice()
		and desktop.game.get_view().completed, "fixture probes alone restore all current IAM evidence and completion")
	life_observations.append({"scenario":"IAM_stale_and_reprobe", "advance_ticks":1, "reprobed_requests":probes,
		"current_requests":_iam_current_count(), "stale_notice_after_reprobe":_iam_stale_notice(), "completed":desktop.game.get_view().completed})
	await _capture("iam-refreshed-proof.png")

func _iam_current_count() -> int:
	var count := 0
	for request in desktop._tool_current().get("data", {}).get("requests", []):
		if request.get("current", false): count += 1
	return count

func _iam_stale_notice() -> bool:
	for control in desktop.tool_obs_box.get_children():
		if control.get_meta("iam_stale_notice", false) and control.is_visible_in_tree(): return true
	return false

func _habitat_focus(label: String) -> void:
	await _frames(4)
	var owner := root.gui_get_focus_owner()
	var retained: bool = is_instance_valid(owner) and room.habitat_panel.is_ancestor_of(owner) and owner.is_visible_in_tree()
	if retained and owner is BaseButton: retained = not owner.disabled
	_check(retained, "household action retains a usable panel focus: " + label)
	life_observations.append({"scenario":"habitat_focus", "action":label, "retained":retained,
		"focus_key":str(owner.get_meta("habitat_focus", "")) if is_instance_valid(owner) else ""})

func _fresh_no_backup(main: Control, main_before: Dictionary) -> void:
	var settings: Dictionary = room.settings_store.get_values()
	var window_size := root.size
	if room._in_desktop:
		await _key(KEY_F10); await _frames(3)
	for locale in ["ko", "de"]:
		var preview := settings.duplicate(true)
		preview.locale = locale
		preview.font_scale = 1.6
		preview.fullscreen = false
		if not _set_test_settings(preview): break
		root.size = Vector2i(1280, 720)
		var path: String = test_base.get_basename() + "_fresh_" + locale + ".json"
		_check(path.begins_with("user://tests/") and not FileAccess.file_exists(path)
			and not FileAccess.file_exists(path + ".bak"), "fresh recovery fixture has a new isolated path without backup: " + locale)
		if not path.begins_with("user://tests/") or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"): return
		var damaged: String = "{damaged isolated habitat / " + locale
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "isolated broken household fixture can be written: " + locale)
		if file == null: return
		file.store_string(damaged)
		file.close()
		room.habitat_path = path
		room.habitat_store = room.habitat_store.get_script().new(path)
		room.habitat_load_result = room.habitat_store.load_state()
		_check(not room.habitat_load_result.ok and not room.habitat_view().ready
			and room.habitat_view().fresh_available and not room.habitat_view().recovery_available,
			"broken no-backup household offers fresh recovery only: " + locale)
		room.show_habitat("shop"); await _frames(5)
		_check(room.habitat_panel.controls.recover.disabled and room.habitat_panel.controls.has("fresh"),
			"read-only panel disables backup recovery and exposes fresh action: " + locale)
		var before := _path_fingerprint(path)
		var state_before: Dictionary = room.habitat_view().duplicate(true)
		await _scroll_click(room.habitat_panel.controls.fresh); await _frames(3)
		_check(room.habitat_panel.fresh.visible and _path_fingerprint(path) == before,
			"actual fresh action opens confirmation before writing: " + locale)
		var dialog: ConfirmationDialog = room.habitat_panel.fresh
		# Embedded dialogs use logical viewport coordinates under the product's stretch transform.
		var viewport_size: Vector2 = room.habitat_panel.get_viewport_rect().size
		_check(dialog.position.x >= 0 and dialog.position.y >= 0 and dialog.position.x + dialog.size.x <= viewport_size.x
			and dialog.position.y + dialog.size.y <= viewport_size.y,
			"large fresh confirmation fits the actual viewport: " + locale)
		await _capture("large-%s-fresh-no-backup-confirm.png" % locale)
		var cancel: Button = dialog.get_cancel_button()
		cancel.grab_focus(); await _frames(1)
		_check(cancel.get_viewport().gui_get_focus_owner() == cancel, "actual fresh Cancel receives dialog keyboard focus: " + locale)
		await _key(KEY_ENTER, false, false, 0, false, cancel.get_viewport()); await _frames(3)
		_check(not dialog.visible, "actual fresh Cancel closes confirmation: " + locale)
		_check(_path_fingerprint(path) == before and room.habitat_view() == state_before,
			"actual fresh Cancel preserves exact damaged bytes and household state: " + locale)
		await _scroll_click(room.habitat_panel.controls.fresh)
		await _confirm_dialog(room.habitat_panel.fresh); await _frames(4)
		var preserved: String = room.habitat_load_result.get("damaged_path", "")
		_check(room.habitat_view().ready and room.habitat_load_result.get("code") == "HABITAT_FRESH"
			and not preserved.is_empty() and FileAccess.get_file_as_string(preserved) == damaged,
			"actual fresh Confirm restores starter room and preserves damaged bytes: " + locale)
		_check(main.game.export_snapshot() == main_before, "fresh household recovery leaves main world unchanged: " + locale)
		life_observations.append({"scenario":"fresh_no_backup", "locale":locale, "path":path,
			"preserved_path":preserved, "damaged_preserved":not preserved.is_empty() and FileAccess.get_file_as_string(preserved) == damaged,
			"ready":room.habitat_view().ready, "main_unchanged":main.game.export_snapshot() == main_before,
			"setup":"Malformed bytes in a new user://tests/ habitat path; isolated store load and shop context setup. Fresh, Cancel, and Confirm use native InputEvents."})
		await _capture("large-%s-fresh-restored.png" % locale)
		await _close_panel()
	root.size = window_size
	_set_test_settings(settings)
	await _frames(4)

func _world_e(id: String, at: Vector3, target: Vector3) -> void:
	# Camera approach is explicit setup; facing gate and actual E input perform interaction.
	room.player.global_position += room.studio.to_global(at) - room.camera.global_position
	var facing: Vector3 = room.camera.global_transform.looking_at(room.studio.to_global(target), Vector3.UP).basis.get_euler()
	room.player.global_rotation = Vector3(0, facing.y, 0)
	room._pitch = facing.x
	room.camera.rotation = Vector3(facing.x, 0, 0)
	await _frames(3)
	_check(room._interaction_target().get("id", "") == id, "authored approach sees actual interaction: " + id)
	await _key(KEY_E); await _frames(3)
	if id == "computer":
		_check(room._in_desktop and room.desktop != null and room.desktop.visible, "actual E resumes computer desktop")
	elif id not in ["room_exit","courtyard_enter"]:
		_check(room.habitat_panel != null, "actual E opens interaction panel: " + id)

func _optional_computer_resume() -> void:
	await _open_terminal(0)
	var input: LineEdit = desktop.terms[0].input
	input.text = "optional-I02-unsent-draft"
	input.grab_focus()
	var same := desktop
	var snapshot: Dictionary = desktop.game.export_snapshot()
	await _key(KEY_F10); await _frames(3)
	_check(not room._in_desktop and not same.visible, "I02 F10 actually returns to Room")
	await _capture("optional-I02-room-before-E.png")
	await _world_e("computer", Vector3(0.2, 1.63, 0), room.studio.computer_position)
	_check(room.desktop == same and same.pack_id == "investigation", "actual computer E retains current optional session")
	_check(same.game.export_snapshot() == snapshot and same.game.get_view().mission_id == "I02", "actual computer E preserves exact I02 world")
	_check(input.text == "optional-I02-unsent-draft" and root.gui_get_focus_owner() == input, "actual computer E preserves optional draft and input focus")
	life_observations.append({"scenario":"I02_F10_room_computer_E", "same_desktop":room.desktop == same,
		"same_snapshot":same.game.export_snapshot() == snapshot, "draft":input.text, "focus_restored":root.gui_get_focus_owner() == input})
	await _capture("optional-I02-resumed-E.png")
	# Draft text is explicit fixture setup; clear it before the route's real submitted commands.
	input.text = ""

func _large_optional_controls() -> void:
	if not room._in_desktop:
		await _world_e("computer", Vector3(0.2, 1.63, 0), room.studio.computer_position)
	desktop = room.desktop
	var settings: Dictionary = room.settings_store.get_values()
	var main := desktop
	var snapshot: Dictionary = main.game.export_snapshot()
	var window_size := root.size
	for locale in ["ko", "de"]:
		var preview := settings.duplicate(true)
		preview.locale = locale
		preview.font_scale = 1.6
		preview.fullscreen = false
		# The actual store is uniquely isolated before boot. Temporary test preference IO is setup.
		if not _set_test_settings(preview): break
		root.size = Vector2i(1280, 720)
		await _frames(5)
		_check(root.size == Vector2i(1280, 720) and is_equal_approx(desktop.font_scale, 1.6), "optional large text uses 1280x720 / 1.6: " + locale)
		_check(room._in_desktop and desktop.is_visible_in_tree(), "large optional chooser starts on visible desktop: " + locale)
		await _open_app("board")
		await _click(desktop.commission_entry_button)
		for id in ["I01", "I02"]:
			var card := _metadata_button(desktop.commission_list, "commission_id", id)
			_check(card != null, "large optional chooser exposes card: " + locale + "/" + id)
			if card != null:
				await _scroll_reach(card, locale + "/chooser/" + id)
		await _capture("large-%s-chooser-last.png" % locale)
		var close := _button_text(desktop.commission_panel, str(TranslationServer.translate("UI_COMMISSIONS_CLOSE")))
		_check(close != null, "large optional chooser exposes close: " + locale)
		if close != null: await _scroll_click(close)
		desktop._open_deskshop(); await _frames(3)
		var lamp := _metadata_button(room.habitat_panel.content, "product_id", "lamp_cool")
		_check(lamp != null and not lamp.disabled, "large shop exposes final lamp action: " + locale)
		if lamp != null: await _scroll_reach(lamp, locale + "/shop/lamp_cool")
		await _capture("large-%s-shop-last-lamp.png" % locale)
		await _close_panel()
		await _key(KEY_F10); await _frames(3)
		# Context setup avoids mutating an already verified job just to inspect controls.
		room.show_habitat("network_cabinet"); await _frames(3)
		for id in ["inspect_cabinet", "route", "locked", "configure", "verify_job"]:
			await _scroll_reach(room.habitat_panel.controls[id], locale + "/cabinet/" + id)
		await _capture("large-%s-cabinet-last-control.png" % locale)
		await _close_panel()
		await _world_e("computer", Vector3(0.2, 1.63, 0), room.studio.computer_position)
		desktop = room.desktop
		_check(desktop == main and desktop.game.export_snapshot() == snapshot, "large optional UI preserves main session: " + locale)
	root.size = window_size
	_set_test_settings(settings)
	await _frames(4)
	_check(room.settings_store.get_values() == settings and is_equal_approx(desktop.font_scale, float(settings.font_scale)), "large optional previews restore original isolated preferences")

func _scroll_reach(control: Control, label: String) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "large control exists: " + label)
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return
	# Wheel events exercise actual scroll input; focus follows to the exact requested control.
	var scroll: ScrollContainer
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll = ancestor
			break
		ancestor = ancestor.get_parent()
	if scroll != null:
		var point := scroll.get_global_rect().get_center()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.position = point
		event.global_position = point
		event.pressed = true
		control.get_viewport().push_input(event, true)
		await _frames(2)
	control.grab_focus()
	await _frames(4)
	var visible := _visible_control_rect(control)
	var reachable := visible.size.x >= control.size.x - 1 and visible.size.y >= control.size.y - 1
	_check(root.gui_get_focus_owner() == control and reachable, "large control fully exposed by scroll/focus: " + label)
	life_observations.append({"control":label, "reachable":reachable, "rect":str(control.get_global_rect()), "visible_rect":str(visible), "scroll":scroll.scroll_vertical if scroll != null else 0})

func _visible_control_rect(control: Control) -> Rect2:
	var visible := control.get_global_rect().intersection(control.get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and (parent.clip_contents or parent is ScrollContainer):
			visible = visible.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return visible

func _product(id: String) -> void:
	var button := _metadata_button(room.habitat_panel.content, "product_id", id)
	_check(button != null and not button.disabled, "available product action: " + id)
	if button != null and not button.disabled:
		button.grab_focus(); await _frames(3); await _click(button); await _frames(3)

func _close_panel() -> void:
	await _key(KEY_ESCAPE); await _frames(3)
	_check(room.habitat_panel == null, "Escape closes household panel")

func _br_open_page() -> void:
	await _open_app("browser")
	desktop.br_addr.text = "https://i02.investigation.packet.test/review"
	desktop.br_addr.grab_focus(); await _key(KEY_ENTER); await _frames(4)
	_check(not desktop.br_failed and not desktop.br_body.get_parsed_text().is_empty(), "news page shows authoritative selected report")
	await _capture("news-article.png")

func _scroll_click(control: Control) -> void:
	control.grab_focus()
	await _frames(3)
	var visible := _visible_control_rect(control)
	_check(visible.size.x >= control.size.x - 1 and visible.size.y >= control.size.y - 1, "scroll focus fully exposes actual clicked control")
	await _click(control)
