extends Control

# TradeUI
# ---------------------------------------------------------------------------
# Backed by Scenes/ui/trade/TradeScene.tscn. The scene owns layout/positions/
# static panel styling (baked StyleBoxFlat resources); this script wires
# signals, applies the shared PixelUIStyle text/button styling (which needs
# the runtime game font, so it stays in code rather than baked into the
# scene), and owns all trade state/network logic. Node names below match the
# scene 1:1 -- rename in one place, update the other.
#
# Skinning / customizing your own look:
#   Panels (PanelBack, TopBar, LocalColumn, RemoteColumn, PickerPanel,
#   AmountPanel, FinalPanel) use baked StyleBoxFlat resources on their
#   "panel" theme override -- open TradeScene.tscn and swap any of those for
#   a StyleBoxTexture (or add your own TextureRect/NinePatchRect children) to
#   reskin a panel. Nothing at runtime touches panel styleboxes, so editor
#   changes there always stick.
#
#   Buttons and slots are different: by default this script re-applies the
#   shared PixelUIStyle look every time it (re)styles, which would overwrite
#   hand styling done in the editor. Set `use_pixel_ui_style = false` below
#   (an @export, so it's a checkbox on the TradeUI root node in the
#   Inspector) to turn that off entirely -- once disabled, whatever you set
#   in the editor on AcceptButton/CancelButton/CloseButton/the slot buttons/
#   etc. (including swapping in your own PixelButton-based custom buttons)
#   is left alone. The dynamic per-slot "filled vs empty" tint still applies
#   when the default styling is on, but its four colors are exposed as
#   exports below so you can retint them without touching code.
#
#   The picker's item-list buttons are generated at runtime (one tradable
#   item = one button, so the count isn't known ahead of time). They are
#   duplicated from the hidden PickerItemTemplate node under
#   InventoryPicker/PickerPanel/Scroll/PickerList -- style that one template
#   node in the editor and every generated item button inherits it.
# ---------------------------------------------------------------------------

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const SLOT_COUNT := 6

## Master switch for the automatic PixelUIStyle look. Turn off to keep
## whatever button/label styling you set up by hand in TradeScene.tscn.
@export var use_pixel_ui_style: bool = true

@export_group("Slot Colors")
@export var slot_fill_empty: Color = Color(0.05, 0.12, 0.18, 0.42)
@export var slot_border_empty: Color = Color(0.01, 0.04, 0.08, 0.64)
@export var slot_fill_filled: Color = Color(0.10, 0.34, 0.56, 0.46)
@export var slot_border_filled: Color = Color(0.32, 0.70, 1.0, 0.72)

var world = null

@onready var panel: Control = get_node_or_null("TradePanel") as Control
@onready var status_label: Label = get_node_or_null("TradePanel/StatusLabel") as Label
@onready var title_label: Label = get_node_or_null("TradePanel/Title") as Label
@onready var top_close_button: Button = get_node_or_null("TradePanel/CloseButton") as Button
@onready var local_name_label: Label = get_node_or_null("TradePanel/LocalColumn/NameLabel") as Label
@onready var remote_name_label: Label = get_node_or_null("TradePanel/RemoteColumn/NameLabel") as Label
@onready var local_check_label: Label = get_node_or_null("TradePanel/LocalColumn/AcceptCheck") as Label
@onready var remote_check_label: Label = get_node_or_null("TradePanel/RemoteColumn/AcceptCheck") as Label
@onready var accept_button: Button = get_node_or_null("TradePanel/AcceptButton") as Button
@onready var cancel_button: Button = get_node_or_null("TradePanel/CancelButton") as Button

@onready var picker_overlay: Control = get_node_or_null("InventoryPicker") as Control
@onready var picker_title_label: Label = get_node_or_null("InventoryPicker/PickerPanel/Title") as Label
@onready var picker_close_button: Button = get_node_or_null("InventoryPicker/PickerPanel/CloseButton") as Button
@onready var picker_list: VBoxContainer = get_node_or_null("InventoryPicker/PickerPanel/Scroll/PickerList") as VBoxContainer
@onready var picker_item_template: Button = get_node_or_null("InventoryPicker/PickerPanel/Scroll/PickerList/PickerItemTemplate") as Button
@onready var amount_panel: Panel = get_node_or_null("InventoryPicker/PickerPanel/AmountPanel") as Panel
@onready var amount_label: Label = get_node_or_null("InventoryPicker/PickerPanel/AmountPanel/AmountLabel") as Label
@onready var amount_spin: SpinBox = get_node_or_null("InventoryPicker/PickerPanel/AmountPanel/AmountSpin") as SpinBox
@onready var picker_add_button: Button = get_node_or_null("InventoryPicker/PickerPanel/AmountPanel/AddButton") as Button
@onready var picker_clear_button: Button = get_node_or_null("InventoryPicker/PickerPanel/AmountPanel/ClearSelectedButton") as Button

@onready var final_overlay: Control = get_node_or_null("FinalConfirmOverlay") as Control
@onready var final_title_label: Label = get_node_or_null("FinalConfirmOverlay/FinalPanel/Title") as Label
@onready var final_summary_label: Label = get_node_or_null("FinalConfirmOverlay/FinalPanel/FinalSummaryLabel") as Label
@onready var final_confirm_button: Button = get_node_or_null("FinalConfirmOverlay/FinalPanel/FinalConfirmButton") as Button
@onready var final_back_button: Button = get_node_or_null("FinalConfirmOverlay/FinalPanel/BackButton") as Button

var local_slots: Array = []
var remote_slots: Array = []

var current_trade := {}
var pending_requests_by_name := {}
var selected_picker_slot := -1
var selected_picker_item := {}


func _ready() -> void:
	_connect_signals()
	_populate_slot_arrays()
	_apply_styles()
	# Reach the closed state, but skip the inventory round trip when there is nothing to end.
	# close_trade_ui() calls world.end_trade_item_select(), which unconditionally runs
	# update_inventory_window() and rebuilds all ~300 inventory slots -- measured at ~555 ms of
	# the old setup()'s 564 ms, while the scene's own _ready() work above is only a few ms. This
	# runs from the post-spawn optional-UI warmup, so an unconditional close landed as a half
	# second freeze on a trade UI the player had not opened, with controls already unlocked. On a
	# freshly ready UI trade_select_active is already false, so the rebuild would change nothing.
	#
	# If a selection somehow IS active (setup can run again on an existing TradeUI node), the
	# full close path still runs -- correctness before speed.
	_close_trade_ui(_is_trade_item_selecting())


func setup(parent_world):
	world = parent_world


func _connect_signals() -> void:
	if panel != null and not panel.gui_input.is_connected(_on_panel_gui_input):
		panel.gui_input.connect(_on_panel_gui_input)
	if top_close_button != null and not top_close_button.pressed.is_connected(_on_cancel_pressed):
		top_close_button.pressed.connect(_on_cancel_pressed)
	if accept_button != null and not accept_button.pressed.is_connected(_on_accept_pressed):
		accept_button.pressed.connect(_on_accept_pressed)
	if cancel_button != null and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if picker_close_button != null and not picker_close_button.pressed.is_connected(close_picker):
		picker_close_button.pressed.connect(close_picker)
	if picker_add_button != null and not picker_add_button.pressed.is_connected(_on_add_selected_item_pressed):
		picker_add_button.pressed.connect(_on_add_selected_item_pressed)
	if picker_clear_button != null and not picker_clear_button.pressed.is_connected(_on_clear_selected_slot_pressed):
		picker_clear_button.pressed.connect(_on_clear_selected_slot_pressed)
	if final_confirm_button != null and not final_confirm_button.pressed.is_connected(_on_final_confirm_pressed):
		final_confirm_button.pressed.connect(_on_final_confirm_pressed)
	if final_back_button != null and not final_back_button.pressed.is_connected(_on_cancel_pressed):
		final_back_button.pressed.connect(_on_cancel_pressed)


func _populate_slot_arrays() -> void:
	local_slots.clear()
	remote_slots.clear()

	var local_grid = get_node_or_null("TradePanel/LocalColumn/SlotGrid")
	var remote_grid = get_node_or_null("TradePanel/RemoteColumn/SlotGrid")

	for i in range(SLOT_COUNT):
		var local_slot: Button = null
		if local_grid != null:
			local_slot = local_grid.get_node_or_null("LocalSlot" + str(i)) as Button
		local_slots.append(local_slot)
		if local_slot != null and not local_slot.pressed.is_connected(_on_local_slot_pressed):
			local_slot.pressed.connect(_on_local_slot_pressed.bind(i))
		if local_slot != null:
			var clear_button = local_slot.get_node_or_null("ClearButton")
			if clear_button != null and not clear_button.pressed.is_connected(_on_clear_slot_button_pressed):
				clear_button.pressed.connect(_on_clear_slot_button_pressed.bind(i))

		var remote_slot: Button = null
		if remote_grid != null:
			remote_slot = remote_grid.get_node_or_null("RemoteSlot" + str(i)) as Button
		remote_slots.append(remote_slot)


func _apply_styles() -> void:
	if not use_pixel_ui_style:
		return

	PixelUIStyle.apply_label_shadow(title_label, 28)
	PixelUIStyle.apply_small_label(status_label, 16)
	PixelUIStyle.apply_close_button(top_close_button)

	PixelUIStyle.apply_label_shadow(local_name_label, 22)
	PixelUIStyle.apply_label_shadow(remote_name_label, 22)
	PixelUIStyle.apply_label_shadow(local_check_label, 24, Color(0.45, 1.0, 0.20, 1.0))
	PixelUIStyle.apply_label_shadow(remote_check_label, 24, Color(0.45, 1.0, 0.20, 1.0))

	for slot in local_slots:
		_style_slot(slot, true)
	for slot in remote_slots:
		_style_slot(slot, false)

	PixelUIStyle.apply_yellow_button(accept_button, 18)
	PixelUIStyle.apply_close_button(cancel_button)
	cancel_button.text = "Cancel"

	PixelUIStyle.apply_label_shadow(picker_title_label, 24)
	PixelUIStyle.apply_close_button(picker_close_button)
	PixelUIStyle.apply_small_label(amount_label, 16)
	PixelUIStyle.apply_yellow_button(picker_add_button, 15)
	PixelUIStyle.apply_blue_button(picker_clear_button, 15)

	PixelUIStyle.apply_label_shadow(final_title_label, 26)
	PixelUIStyle.apply_small_label(final_summary_label, 17)
	PixelUIStyle.apply_yellow_button(final_confirm_button, 16)
	PixelUIStyle.apply_close_button(final_back_button)
	final_back_button.text = "Cancel"

	if picker_item_template != null:
		PixelUIStyle.apply_blue_button(picker_item_template, 15)


func _style_slot(slot: Button, is_local: bool) -> void:
	if slot == null:
		return
	PixelUIStyle.apply_button_text(slot, 14)
	var label = slot.get_node_or_null("ItemLabel")
	if label != null:
		PixelUIStyle.apply_small_label(label, 12)
	if is_local:
		var clear_button = slot.get_node_or_null("ClearButton")
		if clear_button != null:
			PixelUIStyle.apply_close_button(clear_button)
	_apply_slot_style(slot, false)


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
			if use_pixel_ui_style:
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
			if use_pixel_ui_style:
				PixelUIStyle.apply_small_label(label, 13)
		button.tooltip_text = ""
		if clear_button != null:
			clear_button.visible = false


func _apply_slot_style(button: Button, filled: bool):
	if not use_pixel_ui_style or button == null:
		return
	var fill = slot_fill_filled if filled else slot_fill_empty
	var border = slot_border_filled if filled else slot_border_empty
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

	# PickerItemTemplate lives under picker_list too (it's the node generated
	# item buttons are duplicated from), so it must survive this clear.
	for child in picker_list.get_children():
		if child == picker_item_template:
			continue
		child.queue_free()

	var items = collect_tradable_items()
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No tradable items in your server inventory."
		if use_pixel_ui_style:
			PixelUIStyle.apply_small_label(empty_label, 16)
		picker_list.add_child(empty_label)
		return

	for item in items:
		var button: Button = (picker_item_template.duplicate() as Button) if picker_item_template != null else Button.new()
		button.visible = true
		button.text = get_item_display_name(str(item.get("item_id", "")), str(item.get("item_category", ""))) + "  x" + str(item.get("count", 0))
		if picker_item_template == null:
			button.custom_minimum_size = Vector2(552, 38)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_NONE
			if use_pixel_ui_style:
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
