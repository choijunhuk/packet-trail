extends RefCounted

const MAX_BYTES := 2 * 1024 * 1024
const DEFAULT_PATH := "user://saves/slot_01.json"

var _recovery_sequence := 0


func save(snapshot: Dictionary, validator: Callable, path: String = DEFAULT_PATH) -> Dictionary:
	var guard: Dictionary = _guard(path, validator)
	if not guard["ok"]:
		return guard
	var checked: Dictionary = _validated(snapshot, validator)
	if not checked["ok"]:
		return checked
	var expected: Dictionary = checked["snapshot"]
	var previous: Dictionary = {}
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		previous = _read_snapshot(path, validator)
		if not previous["ok"]:
			return _recovery_required(path, validator, previous["text"])
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return _io_error("SAVE_DIRECTORY_FAILED", "저장 폴더를 만들 수 없습니다.", directory_error)
	var bytes: PackedByteArray = JSON.stringify(expected, "", true, true).to_utf8_buffer()
	var staged: Dictionary = _stage(path + ".tmp", bytes, expected, validator)
	if not staged["ok"]:
		return staged
	if not previous.is_empty():
		var backup: Dictionary = _stage(
			path + ".bak.tmp", previous["bytes"], previous["snapshot"], validator
		)
		if not backup["ok"]:
			return backup
		var backup_error: Error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if backup_error != OK:
			return _io_error("SAVE_BACKUP_REPLACE_FAILED", "정상 백업을 갱신하지 못했습니다.", backup_error)
	# shortcut: 단일 프로세스의 동기 슬롯만 지원하며, 슬롯을 여러 프로세스가 공유하면 잠금이 필요하다.
	var replace_error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if replace_error != OK:
		return _io_error("SAVE_REPLACE_FAILED", "기존 저장을 보존한 채 교체를 중단했습니다.", replace_error)
	return {"ok": true, "code": "SAVED", "text": "진행을 저장했습니다."}


func load_save(validator: Callable, path: String = DEFAULT_PATH) -> Dictionary:
	var guard: Dictionary = _guard(path, validator)
	if not guard["ok"]:
		return guard
	var loaded: Dictionary = _read_snapshot(path, validator)
	if loaded["ok"]:
		return {"ok": true, "code": "LOADED", "text": "저장한 진행을 읽었습니다.", "snapshot": loaded["snapshot"]}
	loaded.erase("bytes")
	loaded["backup_available"] = _read_snapshot(path + ".bak", validator)["ok"]
	return loaded


func recover_backup(validator: Callable, path: String = DEFAULT_PATH) -> Dictionary:
	var guard: Dictionary = _guard(path, validator)
	if not guard["ok"]:
		return guard
	var current: Dictionary = _read_snapshot(path, validator)
	if current["ok"]:
		return _failure("SAVE_RECOVERY_NOT_NEEDED", "현재 저장이 정상이므로 이전 백업으로 바꾸지 않았습니다.")
	var backup: Dictionary = _read_snapshot(path + ".bak", validator)
	if not backup["ok"]:
		var unavailable: Dictionary = _failure("SAVE_BACKUP_INVALID", "복구 가능한 정상 백업이 없습니다. " + backup["text"])
		unavailable["backup_available"] = false
		return unavailable
	var staged: Dictionary = _stage(path + ".tmp", backup["bytes"], backup["snapshot"], validator)
	if not staged["ok"]:
		return staged
	var damaged_path := ""
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		if DirAccess.dir_exists_absolute(path):
			return _failure("SAVE_PATH_IS_DIRECTORY", "저장 위치가 폴더여서 복구하지 않았습니다.")
		damaged_path = _damaged_path(path)
		if damaged_path.is_empty():
			return _failure("SAVE_RECOVERY_PATH_FAILED", "손상 원본을 보존할 새 이름을 만들지 못했습니다.")
		var preserve_error: Error = DirAccess.rename_absolute(path, damaged_path)
		if preserve_error != OK:
			return _io_error("SAVE_PRESERVE_FAILED", "손상 원본을 보존하지 못해 복구를 중단했습니다.", preserve_error)
	var restore_error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if restore_error != OK:
		var failed: Dictionary = _io_error("SAVE_RECOVERY_FAILED", "백업과 원본을 보존했지만 복구하지 못했습니다.", restore_error)
		failed["damaged_path"] = damaged_path
		return failed
	return {
		"ok": true, "code": "RECOVERED", "text": "정상 백업을 복구했습니다.",
		"snapshot": backup["snapshot"].duplicate(true), "damaged_path": damaged_path,
	}


func start_new(snapshot: Dictionary, validator: Callable, path: String = DEFAULT_PATH) -> Dictionary:
	var guard: Dictionary = _guard(path, validator)
	if not guard["ok"]:
		return guard
	if _read_snapshot(path, validator)["ok"]:
		return _failure("RECOVERY_NOT_NEEDED", "현재 저장이 정상이므로 새 저장으로 바꾸지 않았습니다.")
	var checked: Dictionary = _validated(snapshot, validator)
	if not checked["ok"]:
		return checked
	for original in [path, path + ".bak"]:
		if DirAccess.dir_exists_absolute(original):
			return _failure("SAVE_PATH_IS_DIRECTORY", "기존 저장 위치가 폴더여서 새 저장을 시작하지 않았습니다.")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return _io_error("SAVE_DIRECTORY_FAILED", "저장 폴더를 만들 수 없습니다.", directory_error)
	var expected: Dictionary = checked["snapshot"]
	var bytes: PackedByteArray = JSON.stringify(expected, "", true, true).to_utf8_buffer()
	var staged: Dictionary = _stage(path + ".tmp", bytes, expected, validator)
	if not staged["ok"]:
		return staged
	var preserved: Dictionary = {}
	for original in [path, path + ".bak"]:
		if not FileAccess.file_exists(original):
			continue
		var damaged: String = _damaged_path(original)
		if damaged.is_empty():
			return _rollback_new(preserved, _failure("SAVE_RECOVERY_PATH_FAILED", "이전 파일을 보존할 새 이름을 만들지 못했습니다."))
		var safe: Dictionary = _check_links(damaged)
		if not safe["ok"]:
			return _rollback_new(preserved, safe)
		var preserve_error: Error = DirAccess.rename_absolute(original, damaged)
		if preserve_error != OK:
			return _rollback_new(preserved, _io_error("SAVE_PRESERVE_FAILED", "이전 파일을 보존하지 못해 새 저장을 중단했습니다.", preserve_error))
		preserved[original] = damaged
	var replace_error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if replace_error != OK:
		return _rollback_new(preserved, _io_error("SAVE_NEW_REPLACE_FAILED", "새 저장 교체에 실패했습니다.", replace_error))
	return {
		"ok": true, "code": "NEW_STARTED", "text": "이전 파일을 별도로 보존하고 현재 진행을 새로 저장했습니다.",
		"damaged_path": preserved.get(path, ""), "damaged_backup_path": preserved.get(path + ".bak", ""),
	}


func _rollback_new(preserved: Dictionary, failure: Dictionary) -> Dictionary:
	var remaining: Array[String] = []
	var errors := PackedStringArray()
	var originals: Array = preserved.keys()
	originals.reverse()
	for original in originals:
		var damaged: String = preserved[original]
		if FileAccess.file_exists(original) or DirAccess.dir_exists_absolute(original):
			errors.append("기존 경로가 점유돼 원위치로 복원하지 않았습니다: " + damaged)
			remaining.append(damaged)
			continue
		var restore_error: Error = DirAccess.rename_absolute(damaged, original)
		if restore_error != OK:
			errors.append("원위치 복원 실패: " + damaged + " (" + error_string(restore_error) + ")")
			remaining.append(damaged)
	failure["preserved_paths"] = remaining
	if not errors.is_empty():
		failure["text"] += " " + " ".join(errors)
	elif not preserved.is_empty():
		failure["text"] += " 이전 파일은 원래 위치로 복원했습니다."
	return failure


func path_status(path: String, validator: Callable) -> Dictionary:
	var guard: Dictionary = _guard(path, validator)
	if not guard.ok: return guard
	return {"ok": true, "exists": FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path), "backup_exists": FileAccess.file_exists(path + ".bak") or DirAccess.dir_exists_absolute(path + ".bak")}


func _guard(path: String, validator: Callable) -> Dictionary:
	if not validator.is_valid():
		return _failure("SAVE_INVALID_VALIDATOR", "저장 검증 함수를 사용할 수 없습니다.")
	if not (path.begins_with("user://saves/") or path.begins_with("user://tests/")) or not path.ends_with(".json"):
		return _failure("SAVE_PATH_REJECTED", "로컬 저장 폴더의 JSON 경로만 사용할 수 있습니다.")
	var relative: String = path.trim_prefix("user://")
	if relative.contains("\\") or relative.contains(":"):
		return _failure("SAVE_PATH_REJECTED", "올바르지 않은 저장 경로입니다.")
	for part in relative.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return _failure("SAVE_PATH_REJECTED", "상위 경로나 빈 경로를 사용할 수 없습니다.")
	for index in range(relative.length()):
		if relative.unicode_at(index) < 32 or relative.unicode_at(index) == 127:
			return _failure("SAVE_PATH_REJECTED", "제어 문자가 포함된 저장 경로입니다.")
	for candidate in [path, path + ".tmp", path + ".bak", path + ".bak.tmp"]:
		var links: Dictionary = _check_links(candidate)
		if not links["ok"]:
			return links
	return {"ok": true}


func _check_links(path: String) -> Dictionary:
	var parent := "user://"
	for part in path.trim_prefix("user://").split("/"):
		if not DirAccess.dir_exists_absolute(parent):
			return {"ok": true}
		var directory: DirAccess = DirAccess.open(parent)
		if directory == null:
			return _io_error("SAVE_DIRECTORY_OPEN_FAILED", "저장 경로를 확인할 수 없습니다.", DirAccess.get_open_error())
		if directory.is_link(part):
			return _failure("SAVE_PATH_REJECTED", "심볼릭 링크를 저장 경로로 사용할 수 없습니다.")
		parent = parent.path_join(part)
	return {"ok": true}


func _validated(raw: Variant, validator: Callable) -> Dictionary:
	var candidate: Variant = raw
	if raw is Dictionary or raw is Array:
		candidate = raw.duplicate(true)
	var result: Variant = validator.call(candidate)
	if not result is Dictionary or result.get("ok") != true or not result.get("snapshot") is Dictionary:
		var text := "저장 데이터가 검증을 통과하지 못했습니다."
		if result is Dictionary:
			text = str(result.get("text", text))
		return _failure("SAVE_INVALID_SNAPSHOT", text)
	return {"ok": true, "snapshot": result["snapshot"].duplicate(true)}


func _stage(path: String, bytes: PackedByteArray, expected: Dictionary, validator: Callable) -> Dictionary:
	if bytes.size() > MAX_BYTES:
		return _failure("SAVE_SIZE_LIMIT", "저장 데이터는 2 MiB를 넘을 수 없습니다.")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _io_error("SAVE_WRITE_OPEN_FAILED", "임시 저장 파일을 열지 못했습니다.", FileAccess.get_open_error())
	var stored: bool = file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if not stored or write_error != OK:
		return _io_error("SAVE_WRITE_FAILED", "임시 저장 파일을 쓰지 못했습니다.", write_error if write_error != OK else ERR_FILE_CANT_WRITE)
	var verified: Dictionary = _read_snapshot(path, validator)
	if not verified["ok"]:
		return verified
	if not verified["snapshot"].recursive_equal(expected, 64):
		return _failure("SAVE_ROUNDTRIP_MISMATCH", "재읽기 결과가 원래 저장 값과 달라 교체하지 않았습니다.")
	return {"ok": true}


func _read_snapshot(path: String, validator: Callable) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _io_error("SAVE_NOT_FOUND" if open_error == ERR_FILE_NOT_FOUND else "SAVE_READ_OPEN_FAILED", "저장 파일을 읽을 수 없습니다.", open_error)
	var length: int = file.get_length()
	if length > MAX_BYTES:
		file.close()
		return _failure("SAVE_SIZE_LIMIT", "저장 파일이 2 MiB 제한을 넘습니다.")
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or (read_error != OK and read_error != ERR_FILE_EOF):
		return _io_error("SAVE_READ_FAILED", "저장 파일을 끝까지 읽지 못했습니다.", read_error if read_error != OK else ERR_FILE_CANT_READ)
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure("SAVE_INVALID_ENCODING", "저장 파일의 UTF-8 인코딩이 손상되었습니다.")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("SAVE_INVALID_JSON", "저장 JSON이 손상되었습니다: " + parser.get_error_message())
	var checked: Dictionary = _validated(parser.data, validator)
	if not checked["ok"]:
		return checked
	checked["bytes"] = bytes
	return checked


func _recovery_required(path: String, validator: Callable, reason: String) -> Dictionary:
	var result: Dictionary = _failure("SAVE_RECOVERY_REQUIRED", "기존 저장을 덮어쓰지 않았습니다. 복구를 먼저 확인하세요. " + reason)
	result["backup_available"] = _read_snapshot(path + ".bak", validator)["ok"]
	return result


func _damaged_path(path: String) -> String:
	for _attempt in range(16):
		_recovery_sequence += 1
		var candidate: String = path.trim_suffix(".json") + ".damaged_%d_%d.json" % [Time.get_ticks_usec(), _recovery_sequence]
		if not FileAccess.file_exists(candidate) and not DirAccess.dir_exists_absolute(candidate):
			return candidate
	return ""


func _failure(code: String, text: String) -> Dictionary:
	return {"ok": false, "code": code, "text": text}


func _io_error(code: String, text: String, error: Error) -> Dictionary:
	return _failure(code, text + " (" + error_string(error) + ")")
