extends Node

const PLAYER_SCRIPT_PATH := "res://Scripts/player.gd"
const TILE_SIZE := 32.0
const TARGET_TILE_HEIGHT := 3.0
const COLLISION_CLEARANCE := 1.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_script = load(PLAYER_SCRIPT_PATH)
	assert(player_script is GDScript)
	var constants: Dictionary = player_script.get_script_constant_map()
	var jump_velocity := float(constants.get("JUMP_VELOCITY", 0.0))
	var springboard_velocity := float(constants.get("SPRINGBOARD_DEFAULT_JUMP_VELOCITY", 0.0))
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var physics_rate := float(Engine.physics_ticks_per_second)
	assert(jump_velocity < 0.0)
	assert(springboard_velocity == -420.0)
	assert(gravity > 0.0)
	assert(physics_rate > 0.0)

	# The takeoff frame retains the previous floor state, so gravity starts next frame.
	var velocity_y := jump_velocity
	var delta := 1.0 / physics_rate
	var displacement_y := velocity_y * delta
	while velocity_y < 0.0:
		velocity_y += gravity * delta
		if velocity_y < 0.0:
			displacement_y += velocity_y * delta

	var ascent_pixels := -displacement_y
	var required_pixels := TILE_SIZE * TARGET_TILE_HEIGHT + COLLISION_CLEARANCE
	assert(ascent_pixels >= required_pixels)
	assert(ascent_pixels < TILE_SIZE * 3.15)
	print("[normal-jump-height] success ascent=%.2fpx tiles=%.3f" % [ascent_pixels, ascent_pixels / TILE_SIZE])
	get_tree().quit(0)
