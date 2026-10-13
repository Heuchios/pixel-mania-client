extends "res://tests/dev_wings_jumping_player_fixture.gd"

var holding_jump := false
var wet := false

func is_jump_pressed() -> bool:
	return holding_jump

func get_horizontal_input_direction() -> float:
	return 0.0

func is_standing_on_water() -> bool:
	return wet
