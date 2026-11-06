extends RefCounted
## Authoring boundary for a finite fictional provenance/disclosure exercise.

const Model = preload("res://scripts/core/release_case.gd")
const SOURCES := ["digest", "source_revision", "builder_id", "filename"]


static func validate(definition: Dictionary, mission: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["artifacts", "statements", "registries", "builds", "service_cases", "report_evidence", "recipients", "followups"]:
		if not definition.get(key) is Dictionary or definition[key].size() > {"artifacts": 12, "statements": 24, "registries": 8, "builds": 12, "service_cases": 32, "report_evidence": 32, "recipients": 8, "followups": 8}[key]:
			errors.append("Invalid release registry: " + key)
	if not errors.is_empty(): return errors
	if definition.artifacts.is_empty() or definition.statements.is_empty() or definition.registries.is_empty() or definition.service_cases.is_empty() or definition.report_evidence.is_empty() or definition.recipients.is_empty() or definition.followups.is_empty() or definition.artifacts.size() + definition.builds.size() > 12:
		errors.append("Release registries must describe a bounded playable case.")
	if not mission.get("hosts", {}).has(definition.get("host_id", "")):
		errors.append("Unknown release host.")
	var session: Variant = definition.get("requires_session")
	if not session is Dictionary or session.get("host_id", "") != definition.get("host_id", "") or not mission.get("hosts", {}).get(definition.get("host_id", ""), {}).get("accounts", {}).has(session.get("account_id", "")):
		errors.append("Release operations require one registered operator session.")
	var all_artifacts: Dictionary = definition.artifacts.duplicate(true)
	for id in definition.builds:
		if all_artifacts.has(id): errors.append("Virtual build output collides with an artifact.")
		all_artifacts[id] = definition.builds[id]
	for id in all_artifacts:
		var artifact: Variant = all_artifacts[id]
		if not _id(id) or not artifact is Dictionary or not _text(artifact.get("label")) or not _text(artifact.get("filename", id)) or not _text(artifact.get("source_revision"), 128) or not _text(artifact.get("builder_id"), 128) or not _manifest(artifact.get("payload")):
			errors.append("Invalid registered virtual artifact: " + str(id))
	for id in definition.statements:
		var statement: Variant = definition.statements[id]
		if not _id(id) or not statement is Dictionary:
			errors.append("Invalid provenance statement.")
			continue
		if not _digest(statement.get("subject_digest")) or not _text(statement.get("source_revision"), 128) or not _text(statement.get("builder_id"), 128) or not definition.registries.has(statement.get("registry_id", "")):
			errors.append("Invalid fixed provenance binding.")
	for id in definition.registries:
		var registry: Variant = definition.registries[id]
		if not _id(id) or not registry is Dictionary or not _strings(registry.get("trusted_builders"), 16) or not _strings(registry.get("revoked_builders"), 16) or not _refs(registry.get("trusted_statements"), definition.statements, 24):
			errors.append("Invalid fixed provenance trust registry.")
	for id in definition.builds:
		var build: Variant = definition.builds[id]
		if not build is Dictionary or not definition.statements.has(build.get("statement_id", "")) or not definition.registries.has(build.get("registry_id", "")):
			errors.append("Virtual builds need registered provenance references.")
		elif errors.is_empty() and not Model._valid_verification(definition, {"built": [id]}, {"artifact_id": id, "statement_id": build.statement_id, "registry_id": build.registry_id}):
			errors.append("Approved virtual builds need matching trusted provenance.")
	for id in definition.service_cases:
		var scenario: Variant = definition.service_cases[id]
		if not _id(id) or not scenario is Dictionary or not _text(scenario.get("label")) or not _id(scenario.get("operation")) or not _text(scenario.get("target"), 128) or not _integer(scenario.get("expected_status"), 100, 599) or not int(scenario.get("expected_status")) in [200, 403, 503] or not scenario.get("expected_business") is bool or scenario.get("expected_business") != (scenario.get("expected_status") == 200):
			errors.append("Invalid registered service request.")
	if not _refs(definition.get("required_service_cases"), definition.service_cases, 32) or definition.get("required_service_cases", []).is_empty():
		errors.append("Release goals need registered service checks.")
	var field_ids: Dictionary = {}
	var public_fields: Dictionary = {}
	for id in definition.report_evidence:
		var evidence: Variant = definition.report_evidence[id]
		if not _id(id) or not evidence is Dictionary or not _text(evidence.get("label")) or not all_artifacts.has(evidence.get("artifact_id", "")) or not evidence.get("fields") is Dictionary or evidence.get("fields", {}).is_empty() or evidence.get("fields", {}).size() > 16:
			errors.append("Invalid artifact-bound report evidence.")
			continue
		for field_id in evidence.fields:
			var field: Variant = evidence.fields[field_id]
			if not _id(field_id) or field_ids.has(field_id) or not field is Dictionary or not field.get("sensitivity", "") in ["public", "restricted"]:
				errors.append("Report field IDs must be unique and classified.")
				continue
			if field.has("source") == field.has("text") or (field.has("source") and not SOURCES.has(field.source)) or (field.has("text") and not _text(field.text)):
				errors.append("Report fields need exactly one authoritative source or authored text.")
			field_ids[field_id] = id
			if field.get("sensitivity", "") == "public": public_fields[field_id] = id
	if field_ids.size() > 64: errors.append("Too many report fields.")
	for id in definition.followups:
		var followup: Variant = definition.followups[id]
		if not _id(id) or not followup is Dictionary or not followup.get("predicate", "") in ["digest_mismatch", "current_release"] or not _refs(followup.get("required_artifacts"), all_artifacts, 12) or followup.get("required_artifacts", []).is_empty() or not _text(followup.get("result_key")):
			errors.append("Invalid evidence-bound follow-up.")
		elif followup.predicate == "digest_mismatch" and followup.required_artifacts.size() < 2:
			errors.append("Digest mismatch requires two observed artifacts.")
	for id in definition.recipients:
		var recipient: Variant = definition.recipients[id]
		if not _id(id) or not recipient is Dictionary or not _text(recipient.get("label")) or not _refs(recipient.get("allowed_fields"), field_ids, 64) or recipient.get("allowed_fields", []).is_empty() or not _refs(recipient.get("required_evidence"), definition.report_evidence, 32) or recipient.get("required_evidence", []).is_empty() or not _refs(recipient.get("required_fields", []), field_ids, 64) or not definition.followups.has(recipient.get("followup_id", "")) or not _text(recipient.get("reply_key")) or not recipient.get("public", false) is bool:
			errors.append("Invalid report recipient.")
			continue
		for field_id in recipient.get("required_fields", []):
			if not recipient.allowed_fields.has(field_id): errors.append("Recipient requires an unauthorized field.")
		for evidence_id in recipient.required_evidence:
			var covered := false
			for field_id in recipient.allowed_fields:
				if field_ids.get(field_id, "") == evidence_id: covered = true
			if not covered: errors.append("Recipient cannot receive a required evidence field.")
		if recipient.get("public", false):
			for field_id in recipient.allowed_fields:
				if not public_fields.has(field_id): errors.append("Public recipients cannot receive restricted fields.")
	return errors


static func _manifest(value: Variant) -> bool:
	if not value is String or value.length() > 4096 or value.to_utf8_buffer().size() > 8192: return false
	var manifest: Variant = JSON.parse_string(value)
	if not manifest is Dictionary or not manifest.get("enabled") is bool or not manifest.get("operations") is Dictionary or manifest.operations.size() > 16: return false
	for key in manifest:
		if not key in ["enabled", "operations", "release_note"]: return false
	if manifest.has("release_note") and not _text(manifest.release_note, 256): return false
	for operation in manifest.operations:
		if not _id(operation) or not _strings(manifest.operations[operation], 32): return false
	return true


static func _digest(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true


static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128 and value.is_valid_identifier()


static func _text(value: Variant, maximum: int = 4096) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= maximum


static func _strings(value: Variant, maximum: int) -> bool:
	return Model._unique_strings(value, maximum)


static func _refs(value: Variant, registry: Dictionary, maximum: int) -> bool:
	if not _strings(value, maximum): return false
	for id in value:
		if not registry.has(id): return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum
