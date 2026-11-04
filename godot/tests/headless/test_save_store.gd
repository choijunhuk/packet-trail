extends RefCounted

const SaveStore = preload("res://scripts/core/save_store.gd")

var _checks := 0
var _failures: Array[String] = []
var _root := ""
var _saw_json_float := false


func run() -> Dictionary:
	_checks = 0
	_failures.clear()
	_saw_json_float = false
	_root = "user://tests/save_store_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(_root)
	_check(directory_error == OK, "고유 테스트 폴더 생성")
	if directory_error == OK:
		_test_missing()
		_test_round_trip()
		_test_validation_rejection()
		_test_damage_and_recovery()
		_test_invalid_backup()
		_test_start_new()
		_test_start_new_failures()
		_test_write_failures()
		_test_size_limit()
		_test_paths()
		_test_round_trip_mismatch()
		_remove_tree(_root)
	return {"checks": _checks, "failures": _failures.duplicate()}


func _test_missing() -> void:
	var store = SaveStore.new()
	var result: Dictionary = store.load_save(_validator, _root + "/missing.json")
	_check(not result["ok"] and not result.has("snapshot"), "없는 슬롯은 스냅샷을 반환하지 않음")
	_check(not result.get("backup_available", true), "없는 슬롯의 백업도 없음")
	_check(not str(result["text"]).is_empty(), "읽기 실패를 명시적으로 설명")


func _test_round_trip() -> void:
	var store = SaveStore.new()
	var path: String = _root + "/roundtrip.json"
	var source: Dictionary = _fixture()
	# 저장기의 추출/정규화 함수로 기대값을 만들지 않는다.
	var expected: Dictionary = _fixture()
	var saved: Dictionary = store.save(source, _validator, path)
	_check(saved["ok"], "중첩 비기본 스냅샷 저장: " + saved["text"])
	if not saved["ok"]:
		return
	source["world"]["files"][0]["content"] = "호출자가 나중에 바꾼 값"
	source["world"]["messages"][0]["body"] = "바뀐 답장"
	var loaded: Dictionary = store.load_save(_validator, path)
	_check(loaded["ok"], "정상 저장 재읽기")
	if loaded["ok"]:
		_check(loaded["snapshot"].recursive_equal(expected, 64), "독립 기대값의 모든 중첩 지속 값 보존")
		loaded["snapshot"]["world"]["archive"][0]["content"] = "반환 사본 변경"
		var reread: Dictionary = store.load_save(_validator, path)
		_check(reread["ok"] and reread["snapshot"].recursive_equal(expected, 64), "읽기 반환값 변경은 저장에 영향 없음")
	_check(_saw_json_float, "JSON 숫자는 validator에서 정수로 정규화됨")
	_check(not FileAccess.file_exists(path + ".bak"), "첫 저장은 없는 이전 본문을 백업으로 만들지 않음")
	var next: Dictionary = _second_fixture()
	var second: Dictionary = store.save(next, _validator, path)
	_check(second["ok"], "두 번째 정상 저장")
	if second["ok"]:
		var backup: Dictionary = _parse_fixture(path + ".bak")
		_check(backup.get("ok", false) and backup["snapshot"].recursive_equal(expected, 64), "백업은 직전 정상 본문의 깊은 값")
		var current: Dictionary = store.load_save(_validator, path)
		_check(current["ok"] and current["snapshot"].recursive_equal(next, 64), "새 본문은 새 스냅샷")


func _test_validation_rejection() -> void:
	var path: String = _root + "/rejection.json"
	if not _seed_pair(path):
		return
	var main_before: PackedByteArray = _read_bytes(path)
	var backup_before: PackedByteArray = _read_bytes(path + ".bak")
	var unknown_version: Dictionary = _fixture()
	unknown_version["save_version"] = 99
	var missing_field: Dictionary = _fixture()
	missing_field["world"].erase("session")
	var unknown_reference: Dictionary = _fixture()
	unknown_reference["world"]["session"]["host_id"] = "unknown_host"
	var store = SaveStore.new()
	for invalid in [unknown_version, missing_field, unknown_reference]:
		var result: Dictionary = store.save(invalid, _validator, path)
		_check(not result["ok"], "버전/필드/참조 검증 거절")
		_check(_read_bytes(path) == main_before and _read_bytes(path + ".bak") == backup_before, "검증 거절은 정상 본문/백업을 보존")
	var bad_callable: Dictionary = store.save(_fixture(), Callable(), path)
	_check(not bad_callable["ok"] and bad_callable["code"] == "SAVE_INVALID_VALIDATOR", "없는 validator 거절")
	var bad_result := func(_raw: Variant) -> Dictionary:
		return {"ok": true, "snapshot": "not a dictionary", "text": "잘못된 검증 반환"}
	_check(not store.save(_fixture(), bad_result, path)["ok"], "잘못된 validator 반환 계약 거절")
	_check(_read_bytes(path) == main_before and _read_bytes(path + ".bak") == backup_before, "validator 오류도 기존 정상본 보존")


func _test_damage_and_recovery() -> void:
	var path: String = _root + "/recovery.json"
	if not _seed_pair(path):
		return
	var store = SaveStore.new()
	var backup_before: PackedByteArray = _read_bytes(path + ".bak")
	var damaged := "{ broken JSON"
	if not _write_bytes(path, damaged.to_utf8_buffer()):
		return
	var loaded: Dictionary = store.load_save(_validator, path)
	_check(not loaded["ok"] and loaded.get("backup_available", false), "손상 본문은 유효 백업의 존재만 보고")
	_check(not loaded.has("snapshot") and _read_bytes(path) == damaged.to_utf8_buffer(), "불러오기는 손상 원본/메모리용 스냅샷을 바꾸지 않음")
	var blocked: Dictionary = store.save(_fixture(), _validator, path)
	_check(not blocked["ok"] and blocked["code"] == "SAVE_RECOVERY_REQUIRED", "손상 본문 위 자동 저장 차단")
	_check(_read_bytes(path) == damaged.to_utf8_buffer() and _read_bytes(path + ".bak") == backup_before, "차단 후 손상 원본과 정상 백업 보존")
	var block_error: Error = DirAccess.make_dir_absolute(path + ".tmp")
	_check(block_error == OK, "복구 쓰기 실패용 폴더 생성")
	if block_error == OK:
		var failed: Dictionary = store.recover_backup(_validator, path)
		_check(not failed["ok"], "복구 쓰기 실패를 성공으로 숨기지 않음")
		_check(_read_bytes(path) == damaged.to_utf8_buffer() and _read_bytes(path + ".bak") == backup_before, "복구 실패도 원본/백업 보존")
		_check(DirAccess.remove_absolute(path + ".tmp") == OK, "복구 실패 방해 폴더 정리")
	var recovered: Dictionary = store.recover_backup(_validator, path)
	_check(recovered["ok"], "명시적 백업 복구")
	if not recovered["ok"]:
		return
	var preserved: String = recovered.get("damaged_path", "")
	_check(preserved.begins_with(_root + "/") and FileAccess.file_exists(preserved), "손상 원본을 고유 파일로 보존")
	if not preserved.is_empty():
		_check(_read_bytes(preserved) == damaged.to_utf8_buffer(), "보존한 손상 원본의 바이트 일치")
	_check(recovered["snapshot"].recursive_equal(_fixture(), 64), "복구는 정상 백업 스냅샷을 반환")
	_check(_read_bytes(path + ".bak") == backup_before, "복구가 정상 백업 자체를 변경하지 않음")
	var main_before: PackedByteArray = _read_bytes(path)
	var unnecessary: Dictionary = store.recover_backup(_validator, path)
	_check(not unnecessary["ok"] and _read_bytes(path) == main_before, "정상 본문을 오래된 백업으로 되돌리지 않음")
	if _write_bytes(path, "{ second damage".to_utf8_buffer()):
		var again: Dictionary = store.recover_backup(_validator, path)
		_check(again["ok"] and again.get("damaged_path", "") != preserved, "반복 복구의 damaged 이름은 서로 다름")
		_check(FileAccess.file_exists(preserved) and _read_bytes(preserved) == damaged.to_utf8_buffer(), "다음 복구도 이전 손상 원본 보존")


func _test_invalid_backup() -> void:
	var path: String = _root + "/invalid_backup.json"
	if not _seed_pair(path):
		return
	var invalid: Dictionary = _fixture()
	invalid["save_version"] = 88
	var main_bytes: PackedByteArray = JSON.stringify(invalid).to_utf8_buffer()
	var backup_bytes: PackedByteArray = "not JSON".to_utf8_buffer()
	if not _write_bytes(path, main_bytes) or not _write_bytes(path + ".bak", backup_bytes):
		return
	var store = SaveStore.new()
	var loaded: Dictionary = store.load_save(_validator, path)
	_check(not loaded["ok"] and not loaded.get("backup_available", true), "미지원 버전과 손상 백업을 정상으로 읽지 않음")
	_check(not store.recover_backup(_validator, path)["ok"], "손상 백업 복구 거절")
	_check(not store.save(_fixture(), _validator, path)["ok"], "미지원 기존 저장 위 자동 저장 거절")
	_check(_read_bytes(path) == main_bytes and _read_bytes(path + ".bak") == backup_bytes, "모두 실패한 뒤 두 원본 보존")


func _test_start_new() -> void:
	var path: String = _root + "/new_after_damage.json"
	if not _seed_pair(path):
		return
	var main_bytes: PackedByteArray = "{ damaged main".to_utf8_buffer()
	var backup_bytes: PackedByteArray = "[ damaged backup".to_utf8_buffer()
	if not _write_bytes(path, main_bytes) or not _write_bytes(path + ".bak", backup_bytes):
		return
	var store = SaveStore.new()
	var expected: Dictionary = _second_fixture()
	var result: Dictionary = store.start_new(expected, _validator, path)
	_check(result["ok"], "두 원본 모두 손상돼도 명시적 새 저장 시작")
	if not result["ok"]:
		return
	var damaged_main: String = result.get("damaged_path", "")
	var damaged_backup: String = result.get("damaged_backup_path", "")
	_check(damaged_main.begins_with(_root + "/") and damaged_backup.begins_with(_root + "/") and damaged_main != damaged_backup, "두 이전 원본의 서로 다른 고유 보존 경로")
	if not damaged_main.is_empty() and not damaged_backup.is_empty():
		_check(_read_bytes(damaged_main) == main_bytes and _read_bytes(damaged_backup) == backup_bytes, "이전 main/bak 두 원본의 바이트 보존")
	var loaded: Dictionary = store.load_save(_validator, path)
	_check(loaded["ok"] and loaded["snapshot"].recursive_equal(expected, 64), "새 저장은 현재 진행으로 정상 load")
	_check(store.save(_fixture(), _validator, path)["ok"], "새 저장 뒤 일반 저장도 다시 가능")
	var main_before: PackedByteArray = _read_bytes(path)
	var backup_before: PackedByteArray = _read_bytes(path + ".bak")
	var protected: Dictionary = store.start_new(_second_fixture(), _validator, path)
	_check(not protected["ok"] and protected["code"] == "RECOVERY_NOT_NEEDED", "정상 main에서 새 저장 오조작 보호")
	_check(_read_bytes(path) == main_before and _read_bytes(path + ".bak") == backup_before, "오조작 거절 뒤 정상 main/bak 보존")
	var valid_backup_path: String = _root + "/new_with_valid_backup.json"
	if _seed_pair(valid_backup_path) and _write_bytes(valid_backup_path, main_bytes):
		_check(store.load_save(_validator, valid_backup_path).get("backup_available", false), "유효 bak이면 기존 복구 선택도 안내 가능")
		var valid_backup: PackedByteArray = _read_bytes(valid_backup_path + ".bak")
		var explicit: Dictionary = store.start_new(_second_fixture(), _validator, valid_backup_path)
		_check(explicit["ok"], "유효 bak이 있어도 명시적으로 현재 진행 새 저장 가능")
		if explicit["ok"]:
			_check(_read_bytes(explicit["damaged_backup_path"]) == valid_backup, "새 저장 선택도 이전 정상 bak를 별도 보존")


func _test_start_new_failures() -> void:
	var path: String = _root + "/new_failure.json"
	if not _seed_pair(path):
		return
	var main_bytes: PackedByteArray = "{ original main".to_utf8_buffer()
	var backup_bytes: PackedByteArray = "{ original backup".to_utf8_buffer()
	if not _write_bytes(path, main_bytes) or not _write_bytes(path + ".bak", backup_bytes):
		return
	var store = SaveStore.new()
	var invalid: Dictionary = _fixture()
	invalid["save_version"] = 99
	_check(not store.start_new(invalid, _validator, path)["ok"], "새 저장도 입력 검증 거절")
	_check(_read_bytes(path) == main_bytes and _read_bytes(path + ".bak") == backup_bytes, "새 저장 검증 실패 시 두 원본 보존")
	var mkdir_error: Error = DirAccess.make_dir_absolute(path + ".tmp")
	_check(mkdir_error == OK, "새 저장 stage 실패용 폴더 생성")
	if mkdir_error == OK:
		_check(not store.start_new(_fixture(), _validator, path)["ok"], "새 저장 stage 실제 I/O 실패 보고")
		_check(_read_bytes(path) == main_bytes and _read_bytes(path + ".bak") == backup_bytes, "stage 실패 전에 원본을 옮기지 않음")
		_check(DirAccess.remove_absolute(path + ".tmp") == OK, "새 저장 stage 방해 폴더 정리")
	var injected := [false]
	# tmp 재검증 직후 실제 파일 소실을 주입해 원본 이동 뒤의 교체 실패를 검사한다.
	var lose_staged_file := func(raw: Variant) -> Dictionary:
		var checked: Dictionary = _validator(raw)
		if checked["ok"] and FileAccess.file_exists(path + ".tmp"):
			var move_error: Error = DirAccess.rename_absolute(path + ".tmp", path + ".lost_tmp")
			_check(move_error == OK, "새 저장 교체 실패용 tmp 소실 주입")
			injected[0] = move_error == OK
		return checked
	var failed: Dictionary = store.start_new(_fixture(), lose_staged_file, path)
	_check(injected[0] and not failed["ok"] and failed["code"] == "SAVE_NEW_REPLACE_FAILED", "두 원본 보존 뒤 실제 교체 실패 보고")
	_check(_read_bytes(path) == main_bytes and _read_bytes(path + ".bak") == backup_bytes, "교체 실패는 main/bak 두 원본을 원위치 복원")
	_check(not failed.has("snapshot"), "새 저장 실패는 메모리 진행 교체용 스냅샷을 반환하지 않음")


func _test_write_failures() -> void:
	var path: String = _root + "/write_failure.json"
	if not _seed_pair(path):
		return
	var main_before: PackedByteArray = _read_bytes(path)
	var backup_before: PackedByteArray = _read_bytes(path + ".bak")
	var store = SaveStore.new()
	for suffix in [".tmp", ".bak.tmp"]:
		var blocked_path: String = path + suffix
		var mkdir_error: Error = DirAccess.make_dir_absolute(blocked_path)
		_check(mkdir_error == OK, "실제 쓰기 실패용 폴더: " + suffix)
		if mkdir_error == OK:
			var result: Dictionary = store.save(_fixture(), _validator, path)
			_check(not result["ok"] and not str(result["text"]).is_empty(), "실제 임시 파일 열기 실패 보고: " + suffix)
			_check(_read_bytes(path) == main_before and _read_bytes(path + ".bak") == backup_before, "쓰기 실패 뒤 정상 본문/백업 보존: " + suffix)
			_check(DirAccess.remove_absolute(blocked_path) == OK, "쓰기 실패 방해 폴더 정리: " + suffix)
	var parent: String = _root + "/parent_is_file"
	if _write_bytes(parent, "keep me".to_utf8_buffer()):
		_check(not store.save(_fixture(), _validator, parent + "/slot.json")["ok"], "부모가 파일인 경로의 저장 실패")
		_check(_read_bytes(parent) == "keep me".to_utf8_buffer(), "폴더 생성 실패가 기존 파일을 지우지 않음")
	var rename_path: String = _root + "/rename_failure.json"
	var first: Dictionary = store.save(_fixture(), _validator, rename_path)
	_check(first["ok"], "rename 실패 검사용 정상 본문 준비")
	if first["ok"]:
		var old_main: PackedByteArray = _read_bytes(rename_path)
		var block_error: Error = DirAccess.make_dir_absolute(rename_path + ".bak")
		_check(block_error == OK, "백업 rename 실패용 폴더 준비")
		if block_error == OK:
			var replaced: Dictionary = store.save(_second_fixture(), _validator, rename_path)
			_check(not replaced["ok"] and replaced["code"] == "SAVE_BACKUP_REPLACE_FAILED", "실제 백업 rename 오류 보고")
			_check(_read_bytes(rename_path) == old_main, "rename 실패 시 기존 정상 본문 보존")


func _test_size_limit() -> void:
	var path: String = _root + "/size.json"
	if not _seed_pair(path):
		return
	var main_before: PackedByteArray = _read_bytes(path)
	var backup_before: PackedByteArray = _read_bytes(path + ".bak")
	var oversized: Dictionary = _fixture()
	oversized["world"]["files"][0]["content"] = "x".repeat(SaveStore.MAX_BYTES)
	var store = SaveStore.new()
	var rejected: Dictionary = store.save(oversized, _validator, path)
	_check(not rejected["ok"] and rejected["code"] == "SAVE_SIZE_LIMIT", "JSON 인코딩 후 2 MiB 초과 저장 거절")
	_check(_read_bytes(path) == main_before and _read_bytes(path + ".bak") == backup_before, "초과 저장도 정상본/백업 보존")
	var large_path: String = _root + "/oversize_read.json"
	var bytes := PackedByteArray()
	bytes.resize(SaveStore.MAX_BYTES + 1)
	bytes.fill(32)
	if _write_bytes(large_path, bytes):
		var loaded: Dictionary = store.load_save(_validator, large_path)
		_check(not loaded["ok"] and loaded["code"] == "SAVE_SIZE_LIMIT", "2 MiB 초과 읽기는 파싱 전에 거절")


func _test_paths() -> void:
	var store = SaveStore.new()
	var invalid_paths: Array[String] = [
		"res://save.json", "/tmp/save.json", "user://saves/../escape.json",
		"user://tests/./escape.json", "user://tests//escape.json", "user://other/save.json",
		_root + "/wrong.txt", _root + "/back\\slash.json", _root + "/line\nbreak.json",
	]
	for path in invalid_paths:
		for result in [store.save(_fixture(), _validator, path), store.load_save(_validator, path), store.recover_backup(_validator, path), store.start_new(_fixture(), _validator, path)]:
			_check(not result["ok"] and result["code"] == "SAVE_PATH_REJECTED", "네 공개 API의 경로 거절: " + path)
	var nested: String = _root + "/nested/deeper/slot.json"
	_check(store.save(_fixture(), _validator, nested)["ok"], "유효한 고유 테스트 하위 폴더는 생성 가능")


func _test_round_trip_mismatch() -> void:
	var store = SaveStore.new()
	var path: String = _root + "/mismatch.json"
	var calls := [0]
	var unstable := func(raw: Variant) -> Dictionary:
		var checked: Dictionary = _validator(raw)
		calls[0] += 1
		if checked["ok"] and calls[0] > 1:
			checked["snapshot"]["world"]["alert_level"] += 1
		return checked
	var result: Dictionary = store.save(_fixture(), unstable, path)
	_check(calls[0] >= 2, "tmp 재읽기에도 validator 호출")
	_check(not result["ok"] and result["code"] == "SAVE_ROUNDTRIP_MISMATCH", "정규화 재읽기의 중첩 값 변경 검출")
	_check(not FileAccess.file_exists(path), "재읽기 불일치 시 본문을 만들지 않음")


func _fixture() -> Dictionary:
	return {
		"save_version": 1, "mission_id": "M01",
		"world": {
			"session": {"host_id": "night_archive", "account_id": "maint", "cwd": "/handoff/night", "connected": true},
			"permissions": {"maint": ["read", "archive"], "guest": ["read_notice"]},
			"files": [{"path": "/handoff/night/record.txt", "record_id": "handoff_202", "source": "night_archive", "content": "삭제 전 인계 기록\n두 번째 줄"}],
			"archive": [{"name": "인계 사본", "record_id": "handoff_202", "source": "maint_session", "content": "회수한 허구 자료"}],
			"messages": [{"id": "reply_1", "sender": "서윤", "subject": "사본 확인", "body": "고마워요. 다음 단서입니다."}],
			"alert_level": 1, "completed": true, "next_clue": {"id": "clue_2", "seen": false},
			"notes": ["가상 경로", {"attempts": 3, "ratio": 0.375}, null], "empty": [],
		},
	}


func _second_fixture() -> Dictionary:
	var snapshot: Dictionary = _fixture()
	snapshot["world"]["session"]["cwd"] = "/handoff"
	snapshot["world"]["alert_level"] = 2
	snapshot["world"]["files"][0]["content"] = "다음 정상 본문"
	snapshot["world"]["next_clue"]["seen"] = true
	return snapshot


func _validator(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.has_all(["save_version", "mission_id", "world"]):
		return {"ok": false, "text": "필수 저장 필드 누락"}
	if typeof(raw["save_version"]) != TYPE_INT and typeof(raw["save_version"]) != TYPE_FLOAT:
		return {"ok": false, "text": "버전 자료형 오류"}
	if typeof(raw["save_version"]) == TYPE_FLOAT:
		_saw_json_float = true
	if raw["save_version"] != 1 or raw["mission_id"] != "M01":
		return {"ok": false, "text": "지원하지 않는 버전/미션"}
	var world: Variant = raw["world"]
	if not world is Dictionary or not world.has_all(["session", "permissions", "files", "archive", "messages", "alert_level", "completed", "next_clue", "notes", "empty"]):
		return {"ok": false, "text": "중첩 지속 필드 누락"}
	if not world["session"] is Dictionary or world["session"].get("host_id") != "night_archive":
		return {"ok": false, "text": "잘못된 호스트 참조"}
	return {"ok": true, "snapshot": _normalize(raw), "text": ""}


func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key in value:
			normalized_dictionary[key] = _normalize(value[key])
		return normalized_dictionary
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize(item))
		return normalized_array
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return value


func _seed_pair(path: String) -> bool:
	var store = SaveStore.new()
	var first: Dictionary = store.save(_fixture(), _validator, path)
	var second: Dictionary = store.save(_second_fixture(), _validator, path) if first["ok"] else {"ok": false}
	_check(first["ok"] and second["ok"], "정상 본문/백업 준비: " + path.get_file())
	return first["ok"] and second["ok"]


func _parse_fixture(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(_read_bytes(path).get_string_from_utf8()) != OK:
		return {"ok": false}
	return _validator(parser.data)


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "테스트 파일 열기: " + path.get_file())
	if file == null:
		return false
	var stored: bool = file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	_check(stored and error == OK, "테스트 파일 쓰기: " + path.get_file())
	return stored and error == OK


func _read_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	_check(file != null, "검사용 파일 읽기: " + path.get_file())
	if file == null:
		return PackedByteArray()
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	_check(bytes.size() == length and (error == OK or error == ERR_FILE_EOF), "검사용 전체 바이트 읽기: " + path.get_file())
	return bytes


func _remove_tree(path: String) -> void:
	if _root.is_empty() or not (path == _root or path.begins_with(_root + "/")):
		_check(false, "고유 테스트 폴더 밖 정리 거절")
		return
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "정리할 고유 테스트 폴더 열기")
	if directory == null:
		return
	var list_error: Error = directory.list_dir_begin()
	_check(list_error == OK, "고유 테스트 폴더 항목 읽기")
	if list_error != OK:
		return
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child: String = path.path_join(entry)
		if directory.current_is_dir() and not directory.is_link(entry):
			_remove_tree(child)
		else:
			_check(DirAccess.remove_absolute(child) == OK, "고유 테스트 파일 정리: " + entry)
		entry = directory.get_next()
	directory.list_dir_end()
	_check(DirAccess.remove_absolute(path) == OK, "고유 테스트 폴더 정리")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
