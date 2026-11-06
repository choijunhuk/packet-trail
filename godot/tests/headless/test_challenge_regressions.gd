extends "res://tests/headless/test_mutation_limits.gd"
## Independent challenge checks use real actions and distinct resulting state.

const CHALLENGE_FIXTURE := "res://tests/fixtures/challenge_solutions.json"
const ObservationCase = preload("res://scripts/core/observation_case.gd")
const ResponseLab = preload("res://scripts/core/response_lab.gd")
var route_worlds: Dictionary = {}
var critical_observations: Array = []


func _new_for_slot(path: String) -> Variant:
	return Campaign.new(path, "challenge")


func _run() -> void:
	var before := _fingerprints()
	test_root = "user://tests/challenge_independent_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var loaded: Dictionary = Loader.load_campaign("challenge")
	_check(loaded.get("ok", false), "challenge definition validates", loaded.get("errors"))
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHALLENGE_FIXTURE))
	_check(raw is Dictionary and raw.get("packs", {}).get("challenge", {}).get("missions") is Dictionary, "independent challenge fixtures exist")
	if loaded.get("ok", false) and raw is Dictionary and raw.get("packs", {}).get("challenge", {}).get("missions") is Dictionary:
		definition = loaded.definition
		solutions = raw.packs.challenge.missions
		_check(definition.mission_order == ["X01", "X02", "X03"], "challenge contains exactly the authored three-case arc")
		for id in definition.mission_order:
			var paths: Array = solutions.get(id, {}).get("paths", [])
			_check(paths.size() == 2, id + ": two action witnesses exist")
			route_worlds[id] = []
			for route in paths:
				var game = _fresh()
				if not _prepare(game, id): continue
				_check(not game.get_view().get("completed", true), id + ": fresh target starts incomplete")
				if not _replay(game, route.get("actions", []), id + "/" + str(route.get("id"))): continue
				_check(game.get_view().get("completed", false), id + ": actual route satisfies goals")
				_round_trip(game, id + ": completed route remains saveable")
				route_worlds[id].append(game.export_snapshot().current_world.duplicate(true))
				_test_unknown_action(game, id)
				if id in ["X01", "X02"]: _test_stale_basis(game, id)
			_test_negative_recovery(id, paths[0] if not paths.is_empty() else {})
			if id == "X02" and not paths.is_empty(): _test_world_writable(paths[0])
			if id == "X03" and not paths.is_empty(): _test_uncited_and_client_only(paths[0])
			if route_worlds[id].size() == 2:
				_assert_distinct(id, route_worlds[id][0], route_worlds[id][1])
	if not solutions.is_empty():
		_test_corrupted_write_completion()
		_test_baseline_first_auth_recovery()
		_test_notification_scope_counterexample()
		_test_single_source_handoff()
		_test_audit_authority_and_clock_order()
	_check(_fingerprints() == before, "all default user files unchanged")
	_cleanup(test_root)
	print(JSON.stringify({"suite": "challenge_regressions", "checks": checks, "failures": failures, "critical_observations": critical_observations, "route_world_counts": route_worlds.keys().map(func(id): return {"mission": id, "routes": route_worlds[id].size()}), "limit": "Independent real-action state/restore checks; native input and human difficulty are separate."}))
	quit(0 if failures.is_empty() else 1)


func _test_unknown_action(game: Variant, id: String) -> void:
	var before: Dictionary = game.export_snapshot()
	var result: Dictionary = game.use_tool("unregistered_challenge_tool", {"action": "probe"})
	_check(not result.get("ok", true), id + ": unregistered tool cannot fabricate progress")
	_check(_same(game.export_snapshot(), before), id + ": rejected action preserves all canonical state")


func _assert_distinct(id: String, a: Dictionary, b: Dictionary) -> void:
	match id:
		"X01":
			_check(not _same(a.policies, b.policies), "X01 routes leave actually different availability/security policies")
			_check(_response_endpoints(a) != _response_endpoints(b), "X01 normal requests actually use different endpoints")
		"X02":
			_check(not _write_paths(a).is_empty() and not _write_paths(b).is_empty() and _write_paths(a) != _write_paths(b), "X02 routes actually write the required body to distinct registered files")
			_check(_response_endpoints(a) != _response_endpoints(b), "X02 routes deliver work through distinct endpoints")
		"X03":
			_check(_sensor_sources(a) != _sensor_sources(b), "X03 alternatives cite genuinely different sensor/source provenance")


func _response_endpoints(world: Dictionary) -> Array:
	var endpoints: Array = []
	for state in world.model_states.values():
		for receipt in state.get("probe_receipts", {}).values():
			if receipt.get("business_ok", false) or receipt.get("status", 0) == 200:
				var value := str(receipt.get("endpoint_id", ""))
				if not endpoints.has(value): endpoints.append(value)
	endpoints.sort()
	return endpoints


func _write_paths(world: Dictionary) -> Array:
	var paths: Array = []
	for state in world.model_states.values():
		for host in state.get("file_overrides", {}):
			for path in state.file_overrides[host]:
				var entry: Dictionary = state.file_overrides[host][path]
				if entry.get("kind") == "file" and entry.get("content") == "DEPLOYMENT READY\n":
					paths.append(str(host) + ":" + str(path))
	paths.sort()
	return paths


func _sensor_sources(world: Dictionary) -> Array:
	var sources: Array = []
	for state in world.model_states.values():
		for observation in state.get("observations", {}).values():
			var value := str(observation.get("sensor_id", "")) + ":" + JSON.stringify(observation.get("provenance", {}), "", true)
			if not sources.has(value): sources.append(value)
	sources.sort()
	return sources


func _test_stale_basis(game: Variant, id: String) -> void:
	var cid := "ch1_" + id.to_lower() + "_response"
	var model: Dictionary = definition.missions[id].challenges[cid]
	var before: Dictionary = game.export_snapshot().current_world
	_check(ResponseLab.goal_met(model, before.model_states[cid], game._runtime._model_context()), id + ": final receipts prove current business matrix")
	var control := "direct_open" if id == "X01" else "notify_open"
	var current: bool = bool(before.policies.get(model.controls[control].policy_id, false))
	var changed: Dictionary = game.use_tool(cid, {"action": "set_control", "control_id": control, "value": not current})
	_check(changed.get("ok", false), id + ": legitimate later policy change is executable")
	var world: Dictionary = game.export_snapshot().current_world
	_check(not ResponseLab.goal_met(model, world.model_states[cid], game._runtime._model_context()), id + ": stale successful receipts cannot certify changed current policy")
	_round_trip(game, id + ": post-completion changed policy remains restorable")


func _test_negative_recovery(id: String, route: Dictionary) -> void:
	if route.is_empty(): return
	var game = _fresh()
	if not _prepare(game, id): return
	var actions: Array = route.actions
	if id == "X03":
		if not _replay(game, actions.slice(0, actions.size() - 1), "X03 gather actual cited evidence before handoff"): return
		_check(not game.get_view().get("completed", true), "X03 evidence alone is not a completed handoff")
		var wrong: Dictionary = actions.back().duplicate(true)
		wrong.params.next_sensor_id = "ch1_x03_address_watch"
		var snapshot: Dictionary = game.export_snapshot()
		var failed: Dictionary = _action(game, wrong)
		_check(not failed.get("ok", true) and failed.get("code") == "HANDOFF_INCOMPLETE", "X03 supported claims with wrong next observation point are rejected")
		_check(_same(snapshot, game.export_snapshot()), "X03 rejected handoff preserves prior evidence and state")
		_check(_replay(game, [actions.back()], "X03 recover with actual valid next observation point") and game.get_view().get("completed", false), "X03 failed handoff can be corrected without reset")
		return
	if not _replay(game, actions.slice(0, 2), id + " authenticate before negative policy actions"): return
	var cid := "ch1_" + id.to_lower() + "_response"
	var model: Dictionary = definition.missions[id].challenges[cid]
	var availability: Array = ["direct_open", "gateway_open"] if id == "X01" else ["notify_open", "standby_open"]
	for control in availability:
		var result: Dictionary = game.use_tool(cid, {"action": "set_control", "control_id": control, "value": false})
		_check(result.get("ok", false), id + ": closing a registered service executes")
	for case_id in model.cases:
		game.use_tool(cid, {"action": "probe", "case_id": case_id})
	var bad_world: Dictionary = game.export_snapshot().current_world
	var receipts: Dictionary = bad_world.model_states[cid].get("probe_receipts", {})
	_check(receipts.size() == model.cases.size(), id + ": all-off negative has every receipt, not missing evidence")
	var normal_outages := 0
	for case_id in model.cases:
		if model.cases[case_id].get("class") != "normal": continue
		var receipt: Dictionary = receipts.get(case_id, {})
		if int(receipt.get("status", 0)) == 503:
			normal_outages += 1
			_check(not receipt.get("business", {}).values().has(true), id + ": actual offline normal request has no successful business outcome")
	_check(normal_outages > 0, id + ": all-off actually breaks a normal business request")
	_check(not game.get_view().get("completed", true), id + ": shutting every business path cannot complete the incident")
	_round_trip(game, id + ": mistaken outage saves without destroying recovery")
	for control in availability:
		game.use_tool(cid, {"action": "set_control", "control_id": control, "value": true})
	_local(game)
	_check(_replay(game, actions, id + " recover actual business after wrong shutdown") and game.get_view().get("completed", false), id + ": wrong availability change is recoverable through normal actions")


func _test_world_writable(route: Dictionary) -> void:
	var game = _fresh()
	if not _prepare(game, "X02") or not _replay(game, route.actions.slice(0, 3), "X02 authenticate and grant actual job group"): return
	var cid := "ch1_x02_response"
	for pair in [["directory_mode", "777"], ["file_mode", "666"]]:
		var result: Dictionary = game.use_tool(cid, {"action": "set_control", "control_id": pair[0], "value": pair[1]})
		_check(result.get("ok", false), "X02 writable-to-everyone control is a real available mistake")
	for case_id in definition.missions.X02.challenges[cid].cases:
		game.use_tool(cid, {"action": "probe", "case_id": case_id})
	var world: Dictionary = game.export_snapshot().current_world
	var foreign: Dictionary = world.model_states[cid].probe_receipts.get("foreign_write", {})
	_check(int(foreign.get("status", 0)) == 200, "X02 broad writable modes expose actual outsider write counterexample")
	_check(not game.get_view().get("completed", true), "X02 legitimate work plus exposed outsider write is not completion")
	for pair in [["directory_mode", "750"], ["file_mode", "660"]]:
		game.use_tool(cid, {"action": "set_control", "control_id": pair[0], "value": pair[1]})
	_local(game)
	_check(_replay(game, route.actions, "X02 recover permissions with ordinary policy and probes") and game.get_view().get("completed", false), "X02 overbroad permissions remain repairable")


func _test_uncited_and_client_only(route: Dictionary) -> void:
	var game = _fresh()
	if not _prepare(game, "X03") or not _replay(game, route.actions.slice(0, 2), "X03 authenticate before counterevidence tests"): return
	var cid := "ch1_x03_observations"
	var model: Dictionary = definition.missions.X03.challenges[cid]
	var snapshot: Dictionary = game.export_snapshot()
	var claim: Dictionary = model.initial_claims.prior.claim
	var result: Dictionary = game.use_tool(cid, {"action": "hypothesize", "hypothesis_id": "uncited", "claim": claim, "observation_ids": ["not-collected:any:record"]})
	_check(not result.get("ok", true) and result.get("code") == "INVALID_CLAIM", "X03 invented observation references are rejected")
	_check(_same(snapshot, game.export_snapshot()), "X03 rejected invented citations leave current evidence unchanged")
	result = game.use_tool(cid, {"action": "collect", "sensor_id": "ch1_x03_field"})
	_check(result.get("ok", false), "X03 first public field window is collectable")
	var world: Dictionary = game.export_snapshot().current_world
	var state: Dictionary = world.model_states[cid]
	var assessed: Dictionary = ObservationCase.assess(claim, state.observations.keys(), state)
	_check(assessed.get("verdict") != "supported", "X03 client-supplied shared markers do not establish the same server session")
	result = game.use_tool(cid, {"action": "handoff", "claims": [{"claim": claim, "observation_ids": state.observations.keys()}], "next_sensor_id": "ch1_x03_vault_watch"})
	_check(not result.get("ok", true) and not game.get_view().get("completed", true), "X03 shared-address evidence alone cannot complete a handoff")


func _test_corrupted_write_completion() -> void:
	var cid := "ch1_x02_response"
	var model: Dictionary = definition.missions.X02.challenges[cid]
	for route in solutions.X02.paths:
		var game = _fresh()
		if not _prepare(game, "X02"): continue
		var actions: Array = route.actions
		if not _replay(game, actions.slice(0, actions.size() - 1), "C1 prepare all but final goal receipt"): continue
		_check(not game.get_view().get("completed", true), "C1 exploit begins before first completion")
		var is_direct: bool = route.id == "precise_repair"
		if is_direct:
			for pair in [["directory_mode", "777"], ["file_mode", "666"]]:
				game.use_tool(cid, {"action": "set_control", "control_id": pair[0], "value": pair[1]})
			game.use_tool(cid, {"action": "probe", "case_id": "foreign_write"})
			for pair in [["directory_mode", "750"], ["file_mode", "660"]]:
				game.use_tool(cid, {"action": "set_control", "control_id": pair[0], "value": pair[1]})
			game.use_tool(cid, {"action": "probe", "case_id": "foreign_write"})
		else:
			game.use_tool(cid, {"action": "request", "request": {"method": "POST", "url": "https://gateway.x02.challenge.packet.test/deployment/write", "body": {"content": "UNAUTHORIZED\n"}, "headers": {}}})
		_action(game, actions.back())
		var world: Dictionary = game.export_snapshot().current_world
		var state: Dictionary = world.model_states[cid]
		var host := "ch1_x02_desk" if is_direct else "ch1_x02_gateway"
		var path := "/deploy/status.txt" if is_direct else "/approved/status.txt"
		var files := ResponseLab.effective_files(model, state, game._runtime._model_context(), host)
		var content := str(files.get(path, {}).get("content", ""))
		_check(content == "UNAUTHORIZED\n", "C1 actual exposed write leaves wrong current deployment body: " + str(route.id))
		var met: bool = ResponseLab.goal_met(model, state, game._runtime._model_context())
		critical_observations.append({"case": "C1", "route": route.id, "current_content": content, "completed": game.get_view().get("completed"), "current_goal_met": met})
		_check(not met, "C1 restored permissions and denied outsider cannot certify corrupted current content: " + str(route.id))
		_check(not game.get_view().get("completed", true), "C1 corrupted body cannot trigger initial completion: " + str(route.id))


func _test_baseline_first_auth_recovery() -> void:
	var cid := "ch1_x01_response"
	var model: Dictionary = definition.missions.X01.challenges[cid]
	for route in solutions.X01.paths:
		var game = _fresh()
		if not _prepare(game, "X01") or not _replay(game, route.actions.slice(0, 2), "I1 authenticate before natural exploration"): continue
		for case_id in model.cases:
			game.use_tool(cid, {"action": "probe", "case_id": case_id})
		_local(game)
		if not _replay(game, route.actions, "I1 actual A/B route after baseline probing"): continue
		var world: Dictionary = game.export_snapshot().current_world
		var met: bool = ResponseLab.goal_met(model, world.model_states[cid], game._runtime._model_context())
		critical_observations.append({"case": "I1", "route": route.id, "completed_after_baseline": game.get_view().get("completed"), "current_goal_met": met, "auth_counters": world.model_states[cid].auth_users})
		_check(met and game.get_view().get("completed", false), "I1 baseline exploration then intended route remains completable: " + str(route.id))
		var probe_routes := {}
		for action in route.actions:
			if action.get("params", {}).get("action") == "probe":
				probe_routes[action.params.case_id] = str(action.params.get("route_id", "direct"))
		for case_id in model.cases:
			game.use_tool(cid, {"action": "probe", "case_id": case_id, "route_id": probe_routes.get(case_id, "direct")})
		world = game.export_snapshot().current_world
		_check(ResponseLab.goal_met(model, world.model_states[cid], game._runtime._model_context()), "I1 repeat complete scenario probes remain recoverable and current: " + str(route.id))


func _test_notification_scope_counterexample() -> void:
	var game = _fresh()
	if not _prepare(game, "X02") or not _replay(game, solutions.X02.paths[0].actions.slice(0, 2), "I2 authenticate before notification scope"): return
	var cid := "ch1_x02_response"
	for control in ["notify_open", "standby_open"]:
		game.use_tool(cid, {"action": "set_control", "control_id": control, "value": true})
	game.use_tool(cid, {"action": "set_control", "control_id": "target_scope", "value": false})
	for case_id in ["notify", "internal_target", "standby_target"]:
		game.use_tool(cid, {"action": "probe", "case_id": case_id})
	var state: Dictionary = game.export_snapshot().current_world.model_states[cid]
	var status: int = int(state.probe_receipts.internal_target.status)
	critical_observations.append({"case": "I2", "unscoped_internal_status": status, "unscoped_ward_status": state.probe_receipts.notify.status})
	_check(status == 200 and state.probe_receipts.standby_target.status == 200, "I2 disabled scope permits an actual out-of-scope delivery counterexample")
	game.use_tool(cid, {"action": "set_control", "control_id": "target_scope", "value": true})
	for case_id in ["notify", "internal_target", "standby_target"]:
		game.use_tool(cid, {"action": "probe", "case_id": case_id})
	state = game.export_snapshot().current_world.model_states[cid]
	_check(state.probe_receipts.notify.status == 200 and state.probe_receipts.internal_target.status == 403 and state.probe_receipts.standby_target.status == 403, "I2 enabled scope preserves intended delivery and rejects actual outside targets")


func _test_single_source_handoff() -> void:
	var cid := "ch1_x03_observations"
	var model: Dictionary = definition.missions.X03.challenges[cid]
	for sensor in ["ch1_x03_field", "ch1_x03_receiver"]:
		var game = _fresh()
		if not _prepare(game, "X03") or not _replay(game, solutions.X03.paths[0].actions.slice(0, 2), "I3 authenticate field operator"): continue
		for window in model.sensors[sensor].windows.size():
			if window > 0: game.use_tool(cid, {"action": "advance_watch", "sensor_id": sensor})
			game.use_tool(cid, {"action": "collect", "sensor_id": sensor})
		var state: Dictionary = game.export_snapshot().current_world.model_states[cid]
		var claims: Array = []
		for claim in model.handoff_requirements.supported:
			claims.append({"claim": claim.duplicate(true), "observation_ids": state.observations.keys()})
		var result: Dictionary = game.use_tool(cid, {"action": "handoff", "claims": claims, "next_sensor_id": "ch1_x03_vault_watch"})
		critical_observations.append({"case": "I3", "sensor": sensor, "completed": game.get_view().get("completed"), "handoff_ok": result.get("ok"), "collected": state.observations.size()})
		_check(not result.get("ok", true) and not game.get_view().get("completed", true), "I3 intended corroboration cannot be completed from a single source: " + sensor)


func _test_audit_authority_and_clock_order() -> void:
	var game = _fresh()
	if not _prepare(game, "X03") or not _replay(game, solutions.X03.paths[0].actions.slice(0, 2), "X03 field authority for clock proof"): return
	var cid := "ch1_x03_observations"
	var snapshot: Dictionary = game.export_snapshot()
	var refused: Dictionary = game.use_tool(cid, {"action": "collect", "sensor_id": "ch1_x03_audit"})
	_check(not refused.get("ok", true), "X03 operator cannot collect distinct approved audit authority")
	_check(_same(snapshot, game.export_snapshot()), "X03 rejected audit collection does not fabricate observations")
	for action in [{"action": "collect", "sensor_id": "ch1_x03_field"}, {"action": "advance_watch", "sensor_id": "ch1_x03_field"}, {"action": "collect", "sensor_id": "ch1_x03_field"}, {"action": "collect", "sensor_id": "ch1_x03_receiver"}]:
		var response: Dictionary = game.use_tool(cid, action)
		_check(response.get("ok", false), "X03 real field/receiver clock evidence is collectable")
	var state: Dictionary = game.export_snapshot().current_world.model_states[cid]
	var raw_state := state.duplicate(true)
	var raw_rotate: Array = []
	var raw_depart: Array = []
	for observation in raw_state.observations.values():
		observation.normalized_interval = observation.canonical.observed_at.duplicate()
		if observation.event_id == "ROTATE": raw_rotate = observation.normalized_interval
		if observation.event_id == "DEPART": raw_depart = observation.normalized_interval
	_check(not raw_rotate.is_empty() and not raw_depart.is_empty() and raw_rotate[0] > raw_depart[1], "X03 observed cross-source clocks put rotation after departure before correction")
	var claim := {"kind": "before", "left": "event:ROTATE", "right": "event:DEPART"}
	var corrected: Dictionary = ObservationCase.assess(claim, state.observations.keys(), state)
	var uncorrected: Dictionary = ObservationCase.assess(claim, raw_state.observations.keys(), raw_state)
	_check(corrected.get("verdict") == "supported" and uncorrected.get("verdict") != "supported", "X03 clock offsets change an actual assessment instead of cosmetic timestamps")
	_check(_same(game.export_snapshot().current_world.model_states[cid], state), "X03 raw-vs-corrected assessment uses a copy and never changes live world")
	var audit_actions: Array = solutions.X03.paths[1].actions
	if _replay(game, audit_actions.slice(2, 4), "X03 explicit auditor login"):
		var accepted: Dictionary = game.use_tool(cid, {"action": "collect", "sensor_id": "ch1_x03_audit"})
		_check(accepted.get("ok", false), "X03 authorized auditor can collect the independent export")
