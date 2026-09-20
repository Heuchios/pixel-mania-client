extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://Scripts/world.gd").new()
	# Use the shipped TileSets so visual checks cover the real atlas, not the
	# renderer's dynamically generated fallback sources.
	var main_scene = load("res://Scenes/main.tscn").instantiate()
	for layer_name in ["ForegroundTileMapLayer", "ForegroundCollisionTileMapLayer"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = main_scene.get_node("World/" + layer_name).tile_set.duplicate(true)
		world.add_child(layer)
	main_scene.free()
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
	# Sand used to freeze into a missing PNG: an invisible solid cell which could
	# fall back to dirt on a visual refresh. Check the actual snow-bank artwork,
	# then exercise freeze/thaw and removal next to an excavated corner.
	var bank_data: Dictionary = world.item_database["snow_bank"]
	var bank_texture = bank_data.get("texture")
	assert(bank_texture is Dictionary, "Snow bank must use the shipped terrain atlas")
	var atlas: Texture2D = load(bank_texture["atlas"])
	var bank_image := atlas.get_image()
	var bank_cell: Array = bank_texture["cell"]
	assert(bank_image.get_pixel(int(bank_cell[0]) * 32 + 16, int(bank_cell[1]) * 32 + 16).a > 0.9)
	var corner := Vector2i(20, 20)
	var hole := corner + Vector2i.RIGHT
	manager.create_block(corner, "sand")
	for block_type in ["snow_bank", "sand", "snow_bank"]:
		manager.replace_event_block_without_drop(corner, block_type)
		manager.normalize_block_variant_at(corner)
		assert(world.blocks[corner].type == block_type)
		assert(has_solid_collision(world, renderer, corner))
		assert(renderer.foreground_layer.get_cell_source_id(corner) >= 0, "Solid storm terrain must remain visible")
		if block_type == "snow_bank":
			assert(renderer.foreground_layer.get_cell_atlas_coords(corner) == Vector2i(11, 2))
		assert(not world.blocks.has(hole))
		assert(not has_solid_collision(world, renderer, hole))
	manager.remove_block_without_drop(corner)
	manager.set_snow_storm_visuals_active(false)
	assert(not world.blocks.has(corner))
	assert(not has_solid_collision(world, renderer, corner))
	assert(renderer.foreground_layer.get_cell_source_id(corner) < 0)
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
