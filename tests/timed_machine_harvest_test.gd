extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	for id in ["colored_block_maker", "gem_driller"]:
		var pos := Vector2i.ZERO
		world.blocks.clear()
		world.tackle_box_states.clear()
		assert(manager.is_tackle_box_block_type(id))
		manager.initialize_tackle_box_cooldown_on_place(pos, id)
		var state: Dictionary = world.tackle_box_states[pos].state
		var duration := 7200000 if id == "colored_block_maker" else 43200000
		assert(state.cooldown_ms == duration)
		assert(manager.get_tackle_box_remaining_ms(pos) > duration - 1000)
		assert(not manager.tackle_box_is_ready(pos))
		var art: Dictionary = manager.get_stateful_block_atlas_data(id, pos)
		assert(art.atlas_coords == (Vector2i(12, 16) if id == "colored_block_maker" else Vector2i(6, 16)))
		var block := Node2D.new()
		var visual := Sprite2D.new()
		visual.name = "Visual"
		block.add_child(visual)
		manager.refresh_timed_machine_animation(pos, id, block)
		assert(visual.texture is AtlasTexture)
		if id == "colored_block_maker":
			assert(manager.animated_block_visuals.has(visual.get_instance_id()))
			assert(manager.animated_block_visuals[visual.get_instance_id()].frames.size() == 2)
		state.next_harvest_at_ms = Time.get_unix_time_from_system() * 1000.0 - 1.0
		state.remaining_ms = 0
		assert(manager.tackle_box_is_ready(pos))
		art = manager.get_stateful_block_atlas_data(id, pos)
		assert(art.atlas_coords == (Vector2i(14, 16) if id == "colored_block_maker" else Vector2i(5, 16)))
		manager.refresh_timed_machine_animation(pos, id, block)
		assert(not manager.animated_block_visuals.has(visual.get_instance_id()))
		assert((visual.texture as AtlasTexture).region.position == Vector2(art.atlas_coords) * 32.0)
		block.free()
	assert(world.item_database.colored_block_maker.colored_block_rewards.size() == 28)
	assert(world.item_database.atm_machine.timed_provider_reward == "gems")
	print("TIMED_MACHINE_CLIENT_PASS: placement cooldowns, punch provider classification, producing/ready atlas, two-frame running animation, ready animation cleanup")
	manager.free()
	world.free()
	quit()
