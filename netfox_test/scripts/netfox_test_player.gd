extends CharacterBody2D

const BODY_AUTHORITY := 1

@export var speed: float = 170.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 0.90
@export var jump_hold_fall_pause_time: float = 0.10

var owning_peer_id: int = BODY_AUTHORITY
var facing_dir: int = 1
var movement_state: String = "idle"
var rollback_tick_count: int = 0
var current_visual_animation: String = ""
var current_face_animation: String = ""
var jump_hold_fall_pause_timer: float = 0.0

@onready var player_input: Node = $PlayerInput
@onready var rollback_synchronizer: Node = $RollbackSynchronizer
@onready var tick_interpolator: Node = $TickInterpolator
@onready var debug_label: Label = $DebugLabel
@onready var player_visual: Node2D = $PlayerVisual
@onready var movement_animation_player: AnimationPlayer = $AnimationPlayer
@onready var jump_animation_player: AnimationPlayer = $Jump
@onready var idle_animation_player: AnimationPlayer = $idle
@onready var face_expression_animated: AnimatedSprite2D = $PlayerVisual/Head/FaceExpressionAnimated
@onready var test_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var dead_spirit_animated: AnimatedSprite2D = get_node_or_null("DeadSpiritAnimated") as AnimatedSprite2D


func _ready() -> void:
	setup_pixelmania_visuals()
	update_visuals()
	update_local_camera()
	update_debug_label()


func setup_authority(peer_id: int) -> void:
	owning_peer_id = peer_id
	set_multiplayer_authority(BODY_AUTHORITY)

	if player_input != null:
		player_input.set_multiplayer_authority(peer_id)

	if rollback_synchronizer != null and rollback_synchronizer.has_method("process_settings"):
		rollback_synchronizer.process_settings()

	if tick_interpolator != null and tick_interpolator.has_method("process_settings"):
		tick_interpolator.process_settings()

	update_local_camera()

	print("[NetfoxTest] player=", name,
		" peer=", peer_id,
		" body_authority=", get_multiplayer_authority(),
		" input_authority=", player_input.get_multiplayer_authority() if player_input != null else -1,
		" camera_enabled=", test_camera.enabled if test_camera != null else false,
		" path=", get_path())


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	rollback_tick_count += 1

	var input_movement := Vector2.ZERO
	var input_jump_pressed := false
	var input_jump_held := false
	var input_facing_dir := facing_dir
	if player_input != null:
		var raw_movement = player_input.get("movement")
		if raw_movement is Vector2:
			input_movement = raw_movement
		input_jump_pressed = bool(player_input.get("jump_pressed"))
		input_jump_held = bool(player_input.get("jump_held"))
		input_facing_dir = int(player_input.get("facing_dir"))

	if absf(input_movement.x) > 0.01:
		facing_dir = -1 if input_movement.x < 0.0 else 1
	elif input_facing_dir != 0:
		facing_dir = -1 if input_facing_dir < 0 else 1

	var target_x := input_movement.x * speed
	var horizontal_step := acceleration * delta if absf(input_movement.x) > 0.01 else friction * delta
	velocity.x = move_toward(velocity.x, target_x, horizontal_step)

	if not input_jump_held:
		jump_hold_fall_pause_timer = 0.0

	if not is_on_floor():
		if input_jump_held and jump_hold_fall_pause_timer > 0.0 and velocity.y >= 0.0:
			jump_hold_fall_pause_timer = maxf(0.0, jump_hold_fall_pause_timer - delta)
			velocity.y = 0.0
		else:
			var gravity_multiplier := fall_gravity_multiplier if velocity.y > 0.0 else 1.0
			velocity.y += gravity * gravity_multiplier * delta
	elif input_jump_pressed:
		velocity.y = jump_velocity
		jump_hold_fall_pause_timer = jump_hold_fall_pause_time
	else:
		jump_hold_fall_pause_timer = 0.0

	var physics_factor := float(NetworkTime.physics_factor)

	velocity *= physics_factor
	move_and_slide()
	velocity /= physics_factor
	if is_on_floor():
		jump_hold_fall_pause_timer = 0.0

	update_movement_state()


func _process(_delta: float) -> void:
	update_visuals()
	update_local_camera()
	update_debug_label()


func update_movement_state() -> void:
	if not is_on_floor():
		movement_state = "fall" if velocity.y > 0.0 else "jump"
	elif absf(velocity.x) > 6.0:
		movement_state = "run"
	else:
		movement_state = "idle"


func setup_pixelmania_visuals() -> void:
	if player_visual == null:
		return

	if dead_spirit_animated != null:
		dead_spirit_animated.visible = false

	for child in player_visual.find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite := child as AnimatedSprite2D
		if animated_sprite == null or animated_sprite.sprite_frames == null:
			continue
		if animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

	if face_expression_animated != null:
		face_expression_animated.visible = true


func update_visuals() -> void:
	update_visual_direction()
	update_face_expression()
	update_body_animation()


func update_visual_direction() -> void:
	if player_visual == null:
		return

	var base_scale_x := absf(player_visual.scale.x)
	if base_scale_x <= 0.001:
		base_scale_x = 1.0
	player_visual.scale.x = base_scale_x * float(facing_dir)


func update_face_expression() -> void:
	if face_expression_animated == null or face_expression_animated.sprite_frames == null:
		return

	var target_expression := "idle"
	if movement_state == "jump":
		target_expression = "jump"
	elif movement_state == "fall":
		target_expression = "fall"

	if current_face_animation == target_expression:
		return

	if face_expression_animated.sprite_frames.has_animation(target_expression):
		face_expression_animated.play(target_expression)
		current_face_animation = target_expression


func update_body_animation() -> void:
	var target_animation := "idle"
	if movement_state == "run":
		target_animation = "walk"
	elif movement_state == "jump" or movement_state == "fall":
		target_animation = "jump"

	if current_visual_animation == target_animation:
		return

	reset_visual_pose()
	match target_animation:
		"walk":
			play_animation_if_available(movement_animation_player, "walk")
		"jump":
			play_animation_if_available(jump_animation_player, "jump")
		_:
			play_animation_if_available(idle_animation_player, "idle")

	current_visual_animation = target_animation


func reset_visual_pose() -> void:
	for animation_player in [movement_animation_player, jump_animation_player, idle_animation_player]:
		if animation_player is AnimationPlayer:
			var player := animation_player as AnimationPlayer
			if player.has_animation("RESET"):
				player.play("RESET")
				player.advance(0.001)
				player.stop()


func play_animation_if_available(animation_player: AnimationPlayer, animation_name: String) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name)


func update_local_camera() -> void:
	if test_camera == null:
		return

	var is_local_owner := owning_peer_id == multiplayer.get_unique_id()
	test_camera.enabled = is_local_owner
	test_camera.visible = is_local_owner


func update_debug_label() -> void:
	if debug_label == null:
		return

	var input_authority := -1
	if player_input != null:
		input_authority = player_input.get_multiplayer_authority()

	var ownership_label := "LOCAL" if owning_peer_id == multiplayer.get_unique_id() else "REMOTE"
	debug_label.text = "%s peer %d\nbody %d input %d\n%s t%d" % [
		ownership_label,
		owning_peer_id,
		get_multiplayer_authority(),
		input_authority,
		movement_state,
		rollback_tick_count
	]


func _get_rollback_state_properties() -> Array:
	return [
		[".", "position"],
		[".", "velocity"],
		[".", "facing_dir"],
		[".", "movement_state"]
	]


func _get_interpolated_properties() -> Array:
	return [
		[".", "position"]
	]
