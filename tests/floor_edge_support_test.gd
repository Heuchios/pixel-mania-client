extends SceneTree

class FloorRects extends Node:
	var rectangles: Dictionary = {}
	func get_block_collision_rect_for_grid(grid: Vector2i, _type: String) -> Rect2:
		return rectangles[grid]

class FixtureWorld extends Node:
	const BLOCK_SIZE := 32
	var blocks: Dictionary = {}
	var block_manager: Node
	var noclip_enabled := false

var player
var fixture_world: FixtureWorld
var floor_body: StaticBody2D
var floor_shape: CollisionShape2D
var support

func _initialize() -> void:
	_run.call_deferred()

func _land(x: float, top: float = -16.0) -> void:
	player.position = Vector2(x, top - 12.0)
	player.velocity = Vector2(0.0, 200.0)
	for frame in range(8):
		await physics_frame
		player.move_and_slide()
		if player.is_on_floor():
			return
	assert(false, "The baseline rectangular body must contact this edge")

func _run() -> void:
	support = load("res://Scripts/player_floor_support.gd")
	fixture_world = FixtureWorld.new()
	fixture_world.block_manager = FloorRects.new()
	fixture_world.blocks[Vector2i.ZERO] = {"type": "dirt"}
	fixture_world.block_manager.rectangles[Vector2i.ZERO] = Rect2(-16, -16, 32, 32)
	root.add_child(fixture_world)
	root.add_child(fixture_world.block_manager)
	floor_body = StaticBody2D.new()
	floor_shape = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(32, 32)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	player = load("res://tests/corner_contact_fixture.gd").new()
	player.fixture_world = fixture_world
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var body_rectangle := RectangleShape2D.new()
	body_rectangle.size = Vector2(17, 24)
	shape.shape = body_rectangle
	shape.position = Vector2(0.5, -5)
	player.add_child(shape)
	root.add_child(player)
	player.configure_player_floor_collision()
	for side in [-1, 1]:
		for overlap in [0.25, 1.0, 2.0]:
			await _land(side * (24.5 - overlap) - 0.5)
			var before: Vector2 = player.position
			player.velocity.x = side * 23.0
			player.coyote_timer = 0.075
			player.air_jumps_used = 1
			assert(support.release_unsupported_edge(player, fixture_world), "A toe-sized contact must release on either side")
			assert(not player.is_on_floor())
			assert(is_equal_approx(player.velocity.x, side * 23.0), "Do not inject sideways velocity")
			assert(player.velocity.y == 0.0, "Do not inject a falling boost")
			assert(player.coyote_timer == 0.075 and player.air_jumps_used == 1)
			assert(player.position.distance_to(before) <= 3.2, "Clear only the unsupported sliver")
			player.velocity.x = 0.0
			for frame in range(8):
				await physics_frame
				player.apply_gravity(1.0 / 60.0)
				player.move_and_slide()
			assert(player.position.y > before.y + 2.0 and not player.is_on_floor(), "Gravity must resume without reattaching")
		for overlap in [3.0, 4.0, 8.0]:
			await _land(side * (24.5 - overlap) - 0.5)
			var before: Vector2 = player.position
			for frame in range(6):
				await physics_frame
				assert(not support.release_unsupported_edge(player, fixture_world))
				player.velocity = Vector2(0, 20)
				player.move_and_slide()
			assert(player.is_on_floor() and player.position.distance_to(before) < 0.01, "Supported edges must stay stable")
	# Adjacent blocks supply continuous support even when the first tile has only a sliver.
	fixture_world.blocks[Vector2i(1, 0)] = {"type": "dirt"}
	fixture_world.block_manager.rectangles[Vector2i(1, 0)] = Rect2(16, -16, 32, 32)
	var neighbor := StaticBody2D.new()
	neighbor.position = Vector2(32, 0)
	var neighbor_shape := CollisionShape2D.new()
	neighbor_shape.shape = rectangle
	neighbor.add_child(neighbor_shape)
	root.add_child(neighbor)
	await _land(21.5)
	assert(not support.release_unsupported_edge(player, fixture_world) and player.is_on_floor(), "Never drop a player at a tile seam")
	neighbor.free()
	fixture_world.blocks.erase(Vector2i(1, 0))
	# One-way platforms retain their real top surface and normal jump-through behavior.
	var platform_shape := RectangleShape2D.new()
	platform_shape.size = Vector2(32, 6)
	floor_shape.shape = platform_shape
	floor_shape.position.y = -13
	floor_shape.one_way_collision = true
	await _land(21.5)
	assert(support.release_unsupported_edge(player, fixture_world), "One-way platform corners also release")
	await _land(19.5)
	assert(not support.release_unsupported_edge(player, fixture_world))
	player.velocity.y = -430.0
	var jump_position: Vector2 = player.position
	assert(not support.release_unsupported_edge(player, fixture_world) and player.position == jump_position, "A jump is never moved sideways")
	# Use an offset narrow collider instead of assuming every block occupies a full tile.
	floor_shape.one_way_collision = false
	platform_shape.size = Vector2(12, 20)
	floor_shape.position = Vector2(0, 6)
	fixture_world.block_manager.rectangles[Vector2i.ZERO] = Rect2(-6, -4, 12, 20)
	await _land(11.5, -4)
	assert(support.release_unsupported_edge(player, fixture_world), "Custom colliders use their own width and top")
	# Wide machines are stored at an anchor outside the player's queried tile.
	var wide := RectangleShape2D.new()
	wide.size = Vector2(96, 32)
	floor_shape.shape = wide
	floor_shape.position = Vector2.ZERO
	fixture_world.block_manager.rectangles[Vector2i.ZERO] = Rect2(-48, -16, 96, 32)
	await _land(54.5)
	assert(support.release_unsupported_edge(player, fixture_world), "Multi-tile machines resolve their physical collider anchor")
	# The production movement step must release the corner before gravity/jump decisions.
	floor_shape.shape = rectangle
	floor_shape.position = Vector2.ZERO
	fixture_world.block_manager.rectangles[Vector2i.ZERO] = Rect2(-16, -16, 32, 32)
	await _land(21.5)
	var step_start: Vector2 = player.position
	player.coyote_timer = 0.075
	player.run_player_movement_step(1.0 / 60.0)
	assert(not player.is_on_floor() and player.velocity.y > 0.0 and player.position.y > step_start.y, "The complete movement step resumes falling")
	assert(player.coyote_timer > 0.0 and player.coyote_timer < 0.075, "Keep the existing coyote-jump grace period")
	var wall := StaticBody2D.new()
	wall.position = Vector2(47, -32)
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)
	await _land(21.5)
	support.release_unsupported_edge(player, fixture_world)
	assert(player.get_player_collision_rect_at(player.global_position).end.x <= 31.01, "Edge clearance cannot push the body through a wall")
	wall.free()
	# Native slopes and unknown non-grid floors retain their normal behavior.
	floor_body.rotation = 0.20
	await _land(0.0)
	assert(absf(player.get_floor_normal().x) > 0.01)
	assert(not support.release_unsupported_edge(player, fixture_world))
	floor_body.rotation = 0.0
	await _land(21.5)
	fixture_world.blocks.clear()
	assert(not support.release_unsupported_edge(player, fixture_world))
	# The production terrain also uses TileMapLayer collision instead of block nodes.
	floor_shape.disabled = true
	fixture_world.blocks[Vector2i.ZERO] = {"type": "dirt"}
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	var tile := atlas.get_tile_data(Vector2i.ZERO, 0)
	tile.set_collision_polygons_count(0, 1)
	tile.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	var terrain := TileMapLayer.new()
	terrain.tile_set = tile_set
	terrain.position = Vector2(-16, -16)
	root.add_child(terrain)
	terrain.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	await physics_frame
	await physics_frame
	await _land(-22.5)
	assert(support.release_unsupported_edge(player, fixture_world), "TileMapLayer edges release on the same rules")
	terrain.free()
	player.free()
	floor_body.free()
	fixture_world.block_manager.free()
	fixture_world.free()
	print("FLOOR_EDGE_SUPPORT: PASS; mirrored overhangs, stable edges, seams, one-way platforms, jumping, custom colliders and movement integration")
	quit()
