extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
var world = null
var summary_label: Label
var details_label: Label
var message_label: Label
var pay_button: Button
var refresh_button: Button
var card: PanelContainer
var confirmation: Control
var info: Dictionary = {}
var pending_id := ""
var pending_action := ""
var deadline := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.8)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.atlas_style("inner_panel", Color.WHITE, 4))
	add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("WORLD TAXES", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("BACK")
	header.add_child(close)
	close.pressed.connect(close_panel)
	summary_label = _label("Loading taxes...", 20)
	box.add_child(summary_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	details_label = _label("", 16)
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details_label)
	message_label = _label("", 16)
	box.add_child(message_label)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	refresh_button = _button("REFRESH")
	actions.add_child(refresh_button)
	refresh_button.pressed.connect(func(): _request("world_tax_status"))
	pay_button = _button("PAY TAX")
	Style.apply_green_button(pay_button, 18)
	pay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(pay_button)
	pay_button.pressed.connect(_confirm_payment)
	confirmation = preload("res://Scripts/ui/vending_purchase_confirmation.gd").new()
	confirmation.title = "Pay world tax"
	confirmation.ok_button_text = "PAY GEMS"
	add_child(confirmation)
	confirmation.confirmed.connect(func(): _request("world_tax_pay", {"tax_amount": int(info.get("amount_due", 0))}))
	get_viewport().size_changed.connect(_fit)
	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		network.world_tax_received.connect(receive_result)
	_fit()
	hide()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Style.apply_game_font_to_node(label)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	Style.apply_blue_button(button, 18)
	return button

func _fit() -> void:
	if card == null:
		return
	var viewport_size := get_viewport_rect().size
	card.size = Vector2(minf(760, viewport_size.x - 24), minf(680, viewport_size.y - 24))
	card.position = (viewport_size - card.size) * 0.5

func open_panel(parent_world) -> void:
	world = parent_world
	info = {}
	pending_id = ""
	deadline = 0
	summary_label.text = "Loading taxes..."
	details_label.text = ""
	show()
	_fit()
	_request("world_tax_status")

func close_panel() -> void:
	pending_id = ""
	deadline = 0
	confirmation.hide()
	hide()

func _request(action: String, extra: Dictionary = {}) -> void:
	if deadline > 0 or world == null:
		return
	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return
	pending_id = "tax_" + str(Time.get_ticks_usec())
	pending_action = action
	var payload := {"action": action, "world": str(world.current_world_name), "request_id": pending_id}
	payload.merge(extra)
	pay_button.disabled = true
	refresh_button.disabled = true
	if network.send_inventory_transaction_request(payload):
		deadline = Time.get_ticks_msec() + 15000
		message_label.text = "Processing payment..." if action == "world_tax_pay" else "Loading..."
	else:
		pending_id = ""
		refresh_button.disabled = false
		message_label.text = "Could not contact the server. Refresh to try again."

func _process(_delta: float) -> void:
	if deadline > 0 and Time.get_ticks_msec() >= deadline:
		deadline = 0
		pending_id = ""
		refresh_button.disabled = false
		pay_button.disabled = true
		message_label.text = "Request timed out. Refresh to check the latest bill before paying."

func receive_result(data: Dictionary) -> void:
	if pending_id == "" or str(data.get("request_id", "")) != pending_id:
		return
	pending_id = ""
	deadline = 0
	refresh_button.disabled = false
	if not bool(data.get("ok", false)):
		message_label.text = str(data.get("message", "Request failed. Refresh to try again."))
		pay_button.disabled = true
		return
	info = data.get("world_tax", {})
	message_label.text = str(data.get("message", ""))
	render_status()

func _date(value) -> String:
	return str(value).replace("T", " ").left(19) + " UTC"

func render_status() -> void:
	pay_button.disabled = true
	if not bool(info.get("enabled", false)):
		summary_label.text = "World taxes are not active on this server."
		details_label.text = ""
		return
	var amount := int(info.get("amount_due", 0))
	summary_label.text = "Owned worlds: %d  |  Free allowance: 3\nDue now: %d gems" % [int(info.get("owned_count", 0)), amount]
	if bool(info.get("blocked", false)):
		summary_label.text += "\nOVERDUE — new worlds and name claims blocked"
	details_label.text = "500 gems per extra world each week.\nThis week's bill: %d gems\nNext bill: %s\n\nYour weekly bill uses the highest number of worlds above 3 owned that week. Transfers do not erase existing charges.\n\nPay within 7 days after a bill is due. Overdue tax blocks acquiring more worlds and reserving or claiming names. Your existing worlds, builds and paid names remain yours.\n\nUNPAID BILLS\n" % [int(info.get("current_bill_gems", 0)), _date(info.get("next_due_at", ""))]
	var bills: Array = info.get("bills", [])
	if bills.is_empty():
		details_label.text += "No unpaid bills.\n"
	for bill in bills:
		details_label.text += "%d gems — due %s\nGrace ends %s\n\n" % [int(bill.amount_gems), _date(bill.due_at), _date(bill.grace_until)]
	details_label.text += "\nRECENT PAYMENTS\n"
	var history: Array = info.get("history", [])
	if history.is_empty():
		details_label.text += "No payments yet.\n"
	for payment in history:
		details_label.text += "%d gems — %s\n" % [int(payment.amount_gems), _date(payment.paid_at)]
	details_label.text += "\nOWNED WORLDS\n" + ", ".join(info.get("worlds", []))
	pay_button.text = "PAY %d GEMS" % amount if amount > 0 else "NOTHING DUE"
	pay_button.disabled = amount <= 0

func _confirm_payment() -> void:
	if deadline > 0 or int(info.get("amount_due", 0)) <= 0:
		return
	confirmation.dialog_text = "Pay all due world tax: %d gems?\nThis payment is recorded by the server." % int(info.amount_due)
	confirmation.popup_centered(Vector2i(mini(440, int(get_viewport_rect().size.x) - 32), 180))
