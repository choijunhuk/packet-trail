extends "res://scripts/core/game.gd"

const Models = preload("res://scripts/core/tool_runtime.gd")
const EXTRA_COMMANDS := ["man", "whoami", "id", "grep", "find", "mkdir", "cp", "mv", "rm", "nmap", "scan", "dig", "ping", "traceroute", "route", "pivot", "curl", "wget", "sudo", "strings", "xxd", "decode", "configure", "tool"]
var _terminal := 0
var _authentication: Dictionary = {}


func configure(definition: Dictionary) -> void:
	_definition = _normalize_numbers(definition)
	_ready = true
	_world = _initial_world()
	_world["terminals"] = {"0": _world.sessions}
	_world["policies"] = definition.get("policies", {}).duplicate(true)
	_world["model_states"] = {}
	_world["model_actions"] = {}
	_world["web_sessions"] = {}
	_world["facts"] = []
	_world["observations"] = []
	_world["permission_grants"] = {}
	_world.discovered = []
	for id in definition.hosts:
		if definition.hosts[id].get("via", ["local"]).has("local"):
			_world.discovered.append(id)
	_authentication.clear()
	_terminal = 0
	_pending = {}
	_evaluate_completion()


func select_terminal(id: int) -> bool:
	if id < 0 or id > 3:
		return false
	_authentication[str(_terminal)] = _pending
	if not _world.terminals.has(str(id)):
		_world.terminals[str(id)] = [{"host_id": "local", "account_id": "player", "cwd": "/home/player"}]
	_terminal = id
	_world.sessions = _world.terminals[str(id)]
	_pending = _authentication.get(str(id), {})
	return true


func run_command(line: String, terminal_id: int = 0) -> Dictionary:
	if terminal_id < 0 or terminal_id > 3:
		return _result(false, "INVALID_TERMINAL", "Terminal ID must be 0–3.")
	var parsed: Dictionary = Parser.parse(line)
	if not parsed.ok:
		return _result(false, parsed.code, parsed.text)
	var before: Dictionary = checkpoint()
	select_terminal(terminal_id)
	if not _pending.is_empty():
		var busy: Dictionary = _result(false, "AUTH_REQUIRED", "Complete or cancel authentication first.")
		rollback(before)
		return busy
	var command: String = parsed.command
	var args: Array = parsed.args
	var result: Dictionary
	if COMMANDS.has(command):
		result = super.execute(line)
	else:
		result = _extra(command, args)
	if not result.ok and not result.get("changed", false):
		rollback(before)
	_evaluate_completion()
	return result


func authenticate(password: String, terminal_id: int = 0) -> Dictionary:
	var before: Dictionary = checkpoint()
	if not select_terminal(terminal_id):
		return _result(false, "INVALID_TERMINAL", "Terminal ID must be 0–3.")
	if not _pending.is_empty():
		var service: Dictionary = _service(_pending.host_id, "22", _session().host_id)
		if not service.ok or service.get("protocol", "") != "ssh":
			var unavailable: Dictionary = _result(false, "SERVICE_UNAVAILABLE", "SSH service conditions changed before authentication completed.")
			rollback(before)
			return unavailable
	var result: Dictionary = super.submit_password(password)
	if not result.ok and not result.get("changed", false):
		rollback(before)
	_evaluate_completion()
	return result


func cancel_auth(terminal_id: int = 0) -> Dictionary:
	if not select_terminal(terminal_id):
		return _result(false, "INVALID_TERMINAL", "Terminal ID must be 0–3.")
	return super.cancel_authentication()


func _ssh(args: Array) -> Dictionary:
	if args.size() != 1 or str(args[0]).count("@") != 1:
		return _usage("ssh user@host")
	var host_id: String = _host(str(args[0]).get_slice("@", 1))
	var service: Dictionary = _service(host_id, "22", _session().host_id)
	if not service.ok:
		return service
	if service.get("protocol", "") != "ssh":
		return _result(false, "PROTOCOL_MISMATCH", "An open port without an SSH service cannot create a shell.")
	var result: Dictionary = super._ssh(args)
	if result.ok and not _world.discovered.has(host_id):
		_world.discovered.append(host_id)
		result.changed = true
	return result


func _archive(source: Dictionary, name: String, destination: String) -> Dictionary:
	var result: Dictionary = super._archive(source, name, destination)
	if result.ok:
		result.text = "ARCHIVED / " + name
		if _world.completed:
			result.text += "\n" + _definition.mission_id + " COMPLETE / " + _tr(_definition.title)
	return result


func _cat(args: Array) -> Dictionary:
	var result: Dictionary = super._cat(args)
	if result.ok and args.size() == 1:
		var path: Dictionary = FS.normalize(str(args[0]), _session().cwd, _home())
		var entry: Dictionary = _files().get(path.get("path", ""), {})
		if entry.has("display_content_key"):
			result.text = _tr(entry.display_content_key)
		elif _definition.records.has(entry.get("record_id", "")) and _definition.records[entry.record_id].has("display_content_key"):
			result.text = _tr(_definition.records[entry.record_id].display_content_key)
		for id in _definition.hosts:
			if str(entry.get("content", "")).contains(_definition.hosts[id].domain) and not _world.discovered.has(id):
				_world.discovered.append(id)
				result.changed = true
	return result


func _sources_preserved() -> bool:
	return _world.remote_files == _initial_remote_files()


func _initial_remote_files() -> Dictionary:
	var remote: Dictionary = {}
	for id in _definition.hosts:
		var files: Dictionary = _definition.hosts[id].files.duplicate(true)
		for path in files:
			files[path]["source"] = files[path].get("source", str(id) + ":" + str(path))
		remote[id] = files
	return remote


func _evaluate_completion() -> bool:
	if not _world.has("facts"):
		return false
	_world.facts = _computed_facts()
	var was: bool = _world.completed
	var satisfied: bool = not _definition.goals.is_empty()
	for goal in _definition.goals:
		satisfied = satisfied and _goal(goal)
	_world.completed = satisfied
	_world.replies = ["complete"] if satisfied else []
	return satisfied and not was


func _goal(goal: Dictionary) -> bool:
	match str(goal.kind):
		"record_acquired":
			for path in _world.local_files:
				var entry: Dictionary = _world.local_files[path]
				if str(path).begins_with("/home/player/archive/") and entry.record_id == goal.record_id and _record_valid(entry):
					return true
		"sources_preserved":
			return _sources_preserved()
		"fact":
			if not _world.facts.has(goal.id):
				return false
			for id in _definition.challenges:
				var challenge: Dictionary = _definition.challenges[id]
				if challenge.kind == "upload" and challenge.get("fact_id", "") == goal.id and not _uploads_safe(_world.model_states.get(id, {})):
					return false
			return true
		"policy":
			return _world.policies.get(goal.id) == goal.value
		"session":
			return _has_session(goal.host_id, goal.account_id)
		"service":
			return _service(goal.host_id, str(goal.port), "local").get("state", "") == goal.state
	return false


func _uploads_safe(state: Dictionary) -> bool:
	if state.get("executable", false):
		return false
	for file in state.get("stored_files", []):
		if file.get("execution_allowed", false):
			return false
	return true


func _computed_facts() -> Array:
	var facts: Array = []
	for entry in _world.local_files.values():
		if _record_valid(entry):
			for fact in _definition.records[entry.record_id].get("grants_facts", []):
				if not facts.has(fact):
					facts.append(fact)
	for id in _world.get("model_states", {}):
		var challenge: Dictionary = _definition.challenges[id]
		if _world.model_states[id].get("solved", false) and challenge.has("fact_id") and not facts.has(challenge.fact_id):
			facts.append(challenge.fact_id)
	facts.sort()
	return facts


func _record_valid(entry: Dictionary) -> bool:
	var id: String = str(entry.get("record_id", ""))
	return _definition.records.has(id) and entry.get("content", "") == _definition.records[id].content and _definition.records[id].allowed_sources.has(entry.get("source", ""))


func _known_source(entry: Dictionary) -> bool:
	return _record_valid(entry) or super._known_source(entry)


func _groups() -> Array:
	var groups: Array = super._groups().duplicate()
	for group in _world.get("permission_grants", {}).get(_session().host_id + ":" + _session().account_id, []):
		if not groups.has(group):
			groups.append(group)
	return groups


func _host(address: String) -> String:
	if _definition.hosts.has(address):
		return address
	for id in _definition.hosts:
		if address in [_definition.hosts[id].domain, _definition.hosts[id].address]:
			return id
	return ""


func _service(host_id: String, port: String, origin: String) -> Dictionary:
	if not _definition.hosts.has(host_id):
		return _result(false, "HOST_NOT_FOUND", "Unknown virtual host.")
	var host: Dictionary = _definition.hosts[host_id]
	if origin != host_id and not host.get("via", ["local"]).has(origin):
		var filtered: Dictionary = _result(false, "UNREACHABLE", "No route from " + origin + " to " + host_id)
		filtered["state"] = "filtered"
		return filtered
	var service: Dictionary = host.services.get(port, {"state": "closed", "protocol": "unknown"})
	var state: String = service.state
	if service.has("policy_id") and _world.policies.get(service.policy_id) != service.get("policy_value", true):
		state = "filtered"
	for policy in service.get("required_policies", {}):
		if _world.policies.get(policy) != service.required_policies[policy]:
			state = "filtered"
	var result: Dictionary = _result(state == "open", "SERVICE_OPEN" if state == "open" else "SERVICE_" + state.to_upper(), host.domain + ":" + port + " " + state)
	result["state"] = state
	result["protocol"] = service.get("protocol", "unknown")
	return result


func _has_session(host_id: String, account_id: String) -> bool:
	for stack in _world.terminals.values():
		for session in stack:
			if session.host_id == host_id and session.account_id == account_id:
				return true
	return _web_identity(host_id).get("account_id", "") == account_id


func _managed_session_id(host_id: String, account: String) -> String:
	for id in _definition.challenges:
		var challenge: Dictionary = _definition.challenges[id]
		if challenge.kind == "session" and challenge.get("host_id", "") == host_id and challenge.get("account_id", "") == account:
			return id
	return ""


func _web_identity(host_id: String) -> Dictionary:
	var session: Dictionary = _world.web_sessions.get(host_id, {})
	if session.is_empty():
		return {}
	var transport: Dictionary = _service(host_id, "443", "local")
	if not transport.ok or transport.get("protocol", "") != "https":
		return {}
	var id: String = _managed_session_id(host_id, str(session.get("account_id", "")))
	if id.is_empty():
		return session
	var challenge: Dictionary = _definition.challenges[id]
	var state: Dictionary = _world.model_states.get(id, {})
	var token: String = str(session.get("token", ""))
	var tokens: Dictionary = state.get("tokens", {})
	if not tokens.has(token):
		return {}
	var strict: bool = _world.policies.get(challenge.policy_id, false) == true
	if strict and (tokens[token].get("revoked", false) or int(tokens[token].get("expires_at", 0)) <= int(state.get("tick", 0)) or token == challenge.get("stale_token", "")):
		return {}
	return session


func _requirements(definition: Dictionary) -> Dictionary:
	for fact in definition.get("requires_facts", []):
		if not _world.facts.has(fact):
			return _result(false, "MISSING_EVIDENCE", "Required evidence has not been obtained: " + str(fact))
	var session: Dictionary = definition.get("requires_session", {})
	if not session.is_empty() and not _has_session(session.get("host_id", ""), session.get("account_id", "")):
		return _result(false, "AUTH_REQUIRED", "Required virtual session is not active.")
	return _result(true, "OK", "")


func use_challenge(id: String, input: Variant, account: String = "") -> Dictionary:
	if not _definition.challenges.has(id):
		return _result(false, "UNKNOWN_TOOL", "Unknown challenge.")
	if not _json_value(input, 8):
		return _result(false, "INVALID_ARGUMENTS", "Tool input must contain bounded JSON values only.")
	input = _normalize_numbers(input)
	var challenge: Dictionary = _definition.challenges[id]
	var required: Dictionary = _requirements(challenge)
	if not required.ok:
		return required
	var subject_host: String = str(challenge.get("host_id", challenge.get("requires_session", {}).get("host_id", "")))
	var identity: String = account
	if identity.is_empty() and _session().host_id == subject_host and subject_host != "local":
		identity = _session().account_id
	var web_identity: Dictionary = _web_identity(subject_host)
	if identity.is_empty() and not web_identity.is_empty():
		identity = web_identity.account_id
	if challenge.has("requires_session") and identity != challenge.requires_session.get("account_id", ""):
		return _result(false, "AUTH_REQUIRED", "The acting account does not match this session boundary.")
	if challenge.kind in ["query", "render", "path", "exec", "idor", "session", "csrf", "upload", "auth"] and not subject_host.is_empty():
		var web_service: Dictionary = _service(subject_host, "443", subject_host)
		if not web_service.ok or web_service.get("protocol", "") != "https":
			return _result(false, "SERVICE_UNAVAILABLE", "The target HTTPS service is unavailable.")
	if challenge.kind == "fetch":
		var target: Dictionary = _page_url(str(input))
		if not target.ok:
			return _result(false, target.code, target.text)
		var address: String = str(target.url).get_slice("://", 1).get_slice("/", 0)
		var target_id: String = _host(address)
		var source_id: String = subject_host if not subject_host.is_empty() else str(_session().host_id)
		var port := "443" if str(target.url).begins_with("https:") else "80"
		var service: Dictionary = _service(target_id, port, source_id)
		if not service.ok:
			return _result(false, service.code, service.text)
		var target_page: Dictionary = _definition.pages.get(str(target.url).get_slice("?", 0), {})
		var target_access: Dictionary = _requirements(target_page)
		if not target_access.ok:
			return target_access
	var before: Dictionary = _world.model_states.get(id, {})
	if _world.model_actions.get(id, []).size() >= 128:
		return _result(false, "OBSERVATION_LIMIT", "Restart this case to clear its experiment history.")
	var observed: Dictionary
	if challenge.kind == "auth":
		observed = _auth_model(challenge, input, before)
	else:
		observed = Models.apply_challenge(_model_definition(challenge), input, _world.policies, before, identity)
	return _commit_model(id, input, identity, observed)


func _commit_model(id: String, input: Variant, identity: String, observed: Dictionary) -> Dictionary:
	if not observed.ok:
		return _result(false, observed.code, observed.text)
	var challenge: Dictionary = _definition.challenges[id]
	var before: Dictionary = _world.model_states.get(id, {})
	var subject_host: String = str(challenge.get("host_id", challenge.get("requires_session", {}).get("host_id", "")))
	if _world.model_actions.get(id, []).size() >= 128:
		return _result(false, "OBSERVATION_LIMIT", "Restart this case to clear its experiment history.")
	observed.state["solved"] = bool(before.get("solved", false)) or bool(observed.solved)
	_world.model_states[id] = observed.state
	if challenge.kind == "session" and input is Dictionary and not subject_host.is_empty():
		var action: String = str(input.get("action", ""))
		var token: String = str(input.get("token", "new-session"))
		if action == "issue" or (action == "reuse" and observed.get("status", 403) == 200):
			_world.web_sessions[subject_host] = {"account_id": identity, "token": token}
		elif action == "revoke" and _world.web_sessions.get(subject_host, {}).get("token", "") == token:
			_world.web_sessions.erase(subject_host)
	if not _world.model_actions.has(id):
		_world.model_actions[id] = []
	var receipt: Variant = _normalize_numbers(input)
	if challenge.kind == "auth" and receipt is Dictionary and receipt.get("action", "login") == "login":
		var username: String = str(receipt.get("username", ""))
		var accounts: Dictionary = _definition.hosts[subject_host].accounts
		if not accounts.has(username) or str(receipt.get("password", "")) != accounts[username].password:
			var invalid_password := "__incorrect_game_password__"
			while accounts.has(username) and invalid_password == accounts[username].password:
				invalid_password += "_"
			receipt["password"] = invalid_password
	_world.model_actions[id].append({"input": receipt, "account": identity, "policies": _world.policies.duplicate(true)})
	if challenge.kind == "auth" and input is Dictionary and input.get("action", "login") == "login" and observed.get("status", 401) == 200:
		var opened: Dictionary = _open_web_identity(subject_host, str(input.get("username", "")))
		if not opened.ok:
			return opened
	if challenge.kind == "policy" and observed.solved:
		_world.policies[challenge.policy_id] = observed.state.policy_value
	if challenge.kind == "permission" and observed.solved:
		_world.permission_grants[challenge.host_id + ":" + challenge.account_id] = [challenge.group]
	if observed.solved:
		var record: Dictionary = _definition.records[challenge.record_id]
		var entry: Dictionary = _entry("file", "600", record.content)
		entry.record_id = challenge.record_id
		entry.source = challenge.source
		var already_archived := false
		for existing in _world.local_files.values():
			if existing.get("record_id", "") == entry.record_id and existing.get("content", "") == entry.content and existing.get("source", "") == entry.source:
				already_archived = true
		if not already_archived:
			_archive(entry, challenge.record_id + ".txt", "/home/player/archive")
	_evaluate_completion()
	var result: Dictionary = _result(true, observed.code, observed.text, true, "tool_observed")
	result["status"] = observed.get("status", 200)
	result["solved"] = observed.solved
	return result


func _open_web_identity(host_id: String, account: String) -> Dictionary:
	var id: String = _managed_session_id(host_id, account)
	if id.is_empty():
		_world.web_sessions[host_id] = {"account_id": account, "token": "session-" + account}
		return _result(true, "WEB_AUTHENTICATED", account, true)
	var token: String = "session-" + account + "-" + str(_world.model_actions.get(id, []).size() + 1)
	var input: Dictionary = {"action": "issue", "token": token}
	var observed: Dictionary = Models.apply_challenge(_model_definition(_definition.challenges[id]), input, _world.policies, _world.model_states.get(id, {}), account)
	return _commit_model(id, input, account, observed)


func _auth_model(challenge: Dictionary, input: Variant, previous: Dictionary) -> Dictionary:
	if not input is Dictionary or not _definition.hosts.has(challenge.get("host_id", "")):
		return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "Provide login/wait action and configured host."}
	var state: Dictionary = previous.duplicate(true)
	var strict: bool = _world.policies.get(challenge.get("policy_id", ""), false) == true
	var status := 200
	if not input.get("action", "login") in ["login", "wait"]:
		return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "Authentication action must be login or wait."}
	var username: String = str(input.get("username", challenge.get("account_id", "")))
	var users: Dictionary = state.get("users", {})
	var user_state: Dictionary = users.get(username, {"attempts": 0, "remaining": 0})
	if input.get("action", "login") == "wait":
		var ticks: Variant = input.get("ticks", 0)
		if not _integer(ticks, 1, 32):
			return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "wait ticks must be 1–32."}
		user_state.remaining = maxi(0, int(user_state.remaining) - int(ticks))
		if user_state.remaining == 0:
			user_state.attempts = 0
	else:
		if not input.get("username") is String or not input.get("password") is String:
			return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "Login requires string username and password."}
		var accounts: Dictionary = _definition.hosts[challenge.host_id].accounts
		if strict and int(user_state.remaining) > 0:
			status = 429
			state["limit_observed"] = true
		elif not accounts.has(username) or str(input.get("password", "")) != accounts[username].password:
			status = 401
			user_state.attempts = int(user_state.attempts) + 1
			if strict and user_state.attempts >= int(challenge.get("limit", 2)):
				user_state.remaining = int(challenge.get("cooldown", 2))
		else:
			if strict and username == challenge.get("account_id", ""):
				state["normal_allowed"] = true
			user_state.attempts = 0
	users[username] = user_state
	state["users"] = users
	state["blocked"] = strict and int(user_state.remaining) > 0
	return {"ok": true, "code": "MODEL_OBSERVED", "text": "Authentication status " + str(status) + " / attempts " + str(user_state.attempts) + " / wait " + str(user_state.remaining), "state": state, "status": status, "solved": strict and state.get("limit_observed", false) and state.get("normal_allowed", false)}


func _model_definition(challenge: Dictionary) -> Dictionary:
	var definition: Dictionary = challenge.duplicate(true)
	if challenge.kind == "query":
		var rows: Array = []
		for id in _definition.records:
			if str(id).ends_with("_BASELINE") or _definition.records[id].get("public", false):
				rows.append({"record_id": id, "content": _definition.records[id].content, "restricted": false})
		if rows.is_empty():
			rows.append({"record_id": "public_catalog", "content": "public catalog", "restricted": false})
		rows.append({"record_id": challenge.record_id, "content": _definition.records[challenge.record_id].content, "restricted": true})
		definition["_query_rows"] = rows
	if challenge.kind == "idor":
		var contents: Dictionary = {}
		for object in challenge.get("objects", {}).values():
			if _definition.records.has(object.get("record_id", "")):
				contents[object.record_id] = _definition.records[object.record_id].content
		definition["_object_contents"] = contents
	if challenge.has("run_as"):
		var host: String = challenge.get("host_id", challenge.get("requires_session", {}).get("host_id", ""))
		definition["_execution_groups"] = _definition.hosts[host].accounts[challenge.run_as].groups
	return definition


func request_page(method: String, url: String, body: Dictionary = {}, headers: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _page_url(url)
	if not normalized.ok:
		return _web_error(normalized.code, normalized.text, 400, url)
	var base: String = normalized.url.get_slice("?", 0)
	var browser_context: bool = headers.get("X-Packet-Context", "terminal") == "browser"
	var transport_origin: String = "local" if browser_context else str(_session().host_id)
	var host_id := ""
	for id in _definition.hosts:
		if base.get_slice("://", 1).get_slice("/", 0) == _definition.hosts[id].domain:
			host_id = id
	if not host_id.is_empty():
		var reachable: Dictionary = _service(host_id, "443" if base.begins_with("https:") else "80", transport_origin)
		if not reachable.ok:
			return _web_error(reachable.code, reachable.text, 503, url)
		if reachable.get("protocol", "") != ("https" if base.begins_with("https:") else "http"):
			return _web_error("PROTOCOL_MISMATCH", "The open port is not the requested HTTP service.", 503, url)
	if base.ends_with("/login") and method.to_upper() == "POST" and not host_id.is_empty():
		var accounts: Dictionary = _definition.hosts[host_id].accounts
		var username: String = str(body.get("username", ""))
		var auth_id := ""
		for id in _definition.challenges:
			var challenge: Dictionary = _definition.challenges[id]
			if challenge.kind == "auth" and challenge.get("host_id", "") == host_id:
				auth_id = id
				break
		var login_status := 200
		if not auth_id.is_empty():
			var attempt: Dictionary = {"action": "login", "username": body.get("username"), "password": body.get("password")}
			var challenge: Dictionary = _definition.challenges[auth_id]
			var observed: Dictionary = _auth_model(challenge, attempt, _world.model_states.get(auth_id, {}))
			var committed: Dictionary = _commit_model(auth_id, attempt, "", observed)
			if not committed.ok:
				return _web_error(committed.code, committed.text, 400, url)
			login_status = int(committed.get("status", 401))
		elif not accounts.has(username) or not body.get("password") is String or body.password != accounts[username].password:
			login_status = 401
		else:
			var opened: Dictionary = _open_web_identity(host_id, username)
			if not opened.ok:
				return _web_error(opened.code, opened.text, 400, url)
		if login_status != 200:
			_denied("AUTH_DENIED", "Virtual credentials rejected.")
			var denied: Dictionary = _web_error("AUTH_DENIED", "Virtual authentication status " + str(login_status), login_status, url)
			denied.changed = true
			return denied
		var logged_in: Dictionary = _web_error("WEB_AUTHENTICATED", "Authenticated as " + username, 200, url)
		logged_in.actor = username
		logged_in["actor_context"] = "web"
		logged_in.cookie_preview = _world.web_sessions[host_id].token
		logged_in.headers = {"Set-Cookie": "packet_session=" + str(logged_in.cookie_preview)}
		logged_in.route = ["local", host_id]
		logged_in.trace = [{"method": "POST", "status": 200, "host_id": host_id, "actor": username}]
		logged_in.changed = true
		return logged_in
	if base.ends_with("/logout"):
		if method.to_upper() != "POST":
			return _web_error("INVALID_METHOD", "Logout requires POST.", 405, url)
		var token: String = str(_world.web_sessions.get(host_id, {}).get("token", ""))
		for id in _definition.challenges:
			var challenge: Dictionary = _definition.challenges[id]
			if challenge.kind == "session" and challenge.get("host_id", "") == host_id and _world.model_states.get(id, {}).get("tokens", {}).has(token):
				use_challenge(id, {"action": "revoke", "token": token})
		_world.web_sessions.erase(host_id)
		var logged_out: Dictionary = _web_error("WEB_LOGGED_OUT", "Session revoked.", 200, url)
		logged_out.changed = true
		return logged_out
	if not _definition.pages.has(base):
		return _web_error("UNKNOWN_URL", "No internal route.", 404, url)
	var page: Dictionary = _definition.pages[base]
	if page.has("host_id") and page.host_id != host_id:
		return _web_error("ROUTE_HOST_MISMATCH", "Page host does not match its route.", 503, url)
	var allowed: Dictionary = _requirements(page)
	if not allowed.ok:
		return _web_error(allowed.code, allowed.text, 403, url)
	var response: Dictionary = _web_error("OK", _tr(page.body), 200, url)
	response.title = _tr(page.title)
	response.links = page.links.duplicate(true)
	for link in response.links:
		link.label = _tr(link.label)
	response.can_archive = page.has("record_id")
	var active_web: Dictionary = _web_identity(host_id)
	var actor: String = active_web.get("account_id", "anonymous")
	var actor_context := "web"
	if not browser_context and _session().host_id == host_id and host_id != "local":
		actor = _session().account_id
		actor_context = "terminal"
	elif not browser_context and page.has("requires_session") and _session().host_id == page.requires_session.get("host_id", "") and _session().account_id == page.requires_session.get("account_id", ""):
		actor = _session().account_id
		actor_context = "terminal"
	if page.has("requires_session") and actor != page.requires_session.get("account_id", ""):
		_denied("AUTH_REQUIRED", "Authenticated actor required.")
		var denied: Dictionary = _web_error("AUTH_REQUIRED", "The acting request requires an authenticated account.", 401, url)
		denied.changed = true
		return denied
	response["actor"] = actor
	response["actor_context"] = actor_context
	var source_origin: String = "https://local.packet.test" if transport_origin == "local" else "https://" + str(_definition.hosts[transport_origin].domain)
	response["source_origin"] = headers.get("Origin", source_origin)
	response["route"] = [transport_origin, host_id]
	response["cookie_preview"] = active_web.get("token", "") if actor_context == "web" else ""
	if page.has("challenge_id"):
		var challenge: Dictionary = _definition.challenges[page.challenge_id]
		if method.to_upper() == "GET" and body.is_empty() and not url.contains("?"):
			return response
		if challenge.kind in ["csrf", "upload", "policy", "session", "auth", "exec", "permission", "memory", "render"] and not method.to_upper() in ["POST", "PUT", "PATCH"]:
			return _web_error("INVALID_METHOD", "This virtual operation requires a state-changing method.", 405, url)
		var parameters: Dictionary = body.duplicate(true)
		if url.contains("?"):
			for pair in url.get_slice("?", 1).split("&"):
				var parts: PackedStringArray = pair.split("=", true, 1)
				parameters[parts[0].uri_decode()] = parts[1].uri_decode() if parts.size() > 1 else ""
		var input: Variant = parameters.get("input", parameters.get(challenge.get("parameter", "q"), parameters))
		if challenge.kind == "csrf" and input is Dictionary and headers.has("Origin"):
			input["origin"] = headers.Origin
		elif challenge.kind == "csrf" and input is Dictionary:
			response.source_origin = input.get("origin", response.source_origin)
		var observation: Dictionary = use_challenge(page.challenge_id, input, str(response.actor) if response.actor != "anonymous" else "")
		response.ok = observation.ok
		response.code = observation.code
		response.status = observation.get("status", 400 if not observation.ok else 200)
		response.body = observation.text
		response.text = observation.text
		response["changed"] = observation.get("changed", false)
	response.trace = [{"method": method.to_upper(), "status": response.status, "host_id": host_id, "actor": response.actor, "origin": response.source_origin}]
	return response


func collect_page(url: String) -> Dictionary:
	var response: Dictionary = request_page("GET", url, {}, {"X-Packet-Context": "browser"})
	if not response.ok or response.status != 200:
		return _result(false, response.code, response.body)
	var base: String = str(response.url).get_slice("?", 0)
	var page: Dictionary = _definition.pages.get(base, {})
	if not page.has("record_id"):
		return _result(false, "NO_RECORD", "This page has no collectible record.")
	var record: Dictionary = _definition.records[page.record_id]
	var entry: Dictionary = _entry("file", "600", record.content)
	entry.record_id = page.record_id
	entry.source = page.source
	return _archive(entry, page.filename, "/home/player/archive")


func _web_error(code: String, text: String, status: int, url: String) -> Dictionary:
	var shown: String = _result(status < 400, code, text).text
	return {"ok": status < 400, "code": code, "text": shown, "changed": false, "status": status, "headers": {}, "title": code, "body": shown, "links": [], "can_archive": false, "url": url, "trace": [], "actor": "anonymous", "source_origin": "https://local.packet.test", "route": [], "cookie_preview": ""}


func _page_url(url: String) -> Dictionary:
	var value: String = url.strip_edges()
	if value.length() > 2048 or value.contains("@") or value.contains("\\"):
		return {"ok": false, "code": "EXTERNAL_URL", "text": "Only registered virtual HTTP(S) .test addresses are supported."}
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return {"ok": false, "code": "EXTERNAL_URL", "text": "Control characters are not valid in a virtual URL."}
	value = value.get_slice("#", 0)
	var base: String = value.get_slice("?", 0)
	if not (base.begins_with("https://") or base.begins_with("http://")):
		return {"ok": false, "code": "EXTERNAL_URL", "text": "Unsupported virtual URL scheme."}
	var authority: String = base.get_slice("://", 1).get_slice("/", 0)
	if not authority.ends_with(".test") or authority.contains(":"):
		return {"ok": false, "code": "EXTERNAL_URL", "text": "External domains and explicit ports are outside this browser subset."}
	while base.ends_with("/"):
		base = base.trim_suffix("/")
	return {"ok": true, "url": base + ("?" + value.get_slice("?", 1) if value.contains("?") else "")}


func _extra(command: String, args: Array) -> Dictionary:
	match command:
		"man":
			return _help(args)
		"whoami":
			return _result(true, "OK", _session().account_id) if args.is_empty() else _usage("whoami")
		"id", "sudo":
			if command == "sudo" and args != ["-l"]:
				return _usage("sudo -l")
			if command == "id" and not args.is_empty():
				return _usage("id")
			return _result(true, "OK", "user=" + _session().account_id + " groups=" + ",".join(_groups()))
		"nmap", "scan", "dig", "ping", "traceroute", "route", "pivot":
			if not (args.size() == 1 or (command in ["nmap", "scan"] and args.size() == 2 and args[0] == "-sV")) or str(args[-1]).begins_with("-"):
				return _usage(command + (" [-sV] host" if command in ["nmap", "scan"] else " host"))
			var target: String = str(args[-1]) if not args.is_empty() else ""
			var id: String = _host(target)
			if id.is_empty():
				return _result(false, "HOST_NOT_FOUND", "Specify a registered virtual host.")
			var lines: Array[String] = []
			for port in _definition.hosts[id].services:
				var service: Dictionary = _service(id, str(port), _session().host_id)
				lines.append(port + "/" + str(service.get("protocol", "unknown")) + " " + str(service.get("state", "filtered")))
			var discovered: bool = not _world.discovered.has(id)
			if discovered:
				_world.discovered.append(id)
			return _result(true, "OK", _session().host_id + " → " + id + " / " + _definition.hosts[id].address + "\n" + "\n".join(lines), discovered)
		"curl", "wget":
			if args.is_empty():
				return _usage(command + " URL")
			var method := "GET"
			var body: Dictionary = {}
			var url := ""
			var index := 0
			while index < args.size():
				if args[index] == "-i":
					index += 1
					continue
				if args[index] in ["-X", "-d"]:
					if index + 1 >= args.size():
						return _usage("curl [-X METHOD] [-d JSON] URL")
					if args[index] == "-X":
						method = args[index + 1]
					else:
						var parsed: Variant = JSON.parse_string(args[index + 1])
						if not parsed is Dictionary:
							return _usage("curl -d JSON-object URL")
						body = parsed
					index += 2
					continue
				if str(args[index]).begins_with("-") or not url.is_empty():
					return _usage("curl [-X METHOD] [-d JSON] URL")
				url = args[index]
				index += 1
			if command == "wget":
				return collect_page(url)
			var response: Dictionary = request_page(method, url, body)
			return _result(response.ok, response.code, "HTTP " + str(response.status) + "\n" + str(response.body), response.changed)
		"configure":
			if args.size() != 2 or not _world.policies.has(str(args[0])):
				return _usage("configure policyID value")
			var value: Variant = JSON.parse_string(args[1])
			if value == null:
				value = args[1]
			if not _policy_allowed(str(args[0]), value):
				return _result(false, "INVALID_POLICY", "Unsupported policy value.")
			_world.policies[args[0]] = value
			return _result(true, "POLICY_CHANGED", str(args[0]) + "=" + str(value), true)
		"tool":
			if args.is_empty() or args.size() > 2:
				return _usage("tool challengeID 'input or JSON'")
			var input: Variant = args[1] if args.size() == 2 else ""
			if input is String and (input.begins_with("{") or input.begins_with("[")):
				input = JSON.parse_string(input)
			return use_challenge(args[0], input)
		"grep", "strings", "xxd", "decode", "find", "cp", "mv", "mkdir", "rm":
			return _file_command(command, args)
	return _result(false, "UNKNOWN_COMMAND", "Unsupported command. help lists the Linux subset.")


func _file_command(command: String, args: Array) -> Dictionary:
	if args.is_empty():
		return _usage(command + " arguments")
	if not command in ["grep", "find"] and str(args[0]).begins_with("-"):
		return _usage(command + " positional-arguments")
	if command == "find":
		var start: Dictionary = FS.normalize(str(args[0]), _session().cwd, _home())
		if not start.ok or not FS.access(_files(), start.get("path", "/"), _session().account_id, _groups(), "list").ok:
			return _result(false, "PERMISSION_DENIED", "Search root is not readable.")
		if args.size() != 1 and not (args.size() == 3 and args[1] == "-name"):
			return _usage("find path [-name pattern]")
		var lines: Array[String] = []
		for path in _files():
			if (path == start.path or str(path).begins_with(start.path.trim_suffix("/") + "/")) and FS.access(_files(), path, _session().account_id, _groups(), "stat").ok and (args.size() == 1 or str(path).get_file().match(str(args[2]))):
				lines.append(path)
		return _result(true, "OK", "\n".join(lines))
	var path_arg: String = str(args[-1]) if command == "grep" else str(args[0])
	var resolved: Dictionary = FS.normalize(path_arg, _session().cwd, _home())
	if not resolved.ok:
		return _result(false, resolved.code, resolved.text)
	if command in ["mkdir", "rm", "mv"]:
		if _session().host_id != "local":
			return _result(false, "PERMISSION_DENIED", "Remote originals must be preserved.")
		if not resolved.path.begins_with("/home/player/"):
			return _result(false, "PERMISSION_DENIED", "Only the virtual player home is writable.")
		var files: Dictionary = _world.local_files
		if not FS.access(files, resolved.path.get_base_dir(), "player", ["player"], "write_dir").ok:
			return _result(false, "PERMISSION_DENIED", "Parent directory is not writable.")
		if command == "mkdir":
			if args.size() != 1 or files.has(resolved.path):
				return _usage("mkdir new-path")
			files[resolved.path] = _entry("dir", "700")
		elif not files.has(resolved.path) or files[resolved.path].kind != "file":
			return _result(false, "NOT_FOUND", "Specify an existing local file.")
		elif command == "rm":
			if args.size() != 1:
				return _usage("rm file")
			files.erase(resolved.path)
		else:
			if args.size() != 2:
				return _usage("mv source destination")
			var destination: Dictionary = FS.normalize(args[1], _session().cwd, _home())
			if not destination.ok or not str(destination.get("path", "")).begins_with("/home/player/") or files.has(destination.get("path", "")) or not FS.access(files, str(destination.get("path", "/")).get_base_dir(), "player", ["player"], "write_dir").ok:
				return _result(false, "PERMISSION_DENIED", "Destination is not writable or already exists.")
			files[destination.path] = files[resolved.path]
			files.erase(resolved.path)
		return _result(true, "FILES_CHANGED", resolved.path, true)
	var checked: Dictionary = FS.access(_files(), resolved.path, _session().account_id, _groups(), "read")
	if not checked.ok or checked.entry.get("kind", "") != "file":
		return _result(false, checked.get("code", "IS_DIRECTORY"), checked.get("text", "Specify a file."))
	if command == "cp":
		if args.size() != 2:
			return _usage("cp source local-destination")
		var destination: Dictionary = FS.normalize(str(args[1]), "/home/player", "/home/player")
		if not destination.ok:
			return _result(false, destination.code, destination.text)
		return _archive(checked.entry, resolved.path.get_file(), destination.path)
	var content: String = checked.entry.content
	if command == "grep":
		var values: Array = args.duplicate()
		var ignore := false
		var numbered := false
		while not values.is_empty() and str(values[0]).begins_with("-"):
			if not values[0] in ["-n", "-i", "-F"]:
				return _usage("grep [-n|-i|-F] text file")
			var option: String = str(values.pop_front())
			ignore = ignore or option == "-i"
			numbered = numbered or option == "-n"
		if values.size() != 2:
			return _usage("grep [-n|-i|-F] text file")
		var matches: Array[String] = []
		var number := 0
		for line in content.split("\n"):
			number += 1
			if (line.to_lower() if ignore else line).contains(str(values[0]).to_lower() if ignore else str(values[0])):
				matches.append(str(number) + ":" + line if numbered else line)
		return _result(true, "OK", "\n".join(matches))
	if command == "xxd":
		return _result(true, "OK", content.to_utf8_buffer().hex_encode())
	if command == "decode":
		var bytes: PackedByteArray = Marshalls.base64_to_raw(content.strip_edges())
		return _result(true, "OK", bytes.get_string_from_utf8())
	return _result(true, "OK", content)


func _help(args: Array) -> Dictionary:
	if args.is_empty():
		return _result(true, "OK", _tr("CAMPAIGN_HELP_OVERVIEW").format({"commands": ", ".join(COMMANDS + EXTRA_COMMANDS)}))
	if args.size() != 1 or not (COMMANDS + EXTRA_COMMANDS).has(args[0]):
		return _usage("help [registered-command]")
	var syntax: Dictionary = {
		"help": "help [command]", "man": "man [command]", "ssh": "ssh account@host", "exit": "exit", "ls": "ls [-l] [path]", "cd": "cd [path]", "pwd": "pwd", "cat": "cat path", "scp": "scp source [local-destination]",
		"whoami": "whoami", "id": "id", "sudo": "sudo -l", "grep": "grep [-n|-i|-F] literal file", "find": "find path [-name pattern]", "mkdir": "mkdir path", "cp": "cp source local-destination", "mv": "mv local-source local-destination", "rm": "rm local-file",
		"nmap": "nmap [-sV] host", "scan": "scan [-sV] host", "dig": "dig host", "ping": "ping host", "traceroute": "traceroute host", "route": "route host", "pivot": "pivot host", "curl": "curl [-i] [-X METHOD] [-d JSON] URL", "wget": "wget URL",
		"strings": "strings file", "xxd": "xxd file", "decode": "decode base64-file", "configure": "configure policyID value", "tool": "tool challengeID 'input or JSON'",
	}
	return _result(true, "OK", _tr("CAMPAIGN_HELP_COMMAND").format({"command": syntax.get(args[0], args[0])}))


func _policy_allowed(id: String, value: Variant) -> bool:
	if not _definition.policies.has(id):
		return false
	if _definition.policies[id] is bool:
		return value is bool
	for challenge in _definition.challenges.values():
		if challenge.get("policy_id", "") == id and challenge.get("values", []).has(value):
			return true
	return value == _definition.policies[id]


func snapshot_world() -> Dictionary:
	var copy: Dictionary = _world.duplicate(true)
	copy.erase("sessions")
	return copy


func checkpoint() -> Dictionary:
	return {"world": snapshot_world(), "terminal": _terminal, "pending": _pending.duplicate(true), "authentication": _authentication.duplicate(true)}


func rollback(saved: Dictionary) -> void:
	_terminal = saved.terminal
	_world = saved.world.duplicate(true)
	_world["sessions"] = _world.terminals[str(_terminal)]
	_pending = saved.pending.duplicate(true)
	_authentication = saved.authentication.duplicate(true)


func complete(input: String, terminal_id: int = 0) -> PackedStringArray:
	if terminal_id < 0 or terminal_id > 3:
		return PackedStringArray()
	var previous_terminal: int = _terminal
	var previous_sessions: Array = _world.sessions
	var previous_pending: Dictionary = _pending
	_terminal = terminal_id
	_world.sessions = _world.terminals.get(str(terminal_id), [{"host_id": "local", "account_id": "player", "cwd": "/home/player"}])
	_pending = previous_pending if terminal_id == previous_terminal else _authentication.get(str(terminal_id), {})
	var choices := PackedStringArray()
	if _pending.is_empty():
		if not input.contains(" "):
			for command in COMMANDS + EXTRA_COMMANDS:
				if str(command).begins_with(input):
					choices.append(command)
		else:
			choices = super.autocomplete(input)
	_terminal = previous_terminal
	_world.sessions = previous_sessions
	_pending = previous_pending
	return choices


func validate_world(raw: Variant) -> Dictionary:
	var expected_keys: Array = snapshot_world().keys()
	if not raw is Dictionary or raw.size() != expected_keys.size() or not raw.has_all(expected_keys) or not _json_value(raw):
		return _invalid("Invalid campaign world shape.")
	var world: Dictionary = _normalize_numbers(raw)
	for key in ["remote_files", "local_files", "terminals", "policies", "model_states", "model_actions", "web_sessions", "permission_grants"]:
		if not world[key] is Dictionary:
			return _invalid("Invalid world container: " + key)
	for key in ["facts", "replies", "discovered", "observations"]:
		if not world[key] is Array or world[key].size() > 512:
			return _invalid("Invalid world list: " + key)
	if not world.completed is bool or not _integer(world.alert_level, 0, _definition.alert_max):
		return _invalid("Invalid progress/alert type.")
	if not world.terminals.has("0") or not world.terminals["0"] is Array or world.terminals["0"].is_empty():
		return _invalid("Missing local terminal base.")
	for host in world.remote_files:
		if not _definition.hosts.has(host) or not world.remote_files[host] is Dictionary:
			return _invalid("Unknown/invalid remote host.")
		for entry in world.remote_files[host].values():
			if not entry is Dictionary or not entry.has_all(["kind", "owner", "group", "mode", "content", "record_id", "source"]):
				return _invalid("Invalid remote entry.")
	for state in world.model_states.values():
		if not state is Dictionary:
			return _invalid("Invalid model state.")
	if world.policies.size() != _definition.policies.size():
		return _invalid("Policy keys differ.")
	for id in world.policies:
		if not _policy_allowed(id, world.policies[id]):
			return _invalid("Invalid policy value.")
	apply_world(world)
	if not _sources_preserved():
		return _invalid("Canonical remote files changed.")
	for host_files in world.remote_files.values():
		for entry in host_files.values():
			var mode: String = str(entry.get("mode", ""))
			if mode.length() != 3 or not mode[0] in "01234567" or not mode[1] in "01234567" or not mode[2] in "01234567":
				return _invalid("Invalid permission mode.")
	var base: Dictionary = _initial_local_files()
	if world.local_files.size() > 512:
		return _invalid("Local file count exceeded.")
	for path in base:
		if world.local_files.get(path) != base[path]:
			return _invalid("Local base folders changed.")
	for path in world.local_files:
		var entry: Variant = world.local_files[path]
		var normalized: Dictionary = FS.normalize(path)
		if not entry is Dictionary or not normalized.ok or normalized.path != path or not entry.has_all(["kind", "owner", "group", "mode", "content", "record_id", "source"]):
			return _invalid("Invalid local file entry.")
		if base.has(path):
			continue
		if entry.size() != 7:
			return _invalid("Unknown local entry fields.")
		if not str(path).begins_with("/home/player/") or not world.local_files.has(str(path).get_base_dir()) or world.local_files[str(path).get_base_dir()].kind != "dir" or entry.owner != "player" or entry.group != "player":
			return _invalid("Invalid local path/owner.")
		if entry.kind == "dir":
			if entry != _entry("dir", "700"):
				return _invalid("Invalid local directory.")
		elif entry.kind != "file" or entry.mode != "600" or not _known_source(entry):
			return _invalid("Record body/ID/source mismatch.")
	if world.model_states.keys().size() != world.model_actions.keys().size() or not world.model_actions.has_all(world.model_states.keys()):
		return _invalid("Model receipt mismatch.")
	var original_policies: Dictionary = world.policies.duplicate(true)
	var original_web: Dictionary = world.web_sessions.duplicate(true)
	for id in world.model_actions:
		if not _definition.challenges.has(id) or not world.model_actions[id] is Array or world.model_actions[id].is_empty() or world.model_actions[id].size() > 128:
			return _invalid("Unknown or oversized model history.")
		var state: Dictionary = {}
		var challenge: Dictionary = _definition.challenges[id]
		for action in world.model_actions[id]:
			if not action is Dictionary or not action.has_all(["input", "account", "policies"]) or not action.account is String or not action.policies is Dictionary or action.policies.size() != original_policies.size():
				return _invalid("Malformed model observation.")
			for policy in action.policies:
				if not _policy_allowed(policy, action.policies[policy]):
					return _invalid("Invalid observed policy.")
			_world.policies = action.policies.duplicate(true)
			var result: Dictionary = _auth_model(challenge, action.input, state) if challenge.kind == "auth" else Models.apply_challenge(_model_definition(challenge), action.input, action.policies, state, action.account)
			if not result.ok:
				return _invalid("Impossible model observation.")
			result.state["solved"] = state.get("solved", false) or result.solved
			state = result.state
		if not state.recursive_equal(world.model_states[id], 0):
			return _invalid("Computed model state differs from receipts.")
	_world.policies = original_policies
	_world.web_sessions = original_web
	var grants: Dictionary = {}
	for id in world.model_states:
		var challenge: Dictionary = _definition.challenges[id]
		if challenge.kind == "permission" and world.model_states[id].get("solved", false):
			grants[challenge.host_id + ":" + challenge.account_id] = [challenge.group]
	if grants != world.permission_grants:
		return _invalid("Permission grants have no valid proof.")
	if not world.terminals.has("0") or world.terminals.size() > 4:
		return _invalid("Invalid terminal count.")
	for id in world.terminals:
		if not id in ["0", "1", "2", "3"] or not world.terminals[id] is Array or world.terminals[id].is_empty() or world.terminals[id].size() > 16:
			return _invalid("Invalid terminal stack.")
		var stack: Array = world.terminals[id]
		for index in range(stack.size()):
			var session: Variant = stack[index]
			if not session is Dictionary or session.size() != 3 or not session.has_all(["host_id", "account_id", "cwd"]):
				return _invalid("Invalid session fields.")
			var files: Dictionary = world.local_files
			var groups: Array = ["player"]
			if index == 0:
				if session.host_id != "local" or session.account_id != "player":
					return _invalid("Terminal base must be local.")
			else:
				if not _definition.hosts.has(session.host_id) or not _definition.hosts[session.host_id].accounts.has(session.account_id) or not _service(session.host_id, "22", stack[index - 1].host_id).ok:
					return _invalid("Unknown/unreachable authenticated session.")
				files = world.remote_files[session.host_id]
				groups = _definition.hosts[session.host_id].accounts[session.account_id].groups.duplicate()
				groups.append_array(grants.get(session.host_id + ":" + session.account_id, []))
			var path: Dictionary = FS.normalize(str(session.cwd))
			if not path.ok or path.path != session.cwd or not files.has(session.cwd) or files[session.cwd].kind != "dir" or not FS.access(files, session.cwd, session.account_id, groups, "enter").ok:
				return _invalid("Invalid working directory.")
	for id in world.web_sessions:
		var session: Variant = world.web_sessions[id]
		if not _definition.hosts.has(id) or not session is Dictionary or not session.has_all(["account_id", "token"]) or not _definition.hosts[id].accounts.has(session.account_id) or not session.token is String:
			return _invalid("Invalid web authentication session.")
		var managed: String = _managed_session_id(id, session.account_id)
		if not managed.is_empty():
			if not world.model_states.get(managed, {}).get("tokens", {}).has(session.token):
				return _invalid("Web token has no issuance observation.")
		elif session.token != "session-" + str(session.account_id):
			return _invalid("Unknown web authentication token.")
	for id in world.discovered:
		if not _definition.hosts.has(id):
			return _invalid("Unknown discovered host.")
	var claimed_completed: bool = world.completed
	var claimed_facts: Array = world.facts.duplicate()
	var claimed_replies: Array = world.replies.duplicate()
	_evaluate_completion()
	if _world.completed != claimed_completed or _world.facts != claimed_facts or _world.replies != claimed_replies:
		return _invalid("Progress/facts do not match current goals.")
	return {"ok": true, "world": snapshot_world(), "text": "Validated"}


func _json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 24:
		return false
	if value is Dictionary:
		if value.size() > 512:
			return false
		for key in value:
			if not key is String or not _json_value(value[key], depth + 1):
				return false
		return true
	if value is Array:
		if value.size() > 512:
			return false
		for entry in value:
			if not _json_value(entry, depth + 1):
				return false
		return true
	if value is String:
		return value.length() <= 32768
	return value == null or value is bool or (typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and abs(float(value)) <= 9007199254740991.0)


func _normalize_numbers(value: Variant) -> Variant:
	return Models.normalize_value(value)


func apply_world(world: Dictionary, reset_auth: bool = true) -> void:
	_world = world.duplicate(true)
	_world["sessions"] = _world.terminals.get(str(_terminal), _world.terminals["0"])
	if reset_auth:
		_pending = {}
		_authentication.clear()


func view(terminal_id: int = 0) -> Dictionary:
	if terminal_id < 0 or terminal_id > 3:
		return {"ready": false, "error": "Invalid terminal ID.", "tools": [], "network": [], "archive": [], "messages": [], "files": []}
	var previous_terminal: int = _terminal
	var previous_sessions: Array = _world.sessions
	var previous_pending: Dictionary = _pending
	_terminal = terminal_id
	_world.sessions = _world.terminals.get(str(terminal_id), [{"host_id": "local", "account_id": "player", "cwd": "/home/player"}])
	_pending = previous_pending if terminal_id == previous_terminal else _authentication.get(str(terminal_id), {})
	var network: Array = []
	for id in _definition.hosts:
		if _world.discovered.has(id):
			network.append({"id": id, "name": _tr(_definition.hosts[id].name), "address": _definition.hosts[id].domain, "status": "connected" if _session().host_id == id else "known"})
	var archive: Array = []
	for path in _world.local_files:
		var entry: Dictionary = _world.local_files[path]
		if entry.kind == "file" and str(path).begins_with("/home/player/archive/"):
			var record: Dictionary = _definition.records.get(entry.record_id, {})
			archive.append({"name": str(path).get_file(), "path": path, "content": _tr(record.display_content_key) if record.has("display_content_key") else entry.content, "record_id": entry.record_id, "source": entry.source})
	var messages: Array = [_definition.mail.intro.duplicate(true)]
	if _world.completed:
		messages.append(_definition.mail.complete.duplicate(true))
	for message in messages:
		for key in ["sender", "subject", "body"]:
			message[key] = _tr(message[key])
	var listing: Array = FS.children(_files(), _session().cwd) if FS.access(_files(), _session().cwd, _session().account_id, _groups(), "list").ok else []
	var tools: Array = []
	for id in _definition.challenges:
		var challenge: Dictionary = _definition.challenges[id]
		var data: Dictionary = {}
		for key in ["rows", "encoded", "xor_key", "buffer_size", "memory_size", "base_path", "origin"]:
			if challenge.has(key):
				data[key] = challenge[key]
		var description: String = _tr(challenge.get("explain", ""))
		var required_session: Dictionary = challenge.get("requires_session", {})
		if not required_session.is_empty():
			description += "\n" + _tr(_definition.hosts[required_session.host_id].name) + " / " + str(required_session.account_id)
		tools.append({"id": id, "name": _tr(challenge.get("name", str(challenge.kind).to_upper())), "description": description, "kind": challenge.kind, "data": data, "input_schema": _input_schema(challenge.kind), "usage": _tr(challenge.get("usage", "")), "requirements": challenge.get("requires_facts", []), "required_session": required_session})
	for spec in [{"id": "netprobe", "key": "NETPROBE", "kind": "scan", "field": "target"}, {"id": "traceroute", "key": "TRACEROUTE", "kind": "route", "field": "target"}, {"id": "filelens", "key": "FILELENS", "kind": "file", "field": "path"}, {"id": "loglens", "key": "LOGLENS", "kind": "log", "field": "path"}]:
		tools.append({"id": spec.id, "name": _tr("TOOL_" + spec.key + "_NAME"), "description": _tr("TOOL_" + spec.key + "_DESCRIPTION"), "kind": spec.kind, "data": {"targets": network} if spec.field == "target" else {"files": listing}, "input_schema": [spec.field], "usage": _tr("TOOL_" + spec.key + "_USAGE"), "requirements": []})
	var objectives: Array = []
	for goal in _definition.goals:
		var raw_id: String = str(goal.get("record_id", goal.get("id", goal.get("host_id", ""))))
		objectives.append({"kind": goal.kind, "id": raw_id, "completed": _goal(goal), "display_name": _tr(goal.get("label_display", raw_id)), "target_display": str(goal.get("target_display", ""))})
	var milestones: Array = []
	for milestone in _definition.get("milestones", []):
		milestones.append({"id": milestone.get("id", ""), "title": _tr(milestone.get("title", "")), "text": _tr(milestone.get("text", ""))})
	var result: Dictionary = {"ready": true, "error": "", "terminal_id": _terminal, "terminals": ["0", "1", "2", "3"], "prompt": _session().account_id + "@" + _session().host_id + ":" + _session().cwd + "$", "host": _session().host_id, "user": _session().account_id, "cwd": _session().cwd, "alert_level": _world.alert_level, "alert_max": _definition.alert_max, "completed": _world.completed, "password_pending": not _pending.is_empty(), "mission_id": _definition.mission_id, "mission_title": _tr(_definition.title), "mission_goal": _tr(_definition.get("goal_text", "")), "hint": "", "messages": messages, "archive": archive, "files": listing, "network": network, "browser_home": _definition.initial_web_url, "tools": tools, "policies": _world.policies, "facts": _world.facts, "objectives": objectives, "milestones": milestones}.duplicate(true)
	_terminal = previous_terminal
	_world.sessions = previous_sessions
	_pending = previous_pending
	return result


func _input_schema(kind: String) -> Array:
	match kind:
		"session": return ["action", "token", "ticks"]
		"csrf": return ["origin", "token", "value"]
		"upload": return ["filename", "mime", "signature"]
		"auth": return ["action", "username", "password", "ticks"]
		"idor": return ["object_id"]
		"compare": return ["left", "right"]
	return ["input"]


func _tr(value: Variant) -> String:
	return str(TranslationServer.translate(str(value)))


func _result(ok: bool, code: String, text: String, changed: bool = false, event: String = "") -> Dictionary:
	var key: String = "CAMPAIGN_RESULT_" + code
	var translated: String = _tr(key)
	var detail: String = text
	if code in ["NO_AUTH_PENDING", "NO_CONNECTION", "SESSION_LIMIT", "AUTH_CANCELLED", "ARCHIVE_LIMIT", "EMPTY_INPUT", "AUTH_REQUIRED", "AUTH_DENIED"]:
		detail = ""
	elif code == "CONNECTED":
		detail = _session().account_id + "@" + _session().host_id
	elif code == "MISSING_EVIDENCE":
		detail = text.get_slice(": ", 1)
	var shown: String = translated.format({"detail": detail}) if translated != key else text
	return {"ok": ok, "code": code, "text": shown, "text_key": key, "text_vars": {"detail": detail}, "changed": changed, "needs_password": not _pending.is_empty(), "event": event}
