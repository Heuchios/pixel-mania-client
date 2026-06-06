extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const FISH_MONGER_W := 840.0
const FISH_MONGER_H := 560.0
const FISH_MONGER_HEADER_H := 78.0
const FISH_MONGER_SCROLL_GUTTER := 24.0

var world = null
var ui_layer_ref = null
var current_grid: Vector2i = Vector2i(999999, 999999)
var panel = null
var gem_label = null
var fish_scroll = null
var fish_rows_root = null
var sell_all_button = null
var empty_label = null
var last_panel_viewport_size := Vector2.ZERO


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 135
	build_ui()
	close_fish_monger()


func _process(_delta):
	if not visible:
		return

	var viewport_size = get_viewport_rect().size
	if viewport_size != last_panel_viewport_size:
		update_panel_position()
	update_header()


func build_ui():
	for child in get_children():
		child.queue_free()

	panel = Control.new()
	panel.name = "FishMongerPanel"
	panel.size = Vector2(FISH_MONGER_W, FISH_MONGER_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		22,
		0
	))
	panel.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		22,
		12
	))
	panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(FISH_MONGER_W, FISH_MONGER_HEADER_H)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		22,
		8
	))
	panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, FISH_MONGER_HEADER_H - 5.0)
	top_line.size = Vector2(FISH_MONGER_W, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "FISH MONGER"
	title.position = Vector2(34, 8)
	title.size = Vector2(390, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 44)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "SELL FISH"
	subtitle.position = Vector2(40, 58)
	subtitle.size = Vector2(360, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 14)
	panel.add_child(subtitle)

	var gem_chip = Panel.new()
	gem_chip.name = "GemChip"
	gem_chip.position = Vector2(FISH_MONGER_W - 346, 17)
	gem_chip.size = Vector2(250, 44)
	gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		14,
		7
	))
	panel.add_child(gem_chip)

	var gem_icon = TextureRect.new()
	gem_icon.name = "GemIcon"
	gem_icon.position = Vector2(14, 9)
	gem_icon.size = Vector2(26, 26)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		gem_icon.texture = world.currency_textures["gem"]
	gem_chip.add_child(gem_icon)

	gem_label = Label.new()
	gem_label.name = "GemLabel"
	gem_label.position = Vector2(46, 7)
	gem_label.size = Vector2(192, 30)
	gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(gem_label, 18, PixelUIStyle.GOLD_SOFT)
	gem_chip.add_child(gem_label)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(FISH_MONGER_W - 84, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_fish_monger_arcade_button_style(close_button, false, true, 24)
	close_button.text = "X"
	close_button.pressed.connect(close_fish_monger)
	panel.add_child(close_button)

	var info_card = Panel.new()
	info_card.name = "InfoCard"
	info_card.position = Vector2(32, 96)
	info_card.size = Vector2(FISH_MONGER_W - 64, 58)
	info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		3,
		12,
		5
	))
	panel.add_child(info_card)

	var info = Label.new()
	info.name = "Info"
	info.text = "Prices are based on each fish's weight and gems per lb"
	info.position = Vector2(52, 112)
	info.size = Vector2(520, 26)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(info, 16)
	panel.add_child(info)

	sell_all_button = Button.new()
	sell_all_button.name = "SellAllButton"
	sell_all_button.text = "SELL ALL"
	sell_all_button.position = Vector2(FISH_MONGER_W - 214, 105)
	sell_all_button.size = Vector2(156, 40)
	sell_all_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_fish_monger_arcade_button_style(sell_all_button, true, false, 15)
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	panel.add_child(sell_all_button)

	var scroll_back = Panel.new()
	scroll_back.name = "ScrollBack"
	scroll_back.position = Vector2(32, 168)
	scroll_back.size = Vector2(FISH_MONGER_W - 64, 350)
	scroll_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		5
	))
	panel.add_child(scroll_back)

	fish_scroll = ScrollContainer.new()
	fish_scroll.name = "FishScroll"
	fish_scroll.position = Vector2(40, 176)
	fish_scroll.size = Vector2(FISH_MONGER_W - 80, 334)
	fish_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fish_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	fish_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	fish_scroll.clip_contents = true
	panel.add_child(fish_scroll)

	fish_rows_root = Control.new()
	fish_rows_root.name = "FishRows"
	fish_rows_root.position = Vector2.ZERO
	fish_rows_root.size = Vector2(get_fish_row_content_width(), fish_scroll.size.y)
	fish_rows_root.custom_minimum_size = fish_rows_root.size
	fish_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_rows_root.clip_contents = true
	fish_scroll.add_child(fish_rows_root)

	empty_label = Label.new()
	empty_label.name = "EmptyState"
	empty_label.text = "You don't have any fish to sell yet. Go fishing!"
	empty_label.position = Vector2(52, 304)
	empty_label.size = Vector2(FISH_MONGER_W - 104, 42)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(empty_label, 20, PixelUIStyle.TEXT_SOFT)
	panel.add_child(empty_label)

	call_deferred("apply_fish_monger_scrollbar_style")
	update_panel_position()


func apply_fish_monger_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.56), Color(0.10, 0.0, 0.02, 0.62), 3, 12, 3))
		return
	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return
	PixelUIStyle.apply_blue_button(button, font_size)


func apply_fish_monger_input_style(line_edit: LineEdit, font_size: int = 17):
	if line_edit == null:
		return

	PixelUIStyle.apply_input(line_edit, font_size)


func apply_fish_monger_scrollbar_style():
	if fish_scroll == null:
		return

	var scrollbar = fish_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func get_fish_row_content_width() -> float:
	if fish_scroll == null:
		return max(1.0, FISH_MONGER_W - 104.0)

	return max(1.0, fish_scroll.size.x - FISH_MONGER_SCROLL_GUTTER)


func open_fish_monger(grid_pos: Vector2i):
	current_grid = grid_pos
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_panel_position()
	refresh()

	if panel != null:
		PixelUIStyle.play_panel_open(panel)


func close_fish_monger():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_panel_viewport_size = Vector2.ZERO


func is_fish_monger_open() -> bool:
	return visible


func update_panel_position():
	if panel == null:
		return

	var screen_size = get_viewport_rect().size
	last_panel_viewport_size = screen_size
	var max_x = max(12.0, screen_size.x - panel.size.x - 12.0)
	var max_y = max(40.0, screen_size.y - panel.size.y - 24.0)
	panel.position = Vector2(
		clamp((screen_size.x - panel.size.x) / 2.0, 12.0, max_x),
		clamp((screen_size.y - panel.size.y) / 2.0, 40.0, max_y)
	)


func update_header():
	if world == null:
		return

	if gem_label != null:
		gem_label.text = world.get_currency_display_text("gem")


func refresh():
	if world == null or fish_rows_root == null:
		return

	var saved_scroll = fish_scroll.scroll_vertical if fish_scroll != null else 0

	update_header()

	for child in fish_rows_root.get_children():
		child.queue_free()

	var entries: Array = []
	if world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_sellable_fish_entries"):
		entries = world.fish_monger_manager.get_sellable_fish_entries()

	var pending = is_sale_pending()
	if sell_all_button != null:
		sell_all_button.disabled = pending or entries.is_empty()

	if empty_label != null:
		empty_label.visible = entries.is_empty()

	if entries.is_empty():
		fish_rows_root.custom_minimum_size = Vector2(get_fish_row_content_width(), fish_scroll.size.y)
		fish_rows_root.size = fish_rows_root.custom_minimum_size
		call_deferred("restore_scroll_position", saved_scroll)
		return

	var row_height = 92.0
	var gap = 12.0
	var content_width = get_fish_row_content_width()
	fish_rows_root.custom_minimum_size = Vector2(
		content_width,
		max(fish_scroll.size.y, entries.size() * (row_height + gap) - gap + 10.0)
	)
	fish_rows_root.size = fish_rows_root.custom_minimum_size

	for i in range(entries.size()):
		create_fish_row(entries[i], Vector2(0, i * (row_height + gap)), row_height, pending)

	call_deferred("restore_scroll_position", saved_scroll)


func restore_scroll_position(scroll_value: int):
	if fish_scroll == null:
		return

	var scrollbar = fish_scroll.get_v_scroll_bar()
	if scrollbar == null:
		fish_scroll.scroll_vertical = scroll_value
		return

	var max_scroll = int(max(0.0, scrollbar.max_value - scrollbar.page))
	fish_scroll.scroll_vertical = clamp(scroll_value, 0, max_scroll)


func create_fish_row(entry: Dictionary, row_position: Vector2, row_height: float, pending: bool):
	var item_id = str(entry.get("item_id", ""))
	var weight_lb = snapped(float(entry.get("weight_lb", entry.get("count", 0.0))), 0.1)
	var price_per_lb = int(entry.get("price_per_lb", entry.get("sell_value", 0)))
	var default_amount = max(0.1, weight_lb)
	var rarity = str(entry.get("rarity", "common"))
	var row_width = max(700.0, get_fish_row_content_width())
	var sell_button_w = 96.0
	var sell_button_x = row_width - sell_button_w - 10.0
	var amount_minus_x = sell_button_x - 124.0
	var amount_input_x = amount_minus_x + 34.0
	var amount_plus_x = amount_input_x + 58.0
	var price_x = amount_minus_x - 144.0
	var name_width = clamp(price_x - 102.0, 160.0, 280.0)

	var row = Panel.new()
	row.name = "FishRow_" + item_id
	row.position = row_position
	row.size = Vector2(row_width, row_height)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.clip_contents = true
	row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.14, 0.27, 0.38, 0.48),
		Color(0.42, 0.78, 1.0, 0.34),
		3,
		12,
		5
	))
	fish_rows_root.add_child(row)

	var icon_back = Panel.new()
	icon_back.name = "IconBack"
	icon_back.position = Vector2(12, 15)
	icon_back.size = Vector2(62, 62)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	row.add_child(icon_back)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(20, 21)
	icon.size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = entry.get("texture", null)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = str(entry.get("display_name", item_id.capitalize()))
	name_label.position = Vector2(88, 14)
	name_label.size = Vector2(name_width, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 19)
	row.add_child(name_label)

	var qty_label = Label.new()
	qty_label.name = "Quantity"
	qty_label.text = "Owned: " + format_weight(weight_lb)
	qty_label.position = Vector2(88, 48)
	qty_label.size = Vector2(140, 22)
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(qty_label, 14)
	row.add_child(qty_label)

	var price_label = Label.new()
	price_label.name = "Price"
	price_label.text = format_gem_amount(price_per_lb) + " gems/lb"
	price_label.position = Vector2(price_x, 16)
	price_label.size = Vector2(138, 24)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(price_label, 15, PixelUIStyle.GOLD_SOFT)
	row.add_child(price_label)

	var total_label = Label.new()
	total_label.name = "Total"
	total_label.text = "Total: " + format_gem_amount(calculate_fish_sale_value(default_amount, price_per_lb)) + " gems"
	total_label.position = Vector2(price_x, 50)
	total_label.size = Vector2(138, 22)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(total_label, 14)
	row.add_child(total_label)

	var amount_control_y := 33.0
	var amount_control_height := 36.0

	var minus_button = Button.new()
	minus_button.name = "AmountMinus"
	minus_button.text = "-"
	minus_button.position = Vector2(amount_minus_x, amount_control_y)
	minus_button.size = Vector2(30, amount_control_height)
	minus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	minus_button.disabled = pending or weight_lb <= 0.1
	apply_fish_monger_arcade_button_style(minus_button, false, false, 18)
	row.add_child(minus_button)

	var amount_input = LineEdit.new()
	amount_input.name = "AmountInput"
	amount_input.text = format_weight_number(default_amount)
	amount_input.placeholder_text = "1.0"
	amount_input.position = Vector2(amount_input_x, amount_control_y)
	amount_input.size = Vector2(54, amount_control_height)
	amount_input.max_length = 8
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_input.mouse_filter = Control.MOUSE_FILTER_STOP
	amount_input.editable = not pending and weight_lb > 0.0
	apply_fish_monger_input_style(amount_input, 17)
	row.add_child(amount_input)

	var plus_button = Button.new()
	plus_button.name = "AmountPlus"
	plus_button.text = "+"
	plus_button.position = Vector2(amount_plus_x, amount_control_y)
	plus_button.size = Vector2(30, amount_control_height)
	plus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	plus_button.disabled = pending or weight_lb <= 0.1
	apply_fish_monger_arcade_button_style(plus_button, false, false, 18)
	row.add_child(plus_button)

	var sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.position = Vector2(sell_button_x, 24)
	sell_button.size = Vector2(sell_button_w, 44)
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_button.disabled = pending or weight_lb <= 0.0 or price_per_lb <= 0
	apply_fish_monger_arcade_button_style(sell_button, true, false, 17)
	sell_button.pressed.connect(_on_sell_pressed.bind(item_id, amount_input, weight_lb))
	row.add_child(sell_button)

	amount_input.text_changed.connect(_on_amount_text_changed.bind(amount_input, total_label, sell_button, weight_lb, price_per_lb, pending))
	amount_input.text_submitted.connect(_on_amount_text_submitted.bind(amount_input, total_label, sell_button, weight_lb, price_per_lb, pending))
	amount_input.focus_exited.connect(_on_amount_focus_exited.bind(amount_input, total_label, sell_button, weight_lb, price_per_lb, pending))
	minus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, weight_lb, price_per_lb, pending, -1.0))
	plus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, weight_lb, price_per_lb, pending, 1.0))


func parse_amount_text(raw_text: String) -> float:
	var clean_text = raw_text.strip_edges()
	if clean_text == "" or not clean_text.is_valid_float():
		return 0.0

	return max(0.0, float(clean_text))


func clamp_sell_amount(amount: float, owned_weight: float) -> float:
	return snapped(min(max(0.1, amount), max(0.1, owned_weight)), 0.1)


func update_amount_summary(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool):
	var amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if amount > owned_weight:
		amount = owned_weight
	var total_gems: int = calculate_fish_sale_value(amount, price_per_lb)

	if total_label != null:
		total_label.text = "Total: " + format_gem_amount(total_gems) + " gems"

	if sell_button != null:
		sell_button.disabled = pending or owned_weight <= 0.0 or price_per_lb <= 0 or amount <= 0.0 or amount > owned_weight or total_gems <= 0


func sanitize_amount_input(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool) -> float:
	var amount = clamp_sell_amount(parse_amount_text(amount_input.text if amount_input != null else ""), owned_weight)
	if amount_input != null:
		amount_input.text = format_weight_number(amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_weight, price_per_lb, pending)
	return amount


func format_gem_amount(amount: int) -> String:
	if world != null and world.has_method("format_currency_amount"):
		return world.format_currency_amount(amount)

	return str(amount)


func format_weight(weight: float) -> String:
	return format_weight_number(weight) + " lb"


func format_weight_number(weight: float) -> String:
	return "%.1f" % snapped(weight, 0.1)


func calculate_fish_sale_value(weight: float, price_per_lb: int) -> int:
	if world != null and world.fish_monger_manager != null and world.fish_monger_manager.has_method("calculate_fish_sale_value"):
		return int(world.fish_monger_manager.calculate_fish_sale_value(weight, price_per_lb))
	if weight <= 0.0 or price_per_lb <= 0:
		return 0
	var tenths: int = max(0, int(round(snapped(weight, 0.1) * 10.0)))
	if tenths <= 0:
		return 0
	return int(floor((float(price_per_lb) * float(tenths)) / 10.0))


func _on_amount_text_changed(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool):
	update_amount_summary(amount_input, total_label, sell_button, owned_weight, price_per_lb, pending)


func _on_amount_text_submitted(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_weight, price_per_lb, pending)


func _on_amount_focus_exited(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_weight, price_per_lb, pending)


func _on_amount_step_pressed(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_weight: float, price_per_lb: int, pending: bool, delta: float):
	var current_amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if current_amount <= 0.0:
		current_amount = min(1.0, owned_weight)

	var next_amount = clamp_sell_amount(current_amount + delta, owned_weight)
	if amount_input != null:
		amount_input.text = format_weight_number(next_amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_weight, price_per_lb, pending)


func is_sale_pending() -> bool:
	return world != null and world.fish_monger_manager != null and bool(world.fish_monger_manager.pending_transaction)


func _on_sell_pressed(item_id: String, amount_input: LineEdit, owned_weight: float):
	if world != null and world.fish_monger_manager != null:
		var requested_amount = parse_amount_text(amount_input.text if amount_input != null else "")
		if requested_amount <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 0.1 lb to sell.")
			return
		var amount = clamp_sell_amount(requested_amount, owned_weight)
		if amount_input != null:
			amount_input.text = format_weight_number(amount)
		world.fish_monger_manager.sell_fish(item_id, amount)


func _on_sell_all_pressed():
	if world != null and world.fish_monger_manager != null:
		world.fish_monger_manager.sell_all_fish()
