extends Node
## Explicit opt-in, brief effects on this game's own Window only.
## No process execution, files, clipboard, external windows or focus requests.

signal effects_finished(result: Dictionary)

const DURATION := 1.2
const OFFSET := 12
const MIN_VIEWPORT := Vector2i(960, 540)

class GameWindowDriver extends RefCounted:
	var window: Window

	func _init(owned_window: Window) -> void:
		window = owned_window

	func snapshot() -> Dictionary:
		if not is_instance_valid(window) or DisplayServer.get_name() == "headless":
			return {"available": false}
		return {"available": true, "native": true, "title": window.title,
			"position": window.position, "size": window.size, "mode": window.mode,
			"screen": window.current_screen, "focused": window.has_focus(),
			"outer_position": window.get_position_with_decorations(),
			"outer_size": window.get_size_with_decorations(),
			"usable": DisplayServer.screen_get_usable_rect(window.current_screen)}

	func set_title(value: String) -> void:
		if is_instance_valid(window): window.title = value

	func set_position(value: Vector2i) -> void:
		if is_instance_valid(window): window.position = value

var active := false
var _settings: Dictionary = {}
var _driver: RefCounted
var _timer: Timer
var _original: Dictionary = {}
var _expected: Dictionary = {}
var _moved := false
var _event_id := ""


func _init(window_driver: RefCounted = null) -> void:
	# An injected driver permits isolated restoration tests without touching a desktop.
	_driver = window_driver
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	if _driver == null: _driver = GameWindowDriver.new(get_window())
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(func(): _finish("completed"))
	add_child(_timer)


func configure(settings: Dictionary) -> void:
	_settings = settings.duplicate(true)
	if active and (not bool(_settings.get("desktop_effects", false)) or bool(_settings.get("reduced_motion", false))):
		_finish("settings_changed")


func preview() -> Dictionary:
	return _start("preview", "SETTINGS_DESKTOP_EFFECTS_PREVIEW")


func trigger_story(event_id: String) -> Dictionary:
	if event_id.is_empty(): return _skipped("missing_event")
	# The caller owns authored milestones and once-per-profile bookkeeping.
	return _start(event_id, "SETTINGS_DESKTOP_EFFECTS")


func cancel() -> Dictionary:
	return _finish("cancelled")


func skip() -> Dictionary:
	return _finish("skipped")


func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE and event.physical_keycode != KEY_ESCAPE:
		return
	skip()
	get_viewport().set_input_as_handled()


func _start(event_id: String, title_key: String) -> Dictionary:
	if not bool(_settings.get("desktop_effects", false)): return _skipped("disabled")
	if active: return _skipped("busy")
	if not is_inside_tree() or _timer == null or _driver == null: return _skipped("not_ready")
	var state: Dictionary = _driver.snapshot()
	if not state.get("available", false): return _skipped("unavailable")
	if not state.get("focused", false): return _skipped("unfocused")
	_original = state.duplicate(true)
	_event_id = event_id
	active = true
	var label := str(TranslationServer.translate(title_key))
	if label == title_key: label = "Game window effect preview" if event_id == "preview" else "Game window effect"
	_driver.set_title(str(ProjectSettings.get_setting("application/config/name", "MidnightAccess")) + " · " + label)
	_moved = false
	if _can_move(state):
		var target: Vector2i = state.position + _offset(state)
		if target != state.position:
			_driver.set_position(target)
			_moved = true
	_expected = _driver.snapshot()
	_timer.start(DURATION)
	set_process(true)
	return {"ok": true, "started": true, "event_id": event_id, "motion": _moved,
		"native_request": bool(state.get("native", false)), "duration": DURATION}


func _can_move(state: Dictionary) -> bool:
	if bool(_settings.get("reduced_motion", false)) or bool(_settings.get("fullscreen", false)):
		return false
	if state.mode != Window.MODE_WINDOWED or state.size.x < MIN_VIEWPORT.x or state.size.y < MIN_VIEWPORT.y:
		return false
	var usable: Rect2i = state.usable
	var outer := Rect2i(state.outer_position, state.outer_size)
	return usable.has_area() and usable.encloses(outer)


func _offset(state: Dictionary) -> Vector2i:
	var usable: Rect2i = state.usable
	var outer := Rect2i(state.outer_position, state.outer_size)
	for delta in [Vector2i(OFFSET, 0), Vector2i(-OFFSET, 0)]:
		if usable.encloses(Rect2i(outer.position + delta, outer.size)): return delta
	return Vector2i.ZERO


func _process(_delta: float) -> void:
	if not active: return
	var state: Dictionary = _driver.snapshot()
	if not state.get("available", false) or not state.get("focused", false) or not _same_geometry(state, _expected):
		_finish("window_changed")


func _same_geometry(left: Dictionary, right: Dictionary) -> bool:
	for key in ["position", "size", "mode", "screen"]:
		if not left.has(key) or left[key] != right.get(key): return false
	return true


func _finish(reason: String) -> Dictionary:
	if not active: return {"ok": true, "started": false, "reason": "inactive"}
	active = false
	set_process(false)
	if is_instance_valid(_timer): _timer.stop()
	var state: Dictionary = _driver.snapshot()
	var restored_position := false
	if state.get("available", false):
		# Restore only values still owned by this effect; preserve user moves/resizes/mode changes.
		if _moved and _same_geometry(state, _expected):
			_driver.set_position(_original.position)
			restored_position = true
		if state.get("title") == _expected.get("title"):
			_driver.set_title(str(_original.title))
	var result := {"ok": true, "started": false, "reason": reason, "event_id": _event_id,
		"position_restored": restored_position, "native_request": bool(_original.get("native", false))}
	_original.clear()
	_expected.clear()
	_moved = false
	effects_finished.emit(result)
	return result


func _skipped(reason: String) -> Dictionary:
	return {"ok": true, "started": false, "reason": reason, "native_request": false}


func _exit_tree() -> void:
	_finish("shutdown")
