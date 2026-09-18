extends SceneTree

const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")
const DB = preload("res://Scripts/item_database.gd")
const ITEM := "the_starry_night"
const REGION := Rect2(704, 864, 64, 64)

func _init() -> void:
	call_deferred("run")


func run() -> void:
	OS.set_environment("PIXELMANIA_TILEMAP_CHUNK_STREAMING", "0")
	var authored_scene: Node = load("res://Scenes/main.tscn").instantiate()
	var authored_layer: TileMapLayer = authored_scene.get_node("World/ForegroundTileMapLayer")
	var tile_set := authored_layer.tile_set
	var atlas_source := tile_set.get_source(0) as TileSetAtlasSource
	assert(atlas_source.get_tile_size_in_atlas(Vector2i(22, 27)) == Vector2i(2, 2))
	var item_id := ATLAS.get_item_id_for_key(ITEM)
	for source in [null, tile_set]:
		var icon := ATLAS.get_item_icon(item_id, source)
		assert(icon != null and icon.region == REGION, "Full artwork must work with and without a world TileSet")
		assert(icon.get_size() == Vector2(64, 64))
		assert(ATLAS.get_item_icon(item_id, source) == icon, "Repeated lookups should reuse the full-size icon")
	assert(ATLAS.get_item_icon(ATLAS.get_item_id_for_key("sunflower_painting"), tile_set).get_size() == Vector2(32, 32))
	authored_scene.free()

	var world = load("res://tests/starry_night_world_fixture.gd").new()
	root.add_child(world)
	var layer := TileMapLayer.new()
	layer.name = "ForegroundTileMapLayer"
	layer.tile_set = tile_set
	world.add_child(layer)
	world.item_database = ATLAS.merge_item_database(DB.ITEMS.duplicate(true))
	world.tier_1_splice_balance = DB.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.setup_item_database()
	assert(world.block_textures[ITEM].region == REGION, "World texture cache must not crop the artwork")
	world.setup_block_manager()
	world.setup_item_gameplay_manager()
	world.setup_drop_manager()
	assert(world.get_inventory_icon_texture(ITEM, "block").region == REGION)
	assert(world.get_item_drop_texture(ITEM, "block").region == REGION)
	assert(world.get_seed_preview_block_texture(ITEM).region == REGION)

	var grid := Vector2i(10, 10)
	for placement in range(2):
		world.create_block(grid, ITEM)
		assert(world.blocks.has(grid))
		var block: Node2D = world.blocks[grid].node
		assert(is_instance_valid(block), "Large decorative items must retain their sprite node")
		var visual: Sprite2D = block.get_node("Visual")
		assert(visual.visible and visual.texture.get_size() == Vector2(64, 64))
		assert(visual.texture.region == REGION)
		assert(visual.position == Vector2(16, -16), "Artwork should extend upward and right from its anchor")
		assert(visual.get_rect().size == Vector2(64, 64))
		await process_frame
		var collision: CollisionShape2D = block.get_node_or_null("CollisionShape2D")
		assert(collision == null or collision.disabled, "The painting must remain non-solid")
		world.remove_block_without_drop(grid)
		assert(not world.blocks.has(grid), "Removal must remove the entire painting")
		await process_frame
	world.free()
	await process_frame
	print("STARRY_NIGHT_OK: 64x64 region, icons, drops, seed preview, placement, collision and recreate")
	quit()
