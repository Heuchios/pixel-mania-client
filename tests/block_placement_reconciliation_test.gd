extends SceneTree


class PlacementWorld:
	extends Node2D

	const WORLD_WIDTH := 200
	const WORLD_HEIGHT := 70
	const INVALID_GRID_POS := Vector2i(-999999, -999999)

	var current_world_name := "TEST"
	var blocks: Dictionary = {}
	var inventory: Dictionary = {"dirt": 20}
	var seed_inventory: Dictionary = {}
	var lure_inventory: Dictionary = {}
	var material_inventory: Dictionary = {}
	var item_database: Dictionary = {
		"dirt": {
			"category": "block",
			"placeable": true,
			"place_layer": "foreground"
		}
	}

	func refresh_area_lock_highlight_overlay() -> void:
		pass

	func refresh_ui_after_item_change(_item_type: String, _category: String) -> void:
		pass

	func clamp_item_stack_count(_item_type: String, _category: String, count: int) -> int:
		return count


class RevisionBlockManager:
	extends Node

	var confirmation_count := 0
	var pending_request_ids: Dictionary = {}

	func confirm_predicted_authoritative_place(data: Dictionary) -> bool:
		var request_id := str(data.get("request_id", data.get("action_id", "")))
		if request_id == "" or not pending_request_ids.has(request_id):
			return false
		pending_request_ids.erase(request_id)
		confirmation_count += 1
		return true

	func replace_block_without_drop(grid_pos: Vector2i, block_type: String) -> void:
		var revision_world = get_parent()
		if revision_world != null:
			revision_world.blocks[grid_pos] = {"type": block_type}


class RevisionWorld:
	extends Node

	const WORLD_WIDTH := 200
	const WORLD_HEIGHT := 70

	var current_world_name := "TEST"
	var applying_network_world_update := false
	var save_manager = null
	var block_manager: RevisionBlockManager = null
	var blocks: Dictionary = {}
	var vending_states: Dictionary = {}

	func is_vending_machine_block_type(_block_type: String) -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _make_pending(request_id: String, grid_pos: Vector2i, created_at_ms: int = -1) -> Dictionary:
	return {
		"request_id": request_id,
		"world": "TEST",
		"layer": "foreground",
		"grid_pos": grid_pos,
		"block_type": "dirt",
		"category": "block",
		"reserved_amount": 1,
		"spent_amount": 0,
		"created_at_ms": Time.get_ticks_msec() if created_at_ms < 0 else created_at_ms,
		"last_reconcile_request_ms": 0,
		"reconcile_attempts": 0
	}


func _mark_prediction(world: PlacementWorld, request_id: String, grid_pos: Vector2i) -> void:
	world.blocks[grid_pos] = {
		"type": "dirt",
		"_predicted_authoritative_place": true,
		"_predicted_request_id": request_id
	}


func _run() -> void:
	var placement_world := PlacementWorld.new()
	root.add_child(placement_world)
	var block_manager_script := load("res://Scripts/block_manager.gd") as Script
	assert(block_manager_script != null, "Could not load BlockManager.")
	var block_manager = block_manager_script.new()
	block_manager.world = placement_world
	placement_world.add_child(block_manager)

	var first_request: String = block_manager.make_authoritative_place_request_id("foreground", Vector2i(8, 9), "dirt")
	var second_request: String = block_manager.make_authoritative_place_request_id("foreground", Vector2i(8, 9), "dirt")
	assert(first_request != second_request, "Rapid placements must receive unique request IDs.")

	var current_request := "place_current"
	var current_grid := Vector2i(10, 11)
	block_manager.predicted_authoritative_place_requests[current_request] = _make_pending(current_request, current_grid)
	_mark_prediction(placement_world, current_request, current_grid)
	block_manager.handle_rejected_block_update({
		"type": "action_rejected",
		"action": "place",
		"request_id": "place_old",
		"layer": "foreground",
		"x": current_grid.x,
		"y": current_grid.y,
		"block_type": "dirt",
		"reason": "occupied"
	})
	assert(block_manager.predicted_authoritative_place_requests.has(current_request), "A delayed rejection must not roll back a newer request on the same cell.")
	assert(placement_world.blocks.has(current_grid), "A delayed rejection must not remove the newer predicted block.")

	block_manager.handle_rejected_block_update({
		"type": "action_rejected",
		"action": "place",
		"request_id": current_request,
		"layer": "foreground",
		"x": current_grid.x,
		"y": current_grid.y,
		"block_type": "dirt",
		"reason": "duplicate_request",
		"message": "Duplicate request ignored."
	})
	assert(block_manager.predicted_authoritative_place_requests.has(current_request), "A duplicate notice must reconcile instead of rolling back.")

	var timeout_request := "place_timeout"
	var timeout_grid := Vector2i(12, 13)
	block_manager.predicted_authoritative_place_requests[timeout_request] = _make_pending(
		timeout_request,
		timeout_grid,
		Time.get_ticks_msec() - block_manager.AUTHORITATIVE_PLACE_PREDICTION_TIMEOUT_MS - 1
	)
	_mark_prediction(placement_world, timeout_request, timeout_grid)
	block_manager.cleanup_expired_authoritative_place_predictions()
	assert(block_manager.predicted_authoritative_place_requests.has(timeout_request), "A client timeout must keep the prediction pending until authoritative reconciliation.")
	assert(placement_world.blocks.has(timeout_grid), "A client timeout must not remove a predicted block.")

	var parallel_request := "place_parallel"
	var parallel_grid := Vector2i(14, 15)
	block_manager.predicted_authoritative_place_requests[parallel_request] = _make_pending(parallel_request, parallel_grid)
	_mark_prediction(placement_world, parallel_request, parallel_grid)
	assert(block_manager.handle_authoritative_place_reconcile({
		"request_id": current_request,
		"world": "TEST",
		"layer": "foreground",
		"x": current_grid.x,
		"y": current_grid.y,
		"authoritative_pending": false,
		"authoritative_present": true,
		"authoritative_matches_request": true,
		"authoritative_block_type": "dirt"
	}) == "confirmed")
	assert(not block_manager.predicted_authoritative_place_requests.has(current_request), "The exact committed request must confirm.")
	assert(block_manager.predicted_authoritative_place_requests.has(parallel_request), "Confirming one rapid placement must not consume another request.")

	var reconnect_request := "place_reconnect"
	var reconnect_grid := Vector2i(16, 17)
	block_manager.predicted_authoritative_place_requests[reconnect_request] = _make_pending(reconnect_request, reconnect_grid)
	_mark_prediction(placement_world, reconnect_request, reconnect_grid)
	block_manager.reconcile_authoritative_place_predictions_after_snapshot([
		{
			"x": reconnect_grid.x,
			"y": reconnect_grid.y,
			"block_type": "dirt",
			"placement_request_id": reconnect_request,
			"block_revision": 21
		}
	], [])
	assert(not block_manager.predicted_authoritative_place_requests.has(reconnect_request), "A reconnect snapshot with the exact placement ID must confirm the prediction.")

	var revision_world := RevisionWorld.new()
	var revision_block_manager := RevisionBlockManager.new()
	revision_world.block_manager = revision_block_manager
	revision_world.add_child(revision_block_manager)
	root.add_child(revision_world)
	var sync_script := load("res://Scripts/world_state_sync_manager.gd") as Script
	assert(sync_script != null, "Could not load WorldStateSyncManager.")
	var sync_manager = sync_script.new()
	sync_manager.world = revision_world
	revision_world.add_child(sync_manager)
	sync_manager._reset_block_revision_tracking("TEST", 20)
	sync_manager._record_block_revision("foreground", Vector2i(20, 21), 20)
	assert(sync_manager._should_ignore_stale_block_update("foreground", Vector2i(20, 21), 19, false))
	assert(sync_manager._should_ignore_stale_block_update("foreground", Vector2i(20, 21), 20, false))
	assert(not sync_manager._should_ignore_stale_block_update("foreground", Vector2i(20, 21), 21, false))
	assert(not sync_manager._should_ignore_stale_block_update("foreground", Vector2i(21, 21), 19, false), "Different cells may arrive out of global order.")
	var generation_before: int = int(sync_manager.world_state_apply_generation)
	sync_manager.apply_network_world_state({"type": "world_state", "world": "TEST", "block_revision": 19})
	assert(sync_manager.world_state_apply_generation == generation_before, "An older full snapshot must not rebuild over newer live state.")
	var acknowledged_grid := Vector2i(22, 21)
	var acknowledged_request := "place_ack_without_actor"
	revision_world.blocks[acknowledged_grid] = {"type": "dirt"}
	revision_block_manager.pending_request_ids[acknowledged_request] = true
	sync_manager.apply_network_block_update({
		"type": "world_block_update",
		"world": "TEST",
		"action": "place",
		"layer": "foreground",
		"x": acknowledged_grid.x,
		"y": acknowledged_grid.y,
		"block_type": "dirt",
		"block_revision": 21,
		"request_id": acknowledged_request
	})
	assert(not revision_block_manager.pending_request_ids.has(acknowledged_request), "An exact placement acknowledgement must confirm without requiring an actor username.")
	assert(revision_block_manager.confirmation_count == 1, "A successful authoritative acknowledgement must confirm exactly once.")
	revision_block_manager.pending_request_ids["place_delayed_success"] = true
	sync_manager.apply_network_block_update({
		"type": "world_block_update",
		"world": "TEST",
		"action": "place",
		"layer": "foreground",
		"x": 20,
		"y": 21,
		"block_type": "dirt",
		"block_revision": 19,
		"request_id": "place_delayed_success"
	})
	assert(revision_block_manager.confirmation_count == 2, "A stale success may resolve its exact request but must not mutate the cell.")

	sync_manager.free()
	revision_world.free()
	block_manager.free()
	placement_world.free()
	print("[block-placement-reconciliation] success")
	quit(0)
