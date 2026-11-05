extends RefCounted
## Local preferences only; campaign slots never pass through this store.

signal changed(values: Dictionary)

const PATH := "user://settings.json"
const LOCALES := ["ko", "en", "ja", "zh_Hans", "es", "de"]
const DEFAULTS := {
	"master_volume": 0.8, "music_volume": 0.65, "sfx_volume": 0.8,
	"ui_volume": 0.65, "ambience_volume": 0.65,
	"keyboard_volume": 0.45, "tool_volume": 0.7, "notification_volume": 0.7,
	"reduced_motion": false, "comfort_mode": true, "font_scale": 1.0,
	"fullscreen": false, "mouse_sensitivity": 0.12,
	"background_audio": false, "locale": "ko",
}
var _values: Dictionary = DEFAULTS.duplicate(true)


func get_values() -> Dictionary:
	return _values.duplicate(true)


func validate_values(input: Variant) -> Dictionary:
	if not input is Dictionary:
		return {"ok": false, "error": "Settings must be an object."}
	var values: Dictionary = DEFAULTS.duplicate(true)
	for key in input:
		if not key is String or not DEFAULTS.has(key):
			return {"ok": false, "error": "Unknown settings field."}
		var value: Variant = input[key]
		if key == "locale":
			if not value is String or not value in LOCALES:
				return {"ok": false, "error": "Unsupported language."}
		elif DEFAULTS[key] is bool:
			if not value is bool:
				return {"ok": false, "error": "Expected a boolean setting."}
		else:
			if not (value is float or value is int) or not is_finite(float(value)):
				return {"ok": false, "error": "Expected a finite numeric setting."}
			var limits := Vector2(0.0, 1.0)
			if key == "font_scale":
				limits = Vector2(0.85, 1.6)
			elif key == "mouse_sensitivity":
				limits = Vector2(0.03, 0.5)
			if float(value) < limits.x or float(value) > limits.y:
				return {"ok": false, "error": "Setting is outside its supported range."}
			value = float(value)
		values[key] = value
	return {"ok": true, "values": values}


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"ok": true, "values": get_values()}
	var loaded := _read(PATH)
	if loaded["ok"]:
		_values = loaded["values"]
	return loaded


func update_settings(patch: Dictionary) -> Dictionary:
	var candidate := _values.duplicate(true)
	for key in patch:
		candidate[key] = patch[key]
	var checked := validate_values(candidate)
	if not checked["ok"]:
		return checked
	var directory := DirAccess.open("user://")
	if directory == null:
		return {"ok": false, "error": "Settings directory is unavailable."}
	for name in ["settings.json", "settings.json.tmp", "settings.json.bak"]:
		if directory.is_link(name) or directory.dir_exists(name):
			return {"ok": false, "error": "Settings path is not a regular local file."}
	var staged := PATH + ".tmp"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write settings."}
	file.store_string(JSON.stringify({"version": 1, "values": checked["values"]}, "", true, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "Settings write failed."}
	var verified := _read(staged)
	if not verified["ok"] or verified["values"] != checked["values"]:
		return {"ok": false, "error": "Settings verification failed."}
	if FileAccess.file_exists(PATH):
		var backup_error := DirAccess.copy_absolute(PATH, PATH + ".bak")
		if backup_error != OK:
			return {"ok": false, "error": "Cannot preserve previous settings."}
	# shortcut: one running game owns this preferences file; add locking before multi-instance writes.
	var replace_error := DirAccess.rename_absolute(staged, PATH)
	if replace_error != OK:
		return {"ok": false, "error": "Cannot replace settings; previous file is preserved."}
	_values = checked["values"]
	changed.emit(get_values())
	return {"ok": true, "values": get_values()}


func reset_controls() -> Dictionary:
	return update_settings({"mouse_sensitivity": DEFAULTS["mouse_sensitivity"], "comfort_mode": true})


func _read(path: String) -> Dictionary:
	var directory := DirAccess.open("user://")
	if directory == null or directory.is_link(path.get_file()):
		return {"ok": false, "error": "Settings path is unavailable."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Cannot read settings."}
	if file.get_length() > 65536:
		file.close()
		return {"ok": false, "error": "Settings file is too large."}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "Settings file is damaged; defaults remain active."}
	var data: Dictionary = parser.data
	if data.size() != 2 or not data.has("version") or not data.has("values"):
		return {"ok": false, "error": "Unsupported settings structure."}
	var version: Variant = data["version"]
	if not (version is int or version is float) or float(version) != 1.0:
		return {"ok": false, "error": "Unsupported settings version."}
	return validate_values(data["values"])
