extends RefCounted

const INSPECTION_SECTIONS := ["listing", "call_graph", "trace"]
const OPS := ["CONST", "LOAD", "CMP", "BRANCH", "JUMP", "CALL", "RET", "SET_OUTPUT", "HALT"]


static func apply_action(definition: Dictionary, input: Variant, previous: Dictionary, _context: Dictionary = {}) -> Dictionary:
	if not input is Dictionary:
		return _error("INVALID_ARGUMENTS", "Select a VM action and structured input values.", previous)
	if not input.get("action", "inspect") is String or not input.get("case_id", "") is String:
		return _error("VM_INVALID", "VM action and case identifiers must be text.", previous)
	var state: Dictionary = previous.duplicate(true)
	state["cases"] = state.get("cases", {})
	var action: String = str(input.get("action", "inspect"))
	if action == "inspect":
		var section: Variant = input.get("section", "listing")
		if not section is String or not INSPECTION_SECTIONS.has(section):
			return _error("VM_INVALID", "Unknown public inspection section.", previous)
		return _ok(definition, state, "VM inspection", {"section": section, "rows": public_data(definition, state).get(section, [])})
	var id: String = str(input.get("case_id", state.get("active_case", "case_1")))
	if id.is_empty() or id.length() > 64:
		return _error("VM_INVALID", "Invalid case identifier.", previous)
	if action == "set_input":
		var values: Variant = input.get("values", {})
		if not _valid_inputs(definition, values):
			return _error("VM_INVALID", "Program input types or choices do not match.", previous)
		if not state.cases.has(id) and state.cases.size() >= 16:
			return _error("VM_LIMIT", "At most sixteen VM cases can be retained.", previous)
		state.cases[id] = _initial_case(definition, values)
		state["active_case"] = id
		return _ok(definition, state, "Program inputs applied.")
	if action == "reset":
		if not state.cases.has(id):
			return _error("VM_INVALID", "Set inputs before resetting a case.", previous)
		state.cases[id] = _initial_case(definition, state.cases[id].inputs)
		state["active_case"] = id
		return _ok(definition, state, "Program case reset.")
	if not action in ["step", "run"] or not state.cases.has(id):
		return _error("VM_INVALID", "Set inputs before executing a registered VM case.", previous)
	var count: Variant = input.get("count", 1) if action == "step" else definition.get("limits", {}).get("steps", 256)
	if not _integer(count, 1, 32 if action == "step" else 4096):
		return _error("VM_LIMIT", "Step count exceeds the execution limit.", previous)
	var machine: Dictionary = state.cases[id].duplicate(true)
	for _index in range(int(count)):
		if machine.status == "halted":
			break
		var error: String = _step(definition, machine)
		if not error.is_empty():
			return _error("VM_LIMIT" if error.begins_with("Limit") else "VM_INVALID", error, previous)
	if action == "run" and machine.status != "halted":
		return _error("VM_LIMIT", "Program execution budget exhausted before HALT.", previous)
	state.cases[id] = machine
	state["active_case"] = id
	return _ok(definition, state, "Program " + str(machine.status), {"case_id": id, "outputs": machine.outputs.duplicate(true), "steps_used": machine.steps_used})


static func _initial_case(definition: Dictionary, values: Dictionary) -> Dictionary:
	return {"inputs": values.duplicate(true), "function": definition.program.entry, "pc": 0, "registers": {}, "call_stack": [], "outputs": {}, "trace": [], "status": "running", "steps_used": 0}


static func _step(definition: Dictionary, machine: Dictionary) -> String:
	var limits: Dictionary = definition.get("limits", {})
	if machine.steps_used >= int(limits.get("steps", 256)):
		return "Limit: program execution budget exhausted."
	var functions: Dictionary = definition.program.functions
	if not functions.has(machine.function) or machine.pc < 0 or machine.pc >= functions[machine.function].size():
		return "Program counter is outside a declared function."
	var instruction: Dictionary = functions[machine.function][machine.pc]
	var op: String = str(instruction.get("op", ""))
	var old_function: String = machine.function
	var old_pc: int = int(machine.pc)
	machine.pc += 1
	machine.steps_used += 1
	match op:
		"CONST":
			machine.registers[instruction.dst] = instruction.get("value")
		"LOAD":
			if not machine.inputs.has(instruction.get("input", "")):
				return "Program references an unknown input."
			machine.registers[instruction.dst] = machine.inputs[instruction.input]
		"CMP":
			var left: Dictionary = _operand(instruction.get("left"), machine.registers)
			var right: Dictionary = _operand(instruction.get("right"), machine.registers)
			if not left.ok or not right.ok:
				return "Comparison references an unknown register."
			var relation: String = str(instruction.get("relation", "eq"))
			if typeof(left.value) != typeof(right.value):
				return "Comparison operands have different types."
			if relation in ["lt", "le"] and not typeof(left.value) in [TYPE_INT, TYPE_FLOAT]:
				return "Ordered comparisons require numeric operands."
			match relation:
				"eq": machine.registers[instruction.dst] = left.value == right.value
				"ne": machine.registers[instruction.dst] = left.value != right.value
				"lt": machine.registers[instruction.dst] = left.value < right.value
				"le": machine.registers[instruction.dst] = left.value <= right.value
				_: return "Unsupported comparison operation."
		"BRANCH":
			if not machine.registers.get(instruction.get("reg", "")) is bool:
				return "Branch condition must be a boolean register."
			var target: String = str(instruction.get("then" if machine.registers[instruction.reg] else "else", ""))
			machine.pc = _label(functions[machine.function], target)
			if machine.pc < 0:
				return "Branch label does not exist in this function."
		"JUMP":
			machine.pc = _label(functions[machine.function], str(instruction.get("target", "")))
			if machine.pc < 0:
				return "Jump label does not exist in this function."
		"CALL":
			if not functions.has(instruction.get("function", "")):
				return "Call target does not exist."
			if machine.call_stack.size() >= int(limits.get("stack", 16)):
				return "Limit: call stack exhausted."
			machine.call_stack.append({"function": machine.function, "pc": machine.pc, "registers": machine.registers.duplicate(true), "dst": instruction.get("dst", "result")})
			machine.function = instruction.function
			machine.pc = 0
			machine.registers = {}
		"RET":
			if machine.call_stack.is_empty() or not machine.registers.has(instruction.get("reg", "")):
				return "Return has no caller or source register."
			var value: Variant = machine.registers[instruction.reg]
			var caller: Dictionary = machine.call_stack.pop_back()
			machine.function = caller.function
			machine.pc = caller.pc
			machine.registers = caller.registers
			machine.registers[caller.dst] = value
		"SET_OUTPUT":
			machine.outputs[instruction.get("key", "result")] = instruction.get("value")
		"HALT":
			machine.status = "halted"
		_:
			return "Unsupported VM instruction."
	var slots: int = machine.registers.size() + machine.outputs.size()
	for frame in machine.call_stack:
		slots += frame.registers.size()
	if slots > int(limits.get("memory", 64)):
		return "Limit: virtual value storage exhausted."
	machine.trace.append({"function": old_function, "pc": old_pc, "op": op, "next_function": machine.function, "next_pc": machine.pc, "outputs": machine.outputs.duplicate(true)})
	return ""


static func _operand(raw: Variant, registers: Dictionary) -> Dictionary:
	if not raw is Dictionary or raw.size() != 1:
		return {"ok": false}
	if raw.has("reg"):
		return {"ok": registers.has(raw.reg), "value": registers.get(raw.reg)}
	return {"ok": raw.has("value"), "value": raw.get("value")}


static func _label(instructions: Array, name: String) -> int:
	for index in range(instructions.size()):
		if instructions[index].get("label", "") == name:
			return index
	return -1


static func _valid_inputs(definition: Dictionary, values: Variant) -> bool:
	if not values is Dictionary or values.size() != definition.inputs.size() or not values.has_all(definition.inputs.keys()):
		return false
	for id in definition.inputs:
		var spec: Dictionary = definition.inputs[id]
		var value: Variant = values[id]
		if spec.type == "bool" and not value is bool:
			return false
		if spec.type == "int" and not _integer(value, -1000000, 1000000):
			return false
		if spec.type == "enum" and not spec.get("choices", []).has(value):
			return false
		if spec.type == "string" and (not value is String or value.length() > 256):
			return false
	return true


static func goal_met(definition: Dictionary, state: Dictionary, requirements: Array = []) -> bool:
	var names: Array = requirements if not requirements.is_empty() else definition.get("outcomes", {}).keys()
	if names.is_empty():
		return false
	for name in names:
		if not definition.get("outcomes", {}).has(name):
			return false
		var desired: Dictionary = definition.outcomes[name]
		var found := false
		for machine in state.get("cases", {}).values():
			if machine.get("status", "") != "halted" or machine.inputs.get("retention_scope") != desired.get("input_scope"):
				continue
			var matches := true
			for key in desired.get("output", {}):
				matches = matches and machine.outputs.get(key) == desired.output[key]
			found = found or matches
		if not found:
			return false
	return true


static func public_data(definition: Dictionary, state: Dictionary) -> Dictionary:
	var listing: Array = []
	var graph: Array = []
	for function in definition.program.functions:
		for index in range(definition.program.functions[function].size()):
			var row: Dictionary = definition.program.functions[function][index].duplicate(true)
			row["owner_function"] = function
			row["pc"] = index
			listing.append(row)
			if row.op == "CALL":
				graph.append({"from": function, "to": row.get("function", "")})
	var machine: Dictionary = state.get("cases", {}).get(state.get("active_case", ""), {})
	return {"listing": listing, "call_graph": graph, "trace": machine.get("trace", []), "outputs": machine.get("outputs", {}), "limits": definition.get("limits", {}), "steps_used": machine.get("steps_used", 0), "status": machine.get("status", "idle"), "active_case": state.get("active_case", ""), "cases": state.get("cases", {}).keys()}


static func _ok(definition: Dictionary, state: Dictionary, text: String, feedback: Dictionary = {}) -> Dictionary:
	return {"ok": true, "code": "VM_OBSERVED", "text": text, "state": state, "solved": goal_met(definition, state), "status": 200, "feedback": feedback, "effects": {}}


static func _error(code: String, text: String, previous: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "text": text, "state": previous.duplicate(true), "solved": false, "status": 400, "effects": {}}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum
