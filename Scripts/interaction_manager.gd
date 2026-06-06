extends Node

var world = null


func setup(world_ref):
	world = world_ref


func use_selected_item_at_mouse():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_world_menu_open():
		return

	if world.is_crafting_open():
		return

	if world.is_furnace_open():
		return

	if world.is_sign_open():
		return

	if world.is_shop_open():
		return

	if world.is_world_lock_ui_open():
		return

	if world.has_method("is_vending_open") and world.is_vending_open():
		return

	if world.has_method("is_safe_open") and world.is_safe_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if world.selected_item_category == "tool" and world.selected_item_type == world.FISHING_ROD_ID:
		world.use_fishing_rod_at_mouse()
		return

	if world.selected_item_category == "lure":
		world.use_selected_lure_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "entrance_mover":
		world.use_entrance_mover_at_mouse()
		return

	var clicked_grid = world.get_mouse_grid_position()
	var clicked_entrance_gate = world.get_entrance_gate_near_grid(clicked_grid)

	if clicked_entrance_gate != world.INVALID_GRID_POS:
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "punch":
		if world.has_method("play_player_punch_animation"):
			world.play_player_punch_animation()
		world.break_block_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "wrench":
		interact_with_mouse()
		return

	if world.selected_item_category == "block":
		world.place_block_at_mouse()
		return

	if world.selected_item_category == "seed":
		world.plant_seed_at_mouse()
		return


func place_selected_item_at_mouse():
	use_selected_item_at_mouse()


func interact_with_mouse():
	if world.has_method("get_remote_player_at_screen_position"):
		var remote_player = world.get_remote_player_at_screen_position(world.get_viewport().get_mouse_position())
		if remote_player is Dictionary and not remote_player.is_empty():
			var remote_position = Vector2(float(remote_player.get("x", 0.0)), float(remote_player.get("y", 0.0)))
			if world.player != null and world.player.global_position.distance_to(remote_position) > world.INTERACTION_PIXEL_RANGE:
				world.show_notification("Too far away.")
				return

			if world.has_method("open_remote_player_profile"):
				world.open_remote_player_profile(remote_player)
				return

	var grid_pos = world.get_mouse_grid_position()

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	interact_with_grid(grid_pos)


func interact_with_facing_tile():
	if world.has_method("get_remote_player_in_interaction_range"):
		var remote_player = world.get_remote_player_in_interaction_range()
		if remote_player is Dictionary and not remote_player.is_empty():
			if world.has_method("open_remote_player_profile"):
				world.open_remote_player_profile(remote_player)
				return

	var player_grid = world.get_player_grid_position()
	var grid_pos = Vector2i(player_grid.x + world.player_facing_direction, player_grid.y)

	var anchor_grid = get_anchor_grid_for_block_area(grid_pos)

	if anchor_grid != world.INVALID_GRID_POS:
		interact_with_grid(anchor_grid)
		return

	# Try one tile lower too, because stations usually sit at foot level.
	var lower_pos = Vector2i(grid_pos.x, grid_pos.y + 1)

	anchor_grid = get_anchor_grid_for_block_area(lower_pos)

	if anchor_grid != world.INVALID_GRID_POS:
		interact_with_grid(anchor_grid)
		return

	world.show_notification("Nothing to interact with.")


func interact_with_grid(grid_pos: Vector2i):
	grid_pos = get_anchor_grid_for_block_area(grid_pos)

	if not world.blocks.has(grid_pos):
		world.show_notification("Nothing to interact with.")
		return

	var block_type = str(world.blocks[grid_pos]["type"])

	if world.has_method("can_current_player_interact_with_block") and not world.can_current_player_interact_with_block(block_type):
		if is_safe_block(block_type):
			if world.world_lock_manager != null and world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can open this safe.")
			else:
				world.show_notification("Lock this world before using safes.")
		elif is_vending_machine_block(block_type):
			world.show_notification("Lock this world before using vending machines.")
		elif is_wooden_entrance_block(block_type):
			world.show_notification("Only the world owner or world admins can lock this entrance.")
		else:
			world.show_notification("This world is locked.")
		return

	if block_type == "world_lock":
		if world.has_method("open_world_lock_ui"):
			world.open_world_lock_ui(grid_pos)
		return

	if world.is_entrance_gate_block(block_type):
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if is_crafting_station_block(block_type):
		world.open_crafting_station(grid_pos)
		return

	if is_furnace_block(block_type):
		world.open_furnace_station(grid_pos)
		return

	if is_wooden_entrance_block(block_type):
		toggle_wooden_entrance(grid_pos)
		return

	if world.is_sign_block(block_type):
		world.open_sign_editor(grid_pos)
		return

	if is_vending_machine_block(block_type):
		open_vending_ui(grid_pos)
		return

	if is_safe_block(block_type):
		open_safe_ui(grid_pos)
		return

	if is_fish_monger_block(block_type):
		open_fish_monger_ui(grid_pos)
		return

	world.show_notification("Nothing to interact with.")


func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
	if world != null and world.has_method("get_anchor_grid_for_block_area"):
		return world.get_anchor_grid_for_block_area(grid_pos)

	if world != null and world.blocks.has(grid_pos):
		return grid_pos

	if world != null:
		return world.INVALID_GRID_POS

	return Vector2i(999999, 999999)


func is_wooden_entrance_block(block_type: String) -> bool:
	return block_type == "wooden_entrance"


func is_vending_machine_block(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func is_safe_block(block_type: String) -> bool:
	return block_type == "safe"


func is_fish_monger_block(block_type: String) -> bool:
	return block_type == "fish_monger"


func open_vending_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_vending_ui"):
		world.open_vending_ui(grid_pos)
	else:
		world.show_notification("Vending UI is not ready.")


func open_safe_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_safe_ui"):
		world.open_safe_ui(grid_pos)
	else:
		world.show_notification("Safe UI is not ready.")


func open_fish_monger_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_fish_monger_ui"):
		world.open_fish_monger_ui(grid_pos)
	else:
		world.show_notification("Fish Monger UI is not ready.")


func can_current_player_toggle_wooden_entrance() -> bool:
	if world != null and world.has_method("can_current_player_toggle_wooden_entrance"):
		return bool(world.can_current_player_toggle_wooden_entrance())

	return true


func set_wooden_entrance_locked(grid_pos: Vector2i, locked: bool):
	if not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos]["type"])

	if not is_wooden_entrance_block(block_type):
		return

	world.blocks[grid_pos]["entrance_locked"] = locked

	if world.block_manager != null and world.block_manager.has_method("refresh_wooden_entrance_collision"):
		world.block_manager.refresh_wooden_entrance_collision(grid_pos)

	update_wooden_entrance_visual(grid_pos)

	send_network_wooden_entrance_state(grid_pos, locked)


func toggle_wooden_entrance(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	if not can_current_player_toggle_wooden_entrance():
		world.show_notification("Only the world owner or world admins can lock this entrance.")
		return

	var is_locked = bool(world.blocks[grid_pos].get("entrance_locked", false))
	set_wooden_entrance_locked(grid_pos, not is_locked)

	if bool(world.blocks[grid_pos].get("entrance_locked", false)):
		world.show_notification("Wooden Entrance locked.")
	else:
		world.show_notification("Wooden Entrance unlocked.")


func send_network_wooden_entrance_state(grid_pos: Vector2i, locked: bool):
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		network.send_world_interaction_update({
			"action": "wooden_entrance_state",
			"x": grid_pos.x,
			"y": grid_pos.y,
			"locked": locked
		}, world.current_world_name)


func update_wooden_entrance_visual(grid_pos: Vector2i):
	if world == null or world.block_manager == null:
		return

	if world.block_manager.has_method("update_wooden_entrance_visual"):
		world.block_manager.update_wooden_entrance_visual(grid_pos)


func is_crafting_station_block(block_type: String) -> bool:
	return block_type == "crafting_station"


func get_crafting_station_left_pos(grid_pos: Vector2i) -> Vector2i:
	return grid_pos


func should_server_create_break_drops() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func place_crafting_station_at_mouse():
	if not world.inventory.has("crafting_station"):
		return

	if world.inventory["crafting_station"] <= 0:
		world.show_notification("You don't have a Crafting Station.")
		return

	var grid_pos = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_method("can_current_player_build") and not world.can_current_player_build():
		world.show_notification("This world is locked.")
		return

	if not world.can_place_block_here(grid_pos):
		world.show_notification("Need an empty tile.")
		return

	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if send_network_station_place(grid_pos):
			world.show_notification("Placing Crafting Station...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	world.create_block(grid_pos, "crafting_station")

	send_network_station_place(grid_pos)

	world.inventory["crafting_station"] -= 1
	world.update_all_ui()


func break_crafting_station(grid_pos: Vector2i):
	if world.has_method("can_current_player_break_block") and not world.can_current_player_break_block("crafting_station"):
		world.show_notification("This world is locked.")
		return

	var station_pos = get_crafting_station_left_pos(grid_pos)

	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if send_network_station_remove(station_pos):
			world.show_notification("Breaking Crafting Station...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	var drop_position = Vector2(station_pos.x * world.BLOCK_SIZE, station_pos.y * world.BLOCK_SIZE)

	if world.blocks.has(station_pos):
		var block_node = world.blocks[station_pos]["node"]

		if is_instance_valid(block_node):
			var crack_overlay = block_node.get_node_or_null("CrackOverlay")
			if crack_overlay != null:
				crack_overlay.queue_free()

			block_node.queue_free()

		world.blocks.erase(station_pos)
		world.block_hit_progress.erase(station_pos)
		world.block_hit_timers.erase(station_pos)

	send_network_station_remove(station_pos)

	if not should_server_create_break_drops():
		world.create_item_drop("crafting_station", drop_position, false, "block", 0.0, 1)
		world.try_drop_gems("crafting_station", drop_position)
	world.update_all_ui()


func is_furnace_block(block_type: String) -> bool:
	return block_type == "furnace"


func send_network_station_place(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_block_update"):
		return false

	return bool(network.send_world_block_update("place", "foreground", grid_pos, "crafting_station", world.current_world_name))


func send_network_station_remove(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_block_update"):
		return false

	return bool(network.send_world_block_update("break", "foreground", grid_pos, "crafting_station", world.current_world_name))
