extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

var world = null
var overlay: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var status_label: Label = null
var item_label: Label = null
var item_icon: TextureRect = null
var inventory_root: VBoxContainer = null
var withdraw_button: Button = null
var close_button: Button = null

var current_grid := Vector2i.ZERO
var current_state: Dictionary = {}
var display_open := false
var pending_inventory_select := false


func setup(parent_world, _ui_node = null):
	world = parent_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 146
	build_ui()
	close_display()


func _process(_delta):
	if display_open:
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
	panel.size = Vector2(600, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 14
	))
	add_child(panel)

	title_label = Label.new()
	title_label.text = "DISPLAY"
	title_label.position = Vector2(24, 12)
	title_label.size = Vector2(360, 44)
	PixelUIStyle.apply_label_shadow(title_label, 34)
	panel.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel.size.x - 62, 14)
	close_button.size = Vector2(42, 38)
	PixelUIStyle.apply_blue_button(close_button, 18)
	close_button.pressed.connect(close_display)
	panel.add_child(close_button)

	status_label = Label.new()
	status_label.position = Vector2(28, 58)
	status_label.size = Vector2(panel.size.x - 56, 26)
	PixelUIStyle.apply_small_label(status_label, 15)
	panel.add_child(status_label)

	var slot_panel = Panel.new()
	slot_panel.position = Vector2(24, 94)
	slot_panel.size = Vector2(panel.size.x - 48, 112)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.14, 0.25, 0.34, 0.58),
		Color(0.72, 0.92, 1.0, 0.46),
		3, 8, 6
	))
	panel.add_child(slot_panel)

	item_icon = TextureRect.new()
	item_icon.position = Vector2(20, 20)
	item_icon.size = Vector2(72, 72)
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_panel.add_child(item_icon)

	item_label = Label.new()
	item_label.position = Vector2(112, 22)
	item_label.size = Vector2(slot_panel.size.x - 240, 68)
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUIStyle.apply_small_label(item_label, 20)
	slot_panel.add_child(item_label)

	withdraw_button = Button.new()
	withdraw_button.text = "TAKE"
	withdraw_button.position = Vector2(slot_panel.size.x - 114, 34)
	withdraw_button.size = Vector2(88, 42)
	PixelUIStyle.apply_yellow_button(withdraw_button, 18)
	withdraw_button.pressed.connect(withdraw_display_item)
	slot_panel.add_child(withdraw_button)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(24, 228)
	scroll.size = Vector2(panel.size.x - 48, 264)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	inventory_root = VBoxContainer.new()
	inventory_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_root.add_theme_constant_override("separation", 8)
	scroll.add_child(inventory_root)


func update_position():
	if panel == null:
		return
	var screen_size = get_viewport_rect().size
	panel.position = Vector2(
		floor((screen_size.x - panel.size.x) * 0.5),
		floor(max(24.0, (screen_size.y - panel.size.y) * 0.5))
	)


func open_display(grid_pos: Vector2i):
	current_grid = grid_pos
	current_state = get_cached_state()
	display_open = true
	pending_inventory_select = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	refresh()
	if not request_display_state():
		pending_inventory_select = false


func close_display():
	var was_open := display_open
	display_open = false
	pending_inventory_select = false
	current_state.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false
	if was_open and world != null and world.has_method("end_display_item_select"):
		world.end_display_item_select(true)


func is_display_open() -> bool:
	return display_open and visible


func request_display_state() -> bool:
	return send_display_request({"action": "display_get_state"})


func send_display_request(payload: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_inventory_transaction_request"):
		if world != null:
			world.show_notification("Connection required.")
		return false

	var request = payload.duplicate(true)
	request["world"] = world.current_world_name
	request["x"] = current_grid.x
	request["y"] = current_grid.y
	if not bool(network.send_inventory_transaction_request(request)):
		if world != null:
			world.show_notification("That display action could not be completed.")
		return false
	return true


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action = str(data.get("action", ""))
	if not action.begins_with("display_"):
		return false
	var display_state = data.get("display_state", null)
	if display_state is Dictionary and not display_state.is_empty():
		apply_display_state(display_state)
	var message = str(data.get("message", "")).strip_edges()
	if message != "" and world != null:
		world.show_notification(message)
	if display_open:
		refresh()
		maybe_begin_inventory_select()
	return true


func handle_display_state(data: Dictionary):
	var x = int(data.get("x", 999999))
	var y = int(data.get("y", 999999))
	if x != current_grid.x or y != current_grid.y:
		return
	var state = data.get("state", null)
	if state is Dictionary:
		apply_display_state(state)
	elif data.has("state"):
		apply_display_state({})
	else:
		apply_display_state(data)
	refresh()
	maybe_begin_inventory_select()


func apply_display_state(data: Dictionary):
	var target_grid := current_grid
	if data.has("x") and data.has("y"):
		target_grid = Vector2i(int(data.get("x", current_grid.x)), int(data.get("y", current_grid.y)))
	var next_state := data.duplicate(true)
	if target_grid == current_grid:
		current_state = next_state.duplicate(true)
	if world != null and "display_states" in world:
		world.display_states[target_grid] = {"state": next_state}
		if world.has_method("update_display_visual"):
			world.update_display_visual(target_grid)


func get_cached_state() -> Dictionary:
	if world == null or not ("display_states" in world):
		return {}
	if not world.display_states.has(current_grid):
		return {}
	var raw_state = world.display_states.get(current_grid, {})
	if raw_state is Dictionary and raw_state.has("state") and raw_state.get("state") is Dictionary:
		return raw_state.get("state").duplicate(true)
	if raw_state is Dictionary:
		return raw_state.duplicate(true)
	return {}


func get_slot() -> Dictionary:
	var slot = current_state.get("slot", current_state.get("item", {}))
	if slot is Dictionary:
		return slot
	return {}


func can_manage_display() -> bool:
	var local_owner := false
	if world != null and world.world_lock_manager != null and world.world_lock_manager.has_method("is_current_player_owner"):
		local_owner = bool(world.world_lock_manager.is_current_player_owner())
	if current_state.has("can_manage"):
		return bool(current_state.get("can_manage", false)) or local_owner
	return local_owner


func refresh():
	var slot = get_slot()
	var can_manage = can_manage_display()
	status_label.text = "Owner only" if not can_manage else "Choose one item to display"
	withdraw_button.visible = can_manage and not slot.is_empty()
	item_icon.texture = null

	if slot.is_empty():
		item_label.text = "Empty"
	else:
		var item_id = str(slot.get("item_id", slot.get("item_type", "")))
		var category = str(slot.get("item_category", "block"))
		item_label.text = world.get_item_display_name(item_id, category) if world != null and world.has_method("get_item_display_name") else item_id
		if world != null and world.has_method("get_item_texture"):
			item_icon.texture = world.get_item_texture(item_id, category)

	refresh_inventory_list(can_manage and slot.is_empty())


func refresh_inventory_list(can_deposit: bool):
	if inventory_root == null:
		return
	for child in inventory_root.get_children():
		child.queue_free()

	if not can_deposit:
		var label = Label.new()
		label.text = "Take the displayed item before adding another."
		PixelUIStyle.apply_small_label(label, 17)
		inventory_root.add_child(label)
		return

	if get_inventory_entries().is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items available."
		PixelUIStyle.apply_small_label(empty_label, 17)
		inventory_root.add_child(empty_label)
		return

	var button = Button.new()
	button.text = "PICK FROM INVENTORY"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 48)
	PixelUIStyle.apply_blue_button(button, 16)
	button.pressed.connect(begin_inventory_select)
	inventory_root.add_child(button)


func get_inventory_entries() -> Array:
	var entries: Array = []
	if world == null:
		return entries

	var inventory_sources = [
		{"category": "block", "items": world.inventory},
		{"category": "seed", "items": world.seed_inventory},
		{"category": "tool", "items": world.tool_inventory},
		{"category": "material", "items": world.material_inventory},
		{"category": "lure", "items": world.lure_inventory},
		{"category": "fish", "items": world.fish_inventory},
		{"category": "back", "items": world.back_inventory},
		{"category": "hat", "items": world.hat_inventory},
		{"category": "hair", "items": world.hair_inventory},
		{"category": "eyewear", "items": world.eyewear_inventory},
		{"category": "shirt", "items": world.shirt_inventory},
		{"category": "pants", "items": world.pants_inventory},
		{"category": "shoes", "items": world.shoes_inventory},
		{"category": "ride", "items": world.ride_inventory},
		{"category": "currency", "items": world.currency_inventory}
	]

	for source in inventory_sources:
		var category = str(source.get("category", ""))
		var items = source.get("items", {})
		if not (items is Dictionary):
			continue
		for item_id in items.keys():
			var amount = get_inventory_amount(str(item_id), category, items.get(item_id, 0))
			if amount <= 0 or is_hidden_item(str(item_id)):
				continue
			entries.append({
				"item_id": str(item_id),
				"item_category": category,
				"amount": amount
			})

	entries.sort_custom(func(a, b): return get_display_name(str(a.get("item_id", "")), str(a.get("item_category", ""))) < get_display_name(str(b.get("item_id", "")), str(b.get("item_category", ""))))
	return entries


func get_inventory_amount(item_id: String, category: String, raw_value) -> int:
	if world != null and world.has_method("get_item_count"):
		return int(world.get_item_count(item_id, category))
	if raw_value is int or raw_value is float:
		return int(raw_value)
	if raw_value is Dictionary:
		return int(raw_value.get("count", raw_value.get("amount", raw_value.get("quantity", 0))))
	return 0


func is_hidden_item(item_id: String) -> bool:
	if world == null or not (world.item_database is Dictionary) or not world.item_database.has(item_id):
		return false
	return bool(world.item_database[item_id].get("hidden", false))


func get_display_name(item_id: String, category: String) -> String:
	if world != null and world.has_method("get_item_display_name"):
		return world.get_item_display_name(item_id, category)
	return item_id.replace("_", " ").capitalize()


func deposit_display_item(item_id: String, category: String):
	if not can_manage_display():
		if world != null:
			world.show_notification("Only the world owner can use this display.")
		return
	send_display_request({
		"action": "display_deposit",
		"item_type": item_id,
		"item_id": item_id,
		"item_category": category,
		"amount": 1
	})


func add_inventory_item_to_display(item_id: String, category: String, _amount: int = 1) -> bool:
	if not display_open:
		return false
	if not can_manage_display():
		if world != null:
			world.show_notification("Only the world owner can use this display.")
		return false
	if not get_slot().is_empty():
		if world != null:
			world.show_notification("Take the displayed item before adding another.")
		return false
	return send_display_request({
		"action": "display_deposit",
		"item_type": item_id,
		"item_id": item_id,
		"item_category": category,
		"amount": 1
	})


func begin_inventory_select():
	pending_inventory_select = false
	if world != null and world.has_method("begin_display_item_select"):
		world.begin_display_item_select()


func maybe_begin_inventory_select():
	if not pending_inventory_select or not display_open:
		return
	if not can_manage_display():
		pending_inventory_select = false
		return
	if not get_slot().is_empty():
		pending_inventory_select = false
		return
	begin_inventory_select()


func withdraw_display_item():
	if not can_manage_display():
		if world != null:
			world.show_notification("Only the world owner can use this display.")
		return
	var slot = get_slot()
	var item_id = str(slot.get("item_id", slot.get("item_type", "")))
	var category = str(slot.get("item_category", "block"))
	if item_id == "":
		return
	send_display_request({
		"action": "display_withdraw",
		"item_type": item_id,
		"item_id": item_id,
		"item_category": category,
		"amount": 1
	})
