extends "res://Scripts/world_state_sync_manager.gd"

func _get_local_network_player_ids() -> Array:
	return ["local-player"]

func _get_local_session_username() -> String:
	return "LOCAL"
