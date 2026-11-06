extends "res://tests/headless/test_mutation_limits.gd"

const OPTIONAL_FIXTURE := "res://tests/fixtures/investigation_solutions.json"
const Habitat = preload("res://scripts/core/habitat_store.gd")
var route_results: Dictionary = {}
var replay_findings: Array = []

func _new_for_slot(path: String) -> Variant:
	return Campaign.new(path, "investigation")

func _run() -> void:
	var before := _protected_all()
	test_root = "user://tests/mutation_limits_optional_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OPTIONAL_FIXTURE))
	var catalog = load("res://scripts/core/campaign_catalog.gd")
	_check(catalog.list_packs().size() == 4, "optional topics do not add a fifth main choice")
	_check(catalog.list_commissions().size() == 1, "optional catalog is explicitly separate")
	for mid in ["I01", "I02"]:
		route_results[mid] = []
		for route in fixture.packs.investigation.missions[mid].paths:
			var game = _fresh()
			_check(game.choose_mission(mid).ok, mid + " independently starts before any other commission")
			_check(game.get_view().endings.is_empty() and not game.choose_ending("invented").ok, "zero-main collection has no vacuous ending")
			var index := 0
			for action in route.actions:
				if not _replay(game, [action], mid + "/" + str(route.id)): break
				if index == route.actions.size() / 2:
					_round_trip(game, "independent optional midway")
				index += 1
			_check(game.get_view().completed, mid + "/" + str(route.id) + " actually completes")
			_check(game.get_view().endings.is_empty(), "commission completion never unlocks a main ending")
			var selected := str(game.get_view().mission_id)
			_check(game.advance().ok and game.get_view().mission_id == selected, "completed commission does not auto-chain another topic")
			_round_trip(game, "optional completed state")
			var snapshot: Dictionary = game.export_snapshot()
			var cid := "iv1_i01_iam" if mid == "I01" else "iv1_i02_release"
			route_results[mid].append(snapshot.current_world.model_states[cid].duplicate(true))
			_test_tampered_actor(game, snapshot, cid)
			_test_cross_pack(snapshot)
			_test_invalid_action(game, cid)
			if mid == "I02": _test_page(game, str(route.id))
			_test_stale_current(game, mid, cid)
	_check(route_results.I01.size() == 2 and route_results.I01[0].bindings != route_results.I01[1].bindings, "IAM alternatives produce distinct actual bindings")
	_check(route_results.I02.size() == 2 and route_results.I02[0].deployed != route_results.I02[1].deployed, "release alternatives deploy distinct actual artifacts")
	_check(route_results.I02[0].report.recipient_id != route_results.I02[1].report.recipient_id, "disclosure recipients and follow-ups are actual choices")
	_test_unsafe_release()
	_test_habitat_independent()
	_check(_protected_all() == before, "all real settings/campaign/habitat files and sidecars remain unchanged")
	_cleanup(test_root)
	print(JSON.stringify({"suite":"optional_regressions", "checks":checks, "failures":failures, "optional_routes":4, "main_cases":47, "main_routes":94, "replay_findings":replay_findings, "limit":"Independent public API and isolated disk checks; native UI/physical OS acceptance is separate."}))
	quit(0 if failures.is_empty() else 1)

func _protected_all() -> Dictionary:
	var result := _fingerprints()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = Habitat.PATH + suffix
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result

func _test_tampered_actor(game: Variant, snapshot: Dictionary, cid: String) -> void:
	var altered := snapshot.duplicate(true)
	altered.current_world.model_actions[cid][0]["account"] = "fabricated-principal"
	var candidate = _fresh()
	var result: Dictionary = candidate.restore_snapshot(altered)
	replay_findings.append({"model":cid,"forged_account_accepted":result.ok})
	_check(not result.ok, cid + ": changing only recorded actor must invalidate snapshot")
	_check(game.export_snapshot() == snapshot, "rejected foreign candidate cannot mutate original game")
	for key in ["model_states", "model_actions"]:
		altered = snapshot.duplicate(true)
		if key == "model_states": altered.current_world.model_states[cid]["solved"] = false
		else: altered.current_world.model_actions[cid][0]["input"]["action"] = "invented"
		_check(not candidate.restore_snapshot(altered).ok, "edited model state or impossible action cannot restore")

func _test_cross_pack(snapshot: Dictionary) -> void:
	for pack in ["intruder", "defender", "tracker", "challenge"]:
		var candidate = Campaign.new(test_root + "/foreign_" + pack + ".json", pack)
		_check(not candidate.restore_snapshot(snapshot).ok, "optional snapshot cannot replace " + pack)

func _test_invalid_action(game: Variant, cid: String) -> void:
	var before: Dictionary = game.export_snapshot()
	var result: Dictionary = game.use_tool(cid, {"action":"probe", "request_id":"fabricated", "case_id":"fabricated", "outcome":"allow"})
	_check(not result.ok and game.export_snapshot() == before, "caller cannot invent a result or request")

func _test_page(game: Variant, route: String) -> void:
	var url := "https://i02.investigation.packet.test/review"
	var before: Dictionary = game.export_snapshot()
	var page: Dictionary = game.browse(url, 0)
	_check(page.ok == (route == "reviewed_rebuild"), "article availability reflects actual selected recipient")
	_check(game.export_snapshot() == before, "authorized article GET is strictly read-only")
	_check(page.get("cookie", "").is_empty() and game.export_snapshot().current_world.web_sessions == before.current_world.web_sessions, "SSH projection grants no HTTP session")
	for request in [{"method":"POST","url":url,"body":{}},{"method":"GET","url":url+"?view=private","body":{}},{"method":"GET","url":url,"body":{"private":true}}]:
		before = game.export_snapshot()
		var result: Dictionary = game.request(request.method, request.url, request.body, {}, 0)
		_check(not result.ok and result.status == 405 and game.export_snapshot() == before, "projection rejects mutation/query/body without state changes")
	before = game.export_snapshot()
	page = game.browse(url, 1)
	_check(not page.ok and game.export_snapshot() == before, "local terminal cannot borrow another terminal's SSH authority")
	var fresh = _fresh()
	fresh.choose_mission("I02")
	before = fresh.export_snapshot()
	page = fresh.browse(url, 0)
	_check(not page.ok and fresh.export_snapshot() == before, "anonymous projection denial does not raise alert or mutate state")

func _test_stale_current(game: Variant, mid: String, cid: String) -> void:
	var runtime = game.get("_runtime")
	var def: Dictionary = runtime.get("_definition").challenges[cid]
	var models = load("res://scripts/core/tool_runtime.gd")
	var result: Dictionary
	if mid == "I01":
		result = game.use_tool(cid, {"action":"restore_initial"})
		_check(result.ok and not models.IAMCase.goal_met(def, game.export_snapshot().current_world.model_states[cid]), "restoring insecure IAM config invalidates current proof")
	else:
		result = game.use_tool(cid, {"action":"restore_initial"})
		_check(result.ok and not models.ReleaseCase.goal_met(def, game.export_snapshot().current_world.model_states[cid]), "restoring release state invalidates current verification/report proof")
	_round_trip(game, "changed completed optional case preserves historical completion and current state separately")

func _test_habitat_independent() -> void:
	var store = Habitat.new(test_root + "/habitat.json")
	_check(store.load_state().ok, "independent household loads without mandatory sidequests")
	var main = Campaign.new(test_root + "/main.json", "intruder")
	var main_before: Dictionary = main.export_snapshot()
	_check(store.apply("order", {"product_id":"monitor_dual"}).ok, "starter funds permit cosmetic purchase without advanced quest")
	var before: Dictionary = store.export_snapshot()
	for params in [{"product_id":"keyboard_coral","price":-10},{"product_id":"../../outside"}]:
		_check(not store.apply("order",params).ok and store.export_snapshot() == before, "forged price/path cannot alter wallet")
	_check(not store.apply("equip", {"slot":"monitor","product_id":"monitor_dual"}).ok, "pending order cannot equip")
	_check(store.apply("collect_delivery").ok and store.apply("equip", {"slot":"monitor","product_id":"monitor_dual"}).ok, "pickup gives actual ownership before equip")
	_check(main.export_snapshot() == main_before, "household progression never changes main world or prerequisites")
	var forged: Dictionary = store.export_snapshot()
	forged.state["balance"] = 999999
	_check(not store.validate_snapshot(forged).ok, "forged household wallet cannot pass replay validation")
	for action in [["accept_job",{"job_id":"network_cabinet"}],["inspect_cabinet",{}],["configure_cabinet",{"route":"off","locked":true}],["verify_job",{}]]:
		store.apply(action[0],action[1])
	_check(not store.get_view().job.current_check.passed and store.get_view().earned == 0, "turning cabinet off fails actual normal telemetry and yields no reward")
	store.apply("configure_cabinet",{"route":"public","locked":true});store.apply("verify_job")
	_check(not store.get_view().job.current_check.passed, "locked cover alone cannot secure public route")
	store.apply("configure_cabinet",{"route":"approved_relay","locked":true});store.apply("verify_job")
	var earned: int = store.get_view().earned
	_check(earned == 200, "registered alternate safe route earns one reward")
	store.apply("verify_job")
	var restored = Habitat.new(test_root + "/habitat.json")
	_check(restored.load_state().ok and restored.get_view().earned == earned, "repeat verification and reload do not farm rewards")

func _test_unsafe_release() -> void:
	var game = _fresh()
	game.choose_mission("I02")
	_check(_replay(game, [{"kind":"command","line":"ssh investigator@i02.investigation.packet.test"},{"kind":"password","value":"source-custody"}], "unsafe release authorization"), "unsafe case uses real authorized SSH")
	var cid := "iv1_i02_release"
	for id in ["unsafe_attested", "offline", "revoked"]:
		_check(game.use_tool(cid,{"action":"inspect_artifact","artifact_id":id}).ok, "actual candidate inspected " + id)
		_check(game.use_tool(cid,{"action":"verify","artifact_id":id,"statement_id":id+"_statement","registry_id":"ledger"}).ok, "verification records actual candidate result")
		var state: Dictionary = game.export_snapshot().current_world.model_states[cid]
		if id == "revoked":
			_check(not state.verified[id].valid and not game.use_tool(cid,{"action":"deploy","artifact_id":id}).ok, "revoked builder cannot deploy even matching statement")
			continue
		_check(state.verified[id].valid and game.use_tool(cid,{"action":"deploy","artifact_id":id}).ok, "unsafe or offline payload can have valid provenance")
		for case_id in ["citizen","notice","cross_tenant","internal"]:
			_check(game.use_tool(cid,{"action":"probe","case_id":case_id}).ok, "all real service probes run")
		state = game.export_snapshot().current_world.model_states[cid]
		if id == "unsafe_attested":
			_check(state.probe_receipts.internal.status == 200 and state.probe_receipts.internal.business, "attested unsafe manifest actually exposes internal target")
		else:
			_check(state.probe_receipts.citizen.status == 503 and not state.probe_receipts.citizen.business, "offline signed manifest actually fails legitimate service")
		_check(not game.get_view().completed, "valid provenance alone cannot complete unsafe business state")
	var before: Dictionary = game.export_snapshot()
	_check(not game.use_tool(cid,{"action":"report","recipient_id":"journalist","evidence_ids":["stable_evidence"],"fields":["stable_internal"]}).ok, "unobserved restricted evidence cannot be sent")
	_check(game.export_snapshot() == before, "refused sensitive report preserves all state")
