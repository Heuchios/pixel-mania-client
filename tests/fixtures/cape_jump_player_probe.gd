extends "res://Scripts/player.gd"

var fixture_world: Node
var accepted_jumps := 0

func get_world_controller():
	return fixture_world

func is_standing_on_water() -> bool:
	return false

func preserve_slippery_surface_for_air():
	pass

func do_jump():
	# Exercise the real try_jump and item ability gates without a physics world.
	accepted_jumps += 1
	velocity.y = JUMP_VELOCITY
