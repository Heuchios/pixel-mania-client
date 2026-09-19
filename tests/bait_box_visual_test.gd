extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	var item = world.item_database.tackle_box
	assert(item.display_name == "Bait Box" and item.block_health == 4)
	assert(item.tackle_box_cooldown_seconds == 14400 and item.tackle_box_reward_count == 5)
	assert(item.no_collision and item.seed == "")
	for state in range(3):
		world.tackle_box_states[Vector2i.ZERO] = {"remaining_ms": [14400000, 7200000, 0][state]}
		assert(manager.get_tackle_box_visual_state_frame(Vector2i.ZERO) == state)
		var art = manager.get_stateful_block_atlas_data("tackle_box", Vector2i.ZERO)
		assert(art.atlas_coords == Vector2i(15 + state, 15))
		assert(manager.get_stateful_block_texture_path("tackle_box", Vector2i.ZERO) == "")
	for id in ["apple", "rose", "lily", "sunflower"]:
		assert(world.item_database[id].block_health == 2)
	assert(world.item_database.sunflower.seed == "tulip_seed")
	print("Bait Box: start/midway/ready atlas states, original cooldown/rewards/collision; flower and apple health preserved")
	manager.free()
	world.free()
	quit()
