extends "res://Scripts/network_manager.gd"

var authenticated := true
var sent: Array[Dictionary] = []
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func is_server_session_authenticated() -> bool: return authenticated
func send_message(data: Dictionary) -> bool:
	sent.append(data)
	return true
