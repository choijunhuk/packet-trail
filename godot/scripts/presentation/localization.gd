class_name PacketLocalization
extends RefCounted
## Presentation only: canonical commands, paths, credentials and save data never enter this API.

const LOCALES := ["ko", "en", "ja", "zh_Hans", "es", "de"]
const PRIMARY_FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const JP_FONT = preload("res://assets/fonts/NotoSansJP.ttf")
const SC_FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const MONO_FONT = preload("res://assets/fonts/NotoSansMono.ttf")
static var _configured := false
static var _font: Font
static var _mono_font: Font


static func configure(locale: String = "ko") -> bool:
	if not _configured:
		for code in LOCALES:
			var resource := load("res://locales/%s.po" % code) as Translation
			if resource == null:
				push_error("Missing translation resource: %s" % code)
				return false
			TranslationServer.add_translation(resource)
		_font = install_font_fallbacks(PRIMARY_FONT)
		_configured = true
	return set_locale(locale)


static func set_locale(locale: String) -> bool:
	if locale not in LOCALES:
		return false
	TranslationServer.set_locale(locale)
	return true


static func get_locale() -> String:
	return TranslationServer.get_locale()


static func tr_key(key: String, replacements: Dictionary = {}) -> String:
	var translated := str(TranslationServer.translate(key))
	return translated.format(replacements) if not replacements.is_empty() else translated


static func get_font() -> Font:
	if _font == null:
		_font = install_font_fallbacks(PRIMARY_FONT)
	return _font


static func get_mono_font() -> Font:
	if _mono_font == null:
		_mono_font = MONO_FONT
		var fallbacks: Array[Font] = [get_font()]
		_mono_font.fallbacks = fallbacks
	return _mono_font


static func install_font_fallbacks(font: Font) -> Font:
	if font == null:
		return null
	var fallbacks: Array[Font] = font.fallbacks.duplicate()
	for fallback in [JP_FONT, SC_FONT]:
		if fallback != font and not fallbacks.has(fallback):
			fallbacks.append(fallback)
	font.fallbacks = fallbacks
	return font
