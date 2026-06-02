extends Node

var world = null

var item_database = {}
var splice_recipes = {}
var seed_textures = {}
var seed_tree_textures = {}
var block_textures = {}

var block_size = 32
var invalid_grid_pos = Vector2i(999999, 999999)
var seed_grow_time = 8.0
var mature_seed_extra_drop_chance = 0.65
var mutant_tree_mature_texture = null

var planted_seeds = {}

const INVENTORY_UI_STYLE_PATH = "res://Assets/ui/inventory/"
const TREE_TYPE_BADGE_SIZE = 10.0
const TREE_TYPE_BADGE_ICON_SIZE = 7.0
const TREE_TYPE_BADGE_POSITION_X = 6.0
const TREE_TYPE_BADGE_STYLE_VERSION = 2


func setup(
	parent_world,
	passed_item_database: Dictionary,
	passed_splice_recipes: Dictionary,
	passed_seed_textures: Dictionary,
	passed_seed_tree_textures: Dictionary,
	passed_block_textures: Dictionary,
	passed_block_size: int,
	passed_invalid_grid_pos: Vector2i,
	passed_seed_grow_time: float,
	passed_mature_seed_extra_drop_chance: float
):
	world = parent_world
	item_database = passed_item_database
	splice_recipes = passed_splice_recipes
	seed_textures = passed_seed_textures
	seed_tree_textures = passed_seed_tree_textures
	block_textures = passed_block_textures
	block_size = passed_block_size
	invalid_grid_pos = passed_invalid_grid_pos
	seed_grow_time = passed_seed_grow_time
	mature_seed_extra_drop_chance = passed_mature_seed_extra_drop_chance
	if ResourceLoader.exists("res://Assets/seed_tree_sprites/mutant_tree_mature.png"):
		mutant_tree_mature_texture = load("res://Assets/seed_tree_sprites/mutant_tree_mature.png")


func has_seed_at(grid_pos: Vector2i) -> bool:
	return planted_seeds.has(grid_pos)


func get_seed_growth_status_text_for_player(player_grid_pos: Vector2i, player_world_pos: Vector2) -> String:
	var seed_grid = get_seed_grid_overlapping_player(player_grid_pos, player_world_pos)
	if seed_grid == invalid_grid_pos:
		return ""

	return get_seed_growth_status_text(seed_grid)


func get_seed_grid_overlapping_player(player_grid_pos: Vector2i, player_world_pos: Vector2) -> Vector2i:
	if planted_seeds.has(player_grid_pos):
		return player_grid_pos

	var best_grid = invalid_grid_pos
	var best_distance = 100000000.0

	for grid_pos in planted_seeds.keys():
		var base_pos = Vector2(grid_pos.x * block_size, grid_pos.y * block_size)
		var tree_overlap_rect = Rect2(
			base_pos + Vector2(-24, -54),
			Vector2(48, 72)
		)

		if tree_overlap_rect.has_point(player_world_pos):
			var distance = player_world_pos.distance_squared_to(base_pos)
			if distance < best_distance:
				best_distance = distance
				best_grid = grid_pos

	return best_grid


func get_seed_growth_status_text(grid_pos: Vector2i) -> String:
	if not planted_seeds.has(grid_pos):
		return ""

	var seed_data = planted_seeds[grid_pos]
	if bool(seed_data.get("mature", false)) or float(seed_data.get("grow_time", 0.0)) <= 0.0:
		return "Ready to harvest"

	return "Growth: " + format_seed_growth_time(float(seed_data.get("grow_time", 0.0)))


func format_seed_growth_time(seconds_remaining: float) -> String:
	var total_seconds = int(ceil(max(0.0, seconds_remaining)))
	if total_seconds >= 60:
		var minutes = int(total_seconds / 60)
		var seconds = total_seconds % 60
		var seconds_text = str(seconds)
		if seconds < 10:
			seconds_text = "0" + seconds_text
		return str(minutes) + "m " + seconds_text + "s"

	return str(total_seconds) + "s"


func get_clicked_planted_seed_grid(direct_grid: Vector2i, mouse_pos: Vector2) -> Vector2i:
	if planted_seeds.has(direct_grid):
		return direct_grid

	for grid_pos in planted_seeds.keys():
		var base_pos = Vector2(grid_pos.x * block_size, grid_pos.y * block_size)

		var tree_click_rect = Rect2(
			base_pos + Vector2(-24, -54),
			Vector2(48, 72)
		)

		if tree_click_rect.has_point(mouse_pos):
			return grid_pos

	return invalid_grid_pos


func try_splice_seed_tree(
	grid_pos: Vector2i,
	selected_item_type: String,
	selected_item_category: String,
	seed_inventory: Dictionary
) -> bool:
	if not planted_seeds.has(grid_pos):
		return false

	if selected_item_category != "seed":
		notify("Select a seed from the Seeds tab first.")
		return false

	if not seed_inventory.has(selected_item_type):
		return false

	if int(seed_inventory[selected_item_type]) <= 0:
		notify("You do not have that seed.")
		return false

	var seed_data = planted_seeds[grid_pos]

	if bool(seed_data.get("mature", false)):
		notify("This seed-tree is already mature. Harvest it first.")
		return false

	var first_seed = str(seed_data["seed_type"])
	var second_seed = selected_item_type
	var result_seed = get_splice_result(first_seed, second_seed)

	if result_seed == "":
		notify("These seeds cannot be spliced.")
		return false

	seed_inventory[second_seed] = int(seed_inventory[second_seed]) - 1

	planted_seeds[grid_pos]["seed_type"] = result_seed
	planted_seeds[grid_pos]["grow_time"] = seed_grow_time
	planted_seeds[grid_pos]["max_grow_time"] = seed_grow_time
	planted_seeds[grid_pos]["mature"] = false
	planted_seeds[grid_pos]["stage"] = -1

	update_seed_tree_visual(grid_pos)

	notify("Spliced into " + get_seed_display_name(result_seed) + ".")

	return true




func get_seed_display_name(seed_id: String) -> String:
	if item_database.has(seed_id):
		return str(item_database[seed_id].get("display_name", seed_id))

	return seed_id

func get_splice_result(seed_a: String, seed_b: String) -> String:
	var recipe_key = get_splice_key(seed_a, seed_b)

	if splice_recipes.has(recipe_key):
		return splice_recipes[recipe_key]

	return ""


func get_splice_key(seed_a: String, seed_b: String) -> String:
	var pair = [seed_a, seed_b]
	pair.sort()

	return str(pair[0]) + "+" + str(pair[1])


func create_planted_seed(grid_pos: Vector2i, seed_type: String, grow_time: float, max_grow_time: float = -1.0) -> bool:
	if planted_seeds.has(grid_pos):
		return false

	if max_grow_time <= 0.0:
		max_grow_time = seed_grow_time

	var seed_node = Node2D.new()
	seed_node.name = "SeedTree_" + seed_type
	seed_node.global_position = Vector2(grid_pos.x * block_size, grid_pos.y * block_size)

	if world != null:
		world.add_child(seed_node)
	else:
		add_child(seed_node)

	planted_seeds[grid_pos] = {
		"node": seed_node,
		"seed_type": seed_type,
		"grow_time": grow_time,
		"max_grow_time": max_grow_time,
		"stage": -1,
		"mature": false,
		"mutated": false
	}

	update_seed_tree_visual(grid_pos)

	return true


func update_seed_system(delta):
	for grid_pos in planted_seeds.keys().duplicate():
		if not planted_seeds.has(grid_pos):
			continue

		var seed_data = planted_seeds[grid_pos]

		if not is_instance_valid(seed_data["node"]):
			planted_seeds.erase(grid_pos)
			continue

		if bool(seed_data.get("mature", false)):
			animate_mature_seed_tree(grid_pos)
			continue

		var new_grow_time = max(0.0, float(seed_data["grow_time"]) - delta)
		planted_seeds[grid_pos]["grow_time"] = new_grow_time

		if new_grow_time <= 0.0:
			planted_seeds[grid_pos]["mature"] = true

		update_seed_tree_visual(grid_pos)
		animate_mature_seed_tree(grid_pos)


func get_seed_tree_stage(grid_pos: Vector2i) -> int:
	if not planted_seeds.has(grid_pos):
		return 0

	var seed_data = planted_seeds[grid_pos]

	if bool(seed_data.get("mature", false)):
		return 3

	var max_time = float(seed_data.get("max_grow_time", seed_grow_time))
	var current_time = float(seed_data["grow_time"])
	var progress = clamp(1.0 - (current_time / max_time), 0.0, 1.0)

	if progress < 0.30:
		return 0

	if progress < 0.65:
		return 1

	return 2


func update_seed_tree_visual(grid_pos: Vector2i):
	if not planted_seeds.has(grid_pos):
		return

	var seed_data = planted_seeds[grid_pos]
	var seed_node = seed_data["node"]

	if not is_instance_valid(seed_node):
		return

	var stage = get_seed_tree_stage(grid_pos)

	if int(seed_data["stage"]) == stage:
		if stage == 3 and tree_type_badge_needs_refresh(seed_node):
			var current_seed_type = str(seed_data["seed_type"])
			var current_block_type = seed_to_block_type(current_seed_type)
			var current_tree_texture = get_seed_tree_texture(current_block_type, stage)
			if bool(seed_data.get("mutated", false)) and mutant_tree_mature_texture != null:
				current_tree_texture = mutant_tree_mature_texture
			create_tree_type_badge(seed_node, current_block_type, current_tree_texture)
		return

	planted_seeds[grid_pos]["stage"] = stage

	for child in seed_node.get_children():
		child.queue_free()

	var seed_type = str(seed_data["seed_type"])
	var block_type = seed_to_block_type(seed_type)

	var sprite = Sprite2D.new()
	sprite.name = "TreeSprite"

	var tree_texture = get_seed_tree_texture(block_type, stage)
	if stage == 3 and bool(seed_data.get("mutated", false)) and mutant_tree_mature_texture != null:
		tree_texture = mutant_tree_mature_texture

	if tree_texture != null:
		sprite.texture = tree_texture
	else:
		print("Missing seed-tree sprite for: " + block_type + " stage " + str(stage))

	sprite.position = Vector2(0, 0)
	sprite.scale = Vector2(1.0, 1.0)
	seed_node.add_child(sprite)

	if stage == 3:
		create_tree_type_badge(seed_node, block_type, tree_texture)


func create_tree_type_badge(seed_node: Node2D, block_type: String, tree_texture):
	var badge_texture = get_tree_type_badge_texture(block_type)
	if badge_texture == null:
		return

	var badge = Node2D.new()
	badge.name = "TreeTypeBadge"
	badge.position = get_tree_type_badge_position(tree_texture)
	badge.z_index = 6
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.set_meta("style_version", TREE_TYPE_BADGE_STYLE_VERSION)
	seed_node.add_child(badge)

	var slot_texture = get_tree_type_badge_slot_texture(block_type)
	if slot_texture != null:
		var backing = Sprite2D.new()
		backing.name = "BadgeBacking"
		backing.centered = true
		backing.texture = slot_texture
		backing.scale = get_tree_type_badge_backing_scale(slot_texture)
		backing.z_index = 0
		badge.add_child(backing)
	else:
		var half_size = TREE_TYPE_BADGE_SIZE * 0.5
		var backing = Polygon2D.new()
		backing.name = "BadgeBacking"
		backing.color = Color(0.05, 0.10, 0.18, 0.88)
		backing.polygon = PackedVector2Array([
			Vector2(-half_size, -half_size),
			Vector2(half_size, -half_size),
			Vector2(half_size, half_size),
			Vector2(-half_size, half_size)
		])
		backing.z_index = 0
		badge.add_child(backing)

	var icon_shadow = Sprite2D.new()
	icon_shadow.name = "BadgeIconShadow"
	icon_shadow.centered = true
	icon_shadow.texture = badge_texture
	icon_shadow.modulate = Color(0, 0, 0, 0.45)
	icon_shadow.position = Vector2(1, 1)
	icon_shadow.scale = get_tree_type_badge_icon_scale(badge_texture)
	icon_shadow.z_index = 1
	badge.add_child(icon_shadow)

	var icon = Sprite2D.new()
	icon.name = "BadgeIcon"
	icon.centered = true
	icon.texture = badge_texture
	icon.scale = icon_shadow.scale
	icon.z_index = 2
	badge.add_child(icon)


func tree_type_badge_needs_refresh(seed_node: Node2D) -> bool:
	var badge = seed_node.get_node_or_null("TreeTypeBadge")
	if badge == null:
		return true

	if int(badge.get_meta("style_version", 0)) == TREE_TYPE_BADGE_STYLE_VERSION:
		return false

	seed_node.remove_child(badge)
	badge.queue_free()
	return true


func get_tree_type_badge_slot_texture(block_type: String):
	var slot_path = INVENTORY_UI_STYLE_PATH + get_tree_type_badge_slot_file(block_type)
	if ResourceLoader.exists(slot_path):
		return load(slot_path)

	var fallback_path = INVENTORY_UI_STYLE_PATH + "slot_normal.png"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)

	return null


func get_tree_type_badge_slot_file(block_type: String) -> String:
	var rarity = "common"
	if item_database.has(block_type):
		rarity = str(item_database[block_type].get("rarity", "common"))

	match rarity:
		"rare":
			return "slot_rare.png"
		"epic":
			return "slot_epic.png"
		"legendary":
			return "slot_legendary.png"
		_:
			return "slot_normal.png"


func get_tree_type_badge_backing_scale(slot_texture) -> Vector2:
	var longest_edge = max(float(slot_texture.get_width()), float(slot_texture.get_height()))
	if longest_edge <= 0.0:
		return Vector2.ONE

	var scale_amount = TREE_TYPE_BADGE_SIZE / longest_edge
	return Vector2(scale_amount, scale_amount)


func get_tree_type_badge_texture(block_type: String):
	if world != null and world.has_method("get_item_texture"):
		var item_texture = world.get_item_texture(block_type, "block")
		if item_texture != null:
			return item_texture

	if block_textures.has(block_type):
		return block_textures[block_type]

	return null


func get_tree_type_badge_icon_scale(badge_texture) -> Vector2:
	var longest_edge = max(float(badge_texture.get_width()), float(badge_texture.get_height()))
	if longest_edge <= 0.0:
		return Vector2.ONE

	var scale_amount = TREE_TYPE_BADGE_ICON_SIZE / longest_edge
	return Vector2(scale_amount, scale_amount)


func get_tree_type_badge_position(tree_texture) -> Vector2:
	if tree_texture == null:
		return Vector2(TREE_TYPE_BADGE_POSITION_X, -6.0)

	var tree_height = float(tree_texture.get_height())
	var badge_y = -clamp(tree_height * 0.18, 6.0, 12.0)

	return Vector2(TREE_TYPE_BADGE_POSITION_X, badge_y)


func get_seed_tree_texture(block_type: String, stage: int):
	if not seed_tree_textures.has(block_type):
		return null

	var textures = seed_tree_textures[block_type]

	if stage >= 0 and stage < textures.size():
		if textures[stage] != null:
			return textures[stage]

	if textures.size() >= 3 and textures[2] != null:
		return textures[2]

	return null


func animate_mature_seed_tree(grid_pos: Vector2i):
	if not planted_seeds.has(grid_pos):
		return

	var seed_data = planted_seeds[grid_pos]

	if not bool(seed_data.get("mature", false)):
		return

	var seed_node = seed_data["node"]

	if not is_instance_valid(seed_node):
		return

	seed_node.global_position = Vector2(
		grid_pos.x * block_size,
		grid_pos.y * block_size
	)

	var sprite = seed_node.get_node_or_null("TreeSprite")
	var badge = seed_node.get_node_or_null("TreeTypeBadge")

	if sprite != null:
		var badge_base_position = get_tree_type_badge_position(sprite.texture)

		if not bool(seed_data.get("mutated", false)):
			sprite.position = Vector2.ZERO
			if badge != null:
				badge.position = badge_base_position
			return

		var bob = sin(Time.get_ticks_msec() / 260.0) * 1.2
		sprite.position = Vector2(0, bob)
		if badge != null:
			badge.position = badge_base_position + Vector2(0, bob)


func roll_mutated_tree_drop() -> Dictionary:
	var roll = randf()
	if roll < 0.80:
		return {
			"item_id": "glowing_dirt",
			"amount": randi_range(1, 5),
			"is_seed": false,
			"offset": Vector2(0, -16)
		}
	if roll < 0.90:
		return {
			"item_id": "sakura_sword",
			"amount": 1,
			"is_seed": false,
			"offset": Vector2(0, -16)
		}
	return {
		"item_id": "pulu_pulu",
		"amount": 1,
		"is_seed": false,
		"offset": Vector2(0, -16)
	}


func harvest_planted_seed(grid_pos: Vector2i):
	if not planted_seeds.has(grid_pos):
		return

	var seed_data = planted_seeds[grid_pos]
	var seed_type = str(seed_data["seed_type"])
	var block_type = seed_to_block_type(seed_type)
	var seed_node = seed_data["node"]
	var drop_position = Vector2(grid_pos.x * block_size, grid_pos.y * block_size)

	if is_instance_valid(seed_node):
		seed_node.queue_free()

	planted_seeds.erase(grid_pos)

	if world == null:
		return

	if bool(seed_data.get("mature", false)):
		if bool(seed_data.get("mutated", false)):
			if world.has_method("spawn_item_drop"):
				var mutated_drop = roll_mutated_tree_drop()
				var amount = int(mutated_drop.get("amount", 1))
				for i in range(max(1, amount)):
					world.spawn_item_drop(
						str(mutated_drop.get("item_id", "")),
						drop_position + mutated_drop.get("offset", Vector2.ZERO),
						bool(mutated_drop.get("is_seed", false))
					)
		else:
			if world.has_method("spawn_item_drop"):
				world.spawn_item_drop(block_type, drop_position, false)

			if randf() <= mature_seed_extra_drop_chance:
				if world.has_method("spawn_item_drop"):
					world.spawn_item_drop(seed_type, drop_position + Vector2(0, -8), true)
	else:
		if world.has_method("spawn_item_drop"):
			world.spawn_item_drop(seed_type, drop_position, true)


func remove_seed_at(grid_pos: Vector2i) -> bool:
	if not planted_seeds.has(grid_pos):
		return false

	var seed_node = planted_seeds[grid_pos].get("node", null)
	if is_instance_valid(seed_node):
		seed_node.queue_free()

	planted_seeds.erase(grid_pos)
	return true


func set_seed_mature(grid_pos: Vector2i, mature: bool):
	if not planted_seeds.has(grid_pos):
		return

	planted_seeds[grid_pos]["mature"] = mature
	if mature:
		planted_seeds[grid_pos]["grow_time"] = 0.0

	planted_seeds[grid_pos]["stage"] = -1
	update_seed_tree_visual(grid_pos)


func set_seed_mutated(grid_pos: Vector2i, mutated: bool):
	if not planted_seeds.has(grid_pos):
		return

	planted_seeds[grid_pos]["mutated"] = mutated
	planted_seeds[grid_pos]["stage"] = -1
	update_seed_tree_visual(grid_pos)


func seed_to_block_type(seed_type: String) -> String:
	if item_database.has(seed_type):
		return str(item_database[seed_type].get("grows_into", seed_type.replace("_seed", "")))

	return seed_type.replace("_seed", "")


func get_save_data() -> Array:
	var result = []

	for grid_pos in planted_seeds.keys():
		var seed_data = planted_seeds[grid_pos]
		var seed_node = seed_data["node"]

		if is_instance_valid(seed_node):
			result.append({
				"x": grid_pos.x,
				"y": grid_pos.y,
				"seed_type": seed_data["seed_type"],
				"grow_time": seed_data["grow_time"],
				"max_grow_time": seed_data.get("max_grow_time", seed_grow_time),
				"mature": seed_data.get("mature", false),
				"mutated": seed_data.get("mutated", false)
			})

	return result


func load_seed_data(saved_seeds: Array):
	clear()

	for seed_data in saved_seeds:
		var grid_pos = Vector2i(seed_data["x"], seed_data["y"])
		var seed_type = str(seed_data["seed_type"])
		var grow_time = float(seed_data.get("grow_time", seed_grow_time))
		var max_grow_time = float(seed_data.get("max_grow_time", seed_grow_time))
		var mature = bool(seed_data.get("mature", false))
		var mutated = bool(seed_data.get("mutated", false))

		if seed_textures.has(seed_type):
			create_planted_seed(grid_pos, seed_type, grow_time, max_grow_time)

			if planted_seeds.has(grid_pos):
				planted_seeds[grid_pos]["mature"] = mature
				planted_seeds[grid_pos]["mutated"] = mutated

				if mature:
					planted_seeds[grid_pos]["grow_time"] = 0.0

				planted_seeds[grid_pos]["stage"] = -1
				update_seed_tree_visual(grid_pos)


func clear():
	for grid_pos in planted_seeds.keys():
		var seed_node = planted_seeds[grid_pos]["node"]

		if is_instance_valid(seed_node):
			seed_node.queue_free()

	planted_seeds.clear()


func notify(message: String):
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)
	else:
		print(message)
