extends RefCounted

const BaseLoader = preload("res://scripts/core/content_loader.gd")
const Models = preload("res://scripts/core/tool_runtime.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const ModelSchema = preload("res://scripts/core/campaign_model_schema.gd")
const GOALS := ["record_acquired", "sources_preserved", "fact", "policy", "session", "service", "response_matrix", "observation_handoff", "vm_cases", "current_boundaries"]
const PATH := "res://data/campaign/campaign.json"


static func load_campaign(pack_id: String = "legacy_intruder") -> Dictionary:
	var entry: Dictionary = Catalog.get_pack(pack_id)
	if entry.is_empty():
		return {"ok": false, "errors": ["Unknown campaign pack."], "definition": {}}
	var file := FileAccess.open(entry.resource, FileAccess.READ)
	if file == null:
		return {"ok": false, "errors": ["Campaign content unavailable."], "definition": {}}
	if file.get_length() > 16777216:
		return {"ok": false, "errors": ["Campaign content exceeds 16 MiB."], "definition": {}}
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		return {"ok": false, "errors": [parser.get_error_message()], "definition": {}}
	return validate(parser.data, pack_id)


static func validate(raw: Variant, expected_pack_id: String = "") -> Dictionary:
	var errors: Array[String] = []
	if not raw is Dictionary or not raw.has_all(["schema_version", "content_version", "campaign_id", "start_mission", "mission_order", "missions", "endings"]):
		return {"ok": false, "errors": ["Missing campaign fields."], "definition": {}}
	var data: Dictionary = Models.normalize_value(raw)
	if not _integer(data.schema_version, 1, 1) or not data.missions is Dictionary or not data.mission_order is Array or not data.endings is Array or not data.campaign_id is String or not data.start_mission is String:
		return {"ok": false, "errors": ["Invalid campaign types/version."], "definition": {}}
	if not _integer(data.content_version, 1, 100000):
		return {"ok": false, "errors": ["Invalid content version."], "definition": {}}
	data.schema_version = 1
	data.content_version = int(data.content_version)
	if not expected_pack_id.is_empty():
		var entry: Dictionary = Catalog.get_pack(expected_pack_id)
		if entry.is_empty() or data.campaign_id != entry.campaign_id or data.content_version != entry.content_version:
			return {"ok": false, "errors": ["Campaign pack identity/version mismatch."], "definition": {}}
	var seen: Array = []
	for id in data.mission_order:
		if not id is String or seen.has(id) or not data.missions.has(id):
			errors.append("Mission order contains missing/duplicate ID.")
		seen.append(id)
	if seen.size() != data.missions.size() or not data.missions.has(data.start_mission):
		errors.append("Mission order/start mismatch.")
	var all_facts: Array = []
	for id in data.missions:
		var mission: Variant = data.missions[id]
		if not id is String or not mission is Dictionary:
			errors.append(str(id) + ": invalid mission")
			continue
		for field in ["chapter", "optional", "prerequisites", "policies", "challenges", "hints"]:
			if not mission.has(field):
				errors.append(str(id) + ": missing " + field)
		if not mission.get("hosts") is Dictionary or not mission.get("pages") is Dictionary or not mission.get("records") is Dictionary or not mission.get("goals") is Array or not mission.get("goal") is Dictionary or not mission.get("policies") is Dictionary or not mission.get("challenges") is Dictionary:
			errors.append(str(id) + ": invalid mission containers")
			continue
		if not mission.get("mission_id") is String or mission.get("mission_id") != id or not mission.get("prerequisites") is Array or not mission.get("optional") is bool or not _integer(mission.get("chapter"), 1, 6):
			errors.append(str(id) + ": invalid mission metadata")
			continue
		if mission.goals.is_empty():
			errors.append(str(id) + ": goals cannot be empty")
		mission.chapter = int(mission.chapter)
		for predecessor in mission.prerequisites:
			if not data.missions.has(predecessor) or data.mission_order.find(predecessor) >= data.mission_order.find(id):
				errors.append(str(id) + ": prerequisite missing or cyclic")
		var base: Dictionary = mission.duplicate(true)
		base.mission_id = "M01"
		base.goals = [{"kind": "record_acquired", "record_id": base.get("goal", {}).get("record_id", "")}, {"kind": "sources_preserved"}]
		for page in base.pages.values():
			if page is Dictionary and page.has("record_id") and base.records.has(page.record_id):
				page.body = base.records[page.record_id].content
		for host_id in mission.hosts:
			var host: Variant = mission.hosts[host_id]
			if not host is Dictionary:
				errors.append(str(id) + ": invalid host")
				continue
			host["services"] = host.get("services", {"22": {"protocol": "ssh", "state": "open"}, "443": {"protocol": "https", "state": "open"}})
			host["via"] = host.get("via", ["local"])
			if not host.services is Dictionary or not host.via is Array:
				errors.append(str(id) + ": invalid network")
				continue
			for origin in host.via:
				if origin != "local" and not mission.hosts.has(origin):
					errors.append(str(id) + ": unknown route origin")
			for port in host.services:
				var service: Variant = host.services[port]
				if not str(port).is_valid_int() or int(port) < 1 or int(port) > 65535 or not service is Dictionary or not ["open", "closed", "filtered"].has(service.get("state")) or not ["ssh", "http", "https", "ftp", "db", "notification"].has(service.get("protocol")):
					errors.append(str(id) + ": invalid service")
					continue
				if not service.get("required_policies", {}) is Dictionary:
					errors.append(str(id) + ": invalid service policies")
				else:
					for policy in service.get("required_policies", {}):
						if not mission.policies.has(policy):
							errors.append(str(id) + ": unknown service policy")
		var validated: Dictionary = BaseLoader.validate(base)
		if not validated.ok:
			for message in validated.errors:
				errors.append(str(id) + ": " + str(message))
			continue
		for goal in mission.goals:
			if not goal is Dictionary or not GOALS.has(goal.get("kind")):
				errors.append(str(id) + ": unknown goal")
				continue
			var required_fields: Array = {"record_acquired": ["kind", "record_id"], "sources_preserved": ["kind"], "fact": ["kind", "id"], "policy": ["kind", "id", "value"], "session": ["kind", "host_id", "account_id"], "service": ["kind", "host_id", "port", "state"], "response_matrix": ["kind", "challenge_id", "case_ids"], "observation_handoff": ["kind", "challenge_id"], "vm_cases": ["kind", "challenge_id", "requirements"], "current_boundaries": ["kind", "cases"]}[goal.kind]
			if not goal.has_all(required_fields):
				errors.append(str(id) + ": missing goal fields")
				continue
			for field in ["record_id", "id", "host_id", "account_id", "state", "challenge_id"]:
				if goal.has(field) and not goal[field] is String:
					errors.append(str(id) + ": invalid goal reference type")
			for field in ["label_display", "target_display"]:
				if goal.has(field) and not goal[field] is String:
					errors.append(str(id) + ": invalid goal display metadata")
			match goal.kind:
				"record_acquired":
					if not mission.records.has(goal.get("record_id")):
						errors.append(str(id) + ": missing goal record")
				"policy":
					if not mission.policies.has(goal.get("id")):
						errors.append(str(id) + ": missing goal policy")
					elif typeof(mission.policies[goal.id]) != typeof(goal.value) and not (typeof(mission.policies[goal.id]) in [TYPE_INT, TYPE_FLOAT] and typeof(goal.value) in [TYPE_INT, TYPE_FLOAT]):
						errors.append(str(id) + ": invalid policy goal value type")
				"session", "service":
					if not mission.hosts.has(goal.get("host_id")):
						errors.append(str(id) + ": missing goal host")
					elif goal.kind == "session" and not mission.hosts[goal.host_id].accounts.has(goal.get("account_id")):
						errors.append(str(id) + ": missing goal account")
					elif goal.kind == "service" and (not mission.hosts[goal.host_id].services.has(str(goal.get("port", ""))) or not ["open", "closed", "filtered"].has(goal.get("state"))):
						errors.append(str(id) + ": invalid service goal")
			for message in _model_goal_errors(goal, mission):
				errors.append(str(id) + ": " + message)
		for challenge_id in mission.challenges:
			var challenge: Variant = mission.challenges[challenge_id]
			if not challenge is Dictionary or not (Models.KINDS + ["auth"]).has(challenge.get("kind")) or (not Models.STATEFUL_KINDS.has(challenge.get("kind")) and not mission.records.has(challenge.get("record_id", ""))):
				errors.append(str(id) + ": invalid challenge")
				continue
			if challenge.has("record_id") and (not mission.records.has(challenge.record_id) or not mission.records[challenge.record_id].allowed_sources.has(challenge.get("source", ""))):
				errors.append(str(id) + ": challenge source mismatch")
			if challenge.has("policy_id") and not mission.policies.has(challenge.policy_id):
				errors.append(str(id) + ": challenge policy missing")
			for message in _challenge_errors(challenge, mission):
				errors.append(str(id) + "/" + str(challenge_id) + ": " + message)
			if challenge.has("fact_id") and not all_facts.has(challenge.fact_id):
				all_facts.append(challenge.fact_id)
		for record in mission.records.values():
			for fact in record.get("grants_facts", []):
				if not all_facts.has(fact):
					all_facts.append(fact)
		for page in mission.pages.values():
			if page.has("challenge_id") and not mission.challenges.has(page.challenge_id):
				errors.append(str(id) + ": page challenge missing")
			if not _requirements_valid(page, mission):
				errors.append(str(id) + ": invalid page access requirements")
	if data.endings.is_empty():
		errors.append("Ending definitions cannot be empty.")
	for message in _contact_errors(data):
		errors.append(message)
	var ending_ids: Array[String] = []
	for ending in data.endings:
		if not ending is Dictionary or not ending.has_all(["id", "title", "text", "requires_facts"]) or not ending.get("id") is String or not ending.get("title") is String or not ending.get("text") is String or not ending.get("requires_facts") is Array:
			errors.append("Invalid ending.")
			continue
		if ending.id.is_empty() or ending_ids.has(ending.id):
			errors.append("Ending IDs must be nonempty and unique.")
		ending_ids.append(ending.id)
		for fact in ending.requires_facts:
			if not all_facts.has(fact):
				errors.append("Ending references unknown evidence.")
	for mission in data.missions.values():
		if not mission is Dictionary or not mission.get("goals") is Array:
			continue
		for goal in mission.goals:
			if goal is Dictionary and goal.get("kind", "") == "fact" and not all_facts.has(goal.get("id")):
				errors.append("Unknown goal evidence.")
	return {"ok": errors.is_empty(), "definition": data if errors.is_empty() else {}, "errors": errors}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _requirements_valid(definition: Dictionary, mission: Dictionary) -> bool:
	if definition.has("host_id") and (not definition.host_id is String or not mission.hosts.has(definition.host_id)):
		return false
	if not definition.get("requires_facts", []) is Array:
		return false
	for fact in definition.get("requires_facts", []):
		if not fact is String:
			return false
	var session: Variant = definition.get("requires_session", {})
	if not session is Dictionary:
		return false
	return session.is_empty() or (mission.hosts.has(session.get("host_id", "")) and mission.hosts[session.host_id].accounts.has(session.get("account_id", "")))


static func _challenge_errors(challenge: Dictionary, mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _requirements_valid(challenge, mission):
		errors.append("Invalid access requirements.")
	if Models.STATEFUL_KINDS.has(challenge.kind):
		return errors + ModelSchema.errors(challenge, mission)
	var fields: Dictionary = {
		"query": [], "render": ["marker"], "path": ["base_path", "target_path"], "exec": ["marker"], "fetch": ["target_url"],
		"permission": ["group", "host_id", "account_id"], "audit": ["encoded", "xor_key"], "reverse": ["encoded", "xor_key"],
		"memory": ["buffer_size", "memory_size", "flag_offset", "expected_byte"], "packet": ["rows", "field", "value"], "trace": ["rows", "field", "value"],
		"compare": ["left", "right"], "token": ["token"], "policy": ["policy_id", "values"], "idor": ["objects", "policy_id"],
		"session": ["host_id", "account_id", "stale_token", "policy_id"], "csrf": ["origin", "csrf_token", "policy_id"],
		"upload": ["policy_id"], "auth": ["host_id", "account_id", "policy_id"],
	}
	for field in fields.get(challenge.kind, []):
		if not challenge.has(field):
			errors.append("Missing model field: " + str(field))
	if not errors.is_empty():
		return errors
	for field in ["marker", "base_path", "target_path", "target_url", "group", "host_id", "account_id", "field", "value", "left", "right", "token", "policy_id", "stale_token", "origin", "csrf_token", "fact_id"]:
		if challenge.has(field) and (not challenge[field] is String or str(challenge[field]).is_empty()):
			errors.append("Invalid model string: " + field)
	if challenge.has("account_id") and challenge.has("host_id") and (not mission.hosts.has(challenge.host_id) or not mission.hosts[challenge.host_id].accounts.has(challenge.account_id)):
		errors.append("Unknown model account.")
	if challenge.has("policy_id") and challenge.kind != "policy" and mission.policies.has(challenge.policy_id) and not mission.policies[challenge.policy_id] is bool:
		errors.append("Security model policies must be boolean.")
	if challenge.has("run_as"):
		var host: String = challenge.get("host_id", challenge.get("requires_session", {}).get("host_id", ""))
		if not mission.hosts.has(host) or not mission.hosts[host].accounts.has(challenge.run_as):
			errors.append("Unknown service execution account.")
	if challenge.kind in ["reverse", "audit"]:
		if not challenge.encoded is Array or challenge.encoded.is_empty() or challenge.encoded.size() > 4096 or not _integer(challenge.xor_key, 0, 255):
			errors.append("Invalid byte-analysis data.")
		else:
			for byte in challenge.encoded:
				if not _integer(byte, 0, 255):
					errors.append("Invalid encoded byte.")
	if challenge.kind == "memory":
		for field in ["buffer_size", "memory_size", "flag_offset", "expected_byte"]:
			if not _integer(challenge[field], 0, 256):
				errors.append("Invalid memory bound.")
		if errors.is_empty() and (challenge.memory_size < 1 or challenge.buffer_size < 1 or challenge.flag_offset < challenge.buffer_size or challenge.flag_offset >= challenge.memory_size or challenge.expected_byte > 255):
			errors.append("Memory flag must be outside the buffer and inside virtual memory.")
	if challenge.kind in ["packet", "trace"]:
		if not challenge.rows is Array or challenge.rows.is_empty() or challenge.rows.size() > 512:
			errors.append("Invalid observation rows.")
		else:
			for row in challenge.rows:
				if not row is Dictionary:
					errors.append("Invalid observation row.")
	if challenge.kind == "policy" and (not challenge.values is Array or challenge.values.is_empty()):
		errors.append("Invalid policy choices.")
	if challenge.kind == "idor":
		if not challenge.objects is Dictionary or challenge.objects.is_empty():
			errors.append("Invalid object ownership table.")
		else:
			for object in challenge.objects.values():
				if not object is Dictionary or not object.get("owner") is String or not mission.records.has(object.get("record_id", "")):
					errors.append("Invalid object record/owner.")
	for field in ["limit", "cooldown", "ttl"]:
		if challenge.has(field) and not _integer(challenge[field], 1, 64):
			errors.append("Invalid logical timing bound.")
	return errors


static func _model_goal_errors(goal: Dictionary, mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var required_kind: String = {"response_matrix": "response_lab", "observation_handoff": "observation_case", "vm_cases": "branch_vm"}.get(goal.kind, "")
	if not required_kind.is_empty():
		var model: Variant = mission.challenges.get(goal.get("challenge_id", ""))
		if not model is Dictionary or model.get("kind", "") != required_kind: return ["Goal references another model kind."]
		if goal.kind == "response_matrix":
			if not goal.get("case_ids") is Array or goal.case_ids.is_empty(): return ["Response goal must name its cases."]
			for id in goal.case_ids:
				if not id is String or not model.get("cases", {}).has(id): errors.append("Unknown response goal case.")
		if goal.kind == "vm_cases":
			if not goal.get("requirements") is Array or goal.requirements.is_empty(): return ["VM goal must name actual output predicates."]
			for id in goal.requirements:
				if not id is String or not model.get("outcomes", {}).has(id): errors.append("Unknown VM output predicate.")
	if goal.kind == "current_boundaries":
		if not goal.get("cases") is Dictionary: return ["Boundary references must be qualified."]
		for boundary in ["web", "route", "service"]:
			if not goal.cases.get(boundary) is Array or goal.cases[boundary].is_empty():
				errors.append("Missing current boundary cases.")
				continue
			for ref in goal.cases[boundary]:
				if not ref is Dictionary or ref.size() != 2 or not ref.get("challenge_id") is String or not ref.get("case_id") is String:
					errors.append("Boundary case requires challenge_id and case_id.")
					continue
				var model: Variant = mission.challenges.get(ref.challenge_id)
				if not model is Dictionary or model.get("kind", "") != "response_lab" or not model.get("cases", {}).has(ref.case_id): errors.append("Unknown qualified boundary case.")
	return errors


static func _contact_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.get("contacts", {}) is Dictionary: return ["Invalid campaign contacts."]
	for id in data.get("contacts", {}):
		var contact: Variant = data.contacts[id]
		if not id in ["C01", "C02", "C03", "C04"] or not contact is Dictionary or not contact.get("name_key") is String or not contact.get("introduced_by") is Array or contact.introduced_by.is_empty() or not contact.get("face_gate") is Dictionary:
			errors.append("Invalid campaign contact metadata.")
			continue
		for mission_id in contact.introduced_by:
			if not mission_id is String or not data.missions.has(mission_id): errors.append("Unknown contact introduction.")
		var gate: Dictionary = contact.face_gate
		if not gate.get("when", "") in ["introduced", "completed"] or not gate.get("explicit") is bool or (gate.get("when") == "completed" and not data.missions.has(gate.get("mission_id", ""))): errors.append("Invalid contact face gate.")
		if id == "C01" and gate.get("explicit") != true: errors.append("C01 privacy reveal must remain an explicit choice.")
	return errors
