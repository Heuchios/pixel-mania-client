extends SceneTree


class RetrySaveManager:
	extends RefCounted

	var retry_count: int = 0

	func retry_server_world_entry(_reason: String) -> bool:
		retry_count += 1
		return true


class RetryWorld:
	extends Node

	var applying_network_world_update: bool = false
	var current_world_name: String = "TEST"
	var save_manager := RetrySaveManager.new()


func _init() -> void:
	call_deferred("_run")


func source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start: int = source.find(start_marker)
	assert(start >= 0, "Missing source marker: " + start_marker)
	var finish: int = source.find(end_marker, start + start_marker.length())
	assert(finish >= 0, "Missing source marker: " + end_marker)
	return source.substr(start, finish - start)


func _run() -> void:
	var loading_script: Script = load("res://Scripts/world_loading_ui_manager.gd")
	assert(loading_script != null)
	var loading_manager: Node = loading_script.new()
	var retry_world := RetryWorld.new()
	loading_manager.set("world", retry_world)
	loading_manager.set("waiting_for_server_state", true)
	loading_manager.set("next_server_retry_msec", 1)
	loading_manager.call("update_timeout")
	assert(bool(loading_manager.get("waiting_for_server_state")))
	assert(retry_world.save_manager.retry_count == 0)
	loading_manager.set("next_server_retry_msec", 1)
	loading_manager.set("server_retry_attempt_count", 1)
	loading_manager.call("update_timeout")
	assert(retry_world.save_manager.retry_count == 1)
	loading_manager.free()
	retry_world.free()

	var loading_source := FileAccess.get_file_as_string("res://Scripts/world_loading_ui_manager.gd")
	var timeout_source := source_between(loading_source, "func update_timeout", "func is_world_ready_for_player")
	assert(timeout_source.contains("retry_server_world_entry"))
	assert(not timeout_source.contains("finish_world_entry_after_load"))
	assert(not timeout_source.contains("finish_smooth_world_load()"))

	var network_source := FileAccess.get_file_as_string("res://Scripts/network_manager.gd")
	assert(network_source.contains("var pending_server_world_state: Dictionary = {}"))
	assert(network_source.contains("apply_pending_server_world_state_if_ready()"))
	assert(network_source.contains("_queue_pending_server_world_state(data, \"world_scene_not_ready\")"))
	assert(network_source.contains("pending_server_world_state = data.duplicate(false)"))
	assert(network_source.contains("pending_server_world_state.duplicate(false)"))
	assert(not network_source.contains("pending_server_world_state.duplicate(true)"))
	assert(network_source.contains("join_request_id"))
	assert(network_source.contains("client_first_world_byte"))
	assert(network_source.contains("max_frame_delta_ms"))
	assert(network_source.contains("frame_stall_count"))
	assert(network_source.contains("var pending_world_entry_block_updates: Array[Dictionary] = []"))
	assert(network_source.contains("_queue_pending_world_entry_block_update_if_needed(data)"))
	assert(network_source.contains("func process_pending_world_entry_block_updates"))
	assert(network_source.contains("\"world_entry_catchup_wait\""))
	assert(loading_source.contains("client_world_revealed"))
	var network_process_source := source_between(network_source, "func _process", "func process_server_packets_with_budget")
	var packet_budget_index: int = network_process_source.find("process_server_packets_with_budget()")
	var world_state_apply_index: int = network_process_source.find("apply_pending_server_world_state_if_ready()")
	var catchup_apply_index: int = network_process_source.find("process_pending_world_entry_block_updates()")
	var ready_retry_index: int = network_process_source.find("process_pending_world_entry_ready_retry()")
	assert(packet_budget_index >= 0)
	assert(world_state_apply_index > packet_budget_index)
	assert(catchup_apply_index > world_state_apply_index)
	assert(ready_retry_index > catchup_apply_index)
	var connect_source := source_between(network_source, "func connect_to_server", "func request_server_connection")
	assert(connect_source.contains("_invalidate_active_join_request_for_transport_change"))
	var invalidate_source := source_between(network_source, "func _invalidate_active_join_request_for_transport_change", "func play_local_join_world_sound")
	assert(invalidate_source.contains("active_join_request_pending"))
	assert(invalidate_source.contains("cancel_active_join_request()"))
	var metadata_source := source_between(network_source, "func _accept_world_entry_snapshot_metadata", "func notify_world_entry_spawn_ready")
	assert(metadata_source.contains("duplicate_active_snapshot"))
	assert(metadata_source.contains("world_entry_ready_sent"))
	assert(metadata_source.contains("not pending_world_entry_ready.is_empty()"))
	var activation_source := source_between(network_source, "func _handle_world_entry_active", "func _handle_world_entry_rejected_message")
	assert(not activation_source.contains("active_before_client_ready"))
	assert(not activation_source.contains("if not world_entry_ready_sent"))
	assert(activation_source.contains("active_revision_mismatch"))
	assert(activation_source.contains("controls_unlocked"))
	assert(activation_source.contains("process_pending_world_entry_block_updates()"))

	var readiness_source := source_between(loading_source, "func is_world_ready_for_player", "func _is_dedicated_netfox_server_without_local_player")
	assert(not readiness_source.contains("blocks.is_empty()"))

	var save_source := FileAccess.get_file_as_string("res://Scripts/save_manager.gd")
	var retry_source := source_between(save_source, "func retry_server_world_entry", "func handle_server_world_entry_rejected")
	assert(retry_source.contains("cancel_active_join_request"))
	assert(retry_source.contains("request_server_connection(false)"))
	assert(not retry_source.contains("request_server_connection(true)"))
	var enter_source := source_between(save_source, "func enter_world_by_name", "func handle_network_door_enter_ok")
	assert(enter_source.contains("request_server_connection(false)"))
	assert(not enter_source.contains("request_server_connection(true)"))

	var sync_source := FileAccess.get_file_as_string("res://Scripts/world_state_sync_manager.gd")
	var apply_source := source_between(sync_source, "func apply_network_world_state", "func apply_network_block_update")
	var exclusive_flag_index: int = apply_source.find("world.applying_network_world_update = true")
	var first_await_index: int = apply_source.find("await wait_for_world_state_loading_overlay_to_draw")
	assert(exclusive_flag_index >= 0)
	assert(first_await_index >= 0)
	assert(exclusive_flag_index < first_await_index)
	assert(apply_source.contains("not is_world_state_apply_current(apply_generation)"))
	assert(apply_source.contains("if raw_foreground is Dictionary:"))

	var sync_script: Script = load("res://Scripts/world_state_sync_manager.gd")
	assert(sync_script != null)
	var sync_manager: Node = sync_script.new()
	var prioritized: Array = sync_manager.call("_prioritize_world_layer_entries_for_spawn", [
		{"x": 80, "y": 20, "block_type": "far_a"},
		{"x": 9, "y": 10, "block_type": "near_a"},
		{"x": 12, "y": 8, "block_type": "near_b"},
		{"x": 90, "y": 20, "block_type": "far_b"}
	], {"spawn_grid_x": 10, "spawn_grid_y": 10})
	assert(prioritized.size() == 4)
	assert(str(prioritized[0].get("block_type", "")) == "near_a")
	assert(str(prioritized[1].get("block_type", "")) == "near_b")
	assert(str(prioritized[2].get("block_type", "")) == "far_a")
	assert(str(prioritized[3].get("block_type", "")) == "far_b")
	sync_manager.free()

	var server_route_source := FileAccess.get_file_as_string("res://backend/src/server_phase8_player_session_routes.ts")
	assert(server_route_source.contains("join_request_id: joinRequestId"))
	assert(server_route_source.contains("WORLD_ENTRY_CATCHUP_MAX_NO_PROGRESS_ATTEMPTS"))
	assert(server_route_source.contains("type: \"world_entry_catchup_wait\""))
	assert(server_route_source.contains("player.world_entry_snapshot_queued = false"))
	assert(server_route_source.contains("player.world_entry_snapshot_queued = true"))

	var server_source := FileAccess.get_file_as_string("res://backend/src/server.ts")
	assert(server_source.contains("function getPendingWorldEntryPlayerRecords"))
	assert(server_source.contains("player.world_entry_snapshot_queued !== true"))
	assert(server_source.contains("world_entry_catchup_broadcast"))

	print("[world-join-state-lifecycle] success")
	quit(0)
