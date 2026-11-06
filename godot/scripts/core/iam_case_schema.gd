extends RefCounted
## Closed authored registries for the finite IAM exercise.


static func validate(definition: Dictionary, mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not definition.get("kind") is String or definition.kind != "iam_case" or JSON.stringify(definition).length() > 65536:
		return ["Invalid IAM kind or definition size."]
	for key in ["principals", "resources", "roles", "initial_bindings", "binding_choices", "credentials", "requests"]:
		if not definition.get(key) is Dictionary:
			errors.append("Invalid IAM registry: " + key)
	if not definition.get("required_requests") is Array:
		errors.append("Missing required IAM requests.")
	if not errors.is_empty(): return errors
	for key in ["principals", "resources", "roles"]:
		if definition[key].is_empty() or definition[key].size() > 16: errors.append("IAM registry outside its bounds: " + key)
	for key in ["credentials", "requests"]:
		if definition[key].is_empty() or definition[key].size() > 32: errors.append("IAM registry outside its bounds: " + key)
	for key in ["name", "explain", "usage"]:
		if definition.has(key) and (not definition[key] is String or definition[key].is_empty() or definition[key].length() > 4096): errors.append("Invalid IAM presentation key.")
	var hosts: Dictionary = mission.get("hosts", {})
	var host: Variant = definition.get("host_id")
	var session: Variant = definition.get("requires_session")
	if not host is String or not hosts.has(host):
		errors.append("Unknown IAM host.")
	if not session is Dictionary or not session.get("host_id") is String or not session.get("account_id") is String:
		errors.append("IAM requires an explicit operator session.")
	elif session.host_id != host or not hosts.get(session.host_id, {}).get("accounts", {}).has(session.account_id):
		errors.append("Unknown IAM operator session.")
	for key in ["principals", "resources"]:
		for id in definition[key]:
			var row: Variant = definition[key][id]
			if not _id(id) or not row is Dictionary or not _keys(row, ["tenant", "label", "payload"]) or not _id(row.get("tenant")) or not _label(row):
				errors.append("Invalid IAM tenant or resource/principal.")
			elif row.has("payload") and (not row.payload is String or row.payload.length() > 1024):
				errors.append("IAM resource payload must be bounded text.")
	var actions: Array = []
	for id in definition.requests:
		var request: Variant = definition.requests[id]
		if not _id(id) or not request is Dictionary or not _keys(request, ["label", "credential_ref", "action", "resource_id", "expect", "routes"]) or not request.get("label") is String or request.label.is_empty() or request.label.length() > 4096:
			errors.append("Invalid IAM request.")
			continue
		if not _id(request.get("action")) or not request.get("resource_id") is String or not request.get("credential_ref") is String or not request.get("expect") is String or not definition.resources.has(request.resource_id) or not definition.credentials.has(request.credential_ref) or not request.expect in ["allow", "deny"]:
			errors.append("Unknown IAM request identity, action, resource or expected decision.")
		else:
			if not actions.has(request.action): actions.append(request.action)
		if not request.get("routes", {}) is Dictionary or request.get("routes", {}).size() > 8:
			errors.append("Invalid IAM route registry.")
		else:
			for route in request.get("routes", {}):
				var binding: Variant = request.routes[route]
				if not _id(route) or route == "direct" or not binding is Dictionary or not _keys(binding, ["credential_ref"]) or not binding.get("credential_ref") is String or not definition.credentials.has(binding.credential_ref):
					errors.append("Unknown IAM request route credential.")
	var total_rules := 0
	for id in definition.roles:
		var role: Variant = definition.roles[id]
		if not _id(id) or not role is Dictionary or not _keys(role, ["label", "rules"]) or not _label(role) or not role.get("rules") is Array or role.rules.size() > 32:
			errors.append("Invalid IAM role.")
			continue
		total_rules += role.rules.size()
		for rule in role.rules:
			if not rule is Dictionary or not _keys(rule, ["effect", "actions", "resources", "tenant_scope"]) or not rule.get("effect") is String or not rule.get("tenant_scope") is String or not rule.effect in ["allow", "deny"] or not rule.tenant_scope in ["same", "any"] or not _ids(rule.get("actions"), actions, 32) or not _ids(rule.get("resources"), definition.resources.keys(), 16):
				errors.append("Invalid IAM effect, action, resource or tenant condition.")
	if total_rules > 32: errors.append("Too many IAM rules.")
	if definition.initial_bindings.size() != definition.principals.size() or definition.binding_choices.size() != definition.principals.size():
		errors.append("Every IAM principal needs one initial binding and registered choices.")
	for id in definition.principals:
		if not _ids(definition.binding_choices.get(id), definition.roles.keys(), 16) or not definition.get("initial_bindings", {}).get(id) is String or not definition.binding_choices.get(id, []).has(definition.initial_bindings.get(id)):
			errors.append("Unknown IAM initial binding or role choice.")
	for id in definition.initial_bindings:
		if not definition.principals.has(id): errors.append("Unknown IAM binding principal.")
	for id in definition.binding_choices:
		if not definition.principals.has(id): errors.append("Unknown IAM role-choice principal.")
	for ref in definition.credentials:
		var credential: Variant = definition.credentials[ref]
		if not _id(ref) or not credential is Dictionary or not _keys(credential, ["principal_id", "expires_tick", "revoked"]) or not credential.get("principal_id") is String or not definition.principals.has(credential.principal_id) or not _integer(credential.get("expires_tick"), 0, 4096) or not credential.get("revoked") is bool:
			errors.append("Invalid IAM credential registry.")
	if not _ids(definition.required_requests, definition.requests.keys(), 32):
		errors.append("IAM requires distinct registered assessment requests.")
	else:
		var has_allow := false
		var has_deny := false
		for id in definition.required_requests:
			var request: Variant = definition.requests[id]
			if request is Dictionary and request.get("expect") is String:
				has_allow = has_allow or request.get("expect") == "allow"
				has_deny = has_deny or request.get("expect") == "deny"
		if not has_allow or not has_deny: errors.append("IAM must preserve normal access and reject a negative request.")
	return errors


static func _keys(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if not key is String or not allowed.has(key): return false
	return true


static func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	if not value[0] in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ": return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-": return false
	return true


static func _label(value: Dictionary) -> bool:
	return not value.has("label") or (value.label is String and not value.label.is_empty() and value.label.length() <= 4096)


static func _ids(value: Variant, registry: Array, limit: int) -> bool:
	if not value is Array or value.is_empty() or value.size() > limit: return false
	var seen: Array = []
	for id in value:
		if not _id(id) or not registry.has(id) or seen.has(id): return false
		seen.append(id)
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum
