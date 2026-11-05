extends RefCounted
## Functional UI context transitions with real scenes/core and isolated slots; not native input.

const RoomScene = preload("res://scenes/room.tscn")
const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const Bootstrap = preload("res://scripts/full_game.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")

var checks := 0
var failures: Array[String] = []
var _tree: SceneTree
var _test_root := ""
var _room: Node3D
var _callbacks := 0


class AudioSpy extends Node:
	var current_mood := ""
	var transitions: Array[String] = []
	func set_mood(value: String) -> void:
		if value != current_mood:
			current_mood = value
			transitions.append(value)
	func play_ui(_event: String) -> void: pass
	func set_paused(_paused: bool) -> void: pass
	func set_volumes(_values: Dictionary) -> void: pass


func run(tree: SceneTree) -> Dictionary:
	checks = 0
	failures.clear()
	_callbacks = 0
	_tree = tree
	_test_root = "user://tests/ui_context_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var before := _fingerprints()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_root))
	_room = RoomScene.instantiate()
	_room.desktop_scene = DesktopScene
	var entries: Array = []
	for pack in Catalog.list_packs(true):
		_room.campaign_slots[pack.id] = Catalog.test_slot(_test_root + "/session.json", pack.id)
		if pack.id != "legacy_intruder":
			var entry: Dictionary = pack.duplicate(true)
			entry["disk_available"] = pack.id == "intruder"
			entries.append(entry)
	for id in ["intruder", "legacy_intruder"]:
		var game = Campaign.new(_room.campaign_slots[id], id)
		_check(game.save_game().get("ok", false), "isolated initial save: " + id)
	_tree.root.add_child(_room)
	_room.set_campaigns(entries)
	await _tree.process_frame
	_test_active_resume()
	_test_menu_load()
	_test_retained_confirmation()
	_test_audio_context()
	_room.queue_free()
	await _tree.process_frame
	await _tree.process_frame
	_check(_fingerprints() == before, "default settings and all campaign slots/backups unchanged")
	_cleanup(_test_root)
	return {"checks": checks, "failures": failures.duplicate(), "protected_paths": before.size(),
		"limit": "Headless functional scene methods and audio-routing spy; no native input, rendering, hearing, or default-slot writes."}


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _press_computer() -> void:
	_room.camera.global_position = _room.studio.computer_position + Vector3(0, 0, 2)
	_room.camera.look_at(_room.studio.computer_position)
	_check(_room._can_use_computer(), "functional E probe faces nearby computer")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	_room._unhandled_key_input(key)


func _test_active_resume() -> void:
	_room.open_desktop("legacy")
	var desktop: Control = _room.desktop
	var game = desktop.game
	var slot: String = desktop.save_slot_path
	desktop.terms[0].input.text = "unsaved legacy terminal draft"
	_room.return_to_room()
	_press_computer()
	_check(_room.desktop == desktop, "F10/E resumes actual legacy desktop instance")
	_check(_room.desktop.game == game, "F10/E preserves actual legacy core instance")
	_check(_room.desktop.pack_id == "legacy_intruder" and _room.desktop.save_slot_path == slot,
		"F10/E preserves legacy pack and isolated slot")
	_check(desktop.terms[0].input.text == "unsaved legacy terminal draft", "F10/E preserves unsaved legacy draft")
	_check(not _room._desktops.has("intruder"), "legacy E resume does not create a public desktop")
	_room.show_main_menu()
	_room.select_campaign("intruder")
	_room.open_desktop("continue")
	_check(_room.desktop.pack_id == "intruder" and _room.desktop != desktop,
		"explicit public menu choice still switches campaign")


func _test_menu_load() -> void:
	var desktop: Control = _room.desktop
	desktop.autosave_suspended = true
	desktop.terms[0].input.text = "unsaved progress after autosave failure"
	_check(desktop.game.execute("mkdir /home/player/ui_context_unsaved").get("ok", false), "create unsaved virtual directory")
	_check(desktop.game.execute("cd /home/player/ui_context_unsaved").get("ok", false), "enter unsaved virtual directory")
	_room.show_main_menu()
	_room.load_button.pressed.emit()
	_check(_room.confirm.visible, "menu load asks before replacing active memory")
	_check(desktop.game.get_view().cwd == "/home/player/ui_context_unsaved", "menu load preserves unsaved core state until confirmation")
	_check(desktop.terms[0].input.text == "unsaved progress after autosave failure",
		"menu load preserves unsaved draft until confirmation")
	_room.confirm.hide()
	_room.confirm.canceled.emit()
	_check(desktop.terms[0].input.text == "unsaved progress after autosave failure", "cancel load preserves memory")
	_room.load_button.pressed.emit()
	_room.confirm.hide()
	_room.confirm.confirmed.emit()
	_check(_room._in_desktop and desktop.game.get_view().cwd == "/home/player", "confirmed menu load replaces world once")


func _callback() -> void:
	_callbacks += 1


func _test_retained_confirmation() -> void:
	var desktop: Control = _room.desktop
	desktop._ask("Same-session retained prompt", _callback)
	_room.return_to_room()
	_press_computer()
	_check(desktop.confirm.visible and desktop.confirm_action.is_valid(), "same-session resume retains legitimate prompt")
	desktop.confirm.hide()
	desktop._on_confirmed()
	_check(_callbacks == 1, "same-session confirmation invokes its callback once")
	for action in ["new", "load"]:
		desktop._ask("Old-world prompt", _callback)
		_room.show_main_menu()
		_room.open_desktop(action)
		_check(not desktop.confirm.visible, action + " does not restore a previous-world Window")
		_check(not desktop.confirm_action.is_valid(), action + " invalidates previous-world callback")
		desktop._on_confirmed()
		_check(_callbacks == 1, action + " rejects a late previous-world confirmation")
		desktop.confirm.hide()


func _test_audio_context() -> void:
	var desktop: Control = _room.desktop
	var bootstrap = Bootstrap.new()
	var spy := AudioSpy.new()
	bootstrap.room = _room
	bootstrap.audio = spy
	bootstrap.save_slot_path = _test_root + "/session.json"
	bootstrap._on_desktop_requested("continue")
	var view := {"ready": true, "campaign": {"id": "intruder"}, "mission_id": "S02",
		"completed": false, "alert_level": 0, "ending": {"id": "chosen"}}
	bootstrap._on_view_changed(view, desktop)
	_check(spy.current_mood == "investigate", "historical ending does not pin optional-case mood")
	bootstrap._on_campaign_finished(view.ending, desktop)
	_check(spy.current_mood == "ending", "actual ending choice starts finale")
	var count := spy.transitions.count("ending")
	bootstrap._on_view_changed(view, desktop)
	_check(spy.transitions.count("ending") == count, "repeated ending view does not restart one-shot")
	view.alert_level = 1
	bootstrap._on_view_changed(view, desktop)
	_check(spy.current_mood == "alert", "new alert interrupts historical finale context")
	view.alert_level = 0
	bootstrap._on_view_changed(view, desktop)
	_check(desktop.has_signal("presentation_context_changed"), "desktop exposes actual foreground presentation context")
	if desktop.has_signal("presentation_context_changed"):
		desktop._open_app("ending", true)
		_check(spy.current_mood == "ending", "explicit credits reopening starts finale")
		count = spy.transitions.count("ending")
		desktop._open_app("ending", true)
		bootstrap._on_view_changed(view, desktop)
		_check(spy.transitions.count("ending") == count, "same credits context and repeated views play once")
		desktop._open_app("board", true)
		_check(spy.current_mood == "investigate", "leaving credits for board restores case mood")
		desktop._open_app("ending", true)
	_room.return_to_room()
	bootstrap._on_room_entered()
	_press_computer()
	bootstrap._on_desktop_requested("continue")
	bootstrap._on_view_changed(view, desktop)
	_check(spy.current_mood != "ending", "F10/E does not replay a historical finale")
	desktop._close("board")
	_check(spy.current_mood != "ending", "closing a background app does not reopen historical credits context")
	bootstrap.free()
	spy.free()


func _fingerprints() -> Dictionary:
	var result := {}
	var paths: Array[String] = ["user://settings.json", Catalog.LEGACY_SOURCE, "user://saves/slot_01.json"]
	for pack in Catalog.list_packs(true):
		paths.append(Catalog.default_slot(pack.id))
	for path in paths:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var full: String = path + suffix
			result[full] = FileAccess.get_sha256(full) if FileAccess.file_exists(full) else "MISSING"
	var directory := DirAccess.open("user://saves")
	if directory != null:
		for filename in directory.get_files():
			result["user://saves/" + filename] = "SYMLINK" if directory.is_link(filename) else FileAccess.get_sha256("user://saves/" + filename)
	return result


func _cleanup(path: String) -> void:
	if not path.begins_with(_test_root) or not _test_root.begins_with("user://tests/ui_context_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(path)
