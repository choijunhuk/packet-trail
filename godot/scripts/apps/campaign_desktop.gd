extends Control
## 심야접속 · 전체 캠페인 가상 데스크톱 (표시 전용 UI).
## 세계 상태·판정·권한·저장은 CampaignGame 코어만 소유한다. 이 화면은 get_view()를 그리고
## 공개 API(execute/submit_password/cancel_authentication/autocomplete/browse/request/collect_web/
## use_tool/choose_mission/advance/choose_ending/get_hint/save_game/load_game/recover_save/
## start_new_save/import_legacy_save)만 요청한다.
## 실제 셸·네트워크·웹뷰·OS.shell_open·저장 파일 직접 접근은 사용하지 않는다.
## 증거 핀·비교·메모는 이 화면 안의 보조 표시일 뿐 저장이나 완료 판정에 쓰이지 않는다.

signal return_to_room_requested
signal view_changed(view: Dictionary)
signal campaign_finished(ending: Dictionary)
signal pause_changed(paused: bool)
signal action_performed(result: Dictionary)
signal settings_requested

const CampaignGame = preload("res://scripts/core/campaign_game.gd")
const Localization = preload("res://scripts/presentation/localization.gd")

const C_BG := Color(0.034, 0.050, 0.062)
const C_PANEL := Color(0.064, 0.086, 0.102, 0.98)
const C_FIELD := Color(0.036, 0.052, 0.062)
const C_BAR := Color(0.086, 0.114, 0.132)
const C_BAR_ACTIVE := Color(0.092, 0.160, 0.172)
const C_LINE := Color(0.19, 0.26, 0.29)
const C_TEXT := Color(0.91, 0.94, 0.95)
const C_DIM := Color(0.64, 0.72, 0.75)
const C_FAINT := Color(0.47, 0.54, 0.57)
const C_TEAL := Color(0.40, 0.80, 0.78)
const C_TEAL_DIM := Color(0.53, 0.77, 0.77)
const C_AMBER := Color(0.94, 0.67, 0.33)

const TERMS := 4
const MAX_LOG_PARAGRAPHS := 900
const MAX_HISTORY := 120
const MAX_INPUT := 512
const MAX_JSON_CHARS := 8192
const MAX_TABLE_ROWS := 200
const MIN_WIN := Vector2(360, 220)
const PORTRAIT_DIR := "res://assets/portraits/"
const METHODS := ["GET", "POST", "PUT", "PATCH", "DELETE"]
const CHARACTERS := ["C01", "C02", "C03", "C04"]
# 얼굴 공개 시점(해당 사건 완료 뒤). 빈 값은 등장 즉시 공개. 코어가 characters 메타데이터를 주면 그쪽을 우선한다.
const FACE_GATES := {"C01": "M12", "C02": "", "C03": "M16", "C04": "M20"}
# 이 화면이 전용 설명(UI_TOOLKIND_*)을 가진 모델 종류. 그 밖의 종류는 일반 설명과 JSON/단일 입력으로 표시한다.
const TOOL_KINDS := ["query", "render", "path", "exec", "fetch", "permission", "audit", "reverse", "memory",
		"packet", "trace", "compare", "token", "policy", "idor", "auth", "session", "csrf", "upload",
		"scan", "route", "file", "log"]

# 데스크톱 크기 대비 기본 위치/크기
const APP_RECTS := {
	"term0": Rect2(0.010, 0.025, 0.500, 0.950),
	"term1": Rect2(0.050, 0.065, 0.460, 0.740),
	"term2": Rect2(0.090, 0.105, 0.460, 0.740),
	"term3": Rect2(0.130, 0.145, 0.460, 0.740),
	"mail": Rect2(0.520, 0.025, 0.470, 0.540),
	"board": Rect2(0.520, 0.585, 0.470, 0.390),
	"browser": Rect2(0.080, 0.040, 0.620, 0.900),
	"requestlab": Rect2(0.200, 0.050, 0.640, 0.900),
	"tools": Rect2(0.110, 0.030, 0.740, 0.940),
	"files": Rect2(0.240, 0.080, 0.520, 0.720),
	"archive": Rect2(0.260, 0.070, 0.600, 0.840),
	"status": Rect2(0.580, 0.050, 0.400, 0.880),
	"help": Rect2(0.550, 0.030, 0.430, 0.920),
	"ending": Rect2(0.160, 0.040, 0.680, 0.920),
}
const APP_TITLES := {
	"mail": "UI_APP_MAIL", "browser": "UI_APP_BROWSER", "requestlab": "UI_APP_REQUESTLAB",
	"tools": "UI_APP_TOOLS", "files": "UI_APP_FILES", "archive": "UI_APP_ARCHIVE",
	"board": "UI_APP_BOARD", "status": "UI_APP_STATUS", "help": "UI_APP_HELP", "ending": "UI_APP_ENDING",
}
const TASK_APPS := ["mail", "browser", "requestlab", "tools", "files", "archive", "board", "status", "help", "ending"]
# Ctrl/Cmd+1..9
const SHORTCUTS := ["terminal", "mail", "browser", "requestlab", "tools", "files", "archive", "board", "status"]

@export var save_slot_path: String = "user://saves/campaign_01.json"

var game = null
var session_active := false
var autosave_suspended := false
var last_view: Dictionary = {}
var last_mission := ""
var term_views: Array = [{}, {}, {}, {}]
var term_live: Array = [true, false, false, false]
var active_term := 0
var paused := false
var reduced_motion := false

var ui_theme := Theme.new()
var ui_font: FontVariation
var terminal_font: FontVariation
var font_scale := 1.0
var font_step := 0
var ui_size := 17
var term_size := 19
var top_h := 36
var task_h := 48
var sized: Array = []  # [Control, delta, is_terminal]
var _i18n: Array = []  # [Object, property, key, replacements]
var _fallback_lang := ""
var _fallback_strings: Dictionary = {}
var _texture_cache: Dictionary = {}

var sb_frame_on: StyleBoxFlat
var sb_frame_off: StyleBoxFlat
var sb_bar_on: StyleBoxFlat
var sb_bar_off: StyleBoxFlat

# 셸
var layer: Control
var top_panel: PanelContainer
var task_panel: PanelContainer
var top_mission: Label
var top_progress: Label
var top_alert: Label
var top_host: Label
var top_save: Label
var font_down_btn: Button
var pause_btn: Button
var task_scroll: ScrollContainer
var task_buttons := {}
var term_task_buttons: Array = []
var status_label: Label
var save_btn: Button
var load_btn: Button
var recover_btn: Button
var fresh_btn: Button
var room_btn: Button
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var confirm: ConfirmationDialog
var confirm_action := Callable()
var pause_overlay: Control
var pause_resume_btn: Button
var recovery_overlay: Control
var recovery_text: Label
var recovery_recover_btn: Button
var recovery_fresh_btn: Button
var recovery_continue_btn: Button
var fatal_overlay: Control
var fatal_label: Label
var _focus_before_pause = null  # Control 또는 null (해제됐을 수 있어 타입을 두지 않는다)
var _focus_before_hide = null

# 창
var wins := {}  # id -> {win, frame, bar, title, focus, state, placed, restore}
var active_id := ""
var drag := {}

# 터미널: 창마다 독립 출력·기록·입력 초안·암호 대기 상태
var terms: Array = []

# 메일
var mail_list: ItemList
var mail_avatar_tex: TextureRect
var mail_avatar_glyph: Label
var mail_avatar_box: PanelContainer
var mail_subject: Label
var mail_sender: Label
var mail_meta: Label
var mail_reveal_btn: Button
var mail_body: RichTextLabel
var mail_read := {}
var mail_selected := ""
var mail_shown_key := ""
var mail_reveal_char := ""
var face_disclosed := {}

# 브라우저
var br_addr: LineEdit
var br_back: Button
var br_fwd: Button
var br_title: Label
var br_meta: Label
var br_body: RichTextLabel
var br_links: VBoxContainer
var br_status: Label
var br_stale: Label
var br_archive: Button
var br_form_toggle: Button
var br_form_box: VBoxContainer
var br_method: OptionButton
var br_field: LineEdit
var br_value: LineEdit
var br_user: LineEdit
var br_pass: LineEdit
var br_history: Array[String] = []
var br_cursor := -1
var br_url := ""
var br_failed := false
var br_opened := false

# RequestLab
var rl_method: OptionButton
var rl_url: LineEdit
var rl_headers: TextEdit
var rl_body: TextEdit
var rl_error: Label
var rl_recent: OptionButton
var rl_status: Label
var rl_meta: Label
var rl_trace: Label
var rl_response: RichTextLabel
var rl_history: Array = []

# 도구 작업대
var tool_list: ItemList
var tool_empty: Label
var tool_detail: VBoxContainer
var tool_title: Label
var tool_kind: Label
var tool_desc: Label
var tool_usage: Label
var tool_req: Label
var tool_obs_box: VBoxContainer
var tool_input_box: VBoxContainer
var tool_adv_toggle: CheckButton
var tool_adv_box: VBoxContainer
var tool_adv_edit: TextEdit
var tool_run_btn: Button
var tool_result_status: Label
var tool_result: RichTextLabel
var tool_model: Label
var tool_limit: Label
var tool_inputs := {}
var tool_selected := ""
var tool_ids_sig := ""
var tool_observation_sig := ""
var tool_drafts := {}
var tool_tree: Tree
var tool_row_keys: Array = []
var tool_memory: MemoryGrid
var tool_xor_key: LineEdit
var tool_xor_out: Label

# 파일
var fs_term: OptionButton
var fs_path: Label
var fs_list: ItemList
var fs_title: Label
var fs_out: RichTextLabel
var files_term := 0

# 보관 자료
var ar_list: ItemList
var ar_meta: Label
var ar_body: RichTextLabel
var ar_pin_btn: Button
var ar_compare_toggle: CheckButton
var ar_compare_box: VBoxContainer
var ar_compare_meta: Label
var ar_compare_body: RichTextLabel
var ar_notes: TextEdit
var ar_selected := ""
var ar_pinned := ""
var ar_shown_key := ""

# 사건 보드
var bd_tree: Tree
var bd_title: Label
var bd_state: Label
var bd_goal: Label
var bd_obj_head: Label
var bd_objectives: VBoxContainer
var bd_stage_head: Label
var bd_milestones: VBoxContainer
var bd_switch_btn: Button
var bd_next_btn: Button
var bd_ending_btn: Button
var bd_hint_buttons: Array = []
var bd_hint_hide: Button
var bd_hint_text: Label
var bd_chapters: Label
var bd_selected := ""
var hints_revealed := 0

# 상태·네트워크
var st_mission: Label
var st_alert: Label
var st_alert_explain: Label
var st_sessions: Label
var st_policies: Label
var st_facts: Label
var net_map: NetMap

# 도움말
var hp_goal: Label

# 결말
var en_intro: Label
var en_choices: VBoxContainer
var en_chosen_title: Label
var en_chosen_text: Label
var en_credits: Label
var en_sig := ""


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	theme = ui_theme
	_build_shell()
	_build_windows()
	_build_overlays()
	_font_apply()
	_relocalize()
	visibility_changed.connect(_on_visibility_changed)
	# 코어만 만든다. 디스크 읽기/쓰기는 Room이 start_session을 호출할 때만 한다.
	game = CampaignGame.new(save_slot_path)
	if not _game_ready(game):
		_show_fatal(_s(_d(game.get_view()), "error", _t("UI_ERR_NO_VIEW")))


# ── 공개 통합 API ─────────────────────────────────────────────

## Room이 확인을 마친 뒤 호출한다. new/continue/load/import.
func start_session(action: String) -> Dictionary:
	_set_paused(false)
	match action:
		"continue":
			if session_active and _game_ready(game):
				_resume()
				return {"ok": true, "code": "RESUMED", "text": ""}
			return _load_from_disk()
		"load":
			return _load_from_disk()
		"new":
			return _begin_new()
		"import":
			return _begin_import()
	return {"ok": false, "code": "UI_UNKNOWN_SESSION_ACTION", "text": _t("UI_ERR_UNKNOWN_SESSION_ACTION", {"action": action})}


## 디스크를 바꾸지 않고 이어하기 가능 여부만 확인한다.
func can_continue() -> bool:
	if session_active and _game_ready(game):
		return true
	var probe = CampaignGame.new(save_slot_path)
	var r := _d(probe.load_game())
	return _b(r, "ok") or _b(r, "backup_available") or _s(r, "code") != "SAVE_NOT_FOUND"


func get_game_view() -> Dictionary:
	if game == null:
		return {}
	return _view(active_term)


func apply_settings(values: Dictionary) -> void:
	if values.has("locale"):
		Localization.set_locale(str(values["locale"]))
	var scale_value = values.get("font_scale", font_scale)
	if scale_value is float or scale_value is int:
		font_scale = clampf(float(scale_value), 0.75, 2.0)
	var motion = values.get("reduced_motion", reduced_motion)
	if motion is bool:
		reduced_motion = motion
	_tool_save_draft()
	_font_apply()
	_relocalize()
	if br_url != "":
		br_stale.visible = true
	if game != null and _game_ready(game):
		_refresh_all()
		var tool := _tool_current()
		if not tool.is_empty():
			_tool_show(tool, true)
		en_sig = ""
		_refresh_ending(last_view)


# ── 안전한 읽기 도우미 ─────────────────────────────────────────

static func _s(d: Dictionary, k: String, def: String = "") -> String:
	var x = d.get(k, def)
	return def if x == null else str(x)


static func _i(d: Dictionary, k: String, def: int = 0) -> int:
	var x = d.get(k, def)
	if x is int or x is float:
		return int(x)
	return def


static func _b(d: Dictionary, k: String, def: bool = false) -> bool:
	var x = d.get(k, def)
	if x is bool:
		return x
	return def


static func _a(d: Dictionary, k: String) -> Array:
	var x = d.get(k, [])
	if x is Array:
		return x
	if x is PackedStringArray:
		return Array(x)
	return []


static func _d(x) -> Dictionary:
	if x is Dictionary:
		return x
	return {}


func _game_ready(g) -> bool:
	if g == null:
		return false
	return _b(_d(g.get_view()), "ready", false)


func _view(t: int) -> Dictionary:
	if game == null:
		return {}
	return _d(game.get_view(t))


func _modal_open() -> bool:
	return (confirm != null and confirm.visible) or (recovery_overlay != null and recovery_overlay.visible) \
			or (fatal_overlay != null and fatal_overlay.visible)


func _can_act() -> bool:
	return game != null and not paused and not fatal_overlay.visible and not recovery_overlay.visible


# ── 현지화 ─────────────────────────────────────────────────────

## 공유 번역(PO)을 먼저 쓰고, 아직 병합되지 않은 UI 키는 이 앱의 원본 문자열로 표시한다.
func _t(key: String, repl: Dictionary = {}) -> String:
	var s: String = Localization.tr_key(key)
	if s == key:
		s = str(_fallback().get(key, key))
	return s.format(repl) if not repl.is_empty() else s


func _fallback() -> Dictionary:
	var lang := "ko" if Localization.get_locale().begins_with("ko") else "en"
	if lang != _fallback_lang:
		_fallback_lang = lang
		_fallback_strings = {}
		var path := "res://assets/ui/strings_%s.json" % lang
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is JSON and res.data is Dictionary:
				_fallback_strings = res.data
	return _fallback_strings


func _reg(node: Object, prop: String, key: String, repl: Dictionary = {}) -> void:
	_i18n.append([node, prop, key, repl])
	node.set(prop, _t(key, repl))


func _relocalize() -> void:
	var kept: Array = []
	for e in _i18n:
		if is_instance_valid(e[0]):
			e[0].set(e[1], _t(e[2], e[3]))
			kept.append(e)
	_i18n = kept
	if confirm != null:
		confirm.title = _t("UI_CONFIRM_TITLE")
		confirm.ok_button_text = _t("UI_OK")
		confirm.cancel_button_text = _t("UI_CANCEL")
	_br_form_label()
	if rl_recent != null:
		_rl_rebuild_recent()
	_update_taskbar()


# ── 테마 ──────────────────────────────────────────────────────

func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 3, margin: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _build_theme() -> void:
	var t := ui_theme
	ui_font = FontVariation.new()
	ui_font.base_font = Localization.get_font()
	ui_font.variation_embolden = 0.4
	ui_font.variation_opentype = {"wght": 500.0}
	terminal_font = FontVariation.new()
	terminal_font.base_font = Localization.get_mono_font()
	terminal_font.variation_opentype = {"wght": 500.0, "wdth": 100.0}
	t.default_font = ui_font
	t.default_font_size = ui_size
	for cls in ["Label", "Button", "LineEdit", "ItemList", "TextEdit", "Tree", "OptionButton", "CheckButton", "CheckBox", "PopupMenu"]:
		t.set_color("font_color", cls, C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_color("font_selected_color", "RichTextLabel", Color.WHITE)
	t.set_color("selection_color", "RichTextLabel", Color(0.22, 0.45, 0.46, 0.6))
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, C_TEXT)
		t.set_color("font_pressed_color", cls, C_TEAL)
		t.set_color("font_hover_pressed_color", cls, C_TEAL)
		t.set_color("font_disabled_color", cls, Color(0.40, 0.45, 0.47))
	for cls in ["LineEdit", "TextEdit"]:
		t.set_color("font_placeholder_color", cls, Color(0.43, 0.50, 0.53))
		t.set_color("caret_color", cls, C_TEAL)
		t.set_color("selection_color", cls, Color(0.22, 0.45, 0.46, 0.6))
		t.set_color("font_readonly_color", cls, C_DIM)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(0.2, 0.27, 0.3, 0.6))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	var focus := _sb(Color(0, 0, 0, 0), C_TEAL, 2, 3, 6)
	focus.draw_center = false
	var focus_thin := _sb(Color(0, 0, 0, 0), Color(0.36, 0.70, 0.69), 1, 3, 4)
	focus_thin.draw_center = false
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _sb(Color(0.105, 0.145, 0.165), C_LINE, 1, 3, 6))
		t.set_stylebox("hover", cls, _sb(Color(0.135, 0.195, 0.215), Color(0.30, 0.54, 0.55), 1, 3, 6))
		t.set_stylebox("pressed", cls, _sb(Color(0.085, 0.195, 0.205), C_TEAL, 1, 3, 6))
		t.set_stylebox("disabled", cls, _sb(Color(0.075, 0.095, 0.105), Color(0.15, 0.2, 0.22), 1, 3, 6))
		t.set_stylebox("focus", cls, focus)
	for cls in ["CheckButton", "CheckBox"]:
		t.set_stylebox("focus", cls, focus)
	t.set_stylebox("normal", "LineEdit", _sb(C_FIELD, C_LINE, 1, 3, 6))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", _sb(Color(0.05, 0.06, 0.07), C_LINE, 1, 3, 6))
	t.set_stylebox("normal", "TextEdit", _sb(C_FIELD, C_LINE, 1, 3, 6))
	t.set_stylebox("focus", "TextEdit", focus)
	t.set_stylebox("read_only", "TextEdit", _sb(Color(0.05, 0.06, 0.07), C_LINE, 1, 3, 6))
	t.set_stylebox("panel", "ItemList", _sb(Color(0.044, 0.064, 0.074), C_LINE, 1, 3, 4))
	t.set_stylebox("focus", "ItemList", focus_thin)
	t.set_stylebox("selected", "ItemList", _sb(Color(0.11, 0.22, 0.23), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("selected_focus", "ItemList", _sb(Color(0.12, 0.27, 0.28), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("hovered", "ItemList", _sb(Color(0.085, 0.135, 0.145), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_constant("v_separation", "ItemList", 5)
	t.set_stylebox("panel", "Tree", _sb(Color(0.044, 0.064, 0.074), C_LINE, 1, 3, 4))
	t.set_stylebox("focus", "Tree", focus_thin)
	t.set_stylebox("selected", "Tree", _sb(Color(0.11, 0.22, 0.23), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("selected_focus", "Tree", _sb(Color(0.12, 0.27, 0.28), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("title_button_normal", "Tree", _sb(C_BAR, C_LINE, 0, 0, 4))
	t.set_stylebox("title_button_hover", "Tree", _sb(C_BAR, C_LINE, 0, 0, 4))
	t.set_stylebox("title_button_pressed", "Tree", _sb(C_BAR, C_LINE, 0, 0, 4))
	t.set_color("title_button_color", "Tree", C_DIM)
	t.set_constant("v_separation", "Tree", 4)
	t.set_constant("item_margin", "Tree", 14)
	t.set_stylebox("normal", "RichTextLabel", _sb(C_FIELD, C_LINE, 1, 3, 9))
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, C_LINE, 1, 4, 0))
	t.set_stylebox("panel", "PopupMenu", _sb(Color(0.06, 0.085, 0.095), C_LINE, 1, 3, 6))
	t.set_stylebox("hover", "PopupMenu", _sb(Color(0.11, 0.22, 0.23), Color(0, 0, 0, 0), 0, 2, 4))
	t.set_stylebox("panel", "TooltipPanel", _sb(Color(0.055, 0.075, 0.085), C_LINE, 1, 3, 7))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "AcceptDialog", _sb(Color(0.066, 0.09, 0.105), Color(0.30, 0.55, 0.56), 1, 5, 16))
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _sb(Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 0, 3, 2))
		t.set_stylebox("grabber", bar, _sb(Color(0.24, 0.32, 0.35), Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_highlight", bar, _sb(Color(0.32, 0.50, 0.51), Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_pressed", bar, _sb(C_TEAL, Color(0, 0, 0, 0), 0, 3, 3))
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HSplitContainer", 8)
	t.set_constant("separation", "VSplitContainer", 8)

	sb_frame_off = _sb(C_PANEL, C_LINE, 1, 5, 1)
	sb_frame_off.shadow_color = Color(0, 0, 0, 0.38)
	sb_frame_off.shadow_size = 12
	sb_frame_on = sb_frame_off.duplicate()
	sb_frame_on.border_color = Color(0.30, 0.60, 0.60)
	sb_bar_off = _sb(C_BAR, Color(0, 0, 0, 0), 0, 0, 3)
	sb_bar_off.corner_radius_top_left = 5
	sb_bar_off.corner_radius_top_right = 5
	sb_bar_off.content_margin_left = 12
	sb_bar_on = sb_bar_off.duplicate()
	sb_bar_on.bg_color = C_BAR_ACTIVE


func _size(c: Control, delta: int, term: bool = false) -> void:
	sized.append([c, delta, term])
	_apply_size(c, delta, term)


func _apply_size(c: Control, delta: int, term: bool) -> void:
	var key := "normal_font_size" if c is RichTextLabel else "font_size"
	c.add_theme_font_size_override(key, maxi((term_size if term else ui_size) + delta, 10))
	if term:
		c.add_theme_font_override("normal_font" if c is RichTextLabel else "font", terminal_font)


func _font_apply() -> void:
	ui_size = clampi(roundi(17.0 * font_scale) + font_step, 13, 34)
	term_size = clampi(roundi(19.0 * font_scale) + font_step, 14, 36)
	ui_theme.default_font_size = ui_size
	var kept: Array = []
	for e in sized:
		if is_instance_valid(e[0]):
			_apply_size(e[0], e[1], e[2])
			kept.append(e)
	sized = kept
	top_h = maxi(36, ui_size + 18)
	task_h = maxi(50, ui_size + 30)
	if top_panel != null:
		top_panel.offset_bottom = top_h
		task_panel.offset_top = -task_h
		layer.offset_top = top_h
		layer.offset_bottom = -task_h
		toast_panel.offset_top = top_h + 12
		toast_panel.offset_bottom = top_h + 12
	if net_map != null:
		net_map.queue_redraw()
	if tool_memory != null and is_instance_valid(tool_memory):
		tool_memory.queue_redraw()


func _font_nudge(d: int) -> void:
	font_step = clampi(font_step + d, -3, 8)
	_font_apply()


# ── 공통 위젯 ──────────────────────────────────────────────────

func _btn(key: String, tip_key: String, cb: Callable, focusable: bool = true) -> Button:
	var b := Button.new()
	_reg(b, "text", key)
	if not tip_key.is_empty():
		_reg(b, "tooltip_text", tip_key)
	if not focusable:
		b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _btn_raw(text: String, tip_key: String, cb: Callable, focusable: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	if not tip_key.is_empty():
		_reg(b, "tooltip_text", tip_key)
	if not focusable:
		b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _label(text: String, color: Color = C_TEXT, delta: int = 0, wrap: bool = false, term: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_size(l, delta, term)
	return l


func _klabel(key: String, color: Color = C_TEXT, delta: int = 0, wrap: bool = false, repl: Dictionary = {}) -> Label:
	var l := _label("", color, delta, wrap)
	_reg(l, "text", key, repl)
	return l


func _section(key: String) -> Label:
	var l := _klabel(key, C_TEAL_DIM, -3)
	l.uppercase = false
	return l


func _line_edit(placeholder_key: String, delta: int = 0) -> LineEdit:
	var e := LineEdit.new()
	e.max_length = MAX_INPUT
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.context_menu_enabled = true
	if not placeholder_key.is_empty():
		_reg(e, "placeholder_text", placeholder_key)
	_size(e, delta)
	return e


func _text_edit(placeholder_key: String, min_h: float) -> TextEdit:
	var e := TextEdit.new()
	e.custom_minimum_size = Vector2(0, min_h)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	if not placeholder_key.is_empty():
		_reg(e, "placeholder_text", placeholder_key)
	_size(e, -2)
	return e


## 선택·복사 가능한 순수 텍스트 출력. BBCode를 해석하지 않고 meta 링크를 열지 않는다.
func _plain_text(term: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.selection_enabled = true
	r.context_menu_enabled = true
	r.focus_mode = Control.FOCUS_CLICK
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size(r, 0, term)
	return r


func _set_plain(r: RichTextLabel, text: String) -> void:
	r.clear()
	r.add_text(text)
	r.scroll_to_line(0)


func _scroll_wrap(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _small(b: Control, delta: int = -2) -> Control:
	_size(b, delta)
	return b


func _pulse(c: CanvasItem, color: Color) -> void:
	if c == null or reduced_motion:
		return
	c.modulate = color.lightened(0.35)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color.WHITE, 0.9)


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ── 바탕·상단·작업 표시줄 ───────────────────────────────────────

func _build_shell() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.offset_top = top_h
	layer.offset_bottom = -task_h
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.resized.connect(_clamp_all)
	add_child(layer)

	top_panel = PanelContainer.new()
	var top_sb := _sb(Color(0.026, 0.038, 0.047, 0.96), C_LINE, 0, 0, 4)
	top_sb.border_width_bottom = 1
	top_sb.content_margin_left = 16
	top_sb.content_margin_right = 10
	top_panel.add_theme_stylebox_override("panel", top_sb)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_top = 0
	top_panel.offset_bottom = top_h
	add_child(top_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top_panel.add_child(row)
	row.add_child(_klabel("UI_BRAND", C_TEAL_DIM, -4))
	top_mission = _label("", C_TEXT, -2)
	top_mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_mission.clip_text = true
	top_mission.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(top_mission)
	top_progress = _label("", C_DIM, -3)
	row.add_child(top_progress)
	top_alert = _label("", C_DIM, -3)
	row.add_child(top_alert)
	top_host = _label("", C_TEAL, -3)
	top_host.clip_text = true
	top_host.custom_minimum_size = Vector2(120, 0)
	top_host.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(top_host)
	top_save = _label("", C_TEAL_DIM, -4)
	row.add_child(top_save)
	var flat := _sb(Color(0, 0, 0, 0), C_LINE, 1, 3, 3)
	flat.content_margin_left = 8
	flat.content_margin_right = 8
	font_down_btn = _btn_raw("A−", "UI_FONT_SMALLER", _font_nudge.bind(-1))
	var font_up := _btn_raw("A+", "UI_FONT_LARGER", _font_nudge.bind(1))
	pause_btn = _btn("UI_PAUSE", "UI_PAUSE_TIP", _toggle_pause)
	for b in [font_down_btn, font_up, pause_btn]:
		b.add_theme_stylebox_override("normal", flat)
		_size(b, -4)
		row.add_child(b)

	task_panel = PanelContainer.new()
	var task_sb := _sb(Color(0.032, 0.047, 0.057, 0.97), C_LINE, 0, 0, 5)
	task_sb.border_width_top = 1
	task_sb.content_margin_left = 10
	task_sb.content_margin_right = 10
	task_panel.add_theme_stylebox_override("panel", task_sb)
	task_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	task_panel.offset_top = -task_h
	task_panel.offset_bottom = 0
	add_child(task_panel)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	task_panel.add_child(trow)
	task_scroll = ScrollContainer.new()
	task_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	task_scroll.follow_focus = true
	task_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.size_flags_stretch_ratio = 3.0
	trow.add_child(task_scroll)
	var apps := HBoxContainer.new()
	apps.add_theme_constant_override("separation", 4)
	task_scroll.add_child(apps)
	var tb := _btn_raw("", "UI_TASK_TERMINAL_TIP", _open_terminal_last)
	_size(tb, -3)
	task_buttons["terminal"] = tb
	apps.add_child(tb)
	for t in TERMS:
		var nb := _btn_raw(str(t + 1), "", _open_terminal.bind(t))
		_reg(nb, "tooltip_text", "UI_TASK_TERMINAL_N_TIP", {"n": t + 1})
		nb.custom_minimum_size = Vector2(34, 0)
		_size(nb, -3)
		term_task_buttons.append(nb)
		apps.add_child(nb)
	apps.add_child(VSeparator.new())
	for id in TASK_APPS:
		var b := _btn_raw("", "UI_TASK_OPEN_TIP", _open_app.bind(id, true))
		_size(b, -3)
		task_buttons[id] = b
		apps.add_child(b)
	task_buttons["ending"].visible = false
	status_label = _label("", C_DIM, -4)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_stretch_ratio = 1.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trow.add_child(status_label)
	save_btn = _btn("UI_SAVE", "UI_SAVE_TIP", _manual_save)
	load_btn = _btn("UI_LOAD", "UI_LOAD_TIP", _ask_load)
	recover_btn = _btn("UI_RECOVER", "UI_RECOVER_TIP", _ask_recover)
	fresh_btn = _btn("UI_FRESH_SAVE", "UI_FRESH_SAVE_TIP", _ask_fresh)
	room_btn = _btn("UI_ROOM", "UI_ROOM_TIP", _request_room)
	for b in [save_btn, load_btn, recover_btn, fresh_btn, room_btn]:
		_size(b, -3)
		trow.add_child(b)
	for b in [recover_btn, fresh_btn]:
		b.add_theme_color_override("font_color", C_AMBER)
		b.visible = false


func _build_overlays() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.anchor_left = 1.0
	toast_panel.anchor_right = 1.0
	toast_panel.offset_left = -480
	toast_panel.offset_right = -18
	toast_panel.offset_top = top_h + 12
	toast_panel.offset_bottom = top_h + 12
	toast_panel.visible = false
	add_child(toast_panel)
	toast_label = _label("", C_TEXT, -1, true)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	confirm = ConfirmationDialog.new()
	confirm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	confirm.dialog_autowrap = true
	confirm.theme = ui_theme
	confirm.confirmed.connect(_on_confirmed)
	confirm.visibility_changed.connect(_on_confirm_visibility)
	add_child(confirm)

	pause_overlay = _overlay_panel(Color(0.015, 0.025, 0.03, 0.86))
	var pbox := _overlay_box(pause_overlay, 520)
	pbox.add_child(_klabel("UI_PAUSE_TITLE", C_TEAL, 8))
	pbox.add_child(_klabel("UI_PAUSE_BODY", C_DIM, -1, true))
	pause_resume_btn = _btn("UI_PAUSE_RESUME", "", _set_paused.bind(false))
	pbox.add_child(pause_resume_btn)
	pbox.add_child(_btn("UI_OPEN_SETTINGS", "UI_OPEN_SETTINGS_TIP", _open_settings))
	pbox.add_child(_btn("UI_PAUSE_HELP", "", _pause_to_help))
	pbox.add_child(_btn("UI_ROOM", "UI_ROOM_TIP", _request_room))

	recovery_overlay = _overlay_panel(Color(0.02, 0.03, 0.035, 0.93))
	var rbox := _overlay_box(recovery_overlay, 660)
	rbox.add_child(_klabel("UI_RECOVERY_TITLE", C_AMBER, 5, true))
	recovery_text = _label("", C_TEXT, -1, true)
	rbox.add_child(recovery_text)
	rbox.add_child(_klabel("UI_RECOVERY_EXPLAIN", C_DIM, -3, true))
	recovery_recover_btn = _btn("UI_RECOVER", "UI_RECOVER_TIP", _ask_recover)
	recovery_fresh_btn = _btn("UI_FRESH_SAVE", "UI_FRESH_SAVE_TIP", _ask_fresh)
	recovery_continue_btn = _btn("UI_RECOVERY_CONTINUE", "UI_RECOVERY_CONTINUE_TIP", _recovery_dismiss)
	for b in [recovery_recover_btn, recovery_fresh_btn, recovery_continue_btn]:
		rbox.add_child(b)
	rbox.add_child(_btn("UI_ROOM", "UI_ROOM_TIP", _request_room))

	fatal_overlay = _overlay_panel(Color(0.02, 0.03, 0.035, 0.95))
	var fbox := _overlay_box(fatal_overlay, 640)
	fbox.add_child(_klabel("UI_FATAL_TITLE", C_AMBER, 4, true))
	fatal_label = _label("", C_TEXT, 0, true)
	fbox.add_child(fatal_label)
	fbox.add_child(_btn("UI_FATAL_RETRY", "", _retry_core))
	fbox.add_child(_btn("UI_ROOM", "UI_ROOM_TIP", _request_room))


func _overlay_panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", _sb(color, Color(0, 0, 0, 0), 0, 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.visible = false
	add_child(p)
	return p


func _overlay_box(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	parent.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.082, 0.095), Color(0.26, 0.42, 0.43), 1, 6, 22))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	return box


func _toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_panel.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.072, 0.082, 0.97), color.darkened(0.25), 1, 4, 12))
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	status_label.text = text.replace("\n", " · ")
	status_label.tooltip_text = text
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(4.5 if not reduced_motion else 6.0)
	if reduced_motion:
		toast_tween.tween_callback(toast_panel.hide)
	else:
		toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.6)
		toast_tween.tween_callback(toast_panel.hide)
	if paused:
		toast_tween.pause()


func _ask(text: String, action: Callable) -> void:
	if game == null:
		return
	confirm.title = _t("UI_CONFIRM_TITLE")
	confirm.ok_button_text = _t("UI_OK")
	confirm.cancel_button_text = _t("UI_CANCEL")
	confirm.dialog_text = text
	confirm_action = action
	confirm.popup_centered(Vector2i(mini(600, int(size.x) - 40), 0))


## 확인창을 닫으면(확인·취소 모두) 이전 활성 창 입력으로 돌아간다. 복구 화면이 떠 있으면 그쪽을 우선한다.
func _on_confirm_visibility() -> void:
	if confirm.visible:
		return
	if recovery_overlay != null and recovery_overlay.visible:
		call_deferred("_focus_recovery")
	elif paused:
		pause_resume_btn.call_deferred("grab_focus")
	else:
		call_deferred("_restore_focus", null)


func _on_confirmed() -> void:
	var a := confirm_action
	confirm_action = Callable()
	if a.is_valid():
		a.call()


# ── 일시정지·방 복귀·설정 ─────────────────────────────────────

func _toggle_pause() -> void:
	_set_paused(not paused)


func _set_paused(on: bool, restore_focus: bool = true) -> void:
	if paused == on:
		return
	paused = on
	pause_overlay.visible = on
	if on:
		_focus_before_pause = _owned_focus()
		drag = {}
		if toast_tween != null and toast_tween.is_valid():
			toast_tween.pause()
		if pause_resume_btn.is_visible_in_tree():
			pause_resume_btn.grab_focus()
	else:
		if toast_tween != null and toast_tween.is_valid():
			toast_tween.play()
		if restore_focus:
			_restore_focus(_focus_before_pause)
		_focus_before_pause = null
	pause_changed.emit(on)


func _pause_to_help() -> void:
	_set_paused(false, false)
	_open_app("help", true)


func _request_room() -> void:
	_set_paused(false, false)
	return_to_room_requested.emit()


func _room_node() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("show_settings"):
			return n
		n = n.get_parent()
	return null


func _room_settings_open() -> bool:
	var room := _room_node()
	return room != null and room.get("settings_panel") != null


func _open_settings() -> void:
	if not get_signal_connection_list("settings_requested").is_empty():
		settings_requested.emit()
		return
	var room := _room_node()
	if room != null:
		room.call("show_settings")
	else:
		_toast(_t("UI_SETTINGS_UNAVAILABLE"), C_AMBER)


func _on_visibility_changed() -> void:
	if not visible:
		_focus_before_hide = _owned_focus()
		drag = {}
		if paused:
			_set_paused(false, false)
	else:
		call_deferred("_restore_focus", _focus_before_hide)


## 이 데스크톱 안에 있는 현재 포커스 컨트롤(없으면 null).
func _owned_focus() -> Control:
	if not is_inside_tree():
		return null
	var fo: Control = get_viewport().gui_get_focus_owner()
	if fo != null and is_ancestor_of(fo):
		return fo
	return null


func _restore_focus(target = null) -> void:
	if not is_visible_in_tree() or _modal_open():
		return
	# 숨어 있는 동안 다시 만들어진(해제된) 컨트롤일 수 있으므로 유효성부터 확인한다.
	if is_instance_valid(target) and target is Control:
		var c: Control = target
		if c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()
			return
	if not active_id.is_empty() and wins.has(active_id) and wins[active_id]["win"].visible:
		_focus_default(active_id)


# ── 창 관리 ───────────────────────────────────────────────────

func _build_windows() -> void:
	for t in TERMS:
		var tc := _build_terminal(t)
		_make_window("term%d" % t, "UI_WIN_TERMINAL_N", {"n": t + 1}, tc, terms[t]["input"])
	var c: Control = _build_mail()
	_make_window("mail", APP_TITLES["mail"], {}, c, mail_list)
	c = _build_browser()
	_make_window("browser", APP_TITLES["browser"], {}, c, br_addr)
	c = _build_requestlab()
	_make_window("requestlab", APP_TITLES["requestlab"], {}, c, rl_url)
	c = _build_tools()
	_make_window("tools", APP_TITLES["tools"], {}, c, tool_list)
	c = _build_files()
	_make_window("files", APP_TITLES["files"], {}, c, fs_list)
	c = _build_archive()
	_make_window("archive", APP_TITLES["archive"], {}, c, ar_list)
	c = _build_board()
	_make_window("board", APP_TITLES["board"], {}, c, bd_tree)
	c = _build_status()
	_make_window("status", APP_TITLES["status"], {}, c, null)
	c = _build_help()
	_make_window("help", APP_TITLES["help"], {}, c, null)
	c = _build_ending()
	_make_window("ending", APP_TITLES["ending"], {}, c, null)


func _make_window(id: String, title_key: String, repl: Dictionary, content: Control, focus: Control) -> void:
	var win := Control.new()
	win.mouse_filter = Control.MOUSE_FILTER_STOP
	win.visible = false
	win.set_meta("app_id", id)
	layer.add_child(win)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override("panel", sb_frame_off)
	win.add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.add_theme_stylebox_override("panel", sb_bar_off)
	bar.gui_input.connect(_on_bar_input.bind(id))
	col.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	var title := _label("", C_TEXT, -2)
	_reg(title, "text", title_key, repl)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar_row.add_child(title)
	var flat := _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 2)
	flat.content_margin_left = 10
	flat.content_margin_right = 10
	for spec in [["─", "UI_WIN_MINIMIZE", _minimize], ["□", "UI_WIN_MAXIMIZE", _toggle_max], ["×", "UI_WIN_CLOSE", _close]]:
		var cb: Callable = spec[2]
		var b := _btn_raw(spec[0], spec[1], cb.bind(id), false)
		b.add_theme_stylebox_override("normal", flat)
		_size(b, -3)
		bar_row.add_child(b)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	col.add_child(pad)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(content)

	var grip := Control.new()
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -16
	grip.offset_top = -16
	grip.offset_right = 0
	grip.offset_bottom = 0
	grip.gui_input.connect(_on_grip_input.bind(id))
	grip.draw.connect(_draw_grip.bind(grip))
	win.add_child(grip)

	wins[id] = {"win": win, "frame": frame, "bar": bar, "title": title, "focus": focus,
			"state": "closed", "placed": false, "restore": Rect2()}


func _draw_grip(grip: Control) -> void:
	grip.draw_line(Vector2(4, 14), Vector2(14, 4), C_FAINT, 1.0)
	grip.draw_line(Vector2(9, 14), Vector2(14, 9), C_FAINT, 1.0)


func _desk_size() -> Vector2:
	if layer != null and layer.size.x > 1.0:
		return layer.size
	return get_viewport_rect().size - Vector2(0, top_h + task_h)


func _default_rect(id: String) -> Rect2:
	var f: Rect2 = APP_RECTS[id]
	var area := _desk_size()
	return Rect2(f.position * area, f.size * area)


func _clamp_win(w: Control) -> void:
	var area := _desk_size()
	w.size = Vector2(minf(maxf(w.size.x, MIN_WIN.x), area.x), minf(maxf(w.size.y, MIN_WIN.y), area.y))
	# 제목줄 일부가 항상 데스크톱 안에 남아 다시 잡을 수 있게 한다.
	w.position = Vector2(clampf(w.position.x, 100.0 - w.size.x, area.x - 100.0),
			clampf(w.position.y, 0.0, maxf(area.y - 36.0, 0.0)))


func _clamp_all() -> void:
	for id in wins:
		_clamp_win(wins[id]["win"])


func _open_terminal_last() -> void:
	_open_terminal(active_term)


func _open_terminal(t: int) -> void:
	if game == null or fatal_overlay.visible:
		return
	var first: bool = not bool(term_live[t])
	term_live[t] = true
	_open_app("term%d" % t, true)
	if first or terms[t]["out"].get_paragraph_count() <= 1:
		if terms[t]["out"].get_paragraph_count() <= 1:
			_term_line(t, _t("UI_TERM_WELCOME", {"n": t + 1}), C_DIM)
		_refresh_all()


func _open_app(id: String, grab: bool = true) -> void:
	if game == null or fatal_overlay.visible:
		return
	if id == "terminal":
		_open_terminal(active_term)
		return
	if not wins.has(id):
		return
	var w: Dictionary = wins[id]
	var win: Control = w["win"]
	if not w["placed"]:
		var r := _default_rect(id)
		win.position = r.position
		win.size = r.size
		w["placed"] = true
	w["state"] = "open"
	win.visible = true
	_clamp_win(win)
	_activate(id, grab)
	if id == "browser" and not br_opened:
		br_opened = true
		_br_navigate(_s(last_view, "browser_home"), true)
	elif id == "mail":
		_select_unread_mail()
	elif id == "ending":
		en_sig = ""
		_refresh_ending(last_view)
	elif id == "files":
		_refresh_files()


func _activate(id: String, grab: bool) -> void:
	if not wins.has(id):
		return
	active_id = id
	var win: Control = wins[id]["win"]
	win.move_to_front()
	for k in wins:
		var on: bool = k == id
		wins[k]["frame"].add_theme_stylebox_override("panel", sb_frame_on if on else sb_frame_off)
		wins[k]["bar"].add_theme_stylebox_override("panel", sb_bar_on if on else sb_bar_off)
	if id.begins_with("term"):
		var t := int(id.substr(4))
		if t != active_term:
			active_term = t
			if game != null:
				term_views[t] = _view(t)
				last_view = term_views[t]
				_refresh_top(last_view)
				_refresh_tools(last_view)
	if grab:
		_focus_default(id)
	_update_taskbar()


func _focus_default(id: String) -> void:
	if not wins.has(id):
		return
	var f = wins[id]["focus"]
	if f is Control and f.is_visible_in_tree():
		f.grab_focus()
		if f is LineEdit and f.has_method("edit"):
			f.call("edit")
		return
	# 고정 초점이 없는 창은 첫 번째 키보드 조작 가능한 컨트롤로 보낸다.
	var first := _first_focusable(wins[id]["win"])
	if first != null:
		first.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _first_focusable(n: Node) -> Control:
	for child in n.get_children():
		var c := child as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var b := c as BaseButton
		if c.focus_mode == Control.FOCUS_ALL and (b == null or not b.disabled):
			return c
		var inner := _first_focusable(c)
		if inner != null:
			return inner
	return null


func _hide_window(id: String, state: String) -> void:
	var win: Control = wins[id]["win"]
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and win.is_ancestor_of(fo):
		get_viewport().gui_release_focus()
	wins[id]["state"] = state
	win.visible = false
	if active_id == id:
		active_id = ""
		for i in range(layer.get_child_count() - 1, -1, -1):
			var c := layer.get_child(i) as Control
			if c != null and c.visible:
				_activate(str(c.get_meta("app_id")), true)
				return
	_update_taskbar()


func _minimize(id: String) -> void:
	_hide_window(id, "min")


func _close(id: String) -> void:
	_hide_window(id, "closed")


func _toggle_max(id: String) -> void:
	var w: Dictionary = wins[id]
	var win: Control = w["win"]
	var full := Rect2(Vector2.ZERO, _desk_size())
	var restore: Rect2 = w["restore"]
	if Rect2(win.position, win.size).is_equal_approx(full) and restore.size.x > 0.0:
		win.position = restore.position
		win.size = restore.size
	else:
		w["restore"] = Rect2(win.position, win.size)
		win.position = full.position
		win.size = full.size
	_clamp_win(win)
	_activate(id, false)


func _arrange() -> void:
	if game == null:
		return
	for id in wins:
		var w: Dictionary = wins[id]
		var win: Control = w["win"]
		var r := _default_rect(id)
		win.position = r.position
		win.size = r.size
		w["placed"] = true
		if w["state"] == "min":
			w["state"] = "open"
			win.visible = true
	var keep := active_id
	for id in wins:
		if wins[id]["state"] == "open" and id != keep:
			_activate(id, false)
	if not keep.is_empty() and wins[keep]["state"] == "open":
		_activate(keep, true)


func _cycle_window(dir: int) -> void:
	var open: Array = []
	for i in layer.get_child_count():
		var c := layer.get_child(i) as Control
		if c != null and c.visible:
			open.append(str(c.get_meta("app_id")))
	if open.size() < 2:
		return
	# 맨 앞(마지막) 창을 기준으로 다음/이전 창을 맨 앞으로 가져온다.
	var target: String = open[0] if dir > 0 else open[open.size() - 2]
	_activate(target, true)


func _on_bar_input(event: InputEvent, id: String) -> void:
	if paused:
		return
	var win: Control = wins[id]["win"]
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and mb.double_click:
			drag = {}
			_toggle_max(id)
		elif mb.pressed:
			drag = {"id": id, "mode": "move", "mouse": mb.global_position, "rect": Rect2(win.position, win.size)}
		else:
			drag = {}
		return
	var mm := event as InputEventMouseMotion
	if mm != null and drag.get("id", "") == id and drag.get("mode", "") == "move":
		var r: Rect2 = drag["rect"]
		var start: Vector2 = drag["mouse"]
		win.position = r.position + (mm.global_position - start)
		_clamp_win(win)


func _on_grip_input(event: InputEvent, id: String) -> void:
	if paused:
		return
	var win: Control = wins[id]["win"]
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			drag = {"id": id, "mode": "resize", "mouse": mb.global_position, "rect": Rect2(win.position, win.size)}
		else:
			drag = {}
		return
	var mm := event as InputEventMouseMotion
	if mm != null and drag.get("id", "") == id and drag.get("mode", "") == "resize":
		var r: Rect2 = drag["rect"]
		var start: Vector2 = drag["mouse"]
		var delta: Vector2 = mm.global_position - start
		var area := _desk_size()
		win.size = Vector2(clampf(r.size.x + delta.x, MIN_WIN.x, maxf(area.x - win.position.x, MIN_WIN.x)),
				clampf(r.size.y + delta.y, MIN_WIN.y, maxf(area.y - win.position.y, MIN_WIN.y)))


# ── 입력 라우팅 ───────────────────────────────────────────────
# 마우스: 누를 때 클릭된 창을 맨 앞으로 올리고, 다른 창 입력에 남은 포커스를 놓는다.
# 버튼을 놓은 뒤에만(지연 호출) 활성 창 입력으로 포커스를 되돌려 클릭 동작이 취소되지 않게 한다.
# 키: F10은 Room이 처리하도록 그대로 통과시킨다. IME 조합 중에는 단축키를 처리하지 않는다.

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _room_settings_open():
		return
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo or key.keycode == KEY_F10:
			return
		var fo := get_viewport().gui_get_focus_owner()
		if (fo is LineEdit or fo is TextEdit) and fo.has_ime_text():
			return
		if paused:
			if key.keycode == KEY_ESCAPE or key.keycode == KEY_PAUSE:
				_set_paused(false)
				get_viewport().set_input_as_handled()
			elif fo == null or not pause_overlay.is_ancestor_of(fo):
				pause_resume_btn.grab_focus()
				get_viewport().set_input_as_handled()
			return
		if _modal_open():
			return
		if _handle_shortcut(key, fo):
			get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or paused or _modal_open():
		return
	if not (mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]):
		return
	if not mb.pressed:
		if not active_id.is_empty():
			call_deferred("_focus_after_click", active_id)
		return
	for i in range(layer.get_child_count() - 1, -1, -1):
		var c := layer.get_child(i) as Control
		if c == null or not c.visible or not c.get_global_rect().has_point(mb.position):
			continue
		var id := str(c.get_meta("app_id"))
		var fo2 := get_viewport().gui_get_focus_owner()
		if fo2 != null and wins.has(id) and not c.is_ancestor_of(fo2) and layer.is_ancestor_of(fo2):
			get_viewport().gui_release_focus()
		if id != active_id:
			_activate(id, false)
		return


func _handle_shortcut(key: InputEventKey, fo: Control) -> bool:
	var cmd := key.is_command_or_control_pressed()
	var code := key.keycode
	if cmd and not key.alt_pressed and code >= KEY_1 and code <= KEY_9:
		var n := int(code - KEY_1)
		if key.shift_pressed:
			if n < TERMS:
				_open_terminal(n)
				return true
			return false
		_open_app(SHORTCUTS[n], true)
		return true
	if (cmd or key.ctrl_pressed) and code == KEY_TAB:
		_cycle_window(-1 if key.shift_pressed else 1)
		return true
	if cmd or key.alt_pressed:
		return false
	match code:
		KEY_F1:
			_open_app("help", true)
			return true
		KEY_F6:
			if key.shift_pressed:
				font_down_btn.grab_focus()
			else:
				task_buttons["terminal"].grab_focus()
			return true
		KEY_PAUSE:
			_set_paused(true)
			return true
		KEY_ESCAPE:
			# 입력칸의 Esc(터미널 입력 지우기·인증 취소 등)는 빼앗지 않는다.
			if fo is LineEdit or fo is TextEdit:
				return false
			_set_paused(true)
			return true
	return false


func _focus_after_click(id: String) -> void:
	if id != active_id or paused or _modal_open() or not wins.has(id):
		return
	var fo := get_viewport().gui_get_focus_owner()
	var win: Control = wins[id]["win"]
	if not win.visible:
		return
	# 창 안의 다른 컨트롤을 눌렀다면 그 선택을 존중한다. 창 밖(작업 표시줄 등)을 누른 뒤에는 창 입력으로 돌아간다.
	if fo == null or not win.is_ancestor_of(fo):
		_focus_default(id)


func _update_taskbar() -> void:
	if task_buttons.is_empty() or wins.is_empty():
		return
	for id in task_buttons:
		var b: Button = task_buttons[id]
		var label_text := ""
		var st := "closed"
		if id == "terminal":
			label_text = _t("UI_APP_TERMINAL")
			for t in TERMS:
				var ts: String = wins["term%d" % t]["state"]
				if ts == "open":
					st = "open"
				elif ts == "min" and st != "open":
					st = "min"
		else:
			label_text = _t(APP_TITLES[id])
			st = wins[id]["state"]
		if id == "mail":
			var n := _unread_count()
			if n > 0:
				label_text = _t("UI_TASK_MAIL_UNREAD", {"name": label_text, "n": n})
		b.text = ("● " if st == "open" else ("○ " if st == "min" else "")) + label_text
		var active: bool = id == active_id or (id == "terminal" and active_id.begins_with("term"))
		var col := C_DIM
		if st != "closed":
			col = C_TEAL if active and st == "open" else C_TEXT
		b.add_theme_color_override("font_color", col)
	for t in TERMS:
		var nb: Button = term_task_buttons[t]
		var ts: String = wins["term%d" % t]["state"]
		var on: bool = active_id == "term%d" % t
		nb.text = str(t + 1) + ("•" if ts == "open" else ("◦" if ts == "min" else ""))
		nb.add_theme_color_override("font_color", C_TEAL if on else (C_TEXT if ts != "closed" else C_FAINT))
	var ending_relevant := _main_complete(last_view) or not _d(last_view.get("ending", {})).is_empty()
	task_buttons["ending"].visible = ending_relevant


# ── 터미널 (0..3, 각자 독립 세션) ─────────────────────────────

func _build_terminal(t: int) -> Control:
	var d := {"history": [], "hist_idx": -1, "draft": "", "last_frame": -1, "pw": false}
	var col := VBoxContainer.new()
	var head := HBoxContainer.new()
	var header := _label("", C_DIM, -3)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.clip_text = true
	header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(header)
	var clear_b := _btn("UI_TERM_CLEAR", "UI_TERM_CLEAR_TIP", _term_clear.bind(t))
	var exit_b := _btn("UI_TERM_EXIT", "UI_TERM_EXIT_TIP", _term_exit.bind(t))
	for b in [clear_b, exit_b]:
		_size(b, -4)
		head.add_child(b)
	col.add_child(head)
	var out := _plain_text(true)
	# 맨 아래일 때만 따라가고, 위로 읽는 중이면 위치를 유지한다.
	out.scroll_following = true
	out.gui_input.connect(_on_term_out_input.bind(t))
	col.add_child(out)
	var row := HBoxContainer.new()
	var prompt := _label("$", C_TEAL, -2, false, true)
	row.add_child(prompt)
	var input := LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = MAX_INPUT
	input.set("keep_editing_on_text_submit", true)
	input.text_submitted.connect(_on_term_submit.bind(t))
	input.gui_input.connect(_on_term_key.bind(t))
	_size(input, 0, true)
	row.add_child(input)
	col.add_child(row)
	d["out"] = out
	d["input"] = input
	d["prompt"] = prompt
	d["header"] = header
	terms.append(d)
	return col


func _term_line(t: int, text: String, color: Color) -> void:
	var out: RichTextLabel = terms[t]["out"]
	# 한 단락마다 색 구간을 닫아 오래된 단락을 안전하게 지울 수 있게 한다.
	for line in text.split("\n"):
		out.push_color(color)
		out.add_text(line)
		out.pop()
		out.newline()
	if out.get_paragraph_count() > MAX_LOG_PARAGRAPHS + 100:
		while out.get_paragraph_count() > MAX_LOG_PARAGRAPHS:
			out.remove_paragraph(0)


func _term_print(t: int, r: Dictionary) -> void:
	var ok := _b(r, "ok")
	var text := _s(r, "text").trim_suffix("\n")
	if not text.is_empty():
		_term_line(t, text, C_TEXT if ok else C_AMBER)
	var code := _s(r, "code")
	if not ok and not code.is_empty():
		_term_line(t, "  · " + code, C_FAINT)


func _refocus_terminal(t: int) -> void:
	var id := "term%d" % t
	if wins.has(id) and wins[id]["win"].visible and not paused:
		var input: LineEdit = terms[t]["input"]
		input.grab_focus()
		if input.has_method("edit"):
			input.call("edit")


func _on_term_out_input(event: InputEvent, t: int) -> void:
	var mb := event as InputEventMouseButton
	var out: RichTextLabel = terms[t]["out"]
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and out.get_selected_text().is_empty():
		_refocus_terminal(t)


func _on_term_key(event: InputEvent, t: int) -> void:
	var k := event as InputEventKey
	var d: Dictionary = terms[t]
	var input: LineEdit = d["input"]
	if k == null or not k.pressed or input.has_ime_text():
		return
	if k.is_command_or_control_pressed() and k.keycode == KEY_L:
		_term_clear(t)
		input.accept_event()
		return
	match k.keycode:
		KEY_UP:
			_hist(t, -1)
		KEY_DOWN:
			_hist(t, 1)
		KEY_TAB:
			# 빈 입력·Shift+Tab은 일반 포커스 이동으로 남겨 포커스 함정을 만들지 않는다.
			if k.shift_pressed or k.is_command_or_control_pressed() or input.text.is_empty() or bool(d["pw"]):
				return
			_complete(t)
		KEY_ESCAPE:
			input.clear()
			d["hist_idx"] = -1
			if bool(d["pw"]):
				_term_cancel_auth(t)
		_:
			return
	input.accept_event()


func _hist(t: int, dir: int) -> void:
	var d: Dictionary = terms[t]
	var history: Array = d["history"]
	var input: LineEdit = d["input"]
	if history.is_empty() or bool(d["pw"]):
		return
	var idx := int(d["hist_idx"])
	if idx == -1:
		if dir > 0:
			return
		d["draft"] = input.text
		idx = history.size() - 1
	else:
		idx += dir
	if idx >= history.size():
		idx = -1
		input.text = str(d["draft"])
	else:
		idx = maxi(idx, 0)
		input.text = str(history[idx])
	d["hist_idx"] = idx
	input.caret_column = input.text.length()


func _complete(t: int) -> void:
	# 암호 입력 중에는 입력 문자열을 어디에도 보내지 않는다.
	var d: Dictionary = terms[t]
	if game == null or bool(d["pw"]):
		return
	var input: LineEdit = d["input"]
	var line := input.text
	var raw = game.autocomplete(line, t)
	var cands: Array = []
	if raw is PackedStringArray or raw is Array:
		cands = Array(raw)
	if cands.is_empty():
		return
	var applied := _apply_completion(line, _common_prefix(cands))
	if cands.size() == 1 and applied != line and not applied.ends_with("/") and not applied.ends_with(" "):
		applied += " "
	if applied != line:
		input.text = applied
		input.caret_column = applied.length()
	if cands.size() > 1:
		_term_line(t, "  ".join(PackedStringArray(cands)), C_DIM)


# 후보가 전체 줄이든 마지막 토큰/경로 조각이든 같은 결과가 나오게 붙인다.
static func _apply_completion(line: String, cand: String) -> String:
	if cand.is_empty():
		return line
	if cand.begins_with(line):
		return cand
	var cut := line.rfind(" ") + 1
	var token := line.substr(cut)
	if cand.begins_with(token):
		return line.substr(0, cut) + cand
	var slash := token.rfind("/") + 1
	if slash > 0 and cand.begins_with(token.substr(slash)):
		return line.substr(0, cut + slash) + cand
	return line


static func _common_prefix(items: Array) -> String:
	var p := str(items[0])
	for it in items:
		var s := str(it)
		var n := 0
		while n < mini(p.length(), s.length()) and p[n] == s[n]:
			n += 1
		p = p.substr(0, n)
	return p


func _on_term_submit(text: String, t: int) -> void:
	var d: Dictionary = terms[t]
	var input: LineEdit = d["input"]
	if input.has_ime_text():
		return
	# 같은 프레임의 중복 Enter(text_submitted 두 번)를 한 번으로 처리한다.
	var frame := Engine.get_process_frames()
	if frame == int(d["last_frame"]):
		return
	d["last_frame"] = frame
	input.clear()
	d["hist_idx"] = -1
	d["draft"] = ""
	_refocus_terminal(t)
	if not _can_act():
		return
	if bool(d["pw"]):
		if text.is_empty():
			_term_line(t, _t("UI_TERM_EMPTY_PASSWORD"), C_DIM)
			return
		# 암호는 화면·기록·초안에 남기지 않고 코어에만 한 번 전달한다.
		_term_line(t, _t("UI_TERM_PASSWORD_SENT"), C_DIM)
		var r := _act("terminal", func(): return game.submit_password(text, t), t)
		_term_print(t, r)
		return
	var cmd := text.strip_edges()
	if cmd.is_empty():
		_term_line(t, _s(term_views[t], "prompt", "$"), C_TEAL_DIM)
		return
	var history: Array = d["history"]
	if history.is_empty() or str(history[-1]) != cmd:
		history.append(cmd)
		if history.size() > MAX_HISTORY:
			history.remove_at(0)
	if cmd == "clear":
		_term_clear(t)
		return
	_run_command(t, cmd, "")


func _run_command(t: int, cmd: String, tag: String) -> Dictionary:
	if not _can_act():
		return {}
	term_live[t] = true
	var echo := _s(term_views[t], "prompt", "$") + " " + cmd
	if not tag.is_empty():
		echo = _t("UI_TERM_TAGGED", {"tag": tag, "line": echo})
	_term_line(t, echo, C_TEAL_DIM)
	var r := _act("terminal", func(): return game.execute(cmd, t), t)
	_term_print(t, r)
	return r


func _term_clear(t: int) -> void:
	var out: RichTextLabel = terms[t]["out"]
	out.clear()
	_refocus_terminal(t)


func _term_exit(t: int) -> void:
	if bool(terms[t]["pw"]):
		_term_cancel_auth(t)
	else:
		_run_command(t, "exit", "")
	_refocus_terminal(t)


func _term_cancel_auth(t: int) -> void:
	if game == null:
		return
	var r := _d(game.cancel_authentication(t))
	_term_print(t, r)
	_refresh_all()


func _refresh_terminal(t: int) -> void:
	var d: Dictionary = terms[t]
	var v: Dictionary = term_views[t]
	if v.is_empty():
		return
	var pw := _b(v, "password_pending")
	var input: LineEdit = d["input"]
	if input.secret and not pw:
		input.clear()
		d["hist_idx"] = -1
		d["draft"] = ""
	d["pw"] = pw
	input.secret = pw
	input.context_menu_enabled = not pw
	var prompt: Label = d["prompt"]
	prompt.text = _t("UI_TERM_PASSWORD_PROMPT") if pw else _s(v, "prompt", "$")
	prompt.add_theme_color_override("font_color", C_AMBER if pw else C_TEAL)
	input.placeholder_text = _t("UI_TERM_PASSWORD_PLACEHOLDER") if pw else _t("UI_TERM_PLACEHOLDER")
	var header: Label = d["header"]
	header.text = _t("UI_TERM_HEADER", {"n": t + 1, "user": _s(v, "user"), "host": _s(v, "host"), "cwd": _s(v, "cwd")})
	header.tooltip_text = header.text


# ── 메일·이야기 ───────────────────────────────────────────────

func _build_mail() -> Control:
	var split := HSplitContainer.new()
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	mail_list = ItemList.new()
	mail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mail_list.item_selected.connect(_on_mail_selected)
	_size(mail_list, -2)
	left.add_child(mail_list)
	left.add_child(_section("UI_MAIL_CONTACTS"))
	mail_contacts = VBoxContainer.new()
	mail_contacts.add_theme_constant_override("separation", 3)
	left.add_child(mail_contacts)
	split.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	mail_avatar_box = PanelContainer.new()
	mail_avatar_box.custom_minimum_size = Vector2(80, 80)
	mail_avatar_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mail_avatar_box.add_theme_stylebox_override("panel", _sb(Color(0.085, 0.16, 0.175), C_TEAL_DIM.darkened(0.2), 1, 8, 3))
	mail_avatar_box.clip_contents = true
	mail_avatar_tex = TextureRect.new()
	mail_avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mail_avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mail_avatar_tex.visible = false
	mail_avatar_box.add_child(mail_avatar_tex)
	mail_avatar_glyph = _label("◆", C_TEAL, 6)
	mail_avatar_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mail_avatar_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mail_avatar_box.add_child(mail_avatar_glyph)
	head.add_child(mail_avatar_box)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mail_subject = _label("", C_TEXT, 2, true)
	mail_sender = _label("", C_TEAL_DIM, -2)
	mail_meta = _label("", C_FAINT, -4, true)
	mail_reveal_btn = _btn_raw("", "UI_MAIL_REVEAL_TIP", _mail_reveal_face)
	mail_reveal_btn.visible = false
	mail_reveal_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_size(mail_reveal_btn, -4)
	for c in [mail_subject, mail_sender, mail_meta, mail_reveal_btn]:
		names.add_child(c)
	head.add_child(names)
	right.add_child(head)
	right.add_child(HSeparator.new())
	mail_body = _plain_text()
	right.add_child(mail_body)
	split.add_child(right)
	return split


func _mail_key(v: Dictionary, msg: Dictionary) -> String:
	return _s(v, "mission_id") + ":" + _s(msg, "id")


func _refresh_mail(v: Dictionary) -> void:
	_refresh_contacts(v)
	mail_list.clear()
	var sel := -1
	for m in _a(v, "messages"):
		var d := _d(m)
		var key := _mail_key(v, d)
		var i := mail_list.add_item(("   " if mail_read.has(key) else "● ") + _s(d, "subject", _t("UI_MAIL_NO_SUBJECT")))
		mail_list.set_item_metadata(i, {"msg": d, "key": key})
		mail_list.set_item_tooltip(i, _s(d, "sender"))
		if not mail_read.has(key):
			mail_list.set_item_custom_fg_color(i, C_TEAL)
		if key == mail_selected:
			sel = i
	if mail_list.item_count == 0:
		mail_selected = ""
		mail_shown_key = ""
		mail_subject.text = _t("UI_MAIL_EMPTY")
		mail_sender.text = ""
		mail_meta.text = ""
		mail_reveal_btn.visible = false
		mail_avatar_tex.visible = false
		mail_avatar_glyph.visible = true
		mail_avatar_glyph.text = "◆"
		mail_body.clear()
		return
	if sel < 0:
		# 선택이 현재 세계에 없으면(사건 전환·새 진행·불러오기) 가장 최근 메일을 보여 준다.
		sel = mail_list.item_count - 1
	mail_list.select(sel)
	_mail_show_index(sel, wins.has("mail") and wins["mail"]["state"] == "open")


func _select_unread_mail() -> void:
	for i in range(mail_list.item_count - 1, -1, -1):
		var meta := _d(mail_list.get_item_metadata(i))
		if not mail_read.has(_s(meta, "key")):
			mail_list.select(i)
			_mail_show_index(i, true)
			return
	if mail_list.item_count > 0:
		var cur := mail_list.get_selected_items()
		var i: int = cur[0] if not cur.is_empty() else mail_list.item_count - 1
		mail_list.select(i)
		_mail_show_index(i, true)


func _on_mail_selected(i: int) -> void:
	_mail_show_index(i, true)


func _mail_show_index(i: int, mark_read: bool) -> void:
	var meta := _d(mail_list.get_item_metadata(i))
	var d := _d(meta.get("msg", {}))
	var key := _s(meta, "key")
	mail_selected = key
	if mark_read and not mail_read.has(key):
		mail_read[key] = true
		mail_list.set_item_text(i, "   " + _s(d, "subject", _t("UI_MAIL_NO_SUBJECT")))
		mail_list.set_item_custom_fg_color(i, C_TEXT)
		_update_taskbar()
	var shown := key + "\n" + _s(d, "body") + "\n" + Localization.get_locale() + JSON.stringify([last_view.get("characters", []), face_disclosed.keys()])
	if shown == mail_shown_key:
		return  # 같은 메일이면 본문 스크롤 위치를 유지한다.
	mail_shown_key = shown
	mail_subject.text = _s(d, "subject", _t("UI_MAIL_NO_SUBJECT"))
	mail_sender.text = _s(d, "sender")
	var kind := _s(d, "id")
	var kind_key := "UI_MAIL_KIND_INTRO" if kind == "intro" else ("UI_MAIL_KIND_REPLY" if kind == "complete" else "UI_MAIL_KIND_OTHER")
	mail_meta.text = _t(kind_key, {"mission": _s(last_view, "mission_id"), "title": _s(last_view, "mission_title")})
	_mail_avatar(d)
	_set_plain(mail_body, _s(d, "body"))


func _character_for(msg: Dictionary) -> String:
	for k in ["character_id", "sender_id", "character"]:
		var c := _s(msg, k)
		if not c.is_empty():
			return c
	var sender := _s(msg, "sender")
	if sender.is_empty():
		return ""
	for c in CHARACTERS:
		var key: String = c + "_NAME"
		if sender == key or sender == Localization.tr_key(key):
			return c
	return ""


func _character_meta(cid: String) -> Dictionary:
	for c in _a(last_view, "characters"):
		var d := _d(c)
		if _s(d, "id") == cid:
			return d
	return {}


func _mission_done(id: String) -> bool:
	for m in _a(last_view, "missions"):
		var d := _d(m)
		if _s(d, "id") == id:
			return _b(d, "completed")
	return false


## 코어가 characters를 주면 그것만 따른다(만난 인물만 포함, 얼굴 공개·공개 제안 여부도 코어 결정).
## characters가 없는 구버전 코어에서만 사건 완료 시점 규칙 + 화면 안의 명시적 선택으로 대신한다.
func _core_has_characters() -> bool:
	return last_view.get("characters") is Array


func _face_state(cid: String) -> Dictionary:
	if cid.is_empty():
		return {"met": false, "revealed": false, "can_reveal": false, "expression": "neutral"}
	if _core_has_characters():
		var meta := _character_meta(cid)
		if meta.is_empty():
			return {"met": false, "revealed": false, "can_reveal": false, "expression": "neutral"}
		return {"met": true, "revealed": _b(meta, "face_revealed"), "can_reveal": _b(meta, "can_reveal"),
				"expression": _s(meta, "expression", "neutral"), "name": _s(meta, "name")}
	if not FACE_GATES.has(cid):
		return {"met": true, "revealed": false, "can_reveal": false, "expression": "neutral"}
	var gate: String = FACE_GATES[cid]
	var reached := gate.is_empty() or _mission_done(gate)
	var chosen := gate.is_empty() or face_disclosed.has(cid)
	return {"met": true, "revealed": reached and chosen, "can_reveal": reached and not chosen, "expression": "neutral"}


func _mail_avatar(d: Dictionary) -> void:
	var cid := _character_for(d)
	var sender := _s(d, "sender")
	mail_reveal_char = ""
	mail_reveal_btn.visible = false
	var tex: Texture2D = null
	if not cid.is_empty():
		var fs := _face_state(cid)
		if _b(fs, "can_reveal"):
			mail_reveal_char = cid
			mail_reveal_btn.text = _t("UI_MAIL_REVEAL_FACE", {"name": sender})
			mail_reveal_btn.visible = true
		elif _b(fs, "revealed"):
			tex = _portrait(cid, _s(fs, "expression", "neutral"), "")
	mail_avatar_tex.texture = tex
	mail_avatar_tex.visible = tex != null
	mail_avatar_glyph.visible = tex == null
	# 얼굴이 공개되지 않은 인물은 추상 표식, 그 밖의 발신자는 이름 첫 글자.
	mail_avatar_glyph.text = "◆" if not cid.is_empty() or sender.is_empty() else sender.substr(0, 1)
	mail_avatar_box.tooltip_text = sender


func _portrait(cid: String, expr: String, explicit_path: String) -> Texture2D:
	var paths: Array = []
	if explicit_path.begins_with(PORTRAIT_DIR) and explicit_path.ends_with(".png") and not explicit_path.contains(".."):
		paths.append(explicit_path)
	if expr.is_valid_identifier():
		paths.append(PORTRAIT_DIR + cid + "-" + expr + ".png")
	paths.append(PORTRAIT_DIR + cid + "-neutral.png")
	for p in paths:
		if _texture_cache.has(p):
			return _texture_cache[p]
		if ResourceLoader.exists(p):
			var tex := load(p) as Texture2D
			if tex != null:
				_texture_cache[p] = tex
				return tex
	return null


func _mail_reveal_face() -> void:
	_reveal_contact(mail_reveal_char)


## 얼굴 공개는 이야기 속 선택이다. 코어가 지원하면 코어 결정(저장됨)으로, 아니면 화면 안 선택으로만 처리한다.
func _reveal_contact(cid: String) -> void:
	if cid.is_empty() or not _can_act():
		return
	if _core_has_characters() and game.has_method("reveal_contact"):
		var r := _act("mail", func(): return game.reveal_contact(cid))
		if not _b(r, "ok"):
			_toast(_t("UI_NOTE_ACTION_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)
	else:
		face_disclosed[cid] = true
		_refresh_all()
	mail_shown_key = ""
	var cur := mail_list.get_selected_items()
	if not cur.is_empty():
		_mail_show_index(cur[0], true)


var mail_contacts: VBoxContainer
var mail_contacts_sig := ""


func _refresh_contacts(v: Dictionary) -> void:
	if mail_contacts == null:
		return
	var chars: Array = []
	if v.get("characters") is Array:
		chars = v["characters"]
	var sig := JSON.stringify([chars, face_disclosed.keys(), Localization.get_locale()])
	if sig == mail_contacts_sig:
		return
	mail_contacts_sig = sig
	_clear_children(mail_contacts)
	if chars.is_empty():
		mail_contacts.add_child(_label(_t("UI_MAIL_CONTACTS_NONE"), C_FAINT, -4, true))
		return
	for c in chars:
		var d := _d(c)
		var cid := _s(d, "id")
		var name_text := _s(d, "name", cid)
		if _b(d, "can_reveal"):
			var b := _btn_raw(_t("UI_MAIL_REVEAL_FACE", {"name": name_text}), "UI_MAIL_REVEAL_TIP", _reveal_contact.bind(cid))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_color_override("font_color", C_TEAL)
			_size(b, -4)
			mail_contacts.add_child(b)
		else:
			var key := "UI_MAIL_CONTACT_FACE" if _b(d, "face_revealed") else "UI_MAIL_CONTACT_ABSTRACT"
			mail_contacts.add_child(_label(_t(key, {"name": name_text}), C_DIM, -4, true))


func _unread_count() -> int:
	var n := 0
	for m in _a(last_view, "messages"):
		if not mail_read.has(_mail_key(last_view, _d(m))):
			n += 1
	return n


# ── 브라우저 (가상 사이트만, 공통 요청 처리기 사용) ─────────────

func _build_browser() -> Control:
	var col := VBoxContainer.new()
	var bar := HBoxContainer.new()
	br_back = _btn_raw("←", "UI_BR_BACK", _br_go.bind(-1))
	br_fwd = _btn_raw("→", "UI_BR_FORWARD", _br_go.bind(1))
	var reload := _btn_raw("⟳", "UI_BR_RELOAD", _br_reload)
	var home := _btn_raw("⌂", "UI_BR_HOME", _br_home)
	for b in [br_back, br_fwd, reload, home]:
		bar.add_child(b)
	br_addr = _line_edit("UI_BR_ADDR_PLACEHOLDER")
	br_addr.text_submitted.connect(_on_br_addr_submit)
	bar.add_child(br_addr)
	bar.add_child(_btn("UI_BR_GO", "UI_BR_GO_TIP", _br_go_addr))
	bar.add_child(_btn("UI_BR_TO_LAB", "UI_BR_TO_LAB_TIP", _br_to_lab))
	col.add_child(bar)
	br_title = _label("", C_TEXT, 4, true)
	col.add_child(br_title)
	br_meta = _label("", C_FAINT, -4, true)
	col.add_child(br_meta)
	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	br_body = _plain_text()
	br_body.custom_minimum_size = Vector2(0, 120)
	split.add_child(br_body)
	var links_wrap := VBoxContainer.new()
	links_wrap.add_child(_section("UI_BR_LINKS"))
	br_links = VBoxContainer.new()
	br_links.add_theme_constant_override("separation", 2)
	var links_scroll := _scroll_wrap(br_links)
	links_scroll.custom_minimum_size = Vector2(0, 76)
	links_wrap.add_child(links_scroll)
	split.add_child(links_wrap)
	col.add_child(split)

	br_form_toggle = _btn_raw("", "UI_BR_FORM_TIP", _br_toggle_form)
	br_form_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	br_form_toggle.flat = true
	br_form_toggle.add_theme_color_override("font_color", C_TEAL_DIM)
	_size(br_form_toggle, -3)
	col.add_child(br_form_toggle)
	br_form_box = VBoxContainer.new()
	br_form_box.visible = false
	var frow := HBoxContainer.new()
	frow.add_child(_klabel("UI_BR_FORM_LABEL", C_DIM, -3))
	br_method = OptionButton.new()
	br_method.add_item("GET")
	br_method.add_item("POST")
	_size(br_method, -2)
	frow.add_child(br_method)
	br_field = _line_edit("UI_BR_FIELD_PLACEHOLDER", -2)
	br_field.text = "input"
	br_field.size_flags_stretch_ratio = 0.45
	frow.add_child(br_field)
	br_value = _line_edit("UI_BR_VALUE_PLACEHOLDER", -2)
	br_value.text_submitted.connect(_on_br_value_submit)
	frow.add_child(br_value)
	frow.add_child(_small(_btn("UI_BR_SEND", "UI_BR_SEND_TIP", _br_submit_form)))
	br_form_box.add_child(frow)
	var lrow := HBoxContainer.new()
	lrow.add_child(_klabel("UI_BR_LOGIN_LABEL", C_DIM, -3))
	br_user = _line_edit("UI_BR_USER_PLACEHOLDER", -2)
	br_pass = _line_edit("UI_BR_PASS_PLACEHOLDER", -2)
	br_pass.secret = true
	br_pass.context_menu_enabled = false
	br_pass.text_submitted.connect(_on_br_pass_submit)
	lrow.add_child(br_user)
	lrow.add_child(br_pass)
	lrow.add_child(_small(_btn("UI_BR_LOGIN", "UI_BR_LOGIN_TIP", _br_login)))
	lrow.add_child(_small(_btn("UI_BR_LOGOUT", "UI_BR_LOGOUT_TIP", _br_logout)))
	br_form_box.add_child(lrow)
	br_form_box.add_child(_klabel("UI_BR_FORM_NOTE", C_FAINT, -4, true))
	col.add_child(br_form_box)

	var foot := HBoxContainer.new()
	br_status = _label("", C_DIM, -3)
	br_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br_status.clip_text = true
	br_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(br_status)
	br_stale = _klabel("UI_BR_STALE", C_AMBER, -3)
	br_stale.visible = false
	foot.add_child(br_stale)
	br_archive = _btn("UI_BR_ARCHIVE", "UI_BR_ARCHIVE_TIP", _br_archive_page)
	br_archive.add_theme_color_override("font_color", C_TEAL)
	br_archive.visible = false
	_size(br_archive, -3)
	foot.add_child(br_archive)
	col.add_child(foot)
	_br_form_label()
	_br_update_nav()
	return col


func _br_form_label() -> void:
	if br_form_toggle != null:
		br_form_toggle.text = ("▾ " if br_form_box.visible else "▸ ") + _t("UI_BR_FORM_TOGGLE")


func _br_toggle_form() -> void:
	br_form_box.visible = not br_form_box.visible
	_br_form_label()
	if br_form_box.visible:
		br_value.grab_focus()


func _on_br_addr_submit(text: String) -> void:
	if not br_addr.has_ime_text():
		_br_navigate(text, true)


func _on_br_value_submit(_text: String) -> void:
	if not br_value.has_ime_text():
		_br_submit_form()


func _on_br_pass_submit(_text: String) -> void:
	if not br_pass.has_ime_text():
		_br_login()


func _br_go_addr() -> void:
	_br_navigate(br_addr.text, true)


func _br_reload() -> void:
	_br_navigate(br_url if not br_url.is_empty() else br_addr.text, false)


func _br_home() -> void:
	_br_navigate(_s(last_view, "browser_home"), true)


func _br_navigate(url: String, push: bool) -> void:
	url = url.strip_edges()
	if url.is_empty() or not _can_act():
		return
	br_addr.text = url
	var r := _act("browser", func(): return game.browse(url))
	_br_render(r, url, push, true)


func _br_render(r: Dictionary, url: String, push: bool, is_nav: bool) -> void:
	_clear_children(br_links)
	br_stale.visible = false
	var ok := _b(r, "ok")
	var status := _i(r, "status", 200 if ok else 0)
	var code := _s(r, "code", "UNKNOWN")
	if ok:
		br_failed = false
		br_url = _s(r, "url", url)
		if push and (br_cursor < 0 or br_history[br_cursor] != br_url):
			br_history.resize(br_cursor + 1)
			br_history.append(br_url)
			br_cursor = br_history.size() - 1
		br_addr.text = br_url
		br_title.text = _s(r, "title")
		_set_plain(br_body, _s(r, "body", _s(r, "text")))
		for l in _a(r, "links"):
			var d := _d(l)
			var target := _s(d, "url")
			if target.is_empty():
				continue
			var lb := _btn_raw(_t("UI_BR_LINK", {"label": _s(d, "label", target), "url": target}), "", _br_navigate.bind(target, true))
			lb.tooltip_text = target
			lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lb.flat = true
			lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lb.add_theme_color_override("font_color", C_TEAL)
			_size(lb, -2)
			br_links.add_child(lb)
		if br_links.get_child_count() == 0:
			br_links.add_child(_label(_t("UI_BR_NO_LINKS"), C_FAINT, -3))
		br_archive.visible = _b(r, "can_archive")
		br_status.text = _t("UI_BR_STATUS_OK", {"status": status})
		br_status.add_theme_color_override("font_color", C_DIM if status < 400 else C_AMBER)
	else:
		if is_nav:
			br_failed = true
			br_url = ""
			br_archive.visible = false
		br_title.text = _br_error_title(status)
		var body := _s(r, "body", _s(r, "text"))
		_set_plain(br_body, body if not body.is_empty() else _t("UI_BR_ERR_EMPTY"))
		br_links.add_child(_label(_t("UI_BR_NO_LINKS"), C_FAINT, -3))
		br_status.text = _t("UI_BR_STATUS_ERR", {"code": code, "status": status, "url": url})
		br_status.add_theme_color_override("font_color", C_AMBER)
	br_status.tooltip_text = br_status.text
	br_meta.text = _br_meta_text(r)
	_br_update_nav()


func _br_meta_text(r: Dictionary) -> String:
	var route := " → ".join(PackedStringArray(_a(r, "route").map(func(x): return str(x))))
	return _t("UI_BR_META", {"status": _i(r, "status", 0), "actor": _s(r, "actor", "anonymous"),
			"context": _s(r, "actor_context", "—"), "route": route if not route.is_empty() else "—"})


func _br_error_title(status: int) -> String:
	match status:
		400:
			return _t("UI_BR_ERR_400")
		401:
			return _t("UI_BR_ERR_401")
		403:
			return _t("UI_BR_ERR_403")
		404:
			return _t("UI_BR_ERR_404")
		405:
			return _t("UI_BR_ERR_405")
		415:
			return _t("UI_BR_ERR_415")
		429:
			return _t("UI_BR_ERR_429")
		503:
			return _t("UI_BR_ERR_503")
	return _t("UI_BR_ERR_OTHER", {"status": status})


func _br_go(dir: int) -> void:
	if br_failed and dir < 0 and br_cursor >= 0:
		_br_navigate(br_history[br_cursor], false)
		return
	var n := br_cursor + dir
	if n < 0 or n >= br_history.size():
		return
	br_cursor = n
	_br_navigate(br_history[n], false)


func _br_update_nav() -> void:
	br_back.disabled = br_cursor <= 0 and not (br_failed and br_cursor >= 0)
	br_fwd.disabled = br_cursor >= br_history.size() - 1


func _br_page() -> String:
	return br_url if not br_url.is_empty() else br_addr.text.strip_edges()


static func _origin(url: String) -> String:
	var u := url.strip_edges()
	var i := u.find("://")
	if i < 0:
		return ""
	var host := u.substr(i + 3).get_slice("/", 0).get_slice("?", 0)
	if host.is_empty():
		return ""
	return u.substr(0, i + 3) + host


func _br_submit_form() -> void:
	if not _can_act():
		return
	var field := br_field.text.strip_edges()
	var value := br_value.text
	if field.is_empty() or value.strip_edges().is_empty():
		_br_note(_t("UI_BR_FORM_EMPTY"), C_AMBER)
		return
	var page := _br_page()
	if page.is_empty():
		_br_note(_t("UI_BR_NO_PAGE"), C_AMBER)
		return
	var base := page.get_slice("?", 0)
	if br_method.selected == 0:
		_br_navigate(base + "?" + field.uri_encode() + "=" + value.uri_encode(), true)
		return
	var body := {field: value}
	var r := _act("browser", func(): return game.request("POST", base, body, {"X-Packet-Context": "browser"}))
	_br_render(r, base, false, false)


func _br_login() -> void:
	if not _can_act():
		return
	var user := br_user.text.strip_edges()
	var secret_text := br_pass.text
	br_pass.clear()
	var origin := _origin(_br_page())
	if user.is_empty() or secret_text.is_empty() or origin.is_empty():
		_br_note(_t("UI_BR_LOGIN_EMPTY"), C_AMBER)
		return
	var body := {"username": user, "password": secret_text}
	secret_text = ""
	var r := _act("browser", func(): return game.request("POST", origin + "/login", body, {"X-Packet-Context": "browser"}))
	body.clear()
	_br_note(_t("UI_BR_AUTH_RESULT", {"status": _i(r, "status", 0), "detail": _s(r, "text")}), C_TEAL if _b(r, "ok") else C_AMBER)
	if not br_url.is_empty():
		br_stale.visible = true


func _br_logout() -> void:
	if not _can_act():
		return
	var origin := _origin(_br_page())
	if origin.is_empty():
		_br_note(_t("UI_BR_NO_PAGE"), C_AMBER)
		return
	var r := _act("browser", func(): return game.request("POST", origin + "/logout", {}, {"X-Packet-Context": "browser"}))
	_br_note(_t("UI_BR_AUTH_RESULT", {"status": _i(r, "status", 0), "detail": _s(r, "text")}), C_DIM if _b(r, "ok") else C_AMBER)
	if not br_url.is_empty():
		br_stale.visible = true


func _br_note(text: String, color: Color) -> void:
	br_status.text = text.replace("\n", " · ")
	br_status.tooltip_text = text
	br_status.add_theme_color_override("font_color", color)


func _br_archive_page() -> void:
	if br_url.is_empty() or not _can_act():
		return
	var url := br_url
	var r := _act("browser", func(): return game.collect_web(url))
	_br_note(_s(r, "text"), C_TEAL if _b(r, "ok") else C_AMBER)


func _br_to_lab() -> void:
	rl_method.select(0)
	rl_url.text = _br_page()
	_open_app("requestlab", true)


func _br_reset() -> void:
	br_history.clear()
	br_cursor = -1
	br_url = ""
	br_failed = false
	br_opened = false
	br_addr.text = ""
	br_title.text = ""
	br_meta.text = ""
	br_body.clear()
	_clear_children(br_links)
	br_archive.visible = false
	br_stale.visible = false
	br_status.text = ""
	br_pass.clear()
	_br_update_nav()


# ── RequestLab (브라우저·curl과 같은 가상 요청 처리기) ──────────

func _build_requestlab() -> Control:
	var split := VSplitContainer.new()
	var top := VBoxContainer.new()
	var row := HBoxContainer.new()
	rl_method = OptionButton.new()
	for m in METHODS:
		rl_method.add_item(m)
	_size(rl_method, -2)
	row.add_child(rl_method)
	rl_url = _line_edit("UI_RL_URL_PLACEHOLDER")
	rl_url.text_submitted.connect(_on_rl_url_submit)
	row.add_child(rl_url)
	row.add_child(_btn("UI_RL_SEND", "UI_RL_SEND_TIP", _rl_send))
	row.add_child(_small(_btn("UI_RL_FROM_BROWSER", "UI_RL_FROM_BROWSER_TIP", _rl_from_browser)))
	top.add_child(row)
	var editors := HBoxContainer.new()
	editors.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editors.add_theme_constant_override("separation", 10)
	var hcol := VBoxContainer.new()
	hcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hcol.add_child(_section("UI_RL_HEADERS"))
	rl_headers = _text_edit("UI_RL_HEADERS_PLACEHOLDER", 90)
	rl_headers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(rl_headers)
	var bcol := VBoxContainer.new()
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bcol.add_child(_section("UI_RL_BODY"))
	rl_body = _text_edit("UI_RL_BODY_PLACEHOLDER", 90)
	rl_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bcol.add_child(rl_body)
	editors.add_child(hcol)
	editors.add_child(bcol)
	top.add_child(editors)
	rl_error = _label("", C_AMBER, -3, true)
	rl_error.visible = false
	top.add_child(rl_error)
	var rrow := HBoxContainer.new()
	rrow.add_child(_klabel("UI_RL_RECENT", C_DIM, -3))
	rl_recent = OptionButton.new()
	rl_recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl_recent.clip_text = true
	rl_recent.item_selected.connect(_rl_load_recent)
	_size(rl_recent, -3)
	rrow.add_child(rl_recent)
	top.add_child(rrow)
	top.add_child(_klabel("UI_RL_NOTE", C_FAINT, -4, true))
	split.add_child(top)
	var bottom := VBoxContainer.new()
	bottom.add_child(_section("UI_RL_RESPONSE"))
	rl_status = _label("", C_DIM, 1)
	rl_meta = _label("", C_DIM, -3, true)
	rl_trace = _label("", C_FAINT, -4, true)
	rl_response = _plain_text()
	rl_response.custom_minimum_size = Vector2(0, 90)
	for c in [rl_status, rl_meta, rl_trace, rl_response]:
		bottom.add_child(c)
	split.add_child(bottom)
	_rl_rebuild_recent()
	_rl_reset_response()
	return split


func _rl_reset_response() -> void:
	rl_status.text = _t("UI_RL_NO_RESPONSE")
	rl_status.add_theme_color_override("font_color", C_FAINT)
	rl_meta.text = ""
	rl_trace.text = ""
	rl_response.clear()


func _on_rl_url_submit(_text: String) -> void:
	if not rl_url.has_ime_text():
		_rl_send()


func _rl_from_browser() -> void:
	rl_method.select(0)
	rl_url.text = _br_page()
	rl_url.grab_focus()


## 비어 있으면 빈 객체. JSON 객체가 아니면 코어를 호출하지 않고 이유를 돌려준다.
func _parse_json_object(text: String, field: String) -> Dictionary:
	var s := text.strip_edges()
	if s.is_empty():
		return {"ok": true, "value": {}}
	if s.length() > MAX_JSON_CHARS:
		return {"ok": false, "error": _t("UI_JSON_TOO_LONG", {"field": field, "max": MAX_JSON_CHARS})}
	var parser := JSON.new()
	if parser.parse(s) != OK:
		return {"ok": false, "error": _t("UI_JSON_INVALID", {"field": field, "line": parser.get_error_line(), "detail": parser.get_error_message()})}
	if not parser.data is Dictionary:
		return {"ok": false, "error": _t("UI_JSON_NOT_OBJECT", {"field": field})}
	return {"ok": true, "value": parser.data}


func _rl_fail(text: String) -> void:
	rl_error.text = text
	rl_error.visible = true


func _rl_send() -> void:
	if not _can_act():
		return
	rl_error.visible = false
	var url := rl_url.text.strip_edges()
	if url.is_empty():
		_rl_fail(_t("UI_RL_ERR_URL"))
		return
	var hr := _parse_json_object(rl_headers.text, _t("UI_RL_HEADERS"))
	if not _b(hr, "ok"):
		_rl_fail(_s(hr, "error"))
		return
	var headers: Dictionary = {}
	var raw_headers := _d(hr.get("value", {}))
	for k in raw_headers:
		var val = raw_headers[k]
		if not (val is String or val is float or val is int or val is bool):
			_rl_fail(_t("UI_RL_ERR_HEADER_VALUE", {"name": str(k)}))
			return
		headers[str(k)] = str(val)
	var br := _parse_json_object(rl_body.text, _t("UI_RL_BODY"))
	if not _b(br, "ok"):
		_rl_fail(_s(br, "error"))
		return
	var body := _d(br.get("value", {}))
	var method: String = METHODS[clampi(rl_method.selected, 0, METHODS.size() - 1)]
	var r := _act("requestlab", func(): return game.request(method, url, body, headers, active_term))
	_rl_render(r)
	_rl_remember(method, url, rl_headers.text, rl_body.text)


func _rl_render(r: Dictionary) -> void:
	var status := _i(r, "status", 0)
	rl_status.text = _t("UI_RL_STATUS", {"status": status, "code": _s(r, "code", "—")})
	var col := C_TEAL if status > 0 and status < 300 else (C_TEXT if status > 0 and status < 400 else C_AMBER)
	rl_status.add_theme_color_override("font_color", col)
	var route := " → ".join(PackedStringArray(_a(r, "route").map(func(x): return str(x))))
	var cookie := _s(r, "cookie_preview")
	var meta := _t("UI_RL_META", {"actor": _s(r, "actor", "anonymous"), "context": _s(r, "actor_context", "—"),
			"origin": _s(r, "source_origin", "—"), "route": route if not route.is_empty() else "—",
			"cookie": cookie if not cookie.is_empty() else "—"})
	var headers := _d(r.get("headers", {}))
	if not headers.is_empty():
		meta += "\n" + _t("UI_RL_RESPONSE_HEADERS", {"list": JSON.stringify(headers)})
	if _b(r, "changed"):
		meta += "\n" + _t("UI_RL_CHANGED")
	rl_meta.text = meta
	var lines: Array = []
	for step in _a(r, "trace"):
		var d := _d(step)
		lines.append("%s %s · host=%s · actor=%s · origin=%s" % [_s(d, "method"), _s(d, "status"), _s(d, "host_id"), _s(d, "actor"), _s(d, "origin")])
	rl_trace.text = _t("UI_RL_TRACE", {"lines": "\n".join(PackedStringArray(lines))}) if not lines.is_empty() else ""
	_set_plain(rl_response, _s(r, "body", _s(r, "text")))


func _rl_remember(method: String, url: String, headers_text: String, body_text: String) -> void:
	var entry := {"method": method, "url": url, "headers": headers_text, "body": body_text}
	for i in range(rl_history.size() - 1, -1, -1):
		if rl_history[i] == entry:
			rl_history.remove_at(i)
	rl_history.push_front(entry)
	if rl_history.size() > 20:
		rl_history.resize(20)
	_rl_rebuild_recent()


func _rl_rebuild_recent() -> void:
	rl_recent.clear()
	rl_recent.add_item(_t("UI_RL_RECENT_NONE") if rl_history.is_empty() else _t("UI_RL_RECENT_PICK"))
	for e in rl_history:
		rl_recent.add_item("%s %s" % [e["method"], e["url"]])
	rl_recent.select(0)


func _rl_load_recent(i: int) -> void:
	if i <= 0 or i > rl_history.size():
		return
	var e: Dictionary = rl_history[i - 1]
	rl_method.select(maxi(METHODS.find(str(e["method"])), 0))
	rl_url.text = str(e["url"])
	rl_headers.text = str(e["headers"])
	rl_body.text = str(e["body"])
	rl_recent.select(0)


# ── 도구 작업대 ───────────────────────────────────────────────
# 코어 view.tools의 공개 관찰(data)과 입력 이름(input_schema)만 사용한다. 실행 버튼은 정답 버튼이 아니며,
# 빈 입력은 코어로 보내지 않는다. 숨은 정답·목표 값은 화면에 만들지 않는다.

var tool_policy_label: Label
var tool_actor_label: Label


func _build_tools() -> Control:
	var split := HSplitContainer.new()
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	left.add_child(_section("UI_TOOL_LIST"))
	tool_list = ItemList.new()
	tool_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tool_list.item_selected.connect(_on_tool_selected)
	_size(tool_list, -2)
	left.add_child(tool_list)
	left.add_child(_klabel("UI_TOOL_LIST_NOTE", C_FAINT, -4, true))
	split.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_empty = _klabel("UI_TOOL_EMPTY", C_DIM, -1, true)
	right.add_child(tool_empty)
	tool_detail = VBoxContainer.new()
	tool_detail.add_theme_constant_override("separation", 8)
	tool_title = _label("", C_TEXT, 3, true)
	tool_kind = _label("", C_TEAL_DIM, -3, true)
	tool_desc = _label("", C_TEXT, -1, true)
	tool_usage = _label("", C_DIM, -2, true)
	tool_req = _label("", C_AMBER, -3, true)
	for c in [tool_title, tool_kind, tool_desc, tool_usage, tool_req]:
		tool_detail.add_child(c)
	tool_detail.add_child(_section("UI_TOOL_OBSERVATIONS"))
	tool_obs_box = VBoxContainer.new()
	tool_detail.add_child(tool_obs_box)
	tool_detail.add_child(_section("UI_TOOL_INPUT"))
	tool_input_box = VBoxContainer.new()
	tool_detail.add_child(tool_input_box)
	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 12)
	tool_run_btn = _btn("UI_TOOL_RUN", "UI_TOOL_RUN_TIP", _tool_run)
	tool_run_btn.add_theme_color_override("font_color", C_TEAL)
	run_row.add_child(tool_run_btn)
	tool_adv_toggle = CheckButton.new()
	_reg(tool_adv_toggle, "text", "UI_TOOL_ADVANCED")
	_reg(tool_adv_toggle, "tooltip_text", "UI_TOOL_ADVANCED_TIP")
	tool_adv_toggle.toggled.connect(_on_tool_adv_toggled)
	_size(tool_adv_toggle, -3)
	run_row.add_child(tool_adv_toggle)
	tool_detail.add_child(run_row)
	tool_adv_box = VBoxContainer.new()
	tool_adv_box.visible = false
	tool_adv_box.add_child(_klabel("UI_TOOL_ADVANCED_NOTE", C_FAINT, -4, true))
	tool_adv_edit = _text_edit("UI_TOOL_ADVANCED_PLACEHOLDER", 90)
	tool_adv_box.add_child(tool_adv_edit)
	tool_adv_box.add_child(_small(_btn("UI_TOOL_RUN_JSON", "UI_TOOL_RUN_JSON_TIP", _tool_run_json)))
	tool_detail.add_child(tool_adv_box)
	tool_detail.add_child(_section("UI_TOOL_RESULT"))
	tool_result_status = _label("", C_DIM, -1, true)
	tool_detail.add_child(tool_result_status)
	tool_result = _plain_text()
	tool_result.fit_content = true
	tool_result.scroll_active = false
	tool_result.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tool_result.custom_minimum_size = Vector2(0, 56)
	tool_detail.add_child(tool_result)
	tool_detail.add_child(_section("UI_TOOL_LEARN"))
	tool_model = _label("", C_DIM, -2, true)
	tool_limit = _label("", C_FAINT, -3, true)
	tool_detail.add_child(tool_model)
	tool_detail.add_child(tool_limit)
	tool_detail.visible = false
	right.add_child(_scroll_wrap(tool_detail))
	split.add_child(right)
	return split


func _kind_name(kind: String) -> String:
	var key := "UI_TOOLKIND_" + kind.to_upper()
	var s := _t(key)
	return kind if s == key else s


## 번역이 없으면 빈 문자열(키를 화면에 노출하지 않음).
func _t_opt(key: String, repl: Dictionary = {}) -> String:
	var s := _t(key, repl)
	return "" if s == key else s


func _tool_current() -> Dictionary:
	for t in _a(last_view, "tools"):
		var d := _d(t)
		if _s(d, "id") == tool_selected:
			return d
	return {}


func _refresh_tools(v: Dictionary) -> void:
	var tools := _a(v, "tools")
	var ids: Array = []
	for t in tools:
		ids.append(_s(_d(t), "id"))
	var sig := _s(v, "mission_id") + "|" + ",".join(PackedStringArray(ids)) + "|" + Localization.get_locale()
	if sig != tool_ids_sig:
		tool_ids_sig = sig
		tool_list.clear()
		for t in tools:
			var d := _d(t)
			var i := tool_list.add_item(_t("UI_TOOL_LIST_ITEM", {"name": _s(d, "name", _s(d, "id")), "kind": _kind_name(_s(d, "kind"))}))
			tool_list.set_item_metadata(i, _s(d, "id"))
			tool_list.set_item_tooltip(i, _s(d, "id"))
	var has := not tools.is_empty()
	tool_empty.visible = not has
	tool_detail.visible = has
	if not has:
		tool_selected = ""
		return
	var idx := ids.find(tool_selected)
	var rebuild := idx < 0
	if idx < 0:
		idx = 0
	tool_list.select(idx)
	var tool := _d(tools[idx])
	if rebuild:
		_tool_show(tool, true)
	elif JSON.stringify(_d(tool.get("data", {}))) != tool_observation_sig:
		_tool_build_obs(tool)
	_tool_update_context(tool, v)


func _on_tool_selected(i: int) -> void:
	var id := str(tool_list.get_item_metadata(i))
	if id == tool_selected:
		return
	_tool_save_draft()
	tool_selected = id
	var tool := _tool_current()
	if not tool.is_empty():
		_tool_show(tool, true)
		_tool_update_context(tool, last_view)


func _tool_show(tool: Dictionary, rebuild: bool) -> void:
	if not rebuild:
		return
	if _s(tool, "id") != tool_selected:
		_tool_save_draft()
	tool_selected = _s(tool, "id")
	var kind := _s(tool, "kind")
	tool_title.text = _s(tool, "name", tool_selected)
	tool_kind.text = _t("UI_TOOL_KIND_LINE", {"kind": _kind_name(kind), "id": tool_selected})
	var desc := _s(tool, "description")
	tool_desc.text = desc if not desc.is_empty() else _t("UI_TOOL_NO_DESC")
	var usage := _s(tool, "usage")
	tool_usage.text = _t("UI_TOOL_USAGE", {"text": usage}) if not usage.is_empty() else ""
	tool_usage.visible = not usage.is_empty()
	_tool_build_obs(tool)
	_tool_build_inputs(tool)
	tool_adv_edit.text = ""
	if tool_adv_toggle.button_pressed:
		tool_adv_edit.text = _tool_template(tool)
	tool_result_status.text = _t("UI_TOOL_NOT_RUN")
	tool_result_status.add_theme_color_override("font_color", C_FAINT)
	tool_result.clear()
	var key := kind.to_upper()
	var model := _t_opt("UI_TOOLKIND_%s_MODEL" % key)
	var limit := _t_opt("UI_TOOLKIND_%s_LIMIT" % key)
	tool_model.text = _t("UI_TOOL_MODEL", {"text": model if not model.is_empty() else _t("UI_TOOL_MODEL_GENERIC")})
	tool_limit.text = _t("UI_TOOL_LIMIT", {"text": limit if not limit.is_empty() else _t("UI_TOOL_LIMIT_GENERIC")})


func _tool_update_context(tool: Dictionary, v: Dictionary) -> void:
	var facts := _a(v, "facts")
	var missing := 0
	for f in _a(tool, "requirements"):
		if not facts.has(f):
			missing += 1
	tool_req.text = _t("UI_TOOL_REQ_MISSING", {"n": missing}) if missing > 0 else ""
	tool_req.visible = missing > 0
	if tool_policy_label != null and is_instance_valid(tool_policy_label):
		tool_policy_label.text = _t("UI_TOOL_OBS_POLICIES", {"list": _policy_list(_d(v.get("policies", {})))})
	if tool_actor_label != null and is_instance_valid(tool_actor_label):
		var tv: Dictionary = term_views[active_term]
		tool_actor_label.text = _t("UI_TOOL_OBS_ACTOR", {"n": active_term + 1, "user": _s(tv, "user"), "host": _s(tv, "host")})


func _policy_list(p: Dictionary) -> String:
	if p.is_empty():
		return "—"
	var parts: Array = []
	for k in p:
		parts.append("%s=%s" % [str(k), JSON.stringify(p[k])])
	return ", ".join(PackedStringArray(parts))


func _tool_build_obs(tool: Dictionary) -> void:
	tool_observation_sig = JSON.stringify(_d(tool.get("data", {})))
	_clear_children(tool_obs_box)
	tool_tree = null
	tool_memory = null
	tool_xor_key = null
	tool_xor_out = null
	tool_policy_label = null
	tool_actor_label = null
	tool_row_keys = []
	var data := _d(tool.get("data", {}))
	var kind := _s(tool, "kind")
	var any := false
	if data.has("rows"):
		_obs_rows(_a(data, "rows"))
		any = true
	if data.has("encoded"):
		_obs_bytes(_a(data, "encoded"), data.get("xor_key", null))
		any = true
	if data.has("memory_size") or data.has("buffer_size"):
		_obs_memory(_i(data, "buffer_size", 0), _i(data, "memory_size", 64))
		any = true
	if data.has("targets"):
		_obs_pick_list(_a(data, "targets"), "target")
		any = true
	if data.has("files"):
		_obs_pick_list(_a(data, "files"), "path")
		any = true
	if data.has("base_path"):
		tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_BASE_PATH", {"path": _s(data, "base_path")}), C_TEXT, -2, true))
		any = true
	if data.has("origin"):
		tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_ORIGIN", {"origin": _s(data, "origin")}), C_TEXT, -2, true))
		any = true
	if kind == "policy":
		tool_policy_label = _label("", C_TEXT, -2, true)
		tool_obs_box.add_child(tool_policy_label)
		any = true
	if kind in ["permission", "idor", "session", "auth", "csrf"]:
		tool_actor_label = _label("", C_DIM, -3, true)
		tool_obs_box.add_child(tool_actor_label)
		tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_ACTOR_NOTE"), C_FAINT, -4, true))
		any = true
	if not any:
		tool_obs_box.add_child(_label(_t("UI_TOOL_NO_DATA"), C_FAINT, -3, true))


func _obs_rows(rows: Array) -> void:
	for r in rows:
		for k in _d(r):
			if not tool_row_keys.has(str(k)):
				tool_row_keys.append(str(k))
	if tool_row_keys.is_empty():
		tool_obs_box.add_child(_label(_t("UI_TOOL_ROWS_EMPTY"), C_FAINT, -3, true))
		return
	tool_tree = Tree.new()
	tool_tree.columns = tool_row_keys.size()
	tool_tree.column_titles_visible = true
	tool_tree.hide_root = true
	tool_tree.select_mode = Tree.SELECT_SINGLE
	tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown := mini(rows.size(), MAX_TABLE_ROWS)
	tool_tree.custom_minimum_size = Vector2(0, clampf(float(shown + 1) * float(ui_size + 12), 120.0, 300.0))
	for c in tool_row_keys.size():
		tool_tree.set_column_title(c, tool_row_keys[c])
		tool_tree.set_column_expand(c, true)
		tool_tree.set_column_clip_content(c, true)
	var root := tool_tree.create_item()
	for i in shown:
		var d := _d(rows[i])
		var item := tool_tree.create_item(root)
		for c in tool_row_keys.size():
			var cell := str(d.get(tool_row_keys[c], ""))
			item.set_text(c, cell)
			item.set_tooltip_text(c, cell)
	tool_tree.cell_selected.connect(_on_tool_cell_selected)
	tool_tree.item_selected.connect(_on_tool_cell_selected)
	_size(tool_tree, -3)
	tool_obs_box.add_child(tool_tree)
	tool_obs_box.add_child(_label(_t("UI_TOOL_ROWS_NOTE", {"n": rows.size()}), C_FAINT, -4, true))


## 공용 도구(NetProbe/TraceRoute/FileLens/LogLens)의 후보: 코어가 준 이미 발견한 호스트·현재 읽을 수 있는 cwd 목록뿐.
func _obs_pick_list(items: Array, field: String) -> void:
	if items.is_empty():
		tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_NONE_KNOWN"), C_FAINT, -3, true))
		return
	tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_TARGETS") if field == "target" else _t("UI_TOOL_OBS_FILES"), C_DIM, -3, true))
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, clampf(float(items.size()) * float(ui_size + 12), 70.0, 200.0))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		var d := _d(it)
		var value := ""
		var text := ""
		if field == "target":
			value = _s(d, "address", _s(d, "id"))
			text = _t("UI_TOOL_TARGET_ITEM", {"name": _s(d, "name", _s(d, "id")), "address": value})
		else:
			value = _s(d, "path")
			text = value + ("/" if _s(d, "kind") == "dir" else "")
		if value.is_empty():
			continue
		var i := list.add_item(text)
		list.set_item_metadata(i, value)
		list.set_item_tooltip(i, value)
	list.item_selected.connect(_on_pick_selected.bind(list, field))
	_size(list, -3)
	tool_obs_box.add_child(list)


func _on_pick_selected(i: int, list: ItemList, field: String) -> void:
	var ctl = tool_inputs.get(field)
	if ctl is LineEdit:
		ctl.text = str(list.get_item_metadata(i))
		ctl.caret_column = ctl.text.length()


func _on_tool_cell_selected() -> void:
	if tool_tree == null:
		return
	var it := tool_tree.get_selected()
	var col := tool_tree.get_selected_column()
	if it == null or col < 0 or col >= tool_row_keys.size():
		return
	var field = tool_inputs.get("__field")
	var value = tool_inputs.get("__value")
	if field is OptionButton:
		field.select(col + 1)
	if value is LineEdit:
		value.text = it.get_text(col)


func _obs_bytes(encoded: Array, key) -> void:
	var hex: Array = []
	var dec: Array = []
	for b in encoded:
		hex.append("%02X" % (int(b) & 0xFF))
		dec.append(str(int(b)))
	tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_BYTES", {"n": encoded.size(), "hex": " ".join(PackedStringArray(hex))}), C_TEXT, -2, true, true))
	tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_BYTES_DEC", {"dec": " ".join(PackedStringArray(dec))}), C_DIM, -3, true))
	if key is int or key is float:
		var k := int(key)
		tool_obs_box.add_child(_label(_t("UI_TOOL_OBS_XOR", {"dec": k, "hex": "%02X" % (k & 0xFF)}), C_TEXT, -2, true))
	var row := HBoxContainer.new()
	row.add_child(_label(_t("UI_TOOL_XOR_CALC"), C_DIM, -3))
	tool_xor_key = _line_edit("UI_TOOL_XOR_KEY_PLACEHOLDER", -2)
	tool_xor_key.max_length = 6
	tool_xor_key.custom_minimum_size = Vector2(120, 0)
	tool_xor_key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tool_xor_key.set_meta("bytes", encoded)
	tool_xor_key.text_changed.connect(_on_xor_key_changed)
	row.add_child(tool_xor_key)
	tool_obs_box.add_child(row)
	tool_xor_out = _label("", C_TEAL_DIM, -2, true, true)
	tool_obs_box.add_child(tool_xor_out)
	tool_obs_box.add_child(_label(_t("UI_TOOL_XOR_NOTE"), C_FAINT, -4, true))


## 플레이어가 직접 넣은 키로만 계산하는 보조 계산기. 결과를 입력칸에 자동으로 넣지 않는다.
func _on_xor_key_changed(text: String) -> void:
	if tool_xor_key == null or tool_xor_out == null:
		return
	var s := text.strip_edges().to_lower()
	if s.is_empty():
		tool_xor_out.text = ""
		return
	var k := -1
	if s.begins_with("0x") and s.length() > 2 and s.substr(2).is_valid_hex_number():
		k = s.substr(2).hex_to_int()
	elif s.is_valid_int():
		k = s.to_int()
	if k < 0 or k > 255:
		tool_xor_out.text = _t("UI_TOOL_XOR_BAD_KEY")
		return
	var chars := ""
	for b in tool_xor_key.get_meta("bytes", []):
		var c := (int(b) ^ k) & 0xFF
		chars += String.chr(c) if c >= 32 and c < 127 else "·"
	tool_xor_out.text = _t("UI_TOOL_XOR_RESULT", {"key": k, "text": chars})


func _obs_memory(buffer_size: int, memory_size: int) -> void:
	tool_memory = MemoryGrid.new()
	tool_memory.memory_size = clampi(memory_size if memory_size > 0 else 64, 1, 512)
	tool_memory.buffer_size = clampi(buffer_size, 0, tool_memory.memory_size)
	tool_memory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_obs_box.add_child(tool_memory)
	tool_memory.update_minimum_size()
	tool_obs_box.add_child(_label(_t("UI_TOOL_MEM_LEGEND", {"buffer": tool_memory.buffer_size, "size": tool_memory.memory_size}), C_DIM, -3, true))


func _on_mem_input_changed(text: String) -> void:
	if tool_memory == null:
		return
	var hex := text.to_lower().replace(" ", "")
	var bytes: Array = []
	var valid := hex.length() % 2 == 0
	for ch in hex:
		if not ch in "0123456789abcdef":
			valid = false
	if valid:
		for i in range(0, mini(hex.length(), tool_memory.memory_size * 2), 2):
			bytes.append(hex.substr(i, 2).hex_to_int())
	tool_memory.bytes = bytes
	tool_memory.invalid = not valid and not hex.is_empty()
	tool_memory.queue_redraw()


func _tool_schema(tool: Dictionary) -> Array:
	var schema: Array = []
	for f in _a(tool, "input_schema"):
		schema.append(str(f))
	if schema.is_empty():
		schema = ["input"]
	return schema


func _field_name(f: String) -> String:
	var s := _t_opt("UI_TOOL_FIELD_" + f.to_upper())
	return s if not s.is_empty() else f


func _tool_build_inputs(tool: Dictionary) -> void:
	_clear_children(tool_input_box)
	tool_inputs = {}
	var kind := _s(tool, "kind")
	var schema := _tool_schema(tool)
	var draft := _d(tool_drafts.get(tool_selected, {}))
	if schema.size() == 1 and schema[0] == "input":
		if kind in ["packet", "trace"] and not tool_row_keys.is_empty():
			var row := HBoxContainer.new()
			row.add_child(_label(_t("UI_TOOL_FILTER"), C_DIM, -3))
			var opt := OptionButton.new()
			opt.add_item(_t("UI_TOOL_PICK_FIELD"))
			for k in tool_row_keys:
				opt.add_item(str(k))
			opt.set_meta("placeholder", true)
			_size(opt, -2)
			row.add_child(opt)
			row.add_child(_label("=", C_DIM, -2))
			var val := _line_edit("UI_TOOL_PH_FILTER_VALUE", -2)
			val.text_submitted.connect(_on_tool_submit)
			row.add_child(val)
			tool_input_box.add_child(row)
			tool_inputs["__field"] = opt
			tool_inputs["__value"] = val
		else:
			var ph := "UI_TOOL_PH_" + kind.to_upper()
			if _t_opt(ph).is_empty():
				ph = "UI_TOOL_PH_GENERIC"
			var e := _line_edit(ph, -1)
			e.text_submitted.connect(_on_tool_submit)
			if kind == "memory":
				e.text_changed.connect(_on_mem_input_changed)
			tool_input_box.add_child(e)
			tool_inputs["input"] = e
	else:
		var fields: Array = schema.duplicate()
		if kind == "session" and not fields.has("ticks"):
			fields.append("ticks")
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 6)
		for f in fields:
			grid.add_child(_label(_field_name(f), C_DIM, -3))
			var ctl: Control
			if f == "action" and kind in ["session", "auth"]:
				var opt := OptionButton.new()
				opt.add_item(_t("UI_TOOL_PICK_ACTION"))
				for a in (["issue", "reuse", "revoke", "wait"] if kind == "session" else ["login", "wait"]):
					opt.add_item(a)
				opt.set_meta("placeholder", true)
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_size(opt, -2)
				ctl = opt
			else:
				var e := _line_edit("", -2)
				e.placeholder_text = _t_opt("UI_TOOL_PH_FIELD_" + f.to_upper())
				if f == "password":
					e.secret = true
					e.context_menu_enabled = false
				e.text_submitted.connect(_on_tool_submit)
				ctl = e
			grid.add_child(ctl)
			tool_inputs[f] = ctl
		tool_input_box.add_child(grid)
	# 입력 초안 복원(암호는 저장하지 않는다)
	for f in tool_inputs:
		if not draft.has(f) or f == "password":
			continue
		var ctl = tool_inputs[f]
		if ctl is LineEdit:
			ctl.text = str(draft[f])
			if f == "input" and kind == "memory":
				_on_mem_input_changed(ctl.text)
		elif ctl is OptionButton:
			var idx := int(draft[f])
			if idx >= 0 and idx < ctl.item_count:
				ctl.select(idx)
	tool_input_box.add_child(_label(_t("UI_TOOL_INPUT_NOTE"), C_FAINT, -4, true))


func _tool_save_draft() -> void:
	if tool_selected.is_empty() or tool_inputs.is_empty():
		return
	var d := {}
	for f in tool_inputs:
		var ctl = tool_inputs[f]
		if not is_instance_valid(ctl) or f == "password":
			continue
		if ctl is LineEdit:
			d[f] = ctl.text
		elif ctl is OptionButton:
			d[f] = ctl.selected
	tool_drafts[tool_selected] = d


func _input_value(f: String) -> String:
	var ctl = tool_inputs.get(f)
	if ctl is LineEdit:
		return ctl.text
	if ctl is OptionButton:
		if ctl.selected < 0 or (ctl.selected == 0 and ctl.has_meta("placeholder")):
			return ""
		return ctl.get_item_text(ctl.selected)
	return ""


func _tool_params() -> Dictionary:
	var tool := _tool_current()
	var kind := _s(tool, "kind")
	if tool_inputs.has("__field"):
		var field := _input_value("__field")
		var value := _input_value("__value").strip_edges()
		if field.is_empty() or value.is_empty():
			return {}
		return {"input": field + "=" + value}
	if tool_inputs.size() == 1 and tool_inputs.has("input"):
		var text := _input_value("input")
		if text.strip_edges().is_empty():
			return {}
		return {"input": text.strip_edges() if kind == "memory" else text}
	var p := {}
	for f in tool_inputs:
		var val := _input_value(f)
		if val.strip_edges().is_empty():
			continue
		if f == "ticks":
			if not val.strip_edges().is_valid_int():
				return {"__error": _t("UI_TOOL_ERR_TICKS")}
			p[f] = val.strip_edges().to_int()
		else:
			p[f] = val
	return p


func _on_tool_submit(_text: String) -> void:
	var fo := get_viewport().gui_get_focus_owner()
	if fo is LineEdit and fo.has_ime_text():
		return
	_tool_run()


func _tool_run() -> void:
	if not _can_act():
		return
	var tool := _tool_current()
	if tool.is_empty():
		return
	var params := _tool_params()
	if params.has("__error"):
		_tool_local_error(str(params["__error"]))
		return
	if params.is_empty():
		_tool_local_error(_t("UI_TOOL_NEED_INPUT"))
		return
	params["terminal_id"] = active_term
	_tool_exec(tool, params)
	var pw = tool_inputs.get("password")
	if pw is LineEdit:
		pw.clear()


func _tool_local_error(text: String) -> void:
	tool_result_status.text = text
	tool_result_status.add_theme_color_override("font_color", C_AMBER)
	tool_result.clear()


func _tool_exec(tool: Dictionary, params: Dictionary) -> void:
	var id := _s(tool, "id")
	var before_arc := _a(last_view, "archive").size()
	var r := _act("tools", func(): return game.use_tool(id, params))
	var grew := _a(last_view, "archive").size() > before_arc
	var ok := _b(r, "ok")
	var code := _s(r, "code", "—")
	var lines: Array = []
	if ok:
		lines.append(_t("UI_TOOL_RESULT_OK", {"code": code, "status": _i(r, "status", 200)}))
	else:
		lines.append(_t("UI_TOOL_RESULT_ERR", {"code": code}))
		var why := _t_opt("UI_TOOL_ERR_" + code)
		if not why.is_empty():
			lines.append(why)
	if grew:
		lines.append(_t("UI_TOOL_RESULT_RECOVERED"))
	tool_result_status.text = "\n".join(PackedStringArray(lines))
	tool_result_status.add_theme_color_override("font_color", C_TEAL if grew else (C_TEXT if ok else C_AMBER))
	_set_plain(tool_result, _s(r, "text"))


func _on_tool_adv_toggled(on: bool) -> void:
	tool_adv_box.visible = on
	if on and tool_adv_edit.text.strip_edges().is_empty():
		tool_adv_edit.text = _tool_template(_tool_current())


func _tool_template(tool: Dictionary) -> String:
	if tool.is_empty():
		return ""
	var t := {}
	for f in _tool_schema(tool):
		t[f] = ""
	return JSON.stringify(t, "  ")


func _tool_run_json() -> void:
	if not _can_act():
		return
	var tool := _tool_current()
	if tool.is_empty():
		return
	var pr := _parse_json_object(tool_adv_edit.text, _t("UI_TOOL_ADVANCED"))
	if not _b(pr, "ok"):
		_tool_local_error(_s(pr, "error"))
		return
	var params := _d(pr.get("value", {})).duplicate(true)
	var meaningful := false
	for k in params:
		if k != "terminal_id" and k != "challenge_id" and str(params[k]).strip_edges() != "":
			meaningful = true
	if not meaningful:
		_tool_local_error(_t("UI_TOOL_NEED_INPUT"))
		return
	if not params.has("terminal_id"):
		params["terminal_id"] = active_term
	_tool_exec(tool, params)


func _tools_reset() -> void:
	tool_selected = ""
	tool_ids_sig = ""
	tool_observation_sig = ""
	tool_drafts.clear()
	tool_inputs = {}
	_clear_children(tool_input_box)
	_clear_children(tool_obs_box)
	tool_adv_edit.text = ""


# ── 파일 보기 (선택한 터미널 세션의 cwd) ─────────────────────────

var fs_selected_path := ""


func _build_files() -> Control:
	var col := VBoxContainer.new()
	var bar := HBoxContainer.new()
	bar.add_child(_klabel("UI_FS_SESSION", C_DIM, -3))
	fs_term = OptionButton.new()
	for t in TERMS:
		fs_term.add_item(str(t + 1))
	fs_term.item_selected.connect(_on_fs_term_selected)
	_size(fs_term, -2)
	bar.add_child(fs_term)
	fs_path = _label("", C_TEAL, -2)
	fs_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_path.clip_text = true
	fs_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(fs_path)
	bar.add_child(_small(_btn("UI_FS_UP", "UI_FS_UP_TIP", _fs_up)))
	bar.add_child(_small(_btn("UI_FS_OPEN", "UI_FS_OPEN_TIP", _fs_open_selected)))
	col.add_child(bar)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fs_list = ItemList.new()
	fs_list.custom_minimum_size = Vector2(240, 0)
	fs_list.item_activated.connect(_fs_open)
	fs_list.item_selected.connect(_on_fs_selected)
	_size(fs_list, -2)
	split.add_child(fs_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_title = _label("", C_DIM, -2)
	fs_title.clip_text = true
	fs_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(fs_title)
	fs_out = _plain_text()
	right.add_child(fs_out)
	split.add_child(right)
	col.add_child(split)
	col.add_child(_klabel("UI_FS_NOTE", C_FAINT, -4, true))
	return col


func _on_fs_term_selected(i: int) -> void:
	files_term = clampi(i, 0, TERMS - 1)
	term_live[files_term] = true
	fs_selected_path = ""
	_refresh_all()


func _on_fs_selected(i: int) -> void:
	fs_selected_path = _s(_d(fs_list.get_item_metadata(i)), "path")


func _refresh_files() -> void:
	if fs_list == null:
		return
	files_term = clampi(files_term, 0, TERMS - 1)
	fs_term.select(files_term)
	var v: Dictionary = term_views[files_term]
	if v.is_empty():
		v = last_view
	fs_path.text = _t("UI_FS_PATH", {"user": _s(v, "user"), "host": _s(v, "host"), "cwd": _s(v, "cwd")})
	fs_path.tooltip_text = fs_path.text
	fs_list.clear()
	for f in _a(v, "files"):
		var d := _d(f)
		var is_dir := _s(d, "kind") == "dir"
		var i := fs_list.add_item(("▸ %s/" if is_dir else "· %s") % _s(d, "name"))
		fs_list.set_item_metadata(i, d)
		fs_list.set_item_tooltip(i, _t("UI_FS_ENTRY_TIP", {"path": _s(d, "path"), "owner": _s(d, "owner", "—"), "mode": _s(d, "mode", "—")}))
		if is_dir:
			fs_list.set_item_custom_fg_color(i, C_TEAL_DIM)
		if _s(d, "path") == fs_selected_path:
			fs_list.select(i)
	if fs_list.item_count == 0:
		var i := fs_list.add_item(_t("UI_FS_EMPTY"))
		fs_list.set_item_disabled(i, true)
		fs_list.set_item_metadata(i, {})


func _fs_quote(path: String) -> String:
	return ("\"%s\"" % path) if " " in path else path


func _fs_up() -> void:
	_run_command(files_term, "cd ..", _t("UI_FS_TAG"))


func _fs_open_selected() -> void:
	var s := fs_list.get_selected_items()
	if not s.is_empty():
		_fs_open(s[0])


func _fs_open(i: int) -> void:
	var d := _d(fs_list.get_item_metadata(i))
	var path := _s(d, "path")
	if path.is_empty() or not _can_act():
		return
	if _s(d, "kind") == "dir":
		fs_selected_path = ""
		_run_command(files_term, "cd " + _fs_quote(path), _t("UI_FS_TAG"))
		return
	var r := _run_command(files_term, "cat " + _fs_quote(path), _t("UI_FS_TAG"))
	fs_title.text = path
	fs_title.add_theme_color_override("font_color", C_DIM if _b(r, "ok") else C_AMBER)
	_set_plain(fs_out, _s(r, "text"))


# ── 보관 자료 (코어 기록이 권위. 핀·비교·메모는 화면 보조) ─────────

func _build_archive() -> Control:
	var split := HSplitContainer.new()
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	left.add_child(_section("UI_AR_LIST"))
	ar_list = ItemList.new()
	ar_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ar_list.item_selected.connect(_on_ar_selected)
	_size(ar_list, -2)
	left.add_child(ar_list)
	ar_pin_btn = _btn("UI_AR_PIN", "UI_AR_PIN_TIP", _ar_pin)
	_size(ar_pin_btn, -3)
	left.add_child(ar_pin_btn)
	ar_compare_toggle = CheckButton.new()
	_reg(ar_compare_toggle, "text", "UI_AR_COMPARE")
	_reg(ar_compare_toggle, "tooltip_text", "UI_AR_COMPARE_TIP")
	ar_compare_toggle.toggled.connect(_on_ar_compare_toggled)
	_size(ar_compare_toggle, -3)
	left.add_child(ar_compare_toggle)
	split.add_child(left)
	var right := VSplitContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view := VBoxContainer.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ar_meta = _label("", C_DIM, -2, true)
	view.add_child(ar_meta)
	var panes := HSplitContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ar_body = _plain_text()
	panes.add_child(ar_body)
	ar_compare_box = VBoxContainer.new()
	ar_compare_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar_compare_box.visible = false
	ar_compare_meta = _label("", C_TEAL_DIM, -3, true)
	ar_compare_box.add_child(ar_compare_meta)
	ar_compare_body = _plain_text()
	ar_compare_box.add_child(ar_compare_body)
	panes.add_child(ar_compare_box)
	view.add_child(panes)
	right.add_child(view)
	var notes := VBoxContainer.new()
	notes.add_child(_klabel("UI_AR_NOTES", C_TEAL_DIM, -3))
	ar_notes = _text_edit("UI_AR_NOTES_PLACEHOLDER", 70)
	notes.add_child(ar_notes)
	notes.add_child(_klabel("UI_AR_NOTES_NOTE", C_FAINT, -4, true))
	right.add_child(notes)
	split.add_child(right)
	return split


func _archive_item(path: String) -> Dictionary:
	for a in _a(last_view, "archive"):
		var d := _d(a)
		if _s(d, "path") == path:
			return d
	return {}


func _refresh_archive(v: Dictionary) -> void:
	ar_list.clear()
	var sel := -1
	for a in _a(v, "archive"):
		var d := _d(a)
		var path := _s(d, "path")
		var i := ar_list.add_item(("◆ " if path == ar_pinned else "") + _s(d, "name", path))
		ar_list.set_item_metadata(i, d)
		ar_list.set_item_tooltip(i, _t("UI_AR_ITEM_TIP", {"record": _s(d, "record_id", "—"), "source": _s(d, "source", "—")}))
		if path == ar_selected:
			sel = i
	if not ar_pinned.is_empty() and _archive_item(ar_pinned).is_empty():
		ar_pinned = ""
	ar_pin_btn.disabled = ar_list.item_count == 0
	if ar_list.item_count == 0:
		ar_selected = ""
		ar_shown_key = ""
		ar_meta.text = _t("UI_AR_EMPTY_META")
		_set_plain(ar_body, _t("UI_AR_EMPTY_BODY"))
		_ar_update_compare()
		return
	if sel < 0:
		sel = ar_list.item_count - 1
		ar_selected = _s(_d(ar_list.get_item_metadata(sel)), "path")
	ar_list.select(sel)
	_ar_show(_d(ar_list.get_item_metadata(sel)))
	_ar_update_compare()


func _on_ar_selected(i: int) -> void:
	var d := _d(ar_list.get_item_metadata(i))
	ar_selected = _s(d, "path")
	_ar_show(d)


func _ar_meta_text(d: Dictionary) -> String:
	return _t("UI_AR_META", {"path": _s(d, "path"), "source": _s(d, "source", "—"), "record": _s(d, "record_id", "—")})


func _ar_show(d: Dictionary) -> void:
	var key := _s(d, "path") + "\n" + _s(d, "content") + "\n" + Localization.get_locale()
	if key == ar_shown_key:
		return
	ar_shown_key = key
	ar_meta.text = _ar_meta_text(d)
	_set_plain(ar_body, _s(d, "content"))


func _ar_pin() -> void:
	if ar_selected.is_empty():
		return
	ar_pinned = "" if ar_pinned == ar_selected else ar_selected
	_refresh_archive(last_view)


func _on_ar_compare_toggled(_on: bool) -> void:
	_ar_update_compare()


func _ar_update_compare() -> void:
	var on := ar_compare_toggle.button_pressed
	ar_compare_box.visible = on
	if not on:
		return
	var pinned := _archive_item(ar_pinned)
	if pinned.is_empty():
		ar_compare_meta.text = _t("UI_AR_COMPARE_NONE")
		ar_compare_body.clear()
		return
	ar_compare_meta.text = _t("UI_AR_COMPARE_PINNED", {"meta": _ar_meta_text(pinned)})
	_set_plain(ar_compare_body, _s(pinned, "content"))


# ── 사건 보드 (24 메인 + 4 선택) ──────────────────────────────

func _build_board() -> Control:
	var split := HSplitContainer.new()
	bd_tree = Tree.new()
	bd_tree.custom_minimum_size = Vector2(290, 0)
	bd_tree.hide_root = true
	bd_tree.select_mode = Tree.SELECT_ROW
	bd_tree.item_selected.connect(_on_bd_selected)
	bd_tree.item_activated.connect(_on_bd_activated)
	_size(bd_tree, -2)
	split.add_child(bd_tree)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	bd_title = _label("", C_TEXT, 3, true)
	bd_state = _label("", C_DIM, -2, true)
	bd_goal = _label("", C_TEXT, -1, true)
	bd_obj_head = _section("UI_BD_OBJECTIVES")
	bd_objectives = VBoxContainer.new()
	bd_objectives.add_theme_constant_override("separation", 3)
	bd_stage_head = _section("UI_BD_STAGES")
	bd_milestones = VBoxContainer.new()
	bd_milestones.add_theme_constant_override("separation", 4)
	for c in [bd_title, bd_state, bd_goal, bd_obj_head, bd_objectives, bd_stage_head, bd_milestones]:
		detail.add_child(c)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	bd_switch_btn = _btn("UI_BD_SWITCH", "UI_BD_SWITCH_TIP", _bd_switch)
	bd_next_btn = _btn("UI_BD_NEXT", "UI_BD_NEXT_TIP", _bd_next)
	bd_next_btn.add_theme_color_override("font_color", C_TEAL)
	bd_ending_btn = _btn("UI_BD_ENDING", "UI_BD_ENDING_TIP", _open_app.bind("ending", true))
	bd_ending_btn.add_theme_color_override("font_color", C_AMBER)
	for b in [bd_switch_btn, bd_next_btn, bd_ending_btn]:
		_size(b, -2)
		actions.add_child(b)
	detail.add_child(actions)
	detail.add_child(_section("UI_BD_HINTS"))
	detail.add_child(_klabel("UI_BD_HINTS_NOTE", C_FAINT, -4, true))
	var hrow := HFlowContainer.new()
	hrow.add_theme_constant_override("h_separation", 6)
	for n in 3:
		var hb := _btn_raw("", "UI_BD_HINT_TIP", _bd_hint.bind(n))
		_reg(hb, "text", "UI_BD_HINT_N", {"n": n + 1})
		_size(hb, -3)
		bd_hint_buttons.append(hb)
		hrow.add_child(hb)
	bd_hint_hide = _btn_raw("", "", _bd_hint_toggle)
	_size(bd_hint_hide, -3)
	hrow.add_child(bd_hint_hide)
	detail.add_child(hrow)
	bd_hint_text = _label("", C_AMBER, -2, true)
	bd_hint_text.visible = false
	detail.add_child(bd_hint_text)
	detail.add_child(_section("UI_BD_CHAPTERS"))
	bd_chapters = _label("", C_DIM, -3, true)
	detail.add_child(bd_chapters)
	split.add_child(_scroll_wrap(detail))
	return split


func _mission_dict(id: String) -> Dictionary:
	for m in _a(last_view, "missions"):
		var d := _d(m)
		if _s(d, "id") == id:
			return d
	return {}


func _main_complete(v: Dictionary) -> bool:
	var any := false
	for m in _a(v, "missions"):
		var d := _d(m)
		if _b(d, "optional"):
			continue
		any = true
		if not _b(d, "completed"):
			return false
	return any


func _bd_item_text(d: Dictionary, current: String) -> String:
	var id := _s(d, "id")
	var done := _b(d, "completed")
	var open := _b(d, "available")
	var mark := "● " if id == current else ("✓ " if done else ("○ " if open else "· "))
	if done or open:
		return mark + _t("UI_BD_ITEM", {"id": id, "title": _s(d, "title")})
	# 잠긴 사건의 제목은 미리 보여 주지 않는다.
	return mark + _t("UI_BD_ITEM_LOCKED", {"id": id})


func _refresh_board(v: Dictionary) -> void:
	var missions := _a(v, "missions")
	var current := _s(v, "mission_id")
	if bd_selected.is_empty() or _mission_dict(bd_selected).is_empty():
		bd_selected = current
	var counts := {}
	var opt_done := 0
	var opt_total := 0
	for m in missions:
		var d := _d(m)
		if _b(d, "optional"):
			opt_total += 1
			opt_done += 1 if _b(d, "completed") else 0
			continue
		var ch := _i(d, "chapter", 0)
		if not counts.has(ch):
			counts[ch] = [0, 0]
		counts[ch][1] += 1
		if _b(d, "completed"):
			counts[ch][0] += 1
	bd_tree.clear()
	var root := bd_tree.create_item()
	var chapter_items := {}
	var optional_item: TreeItem = null
	var selected_item: TreeItem = null
	for m in missions:
		var d := _d(m)
		var parent: TreeItem
		if _b(d, "optional"):
			if optional_item == null:
				optional_item = bd_tree.create_item(root)
				optional_item.set_text(0, _t("UI_BD_OPTIONAL_GROUP", {"done": opt_done, "total": opt_total}))
				optional_item.set_selectable(0, false)
				optional_item.set_custom_color(0, C_TEAL_DIM)
			parent = optional_item
		else:
			var ch := _i(d, "chapter", 0)
			if not chapter_items.has(ch):
				var ci := bd_tree.create_item(root)
				ci.set_text(0, _t("UI_BD_CHAPTER_PROGRESS", {"n": ch, "done": counts[ch][0], "total": counts[ch][1]}))
				ci.set_selectable(0, false)
				ci.set_custom_color(0, C_TEAL_DIM)
				chapter_items[ch] = ci
			parent = chapter_items[ch]
		var it := bd_tree.create_item(parent)
		var id := _s(d, "id")
		it.set_text(0, _bd_item_text(d, current))
		it.set_metadata(0, id)
		var col := C_FAINT
		if id == current:
			col = C_TEAL
		elif _b(d, "completed"):
			col = C_DIM
		elif _b(d, "available"):
			col = C_TEXT
		it.set_custom_color(0, col)
		if id == bd_selected:
			selected_item = it
	if selected_item != null:
		selected_item.select(0)
		bd_tree.scroll_to_item(selected_item)
	var parts: Array = []
	var chs: Array = counts.keys()
	chs.sort()
	for ch in chs:
		parts.append(_t("UI_BD_CHAPTER_PROGRESS", {"n": ch, "done": counts[ch][0], "total": counts[ch][1]}))
	if opt_total > 0:
		parts.append(_t("UI_BD_OPTIONAL_GROUP", {"done": opt_done, "total": opt_total}))
	bd_chapters.text = "\n".join(PackedStringArray(parts))
	_bd_show(_mission_dict(bd_selected))


func _on_bd_selected() -> void:
	var it := bd_tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	bd_selected = str(it.get_metadata(0))
	_bd_show(_mission_dict(bd_selected))


func _on_bd_activated() -> void:
	var d := _mission_dict(bd_selected)
	if not d.is_empty() and _b(d, "available") and bd_selected != _s(last_view, "mission_id"):
		_bd_switch()


func _bd_show(d: Dictionary) -> void:
	var v := last_view
	var id := _s(d, "id")
	var current := _s(v, "mission_id")
	var done := _b(d, "completed")
	var open := _b(d, "available")
	var is_current := id == current and not id.is_empty()
	if d.is_empty():
		bd_title.text = ""
		bd_state.text = ""
		bd_goal.text = ""
	else:
		bd_title.text = _t("UI_BD_ITEM", {"id": id, "title": _s(d, "title")}) if (done or open) else _t("UI_BD_ITEM_LOCKED", {"id": id})
		var tags: Array = []
		if _b(d, "optional"):
			tags.append(_t("UI_BD_TAG_OPTIONAL"))
		else:
			tags.append(_t("UI_BD_CHAPTER", {"n": _i(d, "chapter", 0)}))
		if is_current:
			tags.append(_t("UI_BD_STATE_CURRENT"))
		if done:
			tags.append(_t("UI_BD_STATE_DONE"))
			if is_current and not _b(v, "completed"):
				tags.append(_t("UI_BD_STATE_RECHECK"))
		elif open:
			tags.append(_t("UI_BD_STATE_AVAILABLE"))
		else:
			tags.append(_t("UI_BD_STATE_LOCKED"))
		bd_state.text = " · ".join(PackedStringArray(tags))
	_clear_children(bd_objectives)
	_clear_children(bd_milestones)
	if is_current:
		var goal := _s(v, "mission_goal")
		bd_goal.text = _t("UI_BD_GOAL", {"text": goal}) if not goal.is_empty() else ""
		bd_goal.visible = not goal.is_empty()
		var objs := _a(v, "objectives")
		for o in objs:
			var od := _d(o)
			var ok := _b(od, "completed")
			var row := _label(_t("UI_OBJ_ROW", {"mark": "✓" if ok else "○", "text": _obj_text(od),
					"state": _t("UI_OBJ_DONE") if ok else _t("UI_OBJ_PENDING")}), C_TEAL if ok else C_TEXT, -2, true)
			bd_objectives.add_child(row)
		if objs.is_empty():
			bd_objectives.add_child(_label(_t("UI_BD_NO_OBJECTIVES"), C_FAINT, -3, true))
		for ms in _a(v, "milestones"):
			var md := _d(ms)
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 1)
			box.add_child(_label(_s(md, "title"), C_TEAL_DIM, -3, true))
			box.add_child(_label(_s(md, "text"), C_DIM, -3, true))
			bd_milestones.add_child(box)
		bd_obj_head.visible = true
		bd_stage_head.visible = bd_milestones.get_child_count() > 0
	else:
		bd_goal.visible = not d.is_empty()
		bd_goal.text = _t("UI_BD_OTHER_DONE") if done else (_t("UI_BD_OTHER_AVAILABLE") if open else _t("UI_BD_OTHER_LOCKED"))
		bd_obj_head.visible = false
		bd_stage_head.visible = false
	bd_switch_btn.visible = not is_current and not d.is_empty()
	bd_switch_btn.disabled = not open
	bd_next_btn.visible = is_current
	bd_next_btn.disabled = not _b(v, "can_advance")
	bd_ending_btn.visible = _main_complete(v)
	_bd_update_hints(is_current)


func _obj_text(o: Dictionary) -> String:
	var kind := _s(o, "kind")
	var display := _s(o, "display_name", _s(o, "id"))
	var target := _s(o, "target_display")
	if not target.is_empty():
		display += " · " + target
	var s := _t_opt("UI_OBJ_" + kind.to_upper(), {"id": display})
	return s if not s.is_empty() else _t("UI_OBJ_OTHER", {"kind": kind, "id": display})


func _bd_update_hints(is_current: bool = true) -> void:
	var hints := _a(last_view, "hints")
	for n in bd_hint_buttons.size():
		var b: Button = bd_hint_buttons[n]
		b.visible = is_current and n < hints.size()
		b.disabled = n > hints_revealed
	bd_hint_hide.visible = is_current and hints_revealed > 0
	bd_hint_hide.text = _t("UI_BD_HINT_HIDE") if bd_hint_text.visible else _t("UI_BD_HINT_SHOW")
	if not is_current:
		bd_hint_text.visible = false
		return
	if hints.is_empty():
		bd_hint_text.text = _t("UI_BD_NO_HINTS")
		return
	var lines: Array = []
	for i in mini(hints_revealed, hints.size()):
		lines.append(_t("UI_BD_HINT_LINE", {"n": i + 1, "text": str(hints[i])}))
	bd_hint_text.text = "\n\n".join(PackedStringArray(lines))


func _bd_hint(n: int) -> void:
	if game == null or paused:
		return
	var hints := _a(last_view, "hints")
	if n >= hints.size() or n > hints_revealed:
		return
	# 안내 표시만 바꾼다. 통과 조건·경보와 무관하다.
	game.get_hint(n)
	hints_revealed = maxi(hints_revealed, n + 1)
	bd_hint_text.visible = true
	_bd_update_hints(true)


func _bd_hint_toggle() -> void:
	bd_hint_text.visible = not bd_hint_text.visible
	_bd_update_hints(true)


func _bd_switch() -> void:
	var id := bd_selected
	if id.is_empty() or id == _s(last_view, "mission_id") or not _can_act():
		return
	var r := _act("board", func(): return game.choose_mission(id))
	if not _b(r, "ok"):
		_toast(_t("UI_NOTE_ACTION_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)


func _bd_next() -> void:
	if not _can_act():
		return
	var r := _act("board", func(): return game.advance())
	var code := _s(r, "code")
	if code == "CAMPAIGN_COMPLETE":
		_toast(_t("UI_NOTE_MAIN_COMPLETE"), C_TEAL)
		_open_app("ending", true)
	elif not _b(r, "ok"):
		_toast(_t("UI_NOTE_ACTION_FAILED", {"code": code, "detail": _s(r, "text")}), C_AMBER)


# ── 상태·네트워크 ─────────────────────────────────────────────

func _build_status() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	st_mission = _label("", C_TEXT, 1, true)
	st_alert = _label("", C_DIM, -1)
	st_alert_explain = _label("", C_DIM, -3, true)
	for c in [st_mission, st_alert, st_alert_explain]:
		col.add_child(c)
	col.add_child(_section("UI_ST_SESSIONS"))
	st_sessions = _label("", C_TEXT, -3, true, true)
	col.add_child(st_sessions)
	col.add_child(_section("UI_ST_POLICIES"))
	st_policies = _label("", C_DIM, -3, true)
	col.add_child(st_policies)
	st_facts = _label("", C_DIM, -3, true)
	col.add_child(st_facts)
	col.add_child(_section("UI_ST_NETWORK"))
	net_map = NetMap.new()
	net_map.custom_minimum_size = Vector2(0, 220)
	net_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(net_map)
	col.add_child(_klabel("UI_ST_NETWORK_NOTE", C_FAINT, -4, true))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	for spec in [["UI_OPEN_SETTINGS", "UI_OPEN_SETTINGS_TIP", _open_settings], ["UI_ROOM", "UI_ROOM_TIP", _request_room],
			["UI_ARRANGE", "UI_ARRANGE_TIP", _arrange], ["UI_PAUSE", "UI_PAUSE_TIP", _toggle_pause]]:
		actions.add_child(_small(_btn(spec[0], spec[1], spec[2])))
	col.add_child(actions)
	return _scroll_wrap(col)


func _alert_text(v: Dictionary) -> String:
	var al := _i(v, "alert_level")
	var mx := maxi(_i(v, "alert_max", 3), 1)
	return _t("UI_ALERT_METER", {"bar": "■".repeat(mini(al, mx)) + "□".repeat(maxi(mx - al, 0)), "level": al, "max": mx})


func _refresh_status(v: Dictionary) -> void:
	var done := _b(v, "completed")
	st_mission.text = _t("UI_ST_MISSION", {"id": _s(v, "mission_id"), "title": _s(v, "mission_title"),
			"state": _t("UI_ST_DONE") if done else _t("UI_ST_ACTIVE")})
	var al := _i(v, "alert_level")
	var mx := maxi(_i(v, "alert_max", 3), 1)
	st_alert.text = _alert_text(v)
	st_alert.add_theme_color_override("font_color", C_AMBER if al > 0 else C_DIM)
	st_alert_explain.text = _t("UI_ALERT_EXPLAIN_MAX") if al >= mx else _t("UI_ALERT_EXPLAIN_%d" % clampi(al, 0, 2))
	var lines: Array = []
	var links := {}
	for t in TERMS:
		var tv: Dictionary = term_views[t]
		if tv.is_empty() or (not bool(term_live[t]) and _s(tv, "host", "local") == "local"):
			continue
		var key := "UI_ST_SESSION_LINE_AUTH" if _b(tv, "password_pending") else "UI_ST_SESSION_LINE"
		lines.append(_t(key, {"n": t + 1, "user": _s(tv, "user"), "host": _s(tv, "host"), "cwd": _s(tv, "cwd")}))
		var host := _s(tv, "host")
		if not links.has(host):
			links[host] = []
		links[host].append(str(t + 1))
	st_sessions.text = "\n".join(PackedStringArray(lines))
	st_policies.text = _policy_list(_d(v.get("policies", {})))
	st_facts.text = _t("UI_ST_FACTS", {"n": _a(v, "facts").size()})
	net_map.nodes = _a(v, "network")
	net_map.links = links
	net_map.local_label = _t("UI_NET_LOCAL")
	net_map.empty_label = _t("UI_NET_EMPTY")
	net_map.known_label = _t("UI_NET_KNOWN")
	net_map.connected_fmt = _t("UI_NET_CONNECTED")
	net_map.queue_redraw()


# ── 도움말 ────────────────────────────────────────────────────

var hp_guide: RichTextLabel
var hp_sig := ""


func _build_help() -> Control:
	var col := VBoxContainer.new()
	hp_goal = _label("", C_TEAL, -2, true)
	col.add_child(hp_goal)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.add_child(_small(_btn("UI_HELP_RUN_HELP", "UI_HELP_RUN_HELP_TIP", _help_in_terminal)))
	row.add_child(_small(_btn("UI_HELP_OPEN_HINTS", "UI_HELP_OPEN_HINTS_TIP", _open_app.bind("board", true))))
	row.add_child(_small(_btn("UI_ARRANGE", "UI_ARRANGE_TIP", _arrange)))
	col.add_child(row)
	hp_guide = _plain_text()
	col.add_child(hp_guide)
	return col


func _help_in_terminal() -> void:
	_open_terminal(active_term)
	_run_command(active_term, "help", _t("UI_HELP_TAG"))


func _refresh_help(v: Dictionary) -> void:
	var goal := _s(v, "mission_goal")
	hp_goal.text = _t("UI_HELP_GOAL", {"text": goal}) if not goal.is_empty() else ""
	var sig := Localization.get_locale()
	if sig != hp_sig:
		hp_sig = sig
		_set_plain(hp_guide, _t("UI_HELP_BODY"))


# ── 결말 ──────────────────────────────────────────────────────

func _build_ending() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(_klabel("UI_ENDING_HEADER", C_TEAL, 5, true))
	en_intro = _label("", C_DIM, -1, true)
	col.add_child(en_intro)
	en_choices = VBoxContainer.new()
	en_choices.add_theme_constant_override("separation", 6)
	col.add_child(en_choices)
	col.add_child(HSeparator.new())
	en_chosen_title = _label("", C_TEXT, 4, true)
	en_chosen_text = _label("", C_TEXT, 0, true)
	en_credits = _label("", C_FAINT, -3, true)
	for c in [en_chosen_title, en_chosen_text, en_credits]:
		col.add_child(c)
	col.add_child(_small(_btn("UI_ENDING_TO_BOARD", "", _open_app.bind("board", true))))
	return _scroll_wrap(col)


func _refresh_ending(v: Dictionary) -> void:
	if en_choices == null:
		return
	var main_done := _main_complete(v)
	var chosen := _d(v.get("ending", {}))
	var sig := JSON.stringify([v.get("endings", []), chosen, main_done, Localization.get_locale()])
	if sig == en_sig:
		return
	en_sig = sig
	_clear_children(en_choices)
	if not main_done:
		var done := 0
		var total := 0
		for m in _a(v, "missions"):
			var d := _d(m)
			if not _b(d, "optional"):
				total += 1
				done += 1 if _b(d, "completed") else 0
		en_intro.text = _t("UI_ENDING_NOT_YET", {"done": done, "total": total})
	else:
		en_intro.text = _t("UI_ENDING_INTRO")
		for e in _a(v, "endings"):
			var d := _d(e)
			if _b(d, "available"):
				var title := _s(d, "title")
				var mark := "✓ " if _s(d, "id") == _s(chosen, "id") else ""
				var b := _btn_raw(mark + _t("UI_ENDING_CHOICE", {"title": title}), "UI_ENDING_CHOICE_TIP", _ask_ending.bind(_s(d, "id"), title))
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				en_choices.add_child(b)
			else:
				# 근거가 부족한 결말은 제목·본문을 드러내지 않는다.
				en_choices.add_child(_label(_t("UI_ENDING_LOCKED"), C_FAINT, -2, true))
	var has := not chosen.is_empty()
	en_chosen_title.visible = has
	en_chosen_text.visible = has
	en_credits.visible = has
	if has:
		en_chosen_title.text = _s(chosen, "title")
		en_chosen_text.text = _s(chosen, "text")
		var credits := _t_opt("CREDITS_BODY")
		en_credits.text = _t("UI_ENDING_CREDITS", {"credits": credits}) if not credits.is_empty() else _t("UI_ENDING_THANKS")


func _ask_ending(id: String, title: String) -> void:
	if not _can_act():
		return
	_ask(_t("UI_ENDING_CONFIRM", {"title": title}), _choose_ending.bind(id))


func _choose_ending(id: String) -> void:
	var r := _act("ending", func(): return game.choose_ending(id))
	if not _b(r, "ok"):
		_toast(_t("UI_NOTE_ACTION_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)
		return
	en_sig = ""
	_refresh_ending(last_view)
	_open_app("ending", true)
	campaign_finished.emit(_d(last_view.get("ending", {})).duplicate(true))


# ── 코어 행동·갱신 ────────────────────────────────────────────

## 모든 코어 요청의 단일 경로: 호출 → 읽기 모델 갱신 → 변화 알림 → 자동저장 → 신호.
func _act(app: String, action: Callable, t: int = -1) -> Dictionary:
	if not _can_act():
		return {"ok": false, "code": "UI_BLOCKED", "text": _t("UI_ERR_BLOCKED"), "changed": false}
	var before: Dictionary = last_view
	var before_t: Dictionary = term_views[t] if t >= 0 else {}
	var sig_before := _state_sig()
	var raw = action.call()
	var r: Dictionary = raw if raw is Dictionary else {"ok": false, "code": "UI_BAD_RESULT", "text": _t("UI_ERR_BAD_RESULT"), "changed": false}
	_refresh_all()
	var changed := _b(r, "changed") or _state_sig() != sig_before
	if changed and app != "browser" and not br_url.is_empty():
		br_stale.visible = true
	_after_action(before, r, t, before_t)
	if changed:
		_autosave()
	var emitted: Dictionary = r.duplicate(true)
	emitted["ui_app"] = app
	action_performed.emit(emitted)
	return r


func _state_sig() -> String:
	var v := last_view
	var sessions: Array = []
	for t in TERMS:
		var tv: Dictionary = term_views[t]
		sessions.append([_s(tv, "host"), _s(tv, "user"), _s(tv, "cwd")])
	return JSON.stringify([_s(v, "mission_id"), _b(v, "completed"), _i(v, "alert_level"), _a(v, "archive").size(),
			_a(v, "facts"), v.get("policies", {}), _a(v, "terminals"), sessions, v.get("ending", {})])


func _refresh_all() -> void:
	if game == null:
		return
	# get_view(0..3)는 코어 계약상 세계·현재 주체를 바꾸지 않는 읽기다.
	term_live[active_term] = true
	for t in TERMS:
		term_views[t] = _view(t)
	var v: Dictionary = term_views[active_term]
	if v.is_empty() or not _b(v, "ready", false):
		_show_fatal(_s(v, "error", _t("UI_ERR_NO_VIEW")))
		return
	var mission := _s(v, "mission_id")
	var mission_changed := not last_mission.is_empty() and mission != last_mission
	last_mission = mission
	last_view = v
	if mission_changed:
		_on_mission_changed(v)
	_refresh_top(v)
	for t in TERMS:
		if term_live[t]:
			_refresh_terminal(t)
	_refresh_mail(v)
	_refresh_tools(v)
	_refresh_files()
	_refresh_archive(v)
	_refresh_board(v)
	_refresh_status(v)
	_refresh_help(v)
	_refresh_ending(v)
	_update_taskbar()
	view_changed.emit(v.duplicate(true))


func _refresh_top(v: Dictionary) -> void:
	top_mission.text = _t("UI_TOP_MISSION", {"id": _s(v, "mission_id"), "title": _s(v, "mission_title")})
	top_mission.tooltip_text = _s(v, "mission_goal")
	var objs := _a(v, "objectives")
	var done := 0
	for o in objs:
		done += 1 if _b(_d(o), "completed") else 0
	if _b(v, "completed"):
		top_progress.text = _t("UI_TOP_CASE_DONE")
		top_progress.add_theme_color_override("font_color", C_TEAL)
	elif _b(v, "completion_recorded"):
		# 과거 완료 기록은 있지만 재방문 중 현재 상태가 목표를 다시 충족하지 않는다.
		top_progress.text = _t("UI_TOP_RECORDED", {"done": done, "total": objs.size()})
		top_progress.add_theme_color_override("font_color", C_AMBER)
	elif not objs.is_empty():
		top_progress.text = _t("UI_TOP_OBJECTIVES", {"done": done, "total": objs.size()})
		top_progress.add_theme_color_override("font_color", C_DIM)
	else:
		top_progress.text = ""
	var al := _i(v, "alert_level")
	top_alert.text = _alert_text(v)
	top_alert.add_theme_color_override("font_color", C_AMBER if al > 0 else C_DIM)
	var tv: Dictionary = term_views[active_term] if not term_views[active_term].is_empty() else v
	top_host.text = _t("UI_TOP_SESSION", {"n": active_term + 1, "user": _s(tv, "user"), "host": _s(tv, "host")})
	top_host.tooltip_text = top_host.text
	_refresh_save_mode()


func _after_action(before: Dictionary, r: Dictionary, t: int, before_t: Dictionary) -> void:
	var v := last_view
	var notes: Array = []
	var color := C_TEXT
	if not before.is_empty() and _s(before, "mission_id") == _s(v, "mission_id"):
		var b_keys := {}
		for m in _a(before, "messages"):
			b_keys[_mail_key(before, _d(m))] = true
		var new_mail := false
		for m in _a(v, "messages"):
			if not b_keys.has(_mail_key(v, _d(m))):
				new_mail = true
		if not _b(before, "completed") and _b(v, "completed"):
			notes.append(_t("UI_NOTE_CASE_COMPLETE", {"title": _s(v, "mission_title")}))
			if new_mail:
				notes.append(_t("UI_NOTE_NEW_MAIL"))
			color = C_TEAL
		elif new_mail:
			notes.append(_t("UI_NOTE_NEW_MAIL"))
		var arc := _a(v, "archive")
		if arc.size() > _a(before, "archive").size():
			notes.append(_t("UI_NOTE_ARCHIVED", {"name": _s(_d(arc.back()), "name")}))
			if color == C_TEXT:
				color = C_TEAL
			_pulse(task_buttons["archive"], C_TEAL)
		var b_done := 0
		var a_done := 0
		for o in _a(before, "objectives"):
			b_done += 1 if _b(_d(o), "completed") else 0
		var objs := _a(v, "objectives")
		for o in objs:
			a_done += 1 if _b(_d(o), "completed") else 0
		if a_done > b_done and not _b(v, "completed"):
			notes.append(_t("UI_NOTE_OBJECTIVE", {"done": a_done, "total": objs.size()}))
			if color == C_TEXT:
				color = C_TEAL
		var al := _i(v, "alert_level")
		var mx := maxi(_i(v, "alert_max", 3), 1)
		if al > _i(before, "alert_level"):
			notes.append(_t("UI_NOTE_ALERT", {"level": al, "max": mx}))
			if al >= mx:
				notes.append(_t("UI_NOTE_ALERT_MAX"))
			if color == C_TEXT:
				color = C_AMBER
			_pulse(top_alert, C_AMBER)
		if _b(v, "can_advance") and not _b(before, "can_advance"):
			notes.append(_t("UI_NOTE_NEXT_READY"))
	if t >= 0 and not before_t.is_empty() and _b(r, "ok"):
		var after_t: Dictionary = term_views[t]
		if _s(after_t, "host") != _s(before_t, "host") or _s(after_t, "user") != _s(before_t, "user"):
			if _s(after_t, "host") == "local":
				notes.append(_t("UI_NOTE_LOCAL", {"n": t + 1, "user": _s(after_t, "user")}))
			else:
				notes.append(_t("UI_NOTE_ACCESS", {"n": t + 1, "user": _s(after_t, "user"), "host": _s(after_t, "host")}))
				if color == C_TEXT:
					color = C_TEAL
			_pulse(terms[t]["header"], C_TEAL)
			_pulse(terms[t]["prompt"], C_TEAL)
	if not notes.is_empty():
		_toast("\n".join(PackedStringArray(notes)), color)


func _on_mission_changed(v: Dictionary) -> void:
	# 사건별 화면 캐시만 비운다. 코어의 사건 상태·보관 자료는 코어가 보존한다.
	_br_reset()
	_tools_reset()
	hints_revealed = 0
	bd_hint_text.visible = false
	bd_selected = _s(v, "mission_id")
	mail_selected = ""
	mail_shown_key = ""
	fs_selected_path = ""
	ar_selected = ""
	ar_shown_key = ""
	ar_pinned = ""
	for t in TERMS:
		if term_live[t]:
			_term_line(t, _t("UI_TERM_CASE_BANNER", {"id": _s(v, "mission_id"), "title": _s(v, "mission_title")}), C_FAINT)
	_toast(_t("UI_NOTE_MISSION", {"id": _s(v, "mission_id"), "title": _s(v, "mission_title")}), C_TEAL)
	call_deferred("_br_open_home")


func _br_open_home() -> void:
	if wins.has("browser") and wins["browser"]["state"] != "closed" and _can_act():
		br_opened = true
		_br_home()
	else:
		br_opened = false


func _reset_world_caches() -> void:
	_br_reset()
	_tools_reset()
	hints_revealed = 0
	bd_hint_text.visible = false
	bd_selected = ""
	mail_read.clear()
	mail_selected = ""
	mail_shown_key = ""
	face_disclosed.clear()
	mail_contacts_sig = ""
	fs_selected_path = ""
	ar_selected = ""
	ar_shown_key = ""
	ar_pinned = ""
	en_sig = ""
	last_mission = ""
	last_view = {}
	for t in TERMS:
		term_views[t] = {}


# ── 세션 수명·저장 ────────────────────────────────────────────

func _install_game(candidate, banner_key: String) -> void:
	game = candidate
	session_active = true
	_hide_fatal()
	_reset_world_caches()
	# 저장에서 원격 연결이 남아 있는 터미널은 사용 중인 세션으로 표시한다.
	for t in TERMS:
		if not bool(term_live[t]) and _s(_view(t), "host", "local") != "local":
			term_live[t] = true
	for t in TERMS:
		if term_live[t]:
			_term_line(t, _t(banner_key), C_FAINT)
	_refresh_all()
	_ensure_default_windows()
	call_deferred("_br_open_home")


func _ensure_default_windows() -> void:
	for id in wins:
		if wins[id]["state"] == "open":
			return
	_open_app("mail", false)
	_open_app("board", false)
	_open_terminal(0)


func _resume() -> void:
	_hide_fatal()
	_refresh_all()
	_ensure_default_windows()


func _load_from_disk() -> Dictionary:
	var candidate = game if (session_active and game != null) else CampaignGame.new(save_slot_path)
	if not _game_ready(candidate):
		var err := _s(_d(candidate.get_view()), "error", _t("UI_ERR_NO_VIEW"))
		_show_fatal(err)
		return {"ok": false, "code": "INVALID_CONTENT", "text": err}
	var r := _d(candidate.load_game())
	if _b(r, "ok"):
		autosave_suspended = false
		recovery_overlay.visible = false
		_set_recovery_buttons({})
		_install_game(candidate, "UI_BANNER_LOADED")
		_toast(_t("UI_NOTE_LOADED"), C_TEAL)
		return {"ok": true, "code": "LOADED", "text": ""}
	var code := _s(r, "code")
	if code == "SAVE_NOT_FOUND" and not _b(r, "backup_available"):
		if session_active:
			_toast(_t("UI_LOAD_NOT_FOUND_ACTIVE"), C_AMBER)
			return {"ok": true, "code": code, "text": ""}
		return {"ok": false, "code": code, "text": _t("UI_ERR_NO_SAVE")}
	# 손상·버전 불일치·백업만 남음: 새 상태로 덮어쓰지 않고 자동저장을 멈춘 채 선택지를 보여 준다.
	autosave_suspended = true
	if not session_active:
		_install_game(candidate, "UI_BANNER_UNSAVED")
	_show_recovery(r)
	return {"ok": true, "code": code, "text": ""}


func _begin_new() -> Dictionary:
	var candidate = CampaignGame.new(save_slot_path)
	if not _game_ready(candidate):
		var err := _s(_d(candidate.get_view()), "error", _t("UI_ERR_NO_VIEW"))
		_show_fatal(err)
		return {"ok": false, "code": "INVALID_CONTENT", "text": err}
	# Room이 확인을 받은 뒤다. 정상 기존 v2 슬롯은 Store가 .bak으로 보관한 뒤 교체한다.
	var r := _d(candidate.save_game())
	autosave_suspended = not _b(r, "ok")
	recovery_overlay.visible = false
	_install_game(candidate, "UI_BANNER_NEW")
	if _b(r, "ok"):
		_set_recovery_buttons({})
		_toast(_t("UI_NOTE_NEW_SAVED"), C_TEAL)
	else:
		_show_recovery(r)
	_refresh_save_mode()
	return {"ok": true, "code": "NEW_STARTED", "text": ""}


func _begin_import() -> Dictionary:
	var candidate = CampaignGame.new(save_slot_path)
	if not _game_ready(candidate):
		var err := _s(_d(candidate.get_view()), "error", _t("UI_ERR_NO_VIEW"))
		return {"ok": false, "code": "INVALID_CONTENT", "text": err}
	if not candidate.has_method("import_legacy_save"):
		return {"ok": false, "code": "UI_IMPORT_UNAVAILABLE", "text": _t("UI_IMPORT_UNAVAILABLE")}
	# 고정된 구버전 슬롯만 코어가 읽는다. UI는 파일 경로를 받지 않는다. 실패하면 현재 진행은 그대로다.
	var r := _d(candidate.import_legacy_save())
	if not _b(r, "ok"):
		return {"ok": false, "code": _s(r, "code"), "text": _t("UI_IMPORT_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")})}
	recovery_overlay.visible = false
	_install_game(candidate, "UI_BANNER_IMPORTED")
	var s := _d(candidate.save_game())
	autosave_suspended = not _b(s, "ok")
	if _b(s, "ok"):
		_set_recovery_buttons({})
		_toast(_t("UI_NOTE_IMPORTED_SAVED"), C_TEAL)
	else:
		_show_recovery(s)
	_refresh_save_mode()
	return {"ok": true, "code": "IMPORTED_M01", "text": ""}


func _show_recovery(r: Dictionary) -> void:
	recovery_text.text = _t("UI_RECOVERY_DETAIL", {"code": _s(r, "code", "—"), "detail": _s(r, "text")})
	recovery_recover_btn.visible = _b(r, "backup_available")
	recovery_fresh_btn.visible = true
	recovery_overlay.visible = true
	_set_recovery_buttons(r)
	_refresh_save_mode()
	call_deferred("_focus_recovery")


func _focus_recovery() -> void:
	if not recovery_overlay.visible or not is_visible_in_tree():
		return
	for b in [recovery_recover_btn, recovery_fresh_btn, recovery_continue_btn]:
		if b.visible:
			b.grab_focus()
			return


func _recovery_dismiss() -> void:
	recovery_overlay.visible = false
	_toast(_t("UI_NOTE_UNSAVED_PLAY"), C_AMBER)
	_restore_focus(null)


func _set_recovery_buttons(r: Dictionary) -> void:
	var failing := autosave_suspended and not r.is_empty()
	recover_btn.visible = failing and _b(r, "backup_available")
	fresh_btn.visible = failing
	_refresh_save_mode()


func _refresh_save_mode() -> void:
	if top_save == null:
		return
	top_save.text = _t("UI_AUTOSAVE_OFF") if autosave_suspended else _t("UI_AUTOSAVE_ON")
	top_save.add_theme_color_override("font_color", C_AMBER if autosave_suspended else C_TEAL_DIM)
	top_save.tooltip_text = _t("UI_AUTOSAVE_OFF_TIP") if autosave_suspended else _t("UI_AUTOSAVE_ON_TIP")


func _autosave() -> void:
	if autosave_suspended or not session_active or game == null:
		return
	var r := _d(game.save_game())
	if _b(r, "ok"):
		return
	autosave_suspended = true
	_set_recovery_buttons(r)
	_toast(_t("UI_AUTOSAVE_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)


func _manual_save() -> void:
	if game == null or not session_active or paused:
		return
	var r := _d(game.save_game())
	if _b(r, "ok"):
		autosave_suspended = false
		_set_recovery_buttons({})
		_toast(_t("UI_NOTE_SAVED"), C_TEAL)
	else:
		autosave_suspended = true
		_set_recovery_buttons(r)
		_toast(_t("UI_SAVE_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)
	_refresh_save_mode()


func _ask_load() -> void:
	if session_active and not paused:
		_ask(_t("UI_CONFIRM_LOAD"), _do_load)


func _do_load() -> void:
	var r := start_session("load")
	if not _b(r, "ok"):
		_toast(_s(r, "text"), C_AMBER)


func _ask_recover() -> void:
	if game != null:
		_ask(_t("UI_CONFIRM_RECOVER"), _do_recover)


func _do_recover() -> void:
	var r := _d(game.recover_save())
	if not _b(r, "ok"):
		_toast(_t("UI_RECOVER_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)
		return
	autosave_suspended = false
	recovery_overlay.visible = false
	_set_recovery_buttons({})
	_install_game(game, "UI_BANNER_RECOVERED")
	_toast(_t("UI_NOTE_RECOVERED"), C_TEAL)


func _ask_fresh() -> void:
	if game != null:
		_ask(_t("UI_CONFIRM_FRESH"), _do_fresh)


func _do_fresh() -> void:
	var r := _d(game.start_new_save())
	if not _b(r, "ok"):
		_toast(_t("UI_FRESH_FAILED", {"code": _s(r, "code"), "detail": _s(r, "text")}), C_AMBER)
		return
	autosave_suspended = false
	recovery_overlay.visible = false
	_set_recovery_buttons({})
	_toast(_t("UI_NOTE_FRESH_SAVED"), C_TEAL)
	_restore_focus(null)


func _show_fatal(msg: String) -> void:
	fatal_overlay.visible = true
	fatal_label.text = _t("UI_FATAL_BODY", {"detail": msg})
	status_label.text = _t("UI_FATAL_TITLE")


func _hide_fatal() -> void:
	fatal_overlay.visible = false


func _retry_core() -> void:
	var candidate = CampaignGame.new(save_slot_path)
	if not _game_ready(candidate):
		_show_fatal(_s(_d(candidate.get_view()), "error", _t("UI_ERR_NO_VIEW")))
		return
	game = candidate
	session_active = false
	_hide_fatal()
	var r := _load_from_disk()
	if not _b(r, "ok"):
		_show_fatal(_s(r, "text"))


# ── 그리기 전용 보조 Control ──────────────────────────────────

class Backdrop extends Control:
	const PTS := [Vector2(0.06, 0.80), Vector2(0.20, 0.64), Vector2(0.34, 0.72), Vector2(0.52, 0.56),
			Vector2(0.68, 0.67), Vector2(0.83, 0.47), Vector2(0.95, 0.58)]

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.034, 0.050, 0.062))
		var g := Color(0.42, 0.62, 0.66, 0.04)
		var step := 40.0
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), g, 1.0)
			x += step
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), g, 1.0)
			y += step
		var line := Color(0.40, 0.80, 0.78, 0.07)
		for i in PTS.size() - 1:
			draw_line(PTS[i] * size, PTS[i + 1] * size, line, 1.0, true)
		draw_line(PTS[1] * size, Vector2(0.28, 0.42) * size, line, 1.0, true)
		draw_line(PTS[4] * size, Vector2(0.74, 0.86) * size, line, 1.0, true)
		for p in PTS:
			draw_circle(p * size, 3.0, Color(0.40, 0.80, 0.78, 0.14))
		draw_circle(PTS[5] * size, 3.5, Color(0.94, 0.67, 0.33, 0.18))
		# 가장자리를 조금 어둡게 해 창이 배경보다 앞에 보이게 한다.
		var edge := Color(0, 0, 0, 0.18)
		draw_rect(Rect2(0, 0, size.x, 60), edge)
		draw_rect(Rect2(0, size.y - 60, size.x, 60), edge)


class NetMap extends Control:
	var nodes: Array = []
	var links: Dictionary = {}
	var local_label := "LOCAL"
	var empty_label := ""
	var known_label := ""
	var connected_fmt := "{list}"

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var fs := maxi(get_theme_default_font_size() - 3, 11)
		var text := Color(0.85, 0.90, 0.91)
		var dim := Color(0.55, 0.63, 0.66)
		var teal := Color(0.40, 0.80, 0.78)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.036, 0.052, 0.062))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.19, 0.26, 0.29), false, 1.0)
		var local := Vector2(48, size.y * 0.5)
		var n := nodes.size()
		for i in n:
			var d: Dictionary = nodes[i] if nodes[i] is Dictionary else {}
			var p := Vector2(maxf(size.x * 0.40, 150.0), size.y * (i + 1) / float(n + 1))
			var id := str(d.get("id", ""))
			var conn: Array = links.get(id, [])
			if not conn.is_empty():
				draw_line(local, p, teal, 2.0, true)
				draw_arc(p, 12.0, 0.0, TAU, 32, teal, 1.5, true)
				draw_circle(p, 6.0, teal)
			else:
				draw_dashed_line(local, p, Color(dim, 0.6), 1.0, 6.0)
				draw_circle(p, 5.0, dim)
			var w := maxf(size.x - p.x - 26.0, 40.0)
			draw_string(font, p + Vector2(22, -3), str(d.get("name", id)), HORIZONTAL_ALIGNMENT_LEFT, w, fs, text)
			var state := connected_fmt.format({"list": ", ".join(PackedStringArray(conn))}) if not conn.is_empty() else known_label
			draw_string(font, p + Vector2(22, fs + 2), "%s · %s" % [str(d.get("address", "")), state], HORIZONTAL_ALIGNMENT_LEFT, w, fs - 1, teal if not conn.is_empty() else dim)
		var local_conn: Array = links.get("local", [])
		draw_circle(local, 8.0, teal)
		draw_string(font, local + Vector2(-30, 28), local_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, teal)
		if not local_conn.is_empty():
			draw_string(font, local + Vector2(-30, 28 + fs + 2), connected_fmt.format({"list": ", ".join(PackedStringArray(local_conn))}), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, dim)
		if n == 0:
			draw_string(font, Vector2(90, local.y + 5), empty_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)


class MemoryGrid extends Control:
	const COLS := 16
	var memory_size := 64
	var buffer_size := 0
	var bytes: Array = []
	var invalid := false

	func _cell_h() -> float:
		return float(get_theme_default_font_size()) + 10.0

	func _get_minimum_size() -> Vector2:
		var rows := ceili(float(memory_size) / float(COLS))
		return Vector2(0, rows * _cell_h() + 10.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
			update_minimum_size()
			queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var fs := maxi(get_theme_default_font_size() - 4, 10)
		var label_w := float(fs) * 3.4
		var cw := maxf((size.x - label_w) / COLS, 12.0)
		var ch := _cell_h()
		var teal := Color(0.40, 0.80, 0.78)
		var amber := Color(0.94, 0.67, 0.33)
		for i in memory_size:
			var r: int = floori(float(i) / COLS)
			var c: int = int(i) % COLS
			var rect := Rect2(label_w + c * cw + 1.0, r * ch + 5.0, cw - 2.0, ch - 2.0)
			var in_buf := i < buffer_size
			var filled := i < bytes.size()
			var bg := Color(0.045, 0.065, 0.075)
			if filled:
				bg = Color(teal, 0.22) if in_buf else Color(amber, 0.24)
			draw_rect(rect, bg)
			draw_rect(rect, Color(teal, 0.35) if in_buf else Color(amber, 0.30), false, 1.0)
			if filled:
				draw_string(font, rect.position + Vector2(3, ch * 0.5 + fs * 0.35), "%02X" % int(bytes[i]), HORIZONTAL_ALIGNMENT_LEFT, cw - 4.0, fs, Color(0.92, 0.95, 0.96))
			if c == 0:
				draw_string(font, Vector2(0, rect.position.y + ch * 0.5 + fs * 0.35), "+%02X" % i, HORIZONTAL_ALIGNMENT_LEFT, label_w - 4.0, fs, Color(0.55, 0.63, 0.66))
		if invalid:
			draw_rect(Rect2(Vector2.ZERO, size), amber, false, 2.0)
