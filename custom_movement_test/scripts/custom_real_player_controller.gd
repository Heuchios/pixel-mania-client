extends CharacterBody2D
class_name CustomRealPlayerController

const Protocol = preload("res://custom_movement_test/scripts/custom_movement_protocol.gd")
const LOCAL_DRAW_Z_INDEX := 4096
const REMOTE_DRAW_Z_MAX := 3900

@onready var player_visual: Node2D = get_node_or_null("PlayerVisual") as Node2D
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var username_label: Label = get_node_or_null("UsernameLabel") as Label
@onready var debug_label: Label = get_node_or_null("DebugLabel") as Label
@onready var movement_animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var jump_animation_player: AnimationPlayer = get_node_or_null("Jump") as AnimationPlayer
@onready var idle_animation_player: AnimationPlayer = get_node_or_null("idle") as AnimationPlayer
@onready var face_expression_animated: AnimatedSprite2D = get_node_or_null("PlayerVisual/Head/FaceExpressionAnimated") as AnimatedSprite2D
@onready var dead_spirit_animated: AnimatedSprite2D = get_node_or_null("DeadSpiritAnimated") as AnimatedSprite2D
@onready var left_foot: Node2D = get_node_or_null("PlayerVisual/LeftFoot") as Node2D
@onready var right_foot: Node2D = get_node_or_null("PlayerVisual/RightFoot") as Node2D
@onready var left_arm: Node2D = get_node_or_null("PlayerVisual/LeftArm") as Node2D
@onready var right_arm: Node2D = get_node_or_null("PlayerVisual/RightArm") as Node2D
@onready var hand_item: Node2D = get_node_or_null("PlayerVisual/HandItem") as Node2D

var peer_id := 0
var local_controlled := false
var server_authority := false
var facing_dir := 1
var movement_state := "idle"
var username := ""
var jump_hold_fall_pause_timer := 0.0

var _animation_time := 0.0


func _ready() -> void:
	set_physics_process(false)
	z_as_relative = false
	_apply_role_settings()
	_update_visuals(0.0)


func _process(delta: float) -> void:
	_animation_time += delta
	_update_visuals(delta)
	_update_whole_player_sort()


func setup(new_peer_id: int, is_local_controlled: bool, is_server_authority: bool = false, display_name: String = "") -> void:
	peer_id = int(new_peer_id)
	local_controlled = bool(is_local_controlled)
	server_authority = bool(is_server_authority)
	username = display_name.strip_edges()
	if username == "":
		if server_authority:
			username = "Server %d" % peer_id
		elif local_controlled:
			username = "You %d" % peer_id
		else:
			username = "Peer %d" % peer_id
	_apply_role_settings()


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
	_update_visuals(0.0)


func set_facing_dir(new_facing_dir: int) -> void:
	if int(new_facing_dir) == 0:
		return
	facing_dir = 1 if int(new_facing_dir) > 0 else -1
	if player_visual != null:
		player_visual.scale.x = float(facing_dir)


func set_debug_lines(lines: Array) -> void:
	if debug_label == null:
		return

	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += str(line)
	debug_label.text = text


func is_camera_enabled() -> bool:
	return camera_2d != null and camera_2d.enabled


func set_camera_enabled(enabled: bool) -> void:
	if camera_2d == null:
		return
	camera_2d.enabled = enabled
	if enabled:
		camera_2d.make_current()


func _apply_role_settings() -> void:
	collision_layer = 2
	collision_mask = 1
	set_camera_enabled(local_controlled and not server_authority)

	if username_label != null:
		username_label.text = username
		username_label.visible = not server_authority
	if debug_label != null:
		debug_label.visible = not server_authority
	if dead_spirit_animated != null:
		dead_spirit_animated.visible = false


func _update_visuals(_delta: float) -> void:
	var clean_state := _normalized_movement_state()
	_update_face_expression(clean_state)
	_update_animation_players(clean_state)
	_update_layered_pose(clean_state)


func _normalized_movement_state() -> String:
	match movement_state:
		"run", "jump", "fall":
			return movement_state
		_:
			return "idle"


func _update_face_expression(clean_state: String) -> void:
	if face_expression_animated == null or face_expression_animated.sprite_frames == null:
		return

	var face_animation := "idle"
	if clean_state == "jump" or clean_state == "fall":
		face_animation = clean_state
	if not face_expression_animated.sprite_frames.has_animation(face_animation):
		return

	face_expression_animated.visible = true
	if face_expression_animated.animation != StringName(face_animation):
		face_expression_animated.play(face_animation)


func _update_animation_players(clean_state: String) -> void:
	if clean_state == "run":
		_play_animation_if_available(movement_animation_player, "walk")
		_stop_animation_if_available(jump_animation_player)
		_stop_animation_if_available(idle_animation_player)
	elif clean_state == "jump" or clean_state == "fall":
		_play_animation_if_available(jump_animation_player, "jump")
		_stop_animation_if_available(movement_animation_player)
		_stop_animation_if_available(idle_animation_player)
	else:
		_play_animation_if_available(idle_animation_player, "idle")
		_stop_animation_if_available(movement_animation_player)
		_stop_animation_if_available(jump_animation_player)


func _update_layered_pose(clean_state: String) -> void:
	_reset_layered_pose()

	if clean_state == "run":
		var stride := sin(_animation_time * 10.0)
		if left_foot != null:
			left_foot.position.y = -0.75 - max(stride, 0.0) * 1.25
		if right_foot != null:
			right_foot.position.y = -0.75 - max(-stride, 0.0) * 1.25
		if left_arm != null:
			left_arm.rotation = -stride * 0.14
		if right_arm != null:
			right_arm.rotation = 0.034906585 + stride * 0.18
		if hand_item != null:
			hand_item.rotation = stride * 0.18
	elif clean_state == "jump":
		if left_foot != null:
			left_foot.position.y = -2.0
		if right_foot != null:
			right_foot.position.y = -2.0
		if left_arm != null:
			left_arm.rotation = -0.14
		if right_arm != null:
			right_arm.rotation = 0.16
		if hand_item != null:
			hand_item.rotation = 0.16
	elif clean_state == "fall":
		if left_foot != null:
			left_foot.position.y = 1.0
		if right_foot != null:
			right_foot.position.y = 1.0
		if left_arm != null:
			left_arm.rotation = 0.08
		if right_arm != null:
			right_arm.rotation = -0.08
		if hand_item != null:
			hand_item.rotation = -0.08
	else:
		var idle_sway := sin(_animation_time * 2.75) * 0.035
		if right_arm != null:
			right_arm.rotation = 0.034906585 + idle_sway
		if hand_item != null:
			hand_item.rotation = idle_sway
		if left_arm != null:
			left_arm.rotation = -idle_sway * 0.5


func _reset_layered_pose() -> void:
	if left_foot != null:
		left_foot.position = Vector2.ZERO
		left_foot.rotation = 0.0
	if right_foot != null:
		right_foot.position = Vector2.ZERO
		right_foot.rotation = 0.0
	if left_arm != null:
		left_arm.position = Vector2.ZERO
		left_arm.rotation = 0.0
	if right_arm != null:
		right_arm.position = Vector2.ZERO
		right_arm.rotation = 0.034906585
	if hand_item != null:
		hand_item.position = Vector2.ZERO
		hand_item.rotation = 0.0


func _update_whole_player_sort() -> void:
	var foot_sort_z := int(round(global_position.y))
	if local_controlled and not server_authority:
		z_index = LOCAL_DRAW_Z_INDEX
	else:
		z_index = clampi(foot_sort_z, -4096, REMOTE_DRAW_Z_MAX)


func _play_animation_if_available(animation_player: AnimationPlayer, animation_name: String) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name or not animation_player.is_playing():
		animation_player.play(animation_name)


func _stop_animation_if_available(animation_player: AnimationPlayer) -> void:
	if animation_player == null:
		return
	if animation_player.is_playing():
		animation_player.stop()
