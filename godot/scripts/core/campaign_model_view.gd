extends RefCounted
## Finite presentation projections for registered stateful models.

const Models = preload("res://scripts/core/tool_runtime.gd")


static func project(definition: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	var actions: Array = [{"id": "inspect", "fields": []}]
	var data: Dictionary = {}
	match definition.kind:
		"response_lab":
			var initialized: Dictionary = Models.ResponseLab.initial_state(definition, state)
			data = Models.ResponseLab.public_data(definition, initialized, context)
			var controls: Array = []
			var values: Array = []
			for id in definition.get("controls", {}):
				var control: Dictionary = definition.controls[id]
				controls.append({"id": id, "label": _tr(control.get("label", id))})
				for value in control.get("values", []):
					if not values.has(value): values.append(value)
			var value_options: Array = []
			for value in values:
				value_options.append({"id": value, "label": ", ".join(PackedStringArray(value)) if value is Array else str(value)})
			var artifact_options: Array = []
			for artifact in data.artifacts: artifact_options.append({"id": artifact.artifact_id, "label": str(artifact.filename) + " / " + str(artifact.stored_as)})
			actions.append({"id": "quarantine", "fields": [_field("artifact_id", "enum", artifact_options), {"id": "quarantined", "type": "bool", "default": true}]})
			var cases: Array = []
			var routes: Array = ["direct"]
			for id in definition.get("cases", {}):
				cases.append({"id": id, "label": _tr(definition.cases[id].label)})
				for route in definition.cases[id].get("routes", {}):
					if not routes.has(route): routes.append(route)
			var checkpoint_options: Array = []
			for checkpoint in data.checkpoints: checkpoint_options.append({"id": checkpoint.id, "label": checkpoint.label})
			var tokens: Array = initialized.tokens.keys()
			for token in context.get("managed_tokens", {}):
				if not tokens.has(token): tokens.append(token)
			actions.append({"id": "set_control", "fields": [_field("control_id", "enum", controls), _field("value", "enum", value_options)]})
			actions.append({"id": "probe", "fields": [_field("case_id", "enum", cases), _field("route_id", "enum", routes)]})
			actions.append({"id": "checkpoint", "fields": [_field("group", "enum", definition.get("checkpoint_groups", {}).keys())]})
			actions.append({"id": "rollback", "fields": [_field("checkpoint_id", "enum", checkpoint_options), _field("group", "enum", definition.get("checkpoint_groups", {}).keys())]})
			actions.append({"id": "revoke", "fields": [_field("token_ref", "enum", tokens)]})
			actions.append({"id": "advance", "fields": [{"id": "ticks", "type": "int", "min": 1, "max": 32}]})
		"observation_case":
			data = Models.ObservationCase.public_data(definition, state, context.get("authorized_sensors", []))
			var sensors: Array = []
			for sensor in data.sensors:
				if sensor.available: sensors.append({"id": sensor.id, "label": sensor.label})
			var claim_fields: Array = [_field("kind", "enum", definition.get("claim_types", [])), _field("left", "enum", data.entities), _field("right", "enum", data.entities)]
			actions.append({"id": "collect", "fields": [_field("sensor_id", "enum", sensors)]})
			actions.append({"id": "advance_watch", "fields": [_field("sensor_id", "enum", sensors)]})
			actions.append({"id": "hypothesize", "fields": [_field("hypothesis_id", "string"), {"id": "claim", "type": "object", "fields": claim_fields}, _field("observation_ids", "array", state.get("observations", {}).keys())]})
			actions.append({"id": "test", "fields": [_field("hypothesis_id", "enum", state.get("hypotheses", {}).keys())]})
			actions.append({"id": "revise", "fields": [_field("hypothesis_id", "enum", state.get("hypotheses", {}).keys()), {"id": "replacement_claim", "type": "object", "fields": claim_fields}, _field("reason_observation_ids", "array", state.get("observations", {}).keys())]})
			actions.append({"id": "handoff", "fields": [_field("supported_hypothesis_ids", "array", state.get("hypotheses", {}).keys()), _field("next_sensor_id", "enum", sensors)]})
			data["initial_claims"] = {}
			for id in definition.get("initial_claims", {}):
				var prior: Dictionary = definition.initial_claims[id]
				data.initial_claims[id] = {"label": _tr(prior.get("label", id)), "claim": prior.get("claim", {}).duplicate(true), "source_id": prior.get("source_id", "")}
		"iam_case":
			var initialized: Dictionary = Models.IAMCase.initial_state(definition, state)
			data = Models.IAMCase.public_data(definition, initialized, context)
			actions[0].fields = [_field("section", "enum", _sections({"bindings": "UI_IAM_BINDINGS", "principals": "UI_IAM_PRINCIPALS", "resources": "UI_IAM_RESOURCES", "roles": "UI_IAM_ROLES", "credentials": "UI_IAM_CREDENTIALS", "requests": "UI_IAM_REQUESTS", "probe_receipts": "UI_MODEL_RECEIPTS"}))]
			var principals: Array = []
			var roles: Array = []
			for id in definition.principals: principals.append({"id": id, "label": _tr(definition.principals[id].get("label", id))})
			for id in definition.roles: roles.append({"id": id, "label": _tr(definition.roles[id].get("label", id))})
			var requests: Array = []
			var routes: Array = ["direct"]
			for id in definition.requests:
				requests.append({"id": id, "label": _tr(definition.requests[id].label)})
				for route in definition.requests[id].get("routes", {}):
					if not routes.has(route): routes.append(route)
			actions.append({"id": "bind", "fields": [_field("principal_id", "enum", principals), _field("role_id", "enum", roles)]})
			actions.append({"id": "revoke", "fields": [_field("credential_ref", "enum", definition.credentials.keys())]})
			actions.append({"id": "probe", "fields": [_field("request_id", "enum", requests), _field("route_id", "enum", routes)]})
			actions.append({"id": "advance", "fields": [{"id": "ticks", "type": "int", "min": 1, "max": 32}]})
			actions.append({"id": "restore_initial", "fields": []})
		"release_case":
			var initialized: Dictionary = Models.ReleaseCase.initial_state(definition, state)
			data = Models.ReleaseCase.public_data(definition, initialized, context)
			actions[0].fields = [_field("section", "enum", _sections({"artifacts": "UI_RELEASE_ARTIFACTS", "provenance": "UI_RELEASE_STATEMENTS", "registries": "UI_RELEASE_REGISTRIES", "builds": "UI_RELEASE_BUILDS", "services": "UI_RELEASE_SERVICES", "evidence": "UI_RELEASE_EVIDENCE", "recipients": "UI_RELEASE_RECIPIENTS", "deployment": "UI_RELEASE_DEPLOYMENT", "report": "UI_RELEASE_REPORT", "replies": "UI_RELEASE_REPLIES", "article": "UI_RELEASE_ARTICLE"}))]
			var artifacts: Array = []
			for id in definition.artifacts: artifacts.append({"id": id, "label": _tr(definition.artifacts[id].label)})
			for id in definition.builds:
				if initialized.get("built", []).has(id): artifacts.append({"id": id, "label": _tr(definition.builds[id].label)})
			actions.append({"id": "inspect_artifact", "fields": [_field("artifact_id", "enum", artifacts)]})
			actions.append({"id": "inspect_provenance", "fields": [_field("statement_id", "enum", definition.statements.keys())]})
			actions.append({"id": "verify", "fields": [_field("artifact_id", "enum", artifacts), _field("statement_id", "enum", definition.statements.keys()), _field("registry_id", "enum", definition.registries.keys())]})
			actions.append({"id": "build", "fields": [_field("build_id", "enum", definition.builds.keys())]})
			actions.append({"id": "deploy", "fields": [_field("artifact_id", "enum", artifacts)]})
			var cases: Array = []
			for id in definition.service_cases: cases.append({"id": id, "label": _tr(definition.service_cases[id].label)})
			actions.append({"id": "probe", "fields": [_field("case_id", "enum", cases)]})
			var evidence: Array = []
			var fields: Array = []
			for id in definition.report_evidence:
				evidence.append({"id": id, "label": _tr(definition.report_evidence[id].label)})
				for field in definition.report_evidence[id].fields:
					fields.append({"id": field, "label": _tr(definition.report_evidence[id].fields[field].get("label", field))})
			var recipients: Array = []
			for id in definition.recipients: recipients.append({"id": id, "label": _tr(definition.recipients[id].label)})
			actions.append({"id": "report", "fields": [_field("recipient_id", "enum", recipients), _field("evidence_ids", "array", evidence), _field("fields", "array", fields)]})
			actions.append({"id": "followup", "fields": [_field("followup_id", "enum", definition.followups.keys()), _field("evidence_ids", "array", evidence)]})
			actions.append({"id": "restore_initial", "fields": []})
		"branch_vm":
			data = Models.BranchVM.public_data(definition, state)
			actions[0].fields = [_field("section", "enum", [{"id": "listing", "label": _tr("UI_VM_LISTING")}, {"id": "call_graph", "label": _tr("UI_VM_CALL_GRAPH")}, {"id": "trace", "label": _tr("UI_VM_TRACE")}])]
			var values: Array = []
			for id in definition.inputs:
				var spec: Dictionary = definition.inputs[id]
				var field: Dictionary = _field(id, str(spec.type), spec.get("choices", []))
				field["label"] = spec.get("label", "")
				if spec.type == "int": field.merge({"min": -1000000, "max": 1000000})
				values.append(field)
			actions.append({"id": "set_input", "fields": [_field("case_id", "string"), {"id": "values", "type": "object", "fields": values}]})
			actions.append({"id": "step", "fields": [_field("case_id", "enum", data.cases), {"id": "count", "type": "int", "min": 1, "max": 32}]})
			actions.append({"id": "run", "fields": [_field("case_id", "enum", data.cases)]})
			actions.append({"id": "reset", "fields": [_field("case_id", "enum", data.cases)]})
	return {"data": data, "actions": actions}


static func _sections(labels: Dictionary) -> Array:
	var result: Array = []
	for id in labels: result.append({"id": id, "label": _tr(labels[id])})
	return result


static func _field(id: String, type: String, options: Array = []) -> Dictionary:
	return {"id": id, "type": type, "options": options}


static func _tr(value: Variant) -> String:
	return str(TranslationServer.translate(str(value)))
