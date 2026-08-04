extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const MAX_SAFE_SLOTS := 10
const SAFE_HEADER_HEIGHT := 78.0
const SAFE_SLOT_COLUMNS := 5
const SLOT_SIZE := Vector2(190, 126)
const SLOT_GAP := Vector2(16, 16)
const SAFE_PANEL_RADIUS := 18
const SAFE_SCROLLBAR_GUTTER := 32.0

var world = null
var ui_layer_ref = null

var overlay = null
var panel_shadow = null
var panel = null
var status_label = null
var slots_scroll = null
var slots_root = null
var withdraw_popup = null
var withdraw_amount_input = null
var withdraw_amount_slider = null
var withdraw_slot_index := -1
var withdraw_max_amount := 1
var withdraw_amount_updating := false

var current_grid := Vector2i.ZERO
var current_state := {}
var safe_open_requested := false


func _ready():
	if not safe_open_requested:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if overlay != null:
			overlay.visible = false
		if panel != null:
			panel.visible = false


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	safe_open_requested = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 146
	build_ui()
	close_safe()


func _process(_delta):
	if visible:
		update_position()


func get_safe_viewport_size() -> Vector2:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


func get_safe_margin_x(screen_size: Vector2) -> float:
	return clamp(screen_size.x * 0.035, 26.0, 76.0)


func format_safe_number(value: int) -> String:
	var digits = str(max(0, value))
	var result = ""
	var group_count = 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1
	return result


func fit_safe_text(value: String, max_chars: int) -> String:
	var clean_value = value.strip_edges()
	if clean_value.length() <= max_chars:
		return clean_value
	return clean_value.substr(0, max(1, max_chars - 3)).strip_edges() + "..."


func apply_safe_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		return
	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		return
	PixelUIStyle.apply_blue_button(button, font_size)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func apply_safe_slot_style(button: Button, is_filled: bool):
	if button == null:
		return
	var fill = Color(0.18, 0.32, 0.43, 0.42)
	var border = Color(0.72, 0.92, 1.0, 0.46)
	if not is_filled:
		fill = Color(0.12, 0.24, 0.34, 0.30)
		border = Color(0.42, 0.78, 1.0, 0.44)
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(fill, border, 4, 8, 7))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(fill.r + 0.05, fill.g + 0.06, fill.b + 0.07, min(fill.a + 0.18, 0.78)), Color(0.60, 0.92, 1.0, 0.74), 4, 8, 9))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.08, 0.18, 0.27, 0.62), Color(0.20, 0.52, 0.86, 0.80), 4, 8, 4))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))


func apply_safe_scrollbar_style():
	if slots_scroll == null:
		return
	var scrollbar = slots_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func get_safe_columns() -> int:
	var available_width: float = 5.0 * SLOT_SIZE.x + 4.0 * SLOT_GAP.x
	if slots_scroll != null:
		available_width = max(0.0, slots_scroll.size.x - SAFE_SCROLLBAR_GUTTER)
	return clamp(int(floor((available_width + SLOT_GAP.x) / (SLOT_SIZE.x + SLOT_GAP.x))), 2, SAFE_SLOT_COLUMNS)


func build_ui():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		child.queue_free()
	withdraw_popup = null
	withdraw_amount_input = null
	withdraw_amount_slider = null

	var screen_size = get_safe_viewport_size()
	var panel_size = Vector2(
		min(1100.0, max(620.0, screen_size.x - 80.0)),
		min(560.0, max(430.0, screen_size.y - 96.0))
	)
	var margin_x = 34.0
	var content_width = max(420.0, panel_size.x - margin_x * 2.0)
	var grid_y = SAFE_HEADER_HEIGHT + 72.0
	if panel_size.y < 520.0:
		grid_y = SAFE_HEADER_HEIGHT + 42.0
	var storage_height = max(258.0, panel_size.y - grid_y - 30.0)

	overlay = ColorRect.new()
	overlay.name = "SafeOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel_shadow = Panel.new()
	panel_shadow.name = "SafePanelShadow"
	panel_shadow.position = Vector2.ZERO
	panel_shadow.size = panel_size
	panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		0, SAFE_PANEL_RADIUS, 22
	))
	add_child(panel_shadow)

	panel = Control.new()
	panel.name = "SafePanel"
	panel.position = Vector2.ZERO
	panel.size = panel_size
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, SAFE_PANEL_RADIUS, 16
	))
	panel.add_child(panel_back)

	var panel_gloss = Panel.new()
	panel_gloss.name = "PanelGloss"
	panel_gloss.position = Vector2(8, 8)
	panel_gloss.size = Vector2(panel_size.x - 16.0, 54)
	panel_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_gloss.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(1.0, 1.0, 1.0, 0.035),
		Color(1.0, 1.0, 1.0, 0.0),
		0, SAFE_PANEL_RADIUS - 4, 0
	))
	panel.add_child(panel_gloss)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(panel_size.x, SAFE_HEADER_HEIGHT)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0, SAFE_PANEL_RADIUS, 8
	))
	panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, SAFE_HEADER_HEIGHT - 5.0)
	top_line.size = Vector2(panel_size.x, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "SAFE"
	title.position = Vector2(margin_x, 6)
	title.size = Vector2(min(420.0, panel_size.x * 0.42), 66)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 56 if panel_size.x >= 1000.0 else 42)
	panel.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "OWNER STORAGE"
	title_sub.position = Vector2(margin_x + 6.0, 60)
	title_sub.size = Vector2(240, 22)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	panel.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(panel_size.x - margin_x - close_button.size.x, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_safe_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_safe)
	panel.add_child(close_button)

	var chip_width = 276.0 if panel_size.x >= 960.0 else 236.0
	var status_chip = Panel.new()
	status_chip.name = "StatusChip"
	status_chip.position = Vector2(close_button.position.x - chip_width - 14.0, 14)
	status_chip.size = Vector2(chip_width, 48)
	status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 14, 8
	))
	panel.add_child(status_chip)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = status_chip.position + Vector2(18, 7)
	status_label.size = Vector2(chip_width - 36.0, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status_label, 18, Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(status_label)

	var card = Panel.new()
	card.name = "SafeCard"
	card.position = Vector2(margin_x, grid_y)
	card.size = Vector2(content_width, storage_height)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3, 14, 10
	))
	panel.add_child(card)

	var card_title = Label.new()
	card_title.name = "CardTitle"
	card_title.text = "* STORAGE"
	card_title.position = Vector2(18, 10)
	card_title.size = Vector2(260, 30)
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(card_title, 24)
	card.add_child(card_title)

	var hint = Label.new()
	hint.name = "Hint"
	hint.text = "Choose an empty slot to add items, or choose a stored item to withdraw it."
	hint.position = Vector2(286, 13)
	hint.size = Vector2(max(120.0, card.size.x - 304.0), 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(hint, 13)
	card.add_child(hint)

	var divider = ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(18, 46)
	divider.size = Vector2(card.size.x - 36.0, 3)
	divider.color = Color(0.42, 0.82, 1.0, 0.34)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(divider)

	slots_scroll = ScrollContainer.new()
	slots_scroll.name = "SafeScroll"
	slots_scroll.position = Vector2(18, 62)
	slots_scroll.size = Vector2(card.size.x - 36.0 - SAFE_SCROLLBAR_GUTTER, card.size.y - 88.0)
	slots_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	slots_scroll.clip_contents = true
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slots_scroll.clip_contents = true
	card.add_child(slots_scroll)

	slots_root = Control.new()
	slots_root.name = "SlotsRoot"
	slots_root.position = Vector2.ZERO
	slots_root.size = slots_scroll.size
	slots_root.custom_minimum_size = slots_scroll.size
	slots_root.clip_contents = true
	slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_scroll.add_child(slots_root)
	apply_safe_scrollbar_style()


func update_position():
	if panel == null:
		return
	var screen_size = get_safe_viewport_size()
	var panel_position = Vector2(
		floor((screen_size.x - panel.size.x) * 0.5),
		floor(max(40.0, (screen_size.y - panel.size.y) * 0.5))
	)
	panel.position = panel_position
	if panel_shadow != null:
		panel_shadow.position = panel_position


func open_safe(grid_pos: Vector2i):
	safe_open_requested = true
	current_grid = grid_pos
	current_state = {}
	if world != null and world.safe_states.has(current_grid):
		current_state = world.safe_states[current_grid].duplicate(true)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel_shadow != null:
		panel_shadow.visible = true
	if panel != null:
		panel.visible = true
	refresh_ui()
	request_safe_state()


func close_safe():
	safe_open_requested = false
	hide_withdraw_popup()
	if world != null and world.has_method("is_safe_item_selecting") and world.is_safe_item_selecting():
		world.end_safe_item_select(true)
	current_state.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel_shadow != null:
		panel_shadow.visible = false
	if panel != null:
		panel.visible = false


func is_safe_open() -> bool:
	return safe_open_requested and visible


func request_safe_state():
	send_safe_request({
		"action": "safe_get_state"
	})


func send_safe_request(payload: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_inventory_transaction_request"):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Connection required.")
		return false

	var request = payload.duplicate(true)
	request["world"] = world.current_world_name
	request["x"] = current_grid.x
	request["y"] = current_grid.y
	if not bool(network.send_inventory_transaction_request(request)):
		if world != null and world.has_method("show_notification"):
			world.show_notification("That action could not be completed.")
		return false
	return true


func add_inventory_item_to_safe(item_type: String, category: String, amount: int) -> bool:
	if not visible:
		return false
	if not can_manage_current_safe():
		if world != null:
			world.show_notification("Only the world owner can use this safe.")
		return false
	if get_slots().size() >= get_max_slots() and find_merge_slot(item_type, category, amount) < 0:
		if world != null:
			world.show_notification("That safe is full.")
		return false

	return send_safe_request({
		"action": "safe_deposit",
		"item_type": item_type,
		"item_id": item_type,
		"item_category": category,
		"amount": max(1, amount),
	})


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action = str(data.get("action", ""))
	if not action.begins_with("safe_"):
		return false
	if not safe_open_requested:
		return true

	var safe_state = data.get("safe_state", {})
	if safe_state is Dictionary and not safe_state.is_empty():
		apply_safe_state(safe_state)

	var message = str(data.get("message", "")).strip_edges()
	if message != "" and world != null and world.has_method("show_notification"):
		world.show_notification(message)

	refresh_ui()
	return true


func handle_safe_state(data: Dictionary):
	if not safe_open_requested:
		return
	var x = int(data.get("x", 999999))
	var y = int(data.get("y", 999999))
	if x != current_grid.x or y != current_grid.y:
		return
	apply_safe_state(data)
	refresh_ui()


func apply_safe_state(data: Dictionary):
	current_state = data.duplicate(true)
	if not (current_state.get("slots", []) is Array):
		current_state["slots"] = []


func get_slots() -> Array:
	var slots = current_state.get("slots", [])
	if slots is Array:
		return slots
	return []


func get_max_slots() -> int:
	return clamp(int(current_state.get("max_slots", MAX_SAFE_SLOTS)), 1, MAX_SAFE_SLOTS)


func can_manage_current_safe() -> bool:
	if current_state.is_empty():
		return true
	return bool(current_state.get("can_manage", true))


func find_merge_slot(item_type: String, category: String, amount: int) -> int:
	var slots = get_slots()
	var stack_limit = 400
	if world != null and world.has_method("get_stack_limit_for_item"):
		stack_limit = world.get_stack_limit_for_item(item_type, category)
	for i in range(slots.size()):
		var slot = slots[i]
		if not (slot is Dictionary):
			continue
		if str(slot.get("item_id", "")) == item_type and str(slot.get("item_category", "")) == category:
			if int(slot.get("amount", 0)) + amount <= stack_limit:
				return i
	return -1


func refresh_ui():
	if slots_root == null:
		return

	for child in slots_root.get_children():
		slots_root.remove_child(child)
		child.queue_free()

	var slots = get_slots()
	var max_slots = get_max_slots()
	var shown_slots = min(max_slots, slots.size() + 1)
	if shown_slots <= 0:
		shown_slots = 1
	if slots.size() >= max_slots:
		shown_slots = max_slots

	if status_label != null:
		if can_manage_current_safe():
			status_label.text = str(slots.size()) + " / " + str(max_slots) + " SLOTS USED"
		else:
			status_label.text = "WORLD OWNER ONLY"

	var columns = get_safe_columns()
	var rows = max(1, int(ceil(float(shown_slots) / float(columns))))
	var grid_size = Vector2(
		float(columns) * SLOT_SIZE.x + float(columns - 1) * SLOT_GAP.x,
		float(rows) * SLOT_SIZE.y + float(rows - 1) * SLOT_GAP.y
	)
	if slots_root != null:
		var scroll_width = slots_scroll.size.x if slots_scroll != null else grid_size.x
		var scroll_height = slots_scroll.size.y if slots_scroll != null else grid_size.y
		var root_width = max(grid_size.x, scroll_width - SAFE_SCROLLBAR_GUTTER)
		var root_height = max(grid_size.y, slots_scroll.size.y if slots_scroll != null else grid_size.y)
		slots_root.size = Vector2(root_width, root_height)
		slots_root.custom_minimum_size = slots_root.size
		if slots_scroll != null:
			slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if grid_size.y > scroll_height else ScrollContainer.SCROLL_MODE_DISABLED

	for i in range(shown_slots):
		var slot_data = {}
		if i < slots.size() and slots[i] is Dictionary:
			slot_data = slots[i]
		var slot_button = make_slot_button(i, slot_data)
		slots_root.add_child(slot_button)


func make_slot_button(slot_index: int, slot_data: Dictionary) -> Button:
	var button = Button.new()
	button.name = "SafeSlot" + str(slot_index)
	button.size = SLOT_SIZE
	button.clip_contents = true
	var columns = get_safe_columns()
	var col = slot_index % columns
	var row = int(floor(float(slot_index) / float(columns)))
	button.position = Vector2(col * (SLOT_SIZE.x + SLOT_GAP.x), row * (SLOT_SIZE.y + SLOT_GAP.y))
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_on_slot_pressed.bind(slot_index))

	var is_filled = not slot_data.is_empty()
	apply_safe_slot_style(button, is_filled)

	var card_shine = ColorRect.new()
	card_shine.name = "CardShine"
	card_shine.position = Vector2(5, 5)
	card_shine.size = Vector2(button.size.x - 10.0, 2)
	card_shine.color = Color(1.0, 1.0, 1.0, 0.10)
	card_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card_shine)

	if is_filled:
		var item_id = str(slot_data.get("item_id", ""))
		var category = str(slot_data.get("item_category", "block"))
		var item_name = world.get_item_display_name(item_id, category) if world != null and world.has_method("get_item_display_name") else item_id

		var icon_back = Panel.new()
		icon_back.name = "IconBack"
		icon_back.position = Vector2(14, 16)
		icon_back.size = Vector2(72, 72)
		icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.18, 0.32, 0.43, 0.42),
			Color(0.72, 0.92, 1.0, 0.46),
			2, 6, 2
		))
		button.add_child(icon_back)

		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(18, 18)
		icon.size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if world != null and world.has_method("get_item_texture"):
			icon.texture = world.get_item_texture(item_id, category)
		button.add_child(icon)

		var name_label = Label.new()
		name_label.name = "Name"
		name_label.text = fit_safe_text(item_name, 12)
		name_label.position = Vector2(96, 20)
		name_label.size = Vector2(button.size.x - 108.0, 26)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(name_label, 15)
		button.add_child(name_label)

		var meta_label = Label.new()
		meta_label.name = "Meta"
		meta_label.text = fit_safe_text(category.capitalize(), 10)
		meta_label.position = Vector2(98, 48)
		meta_label.size = Vector2(button.size.x - 110.0, 20)
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		meta_label.clip_text = true
		meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(meta_label, 12)
		meta_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55, 1.0))
		button.add_child(meta_label)

		var amount_label = Label.new()
		amount_label.name = "Amount"
		amount_label.text = "x" + format_safe_number(int(slot_data.get("amount", 1)))
		amount_label.position = Vector2(96, 70)
		amount_label.size = Vector2(button.size.x - 108.0, 24)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(amount_label, 17)
		button.add_child(amount_label)

		var action_bar = Panel.new()
		action_bar.name = "ActionBar"
		action_bar.position = Vector2(6, button.size.y - 38.0)
		action_bar.size = Vector2(button.size.x - 12.0, 32)
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.10, 0.34, 0.68, 0.96),
			Color(0.38, 0.78, 1.0, 0.65),
			2, 5, 3
		))
		button.add_child(action_bar)

		var action_label = Label.new()
		action_label.name = "ActionLabel"
		action_label.text = "WITHDRAW"
		action_label.position = action_bar.position
		action_label.size = action_bar.size
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(action_label, 14)
		button.add_child(action_label)
	else:
		var plus_label = Label.new()
		plus_label.name = "Plus"
		plus_label.text = "+"
		plus_label.position = Vector2(0, 20)
		plus_label.size = Vector2(SLOT_SIZE.x, 48)
		plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(plus_label, 38)
		plus_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 0.95))
		button.add_child(plus_label)

		var add_label = Label.new()
		add_label.name = "AddLabel"
		add_label.text = "ADD ITEM"
		add_label.position = Vector2(8, 72)
		add_label.size = Vector2(button.size.x - 16.0, 24)
		add_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(add_label, 14)
		button.add_child(add_label)

		var action_bar = Panel.new()
		action_bar.name = "ActionBar"
		action_bar.position = Vector2(6, button.size.y - 38.0)
		action_bar.size = Vector2(button.size.x - 12.0, 32)
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.14, 0.86, 0.06, 0.98),
			Color(0.035, 0.34, 0.02, 1.0),
			3, 5, 4
		))
		button.add_child(action_bar)

		var action_label = Label.new()
		action_label.name = "ActionLabel"
		action_label.text = "STORE"
		action_label.position = action_bar.position
		action_label.size = action_bar.size
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(action_label, 14)
		button.add_child(action_label)

	return button


func hide_withdraw_popup():
	withdraw_slot_index = -1
	withdraw_max_amount = 1
	withdraw_amount_updating = false
	withdraw_amount_input = null
	withdraw_amount_slider = null
	if withdraw_popup != null:
		withdraw_popup.queue_free()
		withdraw_popup = null


func show_withdraw_popup(slot_index: int, slot_data: Dictionary):
	hide_withdraw_popup()
	withdraw_slot_index = slot_index
	withdraw_max_amount = max(1, int(slot_data.get("amount", 1)))

	var popup_size = Vector2(430, 294)
	if panel != null:
		popup_size.x = min(popup_size.x, panel.size.x - 54.0)
	withdraw_popup = Panel.new()
	withdraw_popup.name = "WithdrawPopup"
	withdraw_popup.size = popup_size
	withdraw_popup.position = (panel.size - popup_size) * 0.5 if panel != null else Vector2(220, 150)
	withdraw_popup.z_index = 40
	withdraw_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	withdraw_popup.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 12, 10
	))
	panel.add_child(withdraw_popup)

	var header = Panel.new()
	header.name = "PopupHeader"
	header.position = Vector2.ZERO
	header.size = Vector2(popup_size.x, 56)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0, 0, 8
	))
	withdraw_popup.add_child(header)

	var title = Label.new()
	title.name = "PopupTitle"
	title.text = "WITHDRAW"
	title.position = Vector2(22, 7)
	title.size = Vector2(popup_size.x - 92.0, 42)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 30)
	withdraw_popup.add_child(title)

	var close_button = Button.new()
	close_button.name = "PopupClose"
	close_button.text = "X"
	close_button.size = Vector2(42, 38)
	close_button.position = Vector2(popup_size.x - 54.0, 9)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_safe_arcade_button_style(close_button, false, true, 20)
	close_button.pressed.connect(hide_withdraw_popup)
	withdraw_popup.add_child(close_button)

	var item_id = str(slot_data.get("item_id", ""))
	var category = str(slot_data.get("item_category", "block"))
	var item_name = item_id
	if world != null and world.has_method("get_item_display_name"):
		item_name = world.get_item_display_name(item_id, category)

	var icon_back = Panel.new()
	icon_back.name = "PopupIconBack"
	icon_back.position = Vector2(28, 78)
	icon_back.size = Vector2(82, 82)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		3, 8, 4
	))
	withdraw_popup.add_child(icon_back)

	var icon = TextureRect.new()
	icon.name = "PopupIcon"
	icon.position = Vector2(35, 85)
	icon.size = Vector2(68, 68)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.has_method("get_item_texture"):
		icon.texture = world.get_item_texture(item_id, category)
	withdraw_popup.add_child(icon)

	var item_label = Label.new()
	item_label.name = "PopupItemName"
	item_label.text = item_name
	item_label.position = Vector2(128, 82)
	item_label.size = Vector2(popup_size.x - 152.0, 32)
	item_label.clip_text = true
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(item_label, 19)
	withdraw_popup.add_child(item_label)

	var available_label = Label.new()
	available_label.name = "PopupAvailable"
	available_label.text = "Stored: x" + format_safe_number(withdraw_max_amount)
	available_label.position = Vector2(130, 116)
	available_label.size = Vector2(popup_size.x - 154.0, 24)
	available_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(available_label, 13)
	available_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0, 1.0))
	withdraw_popup.add_child(available_label)

	var amount_label = Label.new()
	amount_label.name = "PopupAmountLabel"
	amount_label.text = "AMOUNT"
	amount_label.position = Vector2(28, 176)
	amount_label.size = Vector2(90, 26)
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(amount_label, 13)
	withdraw_popup.add_child(amount_label)

	withdraw_amount_input = LineEdit.new()
	withdraw_amount_input.name = "WithdrawAmountInput"
	withdraw_amount_input.position = Vector2(128, 174)
	withdraw_amount_input.size = Vector2(popup_size.x - 156.0, 34)
	withdraw_amount_input.text = str(withdraw_max_amount)
	withdraw_amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	withdraw_amount_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(withdraw_amount_input, 16)
	withdraw_amount_input.text_changed.connect(_on_withdraw_amount_text_changed)
	withdraw_popup.add_child(withdraw_amount_input)

	withdraw_amount_slider = HSlider.new()
	withdraw_amount_slider.name = "WithdrawAmountSlider"
	withdraw_amount_slider.position = Vector2(28, 218)
	withdraw_amount_slider.size = Vector2(popup_size.x - 56.0, 24)
	withdraw_amount_slider.min_value = 1.0
	withdraw_amount_slider.max_value = float(withdraw_max_amount)
	withdraw_amount_slider.step = 1.0
	withdraw_amount_slider.value = float(withdraw_max_amount)
	withdraw_amount_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	withdraw_amount_slider.value_changed.connect(_on_withdraw_amount_slider_changed)
	withdraw_popup.add_child(withdraw_amount_slider)

	var withdraw_button = Button.new()
	withdraw_button.name = "ConfirmWithdraw"
	withdraw_button.text = "WITHDRAW"
	withdraw_button.position = Vector2(28, popup_size.y - 48.0)
	withdraw_button.size = Vector2((popup_size.x - 70.0) * 0.58, 34)
	withdraw_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_safe_arcade_button_style(withdraw_button, true, false, 14)
	withdraw_button.pressed.connect(_confirm_safe_withdraw)
	withdraw_popup.add_child(withdraw_button)

	var cancel_button = Button.new()
	cancel_button.name = "CancelWithdraw"
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(withdraw_button.position.x + withdraw_button.size.x + 14.0, popup_size.y - 48.0)
	cancel_button.size = Vector2(popup_size.x - cancel_button.position.x - 28.0, 34)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_safe_arcade_button_style(cancel_button, false, false, 14)
	cancel_button.pressed.connect(hide_withdraw_popup)
	withdraw_popup.add_child(cancel_button)


func _on_withdraw_amount_slider_changed(value: float):
	if withdraw_amount_updating:
		return
	set_withdraw_amount_value(int(round(value)), true)


func _on_withdraw_amount_text_changed(new_text: String):
	if withdraw_amount_updating:
		return
	var digits = ""
	for i in range(new_text.length()):
		var character = new_text.substr(i, 1)
		if character.is_valid_int():
			digits += character
	if digits == "":
		return
	set_withdraw_amount_value(int(digits), false)


func set_withdraw_amount_value(amount: int, update_text: bool):
	var value = clamp(amount, 1, withdraw_max_amount)
	withdraw_amount_updating = true
	if withdraw_amount_slider != null:
		withdraw_amount_slider.value = float(value)
	if withdraw_amount_input != null and update_text:
		withdraw_amount_input.text = str(value)
	withdraw_amount_updating = false


func get_withdraw_amount() -> int:
	if withdraw_amount_input == null:
		return withdraw_max_amount
	var text_value = withdraw_amount_input.text.strip_edges()
	if text_value == "" or not text_value.is_valid_int():
		return withdraw_max_amount
	return clamp(int(text_value), 1, withdraw_max_amount)


func _confirm_safe_withdraw():
	var slots = get_slots()
	if withdraw_slot_index < 0 or withdraw_slot_index >= slots.size():
		hide_withdraw_popup()
		return
	var slot = slots[withdraw_slot_index]
	if not (slot is Dictionary):
		hide_withdraw_popup()
		return
	var item_id = str(slot.get("item_id", ""))
	var category = str(slot.get("item_category", "block"))
	if item_id == "":
		hide_withdraw_popup()
		return
	var amount = get_withdraw_amount()
	if send_safe_request({
		"action": "safe_withdraw",
		"slot_index": withdraw_slot_index,
		"item_type": item_id,
		"item_id": item_id,
		"item_category": category,
		"amount": amount,
	}):
		hide_withdraw_popup()


func _on_slot_pressed(slot_index: int):
	if not can_manage_current_safe():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Only the world owner can use this safe.")
		return

	var slots = get_slots()
	if slot_index < slots.size():
		var slot = slots[slot_index]
		if not (slot is Dictionary):
			return
		show_withdraw_popup(slot_index, slot)
		return

	if slots.size() >= get_max_slots():
		if world != null and world.has_method("show_notification"):
			world.show_notification("That safe is full.")
		return

	if world != null and world.has_method("begin_safe_item_select"):
		world.begin_safe_item_select()
