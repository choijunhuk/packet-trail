extends Node
## Connect the room, the virtual desktop and presentation. All game rules stay in CampaignGame.

const RoomScene = preload("res://scenes/room.tscn")
const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const Locale = preload("res://scripts/presentation/localization.gd")
const ManualProfileStore = preload("res://scripts/core/manual_profile_store.gd")
const ManualSavePanel = preload("res://scripts/presentation/manual_save_panel.gd")
const Habitat = preload("res://scripts/core/habitat_store.gd")
const DesktopEffects = preload("res://scripts/presentation/desktop_effects.gd")

## Empty selects fixed product slots; a nonempty base must resolve only to tests slots.
@export var save_slot_path := ""
var legacy_source_override := ""
var room: Node3D
var audio: Node
var _last_view: Dictionary = {}
var _connected_desktops: Dictionary = {}
var _ending_presenting := false
var _shutting_down := false
var manual_store: RefCounted
var manual_profile_result: Dictionary = {}
var desktop_effects: Node
var _campaign_paths: Dictionary = {}
var _profile_active := false
var _manual_scrim: ColorRect
var _manual_focus_target: Control
var _story_effects_seen: Dictionary = {}


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# Test overrides must be validated before any settings, household or campaign IO.
	if not save_slot_path.is_empty() and Catalog.test_slot(save_slot_path, "intruder").is_empty():
		manual_profile_result = {"ok": false, "code": "INVALID_TEST_ROOT", "text": "Invalid isolated save root."}
		push_error("Invalid campaign test slot override; no default user slot was selected.")
		return
	manual_store = ManualProfileStore.new("user://profiles" if save_slot_path.is_empty() else save_slot_path.get_basename() + "_profiles")
	if not legacy_source_override.is_empty() and (save_slot_path.is_empty() or Catalog.test_slot(legacy_source_override, "legacy_intruder").is_empty()):
		manual_profile_result = {"ok": false, "code": "INVALID_LEGACY_SOURCE", "text": "Legacy test source must remain isolated."}
		return
	manual_profile_result = manual_store.resolve_paths()
	_profile_active = bool(manual_profile_result.get("active", false)) and bool(manual_profile_result.get("ok", false))
	if _profile_active:
		_campaign_paths = manual_profile_result.campaign_slots.duplicate(true)
	audio = AudioDirector.new()
	audio.name = "Score"
	add_child(audio)
	desktop_effects = DesktopEffects.new()
	desktop_effects.name = "DesktopEffects"
	add_child(desktop_effects)
	room = RoomScene.instantiate()
	room.name = "Studio"
	room.desktop_scene = DesktopScene
	room.legacy_source_override = legacy_source_override
	if not save_slot_path.is_empty():
		room.settings_path = save_slot_path.get_basename() + "_preferences.json"
		room.habitat_path = save_slot_path.get_basename() + "_habitat.json"
	if _profile_active:
		room.habitat_path = str(manual_profile_result.habitat_path)
		room.allow_legacy_auto_import = false
	room.profile_recovery_required = not bool(manual_profile_result.get("ok", false))
	room.profile_recovery_code = str(manual_profile_result.get("code", ""))
	for pack in Catalog.list_all_packs(true):
		var id := str(pack["id"])
		var slot := _slot_for(id)
		if slot.is_empty():
			push_error("Invalid campaign test slot override; no default user slot was selected.")
			return
		room.campaign_slots[id] = slot
	room.desktop_save_slot_path = _slot_for("intruder")
	room.settings_changed.connect(_on_settings)
	room.settings_applying.connect(desktop_effects.cancel)
	room.application_focus_changed.connect(audio.set_background_active)
	room.desktop_requested.connect(_on_desktop_requested)
	room.room_entered.connect(_on_room_entered)
	room.campaign_selected.connect(_on_campaign_selected)
	room.quit_requested.connect(request_shutdown)
	room.manual_saves_requested.connect(show_manual_saves)
	room.desktop_effects_preview_requested.connect(_on_desktop_effects_preview)
	add_child(room)
	# Input is dispatched from the last child first; active effects own Escape.
	move_child(desktop_effects, -1)
	audio.configure(room.settings_store.get_values())
	desktop_effects.configure(room.settings_store.get_values())
	audio.set_mood("home")
	_refresh_save_status()
	_update_title()
	if room.profile_recovery_required:
		show_manual_saves.call_deferred()
	elif _profile_active:
		_select_profile_pack(manual_profile_result.get("context", {}))
		_refresh_save_status()
		room.show_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_shutdown()


func request_shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	if is_instance_valid(desktop_effects):
		desktop_effects.cancel()
	set_process_input(false)
	if is_instance_valid(room):
		room.process_mode = Node.PROCESS_MODE_DISABLED
	var players: Array[Node] = []
	if is_instance_valid(audio):
		audio.process_mode = Node.PROCESS_MODE_DISABLED
		players = audio.find_children("*", "AudioStreamPlayer", true, false)
	for player in players:
		player.stop()
	var tree := get_tree()
	for index in range(3):
		await tree.process_frame
	for player in players:
		if is_instance_valid(player):
			player.stream = null
	if is_instance_valid(audio):
		audio.queue_free()
		audio = null
	for index in range(4):
		await tree.process_frame
	await tree.create_timer(0.2).timeout
	tree.quit()


func _refresh_save_status() -> void:
	var entries: Array = []
	for pack in Catalog.list_packs():
		var id := str(pack["id"])
		if room.profile_recovery_required:
			var unavailable: Dictionary = pack.duplicate(true)
			unavailable.merge({"disk_available": false, "can_continue": false, "save_state": "recovery", "progress": {}})
			entries.append(unavailable)
			continue
		var probe = Campaign.new(_slot_for(id), id)
		var status: Dictionary = probe.get_save_status()
		var cached = room.get_cached_desktop(id)
		var memory_active := is_instance_valid(cached) and bool(cached.get("session_active"))
		var view: Dictionary = cached.get_game_view() if memory_active else {}
		if not memory_active and bool(status.get("valid", false)):
			var loaded: Dictionary = probe.load_game()
			if bool(loaded.get("ok", false)):
				view = probe.get_view()
			else:
				status["valid"] = false
		var entry: Dictionary = pack.duplicate(true)
		entry["disk_available"] = bool(status.get("exists", false)) or bool(status.get("backup_available", false))
		entry["can_continue"] = memory_active or entry["disk_available"]
		entry["save_state"] = "memory" if memory_active else ("saved" if bool(status.get("valid", false)) else ("recovery" if entry["can_continue"] else "empty"))
		entry["progress"] = view.get("campaign_progress", {})
		entries.append(entry)
	room.set_campaigns(entries)
	room.desktop_save_slot_path = _slot_for(room.selected_pack_id)
	if room.profile_recovery_required:
		room.set_legacy_campaign_available(false)
		room.set_legacy_session_available(false)
		room.set_legacy_source_available(false)
		return
	var legacy = Campaign.new(_slot_for("legacy_intruder"), "legacy_intruder")
	var legacy_status: Dictionary = legacy.get_save_status(save_slot_path.is_empty() or not legacy_source_override.is_empty(), legacy_source_override)
	var cached_legacy = room.get_cached_desktop("legacy_intruder")
	var legacy_memory := is_instance_valid(cached_legacy) and bool(cached_legacy.get("session_active"))
	var can_resume_legacy := legacy_memory or bool(legacy_status.get("exists", false)) or bool(legacy_status.get("backup_available", false)) or (not _profile_active and bool(legacy_status.get("legacy_source_available", false)))
	var legacy_problem := ""
	if not can_resume_legacy and bool(legacy_status.get("legacy_source_exists", false)) and not bool(legacy_status.get("legacy_source_available", false)):
		legacy_problem = room._text("LEGACY_SOURCE_UNSUPPORTED", {"code": legacy_status.get("legacy_source_reason", "UNKNOWN")})
	room.set_legacy_campaign_available(can_resume_legacy, legacy_problem)
	room.set_legacy_session_available(bool(legacy_status.get("legacy_available", false)))
	room.set_legacy_source_available(_profile_active and bool(legacy_status.get("legacy_source_available", false)) and not bool(legacy_status.get("exists", false)) and not bool(legacy_status.get("backup_exists", false)))


func _slot_for(id: String) -> String:
	if _profile_active:
		return str(_campaign_paths.get(id, ""))
	return Catalog.default_slot(id) if save_slot_path.is_empty() else Catalog.test_slot(save_slot_path, id)


func _on_campaign_selected(_id: String) -> void:
	_refresh_save_status()


func _on_settings(values: Dictionary) -> void:
	audio.set_volumes(values)
	if is_instance_valid(desktop_effects):
		desktop_effects.configure(values)
	if is_instance_valid(room.desktop) and room.desktop.has_method("apply_settings"):
		room.desktop.apply_settings(room.presentation_settings(values))
	_update_title()


func _update_title() -> void:
	get_window().title = Locale.tr_key("ROOM_TITLE") + " · " + str(ProjectSettings.get_setting("application/config/version", "1.0.0-rc1"))


func _on_desktop_requested(_action: String) -> void:
	var desktop: Control = room.desktop
	_ending_presenting = false
	if not _connected_desktops.has(desktop.get_instance_id()):
		_connected_desktops[desktop.get_instance_id()] = true
		if desktop.has_signal("view_changed"):
			desktop.view_changed.connect(_on_view_changed.bind(desktop))
		if desktop.has_signal("return_to_room_requested"):
			desktop.return_to_room_requested.connect(_on_return_requested.bind(desktop))
		if desktop.has_signal("campaign_finished"):
			desktop.campaign_finished.connect(_on_campaign_finished.bind(desktop))
		if desktop.has_signal("presentation_context_changed"):
			desktop.presentation_context_changed.connect(_on_presentation_context_changed.bind(desktop))
		if desktop.has_signal("pause_changed"):
			desktop.pause_changed.connect(_on_pause_changed.bind(desktop))
		if desktop.has_signal("action_performed"):
			desktop.action_performed.connect(_on_action_performed.bind(desktop))
		if desktop.has_signal("settings_requested"):
			desktop.settings_requested.connect(_on_settings_requested.bind(desktop))
		if desktop.has_signal("manual_saves_requested"):
			desktop.manual_saves_requested.connect(show_manual_saves)
	if desktop.has_method("apply_settings"):
		desktop.apply_settings(room.presentation_settings())
	if desktop.has_method("get_game_view"):
		_on_view_changed(desktop.get_game_view(), desktop)
	_refresh_save_status()


func _on_view_changed(view: Dictionary, source: Control = null) -> void:
	if source != null and (source != room.desktop or not room._in_desktop):
		return
	if not bool(view.get("ready", false)):
		return
	var ending: Variant = view.get("ending", "")
	var has_ending: bool = (ending is Dictionary and not ending.is_empty()) or (ending is String and not ending.is_empty())
	var mission := str(view.get("mission_id", "M01"))
	var alert := int(view.get("alert_level", 0))
	var completed := bool(view.get("completed", false))
	var campaign: Dictionary = view.get("campaign", {})
	if str(_last_view.get("campaign", {}).get("id", "")) != str(campaign.get("id", "")):
		_last_view = {}
		_ending_presenting = false
	if not _last_view.is_empty() and (mission != str(_last_view.get("mission_id", "")) or alert > int(_last_view.get("alert_level", 0))):
		_ending_presenting = false
	if _ending_presenting and has_ending:
		audio.set_mood("ending")
	elif alert > 0:
		audio.set_mood("alert")
	elif completed:
		audio.set_mood("flow")
	else:
		audio.set_mood(_mission_mood(mission))
	if not _last_view.is_empty():
		if mission != str(_last_view.get("mission_id", "")):
			audio.play_ui("notification")
		elif completed and not bool(_last_view.get("completed", false)):
			audio.play_ui("success")
		elif alert > int(_last_view.get("alert_level", 0)):
			audio.play_ui("alert")
		elif str(view.get("host", "")) != str(_last_view.get("host", "")):
			audio.play_ui("connect")
		if str(campaign.get("id", "")) == "investigation" and mission == "I02" and str(_last_view.get("mission_id", "")) == "I02" and completed and not bool(_last_view.get("completed", false)) and not _story_effects_seen.has("investigation:I02"):
			_story_effects_seen["investigation:I02"] = true
			desktop_effects.trigger_story("investigation:I02")
	_last_view = view.duplicate(true)


func _mission_mood(mission: String) -> String:
	if mission in ["M01", "M02", "D01", "T01"]:
		return "intro"
	if mission in ["M12", "M16", "M20", "M24", "D04", "D07", "D08", "T04", "T07", "T08"]:
		return "reveal"
	if mission in ["M05", "M06", "M07", "M08", "M13", "M14", "M15", "D02", "D03", "D05", "D06", "T03", "T05"]:
		return "flow"
	return "investigate"


func _on_action_performed(result: Dictionary, source: Control = null) -> void:
	if source != null and (source != room.desktop or not room._in_desktop):
		return
	if not bool(result.get("ok", false)):
		audio.play_ui("error")
	elif str(result.get("event", "")) in ["tool", "tool_observed"] or str(result.get("ui_app", "")) == "tools":
		audio.play_ui("tool")


func _on_room_entered() -> void:
	_ending_presenting = false
	audio.set_paused(false)
	audio.set_mood("home")
	_refresh_save_status()


func _on_return_requested(source: Control) -> void:
	if source == room.desktop and room._in_desktop:
		room.return_to_room()


func _on_campaign_finished(_ending: Dictionary, source: Control) -> void:
	if source == room.desktop and room._in_desktop:
		_ending_presenting = true
		audio.set_mood("ending")


func _on_presentation_context_changed(app_id: String, source: Control) -> void:
	if source != room.desktop or not room._in_desktop:
		return
	_ending_presenting = app_id == "ending"
	_on_view_changed(_last_view, source)


func _on_pause_changed(value: bool, source: Control) -> void:
	if source == room.desktop and room._in_desktop:
		audio.set_paused(value)


func _on_settings_requested(source: Control = null) -> void:
	if source != null and source != room.desktop:
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	room.show_settings()
	if room.settings_panel != null:
		room.settings_panel.closed.connect(func():
			if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
				previous_focus.call_deferred("grab_focus")
			elif room._in_desktop and is_instance_valid(room.desktop):
				room.desktop.call_deferred("_restore_focus")
			else:
				room._focus_menu(), CONNECT_ONE_SHOT)


## Capture live campaign models first; an invalid existing file is never an absence marker.
func capture_manual_profile() -> Dictionary:
	if not is_instance_valid(room) or room.profile_recovery_required:
		return {"ok": false, "code": "PROFILE_RECOVERY_REQUIRED"}
	if room.habitat_store == null or not bool(room.habitat_view().get("ready", false)):
		return {"ok": false, "code": "HABITAT_RECOVERY_REQUIRED"}
	var campaigns := {}
	for pack in Catalog.list_all_packs(true):
		var id := str(pack.id)
		var cached = room.get_cached_desktop(id)
		if is_instance_valid(cached) and bool(cached.get("session_active")) and cached.game != null:
			campaigns[id] = cached.game.export_snapshot()
			continue
		var slot := _slot_for(id)
		if slot.is_empty():
			return {"ok": false, "code": "INVALID_SLOT"}
		var probe = Campaign.new(slot, id)
		var status: Dictionary = probe.get_save_status()
		if bool(status.get("exists", false)) or bool(status.get("backup_exists", false)) or bool(status.get("backup_available", false)):
			var loaded: Dictionary = probe.load_game()
			if not bool(loaded.get("ok", false)):
				return loaded
			campaigns[id] = probe.export_snapshot()
		else:
			# Failed path/link checks also fail closed rather than turning damage into absence.
			if str(status.get("reason_code", "")) != "SAVE_NOT_FOUND":
				return {"ok": false, "code": status.get("reason_code", "SAVE_UNREADABLE")}
			campaigns[id] = null
	var mode := "desktop" if room._in_desktop else ("menu" if room.menu.visible else "room")
	var pack_id := str(room._active_pack_id) if not str(room._active_pack_id).is_empty() and mode != "menu" else str(room.selected_pack_id)
	return {"ok": true, "snapshots": {"campaigns": campaigns, "habitat": room.habitat_store.export_snapshot()},
		"context": {"pack_id": pack_id, "mode": mode, "zone": room.current_zone, "return_pack_id": room._commission_return_pack}}


func save_manual_slot(index: int) -> Dictionary:
	if manual_store == null:
		return {"ok": false, "code": "INVALID_TEST_ROOT"}
	var captured := capture_manual_profile()
	if not captured.get("ok", false):
		return captured
	return manual_store.save_slot(index, captured.snapshots, captured.context)


## The only live mutation happens after every staged model and the pointer commit succeed.
func load_manual_slot(index: int, use_backup: bool = false) -> Dictionary:
	if manual_store == null or not is_instance_valid(room):
		return {"ok": false, "code": "INVALID_TEST_ROOT"}
	return _restore_prepared_profile(manual_store.prepare_restore(index, use_backup))


func recover_active_profile() -> Dictionary:
	if manual_store == null or not is_instance_valid(room):
		return {"ok": false, "code": "INVALID_TEST_ROOT"}
	return _restore_prepared_profile(manual_store.prepare_active_recovery())


func _restore_prepared_profile(prepared: Dictionary) -> Dictionary:
	if not prepared.get("ok", false):
		return prepared
	var paths: Dictionary = prepared.get("paths", {})
	var snapshots: Dictionary = prepared.get("snapshots", {})
	var replacements := {}
	for pack in Catalog.list_all_packs(true):
		var id := str(pack.id)
		var path := str(paths.get("campaign_slots", {}).get(id, ""))
		if path.is_empty():
			return {"ok": false, "code": "INVALID_PROFILE_PATHS"}
		var candidate = Campaign.new(path, id)
		if not bool(candidate.get_view().get("ready", false)):
			return {"ok": false, "code": "INVALID_CONTENT"}
		var raw: Variant = snapshots.get("campaigns", {}).get(id)
		if raw != null:
			var restored: Dictionary = candidate.restore_snapshot(raw)
			if not restored.get("ok", false):
				return restored
		replacements[id] = candidate
	var habitat_path := str(paths.get("habitat_path", ""))
	if habitat_path.is_empty():
		return {"ok": false, "code": "INVALID_PROFILE_PATHS"}
	var replacement_habitat = Habitat.new(habitat_path)
	var habitat_loaded: Dictionary = replacement_habitat.load_state()
	if not habitat_loaded.get("ok", false):
		return habitat_loaded
	if not replacement_habitat.get_view().get("ready", false):
		return {"ok": false, "code": "HABITAT_RECOVERY_REQUIRED"}
	var committed: Dictionary = manual_store.commit_restore(prepared)
	if not committed.get("ok", false):
		return committed
	desktop_effects.cancel()
	room._close_habitat_panel()
	room.invalidate_desktops()
	_connected_desktops.clear()
	_last_view.clear()
	_ending_presenting = false
	_profile_active = true
	_campaign_paths = committed.paths.campaign_slots.duplicate(true)
	room.campaign_slots = _campaign_paths.duplicate(true)
	room.habitat_path = str(committed.paths.habitat_path)
	room.habitat_store = replacement_habitat
	room.habitat_load_result = habitat_loaded
	room.profile_recovery_required = false
	room.profile_recovery_code = ""
	room.allow_legacy_auto_import = false
	room.studio.apply_habitat(replacement_habitat.get_view())
	room._rebuild_menu()
	manual_profile_result = {"ok": true, "active": true, "campaign_slots": _campaign_paths, "habitat_path": room.habitat_path, "context": committed.context}
	_refresh_save_status()
	_apply_profile_context(committed.context)
	if room.manual_save_panel != null:
		room.manual_save_panel._grab_initial_focus()
	return {"ok": true, "code": "PROFILE_RESTORED"}


func _apply_profile_context(context: Dictionary) -> void:
	var pack := str(context.get("pack_id", "intruder"))
	var return_pack := str(context.get("return_pack_id", ""))
	_select_profile_pack(context)
	room._active_pack_id = pack
	room._change_zone(str(context.get("zone", "room")))
	_refresh_save_status()
	match str(context.get("mode", "menu")):
		"desktop": room.open_desktop("continue", pack)
		"room": room.return_to_room()
		_: room.show_main_menu()
	room._commission_return_pack = return_pack


func _select_profile_pack(context: Dictionary) -> void:
	var pack := str(context.get("pack_id", "intruder"))
	var return_pack := str(context.get("return_pack_id", ""))
	room.selected_pack_id = pack if Catalog.PUBLIC_IDS.has(pack) else (return_pack if Catalog.PUBLIC_IDS.has(return_pack) else "intruder")


func show_manual_saves() -> void:
	if not is_instance_valid(room) or manual_store == null or room.manual_save_panel != null or room.settings_panel != null or room.habitat_panel != null:
		return
	_manual_focus_target = get_viewport().gui_get_focus_owner()
	room._looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_manual_scrim = ColorRect.new()
	_manual_scrim.color = Color(0.01, 0.02, 0.03, 0.82)
	_manual_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.overlay.add_child(_manual_scrim)
	room.manual_save_panel = ManualSavePanel.new()
	room.overlay.add_child(room.manual_save_panel)
	room.manual_save_panel.setup(manual_store.list_slots(), float(room.settings_store.get_values().font_scale), not room.profile_recovery_required, room.profile_recovery_code, manual_store.get_active_recovery_status() if room.profile_recovery_required else {})
	room.manual_save_panel.closed.connect(_close_manual_saves)
	room.manual_save_panel.save_requested.connect(_on_manual_save_requested)
	room.manual_save_panel.load_requested.connect(_on_manual_load_requested)
	room.manual_save_panel.backup_load_requested.connect(_on_manual_backup_load_requested)
	room.manual_save_panel.active_recovery_requested.connect(_on_active_recovery_requested)


func _close_manual_saves() -> void:
	if room.manual_save_panel != null:
		room.manual_save_panel.get_parent().remove_child(room.manual_save_panel)
		room.manual_save_panel.queue_free()
		room.manual_save_panel = null
	if _manual_scrim != null:
		_manual_scrim.get_parent().remove_child(_manual_scrim)
		_manual_scrim.queue_free()
		_manual_scrim = null
	_restore_manual_focus.call_deferred()


func _restore_manual_focus() -> void:
	if is_instance_valid(_manual_focus_target) and _manual_focus_target.is_visible_in_tree() and not _manual_focus_target.is_queued_for_deletion():
		_manual_focus_target.grab_focus()
	elif room._in_desktop and is_instance_valid(room.desktop):
		room.desktop._restore_focus()
	else:
		room._focus_menu()


func _on_manual_save_requested(index: int) -> void:
	var result := save_manual_slot(index)
	if room.manual_save_panel != null:
		room.manual_save_panel.render(manual_store.list_slots(), not room.profile_recovery_required)
		room.manual_save_panel.show_result(result, "save", index)


func _on_manual_load_requested(index: int) -> void:
	var result := load_manual_slot(index)
	if room.manual_save_panel != null:
		room.manual_save_panel.render(manual_store.list_slots(), not room.profile_recovery_required)
		room.manual_save_panel.show_result(result, "load", index)
		room.manual_save_panel._restore_focus.call_deferred(index, "load", room.manual_save_panel.scroll.scroll_vertical)


func _on_manual_backup_load_requested(index: int) -> void:
	var result := load_manual_slot(index, true)
	if room.manual_save_panel != null:
		room.manual_save_panel.render(manual_store.list_slots(), not room.profile_recovery_required)
		room.manual_save_panel.show_result(result, "load", index)
		room.manual_save_panel._restore_focus.call_deferred(index, "backup", room.manual_save_panel.scroll.scroll_vertical)


func _on_active_recovery_requested() -> void:
	var result := recover_active_profile()
	if room.manual_save_panel != null:
		room.manual_save_panel.render(manual_store.list_slots(), not room.profile_recovery_required)
		room.manual_save_panel.show_result(result, "recover", 0)


func _on_desktop_effects_preview() -> void:
	if is_instance_valid(desktop_effects):
		desktop_effects.preview()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(room):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		audio.play_ui("click")
	elif event is InputEventKey and event.pressed and not event.echo and room._in_desktop:
		if event.unicode > 0 or event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
			audio.play_ui("key")


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(room):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if room.settings_panel != null:
			room.settings_panel.closed.emit()
			get_viewport().set_input_as_handled()
