extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const VENDING_INPUT_BOX = preload("res://Assets/ui/vending/input_box.png")
const VENDING_SCROLL_TRACK = preload("res://Assets/ui/vending/inventory_scroll_track.png")
const VENDING_SCROLL_THUMB = preload("res://Assets/ui/vending/inventory_scroll_thumb.png")
const VENDING_SCROLL_THUMB_HOVER = preload("res://Assets/ui/vending/inventory_scroll_thumb_hover.png")

var world = null
var ui_layer_ref = null

var overlay = null
var panel = null
var status_label = null
var item_slot = null
var item_icon = null
var item_label = null
var stock_spin = null
var per_sale_spin = null
var price_spin = null
var list_button = null
var buy_button = null
var cancel_button = null
var collect_button = null
var log_button = null
var log_overlay = null
var log_text = null

var current_grid := Vector2i.ZERO
var current_state := {}
var selected_item := {}
var scene_ui_ready := false


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 145
	build_ui()
	close_vending()


func _process(_delta):
	if visible:
		update_position()


func build_ui():
	scene_ui_ready = bind_scene_ui()
	if not scene_ui_ready:
		push_error("VendingUI: scene GUI nodes are missing. Coded vending GUI fallback is disabled.")
		return

	update_position()


func bind_scene_ui() -> bool:
	overlay = get_node_or_null("VendingOverlay")
	panel = get_node_or_null("VendingPanel")
	if overlay == null or panel == null:
		return false

	status_label = panel.get_node_or_null("StatusBack/Status")
	item_slot = panel.get_node_or_null("ItemCard/ItemSlot")
	item_icon = item_slot.get_node_or_null("Icon") if item_slot != null else null
	item_label = item_slot.get_node_or_null("ItemLabel") if item_slot != null else null
	stock_spin = panel.get_node_or_null("PriceCard/StockSpin")
	per_sale_spin = panel.get_node_or_null("PriceCard/PerSaleSpin")
	price_spin = panel.get_node_or_null("PriceCard/PriceSpin")
	list_button = panel.get_node_or_null("ListButton")
	buy_button = panel.get_node_or_null("BuyButton")
	cancel_button = panel.get_node_or_null("CancelListingButton")
	collect_button = panel.get_node_or_null("CollectButton")
	log_button = panel.get_node_or_null("LogButton")
	log_overlay = panel.get_node_or_null("VendingLogOverlay")
	log_text = log_overlay.get_node_or_null("LogScroll/LogText") if log_overlay != null else null

	if status_label == null or item_slot == null or item_icon == null or item_label == null:
		return false
	if stock_spin == null or per_sale_spin == null or price_spin == null:
		return false
	if list_button == null or buy_button == null or cancel_button == null or collect_button == null or log_button == null:
		return false
	if log_overlay == null or log_text == null:
		return false

	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_button(panel.get_node_or_null("CloseButton"), close_vending)
	_connect_button(item_slot, _on_item_slot_pressed)
	_connect_button(list_button, _on_list_pressed)
	_connect_button(buy_button, _on_buy_pressed)
	_connect_button(collect_button, _on_collect_pressed)
	_connect_button(log_button, _on_log_pressed)
	_connect_button(cancel_button, _on_cancel_listing_pressed)
	_connect_button(log_overlay.get_node_or_null("CloseButton"), _hide_log_overlay)
	_connect_spin(stock_spin)
	_connect_spin(per_sale_spin)
	_connect_spin(price_spin)
	apply_vending_scrollbar_style(log_overlay.get_node_or_null("LogScroll"))
	log_overlay.visible = false
	return true


func _connect_button(button, callback: Callable) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_spin(spin) -> void:
	if spin == null:
		return
	spin.step = 1
	spin.mouse_filter = Control.MOUSE_FILTER_STOP
	if not spin.value_changed.is_connected(_on_price_fields_changed):
		spin.value_changed.connect(_on_price_fields_changed)
	var editor = spin.get_line_edit()
	if editor != null:
		apply_vending_input_style(editor, 17)


func _hide_log_overlay() -> void:
	if log_overlay != null:
		log_overlay.visible = false


func build_legacy_ui():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "VendingOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.26)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Control.new()
	panel.name = "VendingPanel"
	panel.size = Vector2(860, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(9, 9)
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
	top_bar.size = Vector2(panel.size.x, 82)
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
	top_line.position = Vector2(0, 77)
	top_line.size = Vector2(panel.size.x, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "VENDING MACHINE"
	title.position = Vector2(34, 6)
	title.size = Vector2(520, 58)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 44)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "PLAYER MARKET"
	subtitle.position = Vector2(40, 61)
	subtitle.size = Vector2(220, 20)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 13)
	panel.add_child(subtitle)

	var status_back = Panel.new()
	status_back.name = "StatusBack"
	status_back.position = Vector2(558, 18)
	status_back.size = Vector2(206, 44)
	status_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		14,
		8
	))
	panel.add_child(status_back)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2.ZERO
	status_label.size = status_back.size
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status_label, 16, PixelUIStyle.TEXT_SOFT)
	status_back.add_child(status_label)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(790, 18)
	close_button.size = Vector2(48, 44)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_vending)
	panel.add_child(close_button)

	var item_card = Panel.new()
	item_card.name = "ItemCard"
	item_card.position = Vector2(30, 106)
	item_card.size = Vector2(358, 322)
	item_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		4,
		10,
		7
	))
	panel.add_child(item_card)

	var item_title = Label.new()
	item_title.text = "ITEM LISTING"
	item_title.position = Vector2(20, 14)
	item_title.size = Vector2(180, 28)
	item_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(item_title, 22, PixelUIStyle.GOLD_SOFT)
	item_card.add_child(item_title)

	var art_back = Panel.new()
	art_back.name = "ArtBack"
	art_back.position = Vector2(18, 52)
	art_back.size = Vector2(322, 170)
	art_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_back.clip_contents = true
	art_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.70, 0.72, 0.73, 0.88),
		Color(0.08, 0.09, 0.12, 1.0),
		2,
		2,
		0
	))
	item_card.add_child(art_back)

	for ray_index in range(5):
		var ray = ColorRect.new()
		ray.name = "Ray_" + str(ray_index)
		ray.position = Vector2(-26.0 + float(ray_index) * 74.0, -14.0)
		ray.size = Vector2(32, 220)
		ray.rotation_degrees = -28.0
		ray.color = Color(1.0, 1.0, 1.0, 0.16 if ray_index % 2 == 0 else 0.08)
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_back.add_child(ray)

	var wash = ColorRect.new()
	wash.name = "AccentWash"
	wash.position = Vector2(180, 0)
	wash.size = Vector2(142, 170)
	wash.color = Color(0.18, 0.84, 1.0, 0.14)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_back.add_child(wash)

	item_slot = Button.new()
	item_slot.name = "ItemSlot"
	item_slot.position = Vector2(106, 76)
	item_slot.size = Vector2(146, 122)
	item_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	item_slot.clip_contents = true
	item_slot.text = ""
	item_slot.add_theme_stylebox_override("normal", PixelUIStyle.slot_style("currency"))
	item_slot.add_theme_stylebox_override("hover", PixelUIStyle.style_box(
		Color(0.045, 0.380, 0.450, 0.98),
		Color(0.70, 1.0, 1.0, 0.96),
		3,
		13,
		7
	))
	item_slot.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(
		Color(0.020, 0.210, 0.270, 0.98),
		Color(0.12, 0.52, 0.70, 1.0),
		3,
		13,
		4
	))
	item_slot.pressed.connect(_on_item_slot_pressed)
	item_card.add_child(item_slot)

	item_icon = TextureRect.new()
	item_icon.name = "Icon"
	item_icon.position = Vector2(38, 16)
	item_icon.size = Vector2(70, 62)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.visible = false
	item_slot.add_child(item_icon)

	item_label = Label.new()
	item_label.name = "ItemLabel"
	item_label.position = Vector2(10, 79)
	item_label.size = Vector2(126, 38)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_label.clip_text = true
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(item_label, 13)
	item_slot.add_child(item_label)

	var hint = Label.new()
	hint.name = "Hint"
	hint.text = "Click the item slot to choose stock from your backpack."
	hint.position = Vector2(24, 236)
	hint.size = Vector2(310, 46)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(hint, 14)
	item_card.add_child(hint)

	var stock_note = Label.new()
	stock_note.name = "StockNote"
	stock_note.text = "World Lock pricing"
	stock_note.position = Vector2(24, 286)
	stock_note.size = Vector2(310, 24)
	stock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(stock_note, 15, PixelUIStyle.GOLD_SOFT)
	item_card.add_child(stock_note)

	var price_card = Panel.new()
	price_card.name = "PriceCard"
	price_card.position = Vector2(414, 106)
	price_card.size = Vector2(416, 322)
	price_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		4,
		10,
		7
	))
	panel.add_child(price_card)

	var setup_title = Label.new()
	setup_title.text = "SALE DETAILS"
	setup_title.position = Vector2(22, 14)
	setup_title.size = Vector2(180, 28)
	setup_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(setup_title, 22, PixelUIStyle.GOLD_SOFT)
	price_card.add_child(setup_title)

	add_field_label(price_card, "STOCK LOADED", Vector2(26, 66))
	stock_spin = make_spin_box(Vector2(244, 62), 1, 1)
	price_card.add_child(stock_spin)

	add_field_label(price_card, "ITEMS PER SALE", Vector2(26, 128))
	per_sale_spin = make_spin_box(Vector2(244, 124), 1, 1)
	price_card.add_child(per_sale_spin)

	add_field_label(price_card, "WORLD LOCK PRICE", Vector2(26, 190))
	price_spin = make_spin_box(Vector2(244, 186), 1, 200)
	price_card.add_child(price_spin)

	var formula = Label.new()
	formula.name = "Formula"
	formula.text = "Example: 10 Dirt for 1 World Lock."
	formula.position = Vector2(26, 250)
	formula.size = Vector2(360, 42)
	formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(formula, 14)
	price_card.add_child(formula)

	var action_back = Panel.new()
	action_back.name = "ActionBack"
	action_back.position = Vector2(30, 452)
	action_back.size = Vector2(800, 76)
	action_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.82, 0.94, 1.0, 0.10),
		Color(0.42, 0.78, 1.0, 0.22),
		1,
		8,
		0
	))
	panel.add_child(action_back)

	list_button = Button.new()
	list_button.name = "ListButton"
	list_button.text = "LIST ITEM"
	list_button.position = Vector2(50, 467)
	list_button.size = Vector2(150, 46)
	list_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_vending_button_style(list_button, true, false, 17)
	list_button.pressed.connect(_on_list_pressed)
	panel.add_child(list_button)

	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "BUY"
	buy_button.position = Vector2(214, 467)
	buy_button.size = Vector2(220, 46)
	buy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_vending_button_style(buy_button, true, false, 17)
	buy_button.pressed.connect(_on_buy_pressed)
	panel.add_child(buy_button)

	collect_button = Button.new()
	collect_button.name = "CollectButton"
	collect_button.text = "COLLECT"
	collect_button.position = Vector2(448, 467)
	collect_button.size = Vector2(122, 46)
	collect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_vending_button_style(collect_button, false, false, 16)
	collect_button.pressed.connect(_on_collect_pressed)
	panel.add_child(collect_button)

	log_button = Button.new()
	log_button.name = "LogButton"
	log_button.text = "LOG"
	log_button.position = Vector2(584, 467)
	log_button.size = Vector2(92, 46)
	log_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_vending_button_style(log_button, false, false, 16)
	log_button.pressed.connect(_on_log_pressed)
	panel.add_child(log_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelListingButton"
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(690, 467)
	cancel_button.size = Vector2(116, 46)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_vending_button_style(cancel_button, false, true, 16)
	cancel_button.pressed.connect(_on_cancel_listing_pressed)
	panel.add_child(cancel_button)

	build_log_overlay()
	update_position()
	PixelUIStyle.play_panel_open(panel, Vector2(0.98, 0.98), 0.18)


func build_log_overlay():
	log_overlay = Control.new()
	log_overlay.name = "VendingLogOverlay"
	log_overlay.size = Vector2(560, 382)
	log_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	log_overlay.visible = false
	log_overlay.z_index = 30
	panel.add_child(log_overlay)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(7, 7)
	shadow.size = log_overlay.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		18,
		0
	))
	log_overlay.add_child(shadow)

	var back = Panel.new()
	back.name = "Back"
	back.position = Vector2.ZERO
	back.size = log_overlay.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		18,
		10
	))
	log_overlay.add_child(back)

	var header = Panel.new()
	header.name = "Header"
	header.position = Vector2.ZERO
	header.size = Vector2(log_overlay.size.x, 70)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		18,
		6
	))
	log_overlay.add_child(header)

	var line = ColorRect.new()
	line.name = "HeaderLine"
	line.position = Vector2(0, 66)
	line.size = Vector2(log_overlay.size.x, 3)
	line.color = Color(0.42, 0.78, 1.0, 0.46)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_overlay.add_child(line)

	var title = Label.new()
	title.text = "SALE LOG"
	title.position = Vector2(24, 10)
	title.size = Vector2(260, 46)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(title, 32)
	log_overlay.add_child(title)

	var close = Button.new()
	close.text = "X"
	close.position = Vector2(502, 14)
	close.size = Vector2(40, 38)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close)
	close.pressed.connect(func(): log_overlay.visible = false)
	log_overlay.add_child(close)

	var scroll_back = Panel.new()
	scroll_back.name = "ScrollBack"
	scroll_back.position = Vector2(24, 88)
	scroll_back.size = Vector2(512, 264)
	scroll_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		2,
		12,
		2
	))
	log_overlay.add_child(scroll_back)

	var scroll = ScrollContainer.new()
	scroll.name = "LogScroll"
	scroll.position = Vector2(34, 98)
	scroll.size = Vector2(492, 244)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	log_overlay.add_child(scroll)

	log_text = Label.new()
	log_text.name = "LogText"
	log_text.position = Vector2.ZERO
	log_text.size = Vector2(460, 244)
	log_text.custom_minimum_size = Vector2(460, 244)
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(log_text, 14)
	scroll.add_child(log_text)
	apply_vending_scrollbar_style(scroll)


func add_field_label(parent, text: String, pos: Vector2):
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(190, 32)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(label, 15)
	parent.add_child(label)


func make_spin_box(pos: Vector2, min_value: int, max_value: int) -> SpinBox:
	var spin = SpinBox.new()
	spin.position = pos
	spin.size = Vector2(142, 38)
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = min_value
	spin.mouse_filter = Control.MOUSE_FILTER_STOP
	spin.add_theme_font_size_override("font_size", 17)
	spin.value_changed.connect(_on_price_fields_changed)
	var editor = spin.get_line_edit()
	if editor != null:
		apply_vending_input_style(editor, 17)
	return spin


func apply_vending_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 16):
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


func apply_vending_input_style(line_edit: LineEdit, font_size: int = 17):
	if line_edit == null:
		return

	line_edit.add_theme_font_size_override("font_size", font_size)
	line_edit.add_theme_stylebox_override("normal", vending_texture_style(VENDING_INPUT_BOX))
	line_edit.add_theme_stylebox_override("focus", vending_texture_style(VENDING_INPUT_BOX))
	line_edit.add_theme_color_override("font_color", PixelUIStyle.TEXT_LIGHT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.76, 0.90, 1.0, 0.74))
	line_edit.add_theme_color_override("caret_color", PixelUIStyle.GOLD_SOFT)
	line_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))


func apply_vending_scrollbar_style(scroll):
	if scroll == null:
		return

	var scrollbar = scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", vending_texture_style(VENDING_SCROLL_TRACK))
	scrollbar.add_theme_stylebox_override("grabber", vending_texture_style(VENDING_SCROLL_THUMB))
	scrollbar.add_theme_stylebox_override("grabber_highlight", vending_texture_style(VENDING_SCROLL_THUMB_HOVER))
	scrollbar.add_theme_stylebox_override("grabber_pressed", vending_texture_style(VENDING_SCROLL_THUMB_HOVER))


func vending_texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	return style


func open_vending(grid_pos: Vector2i):
	if not scene_ui_ready:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Vending UI scene is not ready.")
		return

	current_grid = grid_pos
	selected_item.clear()
	current_state = {
		"x": grid_pos.x,
		"y": grid_pos.y,
		"listing": {},
		"pending_wls": 0,
		"logs": [],
		"status": "empty",
		"can_manage": false
	}
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_overlay.visible = false
	update_position()
	refresh_ui()
	request_vend_state()


func close_vending():
	if world != null and world.has_method("end_vend_item_select") and world.has_method("is_vend_item_selecting") and bool(world.is_vend_item_selecting()):
		world.end_vend_item_select(true)
	visible = false
	selected_item.clear()
	if log_overlay != null:
		log_overlay.visible = false


func is_vending_open() -> bool:
	return visible


func update_position():
	if panel == null:
		return
	var screen_size = get_viewport_rect().size
	panel.position = Vector2((screen_size.x - panel.size.x) / 2.0, max(54.0, (screen_size.y - panel.size.y) / 2.0))
	if log_overlay != null:
		log_overlay.position = Vector2((panel.size.x - log_overlay.size.x) / 2.0, 92.0)


func request_vend_state():
	send_vend_request({
		"action": "vend_get_state"
	})


func send_vend_request(payload: Dictionary) -> bool:
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
			world.show_notification("That vending action could not be completed.")
		return false
	return true


func add_inventory_item_to_vend(item_type: String, category: String, amount: int) -> bool:
	if not visible:
		return false
	if not can_manage_current_vend():
		if world != null:
			world.show_notification("Only the vending machine owner can list items.")
		return false
	if is_current_vend_awaiting_collection():
		if world != null:
			world.show_notification("Collect the sold vending machine first.")
		return false
	if not get_listing().is_empty():
		if world != null:
			world.show_notification("Cancel or collect the current vending machine first.")
		return false

	selected_item = {
		"item_id": item_type,
		"item_category": category,
		"stock": max(1, amount)
	}
	stock_spin.max_value = max(1, amount)
	stock_spin.value = max(1, amount)
	per_sale_spin.max_value = max(1, amount)
	per_sale_spin.value = min(int(per_sale_spin.value), max(1, amount))
	refresh_ui()
	return true


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action = str(data.get("action", ""))
	if not action.begins_with("vend_"):
		return false

	var vend_state = data.get("vend_state", {})
	if vend_state is Dictionary and not vend_state.is_empty():
		apply_vend_state(vend_state)
		sync_world_vending_preview()

	var message = str(data.get("message", "")).strip_edges()
	if message != "" and world != null and world.has_method("show_notification"):
		world.show_notification(message)

	if bool(data.get("ok", false)) and action == "vend_set_listing":
		selected_item.clear()

	refresh_ui()
	return true


func handle_vend_state(data: Dictionary):
	var x = int(data.get("x", 999999))
	var y = int(data.get("y", 999999))
	if x != current_grid.x or y != current_grid.y:
		return
	apply_vend_state(data)
	sync_world_vending_preview()
	refresh_ui()


func apply_vend_state(data: Dictionary):
	var normalized_state: Dictionary = {}
	if data.has("state") and data.get("state") is Dictionary:
		normalized_state = data.get("state").duplicate(true)
	else:
		normalized_state = data.duplicate(true)

	if not normalized_state.has("x"):
		normalized_state["x"] = int(data.get("x", current_grid.x))
	if not normalized_state.has("y"):
		normalized_state["y"] = int(data.get("y", current_grid.y))

	current_state = normalized_state
	if current_state.get("listing", {}) == null:
		current_state["listing"] = {}
	if not (current_state.get("logs", []) is Array):
		current_state["logs"] = []


func sync_world_vending_preview() -> void:
	if world == null:
		return

	if "vending_states" in world:
		if get_listing().is_empty() and not is_current_vend_awaiting_collection():
			world.vending_states.erase(current_grid)
		else:
			world.vending_states[current_grid] = current_state.duplicate(true)

	if world.has_method("update_vending_machine_preview"):
		world.update_vending_machine_preview(current_grid)


func get_listing() -> Dictionary:
	var listing = current_state.get("listing", {})
	if listing is Dictionary and str(listing.get("item_id", "")) != "":
		return listing
	return {}


func get_vend_status() -> String:
	return str(current_state.get("status", "")).strip_edges().to_lower()


func is_current_vend_awaiting_collection() -> bool:
	return int(current_state.get("pending_wls", 0)) > 0 or get_vend_status() == "sold"


func can_manage_current_vend() -> bool:
	return bool(current_state.get("can_manage", false))


func refresh_ui():
	if panel == null:
		return

	var listing = get_listing()
	var pending = int(current_state.get("pending_wls", 0))
	var can_manage = can_manage_current_vend()

	if pending > 0:
		status_label.text = str(pending) + " WL READY"
	elif is_current_vend_awaiting_collection():
		status_label.text = "SOLD"
	elif not listing.is_empty():
		status_label.text = "ITEM LISTED"
	else:
		status_label.text = "EMPTY"

	refresh_item_slot(listing)
	refresh_price_controls(listing)
	refresh_buttons(listing, pending, can_manage)
	refresh_log_text()


func refresh_item_slot(listing: Dictionary):
	var display_item = {}
	if not selected_item.is_empty():
		display_item = selected_item
	elif not listing.is_empty():
		display_item = listing

	item_slot.text = ""
	if display_item.is_empty():
		item_icon.visible = false
		item_icon.texture = null
		item_label.text = "+\nSelect Item"
		return

	var item_id = str(display_item.get("item_id", ""))
	var category = str(display_item.get("item_category", ""))
	var amount = int(display_item.get("stock", display_item.get("amount", 0)))
	var texture = world.get_item_texture(item_id, category) if world != null and world.has_method("get_item_texture") else null
	item_icon.texture = texture
	item_icon.visible = texture != null
	item_label.text = get_item_name(item_id, category) + "\nx" + str(amount)


func refresh_price_controls(listing: Dictionary):
	var editable = can_manage_current_vend() and listing.is_empty() and not is_current_vend_awaiting_collection()

	stock_spin.editable = editable and not selected_item.is_empty()
	per_sale_spin.editable = editable and not selected_item.is_empty()
	price_spin.editable = editable and not selected_item.is_empty()

	if selected_item.is_empty() and not listing.is_empty():
		var stock = max(1, int(listing.get("stock", 1)))
		stock_spin.max_value = stock
		stock_spin.value = stock
		per_sale_spin.max_value = stock
		per_sale_spin.value = max(1, int(listing.get("amount_per_sale", listing.get("amount_per_sale", 1))))
		price_spin.value = max(1, int(listing.get("price_wls", 1)))
	elif not selected_item.is_empty():
		var selected_stock = max(1, int(selected_item.get("stock", 1)))
		stock_spin.max_value = selected_stock
		per_sale_spin.max_value = max(1, int(stock_spin.value))
		if int(per_sale_spin.value) > int(stock_spin.value):
			per_sale_spin.value = int(stock_spin.value)


func refresh_buttons(listing: Dictionary, pending: int, can_manage: bool):
	var awaiting_collection = is_current_vend_awaiting_collection()
	list_button.visible = can_manage
	list_button.disabled = selected_item.is_empty() or not listing.is_empty() or awaiting_collection
	list_button.position = Vector2(50, 467)
	list_button.size = Vector2(150, 46)

	buy_button.visible = not listing.is_empty() and not can_manage
	buy_button.disabled = listing.is_empty()
	if not listing.is_empty():
		buy_button.text = "BUY x" + str(int(listing.get("amount_per_sale", 1))) + " - " + str(int(listing.get("price_wls", 1))) + " WL"
	if buy_button.visible:
		buy_button.position = Vector2(50, 467)
		buy_button.size = Vector2(384, 46)
	else:
		buy_button.position = Vector2(214, 467)
		buy_button.size = Vector2(220, 46)

	collect_button.visible = can_manage
	collect_button.disabled = pending <= 0
	collect_button.position = Vector2(448, 467)
	collect_button.size = Vector2(122, 46)

	cancel_button.visible = can_manage
	cancel_button.disabled = listing.is_empty()
	cancel_button.position = Vector2(690, 467)
	cancel_button.size = Vector2(116, 46)

	log_button.position = Vector2(584, 467)
	log_button.size = Vector2(92, 46)


func refresh_log_text():
	var logs = current_state.get("logs", [])
	if not (logs is Array) or logs.is_empty():
		log_text.text = "No sales yet."
		return

	var lines = []
	for i in range(logs.size() - 1, -1, -1):
		var entry = logs[i]
		if not (entry is Dictionary):
			continue
		var buyer = str(entry.get("buyer_username", "Player"))
		var item_id = str(entry.get("item_id", ""))
		var category = str(entry.get("item_category", ""))
		var amount = int(entry.get("amount", 0))
		var price = int(entry.get("price_wls", 0))
		var date = str(entry.get("date", ""))
		lines.append(buyer + " bought " + get_item_name(item_id, category) + " x" + str(amount) + " for " + str(price) + " WL\n" + date)
	log_text.text = "\n\n".join(lines)


func _on_price_fields_changed(_value: float):
	if stock_spin != null and per_sale_spin != null:
		per_sale_spin.max_value = max(1, int(stock_spin.value))
		if int(per_sale_spin.value) > int(stock_spin.value):
			per_sale_spin.value = int(stock_spin.value)


func read_spin_box_int(spin: SpinBox, fallback: int = 1) -> int:
	if spin == null:
		return fallback

	var parsed_value = int(spin.value)
	var editor = spin.get_line_edit()
	if editor != null:
		var raw_text = editor.text.strip_edges()
		if raw_text.is_valid_float():
			parsed_value = int(round(float(raw_text)))

	parsed_value = clamp(parsed_value, int(spin.min_value), int(spin.max_value))
	spin.value = parsed_value
	return parsed_value


func _on_item_slot_pressed():
	if not can_manage_current_vend():
		if world != null:
			world.show_notification("Only the vending machine owner can list items.")
		return
	if is_current_vend_awaiting_collection():
		if world != null:
			world.show_notification("Collect the sold vending machine first.")
		return
	if not get_listing().is_empty():
		if world != null:
			world.show_notification("Cancel or collect the current vending machine first.")
		return
	if world != null and world.has_method("begin_vend_item_select"):
		world.begin_vend_item_select()


func _on_list_pressed():
	if selected_item.is_empty():
		if world != null:
			world.show_notification("Select an item first.")
		return
	if is_current_vend_awaiting_collection():
		if world != null:
			world.show_notification("Collect the sold vending machine first.")
		return
	if not get_listing().is_empty():
		if world != null:
			world.show_notification("Cancel the current vending listing first.")
		return

	var stock_value = read_spin_box_int(stock_spin, 1)
	var per_sale_value = read_spin_box_int(per_sale_spin, 1)
	var price_value = read_spin_box_int(price_spin, 1)
	per_sale_value = clamp(per_sale_value, 1, stock_value)
	per_sale_spin.max_value = stock_value
	per_sale_spin.value = per_sale_value

	send_vend_request({
		"action": "vend_set_listing",
		"item_id": str(selected_item.get("item_id", "")),
		"item_category": str(selected_item.get("item_category", "")),
		"stock": stock_value,
		"amount_per_sale": per_sale_value,
		"price_wls": price_value
	})


func _on_buy_pressed():
	send_vend_request({
		"action": "vend_buy",
		"sale_count": 1
	})


func _on_collect_pressed():
	send_vend_request({
		"action": "vend_collect"
	})


func _on_cancel_listing_pressed():
	send_vend_request({
		"action": "vend_cancel"
	})


func _on_log_pressed():
	refresh_log_text()
	log_overlay.visible = true


func get_item_name(item_id: String, category: String) -> String:
	if world != null and world.has_method("get_item_display_name"):
		return world.get_item_display_name(item_id, category)
	return item_id.capitalize()
