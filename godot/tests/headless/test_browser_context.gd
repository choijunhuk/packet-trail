extends "res://tests/headless/test_mutation_limits.gd"
## Explicit browser selection uses the existing virtual actor/cookie/rollback contracts.

const HOME := "https://archive.packet.test"
const RECORD := "https://mirror.packet.test/cache/47"


func _run() -> void:
	var protected_before := _fingerprints()
	test_root = "user://tests/mutation_limits_browser_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var loaded: Dictionary = Loader.load_campaign("legacy_intruder")
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
	_check(loaded.get("ok", false) and fixture is Dictionary and fixture.get("missions") is Dictionary,
		"existing legacy definitions and actual-action fixtures load")
	if loaded.get("ok", false) and fixture is Dictionary and fixture.get("missions") is Dictionary:
		definition = loaded.definition
		solutions = fixture.missions
		_test_legacy_defaults()
		var game = _fresh()
		var browse_args := _argument_count(game, "browse")
		var collect_args := _argument_count(game, "collect_web")
		observations["api_arguments"] = {"browse": browse_args, "collect_web": collect_args}
		_check(browse_args == 2, "browse accepts an explicit terminal while retaining its one-argument default", browse_args)
		_check(collect_args == 2, "collect_web accepts an explicit terminal while retaining its legacy default", collect_args)
		if browse_args == 2 and collect_args == 2:
			_test_explicit_selection_and_pending()
			_test_invalid_and_ordinary_failures()
			_test_shared_web_actor_and_vantage()
			_test_archive_capacity_rollback()
			_test_snapshot_budget_rollback()
			_test_failed_response_get_side_effects()
	_check(_fingerprints() == protected_before, "default settings and all campaign slots/sidecars remain unchanged")
	_cleanup(test_root)
	print(JSON.stringify({"suite": "browser_context", "checks": checks, "failures": failures,
		"observations": observations, "protected_paths": protected_before.size(),
		"limit": "Actual virtual core APIs with isolated test slots; UI drafts, native rendering/input, and physical IME are not exercised."}))
	quit(0 if failures.is_empty() else 1)


func _argument_count(game: Variant, method: String) -> int:
	for entry in game.get_method_list():
		if entry.name == method:
			return entry.args.size()
	return -1


func _checkpoint(game: Variant) -> Dictionary:
	return game._runtime.checkpoint()


func _selected(game: Variant) -> int:
	return int(_checkpoint(game).terminal)


func _browse(game: Variant, url: String, terminal: int) -> Dictionary:
	return game.callv("browse", [url, terminal])


func _collect(game: Variant, url: String, terminal: int) -> Dictionary:
	return game.callv("collect_web", [url, terminal])


func _login_ssh(game: Variant, host: String, account: String, password: String, terminal: int) -> bool:
	var requested: Dictionary = game.execute("ssh " + account + "@" + host, terminal)
	_check(requested.get("needs_password", false), "real SSH fixture requests a password on terminal " + str(terminal), requested.get("code"))
	var authenticated: Dictionary = game.submit_password(password, terminal)
	_check(authenticated.get("ok", false), "real SSH fixture authenticates only terminal " + str(terminal), authenticated.get("code"))
	return authenticated.get("ok", false)


func _assert_v2(game: Variant, label: String) -> void:
	var snapshot: Dictionary = game.export_snapshot()
	var keys: Array = snapshot.keys()
	var expected: Array = Campaign.SAVE_KEYS.duplicate()
	keys.sort()
	expected.sort()
	_check(keys == expected and snapshot.save_version == 2, label + ": snapshot retains exactly the nine v2 keys")
	_round_trip(game, label)


func _test_legacy_defaults() -> void:
	var game = _fresh()
	_check(game.execute("pwd", 3).get("ok", false) and _selected(game) == 3, "legacy sequence starts with another terminal selected")
	var page: Dictionary = game.browse(HOME)
	_check(page.get("ok", false) and _selected(game) == 0, "one-argument browse keeps terminal0 default")
	_check(page.get("actor") == "anonymous" and page.get("route") == ["local", "archive"],
		"legacy browser keeps its web actor and local transport origin")
	game.execute("pwd", 3)
	var collected: Dictionary = game.collect_web(RECORD)
	_check(collected.get("ok", false) and _selected(game) == 3, "one-argument collect preserves the actual last selected terminal")
	_check(game.get_view(3).get("completed", false), "legacy collect still acquires the actual M01 canonical record")
	observations["legacy_defaults"] = {"browse_terminal": 0, "collect_terminal": _selected(game)}
	_assert_v2(game, "legacy browser/collect")


func _test_explicit_selection_and_pending() -> void:
	var game = _fresh()
	if not _login_ssh(game, "archive.packet.test", "maint", "lumen-47", 0):
		return
	if not _login_ssh(game, "archive.packet.test", "guest", "guest", 1):
		return
	var pending: Dictionary = game.execute("ssh maint@archive.packet.test", 3)
	_check(pending.get("needs_password", false), "a separate terminal has a real unfinished authentication")
	var before: Dictionary = _checkpoint(game)
	var page := _browse(game, HOME, 2)
	var after: Dictionary = _checkpoint(game)
	_check(page.get("ok", false) and _selected(game) == 2, "explicit browse selects terminal2 despite last operation on terminal3")
	_check(page.get("actor") == "anonymous" and page.get("actor_context") == "web" and page.get("cookie_preview") == "",
		"explicit browser never borrows terminal0 SSH authority")
	_check(after.world.terminals["0"] == before.world.terminals["0"] and after.world.terminals["1"] == before.world.terminals["1"],
		"browser selection preserves other authenticated terminal stacks")
	_check(game.get_view(3).get("password_pending", false) and not game.get_view(2).get("password_pending", true),
		"pending authentication stays on terminal3 and does not leak to browser terminal2")
	_check(game.execute("pwd", 1).get("ok", false), "last operation can change to terminal1 after browsing")
	var collected := _collect(game, RECORD, 2)
	_check(collected.get("ok", false) and _selected(game) == 2, "explicit collect uses terminal2 rather than the last operation")
	_check(game.get_view(0).user == "maint" and game.get_view(1).user == "guest" and game.get_view(3).password_pending,
		"collection preserves distinct credentials and another terminal's pending input")
	_check(game.submit_password("lumen-47", 3).get("ok", false), "pending input still accepts its genuine credential after browse and collect")
	var source: Dictionary = game.export_snapshot().current_world.remote_files
	_check(source == before.world.remote_files, "collect preserves the actual remote originals")
	_assert_v2(game, "explicit selection and independent terminal stacks")


func _test_invalid_and_ordinary_failures() -> void:
	var game = _fresh()
	game.execute("ssh guest@archive.packet.test", 1)
	var before: Dictionary = _checkpoint(game)
	for terminal in [-9, -2, -1, 4, 9]:
		var rejected := _browse(game, HOME, terminal)
		_check(rejected.get("code") == "INVALID_TERMINAL" and not rejected.get("ok", true), "invalid browse terminal is rejected: " + str(terminal))
		_check(_same(_checkpoint(game), before), "invalid browse leaves selected terminal, authentication and world unchanged")
	for terminal in [-9, -2, 4, 9]:
		var rejected := _collect(game, RECORD, terminal)
		_check(rejected.get("code") == "INVALID_TERMINAL" and not rejected.get("ok", true), "invalid collect terminal is rejected: " + str(terminal))
		_check(_same(_checkpoint(game), before), "invalid collect leaves selected terminal, authentication and world unchanged")
	for url in ["https://unregistered.invalid", HOME + "/not-registered"]:
		var rejected := _browse(game, url, 2)
		_check(not rejected.get("ok", true), "ordinary browser failure is returned")
		_check(_same(_checkpoint(game), before), "unchanged browser failure rolls back unused terminal2 and retains pending input")
	for url in ["https://unregistered.invalid", HOME]:
		var rejected := _collect(game, url, 2)
		_check(not rejected.get("ok", true), "ordinary collection failure is returned")
		_check(_same(_checkpoint(game), before), "unchanged collection failure rolls back unused terminal2 and retains pending input")
	_check(game.submit_password("guest", 1).get("ok", false), "invalid and ordinary failures preserve the original authentication draft")
	_assert_v2(game, "ordinary and invalid browser failures")


func _test_shared_web_actor_and_vantage() -> void:
	var game = _fresh()
	if not _prepare(game, "M06"):
		return
	if not _login_ssh(game, "auth.packet.test", "shiftlead", "warm-circuit", 0):
		return
	if not _login_ssh(game, "auth.packet.test", "guest", "guest", 1):
		return
	var url := "https://auth.packet.test/context"
	var page := _browse(game, url, 2)
	_check(page.get("status") == 401 and page.get("actor") == "anonymous", "browser terminal2 cannot borrow terminal0's privileged SSH actor")
	_check(game.export_snapshot().current_world.web_sessions.is_empty(), "browsing never turns another terminal's SSH session into a web cookie")
	var no_cookie := _collect(game, url, 1)
	_check(no_cookie.get("code") == "AUTH_REQUIRED" and not no_cookie.get("ok", true), "explicit collect cannot use terminal0 credentials without the target web identity")
	var logged_in: Dictionary = game.request("POST", "https://auth.packet.test/login",
		{"username": "shiftlead", "password": "warm-circuit"}, {"X-Packet-Context": "browser"}, 1)
	_check(logged_in.get("status") == 200, "actual target HTTP login creates a real browser cookie")
	var cookie: Dictionary = game.export_snapshot().current_world.web_sessions.auth.duplicate(true)
	var pending: Dictionary = game.execute("ssh shiftlead@auth.packet.test", 3)
	_check(pending.get("needs_password", false), "cookie fixture retains a distinct unfinished terminal3 login")
	page = _browse(game, url, 2)
	_check(page.get("status") == 200 and page.get("actor") == "shiftlead" and page.get("actor_context") == "web",
		"browser terminal2 uses the actual origin's shared web cookie while its SSH session remains local")
	_check(page.get("cookie_preview") == cookie.token and page.get("route") == ["local", "auth"] and _selected(game) == 2,
		"explicit terminal selection does not change cookie provenance or browser transport vantage")
	var before: Dictionary = _checkpoint(game)
	var no_record := _collect(game, url, 1)
	_check(no_record.get("code") == "NO_RECORD", "authenticated collection applies page semantics rather than pretending this page has a record")
	_check(_same(_checkpoint(game), before), "no-record failure restores the caller's context and retains cookie/pending authentication")
	page = _browse(game, "https://custodym06.packet.test", 0)
	_check(page.get("status") == 503 and page.get("code") == "UNREACHABLE", "browser stays at local vantage even with terminal0 on the required SSH relay")
	_check(_same(_checkpoint(game), before), "unreachable browser request leaves all real authority unchanged")
	_check(game.get_view(3).password_pending and game.submit_password("warm-circuit", 3).get("ok", false),
		"shared web browsing does not consume another terminal's pending password")
	_assert_v2(game, "shared origin cookie and browser vantage")
	var reloaded = Campaign.new(slots[game.get_instance_id()])
	_check(reloaded.load_game().get("ok", false), "shared-cookie fixture loads through the existing save facade")
	page = _browse(reloaded, url, 2)
	_check(page.get("status") == 200 and page.get("cookie_preview") == cookie.token and page.get("actor") == "shiftlead",
		"explicit browser actor/cookie behavior survives the normal v2 disk round-trip")


func _test_archive_capacity_rollback() -> void:
	var game = _fresh()
	var legacy: Dictionary = game.export_snapshot()
	# A valid old saturated input, not injected achievement or an authored solution.
	for index in range(508):
		legacy.current_world.local_files["/home/player/browser_legacy_%03d" % index] = {
			"kind": "dir", "owner": "player", "group": "player", "mode": "700", "content": "", "record_id": "", "source": ""}
	legacy.mission_states.M01 = legacy.current_world.duplicate(true)
	_check(game.restore_snapshot(legacy).get("ok", false), "existing valid512-entry saturation remains loadable")
	game.execute("ssh guest@archive.packet.test", 1)
	var before: Dictionary = _checkpoint(game)
	var rejected := _collect(game, RECORD, 3)
	_check(rejected.get("code") == "ARCHIVE_LIMIT" and not rejected.get("ok", true), "explicit collection preserves the existing shared archive budget")
	_check(_same(_checkpoint(game), before), "archive refusal restores selected terminal, pending authentication and all files")
	_check(game.execute("rmdir ~/browser_legacy_000", 2).get("ok", false), "ordinary deletion can reclaim old loaded capacity")
	_check(_collect(game, RECORD, 3).get("ok", false) and _selected(game) == 3, "reclaimed capacity allows actual canonical collection using explicit terminal3")
	_check(game.get_view(3).completed and game.get_view(1).password_pending, "real record recovery completes M01 without consuming terminal1 authentication")
	_assert_v2(game, "archive capacity recovery")


func _test_snapshot_budget_rollback() -> void:
	var game = _fresh()
	var loaded: Dictionary = game.export_snapshot()
	# Bounded inert observations form a valid size-boundary input, never solution evidence.
	for index in range(32):
		loaded.current_world.observations.append("x".repeat(32768))
	loaded.mission_states.M01 = loaded.current_world.duplicate(true)
	var excess: int = _snapshot_bytes(loaded) - (Store.MAX_BYTES - 128)
	var trimmed: int = 32768 - ceili(float(excess) / 2.0)
	_check(trimmed >= 0 and trimmed <= 32768, "near-limit fixture fits one bounded inert observation", trimmed)
	if trimmed < 0 or trimmed > 32768:
		return
	loaded.current_world.observations[31] = "x".repeat(trimmed)
	loaded.mission_states.M01 = loaded.current_world.duplicate(true)
	var restored: Dictionary = game.restore_snapshot(loaded)
	_check(restored.get("ok", false), "near2MiB snapshot remains a valid loaded state", restored)
	if not restored.get("ok", false):
		return
	var before: Dictionary = _checkpoint(game)
	var result := _collect(game, RECORD, 3)
	_check(result.get("code") == "STATE_BUDGET" and not result.get("ok", true), "explicit collection still uses the complete v2 snapshot budget")
	_check(_same(_checkpoint(game), before), "snapshot-budget rejection restores context, files and completion credit")
	_check(_snapshot_bytes(game.export_snapshot()) <= Store.MAX_BYTES, "budget refusal leaves the active snapshot serializable")
	_assert_v2(game, "near-limit rejected collection")


func _snapshot_bytes(snapshot: Dictionary) -> int:
	return JSON.stringify(snapshot, "", true, true).to_utf8_buffer().size()


func _public_game() -> Variant:
	next_slot += 1
	var path := test_root + "/public_%d.json" % next_slot
	var game = Campaign.new(path, "intruder")
	slots[game.get_instance_id()] = path
	return game


func _test_failed_response_get_side_effects() -> void:
	var loaded: Dictionary = Loader.load_campaign("intruder")
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/perspectives_solutions.json"))
	_check(loaded.get("ok", false) and fixture is Dictionary and fixture.get("packs", {}).get("intruder", {}).get("missions") is Dictionary,
		"public intruder definitions and actual-action fixtures load for failed GET comparison")
	if not loaded.get("ok", false) or not fixture is Dictionary or not fixture.get("packs", {}).get("intruder", {}).get("missions") is Dictionary:
		return
	definition = loaded.definition
	solutions = fixture.packs.intruder.missions
	var prepared = _public_game()
	if not _prepare(prepared, "M24"):
		return
	var snapshot: Dictionary = prepared.export_snapshot()
	var challenge := "in2_m24_response"
	var comparisons: Array[Dictionary] = []
	for status in [401, 200]:
		var url := "https://control.packet.test/tickets/" + ("C731" if status == 401 else "SECRET")
		for terminal in [-1, 2]:
			var label := "HTTP%d terminal%d" % [status, terminal]
			var requested = _public_game()
			var collected = _public_game()
			for game in [requested, collected]:
				_check(game.restore_snapshot(snapshot).get("ok", false), "actual prerequisite-earned M24 snapshot restores without injected progress")
				if status == 200:
					var login: Dictionary = game.request("POST", "https://control.packet.test/login", {"username": "examiner", "password": "final-map"}, {"X-Packet-Context": "browser"})
					_check(login.get("status") == 200 and not game.export_snapshot().current_world.web_sessions.is_empty(), "actual M24 HTTP login earns the examiner cookie")
				_check(game.execute("ssh examiner@control.packet.test", 3).get("needs_password", false), "failed collection fixture retains a real pending terminal3 login")
				# A real browse settles the current terminal's lazy authentication cache equally.
				_check(game.browse("https://control.packet.test", 3).get("ok", false), "fixture browses its real home page without consuming pending input")
			var before: Dictionary = _checkpoint(requested)
			_check(_same(_checkpoint(collected), before), "request and collect begin from identical world, terminal and pending input")
			var request_terminal: int = 3 if terminal == -1 else terminal
			var response: Dictionary = requested.request("GET", url, {}, {"X-Packet-Context": "browser"}, request_terminal)
			var result: Dictionary = collected.collect_web(url) if terminal == -1 else _collect(collected, url, terminal)
			var expected: Dictionary = _checkpoint(requested)
			var actual: Dictionary = _checkpoint(collected)
			_check(response.get("status") == status and response.get("ok", false) == (status == 200) and response.get("changed", false), "actual M24 object GET commits its observation: " + label)
			_check(expected.world.model_actions.get(challenge, []).size() == before.world.model_actions.get(challenge, []).size() + 1,
				"direct GET appends exactly one real response-model receipt")
			_check(not result.get("ok", true) and result.get("code") == (response.get("code") if status == 401 else "NO_RECORD"), "collection returns its actual GET or no-record failure: " + label)
			_check(result.get("changed", false), "failed collect forwards the committed GET change flag: " + label, result.get("code"))
			_check(_same(actual, expected), "failed collect preserves the same GET world, selection and pending input: " + label)
			_check(collected.get_view(3).get("password_pending", false), "failed collection does not consume another terminal's pending authentication")
			_check(not collected.get_view().get("completed", true) and actual.world.remote_files == before.world.remote_files and actual.world.local_files == before.world.local_files,
				"failed collection grants no completion or archive and preserves canonical originals")
			var saved: Dictionary = collected.export_snapshot()
			_check(saved.size() == Campaign.SAVE_KEYS.size() and saved.has_all(Campaign.SAVE_KEYS), "failed GET retains exactly the nine v2 snapshot keys")
			_check(collected.save_game().get("ok", false), "failed collection with a real GET receipt saves through the facade")
			var reloaded = Campaign.new(slots[collected.get_instance_id()], "intruder")
			_check(reloaded.load_game().get("ok", false) and _same(reloaded.export_snapshot(), saved), "failed collection receipt survives the isolated public-pack disk round-trip")
			comparisons.append({"terminal_argument": terminal, "status": response.get("status"), "request_changed": response.get("changed"),
				"collect_changed": result.get("changed"), "request_receipts": expected.world.model_actions.get(challenge, []).size(),
				"collect_receipts": actual.world.model_actions.get(challenge, []).size(), "same_checkpoint": _same(actual, expected)})
	observations["failed_response_get"] = comparisons
