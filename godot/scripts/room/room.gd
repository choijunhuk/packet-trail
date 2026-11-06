extends Node3D

signal desktop_requested(action: String)
signal room_entered
signal settings_changed(values: Dictionary)
signal application_focus_changed(active: bool)
signal campaign_selected(pack_id: String)
signal quit_requested

const Store = preload("res://scripts/presentation/settings_store.gd")
const DesktopTheme = preload("res://scripts/presentation/desktop_theme.gd")
const SettingsPanel = preload("res://scripts/presentation/settings_panel.gd")
const StudioWorld = preload("res://scripts/room/studio_world.gd")
const Localization = preload("res://scripts/presentation/localization.gd")
const FALLBACK := {
	"SUPPORT_SCOPE_SHORT": "목표와 경보 규칙은 같고, 자동 안내량이 달라집니다.",
	"LOBBY_ROOM_SHORT": "작업실",
	"LOBBY_CHOOSE_STORY": "오늘 밤, 어느 쪽에 설까요?",
	"LOBBY_ROLE_INTRUDER": "단서를 따라 침투하고 감춰진 기록을 회수합니다.",
	"LOBBY_ROLE_DEFENDER": "위협을 막으면서 시민과 동료의 업무를 지킵니다.",
	"LOBBY_ROLE_CHALLENGE": "침투·방어·추적을 조합하는 고급 사건입니다. 기본 조작을 익힌 뒤 도전하세요.",
	"CAMPAIGN_CHALLENGE": "종합 도전",
	"LOBBY_ROLE_TRACKER": "기록의 출처와 시간을 비교해 연결을 추적합니다.",
	"LOBBY_CASE_COUNTS": "본편 {main} · 선택 {optional}",
	"LOBBY_CASE_COUNT": "독립 이야기 · {total}개 사건",
	"SUPPORT_TITLE": "플레이 지원",
	"SUPPORT_GUIDED": "가이드",
	"SUPPORT_STANDARD": "표준",
	"SUPPORT_INDEPENDENT": "자율",
	"SUPPORT_GUIDED_DESC": "새 의뢰와 첫 방향 안내를 열고 초반 힌트를 함께 보여 줍니다.",
	"SUPPORT_STANDARD_DESC": "바탕화면에서 직접 앱을 열고 필요할 때 단계별 힌트를 요청합니다.",
	"SUPPORT_INDEPENDENT_DESC": "자동 길잡이를 줄입니다. 도움말과 수동 힌트는 언제든 사용할 수 있습니다.",
	"SUPPORT_SCOPE": "안내와 힌트 표시량을 선택합니다. 목표·경보 규칙과 허용 해법은 같으며 설정에서 바꿀 수 있습니다.",
	"SUPPORT_NOT_SAVED": "지원 설정을 저장하지 못했습니다. 이번 플레이에는 적용됩니다.",
	"SETTINGS_PLAY": "플레이 지원",
	"SETTINGS_DISPLAY_TAB": "화면",
	"SETTINGS_AUDIO_TAB": "음향",
	"SETTINGS_CONTROLS_TAB": "조작",
	"SETTINGS_SUPPORT_FOR": "{campaign} 지원 수준",
	"SETTINGS_AUDIO_DETAILS": "세부 소리",
	"SETTINGS_CONTROLS_NOTE": "작업실: WASD 이동 · 마우스 오른쪽 시선 · E 컴퓨터 · F10 작업실 복귀. 데스크톱 도움말에서 앱과 터미널 단축키를 확인할 수 있습니다.",
	"ROOM_TITLE": "심야접속", "ROOM_SUBTITLE": "비가 그치기 전, 다음 기록을 찾는다.",
	"CONTINUE": "계속하기", "NEW_GAME": "새 게임", "LOAD_GAME": "불러오기", "SETTINGS": "설정",
	"CREDITS": "제작 정보", "QUIT": "종료", "ENTER_ROOM": "작업실 둘러보기", "BACK": "돌아가기",
	"COMPUTER_USE": "E · 컴퓨터 사용", "RETURN_TO_ROOM": "F10 · 작업실로",
	"ROOM_CONTROLS": "WASD 이동 · 마우스 오른쪽 버튼 시선 · E 컴퓨터 · Esc 메뉴",
	"NEW_GAME_CONFIRM": "기존 캠페인을 백업하고 새 진행으로 저장 슬롯을 대체합니다. M01 구버전 저장은 유지됩니다.",
	"START_NEW": "새 진행 시작", "CANCEL": "취소", "DESKTOP_NOT_READY": "데스크톱 연결을 준비하지 못했습니다.",
	"IMPORT_LEGACY": "구버전 M01 가져오기",
	"IMPORT_CONFIRM": "M01 구버전 저장은 유지됩니다. 가져온 진행으로 현재 캠페인 슬롯을 교체하며, 기존 캠페인이 있으면 백업합니다.",
	"CREDITS_BODY": "독립 제작 해킹 시뮬레이터\n가상 서버·명령만 사용합니다.\n\nNoto Sans KR · SIL Open Font License 1.1",
	"CAMPAIGN_SELECT": "캠페인 선택", "CAMPAIGN_INTRUDER": "침투자", "CAMPAIGN_DEFENDER": "방어자", "CAMPAIGN_TRACKER": "추적자",
	"CAMPAIGN_INTRUDER_DESC": "닫힌 경로를 열고 숨겨진 기록을 회수하세요.",
	"CAMPAIGN_DEFENDER_DESC": "위협을 막으면서 정상 업무를 지키세요.",
	"CAMPAIGN_TRACKER_DESC": "관측과 반증으로 연결을 좁히세요.",
	"CAMPAIGN_PROGRESS": "진행 {done}/{total}", "CAMPAIGN_NO_SAVE": "아직 저장된 진행 없음",
	"CAMPAIGN_SAVE_ATTENTION": "저장 상태를 확인하거나 백업을 복구할 수 있습니다.",
	"CAMPAIGN_NEW_CONFIRM": "{campaign}의 기존 진행을 백업하고 새로 시작합니다. 다른 캠페인과 이전판 저장은 유지됩니다.",
	"LEGACY_CONTINUE": "이전판 계속", "LEGACY_CONTINUE_DESC": "이전판 진행은 새 캠페인과 별도로 보존됩니다.",
	"LEGACY_SOURCE_UNSUPPORTED": "이전판 저장을 찾았지만 현재 검증을 통과하지 못했습니다. 원본은 보존되며 새 캠페인에 반영되지 않습니다. 이유: {code}",
	"CAMPAIGN_IMPORT_CONFIRM": "구버전 M01을 이전판 캠페인으로 가져옵니다. 이전판 슬롯이 있으면 백업 후 교체하며, 새 캠페인 저장은 유지됩니다.",
	"UI_CONFIRM_LOAD": "디스크의 마지막 저장으로 되돌립니다.\n저장하지 않은 현재 진행은 사라집니다.",
}

@export var desktop_scene: PackedScene
@export var desktop_save_slot_path := "user://saves/campaign_01.json"
@export var has_saved_session := false
@export var has_legacy_session := false
@export var selected_pack_id := "intruder"
var campaign_slots: Dictionary = {}
var campaign_buttons: Dictionary = {}
var support_summary: Label
var support_picker: OptionButton
var settings_path := Store.PATH
var _chosen_support: Dictionary = {}
var _session_support: Dictionary = {}
var _pending_support := ""
var _preferences_readable := true
var campaign_progress: Label
var legacy_continue_button: Button
var legacy_notice: Label
var _campaigns: Array = []
var _desktops: Dictionary = {}
var _active_pack_id := ""
var _legacy_campaign_available := false
var _legacy_campaign_problem := ""
var _menu_focus_target: Control
var settings_store := Store.new()
var studio: Node3D
var player: CharacterBody3D
var camera: Camera3D
var menu_camera: Camera3D
var desktop: Control
var desktop_layer: CanvasLayer
var overlay: CanvasLayer
var menu: Control
var menu_box: VBoxContainer
var hint: Label
var note: Label
var continue_button: Button
var load_button: Button
var import_button: Button
var settings_panel: PanelContainer
var settings_scrim: ColorRect
var confirm: ConfirmationDialog
var _in_desktop := false
var _looking := false
var _pitch := -0.05
var _theme := Theme.new()
var _desktop_windows: Array[Window] = []
var _desktop_window_generations: Dictionary = {}
var _pending_action := ""
var _pending_pack_id := ""


func _text(key: String, replacements: Dictionary = {}) -> String:
	var translated := TranslationServer.translate(key)
	var result: String = FALLBACK.get(key, key) if translated == key else translated
	return result.format(replacements) if not replacements.is_empty() else result


func _ready() -> void:
	settings_store = Store.new(settings_path)
	var loaded: Dictionary = settings_store.load_settings()
	_preferences_readable = bool(loaded.get("ok", false))
	Localization.configure(settings_store.get_values()["locale"])
	if DisplayServer.get_name() != "headless":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	settings_store.changed.connect(_on_preferences_committed)
	studio = StudioWorld.new()
	studio.name = "Studio"
	add_child(studio)
	_build_player()
	_build_interface()
	_apply_settings(settings_store.get_values())
	get_window().focus_entered.connect(func(): application_focus_changed.emit(true))
	get_window().focus_exited.connect(_on_focus_lost)
	show_main_menu()


func set_session_available(available: bool) -> void:
	has_saved_session = available
	if continue_button != null:
		var cached = _desktops.get(selected_pack_id)
		continue_button.disabled = not available and not (is_instance_valid(cached) and cached.session_active)
		load_button.disabled = not available


func set_legacy_session_available(available: bool) -> void:
	has_legacy_session = available
	if import_button != null:
		import_button.disabled = not available
		import_button.visible = available


func set_campaigns(entries: Array) -> void:
	_campaigns = entries.duplicate(true)
	var ids: Array = []
	for entry in _campaigns:
		ids.append(str(entry.get("id", "")))
	if not ids.has(selected_pack_id) and not ids.is_empty():
		selected_pack_id = str(ids[0])
	if menu_box != null:
		if campaign_buttons.size() != _campaigns.size():
			_rebuild_menu()
		else:
			_update_campaign_details()

func set_legacy_campaign_available(available: bool, problem := "") -> void:
	_legacy_campaign_available = available
	_legacy_campaign_problem = problem
	if legacy_continue_button != null:
		legacy_continue_button.visible = available or not problem.is_empty()
		legacy_continue_button.disabled = not available
	if legacy_notice != null:
		legacy_notice.text = problem
		legacy_notice.visible = not problem.is_empty()


func select_campaign(id: String) -> bool:
	for entry in _campaigns:
		if str(entry.get("id", "")) == id:
			selected_pack_id = id
			_update_campaign_details()
			campaign_selected.emit(id)
			return true
	return false


func _campaign_entry() -> Dictionary:
	for entry in _campaigns:
		if str(entry.get("id", "")) == selected_pack_id:
			return entry
	return {}


func get_cached_desktop(id: String) -> Control:
	return _desktops.get(id)


func _campaign_title(id: String) -> String:
	return _text("LEGACY_CONTINUE") if id == "legacy_intruder" else _text("CAMPAIGN_" + id.to_upper())


func _update_campaign_details() -> void:
	var entry := _campaign_entry()
	for id in campaign_buttons:
		var button: Button = campaign_buttons[id]
		button.set_pressed_no_signal(id == selected_pack_id)
	var progress: Dictionary = entry.get("progress", {})
	var state := str(entry.get("save_state", "empty"))
	if campaign_progress != null:
		campaign_progress.text = _text("CAMPAIGN_NO_SAVE") if state == "empty" else (_text("CAMPAIGN_SAVE_ATTENTION") if state == "recovery" else _text("CAMPAIGN_PROGRESS", {"done": progress.get("completed", 0), "total": progress.get("total", 0)}))
	var level := _support_for_selection()
	if support_picker != null:
		for index in range(support_picker.item_count):
			if support_picker.get_item_metadata(index) == level:
				support_picker.select(index)
	if support_summary != null:
		support_summary.text = _text("SUPPORT_" + level.to_upper() + "_DESC")
	set_session_available(bool(entry.get("disk_available", entry.get("can_continue", false))))


func _support_for_selection() -> String:
	return str(_chosen_support.get(selected_pack_id, presentation_settings().get("support_" + selected_pack_id, "standard")))


func presentation_settings(base_values: Dictionary = {}) -> Dictionary:
	var values: Dictionary = settings_store.get_values() if base_values.is_empty() else base_values.duplicate(true)
	for id in _session_support:
		values["support_" + str(id)] = _session_support[id]
	return values


func select_support(level: String) -> bool:
	if not level in ["guided", "standard", "independent"]:
		return false
	_chosen_support[selected_pack_id] = level
	_update_campaign_details()
	return true

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.05, 0.05, 1.9)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	player.add_child(shape)
	add_child(player)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.63, 0)
	camera.rotation.x = _pitch
	camera.fov = 65.0
	player.add_child(camera)
	menu_camera = Camera3D.new()
	menu_camera.fov = 55.0
	menu_camera.position = Vector3(3.05, 1.93, 3.05)
	add_child(menu_camera)
	menu_camera.look_at(Vector3(-0.1, 1.35, -1.9))


func _build_interface() -> void:
	_theme = DesktopTheme.create(float(settings_store.get_values()["font_scale"]))
	desktop_layer = CanvasLayer.new()
	desktop_layer.layer = 4
	add_child(desktop_layer)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = _theme
	overlay.add_child(menu)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.047, 0.09, 0.96)
	veil.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 600
	menu.add_child(veil)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margins.offset_left = 38
	margins.offset_right = 562
	margins.offset_top = 24
	margins.offset_bottom = -20
	menu.add_child(margins)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 8)
	margins.add_child(menu_box)
	_rebuild_menu()
	hint = Label.new()
	hint.theme = _theme
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 30
	hint.offset_top = -58
	hint.offset_right = -30
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_outline_size", 5)
	overlay.add_child(hint)
	confirm = ConfirmationDialog.new()
	confirm.theme = _theme
	confirm.dialog_autowrap = true
	confirm.borderless = true
	confirm.exclusive = true
	confirm.add_theme_stylebox_override("panel", DesktopTheme.panel(DesktopTheme.SURFACE, DesktopTheme.ACCENT, 8, 22))
	confirm.confirmed.connect(_on_menu_confirmed)
	confirm.canceled.connect(_cancel_menu_confirmation)
	overlay.add_child(confirm)

func _rebuild_menu() -> void:
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	campaign_buttons.clear()
	var title := Label.new()
	title.text = _text("ROOM_TITLE")
	title.add_theme_font_size_override("font_size", roundi(34.0 * settings_store.get_values()["font_scale"]))
	menu_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _text("LOBBY_CHOOSE_STORY")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", DesktopTheme.MUTED)
	menu_box.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	menu_box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	for entry in _campaigns:
		var id := str(entry.get("id", ""))
		var button := Button.new()
		button.set_meta("scenario_id", id)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 68
		var optional := int(entry.get("optional_count", 0))
		var count := _text("LOBBY_CASE_COUNTS", {"main": entry.get("main_count", 0), "optional": optional}) if optional > 0 else _text("LOBBY_CASE_COUNT", {"total": entry.get("main_count", 0)})
		button.text = _campaign_title(id) + "  ·  " + count + "\n" + _text("LOBBY_ROLE_" + id.to_upper())
		button.accessibility_name = _campaign_title(id) + ": " + _text("LOBBY_ROLE_" + id.to_upper())
		button.pressed.connect(select_campaign.bind(id))
		body.add_child(button)
		campaign_buttons[id] = button
	campaign_progress = Label.new()
	campaign_progress.add_theme_color_override("font_color", DesktopTheme.ACCENT_SOFT)
	campaign_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_box.add_child(campaign_progress)
	var support_row := HBoxContainer.new()
	menu_box.add_child(support_row)
	var support_title := Label.new()
	support_title.text = _text("SUPPORT_TITLE")
	support_row.add_child(support_title)
	support_picker = OptionButton.new()
	support_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support_picker.set_meta("support_selector", true)
	support_picker.accessibility_name = _text("SUPPORT_TITLE")
	for level in ["guided", "standard", "independent"]:
		support_picker.add_item(_text("SUPPORT_" + level.to_upper()))
		support_picker.set_item_metadata(support_picker.item_count - 1, level)
	support_picker.item_selected.connect(func(index: int): select_support(str(support_picker.get_item_metadata(index))))
	support_row.add_child(support_picker)
	support_summary = Label.new()
	support_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_box.add_child(support_summary)
	var scope := Label.new()
	scope.text = _text("SUPPORT_SCOPE_SHORT")
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope.add_theme_font_size_override("font_size", roundi(15.0 * settings_store.get_values()["font_scale"]))
	scope.add_theme_color_override("font_color", DesktopTheme.MUTED)
	menu_box.add_child(scope)
	legacy_continue_button = _button("LEGACY_CONTINUE", func(): open_desktop("legacy"))
	legacy_continue_button.set_meta("pack_id", "legacy_intruder")
	legacy_continue_button.tooltip_text = _text("LEGACY_CONTINUE_DESC")
	menu_box.remove_child(legacy_continue_button)
	body.add_child(legacy_continue_button)
	legacy_continue_button.visible = _legacy_campaign_available or not _legacy_campaign_problem.is_empty()
	legacy_continue_button.disabled = not _legacy_campaign_available
	legacy_notice = Label.new()
	legacy_notice.text = _legacy_campaign_problem
	legacy_notice.visible = not _legacy_campaign_problem.is_empty()
	legacy_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy_notice.add_theme_color_override("font_color", DesktopTheme.WARNING)
	body.add_child(legacy_notice)
	import_button = _button("IMPORT_LEGACY", _confirm_import)
	menu_box.remove_child(import_button)
	body.add_child(import_button)
	import_button.visible = has_legacy_session
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", DesktopTheme.WARNING)
	body.add_child(note)
	var primary := HBoxContainer.new()
	menu_box.add_child(primary)
	continue_button = _button("CONTINUE", func(): open_desktop("continue", selected_pack_id, _support_for_selection()))
	continue_button.set_meta("lobby_action", "continue")
	menu_box.remove_child(continue_button)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.add_child(continue_button)
	var new_game := _button("NEW_GAME", _confirm_new)
	new_game.set_meta("lobby_action", "new")
	new_game.add_theme_stylebox_override("normal", DesktopTheme.panel(Color("244d80"), DesktopTheme.ACCENT, 6, 12))
	menu_box.remove_child(new_game)
	new_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.add_child(new_game)
	var actions := HBoxContainer.new()
	menu_box.add_child(actions)
	load_button = _button("LOAD_GAME", _confirm_load)
	load_button.set_meta("lobby_action", "load")
	menu_box.remove_child(load_button)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(load_button)
	for key in ["SETTINGS", "ENTER_ROOM", "QUIT"]:
		var callback: Callable = show_settings if key == "SETTINGS" else (return_to_room if key == "ENTER_ROOM" else func(): quit_requested.emit())
		var button := _button(key, callback)
		menu_box.remove_child(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("lobby_action", key.to_lower())
		button.tooltip_text = _text(key)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if key == "ENTER_ROOM":
			button.text = _text("LOBBY_ROOM_SHORT")
		actions.add_child(button)
	set_session_available(has_saved_session)
	set_legacy_session_available(has_legacy_session)
	_update_campaign_details()

func _button(key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = _text(key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 43
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	normal.content_margin_left = 17
	normal.set_corner_radius_all(4)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color("203d48")
	selected.border_color = Color("72b7bc")
	selected.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("focus", selected)
	button.pressed.connect(callback)
	menu_box.add_child(button)
	return button


func _confirm_new() -> void:
	_menu_focus_target = get_viewport().gui_get_focus_owner()
	_pending_action = "new"
	_pending_pack_id = selected_pack_id
	_pending_support = _support_for_selection()
	confirm.title = _text("NEW_GAME")
	confirm.dialog_text = _text("CAMPAIGN_NEW_CONFIRM", {"campaign": _campaign_title(selected_pack_id)}) + "\n\n" + _text("SUPPORT_TITLE") + ": " + _text("SUPPORT_" + _pending_support.to_upper())
	confirm.ok_button_text = _text("START_NEW")
	confirm.cancel_button_text = _text("CANCEL")
	confirm.popup_centered(Vector2i(540, 220))


func _confirm_import() -> void:
	_menu_focus_target = get_viewport().gui_get_focus_owner()
	_pending_support = ""
	_pending_action = "import"
	_pending_pack_id = "legacy_intruder"
	confirm.title = _text("IMPORT_LEGACY")
	confirm.dialog_text = _text("CAMPAIGN_IMPORT_CONFIRM")
	confirm.ok_button_text = _text("IMPORT_LEGACY")
	confirm.cancel_button_text = _text("CANCEL")
	confirm.popup_centered(Vector2i(540, 240))


func _confirm_load() -> void:
	var cached = _desktops.get(selected_pack_id)
	if not is_instance_valid(cached) or not cached.session_active:
		open_desktop("load", selected_pack_id, _support_for_selection())
		return
	_menu_focus_target = get_viewport().gui_get_focus_owner()
	_pending_action = "load"
	_pending_pack_id = selected_pack_id
	_pending_support = _support_for_selection()
	confirm.title = _text("LOAD_GAME")
	confirm.dialog_text = _text("UI_CONFIRM_LOAD")
	confirm.ok_button_text = _text("LOAD_GAME")
	confirm.cancel_button_text = _text("CANCEL")
	confirm.popup_centered(Vector2i(540, 220))


func _on_menu_confirmed() -> void:
	var action := _pending_action
	var pack := _pending_pack_id
	var level := _pending_support
	_pending_action = ""
	_pending_pack_id = ""
	_pending_support = ""
	if not action.is_empty() and not pack.is_empty():
		open_desktop(action, pack, level)

func _cancel_menu_confirmation() -> void:
	_pending_support = ""
	_pending_action = ""
	_pending_pack_id = ""
	_restore_menu_focus()


func _restore_menu_focus() -> void:
	call_deferred("_restore_menu_focus_now")


func _restore_menu_focus_now() -> void:
	if is_instance_valid(_menu_focus_target) and _menu_focus_target.is_visible_in_tree():
		_menu_focus_target.grab_focus()
	else:
		_focus_menu()


func open_desktop(action := "continue", target_pack := "", support_level := "") -> void:
	if target_pack.is_empty():
		target_pack = "legacy_intruder" if action in ["legacy", "import"] else selected_pack_id
	var slot := str(campaign_slots.get(target_pack, ""))
	if slot.is_empty():
		show_main_menu()
		note.text = _text("DESKTOP_NOT_READY")
		return
	_hide_desktop()
	desktop = _desktops.get(target_pack)
	desktop_save_slot_path = slot
	if desktop == null:
		if desktop_scene == null:
			show_main_menu()
			note.text = _text("DESKTOP_NOT_READY")
			return
		var instance := desktop_scene.instantiate()
		if not instance is Control:
			instance.queue_free()
			note.text = _text("DESKTOP_NOT_READY")
			return
		instance.set("save_slot_path", slot)
		instance.set("pack_id", target_pack)
		desktop = instance
		_desktops[target_pack] = desktop
		desktop_layer.add_child(desktop)
		desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var support_notice := ""
	var presentation := presentation_settings()
	if target_pack != "legacy_intruder" and support_level in ["guided", "standard", "independent"]:
		presentation["support_" + target_pack] = support_level
	if desktop.has_method("apply_settings"):
		desktop.apply_settings(presentation)
	if desktop.has_method("start_session"):
		var result: Variant = desktop.call("start_session", "continue" if action == "legacy" else action)
		if result is Dictionary and not result.get("ok", true):
			show_main_menu()
			note.text = str(result.get("text", _text("DESKTOP_NOT_READY")))
			return
	elif action != "continue":
		show_main_menu()
		note.text = _text("DESKTOP_NOT_READY")
		return
	if target_pack != "legacy_intruder" and support_level in ["guided", "standard", "independent"]:
		_session_support[target_pack] = support_level
		var key := "support_" + target_pack
		if settings_store.get_values().get(key, "standard") != support_level:
			var saved := {"ok": false}
			if _preferences_readable:
				var patch := {}
				for id in _session_support:
					patch["support_" + str(id)] = _session_support[id]
				saved = settings_store.update_settings(patch)
			if not saved.get("ok", false):
				support_notice = _text("SUPPORT_NOT_SAVED")
	_active_pack_id = target_pack
	desktop.visible = true
	desktop.process_mode = Node.PROCESS_MODE_INHERIT
	var retained: Array[Window] = []
	var retained_generations := {}
	for window in _desktop_windows:
		if is_instance_valid(window):
			if desktop.is_ancestor_of(window):
				if _desktop_window_generations.get(window.get_instance_id()) == desktop.get("session_generation"):
					window.show()
			else:
				retained.append(window)
				retained_generations[window.get_instance_id()] = _desktop_window_generations.get(window.get_instance_id())
	_desktop_windows = retained
	_desktop_window_generations = retained_generations
	_in_desktop = true
	# The desktop is opaque; avoid rendering the studio behind its interface.
	studio.hide()
	menu.hide()
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hint.text = _text("RETURN_TO_ROOM")
	hint.hide()
	desktop_requested.emit(action)
	if not support_notice.is_empty():
		desktop.show_notice(support_notice)


func return_to_room() -> void:
	studio.show()
	_hide_desktop()
	_in_desktop = false
	menu.hide()
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_looking = false
	hint.show()
	room_entered.emit()


func show_main_menu() -> void:
	studio.show()
	_hide_desktop()
	_in_desktop = false
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_camera.make_current()
	menu.show()
	hint.hide()
	set_session_available(has_saved_session)
	_focus_menu()


func _hide_desktop() -> void:
	if desktop == null:
		return
	# Window is not a CanvasItem: hiding its Control parent does not hide embedded app windows.
	for child in desktop.find_children("*", "Window", true, false):
		if child.visible:
			if not child in _desktop_windows:
				_desktop_windows.append(child)
			_desktop_window_generations[child.get_instance_id()] = desktop.get("session_generation")
			child.hide()
	desktop.hide()
	desktop.process_mode = Node.PROCESS_MODE_DISABLED


func _focus_menu() -> void:
	if menu == null or not menu.visible:
		return
	var selected: Button = campaign_buttons.get(selected_pack_id)
	if is_instance_valid(selected):
		selected.grab_focus()
	elif is_instance_valid(continue_button) and not continue_button.disabled:
		continue_button.grab_focus()

func show_settings() -> void:
	if settings_panel != null:
		return
	settings_scrim = ColorRect.new()
	settings_scrim.color = Color(0.01, 0.02, 0.03, 0.78)
	settings_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(settings_scrim)
	settings_panel = SettingsPanel.new()
	var viewport := get_viewport().get_visible_rect().size
	var size := Vector2(minf(840, viewport.x - 56), minf(760, viewport.y - 60))
	overlay.add_child(settings_panel)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -size.x * 0.5
	settings_panel.offset_right = size.x * 0.5
	settings_panel.offset_top = -size.y * 0.5
	settings_panel.offset_bottom = size.y * 0.5
	settings_panel.setup(settings_store, presentation_settings())
	settings_panel.closed.connect(func():
		settings_panel.queue_free()
		settings_panel = null
		settings_scrim.queue_free()
		settings_scrim = null
		_rebuild_menu()
		_focus_menu())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_credits() -> void:
	note.text = _text("CREDITS_BODY")


func _on_preferences_committed(values: Dictionary) -> void:
	_preferences_readable = true
	_apply_settings(values)


func _apply_settings(values: Dictionary) -> void:
	Localization.set_locale(values["locale"])
	_theme = DesktopTheme.create(float(values["font_scale"]))
	_chosen_support.clear()
	_session_support.clear()
	if menu != null:
		menu.theme = _theme
	if hint != null:
		hint.theme = _theme
	if confirm != null:
		confirm.theme = _theme
	if camera != null:
		camera.fov = 60.0 if values["comfort_mode"] else 72.0
	if studio != null:
		studio.set_reduced_motion(values["reduced_motion"])
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	for pair in [["Master", "master_volume"], ["Music", "music_volume"], ["SFX", "sfx_volume"], ["UI", "ui_volume"], ["Ambience", "ambience_volume"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, values[pair[1]])))
	if menu_box != null:
		_rebuild_menu()
	settings_changed.emit(values)


func _on_focus_lost() -> void:
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	application_focus_changed.emit(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10 and _in_desktop:
		return_to_room()
		get_viewport().set_input_as_handled()
	if _in_desktop or menu.visible or settings_panel != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and _looking:
		var sensitivity: float = settings_store.get_values()["mouse_sensitivity"]
		player.rotation.y -= deg_to_rad(event.relative.x * sensitivity)
		_pitch = clampf(_pitch - deg_to_rad(event.relative.y * sensitivity), -1.0, 0.8)
		camera.rotation.x = _pitch


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _in_desktop:
		return
	if event.keycode == KEY_ESCAPE:
		if settings_panel != null:
			settings_panel.closed.emit()
		elif menu.visible:
			return_to_room()
		else:
			show_main_menu()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_E and not menu.visible and _can_use_computer():
		open_desktop("continue", _active_pack_id)
		get_viewport().set_input_as_handled()


func _can_use_computer() -> bool:
	var direction: Vector3 = studio.computer_position - camera.global_position
	return direction.length() < 3.7 and (-camera.global_basis.z).dot(direction.normalized()) > 0.55


func _physics_process(delta: float) -> void:
	if player == null or menu == null or menu.visible or _in_desktop or settings_panel != null:
		return
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := player.basis * Vector3(input.x, 0, input.y).normalized()
	var speed := 1.7 if settings_store.get_values()["comfort_mode"] else 2.4
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y -= 9.8 * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -3.4, 3.15)
	player.position.z = clampf(player.position.z, -2.9, 2.8)
	hint.text = _text("COMPUTER_USE") if _can_use_computer() else _text("ROOM_CONTROLS")
