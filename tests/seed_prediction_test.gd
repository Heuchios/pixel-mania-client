extends SceneTree

class MockNetwork extends Node:
	var sent: Array = []
	var allow_send := true
	var local_player_id := "local"
	var client_id := "local"
	func send_inventory_transaction_request(data: Dictionary) -> bool:
		if not allow_send: return false
		sent.append(data)
		return true

func _initialize(): call_deferred("run")

func run():
	var old_network = root.get_node_or_null("NetworkManager")
	if old_network != null: root.remove_child(old_network)
	var network := MockNetwork.new()
	network.name = "NetworkManager"
	root.add_child(network)
	var world = load("res://tests/seed_prediction_world_fixture.gd").new()
	root.add_child(world)
	world.current_world_name = "TEST"
	world.selected_item_type = "dirt_seed"
	world.selected_item_category = "seed"
	world.seed_inventory = {"dirt_seed": 2}
	var seeds = load("res://Scripts/seed_system.gd").new()
	world.add_child(seeds)
	world.seed_system = seeds
	seeds.world = world
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	seeds.seed_tree_textures = {"dirt": [texture, texture, texture, texture]}
	var manager = load("res://Scripts/block_manager.gd").new()
	world.add_child(manager)
	world.block_manager = manager
	manager.world = world
	world.crack_textures = {1: texture, 2: texture, 3: texture}
	var sync = load("res://Scripts/world_state_sync_manager.gd").new()
	world.add_child(sync)
	sync.world = world
	var p := Vector2i(4, 3)
	var started := Time.get_ticks_usec()
	assert(world.request_server_seed_place(p))
	assert(seeds.predicted_seed_visuals.has(p), "The tree preview must exist before any server reply")
	var prediction_ms := (Time.get_ticks_usec() - started) / 1000.0
	assert(seeds.planted_seeds.is_empty(), "Prediction cannot create authoritative growth state")
	assert(world.seed_inventory.dirt_seed == 2, "Visual prediction cannot spend inventory")
	assert(not world.request_server_seed_place(p), "Holding on the same pending cell sends once")
	assert(world.request_server_seed_place(Vector2i(5, 3)))
	assert(not world.request_server_seed_place(Vector2i(6, 3)), "Reserve pending quantities")
	assert(network.sent.size() == 2)
	var first_request: String = network.sent[0].request_id
	world.reject_pending_authoritative_seed_place({"request_id": first_request, "world": "OTHER"})
	assert(seeds.predicted_seed_visuals.has(p))
	world.reject_pending_authoritative_seed_place({"request_id": first_request})
	assert(not seeds.predicted_seed_visuals.has(p))
	assert(world.request_server_seed_place(p))
	world.reject_pending_authoritative_seed_place({"request_id": first_request})
	assert(seeds.predicted_seed_visuals.has(p), "Old rejection cannot remove a new prediction")
	await create_timer(0.2).timeout
	assert(seeds.predicted_seed_visuals.has(p), "Preview remains responsive during network latency")
	var confirmation := {"world": "TEST", "action": "place", "x": 4, "y": 3, "seed_type": "dirt_seed", "grow_time": 60, "max_grow_time": 60, "planted_at": 1000}
	sync.apply_network_seed_update(confirmation)
	assert(seeds.planted_seeds.has(p) and not seeds.predicted_seed_visuals.has(p))
	var node: Node = seeds.planted_seeds[p].node
	sync.apply_network_seed_update(confirmation)
	assert(seeds.planted_seeds[p].node == node, "Duplicate confirmation must not rebuild the tree")
	for i in range(1, 4):
		if i > 1: await create_timer(0.32).timeout
		world.harvest_planted_seed(p)
		assert(world.block_hit_progress[p] == i)
		assert(node.get_node_or_null("CrackOverlay") != null, "Growing trees reuse block cracks")
		if i < 3:
			world.handle_inventory_transaction_result({"action": "seed_harvest", "ok": true, "seed_removed": false, "hit_count": i, "damage_reset_ms": 3500, "request_id": network.sent[-1].request_id})
			assert(world.block_hit_timers[p] == 3.5)
	var sent_before: int = network.sent.size()
	world.harvest_planted_seed(p)
	assert(network.sent.size() == sent_before, "Pending final hit cannot spam destruction")
	seeds.update_seed_system(30.0)
	assert(node.get_node_or_null("CrackOverlay") != null, "Stage changes must preserve cracking")
	manager.update_block_damage_recovery(4.0)
	assert(not world.block_hit_progress.has(p))
	assert(node.get_node_or_null("CrackOverlay") == null, "Stopping clears cracks")
	sync.apply_network_seed_update({"world": "TEST", "action": "hit", "x": 4, "y": 3, "planted_at": 1000, "hit_count": 2, "damage_reset_ms": 3500})
	assert(world.block_hit_progress[p] == 2, "Remote player hit updates use the same crack path")
	sync.apply_network_seed_update({"world": "TEST", "action": "remove", "x": 4, "y": 3, "planted_at": 1000})
	assert(not seeds.planted_seeds.has(p) and not world.block_hit_progress.has(p))
	assert(world.seed_harvest_pending_rollback.is_empty(), "No late hit response may resurrect a removed tree")
	confirmation.planted_at = 2000
	sync.apply_network_seed_update(confirmation)
	sync.apply_network_seed_update({"world": "TEST", "action": "remove", "x": 4, "y": 3, "planted_at": 1000})
	assert(seeds.planted_seeds.has(p), "Stale removal must not delete a replanted tree")
	confirmation.tree_created_at = 2000
	confirmation.planted_at = 10
	confirmation.grow_time = 0
	sync.apply_network_seed_update(confirmation)
	assert(seeds.is_seed_ready_to_harvest(p), "Server growth speedups keep identity and update the deadline")
	network.allow_send = false
	world.clear_pending_authoritative_seed_place(Vector2i(5, 3))
	assert(not world.request_server_seed_place(Vector2i(8, 3)))
	assert(not seeds.predicted_seed_visuals.has(Vector2i(8, 3)))
	seeds.clear()
	assert(seeds.predicted_seed_visuals.is_empty() and seeds.growing_seed_grids.is_empty())
	world.queue_free()
	network.queue_free()
	if old_network != null: old_network.queue_free()
	await process_frame
	print("SEED_PREDICTION_OK: immediate visual (", prediction_ms, "ms), 200ms delayed confirmation, quantity reservations, reject/stale replies, duplicate confirmation, hold cracks, stage transition, decay, remote hits, removal/replant, disconnect cleanup")
	quit()
