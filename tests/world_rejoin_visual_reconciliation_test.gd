extends SceneTree

const WorldTileMapRenderer = preload("res://Scripts/world_tilemap_renderer.gd")


class MockWorld:
	extends Node2D

	var BLOCK_SIZE: int = 32
	var player: Node2D = null


func _init() -> void:
	call_deferred("_run")


func source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start: int = source.find(start_marker)
	assert(start >= 0, "Missing source marker: " + start_marker)
	var finish: int = source.find(end_marker, start + start_marker.length())
	assert(finish >= 0, "Missing source marker: " + end_marker)
	return source.substr(start, finish - start)


func _run() -> void:
	var block_manager_script: Script = load("res://Scripts/block_manager.gd")
	var save_manager_script: Script = load("res://Scripts/save_manager.gd")
	assert(block_manager_script != null)
	assert(save_manager_script != null)

	var block_manager_source := FileAccess.get_file_as_string("res://Scripts/block_manager.gd")
	var finalize_source := source_between(
		block_manager_source,
		"func finalize_world_load_block_variants",
		"func _can_convert_node_backed_block_to_tilemap"
	)
	assert(finalize_source.contains("refresh_streaming_now"))
	assert(block_manager_source.contains("func schedule_world_entry_tilemap_visual_reconciliation"))

	var mock_world := MockWorld.new()
	root.add_child(mock_world)
	var mock_player := Node2D.new()
	mock_world.add_child(mock_player)
	mock_world.player = mock_player
	mock_world.set_meta("world_bulk_load_in_progress", true)

	var renderer = WorldTileMapRenderer.new()
	mock_world.add_child(renderer)
	renderer.world = mock_world
	renderer.enabled = true
	renderer.chunk_streaming_enabled = true
	renderer._reset_streaming_state()

	var foreground_layer := TileMapLayer.new()
	renderer.add_child(foreground_layer)
	renderer.foreground_layer = foreground_layer

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas_source := TileSetAtlasSource.new()
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	atlas_source.texture = ImageTexture.create_from_image(image)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	var source_id := tile_set.add_source(atlas_source)
	foreground_layer.tile_set = tile_set

	var block_grid := Vector2i(1, 1)
	assert(renderer.set_item_atlas_cell(block_grid, source_id, Vector2i.ZERO))
	renderer.dirty_chunks.clear()

	var before_summary: Dictionary = renderer.get_streaming_summary()
	assert(int((before_summary.get("cached_by_layer", {}) as Dictionary).get("foreground", 0)) == 1)
	assert(int((before_summary.get("active_by_layer", {}) as Dictionary).get("foreground", 0)) == 0)
	assert(foreground_layer.get_cell_source_id(block_grid) == -1)

	renderer.refresh_streaming_now()

	var after_summary: Dictionary = renderer.get_streaming_summary()
	assert(int((after_summary.get("active_by_layer", {}) as Dictionary).get("foreground", 0)) == 1)
	assert(foreground_layer.get_cell_source_id(block_grid) == source_id)
	mock_world.set_meta("world_bulk_load_in_progress", false)

	# Reproduce the rejoin failure: renderer bookkeeping still says the cell is
	# applied, but the physical TileMap cell is gone. Re-syncing the same logical
	# block must restore the real cell instead of trusting the stale cache.
	foreground_layer.erase_cell(block_grid)
	assert(foreground_layer.get_cell_source_id(block_grid) == -1)
	var stale_summary: Dictionary = renderer.get_streaming_summary()
	assert(int((stale_summary.get("active_by_layer", {}) as Dictionary).get("foreground", 0)) == 1)
	assert(renderer.set_item_atlas_cell(block_grid, source_id, Vector2i.ZERO))
	assert(
		foreground_layer.get_cell_source_id(block_grid) == source_id,
		"Matching renderer bookkeeping must not hide a missing physical TileMap cell."
	)

	foreground_layer.erase_cell(block_grid)
	var reconcile_result: Dictionary = renderer.reconcile_active_cells()
	assert(int(reconcile_result.get("repaired_cells", 0)) == 1)
	assert(
		foreground_layer.get_cell_source_id(block_grid) == source_id,
		"Active-cell reconciliation must repair a physical cell lost after world load."
	)

	# Godot silently rejects cells that reference an atlas coordinate which does
	# not exist. The renderer must not cache/report those writes as successful.
	var invalid_grid := Vector2i(2, 1)
	assert(
		not renderer.set_item_atlas_cell(invalid_grid, source_id, Vector2i(99, 99)),
		"Invalid atlas cells must be rejected before a block node is hidden or removed."
	)
	assert(foreground_layer.get_cell_source_id(invalid_grid) == -1)

	mock_world.free()
	print("[world-rejoin-visual-reconciliation] success")
	quit(0)
