extends RefCounted
## Functional metadata/scene regression, not physical input or native visual acceptance.
const RoomScene = preload("res://scenes/room.tscn")
const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const Settings = preload("res://scripts/presentation/settings_store.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const Localization = preload("res://scripts/presentation/localization.gd")
const SafeFixtures = preload("res://tests/headless/test_support_settings.gd")

var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var tree: SceneTree
var test_root := ""
var fixture_helper: RefCounted


func run(scene_tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	observations.clear()
	tree = scene_tree
	test_root = "user://tests/lobby_preferences_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	fixture_helper = SafeFixtures.new()
	fixture_helper.root_path = test_root
	var protected: Dictionary = fixture_helper._fingerprints()
	var locale := TranslationServer.get_locale()
	var audio := {}
	for index in AudioServer.bus_count: audio[index] = AudioServer.get_bus_volume_db(index)
	_check(DirAccess.make_dir_recursive_absolute(test_root) == OK, "fixture creates only an owned test tree")
	await _unreadable_preferences("damaged", "{ corrupted original preferences".to_utf8_buffer())
	await _unreadable_preferences("newer", JSON.stringify({"version": 99, "values": {"locale": "ja", "music_volume": 0.31, "font_scale": 1.42}, "future": "keep this document"}).to_utf8_buffer())
	await _session_preference_panel()
	await _cross_pack_preference()
	Localization.set_locale(locale)
	for index in audio: AudioServer.set_bus_volume_db(index, audio[index])
	_check(fixture_helper._fingerprints() == protected, "all 28 real preference/campaign paths retain original bytes and path types")
	fixture_helper._remove_owned(test_root)
	_check(not DirAccess.dir_exists_absolute(test_root), "only this unique test tree is cleaned")
	return {"suite": "lobby_preferences", "checks": checks, "failures": failures.duplicate(), "protected_paths": protected.size(), "observations": observations.duplicate(true),
		"limit": "Real Room/Desktop/SettingsPanel functional methods and metadata controls with isolated IO. Not OS mouse/keyboard, pixel or physical IME acceptance."}


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)


func _write_owned(path: String, bytes: PackedByteArray) -> void:
	_check(path.begins_with(test_root + "/"), "fixture write is confined to the unique test tree")
	if not path.begins_with(test_root + "/"): return
	_check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "fixture creates owned parents")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture opens its owned file")
	if file == null: return
	_check(file.store_buffer(bytes), "fixture stores explicit bytes")
	file.close()


func _valid_preferences() -> PackedByteArray:
	return JSON.stringify({"version": 1, "values": {"locale": "en", "music_volume": 0.27, "font_scale": 1.25,
		"support_intruder": "standard", "support_defender": "standard", "support_tracker": "standard"}}, "", true, true).to_utf8_buffer()


func _room_fixture(settings_path: String, name: String) -> Node3D:
	# White-box setup is restricted to construction and safe integration plumbing.
	var room: Node3D = RoomScene.instantiate()
	room.settings_path = settings_path
	room.desktop_scene = DesktopScene
	for pack in Catalog.list_all_packs(true):
		var path: String = Catalog.test_slot(test_root + "/" + name + "/campaign.json", pack.id)
		_check(path.begins_with(test_root + "/"), "all real campaign slots are injected before Room enters the tree")
		room.campaign_slots[pack.id] = path
	room.desktop_save_slot_path = room.campaign_slots.intruder
	room.set_campaigns(Catalog.list_packs())
	# Same support delivery as FullGame._on_settings; audio/title are outside this regression.
	room.settings_changed.connect(func(values: Dictionary):
		if is_instance_valid(room.desktop): room.desktop.apply_settings(room.presentation_settings(values)))
	tree.root.add_child(room)
	await tree.process_frame
	await tree.process_frame
	_check(room.settings_store.get("_path") == settings_path, "real Room retains the explicit isolated preference path")
	return room


func _start(room: Node3D, pack: String, level: String, action: String = "new") -> bool:
	_check(room.select_campaign(pack), "functional role selection uses a real catalog entry")
	_check(room.select_support(level), "functional support selection uses a declared enum")
	room.open_desktop(action, pack, level)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var active: bool = is_instance_valid(room.desktop) and room.desktop.session_active
	_check(active, "real desktop session starts without injected progress flags")
	if not active: return false
	_check(str(room.desktop.game.get("_save_path")).begins_with(test_root + "/"), "real game writes only its injected test campaign slot")
	return true


func _close_room(room: Node3D) -> void:
	room.queue_free()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame


func _unreadable_preferences(id: String, original: PackedByteArray) -> void:
	var path := test_root + "/m1_" + id + "/preferences.json"
	var good_backup := _valid_preferences()
	_write_owned(path, original)
	_write_owned(path + ".bak", good_backup)
	var room := await _room_fixture(path, "m1_" + id)
	if id == "damaged":
		room.set_legacy_session_available(true)
		_check(room.import_button.visible, "legacy import becomes visible when availability arrives after initial menu creation")
		room.set_legacy_session_available(false)
		_check(not room.import_button.visible, "legacy import hides again when its source becomes unavailable")
	_check(room.settings_store.get_values().support_intruder == "standard", "failed preference read leaves a safe in-memory support default")
	if await _start(room, "intruder", "guided"):
		_check(room.desktop.support_mode == "guided" and room.presentation_settings().support_intruder == "guided", "M1 unreadable preferences still allow the selected session-only guidance: " + id)
		_check(FileAccess.get_file_as_bytes(path) == original, "M1 automatic support selection preserves unreadable original bytes: " + id)
		_check(FileAccess.get_file_as_bytes(path + ".bak") == good_backup, "M1 automatic support selection preserves the prior valid custom backup: " + id)
		_check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak.tmp"), "M1 lobby does not stage an automatic replacement after failed read: " + id)
		var parser := JSON.new()
		var parsed := parser.parse(FileAccess.get_file_as_string(path + ".bak"))
		var backup: Variant = parser.data if parsed == OK else null
		_check(backup is Dictionary and backup.get("values", {}).get("locale") == "en" and backup.get("values", {}).get("music_volume") == 0.27 and backup.get("values", {}).get("font_scale") == 1.25, "M1 valid backup retains actual custom language/audio/font settings: " + id)
		observations.append({"case": "M1_" + id, "original_preserved": FileAccess.get_file_as_bytes(path) == original, "backup_preserved": FileAccess.get_file_as_bytes(path + ".bak") == good_backup, "session_support": room.desktop.support_mode})
	await _close_room(room)


func _session_preference_panel() -> void:
	var path := test_root + "/m3_panel/preferences.json"
	var original := _valid_preferences()
	_write_owned(path, original)
	var room := await _room_fixture(path, "m3_panel")
	_check(room.settings_store.get_values().locale == "en" and room.settings_store.get_values().music_volume == 0.27, "M3 starts from a genuinely loaded non-default preferences file")
	# Add the blocker after load: before _ready it would conflate M3 with M1.
	_check(DirAccess.make_dir_absolute(path + ".bak.tmp") == OK, "M3 real directory blocker prevents the automatic write")
	if not await _start(room, "intruder", "guided"):
		await _close_room(room)
		return
	_check(room.desktop.support_mode == "guided" and room.settings_store.get_values().support_intruder == "standard", "M3 failed auto-persistence applies session guidance without faking stored values")
	_check(FileAccess.get_file_as_bytes(path) == original, "M3 actual automatic write failure preserves the normal original")
	var before: Dictionary = room.desktop.game.export_snapshot()
	_check(DirAccess.remove_absolute(path + ".bak.tmp") == OK, "M3 removes only its owned failure blocker")
	room.show_settings()
	await tree.process_frame
	var panel: PanelContainer = room.settings_panel
	_check(is_instance_valid(panel), "M3 opens the real Room SettingsPanel")
	if is_instance_valid(panel):
		var support: OptionButton = panel.controls.support_intruder
		var displayed: String = str(support.get_item_metadata(support.selected))
		_check(displayed == "guided", "M3 settings initially show the effective session support, not the stale stored standard")
		var header: TabBar = panel.tabs.get_tab_bar()
		var reached := false
		for index in range(14):
			if tree.root.gui_get_focus_owner() == header:
				reached = true
				break
			await _key(KEY_TAB)
		_check(reached, "settings keyboard Tab cycle reaches the real category header")
		if reached:
			var initial: int = panel.tabs.current_tab
			await _key(KEY_RIGHT)
			_check(panel.tabs.current_tab != initial, "real category header changes settings tabs with the keyboard")
		var music: HSlider = panel.controls.music_volume
		music.value = 0.19
		panel._apply()
		await tree.process_frame
		await tree.process_frame
		_check(room.presentation_settings().support_intruder == "guided" and room.desktop.support_mode == "guided", "M3 applying only an audio change preserves effective guidance")
		var stored := Settings.new(path)
		var loaded: Dictionary = stored.load_settings()
		_check(loaded.get("ok", false) and stored.get_values().support_intruder == "guided" and stored.get_values().music_volume == 0.19, "M3 explicit Apply persists the guidance shown to the player with the requested audio value")
		_check(room.desktop.game.export_snapshot().recursive_equal(before, 0), "M3 preference Apply preserves the complete strict campaign world")
		observations.append({"case": "M3_panel", "initial_support": displayed, "session_support": room.desktop.support_mode, "stored_support": stored.get_values().support_intruder, "stored_music": stored.get_values().music_volume})
	await _close_room(room)


func _cross_pack_preference() -> void:
	var path := test_root + "/m3_cross/preferences.json"
	_write_owned(path, _valid_preferences())
	var room := await _room_fixture(path, "m3_cross")
	_check(DirAccess.make_dir_absolute(path + ".bak.tmp") == OK, "cross-pack fixture blocks only the first support write")
	if not await _start(room, "intruder", "guided"):
		await _close_room(room)
		return
	var first_desktop: Control = room.desktop
	var before: Dictionary = first_desktop.game.export_snapshot()
	_check(room.presentation_settings().support_intruder == "guided" and room.settings_store.get_values().support_intruder == "standard", "cross-pack A has a genuine unsaved session-only preference")
	_check(DirAccess.remove_absolute(path + ".bak.tmp") == OK, "cross-pack fixture permits the later independent write")
	if await _start(room, "defender", "independent"):
		_check(room.settings_store.get_values().support_defender == "independent", "cross-pack B actually persists its support")
		_check(room.presentation_settings().support_intruder == "guided", "cross-pack B persistence never clears A's effective unsaved guidance")
		_check(room.desktop.support_mode == "independent", "cross-pack B uses its independently chosen guidance")
		if await _start(room, "intruder", "guided", "continue"):
			_check(room.desktop == first_desktop and room.desktop.support_mode == "guided", "returning to A reuses its real session with retained guidance")
			_check(room.desktop.game.export_snapshot().recursive_equal(before, 0), "cross-pack preference commits do not alter A's campaign world")
		observations.append({"case": "M3_cross_pack", "effective_intruder": room.presentation_settings().support_intruder, "stored_defender": room.settings_store.get_values().support_defender})
	await _close_room(room)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame
