extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

@export_category("Donation Box Layout")
@export var preferred_panel_size := Vector2(980, 610)
@export_range(620.0, 1400.0, 10.0) var minimum_panel_width := 620.0
@export_range(430.0, 900.0, 10.0) var minimum_panel_height := 430.0
@export_range(110.0, 240.0, 2.0) var donation_card_width := 190.0
@export_range(96.0, 190.0, 2.0) var donation_card_height := 132.0
@export_range(2, 8, 1) var maximum_columns := 5
@export_range(6.0, 32.0, 1.0) var card_gap := 14.0

@export_category("Donation Box Copy")
@export var title_text := "DONATION BOX"
@export var subtitle_text := "GIVE ITEMS TO THE WORLD OWNER"
@export var public_privacy_text := "Donations are private. Only the world owner can view and retrieve them."
@export var empty_owner_text := "No donations yet."

@export_category("Donation Box Colors")
@export var accent_color := Color(1.0, 0.72, 0.16, 1.0)
@export var accent_border_color := Color(1.0, 0.92, 0.46, 0.86)
@export var card_fill_color := Color(0.16, 0.30, 0.41, 0.72)
@export var card_border_color := Color(0.58, 0.86, 1.0, 0.54)

var world = null
var ui_layer_ref = null
var overlay: ColorRect = null
var panel_shadow: Panel = null
var panel: Control = null
var status_label: Label = null
var hint_label: Label = null
var donations_scroll: ScrollContainer = null
var donations_root: Control = null
var donate_button: Button = null
var retrieve_all_button: Button = null

var current_grid := Vector2i.ZERO
var current_state: Dictionary = {}
var donation_box_open_requested := false


func _ready():
	if not donation_box_open_requested:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	donation_box_open_requested = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 147
	build_ui()
	close_donation_box()


func _process(_delta):
	if not donation_box_open_requested:
		if visible:
			visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	if visible:
		update_position()


func get_view_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return Vector2(1180, 680)
	return viewport_size


func apply_button_style(button: Button, primary := false, danger := false, font_size := 15):
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.94), Color(1.0, 0.34, 0.38, 0.62), 3, 11, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.84), 3, 11, 7))
	elif primary:
		PixelUIStyle.apply_yellow_button(button, font_size)
	else:
		PixelUIStyle.apply_blue_button(button, font_size)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func build_ui():
	for child in get_children():
		child.queue_free()

	var viewport_size := get_view_size()
	var actual_panel_size := Vector2(
		min(preferred_panel_size.x, max(minimum_panel_width, viewport_size.x - 72.0)),
		min(preferred_panel_size.y, max(minimum_panel_height, viewport_size.y - 80.0))
	)

	overlay = ColorRect.new()
	overlay.name = "DonationBoxOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.18)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel_shadow = Panel.new()
	panel_shadow.name = "DonationBoxPanelShadow"
	panel_shadow.size = actual_panel_size
	panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 18, 22))
	add_child(panel_shadow)

	panel = Control.new()
	panel.name = "DonationBoxPanel"
	panel.size = actual_panel_size
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var panel_back := Panel.new()
	panel_back.size = actual_panel_size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 4, 18, 16))
	panel.add_child(panel_back)

	var header := Panel.new()
	header.size = Vector2(actual_panel_size.x, 94)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_HEADER, PixelUIStyle.GLASS_BORDER, 0, 18, 8))
	panel.add_child(header)

	var top_line := ColorRect.new()
	top_line.position = Vector2(0, 89)
	top_line.size = Vector2(actual_panel_size.x, 5)
	top_line.color = accent_color
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(30, 5)
	title.size = Vector2(actual_panel_size.x * 0.52, 54)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 44 if actual_panel_size.x >= 850 else 34)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.position = Vector2(34, 59)
	subtitle.size = Vector2(actual_panel_size.x * 0.58, 23)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 13)
	panel.add_child(subtitle)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(actual_panel_size.x - 82, 18)
	apply_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_donation_box)
	panel.add_child(close_button)

	status_label = Label.new()
	status_label.position = Vector2(max(420.0, close_button.position.x - 300.0), 24)
	status_label.size = Vector2(max(150.0, close_button.position.x - max(420.0, close_button.position.x - 300.0) - 12.0), 38)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status_label, 16)
	panel.add_child(status_label)

	var action_y := 108.0
	donate_button = Button.new()
	donate_button.name = "DonateButton"
	donate_button.text = "DONATE"
	donate_button.position = Vector2(30, action_y)
	donate_button.size = Vector2(200, 50)
	apply_button_style(donate_button, true, false, 17)
	donate_button.pressed.connect(_on_donate_pressed)
	panel.add_child(donate_button)

	retrieve_all_button = Button.new()
	retrieve_all_button.name = "RetrieveAllButton"
	retrieve_all_button.text = "RETRIEVE ALL DONATIONS"
	retrieve_all_button.position = Vector2(244, action_y)
	retrieve_all_button.size = Vector2(292, 50)
	apply_button_style(retrieve_all_button, false, false, 15)
	retrieve_all_button.pressed.connect(_on_retrieve_all_pressed)
	panel.add_child(retrieve_all_button)

	hint_label = Label.new()
	hint_label.position = Vector2(552, action_y + 3)
	hint_label.size = Vector2(max(140.0, actual_panel_size.x - 582.0), 44)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(hint_label, 12)
	panel.add_child(hint_label)

	var card := Panel.new()
	card.position = Vector2(30, 174)
	card.size = Vector2(actual_panel_size.x - 60.0, actual_panel_size.y - 204.0)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 14, 10))
	panel.add_child(card)

	donations_scroll = ScrollContainer.new()
	donations_scroll.position = Vector2(16, 16)
	donations_scroll.size = Vector2(card.size.x - 32.0, card.size.y - 32.0)
	donations_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	donations_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	donations_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(donations_scroll)

	donations_root = Control.new()
	donations_root.size = donations_scroll.size
	donations_root.custom_minimum_size = donations_scroll.size
	donations_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	donations_scroll.add_child(donations_root)

	var scrollbar := donations_scroll.get_v_scroll_bar()
	if scrollbar != null:
		scrollbar.custom_minimum_size.x = 12
		scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(accent_color.darkened(0.22), accent_border_color, 2, 7, 4))


func update_position():
	if panel == null:
		return
	var viewport_size := get_view_size()
	var position := Vector2(floor((viewport_size.x - panel.size.x) * 0.5), floor(max(30.0, (viewport_size.y - panel.size.y) * 0.5)))
	panel.position = position
	if panel_shadow != null:
		panel_shadow.position = position


func has_donation_box_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or not ("blocks" in world) or not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false
	var block_type := str(block_data.get("type", block_data.get("block_type", "")))
	if world.has_method("is_donation_box_block_type"):
		return bool(world.is_donation_box_block_type(block_type))
	return block_type.strip_edges().to_lower() == "donation_box"


func open_donation_box(grid_pos: Vector2i):
	if not has_donation_box_at_grid(grid_pos):
		close_donation_box()
		return
	donation_box_open_requested = true
	current_grid = grid_pos
	current_state = {}
	if world != null and world.donation_box_states.has(current_grid):
		var cached = world.donation_box_states[current_grid]
		if cached is Dictionary:
			current_state = cached.get("state", cached).duplicate(true)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_ui()
	request_donation_box_state()


func close_donation_box():
	donation_box_open_requested = false
	if world != null and world.has_method("is_donation_box_item_selecting") and world.is_donation_box_item_selecting():
		world.end_donation_box_item_select(true)
	current_state.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_donation_box_open() -> bool:
	return donation_box_open_requested and visible


func request_donation_box_state():
	send_donation_box_request({"action": "donation_box_get_state"})


func send_donation_box_request(payload: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_inventory_transaction_request"):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Connection required.")
		return false
	var request := payload.duplicate(true)
	request["world"] = world.current_world_name
	request["x"] = current_grid.x
	request["y"] = current_grid.y
	if not bool(network.send_inventory_transaction_request(request)):
		if world != null and world.has_method("show_notification"):
			world.show_notification("That Donation Box action could not be sent.")
		return false
	return true


func add_inventory_item_to_donation_box(item_type: String, category: String, amount: int) -> bool:
	if not is_donation_box_open():
		return false
	return send_donation_box_request({
		"action": "donation_box_donate",
		"item_id": item_type,
		"item_type": item_type,
		"item_category": category,
		"amount": max(1, amount)
	})


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action := str(data.get("action", "")).strip_edges().to_lower()
	if not action.begins_with("donation_box_"):
		return false
	if not donation_box_open_requested:
		return true
	var state_value = data.get("donation_box_state", {})
	if state_value is Dictionary and not state_value.is_empty():
		apply_donation_box_state(state_value)
	var message := str(data.get("message", "")).strip_edges()
	if message != "" and world != null and world.has_method("show_notification"):
		world.show_notification(message)
	refresh_ui()
	return true


func handle_donation_box_state(data: Dictionary):
	if not donation_box_open_requested:
		return
	if int(data.get("x", 999999)) != current_grid.x or int(data.get("y", 999999)) != current_grid.y:
		return
	apply_donation_box_state(data.get("state", data) if data.get("state", data) is Dictionary else {})
	refresh_ui()


func handle_donation_box_visual_state(data: Dictionary):
	if not donation_box_open_requested:
		return
	if int(data.get("x", 999999)) != current_grid.x or int(data.get("y", 999999)) != current_grid.y:
		return
	current_state["donation_count"] = maxi(0, int(data.get("donation_count", 0)))
	current_state["has_donations"] = bool(data.get("has_donations", false))
	refresh_ui()
	if can_manage():
		request_donation_box_state()


func apply_donation_box_state(state_value: Dictionary):
	current_state = state_value.duplicate(true)
	if not (current_state.get("donations", []) is Array):
		current_state["donations"] = []
	if world != null:
		world.donation_box_states[current_grid] = {"state": current_state.duplicate(true)}
		if world.has_method("update_donation_box_visual"):
			world.update_donation_box_visual(current_grid)


func get_donations() -> Array:
	var donations = current_state.get("donations", [])
	return donations if donations is Array else []


func can_manage() -> bool:
	return bool(current_state.get("can_manage", false))


func refresh_ui():
	if donations_root == null:
		return
	for child in donations_root.get_children():
		donations_root.remove_child(child)
		child.queue_free()

	var donation_count: int = maxi(int(current_state.get("donation_count", 0)), get_donations().size())
	var max_donations: int = maxi(1, int(current_state.get("max_donations", 30)))
	if status_label != null:
		status_label.text = str(donation_count) + " / " + str(max_donations) + " DONATIONS"
	if hint_label != null:
		hint_label.text = "Click an item to retrieve it." if can_manage() else public_privacy_text
	if retrieve_all_button != null:
		retrieve_all_button.visible = can_manage()
		retrieve_all_button.disabled = donation_count <= 0
	if donate_button != null:
		donate_button.disabled = donation_count >= max_donations

	if not can_manage():
		add_center_message(public_privacy_text)
		return
	var donations := get_donations()
	if donations.is_empty():
		add_center_message(empty_owner_text)
		return

	var available_width: float = maxf(1.0, donations_scroll.size.x - 20.0)
	var columns: int = clampi(int(floor((available_width + card_gap) / (donation_card_width + card_gap))), 2, maximum_columns)
	var rows := int(ceil(float(donations.size()) / float(columns)))
	donations_root.size = Vector2(available_width, max(donations_scroll.size.y, float(rows) * donation_card_height + float(max(0, rows - 1)) * card_gap))
	donations_root.custom_minimum_size = donations_root.size
	for index in range(donations.size()):
		var entry = donations[index]
		if entry is Dictionary:
			donations_root.add_child(make_donation_card(index, entry, columns))


func add_center_message(message: String):
	var label := Label.new()
	label.text = message
	label.position = Vector2(24, max(18.0, donations_scroll.size.y * 0.32))
	label.size = Vector2(max(100.0, donations_scroll.size.x - 48.0), 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(label, 18)
	donations_root.add_child(label)


func make_donation_card(index: int, entry: Dictionary, columns: int) -> Button:
	var button := Button.new()
	button.name = "Donation" + str(index)
	button.size = Vector2(donation_card_width, donation_card_height)
	button.position = Vector2(float(index % columns) * (donation_card_width + card_gap), float(index / columns) * (donation_card_height + card_gap))
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(card_fill_color, card_border_color, 3, 9, 7))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(card_fill_color.lightened(0.10), accent_border_color, 4, 9, 9))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(card_fill_color.darkened(0.14), accent_color, 3, 9, 5))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.pressed.connect(_on_donation_pressed.bind(str(entry.get("donation_id", ""))))

	var item_id := str(entry.get("item_id", entry.get("item_type", "")))
	var category := str(entry.get("item_category", "block"))
	var icon := TextureRect.new()
	icon.position = Vector2(12, 12)
	icon.size = Vector2(62, 62)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.has_method("get_item_texture"):
		icon.texture = world.get_item_texture(item_id, category)
	button.add_child(icon)

	var item_name := item_id.replace("_", " ").capitalize()
	if world != null and world.has_method("get_item_display_name"):
		item_name = world.get_item_display_name(item_id, category)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.position = Vector2(82, 13)
	name_label.size = Vector2(max(60.0, donation_card_width - 92.0), 42)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 14)
	button.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = "x" + str(max(1, int(entry.get("amount", 1))))
	amount_label.position = Vector2(82, 57)
	amount_label.size = Vector2(max(60.0, donation_card_width - 92.0), 24)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(amount_label, 17)
	amount_label.add_theme_color_override("font_color", accent_border_color)
	button.add_child(amount_label)

	var donor_label := Label.new()
	donor_label.text = "FROM " + str(entry.get("donor_name", entry.get("donor_username", "PLAYER"))).to_upper()
	donor_label.position = Vector2(10, donation_card_height - 46.0)
	donor_label.size = Vector2(donation_card_width - 20.0, 18)
	donor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	donor_label.clip_text = true
	donor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(donor_label, 11)
	button.add_child(donor_label)

	var action_label := Label.new()
	action_label.text = "RETRIEVE"
	action_label.position = Vector2(8, donation_card_height - 27.0)
	action_label.size = Vector2(donation_card_width - 16.0, 20)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(action_label, 12)
	button.add_child(action_label)
	return button


func _on_donate_pressed():
	if world != null and world.has_method("begin_donation_box_item_select"):
		world.begin_donation_box_item_select()


func _on_retrieve_all_pressed():
	if not can_manage():
		return
	send_donation_box_request({"action": "donation_box_retrieve_all"})


func _on_donation_pressed(donation_id: String):
	if not can_manage() or donation_id == "":
		return
	send_donation_box_request({
		"action": "donation_box_retrieve",
		"donation_id": donation_id
	})
