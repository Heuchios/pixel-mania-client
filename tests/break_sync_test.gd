extends SceneTree
class TestWorld extends Node:
	var applied: Array = []
	var blocks := {Vector2i(31, 32): {"type": "dirt"}}
	var block_hit_progress := {Vector2i(31, 32): 3}
	var block_hit_timers := {Vector2i(31, 32): 0.01}
	func apply_network_block_update(data: Dictionary):
		applied.append(data)
func _initialize():
	call_deferred("run")
func run():
	var world := TestWorld.new()
	var net = load("res://tests/break_queue_fixture.gd").new()
	net.test_world = world
	net.current_world_name = "TEST"
	var tiles: Array = []
	for x in range(4096):
		tiles.append({"action": "place", "world": "TEST", "layer": "foreground", "x": x, "y": 32, "block_type": "snow"})
	net.handle_world_event_tile_updates({"world": "TEST", "updates": tiles})
	var removal := {"action": "break", "world": "TEST", "layer": "foreground", "x": 31, "y": 32}
	assert(not net.queue_world_block_update_behind_pending_event_updates(removal))
	world.apply_network_block_update(removal)
	while not net.world_event_tile_update_queue.is_empty():
		net.process_world_event_tile_update_queue()
	assert(world.applied[0].action == "break")
	for event in world.applied.slice(1):
		assert(event.x != 31, "Stale queued event restored the broken tile")
	# Later event updates remain valid (only earlier queued work is superseded).
	net.handle_world_event_tile_updates({"world": "TEST", "updates": [tiles[31]]})
	net.process_world_event_tile_update_queue()
	assert(world.applied.back().action == "place")
	var manager = load("res://tests/break_pending_fixture.gd").new()
	manager.world = world
	var pos := Vector2i(31, 32)
	var key = manager.get_authoritative_break_key("foreground", pos)
	manager.authoritative_break_request_keys[key] = {"request_id": "new", "last_check_ms": 0}
	manager.hit_block_grid(pos)
	assert(world.block_hit_progress[pos] == 3, "Holding must not advance a pending break")
	manager.update_block_damage_recovery(1.0)
	assert(manager.authoritative_break_request_keys.has(key), "Damage decay must not resend destruction")
	var response := {"x": 31, "y": 32, "layer": "foreground", "request_id": "old"}
	assert(not manager.resolve_pending_break_response(response))
	response.request_id = "new"
	response.authoritative_pending = true
	assert(not manager.resolve_pending_break_response(response))
	response.authoritative_pending = false
	assert(manager.resolve_pending_break_response(response))
	assert(not manager.authoritative_break_request_keys.has(key))
	manager.authoritative_break_request_keys[key] = {"request_id": "rejected", "world": "TEST"}
	assert(not manager.resolve_pending_break_response({"request_id": "rejected", "world": "OTHER"}))
	assert(manager.resolve_pending_break_response({"request_id": "rejected", "reason": "permission_denied"}), "Cell-less rejection must unblock its request")
	manager.free()
	net.free()
	world.free()
	print("BREAK_SYNC_OK: 4096 queued tiles, immediate removal, no stale resurrection, later events, pending hold, decay, stale replies, in-flight persistence")
	quit()
