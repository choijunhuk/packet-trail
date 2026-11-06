extends SceneTree
## Reachable mutation/save contracts and functional UI regressions; never uses default slots.

const Campaign = preload("res://scripts/core/campaign_game.gd")
const Loader = preload("res://scripts/core/campaign_loader.gd")
const FS = preload("res://scripts/core/virtual_fs.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Localization = preload("res://scripts/presentation/localization.gd")
const PROTECTED := ["user://settings.json", "user://saves/campaign_01.json", "user://saves/slot_01.json",
	"user://saves/legacy_continue_01.json", "user://saves/intruder_v2_01.json",
	"user://saves/defender_01.json", "user://saves/tracker_01.json", "user://saves/challenge_01.json"]

var checks := 0
var failures: Array[Dictionary] = []
var definition: Dictionary = {}
var solutions: Dictionary = {}
var test_root := ""
var slots: Dictionary = {}
var next_slot := 0
var observations: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var before := _fingerprints()
	test_root = "user://tests/mutation_limits_%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
	var loaded: Dictionary = Loader.load_campaign()
	_check(loaded.get("ok", false), "legacy campaign definition loads")
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
	_check(fixture is Dictionary and fixture.get("missions") is Dictionary, "legacy actual-action fixtures load")
	if loaded.get("ok", false) and fixture is Dictionary and fixture.get("missions") is Dictionary:
		definition = loaded.definition
		solutions = fixture.missions
		_test_final_paths(false)
		_test_final_paths(true)
		_test_file_operations()
		_test_destination_limits()
		_test_directory_budget()
		_test_legacy_loaded_capacity()
		_test_receipt_budget()
		_test_save_recovery()
		for id in ["M06", "M23"]:
			_test_auth_credit(id)
		await _test_ui_lifecycle()
	_check(_fingerprints() == before, "default settings/campaign/legacy bytes remain unchanged")
	_cleanup(test_root)
	print(JSON.stringify({"suite": "mutation_limits", "checks": checks, "failures": failures,
		"observations": observations, "limit": "Real finite campaign API and isolated disk slots; UI method calls are headless functional evidence, not native/physical GUI input."}))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not ok:
		failures.append({"case": label, "detail": detail})


func _fresh() -> Variant:
	next_slot += 1
	var path := test_root + "/slot_%d.json" % next_slot
	var game = _new_for_slot(path)
	slots[game.get_instance_id()] = path
	return game


func _new_for_slot(path: String) -> Variant:
	return Campaign.new(path)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return left.recursive_equal(right, 0)


func _round_trip(game: Variant, label: String) -> void:
	var saved: Dictionary = game.save_game()
	_check(saved.get("ok", false), label + ": reachable state saves", saved.get("code"))
	if not saved.get("ok", false):
		return
	var restored = _new_for_slot(slots[game.get_instance_id()])
	var loaded: Dictionary = restored.load_game()
	_check(loaded.get("ok", false), label + ": real isolated slot reloads", loaded.get("code"))
	_check(_same(restored.export_snapshot(), game.export_snapshot()), label + ": disk round-trip preserves canonical state")


func _completed(game: Variant, id: String) -> bool:
	for item in game.get_view().get("missions", []):
		if item.get("id") == id:
			return item.get("completed", false)
	return false


func _prepare(game: Variant, id: String) -> bool:
	for prior in definition.missions[id].prerequisites:
		if not _completed(game, prior):
			if not _prepare(game, prior) or not _replay(game, solutions[prior].paths[0].actions, "prepare " + str(prior)):
				return false
	var chosen: Dictionary = game.choose_mission(id)
	_check(chosen.get("ok", false), "actual prerequisites unlock " + id, chosen.get("code"))
	return chosen.get("ok", false)


func _action(game: Variant, action: Dictionary) -> Dictionary:
	var terminal := int(action.get("terminal_id", 0))
	match str(action.get("kind", "")):
		"command": return game.execute(action.line, terminal)
		"password": return game.submit_password(action.value, terminal)
		"tool": return game.use_tool(action.tool_id, action.get("params", {}))
		"request": return game.request(action.get("method", "GET"), action.url, action.get("body", {}), action.get("headers", {}), terminal)
		"browse": return game.browse(action.url)
		"collect_web": return game.collect_web(action.url)
	return {"ok": false, "code": "UNKNOWN_TEST_ACTION"}


func _replay(game: Variant, actions: Array, label: String) -> bool:
	for action in actions:
		var result := _action(game, action)
		for key in action.get("expect", {"ok": true}):
			var expected: Variant = action.get("expect", {"ok": true})[key]
			_check(result.get(key) == expected, label + ": actual action " + key, result.get("code"))
			if result.get(key) != expected:
				return false
	return true


func _local(game: Variant) -> void:
	for attempt in range(16):
		if game.get_view().get("host") == "local":
			return
		game.execute("exit")
	_check(false, "terminal returns to local without replacing state")


func _test_final_paths(after_completion: bool) -> void:
	var game = _fresh()
	if after_completion:
		if not _replay(game, solutions.M01.paths[0].actions, "complete M01 before mutation"):
			return
		_local(game)
	_round_trip(game, "before path boundary")
	var commands := ["mkdir ~/" + "a".repeat(400), "cd ~/" + "a".repeat(400),
		"mkdir " + "b".repeat(400), "cd " + "b".repeat(400), "mkdir " + "c".repeat(220)]
	for index in range(commands.size()):
		var line: String = commands[index]
		_check(line.length() <= 512, "path regression fits product terminal input")
		var before: Dictionary = game.export_snapshot()
		var path: String = slots[game.get_instance_id()]
		var digest := FileAccess.get_sha256(path)
		var result: Dictionary = game.execute(line)
		if index < commands.size() - 1:
			_check(result.get("ok", false), "legal relative path prefix remains usable", result.get("code"))
		else:
			_check(not result.get("ok", true), "overlong final path is rejected before mutation")
			_check(_same(game.export_snapshot(), before), "rejected final path preserves world/checkpoint")
		var saved: Dictionary = game.save_game()
		_check(saved.get("ok", false), "path action leaves a saveable state", saved.get("code"))
		if not saved.get("ok", false):
			_check(FileAccess.get_sha256(path) == digest, "failed save preserves existing isolated slot bytes")
	game.reset()
	_round_trip(game, "reset after path mutation")
	_check(_completed(game, "M01") == after_completion, "reset preserves only existing completion receipt")
	_check(not FS.normalize("x".repeat(30), "/home/player/" + "y".repeat(1000)).get("ok", true), "VFS validates composed absolute length")


func _before_m01_copy(game: Variant) -> bool:
	for action in solutions.M01.paths[0].actions:
		if action.kind == "command" and str(action.line).begins_with("scp "):
			return true
		if not _replay(game, [action], "real M01 copy context"):
			return false
	_check(false, "M01 actual path contains a copy action")
	return false


func _test_file_operations() -> void:
	var game = _fresh()
	for line in ["mkdir ~/scratch", "mkdir ~/scratch/inside"]:
		_check(game.execute(line).get("ok", false), "normal local directory creation: " + line)
	var before: Dictionary = game.export_snapshot()
	_check(not game.execute("rmdir ~/scratch").get("ok", true), "nonempty directory cannot be removed")
	_check(_same(game.export_snapshot(), before), "failed rmdir rolls back")
	if not _before_m01_copy(game):
		return
	for line in ["mkdir /public/qa", "rm /public/readme.txt", "mv /public/readme.txt /public/other.txt", "rmdir /public"]:
		before = game.export_snapshot()
		_check(not game.execute(line).get("ok", true), "remote originals remain immutable: " + line)
		_check(_same(game.export_snapshot(), before), "remote mutation refusal preserves state")
	_check(game.execute("cp /vault/handoff.log ~/scratch/copy.log").get("ok", false), "remote readable source copies to local home")
	_local(game)
	_check(game.execute("mv ~/scratch/copy.log ~/scratch/moved.log").get("ok", false), "local move preserves file provenance")
	var world: Dictionary = game.export_snapshot().current_world
	_check(world.local_files.get("/home/player/scratch/moved.log", {}).get("record_id") == "handoff-47", "moved copy retains canonical record identity")
	for line in ["rm ~/scratch/moved.log", "rmdir ~/scratch/inside", "rmdir ~/scratch"]:
		_check(game.execute(line).get("ok", false), "local cleanup reclaims entries: " + line)
	_round_trip(game, "cp/mv/rm/rmdir")


func _test_directory_budget() -> void:
	var game = _fresh()
	var initial: int = game.export_snapshot().current_world.local_files.size()
	var created: Array[String] = []
	var rejected := false
	for index in range(516):
		var before: Dictionary = game.export_snapshot()
		var name := "~/bounded_%03d" % index
		var result: Dictionary = game.execute("mkdir " + name)
		if not result.get("ok", false):
			rejected = true
			_check(_same(game.export_snapshot(), before), "directory capacity refusal preserves state")
			break
		created.append(name)
	var count: int = game.export_snapshot().current_world.local_files.size()
	observations["local_capacity"] = {"initial": initial, "created": created.size(), "final": count}
	_check(rejected and count <= 512, "mkdir shares a finite saveable local-entry budget", count)
	_round_trip(game, "directory capacity")
	if created.is_empty():
		return
	_check(game.execute("rmdir " + created.back()).get("ok", false), "empty rmdir reclaims one exhausted entry")
	if not _before_m01_copy(game):
		return
	var copied: Dictionary = game.execute("scp /vault/handoff.log")
	_check(copied.get("ok", false), "reclaimed directory capacity permits actual record archive", copied.get("code"))
	_round_trip(game, "archive after capacity recovery")


func _test_destination_limits() -> void:
	var game = _fresh()
	for component in ["a".repeat(400), "b".repeat(400), "c".repeat(199)]:
		_check(game.execute("mkdir " + component).get("ok", false), "legal destination folder can be created")
		_check(game.execute("cd " + component).get("ok", false), "legal destination folder can be entered")
	var destination: String = game.get_view().cwd
	if not _before_m01_copy(game):
		return
	for operation in ["scp", "cp"]:
		var before: Dictionary = game.export_snapshot()
		var result: Dictionary = game.execute(operation + " /vault/handoff.log " + destination)
		_check(not result.get("ok", true), operation + ": filename join cannot create an overlong final destination")
		_check(_same(game.export_snapshot(), before), operation + ": rejected final destination preserves source and world")
		game.restore_snapshot(before)
	_check(game.execute("scp /vault/handoff.log ~/short.log").get("ok", false), "short destination remains usable after refused copies")
	_local(game)
	var before: Dictionary = game.export_snapshot()
	var moved: Dictionary = game.execute("mv ~/short.log " + "z".repeat(20))
	_check(not moved.get("ok", true), "mv checks the composed destination before removing source")
	_check(_same(game.export_snapshot(), before), "refused move preserves original local file")
	game.restore_snapshot(before)
	_round_trip(game, "archive/cp/mv final destinations")


func _test_save_recovery() -> void:
	var game = _fresh()
	_round_trip(game, "recovery initial checkpoint")
	var backup: Dictionary = game.export_snapshot()
	game.execute("mkdir ~/newer-checkpoint")
	_round_trip(game, "recovery newer checkpoint")
	var path: String = slots[game.get_instance_id()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "only the owned test slot can be deliberately damaged")
	if file == null:
		return
	file.store_string("{damaged test slot")
	file.close()
	var damaged_hash := FileAccess.get_sha256(path)
	var before: Dictionary = game.export_snapshot()
	var loaded: Dictionary = game.load_game()
	_check(not loaded.get("ok", true) and loaded.get("backup_available", false), "damaged isolated slot reports its valid backup")
	_check(_same(game.export_snapshot(), before), "failed disk load preserves active progress")
	var recovered: Dictionary = game.recover_save()
	_check(recovered.get("ok", false), "normal backup recovers through the real Store API", recovered.get("code"))
	_check(_same(game.export_snapshot(), backup), "recovery applies the exact older checkpoint")
	var preserved: String = recovered.get("damaged_path", "")
	_check(preserved.begins_with(test_root) and FileAccess.get_sha256(preserved) == damaged_hash, "recovery preserves the damaged original bytes inside the owned folder")
	_round_trip(game, "recovered slot")


func _test_legacy_loaded_capacity() -> void:
	var game = _fresh()
	var legacy: Dictionary = game.export_snapshot()
	# Compatibility input at the old validator's valid limit; never used as solution evidence.
	for index in range(508):
		legacy.current_world.local_files["/home/player/legacy_%03d" % index] = {
			"kind": "dir", "owner": "player", "group": "player", "mode": "700",
			"content": "", "record_id": "", "source": ""}
	legacy.mission_states.M01 = legacy.current_world.duplicate(true)
	_check(game.restore_snapshot(legacy).get("ok", false), "previously valid512-entry legacy snapshot remains loadable")
	_check(game.execute("ls").get("ok", false), "full legacy state retains non-growing observation")
	_round_trip(game, "loaded512-entry legacy checkpoint")
	var before: Dictionary = game.export_snapshot()
	_check(not game.execute("mkdir ~/one-too-many").get("ok", true), "loaded legacy capacity rejects new growth")
	_check(_same(game.export_snapshot(), before), "growth rejection preserves full legacy checkpoint")
	_check(game.execute("rmdir ~/legacy_000").get("ok", false), "loaded full legacy state can reclaim a directory")
	if _before_m01_copy(game):
		var archived: Dictionary = game.execute("scp /vault/handoff.log")
		_check(archived.get("ok", false), "reclaimed old capacity permits the genuine required record", archived.get("code"))
		_check(game.get_view().get("completed", false), "real recovery actions complete the old mission normally")
		_round_trip(game, "old capacity restored through real actions")


func _test_receipt_budget() -> void:
	var game = _fresh()
	if not _prepare(game, "M02") or not _replay(game, solutions.M02.paths[0].actions, "M02 receipt setup"):
		return
	_round_trip(game, "before receipt budget")
	var accepted := 0
	var limited := false
	var maximum := 0
	for id in ["m02_exhibit_1_a", "m02_primary"]:
		var challenge: Dictionary = definition.missions.M02.challenges[id]
		_local(game)
		var required: Dictionary = challenge.requires_session
		var account: Dictionary = definition.missions.M02.hosts[required.host_id].accounts[required.account_id]
		game.execute("ssh " + required.account_id + "@" + definition.missions.M02.hosts[required.host_id].domain)
		game.submit_password(account.password)
		for index in range(128):
			var before: Dictionary = game.export_snapshot()
			var result: Dictionary = game.use_tool(id, {"input": "budget-observation-" + "x".repeat(4096)})
			if not result.get("ok", false):
				limited = true
				_check(_same(game.export_snapshot(), before), "receipt budget refusal is atomic")
				break
			accepted += 1
			var bytes: int = JSON.stringify(game.export_snapshot(), "", true, true).to_utf8_buffer().size()
			maximum = maxi(maximum, bytes)
			if bytes > Store.MAX_BYTES:
				_check(false, "accepted observation never exceeds serializable slot budget", bytes)
				break
		if maximum > Store.MAX_BYTES:
			break
	observations["receipt_budget"] = {"accepted": accepted, "max_bytes": maximum, "limit_observed": limited}
	_check(limited, "finite observation or snapshot budget is enforced")
	_round_trip(game, "large repeated model receipts")


func _test_auth_credit(id: String) -> void:
	var game = _fresh()
	if not _prepare(game, id):
		return
	var cid := "m06_primary" if id == "M06" else "m23_login"
	var challenge: Dictionary = definition.missions[id].challenges[cid]
	var host: Dictionary = definition.missions[id].hosts[challenge.host_id]
	var input := {"action": "login", "username": challenge.account_id, "password": host.accounts[challenge.account_id].password}
	_check(game.use_tool(cid, {"input": input}).get("code") == "MISSING_EVIDENCE", id + ": direct model is gated before evidence")
	_check(game.execute("configure " + challenge.policy_id + " true").get("ok", false), id + ": legitimate service policy can be configured")
	var url: String = "https://" + host.domain + "/login"
	var statuses: Array = []
	statuses.append(game.request("POST", url, input).get("status"))
	var cookie: Dictionary = game.export_snapshot().current_world.web_sessions.get(challenge.host_id, {}).duplicate(true)
	_check(not cookie.get("token", "").is_empty() and cookie.get("account_id") == challenge.account_id, id + ": real valid login issues a cookie before assessment")
	for index in range(3):
		statuses.append(game.request("POST", url, {"username": challenge.account_id, "password": "qa-invalid-password"}).get("status"))
	_check(statuses == [200, 401, 401, 429], id + ": real login/account failure counters remain shared", statuses)
	var world: Dictionary = game.export_snapshot().current_world
	_check(not world.facts.has(challenge.fact_id), id + ": login observation cannot award gated evidence early")
	var reward := false
	for file in world.local_files.values():
		reward = reward or file.get("record_id") == challenge.record_id
	_check(not reward, id + ": gated canonical reward is not archived early")
	_check(not world.completed, id + ": actual remaining goals still prevent completion")
	_round_trip(game, id + ": ungraded real authentication replay")
	var graded = _fresh()
	if not _prepare(graded, id):
		return
	for action in solutions[id].paths[0].actions:
		if action.kind == "tool" and action.get("tool_id") == cid:
			break
		if not _replay(graded, [action], id + ": acquire actual prerequisite evidence"):
			return
	for fact in challenge.get("requires_facts", []):
		_check(graded.get_view().facts.has(fact), id + ": graded experiment has prerequisite evidence")
	for index in range(3):
		graded.request("POST", url, {"username": challenge.account_id, "password": "qa-invalid-password"})
	var waited: Dictionary = graded.use_tool(cid, {"input": {"action": "wait", "username": challenge.account_id, "ticks": 2}})
	_check(waited.get("ok", false), id + ": actual cooldown recovery remains available")
	_check(graded.request("POST", url, input).get("status") == 200, id + ": authenticated normal workflow survives recovery")
	_check(graded.get_view().facts.has(challenge.fact_id), id + ": valid assessed observation awards evidence")
	_round_trip(graded, id + ": assessed model replay")


func _test_ui_lifecycle() -> void:
	Localization.configure("ko")
	var desktop = load("res://scenes/campaign_desktop.tscn").instantiate()
	desktop.save_slot_path = test_root + "/ui.json"
	desktop.set("pack_id", "legacy_intruder")
	root.add_child(desktop)
	await process_frame
	var ready: bool = desktop.get_game_view().get("ready", false)
	_check(ready, "UI regression has a real ready legacy campaign")
	if not ready:
		desktop.queue_free()
		for index in range(4):
			await process_frame
		return
	desktop.call("_refresh_all")
	for id in ["mail", "board", "help", "terminal"]:
		desktop.call("_open_app", id, false)
	var open: Array[String] = []
	for child in desktop.layer.get_children():
		if child.visible:
			open.append(str(child.get_meta("app_id")))
	_check(open.size() == 4 and open.has("mail") and open.has("board") and open.has("help") and open.has("term0"), "UI regression opens four actual independent app windows", open)
	for direction in [-1, 1]:
		var reached: Array[String] = []
		for index in range(open.size() * 2):
			desktop.call("_cycle_window", direction)
			if not reached.has(str(desktop.active_id)):
				reached.append(str(desktop.active_id))
		_check(reached.size() == open.size(), "window cycle reaches every open app in direction " + str(direction), reached)
	var before: int = desktop.sized.size()
	for index in range(40):
		desktop.call("_refresh_all")
		await process_frame
	var dead := 0
	for row in desktop.sized:
		if not is_instance_valid(row[0]):
			dead += 1
	observations["ui_registry"] = {"before": before, "after_40": desktop.sized.size(), "dead": dead}
	_check(dead == 0, "size registry releases destroyed controls", dead)
	_check(desktop.sized.size() <= before + 32, "size registry remains bounded across unchanged refreshes", desktop.sized.size())
	desktop.queue_free()
	for index in range(4):
		await process_frame


func _fingerprints() -> Dictionary:
	var result := {}
	for base in PROTECTED:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var path: String = base + suffix
			result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result


func _cleanup(path: String) -> void:
	if not path.begins_with(test_root) or not test_root.begins_with("user://tests/mutation_limits_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child in directory.get_directories():
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(path)
