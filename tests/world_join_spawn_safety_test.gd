extends SceneTree


func _init() -> void:
	call_deferred("_run")


func source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	assert(start >= 0, "Missing source marker: " + start_marker)
	var finish := source.find(end_marker, start + start_marker.length())
	assert(finish >= 0, "Missing source marker: " + end_marker)
	return source.substr(start, finish - start)


func _run() -> void:
	assert(load("res://Scripts/world.gd") != null)
	assert(load("res://Scripts/player_manager.gd") != null)
	assert(load("res://Scripts/networking/netfox_real_manager.gd") != null)
	assert(load("res://Scripts/networking/custom_authoritative_movement_manager.gd") != null)

	var world_source := FileAccess.get_file_as_string("res://Scripts/world.gd")
	var entrance_resolver := source_between(
		world_source,
		"func get_entrance_gate_spawn_position",
		"func is_entrance_gate_spawn_resolution_deferred"
	)
	assert(entrance_resolver.contains("get_live_entrance_gate_spawn_position(false)"))
	assert(entrance_resolver.contains("is_entrance_gate_spawn_resolution_deferred()"))
	assert(entrance_resolver.contains("return Vector2(INF, INF)"))
	assert(not entrance_resolver.contains("return Vector2.ZERO"))

	var live_entrance_resolver := source_between(
		world_source,
		"func get_live_entrance_gate_spawn_position",
		"func force_place_player_at_current_entrance_gate"
	)
	assert(live_entrance_resolver.contains("find_live_entrance_gate_grid_from_blocks()"))
	assert(live_entrance_resolver.contains("return Vector2(INF, INF)"))
	assert(not live_entrance_resolver.contains("get_default_entrance_gate"))

	var force_spawn := source_between(
		world_source,
		"func force_place_player_at_current_entrance_gate",
		"func flush_world_entry_spawn_position_to_server"
	)
	assert(force_spawn.find("not is_finite(spawn_pos.x)") < force_spawn.find("player.global_position = spawn_pos"))

	var player_manager_source := FileAccess.get_file_as_string("res://Scripts/player_manager.gd")
	var movement_sync := source_between(
		player_manager_source,
		"func update_multiplayer_movement",
		"func flush_multiplayer_position"
	)
	assert(movement_sync.contains("is_world_entry_position_sync_blocked()"))
	var movement_flush := source_between(
		player_manager_source,
		"func flush_multiplayer_position",
		"func is_world_entry_position_sync_blocked"
	)
	assert(movement_flush.contains("is_world_entry_position_sync_blocked()"))
	var entry_sync_guard := source_between(
		player_manager_source,
		"func is_world_entry_position_sync_blocked",
		"func is_multiplayer_position_flush_redundant"
	)
	assert(entry_sync_guard.contains("world_entry_in_progress"))
	assert(entry_sync_guard.contains("world_bulk_load_in_progress"))
	assert(entry_sync_guard.contains("waiting_for_server_world_state"))

	var netfox_source := FileAccess.get_file_as_string("res://Scripts/networking/netfox_real_manager.gd")
	var netfox_spawn_resolver := source_between(
		netfox_source,
		"func _get_spawn_position",
		"func _has_valid_entrance_spawn_position"
	)
	assert(netfox_spawn_resolver.contains("get_entrance_gate_spawn_position()"))
	assert(netfox_spawn_resolver.contains("return Vector2(INF, INF)"))
	assert(not netfox_spawn_resolver.contains("spawned_players"))
	assert(not netfox_spawn_resolver.contains("48"))
	assert(not netfox_spawn_resolver.contains("Vector2(300"))
	var netfox_spawn_ready := source_between(
		netfox_source,
		"func _is_peer_ready_for_spawn",
		"func _process_pending_spawn_requests"
	)
	assert(netfox_spawn_ready.contains("mode == \"standalone\""))
	assert(netfox_spawn_ready.contains("_has_valid_entrance_spawn_position()"))
	var netfox_spawn_apply := source_between(
		netfox_source,
		"func _spawn_player",
		"func _despawn_player"
	)
	assert(netfox_spawn_apply.find("not is_finite(spawn_position.x)") < netfox_spawn_apply.find("global_position = spawn_position"))

	var custom_source := FileAccess.get_file_as_string("res://Scripts/networking/custom_authoritative_movement_manager.gd")
	var custom_spawn_resolver := source_between(
		custom_source,
		"func _spawn_position_for_peer",
		"func _has_valid_entrance_spawn_position"
	)
	assert(custom_spawn_resolver.contains("get_entrance_gate_spawn_position()"))
	assert(custom_spawn_resolver.contains("return Vector2(INF, INF)"))
	assert(not custom_spawn_resolver.contains("server_spawn_slots_by_world"))
	assert(not custom_spawn_resolver.contains("48"))
	assert(not custom_spawn_resolver.contains("Vector2(300"))
	assert(not custom_spawn_resolver.contains("get_current_entrance_gate_spawn_position"))
	var custom_spawn_apply := source_between(
		custom_source,
		"func _server_add_player",
		"func _server_remove_player"
	)
	assert(custom_spawn_apply.find("not is_finite(spawn_position.x)") < custom_spawn_apply.find("_force_player_state(existing, spawn_position"))
	assert(custom_spawn_apply.find("not is_finite(spawn_position.x)") < custom_spawn_apply.find("_force_player_state(player, spawn_position"))

	print("[world-join-spawn-safety] success")
	quit(0)
