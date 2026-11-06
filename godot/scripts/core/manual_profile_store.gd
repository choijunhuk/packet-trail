extends RefCounted
## Five whole-profile checkpoints. Only generated paths enter the disk boundary.

const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Habitat = preload("res://scripts/core/habitat_store.gd")
const Store = preload("res://scripts/core/save_store.gd")
const ROOT := "user://profiles"
const SLOT_COUNT := 5
const MAX_GENERATIONS := 128
const MANIFEST_KEYS := ["profile_version", "kind", "index", "generation", "saved_at", "context", "campaigns"]

var _root: String
var _active_root: String
var _active_path: String
var _store := Store.new()
var _habitat := Habitat.new()
var _games: Dictionary = {}
var _prepared: Dictionary = {}


func _init(root: String = ROOT) -> void:
	_root = root
	_active_root = "user://saves/profile_generations" if root == ROOT else root + "/active_generations"
	_active_path = "user://saves/profile_active.json" if root == ROOT else root + "/active.json"


func save_slot(index: int, snapshots: Dictionary, context: Dictionary) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	if index < 1 or index > SLOT_COUNT: return _failure("PROFILE_SLOT_REJECTED", "Choose a manual slot from 1 to 5.")
	var checked: Dictionary = _validate_snapshots(snapshots)
	if not checked.ok: return checked
	if not _valid_context(context): return _failure("PROFILE_CONTEXT_REJECTED", "Unknown profile location or campaign.")
	if not _context_matches(context, checked.snapshots): return _failure("PROFILE_CONTEXT_REJECTED", "The saved location requires its campaign progress.")
	var created: Dictionary = _create_generation("manual", checked.snapshots, context, index)
	if not created.ok: return created
	var committed: Dictionary = _commit_manifest(_slot_path(index), created.manifest)
	if not committed.ok: return committed
	_collect_unreferenced()
	return {"ok": true, "code": "PROFILE_SAVED", "text": "Manual profile saved.", "index": index, "saved_at": created.manifest.saved_at}


func list_slots() -> Array:
	var rows: Array = []
	var guard: Dictionary = _guard()
	for index in range(1, SLOT_COUNT + 1):
		var row: Dictionary = {"index": index, "status": "empty", "saved_at": 0, "pack_id": "", "mission_id": "", "completed": 0, "total": 0, "backup_available": false, "backup_metadata": {}}
		if not guard.ok:
			row.merge({"status": "damaged", "code": guard.code, "text": guard.text}, true)
		elif _exists(_slot_path(index)) or _exists(_slot_path(index) + ".bak"):
			var loaded: Dictionary = _load_profile(_slot_path(index), "manual", index)
			if not loaded.ok:
				row.merge({"status": "damaged", "code": loaded.code, "text": loaded.text}, true)
			else:
				row.merge(_summary(loaded), true)
			var backup: Dictionary = _load_profile(_slot_path(index) + ".bak", "manual", index)
			if backup.ok:
				row.backup_available = true
				row.backup_metadata = _summary(backup)
		rows.append(row)
	return rows


func prepare_restore(index: int, use_backup: bool = false) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	if index < 1 or index > SLOT_COUNT: return _failure("PROFILE_SLOT_REJECTED", "Choose a manual slot from 1 to 5.")
	var source: Dictionary = _load_profile(_slot_path(index) + (".bak" if use_backup else ""), "manual", index)
	if not source.ok: return source
	return _prepare_profile(source.snapshots, source.manifest.context)


func get_active_recovery_status() -> Dictionary:
	var candidate: Dictionary = _active_recovery_candidate()
	var status: Dictionary = {"ok": candidate.ok, "available": candidate.get("available", false), "manifest_source": candidate.get("manifest_source", "current"), "backup_members": candidate.get("backup_members", []), "context": candidate.get("context", {}).duplicate(true), "code": candidate.get("code", "PROFILE_RECOVERY_AVAILABLE"), "text": candidate.get("text", "Validated autosave backup recovery is available.")}
	return status


func prepare_active_recovery() -> Dictionary:
	var candidate: Dictionary = _active_recovery_candidate()
	if not candidate.ok: return candidate
	if not candidate.available: return _failure("PROFILE_RECOVERY_NOT_NEEDED", "The active profile does not need backup recovery.")
	return _prepare_profile(candidate.snapshots, candidate.context)


func _prepare_profile(snapshots: Dictionary, context: Dictionary) -> Dictionary:
	_prepared.clear()
	# Never restore into the immutable checkpoint or overwrite the current active files.
	var staged: Dictionary = _create_generation("active", snapshots, context, 0)
	if not staged.ok: return staged
	var token: String = _new_id()
	_prepared[token] = {"manifest": staged.manifest, "digest": JSON.stringify(snapshots, "", true, true).sha256_text()}
	return {"ok": true, "token": token, "paths": _paths(staged.manifest), "snapshots": snapshots.duplicate(true), "context": context.duplicate(true)}


func commit_restore(prepared: Dictionary) -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	var token: Variant = prepared.get("token")
	if not token is String or not _prepared.has(token): return _failure("PROFILE_PREPARATION_REJECTED", "Prepare this restore again before confirming it.")
	var manifest: Dictionary = _prepared[token].manifest
	var verified: Dictionary = _read_generation(manifest)
	if not verified.ok: return verified
	if JSON.stringify(verified.snapshots, "", true, true).sha256_text() != _prepared[token].digest:
		return _failure("PROFILE_PREPARATION_CHANGED", "The prepared profile changed; prepare the restore again.")
	var committed: Dictionary = _commit_manifest(_active_path, manifest)
	if not committed.ok: return committed
	_prepared.erase(token)
	_collect_unreferenced()
	return {"ok": true, "code": "PROFILE_RESTORED", "text": "Manual profile restored.", "paths": _paths(manifest), "context": manifest.context.duplicate(true)}


func resolve_paths() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	if not _exists(_active_path) and not _exists(_active_path + ".bak"):
		if _active_history_exists(): return _failure("PROFILE_POINTER_MISSING", "The selected profile pointers are missing; restore a manual checkpoint explicitly.")
		var slots: Dictionary = {}
		for id in Catalog.ENTRIES: slots[id] = Catalog.default_slot(id) if _root == ROOT else _root + "/fixed_" + id + ".json"
		return {"ok": true, "active": false, "campaign_slots": slots, "habitat_path": Habitat.PATH if _root == ROOT else _root + "/fixed_habitat.json", "context": {}}
	var loaded: Dictionary = _load_profile(_active_path, "active", 0)
	if not loaded.ok: return loaded
	var paths: Dictionary = _paths(loaded.manifest)
	return {"ok": true, "active": true, "campaign_slots": paths.campaign_slots, "habitat_path": paths.habitat_path, "context": loaded.manifest.context.duplicate(true)}


func _validate_snapshots(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _keys(raw, ["campaigns", "habitat"]) or not raw.campaigns is Dictionary or not _keys(raw.campaigns, Catalog.ENTRIES.keys()):
		return _failure("PROFILE_INVALID_SNAPSHOT", "A profile requires all registered campaigns and its room state.")
	var campaigns: Dictionary = {}
	for id in Catalog.ENTRIES:
		if raw.campaigns[id] == null:
			campaigns[id] = null
			continue
		var checked: Dictionary = _validate_campaign(raw.campaigns[id], id)
		if not checked.ok: return _failure("PROFILE_INVALID_CAMPAIGN", str(id) + ": " + checked.text)
		campaigns[id] = checked.snapshot
	var habitat: Dictionary = _habitat.validate_snapshot(raw.habitat)
	if not habitat.ok: return _failure("PROFILE_INVALID_HABITAT", habitat.text)
	return {"ok": true, "snapshots": {"campaigns": campaigns, "habitat": habitat.snapshot}}


func _validate_campaign(raw: Variant, id: String) -> Dictionary:
	if not _games.has(id): _games[id] = Campaign.new("", id)
	return _games[id]._validate_snapshot(raw)


func _active_recovery_candidate() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok: return guard
	if not _exists(_active_path) and not _exists(_active_path + ".bak"):
		if _active_history_exists(): return _failure("PROFILE_POINTER_MISSING", "The selected profile pointers are missing; restore a manual checkpoint explicitly.")
		return {"ok": true, "available": false, "code": "PROFILE_RECOVERY_NOT_NEEDED", "text": "No active profile needs recovery."}
	var failure: Dictionary = _failure("PROFILE_MANIFEST_UNRECOVERABLE", "Neither active profile is recoverable.")
	for source in ["current", "backup"]:
		var selected: Dictionary = _read_manifest(_active_path + (".bak" if source == "backup" else ""), "active", 0)
		if not selected.ok: continue
		var candidate: Dictionary = _recoverable_generation(selected.snapshot)
		if not candidate.ok:
			if source == "current": failure = candidate
			continue
		var available: bool = source == "backup" or not candidate.backup_members.is_empty()
		return {"ok": true, "available": available, "manifest_source": source, "backup_members": candidate.backup_members, "context": selected.snapshot.context.duplicate(true), "snapshots": candidate.snapshots, "code": "PROFILE_RECOVERY_AVAILABLE" if available else "PROFILE_RECOVERY_NOT_NEEDED", "text": "Validated autosave backup recovery is available." if available else "The active profile is valid."}
	return failure


func _recoverable_generation(manifest: Dictionary) -> Dictionary:
	var directory: String = _generation_root("active").path_join(manifest.generation)
	var marker: Dictionary = _read_json(directory + "/generation.json", 1024)
	if not marker.ok or not _valid_marker(marker.get("data"), "active", manifest.generation): return _failure("PROFILE_INVALID_GENERATION", "The selected profile generation is missing or damaged.")
	var snapshots: Dictionary = {"campaigns": {}, "habitat": {}}
	var backup_members: Array = []
	for id in Catalog.ENTRIES:
		var path: String = directory + "/" + id + ".json"
		if not manifest.campaigns.has(id) and not _exists(path) and not _exists(path + ".bak"):
			snapshots.campaigns[id] = null
			continue
		var member: Dictionary = _recoverable_member(path, id)
		if not member.ok: return member
		snapshots.campaigns[id] = member.snapshot
		if member.backup: backup_members.append(id)
	var room: Dictionary = _recoverable_member(directory + "/habitat.json", "habitat")
	if not room.ok: return room
	snapshots.habitat = room.snapshot
	if room.backup: backup_members.append("habitat")
	if not _context_matches(manifest.context, snapshots): return _failure("PROFILE_CONTEXT_REJECTED", "The recoverable profile is missing required campaign progress.")
	return {"ok": true, "backup_members": backup_members, "snapshots": snapshots}


func _recoverable_member(path: String, id: String) -> Dictionary:
	for suffix in ["", ".bak"]:
		var loaded: Dictionary = _read_json(path + suffix, 65536 if id == "habitat" else Store.MAX_BYTES)
		if not loaded.ok: continue
		var checked: Dictionary = _habitat.validate_snapshot(loaded.data) if id == "habitat" else _validate_campaign(loaded.data, id)
		if checked.ok: return {"ok": true, "snapshot": checked.snapshot, "backup": not suffix.is_empty()}
	return _failure("PROFILE_MEMBER_UNRECOVERABLE", "No valid original or autosave backup exists for " + id + ".")


func _summary(loaded: Dictionary) -> Dictionary:
	var pack: String = loaded.manifest.context.pack_id
	var snapshot: Variant = loaded.snapshots.campaigns[pack]
	var entry: Dictionary = Catalog.get_pack(pack)
	return {"status": "valid", "saved_at": loaded.manifest.saved_at, "pack_id": pack, "mission_id": snapshot.current_mission if snapshot is Dictionary else entry.start_mission, "completed": snapshot.completed.size() if snapshot is Dictionary else 0, "total": int(entry.main_count) + int(entry.optional_count)}


func _create_generation(kind: String, snapshots: Dictionary, context: Dictionary, index: int) -> Dictionary:
	var base: String = _generation_root(kind)
	# Collection may be inhibited by damage; the capacity bound then fails closed.
	_collect_unreferenced()
	if DirAccess.dir_exists_absolute(base) and DirAccess.get_directories_at(base).size() >= MAX_GENERATIONS:
		return _failure("PROFILE_CAPACITY_LIMIT", "Profile storage needs recovery before another checkpoint can be written.")
	var generation: String = _new_id()
	var directory: String = base.path_join(generation)
	if _exists(directory): return _failure("PROFILE_GENERATION_COLLISION", "Could not reserve a new profile generation.")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return _failure("PROFILE_DIRECTORY_FAILED", "Could not create profile storage.")
	var marker: Dictionary = {"profile_version": 1, "kind": kind, "generation": generation, "selected": false}
	var wrote: Dictionary = _write_json(directory + "/generation.json", marker, 1024)
	if not wrote.ok: return wrote
	var present: Array = []
	for id in Catalog.ENTRIES:
		if snapshots.campaigns[id] == null: continue
		present.append(id)
		wrote = _write_json(directory + "/" + id + ".json", snapshots.campaigns[id], Store.MAX_BYTES)
		if not wrote.ok: return wrote
	wrote = _write_json(directory + "/habitat.json", snapshots.habitat, 65536)
	if not wrote.ok: return wrote
	var manifest: Dictionary = {"profile_version": 1, "kind": kind, "index": index, "generation": generation, "saved_at": int(Time.get_unix_time_from_system()), "context": context.duplicate(true), "campaigns": present}
	var checked: Dictionary = _read_generation(manifest)
	if not checked.ok: return checked
	if not checked.snapshots.recursive_equal(snapshots, 64): return _failure("PROFILE_ROUNDTRIP_MISMATCH", "Profile files changed while being staged.")
	return {"ok": true, "manifest": manifest}


func _load_profile(path: String, kind: String, index: int) -> Dictionary:
	var manifest: Dictionary = _read_manifest(path, kind, index)
	if not manifest.ok: return manifest
	var loaded: Dictionary = _read_generation(manifest.snapshot)
	if not loaded.ok: return loaded
	return {"ok": true, "manifest": manifest.snapshot, "snapshots": loaded.snapshots}


func _read_generation(manifest: Dictionary) -> Dictionary:
	var directory: String = _generation_root(manifest.kind).path_join(manifest.generation)
	var marker: Dictionary = _read_json(directory + "/generation.json", 1024)
	if not marker.ok or not _valid_marker(marker.get("data"), manifest.kind, manifest.generation): return _failure("PROFILE_INVALID_GENERATION", "Profile generation is missing or damaged.")
	var campaigns: Dictionary = {}
	for id in Catalog.ENTRIES:
		var path: String = directory + "/" + id + ".json"
		var present: bool = manifest.campaigns.has(id) or (manifest.kind == "active" and _exists(path))
		if not present:
			if _exists(path) or _exists(path + ".bak"): return _failure("PROFILE_UNEXPECTED_MEMBER", "An absent campaign has unexpected profile files.")
			campaigns[id] = null
			continue
		var member: Dictionary = _read_json(path, Store.MAX_BYTES)
		if not member.ok: return member
		campaigns[id] = member.data
	var room: Dictionary = _read_json(directory + "/habitat.json", 65536)
	if not room.ok: return room
	var checked: Dictionary = _validate_snapshots({"campaigns": campaigns, "habitat": room.data})
	if not checked.ok: return checked
	if not _context_matches(manifest.context, checked.snapshots): return _failure("PROFILE_CONTEXT_REJECTED", "The saved location is missing its campaign progress.")
	return checked


func _paths(manifest: Dictionary) -> Dictionary:
	var directory: String = _generation_root(manifest.kind).path_join(manifest.generation)
	var slots: Dictionary = {}
	for id in Catalog.ENTRIES: slots[id] = directory + "/" + id + ".json"
	return {"campaign_slots": slots, "habitat_path": directory + "/habitat.json"}


func _commit_manifest(path: String, manifest: Dictionary) -> Dictionary:
	for candidate in [path, path + ".tmp", path + ".bak", path + ".bak.tmp"]:
		var links: Dictionary = _store._check_links(candidate)
		if not links.ok: return links
		if DirAccess.dir_exists_absolute(candidate): return _failure("PROFILE_PATH_IS_DIRECTORY", "Profile pointer is occupied by a directory.")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return _failure("PROFILE_DIRECTORY_FAILED", "Could not create the profile pointer directory.")
	var previous: Dictionary = _read_manifest(path, manifest.kind, manifest.index)
	var previous_backup: Dictionary = _read_manifest(path + ".bak", manifest.kind, manifest.index)
	var previous_readable: bool = previous.ok and _generation_readable(previous.snapshot)
	var backup_readable: bool = previous_backup.ok and _generation_readable(previous_backup.snapshot)
	var uncertain: bool = (_exists(path) and not previous.ok) or (_exists(path + ".bak") and not previous_backup.ok)
	uncertain = uncertain or (manifest.kind == "active" and _active_history_exists() and not _exists(path) and not _exists(path + ".bak"))
	if uncertain:
		var protected: Dictionary = _quarantine_uncertain(manifest.kind, manifest.generation)
		if not protected.ok: return protected
	for earlier in [previous, previous_backup]:
		if earlier.ok and not _generation_readable(earlier.snapshot):
			var protected: Dictionary = _quarantine_generation(earlier.snapshot.kind, earlier.snapshot.generation)
			if not protected.ok: return protected
	# Explicit restore may repair a broken active pointer; preserve every damaged byte first.
	for original in [path, path + ".bak"]:
		if not _exists(original) or (previous_readable if original == path else backup_readable): continue
		var preserved: Dictionary = _preserve_file(original, original + ".damaged." + _new_id())
		if not preserved.ok: return preserved
	var bytes: PackedByteArray = JSON.stringify(manifest, "", true, true).to_utf8_buffer()
	var validator: Callable = _manifest_validator.bind(manifest.kind, manifest.index)
	var staged: Dictionary = _store._stage(path + ".tmp", bytes, manifest, validator)
	if not staged.ok: return staged
	if _exists(path) or _exists(path + ".bak"):
		var backup: Dictionary = previous.snapshot if previous_readable else (previous_backup.snapshot if backup_readable else manifest)
		staged = _store._stage(path + ".bak.tmp", JSON.stringify(backup, "", true, true).to_utf8_buffer(), backup, validator)
		if not staged.ok: return staged
		if DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK: return _failure("PROFILE_BACKUP_FAILED", "Could not preserve the previous profile pointer.")
	var selected: Dictionary = _mark_generation_selected(manifest)
	if not selected.ok: return selected
	if manifest.kind == "active":
		# Interrupted first selection fails closed on restart; flush/rename do not promise power-loss fsync durability.
		var history: Dictionary = _mark_active_selected()
		if not history.ok: return history
	# This is the only operation that changes which complete profile is active.
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return _failure("PROFILE_COMMIT_FAILED", "The previous profile pointer was kept.")
	return {"ok": true}


func _generation_readable(manifest: Dictionary) -> bool:
	return _recoverable_generation(manifest).ok if manifest.kind == "active" else _read_generation(manifest).ok


func _quarantine_uncertain(kind: String, incoming: String) -> Dictionary:
	var excluded: Array = [incoming]
	if kind == "active":
		for prepared in _prepared.values(): excluded.append(prepared.manifest.generation)
	var base: String = _generation_root(kind)
	if not DirAccess.dir_exists_absolute(base): return {"ok": true}
	for generation in DirAccess.get_directories_at(base):
		if excluded.has(generation) or not _valid_id(generation): continue
		var marker: Dictionary = _read_json(base.path_join(generation) + "/generation.json", 1024)
		if marker.ok and marker.data is Dictionary and marker.data.get("selected") == false: continue
		var protected: Dictionary = _quarantine_generation(kind, generation)
		if not protected.ok: return protected
	return {"ok": true}


func _quarantine_generation(kind: String, generation: String) -> Dictionary:
	var directory: String = _generation_root(kind).path_join(generation)
	# Unknown files, links and damaged ownership already exclude a directory from collection.
	if not _owned_generation(directory, kind, generation): return {"ok": true}
	return _write_json(directory + "/quarantine.json", {"profile_version": 1, "kind": kind, "generation": generation}, 1024)


func _mark_generation_selected(manifest: Dictionary) -> Dictionary:
	var path: String = _generation_root(manifest.kind).path_join(manifest.generation) + "/generation.json"
	var marker: Dictionary = _read_json(path, 1024)
	if not marker.ok or not _valid_marker(marker.get("data"), manifest.kind, manifest.generation): return _failure("PROFILE_INVALID_GENERATION", "The prepared generation marker changed.")
	var selected: Dictionary = marker.data.duplicate(true)
	selected.selected = true
	var wrote: Dictionary = _write_json(path + ".tmp", selected, 1024)
	if not wrote.ok: return wrote
	var verified: Dictionary = _read_json(path + ".tmp", 1024)
	if not verified.ok or not _valid_marker(verified.get("data"), manifest.kind, manifest.generation) or verified.data.get("selected") != true: return _failure("PROFILE_MARKER_FAILED", "Could not verify the selected generation marker.")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return _failure("PROFILE_MARKER_FAILED", "Could not record the selected generation.")
	return {"ok": true}


func _mark_active_selected() -> Dictionary:
	var path: String = _active_root + "/active_selected.json"
	if _exists(path): return {"ok": true}
	var marker: Dictionary = {"profile_version": 1, "active_selected": true}
	var wrote: Dictionary = _write_json(path + ".tmp", marker, 1024)
	if not wrote.ok: return wrote
	var verified: Dictionary = _read_json(path + ".tmp", 1024)
	if not verified.ok or not verified.data is Dictionary or not _keys(verified.data, ["profile_version", "active_selected"]) or not _integer(verified.data.profile_version, 1, 1) or verified.data.active_selected != true: return _failure("PROFILE_HISTORY_FAILED", "Could not verify active profile selection history.")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return _failure("PROFILE_HISTORY_FAILED", "Could not preserve active profile selection history.")
	return {"ok": true}


func _active_history_exists() -> bool:
	return _exists(_active_root + "/active_selected.json") or _exists(_active_root + "/active_selected.json.tmp")


func _read_manifest(path: String, kind: String, index: int) -> Dictionary:
	var loaded: Dictionary = _read_json(path, 8192)
	if not loaded.ok: return loaded
	return _manifest_validator(loaded.data, kind, index)


func _manifest_validator(raw: Variant, kind: String, index: int) -> Dictionary:
	if not raw is Dictionary or not _keys(raw, MANIFEST_KEYS) or not _integer(raw.get("profile_version"), 1, 1) or raw.get("kind") != kind or not _integer(raw.get("index"), index, index) or not _valid_id(raw.get("generation")) or not _integer(raw.get("saved_at"), 1, 9007199254740991) or not _valid_context(raw.get("context")) or not raw.get("campaigns") is Array:
		return _failure("PROFILE_INVALID_MANIFEST", "Unknown or damaged profile manifest.")
	var seen: Array = []
	for id in raw.campaigns:
		if not id is String or not Catalog.ENTRIES.has(id) or seen.has(id): return _failure("PROFILE_INVALID_MANIFEST", "Unknown or duplicate campaign in profile manifest.")
		seen.append(id)
	var normalized: Dictionary = raw.duplicate(true)
	normalized.profile_version = 1
	normalized.index = index
	normalized.saved_at = int(raw.saved_at)
	return {"ok": true, "snapshot": normalized}


func _collect_unreferenced() -> void:
	if not _guard().ok: return
	var retained: Dictionary = {"manual": {}, "active": {}}
	for index in range(0, SLOT_COUNT + 1):
		var kind: String = "active" if index == 0 else "manual"
		var path: String = _active_path if index == 0 else _slot_path(index)
		for pointer in [path, path + ".bak"]:
			if not _exists(pointer): continue
			var manifest: Dictionary = _read_manifest(pointer, kind, index)
			if not manifest.ok: return
			retained[kind][manifest.snapshot.generation] = true
	for prepared in _prepared.values(): retained.active[prepared.manifest.generation] = true
	for kind in ["manual", "active"]:
		var base: String = _generation_root(kind)
		if not DirAccess.dir_exists_absolute(base): continue
		if kind == "active" and _active_history_exists() and not _exists(_active_path) and not _exists(_active_path + ".bak"): continue
		for generation in DirAccess.get_directories_at(base):
			if retained[kind].has(generation) or not _valid_id(generation): continue
			var directory: String = base.path_join(generation)
			if not _owned_generation(directory, kind, generation): continue
			for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
			DirAccess.remove_absolute(directory)


func _owned_generation(directory: String, kind: String, generation: String) -> bool:
	if not _store._check_links(directory).ok: return false
	var marker: Dictionary = _read_json(directory + "/generation.json", 1024)
	if not marker.ok or not _valid_marker(marker.get("data"), kind, generation): return false
	var allowed: Array = ["generation.json", "generation.json.tmp", "habitat.json"]
	for id in Catalog.ENTRIES: allowed.append(id + ".json")
	if kind == "active":
		for name in allowed.duplicate():
			if name in ["generation.json", "generation.json.tmp"]: continue
			for suffix in [".bak", ".tmp", ".bak.tmp"]: allowed.append(name + suffix)
	var entries: DirAccess = DirAccess.open(directory)
	if entries == null: return false
	entries.include_hidden = true
	if entries.list_dir_begin() != OK: return false
	var file: String = entries.get_next()
	while not file.is_empty():
		if entries.current_is_dir() or entries.is_link(file) or not allowed.has(file):
			entries.list_dir_end()
			return false
		file = entries.get_next()
	entries.list_dir_end()
	return true


func _read_json(path: String, maximum: int) -> Dictionary:
	var safe: Dictionary = _store._check_links(path)
	if not safe.ok: return safe
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("PROFILE_READ_FAILED", "Profile file is missing or unreadable.")
	var length: int = file.get_length()
	if length > maximum:
		file.close()
		return _failure("PROFILE_SIZE_LIMIT", "Profile member exceeds its size limit.")
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	if bytes.size() != length or error not in [OK, ERR_FILE_EOF] or bytes.get_string_from_utf8().to_utf8_buffer() != bytes: return _failure("PROFILE_READ_FAILED", "Profile file could not be read completely as UTF-8.")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return _failure("PROFILE_INVALID_JSON", "Profile JSON is damaged.")
	return {"ok": true, "data": parser.data}


func _write_json(path: String, value: Dictionary, maximum: int) -> Dictionary:
	var bytes: PackedByteArray = JSON.stringify(value, "", true, true).to_utf8_buffer()
	if bytes.size() > maximum: return _failure("PROFILE_SIZE_LIMIT", "Profile member exceeds its size limit.")
	return _write_bytes(path, bytes)


func _write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
	var safe: Dictionary = _store._check_links(path)
	if not safe.ok: return safe
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _failure("PROFILE_WRITE_FAILED", "Could not open the staged profile file.")
	var stored: bool = file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if not stored or error != OK: return _failure("PROFILE_WRITE_FAILED", "Could not write the complete profile file.")
	return {"ok": true}


func _preserve_file(original: String, destination: String) -> Dictionary:
	for path in [original, destination]:
		var safe: Dictionary = _store._check_links(path)
		if not safe.ok: return safe
	var source: FileAccess = FileAccess.open(original, FileAccess.READ)
	if source == null: return _failure("PROFILE_PRESERVE_FAILED", "Could not read the damaged profile pointer for preservation.")
	var target: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if target == null:
		source.close()
		return _failure("PROFILE_PRESERVE_FAILED", "Could not preserve the damaged profile pointer.")
	var remaining: int = source.get_length()
	var copied := true
	while remaining > 0:
		var count: int = mini(remaining, 65536)
		var bytes: PackedByteArray = source.get_buffer(count)
		if bytes.size() != count or not target.store_buffer(bytes):
			copied = false
			break
		remaining -= count
	target.flush()
	copied = copied and source.get_error() in [OK, ERR_FILE_EOF] and target.get_error() == OK
	source.close()
	target.close()
	return {"ok": true} if copied else _failure("PROFILE_PRESERVE_FAILED", "Could not preserve every byte of the damaged profile pointer.")


func _guard() -> Dictionary:
	if _root != ROOT and not _root.begins_with("user://tests/"): return _failure("PROFILE_ROOT_REJECTED", "Only profile storage or an isolated test root is allowed.")
	var relative: String = _root.trim_prefix("user://")
	if relative.contains("\\") or relative.contains(":"): return _failure("PROFILE_ROOT_REJECTED", "Invalid profile storage root.")
	for part in relative.split("/"):
		if part.is_empty() or part in [".", ".."]: return _failure("PROFILE_ROOT_REJECTED", "Invalid profile storage root component.")
	for index in relative.length():
		if relative.unicode_at(index) < 32 or relative.unicode_at(index) == 127: return _failure("PROFILE_ROOT_REJECTED", "Invalid profile storage root character.")
	for path in [_root, _generation_root("manual"), _active_root, _active_path, _active_path + ".bak", _active_root + "/active_selected.json", _active_root + "/active_selected.json.tmp"]:
		var safe: Dictionary = _store._check_links(path)
		if not safe.ok: return safe
	return {"ok": true}


func _generation_root(kind: String) -> String:
	return _root + "/slot_generations" if kind == "manual" else _active_root


func _slot_path(index: int) -> String:
	return _root + "/slot_%02d.json" % index


static func _valid_context(value: Variant) -> bool:
	return value is Dictionary and _keys(value, ["pack_id", "mode", "zone", "return_pack_id"]) and value.pack_id is String and Catalog.ENTRIES.has(value.pack_id) and value.mode is String and value.mode in ["desktop", "room", "menu"] and value.zone is String and value.zone in ["room", "courtyard"] and value.return_pack_id is String and (value.return_pack_id.is_empty() or Catalog.ENTRIES.has(value.return_pack_id))


static func _context_matches(context: Dictionary, snapshots: Dictionary) -> bool:
	if context.mode == "desktop" and snapshots.campaigns[context.pack_id] == null: return false
	if context.pack_id == "investigation" and not context.return_pack_id.is_empty():
		return context.return_pack_id != "investigation" and snapshots.campaigns[context.return_pack_id] != null
	return true


static func _valid_marker(value: Variant, kind: String, generation: String) -> bool:
	return value is Dictionary and (_keys(value, ["profile_version", "kind", "generation"]) or (_keys(value, ["profile_version", "kind", "generation", "selected"]) and value.selected is bool)) and _integer(value.profile_version, 1, 1) and value.kind == kind and value.generation == generation


static func _valid_id(value: Variant) -> bool:
	if not value is String or value.length() != 34 or not value.begins_with("g_"): return false
	for character in value.substr(2):
		if not character in "0123456789abcdef": return false
	return true


static func _new_id() -> String:
	return "g_" + Crypto.new().generate_random_bytes(16).hex_encode()


static func _keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _failure(code: String, text: String) -> Dictionary:
	return {"ok": false, "code": code, "text": text}
