extends SceneTree

const TEST_GRID_POS := Vector2i(8, 6)


class MockWorld:
	extends Node2D

	var BLOCK_SIZE := 32
	var player: Node2D = null
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}
	var block_textures: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _make_shift_block() -> Dictionary:
	var body := StaticBody2D.new()
	body.name = "ShiftBlock"
	body.position = Vector2(TEST_GRID_POS * 32)
	body.collision_layer = 1
	body.collision_mask = 1

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision.shape = shape
	body.add_child(collision)

	return {
		"body": body,
		"collision": collision,
		"data": {
			"type": "shift_block",
			"node": body
		}
	}


func _make_collision_layer(renderer: Node) -> TileMapLayer:
	var collision_layer := TileMapLayer.new()
	renderer.add_child(collision_layer)
	renderer.foreground_collision_layer = collision_layer

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var atlas_source := TileSetAtlasSource.new()
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	atlas_source.texture = ImageTexture.create_from_image(image)
	atlas_source.texture_region_size = Vector2i(32, 32)
	atlas_source.create_tile(Vector2i.ZERO)
	var source_id := tile_set.add_source(atlas_source)
	var tile_data := atlas_source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([
			Vector2(-16, -16),
			Vector2(16, -16),
			Vector2(16, 16),
			Vector2(-16, 16)
		])
	)
	collision_layer.tile_set = tile_set
	collision_layer.set_cell(TEST_GRID_POS, source_id, Vector2i.ZERO)
	return collision_layer


func _run() -> void:
	var world := MockWorld.new()
	root.add_child(world)
	world.item_database["shift_block"] = {
		"category": "block",
		"solid": true,
		"collidable": true,
		"collision_type": "full",
		"collision_size": Vector2(32, 32),
		"collision_offset": Vector2.ZERO,
		"colour_cycle_block": true
	}

	var renderer = load("res://Scripts/world_tilemap_renderer.gd").new()
	renderer.name = "WorldTileMapRenderer"
	world.add_child(renderer)
	renderer.enabled = true
	renderer.chunk_streaming_enabled = false
	renderer._reset_streaming_state()
	var collision_layer := _make_collision_layer(renderer)

	var block_manager_script: Script = load("res://Scripts/block_manager.gd")
	assert(block_manager_script != null, "Could not load BlockManager.")
	var block_manager = block_manager_script.new()
	block_manager.world = world
	block_manager.tilemap_renderer = renderer
	block_manager.foreground_tilemap_collision_enabled = true
	block_manager.foreground_tilemap_collision_replaces_nodes_enabled = true

	# Reproduce a rejoin split: the live Shift Block node is still present, but
	# its shape was disabled after collision ownership moved to the TileMapLayer.
	var old_block := _make_shift_block()
	var old_body: StaticBody2D = old_block.body
	var old_collision: CollisionShape2D = old_block.collision
	world.add_child(old_body)
	old_collision.disabled = true
	old_body.set_meta("tilemap_collision", true)
	old_body.set_meta("tilemap_collision_replaces_node", true)
	var old_data: Dictionary = old_block.data
	old_data["tilemap_collision"] = true
	old_data["tilemap_collision_kind"] = "full"
	world.blocks[TEST_GRID_POS] = old_data

	assert(collision_layer.get_cell_source_id(TEST_GRID_POS) >= 0)
	assert(
		not block_manager.is_foreground_tilemap_collision_candidate(TEST_GRID_POS, old_data),
		"Shift Block must retain node-owned collision."
	)
	assert(not block_manager.sync_foreground_tilemap_collision_for_block(TEST_GRID_POS, old_data))
	assert(collision_layer.get_cell_source_id(TEST_GRID_POS) == -1)
	assert(not old_collision.disabled, "Split ownership recovery must restore the node shape.")
	assert(not old_body.has_meta("tilemap_collision"))
	assert(not old_body.has_meta("tilemap_collision_replaces_node"))
	var repaired_data: Dictionary = world.blocks[TEST_GRID_POS]
	assert(not repaired_data.has("tilemap_collision"))
	assert(not repaired_data.has("tilemap_collision_kind"))

	# Recreate the block as a full world-state rejoin would. Its collider must be
	# active immediately and no shared collision cell may be installed.
	world.blocks.clear()
	old_body.queue_free()
	var rejoined_block := _make_shift_block()
	var rejoined_body: StaticBody2D = rejoined_block.body
	var rejoined_collision: CollisionShape2D = rejoined_block.collision
	world.add_child(rejoined_body)
	var rejoined_data: Dictionary = rejoined_block.data
	world.blocks[TEST_GRID_POS] = rejoined_data
	block_manager.configure_block_collision(rejoined_body, "shift_block", TEST_GRID_POS)
	assert(not rejoined_collision.disabled, "Rejoined Shift Block must have one active node collider.")
	assert(collision_layer.get_cell_source_id(TEST_GRID_POS) == -1)
	assert(not rejoined_body.has_meta("tilemap_collision_replaces_node"))

	block_manager.free()
	print("[shift-block-rejoin-collision] success")
	quit(0)
