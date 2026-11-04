extends Control
## 심야접속 P1 가상 데스크톱.
## 모든 세계 상태는 Game(코어)에 있다. 이 UI는 get_view()를 표시하고
## execute/submit_password/browse/collect_web/save/load/recover/reset만 요청한다.
## 실제 셸·네트워크·외부 웹뷰·OS.shell_open은 호출하지 않는다.

const Game = preload("res://scripts/core/game.gd")
const UI_FONT = preload("res://assets/fonts/NotoSansKR.ttf")

const C_PANEL := Color(0.07, 0.095, 0.112, 0.97)
const C_BAR := Color(0.095, 0.128, 0.148)
const C_BAR_ACTIVE := Color(0.10, 0.175, 0.19)
const C_LINE := Color(0.20, 0.28, 0.31)
const C_TEXT := Color(0.92, 0.95, 0.96)
const C_DIM := Color(0.67, 0.75, 0.78)
const C_CYAN := Color(0.40, 0.82, 0.80)
const C_CYAN_DIM := Color(0.54, 0.80, 0.80)
const C_AMBER := Color(0.95, 0.68, 0.32)

const TOP_H := 30
const TASK_H := 44
const MAX_LOG_PARAGRAPHS := 800
const MAX_HISTORY := 100
const MIN_WIN := Vector2(340, 200)

# id -> [작업 표시줄 이름, 데스크톱 크기 대비 기본 위치/크기]
const APPS := {
	"terminal": ["터미널", Rect2(0.012, 0.03, 0.53, 0.94)],
	"mail": ["메일", Rect2(0.556, 0.03, 0.432, 0.55)],
	"browser": ["브라우저", Rect2(0.07, 0.07, 0.60, 0.80)],
	"files": ["파일", Rect2(0.26, 0.12, 0.48, 0.62)],
	"archive": ["보관소", Rect2(0.33, 0.16, 0.50, 0.62)],
	"status": ["사건", Rect2(0.556, 0.605, 0.432, 0.365)],
	"help": ["도움말", Rect2(0.60, 0.06, 0.37, 0.74)],
}
const APP_ORDER := ["terminal", "mail", "browser", "files", "archive", "status", "help"]

const HELP_TEXT := "이 컴퓨터는 게임 속 가상 단말입니다. 서버·사이트·파일은 모두 허구이며 실제 네트워크나 셸로 나가지 않습니다.\n\n터미널\n  Enter 실행 · ↑/↓ 이전 명령 · Tab 자동완성 · Esc 입력 지우기/암호 대기 취소 · clear 화면 지우기\n  암호 입력 중에는 입력이 가려지고 기록에 남지 않습니다.\n\n창\n  제목줄을 끌어 이동 · 제목줄 두 번 클릭으로 최대화/복원 · 오른쪽 아래 모서리로 크기 조절\n  ─ 최소화, × 닫기(앱 상태·입력·로그는 유지) · 작업 표시줄 버튼으로 다시 열기\n  창이 화면 밖으로 사라지면 '창 정렬'로 기본 배치를 복원합니다.\n  글씨가 작으면 상단 A- / A+ 로 조절합니다.\n\n저장\n  저장: 고정 슬롯에 기록 · 불러오기: 마지막 저장으로 되돌림\n  새 작업: 세계 초기화 후 자동저장 일시중지. [저장]을 누르면 이전 슬롯을 대체하고 자동저장을 재개\n\n경보\n  서버가 관찰한 거절 행동에만 오릅니다. 로컬 오타·읽기·창 전환은 경보와 무관합니다."

@export var save_slot_path: String = "user://saves/slot_01.json"
var autosave_paused := false
var autosave_label: Label
var fresh_save_btn: Button
var game = null
var ui_theme := Theme.new()
var ui_size := 17
var term_size := 20
var sized: Array = []  # [Control, delta, is_terminal]

var sb_frame_on: StyleBoxFlat
var sb_frame_off: StyleBoxFlat
var sb_bar_on: StyleBoxFlat
var sb_bar_off: StyleBoxFlat

var layer: Control
var mission_label: Label
var alert_label: Label
var host_label: Label
var task_buttons := {}
var status_label: Label
var recover_btn: Button
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var confirm: ConfirmationDialog
var confirm_action := Callable()
var error_overlay: Control
var error_label: Label

var wins := {}  # id -> {win, frame, bar, focus, state, placed, restore}
var active_id := ""
var drag := {}
var last_view: Dictionary = {}

# 터미널
var term_out: RichTextLabel
var term_in: LineEdit
var term_prompt: Label
var term_header: Label
var history: Array[String] = []
var hist_idx := -1
var hist_draft := ""
var last_submit_frame := -1
var pw_pending := false

# 메일
var mail_list: ItemList
var mail_sender: Label
var mail_subject: Label
var mail_body: RichTextLabel
var read_ids := {}
var selected_mail := ""
var shown_mail_key := ""

# 브라우저
var br_addr: LineEdit
var br_title: Label
var br_body: RichTextLabel
var br_links: VBoxContainer
var br_status: Label
var br_archive: Button
var br_back: Button
var br_fwd: Button
var br_history: Array[String] = []
var br_cursor := -1
var br_url := ""
var br_failed := false
var br_opened := false

# 파일
var fs_path: Label
var fs_list: ItemList
var fs_title: Label
var fs_out: RichTextLabel

# 보관소
var ar_list: ItemList
var ar_meta: Label
var ar_body: RichTextLabel
var selected_archive := ""

# 사건/도움말
var st_mission: Label
var st_goal: Label
var st_conn: Label
var st_alert: Label
var st_done: Label
var net_map: NetMap
var hp_goal: Label
var hp_hint: Label
var hp_hint_btn: Button


func _ready() -> void:
	get_window().title = "심야접속 · M01 첫 실행판"
	_build_theme()
	theme = ui_theme
	_build_shell()
	_build_windows()
	_build_overlays()
	_start_game()


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


func _view() -> Dictionary:
	if game == null:
		return {}
	return _d(game.get_view())


func _ready_ok() -> bool:
	return game != null and not error_overlay.visible


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
	var readable_font := FontVariation.new()
	readable_font.base_font = UI_FONT
	readable_font.variation_embolden = 0.4
	readable_font.variation_opentype = {"wght": 500.0}
	t.default_font = readable_font
	t.default_font_size = ui_size
	for cls in ["Label", "Button", "LineEdit", "ItemList"]:
		t.set_color("font_color", cls, C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_color("font_selected_color", "RichTextLabel", Color.WHITE)
	t.set_color("selection_color", "RichTextLabel", Color(0.22, 0.45, 0.46, 0.6))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_CYAN)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.47))
	t.set_color("font_placeholder_color", "LineEdit", Color(0.42, 0.49, 0.52))
	t.set_color("caret_color", "LineEdit", C_CYAN)
	t.set_color("selection_color", "LineEdit", Color(0.22, 0.45, 0.46, 0.6))
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)

	t.set_stylebox("normal", "Button", _sb(Color(0.11, 0.15, 0.17), C_LINE, 1, 3, 6))
	t.set_stylebox("hover", "Button", _sb(Color(0.14, 0.20, 0.22), Color(0.3, 0.55, 0.56), 1, 3, 6))
	t.set_stylebox("pressed", "Button", _sb(Color(0.09, 0.20, 0.21), C_CYAN, 1, 3, 6))
	t.set_stylebox("disabled", "Button", _sb(Color(0.08, 0.10, 0.11), C_LINE, 1, 3, 6))
	var focus := _sb(Color(0, 0, 0, 0), C_CYAN, 1, 3, 6)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("normal", "LineEdit", _sb(Color(0.035, 0.05, 0.06), C_LINE, 1, 3, 6))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", _sb(Color(0.05, 0.06, 0.07), C_LINE, 1, 3, 6))
	t.set_stylebox("panel", "ItemList", _sb(Color(0.045, 0.065, 0.075), C_LINE, 1, 3, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _sb(Color(0.11, 0.22, 0.23), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("selected_focus", "ItemList", _sb(Color(0.12, 0.26, 0.27), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("hovered", "ItemList", _sb(Color(0.09, 0.14, 0.15), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("normal", "RichTextLabel", _sb(Color(0.035, 0.05, 0.06), C_LINE, 1, 3, 8))
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, C_LINE, 1, 4, 0))
	t.set_stylebox("panel", "TooltipPanel", _sb(Color(0.06, 0.08, 0.09), C_LINE, 1, 3, 6))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)

	sb_frame_off = _sb(C_PANEL, C_LINE, 1, 4, 1)
	sb_frame_off.shadow_color = Color(0, 0, 0, 0.35)
	sb_frame_off.shadow_size = 10
	sb_frame_on = sb_frame_off.duplicate()
	sb_frame_on.border_color = Color(0.30, 0.62, 0.62)
	sb_bar_off = _sb(C_BAR, Color(0, 0, 0, 0), 0, 0, 3)
	sb_bar_off.corner_radius_top_left = 4
	sb_bar_off.corner_radius_top_right = 4
	sb_bar_off.content_margin_left = 10
	sb_bar_on = sb_bar_off.duplicate()
	sb_bar_on.bg_color = C_BAR_ACTIVE


func _size(c: Control, delta: int, term: bool) -> void:
	sized.append([c, delta, term])
	_apply_size(c, delta, term)


func _apply_size(c: Control, delta: int, term: bool) -> void:
	var key := "normal_font_size" if c is RichTextLabel else "font_size"
	c.add_theme_font_size_override(key, (term_size if term else ui_size) + delta)


func _font_step(d: int) -> void:
	ui_size = clampi(ui_size + d, 14, 22)
	term_size = clampi(term_size + d, 16, 26)
	ui_theme.default_font_size = ui_size
	for e in sized:
		if is_instance_valid(e[0]):
			_apply_size(e[0], e[1], e[2])


# ── 공통 위젯 ──────────────────────────────────────────────────

func _btn(text: String, tip: String, cb: Callable, focusable: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
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


# 선택·복사 가능한 순수 텍스트 출력. BBCode를 해석하지 않고 meta 링크를 열지 않는다.
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


func _pulse(c: CanvasItem, color: Color) -> void:
	if c == null:
		return
	c.modulate = color.lightened(0.35)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color.WHITE, 0.9)


# ── 바탕/상단/작업 표시줄 ───────────────────────────────────────

func _build_shell() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.offset_top = TOP_H
	layer.offset_bottom = -TASK_H
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.resized.connect(_clamp_all)
	add_child(layer)

	var top := PanelContainer.new()
	var top_sb := _sb(Color(0.03, 0.045, 0.055, 0.94), C_LINE, 0, 0, 4)
	top_sb.border_width_bottom = 1
	top_sb.content_margin_left = 14
	top_sb.content_margin_right = 10
	top.add_theme_stylebox_override("panel", top_sb)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 0
	top.offset_bottom = TOP_H
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	top.add_child(row)
	row.add_child(_label("심야접속 / MIDNIGHT ACCESS", C_DIM, -4))
	mission_label = _label("", C_TEXT, -3)
	mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.clip_text = true
	row.add_child(mission_label)
	alert_label = _label("", C_DIM, -3)
	row.add_child(alert_label)
	host_label = _label("M01 / LOCAL", C_CYAN, -3)
	row.add_child(host_label)
	autosave_label = _label("자동저장 ON", C_CYAN_DIM, -4)
	row.add_child(autosave_label)
	for d in [-1, 1]:
		var fb := _btn("A-" if d < 0 else "A+", "글자 크기", _font_step.bind(d), false)
		fb.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), C_LINE, 1, 3, 2))
		_size(fb, -5, false)
		row.add_child(fb)

	var task := PanelContainer.new()
	var task_sb := _sb(Color(0.035, 0.05, 0.06, 0.96), C_LINE, 0, 0, 5)
	task_sb.border_width_top = 1
	task_sb.content_margin_left = 10
	task_sb.content_margin_right = 10
	task.add_theme_stylebox_override("panel", task_sb)
	task.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	task.offset_top = -TASK_H
	task.offset_bottom = 0
	add_child(task)
	var trow := HBoxContainer.new()
	task.add_child(trow)
	for id in APP_ORDER:
		var b := _btn(APPS[id][0], "열기 / 앞으로 가져오기", _open_app.bind(id, true), false)
		_size(b, -2, false)
		task_buttons[id] = b
		trow.add_child(b)
	trow.add_child(VSeparator.new())
	var arrange := _btn("창 정렬", "모든 창을 기본 배치로 복원", _arrange, false)
	_size(arrange, -2, false)
	trow.add_child(arrange)
	status_label = _label("", C_DIM, -3)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	trow.add_child(status_label)
	for spec in [["저장", "고정 슬롯에 현재 진행 저장", _save],
			["불러오기", "마지막 저장으로 되돌리기", _ask_load],
			["새 작업", "진행 중인 세계만 초기화 (디스크 저장은 유지)", _ask_reset]]:
		var sbtn := _btn(spec[0], spec[1], spec[2], false)
		_size(sbtn, -2, false)
		trow.add_child(sbtn)
	recover_btn = _btn("백업 복구", "손상된 저장본은 보존하고 정상 백업으로 복구", _ask_recover, false)
	recover_btn.add_theme_color_override("font_color", C_AMBER)
	recover_btn.visible = false
	_size(recover_btn, -2, false)
	trow.add_child(recover_btn)
	fresh_save_btn = _btn("손상본 보존·새 저장", "기존 손상본과 백업은 별도 보존하고 현재 진행을 새 저장", _ask_fresh_save, false)
	fresh_save_btn.add_theme_color_override("font_color", C_AMBER)
	fresh_save_btn.visible = false
	_size(fresh_save_btn, -2, false)
	trow.add_child(fresh_save_btn)


func _build_overlays() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.anchor_left = 1.0
	toast_panel.anchor_right = 1.0
	toast_panel.offset_left = -460
	toast_panel.offset_right = -18
	toast_panel.offset_top = TOP_H + 12
	toast_panel.offset_bottom = TOP_H + 12
	toast_panel.visible = false
	add_child(toast_panel)
	toast_label = _label("", C_TEXT, -1, true)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	confirm = ConfirmationDialog.new()
	confirm.title = "확인"
	confirm.ok_button_text = "확인"
	confirm.cancel_button_text = "취소"
	confirm.dialog_autowrap = true
	confirm.theme = ui_theme
	confirm.confirmed.connect(func():
		if confirm_action.is_valid():
			confirm_action.call())
	add_child(confirm)

	error_overlay = PanelContainer.new()
	error_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	error_overlay.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.03, 0.035, 0.94), Color(0, 0, 0, 0), 0, 0, 0))
	error_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	error_overlay.visible = false
	add_child(error_overlay)
	var center := CenterContainer.new()
	error_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	center.add_child(box)
	box.add_child(_label("게임 데이터를 준비하지 못했습니다", C_AMBER, 3))
	error_label = _label("", C_TEXT, 0, true)
	box.add_child(error_label)
	box.add_child(_btn("다시 시도", "코어를 다시 초기화", _start_game))


# ── 게임 시작/오류 ─────────────────────────────────────────────

func _start_game() -> void:
	game = Game.new(save_slot_path)
	var v := _view()
	if v.is_empty() or not _b(v, "ready", true):
		_show_fatal(_s(v, "error", "코어가 화면 정보를 반환하지 않았습니다."))
		return
	error_overlay.visible = false
	term_out.clear()
	_term_line("심야접속 로컬 단말 · 'help'로 사용 가능한 명령을 확인하세요.", C_DIM)
	var existing := _d(game.load_game())
	if _b(existing, "ok"):
		_term_line("이전 야간 작업을 이어갑니다. 새로 시작하려면 새 작업을 선택하세요.", C_CYAN)
		v = _view()
	elif _s(existing, "code") != "SAVE_NOT_FOUND" or _b(existing, "backup_available"):
		_report_io(existing, "저장 확인")
	_refresh_all(v)
	_open_app("status", false)
	_open_app("mail", false)
	_open_app("terminal", true)


func _show_fatal(msg: String) -> void:
	error_overlay.visible = true
	error_label.text = "%s\n\n다른 내용으로 대체하지 않았습니다. 미션 데이터와 코어 오류를 확인하세요." % msg
	status_label.text = "준비 오류"


# ── 창 관리 ───────────────────────────────────────────────────

func _build_windows() -> void:
	_make_window("terminal", "터미널", _build_terminal(), term_in)
	_make_window("mail", "메일", _build_mail(), mail_list)
	_make_window("browser", "브라우저 · 가상 네트워크", _build_browser(), br_addr)
	_make_window("files", "파일 보기", _build_files(), fs_list)
	_make_window("archive", "로컬 보관소", _build_archive(), ar_list)
	_make_window("status", "사건 · 네트워크", _build_status(), null)
	_make_window("help", "도움말", _build_help(), null)


func _make_window(id: String, title: String, content: Control, focus: Control) -> void:
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
	var lbl := _label(title, C_TEXT, -2)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	bar_row.add_child(lbl)
	var flat := _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 2)
	flat.content_margin_left = 9
	flat.content_margin_right = 9
	for spec in [["─", "최소화", _minimize], ["×", "닫기 (상태는 유지)", _close]]:
		var cb: Callable = spec[2]
		var b := _btn(spec[0], spec[1], cb.bind(id), false)
		b.add_theme_stylebox_override("normal", flat)
		_size(b, -3, false)
		bar_row.add_child(b)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	col.add_child(pad)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(content)

	var grip := Control.new()
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -14
	grip.offset_top = -14
	grip.offset_right = 0
	grip.offset_bottom = 0
	grip.gui_input.connect(_on_grip_input.bind(id))
	grip.draw.connect(func():
		grip.draw_line(Vector2(3, 12), Vector2(12, 3), C_DIM, 1.0)
		grip.draw_line(Vector2(8, 12), Vector2(12, 8), C_DIM, 1.0))
	win.add_child(grip)

	wins[id] = {"win": win, "frame": frame, "bar": bar, "focus": focus,
			"state": "closed", "placed": false, "restore": Rect2()}


func _desk_size() -> Vector2:
	if layer != null and layer.size.x > 1.0:
		return layer.size
	return get_viewport_rect().size - Vector2(0, TOP_H + TASK_H)


func _default_rect(id: String) -> Rect2:
	var f: Rect2 = APPS[id][1]
	var area := _desk_size()
	return Rect2(f.position * area, f.size * area)


func _clamp_win(w: Control) -> void:
	var area := _desk_size()
	w.size = Vector2(minf(maxf(w.size.x, MIN_WIN.x), area.x), minf(maxf(w.size.y, MIN_WIN.y), area.y))
	# 제목줄의 일부가 항상 데스크톱 안에 남아 잡을 수 있게 한다.
	w.position = Vector2(clampf(w.position.x, 90.0 - w.size.x, area.x - 90.0),
			clampf(w.position.y, 0.0, maxf(area.y - 34.0, 0.0)))


func _clamp_all() -> void:
	for id in wins:
		_clamp_win(wins[id]["win"])


func _open_app(id: String, grab: bool = true) -> void:
	if not _ready_ok():
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
		_navigate(_s(last_view, "browser_home", ""), true)
	elif id == "mail":
		_select_unread_mail()


func _activate(id: String, grab: bool) -> void:
	active_id = id
	var win: Control = wins[id]["win"]
	win.move_to_front()
	for k in wins:
		var on: bool = k == id
		wins[k]["frame"].add_theme_stylebox_override("panel", sb_frame_on if on else sb_frame_off)
		wins[k]["bar"].add_theme_stylebox_override("panel", sb_bar_on if on else sb_bar_off)
	if grab:
		_focus_default(id)
	_update_taskbar()


func _focus_default(id: String) -> void:
	var f = wins[id]["focus"]
	if f is Control and f.is_visible_in_tree():
		f.grab_focus()
		if f is LineEdit and f.has_method("edit"):
			f.call("edit")
	else:
		get_viewport().gui_release_focus()


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


func _arrange() -> void:
	if not _ready_ok():
		return
	for id in APP_ORDER:
		var w: Dictionary = wins[id]
		var win: Control = w["win"]
		var r := _default_rect(id)
		win.position = r.position
		win.size = r.size
		w["placed"] = true
		if w["state"] == "min":
			w["state"] = "open"
			win.visible = true
	for id in APP_ORDER:
		if wins[id]["state"] == "open" and id != "terminal":
			_activate(id, false)
	if wins["terminal"]["state"] == "open":
		_activate("terminal", true)


func _on_bar_input(event: InputEvent, id: String) -> void:
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


# GUI 피킹보다 먼저 클릭된 창을 맨 앞으로 올린다. 다른 창에 있던 키보드 포커스는
# 놓아서 뒤 창 클릭 후의 타이핑이 앞 창 입력에 새지 않게 한다.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or error_overlay.visible or confirm.visible:
		return
	if not (mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]):
		return
	for i in range(layer.get_child_count() - 1, -1, -1):
		var c := layer.get_child(i) as Control
		if c == null or not c.visible or not c.get_global_rect().has_point(mb.position):
			continue
		var id := str(c.get_meta("app_id"))
		var fo := get_viewport().gui_get_focus_owner()
		if fo != null and not c.is_ancestor_of(fo):
			get_viewport().gui_release_focus()
		if id != active_id:
			_activate(id, false)
		call_deferred("_focus_after_click", id)
		return


func _focus_after_click(id: String) -> void:
	var fo := get_viewport().gui_get_focus_owner()
	var win: Control = wins[id]["win"]
	if win.visible and (fo == null or not win.is_ancestor_of(fo)):
		_focus_default(id)


func _update_taskbar() -> void:
	for id in task_buttons:
		var b: Button = task_buttons[id]
		var st: String = wins[id]["state"]
		var label_text: String = APPS[id][0]
		if id == "mail":
			var n := _unread_count()
			if n > 0:
				label_text += " (%d)" % n
		b.text = ("● " if st == "open" else ("○ " if st == "min" else "")) + label_text
		var col := C_DIM
		if st != "closed":
			col = C_CYAN if id == active_id and st == "open" else C_TEXT
		b.add_theme_color_override("font_color", col)


# ── 터미널 ────────────────────────────────────────────────────

func _build_terminal() -> Control:
	var col := VBoxContainer.new()
	term_header = _label("", C_DIM, -3)
	term_header.clip_text = true
	col.add_child(term_header)
	term_out = _plain_text(true)
	term_out.scroll_following = true  # 맨 아래일 때만 따라가고, 위로 읽는 중이면 위치를 유지한다.
	term_out.gui_input.connect(_on_term_out_input)
	col.add_child(term_out)
	var row := HBoxContainer.new()
	term_prompt = _label("$", C_CYAN, -2, false, true)
	row.add_child(term_prompt)
	term_in = LineEdit.new()
	term_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_in.max_length = 256
	term_in.set("keep_editing_on_text_submit", true)
	term_in.text_submitted.connect(_on_term_submit)
	term_in.gui_input.connect(_on_term_key)
	_size(term_in, 0, true)
	row.add_child(term_in)
	col.add_child(row)
	return col


func _term_line(text: String, color: Color) -> void:
	# 한 단락마다 색 구간을 닫아 오래된 단락을 안전하게 지울 수 있게 한다.
	for line in text.split("\n"):
		term_out.push_color(color)
		term_out.add_text(line)
		term_out.pop()
		term_out.newline()
	if term_out.get_paragraph_count() > MAX_LOG_PARAGRAPHS + 100:
		while term_out.get_paragraph_count() > MAX_LOG_PARAGRAPHS:
			term_out.remove_paragraph(0)


func _print_result(r: Dictionary) -> void:
	var ok := _b(r, "ok", false)
	var t := _s(r, "text").trim_suffix("\n")
	if not t.is_empty():
		_term_line(t, C_TEXT if ok else C_AMBER)
	var code := _s(r, "code")
	if not ok and not code.is_empty():
		_term_line("  · " + code, C_DIM)


func _refocus_terminal() -> void:
	if wins.has("terminal") and wins["terminal"]["win"].visible:
		term_in.grab_focus()
		if term_in.has_method("edit"):
			term_in.call("edit")


func _on_term_out_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and term_out.get_selected_text().is_empty():
		_refocus_terminal()


func _on_term_key(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or term_in.has_ime_text():
		return
	match k.keycode:
		KEY_UP:
			_hist(-1)
		KEY_DOWN:
			_hist(1)
		KEY_TAB:
			if k.shift_pressed:
				return
			_complete()
		KEY_ESCAPE:
			term_in.clear()
			if pw_pending:
				_print_result(_do_action(func(): return game.cancel_authentication()))
		_:
			return
	term_in.accept_event()


func _hist(dir: int) -> void:
	if history.is_empty() or pw_pending:
		return
	if hist_idx == -1:
		if dir > 0:
			return
		hist_draft = term_in.text
		hist_idx = history.size() - 1
	else:
		hist_idx += dir
	if hist_idx >= history.size():
		hist_idx = -1
		term_in.text = hist_draft
	else:
		hist_idx = maxi(hist_idx, 0)
		term_in.text = history[hist_idx]
	term_in.caret_column = term_in.text.length()


func _complete() -> void:
	# 암호 입력 중에는 입력 문자열을 어디에도 보내지 않는다.
	if not _ready_ok() or pw_pending:
		return
	var line := term_in.text
	var raw = game.autocomplete(line)
	var cands: Array = []
	if raw is PackedStringArray or raw is Array:
		cands = Array(raw)
	if cands.is_empty():
		return
	var applied := _apply_completion(line, _common_prefix(cands))
	if cands.size() == 1 and applied != line and not applied.ends_with("/") and not applied.ends_with(" "):
		applied += " "
	if applied != line:
		term_in.text = applied
		term_in.caret_column = applied.length()
	if cands.size() > 1:
		_term_line("  ".join(PackedStringArray(cands)), C_DIM)


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


func _on_term_submit(text: String) -> void:
	if term_in.has_ime_text():
		return
	var frame := Engine.get_process_frames()
	if frame == last_submit_frame:
		return
	last_submit_frame = frame
	term_in.clear()
	hist_idx = -1
	_refocus_terminal()
	if not _ready_ok():
		return
	if pw_pending:
		if text.is_empty():
			_term_line("(빈 암호는 보내지 않았습니다)", C_DIM)
			return
		_term_line("암호 입력됨 (가림)", C_DIM)
		var pw := text
		_print_result(_do_action(func(): return game.submit_password(pw)))
		return
	var cmd := text.strip_edges()
	if cmd.is_empty():
		_term_line(term_prompt.text, C_CYAN_DIM)
		return
	if history.is_empty() or history[-1] != cmd:
		history.append(cmd)
		if history.size() > MAX_HISTORY:
			history.remove_at(0)
	if cmd == "clear":
		term_out.clear()
		return
	_run_command(cmd, "")


func _run_command(cmd: String, tag: String) -> Dictionary:
	var prefix := ("[%s] " % tag) if not tag.is_empty() else ""
	_term_line(prefix + term_prompt.text + " " + cmd, C_CYAN_DIM)
	var r := _do_action(func(): return game.execute(cmd))
	_print_result(r)
	return r


func _do_action(action: Callable) -> Dictionary:
	var before := _view()
	var raw = action.call()
	var r: Dictionary = raw if raw is Dictionary else {"ok": false, "code": "UI_BAD_RESULT", "text": "코어가 올바른 결과를 반환하지 않았습니다."}
	_after_action(before, r)
	if _b(r, "changed") and not autosave_paused:
		var saved := _d(game.save_game())
		if not _b(saved, "ok"):
			_report_io(saved, "자동저장")
	return r


# 행동 전후의 읽기 모델을 비교해 ACCESS·경보·회수·완료를 작게 강조한다.
func _after_action(before: Dictionary, r: Dictionary) -> void:
	var v := _view()
	var notes: Array = []
	var color := C_TEXT
	var b_ids := _ids(_a(before, "messages"))
	var new_mail := false
	for id in _ids(_a(v, "messages")):
		if not b_ids.has(id):
			new_mail = true
	if not _b(before, "completed") and _b(v, "completed"):
		notes.append("의뢰 완료" + (" · 새 메일이 도착했습니다." if new_mail else ""))
		color = C_CYAN
	elif new_mail:
		notes.append("새 메일이 도착했습니다.")
	var arc := _a(v, "archive")
	if arc.size() > _a(before, "archive").size():
		notes.append("회수 · %s → 로컬 보관소" % _s(_d(arc.back()), "name"))
		if color == C_TEXT:
			color = C_CYAN
		_pulse(task_buttons["archive"], C_CYAN)
	var al := _i(v, "alert_level")
	var mx := _i(v, "alert_max", 3)
	if al > _i(before, "alert_level"):
		var msg := "경보 %d/%d · 서버가 거절된 시도를 기록했습니다." % [al, mx]
		if al >= mx:
			msg += "\n상한 도달 · 도움말 창에서 현재 단서를 확인할 수 있습니다."
		notes.append(msg)
		if color == C_TEXT:
			color = C_AMBER
		_pulse(alert_label, C_AMBER)
	var host := _s(v, "host")
	var user := _s(v, "user")
	if _b(r, "ok", false) and (host != _s(before, "host") or user != _s(before, "user")):
		if _is_local(v):
			notes.append("로컬로 복귀 · %s" % user)
		else:
			notes.append("ACCESS · %s@%s" % [user, host])
			if color == C_TEXT:
				color = C_CYAN
		_pulse(term_header, C_CYAN)
		_pulse(term_prompt, C_CYAN)
	_refresh_all(v)
	if not notes.is_empty():
		_toast("\n".join(PackedStringArray(notes)), color)


static func _ids(msgs: Array) -> Dictionary:
	var out := {}
	for m in msgs:
		out[_s(_d(m), "id")] = true
	return out


func _is_local(v: Dictionary) -> bool:
	var host := _s(v, "host")
	for n in _a(v, "network"):
		var d := _d(n)
		if host == _s(d, "id") or host == _s(d, "address") or host == _s(d, "name"):
			return false
	return true


func _toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_panel.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.075, 0.085, 0.96), color.darkened(0.25), 1, 4, 10))
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	status_label.text = text.replace("\n", " · ")
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(3.5)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.6)
	toast_tween.tween_callback(toast_panel.hide)


# ── 메일 ──────────────────────────────────────────────────────

func _build_mail() -> Control:
	var split := HSplitContainer.new()
	mail_list = ItemList.new()
	mail_list.custom_minimum_size = Vector2(230, 0)
	mail_list.item_selected.connect(_on_mail_selected)
	split.add_child(mail_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var avatar := PanelContainer.new()  # 얼굴 없는 추상 아바타
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar.add_theme_stylebox_override("panel", _sb(Color(0.10, 0.19, 0.21), C_CYAN_DIM, 1, 22, 0))
	var glyph := _label("◆", C_CYAN, -2)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(glyph)
	head.add_child(avatar)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mail_subject = _label("", C_TEXT, 1, true)
	mail_sender = _label("", C_DIM, -2)
	names.add_child(mail_subject)
	names.add_child(mail_sender)
	head.add_child(names)
	right.add_child(head)
	mail_body = _plain_text()
	right.add_child(mail_body)
	split.add_child(right)
	return split


func _refresh_mail(v: Dictionary) -> void:
	mail_list.clear()
	var sel := -1
	for m in _a(v, "messages"):
		var d := _d(m)
		var id := _s(d, "id")
		var i := mail_list.add_item(("   " if read_ids.has(id) else "● ") + _s(d, "subject", "(제목 없음)"))
		mail_list.set_item_metadata(i, d)
		mail_list.set_item_tooltip(i, _s(d, "sender"))
		if id == selected_mail:
			sel = i
	if sel >= 0:
		mail_list.select(sel)
		_show_mail(_d(mail_list.get_item_metadata(sel)))
	elif mail_list.item_count == 0:
		selected_mail = ""
		mail_subject.text = "받은 메일 없음"
		mail_sender.text = ""
		shown_mail_key = ""
		mail_body.clear()


func _select_unread_mail() -> void:
	for i in range(mail_list.item_count - 1, -1, -1):
		if not read_ids.has(_s(_d(mail_list.get_item_metadata(i)), "id")):
			mail_list.select(i)
			_on_mail_selected(i)
			return
	if selected_mail.is_empty() and mail_list.item_count > 0:
		mail_list.select(0)
		_on_mail_selected(0)


func _on_mail_selected(i: int) -> void:
	var d := _d(mail_list.get_item_metadata(i))
	selected_mail = _s(d, "id")
	read_ids[selected_mail] = true
	mail_list.set_item_text(i, "   " + _s(d, "subject", "(제목 없음)"))
	_show_mail(d)
	_update_taskbar()


func _show_mail(d: Dictionary) -> void:
	var key := _s(d, "id") + "\n" + _s(d, "body")
	if key == shown_mail_key:
		return  # 같은 메일이면 본문 스크롤 위치를 유지한다.
	shown_mail_key = key
	mail_subject.text = _s(d, "subject", "(제목 없음)")
	mail_sender.text = _s(d, "sender")
	_set_plain(mail_body, _s(d, "body"))


func _unread_count() -> int:
	var n := 0
	for m in _a(last_view, "messages"):
		if not read_ids.has(_s(_d(m), "id")):
			n += 1
	return n


# ── 브라우저 ──────────────────────────────────────────────────

func _build_browser() -> Control:
	var col := VBoxContainer.new()
	var bar := HBoxContainer.new()
	br_back = _btn("←", "뒤로", _br_go.bind(-1))
	br_fwd = _btn("→", "앞으로", _br_go.bind(1))
	bar.add_child(br_back)
	bar.add_child(br_fwd)
	bar.add_child(_btn("새로고침", "다시 요청", func(): _navigate(br_addr.text, false)))
	bar.add_child(_btn("홈", "등록된 홈", func(): _navigate(_s(last_view, "browser_home", ""), true)))
	br_addr = LineEdit.new()
	br_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br_addr.max_length = 512
	br_addr.placeholder_text = "주소 입력 · 게임 속 가상 사이트만 열립니다"
	br_addr.text_submitted.connect(func(t: String):
		if not br_addr.has_ime_text():
			_navigate(t, true))
	bar.add_child(br_addr)
	bar.add_child(_btn("이동", "주소로 이동", func(): _navigate(br_addr.text, true)))
	col.add_child(bar)
	br_title = _label("", C_TEXT, 3, true)
	col.add_child(br_title)
	br_body = _plain_text()
	col.add_child(br_body)
	br_links = VBoxContainer.new()
	br_links.add_theme_constant_override("separation", 2)
	col.add_child(br_links)
	var foot := HBoxContainer.new()
	br_status = _label("", C_DIM, -3)
	br_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br_status.clip_text = true
	foot.add_child(br_status)
	br_archive = _btn("사본 보관", "이 페이지의 사본을 로컬 보관소로 회수", _archive_page)
	br_archive.add_theme_color_override("font_color", C_CYAN)
	br_archive.visible = false
	foot.add_child(br_archive)
	col.add_child(foot)
	_update_nav()
	return col


func _navigate(url: String, push: bool) -> void:
	url = url.strip_edges()
	if url.is_empty() or not _ready_ok():
		return
	br_addr.text = url
	var before := _view()
	var r := _d(game.browse(url))
	for c in br_links.get_children():
		c.queue_free()
	if _b(r, "ok", false):
		br_failed = false
		br_url = _s(r, "url", url)
		if push and (br_cursor < 0 or br_history[br_cursor] != br_url):
			br_history.resize(br_cursor + 1)
			br_history.append(br_url)
			br_cursor = br_history.size() - 1
		br_addr.text = br_url
		br_title.text = _s(r, "title")
		_set_plain(br_body, _s(r, "body"))
		for l in _a(r, "links"):
			var d := _d(l)
			var target := _s(d, "url")
			var lb := _btn("→ %s   %s" % [_s(d, "label", target), target], target, _navigate.bind(target, true))
			lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lb.flat = true
			lb.add_theme_color_override("font_color", C_CYAN)
			br_links.add_child(lb)
		br_archive.visible = _b(r, "can_archive", false)
		br_status.text = "가상 페이지 · 실제 인터넷에 연결하지 않습니다"
		br_status.add_theme_color_override("font_color", C_DIM)
	else:
		br_failed = true
		br_url = ""
		br_archive.visible = false
		br_title.text = "페이지를 열 수 없음"
		var body := _s(r, "body", _s(r, "text"))
		_set_plain(br_body, body if not body.is_empty() else "이 주소는 게임 속 가상 네트워크에 없습니다.")
		br_status.text = "오류 %s · %s" % [_s(r, "code", "UNKNOWN"), url]
		br_status.add_theme_color_override("font_color", C_AMBER)
	_update_nav()
	_after_action(before, r)


func _br_go(dir: int) -> void:
	if br_failed and dir < 0 and br_cursor >= 0:
		_navigate(br_history[br_cursor], false)
		return
	var n := br_cursor + dir
	if n < 0 or n >= br_history.size():
		return
	br_cursor = n
	_navigate(br_history[n], false)


func _update_nav() -> void:
	br_back.disabled = br_cursor <= 0 and not (br_failed and br_cursor >= 0)
	br_fwd.disabled = br_cursor >= br_history.size() - 1


func _archive_page() -> void:
	if br_url.is_empty() or not _ready_ok():
		return
	var url := br_url
	_term_line("[브라우저] 사본 보관 · " + url, C_CYAN_DIM)
	var r := _do_action(func(): return game.collect_web(url))
	_print_result(r)
	var ok := _b(r, "ok", false)
	if ok:
		_navigate(url, false)  # can_archive 등 최신 페이지 상태 반영
	br_status.text = _s(r, "text").replace("\n", " ")
	br_status.add_theme_color_override("font_color", C_CYAN if ok else C_AMBER)


# ── 파일 보기 ─────────────────────────────────────────────────

func _build_files() -> Control:
	var col := VBoxContainer.new()
	var bar := HBoxContainer.new()
	fs_path = _label("", C_CYAN, -2)
	fs_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_path.clip_text = true
	bar.add_child(fs_path)
	bar.add_child(_btn("상위 폴더", "cd ..", func():
		if _ready_ok():
			_run_command("cd ..", "파일")))
	bar.add_child(_btn("열기", "선택 항목 열기", func():
		var s := fs_list.get_selected_items()
		if not s.is_empty():
			_open_entry(s[0])))
	col.add_child(bar)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fs_list = ItemList.new()
	fs_list.custom_minimum_size = Vector2(230, 0)
	fs_list.item_activated.connect(_open_entry)
	split.add_child(fs_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_title = _label("", C_DIM, -2)
	fs_title.clip_text = true
	right.add_child(fs_title)
	fs_out = _plain_text()
	right.add_child(fs_out)
	split.add_child(right)
	col.add_child(split)
	col.add_child(_label("두 번 클릭 또는 Enter: 폴더는 cd, 파일은 cat으로 현재 터미널 세션에서 실행됩니다.", C_DIM, -4, true))
	return col


func _refresh_files(v: Dictionary) -> void:
	fs_path.text = "%s@%s : %s" % [_s(v, "user"), _s(v, "host"), _s(v, "cwd")]
	fs_list.clear()
	for f in _a(v, "files"):
		var d := _d(f)
		var is_dir := _s(d, "kind") == "dir"
		var i := fs_list.add_item(("▷ %s/" if is_dir else "· %s") % _s(d, "name"))
		fs_list.set_item_metadata(i, d)
		fs_list.set_item_tooltip(i, _s(d, "path"))
	if fs_list.item_count == 0:
		var i := fs_list.add_item("(이 위치에서 보이는 항목 없음)")
		fs_list.set_item_disabled(i, true)
		fs_list.set_item_metadata(i, {})


func _open_entry(i: int) -> void:
	var d := _d(fs_list.get_item_metadata(i))
	var path := _s(d, "path")
	if path.is_empty() or not _ready_ok():
		return
	var q := ("\"%s\"" % path) if " " in path else path
	if _s(d, "kind") == "dir":
		_run_command("cd " + q, "파일")
		return
	var r := _run_command("cat " + q, "파일")
	fs_title.text = path
	fs_title.add_theme_color_override("font_color", C_DIM if _b(r, "ok", false) else C_AMBER)
	_set_plain(fs_out, _s(r, "text"))


# ── 보관소 ────────────────────────────────────────────────────

func _build_archive() -> Control:
	var split := HSplitContainer.new()
	ar_list = ItemList.new()
	ar_list.custom_minimum_size = Vector2(210, 0)
	ar_list.item_selected.connect(func(i: int):
		var d := _d(ar_list.get_item_metadata(i))
		selected_archive = _s(d, "path")
		_show_archive(d))
	split.add_child(ar_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar_meta = _label("", C_DIM, -2, true)
	right.add_child(ar_meta)
	ar_body = _plain_text()
	right.add_child(ar_body)
	split.add_child(right)
	return split


func _refresh_archive(v: Dictionary) -> void:
	ar_list.clear()
	var sel := -1
	for a in _a(v, "archive"):
		var d := _d(a)
		var i := ar_list.add_item(_s(d, "name", _s(d, "path")))
		ar_list.set_item_metadata(i, d)
		if _s(d, "path") == selected_archive:
			sel = i
	if ar_list.item_count == 0:
		selected_archive = ""
		ar_meta.text = "보관된 자료 0건"
		_set_plain(ar_body, "아직 회수한 자료가 없습니다.\n의뢰 대상 자료의 사본을 회수하면 내용과 출처가 이곳에 표시됩니다.")
		return
	if sel < 0:
		sel = ar_list.item_count - 1
		selected_archive = _s(_d(ar_list.get_item_metadata(sel)), "path")
	ar_list.select(sel)
	_show_archive(_d(ar_list.get_item_metadata(sel)))


func _show_archive(d: Dictionary) -> void:
	var meta := "경로  %s\n출처  %s" % [_s(d, "path"), _s(d, "source", "기록 없음")]
	if not _s(d, "record_id").is_empty():
		meta += "\n기록  " + _s(d, "record_id")
	if meta == ar_meta.text:
		return
	ar_meta.text = meta
	_set_plain(ar_body, _s(d, "content"))


# ── 사건/네트워크 ─────────────────────────────────────────────

func _build_status() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	st_mission = _label("", C_TEXT, 0)
	st_goal = _label("", C_DIM, -2, true)
	st_conn = _label("", C_CYAN, -2)
	st_alert = _label("", C_DIM, -2)
	st_done = _label("", C_DIM, -2)
	for l in [st_mission, st_goal, st_conn, st_alert, st_done]:
		col.add_child(l)
	net_map = NetMap.new()
	net_map.custom_minimum_size = Vector2(0, 110)
	net_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	net_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(net_map)
	return col


func _alert_text(v: Dictionary) -> String:
	var al := _i(v, "alert_level")
	var mx := maxi(_i(v, "alert_max", 3), 1)
	return "경보 %s%s %d/%d" % ["■".repeat(mini(al, mx)), "□".repeat(maxi(mx - al, 0)), al, mx]


func _refresh_status(v: Dictionary) -> void:
	st_mission.text = _s(v, "mission_title")
	st_goal.text = "목표 · " + _s(v, "mission_goal")
	st_conn.text = "세션 · %s@%s  %s" % [_s(v, "user"), _s(v, "host"), _s(v, "cwd")]
	var al := _i(v, "alert_level")
	st_alert.text = _alert_text(v) + ("  · 서버가 거절된 시도를 기록 중" if al > 0 else "  · 관찰된 위험 없음")
	st_alert.add_theme_color_override("font_color", C_AMBER if al > 0 else C_DIM)
	var done := _b(v, "completed")
	st_done.text = "상태 · 의뢰 완료" if done else "상태 · 진행 중"
	st_done.add_theme_color_override("font_color", C_CYAN if done else C_DIM)
	net_map.nodes = _a(v, "network")
	net_map.current = _s(v, "host")
	net_map.queue_redraw()


# ── 도움말 ────────────────────────────────────────────────────

func _build_help() -> Control:
	var col := VBoxContainer.new()
	hp_goal = _label("", C_CYAN, -2, true)
	col.add_child(hp_goal)
	var row := HBoxContainer.new()
	row.add_child(_btn("터미널에서 help 실행", "게임의 명령 도움말을 터미널에 출력", func():
		_open_app("terminal", true)
		if _ready_ok():
			_run_command("help", "도움말")))
	hp_hint_btn = _btn("현재 단서 보기", "선택 사항 · 정답을 실행하지는 않습니다", func():
		hp_hint.visible = not hp_hint.visible
		hp_hint_btn.text = "단서 숨기기" if hp_hint.visible else "현재 단서 보기")
	row.add_child(hp_hint_btn)
	col.add_child(row)
	hp_hint = _label("", C_AMBER, -2, true)
	hp_hint.visible = false
	col.add_child(hp_hint)
	var guide := _plain_text()
	guide.add_text(HELP_TEXT)
	col.add_child(guide)
	return col


func _refresh_help(v: Dictionary) -> void:
	hp_goal.text = "현재 목표 · " + _s(v, "mission_goal")
	var hint := _s(v, "hint")
	hp_hint.text = hint if not hint.is_empty() else "지금 표시할 단서가 없습니다."


# ── 전체 갱신 ─────────────────────────────────────────────────

func _refresh_all(v: Dictionary) -> void:
	last_view = v
	pw_pending = _b(v, "password_pending")
	mission_label.text = _s(v, "mission_title")
	var al := _i(v, "alert_level")
	alert_label.text = _alert_text(v)
	alert_label.add_theme_color_override("font_color", C_AMBER if al > 0 else C_DIM)
	_refresh_save_mode()
	host_label.text = "M01 / " + ("LOCAL" if _is_local(v) else _s(v, "host").to_upper())

	term_in.secret = pw_pending
	term_prompt.text = "암호 (가림)" if pw_pending else _s(v, "prompt", "$")
	term_prompt.add_theme_color_override("font_color", C_AMBER if pw_pending else C_CYAN)
	term_in.placeholder_text = "암호 입력 · 화면과 기록에 남지 않음" if pw_pending else "명령 입력 · help · Tab 완성 · ↑↓ 기록"
	term_header.text = "세션  %s@%s  ·  %s" % [_s(v, "user"), _s(v, "host"), _s(v, "cwd")]

	_refresh_mail(v)
	_refresh_files(v)
	_refresh_archive(v)
	_refresh_status(v)
	_refresh_help(v)
	_update_taskbar()


# ── 저장/불러오기/새 작업 ─────────────────────────────────────

func _ask(text: String, action: Callable) -> void:
	if not _ready_ok():
		return
	confirm.dialog_text = text
	confirm_action = action
	confirm.popup_centered(Vector2i(560, 0))


func _report_io(r: Dictionary, what: String) -> bool:
	var ok := _b(r, "ok", false)
	var t := _s(r, "text")
	if ok:
		autosave_paused = false
		fresh_save_btn.visible = false
		recover_btn.visible = false
	else:
		if _s(r, "code") != "SAVE_NOT_FOUND" or _b(r, "backup_available"):
			autosave_paused = true
		recover_btn.visible = _b(r, "backup_available")
		fresh_save_btn.visible = r.has("backup_available") and (_s(r, "code") != "SAVE_NOT_FOUND" or _b(r, "backup_available"))
	_refresh_save_mode()
	if ok:
		_toast("%s 완료%s" % [what, (" · " + t) if not t.is_empty() else ""], C_CYAN)
	else:
		_toast("%s 실패 · %s%s" % [what, _s(r, "code", "UNKNOWN"), ("\n" + t) if not t.is_empty() else ""], C_AMBER)
	_term_line("[%s] %s" % [what, t if not t.is_empty() else ("완료" if ok else _s(r, "code"))], C_DIM if ok else C_AMBER)
	return ok


func _refresh_save_mode() -> void:
	if autosave_label == null:
		return
	autosave_label.text = "자동저장 일시중지" if autosave_paused else "자동저장 ON"
	autosave_label.add_theme_color_override("font_color", C_AMBER if autosave_paused else C_CYAN_DIM)
	autosave_label.tooltip_text = "이전 디스크 진행을 보존 중입니다. [저장] 성공 시 현재 진행으로 대체하고 자동저장을 재개합니다." if autosave_paused else "상태가 바뀌면 현재 슬롯에 자동 저장합니다."


func _save() -> void:
	if _ready_ok():
		_report_io(_d(game.save_game()), "저장")


func _ask_load() -> void:
	_ask("마지막 저장으로 되돌립니다.\n저장하지 않은 현재 진행은 사라집니다.", _load)


func _load() -> void:
	var r := _d(game.load_game())
	var ok := _report_io(r, "불러오기")
	var code := _s(r, "code").to_upper()
	recover_btn.visible = not ok and (_b(r, "backup_available") or "CORRUPT" in code or "BACKUP" in code)
	if ok:
		_world_replaced("── 저장에서 복원 ──")


func _ask_recover() -> void:
	_ask("손상된 저장본은 별도로 보존하고, 정상 백업으로 복구합니다.", _recover)


func _recover() -> void:
	if _report_io(_d(game.recover_save()), "백업 복구"):
		recover_btn.visible = false
		_world_replaced("── 백업에서 복원 ──")


func _ask_fresh_save() -> void:
	_ask("기존 손상 저장·백업은 별도 파일로 보존하고, 현재 진행을 새 저장으로 기록합니다.\n현재 진행은 초기화하지 않습니다.", _fresh_save)


func _fresh_save() -> void:
	_report_io(_d(game.start_new_save()), "손상본 보존·새 저장")


func _ask_reset() -> void:
	_ask("진행 중인 M01 세계만 처음 상태로 되돌립니다.\n디스크의 이전 진행을 보존하며 자동저장을 일시중지합니다.\n[저장]을 누르면 현재 진행으로 대체하고 자동저장을 재개합니다.", _reset)


func _reset() -> void:
	game.reset()
	autosave_paused = true
	_refresh_save_mode()
	_toast("새 작업 · 세계 초기화 · 자동저장 일시중지 · 저장 선택 전까지 이전 진행 유지", C_TEXT)
	_world_replaced("── 새 작업: M01 초기 상태 ──")


func _world_replaced(banner: String) -> void:
	var v := _view()
	if v.is_empty() or not _b(v, "ready", true):
		_show_fatal(_s(v, "error", "코어가 화면 정보를 반환하지 않았습니다."))
		return
	_term_line(banner, C_DIM)
	br_history.clear()
	br_cursor = -1
	br_url = ""
	br_failed = false
	br_opened = false
	selected_archive = ""
	shown_mail_key = ""
	_refresh_all(v)
	if wins["browser"]["state"] != "closed":
		br_opened = true
		_navigate(_s(v, "browser_home", ""), true)
	else:
		_update_nav()


# ── 그리기 전용 보조 Control ──────────────────────────────────

class Backdrop extends Control:
	const PTS := [Vector2(0.06, 0.80), Vector2(0.20, 0.64), Vector2(0.34, 0.72), Vector2(0.52, 0.56),
			Vector2(0.68, 0.67), Vector2(0.83, 0.47), Vector2(0.95, 0.58)]

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.066, 0.08))
		var g := Color(0.42, 0.62, 0.66, 0.045)
		var step := 40.0
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), g, 1.0)
			x += step
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), g, 1.0)
			y += step
		var line := Color(0.40, 0.82, 0.80, 0.08)
		for i in PTS.size() - 1:
			draw_line(PTS[i] * size, PTS[i + 1] * size, line, 1.0, true)
		draw_line(PTS[1] * size, Vector2(0.28, 0.42) * size, line, 1.0, true)
		draw_line(PTS[4] * size, Vector2(0.74, 0.86) * size, line, 1.0, true)
		for p in PTS:
			draw_circle(p * size, 3.0, Color(0.40, 0.82, 0.80, 0.16))
		draw_circle(PTS[5] * size, 3.5, Color(0.95, 0.68, 0.32, 0.20))


class NetMap extends Control:
	var nodes: Array = []
	var current := ""

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	static func _status_color(st: String) -> Color:
		var s := st.to_lower()
		for k in ["denied", "alert", "block", "refus", "lock", "거부", "차단", "경보"]:
			if k in s:
				return Color(0.95, 0.68, 0.32)
		for k in ["connect", "session", "access", "online", "active", "open", "접속", "연결"]:
			if k in s:
				return Color(0.40, 0.82, 0.80)
		return Color(0.45, 0.53, 0.57)

	func _draw() -> void:
		var font := get_theme_default_font()
		var fs := maxi(get_theme_default_font_size() - 3, 11)
		var text := Color(0.83, 0.88, 0.89)
		var dim := Color(0.53, 0.61, 0.64)
		var cyan := Color(0.40, 0.82, 0.80)
		var local := Vector2(40, size.y * 0.5)
		var n := nodes.size()
		for i in n:
			var d: Dictionary = nodes[i] if nodes[i] is Dictionary else {}
			var p := Vector2(size.x * 0.42, size.y * (i + 1) / float(n + 1))
			var st := str(d.get("status", ""))
			var col := _status_color(st)
			var here := current != "" and (current == str(d.get("id", "")) or current == str(d.get("address", "")) or current == str(d.get("name", "")))
			if here:
				draw_line(local, p, cyan, 2.0, true)
				draw_arc(p, 12.0, 0.0, TAU, 32, cyan, 1.5, true)
			else:
				draw_dashed_line(local, p, Color(col, 0.7), 1.0, 6.0)
			draw_circle(p, 6.0, col)
			var w := maxf(size.x - p.x - 24.0, 40.0)
			draw_string(font, p + Vector2(20, -3), str(d.get("name", d.get("id", "?"))), HORIZONTAL_ALIGNMENT_LEFT, w, fs, text)
			draw_string(font, p + Vector2(20, fs + 1), "%s · %s" % [str(d.get("address", "")), st], HORIZONTAL_ALIGNMENT_LEFT, w, fs - 1, dim)
		draw_circle(local, 8.0, cyan)
		draw_string(font, local + Vector2(-26, 26), "LOCAL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, cyan)
		if n == 0:
			draw_string(font, Vector2(80, local.y + 5), "알려진 원격 노드 없음", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
