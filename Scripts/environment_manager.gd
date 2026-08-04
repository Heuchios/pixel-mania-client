extends Node

var world = null


func setup(world_ref):
	world = world_ref


func is_entrance_gate_block(block_type: String) -> bool:
	return block_type == world.ENTRANCE_GATE_TYPE

func get_entrance_gate_center_x() -> int:
	return int(floor(float(world.WORLD_WIDTH) * 0.5))

func is_entrance_surface_candidate(block_type: String) -> bool:
	if block_type in [world.ENTRANCE_GATE_TYPE, "world_lock", "super_world_lock", "bedrock"]:
		return false

	if world.item_database.has(block_type) and bool(world.item_database[block_type].get("no_collision", false)):
		return false

	return block_type != ""

func get_existing_entrance_surface_y(gate_x: int) -> int:
	var best_surface_y = -1
	var best_distance = world.WORLD_WIDTH + 1
	var min_x = max(0, gate_x - world.ENTRANCE_GATE_CLEAR_RADIUS)
	var max_x = min(world.WORLD_WIDTH - 1, gate_x + world.ENTRANCE_GATE_CLEAR_RADIUS)

	for x in range(min_x, max_x + 1):
		for y in range(0, world.BEDROCK_START_Y):
			var grid_pos = Vector2i(x, y)
			if not world.blocks.has(grid_pos):
				continue

			var block_type = str(world.blocks[grid_pos].get("type", ""))
			if not is_entrance_surface_candidate(block_type):
				continue

			var distance = abs(x - gate_x)
			if best_surface_y == -1 or distance < best_distance or (distance == best_distance and y < best_surface_y):
				best_surface_y = y
				best_distance = distance
			break

	return best_surface_y

func get_default_entrance_gate_surface_y() -> int:
	var gate_x = get_entrance_gate_center_x()

	if world.terrain_surface_y.has(gate_x):
		return int(world.terrain_surface_y[gate_x])

	var existing_surface_y = get_existing_entrance_surface_y(gate_x)
	if existing_surface_y >= 0:
		return existing_surface_y

	if world.world_generation_manager != null:
		if world.world_generation_manager.has_method("prepare_generation_rng"):
			world.world_generation_manager.prepare_generation_rng()
		if world.world_generation_manager.has_method("generate_terrain_surface"):
			world.world_generation_manager.generate_terrain_surface()

	if world.terrain_surface_y.has(gate_x):
		return int(world.terrain_surface_y[gate_x])

	return world.get_surface_y_at_x(gate_x)

func get_default_entrance_gate_grid_position() -> Vector2i:
	var gate_x = get_entrance_gate_center_x()
	var surface_y = get_default_entrance_gate_surface_y()

	# surface_y is the first solid terrain row. The gate lives in the walkable
	# cell above it so the player can stand on the support and enter the gate.
	return Vector2i(gate_x, surface_y - 1)

func get_generated_entrance_gate_grid_position() -> Vector2i:
	var default_gate_pos = get_default_entrance_gate_grid_position()
	return Vector2i(default_gate_pos.x, default_gate_pos.y + 1)

func find_entrance_gate_grid() -> Vector2i:
	for grid_pos in world.blocks.keys():
		if str(world.blocks[grid_pos].get("type", "")) == world.ENTRANCE_GATE_TYPE:
			return grid_pos

	return world.INVALID_GRID_POS

func get_entrance_gate_grid_position() -> Vector2i:
	var existing_gate = find_entrance_gate_grid()

	if existing_gate != world.INVALID_GRID_POS:
		return existing_gate

	return get_default_entrance_gate_grid_position()

func get_entrance_gate_near_grid(grid_pos: Vector2i) -> Vector2i:
	var gate_pos = find_entrance_gate_grid()

	if gate_pos == world.INVALID_GRID_POS:
		return world.INVALID_GRID_POS

	# Entrance Gate interaction is limited to its own single block tile only.
	if grid_pos == gate_pos:
		return gate_pos

	return world.INVALID_GRID_POS

func reject_entrance_gate_target(message: String, show_message: bool) -> bool:
	if show_message:
		world.show_notification(message)
	return false

func is_protected_entrance_gate_support_block(block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false

	if clean_type in ["world_lock", "super_world_lock", "safe", "fish_monger", "crafting_station", "furnace"]:
		return true

	var protected_methods: Array[String] = [
		"is_vending_machine_block_type",
		"is_display_block_type",
		"is_mailbox_block_type",
		"is_wooden_entrance_block",
		"is_door_block",
		"is_sign_block",
		"is_toggle_block",
		"is_bulletin_board_block_type",
		"is_tackle_box_block_type",
		"is_chicken_block_type",
		"is_cow_block_type",
		"is_duck_block_type",
		"is_water_well_block_type",
		"is_dice_block_type",
		"is_anti_punch_block_type",
		"is_anti_talk_block_type",
		"is_anti_gravity_block_type",
		"is_theme_machine_block_type",
		"is_oil_refinery_block_type",
		"is_battery_charger_block_type"
	]
	for method_name in protected_methods:
		if world.has_method(method_name) and bool(world.call(method_name, clean_type)):
			return true

	return false

func can_replace_entrance_gate_support_at(under_pos: Vector2i, show_message: bool = true) -> bool:
	if not world.is_grid_inside_world(under_pos):
		return reject_entrance_gate_target("Not enough space under the gate.", show_message)

	if world.has_planted_seed(under_pos):
		return reject_entrance_gate_target("A seed is under the gate spot.", show_message)

	if not world.blocks.has(under_pos):
		return true

	var under_block_data: Variant = world.blocks[under_pos]
	if not (under_block_data is Dictionary):
		return true

	var under_block: Dictionary = under_block_data
	var under_type := str(under_block.get("type", "")).strip_edges()

	if under_type == world.ENTRANCE_GATE_TYPE or is_protected_entrance_gate_support_block(under_type):
		return reject_entrance_gate_target("A protected block is under that spot.", show_message)

	if world.item_database.has(under_type):
		var raw_under_item_data: Variant = world.item_database[under_type]
		if raw_under_item_data is Dictionary:
			var under_item_data: Dictionary = raw_under_item_data
			if bool(under_item_data.get("unbreakable", false)) and under_type != "bedrock":
				return reject_entrance_gate_target("Unbreakable block under gate spot.", show_message)

	return true

func resolve_entrance_mover_target_grid(clicked_grid: Vector2i) -> Vector2i:
	if can_place_entrance_gate_at(clicked_grid, false):
		return clicked_grid

	if not world.blocks.has(clicked_grid):
		return clicked_grid

	var gate_above_support := Vector2i(clicked_grid.x, clicked_grid.y - 1)
	if can_place_entrance_gate_at(gate_above_support, false):
		return gate_above_support

	return clicked_grid

func use_entrance_mover_at_mouse():
	if not world.tool_inventory.has("entrance_mover") or int(world.tool_inventory["entrance_mover"]) <= 0:
		world.show_notification("You do not have an Entrance Mover.")
		return

	var clicked_grid = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(clicked_grid):
		world.show_notification("Outside world bounds.")
		return

	var target_grid = resolve_entrance_mover_target_grid(clicked_grid)

	if not world.can_reach_grid(target_grid):
		world.show_notification("Too far away.")
		return

	if should_request_server_entrance_gate_move():
		if can_place_entrance_gate_at(target_grid):
			request_server_entrance_gate_move(target_grid)
		return

	if move_entrance_gate_to(target_grid):
		world.tool_inventory["entrance_mover"] = max(0, int(world.tool_inventory["entrance_mover"]) - 1)

		if int(world.tool_inventory["entrance_mover"]) <= 0 and world.selected_item_type == "entrance_mover":
			world.selected_item_type = world.primary_hotbar_tool
			world.selected_item_category = "tool"

		world.update_all_ui()

func should_request_server_entrance_gate_move() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func request_server_entrance_gate_move(new_gate_pos: Vector2i) -> bool:
	var old_gate_pos = find_entrance_gate_grid()
	if old_gate_pos == world.INVALID_GRID_POS:
		world.show_notification("Entrance Gate missing.")
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return false

	if not bool(network.send_world_interaction_update({
		"action": "entrance_gate_move",
		"old_x": old_gate_pos.x,
		"old_y": old_gate_pos.y,
		"x": new_gate_pos.x,
		"y": new_gate_pos.y
	}, world.current_world_name)):
		world.show_notification("Almost ready. Try again in a moment.")
		return false

	world.show_notification("Moving Entrance Gate...")
	return true

func move_entrance_gate_to(new_gate_pos: Vector2i) -> bool:
	var old_gate_pos = find_entrance_gate_grid()

	if old_gate_pos == world.INVALID_GRID_POS:
		world.show_notification("Entrance Gate missing.")
		return false

	if new_gate_pos == old_gate_pos:
		world.show_notification("Entrance Gate is already here.")
		return false

	if not can_place_entrance_gate_at(new_gate_pos):
		return false

	# Remove old gate and any legacy bedrock support platform.
	world.remove_block_without_drop(old_gate_pos)
	remove_old_entrance_gate_bedrock(old_gate_pos)

	# Place the new single-tile bedrock support and new gate.
	ensure_entrance_gate_bedrock(new_gate_pos)
	world.create_block(new_gate_pos, world.ENTRANCE_GATE_TYPE)
	update_entrance_gate_visual(new_gate_pos)

	world.show_notification("Entrance Gate moved.")
	world.save_world()
	return true

func can_place_entrance_gate_at(gate_pos: Vector2i, show_message: bool = true) -> bool:
	if not world.is_grid_inside_world(gate_pos):
		return reject_entrance_gate_target("Outside world bounds.", show_message)

	if gate_pos.y <= 3 or gate_pos.y + 1 >= world.BEDROCK_START_Y:
		return reject_entrance_gate_target("Not enough space for the Entrance Gate.", show_message)

	if world.blocks.has(gate_pos):
		return reject_entrance_gate_target("That spot is blocked.", show_message)

	if world.has_planted_seed(gate_pos):
		return reject_entrance_gate_target("A seed is blocking that spot.", show_message)

	if world.is_block_inside_player(gate_pos):
		return reject_entrance_gate_target("Move away from that spot first.", show_message)

	if is_gate_area_inside_player(gate_pos):
		return reject_entrance_gate_target("Move away from the new gate area first.", show_message)

	for x in range(gate_pos.x - 1, gate_pos.x + 2):
		var walking_pos = Vector2i(x, gate_pos.y)
		if walking_pos == gate_pos:
			continue

		if not world.is_grid_inside_world(walking_pos):
			return reject_entrance_gate_target("Not enough walking space around the gate.", show_message)

		if world.blocks.has(walking_pos) or world.has_planted_seed(walking_pos):
			return reject_entrance_gate_target("Clear the walking space beside the gate first.", show_message)

	# Do not overwrite special player-built/interactive blocks under the new gate.
	var under_pos = Vector2i(gate_pos.x, gate_pos.y + 1)
	if not can_replace_entrance_gate_support_at(under_pos, show_message):
		return false

	return true

func is_gate_area_inside_player(gate_pos: Vector2i) -> bool:
	for check_pos in [gate_pos, Vector2i(gate_pos.x, gate_pos.y + 1)]:
		if world.is_block_inside_player(check_pos):
			return true

	return false

func remove_old_entrance_gate_bedrock(gate_pos: Vector2i):
	# Remove the center support plus old side supports from worlds saved before the 32x32 gate.
	for x in range(gate_pos.x - 1, gate_pos.x + 2):
		var bedrock_pos = Vector2i(x, gate_pos.y + 1)
		var block_data = world.blocks.get(bedrock_pos, {})
		if not world.blocks.has(bedrock_pos) or (block_data is Dictionary and str(block_data.get("type", "")) == "bedrock"):
			world.remove_block_without_drop(bedrock_pos)

func is_player_standing_on_entrance_gate() -> bool:
	var gate_pos = find_entrance_gate_grid()

	if gate_pos == world.INVALID_GRID_POS:
		return false

	var player_grid_pos = world.get_player_grid_position()
	return player_grid_pos == gate_pos

func can_use_entrance_gate() -> bool:
	if not is_player_standing_on_entrance_gate():
		world.show_notification("Stand on the Entrance Gate to exit.")
		return false

	return true

func ensure_entrance_gate_bedrock(gate_pos: Vector2i):
	var bedrock_pos = Vector2i(gate_pos.x, gate_pos.y + 1)

	if world.is_grid_inside_world(bedrock_pos):
		world.replace_block_without_drop(bedrock_pos, "bedrock")

func cleanup_legacy_entrance_gate_bedrock(gate_pos: Vector2i):
	for x in [gate_pos.x - 1, gate_pos.x + 1]:
		var bedrock_pos = Vector2i(x, gate_pos.y + 1)

		if world.blocks.has(bedrock_pos) and str(world.blocks[bedrock_pos].get("type", "")) == "bedrock":
			world.remove_block_without_drop(bedrock_pos)

func get_entrance_gate_spawn_position() -> Vector2:
	var gate_pos = get_entrance_gate_grid_position()
	return Vector2(gate_pos.x * world.BLOCK_SIZE, gate_pos.y * world.BLOCK_SIZE)

func get_clear_entrance_spawn_grid(gate_pos: Vector2i) -> Vector2i:
	return gate_pos

func ensure_generated_entrance_gate():
	ensure_entrance_gate(true)

func ensure_entrance_gate(use_generated_lower_layout: bool = false):
	var existing_gate = find_entrance_gate_grid()

	if existing_gate != world.INVALID_GRID_POS:
		ensure_entrance_gate_bedrock(existing_gate)
		cleanup_legacy_entrance_gate_bedrock(existing_gate)
		update_entrance_gate_visual(existing_gate)
		return

	var gate_x = get_entrance_gate_center_x()
	var surface_y = get_default_entrance_gate_surface_y()

	# Clear the center area so every world has a safe entrance zone.
	for x in range(gate_x - world.ENTRANCE_GATE_CLEAR_RADIUS, gate_x + world.ENTRANCE_GATE_CLEAR_RADIUS + 1):
		if x < 1 or x >= world.WORLD_WIDTH - 1:
			continue

		for y in range(surface_y - 5, surface_y):
			world.remove_block_without_drop(Vector2i(x, y))

		world.replace_block_without_drop(Vector2i(x, surface_y), "grass")

		for y in range(surface_y + 1, min(surface_y + 4, world.BEDROCK_START_Y)):
			world.replace_block_without_drop(Vector2i(x, y), "dirt")

	var gate_pos = (
		get_generated_entrance_gate_grid_position()
		if use_generated_lower_layout
		else get_default_entrance_gate_grid_position()
	)
	ensure_entrance_gate_bedrock(gate_pos)
	cleanup_legacy_entrance_gate_bedrock(gate_pos)
	world.replace_block_without_drop(gate_pos, world.ENTRANCE_GATE_TYPE)
	update_entrance_gate_visual(gate_pos)

func update_entrance_gate_visual(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_data = world.blocks[grid_pos]
	if not (block_data is Dictionary):
		return

	var block_node = block_data.get("node", null)

	if block_node == null:
		return

	var visual = block_node.get_node_or_null("Visual")

	if visual == null:
		return

	# The entrance gate is a 32x32 tile, so no tall-sprite lift is needed.
	visual.position = Vector2.ZERO
	visual.z_index = 25
	block_node.z_index = 25
	if world.block_manager != null and world.block_manager.has_method("setup_block_animation"):
		world.block_manager.setup_block_animation(block_node, world.ENTRANCE_GATE_TYPE, visual)

func exit_world_from_entrance_gate():
	world.show_notification("Leaving world...")
	if world.has_method("exit_to_world_menu"):
		world.exit_to_world_menu()
	else:
		world.exit_to_main_menu(true)

func setup_water_animation():
	if world.water_frames == null:
		world.water_frames = []

	world.water_frames.clear()

	var frame_paths = [
		"res://Assets/blocks/Tier_1/basic blocks/water_0.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_1.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_2.png",
		"res://Assets/blocks/Tier_1/basic blocks/water_3.png"
	]

	for path in frame_paths:
		if ResourceLoader.exists(path):
			world.water_frames.append(load(path))

	if world.water_frames.size() > 0:
		world.block_textures["water"] = world.water_frames[0]

func update_water_animation(delta):
	# Water now uses layered block textures: the surface stays water_0 and
	# tiles below water become water_block_2. A global animation pass would
	# overwrite that layering, so block_manager owns water visuals.
	if world == null:
		return

	if world.block_manager != null and world.block_manager.has_method("get_visual_block_variant"):
		return

	if world.water_frames == null:
		setup_water_animation()
		return

	if world.water_frames.size() == 0:
		setup_water_animation()

		if world.water_frames.size() == 0:
			return

	world.water_anim_timer += delta

	if world.water_anim_timer < world.WATER_ANIMATION_SPEED:
		return

	world.water_anim_timer = 0.0
	world.water_anim_index = (world.water_anim_index + 1) % world.water_frames.size()
	var current_water_texture = world.water_frames[world.water_anim_index]

	for grid_pos in world.blocks.keys():
		if str(world.blocks[grid_pos].get("type", "")) != "water":
			continue

		var block_data = world.blocks[grid_pos]
		if not (block_data is Dictionary):
			continue

		var block_node = block_data.get("node", null)

		if block_node == null or not is_instance_valid(block_node):
			continue

		var visual = block_node.get_node_or_null("Visual")

		if visual != null:
			visual.texture = current_water_texture
