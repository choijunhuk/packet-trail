extends RefCounted
## Only this suite's unique user://tests tree may be written or removed.
const Settings = preload("res://scripts/presentation/settings_store.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Loader = preload("res://scripts/core/campaign_loader.gd")
const SUPPORT_FIELDS := ["support_intruder", "support_defender", "support_tracker", "support_challenge"]
const LEVELS := ["guided", "standard", "independent"]

var checks := 0
var failures: Array[String] = []
var skipped: Array[String] = []
var root_path := ""


func run() -> Dictionary:
	checks = 0
	failures.clear()
	skipped.clear()
	root_path = "user://tests/support_settings_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
	var protected := _fingerprints()
	var ready := true
	for field in SUPPORT_FIELDS:
		var result: Dictionary = Settings.new().validate_values({field: "guided"})
		_check(result.get("ok", false), "guided support is accepted: " + field)
		ready = ready and result.get("ok", false)
	if not ready:
		_check(_fingerprints() == protected, "enum-only RED preserves all real preferences and campaign slots")
		return _report("enum_red")
	_check(DirAccess.make_dir_recursive_absolute(root_path) == OK, "create unique owned test directory")
	_validation()
	_round_trip()
	_paths()
	_blocked_paths()
	_unix_write_failure()
	_links()
	_bad_files()
	_campaign_invariance()
	_check(_fingerprints() == protected, "all real preferences/slot paths remain byte-identical")
	_remove_owned(root_path)
	_check(not DirAccess.dir_exists_absolute(root_path), "remove only the unique owned test tree")
	return _report("full")


func _report(stage: String) -> Dictionary:
	return {"checks": checks, "failures": failures.duplicate(), "skipped": skipped.duplicate(), "stage": stage,
		"limit": "Isolated preference IO and unchanged campaign contracts; not native UI or physical input acceptance."}


func _store(path: String) -> Variant:
	# Keep the baseline enum RED runnable before the constructor gains path injection.
	var script: Variant = Settings
	var store: Variant = script.new(path)
	# Never exercise IO if a regression discarded an injected path.
	var isolated: bool = store.get("_path") == path
	_check(isolated, "constructor keeps the explicit path without default fallback")
	return store if isolated else null


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)


func _validation() -> void:
	var store := Settings.new()
	var before := store.get_values()
	for field in SUPPORT_FIELDS:
		_check(before.get(field) == "standard", "missing support defaults to standard: " + field)
		for level in LEVELS:
			var result: Dictionary = store.validate_values({field: level})
			_check(result.get("ok", false) and result.values.get(field) == level, "explicit scalar support validates: " + field + "/" + level)
		for invalid in [null, true, 0, 1.0, [], {}, "", "GUIDED", " guided", "easy", "hard"]:
			_check(not store.validate_values({field: invalid}).get("ok", true), "invalid support type/value is rejected: " + field + "/" + str(invalid))
	for invalid in [{"support_unknown": "guided"}, {"support_legacy_intruder": "guided"}, {"profiles": {"intruder": "guided"}}, {"difficulty": "hard"}]:
		_check(not store.validate_values(invalid).get("ok", true), "unknown preference fields are rejected")
	var old: Dictionary = store.validate_values({"locale": "en", "master_volume": 0.37, "comfort_mode": false})
	_check(old.get("ok", false) and old.values.locale == "en" and old.values.master_volume == 0.37 and old.values.comfort_mode == false, "old display/audio/input values survive default completion")
	for field in SUPPORT_FIELDS: _check(old.get("values", {}).get(field) == "standard", "old sparse preferences gain a standard support default")
	_check(store.get_values().recursive_equal(before, 0), "validation does not apply settings in memory")
	var exposed := store.get_values()
	exposed.support_intruder = "independent"
	_check(store.get_values().recursive_equal(before, 0), "preference getter remains detached")


func _round_trip() -> void:
	var path := root_path + "/nested/old/preferences.json"
	var store = _store(path)
	_check(store.load_settings().get("ok", false), "missing settings read as defaults")
	_check(not DirAccess.dir_exists_absolute(path.get_base_dir()), "missing settings read never creates parents")
	var old := {"version": 1, "values": {"locale": "en", "font_scale": 1.35, "fullscreen": true, "music_volume": 0.21}}
	_write(path, JSON.stringify(old).to_utf8_buffer())
	var original := FileAccess.get_file_as_bytes(path)
	var loaded: Dictionary = store.load_settings()
	_check(loaded.get("ok", false) and loaded.values.locale == "en" and loaded.values.font_scale == 1.35 and loaded.values.fullscreen == true and loaded.values.music_volume == 0.21, "old v1 JSON retains actual non-default settings")
	for field in SUPPORT_FIELDS: _check(loaded.get("values", {}).get(field) == "standard", "old v1 JSON fills missing support defaults")
	_check(FileAccess.get_file_as_bytes(path) == original and not FileAccess.file_exists(path + ".bak"), "loading old v1 JSON never migrates or rewrites it")
	var signals: Array = []
	store.changed.connect(func(values: Dictionary):
		signals.append(values.duplicate(true))
		values.support_intruder = "listener-mutated")
	var saved: Dictionary = store.update_settings({"support_intruder": "guided", "support_defender": "independent", "support_tracker": "standard", "support_challenge": "independent"})
	_check(saved.get("ok", false), "save isolated explicit per-campaign support")
	_check(signals.size() == 1 and signals[0].support_intruder == "guided", "changed signal emits normalized values only after successful persistence")
	_check(store.get_values().support_intruder == "guided", "signal listener cannot mutate store memory")
	_check(FileAccess.get_file_as_bytes(path + ".bak") == original, "backup preserves exact old v1 bytes")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(disk is Dictionary and disk.size() == 2 and disk.get("version") == 1 and disk.get("values", {}).get("support_defender") == "independent" and disk.get("values", {}).get("support_challenge") == "independent", "preferences retain the existing v1 envelope with scalar support fields")
	var restored = _store(path)
	_check(restored.load_settings().get("ok", false) and restored.get_values().recursive_equal(store.get_values(), 0), "all display/audio/support values survive disk round-trip")
	var before := _owned_files(path)
	var memory: Dictionary = store.get_values()
	_check(not store.update_settings({"support_intruder": "hard"}).get("ok", true), "invalid patch is not persisted")
	_check(_owned_files(path) == before and store.get_values().recursive_equal(memory, 0) and signals.size() == 1, "invalid update preserves main/backup/temp, memory and signal count")
	_check(store.reset_controls().get("ok", false) and store.get_values().support_intruder == "guided", "control reset leaves support choices intact")


func _paths() -> void:
	# Namespace rejection is inspected without risking a write to a real source path.
	var outside := ["", "user://other.json", "user://saves/slot_01.json", "user://tests/../settings.json", "res://settings.json", "/tmp/settings.json", "user://tests/", "user://tests/not-json.txt"]
	for path in outside:
		var store = _store(path)
		var memory: Dictionary = store.get_values()
		_check(not store._guard().get("ok", true), "invalid namespace is rejected before any IO: " + path)
		_check(store.get_values().recursive_equal(memory, 0), "namespace rejection preserves memory")
	# All actual negative IO calls still physically resolve inside this owned tree.
	for path in [root_path + "/inside/../bad.json", root_path + "//double.json", root_path + "/./dot.json", root_path + "/not-json.txt", root_path + "/control\n.json", root_path + "/colon:part.json"]:
		var store = _store(path)
		var memory: Dictionary = store.get_values()
		_check(not store.load_settings().get("ok", true), "nonnormalized owned path rejects reads")
		_check(not store.update_settings({"support_intruder": "guided"}).get("ok", true), "nonnormalized owned path rejects writes")
		_check(store.get_values().recursive_equal(memory, 0), "invalid path preserves in-memory preferences")
	var path := root_path + "/created/a/b/settings.json"
	var store = _store(path)
	_check(store.update_settings({"support_tracker": "independent"}).get("ok", false) and FileAccess.file_exists(path), "safe owned missing parent directories can be created")
	var blocker := root_path + "/parent-file"
	_write(blocker, "owned blocker".to_utf8_buffer())
	var before := FileAccess.get_file_as_bytes(blocker)
	_check(not _store(blocker + "/settings.json").update_settings({"support_intruder": "guided"}).get("ok", true), "a file cannot be used as a settings parent")
	_check(FileAccess.get_file_as_bytes(blocker) == before, "parent file remains unchanged")


func _blocked_paths() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = root_path + "/blocked" + (str(suffix).replace(".", "_") if not str(suffix).is_empty() else "_main") + ".json"
		var store = _store(path)
		_check(store.update_settings({"support_intruder": "guided"}).get("ok", false), "seed isolated settings before blocked-path failure")
		_check(store.update_settings({"support_defender": "independent"}).get("ok", false), "seed an actual previous backup")
		var blocked: String = path + str(suffix)
		if FileAccess.file_exists(blocked): DirAccess.remove_absolute(blocked)
		_check(DirAccess.make_dir_absolute(blocked) == OK, "create owned directory in a settings file position")
		var before := _owned_files(path)
		var memory: Dictionary = store.get_values()
		var events: Array = []
		store.changed.connect(func(values: Dictionary): events.append(values))
		_check(not store.update_settings({"support_tracker": "guided"}).get("ok", true), "directory in main/tmp/bak/bak.tmp blocks write")
		_check(_owned_files(path) == before and store.get_values().recursive_equal(memory, 0) and events.is_empty(), "blocked write preserves all existing paths, bytes, memory and signals")


func _unix_write_failure() -> void:
	if OS.get_name() == "Windows":
		skipped.append("Unix permission-based actual write failure is not available on Windows; directory and link guards are checked separately.")
		return
	var path := root_path + "/read-only/settings.json"
	var store = _store(path)
	_check(store.update_settings({"support_intruder": "guided"}).get("ok", false), "seed real IO failure case")
	_check(store.update_settings({"support_defender": "independent"}).get("ok", false), "seed real IO backup")
	var before := _owned_files(path)
	var memory: Dictionary = store.get_values()
	var permissions := FileAccess.get_unix_permissions(path.get_base_dir())
	var changed: Error = FileAccess.set_unix_permissions(path.get_base_dir(), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	_check(changed == OK, "make only the owned parent directory read-only")
	if changed == OK:
		var result: Dictionary = store.update_settings({"support_tracker": "guided"})
		_check(not result.get("ok", true), "actual FileAccess create failure returns an explicit error")
		_check(_owned_files(path) == before and store.get_values().recursive_equal(memory, 0), "actual failed write preserves normal main/backup and memory")
		_check(FileAccess.set_unix_permissions(path.get_base_dir(), permissions) == OK, "restore owned directory permissions before cleanup")


func _links() -> void:
	var directory := DirAccess.open(root_path)
	var target := root_path + "/link-target.json"
	_write(target, JSON.stringify({"version": 1, "values": {"locale": "ja"}}).to_utf8_buffer())
	var expected := FileAccess.get_file_as_bytes(target)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = root_path + "/link" + (str(suffix).replace(".", "_") if not str(suffix).is_empty() else "_main") + ".json"
		var linked: Error = directory.create_link(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(path + suffix))
		if linked != OK:
			if OS.get_name() == "Windows": skipped.append("Windows symbolic-link creation requires Developer Mode/elevation: " + suffix)
			else: _check(false, "create isolated leaf symlink")
			continue
		var store = _store(path)
		_check(not store.load_settings().get("ok", true) and not store.update_settings({"support_intruder": "guided"}).get("ok", true), "linked main or sidecar cannot be read/written as settings")
		_check(FileAccess.get_file_as_bytes(target) == expected, "symlink target bytes remain untouched")
	var real_parent := root_path + "/real-parent"
	DirAccess.make_dir_recursive_absolute(real_parent)
	_write(real_parent + "/settings.json", expected)
	var parent_link := root_path + "/linked-parent"
	var linked: Error = directory.create_link(ProjectSettings.globalize_path(real_parent), ProjectSettings.globalize_path(parent_link))
	if linked == OK:
		var store = _store(parent_link + "/settings.json")
		_check(not store.load_settings().get("ok", true) and not store.update_settings({"support_tracker": "guided"}).get("ok", true), "parent symlink is rejected before following it")
		_check(FileAccess.get_file_as_bytes(real_parent + "/settings.json") == expected, "linked parent target remains unchanged")
	elif OS.get_name() == "Windows": skipped.append("Windows parent-symlink fixture unavailable without Developer Mode/elevation.")
	else: _check(false, "create isolated parent symlink")


func _bad_files() -> void:
	var path := root_path + "/bad-files/settings.json"
	var store = _store(path)
	_check(store.update_settings({"support_intruder": "guided"}).get("ok", false), "seed before malformed settings reads")
	var memory: Dictionary = store.get_values()
	for raw in ["{broken", JSON.stringify({"version": 99, "values": {}}), JSON.stringify({"version": true, "values": {}}), JSON.stringify({"version": 1, "values": {"support_intruder": "hard"}}), JSON.stringify({"version": 1, "values": {}, "campaign": {}}), " ".repeat(65537)]:
		_write(path, raw.to_utf8_buffer())
		var before := FileAccess.get_file_as_bytes(path)
		_check(not store.load_settings().get("ok", true), "damaged/version/type/oversize settings read is rejected")
		_check(FileAccess.get_file_as_bytes(path) == before and store.get_values().recursive_equal(memory, 0), "failed read preserves original bytes and active values")


func _campaign_invariance() -> void:
	var path := root_path + "/campaign-support.json"
	var store = _store(path)
	for pack in ["intruder", "defender", "tracker", "challenge", "legacy_intruder"]:
		var game = Campaign.new(root_path + "/campaign_" + pack + ".json", pack)
		var before: Dictionary = game.export_snapshot()
		var view: Dictionary = game.get_view()
		_check(view.get("ready", false) and before.size() == 9 and before.get("save_version") == 2, "campaign retains strict v2 nine-field contract: " + pack)
		for level in LEVELS:
			var patch := {"support_intruder": level, "support_defender": level, "support_tracker": level, "support_challenge": level}
			_check(store.update_settings(patch).get("ok", false), "persist support without touching game: " + pack + "/" + level)
			game.get_hint(2)
			game.execute("pwd")
			_check(game.export_snapshot().recursive_equal(before, 0), "support and optional hint do not change campaign snapshot: " + pack + "/" + level)
			_check(game.get_view().get("completed") == view.get("completed") and game.get_view().get("alert_level") == view.get("alert_level"), "support leaves goal/alert unchanged: " + pack + "/" + level)
		var metadata_in_save: Dictionary = before.duplicate(true)
		metadata_in_save["support_intruder"] = "guided"
		_check(not game.restore_snapshot(metadata_in_save).get("ok", true), "support metadata is rejected inside the strict campaign envelope: " + pack)
		_check(game.export_snapshot().recursive_equal(before, 0), "rejected metadata cannot alter campaign progress: " + pack)
		var restored = Campaign.new(root_path + "/restore_" + pack + ".json", pack)
		_check(restored.restore_snapshot(JSON.parse_string(JSON.stringify(before))).get("ok", false), "old strict v2 snapshot still restores: " + pack)
		var definition: Dictionary = Loader.load_campaign(pack).definition
		var start: Dictionary = definition.missions[definition.start_mission]
		var host_id := ""
		for id in start.hosts:
			if start.hosts[id].get("via", ["local"]).has("local") and start.hosts[id].services.get("22", {}).get("state") == "open":
				host_id = id
				break
		_check(not host_id.is_empty(), "action-invariance fixture has an actually reachable initial SSH host")
		if host_id.is_empty(): continue
		var host: Dictionary = start.hosts[host_id]
		var username: String = host.accounts.keys()[0]
		var wrong := "__support_test_wrong_password__"
		while wrong == host.accounts[username].password: wrong += "_"
		var results: Array = []
		for level in LEVELS:
			store.update_settings({"support_intruder": level, "support_defender": level, "support_tracker": level, "support_challenge": level})
			var candidate = Campaign.new(root_path + "/action_" + pack + "_" + level + ".json", pack)
			var connected: Dictionary = candidate.execute("ssh " + username + "@" + host.domain)
			var failed: Dictionary = candidate.submit_password(wrong)
			_check(connected.get("ok", false) and failed.get("code") == "AUTH_DENIED", "real denied-auth action is exercised under support preference: " + pack + "/" + level)
			results.append(candidate.export_snapshot())
		_check(results[0].recursive_equal(results[1], 0) and results[1].recursive_equal(results[2], 0), "same actual action produces identical core state under all support preferences: " + pack)


func _write(path: String, bytes: PackedByteArray) -> void:
	_check(path.begins_with(root_path + "/"), "fixture write remains in this suite's owned test tree")
	if not path.begins_with(root_path + "/"): return
	_check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "create owned fixture parents")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "open owned fixture")
	if file == null: return
	_check(file.store_buffer(bytes), "write owned fixture bytes")
	file.close()


func _owned_files(path: String) -> Dictionary:
	var result := {}
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: result[suffix] = _fingerprint(path + suffix)
	return result


func _fingerprints() -> Dictionary:
	var paths: Array = ["user://settings.json"]
	for name in ["slot_01", "campaign_01", "legacy_continue_01", "intruder_v2_01", "defender_01", "tracker_01", "challenge_01"]: paths.append("user://saves/" + name + ".json")
	var result := {}
	for path in paths:
		for suffix in ["", ".tmp", ".bak", ".bak.tmp"]: result[path + suffix] = _fingerprint(path + suffix)
	return result


func _fingerprint(path: String) -> String:
	var parent := "user://"
	for part in path.trim_prefix("user://").split("/"):
		var dir := DirAccess.open(parent)
		if dir == null: return "missing"
		if dir.is_link(part): return "link"
		parent = parent.path_join(part)
	if DirAccess.dir_exists_absolute(path): return "directory"
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"


func _remove_owned(path: String) -> void:
	if not (path == root_path or path.begins_with(root_path + "/")): return
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir() and not directory.is_link(name): _remove_owned(child)
		else: _check(DirAccess.remove_absolute(child) == OK, "remove owned fixture file/link")
		name = directory.get_next()
	directory.list_dir_end()
	_check(DirAccess.remove_absolute(path) == OK, "remove owned fixture directory")
