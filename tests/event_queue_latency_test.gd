extends SceneTree

class QueueWorld extends Node:
	var removed := false
	var applied := 0
	func apply_network_block_update(data: Dictionary):
		if data.action == "break":
			removed = true
		else:
			# Controlled expensive-cell workload, not a device FPS measurement.
			var until := Time.get_ticks_usec() + 250
			while Time.get_ticks_usec() < until: pass
		applied += 1

func _initialize(): call_deferred("run")

func run():
	for legacy in [true, false]:
		var world := QueueWorld.new()
		var network = load("res://tests/break_queue_fixture.gd").new()
		network.test_world = world
		network.current_world_name = "TEST"
		var updates: Array = []
		for x in range(4096): updates.append({"action": "place", "x": x, "y": 5})
		network.handle_world_event_tile_updates({"world": "TEST", "updates": updates})
		var removal := {"action": "break", "world": "TEST", "layer": "foreground", "x": 31, "y": 5}
		var start := Time.get_ticks_usec()
		if legacy:
			# The previous committed queue function appended live changes here.
			network.world_event_tile_update_queue.append(removal)
		else:
			assert(not network.queue_world_block_update_behind_pending_event_updates(removal))
			world.apply_network_block_update(removal)
		var frames := 0
		while not world.removed:
			network.process_world_event_tile_update_queue()
			frames += 1
		print("EVENT_QUEUE_LATENCY ", JSON.stringify({"legacy": legacy, "tiles": 4096, "controlled_tile_cost_usec": 250, "frames_before_break": frames, "cpu_elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0, "scheduled_delay_at_30fps_ms": frames * 1000.0 / 30.0}))
		if not legacy: assert(frames == 0)
		network.free()
		world.free()
	print("EVENT_QUEUE_LATENCY_OK")
	quit()
