extends SceneTree


const TEST_GRID_POS := Vector2i(4, 4)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("PIXELMANIA_TILEMAP_CHUNK_STREAMING", "0")

	var packed_main := load("res://Scenes/main.tscn") as PackedScene
	if packed_main == null:
		fail_test("Could not load main scene.")
		return
	var main := packed_main.instantiate()
	var world = main.get_node("World")
	var renderer = world.get_node("WorldTileMapRenderer")
	if world == null or renderer == null:
		fail_test("Main scene is missing the world or TileMap renderer.")
		return

	renderer.setup(world)

	var block_manager = load("res://Scripts/block_manager.gd").new()
	block_manager.world = world
	block_manager.tilemap_renderer = renderer
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(
		load("res://Scripts/item_database.gd").ITEMS.duplicate(true)
	)

	var water_texture := load("res://Assets/blocks/Tier_1/basic blocks/water_0.png") as Texture2D
	if water_texture == null:
		fail_test("Could not load the first water frame.")
		return
	var metadata: Dictionary = block_manager.get_block_tilemap_metadata(
		"water",
		"water",
		TEST_GRID_POS,
		false
	)
	if not block_manager.sync_renderer_water_visual_cell(
		renderer,
		TEST_GRID_POS,
		water_texture,
		metadata
	):
		fail_test("Could not sync the water visual cell.")
		return

	var water_layer: TileMapLayer = renderer.water_layer
	var source_id := water_layer.get_cell_source_id(TEST_GRID_POS)
	var atlas_coords := water_layer.get_cell_atlas_coords(TEST_GRID_POS)
	var atlas_source := water_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas_source == null or atlas_source.get_tile_animation_frames_count(atlas_coords) <= 1:
		# Static atlas cells can also animate through BlockManager's frame clock.
		# Exercise that fallback instead of requiring a particular TileSet layout.
		block_manager.sync_tilemap_foreground_animation_cell(TEST_GRID_POS, "water", "water")
		var entry: Dictionary = block_manager.tilemap_foreground_animated_cells.get(TEST_GRID_POS, {})
		if maxi(entry.get("frames", []).size(), entry.get("atlas_frames", []).size()) <= 1:
			fail_test("Surface water has neither TileSet animation nor fallback frames.")
			return
		var first_source: int = water_layer.get_cell_source_id(TEST_GRID_POS)
		var first_coords: Vector2i = water_layer.get_cell_atlas_coords(TEST_GRID_POS)
		# The animation clock uses wall time; a headless SceneTree timer can run
		# ahead of it. Observe rendered frames until the real clock advances.
		var deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			block_manager.apply_tilemap_foreground_animation_frame(TEST_GRID_POS, true)
			if first_source != water_layer.get_cell_source_id(TEST_GRID_POS) or first_coords != water_layer.get_cell_atlas_coords(TEST_GRID_POS):
				break
		if first_source == water_layer.get_cell_source_id(TEST_GRID_POS) and first_coords == water_layer.get_cell_atlas_coords(TEST_GRID_POS):
			fail_test("Surface water fallback did not advance its rendered frame.")
			return

	block_manager.free()
	main.free()
	print("[water-tilemap-animation] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[water-tilemap-animation] " + message)
	quit(1)
