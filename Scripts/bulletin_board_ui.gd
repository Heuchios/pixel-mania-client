extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const MAX_BULLETIN_BOARD_MESSAGES := 30
const MAX_MESSAGE_LENGTH := 220
const PANEL_BASE_SIZE := Vector2(760, 560)
const PANEL_MARGIN := 28.0

var world = null
var overlay: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var status_label: Label = null
var messages_scroll: ScrollContainer = null
var messages_root: VBoxContainer = null
var message_input: TextEdit = null
var post_button: Button = null
var clear_button: Button = null
var close_button: Button = null
var count_label: Label = null

var current_grid := Vector2i.ZERO
var board_open := false


func setup(parent_world, _ui_node = null):
	world = parent_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 146
	build_ui()
	close_bulletin_board()


func _process(_delta):
	if board_open:
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
	panel.size = PANEL_BASE_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 14
	))
	add_child(panel)

	title_label = Label.new()
	title_label.text = "BULLETIN BOARD"
	PixelUIStyle.apply_label_shadow(title_label, 34)
	panel.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_bulletin_board)
	panel.add_child(close_button)

	status_label = Label.new()
	PixelUIStyle.apply_small_label(status_label, 15)
	panel.add_child(status_label)

	messages_scroll = ScrollContainer.new()
	messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	messages_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	messages_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(messages_scroll)

	messages_root = VBoxContainer.new()
	messages_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	messages_root.add_theme_constant_override("separation", 10)
	messages_scroll.add_child(messages_root)

	message_input = TextEdit.new()
	message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	message_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_text_edit_style(message_input, 16)
	message_input.text_changed.connect(_on_message_text_changed)
	panel.add_child(message_input)

	count_label = Label.new()
	PixelUIStyle.apply_small_label(count_label, 14)
	panel.add_child(count_label)

	post_button = Button.new()
	post_button.text = "POST"
	PixelUIStyle.apply_yellow_button(post_button, 18)
	post_button.pressed.connect(post_message)
	panel.add_child(post_button)

	clear_button = Button.new()
	clear_button.text = "CLEAR"
	PixelUIStyle.apply_blue_button(clear_button, 18)
	clear_button.pressed.connect(clear_board)
	panel.add_child(clear_button)

	layout_panel()


func layout_panel():
	if panel == null:
		return

	var panel_w: float = panel.size.x
	var panel_h: float = panel.size.y
	var margin := 24.0

	if title_label != null:
		title_label.position = Vector2(margin, 12)
		title_label.size = Vector2(panel_w - 140.0, 44)

	if close_button != null:
		close_button.position = Vector2(panel_w - 66.0, 14)
		close_button.size = Vector2(42, 38)

	if status_label != null:
		status_label.position = Vector2(margin + 4.0, 58)
		status_label.size = Vector2(panel_w - (margin * 2.0), 26)

	var input_h := 96.0
	var buttons_h := 42.0
	var input_y: float = panel_h - margin - buttons_h - 14.0 - input_h

	if messages_scroll != null:
		messages_scroll.position = Vector2(margin, 92)
		messages_scroll.size = Vector2(panel_w - (margin * 2.0), input_y - 104.0)

	if messages_root != null and messages_scroll != null:
		messages_root.custom_minimum_size = Vector2(max(0.0, messages_scroll.size.x - 18.0), 0)

	if message_input != null:
		message_input.position = Vector2(margin, input_y)
		message_input.size = Vector2(panel_w - (margin * 2.0), input_h)

	if count_label != null:
		count_label.position = Vector2(margin, input_y + input_h + 6.0)
		count_label.size = Vector2(190, buttons_h)

	if post_button != null:
		post_button.position = Vector2(panel_w - margin - 140.0, input_y + input_h + 4.0)
		post_button.size = Vector2(140, buttons_h)

	if clear_button != null:
		clear_button.position = Vector2(post_button.position.x - 154.0, post_button.position.y) if post_button != null else Vector2(margin, input_y + input_h + 4.0)
		clear_button.size = Vector2(140, buttons_h)


func update_position():
	if panel == null:
		return

	var screen_size: Vector2 = get_viewport_rect().size
	var target_size := Vector2(
		min(PANEL_BASE_SIZE.x, max(420.0, screen_size.x - PANEL_MARGIN * 2.0)),
		min(PANEL_BASE_SIZE.y, max(420.0, screen_size.y - PANEL_MARGIN * 2.0))
	)
	if panel.size != target_size:
		panel.size = target_size
		layout_panel()

	panel.position = Vector2(
		floor((screen_size.x - panel.size.x) * 0.5),
		floor(max(PANEL_MARGIN, (screen_size.y - panel.size.y) * 0.5))
	)


func open_bulletin_board(grid_pos: Vector2i):
	current_grid = grid_pos
	board_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	if message_input != null:
		message_input.text = ""
	update_position()
	refresh()


func close_bulletin_board():
	board_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false


func is_bulletin_board_open() -> bool:
	return board_open and visible


func refresh():
	if messages_root == null:
		return

	for child in messages_root.get_children():
		child.queue_free()

	var messages: Array = get_messages()
	var count: int = min(messages.size(), MAX_BULLETIN_BOARD_MESSAGES)
	if status_label != null:
		status_label.text = str(count) + "/" + str(MAX_BULLETIN_BOARD_MESSAGES) + " messages"
	if clear_button != null:
		clear_button.visible = can_clear_board() and count > 0
	if post_button != null:
		post_button.disabled = false
	update_character_count()

	if count <= 0:
		add_empty_row("No posts yet.")
		return

	var ordered: Array = messages.duplicate()
	ordered.reverse()
	for message_value in ordered:
		if not (message_value is Dictionary):
			continue
		add_message_row(message_value)

	if messages_scroll != null:
		messages_scroll.scroll_vertical = 0


func get_current_state() -> Dictionary:
	if world == null or not ("bulletin_board_states" in world):
		return {}
	if not world.bulletin_board_states.has(current_grid):
		return {}
	var raw_state: Variant = world.bulletin_board_states.get(current_grid, {})
	if raw_state is Dictionary and raw_state.has("state") and raw_state.get("state") is Dictionary:
		return raw_state.get("state")
	if raw_state is Dictionary:
		return raw_state
	return {}


func get_messages() -> Array:
	var state: Dictionary = get_current_state()
	var messages_value: Variant = state.get("messages", [])
	if messages_value is Array:
		return messages_value
	return []


func can_clear_board() -> bool:
	var state: Dictionary = get_current_state()
	var local_can_manage := false
	if world != null and world.has_method("can_current_player_manage_bulletin_board"):
		local_can_manage = bool(world.can_current_player_manage_bulletin_board())
	if state.has("can_clear"):
		return bool(state.get("can_clear", false)) or local_can_manage
	if state.has("can_manage"):
		return bool(state.get("can_manage", false)) or local_can_manage
	return local_can_manage


func add_empty_row(text: String):
	var row := Label.new()
	row.text = text
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if messages_root != null:
		row.custom_minimum_size = Vector2(messages_root.custom_minimum_size.x, 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	PixelUIStyle.apply_small_label(row, 17)
	messages_root.add_child(row)


func add_message_row(message: Dictionary):
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.090, 0.190, 0.275, 0.62),
		Color(0.420, 0.780, 1.000, 0.38),
		2, 8, 4
	))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if messages_root != null:
		card.custom_minimum_size = Vector2(messages_root.custom_minimum_size.x, 74)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var header := Label.new()
	var player_name: String = str(message.get("player_name", message.get("username", message.get("from", "Player")))).strip_edges()
	if player_name == "":
		player_name = "Player"
	header.text = player_name + "  -  " + format_timestamp(message.get("posted_at", message.get("created_at", message.get("sent_at", ""))))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUIStyle.apply_section_title(header, 16)
	box.add_child(header)

	var body := Label.new()
	body.text = str(message.get("message", message.get("text", ""))).strip_edges()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	PixelUIStyle.apply_small_label(body, 16)
	box.add_child(body)

	messages_root.add_child(card)


func post_message():
	if message_input == null:
		return
	if is_anti_talk_blocking_post():
		if world != null:
			world.show_notification("Anti-talk is enabled in this world.")
		return
	var text: String = message_input.text.strip_edges()
	if text == "":
		return
	if text.length() > MAX_MESSAGE_LENGTH:
		text = text.substr(0, MAX_MESSAGE_LENGTH)
	if send_bulletin_board_update("post", text):
		message_input.text = ""
		update_character_count()


func clear_board():
	send_bulletin_board_update("clear", "")


func send_bulletin_board_update(operation: String, message: String) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_interaction_update"):
		if world != null:
			world.show_notification("Connection required.")
		return false

	var payload := {
		"action": "bulletin_board_state",
		"operation": operation,
		"x": current_grid.x,
		"y": current_grid.y,
		"message": message
	}
	var world_name: String = world.current_world_name if world != null else ""
	if not bool(network.send_world_interaction_update(payload, world_name)):
		if world != null:
			world.show_notification("That board action could not be completed.")
		return false
	return true


func is_anti_talk_blocking_post() -> bool:
	if world == null:
		return false
	if not world.has_method("is_anti_talk_enabled") or not bool(world.is_anti_talk_enabled()):
		return false
	if world.has_method("can_current_player_bypass_anti_talk") and bool(world.can_current_player_bypass_anti_talk()):
		return false
	return true


func handle_bulletin_board_state(data: Dictionary):
	var x: int = int(data.get("x", 999999))
	var y: int = int(data.get("y", 999999))
	if x != current_grid.x or y != current_grid.y:
		return
	refresh()


func _on_message_text_changed():
	if message_input == null:
		return
	if message_input.text.length() > MAX_MESSAGE_LENGTH:
		var cursor_line: int = message_input.get_caret_line()
		var cursor_column: int = message_input.get_caret_column()
		message_input.text = message_input.text.substr(0, MAX_MESSAGE_LENGTH)
		message_input.set_caret_line(min(cursor_line, message_input.get_line_count() - 1))
		message_input.set_caret_column(min(cursor_column, message_input.get_line(message_input.get_caret_line()).length()))
	update_character_count()


func update_character_count():
	if count_label == null:
		return
	var length := 0
	if message_input != null:
		length = message_input.text.length()
	count_label.text = str(length) + "/" + str(MAX_MESSAGE_LENGTH)


func format_timestamp(value) -> String:
	var text: String = str(value).strip_edges()
	if text == "":
		return "unknown date"
	if text.length() >= 16 and text.find("T") >= 0:
		return text.substr(0, 10) + " " + text.substr(11, 5)
	return text


func apply_text_edit_style(text_edit: TextEdit, font_size: int = 16):
	if text_edit == null:
		return
	text_edit.add_theme_font_size_override("font_size", font_size)
	text_edit.add_theme_stylebox_override("normal", PixelUIStyle.input_style())
	text_edit.add_theme_stylebox_override("focus", PixelUIStyle.input_focus_style())
	text_edit.add_theme_stylebox_override("read_only", PixelUIStyle.input_style())
	text_edit.add_theme_color_override("font_color", PixelUIStyle.TEXT_LIGHT)
	text_edit.add_theme_color_override("caret_color", PixelUIStyle.GOLD_SOFT)
	text_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))
