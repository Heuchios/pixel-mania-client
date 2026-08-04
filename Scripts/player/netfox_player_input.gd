extends "res://addons/netfox.extras/base-net-input.gd"

const QUEUED_PUNCH_PRESS_TICKS := 2

var movement: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var punch_pressed: bool = false
var facing_dir: int = 1
var queued_punch_press_ticks: int = 0


func _gather() -> void:
	if not is_multiplayer_authority():
		return

	var horizontal := Input.get_axis("move_left", "move_right")
	if Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0

	horizontal = clampf(horizontal, -1.0, 1.0)
	movement = Vector2(horizontal, 0.0)
	jump_pressed = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
	jump_held = Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
	punch_pressed = Input.is_action_just_pressed("punch") or queued_punch_press_ticks > 0
	if queued_punch_press_ticks > 0:
		queued_punch_press_ticks -= 1

	if absf(horizontal) > 0.01:
		facing_dir = -1 if horizontal < 0.0 else 1


func queue_punch_press() -> void:
	queued_punch_press_ticks = QUEUED_PUNCH_PRESS_TICKS


func _get_rollback_input_properties() -> Array:
	return [
		[".", "movement"],
		[".", "jump_pressed"],
		[".", "jump_held"],
		[".", "punch_pressed"],
		[".", "facing_dir"]
	]
