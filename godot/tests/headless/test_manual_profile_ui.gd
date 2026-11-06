extends "res://tests/headless/test_desktop_shell.gd"

const FullScene = preload("res://scenes/full_game.tscn")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Habitat = preload("res://scripts/core/habitat_store.gd")
const ManualPanel = preload("res://scripts/presentation/manual_save_panel.gd")

class EffectsProbe extends Node:
	var active := false
	var previews := 0
	var stories: Array = []
	func configure(_values: Dictionary) -> void: pass
	func preview() -> Dictionary:
		previews += 1
		return {"ok": true}
	func trigger_story(id: String) -> Dictionary:
		stories.append(id)
		return {"ok": true}
	func cancel() -> void: active = false
	func skip() -> void: active = false


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	tree = scene_tree
	var protected := _fingerprints()
	_fingerprint_folder("user://profiles", protected)
	var previous_locale := Localization.get_locale()
	test_root = "user://tests/manual_profile_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(test_root)
	var base := test_root + "/campaign.json"
	var full := await _new_full(base)
	var room = full.room
	_check(full.manual_store != null and full.manual_profile_result.ok, "profile coordinator starts with an isolated valid root")
	_check(room.campaign_buttons.size() == 4, "five manual checkpoints do not add main campaign cards")
	var early: Dictionary = full.capture_manual_profile()
	_check(early.ok and early.snapshots.campaigns.values().all(func(raw): return raw == null), "unstarted campaigns are captured as six explicit absences")
	_check(full.save_manual_slot(1).ok, "slot 1 captures the untouched early profile")
	var expected := {1: early}
	for pack in Catalog.list_all_packs(true):
		room.open_desktop("new", str(pack.id), "independent")
		_check(room.desktop.pack_id == pack.id and room.desktop.session_active, "fixture starts the real cached campaign: " + str(pack.id))
	room.open_desktop("continue", "intruder")
	room.open_commission("I02")
	_check(room._commission_return_pack == "intruder", "fixture retains the main campaign return context while an optional commission is active")
	var original_autosaves := {}
	for pack in Catalog.list_all_packs(true):
		var path: String = room.campaign_slots[pack.id]
		original_autosaves[path] = FileAccess.get_file_as_bytes(path)
	for index in range(2, 6):
		# Public core actions change every cached world without writing an autosave.
		for pack in Catalog.list_all_packs(true):
			var cached = room.get_cached_desktop(str(pack.id))
			var prior: Dictionary = cached.game.export_snapshot()
			var changed: Dictionary = cached.game.execute("mkdir ~/checkpoint_%d" % index)
			_check(changed.ok and cached.game.export_snapshot() != prior, "actual core command mutates checkpoint " + str(index) + ": " + str(pack.id))
		room.habitat_store.apply("set_lighting", {"lighting": "dawn" if index % 2 == 0 else "night"})
		expected[index] = full.capture_manual_profile()
		_check(full.save_manual_slot(index).ok, "whole-profile slot is saved: " + str(index))
	for path in original_autosaves:
		_check(FileAccess.get_file_as_bytes(path) == original_autosaves[path], "manual checkpoint leaves existing campaign autosave bytes separate")
	_check(full.manual_store.list_slots().size() == 5 and full.manual_store.list_slots().all(func(row): return row.status == "valid"), "all five manual checkpoints are valid")
	await _panel_flow(full)
	# A campaign with no cached desktop must be captured from its real disk model.
	var tracker = room.get_cached_desktop("tracker")
	room._desktops.erase("tracker")
	tracker.get_parent().remove_child(tracker)
	tracker.queue_free()
	var unloaded = Campaign.new(room.campaign_slots.tracker, "tracker")
	_check(unloaded.load_game().ok, "unloaded tracker has a real isolated disk checkpoint")
	unloaded.execute("mkdir ~/disk_only")
	_check(unloaded.save_game().ok, "unloaded campaign fixture mutates through core save API")
	var captured_disk: Dictionary = full.capture_manual_profile()
	_check(captured_disk.ok and captured_disk.snapshots.campaigns.tracker == unloaded.export_snapshot(), "capture loads an uncached campaign through Campaign.load_game")
	var settings_result: Dictionary = room.settings_store.update_settings({"master_volume": 0.42, "locale": "de", "font_scale": 1.6})
	_check(settings_result.ok, "settings can change after the manual checkpoint")
	var preferences: Dictionary = room.settings_store.get_values()
	var preference_bytes := FileAccess.get_file_as_bytes(room.settings_path)
	var stale_ids: Array = []
	for cached in room._desktops.values(): stale_ids.append(cached.get_instance_id())
	_check(full.load_manual_slot(5).ok, "whole-profile restore commits a validated replacement generation")
	await tree.process_frame
	await tree.process_frame
	var restored: Dictionary = full.capture_manual_profile()
	_check(restored.ok and restored.snapshots == expected[5].snapshots, "restore reproduces every cached campaign and habitat snapshot exactly")
	_check(room.desktop.pack_id == "investigation" and room._commission_return_pack == "intruder", "restore reopens the optional campaign with its saved main return context")
	_check(room._desktops.size() == 1 and full._connected_desktops.size() == 1 and stale_ids.all(func(id): return not is_instance_id_valid(id)), "all old desktops and connection identities are invalidated before Continue")
	_check(room.settings_store.get_values() == preferences and FileAccess.get_file_as_bytes(room.settings_path) == preference_bytes, "restoring progress preserves newer settings in memory and on disk")
	room.return_from_commission()
	_check(room.desktop.pack_id == "intruder" and room.desktop.game.export_snapshot() == expected[5].snapshots.campaigns.intruder, "optional return reloads the restored main snapshot instead of a stale cached model")
	var live_before: Dictionary = full.capture_manual_profile()
	var active_path := base.get_basename() + "_profiles/active.json"
	var active_before := FileAccess.get_file_as_bytes(active_path)
	var failed: Dictionary = full.load_manual_slot(0)
	_check(not failed.ok and full.capture_manual_profile().snapshots == live_before.snapshots and FileAccess.get_file_as_bytes(active_path) == active_before, "failed restore leaves live models and the active pointer untouched")
	# An invalid existing uncached save or orphan backup must never become null.
	var absent_path: String = room.campaign_slots.tracker
	_write(absent_path, "damaged-tracker")
	_check(not full.capture_manual_profile().ok, "an invalid existing unloaded campaign blocks saving instead of becoming absence")
	DirAccess.remove_absolute(absent_path)
	_write(absent_path + ".bak", "damaged-orphan")
	_check(not full.capture_manual_profile().ok, "an invalid orphan backup also blocks manual capture")
	DirAccess.remove_absolute(absent_path + ".bak")
	_check(full.load_manual_slot(1).ok, "an earlier checkpoint with unstarted campaigns can be restored")
	var early_restored: Dictionary = full.capture_manual_profile()
	_check(early_restored.ok and early_restored.snapshots == early.snapshots and room._desktops.is_empty(), "restoring early absence clears every later cached campaign")
	for pack in Catalog.list_all_packs(true):
		var probe = Campaign.new(room.campaign_slots[pack.id], pack.id)
		var status: Dictionary = probe.get_save_status()
		_check(not status.exists and not status.backup_exists, "later disk progress cannot reappear in an absent restored campaign: " + str(pack.id))
	_check(not room.allow_legacy_auto_import, "an active profile suppresses automatic legacy resurrection")
	_check(room.settings_store.get_values() == preferences, "early restore also leaves preferences unchanged")
	full.show_manual_saves()
	var menu_panel = room.manual_save_panel
	menu_panel.cards[1].load.pressed.emit()
	menu_panel.confirmation.confirmed.emit()
	await tree.process_frame
	await tree.process_frame
	_check(room.manual_save_panel == menu_panel and tree.root.gui_get_focus_owner() == menu_panel.cards[1].load, "loading a menu checkpoint keeps keyboard focus on its Load action inside the manual modal")
	full._close_manual_saves()
	await _free_full(full)
	# Startup cannot fall back to old fixed files when the active profile is damaged.
	_write(active_path, "preserve-corrupt-active-pointer")
	var corrupt_bytes := FileAccess.get_file_as_bytes(active_path)
	full = await _new_full(base)
	room = full.room
	_check(room.profile_recovery_required and room.manual_save_panel != null, "corrupt active-profile startup opens the actual manual recovery UI")
	_check(not room.habitat_view().ready and room._desktops.is_empty() and room.manual_save_panel.cards[1].save.disabled, "corrupt profile blocks gameplay and manual saving instead of installing defaults")
	_check(FileAccess.get_file_as_bytes(active_path) == corrupt_bytes, "opening recovery preserves the damaged active pointer")
	room.manual_save_panel.cards[5].load.pressed.emit()
	_check(room.manual_save_panel.confirmation.visible, "a valid manual checkpoint remains loadable during startup recovery")
	room.manual_save_panel.confirmation.confirmed.emit()
	await tree.process_frame
	_check(not room.profile_recovery_required and full.capture_manual_profile().snapshots == expected[5].snapshots, "confirmed manual load recovers the entire profile after corrupt startup")
	full._close_manual_saves()
	var effects := EffectsProbe.new()
	full.desktop_effects.cancel()
	full.desktop_effects.queue_free()
	full.add_child(effects)
	full.desktop_effects = effects
	room.show_settings()
	room.settings_panel.desktop_effects_preview_requested.emit()
	_check(effects.previews == 1, "real settings panel forwards its preview request through Room to the full-game service")
	room.settings_panel.closed.emit()
	var completed_view: Dictionary = room.desktop.get_game_view()
	completed_view.completed = true
	full._last_view = {}
	full._on_view_changed(completed_view)
	_check(effects.stories.is_empty(), "loading an already-completed optional case does not trigger a story effect")
	full._last_view = completed_view.duplicate(true)
	full._last_view.mission_id = "I01"
	full._last_view.completed = false
	full._on_view_changed(completed_view)
	_check(effects.stories.is_empty(), "switching from another optional mission to completed I02 does not trigger a story effect")
	full._last_view = completed_view.duplicate(true)
	full._last_view.completed = false
	full._on_view_changed(completed_view)
	_check(effects.stories == ["investigation:I02"], "only an actual I02 incomplete-to-complete transition requests the optional story effect")
	full._last_view.completed = false
	full._on_view_changed(completed_view)
	_check(effects.stories.size() == 1, "the authored I02 story effect is requested at most once per session")
	await _free_full(full)
	await _active_backup_recovery()
	await _manual_backup_recovery()
	await _explicit_legacy_source_import()
	await _locale_geometry()
	await _lobby_action_geometry()
	await _autosave_retry_regression()
	Localization.set_locale(previous_locale)
	var after := _fingerprints()
	_fingerprint_folder("user://profiles", after)
	_check(after == protected, "all default campaign, habitat, profiles and preference paths remain unchanged")
	_remove_owned(test_root)
	return {"suite": "manual_profile_ui", "checks": checks, "failures": failures.duplicate(), "protected_paths": protected.size(), "limit": "Actual Godot scene methods, synthesized keys, layout geometry and isolated disk transactions. Native pixels, physical input and platform-specific window effects are separate."}


func _active_backup_recovery() -> void:
	var base := test_root + "/active_recovery.json"
	var full := await _new_full(base)
	var room = full.room
	room.open_desktop("new", "intruder", "independent")
	room.open_desktop("new", "defender", "independent")
	_check(full.save_manual_slot(1).ok and full.load_manual_slot(1).ok, "active-backup fixture uses a real selected generation")
	var damaged_path: String = room.campaign_slots.intruder
	var intruder = Campaign.new(damaged_path, "intruder")
	_check(intruder.load_game().ok, "active intruder fixture loads through its generation path")
	intruder.execute("mkdir ~/verified_backup")
	_check(intruder.save_game().ok, "active intruder creates its first autosave backup")
	var expected_intruder: Dictionary = intruder.export_snapshot()
	intruder.execute("mkdir ~/later_corrupt_primary")
	_check(intruder.save_game().ok, "active intruder preserves its latest valid predecessor as backup")
	room.desktop.game.execute("mkdir ~/latest_healthy_defender")
	_check(room.desktop.game.save_game().ok, "another active campaign keeps newer independent progress")
	_check(room.habitat_store.apply("set_lighting", {"lighting": "dawn"}).ok, "active habitat has a newer healthy state")
	var expected: Dictionary = full.capture_manual_profile()
	expected.snapshots.campaigns.intruder = expected_intruder
	_check(room.settings_store.update_settings({"master_volume": 0.38, "font_scale": 1.6, "locale": "de"}).ok, "backup recovery fixture has newer independent preferences")
	var preference_bytes := FileAccess.get_file_as_bytes(room.settings_path)
	var active_path := base.get_basename() + "_profiles/active.json"
	var pointer_before := FileAccess.get_file_as_bytes(active_path)
	var active_root := base.get_basename() + "_profiles/active_generations"
	var generations_before := DirAccess.get_directories_at(active_root)
	_write(damaged_path, "preserve-damaged-active-member")
	var damaged_before := FileAccess.get_file_as_bytes(damaged_path)
	await _free_full(full)

	full = await _new_full(base)
	room = full.room
	var panel = room.manual_save_panel
	_check(room.profile_recovery_required and panel != null and panel.active_recovery_button != null, "an invalid active member with a valid autosave backup has an explicit recovery action")
	_check(panel._recovery_status.manifest_source == "current" and panel._recovery_status.backup_members == ["intruder"], "recovery preview identifies the current profile and only the damaged campaign backup")
	panel.active_recovery_button.pressed.emit()
	_check(panel.confirmation.visible, "autosave backup recovery waits for an explicit whole-profile confirmation")
	panel.confirmation.canceled.emit()
	panel.confirmation.confirmed.emit()
	_check(FileAccess.get_file_as_bytes(active_path) == pointer_before and FileAccess.get_file_as_bytes(damaged_path) == damaged_before and DirAccess.get_directories_at(active_root) == generations_before, "reading and cancelling recovery stages nothing and preserves active/damaged bytes")
	panel.active_recovery_button.pressed.emit()
	panel.confirmation.confirmed.emit()
	await tree.process_frame
	var restored: Dictionary = full.capture_manual_profile()
	_check(restored.ok and restored.snapshots == expected.snapshots, "confirmed active recovery restores the valid backup while preserving latest healthy campaigns and habitat")
	_check(not room.profile_recovery_required and panel.active_recovery_button == null and not panel.cards[1].save.disabled, "successful backup recovery clears the blocked state and re-enables normal checkpoints")
	room.select_campaign("tracker")
	var new_game_enabled := false
	for button in room.menu_box.find_children("*", "Button", true, false):
		if button.get_meta("lobby_action", "") == "new": new_game_enabled = not button.disabled
	_check(new_game_enabled, "successful recovery immediately re-enables New Game for an unstarted campaign")
	_check(FileAccess.get_file_as_bytes(room.settings_path) == preference_bytes and FileAccess.get_file_as_bytes(damaged_path) == damaged_before, "backup recovery preserves independent preferences and the original damaged generation")
	full._close_manual_saves()
	await _free_full(full)
	full = await _new_full(base)
	_check(not full.room.profile_recovery_required and full.capture_manual_profile().snapshots == expected.snapshots, "restart resolves the complete recovered active profile")
	_check(full.room.menu.visible and not full.room._in_desktop and full.room._desktops.is_empty() and full.room.current_zone == "room", "restart opens the main menu without reapplying the old checkpoint desktop, zone or return context")
	await _free_full(full)


func _manual_backup_recovery() -> void:
	var base := test_root + "/manual_backup.json"
	var full := await _new_full(base)
	var room = full.room
	room.open_desktop("new", "intruder", "independent")
	var original: Dictionary = full.capture_manual_profile()
	_check(full.save_manual_slot(1).ok, "manual backup fixture has an original checkpoint")
	room.desktop.game.execute("mkdir ~/later_manual_slot")
	_check(full.save_manual_slot(1).ok, "manual overwrite preserves a separate checkpoint backup")
	var root := base.get_basename() + "_profiles"
	_write(root + "/slot_01.json", "preserve-damaged-manual-pointer")
	var damaged := FileAccess.get_file_as_bytes(root + "/slot_01.json")
	full.show_manual_saves()
	var panel = room.manual_save_panel
	_check(panel.cards[1].row.status == "damaged" and panel.cards[1].load.disabled and panel.cards[1].has("backup"), "a damaged manual checkpoint exposes a distinct valid backup action")
	panel.cards[1].backup.pressed.emit()
	_check(panel.confirmation.visible, "manual checkpoint backup loading requires explicit confirmation")
	panel.confirmation.canceled.emit()
	panel.confirmation.confirmed.emit()
	_check(FileAccess.get_file_as_bytes(root + "/slot_01.json") == damaged and not FileAccess.file_exists(root + "/active.json"), "cancelling manual backup load preserves damage and never creates an active pointer")
	panel.cards[1].backup.pressed.emit()
	panel.confirmation.confirmed.emit()
	var restored: Dictionary = full.capture_manual_profile()
	_check(restored.ok and restored.snapshots == original.snapshots, "confirmed backup action restores the original complete manual checkpoint")
	_check(FileAccess.get_file_as_bytes(root + "/slot_01.json") == damaged, "loading a slot backup leaves its damaged primary manifest untouched")
	full._close_manual_saves()
	await _free_full(full)


func _explicit_legacy_source_import() -> void:
	var source := test_root + "/preserved_source.json"
	var original = Campaign.new(source, "legacy_intruder")
	original.execute("mkdir ~/preserved_legacy_progress")
	_check(original.save_game().ok, "legacy import fixture uses an owned valid preserved-edition original")
	var original_bytes := FileAccess.get_file_as_bytes(source)
	var full := await _new_full(test_root + "/legacy_profile.json", source)
	var early: Dictionary = full.capture_manual_profile()
	_check(early.ok and early.snapshots.campaigns.legacy_intruder == null and full.save_manual_slot(1).ok, "manual capture preserves unimported legacy absence without requiring import")
	_check(full.load_manual_slot(1).ok, "early profile with an unimported legacy original activates normally")
	var room = full.room
	_check(not room.allow_legacy_auto_import and room.legacy_source_import_button.visible and not room.legacy_source_import_button.disabled and not room.legacy_continue_button.visible, "active profile offers an explicit legacy-source import instead of silently resurrecting absent progress")
	for language in Localization.LOCALES:
		Localization.set_locale(language)
		room._rebuild_menu()
		room.legacy_source_import_button.pressed.emit()
		_check(not room.legacy_source_import_button.text.begins_with("LEGACY_SOURCE_") and not room.confirm.dialog_text.begins_with("LEGACY_SOURCE_") and not room.confirm.title.begins_with("LEGACY_SOURCE_"), "explicit preserved-edition import labels resolve in " + language)
		room._cancel_menu_confirmation()
		room.confirm.hide()
	Localization.set_locale("ko")
	room._rebuild_menu()
	room.legacy_source_import_button.pressed.emit()
	_check(room.confirm.visible, "copying the preserved original requires confirmation")
	room._cancel_menu_confirmation()
	room.confirm.hide()
	room._on_menu_confirmed()
	_check(full.capture_manual_profile().snapshots.campaigns.legacy_intruder == null and FileAccess.get_file_as_bytes(source) == original_bytes, "cancelled legacy import preserves profile absence and original bytes")
	room.legacy_source_import_button.pressed.emit()
	room.confirm.hide()
	room._on_menu_confirmed()
	_check(room._in_desktop and room.desktop.pack_id == "legacy_intruder" and room.desktop.game.export_snapshot() == original.export_snapshot(), "confirmed explicit import resumes the preserved original through a separate active-generation copy")
	_check(FileAccess.get_file_as_bytes(source) == original_bytes and full.load_manual_slot(1).ok and full.capture_manual_profile().snapshots.campaigns.legacy_intruder == null, "restoring the early checkpoint still preserves absence after an explicit import, leaving the original intact")
	await _free_full(full)


func _panel_flow(full: Node) -> void:
	var room = full.room
	room.desktop._open_manual_saves()
	var panel = room.manual_save_panel
	_check(panel != null and panel.cards.size() == 5 and room.desktop._room_settings_open(), "footer opens five manual cards as a protected desktop modal")
	var f10 := InputEventKey.new()
	f10.keycode = KEY_F10
	f10.pressed = true
	room._input(f10)
	_check(room._in_desktop, "F10 cannot bypass the checkpoint modal")
	var before: Dictionary = full.capture_manual_profile()
	var rows_before: Array = full.manual_store.list_slots()
	panel.cards[2].save.pressed.emit()
	_check(panel.confirmation.visible, "overwriting a populated manual slot requires confirmation")
	panel.confirmation.canceled.emit()
	panel.confirmation.confirmed.emit()
	_check(full.manual_store.list_slots() == rows_before, "Cancel invalidates the overwrite callback and preserves all slots")
	var slot_root := str(full.manual_store.get("_root"))
	var overwritten_before := FileAccess.get_file_as_bytes(slot_root + "/slot_02.json")
	var other_slots := {}
	for index in [1, 3, 4, 5]:
		other_slots[index] = FileAccess.get_file_as_bytes(slot_root + "/slot_%02d.json" % index)
	panel.cards[2].save.pressed.emit()
	panel.confirmation.confirmed.emit()
	_check(FileAccess.get_file_as_bytes(slot_root + "/slot_02.json") != overwritten_before and panel.feedback.text == Localization.tr_key("MANUAL_SAVE_OK", {"slot": 2}), "confirmed overwrite changes the chosen checkpoint and shows its localized success")
	for index in other_slots:
		_check(FileAccess.get_file_as_bytes(slot_root + "/slot_%02d.json" % index) == other_slots[index], "overwriting slot 2 preserves another manual checkpoint: " + str(index))
	panel.cards[2].load.pressed.emit()
	_check(panel.confirmation.visible, "whole-profile loading requires confirmation")
	panel.confirmation.canceled.emit()
	panel.confirmation.confirmed.emit()
	_check(full.capture_manual_profile().snapshots == before.snapshots, "cancelled whole-profile load leaves every live model unchanged")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._input(escape)
	_check(room.manual_save_panel == null, "Escape closes the manual panel after cancelled confirmation")
	room.desktop._set_paused(true)
	room.desktop._open_manual_saves()
	_check(room.manual_save_panel != null and room.desktop.paused, "manual checkpoint panel is also available while paused")
	full._close_manual_saves()
	room.desktop._set_paused(false)


func _locale_geometry() -> void:
	var original_size := tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var physical_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var to_screen := tree.root.get_final_transform()
	var rows: Array = []
	for index in range(1, 6):
		rows.append({"index": index, "status": "valid" if index < 4 else ("empty" if index == 4 else "damaged"), "saved_at": Time.get_unix_time_from_system(), "pack_id": "investigation", "mission_id": "I02", "completed": 1, "total": 2, "code": "INVALID_CHECKPOINT", "backup_available": index == 5})
	for locale in Localization.LOCALES:
		Localization.set_locale(locale)
		var panel := ManualPanel.new()
		tree.root.add_child(panel)
		panel.setup(rows, 1.6)
		await tree.process_frame
		await tree.process_frame
		_check(panel.cards.size() == 5 and panel.cards[4].load.disabled and panel.cards[5].load.disabled and not panel.cards[5].save.disabled, "empty and damaged states have safe load/save actions in " + locale)
		_check(physical_rect.encloses(to_screen * panel.get_global_rect()), "large-font manual panel fits the viewport in " + locale)
		_check(panel.scroll.follow_focus and not panel.cards[1].save.focus_next.is_empty(), "keyboard focus is constrained to scrollable checkpoint actions in " + locale)
		panel.cards[1].load.pressed.emit()
		await tree.process_frame
		_check(panel.confirmation.dialog_autowrap and physical_rect.encloses(to_screen * Rect2(Vector2(panel.confirmation.position), Vector2(panel.confirmation.size))), "localized load confirmation fits the viewport at 1.6 scale in " + locale)
		for button in [panel.confirmation.get_ok_button(), panel.confirmation.get_cancel_button()]:
			var rect: Rect2 = button.get_global_rect()
			rect.position += Vector2(panel.confirmation.position)
			_check(physical_rect.encloses(to_screen * rect), "localized confirmation button is fully visible at 1.6 scale in " + locale + ": " + button.text)
		var unresolved := false
		for control in panel.find_children("*", "Control", true, false):
			if control is Label or control is Button:
				unresolved = unresolved or control.text.begins_with("MANUAL_") or control.text.contains("{slot}") or control.text.contains("{mission}")
		_check(not unresolved, "manual panel text resolves localized labels and placeholders in " + locale)
		panel.confirmation.canceled.emit()
		panel.cards[5].backup.pressed.emit()
		await tree.process_frame
		_check(not panel.confirmation.dialog_text.contains("MANUAL_") and not panel.confirmation.dialog_text.contains("{slot}") and not panel.confirmation.title.begins_with("MANUAL_"), "manual backup confirmation resolves labels and placeholders in " + locale)
		_check(physical_rect.encloses(to_screen * Rect2(Vector2(panel.confirmation.position), Vector2(panel.confirmation.size))), "large-font manual backup confirmation fits the viewport in " + locale)
		panel.queue_free()
		await tree.process_frame
		for source in ["current", "backup"]:
			var recovery := ManualPanel.new()
			tree.root.add_child(recovery)
			var members: Array = Catalog.ENTRIES.keys() + ["habitat"]
			recovery.setup(rows, 1.6, false, "PROFILE_INVALID_MEMBER", {"available": true, "manifest_source": source, "backup_members": members})
			await tree.process_frame
			recovery.active_recovery_button.pressed.emit()
			await tree.process_frame
			await tree.process_frame
			_check(physical_rect.encloses(to_screen * recovery.get_global_rect()), "large-font " + source + " recovery panel fits the viewport in " + locale)
			_check(physical_rect.encloses(to_screen * Rect2(Vector2(recovery.confirmation.position), Vector2(recovery.confirmation.size))), "large-font " + source + " recovery confirmation fits the viewport in " + locale + " (position=" + str(recovery.confirmation.position) + ", size=" + str(recovery.confirmation.size) + ")")
			for button in [recovery.confirmation.get_ok_button(), recovery.confirmation.get_cancel_button()]:
				var rect: Rect2 = button.get_global_rect()
				rect.position += Vector2(recovery.confirmation.position)
				_check(physical_rect.encloses(to_screen * rect), "large-font recovery button fits the viewport in " + locale + ": " + button.text)
			var unresolved_recovery := recovery.confirmation.dialog_text.contains("MANUAL_") or recovery.confirmation.dialog_text.contains("{members}")
			for control in recovery.find_children("*", "Control", true, false):
				if control is Label or control is Button:
					unresolved_recovery = unresolved_recovery or control.text.begins_with("MANUAL_") or control.text.contains("{members}")
			_check(not unresolved_recovery, "current/previous recovery labels resolve in " + locale)
			recovery.queue_free()
			await tree.process_frame
	tree.root.size = original_size
	await tree.process_frame


func _lobby_action_geometry() -> void:
	var original_size := tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var full := await _new_full(test_root + "/lobby_layout.json")
	var room = full.room
	var physical_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var to_screen := tree.root.get_final_transform()
	for language in Localization.LOCALES:
		_check(room.settings_store.update_settings({"font_scale": 1.6, "locale": language}).ok, "large-font lobby preferences apply in " + language)
		await tree.process_frame
		await tree.process_frame
		var first_choice: Button = room.campaign_buttons.intruder
		var choice_scroll: ScrollContainer = first_choice.get_parent().get_parent()
		_check(choice_scroll.get_global_rect().encloses(first_choice.get_global_rect()), "first campaign choice is fully visible before scrolling at 1.6 scale in " + language)
		for action in ["load", "settings", "enter_room", "quit", "manual_saves"]:
			var button: Button
			for candidate in room.menu_box.find_children("*", "Button", true, false):
				if candidate.get_meta("lobby_action", "") == action:
					button = candidate
					break
			_check(button != null and button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "lobby action preserves its complete label in " + language + ": " + action)
			if button == null: continue
			if action == "manual_saves":
				_check(button.get_parent() == room.menu_box and physical_rect.encloses(to_screen * button.get_global_rect()), "manual saves remains a visible fixed main-menu action in " + language)
			button.grab_focus()
			await tree.process_frame
			await tree.process_frame
			_check(physical_rect.encloses(to_screen * button.get_global_rect()), "keyboard scroll brings the complete lobby action into view in " + language + ": " + action)
			var font: Font = button.get_theme_font("font")
			var font_size := button.get_theme_font_size("font_size")
			var insets := button.get_theme_stylebox("normal").get_minimum_size()
			var available: Vector2 = button.size - insets
			var text_size: Vector2 = font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, available.x, font_size) if button.autowrap_mode != TextServer.AUTOWRAP_OFF else font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			_check(text_size.x <= available.x + 1 and text_size.y <= available.y + 1, "full lobby action text fits its button at 1.6 scale in " + language + ": " + action)
		for id in room.campaign_buttons:
			var campaign_button: Button = room.campaign_buttons[id]
			campaign_button.grab_focus()
			await tree.process_frame
			await tree.process_frame
			_check(physical_rect.encloses(to_screen * campaign_button.get_global_rect()), "campaign choice stays keyboard-reachable in " + language + ": " + str(id))
	await _free_full(full)
	tree.root.size = original_size
	await tree.process_frame


func _autosave_retry_regression() -> void:
	var full := await _new_full(test_root + "/autosave_retry.json")
	var room = full.room
	room.open_desktop("new", "intruder", "independent")
	var desktop = room.desktop
	var path: String = desktop.save_slot_path
	var before := FileAccess.get_file_as_bytes(path)
	_check(not desktop.autosave_suspended and not desktop.autosave_retry_btn.visible, "healthy autosave does not show a retry action")
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "owned autosave fixture blocks only its staging path")
	var action: Dictionary = desktop._act("terminal", desktop.game.execute.bind("mkdir ~/dirty_retry_progress"))
	var dirty: Dictionary = desktop.game.export_snapshot()
	_check(action.ok and desktop.autosave_suspended and desktop.autosave_retry_btn.visible and not desktop.autosave_retry_btn.disabled and FileAccess.get_file_as_bytes(path) == before, "real action IO failure suspends autosave and exposes its distinct retry action without changing saved bytes")
	desktop._set_paused(true)
	_check(desktop.autosave_retry_btn.disabled, "paused sessions cannot retry autosave")
	desktop._set_paused(false)
	_check(not desktop.autosave_retry_btn.disabled, "resuming the session enables retry without reloading progress")
	desktop._open_manual_saves()
	room.manual_save_panel.cards[1].save.pressed.emit()
	_check(full.manual_store.list_slots()[0].status == "valid" and desktop.autosave_suspended and FileAccess.get_file_as_bytes(path) == before, "saving one of five manual checkpoints never claims that the original autosave resumed")
	full._close_manual_saves()
	_check(DirAccess.remove_absolute(path + ".tmp") == OK, "owned autosave IO failure is repaired")
	desktop.autosave_retry_btn.pressed.emit()
	var reloaded = Campaign.new(path, "intruder")
	_check(not desktop.autosave_suspended and not desktop.autosave_retry_btn.visible and reloaded.load_game().ok and reloaded.export_snapshot() == dirty, "retry button writes the dirty current campaign and resumes autosave without losing progress")
	for language in Localization.LOCALES:
		Localization.set_locale(language)
		desktop.apply_settings({"support_intruder": "independent"})
		_check(desktop.autosave_retry_btn.tooltip_text == Localization.tr_key("MANUAL_AUTOSAVE_RETRY") and not desktop.autosave_retry_btn.tooltip_text.begins_with("MANUAL_"), "autosave retry has a distinct localized accessible action in " + language)
	await _free_full(full)


func _new_full(base: String, legacy_source: String = "") -> Node:
	var full := FullScene.instantiate()
	full.save_slot_path = base
	full.legacy_source_override = legacy_source
	tree.root.add_child(full)
	await tree.process_frame
	await tree.process_frame
	return full


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "owned test fixture is writable")
	if file != null:
		file.store_string(value)
		file.close()


func _free_full(full: Node) -> void:
	full.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(full.desktop_effects): full.desktop_effects.cancel()
	var players: Array[Node] = full.audio.find_children("*", "AudioStreamPlayer", true, false)
	for player in players: player.stop()
	for index in range(3): await tree.process_frame
	for player in players: player.stream = null
	await tree.create_timer(0.15).timeout
	full.queue_free()
	await tree.process_frame
	await tree.process_frame
