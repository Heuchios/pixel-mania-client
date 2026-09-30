extends "res://tests/network_game_smoke.gd"

const EDIT_WORLD := "NETWORK_AUDIT"

func peer_phase() -> String:
	var peer := "observer" if role == "actor" else "actor"
	var file := output.path_join(peer + ".phase")
	return FileAccess.get_file_as_string(file) if FileAccess.file_exists(file) else ""

func enter(target: String) -> bool:
	var previous_entry: String = network.active_world_entry_session_id
	world.enter_world_by_name(target)
	return await until(func(): return network.world_entry_active and network.active_world_entry_session_id != previous_entry and world.current_world_name == target and not world.is_movement_locked(), "entered " + target, 45)

func block_present(grid: Vector2i, layer: String) -> bool:
	return world.background_blocks.has(grid) if layer == "background" else world.blocks.has(grid)

func place(grid: Vector2i, layer: String) -> bool:
	var item := "dirt_wall" if layer == "background" else "dirt"
	network.send_world_block_update("place", layer, grid, item, EDIT_WORLD)
	return await until(func(): return block_present(grid, layer), "placed " + layer)

func break_cell(grid: Vector2i, layer: String) -> bool:
	var item := "dirt_wall" if layer == "background" else "dirt"
	for hit in range(10):
		network.send_world_block_update("break", layer, grid, item, EDIT_WORLD, {"source_tool": "punch"})
		await create_timer(0.4).timeout
		if not block_present(grid, layer):
			return true
	return require(false, "broke " + layer)

func run():
	network = root.get_node("NetworkManager")
	var mode = root.get_node("MovementMode")
	output = mode.get_launch_arg_value("--audit-output", "")
	role = mode.get_launch_arg_value("--audit-role", "actor")
	if not require(output != "" and str(network.active_server_urls[0]).begins_with("ws://127.0.0.1:"), "explicit loopback required"):
		return
	if not await until(func(): return network.is_connected_to_server(), "socket open"):
		return
	var username := "NetAuditActor" if role == "actor" else "NetAuditObserver"
	network.send_message({"type": "dev_backend_login", "username": username, "world": "LOBBY", "request_id": "rejoin_login", "movement_batch_format": "columns_v1"})
	if not await until(func(): return network.is_server_session_authenticated(), "authentication"):
		return
	change_scene_to_file("res://Scenes/main.tscn")
	await process_frame
	await process_frame
	world = network.get_world_node()
	world.create_or_switch_profile(username)
	if not await enter(EDIT_WORLD):
		return
	mark("ready")
	if not await until(func(): return world.player_manager.remote_players.size() == 1, "both players joined", 45):
		return
	var grid_file := output.path_join("rejoin-cells.json")
	if role == "actor":
		var old_grid := Vector2i(roundi(world.player.global_position.x / 32.0), roundi(world.player.global_position.y / 32.0)) + Vector2i(2, -1)
		var next_grid := old_grid + Vector2i(0, -1)
		var file := FileAccess.open(grid_file, FileAccess.WRITE)
		file.store_string(JSON.stringify({"old": [old_grid.x, old_grid.y], "next": [next_grid.x, next_grid.y]}))
		file.close()
		if not await place(old_grid, "foreground"):
			return
		mark("initial_placed")
		if not await until(func(): return peer_phase() == "away", "observer left"):
			return
		if not await break_cell(old_grid, "foreground") or not await place(next_grid, "foreground"):
			return
		mark("edited_while_away")
		if not await until(func(): return peer_phase() == "rejoined_verified", "observer sees absent-player edits", 45):
			return
		if not await enter("REJOIN_OTHER"):
			return
		mark("away")
		if not await until(func(): return peer_phase() == "edited_while_away", "observer edited"):
			return
		if not await enter(EDIT_WORLD):
			return
		if not require(block_present(old_grid, "foreground") and not block_present(next_grid, "foreground"), "actor rejoin reflects observer placement and break"):
			return
		results["rejoin"] = "observer changes visible without restarting"
		finish(0)
	else:
		if not await until(func(): return peer_phase() == "initial_placed", "actor initial placement"):
			return
		var cells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(grid_file))
		var old_grid := Vector2i(cells.old[0], cells.old[1])
		var next_grid := Vector2i(cells.next[0], cells.next[1])
		if not await until(func(): return block_present(old_grid, "foreground"), "initial live placement visible"):
			return
		if not await enter("REJOIN_OTHER"):
			return
		mark("away")
		if not await until(func(): return peer_phase() == "edited_while_away", "actor edited"):
			return
		if not await enter(EDIT_WORLD):
			return
		results["old_present"] = block_present(old_grid, "foreground")
		results["new_present"] = block_present(next_grid, "foreground")
		if not require(not block_present(old_grid, "foreground") and block_present(next_grid, "foreground"), "observer rejoin reflects actor placement and break"):
			return
		mark("rejoined_verified")
		if not await until(func(): return peer_phase() == "away", "actor left"):
			return
		if not await break_cell(next_grid, "foreground") or not await place(old_grid, "foreground"):
			return
		mark("edited_while_away")
		if not await until(func(): return peer_phase() == "done", "actor verified rejoin", 45):
			return
		results["rejoin"] = "actor changes visible without restarting"
		finish(0)
