extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const SLOT_COUNT := 6

var world = null
var panel = null
var overlay = null
var status_label = null
var local_name_label = null
var remote_name_label = null
var local_check_label = null
var remote_check_label = null
var accept_button = null
var cancel_button = null
var local_slots = []
var remote_slots = []
var picker_overlay = null
var picker_list = null
var amount_panel = null
var amount_label = null
var amount_spin = null
var final_overlay = null
var final_summary_label = null
var final_confirm_button = null

var current_trade := {}
var pending_requests_by_name := {}
var selected_picker_slot := -1
var selected_picker_item := {}


func setup(parent_world):
	world = parent_world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 150
	build_ui()
	# Reach the closed state, but skip the inventory round trip when there is nothing to end.
	# close_trade_ui() calls world.end_trade_item_select(), which unconditionally runs
	# update_inventory_window() and rebuilds all ~300 inventory slots -- measured at ~555 ms of
	# setup()'s 564 ms, while build_ui() itself is only ~9 ms. setup() runs from the post-spawn
	# optional-UI warmup, so that landed as a half-second freeze on a trade UI the player had
	# not opened, with controls already unlocked. On a freshly built UI trade_select_active is
	# already false, so the rebuild changes nothing.
	#
	# If a selection somehow IS active (setup can run again on an existing TradeUI node), the
	# full close path still runs -- correctness before speed.
	_close_trade_ui(_is_trade_item_selecting())


func build_ui():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "TradeOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.18)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Control.new()
	panel.name = "TradePanel"
	panel.size = Vector2(920, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	add_child(panel)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4,
		14,
		7
	))
	panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(16, 16)
	top_bar.size = Vector2(888, 58)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		4,
		12,
		5
	))
	panel.add_child(top_bar)

	var title = Label.new()
	title.name = "Title"
	title.text = "PLAYER TRADE"
	title.position = Vector2(34, 28)
	title.size = Vector2(360, 34)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 28)
	panel.add_child(title)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.position = Vector2(360, 30)
	status_label.size = Vector2(430, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(status_label, 16)
	panel.add_child(status_label)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(846, 26)
	close_button.size = Vector2(42, 36)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(_on_cancel_pressed)
	panel.add_child(close_button)

	create_trade_column(true, Vector2(32, 98), "YOU")
	create_trade_column(false, Vector2(488, 98), "OTHER PLAYER")
	create_bottom_buttons()
	create_picker_overlay()
	create_final_overlay()
	update_position()


func create_trade_column(is_local: bool, column_position: Vector2, title_text: String):
	var column = Panel.new()
	column.name = "LocalColumn" if is_local else "RemoteColumn"
	column.position = column_position
	column.size = Vector2(400, 360)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		4
	))
	panel.add_child(column)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = title_text
	name_label.position = Vector2(16, 12)
	name_label.size = Vector2(300, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 22)
	column.add_child(name_label)

	var check_label = Label.new()
	check_label.name = "AcceptCheck"
	check_label.text = "✓"
	check_label.position = Vector2(342, 12)
	check_label.size = Vector2(36, 28)
	check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check_label.visible = false
	check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(check_label, 24, Color(0.45, 1.0, 0.20, 1.0))
	column.add_child(check_label)

	var grid = GridContainer.new()
	grid.name = "SlotGrid"
	grid.position = Vector2(20, 58)
	grid.size = Vector2(360, 278)
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)

	for i in range(SLOT_COUNT):
		var slot = Button.new()
		slot.name = ("LocalSlot" if is_local else "RemoteSlot") + str(i)
		slot.custom_minimum_size = Vector2(112, 84)
		slot.text = ""
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_local else Control.MOUSE_FILTER_IGNORE
		slot.clip_text = true
		PixelUIStyle.apply_button_text(slot, 14)
		_apply_slot_style(slot, false)

		var slot_icon = TextureRect.new()
		slot_icon.name = "ItemIcon"
		slot_icon.position = Vector2(37, 7)
		slot_icon.size = Vector2(38, 34)
		slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_icon.visible = false
		slot.add_child(slot_icon)

		var slot_label = Label.new()
		slot_label.name = "ItemLabel"
		slot_label.position = Vector2(5, 40)
		slot_label.size = Vector2(102, 38)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_label.clip_text = true
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(slot_label, 12)
		slot.add_child(slot_label)

		if is_local:
			var clear_button = Button.new()
			clear_button.name = "ClearButton"
			clear_button.text = "X"
			clear_button.position = Vector2(84, 5)
			clear_button.size = Vector2(22, 22)
			clear_button.visible = false
			clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
			PixelUIStyle.apply_close_button(clear_button)
			clear_button.pressed.connect(_on_clear_slot_button_pressed.bind(i))
			slot.add_child(clear_button)

			slot.pressed.connect(_on_local_slot_pressed.bind(i))
			local_slots.append(slot)
		else:
			remote_slots.append(slot)

		grid.add_child(slot)

	if is_local:
		local_name_label = name_label
		local_check_label = check_label
	else:
		remote_name_label = name_label
		remote_check_label = check_label


func create_bottom_buttons():
	accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Accept"
	accept_button.position = Vector2(520, 488)
	accept_button.size = Vector2(180, 46)
	accept_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(accept_button, 18)
	accept_button.pressed.connect(_on_accept_pressed)
	panel.add_child(accept_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(718, 488)
	cancel_button.size = Vector2(170, 46)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(cancel_button)
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	panel.add_child(cancel_button)


func create_picker_overlay():
	picker_overlay = Control.new()
	picker_overlay.name = "InventoryPicker"
	picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.visible = false
	picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(picker_overlay)

	var shade = ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_overlay.add_child(shade)

	var picker_panel = Panel.new()
	picker_panel.name = "PickerPanel"
	picker_panel.size = Vector2(620, 470)
	picker_panel.position = Vector2(0, 0)
	picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4,
		14,
		7
	))
	picker_overlay.add_child(picker_panel)

	var title = Label.new()
	title.text = "SELECT ITEM"
	title.position = Vector2(22, 18)
	title.size = Vector2(300, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 24)
	picker_panel.add_child(title)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(558, 16)
	close_button.size = Vector2(40, 34)
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_picker)
	picker_panel.add_child(close_button)

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(20, 62)
	scroll.size = Vector2(580, 292)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_panel.add_child(scroll)

	picker_list = VBoxContainer.new()
	picker_list.name = "PickerList"
	picker_list.add_theme_constant_override("separation", 7)
	scroll.add_child(picker_list)

	amount_panel = Panel.new()
	amount_panel.name = "AmountPanel"
	amount_panel.position = Vector2(20, 372)
	amount_panel.size = Vector2(580, 78)
	amount_panel.visible = false
	amount_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		4
	))
	picker_panel.add_child(amount_panel)

	amount_label = Label.new()
	amount_label.position = Vector2(14, 10)
	amount_label.size = Vector2(290, 26)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(amount_label, 16)
	amount_panel.add_child(amount_label)

	amount_spin = SpinBox.new()
	amount_spin.position = Vector2(16, 40)
	amount_spin.size = Vector2(150, 30)
	amount_spin.min_value = 1
	amount_spin.max_value = 1
	amount_spin.step = 1
	amount_spin.value = 1
	amount_panel.add_child(amount_spin)

	var add_button = Button.new()
	add_button.text = "Add"
	add_button.position = Vector2(390, 36)
	add_button.size = Vector2(86, 34)
	PixelUIStyle.apply_yellow_button(add_button, 15)
	add_button.pressed.connect(_on_add_selected_item_pressed)
	amount_panel.add_child(add_button)

	var clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.position = Vector2(484, 36)
	clear_button.size = Vector2(82, 34)
	PixelUIStyle.apply_blue_button(clear_button, 15)
	clear_button.pressed.connect(_on_clear_selected_slot_pressed)
	amount_panel.add_child(clear_button)


func create_final_overlay():
	final_overlay = Control.new()
	final_overlay.name = "FinalConfirmOverlay"
	final_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	final_overlay.visible = false
	final_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(final_overlay)

	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	final_overlay.add_child(shade)

	var final_panel = Panel.new()
	final_panel.name = "FinalPanel"
	final_panel.size = Vector2(640, 430)
	final_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	final_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.56),
		Color(1.0, 0.84, 0.05, 0.82),
		4,
		14,
		7
	))
	final_overlay.add_child(final_panel)

	var title = Label.new()
	title.text = "FINAL CONFIRMATION"
	title.position = Vector2(24, 18)
	title.size = Vector2(500, 34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 26)
	final_panel.add_child(title)

	final_summary_label = Label.new()
	final_summary_label.position = Vector2(28, 70)
	final_summary_label.size = Vector2(584, 260)
	final_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(final_summary_label, 17)
	final_panel.add_child(final_summary_label)

	final_confirm_button = Button.new()
	final_confirm_button.text = "Final Accept"
	final_confirm_button.position = Vector2(326, 356)
	final_confirm_button.size = Vector2(150, 44)
	PixelUIStyle.apply_yellow_button(final_confirm_button, 16)
	final_confirm_button.pressed.connect(_on_final_confirm_pressed)
	final_panel.add_child(final_confirm_button)

	var back_button = Button.new()
	back_button.text = "Cancel"
	back_button.position = Vector2(492, 356)
	back_button.size = Vector2(120, 44)
	PixelUIStyle.apply_close_button(back_button)
	back_button.text = "Cancel"
	back_button.pressed.connect(_on_cancel_pressed)
	final_panel.add_child(back_button)


func update_position():
	if panel != null:
		var screen = get_viewport_rect().size
		panel.position = Vector2(
			(screen.x - panel.size.x) / 2.0,
			max(32.0, (screen.y - panel.size.y) / 2.0)
		)

	if picker_overlay != null:
		var picker_panel = picker_overlay.get_node_or_null("PickerPanel")
		if picker_panel != null:
			var screen = get_viewport_rect().size
			picker_panel.position = Vector2(
				(screen.x - picker_panel.size.x) / 2.0,
				max(34.0, (screen.y - picker_panel.size.y) / 2.0)
			)

	if final_overlay != null:
		var final_panel = final_overlay.get_node_or_null("FinalPanel")
		if final_panel != null:
			var screen = get_viewport_rect().size
			final_panel.position = Vector2(
				(screen.x - final_panel.size.x) / 2.0,
				max(46.0, (screen.y - final_panel.size.y) / 2.0)
			)


func handle_trade_message(data: Dictionary):
	var message_type = str(data.get("type", ""))

	if message_type == "trade_request_received":
		remember_pending_trade_request(data)
		var request_message = str(data.get("message", "Trade request received."))
		if world != null and world.has_method("show_notification"):
			world.show_notification(request_message)
		return

	if message_type == "trade_request_sent":
		if world != null and world.has_method("show_notification"):
			world.show_notification("Trade invite sent.")
		return

	if message_type == "trade_state":
		forget_pending_trade_request(str(data.get("requester_username", "")))
		current_trade = data.duplicate(true)
		open_trade_ui()
		refresh_trade_state()
		return

	if message_type == "trade_error":
		var message = str(data.get("message", "Trade failed."))
		if status_label != null:
			status_label.text = message
		if world != null and world.has_method("show_notification"):
			world.show_notification(message)
		return

	if message_type == "trade_canceled":
		var canceled_message = str(data.get("message", "Trade canceled."))
		if world != null and world.has_method("show_notification"):
			world.show_notification(canceled_message)
		close_trade_ui()
		return

	if message_type == "trade_completed":
		var completed_message = str(data.get("message", "Trade completed."))
		if world != null and world.has_method("show_notification"):
			world.show_notification(completed_message)
		close_trade_ui()
		return


func open_trade_ui():
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_position()


func remember_pending_trade_request(data: Dictionary):
	var requester = str(data.get("requester_username", "")).strip_edges()
	if requester == "":
		return

	pending_requests_by_name[requester.to_lower()] = data.duplicate(true)


func forget_pending_trade_request(requester_username: String):
	var key = requester_username.strip_edges().to_lower()
	if key != "":
		pending_requests_by_name.erase(key)


func has_pending_request_from(requester_username: String) -> bool:
	var key = requester_username.strip_edges().to_lower()
	return key != "" and pending_requests_by_name.has(key)


func accept_pending_request_from(requester_username: String) -> bool:
	var key = requester_username.strip_edges().to_lower()
	if key == "" or not pending_requests_by_name.has(key):
		return false

	var request = pending_requests_by_name[key]
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if network.has_method("send_trade_response"):
		var trade_id = str(request.get("trade_id", ""))
		if trade_id != "":
			return bool(network.send_trade_response(trade_id, true))

	if network.has_method("send_trade_response_from_player"):
		return bool(network.send_trade_response_from_player(requester_username, true))

	return false


func decline_pending_request_from(requester_username: String) -> bool:
	var key = requester_username.strip_edges().to_lower()
	if key == "" or not pending_requests_by_name.has(key):
		return false

	var request = pending_requests_by_name[key]
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if network.has_method("send_trade_response"):
		var trade_id = str(request.get("trade_id", ""))
		if trade_id != "":
			return bool(network.send_trade_response(trade_id, false))

	return false


func close_trade_ui():
	_close_trade_ui(true)


func _is_trade_item_selecting() -> bool:
	if world == null or not world.has_method("is_trade_item_selecting"):
		return false
	return bool(world.is_trade_item_selecting())


## Statement order is identical to the original close path. end_inventory_trade_select gates
## only the world.end_trade_item_select() call -- the expensive part, since it rebuilds the
## whole inventory window. Every real close still passes true.
func _close_trade_ui(end_inventory_trade_select: bool) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if end_inventory_trade_select and world != null and world.has_method("end_trade_item_select"):
		world.end_trade_item_select(_is_trade_item_selecting())
	close_picker()
	if final_overlay != null:
		final_overlay.visible = false
	current_trade.clear()


func cancel_trade_ui():
	_on_cancel_pressed()


func is_open() -> bool:
	return visible


func refresh_trade_state():
	if current_trade.is_empty():
		return

	var local_id = get_local_player_id()
	var remote_id = get_remote_player_id()
	var status = str(current_trade.get("status", ""))

	if local_name_label != null:
		local_name_label.text = get_player_name_for_id(local_id).to_upper()
	if remote_name_label != null:
		remote_name_label.text = get_player_name_for_id(remote_id).to_upper()

	update_slot_buttons(local_slots, get_offer_slots(local_id), true)
	update_slot_buttons(remote_slots, get_offer_slots(remote_id), false)

	var accepted = current_trade.get("accepted", {})
	var final_accepted = current_trade.get("final_accepted", {})
	var local_done = bool(accepted.get(local_id, false)) if accepted is Dictionary else false
	var remote_done = bool(accepted.get(remote_id, false)) if accepted is Dictionary else false
	var local_final_done = bool(final_accepted.get(local_id, false)) if final_accepted is Dictionary else false
	var remote_final_done = bool(final_accepted.get(remote_id, false)) if final_accepted is Dictionary else false

	if status == "final_pending":
		local_done = local_final_done
		remote_done = remote_final_done

	if local_check_label != null:
		local_check_label.visible = local_done
	if remote_check_label != null:
		remote_check_label.visible = remote_done

	refresh_buttons(status, local_done)
	refresh_final_popup(status, local_final_done, remote_final_done)

	if status_label != null:
		var message = str(current_trade.get("message", "")).strip_edges()
		if message == "":
			message = get_status_text(status)
		status_label.text = message


func refresh_buttons(status: String, local_done: bool):
	if accept_button == null or cancel_button == null:
		return

	var local_id = get_local_player_id()
	var is_target = local_id == str(current_trade.get("target_player_id", ""))

	accept_button.disabled = false
	accept_button.visible = true
	cancel_button.visible = true

	if status == "pending":
		if is_target:
			accept_button.text = "Accept"
			cancel_button.text = "Decline"
		else:
			accept_button.text = "Waiting"
			accept_button.disabled = true
			cancel_button.text = "Cancel"
	elif status == "active":
		accept_button.text = "Accepted" if local_done else "Accept Trade"
		accept_button.disabled = local_done
		cancel_button.text = "Cancel"
	elif status == "final_pending":
		accept_button.text = "Final Pending"
		accept_button.disabled = true
		cancel_button.text = "Cancel"
	else:
		accept_button.visible = false


func refresh_final_popup(status: String, local_final_done: bool, remote_final_done: bool):
	if final_overlay == null:
		return

	final_overlay.visible = status == "final_pending"
	if not final_overlay.visible:
		return

	if final_summary_label != null:
		final_summary_label.text = build_final_summary(local_final_done, remote_final_done)

	if final_confirm_button != null:
		final_confirm_button.disabled = local_final_done
		final_confirm_button.text = "Accepted" if local_final_done else "Final Accept"


func build_final_summary(local_final_done: bool, remote_final_done: bool) -> String:
	var local_id = get_local_player_id()
	var remote_id = get_remote_player_id()
	var text = "You will give:\n"
	text += summarize_slots(get_offer_slots(local_id))
	text += "\nYou will receive:\n"
	text += summarize_slots(get_offer_slots(remote_id))
	text += "\nFinal checks: "
	var local_text = "You OK" if local_final_done else "You waiting"
	var remote_text = get_player_name_for_id(remote_id) + " OK" if remote_final_done else get_player_name_for_id(remote_id) + " waiting"
	text += local_text
	text += " | "
	text += remote_text
	return text


func summarize_slots(slots: Array) -> String:
	var lines = []
	for item in slots:
		if not (item is Dictionary):
			continue
		var item_id = str(item.get("item_id", ""))
		var category = str(item.get("item_category", ""))
		var amount = int(item.get("amount", 0))
		if item_id == "" or amount <= 0:
			continue
		lines.append("- " + get_item_display_name(item_id, category) + " x" + str(amount))

	if lines.is_empty():
		return "- Nothing\n"

	return "\n".join(lines) + "\n"


func update_slot_buttons(buttons: Array, slots: Array, is_local: bool):
	var editable = is_local and str(current_trade.get("status", "")) == "active"

	for i in range(buttons.size()):
		var button = buttons[i]
		if button == null:
			continue

		var item = null
		if i < slots.size() and slots[i] is Dictionary:
			item = slots[i]

		if item == null:
			var empty_text = "...\nWaiting" if is_local and not editable else "+\n" + ("Add Item" if is_local else "Empty")
			set_slot_visual(button, null, empty_text, is_local, editable)
			button.disabled = is_local and not editable
			_apply_slot_style(button, false)
		else:
			var item_id = str(item.get("item_id", ""))
			var category = str(item.get("item_category", ""))
			var amount = int(item.get("amount", 0))
			set_slot_visual(button, item, get_item_display_name(item_id, category) + "\nx" + str(amount), is_local, editable)
			button.disabled = is_local and not editable
			_apply_slot_style(button, true)


func set_slot_visual(button: Button, item, label_text: String, is_local: bool, editable: bool):
	button.text = ""
	var icon = button.get_node_or_null("ItemIcon")
	var label = button.get_node_or_null("ItemLabel")
	var clear_button = button.get_node_or_null("ClearButton")

	if item is Dictionary:
		var item_id = str(item.get("item_id", ""))
		var category = str(item.get("item_category", ""))
		if icon != null:
			icon.texture = get_item_texture(item_id, category)
			icon.visible = icon.texture != null
		if label != null:
			label.text = label_text
			PixelUIStyle.apply_small_label(label, 12)
		button.tooltip_text = label_text.replace("\n", " ")
		if clear_button != null:
			clear_button.visible = is_local and editable
	else:
		if icon != null:
			icon.texture = null
			icon.visible = false
		if label != null:
			label.text = label_text
			PixelUIStyle.apply_small_label(label, 13)
		button.tooltip_text = ""
		if clear_button != null:
			clear_button.visible = false


func _apply_slot_style(button: Button, filled: bool):
	var fill = Color(0.10, 0.34, 0.56, 0.46) if filled else Color(0.05, 0.12, 0.18, 0.42)
	var border = Color(0.32, 0.70, 1.0, 0.72) if filled else Color(0.01, 0.04, 0.08, 0.64)
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(fill, border, 3, 10, 4))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(fill.lightened(0.12), border, 3, 10, 4))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(fill.darkened(0.10), border, 3, 10, 4))


func get_status_text(status: String) -> String:
	match status:
		"pending":
			return "Waiting for trade response."
		"active":
			return "Choose items and accept."
		"final_pending":
			return "Final confirmation required."
		_:
			return "Trade update."


func get_local_player_id() -> String:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null:
		var id_value = network.get("player_id")
		if id_value != null:
			return str(id_value)
	return ""


func get_remote_player_id() -> String:
	var local_id = get_local_player_id()
	var requester = str(current_trade.get("requester_player_id", ""))
	var target = str(current_trade.get("target_player_id", ""))
	return target if local_id == requester else requester


func get_player_name_for_id(player_id: String) -> String:
	if player_id == str(current_trade.get("requester_player_id", "")):
		return str(current_trade.get("requester_username", "Player"))
	if player_id == str(current_trade.get("target_player_id", "")):
		return str(current_trade.get("target_username", "Player"))
	return "Player"


func get_offer_slots(player_id: String) -> Array:
	var offers = current_trade.get("offers", {})
	if offers is Dictionary:
		var slots = offers.get(player_id, [])
		if slots is Array:
			return slots
	return []


func _on_accept_pressed():
	if current_trade.is_empty():
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var trade_id = str(current_trade.get("trade_id", ""))
	var status = str(current_trade.get("status", ""))
	var local_id = get_local_player_id()

	if status == "pending":
		if local_id == str(current_trade.get("target_player_id", "")) and network.has_method("send_trade_response"):
			network.send_trade_response(trade_id, true)
	elif status == "active":
		if network.has_method("send_trade_confirm"):
			network.send_trade_confirm(trade_id)


func _on_final_confirm_pressed():
	if current_trade.is_empty():
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_trade_final_confirm"):
		network.send_trade_final_confirm(str(current_trade.get("trade_id", "")))


func _on_cancel_pressed():
	if current_trade.is_empty():
		close_trade_ui()
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		close_trade_ui()
		return

	var trade_id = str(current_trade.get("trade_id", ""))
	var status = str(current_trade.get("status", ""))
	var local_id = get_local_player_id()
	if status == "pending" and local_id == str(current_trade.get("target_player_id", "")):
		if network.has_method("send_trade_response"):
			network.send_trade_response(trade_id, false)
	elif network.has_method("send_trade_cancel"):
		network.send_trade_cancel(trade_id)


func _on_local_slot_pressed(slot_index: int):
	if str(current_trade.get("status", "")) != "active":
		if world != null and world.has_method("show_notification"):
			world.show_notification("Items cannot be changed now.")
		return

	selected_picker_slot = slot_index
	if world != null and world.has_method("begin_trade_item_select"):
		world.begin_trade_item_select(slot_index)
		return

	open_picker(slot_index)


func add_inventory_item_to_trade(slot_index: int, item_id: String, category: String, amount: int):
	if category == "currency":
		if world != null and world.has_method("show_notification"):
			world.show_notification("Currency cannot be traded.")
		return false
	if world != null and world.item_database.has(item_id):
		if not bool(world.item_database[item_id].get("tradeable", true)):
			if world.has_method("show_notification"):
				world.show_notification("That item cannot be traded.")
			return false

	if current_trade.is_empty() or str(current_trade.get("status", "")) != "active":
		if world != null and world.has_method("show_notification"):
			world.show_notification("Items cannot be changed now.")
		return false

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_trade_offer_update"):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Connection required for trading.")
		return false

	var sent = bool(network.send_trade_offer_update(
		str(current_trade.get("trade_id", "")),
		slot_index,
		item_id,
		category,
		max(1, amount)
	))
	if not sent and world != null and world.has_method("show_notification"):
		world.show_notification("Could not add that item to the trade.")
	return sent


func _on_clear_slot_button_pressed(slot_index: int):
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_trade_offer_update"):
		return
	network.send_trade_offer_update(str(current_trade.get("trade_id", "")), slot_index, "", "", 0)


func open_picker(slot_index: int):
	selected_picker_slot = slot_index
	selected_picker_item.clear()
	amount_panel.visible = false
	rebuild_picker_list()
	picker_overlay.visible = true
	update_position()


func close_picker():
	if picker_overlay != null:
		picker_overlay.visible = false
	selected_picker_slot = -1
	selected_picker_item.clear()


func rebuild_picker_list():
	if picker_list == null:
		return

	for child in picker_list.get_children():
		child.queue_free()

	var items = collect_tradable_items()
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No tradable items in your server inventory."
		PixelUIStyle.apply_small_label(empty_label, 16)
		picker_list.add_child(empty_label)
		return

	for item in items:
		var button = Button.new()
		button.text = get_item_display_name(str(item.get("item_id", "")), str(item.get("item_category", ""))) + "  x" + str(item.get("count", 0))
		button.custom_minimum_size = Vector2(552, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		PixelUIStyle.apply_blue_button(button, 15)
		button.pressed.connect(_on_picker_item_pressed.bind(item))
		picker_list.add_child(button)


func collect_tradable_items() -> Array:
	var items = []
	add_inventory_items(items, "block", "inventory")
	add_inventory_items(items, "seed", "seed_inventory")
	add_inventory_items(items, "tool", "tool_inventory")
	add_inventory_items(items, "back", "back_inventory")
	add_inventory_items(items, "hat", "hat_inventory")
	add_inventory_items(items, "hair", "hair_inventory")
	add_inventory_items(items, "eyewear", "eyewear_inventory")
	add_inventory_items(items, "beard", "beard_inventory")
	add_inventory_items(items, "shirt", "shirt_inventory")
	add_inventory_items(items, "pants", "pants_inventory")
	add_inventory_items(items, "shoes", "shoes_inventory")
	add_inventory_items(items, "ride", "ride_inventory")
	add_inventory_items(items, "material", "material_inventory")
	add_inventory_items(items, "lure", "lure_inventory")
	add_inventory_items(items, "fish", "fish_inventory")
	items.sort_custom(Callable(self, "_sort_trade_items"))
	return items


func add_inventory_items(items: Array, category: String, property_name: String):
	if world == null:
		return

	var inventory = world.get(property_name)
	if not (inventory is Dictionary):
		return

	for item_id in inventory.keys():
		var clean_item = str(item_id)
		var count = int(inventory.get(item_id, 0))
		if count <= 0:
			continue
		if category == "tool" and clean_item == "punch":
			continue
		if category == "currency":
			continue
		if world.item_database.has(clean_item) and bool(world.item_database[clean_item].get("hidden", false)):
			continue
		if world.item_database.has(clean_item) and not bool(world.item_database[clean_item].get("tradeable", true)):
			continue

		items.append({
			"item_id": clean_item,
			"item_category": category,
			"count": count,
			"display_name": get_item_display_name(clean_item, category)
		})


func _sort_trade_items(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("display_name", "")).to_lower() < str(b.get("display_name", "")).to_lower()


func _on_picker_item_pressed(item: Dictionary):
	selected_picker_item = item.duplicate(true)
	var count = max(1, int(item.get("count", 1)))
	amount_panel.visible = true
	amount_label.text = get_item_display_name(str(item.get("item_id", "")), str(item.get("item_category", ""))) + " amount"
	amount_spin.min_value = 1
	amount_spin.max_value = count
	amount_spin.value = min(count, 1)


func _on_add_selected_item_pressed():
	if selected_picker_slot < 0 or selected_picker_item.is_empty():
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_trade_offer_update"):
		return

	network.send_trade_offer_update(
		str(current_trade.get("trade_id", "")),
		selected_picker_slot,
		str(selected_picker_item.get("item_id", "")),
		str(selected_picker_item.get("item_category", "")),
		int(amount_spin.value)
	)
	close_picker()


func _on_clear_selected_slot_pressed():
	if selected_picker_slot < 0:
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_trade_offer_update"):
		return

	network.send_trade_offer_update(str(current_trade.get("trade_id", "")), selected_picker_slot, "", "", 0)
	close_picker()


func get_item_display_name(item_id: String, category: String) -> String:
	if world != null and world.has_method("get_item_display_name"):
		return world.get_item_display_name(item_id, category)
	return item_id.capitalize()


func get_item_texture(item_id: String, category: String):
	if world != null and world.has_method("get_item_texture"):
		return world.get_item_texture(item_id, category)
	return null


func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()

	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
