extends "res://tests/headless/test_mutation_limits.gd"
## Real public actions and independent semantic checks; never achievement injection.

const PACKS := {"intruder": 28, "defender": 8, "tracker": 8}
const STARTS := {"intruder": "M01", "defender": "D01", "tracker": "T01"}
const FIXTURES := "res://tests/fixtures/perspectives_solutions.json"
const LEGACY_SHA := "51699e38f77e1cf1caa01eaa2617587e9e668261c82373cb77d7ad5b0c74d9b8"

var current_pack := "legacy_intruder"
var catalog: Variant
var pack_fixtures: Dictionary = {}
var routes_attempted := 0
var route_rows: Array[Dictionary] = []
var ending_rows: Dictionary = {}


func _run() -> void:
	var before := _fingerprints()
	test_root = "user://tests/mutation_limits_perspectives_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
	catalog = load("res://scripts/core/campaign_catalog.gd")
	_check(catalog != null, "fixed campaign catalog is implemented")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	_check(raw is Dictionary and raw.get("packs") is Dictionary, "all public campaigns have actual-action fixtures")
	if catalog != null and raw is Dictionary and raw.get("packs") is Dictionary:
		pack_fixtures = raw.packs
		_test_catalog()
		for id in PACKS:
			if not _select_pack(id):
				continue
			_test_every_route()
			_test_endings()
			_test_wrong_pack_snapshot()
		_test_recovery_alternatives()
		_test_response_semantics()
		_test_observation_semantics()
		_test_vm_semantics()
		_test_current_normal_auth()
		_test_upload_remediation()
		_test_foreign_sidecar_preservation()
		_test_legacy_continuation()
		_test_malformed_terminal_entries()
	_check(routes_attempted == 88, "all public44 cases have two fresh-engine route attempts", routes_attempted)
	_check(_fingerprints() == before, "all real legacy/public campaign and preferences bytes remain unchanged")
	_cleanup(test_root)
	print(JSON.stringify({"suite": "perspectives", "checks": checks, "failures": failures,
		"routes_attempted": routes_attempted, "routes": route_rows, "endings": ending_rows,
		"limit": "Finite API/disk/semantic contracts and real fixture actions; not human timing, native GUI, hearing or physical IME acceptance."}))
	quit(0 if failures.is_empty() else 1)


func _new_for_slot(path: String) -> Variant:
	return Campaign.new(path, current_pack)


func _select_pack(id: String) -> bool:
	current_pack = id
	var loaded: Dictionary = Loader.load_campaign(id)
	_check(loaded.get("ok", false), "registered definition validates: " + id, loaded.get("errors", []))
	if not loaded.get("ok", false):
		return false
	definition = loaded.definition
	if id == "legacy_intruder":
		solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json")).missions
		return true
	_check(pack_fixtures.get(id) is Dictionary and pack_fixtures[id].get("missions") is Dictionary, "fixture pack exists: " + id)
	if not pack_fixtures.get(id) is Dictionary or not pack_fixtures[id].get("missions") is Dictionary:
		return false
	solutions = pack_fixtures[id].missions
	_check(definition.missions.size() == PACKS[id] and solutions.size() == PACKS[id], "complete public scope has one fixture per case: " + id)
	return true


func _test_catalog() -> void:
	var ids: Array[String] = []
	var slots_seen: Array[String] = []
	for item in catalog.list_packs():
		_check(item is Dictionary and item.has_all(["id", "title", "summary", "role", "start_mission", "main_count", "optional_count"]), "public catalog exposes declared presentation metadata")
		if not item is Dictionary:
			continue
		ids.append(str(item.get("id", "")))
		_check(not item.has("path") and not item.has("definition") and not item.has("solutions"), "catalog metadata excludes authoring definitions")
	ids.sort()
	_check(ids == ["defender", "intruder", "tracker"], "exactly three independent public choices exist", ids)
	for id in ["intruder", "defender", "tracker", "legacy_intruder"]:
		var path: String = catalog.default_slot(id)
		_check(path.begins_with("user://saves/") and path.ends_with(".json") and not slots_seen.has(path), "fixed campaign slot is valid and distinct: " + id)
		_check(not path in ["user://saves/campaign_01.json", "user://saves/slot_01.json"], "new campaign never defaults to an original save: " + id)
		slots_seen.append(path)
		var test_path: String = catalog.test_slot(test_root + "/selector.json", id)
		_check(test_path.begins_with(test_root + "/") and test_path.ends_with(".json"), "test UI selection derives an owned path: " + id)
	for invalid in ["", "../intruder", "res://data/campaign/legacy_v1.json", "unknown", "INTRUDER"]:
		_check(catalog.default_slot(invalid).is_empty(), "unknown pack cannot choose a resource/save path: " + invalid)
		var candidate = Campaign.new(test_root + "/invalid.json", invalid)
		_check(not candidate.get_view().get("ready", true), "unknown pack gives a structured not-ready view")
	for path in ["user://saves/real.json", "res://outside.json", "user://tests/../outside.json", "user://tests/not-json.txt"]:
		_check(catalog.test_slot(path, "intruder").is_empty(), "test-slot guard rejects disallowed base: " + path)
	for id in PACKS:
		current_pack = id
		var game = _fresh()
		var view: Dictionary = game.get_view()
		_check(view.get("ready", false) and view.get("mission_id") == STARTS[id], "fresh role starts without another campaign's progress: " + id)
		_check(view.get("campaign", {}).get("id") == id, "read model names only selected campaign")
		_check(view.get("campaign_progress", {}).get("completed") == 0 and view.get("campaign_progress", {}).get("total") == PACKS[id], "fresh progress is pack-local: " + id)
		_check(game.get_save_status().get("legacy_sources_checked") == false, "test status does not inspect real legacy sources")


func _contains(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary:
			return false
		for key in expected:
			if not actual.has(key) or not _contains(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _contains(actual[index], expected[index]):
				return false
		return true
	if expected is bool:
		return actual is bool and actual == expected
	if typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		return typeof(actual) in [TYPE_INT, TYPE_FLOAT] and float(actual) == float(expected)
	return actual == expected


func _replay(game: Variant, actions: Array, label: String) -> bool:
	_check(not actions.is_empty(), label + ": actual action witness is nonempty")
	if actions.is_empty():
		return false
	for action in actions:
		var result: Dictionary = _action(game, action)
		var expected: Dictionary = action.get("expect", {"ok": true})
		var matches := _contains(result, expected)
		_check(matches, label + ": actual action preserves independent expectation", {"expected": expected, "code": result.get("code"), "status": result.get("status")})
		if not matches:
			return false
	return true


func _assert_route(game: Variant, id: String, expected: Dictionary) -> void:
	var view: Dictionary = game.get_view()
	var world: Dictionary = game.export_snapshot().current_world
	_check(expected.get("completed") == true and view.get("completed", false) and _completed(game, id), current_pack + "/" + id + ": actual goals produce completion")
	_check(expected.get("sources_preserved") == true, id + ": independent fixture requires preservation")
	var originals := {}
	for host in definition.missions[id].hosts:
		originals[host] = definition.missions[id].hosts[host].files.duplicate(true)
		for path in originals[host]:
			originals[host][path]["source"] = originals[host][path].get("source", str(host) + ":" + str(path))
	_check(_same(world.remote_files, originals), id + ": source bodies/owners/modes are preserved")
	for record_id in expected.get("archive_record_ids", []):
		var found := false
		for path in world.local_files:
			var entry: Dictionary = world.local_files[path]
			if str(path).begins_with("/home/player/archive/") and entry.get("record_id") == record_id and definition.missions[id].records.has(record_id):
				var record: Dictionary = definition.missions[id].records[record_id]
				found = entry.get("content") == record.content and record.allowed_sources.has(entry.get("source"))
		_check(found, id + ": canonical target and acquisition source exist", record_id)
	for fact in expected.get("facts", []):
		_check(world.facts.has(fact), id + ": independently expected supported fact", fact)
	_check(_contains(world.policies, expected.get("policies", {})), id + ": expected current policies reflect real state")
	_check(_contains(world.model_states, expected.get("model_states", {})), id + ": expected outcomes reflect actual model observations")
	_assert_model_outcomes(id, world, expected.get("model_outcomes", {}))
	_assert_effective_files(game, id, expected.get("remote_files", {}))
	if expected.has("session"):
		var subject: Dictionary = game.get_view(int(expected.session.get("terminal_id", 0)))
		_check(subject.get("host") == expected.session.host_id and subject.get("user") == expected.session.account_id, id + ": expected authenticated actor is real")
	for service in expected.get("services", []):
		var scanned: Dictionary = game.execute("nmap " + str(definition.missions[id].hosts[service.host_id].domain))
		var protocol: String = definition.missions[id].hosts[service.host_id].services[str(service.port)].protocol
		_check(scanned.get("ok", false) and str(scanned.get("text", "")).contains("%s/%s %s" % [str(service.port), protocol, service.state]), id + ": expected service state is observable")


func _assert_model_outcomes(id: String, world: Dictionary, outcomes: Dictionary) -> void:
	for cid in outcomes:
		var expected: Dictionary = outcomes[cid]
		var challenge: Dictionary = definition.missions[id].challenges.get(cid, {})
		var state: Dictionary = world.model_states.get(cid, {})
		_check(not challenge.is_empty() and not state.is_empty(), id + ": actual semantic outcome exists", cid)
		match str(expected.get("kind", "")):
			"response_matrix":
				_check(not expected.get("case_ids", []).is_empty(), id + ": business expectation names actual cases")
				for case_id in expected.get("case_ids", []):
					_assert_business_receipt(id, world, cid, case_id)
			"current_boundaries":
				var groups: Array = expected.get("groups", []).duplicate()
				groups.sort()
				_check(groups == ["route", "service", "web"], id + ": capstone independently requires all three actual boundaries")
				var found_boundary := false
				for goal in definition.missions[id].goals:
					if goal.kind != "current_boundaries":
						continue
					found_boundary = true
					for group in groups:
						var allowed := false
						var denied := false
						var reachable := false
						var unreachable := false
						_check(not goal.get("cases", {}).get(group, []).is_empty(), id + ": boundary references actual qualified cases", group)
						for ref in goal.get("cases", {}).get(group, []):
							_check(ref is Dictionary and ref.has_all(["challenge_id", "case_id"]), id + ": boundary case identity is qualified")
							if not ref is Dictionary or not ref.has_all(["challenge_id", "case_id"]):
								continue
							var receipt := _assert_business_receipt(id, world, ref.challenge_id, ref.case_id)
							var status: int = int(receipt.get("status", 0))
							allowed = allowed or (status >= 200 and status < 300)
							denied = denied or status in [401, 403, 404]
							if group == "route":
								var open := _transport_open(id, world, receipt.get("host_id", ""), receipt.get("origin", ""))
								reachable = reachable or open
								unreachable = unreachable or not open
								_check((status != 503) if open else (status == 503), id + ": recorded route result agrees with real vantage/service reachability", ref)
						if group == "route":
							_check(reachable and unreachable, id + ": route boundary proves a permitted and an unreachable vantage")
						else:
							_check(allowed and denied, id + ": boundary preserves legitimate access and rejects unauthorized access", group)
				_check(found_boundary, id + ": current-boundaries expectation has an actual goal")
			"observation_handoff":
				_check(not expected.get("supported", []).is_empty(), id + ": evidence expectation names required relations")
				var copies: Dictionary = state.get("observations", {})
				for copy_id in copies:
					var copy: Dictionary = copies[copy_id]
					var canonical: Dictionary = copy.get("canonical", {})
					_check(not canonical.is_empty() and copy.get("sha256") == JSON.stringify(canonical, "", true, true).sha256_text(), id + ": acquired public copy preserves canonical hash/provenance", copy_id)
					if canonical.has_all(["observed_at", "clock_offset"]):
						var interval := [canonical.observed_at[0] - canonical.clock_offset[1], canonical.observed_at[1] - canonical.clock_offset[0]]
						_check(_contains(copy.get("normalized_interval", []), interval), id + ": corrected clock interval is computed from source uncertainty", copy_id)
				var handoff: Dictionary = state.get("handoff", {})
				var claims: Array = handoff.get("claims", []).duplicate(true)
				for hypothesis_id in handoff.get("supported_hypothesis_ids", []):
					claims.append(state.get("hypotheses", {}).get(hypothesis_id, {}))
				for required in expected.get("supported", []):
					var supported := false
					for proposed in claims:
						var claim: Dictionary = proposed.get("claim", proposed)
						if _claim_matches(claim, required):
							supported = supported or _observed_relation(claim, proposed.get("observation_ids", []), copies, false)
					_check(supported, id + ": handoff supports the particular required relation from cited public copies", required)
				for claim_id in expected.get("refuted_initial_claims", []):
					var prior: Dictionary = challenge.get("initial_claims", {}).get(claim_id, {}).get("claim", {})
					_check(not prior.is_empty() and _observed_relation(prior, copies.keys(), copies, true), id + ": actual contrary public evidence refutes the prior claim", claim_id)
				_check(handoff.get("next_sensor_id") == expected.get("next_sensor_id"), id + ": handoff chooses the independently expected next observation")
			"vm_cases":
				_check(not expected.get("requirements", []).is_empty(), id + ": VM expectation names required computed outcomes")
				for requirement in expected.get("requirements", []):
					var desired: Dictionary = challenge.get("outcomes", {}).get(requirement, {})
					var found := false
					for machine in state.get("cases", {}).values():
						found = found or (machine.get("status") == "halted" and machine.get("inputs", {}).get("retention_scope") == desired.get("input_scope") and _contains(machine.get("outputs", {}), desired.get("output", {})))
					_check(not desired.is_empty() and found, id + ": VM input scope and executed output demonstrate the required behavior", requirement)
			_:
				_check(false, id + ": QA never silently skips an unknown semantic expectation", expected.get("kind"))


func _assert_business_receipt(id: String, world: Dictionary, cid: String, case_id: String) -> Dictionary:
	var model: Dictionary = definition.missions[id].challenges.get(cid, {})
	var scenario: Dictionary = model.get("cases", {}).get(case_id, {})
	var receipt: Dictionary = world.model_states.get(cid, {}).get("probe_receipts", {}).get(case_id, {})
	_check(not receipt.is_empty() and scenario.get("expect", {}).get("statuses", []).has(receipt.get("status")), id + ": actual case has its independently expected status", cid + "/" + case_id)
	_check(receipt.get("case_id") == case_id and receipt.get("assessment_eligible") == true, id + ": only this qualified eligible observation supplies evidence", cid + "/" + case_id)
	if scenario.get("expect", {}).has("business_key"):
		_check(_contains(receipt.get("business", {}).get(scenario.expect.business_key), scenario.expect.get("value")), id + ": business outcome agrees with actual status", case_id)
	var actor: String = scenario.get("actor_ref", {}).get("account_id", "")
	_check(receipt.get("actor") == (actor if not actor.is_empty() else "anonymous"), id + ": approved case uses its registered actor", case_id)
	_check(receipt.get("origin") == scenario.get("actor_ref", {}).get("host_id"), id + ": receipt retains the actual approved observation vantage", case_id)
	var endpoint: Dictionary = model.get("bindings", {}).get("endpoints", {}).get(receipt.get("endpoint_id", ""), {})
	_check(not endpoint.is_empty() and receipt.get("host_id") == endpoint.get("host_id"), id + ": observed endpoint belongs to the actual target", case_id)
	var trace: Array = receipt.get("trace", [])
	_check(not trace.is_empty(), id + ": case has an actual handler trace", case_id)
	for row in trace:
		_check(row.get("operation") == endpoint.get("operation") and row.get("status") == receipt.get("status") and row.get("actor") == receipt.get("actor"), id + ": handler trace agrees with endpoint/actor/result")
	return receipt


func _transport_open(id: String, world: Dictionary, host_id: String, origin: String) -> bool:
	var host: Dictionary = definition.missions[id].hosts.get(host_id, {})
	if host.is_empty() or (origin != host_id and not host.get("via", ["local"]).has(origin)):
		return false
	var service: Dictionary = host.get("services", {}).get("443", {})
	if service.get("state") != "open" or service.get("protocol") != "https":
		return false
	if service.has("policy_id") and world.policies.get(service.policy_id) != service.get("policy_value", true):
		return false
	for policy in service.get("required_policies", {}):
		if world.policies.get(policy) != service.required_policies[policy]:
			return false
	return true


func _assert_effective_files(game: Variant, id: String, expected: Dictionary) -> void:
	if expected.is_empty():
		return
	var observer = _fresh()
	_check(observer.restore_snapshot(game.export_snapshot()).get("ok", false), id + ": effective-file observer starts from genuinely earned progress")
	for host_id in expected:
		var host: Dictionary = definition.missions[id].hosts[host_id]
		var path: String = expected[host_id].keys()[0]
		var account_id: String = host.files[path].owner
		_check(host.accounts.has(account_id), id + ": expected deployed file has a registered reading owner")
		if not host.accounts.has(account_id):
			continue
		_check(observer.execute("ssh " + account_id + "@" + host.domain).get("ok", false), id + ": real terminal reaches deployed file host")
		_check(observer.submit_password(host.accounts[account_id].password).get("ok", false), id + ": real terminal authenticates for the effective file")
		for file_path in expected[host_id]:
			var read: Dictionary = observer.execute("cat " + file_path)
			_check(read.get("ok", false) and read.get("text") == expected[host_id][file_path].get("content"), id + ": terminal reads the actual registered deployment result", file_path)


func _claim_matches(claim: Dictionary, required: Dictionary) -> bool:
	if claim.get("kind") != required.get("kind"):
		return false
	for field in ["left", "right"]:
		if required.has(field) and claim.get(field) != required[field]:
			return false
	return (not required.has("request_tag") or claim.get("left") == "request:" + str(required.request_tag)) and (not required.has("target_node") or claim.get("right") == "node:" + str(required.target_node))


func _observed_relation(claim: Dictionary, ids: Array, copies: Dictionary, contradiction: bool) -> bool:
	for left_id in ids:
		for right_id in ids:
			if not copies.has(left_id) or not copies.has(right_id):
				continue
			var left: Dictionary = copies[left_id]
			var right: Dictionary = copies[right_id]
			if claim.get("kind") == "before" and claim.get("left") == "event:" + str(left.get("event_id")) and claim.get("right") == "event:" + str(right.get("event_id")):
				var matches: bool = (left.normalized_interval[0] > right.normalized_interval[1]) if contradiction else (left.normalized_interval[1] < right.normalized_interval[0])
				if matches:
					return true
			if claim.get("kind") == "forwarded_to" and not contradiction:
				var fields: Dictionary = left.get("public", {})
				if claim.get("left") == "request:" + str(fields.get("request_tag", "")) and claim.get("right") == "node:" + str(fields.get("to_node", "")) and not str(fields.get("from_node", "")).is_empty():
					return true
			if claim.get("kind") == "same_session":
				if left.get("provenance", {}).get("marker_authority") != "server_issued" or right.get("provenance", {}).get("marker_authority") != "server_issued":
					continue
				var a: String = left.get("public", {}).get("session_tag", "")
				var b: String = right.get("public", {}).get("session_tag", "")
				if claim.get("left") == "session:" + a and claim.get("right") == "session:" + b:
					if contradiction and a != b:
						return true
					if not contradiction and a == b and left.normalized_interval[0] <= right.normalized_interval[1] and right.normalized_interval[0] <= left.normalized_interval[1]:
						return true
	return false


func _test_every_route() -> void:
	for id in definition.mission_order:
		var paths: Variant = solutions.get(id, {}).get("paths", [])
		_check(paths is Array and paths.size() == 2, current_pack + "/" + id + ": exactly two authored action witnesses exist")
		if not paths is Array or paths.size() != 2:
			continue
		for route in paths:
			routes_attempted += 1
			var game = _fresh()
			if not _prepare(game, id):
				continue
			_check(not game.get_view().get("completed", true), id + ": fresh target has no injected achievement")
			var label: String = current_pack + "/" + id + "/" + str(route.get("id", ""))
			var actions: Array = route.get("actions", [])
			var split := maxi(1, actions.size() / 2)
			if not _replay(game, actions.slice(0, split), label + " before checkpoint"):
				continue
			# Pending password prompts are deliberately not persisted; checkpoint after authentication.
			while split < actions.size() and _has_pending_auth(game):
				if not _replay(game, [actions[split]], label + " finish authentication"):
					break
				split += 1
			var incomplete: bool = not game.get_view().get("completed", false)
			_round_trip(game, label + " midway")
			var path: String = slots[game.get_instance_id()]
			var resumed = _new_for_slot(path)
			slots[resumed.get_instance_id()] = path
			var reloaded: Dictionary = resumed.load_game()
			_check(reloaded.get("ok", false), label + ": remaining actions use a fresh disk-restored instance")
			if not reloaded.get("ok", false):
				continue
			game = resumed
			if split < actions.size() and not _replay(game, actions.slice(split), label + " after disk resume"):
				continue
			_assert_route(game, id, route.get("expected", {}))
			if id in ["M24", "D08", "T08"]:
				_assert_read_context(game, id)
			_round_trip(game, current_pack + "/" + id + "/" + str(route.get("id", "")))
			var before: Dictionary = game.export_snapshot()
			game.execute("pwd")
			_check(_same(game.export_snapshot(), before), id + ": unrelated read preserves evidence")
			route_rows.append({"pack": current_pack, "mission": id, "route": route.get("id"), "actions": actions.size(),
				"resumed_incomplete": incomplete, "completed": game.get_view().get("completed", false)})


func _has_pending_auth(game: Variant) -> bool:
	for terminal in range(4):
		if game.get_view(terminal).get("password_pending", false):
			return true
	return false


func _assert_read_context(game: Variant, id: String) -> void:
	var before: Dictionary = game.export_snapshot()
	for terminal in range(4):
		var view: Dictionary = game.get_view(terminal)
		_check(view.get("current_goals_met", false), id + ": completed shared-world goals remain true from every terminal view")
		for objective in view.get("objectives", []):
			_check(objective.get("completed", false), id + ": goal observation does not depend on which terminal reads it")
		game.autocomplete("p", terminal)
		_check(_same(game.export_snapshot(), before), id + ": terminal view/autocomplete preserve world and business effects")


func _test_endings() -> void:
	var reached: Array[String] = []
	for variant in range(2):
		var game = _fresh()
		var valid := true
		for id in definition.mission_order:
			if not _prepare(game, id) or not _replay(game, solutions[id].paths[variant].actions, "ending actual campaign replay"):
				valid = false
				break
		if not valid:
			continue
		var completed: Dictionary = game.export_snapshot()
		for ending in game.get_view().get("endings", []):
			if not ending.get("available", false):
				continue
			_check(game.restore_snapshot(completed).get("ok", false), "ending comparison starts from validated real progress")
			var chosen: Dictionary = game.choose_ending(ending.id)
			_check(chosen.get("ok", false) and game.get_view().ending.get("id") == ending.id, current_pack + ": actual ending choice is available", ending.id)
			_round_trip(game, current_pack + ": ending " + ending.id)
			if not reached.has(ending.id):
				reached.append(ending.id)
	for ending in definition.endings:
		_check(reached.has(ending.id), current_pack + ": every authored ending has an actual-action witness", ending.id)
	ending_rows[current_pack] = reached


func _test_wrong_pack_snapshot() -> void:
	var source = _fresh()
	var raw: Dictionary = source.export_snapshot()
	var other_id := "tracker" if current_pack != "tracker" else "intruder"
	var other = Campaign.new(test_root + "/foreign_" + current_pack + ".json", other_id)
	var before: Dictionary = other.export_snapshot()
	_check(not other.restore_snapshot(raw).get("ok", true), "another campaign cannot acquire foreign progress")
	_check(_same(other.export_snapshot(), before), "rejected foreign snapshot preserves selected campaign")
	var v1: Variant = load("res://scripts/core/game.gd").new(test_root + "/v1_read_only.json")
	_check(not other.import_m01(v1.export_snapshot()).get("ok", true), "new campaign cannot relabel old M01 as new achievement")


func _test_recovery_alternatives() -> void:
	if not _select_pack("intruder"):
		return
	for id in ["M06", "M07", "M08", "M12", "M23"]:
		var witness: Dictionary = solutions[id].get("alternative_witness", {})
		_check(witness.has_all(["challenge_id", "a_only_policy_id", "b_expected_a_only_value", "a_failure", "b_failure",
			"normal_cases", "threat_cases", "direct_break_case", "direct_endpoint_domain", "approved_endpoint_domain"]),
			id + ": independent alternatives declare actual mechanisms and counterexamples")
		if witness.is_empty():
			continue
		var cid: String = witness.challenge_id
		var lab: Dictionary = definition.missions[id].challenges[cid]
		for variant in range(2):
			var game = _fresh()
			if not _prepare(game, id) or not _replay(game, solutions[id].paths[variant].actions, id + ": actual alternative mechanism"):
				continue
			var world: Dictionary = game.export_snapshot().current_world
			_check(game.get_view().get("current_goals_met", false), id + ": independent mechanism genuinely satisfies the same business constraints")
			_check(world.policies.get(witness.a_only_policy_id) == (true if variant == 0 else witness.b_expected_a_only_value),
				id + ": approved alternative does not silently apply the direct-path protection")
			var direct := 0
			var delegated := 0
			for case_id in witness.normal_cases:
				var receipt: Dictionary = world.model_states[cid].probe_receipts.get(case_id, {})
				var host: Dictionary = definition.missions[id].hosts.get(receipt.get("host_id", ""), {})
				direct += int(host.get("domain") == witness.direct_endpoint_domain)
				delegated += int(host.get("domain") == witness.approved_endpoint_domain)
				_assert_business_receipt(id, world, cid, case_id)
			if variant == 0:
				_check(direct > 0, id + ": direct repair really serves normal traffic at the original provider")
			else:
				_check(delegated > 0 and direct == 0, id + ": approved-path response actually moves legitimate work to another provider")
			for case_id in witness.threat_cases:
				_assert_business_receipt(id, world, cid, case_id)
			var failure: Dictionary = witness.a_failure if variant == 0 else witness.b_failure
			_check(game.use_tool(cid, {"action": "set_control", "control_id": failure.control_id, "value": failure.value}).get("ok", false),
				id + ": counterexample changes a real registered control")
			var broken: Dictionary = game.use_tool(cid, {"action": "probe", "case_id": witness.direct_break_case})
			var scenario: Dictionary = lab.cases[witness.direct_break_case]
			_check(broken.get("ok", false) and not scenario.expect.statuses.has(broken.get("status")),
				id + ": distinct mechanism failure demonstrably breaks its required threat outcome",
				{"variant": variant, "status": broken.get("status")})
			_check(not game.get_view().get("current_goals_met", true), id + ": cached completion cannot hide the broken mechanism")
			for case_id in witness.normal_cases:
				var route_id: String = world.model_states[cid].probe_receipts[case_id].get("route_id", "direct")
				var normal: Dictionary = game.use_tool(cid, {"action": "probe", "case_id": case_id, "route_id": route_id})
				_check(lab.cases[case_id].expect.statuses.has(normal.get("status")), id + ": counterexample preserves the independently required normal workflow", case_id)
			_round_trip(game, id + ": broken-current mechanism with preserved earlier completion")


func _model_mission(id: String, challenge: Dictionary, goals: Array) -> Dictionary:
	var loaded: Dictionary = Loader.load_campaign("legacy_intruder")
	var mission: Dictionary = loaded.definition.missions.M01.duplicate(true)
	mission.challenges = {id: challenge.duplicate(true)}
	mission.challenges[id].merge({"record_id": "handoff-47", "source": "model:" + id,
		"fact_id": "qa_" + id, "host_id": "archive",
		"requires_session": {"host_id": "archive", "account_id": "maint"}})
	mission.records["handoff-47"].allowed_sources.append("model:" + id)
	mission.goals = goals.duplicate(true)
	return mission


func _model_runtime(mission: Dictionary) -> Variant:
	# Synthetic model definitions exercise the real dispatcher; sessions still authenticate normally.
	var runtime: Variant = load("res://scripts/core/campaign_runtime.gd").new()
	runtime.configure(mission)
	var initiated: Dictionary = runtime.run_command("ssh maint@archive.packet.test")
	var authorized: Dictionary = runtime.authenticate(mission.hosts.archive.accounts.maint.password)
	_check(initiated.get("ok", false) and authorized.get("ok", false), "semantic fixture authenticates a real registered actor")
	return runtime


func _test_response_semantics() -> void:
	var challenge := {
		"kind": "response_lab",
		"controls": {
			"ownership": {"policy_id": "qa_owner", "values": [false, true], "group": "ingress", "label": "QA_OWNER"},
			"availability": {"policy_id": "qa_online", "values": [false, true], "group": "service", "label": "QA_ONLINE"}},
		"bindings": {"objects": {"C731": {"owner": "maint", "record_id": "handoff-47"}},
			"endpoints": {"direct": {"host_id": "archive", "method": "GET", "path_prefix": "/tickets/",
				"operation": "object_read", "owner_policy": "qa_owner", "enabled_policy": "qa_online"}}},
		"cases": {
			"own": {"label": "QA_OWN", "class": "normal", "actor_ref": {"host_id": "archive", "account_id": "maint"},
				"request": {"method": "GET", "url": "https://archive.packet.test/tickets/C731", "body": {}, "headers": {}},
				"expect": {"statuses": [200], "business_key": "ticket:C731:read", "value": true}},
			"foreign": {"label": "QA_FOREIGN", "class": "threat", "actor_ref": {"host_id": "archive", "account_id": "guest"},
				"request": {"method": "GET", "url": "https://archive.packet.test/tickets/C731", "body": {}, "headers": {}},
				"expect": {"statuses": [401, 403], "business_key": "ticket:C731:read", "value": false}}},
		"checkpoint_groups": {"ingress": ["ownership"], "service": ["availability"]}}
	var mission := _model_mission("qa_response", challenge, [{"kind": "response_matrix", "challenge_id": "qa_response", "case_ids": ["own", "foreign"]}])
	mission.policies = {"qa_owner": false, "qa_online": true}
	mission.hosts.archive.services["443"] = {"protocol": "https", "state": "open", "required_policies": {"qa_online": true}}
	mission.pages["https://archive.packet.test/tickets/C731"] = {"title": "QA", "body": "QA", "links": [], "host_id": "archive"}
	var runtime = _model_runtime(mission)
	var normal: Dictionary = runtime.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	var normal_business: Dictionary = runtime.snapshot_world().model_states.get("qa_response", {}).get("business_objects", {}).duplicate(true)
	var foreign: Dictionary = runtime.use_challenge("qa_response", {"action": "probe", "case_id": "foreign"})
	_check(normal.get("status") == 200 and foreign.get("status") == 200, "unprotected handler actually permits owner and outsider")
	_check(not runtime.snapshot_world().completed, "wide-open normal+threat service is not a completed response")
	var altered: Dictionary = mission.duplicate(true)
	altered.challenges.qa_response.cases.own["class"] = "threat"
	altered.challenges.qa_response.cases.own.expect = {"statuses": [403], "business_key": "ticket:C731:read", "value": false}
	var mutant = _model_runtime(altered)
	var same_request: Dictionary = mutant.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	var mutant_business: Dictionary = mutant.snapshot_world().model_states.get("qa_response", {}).get("business_objects", {}).duplicate(true)
	mutant.use_challenge("qa_response", {"action": "probe", "case_id": "foreign"})
	_check(same_request.get("status") == normal.get("status"), "hidden class/expect metadata cannot fabricate handler status")
	_check(_same(mutant_business, normal_business), "assessment metadata cannot fabricate business effects")
	_check(normal.get("feedback", {}).get("business", {}).get("ticket:C731:read") == true,
		"actual unprotected owner read produces its registered business outcome")
	_check(_same(same_request.get("feedback", {}).get("business", {}), normal.get("feedback", {}).get("business", {})),
		"assessment metadata cannot replace the actual request's business outcome")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "ownership", "value": true})
	normal = runtime.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	foreign = runtime.use_challenge("qa_response", {"action": "probe", "case_id": "foreign"})
	_check(normal.get("status") == 200 and foreign.get("status") in [401, 403], "precise response preserves legitimate read and denies foreign read")
	_check(runtime.snapshot_world().completed, "real current normal/threat outcomes complete the response")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "availability", "value": false})
	normal = runtime.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	_check(normal.get("status") != 200 and not runtime.snapshot_world().completed, "blanket service shutdown invalidates current normal-workflow goal")
	var before: Dictionary = runtime.snapshot_world()
	var malformed: Dictionary = runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "not_registered", "value": true})
	_check(not malformed.get("ok", true) and _same(runtime.snapshot_world(), before), "unregistered response control fails atomically")
	_test_response_rollback(mission)
	_test_boundary_namespace(mission)
	_test_http_parity(mission)
	_test_assessment_gate(mission)


func _test_http_parity(mission: Dictionary) -> void:
	var scoped: Dictionary = mission.duplicate(true)
	scoped.policies.qa_owner = true
	scoped.hosts["other"] = scoped.hosts.archive.duplicate(true)
	scoped.hosts.other.domain = "other.qa.packet.test"
	scoped.hosts.other.address = "10.42.88.2"
	scoped.hosts.other.via = ["local", "archive"]
	scoped.challenges.qa_response.bindings.endpoints["other"] = {
		"host_id": "other", "method": "GET", "path_prefix": "/tickets/", "operation": "object_read", "owner_policy": "qa_owner"}
	var runtime = _model_runtime(scoped)
	var same_host: Dictionary = runtime.request_page("GET", "https://archive.packet.test/tickets/C731")
	_check(same_host.get("status") == 200 and same_host.get("actor") == "maint", "raw HTTP uses the actual selected target-host SSH actor")
	var borrowed: Dictionary = runtime.request_page("GET", "https://other.qa.packet.test/tickets/C731", {"actor_ref": {"host_id": "other", "account_id": "maint"}})
	_check(borrowed.get("status") == 401 and borrowed.get("actor") == "anonymous", "same account name on another SSH host is not target authority")
	runtime.run_command("ssh maint@other.qa.packet.test")
	runtime.authenticate(scoped.hosts.other.accounts.maint.password)
	_check(runtime.request_page("GET", "https://other.qa.packet.test/tickets/C731").get("status") == 200, "real authentication on the target host grants its own authority")
	var browser_headers := {"X-Packet-Context": "browser"}
	_check(runtime.request_page("GET", "https://other.qa.packet.test/tickets/C731", {}, browser_headers).get("status") == 401, "browser cannot inherit an SSH identity as its cookie")
	var logged: Dictionary = runtime.request_page("POST", "https://other.qa.packet.test/login",
		{"username": "maint", "password": scoped.hosts.other.accounts.maint.password}, browser_headers)
	_check(logged.get("status") == 200 and not str(logged.get("cookie_preview", "")).is_empty(), "real HTTP login issues its own target-host cookie")
	_check(runtime.request_page("GET", "https://other.qa.packet.test/tickets/C731", {}, browser_headers).get("status") == 200, "browser uses the real authenticated web session")
	var deployed: Dictionary = mission.duplicate(true)
	deployed.hosts.archive.files["/deploy"] = {"kind": "dir", "owner": "maint", "group": "ops", "mode": "700", "content": "", "record_id": ""}
	deployed.hosts.archive.files["/deploy/status.txt"] = {"kind": "file", "owner": "maint", "group": "ops", "mode": "600", "content": "WAITING\n", "record_id": ""}
	deployed.challenges.qa_response.bindings.endpoints["write"] = {"host_id": "archive",
		"method": "POST", "path_prefix": "/qa-deploy", "operation": "vfs_write",
		"file_path": "/deploy/status.txt", "write_scope": ["/deploy/status.txt"]}
	deployed.challenges.qa_response.bindings.endpoints["read"] = {"host_id": "archive",
		"method": "GET", "path_prefix": "/qa-status", "operation": "vfs_read", "file_path": "/deploy/status.txt"}
	var files = _model_runtime(deployed)
	var written: Dictionary = files.request_page("POST", "https://archive.packet.test/qa-deploy", {"content": "DEPLOYMENT READY\n"})
	_check(written.get("status") == 200, "raw HTTP writes through actual registered VFS permission/scope")
	_check(files.run_command("cat /deploy/status.txt").get("text") == "DEPLOYMENT READY\n", "terminal observes the actual HTTP deployment result")
	var fetched: Dictionary = files.request_page("GET", "https://archive.packet.test/qa-status")
	_check(fetched.get("status") == 200 and fetched.get("body") == "DEPLOYMENT READY\n", "raw HTTP reads the same effective file body as terminal")
	var original: Dictionary = files.snapshot_world().remote_files.archive["/deploy/status.txt"]
	_check(original.get("content") == "WAITING\n", "registered write retains its original source version")
	files.run_command("ssh guest@archive.packet.test")
	files.authenticate(deployed.hosts.archive.accounts.guest.password)
	var denied: Dictionary = files.request_page("POST", "https://archive.packet.test/qa-deploy",
		{"content": "UNAUTHORIZED\n", "actor_ref": {"host_id": "archive", "account_id": "maint"}})
	_check(denied.get("status") == 403 and denied.get("actor") == "guest", "body actor spoof cannot bypass real VFS write authority")
	_check(files.snapshot_world().model_states.qa_response.file_overrides.archive["/deploy/status.txt"].content == "DEPLOYMENT READY\n",
		"denied raw write preserves the current deployment version")
	var verifier = _model_runtime(deployed)
	_check(verifier.validate_world(files.snapshot_world()).get("ok", false), "raw HTTP/VFS effects have valid deterministic save replay")


func _test_assessment_gate(mission: Dictionary) -> void:
	var gated: Dictionary = mission.duplicate(true)
	gated.policies.qa_owner = true
	gated.challenges.qa_response["requires_facts"] = ["qa_prerequisite"]
	gated.records["handoff-47"].grants_facts.append("qa_prerequisite")
	var runtime = _model_runtime(gated)
	_check(runtime.request_page("GET", "https://archive.packet.test/tickets/C731").get("status") == 200, "ungraded real normal traffic remains operational")
	runtime.run_command("ssh guest@archive.packet.test")
	runtime.authenticate(gated.hosts.archive.accounts.guest.password)
	_check(runtime.request_page("GET", "https://archive.packet.test/tickets/C731").get("status") == 403, "ungraded real threat traffic is still denied")
	_check(not runtime.snapshot_world().completed and not runtime.snapshot_world().facts.has("qa_qa_response"), "transport evidence cannot award a gated response assessment")
	runtime.run_command("exit")
	_check(runtime.run_command("scp /vault/handoff.log").get("ok", false), "assessment prerequisite comes from a genuine canonical acquisition")
	_check(runtime.snapshot_world().facts.has("qa_prerequisite"), "acquisition derives the registered prerequisite fact")
	_check(runtime.use_challenge("qa_response", {"action": "inspect"}).get("ok", false), "assessment UI can inspect after gaining authority")
	_check(not runtime.snapshot_world().completed and not runtime.snapshot_world().facts.has("qa_qa_response"),
		"later inspection cannot retroactively promote ineligible earlier observations")
	runtime.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	runtime.use_challenge("qa_response", {"action": "probe", "case_id": "foreign"})
	_check(runtime.snapshot_world().completed, "new eligible actual normal/threat observations complete the response")
	var verifier = _model_runtime(gated)
	_check(verifier.validate_world(runtime.snapshot_world()).get("ok", false), "assessment-time eligibility survives deterministic replay")


func _test_boundary_namespace(mission: Dictionary) -> void:
	var scoped: Dictionary = mission.duplicate(true)
	scoped.policies.qa_owner = true
	scoped.challenges["qa_other"] = scoped.challenges.qa_response.duplicate(true)
	scoped.challenges.qa_other.source = "model:qa_other"
	scoped.challenges.qa_other.fact_id = "qa_other_evidence"
	scoped.records["handoff-47"].allowed_sources.append("model:qa_other")
	scoped.goals = [{"kind": "current_boundaries", "cases": {
		"web": [{"challenge_id": "qa_response", "case_id": "own"}, {"challenge_id": "qa_response", "case_id": "foreign"}],
		"route": [{"challenge_id": "qa_other", "case_id": "own"}],
		"service": [{"challenge_id": "qa_response", "case_id": "own"}]}}]
	var runtime = _model_runtime(scoped)
	runtime.use_challenge("qa_response", {"action": "probe", "case_id": "own"})
	runtime.use_challenge("qa_response", {"action": "probe", "case_id": "foreign"})
	_check(not runtime.snapshot_world().completed, "same-named case receipt from another lab cannot fill an unobserved boundary")
	runtime.use_challenge("qa_other", {"action": "probe", "case_id": "own"})
	_check(runtime.snapshot_world().completed, "qualified real case receipts can satisfy shared and independent boundaries")
	var before: Dictionary = runtime.snapshot_world()
	for index in range(20):
		runtime.view()
	_check(_same(runtime.snapshot_world(), before), "boundary goal/view reevaluation never executes another business request")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "ownership", "value": false})
	_check(not runtime.snapshot_world().completed, "current authorization regression invalidates its previously proven boundary")
	var bundle := {"schema_version": 1, "content_version": 1, "campaign_id": "qa_model",
		"start_mission": "M01", "mission_order": ["M01"], "missions": {"M01": scoped},
		"endings": [{"id": "qa", "title": "QA", "text": "QA", "requires_facts": []}]}
	var valid: Dictionary = Loader.validate(bundle)
	_check(valid.get("ok", false), "qualified duplicated case-name fixture is otherwise valid", valid.get("errors", []))
	bundle.missions.M01.goals[0].cases.route = ["own"]
	_check(not Loader.validate(bundle).get("ok", true), "unqualified ambiguous boundary reference is rejected")


func _test_response_rollback(mission: Dictionary) -> void:
	var isolated: Dictionary = mission.duplicate(true)
	isolated.policies["qa_revocation"] = true
	isolated.challenges.qa_response.bindings.endpoints["session"] = {"host_id": "archive",
		"method": "GET", "path_prefix": "/sessions/", "operation": "session_use",
		"revocation_policy": "qa_revocation", "initial_tokens": {"qa-live": {
			"account_id": "maint", "revoked": false, "expires_tick": 1000, "scope": ["C731"]}}}
	isolated.challenges.qa_response.cases["live_session"] = {"label": "QA_LIVE_SESSION", "class": "normal",
		"actor_ref": {"host_id": "archive", "account_id": "maint"}, "request": {"method": "GET",
			"url": "https://archive.packet.test/sessions/use", "body": {"token_ref": "qa-live", "object_id": "C731"}, "headers": {}},
		"expect": {"statuses": [200], "business_key": "session:qa-live:use", "value": true}}
	var runtime = _model_runtime(isolated)
	_check(runtime.use_challenge("qa_response", {"action": "probe", "case_id": "live_session"}).get("status") == 200,
		"rollback fixture proves its registered service token is initially usable")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "ownership", "value": true})
	var checkpoint: Dictionary = runtime.use_challenge("qa_response", {"action": "checkpoint", "group": "ingress"})
	var checkpoint_id: String = checkpoint.get("checkpoint_id", "")
	_check(checkpoint.get("ok", false) and not checkpoint_id.is_empty(), "response checkpoint exposes its real bounded identifier")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "ownership", "value": false})
	_check(runtime.use_challenge("qa_response", {"action": "revoke", "token_ref": "qa-live"}).get("ok", false), "response revokes a real previously issued token")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "availability", "value": false})
	var rolled: Dictionary = runtime.use_challenge("qa_response", {"action": "rollback", "checkpoint_id": checkpoint_id, "group": "ingress"})
	var world: Dictionary = runtime.snapshot_world()
	_check(rolled.get("ok", false) and world.policies.qa_owner == true and world.policies.qa_online == false, "rollback changes only its declared policy group")
	_check(world.model_states.get("qa_response", {}).get("tokens", {}).get("qa-live", {}).get("revoked") == true, "policy rollback cannot revive a revoked credential")
	var before: Dictionary = runtime.snapshot_world()
	_check(not runtime.use_challenge("qa_response", {"action": "rollback", "checkpoint_id": checkpoint_id, "group": "service"}).get("ok", true), "checkpoint cannot be applied to another policy group")
	_check(_same(runtime.snapshot_world(), before), "wrong-group rollback leaves state unchanged")
	runtime.use_challenge("qa_response", {"action": "set_control", "control_id": "availability", "value": true})
	_check(runtime.use_challenge("qa_response", {"action": "probe", "case_id": "live_session"}).get("status") == 403,
		"restoring service after scoped rollback still rejects the revoked token")


func _observation_row(id: String, time: Array, offset: Array, fields: Dictionary, authority: String) -> Dictionary:
	return {"event_id": id, "observed_at": time, "clock_offset": offset, "public": fields,
		"provenance": {"source_id": "archive:approved-export", "collector": "approved-export",
			"vantage": "archive", "acquisition": "registry-read", "marker_authority": authority}}


func _observation_sensor(rows: Array, sampling: String = "complete") -> Dictionary:
	return {"label": "QA_SENSOR", "host_id": "archive", "visibility": "metadata",
		"coverage": {"sampling": sampling, "window": [90, 160]},
		"requires_session": {"host_id": "archive", "account_id": "maint"},
		"windows": [{"rows": rows}]}


func _hypothesis(runtime: Variant, id: String, claim: Dictionary, ids: Array) -> Dictionary:
	var proposed: Dictionary = runtime.use_challenge("qa_observation", {"action": "hypothesize",
		"hypothesis_id": id, "claim": claim, "observation_ids": ids})
	_check(proposed.get("ok", false), "observed entity hypothesis is accepted: " + id)
	return runtime.use_challenge("qa_observation", {"action": "test", "hypothesis_id": id})


func _test_observation_semantics() -> void:
	var shared_fields := {"session_tag": "client-tag", "request_tag": "Q1",
		"from_node": "edge", "to_node": "archive", "shared_address": "10.42.4.8"}
	var trusted_fields := {"session_tag": "S1", "request_tag": "N47",
		"from_node": "edge", "to_node": "archive", "shared_address": "10.42.4.8"}
	var shared := [_observation_row("left", [110, 112], [-2, 2], shared_fields, "client_supplied"),
		_observation_row("right", [111, 113], [-3, 3], shared_fields, "client_supplied")]
	var registry := [_observation_row("arrived", [120, 121], [0, 0], trusted_fields, "server_issued"),
		_observation_row("earlier", [95, 96], [0, 0], trusted_fields, "server_issued")]
	var challenge := {"kind": "observation_case",
		"sensors": {"shared": _observation_sensor(shared, "sampled"), "registry": _observation_sensor(registry),
			"followup": _observation_sensor([_observation_row("later", [145, 146], [0, 0], trusted_fields, "server_issued")], "sampled")},
		"claim_types": ["same_session", "before", "forwarded_to"],
		"handoff_requirements": {"supported": [{"kind": "forwarded_to", "request_tag": "N47", "target_node": "archive"}],
			"refuted": [], "next_vantage": ["followup"], "allow_identity_unknown": true},
		"ground_truth": {"hidden_actor": "actor-a"}}
	challenge.sensors.shared.windows.append({"rows": [
		_observation_row("left", [135, 136], [0, 0], trusted_fields, "server_issued"),
		_observation_row("right", [135, 137], [0, 0], trusted_fields, "server_issued")]})
	var mission := _model_mission("qa_observation", challenge, [{"kind": "observation_handoff", "challenge_id": "qa_observation"}])
	var runtime = _model_runtime(mission)
	var before: Dictionary = runtime.snapshot_world()
	var guessed: Dictionary = runtime.use_challenge("qa_observation", {"action": "hypothesize",
		"hypothesis_id": "guess", "claim": {"kind": "same_session", "left": "event:left", "right": "event:right"},
		"observation_ids": []})
	_check(not guessed.get("ok", true) and _same(runtime.snapshot_world(), before), "unobserved actor/entity guesses cannot create evidence")
	var collected: Dictionary = runtime.use_challenge("qa_observation", {"action": "collect", "sensor_id": "shared"})
	_check(collected.get("ok", false) and collected.get("observations", []).size() == 2, "collect exposes actual copied observations")
	var ids := ["shared:0:left", "shared:0:right"]
	var named_codes: Array[String] = []
	for actor in ["actor-a", "actor-b"]:
		var named: Dictionary = runtime.use_challenge("qa_observation", {"action": "hypothesize",
			"hypothesis_id": "name_guess", "claim": {"kind": "identity", "left": "event:left", "right": "actor:" + actor},
			"observation_ids": ids})
		_check(not named.get("ok", true), "guessing a hidden actor name is not an assessment oracle")
		named_codes.append(str(named.get("code", "")))
	_check(named_codes[0] == named_codes[1], "correct-looking and unrelated hidden names have identical rejection semantics")
	var ip_claim := {"kind": "same_session", "left": "session:client-tag", "right": "session:client-tag"}
	var uncertain := _hypothesis(runtime, "shared-ip", ip_claim, ids)
	_check(uncertain.get("feedback", {}).get("verdict") == "underdetermined", "shared IP and client-supplied matching tags cannot establish one session")
	var order := _hypothesis(runtime, "clock-order", {"kind": "before", "left": "event:left", "right": "event:right"}, ids)
	_check(order.get("feedback", {}).get("verdict") == "underdetermined", "overlapping corrected intervals cannot establish before")
	_check(not runtime.snapshot_world().completed, "hypothesis labels and uncertainty alone cannot satisfy an evidence handoff")
	var hidden: Dictionary = mission.duplicate(true)
	hidden.challenges.qa_observation.ground_truth.hidden_actor = "actor-b"
	var mutant = _model_runtime(hidden)
	mutant.use_challenge("qa_observation", {"action": "collect", "sensor_id": "shared"})
	var independent := _hypothesis(mutant, "shared-ip", ip_claim, ids)
	_check(_same(independent.get("feedback", {}), uncertain.get("feedback", {})), "hidden actor changes cannot alter identical public-evidence feedback")
	var retained: Dictionary = runtime.snapshot_world().model_states.qa_observation.observations.duplicate(true)
	_check(runtime.use_challenge("qa_observation", {"action": "advance_watch", "sensor_id": "shared"}).get("ok", false), "bounded follow-up observation advances without real-time waiting")
	runtime.use_challenge("qa_observation", {"action": "collect", "sensor_id": "shared"})
	var later: Dictionary = runtime.snapshot_world().model_states.qa_observation.observations
	for copy_id in retained:
		_check(later.has(copy_id) and _same(later[copy_id], retained[copy_id]), "new sensor window preserves every previously acquired copy and provenance", copy_id)
	_check(later.has("shared:1:left") and later.has("shared:1:right"), "new source observations receive distinct retained-copy identities")
	runtime.use_challenge("qa_observation", {"action": "collect", "sensor_id": "registry"})
	var refuted := _hypothesis(runtime, "wrong-order", {"kind": "before", "left": "event:arrived", "right": "event:earlier"},
		["registry:0:arrived", "registry:0:earlier"])
	_check(refuted.get("feedback", {}).get("verdict") == "refuted", "complete trustworthy contrary time evidence refutes a wrong order")
	var clean = _model_runtime(mission)
	clean.use_challenge("qa_observation", {"action": "collect", "sensor_id": "registry"})
	var link := _hypothesis(clean, "valid-link", {"kind": "forwarded_to", "left": "request:N47", "right": "node:archive"}, ["registry:0:arrived"])
	_check(link.get("feedback", {}).get("verdict") == "supported", "trusted request and destination evidence supports the observed forwarding")
	var handoff: Dictionary = clean.use_challenge("qa_observation", {"action": "handoff",
		"supported_hypothesis_ids": ["valid-link"], "refuted_hypothesis_ids": [], "unknown_edges": [], "next_sensor_id": "followup"})
	_check(handoff.get("ok", false) and clean.snapshot_world().completed, "valid handoff does not require deliberately attempting a wrong hypothesis")
	var wrong_pair: Dictionary = mission.duplicate(true)
	wrong_pair.challenges.qa_observation.handoff_requirements.supported = [
		{"kind": "before", "left": "event:arrived", "right": "event:earlier"}]
	var unrelated = _model_runtime(wrong_pair)
	unrelated.use_challenge("qa_observation", {"action": "collect", "sensor_id": "registry"})
	var unrelated_order := _hypothesis(unrelated, "other_pair",
		{"kind": "before", "left": "event:earlier", "right": "event:arrived"}, ["registry:0:arrived", "registry:0:earlier"])
	_check(unrelated_order.get("feedback", {}).get("verdict") == "supported", "unrelated order witness is actually supported")
	before = unrelated.snapshot_world()
	var rejected_handoff: Dictionary = unrelated.use_challenge("qa_observation", {"action": "handoff",
		"supported_hypothesis_ids": ["other_pair"], "refuted_hypothesis_ids": [], "unknown_edges": [], "next_sensor_id": "followup"})
	_check(not rejected_handoff.get("ok", true) and not unrelated.snapshot_world().completed,
		"another supported before relation cannot replace the required event pair")
	_check(_same(unrelated.snapshot_world(), before), "wrong-pair handoff refusal preserves evidence and history")
	var bundle := {"schema_version": 1, "content_version": 1, "campaign_id": "qa_model",
		"start_mission": "M01", "mission_order": ["M01"], "missions": {"M01": mission},
		"endings": [{"id": "qa", "title": "QA", "text": "QA", "requires_facts": []}]}
	var valid: Dictionary = Loader.validate(bundle)
	_check(valid.get("ok", false), "metadata sensor validation fixture is otherwise a valid bounded campaign", valid.get("errors", []))
	bundle.missions.M01.challenges.qa_observation.sensors.shared.windows[0].rows[0].public["credentials"] = "never-public"
	_check(not Loader.validate(bundle).get("ok", true), "metadata sensor cannot publish credential/payload columns")


func _test_vm_semantics() -> void:
	var vm := {"kind": "branch_vm",
		"inputs": {"format_ok": {"type": "bool"}, "signature_ok": {"type": "bool"},
			"retention_scope": {"type": "enum", "choices": ["authorized", "excluded"]}},
		"limits": {"steps": 256, "stack": 16, "memory": 64},
		"program": {"entry": "main", "functions": {
			"main": [
				{"label": "entry", "op": "LOAD", "dst": "fmt", "input": "format_ok"},
				{"op": "BRANCH", "reg": "fmt", "then": "signed", "else": "deny"},
				{"label": "signed", "op": "CALL", "function": "check_signature", "dst": "sig"},
				{"op": "BRANCH", "reg": "sig", "then": "grant", "else": "deny"},
				{"label": "grant", "op": "SET_OUTPUT", "key": "release", "value": true}, {"op": "HALT"},
				{"label": "deny", "op": "SET_OUTPUT", "key": "release", "value": false}, {"op": "HALT"}],
			"check_signature": [{"op": "LOAD", "dst": "ok", "input": "signature_ok"}, {"op": "RET", "reg": "ok"}]}},
		"outcomes": {"normal": {"input_scope": "authorized", "output": {"release": true}},
			"counterexample": {"input_scope": "excluded", "output": {"release": true}}}}
	var mission := _model_mission("qa_vm", vm, [{"kind": "vm_cases", "challenge_id": "qa_vm", "requirements": ["normal", "counterexample"]}])
	var runtime = _model_runtime(mission)
	var denied := {"format_ok": true, "signature_ok": false, "retention_scope": "excluded"}
	runtime.use_challenge("qa_vm", {"action": "set_input", "case_id": "normal", "values": denied})
	runtime.use_challenge("qa_vm", {"action": "run", "case_id": "normal"})
	_check(_vm_machine(runtime).get("outputs", {}).get("release") == false, "VM follows called signature check and deny branch")
	_check(not runtime.snapshot_world().completed, "case label alone cannot supply normal/counterexample evidence")
	var valid := {"format_ok": true, "signature_ok": true, "retention_scope": "authorized"}
	runtime.use_challenge("qa_vm", {"action": "set_input", "case_id": "ordinary", "values": valid})
	runtime.use_challenge("qa_vm", {"action": "run", "case_id": "ordinary"})
	_check(_vm_machine(runtime).get("outputs", {}).get("release") == true, "VM computes normal allowed output")
	_check(not runtime.snapshot_world().completed, "normal output alone does not demonstrate missing scope validation")
	var counter := {"format_ok": true, "signature_ok": true, "retention_scope": "excluded"}
	runtime.use_challenge("qa_vm", {"action": "set_input", "case_id": "unrelated-name", "values": counter})
	runtime.use_challenge("qa_vm", {"action": "run", "case_id": "unrelated-name"})
	_check(runtime.snapshot_world().completed, "computed inputs/outputs establish both required VM outcomes")
	var stepped = _model_runtime(mission)
	var uninterrupted = _model_runtime(mission)
	uninterrupted.use_challenge("qa_vm", {"action": "set_input", "case_id": "ordinary", "values": valid})
	uninterrupted.use_challenge("qa_vm", {"action": "run", "case_id": "ordinary"})
	stepped.use_challenge("qa_vm", {"action": "set_input", "case_id": "ordinary", "values": valid})
	for index in range(16):
		stepped.use_challenge("qa_vm", {"action": "step", "count": 1})
	var state := _vm_machine(stepped)
	_check(state.get("outputs", {}).get("release") == true and state.get("trace", []).size() >= 6, "step and run expose the same real branch/call output")
	var run_state := _vm_machine(uninterrupted)
	_check(_contains(state.get("outputs", {}), run_state.get("outputs", {})) and _contains(state.get("trace", []), run_state.get("trace", [])),
		"stepping and uninterrupted run compute identical instruction traces and outputs")
	var graph_edge := false
	var call_target := false
	var inspect_sections: Array[String] = []
	for row in uninterrupted.view().get("tools", []):
		if row.get("id") != "qa_vm":
			continue
		var data: Dictionary = row.get("data", {})
		for action in row.get("actions", []):
			if action.get("id") != "inspect":
				continue
			for field in action.get("fields", []):
				if field.get("id") == "section":
					_check(field.get("type") == "enum", "VM basic inspect section is an explicit selector")
					for option in field.get("options", []):
						inspect_sections.append(str(option.get("id", "")) if option is Dictionary else str(option))
		_check(not data.has("outcomes"), "VM public projection excludes hidden required-answer metadata")
		for edge in data.get("call_graph", []):
			graph_edge = graph_edge or (edge.get("from") == "main" and edge.get("to") == "check_signature")
		for instruction in data.get("listing", []):
			call_target = call_target or (instruction.get("op") == "CALL" and JSON.stringify(instruction).contains("check_signature"))
	_check(graph_edge and call_target, "public VM listing/graph retain the actual called function")
	inspect_sections.sort()
	_check(inspect_sections == ["call_graph", "listing", "trace"], "VM basic inspect form exposes all supported sections without advanced JSON")
	var before: Dictionary = stepped.snapshot_world()
	var wrong_type: Dictionary = valid.duplicate(true)
	wrong_type.format_ok = "true"
	_check(not stepped.use_challenge("qa_vm", {"action": "set_input", "case_id": "bad", "values": wrong_type}).get("ok", true), "VM rejects string values for a boolean input")
	_check(_same(stepped.snapshot_world(), before), "invalid VM input preserves the prior execution")
	_check(not stepped.use_challenge("qa_vm", {"action": "set_input", "case_id": "missing", "values": {}}).get("ok", true), "VM rejects incomplete input schemas")
	for budget in ["steps", "stack", "memory"]:
		var limited: Dictionary = mission.duplicate(true)
		if budget == "steps":
			limited.challenges.qa_vm.program.functions.main = [{"label": "loop", "op": "JUMP", "target": "loop"}]
		elif budget == "stack":
			limited.challenges.qa_vm.program.functions.main = [{"op": "CALL", "function": "main", "dst": "value"}, {"op": "HALT"}]
		else:
			var instructions: Array = []
			for index in range(70):
				instructions.append({"op": "CONST", "dst": "value_%d" % index, "value": index})
			instructions.append({"op": "HALT"})
			limited.challenges.qa_vm.program.functions.main = instructions
		var bounded = _model_runtime(limited)
		bounded.use_challenge("qa_vm", {"action": "set_input", "case_id": "bounded", "values": valid})
		before = bounded.snapshot_world()
		var exhausted: Dictionary = bounded.use_challenge("qa_vm", {"action": "run", "case_id": "bounded"})
		_check(not exhausted.get("ok", true), "VM run terminates at its finite " + budget + " budget")
		var code: String = exhausted.get("code", "")
		_check(code == "VM_LIMIT", "valid VM workload fails for its budget rather than malformed test content", code)
		_check(_same(bounded.snapshot_world(), before), "VM " + budget + " failure leaves no partial output/state")


func _vm_machine(runtime: Variant) -> Dictionary:
	var state: Dictionary = runtime.snapshot_world().model_states.get("qa_vm", {})
	return state.get("cases", {}).get(state.get("active_case", ""), {})


func _public_model(game: Variant, id: String) -> Dictionary:
	for row in game.get_view().get("tools", []):
		if row.get("id") == id:
			return row
	return {}


func _test_current_normal_auth() -> void:
	if not _select_pack("defender"):
		return
	var game = _fresh()
	if not _prepare(game, "D02") or not _replay(game, solutions.D02.paths[0].actions, "D02 genuinely complete before currentness repro"):
		return
	var cid := "df1_d02_response"
	var lab: Dictionary = definition.missions.D02.challenges[cid]
	var request: Dictionary = lab.cases.legitimate.request
	var history: Dictionary = game.export_snapshot().current_world.model_states[cid].probe_receipts.duplicate(true)
	_round_trip(game, "D02 before newly locked normal account")
	for index in range(2):
		var wrong: Dictionary = request.body.duplicate(true)
		wrong.password = "qa-new-incorrect"
		_check(game.request(request.method, request.url, wrong).get("status") == 401, "D02 actual extra failed login increments the same user's counter")
	_check(not game.get_view().get("current_goals_met", true), "D02 cached normal200 cannot claim current workflow availability during cooldown")
	var blocked: Dictionary = game.export_snapshot()
	var observer = _fresh()
	observer.restore_snapshot(blocked)
	_check(observer.request(request.method, request.url, request.body).get("status") == 429, "D02 independent real normal request confirms current cooldown")
	var after: Dictionary = game.export_snapshot().current_world.model_states[cid].probe_receipts
	for key in history:
		if str(key).contains("failed"):
			_check(_same(after.get(key, {}), history[key]), "D02 preserves the earned historical failed-login sequence", key)
	_round_trip(game, "D02 current unavailable with earlier completion receipt")
	_check(game.use_tool(cid, {"action": "advance", "ticks": 2}).get("ok", false), "D02 logical cooldown recovery remains available")
	_check(game.get_view().get("current_goals_met", false), "D02 actual current normal availability recovers after logical advance")
	for index in range(2):
		game.request(request.method, request.url, {"username": "outsider", "password": "qa-unrelated-wrong"})
	game.execute("pwd")
	_check(game.get_view().get("current_goals_met", false), "D02 another username or unrelated read cannot invalidate the legitimate user's current availability")
	_round_trip(game, "D02 recovered currentness and preserved history")


func _test_upload_remediation() -> void:
	if not _select_pack("defender"):
		return
	var cid := "df1_d04_response"
	for variant in range(2):
		var game = _fresh()
		if not _prepare(game, "D04"):
			continue
		var host: Dictionary = definition.missions.D04.hosts.df1_d04_desk
		game.execute("ssh operator@" + host.domain)
		game.submit_password(host.accounts.operator.password)
		var accepted: Dictionary = game.use_tool(cid, {"action": "probe", "case_id": "disguised"})
		_check(accepted.get("status") == 201, "D04 prepatch observation actually stores the disguised artifact")
		var initial: Dictionary = game.export_snapshot().current_world.model_states[cid]
		var was_executable := false
		for artifact in initial.get("business_objects", {}).values():
			if artifact is Dictionary and artifact.get("filename") == "fake.jpg":
				was_executable = artifact.get("execution_allowed", false)
		_check(was_executable, "D04 initial artifact has the actual vulnerable execution state")
		var events: Array = initial.get("artifact_events", []).duplicate(true)
		_check(not events.is_empty(), "D04 accepted artifact has a retained event history")
		if not _replay(game, solutions.D04.paths[variant].actions, "D04 ordinary repair after observing vulnerability"):
			continue
		var view: Dictionary = _public_model(game, cid)
		var artifacts: Array = view.get("data", {}).get("artifacts", [])
		var fake := {}
		var normal := {}
		for artifact in artifacts:
			if artifact.get("filename") == "fake.jpg":
				fake = artifact
			if artifact.get("filename") == "normal.jpg":
				normal = artifact
		_check(not fake.is_empty() and not str(fake.get("artifact_id", "")).is_empty(), "D04 public artifacts identify the retained cause and safe remediation target")
		if variant == 1 and not fake.is_empty():
			var quarantined: Dictionary = game.use_tool(cid, {"action": "quarantine", "artifact_id": fake.artifact_id, "quarantined": true})
			_check(quarantined.get("ok", false), "D04 approved-route repair can visibly quarantine the dangerous old artifact")
		_check(game.get_view().get("current_goals_met", false), "D04 supported repair restores normal matrix after vulnerable-first observation")
		var state: Dictionary = game.export_snapshot().current_world.model_states[cid]
		var retained: Array = state.get("artifact_events", [])
		_check(retained.size() >= events.size() and _contains(retained.slice(0, events.size()), events), "D04 remediation preserves the original accepted/execution history")
		for artifact in _public_model(game, cid).get("data", {}).get("artifacts", []):
			if artifact.get("filename") == "fake.jpg":
				_check(artifact.get("execution_allowed_at_upload") == true and artifact.get("execution_allowed") == false,
					"D04 distinguishes historical execution acceptance from current execution denial")
		_round_trip(game, "D04 vulnerable-first repair and artifact history")
		if variant == 1 and not normal.is_empty():
			var hidden: Dictionary = game.use_tool(cid, {"action": "quarantine", "artifact_id": normal.get("artifact_id"), "quarantined": true})
			_check(hidden.get("ok", false) and not game.get_view().get("current_goals_met", true), "D04 quarantining legitimate photos fails normal workflow preservation")


func _owned_files() -> Dictionary:
	var result := {}
	var directory := DirAccess.open(test_root)
	if directory != null:
		for name in directory.get_files():
			result[name] = FileAccess.get_sha256(test_root.path_join(name))
	return result


func _write_test_bytes(path: String, bytes: PackedByteArray) -> void:
	_check(path.begins_with(test_root + "/"), "deliberate disk fixture is inside this process's owned folder")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "owned sidecar fixture can be created")
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _test_foreign_sidecar_preservation() -> void:
	if not _select_pack("intruder"):
		return
	var foreign = _fresh()
	_round_trip(foreign, "foreign identity source")
	var foreign_bytes := FileAccess.get_file_as_bytes(slots[foreign.get_instance_id()])
	if not _select_pack("defender"):
		return
	var current = _fresh()
	_round_trip(current, "current identity source")
	var current_bytes := FileAccess.get_file_as_bytes(slots[current.get_instance_id()])
	var layouts := [
		{"id": "main_foreign", "main": "foreign", "sidecar": ""},
		{"id": "backup_only", "main": "", "sidecar": ".bak"},
		{"id": "damaged_main_foreign_backup", "main": "damaged", "sidecar": ".bak"},
		{"id": "own_main_foreign_backup", "main": "own", "sidecar": ".bak"},
		{"id": "temporary_only", "main": "", "sidecar": ".tmp"},
		{"id": "backup_temporary_only", "main": "", "sidecar": ".bak.tmp"}]
	for layout in layouts:
		for operation in ["save_twice", "start_new", "recover"]:
			var path: String = test_root + "/guard_" + layout.id + "_" + operation + ".json"
			if not str(layout.main).is_empty():
				_write_test_bytes(path, foreign_bytes if layout.main == "foreign" else current_bytes if layout.main == "own" else "{bad owned main".to_utf8_buffer())
			if not str(layout.sidecar).is_empty():
				_write_test_bytes(path + str(layout.sidecar), foreign_bytes)
			var before_files := _owned_files()
			var game = Campaign.new(path, "defender")
			var before: Dictionary = game.export_snapshot()
			var results: Array = []
			match operation:
				"save_twice":
					results.append(game.save_game())
					results.append(game.save_game())
				"start_new": results.append(game.start_new_save())
				"recover": results.append(game.recover_save())
			for result in results:
				_check(not result.get("ok", true) and result.get("code") == "SAVE_DIFFERENT_CAMPAIGN",
					"foreign valid main/sidecar is rejected as another identity before " + operation, layout.id)
			_check(_same(_owned_files(), before_files), "foreign main/bak/tmp paths and exact bytes survive " + operation, layout.id)
			_check(_same(game.export_snapshot(), before), "foreign identity rejection preserves active memory")


func _test_malformed_terminal_entries() -> void:
	if not _select_pack("legacy_intruder"):
		return
	var game = _fresh()
	if not _prepare(game, "M07") or not _replay(game, solutions.M07.paths[0].actions, "valid observed session before malformed-terminal boundary"):
		return
	var before: Dictionary = game.export_snapshot()
	for entry in [42, {}]:
		var malformed: Dictionary = before.duplicate(true)
		malformed.current_world.terminals["0"] = [entry]
		# The external wrapper also rejects any engine Script ERROR from validation.
		var result: Variant = game.restore_snapshot(malformed)
		_check(result is Dictionary and result.get("ok") == false and result.get("code") == "INVALID_SNAPSHOT",
			"malformed terminal entry is rejected cleanly before model context use")
		_check(_same(game.export_snapshot(), before), "malformed terminal rejection preserves the active valid campaign")


func _test_legacy_continuation() -> void:
	if not _select_pack("legacy_intruder"):
		return
	_check(FileAccess.get_sha256("res://data/campaign/legacy_v1.json") == LEGACY_SHA, "frozen legacy definition preserves original release bytes")
	var source = _fresh()
	_round_trip(source, "isolated original v2 initial state")
	if not _replay(source, solutions.M01.paths[0].actions, "actual old M01 before continuation"):
		return
	_round_trip(source, "isolated original completed v2")
	var source_path: String = slots[source.get_instance_id()]
	var original_sha := FileAccess.get_sha256(source_path)
	var original_bak := FileAccess.get_sha256(source_path + ".bak")
	var copy = _fresh()
	var copy_path: String = slots[copy.get_instance_id()]
	var forked: Dictionary = copy.continue_legacy_source(source_path)
	_check(forked.get("ok", false), "explicit test source forks into a distinct continuation slot", forked.get("code"))
	_check(_same(copy.export_snapshot(), source.export_snapshot()), "continuation resumes original content and exact progress")
	_local(copy)
	_check(copy.execute("mkdir ~/newer-continuation").get("ok", false), "continuation can make newer local progress")
	_round_trip(copy, "newer continuation")
	var newer: Dictionary = copy.export_snapshot()
	var resumed = Campaign.new(copy_path, "legacy_intruder")
	_check(resumed.load_continuation().get("ok", false) and _same(resumed.export_snapshot(), newer), "valid continuation takes precedence over older original")
	var file := FileAccess.open(copy_path, FileAccess.WRITE)
	_check(file != null, "only isolated continuation may be deliberately damaged")
	if file != null:
		file.store_string("{damaged continuation")
		file.close()
	var broken = Campaign.new(copy_path, "legacy_intruder")
	var before: Dictionary = broken.export_snapshot()
	_check(not broken.load_continuation().get("ok", true), "damaged continuation never falls back to older original")
	_check(_same(broken.export_snapshot(), before), "failed continuation load preserves active memory")
	var foreign = Campaign.new(source_path, "defender")
	_check(not foreign.load_game().get("ok", true), "wrong-pack normal file is rejected")
	_check(not foreign.start_new_save().get("ok", true), "wrong-pack normal file is not reclassified as damaged")
	_check(FileAccess.get_sha256(source_path) == original_sha and FileAccess.get_sha256(source_path + ".bak") == original_bak, "original v2 main/backup survive continuation and wrong-pack rejection")
	for invalid in ["res://project.godot", "user://saves/campaign_01.json", "user://tests/../escape.json"]:
		var guarded = _fresh()
		_check(not guarded.continue_legacy_source(invalid).get("ok", true), "source override rejects unowned source: " + invalid)
	var damaged_source = _fresh()
	_round_trip(damaged_source, "legacy source backup initial")
	damaged_source.execute("mkdir ~/older-source-change")
	_round_trip(damaged_source, "legacy source backup newer")
	var damaged_path: String = slots[damaged_source.get_instance_id()]
	file = FileAccess.open(damaged_path, FileAccess.WRITE)
	_check(file != null, "only an owned source may be damaged for fallback regression")
	if file != null:
		file.store_string("{bad original with good backup")
		file.close()
	var bad_sha := FileAccess.get_sha256(damaged_path)
	var good_bak := FileAccess.get_sha256(damaged_path + ".bak")
	var rejected = _fresh()
	before = rejected.export_snapshot()
	_check(not rejected.continue_legacy_source(damaged_path).get("ok", true), "bad original never silently substitutes its valid backup")
	_check(_same(rejected.export_snapshot(), before) and not FileAccess.file_exists(slots[rejected.get_instance_id()]), "failed source fork creates no continuation or progress")
	_check(FileAccess.get_sha256(damaged_path) == bad_sha and FileAccess.get_sha256(damaged_path + ".bak") == good_bak, "source rejection preserves original and backup bytes")
	var v1: Variant = load("res://scripts/core/game.gd").new(test_root + "/original_v1.json")
	var old_definition: Dictionary = v1.get("_definition")
	_check(v1.execute("ssh maint@archive.packet.test").get("ok", false), "v1 import witness starts actual old authentication")
	_check(v1.submit_password(old_definition.hosts.archive.accounts.maint.password).get("ok", false), "v1 import witness authenticates the old account")
	_check(v1.execute("scp /vault/handoff.log").get("ok", false) and v1.get_view().get("completed", false), "v1 import witness earns its old M01 completion")
	var imported = _fresh()
	_check(imported.import_m01(v1.export_snapshot()).get("ok", false) and imported.get_view().get("completed", false), "explicit v1 M01 import remains available only in legacy continuation")
	_round_trip(imported, "explicit old v1 import")
