extends SceneTree


func _init() -> void:
	call_deferred("_run")


func source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	assert(start >= 0, "Missing source marker: " + start_marker)
	var finish := source.find(end_marker, start + start_marker.length())
	assert(finish >= 0, "Missing source marker: " + end_marker)
	return source.substr(start, finish - start)


func _run() -> void:
	assert(load("res://Scripts/block_manager.gd") != null)
	var source := FileAccess.get_file_as_string("res://Scripts/block_manager.gd")
	var dependency_source := source_between(
		source,
		"func has_neighbor_dependent_visual_variant",
		"func refresh_neighbor_dependent_block_variant_at"
	)
	assert(dependency_source.contains("clean_type == \"dirt\""))
	assert(dependency_source.contains("clean_type == \"water\""))
	assert(dependency_source.contains("clean_type == \"wood\""))
	assert(dependency_source.contains("clean_type == \"climbing_vine\""))
	assert(dependency_source.contains("has_platform_visual_variants(clean_type)"))
	assert(dependency_source.contains("has_vertical_variant_atlas_coords(clean_type)"))
	assert(dependency_source.contains("has_connected_visual_variants(clean_type)"))
	assert(not dependency_source.contains("\"lava\""))

	var refresh_source := source_between(
		source,
		"func refresh_neighbor_dependent_block_variant_at",
		"func update_vertical_block_variants_around"
	)
	assert(refresh_source.contains("has_neighbor_dependent_visual_variant(block_type)"))
	assert(refresh_source.contains("normalize_block_variant_at(grid_pos, false)"))

	var update_source := source_between(
		source,
		"func update_vertical_block_variants_around",
		"func finalize_world_load_block_variants"
	)
	assert(update_source.contains("refresh_neighbor_dependent_block_variant_at"))
	assert(not update_source.contains("\n\t\tnormalize_block_variant_at("))

	var renderer_script = load("res://Scripts/world_tilemap_renderer.gd")
	assert(renderer_script != null)
	var renderer = renderer_script.new()
	root.add_child(renderer)
	renderer.enabled = true
	renderer.chunk_streaming_enabled = false
	renderer._reset_streaming_state()

	var foreground_layer := TileMapLayer.new()
	renderer.add_child(foreground_layer)
	renderer.foreground_layer = foreground_layer

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	atlas_source.texture = ImageTexture.create_from_image(image)
	atlas_source.texture_region_size = Vector2i(32, 32)
	var stone_atlas_coords := Vector2i(0, 2)
	var lava_atlas_coords := Vector2i(0, 3)
	atlas_source.create_tile(stone_atlas_coords)
	atlas_source.create_tile(lava_atlas_coords)
	var source_id := tile_set.add_source(atlas_source)
	foreground_layer.tile_set = tile_set

	var lava_cells := [
		Vector2i(9, 62),
		Vector2i(10, 62),
		Vector2i(10, 63)
	]
	for lava_cell in lava_cells:
		assert(renderer.set_item_atlas_cell(lava_cell, source_id, lava_atlas_coords))
	var broken_neighbor := Vector2i(9, 63)
	assert(renderer.set_item_atlas_cell(broken_neighbor, source_id, stone_atlas_coords))
	assert(foreground_layer.get_used_cells().size() == lava_cells.size() + 1)

	renderer.erase_block_cell(broken_neighbor)
	assert(foreground_layer.get_cell_source_id(broken_neighbor) == -1)
	assert(foreground_layer.get_used_cells().size() == lava_cells.size())
	for lava_cell in lava_cells:
		assert(foreground_layer.get_cell_source_id(lava_cell) == source_id)
		assert(foreground_layer.get_cell_atlas_coords(lava_cell) == lava_atlas_coords)

	print("[generated-lava-neighbor-refresh] success")
	quit(0)
