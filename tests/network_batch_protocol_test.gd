extends SceneTree

class TestWorld extends Node:
	var in_world := true
	var current_world_name := "BATCHTEST"
	var applying_network_world_update := false
	var received_positions: Array[Dictionary] = []
	var received_left_ids: Array[String] = []
	var received_world_updates: Array[Dictionary] = []
	var received_block_reconciliations: Array[Dictionary] = []

	func handle_network_player_position(data: Dictionary) -> void:
		received_positions.append(data.duplicate(true))

	func handle_network_player_left(player_id: String) -> void:
		received_left_ids.append(player_id)

	func apply_network_block_update(data: Dictionary) -> void:
		received_world_updates.append(data.duplicate(true))

	func apply_network_block_reconcile(data: Dictionary) -> void:
		received_block_reconciliations.append(data.duplicate(true))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var network = root.get_node_or_null("NetworkManager")
	assert(network != null)
	assert(str(network.get_client_version()).strip_edges() != "")

	var test_world := TestWorld.new()
	test_world.name = "World"
	root.add_child(test_world)
	current_scene = test_world

	network.current_world_name = "BATCHTEST"
	network.player_id = "LOCAL"
	network.world_population_counts.clear()
	network.world_population_players.clear()
	network.world_population_authoritative.clear()

	network.handle_player_position_batch({
		"type": "player_position_batch",
		"world": "BATCHTEST",
		"players": [
			{"player_id": "REMOTE_A", "x": 10.0, "y": 20.0},
			{"player_id": "LOCAL", "x": 30.0, "y": 40.0},
			{"player_id": "REMOTE_OLD", "world": "OLDWORLD", "x": 1.0, "y": 2.0},
		],
		"left": [
			{"player_id": "REMOTE_B"},
			{"player_id": "REMOTE_C", "interest_cull": true},
		],
	})
	assert(test_world.received_positions.size() == 1)
	assert(str(test_world.received_positions[0].get("player_id", "")) == "REMOTE_A")
	assert(str(test_world.received_positions[0].get("world", "")) == "BATCHTEST")
	assert(test_world.received_left_ids == ["REMOTE_B", "REMOTE_C"])
	assert(network.world_population_players.get("BATCHTEST", {}).has("REMOTE_A"))
	assert(not network.world_population_players.get("BATCHTEST", {}).has("REMOTE_B"))

	network.handle_player_position_batch({
		"type": "player_position_batch",
		"world": "OLDWORLD",
		"players": [{"player_id": "REMOTE_STALE", "x": 5.0, "y": 6.0}],
	})
	assert(test_world.received_positions.size() == 1)

	network.handle_world_update_batch({
		"type": "world_update_batch",
		"world": "BATCHTEST",
		"updates": [
			{"type": "world_block_update", "action": "place", "x": 2, "y": 3, "block_type": "dirt"},
			{"type": "world_block_update", "world": "OLDWORLD", "action": "place", "x": 4, "y": 5, "block_type": "stone"},
		],
	})
	assert(test_world.received_world_updates.size() == 1)
	assert(str(test_world.received_world_updates[0].get("world", "")) == "BATCHTEST")
	assert(int(test_world.received_world_updates[0].get("x", -1)) == 2)

	network.handle_world_update_payload({
		"type": "world_block_reconcile",
		"world": "BATCHTEST",
		"request_id": "place_direct",
		"x": 6,
		"y": 7,
	})
	network.handle_world_update_batch({
		"type": "world_update_batch",
		"world": "BATCHTEST",
		"updates": [{
			"type": "world_block_reconcile",
			"request_id": "place_batched",
			"x": 8,
			"y": 9,
		}],
	})
	assert(test_world.received_block_reconciliations.size() == 2, "Direct and batched reconciliation must use the same client handler.")
	assert(str(test_world.received_block_reconciliations[0].get("world", "")) == "BATCHTEST")
	assert(str(test_world.received_block_reconciliations[1].get("world", "")) == "BATCHTEST")
	assert(str(test_world.received_block_reconciliations[0].get("request_id", "")) == "place_direct")
	assert(str(test_world.received_block_reconciliations[1].get("request_id", "")) == "place_batched")

	print("[network-batch-protocol] success")
	quit(0)
