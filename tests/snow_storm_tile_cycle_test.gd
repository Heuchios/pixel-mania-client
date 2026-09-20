extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	world.set_meta("world_bulk_load_in_progress", true)
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	world.block_manager = manager
	var renderer = manager.ensure_tilemap_renderer()
	renderer.enabled = true
	renderer.chunk_streaming_enabled = false
	manager.foreground_tilemap_collision_enabled = true
	manager.foreground_tilemap_collision_replaces_nodes_enabled = true
	var cell := Vector2i(12, 15)
	manager.create_block(cell, "water")
	assert(world.blocks[cell].type == "water")
	assert(not has_solid_collision(world, renderer, cell))
	manager.set_snow_storm_visuals_active(true)
	manager.replace_event_block_without_drop(cell, "ice_treasure")
	assert(world.blocks[cell].type == "ice_treasure")
	assert(has_solid_collision(world, renderer, cell))
	manager.remove_block_without_drop(cell)
	assert(not world.blocks.has(cell))
	assert(not has_solid_collision(world, renderer, cell))
	# Refill during the storm must not generate another client-only treasure.
	manager.create_block(cell, "water")
	assert(world.blocks[cell].type == "water")
	assert(not has_solid_collision(world, renderer, cell))
	manager.set_snow_storm_visuals_active(false)
	assert(world.blocks[cell].type == "water")
	assert(not has_solid_collision(world, renderer, cell))
	# Next storm can yield ordinary ice at the same cell, then thaw cleanly.
	manager.set_snow_storm_visuals_active(true)
	manager.replace_event_block_without_drop(cell, "ice_block")
	assert(has_solid_collision(world, renderer, cell))
	manager.set_snow_storm_visuals_active(false)
	manager.replace_event_block_without_drop(cell, "water")
	assert(world.blocks[cell].type == "water")
	assert(not has_solid_collision(world, renderer, cell))
	assert(world.blocks[cell].item_id == load("res://Scripts/ItemAtlasDB.gd").get_item_id_for_key("water"))
	manager.free()
	world.free()
	print("[snow-storm-tile-cycle] success")
	quit()

func has_solid_collision(world, renderer, cell: Vector2i) -> bool:
	if renderer.has_foreground_collision_cell(cell):
		return true
	var body = world.blocks.get(cell, {}).get("node", null)
	if body == null or not is_instance_valid(body):
		return false
	return body.collision_layer != 0 and not body.get_node("CollisionShape2D").disabled