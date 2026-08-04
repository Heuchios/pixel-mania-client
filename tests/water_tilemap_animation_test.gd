extends SceneTree


const WATER_ATLAS_COORDS := Vector2i(1, 3)
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
	if not renderer.has_visual_tile_animation(WATER_ATLAS_COORDS):
		fail_test("Configured water atlas tile is not animated.")
		return

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
		fail_test(
			"Surface water resolved to a static cell: source=%d coords=%s." % [
				source_id,
				str(atlas_coords)
			]
		)
		return

	block_manager.free()
	main.free()
	print("[water-tilemap-animation] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[water-tilemap-animation] " + message)
	quit(1)
