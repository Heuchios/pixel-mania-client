extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	Input.emulate_touch_from_mouse = true
	print("TOUCHSCREEN: ", DisplayServer.is_touchscreen_available())
	var policy = root.get_node("MobileScrollPolicy")
	if not node_added.is_connected(policy._on_node_added):
		node_added.connect(policy._on_node_added)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 250)
	root.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for i in range(20):
		var button := Button.new()
		button.text = "Row %d" % i
		button.custom_minimum_size = Vector2(260, 70)
		rows.add_child(button)
	for i in range(5):
		await process_frame
	check(rows.get_child(0).mouse_filter == Control.MOUSE_FILTER_PASS, "Dynamically added list buttons must be configured automatically")
	policy.configure_tree(scroll)
	check(rows.get_child(0).mouse_filter == Control.MOUSE_FILTER_PASS, "List buttons must pass drag input")
	var received: Array = []
	scroll.gui_input.connect(func(event): received.append(event))
	var clicks: Array = []
	rows.get_child(0).pressed.connect(func(): clicks.append(true))
	mouse(Vector2(150, 130), true)
	for y in [110, 90, 60, 20]:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(150, y)
		motion.relative = Vector2(0, -30)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	mouse(Vector2(150, 20), false)
	check(received.size() >= 5, "Swipes over cards must reach ScrollContainer")
	check(clicks.is_empty(), "Swiping must not select a card")
	print("NATIVE SCROLL OFFSET: ", scroll.scroll_vertical, " received=", received.size())
	check(scroll.scroll_vertical > 0, "Native swipe must move the list")
	# Dedicated controls retain their own gestures.
	var slider := HSlider.new()
	rows.add_child(slider)
	policy.configure_control(slider)
	check(slider.mouse_filter == Control.MOUSE_FILTER_STOP, "Slider gesture must remain independent")
	var custom := ScrollContainer.new()
	custom.set_meta("custom_touch_scroll", true)
	root.add_child(custom)
	var slot := Button.new()
	custom.add_child(slot)
	policy.configure_control(slot)
	check(slot.mouse_filter == Control.MOUSE_FILTER_STOP, "Custom inventory handling must remain independent")
	scroll.scroll_vertical = 0
	await process_frame
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(150, 130)
	tap.pressed = true
	root.push_input(tap, true)
	tap = tap.duplicate()
	tap.pressed = false
	root.push_input(tap, true)
	check(clicks.size() == 1, "A normal tap must still select exactly once")
	scroll.queue_free()
	custom.queue_free()
	await process_frame
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	root.add_child(shop)
	for i in range(15):
		await process_frame
	# Select the category with the greatest overflow, then test scaled thumb coordinates.
	for grid in shop._category_grids:
		grid.visible = false
	var best = shop._category_grids[0]
	for grid in shop._category_grids:
		if grid.get_child_count() > best.get_child_count():
			best = grid
	best.visible = true
	for i in range(40):
		best.add_child(best.get_child(0).duplicate())
	for i in range(5):
		await process_frame
	check(best.get_child(0).mouse_filter == Control.MOUSE_FILTER_PASS, "Shop cards must allow swipes")
	for ui_scale in [1.0, 1.25]:
		shop.scale = Vector2.ONE * ui_scale
		shop.item_scroll.scroll_vertical = 0
		shop._sync_item_scroll_slider()
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = true
		touch.position = shop.item_scroll_handle.size * 0.5
		shop._on_item_scroll_handle_gui_input(touch)
		check(shop.item_scroll.scroll_vertical == 0, "Touching handle must not jump at scale %s" % ui_scale)
		var fake_mouse := InputEventMouseButton.new()
		fake_mouse.device = InputEvent.DEVICE_ID_EMULATION
		fake_mouse.button_index = MOUSE_BUTTON_LEFT
		fake_mouse.pressed = true
		shop._on_item_scroll_handle_gui_input(fake_mouse)
		check(shop._item_scroll_handle_touch_index == 0, "Emulated mouse must not steal touch drag")
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = touch.position + Vector2(0, 60)
		shop._on_item_scroll_handle_gui_input(drag)
		check(shop.item_scroll.scroll_vertical > 0, "Handle must move scroll at scale %s" % ui_scale)
		touch.pressed = false
		shop._on_item_scroll_handle_gui_input(touch)
		check(not shop._item_scroll_handle_dragging, "Release must end drag")
	shop.queue_free()
	await process_frame
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(inventory)
	for i in range(5):
		await process_frame
	check(inventory.inventory_scroll.get_meta("custom_touch_scroll", false), "Inventory must opt out of native gesture policy")
	inventory.queue_free()
	await process_frame
	var recipes = load("res://Scenes/ui/recipe_book/RecipeBookScene.tscn").instantiate()
	root.add_child(recipes)
	var entries: Array = []
	for i in range(80):
		entries.append({"id": "recipe_%d" % i, "name": "Recipe %d" % i, "category": "blocks", "method": "splicing"})
	recipes.set_all_recipes({1: entries})
	recipes.open()
	for i in range(12):
		await process_frame
	var checked := 0
	for button in recipes.find_children("*", "Button", true, false):
		var parent = button.get_parent()
		while parent != null and not parent is ScrollContainer:
			parent = parent.get_parent()
		if parent is ScrollContainer:
			checked += 1
			check(button.mouse_filter != Control.MOUSE_FILTER_STOP, "Recipe buttons must allow swipes")
	check(checked > 0, "Recipe scroll content must be exercised")
	recipes.queue_free()
	print("MOBILE_SCROLL: %d failures" % failures)
	quit(1 if failures else 0)
func mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
