extends RefCounted

const Loader = preload("res://scripts/core/content_loader.gd")
const Parser = preload("res://scripts/core/command_parser.gd")
const FS = preload("res://scripts/core/virtual_fs.gd")
const Store = preload("res://scripts/core/save_store.gd")
const COMMANDS := ["help", "ssh", "exit", "ls", "cd", "pwd", "cat", "scp"]
const WORLD_KEYS := ["remote_files", "local_files", "sessions", "alert_level", "completed", "replies", "discovered"]

var _definition: Dictionary = {}
var _world: Dictionary = {}
var _pending: Dictionary = {}
var _ready := false
var _error := ""
var _store = Store.new()
var _save_path := Store.DEFAULT_PATH

func _init(save_path: String = Store.DEFAULT_PATH) -> void:
	_save_path = save_path
	var loaded := Loader.load_mission()
	_ready = bool(loaded.ok)
	if not _ready:
		_error = "\n".join(loaded.errors)
		return
	_definition = loaded.definition
	reset()

func reset() -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	_world = _initial_world()
	_pending.clear()
	return _result(true, "RESET", "새 야간 작업을 시작했습니다. 저장 파일은 그대로 보존됩니다.", true)

func execute(line: String) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	if not _pending.is_empty():
		return _result(false, "AUTH_REQUIRED", "가상 암호를 입력하거나 입력 취소를 선택하세요.")
	var parsed := Parser.parse(line)
	if not parsed.ok:
		return _result(false, parsed.code, parsed.text)
	var command: String = parsed.command
	var args: Array = parsed.args
	if command.is_empty():
		return _result(false, "EMPTY_INPUT", "")
	if not COMMANDS.has(command):
		return _result(false, "UNKNOWN_COMMAND", command + ": command not found. help로 지원 명령을 확인하세요.")
	match command:
		"help":
			return _help(args)
		"ssh":
			return _ssh(args)
		"exit":
			if not args.is_empty():
				return _usage("exit")
			if _world.sessions.size() <= 1:
				return _result(false, "NO_CONNECTION", "현재 로컬 세션입니다.")
			var previous: Dictionary = _world.sessions.pop_back()
			return _result(true, "DISCONNECTED", previous.host_id + " 연결을 종료했습니다.", true)
		"pwd":
			if not args.is_empty():
				return _usage("pwd")
			return _result(true, "OK", _session().cwd)
		"ls":
			return _ls(args)
		"cd":
			return _cd(args)
		"cat":
			return _cat(args)
		"scp":
			return _scp(args)
	return _result(false, "UNKNOWN_COMMAND", "지원하지 않는 명령입니다.")

func submit_password(password: String) -> Dictionary:
	if _pending.is_empty():
		return _result(false, "NO_AUTH_PENDING", "진행 중인 인증이 없습니다.")
	var target := _pending.duplicate(true)
	_pending.clear()
	var accounts: Dictionary = _definition.hosts[target.host_id].accounts
	if not accounts.has(target.account_id) or password != accounts[target.account_id].password:
		return _denied("AUTH_DENIED", "Permission denied: 가상 계정 또는 암호가 일치하지 않습니다.")
	if _world.sessions.size() >= 16:
		return _result(false, "SESSION_LIMIT", "세션이 너무 많습니다. exit로 이전 연결을 종료하세요.")
	_world.sessions.append({"host_id": target.host_id, "account_id": target.account_id, "cwd": accounts[target.account_id].home})
	return _result(true, "CONNECTED", "ACCESS GRANTED\n" + target.account_id + " 계정으로 연결됐습니다. 자료를 확인하세요.", true, "access_granted")

func cancel_authentication() -> Dictionary:
	_pending.clear()
	return _result(true, "AUTH_CANCELLED", "인증 입력을 취소했습니다.")

func browse(url: String) -> Dictionary:
	if not _ready:
		return {"ok": false, "code": "INVALID_CONTENT", "title": "데이터 오류", "body": _error, "links": [], "can_archive": false, "url": url}
	var normalized := _page_url(url)
	if not normalized.ok:
		return {"ok": false, "code": normalized.code, "title": "연결할 수 없음", "body": normalized.text, "links": [], "can_archive": false, "url": url}
	var value: String = normalized.url
	if not _definition.pages.has(value):
		return {"ok": false, "code": "UNKNOWN_URL", "title": "404 / 보관 페이지 없음", "body": "이 주소에는 게임 내부 페이지가 없습니다. 서버에 남은 링크를 확인하세요.", "links": [], "can_archive": false, "url": value}
	var page: Dictionary = _definition.pages[value]
	return {"ok": true, "code": "OK", "title": page.title, "body": page.body, "links": page.links.duplicate(true), "can_archive": page.has("record_id"), "url": value}

func collect_web(url: String) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	var normalized := _page_url(url)
	if not normalized.ok:
		return _result(false, normalized.code, normalized.text)
	if not _definition.pages.has(normalized.url):
		return _result(false, "UNKNOWN_URL", "보관 페이지가 없습니다.")
	var page: Dictionary = _definition.pages[normalized.url]
	if not page.has("record_id"):
		return _result(false, "NO_RECORD", "이 페이지에는 회수할 자료가 없습니다.")
	var entry := _entry("file", "600", page.body)
	entry.record_id = page.record_id
	entry.source = page.source
	return _archive(entry, page.filename, "/home/player/archive")

func export_snapshot() -> Dictionary:
	return {"save_version": 1, "mission_id": "M01", "world": _world.duplicate(true)}

func restore_snapshot(raw: Variant) -> Dictionary:
	var checked := _validate_snapshot(raw)
	if not checked.ok:
		return _result(false, "INVALID_SNAPSHOT", checked.text)
	_world = checked.snapshot.world.duplicate(true)
	_pending.clear()
	return _result(true, "RESTORED", "야간 작업 상태를 복원했습니다.", true)

func save_game() -> Dictionary:
	return _store.save(export_snapshot(), Callable(self, "_validate_snapshot"), _save_path)

func load_game() -> Dictionary:
	var result: Dictionary = _store.load_save(Callable(self, "_validate_snapshot"), _save_path)
	if result.ok:
		_world = result.snapshot.world.duplicate(true)
		_pending.clear()
	return result

func start_new_save() -> Dictionary:
	return _store.start_new(export_snapshot(), Callable(self, "_validate_snapshot"), _save_path)

func recover_save() -> Dictionary:
	var result: Dictionary = _store.recover_backup(Callable(self, "_validate_snapshot"), _save_path)
	if result.ok:
		_world = result.snapshot.world.duplicate(true)
		_pending.clear()
	return result

func autocomplete(input: String) -> PackedStringArray:
	var choices := PackedStringArray()
	if not _ready or not _pending.is_empty():
		return choices
	if not input.contains(" "):
		for command in COMMANDS:
			if command.begins_with(input):
				choices.append(command)
		return choices
	var last_space := input.rfind(" ")
	var prefix := input.substr(0, last_space + 1)
	var fragment := input.substr(last_space + 1)
	var directory := String(_session().cwd)
	var basename := fragment
	if fragment.contains("/"):
		var resolved := FS.normalize(fragment.get_base_dir(), directory, _home())
		if not resolved.ok:
			return choices
		directory = resolved.path
		basename = fragment.get_file()
	var allowed := FS.access(_files(), directory, _session().account_id, _groups(), "list")
	if not allowed.ok:
		return choices
	for item in FS.children(_files(), directory):
		if String(item.name).begins_with(basename):
			var candidate: String = item.path if fragment.contains("/") else item.name
			if item.kind == "dir":
				candidate += "/"
			choices.append(prefix + candidate)
	return choices

func get_view() -> Dictionary:
	if not _ready:
		return {"ready": false, "error": _error, "prompt": "오류", "password_pending": false, "messages": [], "files": [], "archive": [], "network": []}
	var session := _session()
	var host_name := "midnight-local" if session.host_id == "local" else String(_definition.hosts[session.host_id].domain)
	var prompt := "%s@%s:%s$" % [session.account_id, host_name, _short_path(session.cwd)]
	if not _pending.is_empty():
		prompt = "%s@%s 가상 암호:" % [_pending.account_id, _definition.hosts[_pending.host_id].domain]
	var messages: Array = [_definition.mail.intro.duplicate(true)]
	for id in _world.replies:
		if id == "complete":
			messages.append(_definition.mail.complete.duplicate(true))
	var archive: Array = []
	for path in _world.local_files:
		var entry: Dictionary = _world.local_files[path]
		if String(path).begins_with("/home/player/archive/") and entry.kind == "file":
			archive.append({"name": String(path).get_file(), "path": path, "content": entry.content, "record_id": entry.record_id, "source": entry.source})
	archive.sort_custom(func(a, b): return String(a.name) < String(b.name))
	var listing: Array = []
	if FS.access(_files(), session.cwd, session.account_id, _groups(), "list").ok:
		listing = FS.children(_files(), session.cwd)
	var network: Array = [{"id": "archive", "name": "야간 보관소", "address": "archive.packet.test", "status": "연결됨" if session.host_id == "archive" else "발견됨"}]
	if _world.discovered.has("relay02"):
		network.append({"id": "relay02", "name": "릴레이 02 · 후속 단서", "address": "RELAY / 02", "status": "기록 확보"})
	var hint := "서윤의 메일을 확인하세요. ssh guest@archive.packet.test 로 첫 연결을 시작할 수 있습니다."
	if session.host_id == "archive":
		hint = "공개 폴더의 readme.txt와 shift-note.txt에 다른 접근 경로가 남아 있습니다."
	if session.account_id == "maint":
		hint = "scp /vault/handoff.log 로 사본을 ~/archive 에 보관하세요. 같은 이름의 미끼 기록을 구분하세요."
	if _world.completed:
		hint = "첫 의뢰 완료. 메일함에 도착한 서윤의 답장을 확인하세요."
	return {"ready": true, "error": "", "prompt": prompt, "host": host_name, "user": session.account_id, "cwd": session.cwd, "alert_level": _world.alert_level, "alert_max": _definition.alert_max, "completed": _world.completed, "password_pending": not _pending.is_empty(), "mission_title": _definition.title, "mission_goal": "인계 기록 사본을 회수하고 원본을 보존하세요.", "hint": hint, "messages": messages, "archive": archive, "files": listing, "network": network, "browser_home": _definition.initial_web_url}.duplicate(true)

func _help(args: Array) -> Dictionary:
	if args.size() > 1:
		return _usage("help [명령]")
	var descriptions := {
		"help": "help [명령] — 이 게임이 지원하는 명령을 확인합니다.",
		"ssh": "ssh <계정>@<가상 host> — 가상 암호를 입력해 연결합니다. 예: ssh guest@archive.packet.test",
		"exit": "exit — 현재 연결을 종료하고 이전 세션으로 돌아갑니다.",
		"ls": "ls [-l] [경로] — 가상 폴더의 목록/소유자/권한을 봅니다.",
		"cd": "cd [경로] — 가상 작업 폴더를 옮깁니다. .. 와 ~ 를 지원합니다.",
		"pwd": "pwd — 현재 가상 경로를 표시합니다.",
		"cat": "cat <경로> — 읽기 권한이 있는 텍스트를 봅니다.",
		"scp": "scp <원격 파일> [로컬 경로] — 사본을 로컬 ~/archive 에 보관합니다. 같은 이름은 별도 이름으로 보존합니다. 실제 scp와 다른 게임용 부분 구문입니다."
	}
	if not args.is_empty():
		if not descriptions.has(args[0]):
			return _result(false, "UNKNOWN_COMMAND", "도움말에 없는 명령입니다.")
		return _result(true, "OK", descriptions[args[0]])
	return _result(true, "OK", "지원 명령 · 대소문자 구별\n" + "\n".join(descriptions.values()) + "\n\n모든 접속과 파일은 게임 내부 데이터입니다. 실제 서버·파일에는 접근하지 않습니다.")

func _ssh(args: Array) -> Dictionary:
	if args.size() != 1 or String(args[0]).count("@") != 1 or String(args[0]).begins_with("-"):
		return _usage("ssh <계정>@<가상 host>")
	var account := String(args[0]).get_slice("@", 0)
	var address := String(args[0]).get_slice("@", 1)
	if account.is_empty():
		return _usage("ssh <계정>@<가상 host>")
	for id in _definition.hosts:
		var host: Dictionary = _definition.hosts[id]
		if address == host.domain or address == host.address:
			_pending = {"host_id": id, "account_id": account}
			return _result(true, "AUTH_REQUIRED", "가상 암호를 입력하세요. 입력한 암호는 이력에 기록하지 않습니다.")
	return _result(false, "HOST_NOT_FOUND", "이 사건의 가상 네트워크에서 찾을 수 없는 host입니다.")

func _ls(args: Array) -> Dictionary:
	var detailed := false
	var path := "."
	var positional := 0
	for argument in args:
		if argument == "-l":
			detailed = true
		elif String(argument).begins_with("-"):
			return _usage("ls [-l] [경로]")
		else:
			positional += 1
			path = argument
	if positional > 1:
		return _usage("ls [-l] [경로]")
	var resolved := FS.normalize(path, _session().cwd, _home())
	if not resolved.ok:
		return _result(false, resolved.code, resolved.text)
	var files := _files()
	var checked := FS.access(files, resolved.path, _session().account_id, _groups(), "stat")
	if not checked.ok:
		return _filesystem_failure(checked)
	if checked.entry.kind == "file":
		return _result(true, "OK", String(resolved.path).get_file())
	checked = FS.access(files, resolved.path, _session().account_id, _groups(), "list")
	if not checked.ok:
		return _filesystem_failure(checked)
	var lines: Array[String] = []
	for item in FS.children(files, resolved.path):
		var label := String(item.name) + ("/" if item.kind == "dir" else "")
		if detailed:
			var entry: Dictionary = files[item.path]
			label = "%s  %s  %s  %s" % [entry.mode, entry.owner, entry.group, label]
		lines.append(label)
	return _result(true, "OK", "\n".join(lines) if not lines.is_empty() else "(empty)")

func _cd(args: Array) -> Dictionary:
	if args.size() > 1 or (args.size() == 1 and String(args[0]).begins_with("-")):
		return _usage("cd [경로]")
	var resolved := FS.normalize(args[0] if not args.is_empty() else "~", _session().cwd, _home())
	if not resolved.ok:
		return _result(false, resolved.code, resolved.text)
	var checked := FS.access(_files(), resolved.path, _session().account_id, _groups(), "enter")
	if not checked.ok:
		return _filesystem_failure(checked)
	if checked.entry.kind != "dir":
		return _result(false, "NOT_DIRECTORY", resolved.path + ": Not a directory")
	_session().cwd = resolved.path
	return _result(true, "OK", "", true)

func _cat(args: Array) -> Dictionary:
	if args.size() != 1 or String(args[0]).begins_with("-"):
		return _usage("cat <경로>")
	var resolved := FS.normalize(args[0], _session().cwd, _home())
	if not resolved.ok:
		return _result(false, resolved.code, resolved.text)
	var checked := FS.access(_files(), resolved.path, _session().account_id, _groups(), "read")
	if not checked.ok:
		return _filesystem_failure(checked)
	if checked.entry.kind != "file":
		return _result(false, "IS_DIRECTORY", resolved.path + ": Is a directory")
	return _result(true, "OK", checked.entry.content)

func _scp(args: Array) -> Dictionary:
	if args.is_empty() or args.size() > 2 or String(args[0]).begins_with("-"):
		return _usage("scp <원격 파일> [로컬 경로]")
	if _session().host_id == "local":
		return _result(false, "NO_CONNECTION", "먼저 가상 서버에 연결하세요.")
	var resolved := FS.normalize(args[0], _session().cwd, _home())
	if not resolved.ok:
		return _result(false, resolved.code, resolved.text)
	var checked := FS.access(_files(), resolved.path, _session().account_id, _groups(), "read")
	if not checked.ok:
		return _filesystem_failure(checked)
	if checked.entry.kind != "file":
		return _result(false, "IS_DIRECTORY", "회수할 파일 하나를 지정하세요.")
	var destination := "/home/player/archive"
	if args.size() == 2:
		var normalized := FS.normalize(args[1], "/home/player", "/home/player")
		if not normalized.ok:
			return _result(false, normalized.code, normalized.text)
		destination = normalized.path
	return _archive(checked.entry, String(resolved.path).get_file(), destination)

func _archive(source: Dictionary, name: String, destination: String) -> Dictionary:
	var local: Dictionary = _world.local_files
	var path := destination
	if local.has(destination) and local[destination].kind == "dir":
		path = destination.path_join(name)
	if not path.begins_with("/home/player/"):
		return _result(false, "PERMISSION_DENIED", "로컬 가상 홈의 폴더만 지정할 수 있습니다.")
	var allowed := FS.access(local, path.get_base_dir(), "player", ["player"], "write_dir")
	if not allowed.ok:
		return _result(false, allowed.code, allowed.text)
	var original_path := path
	var counter := 1
	while local.has(path):
		var extension := original_path.get_extension()
		var stem := original_path.get_basename()
		path = "%s(%d)%s" % [stem, counter, "." + extension if not extension.is_empty() else ""]
		counter += 1
	var final_path := FS.normalize(path)
	if not final_path.ok or final_path.path != path:
		return _result(false, "INVALID_PATH", "The final archive path is invalid or too long.")
	if local.size() >= _archive_limit():
		return _result(false, "ARCHIVE_LIMIT", "보관 파일 수 제한에 도달했습니다.")
	var copy := _entry("file", "600", String(source.get("content", "")))
	copy.record_id = String(source.get("record_id", ""))
	copy.source = String(source.get("source", ""))
	local[path] = copy
	var finished := _evaluate_completion()
	var text := "보관 완료: " + path
	if path != original_path:
		text += "\n같은 이름의 파일은 덮어쓰지 않고 별도 보존했습니다."
	if finished:
		text += "\n\nM01 COMPLETE / 인계 기록 확인\n원본 보존 · 사본 출처 확인\n서윤에게서 새 답장이 도착했습니다."
	elif not _world.completed:
		if _target_record(copy) and not path.begins_with("/home/player/archive/"):
			text += "\n목표 사본은 맞지만 ~/archive 밖입니다. 회수 보관소 ~/archive 로 복사하세요."
		elif _target_record(copy):
			text += "\n사본은 맞지만 원본 보존 조건을 확인해야 합니다."
		else:
			text += "\n이 사본은 아직 목표 인계 기록과 일치하지 않습니다."
	return _result(true, "ARCHIVED", text, true, "mission_completed" if finished else "record_archived")


func _archive_limit() -> int:
	return 128

func _evaluate_completion() -> bool:
	if _world.completed or not _sources_preserved():
		return false
	for path in _world.local_files:
		if String(path).begins_with("/home/player/archive/") and _target_record(_world.local_files[path]):
			_world.completed = true
			_world.replies = ["complete"]
			_world.discovered = ["archive", "relay02"]
			return true
	return false

func _target_record(entry: Dictionary) -> bool:
	var id: String = _definition.goal.record_id
	var record: Dictionary = _definition.records[id]
	return entry.get("kind", "") == "file" and entry.get("record_id", "") == id and entry.get("content", "") == record.content and record.allowed_sources.has(entry.get("source", ""))

func _sources_preserved() -> bool:
	return _world.remote_files == _initial_remote_files()

func _validate_snapshot(raw: Variant) -> Dictionary:
	if not _ready or not raw is Dictionary or raw.size() != 3 or not raw.has_all(["save_version", "mission_id", "world"]):
		return _invalid("저장 형식이 올바르지 않습니다.")
	if not _integer(raw.save_version, 1, 1) or raw.mission_id != "M01" or not raw.world is Dictionary:
		return _invalid("저장 버전 또는 사건이 일치하지 않습니다.")
	var world: Dictionary = raw.world.duplicate(true)
	if world.size() != WORLD_KEYS.size() or not world.has_all(WORLD_KEYS):
		return _invalid("지속 상태 필드가 누락됐거나 지원하지 않는 필드가 있습니다.")
	if not world.remote_files is Dictionary or world.remote_files != _initial_remote_files():
		return _invalid("원본 서버 파일 또는 출처가 변경됐습니다.")
	if not world.local_files is Dictionary or world.local_files.size() > 128:
		return _invalid("보관소 구조가 올바르지 않습니다.")
	var base: Dictionary = _initial_local_files()
	for path in base:
		if not world.local_files.has(path) or world.local_files[path] != base[path]:
			return _invalid("로컬 기본 폴더가 변경됐습니다.")
	for path in world.local_files:
		if not path is String or not world.local_files[path] is Dictionary:
			return _invalid("보관 파일 형식이 올바르지 않습니다.")
		if base.has(path):
			continue
		var resolved := FS.normalize(path)
		var entry: Dictionary = world.local_files[path]
		if not resolved.ok or resolved.path != path or not String(path).begins_with("/home/player/") or not world.local_files.has(String(path).get_base_dir()) or world.local_files[String(path).get_base_dir()].get("kind", "") != "dir":
			return _invalid("보관 경로가 올바르지 않습니다.")
		if entry.size() != 7 or not entry.has_all(["kind", "owner", "group", "mode", "content", "record_id", "source"]) or entry.kind != "file" or entry.owner != "player" or entry.group != "player" or entry.mode != "600":
			return _invalid("보관 파일 메타데이터가 올바르지 않습니다.")
		if not entry.content is String or not entry.record_id is String or not entry.source is String or not _known_source(entry):
			return _invalid("보관 자료의 원본 데이터 또는 출처가 일치하지 않습니다.")
	if not world.sessions is Array or world.sessions.is_empty() or world.sessions.size() > 16:
		return _invalid("세션 스택이 올바르지 않습니다.")
	for index in range(world.sessions.size()):
		var session: Variant = world.sessions[index]
		if not session is Dictionary or session.size() != 3 or not session.has_all(["host_id", "account_id", "cwd"]):
			return _invalid("세션 필드가 올바르지 않습니다.")
		if not session.host_id is String or not session.account_id is String or not session.cwd is String:
			return _invalid("세션 자료형이 올바르지 않습니다.")
		var files: Dictionary
		var groups: Array
		if index == 0:
			if session.host_id != "local" or session.account_id != "player":
				return _invalid("첫 세션은 로컬이어야 합니다.")
			files = world.local_files
			groups = ["player"]
		else:
			if not _definition.hosts.has(session.host_id) or not _definition.hosts[session.host_id].accounts.has(session.account_id):
				return _invalid("존재하지 않는 호스트/계정 세션입니다.")
			files = world.remote_files[session.host_id]
			groups = _definition.hosts[session.host_id].accounts[session.account_id].groups
		var normalized := FS.normalize(session.cwd)
		if not normalized.ok or normalized.path != session.cwd or not files.has(session.cwd) or files[session.cwd].kind != "dir" or not FS.access(files, session.cwd, session.account_id, groups, "enter").ok:
			return _invalid("세션 작업 폴더가 올바르지 않습니다.")
	if not _integer(world.alert_level, 0, _definition.alert_max) or not world.completed is bool or not world.replies is Array or not world.discovered is Array:
		return _invalid("경보/진행 상태 자료형이 올바르지 않습니다.")
	world.alert_level = int(world.alert_level)
	var has_target := false
	for path in world.local_files:
		if String(path).begins_with("/home/player/archive/") and _target_record(world.local_files[path]):
			has_target = true
	if world.completed != has_target or world.replies != (["complete"] if has_target else []) or world.discovered != (["archive", "relay02"] if has_target else ["archive"]):
		return _invalid("완료 표시·회수 자료·답장/다음 단서가 서로 일치하지 않습니다.")
	return {"ok": true, "snapshot": {"save_version": 1, "mission_id": "M01", "world": world}, "text": "검증 완료"}

func _known_source(entry: Dictionary) -> bool:
	for host_id in _definition.hosts:
		for path in _definition.hosts[host_id].files:
			var original: Dictionary = _definition.hosts[host_id].files[path]
			if entry.source == String(host_id) + ":" + String(path) and entry.record_id == original.record_id and entry.content == original.content and original.kind == "file":
				return true
	for page in _definition.pages.values():
		if page.has("record_id") and entry.source == page.source and entry.record_id == page.record_id and entry.content == page.body:
			return true
	return false

func _initial_world() -> Dictionary:
	return {"remote_files": _initial_remote_files(), "local_files": _initial_local_files(), "sessions": [{"host_id": "local", "account_id": "player", "cwd": "/home/player"}], "alert_level": 0, "completed": false, "replies": [], "discovered": ["archive"]}

func _initial_remote_files() -> Dictionary:
	var remote: Dictionary = {}
	for id in _definition.hosts:
		var files: Dictionary = _definition.hosts[id].files.duplicate(true)
		for path in files:
			files[path].source = String(id) + ":" + String(path)
		remote[id] = files
	return remote

func _initial_local_files() -> Dictionary:
	return {"/": _entry("dir", "755"), "/home": _entry("dir", "755"), "/home/player": _entry("dir", "700"), "/home/player/archive": _entry("dir", "700")}

func _entry(kind: String, mode: String, content: String = "") -> Dictionary:
	return {"kind": kind, "owner": "player", "group": "player", "mode": mode, "content": content, "record_id": "", "source": ""}

func _session() -> Dictionary:
	return _world.sessions[-1]

func _files() -> Dictionary:
	return _world.local_files if _session().host_id == "local" else _world.remote_files[_session().host_id]

func _groups() -> Array:
	return ["player"] if _session().host_id == "local" else _definition.hosts[_session().host_id].accounts[_session().account_id].groups

func _home() -> String:
	return "/home/player" if _session().host_id == "local" else _definition.hosts[_session().host_id].accounts[_session().account_id].home

func _short_path(path: String) -> String:
	return "~" + path.substr(12) if path == "/home/player" or path.begins_with("/home/player/") else path

func _filesystem_failure(result: Dictionary) -> Dictionary:
	if result.code == "PERMISSION_DENIED" and _session().host_id != "local":
		return _denied(result.code, result.text)
	return _result(false, result.code, result.text)

func _denied(code: String, text: String) -> Dictionary:
	_world.alert_level = mini(int(_definition.alert_max), int(_world.alert_level) + 1)
	if _world.alert_level >= 2:
		text += "\n경보 2 · 메모의 단서나 웹 보관 경로를 확인하세요. 이 사건은 연결을 차단하지 않습니다."
	return _result(false, code, text, true, "alert_changed")

func _page_url(url: String) -> Dictionary:
	var value := url.strip_edges()
	if value.length() > 2048 or not Loader._internal_url(value) or value.contains("\n") or value.contains("\r"):
		return {"ok": false, "code": "EXTERNAL_URL", "text": "게임 내부의 http(s) .test 주소만 열 수 있습니다."}
	while value.ends_with("/"):
		value = value.substr(0, value.length() - 1)
	return {"ok": true, "url": value}

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

func _invalid(text: String) -> Dictionary:
	return {"ok": false, "text": text, "snapshot": {}}

func _usage(usage: String) -> Dictionary:
	return _result(false, "INVALID_ARGUMENTS", "Usage: " + usage)

func _result(ok: bool, code: String, text: String, changed: bool = false, event: String = "") -> Dictionary:
	return {"ok": ok, "code": code, "text": text, "changed": changed, "needs_password": not _pending.is_empty(), "event": event}
