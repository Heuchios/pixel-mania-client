extends SceneTree

var network
var world
var output := ""
var role := "actor"
var results := {}

func _initialize():
	call_deferred("run")

func require(condition: bool, label: String) -> bool:
	if not condition:
		results["failure"] = label
		finish(1)
	return condition

func until(predicate: Callable, label: String, seconds: float = 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return require(bool(predicate.call()), label)

func mark(value: String):
	var file := FileAccess.open(output.path_join(role + ".phase"), FileAccess.WRITE)
	file.store_string(value)

func finish(code: int):
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	results["ok"] = code == 0
	results["role"] = role
	var file := FileAccess.open(output.path_join(role + "-result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("NETWORK_GAME_RESULT ", JSON.stringify(results))
	mark("done")
	quit(code)

func run():
	network = root.get_node("NetworkManager")
	var mode = root.get_node("MovementMode")
	output = mode.get_launch_arg_value("--audit-output", "")
	role = mode.get_launch_arg_value("--audit-role", "actor")
	if not require(output != "" and str(network.active_server_urls[0]).begins_with("ws://127.0.0.1:"), "Smoke test requires explicit loopback and output directory"):
		return
	if not await until(func(): return network.is_connected_to_server(), "socket open"):
		return
	var username := "NetAuditActor" if role == "actor" else "NetAuditObserver"
	network.send_message({"type": "dev_backend_login", "username": username, "world": "LOBBY", "request_id": "audit_login", "movement_batch_format": "columns_v1"})
	if not await until(func(): return network.is_server_session_authenticated(), "authentication"):
		return
	change_scene_to_file("res://Scenes/main.tscn")
	await process_frame
	await process_frame
	world = network.get_world_node()
	if not require(world != null and world.has_method("create_or_switch_profile"), "actual World node available"):
		return
	world.create_or_switch_profile(username)
	world.enter_world_by_name("NETWORK_AUDIT")
	if not await until(func(): return network.world_entry_active and world.in_world and not world.is_movement_locked(), "world initialized, spawned and controls ready", 45):
		return
	mark("ready")
	if not await until(func(): return world.player_manager.remote_players.size() == 1, "one remote player", 40):
		return
	if role == "observer":
		var deadline := Time.get_ticks_msec() + 100000
		var max_remotes := 0
		var positions := {}
		while Time.get_ticks_msec() < deadline:
			max_remotes = maxi(max_remotes, world.player_manager.remote_players.size())
			for remote in world.player_manager.remote_players.values():
				positions[str(remote.global_position.round())] = true
			if FileAccess.file_exists(output.path_join("actor.phase")) and FileAccess.get_file_as_string(output.path_join("actor.phase")) == "done":
				break
			await process_frame
		results["max_remote_entities"] = max_remotes
		results["distinct_remote_positions"] = positions.size()
		if not require(max_remotes == 1 and positions.size() > 5, "remote movement without duplicate entity"):
			return
		finish(0)
		return

	var start: Vector2 = world.player.global_position
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	await physics_frame
	results["immediate_local_travel_px"] = world.player.global_position.distance_to(start)
	if not require(float(results.immediate_local_travel_px) > 0.1, "input must move locally before a 250ms round trip"):
		return
	await create_timer(0.25).timeout
	Input.action_release("move_right")
	var grounded_y: float = world.player.global_position.y
	Input.action_press("jump")
	await create_timer(0.14).timeout
	Input.action_release("jump")
	results["jump_height_px"] = grounded_y - world.player.global_position.y
	await create_timer(1.2).timeout
	if not require(float(results.jump_height_px) > 5, "real physics jump"):
		return
	var grid := Vector2i(roundi(world.player.global_position.x / 32.0), roundi(world.player.global_position.y / 32.0)) + Vector2i(2, -1)
	var quantity_before := int(world.inventory.get("dirt", 0))
	var place_started := Time.get_ticks_msec()
	network.send_world_block_update("place", "foreground", grid, "dirt", "NETWORK_AUDIT")
	if not await until(func(): return world.blocks.has(grid), "placement visible"):
		return
	results["place_visible_ms"] = Time.get_ticks_msec() - place_started
	if not await until(func(): return int(world.inventory.get("dirt", 0)) == quantity_before - 1, "placement charged once"):
		return
	for hit in range(10):
		network.send_world_block_update("break", "foreground", grid, "dirt", "NETWORK_AUDIT", {"source_tool": "punch"})
		await create_timer(0.4).timeout
		if not world.blocks.has(grid):
			break
	if not require(not world.blocks.has(grid), "authoritative block break rendered"):
		return
	results["block_actions"] = "placed, charged once, multi-hit break rendered"
	var lock_grid := grid + Vector2i(-1, 0)
	network.send_world_block_update("place", "foreground", lock_grid, "world_lock", "NETWORK_AUDIT")
	if not await until(func(): return world.blocks.has(lock_grid), "world lock placement"):
		return
	network.send_world_block_update("place", "foreground", grid, "display_case", "NETWORK_AUDIT")
	if not await until(func(): return world.blocks.has(grid) and str(world.blocks[grid].get("type", "")) == "display_case", "display case placement"):
		return
	await create_timer(0.4).timeout
	var display_quantity := int(world.inventory.get("dirt", 0))
	var display_started := Time.get_ticks_msec()
	world.selected_item_type = "dirt"
	world.selected_item_category = "block"
	world.block_manager.try_display_selected_item_at_grid(grid)
	if not await until(func(): return int(world.inventory.get("dirt", 0)) == display_quantity - 1, "display deposit authoritative inventory"):
		return
	results["display_deposit_ms"] = Time.get_ticks_msec() - display_started
	world.block_manager.try_withdraw_display_item_at_grid(grid)
	if not await until(func(): return int(world.inventory.get("dirt", 0)) == display_quantity, "display withdrawal authoritative inventory"):
		return
	results["display_roundtrip"] = "quantity conserved"
	world.toggle_inventory_window()
	if not require(world.is_inventory_open(), "inventory UI opened"):
		return
	display_started = Time.get_ticks_msec()
	world.block_manager.try_display_selected_item_at_grid(grid)
	if not await until(func(): return int(world.inventory.get("dirt", 0)) == display_quantity - 1, "display deposit with inventory open"):
		return
	results["display_inventory_open_ms"] = Time.get_ticks_msec() - display_started
	world.block_manager.try_withdraw_display_item_at_grid(grid)
	if not await until(func(): return int(world.inventory.get("dirt", 0)) == display_quantity, "display withdrawal with inventory open"):
		return
	world.toggle_inventory_window()
	# The runner terminates only this test proxy's connections, then permits the
	# existing authenticated token to reconnect normally. No action is replayed.
	var old_entry: String = network.active_world_entry_session_id
	var old_generation: int = network.socket_generation
	mark("interrupt")
	if not await until(func(): return network.socket_generation > old_generation and network.world_entry_active and network.active_world_entry_session_id != old_entry and network.is_server_session_authenticated(), "authenticated reconnect and fresh world snapshot", 45):
		return
	if not require(int(world.inventory.get("dirt", 0)) == display_quantity, "reconnect preserves authoritative inventory"):
		return
	results["reconnect"] = "new transport and entry session, correct world and inventory"
	network._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await create_timer(0.2).timeout
	network._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(1.0).timeout
	results["connection"] = network.get_connection_debug_summary()
	results["corrections"] = int(world.get_meta("server_position_correction_count", 0))
	if not require(int(results["corrections"]) == 0, "ordinary movement and reconnect must not require position corrections"):
		return
	if mode.has_launch_arg("--audit-render"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("game.png"))
	finish(0)
