extends RefCounted
## A finite, provider-neutral role/resource policy exercise; no external IAM API.

const SECTIONS := ["principals", "resources", "roles", "bindings", "credentials", "requests", "probe_receipts"]
const MAX_TICK := 4096


static func initial_state(definition: Dictionary, previous: Dictionary) -> Dictionary:
	if not previous.is_empty():
		return previous.duplicate(true)
	var revoked: Dictionary = {}
	for ref in definition.get("credentials", {}):
		revoked[ref] = definition.credentials[ref].get("revoked", false)
	return {"bindings": definition.get("initial_bindings", {}).duplicate(true), "revoked": revoked, "tick": 0, "probe_receipts": {}}


static func apply_action(definition: Dictionary, input: Variant, previous: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not input is Dictionary or not input.get("action", "inspect") is String or JSON.stringify(input).length() > 4096:
		return _error("IAM_INVALID", "Select a bounded IAM action.", previous)
	var action: String = input.get("action", "inspect")
	var fields: Dictionary = {"inspect": ["section"], "bind": ["principal_id", "role_id"], "revoke": ["credential_ref"], "probe": ["request_id", "route_id"], "advance": ["ticks"], "restore_initial": []}
	if not fields.has(action):
		return _error("IAM_INVALID", "Unknown IAM action.", previous)
	for key in input:
		if not key is String or (not key in ["action", "terminal_id", "challenge_id"] and not fields[action].has(key)):
			return _error("IAM_INVALID", "Unknown IAM action field.", previous)
	if input.has("terminal_id") and not _integer(input.terminal_id, 0, 3):
		return _error("IAM_INVALID", "Invalid terminal reference.", previous)
	if input.has("challenge_id") and (not input.challenge_id is String or input.challenge_id.length() > 64):
		return _error("IAM_INVALID", "Invalid challenge reference.", previous)
	var state: Dictionary = initial_state(definition, previous)
	if not _valid_state(definition, state):
		return _error("IAM_INVALID_STATE", "IAM state does not match its registered configuration.", previous)
	var feedback: Dictionary = {}
	match action:
		"inspect":
			var section: Variant = input.get("section", "bindings")
			if not section is String or not SECTIONS.has(section):
				return _error("IAM_INVALID", "Unknown public IAM section.", previous)
			feedback = {"section": section, "data": public_data(definition, state, context)[section]}
		"bind":
			var principal: Variant = input.get("principal_id")
			var role: Variant = input.get("role_id")
			if not principal is String or not role is String or not definition.get("binding_choices", {}).get(principal, []).has(role):
				return _error("IAM_INVALID_BINDING", "Select a registered principal and one of its role choices.", previous)
			state.bindings[principal] = role
			feedback = {"principal_id": principal, "role_id": role}
		"revoke":
			var ref: Variant = input.get("credential_ref")
			if not ref is String or not definition.get("credentials", {}).has(ref):
				return _error("IAM_UNKNOWN_CREDENTIAL", "Unknown registered credential.", previous)
			state.revoked[ref] = true
			feedback = {"credential_ref": ref, "revoked": true}
		"advance":
			var ticks: Variant = input.get("ticks")
			if not _integer(ticks, 1, 32) or int(state.tick) + int(ticks) > MAX_TICK:
				return _error("IAM_INVALID", "Advance requires 1–32 logical ticks within the exercise limit.", previous)
			state.tick = int(state.tick) + int(ticks)
			feedback = {"tick": state.tick}
		"restore_initial":
			state = initial_state(definition, {})
			feedback = {"restored": true}
		"probe":
			var request_id: Variant = input.get("request_id")
			var route_id: Variant = input.get("route_id", "direct")
			if not request_id is String or not route_id is String or not definition.get("requests", {}).has(request_id):
				return _error("IAM_UNKNOWN_REQUEST", "Unknown registered IAM request.", previous)
			if _credential_for(definition.requests[request_id], route_id).is_empty():
				return _error("IAM_UNKNOWN_ROUTE", "Unknown registered IAM request route.", previous)
			feedback = _receipt(definition, state, request_id, route_id)
			state.probe_receipts[request_id] = feedback.duplicate(true)
	return {"ok": true, "code": "IAM_OBSERVED", "text": "IAM configuration and request evidence updated.", "state": state, "solved": goal_met(definition, state, context), "status": 200, "feedback": feedback, "effects": {}}


static func goal_met(definition: Dictionary, state: Dictionary, _context: Dictionary = {}) -> bool:
	if not _valid_state(definition, state) or definition.get("required_requests", []).is_empty():
		return false
	for id in definition.required_requests:
		if not definition.get("requests", {}).has(id) or not state.probe_receipts.get(id) is Dictionary:
			return false
		var observed: Dictionary = state.probe_receipts[id]
		var route: Variant = observed.get("route_id")
		if not route is String or _credential_for(definition.requests[id], route).is_empty():
			return false
		var current: Dictionary = _receipt(definition, state, id, route)
		if not observed.recursive_equal(current, 0) or current.decision != definition.requests[id].expect:
			return false
	return true


static func public_data(definition: Dictionary, previous: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var state: Dictionary = initial_state(definition, previous)
	var result: Dictionary = {"principals": [], "resources": [], "roles": [], "bindings": [], "credentials": [], "requests": [], "probe_receipts": {}}
	if not _valid_state(definition, state):
		return result
	for id in definition.principals:
		var principal: Dictionary = definition.principals[id]
		result.principals.append({"id": id, "label": _tr(principal.get("label", id)), "tenant": principal.tenant})
		result.bindings.append({"principal_id": id, "role_id": state.bindings[id], "choices": definition.binding_choices[id].duplicate()})
	for id in definition.resources:
		var resource: Dictionary = definition.resources[id]
		result.resources.append({"id": id, "label": _tr(resource.get("label", id)), "tenant": resource.tenant})
	for id in definition.roles:
		result.roles.append({"id": id, "label": _tr(definition.roles[id].get("label", id)), "rules": definition.roles[id].rules.duplicate(true)})
	for ref in definition.credentials:
		var credential: Dictionary = definition.credentials[ref]
		result.credentials.append({"credential_ref": ref, "principal_id": credential.principal_id, "expires_tick": credential.expires_tick, "revoked": state.revoked[ref], "expired": int(state.tick) >= int(credential.expires_tick)})
	for id in definition.requests:
		var request: Dictionary = definition.requests[id]
		result.requests.append({"request_id": id, "label": _tr(request.label), "action": request.action, "resource_id": request.resource_id, "expect": request.expect, "route_options": ["direct"] + request.get("routes", {}).keys(), "observed": state.probe_receipts.get(id, {}).duplicate(true)})
	result.probe_receipts = state.probe_receipts.duplicate(true)
	return result


static func _credential_for(request: Dictionary, route: String) -> String:
	return str(request.get("credential_ref", "")) if route == "direct" else str(request.get("routes", {}).get(route, {}).get("credential_ref", ""))


static func _receipt(definition: Dictionary, state: Dictionary, request_id: String, route_id: String) -> Dictionary:
	var request: Dictionary = definition.requests[request_id]
	var ref: String = _credential_for(request, route_id)
	var credential: Dictionary = definition.credentials[ref]
	var principal_id: String = credential.principal_id
	var role_id: String = state.bindings[principal_id]
	var result: Dictionary = {"request_id": request_id, "route_id": route_id, "credential_ref": ref, "principal_id": principal_id, "role_id": role_id, "action": request.action, "resource_id": request.resource_id, "decision": "deny", "reason": "DEFAULT_DENY", "matched_rules": [], "tick": int(state.tick), "basis": _basis(state)}
	if state.revoked[ref]:
		result.reason = "CREDENTIAL_REVOKED"
		return result
	if int(state.tick) >= int(credential.expires_tick):
		result.reason = "CREDENTIAL_EXPIRED"
		return result
	var allowed := false
	var denied := false
	var rules: Array = definition.roles[role_id].rules
	for index in rules.size():
		var rule: Dictionary = rules[index]
		if not rule.actions.has(request.action) or not rule.resources.has(request.resource_id):
			continue
		if rule.tenant_scope == "same" and definition.principals[principal_id].tenant != definition.resources[request.resource_id].tenant:
			continue
		result.matched_rules.append(role_id + ":" + str(index))
		if rule.effect == "deny": denied = true
		else: allowed = true
	if denied:
		result.reason = "EXPLICIT_DENY"
	elif allowed:
		result.decision = "allow"
		result.reason = "EXPLICIT_ALLOW"
	return result


static func _basis(state: Dictionary) -> String:
	return JSON.stringify({"bindings": state.bindings, "revoked": state.revoked, "tick": int(state.tick)}, "", true).sha256_text()


static func _valid_state(definition: Dictionary, state: Dictionary) -> bool:
	if not state.get("bindings") is Dictionary or not state.get("revoked") is Dictionary or not state.get("probe_receipts") is Dictionary or not _integer(state.get("tick"), 0, MAX_TICK):
		return false
	for key in state:
		if not key in ["bindings", "revoked", "tick", "probe_receipts", "solved"]:
			return false
	if state.has("solved") and not state.solved is bool:
		return false
	if state.bindings.size() != definition.get("principals", {}).size() or state.revoked.size() != definition.get("credentials", {}).size():
		return false
	for id in state.bindings:
		if not id is String or not state.bindings[id] is String or not definition.get("binding_choices", {}).get(id, []).has(state.bindings[id]):
			return false
	for ref in state.revoked:
		if not definition.get("credentials", {}).has(ref) or not state.revoked[ref] is bool:
			return false
		if definition.credentials[ref].get("revoked", false) and not state.revoked[ref]:
			return false
	for id in state.probe_receipts:
		if not definition.get("requests", {}).has(id) or not state.probe_receipts[id] is Dictionary:
			return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _tr(value: String) -> String:
	return str(TranslationServer.translate(value))


static func _error(code: String, text: String, previous: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "state": previous.duplicate(true), "solved": false, "status": 400, "feedback": {}, "effects": {}}
