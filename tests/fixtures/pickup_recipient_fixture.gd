extends "res://Scripts/drop_manager.gd"

var test_network: Node
var entries := {}
var removals: Array = []
var updates: Array = []
func get_network_manager(): return test_network
func is_drop_message_for_current_world(_data: Dictionary) -> bool: return true
func get_drop_by_id(id: String) -> Dictionary: return entries.get(id, {})
func mark_drop_id_recently_removed(_id: String) -> void: pass
func mark_drop_ids_recently_removed(_ids: Array) -> void: pass
func process_queued_drop_pickups(_force: bool = false) -> int: return 0
func trace_drop_pickup_event(_stage: String, _data: Dictionary = {}, _drop: Dictionary = {}) -> void: pass
func debug_action_position_flow(_stage: String, _data: Dictionary = {}) -> void: pass
func record_drop_pickup_server_event(_reason: String, _drop: Dictionary = {}, _extra: Dictionary = {}) -> void: pass
func remove_drop_by_id(id: String, animate: bool = false, _entire_stack: bool = false) -> bool:
	removals.append({"id": id, "animate": animate})
	return true
func apply_network_item_drop_update(data: Dictionary): updates.append(data)
