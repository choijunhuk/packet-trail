extends RefCounted
## Read-only presentation contracts. Never loads, saves, resets or removes preferences/slots.

const Settings = preload("res://scripts/presentation/settings_store.gd")
const Localization = preload("res://scripts/presentation/localization.gd")
const AudioDirector = preload("res://scripts/presentation/audio_director.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const PROTECTED := ["user://settings.json", "user://settings.json.bak",
	"user://saves/campaign_01.json", "user://saves/campaign_01.json.bak",
	"user://saves/slot_01.json", "user://saves/slot_01.json.bak"]

var checks := 0
var failures: Array[String] = []


func run() -> Dictionary:
	checks = 0
	failures.clear()
	var before := _fingerprints()
	_settings()
	_locales()
	_audio()
	_scene_contract()
	_check(_fingerprints() == before, "presentation checks preserve default settings/campaign/legacy bytes")
	return {"checks": checks, "failures": failures.duplicate(),
		"limit": "Read-only contracts; real input/rendering uses capture_full_game.gd. Physical IME/hearing remain separate."}


func _settings() -> void:
	var store := Settings.new()
	var defaults := store.get_values()
	_check(store.validate_values(defaults).get("ok", false), "all default preferences validate")
	for field in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume",
		"keyboard_volume", "tool_volume", "notification_volume"]:
		_check(defaults.has(field), "independent audio preference exists: " + field)
		_check(store.validate_values({field: 0.0}).get("ok", false), "audio mute value allowed: " + field)
		_check(not store.validate_values({field: -0.1}).get("ok", true), "negative volume rejected: " + field)
		_check(not store.validate_values({field: NAN}).get("ok", true), "NaN volume rejected: " + field)
	for value in [null, [], {"unknown": true}, {"locale": "xx"}, {"font_scale": 0.1},
		{"font_scale": 2.0}, {"fullscreen": 1}, {"background_audio": "false"}]:
		_check(not store.validate_values(value).get("ok", true), "invalid preference object rejected")
	var copy := store.get_values()
	copy["master_volume"] = 0.0
	_check(store.get_values() == defaults, "preference getter returns a detached copy")
	for locale in Settings.LOCALES:
		_check(store.validate_values({"locale": locale, "font_scale": 1.6}).get("ok", false),
			"locale and large text validated without writing: " + locale)
	_check(store.get_values() == defaults, "validation never applies or persists preferences")


func _locales() -> void:
	var original := TranslationServer.get_locale()
	_check(Localization.configure(original if original in Localization.LOCALES else "ko"), "localization loads")
	var english := load("res://locales/en.po") as Translation
	_check(english != null, "English key inventory is available")
	if english == null:
		TranslationServer.set_locale(original)
		return
	var keys := english.get_message_list()
	var campaign_keys := _campaign_keys()
	var ui_keys := _ui_keys()
	var campaign := Campaign.new("user://tests/presentation_read_only_%d_%d.json" % [Time.get_ticks_usec(), get_instance_id()])
	var initial_view: Dictionary = campaign.get_view()
	_check(initial_view.get("ready", false), "real campaign is ready for locale invariance checks")
	var snapshot: Dictionary = campaign.export_snapshot()
	_check(keys.size() > 100, "translation inventory includes the complete presentation rather than sample labels")
	_check(campaign_keys.size() > 100, "visible campaign strings are included in translation coverage")
	for locale in Localization.LOCALES:
		var resource := load("res://locales/%s.po" % locale) as Translation
		_check(resource != null, "translation resource exists: " + locale)
		if resource == null:
			continue
		_check(Localization.set_locale(locale), "supported locale switches: " + locale)
		var missing: Array[String] = []
		for key in keys:
			if resource.get_message(key).is_empty():
				missing.append(key)
		for key in campaign_keys:
			if resource.get_message(key).is_empty() and not missing.has(key):
				missing.append(key)
		for key in ui_keys:
			if resource.get_message(key).is_empty() and not missing.has(key):
				missing.append(key)
		_check(missing.is_empty(), "locale has all English keys: %s (%s)" % [locale, ", ".join(missing.slice(0, 5))])
		for key in ["ROOM_TITLE", "NEW_GAME", "CONTINUE", "SETTINGS", "TERMINAL", "CAMPAIGN_COMPLETE"]:
			var text := str(TranslationServer.translate(key))
			_check(not text.is_empty() and text != key, "visible label translates: %s/%s" % [locale, key])
		var view: Dictionary = campaign.get_view()
		_check(campaign.export_snapshot() == snapshot, "locale preserves actual canonical campaign snapshot: " + locale)
		for field in ["mission_id", "prompt", "host", "user", "cwd", "browser_home"]:
			_check(view.get(field) == initial_view.get(field), "locale preserves canonical %s: %s" % [field, locale])
	_check(not Localization.set_locale("unsupported"), "unsupported locale cannot change language")
	TranslationServer.set_locale(original)
	for pair in [[Localization.PRIMARY_FONT, "한"], [Localization.JP_FONT, "日"], [Localization.SC_FONT, "汉"]]:
		_check(pair[0].has_char(str(pair[1]).unicode_at(0)), "bundled font has representative CJK glyph: " + str(pair[1]))


func _campaign_keys() -> Dictionary:
	var result := {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/campaign.json"))
	_check(data is Dictionary and data.get("missions", {}) is Dictionary, "campaign translation source parses")
	if not data is Dictionary or not data.get("missions", {}) is Dictionary:
		return result
	for mission in data.get("missions", {}).values():
		_text_fields(mission, ["title", "goal_text"], result)
		for hint in mission.get("hints", []):
			result[str(hint)] = true
		for entry in mission.get("milestones", []):
			_text_fields(entry, ["title", "text"], result)
		for entry in mission.get("mail", {}).values():
			_text_fields(entry, ["sender", "subject", "body"], result)
		for entry in mission.get("hosts", {}).values():
			_text_fields(entry, ["name"], result)
		for entry in mission.get("records", {}).values():
			_text_fields(entry, ["display_content_key"], result)
		for entry in mission.get("challenges", {}).values():
			_text_fields(entry, ["name", "explain", "usage"], result)
		for entry in mission.get("pages", {}).values():
			_text_fields(entry, ["title", "body"], result)
			for link in entry.get("links", []):
				_text_fields(link, ["label"], result)
	for entry in data.get("endings", []):
		_text_fields(entry, ["title", "text"], result)
	return result


func _ui_keys() -> Dictionary:
	var path := "res://assets/ui/strings_en.json"
	_check(FileAccess.file_exists(path), "campaign desktop English source strings exist")
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(data is Dictionary and data.size() > 30, "campaign desktop UI inventory is populated")
	return data if data is Dictionary else {}


func _text_fields(entry: Dictionary, fields: Array, output: Dictionary) -> void:
	for field in fields:
		if entry.has(field) and not str(entry[field]).is_empty():
			output[str(entry[field])] = true


func _audio() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	_check(manifest is Dictionary, "original audio manifest parses")
	if not manifest is Dictionary:
		return
	_check(manifest.get("music", []).size() == 7, "seven original score cues")
	_check(manifest.get("edits", []).size() == 1, "ending edit is separate from seven loop cues")
	_check(manifest.get("effects", []).size() == 12, "twelve original event effects")
	var duration := 0.0
	for entry in manifest.get("music", []):
		duration += float(entry.get("master_stats", {}).get("seconds", 0))
	_check(duration >= 1020 and duration <= 1440, "original score totals 17 to 24 minutes")
	for collection in ["music", "edits", "effects", "ambience"]:
		for entry in manifest.get(collection, []):
			var path := "res://" + str(entry.get("path", ""))
			_check(FileAccess.file_exists(path), "shipped audio exists: " + path)
			if not FileAccess.file_exists(path):
				continue
			_check(FileAccess.get_sha256(path) == entry.get("sha256", ""), "shipped audio hash: " + path)
			_check(load(path) is AudioStreamOggVorbis, "Godot imports actual Ogg stream: " + path)
			var values: Dictionary = entry.get("encoded_stats", {})
			_check(values.get("clipped_samples", -1) == 0 and float(values.get("rms", 0)) > .0001,
				"audio manifest records non-silent unclipped measurements: " + path)
			if entry.get("loop", false):
				_check(float(values.get("loop_jump", 1)) < .02 and values.get("silent_seconds", -1) == 0,
					"loop seam and continuity measured: " + path)
	var bus_state: Array[Dictionary] = []
	for index in range(AudioServer.bus_count):
		bus_state.append({"name": AudioServer.get_bus_name(index), "volume": AudioServer.get_bus_volume_db(index),
			"mute": AudioServer.is_bus_mute(index)})
	var audio := AudioDirector.new()
	audio.configure(Settings.DEFAULTS)
	_check(audio.current_mood.is_empty(), "configuration never starts music automatically")
	_check(audio.get("_music").size() == 2, "exactly two crossfade players")
	for method in ["configure", "set_mood", "set_volumes", "play_ui", "set_background_active", "set_paused"]:
		_check(audio.has_method(method), "audio API exists: " + method)
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "independent mix bus: " + bus)
	audio.set_volumes({"master_volume": 0.0, "music_volume": 2.0, "sfx_volume": NAN, "mute": true})
	_check(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master")) == 0.0, "true zero master volume")
	_check(absf(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")) - 1.0) < .001, "volume is clamped")
	_check(absf(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")) - Settings.DEFAULTS.sfx_volume) < .001,
		"non-finite volume cannot corrupt bus")
	_check(AudioServer.is_bus_mute(0), "explicit master mute")
	audio.free()
	while AudioServer.bus_count > bus_state.size():
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	for index in range(bus_state.size()):
		AudioServer.set_bus_volume_db(index, bus_state[index].volume)
		AudioServer.set_bus_mute(index, bus_state[index].mute)


func _scene_contract() -> void:
	var scene := load("res://scenes/full_game.tscn") as PackedScene
	_check(scene != null, "product full-game scene exists")
	if scene == null:
		return
	var instance := scene.instantiate()
	var injectable := false
	var exported := false
	for property in instance.get_property_list():
		if property.name == "save_slot_path":
			injectable = true
			exported = (int(property.usage) & PROPERTY_USAGE_EDITOR) != 0
	_check(injectable, "product root exposes save_slot_path before entering tree")
	_check(exported, "save_slot_path is an exported scene-injection contract")
	instance.free()


func _fingerprints() -> Dictionary:
	var result := {}
	for path in PROTECTED:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
