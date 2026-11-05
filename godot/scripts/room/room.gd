extends Node3D

signal desktop_requested(action: String)
signal room_entered
signal settings_changed(values: Dictionary)
signal application_focus_changed(active: bool)

const Store = preload("res://scripts/presentation/settings_store.gd")
const SettingsPanel = preload("res://scripts/presentation/settings_panel.gd")
const StudioWorld = preload("res://scripts/room/studio_world.gd")
const Localization = preload("res://scripts/presentation/localization.gd")
const FALLBACK := {
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
}

@export var desktop_scene: PackedScene
@export var desktop_save_slot_path := "user://saves/campaign_01.json"
@export var has_saved_session := false
@export var has_legacy_session := false
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
var _pending_action := "new"


func _text(key: String) -> String:
	var translated := TranslationServer.translate(key)
	return FALLBACK.get(key, key) if translated == key else translated


func _ready() -> void:
	settings_store.load_settings()
	Localization.configure(settings_store.get_values()["locale"])
	if DisplayServer.get_name() != "headless":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	settings_store.changed.connect(_apply_settings)
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
		continue_button.disabled = not available and desktop == null
		load_button.disabled = not available


func set_legacy_session_available(available: bool) -> void:
	has_legacy_session = available
	if import_button != null:
		import_button.disabled = not available


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
	var readable_font := FontVariation.new()
	readable_font.base_font = Localization.get_font()
	readable_font.variation_embolden = 0.35
	_theme.default_font = readable_font
	_theme.default_font_size = 20
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
	veil.color = Color(0.025, 0.05, 0.07, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 550
	menu.add_child(veil)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margins.offset_left = 54
	margins.offset_right = 495
	margins.offset_top = 42
	margins.offset_bottom = -35
	menu.add_child(margins)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margins.add_child(scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 13)
	scroll.add_child(menu_box)
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
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("111d27")
	dialog_style.border_color = Color("72b7bc")
	dialog_style.set_border_width_all(1)
	dialog_style.set_corner_radius_all(7)
	dialog_style.content_margin_left = 22
	dialog_style.content_margin_right = 22
	dialog_style.content_margin_top = 22
	dialog_style.content_margin_bottom = 18
	confirm.add_theme_stylebox_override("panel", dialog_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("203d48")
	button_style.set_corner_radius_all(4)
	button_style.content_margin_left = 12
	button_style.content_margin_right = 12
	button_style.content_margin_top = 8
	button_style.content_margin_bottom = 8
	for button in [confirm.get_ok_button(), confirm.get_cancel_button()]:
		button.add_theme_stylebox_override("normal", button_style)
	confirm.confirmed.connect(func(): open_desktop(_pending_action))
	overlay.add_child(confirm)


func _rebuild_menu() -> void:
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	var eyebrow := Label.new()
	eyebrow.text = "MIDNIGHT / ACCESS"
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("7fbfc1"))
	menu_box.add_child(eyebrow)
	var title := Label.new()
	title.text = _text("ROOM_TITLE")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 48)
	menu_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _text("ROOM_SUBTITLE")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("a4b7bf"))
	menu_box.add_child(subtitle)
	menu_box.add_child(HSeparator.new())
	continue_button = _button("CONTINUE", func(): open_desktop("continue"))
	_button("NEW_GAME", _confirm_new)
	load_button = _button("LOAD_GAME", func(): open_desktop("load"))
	import_button = _button("IMPORT_LEGACY", _confirm_import)
	_button("ENTER_ROOM", return_to_room)
	_button("SETTINGS", show_settings)
	_button("CREDITS", _show_credits)
	_button("QUIT", func(): get_tree().quit())
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("94a8b2"))
	menu_box.add_child(note)
	set_session_available(has_saved_session)
	set_legacy_session_available(has_legacy_session)


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
	_pending_action = "new"
	confirm.title = _text("NEW_GAME")
	confirm.dialog_text = _text("NEW_GAME_CONFIRM")
	confirm.ok_button_text = _text("START_NEW")
	confirm.cancel_button_text = _text("CANCEL")
	confirm.popup_centered(Vector2i(540, 220))


func _confirm_import() -> void:
	_pending_action = "import"
	confirm.title = _text("IMPORT_LEGACY")
	confirm.dialog_text = _text("IMPORT_CONFIRM")
	confirm.ok_button_text = _text("IMPORT_LEGACY")
	confirm.cancel_button_text = _text("CANCEL")
	confirm.popup_centered(Vector2i(540, 240))


func open_desktop(action := "continue") -> void:
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
		instance.set("save_slot_path", desktop_save_slot_path)
		desktop = instance
		desktop_layer.add_child(desktop)
		desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if desktop.has_method("start_session"):
		var result: Variant = desktop.call("start_session", action)
		if result is Dictionary and not result.get("ok", true):
			show_main_menu()
			note.text = str(result.get("text", _text("DESKTOP_NOT_READY")))
			return
	elif action != "continue":
		show_main_menu()
		note.text = _text("DESKTOP_NOT_READY")
		return
	desktop.visible = true
	desktop.process_mode = Node.PROCESS_MODE_INHERIT
	for window in _desktop_windows:
		if is_instance_valid(window):
			window.show()
	_desktop_windows.clear()
	_in_desktop = true
	# The desktop is opaque; avoid rendering the studio behind its interface.
	studio.hide()
	menu.hide()
	_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hint.text = _text("RETURN_TO_ROOM")
	hint.hide()
	desktop_requested.emit(action)


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
			child.hide()
	desktop.hide()
	desktop.process_mode = Node.PROCESS_MODE_DISABLED


func _focus_menu() -> void:
	for child in menu_box.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break


func show_settings() -> void:
	if settings_panel != null:
		return
	settings_scrim = ColorRect.new()
	settings_scrim.color = Color(0.01, 0.02, 0.03, 0.78)
	settings_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(settings_scrim)
	settings_panel = SettingsPanel.new()
	var viewport := get_viewport().get_visible_rect().size
	var size := Vector2(minf(680, viewport.x - 56), minf(780, viewport.y - 60))
	overlay.add_child(settings_panel)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -size.x * 0.5
	settings_panel.offset_right = size.x * 0.5
	settings_panel.offset_top = -size.y * 0.5
	settings_panel.offset_bottom = size.y * 0.5
	settings_panel.setup(settings_store)
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


func _apply_settings(values: Dictionary) -> void:
	Localization.set_locale(values["locale"])
	_theme.default_font_size = roundi(20.0 * values["font_scale"])
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
		open_desktop("continue")
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
