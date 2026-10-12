extends SceneTree

const InventoryScene = preload("res://Scenes/ui/inventory/InventoryScene.tscn")

class DropWorld extends Node2D:
	var dropped_items: Array = []
	var player: Node2D = null
	const PICKUP_RANGE := 48

func _initialize() -> void:
	call_deferred("run")

func make_drop(id: String, cell: int, reachable: bool = true) -> Dictionary:
	return {"drop_id": id, "stack_grid_x": cell, "stack_grid_y": 1,
		"pickup_requested": true, "pickup_requested_amount": 1, "reachable": reachable}

func run() -> void:
	var world := DropWorld.new()
	var queue = load("res://tests/fixtures/pickup_queue_performance_fixture.gd").new()
	queue.world = world
	# Distant idle drops must not be repeatedly scanned between sends.
	for index in range(10000):
		world.dropped_items.append({"drop_id": "idle_%d" % index})
	var rejected := make_drop("unreachable", 1, false)
	world.dropped_items.append(rejected)
	for index in range(8):
		var drop := make_drop("pending_%d" % index, index + 2)
		world.dropped_items.append(drop)
		queue.drops_by_cell[queue.get_drop_cell_key(Vector2i(index + 2, 1))] = [drop]
	var start := Time.get_ticks_usec()
	assert(queue.process_queued_drop_pickups(true) == 4)
	print("PICKUP_QUEUE_PROBE ", {"drops": world.dropped_items.size(), "drain_usec": Time.get_ticks_usec() - start, "extra_world_scans": queue.full_scan_count})
	assert(queue.full_scan_count == 0, "Drain must reuse its pending snapshot")
	assert(not rejected.pickup_requested, "Out-of-range requests still cancel")
	assert(queue.sent_batches == [["pending_0"], ["pending_1"], ["pending_2"], ["pending_3"]])
	assert(queue.process_queued_drop_pickups(true) == 0, "In-flight limit is unchanged")
	for drop in world.dropped_items:
		queue._clear_drop_pickup_flags(drop)
	world.dropped_items.clear()
	queue.drops_by_cell.clear()
	queue.sent_batches.clear()
	queue.reset_drop_pickup_send_budget()
	# Bulk sends count all included drops, not just packets, toward the old cap.
	for index in range(6):
		world.dropped_items.append(make_drop("bulk_%d" % index, 1))
	world.dropped_items.append(make_drop("next_tile", 2))
	queue.drops_by_cell["1:1"] = world.dropped_items.slice(0, 6)
	queue.drops_by_cell["2:1"] = [world.dropped_items.back()]
	assert(queue.process_queued_drop_pickups(true) == 1)
	assert(queue.sent_batches[0].size() == 6)
	assert(not world.dropped_items.back().get("pickup_request_sent", false))
	for drop in world.dropped_items:
		queue._clear_drop_pickup_flags(drop)
	queue.mark_drop_pickup_requested(world.dropped_items.back(), 1)
	queue.fail_send = true
	queue.reset_drop_pickup_send_budget()
	assert(queue.process_queued_drop_pickups(true) == 0)
	assert(not world.dropped_items.back().pickup_requested, "Failed sends still clear pending state")
	queue.mark_drop_pickup_requested(world.dropped_items.back(), 1)
	queue.drop_pickup_busy_until_ms = Time.get_ticks_msec() + 1000
	world.dropped_items.back().reachable = false
	assert(queue.process_queued_drop_pickups(true) == 0)
	assert(not world.dropped_items.back().pickup_requested, "Busy drains still cancel unreachable requests")
	queue.free()
	world.free()

	var inventory = InventoryScene.instantiate()
	root.add_child(inventory)
	await process_frame
	for viewport_size in [Vector2(640, 360), Vector2(360, 640), Vector2(1920, 1080)]:
		inventory._fit_compact_inventory(viewport_size)
		await process_frame
		var window: Control = inventory.get_node("Window")
		var size_before := window.size
		var columns_before: int = inventory.inventory_grid.columns
		start = Time.get_ticks_usec()
		for index in range(120):
			inventory._fit_compact_inventory(viewport_size)
		var cached_usec := Time.get_ticks_usec() - start
		assert(window.size == size_before)
		assert(inventory.inventory_grid.columns == columns_before)
		start = Time.get_ticks_usec()
		for index in range(120):
			inventory._last_fit_viewport_size = Vector2(-1, -1)
			inventory._fit_compact_inventory(viewport_size)
		print("INVENTORY_LAYOUT_PROBE ", {"viewport": viewport_size, "calls": 120, "cached_usec": cached_usec, "repeated_layout_usec": Time.get_ticks_usec() - start})
		await process_frame
		assert(window.size == size_before)
		assert(inventory.inventory_grid.columns == columns_before)
	# Drawer movement still updates its transform on every call.
	inventory.set_drawer_window_transform(Vector2(100, 150), 0.75)
	var first_y: float = inventory.window.position.y
	inventory.set_drawer_window_transform(Vector2(100, 160), 0.75)
	assert(inventory.window.position.y != first_y)
	inventory.queue_free()
	await process_frame
	print("MULTIPLAYER_HOT_PATH_OK")
	quit()
