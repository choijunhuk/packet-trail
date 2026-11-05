extends RefCounted
## Closed schemas for authored response, observation, and branching models.
const Models = preload("res://scripts/core/tool_runtime.gd")


static func errors(model: Dictionary, mission: Dictionary) -> Array[String]:
	match model.get("kind", ""):
		"response_lab": return _response(model, mission)
		"observation_case": return _observation(model, mission)
		"branch_vm": return _vm(model)
	return []


static func _response(model: Dictionary, mission: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["controls", "bindings", "cases", "checkpoint_groups"]:
		if not model.get(key) is Dictionary: result.append("Invalid response container: " + key)
	if not result.is_empty(): return result
	if not model.bindings.get("endpoints") is Dictionary or not model.bindings.get("objects", {}) is Dictionary or model.cases.is_empty() or model.cases.size() > 32 or model.controls.size() > 32:
		return ["Invalid response bindings or bounds."]
	for id in model.controls:
		var control: Variant = model.controls[id]
		if not id is String or not control is Dictionary or not control.get("values") is Array or control.values.is_empty() or control.values.size() > 32:
			result.append("Invalid control choices.")
			continue
		match str(control.get("kind", "policy")):
			"policy":
				if not mission.policies.has(control.get("policy_id", "")): result.append("Unknown control policy.")
				else:
					for value in control.values:
						if typeof(value) != typeof(mission.policies[control.policy_id]): result.append("Control value type differs from policy.")
			"vfs_mode":
				if not _file_ref(control, mission): result.append("Unknown virtual permission target.")
				for value in control.values:
					if not value is String or value.length() != 3 or not value[0] in "01234567" or not value[1] in "01234567" or not value[2] in "01234567": result.append("Invalid mode choice.")
			"actor_groups":
				if not _actor(control, mission): result.append("Unknown group-assignment actor.")
				for value in control.values:
					if not _strings(value, 16): result.append("Invalid group choices.")
			_: result.append("Unknown response control kind.")
	for object in model.bindings.get("objects", {}).values():
		if not object is Dictionary or not object.get("owner") is String or not mission.records.has(object.get("record_id", "")) or not _strings(object.get("assigned_to", []), 32): result.append("Invalid business object reference.")
	var operations := ["object_read", "delegated_read", "auth_login", "session_use", "upload_create", "notify_send", "vfs_read", "vfs_write", "csrf_change"]
	for endpoint in model.bindings.endpoints.values():
		if not endpoint is Dictionary or not mission.hosts.has(endpoint.get("host_id", "")) or not endpoint.get("method", "GET") in ["GET", "POST", "PUT", "PATCH", "DELETE"] or not endpoint.get("path_prefix") is String or not endpoint.path_prefix.begins_with("/") or not operations.has(endpoint.get("operation", "")):
			result.append("Invalid response endpoint.")
			continue
		for key in endpoint:
			if str(key).ends_with("_policy") and (not mission.policies.has(endpoint[key]) or not mission.policies[endpoint[key]] is bool): result.append("Unknown/nonboolean endpoint policy.")
		if endpoint.operation == "delegated_read":
			if not endpoint.get("scopes") is Dictionary: result.append("Delegation scopes must be explicit.")
			else:
				for account in endpoint.scopes:
					if not _strings(endpoint.scopes[account], 32): result.append("Invalid delegation scope.")
		if endpoint.operation == "csrf_change":
			if not endpoint.get("origin") is String or endpoint.origin != "https://" + str(mission.hosts[endpoint.host_id].domain) or not mission.policies.has(endpoint.get("token_policy", "")) or not endpoint.get("tokens") is Dictionary or not endpoint.get("scopes") is Dictionary:
				result.append("Invalid fixed CSRF context/nonce/scope binding.")
			else:
				for account in endpoint.tokens:
					if not mission.hosts[endpoint.host_id].accounts.has(account) or not endpoint.tokens[account] is String or endpoint.tokens[account].is_empty(): result.append("Unknown CSRF token principal.")
				for account in endpoint.scopes:
					if not mission.hosts[endpoint.host_id].accounts.has(account) or not _strings(endpoint.scopes[account], 32) or endpoint.scopes[account].is_empty(): result.append("Invalid fixed CSRF target scope.")
			if endpoint.has("own_setting") and not endpoint.own_setting is String: result.append("Invalid fixed setting target.")
		if endpoint.operation in ["vfs_read", "vfs_write"] and not _file_ref(endpoint, mission): result.append("Unknown endpoint virtual file.")
		if endpoint.operation == "vfs_write" and (not _strings(endpoint.get("write_scope", model.bindings.get("write_scope", [])), 32) or not endpoint.get("write_scope", model.bindings.get("write_scope", [])).has(endpoint.get("file_path", ""))): result.append("Write target must be in the declared file scope.")
		if endpoint.operation == "notify_send" and not _strings(endpoint.get("allowed_targets", []), 32): result.append("Invalid notification targets.")
		if endpoint.operation == "session_use":
			if not endpoint.get("initial_tokens", {}) is Dictionary: result.append("Invalid token registry.")
			else:
				for token in endpoint.get("initial_tokens", {}).values():
					if not token is Dictionary or not mission.hosts[endpoint.host_id].accounts.has(token.get("account_id", "")) or not token.get("revoked", false) is bool or not _integer(token.get("expires_tick", 1000000), 0, 1000000) or not _strings(token.get("scope", []), 32): result.append("Invalid initial token state.")
		for key in ["limit", "cooldown", "ttl"]:
			if endpoint.has(key) and not _integer(endpoint[key], 1, 64): result.append("Invalid logical bound.")
	for scenario in model.cases.values():
		if not scenario is Dictionary or not scenario.get("label") is String or not _actor(scenario.get("actor_ref"), mission) or not scenario.get("request") is Dictionary or not scenario.get("routes", {}) is Dictionary or not scenario.get("expect") is Dictionary:
			result.append("Invalid response scenario.")
			continue
		var requests: Array = [scenario.request] + scenario.get("routes", {}).values()
		for request in requests:
			if not _request(request, model, mission): result.append("Unknown/invalid scenario request route.")
		if not scenario.expect.get("statuses") is Array or scenario.expect.statuses.is_empty(): result.append("Missing expected status set.")
		else:
			for status in scenario.expect.statuses:
				if not _integer(status, 100, 599): result.append("Invalid expected HTTP status.")
		if scenario.expect.has("business_key") and (not scenario.expect.business_key is String or not _scalar(scenario.expect.get("value"))): result.append("Invalid business assertion.")
	for group in model.checkpoint_groups:
		if not _strings(model.checkpoint_groups[group], 32) or model.checkpoint_groups[group].is_empty():
			result.append("Invalid checkpoint group.")
			continue
		for id in model.checkpoint_groups[group]:
			if not model.controls.has(id) or model.controls[id].get("group", "") != group: result.append("Checkpoint references another control group.")
	if not model.get("initial_checkpoints", {}) is Dictionary or model.get("initial_checkpoints", {}).size() > 8: result.append("Invalid initial checkpoints.")
	else:
		for checkpoint in model.get("initial_checkpoints", {}).values():
			if not checkpoint is Dictionary or not model.checkpoint_groups.has(checkpoint.get("group", "")) or not checkpoint.get("values") is Dictionary:
				result.append("Invalid initial checkpoint.")
				continue
			if checkpoint.values.size() != model.checkpoint_groups[checkpoint.group].size(): result.append("Incomplete checkpoint group.")
			for id in checkpoint.values:
				if not model.checkpoint_groups[checkpoint.group].has(id) or not model.controls[id].values.has(checkpoint.values[id]): result.append("Invalid checkpoint control/value.")
	return result


static func _observation(model: Dictionary, mission: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not model.get("sensors") is Dictionary or model.sensors.is_empty() or model.sensors.size() > 32 or not _strings(model.get("claim_types"), 3) or not model.get("handoff_requirements") is Dictionary: return ["Invalid observation model containers."]
	for kind in model.claim_types:
		if not kind in ["same_session", "before", "forwarded_to"]: result.append("Unknown relation type.")
	for sensor in model.sensors.values():
		if not sensor is Dictionary or not sensor.get("label") is String or not mission.hosts.has(sensor.get("host_id", "")) or not sensor.get("visibility", "metadata") in ["metadata", "endpoint", "payload"] or not sensor.get("windows") is Array or sensor.windows.is_empty() or sensor.windows.size() > 16:
			result.append("Invalid observation point.")
			continue
		if sensor.has("requires_session") and not _actor(sensor.requires_session, mission): result.append("Unknown observation authority.")
		if not sensor.get("coverage", {}) is Dictionary: result.append("Invalid observation coverage.")
		for window in sensor.windows:
			if not window is Dictionary or not window.get("rows") is Array or window.rows.size() > 128:
				result.append("Invalid observation window.")
				continue
			var seen: Array = []
			for row in window.rows:
				if not row is Dictionary or not row.get("event_id") is String or seen.has(row.get("event_id")) or not _interval(row.get("observed_at")) or not _interval(row.get("clock_offset")) or not row.get("public") is Dictionary or not row.get("provenance") is Dictionary:
					result.append("Invalid source observation.")
					continue
				seen.append(row.event_id)
				for key in ["source_id", "collector", "vantage", "acquisition", "marker_authority"]:
					if not row.provenance.get(key) is String: result.append("Missing observation provenance.")
				if not row.provenance.get("marker_authority", "") in ["server_issued", "client_supplied"]: result.append("Unknown marker authority.")
				if sensor.get("visibility", "metadata") == "metadata" and (row.public.has("authorized_excerpt") or row.public.has("payload") or row.public.has("plaintext") or row.public.has("credentials") or row.public.has("password") or row.public.has("secret")): result.append("Metadata observation cannot disclose a payload.")
	var required: Dictionary = model.handoff_requirements
	if not required.get("supported") is Array or required.supported.is_empty() or not _strings(required.get("next_vantage"), 32) or not _strings(required.get("refuted", []), 32) or not model.get("initial_claims", {}) is Dictionary: return result + ["Invalid handoff requirements."]
	for id in required.next_vantage:
		if not model.sensors.has(id): result.append("Unknown next observation point.")
	for relation in required.supported:
		if not relation is Dictionary or not model.claim_types.has(relation.get("kind", "")): result.append("Unknown required relation.")
		elif relation.kind == "before" and (not relation.get("left") is String or not relation.get("right") is String): result.append("Before requires specific event references.")
	for id in required.get("refuted", []):
		if not model.get("initial_claims", {}).get(id, {}).get("claim") is Dictionary: result.append("Unknown authored prior claim.")
	return result


static func _vm(model: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not model.get("program") is Dictionary or not model.program.get("functions") is Dictionary or not model.get("inputs") is Dictionary or not model.get("outcomes") is Dictionary or model.outcomes.is_empty() or model.inputs.size() > 32 or not model.get("limits", {}) is Dictionary: return ["Invalid VM containers."]
	var functions: Dictionary = model.program.functions
	if not functions.has(model.program.get("entry", "")) or functions.size() > 32: return ["Unknown VM entry or too many functions."]
	for id in model.inputs:
		var spec: Variant = model.inputs[id]
		if not spec is Dictionary or not spec.get("type") in ["bool", "int", "enum", "string"] or (spec.get("type") == "enum" and (not spec.get("choices") is Array or spec.choices.is_empty())): result.append("Invalid VM input schema.")
	for name in functions:
		var instructions: Variant = functions[name]
		if not instructions is Array or instructions.is_empty() or instructions.size() > 256:
			result.append("Invalid VM instruction bound.")
			continue
		var labels: Array = []
		for instruction in instructions:
			if not instruction is Dictionary or not Models.BranchVM.OPS.has(instruction.get("op", "")):
				result.append("Unknown VM instruction.")
				continue
			if instruction.has("label"):
				if not instruction.label is String or instruction.label.is_empty() or labels.has(instruction.label): result.append("Duplicate/invalid VM label.")
				labels.append(instruction.label)
		for instruction in instructions:
			if not instruction is Dictionary: continue
			match instruction.get("op", ""):
				"CONST", "LOAD", "CMP":
					if not instruction.get("dst") is String: result.append("Missing register destination.")
			if instruction.get("op") == "LOAD" and not model.inputs.has(instruction.get("input", "")): result.append("Unknown VM input reference.")
			if instruction.get("op") == "CALL" and (not functions.has(instruction.get("function", "")) or not instruction.get("dst", "result") is String): result.append("Unknown VM call target.")
			if instruction.get("op") == "JUMP" and not labels.has(instruction.get("target", "")): result.append("Unknown jump label.")
			if instruction.get("op") == "BRANCH" and (not instruction.get("reg") is String or not labels.has(instruction.get("then", "")) or not labels.has(instruction.get("else", ""))): result.append("Invalid branch references.")
			if instruction.get("op") == "RET" and not instruction.get("reg") is String: result.append("Invalid return source.")
			if instruction.get("op") == "SET_OUTPUT" and (not instruction.get("key") is String or not instruction.has("value")): result.append("Invalid output key/value.")
			if instruction.get("op") == "CONST" and not instruction.has("value"): result.append("Missing constant value.")
			if instruction.get("op") == "CMP":
				for side in ["left", "right"]:
					var operand: Variant = instruction.get(side)
					if not operand is Dictionary or operand.size() != 1 or (not operand.has("reg") and not operand.has("value")) or (operand.has("reg") and not operand.reg is String): result.append("Invalid comparison operand.")
				if not instruction.get("relation", "eq") in ["eq", "ne", "lt", "le"]: result.append("Invalid comparison relation.")
	for key in ["steps", "stack", "memory"]:
		if not _integer(model.get("limits", {}).get(key, {"steps": 256, "stack": 16, "memory": 64}[key]), 1, {"steps": 4096, "stack": 32, "memory": 512}[key]): result.append("Invalid VM resource limit.")
	for outcome in model.outcomes.values():
		if not outcome is Dictionary or not outcome.get("output") is Dictionary or outcome.output.is_empty() or not outcome.has("input_scope"): result.append("Invalid VM outcome predicate.")
	return result


static func _actor(raw: Variant, mission: Dictionary) -> bool:
	return raw is Dictionary and mission.hosts.has(raw.get("host_id", "")) and mission.hosts[raw.host_id].accounts.has(raw.get("account_id", ""))


static func _file_ref(raw: Dictionary, mission: Dictionary) -> bool:
	return mission.hosts.has(raw.get("host_id", "")) and mission.hosts[raw.host_id].files.has(raw.get("file_path", ""))


static func _request(raw: Variant, model: Dictionary, mission: Dictionary) -> bool:
	if not raw is Dictionary or not raw.get("url") is String or not raw.get("body", {}) is Dictionary or not raw.get("headers", {}) is Dictionary: return false
	if not (raw.url.begins_with("https://") or raw.url.begins_with("http://")) or raw.url.contains("@") or raw.url.contains("\\"): return false
	return not Models.ResponseLab.match_endpoint(model, raw, {"hosts": mission.hosts}).is_empty()


static func _strings(raw: Variant, maximum: int) -> bool:
	if not raw is Array or raw.size() > maximum: return false
	for value in raw:
		if not value is String: return false
	return true


static func _interval(raw: Variant) -> bool:
	return raw is Array and raw.size() == 2 and _integer(raw[0], -1000000, 1000000) and _integer(raw[1], -1000000, 1000000) and raw[0] <= raw[1]


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum


static func _scalar(value: Variant) -> bool:
	return value is bool or value is String or _integer(value, -9007199254740991, 9007199254740991)
