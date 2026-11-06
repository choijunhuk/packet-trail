extends RefCounted

const Model = preload("res://scripts/core/release_case.gd")
const Schema = preload("res://scripts/core/release_case_schema.gd")
var checks := 0
var failures: Array[String] = []


func run() -> Dictionary:
	checks = 0
	failures.clear()
	var definition := fixture()
	_check(Schema.validate(definition, mission()).is_empty(), "authored bounded release fixture validates: " + str(Schema.validate(definition, mission())))
	_invalid_schemas(definition)
	_test_json_schema(definition)
	var state: Dictionary = {}
	for input in [null, "verify", {"action": "unknown"}, {"action": "deploy", "artifact_id": "stable", "verified": true}, {"action": "report", "recipient_id": "press", "evidence_ids": ["stable_evidence"], "fields": [123]}, {"action": "inspect", "section": "private"}, {"action": "build", "build_id": "../../host"}]:
		var result := Model.apply_action(definition, input, state)
		_check(not result.ok and result.state == state, "invalid action cannot alter previous state")
	_check(not Model.goal_met(definition, state), "empty state cannot complete release review")
	_check(not Model.apply_action(definition, {"action": "deploy", "artifact_id": "stable"}, state).ok, "artifact cannot deploy without current verification")
	_check(not Model.apply_action(definition, {"action": "verify", "artifact_id": "stable", "statement_id": "stable_statement", "registry_id": "release_registry"}, state).ok, "verification requires actual artifact inspection")
	state = _apply(definition, state, {"action": "inspect_artifact", "artifact_id": "stable"})
	state = _apply(definition, state, {"action": "verify", "artifact_id": "stable", "statement_id": "bad_statement", "registry_id": "release_registry"})
	_check(not state.verified.stable.valid, "same filename cannot borrow a different artifact's provenance")
	_check(not Model.apply_action(definition, {"action": "deploy", "artifact_id": "stable"}, state).ok, "failed provenance observation never grants deploy permission")
	state = _apply(definition, state, {"action": "verify", "artifact_id": "stable", "statement_id": "untrusted_statement", "registry_id": "release_registry"})
	_check(not state.verified.stable.valid, "matching digest from an unregistered statement is insufficient")
	state = _apply(definition, state, {"action": "inspect_artifact", "artifact_id": "revoked"})
	state = _apply(definition, state, {"action": "verify", "artifact_id": "revoked", "statement_id": "revoked_statement", "registry_id": "release_registry"})
	_check(not state.verified.revoked.valid, "revoked builder fails even with registered matching provenance")
	state = _apply(definition, state, {"action": "inspect_artifact", "artifact_id": "unsafe"})
	state = _apply(definition, state, {"action": "verify", "artifact_id": "unsafe", "statement_id": "unsafe_statement", "registry_id": "release_registry"})
	_check(state.verified.unsafe.valid, "authentic provenance can describe an unsafe release")
	state = _apply(definition, state, {"action": "deploy", "artifact_id": "unsafe"})
	state = _probe_all(definition, state)
	_check(state.probe_receipts.normal.status == 200 and state.probe_receipts.outside.status == 200, "service outcomes follow actual manifest including unsafe external delivery")
	_check(not Model.goal_met(definition, state), "verified unsafe artifact cannot satisfy service goals")
	var bad_report := Model.apply_action(definition, {"action": "report", "recipient_id": "press", "evidence_ids": ["stable_evidence"], "fields": ["stable_digest"]}, state)
	_check(not bad_report.ok and bad_report.state == state, "cannot report uncorrected business behavior as completion")
	var rollback := _finish_route(definition, false, "staff")
	var rebuilt := _finish_route(definition, true, "press")
	_check(Model.goal_met(definition, rollback) and Model.goal_met(definition, rebuilt), "rollback and rebuilt routes both complete with valid recipient follow-up")
	_check(rollback.deployed != rebuilt.deployed and rollback.report.recipient_id != rebuilt.report.recipient_id, "routes have different deployed artifact and recipient outcomes")
	_check(Model.project_page(definition, rollback, "article").is_empty(), "private staff report does not generate a news article")
	var article := Model.project_page(definition, rebuilt, "article")
	_check(not article.is_empty() and not article.pending and str(article.body).begins_with("PRESS_RESULT") and str(article.body).contains(str(definition.artifacts.stable.payload).sha256_text()), "verified journalist follow-up produces its own final article")
	_check(str(Model.project_page(definition, rollback, "reply").body).begins_with("STAFF_RESULT"), "staff recipient has an independent observable reply")
	_check(not JSON.stringify(Model.public_data(definition, rollback)).contains("private-routing-secret"), "public projections never leak restricted field content even for staff report")
	_check(not JSON.stringify(Model.public_data(definition, rebuilt)).contains("private-routing-secret"), "news projections redact restricted data")
	var before := rebuilt.duplicate(true)
	var view := Model.public_data(definition, rebuilt)
	var page := Model.project_page(definition, rebuilt, "reply")
	_check(not view.is_empty() and not page.is_empty() and rebuilt == before, "tool and page reads are side-effect free")
	var invalid := Model.apply_action(definition, {"action": "report", "recipient_id": "press", "evidence_ids": ["stable_evidence", "bad_evidence"], "fields": ["stable_digest", "bad_digest", "private_note"]}, rebuilt)
	_check(not invalid.ok and invalid.state == rebuilt, "journalist cannot receive restricted fields")
	invalid = Model.apply_action(definition, {"action": "report", "recipient_id": "press", "evidence_ids": ["fabricated"], "fields": ["stable_digest"]}, rebuilt)
	_check(not invalid.ok and invalid.state == rebuilt, "fabricated evidence is rejected without partial changes")
	invalid = Model.apply_action(definition, {"action": "followup", "followup_id": "staff_check", "evidence_ids": ["stable_evidence", "bad_evidence"]}, rebuilt)
	_check(not invalid.ok and invalid.state == rebuilt, "follow-up must match the actual chosen recipient")
	invalid = Model.apply_action(definition, {"action": "followup", "followup_id": "press_check", "evidence_ids": ["bad_evidence"]}, rebuilt)
	_check(not invalid.ok and invalid.state == rebuilt, "digest mismatch claim requires both inspected artifact sources")
	var tampered := definition.duplicate(true)
	tampered.artifacts.stable.payload = _payload(["ward", "outside"])
	_check(not Model.goal_met(tampered, rollback), "artifact content changes invalidate current verification and receipts")
	tampered = definition.duplicate(true)
	tampered.registries.release_registry.revoked_builders.append("approved_builder")
	_check(not Model.goal_met(tampered, rebuilt), "builder revocation invalidates completion basis")
	var redeployed := _apply(definition, rebuilt, {"action": "deploy", "artifact_id": "rebuilt"})
	_check(redeployed.probe_receipts.is_empty() and redeployed.report.is_empty() and redeployed.followup.is_empty() and not Model.goal_met(definition, redeployed), "redeployment requires new service and reporting checks")
	var reset := _apply(definition, rebuilt, {"action": "restore_initial"})
	_check(reset.deployed == "" and reset.built.is_empty() and reset.inspected.is_empty() and not Model.goal_met(definition, reset), "restoring initial state recovers without stale completion")
	var shutdown := _prepare_artifact(definition, {}, "disabled", "disabled_statement")
	shutdown = _apply(definition, shutdown, {"action": "deploy", "artifact_id": "disabled"})
	shutdown = _probe_all(definition, shutdown)
	_check(shutdown.probe_receipts.normal.status == 503 and not shutdown.probe_receipts.normal.business and not Model.goal_met(definition, shutdown), "stopping every service is not a successful release repair")
	var inspect_only := _apply(definition, {}, {"action": "inspect_artifact", "artifact_id": "bad"})
	var evidence: Array = Model.public_data(definition, inspect_only).evidence
	_check(evidence[0].fields[0].get("value", "") == "", "uninspected evidence values are not disclosed")
	_check(evidence[1].fields[0].value == definition.artifacts.bad.payload.sha256_text(), "observed evidence uses actual payload digest")
	return {"suite": "release_case", "checks": checks, "failures": failures.duplicate(), "limit": "Pure deterministic virtual model/schema checks; campaign replay, UI and human learning acceptance are separate."}


func _finish_route(definition: Dictionary, rebuild: bool, recipient: String) -> Dictionary:
	var state: Dictionary = {}
	for id in ["stable", "bad"]: state = _apply(definition, state, {"action": "inspect_artifact", "artifact_id": id})
	var artifact_id := "stable"
	var statement_id := "stable_statement"
	if rebuild:
		state = _apply(definition, state, {"action": "build", "build_id": "rebuilt"})
		artifact_id = "rebuilt"
		statement_id = "rebuilt_statement"
	state = _prepare_artifact(definition, state, artifact_id, statement_id)
	state = _apply(definition, state, {"action": "deploy", "artifact_id": artifact_id})
	state = _probe_all(definition, state)
	var fields := ["stable_digest", "bad_digest"]
	if recipient == "staff": fields.append("private_note")
	state = _apply(definition, state, {"action": "report", "recipient_id": recipient, "evidence_ids": ["stable_evidence", "bad_evidence"], "fields": fields})
	state = _apply(definition, state, {"action": "followup", "followup_id": definition.recipients[recipient].followup_id, "evidence_ids": ["stable_evidence", "bad_evidence"]})
	return state


func _prepare_artifact(definition: Dictionary, state: Dictionary, id: String, statement: String) -> Dictionary:
	state = _apply(definition, state, {"action": "inspect_artifact", "artifact_id": id})
	return _apply(definition, state, {"action": "verify", "artifact_id": id, "statement_id": statement, "registry_id": "release_registry"})


func _probe_all(definition: Dictionary, state: Dictionary) -> Dictionary:
	for id in definition.required_service_cases: state = _apply(definition, state, {"action": "probe", "case_id": id})
	return state


func _apply(definition: Dictionary, state: Dictionary, input: Dictionary) -> Dictionary:
	var before := state.duplicate(true)
	var result: Dictionary = Model.apply_action(definition, input, state)
	_check(result.ok and result.effects == {}, "valid action has no external effects: " + str(input))
	_check(state == before, "model does not mutate its input state: " + str(input.action))
	return result.state


func _test_json_schema(definition: Dictionary) -> void:
	var restored: Dictionary = JSON.parse_string(JSON.stringify(definition))
	_check(Schema.validate(restored, mission()).is_empty(), "JSON-restored release definition validates without loader normalization")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/packs/investigation_v1.json"))
	var authored: Dictionary = pack.missions.I02
	_check(Schema.validate(authored.challenges.iv1_i02_release, authored).is_empty(), "raw authored I02 JSON definition validates without loader normalization")
	for row in [[200.0, true], [403.0, false], [503.0, false]]:
		var numeric := definition.duplicate(true)
		numeric.service_cases.normal.expected_status = row[0]
		numeric.service_cases.normal.expected_business = row[1]
		_check(Schema.validate(numeric, mission()).is_empty(), "integer-valued JSON service status validates: " + str(row[0]))
	for value in [200.5, 403.5, 503.5, 201, "200", true, null]:
		var invalid := definition.duplicate(true)
		invalid.service_cases.normal.expected_status = value
		_check(not Schema.validate(invalid, mission()).is_empty(), "fractional, unsupported or nonnumeric service status is rejected: " + str(value))


func _invalid_schemas(definition: Dictionary) -> void:
	for change in ["payload", "digest", "reference", "private", "collision", "manifest", "evidence", "duplicate_field", "build_digest", "build_source", "build_builder", "build_untrusted_builder", "build_revoked_builder", "build_untrusted_statement"]:
		var invalid := definition.duplicate(true)
		match change:
			"payload": invalid.artifacts.stable.payload = "A".repeat(4097)
			"digest": invalid.statements.stable_statement.subject_digest = "not-a-digest"
			"reference": invalid.recipients.press.allowed_fields.append("invented")
			"private": invalid.recipients.press.allowed_fields.append("private_note")
			"collision": invalid.builds.stable = invalid.builds.rebuilt.duplicate(true)
			"manifest": invalid.artifacts.stable.payload = '{"enabled":true,"operations":{"serve":"ward"}}'
			"evidence": invalid.report_evidence.stable_evidence.artifact_id = "invented"
			"duplicate_field": invalid.report_evidence.bad_evidence.fields.stable_digest = {"source": "digest", "sensitivity": "public"}
			"build_digest": invalid.builds.rebuilt.payload = _payload(["ward", "outside"])
			"build_source": invalid.builds.rebuilt.source_revision = "different_source"
			"build_builder": invalid.builds.rebuilt.builder_id = "different_builder"
			"build_untrusted_builder": invalid.registries.release_registry.trusted_builders.erase("approved_builder")
			"build_revoked_builder": invalid.registries.release_registry.revoked_builders.append("approved_builder")
			"build_untrusted_statement": invalid.registries.release_registry.trusted_statements.erase("rebuilt_statement")
		_check(not Schema.validate(invalid, mission()).is_empty(), "schema rejects invalid authoring: " + change)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)


static func _payload(targets: Array, enabled := true) -> String:
	return JSON.stringify({"enabled": enabled, "operations": {"notify": targets}})


static func mission() -> Dictionary:
	return {"hosts": {"build_host": {"accounts": {"operator": {}}}}}


static func fixture() -> Dictionary:
	var stable := _payload(["ward"])
	var unsafe := _payload(["ward", "outside"])
	var disabled := _payload([], false)
	var rebuilt := _payload(["ward", "audit"])
	var artifacts := {}
	for row in [["stable", stable, "old_source", "approved_builder"], ["bad", unsafe, "unreviewed_source", "other_builder"], ["unsafe", unsafe, "reviewed_but_wrong", "approved_builder"], ["revoked", stable, "old_source", "revoked_builder"], ["disabled", disabled, "disabled_source", "approved_builder"]]:
		artifacts[row[0]] = {"label": str(row[0]), "filename": "same-release.pkg", "payload": row[1], "source_revision": row[2], "builder_id": row[3]}
	var statements := {}
	for id in artifacts:
		statements[id + "_statement"] = {"subject_digest": str(artifacts[id].payload).sha256_text(), "source_revision": artifacts[id].source_revision, "builder_id": artifacts[id].builder_id, "registry_id": "release_registry"}
	statements["untrusted_statement"] = statements.stable_statement.duplicate(true)
	statements["rebuilt_statement"] = {"subject_digest": rebuilt.sha256_text(), "source_revision": "reviewed_source", "builder_id": "approved_builder", "registry_id": "release_registry"}
	return {"kind": "release_case", "host_id": "build_host", "requires_session": {"host_id": "build_host", "account_id": "operator"}, "artifacts": artifacts, "statements": statements,
		"registries": {"release_registry": {"trusted_builders": ["approved_builder", "revoked_builder"], "revoked_builders": ["revoked_builder"], "trusted_statements": ["stable_statement", "bad_statement", "unsafe_statement", "revoked_statement", "disabled_statement", "rebuilt_statement"]}},
		"builds": {"rebuilt": {"label": "Rebuild reviewed source", "filename": "rebuilt.pkg", "payload": rebuilt, "source_revision": "reviewed_source", "builder_id": "approved_builder", "statement_id": "rebuilt_statement", "registry_id": "release_registry"}},
		"service_cases": {"normal": {"label": "Normal notification", "operation": "notify", "target": "ward", "expected_status": 200, "expected_business": true}, "outside": {"label": "Outside notification", "operation": "notify", "target": "outside", "expected_status": 403, "expected_business": false}}, "required_service_cases": ["normal", "outside"],
		"report_evidence": {"stable_evidence": {"label": "Independent stable archive", "artifact_id": "stable", "fields": {"stable_digest": {"source": "digest", "sensitivity": "public"}, "private_note": {"text": "private-routing-secret", "sensitivity": "restricted"}}}, "bad_evidence": {"label": "Received archive", "artifact_id": "bad", "fields": {"bad_digest": {"source": "digest", "sensitivity": "public"}}}},
		"recipients": {"staff": {"label": "Maintainer", "allowed_fields": ["stable_digest", "bad_digest", "private_note"], "required_evidence": ["stable_evidence", "bad_evidence"], "reply_key": "STAFF_REPLY", "followup_id": "staff_check", "public": false}, "press": {"label": "Newsroom", "allowed_fields": ["stable_digest", "bad_digest"], "required_evidence": ["stable_evidence", "bad_evidence"], "reply_key": "PRESS_REPLY", "followup_id": "press_check", "public": true}},
		"followups": {"staff_check": {"predicate": "current_release", "required_artifacts": ["bad"], "result_key": "STAFF_RESULT"}, "press_check": {"predicate": "digest_mismatch", "required_artifacts": ["stable", "bad"], "result_key": "PRESS_RESULT"}}}
