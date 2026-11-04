extends RefCounted

const FS = preload("res://scripts/core/virtual_fs.gd")
const DEFAULT_PATH := "res://data/missions/M01.json"
const GOAL_KINDS := ["record_acquired", "sources_preserved"]

static func load_mission(path: String = DEFAULT_PATH) -> Dictionary:
	if not path.begins_with("res://data/missions/") or path.contains("..") or not path.ends_with(".json"):
		return {"ok": false, "definition": {}, "errors": ["허용된 미션 리소스 경로가 아닙니다."]}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "definition": {}, "errors": ["미션 데이터를 열 수 없습니다: " + path]}
	if file.get_length() > 2097152:
		return {"ok": false, "definition": {}, "errors": ["미션 크기 제한을 초과했습니다."]}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "definition": {}, "errors": ["미션 JSON 오류: " + parser.get_error_message()]}
	return validate(parser.data)

static func validate(raw: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return {"ok": false, "definition": {}, "errors": ["미션은 객체여야 합니다."]}
	var data: Dictionary = raw.duplicate(true)
	for key in ["schema_version", "mission_id", "title", "alert_max", "goal", "goals", "records", "hosts", "pages", "mail", "initial_web_url"]:
		if not data.has(key):
			errors.append("누락된 필드: " + key)
	if not errors.is_empty():
		return {"ok": false, "definition": {}, "errors": errors}
	if not _integer(data.schema_version, 1, 1) or not _integer(data.alert_max, 0, 3):
		errors.append("schema_version/alert_max 값이 올바르지 않습니다.")
	else:
		data.schema_version = int(data.schema_version)
		data.alert_max = int(data.alert_max)
	if not data.mission_id is String or data.mission_id != "M01" or not data.title is String:
		errors.append("이 묶음은 M01만 지원합니다.")
	if not data.goal is Dictionary or not data.goals is Array or not data.records is Dictionary or not data.hosts is Dictionary or not data.pages is Dictionary or not data.mail is Dictionary:
		return {"ok": false, "definition": {}, "errors": errors + ["미션 필드 자료형 오류"]}
	if data.goals.is_empty():
		errors.append("goals가 비어 있습니다.")
	var seen: Array[String] = []
	for goal in data.goals:
		if not goal is Dictionary or not GOAL_KINDS.has(goal.get("kind", "")):
			errors.append("미등록 goal kind")
			continue
		if seen.has(goal.kind):
			errors.append("중복 goal kind")
		seen.append(goal.kind)
		if goal.kind == "record_acquired" and goal.get("record_id", "") != data.goal.get("record_id", ""):
			errors.append("goal의 자료 ID가 일치하지 않습니다.")
	for kind in GOAL_KINDS:
		if not seen.has(kind):
			errors.append("필수 목표 누락: " + kind)
	var target_id: String = String(data.goal.get("record_id", ""))
	if target_id.is_empty() or not data.records.has(target_id) or data.goal.get("destination", "") != "/home/player/archive":
		errors.append("목표 기록 또는 보관소 참조 오류")
	for record_id in data.records:
		var record: Variant = data.records[record_id]
		if not record_id is String or not record is Dictionary or not record.get("content") is String or not record.get("allowed_sources") is Array:
			errors.append("기록 정의 오류")
		elif record.allowed_sources.is_empty():
			errors.append("기록의 허용 출처가 비어 있습니다.")
	if not errors.is_empty():
		return {"ok": false, "definition": {}, "errors": errors}
	for host_id in data.hosts:
		var host: Variant = data.hosts[host_id]
		if not host is Dictionary or not host.get("files") is Dictionary or not host.get("accounts") is Dictionary:
			errors.append("호스트 정의 오류")
			continue
		if not host.get("domain", "") is String or not String(host.get("domain", "")).ends_with(".test") or not host.get("address", "") is String or not host.get("name", "") is String:
			errors.append("가상 호스트 이름 오류")
		if host.accounts.is_empty() or not host.files.has("/"):
			errors.append("계정 또는 파일 루트 누락")
		for account_id in host.accounts:
			var account: Variant = host.accounts[account_id]
			if not account is Dictionary or not account.get("password") is String or not account.get("groups") is Array or not account.get("home") is String:
				errors.append("계정 정의 오류")
				continue
			if not host.files.has(account.home) or not host.files[account.home] is Dictionary or host.files[account.home].get("kind", "") != "dir":
				errors.append("계정 홈 참조 오류")
		for path in host.files:
			var entry: Variant = host.files[path]
			var normalized := FS.normalize(String(path))
			if not path is String or not normalized.ok or normalized.path != path or not String(path).begins_with("/"):
				errors.append("정규화되지 않은 가상 경로")
			if not entry is Dictionary:
				errors.append("파일 정의 오류")
				continue
			if not ["file", "dir"].has(entry.get("kind", "")) or not host.accounts.has(entry.get("owner", "")) or not entry.get("content") is String or not entry.get("record_id") is String or not entry.get("group") is String:
				errors.append("파일 필드/소유자 참조 오류")
			var mode := String(entry.get("mode", ""))
			if mode.length() != 3 or not mode[0] in "01234567" or not mode[1] in "01234567" or not mode[2] in "01234567":
				errors.append("파일 권한 표기 오류")
			if path != "/" and (not host.files.has(String(path).get_base_dir()) or not host.files[String(path).get_base_dir()] is Dictionary or host.files[String(path).get_base_dir()].get("kind", "") != "dir"):
				errors.append("파일 부모 경로 누락")
	if not errors.is_empty():
		return {"ok": false, "definition": {}, "errors": errors}
	for url in data.pages:
		var page: Variant = data.pages[url]
		if not url is String or not _internal_url(url) or not page is Dictionary:
			errors.append("가상 웹페이지 정의 오류")
			continue
		if not page.get("title") is String or not page.get("body") is String or not page.get("links") is Array:
			errors.append("웹페이지 필드 오류")
			continue
		for link in page.links:
			if not link is Dictionary or not link.get("label") is String or not data.pages.has(link.get("url", "")):
				errors.append("웹 링크 참조 오류")
		if page.has("record_id"):
			if not data.records.has(page.record_id) or not page.get("source") is String or not page.get("filename") is String or (not FS.normalize("/" + String(page.get("filename", ""))).get("ok", false) or String(page.get("filename", "")) in ["", ".", ".."] or String(page.get("filename", "")).contains("/")):
				errors.append("웹 보관 기록 참조 오류")
			elif not data.records[page.record_id].allowed_sources.has(page.source) or page.body != data.records[page.record_id].content:
				errors.append("웹 보관 기록 무결성 오류")
	if not data.pages.has(data.initial_web_url):
		errors.append("초기 웹페이지가 없습니다.")
	for key in ["intro", "complete"]:
		if not data.mail.has(key) or not data.mail[key] is Dictionary:
			errors.append("메일 정의 누락")
			continue
		for field in ["id", "sender", "subject", "body"]:
			if not data.mail[key].get(field) is String:
				errors.append("메일 필드 오류")
	if data.mail.has("intro") and data.mail.has("complete") and data.mail.intro is Dictionary and data.mail.complete is Dictionary and data.mail.intro.get("id", "") == data.mail.complete.get("id", ""):
		errors.append("중복 메일 ID")
	return {"ok": errors.is_empty(), "definition": data if errors.is_empty() else {}, "errors": errors}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _internal_url(url: String) -> bool:
	if not (url.begins_with("https://") or url.begins_with("http://")) or url.contains("@") or url.contains("\\"):
		return false
	var host := url.get_slice("://", 1).get_slice("/", 0)
	return host.ends_with(".test") and not host.contains(":")
