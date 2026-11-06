extends PanelContainer
## Five player checkpoints. The coordinator owns validation and whole-profile transactions.

signal closed
signal save_requested(index: int)
signal load_requested(index: int)
signal backup_load_requested(index: int)
signal active_recovery_requested

const ThemeSource = preload("res://scripts/presentation/desktop_theme.gd")
const Locale = preload("res://scripts/presentation/localization.gd")
const Catalog = preload("res://scripts/core/campaign_catalog.gd")

var cards: Dictionary = {}
var content: VBoxContainer
var scroll: ScrollContainer
var feedback: Label
var close_button: Button
var confirmation: ConfirmationDialog
var rows: Array = []
var _pending_action := ""
var _pending_index := 0
var _confirm_focus: Control
var _can_save := true
var _recovery_code := ""
var _recovery_status: Dictionary = {}
var active_recovery_button: Button
var _title: Label
var _help: Label


func setup(slot_rows: Array, font_scale: float = 1.0, can_save: bool = true, recovery_code: String = "", recovery_status: Dictionary = {}) -> void:
	_can_save = can_save
	_recovery_code = recovery_code
	_recovery_status = recovery_status.duplicate(true)
	theme = ThemeSource.create(font_scale)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var viewport := get_viewport_rect().size
	var panel_size := Vector2(minf(1000, viewport.x - 48), minf(800, viewport.y - 48))
	offset_left = -panel_size.x * 0.5
	offset_right = panel_size.x * 0.5
	offset_top = -panel_size.y * 0.5
	offset_bottom = panel_size.y * 0.5
	add_theme_stylebox_override("panel", ThemeSource.panel(ThemeSource.SURFACE, ThemeSource.LINE, 8, 18))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	_title = _label("MANUAL_PROFILE_RECOVERY" if not can_save else "MANUAL_SAVES_TITLE")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", roundi(24.0 * font_scale))
	header.add_child(_title)
	close_button = _button("BACK", func(): closed.emit())
	header.add_child(close_button)
	_help = _label("MANUAL_PROFILE_RECOVERY_HELP" if not can_save else "MANUAL_SAVES_HELP")
	outer.add_child(_help)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	feedback = _label("")
	feedback.add_theme_color_override("font_color", ThemeSource.WARNING)
	outer.add_child(feedback)
	confirmation = ConfirmationDialog.new()
	confirmation.theme = theme
	confirmation.dialog_autowrap = true
	confirmation.exclusive = true
	confirmation.cancel_button_text = Locale.tr_key("CANCEL")
	confirmation.confirmed.connect(_on_confirmed)
	confirmation.canceled.connect(_on_canceled)
	add_child(confirmation)
	render(slot_rows, can_save)
	if not recovery_code.is_empty():
		show_result({"ok": false, "code": recovery_code}, "load", 0)
	_grab_initial_focus.call_deferred()


func _grab_initial_focus() -> void:
	if is_inside_tree() and is_instance_valid(close_button) and close_button.is_inside_tree():
		close_button.grab_focus()


func render(slot_rows: Array, can_save: bool = true) -> void:
	var previous := get_viewport().gui_get_focus_owner()
	var previous_index := int(previous.get_meta("manual_slot", 0)) if is_instance_valid(previous) else 0
	var previous_action := str(previous.get_meta("manual_action", "")) if is_instance_valid(previous) else ""
	var position_before := scroll.scroll_vertical
	_can_save = can_save
	_title.text = Locale.tr_key("MANUAL_SAVES_TITLE" if can_save else "MANUAL_PROFILE_RECOVERY")
	_help.text = Locale.tr_key("MANUAL_SAVES_HELP" if can_save else "MANUAL_PROFILE_RECOVERY_HELP")
	rows = slot_rows.duplicate(true)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	cards.clear()
	active_recovery_button = null
	var focus_order: Array[Control] = [close_button]
	if not can_save and _recovery_status.get("available", false):
		content.add_child(_label("MANUAL_ACTIVE_RECOVER_PREVIOUS" if _recovery_status.get("manifest_source", "current") == "backup" else "MANUAL_ACTIVE_RECOVER_CURRENT", {"members": _recovery_members()}))
		active_recovery_button = _button("MANUAL_ACTIVE_RECOVER", _request_active_recovery)
		content.add_child(active_recovery_button)
		focus_order.append(active_recovery_button)
	for index in range(1, 6):
		var row: Dictionary = rows[index - 1] if rows.size() >= index else {"index": index, "status": "damaged"}
		var card := PanelContainer.new()
		card.set_meta("manual_slot", index)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", ThemeSource.panel(ThemeSource.FIELD, ThemeSource.LINE, 6, 14))
		content.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 5)
		card.add_child(body)
		var heading := _label("MANUAL_SLOT", {"slot": index})
		heading.add_theme_color_override("font_color", ThemeSource.ACCENT)
		body.add_child(heading)
		var state := str(row.get("status", "damaged"))
		if state == "valid":
			var pack: Dictionary = Catalog.get_pack(str(row.get("pack_id", "")))
			body.add_child(_label(str(pack.get("title_key", "MANUAL_SLOT_DAMAGED"))))
			body.add_child(_label("MANUAL_CURRENT_MISSION", {"mission": row.get("mission_id", "—")}))
			body.add_child(_label("MANUAL_SLOT_PROGRESS", {"done": row.get("completed", 0), "total": row.get("total", 0)}))
			body.add_child(_label("MANUAL_SLOT_SAVED_AT", {"datetime": _local_time(int(row.get("saved_at", 0)))}))
		else:
			body.add_child(_label("MANUAL_SLOT_EMPTY" if state == "empty" else "MANUAL_SLOT_DAMAGED"))
			if state == "damaged" and not str(row.get("code", "")).is_empty():
				var reason := _label("MANUAL_OPERATION_FAILED", {"code": row.code})
				reason.add_theme_color_override("font_color", ThemeSource.WARNING)
				body.add_child(reason)
		var actions := HBoxContainer.new()
		body.add_child(actions)
		var save := _button("MANUAL_SAVE_ACTION", _request.bind("save", index))
		var load_button := _button("MANUAL_LOAD_ACTION", _request.bind("load", index))
		save.disabled = not can_save
		load_button.disabled = state != "valid"
		for button in [save, load_button]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.set_meta("manual_slot", index)
			button.set_meta("manual_action", "save" if button == save else "load")
			button.accessibility_name = heading.text + " · " + button.text
			actions.add_child(button)
			if not button.disabled:
				focus_order.append(button)
		cards[index] = {"card": card, "save": save, "load": load_button, "row": row}
		if row.get("backup_available", false):
			var backup := _button("MANUAL_SLOT_BACKUP_LOAD", _request.bind("backup", index))
			backup.set_meta("manual_slot", index)
			backup.set_meta("manual_action", "backup")
			body.add_child(backup)
			focus_order.append(backup)
			cards[index]["backup"] = backup
	for index in range(focus_order.size()):
		var control := focus_order[index]
		control.focus_next = control.get_path_to(focus_order[(index + 1) % focus_order.size()])
		control.focus_previous = control.get_path_to(focus_order[posmod(index - 1, focus_order.size())])
	_restore_focus.call_deferred(previous_index, previous_action, position_before)


func _local_time(unix_time: int) -> String:
	var local_seconds := unix_time + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(local_seconds)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute, date.second]


func _request(action: String, index: int) -> void:
	if not cards.has(index) or confirmation.visible:
		return
	var state := str(cards[index].row.get("status", "damaged"))
	if action == "backup" and not cards[index].row.get("backup_available", false):
		return
	if action == "save" and not _can_save or action == "load" and state != "valid":
		return
	if action == "save" and state == "empty":
		save_requested.emit(index)
		return
	_pending_action = action
	_pending_index = index
	_confirm_focus = get_viewport().gui_get_focus_owner()
	confirmation.get_label().custom_minimum_size.x = 0
	confirmation.title = Locale.tr_key("MANUAL_SAVE_ACTION" if action == "save" else ("MANUAL_SLOT_BACKUP_LOAD" if action == "backup" else "MANUAL_LOAD_ACTION"))
	confirmation.dialog_text = Locale.tr_key("MANUAL_OVERWRITE_CONFIRM" if action == "save" else ("MANUAL_SLOT_BACKUP_CONFIRM" if action == "backup" else "MANUAL_LOAD_CONFIRM"), {"slot": index})
	confirmation.ok_button_text = confirmation.title
	confirmation.popup_centered(Vector2i(mini(640, int(get_viewport_rect().size.x) - 48), 0))


func _recovery_members() -> String:
	var names: PackedStringArray = []
	for id in _recovery_status.get("backup_members", []):
		names.append(Locale.tr_key("HAB_TITLE_SHOP" if id == "habitat" else str(Catalog.get_pack(str(id)).get("title_key", ""))))
	return ", ".join(names)


func _request_active_recovery() -> void:
	if confirmation.visible or not _recovery_status.get("available", false):
		return
	_pending_action = "recover"
	_pending_index = 0
	_confirm_focus = get_viewport().gui_get_focus_owner()
	var dialog_width := mini(1000, int(get_viewport_rect().size.x) - 96)
	# The label needs its intended width before text sets the dialog's minimum height.
	confirmation.get_label().custom_minimum_size.x = dialog_width - 48
	confirmation.get_label().size.x = dialog_width - 48
	confirmation.title = Locale.tr_key("MANUAL_ACTIVE_RECOVER")
	confirmation.dialog_text = Locale.tr_key("MANUAL_ACTIVE_RECOVER_CONFIRM") + "\n\n" + Locale.tr_key("MANUAL_ACTIVE_RECOVER_PREVIOUS" if _recovery_status.get("manifest_source", "current") == "backup" else "MANUAL_ACTIVE_RECOVER_CURRENT", {"members": _recovery_members()})
	confirmation.ok_button_text = confirmation.title
	confirmation.popup_centered(Vector2i(dialog_width, 0))


func _on_confirmed() -> void:
	var action := _pending_action
	var index := _pending_index
	_pending_action = ""
	_pending_index = 0
	confirmation.hide()
	if action == "save":
		save_requested.emit(index)
	elif action == "load":
		load_requested.emit(index)
	elif action == "backup":
		backup_load_requested.emit(index)
	elif action == "recover":
		active_recovery_requested.emit()


func _on_canceled() -> void:
	_pending_action = ""
	_pending_index = 0
	confirmation.hide()
	if is_instance_valid(_confirm_focus) and _confirm_focus.is_visible_in_tree():
		_restore_confirmation_focus.call_deferred()


func _restore_confirmation_focus() -> void:
	if is_inside_tree() and is_instance_valid(_confirm_focus) and _confirm_focus.is_inside_tree() and _confirm_focus.is_visible_in_tree() and not _confirm_focus.is_queued_for_deletion():
		_confirm_focus.grab_focus()


func is_confirmation_open() -> bool:
	return confirmation != null and confirmation.visible


func show_result(result: Dictionary, action: String, index: int) -> void:
	feedback.text = Locale.tr_key("MANUAL_SAVE_OK" if action == "save" else ("MANUAL_ACTIVE_RECOVER_OK" if action == "recover" else "MANUAL_LOAD_OK"), {"slot": index}) if result.get("ok", false) else Locale.tr_key("MANUAL_OPERATION_FAILED", {"code": result.get("code", "UNKNOWN")})
	feedback.add_theme_color_override("font_color", ThemeSource.ACCENT if result.get("ok", false) else ThemeSource.WARNING)


func _restore_focus(index: int, action: String, scroll_position: int) -> void:
	if not is_inside_tree():
		return
	scroll.scroll_vertical = scroll_position
	if cards.has(index) and action in ["save", "load", "backup"] and cards[index].has(action):
		var button: Button = cards[index][action]
		if not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()


func _label(key: String, replacements: Dictionary = {}) -> Label:
	var label := Label.new()
	label.text = Locale.tr_key(key, replacements) if not key.is_empty() else ""
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = Locale.tr_key(key)
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	return button


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or is_confirmation_open():
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not is_ancestor_of(focused):
			close_button.grab_focus()
