extends "res://Scripts/world_lock_manager.gd"

var test_username := "OWNER"

func get_current_player_name() -> String:
	return test_username
func _get_active_session_username() -> String:
	return test_username
func _get_active_account_id() -> String:
	return ""
func _get_active_player_profile_id() -> String:
	return ""
func _is_local_owner_session_verified() -> bool:
	return true
func _is_strict_security_mode() -> bool:
	return true
func can_current_player_manage_area_lock(area_lock: Dictionary) -> bool:
	return str(area_lock.get("owner_name", "")).to_upper() == test_username
func can_current_player_build() -> bool:
	return false
func request_save():
	pass
func refresh_area_lock_highlight_overlay():
	pass
func refresh_area_lock_block_visuals():
	pass
