extends RefCounted
## Finite presentation projections for the three supported stateful models.

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


static func _field(id: String, type: String, options: Array = []) -> Dictionary:
	return {"id": id, "type": type, "options": options}


static func _tr(value: Variant) -> String:
	return str(TranslationServer.translate(str(value)))
