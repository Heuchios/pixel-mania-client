extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

var world = null
var background_blocks: Dictionary = {}
var last_server_sign_on_notice_at := 0
var animated_block_visuals: Dictionary = {}
var wooden_entrance_active_visuals: Dictionary = {}
var springboard_active_visuals: Dictionary = {}
var wooden_entrance_frame_cache: Array[Texture2D] = []
var last_wooden_entrance_grid := Vector2i(-999999, -999999)
var visual_variant_texture_cache: Dictionary = {}
var existing_variant_path_cache: Dictionary = {}
var authoritative_break_request_keys: Dictionary = {}
var authoritative_place_request_times: Dictionary = {}
const AUTHORITATIVE_REQUEST_REPEAT_MS := 1000
const DEBUG_ACTION_POSITION_FLOW := false
const WOODEN_ENTRANCE_FRAME_SECONDS := 0.14
const WATER_VISUAL_Z_INDEX := 120

const NO_VARIANT_GRID_POS := Vector2i(-999999, -999999)
const DIRT_TOP_TEXTURE_PATH := "res://Assets/blocks/basic blocks/dirt_block.png"
const DIRT_LOWER_TEXTURE_PATHS := [
	"res://Assets/blocks/basic blocks/dirt_block_1.png",
	"res://Assets/blocks/basic blocks/dirt_block_2.png"
]
const STONE_TEXTURE_PATHS := [
	"res://Assets/blocks/basic blocks/stone_block.png",
	"res://Assets/blocks/basic blocks/stone_block_2.png",
	"res://Assets/blocks/basic blocks/stone_block_3.png"
]
const WATER_TOP_TEXTURE_PATH := "res://Assets/blocks/basic blocks/water_0.png"
const WATER_LOWER_TEXTURE_PATH := "res://Assets/blocks/basic blocks/water_block_2.png"
const WOOD_PLATFORM_LEFT_END_TEXTURE_PATH := "res://Assets/blocks/crafting_station/blocks/wood_platform_left_end.png"
const WOOD_PLATFORM_MIDDLE_TEXTURE_PATH := "res://Assets/blocks/crafting_station/blocks/wood_platform_middle.png"
const WOOD_PLATFORM_RIGHT_END_TEXTURE_PATH := "res://Assets/blocks/crafting_station/blocks/wood_platform_right_end.png"
const CAVE_BACKGROUND_TEXTURE_PATHS := [
	"res://Assets/background/cave_background.png",
	"res://Assets/background/cave_background_2.png",
	"res://Assets/background/cave_background_3.png"
]

func setup(world_ref):
	world = world_ref


func _process(delta):
	update_wooden_entrance_crossing()
	update_wooden_entrance_animations(delta)
	update_springboard_animations(delta)

	if not animated_block_visuals.is_empty():
		update_synced_block_animations()


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][BlockManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func is_applying_network_world_update() -> bool:
	if world == null:
		return false
	if "applying_network_world_update" in world:
		return bool(world.applying_network_world_update)
	return false


func send_network_block_update(action: String, layer: String, grid_pos: Vector2i, block_type: String = "", extra_data: Dictionary = {}) -> bool:
	if is_applying_network_world_update():
		return false
	if world == null:
		return false
	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	if network.has_method("send_world_block_update"):
		if str(action).to_lower() == "break" or str(action).to_lower() == "hit":
			debug_action_position_flow("break block request send", {
				"action": action,
				"layer": layer,
				"x": grid_pos.x,
				"y": grid_pos.y,
				"block_type": block_type
			})
		var sent = bool(network.send_world_block_update(action, layer, grid_pos, block_type, world.current_world_name, extra_data))
		if str(action).to_lower() == "break" or str(action).to_lower() == "hit":
			debug_action_position_flow("break block request end", {
				"action": action,
				"sent": sent,
				"layer": layer,
				"x": grid_pos.x,
				"y": grid_pos.y,
				"block_type": block_type
		})
		return sent
	return false


func get_network_manager():
	if world == null:
		return null

	return world.get_node_or_null("/root/NetworkManager")


func should_use_server_authoritative_world_actions() -> bool:
	if world == null:
		return false
	if world.has_method("should_use_server_authoritative_world_actions"):
		if not bool(world.should_use_server_authoritative_world_actions()):
			return false
	else:
		return false
	var network = get_network_manager()
	if network == null:
		return false
	if network.has_method("is_server_session_authenticated"):
		return bool(network.is_server_session_authenticated())
	return bool(network.get("server_session_authenticated"))


func get_authoritative_break_key(layer: String, grid_pos: Vector2i) -> String:
	return layer + ":" + str(grid_pos.x) + ":" + str(grid_pos.y)


func get_authoritative_place_key(layer: String, grid_pos: Vector2i, block_type: String) -> String:
	return layer + ":" + str(grid_pos.x) + ":" + str(grid_pos.y) + ":" + block_type


func has_recent_authoritative_place_request(key: String) -> bool:
	var now = Time.get_ticks_msec()
	var last_sent = int(authoritative_place_request_times.get(key, 0))
	return last_sent > 0 and now - last_sent < AUTHORITATIVE_REQUEST_REPEAT_MS


func mark_authoritative_place_request(key: String):
	authoritative_place_request_times[key] = Time.get_ticks_msec()


func should_server_create_break_drops() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func is_waiting_for_server_sign_on() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions") and not bool(world.should_use_server_authoritative_world_actions()):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return true

	if network.has_method("can_send_authenticated_payload"):
		return not bool(network.can_send_authenticated_payload())

	if network.has_method("is_server_session_authenticated"):
		return not bool(network.is_server_session_authenticated())

	return true


func show_server_sign_on_notice():
	if world == null:
		return

	var now = Time.get_ticks_msec()
	if now - last_server_sign_on_notice_at < 1500:
		return

	last_server_sign_on_notice_at = now
	world.show_notification("Almost ready. Try again in a moment.")


func get_background_blocks_parent():
	if world == null:
		return null

	if world.has_node("BackgroundBlocks"):
		return world.get_node("BackgroundBlocks")

	return world


func is_background_block_type(block_type: String) -> bool:
	if world == null:
		return false

	if not world.item_database.has(block_type):
		return false

	var item_data = world.item_database[block_type]

	if bool(item_data.get("background_block", false)):
		return true

	if str(item_data.get("place_layer", "")) == "background":
		return true

	return false


func get_stable_variant_index(grid_pos: Vector2i, count: int, salt: int = 0) -> int:
	if count <= 1:
		return 0

	var value = int((grid_pos.x * 73856093) + (grid_pos.y * 19349663) + (salt * 83492791))
	return posmod(value, count)


func get_weighted_stable_variant_index(grid_pos: Vector2i, weights: Array, salt: int = 0) -> int:
	var total_weight := 0
	for weight in weights:
		total_weight += max(0, int(weight))

	if total_weight <= 0:
		return 0

	var roll = get_stable_variant_index(grid_pos, total_weight, salt)
	var running_total := 0
	for i in range(weights.size()):
		running_total += max(0, int(weights[i]))
		if roll < running_total:
			return i

	return max(0, weights.size() - 1)


func normalize_legacy_block_id(block_type: String) -> String:
	if block_type == "crafting_station_left":
		return "crafting_station"
	if block_type == "crafting_station_right":
		return ""
	return block_type


func get_cached_visual_variant_texture(texture_path: String):
	if texture_path == "":
		return null

	if visual_variant_texture_cache.has(texture_path):
		return visual_variant_texture_cache[texture_path]

	if not ResourceLoader.exists(texture_path):
		visual_variant_texture_cache[texture_path] = null
		return null

	var texture = load(texture_path)
	visual_variant_texture_cache[texture_path] = texture
	return texture


func get_foreground_block_type_at(grid_pos: Vector2i) -> String:
	if world == null or not world.blocks.has(grid_pos):
		return ""

	return str(world.blocks[grid_pos].get("type", ""))


func is_wood_platform_block_type(block_type: String) -> bool:
	return block_type == "wood_platform"


func has_wood_platform_neighbor(grid_pos: Vector2i) -> bool:
	return is_wood_platform_block_type(get_foreground_block_type_at(grid_pos))


func is_wooden_entrance_block_type(block_type: String) -> bool:
	return block_type == "wooden_entrance"


func is_wooden_entrance_at(grid_pos: Vector2i) -> bool:
	return is_wooden_entrance_block_type(get_foreground_block_type_at(grid_pos))


func get_grid_pos_for_block_node(block) -> Vector2i:
	if block == null or world == null:
		return NO_VARIANT_GRID_POS

	return Vector2i(
		int(round(block.position.x / world.BLOCK_SIZE)),
		int(round(block.position.y / world.BLOCK_SIZE))
	)


func is_wooden_entrance_locked(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	return bool(world.blocks[grid_pos].get("entrance_locked", false))


func can_current_player_pass_wooden_entrance() -> bool:
	if world != null and world.has_method("can_current_player_pass_wooden_entrance"):
		return bool(world.can_current_player_pass_wooden_entrance())

	return true


func should_disable_wooden_entrance_collision(grid_pos: Vector2i) -> bool:
	if not is_wooden_entrance_locked(grid_pos):
		return true

	return can_current_player_pass_wooden_entrance()


func refresh_wooden_entrance_collision(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	set_original_block_collision_disabled(block_node, should_disable_wooden_entrance_collision(grid_pos))


func refresh_all_wooden_entrance_collisions():
	if world == null:
		return

	for grid_pos in world.blocks.keys():
		if is_wooden_entrance_at(grid_pos):
			refresh_wooden_entrance_collision(grid_pos)


func get_existing_variant_paths(paths: Array) -> Array:
	var cache_key := ""
	for texture_path in paths:
		cache_key += str(texture_path) + "|"

	if existing_variant_path_cache.has(cache_key):
		return existing_variant_path_cache[cache_key]

	var existing_paths: Array = []
	for texture_path in paths:
		var clean_path = str(texture_path)
		if clean_path != "" and ResourceLoader.exists(clean_path):
			existing_paths.append(clean_path)

	existing_variant_path_cache[cache_key] = existing_paths
	return existing_paths


func get_visual_block_variant(base_block_id: String, grid_pos: Vector2i, background := false) -> String:
	if grid_pos == NO_VARIANT_GRID_POS:
		return ""

	if background:
		if base_block_id == "cave_background":
			var cave_paths = get_existing_variant_paths(CAVE_BACKGROUND_TEXTURE_PATHS)
			if cave_paths.is_empty():
				return ""
			return cave_paths[get_stable_variant_index(grid_pos, cave_paths.size(), 21)]
		return ""

	# Dirt and water use vertical visual rules. The block type saved for gameplay
	# stays as the base ID, while only the Sprite2D texture changes.
	if base_block_id == "dirt":
		var above_pos = Vector2i(grid_pos.x, grid_pos.y - 1)
		if get_foreground_block_type_at(above_pos) == "dirt":
			var dirt_lower_paths = get_existing_variant_paths(DIRT_LOWER_TEXTURE_PATHS)
			if dirt_lower_paths.is_empty():
				return DIRT_TOP_TEXTURE_PATH
			var dirt_variant_index = min(get_weighted_stable_variant_index(grid_pos, [85, 15], 11), dirt_lower_paths.size() - 1)
			return dirt_lower_paths[dirt_variant_index]
		return DIRT_TOP_TEXTURE_PATH

	if base_block_id == "stone":
		var stone_paths = get_existing_variant_paths(STONE_TEXTURE_PATHS)
		if stone_paths.is_empty():
			return ""
		var stone_variant_index = min(get_weighted_stable_variant_index(grid_pos, [65, 25, 10], 31), stone_paths.size() - 1)
		return stone_paths[stone_variant_index]

	if base_block_id == "water":
		var above_water_pos = Vector2i(grid_pos.x, grid_pos.y - 1)
		if get_foreground_block_type_at(above_water_pos) == "water":
			return WATER_LOWER_TEXTURE_PATH
		# Top water keeps the normal animated water frames; only lower water gets a static visual override.
		return ""

	if base_block_id == "wood_platform":
		var has_left_platform = has_wood_platform_neighbor(Vector2i(grid_pos.x - 1, grid_pos.y))
		var has_right_platform = has_wood_platform_neighbor(Vector2i(grid_pos.x + 1, grid_pos.y))

		if has_left_platform and has_right_platform:
			return WOOD_PLATFORM_MIDDLE_TEXTURE_PATH
		if has_right_platform:
			return WOOD_PLATFORM_LEFT_END_TEXTURE_PATH
		if has_left_platform:
			return WOOD_PLATFORM_RIGHT_END_TEXTURE_PATH
		return ""

	return ""


func clear_block_animation(block, visual: Sprite2D = null):
	if block != null and is_instance_valid(block):
		var existing_timer = block.get_node_or_null("BlockAnimationTimer")
		if existing_timer != null:
			if not existing_timer.is_queued_for_deletion():
				existing_timer.queue_free()

	if visual == null and block != null and is_instance_valid(block):
		visual = block.get_node_or_null("Visual")

	if visual == null:
		return

	animated_block_visuals.erase(visual.get_instance_id())

	if visual.has_meta("animation_frames"):
		visual.remove_meta("animation_frames")
	if visual.has_meta("animation_frame_index"):
		visual.remove_meta("animation_frame_index")


func parse_block_vector2(raw_value, fallback := Vector2.ZERO) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if raw_value is Vector2i:
		return Vector2(float(raw_value.x), float(raw_value.y))
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	if raw_value is Dictionary:
		return Vector2(float(raw_value.get("x", fallback.x)), float(raw_value.get("y", fallback.y)))

	return fallback


func parse_block_visual_offset(raw_offset) -> Vector2:
	return parse_block_vector2(raw_offset, Vector2.ZERO)


func apply_block_visual_layout(visual: Sprite2D, block_type: String):
	if visual == null:
		return
	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	visual.centered = bool(item_data.get("visual_centered", true))
	visual.position = parse_block_visual_offset(item_data.get("visual_offset", Vector2.ZERO))
	visual.z_index = WATER_VISUAL_Z_INDEX if block_type == "water" else 0
	visual.z_as_relative = true


func apply_original_collision_layout(block, block_type: String):
	if block == null or world == null:
		return

	var collision = block.get_node_or_null("CollisionShape2D")
	if collision == null:
		return

	var default_size = Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var item_data = world.item_database.get(block_type, {})
	var collision_size = parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset = parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)
	var rect_shape: RectangleShape2D

	if collision.shape is RectangleShape2D:
		rect_shape = collision.shape.duplicate() as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()

	rect_shape.size = collision_size
	collision.shape = rect_shape
	collision.position = collision_offset


func normalize_block_variant_at(grid_pos: Vector2i, background := false):
	if background:
		if not background_blocks.has(grid_pos):
			return

		var background_data = background_blocks[grid_pos]
		var background_node = background_data.get("node", null)
		if background_node == null or not is_instance_valid(background_node):
			return

		set_block_texture(background_node, str(background_data.get("type", "")), grid_pos, true)
		apply_background_block_style(background_node)
		return

	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	set_block_texture(block_node, str(block_data.get("type", "")), grid_pos, false)


func update_vertical_block_variants_around(grid_pos: Vector2i):
	# Vertical stacks need local neighbor refreshes after place/break/load:
	# dirt top stays dirt_block, lower dirt alternates stable variants;
	# water top stays water_0, deeper water becomes water_block_2.
	for y_offset in range(-2, 3):
		normalize_block_variant_at(Vector2i(grid_pos.x, grid_pos.y + y_offset), false)

	# Wood platforms use horizontal visual joins:
	# single = standalone, two = left/right, longer runs = left/middle/right.
	for x_offset in range(-2, 3):
		normalize_block_variant_at(Vector2i(grid_pos.x + x_offset, grid_pos.y), false)


func create_background_block(grid_pos: Vector2i, block_type: String = "cave_background"):
	if background_blocks.has(grid_pos):
		return

	var parent = get_background_blocks_parent()

	if parent == null:
		return

	var block = world.block_scene.instantiate()
	block.position = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	block.z_index = 0
	block.z_as_relative = true
	parent.add_child(block)

	background_blocks[grid_pos] = {
		"node": block,
		"type": block_type
	}
	authoritative_place_request_times.erase(get_authoritative_place_key("background", grid_pos, block_type))

	set_block_texture(block, block_type, grid_pos, true)
	apply_background_block_style(block)
	configure_block_collision(block, block_type)


func remove_background_block_without_drop(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_node = background_blocks[grid_pos]["node"]

	if block_node != null and is_instance_valid(block_node):
		clear_block_animation(block_node)
		block_node.queue_free()

	background_blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)


func replace_background_block_without_drop(grid_pos: Vector2i, block_type: String = "cave_background"):
	if background_blocks.has(grid_pos):
		remove_background_block_without_drop(grid_pos)

	create_background_block(grid_pos, block_type)


func clear_background_blocks():
	for grid_pos in background_blocks.keys():
		var block_node = background_blocks[grid_pos].get("node", null)

		if block_node != null and is_instance_valid(block_node):
			clear_block_animation(block_node)
			block_node.queue_free()

	background_blocks.clear()
	authoritative_break_request_keys.clear()
	authoritative_place_request_times.clear()


func update_background_block_crack_visual(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_data = background_blocks[grid_pos]
	var block_node = block_data["node"]
	var block_type = str(block_data["type"])

	if block_node == null:
		return

	var max_hits = get_block_max_hits(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0))
	var stage = get_crack_stage(current_hits, max_hits)

	var crack_overlay = block_node.get_node_or_null("CrackOverlay")

	if stage <= 0:
		if crack_overlay != null:
			crack_overlay.queue_free()

		return

	if not world.crack_textures.has(stage):
		return

	if crack_overlay == null:
		crack_overlay = Sprite2D.new()
		crack_overlay.name = "CrackOverlay"
		crack_overlay.centered = true
		crack_overlay.position = Vector2.ZERO
		crack_overlay.z_index = 20
		crack_overlay.z_as_relative = true
		block_node.add_child(crack_overlay)

	crack_overlay.texture = world.crack_textures[stage]
	crack_overlay.visible = true


func hit_background_block_grid(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_type = str(background_blocks[grid_pos]["type"])

	if world.has_method("can_current_player_break_block") and not world.can_current_player_break_block(block_type):
		world.show_notification("This world is locked.")
		return

	if world.item_database.has(block_type) and bool(world.item_database[block_type].get("unbreakable", false)):
		world.show_notification(world.get_item_display_name(block_type, "block") + " cannot be broken.")
		return

	var max_hits = get_block_max_hits(block_type)
	var hit_power = world.get_current_break_power(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0)) + hit_power
	world.block_hit_progress[grid_pos] = current_hits
	world.block_hit_timers[grid_pos] = world.BLOCK_DAMAGE_RESET_DELAY

	if should_use_server_authoritative_world_actions():
		var action = "hit" if current_hits < max_hits else "break"
		var break_key = get_authoritative_break_key("background", grid_pos)
		if action == "break" and authoritative_break_request_keys.has(break_key):
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
			return
		if send_network_block_update(action, "background", grid_pos, block_type, {
			"hit_power": hit_power,
			"hit_count": current_hits,
			"max_hits": max_hits
		}):
			if action == "break":
				authoritative_break_request_keys[break_key] = true
			update_background_block_crack_visual(grid_pos)
			if current_hits < max_hits:
				world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
			else:
				world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if current_hits < max_hits:
		send_network_block_update("hit", "background", grid_pos, block_type)
		update_background_block_crack_visual(grid_pos)
		world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
		return

	break_background_block_grid(grid_pos)


func break_background_block_grid(grid_pos: Vector2i):
	if not background_blocks.has(grid_pos):
		return

	var block_type = str(background_blocks[grid_pos]["type"])
	var block_node = background_blocks[grid_pos]["node"]
	var drop_position = block_node.global_position

	if should_use_server_authoritative_world_actions() and not is_applying_network_world_update():
		if send_network_block_update("break", "background", grid_pos, block_type):
			authoritative_break_request_keys[get_authoritative_break_key("background", grid_pos)] = true
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	var crack_overlay = block_node.get_node_or_null("CrackOverlay")
	if crack_overlay != null:
		crack_overlay.queue_free()

	block_node.queue_free()
	background_blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)

	send_network_block_update("break", "background", grid_pos, block_type)

	if not should_server_create_break_drops():
		world.try_drop_block(block_type, drop_position)
		world.try_drop_seed(block_type, drop_position)


func can_place_background_block_here(grid_pos: Vector2i) -> bool:
	if background_blocks.has(grid_pos):
		world.show_notification("There is already a background block here.")
		return false

	if world.has_planted_seed(grid_pos):
		world.show_notification("Cannot place behind a planted seed.")
		return false

	return true


func setup_crack_textures():
	world.crack_textures.clear()

	for stage in range(1, 4):
		var path = "res://Assets/effects/block_crack_" + str(stage) + ".png"

		if ResourceLoader.exists(path):
			world.crack_textures[stage] = load(path)


func get_block_max_hits(block_type: String) -> int:
	if world.item_database.has(block_type):
		return max(1, int(world.item_database[block_type].get("block_health", world.BLOCK_MAX_HITS)))

	return world.BLOCK_MAX_HITS


func get_crack_stage(current_hits: int, max_hits: int) -> int:
	if current_hits <= 0:
		return 0

	if max_hits <= 1:
		return 0

	var damage_ratio = float(current_hits) / float(max_hits)

	if damage_ratio >= 0.75:
		return 3

	if damage_ratio >= 0.45:
		return 2

	return 1


func update_block_crack_visual(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_node = block_data["node"]
	var block_type = str(block_data["type"])

	if block_node == null:
		return

	var max_hits = get_block_max_hits(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0))
	var stage = get_crack_stage(current_hits, max_hits)

	var crack_overlay = block_node.get_node_or_null("CrackOverlay")

	if stage <= 0:
		if crack_overlay != null:
			crack_overlay.queue_free()

		return

	if not world.crack_textures.has(stage):
		return

	if crack_overlay == null:
		crack_overlay = Sprite2D.new()
		crack_overlay.name = "CrackOverlay"
		crack_overlay.centered = true
		crack_overlay.position = Vector2.ZERO
		crack_overlay.z_index = 20
		crack_overlay.z_as_relative = true
		block_node.add_child(crack_overlay)

	crack_overlay.texture = world.crack_textures[stage]
	crack_overlay.visible = true


func is_non_collideable_block(block_type: String) -> bool:
	if not world.item_database.has(block_type):
		return false

	var item_data = world.item_database[block_type]

	# New preferred setting:
	# "collidable": false
	if item_data.has("collidable"):
		return not bool(item_data.get("collidable", true))

	# Old/backward-compatible setting:
	# "no_collision": true
	if item_data.has("no_collision"):
		return bool(item_data.get("no_collision", false))

	return false


func block_requires_world_lock(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("requires_world_lock", false))


func world_has_world_lock() -> bool:
	if world == null or world.world_lock_manager == null:
		return false

	return bool(world.world_lock_manager.is_locked)


func block_requires_full_area_clear(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("requires_full_area_clear", false))


func block_occupies_collision_area(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	return bool(world.item_database[block_type].get("occupies_collision_area", false))


func get_block_collision_rect_for_grid(grid_pos: Vector2i, block_type: String) -> Rect2:
	var default_size = Vector2(float(world.BLOCK_SIZE), float(world.BLOCK_SIZE))
	var item_data = world.item_database.get(block_type, {})
	var collision_size = parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset = parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)
	var center = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE) + collision_offset
	return Rect2(center - collision_size * 0.5, collision_size)


func get_grid_positions_overlapping_rect(rect: Rect2) -> Array:
	var positions: Array = []
	var block_size = float(world.BLOCK_SIZE)
	var half_block = block_size * 0.5
	var epsilon = 0.01
	var min_x = int(floor((rect.position.x + half_block + epsilon) / block_size))
	var min_y = int(floor((rect.position.y + half_block + epsilon) / block_size))
	var max_x = int(floor((rect.position.x + rect.size.x - epsilon + half_block) / block_size))
	var max_y = int(floor((rect.position.y + rect.size.y - epsilon + half_block) / block_size))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			positions.append(Vector2i(x, y))

	return positions


func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
	if world == null:
		return Vector2i(999999, 999999)

	if world.blocks.has(grid_pos):
		return grid_pos

	var block_size = float(world.BLOCK_SIZE)
	var tile_center = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	var tile_rect = Rect2(
		tile_center - Vector2(block_size, block_size) * 0.5 + Vector2(0.01, 0.01),
		Vector2(block_size - 0.02, block_size - 0.02)
	)

	for existing_grid_pos in world.blocks.keys():
		var block_type = str(world.blocks[existing_grid_pos].get("type", ""))
		if not block_occupies_collision_area(block_type):
			continue

		var existing_rect = get_block_collision_rect_for_grid(existing_grid_pos, block_type)
		if existing_rect.intersects(tile_rect, false):
			return existing_grid_pos

	return world.INVALID_GRID_POS


func does_rect_overlap_reserved_object(rect: Rect2, ignore_grid_pos: Vector2i = Vector2i(999999, 999999)) -> bool:
	if world == null:
		return false

	for existing_grid_pos in world.blocks.keys():
		if existing_grid_pos == ignore_grid_pos:
			continue

		var block_type = str(world.blocks[existing_grid_pos].get("type", ""))
		if not block_occupies_collision_area(block_type):
			continue

		var existing_rect = get_block_collision_rect_for_grid(existing_grid_pos, block_type)
		if existing_rect.intersects(rect, false):
			return true

	return false


func can_place_full_collision_area(grid_pos: Vector2i, block_type: String) -> bool:
	var collision_rect = get_block_collision_rect_for_grid(grid_pos, block_type)
	var occupied_positions = get_grid_positions_overlapping_rect(collision_rect)

	for check_pos in occupied_positions:
		if not world.is_grid_inside_world(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if world.blocks.has(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if world.has_planted_seed(check_pos):
			world.show_notification("Need enough empty space.")
			return false

		if world.is_block_inside_player(check_pos):
			world.show_notification("Need enough empty space.")
			return false

	if does_rect_overlap_reserved_object(collision_rect):
		world.show_notification("Need enough empty space.")
		return false

	return true


func remove_block_without_drop(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_node = world.blocks[grid_pos]["node"]

	if block_node != null and is_instance_valid(block_node):
		clear_block_animation(block_node)
		block_node.queue_free()

	world.blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	update_vertical_block_variants_around(grid_pos)


func replace_block_without_drop(grid_pos: Vector2i, block_type: String):
	if world.blocks.has(grid_pos):
		remove_block_without_drop(grid_pos)

	create_block(grid_pos, block_type)


func apply_background_block_style(block):
	if block == null:
		return
	var visual = block.get_node_or_null("Visual")
	if visual != null and visual is Sprite2D:
		visual.modulate = Color(1, 1, 1, 1)
		visual.z_index = -1


func create_block(grid_pos: Vector2i, block_type: String = "dirt"):
	block_type = normalize_legacy_block_id(block_type)
	if block_type == "":
		return

	if world.blocks.has(grid_pos):
		return

	var block = world.block_scene.instantiate()
	block.position = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	world.add_child(block)

	world.blocks[grid_pos] = {
		"node": block,
		"type": block_type,
		"entrance_locked": false,
		"sign_text": ""
	}
	authoritative_place_request_times.erase(get_authoritative_place_key("foreground", grid_pos, block_type))

	set_block_texture(block, block_type, grid_pos, false)
	configure_block_collision(block, block_type, grid_pos)

	if block_type == "wooden_entrance":
		world.update_wooden_entrance_visual(grid_pos)

	if block_type == "sign":
		world.update_sign_text_visual(grid_pos)

	if block_type == world.ENTRANCE_GATE_TYPE:
		world.update_entrance_gate_visual(grid_pos)

	world.block_hit_progress.erase(grid_pos)
	update_vertical_block_variants_around(grid_pos)


func refresh_all_block_collisions():
	if world == null:
		return

	if not "blocks" in world:
		return

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks[grid_pos]

		if not block_data.has("node") or not block_data.has("type"):
			continue

		var block_node = block_data["node"]

		if block_node != null and is_instance_valid(block_node):
			configure_block_collision(block_node, str(block_data["type"]), grid_pos)

	for grid_pos in background_blocks.keys():
		var block_data = background_blocks[grid_pos]

		if not block_data.has("node") or not block_data.has("type"):
			continue

		var block_node = block_data["node"]

		if block_node != null and is_instance_valid(block_node):
			configure_block_collision(block_node, str(block_data["type"]))


func set_block_texture(block, block_type: String, grid_pos: Vector2i = NO_VARIANT_GRID_POS, background := false):
	var visual = block.get_node_or_null("Visual")

	if visual == null:
		return

	clear_block_animation(block, visual)
	apply_block_visual_layout(visual, block_type)

	var variant_texture_path = get_visual_block_variant(block_type, grid_pos, background)
	if variant_texture_path != "":
		var variant_texture = get_cached_visual_variant_texture(variant_texture_path)
		if variant_texture != null:
			visual.texture = variant_texture
			return

	if world.block_textures.has(block_type):
		visual.texture = world.block_textures[block_type]

	if not is_triggered_springboard_animation_block(block_type):
		setup_block_animation(block, block_type, visual)


func is_triggered_springboard_animation_block(block_type: String) -> bool:
	if world == null or not world.item_database.has(block_type):
		return false

	var item_data = world.item_database[block_type]
	return bool(item_data.get("springboard", false)) and item_data.has("springboard_animation_frames")


func get_springboard_animation_frames(block_type: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if world == null or not world.item_database.has(block_type):
		return result

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("springboard_animation_frames", [])
	if not (frame_paths is Array):
		return result

	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			result.append(texture)

	return result


func play_springboard_block_animation(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	var block_type = str(block_data.get("type", ""))
	if not is_triggered_springboard_animation_block(block_type):
		return

	var block_node = block_data.get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if visual == null:
		return

	var frames = get_springboard_animation_frames(block_type)
	if frames.size() <= 1:
		return

	var item_data = world.item_database[block_type]
	var frame_seconds = max(0.10, float(item_data.get("springboard_animation_frame_seconds", 0.18)))
	springboard_active_visuals[visual.get_instance_id()] = {
		"visual": visual,
		"frames": frames,
		"frame_seconds": frame_seconds,
		"elapsed": 0.0,
		"frame_index": -1
	}
	apply_springboard_animation_frame(visual, frames, 0)


func update_springboard_animations(delta):
	for visual_id in springboard_active_visuals.keys():
		var entry = springboard_active_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			springboard_active_visuals.erase(visual_id)
			continue

		var frames = entry.get("frames", [])
		if not (frames is Array) or frames.size() <= 1:
			springboard_active_visuals.erase(visual_id)
			continue

		var elapsed = float(entry.get("elapsed", 0.0)) + delta
		var frame_seconds = max(0.10, float(entry.get("frame_seconds", 0.18)))
		var frame_index = int(floor(elapsed / frame_seconds))

		if frame_index >= frames.size():
			apply_springboard_animation_frame(visual, frames, 0)
			springboard_active_visuals.erase(visual_id)
			continue

		entry["elapsed"] = elapsed
		springboard_active_visuals[visual_id] = entry
		apply_springboard_animation_frame(visual, frames, frame_index)


func apply_springboard_animation_frame(visual: Sprite2D, frames: Array, frame_index: int):
	if visual == null or frames.size() == 0:
		return

	var safe_index = int(clamp(frame_index, 0, frames.size() - 1))
	if int(visual.get_meta("springboard_animation_frame_index", -1)) == safe_index:
		return

	visual.set_meta("springboard_animation_frame_index", safe_index)
	visual.texture = frames[safe_index]


func setup_block_animation(block, block_type: String, visual: Sprite2D):
	clear_block_animation(block, visual)

	if world == null or not world.item_database.has(block_type):
		return

	var item_data = world.item_database[block_type]
	var frame_paths = item_data.get("animation_frames", [])
	if not (frame_paths is Array) or frame_paths.size() <= 1:
		return

	var frames: Array[Texture2D] = []
	for frame_path in frame_paths:
		var texture = AtlasTextureFactory.load_texture(frame_path)
		if texture != null:
			frames.append(texture)

	if frames.size() <= 1:
		return

	visual.set_meta("animation_frames", frames)
	visual.set_meta("animation_frame_index", -1)

	var frame_seconds = max(0.08, float(item_data.get("animation_frame_seconds", 0.45)))
	animated_block_visuals[visual.get_instance_id()] = {
		"visual": visual,
		"frames": frames,
		"frame_seconds": frame_seconds
	}
	apply_synced_block_animation_frame(visual, frames, frame_seconds, true)


func update_synced_block_animations():
	for visual_id in animated_block_visuals.keys():
		var entry = animated_block_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			animated_block_visuals.erase(visual_id)
			continue

		var frames = entry.get("frames", [])
		if not (frames is Array) or frames.size() <= 1:
			animated_block_visuals.erase(visual_id)
			continue

		apply_synced_block_animation_frame(visual, frames, float(entry.get("frame_seconds", 0.45)))


func apply_synced_block_animation_frame(visual: Sprite2D, frames: Array, frame_seconds: float, force_update: bool = false):
	if visual == null or frames.size() <= 1:
		return

	var frame_msec = max(1, int(round(max(0.08, frame_seconds) * 1000.0)))
	var synced_index = int(floor(float(Time.get_ticks_msec()) / float(frame_msec))) % frames.size()
	if not force_update and int(visual.get_meta("animation_frame_index", -1)) == synced_index:
		return

	visual.set_meta("animation_frame_index", synced_index)
	visual.texture = frames[synced_index]


func get_wooden_entrance_frames() -> Array[Texture2D]:
	if not wooden_entrance_frame_cache.is_empty():
		return wooden_entrance_frame_cache

	var item_data = {}
	if world != null and world.item_database.has("wooden_entrance"):
		item_data = world.item_database["wooden_entrance"]

	var frame_paths = item_data.get("entrance_frames", [
		"res://Assets/blocks/Tier_1/wooden_entrance_1.png",
		"res://Assets/blocks/Tier_1/wooden_entrance_2.png",
		"res://Assets/blocks/Tier_1/wooden_entrance_3.png"
	])

	if frame_paths is Array:
		for frame_path in frame_paths:
			var texture = AtlasTextureFactory.load_texture(frame_path)
			if texture != null:
				wooden_entrance_frame_cache.append(texture)

	return wooden_entrance_frame_cache


func update_wooden_entrance_visual(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if visual == null:
		return

	var frames = get_wooden_entrance_frames()
	if not frames.is_empty():
		visual.texture = frames[0]

	visual.flip_h = false
	visual.modulate = Color(0.82, 0.88, 1.0, 1.0) if is_wooden_entrance_locked(grid_pos) else Color(1.0, 1.0, 1.0, 1.0)


func get_wooden_entrance_walk_direction(grid_pos: Vector2i, previous_grid_pos: Vector2i) -> int:
	if previous_grid_pos != NO_VARIANT_GRID_POS:
		if previous_grid_pos.x < grid_pos.x:
			return 1
		if previous_grid_pos.x > grid_pos.x:
			return -1

	if world != null and world.player != null and world.player is CharacterBody2D:
		if world.player.velocity.x < -1.0:
			return -1
		if world.player.velocity.x > 1.0:
			return 1

	if world != null and "player_facing_direction" in world:
		return -1 if int(world.player_facing_direction) < 0 else 1

	return 1


func play_wooden_entrance_pass_animation(grid_pos: Vector2i, walk_direction: int = 1):
	if world == null or not world.blocks.has(grid_pos):
		return

	var frames = get_wooden_entrance_frames()
	if frames.size() <= 1:
		return

	var block_node = world.blocks[grid_pos].get("node", null)
	if block_node == null or not is_instance_valid(block_node):
		return

	var visual = block_node.get_node_or_null("Visual")
	if visual == null:
		return

	var flip_h = walk_direction > 0
	visual.flip_h = flip_h
	wooden_entrance_active_visuals[visual.get_instance_id()] = {
		"grid_pos": grid_pos,
		"visual": visual,
		"frames": frames,
		"elapsed": 0.0,
		"frame_index": -1,
		"flip_h": flip_h
	}


func reset_wooden_entrance_pass_animation(grid_pos: Vector2i):
	for visual_id in wooden_entrance_active_visuals.keys():
		var entry = wooden_entrance_active_visuals[visual_id]
		if entry.get("grid_pos", NO_VARIANT_GRID_POS) == grid_pos:
			wooden_entrance_active_visuals.erase(visual_id)

	update_wooden_entrance_visual(grid_pos)


func update_wooden_entrance_animations(delta: float):
	for visual_id in wooden_entrance_active_visuals.keys():
		var entry = wooden_entrance_active_visuals[visual_id]
		var visual = entry.get("visual", null)
		if visual == null or not is_instance_valid(visual):
			wooden_entrance_active_visuals.erase(visual_id)
			continue

		var frames = entry.get("frames", [])
		if not (frames is Array) or frames.is_empty():
			wooden_entrance_active_visuals.erase(visual_id)
			continue

		var elapsed = float(entry.get("elapsed", 0.0)) + delta
		var frame_index = int(floor(elapsed / WOODEN_ENTRANCE_FRAME_SECONDS))

		if frame_index >= frames.size():
			frame_index = frames.size() - 1
			elapsed = WOODEN_ENTRANCE_FRAME_SECONDS * float(frames.size())

		var flip_h = bool(entry.get("flip_h", false))
		if visual.flip_h != flip_h:
			visual.flip_h = flip_h

		if frame_index != int(entry.get("frame_index", -1)) or visual.texture != frames[frame_index]:
			visual.texture = frames[frame_index]
			entry["frame_index"] = frame_index

		entry["elapsed"] = elapsed
		wooden_entrance_active_visuals[visual_id] = entry


func update_wooden_entrance_crossing():
	if world == null or world.player == null:
		if last_wooden_entrance_grid != NO_VARIANT_GRID_POS and is_wooden_entrance_at(last_wooden_entrance_grid):
			reset_wooden_entrance_pass_animation(last_wooden_entrance_grid)
		last_wooden_entrance_grid = NO_VARIANT_GRID_POS
		return

	var grid_pos = world.get_player_grid_position()
	if grid_pos == last_wooden_entrance_grid:
		return

	var previous_grid_pos = last_wooden_entrance_grid
	last_wooden_entrance_grid = grid_pos

	if previous_grid_pos != NO_VARIANT_GRID_POS and is_wooden_entrance_at(previous_grid_pos):
		reset_wooden_entrance_pass_animation(previous_grid_pos)

	if not is_wooden_entrance_at(grid_pos):
		return

	if not should_disable_wooden_entrance_collision(grid_pos):
		return

	play_wooden_entrance_pass_animation(grid_pos, get_wooden_entrance_walk_direction(grid_pos, previous_grid_pos))


func configure_block_collision(block, block_type: String, grid_pos: Vector2i = NO_VARIANT_GRID_POS):
	remove_wood_platform_collision(block)
	apply_original_collision_layout(block, block_type)
	if grid_pos == NO_VARIANT_GRID_POS:
		grid_pos = get_grid_pos_for_block_node(block)

	if block_type == "wood_platform":
		set_original_block_collision_disabled(block, true)
		add_wood_platform_collision(block)
	elif block_type == "wooden_entrance":
		set_original_block_collision_disabled(block, should_disable_wooden_entrance_collision(grid_pos))
	elif block_type == "sign":
		set_original_block_collision_disabled(block, true)
	elif is_background_block_type(block_type):
		set_original_block_collision_disabled(block, true)
	elif is_non_collideable_block(block_type):
		set_original_block_collision_disabled(block, true)
	else:
		set_original_block_collision_disabled(block, false)


func set_original_block_collision_disabled(node, disabled: bool):
	if node == null:
		return

	for child in node.get_children():
		if child.name.begins_with("WoodPlatform"):
			continue

		if child is CollisionShape2D:
			child.disabled = disabled

		set_original_block_collision_disabled(child, disabled)


func remove_wood_platform_collision(node):
	if node == null:
		return

	for child in node.get_children():
		if child.name.begins_with("WoodPlatform"):
			child.queue_free()
		else:
			remove_wood_platform_collision(child)


func get_block_collision_body(node):
	if node == null:
		return null

	if node is CollisionObject2D:
		return node

	for child in node.get_children():
		var found = get_block_collision_body(child)

		if found != null:
			return found

	return null


func add_wood_platform_collision(block):
	var collision_body = get_block_collision_body(block)

	if collision_body == null:
		return

	var top_shape = RectangleShape2D.new()
	top_shape.size = Vector2(world.BLOCK_SIZE, 6)

	var top_collision = CollisionShape2D.new()
	top_collision.name = "WoodPlatformTopCollision"
	top_collision.shape = top_shape
	top_collision.position = Vector2(0, -13)
	top_collision.one_way_collision = true
	top_collision.one_way_collision_margin = 8.0
	collision_body.add_child(top_collision)


func break_block_at_mouse():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_shop_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	var clicked_seed_grid = world.get_clicked_planted_seed_grid()

	if clicked_seed_grid != world.INVALID_GRID_POS:
		if not world.can_reach_grid(clicked_seed_grid):
			return

		if world.has_method("can_current_player_build") and not world.can_current_player_build():
			world.show_notification("This world is locked.")
			return

		if world.selected_item_category == "seed":
			world.try_splice_seed_tree(clicked_seed_grid)
			return

		world.harvest_planted_seed(clicked_seed_grid)
		return

	var grid_pos = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var anchor_grid_pos = get_anchor_grid_for_block_area(grid_pos)

	if anchor_grid_pos != world.INVALID_GRID_POS:
		hit_block_grid(anchor_grid_pos)
		return

	if background_blocks.has(grid_pos):
		hit_background_block_grid(grid_pos)
		return


func update_block_damage_recovery(delta):
	var positions_to_reset = []

	for grid_pos in world.block_hit_timers.keys():
		if not world.blocks.has(grid_pos) and not background_blocks.has(grid_pos):
			positions_to_reset.append(grid_pos)
			continue

		var time_left = float(world.block_hit_timers.get(grid_pos, 0.0)) - delta
		world.block_hit_timers[grid_pos] = time_left

		if time_left <= 0.0:
			positions_to_reset.append(grid_pos)

	for grid_pos in positions_to_reset:
		world.block_hit_timers.erase(grid_pos)
		world.block_hit_progress.erase(grid_pos)
		authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
		authoritative_break_request_keys.erase(get_authoritative_break_key("background", grid_pos))
		update_block_crack_visual(grid_pos)
		update_background_block_crack_visual(grid_pos)


func hit_block_grid(grid_pos: Vector2i):
	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return

	if not world.blocks.has(grid_pos):
		return

	var block_type = world.blocks[grid_pos]["type"]

	if world.has_method("can_current_player_break_block") and not world.can_current_player_break_block(str(block_type)):
		if str(block_type) == "world_lock":
			if world.world_lock_manager != null and world.world_lock_manager.has_method("has_world_lock_break_blockers") and world.world_lock_manager.has_world_lock_break_blockers():
				world.show_notification("Remove all Safes, vending machines, and Fish Mongers before breaking the World Lock.")
			else:
				world.show_notification("Only the world owner can break the World Lock.")
		elif str(block_type) == "fish_monger":
			world.show_notification("Only the world owner or players with access can break the Fish Monger.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_vending_machine_block") and world.world_lock_manager.is_vending_machine_block(str(block_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can break vending machines.")
			else:
				world.show_notification("Lock this world before breaking vending machines.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_safe_block") and world.world_lock_manager.is_safe_block(str(block_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can break safes.")
			else:
				world.show_notification("Lock this world before breaking safes.")
		else:
			world.show_notification("This world is locked.")
		return

	if block_type == "bedrock":
		world.show_notification("Bedrock cannot be broken.")
		return

	if world.is_entrance_gate_block(block_type):
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if world.item_database.has(block_type) and bool(world.item_database[block_type].get("unbreakable", false)):
		world.show_notification(world.get_item_display_name(block_type, "block") + " cannot be broken.")
		return

	var max_hits = get_block_max_hits(block_type)
	var hit_power = world.get_current_break_power(block_type)
	var current_hits = int(world.block_hit_progress.get(grid_pos, 0)) + hit_power
	world.block_hit_progress[grid_pos] = current_hits
	world.block_hit_timers[grid_pos] = world.BLOCK_DAMAGE_RESET_DELAY

	if should_use_server_authoritative_world_actions():
		var action = "hit" if current_hits < max_hits else "break"
		var break_key = get_authoritative_break_key("foreground", grid_pos)
		if action == "break" and authoritative_break_request_keys.has(break_key):
			world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
			return
		if send_network_block_update(action, "foreground", grid_pos, str(block_type), {
			"hit_power": hit_power,
			"hit_count": current_hits,
			"max_hits": max_hits
		}):
			if action == "break":
				authoritative_break_request_keys[break_key] = true
			update_block_crack_visual(grid_pos)
			if world.has_method("play_sound_punch"): world.play_sound_punch()
			if current_hits < max_hits:
				world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
			else:
				world.show_notification("Breaking " + world.get_item_display_name(block_type, "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if current_hits < max_hits:
		send_network_block_update("hit", "foreground", grid_pos, str(block_type))
		update_block_crack_visual(grid_pos)
		world.show_notification("Hit " + world.get_item_display_name(block_type, "block") + " " + str(current_hits) + "/" + str(max_hits))
		if world.has_method("play_sound_punch"): world.play_sound_punch()
		return

	if world.has_method("play_sound_punch"): world.play_sound_punch()
	break_block_grid(grid_pos)


func break_block_grid(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_type = world.blocks[grid_pos]["type"]

	if world.is_crafting_station_block(block_type):
		world.break_crafting_station(grid_pos)
		return

	var block_node = world.blocks[grid_pos]["node"]
	var drop_position = block_node.global_position

	if should_use_server_authoritative_world_actions() and not is_applying_network_world_update():
		if send_network_block_update("break", "foreground", grid_pos, str(block_type)):
			authoritative_break_request_keys[get_authoritative_break_key("foreground", grid_pos)] = true
			world.show_notification("Breaking " + world.get_item_display_name(str(block_type), "block") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	var crack_overlay = block_node.get_node_or_null("CrackOverlay")
	if crack_overlay != null:
		crack_overlay.queue_free()

	clear_block_animation(block_node)
	block_node.queue_free()
	world.blocks.erase(grid_pos)
	authoritative_break_request_keys.erase(get_authoritative_break_key("foreground", grid_pos))
	world.block_hit_progress.erase(grid_pos)
	world.block_hit_timers.erase(grid_pos)
	update_vertical_block_variants_around(grid_pos)

	if str(block_type) == "world_lock" and world.has_method("on_world_lock_block_broken"):
		world.on_world_lock_block_broken(grid_pos)

	send_network_block_update("break", "foreground", grid_pos, str(block_type))

	if not should_server_create_break_drops():
		world.try_drop_block(block_type, drop_position)
		world.try_drop_seed(block_type, drop_position)
		world.try_drop_gems(block_type, drop_position)


func punch_facing_block():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_shop_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if world.player == null:
		return

	var player_grid_pos = world.get_player_grid_position()
	var target_grid_pos = Vector2i(
		player_grid_pos.x + world.player_facing_direction,
		player_grid_pos.y
	)

	punch_grid_position(target_grid_pos)


func punch_grid_position(grid_pos: Vector2i):
	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_planted_seed(grid_pos):
		if world.has_method("can_current_player_build") and not world.can_current_player_build():
			world.show_notification("This world is locked.")
			return

		world.harvest_planted_seed(grid_pos)
		return

	var anchor_grid_pos = get_anchor_grid_for_block_area(grid_pos)

	if anchor_grid_pos != world.INVALID_GRID_POS:
		hit_block_grid(anchor_grid_pos)
		return

	if background_blocks.has(grid_pos):
		hit_background_block_grid(grid_pos)
		return


func punch_at_mouse():
	if world.is_chat_input_focused():
		return

	var old_item_type = world.selected_item_type
	var old_item_category = world.selected_item_category

	world.selected_item_type = "punch"
	world.selected_item_category = "tool"

	break_block_at_mouse()

	world.selected_item_type = old_item_type
	world.selected_item_category = old_item_category

	world.update_all_ui()


func place_block_at_mouse():
	if is_waiting_for_server_sign_on():
		show_server_sign_on_notice()
		return

	if world.selected_item_type == "crafting_station":
		world.place_crafting_station_at_mouse()
		return

	if not world.inventory.has(world.selected_item_type):
		return

	if world.inventory[world.selected_item_type] <= 0:
		world.show_notification("You don't have any " + world.get_item_display_name(world.selected_item_type, world.selected_item_category) + ".")
		return

	var grid_pos = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if block_requires_world_lock(world.selected_item_type) and not world_has_world_lock():
		world.show_notification("You need a World Lock in this world before placing a Fish Monger.")
		return

	if world.selected_item_type == "world_lock" and world.world_lock_manager != null:
		var already_has_lock := bool(world.world_lock_manager.is_locked)
		if world.world_lock_manager.has_method("has_world_lock_block"):
			already_has_lock = already_has_lock or bool(world.world_lock_manager.has_world_lock_block())
		if already_has_lock:
			world.show_notification("This world already has a World Lock.")
			return

	if world.has_method("can_current_player_place_block") and not world.can_current_player_place_block(str(world.selected_item_type)):
		if world.world_lock_manager != null and world.world_lock_manager.has_method("is_vending_machine_block") and world.world_lock_manager.is_vending_machine_block(str(world.selected_item_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can place vending machines.")
			else:
				world.show_notification("Lock this world before placing vending machines.")
		elif world.world_lock_manager != null and world.world_lock_manager.has_method("is_safe_block") and world.world_lock_manager.is_safe_block(str(world.selected_item_type)):
			if world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can place safes.")
			else:
				world.show_notification("Lock this world before placing safes.")
		else:
			world.show_notification("This world is locked.")
		return

	if world.has_method("can_current_player_build") and not world.can_current_player_build():
		world.show_notification("This world is locked.")
		return

	if is_background_block_type(world.selected_item_type):
		if not can_place_background_block_here(grid_pos):
			return

		if should_use_server_authoritative_world_actions():
			var background_place_key = get_authoritative_place_key("background", grid_pos, world.selected_item_type)
			if has_recent_authoritative_place_request(background_place_key):
				world.show_notification("Placing " + world.get_item_display_name(world.selected_item_type, world.selected_item_category) + "...")
				return
			if send_network_block_update("place", "background", grid_pos, world.selected_item_type):
				mark_authoritative_place_request(background_place_key)
				world.show_notification("Placing " + world.get_item_display_name(world.selected_item_type, world.selected_item_category) + "...")
			else:
				world.show_notification("Almost ready. Try again in a moment.")
			return

		create_background_block(grid_pos, world.selected_item_type)
		send_network_block_update("place", "background", grid_pos, world.selected_item_type)
		world.inventory[world.selected_item_type] -= 1
		if world.has_method("play_sound_place"): world.play_sound_place()
		world.update_all_ui()
		return

	if not can_place_block_here(grid_pos):
		return

	if should_use_server_authoritative_world_actions():
		var foreground_place_key = get_authoritative_place_key("foreground", grid_pos, world.selected_item_type)
		if has_recent_authoritative_place_request(foreground_place_key):
			world.show_notification("Placing " + world.get_item_display_name(world.selected_item_type, world.selected_item_category) + "...")
			return
		if send_network_block_update("place", "foreground", grid_pos, world.selected_item_type):
			mark_authoritative_place_request(foreground_place_key)
			world.show_notification("Placing " + world.get_item_display_name(world.selected_item_type, world.selected_item_category) + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	create_block(grid_pos, world.selected_item_type)
	send_network_block_update("place", "foreground", grid_pos, world.selected_item_type)

	if world.selected_item_type == "world_lock" and world.has_method("on_world_lock_block_placed"):
		world.on_world_lock_block_placed(grid_pos)

	world.inventory[world.selected_item_type] -= 1
	if world.has_method("play_sound_place"): world.play_sound_place()
	world.update_all_ui()


func can_place_block_here(grid_pos: Vector2i) -> bool:
	var block_type = str(world.selected_item_type)

	if world.blocks.has(grid_pos):
		return false

	if world.has_planted_seed(grid_pos):
		return false

	if world.is_block_inside_player(grid_pos):
		return false

	var proposed_rect = get_block_collision_rect_for_grid(grid_pos, block_type)
	if does_rect_overlap_reserved_object(proposed_rect):
		return false

	if block_requires_full_area_clear(block_type):
		return can_place_full_collision_area(grid_pos, block_type)

	return true


func is_lava_block(grid_pos: Vector2i) -> bool:
	if not world.blocks.has(grid_pos):
		return false

	return world.blocks[grid_pos]["type"] == "lava"
