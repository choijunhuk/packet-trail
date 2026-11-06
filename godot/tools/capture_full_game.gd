extends SceneTree
## Render/input regression. Launch only the source project; never use an installed app copy.
## All campaign writes go to the unique injected tests slot. Preferences are read-only.

const Localization = preload("res://scripts/presentation/localization.gd")
const Settings = preload("res://scripts/presentation/settings_store.gd")
const Campaign = preload("res://scripts/core/campaign_game.gd")
const PROTECTED := ["user://settings.json", "user://settings.json.bak",
	"user://saves/campaign_01.json", "user://saves/campaign_01.json.bak",
	"user://saves/slot_01.json", "user://saves/slot_01.json.bak"]

var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var capture_metrics: Array[Dictionary] = []
var campaign_cases: Array[Dictionary] = []
var not_run := ["Physical IME composition: the public Godot InputEvent API cannot inject a platform composition buffer.",
	"Human hearing, long-term music fatigue, physical devices and other operating systems.",
	"OS-level focus/device switching: background integration below injects Window focus signals.",
	"Embedded dialog acceptance uses native keyboard Enter; synthetic child-window mouse hover is not claimed."]
var slot := ""
var output_dir := ""
var before_files := {}
var full: Node
var room: Node
var desktop: Control
var finished := false
var action_result: Dictionary = {}
var profile := "full"
var started_ms := 0


func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	if OS.get_cmdline_user_args().has("--ci-render-smoke"):
		profile = "ci-render-smoke"
		not_run.append("M02–M24 and four optional case GUI replays are NOT_RUN in this M01-only smoke; full campaign/backend coverage is separate evidence.")
		not_run.append("M03 discovery and M05 actor-context GUI regressions are NOT_RUN in smoke; use the default full profile.")
		not_run.append("Ending selection/credits GUI are NOT_RUN in smoke; ending backend validation belongs to the separate headless campaign suite.")
	_run.call_deferred()
	create_timer(150.0 if profile == "ci-render-smoke" else 300.0).timeout.connect(func():
		if not finished:
			failures.append("%s render/input regression timed out" % profile)
			_finish())


func _run() -> void:
	before_files = _fingerprints()
	if DisplayServer.get_name() == "headless":
		_check(false, "rendered_full_game requires a real renderer; do not substitute headless for pixel/input evidence")
		_finish()
		return
	output_dir = ProjectSettings.globalize_path("res://../.omx/artifacts/full-production/").simplify_path()
	if profile == "ci-render-smoke":
		output_dir = output_dir.path_join("ci-render-smoke")
	_check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "full-production artifact directory is writable")
	slot = "user://tests/full_ui_%d_%d.json" % [Time.get_ticks_usec(), get_instance_id()]
	_check(not FileAccess.file_exists(slot), "unique test campaign slot does not already exist")
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/full_game.tscn") as PackedScene
	_check(scene != null, "full product scene is available")
	if scene == null:
		_finish()
		return
	full = scene.instantiate()
	if not _require_fields(full, ["save_slot_path", "room", "audio"]):
		full.free()
		_finish()
		return
	full.set("save_slot_path", slot)
	root.add_child(full)
	current_scene = full
	await _frames(10)
	room = full.get("room")
	_check(room != null, "bootstrap creates the actual studio")
	if room == null or not _require_fields(room, ["desktop_save_slot_path", "menu", "menu_box", "desktop", "confirm", "settings_store"]):
		_finish()
		return
	_check(room.get("desktop_save_slot_path") == slot, "test slot reaches room before desktop instantiation")
	if room.get("desktop_save_slot_path") != slot:
		_finish()
		return
	_check(room.get("desktop") == null, "menu boot has not started a campaign implicitly")
	_check(room.get("menu").visible, "full game boots to menu")
	await _capture("full-menu.png")
	room.call("show_settings")
	await _frames(2)
	_check(room.get("settings_panel") != null, "product settings panel opens")
	await _capture("full-settings.png")
	var cancel := _button_text(room.get("settings_panel"), str(TranslationServer.translate("CANCEL")))
	_check(cancel != null, "settings cancel is reachable without applying/saving")
	if cancel == null:
		_finish()
		return
	await _click(cancel)
	_check(room.get("settings_panel") == null, "settings cancel closes panel")
	var new_game := _button_text(room.get("menu_box"), str(TranslationServer.translate("NEW_GAME")))
	_check(new_game != null, "menu exposes a real new-game action")
	if new_game == null:
		_finish()
		return
	await _click(new_game)
	_check(room.get("confirm").visible, "new game requires its existing confirmation dialog")
	await _confirm_dialog(room.get("confirm"))
	await _frames(8)
	desktop = room.get("desktop")
	_check(desktop != null, "new game enters the real campaign desktop")
	if desktop == null or not _require_fields(desktop, ["save_slot_path", "game"]):
		_finish()
		return
	_check(desktop.get("save_slot_path") == slot, "campaign UI uses only the injected test slot")
	if desktop.get("save_slot_path") != slot:
		_finish()
		return
	if not _require_methods(desktop, ["start_session", "apply_settings", "get_game_view"]):
		_finish()
		return
	for event in ["view_changed", "return_to_room_requested", "campaign_finished", "pause_changed", "action_performed"]:
		_check(desktop.has_signal(event), "product presentation signal exists: " + event)
	_check(desktop.get("game") != null and desktop.get_game_view().get("ready", false), "new session has a ready authoritative campaign")
	if desktop.get("game") == null or not desktop.get_game_view().get("ready", false):
		_finish()
		return
	_check(desktop.get("game").get("_save_path") == slot, "authoritative campaign store also uses the isolated test slot")
	if desktop.get("game").get("_save_path") != slot:
		_finish()
		return
	desktop.action_performed.connect(func(result: Dictionary): action_result = result.duplicate(true))
	if not _require_fields(desktop, ["terms", "active_term", "active_id", "wins", "task_buttons",
		"font_down_btn", "top_panel", "ui_size", "save_btn", "room_btn", "bd_tree", "bd_next_btn"]):
		_finish()
		return
	await _keyboard_focus_checks()
	await _terminal_session_checks()
	await _request_lab_checks()
	if profile == "ci-render-smoke":
		await _play_ci_render_smoke()
		_finish()
		return
	if not (await _play_campaign()):
		_finish()
		return
	await _ending_checks()
	_finish()


func _play_ci_render_smoke() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
	_check(source is Dictionary and source.get("missions", {}) is Dictionary, "smoke uses real campaign action fixtures")
	if not source is Dictionary or not source.get("missions", {}) is Dictionary:
		return
	_check(desktop.get_game_view().get("mission_id") == "M01", "smoke starts the actual M01 case")
	if not (await _play_route("M01", source.missions.get("M01", {}))):
		return
	await _file_observation_checks()
	await _save_and_room_checks()
	await _locale_audio_checks()
	_check(campaign_cases.size() == 1 and campaign_cases[0].mission_id == "M01" and campaign_cases[0].completed,
		"ci-render-smoke reports exactly one actually completed case")


func _play_campaign() -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/campaign_solutions.json"))
	_check(source is Dictionary and source.get("missions", {}) is Dictionary, "real campaign action fixtures are available")
	if not source is Dictionary or not source.get("missions", {}) is Dictionary:
		return false
	var mains: Array[String] = []
	var optional: Array[String] = []
	for mission in desktop.get_game_view().get("missions", []):
		if mission.get("optional", false):
			optional.append(str(mission.id))
		else:
			mains.append(str(mission.id))
	_check(mains.size() == 24 and optional.size() == 4, "actual case board covers 24 main and 4 optional cases")
	if mains.size() != 24 or optional.size() != 4:
		return false
	for index in range(mains.size()):
		var id := mains[index]
		_check(desktop.get_game_view().get("mission_id") == id, "real next-case navigation reaches " + id)
		if desktop.get_game_view().get("mission_id") != id:
			return false
		if not (await _play_route(id, source.missions.get(id, {}))):
			return false
		if id == "M01":
			await _file_observation_checks()
			await _save_and_room_checks()
			await _locale_audio_checks()
		if index + 1 < mains.size():
			await _open_app("board")
			_check(not desktop.bd_next_btn.disabled, "completed case enables the real Next button: " + id)
			await _focus_and_click(desktop.bd_next_btn)
			await _frames(2)
			_check(desktop.get_game_view().get("mission_id") == mains[index + 1], "Next button changes the authoritative case")
			await _mail_matches_current()
			_assert_mood(desktop.get_game_view(), "new " + mains[index + 1])
	var complete := true
	for mission in desktop.get_game_view().get("missions", []):
		if not mission.get("optional", false):
			complete = complete and bool(mission.get("completed", false))
	_check(complete, "all main cases completed before any optional case is required")
	for id in optional:
		if not (await _select_case(id)) or not (await _play_route(id, source.missions.get(id, {}))):
			return false
	return await _select_case("M24")


func _play_route(id: String, fixture: Dictionary) -> bool:
	var paths: Array = fixture.get("paths", [])
	_check(not paths.is_empty() and not paths[0].get("actions", []).is_empty(), "non-empty real solution route exists: " + id)
	if paths.is_empty() or paths[0].get("actions", []).is_empty():
		return false
	var route: Dictionary = paths[0]
	var alerted := false
	var discovery_checked := false
	var actor_checked := false
	var step := 0
	for action in route.actions:
		if id == "M05" and action.kind == "tool" and action.get("tool_id") == "m05_primary" and not actor_checked:
			await _actor_context_checks()
			actor_checked = true
			if not failures.is_empty():
				not_run.append("Remaining cases/ending skipped after real UI-01/UI-02/UI-03 regressions failed at M05; this is a failing partial run.")
				return false
		var result := await _fixture_action(action)
		var expected: Dictionary = action.get("expect", {"ok": true})
		for field in expected:
			_check(result.get(field) == expected[field], "%s UI action %d %s expected %s=%s, got %s (%s)" %
				[id, step, str(action.kind), field, str(expected[field]), str(result.get(field)), str(result.get("code", "missing result"))])
			if result.get(field) != expected[field]:
				return false
		if action.kind == "password":
			var terminal := int(action.get("terminal_id", 0))
			_check(not desktop.terms[terminal]["history"].has(str(action.value)), "fixture password stays outside terminal history: " + id)
			if id == "M03" and not discovery_checked:
				await _discovery_observation_checks()
				discovery_checked = true
		if id == "M01" and action.kind == "password" and str(action.get("value", "")) == "guest" and not alerted:
			var denial := await _submit("cat /vault/handoff.log")
			var view: Dictionary = desktop.get_game_view()
			_check(not denial.get("ok", true) and int(view.alert_level) == 1 and not view.completed,
				"real guest permission denial raises M01 alert without completing the case")
			_assert_mood(view, "M01 real permission denial")
			alerted = true
		step += 1
	var view: Dictionary = desktop.get_game_view()
	_check(view.get("completed", false), "actual UI actions complete real goals and constraints: " + id)
	if not view.get("completed", false):
		return false
	var expected: Dictionary = route.get("expected", {})
	for fact in expected.get("facts", []):
		_check(view.get("facts", []).has(fact), "actual UI route establishes required fact: %s/%s" % [id, fact])
	for policy in expected.get("policies", {}):
		_check(view.get("policies", {}).get(policy) == expected.policies[policy], "actual UI route preserves expected policy: %s/%s" % [id, policy])
	var records: Array = []
	for record in view.get("archive", []):
		records.append(record.get("record_id", ""))
	for record in expected.get("archive_record_ids", []):
		_check(records.has(record), "recovered real record appears in UI read model: %s/%s" % [id, record])
	_assert_mood(view, "completed " + id)
	if id == "M01":
		_check(alerted and int(view.alert_level) == 1, "M01 completion preserves the actual alert value while selecting flow music")
	await _open_app("board")
	_check(not str(view.get("mission_goal", "")).is_empty() and desktop.bd_goal.text.contains(str(view.mission_goal)), "case board renders the actual goal: " + id)
	_check(not view.get("objectives", []).is_empty() and desktop.bd_objectives.get_child_count() == view.objectives.size(), "case board renders every authoritative objective: " + id)
	await _mail_matches_current()
	if id in ["M01", "M09", "M16", "M24", "P01"]:
		await _capture("full-%s-completed.png" % id.to_lower())
	campaign_cases.append({"mission_id": id, "route_id": route.get("id", ""), "actions": step,
		"completed": view.completed, "alert_level": view.alert_level, "archive_records": records.size()})
	return true


func _save_and_room_checks() -> void:
	var disk_before := FileAccess.get_sha256(slot)
	# Suspend only this test UI's autosave so a real virtual change proves the Save click.
	desktop.autosave_suspended = true
	var changed := await _submit("mkdir /home/player/qa_ui_%d" % Time.get_ticks_usec(), 1)
	_check(changed.get("ok", false) and changed.get("changed", false), "manual-save test creates a real unsaved virtual directory")
	_check(FileAccess.get_sha256(slot) == disk_before, "suspended test autosave leaves the test slot unchanged")
	var snapshot: Dictionary = desktop.game.export_snapshot()
	await _click(desktop.save_btn)
	_check(not desktop.autosave_suspended and FileAccess.get_sha256(slot) != disk_before, "actual Save click writes new state and resumes saving")
	var probe := Campaign.new(slot)
	var loaded: Dictionary = probe.load_game()
	_check(loaded.get("ok", false) and probe.export_snapshot() == snapshot, "manual save round-trips the actual campaign snapshot")
	await _open_terminal(0)
	var input: LineEdit = desktop.terms[0]["input"]
	input.text = "room-return-draft"
	var same_desktop := desktop
	await _key(KEY_F10)
	_check(not room.get("_in_desktop") and not desktop.visible, "native F10 returns to the parent studio")
	_check(room.get("desktop") == same_desktop, "room return keeps the exact desktop instance")
	_check(full.get("audio").get("current_mood") == "home", "room return selects home score")
	await _capture("full-room-return.png")
	await _key(KEY_ESCAPE)
	_check(room.get("menu").visible, "native Escape opens the studio menu")
	_check(not room.get("continue_button").disabled, "saved/active session enables Continue")
	await _click(room.get("continue_button"))
	await _frames(4)
	_check(room.get("desktop") == same_desktop and desktop.visible, "Continue restores the same desktop")
	_check(desktop.game.export_snapshot() == snapshot and input.text == "room-return-draft", "room reentry preserves world, terminals and unsent draft")
	_check(root.gui_get_focus_owner() == input, "room reentry restores the exact terminal focus")
	_assert_mood(desktop.get_game_view(), "same UI after room reentry")


func _locale_audio_checks() -> void:
	var settings: Dictionary = room.get("settings_store").get_values()
	var snapshot: Dictionary = desktop.game.export_snapshot()
	var draft: String = desktop.terms[0]["input"].text
	root.size = Vector2i(1280, 720)
	for locale in Localization.LOCALES:
		var preview := settings.duplicate(true)
		preview["locale"] = locale
		preview["font_scale"] = 1.6
		preview["fullscreen"] = false
		# Isolated preference IO is setup; actual Apply/Cancel input has separate preview coverage.
		if not _set_test_settings(preview):
			return
		root.size = Vector2i(1280, 720)
		await _frames(3)
		_check(root.size == Vector2i(1280, 720), "large-text locale check uses an actual 1280×720 window: " + locale)
		_check(TranslationServer.get_locale().begins_with(locale) and is_equal_approx(desktop.font_scale, 1.6), "live locale/large-text preview applies without saving: " + locale)
		_check(desktop.game.export_snapshot() == snapshot and desktop.terms[0]["input"].text == draft,
			"locale and text size preserve actual progress and command draft: " + locale)
		_check(desktop.ui_size >= 24, "large text actually increases the desktop font: " + locale)
		var messages: Array = desktop.get_game_view().get("messages", [])
		if not messages.is_empty():
			_check(desktop.mail_body.get_parsed_text().strip_edges() == str(messages.back().body).strip_edges(), "locale refreshes the selected mail body cache: " + locale)
		_check(not desktop.top_mission.text.contains("UI_TOP_"), "localized desktop header contains display text: " + locale)
		_windows_fit(locale)
		await _key(KEY_F6)
		_check(root.gui_get_focus_owner() == desktop.launcher_button, "large text retains keyboard launcher reachability: " + locale)
		await _capture("full-locale-%s-1280-large.png" % locale.to_lower())
	root.size = Vector2i(1600, 900)
	if not _set_test_settings(settings):
		return
	await _frames(3)
	var audio: Node = full.get("audio")
	var preview := settings.duplicate(true)
	for key in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "keyboard_volume"]:
		preview[key] = 0.0
	preview["tool_volume"] = .25
	preview["notification_volume"] = .5
	preview["background_audio"] = false
	if not _set_test_settings(preview):
		return
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		_check(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)) == 0.0, "live settings provide true mute: " + bus)
	_check(audio.get("_event_volumes") == {"key": 0.0, "tool": .25, "notification": .5}, "keyboard/tools/notifications have independent live levels")
	audio.call("set_volumes", {"mute": true})
	_check(AudioServer.is_bus_mute(0), "master mute is honored")
	audio.call("set_volumes", {"mute": false})
	var playing_music: Array[AudioStreamPlayer] = []
	for player in audio.get("_music"):
		if player.has_stream_playback():
			playing_music.append(player)
	_check(not playing_music.is_empty(), "integrated score has a real active playback before focus/pause checks")
	root.focus_exited.emit()
	await _frames(2)
	_check(not audio.get("_background_active") and audio.get("_ambience").stream_paused, "Window focus loss pauses ambience through the real integration signal")
	for player in playing_music:
		_check(player.stream_paused, "background policy pauses every playing crossfade part")
	root.focus_entered.emit()
	await _frames(2)
	_check(audio.get("_background_active") and not audio.get("_ambience").stream_paused, "Window focus return resumes preserved playback")
	await _key(KEY_PAUSE)
	_check(desktop.paused and audio.get("_paused") and desktop.pause_overlay.visible, "native Pause opens UI and pauses the integrated score")
	_check(audio.get("_ambience").stream_paused, "pause includes ambience")
	var active_player: AudioStreamPlayer = audio.get("_music")[audio.get("_active")]
	_check(active_player.has_stream_playback() and active_player.stream_paused, "UI pause preserves and pauses actual music playback")
	var active: String = desktop.active_id
	await _key(KEY_2, true)
	_check(desktop.active_id == active and desktop.game.export_snapshot() == snapshot, "pause blocks app shortcuts and world mutation")
	await _focus_and_click(desktop.pause_resume_btn)
	_check(not desktop.paused and not audio.get("_paused"), "actual resume button resumes the integrated score")
	if not _set_test_settings(settings):
		return
	await _frames(2)
	_check(room.get("settings_store").get_values() == settings, "all settings previews leave the stored preference object unchanged")
	_check(desktop.game.export_snapshot() == snapshot, "locale/audio/focus/pause tests preserve the canonical world")


func _set_test_settings(values: Dictionary) -> bool:
	var store: RefCounted = room.get("settings_store")
	var path := str(store.get("_path"))
	var isolated: bool = path.begins_with("user://tests/") and path == str(room.get("settings_path"))
	_check(isolated, "preference setup cannot touch the default settings path")
	if not isolated:
		return false
	var result: Dictionary = store.call("update_settings", values)
	_check(result.get("ok", false), "isolated preferences apply through the real settings signal")
	return result.get("ok", false)


func _windows_fit(label: String) -> void:
	var bounds: Rect2 = desktop.layer.get_global_rect()
	for id in desktop.wins:
		var window: Control = desktop.wins[id]["win"]
		if window.visible:
			var rect := window.get_global_rect()
			_check(rect.position.x >= bounds.position.x - 1 and rect.position.y >= bounds.position.y - 1
				and rect.end.x <= bounds.end.x + 1 and rect.end.y <= bounds.end.y + 1, "visible window stays inside desktop at 1280/large text: %s/%s" % [label, id])


func _ending_checks() -> void:
	await _open_app("board")
	_check(desktop.bd_ending_btn.visible, "real campaign completion exposes the ending action")
	await _focus_and_click(desktop.bd_ending_btn)
	_check(desktop.active_id == "ending", "actual board ending button opens the ending screen")
	var choice: Button
	for child in desktop.en_choices.get_children():
		if child is Button and not child.disabled:
			choice = child
			break
	_check(choice != null, "an ending is available from actual completed facts")
	if choice == null:
		return
	await _focus_and_click(choice)
	_check(desktop.confirm.visible, "ending selection uses the real confirmation dialog")
	await _confirm_dialog(desktop.confirm)
	await _frames(3)
	var ending: Dictionary = desktop.get_game_view().get("ending", {})
	_check(not ending.is_empty(), "confirmed ending is selected by the authoritative campaign")
	_check(desktop.en_chosen_title.visible and desktop.en_chosen_title.text == str(ending.get("title", "")), "ending screen renders the chosen title")
	_check(desktop.en_chosen_text.text == str(ending.get("text", "")) and not desktop.en_chosen_text.text.is_empty(), "ending screen renders the real outcome narrative")
	_check(desktop.en_credits.visible and not desktop.en_credits.text.is_empty(), "ending screen exposes credits")
	_assert_mood(desktop.get_game_view(), "real chosen ending")
	await _capture("full-ending-credits.png")
	await _click(desktop.save_btn)
	var probe := Campaign.new(slot)
	var loaded: Dictionary = probe.load_game()
	_check(loaded.get("ok", false) and probe.get_view().get("ending", {}).get("id") == ending.get("id"), "real chosen ending survives isolated save/load")


func _mail_matches_current() -> void:
	await _open_app("mail")
	var messages: Array = desktop.get_game_view().get("messages", [])
	_check(not messages.is_empty(), "current real mission provides narrative mail")
	if messages.is_empty():
		return
	var current: Dictionary = messages.back()
	_check(desktop.mail_subject.text == str(current.get("subject", "")), "mail selection updates to the current mission/reply subject")
	_check(desktop.mail_body.get_parsed_text().strip_edges() == str(current.get("body", "")).strip_edges(), "mail body cache matches the current mission/reply")


func _select_case(id: String) -> bool:
	await _open_app("board")
	var item := _case_item(desktop.bd_tree.get_root(), id)
	_check(item != null, "case exists in actual board tree: " + id)
	if item == null:
		return false
	item.select(0)
	desktop.bd_tree.scroll_to_item(item)
	desktop.bd_tree.item_selected.emit()
	await _frames(2)
	_check(desktop.bd_selected == id and not desktop.bd_switch_btn.disabled, "available case can be selected through the real board: " + id)
	await _focus_and_click(desktop.bd_switch_btn)
	await _frames(2)
	_check(desktop.get_game_view().get("mission_id") == id, "case switch button changes the real campaign: " + id)
	return desktop.get_game_view().get("mission_id") == id


func _case_item(item: TreeItem, id: String) -> TreeItem:
	if item == null:
		return null
	if item.get_metadata(0) != null and str(item.get_metadata(0)) == id:
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _case_item(child, id)
		if found != null:
			return found
		child = child.get_next()
	return null


func _keyboard_focus_checks() -> void:
	_check(desktop.terms.size() == 4, "four independent terminal controls exist")
	await _open_terminal(0)
	var input: LineEdit = desktop.terms[0]["input"]
	input.text = "focus-preserved-draft"
	var before: Dictionary = desktop.game.export_snapshot()
	for index in range(9):
		await _key(KEY_1 + index, true)
		var expected: String = ["term0", "mail", "browser", "requestlab", "tools", "files", "archive", "board", "status"][index]
		_check(desktop.active_id == expected, "native app shortcut %d selects %s" % [index + 1, expected])
		_check(input.text == "focus-preserved-draft", "app shortcut never types into terminal draft")
	_check(desktop.game.export_snapshot() == before, "presentation shortcuts preserve real campaign state")
	await _key(KEY_F6)
	_check(root.gui_get_focus_owner() == desktop.launcher_button, "F6 moves keyboard focus to launcher")
	await _key(KEY_F6, false, true)
	_check(root.gui_get_focus_owner() == desktop.font_down_btn, "Shift F6 reaches text-size control")
	await _open_terminal(0)
	var size_before: int = desktop.ui_size
	await _click(desktop.font_down_btn)
	_check(desktop.ui_size == size_before - 1, "actual mouse press/release activates font button")
	_check(root.gui_get_focus_owner() == input and input.text == "focus-preserved-draft",
		"toolbar click restores terminal focus after activation without losing draft")
	var larger: Button = desktop.font_up_btn
	_check(larger != null, "font-size restoration action exists")
	if larger != null:
		await _click(larger)
		_check(desktop.ui_size == size_before, "font button pair restores initial size")
	input.clear()
	input.grab_focus()
	await _key(KEY_NONE, false, false, "한".unicode_at(0))
	_check(input.text == "한", "actual Unicode InputEvent commits Korean text to the focused terminal")
	await _key(KEY_2, true)
	_check(desktop.active_id == "mail" and input.text == "한", "app shortcut preserves committed CJK draft")
	await _key(KEY_3, true, false, 0, true)
	_check(desktop.active_id == "mail", "echo key cannot repeat app switching")
	var source := FileAccess.get_file_as_string("res://scripts/apps/campaign_desktop.gd")
	_check(source.contains("has_ime_text()"), "source retains a platform IME composition guard (physical composition remains NOT_RUN)")
	await _open_terminal(0)
	input.clear()


func _terminal_session_checks() -> void:
	await _submit("pwd")
	var input: LineEdit = desktop.terms[0]["input"]
	input.text = "history-draft"
	await _key(KEY_UP)
	_check(input.text == "pwd", "native Up recalls terminal-local command history")
	await _key(KEY_DOWN)
	_check(input.text == "history-draft", "native Down restores unsent draft")
	var before_auth: Dictionary = desktop.game.export_snapshot()
	await _submit("ssh guest@archive.packet.test")
	_check(input.secret and not input.context_menu_enabled, "authentication masks password and disables context menu")
	input.text = "not-submitted-secret"
	await _key(KEY_UP)
	_check(input.text == "not-submitted-secret", "history navigation cannot replace a pending password")
	await _key(KEY_TAB)
	_check(input.text == "not-submitted-secret", "completion cannot expose a pending password")
	# Password Tab permits normal focus traversal; target the input before testing its Escape handler.
	input.grab_focus()
	await _frames(1)
	await _key(KEY_ESCAPE)
	_check(not input.secret and not desktop.game.get_view(0).password_pending, "native Escape cancels authentication")
	_check(not desktop.paused, "Escape on the focused password input does not open pause")
	_check(desktop.game.export_snapshot() == before_auth, "cancelled authentication preserves world and alert")
	await _submit("ssh guest@archive.packet.test")
	await _submit("guest")
	_check(not desktop.terms[0]["history"].has("guest"), "password never enters command history")
	var remote: Dictionary = desktop.game.get_view(0)
	_check(remote.host == "archive" and remote.user == "guest", "terminal zero owns its authenticated remote session")
	for index in range(1, 4):
		await _submit("pwd", index)
		var view: Dictionary = desktop.game.get_view(index)
		_check(view.host == "local" and view.user == "player", "terminal %d retains independent local identity" % index)
		desktop.terms[index]["input"].text = "terminal-%d-draft" % index
		_check(not desktop.terms[index]["history"].has("ssh guest@archive.packet.test"), "terminal %d history is isolated" % index)
	await _open_terminal(0)
	input.text = "retained-terminal-draft"
	var world_before: Dictionary = desktop.game.export_snapshot()
	var close: Button = desktop.wins["term0"]["actions"]["close"]
	_check(close != null, "terminal window has an actual close button")
	if close != null:
		await _click(close)
		_check(not desktop.wins["term0"]["win"].visible, "mouse close hides terminal window")
		await _open_terminal(0)
		_check(desktop.terms[0]["input"] == input and input.text == "retained-terminal-draft", "reopening keeps the same terminal input and draft")
		_check(desktop.game.export_snapshot() == world_before and desktop.game.get_view(0).host == "archive",
			"close/reopen never logs out or replaces the session")
	await _capture("full-four-terminals.png")
	await _password_replacement_checks()
	await _frames(2)


func _password_replacement_checks() -> void:
	var input: LineEdit = desktop.terms[0]["input"]
	var secret := "unsubmitted-exit-canary"
	await _submit("ssh maint@archive.packet.test")
	_check(input.secret, "UI-01 Exit precondition is actual pending authentication")
	input.text = secret
	var exit_button := _button_text(desktop.wins["term0"]["win"], desktop._t("UI_TERM_EXIT"))
	_check(exit_button != null, "actual terminal Exit button exists")
	if exit_button != null:
		await _focus_and_click(exit_button)
	_assert_secret_cleared(secret, "Exit")
	input.clear()
	secret = "unsubmitted-new-canary"
	await _submit("ssh maint@archive.packet.test")
	input.text = secret
	await _key(KEY_F10)
	await _key(KEY_ESCAPE)
	var new_game := _button_text(room.get("menu_box"), str(TranslationServer.translate("NEW_GAME")))
	_check(new_game != null, "actual New Game menu action exists during pending authentication")
	if new_game != null:
		await _click(new_game)
		await _confirm_dialog(room.get("confirm"))
	await _frames(3)
	_assert_secret_cleared(secret, "confirmed New Game")
	_check(desktop.get_game_view().get("host") == "local" and desktop.game.get("_save_path") == slot, "actual New Game replacement stays in the isolated slot")
	input.clear()
	secret = "unsubmitted-load-canary"
	await _submit("ssh guest@archive.packet.test")
	input.text = secret
	await _click(desktop.load_btn)
	_check(desktop.confirm.visible, "actual Load button opens replacement confirmation")
	await _confirm_dialog(desktop.confirm)
	await _frames(3)
	_assert_secret_cleared(secret, "confirmed Load")
	input.clear()
	_check(desktop.game.get("_save_path") == slot, "Load replacement reads only the injected test slot")


func _assert_secret_cleared(secret: String, action: String) -> void:
	var terminal: Dictionary = desktop.terms[0]
	var input: LineEdit = terminal.input
	_check(not input.secret and input.text.is_empty(), "UI-01 pending secret is cleared before plain input after " + action)
	_check(int(terminal.hist_idx) == -1 and str(terminal.draft).is_empty(), "UI-01 password-mode history cursor/draft reset after " + action)
	_check(not terminal.history.has(secret) and not terminal.out.get_parsed_text().contains(secret), "UI-01 unsubmitted secret never reaches history/output after " + action)


func _file_observation_checks() -> void:
	await _submit("cd /home/player", 1)
	if not (await _select_tool("filelens")):
		return
	var archive: Array = desktop.get_game_view().get("archive", [])
	_check(not archive.is_empty(), "UI-03 FileLens uses an actually recovered record")
	if archive.is_empty():
		return
	var path: String = archive[0].path
	var input: LineEdit = desktop.tool_inputs["path"]
	input.text = path
	var result := await _run_selected_tool()
	_check(result.get("ok", false), "UI-03 FileLens displays a real read before cache changes")
	var observation: String = desktop.tool_result.get_parsed_text()
	input.text = "/home/player/held-filelens-draft.txt"
	await _submit("cd /home/player/archive", 1)
	await _open_app("tools")
	_assert_observation("filelens", "files", "path", input, "/home/player/held-filelens-draft.txt", observation, "cwd change")
	var copy := "/home/player/archive/qa_candidate_%d.log" % Time.get_ticks_usec()
	result = await _submit("cp %s %s" % [_quote_argument(path), _quote_argument(copy)], 1)
	_check(result.get("ok", false) and result.get("changed", false), "UI-03 actual virtual copy creates a new readable file")
	await _open_app("tools")
	_assert_observation("filelens", "files", "path", input, "/home/player/held-filelens-draft.txt", observation, "file addition")
	result = await _submit("rm " + _quote_argument(copy), 1)
	_check(result.get("ok", false), "UI-03 actual virtual removal deletes only the test copy")
	await _open_app("tools")
	_assert_observation("filelens", "files", "path", input, "/home/player/held-filelens-draft.txt", observation, "file removal")
	await _open_terminal(0)
	await _open_app("tools")
	_assert_observation("filelens", "files", "path", input, "/home/player/held-filelens-draft.txt", observation, "different terminal/account")


func _discovery_observation_checks() -> void:
	if not (await _select_tool("netprobe")):
		return
	var input: LineEdit = desktop.tool_inputs["target"]
	input.text = "transit04"
	var baseline := await _run_selected_tool()
	_check(baseline.get("ok", false), "UI-03 NetProbe has a real baseline observation")
	var observation: String = desktop.tool_result.get_parsed_text()
	var before: Array = _tool_data("netprobe").get("targets", []).duplicate(true)
	input.text = "held-netprobe-draft"
	var discovery := await _submit("nmap custodym03.packet.test")
	_check(discovery.get("ok", false) and discovery.get("changed", false), "UI-03 actual scan discovers a previously unknown reachable host")
	await _open_app("tools")
	_check(_tool_data("netprobe").get("targets", []).size() > before.size(), "UI-03 core discovery expands actual target candidates")
	_assert_observation("netprobe", "targets", "address", input, "held-netprobe-draft", observation, "host discovery")


func _actor_context_checks() -> void:
	await _open_terminal(0)
	if not (await _select_tool("m05_primary")):
		return
	var actor0: Dictionary = desktop.game.get_view(0)
	var actor1: Dictionary = desktop.game.get_view(1)
	_check(actor0.user != actor1.user and actor0.host != actor1.host, "UI-02 terminals have genuinely different authenticated actors")
	var input: LineEdit = desktop.tool_inputs["object_id"]
	input.text = "own"
	await _open_terminal(1)
	await _open_app("tools")
	var expected: String = desktop._t("UI_TOOL_OBS_ACTOR", {"n": 2, "user": actor1.user, "host": actor1.host})
	_check(desktop.tool_actor_label.text == expected, "UI-02 displayed actor updates to T2 before any model action")
	_check(desktop.tool_inputs["object_id"] == input and input.text == "own", "UI-02 terminal activation preserves the selected tool input")
	var before: Dictionary = desktop.game.export_snapshot()
	var result := await _run_selected_tool()
	_check(not result.get("ok", true) and result.get("code") == "AUTH_REQUIRED", "UI-02 actual T2 local actor cannot use T1's required session")
	_check(desktop.game.export_snapshot() == before, "UI-02 denied actor cannot acquire the authenticated actor's record")
	await _open_terminal(0)
	await _open_app("tools")
	expected = desktop._t("UI_TOOL_OBS_ACTOR", {"n": 1, "user": actor0.user, "host": actor0.host})
	_check(desktop.tool_actor_label.text == expected, "UI-02 displayed actor returns to T1 before its next action")


func _tool_data(id: String) -> Dictionary:
	for tool in desktop.game.get_view(desktop.active_term).get("tools", []):
		if tool.get("id") == id:
			return tool.get("data", {})
	return {}


func _assert_observation(id: String, collection: String, field: String, input: LineEdit, draft: String, result: String, action: String) -> void:
	var expected: Array[String] = []
	for entry in _tool_data(id).get(collection, []):
		expected.append(str(entry.get(field, "")))
	var actual: Array[String] = []
	for list in desktop.tool_obs_box.find_children("*", "ItemList", true, false):
		for index in range(list.item_count):
			actual.append(str(list.get_item_metadata(index)))
	expected.sort()
	actual.sort()
	_check(actual == expected, "UI-03 selected %s candidates match fresh authoritative data after %s" % [id, action])
	var key := "target" if collection == "targets" else "path"
	_check(desktop.tool_selected == id and desktop.tool_inputs.get(key) == input and input.text == draft, "UI-03 observation refresh preserves selection/input/draft after " + action)
	_check(desktop.tool_result.get_parsed_text() == result, "UI-03 observation refresh preserves prior result after " + action)


func _request_lab_checks() -> void:
	await _open_app("requestlab")
	var initial: Dictionary = desktop.game.export_snapshot()
	desktop.rl_method.select(0)
	desktop.rl_url.text = str(desktop.get_game_view().browser_home)
	desktop.rl_headers.text = "{}"
	desktop.rl_body.text = "[]"
	desktop.rl_url.grab_focus()
	action_result = {}
	await _key(KEY_ENTER)
	_check(desktop.rl_error.visible and action_result.is_empty(), "invalid RequestLab JSON is rejected before invoking the model")
	_check(desktop.game.export_snapshot() == initial, "invalid RequestLab JSON cannot mutate the world")
	var response := await _request("GET", str(desktop.get_game_view().browser_home))
	_check(response.get("status", 0) == 200 and not desktop.rl_response.get_parsed_text().is_empty(), "RequestLab renders the actual virtual response")
	_check(not desktop.rl_meta.text.is_empty() and not desktop.rl_trace.text.is_empty(), "RequestLab exposes acting identity, origin and request trace")
	await _capture("full-request-lab.png")
	var history_size: int = desktop.rl_history.size()
	response = await _request("GET", "https://example.com")
	_check(not response.get("ok", true) and not str(response.get("code", "")).is_empty(), "external request is a visible virtual-domain refusal")
	_check(desktop.rl_history.size() >= history_size, "RequestLab preserves editable request history")
	await _capture("full-request-refused.png")


func _request(method: String, url: String, body: Dictionary = {}, headers: Dictionary = {}) -> Dictionary:
	await _open_app("requestlab")
	var methods := ["GET", "POST", "PUT", "PATCH", "DELETE"]
	var index := methods.find(method)
	_check(index >= 0, "fixture uses a supported request method")
	if index < 0:
		return {}
	desktop.rl_method.select(index)
	desktop.rl_url.text = url
	desktop.rl_headers.text = JSON.stringify(headers)
	desktop.rl_body.text = JSON.stringify(body)
	desktop.rl_url.grab_focus()
	action_result = {}
	await _key(KEY_ENTER)
	_check(action_result.has("ok"), "native RequestLab Enter dispatches the real request model")
	return action_result.duplicate(true)


func _browse(url: String) -> Dictionary:
	await _open_app("browser")
	desktop.br_addr.text = url
	desktop.br_addr.grab_focus()
	action_result = {}
	await _key(KEY_ENTER)
	_check(action_result.has("ok"), "native browser Enter dispatches the shared request model")
	return action_result.duplicate(true)


func _use_tool(id: String, params: Dictionary) -> Dictionary:
	if id == "requestlab":
		return await _request(str(params.get("method", "GET")), str(params.get("url", "")), params.get("body", {}), params.get("headers", {}))
	if not (await _select_tool(id)):
		return {"ok": false, "code": "UI_TOOL_NOT_LISTED"}
	if not desktop.tool_adv_toggle.button_pressed:
		await _focus_and_click(desktop.tool_adv_toggle)
	_check(desktop.tool_adv_box.visible, "advanced model input is visible")
	desktop.tool_adv_edit.text = JSON.stringify(params)
	var run := _button_text(desktop.tool_adv_box, desktop._t("UI_TOOL_RUN_JSON"))
	_check(run != null, "advanced JSON has an actual execute button")
	if run == null:
		return {"ok": false, "code": "UI_TOOL_RUN_MISSING"}
	action_result = {}
	await _focus_and_click(run)
	_check(action_result.has("ok"), "actual Tools click dispatches the shared model")
	_check(not desktop.tool_result.get_parsed_text().is_empty(), "Tools renders the actual model observation")
	_check(not desktop.tool_model.text.is_empty() and not desktop.tool_limit.text.is_empty(), "Tools presents its model and limits")
	return action_result.duplicate(true)


func _select_tool(id: String) -> bool:
	await _open_app("tools")
	var selected := -1
	for index in range(desktop.tool_list.item_count):
		if str(desktop.tool_list.get_item_metadata(index)) == id:
			selected = index
	_check(selected >= 0, "actual model is selectable in Tools: " + id)
	if selected < 0:
		return false
	# Selection uses the real ItemList signal; execution uses the native mouse path.
	desktop.tool_list.select(selected)
	desktop.tool_list.item_selected.emit(selected)
	await _frames(2)
	_check(desktop.tool_selected == id, "Tools selection binds the requested real model")
	return desktop.tool_selected == id


func _run_selected_tool() -> Dictionary:
	action_result = {}
	await _focus_and_click(desktop.tool_run_btn)
	_check(action_result.has("ok"), "actual normal model Run button dispatches the shared backend")
	return action_result.duplicate(true)


func _fixture_action(action: Dictionary) -> Dictionary:
	match str(action.get("kind", "")):
		"command":
			return await _submit(str(action.get("line", "")), int(action.get("terminal_id", 0)))
		"password":
			return await _submit(str(action.get("value", "")), int(action.get("terminal_id", 0)))
		"browse":
			return await _browse(str(action.get("url", "")))
		"request":
			return await _request(str(action.get("method", "GET")), str(action.get("url", "")), action.get("body", {}), action.get("headers", {}))
		"tool":
			return await _use_tool(str(action.get("tool_id", "")), action.get("params", {}))
		"collect_web":
			await _browse(str(action.get("url", "")))
			_check(desktop.br_archive.visible, "the real page exposes its record collection action")
			action_result = {}
			await _focus_and_click(desktop.br_archive)
			return action_result.duplicate(true)
	_check(false, "unsupported UI fixture action must fail: " + str(action.get("kind", "")))
	return {"ok": false, "code": "UNSUPPORTED_UI_FIXTURE_ACTION"}


func _focus_and_click(control: Control) -> void:
	if not is_instance_valid(control):
		_check(false, "focus/click target is unavailable")
		return
	control.grab_focus()
	await _frames(2)
	await _click(control)


func _assert_mood(view: Dictionary, label: String) -> void:
	var expected := "investigate"
	if not view.get("ending", {}).is_empty():
		expected = "ending"
	elif view.get("completed", false):
		expected = "flow"
	elif int(view.get("alert_level", 0)) > 0:
		expected = "alert"
	elif str(view.get("mission_id", "")) in ["M12", "M16", "M20", "M24"]:
		expected = "reveal"
	elif str(view.get("mission_id", "")) in ["M01", "M02"]:
		expected = "intro"
	_check(full.get("audio").get("current_mood") == expected, "actual campaign audio priority: " + label + " → " + expected)


func _open_app(id: String) -> void:
	var shortcuts := ["terminal", "mail", "browser", "requestlab", "tools", "files", "archive", "board", "status"]
	var index := shortcuts.find(id)
	if index >= 0:
		await _key(KEY_1 + index, true)
	else:
		var button: Button = desktop.launcher_buttons.get(id)
		_check(button != null, "real launcher action exists: " + id)
		if button == null:
			return
		if not desktop.launcher_panel.visible:
			await _click(desktop.launcher_button)
		button.grab_focus()
		await _frames(2)
		await _click(button)
	_check(desktop.active_id == id or (id == "terminal" and desktop.active_id.begins_with("term")),
		"keyboard or taskbar opens the actual app: " + id)


func _open_terminal(index: int) -> void:
	await _key(KEY_1 + index, true, true)
	_check(desktop.active_term == index and desktop.active_id == "term%d" % index,
		"native shortcut selects independent terminal %d" % index)


func _submit(text: String, terminal := 0) -> Dictionary:
	await _open_terminal(terminal)
	var input: LineEdit = desktop.terms[terminal]["input"]
	input.text = text
	input.caret_column = text.length()
	input.grab_focus()
	action_result = {}
	await _key(KEY_ENTER)
	await _frames(1)
	_check(action_result.has("ok"), "native Enter dispatches a domain action (terminal %d)" % terminal)
	return action_result.duplicate(true)


func _quote_argument(value: Variant) -> String:
	var text: String = value if value is String else JSON.stringify(value)
	return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"") + "\""


func _property(object: Object, key: String) -> bool:
	for entry in object.get_property_list():
		if entry.name == key:
			return true
	return false


func _require_fields(object: Object, fields: Array) -> bool:
	var valid := true
	for field in fields:
		var present := _property(object, field)
		_check(present, "required integration field: " + str(field))
		valid = valid and present
	return valid


func _require_methods(object: Object, methods: Array) -> bool:
	var valid := true
	for method in methods:
		var present := object.has_method(method)
		_check(present, "required integration method: " + str(method))
		valid = valid and present
	return valid


func _confirm_dialog(dialog: AcceptDialog) -> void:
	var button := dialog.get_ok_button()
	var viewport := button.get_viewport()
	button.grab_focus()
	await _frames(1)
	_check(viewport.gui_get_focus_owner() == button, "embedded dialog keyboard focus reaches its actual OK button")
	await _key(KEY_ENTER, false, false, 0, false, viewport)
	_check(not dialog.visible, "actual Enter accepts and closes the embedded dialog")


func _key(code: int, command := false, shift := false, unicode := 0, echo := false, viewport: Viewport = null) -> void:
	var target := viewport if viewport != null else root
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = command
	event.meta_pressed = command
	event.shift_pressed = shift
	event.unicode = unicode
	event.echo = echo
	event.pressed = true
	target.push_input(event, true)
	await _frames(1)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	event.echo = false
	target.push_input(event, true)
	await _frames(1)


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "mouse target exists and is visible")
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	_check(viewport.get_visible_rect().has_point(point), "mouse target lies in its viewport")
	await _pointer_click(viewport, point)


func _click_local(control: Control, local_point: Vector2) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "point input target is a real visible Control")
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var point := control.get_global_transform_with_canvas() * local_point
	_check(control.get_viewport().get_visible_rect().has_point(point), "point input lies in target viewport")
	await _pointer_click(control.get_viewport(), point)


func _pointer_click(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	viewport.push_input(event, true)
	await _frames(1)
	# Complete the injected pointer stream after any native motion during the held frame.
	var return_motion := motion.duplicate() as InputEventMouseMotion
	return_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(return_motion, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	viewport.push_input(event, true)
	await _frames(2)


func _button_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button_text(child, text)
		if found != null:
			return found
	return null


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _capture(filename: String) -> void:
	await _frames(2)
	# Static or occluded windows need not draw during input waits; explicitly render each capture.
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	_check(not image.is_empty(), "renderer returns pixels: " + filename)
	if image.is_empty():
		return
	var minimum := 1.0
	var maximum := 0.0
	for x in range(1, 8):
		for y in range(1, 8):
			var pixel := image.get_pixel(int(image.get_width() * x / 8), int(image.get_height() * y / 8))
			var value := pixel.get_luminance()
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
	_check(maximum - minimum > .005, "render is not a single flat clear color: " + filename)
	var path := output_dir.path_join(filename)
	var error := image.save_png(path)
	_check(error == OK, "PNG written inside full-production artifacts: " + filename)
	if error == OK:
		captures.append(path)
		capture_metrics.append({"path": path, "width": image.get_width(), "height": image.get_height(),
			"min_sample_luminance": minimum, "max_sample_luminance": maximum,
			"sha256": FileAccess.get_sha256(path)})


func _fingerprints() -> Dictionary:
	var result := {}
	for path in PROTECTED:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if finished:
		return
	finished = true
	_cleanup_and_report.call_deferred()


func _cleanup_and_report() -> void:
	if is_instance_valid(full):
		full.set_process_input(false)
		full.process_mode = Node.PROCESS_MODE_DISABLED
		var players := full.find_children("*", "AudioStreamPlayer", true, false)
		for player in players:
			player.stop()
		for index in range(3):
			await process_frame
		for player in players:
			if is_instance_valid(player):
				player.stream = null
		current_scene = null
		full.queue_free()
		full = null
		room = null
		desktop = null
		for index in range(4):
			await process_frame
		await create_timer(.2).timeout
	if not before_files.is_empty():
		_check(_fingerprints() == before_files, "default campaign/legacy/preferences bytes remain unchanged")
	print(JSON.stringify({"suite": "rendered_full_game", "checks": checks, "failures": failures,
		"profile": profile, "expected_scope": {"cases": 1 if profile == "ci-render-smoke" else 28,
			"main_cases": 1 if profile == "ci-render-smoke" else 24, "optional_cases": 0 if profile == "ci-render-smoke" else 4,
			"locales": Localization.LOCALES, "ending": profile == "full"},
		"elapsed_seconds": float(Time.get_ticks_msec() - started_ms) / 1000.0,
		"capture_dir": output_dir, "captures": captures, "capture_metrics": capture_metrics, "campaign_cases": campaign_cases,
		"test_save_slot": slot, "not_run": not_run,
		"limit": "Actual source-scene rendering and injected native InputEvents; physical IME/hearing/other OS acceptance are separate."}))
	quit.call_deferred(0 if failures.is_empty() else 1)
