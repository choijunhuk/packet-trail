extends RefCounted
## Shared native widgets for the fictional desktop, lobby and preferences.

const Localization = preload("res://scripts/presentation/localization.gd")

const BG := Color("151617")
const SURFACE := Color("232426")
const RAISED := Color("303235")
const FIELD := Color("17191b")
const LINE := Color("51565c")
const TEXT := Color("f3f1ed")
const MUTED := Color("b9bbb9")
const ACCENT := Color("85d1c7")
const ACCENT_SOFT := Color("b5e4dc")
const SUCCESS := Color("8bd4b3")
const WARNING := Color("f1bd71")



## Identity colors are independent from success, warning and failure feedback.
static func app_accent(id: String) -> Color:
	if id.begins_with("term"):
		return Color("9cddb8")
	match id:
		"tools", "requestlab", "status": return Color("82d7cc")
		"mail": return Color("edb58f")
		"browser": return Color("c4b3ed")
		"files", "archive": return Color("a7c8f0")
		"board", "ending": return Color("dec48c")
		_: return Color("c3c8ce")


static func app_surface(id: String) -> Color:
	return SURFACE.lerp(app_accent(id), 0.055)


static func panel(fill: Color = SURFACE, border: Color = LINE, radius: int = 6, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


static func create(font_scale: float = 1.0, accent: Color = ACCENT) -> Theme:
	var value := Theme.new()
	var readable := FontVariation.new()
	readable.base_font = Localization.get_font()
	readable.variation_embolden = 0.35
	value.default_font = readable
	value.default_font_size = roundi(17.0 * font_scale)
	value.set_color("font_color", "Label", TEXT)
	value.set_color("default_color", "RichTextLabel", TEXT)
	value.set_color("font_color", "CheckBox", TEXT)
	value.set_color("button_pressed_color", "CheckBox", accent)
	value.set_color("font_hover_color", "CheckBox", TEXT)
	value.set_constant("separation", "VBoxContainer", 10)
	value.set_constant("separation", "HBoxContainer", 10)
	value.set_stylebox("panel", "PanelContainer", panel())
	var normal := panel(RAISED)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := panel(RAISED.lerp(accent, 0.14), accent)
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	var pressed := panel(SURFACE.lerp(accent, 0.22), accent)
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8
	var focus := panel(Color.TRANSPARENT, accent)
	focus.set_border_width_all(2)
	var disabled := panel(Color("222426"), Color("45494e"))
	for widget in ["Button", "OptionButton", "MenuButton"]:
		value.set_stylebox("normal", widget, normal)
		value.set_stylebox("hover", widget, hover)
		value.set_stylebox("pressed", widget, pressed)
		value.set_stylebox("focus", widget, focus)
		value.set_stylebox("disabled", widget, disabled)
		value.set_color("font_color", widget, TEXT)
		value.set_color("font_hover_color", widget, TEXT)
		value.set_color("font_pressed_color", widget, TEXT)
		value.set_color("font_disabled_color", widget, MUTED)
	for widget in ["LineEdit", "TextEdit"]:
		value.set_stylebox("normal", widget, panel(FIELD))
		value.set_stylebox("focus", widget, panel(FIELD, accent))
		value.set_color("font_color", widget, TEXT)
		value.set_color("font_placeholder_color", widget, MUTED)
		value.set_color("caret_color", widget, TEXT)
		value.set_color("selection_color", widget, SURFACE.lerp(accent, 0.25))
	for widget in ["Tree", "ItemList"]:
		value.set_stylebox("panel", widget, panel(FIELD))
		value.set_stylebox("selected", widget, panel(SURFACE.lerp(accent, 0.22), accent, 3, 4))
		value.set_stylebox("selected_focus", widget, panel(SURFACE.lerp(accent, 0.22), accent, 3, 4))
		value.set_color("font_color", widget, TEXT)
		value.set_color("font_selected_color", widget, TEXT)
		value.set_color("font_hovered_color", widget, TEXT)
		value.set_color("guide_color", widget, LINE)
	var popup := panel(Color("27292c"), LINE, 8, 8)
	popup.shadow_color = Color(0, 0, 0, 0.35)
	popup.shadow_size = 8
	popup.shadow_offset = Vector2(0, 4)
	value.set_stylebox("panel", "PopupMenu", popup)
	value.set_stylebox("hover", "PopupMenu", panel(SURFACE.lerp(accent, 0.22), Color.TRANSPARENT, 4, 6))
	value.set_color("font_color", "PopupMenu", TEXT)
	value.set_color("font_hover_color", "PopupMenu", TEXT)
	value.set_constant("v_separation", "PopupMenu", 10)
	value.set_stylebox("panel", "TabContainer", panel(SURFACE, LINE, 6, 14))
	value.set_stylebox("tab_selected", "TabBar", panel(RAISED, accent, 5, 10))
	value.set_stylebox("tab_unselected", "TabBar", panel(FIELD, LINE, 5, 10))
	value.set_color("font_selected_color", "TabBar", TEXT)
	value.set_color("font_unselected_color", "TabBar", MUTED)
	for widget in ["VScrollBar", "HScrollBar"]:
		value.set_stylebox("scroll", widget, panel(FIELD, Color.TRANSPARENT, 4, 2))
		value.set_stylebox("grabber", widget, panel(Color("747c82"), Color.TRANSPARENT, 4, 5))
		value.set_stylebox("grabber_highlight", widget, panel(Color("a5adb1"), Color.TRANSPARENT, 4, 5))
		value.set_stylebox("grabber_pressed", widget, panel(accent, Color.TRANSPARENT, 4, 5))
	return value
