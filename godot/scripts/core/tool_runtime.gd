extends RefCounted

const FS = preload("res://scripts/core/virtual_fs.gd")
const ResponseLab = preload("res://scripts/core/response_lab.gd")
const ObservationCase = preload("res://scripts/core/observation_case.gd")
const BranchVM = preload("res://scripts/core/branch_vm.gd")
const STATEFUL_KINDS := ["response_lab", "observation_case", "branch_vm"]
const KINDS := ["query", "render", "path", "exec", "fetch", "permission", "audit", "reverse", "memory", "packet", "trace", "compare", "token", "policy", "idor", "session", "csrf", "upload", "response_lab", "observation_case", "branch_vm"]


static func normalize_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = normalize_value(value[key])
		return dictionary
	if value is Array:
		var entries: Array = []
		for entry in value:
			entries.append(normalize_value(entry))
		return entries
	if typeof(value) == TYPE_FLOAT and is_finite(value) and abs(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	return value


static func apply_challenge(definition: Dictionary, input: Variant, policies: Dictionary, previous: Dictionary, account: String = "", context: Dictionary = {}) -> Dictionary:
	match definition.get("kind", ""):
		"response_lab": return ResponseLab.apply_action(definition, input, previous, context)
		"observation_case": return ObservationCase.apply_action(definition, input, previous, context)
		"branch_vm": return BranchVM.apply_action(definition, input, previous, context)
	var state: Dictionary = previous.duplicate(true)
	var kind: String = definition.get("kind", "")
	var policy: Variant = policies.get(definition.get("policy_id", ""), false)
	var strict: bool = policy is bool and policy
	var text := str(input) if not input is Dictionary else JSON.stringify(input)
	var solved := false
	var detail := ""
	var status := 200
	match kind:
		"query":
			var condition_pattern := RegEx.new()
			condition_pattern.compile("(?i)\\bor\\s+('[^']*'|\"[^\"]*\"|[0-9]+)\\s*=\\s*('[^']*'|\"[^\"]*\"|[0-9]+)")
			var found: RegExMatch = condition_pattern.search(text)
			if not strict and found != null:
				var left: String = found.get_string(1)
				var right: String = found.get_string(2)
				var tail: String = text.substr(found.get_end()).strip_edges()
				var supported_tail: bool = tail.is_empty() or tail.begins_with("--")
				if left.is_valid_int() and right.is_valid_int():
					solved = supported_tail and int(left) == int(right)
				elif left.length() >= 2 and right.length() >= 2:
					solved = supported_tail and left.substr(1, left.length() - 2) == right.substr(1, right.length() - 2)
			var selected: Array = []
			for row in definition.get("_query_rows", []):
				if solved or (not row.get("restricted", false) and str(row.get("content", "")).to_lower().contains(text.to_lower())):
					selected.append(row)
			detail = "parameter binding: " + str(strict) + "\n" + JSON.stringify(selected, "  ")
			state["selected_rows"] = selected
		"render":
			solved = not strict and text.contains("signal:" + str(definition.get("marker", ""))) and not str(definition.get("marker", "")).is_empty()
			state["render_mode"] = "text" if strict else "virtual-markup"
			state["rendered_text"] = text
			state["signal"] = definition.get("marker", "") if solved else ""
			detail = "render context: " + ("text escaped" if strict else "virtual signal interpreted")
		"path":
			var path: Dictionary = FS.normalize(text, definition.get("base_path", "/public"))
			solved = not strict and path.ok and path.path == definition.get("target_path", "")
			detail = "normalized: " + str(path.get("path", "invalid")) + " / document-root boundary: " + str(strict)
		"exec":
			var jobs: PackedStringArray = text.split(";")
			solved = not strict and jobs.size() == 2 and jobs[0].strip_edges() == "diagnose" and jobs[1].strip_edges() == "inspect:" + str(definition.get("marker", "")) and not str(definition.get("marker", "")).is_empty()
			state["jobs"] = ["diagnose", "inspect:" + str(definition.get("marker", ""))] if solved else ["diagnose"]
			state["caller_account"] = account
			state["execution_account"] = definition.get("run_as", account)
			state["execution_groups"] = definition.get("_execution_groups", [])
			detail = "argument array: " + str(strict) + " / registered virtual jobs: " + JSON.stringify(state.jobs) + "\ncaller=" + account + " / run_as=" + str(state.execution_account) + " / groups=" + str(state.execution_groups)
		"fetch":
			solved = not strict and text == definition.get("target_url", "") and _internal(text)
			detail = "server-origin request / egress policy: " + str(strict)
		"permission":
			solved = text == definition.get("group", "") and not text.is_empty() and account == definition.get("account_id", "")
			detail = "account=" + account + " / exposed group=" + text
		"audit", "reverse":
			var decoded := ""
			for byte in definition.get("encoded", []):
				decoded += String.chr(int(byte) ^ int(definition.get("xor_key", 0)))
			solved = not decoded.is_empty() and text == decoded
			detail = "XOR " + str(definition.get("xor_key", 0)) + " / bytes=" + str(definition.get("encoded", []).size())
		"memory":
			var hex: String = text.to_lower().replace(" ", "")
			var bytes: Array[int] = []
			var valid: bool = hex.length() % 2 == 0 and hex.length() <= 512
			for character in hex:
				if not character in "0123456789abcdef":
					valid = false
			if valid:
				for index in range(0, hex.length(), 2):
					bytes.append(hex.substr(index, 2).hex_to_int())
			var offset: int = int(definition.get("flag_offset", -1))
			var size: int = int(definition.get("memory_size", 64))
			solved = valid and offset >= int(definition.get("buffer_size", 0)) and offset >= 0 and offset < size and bytes.size() <= size and bytes.size() > offset and bytes[offset] == int(definition.get("expected_byte", -1))
			detail = "virtual bytes=" + str(bytes.size()) + " / buffer=" + str(definition.get("buffer_size", 0)) + " / flag offset=" + str(offset)
			state["memory"] = bytes if valid and bytes.size() <= size else state.get("memory", [])
			if bytes.size() > size:
				status = 413
		"packet", "trace":
			var pair: PackedStringArray = text.split("=", true, 1)
			var selected: Array = []
			if pair.size() == 2 and pair[0] == definition.get("field", ""):
				for row in definition.get("rows", []):
					if str(row.get(pair[0], "")) == pair[1]:
						selected.append(row)
			solved = not selected.is_empty() and pair.size() == 2 and pair[1] == str(definition.get("value", ""))
			detail = JSON.stringify(selected, "  ")
			state["selected_rows"] = selected
		"compare":
			var parts: PackedStringArray = text.split("|", true, 1)
			if input is Dictionary:
				parts = PackedStringArray([str(input.get("left", "")), str(input.get("right", ""))])
			solved = parts.size() == 2 and parts[0] == definition.get("left", "") and parts[1] == definition.get("right", "") and parts[0] != parts[1]
			detail = "compare: " + text
		"token":
			solved = not text.is_empty() and text == definition.get("token", "")
			detail = "virtual credential reference checked"
		"policy":
			var value: Variant = input
			if input is String and input in ["true", "false"]:
				value = input == "true"
			solved = definition.get("values", [true, false]).has(value)
			state["policy_value"] = value
			detail = "policy value: " + str(value)
		"idor":
			var object_id: String = str(input.get("object_id", "")) if input is Dictionary else text
			var objects: Dictionary = definition.get("objects", {})
			if account.is_empty() or not objects.has(object_id):
				return _result(false, "AUTH_REQUIRED" if account.is_empty() else "NOT_FOUND", "Authenticated account and existing object required.", state)
			var object: Dictionary = objects[object_id]
			status = 403 if strict and object.get("owner", "") != account else 200
			solved = status == 200 and object.get("record_id", "") == definition.get("record_id", "")
			detail = "requester=" + account + " owner=" + str(object.get("owner", "")) + " object=" + object_id
			if status == 200:
				detail += "\n" + str(definition.get("_object_contents", {}).get(object.get("record_id", ""), ""))
		"session":
			if not input is Dictionary:
				return _result(false, "INVALID_ARGUMENTS", "Use action: issue, revoke or reuse with token.", state)
			var tick: int = int(state.get("tick", 0)) + 1
			var tokens: Dictionary = state.get("tokens", {str(definition.get("stale_token", "old")): {"revoked": false, "issued_at": 0, "expires_at": 0}})
			var token: String = str(input.get("token", "new-session"))
			if token.is_empty() or token.length() > 128:
				return _result(false, "INVALID_ARGUMENTS", "Session token must be 1–128 characters.", state)
			match str(input.get("action", "")):
				"issue":
					if account != definition.get("account_id", ""):
						return _result(false, "AUTH_REQUIRED", "Session issuance requires the configured account.", state)
					tokens[token] = {"revoked": false, "issued_at": tick, "expires_at": tick + int(definition.get("ttl", 8))}
				"revoke":
					if not tokens.has(token):
						return _result(false, "NOT_FOUND", "Unknown session token.", state)
					tokens[token]["revoked"] = true
				"reuse":
					status = 403 if not tokens.has(token) or (strict and (tokens[token].revoked or int(tokens[token].get("expires_at", 0)) <= tick or token == definition.get("stale_token", ""))) else 200
					if status == 403 and token == definition.get("stale_token", ""):
						state["stale_denied"] = true
					if strict and status == 200 and token != definition.get("stale_token", ""):
						state["fresh_allowed"] = true
				"wait":
					var ticks: Variant = input.get("ticks", 0)
					if not typeof(ticks) in [TYPE_INT, TYPE_FLOAT] or float(ticks) != floor(float(ticks)) or ticks < 1 or ticks > 32:
						return _result(false, "INVALID_ARGUMENTS", "Session wait ticks must be 1–32.", state)
					tick += int(ticks)
				_:
					return _result(false, "INVALID_ARGUMENTS", "Unknown session action.", state)
			state["tokens"] = tokens
			state["tick"] = tick
			solved = strict and state.get("stale_denied", false) and state.get("fresh_allowed", false)
			detail = "session status=" + str(status) + " tokens=" + str(tokens.keys())
		"csrf":
			if not input is Dictionary or account.is_empty():
				return _result(false, "AUTH_REQUIRED", "Authenticated change request required.", state)
			var valid: bool = input.get("origin", "") == definition.get("origin", "") and input.get("token", "") == definition.get("csrf_token", "")
			status = 200 if not strict or valid else 403
			if strict and not valid:
				state["forged_denied"] = true
			if strict and valid:
				state["normal_allowed"] = true
			if status == 200:
				state["value"] = input.get("value", "unchanged")
			solved = strict and state.get("forged_denied", false) and state.get("normal_allowed", false)
			detail = "origin/token accepted=" + str(valid) + " / changed=" + str(status == 200)
		"upload":
			if not input is Dictionary:
				return _result(false, "INVALID_ARGUMENTS", "Provide filename, mime and signature.", state)
			var filename: String = str(input.get("filename", ""))
			var valid: bool = not filename.contains("/") and not filename.contains("\\") and not filename.contains("..") and filename.get_extension().to_lower() in ["jpg", "jpeg"] and input.get("mime", "") == "image/jpeg" and input.get("signature", "") == "JPEG"
			status = 201 if not strict or valid else 415
			if strict and valid:
				state["image_allowed"] = true
			if strict and not valid:
				state["fake_denied"] = true
			var stored: Array = state.get("stored_files", [])
			if strict:
				for file in stored:
					file["execution_allowed"] = false
			if status == 201:
				stored.append({"filename": filename, "stored_as": "upload-" + str(stored.size() + 1), "mime": str(input.get("mime", "")), "signature": str(input.get("signature", "")), "execution_allowed": not strict and not valid})
			state["stored_files"] = stored
			state["executable"] = not strict and not valid
			solved = strict and state.get("image_allowed", false) and state.get("fake_denied", false) and not state.executable
			detail = "extension/MIME/signature=" + str(valid) + " / executable=" + str(state.executable)
		_:
			return _result(false, "UNKNOWN_MODEL", "Unsupported model.", state)
	var result: Dictionary = _result(true, "MODEL_OBSERVED", detail, state)
	result["solved"] = solved
	result["status"] = status
	return result


static func _result(ok: bool, code: String, text: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "code": code, "text": text, "state": state, "solved": false, "status": 200}


static func _internal(url: String) -> bool:
	return (url.begins_with("https://") or url.begins_with("http://")) and url.get_slice("://", 1).get_slice("/", 0).ends_with(".test") and not url.contains("@") and not url.contains("\\")
