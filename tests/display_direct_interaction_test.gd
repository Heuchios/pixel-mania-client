extends SceneTree


class MockNetworkManager:
	extends Node

	var requests: Array = []

	func send_inventory_transaction_request(payload: Dictionary) -> bool:
		requests.append(payload.duplicate(true))
		return true


class MockWorld:
	extends Node2D

	const INVALID_GRID_POS := Vector2i(999999, 999999)

	var item_database: Dictionary = {
		"display_box": {"display_block": true},
		"display_case": {"display_block": true},
		"fish_hanger": {"display_block": true, "fish_hanger_block": true},
		"dirt": {"category": "block"}
	}
	var blocks: Dictionary = {}
	var display_states: Dictionary = {}
	var selected_item_type := "dirt"
	var selected_item_category := "block"
	var current_world_name := "DISPLAYTEST"
	var notifications: Array[String] = []
	var inventory_counts: Dictionary = {"block:dirt": 2, "fish:pond_fish": 1}
	var display_ui_open_count := 0
	var world_lock_manager = null

	func get_item_count(item_type: String, category: String) -> int:
		return int(inventory_counts.get(category + ":" + item_type, 0))

	func can_reach_grid(_grid_pos: Vector2i) -> bool:
		return true

	func can_current_player_interact_with_block_at(_block_type: String, _grid_pos: Vector2i) -> bool:
		return true

	func show_notification(message: String) -> void:
		notifications.append(message)

	func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
		return grid_pos

	func is_display_block_type(block_type: String) -> bool:
		return block_type == "display_box" or block_type == "display_case" or block_type == "fish_hanger"

	func is_fish_hanger_block_type(block_type: String) -> bool:
		return block_type == "fish_hanger"

	func is_entrance_gate_block(_block_type: String) -> bool:
		return false

	func can_use_entrance_gate() -> bool:
		return false

	func is_sign_block(_block_type: String) -> bool:
		return false

	func open_display_ui(_grid_pos: Vector2i) -> void:
		display_ui_open_count += 1


class TestBlockManager:
	extends "res://Scripts/block_manager.gd"

	var test_network = null

	func get_network_manager():
		return test_network


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var world := MockWorld.new()
	root.add_child(world)
	var network := MockNetworkManager.new()
	world.add_child(network)

	var box_grid := Vector2i(2, 3)
	var case_grid := Vector2i(3, 3)
	var hanger_grid := Vector2i(4, 3)
	var dirt_grid := Vector2i(5, 3)
	world.blocks[box_grid] = {"type": "display_box"}
	world.blocks[case_grid] = {"type": "display_case"}
	world.blocks[hanger_grid] = {"type": "fish_hanger"}
	world.blocks[dirt_grid] = {"type": "dirt"}

	var block_manager := TestBlockManager.new()
	block_manager.process_mode = Node.PROCESS_MODE_DISABLED
	block_manager.world = world
	block_manager.test_network = network
	world.add_child(block_manager)

	assert(block_manager.try_display_selected_item_at_grid(box_grid))
	assert(network.requests.size() == 1)
	assert(network.requests[0].get("action", "") == "display_deposit")
	assert(network.requests[0].get("item_id", "") == "dirt")
	assert(network.requests[0].get("item_category", "") == "block")
	assert(int(network.requests[0].get("amount", 0)) == 1)
	assert(not block_manager.try_display_selected_item_at_grid(hanger_grid))
	assert(not block_manager.try_display_selected_item_at_grid(dirt_grid))

	block_manager.pending_display_transactions.erase(case_grid)
	world.display_states[case_grid] = {
		"state": {
			"slot": {
				"item_id": "dirt",
				"item_type": "dirt",
				"item_category": "block",
				"amount": 1
			}
		}
	}
	assert(block_manager.try_withdraw_display_item_at_grid(case_grid))
	assert(network.requests.size() == 2)
	assert(network.requests[1].get("action", "") == "display_withdraw")
	assert(network.requests[1].get("item_id", "") == "dirt")
	block_manager.pending_display_transactions.erase(box_grid)
	assert(not block_manager.try_withdraw_display_item_at_grid(box_grid))

	world.selected_item_type = "wrench"
	world.selected_item_category = "tool"
	assert(not block_manager.try_display_selected_item_at_grid(box_grid))

	var interaction_manager_script = load("res://Scripts/interaction_manager.gd") as Script
	assert(interaction_manager_script != null)
	var interaction_manager = interaction_manager_script.new()
	interaction_manager.world = world
	world.add_child(interaction_manager)
	interaction_manager.interact_with_grid(box_grid)
	assert(world.display_ui_open_count == 0)
	assert(not world.notifications.is_empty())
	assert(world.notifications.back().contains("Select an inventory item"))

	print("[display-direct-interaction] success")
	world.queue_free()
	await process_frame
	quit(0)
