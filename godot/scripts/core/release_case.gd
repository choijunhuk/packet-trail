extends RefCounted
## Finite virtual provenance and disclosure model; no host compiler or cryptography is executed.

const SECTIONS := ["artifacts", "provenance", "registries", "builds", "services", "evidence", "recipients", "deployment", "report", "replies", "article"]
const ACTION_FIELDS := {
	"inspect": ["action", "section"], "inspect_artifact": ["action", "artifact_id"],
	"inspect_provenance": ["action", "statement_id"], "verify": ["action", "artifact_id", "statement_id", "registry_id"],
	"build": ["action", "build_id"], "deploy": ["action", "artifact_id"], "probe": ["action", "case_id"],
	"report": ["action", "recipient_id", "evidence_ids", "fields"], "followup": ["action", "followup_id", "evidence_ids"],
	"restore_initial": ["action"],
}


static func initial_state(_definition: Dictionary, previous: Dictionary) -> Dictionary:
	var state: Dictionary = previous.duplicate(true)
	for key in ["inspected", "verified", "probe_receipts", "report", "followup"]:
		state[key] = state.get(key, {})
	for key in ["built", "inspected_provenance"]:
		state[key] = state.get(key, [])
	state["deployed"] = state.get("deployed", "")
	return state


static func apply_action(definition: Dictionary, input: Variant, previous: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not _valid_input(input):
		return _error("RELEASE_INVALID", "Select a registered release action and its fields.", previous)
	var state: Dictionary = initial_state(definition, previous)
	var action: String = input.action
	var feedback: Dictionary = {}
	match action:
		"inspect":
			var section: String = input.get("section", "artifacts")
			if not SECTIONS.has(section): return _error("RELEASE_INVALID", "Unknown inspection section.", previous)
			feedback = {"section": section, "rows": public_data(definition, state, context).get(section, [])}
		"restore_initial":
			state = initial_state(definition, {})
		"inspect_artifact":
			var id: String = input.artifact_id
			var artifact: Dictionary = _artifact(definition, state, id)
			if artifact.is_empty(): return _error("RELEASE_UNKNOWN", "Unknown available artifact.", previous)
			state.inspected[id] = str(artifact.payload).sha256_text()
			feedback = {"artifact_id": id, "digest": state.inspected[id], "manifest": JSON.parse_string(artifact.payload)}
		"inspect_provenance":
			var id: String = input.statement_id
			if not definition.statements.has(id): return _error("RELEASE_UNKNOWN", "Unknown registered statement.", previous)
			if not state.inspected_provenance.has(id): state.inspected_provenance.append(id)
			feedback = {"statement_id": id}
		"verify":
			var id: String = input.artifact_id
			if _artifact(definition, state, id).is_empty() or not definition.statements.has(input.statement_id) or not definition.registries.has(input.registry_id):
				return _error("RELEASE_UNKNOWN", "Unknown artifact, statement or registry.", previous)
			if not _inspected(definition, state, id): return _error("RELEASE_UNOBSERVED", "Inspect the actual artifact before verification.", previous)
			var verification: Dictionary = {"artifact_id": id, "statement_id": input.statement_id, "registry_id": input.registry_id}
			verification["basis"] = _verification_basis(definition, state, verification)
			verification["valid"] = _valid_verification(definition, state, verification)
			state.verified[id] = verification
			if not state.inspected_provenance.has(input.statement_id): state.inspected_provenance.append(input.statement_id)
			feedback = {"artifact_id": id, "verified": verification.valid, "statement_id": input.statement_id}
		"build":
			var id: String = input.build_id
			if not definition.builds.has(id): return _error("RELEASE_UNKNOWN", "Unknown approved virtual build.", previous)
			if not state.built.has(id): state.built.append(id)
			feedback = {"artifact_id": id, "digest": str(definition.builds[id].payload).sha256_text()}
		"deploy":
			var id: String = input.artifact_id
			if not _verified(definition, state, id): return _error("RELEASE_UNVERIFIED", "Deployment needs current provenance verification.", previous)
			state.deployed = id
			state.probe_receipts.clear()
			state.report.clear()
			state.followup.clear()
			feedback = {"artifact_id": id}
		"probe":
			var id: String = input.case_id
			if not definition.service_cases.has(id): return _error("RELEASE_UNKNOWN", "Unknown service check.", previous)
			if str(state.deployed).is_empty(): return _error("RELEASE_UNDEPLOYED", "Deploy a verified artifact before checking service behavior.", previous)
			var outcome: Dictionary = _service_outcome(definition, state, id)
			var receipt: Dictionary = outcome.duplicate(true)
			receipt["basis"] = _deployment_basis(definition, state)
			state.probe_receipts[id] = receipt
			feedback = {"case_id": id, "status": outcome.status, "business": outcome.business}
		"report":
			if not _services_current(definition, state): return _error("RELEASE_NOT_READY", "Verify the current deployment and its service checks first.", previous)
			var report: Dictionary = {"recipient_id": input.recipient_id, "evidence_ids": input.evidence_ids.duplicate(), "fields": input.fields.duplicate(), "basis": _deployment_basis(definition, state)}
			if not _report_valid(definition, state, report): return _error("RELEASE_REPORT_INVALID", "Report evidence and disclosed fields must be observed and authorized for this recipient.", previous)
			state.report = report
			state.followup.clear()
			feedback = {"recipient_id": report.recipient_id, "reply_key": definition.recipients[report.recipient_id].reply_key}
		"followup":
			if not _services_current(definition, state) or not _report_valid(definition, state, state.report): return _error("RELEASE_NOT_READY", "The current report must be valid before answering its follow-up.", previous)
			var followup: Dictionary = {"followup_id": input.followup_id, "evidence_ids": input.evidence_ids.duplicate(), "basis": _deployment_basis(definition, state)}
			if not _followup_valid(definition, state, followup): return _error("RELEASE_FOLLOWUP_INVALID", "This follow-up needs its own observed evidence and current deployment.", previous)
			state.followup = followup
			feedback = {"followup_id": followup.followup_id, "result_key": definition.followups[followup.followup_id].result_key}
	return _ok(definition, state, context, feedback)


static func goal_met(definition: Dictionary, state: Dictionary, _context: Dictionary = {}) -> bool:
	return _services_current(definition, state) and _report_valid(definition, state, state.get("report", {})) and _followup_valid(definition, state, state.get("followup", {}))


static func _artifact(definition: Dictionary, state: Dictionary, id: String) -> Dictionary:
	if definition.get("artifacts", {}).has(id): return definition.artifacts[id]
	if state.get("built", []).has(id) and definition.get("builds", {}).has(id): return definition.builds[id]
	return {}


static func _artifact_ids(definition: Dictionary, state: Dictionary) -> Array:
	return definition.get("artifacts", {}).keys() + state.get("built", [])


static func _inspected(definition: Dictionary, state: Dictionary, id: String) -> bool:
	var artifact: Dictionary = _artifact(definition, state, id)
	return not artifact.is_empty() and state.get("inspected", {}).get(id, "") == str(artifact.payload).sha256_text()


static func _verification_basis(definition: Dictionary, state: Dictionary, record: Dictionary) -> String:
	var id: String = str(record.get("artifact_id", ""))
	var artifact: Dictionary = _artifact(definition, state, id)
	return JSON.stringify([id, artifact.get("payload", ""), artifact.get("source_revision", ""), artifact.get("builder_id", ""), definition.get("statements", {}).get(record.get("statement_id", ""), {}), definition.get("registries", {}).get(record.get("registry_id", ""), {})]).sha256_text()


static func _valid_verification(definition: Dictionary, state: Dictionary, record: Dictionary) -> bool:
	var artifact: Dictionary = _artifact(definition, state, str(record.get("artifact_id", "")))
	var statement: Dictionary = definition.get("statements", {}).get(record.get("statement_id", ""), {})
	var registry: Dictionary = definition.get("registries", {}).get(record.get("registry_id", ""), {})
	if artifact.is_empty() or statement.is_empty() or registry.is_empty(): return false
	return statement.get("registry_id", "") == record.get("registry_id", "") and registry.get("trusted_statements", []).has(record.get("statement_id", "")) and registry.get("trusted_builders", []).has(artifact.builder_id) and not registry.get("revoked_builders", []).has(artifact.builder_id) and statement.get("builder_id", "") == artifact.builder_id and statement.get("source_revision", "") == artifact.source_revision and statement.get("subject_digest", "") == str(artifact.payload).sha256_text()


static func _verified(definition: Dictionary, state: Dictionary, id: String) -> bool:
	var record: Dictionary = state.get("verified", {}).get(id, {})
	return _inspected(definition, state, id) and not record.is_empty() and record.get("valid", false) == true and record.get("basis", "") == _verification_basis(definition, state, record) and _valid_verification(definition, state, record)


static func _deployment_basis(definition: Dictionary, state: Dictionary) -> String:
	var id: String = str(state.get("deployed", ""))
	return JSON.stringify([id, _verification_basis(definition, state, state.get("verified", {}).get(id, {})), definition.get("service_cases", {})]).sha256_text()


static func _service_outcome(definition: Dictionary, state: Dictionary, id: String) -> Dictionary:
	var artifact: Dictionary = _artifact(definition, state, str(state.get("deployed", "")))
	var manifest: Variant = JSON.parse_string(str(artifact.get("payload", "")))
	var scenario: Dictionary = definition.service_cases[id]
	var status := 503
	if manifest is Dictionary and manifest.get("enabled", false) == true:
		var allowed: Array = manifest.get("operations", {}).get(scenario.operation, [])
		status = 200 if allowed.has(scenario.target) else 403
	return {"status": status, "business": status == 200}


static func _services_current(definition: Dictionary, state: Dictionary) -> bool:
	var id: String = str(state.get("deployed", ""))
	if not _verified(definition, state, id) or definition.get("required_service_cases", []).is_empty(): return false
	var basis: String = _deployment_basis(definition, state)
	for case_id in definition.required_service_cases:
		var scenario: Dictionary = definition.service_cases[case_id]
		var receipt: Dictionary = state.get("probe_receipts", {}).get(case_id, {})
		var current: Dictionary = _service_outcome(definition, state, case_id)
		if receipt.get("basis", "") != basis or receipt.get("status", -1) != current.status or receipt.get("business") != current.business: return false
		if current.status != scenario.expected_status or current.business != scenario.expected_business: return false
	return true


static func _evidence_available(definition: Dictionary, state: Dictionary, id: String) -> bool:
	var evidence: Dictionary = definition.get("report_evidence", {}).get(id, {})
	return not evidence.is_empty() and _inspected(definition, state, str(evidence.get("artifact_id", "")))


static func _field_lookup(definition: Dictionary, id: String) -> Dictionary:
	for evidence_id in definition.get("report_evidence", {}):
		var fields: Dictionary = definition.report_evidence[evidence_id].fields
		if fields.has(id): return {"evidence_id": evidence_id, "field": fields[id]}
	return {}


static func _report_valid(definition: Dictionary, state: Dictionary, report: Dictionary) -> bool:
	var recipient: Dictionary = definition.get("recipients", {}).get(report.get("recipient_id", ""), {})
	if recipient.is_empty() or report.get("basis", "") != _deployment_basis(definition, state) or not _unique_strings(report.get("evidence_ids"), 32) or not _unique_strings(report.get("fields"), 64) or report.fields.is_empty(): return false
	for evidence_id in report.evidence_ids:
		if not _evidence_available(definition, state, evidence_id): return false
	for field_id in report.fields:
		var found: Dictionary = _field_lookup(definition, field_id)
		if found.is_empty() or not report.evidence_ids.has(found.evidence_id) or not recipient.allowed_fields.has(field_id): return false
	for required in recipient.required_evidence:
		if not report.evidence_ids.has(required): return false
		var represented := false
		for field_id in report.fields:
			if definition.report_evidence[required].fields.has(field_id): represented = true
		if not represented: return false
	for required in recipient.get("required_fields", []):
		if not report.fields.has(required): return false
	return true


static func _followup_valid(definition: Dictionary, state: Dictionary, followup: Dictionary) -> bool:
	var report: Dictionary = state.get("report", {})
	var recipient: Dictionary = definition.get("recipients", {}).get(report.get("recipient_id", ""), {})
	if recipient.is_empty() or not _report_valid(definition, state, report) or followup.get("basis", "") != _deployment_basis(definition, state) or followup.get("followup_id", "") != recipient.followup_id or not _unique_strings(followup.get("evidence_ids"), 32): return false
	var requirement: Dictionary = definition.followups.get(recipient.followup_id, {})
	for id in recipient.required_evidence:
		if not followup.evidence_ids.has(id): return false
	for id in followup.evidence_ids:
		if not _evidence_available(definition, state, id): return false
	var digests: Array = []
	for id in requirement.get("required_artifacts", []):
		if not _inspected(definition, state, id): return false
		var cited := false
		for evidence_id in followup.evidence_ids:
			if definition.report_evidence[evidence_id].artifact_id == id: cited = true
		if not cited: return false
		var digest: String = str(_artifact(definition, state, id).payload).sha256_text()
		if not digests.has(digest): digests.append(digest)
	match str(requirement.get("predicate", "")):
		"digest_mismatch": return digests.size() >= 2
		"current_release": return _services_current(definition, state)
	return false


static func public_data(definition: Dictionary, previous: Dictionary, context: Dictionary = {}) -> Dictionary:
	var state: Dictionary = initial_state(definition, previous)
	var artifacts: Array = []
	for id in _artifact_ids(definition, state):
		var artifact: Dictionary = _artifact(definition, state, id)
		var row := {"id": id, "label": _tr(artifact.get("label", id)), "filename": artifact.get("filename", id), "inspected": _inspected(definition, state, id), "verified": _verified(definition, state, id)}
		if row.inspected:
			row.merge({"digest": str(artifact.payload).sha256_text(), "source_revision": artifact.source_revision, "builder_id": artifact.builder_id, "manifest": JSON.parse_string(artifact.payload)})
		artifacts.append(row)
	var evidence_rows: Array = []
	for id in definition.get("report_evidence", {}):
		var evidence: Dictionary = definition.report_evidence[id]
		var fields: Array = []
		for field_id in evidence.fields:
			var field: Dictionary = evidence.fields[field_id]
			var row := {"id": field_id, "sensitivity": field.sensitivity}
			if field.sensitivity == "public" and _evidence_available(definition, state, id): row["value"] = _field_value(definition, state, id, field_id)
			fields.append(row)
		evidence_rows.append({"id": id, "label": _tr(evidence.get("label", id)), "artifact_id": evidence.artifact_id, "available": _evidence_available(definition, state, id), "fields": fields})
	var statements: Array = []
	for id in definition.get("statements", {}):
		var row := {"id": id, "inspected": state.inspected_provenance.has(id)}
		if row.inspected: row.merge(definition.statements[id].duplicate(true))
		statements.append(row)
	var services: Array = []
	for id in definition.get("service_cases", {}):
		services.append({"id": id, "label": _tr(definition.service_cases[id].label), "observed": state.probe_receipts.get(id, {}).duplicate(true)})
	var recipients: Array = []
	for id in definition.get("recipients", {}):
		var recipient: Dictionary = definition.recipients[id]
		recipients.append({"id": id, "label": _tr(recipient.label), "allowed_fields": recipient.allowed_fields.duplicate(), "required_evidence": recipient.required_evidence.duplicate(), "followup_id": recipient.followup_id})
	var builds: Array = []
	for id in definition.get("builds", {}): builds.append({"id": id, "label": _tr(definition.builds[id].get("label", id)), "artifact_id": id, "available": true})
	return {"artifacts": artifacts, "provenance": statements, "registries": definition.get("registries", {}).duplicate(true), "builds": builds, "services": services, "evidence": evidence_rows, "recipients": recipients, "deployment": {"artifact_id": state.deployed, "current": _services_current(definition, state)}, "report": _report_projection(definition, state), "replies": _reply_projection(definition, state), "article": project_page(definition, state, "article", context)}


static func _field_value(definition: Dictionary, state: Dictionary, evidence_id: String, field_id: String) -> String:
	var evidence: Dictionary = definition.report_evidence[evidence_id]
	var field: Dictionary = evidence.fields[field_id]
	if field.has("text"): return _tr(field.text)
	var artifact: Dictionary = _artifact(definition, state, evidence.artifact_id)
	if field.source == "digest": return str(artifact.payload).sha256_text()
	return str(artifact.get(field.source, evidence.artifact_id if field.source == "filename" else ""))


static func _report_projection(definition: Dictionary, state: Dictionary) -> Dictionary:
	var report: Dictionary = state.get("report", {})
	if not _report_valid(definition, state, report): return {}
	var fields: Array = []
	for id in report.fields:
		var found: Dictionary = _field_lookup(definition, id)
		if found.field.sensitivity == "public": fields.append({"id": id, "evidence_id": found.evidence_id, "value": _field_value(definition, state, found.evidence_id, id)})
	return {"recipient_id": report.recipient_id, "evidence_ids": report.evidence_ids.duplicate(), "fields": fields}


static func _reply_projection(definition: Dictionary, state: Dictionary) -> Dictionary:
	var report: Dictionary = state.get("report", {})
	if not _report_valid(definition, state, report): return {}
	var recipient: Dictionary = definition.recipients[report.recipient_id]
	var result := {"recipient_id": report.recipient_id, "text": _tr(recipient.reply_key), "followup_id": recipient.followup_id, "answered": _followup_valid(definition, state, state.get("followup", {}))}
	if result.answered: result["result"] = _tr(definition.followups[recipient.followup_id].result_key)
	return result


static func project_page(definition: Dictionary, previous: Dictionary, view: String, _context: Dictionary = {}) -> Dictionary:
	if not view in ["article", "reply"]: return {}
	var state: Dictionary = initial_state(definition, previous)
	var report: Dictionary = state.get("report", {})
	if not _report_valid(definition, state, report): return {}
	var recipient: Dictionary = definition.recipients[report.recipient_id]
	if view == "article" and recipient.get("public", false) != true: return {}
	var reply: Dictionary = _reply_projection(definition, state)
	var fields: Array = _report_projection(definition, state).get("fields", [])
	var lines: Array[String] = [str(reply.get("result", reply.get("text", "")))]
	for row in fields:
		var found: Dictionary = _field_lookup(definition, row.id)
		lines.append(_tr(found.field.get("label", row.id)) + ": " + str(row.value))
	return {"recipient_id": report.recipient_id, "title": _tr(recipient.label), "body": "\n\n".join(lines), "fields": fields, "links": [], "pending": not reply.get("answered", false)}


static func _valid_input(input: Variant) -> bool:
	if not input is Dictionary or not input.get("action") is String or not ACTION_FIELDS.has(input.action): return false
	for key in input:
		if not key is String or not ACTION_FIELDS[input.action].has(key): return false
	for key in ACTION_FIELDS[input.action]:
		if key == "action" or (input.action == "inspect" and key == "section"): continue
		if not input.has(key): return false
		if key in ["evidence_ids", "fields"]:
			if not _unique_strings(input[key], 64 if key == "fields" else 32): return false
		elif not input[key] is String or input[key].is_empty() or input[key].length() > 128: return false
	return not input.has("section") or (input.section is String and SECTIONS.has(input.section))


static func _unique_strings(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	var seen: Array = []
	for item in value:
		if not item is String or item.is_empty() or item.length() > 128 or seen.has(item): return false
		seen.append(item)
	return true


static func _tr(key: Variant) -> String:
	return str(TranslationServer.translate(str(key)))


static func _ok(definition: Dictionary, state: Dictionary, context: Dictionary, feedback: Dictionary) -> Dictionary:
	return {"ok": true, "code": "RELEASE_OBSERVED", "text": "Virtual release state updated from the selected operation.", "state": state, "solved": goal_met(definition, state, context), "status": feedback.get("status", 200), "feedback": feedback, "effects": {}}


static func _error(code: String, text: String, previous: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "state": previous.duplicate(true), "solved": false, "status": 400, "feedback": {}, "effects": {}}
