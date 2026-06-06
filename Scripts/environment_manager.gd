extends Node

var world = null


func setup(world_ref):
	world = world_ref


func is_entrance_gate_block(block_type: String) -> bool:
	return block_type == world.ENTRANCE_GATE_TYPE

func get_entrance_gate_center_x() -> int:
	return int(floor(float(world.WORLD_WIDTH) * 0.5))

func find_entrance_gate_grid() -> Vector2i:
	for grid_pos in world.blocks.keys():
		if str(world.blocks[grid_pos].get("type", "")) == world.ENTRANCE_GATE_TYPE:
			return grid_pos

	return world.INVALID_GRID_POS

func get_entrance_gate_grid_position() -> Vector2i:
	var existing_gate = find_entrance_gate_grid()

	if existing_gate != world.INVALID_GRID_POS:
		return existing_gate

	var gate_x = get_entrance_gate_center_x()
	var surface_y = world.get_surface_y_at_x(gate_x)

	# Keep the gate on the same layer as the local surface block.
	return Vector2i(gate_x, surface_y)

func get_entrance_gate_near_grid(grid_pos: Vector2i) -> Vector2i:
	var gate_pos = find_entrance_gate_grid()

	if gate_pos == world.INVALID_GRID_POS:
		return world.INVALID_GRID_POS

	# Entrance Gate interaction is limited to its own single block tile only.
	if grid_pos == gate_pos:
		return gate_pos

	return world.INVALID_GRID_POS

func use_entrance_mover_at_mouse():
	if not world.tool_inventory.has("entrance_mover") or int(world.tool_inventory["entrance_mover"]) <= 0:
		world.show_notification("You do not have an Entrance Mover.")
		return

	var target_grid = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(target_grid):
		world.show_notification("Outside world bounds.")
		return

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

func can_place_entrance_gate_at(gate_pos: Vector2i) -> bool:
	if not world.is_grid_inside_world(gate_pos):
		world.show_notification("Outside world bounds.")
		return false

	if gate_pos.y <= 3 or gate_pos.y + 1 >= world.BEDROCK_START_Y:
		world.show_notification("Not enough space for the Entrance Gate.")
		return false

	if world.blocks.has(gate_pos):
		world.show_notification("That spot is blocked.")
		return false

	if world.has_planted_seed(gate_pos):
		world.show_notification("A seed is blocking that spot.")
		return false

	if world.is_block_inside_player(gate_pos):
		world.show_notification("Move away from that spot first.")
		return false

	if is_gate_area_inside_player(gate_pos):
		world.show_notification("Move away from the new gate area first.")
		return false

	for x in range(gate_pos.x - 1, gate_pos.x + 2):
		var walking_pos = Vector2i(x, gate_pos.y)
		if walking_pos == gate_pos:
			continue

		if not world.is_grid_inside_world(walking_pos):
			world.show_notification("Not enough walking space around the gate.")
			return false

		if world.blocks.has(walking_pos) or world.has_planted_seed(walking_pos):
			world.show_notification("Clear the walking space beside the gate first.")
			return false

	# Do not overwrite special player-built/interactive blocks under the new gate.
	var under_pos = Vector2i(gate_pos.x, gate_pos.y + 1)

	if not world.is_grid_inside_world(under_pos):
		world.show_notification("Not enough space under the gate.")
		return false

	if world.blocks.has(under_pos):
		var under_type = str(world.blocks[under_pos].get("type", ""))

		if under_type == world.ENTRANCE_GATE_TYPE:
			world.show_notification("Entrance Gate is blocking that spot.")
			return false

		if world.item_database.has(under_type):
			if bool(world.item_database[under_type].get("unbreakable", false)) and under_type != "bedrock":
				world.show_notification("Unbreakable block under gate spot.")
				return false

		if under_type in ["crafting_station", "furnace", "wooden_entrance", "sign"]:
			world.show_notification("A station or interactive block is under that spot.")
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

		if world.blocks.has(bedrock_pos) and str(world.blocks[bedrock_pos].get("type", "")) == "bedrock":
			world.replace_block_without_drop(bedrock_pos, "dirt")

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
			world.replace_block_without_drop(bedrock_pos, "dirt")

func get_entrance_gate_spawn_position() -> Vector2:
	var gate_pos = get_entrance_gate_grid_position()
	return Vector2(gate_pos.x * world.BLOCK_SIZE, gate_pos.y * world.BLOCK_SIZE)

func get_clear_entrance_spawn_grid(gate_pos: Vector2i) -> Vector2i:
	return gate_pos

func ensure_entrance_gate():
	var existing_gate = find_entrance_gate_grid()

	if existing_gate != world.INVALID_GRID_POS:
		ensure_entrance_gate_bedrock(existing_gate)
		cleanup_legacy_entrance_gate_bedrock(existing_gate)
		update_entrance_gate_visual(existing_gate)
		return

	var gate_x = get_entrance_gate_center_x()
	var surface_y = world.get_surface_y_at_x(gate_x)

	# Clear the center area so every world has a safe entrance zone.
	for x in range(gate_x - world.ENTRANCE_GATE_CLEAR_RADIUS, gate_x + world.ENTRANCE_GATE_CLEAR_RADIUS + 1):
		if x < 1 or x >= world.WORLD_WIDTH - 1:
			continue

		for y in range(surface_y - 5, surface_y):
			world.remove_block_without_drop(Vector2i(x, y))

		world.replace_block_without_drop(Vector2i(x, surface_y), "grass")

		for y in range(surface_y + 1, min(surface_y + 4, world.BEDROCK_START_Y)):
			world.replace_block_without_drop(Vector2i(x, y), "dirt")

	var gate_pos = Vector2i(gate_x, surface_y)
	ensure_entrance_gate_bedrock(gate_pos)
	cleanup_legacy_entrance_gate_bedrock(gate_pos)
	world.create_block(gate_pos, world.ENTRANCE_GATE_TYPE)
	update_entrance_gate_visual(gate_pos)

func update_entrance_gate_visual(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	var block_node = world.blocks[grid_pos]["node"]

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
		"res://Assets/blocks/basic blocks/water_0.png",
		"res://Assets/blocks/basic blocks/water_1.png",
		"res://Assets/blocks/basic blocks/water_2.png",
		"res://Assets/blocks/basic blocks/water_3.png"
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

		var block_node = world.blocks[grid_pos]["node"]

		if block_node == null or not is_instance_valid(block_node):
			continue

		var visual = block_node.get_node_or_null("Visual")

		if visual != null:
			visual.texture = current_water_texture
