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
const TREE_PREVIEW_ROOT_NAME = "TreePreviewSprites"
const TREE_PREVIEW_MAX_DISPLAY_SIZE = 7.0
const TREE_PREVIEW_Z_INDEX = 5
const TREE_PREVIEW_SHADOW_OFFSET = Vector2(1.0, 1.0)
const TREE_PREVIEW_SHADOW_ALPHA = 0.45
const TREE_TEXTURE_SHADOW_NAME = "TreeSpriteShadow"
const TREE_TEXTURE_SHADOW_OFFSET = Vector2(1.5, 1.5)
const TREE_TEXTURE_SHADOW_ALPHA = 0.38
const SEED_GROWTH_UPDATE_INTERVAL := 0.25
const GROWING_TREE_BREAK_HITS_REQUIRED := 3

var seed_growth_update_elapsed := 0.0
var animated_mature_seed_grids: Dictionary = {}
var seed_tree_visual_cache_warmed := false


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
	seed_growth_update_elapsed = 0.0
	animated_mature_seed_grids.clear()
	seed_tree_visual_cache_warmed = false
	warm_seed_tree_visual_cache()


func has_seed_at(grid_pos: Vector2i) -> bool:
	return planted_seeds.has(grid_pos)


func get_seed_growth_status_text_for_player(player_grid_pos: Vector2i, player_world_pos: Vector2) -> String:
	var seed_grid = get_seed_grid_overlapping_player(player_grid_pos, player_world_pos)
	if seed_grid == invalid_grid_pos:
		return ""

	return get_seed_growth_status_text(seed_grid)


func get_seed_hover_info_for_player(player_grid_pos: Vector2i, player_world_pos: Vector2) -> Dictionary:
	var seed_grid = get_seed_grid_overlapping_player(player_grid_pos, player_world_pos)
	if seed_grid == invalid_grid_pos:
		return {}

	return get_seed_hover_info(seed_grid)


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
	if is_seed_ready_to_harvest(grid_pos):
		return "Ready to harvest"

	return "Growth: " + format_seed_growth_time(float(seed_data.get("grow_time", 0.0)))


func is_seed_ready_to_harvest(grid_pos: Vector2i) -> bool:
	if not planted_seeds.has(grid_pos):
		return false

	var seed_data = planted_seeds[grid_pos]
	return bool(seed_data.get("mature", false)) or float(seed_data.get("grow_time", 0.0)) <= 0.0


func get_ready_seed_grid_overlapping_player(player_grid_pos: Vector2i, player_world_pos: Vector2) -> Vector2i:
	if planted_seeds.has(player_grid_pos) and is_seed_ready_to_harvest(player_grid_pos):
		return player_grid_pos

	var best_grid = invalid_grid_pos
	var best_distance = 100000000.0

	for grid_pos in planted_seeds.keys():
		if not is_seed_ready_to_harvest(grid_pos):
			continue

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


func get_seed_hover_info(grid_pos: Vector2i) -> Dictionary:
	if not planted_seeds.has(grid_pos):
		return {}

	var seed_data = planted_seeds[grid_pos]
	var seed_type: String = str(seed_data.get("seed_type", ""))
	var block_type: String = seed_to_block_type(seed_type)
	var tree_name: String = get_tree_display_name(block_type, seed_type)
	if bool(seed_data.get("mutated", false)):
		tree_name = "Mutant " + tree_name

	return {
		"tree_name": tree_name,
		"status_text": get_seed_growth_status_text(grid_pos),
		"mature": is_seed_ready_to_harvest(grid_pos),
		"grid_pos": grid_pos
	}


func get_tree_display_name(block_type: String, seed_type: String = "") -> String:
	var display_name: String = ""

	if item_database.has(block_type) and item_database[block_type] is Dictionary:
		display_name = str(item_database[block_type].get("display_name", "")).strip_edges()

	if display_name == "" and item_database.has(seed_type) and item_database[seed_type] is Dictionary:
		display_name = str(item_database[seed_type].get("display_name", "")).strip_edges()
		if display_name.to_lower().ends_with(" seed"):
			display_name = display_name.substr(0, display_name.length() - " Seed".length()).strip_edges()

	if display_name == "":
		display_name = block_type.replace("_", " ").capitalize()

	if display_name == "":
		display_name = "Seed"

	if not display_name.to_lower().ends_with("tree"):
		display_name += " Tree"

	return display_name


func format_seed_growth_time(seconds_remaining: float) -> String:
	var total_seconds = int(ceil(max(0.0, seconds_remaining)))
	if total_seconds >= 60:
		var minutes = int(float(total_seconds) / 60.0)
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

	var result_seed_grow_time := get_seed_growth_time(result_seed)
	planted_seeds[grid_pos]["seed_type"] = result_seed
	planted_seeds[grid_pos]["grow_time"] = result_seed_grow_time
	planted_seeds[grid_pos]["max_grow_time"] = result_seed_grow_time
	planted_seeds[grid_pos]["mature"] = false
	planted_seeds[grid_pos]["stage"] = -1

	update_seed_tree_visual(grid_pos)
	sync_seed_animation_membership(grid_pos)

	notify("Spliced into " + get_seed_display_name(result_seed) + ".")

	return true




func get_seed_growth_time(seed_id: String) -> float:
	var clean_seed_id := seed_id.strip_edges()
	if item_database.has(clean_seed_id) and item_database[clean_seed_id] is Dictionary:
		var seed_data: Dictionary = item_database[clean_seed_id]
		return max(1.0, float(seed_data.get("max_grow_time", seed_data.get("grow_time", seed_grow_time))))

	return seed_grow_time


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
	sync_seed_animation_membership(grid_pos)

	return true


func update_seed_system(delta):
	if planted_seeds.is_empty():
		seed_growth_update_elapsed = 0.0
		animated_mature_seed_grids.clear()
		return

	for grid_pos in animated_mature_seed_grids.keys().duplicate():
		if not planted_seeds.has(grid_pos):
			animated_mature_seed_grids.erase(grid_pos)
			continue
		animate_mature_seed_tree(grid_pos)

	seed_growth_update_elapsed += delta
	if seed_growth_update_elapsed < SEED_GROWTH_UPDATE_INTERVAL:
		return

	var growth_delta := seed_growth_update_elapsed
	seed_growth_update_elapsed = 0.0

	for grid_pos in planted_seeds.keys().duplicate():
		if not planted_seeds.has(grid_pos):
			continue

		var seed_data = planted_seeds[grid_pos]

		if not is_instance_valid(seed_data["node"]):
			animated_mature_seed_grids.erase(grid_pos)
			planted_seeds.erase(grid_pos)
			continue

		if bool(seed_data.get("mature", false)):
			sync_seed_animation_membership(grid_pos)
			continue

		var new_grow_time = max(0.0, float(seed_data["grow_time"]) - growth_delta)
		planted_seeds[grid_pos]["grow_time"] = new_grow_time

		if new_grow_time <= 0.0:
			planted_seeds[grid_pos]["mature"] = true

		update_seed_tree_visual(grid_pos)
		sync_seed_animation_membership(grid_pos)


func sync_seed_animation_membership(grid_pos: Vector2i) -> void:
	if not planted_seeds.has(grid_pos):
		animated_mature_seed_grids.erase(grid_pos)
		return

	var seed_data = planted_seeds[grid_pos]
	if bool(seed_data.get("mature", false)) and bool(seed_data.get("mutated", false)):
		animated_mature_seed_grids[grid_pos] = true
	else:
		animated_mature_seed_grids.erase(grid_pos)


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
	var previous_stage: int = int(seed_data.get("stage", -1))

	if previous_stage == stage:
		if stage == 3:
			var current_seed_type = str(seed_data["seed_type"])
			var current_block_type = seed_to_block_type(current_seed_type)
			var current_tree_texture = get_seed_tree_texture(current_block_type, stage)
			if bool(seed_data.get("mutated", false)) and mutant_tree_mature_texture != null:
				current_tree_texture = mutant_tree_mature_texture
			var current_tree_sprite = seed_node.get_node_or_null("TreeSprite")
			if current_tree_sprite != null and current_tree_sprite is Sprite2D:
				sync_tree_texture_shadow(seed_node, current_tree_sprite)
			update_tree_preview_sprites(seed_node, current_block_type, current_tree_texture, bool(seed_data.get("mutated", false)))
			if should_create_tree_type_badge(current_block_type, bool(seed_data.get("mutated", false))):
				if not tree_type_badge_needs_refresh(seed_node):
					return
				create_tree_type_badge(seed_node, current_block_type, current_tree_texture)
			else:
				remove_tree_type_badge(seed_node)
		return

	planted_seeds[grid_pos]["stage"] = stage

	for child in seed_node.get_children():
		seed_node.remove_child(child)
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
	sync_tree_texture_shadow(seed_node, sprite)

	if stage == 3:
		update_tree_preview_sprites(seed_node, block_type, tree_texture, bool(seed_data.get("mutated", false)))

	if stage == 3 and should_create_tree_type_badge(block_type, bool(seed_data.get("mutated", false))):
		create_tree_type_badge(seed_node, block_type, tree_texture)

	emit_tree_growth_particles(grid_pos, block_type, stage, previous_stage)


func emit_tree_growth_particles(grid_pos: Vector2i, block_type: String, stage: int, previous_stage: int):
	if previous_stage < 0 or stage <= previous_stage:
		return
	if world == null or not world.has_method("spawn_tree_growth_particles"):
		return

	world.spawn_tree_growth_particles(grid_pos, block_type, stage)


func remove_tree_texture_shadow(seed_node: Node2D):
	if seed_node == null or not is_instance_valid(seed_node):
		return

	var shadow_node = seed_node.get_node_or_null(TREE_TEXTURE_SHADOW_NAME)
	if shadow_node == null:
		return

	seed_node.remove_child(shadow_node)
	shadow_node.queue_free()


func sync_tree_texture_shadow(seed_node: Node2D, source_sprite: Sprite2D):
	if seed_node == null or not is_instance_valid(seed_node) or source_sprite == null:
		return

	if source_sprite.texture == null:
		remove_tree_texture_shadow(seed_node)
		return

	var shadow_node = seed_node.get_node_or_null(TREE_TEXTURE_SHADOW_NAME)
	var shadow_sprite: Sprite2D = null

	if shadow_node != null and shadow_node.is_queued_for_deletion():
		if shadow_node.get_parent() == seed_node:
			seed_node.remove_child(shadow_node)
		shadow_node = null

	if shadow_node != null:
		if shadow_node is Sprite2D:
			shadow_sprite = shadow_node as Sprite2D
		else:
			seed_node.remove_child(shadow_node)
			shadow_node.queue_free()

	if shadow_sprite == null:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.name = TREE_TEXTURE_SHADOW_NAME
		seed_node.add_child(shadow_sprite)

	shadow_sprite.texture = source_sprite.texture
	shadow_sprite.centered = source_sprite.centered
	shadow_sprite.offset = source_sprite.offset
	shadow_sprite.flip_h = source_sprite.flip_h
	shadow_sprite.flip_v = source_sprite.flip_v
	shadow_sprite.scale = source_sprite.scale
	shadow_sprite.rotation = source_sprite.rotation
	shadow_sprite.position = source_sprite.position + TREE_TEXTURE_SHADOW_OFFSET
	shadow_sprite.z_as_relative = source_sprite.z_as_relative
	shadow_sprite.z_index = source_sprite.z_index - 1
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.modulate = Color(0.0, 0.0, 0.0, TREE_TEXTURE_SHADOW_ALPHA)
	shadow_sprite.visible = source_sprite.visible


func should_create_tree_preview_sprites(block_type: String, mutated: bool = false) -> bool:
	if mutated:
		return false

	if world != null and world.has_method("uses_generated_seed_tree_texture"):
		return bool(world.uses_generated_seed_tree_texture(block_type))

	return false


func update_tree_preview_sprites(seed_node: Node2D, block_type: String, tree_texture, mutated: bool = false):
	var existing_root = seed_node.get_node_or_null(TREE_PREVIEW_ROOT_NAME)
	if not should_create_tree_preview_sprites(block_type, mutated):
		if existing_root != null:
			seed_node.remove_child(existing_root)
			existing_root.queue_free()
		return

	var preview_texture = get_tree_preview_texture(block_type)
	if preview_texture == null or tree_texture == null:
		if existing_root != null:
			seed_node.remove_child(existing_root)
			existing_root.queue_free()
		return

	var preview_scale: Vector2 = get_tree_preview_sprite_scale(preview_texture)
	var preview_size := Vector2i(
		max(1, int(round(float(preview_texture.get_width()) * preview_scale.x))),
		max(1, int(round(float(preview_texture.get_height()) * preview_scale.y)))
	)
	var tree_size := Vector2i(max(1, tree_texture.get_width()), max(1, tree_texture.get_height()))
	var position_key: String = block_type + ":" + str(tree_size) + ":" + str(preview_size)
	if existing_root != null and str(existing_root.get_meta("position_key", "")) == position_key:
		return

	if existing_root != null:
		seed_node.remove_child(existing_root)
		existing_root.queue_free()

	var preview_root := Node2D.new()
	preview_root.name = TREE_PREVIEW_ROOT_NAME
	preview_root.z_index = TREE_PREVIEW_Z_INDEX
	preview_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_root.set_meta("position_key", position_key)
	seed_node.add_child(preview_root)

	var preview_positions: Array = []
	if world != null and world.has_method("get_seed_tree_preview_positions"):
		preview_positions = world.get_seed_tree_preview_positions(block_type, tree_size, preview_size)

	if preview_positions.is_empty():
		preview_positions.append(Vector2i(
			int(round(float(tree_size.x - preview_size.x) * 0.5)),
			int(round(float(tree_size.y - preview_size.y) * 0.35))
		))

	for destination in preview_positions:
		var preview_position: Vector2 = tree_texture_top_left_to_local(destination, tree_size, preview_size)
		var shadow_sprite := Sprite2D.new()
		shadow_sprite.name = "TreePreviewShadow"
		shadow_sprite.texture = preview_texture
		shadow_sprite.centered = true
		shadow_sprite.scale = preview_scale
		shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow_sprite.modulate = Color(0.0, 0.0, 0.0, TREE_PREVIEW_SHADOW_ALPHA)
		shadow_sprite.position = preview_position + TREE_PREVIEW_SHADOW_OFFSET
		shadow_sprite.z_index = 0
		preview_root.add_child(shadow_sprite)

		var preview_sprite := Sprite2D.new()
		preview_sprite.name = "TreePreviewSprite"
		preview_sprite.texture = preview_texture
		preview_sprite.centered = true
		preview_sprite.scale = preview_scale
		preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_sprite.position = preview_position
		preview_sprite.z_index = 1
		preview_root.add_child(preview_sprite)


func get_tree_preview_texture(block_type: String):
	if block_textures.has(block_type):
		return block_textures[block_type]

	if world != null and world.has_method("get_seed_preview_block_texture"):
		var block_texture = world.get_seed_preview_block_texture(block_type)
		if block_texture != null:
			return block_texture

	return get_tree_type_badge_texture(block_type)


func get_tree_preview_sprite_scale(preview_texture) -> Vector2:
	var longest_edge = max(float(preview_texture.get_width()), float(preview_texture.get_height()))
	if longest_edge <= 0.0:
		return Vector2.ONE

	var scale_amount = min(1.0, TREE_PREVIEW_MAX_DISPLAY_SIZE / longest_edge)
	return Vector2(scale_amount, scale_amount)


func tree_texture_top_left_to_local(destination: Vector2i, tree_size: Vector2i, preview_size: Vector2i) -> Vector2:
	return Vector2(destination) - (Vector2(tree_size) * 0.5) + (Vector2(preview_size) * 0.5)


func should_create_tree_type_badge(block_type: String, mutated: bool = false) -> bool:
	if mutated:
		return true

	if world != null and world.has_method("uses_generated_seed_tree_texture"):
		return not bool(world.uses_generated_seed_tree_texture(block_type))

	return true


func remove_tree_type_badge(seed_node: Node2D):
	var badge = seed_node.get_node_or_null("TreeTypeBadge")
	if badge == null:
		return

	seed_node.remove_child(badge)
	badge.queue_free()


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


func warm_seed_tree_visual_cache() -> void:
	if seed_tree_visual_cache_warmed:
		return

	seed_tree_visual_cache_warmed = true
	for block_type in seed_tree_textures.keys():
		var textures = seed_tree_textures[block_type]
		if not (textures is Array):
			continue

		var tree_texture_size := Vector2i(1, 1)
		for texture in textures:
			if texture == null:
				continue
			if texture is Texture2D:
				texture.get_width()
				texture.get_height()
				tree_texture_size = Vector2i(max(1, texture.get_width()), max(1, texture.get_height()))

		if should_create_tree_preview_sprites(block_type, false):
			var preview_texture = get_tree_preview_texture(block_type)
			if preview_texture is Texture2D:
				var preview_scale = get_tree_preview_sprite_scale(preview_texture)
				if world != null and world.has_method("get_seed_tree_preview_positions"):
					world.get_seed_tree_preview_positions(
						block_type,
						tree_texture_size,
						Vector2i(
							max(1, int(round(float(preview_texture.get_width()) * preview_scale.x))),
							max(1, int(round(float(preview_texture.get_height()) * preview_scale.y)))
						)
					)

		var badge_texture = get_tree_type_badge_texture(block_type)
		if badge_texture is Texture2D:
			badge_texture.get_height()
			var slot_texture = get_tree_type_badge_slot_texture(block_type)
			if slot_texture != null and slot_texture is Texture2D:
				slot_texture.get_height()

	if mutant_tree_mature_texture is Texture2D:
		mutant_tree_mature_texture.get_width()
		mutant_tree_mature_texture.get_height()


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
			if sprite is Sprite2D:
				sync_tree_texture_shadow(seed_node, sprite)
			if badge != null:
				badge.position = badge_base_position
			return

		var bob = sin(Time.get_ticks_msec() / 260.0) * 1.2
		sprite.position = Vector2(0, bob)
		if sprite is Sprite2D:
			sync_tree_texture_shadow(seed_node, sprite)
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


func get_tree_harvest_drop_amount(fixed_drop: Dictionary) -> int:
	var amount_range = fixed_drop.get("amount_range", fixed_drop.get("amountRange", []))
	if amount_range is Array and amount_range.size() >= 2:
		var first_amount = int(clamp(int(amount_range[0]), 0, world.MAX_ITEM_STACK_SIZE))
		var second_amount = int(clamp(int(amount_range[1]), 0, world.MAX_ITEM_STACK_SIZE))
		var min_amount = min(first_amount, second_amount)
		var max_amount = max(first_amount, second_amount)
		return randi_range(min_amount, max_amount)

	return int(clamp(int(fixed_drop.get("amount", 1)), 1, world.MAX_ITEM_STACK_SIZE))


func get_tree_harvest_drop_category(item_id: String, requested_category: String) -> String:
	var category = requested_category.strip_edges()
	if category != "":
		return category
	if item_database.has(item_id):
		return str(item_database[item_id].get("category", ""))
	if item_id.ends_with("_seed"):
		return "seed"
	return "block"


func get_tree_harvest_drops(block_type: String) -> Array:
	if not item_database.has(block_type):
		return []
	if not (item_database[block_type] is Dictionary):
		return []

	var block_data: Dictionary = item_database[block_type]
	var rules = block_data.get("tree_drop_rules", block_data.get("harvest_drop_rules", {}))
	if not (rules is Dictionary):
		return []

	var fixed_drops = rules.get("fixed_drops", [])
	if not (fixed_drops is Array):
		return []

	var drops: Array = []
	for fixed_drop in fixed_drops:
		if not (fixed_drop is Dictionary):
			continue

		var item_id = str(fixed_drop.get("item_id", fixed_drop.get("item_type", ""))).strip_edges()
		if item_id == "" or not item_database.has(item_id):
			continue

		var item_category = get_tree_harvest_drop_category(
			item_id,
			str(fixed_drop.get("item_category", fixed_drop.get("category", "")))
		)
		if item_category == "":
			continue

		var amount = get_tree_harvest_drop_amount(fixed_drop)
		if amount <= 0:
			continue

		drops.append({
			"item_id": item_id,
			"item_category": item_category,
			"amount": amount
		})

	return drops


func spawn_tree_harvest_rule_drops(block_type: String, seed_type: String, drop_position: Vector2) -> bool:
	var drops = get_tree_harvest_drops(block_type)
	if drops.is_empty():
		return false

	for drop in drops:
		if not (drop is Dictionary):
			continue

		var item_id := str(drop.get("item_id", "")).strip_edges()
		var item_category := str(drop.get("item_category", "")).strip_edges()
		var amount := int(drop.get("amount", 1))
		if item_id == "" or item_category == "" or amount <= 0:
			continue

		var offset := Vector2.ZERO
		if item_id == seed_type or item_category == "seed":
			offset = Vector2(0, -8)

		if world.has_method("create_item_drop"):
			world.create_item_drop(item_id, drop_position + offset, item_category == "seed", item_category, 0.0, amount)
		elif world.has_method("spawn_item_drop"):
			for i in range(amount):
				world.spawn_item_drop(item_id, drop_position + offset, item_category == "seed")

	return true


func harvest_planted_seed(grid_pos: Vector2i):
	if not planted_seeds.has(grid_pos):
		return

	var seed_data = planted_seeds[grid_pos]
	var seed_type = str(seed_data["seed_type"])
	var block_type = seed_to_block_type(seed_type)
	var seed_node = seed_data["node"]
	var drop_position = Vector2(grid_pos.x * block_size, grid_pos.y * block_size)
	var was_mature := bool(seed_data.get("mature", false))
	if not was_mature:
		var break_hits := mini(GROWING_TREE_BREAK_HITS_REQUIRED, int(seed_data.get("break_hits", 0)) + 1)
		if break_hits < GROWING_TREE_BREAK_HITS_REQUIRED:
			planted_seeds[grid_pos]["break_hits"] = break_hits
			return

	if was_mature and world != null and world.has_method("spawn_tree_break_particles"):
		world.spawn_tree_break_particles(grid_pos, block_type)

	if is_instance_valid(seed_node):
		seed_node.queue_free()

	animated_mature_seed_grids.erase(grid_pos)
	planted_seeds.erase(grid_pos)

	if world == null:
		return

	if was_mature:
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
			if spawn_tree_harvest_rule_drops(block_type, seed_type, drop_position):
				return
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

	animated_mature_seed_grids.erase(grid_pos)
	planted_seeds.erase(grid_pos)
	return true


func get_seed_break_particle_data(grid_pos: Vector2i) -> Dictionary:
	if not planted_seeds.has(grid_pos):
		return {}

	var seed_data = planted_seeds[grid_pos]
	var seed_type = str(seed_data.get("seed_type", ""))

	return {
		"mature": bool(seed_data.get("mature", false)),
		"block_type": seed_to_block_type(seed_type),
		"seed_type": seed_type
	}


func set_seed_mature(grid_pos: Vector2i, mature: bool):
	if not planted_seeds.has(grid_pos):
		return

	planted_seeds[grid_pos]["mature"] = mature
	if mature:
		planted_seeds[grid_pos]["grow_time"] = 0.0

	planted_seeds[grid_pos]["stage"] = -1
	update_seed_tree_visual(grid_pos)
	sync_seed_animation_membership(grid_pos)


func set_seed_mutated(grid_pos: Vector2i, mutated: bool):
	if not planted_seeds.has(grid_pos):
		return

	planted_seeds[grid_pos]["mutated"] = mutated
	planted_seeds[grid_pos]["stage"] = -1
	update_seed_tree_visual(grid_pos)
	sync_seed_animation_membership(grid_pos)


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
				sync_seed_animation_membership(grid_pos)


func clear():
	for grid_pos in planted_seeds.keys():
		var seed_node = planted_seeds[grid_pos]["node"]

		if is_instance_valid(seed_node):
			seed_node.queue_free()

	planted_seeds.clear()
	animated_mature_seed_grids.clear()
	seed_growth_update_elapsed = 0.0


func notify(message: String):
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)
	else:
		print(message)
