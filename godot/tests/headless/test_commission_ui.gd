extends "res://tests/headless/test_desktop_shell.gd"

const FullScene = preload("res://scenes/full_game.tscn")
const CommissionGame = preload("res://scripts/core/campaign_game.gd")


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	tree = scene_tree
	var protected := _fingerprints()
	test_root = "user://tests/commission_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(test_root)
	var full := FullScene.instantiate()
	full.save_slot_path = test_root + "/campaign.json"
	tree.root.add_child(full)
	await tree.process_frame
	await tree.process_frame
	var room = full.room
	_check(room.campaign_buttons.size() == 4 and not room.campaign_buttons.has("investigation"), "optional commission does not become a fifth main choice")
	room.open_desktop("new", "intruder", "independent")
	await tree.process_frame
	var main: Control = room.desktop
	main._open_terminal(0)
	main.terms[0].input.text = "unsent-main-draft"
	main.game.get_hint(1)
	var main_snapshot: Dictionary = main.game.export_snapshot()
	var main_hint: int = main.game.get_view().hint_level
	var main_disk := FileAccess.get_file_as_bytes(room.campaign_slots.intruder)
	main._open_current_board()
	main._show_commissions()
	_check(main.commission_panel.visible and main.commission_list.get_child_count() == 2, "case board offers two independent optional commissions")
	main.commission_panel.hide()
	_check(main.game.export_snapshot() == main_snapshot and main.game.get_view().hint_level == main_hint, "opening and cancelling commission list does not affect main progress or hints")
	_test_commission_recovery(room, main, main_snapshot, main_disk)
	var slot: String = room.campaign_slots.investigation
	DirAccess.make_dir_absolute(slot + ".tmp")
	var failed: Dictionary = room.open_commission("I02")
	_check(not failed.ok and room.desktop == main and main.visible, "failed independent save leaves current main desktop visible")
	_check(main.game.export_snapshot() == main_snapshot and FileAccess.get_file_as_bytes(room.campaign_slots.intruder) == main_disk, "failed commission entry cannot write main slot")
	DirAccess.remove_absolute(slot + ".tmp")
	var opened: Dictionary = room.open_commission("I02")
	await tree.process_frame
	_check(opened.ok and room.desktop.pack_id == "investigation", "second commission starts directly without first completion")
	var optional: Control = room.desktop
	_check(optional.get_game_view().mission_id == "I02" and optional.get_game_view().mode == "commissions", "selected optional mission and mode are explicit")
	_check(optional.get_game_view().endings.is_empty() and not optional._main_complete(optional.get_game_view()), "empty main list never unlocks a campaign ending")
	_check(not optional.game.choose_ending("fake").ok, "commission ending choice is rejected")
	optional._open_app("tools", true)
	var kinds: Array = optional.get_game_view().tools.map(func(tool): return tool.kind)
	_check(kinds.has("release_case"), "release commission exposes a structured model tool")
	var i02_snapshot: Dictionary = optional.game.export_snapshot()
	room.return_from_commission()
	await tree.process_frame
	_check(room.desktop == main and main.visible, "return resumes the original desktop instance")
	_check(main.terms[0].input.text == "unsent-main-draft" and main.game.get_view().hint_level == main_hint, "return retains main terminal draft and hint state")
	_check(main.game.export_snapshot() == main_snapshot and FileAccess.get_file_as_bytes(room.campaign_slots.intruder) == main_disk, "optional entry and return preserve main world and disk bytes")
	_check(room.open_commission("I01").ok, "first commission can start independently after second")
	await tree.process_frame
	var first: Control = room.desktop
	_check(first.get_game_view().mission_id == "I01", "first commission selected")
	_check(first.game.export_snapshot().mission_states.has("I02") and first.game.export_snapshot().mission_states.I02 == i02_snapshot.current_world, "switching commission preserves the other commission checkpoint")
	_check(room.open_commission("I02").ok and room.desktop.get_game_view().mission_id == "I02", "second commission resumes independently")
	room.return_from_commission()
	_check(room.desktop == main and room.campaign_buttons.size() == 4, "main menu choices and cached main remain unchanged after repeated optional switches")
	_test_cached_commission_recovery(room, main, first, main_snapshot, main_disk)
	# Match the product's graceful audio drain without quitting this test SceneTree.
	full.process_mode = Node.PROCESS_MODE_DISABLED
	var players: Array[Node] = full.audio.find_children("*", "AudioStreamPlayer", true, false)
	for player in players:
		player.stop()
	for index in range(3):
		await tree.process_frame
	for player in players:
		player.stream = null
	await tree.create_timer(0.15).timeout
	full.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(_fingerprints() == protected, "all default user slots and preferences remain unchanged")
	_remove_owned(test_root)
	return {"suite": "commission_ui", "checks": checks, "failures": failures.duplicate(), "protected_paths": protected.size(), "limit": "Actual scene methods and isolated disk; native input, pixels and physical OS are separate."}


func _test_commission_recovery(room: Node, main: Control, main_snapshot: Dictionary, main_disk: PackedByteArray) -> void:
	var original_slot: String = room.campaign_slots.investigation
	var slot := test_root + "/recovery.json"
	room.campaign_slots.investigation = slot
	var fixture = CommissionGame.new(slot, "investigation")
	fixture.choose_mission("I02")
	_check(fixture.save_game().ok and fixture.save_game().ok, "recovery fixture has a valid optional save and backup")
	var backup := FileAccess.get_file_as_bytes(slot + ".bak")
	DirAccess.remove_absolute(slot)
	_check(not room.open_commission("I01").ok and not FileAccess.file_exists(slot) and FileAccess.get_file_as_bytes(slot + ".bak") == backup, "direct optional entry refuses a missing primary with a valid backup and preserves its checkpoint")
	_write_commission_bytes(slot, backup)
	var damaged := "{damaged optional save".to_utf8_buffer()
	_write_commission_bytes(slot, damaged)
	main._show_commissions()
	_check(_commission_repair_button(main, "recover") != null and _commission_repair_button(main, "fresh") != null, "corrupt optional save shows both explicit recovery choices")
	_check(FileAccess.get_file_as_bytes(slot) == damaged and not room.open_commission("I01").ok, "opening chooser and attempting entry never overwrite corrupt optional save")
	_commission_repair_button(main, "recover").pressed.emit()
	_check(main.confirm.visible and FileAccess.get_file_as_bytes(slot) == damaged, "optional backup recovery waits for confirmation")
	main.confirm.canceled.emit()
	main._on_confirmed()
	_check(FileAccess.get_file_as_bytes(slot) == damaged, "cancelled recovery invalidates its pending callback")
	_commission_repair_button(main, "recover").pressed.emit()
	main.confirm.hide()
	main._on_confirmed()
	_check(FileAccess.get_file_as_bytes(slot) == backup and _commission_preserved_bytes(slot, damaged), "confirmed backup recovery restores optional checkpoint and preserves damaged bytes")
	_check(main.commission_list.get_child_count() == 2 and _commission_repair_button(main, "recover") == null, "recovered chooser offers both missions again")
	var recovered = CommissionGame.new(slot, "investigation")
	_check(recovered.load_game().ok and recovered.get_view().mission_id == "I02", "recovered optional checkpoint retains its selected mission")
	DirAccess.remove_absolute(slot + ".bak")
	_write_commission_bytes(slot, damaged)
	main._show_commissions()
	_check(_commission_repair_button(main, "recover") == null and _commission_repair_button(main, "fresh") != null, "without a valid backup only preserved fresh save is offered")
	DirAccess.make_dir_absolute(slot + ".tmp")
	_commission_repair_button(main, "fresh").pressed.emit()
	_check(main.confirm.visible and FileAccess.get_file_as_bytes(slot) == damaged, "fresh optional save also waits for confirmation")
	main.confirm.hide()
	main._on_confirmed()
	_check(FileAccess.get_file_as_bytes(slot) == damaged and _commission_repair_button(main, "fresh") != null, "failed fresh save preserves damaged file and leaves retry available")
	_check(room.desktop == main and main.game.export_snapshot() == main_snapshot and FileAccess.get_file_as_bytes(room.campaign_slots.intruder) == main_disk and main.terms[0].input.text == "unsent-main-draft", "failed optional repair preserves main desktop, world, disk and terminal draft")
	DirAccess.remove_absolute(slot + ".tmp")
	_commission_repair_button(main, "fresh").pressed.emit()
	main.confirm.hide()
	main._on_confirmed()
	var fresh = CommissionGame.new(slot, "investigation")
	_check(fresh.load_game().ok and fresh.get_view().mission_id == "I01" and _commission_preserved_bytes(slot, damaged), "confirmed fresh save creates initial optional checkpoint and keeps damaged original")
	DirAccess.remove_absolute(slot)
	var damaged_backup := "{damaged backup without primary".to_utf8_buffer()
	_write_commission_bytes(slot + ".bak", damaged_backup)
	var status: Dictionary = fresh.get_save_status()
	_check(status.backup_exists and not status.backup_available and not status.exists, "save status distinguishes an invalid backup from an absent backup")
	var orphan_entry: Dictionary = room.open_commission("I01")
	_check(not orphan_entry.ok and not FileAccess.file_exists(slot) and FileAccess.get_file_as_bytes(slot + ".bak") == damaged_backup, "direct optional entry refuses invalid orphan backup until explicit preserved fresh recovery")
	main._show_commissions()
	_check(_commission_repair_button(main, "recover") == null and _commission_repair_button(main, "fresh") != null, "missing primary with invalid backup still offers preserved fresh recovery")
	_commission_repair_button(main, "fresh").pressed.emit()
	main.confirm.hide()
	main._on_confirmed()
	_check(fresh.load_game().ok and _commission_preserved_bytes(slot + ".bak", damaged_backup), "fresh recovery preserves an invalid orphaned backup")
	_check(room.desktop == main and main.game.export_snapshot() == main_snapshot and FileAccess.get_file_as_bytes(room.campaign_slots.intruder) == main_disk and not main.autosave_suspended, "successful optional repairs preserve main cached progress, disk and autosave")
	room.campaign_slots.investigation = original_slot
	main.commission_panel.hide()


func _commission_repair_button(main: Control, action: String) -> Button:
	for child in main.commission_list.get_children():
		if child is Button and child.get_meta("commission_repair", "") == action:
			return child
	return null


func _test_cached_commission_recovery(room: Node, main: Control, optional: Control, main_snapshot: Dictionary, main_disk: PackedByteArray) -> void:
	var slot: String = room.campaign_slots.investigation
	var damaged := "{damaged cached optional save".to_utf8_buffer()
	var cached_snapshot: Dictionary = optional.game.export_snapshot()
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(slot + ".bak"))
	var expected = CommissionGame.new(slot, "investigation")
	_check(expected.restore_snapshot(backup).ok, "cached recovery reference uses the validated backup snapshot")
	_write_commission_bytes(slot, damaged)
	main._show_commissions()
	_check(_commission_repair_button(main, "recover") != null, "cached optional progress does not hide disk corruption from chooser")
	DirAccess.make_dir_absolute(slot + ".tmp")
	_commission_repair_button(main, "recover").pressed.emit()
	main.confirm.hide()
	main._on_confirmed()
	_check(FileAccess.get_file_as_bytes(slot) == damaged and optional.game.export_snapshot() == cached_snapshot, "failed backup repair preserves damaged bytes and cached optional progress")
	DirAccess.remove_absolute(slot + ".tmp")
	_commission_repair_button(main, "recover").pressed.emit()
	main.confirm.hide()
	main._on_confirmed()
	_check(optional.game.export_snapshot() == expected.export_snapshot() and _commission_preserved_bytes(slot, damaged), "successful backup repair updates cached optional session to recovered checkpoint")
	_check(room.desktop == main and main.visible and main.game.export_snapshot() == main_snapshot and FileAccess.get_file_as_bytes(room.campaign_slots.intruder) == main_disk and main.terms[0].input.text == "unsent-main-draft", "cached optional recovery preserves main visibility, progress, disk and terminal draft")
	main.commission_panel.hide()


func _write_commission_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _commission_preserved_bytes(path: String, bytes: PackedByteArray) -> bool:
	for file in DirAccess.get_files_at(path.get_base_dir()):
		if file.begins_with(path.get_file().trim_suffix(".json") + ".damaged_") and FileAccess.get_file_as_bytes(path.get_base_dir().path_join(file)) == bytes:
			return true
	return false
