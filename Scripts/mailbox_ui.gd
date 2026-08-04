extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const MAX_MAILBOX_MESSAGES := 20
const MAX_MESSAGE_LENGTH := 128

var world = null
var overlay: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var status_label: Label = null
var messages_root: VBoxContainer = null
var message_input: LineEdit = null
var send_button: Button = null
var empty_button: Button = null
var close_button: Button = null

var current_grid := Vector2i.ZERO
var mailbox_open := false


func setup(parent_world, _ui_node = null):
	world = parent_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 145
	build_ui()
	close_mailbox()


func _process(_delta):
	if mailbox_open:
		update_position()


func build_ui():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Panel.new()
	panel.size = Vector2(560, 460)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 14
	))
	add_child(panel)

	title_label = Label.new()
	title_label.text = "MAILBOX"
	title_label.position = Vector2(24, 12)
	title_label.size = Vector2(360, 44)
	PixelUIStyle.apply_label_shadow(title_label, 34)
	panel.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel.size.x - 62, 14)
	close_button.size = Vector2(42, 38)
	PixelUIStyle.apply_blue_button(close_button, 18)
	close_button.pressed.connect(close_mailbox)
	panel.add_child(close_button)

	status_label = Label.new()
	status_label.position = Vector2(28, 58)
	status_label.size = Vector2(panel.size.x - 56, 26)
	PixelUIStyle.apply_small_label(status_label, 15)
	panel.add_child(status_label)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(24, 92)
	scroll.size = Vector2(panel.size.x - 48, 238)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	messages_root = VBoxContainer.new()
	messages_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_root.add_theme_constant_override("separation", 8)
	scroll.add_child(messages_root)

	message_input = LineEdit.new()
	message_input.position = Vector2(24, 348)
	message_input.size = Vector2(panel.size.x - 48, 40)
	message_input.placeholder_text = "Write a message"
	message_input.max_length = MAX_MESSAGE_LENGTH
	PixelUIStyle.apply_input(message_input, 16)
	panel.add_child(message_input)

	send_button = Button.new()
	send_button.text = "SEND"
	send_button.position = Vector2(24, 404)
	send_button.size = Vector2(128, 40)
	PixelUIStyle.apply_yellow_button(send_button, 18)
	send_button.pressed.connect(send_message)
	panel.add_child(send_button)

	empty_button = Button.new()
	empty_button.text = "EMPTY"
	empty_button.position = Vector2(168, 404)
	empty_button.size = Vector2(128, 40)
	PixelUIStyle.apply_blue_button(empty_button, 18)
	empty_button.pressed.connect(empty_mailbox)
	panel.add_child(empty_button)


func update_position():
	if panel == null:
		return
	var screen_size = get_viewport_rect().size
	panel.position = Vector2(
		floor((screen_size.x - panel.size.x) * 0.5),
		floor(max(28.0, (screen_size.y - panel.size.y) * 0.5))
	)


func open_mailbox(grid_pos: Vector2i):
	current_grid = grid_pos
	mailbox_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	refresh()


func close_mailbox():
	mailbox_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false


func is_mailbox_open() -> bool:
	return mailbox_open and visible


func refresh():
	if messages_root == null:
		return
	for child in messages_root.get_children():
		child.queue_free()

	var messages = get_messages()
	var count = min(messages.size(), MAX_MAILBOX_MESSAGES)
	status_label.text = str(count) + "/" + str(MAX_MAILBOX_MESSAGES) + " messages"
	empty_button.visible = can_empty_mailbox() and count > 0
	send_button.disabled = count >= MAX_MAILBOX_MESSAGES

	if count <= 0:
		var empty_label = Label.new()
		empty_label.text = "No mail yet."
		PixelUIStyle.apply_small_label(empty_label, 17)
		messages_root.add_child(empty_label)
		return

	for message in messages:
		if not (message is Dictionary):
			continue
		var row = Label.new()
		var sender = str(message.get("from", message.get("sender", "Player"))).strip_edges()
		var text = str(message.get("message", message.get("text", ""))).strip_edges()
		if sender == "":
			sender = "Player"
		row.text = sender + ": " + text
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUIStyle.apply_small_label(row, 16)
		messages_root.add_child(row)


func get_current_state() -> Dictionary:
	if world == null or not ("mailbox_states" in world):
		return {}
	if not world.mailbox_states.has(current_grid):
		return {}
	var raw_state = world.mailbox_states.get(current_grid, {})
	if raw_state is Dictionary and raw_state.has("state") and raw_state.get("state") is Dictionary:
		return raw_state.get("state")
	if raw_state is Dictionary:
		return raw_state
	return {}


func get_messages() -> Array:
	var state = get_current_state()
	var messages = state.get("messages", [])
	if messages is Array:
		return messages
	return []


func can_empty_mailbox() -> bool:
	var state = get_current_state()
	var local_owner := false
	if world != null and world.world_lock_manager != null and world.world_lock_manager.has_method("is_current_player_owner"):
		if not bool(world.world_lock_manager.is_locked):
			return true
		local_owner = bool(world.world_lock_manager.is_current_player_owner())
	if state.has("can_empty"):
		return bool(state.get("can_empty", false)) or local_owner
	if state.has("can_manage"):
		return bool(state.get("can_manage", false)) or local_owner
	return local_owner


func handle_mailbox_state(data: Dictionary):
	var x = int(data.get("x", 999999))
	var y = int(data.get("y", 999999))
	if x != current_grid.x or y != current_grid.y:
		return
	refresh()


func send_message():
	var text = message_input.text.strip_edges()
	if text == "":
		return
	if text.length() > MAX_MESSAGE_LENGTH:
		text = text.substr(0, MAX_MESSAGE_LENGTH)
	if send_mailbox_update("send", text):
		message_input.clear()


func empty_mailbox():
	send_mailbox_update("empty", "")


func send_mailbox_update(operation: String, message: String) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_interaction_update"):
		if world != null:
			world.show_notification("Connection required.")
		return false

	var payload = {
		"action": "mailbox_state",
		"operation": operation,
		"x": current_grid.x,
		"y": current_grid.y,
		"message": message
	}
	var world_name = world.current_world_name if world != null else ""
	if not bool(network.send_world_interaction_update(payload, world_name)):
		if world != null:
			world.show_notification("That mailbox action could not be completed.")
		return false
	return true
