extends "res://Scripts/world_lock_scene_ui.gd"

class PreviewManager:
	extends RefCounted
	func normalize_role(value: String) -> String:
		return value.to_lower()
	func get_player_access_role(_username: String) -> String:
		return "admin"
	func get_role_title(value: String) -> String:
		return value
	func is_current_player_owner() -> bool:
		return true

var preview_manager := PreviewManager.new()

func get_manager():
	return preview_manager
