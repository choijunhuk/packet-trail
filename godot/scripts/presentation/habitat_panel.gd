extends PanelContainer
## Fictional local room shop and optional neighborhood interactions.

signal closed
signal action_requested(action: String, params: Dictionary)
signal recovery_requested

const ThemeSource = preload("res://scripts/presentation/desktop_theme.gd")
const Locale = preload("res://scripts/presentation/localization.gd")
var content: VBoxContainer
var feedback: Label
var mode := "shop"
var last_view: Dictionary = {}
var recovery: ConfirmationDialog
var controls: Dictionary = {}


func setup(view: Dictionary, context: String, font_scale: float = 1.0) -> void:
	mode = context
	last_view = view.duplicate(true)
	theme = ThemeSource.create(font_scale, Color("edb58f"))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -490
	offset_right = 490
	offset_top = -340
	offset_bottom = 340
	add_theme_stylebox_override("panel", ThemeSource.panel(ThemeSource.SURFACE, ThemeSource.LINE, 9, 18))
	var outer := VBoxContainer.new()
	add_child(outer)
	var heading := HBoxContainer.new()
	var title := _label("HAB_TITLE_" + mode.to_upper())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", roundi(24.0 * font_scale))
	heading.add_child(title)
	heading.add_child(_button("HAB_CLOSE", func(): closed.emit()))
	outer.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(feedback)
	recovery = ConfirmationDialog.new()
	recovery.title = _t("HAB_RECOVER")
	recovery.dialog_text = _t("HAB_RECOVER_CONFIRM")
	recovery.ok_button_text = _t("HAB_RECOVER")
	recovery.cancel_button_text = _t("CANCEL")
	recovery.confirmed.connect(func(): recovery_requested.emit())
	add_child(recovery)
	render(view)


func render(view: Dictionary) -> void:
	last_view = view.duplicate(true)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	controls.clear()
	content.add_child(_label("HAB_WALLET", {"balance": view.get("balance", 0)}))
	content.add_child(_label("HAB_OPTIONAL_NOTE"))
	if not view.get("ready", false):
		content.add_child(_label("HAB_READ_ONLY"))
		var recover := _button("HAB_RECOVER", func(): recovery.popup_centered(Vector2i(560, 220)))
		recover.disabled = not view.get("recovery_available", false)
		content.add_child(recover)
	if mode == "shop":
		_build_shop(view)
	elif mode == "delivery_locker":
		content.add_child(_label("HAB_DELIVERY_COUNT", {"count": view.get("ready_delivery_count", 0)}))
		content.add_child(_action("HAB_COLLECT", "collect_delivery", {}, view.get("ready", false) and view.get("ready_delivery_count", 0) > 0))
	elif mode == "noticeboard":
		content.add_child(_label("HAB_JOB_DESCRIPTION"))
		content.add_child(_action("HAB_ACCEPT_JOB", "accept_job", {"job_id": "network_cabinet"}, view.get("ready", false) and not view.job.accepted))
		_show_job(view)
	elif mode == "network_cabinet":
		content.add_child(_label("HAB_CABINET_DESCRIPTION"))
		_show_job(view)
		content.add_child(_action("HAB_INSPECT", "inspect_cabinet", {}, view.get("ready", false) and view.job.accepted))
		var route := OptionButton.new()
		for id in ["public", "service", "approved_relay", "off"]:
			route.add_item(_t("HAB_ROUTE_" + id.to_upper()))
			route.set_item_metadata(route.item_count - 1, id)
			route.set_item_tooltip(route.item_count - 1, id)
		route.select(["public", "service", "approved_relay", "off"].find(str(view.job.route)))
		route.accessibility_name = _t("HAB_ROUTE")
		controls.route = route
		content.add_child(_label("HAB_ROUTE"))
		content.add_child(route)
		var locked := CheckBox.new()
		locked.text = _t("HAB_LOCKED")
		locked.button_pressed = view.job.locked
		controls.locked = locked
		content.add_child(locked)
		var configure := _button("HAB_CONFIGURE", func(): action_requested.emit("configure_cabinet", {"route": route.get_item_metadata(route.selected), "locked": locked.button_pressed}))
		configure.disabled = not view.get("ready", false) or not view.job.inspected
		content.add_child(configure)
		controls.configure = configure
		content.add_child(_action("HAB_VERIFY", "verify_job", {}, view.get("ready", false) and view.job.inspected))
	elif mode == "bench":
		content.add_child(_label("HAB_REST_NOTE"))
		content.add_child(_action("HAB_LIGHT_NIGHT", "set_lighting", {"lighting": "night"}, view.get("ready", false)))
		content.add_child(_action("HAB_LIGHT_DAWN", "set_lighting", {"lighting": "dawn"}, view.get("ready", false)))


func _build_shop(view: Dictionary) -> void:
	content.add_child(_label("HAB_SHOP_ADDRESS"))
	content.add_child(_label("HAB_SHOP_DELIVERY"))
	for product in view.get("catalog", []):
		var row := HBoxContainer.new()
		var preview := ProductPreview.new()
		preview.product = product
		preview.custom_minimum_size = Vector2(150, 76)
		preview.tooltip_text = _t(product.label_key)
		row.add_child(preview)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(_label(str(product.label_key)))
		words.add_child(_label("HAB_PRICE", {"price": product.price}))
		row.add_child(words)
		var owned: bool = view.owned.has(product.id)
		var pending := false
		for order in view.orders:
			if order.product_id == product.id and order.status == "ready": pending = true
		var equipped: bool = view.equipped.get(product.slot) == product.id
		var button: Button
		if owned:
			button = _action("HAB_EQUIPPED" if equipped else "HAB_EQUIP", "equip", {"slot": product.slot, "product_id": product.id}, view.get("ready", false) and not equipped)
		elif pending:
			button = _button("HAB_AWAITING_PICKUP", func(): pass)
			button.disabled = true
		else:
			button = _action("HAB_ORDER", "order", {"product_id": product.id}, view.get("ready", false) and int(view.balance) >= int(product.price))
		button.set_meta("product_id", product.id)
		row.add_child(button)
		content.add_child(row)


func _show_job(view: Dictionary) -> void:
	var job: Dictionary = view.job
	content.add_child(_label("HAB_JOB_STATE", {"accepted": _t("HAB_YES" if job.accepted else "HAB_NO"), "rewarded": _t("HAB_YES" if job.rewarded else "HAB_NO")}))
	if not job.current_check.is_empty():
		var receipt: Dictionary = job.current_check
		content.add_child(_label("HAB_JOB_CHECK", {"normal": _t("HAB_YES" if receipt.normal_telemetry else "HAB_NO"), "unauthorized": _t("HAB_YES" if receipt.unauthorized_access else "HAB_NO"), "passed": _t("HAB_YES" if receipt.passed else "HAB_NO")}))
	if job.rewarded:
		content.add_child(_label("HAB_REWARD_RECEIPT", {"route": _t("HAB_ROUTE_" + str(job.reward_receipt.route).to_upper())}))


func show_result(result: Dictionary) -> void:
	feedback.text = _t(str(result.get("code", "HABITAT_UPDATED")))
	if feedback.text == str(result.get("code", "")):
		feedback.text = _t("HAB_ACTION_OK" if result.get("ok", false) else "HAB_ACTION_FAILED")
	feedback.add_theme_color_override("font_color", ThemeSource.SUCCESS if result.get("ok", false) and result.get("code") != "HABITAT_JOB_CHECK_FAILED" else ThemeSource.WARNING)


func _action(key: String, action: String, params: Dictionary, enabled: bool) -> Button:
	var button := _button(key, func(): action_requested.emit(action, params))
	button.disabled = not enabled
	button.set_meta("habitat_action", action)
	controls[action] = button
	return button


func _button(key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = _t(key)
	button.pressed.connect(callback)
	return button


func _label(key: String, params: Dictionary = {}) -> Label:
	var label := Label.new()
	label.text = _t(key).format(params)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _t(key: String) -> String:
	return Locale.tr_key(key)


class ProductPreview extends Control:
	var product: Dictionary = {}
	func _draw() -> void:
		var visual: Dictionary = product.get("visual", {})
		if product.get("slot") == "keyboard":
			draw_style_box(ThemeSource.panel(Color(visual.get("body", "222629")), Color.TRANSPARENT, 5, 0), Rect2(8, 20, 130, 45))
			for y in range(3):
				for x in range(10): draw_rect(Rect2(15 + x * 12, 26 + y * 11, 9, 8), Color(visual.get("keycaps", "444b50")))
		elif product.get("slot") == "monitor":
			var dual: bool = visual.get("layout") == "dual"
			var count := 2 if dual else 1
			for index in range(count):
				var width := 60.0 if dual else (136.0 if visual.get("layout") == "wide" else 110.0)
				draw_rect(Rect2(5 + index * 70, 6, width, 52), Color(visual.get("frame", "20272a")))
				draw_rect(Rect2(10 + index * 70, 11, width - 10, 40), Color(visual.get("glow", "67a6b7")))
				draw_rect(Rect2(30 + index * 70, 60, 36, 5), Color("87908d"))
		else:
			draw_line(Vector2(65, 65), Vector2(85, 20), Color("7f8580"), 5)
			draw_circle(Vector2(85, 20), 17, Color(visual.get("tint", "ffc487")))
			draw_rect(Rect2(43, 65, 50, 6), Color("414846"))
