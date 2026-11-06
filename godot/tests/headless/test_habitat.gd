extends RefCounted

const Habitat = preload("res://scripts/core/habitat_store.gd")

var checks := 0
var failures: Array[String] = []
var skipped: Array[String] = []
var root_path := ""


func run() -> Dictionary:
	checks = 0
	failures.clear()
	skipped.clear()
	root_path = "user://tests/habitat_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var protected := _protected_fingerprints()
	_check(DirAccess.make_dir_recursive_absolute(root_path) == OK, "isolated habitat test root exists")
	_test_shop()
	_test_budget_without_job()
	_test_cabinet()
	_test_tampering()
	_test_io_and_recovery()
	_test_fresh_recovery()
	_test_v1_fixture()
	_test_paths()
	_test_cosmetic_history()
	_test_cabinet_history()
	_check(_protected_fingerprints() == protected, "real room/campaign/preferences files remain byte-identical")
	_remove_tree(root_path)
	return {"suite": "habitat", "checks": checks, "failures": failures.duplicate(), "skipped": skipped.duplicate(), "protected_paths": protected.size(), "limit": "Actual isolated room-store disk transactions and finite cabinet logic; native world geometry/input and human game feel are separate."}


func _new(name: String):
	var store = Habitat.new(root_path + "/" + name + ".json")
	_check(store.load_state().ok, "new isolated room state loads: " + name)
	return store


func _test_shop() -> void:
	var store = _new("shop")
	var path := root_path + "/shop.json"
	_check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "missing room state does not write files")
	var view: Dictionary = store.get_view()
	_check(view.ready and view.balance == Habitat.STARTING_CREDITS and view.owned.size() == 3 and view.catalog.size() == 8, "starter credits, three equipped items and fixed eight-item catalog are available")
	_check(store.apply("order", {"product_id": "keyboard_ivory"}).ok, "registered purchase succeeds")
	view = store.get_view()
	_check(view.balance == Habitat.STARTING_CREDITS - 180 and view.ready_delivery_count == 1 and not view.owned.has("keyboard_ivory"), "purchase charges the fixed price once and waits for pickup")
	var snapshot: Dictionary = store.export_snapshot()
	var bytes := FileAccess.get_file_as_bytes(path)
	for input in [{"product_id": "keyboard_ivory"}, {"product_id": "monitor_starter"}, {"product_id": "unknown"}, {"product_id": "keyboard_coral", "price": -999}]:
		_check(not store.apply("order", input).ok, "duplicate, starter, unknown and caller-priced purchases are refused")
		_check(store.export_snapshot() == snapshot and FileAccess.get_file_as_bytes(path) == bytes, "rejected order preserves disk and wallet")
	_check(not store.apply("equip", {"slot": "keyboard", "product_id": "keyboard_ivory"}).ok, "pending delivery cannot be equipped")
	_check(store.apply("collect_delivery").ok, "ready delivery can be collected")
	_check(store.get_view().owned.has("keyboard_ivory") and store.get_view().ready_delivery_count == 0, "pickup creates ownership exactly once")
	_check(not store.apply("collect_delivery").ok and store.get_view().owned.count("keyboard_ivory") == 1, "repeated pickup cannot duplicate ownership")
	_check(store.apply("equip", {"slot": "keyboard", "product_id": "keyboard_ivory"}).ok, "collected keyboard can be equipped")
	_check(store.get_view().equipped.keyboard == "keyboard_ivory", "equipped item is reflected in room state")
	_check(not store.apply("equip", {"slot": "monitor", "product_id": "keyboard_ivory"}).ok, "equipment must match its slot")
	var loaded = Habitat.new(path)
	_check(loaded.load_state().ok and loaded.export_snapshot() == store.export_snapshot(), "room purchases and equipment reload exactly")
	view = store.get_view()
	view["catalog"][1]["price"] = -999
	view.owned.append("monitor_dual")
	_check(store.get_view().catalog[1].price == 180 and not store.get_view().owned.has("monitor_dual"), "returned catalog and ownership do not alias internal state")
	_check(_string_keys(store.export_snapshot()), "canonical snapshot uses JSON String keys throughout")


func _test_budget_without_job() -> void:
	var store = _new("all-cosmetics")
	var catalog: Array = store.get_view().catalog
	var total := 0
	for product in catalog:
		if product.price > 0: total += int(product.price)
	_check(Habitat.STARTING_CREDITS >= total, "starter budget covers every unique current cosmetic without a job reward")
	for product in catalog:
		if product.price > 0:
			_check(store.apply("order", {"product_id": product.id}).ok, "starter credits can purchase each unique cosmetic: " + str(product.id))
			_check(store.get_view().balance >= 0, "cosmetic purchase never creates a negative balance")
	_check(store.apply("collect_delivery").ok, "all optional cosmetic deliveries can be collected without accepting a job")
	for product in catalog:
		_check(store.apply("equip", {"slot": product.slot, "product_id": product.id}).ok, "every current cosmetic can be tried using only starter credits")
	var view: Dictionary = store.get_view()
	_check(view.owned.size() == catalog.size() and view.balance == Habitat.STARTING_CREDITS - total and view.earned == 0 and not view.job.accepted, "all cosmetics remain accessible without mandatory physical work or hidden income")
	var loaded = Habitat.new(root_path + "/all-cosmetics.json")
	_check(loaded.load_state().ok and loaded.export_snapshot() == store.export_snapshot(), "full starter-funded cosmetic collection reloads exactly")


func _test_cabinet() -> void:
	var store = _new("cabinet")
	_check(not store.apply("configure_cabinet", {"route": "service", "locked": true}).ok, "cabinet cannot be changed before accepting its job")
	_check(not store.apply("inspect_cabinet").ok and not store.apply("verify_job").ok, "inspection and verification require the accepted job")
	_check(not store.apply("accept_job", {"job_id": "unknown"}).ok, "arbitrary jobs cannot mint credits")
	_check(store.apply("accept_job", {"job_id": "network_cabinet"}).ok, "optional cabinet job can be accepted")
	_check(not store.apply("configure_cabinet", {"route": "service", "locked": true}).ok, "cabinet is inspected before configuration")
	_check(store.apply("inspect_cabinet").ok, "accepted cabinet can be inspected")
	for config in [{"route": "public", "locked": false}, {"route": "off", "locked": true}, {"route": "public", "locked": true}, {"route": "service", "locked": false}]:
		_check(store.apply("configure_cabinet", config).ok and store.apply("verify_job").ok, "registered cabinet configuration produces a real check")
		var view: Dictionary = store.get_view()
		_check(not view.job.current_check.passed and view.balance == Habitat.STARTING_CREDITS and view.earned == 0, "public exposure, all-off and unlocked service do not earn a reward")
		if config.route == "off": _check(not view.job.current_check.normal_telemetry and not view.job.current_check.unauthorized_access, "all-off blocks legitimate work despite rejecting outsiders")
		if config.route == "public": _check(view.job.current_check.unauthorized_access, "locking the cabinet does not fix a public bypass route")
	_check(store.apply("configure_cabinet", {"route": "service", "locked": true}).ok and store.apply("verify_job").ok, "locked service route preserves telemetry and denies outsiders")
	var view: Dictionary = store.get_view()
	_check(view.job.current_check.passed and view.job.rewarded and view.balance == Habitat.STARTING_CREDITS + Habitat.JOB_REWARD and view.earned == 200, "first valid job check pays exactly two hundred in-game credits")
	var history: Dictionary = view.job.reward_receipt.duplicate(true)
	var actions: int = store.export_snapshot().actions.size()
	_check(store.apply("verify_job").ok and store.export_snapshot().actions.size() == actions and store.get_view().balance == Habitat.STARTING_CREDITS + Habitat.JOB_REWARD, "repeated identical verification is a no-op and cannot farm credits")
	var loaded = Habitat.new(root_path + "/cabinet.json")
	_check(loaded.load_state().ok and loaded.apply("verify_job").ok and loaded.get_view().balance == Habitat.STARTING_CREDITS + Habitat.JOB_REWARD, "reloading and verifying cannot farm a second reward")
	_check(store.apply("configure_cabinet", {"route": "public", "locked": true}).ok, "a previously successful cabinet can be changed")
	view = store.get_view()
	_check(view.job.current_check.is_empty() and view.earned == 200 and view.job.reward_receipt == history, "current check invalidates while the historical earned receipt is preserved")
	_check(store.apply("verify_job").ok and not store.get_view().job.current_check.passed, "changed unsafe configuration fails a new actual check")
	_check(store.apply("configure_cabinet", {"route": "approved_relay", "locked": true}).ok and store.apply("verify_job").ok, "approved relay is a second valid recovery route")
	view = store.get_view()
	_check(view.job.current_check.passed and view.balance == Habitat.STARTING_CREDITS + Habitat.JOB_REWARD and view.job.reward_receipt.route == "service", "second valid route preserves historical reward and does not repay it")
	_check(not store.apply("configure_cabinet", {"route": "host-network", "locked": true}).ok and not store.apply("configure_cabinet", {"route": "service", "locked": "true"}).ok, "configuration is limited to authored routes and boolean lock state")


func _test_tampering() -> void:
	var store = _new("tamper")
	_check(store.apply("order", {"product_id": "keyboard_ivory"}).ok, "seed purchase proof for save validation")
	var valid: Dictionary = store.export_snapshot()
	var variants: Array = []
	var raw := valid.duplicate(true)
	raw["state"]["balance"] += 1
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["earned"] = 200
	raw["state"]["balance"] += 200
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["orders"][0]["price"] = 0
	variants.append(raw)
	raw = valid.duplicate(true)
	raw.state.owned.append("monitor_dual")
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["equipped"]["monitor"] = "monitor_dual"
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["job"]["rewarded"] = true
	raw["state"]["job"]["reward_receipt"] = {"passed": true, "amount": 200}
	variants.append(raw)
	raw = valid.duplicate(true)
	raw.actions.append(raw.actions[0].duplicate(true))
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["actions"][0]["params"]["price"] = 0
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["save_version"] = 2
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["habitat_id"] = "midnight_campaign"
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["balance"] = -1
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["actions"] = [{"action": "verify_job", "params": {}}]
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["state"]["job"]["current_check"] = {"passed": true}
	variants.append(raw)
	raw = valid.duplicate(true)
	raw["campaign_id"] = "midnight"
	variants.append(raw)
	for candidate in variants:
		_check(not store.validate_snapshot(candidate).ok, "fabricated wallet/ownership/receipt/event/schema is rejected")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(valid))
	_check(store.validate_snapshot(roundtrip).ok and store.validate_snapshot(roundtrip).snapshot == valid, "JSON numeric normalization preserves exact logical proof")
	_check(not store.validate_snapshot({"save_version": true, "habitat_id": Habitat.HABITAT_ID, "actions": [], "state": {}}).ok, "boolean save versions are rejected")


func _test_io_and_recovery() -> void:
	var store = _new("io")
	var path := root_path + "/io.json"
	_check(store.apply("order", {"product_id": "keyboard_ivory"}).ok and store.apply("set_lighting", {"lighting": "dawn"}).ok, "seed valid room main and backup")
	var memory: Dictionary = store.export_snapshot()
	var main := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.get_file_as_bytes(path + ".bak")
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "create only an owned staging directory blocker")
	_check(not store.apply("set_lighting", {"lighting": "night"}).ok, "actual staging FileAccess failure rejects the transaction")
	_check(store.export_snapshot() == memory and FileAccess.get_file_as_bytes(path) == main and FileAccess.get_file_as_bytes(path + ".bak") == backup, "failed transaction preserves memory, main and good backup")
	_check(store.get_view().ready and not store.get_view().get("recovery_available", false), "ordinary staging failure leaves the room ready for retry")
	_check(DirAccess.remove_absolute(path + ".tmp") == OK, "remove the owned empty staging blocker")
	_check(store.apply("set_lighting", {"lighting": "night"}).ok, "same room store retries successfully after a temporary IO blocker is removed")
	memory = store.export_snapshot()
	backup = FileAccess.get_file_as_bytes(path + ".bak")
	var damaged := "{ corrupt room state"
	_write(path, damaged)
	var failed: Dictionary = store.apply("order", {"product_id": "lamp_cool"})
	var view: Dictionary = store.get_view()
	_check(not failed.ok and failed.code == "SAVE_RECOVERY_REQUIRED" and not view.ready and view.get("backup_available", false) and view.get("recovery_available", false), "mid-session disk corruption exposes read-only recovery through the current store view")
	_check(view.code == failed.code and view.text == failed.text and store.export_snapshot() == memory, "recovery-required failure is remembered without changing in-memory progress")
	_check(not store.apply("set_lighting", {"lighting": "dawn"}).ok and FileAccess.get_file_as_string(path) == damaged and FileAccess.get_file_as_bytes(path + ".bak") == backup, "later actions preserve the mid-session damaged original and backup")
	var unreadable = Habitat.new(path)
	var loaded: Dictionary = unreadable.load_state()
	_check(not loaded.ok and loaded.get("backup_available", false) and not unreadable.get_view().ready, "corrupt current room is read-only with an explicit recovery option")
	_check(not unreadable.apply("order", {"product_id": "lamp_cool"}).ok and FileAccess.get_file_as_string(path) == damaged and FileAccess.get_file_as_bytes(path + ".bak") == backup, "automatic actions do not overwrite corruption or its good backup")
	var recovered: Dictionary = unreadable.recover_backup()
	_check(recovered.ok and unreadable.get_view().ready and unreadable.get_view().balance == Habitat.STARTING_CREDITS - 180, "explicit backup recovery restores verified prior room state")
	_check(not unreadable.get_view().get("backup_available", true) and not unreadable.get_view().get("recovery_available", true), "successful explicit recovery clears the stale recovery option")
	_check(not str(recovered.get("damaged_path", "")).is_empty() and FileAccess.get_file_as_string(recovered.damaged_path) == damaged, "recovery preserves the damaged original separately")
	_check(FileAccess.get_file_as_bytes(path + ".bak") == backup, "recovery preserves the verified backup")
	var future: Dictionary = unreadable.export_snapshot()
	future["save_version"] = 99
	_write(path, JSON.stringify(future))
	var future_bytes := FileAccess.get_file_as_bytes(path)
	_check(not unreadable.load_state().ok and not unreadable.apply("set_lighting", {"lighting": "dawn"}).ok, "future room versions require recovery instead of default overwrite")
	_check(FileAccess.get_file_as_bytes(path) == future_bytes and FileAccess.get_file_as_bytes(path + ".bak") == backup, "future-version original and backup remain untouched")
	var missing = _new("missing-main")
	var missing_path := root_path + "/missing-main.json"
	_check(missing.apply("order", {"product_id": "lamp_cool"}).ok and missing.apply("set_lighting", {"lighting": "dawn"}).ok, "seed missing-main recovery fixture")
	var missing_backup := FileAccess.get_file_as_bytes(missing_path + ".bak")
	DirAccess.remove_absolute(missing_path)
	var reopened = Habitat.new(missing_path)
	_check(not reopened.load_state().ok and reopened.get_view().balance == Habitat.STARTING_CREDITS and not reopened.get_view().ready, "missing main with recoverable backup exposes starter view without a write")
	_check(not reopened.apply("order", {"product_id": "keyboard_ivory"}).ok and not FileAccess.file_exists(missing_path) and FileAccess.get_file_as_bytes(missing_path + ".bak") == missing_backup, "missing-main recovery cannot be silently replaced by fresh progress")
	_check(reopened.recover_backup().ok and reopened.get_view().balance == Habitat.STARTING_CREDITS - 100, "missing main can be explicitly restored from its known backup")


func _test_fresh_recovery() -> void:
	var healthy = _new("fresh-healthy")
	_check(healthy.has_method("start_fresh"), "locked rooms expose an explicit preserved fresh-start API")
	if not healthy.has_method("start_fresh"): return
	_check(not healthy.start_fresh().ok and not FileAccess.file_exists(root_path + "/fresh-healthy.json"), "healthy unwritten starter room refuses recovery reset without writing")
	_check(healthy.apply("order", {"product_id": "keyboard_ivory"}).ok, "seed healthy saved room for reset refusal")
	var healthy_memory: Dictionary = healthy.export_snapshot()
	var healthy_bytes := FileAccess.get_file_as_bytes(root_path + "/fresh-healthy.json")
	_check(healthy.start_fresh().code == "RECOVERY_NOT_NEEDED" and healthy.export_snapshot() == healthy_memory and FileAccess.get_file_as_bytes(root_path + "/fresh-healthy.json") == healthy_bytes, "healthy saved room refuses reset without losing wallet or bytes")
	for kind in ["corrupt", "future", "orphan-invalid", "orphan-valid", "corrupt-with-backup"]:
		var path: String = root_path + "/fresh-" + kind + ".json"
		var original := "{unreadable room state"
		if kind == "future":
			var future: Dictionary = healthy_memory.duplicate(true)
			future.save_version = 99
			original = JSON.stringify(future)
		var orphan: bool = kind.begins_with("orphan-")
		if not orphan: _write(path, original)
		var backup := "{unreadable backup"
		if kind in ["orphan-valid", "corrupt-with-backup"]: backup = JSON.stringify(healthy_memory)
		if orphan or kind == "corrupt-with-backup": _write(path + ".bak", backup)
		var had_backup := FileAccess.file_exists(path + ".bak")
		var valid_backup: bool = kind in ["orphan-valid", "corrupt-with-backup"]
		var store = Habitat.new(path)
		_check(not store.load_state().ok and store.get_view().get("fresh_available", false) == not valid_backup, "fresh recovery is offered only without a valid room backup: " + kind)
		_check(not store.apply("set_lighting", {"lighting": "dawn"}).ok and FileAccess.file_exists(path) == not orphan, "recovery lock never creates or replaces the primary automatically: " + kind)
		var memory: Dictionary = store.export_snapshot()
		if valid_backup:
			var files := DirAccess.get_files_at(root_path)
			var refused: Dictionary = store.start_fresh()
			_check(not refused.ok and refused.code == "RECOVERY_NOT_NEEDED" and store.export_snapshot() == memory and store.get_view().recovery_available and not store.get_view().fresh_available, "valid room backup requires explicit backup recovery instead of fresh reset: " + kind)
			_check(DirAccess.get_files_at(root_path) == files and (orphan or FileAccess.get_file_as_string(path) == original) and FileAccess.get_file_as_string(path + ".bak") == backup, "refused fresh reset never moves the valid backup or original: " + kind)
			_check(store.recover_backup().ok and store.get_view().balance == 1320 and FileAccess.get_file_as_string(path + ".bak") == backup, "the in-game backup recovery path remains available: " + kind)
			continue
		DirAccess.make_dir_absolute(path + ".tmp")
		_check(not store.start_fresh().ok and store.export_snapshot() == memory and not store.get_view().ready and store.get_view().fresh_available, "failed fresh staging preserves read-only memory and retry option: " + kind)
		_check((orphan or FileAccess.get_file_as_string(path) == original) and (not had_backup or FileAccess.get_file_as_string(path + ".bak") == backup), "failed fresh staging preserves existing original and backup bytes: " + kind)
		DirAccess.remove_absolute(path + ".tmp")
		var started: Dictionary = store.start_fresh()
		_check(started.ok and started.code == "HABITAT_FRESH" and store.get_view().ready and store.get_view().balance == 1500 and not store.get_view().fresh_available and not store.get_view().recovery_available, "explicit fresh recovery persists starter state and clears recovery choices: " + kind)
		_check((orphan and started.damaged_path.is_empty()) or (not orphan and FileAccess.get_file_as_string(started.damaged_path) == original), "fresh recovery preserves the exact prior primary bytes: " + kind)
		_check((not had_backup and started.damaged_backup_path.is_empty()) or (had_backup and FileAccess.get_file_as_string(started.damaged_backup_path) == backup), "fresh recovery preserves the exact prior backup bytes: " + kind)
		var reopened = Habitat.new(path)
		_check(reopened.load_state().ok and reopened.export_snapshot() == store.export_snapshot() and store.apply("set_lighting", {"lighting": "dawn"}).ok, "fresh room reloads and accepts later persisted actions: " + kind)
	var appeared_path := root_path + "/fresh-backup-appeared.json"
	_write(appeared_path, "{damaged before confirmation")
	var waiting = Habitat.new(appeared_path)
	_check(not waiting.load_state().ok and waiting.get_view().fresh_available, "fresh confirmation can be offered before a valid backup appears")
	_write(appeared_path + ".bak", JSON.stringify(healthy_memory))
	var appeared_files := DirAccess.get_files_at(root_path)
	var appeared_backup := FileAccess.get_file_as_bytes(appeared_path + ".bak")
	var declined: Dictionary = waiting.start_fresh()
	_check(not declined.ok and declined.code == "RECOVERY_NOT_NEEDED" and not waiting.get_view().fresh_available and waiting.get_view().recovery_available, "fresh confirmation rechecks disk and prefers a newly available valid backup")
	_check(DirAccess.get_files_at(root_path) == appeared_files and FileAccess.get_file_as_string(appeared_path) == "{damaged before confirmation" and FileAccess.get_file_as_bytes(appeared_path + ".bak") == appeared_backup, "a backup appearing during confirmation leaves both files in place")
	_check(waiting.recover_backup().ok and waiting.get_view().balance == 1320, "backup discovered during confirmation remains recoverable in game")


func _test_v1_fixture() -> void:
	# Published v1 economics are a disk compatibility contract; do not regenerate from current constants.
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/habitat_v1_economy.json")
	var path := root_path + "/published-v1.json"
	_write(path, fixture)
	var store = Habitat.new(path)
	_check(store.load_state().ok, "published v1 room fixture remains loadable across economy changes")
	var view: Dictionary = store.get_view()
	_check(view.balance == 380 and view.earned == 200 and view.owned.size() == 8 and view.orders.size() == 5, "v1 fixture preserves five fixed purchase prices, ownership and one reward")
	_check(view.equipped == {"keyboard": "keyboard_coral", "monitor": "monitor_dual", "lamp": "lamp_cool"} and view.lighting == "dawn", "v1 fixture retains all equipped slots and lighting")
	_check(view.job.rewarded and view.job.reward_receipt.get("route") == "service" and view.job.current_check.is_empty() and view.job.route == "public", "v1 fixture retains historical reward proof after a later cabinet reset")
	_check(FileAccess.get_file_as_string(path) == fixture, "loading a v1 fixture never rewrites its original bytes")


func _test_paths() -> void:
	for path in ["", "user://saves/slot_01.json", "user://saves/intruder_v2_01.json", "user://settings.json", "res://host.json", "user://tests/../bad.json", "user://tests//bad.json", "user://tests\\bad.json", "user://tests/bad.txt", "user://tests/bad:\n.json"]:
		var store = Habitat.new(path)
		_check(not store.load_state().ok and not store.apply("order", {"product_id": "lamp_cool"}).ok and not store.start_fresh().ok, "invalid/private room paths never fall back to a real user slot, including explicit fresh recovery")
	var target := root_path + "/target.json"
	_write(target, "owned target bytes")
	var before := FileAccess.get_file_as_bytes(target)
	var directory := DirAccess.open(root_path)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = root_path + "/linked-" + str(suffix).replace(".", "_") + ".json"
		var linked: Error = directory.create_link(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(path + suffix))
		if linked != OK:
			if OS.get_name() == "Windows": skipped.append("Windows link fixture requires Developer Mode: " + suffix)
			else: _check(false, "create isolated habitat symlink")
			continue
		var store = Habitat.new(path)
		_check(not store.load_state().ok and not store.apply("order", {"product_id": "lamp_cool"}).ok and not store.start_fresh().ok, "linked main/sidecars are rejected before reading, writing or fresh recovery")
		_check(FileAccess.get_file_as_bytes(target) == before, "habitat link target remains untouched")


func _test_cosmetic_history() -> void:
	var store = _new("cosmetic")
	_check(store.apply("order", {"product_id": "keyboard_ivory"}).ok and store.apply("order", {"product_id": "keyboard_coral"}).ok and store.apply("collect_delivery").ok, "collect two cosmetic choices")
	_check(store.apply("accept_job", {"job_id": "network_cabinet"}).ok and store.apply("inspect_cabinet").ok and store.apply("configure_cabinet", {"route": "approved_relay", "locked": true}).ok and store.apply("verify_job").ok, "seed historical reward before repeated decorating")
	var financial: Dictionary = {"balance": store.get_view().balance, "earned": store.get_view().earned, "owned": store.get_view().owned.duplicate(), "job": store.get_view().job.duplicate(true)}
	for index in 300:
		var equipped: Dictionary = store.apply("equip", {"slot": "keyboard", "product_id": "keyboard_ivory" if index % 2 == 0 else "keyboard_coral"})
		var lighting: Dictionary = store.apply("set_lighting", {"lighting": "night" if index % 2 == 0 else "dawn"})
		_check(equipped.ok and lighting.ok, "normal decorating remains writable beyond a raw 128-event journal")
	var view: Dictionary = store.get_view()
	_check(view.balance == financial.balance and view.earned == financial.earned and view.owned == financial.owned and view.job == financial.job, "three hundred equipment/lighting toggles preserve financial and physical job state")
	_check(store.export_snapshot().actions.size() <= 10, "cosmetic history coalesces to one event per slot and lighting")
	var loaded = Habitat.new(root_path + "/cosmetic.json")
	_check(loaded.load_state().ok and loaded.export_snapshot() == store.export_snapshot(), "coalesced long-term decorating and historical reward replay correctly")
	var events: int = store.export_snapshot().actions.size()
	_check(store.apply("equip", {"slot": "keyboard", "product_id": view.equipped.keyboard}).ok and store.apply("set_lighting", {"lighting": view.lighting}).ok and store.export_snapshot().actions.size() == events, "identical cosmetic choices do not append events")


func _test_cabinet_history() -> void:
	var store = _new("cabinet-history")
	_check(store.apply("accept_job", {"job_id": "network_cabinet"}).ok and store.apply("inspect_cabinet").ok, "seed long-running cabinet job")
	for index in 300:
		var config := {"route": ["public", "off", "service"][index % 3], "locked": false}
		var configured: Dictionary = store.apply("configure_cabinet", config)
		var verified: Dictionary = store.apply("verify_job")
		_check(configured.ok and verified.ok, "cabinet remains configurable and verifiable before its first reward: %d" % index)
		if not configured.ok or not verified.ok: break
	_check(store.get_view().earned == 0 and store.get_view().balance == Habitat.STARTING_CREDITS, "hundreds of failed cabinet checks do not create credits")
	var before_reward = Habitat.new(root_path + "/cabinet-history.json")
	_check(before_reward.load_state().ok and before_reward.export_snapshot() == store.export_snapshot(), "compacted cabinet state and failed current check reload exactly before any reward")
	_check(store.apply("configure_cabinet", {"route": "approved_relay", "locked": true}).ok and store.apply("verify_job").ok, "cabinet remains completable after hundreds of failed checks")
	var receipt: Dictionary = store.get_view().job.reward_receipt.duplicate(true)
	_check(receipt.get("route") == "approved_relay" and receipt.get("passed") == true, "first successful check retains its actual authored reward proof")
	for index in 300:
		var config := {"route": ["public", "off", "approved_relay", "service"][index % 4], "locked": true}
		var configured: Dictionary = store.apply("configure_cabinet", config)
		var verified: Dictionary = store.apply("verify_job")
		_check(configured.ok and verified.ok, "cabinet remains configurable and verifiable after its first reward: %d" % index)
		if not configured.ok or not verified.ok: break
	_check(store.apply("configure_cabinet", {"route": "public", "locked": true}).ok and store.apply("configure_cabinet", {"route": "approved_relay", "locked": true}).ok, "returning to the rewarded configuration still invalidates its old current check")
	var view: Dictionary = store.get_view()
	_check(view.job.current_check.is_empty() and view.job.reward_receipt == receipt and view.earned == Habitat.JOB_REWARD and view.balance == Habitat.STARTING_CREDITS + Habitat.JOB_REWARD, "long cabinet history preserves cleared current check, historical receipt and exactly one payment")
	_check(store.apply("order", {"product_id": "keyboard_ivory"}).ok and store.apply("collect_delivery").ok and store.apply("equip", {"slot": "keyboard", "product_id": "keyboard_ivory"}).ok, "cabinet history cannot lock later purchases, pickup or equipment")
	var snapshot: Dictionary = store.export_snapshot()
	_check(snapshot.actions.size() <= 12 and store.validate_snapshot(snapshot).ok, "cabinet history remains bounded and fully replayable without checkpoints")
	var forged: Dictionary = snapshot.duplicate(true)
	for index in forged.actions.size():
		if forged.actions[index].action == "verify_job":
			forged.actions.remove_at(index)
			break
	_check(not store.validate_snapshot(forged).ok, "compacted reward receipt still requires its successful verification event")
	forged = snapshot.duplicate(true)
	for index in forged.actions.size():
		if forged.actions[index].action == "configure_cabinet":
			forged.actions.remove_at(index)
			break
	_check(not store.validate_snapshot(forged).ok, "compacted reward receipt still requires the configuration that earned it")
	var redundant: Dictionary = snapshot.duplicate(true)
	for index in 3:
		redundant.actions.append({"action": "configure_cabinet", "params": {"route": redundant.state.job.route, "locked": redundant.state.job.locked}})
	_check(store.validate_snapshot(redundant).ok, "existing schema accepts replay-equivalent repeated configuration events")
	var redundant_path := root_path + "/redundant-cabinet.json"
	_write(redundant_path, JSON.stringify(redundant))
	var redundant_loaded = Habitat.new(redundant_path)
	_check(redundant_loaded.load_state().ok and redundant_loaded.apply("set_lighting", {"lighting": "dawn"}).ok and redundant_loaded.get_view().job.current_check.is_empty(), "redundant legacy configuration events cannot erase current-check invalidation during compaction")
	var loaded = Habitat.new(root_path + "/cabinet-history.json")
	_check(loaded.load_state().ok and loaded.export_snapshot() == snapshot, "long cabinet history reloads the exact canonical state and proof")
	var balance: int = loaded.get_view().balance
	_check(loaded.apply("verify_job").ok and loaded.get_view().balance == balance and loaded.get_view().earned == Habitat.JOB_REWARD and loaded.get_view().job.reward_receipt == receipt, "verification after long-history reload cannot pay a second reward")
	var legacy = _new("full-cabinet-journal")
	_check(legacy.apply("accept_job", {"job_id": "network_cabinet"}).ok and legacy.apply("inspect_cabinet").ok, "seed a legacy full journal without changing its save format")
	var full: Dictionary = legacy.export_snapshot()
	for index in Habitat.MAX_ACTIONS - full.actions.size():
		var route: String = "off" if index % 2 == 0 else "public"
		full.actions.append({"action": "configure_cabinet", "params": {"route": route, "locked": false}})
		full.state.job.route = route
	_check(full.actions.size() == Habitat.MAX_ACTIONS and legacy.validate_snapshot(full).ok, "legacy 128-event cabinet journal remains valid under existing schema and bounds")
	_write(root_path + "/full-cabinet-journal.json", JSON.stringify(full))
	var reopened = Habitat.new(root_path + "/full-cabinet-journal.json")
	_check(reopened.load_state().ok and reopened.apply("verify_job").ok and reopened.apply("order", {"product_id": "lamp_cool"}).ok, "an already full valid journal compacts on its next action and keeps the shop writable")


func _protected_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for path in [Habitat.PATH, "user://saves/slot_01.json", "user://saves/campaign_01.json", "user://saves/intruder_v2_01.json", "user://saves/defender_01.json", "user://saves/tracker_01.json", "user://saves/challenge_01.json", "user://saves/investigation_01.json", "user://settings.json"]:
		for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
			var file: String = path + suffix
			result[file] = FileAccess.get_sha256(file) if FileAccess.file_exists(file) else "missing"
	return result


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "write only owned test fixture")
	if file != null:
		file.store_string(text)
		file.close()


func _remove_tree(path: String) -> void:
	if not path.begins_with(root_path): return
	var directory := DirAccess.open(path)
	if directory == null: return
	for name in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		if directory.is_link(name): DirAccess.remove_absolute(path.path_join(name))
		else: _remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


func _string_keys(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not key is String or not _string_keys(value[key]): return false
	elif value is Array:
		for entry in value:
			if not _string_keys(entry): return false
	return true


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
