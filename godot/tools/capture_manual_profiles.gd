extends "res://tools/capture_perspectives.gd"
## Native five-checkpoint and opted-in owned-window acceptance; core fixture setup is explicit.

const QA_OUTPUT := "res://../.omx/artifacts/manual-profile/native"
var observations: Array = []
var expected_profiles: Dictionary = {}
var original_window: Dictionary = {}
var backup_profile: Dictionary = {}

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	profile = "manual-profiles"
	original_window = {"title":root.title,"position":root.position,"size":root.size,"mode":root.mode}
	not_run.append("Campaigns are bounded core fixtures, not a 47-case GUI replay. Physical OS input/IME and other application windows are outside this suite.")
	_run.call_deferred()
	create_timer(180).timeout.connect(func():
		if not finished:
			failures.append("manual profiles native capture exceeded180s")
			_finish())

func _render_suite() -> String:
	return "rendered_manual_profiles"

func _render_ui_observations() -> Array:
	return observations

func _render_expected_scope() -> Dictionary:
	if OS.get_cmdline_user_args().has("--recovery-layout-only"):
		return {"layout_only":true,"recovery_member_labels":7,"restore_actions":0,"case_solutions":0,"endings":0}
	return {"manual_slots":5,"case_solutions":0,"endings":0,"whole_profile":"all six campaign snapshots plus household",
		"native_input":"save/load/overwrite/cancel/settings opt-in/preview", "setup":"bounded core campaign commands, household actions, isolated preferences, scene restart"}

func _fingerprints() -> Dictionary:
	var result := super._fingerprints()
	for folder in ["user://profiles", "user://saves/profile_generations"]:
		_fingerprint_tree(folder, result)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		result["user://saves/profile_active.json" + suffix] = _path_fingerprint("user://saves/profile_active.json" + suffix)
		result["user://saves/profile_generations/active_selected.json" + suffix] = _path_fingerprint("user://saves/profile_generations/active_selected.json" + suffix)
	return result

func _run() -> void:
	if not (await _boot_product()): _finish(); return
	output_dir = ProjectSettings.globalize_path(QA_OUTPUT).simplify_path()
	_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "manual native artifact directory writable")
	if OS.get_cmdline_user_args().has("--recovery-layout-only"):
		await _synthetic_recovery_layout()
		_finish(); return
	_check(str(full.manual_store.get("_root")).begins_with("user://tests/"), "manual profile namespace is isolated")
	_check(not room.settings_store.get_values().desktop_effects, "owned-window effects start opted out")
	await _capture("manual-menu.png")
	await _open_manual()
	expected_profiles[1] = full.capture_manual_profile()
	_check(expected_profiles[1].snapshots.campaigns.values().all(func(value): return value == null), "early slot records every unstarted campaign as absent")
	await _save(1)
	await _capture("slot1-early.png")
	await _close_manual()
	if not (await _select_pack("intruder")) or not (await _start_new_pack("intruder")): _finish(); return
	# Secondary sessions and mutations are fixture setup through bounded in-game APIs.
	for pack in Catalog.list_all_packs(true):
		if room.get_cached_desktop(str(pack.id)) == null:
			room.open_desktop("new", str(pack.id), "independent")
	for index in range(2, 6):
		_fixture_mutations("checkpoint_%d" % index, index)
		var selected: String = {2:"intruder",3:"defender",4:"tracker",5:"investigation"}[index]
		if selected == "investigation":
			room.open_desktop("continue", "intruder")
			room.open_commission("I02")
		else: room.open_desktop("continue", selected)
		await _frames(5)
		_bind_current()
		await _open_manual()
		expected_profiles[index] = full.capture_manual_profile()
		await _save(index)
		await _capture("slot%d-saved.png" % index)
		await _close_manual()
	_check(full.manual_store.list_slots().all(func(row): return row.status == "valid"), "all five manual slots contain valid complete profiles")
	observations.append({"scenario":"fixture_setup", "scope":"Six cached campaigns changed through mkdir core commands; household lighting and purchases via bounded Habitat actions. Save/load buttons use native InputEvents."})
	await _overwrite()
	await _restore_all()
	await _restart_profile(false)
	await _open_manual()
	await _load(1)
	_check_profile(1, "early whole-profile restore")
	_check(room._desktops.is_empty(), "early checkpoint clears every later cached desktop")
	_check_absent()
	await _close_manual()
	await _restart_profile(true)
	await _open_manual()
	await _load(5)
	_check_profile(5, "slot5 restored after early-profile restart")
	await _close_manual()
	await _large_manual()
	await _active_backup_recovery()
	await _native_effects()
	await _synthetic_recovery_layout()
	_finish()

func _fixture_mutations(label: String, index: int) -> void:
	for pack in Catalog.list_all_packs(true):
		var cached = room.get_cached_desktop(str(pack.id))
		if cached == null:
			room.open_desktop("continue", str(pack.id))
			cached = room.get_cached_desktop(str(pack.id))
		var before: Dictionary = cached.game.export_snapshot()
		var result: Dictionary = cached.game.execute("mkdir ~/" + label)
		_check(result.get("ok", false) and cached.game.export_snapshot() != before, "bounded core fixture mutates " + str(pack.id) + "/" + label)
	var lighting: Dictionary = room.habitat_store.apply("set_lighting", {"lighting":"dawn" if index % 2 == 0 else "night"})
	_check(lighting.get("ok", false), "bounded household lighting fixture: " + label)
	if index in [2,3,4,5]:
		var product: String = {2:"keyboard_ivory",3:"keyboard_coral",4:"monitor_wide",5:"lamp_cool"}[index]
		_check(room.habitat_store.apply("order", {"product_id":product}).get("ok", false), "bounded household purchase fixture: " + product)

func _bind_current() -> void:
	pack_slots = room.campaign_slots.duplicate(true)
	pack_desktops.clear()
	if room._in_desktop and is_instance_valid(room.desktop):
		_attach_desktop(str(room.desktop.pack_id))
	else:
		desktop = null
		active_pack = ""

func _open_manual() -> void:
	if room.manual_save_panel != null: return
	# Core fixture sessions can be created synchronously; wait for their embedded windows to lay out.
	await _frames(6)
	_bind_current()
	if room._in_desktop and is_instance_valid(room.desktop):
		desktop = room.desktop
		await _click(desktop.save_btn)
	else:
		await _menu()
		var button := _metadata_button(room.menu_box, "lobby_action", "manual_saves")
		_check(button != null, "lobby exposes real manual saves button")
		if button != null: await _click(button)
	await _frames(4)
	_check(room.manual_save_panel != null and room.manual_save_panel.cards.size() == 5, "actual action opens exactly five manual cards")

func _close_manual() -> void:
	if room.manual_save_panel == null: return
	await _click(room.manual_save_panel.close_button)
	await _frames(4)
	_check(room.manual_save_panel == null, "actual Back closes manual modal")

func _save(index: int) -> void:
	await _reach_click(room.manual_save_panel.cards[index].save)
	await _frames(4)
	_check(not room.manual_save_panel.confirmation.visible, "empty slot saves directly from real button: " + str(index))
	_check_slot_labels(index)

func _load(index: int) -> void:
	await _reach_click(room.manual_save_panel.cards[index].load)
	_check(room.manual_save_panel.confirmation.visible, "whole-profile load requires real confirmation: " + str(index))
	await _confirm_dialog(room.manual_save_panel.confirmation)
	await _frames(8)
	_bind_current()

func _check_slot_labels(index: int) -> void:
	var row: Dictionary = room.manual_save_panel.cards[index].row
	var text := ""
	for label in room.manual_save_panel.cards[index].card.find_children("*", "Label", true, false): text += label.text + "\n"
	var pack: Dictionary = Catalog.get_pack(str(row.pack_id))
	_check(row.status == "valid" and int(row.saved_at) > 0, "saved slot metadata has a real timestamp: " + str(index))
	_check(text.contains(str(TranslationServer.translate(pack.title_key))) and text.contains(str(row.mission_id))
		and text.contains(room.manual_save_panel._local_time(int(row.saved_at))), "actual labels show scenario, mission and timestamp: " + str(index))
	_check(text.contains(Localization.tr_key("MANUAL_SLOT_PROGRESS", {"done":row.completed,"total":row.total})), "actual labels show campaign progress: " + str(index))
	observations.append({"scenario":"slot_labels","slot":index,"row":row,"rendered_text":text})

func _slot_hashes() -> Dictionary:
	var result := {}
	var base: String = full.manual_store.get("_root")
	for index in range(1, 6):
		for suffix in ["", ".bak"]:
			var path: String = base + "/slot_%02d.json" % index + suffix
			result[path] = _path_fingerprint(path)
	return result

func _cancel_dialog(dialog: ConfirmationDialog) -> void:
	var button := dialog.get_cancel_button()
	button.grab_focus(); await _frames(2)
	await _key(KEY_ENTER, false, false, 0, false, button.get_viewport())
	await _frames(3)
	_check(not dialog.visible, "native focused Cancel closes confirmation")

func _overwrite() -> void:
	backup_profile = expected_profiles[2].duplicate(true)
	_fixture_mutations("overwrite_candidate", 6)
	await _open_manual()
	var hashes := _slot_hashes()
	await _reach_click(room.manual_save_panel.cards[2].save)
	_check(room.manual_save_panel.confirmation.visible, "populated slot overwrite opens confirmation")
	await _capture("overwrite-confirm.png")
	await _cancel_dialog(room.manual_save_panel.confirmation)
	_check(_slot_hashes() == hashes, "overwrite Cancel preserves all five manifests and backups")
	expected_profiles[2] = full.capture_manual_profile()
	await _reach_click(room.manual_save_panel.cards[2].save)
	await _confirm_dialog(room.manual_save_panel.confirmation); await _frames(4)
	var after := _slot_hashes()
	var base: String = full.manual_store.get("_root")
	for path in hashes:
		if path.begins_with(base + "/slot_02.json"): continue
		_check(after[path] == hashes[path], "overwrite slot2 preserves another checkpoint: " + path.get_file())
	_check(after[base + "/slot_02.json"] != hashes[base + "/slot_02.json"], "confirmed overwrite changes only selected slot")
	_check_slot_labels(2)
	_check(room.manual_save_panel.cards[2].has("backup"), "overwritten checkpoint exposes validated previous backup action")
	var live: Dictionary = full.capture_manual_profile()
	var manual_hashes := _slot_hashes()
	await _reach_click(room.manual_save_panel.cards[2].backup)
	_check(room.manual_save_panel.confirmation.visible, "actual previous-backup load requires confirmation")
	await _capture("previous-checkpoint-backup-confirm.png")
	await _cancel_dialog(room.manual_save_panel.confirmation)
	_check(full.capture_manual_profile().snapshots == live.snapshots and _slot_hashes() == manual_hashes, "backup load Cancel preserves live profile and checkpoints")
	await _reach_click(room.manual_save_panel.cards[2].backup)
	await _confirm_dialog(room.manual_save_panel.confirmation); await _frames(8)
	_bind_current()
	_check(full.capture_manual_profile().snapshots == backup_profile.snapshots, "actual previous-backup Confirm restores the complete prior slot2 profile")
	_check(_slot_hashes() == manual_hashes, "loading previous backup preserves all manual checkpoint bytes")
	await _close_manual()

func _check_profile(index: int, label: String) -> void:
	var actual: Dictionary = full.capture_manual_profile()
	_check(actual.get("ok", false) and actual.snapshots == expected_profiles[index].snapshots, label + " restores all six campaigns and household exactly")
	observations.append({"scenario":"whole_profile_restore","label":label,"slot":index,"snapshots_exact":actual.get("snapshots") == expected_profiles[index].snapshots})

func _restore_all() -> void:
	_fixture_mutations("after_all_checkpoints", 6)
	var newer: Dictionary = room.settings_store.get_values()
	newer.master_volume = 0.42
	_check(_set_test_settings(newer), "newer isolated preferences are stored before profile load")
	var preference_hash := _path_fingerprint(preferences_path)
	var old_ids: Array = []
	for cached in room._desktops.values(): old_ids.append(cached.get_instance_id())
	await _open_manual()
	await _load(5)
	_check_profile(5, "whole-profile UI load")
	_check(old_ids.all(func(id): return not is_instance_id_valid(id)), "whole-profile load invalidates all stale desktop instances")
	_check(room.settings_store.get_values() == newer and _path_fingerprint(preferences_path) == preference_hash, "whole-profile load preserves newer settings in memory and on disk")
	await _capture("whole-profile-restored.png")
	await _close_manual()
	await _open_app("board")
	await _click(desktop.commission_return_button); await _frames(4)
	_bind_current()
	_check(desktop.pack_id == "intruder" and desktop.game.export_snapshot() == expected_profiles[5].snapshots.campaigns.intruder, "actual optional Return resumes restored main campaign")
	if (await _select_pack("defender")) and (await _continue_pack("defender")):
		_check(desktop.game.export_snapshot() == expected_profiles[5].snapshots.campaigns.defender, "actual other-campaign Continue uses restored profile snapshot")

func _restart_profile(expect_absent: bool) -> void:
	var settings: Dictionary = room.settings_store.get_values()
	await _reload_scene()
	_check(full.manual_profile_result.get("ok", false) and full.manual_profile_result.get("active", false), "fresh FullScene restart resolves active profile using same isolated base")
	_check(room.settings_store.get_values() == settings, "fresh FullScene restart preserves saved preferences")
	if expect_absent:
		_check_profile(1, "early active-profile restart")
		_check_absent()
	else:
		_check_profile(5, "active-profile restart")
		_check(room.menu.visible and not room._in_desktop and room.desktop == null,
			"fresh active-profile startup intentionally returns to the lobby")
		if await _continue_pack("intruder"):
			_check(desktop.game.export_snapshot() == expected_profiles[5].snapshots.campaigns.intruder,
				"actual Continue after fresh startup resumes the restored active profile")
	observations.append({"scenario":"scene_restart","same_test_root":full.save_slot_path == test_base,"active":full.manual_profile_result.get("active", false),"early_absence":expect_absent})

func _reload_scene() -> void:
	var saved_base := test_base
	for player in full.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	root.remove_child(full)
	full.queue_free()
	full = null; room = null; desktop = null
	pack_desktops.clear()
	await _frames(8)
	full = load("res://scenes/full_game.tscn").instantiate()
	full.save_slot_path = saved_base
	root.add_child(full)
	current_scene = full
	await _frames(10)
	room = full.room
	_bind_current()

func _active_backup_recovery() -> void:
	var path: String = room.campaign_slots.intruder
	_check(path.begins_with("user://tests/"), "active backup damage fixture is confined to isolated profile generation")
	if not path.begins_with("user://tests/"): return
	var bytes := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.open(path + ".bak", FileAccess.WRITE)
	backup.store_buffer(bytes); backup.close()
	var damaged := "isolated native active-member damage"
	var original := FileAccess.open(path, FileAccess.WRITE)
	original.store_string(damaged); original.close()
	await _reload_scene()
	_check(room.profile_recovery_required and room.manual_save_panel != null, "corrupt active member restarts into actual recovery modal")
	_check(room.manual_save_panel.cards[1].save.disabled and room.manual_save_panel.active_recovery_button != null,
		"recovery modal disables saving and exposes validated active backup recovery")
	await _reach_click(room.manual_save_panel.active_recovery_button)
	_check(room.manual_save_panel.confirmation.visible, "active backup recovery requires actual confirmation")
	await _capture("active-backup-recovery-confirm.png")
	await _cancel_dialog(room.manual_save_panel.confirmation)
	_check(room.profile_recovery_required and FileAccess.get_file_as_string(path) == damaged, "active backup Cancel preserves broken bytes and recovery state")
	await _reach_click(room.manual_save_panel.active_recovery_button)
	await _confirm_dialog(room.manual_save_panel.confirmation); await _frames(8)
	_bind_current()
	_check(not room.profile_recovery_required, "actual active-backup Confirm exits recovery")
	_check_profile(5, "active autosave backup recovery")
	_check(FileAccess.get_file_as_string(path) == damaged and FileAccess.get_file_as_bytes(path + ".bak") == bytes,
		"active backup recovery preserves original damaged and backup bytes")
	observations.append({"scenario":"active_backup_recovery","source":path,"damaged_preserved":FileAccess.get_file_as_string(path) == damaged,
		"setup":"Validated active intruder bytes copied to its isolated .bak, then its isolated original corrupted before scene restart; recovery and confirmation use native InputEvents."})
	await _capture("active-backup-recovered.png")
	await _close_manual()

func _check_absent() -> void:
	for pack in Catalog.list_all_packs(true):
		var probe := Campaign.new(room.campaign_slots[pack.id], str(pack.id))
		var status: Dictionary = probe.get_save_status()
		_check(not status.get("exists", true) and not status.get("backup_exists", true), "early checkpoint never resurrects later campaign bytes: " + str(pack.id))
	_check(not room.allow_legacy_auto_import, "active early profile suppresses legacy resurrection")

func _large_manual() -> void:
	var settings: Dictionary = room.settings_store.get_values()
	var window_size := root.size
	for locale in ["ko", "de"]:
		var preview := settings.duplicate(true)
		preview.locale = locale; preview.font_scale = 1.6; preview.fullscreen = false
		if not _set_test_settings(preview): return
		root.size = Vector2i(1280,720)
		await _frames(5)
		await _open_manual()
		for action in ["save", "load"]:
			await _reach(room.manual_save_panel.cards[5][action], locale + "/slot5/" + action)
		await _capture("large-%s-slot5.png" % locale)
		var before: Dictionary = full.capture_manual_profile()
		await _reach_click(room.manual_save_panel.cards[5].load)
		var dialog: ConfirmationDialog = room.manual_save_panel.confirmation
		_check(dialog.visible, "large slot5 actual Load opens confirmation: " + locale)
		var bounds: Vector2 = room.manual_save_panel.get_viewport_rect().size
		_check(dialog.position.x >= 0 and dialog.position.y >= 0 and dialog.position.x + dialog.size.x <= bounds.x
			and dialog.position.y + dialog.size.y <= bounds.y, "large manual load confirmation fits logical viewport: " + locale)
		await _capture("large-%s-load-confirm.png" % locale)
		await _cancel_dialog(dialog)
		_check(full.capture_manual_profile().snapshots == before.snapshots, "large load Cancel preserves whole live profile: " + locale)
		await _close_manual()
	root.size = window_size
	_set_test_settings(settings)
	await _frames(4)

func _native_effects() -> void:
	await _menu()
	var new_game := _metadata_button(room.menu_box, "lobby_action", "new")
	_check(new_game != null and not new_game.disabled, "successful active recovery re-enables the lobby New Game action")
	var settings: Dictionary = room.settings_store.get_values()
	_check(not settings.desktop_effects, "window effect opt-in remains false before actual checkbox Apply")
	var button := _metadata_button(room.menu_box, "lobby_action", "settings")
	await _reach_click(button); await _frames(3)
	await _settings_display()
	var preview := _metadata_button(room.settings_panel, "settings_action", "desktop_effects_preview")
	_check(preview != null and preview.disabled and not room.settings_panel.controls.desktop_effects.button_pressed, "preview is disabled before opt-in")
	await _reach_click(room.settings_panel.controls.desktop_effects)
	_check(not room.settings_store.get_values().desktop_effects and preview.disabled, "checkbox draft requires saved Apply before preview")
	await _click(room.settings_panel.apply_button); await _frames(5)
	_check(room.settings_store.get_values().desktop_effects and room.settings_panel == null, "actual Apply saves explicit native-window opt-in")
	button = _metadata_button(room.menu_box, "lobby_action", "settings")
	await _reach_click(button); await _frames(3)
	await _settings_display()
	preview = _metadata_button(room.settings_panel, "settings_action", "desktop_effects_preview")
	await _reach(preview, "native preview")
	_check(not preview.disabled, "saved opt-in enables reopened actual Preview button")
	var service = full.desktop_effects
	var before: Dictionary = service._driver.snapshot()
	var backend_before := DisplayServer.window_get_position(root.get_window_id())
	var outcomes: Array = []
	service.effects_finished.connect(func(result: Dictionary): outcomes.append(result.duplicate(true)))
	await _click(preview)
	var during: Dictionary = service._driver.snapshot()
	var backend_during := DisplayServer.window_get_position(root.get_window_id())
	var started: bool = service.active
	if before.get("available", false) and before.get("focused", false):
		_check(started and during.title != before.title, "actual preview changes this game's real native Window title")
		if service._can_move(before):
			_check(during.position != before.position and backend_during == during.position, "eligible native preview moves the actual DisplayServer game window")
		await _capture("native-window-preview.png")
		await create_timer(1.5).timeout
		var after: Dictionary = service._driver.snapshot()
		var backend_after := DisplayServer.window_get_position(root.get_window_id())
		_check(not service.active and after.title == before.title and after.position == before.position, "real native effect restores owned Window title and position")
		_check(backend_after == backend_before, "DisplayServer confirms actual game-window position restoration")
		_check(not outcomes.is_empty() and outcomes[-1].get("native_request", false), "native service confirms actual Window request without injected driver")
		observations.append({"scenario":"native_window_effect","backend":DisplayServer.get_name(),"native_driver":before.get("native", false),
			"before":before,"during":during,"after":after,"backend_before":str(backend_before),"backend_during":str(backend_during),"backend_after":str(backend_after),
			"outcome":outcomes[-1] if not outcomes.is_empty() else {},"position_changed":during.position != before.position})
		await _click(preview)
		if service.active:
			await _key(KEY_ESCAPE); await _frames(3)
			var skipped: Dictionary = service._driver.snapshot()
			_check(not service.active and skipped.title == before.title and skipped.position == before.position,
				"actual Esc immediately restores the active native Window effect")
			_check(room.settings_panel != null, "native effect Esc is consumed while Settings remains open")
			observations.append({"scenario":"native_window_escape","restored":skipped.title == before.title and skipped.position == before.position,
				"outcome":outcomes[-1] if not outcomes.is_empty() else {}})
	else:
		not_run.append("Native effect title/position acceptance NOT_RUN: actual driver unavailable or game Window unfocused; no focus was requested.")
		observations.append({"scenario":"native_window_effect","backend":DisplayServer.get_name(),"started":started,"before":before,"during":during,"not_run":"unavailable or unfocused"})
	service.cancel()
	await _click(room.settings_panel.cancel_button); await _frames(3)
	_set_test_settings(settings)

func _settings_display() -> void:
	var tabs: TabContainer = room.settings_panel.tabs
	var bar := tabs.get_tab_bar()
	await _click_local(bar, bar.get_tab_rect(1).get_center())
	await _frames(3)
	_check(tabs.current_tab == 1, "actual tab input opens display settings")

func _synthetic_recovery_layout() -> void:
	# Layout fixture only: all seven labels are valid possibilities; no restore signal is connected.
	await _menu()
	var settings: Dictionary = room.settings_store.get_values()
	var window_size := root.size
	var preview := settings.duplicate(true)
	preview.locale = "de"; preview.font_scale = 1.6; preview.fullscreen = false
	if not _set_test_settings(preview): return
	root.size = Vector2i(1280,720)
	await _frames(5)
	await _capture("synthetic-large-de-menu.png")
	await _reach(room.load_button, "large-de/autosave load")
	await _reach(_metadata_button(room.menu_box, "lobby_action", "settings"), "large-de/settings utility")
	await _capture("synthetic-large-de-menu-utilities.png")
	var panel = load("res://scripts/presentation/manual_save_panel.gd").new()
	room.overlay.add_child(panel)
	room.manual_save_panel = panel
	var members: Array = []
	for pack in Catalog.list_all_packs(true): members.append(str(pack.id))
	members.append("habitat")
	panel.setup(full.manual_store.list_slots(), 1.6, false, "PROFILE_INVALID_MEMBER",
		{"available":true,"manifest_source":"current","backup_members":members})
	await _frames(5)
	await _reach_click(panel.active_recovery_button)
	await _frames(4)
	var dialog: ConfirmationDialog = panel.confirmation
	var bounds: Vector2 = panel.get_viewport_rect().size
	var fits: bool = dialog.position.x >= 0 and dialog.position.y >= 0 and dialog.position.x + dialog.size.x <= bounds.x and dialog.position.y + dialog.size.y <= bounds.y
	_check(dialog.visible and fits, "synthetic seven-member German recovery confirmation fits logical viewport")
	observations.append({"scenario":"synthetic_seven_member_recovery_layout","members":members,"dialog_position":str(dialog.position),
		"dialog_size":str(dialog.size),"logical_viewport":str(bounds),"fits":fits,
		"setup":"Direct ManualPanel setup with all six registered campaign labels plus habitat; real recovery-button input and Cancel only, no restore handler connected."})
	await _capture("synthetic-de-seven-backups-confirm.png")
	await _cancel_dialog(dialog)
	room.manual_save_panel = null
	panel.get_parent().remove_child(panel)
	panel.queue_free()
	root.size = window_size
	_set_test_settings(settings)
	await _frames(4)

func _reach(control: Control, label: String) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "reachable control exists: " + label)
	if not is_instance_valid(control): return
	control.grab_focus(); await _frames(4)
	var visible := control.get_global_rect().intersection(control.get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and (parent.clip_contents or parent is ScrollContainer): visible = visible.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	_check(visible.size.x >= control.size.x - 1 and visible.size.y >= control.size.y - 1, "scroll/focus exposes complete native target: " + label)

func _reach_click(control: Control) -> void:
	await _reach(control, "manual/settings action")
	await _click(control)

func _finish() -> void:
	if not original_window.is_empty():
		if is_instance_valid(full) and is_instance_valid(full.desktop_effects): full.desktop_effects.cancel()
		root.title = original_window.title
		root.mode = original_window.mode
		root.size = original_window.size
		root.position = original_window.position
	await super._finish()
