extends SceneTree
const Renderer = preload("res://Scripts/world_tilemap_renderer.gd")
const Profiler = preload("res://Scripts/runtime_profiler.gd")
class WorldStub extends Node2D:
	var BLOCK_SIZE := 32
	var player: Node2D = null
func _initialize(): call_deferred("run")
func run():
	var world := WorldStub.new()
	root.add_child(world)
	var renderer = Renderer.new()
	world.add_child(renderer)
	renderer.world = world
	renderer._reset_streaming_state()
	var layer := TileMapLayer.new()
	renderer.add_child(layer)
	renderer.foreground_layer = layer
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source := TileSetAtlasSource.new()
	var bitmap := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.WHITE)
	source.texture = ImageTexture.create_from_image(bitmap)
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i.ZERO)
	var source_id := tile_set.add_source(source)
	layer.tile_set = tile_set
	renderer.active_chunks = {Vector2i.ZERO: true, Vector2i(1, 0): true}
	world.set_meta("world_bulk_load_in_progress", true)
	for x in range(32):
		for y in range(16): renderer._store_cell("foreground", Vector2i(x, y), source_id)
	assert(renderer.dirty_chunks.size() == 2, "Bulk cell updates must coalesce by chunk")
	renderer._process_dirty_chunks(true)
	world.set_meta("world_bulk_load_in_progress", false)
	Profiler.enabled = true
	Profiler.samples.clear()
	Profiler.counters.clear()
	var started := Time.get_ticks_usec()
	for x in [14, 15, 16, 17]:
		var pos := Vector2i(x, 5)
		renderer._remove_cell("foreground", pos)
		assert(layer.get_cell_source_id(pos) == -1)
		renderer._store_cell("foreground", pos, source_id)
		assert(layer.get_cell_source_id(pos) == source_id)
	assert(renderer.dirty_chunks.is_empty(), "Normal edits must not trigger a whole-chunk rebuild")
	assert(int(Profiler.counters.get("chunk_rebuilds", 0)) == 0)
	print("CHUNK_EDIT_PROBE ", JSON.stringify({"edits": 8, "boundary_x": [15, 16], "chunk_rebuilds": 0, "total_usec": Time.get_ticks_usec() - started}))
	for index in range(100): renderer._rebuild_chunk(Vector2i.ZERO)
	var bucket: Dictionary = Profiler.samples["chunk_rebuild_ms"]
	print("CHUNK_REBUILD_PROBE ", JSON.stringify({"samples": bucket.count, "mean_ms": bucket.sum / bucket.count, "max_ms": bucket.max, "cells": 256, "layers": 1}))
	world.queue_free()
	print("CHUNK_EDIT_PERFORMANCE_OK")
	quit()
