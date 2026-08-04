extends SceneTree

class TestWorld extends Node:
	var in_world := true
	var applying_network_world_update := false
	var current_world_name := "SNOWTEST"
	var received_updates: Array[Dictionary] = []

	func handle_network_player_position(_data = {}) -> void:
		pass

	func apply_network_block_update(data: Dictionary) -> void:
		received_updates.append(data.duplicate(true))


func _init() -> void:
	call_deferred("_run")


func source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	assert(start >= 0, "Missing source marker: " + start_marker)
	var finish := source.find(end_marker, start + start_marker.length())
	assert(finish >= 0, "Missing source marker: " + end_marker)
	return source.substr(start, finish - start)


func _run() -> void:
	assert(load("res://Scripts/block_manager.gd") != null)
	assert(load("res://Scripts/world_state_sync_manager.gd") != null)

	var block_manager_source := FileAccess.get_file_as_string("res://Scripts/block_manager.gd")
	var snow_visual_setter := source_between(
		block_manager_source,
		"func set_snow_storm_visuals_active",
		"func get_snow_storm_source_block_type"
	)
	assert(not snow_visual_setter.contains("apply_snow_storm_local_block_overrides()"))
	assert(snow_visual_setter.contains("restore_snow_storm_local_block_overrides()"))
	assert(block_manager_source.contains("FOREGROUND_TEXTURE_REFRESH_BATCH_SIZE := 1024"))
	assert(block_manager_source.contains("FOREGROUND_TEXTURE_REFRESH_PROCESS_USEC"))
	assert(block_manager_source.contains("Time.get_ticks_usec() - started_usec >= FOREGROUND_TEXTURE_REFRESH_PROCESS_USEC"))

	var network_source := FileAccess.get_file_as_string("res://Scripts/network_manager.gd")
	var event_handler := source_between(
		network_source,
		"func handle_world_event_tile_updates",
		"func process_world_event_tile_update_queue"
	)
	assert(event_handler.contains("world_event_tile_update_queue.append(update_payload)"))
	assert(event_handler.contains("update_payload[\"_from_world_event\"] = true"))
	assert(not event_handler.contains("apply_network_block_update"))
	assert(network_source.count("queue_world_block_update_behind_pending_event_updates(data)") >= 2)

	var queue_processor := source_between(
		network_source,
		"func process_world_event_tile_update_queue",
		"func compact_world_event_tile_update_queue"
	)
	assert(queue_processor.contains("MAX_WORLD_EVENT_TILE_UPDATES_PER_FRAME"))
	assert(queue_processor.contains("MAX_WORLD_EVENT_TILE_UPDATE_PROCESS_USEC"))
	assert(queue_processor.contains("world_node.apply_network_block_update(update_payload)"))

	var world_sync_source := FileAccess.get_file_as_string("res://Scripts/world_state_sync_manager.gd")
	var block_update_handler := source_between(
		world_sync_source,
		"func apply_network_block_update",
		"func _get_foreground_collision_block_type"
	)
	assert(block_update_handler.contains("is_from_world_event"))
	assert(block_update_handler.contains("is_bulk_network_update"))
	assert(block_update_handler.contains("replace_event_block_without_drop"))

	var network = root.get_node_or_null("NetworkManager")
	assert(network != null)
	assert(network.MAX_WORLD_EVENT_TILE_UPDATES_PER_FRAME >= 1024)
	assert(network.MAX_WORLD_EVENT_TILE_UPDATE_PROCESS_USEC <= 2500)
	network.clear_world_event_tile_update_queue()
	network.current_world_name = "SNOWTEST"

	var test_world := TestWorld.new()
	test_world.name = "World"
	root.add_child(test_world)
	current_scene = test_world

	var event_updates: Array = []
	for index in range(600):
		event_updates.append({
			"action": "place",
			"x": index,
			"y": 4,
			"block_type": "ice_block",
		})
	network.handle_world_event_tile_updates({
		"world": "SNOWTEST",
		"updates": event_updates,
	})
	assert(network.world_event_tile_update_queue.size() == 600)

	var simulated_frames := 0
	var first_frame_applied := 0
	while network.world_event_tile_update_queue_read_index < network.world_event_tile_update_queue.size():
		var applied_before: int = test_world.received_updates.size()
		network.process_world_event_tile_update_queue()
		var applied_this_frame: int = test_world.received_updates.size() - applied_before
		assert(applied_this_frame > 0)
		assert(applied_this_frame <= network.MAX_WORLD_EVENT_TILE_UPDATES_PER_FRAME)
		if simulated_frames == 0:
			first_frame_applied = applied_this_frame
		simulated_frames += 1
		assert(simulated_frames < 30)
	assert(first_frame_applied > 24)
	assert(test_world.received_updates.size() == 600)
	for update in test_world.received_updates:
		assert(bool(update.get("_from_world_event", false)))

	test_world.received_updates.clear()
	network.handle_world_event_tile_updates({
		"world": "SNOWTEST",
		"updates": [
			{"action": "place", "x": 1, "y": 5, "block_type": "ice_block"},
			{"action": "place", "x": 2, "y": 5, "block_type": "ice_block"},
		],
	})
	network.handle_world_update_payload({
		"type": "world_block_update",
		"world": "SNOWTEST",
		"action": "place",
		"x": 99,
		"y": 5,
		"block_type": "dirt",
	})
	network.process_world_event_tile_update_queue()
	assert(test_world.received_updates.size() == 3)
	assert(int(test_world.received_updates[0].get("x", -1)) == 1)
	assert(int(test_world.received_updates[1].get("x", -1)) == 2)
	assert(int(test_world.received_updates[2].get("x", -1)) == 99)
	assert(not bool(test_world.received_updates[2].get("_from_world_event", false)))

	network.clear_world_event_tile_update_queue()
	print("[snow-storm-event-delivery] success")
	quit(0)
