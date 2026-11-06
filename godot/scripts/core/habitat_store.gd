extends RefCounted
## In-game room purchases and one optional cabinet job, isolated from campaign saves.

const SaveStore = preload("res://scripts/core/save_store.gd")
const PATH := "user://saves/habitat_01.json"
const HABITAT_ID := "midnight_habitat"
const STARTING_CREDITS := 1500
const JOB_REWARD := 200
const MAX_ACTIONS := 128
const STARTERS := ["keyboard_starter", "monitor_starter", "lamp_starter"]
const SLOTS := ["keyboard", "monitor", "lamp"]
const ROUTES := ["public", "service", "approved_relay", "off"]
const CATALOG := {
	"keyboard_starter": {"slot": "keyboard", "price": 0, "label_key": "HAB_PRODUCT_KEYBOARD_STARTER", "style_id": "graphite", "visual": {"body": "222629", "keycaps": "444b50", "accent": "87cbbd"}},
	"keyboard_ivory": {"slot": "keyboard", "price": 180, "label_key": "HAB_PRODUCT_KEYBOARD_IVORY", "style_id": "ivory", "visual": {"body": "e4d9bd", "keycaps": "faf5e8", "accent": "698f86"}},
	"keyboard_coral": {"slot": "keyboard", "price": 220, "label_key": "HAB_PRODUCT_KEYBOARD_CORAL", "style_id": "coral", "visual": {"body": "b85450", "keycaps": "f0d7c6", "accent": "74cbbb"}},
	"monitor_starter": {"slot": "monitor", "price": 0, "label_key": "HAB_PRODUCT_MONITOR_STARTER", "style_id": "standard", "visual": {"layout": "standard", "frame": "20272a", "glow": "67a6b7"}},
	"monitor_wide": {"slot": "monitor", "price": 320, "label_key": "HAB_PRODUCT_MONITOR_WIDE", "style_id": "wide", "visual": {"layout": "wide", "frame": "353039", "glow": "b6a2d9"}},
	"monitor_dual": {"slot": "monitor", "price": 500, "label_key": "HAB_PRODUCT_MONITOR_DUAL", "style_id": "dual", "visual": {"layout": "dual", "frame": "293b35", "glow": "95d8b9"}},
	"lamp_starter": {"slot": "lamp", "price": 0, "label_key": "HAB_PRODUCT_LAMP_STARTER", "style_id": "warm", "visual": {"tint": "ffc487", "energy": 0.8}},
	"lamp_cool": {"slot": "lamp", "price": 100, "label_key": "HAB_PRODUCT_LAMP_COOL", "style_id": "cool", "visual": {"tint": "a5d4ff", "energy": 1.0}},
}

var _path: String
var _store := SaveStore.new()
var _snapshot: Dictionary
var _loaded := false
var _writable := false
var _backup_available := false
var _last_code := "HABITAT_NOT_LOADED"
var _last_text := "Room state has not been loaded."


func _init(path: String = PATH) -> void:
	_path = path
	_snapshot = _fresh_snapshot()


func load_state() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok:
		return _remember_failure(guard)
	var status: Dictionary = _store.path_status(_path, validate_snapshot)
	if not status.ok:
		return _remember_failure(status)
	if not status.exists:
		if status.backup_exists:
			var missing: Dictionary = _store.load_save(validate_snapshot, _path)
			return _remember_failure(missing)
		_snapshot = _fresh_snapshot()
		_loaded = true
		_writable = true
		return _success("HABITAT_NEW", "Starter room is ready; no save has been written.", false)
	var loaded: Dictionary = _store.load_save(validate_snapshot, _path)
	if not loaded.ok:
		return _remember_failure(loaded)
	_snapshot = loaded.snapshot.duplicate(true)
	_loaded = true
	_writable = true
	return _success("HABITAT_LOADED", "Room state loaded.", false)


func apply(action: String, params: Dictionary = {}) -> Dictionary:
	if not _loaded:
		var loaded: Dictionary = load_state()
		if not loaded.ok:
			return loaded
	if not _writable:
		return _failure("HABITAT_RECOVERY_REQUIRED", "Recover the existing room save before making changes.")
	var guard: Dictionary = _guard()
	if not guard.ok:
		return guard
	var transition: Dictionary = _transition(_snapshot.state, action, params)
	if not transition.ok:
		return transition
	if transition.state.recursive_equal(_snapshot.state, 0):
		return _success(transition.code, transition.text, false)
	var candidate: Dictionary = _snapshot.duplicate(true)
	# Cosmetic choices do not affect purchases or job evidence; retain only their latest value.
	if action in ["equip", "set_lighting"]:
		var retained: Array = []
		for event in candidate.actions:
			if event.action == action and (action == "set_lighting" or event.params.slot == params.slot): continue
			retained.append(event)
		candidate["actions"] = retained
	candidate["actions"].append({"action": action, "params": params.duplicate(true)})
	candidate["state"] = transition.state
	var compacted: Dictionary = _compact_history(candidate)
	if not compacted.ok:
		return compacted
	candidate = compacted.snapshot
	var saved: Dictionary = _store.save(candidate, validate_snapshot, _path)
	if not saved.ok:
		if saved.get("code") == "SAVE_RECOVERY_REQUIRED":
			return _remember_failure(saved)
		return saved
	_snapshot = candidate
	return _success(transition.code, transition.text, true)


func recover_backup() -> Dictionary:
	var guard: Dictionary = _guard()
	if not guard.ok:
		return guard
	var recovered: Dictionary = _store.recover_backup(validate_snapshot, _path)
	if not recovered.ok:
		if not _writable:
			return _remember_failure(recovered)
		return recovered
	_snapshot = recovered.snapshot.duplicate(true)
	_loaded = true
	_writable = true
	var result: Dictionary = _success("HABITAT_RECOVERED", "Room backup recovered; damaged original preserved.", true)
	result["damaged_path"] = recovered.get("damaged_path", "")
	return result


func get_view() -> Dictionary:
	var view: Dictionary = _snapshot.state.duplicate(true)
	view["ready"] = _loaded and _writable
	view["backup_available"] = _backup_available
	view["recovery_available"] = not _writable and _backup_available
	view["code"] = _last_code
	view["text"] = _last_text
	view["catalog"] = []
	for id in CATALOG:
		var product: Dictionary = CATALOG[id].duplicate(true)
		product["id"] = id
		view.catalog.append(product)
	var deliveries := 0
	for order in view.orders:
		if order.status == "ready": deliveries += 1
	view["ready_delivery_count"] = deliveries
	return view


func export_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func validate_snapshot(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _keys(raw, ["save_version", "habitat_id", "actions", "state"], true) or not _integer(raw.get("save_version"), 1, 1) or not raw.get("habitat_id") is String or raw.habitat_id != HABITAT_ID:
		return _failure("HABITAT_INVALID_SAVE", "Unknown room save version or identity.")
	if not raw.actions is Array or raw.actions.size() > MAX_ACTIONS or not raw.state is Dictionary or not _json_value(raw, 8) or JSON.stringify(raw).to_utf8_buffer().size() > 65536:
		return _failure("HABITAT_INVALID_SAVE", "Room save exceeds its shape or size bounds.")
	var canonical: Dictionary = _normalize(raw)
	var state: Dictionary = _fresh_state()
	for index in canonical.actions.size():
		var event: Variant = canonical.actions[index]
		if not event is Dictionary or not _keys(event, ["action", "params"], true) or not event.action is String or not event.params is Dictionary:
			return _failure("HABITAT_INVALID_SAVE", "Malformed room action history.")
		var step: Dictionary = _transition(state, event.action, event.params)
		if not step.ok:
			return _failure("HABITAT_INVALID_SAVE", "Impossible purchase, equipment or cabinet action.")
		state = step.state
	if not state.recursive_equal(canonical.state, 0):
		return _failure("HABITAT_INVALID_SAVE", "Wallet, ownership or cabinet evidence does not match its actions.")
	return {"ok": true, "snapshot": {"save_version": 1, "habitat_id": HABITAT_ID, "actions": canonical.actions, "state": state}}


func _compact_history(snapshot: Dictionary) -> Dictionary:
	var state: Dictionary = _fresh_state()
	var configurations: Array[int] = []
	var reward_configuration := -1
	var reward_verification := -1
	var last_verification := -1
	for index in snapshot.actions.size():
		var event: Dictionary = snapshot.actions[index]
		var step: Dictionary = _transition(state, event.action, event.params)
		if not step.ok:
			return step
		if event.action == "configure_cabinet" and not step.state.job.recursive_equal(state.job, 0):
			configurations.append(index)
		elif event.action == "verify_job":
			last_verification = index
			if not state.job.rewarded and step.state.job.rewarded:
				reward_verification = index
				if not configurations.is_empty(): reward_configuration = configurations.back()
		state = step.state
	var retained: Array = []
	var last_configuration: int = configurations.back() if not configurations.is_empty() else -1
	for index in snapshot.actions.size():
		var event: Dictionary = snapshot.actions[index]
		if event.action == "configure_cabinet":
			# Two final configurations preserve invalidation when returning to the reward route.
			if index != reward_configuration and not configurations.slice(-2).has(index): continue
		elif event.action == "verify_job":
			# Keep the first successful check as financial proof, plus the current check if any.
			if index != reward_verification and not (index == last_verification and index > last_configuration): continue
		retained.append(event)
	var compacted: Dictionary = snapshot.duplicate(true)
	compacted["actions"] = retained
	# Replay from authored defaults must reproduce every field; never trust a state checkpoint.
	return validate_snapshot(compacted)


func _guard() -> Dictionary:
	if _path != PATH:
		if not _path.begins_with("user://tests/") or not _path.ends_with(".json") or _path.contains("\\") or _path.trim_prefix("user://").contains(":"):
			return _failure("HABITAT_PATH_REJECTED", "Only the fixed room slot or isolated test JSON paths are allowed.")
		for part in _path.trim_prefix("user://").split("/"):
			if part.is_empty() or part in [".", ".."]:
				return _failure("HABITAT_PATH_REJECTED", "Invalid room path component.")
		for index in _path.length():
			if _path.unicode_at(index) < 32 or _path.unicode_at(index) == 127:
				return _failure("HABITAT_PATH_REJECTED", "Invalid room path character.")
	return _store.path_status(_path, validate_snapshot)


func _remember_failure(result: Dictionary) -> Dictionary:
	_loaded = true
	_writable = false
	_backup_available = bool(result.get("backup_available", _backup_available))
	_last_code = str(result.get("code", "HABITAT_LOAD_FAILED"))
	_last_text = str(result.get("text", "Room state could not be loaded."))
	return result


func _success(code: String, text: String, changed: bool) -> Dictionary:
	_backup_available = false
	_last_code = code
	_last_text = text
	return {"ok": true, "code": code, "text": text, "changed": changed}


static func _fresh_snapshot() -> Dictionary:
	return {"save_version": 1, "habitat_id": HABITAT_ID, "actions": [], "state": _fresh_state()}


static func _fresh_state() -> Dictionary:
	return {"balance": STARTING_CREDITS, "earned": 0, "orders": [], "owned": STARTERS.duplicate(), "equipped": {"keyboard": "keyboard_starter", "monitor": "monitor_starter", "lamp": "lamp_starter"}, "lighting": "night", "job": {"accepted": false, "inspected": false, "route": "public", "locked": false, "current_check": {}, "rewarded": false, "reward_receipt": {}}}


static func _transition(previous: Dictionary, action: String, params: Dictionary) -> Dictionary:
	var fields: Dictionary = {"order": ["product_id"], "collect_delivery": [], "equip": ["slot", "product_id"], "set_lighting": ["lighting"], "accept_job": ["job_id"], "inspect_cabinet": [], "configure_cabinet": ["route", "locked"], "verify_job": []}
	if not fields.has(action) or not _keys(params, fields[action], true):
		return _failure("HABITAT_INVALID_ACTION", "Unknown room action or fields.")
	var state: Dictionary = previous.duplicate(true)
	var code := "HABITAT_UPDATED"
	match action:
		"order":
			var id: Variant = params.get("product_id")
			if not id is String or not CATALOG.has(id): return _failure("HABITAT_UNKNOWN_PRODUCT", "Unknown room product.")
			if state.owned.has(id): return _failure("HABITAT_ALREADY_OWNED", "This product is already owned.")
			for order in state.orders:
				if order.product_id == id: return _failure("HABITAT_ALREADY_ORDERED", "This product already has an order.")
			if state.orders.size() >= 16: return _failure("HABITAT_ORDER_LIMIT", "Room order limit reached.")
			var price: int = CATALOG[id].price
			if int(state.balance) < price: return _failure("HABITAT_INSUFFICIENT_CREDITS", "Not enough in-game room credits.")
			state["balance"] = int(state.balance) - price
			state["orders"].append({"product_id": id, "price": price, "status": "ready"})
			code = "HABITAT_ORDER_READY"
		"collect_delivery":
			var collected := false
			for order in state.orders:
				if order.status == "ready":
					order["status"] = "collected"
					state["owned"].append(order.product_id)
					collected = true
			if not collected: return _failure("HABITAT_NO_DELIVERIES", "There are no room deliveries to collect.")
			code = "HABITAT_DELIVERY_COLLECTED"
		"equip":
			var slot: Variant = params.get("slot")
			var id: Variant = params.get("product_id")
			if not slot is String or not SLOTS.has(slot) or not id is String or not CATALOG.has(id) or CATALOG[id].slot != slot or not state.owned.has(id): return _failure("HABITAT_INVALID_EQUIPMENT", "Collect a matching owned product before equipping it.")
			state["equipped"][slot] = id
			code = "HABITAT_EQUIPPED"
		"set_lighting":
			var lighting: Variant = params.get("lighting")
			if not lighting is String or not lighting in ["night", "dawn"]: return _failure("HABITAT_INVALID_LIGHTING", "Unknown room lighting scene.")
			state["lighting"] = lighting
			code = "HABITAT_LIGHTING_SET"
		"accept_job":
			if not params.get("job_id") is String or params.job_id != "network_cabinet": return _failure("HABITAT_UNKNOWN_JOB", "Unknown room job.")
			if state.job.accepted: return _failure("HABITAT_JOB_ACCEPTED", "This room job is already accepted.")
			state["job"]["accepted"] = true
			code = "HABITAT_JOB_ACCEPTED"
		"inspect_cabinet":
			if not state.job.accepted: return _failure("HABITAT_JOB_REQUIRED", "Accept the cabinet job first.")
			state["job"]["inspected"] = true
			code = "HABITAT_CABINET_INSPECTED"
		"configure_cabinet":
			if not state.job.accepted or not state.job.inspected: return _failure("HABITAT_INSPECTION_REQUIRED", "Inspect the accepted cabinet job before changing it.")
			if not params.get("route") is String or not ROUTES.has(params.route) or not params.get("locked") is bool: return _failure("HABITAT_INVALID_CONFIG", "Select a registered cabinet route and lock state.")
			if state.job.route != params.route or state.job.locked != params.locked:
				state["job"]["route"] = params.route
				state["job"]["locked"] = params.locked
				state["job"]["current_check"] = {}
			code = "HABITAT_CABINET_CONFIGURED"
		"verify_job":
			if not state.job.accepted or not state.job.inspected: return _failure("HABITAT_INSPECTION_REQUIRED", "Inspect the accepted cabinet job before verifying it.")
			var normal: bool = state.job.route != "off"
			var unauthorized: bool = state.job.route == "public" or (normal and not state.job.locked)
			var passed: bool = normal and not unauthorized
			var receipt: Dictionary = {"job_id": "network_cabinet", "route": state.job.route, "locked": state.job.locked, "normal_telemetry": normal, "unauthorized_access": unauthorized, "passed": passed}
			state["job"]["current_check"] = receipt.duplicate(true)
			if passed and not state.job.rewarded:
				state["earned"] = JOB_REWARD
				state["balance"] = int(state.balance) + JOB_REWARD
				state["job"]["rewarded"] = true
				state["job"]["reward_receipt"] = receipt
			code = "HABITAT_JOB_VERIFIED" if passed else "HABITAT_JOB_CHECK_FAILED"
	return {"ok": true, "code": code, "text": "Room action completed.", "state": state}


static func _keys(value: Dictionary, expected: Array, exact := false) -> bool:
	if exact and value.size() != expected.size(): return false
	for key in value:
		if not key is String or not expected.has(key): return false
	return true


static func _json_value(value: Variant, depth: int) -> bool:
	if depth < 0: return false
	if value is String: return value.length() <= 1024
	if value is bool or value == null: return true
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]: return _integer(value, -1000000, 1000000)
	if value is Array:
		if value.size() > MAX_ACTIONS: return false
		for entry in value:
			if not _json_value(entry, depth - 1): return false
		return true
	if value is Dictionary:
		if value.size() > 64: return false
		for key in value:
			if not key is String or key.length() > 64 or not _json_value(value[key], depth - 1): return false
		return true
	return false


static func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _normalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(_normalize(entry))
		return result
	if typeof(value) == TYPE_FLOAT: return int(value)
	return value


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _failure(code: String, text: String) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "changed": false}
