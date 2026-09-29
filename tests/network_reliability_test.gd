extends SceneTree

var failures := 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		printerr("NETWORK_RELIABILITY: ", message)

func run():
	var network = load("res://Scripts/network_manager.gd").new()
	# A connection can die after join ACK but before readiness. The next socket
	# must not inherit a lifecycle that prevents sending a fresh join request.
	network.active_join_request_id = "old_join"
	network.active_join_world_name = "AUDIT"
	network.active_join_request_pending = false
	network.world_entry_requires_ready = true
	network.pending_world_state_stream = {"world": "AUDIT"}
	network._invalidate_active_join_request_for_transport_change("test_disconnect")
	check(not network.has_incomplete_join_lifecycle_for_world("AUDIT"), "socket replacement must invalidate the snapshot/ready phase")
	check(network.pending_world_state_stream.is_empty(), "old snapshot stream must be cleared")
	# Merely inspecting a snapshot is not evidence of delivery.
	var slots := {"hand": "pickaxe"}
	check(network._should_send_full_movement_visual_sync(slots, {}, {}, "", false), "first appearance needs sync")
	check(network._should_send_full_movement_visual_sync(slots, {}, {}, "", false), "unsent appearance must remain dirty")
	# Exercise the real pacing function on the engine clock, at 60 and 144 FPS.
	for population in [2, 50]:
		network.local_position_batch_world = ""
		network.world_movement_guidance["AUDIT"] = {
			"position_batch_max_items": 38 if population == 2 else 112,
			"world_population_for_batching": population,
			"position_broadcast_interval_ms": 16 if population == 2 else 24,
		}
		var started := Time.get_ticks_msec()
		var previous := -1
		var max_gap := 0
		var sends := 0
		while Time.get_ticks_msec() - started < 1600:
			if network._consume_local_position_batch_slot("AUDIT"):
				var now := Time.get_ticks_msec()
				if previous >= 0:
					max_gap = maxi(max_gap, now - previous)
				previous = now
				sends += 1
			await create_timer(1.0 / 144.0).timeout
		print("NETWORK_PACING population=%d sends=%d max_gap_ms=%d" % [population, sends, max_gap])
		check(max_gap < 110, "pacing must not produce quota-sized silence, population=" + str(population))
		check(sends <= 52, "normal movement must be capped independently of render FPS")
	network.free()
	print("NETWORK_RELIABILITY failures=", failures)
	quit(1 if failures else 0)
