extends SceneTree

const BaseFixture = preload("res://tests/magnet_machine_test.gd")
const InventoryManager = preload("res://Scripts/inventory_manager.gd")

class HudManager extends InventoryManager:
	var arrivals: Array = []
	func play_pickup_target_feedback(id: String, category: String):
		arrivals.append([id, category])

class WorldFixture extends BaseFixture.WorldFixture:
	var inventory_manager
	var block_textures: Dictionary = {}
	var hotbar_items: Array = []
	var hotbar_item_categories: Array = []
	func play_drop_pickup_hud_flight(origin: Vector2, id: String, category: String) -> bool:
		return inventory_manager.play_pickup_flight(origin, id, category)

func _initialize():
	call_deferred("run")

func run():
	create_timer(10.0).timeout.connect(func(): quit(1))
	var world := WorldFixture.new()
	root.add_child(world)
	world.vending_preview_manager = load("res://Scripts/vending_preview_manager.gd").new()
	world.add_child(world.vending_preview_manager)
	world.vending_preview_manager.world = world
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.offset = Vector2(12, 8)
	layer.scale = Vector2(1.25, 1.25)
	world.add_child(layer)
	var hud := Control.new()
	layer.add_child(hud)
	var manager := HudManager.new()
	world.add_child(manager)
	manager.set_process(false)
	manager.world = world
	manager.ui_layer_ref = hud
	world.inventory_manager = manager
	var gem := TextureRect.new()
	gem.position = Vector2(24, 19)
	gem.size = Vector2(30, 30)
	gem.texture = world.get_inventory_icon_texture("gem", "currency")
	hud.add_child(gem)
	manager.gem_icon = gem
	var bag := Control.new()
	bag.position = Vector2(450, 500)
	bag.size = Vector2(60, 60)
	hud.add_child(bag)
	manager.hotbar_handle = bag
	assert(manager.get_pickup_target_control("gem", "currency") == gem)
	assert(manager.get_pickup_target_control("dirt", "block") == bag)
	assert(manager.control_screen_center(gem).is_equal_approx(gem.get_global_transform_with_canvas() * (gem.size * 0.5)))
	var drops = load("res://Scripts/drop_manager.gd").new()
	world.add_child(drops)
	drops.world = world
	var pending := Node2D.new()
	world.add_child(pending)
	pending.position = Vector2(320, 280)
	var pending_data := {"node": pending}
	drops.animate_drop_pickup_vacuum(pending_data, Vector2.ZERO, 1.0)
	assert(pending.global_position.distance_to(Vector2(320, 280)) <= 3.0 and pending.modulate.a == 1.0, "Pending pickups wait visibly at their source")
	pending.queue_free()
	var hidden_drop := Node2D.new()
	world.add_child(hidden_drop)
	hidden_drop.hide()
	hidden_drop.modulate.a = 0.1
	hidden_drop.scale = Vector2(0.15, 0.15)
	root.canvas_transform = Transform2D(0.0, Vector2(-40, -25))
	drops.finish_drop_pickup_vacuum_node({"node": hidden_drop, "item_type": "gem", "item_category": "currency", "pickup_vacuum_start_position": Vector2(320, 280)})
	assert(manager.pickup_flights.size() == 1)
	var flight = manager.pickup_flights[0]
	assert(flight.target == gem)
	assert(flight.start_screen == Vector2(280, 255))
	assert(flight.icon.visible and flight.icon.modulate.a == 1.0)
	assert(flight.z_index > 80, "Pickup draws above the gem HUD")
	assert(manager.play_pickup_flight(Vector2(320, 280), "dirt", "block"))
	var item_flight = manager.pickup_flights[1]
	assert(item_flight.target == bag)
	await create_timer(0.6).timeout
	assert(is_instance_valid(flight) and flight.icon.modulate.a == 1.0, "Icon stays opaque and full-size during flight")
	assert(flight.icon.scale.is_equal_approx(flight.icon_scale))
	if "--preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/pickup-flight-preview.png")
	# Moving the camera must not drag the HUD destination; a moved HUD still tracks.
	root.canvas_transform = Transform2D(0.0, Vector2(-300, -100))
	gem.position += Vector2(30, 10)
	flight.update_visual(1.0)
	assert((flight.get_global_transform_with_canvas() * flight.icon.position).is_equal_approx(gem.get_global_transform_with_canvas() * (gem.size * 0.5)))
	await create_timer(0.65).timeout
	assert(not is_instance_valid(flight) and not is_instance_valid(item_flight))
	assert(manager.arrivals.size() == 2)
	var stack_drops = load("res://tests/fixtures/pickup_hud_drop_fixture.gd").new()
	world.add_child(stack_drops)
	stack_drops.world = world
	var stack_node := Node2D.new()
	world.add_child(stack_node)
	var stack := {"node": stack_node, "drop_id": "a", "drop_stack_ids": ["a", "b"], "drop_stack_amounts": {"a": 5, "b": 5}, "amount": 10, "item_type": "dirt", "item_category": "block", "x": 0, "y": 0}
	stack_drops.drops_by_id = {"a": stack, "b": stack}
	assert(stack_drops.remove_drop_by_id("a", true))
	assert(stack.amount == 5 and is_instance_valid(stack_node) and not stack_node.is_queued_for_deletion())
	assert(manager.pickup_flights[-1].target == bag, "Partial stack pickup gets a flight while its remainder stays in the world")
	manager.play_pickup_flight(Vector2(320, 280), "gem", "currency")
	var cancelled = manager.pickup_flights[-1]
	world.current_world_name = "OTHER"
	await process_frame
	await process_frame
	assert(not is_instance_valid(cancelled) and manager.arrivals.size() == 2, "World changes cancel flights without arrival feedback")
	root.canvas_transform = Transform2D.IDENTITY
	world.free()
	print("PICKUP_HUD_FLIGHT_OK: visible icons, gem/bag routing, camera independence, HUD transforms, arrival and cleanup")
	quit()
