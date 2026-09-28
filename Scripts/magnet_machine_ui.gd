extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
var world
var manager
var current_grid := Vector2i.ZERO
var current_state: Dictionary = {}
var pending := false
var pending_since := 0
var panel: PanelContainer
var column: VBoxContainer
var item_label: Label
var item_icon: TextureRect
var stock: Button
var change: Button
var remote: Button
var building: CheckBox
var collecting: CheckBox
var update: Button
var picker: VBoxContainer
var search: LineEdit
var choices: ItemList
var item_ids: Array[String] = []
var transfer: HBoxContainer
var quantity: SpinBox
var remove_machine: Button

func setup(owner_world, owner_manager):
	world = owner_world
	manager = owner_manager
	name = "MagnetMachineUI"
	z_index = 145
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	label("Magnet Machine", 30)
	column.add_child(HSeparator.new())
	var item_row := HBoxContainer.new()
	column.add_child(item_row)
	item_icon = TextureRect.new()
	item_icon.custom_minimum_size = Vector2(44, 44)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_row.add_child(item_icon)
	item_label = Label.new()
	Style.apply_label_shadow(item_label)
	item_row.add_child(item_label)
	stock = button("The machine is currently empty!", func(): transfer.visible = not transfer.visible)
	change = button("Change Item", show_picker)
	remote = button("Get Remote", func(): send("magnet_remote"))
	label("Punch the machine to toggle building mode.", 18)
	building = CheckBox.new()
	building.text = "Building enabled"
	Style.apply_game_font_to_node(building)
	column.add_child(building)
	collecting = CheckBox.new()
	collecting.text = "Enable item collection"
	Style.apply_game_font_to_node(collecting)
	column.add_child(collecting)
	transfer = HBoxContainer.new()
	column.add_child(transfer)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 5000
	quantity.value = 1
	quantity.custom_minimum_size.x = 130
	Style.apply_input(quantity.get_line_edit())
	transfer.add_child(quantity)
	button("Add", func(): send("magnet_deposit", {"amount": int(quantity.value)}), transfer)
	button("Take", func(): send("magnet_withdraw", {"amount": int(quantity.value)}), transfer)
	transfer.hide()
	remove_machine = button("Remove empty machine", func(): send("magnet_remove"))
	picker = VBoxContainer.new()
	column.add_child(picker)
	search = LineEdit.new()
	search.placeholder_text = "Search your blocks and seeds"
	Style.apply_input(search)
	search.text_changed.connect(func(_text): fill_choices())
	picker.add_child(search)
	choices = ItemList.new()
	choices.custom_minimum_size = Vector2(0, 190)
	choices.fixed_icon_size = Vector2i(32, 32)
	Style.apply_game_font_to_node(choices)
	choices.item_selected.connect(func(index):
		send("magnet_select", {"item_id": item_ids[index]})
		picker.hide())
	picker.add_child(choices)
	picker.hide()
	column.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	button("Close", hide, footer)
	update = button("Update", func(): send("magnet_update", {"collecting": collecting.button_pressed, "building": building.button_pressed}), footer)
	Style.apply_green_button(update)
	hide()

func label(text: String, font_size := 24) -> Label:
	var result := Label.new()
	result.text = text
	Style.apply_label_shadow(result)
	result.add_theme_font_size_override("font_size", font_size)
	column.add_child(result)
	return result

func button(text: String, action: Callable, parent: Node = null) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	Style.apply_blue_button(result)
	result.pressed.connect(action)
	(parent if parent != null else column).add_child(result)
	return result

func _process(_delta):
	if not visible:
		return
	panel.size = Vector2(650, 0)
	var viewport_size := get_viewport_rect().size
	var fit := minf(1.0, minf((viewport_size.x - 24) / panel.size.x, (viewport_size.y - 24) / maxf(1, panel.size.y)))
	panel.scale = Vector2.ONE * fit
	panel.position = (viewport_size - panel.size * fit) * 0.5
	if pending and Time.get_ticks_msec() - pending_since > 6000:
		pending = false
		manager.request("magnet_get_state", current_grid)

func open(grid: Vector2i):
	current_grid = grid
	pending = false
	picker.hide()
	transfer.hide()
	apply_state(manager.states.get(grid, {}), true)
	show()
	manager.request("magnet_get_state", grid)

func apply_state(data: Dictionary, personalized: bool):
	var can_manage := bool(current_state.get("can_manage", false))
	current_state = data.duplicate(true)
	if not personalized:
		current_state["can_manage"] = can_manage
	can_manage = bool(current_state.get("can_manage", false))
	var id := str(data.get("item_id", ""))
	item_label.text = "Currently selected: " + (world.get_item_display_name(id, str(data.get("item_category", "block"))) if id != "" else "Nothing")
	item_icon.texture = world.get_inventory_icon_texture(id, str(data.get("item_category", "block"))) if id != "" else null
	stock.text = "%d / 5,000 items — Add / Take" % int(data.get("count", 0)) if id != "" else "The machine is currently empty!"
	stock.disabled = not can_manage or id == ""
	change.disabled = not can_manage or int(data.get("count", 0)) > 0
	remove_machine.visible = can_manage and int(data.get("count", 0)) == 0
	remote.disabled = id == "" or not bool(data.get("building", false))
	update.disabled = not can_manage
	building.disabled = not can_manage
	collecting.disabled = not can_manage
	if personalized:
		building.button_pressed = bool(data.get("building", false))
		collecting.button_pressed = bool(data.get("collecting", false))

func send(action: String, extra: Dictionary = {}):
	if pending:
		return
	if manager.request(action, current_grid, extra):
		pending = true
		pending_since = Time.get_ticks_msec()

func show_picker():
	picker.visible = not picker.visible
	transfer.hide()
	fill_choices()

func fill_choices():
	choices.clear()
	item_ids.clear()
	for id in world.item_database:
		var data: Dictionary = world.item_database[id]
		var category := str(data.get("category", ""))
		if category not in ["block", "seed"] or bool(data.get("instance_tracked", false)) or id == "magnet_machine":
			continue
		if world.get_item_count(id, category) < 1:
			continue
		var title: String = world.get_item_display_name(id, category)
		if not search.text.is_empty() and not search.text.to_lower() in title.to_lower():
			continue
		item_ids.append(id)
		choices.add_item(title + " (%d)" % world.get_item_count(id, category), world.get_inventory_icon_texture(id, category))
