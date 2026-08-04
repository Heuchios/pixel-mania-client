extends SceneTree


const BLOCK_MANAGER_SCRIPT_PATH := "res://Scripts/block_manager.gd"
const MOBILE_CONTROLS_SCRIPT_PATH := "res://Scripts/mobile_controls.gd"
const WORLD_SCRIPT_PATH := "res://Scripts/world.gd"


class MockWorld:
	extends Node2D

	const BLOCK_SIZE := 32
	const INTERACTION_PIXEL_RANGE := 128.0
	const WORLD_WIDTH := 20
	const WORLD_HEIGHT := 10
	const INVALID_GRID_POS := Vector2i(999999, 999999)

	var blocks: Dictionary = {}
	var item_database: Dictionary = {
		"test_block": {
			"collidable": true,
			"occupies_collision_area": false
		},
		"large_block": {
			"collidable": false,
			"occupies_collision_area": true,
			"collision_size": Vector2(64.0, 64.0)
		}
	}
	var player: Node2D = null
	var player_facing_direction := 1

	func get_player_grid_position() -> Vector2i:
		return Vector2i(
			int(roundf(player.global_position.x / float(BLOCK_SIZE))),
			int(roundf(player.global_position.y / float(BLOCK_SIZE)))
		)

	func is_grid_inside_world(grid_pos: Vector2i) -> bool:
		return grid_pos.x >= 0 and grid_pos.x < WORLD_WIDTH and grid_pos.y >= 0 and grid_pos.y < WORLD_HEIGHT

	func can_reach_grid(grid_pos: Vector2i) -> bool:
		var block_center := Vector2(float(grid_pos.x * BLOCK_SIZE), float(grid_pos.y * BLOCK_SIZE))
		return player.global_position.distance_to(block_center) <= INTERACTION_PIXEL_RANGE

	func has_planted_seed(_grid_pos: Vector2i) -> bool:
		return false

	func has_visible_electrical_tile_at(_grid_pos: Vector2i) -> bool:
		return false


class MockMobileWorld:
	extends Node

	var in_world := true
	var player: Node = null
	var punch_animation_count := 0
	var punch_reach_count := 0
	var adjacent_punch_count := 0

	func play_player_punch_animation() -> void:
		punch_animation_count += 1

	func punch_facing_reach_block() -> void:
		punch_reach_count += 1

	func punch_facing_block() -> void:
		adjacent_punch_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var block_manager_script = load(BLOCK_MANAGER_SCRIPT_PATH)
	var world_script = load(WORLD_SCRIPT_PATH)
	assert(block_manager_script is GDScript)
	assert(world_script is GDScript)
	var has_world_reach_proxy := false
	for method_data in world_script.get_script_method_list():
		if str(method_data.get("name", "")) == "punch_facing_reach_block":
			has_world_reach_proxy = true
			break
	assert(has_world_reach_proxy, "World is missing the mobile punch reach proxy.")

	var world := MockWorld.new()
	var player := Node2D.new()
	world.player = player
	world.add_child(player)
	root.add_child(world)

	var block_manager = block_manager_script.new()
	block_manager.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(block_manager)
	block_manager.world = world

	for x in range(1, 6):
		world.blocks[Vector2i(x, 0)] = {"type": "test_block"}

	for expected_x in range(1, 5):
		var target: Vector2i = block_manager.get_mobile_facing_punch_target_grid()
		assert(target == Vector2i(expected_x, 0), "Mobile punch did not select the nearest reachable block.")
		world.blocks.erase(target)

	assert(
		block_manager.get_mobile_facing_punch_target_grid() == MockWorld.INVALID_GRID_POS,
		"Mobile punch selected a block beyond the normal reach limit."
	)
	world.blocks.clear()
	world.blocks[Vector2i(2, 1)] = {"type": "large_block"}
	assert(
		block_manager.get_mobile_facing_punch_target_grid() == Vector2i(1, 0),
		"Mobile punch missed the reachable occupied area of an oversized block."
	)

	world.player_facing_direction = -1
	world.blocks.clear()
	world.blocks[Vector2i(1, 0)] = {"type": "test_block"}
	world.blocks[Vector2i(2, 0)] = {"type": "test_block"}
	player.global_position = Vector2(3.0 * MockWorld.BLOCK_SIZE, 0.0)
	assert(
		block_manager.get_mobile_facing_punch_target_grid() == Vector2i(2, 0),
		"Mobile punch did not scan nearest-first in the left-facing direction."
	)

	var mobile_controls_script = load(MOBILE_CONTROLS_SCRIPT_PATH)
	assert(mobile_controls_script is GDScript)
	var mobile_world := MockMobileWorld.new()
	root.add_child(mobile_world)
	var mobile_controls = mobile_controls_script.new()
	mobile_controls.process_mode = Node.PROCESS_MODE_DISABLED
	mobile_world.add_child(mobile_controls)
	mobile_controls.world = mobile_world
	mobile_controls._trigger_punch(false)
	assert(mobile_world.punch_animation_count == 1, "Mobile punch did not play its local animation once.")
	assert(mobile_world.punch_reach_count == 1, "Mobile punch did not route through the reach scan once.")
	assert(mobile_world.adjacent_punch_count == 0, "Mobile punch also called the legacy adjacent-only action.")
	mobile_controls.active_action_touches["punch"] = 7
	mobile_controls.punch_hold_repeat_active = true
	mobile_controls._update_punch_hold(0.31)
	assert(mobile_world.punch_reach_count == 2, "Holding the mobile punch button did not repeat the reach action.")
	assert(mobile_world.adjacent_punch_count == 0, "Held mobile punch called the legacy adjacent-only action.")
	mobile_controls.active_action_touches.clear()

	print("[mobile-punch-reach] success")
	world.queue_free()
	mobile_world.queue_free()
	await process_frame
	quit(0)
