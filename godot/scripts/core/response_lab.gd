extends RefCounted

const FS = preload("res://scripts/core/virtual_fs.gd")


static func initial_state(definition: Dictionary, previous: Dictionary) -> Dictionary:
	var state: Dictionary = previous.duplicate(true)
	for key in ["probe_receipts", "business_objects", "tokens", "auth_users", "file_overrides", "group_overrides"]:
		state[key] = state.get(key, {})
	state["checkpoints"] = state.get("checkpoints", definition.get("initial_checkpoints", {}).duplicate(true))
	state["checkpoint_seq"] = int(state.get("checkpoint_seq", 0))
	state["tick"] = int(state.get("tick", 0))
	state["revocation_refs"] = state.get("revocation_refs", [])
	state["file_versions"] = state.get("file_versions", [])
	state["artifact_events"] = state.get("artifact_events", [])
	for endpoint in definition.get("bindings", {}).get("endpoints", {}).values():
		for ref in endpoint.get("initial_tokens", {}):
			if not state.tokens.has(ref):
				state.tokens[ref] = endpoint.initial_tokens[ref].duplicate(true)
	return state


static func apply_action(definition: Dictionary, input: Variant, previous: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not input is Dictionary:
		return _error("INVALID_ARGUMENTS", "Select a response action.", previous)
	var state: Dictionary = initial_state(definition, previous)
	var effects: Dictionary = {"policy_updates": {}, "revoke_tokens": []}
	var policies: Dictionary = context.get("policies", {}).duplicate(true)
	var action: String = str(input.get("action", "inspect"))
	var feedback: Dictionary = {}
	match action:
		"inspect": pass
		"set_control":
			var error: String = _set_control(definition, state, policies, effects, str(input.get("control_id", "")), input.get("value"), context)
			if not error.is_empty():
				return _error("INVALID_CONTROL", error, previous)
		"checkpoint":
			var group: String = str(input.get("group", ""))
			if not definition.get("checkpoint_groups", {}).has(group) or state.checkpoints.size() >= 8:
				return _error("INVALID_CHECKPOINT", "Unknown group or checkpoint limit reached.", previous)
			var values: Dictionary = {}
			for id in definition.checkpoint_groups[group]:
				values[id] = _control_value(definition.controls[id], policies, state, context)
			state.checkpoint_seq += 1
			var id: String = "checkpoint_" + str(state.checkpoint_seq)
			state.checkpoints[id] = {"group": group, "values": values}
			feedback["checkpoint_id"] = id
		"rollback":
			var id: String = str(input.get("checkpoint_id", ""))
			var group: String = str(input.get("group", ""))
			if not state.checkpoints.has(id) or state.checkpoints[id].group != group or not definition.get("checkpoint_groups", {}).has(group):
				return _error("INVALID_CHECKPOINT", "Checkpoint does not belong to the selected group.", previous)
			for control_id in definition.checkpoint_groups[group]:
				if not state.checkpoints[id].values.has(control_id):
					return _error("INVALID_CHECKPOINT", "Checkpoint has no value for this control.", previous)
				var error: String = _set_control(definition, state, policies, effects, control_id, state.checkpoints[id].values[control_id], context)
				if not error.is_empty():
					return _error("INVALID_CONTROL", error, previous)
		"revoke":
			var ref: String = str(input.get("token_ref", ""))
			if not state.tokens.has(ref):
				if not context.get("managed_tokens", {}).has(ref):
					return _error("UNKNOWN_TOKEN", "Unknown managed session.", previous)
				state.tokens[ref] = {"managed": true, "revoked": false}
				effects.revoke_tokens.append(ref)
			state.tokens[ref]["revoked"] = true
			if not state.revocation_refs.has(ref):
				state.revocation_refs.append(ref)
		"quarantine":
			var id: Variant = input.get("artifact_id", "")
			var quarantined: Variant = input.get("quarantined", true)
			if not id is String or not quarantined is bool or not state.business_objects.get(id) is Dictionary or not state.business_objects[id].has("filename"):
				return _error("INVALID_ARGUMENTS", "Choose one registered artifact and a quarantine state.", previous)
			state.business_objects[id]["quarantined"] = quarantined
			state.artifact_events.append({"event": "quarantine_changed", "tick": state.tick, "artifact_id": id, "endpoint_id": state.business_objects[id].get("endpoint_id", ""), "quarantined": quarantined})
			feedback = {"artifact_id": id, "quarantined": quarantined}
		"advance":
			var ticks: Variant = input.get("ticks", 0)
			if not typeof(ticks) in [TYPE_INT, TYPE_FLOAT] or ticks != floor(ticks) or ticks < 1 or ticks > 32:
				return _error("INVALID_ARGUMENTS", "Advance requires 1–32 logical ticks.", previous)
			state.tick += int(ticks)
			for user in state.auth_users.values():
				user["remaining"] = maxi(0, int(user.get("remaining", 0)) - int(ticks))
		"probe":
			var case_id: String = str(input.get("case_id", ""))
			if not definition.get("cases", {}).has(case_id):
				return _error("UNKNOWN_CASE", "Unknown business scenario.", previous)
			var scenario: Dictionary = definition.cases[case_id]
			var route: String = str(input.get("route_id", "direct"))
			var request: Dictionary = scenario.request if route == "direct" else scenario.get("routes", {}).get(route, {})
			if request.is_empty():
				return _error("UNKNOWN_ROUTE", "Unknown approved business route.", previous)
			var probe_context: Dictionary = context.duplicate()
			probe_context["origin"] = scenario.actor_ref.host_id
			var result: Dictionary = dispatch(definition, request, scenario.actor_ref, state, probe_context)
			if not result.ok:
				return _error(result.code, result.text, previous)
			state = result.state
			var receipt: Dictionary = result.response.duplicate(true)
			receipt["case_id"] = case_id
			receipt["route_id"] = route
			receipt["basis"] = basis(definition, state, probe_context, request, scenario.actor_ref)
			state.probe_receipts[case_id] = receipt
			feedback = result.response
		"request":
			if not input.get("request") is Dictionary:
				return _error("INVALID_ARGUMENTS", "A registered request is required.", previous)
			var request: Dictionary = input.request
			var actor: Dictionary = context.get("actor", {})
			var result: Dictionary = dispatch(definition, request, actor, state, context)
			if not result.ok:
				return _error(result.code, result.text, previous)
			state = result.state
			feedback = result.response
			for id in definition.get("cases", {}):
				var scenario: Dictionary = definition.cases[id]
				if scenario.actor_ref.get("account_id", "") != actor.get("account_id", ""):
					continue
				var routes: Dictionary = {"direct": scenario.request}
				routes.merge(scenario.get("routes", {}))
				for route in routes:
					if _same_request(sanitize_input(definition, {"action": "request", "request": request}, context).request, sanitize_input(definition, {"action": "request", "request": routes[route]}, context).request):
						var receipt: Dictionary = result.response.duplicate(true)
						receipt.merge({"case_id": id, "route_id": route, "basis": basis(definition, state, context, request, actor)})
						state.probe_receipts[id] = receipt
		_:
			return _error("INVALID_ARGUMENTS", "Unknown response action.", previous)
	var result_context: Dictionary = context.duplicate()
	result_context["policies"] = policies
	var result: Dictionary = _ok(definition, state, result_context, effects, feedback)
	if feedback.has("checkpoint_id"):
		result["checkpoint_id"] = feedback.checkpoint_id
	return result


static func dispatch(definition: Dictionary, request: Dictionary, actor: Dictionary, previous: Dictionary, context: Dictionary) -> Dictionary:
	var state: Dictionary = initial_state(definition, previous)
	var url: String = str(request.get("url", ""))
	if not request.get("body", {}) is Dictionary or not request.get("headers", {}) is Dictionary:
		return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "Request body and headers must be objects."}
	var matched: Dictionary = match_endpoint(definition, request, context)
	if matched.is_empty():
		return {"ok": false, "code": "UNKNOWN_ROUTE", "text": "No registered business endpoint."}
	var endpoint: Dictionary = matched.definition
	var endpoint_id: String = matched.id
	var domain: String = url.get_slice("://", 1).get_slice("/", 0)
	var path: String = "/" + url.get_slice("://", 1).trim_prefix(domain).trim_prefix("/").get_slice("?", 0)
	var status := 200
	var host_id: String = endpoint.host_id
	var account: String = str(actor.get("account_id", ""))
	var body: Dictionary = request.get("body", {})
	var policies: Dictionary = context.get("policies", {})
	var business: Dictionary = {}
	var new_session: Dictionary = {}
	var response_body := ""
	var key := ""
	var service: Callable = context.get("service_check", Callable())
	if service.is_valid():
		var transport: Dictionary = service.call(host_id, "443" if url.begins_with("https:") else "80", context.get("origin", "local"))
		if not transport.get("ok", false) or transport.get("protocol", "") != ("https" if url.begins_with("https:") else "http"):
			status = 503
	if endpoint.has("enabled_policy") and policies.get(endpoint.enabled_policy, false) != true:
		status = 503
	var operation: String = str(endpoint.get("operation", ""))
	var text_fields: Array = {"auth_login": ["username", "password"], "upload_create": ["filename", "mime", "signature"], "vfs_write": ["content"], "notify_send": ["target"], "session_use": ["token_ref", "object_id"], "csrf_change": ["setting_id", "token"]}.get(operation, [])
	for field in text_fields:
		if body.has(field) and not body[field] is String:
			return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "Registered request fields must use their declared text types."}
	if operation in ["object_read", "delegated_read"]:
		var object_id: String = path.trim_prefix(str(endpoint.path_prefix)).get_slice("/", 0)
		key = "ticket:" + object_id + ":read"
		var object: Dictionary = definition.get("bindings", {}).get("objects", {}).get(object_id, {})
		if status == 200:
			if object.is_empty(): status = 404
			elif account.is_empty(): status = 401
			elif operation == "delegated_read" and not endpoint.get("scopes", {}).get(account, []).has(object_id): status = 403
			elif operation == "object_read" and policies.get(endpoint.get("owner_policy", ""), false) == true and account != object.get("owner", "") and not object.get("assigned_to", []).has(account): status = 403
		business[key] = status == 200
		if status == 200: response_body = str(context.get("records", {}).get(object.get("record_id", ""), {}).get("content", ""))
	elif operation == "notify_send":
		var target: String = str(body.get("target", ""))
		key = "notify:" + target + ":delivered"
		var enforce_targets: bool = not endpoint.has("allowlist_policy") or policies.get(endpoint.allowlist_policy, false) == true
		if status == 200 and ((enforce_targets and not endpoint.get("allowed_targets", []).has(target)) or (not endpoint.has("allowlist_policy") and endpoint.has("target_policy") and policies.get(endpoint.target_policy) != true)):
			status = 403
		if status == 200:
			state.business_objects[key] = int(state.business_objects.get(key, 0)) + 1
		business[key] = status == 200
	elif operation == "auth_login":
		var username: String = str(body.get("username", ""))
		key = "auth:" + username + ":login"
		var accounts: Dictionary = context.get("hosts", {}).get(host_id, {}).get("accounts", {})
		var user: Dictionary = state.auth_users.get(username, {"attempts": 0, "remaining": 0})
		if status == 200:
			if policies.get(endpoint.get("rate_policy", ""), false) == true and user.remaining > 0:
				status = 429
			elif not accounts.has(username) or body.get("password", "") != accounts[username].password:
				status = 401
				user.attempts += 1
				if policies.get(endpoint.get("rate_policy", ""), false) == true and user.attempts >= int(endpoint.get("limit", 2)):
					user.remaining = int(endpoint.get("cooldown", 2))
			else:
				user.attempts = 0
				var token: String = "lab-session:" + endpoint_id + ":" + username
				state.tokens[token] = {"account_id": username, "revoked": false, "expires_tick": state.tick + int(endpoint.get("ttl", 32)), "scope": endpoint.get("scopes", {}).get(username, [])}
				new_session = {"account_id": username, "token": token, "host_id": host_id}
		state.auth_users[username] = user
		business[key] = status == 200
	elif operation == "session_use":
		var ref: String = str(body.get("token_ref", actor.get("token_ref", "")))
		key = "session:" + ref + ":use"
		var token: Dictionary = state.tokens.get(ref, {})
		var recognized: bool = endpoint.get("initial_tokens", {}).has(ref) or ref.begins_with("lab-session:" + endpoint_id + ":")
		if status == 200 and (not recognized or token.is_empty() or (policies.get(endpoint.get("revocation_policy", ""), true) == true and (token.get("revoked", false) or int(token.get("expires_tick", 1000000)) <= state.tick)) or (body.has("object_id") and not token.get("scope", []).has(body.object_id))):
			status = 403
		business[key] = status == 200
		if status == 200 and not str(token.get("account_id", "")).is_empty(): new_session = {"host_id": host_id, "account_id": token.account_id, "token": ref}
	elif operation == "upload_create":
		var name: String = str(body.get("filename", ""))
		key = "upload:" + name + ":created"
		var valid: bool = not name.contains("/") and not name.contains("\\") and name.get_extension().to_lower() in ["jpg", "jpeg"] and body.get("mime", "") == "image/jpeg" and body.get("signature", "") == "JPEG"
		if status == 200 and policies.get(endpoint.get("validation_policy", ""), false) == true and not valid:
			status = 415
		if status == 200:
			status = 201
			var permitted_at_upload: bool = policies.get(endpoint.get("nonexecuting_policy", ""), false) != true and not valid
			state.business_objects[key] = {"stored_as": "upload-" + str(state.artifact_events.size() + 1), "filename": name, "mime": body.get("mime", ""), "signature": body.get("signature", ""), "signature_valid": valid, "endpoint_id": endpoint_id, "accepted_tick": state.tick, "quarantined": false, "execution_policy_id": endpoint.get("nonexecuting_policy", ""), "execution_allowed_at_upload": permitted_at_upload, "execution_allowed": permitted_at_upload}
			state.artifact_events.append({"event": "accepted", "tick": state.tick, "artifact_id": key, "endpoint_id": endpoint_id, "execution_allowed_at_upload": permitted_at_upload})
		business[key] = status == 201
	elif operation == "csrf_change":
		var setting: String = str(body.get("setting_id", endpoint.get("own_setting", "")))
		var value: Variant = body.get("value")
		if not (value is bool or value is String or typeof(value) == TYPE_INT):
			return {"ok": false, "code": "INVALID_ARGUMENTS", "text": "A setting value must be a bounded scalar."}
		var storage_key: String = "setting:" + account + ":" + setting
		key = "setting:" + account + ":updated"
		if status == 200:
			if account.is_empty() or not context.get("hosts", {}).get(host_id, {}).get("accounts", {}).has(account): status = 401
			elif not endpoint.get("scopes", {}).get(account, []).has(setting): status = 403
			elif policies.get(endpoint.get("token_policy", ""), false) == true and (str(body.get("token", "")).is_empty() or body.get("token", "") != endpoint.get("tokens", {}).get(account)): status = 403
			elif policies.get(endpoint.get("origin_policy", endpoint.get("token_policy", "")), false) == true and request.get("headers", {}).get("Origin", "") != endpoint.get("origin", ""): status = 403
			else: state.business_objects[storage_key] = value
		business[key] = status == 200
		business["setting:" + account + ":value"] = state.business_objects.get(storage_key)
		if status == 200: response_body = JSON.stringify({"setting_id": setting, "value": value})
	elif operation in ["vfs_read", "vfs_write"]:
		var file_path: String = str(endpoint.get("file_path", ""))
		key = "file:" + host_id + ":" + file_path + (":read" if operation == "vfs_read" else ":write")
		var files: Dictionary = effective_files(definition, state, context, host_id)
		var groups: Array = actor_groups(state, context, host_id, account)
		var checked: Dictionary = FS.access(files, file_path, account, groups, "read" if operation == "vfs_read" else "stat")
		if status == 200 and (not checked.ok or checked.get("entry", {}).get("kind", "") != "file"):
			status = 403
		if status == 200 and operation == "vfs_write":
			if not endpoint.get("write_scope", definition.get("bindings", {}).get("write_scope", [])).has(file_path) or not FS.permitted(checked.entry, account, groups, 2):
				status = 403
			else:
				var entry: Dictionary = checked.entry.duplicate(true)
				entry.content = str(body.get("content", ""))
				entry.erase("display_content_key")
				entry.source = host_id + ":" + file_path + "@" + str(state.file_versions.size() + 1)
				if not state.file_overrides.has(host_id): state.file_overrides[host_id] = {}
				state.file_overrides[host_id][file_path] = entry
				state.file_versions.append(entry.duplicate(true))
		business[key] = status == 200
		if status == 200: response_body = str(effective_files(definition, state, context, host_id).get(file_path, {}).get("content", ""))
	else:
		return {"ok": false, "code": "UNKNOWN_OPERATION", "text": "Unsupported business operation."}
	var response: Dictionary = {"status": status, "actor": account if not account.is_empty() else "anonymous", "host_id": host_id, "endpoint_id": endpoint_id, "origin": context.get("origin", "local"), "business": business, "trace": [{"operation": operation, "status": status, "actor": account, "target": key}], "body": response_body, "headers": {}}
	if not new_session.is_empty(): response["new_session"] = new_session
	return {"ok": true, "state": state, "response": response}


static func _set_control(definition: Dictionary, state: Dictionary, policies: Dictionary, effects: Dictionary, id: String, value: Variant, context: Dictionary) -> String:
	var control: Dictionary = definition.get("controls", {}).get(id, {})
	var supported := false
	for choice in control.get("values", []):
		if typeof(value) == typeof(choice) and value == choice: supported = true
	if control.is_empty() or not supported: return "Unknown control or unsupported value."
	match str(control.get("kind", "policy")):
		"policy":
			policies[control.policy_id] = value
			effects.policy_updates[control.policy_id] = value
		"actor_groups":
			if not value is Array: return "Group assignments must be an array."
			state.group_overrides[control.host_id + ":" + control.account_id] = value.duplicate()
		"vfs_mode":
			var files: Dictionary = effective_files(definition, state, context, control.host_id)
			if not files.has(control.file_path) or not value is String or value.length() != 3: return "Invalid virtual file mode."
			var entry: Dictionary = files[control.file_path].duplicate(true)
			entry.mode = value
			if not state.file_overrides.has(control.host_id): state.file_overrides[control.host_id] = {}
			state.file_overrides[control.host_id][control.file_path] = entry
		_: return "Unsupported control kind."
	return ""


static func _control_value(control: Dictionary, policies: Dictionary, state: Dictionary, context: Dictionary) -> Variant:
	if control.get("kind", "policy") == "actor_groups": return actor_groups(state, context, control.host_id, control.account_id)
	if control.get("kind", "policy") == "vfs_mode": return effective_files({}, state, context, control.host_id).get(control.file_path, {}).get("mode", "")
	return policies.get(control.get("policy_id", ""))


static func effective_files(_definition: Dictionary, state: Dictionary, context: Dictionary, host_id: String) -> Dictionary:
	var files: Dictionary = context.get("files", {}).get(host_id, context.get("hosts", {}).get(host_id, {}).get("files", {})).duplicate(true)
	for path in state.get("file_overrides", {}).get(host_id, {}): files[path] = state.file_overrides[host_id][path].duplicate(true)
	return files


static func actor_groups(state: Dictionary, context: Dictionary, host_id: String, account_id: String) -> Array:
	return state.get("group_overrides", {}).get(host_id + ":" + account_id, context.get("hosts", {}).get(host_id, {}).get("accounts", {}).get(account_id, {}).get("groups", [])).duplicate()


static func match_endpoint(definition: Dictionary, request: Dictionary, context: Dictionary) -> Dictionary:
	var url: String = str(request.get("url", ""))
	var domain: String = url.get_slice("://", 1).get_slice("/", 0)
	var path: String = "/" + url.get_slice("://", 1).trim_prefix(domain).trim_prefix("/").get_slice("?", 0)
	for id in definition.get("bindings", {}).get("endpoints", {}):
		var candidate: Dictionary = definition.bindings.endpoints[id]
		var host: Dictionary = context.get("hosts", {}).get(candidate.get("host_id", ""), {})
		if host.get("domain", "") == domain and str(request.get("method", "GET")).to_upper() == str(candidate.get("method", "GET")).to_upper() and path.begins_with(str(candidate.get("path_prefix", "/"))):
			return {"id": id, "definition": candidate}
	return {}


static func sanitize_input(definition: Dictionary, raw: Variant, context: Dictionary) -> Variant:
	if not raw is Dictionary: return raw
	var input: Dictionary = raw.duplicate(true)
	if input.get("action", "") != "request" or not input.get("request") is Dictionary: return input
	var request: Dictionary = input.request
	request["body"] = request.get("body", {})
	var matched: Dictionary = match_endpoint(definition, request, context)
	if matched.is_empty() or matched.definition.get("operation", "") != "auth_login" or not request.get("body", {}) is Dictionary: return input
	var host: Dictionary = context.get("hosts", {}).get(matched.definition.host_id, {})
	var username: String = str(request.body.get("username", ""))
	var account: Dictionary = host.get("accounts", {}).get(username, {})
	if account.is_empty() or not request.body.get("password", "") is String or request.body.get("password", "") != account.get("password", ""):
		var marker := "__incorrect_game_password__"
		while marker == account.get("password", ""): marker += "_"
		request.body["password"] = marker
	return input


static func _same_request(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("method", "GET")).to_upper() == str(right.get("method", "GET")).to_upper() and left.get("url", "") == right.get("url", "") and left.get("body", {}) == right.get("body", {})


static func basis(definition: Dictionary, state: Dictionary, context: Dictionary, request: Dictionary, actor: Dictionary) -> String:
	var matched: Dictionary = match_endpoint(definition, request, context)
	if matched.is_empty(): return ""
	var endpoint: Dictionary = matched.definition
	var relevant: Dictionary = {"endpoint": matched.id, "policies": {}, "actor": actor.get("account_id", ""), "origin": context.get("origin", "local")}
	for field in endpoint:
		if str(field).ends_with("_policy"):
			relevant.policies[endpoint[field]] = context.get("policies", {}).get(endpoint[field])
	var host: Dictionary = context.get("hosts", {}).get(endpoint.host_id, {})
	var port: String = "443" if str(request.get("url", "")).begins_with("https:") else "80"
	var service: Dictionary = host.get("services", {}).get(port, {"state": "closed"})
	relevant["service"] = service
	for policy in service.get("required_policies", {}):
		relevant.policies[policy] = context.get("policies", {}).get(policy)
	if service.has("policy_id"):
		relevant.policies[service.policy_id] = context.get("policies", {}).get(service.policy_id)
	if endpoint.get("operation", "") in ["vfs_read", "vfs_write"]:
		var files: Dictionary = effective_files(definition, state, context, endpoint.host_id)
		var path: String = endpoint.get("file_path", "")
		relevant["files"] = {}
		while not path.is_empty():
			var entry: Dictionary = files.get(path, {})
			relevant.files[path] = {"kind": entry.get("kind", ""), "owner": entry.get("owner", ""), "group": entry.get("group", ""), "mode": entry.get("mode", "")}
			if endpoint.get("current_content", false) == true and path == endpoint.get("file_path", ""):
				relevant.files[path]["content"] = entry.get("content")
			if path == "/": break
			path = path.get_base_dir()
		relevant["groups"] = actor_groups(state, context, endpoint.host_id, actor.get("account_id", ""))
	if endpoint.get("operation", "") == "session_use":
		var ref: String = request.get("body", {}).get("token_ref", actor.get("token_ref", ""))
		relevant["token"] = state.get("tokens", {}).get(ref, {})
		relevant["tick"] = state.get("tick", 0)
	return JSON.stringify(relevant, "", true, true).sha256_text()


static func goal_met(definition: Dictionary, state: Dictionary, context: Dictionary, cases: Array = []) -> bool:
	for object in state.get("business_objects", {}).values():
		if object is Dictionary and _artifact_executable(object, context): return false
	var required: Array = cases if not cases.is_empty() else definition.get("cases", {}).keys()
	if required.is_empty(): return false
	for id in required:
		if not definition.cases.has(id) or not state.get("probe_receipts", {}).has(id): return false
		var receipt: Dictionary = state.probe_receipts[id]
		if receipt.get("assessment_eligible", true) != true: return false
		var scenario: Dictionary = definition.cases[id]
		var route: String = receipt.get("route_id", "direct")
		var request: Dictionary = scenario.request if route == "direct" else scenario.get("routes", {}).get(route, {})
		var current_context: Dictionary = context.duplicate()
		current_context["origin"] = receipt.get("origin", "local")
		if request.is_empty() or receipt.get("basis", "") != basis(definition, state, current_context, request, scenario.actor_ref): return false
		var expected: Dictionary = definition.cases[id].expect
		if not expected.get("statuses", []).has(receipt.get("status")): return false
		if expected.has("business_key") and not _same_value(receipt.get("business", {}).get(expected.business_key), expected.get("value")): return false
		if not _normal_current(definition, state, current_context, request, scenario.actor_ref, expected): return false
	return true


static func _normal_current(definition: Dictionary, state: Dictionary, context: Dictionary, request: Dictionary, actor: Dictionary, expected: Dictionary) -> bool:
	var expects_success := false
	for status in expected.get("statuses", []):
		expects_success = expects_success or (status >= 200 and status < 300)
	if not expects_success: return true
	var matched: Dictionary = match_endpoint(definition, request, context)
	if matched.is_empty(): return false
	var endpoint: Dictionary = matched.definition
	var body: Dictionary = request.get("body", {})
	match str(endpoint.operation):
		"auth_login":
			var username: String = str(body.get("username", ""))
			if context.get("policies", {}).get(endpoint.get("rate_policy", ""), false) == true and int(state.get("auth_users", {}).get(username, {}).get("remaining", 0)) > 0: return false
		"upload_create":
			var artifact: Dictionary = state.get("business_objects", {}).get("upload:" + str(body.get("filename", "")) + ":created", {})
			if artifact.is_empty() or artifact.get("quarantined", false): return false
			for field in ["filename", "mime", "signature"]:
				if artifact.get(field, "") != body.get(field, ""): return false
		"vfs_write":
			if endpoint.get("current_content", false) == true:
				var entry: Dictionary = effective_files(definition, state, context, endpoint.host_id).get(endpoint.get("file_path", ""), {})
				if entry.get("kind", "") != "file" or not _same_value(entry.get("content"), body.get("content", "")): return false
		"csrf_change":
			var setting: String = str(body.get("setting_id", endpoint.get("own_setting", "")))
			if not _same_value(state.get("business_objects", {}).get("setting:" + str(actor.get("account_id", "")) + ":" + setting), body.get("value")): return false
	return true


static func _same_value(left: Variant, right: Variant) -> bool:
	return typeof(left) == typeof(right) and left == right


static func _artifact_executable(artifact: Dictionary, context: Dictionary) -> bool:
	if not artifact.has("filename") or artifact.get("quarantined", false): return false
	var capable: bool = not bool(artifact.signature_valid) if artifact.has("signature_valid") else artifact.get("execution_allowed_at_upload", artifact.get("execution_allowed", false)) == true
	return capable and context.get("policies", {}).get(artifact.get("execution_policy_id", ""), false) != true


static func artifacts(state: Dictionary, context: Dictionary) -> Array:
	var rows: Array = []
	for id in state.get("business_objects", {}):
		var artifact: Variant = state.business_objects[id]
		if not artifact is Dictionary or not artifact.has("filename"): continue
		rows.append({"artifact_id": id, "filename": artifact.filename, "stored_as": artifact.get("stored_as", ""), "endpoint_id": artifact.get("endpoint_id", ""), "signature_valid": artifact.get("signature_valid", false), "quarantined": artifact.get("quarantined", false), "execution_allowed": _artifact_executable(artifact, context), "execution_allowed_at_upload": artifact.get("execution_allowed_at_upload", artifact.get("execution_allowed", false)), "accepted_tick": artifact.get("accepted_tick", 0)})
	return rows


static func public_data(definition: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	var controls: Array = []
	for id in definition.get("controls", {}):
		var control: Dictionary = definition.controls[id]
		controls.append({"id": id, "label": str(TranslationServer.translate(control.get("label", id))), "value": _control_value(control, context.get("policies", {}), state, context), "options": control.get("values", [])})
	var matrix: Array = []
	for id in definition.get("cases", {}):
		var scenario: Dictionary = definition.cases[id]
		matrix.append({"case_id": id, "label": str(TranslationServer.translate(scenario.label)), "class": scenario.get("class", "normal"), "route_options": ["direct"] + scenario.get("routes", {}).keys(), "observed": state.get("probe_receipts", {}).get(id, {})})
	var checkpoints: Array = []
	for id in state.get("checkpoints", {}): checkpoints.append({"id": id, "group": state.checkpoints[id].group, "label": str(TranslationServer.translate(state.checkpoints[id].get("label", id)))})
	var public_objects: Dictionary = state.get("business_objects", {}).duplicate(true)
	var artifact_rows: Array = artifacts(state, context)
	for artifact in artifact_rows: public_objects[artifact.artifact_id] = artifact
	return {"controls": controls, "matrix": matrix, "checkpoints": checkpoints, "probe_receipts": state.get("probe_receipts", {}), "business_objects": public_objects, "artifacts": artifact_rows, "artifact_events": state.get("artifact_events", []), "revocation_refs": state.get("revocation_refs", [])}


static func _ok(definition: Dictionary, state: Dictionary, context: Dictionary, effects: Dictionary, feedback: Dictionary) -> Dictionary:
	return {"ok": true, "code": "RESPONSE_OBSERVED", "text": "Response state updated from the selected operation.", "state": state, "solved": goal_met(definition, state, context), "status": feedback.get("status", 200), "feedback": feedback, "effects": effects}


static func _error(code: String, text: String, previous: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "state": previous.duplicate(true), "solved": false, "status": 400, "feedback": {}, "effects": {}}
