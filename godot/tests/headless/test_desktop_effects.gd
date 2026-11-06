extends RefCounted
## Fake-window restoration checks never claim actual OS movement acceptance.

const Effects = preload("res://scripts/presentation/desktop_effects.gd")
const Settings = preload("res://scripts/presentation/settings_store.gd")
const SettingsPanel = preload("res://scripts/presentation/settings_panel.gd")
const SafeFixtures = preload("res://tests/headless/test_support_settings.gd")

class FakeWindow extends RefCounted:
	var state := {"available": true, "native": false, "focused": true, "title": "Original game title",
		"position": Vector2i(100, 100), "size": Vector2i(1280, 720), "mode": Window.MODE_WINDOWED,
		"screen": 0, "outer_position": Vector2i(100, 76), "outer_size": Vector2i(1280, 744),
		"usable": Rect2i(0, 0, 1920, 1080)}
	var writes: Array[String] = []

	func snapshot() -> Dictionary: return state.duplicate(true)

	func set_title(value: String) -> void:
		state.title = value
		writes.append("title")

	func set_position(value: Vector2i) -> void:
		state.outer_position += value - state.position
		state.position = value
		writes.append("position")

var checks := 0
var failures: Array[String] = []
var tree: SceneTree


func run(scene_tree: SceneTree) -> Dictionary:
	tree = scene_tree
	var helper := SafeFixtures.new()
	var before: Dictionary = helper._fingerprints()
	_settings_and_panel(helper)
	await _lifecycle()
	await _suppression()
	await _user_ownership()
	await _escape_input()
	await _timer_while_paused()
	var native := Effects.new()
	tree.root.add_child(native)
	native.configure({"desktop_effects": true})
	if DisplayServer.get_name() == "headless":
		var result: Dictionary = native.preview()
		_check(not result.started and result.reason == "unavailable" and not result.native_request, "headless native adapter never claims an OS request")
	native.free()
	_check(helper._fingerprints() == before, "default preferences and campaign slots remain unchanged")
	return {"suite": "desktop_effects", "checks": checks, "failures": failures.duplicate(),
		"limit": "Isolated settings IO, real panel metadata, fake own-window driver and real paused Timer lifecycle. Native OS movement/focus and physical input are NOT_RUN."}


func _settings_and_panel(helper: RefCounted) -> void:
	var store := Settings.new()
	_check(store.get_values().get("desktop_effects") == false, "actual desktop effects are disabled by default")
	var old: Dictionary = store.validate_values({"locale": "en", "music_volume": 0.31})
	_check(old.ok and old.values.desktop_effects == false and old.values.music_volume == 0.31, "old sparse preferences stay opted out without changing previous values")
	for invalid in [1, "true", null, [], {}]:
		_check(not store.validate_values({"desktop_effects": invalid}).ok, "desktop effects require an explicit boolean: " + str(invalid))
	helper.root_path = "user://tests/desktop_effects_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var path: String = helper.root_path + "/settings.json"
	var isolated := Settings.new(path)
	_check(isolated.update_settings({"desktop_effects": true}).ok, "explicit opt-in persists only in owned test preferences")
	var reloaded := Settings.new(path)
	_check(reloaded.load_settings().ok and reloaded.get_values().desktop_effects, "saved opt-in survives a real isolated round trip")
	var panel := SettingsPanel.new()
	tree.root.add_child(panel)
	panel.setup(store)
	var toggle: CheckBox = panel.controls.desktop_effects
	var preview := _preview_button(panel)
	_check(toggle != null and not toggle.button_pressed, "real display settings expose an unchecked opt-in")
	_check(preview != null and preview.disabled, "preview stays disabled before saved opt-in")
	toggle.button_pressed = true
	_check(preview.disabled, "unsaved checkbox does not activate desktop preview")
	panel.free()
	panel = SettingsPanel.new()
	tree.root.add_child(panel)
	panel.setup(reloaded)
	preview = _preview_button(panel)
	var requests: Array[bool] = []
	panel.desktop_effects_preview_requested.connect(func(): requests.append(true))
	_check(not preview.disabled, "saved explicit opt-in unlocks preview")
	preview.pressed.emit()
	_check(requests.size() == 1, "real preview control emits the integration request")
	panel.controls.desktop_effects.button_pressed = false
	_check(preview.disabled, "unchecking the setting disables preview immediately")
	panel.free()
	helper._remove_owned(helper.root_path)
	_check(not DirAccess.dir_exists_absolute(helper.root_path), "only the owned settings fixture is removed")


func _preview_button(panel: PanelContainer) -> Button:
	for child in panel.find_children("*", "Button", true, false):
		if child.get_meta("settings_action", "") == "desktop_effects_preview": return child
	return null


func _effect(window: RefCounted) -> Node:
	var effect := Effects.new(window)
	tree.root.add_child(effect)
	return effect


func _lifecycle() -> void:
	var window := FakeWindow.new()
	var original := window.snapshot()
	var effect := _effect(window)
	effect.configure({})
	_check(not effect.preview().started and window.writes.is_empty(), "missing opt-in is a zero-write no-op")
	effect.configure({"desktop_effects": true})
	_check(window.writes.is_empty() and not effect.active, "configuration never starts an effect")
	var result: Dictionary = effect.preview()
	_check(result.started and result.motion and not result.native_request, "fake preview starts bounded motion without an OS claim")
	_check(window.state.title.begins_with("MidnightAccess · ") and window.state.title != original.title, "preview explicitly identifies the game in its own title")
	_check(window.state.position.distance_to(original.position) <= Effects.OFFSET, "motion is limited to twelve pixels")
	_check(window.state.usable.encloses(Rect2i(window.state.outer_position, window.state.outer_size)), "decorated window stays inside the usable screen")
	_check(effect.process_mode == Node.PROCESS_MODE_ALWAYS, "effect monitoring continues while game is paused")
	_check(not effect.trigger_story("authored_event").started, "overlapping story effect cannot replace the active snapshot")
	var signals: Array[Dictionary] = []
	effect.effects_finished.connect(func(finished: Dictionary): signals.append(finished))
	effect.cancel()
	_check(window.snapshot() == original and not effect.active, "cancel restores original title, geometry and mode")
	var writes := window.writes.size()
	effect.cancel()
	_check(window.writes.size() == writes and signals.size() == 1, "cancel is idempotent and completion emits once")
	effect.trigger_story("authored_event")
	effect.configure({"desktop_effects": false})
	_check(window.snapshot() == original and not effect.active, "disabling during a story effect restores the window immediately")
	effect.configure({"desktop_effects": true})
	effect.preview()
	effect.configure({"desktop_effects": true, "reduced_motion": true})
	_check(window.snapshot() == original and not effect.active, "enabling reduced motion during movement restores immediately")
	effect.configure({"desktop_effects": true})
	effect.preview()
	effect.skip()
	_check(window.snapshot() == original and not effect.active, "explicit skip restores the current effect")
	effect.preview()
	tree.root.remove_child(effect)
	_check(window.snapshot() == original and not effect.active, "tree exit restores all owned changes before shutdown")
	effect.free()
	await tree.process_frame


func _suppression() -> void:
	for scenario in ["reduced_motion", "fullscreen_setting", "fullscreen", "maximized", "small", "no_space", "edge"]:
		var window := FakeWindow.new()
		var settings := {"desktop_effects": true}
		if scenario == "reduced_motion": settings.reduced_motion = true
		if scenario == "fullscreen_setting": settings.fullscreen = true
		if scenario == "fullscreen": window.state.mode = Window.MODE_FULLSCREEN
		if scenario == "maximized": window.state.mode = Window.MODE_MAXIMIZED
		if scenario == "small": window.state.size = Vector2i(800, 450)
		if scenario == "no_space": window.state.usable = Rect2i(100, 76, 1280, 744)
		if scenario == "edge": window.state.outer_position = Vector2i(-1, 76)
		var original := window.snapshot()
		var effect := _effect(window)
		effect.configure(settings)
		var result: Dictionary = effect.preview()
		_check(result.started and not result.motion and not window.writes.has("position"), "unsafe motion degrades to title only: " + scenario)
		effect.cancel()
		_check(window.snapshot() == original, "title-only effect restores original state: " + scenario)
		effect.free()
	for scenario in ["unfocused", "unavailable"]:
		var window := FakeWindow.new()
		window.state["focused" if scenario == "unfocused" else "available"] = false
		var effect := _effect(window)
		effect.configure({"desktop_effects": true})
		_check(not effect.preview().started and window.writes.is_empty(), "no window write when " + scenario)
		effect.free()
	await tree.process_frame


func _user_ownership() -> void:
	for scenario in ["move", "resize", "mode", "screen", "focus", "title"]:
		var window := FakeWindow.new()
		var original := window.snapshot()
		var effect := _effect(window)
		effect.configure({"desktop_effects": true})
		effect.preview()
		match scenario:
			"move": window.state.position += Vector2i(50, 30)
			"resize": window.state.size += Vector2i(100, 100)
			"mode": window.state.mode = Window.MODE_MAXIMIZED
			"screen": window.state.screen = 1
			"focus": window.state.focused = false
			"title": window.state.title = "New game title"
		var chosen := window.snapshot()
		effect._process(0.0)
		if scenario == "title":
			effect.cancel()
			_check(window.state.title == chosen.title, "a newer game title is preserved on cancel")
		else:
			_check(not effect.active and window.state.title == original.title, "external window change safely ends the owned title effect: " + scenario)
		if scenario in ["move", "resize", "mode", "screen"]:
			_check(window.state.position == chosen.position and window.state.size == chosen.size and window.state.mode == chosen.mode and window.state.screen == chosen.screen, "restoration preserves user-selected geometry and mode: " + scenario)
		effect.free()
	await tree.process_frame


func _escape_input() -> void:
	var window := FakeWindow.new()
	var original := window.snapshot()
	var effect := _effect(window)
	effect.configure({"desktop_effects": true})
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	tree.root.push_input(escape, true)
	_check(not tree.root.is_input_handled() and window.writes.is_empty(), "inactive effect passes Esc through without touching the window")
	effect.preview()
	escape.echo = true
	tree.root.push_input(escape, true)
	_check(effect.active and not tree.root.is_input_handled(), "held-key repeats neither skip nor consume the active effect")
	escape.echo = false
	escape.pressed = false
	tree.root.push_input(escape, true)
	_check(effect.active and not tree.root.is_input_handled(), "Esc release does not consume or end the effect")
	escape.pressed = true
	tree.root.push_input(escape, true)
	_check(not effect.active and window.snapshot() == original and tree.root.is_input_handled(), "engine-dispatched pressed Esc restores active effect and consumes the event before modal handling")
	var writes := window.writes.size()
	tree.root.push_input(escape, true)
	_check(not tree.root.is_input_handled() and window.writes.size() == writes, "Esc after completion remains available to the rest of the game")
	effect.free()
	await tree.process_frame


func _timer_while_paused() -> void:
	var window := FakeWindow.new()
	var original := window.snapshot()
	var effect := _effect(window)
	effect.configure({"desktop_effects": true})
	var previous_pause := tree.paused
	tree.paused = true
	effect.preview()
	await tree.create_timer(Effects.DURATION + 0.15, true).timeout
	_check(not effect.active and window.snapshot() == original, "real timer completes and restores while the game is paused")
	tree.paused = previous_pause
	effect.free()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
