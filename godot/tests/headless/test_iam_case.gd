extends RefCounted

const Model = preload("res://scripts/core/iam_case.gd")
const Schema = preload("res://scripts/core/iam_case_schema.gd")

var checks := 0
var failures: Array[String] = []


func run() -> Dictionary:
	checks = 0
	failures.clear()
	var definition := fixture()
	var frozen := definition.duplicate(true)
	_check(Schema.validate(definition, mission()).is_empty(), "authored finite IAM definition validates")
	var initial: Dictionary = Model.initial_state(definition, {})
	_check(not Model.goal_met(definition, initial), "initial configuration has no successful assessment receipts")
	var unsafe: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": "cross_tenant"}, initial)
	_check(unsafe.ok and unsafe.feedback.decision == "allow", "broad initial grant exposes an actual cross-tenant counterexample")
	_check(not unsafe.solved, "observing unsafe access is not completion")
	var bound: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "narrow"}, unsafe.state)
	var scoped: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": "cross_tenant"}, bound.state)
	_check(scoped.feedback.decision == "deny", "restricted binding rejects cross-tenant access")
	_check(initial.bindings.agent == "broad", "state updates do not mutate the input state")
	_check(definition == frozen, "state operations do not mutate authored rules")
	var direct: Dictionary = _solve(definition, false)
	_check(Model.goal_met(definition, direct), "precise role repair preserves every normal request and rejects negatives")
	var alternate: Dictionary = _solve(definition, true)
	_check(Model.goal_met(definition, alternate), "approved replacement route satisfies the same required outcomes")
	_check(direct.bindings.agent != alternate.bindings.agent, "two routes finish with different actual role bindings")
	_check(direct.probe_receipts.normal_read.credential_ref != alternate.probe_receipts.normal_read.credential_ref, "replacement route uses a different registered credential principal")
	_check(direct.probe_receipts.normal_read.principal_id == "agent" and alternate.probe_receipts.normal_read.principal_id == "gateway", "request receipts identify the real evaluated principal")
	var stale: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "broad"}, direct)
	_check(not stale.solved and not Model.goal_met(definition, stale.state), "changing a binding invalidates old successful assessment evidence")
	stale.state.solved = true
	_check(not Model.goal_met(definition, stale.state), "sticky completion marker cannot substitute for current policy evidence")
	var repaired: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "narrow"}, stale.state)
	_check(Model.goal_met(definition, _probe_all(definition, repaired.state)), "restored correct policy can be reassessed without restarting the case")
	var forged := direct.duplicate(true)
	forged.probe_receipts.normal_read.principal_id = "gateway"
	_check(not Model.goal_met(definition, forged), "forged principal in a request receipt is rejected")
	forged = direct.duplicate(true)
	forged.probe_receipts.normal_read.route_id = "invented"
	_check(not Model.goal_met(definition, forged), "unregistered receipt route is rejected")
	var expired: Dictionary = Model.apply_action(definition, {"action": "advance", "ticks": 32}, direct)
	for index in 3:
		expired = Model.apply_action(definition, {"action": "advance", "ticks": 32}, expired.state)
	_check(not expired.solved, "logical credential expiry invalidates current completion")
	var expired_probe: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": "normal_read"}, expired.state)
	_check(expired_probe.feedback.reason == "CREDENTIAL_EXPIRED" and expired_probe.feedback.decision == "deny", "expired normal credential is actually denied")
	var restored: Dictionary = Model.apply_action(definition, {"action": "restore_initial"}, expired_probe.state)
	_check(restored.state.tick == 0 and restored.state.probe_receipts.is_empty() and not restored.solved, "restore returns authored time/configuration and clears assessment receipts")
	_check(Model.goal_met(definition, _solve_from(definition, restored.state, false)), "expiry and revocation experiments remain recoverable")
	var revoked: Dictionary = Model.apply_action(definition, {"action": "revoke", "credential_ref": "builder"}, direct)
	_check(not revoked.solved, "revoking a required normal credential cannot complete by closing everything")
	var revoke_probe: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": "normal_read"}, revoked.state)
	_check(revoke_probe.feedback.reason == "CREDENTIAL_REVOKED", "revocation takes effect on the actual normal request")
	_test_deny_precedence(definition)
	_test_invalid_actions(definition, direct)
	_test_schema(definition)
	_test_receipt_freshness(definition, direct)
	_test_json_round_trip(definition, direct, alternate)
	_test_authored_initial_assessment()
	var public_before := direct.duplicate(true)
	var view: Dictionary = Model.public_data(definition, direct)
	_check(view.principals.size() == 4 and view.credentials.size() == 6 and view.requests.size() == 7, "public inspection exposes registered identities, credential state and request evidence")
	view.bindings[0].role_id = "invented"
	view.probe_receipts.normal_read.decision = "deny"
	_check(direct == public_before and definition == frozen, "public projection is read-only and does not alias canonical evidence")
	return {"suite": "iam_case", "checks": checks, "failures": failures, "limit": "Pure finite IAM model/schema checks; Runtime authorization, real campaign replay, native UI and provider IAM completeness are separate."}


func _test_receipt_freshness(definition: Dictionary, solved: Dictionary) -> void:
	for row in Model.public_data(definition, {}).requests:
		_check(row.get("current") == false and row.observed.is_empty(), "unobserved request has no current evidence")
	for row in Model.public_data(definition, solved).requests:
		_check(row.get("current") == true, "successful request receipt is current: " + row.request_id)
	var changed: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "gateway", "role_id": "blocked"}, solved)
	for row in Model.public_data(definition, changed.state).requests:
		_check(row.get("current") == false, "unrelated policy change marks previous receipt stale: " + row.request_id)
	var state: Dictionary = changed.state
	for id in definition.required_requests:
		if id != "normal_read":
			state = Model.apply_action(definition, {"action": "probe", "request_id": id}, state).state
	for row in Model.public_data(definition, state).requests:
		if row.request_id == "normal_read":
			_check(row.observed.decision == "allow" and row.get("current") == false, "matching old decision still exposes stale evidence")
	_check(not Model.goal_met(definition, state), "matching displayed decisions cannot replace current evidence")
	var refreshed: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": "normal_read"}, state)
	_check(refreshed.solved, "rechecking the last stale request restores completion")
	for input in [{"action": "revoke", "credential_ref": "relay"}, {"action": "advance", "ticks": 1}]:
		changed = Model.apply_action(definition, input, solved)
		for row in Model.public_data(definition, changed.state).requests:
			_check(row.get("current") == false, "credential or time change marks previous evidence stale")
	for field in ["route_id", "principal_id", "tick"]:
		var forged := solved.duplicate(true)
		forged.probe_receipts.normal_read[field] = 0.5 if field == "tick" else "invented"
		for row in Model.public_data(definition, forged).requests:
			if row.request_id == "normal_read":
				_check(row.get("current") == false, "forged receipt cannot appear current: " + field)
		_check(not Model.goal_met(definition, forged), "forged receipt cannot complete: " + field)


func _test_json_round_trip(definition: Dictionary, direct: Dictionary, alternate: Dictionary) -> void:
	for solved in [direct, alternate]:
		var advanced: Dictionary = Model.apply_action(definition, {"action": "advance", "ticks": 3}, solved)
		var state: Dictionary = _probe_all(definition, advanced.state, solved.bindings.agent == "blocked")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
		var before := restored.duplicate(true)
		_check(Model.goal_met(definition, restored), "JSON-restored integer receipt ticks preserve current completion")
		_check(Model.apply_action(definition, {"action": "inspect"}, restored).solved, "direct model inspection accepts JSON-restored evidence")
		for row in Model.public_data(definition, restored).requests:
			_check(row.get("current") == true, "JSON-restored request evidence remains current")
		_check(restored == before, "JSON evidence checks do not mutate the caller's state")


func _test_authored_initial_assessment() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/packs/investigation_v1.json"))
	var definition: Dictionary = pack.missions.I01.challenges.iv1_i01_iam
	var state: Dictionary = Model.initial_state(definition, {})
	for id in definition.required_requests:
		state = Model.apply_action(definition, {"action": "probe", "request_id": id, "route_id": "direct"}, state).state
	_check(not Model.goal_met(definition, state), "authored I01 cannot complete by probing every direct route without repair")
	_check(state.probe_receipts.cross_tenant.decision == "allow" and state.probe_receipts.grant_change.decision == "allow" and state.probe_receipts.retired_access.decision == "allow", "authored initial assessment exposes the three unrepaired grants")


func _solve(definition: Dictionary, alternate: bool) -> Dictionary:
	return _solve_from(definition, Model.initial_state(definition, {}), alternate)


func _solve_from(definition: Dictionary, previous: Dictionary, alternate: bool) -> Dictionary:
	var result: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "blocked" if alternate else "narrow"}, previous)
	_check(result.ok, "registered role repair action succeeds")
	result = Model.apply_action(definition, {"action": "revoke", "credential_ref": "contractor"}, result.state)
	_check(result.ok, "registered contractor credential revocation succeeds")
	return _probe_all(definition, result.state, alternate)


func _probe_all(definition: Dictionary, previous: Dictionary, alternate := false) -> Dictionary:
	var state := previous.duplicate(true)
	for id in definition.required_requests:
		var result: Dictionary = Model.apply_action(definition, {"action": "probe", "request_id": id, "route_id": "relay" if alternate and id == "normal_read" else "direct"}, state)
		_check(result.ok, "registered assessment probe succeeds: " + id)
		state = result.state
	return state


func _test_deny_precedence(definition: Dictionary) -> void:
	var result: Dictionary = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "deny_override"}, {})
	result = Model.apply_action(definition, {"action": "probe", "request_id": "normal_read"}, result.state)
	_check(result.feedback.decision == "deny" and result.feedback.reason == "EXPLICIT_DENY" and result.feedback.matched_rules.size() == 2, "explicit deny overrides an applicable allow rule")
	var reversed := definition.duplicate(true)
	reversed.roles.deny_override.rules.reverse()
	var replay: Dictionary = Model.apply_action(reversed, {"action": "probe", "request_id": "normal_read"}, result.state)
	_check(replay.feedback.decision == "deny", "deny precedence is independent of authored rule order")
	var same_tenant := definition.duplicate(true)
	same_tenant.roles.narrow.rules[0].resources = ["foreign_secret"]
	result = Model.apply_action(same_tenant, {"action": "bind", "principal_id": "agent", "role_id": "narrow"}, {})
	result = Model.apply_action(same_tenant, {"action": "probe", "request_id": "cross_tenant"}, result.state)
	_check(result.feedback.decision == "deny" and result.feedback.matched_rules.is_empty(), "same-tenant condition rejects a matching foreign resource")
	same_tenant.roles.narrow.rules[0].tenant_scope = "any"
	result = Model.apply_action(same_tenant, {"action": "probe", "request_id": "cross_tenant"}, result.state)
	_check(result.feedback.decision == "allow", "authored any-tenant scope differs from same-tenant evaluation")
	result = Model.apply_action(definition, {"action": "bind", "principal_id": "agent", "role_id": "blocked"}, {})
	result = Model.apply_action(definition, {"action": "probe", "request_id": "normal_read"}, result.state)
	_check(result.feedback.decision == "deny" and result.feedback.reason == "DEFAULT_DENY", "absence of allow means default deny")


func _test_invalid_actions(definition: Dictionary, state: Dictionary) -> void:
	var frozen := state.duplicate(true)
	var inputs: Array = [null, "allow", {"action": true}, {"action": "grant_all"}, {"action": "bind", "principal_id": "agent", "role_id": "ops"}, {"action": "bind", "principal_id": "invented", "role_id": "narrow"}, {"action": "bind", "principal_id": ["agent"], "role_id": "narrow"}, {"action": "revoke", "credential_ref": "invented"}, {"action": "probe", "request_id": "invented"}, {"action": "probe", "request_id": "normal_read", "route_id": "invented"}, {"action": "probe", "request_id": "normal_read", "decision": "allow"}, {"action": "inspect", "section": "private_state"}, {"action": "inspect", "section": ["bindings"]}, {"action": "advance", "ticks": 0}, {"action": "advance", "ticks": 33}, {"action": "advance", "ticks": 1.5}, {"action": "advance", "ticks": true}, {"action": "inspect", "terminal_id": 4}, {"action": "inspect", "challenge_id": []}, {"action": "restore_initial", "state": {"solved": true}}]
	for input in inputs:
		var result: Dictionary = Model.apply_action(definition, input, state)
		_check(not result.ok and result.state == frozen and state == frozen, "invalid action is a no-op: " + str(input))
	var corrupt := state.duplicate(true)
	corrupt.bindings.agent = "ops"
	_check(not Model.apply_action(definition, {"action": "inspect"}, corrupt).ok and not Model.goal_met(definition, corrupt), "corrupt state with unauthorized binding is rejected")
	corrupt = state.duplicate(true)
	corrupt.revoked.revoked = false
	_check(not Model.apply_action(definition, {"action": "inspect"}, corrupt).ok, "authored revoked credentials cannot be revived by injected state")
	corrupt = state.duplicate(true)
	corrupt.tick = 4096
	_check(not Model.apply_action(definition, {"action": "advance", "ticks": 1}, corrupt).ok, "logical tick limit is bounded without partial mutation")
	var transport: Dictionary = Model.apply_action(definition, {"action": "inspect", "terminal_id": 2, "challenge_id": "iam-review"}, state)
	_check(transport.ok and transport.state == frozen, "validated transport identifiers do not change model authority")


func _test_schema(definition: Dictionary) -> void:
	var invalid := definition.duplicate(true)
	invalid.kind = false
	_check(not Schema.validate(invalid, mission()).is_empty(), "nontext model kind is rejected cleanly")
	invalid = definition.duplicate(true)
	invalid.roles.narrow.rules[0].effect = "maybe"
	_check(not Schema.validate(invalid, mission()).is_empty(), "unknown policy effect is rejected")
	invalid = definition.duplicate(true)
	invalid.roles.narrow.rules[0].resources = ["missing"]
	_check(not Schema.validate(invalid, mission()).is_empty(), "unregistered resource reference is rejected")
	invalid = definition.duplicate(true)
	invalid.roles.narrow.rules[0].tenant_scope = "guess"
	_check(not Schema.validate(invalid, mission()).is_empty(), "unknown tenant condition is rejected")
	invalid = definition.duplicate(true)
	invalid.credentials.builder.expires_tick = 1.5
	_check(not Schema.validate(invalid, mission()).is_empty(), "fractional credential expiry is rejected")
	invalid = definition.duplicate(true)
	invalid.credentials.builder.revoked = "false"
	_check(not Schema.validate(invalid, mission()).is_empty(), "nonboolean revocation seed is rejected")
	invalid = definition.duplicate(true)
	invalid.requests.normal_read.routes.relay.credential_ref = "missing"
	_check(not Schema.validate(invalid, mission()).is_empty(), "unregistered route credential is rejected")
	invalid = definition.duplicate(true)
	invalid.binding_choices.agent = ["missing"]
	_check(not Schema.validate(invalid, mission()).is_empty(), "unregistered role choices are rejected")
	invalid = definition.duplicate(true)
	invalid.required_requests = ["cross_tenant"]
	_check(not Schema.validate(invalid, mission()).is_empty(), "assessment cannot consist only of denied requests")
	invalid = definition.duplicate(true)
	invalid.required_requests = ["normal_read", "normal_read", "cross_tenant"]
	_check(not Schema.validate(invalid, mission()).is_empty(), "duplicate assessment IDs are rejected")
	invalid = definition.duplicate(true)
	invalid.requires_session.account_id = "missing"
	_check(not Schema.validate(invalid, mission()).is_empty(), "operator authority references a real authored account")
	invalid = definition.duplicate(true)
	invalid.roles.narrow.rules[0].caller_decision = "allow"
	_check(not Schema.validate(invalid, mission()).is_empty(), "unknown rule fields cannot smuggle a result")
	invalid = definition.duplicate(true)
	invalid.requests.normal_read.expect = ["allow"]
	_check(not Schema.validate(invalid, mission()).is_empty(), "wrong expected-decision type is rejected without evaluation")
	invalid = definition.duplicate(true)
	invalid.credentials = []
	_check(not Schema.validate(invalid, mission()).is_empty(), "wrong registry type is rejected cleanly")


static func mission() -> Dictionary:
	return {"hosts": {"console": {"accounts": {"auditor": {}}}}}


static func fixture() -> Dictionary:
	var value := {"kind": "iam_case", "host_id": "console", "requires_session": {"host_id": "console", "account_id": "auditor"}, "name": "IAM fixture", "principals": {"agent": {"tenant": "town"}, "operator": {"tenant": "town"}, "contractor": {"tenant": "town"}, "gateway": {"tenant": "town"}}, "resources": {"artifact": {"tenant": "town"}, "notice": {"tenant": "town"}, "foreign_secret": {"tenant": "other"}}, "roles": {"broad": {"rules": [{"effect": "allow", "actions": ["read", "policy:write"], "resources": ["artifact", "foreign_secret"], "tenant_scope": "any"}]}, "narrow": {"rules": [{"effect": "allow", "actions": ["read"], "resources": ["artifact"], "tenant_scope": "same"}]}, "ops": {"rules": [{"effect": "allow", "actions": ["write"], "resources": ["notice"], "tenant_scope": "same"}]}, "blocked": {"rules": []}, "deny_override": {"rules": [{"effect": "allow", "actions": ["read"], "resources": ["artifact"], "tenant_scope": "same"}, {"effect": "deny", "actions": ["read"], "resources": ["artifact"], "tenant_scope": "any"}]}}, "initial_bindings": {"agent": "broad", "operator": "ops", "contractor": "narrow", "gateway": "narrow"}, "binding_choices": {"agent": ["broad", "narrow", "blocked", "deny_override"], "operator": ["ops", "blocked"], "contractor": ["narrow", "blocked"], "gateway": ["narrow", "blocked"]}, "credentials": {"builder": {"principal_id": "agent", "expires_tick": 100, "revoked": false}, "operations": {"principal_id": "operator", "expires_tick": 100, "revoked": false}, "contractor": {"principal_id": "contractor", "expires_tick": 100, "revoked": false}, "relay": {"principal_id": "gateway", "expires_tick": 100, "revoked": false}, "expired": {"principal_id": "agent", "expires_tick": 0, "revoked": false}, "revoked": {"principal_id": "agent", "expires_tick": 100, "revoked": true}}, "requests": {}, "required_requests": []}
	value.requests = {
		"normal_read": {"label": "Normal artifact read", "credential_ref": "builder", "action": "read", "resource_id": "artifact", "expect": "allow", "routes": {"relay": {"credential_ref": "relay"}}},
		"normal_notice": {"label": "Normal notice update", "credential_ref": "operations", "action": "write", "resource_id": "notice", "expect": "allow"},
		"cross_tenant": {"label": "Foreign tenant read", "credential_ref": "builder", "action": "read", "resource_id": "foreign_secret", "expect": "deny"},
		"policy_change": {"label": "Policy change", "credential_ref": "builder", "action": "policy:write", "resource_id": "artifact", "expect": "deny"},
		"contractor_read": {"label": "Old contractor access", "credential_ref": "contractor", "action": "read", "resource_id": "artifact", "expect": "deny"},
		"expired_read": {"label": "Expired access", "credential_ref": "expired", "action": "read", "resource_id": "artifact", "expect": "deny"},
		"revoked_read": {"label": "Revoked access", "credential_ref": "revoked", "action": "read", "resource_id": "artifact", "expect": "deny"}}
	value.required_requests = value.requests.keys()
	return value


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
