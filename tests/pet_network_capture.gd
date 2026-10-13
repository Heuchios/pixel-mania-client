extends "res://Scripts/network_manager.gd"

var packets: Array[Dictionary] = []
var authenticated := true
var delivery := true
func _ready(): pass
func is_server_session_authenticated() -> bool: return authenticated
func _can_send_rate_limited(_key: String, _limit: int) -> bool: return true
func flush_world_position_for_payload(_payload: Dictionary) -> void: pass
func send_message(data: Dictionary) -> bool:
	if delivery: packets.append(data.duplicate(true))
	return delivery
