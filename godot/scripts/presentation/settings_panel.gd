extends PanelContainer

signal closed
signal applied(values: Dictionary)
signal desktop_effects_preview_requested

const Localization = preload("res://scripts/presentation/localization.gd")
const DesktopTheme = preload("res://scripts/presentation/desktop_theme.gd")
const FALLBACK := {
	"CAMPAIGN_CHALLENGE": "종합 도전",
	"LOBBY_CHOOSE_STORY": "오늘 밤, 어느 쪽에 설까요?",
	"LOBBY_ROLE_INTRUDER": "단서를 따라 침투하고 감춰진 기록을 회수합니다.",
	"LOBBY_ROLE_DEFENDER": "위협을 막으면서 시민과 동료의 업무를 지킵니다.",
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
	"SETTINGS_TITLE": "환경 설정", "SETTINGS_AUDIO": "음향", "SETTINGS_DISPLAY": "화면과 편안함",
	"MASTER_VOLUME": "전체 음량", "MUSIC_VOLUME": "음악", "SFX_VOLUME": "효과음",
	"UI_VOLUME": "인터페이스", "AMBIENCE_VOLUME": "빗소리·환경음", "FONT_SCALE": "글자 크기",
	"KEYBOARD_VOLUME": "키보드 소리", "TOOL_VOLUME": "도구 소리", "NOTIFICATION_VOLUME": "알림 소리",
	"MOUSE_SENSITIVITY": "마우스 감도", "REDUCED_MOTION": "움직임 줄이기",
	"COMFORT_MODE": "편안한 이동 · 좁은 시야각", "FULLSCREEN": "전체 화면",
	"BACKGROUND_AUDIO": "다른 창을 사용할 때도 소리 재생", "LANGUAGE": "언어",
	"SETTINGS_DESKTOP_EFFECTS": "실제 게임 창 연출 (선택)",
	"SETTINGS_DESKTOP_EFFECTS_NOTE": "게임 창 제목과 위치만 잠깐 바뀝니다. 켜고 적용한 뒤 설정을 다시 열어 미리 보세요. Esc로 건너뛸 수 있습니다. 움직임 줄이기에서는 제목만 바뀝니다.",
	"SETTINGS_DESKTOP_EFFECTS_PREVIEW": "게임 창 연출 미리 보기",
	"APPLY_SETTINGS": "적용하고 저장", "CANCEL": "취소", "RESET_CONTROLS": "조작 기본값",
	"SETTINGS_SAVED": "설정을 저장했습니다.", "SETTINGS_NOT_SAVED": "설정을 저장하지 못했습니다.",
}
var store
var controls: Dictionary = {}
var status: Label
var body: VBoxContainer
var tabs: TabContainer
var cancel_button: Button
var apply_button: Button
var _initial_values: Dictionary = {}


func _text(key: String, replacements: Dictionary = {}) -> String:
	var value := str(TranslationServer.translate(key))
	return str(FALLBACK.get(key, key) if value == key else value).format(replacements)


func setup(settings: RefCounted, initial_values: Dictionary = {}) -> void:
	store = settings
	_initial_values = store.get_values() if initial_values.is_empty() else initial_values.duplicate(true)
	theme = DesktopTheme.create(float(_initial_values["font_scale"]))
	add_theme_stylebox_override("panel", DesktopTheme.panel(DesktopTheme.SURFACE, DesktopTheme.LINE, 10, 22))
	_build()


func _build() -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	add_child(outer)
	var title := Label.new()
	title.text = _text("SETTINGS_TITLE")
	title.add_theme_font_size_override("font_size", roundi(27.0 * _initial_values["font_scale"]))
	outer.add_child(title)
	tabs = TabContainer.new()
	tabs.set_meta("settings_tabs", true)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.clip_tabs = true
	outer.add_child(tabs)
	var values: Dictionary = _initial_values
	var play := _tab("SETTINGS_PLAY")
	var scope := Label.new()
	scope.text = _text("SUPPORT_SCOPE")
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope.add_theme_color_override("font_color", DesktopTheme.MUTED)
	play.add_child(scope)
	for id in ["intruder", "defender", "tracker", "challenge", "investigation"]:
		var label := Label.new()
		label.text = _text("SETTINGS_SUPPORT_FOR", {"campaign": _text("CAMPAIGN_" + id.to_upper())})
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		play.add_child(label)
		var choice := OptionButton.new()
		choice.accessibility_name = label.text
		choice.set_meta("setting_key", "support_" + id)
		for level in ["guided", "standard", "independent"]:
			choice.add_item(_text("SUPPORT_" + level.to_upper()))
			choice.set_item_metadata(choice.item_count - 1, level)
		choice.select(["guided", "standard", "independent"].find(str(values.get("support_" + id, "standard"))))
		play.add_child(choice)
		controls["support_" + id] = choice
	var display := _tab("SETTINGS_DISPLAY_TAB")
	var language_label := Label.new()
	language_label.text = _text("LANGUAGE")
	display.add_child(language_label)
	var language := OptionButton.new()
	var names := ["한국어", "English", "日本語", "简体中文", "Español", "Deutsch"]
	for index in range(store.LOCALES.size()):
		language.add_item(names[index])
		language.set_item_metadata(index, store.LOCALES[index])
	language.select(store.LOCALES.find(values["locale"]))
	language.accessibility_name = _text("LANGUAGE")
	language.set_meta("setting_key", "locale")
	display.add_child(language)
	controls["locale"] = language
	_slider(display, "font_scale", values, 0.85, 1.6)
	for key in ["fullscreen", "reduced_motion"]:
		_checkbox(display, key, values)
	_checkbox(display, "desktop_effects", values)
	controls["desktop_effects"].text = _text("SETTINGS_DESKTOP_EFFECTS")
	controls["desktop_effects"].accessibility_name = _text("SETTINGS_DESKTOP_EFFECTS")
	var effects_note := Label.new()
	effects_note.text = _text("SETTINGS_DESKTOP_EFFECTS_NOTE")
	effects_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_note.add_theme_color_override("font_color", DesktopTheme.MUTED)
	display.add_child(effects_note)
	var preview := Button.new()
	preview.text = _text("SETTINGS_DESKTOP_EFFECTS_PREVIEW")
	preview.set_meta("settings_action", "desktop_effects_preview")
	preview.disabled = not bool(values.get("desktop_effects", false))
	controls["desktop_effects"].toggled.connect(func(enabled: bool):
		preview.disabled = not enabled or not bool(_initial_values.get("desktop_effects", false)))
	preview.pressed.connect(func(): desktop_effects_preview_requested.emit())
	display.add_child(preview)
	var audio := _tab("SETTINGS_AUDIO_TAB")
	for key in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume"]:
		_slider(audio, key, values)
	var details := Label.new()
	details.text = _text("SETTINGS_AUDIO_DETAILS")
	details.add_theme_color_override("font_color", DesktopTheme.MUTED)
	audio.add_child(details)
	for key in ["keyboard_volume", "tool_volume", "notification_volume"]:
		_slider(audio, key, values)
	_checkbox(audio, "background_audio", values)
	var input := _tab("SETTINGS_CONTROLS_TAB")
	var note := Label.new()
	note.text = _text("SETTINGS_CONTROLS_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", DesktopTheme.MUTED)
	input.add_child(note)
	_slider(input, "mouse_sensitivity", values, 0.03, 0.5)
	_checkbox(input, "comfort_mode", values)
	var reset := Button.new()
	reset.text = _text("RESET_CONTROLS")
	reset.set_meta("settings_action", "reset_controls")
	reset.pressed.connect(func():
		controls["mouse_sensitivity"].value = store.DEFAULTS["mouse_sensitivity"]
		controls["comfort_mode"].button_pressed = true)
	input.add_child(reset)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", DesktopTheme.WARNING)
	outer.add_child(status)
	var actions := HBoxContainer.new()
	outer.add_child(actions)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	cancel_button = Button.new()
	cancel_button.text = _text("CANCEL")
	cancel_button.set_meta("settings_action", "cancel")
	cancel_button.pressed.connect(func(): closed.emit())
	actions.add_child(cancel_button)
	apply_button = Button.new()
	apply_button.text = _text("APPLY_SETTINGS")
	apply_button.set_meta("settings_action", "apply")
	apply_button.pressed.connect(_apply)
	actions.add_child(apply_button)
	tabs.tab_changed.connect(func(_index: int): call_deferred("_refresh_focus_chain"))
	_refresh_focus_chain()
	cancel_button.grab_focus()


func _tab(key: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = _text(key)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	if body == null:
		body = column
	return column


func _slider(parent: VBoxContainer, key: String, values: Dictionary, minimum := 0.0, maximum := 1.0) -> void:
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	parent.add_child(line)
	var header := HBoxContainer.new()
	line.add_child(header)
	var label := Label.new()
	label.text = _text(key.to_upper())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(label)
	var amount := Label.new()
	amount.add_theme_color_override("font_color", DesktopTheme.ACCENT_SOFT)
	header.add_child(amount)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = float(values[key])
	slider.custom_minimum_size.y = 28
	slider.accessibility_name = label.text
	slider.set_meta("setting_key", key)
	var update := func(value: float): amount.text = ("%.2f" % value) if key == "mouse_sensitivity" else ("%d%%" % roundi(value * 100.0))
	slider.value_changed.connect(update)
	update.call(slider.value)
	line.add_child(slider)
	controls[key] = slider


func _checkbox(parent: VBoxContainer, key: String, values: Dictionary) -> void:
	var check := CheckBox.new()
	check.text = _text(key.to_upper())
	check.accessibility_name = check.text
	check.button_pressed = bool(values[key])
	check.set_meta("setting_key", key)
	parent.add_child(check)
	controls[key] = check


func _collect_focus(node: Node, output: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			output.append(child)
		_collect_focus(child, output)


func _refresh_focus_chain() -> void:
	var focusable: Array[Control] = []
	var category_bar := tabs.get_tab_bar()
	category_bar.focus_mode = Control.FOCUS_ALL
	focusable.append(category_bar)
	_collect_focus(self, focusable)
	for index in range(focusable.size()):
		focusable[index].focus_next = focusable[(index + 1) % focusable.size()].get_path()
		focusable[index].focus_previous = focusable[(index - 1 + focusable.size()) % focusable.size()].get_path()


func _apply() -> void:
	var patch := {}
	for key in controls:
		var control: Control = controls[key]
		if control is HSlider:
			patch[key] = control.value
		elif control is CheckBox:
			patch[key] = control.button_pressed
		elif control is OptionButton:
			patch[key] = control.get_item_metadata(control.selected)
	var result: Dictionary = store.update_settings(patch)
	if not result.get("ok", false):
		status.text = _text("SETTINGS_NOT_SAVED") + " " + str(result.get("error", ""))
		return
	applied.emit(result["values"])
	closed.emit()
