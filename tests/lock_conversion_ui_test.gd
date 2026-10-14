extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var world = load("res://tests/fixtures/lock_conversion_world_probe.gd").new()
	world.item_database = load("res://Scripts/item_database.gd").ITEMS.duplicate(true)
	world.inventory = {"world_lock": 100, "super_world_lock": 1, "dirt": 12}
	var manager = load("res://tests/fixtures/lock_conversion_inventory_probe.gd").new()
	manager.world = world
	world.inventory_manager = manager
	var scene = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(scene)
	scene.primary_action_requested.connect(manager._on_inventory_scene_primary_action_requested)
	scene.item_double_action_requested.connect(manager._on_inventory_scene_item_double_action_requested)
	scene.set_inventory_items([
		{"id": "world_lock", "category": "block", "count": 100},
		{"id": "super_world_lock", "category": "block", "count": 1},
		{"id": "dirt", "category": "block", "count": 12},
	])
	await process_frame
	await create_timer(0.30).timeout
	for viewport_size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = viewport_size
		await process_frame
		scene._fit_window_to_viewport()
		await process_frame
		for item_id in ["world_lock", "super_world_lock"]:
			scene._select_slot_item({"id": item_id, "category": "block", "count": world.inventory[item_id]})
			check(not scene.use_button.disabled, "Lock USE stays enabled after selecting its stack")
			var before_requests: int = manager.conversion_requests.size()
			if viewport_size.x == 844:
				await touch(scene.use_button.get_global_rect().get_center())
			else:
				await click(scene.use_button.get_global_rect().get_center())
			check(manager.conversion_requests.size() == before_requests + 1, "USE sends one lock conversion on %s for %s" % [viewport_size, item_id])
			if manager.conversion_requests.size() > before_requests:
				check(manager.conversion_requests.back() == ("to_super" if item_id == "world_lock" else "to_world_locks"), "USE requests the correct exchange direction")
			check(world.inventory == {"world_lock": 100, "super_world_lock": 1, "dirt": 12}, "Online conversion waits for the server instead of changing local counts")
			check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(scene.use_button.get_global_rect()), "Lock conversion button fits the screen")
	manager.conversion_requests.clear()
	# Desktop double-click and mobile double-tap must keep converting too.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.double_click = true
	scene._on_slot_gui_input(mouse, "block:world_lock")
	check(manager.conversion_requests == ["to_super"], "Desktop double-click still converts locks")
	scene.last_slot_tap_key = ""
	scene.last_slot_tap_time_ms = 0
	scene._handle_slot_touch_tap("block:super_world_lock")
	scene._handle_slot_touch_tap("block:super_world_lock")
	check(manager.conversion_requests == ["to_super", "to_world_locks"], "Mobile double-tap still converts locks")
	manager.conversion_requests.clear()
	manager._on_inventory_scene_primary_action_requested({"id": "dirt", "category": "block", "amount": 1})
	check(manager.selected_gameplay_items.has("dirt"), "Other blocks keep their normal USE action")
	check(manager.conversion_requests.is_empty(), "Other blocks cannot convert locks")
	manager.trade_select_active = true
	manager._on_inventory_scene_primary_action_requested({"id": "world_lock", "category": "block", "amount": 1})
	check(manager.selection_actions == ["world_lock"], "Trade selection adds locks without converting them")
	check(manager.conversion_requests.is_empty(), "Selection mode never submits conversion")
	manager.trade_select_active = false
	for state_and_item in [
		[{"world_lock": 99, "super_world_lock": 1}, "world_lock"],
		[{"world_lock": 100, "super_world_lock": 400}, "world_lock"],
		[{"world_lock": 301, "super_world_lock": 1}, "super_world_lock"],
		[{"world_lock": 100, "super_world_lock": 0}, "super_world_lock"],
	]:
		world.inventory = state_and_item[0].duplicate()
		var before: Dictionary = world.inventory.duplicate()
		manager._on_inventory_scene_primary_action_requested({"id": state_and_item[1], "category": "block", "amount": 1})
		check(manager.conversion_requests.is_empty(), "Invalid balances or full stacks cannot submit conversion")
		check(world.inventory == before, "A rejected conversion preserves all locks")
		check(not world.messages.is_empty(), "A rejected conversion explains the requirement")
	# The offline development path uses the same exchange ratio in both directions.
	world.authoritative = false
	world.inventory = {"world_lock": 100, "super_world_lock": 0}
	manager._on_inventory_scene_primary_action_requested({"id": "world_lock", "category": "block", "amount": 1})
	check(int(world.inventory.get("world_lock", 0)) == 0 and int(world.inventory.get("super_world_lock", 0)) == 1, "Offline USE exchanges exactly 100 World Locks for 1 Super World Lock")
	manager._on_inventory_scene_primary_action_requested({"id": "super_world_lock", "category": "block", "amount": 1})
	check(int(world.inventory.get("world_lock", 0)) == 100 and int(world.inventory.get("super_world_lock", 0)) == 0, "Offline USE returns exactly 100 World Locks")
	scene.free()
	manager.free()
	world.free()
	await process_frame
	if failures.is_empty():
		print("LOCK_CONVERSION_UI_PASS: %d checks, PC mouse/mobile touch USE, double-click/double-tap, authority, capacity, selection and offline round trip" % checks)
	quit(0 if failures.is_empty() else 1)


func click(point: Vector2) -> void:
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


func touch(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
