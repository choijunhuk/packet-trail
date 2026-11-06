extends RefCounted

const Profiles = preload("res://scripts/core/manual_profile_store.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Habitat = preload("res://scripts/core/habitat_store.gd")
const Store = preload("res://scripts/core/save_store.gd")

var checks := 0
var failures: Array[String] = []
var skipped: Array[String] = []
var root := ""
var fixture: Dictionary = {}
var context := {"pack_id": "intruder", "mode": "desktop", "zone": "courtyard", "return_pack_id": "defender"}

class FinalRenameFailure:
	extends Profiles
	var obstruct_after_history := true

	func _mark_active_selected() -> Dictionary:
		var marked: Dictionary = super._mark_active_selected()
		if marked.ok and obstruct_after_history: DirAccess.make_dir_absolute(_active_path)
		return marked


func run() -> Dictionary:
	root = "user://tests/manual_profile_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var before: Dictionary = _protected()
	fixture = {"campaigns": {}, "habitat": Habitat.new().export_snapshot()}
	for id in Catalog.ENTRIES: fixture.campaigns[id] = null
	fixture.campaigns.intruder = Campaign.new(root + "/fixture.json", "intruder").export_snapshot()
	_test_slots_and_restore()
	_test_damage_and_paths()
	_test_size()
	_test_retention()
	_test_capacity()
	_test_active_recovery()
	_test_manual_backup()
	_test_review_data_retention()
	_test_first_commit_history()
	_check(_protected() == before, "fixed campaign saves, backups and settings remain byte-identical")
	_remove_tree(root)
	return {"suite": "manual_profile_store", "checks": checks, "failures": failures, "skipped": skipped}


func _test_slots_and_restore() -> void:
	var store = Profiles.new(root + "/basic")
	var initial: Dictionary = store.resolve_paths()
	_check(initial.ok and not initial.active, "never-created active pointer uses fixed paths")
	_check(initial.campaign_slots.intruder.begins_with(root + "/") and initial.habitat_path.begins_with(root + "/"), "isolated profile roots never return production fallback paths")
	_check(store.list_slots().size() == 5, "always exactly five slots")
	for index in range(1, 6):
		_check(store.save_slot(index, fixture, context).ok, "manual slot %d saves" % index)
	var other: PackedByteArray = _bytes(store._slot_path(2))
	_check(store.save_slot(1, fixture, context).ok and _bytes(store._slot_path(2)) == other, "overwrite changes only selected slot manifest")
	var rows: Array = store.list_slots()
	for row in rows: _check(row.status == "valid" and row.index >= 1 and row.index <= 5, "saved slot summary is valid")
	_check(rows[0].pack_id == "intruder" and rows[0].mission_id == "M01" and rows[0].completed == 0 and rows[0].total == 28 and typeof(rows[0].saved_at) == TYPE_INT and absi(rows[0].saved_at - int(Time.get_unix_time_from_system())) < 10, "summary derives campaign progress and actual UTC timestamp")
	_check(not store.save_slot(0, fixture, context).ok and not store.prepare_restore(6).ok, "out-of-range slot index rejected")
	var prepared: Dictionary = store.prepare_restore(1)
	_check(prepared.ok, "restore stages a separate active generation")
	if not prepared.ok: return
	_check(not store.resolve_paths().active, "preparation alone leaves current profile unchanged")
	var replacement = Campaign.new(prepared.paths.campaign_slots.intruder, "intruder")
	_check(replacement.load_game().ok, "prepared campaign loads before pointer commit")
	_check(Habitat.new(prepared.paths.habitat_path).load_state().ok, "prepared habitat loads before pointer commit")
	prepared.context.pack_id = "tracker"
	prepared.paths.habitat_path = "user://saves/evil.json"
	_check(store.commit_restore(prepared).ok, "validated opaque preparation commits")
	var resolved: Dictionary = Profiles.new(root + "/basic").resolve_paths()
	_check(resolved.ok and resolved.active and resolved.context == context, "restart resolves committed context without trusting caller metadata")
	_check(not FileAccess.file_exists(resolved.campaign_slots.defender), "absent campaign stays absent after restore")
	_check(Campaign.new(resolved.campaign_slots.defender, "defender").save_game().ok, "new campaign autosaves into restored active generation")
	_check(Profiles.new(root + "/basic").resolve_paths().ok, "later autosave of an absent campaign remains valid on restart")
	var first_pointer: PackedByteArray = _bytes(store._active_path)
	var second: Dictionary = store.prepare_restore(2)
	_check(second.ok, "second restore is ready")
	if not second.ok: return
	DirAccess.make_dir_absolute(store._active_path + ".tmp")
	_check(not store.commit_restore(second).ok, "failure before commit rejects restore")
	_check(_bytes(store._active_path) == first_pointer and Profiles.new(root + "/basic").resolve_paths().ok, "failed restore keeps previous active profile across restart")
	DirAccess.remove_absolute(store._active_path + ".tmp")
	_check(store.commit_restore(second).ok, "prepared restore retries after a reversible disk obstruction")
	_check(not store.commit_restore(second).ok, "consumed prepared token cannot replay")
	var active: Dictionary = store.resolve_paths()
	var active_campaign: String = active.campaign_slots.intruder
	var active_bytes: String = _bytes(active_campaign).get_string_from_utf8()
	DirAccess.remove_absolute(active_campaign)
	_check(not store.resolve_paths().ok, "deleted required active campaign cannot become a fresh campaign")
	_write(active_campaign, active_bytes)
	var changed: Dictionary = store.prepare_restore(1)
	if changed.ok:
		var modified: Dictionary = fixture.habitat.duplicate(true)
		modified.actions.append({"action": "set_lighting", "params": {"lighting": "dawn"}})
		modified.state.lighting = "dawn"
		_write(changed.paths.habitat_path, JSON.stringify(modified))
		_check(not store.commit_restore(changed).ok, "even valid external edits to a prepared generation cannot change confirmed contents")
	_write(store._active_path, "{damaged")
	_check(not Profiles.new(root + "/basic").resolve_paths().ok, "damaged active pointer never falls back to original saves")
	var valid_backup: Dictionary = JSON.parse_string(_bytes(store._active_path + ".bak").get_string_from_utf8())
	var repair: Dictionary = store.prepare_restore(3)
	_check(repair.ok and store.commit_restore(repair).ok and Profiles.new(root + "/basic").resolve_paths().ok, "explicit valid manual restore repairs a damaged active pointer")
	_check(store._read_generation(valid_backup).ok and JSON.parse_string(_bytes(store._active_path + ".bak").get_string_from_utf8()).generation == valid_backup.generation, "repair retains the valid previous backup and its referenced generation")
	var preserved := false
	for file in DirAccess.get_files_at(store._active_path.get_base_dir()):
		if file.begins_with("active.json.damaged.") and _bytes(store._active_path.get_base_dir().path_join(file)).get_string_from_utf8() == "{damaged": preserved = true
	_check(preserved, "explicit repair preserves damaged pointer bytes")
	_write(store._active_path, "x".repeat(200000))
	var oversized_repair: Dictionary = store.prepare_restore(3)
	_check(oversized_repair.ok and store.commit_restore(oversized_repair).ok, "oversized damaged pointer preserves and recovers using bounded memory")
	var oversized_preserved := false
	for file in DirAccess.get_files_at(store._active_path.get_base_dir()):
		if file.begins_with("active.json.damaged.") and _bytes(store._active_path.get_base_dir().path_join(file)).size() == 200000: oversized_preserved = true
	_check(oversized_preserved, "chunked pointer preservation keeps every oversized damaged byte")
	DirAccess.remove_absolute(store._active_path)
	_check(not store.resolve_paths().ok, "missing active pointer with existing backup cannot reset to fixed paths")


func _test_damage_and_paths() -> void:
	var store = Profiles.new(root + "/damage")
	_check(store.save_slot(1, fixture, context).ok, "damage fixture saves")
	var pointer: String = store._slot_path(1)
	var original: String = _bytes(pointer).get_string_from_utf8()
	for field in ["profile_version", "generation", "campaigns", "context", "unknown_path"]:
		var bad: Dictionary = JSON.parse_string(original)
		match field:
			"profile_version": bad.profile_version = 99
			"generation": bad.generation = "../../saves"
			"campaigns": bad.campaigns.append("foreign")
			"context": bad.context.pack_id = "foreign"
			"unknown_path": bad["path"] = "user://saves/intruder_v2_01.json"
		_write(pointer, JSON.stringify(bad))
		_check(store.list_slots()[0].status == "damaged" and not store.prepare_restore(1).ok, "reject damaged manifest field " + field)
	_write(pointer, original)
	var manifest: Dictionary = JSON.parse_string(original)
	var member: String = store._paths(manifest).campaign_slots.intruder
	var saved: String = _bytes(member).get_string_from_utf8()
	for field in ["campaign_id", "content_version", "current_world"]:
		var bad: Dictionary = JSON.parse_string(saved)
		match field:
			"campaign_id": bad.campaign_id = "foreign"
			"content_version": bad.content_version = 999
			"current_world": bad.current_world.completed = true
		_write(member, JSON.stringify(bad))
		_check(not store.prepare_restore(1).ok, "campaign validator rejects corrupt member " + field)
	_write(member, saved)
	var invalid: Dictionary = fixture.duplicate(true)
	invalid["settings"] = {"locale": "en"}
	_check(not store.save_slot(2, invalid, context).ok, "settings are outside profile snapshot schema")
	var absent: Dictionary = fixture.duplicate(true)
	absent.campaigns.intruder = null
	_check(not store.save_slot(2, absent, context).ok, "desktop context requires a selected campaign snapshot")
	var menu_context: Dictionary = context.duplicate(true)
	menu_context.mode = "menu"
	_check(store.save_slot(2, absent, menu_context).ok, "menu context can preserve a never-started campaign")
	var menu_path: String = store._slot_path(2)
	var altered: Dictionary = JSON.parse_string(_bytes(menu_path).get_string_from_utf8())
	altered.context.mode = "desktop"
	_write(menu_path, JSON.stringify(altered))
	_check(store.list_slots()[1].status == "damaged" and not store.prepare_restore(2).ok, "edited desktop context cannot activate a missing campaign")
	for path in ["", "user://profiles/../saves", "user://tests/../saves", "user://tests/root/", "user://tests/a\\b", "res://profiles", "user://tests/\n"]:
		var rejected = Profiles.new(path)
		_check(not rejected.resolve_paths().ok and not rejected.save_slot(1, fixture, context).ok, "invalid storage root fails closed: " + path)
	_check(Habitat._generated_profile_path("user://saves/profile_generations/g_" + "a".repeat(32) + "/habitat.json"), "fixed generated habitat path accepted")
	_check(not Habitat._generated_profile_path("user://saves/profile_generations/g_" + "a".repeat(32) + "/../habitat.json"), "generated habitat traversal rejected")
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var target: String = root + "/link_target.json"
		_write(target, saved)
		DirAccess.remove_absolute(member)
		var linked: int = OS.execute("/bin/ln", ["-s", ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(member)])
		_check(linked == 0 and not store.prepare_restore(1).ok, "symlinked profile member rejected")
		DirAccess.remove_absolute(member)
		_write(member, saved)
		var root_link: String = root + "/linked"
		linked = OS.execute("/bin/ln", ["-s", ProjectSettings.globalize_path(root + "/damage"), ProjectSettings.globalize_path(root_link)])
		_check(linked == 0 and not Profiles.new(root_link).resolve_paths().ok, "symlinked profile root rejected")
		DirAccess.remove_absolute(root_link)
	else: skipped.append("symlink fixtures require Unix ln")


func _test_size() -> void:
	var store = Profiles.new(root + "/sizes")
	var large: Dictionary = fixture.duplicate(true)
	var combined := 0
	for id in Catalog.ENTRIES:
		var snapshot: Dictionary = Campaign.new(root + "/large_" + id + ".json", id).export_snapshot()
		for index in range(400):
			snapshot.current_world.local_files["/home/player/" + "x".repeat(500) + str(index)] = {"kind": "dir", "owner": "player", "group": "player", "mode": "700", "content": "", "record_id": "", "source": ""}
		snapshot.mission_states[snapshot.current_mission] = snapshot.current_world.duplicate(true)
		large.campaigns[id] = snapshot
		combined += JSON.stringify(snapshot).to_utf8_buffer().size()
	_check(combined > Store.MAX_BYTES, "combined profile fixture exceeds the former single-file 2 MiB envelope")
	var result: Dictionary = store.save_slot(1, large, context)
	_check(result.ok, "profile larger than 2 MiB saves with unchanged per-campaign limits: " + str(result.get("text")))
	if result.ok:
		_check(store.prepare_restore(1).ok, "large profile restores member by member")
	var manifest: Dictionary = JSON.parse_string(_bytes(store._slot_path(1)).get_string_from_utf8())
	if manifest is Dictionary:
		var member: String = store._paths(manifest).campaign_slots.intruder
		_write(member, " ".repeat(Store.MAX_BYTES + 1))
		_check(not store.prepare_restore(1).ok, "oversized individual campaign member rejected")
	var huge: Dictionary = fixture.duplicate(true)
	huge.campaigns.intruder.ending = "x".repeat(Store.MAX_BYTES + 1)
	_check(not store.save_slot(2, huge, context).ok, "oversized campaign input cannot create a manual slot")
	var bad_room: Dictionary = fixture.duplicate(true)
	bad_room.habitat.state.balance += 1
	_check(not store.save_slot(3, bad_room, context).ok, "habitat economy remains replay validated")


func _test_retention() -> void:
	var store = Profiles.new(root + "/retention")
	var all_saved := true
	for index in range(105):
		if not store.save_slot(1 + index % 5, fixture, context).ok: all_saved = false
	_check(all_saved, "over one hundred manual saves remain usable")
	_check(DirAccess.get_directories_at(store._generation_root("manual")).size() <= 10, "managed generation count is bounded by five current and backup pointers")
	var backup: Dictionary = JSON.parse_string(_bytes(store._slot_path(1) + ".bak").get_string_from_utf8())
	_check(store._read_generation(backup).ok, "manual manifest backup still references intact members after collection")
	var orphan: String = store._generation_root("manual") + "/g_" + "f".repeat(32)
	DirAccess.make_dir_recursive_absolute(orphan)
	_write(orphan + "/generation.json", JSON.stringify({"profile_version": 1, "kind": "manual", "generation": "g_" + "f".repeat(32)}))
	_write(orphan + "/intruder.json", "{incomplete internal generation")
	_write(store._slot_path(5), "{broken pointer")
	_check(store.save_slot(2, fixture, context).ok and DirAccess.dir_exists_absolute(orphan), "one damaged manifest inhibits generation cleanup")
	_check(store.save_slot(5, fixture, context).ok and FileAccess.file_exists(orphan + "/quarantine.json"), "explicit slot replacement quarantines generations whose ownership of progress became uncertain")
	var unknown: String = store._generation_root("manual") + "/g_" + "e".repeat(32)
	DirAccess.make_dir_recursive_absolute(unknown)
	_write(unknown + "/user_notes.txt", "keep")
	_check(store.save_slot(2, fixture, context).ok and FileAccess.file_exists(unknown + "/user_notes.txt"), "unrecognized contents are never treated as owned generation files")
	var hidden: String = store._generation_root("manual") + "/g_" + "d".repeat(32)
	DirAccess.make_dir_recursive_absolute(hidden)
	_write(hidden + "/generation.json", JSON.stringify({"profile_version": 1, "kind": "manual", "generation": "g_" + "d".repeat(32)}))
	_write(hidden + "/.user_note", "keep hidden")
	_check(store.save_slot(2, fixture, context).ok and FileAccess.file_exists(hidden + "/generation.json") and FileAccess.file_exists(hidden + "/.user_note"), "hidden unknown entries prevent all deletion in a generation")
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var linked: String = store._generation_root("manual") + "/g_" + "c".repeat(32)
		DirAccess.make_dir_recursive_absolute(linked)
		_write(linked + "/generation.json", JSON.stringify({"profile_version": 1, "kind": "manual", "generation": "g_" + "c".repeat(32)}))
		var user_file: String = root + "/protected_user_file.json"
		_write(user_file, "keep outside generation")
		var link_error: int = OS.execute("/bin/ln", ["-s", ProjectSettings.globalize_path(user_file), ProjectSettings.globalize_path(linked + "/intruder.json")])
		_check(link_error == 0 and store.save_slot(2, fixture, context).ok and FileAccess.file_exists(linked + "/generation.json") and _bytes(user_file).get_string_from_utf8() == "keep outside generation", "garbage collection leaves a linked generation and its target untouched")
	for index in range(15):
		var prepared: Dictionary = store.prepare_restore(1)
		_check(prepared.ok and store.commit_restore(prepared).ok, "repeated active profile switch %d" % index)
	_check(DirAccess.get_directories_at(store._generation_root("active")).size() <= 2, "active current and backup generations retained without growth")
	var active_backup: Dictionary = JSON.parse_string(_bytes(store._active_path + ".bak").get_string_from_utf8())
	_check(store._read_generation(active_backup).ok, "active manifest backup remains recoverable after collection")


func _test_capacity() -> void:
	var store = Profiles.new(root + "/capacity")
	_check(store.save_slot(1, fixture, context).ok, "capacity fixture saves")
	var original: PackedByteArray = _bytes(store._slot_path(1))
	_write(store._slot_path(5), "{damaged manifest inhibits cleanup")
	for index in range(Profiles.MAX_GENERATIONS - 1):
		var generation: String = "g_" + str(index).pad_zeros(32)
		var directory: String = store._generation_root("manual").path_join(generation)
		DirAccess.make_dir_recursive_absolute(directory)
		_write(directory + "/generation.json", JSON.stringify({"profile_version": 1, "kind": "manual", "generation": generation}))
	var result: Dictionary = store.save_slot(2, fixture, context)
	_check(not result.ok and result.code == "PROFILE_CAPACITY_LIMIT" and _bytes(store._slot_path(1)) == original, "inhibited collection has a bounded capacity error while preserving existing slots")


func _test_active_recovery() -> void:
	var store = Profiles.new(root + "/active_recovery")
	_check(store.get_active_recovery_status().ok and not store.get_active_recovery_status().available, "no active profile has no automatic backup recovery")
	_check(store.save_slot(1, fixture, context).ok, "active recovery checkpoint saves")
	var initial: Dictionary = store.prepare_restore(1)
	_check(initial.ok and store.commit_restore(initial).ok, "active recovery fixture starts")
	if not initial.ok: return
	var paths: Dictionary = store.resolve_paths()
	var old_generation: String = paths.habitat_path.get_base_dir()
	var game = Campaign.new(paths.campaign_slots.intruder, "intruder")
	_check(game.load_game().ok and game.execute("mkdir ~/autosave_after_checkpoint").ok and game.save_game().ok, "ordinary campaign autosave creates its existing backup")
	var habitat = Habitat.new(paths.habitat_path)
	_check(habitat.load_state().ok and habitat.apply("set_lighting", {"lighting": "dawn"}).ok, "ordinary room autosave creates its existing backup")
	var new_pack = Campaign.new(paths.campaign_slots.defender, "defender")
	_check(new_pack.save_game().ok and new_pack.execute("mkdir ~/new_pack_after_checkpoint").ok and new_pack.save_game().ok, "campaign started after checkpoint creates an independent autosave backup")
	var healthy: Dictionary = store.get_active_recovery_status()
	_check(healthy.ok and not healthy.available and healthy.backup_members.is_empty(), "healthy originals take precedence over older autosave backups")
	_write(paths.campaign_slots.intruder, "{damaged campaign")
	var campaign_only: Dictionary = store.get_active_recovery_status()
	_check(campaign_only.ok and campaign_only.available and campaign_only.backup_members == ["intruder"], "current campaign damage exposes its original autosave backup")
	_write(paths.habitat_path, "{damaged habitat")
	DirAccess.remove_absolute(paths.campaign_slots.defender)
	var before_preview: Dictionary = _tree_fingerprints(root + "/active_recovery")
	var recovery: Dictionary = Profiles.new(root + "/active_recovery").get_active_recovery_status()
	_check(recovery.ok and recovery.available and recovery.manifest_source == "current" and recovery.backup_members.has("intruder") and recovery.backup_members.has("defender") and recovery.backup_members.has("habitat"), "restart preview validates all damaged or backup-only members within one generation")
	_check(_tree_fingerprints(root + "/active_recovery") == before_preview, "recovery preview and cancellation create no files or staged generations")
	_check(not store.resolve_paths().ok, "preview never silently repairs the active profile")
	var prepared: Dictionary = store.prepare_active_recovery()
	_check(prepared.ok and prepared.snapshots.campaigns.defender != null and prepared.snapshots.habitat.state.lighting == "night", "confirmed recovery stages valid campaign and habitat backup snapshots")
	if not prepared.ok: return
	var active_bytes: PackedByteArray = _bytes(store._active_path)
	DirAccess.make_dir_absolute(store._active_path + ".tmp")
	_check(not store.commit_restore(prepared).ok and _bytes(store._active_path) == active_bytes, "recovery commit failure preserves the old active pointer")
	_check(Profiles.new(root + "/active_recovery").get_active_recovery_status().available, "failed recovery still exposes original autosave backups after restart")
	DirAccess.remove_absolute(store._active_path + ".tmp")
	_check(store.commit_restore(prepared).ok, "recovery retries the same validated prepared transaction")
	var restarted = Profiles.new(root + "/active_recovery")
	var restored: Dictionary = restarted.resolve_paths()
	_check(restored.ok and restored.active and restored.habitat_path.get_base_dir() != old_generation and FileAccess.file_exists(restored.campaign_slots.defender), "recovered profile restarts with its formerly backup-only campaign present")
	_check(DirAccess.dir_exists_absolute(old_generation) and FileAccess.file_exists(old_generation + "/intruder.json.bak"), "previous generation and its original autosave backup remain preserved")
	var recovered_game = Campaign.new(restored.campaign_slots.intruder, "intruder")
	_check(recovered_game.load_game().ok and recovered_game.export_snapshot().recursive_equal(fixture.campaigns.intruder, 64), "recovery restores the actual validated backup state")
	_check(not restarted.get_active_recovery_status().available, "successful recovery returns to healthy primary autosaves")
	_write(store._active_path, "{damaged current manifest")
	var pointer_preview: Dictionary = restarted.get_active_recovery_status()
	_check(pointer_preview.ok and pointer_preview.available and pointer_preview.manifest_source == "backup", "invalid current pointer explicitly previews the previous profile manifest")
	var pointer_recovery: Dictionary = restarted.prepare_active_recovery()
	_check(pointer_recovery.ok and restarted.commit_restore(pointer_recovery).ok and Profiles.new(root + "/active_recovery").resolve_paths().ok, "confirmed previous-manifest recovery commits one coherent generation")
	_check(DirAccess.dir_exists_absolute(old_generation), "valid backup manifest retains its original generation after pointer repair")
	var current: Dictionary = restarted.resolve_paths()
	_write(current.campaign_slots.intruder, "{unrecoverable current")
	_write(current.campaign_slots.intruder + ".bak", "{unrecoverable backup")
	var previous_profile: Dictionary = restarted.get_active_recovery_status()
	_check(previous_profile.ok and previous_profile.available and previous_profile.manifest_source == "backup", "one unrecoverable current member explicitly offers a whole previous profile")
	_write(old_generation + "/intruder.json.bak", "{previous generation also unrecoverable")
	var before_failure: Dictionary = _tree_fingerprints(root + "/active_recovery")
	var failed: Dictionary = restarted.get_active_recovery_status()
	_check(not failed.ok and not failed.available and failed.code == "PROFILE_MEMBER_UNRECOVERABLE", "two individually unrecoverable generations cannot be mixed into a recovery")
	_check(not restarted.prepare_active_recovery().ok and _tree_fingerprints(root + "/active_recovery") == before_failure, "unrecoverable recovery cannot stage or alter any profile files")


func _test_manual_backup() -> void:
	var store = Profiles.new(root + "/manual_backup")
	_check(store.save_slot(1, fixture, context).ok, "manual backup initial checkpoint saves")
	var newer: Dictionary = fixture.duplicate(true)
	newer.habitat.actions.append({"action": "set_lighting", "params": {"lighting": "dawn"}})
	newer.habitat.state.lighting = "dawn"
	_check(store.save_slot(1, newer, context).ok, "manual overwrite retains its previous manifest")
	var row: Dictionary = store.list_slots()[0]
	_check(row.status == "valid" and row.backup_available and row.backup_metadata.pack_id == "intruder" and row.backup_metadata.mission_id == "M01", "manual slot exposes validated backup metadata separately from its current summary")
	_write(store._slot_path(1), "{damaged manual manifest")
	row = store.list_slots()[0]
	_check(row.status == "damaged" and row.backup_available and not store.prepare_restore(1).ok, "damaged manual primary remains damaged while explicit backup is available")
	var backup: Dictionary = store.prepare_restore(1, true)
	_check(backup.ok and backup.snapshots.habitat.state.lighting == "night" and store.commit_restore(backup).ok, "explicit manual backup selection restores the previous complete checkpoint")
	var manifest: Dictionary = JSON.parse_string(_bytes(store._slot_path(1) + ".bak").get_string_from_utf8())
	_write(store._paths(manifest).habitat_path, "{damaged manual backup member")
	_check(not store.list_slots()[0].backup_available and not store.prepare_restore(1, true).ok, "invalid manual backup members cannot be offered as recoverable")


func _tree_fingerprints(path: String) -> Dictionary:
	var result: Dictionary = {}
	var directory: DirAccess = DirAccess.open(path)
	if directory == null: return result
	for file in directory.get_files(): result[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
	for child in directory.get_directories(): result.merge(_tree_fingerprints(path.path_join(child)))
	return result


func _test_review_data_retention() -> void:
	var pair: Dictionary = _two_active_generations("uncertain_pointer")
	var store = pair.store
	var latest_path: String = pair.current + "/intruder.json"
	var game = Campaign.new(latest_path, "intruder")
	_check(game.load_game().ok and game.execute("mkdir ~/latest_progress").ok and game.save_game().ok, "latest active generation has actual post-checkpoint autosave progress")
	var latest_hash: String = FileAccess.get_sha256(latest_path)
	var unselected: Dictionary = store._create_generation("active", fixture, context, 0)
	var unselected_path: String = store._paths(unselected.manifest).habitat_path.get_base_dir()
	_write(store._active_path, "{truncated current pointer")
	var recovery: Dictionary = store.prepare_active_recovery()
	_check(recovery.ok and store.commit_restore(recovery).ok, "explicit whole previous-profile recovery succeeds after pointer damage")
	_check(FileAccess.file_exists(latest_path) and FileAccess.get_sha256(latest_path) == latest_hash, "damaged pointer recovery preserves the uncertain latest generation and its autosaves")
	_check(not DirAccess.dir_exists_absolute(unselected_path), "unselected unrelated staging generations are collected instead of quarantined")
	var repeated := true
	for index in range(105):
		var prepared: Dictionary = store.prepare_restore(1)
		if not prepared.ok or not store.commit_restore(prepared).ok: repeated = false
	_check(repeated and DirAccess.get_directories_at(store._generation_root("active")).size() <= 4 and FileAccess.file_exists(latest_path), "one quarantined incident permits over one hundred normal restores with a bounded generation count")

	var missing: Dictionary = _two_active_generations("lost_pointers")
	var missing_store = missing.store
	var original_path: String = missing.current + "/intruder.json"
	DirAccess.remove_absolute(missing_store._active_path)
	DirAccess.remove_absolute(missing_store._active_path + ".bak")
	var resolved: Dictionary = Profiles.new(root + "/lost_pointers").resolve_paths()
	_check(not resolved.ok and resolved.code == "PROFILE_POINTER_MISSING", "previously selected active profile with both pointers lost never falls back to fixed paths")
	_check(missing_store.save_slot(3, fixture, context).ok and FileAccess.file_exists(original_path), "pointer loss cannot let a later manual save collect uncertain active progress")
	var manual: Dictionary = missing_store.prepare_restore(1)
	_check(manual.ok and missing_store.commit_restore(manual).ok and FileAccess.file_exists(original_path), "explicit restoration after metadata loss preserves the previous uncertain generation")

	for damage in ["member", "marker"]:
		var broken: Dictionary = _two_active_generations("unrecoverable_" + damage)
		var broken_store = broken.store
		if damage == "member":
			_write(broken.current + "/intruder.json", "{broken latest member")
			_write(broken.current + "/intruder.json.bak", "{broken latest member backup")
		else:
			_write(broken.current + "/generation.json", "{broken latest marker")
		var status: Dictionary = broken_store.get_active_recovery_status()
		_check(status.ok and status.available and status.manifest_source == "backup", "unrecoverable current " + damage + " offers a whole valid previous generation")
		var selected: Dictionary = broken_store.prepare_restore(1)
		_check(selected.ok and broken_store.commit_restore(selected).ok, "manual escape from broken " + damage + " commits safely")
		var backup: Dictionary = JSON.parse_string(_bytes(broken_store._active_path + ".bak").get_string_from_utf8())
		_check(backup.generation == broken.previous.get_file() and DirAccess.dir_exists_absolute(broken.previous), "last readable generation remains the backup after replacing broken " + damage)
		selected = broken_store.prepare_restore(1)
		_check(selected.ok and broken_store.commit_restore(selected).ok and DirAccess.dir_exists_absolute(broken.current), "future pointer rotation retains the damaged " + damage + " generation for recovery")


func _two_active_generations(name: String) -> Dictionary:
	var store = Profiles.new(root + "/" + name)
	var directories: Array = []
	for index in range(1, 3):
		_check(store.save_slot(index, fixture, context).ok, name + " manual fixture " + str(index))
		var prepared: Dictionary = store.prepare_restore(index)
		_check(prepared.ok and store.commit_restore(prepared).ok, name + " active fixture " + str(index))
		directories.append(store.resolve_paths().habitat_path.get_base_dir())
	return {"store": store, "previous": directories[0], "current": directories[1]}


func _test_first_commit_history() -> void:
	var store = Profiles.new(root + "/first_preflight")
	_check(store.save_slot(1, fixture, context).ok, "first commit preflight fixture saves")
	var prepared: Dictionary = store.prepare_restore(1)
	DirAccess.make_dir_absolute(store._active_path + ".tmp")
	_check(not store.commit_restore(prepared).ok and not store._active_history_exists() and not store.resolve_paths().active, "first commit preflight failure preserves the original profile without selection history")
	DirAccess.remove_absolute(store._active_path + ".tmp")
	_check(store.commit_restore(prepared).ok and store._active_history_exists(), "successful first commit records durable selection history")
	var interrupted = FinalRenameFailure.new(root + "/first_final_rename")
	_check(interrupted.save_slot(1, fixture, context).ok, "first final-rename fixture saves")
	prepared = interrupted.prepare_restore(1)
	_check(not interrupted.commit_restore(prepared).ok and interrupted._active_history_exists(), "failed final rename retains the already-recorded selection intent")
	DirAccess.remove_absolute(interrupted._active_path)
	var restart: Dictionary = Profiles.new(root + "/first_final_rename").resolve_paths()
	_check(not restart.ok and restart.code == "PROFILE_POINTER_MISSING", "restart after selection marker but failed first rename is explicitly blocked")
	interrupted.obstruct_after_history = false
	_check(interrupted.commit_restore(prepared).ok and Profiles.new(root + "/first_final_rename").resolve_paths().active, "explicit retry reconciles the first-commit selection intent")


func _protected() -> Dictionary:
	var result: Dictionary = {}
	var paths: Array = ["user://settings.json", "user://saves/campaign_01.json", "user://saves/slot_01.json", Habitat.PATH, "user://saves/profile_active.json", "user://saves/profile_generations/active_selected.json", "user://saves/profile_generations/active_selected.json.tmp"]
	for id in Catalog.ENTRIES: paths.append(Catalog.default_slot(id))
	for path in paths:
		for suffix in ["", ".bak"]:
			var candidate: String = path + suffix
			result[candidate] = FileAccess.get_sha256(candidate) if FileAccess.file_exists(candidate) else "absent"
	return result


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "fixture write opens " + path)
		return
	file.store_string(text)
	file.close()


func _remove_tree(path: String) -> void:
	if not path.begins_with(root) or path == root.trim_suffix("/").get_base_dir(): return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null: return
	for file in directory.get_files(): DirAccess.remove_absolute(path.path_join(file))
	for child in directory.get_directories():
		if directory.is_link(child): DirAccess.remove_absolute(path.path_join(child))
		else: _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
