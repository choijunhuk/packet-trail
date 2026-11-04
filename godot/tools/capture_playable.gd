extends SceneTree

const GameCore = preload("res://scripts/core/game.gd")

var checks := 0
var failures: Array[String] = []
var desktop: Control
var output_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 810)
	desktop = load("res://scenes/desktop.tscn").instantiate()
	desktop.save_slot_path = "user://tests/render_ui_%s.json" % Time.get_ticks_usec()
	root.add_child(desktop)
	current_scene = desktop
	output_dir = ProjectSettings.globalize_path("res://../.omx/artifacts/first-playable/").simplify_path()
	await _frames(8)
	_check(desktop.game.get_view().ready, "desktop loads the real game")
	_capture("desktop-initial.png")
	desktop._load()
	_check(not desktop.autosave_paused, "missing save does not disable autosave")
	var before_auth: Dictionary = desktop.game.export_snapshot()
	await _submit("ssh guset@archive.packet.test")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	desktop._on_term_key(escape)
	await _frames(2)
	_check(not desktop.term_in.secret and not desktop.game.get_view().password_pending and desktop.game.export_snapshot() == before_auth,
		"Escape cancels UI password mode without adding alert")
	await _submit("ssh guest@archive.packet.test")
	_check(desktop.term_in.secret, "password input is masked")
	await _submit("guest")
	await _submit("cd /vault")
	_check(desktop.game.get_view().alert_level == 1, "UI denial raises action alert")
	await _submit("cat /public/shift-note.txt")
	await _submit("ssh maint@archive.packet.test")
	await _submit("lumen-47")
	_check(not desktop.history.has("guest") and not desktop.history.has("lumen-47"), "passwords stay out of command history")
	await _submit("scp /vault/handoff.log")
	_check(desktop.game.get_view().completed, "terminal UI completes the real mission")
	var before: Dictionary = desktop.game.export_snapshot()
	desktop.term_in.text = "pwd"
	desktop._close("terminal")
	desktop._open_app("terminal")
	await _frames(2)
	_check(desktop.term_in.text == "pwd" and desktop.game.export_snapshot() == before, "closing/reopening preserves input and session")
	desktop._open_app("archive")
	await _frames(3)
	_capture("desktop-completed.png")
	desktop._navigate("https://example.com", true)
	await _frames(2)
	_check(not desktop.br_archive.visible, "external browser URL cannot expose archive action")
	var completed_disk := GameCore.new(desktop.save_slot_path)
	desktop._reset()
	await _submit("cd ~/archive")
	var existing: Dictionary = completed_disk.load_game()
	_check(desktop.autosave_paused and desktop.autosave_label.text.contains("일시중지") and existing.ok and completed_disk.get_view().completed,
		"new work pauses autosave and retains the completed disk save after further actions")
	desktop._save()
	_check(not desktop.autosave_paused and completed_disk.load_game().ok and not completed_disk.get_view().completed,
		"explicit save replaces the old progress and resumes autosave")
	desktop._world_replaced("UI alternate-route test")
	desktop._open_app("browser")
	desktop._navigate("https://mirror.packet.test/cache/47", true)
	await _frames(2)
	desktop._archive_page()
	await _frames(3)
	_check(desktop.game.get_view().completed and desktop.game.get_view().alert_level == 0, "browser UI alternative completes without forced terminal steps")
	root.size = Vector2i(1280, 720)
	await _frames(3)
	desktop._arrange()
	await _frames(3)
	_capture("desktop-1280.png")
	var slot: String = desktop.save_slot_path
	var valid_before: Dictionary = desktop.game.export_snapshot()
	for suffix in ["", ".bak"]:
		var broken := FileAccess.open(slot + suffix, FileAccess.WRITE)
		broken.store_string("{broken-ui-fixture")
		broken.close()
	desktop._load()
	await _frames(2)
	_check(desktop.fresh_save_btn.visible and desktop.game.export_snapshot() == valid_before, "invalid main/backup exposes fresh-save choice without replacing memory")
	desktop._ask_fresh_save()
	desktop.confirm.confirmed.emit()
	desktop.confirm.hide()
	await _frames(2)
	_check(not desktop.fresh_save_btn.visible and desktop.game.load_game().ok and desktop.game.export_snapshot() == valid_before, "explicit fresh-save UI preserves current progress and restores saving")
	var directory := DirAccess.open(slot.get_base_dir())
	var preserved := 0
	for filename in directory.get_files():
		if filename.begins_with(slot.get_file().trim_suffix(".json") + "."):
			if filename.contains("damaged"):
				preserved += 1
			DirAccess.remove_absolute(slot.get_base_dir().path_join(filename))
	_check(preserved == 2, "fresh-save UI preserves both damaged originals")
	print(JSON.stringify({"suite": "rendered_ui", "checks": checks, "failures": failures, "capture_dir": output_dir, "limit": "Automated UI signals and native rendering; physical IME is separate."}))
	quit(0 if failures.is_empty() else 1)

func _submit(text: String) -> void:
	desktop.term_in.text = text
	desktop.term_in.text_submitted.emit(text)
	await _frames(2)

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
	await RenderingServer.frame_post_draw

func _capture(filename: String) -> void:
	var image := root.get_texture().get_image()
	_check(not image.is_empty() and image.save_png(output_dir.path_join(filename)) == OK, "native screenshot " + filename)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
