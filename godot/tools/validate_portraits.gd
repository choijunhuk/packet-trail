extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/portraits/SOURCE.json"))
	_check(manifest is Dictionary and manifest.get("files", []) is Array and manifest.files.size() == 16, "sixteen canonical expression assets")
	if manifest is Dictionary and manifest.get("files", []) is Array:
		for entry in manifest.files:
			var path: String = "res://assets/portraits/" + str(entry.get("file", ""))
			_check(FileAccess.get_sha256(path) == str(entry.get("sha256", "")), "portrait hash " + path)
			var portrait := Image.load_from_file(path)
			_check(_valid_portrait(portrait), "transparent readable portrait " + path)
	var sample := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	sample.fill(Color.TRANSPARENT)
	_check(not _valid_portrait(sample), "fully empty portrait rejected")
	sample.fill(Color.WHITE)
	_check(not _valid_portrait(sample), "opaque rectangular portrait rejected")
	sample.fill(Color.TRANSPARENT)
	sample.fill_rect(Rect2i(100, 100, 824, 924), Color.WHITE)
	_check(_valid_portrait(sample), "transparent subject accepted")
	print(JSON.stringify({"suite": "portraits", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _valid_portrait(portrait: Image) -> bool:
	if portrait == null or portrait.is_empty() or portrait.get_width() < 1024 or portrait.get_height() < 1024:
		return false
	var used := portrait.get_used_rect()
	return portrait.detect_alpha() != Image.ALPHA_NONE and used.size.x > portrait.get_width() / 2 and used.size.y > portrait.get_height() / 2 and portrait.get_pixel(0, 0).a < 0.1 and portrait.get_pixel(portrait.get_width() - 1, 0).a < 0.1


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
