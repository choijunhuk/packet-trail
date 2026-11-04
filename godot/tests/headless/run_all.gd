extends SceneTree

const Game = preload("res://scripts/core/game.gd")
const ContentLoader = preload("res://scripts/core/content_loader.gd")
const SaveTests = preload("res://tests/headless/test_save_store.gd")
const MIRROR = "https://mirror.packet.test/cache/47"
const TARGET_TEXT = "[N47 / HANDOFF]\n야간 인계 기록 · 00:47\n이관 지시: relay-02 → archive-17\n승인 표식: SY / 교차 확인 대기\n원본은 보존하고 사본만 전달할 것.\n후속 단서: 릴레이 02의 누락된 송신 기록.\n"

var checks: int = 0
var failures: Array = []

func _initialize() -> void:
	var initial: Variant = Game.new()
	_check(initial.get_view().get("ready", false), "M01 initializes ready", initial.get_view().get("error", ""))
	if initial.get_view().get("ready", false):
		_test_initial_and_parser(initial)
		_test_terminal_route()
		_test_web_route()
		_test_paths_and_sessions()
		_test_snapshot_validation()
	_test_content_validation()
	var saved: Dictionary = SaveTests.new().run()
	checks += int(saved.get("checks", 0))
	if not saved.has("checks") or not saved.has("failures"):
		failures.append({"case": "save suite returns checks and failures"})
	else:
		failures.append_array(saved["failures"])
	print(JSON.stringify({"suite": "first_playable", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not condition:
		failures.append({"case": label, "detail": detail})

func _login(game: Variant, account: String, password: String) -> Dictionary:
	var prompt: Dictionary = game.execute("ssh " + account + "@archive.packet.test")
	if not prompt.get("needs_password", false):
		return prompt
	return game.submit_password(password)

func _complete_reply_count(game: Variant) -> int:
	var count: int = 0
	for message in game.get_view().get("messages", []):
		if message.get("id", "") == "complete":
			count += 1
	return count

func _test_initial_and_parser(game: Variant) -> void:
	var view: Dictionary = game.get_view()
	_check(view.get("mission_title", "") == "첫 번째 야간 의뢰" and not view.get("completed", true)
		and view.get("alert_level", -1) == 0 and _complete_reply_count(game) == 0,
		"new mission is incomplete without a completion reply")
	var before: Dictionary = game.export_snapshot()
	game.execute("ls")
	game.execute("pwd")
	game.execute("help")
	game.autocomplete("c")
	game.get_view()
	_check(game.export_snapshot() == before, "local observation and autocomplete do not change the world")
	var accepted: Array = []
	for command in ["", "LS", "cat \"file name\"", "cat file name", "ls -la", "ls; pwd",
			"ls | cat", "ls && pwd", "cat $(pwd)", "cat `pwd`", "ls > result"]:
		var result: Dictionary = game.execute(command)
		if result.get("ok", true) or game.export_snapshot() != before:
			accepted.append(command)
	_check(accepted.is_empty(), "unsupported syntax is rejected atomically without raising alert", accepted)
	var auth_before: Dictionary = game.export_snapshot()
	game.execute("ssh guset@archive.packet.test")
	var cancelled: Dictionary = game.cancel_authentication()
	_check(cancelled.get("ok", false) and not game.get_view().get("password_pending", true) and game.export_snapshot() == auth_before,
		"authentication can be cancelled without alert or persistent changes")
	var typo: Dictionary = game.execute("연결오타")
	_check(not typo.get("ok", true) and game.get_view().get("alert_level", -1) == 0,
		"local unknown and IME text do not raise action alert")

func _test_terminal_route() -> void:
	var game: Variant = Game.new()
	var prompt: Dictionary = game.execute("ssh guest@archive.packet.test")
	_check(prompt.get("needs_password", false) and game.get_view().get("password_pending", false),
		"SSH asks for a password before creating an authenticated session")
	var login: Dictionary = game.submit_password("guest")
	_check(login.get("ok", false) and game.get_view().get("user", "") == "guest",
		"guest password opens the limited session")
	var denied: Dictionary = game.execute("cd /vault")
	_check(denied.get("code", "") == "PERMISSION_DENIED" and game.get_view().get("alert_level", -1) == 1
		and game.get_view().get("cwd", "") == "/public", "guest cannot enter protected vault")
	var note: Dictionary = game.execute("cat /public/shift-note.txt")
	var text: String = note.get("text", "")
	_check(note.get("ok", false) and text.contains("maint") and text.contains("lumen-47")
		and text.contains("/vault/handoff.log") and text.contains(MIRROR)
		and game.get_view().get("alert_level", -1) == 1,
		"reading the shift note reveals two routes without adding alert")
	var decoy: Dictionary = game.execute("scp /public/handoff.log ~/archive")
	_check(decoy.get("ok", false) and not game.get_view().get("completed", true)
		and game.get_view().get("archive", []).size() == 1 and _complete_reply_count(game) == 0,
		"same-basename old form is retained but cannot complete the mission")
	login = _login(game, "maint", "lumen-47")
	_check(login.get("ok", false) and game.get_view().get("user", "") == "maint",
		"maintenance clue grants its own authenticated session")
	var elsewhere: Dictionary = game.execute("scp /vault/handoff.log ~")
	_check(elsewhere.get("ok", false) and not game.get_view().get("completed", true) and elsewhere.get("text", "").contains("~/archive")
		and not elsewhere.get("text", "").contains("일치하지"), "authentic record outside archive is described accurately")
	var originals: Dictionary = game.export_snapshot().get("world", {}).get("remote_files", {}).duplicate(true)
	var collected: Dictionary = game.execute("scp /vault/handoff.log ~/archive")
	var archive: Array = game.get_view().get("archive", [])
	var names: Array = []
	var target_found: bool = false
	var decoy_found: bool = false
	for item in archive:
		names.append(item.get("name", ""))
		if item.get("record_id", "") == "handoff-47":
			target_found = item.get("content", "") == TARGET_TEXT and item.get("source", "") == "archive:/vault/handoff.log"
		if item.get("record_id", "") == "old-form":
			decoy_found = item.get("content", "").contains("예전 점검 양식")
	_check(collected.get("ok", false) and archive.size() == 2 and names.size() == 2
		and names[0] != names[1] and target_found and decoy_found,
		"real record is renamed on collision while preserving both payloads")
	var snapshot: Dictionary = game.export_snapshot()
	_check(snapshot.get("world", {}).get("remote_files", {}) == originals,
		"record collection preserves every remote original")
	_check(game.get_view().get("completed", false) and _complete_reply_count(game) == 1
		and snapshot.get("world", {}).get("discovered", []).has("relay02"),
		"authentic collection completes once and reveals the next node")
	game.execute("ls")
	game.execute("scp /vault/handoff.log ~/archive")
	game.get_view()
	_check(game.get_view().get("completed", false) and _complete_reply_count(game) == 1,
		"re-observation and repeated collection do not duplicate the reply")

func _test_web_route() -> void:
	var game: Variant = Game.new()
	var page: Dictionary = game.browse(MIRROR)
	_check(page.get("ok", false) and page.get("can_archive", false)
		and page.get("body", "") == TARGET_TEXT and not game.get_view().get("completed", true),
		"browsing the valid mirror previews the real record without collecting it")
	var collected: Dictionary = game.collect_web(MIRROR)
	var archive: Array = game.get_view().get("archive", [])
	_check(collected.get("ok", false) and game.get_view().get("completed", false)
		and game.get_view().get("alert_level", -1) == 0 and archive.size() == 1
		and archive[0].get("source", "") == "mirror:cache-47" and _complete_reply_count(game) == 1,
		"web alternative completes directly without guest access or forced denial")
	var before: Dictionary = game.export_snapshot()
	var bad_urls: Array = []
	for url in ["https://example.com", "file:///etc/passwd", "https://mirror.packet.test/missing",
			"https://mirror.packet.test.evil/cache/47", "http://127.0.0.1"]:
		var preview: Dictionary = game.browse(url)
		var result: Dictionary = game.collect_web(url)
		if preview.get("ok", true) or result.get("ok", true) or game.export_snapshot() != before:
			bad_urls.append(url)
	_check(bad_urls.is_empty(), "unknown or external URLs are rejected without world changes", bad_urls)
	game.collect_web(MIRROR)
	_check(_complete_reply_count(game) == 1, "mirror recollection does not duplicate the reply")
	var view: Dictionary = game.get_view()
	view["completed"] = false
	view["archive"].clear()
	view["messages"].clear()
	_check(game.get_view().get("completed", false) and game.get_view().get("archive", []).size() == 2
		and _complete_reply_count(game) == 1, "view mutation cannot change authoritative state")
	game.reset()
	_check(not game.get_view().get("completed", true) and game.get_view().get("archive", []).is_empty()
		and game.get_view().get("alert_level", -1) == 0 and _complete_reply_count(game) == 0,
		"reset restores a fresh mission in memory")

func _test_paths_and_sessions() -> void:
	var game: Variant = Game.new()
	game.execute("cd ~/archive")
	_login(game, "guest", "guest")
	var normalized: Dictionary = game.execute("cd /../../../../public")
	_check(normalized.get("ok", false) and game.get_view().get("cwd", "") == "/public",
		"parent traversal is normalized inside the virtual root")
	var url_path: Dictionary = game.execute("cat https://mirror.packet.test/cache/47")
	_check(not url_path.get("ok", true), "virtual file command cannot interpret a URL as a path")
	_login(game, "maint", "lumen-47")
	game.execute("cd /vault")
	game.execute("exit")
	var guest: Dictionary = game.get_view()
	game.execute("exit")
	var local: Dictionary = game.get_view()
	_check(guest.get("user", "") == "guest" and guest.get("cwd", "") == "/public"
		and local.get("user", "") == "player" and local.get("cwd", "") == "/home/player/archive",
		"exiting nested sessions restores each previous working directory")
	var denied_codes: Array = []
	for attempt in range(3):
		denied_codes.append(_login(game, "guest", "incorrect").get("code", ""))
	_check(denied_codes == ["AUTH_DENIED", "AUTH_DENIED", "AUTH_DENIED"]
		and game.get_view().get("alert_level", -1) == 2,
		"invalid authentication is denied and action alert is capped")
	var mirror: Dictionary = game.collect_web(MIRROR)
	_check(mirror.get("ok", false) and game.get_view().get("completed", false),
		"alert threshold preserves a valid alternative route")

func _reject_snapshot(game: Variant, raw: Variant, label: String) -> void:
	var before: Dictionary = game.export_snapshot()
	var result: Dictionary = game.restore_snapshot(raw)
	_check(not result.get("ok", true) and game.export_snapshot() == before, label)

func _test_snapshot_validation() -> void:
	var game: Variant = Game.new()
	game.collect_web(MIRROR)
	var valid: Dictionary = game.export_snapshot()
	var exposed: Dictionary = game.export_snapshot()
	exposed["world"]["local_files"]["/home/player/archive/handoff.log"]["content"] = "mutated export"
	exposed["world"]["replies"].clear()
	_check(game.export_snapshot() == valid, "exported nested snapshot is a deep copy")
	var restored: Variant = Game.new()
	var result: Dictionary = restored.restore_snapshot(JSON.parse_string(JSON.stringify(valid)))
	_check(result.get("ok", false) and restored.export_snapshot() == valid
		and restored.get_view().get("completed", false) and _complete_reply_count(restored) == 1,
		"JSON snapshot round-trip preserves the completed outcome")
	restored.execute("ls")
	restored.collect_web(MIRROR)
	_check(_complete_reply_count(restored) == 1, "restored completion cannot emit another reply")
	var forged: Dictionary = valid.duplicate(true)
	forged["world"]["local_files"]["/home/player/archive/handoff.log"]["content"] = "same ID, forged payload"
	_reject_snapshot(game, forged, "same record ID cannot authenticate a forged payload")
	forged = valid.duplicate(true)
	forged["world"]["local_files"]["/home/player/archive/handoff.log"]["source"] = "archive:/public/handoff.log"
	_reject_snapshot(game, forged, "record source forgery is rejected atomically")
	forged = valid.duplicate(true)
	forged["world"]["remote_files"]["archive"]["/vault/handoff.log"]["content"] = "changed original"
	_reject_snapshot(game, forged, "changed protected original is rejected atomically")
	forged = valid.duplicate(true)
	forged["world"]["sessions"].append({"host_id": "unknown", "account_id": "root", "cwd": "/"})
	_reject_snapshot(game, forged, "unknown session host or account cannot be restored")
	var accepted: Array = []
	for mutation in ["boolean_version", "fractional_version", "boolean_alert", "fractional_alert", "integer_completed"]:
		forged = valid.duplicate(true)
		match mutation:
			"boolean_version": forged["save_version"] = true
			"fractional_version": forged["save_version"] = 1.5
			"boolean_alert": forged["world"]["alert_level"] = true
			"fractional_alert": forged["world"]["alert_level"] = 1.5
			"integer_completed": forged["world"]["completed"] = 1
		var before: Dictionary = game.export_snapshot()
		result = game.restore_snapshot(forged)
		if result.get("ok", true) or game.export_snapshot() != before:
			accepted.append(mutation)
	_check(accepted.is_empty(), "snapshot rejects bool/int confusion and fractional integers atomically", accepted)
	_reject_snapshot(game, [], "non-object save envelope is rejected atomically")

func _test_content_validation() -> void:
	var loaded: Dictionary = ContentLoader.load_mission()
	_check(loaded.get("ok", false) and loaded.get("definition", {}).get("mission_id", "") == "M01",
		"content loader accepts M01 JSON numbers and returns its definition", loaded.get("errors", []))
	if not loaded.get("ok", false):
		return
	var definition: Dictionary = loaded.get("definition", {})
	var accepted: Array = []
	for mutation in ["empty_goals", "unknown_goal", "missing_account", "missing_parent", "external_url", "bad_source", "fractional_schema", "boolean_schema", "boolean_record_sources", "non_object_home"]:
		var invalid: Dictionary = definition.duplicate(true)
		match mutation:
			"empty_goals": invalid["goals"] = []
			"unknown_goal": invalid["goals"] = [{"kind": "unsupported"}]
			"missing_account": invalid["hosts"]["archive"]["accounts"].erase("maint")
			"missing_parent": invalid["hosts"]["archive"]["files"].erase("/vault")
			"external_url": invalid["initial_web_url"] = "https://example.com"
			"bad_source": invalid["pages"][MIRROR]["source"] = "unknown:record"
			"fractional_schema": invalid["schema_version"] = 1.5
			"boolean_schema": invalid["schema_version"] = true
			"boolean_record_sources": invalid["records"]["handoff-47"]["allowed_sources"] = false
			"non_object_home": invalid["hosts"]["archive"]["files"]["/public"] = false
		if ContentLoader.validate(invalid).get("ok", true):
			accepted.append(mutation)
	_check(accepted.is_empty(), "content rejects broken goals, references, paths, sources, and schema types", accepted)
	var duplicate: Dictionary = definition.duplicate(true)
	duplicate["mail"]["complete"]["id"] = "intro"
	_check(not ContentLoader.validate(duplicate).get("ok", true), "duplicate message IDs are rejected")
	var missing: Dictionary = ContentLoader.load_mission("res://data/missions/missing.json")
	_check(not missing.get("ok", true) and not missing.get("errors", []).is_empty(),
		"missing content produces structured loader errors")
