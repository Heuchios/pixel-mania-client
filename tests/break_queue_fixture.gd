extends "res://Scripts/network_manager.gd"
var test_world: Node
func is_message_for_active_world(_data: Dictionary) -> bool:
	return true
func is_world_state_apply_in_progress() -> bool:
	return false
func get_world_node() -> Node:
	return test_world
func is_world_node_active() -> bool:
	return true
