extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var network = root.get_node("NetworkManager")
	network.active_join_request_id = "landfill_test"
	network.active_join_world_name = "LANDFILL_100001"
	network.current_world_name = "LANDFILL_100001"
	network.pending_server_world_state = {"old": true}
	var redirect := {
		"world": "LANDFILL_100001", "target_world": "LANDFILL_100002",
		"join_request_id": "stale"
	}
	assert(not network.handle_landfill_instance_redirect(redirect))
	assert(network.current_world_name == "LANDFILL_100001")
	redirect.join_request_id = "landfill_test"
	assert(network.handle_landfill_instance_redirect(redirect))
	assert(network.current_world_name == "LANDFILL_100002")
	assert(network.active_join_world_name == "LANDFILL_100002")
	assert(network.active_join_request_id == "landfill_test")
	assert(network.pending_server_world_state.is_empty())
	assert(network.is_message_for_active_world({"world": "LANDFILL_100002"}))
	assert(not network.is_message_for_active_world({"world": "LANDFILL_100001"}))
	assert(not network.handle_landfill_instance_redirect(redirect))
	print("[landfill-redirect] PASS")
	quit()
