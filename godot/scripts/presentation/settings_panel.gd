extends PanelContainer

signal closed
signal applied(values: Dictionary)

const Localization = preload("res://scripts/presentation/localization.gd")
const FALLBACK := {
	"SETTINGS_TITLE": "환경 설정", "SETTINGS_AUDIO": "음향", "SETTINGS_DISPLAY": "화면과 편안함",
	"MASTER_VOLUME": "전체 음량", "MUSIC_VOLUME": "음악", "SFX_VOLUME": "효과음",
	"UI_VOLUME": "인터페이스", "AMBIENCE_VOLUME": "빗소리·환경음", "FONT_SCALE": "글자 크기",
	"KEYBOARD_VOLUME": "키보드 소리", "TOOL_VOLUME": "도구 소리", "NOTIFICATION_VOLUME": "알림 소리",
	"MOUSE_SENSITIVITY": "마우스 감도", "REDUCED_MOTION": "움직임 줄이기",
	"COMFORT_MODE": "편안한 이동 · 좁은 시야각", "FULLSCREEN": "전체 화면",
	"BACKGROUND_AUDIO": "다른 창을 사용할 때도 소리 재생", "LANGUAGE": "언어",
	"APPLY_SETTINGS": "적용하고 저장", "CANCEL": "취소", "RESET_CONTROLS": "조작 기본값",
	"SETTINGS_SAVED": "설정을 저장했습니다.", "SETTINGS_NOT_SAVED": "설정을 저장하지 못했습니다.",
}
var store
var controls: Dictionary = {}
var status: Label
var body: VBoxContainer


func _text(key: String) -> String:
	var value := TranslationServer.translate(key)
	return FALLBACK.get(key, key) if value == key else value


func setup(settings: RefCounted) -> void:
	store = settings
	var theme_value := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = Localization.get_font()
	readable_font.variation_embolden = 0.35
	theme_value.default_font = readable_font
	theme_value.default_font_size = roundi(18.0 * store.get_values()["font_scale"])
	theme = theme_value
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111d27")
	style.border_color = Color("49646c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	add_theme_stylebox_override("panel", style)
	_build()


func _build() -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	add_child(outer)
	var title := Label.new()
	title.text = _text("SETTINGS_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var values: Dictionary = store.get_values()
	for key in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume", "keyboard_volume", "tool_volume", "notification_volume", "font_scale", "mouse_sensitivity"]:
		var line := VBoxContainer.new()
		body.add_child(line)
		var label := Label.new()
		label.text = _text(key.to_upper())
		line.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		if key == "font_scale":
			slider.min_value = 0.85
			slider.max_value = 1.6
		elif key == "mouse_sensitivity":
			slider.min_value = 0.03
			slider.max_value = 0.5
		slider.value = values[key]
		slider.custom_minimum_size.y = 28
		slider.accessibility_name = label.text
		line.add_child(slider)
		controls[key] = slider
	for key in ["reduced_motion", "comfort_mode", "fullscreen", "background_audio"]:
		var row := HBoxContainer.new()
		body.add_child(row)
		var check := CheckBox.new()
		check.accessibility_name = _text(key.to_upper())
		check.button_pressed = values[key]
		row.add_child(check)
		var label := Label.new()
		label.text = _text(key.to_upper())
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		controls[key] = check
	var language := OptionButton.new()
	for value in ["한국어", "English", "日本語", "简体中文", "Español", "Deutsch"]:
		language.add_item(value)
	language.selected = store.LOCALES.find(values["locale"])
	language.accessibility_name = _text("LANGUAGE")
	body.add_child(language)
	controls["locale"] = language
	var reset := Button.new()
	reset.text = _text("RESET_CONTROLS")
	reset.pressed.connect(func():
		controls["mouse_sensitivity"].value = store.DEFAULTS["mouse_sensitivity"]
		controls["comfort_mode"].button_pressed = true)
	body.add_child(reset)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status)
	var actions := HBoxContainer.new()
	outer.add_child(actions)
	var cancel := Button.new()
	cancel.text = _text("CANCEL")
	cancel.pressed.connect(func(): closed.emit())
	actions.add_child(cancel)
	var apply := Button.new()
	apply.text = _text("APPLY_SETTINGS")
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(_apply)
	actions.add_child(apply)
	var focusable: Array[Control] = []
	_collect_focus(self, focusable)
	for index in range(focusable.size()):
		focusable[index].focus_next = focusable[(index + 1) % focusable.size()].get_path()
		focusable[index].focus_previous = focusable[(index - 1 + focusable.size()) % focusable.size()].get_path()
	cancel.grab_focus()


func _collect_focus(node: Node, output: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			output.append(child)
		_collect_focus(child, output)


func _apply() -> void:
	var patch := {}
	for key in controls:
		var control: Control = controls[key]
		if control is HSlider:
			patch[key] = control.value
		elif control is CheckBox:
			patch[key] = control.button_pressed
		else:
			patch[key] = store.LOCALES[control.selected]
	var result: Dictionary = store.update_settings(patch)
	if not result["ok"]:
		status.text = _text("SETTINGS_NOT_SAVED") + " " + result.get("error", "")
		return
	applied.emit(result["values"])
	closed.emit()
