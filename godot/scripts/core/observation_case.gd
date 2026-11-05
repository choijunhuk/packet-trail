extends RefCounted


static func apply_action(definition: Dictionary, input: Variant, previous: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not input is Dictionary:
		return _error("INVALID_ARGUMENTS", "Select a collection or hypothesis action.", previous)
	for key in ["hypothesis_id", "sensor_id", "next_sensor_id"]:
		if input.has(key) and not input[key] is String:
			return _error("INVALID_ARGUMENTS", "Observation identifiers must be text.", previous)
	var action_value: Variant = input.get("action", "inspect")
	if not action_value is String:
		return _error("INVALID_ARGUMENTS", "Action must be a registered identifier.", previous)
	if input.has("filter") and not input.filter is Dictionary:
		return _error("INVALID_ARGUMENTS", "Observation filter must be structured fields.", previous)
	for key in ["observation_ids", "reason_observation_ids", "supported_hypothesis_ids", "refuted_hypothesis_ids", "unknown_edges", "claims"]:
		if input.has(key) and not input[key] is Array:
			return _error("INVALID_ARGUMENTS", "Observation references must be lists.", previous)
	for proposed in input.get("claims", []):
		if not proposed is Dictionary or not proposed.get("claim", proposed) is Dictionary or not proposed.get("observation_ids", []) is Array:
			return _error("INVALID_CLAIM", "Each submitted connection must cite its observations.", previous)
	var state: Dictionary = previous.duplicate(true)
	for key in ["sensor_cursors", "observations", "hypotheses"]:
		state[key] = state.get(key, {})
	state["hypothesis_history"] = state.get("hypothesis_history", [])
	state["handoff"] = state.get("handoff", {})
	var action: String = str(input.get("action", "inspect"))
	var feedback: Dictionary = {}
	var collected: Array = []
	if action == "inspect":
		return _ok(definition, state, "Observation sources inspected.")
	if action in ["collect", "advance_watch"]:
		var sensor_id: String = str(input.get("sensor_id", ""))
		if not definition.sensors.has(sensor_id):
			return _error("UNKNOWN_SENSOR", "Unknown observation point.", previous)
		if not context.get("authorized_sensors", definition.sensors.keys()).has(sensor_id):
			return _error("AUTH_REQUIRED", "This observation point is outside the current authority.", previous)
		var sensor: Dictionary = definition.sensors[sensor_id]
		var cursor: int = int(state.sensor_cursors.get(sensor_id, 0))
		var windows: Array = sensor.get("windows", [])
		if action == "advance_watch":
			if cursor + 1 >= windows.size():
				return _error("WINDOW_END", "There is no later observation window at this point.", previous)
			state.sensor_cursors[sensor_id] = cursor + 1
			return _ok(definition, state, "Observation point advanced to its next window.")
		if cursor >= windows.size():
			return _error("WINDOW_END", "No observation window is available.", previous)
		var filter: Dictionary = input.get("filter", {})
		for row in windows[cursor].get("rows", []):
			if not filter.is_empty() and str(row.get("public", {}).get(filter.get("field", ""), "")) != str(filter.get("value", "")):
				continue
			var id: String = sensor_id + ":" + str(cursor) + ":" + str(row.event_id)
			if state.observations.has(id):
				collected.append(state.observations[id].duplicate(true))
				continue
			if state.observations.size() >= 128:
				return _error("OBSERVATION_LIMIT", "Observation archive limit reached.", previous)
			var canonical: Dictionary = {"event_id": row.event_id, "observed_at": row.observed_at, "clock_offset": row.clock_offset, "public": _visible_fields(sensor, row.get("public", {})), "provenance": row.provenance.duplicate(true)}
			var interval: Array = [row.observed_at[0] - row.clock_offset[1], row.observed_at[1] - row.clock_offset[0]]
			var copy: Dictionary = {"id": id, "event_id": row.event_id, "sensor_id": sensor_id, "window_index": cursor, "public": canonical.public, "provenance": canonical.provenance, "normalized_interval": interval, "canonical": canonical, "sha256": JSON.stringify(canonical, "", true, true).sha256_text()}
			state.observations[id] = copy
			collected.append(copy.duplicate(true))
		var result: Dictionary = _ok(definition, state, "Collected " + str(collected.size()) + " observations.")
		for row in collected:
			row.erase("canonical")
		result["observations"] = collected
		return result
	if action in ["hypothesize", "revise"]:
		var id: String = str(input.get("hypothesis_id", ""))
		var claim: Variant = input.get("replacement_claim" if action == "revise" else "claim", {})
		var citations: Variant = input.get("reason_observation_ids" if action == "revise" else "observation_ids", [])
		if id.is_empty() or id.length() > 64 or not _valid_claim(definition, claim, citations, state):
			return _error("INVALID_CLAIM", "A claim must cite collected observations and public entity references.", previous)
		if action == "revise" and not state.hypotheses.has(id):
			return _error("INVALID_CLAIM", "The hypothesis to revise does not exist.", previous)
		if action == "hypothesize" and (state.hypotheses.has(id) or state.hypotheses.size() >= 32):
			return _error("INVALID_CLAIM", "Use revision to correct an existing hypothesis.", previous)
		if state.hypothesis_history.size() >= 128:
			return _error("OBSERVATION_LIMIT", "Hypothesis history limit reached.", previous)
		var assessed: Dictionary = assess(claim, citations, state)
		state.hypothesis_history.append({"hypothesis_id": id, "previous": state.hypotheses.get(id, {}).duplicate(true), "claim": claim.duplicate(true), "observation_ids": citations.duplicate(), "verdict": assessed.verdict})
		state.hypotheses[id] = {"claim": claim.duplicate(true), "observation_ids": citations.duplicate()}
		feedback = assessed
		feedback["hypothesis_id"] = id
	elif action == "test":
		var id: String = str(input.get("hypothesis_id", ""))
		if not state.hypotheses.has(id):
			return _error("INVALID_CLAIM", "Unknown hypothesis.", previous)
		feedback = assess(state.hypotheses[id].claim, state.hypotheses[id].observation_ids, state)
		feedback["hypothesis_id"] = id
	elif action == "handoff":
		var submission: Dictionary = input.duplicate(true)
		if not _handoff_valid(definition, state, submission):
			return _error("HANDOFF_INCOMPLETE", "The handoff lacks a supported connection, required counterevidence or a valid next observation point.", previous)
		state.handoff = submission
		feedback = {"verdict": "supported", "next_sensor_id": submission.get("next_sensor_id", "")}
	else:
		return _error("INVALID_ARGUMENTS", "Unknown observation action.", previous)
	return _ok(definition, state, "Claim evaluated from collected public observations.", feedback)


static func assess(claim: Dictionary, citations: Array, state: Dictionary) -> Dictionary:
	var cited: Array = []
	for id in citations:
		if state.get("observations", {}).has(id):
			cited.append(state.observations[id])
	var supported: Array = []
	var refuted: Array = []
	var all_rows: Array = state.get("observations", {}).values()
	for left in all_rows:
		for right in all_rows:
			var verdict: String = _relation(claim, left, right)
			if verdict == "refuted":
				for row in [left, right]:
					if not refuted.has(row.id):
						refuted.append(row.id)
	for left in cited:
		for right in cited:
			if _relation(claim, left, right) == "supported":
				for row in [left, right]:
					if not supported.has(row.id):
						supported.append(row.id)
	var verdict := "refuted" if not refuted.is_empty() else "supported" if not supported.is_empty() else "underdetermined"
	return {"verdict": verdict, "supporting_ids": supported, "refuting_ids": refuted, "reason": "public_observations_only"}


static func _relation(claim: Dictionary, left: Dictionary, right: Dictionary) -> String:
	var a: Dictionary = left.get("public", {})
	var b: Dictionary = right.get("public", {})
	var kind: String = str(claim.get("kind", ""))
	if kind == "same_session":
		var a_tag: String = str(a.get("session_tag", ""))
		var b_tag: String = str(b.get("session_tag", ""))
		if not ["session:" + a_tag, "session:" + b_tag].has(claim.left) or not ["session:" + a_tag, "session:" + b_tag].has(claim.right) or a_tag.is_empty() or b_tag.is_empty():
			return "underdetermined"
		if left.provenance.get("marker_authority", "") != "server_issued" or right.provenance.get("marker_authority", "") != "server_issued":
			return "underdetermined"
		if claim.left != claim.right and a_tag != b_tag:
			return "refuted"
		if left.id != right.id and claim.left == claim.right and a_tag == b_tag and _overlap(left.normalized_interval, right.normalized_interval):
			return "supported"
	elif kind == "before" and claim.left == "event:" + str(left.event_id) and claim.right == "event:" + str(right.event_id):
		if left.normalized_interval[1] < right.normalized_interval[0]:
			return "supported"
		if left.normalized_interval[0] > right.normalized_interval[1]:
			return "refuted"
	elif kind == "forwarded_to":
		var request: String = str(claim.left).trim_prefix("request:")
		var node: String = str(claim.right).trim_prefix("node:")
		if left.provenance.get("marker_authority", "") == "server_issued" and a.get("request_tag", "") == request and a.get("to_node", "") == node:
			if not str(a.get("from_node", "")).is_empty():
				return "supported"
	return "underdetermined"


static func _overlap(left: Array, right: Array) -> bool:
	return left[0] <= right[1] and right[0] <= left[1]


static func _entities(state: Dictionary) -> Array:
	var ids: Array = []
	for row in state.get("observations", {}).values():
		for value in ["event:" + str(row.event_id), "session:" + str(row.public.get("session_tag", "")), "request:" + str(row.public.get("request_tag", "")), "node:" + str(row.public.get("from_node", "")), "node:" + str(row.public.get("to_node", ""))]:
			if not value.ends_with(":") and not ids.has(value):
				ids.append(value)
	return ids


static func _valid_claim(definition: Dictionary, claim: Variant, citations: Variant, state: Dictionary) -> bool:
	if not claim is Dictionary or not claim.has_all(["kind", "left", "right"]) or not definition.get("claim_types", []).has(claim.kind) or not citations is Array or citations.is_empty():
		return false
	var entities: Array = _entities(state)
	if not entities.has(claim.left) or not entities.has(claim.right):
		return false
	for id in citations:
		if not state.observations.has(id):
			return false
	return true


static func _handoff_valid(definition: Dictionary, state: Dictionary, submission: Dictionary) -> bool:
	var required: Dictionary = definition.get("handoff_requirements", {})
	if not definition.sensors.has(submission.get("next_sensor_id", "")) or not required.get("next_vantage", []).has(submission.get("next_sensor_id", "")):
		return false
	var claims: Array = submission.get("claims", []).duplicate(true)
	for id in submission.get("supported_hypothesis_ids", []):
		if not state.get("hypotheses", {}).has(id):
			return false
		claims.append(state.hypotheses[id])
	for requirement in required.get("supported", []):
		var found := false
		for proposed in claims:
			var claim: Dictionary = proposed.get("claim", proposed)
			var citations: Array = proposed.get("observation_ids", [])
			if not _valid_claim(definition, claim, citations, state) or assess(claim, citations, state).verdict != "supported":
				continue
			if claim.kind == requirement.get("kind", "") and (not requirement.has("left") or claim.left == requirement.left) and (not requirement.has("right") or claim.right == requirement.right) and (not requirement.has("request_tag") or claim.left == "request:" + str(requirement.request_tag)) and (not requirement.has("target_node") or claim.right == "node:" + str(requirement.target_node)):
				found = true
		if not found:
			return false
	for required_claim in required.get("refuted", []):
		if not definition.get("initial_claims", {}).has(required_claim):
			return false
		var authored: Dictionary = definition.initial_claims[required_claim].claim
		if assess(authored, state.observations.keys(), state).verdict != "refuted":
			return false
	return not required.get("supported", []).is_empty()


static func goal_met(definition: Dictionary, state: Dictionary) -> bool:
	return not state.get("handoff", {}).is_empty() and _handoff_valid(definition, state, state.handoff)


static func public_data(definition: Dictionary, state: Dictionary, authorized: Array = []) -> Dictionary:
	var sensors: Array = []
	for id in definition.sensors:
		var sensor: Dictionary = definition.sensors[id]
		var cursor: int = int(state.get("sensor_cursors", {}).get(id, 0))
		sensors.append({"id": id, "label": str(TranslationServer.translate(sensor.label)), "available": authorized.has(id), "visibility": sensor.get("visibility", "metadata"), "window_index": cursor, "can_advance": cursor + 1 < sensor.get("windows", []).size(), "coverage": {"sampling": sensor.get("coverage", {}).get("sampling", "sampled"), "window": sensor.get("coverage", {}).get("window", [])}})
	var observations: Array = []
	for original in state.get("observations", {}).values():
		var row: Dictionary = original.duplicate(true)
		row.erase("canonical")
		observations.append(row)
	var hypotheses: Array = []
	for id in state.get("hypotheses", {}):
		var item: Dictionary = state.hypotheses[id].duplicate(true)
		item["id"] = id
		item.merge(assess(item.claim, item.observation_ids, state))
		hypotheses.append(item)
	return {"sensors": sensors, "observations": observations, "hypotheses": hypotheses, "hypothesis_history": state.get("hypothesis_history", []), "entities": _entities(state), "handoff": state.get("handoff", {})}


static func _visible_fields(sensor: Dictionary, fields: Dictionary) -> Dictionary:
	var visible: Dictionary = {}
	var allowed: Array = ["session_tag", "request_tag", "from_node", "to_node", "shared_address", "record_digest", "account_handle", "size_bucket", "claimed_account", "encrypted", "application_event", "event"]
	if sensor.get("visibility", "metadata") != "metadata": allowed.append_array(["authorized_excerpt", "plaintext", "payload"])
	for key in allowed:
		if fields.has(key): visible[key] = fields[key]
	return visible


static func _ok(definition: Dictionary, state: Dictionary, text: String, feedback: Dictionary = {}) -> Dictionary:
	return {"ok": true, "code": "OBSERVATION_RECORDED", "text": text, "state": state, "solved": goal_met(definition, state), "status": 200, "feedback": feedback, "effects": {}}


static func _error(code: String, text: String, previous: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "state": previous.duplicate(true), "solved": false, "status": 400, "feedback": {}, "effects": {}}
