extends "res://Scripts/block_manager.gd"

var sent_hits: Array[Dictionary] = []
var allowed_cadence := true

func trace_break_stage(_stage: String, _data: Dictionary) -> void:
	pass

func is_waiting_for_server_sign_on() -> bool:
	return false

func is_current_block_hit_punch_action() -> bool:
	return true

func should_use_server_authoritative_world_actions() -> bool:
	return true

func try_consume_block_break_input_cadence() -> bool:
	return allowed_cadence

func get_current_block_hit_source_tool() -> String:
	return "punch"

func send_network_block_update(action: String, layer: String, grid_pos: Vector2i, block_type: String = "", extra_data: Dictionary = {}) -> bool:
	sent_hits.append({"action": action, "layer": layer, "grid": grid_pos, "block_type": block_type, "extra": extra_data})
	return true

func spawn_block_hit_particles(_grid_pos: Vector2i, _block_type: String, _layer: String = "foreground"):
	pass

func play_block_hit_sound(_grid_pos: Vector2i) -> void:
	pass
