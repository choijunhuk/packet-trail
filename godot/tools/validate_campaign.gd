extends SceneTree

const Loader = preload("res://scripts/core/campaign_loader.gd")

var checks := 0
var failures: Array = []


func _initialize() -> void:
	var loaded: Dictionary = Loader.load_campaign()
	_check(loaded.get("ok", false), "campaign loads with structured content", loaded.get("errors", []))
	if loaded.get("ok", false):
		_validate_coverage(loaded.definition)
		_validate_rejections(loaded.definition)
	print(JSON.stringify({"suite": "campaign_content", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not condition:
		failures.append({"case": label, "detail": detail})


func _validate_coverage(definition: Dictionary) -> void:
	var missions: Dictionary = definition.get("missions", {})
	var order: Array = definition.get("mission_order", [])
	var main_ids: Array = []
	var optional_ids: Array = []
	for index in range(1, 25):
		var id := "M%02d" % index
		main_ids.append(id)
		_check(missions.has(id), id + " has authored content")
		if missions.has(id):
			_check(missions[id].get("optional") == false and missions[id].get("chapter") == ceili(float(index) / 4.0), id + " retains its chapter and main status")
	for id in missions:
		if not main_ids.has(id):
			optional_ids.append(id)
			_check(missions[id].get("optional") == true, str(id) + " is an optional case")
	_check(missions.size() == 28 and optional_ids.size() == 4, "full product has 24 main and four optional cases", optional_ids)
	_check(order.size() == 28 and order.size() == _unique(order).size(), "mission order includes each case once")
	_check(definition.get("start_mission") == "M01", "campaign begins at the existing M01")
	var default_endings := 0
	for ending in definition.get("endings", []):
		if ending.get("requires_facts", ["missing"]).is_empty():
			default_endings += 1
	_check(default_endings > 0, "a base ending is reachable without optional facts")


func _unique(values: Array) -> Array:
	var unique: Array = []
	for value in values:
		if not unique.has(value):
			unique.append(value)
	return unique


func _reject(definition: Dictionary, path: Array, value: Variant, label: String, erase := false) -> void:
	var damaged := definition.duplicate(true)
	var node: Dictionary = damaged
	for index in range(path.size() - 1):
		if not node.get(path[index]) is Dictionary:
			_check(false, label + ": authored fixture path is missing", path)
			return
		node = node[path[index]]
	if erase:
		node.erase(path[-1])
	else:
		node[path[-1]] = value
	var result: Dictionary = Loader.validate(damaged)
	_check(not result.get("ok", true) and result.get("errors") is Array and not result.errors.is_empty(), label, result)


func _validate_rejections(definition: Dictionary) -> void:
	_reject(definition, ["schema_version"], true, "boolean schema version is rejected")
	_reject(definition, ["content_version"], 1.5, "fractional content version is rejected")
	_reject(definition, ["start_mission"], "missing", "unknown starting case is rejected")
	_reject(definition, ["mission_order"], ["M01", "M01"], "duplicate/missing mission order is rejected")
	_reject(definition, ["missions", "M01", "goals"], [], "empty goals cannot complete a case")
	_reject(definition, ["missions", "M01", "goals"], [{"kind": "unknown_goal"}], "unknown goal kinds are rejected")
	_reject(definition, ["missions", "M01", "goals"], [{"kind": "record_acquired", "record_id": "unknown_record"}], "unknown goal records are rejected")
	_reject(definition, ["missions", "M01", "prerequisites"], ["M99"], "missing prerequisites are rejected")
	_reject(definition, ["missions", "M01", "prerequisites"], ["M02"], "cyclic/forward prerequisites are rejected")
	_reject(definition, ["missions", "M01", "optional"], "false", "string optional flags are rejected")
	_reject(definition, ["missions", "M01", "chapter"], true, "boolean chapter numbers are rejected")
	_reject(definition, ["missions", "M01", "goal", "record_id"], "unknown_record", "missing target record is rejected")
	_reject(definition, ["endings"], [], "empty ending definitions are rejected")
	if not definition.get("endings", []).is_empty():
		var unknown_fact_endings: Array = definition.endings.duplicate(true)
		var extra: Dictionary = definition.endings[0].duplicate(true)
		extra.id = "qa_unknown_fact_ending"
		extra.requires_facts = ["never_authored_fact"]
		unknown_fact_endings.append(extra)
		_reject(definition, ["endings"], unknown_fact_endings, "endings cannot require an unauthored fact")
		var duplicate_endings: Array = definition.endings.duplicate(true)
		duplicate_endings.append(definition.endings[0].duplicate(true))
		_reject(definition, ["endings"], duplicate_endings, "ending IDs are unique")
	var mission: Dictionary = definition.missions.M01
	if not mission.get("hosts") is Dictionary or mission.hosts.is_empty():
		_check(false, "M01 host prerequisites for boundary fixtures exist")
		return
	var host_id: String = str(mission.hosts.keys()[0])
	var host: Dictionary = mission.hosts[host_id]
	_reject(definition, ["missions", "M01", "hosts", host_id, "via"], ["missing_host"], "unknown routing origins are rejected")
	_reject(definition, ["missions", "M01", "hosts", host_id, "services"], {"0": {"protocol": "ssh", "state": "open"}}, "port zero is rejected")
	_reject(definition, ["missions", "M01", "hosts", host_id, "services"], {"22": {"protocol": "ssh", "state": "unknown"}}, "unsupported service states are rejected")
	_reject(definition, ["missions", "M01", "hosts", host_id, "files", "/"], true, "malformed root entries return structured validation errors")
	var record_id: String = str(mission.goal.record_id)
	_reject(definition, ["missions", "M01", "records", record_id, "allowed_sources"], true, "malformed source lists are rejected without unsafe dereference")
	_reject(definition, ["missions", "M01", "records", record_id, "allowed_sources"], [], "empty record provenance is rejected")
	if host.get("accounts") is Dictionary and not host.accounts.is_empty():
		var account_id: String = str(host.accounts.keys()[0])
		_reject(definition, ["missions", "M01", "hosts", host_id, "accounts", account_id, "home"], "/missing_home", "missing account homes are rejected")
		_reject(definition, ["missions", "M01", "hosts", host_id, "accounts", account_id, "groups"], false, "malformed account groups are rejected")
	else:
		_check(false, "M01 account prerequisites for validation fixtures exist")
	if mission.get("pages") is Dictionary and not mission.pages.is_empty():
		var page_url: String = str(mission.pages.keys()[0])
		_reject(definition, ["missions", "M01", "pages", page_url, "challenge_id"], "unknown_challenge", "page references must point to registered challenges")
	else:
		_check(false, "M01 page prerequisites for validation fixtures exist")
