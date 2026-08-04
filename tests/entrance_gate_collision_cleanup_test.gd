extends SceneTree

const WorldTileMapRenderer = preload("res://Scripts/world_tilemap_renderer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer = WorldTileMapRenderer.new()
	root.add_child(renderer)
	renderer.enabled = true
	renderer.chunk_streaming_enabled = true
	renderer._reset_streaming_state()

	var collision_layer := TileMapLayer.new()
	renderer.add_child(collision_layer)
	renderer.foreground_collision_layer = collision_layer

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	atlas_source.texture = ImageTexture.create_from_image(image)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	var source_id := tile_set.add_source(atlas_source)
	collision_layer.tile_set = tile_set

	var old_support_pos := Vector2i(10, 11)
	collision_layer.set_cell(old_support_pos, source_id, Vector2i.ZERO)
	assert(collision_layer.get_cell_source_id(old_support_pos) == source_id)
	assert(not renderer.has_foreground_collision_cell(old_support_pos))

	renderer.erase_foreground_collision_cell(old_support_pos)
	assert(collision_layer.get_cell_source_id(old_support_pos) == -1)

	print("[entrance-gate-collision-cleanup] success")
	quit(0)
