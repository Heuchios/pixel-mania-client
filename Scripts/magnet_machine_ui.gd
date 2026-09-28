extends Control

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
var world
var manager
var current_grid := Vector2i.ZERO
var current_state: Dictionary = {}
var pending := false
var pending_since := 0
var panel: Control
var item_label: Label
var item_icon: TextureRect
var stock: Button
var change: Button
var remote: Button
var building: CheckBox
var collecting: CheckBox
var update: Button
var picker: Control
var search: LineEdit
var choices: ItemList
var item_ids: Array[String] = []
var transfer: Control
var quantity: SpinBox
var remove_machine: Button
var deposit: Button
var withdraw: Button
var meter: ProgressBar
var status: Label
var picker_empty: Label

func preserve(control: Control, font_size: int):
	control.set_meta("pixelmania_font_role", "preserve")
	control.add_theme_font_size_override("font_size", font_size)

func surface(parent: Control, rect: Rect2, outer := false) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", Style.panel_style() if outer else Style.section_style())
	parent.add_child(result)
	return result

func text(parent: Control, value: String, rect: Rect2, font_size := 16) -> Label:
	var result := Label.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.apply_label_shadow(result, font_size)
	preserve(result, font_size)
	parent.add_child(result)
	return result

func action(parent: Control, value: String, rect: Rect2, callback: Callable, primary := false) -> Button:
	var result := Button.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	if primary: Style.apply_green_button(result, 16)
	else: Style.apply_blue_button(result, 16)
	preserve(result, 16)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

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
	panel = Control.new()
	panel.size = Vector2(860, 650)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	surface(panel, Rect2(0,0,860,650), true)
	surface(panel, Rect2(16,16,828,76))
	text(panel, "MAGNET MACHINE", Rect2(32,24,650,34), 28)
	status = text(panel, "Loading machine...", Rect2(34,62,710,22), 14)
	var close := action(panel, "", Rect2(780,30,48,48), hide)
	Style.apply_close_button(close)
	surface(panel, Rect2(16,104,828,118))
	surface(panel, Rect2(30,118,88,88), true)
	item_icon = TextureRect.new()
	item_icon.position = Vector2(40,128)
	item_icon.size = Vector2(68,68)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(item_icon)
	text(panel, "SELECTED ITEM", Rect2(136,118,430,22), 13)
	item_label = text(panel, "Nothing selected", Rect2(136,144,450,32), 22)
	item_label.clip_text = true
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text(panel, "Empty storage before changing the item.", Rect2(136,183,480,22), 13)
	change = action(panel, "CHANGE ITEM", Rect2(646,142,180,42), show_picker)
	surface(panel, Rect2(16,234,828,160))
	text(panel, "STORAGE", Rect2(32,245,220,26), 20)
	stock = action(panel, "", Rect2(476,244,352,32), func(): quantity.get_line_edit().grab_focus())
	meter = ProgressBar.new()
	meter.position = Vector2(32,284)
	meter.size = Vector2(796,20)
	meter.max_value = 5000
	meter.show_percentage = false
	panel.add_child(meter)
	Style.apply_progress_bar(meter)
	transfer = Control.new()
	transfer.position = Vector2(32,324)
	transfer.size = Vector2(796,48)
	panel.add_child(transfer)
	text(transfer, "QUANTITY", Rect2(0,0,120,42), 14)
	quantity = SpinBox.new()
	quantity.position = Vector2(132,0)
	quantity.size = Vector2(180,42)
	quantity.min_value = 1
	quantity.max_value = 5000
	quantity.value = 1
	transfer.add_child(quantity)
	Style.apply_input(quantity.get_line_edit(), 17)
	preserve(quantity.get_line_edit(), 17)
	deposit = action(transfer, "ADD ITEMS", Rect2(330,0,222,42), func(): transfer_items("magnet_deposit"), true)
	withdraw = action(transfer, "TAKE ITEMS", Rect2(566,0,230,42), func(): transfer_items("magnet_withdraw"))
	surface(panel, Rect2(16,406,828,158))
	text(panel, "MACHINE SETTINGS", Rect2(32,416,450,28), 20)
	building = CheckBox.new()
	building.text = "Building enabled"
	building.position = Vector2(32,452)
	building.size = Vector2(364,38)
	Style.apply_game_font_to_node(building)
	preserve(building, 16)
	panel.add_child(building)
	collecting = CheckBox.new()
	collecting.text = "Collect nearby items"
	collecting.position = Vector2(434,452)
	collecting.size = Vector2(390,38)
	Style.apply_game_font_to_node(collecting)
	preserve(collecting, 16)
	panel.add_child(collecting)
	text(panel, "Punch the machine to toggle building mode.", Rect2(34,512,580,26), 14)
	remote = action(panel, "GET REMOTE", Rect2(646,508,180,40), func(): send("magnet_remote"))
	remove_machine = action(panel, "REMOVE MACHINE", Rect2(32,588,238,42), func(): send("magnet_remove"))
	Style.apply_atlas_button(remove_machine, "red_button")
	preserve(remove_machine,16)
	update = action(panel, "SAVE SETTINGS", Rect2(582,588,246,42), func(): send("magnet_update", {"collecting": collecting.button_pressed, "building": building.button_pressed}), true)
	build_picker()
	hide()

func build_picker():
	picker = Control.new()
	picker.size = panel.size
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(picker)
	var shade := ColorRect.new()
	shade.size = panel.size
	shade.color = Color(0,0,0,.7)
	picker.add_child(shade)
	surface(picker, Rect2(60,64,740,522), true)
	surface(picker, Rect2(76,80,708,66))
	text(picker, "CHOOSE AN ITEM", Rect2(94,92,590,38), 24)
	var close_host := Control.new()
	close_host.position = Vector2(60,64)
	close_host.size = Vector2(740,522)
	close_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(close_host)
	var close := action(close_host, "", Rect2(660,26,48,48), picker.hide)
	Style.apply_close_button(close)
	search = LineEdit.new()
	search.position = Vector2(84,164)
	search.size = Vector2(692,42)
	search.placeholder_text = "Search your blocks and seeds..."
	Style.apply_input(search,16)
	preserve(search,16)
	search.text_changed.connect(func(_text): fill_choices())
	picker.add_child(search)
	choices = ItemList.new()
	choices.position = Vector2(84,222)
	choices.size = Vector2(692,302)
	choices.fixed_icon_size = Vector2i(44,44)
	choices.add_theme_constant_override("v_separation",12)
	choices.add_theme_stylebox_override("panel", Style.section_style())
	Style.apply_game_font_to_node(choices)
	preserve(choices,18)
	choices.add_theme_color_override("font_color", Color.WHITE)
	choices.add_theme_color_override("font_selected_color", Color.WHITE)
	choices.item_selected.connect(func(index):
		if index >= 0 and index < item_ids.size():
			send("magnet_select", {"item_id":item_ids[index]})
			picker.hide())
	picker.add_child(choices)
	picker_empty = text(picker,"No matching blocks or seeds in your inventory.",Rect2(104,322,650,60),16)
	picker_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text(picker,"Select an item to configure this machine.",Rect2(90,538,660,28),14)
	picker.hide()

func transfer_items(action_name: String):
	quantity.apply()
	send(action_name, {"amount":int(quantity.value)})

func sync_actions():
	var manage := bool(current_state.get("can_manage",false))
	var id := str(current_state.get("item_id",""))
	var count := int(current_state.get("count",0))
	deposit.disabled = pending or not manage or id.is_empty() or count >= 5000
	withdraw.disabled = pending or not manage or count <= 0
	change.disabled = pending or not manage or count > 0
	update.disabled = pending or not manage
	remove_machine.disabled = pending or not manage
	remote.disabled = pending or id.is_empty() or not bool(current_state.get("building",false))
	status.text = "Updating machine..." if pending else ("Owner controls" if manage else "View only | Owner access required")

func _process(_delta):
	if not visible: return
	var viewport_size := get_viewport_rect().size
	var fit := maxf(.1,minf(1.0,minf((viewport_size.x-24)/860.0,(viewport_size.y-24)/650.0)))
	panel.scale = Vector2.ONE * fit
	panel.position = (viewport_size - panel.size * fit) * .5
	if pending and Time.get_ticks_msec() - pending_since > 6000:
		pending = false
		manager.request("magnet_get_state",current_grid)
	sync_actions()

func open(grid: Vector2i):
	current_grid = grid
	pending = false
	picker.hide()
	transfer.show()
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
	item_label.text = (world.get_item_display_name(id, str(data.get("item_category", "block"))) if id != "" else "Nothing")
	item_icon.texture = world.get_inventory_icon_texture(id, str(data.get("item_category", "block"))) if id != "" else null
	stock.text = "%d / 5,000 STORED" % int(data.get("count", 0))
	meter.value = int(data.get("count", 0))
	item_label.tooltip_text = item_label.text
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
	if change.disabled: return
	picker.visible = not picker.visible
	transfer.show()
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
		if not search.text.is_empty() and not search.text.strip_edges().to_lower() in (title + " " + str(id)).to_lower():
			continue
		item_ids.append(id)
		choices.add_item(title + " (%d)" % world.get_item_count(id, category), world.get_inventory_icon_texture(id, category))

	picker_empty.visible = item_ids.is_empty()
