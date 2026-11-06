extends Node
## Connect the room, the virtual desktop and presentation. All game rules stay in CampaignGame.

const RoomScene = preload("res://scenes/room.tscn")
const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const Locale = preload("res://scripts/presentation/localization.gd")

## Empty selects fixed product slots; a nonempty base must resolve only to tests slots.
@export var save_slot_path := ""
var room: Node3D
var audio: Node
var _last_view: Dictionary = {}
var _connected_desktops: Dictionary = {}
var _ending_presenting := false
var _shutting_down := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	audio = AudioDirector.new()
	audio.name = "Score"
	add_child(audio)
	room = RoomScene.instantiate()
	room.name = "Studio"
	room.desktop_scene = DesktopScene
	if not save_slot_path.is_empty():
		room.settings_path = save_slot_path.get_basename() + "_preferences.json"
	for pack in Catalog.list_packs(true):
		var id := str(pack["id"])
		var slot := _slot_for(id)
		if slot.is_empty():
			push_error("Invalid campaign test slot override; no default user slot was selected.")
			return
		room.campaign_slots[id] = slot
	room.desktop_save_slot_path = _slot_for("intruder")
	room.settings_changed.connect(_on_settings)
	room.application_focus_changed.connect(audio.set_background_active)
	room.desktop_requested.connect(_on_desktop_requested)
	room.room_entered.connect(_on_room_entered)
	room.campaign_selected.connect(_on_campaign_selected)
	room.quit_requested.connect(request_shutdown)
	add_child(room)
	audio.configure(room.settings_store.get_values())
	audio.set_mood("home")
	_refresh_save_status()
	_update_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_shutdown()


func request_shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
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
	var legacy = Campaign.new(_slot_for("legacy_intruder"), "legacy_intruder")
	var legacy_status: Dictionary = legacy.get_save_status(save_slot_path.is_empty())
	var cached_legacy = room.get_cached_desktop("legacy_intruder")
	var legacy_memory := is_instance_valid(cached_legacy) and bool(cached_legacy.get("session_active"))
	var can_resume_legacy := legacy_memory or bool(legacy_status.get("exists", false)) or bool(legacy_status.get("backup_available", false)) or bool(legacy_status.get("legacy_source_available", false))
	var legacy_problem := ""
	if not can_resume_legacy and bool(legacy_status.get("legacy_source_exists", false)):
		legacy_problem = room._text("LEGACY_SOURCE_UNSUPPORTED", {"code": legacy_status.get("legacy_source_reason", "UNKNOWN")})
	room.set_legacy_campaign_available(can_resume_legacy, legacy_problem)
	room.set_legacy_session_available(bool(legacy_status.get("legacy_available", false)))


func _slot_for(id: String) -> String:
	return Catalog.default_slot(id) if save_slot_path.is_empty() else Catalog.test_slot(save_slot_path, id)


func _on_campaign_selected(_id: String) -> void:
	_refresh_save_status()


func _on_settings(values: Dictionary) -> void:
	audio.set_volumes(values)
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		audio.play_ui("click")
	elif event is InputEventKey and event.pressed and not event.echo and room._in_desktop:
		if event.unicode > 0 or event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
			audio.play_ui("key")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if room.settings_panel != null:
			room.settings_panel.closed.emit()
			get_viewport().set_input_as_handled()
