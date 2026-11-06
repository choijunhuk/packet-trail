extends SceneTree
## Run from an empty project with one trusted exported PCK argument, never the source project.

const DEFINITIONS := {
	"intruder": {"path": "res://data/campaign/packs/intruder_v2.json", "prefix": "M", "main": 24, "optional": ["S01", "S02", "R01", "P01"]},
	"defender": {"path": "res://data/campaign/packs/defender_v1.json", "prefix": "D", "main": 8, "optional": []},
	"tracker": {"path": "res://data/campaign/packs/tracker_v1.json", "prefix": "T", "main": 8, "optional": []},
	"legacy_intruder": {"path": "res://data/campaign/legacy_v1.json", "prefix": "M", "main": 24, "optional": ["S01", "S02", "R01", "P01"]},
}
const MUSIC := ["a01_signal_home", "a02_first_connection", "a03_hidden_route", "a04_packet_flow",
	"a05_raised_alert", "a06_broken_pattern", "a07_clear_channel"]
const LOCALES := ["ko", "en", "ja", "zh_Hans", "es", "de"]
const NOTICES := ["LICENSE-Godot.txt", "THIRD-PARTY-LICENSES.json",
	"assets/fonts/OFL.txt", "assets/fonts/SOURCE.json", "assets/fonts/OFL-JP.txt", "assets/fonts/SOURCE-JP.json", "assets/fonts/METADATA-JP.pb",
	"assets/fonts/OFL-SC.txt", "assets/fonts/SOURCE-SC.json", "assets/fonts/METADATA-SC.pb", "assets/fonts/OFL-Mono.txt", "assets/fonts/SOURCE-Mono.json",
	"assets/audio/LICENSE.txt", "assets/audio/manifest.json", "assets/portraits/SOURCE.json", "assets/ui/desktop/SOURCE.md"]

var checks := 0
var failures: Array[Dictionary] = []
var packs: Dictionary = {}
var visible_files: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_check(args.size() == 1, "one actual exported PCK path is required")
	_check(not ResourceLoader.exists("res://scenes/full_game.tscn") and not DirAccess.dir_exists_absolute("res://scripts/core"),
		"inspection starts from an empty project without source-game fallback")
	if not failures.is_empty():
		_finish()
		return
	_check(FileAccess.file_exists(args[0]) and ProjectSettings.load_resource_pack(args[0], false), "independent exported pack mounts")
	if not failures.is_empty():
		_finish()
		return
	_walk("res://")
	_check(not visible_files.is_empty(), "mounted pack exposes a real resource inventory")
	for path in visible_files:
		_check(not _authoring_path(path), "pack excludes authoring/test material", path if _authoring_path(path) else null)
	for path in NOTICES:
		_check(FileAccess.file_exists("res://" + path), "readable bundled attribution: " + path)
	_check(ResourceLoader.exists("res://scenes/full_game.tscn"), "full product boot scene is packed")
	var loader: Variant = load("res://scripts/core/campaign_loader.gd")
	var catalog: Variant = load("res://scripts/core/campaign_catalog.gd")
	_check(loader != null and catalog != null, "actual packed loader and catalog load")
	if loader == null or catalog == null:
		_finish()
		return
	var public_ids: Array[String] = []
	for entry in catalog.list_packs():
		public_ids.append(str(entry.get("id", "")))
	public_ids.sort()
	_check(public_ids == ["defender", "intruder", "tracker"], "catalog exposes exactly three public independent campaigns", public_ids)
	var campaign_ids: Array[String] = []
	var public_cases := 0
	var legacy_cases := 0
	for id in DEFINITIONS:
		var spec: Dictionary = DEFINITIONS[id]
		_check(FileAccess.file_exists(spec.path), "runtime definition is packed: " + id)
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec.path))
		_check(raw is Dictionary and raw.get("missions") is Dictionary, "packed definition parses: " + id)
		if not raw is Dictionary or not raw.get("missions") is Dictionary:
			continue
		var expected: Array[String] = []
		for index in range(1, spec.main + 1):
			expected.append("%s%02d" % [spec.prefix, index])
		for optional in spec.optional:
			expected.append(optional)
		var actual: Array = raw.missions.keys()
		actual.sort()
		expected.sort()
		_check(actual == expected, "packed case IDs preserve the complete declared scope: " + id)
		var loaded: Dictionary = loader.load_campaign(id)
		_check(loaded.get("ok", false), "actual packed loader validates campaign: " + id, loaded.get("errors", []))
		var identity := str(raw.get("campaign_id", "")) + "@" + str(raw.get("content_version", ""))
		_check(not campaign_ids.has(identity), "campaign identity/version is separate from every other save domain: " + id)
		campaign_ids.append(identity)
		_check(raw.get("endings") is Array and not raw.endings.is_empty(), "campaign has its own actual endings: " + id)
		packs[id] = {"cases": raw.missions.size(), "campaign_id": raw.get("campaign_id"), "endings": raw.get("endings", [])}
		if id == "legacy_intruder":
			legacy_cases += raw.missions.size()
		else:
			public_cases += raw.missions.size()
	_check(public_cases == 44 and legacy_cases == 28, "public44 and preserved legacy28 are counted separately", {"public": public_cases, "legacy": legacy_cases})
	var localization: Variant = load("res://scripts/presentation/localization.gd")
	_check(localization != null, "packed localization implementation loads")
	if localization != null:
		for locale in LOCALES:
			_check(localization.configure(locale), "packed locale configures: " + locale)
			for key in ["NEW_GAME", "UI_APP_TOOLS", "CREDITS_BODY"]:
				_check(localization.tr_key(key) != key, "actual packed translation: " + locale + "/" + key)
			for id in packs:
				for ending in packs[id].endings:
					for field in ["title", "text"]:
						var key: String = ending.get(field, "")
						_check(not key.is_empty() and localization.tr_key(key) != key, "packed campaign ending translates: " + locale + "/" + id + "/" + key)
	for suffix in ["KR", "JP", "SC", "Mono"]:
		_check(load("res://assets/fonts/NotoSans%s.ttf" % suffix) is Font, "actual packed font: " + suffix)
	var desktop_theme: Variant = load("res://scripts/presentation/desktop_theme.gd")
	_check(desktop_theme != null and desktop_theme.create(1.0) is Theme, "actual packed native desktop theme")
	for name in ["wallpaper", "launcher", "terminal", "browser", "mail", "files", "tools", "board", "notification", "minimize", "maximize", "close"]:
		var icon := load("res://assets/ui/desktop/%s.svg" % name) as Texture2D
		_check(icon != null and icon.get_width() > 0 and icon.get_height() > 0, "actual packed original desktop artwork: " + name)
	for id in ["C01", "C02", "C03", "C04"]:
		for expression in ["neutral", "focused", "guarded", "relieved"]:
			var texture := load("res://assets/portraits/%s-%s.png" % [id, expression]) as Texture2D
			_check(texture != null and texture.get_width() >= 1024 and texture.get_height() >= 1024, "actual packed portrait: " + id + "/" + expression)
	for name in MUSIC:
		var cue := load("res://assets/audio/music/%s.ogg" % name) as AudioStream
		_check(cue != null and cue.get_length() >= 120.0, "actual packed original score: " + name)
	var ending_edit := load("res://assets/audio/music/a07_clear_channel_ending.ogg") as AudioStream
	_check(ending_edit != null and ending_edit.get_length() >= 120.0, "actual packed ending audio edit")
	_finish()


func _authoring_path(path: String) -> bool:
	var value := path.to_lower().trim_suffix(".remap")
	for prefix in ["res://tests/", "res://tools/", "res://fixtures/", "res://data/campaign/locales/"]:
		if value.begins_with(prefix):
			return true
	if value.begins_with("res://locales/") and value.ends_with(".json"):
		return true
	if value.begins_with("res://data/") and value.ends_with(".json"):
		if value in ["res://data/campaign/campaign.json", "res://data/missions/m01.json"]:
			return false
		for spec in DEFINITIONS.values():
			if value == str(spec.path).to_lower():
				return false
		return true
	var name := value.get_file()
	return name.contains("solutions") or name.contains("-drafts.") or name.ends_with(".source.json") or name in ["content_inventory.json", "locale_revision.json"]


func _walk(path: String, depth: int = 0) -> void:
	if depth > 16 or visible_files.size() > 8192:
		_check(false, "packed resource tree remains bounded", path)
		return
	var directory := DirAccess.open(path)
	_check(directory != null, "packed resource directory is readable: " + path)
	if directory == null:
		return
	directory.include_hidden = true
	for file in directory.get_files():
		visible_files.append(path.path_join(file))
	for child in directory.get_directories():
		_walk(path.path_join(child), depth + 1)


func _check(ok: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not ok:
		failures.append({"case": label, "detail": detail})


func _finish() -> void:
	var counts := {}
	var public_counts := {}
	var legacy_count := 0
	for id in packs:
		counts[id] = {"cases": packs[id].cases, "endings": packs[id].endings.size()}
		if id == "legacy_intruder":
			legacy_count = int(packs[id].cases)
		else:
			public_counts[id] = int(packs[id].cases)
	print(JSON.stringify({"suite": "packed_perspectives", "checks": checks, "failures": failures,
		"packs": counts, "actual_public_counts": public_counts, "legacy_case_count": legacy_count,
		"inventory_files": visible_files.size(),
		"limit": "Actual PCK resource loading from an empty project; does not establish native OS input/audio or human acceptance."}))
	quit(0 if failures.is_empty() else 1)
