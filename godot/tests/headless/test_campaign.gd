extends SceneTree

const Campaign = preload("res://scripts/core/campaign_game.gd")
const Loader = preload("res://scripts/core/campaign_loader.gd")
const LegacyGame = preload("res://scripts/core/game.gd")
const FIXTURE_PATH := "res://tests/fixtures/campaign_solutions.json"
const LOCALES := ["ko", "en", "ja", "zh_Hans", "es", "de"]

var checks := 0
var failures: Array = []
var definition: Dictionary = {}
var solutions: Dictionary = {}
var instance_count := 0
var test_root := ""


func _initialize() -> void:
	test_root = "user://tests/campaign_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	var loaded: Dictionary = Loader.load_campaign()
	_check(loaded.get("ok", false), "campaign definition is ready", loaded.get("errors", []))
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	_check(file != null, "executable campaign fixture exists")
	if file != null:
		var parsed := JSON.new()
		var parse_error: Error = parsed.parse(file.get_as_text())
		file.close()
		_check(parse_error == OK and parsed.data is Dictionary, "fixture is a JSON object")
		if parse_error == OK and parsed.data is Dictionary:
			solutions = parsed.data.get("missions", {})
	if loaded.get("ok", false) and not solutions.is_empty():
		definition = loaded.definition
		_test_prerequisite_guards()
		_test_all_routes()
		_test_shared_world_and_locale()
		_test_readonly_terminal_context()
		_test_runtime_boundaries()
		_test_network_guards()
		_test_typed_models()
		_test_auth_endpoint_parity()
		_test_expired_web_session()
		_test_remote_mode_forgery()
		_test_upload_current_safety()
		_test_snapshot_and_disk()
		_test_legacy_import()
		_test_endings()
	if DirAccess.dir_exists_absolute(test_root):
		_cleanup(test_root)
	print(JSON.stringify({"suite": "campaign", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not condition:
		failures.append({"case": label, "detail": detail})


func _fresh() -> Variant:
	instance_count += 1
	return Campaign.new(test_root + "/slot_%d.json" % instance_count)


func _paths(id: String) -> Array:
	var entry: Variant = solutions.get(id, {})
	if not entry is Dictionary or not entry.get("paths") is Array or entry.paths.size() != 2:
		_check(false, id + ": exactly two authored solution paths are required")
		return []
	return entry.paths


func _case_completed(game: Variant, id: String) -> bool:
	for item in game.get_view().get("missions", []):
		if item.get("id") == id:
			return item.get("completed", false) == true
	return false


func _prepare(game: Variant, id: String, visiting: Array = []) -> bool:
	if visiting.has(id) or not definition.missions.has(id):
		_check(false, "cannot prepare cyclic or missing prerequisite", {"id": id, "visiting": visiting})
		return false
	var next_visiting := visiting.duplicate()
	next_visiting.append(id)
	for prior in definition.missions[id].prerequisites:
		if _case_completed(game, prior):
			continue
		if not _prepare(game, prior, next_visiting):
			return false
		var paths := _paths(prior)
		if paths.is_empty() or not _replay(game, prior, paths[0]):
			return false
		if not _assert_outcome(game, prior, paths[0].get("expected", {}), "prerequisite"):
			return false
	var chosen: Dictionary = game.choose_mission(id)
	_check(chosen.get("ok", false) and game.get_view().get("mission_id") == id, id + ": choose after real prerequisite solutions", chosen)
	return chosen.get("ok", false) and game.get_view().get("mission_id") == id


func _action(game: Variant, action: Dictionary) -> Dictionary:
	var terminal: int = int(action.get("terminal_id", 0))
	match str(action.get("kind", "")):
		"command": return game.execute(str(action.get("line", "")), terminal)
		"password": return game.submit_password(str(action.get("value", "")), terminal)
		"browse": return game.browse(str(action.get("url", "")))
		"collect_web": return game.collect_web(str(action.get("url", "")))
		"request": return game.request(str(action.get("method", "GET")), str(action.get("url", "")), action.get("body", {}), action.get("headers", {}))
		"tool": return game.use_tool(str(action.get("tool_id", "")), action.get("params", {}))
	_check(false, "fixture contains an unsupported action", action)
	return {"ok": false, "code": "INVALID_TEST_ACTION"}


func _replay(game: Variant, id: String, route: Dictionary) -> bool:
	var actions: Variant = route.get("actions", [])
	if not actions is Array or actions.is_empty():
		_check(false, id + ": route has no executable actions", route.get("id", ""))
		return false
	var passed := true
	for index in range(actions.size()):
		if not actions[index] is Dictionary:
			_check(false, id + ": action must be an object", index)
			return false
		var result := _action(game, actions[index])
		var expected: Dictionary = actions[index].get("expect", {"ok": true})
		for key in expected:
			var equal: bool = result.has(key) and result[key] == expected[key]
			_check(equal, "%s/%s action %d preserves expected %s" % [id, route.get("id", ""), index, key], {"expected": expected[key], "actual": result})
			passed = passed and equal
	return passed


func _world(game: Variant, id: String) -> Dictionary:
	var snapshot: Dictionary = game.export_snapshot()
	if snapshot.get("current_mission") == id and snapshot.get("current_world") is Dictionary:
		return snapshot.current_world
	var states: Variant = snapshot.get("mission_states", {})
	if not states is Dictionary or not states.get(id) is Dictionary:
		_check(false, id + ": authoritative mission snapshot is missing")
		return {}
	return states[id]


func _preserved(world: Dictionary, mission: Dictionary) -> bool:
	var remote: Variant = world.get("remote_files")
	if not remote is Dictionary or remote.size() != mission.hosts.size():
		return false
	for host_id in mission.hosts:
		var files: Dictionary = mission.hosts[host_id].files
		if not remote.get(host_id) is Dictionary or remote[host_id].size() != files.size():
			return false
		for path in files:
			if not remote[host_id].get(path) is Dictionary:
				return false
			for key in ["kind", "owner", "group", "content", "record_id"]:
				if remote[host_id][path].get(key) != files[path].get(key):
					return false
	return true


func _assert_outcome(game: Variant, id: String, expected: Dictionary, context: String) -> bool:
	var view: Dictionary = game.get_view()
	var completed: bool = view.get("mission_id") == id and view.get("completed", false) == true and _case_completed(game, id)
	_check(expected.get("completed") == true and completed, id + ": real goal and campaign completion agree / " + context, view.get("mission_id"))
	var mission: Dictionary = definition.missions[id]
	var world := _world(game, id)
	var archive: Array = []
	for path in world.get("local_files", {}):
		var entry: Dictionary = world.local_files[path]
		if entry.get("kind") == "file" and str(path).begins_with("/home/player/archive/"):
			archive.append(entry)
	for shown in view.get("archive", []):
		if not mission.records.has(shown.get("record_id", "")):
			continue
		var record: Dictionary = mission.records[shown.record_id]
		var expected_text: String = str(TranslationServer.translate(record.display_content_key)) if record.has("display_content_key") else str(record.content)
		_check(shown.get("content") == expected_text, id + ": archive presentation follows the declared display translation", shown.get("record_id"))
	var expected_records: Array = expected.get("archive_record_ids", [])
	_check(expected_records.has(mission.goal.record_id), id + ": fixture independently names the target record")
	for record_id in expected_records:
		var found := false
		if not mission.records.has(record_id):
			_check(false, id + ": fixture references an unauthored record", record_id)
			continue
		var record: Dictionary = mission.records[record_id]
		for entry in archive:
			if entry.get("record_id") == record_id and entry.get("content") == record.content and record.allowed_sources.has(entry.get("source", "")):
				found = true
		_check(found, id + ": recovered ID, canonical payload and allowed provenance match", record_id)
	for fact in expected.get("facts", []):
		_check(view.get("facts", []).has(fact), id + ": expected fact is supported", fact)
	for policy_id in expected.get("policies", {}):
		_check(view.get("policies", {}).get(policy_id) == expected.policies[policy_id], id + ": expected current policy", policy_id)
	if expected.has("session"):
		_check(view.get("host") == expected.session.host_id and view.get("user") == expected.session.account_id, id + ": expected real session identity")
	for service in expected.get("services", []):
		var scan: Dictionary = game.execute("nmap " + str(mission.hosts[service.host_id].domain))
		var expected_line: String = str(service.port) + "/" + str(mission.hosts[service.host_id].services[str(service.port)].protocol) + " " + str(service.state)
		_check(scan.get("ok", false) and str(scan.get("text", "")).contains(expected_line), id + ": service state is observable", scan)
	_check(expected.get("sources_preserved") == true and _preserved(world, mission), id + ": original records and file identities are preserved")
	for goal in mission.goals:
		match str(goal.kind):
			"record_acquired":
				var valid_record := false
				var source: Dictionary = mission.records[goal.record_id]
				for entry in archive:
					if entry.get("record_id") == goal.record_id and entry.get("content") == source.content and source.allowed_sources.has(entry.get("source", "")):
						valid_record = true
				_check(valid_record, id + ": every declared record goal has canonical evidence", goal.record_id)
			"fact":
				_check(view.get("facts", []).has(goal.id), id + ": every declared fact goal is present", goal.id)
			"policy":
				_check(view.get("policies", {}).get(goal.id) == goal.value, id + ": every declared policy goal reflects the current value", goal.id)
			"session":
				var valid_session: bool = world.get("web_sessions", {}).get(goal.host_id, {}).get("account_id") == goal.account_id
				for stack in world.get("terminals", {}).values():
					for session in stack:
						valid_session = valid_session or (session.get("host_id") == goal.host_id and session.get("account_id") == goal.account_id)
				_check(valid_session, id + ": every declared session goal has a real authenticated context", goal)
			"service":
				var observed_service := false
				for service in expected.get("services", []):
					if service.get("host_id") == goal.host_id and str(service.get("port")) == str(goal.port) and service.get("state") == goal.state:
						observed_service = true
				_check(observed_service, id + ": every service goal has an independent observed expectation", goal)
			"sources_preserved":
				_check(_preserved(world, mission), id + ": sources_preserved is checked against authored originals")
			_:
				_check(false, id + ": QA does not silently accept an unknown goal kind", goal)
	return completed


func _reply_count(game: Variant, id: String) -> int:
	var count := 0
	var reply_id: String = str(definition.missions[id].mail.complete.id)
	for message in game.get_view().get("messages", []):
		if message.get("id") == reply_id:
			count += 1
	return count


func _test_all_routes() -> void:
	var total := 0
	for id in definition.mission_order:
		var paths := _paths(id)
		for path in paths:
			var game: Variant = _fresh()
			_check(game.get_view().get("ready", false), id + ": fresh campaign is ready")
			if not _prepare(game, id):
				continue
			_check(not game.get_view().get("completed", true), id + ": initial case is incomplete")
			_replay(game, id, path)
			_assert_outcome(game, id, path.get("expected", {}), str(path.get("id", "")))
			_check(_reply_count(game, id) == 1, id + ": completion reply occurs once")
			game.execute("ls")
			game.execute("pwd")
			_check(_reply_count(game, id) == 1, id + ": post-completion observations do not duplicate effects")
			var restored: Variant = _fresh()
			var result: Dictionary = restored.restore_snapshot(JSON.parse_string(JSON.stringify(game.export_snapshot())))
			_check(result.get("ok", false), id + ": completed case restores", result)
			_check(_reply_count(restored, id) == 1 and _case_completed(restored, id), id + ": restored completion stays singular")
			total += 1
	_check(total == 56, "all 28 × 2 fresh-engine routes were attempted", total)


func _test_prerequisite_guards() -> void:
	var game: Variant = _fresh()
	var before: Dictionary = game.export_snapshot()
	for id in ["M24", "not_a_case"]:
		var result: Dictionary = game.choose_mission(id)
		_check(not result.get("ok", true) and game.export_snapshot() == before, "locked/unknown case cannot be selected atomically", id)
	for ending in definition.endings:
		var result: Dictionary = game.choose_ending(ending.id)
		_check(not result.get("ok", true) and game.export_snapshot() == before, "ending cannot be chosen before final case", ending.id)
	game.get_hint(2)
	_check(not game.get_view().get("completed", true), "requesting guidance cannot complete the current case")
	var first_paths := _paths("M01")
	if not first_paths.is_empty() and _prepare(game, "M01") and _replay(game, "M01", first_paths[1]):
		var advanced: Dictionary = game.advance()
		_check(advanced.get("ok", false) and game.get_view().get("mission_id") == "M02" and _case_completed(game, "M01") and not game.get_view().get("completed", true), "advance opens the next real case and preserves the earned M01 receipt", advanced)
		var incomplete: Dictionary = game.export_snapshot()
		var blocked: Dictionary = game.advance()
		_check(not blocked.get("ok", true) and game.export_snapshot() == incomplete, "an incomplete case cannot advance the campaign")


func _test_shared_world_and_locale() -> void:
	var game: Variant = _fresh()
	var path: Dictionary = _paths("M01")[1]
	if not _prepare(game, "M01") or not _replay(game, "M01", path):
		return
	for terminal in range(4):
		game.get_view(terminal)
	var archive: Array = game.get_view(0).get("archive", [])
	_check(not archive.is_empty(), "M01 alternate route exposes a shared archive")
	if not archive.is_empty():
		var read_result: Dictionary = game.execute("cat " + str(archive[0].path), 1)
		_check(read_result.get("ok", false) and read_result.get("text") == archive[0].content, "another terminal reads the same canonical archive")
	var terminal0: Dictionary = game.get_view(0)
	game.execute("cd /", 1)
	_check(game.get_view(1).get("cwd") == "/" and game.get_view(0).get("cwd") == terminal0.cwd, "terminal working directories remain independent")
	var before: Dictionary = game.export_snapshot()
	var old_locale := TranslationServer.get_locale()
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for terminal in range(4):
			game.get_view(terminal)
		_check(game.export_snapshot() == before, "locale changes presentation without mutating campaign / " + locale)
	TranslationServer.set_locale(old_locale)


func _test_runtime_boundaries() -> void:
	var game: Variant = _fresh()
	for command in ["rm /", "rm -r /", "cat user://saves/campaign_01.json", "cat /etc/passwd", "ls; pwd", "tool unknown_tool x"]:
		var before: Dictionary = game.export_snapshot()
		var result: Dictionary = game.execute(command)
		_check(not result.get("ok", true) and game.export_snapshot() == before, "unsupported/root/host operations fail atomically", command)
	for url in ["https://example.com", "file:///etc/passwd", "https://mirror.packet.test.evil/cache/47", "http://127.0.0.1"]:
		var before: Dictionary = game.export_snapshot()
		var result: Dictionary = game.browse(url)
		_check(not result.get("ok", true) and game.export_snapshot() == before, "external browser input cannot mutate the virtual campaign", url)
	game.execute("ssh guest@archive.packet.test")
	game.submit_password("guest")
	var denied: Dictionary = game.execute("cat /vault/handoff.log")
	_check(not denied.get("ok", true) and game.get_view().get("user") == "guest" and game.get_view().get("archive", []).is_empty() and not game.get_view().get("completed", true), "guest denial cannot disclose or recover the protected original", denied)
	var before_terminal: Dictionary = game.export_snapshot()
	var invalid_terminal: Dictionary = game.execute("pwd", 4)
	_check(not invalid_terminal.get("ok", true) and game.export_snapshot() == before_terminal, "terminal IDs outside the declared range fail atomically")


func _test_network_guards() -> void:
	var closed_found := false
	var internal_found := false
	for id in definition.mission_order:
		var mission: Dictionary = definition.missions[id]
		for host_id in mission.hosts:
			var host: Dictionary = mission.hosts[host_id]
			if not closed_found and host.via.has("local"):
				for port in host.services:
					var service: Dictionary = host.services[port]
					if service.state == "open" or not str(service.protocol) in ["http", "https"]:
						continue
					var closed_game: Variant = _fresh()
					if not _prepare(closed_game, id):
						continue
					var unchanged: Dictionary = closed_game.export_snapshot()
					var response: Dictionary = closed_game.browse(str(service.protocol) + "://" + str(host.domain))
					_check(response.get("status") == 503 and not response.get("ok", true) and closed_game.export_snapshot() == unchanged, id + ": authored closed/filtered HTTP service rejects requests atomically", response)
					closed_found = true
					break
			if not host.services.has("22") or host.accounts.is_empty():
				continue
			var closed: bool = host.services["22"].state != "open" and host.via.has("local")
			var internal: bool = host.services["22"].state == "open" and not host.via.has("local")
			if (closed and not closed_found) or (internal and not internal_found):
				var game: Variant = _fresh()
				if not _prepare(game, id):
					continue
				var before: Dictionary = game.export_snapshot()
				var result: Dictionary = game.execute("ssh " + str(host.accounts.keys()[0]) + "@" + str(host.domain))
				_check(not result.get("ok", true) and not result.get("needs_password", true) and game.export_snapshot() == before, id + ": closed or unreachable SSH cannot yield authentication/access", host_id)
				closed_found = closed_found or closed
				internal_found = internal_found or internal
	_check(closed_found, "authored topology includes a closed/filtered service negative case")
	_check(internal_found, "authored topology includes an internal host unavailable directly from local")


func _test_typed_models() -> void:
	_test_auth_model()
	_test_session_model()
	_test_csrf_model()
	_test_upload_model()
	_test_idor_model()
	_test_optional_models()


func _typed_context(kind: String) -> Dictionary:
	for id in definition.mission_order:
		for challenge_id in definition.missions[id].challenges:
			var challenge: Dictionary = definition.missions[id].challenges[challenge_id]
			if challenge.kind == kind:
				var game: Variant = _fresh()
				if not _prepare(game, id) or not _prefix_before_challenge(game, id, challenge_id):
					return {}
				return {"game": game, "id": id, "challenge_id": challenge_id, "challenge": challenge}
	_check(false, "authored campaign contains typed " + kind + " behavior")
	return {}


func _prefix_before_challenge(game: Variant, id: String, challenge_id: String) -> bool:
	var paths := _paths(id)
	if paths.is_empty():
		return false
	for action in paths[0].actions:
		var matches: bool = action.get("kind") == "tool" and (action.get("tool_id") == challenge_id or action.get("params", {}).get("challenge_id") == challenge_id)
		if action.get("kind") == "request":
			var page: Dictionary = definition.missions[id].pages.get(str(action.get("url", "")).get_slice("?", 0), {})
			matches = page.get("challenge_id", "") == challenge_id
		if action.get("kind") == "command":
			matches = str(action.get("line", "")).begins_with("tool " + challenge_id + " ")
		if matches:
			return true
		if not _replay(game, id, {"id": "typed_prefix", "actions": [action]}):
			return false
	_check(false, id + ": primary route actually exercises " + challenge_id)
	return false


func _model_state(context: Dictionary) -> Dictionary:
	return _world(context.game, context.id).get("model_states", {}).get(context.challenge_id, {})


func _observe(context: Dictionary, input: Variant) -> Dictionary:
	return context.game.use_tool(context.challenge_id, {"input": input})


func _strict(context: Dictionary) -> void:
	var result: Dictionary = context.game.execute("configure " + str(context.challenge.policy_id) + " true")
	_check(result.get("ok", false) and context.game.get_view().get("policies", {}).get(context.challenge.policy_id) == true, context.id + ": the configured current policy is strict", result)


func _challenge_url(context: Dictionary) -> String:
	for url in definition.missions[context.id].pages:
		if definition.missions[context.id].pages[url].get("challenge_id") == context.challenge_id:
			return url
	_check(false, context.id + ": typed tool has a shared HTTP route")
	return ""


func _web_login(context: Dictionary, page_url: String) -> void:
	var host_id: String = str(context.challenge.get("host_id", context.challenge.get("requires_session", {}).get("host_id", "")))
	if not definition.missions[context.id].hosts.has(host_id):
		_check(false, context.id + ": typed HTTP fixture has a declared host")
		return
	var account_id: String = str(context.challenge.get("account_id", context.challenge.get("requires_session", {}).get("account_id", "")))
	var host: Dictionary = definition.missions[context.id].hosts[host_id]
	if not host.accounts.has(account_id):
		_check(false, context.id + ": typed HTTP fixture has a real account")
		return
	var origin: String = page_url.get_slice("://", 0) + "://" + page_url.get_slice("://", 1).get_slice("/", 0)
	var previous_web: Dictionary = _world(context.game, context.id).get("web_sessions", {}).duplicate(true)
	var result: Dictionary = context.game.request("POST", origin + "/login", {"username": account_id, "password": host.accounts[account_id].password}, {})
	var current_web: Dictionary = _world(context.game, context.id).get("web_sessions", {})
	_check(result.get("status") == 200 and current_web.get(host_id, {}).get("account_id") == account_id, context.id + ": HTTP login creates the declared web identity", result)
	for other_host in current_web:
		if other_host != host_id:
			_check(previous_web.has(other_host) and current_web[other_host] == previous_web[other_host], context.id + ": a browser login does not authenticate a different origin", other_host)
	for other_host in previous_web:
		if other_host != host_id:
			_check(current_web.get(other_host) == previous_web[other_host], context.id + ": another origin's web session remains intact", other_host)


func _test_auth_model() -> void:
	var context := _typed_context("auth")
	if context.is_empty():
		return
	_strict(context)
	var account: String = str(context.challenge.account_id)
	var host: Dictionary = definition.missions[context.id].hosts[context.challenge.host_id]
	var wrong := {"action": "login", "username": account, "password": "not-the-authored-password"}
	for attempt in range(int(context.challenge.get("limit", 2))):
		var result := _observe(context, wrong)
		_check(result.get("status") == 401, context.id + ": wrong password is rejected before the rate limit", result)
	var limited := _observe(context, wrong)
	_check(limited.get("status") == 429 and _model_state(context).get("blocked") == true, context.id + ": repeated failures produce a real blocked state", limited)
	var before: Dictionary = context.game.export_snapshot()
	var invalid_wait := _observe(context, {"action": "wait", "ticks": 0})
	_check(not invalid_wait.get("ok", true) and context.game.export_snapshot() == before, context.id + ": zero-tick wait cannot bypass cooldown", invalid_wait)
	var blocked := _observe(context, {"action": "login", "username": account, "password": host.accounts[account].password})
	_check(blocked.get("status") == 429, context.id + ": even valid credentials remain blocked before recovery", blocked)
	_observe(context, {"action": "wait", "ticks": int(context.challenge.get("cooldown", 2))})
	var normal := _observe(context, {"action": "login", "username": account, "password": host.accounts[account].password})
	_check(normal.get("status") == 200 and _model_state(context).get("normal_allowed") == true and _model_state(context).get("limit_observed") == true, context.id + ": explicit recovery retains both restriction and normal-use evidence", normal)
	# The case also requires its later evidence chain; a model observation alone is not completion.
	_check(context.game.reset().get("ok", false), "reset the case before the earned completion fixture")
	var full_path: Dictionary = solutions[context.id].paths[0]
	_check(_replay(context.game, context.id, full_path), "all current case goals are earned before policy revalidation")
	_check(context.game.get_view().get("completed", false) and _reply_count(context.game, context.id) == 1, "revalidation starts from a real singular completion receipt")
	context.game.execute("configure " + str(context.challenge.policy_id) + " false")
	_check(not context.game.get_view().get("completed", true), context.id + ": old success observations cannot override the current unsafe policy")
	context.game.execute("configure " + str(context.challenge.policy_id) + " true")
	_check(_reply_count(context.game, context.id) == 1 and context.game.export_snapshot().get("completed", []).count(context.id) == 1, context.id + ": revalidation cannot duplicate the campaign completion receipt")


func _test_session_model() -> void:
	var context := _typed_context("session")
	if context.is_empty():
		return
	_strict(context)
	_observe(context, {"action": "issue", "token": "qa-session"})
	var allowed := _observe(context, {"action": "reuse", "token": "qa-session"})
	_check(allowed.get("status") == 200, context.id + ": issued token permits normal use", allowed)
	_observe(context, {"action": "revoke", "token": "qa-session"})
	var denied := _observe(context, {"action": "reuse", "token": "qa-session"})
	_check(denied.get("status") == 403 and _model_state(context).get("tokens", {}).get("qa-session", {}).get("revoked") == true, context.id + ": server-revoked token cannot be reused", denied)
	var unknown := _observe(context, {"action": "reuse", "token": "never-issued-token"})
	_check(unknown.get("status") == 403, context.id + ": an unknown token cannot grant access", unknown)


func _test_csrf_model() -> void:
	var context := _typed_context("csrf")
	if context.is_empty():
		return
	_strict(context)
	var initial: Variant = _model_state(context).get("value")
	var forged := _observe(context, {"origin": "https://foreign.packet.test", "token": "invalid", "value": "forged"})
	_check(forged.get("status") == 403 and _model_state(context).get("value") == initial, context.id + ": rejected CSRF cannot change the protected setting", forged)
	var normal_input := {"origin": context.challenge.origin, "token": context.challenge.csrf_token, "value": "qa-approved"}
	var normal := _observe(context, normal_input)
	_check(normal.get("status") == 200 and _model_state(context).get("value") == "qa-approved", context.id + ": valid intent updates the requested setting", normal)
	var url := _challenge_url(context)
	if url.is_empty():
		return
	var host_id: String = str(context.challenge.get("requires_session", {}).get("host_id", ""))
	var browser: Dictionary = context.game.browse(url)
	_check(browser.get("actor") == "anonymous" and not _world(context.game, context.id).get("web_sessions", {}).has(host_id) and _model_state(context).get("value") == "qa-approved", context.id + ": browser context never acquires SSH cookies or changes protected values", browser)
	var terminal_request: Dictionary = context.game.request("POST", url, {"input": normal_input}, {"Origin": context.challenge.origin})
	_check(terminal_request.get("actor_context") == "terminal" and terminal_request.get("actor") == context.challenge.requires_session.account_id and terminal_request.get("cookie_preview", "").is_empty() and not _world(context.game, context.id).get("web_sessions", {}).has(host_id), context.id + ": RequestLab names its terminal identity without inventing a browser session", terminal_request)
	_web_login(context, url)
	var spoofed: Dictionary = context.game.request("POST", url, {"input": normal_input}, {"Origin": "https://foreign.packet.test"})
	_check(spoofed.get("status") == 403 and spoofed.get("source_origin") == "https://foreign.packet.test" and _model_state(context).get("value") == "qa-approved", context.id + ": HTTP origin overrides a forged input claim", spoofed)
	var accepted: Dictionary = context.game.request("POST", url, {"input": normal_input}, {"Origin": context.challenge.origin})
	_check(accepted.get("status") == 200 and accepted.get("actor") == context.challenge.get("requires_session", {}).get("account_id") and not accepted.get("trace", []).is_empty(), context.id + ": HTTP response identifies its real actor and processing trace", accepted)


func _test_upload_model() -> void:
	var context := _typed_context("upload")
	if context.is_empty():
		return
	_strict(context)
	for input in [{"filename": "fake.jpg", "mime": "image/jpeg", "signature": "SCRIPT"}, {"filename": "fake.bin", "mime": "image/jpeg", "signature": "JPEG"}, {"filename": "fake.jpg", "mime": "application/octet-stream", "signature": "JPEG"}]:
		var denied := _observe(context, input)
		_check(denied.get("status") == 415 and _model_state(context).get("executable") == false, context.id + ": filename, MIME and actual format are checked independently", denied)
	var normal := _observe(context, {"filename": "normal.jpg", "mime": "image/jpeg", "signature": "JPEG"})
	_check(normal.get("status") in [200, 201] and _model_state(context).get("image_allowed") == true and _model_state(context).get("executable") == false, context.id + ": normal photos remain usable without becoming executable", normal)


func _test_idor_model() -> void:
	var context := _typed_context("idor")
	if context.is_empty():
		return
	var account: String = str(context.game.get_view().user)
	var owned := ""
	var other := ""
	for object_id in context.challenge.objects:
		if context.challenge.objects[object_id].owner == account:
			owned = object_id
		else:
			other = object_id
	_check(not owned.is_empty() and not other.is_empty(), context.id + ": object fixture contains owner and foreign cases")
	if owned.is_empty() or other.is_empty():
		return
	_strict(context)
	var before_count: int = context.game.get_view().get("archive", []).size()
	var denied := _observe(context, {"object_id": other})
	_check(denied.get("status") == 403 and context.game.get_view().get("archive", []).size() == before_count, context.id + ": object ownership blocks foreign records without awarding them", denied)
	var allowed := _observe(context, {"object_id": owned})
	_check(allowed.get("status") == 200, context.id + ": owner access survives the authorization repair", allowed)


func _test_optional_models() -> void:
	for kind in ["reverse", "memory"]:
		var context := _typed_context(kind)
		if context.is_empty():
			continue
		var before_count: int = context.game.get_view().get("archive", []).size()
		var wrong := _observe(context, "not-an-analysis-result")
		_check(not wrong.get("solved", true) and context.game.get_view().get("archive", []).size() == before_count and not context.game.get_view().get("completed", true), context.id + ": an incorrect analysis does not grant the record", wrong)
		if kind == "memory":
			var memory_size: int = int(context.challenge.memory_size)
			var oversized := _observe(context, "00 ".repeat(memory_size + 1))
			_check(not oversized.get("solved", true) and _model_state(context).get("memory", []).size() <= memory_size and context.game.get_view().get("archive", []).size() == before_count, context.id + ": oversized input cannot create memory outside the declared virtual model", oversized)


func _test_auth_endpoint_parity() -> void:
	var context := _typed_context("auth")
	if context.is_empty():
		return
	_strict(context)
	var account: String = str(context.challenge.account_id)
	var host_id: String = str(context.challenge.host_id)
	var host: Dictionary = definition.missions[context.id].hosts[host_id]
	for attempt in range(int(context.challenge.get("limit", 2)) + 1):
		_observe(context, {"action": "login", "username": account, "password": "qa-wrong-password"})
	_check(_model_state(context).get("blocked") == true, "HTTP parity repro starts with a model-blocked account")
	var login_url: String = "https://" + str(host.domain) + "/login"
	var wrong: Dictionary = context.game.request("POST", login_url, {"username": account, "password": "qa-wrong-password"})
	_check(wrong.get("status") == 429, context.id + ": direct HTTP login shares the model's account rate limit", wrong)
	var correct: Dictionary = context.game.request("POST", login_url, {"username": account, "password": host.accounts[account].password})
	_check(correct.get("status") == 429 and not _world(context.game, context.id).get("web_sessions", {}).has(host_id), context.id + ": valid credentials cannot create a web session during the same cooldown", correct)
	_observe(context, {"action": "wait", "ticks": int(context.challenge.get("cooldown", 2))})
	var recovered: Dictionary = context.game.request("POST", login_url, {"username": account, "password": host.accounts[account].password})
	_check(recovered.get("status") == 200 and _world(context.game, context.id).get("web_sessions", {}).get(host_id, {}).get("account_id") == account, context.id + ": shared HTTP login works after explicit recovery", recovered)


func _test_expired_web_session() -> void:
	var context := _typed_context("session")
	if context.is_empty():
		return
	_strict(context)
	var host_id: String = str(context.challenge.host_id)
	var issued := _observe(context, {"action": "issue", "token": "qa-expiring-token"})
	var web: Dictionary = _world(context.game, context.id).get("web_sessions", {}).get(host_id, {})
	_check(issued.get("ok", false) and web.get("token") == "qa-expiring-token", "expiry repro starts with the managed token as the real browser credential", issued)
	if not issued.get("ok", false) or web.get("token") != "qa-expiring-token":
		return
	for terminal_key in _world(context.game, context.id).get("terminals", {}).keys():
		var terminal: int = int(terminal_key)
		var steps := 0
		while context.game.get_view(terminal).get("host") != "local" and steps < 17:
			var exited: Dictionary = context.game.execute("exit", terminal)
			_check(exited.get("ok", false), "expiry repro closes authenticated SSH fallbacks", exited)
			if not exited.get("ok", false):
				break
			steps += 1
		_check(context.game.get_view(terminal).get("host") == "local", "expiry repro leaves no authenticated terminal context")
	var waited := _observe(context, {"action": "wait", "ticks": 32})
	var state := _model_state(context)
	var token: Dictionary = state.get("tokens", {}).get("qa-expiring-token", {})
	_check(waited.get("ok", false) and (token.is_empty() or int(token.get("expires_at", 0)) <= int(state.get("tick", 0))), "managed token has actually crossed its modeled expiry", waited)
	var url := _challenge_url(context)
	if url.is_empty():
		return
	var browser: Dictionary = context.game.browse(url)
	_check(browser.get("status") in [401, 403] and browser.get("actor") == "anonymous", context.id + ": expired managed cookies cannot authenticate protected browser pages", browser)
	var renewed: Dictionary = context.game.use_tool(context.challenge_id, {"input": {"action": "issue", "token": "qa-unearned-renewal"}, "terminal_id": 0})
	_check(not renewed.get("ok", true) and not _model_state(context).get("tokens", {}).has("qa-unearned-renewal"), context.id + ": expired identity cannot issue itself a new authenticated token", renewed)


func _test_remote_mode_forgery() -> void:
	var game: Variant = _fresh()
	var before: Dictionary = game.export_snapshot()
	var forged: Dictionary = before.duplicate(true)
	var remote: Dictionary = forged.get("current_world", {}).get("remote_files", {}).get("archive", {})
	_check(remote.has("/vault") and remote.has("/vault/handoff.log"), "remote-mode repro retains the real legacy M01 vault fixture")
	if not remote.has("/vault") or not remote.has("/vault/handoff.log"):
		return
	remote["/vault"].mode = "777"
	remote["/vault/handoff.log"].mode = "644"
	var restored: Dictionary = game.restore_snapshot(forged)
	_check(not restored.get("ok", true) and game.export_snapshot() == before, "v2 rejects unreachable remote permission changes atomically", restored)
	game.execute("ssh guest@archive.packet.test")
	game.submit_password("guest")
	var denied_read: Dictionary = game.execute("cat /vault/handoff.log")
	_check(not denied_read.get("ok", true), "remote mode tampering cannot grant guest the protected original", denied_read)


func _test_upload_current_safety() -> void:
	var context := _typed_context("upload")
	if context.is_empty():
		return
	var complete_game: Variant = _fresh()
	var paths := _paths(context.id)
	if paths.is_empty() or not _prepare(complete_game, context.id) or not _replay(complete_game, context.id, paths[0]):
		return
	context.game = complete_game
	_check(context.game.get_view().get("completed", false), "upload-safety repro starts from a fully earned safe completion")
	if not context.game.get_view().get("completed", false):
		return
	context.game.execute("configure " + str(context.challenge.policy_id) + " false")
	var stored := _observe(context, {"filename": "qa-payload.jpg", "mime": "image/jpeg", "signature": "SCRIPT"})
	var unsafe := false
	for file in _model_state(context).get("stored_files", []):
		unsafe = unsafe or file.get("execution_allowed", false)
	_check(stored.get("status") == 201 and unsafe, "upload-safety repro creates a modeled executable upload while protection is off", stored)
	context.game.execute("configure " + str(context.challenge.policy_id) + " true")
	unsafe = _model_state(context).get("executable", false)
	for file in _model_state(context).get("stored_files", []):
		unsafe = unsafe or file.get("execution_allowed", false)
	_check(not (context.game.get_view().get("completed", false) and unsafe), context.id + ": current goals cannot claim a safe repair while stored uploads remain executable")
	_check(_case_completed(context.game, context.id) and context.game.export_snapshot().get("completed", []).count(context.id) == 1, "the historical completion receipt remains singular during the unsafe replay")


func _test_snapshot_and_disk() -> void:
	var game: Variant = _fresh()
	var paths := _paths("M01")
	if paths.is_empty() or not _prepare(game, "M01") or not _replay(game, "M01", paths[0]):
		return
	game.execute("cd /vault", 0)
	game.execute("cd ~/archive", 1)
	var expected: Dictionary = game.export_snapshot().duplicate(true)
	var required := ["save_version", "campaign_id", "content_version", "current_mission", "current_world", "completed", "mission_states", "decisions", "ending"]
	_check(expected.has_all(required) and expected.save_version == 2 and expected.current_mission == "M01", "v2 has the independently declared persistent envelope")
	var world: Dictionary = expected.get("current_world", {})
	_check(world.has_all(["remote_files", "local_files", "terminals", "policies", "model_states", "model_actions", "web_sessions", "facts", "completed", "replies"]), "v2 includes authoritative world, session and model state")
	_check(world.get("terminals", {}).get("0", [{}])[-1].get("cwd") == "/vault" and world.get("terminals", {}).get("1", [{}])[-1].get("cwd") == "/home/player/archive", "nondefault terminal fixture is actually present before saving")
	var saved: Dictionary = game.save_game()
	_check(saved.get("ok", false), "campaign v2 writes its isolated real slot", saved)
	var same_slot: String = test_root + "/slot_%d.json" % instance_count
	var loaded: Variant = Campaign.new(same_slot)
	var result: Dictionary = loaded.load_game()
	# recursion_count is the starting depth, not a configurable maximum.
	_check(result.get("ok", false) and loaded.export_snapshot().recursive_equal(expected, 0), "disk round-trip preserves every independently populated persistent value", result)
	_check(loaded.get_view(0).get("cwd") == "/vault" and loaded.get_view(1).get("cwd") == "/home/player/archive" and _reply_count(loaded, "M01") == 1, "restored public session and reply values agree with the fixture")
	var exposed: Dictionary = loaded.get_view()
	exposed["archive"].clear()
	exposed["messages"].clear()
	_check(loaded.export_snapshot().recursive_equal(expected, 0), "UI dictionaries cannot mutate the restored campaign")
	var roundtrip: Variant = _fresh()
	result = roundtrip.restore_snapshot(JSON.parse_string(JSON.stringify(expected)))
	_check(result.get("ok", false) and roundtrip.export_snapshot().recursive_equal(expected, 0), "JSON integer normalization preserves the authoritative snapshot", result)
	for field in required:
		var missing: Dictionary = expected.duplicate(true)
		missing.erase(field)
		_reject_snapshot(roundtrip, missing, "missing v2 envelope field: " + field)
	for field in world:
		var missing: Dictionary = expected.duplicate(true)
		missing.current_world.erase(field)
		_reject_snapshot(roundtrip, missing, "missing persistent world field: " + str(field))
	for value in [true, 2.5, "2"]:
		var invalid: Dictionary = expected.duplicate(true)
		invalid.save_version = value
		_reject_snapshot(roundtrip, invalid, "invalid v2 save version type/value")
	for value in [true, 1.5, int(definition.missions.M01.alert_max) + 1]:
		var invalid_alert: Dictionary = expected.duplicate(true)
		invalid_alert.current_world.alert_level = value
		_reject_snapshot(roundtrip, invalid_alert, "boolean, fractional or out-of-range campaign alert")
	var invalid: Dictionary = expected.duplicate(true)
	invalid.content_version = int(definition.content_version) + 1
	_reject_snapshot(roundtrip, invalid, "unsupported campaign content version")
	invalid = expected.duplicate(true)
	invalid.current_mission = "M99"
	_reject_snapshot(roundtrip, invalid, "unknown current mission")
	invalid = expected.duplicate(true)
	invalid.completed.append("M24")
	_reject_snapshot(roundtrip, invalid, "forged completion without prerequisites or a valid receipt")
	invalid = expected.duplicate(true)
	invalid.current_world.terminals["0"][-1].account_id = "unregistered-root"
	_reject_snapshot(roundtrip, invalid, "unregistered account cannot be restored")
	invalid = expected.duplicate(true)
	invalid.current_world.terminals["0"][-1].cwd = "/no-such-working-directory"
	_reject_snapshot(roundtrip, invalid, "nonexistent session cwd cannot be restored")
	invalid = expected.duplicate(true)
	invalid.current_world.facts.append("forged-ending-fact")
	_reject_snapshot(roundtrip, invalid, "facts require actual records or model observations")
	invalid = expected.duplicate(true)
	invalid.ending = definition.endings[0].id
	_reject_snapshot(roundtrip, invalid, "snapshot cannot unlock the ending before the main campaign")
	var archive: Array = game.get_view().get("archive", [])
	if not archive.is_empty():
		invalid = expected.duplicate(true)
		invalid.current_world.local_files[archive[0].path].content = "same ID, changed canonical payload"
		_reject_snapshot(roundtrip, invalid, "same-ID payload forgery is rejected")
		invalid = expected.duplicate(true)
		invalid.current_world.local_files[archive[0].path].source = "untrusted:source"
		_reject_snapshot(roundtrip, invalid, "untrusted record provenance is rejected")
	_reject_snapshot(roundtrip, [], "non-object snapshots are rejected")


func _reject_snapshot(game: Variant, raw: Variant, label: String) -> void:
	var before: Dictionary = game.export_snapshot()
	var result: Dictionary = game.restore_snapshot(raw)
	_check(not result.get("ok", true) and game.export_snapshot() == before, "atomic snapshot rejection / " + label, result)


func _test_legacy_import() -> void:
	var legacy: Variant = LegacyGame.new(test_root + "/legacy.json")
	var collected: Dictionary = legacy.collect_web("https://mirror.packet.test/cache/47")
	_check(collected.get("ok", false) and legacy.get_view().get("completed", false), "legacy fixture completed through the real v1 record path")
	var saved: Dictionary = legacy.save_game()
	_check(saved.get("ok", false), "legacy import fixture writes only its isolated test slot", saved)
	if not saved.get("ok", false):
		return
	var legacy_bytes: PackedByteArray = FileAccess.get_file_as_bytes(test_root + "/legacy.json")
	var raw: Dictionary = legacy.export_snapshot()
	var preserved: Dictionary = raw.duplicate(true)
	var game: Variant = _fresh()
	_reject_snapshot(game, raw, "v1 is not silently treated as a v2 save")
	var result: Dictionary = game.import_m01(raw)
	_check(result.get("ok", false) and _case_completed(game, "M01") and not _case_completed(game, "M02") and game.get_view().get("mission_id") == "M01", "explicit legacy import grants only the validated M01 receipt", result)
	_check(raw == preserved and legacy.export_snapshot() == preserved, "import never modifies the source legacy snapshot or game")
	var imported: Dictionary = game.export_snapshot()
	var bad: Dictionary = raw.duplicate(true)
	var archive: Array = legacy.get_view().get("archive", [])
	if not archive.is_empty():
		bad.world.local_files[archive[0].path].content = "forged legacy record"
		var rejected: Dictionary = game.import_m01(bad)
		_check(not rejected.get("ok", true) and game.export_snapshot() == imported, "tampered legacy import preserves the current campaign")
	_check(FileAccess.get_file_as_bytes(test_root + "/legacy.json") == legacy_bytes, "successful and failed import never rewrite the legacy disk slot")


func _test_endings() -> void:
	var main_only: Variant = _fresh()
	for index in range(1, 25):
		var id := "M%02d" % index
		var paths := _paths(id)
		if paths.is_empty() or not _prepare(main_only, id) or not _replay(main_only, id, paths[0]):
			return
		_assert_outcome(main_only, id, paths[0].expected, "main-only campaign")
	for id in definition.mission_order:
		if definition.missions[id].optional:
			_check(not _case_completed(main_only, id), "optional case is not required for the main ending", id)
	var base_ending := ""
	for ending in definition.endings:
		if ending.requires_facts.is_empty():
			base_ending = ending.id
	_check(not base_ending.is_empty(), "main-only campaign has a base ending")
	if not base_ending.is_empty():
		var result: Dictionary = main_only.choose_ending(base_ending)
		_check(result.get("ok", false) and main_only.get_view().get("ending", {}).get("id") == base_ending, "all main cases suffice for the base ending without optional activities", result)
	_test_ending_post_evidence(main_only.export_snapshot())
	var completed: Variant = _fresh()
	for id in definition.mission_order:
		var paths := _paths(id)
		if paths.is_empty() or not _prepare(completed, id) or not _replay(completed, id, paths[0]):
			return
	var proven: Dictionary = completed.export_snapshot()
	_check(proven.get("completed", []).size() == 28, "the ending fixture was earned through all 28 actual routes")
	for ending in definition.endings:
		var game: Variant = _fresh()
		var restored: Dictionary = game.restore_snapshot(proven)
		_check(restored.get("ok", false), "full earned campaign snapshot restores for ending " + str(ending.id), restored)
		var result: Dictionary = game.choose_ending(ending.id)
		_check(result.get("ok", false) and game.get_view().get("ending", {}).get("id") == ending.id and game.export_snapshot().get("ending") == ending.id, "authored ending is independently reachable: " + str(ending.id), result)
		var saved: Dictionary = game.save_game()
		_check(saved.get("ok", false), "full campaign and chosen ending save without discarding earlier cases", saved)
		var same_slot: String = test_root + "/slot_%d.json" % instance_count
		var reload: Variant = Campaign.new(same_slot)
		var loaded: Dictionary = reload.load_game()
		_check(loaded.get("ok", false) and reload.get_view().get("ending", {}).get("id") == ending.id and reload.export_snapshot().get("completed", []).size() == 28, "ending and all case receipts survive a full disk reload", loaded)
	var before: Dictionary = completed.export_snapshot()
	var invalid: Dictionary = completed.choose_ending("not_an_ending")
	_check(not invalid.get("ok", true) and completed.export_snapshot() == before, "unknown endings are rejected atomically")


func _test_ending_post_evidence(main_snapshot: Dictionary) -> void:
	var cases := [
		{"ending": "public_redacted", "optional": ["S01"]},
		{"ending": "independent_review", "optional": ["S02", "R01", "P01"]},
	]
	for scenario in cases:
		var game: Variant = _fresh()
		var restored: Dictionary = game.restore_snapshot(main_snapshot)
		_check(restored.get("ok", false), "ending-evidence repro restores an actually earned main campaign", restored)
		if not restored.get("ok", false):
			continue
		var preconditions := true
		for id in scenario.optional:
			if not _prepare(game, id):
				preconditions = false
				break
			var main_fact: String = str(id).to_lower() + "_evidence"
			var post_fact: String = str(id).to_lower() + "_exhibit_2"
			var paths := _paths(id)
			if paths.is_empty():
				preconditions = false
				break
			for action in paths[0].actions:
				if game.get_view().get("facts", []).has(main_fact):
					break
				if not _replay(game, id, {"id": "ending_partial_evidence", "actions": [action]}):
					preconditions = false
					break
			var facts: Array = game.get_view().get("facts", [])
			var partial: bool = facts.has(main_fact) and not facts.has(post_fact) and not _case_completed(game, id)
			_check(partial, id + ": main evidence exists but the ending's post-evidence has not been obtained", facts)
			preconditions = preconditions and partial
		if not preconditions:
			continue
		var returned: Dictionary = game.choose_mission("M24")
		_check(returned.get("ok", false) and game.get_view().get("mission_id") == "M24", "ending-evidence repro returns to M24 with the partial optional checkpoints preserved", returned)
		if not returned.get("ok", false):
			continue
		var listed_available := false
		var base_available := false
		for ending in game.get_view().get("endings", []):
			if ending.id == scenario.ending:
				listed_available = ending.get("available", false)
			if ending.id == "sealed_audit":
				base_available = ending.get("available", false)
		_check(not listed_available and base_available, "extended ending stays locked without its post-evidence while the base ending remains available", scenario.ending)
		var before: Dictionary = game.export_snapshot()
		var chosen: Dictionary = game.choose_ending(scenario.ending)
		_check(not chosen.get("ok", true) and game.export_snapshot() == before, "an ending cannot assert conclusions whose post-evidence is still missing", {"ending": scenario.ending, "result": chosen})


func _cleanup(path: String) -> void:
	if path != test_root and not path.begins_with(test_root + "/"):
		_check(false, "test cleanup stays inside its own unique directory", path)
		return
	var directory := DirAccess.open(path)
	if directory == null:
		_check(false, "test directory can be cleaned", path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir() and not directory.is_link(entry):
			_cleanup(child)
		else:
			_check(DirAccess.remove_absolute(child) == OK, "test file cleanup", entry)
		entry = directory.get_next()
	directory.list_dir_end()
	_check(DirAccess.remove_absolute(path) == OK, "test directory cleanup", path)


func _test_readonly_terminal_context() -> void:
	var game: Variant = _fresh()
	var before: Dictionary = game.export_snapshot()
	for terminal in range(4):
		game.get_view(terminal)
		game.autocomplete("ca", terminal)
	_check(game.export_snapshot().recursive_equal(before, 0), "view and completion reads never create terminal state")
	var result: Dictionary = game.execute("not_registered", 3)
	_check(not result.get("ok", true) and game.export_snapshot().recursive_equal(before, 0), "a rejected command does not create an unused terminal")
	result = game.request("GET", "https://unregistered.invalid", {}, {"X-Packet-Context": "terminal"}, 3)
	_check(not result.get("ok", true) and game.export_snapshot().recursive_equal(before, 0), "a rejected request preserves the selected terminal and world")
	result = game.execute("ssh guest@archive.packet.test", 0)
	_check(result.get("needs_password", false), "authentication fixture is pending before cross-terminal reads")
	game.get_view(2)
	game.autocomplete("he", 3)
	game.execute("not_registered", 1)
	_check(game.get_view(0).get("password_pending", false), "cross-terminal reads and rejected commands retain pending input")
	_check(game.submit_password("guest", 0).get("ok", false), "retained pending authentication accepts the real fixture credential")
