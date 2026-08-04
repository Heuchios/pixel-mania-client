extends SceneTree

const EnvironmentManager = preload("res://Scripts/environment_manager.gd")


class TestWorld:
	extends Node

	const WORLD_WIDTH = 100
	const WORLD_HEIGHT = 70
	const BEDROCK_START_Y = 66
	const ENTRANCE_GATE_CLEAR_RADIUS = 3
	const ENTRANCE_GATE_TYPE = "entrance_gate"
	const INVALID_GRID_POS = Vector2i(999999, 999999)
	const BLOCK_SIZE = 32

	var blocks = {}
	var terrain_surface_y = {50: 25}
	var item_database = {}
	var world_generation_manager = null


	func get_surface_y_at_x(_x: int) -> int:
		return 25


	func is_grid_inside_world(grid_pos: Vector2i) -> bool:
		return (
			grid_pos.x >= 0
			and grid_pos.x < WORLD_WIDTH
			and grid_pos.y >= 0
			and grid_pos.y < WORLD_HEIGHT
		)


	func remove_block_without_drop(grid_pos: Vector2i):
		blocks.erase(grid_pos)


	func replace_block_without_drop(grid_pos: Vector2i, block_type: String):
		blocks[grid_pos] = {"type": block_type, "node": null}


	func create_block(grid_pos: Vector2i, block_type: String):
		if not blocks.has(grid_pos):
			replace_block_without_drop(grid_pos, block_type)


	func show_notification(_message: String):
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generated_world = TestWorld.new()
	root.add_child(generated_world)
	var generated_manager = EnvironmentManager.new()
	root.add_child(generated_manager)
	generated_manager.setup(generated_world)
	generated_manager.ensure_generated_entrance_gate()

	var lowered_gate_pos := Vector2i(50, 25)
	var lowered_support_pos := Vector2i(50, 26)
	assert(str(generated_world.blocks.get(lowered_gate_pos, {}).get("type", "")) == "entrance_gate")
	assert(str(generated_world.blocks.get(lowered_support_pos, {}).get("type", "")) == "bedrock")
	assert(not generated_world.blocks.has(Vector2i(50, 24)))
	assert(str(generated_world.blocks.get(Vector2i(49, 25), {}).get("type", "")) == "grass")

	generated_manager.ensure_entrance_gate()
	assert(str(generated_world.blocks.get(lowered_gate_pos, {}).get("type", "")) == "entrance_gate")
	assert(str(generated_world.blocks.get(lowered_support_pos, {}).get("type", "")) == "bedrock")

	var saved_world = TestWorld.new()
	root.add_child(saved_world)
	var saved_gate_pos := Vector2i(50, 24)
	saved_world.replace_block_without_drop(saved_gate_pos, "entrance_gate")
	saved_world.replace_block_without_drop(Vector2i(50, 25), "bedrock")
	var saved_manager = EnvironmentManager.new()
	root.add_child(saved_manager)
	saved_manager.setup(saved_world)
	saved_manager.ensure_entrance_gate()

	assert(str(saved_world.blocks.get(saved_gate_pos, {}).get("type", "")) == "entrance_gate")
	assert(not saved_world.blocks.has(lowered_support_pos))

	print("[generated-entrance-gate-layout] success")
	quit(0)
