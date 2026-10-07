extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var network = root.get_node("NetworkManager")
	network.active_join_request_id = "name-join-1"
	network.active_join_world_name = "SHOP"
	assert(network.handle_world_name_redirect({"world":"SHOP","target_world":"W123456","public_name":"SHOP","join_request_id":"name-join-1"}))
	assert(network.current_world_name == "W123456")
	assert(network.active_join_world_name == "W123456")
	assert(network.pending_join_world_name == "SHOP")
	assert(network.pending_join_world_identity == "W123456")
	assert(network.get_public_world_name("W123456") == "SHOP")
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"SHOP","status":"unowned"}})
	assert(network.get_public_world_name("W123456") == "SHOP", "Creation must retain the entered public name")
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"SHOP","status":"reserved"}})
	assert(network.get_public_world_name("W123456") == "SHOP", "Locking must not generate a public name")
	assert(not network.handle_world_name_redirect({"world":"SHOP","target_world":"BAD","join_request_id":"stale"}))
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"WGENERATED","status":"generated","original_paid_gems":null}})
	assert(network.get_public_world_name("W123456") == "WGENERATED")
	network.world_population_counts = {"W123456": 3}
	assert(network.get_world_population_counts() == {"WGENERATED":3})
	# Typing a released name is a fresh public-name request, never a retry of the old identity.
	network.set_pending_join("SHOP", "alice")
	assert(network.pending_join_world_identity == "")
	assert(network.pending_join_world_name == "SHOP")
	print("WORLD_NAME_ALIAS_TEST_OK")
	quit()
