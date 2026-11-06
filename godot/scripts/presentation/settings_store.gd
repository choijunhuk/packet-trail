extends RefCounted
## Local preferences only; campaign slots never pass through this store.

signal changed(values: Dictionary)

const PATH := "user://settings.json"
const LOCALES := ["ko", "en", "ja", "zh_Hans", "es", "de"]
const SUPPORT_KEYS := ["support_intruder", "support_defender", "support_tracker", "support_challenge", "support_investigation"]
const SUPPORT_LEVELS := ["guided", "standard", "independent"]
const MAX_BYTES := 65536
const DEFAULTS := {
	"master_volume": 0.8, "music_volume": 0.65, "sfx_volume": 0.8,
	"ui_volume": 0.65, "ambience_volume": 0.65,
	"keyboard_volume": 0.45, "tool_volume": 0.7, "notification_volume": 0.7,
	"reduced_motion": false, "comfort_mode": true, "font_scale": 1.0,
	"fullscreen": false, "mouse_sensitivity": 0.12,
	"background_audio": false, "desktop_effects": false, "locale": "ko",
	"support_intruder": "standard", "support_defender": "standard", "support_tracker": "standard", "support_challenge": "standard", "support_investigation": "standard",
}
var _values: Dictionary = DEFAULTS.duplicate(true)
var _path: String


func _init(path: String = PATH) -> void:
	# Invalid explicit paths are retained and rejected; never select the real default as a fallback.
	_path = path


func get_values() -> Dictionary:
	return _values.duplicate(true)


func validate_values(input: Variant) -> Dictionary:
	if not input is Dictionary:
		return _failure("Settings must be an object.")
	var values: Dictionary = DEFAULTS.duplicate(true)
	for key in input:
		if not key is String or not DEFAULTS.has(key):
			return _failure("Unknown settings field.")
		var value: Variant = input[key]
		if key == "locale":
			if not value is String or not value in LOCALES:
				return _failure("Unsupported language.")
		elif SUPPORT_KEYS.has(key):
			if not value is String or not SUPPORT_LEVELS.has(value):
				return _failure("Unsupported play-support level.")
		elif DEFAULTS[key] is bool:
			if not value is bool:
				return _failure("Expected a boolean setting.")
		else:
			if not (value is float or value is int) or not is_finite(float(value)):
				return _failure("Expected a finite numeric setting.")
			var limits := Vector2(0.0, 1.0)
			if key == "font_scale":
				limits = Vector2(0.85, 1.6)
			elif key == "mouse_sensitivity":
				limits = Vector2(0.03, 0.5)
			if float(value) < limits.x or float(value) > limits.y:
				return _failure("Setting is outside its supported range.")
			value = float(value)
		values[key] = value
	return {"ok": true, "values": values}


func load_settings() -> Dictionary:
	var guard := _guard()
	if not guard.ok:
		return guard
	if not FileAccess.file_exists(_path):
		return {"ok": true, "values": get_values()}
	var loaded := _read(_path)
	if loaded.ok:
		_values = loaded.values
	return loaded


func update_settings(patch: Dictionary) -> Dictionary:
	var guard := _guard()
	if not guard.ok:
		return guard
	var candidate := _values.duplicate(true)
	for key in patch:
		candidate[key] = patch[key]
	var checked := validate_values(candidate)
	if not checked.ok:
		return checked
	var directory_error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if directory_error != OK:
		return _failure("Settings directory is unavailable.")
	guard = _guard()
	if not guard.ok:
		return guard
	var staged := _path + ".tmp"
	var bytes := JSON.stringify({"version": 1, "values": checked.values}, "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return _failure("Settings file is too large.")
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return _failure("Cannot write settings.")
	var written := file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not written or write_error != OK:
		return _failure("Settings write failed.")
	var verified := _read(staged)
	if not verified.ok or not verified.values.recursive_equal(checked.values, 0):
		return _failure("Settings verification failed.")
	if FileAccess.file_exists(_path):
		# Preserve the previous bytes, including an explicitly replaced damaged v1 file.
		var previous := FileAccess.open(_path, FileAccess.READ)
		if previous == null:
			return _failure("Cannot preserve previous settings.")
		if previous.get_length() > MAX_BYTES:
			previous.close()
			return _failure("Previous settings file is too large; original is unchanged.")
		var original := previous.get_buffer(previous.get_length())
		var read_error := previous.get_error()
		previous.close()
		if read_error != OK:
			return _failure("Cannot read previous settings for backup.")
		var backup_stage := _path + ".bak.tmp"
		if DirAccess.copy_absolute(_path, backup_stage) != OK:
			return _failure("Cannot preserve previous settings.")
		if FileAccess.get_file_as_bytes(backup_stage) != original:
			return _failure("Settings backup verification failed.")
		if DirAccess.rename_absolute(backup_stage, _path + ".bak") != OK:
			return _failure("Cannot replace settings backup; previous file is preserved.")
	# shortcut: one running game owns this preferences file; add locking before multi-instance writes.
	if DirAccess.rename_absolute(staged, _path) != OK:
		return _failure("Cannot replace settings; previous file is preserved.")
	_values = checked.values
	changed.emit(get_values())
	return {"ok": true, "values": get_values()}


func reset_controls() -> Dictionary:
	return update_settings({"mouse_sensitivity": DEFAULTS.mouse_sensitivity, "comfort_mode": true})


func _guard() -> Dictionary:
	if _path != PATH and not (_path.begins_with("user://tests/") and _path.ends_with(".json")):
		return _failure("Settings path is outside the local preferences/test namespace.")
	var relative := _path.trim_prefix("user://")
	if relative.contains("\\") or relative.contains(":"):
		return _failure("Settings path is not normalized.")
	for part in relative.split("/"):
		if part.is_empty() or part in [".", ".."]:
			return _failure("Settings path is not normalized.")
	for index in range(relative.length()):
		if relative.unicode_at(index) < 32 or relative.unicode_at(index) == 127:
			return _failure("Settings path contains a control character.")
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var result := _regular_position(_path + suffix)
		if not result.ok:
			return result
	return {"ok": true}


func _regular_position(path: String) -> Dictionary:
	var parent := "user://"
	var parts := path.trim_prefix("user://").split("/")
	for index in range(parts.size()):
		if not DirAccess.dir_exists_absolute(parent):
			return _failure("Settings parent is not a directory.") if FileAccess.file_exists(parent) else {"ok": true}
		var directory := DirAccess.open(parent)
		if directory == null:
			return _failure("Settings directory is unavailable.")
		var part: String = parts[index]
		if directory.is_link(part):
			return _failure("Settings path cannot contain a symbolic link.")
		if index == parts.size() - 1:
			if directory.dir_exists(part):
				return _failure("Settings path is not a regular local file.")
		elif directory.file_exists(part) and not directory.dir_exists(part):
			return _failure("Settings parent is not a directory.")
		parent = parent.path_join(part)
	return {"ok": true}


func _read(path: String) -> Dictionary:
	if not path in [_path, _path + ".tmp"]:
		return _failure("Unsupported settings read path.")
	var guard := _guard()
	if not guard.ok:
		return guard
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Cannot read settings.")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _failure("Settings file is too large.")
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return _failure("Settings file is damaged; active preferences are unchanged.")
	var data: Dictionary = parser.data
	if data.size() != 2 or not data.has("version") or not data.has("values"):
		return _failure("Unsupported settings structure.")
	var version: Variant = data.version
	if not (version is int or version is float) or float(version) != 1.0:
		return _failure("Unsupported settings version.")
	return validate_values(data.values)


func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
