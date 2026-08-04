extends CharacterBody2D
class_name CustomTestPlayer

const Protocol = preload("res://custom_movement_test/scripts/custom_movement_protocol.gd")

@onready var visual_root: Node2D = get_node_or_null("Visual") as Node2D
@onready var body_polygon: Polygon2D = get_node_or_null("Visual/Body") as Polygon2D
@onready var debug_label: Label = get_node_or_null("DebugLabel") as Label

var peer_id := 0
var local_controlled := false
var server_authority := false
var facing_dir := 1
var movement_state := "idle"
var jump_hold_fall_pause_timer := 0.0


func _ready() -> void:
	set_physics_process(false)
	_apply_role_visual()


func setup(new_peer_id: int, is_local_controlled: bool, is_server_authority: bool = false) -> void:
	peer_id = int(new_peer_id)
	local_controlled = bool(is_local_controlled)
	server_authority = bool(is_server_authority)
	_apply_role_visual()


func simulate_movement_packet(packet: Dictionary, delta: float) -> void:
	var move_x: float = clamp(float(packet.get("move_x", 0.0)), -1.0, 1.0)
	var jump_pressed: bool = bool(packet.get("jump_pressed", false))
	var jump_held: bool = bool(packet.get("jump_held", jump_pressed))
	var packet_facing: int = int(packet.get("facing_dir", facing_dir))
	if packet_facing != 0:
		set_facing_dir(packet_facing)
	simulate_movement_values(move_x, jump_pressed, jump_held, delta)


func simulate_movement_values(move_x: float, jump_pressed: bool, jump_held: bool, delta: float) -> void:
	var clean_move: float = clamp(float(move_x), -1.0, 1.0)
	var target_speed: float = clean_move * Protocol.SPEED

	if absf(clean_move) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, Protocol.ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Protocol.FRICTION * delta)

	if not jump_held:
		jump_hold_fall_pause_timer = 0.0

	if jump_pressed and is_on_floor():
		velocity.y = Protocol.JUMP_VELOCITY
		jump_hold_fall_pause_timer = Protocol.JUMP_HOLD_FALL_PAUSE_TIME

	if not is_on_floor():
		if jump_held and jump_hold_fall_pause_timer > 0.0 and velocity.y >= 0.0:
			jump_hold_fall_pause_timer = maxf(0.0, jump_hold_fall_pause_timer - delta)
			velocity.y = 0.0
		else:
			var gravity_multiplier := Protocol.FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0
			velocity.y = min(velocity.y + (Protocol.GRAVITY * gravity_multiplier * delta), Protocol.MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0
		jump_hold_fall_pause_timer = 0.0

	move_and_slide()
	if is_on_floor():
		jump_hold_fall_pause_timer = 0.0
	movement_state = Protocol.movement_state_for(is_on_floor(), velocity)


func force_state(position_value: Vector2, velocity_value: Vector2, facing_value: int, state_value: String = "", pause_timer_value: float = -1.0) -> void:
	global_position = position_value
	velocity = velocity_value
	set_facing_dir(facing_value)
	if pause_timer_value >= 0.0:
		jump_hold_fall_pause_timer = pause_timer_value
	if state_value.strip_edges() != "":
		movement_state = state_value


func set_facing_dir(new_facing_dir: int) -> void:
	if int(new_facing_dir) == 0:
		return
	facing_dir = 1 if int(new_facing_dir) > 0 else -1
	if visual_root != null:
		visual_root.scale.x = float(facing_dir)


func set_debug_lines(lines: Array) -> void:
	if debug_label == null:
		return

	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += str(line)
	debug_label.text = text


func _apply_role_visual() -> void:
	if body_polygon == null:
		return

	if server_authority:
		body_polygon.color = Color(1.0, 0.73, 0.24, 1.0)
	elif local_controlled:
		body_polygon.color = Color(0.32, 0.95, 0.58, 1.0)
	else:
		body_polygon.color = Color(0.33, 0.68, 1.0, 1.0)
