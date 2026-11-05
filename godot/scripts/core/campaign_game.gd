extends RefCounted

const Loader = preload("res://scripts/core/campaign_loader.gd")
const Runtime = preload("res://scripts/core/campaign_runtime.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Legacy = preload("res://scripts/core/game.gd")
const DEFAULT_PATH := "user://saves/campaign_01.json"
const SAVE_KEYS := ["save_version", "campaign_id", "content_version", "current_mission", "current_world", "completed", "mission_states", "decisions", "ending"]
const CONTACTS := {"C01": {"met": "M01", "gate": "M12", "choice": true}, "C02": {"met": "M02", "gate": "M02", "choice": false}, "C03": {"met": "M09", "gate": "M16", "choice": true}, "C04": {"met": "M15", "gate": "M20", "choice": false}}

var _definition: Dictionary = {}
var _runtime: RefCounted
var _ready := false
var _error := ""
var _current := ""
var _completed: Array = []
var _states: Dictionary = {}
var _decisions: Dictionary = {}
var _ending := ""
var _hint_level := 0
var _save_path := DEFAULT_PATH
var _store = Store.new()


func _init(save_path: String = DEFAULT_PATH) -> void:
	_save_path = save_path
	var loaded: Dictionary = Loader.load_campaign()
	_ready = loaded.ok
	if not _ready:
		_error = "\n".join(loaded.errors)
		return
	_definition = loaded.definition
	_current = _definition.start_mission
	_runtime = Runtime.new()
	_runtime.configure(_definition.missions[_current])


func execute(line: String, terminal_id: int = 0) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	var result: Dictionary = _runtime.run_command(line, terminal_id)
	_sync()
	return result


func submit_password(password: String, terminal_id: int = 0) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	var result: Dictionary = _runtime.authenticate(password, terminal_id)
	_sync()
	return result


func cancel_authentication(terminal_id: int = 0) -> Dictionary:
	return _runtime.cancel_auth(terminal_id) if _ready else _result(false, "INVALID_CONTENT", _error)


func browse(url: String) -> Dictionary:
	return request("GET", url, {}, {"X-Packet-Context": "browser"})


func request(method: String, url: String, body: Dictionary = {}, headers: Dictionary = {}, terminal_id: int = 0) -> Dictionary:
	if not _ready:
		return {"ok": false, "code": "INVALID_CONTENT", "text": _error, "body": _error, "title": "ERROR", "links": [], "can_archive": false, "url": url, "status": 503, "changed": false}
	if not method.to_upper() in ["GET", "POST", "PUT", "PATCH", "DELETE"]:
		return _runtime._web_error("INVALID_METHOD", "Unsupported virtual method.", 405, url)
	if terminal_id < 0 or terminal_id > 3:
		return _runtime._web_error("INVALID_TERMINAL", "Terminal ID must be 0–3.", 400, url)
	if not _runtime._json_value(body, 8) or not _runtime._json_value(headers, 8):
		return _runtime._web_error("INVALID_ARGUMENTS", "Request fields must be bounded JSON values.", 400, url)
	var before: Dictionary = _runtime.checkpoint()
	_runtime.select_terminal(terminal_id)
	var result: Dictionary = _runtime.request_page(method, url, body, headers)
	if not result.ok and not result.get("changed", false):
		_runtime.rollback(before)
	_sync()
	return result


func collect_web(url: String) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	var result: Dictionary = _runtime.collect_page(url)
	_sync()
	return result


func use_tool(tool_id: String, params: Dictionary = {}) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	var before: Dictionary = _runtime.checkpoint()
	var terminal: Variant = params.get("terminal_id", 0)
	if not typeof(terminal) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(terminal)) or float(terminal) != floor(float(terminal)) or not _runtime.select_terminal(int(terminal)):
		return _result(false, "INVALID_TERMINAL", "Terminal ID must be 0–3.")
	var id: String = str(params.get("challenge_id", tool_id))
	var result: Dictionary
	if _definition.missions[_current].challenges.has(id):
		var input: Variant = params.get("input", params.duplicate(true))
		if input is Dictionary or input is Array:
			input = input.duplicate(true)
		if input is Dictionary:
			input.erase("challenge_id")
			input.erase("terminal_id")
		result = _runtime.use_challenge(id, input)
	elif tool_id.to_lower() in ["netprobe", "traceroute"]:
		result = execute(("nmap " if tool_id.to_lower() == "netprobe" else "traceroute ") + str(params.get("target", "")), int(params.get("terminal_id", 0)))
	elif tool_id.to_lower() in ["filelens", "loglens"]:
		result = _runtime._cat([str(params.get("path", ""))])
	elif tool_id.to_lower() == "requestlab" and params.has("url"):
		result = request(str(params.get("method", "GET")), params.url, params.get("body", {}), params.get("headers", {}), int(terminal))
	else:
		result = _result(false, "UNKNOWN_TOOL", "Unknown tool or challenge.")
	if not result.ok and not result.get("changed", false):
		_runtime.rollback(before)
	_sync()
	return result


func choose_mission(id: String) -> Dictionary:
	if not _ready or not _definition.missions.has(id):
		return _result(false, "UNKNOWN_MISSION", "Unknown campaign case.")
	if not _available(id):
		return _result(false, "MISSION_LOCKED", "Complete the prerequisite story cases first.")
	_sync()
	var candidate = Runtime.new()
	candidate.configure(_definition.missions[id])
	if _states.has(id):
		var checked: Dictionary = candidate.validate_world(_states[id])
		if not checked.ok:
			return _result(false, "INVALID_CHECKPOINT", checked.text)
		candidate.apply_world(checked.world)
	_runtime = candidate
	_current = id
	_hint_level = 0
	return _result(true, "MISSION_SELECTED", _tr(_definition.missions[id].title), true)


func advance() -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	_sync()
	if not _completed.has(_current):
		return _result(false, "GOAL_NOT_MET", "Current case goals and constraints are not complete.")
	for id in _definition.mission_order:
		if not _definition.missions[id].optional and not _completed.has(id) and _available(id):
			return choose_mission(id)
	return _result(true, "CAMPAIGN_COMPLETE", "Main campaign complete. Choose an available ending or optional case.")


func choose_ending(choice: String) -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	_sync()
	for id in _definition.mission_order:
		if not _definition.missions[id].optional and not _completed.has(id):
			return _result(false, "ENDING_LOCKED", "Finish the main campaign before choosing its ending.")
	for ending in _definition.endings:
		if ending.id == choice:
			for fact in ending.requires_facts:
				if not _all_facts().has(fact):
					return _result(false, "ENDING_LOCKED", "This ending needs additional evidence.")
			_ending = choice
			_decisions["ending"] = choice
			return _result(true, "ENDING_CHOSEN", _tr(ending.text), true)
	return _result(false, "UNKNOWN_ENDING", "Unknown ending.")


func reset() -> Dictionary:
	if not _ready:
		return _result(false, "INVALID_CONTENT", _error)
	_runtime.configure(_definition.missions[_current])
	_hint_level = 0
	return _result(true, "RESET", "Current case restarted. Saved files and completed story receipts remain unchanged.", true)


func get_hint(level: int = 0) -> Dictionary:
	_hint_level = clampi(level, 0, 2)
	return _result(true, "HINT", get_view().get("hint", ""))


func reveal_contact(id: String) -> Dictionary:
	if not _ready or not CONTACTS.has(id) or not CONTACTS[id].choice or not _completed.has(CONTACTS[id].gate):
		return _result(false, "CONTACT_LOCKED", "This contact has not offered a face reveal yet.")
	_decisions["reveal:" + id] = true
	return _result(true, "CONTACT_REVEALED", _tr(id + "_NAME"), true)


func get_view(terminal_id: int = 0) -> Dictionary:
	if not _ready:
		return {"ready": false, "error": _error, "prompt": "ERROR", "password_pending": false, "messages": [], "files": [], "archive": [], "network": [], "missions": [], "tools": [], "endings": []}
	var view: Dictionary = _runtime.view(terminal_id)
	var missions: Array = []
	for id in _definition.mission_order:
		var mission: Dictionary = _definition.missions[id]
		missions.append({"id": id, "title": _tr(mission.title), "chapter": mission.chapter, "optional": mission.optional, "available": _available(id), "completed": _completed.has(id)})
	var endings: Array = []
	var main_complete := true
	for id in _definition.mission_order:
		if not _definition.missions[id].optional and not _completed.has(id):
			main_complete = false
	for ending in _definition.endings:
		var available: bool = main_complete
		for fact in ending.requires_facts:
			available = available and _all_facts().has(fact)
		endings.append({"id": ending.id, "title": _tr(ending.title), "available": available})
	var hints: Array = []
	for hint in _definition.missions[_current].hints:
		hints.append(_tr(hint))
	view["missions"] = missions
	view["endings"] = endings
	view["ending"] = {}
	for ending in _definition.endings:
		if ending.id == _ending:
			view.ending = {"id": ending.id, "title": _tr(ending.title), "text": _tr(ending.text)}
	view["hints"] = hints
	view["hint_level"] = _hint_level
	view["hint"] = hints[mini(_hint_level, hints.size() - 1)] if not hints.is_empty() else ""
	view["can_advance"] = _completed.has(_current)
	view["completion_recorded"] = _completed.has(_current)
	view["current_goals_met"] = _runtime._world.completed
	view["characters"] = _characters()
	return view.duplicate(true)


func autocomplete(input: String, terminal_id: int = 0) -> PackedStringArray:
	if not _ready:
		return PackedStringArray()
	return _runtime.complete(input, terminal_id)


func export_snapshot() -> Dictionary:
	_sync()
	return {"save_version": 2, "campaign_id": _definition.get("campaign_id", ""), "content_version": _definition.get("content_version", 1), "current_mission": _current, "current_world": _runtime.snapshot_world() if _ready else {}, "completed": _completed.duplicate(), "mission_states": _states.duplicate(true), "decisions": _decisions.duplicate(true), "ending": _ending}


func restore_snapshot(raw: Variant) -> Dictionary:
	var checked: Dictionary = _validate_snapshot(raw)
	if not checked.ok:
		return _result(false, "INVALID_SNAPSHOT", checked.text)
	_apply(checked.snapshot)
	return _result(true, "RESTORED", "Campaign progress restored.", true)


func _validate_snapshot(raw: Variant) -> Dictionary:
	if not _ready or not raw is Dictionary or raw.size() != SAVE_KEYS.size() or not raw.has_all(SAVE_KEYS):
		return {"ok": false, "text": "Campaign snapshot shape mismatch."}
	if not _runtime._json_value(raw):
		return {"ok": false, "text": "Campaign snapshots require bounded JSON values."}
	if not typeof(raw.save_version) in [TYPE_INT, TYPE_FLOAT] or raw.save_version != 2 or not raw.current_mission is String or raw.campaign_id != _definition.campaign_id or not typeof(raw.content_version) in [TYPE_INT, TYPE_FLOAT] or raw.content_version != _definition.content_version or not _definition.missions.has(raw.current_mission) or not raw.mission_states is Dictionary or not raw.completed is Array or not raw.decisions is Dictionary or not raw.ending is String:
		return {"ok": false, "text": "Campaign version/ID/reference mismatch. Legacy M01 requires explicit import."}
	if raw.completed.size() > _definition.missions.size() or raw.mission_states.size() > _definition.missions.size():
		return {"ok": false, "text": "Campaign state count exceeds registered cases."}
	var normalized: Dictionary = raw.duplicate(true)
	normalized.save_version = 2
	normalized.content_version = int(_definition.content_version)
	var seen: Array = []
	for id in raw.completed:
		if not id is String or seen.has(id) or not _definition.missions.has(id) or not raw.mission_states.has(id):
			return {"ok": false, "text": "Unknown/duplicate completed mission."}
		seen.append(id)
	for id in raw.mission_states:
		if not _definition.missions.has(id):
			return {"ok": false, "text": "Unknown mission checkpoint."}
		var candidate = Runtime.new()
		candidate.configure(_definition.missions[id])
		var checked: Dictionary = candidate.validate_world(raw.mission_states[id])
		if not checked.ok or checked.world.completed != raw.completed.has(id):
			return {"ok": false, "text": "Invalid checkpoint " + str(id) + ": " + checked.get("text", "goal mismatch")}
		for prerequisite in _definition.missions[id].prerequisites:
			if not raw.completed.has(prerequisite):
				return {"ok": false, "text": "Checkpoint prerequisite not complete."}
		normalized.mission_states[id] = checked.world
	for prerequisite in _definition.missions[raw.current_mission].prerequisites:
		if not raw.completed.has(prerequisite):
			return {"ok": false, "text": "Current mission prerequisite not complete."}
	var active = Runtime.new()
	active.configure(_definition.missions[raw.current_mission])
	var active_checked: Dictionary = active.validate_world(raw.current_world)
	if not active_checked.ok:
		return {"ok": false, "text": active_checked.text}
	normalized.current_world = active_checked.world
	for key in raw.decisions:
		if key == "ending":
			if raw.ending.is_empty() or raw.decisions[key] != raw.ending:
				return {"ok": false, "text": "Invalid ending decision."}
		elif key in ["reveal:C01", "reveal:C03"]:
			var id: String = str(key).trim_prefix("reveal:")
			if not raw.decisions[key] is bool or raw.decisions[key] != true or not raw.completed.has(CONTACTS[id].gate):
				return {"ok": false, "text": "Contact reveal prerequisites not met."}
		else:
			return {"ok": false, "text": "Unknown story decision."}
	if not raw.ending.is_empty() and raw.decisions.get("ending", "") != raw.ending:
		return {"ok": false, "text": "Invalid story decision."}
	if not raw.ending.is_empty():
		var valid := false
		for ending in _definition.endings:
			if ending.id == raw.ending:
				valid = true
				for fact in ending.requires_facts:
					valid = valid and _facts_in(normalized.mission_states).has(fact)
		for id in _definition.mission_order:
			if not _definition.missions[id].optional and not raw.completed.has(id):
				valid = false
		if not valid:
			return {"ok": false, "text": "Ending requirements not met."}
	return {"ok": true, "snapshot": normalized, "text": "Validated"}


func save_game() -> Dictionary:
	return _store_result(_store.save(export_snapshot(), Callable(self, "_validate_snapshot"), _save_path))


func load_game() -> Dictionary:
	var result: Dictionary = _store.load_save(Callable(self, "_validate_snapshot"), _save_path)
	if result.ok:
		_apply(result.snapshot)
	return _store_result(result)


func recover_save() -> Dictionary:
	var result: Dictionary = _store.recover_backup(Callable(self, "_validate_snapshot"), _save_path)
	if result.ok:
		_apply(result.snapshot)
	return _store_result(result)


func start_new_save() -> Dictionary:
	return _store_result(_store.start_new(export_snapshot(), Callable(self, "_validate_snapshot"), _save_path))


func import_m01(raw: Variant) -> Dictionary:
	if not _ready or not _definition.missions.has("M01"):
		return _result(false, "INVALID_CONTENT", _error)
	var old = Legacy.new()
	var accepted: Dictionary = old.restore_snapshot(raw)
	if not accepted.ok:
		return accepted
	var legacy: Dictionary = old.export_snapshot().world
	var candidate = Runtime.new()
	candidate.configure(_definition.missions.M01)
	for path in legacy.local_files:
		var entry: Dictionary = legacy.local_files[path]
		if entry.kind == "file" and candidate._record_valid(entry):
			candidate._world.local_files[path] = entry.duplicate(true)
	candidate._evaluate_completion()
	if legacy.completed and not candidate._world.completed:
		return _result(false, "INCOMPATIBLE_M01", "Legacy M01 is valid, but its canonical record cannot be mapped to this content version. Original save remains untouched.")
	_runtime = candidate
	_current = "M01"
	_completed = []
	_states = {}
	_decisions = {}
	_ending = ""
	_sync()
	return _result(true, "IMPORTED_M01", "Validated legacy M01 imported into campaign memory. Save explicitly to the separate campaign slot.", true)


func import_legacy_save() -> Dictionary:
	var loaded: Dictionary = _read_legacy_save()
	if not loaded.ok:
		return loaded
	return import_m01(loaded.snapshot)


func _read_legacy_save() -> Dictionary:
	const LEGACY_PATH := "user://saves/slot_01.json"
	var file := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		return _result(false, "LEGACY_NOT_FOUND", "Legacy M01 save could not be read.")
	if file.get_length() > Store.MAX_BYTES:
		file.close()
		return _result(false, "LEGACY_SIZE_LIMIT", "Legacy save exceeds 2 MiB.")
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		return _result(false, "LEGACY_INVALID_JSON", "Legacy save JSON is damaged. Original file is unchanged.")
	var legacy = Legacy.new()
	var checked: Dictionary = legacy.restore_snapshot(parser.data)
	if not checked.ok:
		return checked
	return {"ok": true, "snapshot": legacy.export_snapshot(), "code": "LEGACY_VALIDATED", "text": "Legacy save validated."}


func get_save_status() -> Dictionary:
	var guard: Dictionary = _store._guard(_save_path, Callable(self, "_validate_snapshot"))
	if not _ready or not guard.ok:
		return {"exists": false, "backup_available": false, "legacy_available": false}
	var loaded: Dictionary = _store.load_save(Callable(self, "_validate_snapshot"), _save_path)
	var backup: Dictionary = _store._read_snapshot(_save_path + ".bak", Callable(self, "_validate_snapshot"))
	return {"exists": FileAccess.file_exists(_save_path), "valid": loaded.ok, "backup_available": backup.ok, "legacy_available": _read_legacy_save().ok}


func _apply(snapshot: Dictionary) -> void:
	_current = snapshot.current_mission
	_completed = snapshot.completed.duplicate()
	_states = snapshot.mission_states.duplicate(true)
	_decisions = snapshot.decisions.duplicate(true)
	_ending = snapshot.ending
	_runtime = Runtime.new()
	_runtime.configure(_definition.missions[_current])
	_runtime.apply_world(snapshot.current_world)


func _sync() -> void:
	if not _ready:
		return
	var world: Dictionary = _runtime.snapshot_world()
	if world.completed and not _completed.has(_current):
		_completed.append(_current)
	if not _completed.has(_current) or world.completed:
		_states[_current] = world


func _available(id: String) -> bool:
	for prerequisite in _definition.missions[id].prerequisites:
		if not _completed.has(prerequisite):
			return false
	return true


func _all_facts() -> Array:
	var facts: Array = _facts_in(_states)
	if _ready:
		for fact in _runtime._world.facts:
			if not facts.has(fact):
				facts.append(fact)
	return facts


func _characters() -> Array:
	var result: Array = []
	for id in CONTACTS:
		var contact: Dictionary = CONTACTS[id]
		if _current != contact.met and not _states.has(contact.met) and not _completed.has(contact.met):
			continue
		var reached: bool = _completed.has(contact.gate)
		var revealed: bool = _decisions.get("reveal:" + id, false) if contact.choice else (reached or (id == "C02" and _current == "M02"))
		if id == "C02":
			revealed = _current == "M02" or _states.has("M02") or _completed.has("M02")
		var portrait_expression := "guarded" if not revealed else "focused"
		if revealed and _completed.has("M24"):
			portrait_expression = "relieved"
		if id == "C02" and not _completed.has("M24"):
			portrait_expression = "neutral"
		result.append({"id": id, "name": _tr(id + "_NAME"), "face_revealed": revealed, "can_reveal": contact.choice and reached and not revealed, "expression": portrait_expression})
	return result


func _facts_in(states: Dictionary) -> Array:
	var facts: Array = []
	for world in states.values():
		for fact in world.get("facts", []):
			if not facts.has(fact):
				facts.append(fact)
	return facts


func _tr(key: String) -> String:
	return str(TranslationServer.translate(key))


func _store_result(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	var key: String = "CAMPAIGN_RESULT_" + str(result.get("code", ""))
	var translated: String = _tr(key)
	if translated != key:
		result["technical_detail"] = result.get("text", "") if not result.ok else ""
		result["text"] = translated.format({"detail": ""})
		result["text_key"] = key
		result["text_vars"] = {"detail": ""}
	return result


func _result(ok: bool, code: String, text: String, changed: bool = false) -> Dictionary:
	var key: String = "CAMPAIGN_RESULT_" + code
	var translated: String = _tr(key)
	var shown: String = translated.format({"detail": text}) if translated != key else text
	return {"ok": ok, "code": code, "text": shown, "text_key": key, "text_vars": {"detail": text}, "changed": changed, "needs_password": false, "event": ""}
