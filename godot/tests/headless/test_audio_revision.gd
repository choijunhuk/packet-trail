extends RefCounted
## Independent audio-only suite. Await run(); no preference or campaign file is touched.

const Director = preload("res://scripts/presentation/audio_director.gd")
const LEVELS := {"master_volume": .8, "music_volume": .65, "sfx_volume": .7,
	"ui_volume": .6, "ambience_volume": .5, "background_audio": false}
var checks := 0
var failures: Array[String] = []
var _tree: SceneTree


func run() -> Dictionary:
	checks = 0
	failures.clear()
	_tree = Engine.get_main_loop() as SceneTree
	_seam_definition()
	_assets()
	var saved_buses: Array[Dictionary] = []
	for index in range(AudioServer.bus_count):
		saved_buses.append({"volume": AudioServer.get_bus_volume_db(index), "mute": AudioServer.is_bus_mute(index)})
	var audio := Director.new()
	_tree.root.add_child(audio)
	audio.configure(LEVELS)
	audio.set_process(false)
	_check(audio.current_mood.is_empty(), "configuration never autoplays music")
	_check(audio.get("_music").size() == 2, "exactly two crossfade players")
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "independent audio bus: " + bus)
	audio.set_mood("home")
	await _tree.create_timer(.06).timeout
	audio._process(.9)
	var incoming: AudioStreamPlayer = audio.get("_music")[audio.get("_active")]
	_check(incoming.stream.loop and incoming.has_stream_playback(), "home plays a real looping stream")
	_check(absf(incoming.volume_linear - .5) < .001, "first fade has expected midpoint")
	audio._process(.9)
	audio.set_mood("flow")
	await _tree.create_timer(.04).timeout
	audio._process(.9)
	_check(absf(audio.get("_gains")[0] - .5) < .001 and absf(audio.get("_gains")[1] - .5) < .001, "two-player transition midpoint")
	audio._process(.9)
	_check(not incoming.playing, "retired player stops after crossfade")
	audio.set_mood("alert")
	await _tree.create_timer(.03).timeout
	audio.set_mood("reveal")
	await _tree.create_timer(.03).timeout
	audio._process(1.8)
	_check(audio.current_mood == "reveal", "interrupted transition converges on latest real mood")
	var before: AudioStream = audio.get("_music")[audio.get("_active")].stream
	audio.set_mood("reveal")
	_check(audio.get("_music")[audio.get("_active")].stream == before, "same looping mood does not reload/restart")
	audio.set_mood("unknown")
	_check(audio.current_mood == "reveal", "unknown mood cannot alter playback")
	audio.play_ui("alert")
	await _tree.create_timer(.06).timeout
	var stamp: int = audio.get("_last_event")["alert"]
	audio.play_ui("alarm")
	_check(audio.get("_last_event")["alert"] == stamp, "overlapping alarm is suppressed beyond the throttle interval")
	audio.set_background_active(false)
	_check(audio.get("_ambience").stream_paused, "focus policy pauses ambience")
	var count: int = audio.get("_effects").size()
	audio.play_ui("notification")
	_check(audio.get("_effects").size() == count, "inactive background suppresses new event playback")
	audio.set_volumes({"background_audio": true})
	_check(not audio.get("_ambience").stream_paused, "background opt-in resumes preserved ambience")
	audio.set_background_active(true)
	audio.set_paused(true)
	_check(audio.get("_ambience").stream_paused, "game pause includes ambience")
	audio.play_ui("click")
	_check(audio.get("_effects").has("click"), "pause menu retains UI feedback")
	audio.play_ui("connect")
	_check(not audio.get("_effects").has("connect"), "pause blocks world SFX")
	audio.set_paused(false)
	audio.set_volumes({"master_volume": 0.0, "music_volume": 0.0, "mute": true})
	_check(AudioServer.get_bus_volume_linear(0) == 0.0 and AudioServer.is_bus_mute(0), "true zero/mute master")
	_check(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")) == 0.0, "true zero music")
	audio.set_volumes({"mute": false, "music_volume": 5.0, "sfx_volume": NAN})
	_check(absf(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")) - 1.0) < .001, "finite volume clamps at one")
	_check(absf(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")) - .7) < .001, "NaN cannot corrupt bus volume")
	await _ending(audio)
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	for index in range(3):
		await _tree.process_frame
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			player.stream = null
	audio.queue_free()
	for index in range(3):
		await _tree.process_frame
	await _tree.create_timer(.1).timeout
	while AudioServer.bus_count > saved_buses.size():
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	for index in range(saved_buses.size()):
		AudioServer.set_bus_volume_db(index, saved_buses[index].volume)
		AudioServer.set_bus_mute(index, saved_buses[index].mute)
	return {"checks": checks, "failures": failures.duplicate(), "suite": "audio_revision",
		"limit": "Real Godot resource/playback state and native finished signals with Dummy output; hearing/device acceptance is separate."}


func _ending(audio: Node) -> void:
	audio.set_mood("ending")
	await _tree.create_timer(.04).timeout
	audio._process(1.8)
	var player: AudioStreamPlayer = audio.get("_music")[audio.get("_active")]
	_check(not player.stream.loop, "ending selects the non-looping A07 ending edit")
	_check(str(player.stream.tags.get("title", "")).contains("Ending Edit"), "runtime ending uses the authored ending edit rather than the unused loop")
	var stream: AudioStream = player.stream
	audio.set_mood("ending")
	_check(player.stream == stream, "repeated ending view does not restart/reload the one-shot")
	var finished := [0]
	player.finished.connect(func(): finished[0] += 1)
	audio.set_paused(true)
	await _tree.create_timer(.15).timeout
	_check(finished[0] == 0 and player.stream_paused, "ending remains paused without finishing")
	audio.set_paused(false)
	await _tree.create_timer(.04).timeout
	# Seek after resume to avoid backend-specific paused-seek handling.
	player.seek(maxf(.0, player.stream.get_length() - .08))
	for index in range(40):
		if finished[0] > 0:
			break
		await _tree.create_timer(.025).timeout
	_check(finished[0] == 1 and not player.playing, "native ending finishes exactly once after resume")
	audio.set_mood("ending")
	await _tree.create_timer(.05).timeout
	_check(finished[0] == 1 and not player.playing, "finished ending stays silent under repeated ending views")
	audio.set_mood("home")
	await _tree.create_timer(.04).timeout
	audio._process(1.8)
	audio.set_mood("ending")
	await _tree.create_timer(.04).timeout
	var next: AudioStreamPlayer = audio.get("_music")[audio.get("_active")]
	_check(next.playing and not next.stream.loop, "a later ending after another mood starts one new one-shot")


func _seam_definition() -> void:
	# Endpoint samples are one sample apart on a periodic signal, not the same phase.
	var phase := TAU * 2400.0 / 44160.0
	var natural_difference := absf(.1 * sin(phase))
	var maximum_adjacent_difference := .2 * sin(phase * .5)
	_check(natural_difference > .001, "valid periodic sine has a natural seam derivative above 1e-3")
	_check(natural_difference <= maximum_adjacent_difference, "natural seam difference lies inside ordinary adjacent-sample variation")


func _assets() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	_check(manifest is Dictionary, "audio manifest parses")
	if not manifest is Dictionary:
		return
	_check(manifest.get("music", []).size() == 7 and manifest.get("edits", []).size() == 1, "seven loops and separate ending edit exist")
	_check(manifest.get("effects", []).size() == 12, "twelve original SFX retained")
	_check(int(manifest.get("loop_validation_version", 0)) == 2, "loop validation records local derivative/RMS evidence version")
	for collection in ["music", "edits", "effects", "ambience"]:
		for entry in manifest.get(collection, []):
			var path := "res://" + str(entry.path)
			_check(FileAccess.get_sha256(path) == entry.sha256, "actual encoded bytes match manifest: " + path)
			var stream := load(path) as AudioStreamOggVorbis
			_check(stream != null, "actual Godot Vorbis import: " + path)
			if stream != null:
				_check(absf(stream.get_length() - float(entry.encoded_stats.seconds)) < .02, "engine duration agrees with decoded measurement: " + path)
			if collection == "music":
				_check(int(entry.get("bpm", 0)) >= 108 and int(entry.get("bpm", 0)) <= 148, "stronger tempo contract: " + str(entry.id))
				_check(entry.get("event_counts", {}).get("kick", 0) > 0 and entry.get("event_counts", {}).get("snare", 0) > 0,
					"authored kick and snare are present: " + str(entry.id))
			if entry.get("loop", false):
				var metrics: Dictionary = entry.get("encoded_stats", {}).get("loop_metrics", {})
				_check(not metrics.is_empty(), "circular loop has derivative/RMS evidence: " + path)
				if not metrics.is_empty():
					_check(metrics.get("passed", false), "decoded loop passes local derivative continuity: " + path)
					_check(int(metrics.get("sample_count", 1)) % 64 == 0, "circular buffer avoids native Vorbis tail padding: " + path)
					_check(float(metrics.get("boundary_rms_2ms_ratio", 0)) > .10, "loop does not impose a zero-amplitude fade dip: " + path)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
