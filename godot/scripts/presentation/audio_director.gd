extends Node
## Original score playback. Configure preferences before selecting the first mood.

const CROSSFADE_SECONDS := 1.8
const MUSIC := {
	"home": "a01_signal_home", "intro": "a02_first_connection",
	"investigate": "a03_hidden_route", "flow": "a04_packet_flow",
	"alert": "a05_raised_alert", "reveal": "a06_broken_pattern",
	"ending": "a07_clear_channel",
}
const EVENTS := ["click", "key", "hover", "notification", "success", "error",
	"connect", "disconnect", "alert", "tool", "save", "window"]
const UI_EVENTS := ["click", "key", "hover", "window"]
const ALIASES := {"alarm": "alert", "open": "window", "close": "window",
	"window_open": "window", "window_close": "window", "complete": "success"}
const EVENT_VOLUME_KEYS := {"keyboard_volume": "key", "tool_volume": "tool", "notification_volume": "notification"}

var current_mood := ""
var _music: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _effects: Dictionary = {}
var _last_event: Dictionary = {}
var _event_volumes := {"key": 1.0, "tool": 1.0, "notification": 1.0}
var _gains := [0.0, 0.0]
var _fade_from := [0.0, 0.0]
var _active := 0
var _fade_time := CROSSFADE_SECONDS
var _background_active := true
var _background_audio := false
var _paused := false


func configure(settings: Dictionary = {}) -> void:
	_ensure_players()
	set_volumes(settings)


func _ensure_players() -> void:
	if not _music.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for index in range(2):
		var player := _player("Music")
		player.name = "Music%d" % index
		player.volume_linear = 0.0
		_music.append(player)
	_ambience = _player("Ambience")
	_ambience.volume_db = -7.0
	_ambience.stream = _loop_stream("res://assets/audio/ambience/night_rain_air.ogg")


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _loop_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		push_warning("Audio cue unavailable: " + path)
		return null
	stream = stream.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream


func set_mood(mood: String) -> void:
	if not MUSIC.has(mood) or mood == current_mood:
		return
	_ensure_players()
	var stream := _loop_stream("res://assets/audio/music/%s.ogg" % MUSIC[mood])
	if stream == null:
		return
	# Reuse the quieter player when a new state interrupts an existing transition.
	var next := 0 if _gains[0] <= _gains[1] else 1
	_music[next].stop()
	_music[next].stream = stream
	_gains[next] = 0.0
	_music[next].volume_linear = 0.0
	_music[next].play()
	_fade_from = _gains.duplicate()
	_active = next
	_fade_time = 0.0
	current_mood = mood
	if not _ambience.playing:
		_ambience.play()
	_apply_pause()


func set_volumes(settings: Dictionary) -> void:
	_ensure_players()
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		var key: String = bus.to_lower() + "_volume"
		if settings.has(key) and (settings[key] is float or settings[key] is int):
			var value := float(settings[key])
			if is_finite(value):
				AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), clampf(value, 0.0, 1.0))
	for key in EVENT_VOLUME_KEYS:
		if settings.has(key) and (settings[key] is float or settings[key] is int):
			var value := float(settings[key])
			if is_finite(value):
				var event: String = EVENT_VOLUME_KEYS[key]
				_event_volumes[event] = clampf(value, 0.0, 1.0)
				if _effects.has(event):
					_effects[event].volume_linear = _event_volumes[event]
	if settings.has("mute") and settings["mute"] is bool:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), settings["mute"])
	if settings.has("background_audio") and settings["background_audio"] is bool:
		_background_audio = settings["background_audio"]
	_apply_pause()


func play_ui(event: String) -> void:
	_ensure_players()
	event = ALIASES.get(event, event)
	if not event in EVENTS or (not _background_active and not _background_audio):
		return
	if _paused and not event in UI_EVENTS:
		return
	var now := Time.get_ticks_msec()
	var minimum_gap := 70 if event in ["key", "hover"] else 35
	if now - int(_last_event.get(event, -1000)) < minimum_gap:
		return
	if not _effects.has(event):
		var player := _player("UI" if event in UI_EVENTS else "SFX")
		player.stream = load("res://assets/audio/sfx/%s.ogg" % event) as AudioStream
		player.max_polyphony = 2 if event in ["click", "key"] else 1
		player.volume_linear = float(_event_volumes.get(event, 1.0))
		_effects[event] = player
	var effect: AudioStreamPlayer = _effects[event]
	if effect.stream == null or (event == "alert" and effect.playing):
		return
	_last_event[event] = now
	effect.play()


func set_background_active(active: bool) -> void:
	_background_active = active
	_apply_pause()


func set_paused(paused: bool) -> void:
	_paused = paused
	_apply_pause()


func _apply_pause() -> void:
	var background_muted := not _background_active and not _background_audio
	for player in _music:
		player.stream_paused = _paused or background_muted
	if is_instance_valid(_ambience):
		_ambience.stream_paused = _paused or background_muted
	for event in _effects:
		var player: AudioStreamPlayer = _effects[event]
		player.stream_paused = background_muted or (_paused and not event in UI_EVENTS)


func _process(delta: float) -> void:
	if _music.is_empty() or _paused or (not _background_active and not _background_audio):
		return
	if _fade_time >= CROSSFADE_SECONDS:
		return
	_fade_time = minf(CROSSFADE_SECONDS, _fade_time + delta)
	var progress := _fade_time / CROSSFADE_SECONDS
	for index in range(2):
		var target := 1.0 if index == _active else 0.0
		_gains[index] = lerpf(float(_fade_from[index]), target, progress)
		_music[index].volume_linear = _gains[index]
		if progress >= 1.0 and index != _active:
			_music[index].stop()
