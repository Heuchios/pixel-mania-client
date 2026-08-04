extends SceneTree

const SEED_SYSTEM_SCRIPT = preload("res://Scripts/seed_system.gd")


class MockWorld:
	extends Node2D

	const MAX_ITEM_STACK_SIZE := 200

	var drops: Array[Dictionary] = []

	func spawn_item_drop(item_id: String, position: Vector2, is_seed: bool = false) -> void:
		drops.append({
			"item_id": item_id,
			"position": position,
			"is_seed": is_seed,
		})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var world := MockWorld.new()
	root.add_child(world)
	var seed_system = SEED_SYSTEM_SCRIPT.new()
	world.add_child(seed_system)
	seed_system.world = world

	var grid_pos := Vector2i(4, 3)
	var seed_node := Node2D.new()
	world.add_child(seed_node)
	seed_system.planted_seeds[grid_pos] = {
		"node": seed_node,
		"seed_type": "dirt_seed",
		"grow_time": 30.0,
		"max_grow_time": 60.0,
		"stage": 1,
		"mature": false,
		"mutated": false,
	}

	seed_system.harvest_planted_seed(grid_pos)
	assert(seed_system.planted_seeds.has(grid_pos))
	assert(int(seed_system.planted_seeds[grid_pos].get("break_hits", 0)) == 1)
	assert(world.drops.is_empty())

	seed_system.harvest_planted_seed(grid_pos)
	assert(seed_system.planted_seeds.has(grid_pos))
	assert(int(seed_system.planted_seeds[grid_pos].get("break_hits", 0)) == 2)
	assert(world.drops.is_empty())

	seed_system.harvest_planted_seed(grid_pos)
	assert(not seed_system.planted_seeds.has(grid_pos))
	assert(world.drops.size() == 1)
	assert(str(world.drops[0].get("item_id", "")) == "dirt_seed")

	var mature_grid_pos := Vector2i(5, 3)
	var mature_seed_node := Node2D.new()
	world.add_child(mature_seed_node)
	seed_system.planted_seeds[mature_grid_pos] = {
		"node": mature_seed_node,
		"seed_type": "dirt_seed",
		"grow_time": 0.0,
		"max_grow_time": 60.0,
		"stage": 3,
		"mature": true,
		"mutated": false,
	}
	seed_system.harvest_planted_seed(mature_grid_pos)
	assert(not seed_system.planted_seeds.has(mature_grid_pos))

	print("[growing-tree-break-hits] success")
	world.queue_free()
	await process_frame
	quit(0)
