extends "res://Scripts/player.gd"

var fixture_world: Node
var allowed_air_jumps := -1

func get_world_controller():
	return fixture_world

func is_standing_on_water() -> bool:
	return false

func is_world_anti_gravity_enabled() -> bool:
	return false

func get_jump_velocity_multiplier() -> float:
	return 1.0

func is_in_water_for_jump_sound() -> bool:
	return false

func play_jump_sound():
	pass

func get_extra_air_jumps_allowed() -> int:
	return allowed_air_jumps
