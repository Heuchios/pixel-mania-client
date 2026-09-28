extends SceneTree

const Generator = preload("res://Scripts/world_generation_manager.gd")

class FixtureWorld extends Node:
	const WORLD_WIDTH := 100
	const WORLD_HEIGHT := 70
	const SPAWN_GRID_X := 10
	const SPAWN_FLAT_RADIUS := 5
	var blocks: Dictionary = {}
	var terrain_surface_y: Dictionary = {}
	var block_manager = null
	func create_block(cell: Vector2i, type: String) -> void:
		assert(not blocks.has(cell), "Tree must never overwrite another block")
		blocks[cell] = {"type": type}
	func replace_block_without_drop(cell: Vector2i, type: String) -> void:
		blocks[cell] = {"type": type}


func _initialize() -> void:
	var world := FixtureWorld.new()
	var generator := Generator.new()
	generator.setup(world)
	var total := 0
	for seed_value in range(1, 101):
		world.blocks.clear()
		for x in world.WORLD_WIDTH:
			var y := 32 + roundi(sin(float(x) * 0.15 + seed_value) * 3.0)
			world.terrain_surface_y[x] = y
			world.blocks[Vector2i(x, y)] = {"type": "grass"}
		var ground: Dictionary = world.blocks.duplicate(true)
		generator.generation_seed = seed_value
		generator.generation_rng.seed = seed_value
		generator.generate_trees()
		var first: Dictionary = world.blocks.duplicate(true)
		world.blocks = ground.duplicate(true)
		generator.generation_rng.seed = seed_value
		generator.generate_trees()
		assert(world.blocks == first, "Identical seed must reproduce the same trees")
		for cell: Vector2i in world.blocks:
			var type: String = world.blocks[cell].type
			if not type in ["wood", "leaf"]:
				continue
			assert(cell.y >= 0 and cell.y < world.WORLD_HEIGHT)
			assert(not generator.is_spawn_safe_column(cell.x) and abs(cell.x - 50) > 3)
			if type == "wood":
				var below := cell + Vector2i.DOWN
				assert(world.blocks.has(below), "No diagonal/floating trunk segments")
				if below.y == world.terrain_surface_y[cell.x]:
					assert(world.blocks[below].type == "dirt")
					total += 1
				else:
					assert(world.blocks[below].type == "wood")
	assert(total > 300, "Trees should remain common in generated worlds")
	world.blocks.clear()
	for x in world.WORLD_WIDTH:
		world.terrain_surface_y[x] = 32
	world.blocks[Vector2i(25, 32)] = {"type": "grass"}
	world.blocks[Vector2i(25, 29)] = {"type": "water"}
	var before: Dictionary = world.blocks.duplicate(true)
	assert(not generator.create_tree(25))
	assert(world.blocks == before, "Failed placement must leave the ground untouched")
	generator.free()
	world.free()
	print("[natural-trees] PASS: %d supported trees, deterministic generation, clear spawn, atomic placement" % total)
	quit()
