extends SceneTree

var actions: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(844, 390)
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(inventory)
	inventory.set_inventory_items([
		{"id":"dirt", "category":"block", "count":344},
		{"id":"punch", "category":"tool", "count":1, "can_drop":false, "can_trash":false},
		{"id":"fish", "category":"fish", "count":123}
	])
	inventory.drop_requested.connect(func(item): actions.append(["drop", item]))
	inventory.trash_requested.connect(func(item): actions.append(["trash", item]))
	inventory.primary_action_requested.connect(func(item): actions.append(["use", item]))
	inventory.info_requested.connect(func(item): actions.append(["info", item]))
	await process_frame
	assert(inventory.use_button.visible and inventory.use_button.disabled, "Actions stay visible but disabled until selection")
	assert(inventory.action_skin.visible)
	inventory.set_selected_item("dirt", "block")
	assert(inventory.use_button.visible and inventory.use_button.disabled, "Gameplay/hotbar selection alone must not enable actions")
	var grid_before: Rect2 = inventory.inventory_scroll.get_rect()
	inventory._handle_slot_touch_tap("block:dirt")
	await process_frame
	assert(inventory.inventory_scroll.get_rect() == grid_before, "Selection must not resize the inventory")
	assert(inventory.use_button.visible and not inventory.use_button.disabled)
	var slider: HSlider = inventory.drop_amount_slider
	await click(slider.get_global_rect().end - Vector2(2, slider.get_global_rect().size.y / 2))
	assert(inventory.drop_amount == 344)
	inventory.drop_amount_input.text_changed.emit("151")
	await click(inventory.drop_button.get_global_rect().get_center())
	assert(actions[-1][0] == "drop" and actions[-1][1].amount == 151)
	await click(inventory.trash_button.get_global_rect().get_center())
	assert(actions[-1][0] == "trash" and actions[-1][1].amount == 151)
	await click(inventory.use_button.get_global_rect().get_center())
	assert(actions[-1][0] == "use")
	await click(inventory.info_button.get_global_rect().get_center())
	assert(actions[-1][0] == "info" and actions[-1][1].id == "dirt")
	inventory._handle_slot_touch_tap("tool:punch")
	assert(inventory.drop_button.disabled and inventory.trash_button.disabled)
	assert(inventory.drop_amount == 1)
	inventory._handle_slot_touch_tap("fish:fish")
	inventory.drop_amount_input.text_changed.emit("5.3")
	inventory._on_drop_amount_input_submitted("")
	assert(inventory.drop_amount == 53 and inventory.drop_amount_input.text == "5.3")
	inventory.drop_amount_input.text_changed.emit("9999")
	inventory._on_drop_amount_input_submitted("")
	assert(inventory.drop_amount == 123 and inventory.drop_amount_input.text == "12.3")
	for viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		inventory._fit_window_to_viewport()
		await process_frame
		var main_bounds: Rect2 = inventory.window.get_node("WindowSkin").get_global_rect()
		var sidebar_bounds: Rect2 = inventory.action_skin.get_global_rect()
		var left_bounds: Rect2 = inventory.window.get_node("TabSkin").get_global_rect()
		assert(left_bounds.size.is_equal_approx(sidebar_bounds.size), "Both permanent side panels must have equal dimensions")
		assert(left_bounds.end.x < main_bounds.position.x)
		assert(sidebar_bounds.position.x > main_bounds.end.x, "The action sidebar must be separated from the inventory by a gap")
		for control in inventory.tab_buttons.values():
			assert(left_bounds.encloses(control.get_global_rect()), "Category buttons must fit the left panel")
		for control in [inventory.use_button, inventory.drop_button, inventory.info_button, inventory.trash_button, inventory.drop_amount_input, inventory.close_button]:
			assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(control.get_global_rect()), "Action controls must fit the screen: %s %s %s" % [viewport_size, control.name, control.get_global_rect()])
			assert(not inventory.inventory_scroll.get_global_rect().intersects(control.get_global_rect()), "Actions must not overlap slots: %s %s control=%s grid=%s" % [viewport_size, control.name, control.get_global_rect(), inventory.inventory_scroll.get_global_rect()])
		assert(inventory.inventory_grid.get_combined_minimum_size().x <= inventory.inventory_scroll.size.x)
	inventory.search_input.text = "no match"
	inventory._on_search_changed("")
	assert(inventory.use_button.visible and inventory.use_button.disabled, "Filtering out selection must disable actions")
	inventory.clear_search()
	assert(inventory.use_button.visible and inventory.use_button.disabled)
	inventory._handle_slot_touch_tap("block:dirt")
	inventory.set_inventory_items([{"id":"punch", "category":"tool", "count":1}])
	assert(inventory.use_button.visible and inventory.use_button.disabled, "Removing a selected stack must disable actions")
	inventory._handle_slot_touch_tap("tool:punch")
	inventory.close_inventory()
	inventory.open_inventory()
	assert(inventory.use_button.visible and inventory.use_button.disabled, "Reopening requires an inventory selection")
	inventory.free()
	# Check the real Info integration resolves facts and opens the redesigned panel.
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	world.inventory = {"dirt":12}
	var manager = load("res://Scripts/inventory_manager.gd").new()
	manager.world = world
	world.inventory_manager = manager
	manager.ui_layer_ref = root
	manager._on_inventory_scene_info_requested({"id":"dirt", "category":"block"})
	await create_timer(0.2).timeout
	assert(manager.item_action_popup.is_open())
	assert(manager.item_action_popup.item_data.id == "dirt")
	assert(manager.item_action_popup.get_node("Window/ItemCount").text == "12 IN INVENTORY")
	var behind = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(behind)
	behind.inventory_source = world
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = behind.inventory_scroll.get_global_rect().get_center()
	behind._input(touch)
	assert(behind.inventory_scroll_touch_index == -1, "Info touches must not scroll the inventory behind it")
	behind.free()
	manager.item_action_popup.free()
	manager.free()
	world.free()
	print("[inventory-actions] selection, quantities, permissions, layouts and Info routing passed")
	quit()

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
