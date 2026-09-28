extends SceneTree

const BaseFixture = preload("res://tests/magnet_machine_test.gd")

class WorldFixture extends BaseFixture.WorldFixture:
	var drop_manager
	var inventory = {"dirt": 1}
	var feedback_count := 0
	func play_drop_pickup_target_feedback(_id, _category):
		feedback_count += 1

func _initialize():
	call_deferred("run")

func run():
	var world := WorldFixture.new()
	root.add_child(world)
	world.vending_preview_manager = load("res://Scripts/vending_preview_manager.gd").new()
	world.vending_preview_manager.world = world
	world.add_child(world.vending_preview_manager)
	world.drop_manager = load("res://Scripts/drop_manager.gd").new()
	world.drop_manager.world = world
	world.add_child(world.drop_manager)
	var manager = load("res://Scripts/magnet_machine_manager.gd").new()
	world.add_child(manager)
	manager.setup(world)
	var data = {"world": "MAGNET_TEST", "x": 2, "y": 3, "machine_id": "M", "item_id": "dirt", "item_category": "block", "count": 10,
		"collection_fx": {"event_id": "first", "x": 256, "y": 96, "amount": 3}}
	manager.apply_state(data)
	var machine: AnimatedSprite2D = manager.visuals[Vector2i(2, 3)]
	assert(machine.get_child_count() == 2)
	var item: Sprite2D = machine.get_child(1)
	var origin := item.global_position
	var target: Vector2 = machine.get_node("SelectedItem").global_position
	assert(origin == Vector2(256, 96))
	assert(not manager.states[Vector2i(2, 3)].has("collection_fx"))
	manager.apply_state(data)
	assert(machine.get_child_count() == 2, "Duplicate delivery must not duplicate suction")
	var inventory_item := Sprite2D.new()
	world.add_child(inventory_item)
	inventory_item.position = origin
	world.drop_manager.finish_drop_pickup_vacuum_node({"node": inventory_item, "item_type": "dirt", "item_category": "block"}, target)
	await create_timer(0.4).timeout
	assert(is_instance_valid(item) and is_instance_valid(inventory_item), "Both effects must remain visible beyond the former 0.18s finish")
	assert(item.global_position.distance_to(target) < origin.distance_to(target))
	assert(item.global_position.y < origin.y and item.scale.x < 0.625, "Suction arcs and shrinks toward the machine")
	assert(world.feedback_count == 0)
	await create_timer(0.65).timeout
	assert(not is_instance_valid(item) and not is_instance_valid(inventory_item))
	assert(world.feedback_count == 1, "Only inventory pickup flashes the inventory")
	world.drop_manager.reset_drop_pickup_frame_budgets()
	data.collection_fx.event_id = "second"
	manager.apply_state(data)
	var interrupted = machine.get_child(1)
	manager.reset()
	await process_frame
	assert(not is_instance_valid(interrupted), "Leaving the world cancels active collection effects")
	world.free()
	print("MAGNET_SUCTION_OK: origin, arc, timing, deduplication, feedback routing and cleanup")
	quit()
