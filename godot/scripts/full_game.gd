extends Node
## Connect the room, the virtual desktop and presentation. All game rules stay in CampaignGame.

const RoomScene = preload("res://scenes/room.tscn")
const DesktopScene = preload("res://scenes/campaign_desktop.tscn")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const Locale = preload("res://scripts/presentation/localization.gd")

@export var save_slot_path := "user://saves/campaign_01.json"
var room: Node3D
var audio: Node
var _last_view: Dictionary = {}
var _connected_desktop: Control


func _ready() -> void:
	audio = AudioDirector.new()
	audio.name = "Score"
	add_child(audio)
	room = RoomScene.instantiate()
	room.name = "Studio"
	room.desktop_scene = DesktopScene
	room.desktop_save_slot_path = save_slot_path
	room.settings_changed.connect(_on_settings)
	room.application_focus_changed.connect(audio.set_background_active)
	room.desktop_requested.connect(_on_desktop_requested)
	room.room_entered.connect(_on_room_entered)
	add_child(room)
	audio.configure(room.settings_store.get_values())
	audio.set_mood("home")
	_refresh_save_status()
	_update_title()


func _refresh_save_status() -> void:
	var probe = Campaign.new(save_slot_path)
	var status: Dictionary = probe.get_save_status()
	room.set_session_available(bool(status.get("exists", false)) or bool(status.get("backup_available", false)))
	room.set_legacy_session_available(bool(status.get("legacy_available", false)))


func _on_settings(values: Dictionary) -> void:
	audio.set_volumes(values)
	if is_instance_valid(room.desktop) and room.desktop.has_method("apply_settings"):
		room.desktop.apply_settings(values)
	_update_title()


func _update_title() -> void:
	get_window().title = Locale.tr_key("ROOM_TITLE") + " · " + str(ProjectSettings.get_setting("application/config/version", "1.0.0-rc1"))


func _on_desktop_requested(_action: String) -> void:
	var desktop: Control = room.desktop
	if desktop != _connected_desktop:
		_connected_desktop = desktop
		if desktop.has_signal("view_changed"):
			desktop.view_changed.connect(_on_view_changed)
		if desktop.has_signal("return_to_room_requested"):
			desktop.return_to_room_requested.connect(room.return_to_room)
		if desktop.has_signal("campaign_finished"):
			desktop.campaign_finished.connect(func(_ending): audio.set_mood("ending"))
		if desktop.has_signal("pause_changed"):
			desktop.pause_changed.connect(audio.set_paused)
		if desktop.has_signal("action_performed"):
			desktop.action_performed.connect(_on_action_performed)
		if desktop.has_signal("settings_requested"):
			desktop.settings_requested.connect(_on_settings_requested)
	if desktop.has_method("apply_settings"):
		desktop.apply_settings(room.settings_store.get_values())
	if desktop.has_method("get_game_view"):
		_on_view_changed(desktop.get_game_view())
	_refresh_save_status()


func _on_view_changed(view: Dictionary) -> void:
	if not bool(view.get("ready", false)):
		return
	var ending: Variant = view.get("ending", "")
	var has_ending: bool = (ending is Dictionary and not ending.is_empty()) or (ending is String and not ending.is_empty())
	var mission := str(view.get("mission_id", "M01"))
	var alert := int(view.get("alert_level", 0))
	var completed := bool(view.get("completed", false))
	if has_ending:
		audio.set_mood("ending")
	elif completed:
		audio.set_mood("flow")
	elif alert > 0:
		audio.set_mood("alert")
	elif mission in ["M12", "M16", "M20", "M24"]:
		audio.set_mood("reveal")
	elif mission in ["M01", "M02"]:
		audio.set_mood("intro")
	else:
		audio.set_mood("investigate")
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


func _on_action_performed(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		audio.play_ui("error")
	elif str(result.get("event", "")) in ["tool", "tool_observed"] or str(result.get("ui_app", "")) == "tools":
		audio.play_ui("tool")


func _on_room_entered() -> void:
	audio.set_paused(false)
	audio.set_mood("home")


func _on_settings_requested() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	room.show_settings()
	if room.settings_panel != null:
		room.settings_panel.closed.connect(func():
			if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
				previous_focus.call_deferred("grab_focus"), CONNECT_ONE_SHOT)


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
