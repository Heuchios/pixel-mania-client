extends "res://Scripts/block_manager.gd"

var packets: Array[Dictionary] = []
var cadence := true

func is_waiting_for_server_sign_on() -> bool: return false
func should_use_server_authoritative_world_actions() -> bool: return true
func try_consume_block_break_input_cadence() -> bool: return cadence
func try_enter_door_under_player() -> bool: return false
func send_network_block_update(action: String, layer: String, grid: Vector2i, type: String = "", extra: Dictionary = {}) -> bool:
	packets.append({"action":action,"layer":layer,"grid":grid,"type":type,"extra":extra})
	return true
func update_block_crack_visual(_grid: Vector2i): pass
func update_background_block_crack_visual(_grid: Vector2i): pass
func spawn_block_hit_particles(_grid: Vector2i, _type: String, _layer: String = "foreground"): pass
