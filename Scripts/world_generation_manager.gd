extends Node

var world = null
var generation_rng := RandomNumberGenerator.new()
var generation_seed := 1

const CAVE_BACKGROUND_BLOCK_TYPE = "cave_background"

# Tunable generation values.
# Terrain vertical offset keeps generated worlds above the default surface.
# In Godot grid coordinates, smaller Y means visually higher.
const TERRAIN_SURFACE_VERTICAL_OFFSET = -8

# Slightly wider terrain range so hills can be taller without looking jagged.
const TERRAIN_EXTRA_HILL_RANGE = 3
const HILL_AMPLITUDE_MAJOR = 4.8
const HILL_AMPLITUDE_MINOR = 2.4
const HILL_AMPLITUDE_DETAIL = 1.2

# Surface decoration distribution.
const SURFACE_DECORATION_CHANCE = 0.62
const SURFACE_DECORATION_GRASS_CHANCE = 0.22
const SURFACE_DECORATION_ROSE_CHANCE = 0.30
const SURFACE_DECORATION_TULIP_CHANCE = 0.30
const SURFACE_DECORATION_SPACING_GAP_MAX = 0.84
const SURFACE_DECORATION_NOISE_SCALE_X = 0.17
const SURFACE_DECORATION_NOISE_SCALE_Y = 2.9

# Tree tuning.
const TREE_MIN_HEIGHT = 5
const TREE_MAX_HEIGHT = 8
const TREE_BRANCH_CHANCE = 0.18
const TREE_VINE_CHANCE = 0.06
const TREE_VINE_MAX_LENGTH = 4
const TREE_SPACING_FRACTION = 0.03
const TREE_SURFACE_NOISE_THRESHOLD = 0.30
const TREE_RANDOM_PLACEMENT_CHANCE = 0.45

# Ponds are carved into the dirt layer instead of replacing the grass surface.
const POND_EDGE_DEPTH = 2
const POND_CENTER_DEPTH = 3
const POND_WIDTH_MIN = 5
const POND_WIDTH_MAX = 11
const POND_COUNT_MIN = 2
const POND_COUNT_MAX = 3
const POND_ATTEMPT_LIMIT = 90

# Bottom structure:
# - Bedrock is still the bottom.
# - Only the 4 breakable rows above bedrock get the lava/stone-heavy mix.
# - Everything above that is mostly dirt, with sand/stone sprinkled in.
const BOTTOM_LAVA_STONE_HEIGHT = 4
const CAVE_BOTTOM_SOLID_PADDING = 7

# Cave tuning. These create actual hollow spaces/tunnels while keeping the
# surface and bottom lava/stone layer solid/readable.
const CAVE_MIN_DEPTH = 8
const SHALLOW_CAVE_START_DEPTH = 10
const DEEP_CAVE_START_DEPTH = 18
const CAVE_TUNNEL_NOISE_SEED_A = 1203
const CAVE_TUNNEL_NOISE_SEED_B = 2281
const CAVE_TUNNEL_NOISE_SEED_C = 3359


func setup(world_ref):
	world = world_ref


func generate_world():
	if world == null:
		return

	prepare_generation_rng()
	generate_terrain_surface()

	for x in range(world.WORLD_WIDTH):
		var surface_y = get_surface_y_at_x(x)

		for y in range(surface_y, world.WORLD_HEIGHT):
			var grid_pos = Vector2i(x, y)
			var block_type = get_generated_block_type(x, y, surface_y)

			if block_type != "air":
				world.create_block(grid_pos, block_type)

			if should_place_cave_background(block_type, x, y, surface_y):
				create_generated_background_block(grid_pos)

	generate_natural_ponds()
	generate_surface_decorations()
	generate_trees()
	world.ensure_entrance_gate()


func prepare_generation_rng():
	generation_seed = get_world_generation_seed()
	generation_rng.seed = generation_seed


func get_world_generation_seed() -> int:
	if world == null:
		return 1

	var world_name = str(world.current_world_name).strip_edges().to_upper()

	if world_name == "":
		world_name = str(world.DEFAULT_WORLD_NAME).to_upper()

	var value = 173
	var source = "PIXELMANIA_WORLD_" + world_name

	for i in range(source.length()):
		value = int((value * 131 + source.unicode_at(i)) % 2147483647)

	return max(1, value)


func get_generation_surface_base_y() -> int:
	if world == null:
		return 0

	return clamp(
		world.SURFACE_Y + TERRAIN_SURFACE_VERTICAL_OFFSET,
		get_generation_min_surface_y(),
		get_generation_max_surface_y()
	)


func get_generation_min_surface_y() -> int:
	if world == null:
		return 0

	return max(3, world.TERRAIN_MIN_SURFACE_Y + TERRAIN_SURFACE_VERTICAL_OFFSET - TERRAIN_EXTRA_HILL_RANGE)


func get_generation_max_surface_y() -> int:
	if world == null:
		return 0

	return max(get_generation_min_surface_y(), world.TERRAIN_MAX_SURFACE_Y + TERRAIN_SURFACE_VERTICAL_OFFSET + TERRAIN_EXTRA_HILL_RANGE)


func generate_terrain_surface():
	if world == null:
		return

	world.terrain_surface_y.clear()

	var base_surface_y = get_generation_surface_base_y()
	var min_surface_y = get_generation_min_surface_y()
	var max_surface_y = get_generation_max_surface_y()

	# Per-world deterministic phase keeps every client in the same world on the
	# same base terrain before server edits are applied.
	var wave_seed_a = generation_rng.randf() * TAU
	var wave_seed_b = generation_rng.randf() * TAU
	var wave_seed_c = generation_rng.randf() * TAU
	var drift = 0
	var drift_timer = 0

	for x in range(world.WORLD_WIDTH):
		# Keep the spawn area flat and safe.
		if abs(x - world.SPAWN_GRID_X) <= world.SPAWN_FLAT_RADIUS:
			world.terrain_surface_y[x] = base_surface_y
			continue

		drift_timer -= 1

		if drift_timer <= 0:
			drift_timer = generation_rng.randi_range(4, 8)
			drift += generation_rng.randi_range(-1, 1)
			drift = clamp(drift, -2, 2)

		var wave_1 = sin(float(x) * 0.070 + wave_seed_a) * HILL_AMPLITUDE_MAJOR
		var wave_2 = sin(float(x) * 0.145 + wave_seed_b) * HILL_AMPLITUDE_MINOR
		var wave_3 = sin(float(x) * 0.310 + wave_seed_c) * HILL_AMPLITUDE_DETAIL
		var target_y = int(round(float(base_surface_y) + wave_1 + wave_2 + wave_3 + float(drift)))

		world.terrain_surface_y[x] = clamp(target_y, min_surface_y, max_surface_y)

	# Smooth sharp cliffs so hills are slightly larger but still walkable-looking.
	for smoothing_pass in range(3):
		for x in range(1, world.WORLD_WIDTH - 1):
			if abs(x - world.SPAWN_GRID_X) <= world.SPAWN_FLAT_RADIUS:
				world.terrain_surface_y[x] = base_surface_y
				continue

			var left_y = int(world.terrain_surface_y[x - 1])
			var current = int(world.terrain_surface_y[x])
			var right_y = int(world.terrain_surface_y[x + 1])

			if current < left_y - 1:
				current = left_y - 1

			if current > left_y + 1:
				current = left_y + 1

			if current < right_y - 1:
				current = right_y - 1

			if current > right_y + 1:
				current = right_y + 1

			world.terrain_surface_y[x] = clamp(current, min_surface_y, max_surface_y)


func get_surface_y_at_x(x: int) -> int:
	if world == null:
		return 0

	var safe_x = clamp(x, 0, world.WORLD_WIDTH - 1)

	if world.terrain_surface_y.has(safe_x):
		return int(world.terrain_surface_y[safe_x])

	# If this is a loaded save without terrain_surface_y, find the first solid block.
	for y in range(0, world.WORLD_HEIGHT):
		var grid_pos = Vector2i(safe_x, y)

		if world.blocks.has(grid_pos):
			return y

	return get_generation_surface_base_y()


func is_spawn_safe_column(x: int) -> bool:
	if world == null:
		return false

	return abs(x - world.SPAWN_GRID_X) <= world.SPAWN_FLAT_RADIUS


func get_depth_above_bedrock(y: int) -> int:
	if world == null:
		return 999999

	# 1 means the first breakable tile directly above bedrock.
	return world.BEDROCK_START_Y - y


func is_bottom_lava_stone_layer(y: int) -> bool:
	var depth_above_bedrock = get_depth_above_bedrock(y)
	return depth_above_bedrock >= 1 and depth_above_bedrock <= BOTTOM_LAVA_STONE_HEIGHT


func cell_noise(x: int, y: int, salt: int = 0) -> float:
	var seed_offset = float(generation_seed % 1000003) * 0.0001
	var value = sin(float(x) * 12.9898 + float(y) * 78.233 + float(salt) * 37.719 + seed_offset) * 43758.5453123
	return value - floor(value)


func pick_weighted_block(x: int, y: int, options: Array) -> String:
	var total_weight = 0.0

	for option in options:
		total_weight += float(option.get("weight", 0.0))

	if total_weight <= 0.0:
		return "dirt"

	var roll = cell_noise(x, y, 9047) * total_weight

	for option in options:
		roll -= float(option.get("weight", 0.0))

		if roll <= 0.0:
			return str(option.get("type", "dirt"))

	return str(options[options.size() - 1].get("type", "dirt"))


func should_place_cave_background(block_type: String, x: int, y: int, surface_y: int) -> bool:
	if world == null:
		return false

	if y <= surface_y:
		return false

	if y >= world.BEDROCK_START_Y:
		return false

	if block_type == "water":
		return false

	match block_type:
		"dirt", "sand", "stone", "lava":
			return true
		"air":
			return should_place_cave_background_for_air(x, y, surface_y)

	return false


func should_place_cave_background_for_air(x: int, y: int, surface_y: int) -> bool:
	if world == null:
		return false

	var depth = y - surface_y

	if depth < CAVE_MIN_DEPTH:
		return false

	if is_spawn_safe_column(x):
		return false

	if y >= world.BEDROCK_START_Y - CAVE_BOTTOM_SOLID_PADDING:
		return false

	if is_bottom_lava_stone_layer(y):
		return false

	# Only place background in carved cave pockets, not open sky.
	return should_generate_cave_pocket(x, y, surface_y)


func create_generated_background_block(grid_pos: Vector2i):
	if world == null:
		return

	if world.has_method("create_background_block"):
		world.create_background_block(grid_pos, CAVE_BACKGROUND_BLOCK_TYPE)
		return

	var manager = world.get("block_manager")

	if manager != null and manager.has_method("create_background_block"):
		manager.create_background_block(grid_pos, CAVE_BACKGROUND_BLOCK_TYPE)


func should_generate_cave_pocket(x: int, y: int, surface_y: int) -> bool:
	if world == null:
		return false

	var depth = y - surface_y

	# Keep the first few blocks under grass solid so the surface is stable.
	if depth < CAVE_MIN_DEPTH:
		return false

	if is_spawn_safe_column(x):
		return false

	# Keep the bottom lava/stone/bedrock area readable and mostly solid.
	if y >= world.BEDROCK_START_Y - CAVE_BOTTOM_SOLID_PADDING:
		return false

	if is_bottom_lava_stone_layer(y):
		return false

	var shallow_axis = get_shallow_cave_axis(x, surface_y)
	var deep_axis = get_deep_cave_axis(x, surface_y)

	# Main tunnels are smooth paths rather than individual noise spikes.
	if depth >= SHALLOW_CAVE_START_DEPTH:
		var axis_distance = abs(y - shallow_axis)
		var axis_width = 1.2 + (cell_noise(x, surface_y, CAVE_TUNNEL_NOISE_SEED_A) * 1.35)

		if axis_distance <= axis_width and cell_noise(x, y, CAVE_TUNNEL_NOISE_SEED_B) < 0.90:
			return true

		# Slightly rough side pockets around the tunnel.
		if axis_distance <= axis_width + 1 and cell_noise(x, y, CAVE_TUNNEL_NOISE_SEED_C) < 0.22:
			return true

	# Deep tunnel runs are less frequent and more segmented.
	if depth >= DEEP_CAVE_START_DEPTH:
		var deep_distance = abs(y - deep_axis)
		var deep_axis_width = 0.9 + (cell_noise(x, surface_y, CAVE_TUNNEL_NOISE_SEED_C) * 1.1)

		if cell_noise(surface_y, y, CAVE_TUNNEL_NOISE_SEED_B) > 0.72:
			if deep_distance <= deep_axis_width and cell_noise(x, y, 401) < 0.85:
				return true

			if deep_distance <= deep_axis_width + 1 and cell_noise(x, y, 402) < 0.18:
				return true

	# Soft pocket clusters create irregular cave rooms.
	var pocket_ribbon = cell_noise(x * 3, y * 3, 601)
	var pocket_roll = cell_noise(x, y, 602)

	if depth >= 12 and pocket_ribbon > 0.68 and pocket_roll < 0.28:
		return true

	# Very rare high-level single chip is okay, but avoid random surface noise.
	if depth >= 16 and cell_noise(x, y, 603) < 0.018:
		return true

	return false


func get_shallow_cave_axis(x: int, surface_y: int) -> int:
	if world == null:
		return surface_y

	return surface_y + 13 + int(round((cell_noise(x, surface_y, 801) - 0.5) * 5.6 + (cell_noise(surface_y, x, 802) - 0.5) * 4.0))


func get_deep_cave_axis(x: int, surface_y: int) -> int:
	if world == null:
		return surface_y

	return surface_y + 23 + int(round((cell_noise(x, surface_y, 803) - 0.5) * 7.6 + (cell_noise(surface_y, x, 804) - 0.5) * 3.6))


func get_normal_underground_block_type(x: int, y: int, depth: int) -> String:
	# Just below surface: mostly dirt.
	if depth <= 5:
		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 89.0},
			{"type": "stone", "weight": 7.0},
			{"type": "sand", "weight": 4.0}
		])

	# Mid shallow: still mostly dirt with limited stone and sand.
	if depth <= 16:
		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 80.0},
			{"type": "stone", "weight": 13.0},
			{"type": "sand", "weight": 7.0}
		])

	# Mid bands add more stone and depth variation.
	if depth <= 24:
		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 68.0},
			{"type": "stone", "weight": 24.0},
			{"type": "sand", "weight": 8.0}
		])

	# Deeper underground band.
	if depth <= 34:
		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 55.0},
			{"type": "stone", "weight": 37.0},
			{"type": "sand", "weight": 8.0}
		])

	# Deep underground: much more stone for structure.
	return pick_weighted_block(x, y, [
		{"type": "dirt", "weight": 40.0},
		{"type": "stone", "weight": 53.0},
		{"type": "sand", "weight": 8.0}
	])


func get_surface_block_type(x: int, y: int, surface_y: int) -> String:
	# Keep spawn surface stable and boring to avoid stranding players at start.
	if is_spawn_safe_column(x):
		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 86.0},
			{"type": "sand", "weight": 7.0},
			{"type": "stone", "weight": 7.0}
		])

	var span = max(1, get_generation_max_surface_y() - get_generation_min_surface_y())
	var flatness = clamp(float(surface_y - get_generation_min_surface_y()) / float(span), 0.0, 1.0)
	var soil_noise = cell_noise(x, surface_y, 901)
	var rock_noise = cell_noise(surface_y, x, 902)

	if flatness > 0.73 and soil_noise < 0.20:
		return "sand"

	if rock_noise > 0.90:
		return pick_weighted_block(x, y, [
			{"type": "stone", "weight": 56.0},
			{"type": "dirt", "weight": 34.0},
			{"type": "sand", "weight": 10.0}
		])

	return pick_weighted_block(x, y, [
		{"type": "dirt", "weight": 84.0},
		{"type": "sand", "weight": 9.0},
		{"type": "stone", "weight": 7.0}
	])


func get_bottom_lava_stone_block_type(x: int, y: int) -> String:
	# Only 3-4 rows above bedrock should have this stronger lava/stone feel.
	return pick_weighted_block(x, y, [
		{"type": "stone", "weight": 62.0},
		{"type": "lava", "weight": 28.0},
		{"type": "dirt", "weight": 10.0}
	])


func get_generated_block_type(x: int, y: int, surface_y: int) -> String:
	if world == null:
		return "air"

	# Bottom rows are unbreakable bedrock.
	if y >= world.BEDROCK_START_Y:
		return "bedrock"

	# Above terrain is air.
	if y < surface_y:
		return "air"

	# Main surface material. Decoration comes later as a separate pass.
	if y == surface_y:
		return get_surface_block_type(x, y, surface_y)

	var depth = y - surface_y

	# Only the few rows directly above bedrock use the lava/stone mix.
	if is_bottom_lava_stone_layer(y):
		return get_bottom_lava_stone_block_type(x, y)

	# Keep the spawn area clean: no lava/caves directly under spawn.
	if is_spawn_safe_column(x):
		if depth <= 9:
			return pick_weighted_block(x, y, [
				{"type": "dirt", "weight": 88.0},
				{"type": "stone", "weight": 9.0},
				{"type": "sand", "weight": 3.0}
			])

		return pick_weighted_block(x, y, [
			{"type": "dirt", "weight": 80.0},
			{"type": "stone", "weight": 15.0},
			{"type": "sand", "weight": 5.0}
		])

	# Underground empty spaces. Cave background is only placed on supporting terrain.
	if should_generate_cave_pocket(x, y, surface_y):
		return "air"

	return get_normal_underground_block_type(x, y, depth)


func generate_natural_ponds():
	if world == null:
		return

	var pond_count = generation_rng.randi_range(POND_COUNT_MIN, POND_COUNT_MAX)
	var created = 0
	var used_centers = []

	for attempt in range(POND_ATTEMPT_LIMIT):
		if created >= pond_count:
			return

		var width = generation_rng.randi_range(POND_WIDTH_MIN, POND_WIDTH_MAX)

		if width % 2 == 0:
			width += 1

		var center_x = generation_rng.randi_range(8, world.WORLD_WIDTH - 9)
		var min_spacing = max(world.WATER_MIN_POOL_SPACING, width)

		if is_spawn_safe_column(center_x):
			continue

		var too_close = false

		for used_x in used_centers:
			if abs(int(used_x) - center_x) < min_spacing:
				too_close = true
				break

		if too_close:
			continue

		if can_generate_natural_pond(center_x, width):
			create_natural_pond(center_x, width)
			used_centers.append(center_x)
			created += 1


func can_generate_natural_pond(center_x: int, width: int) -> bool:
	if world == null:
		return false

	var half = int(floor(float(width) * 0.5))
	var min_surface = 999999
	var max_surface = -999999

	for x in range(center_x - half, center_x + half + 1):
		if x <= 2 or x >= world.WORLD_WIDTH - 3:
			return false

		if is_spawn_safe_column(x):
			return false

		var surface_y = get_surface_y_at_x(x)
		min_surface = min(min_surface, surface_y)
		max_surface = max(max_surface, surface_y)

		var surface_pos = Vector2i(x, surface_y)
		var dirt_pos = Vector2i(x, surface_y + 1)

		if not world.blocks.has(surface_pos):
			return false

		var top_block_type = str(world.blocks[surface_pos].get("type", ""))
		if not (top_block_type in ["dirt", "sand", "stone", "grass"]):
			return false

		if not world.blocks.has(dirt_pos):
			return false

		var below_block_type = str(world.blocks[dirt_pos].get("type", ""))
		if not (below_block_type in ["dirt", "sand", "stone"]):
			return false

	# Only make ponds on mostly flat ground, not on random cliffs.
	if max_surface - min_surface > 1:
		return false

	return true


func create_natural_pond(center_x: int, width: int):
	if world == null:
		return

	var half = int(floor(float(width) * 0.5))
	var start_x = center_x - half
	var end_x = center_x + half

	var surface_y_for_pond = -999999
	var pond_profile_noise = generation_rng.randi()

	for x in range(start_x, end_x + 1):
		surface_y_for_pond = max(surface_y_for_pond, get_surface_y_at_x(x))

	# Put the water surface one tile below the grass surface so water replaces dirt,
	# not the top block. This makes ponds look carved into natural banks.
	var water_surface_y = surface_y_for_pond + 1

	# Dirt banks around the pond. The water should touch dirt, not grass blocks.
	for x in range(start_x, end_x + 1):
		var distance_from_center = abs(x - center_x)
		var base_depth = POND_CENTER_DEPTH
		var edge_curve = int(floor(POND_EDGE_DEPTH + sin(float(distance_from_center) * 0.65 + float(pond_profile_noise) * 0.001)))
		var carve_depth = clamp(base_depth + edge_curve, POND_EDGE_DEPTH, POND_CENTER_DEPTH + 2)

		for y in range(get_surface_y_at_x(x), water_surface_y + POND_CENTER_DEPTH + 2):
			var pos = Vector2i(x, y)
			var local_depth = y - water_surface_y

			# Keep outside edge banks solid dirt.
			if x == start_x or x == end_x:
				world.replace_block_without_drop(pos, "dirt")
				clear_generated_background_block(pos)
				continue

			# Clear the old grass/top layer above the water.
			if y < water_surface_y:
				world.remove_block_without_drop(pos)
				clear_generated_background_block(pos)
				continue

			var local_variation = 0.0
			if abs(distance_from_center) > 1:
				local_variation = (0.22 - cell_noise(x, distance_from_center, pond_profile_noise % 1000)) * 1.4

			var pond_depth = clamp(carve_depth + int(round(local_variation)), POND_EDGE_DEPTH, POND_CENTER_DEPTH + 2)

			if local_depth < pond_depth:
				world.replace_block_without_drop(pos, "water")
				clear_generated_background_block(pos)
			else:
				world.replace_block_without_drop(pos, "dirt")
				clear_generated_background_block(pos)

	# Extra dirt lip directly beside the open water so it never looks like water is
	# spawning inside grass blocks.
	world.replace_block_without_drop(Vector2i(start_x + 1, water_surface_y), "dirt")
	world.replace_block_without_drop(Vector2i(end_x - 1, water_surface_y), "dirt")
	clear_generated_background_block(Vector2i(start_x + 1, water_surface_y))
	clear_generated_background_block(Vector2i(end_x - 1, water_surface_y))


func clear_generated_background_block(grid_pos: Vector2i):
	if world == null:
		return

	var manager = world.get("block_manager")

	if manager != null and manager.has_method("remove_background_block_without_drop"):
		manager.remove_background_block_without_drop(grid_pos)


func generate_trees():
	if world == null:
		return

	var last_tree_x = -999

	for x in range(4, world.WORLD_WIDTH - 4):
		if is_spawn_safe_column(x):
			continue
		
		var minimum_tree_spacing = max(world.TREE_MIN_SPACING - 3, 3)

		if x - last_tree_x < minimum_tree_spacing:
			continue

		var terrain_roll = cell_noise(x, get_surface_y_at_x(x), 7001)
		if terrain_roll > TREE_SURFACE_NOISE_THRESHOLD:
			continue

		var density_roll = cell_noise(x * 2, get_surface_y_at_x(x), 7002)

		if density_roll < TREE_SPACING_FRACTION:
			continue

		if generation_rng.randf() < TREE_RANDOM_PLACEMENT_CHANCE:
			create_tree(x)
			last_tree_x = x


func generate_surface_decorations():
	if world == null:
		return

	for x in range(2, world.WORLD_WIDTH - 2):
		var surface_y = get_surface_y_at_x(x)
		var surface_pos = Vector2i(x, surface_y)

		if not world.blocks.has(surface_pos):
			continue

		var surface_type = str(world.blocks[surface_pos].get("type", ""))

		# Only ground-facing blocks can host top-side planting and grass cover.
		if not (surface_type in ["dirt", "sand", "stone"]):
			continue

		# Keep a natural amount of empty space; not every tile should be filled.
		var occupancy_roll = cell_noise(x, surface_y, 7201)
		var spacing_roll = cell_noise(int(x * SURFACE_DECORATION_NOISE_SCALE_X), int(float(surface_y) * SURFACE_DECORATION_NOISE_SCALE_Y), 7202)
		if occupancy_roll > SURFACE_DECORATION_CHANCE:
			continue

		if spacing_roll > SURFACE_DECORATION_SPACING_GAP_MAX:
			continue

		var decoration_type = get_surface_decoration_type(x, surface_y)

		if decoration_type == "":
			continue

		world.replace_block_without_drop(surface_pos, decoration_type)


func get_surface_decoration_type(x: int, surface_y: int) -> String:
	var occupancy_roll = cell_noise(x, surface_y, 7200)

	if occupancy_roll > SURFACE_DECORATION_CHANCE:
		return ""

	var selection_roll = cell_noise(x, surface_y + 1, 7201)
	var total = SURFACE_DECORATION_GRASS_CHANCE + SURFACE_DECORATION_ROSE_CHANCE + SURFACE_DECORATION_TULIP_CHANCE

	if total <= 0.0:
		return ""

	var normalized = selection_roll / total

	if normalized < (SURFACE_DECORATION_TULIP_CHANCE / total):
		return "tulip"

	if normalized < ((SURFACE_DECORATION_TULIP_CHANCE + SURFACE_DECORATION_ROSE_CHANCE) / total):
		return "rose"

	return "grass"


func create_tree(x: int):
	if world == null:
		return

	if x <= 1 or x >= world.WORLD_WIDTH - 2:
		return

	var surface_y = get_surface_y_at_x(x)
	var base_y = surface_y - 1

	# Trees now spawn on a dirt block, not a grass block.
	# Since the natural surface is grass, turn the tree's center footing into dirt
	# before placing the trunk.
	var ground_pos = Vector2i(x, surface_y)
	if not world.blocks.has(ground_pos):
		return

	var ground_type = str(world.blocks[ground_pos].get("type", ""))
	if not (ground_type in ["grass", "dirt", "sand", "stone", "rose", "tulip"]):
		return

	# Skip very steep spots.
	if abs(get_surface_y_at_x(x - 1) - surface_y) > 1:
		return

	if abs(get_surface_y_at_x(x + 1) - surface_y) > 1:
		return

	world.replace_block_without_drop(ground_pos, "dirt")

	var trunk_height = generation_rng.randi_range(TREE_MIN_HEIGHT, TREE_MAX_HEIGHT)
	var trunk_tilt = 0
	var leaf_positions = []

	if cell_noise(x, surface_y, 7101) > 0.9:
		var tilt_noise = cell_noise(x + 10, surface_y, 7102)

		if tilt_noise < 0.33:
			trunk_tilt = -1
		elif tilt_noise > 0.66:
			trunk_tilt = 1

	var trunk_positions = []

	for i in range(trunk_height):
		var trunk_pos = Vector2i(x + trunk_tilt * int(floor(float(i) / 2.0)), base_y - i)
		world.create_block(trunk_pos, "wood")
		trunk_positions.append(trunk_pos)

	var leaf_core_y = base_y - trunk_height
	var leaf_spread_x = 2

	if trunk_height >= 6:
		leaf_spread_x = 3

	if trunk_height >= 7:
		leaf_spread_x = 4

	# Fuller canopy with slight top/side irregularity.
	# Fuller canopy with a taller, denser top and natural irregular edges.
	for dy in range(-4, 2):
		var row_span = leaf_spread_x

		if dy >= -1:
			row_span = max(2, leaf_spread_x - 1)
		elif dy <= -3:
			row_span = max(3, leaf_spread_x + 1)
		else:
			row_span = leaf_spread_x + 1

		row_span = int(row_span + round((cell_noise(x, leaf_core_y + dy, 7401) - 0.5) * 1.2))
		row_span = clamp(row_span, 2, leaf_spread_x + 2)

		for dx in range(-row_span, row_span + 1):
			var leaf_pos = Vector2i(trunk_positions[trunk_positions.size() - 1].x + dx, leaf_core_y + dy)
			var dist = abs(dx) + abs(dy)

			if dist > 8:
				continue

			var leaf_noise = cell_noise(leaf_pos.x, leaf_pos.y, 7400)
			var is_edge = abs(dx) == row_span or dist >= 5

			# Keep the top dense and full, but carve natural-looking edge breaks.
			if dy < -1 and dist <= 2 and leaf_noise < 0.03:
				continue
			elif is_edge and leaf_noise < 0.28:
				continue
			elif dist > 4 and leaf_noise < 0.16:
				continue
			elif dist > 5 and leaf_noise < 0.35:
				continue

			world.create_block(leaf_pos, "leaf")
			leaf_positions.append(leaf_pos)

	# Keep branches straight up for a clean vertical form.
	if generation_rng.randf() < TREE_BRANCH_CHANCE:
		var branch_start_y = leaf_core_y + 2 + generation_rng.randi_range(0, 1)
		var branch_length = generation_rng.randi_range(1, 2)

		for i in range(branch_length):
			var branch_pos = Vector2i(trunk_positions[trunk_positions.size() - 1].x, branch_start_y - i)
			if branch_pos.y < 0 or world.blocks.has(branch_pos):
				break

			world.create_block(branch_pos, "wood")

	create_tree_vines(leaf_positions)


func create_tree_vines(vine_anchors: Array):
	if world == null:
		return

	if vine_anchors.size() <= 0:
		return

	var max_vines = 4
	var vines_created = 0

	for i in range(vine_anchors.size()):
		if vines_created >= max_vines:
			return

		var anchor = vine_anchors[i]

		if not world.blocks.has(anchor):
			continue

		var anchor_type = str(world.blocks[anchor].get("type", ""))
		if anchor_type != "leaf":
			continue

		if not is_leaf_edge_anchor(anchor, vine_anchors):
			continue

		var vine_roll = cell_noise(anchor.x, anchor.y, 8300)
		vine_roll += 0.05 * float(i % 3)

		if vine_roll > TREE_VINE_CHANCE:
			continue

		var start_pos = Vector2i(anchor.x, anchor.y + 1)

		if world.blocks.has(start_pos):
			continue

		var drop_count = 0
		while drop_count < TREE_VINE_MAX_LENGTH:
			var pos = Vector2i(start_pos.x, start_pos.y + drop_count)

			if pos.y >= world.BEDROCK_START_Y:
				break

			var existing = world.blocks.get(pos, null)
			if existing != null:
				break

			world.create_block(pos, "vines")
			drop_count += 1
			vines_created += 1


func is_leaf_edge_anchor(anchor: Vector2i, leaf_positions: Array) -> bool:
	if leaf_positions == null:
		return false

	var has_left = false
	var has_right = false
	var has_up = false
	var has_down = false

	for i in range(leaf_positions.size()):
		var pos = leaf_positions[i]

		if pos == Vector2i(anchor.x - 1, anchor.y):
			has_left = true
		if pos == Vector2i(anchor.x + 1, anchor.y):
			has_right = true
		if pos == Vector2i(anchor.x, anchor.y + 1):
			has_up = true
		if pos == Vector2i(anchor.x, anchor.y - 1):
			has_down = true

	return not (has_left and has_right and has_up and has_down)
