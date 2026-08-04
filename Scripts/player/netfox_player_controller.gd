extends CharacterBody2D

const BODY_AUTHORITY := 1
const WORLD_COLLISION_LAYER_MASK := 1
const PLAYER_COLLISION_LAYER_MASK := 2
const PUNCH_VISUAL_TICKS := 18
const DEBUG_ARG := "--netfox-real-debug"
const DEBUG_ENV := "NETFOX_REAL_DEBUG"
const INTERPOLATED_POSITION_PROPERTIES: Array[String] = [".:position"]
const WORLD_COLLISION_READY_META := "netfox_tilemap_collision_stream_ready"
const WORLD_COLLISION_READY_CACHE_KEY_META := "netfox_tilemap_collision_stream_cache_key"
const SOLID_COLLISION_QUERY_MARGIN := 1.0
const SOLID_COLLISION_RECOVERY_EPSILON := 0.05
const MAX_SOLID_COLLISION_RECOVERY_ITERATIONS := 4
const PLAYER_FLOOR_MAX_ANGLE := 0.6108652381980153 # 35 degrees
const PLAYER_FLOOR_SNAP_LENGTH := 0.0
const PLAYER_SLIDE_ON_CEILING := true
const CEILING_CONTACT_FALL_START_VELOCITY := 24.0
const CEILING_CONTACT_IMPACT_FALL_RATIO := 0.08
const CEILING_CONTACT_MAX_FALL_START_VELOCITY := 36.0
const CEILING_CONTACT_NORMAL_Y_THRESHOLD := 0.35
const CEILING_CORNER_NORMAL_X_THRESHOLD := 0.15
const CEILING_UNSTICK_NUDGE := 1.0
const CEILING_CORNER_UNSTICK_NUDGE := 0.35

@export var speed: float = 170.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 0.90
@export var jump_hold_fall_pause_time: float = 0.10
@export_node_path("Node") var player_input_path: NodePath = ^"PlayerInput"
@export_node_path("Node") var rollback_synchronizer_path: NodePath = ^"RollbackSynchronizer"
@export_node_path("Node") var tick_interpolator_path: NodePath = ^"TickInterpolator"
@export_node_path("Label") var debug_label_path: NodePath = ^"DebugLabel"
@export_node_path("Label") var username_label_path: NodePath = ^"UsernameLabel"
@export_node_path("Node2D") var player_visual_path: NodePath = ^"PlayerVisual"
@export_node_path("Camera2D") var camera_path: NodePath = ^"Camera2D"

var owning_peer_id: int = BODY_AUTHORITY
var facing_dir: int = 1
var movement_state: String = "idle"
var is_punching: bool = false
var action_state: String = "none"
var rollback_tick_count: int = 0
var current_visual_animation: String = ""
var current_face_animation: String = ""
var display_name: String = ""
var debug_enabled := false
var punch_ticks_remaining: int = 0
var was_punching_last_visual_update := false
var last_visual_scale_x: float = 1.0
var last_had_control_input := false
var world_collision_wait_logged := false
var movement_config_logged := false
var jump_hold_fall_pause_timer: float = 0.0
var world_collision_ready_cached := false
var world_collision_ready_cache_key := ""

@onready var player_input: Node = get_node_or_null(player_input_path)
@onready var rollback_synchronizer: Node = get_node_or_null(rollback_synchronizer_path)
@onready var tick_interpolator: Node = get_node_or_null(tick_interpolator_path)
@onready var debug_label: Label = get_node_or_null(debug_label_path) as Label
@onready var username_label: Label = get_node_or_null(username_label_path) as Label
@onready var player_visual: Node2D = get_node_or_null(player_visual_path) as Node2D
@onready var test_camera: Camera2D = get_node_or_null(camera_path) as Camera2D
@onready var movement_animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var jump_animation_player: AnimationPlayer = get_node_or_null("Jump") as AnimationPlayer
@onready var idle_animation_player: AnimationPlayer = get_node_or_null("idle") as AnimationPlayer
@onready var face_expression_animated: AnimatedSprite2D = get_node_or_null("PlayerVisual/Head/FaceExpressionAnimated") as AnimatedSprite2D
@onready var dead_spirit_animated: AnimatedSprite2D = get_node_or_null("DeadSpiritAnimated") as AnimatedSprite2D
@onready var right_arm: Node2D = get_node_or_null("PlayerVisual/RightArm") as Node2D
@onready var hand_item: Node2D = get_node_or_null("PlayerVisual/HandItem") as Node2D


func _enter_tree() -> void:
	configure_player_collision_layers()
	configure_player_floor_collision()


func _ready() -> void:
	debug_enabled = is_netfox_debug_enabled()
	configure_player_collision_layers()
	configure_player_floor_collision()
	setup_visuals()
	_update_visuals_from_state(false)
	update_local_camera()
	update_debug_label()


func configure_player_collision_layers() -> void:
	collision_layer = PLAYER_COLLISION_LAYER_MASK
	collision_mask = WORLD_COLLISION_LAYER_MASK


func configure_player_floor_collision() -> void:
	# Diagonal block-corner hits should not briefly pause falling or ceiling-slide.
	up_direction = Vector2.UP
	floor_max_angle = PLAYER_FLOOR_MAX_ANGLE
	floor_snap_length = PLAYER_FLOOR_SNAP_LENGTH
	slide_on_ceiling = PLAYER_SLIDE_ON_CEILING


func setup_authority(peer_id: int) -> void:
	owning_peer_id = peer_id
	set_multiplayer_authority(BODY_AUTHORITY)

	if player_input != null:
		player_input.set_multiplayer_authority(peer_id)

	if rollback_synchronizer != null and rollback_synchronizer.has_method("process_settings"):
		configure_rollback_synchronizer_for_authority()
		rollback_synchronizer.process_settings()

	if tick_interpolator != null and tick_interpolator.has_method("process_settings"):
		configure_tick_interpolator_for_authority()
		tick_interpolator.process_settings()

	update_local_camera()

	print("[NetfoxPlayer] player=", name,
		" path=", get_path(),
		" peer=", peer_id,
		" body_authority=", get_multiplayer_authority(),
		" input_authority=", player_input.get_multiplayer_authority() if player_input != null else -1,
		" interpolate_position=", should_interpolate_position(),
		" camera_enabled=", test_camera.enabled if test_camera != null else false)
	log_movement_config_once()


func log_movement_config_once() -> void:
	if movement_config_logged:
		return
	movement_config_logged = true

	print("[NetfoxMovementConfig] player=%s path=%s role=%s peer=%d local_peer=%d body_authority=%d input_authority=%d speed=%.2f acceleration=%.2f friction=%.2f gravity=%.2f jump_velocity=%.2f max_fall_speed=unbounded collision_shape=%s layer=%d mask=%d physics_tick_rate=%d netfox_tick_rate=%d max_ticks_per_frame=%s sync_to_physics=%s rollback_history=%s input_delay=%s input_redundancy=%s state_sync_history=%s physics_factor=%.3f rollback_prediction=%s tick_interpolator_enabled=%s tick_interpolator_properties=%s rollback_state_properties=%s rollback_input_properties=%s" % [
		name,
		str(get_path()),
		"server" if multiplayer.is_server() else "client",
		owning_peer_id,
		get_local_peer_id(),
		get_multiplayer_authority(),
		player_input.get_multiplayer_authority() if player_input != null else -1,
		speed,
		acceleration,
		friction,
		gravity,
		jump_velocity,
		get_collision_shape_size_text(),
		collision_layer,
		collision_mask,
		Engine.physics_ticks_per_second,
		get_netfox_network_tick_rate(),
		get_project_setting_text("netfox/time/max_ticks_per_frame"),
		get_project_setting_text("netfox/time/sync_to_physics"),
		get_project_setting_text("netfox/rollback/history_limit"),
		get_project_setting_text("netfox/rollback/input_delay"),
		get_project_setting_text("netfox/rollback/input_redundancy"),
		get_project_setting_text("netfox/state_synchronizer/history_limit"),
		get_network_physics_factor(),
		str(rollback_synchronizer.get("enable_prediction") if rollback_synchronizer != null else false),
		str(tick_interpolator.get("enabled") if tick_interpolator != null else false),
		str(tick_interpolator.get("properties") if tick_interpolator != null else []),
		str(rollback_synchronizer.get("state_properties") if rollback_synchronizer != null else _get_rollback_state_properties()),
		str(rollback_synchronizer.get("input_properties") if rollback_synchronizer != null else [])
	])


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	rollback_tick_count += 1

	var input_movement := Vector2.ZERO
	var input_jump_pressed := false
	var input_jump_held := false
	var input_punch_pressed := false
	var input_facing_dir := 0
	var has_control_input := has_control_input_for_tick(tick)
	last_had_control_input = has_control_input
	if player_input != null:
		var raw_movement = player_input.get("movement")
		if raw_movement is Vector2:
			input_movement = raw_movement
		input_jump_pressed = bool(player_input.get("jump_pressed"))
		input_jump_held = bool(player_input.get("jump_held"))
		input_punch_pressed = bool(player_input.get("punch_pressed"))
		input_facing_dir = int(player_input.get("facing_dir"))

	if absf(input_movement.x) > 0.01:
		facing_dir = -1 if input_movement.x < 0.0 else 1
	elif input_facing_dir != 0:
		facing_dir = -1 if input_facing_dir < 0 else 1
	update_action_state(input_punch_pressed)

	if not is_world_collision_ready():
		velocity = Vector2.ZERO
		movement_state = "idle"
		_log_world_collision_wait_once()
		return

	if world_collision_wait_logged and debug_enabled:
		print("[NetfoxPlayer] world collision ready for ", get_path())
	world_collision_wait_logged = false

	recover_solid_block_overlap(global_position, tick, "pre-move")

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

	var rollback_physics_factor := get_rollback_physics_factor()
	if rollback_physics_factor != 1.0:
		velocity *= rollback_physics_factor
	var position_before_slide := global_position
	var horizontal_velocity_before_slide: float = velocity.x
	var vertical_velocity_before_slide: float = velocity.y
	move_and_slide()
	release_ceiling_collision_pause(horizontal_velocity_before_slide, vertical_velocity_before_slide)
	if rollback_physics_factor != 1.0:
		velocity /= rollback_physics_factor
	recover_solid_block_overlap(position_before_slide, tick, "post-move")
	report_netfox_collision_debug(tick)
	clamp_to_world_bounds()
	if is_on_floor():
		jump_hold_fall_pause_timer = 0.0

	update_movement_state()


func recover_solid_block_overlap(previous_global_position: Vector2, tick: int, reason: String) -> void:
	var total_correction := Vector2.ZERO
	var reference_rect := get_player_collision_rect_at(previous_global_position)

	for _iteration in range(MAX_SOLID_COLLISION_RECOVERY_ITERATIONS):
		var current_rect := get_player_collision_rect_at(global_position)
		var correction := get_solid_block_recovery_push(current_rect, reference_rect)
		if correction == Vector2.ZERO:
			break

		global_position += correction
		total_correction += correction
		reference_rect = get_player_collision_rect_at(global_position)

		if absf(correction.x) > 0.0:
			velocity.x = 0.0
		if absf(correction.y) > 0.0:
			velocity.y = 0.0
			if correction.y > 0.0:
				jump_hold_fall_pause_timer = 0.0

	if total_correction != Vector2.ZERO:
		report_solid_block_recovery(tick, total_correction, reason)


func release_ceiling_collision_pause(horizontal_velocity_before_slide: float = 0.0, vertical_velocity_before_slide: float = 0.0) -> void:
	if is_on_floor():
		return

	var was_moving_up: bool = vertical_velocity_before_slide < -0.01
	var has_any_slide_collision: bool = get_slide_collision_count() > 0
	var has_overhead_contact: bool = is_on_ceiling()
	var corner_nudge_x: float = 0.0
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector2 = collision.get_normal()
		if normal.y <= CEILING_CONTACT_NORMAL_Y_THRESHOLD:
			continue

		has_overhead_contact = true
		if absf(normal.x) > CEILING_CORNER_NORMAL_X_THRESHOLD:
			corner_nudge_x += 1.0 if normal.x > 0.0 else -1.0

	var should_release_overhead_contact: bool = was_moving_up and has_overhead_contact
	if not should_release_overhead_contact and not (was_moving_up and has_any_slide_collision and absf(velocity.y) <= 0.01):
		return

	jump_hold_fall_pause_timer = 0.0
	var release_fall_velocity: float = maxf(
		CEILING_CONTACT_FALL_START_VELOCITY,
		minf(absf(vertical_velocity_before_slide) * CEILING_CONTACT_IMPACT_FALL_RATIO, CEILING_CONTACT_MAX_FALL_START_VELOCITY)
	)
	velocity.y = maxf(velocity.y, release_fall_velocity)
	global_position.y += CEILING_UNSTICK_NUDGE
	if absf(horizontal_velocity_before_slide) > absf(velocity.x) and absf(horizontal_velocity_before_slide) > 0.01:
		velocity.x = horizontal_velocity_before_slide
	if absf(corner_nudge_x) > 0.01:
		global_position.x += clampf(corner_nudge_x, -1.0, 1.0) * CEILING_CORNER_UNSTICK_NUDGE


func get_player_collision_rect_at(body_global_position: Vector2) -> Rect2:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var shape_offset := Vector2.ZERO
	var effective_size := Vector2(16.0, 16.0)

	if collision_shape != null:
		shape_offset = collision_shape.position
		if collision_shape.shape is RectangleShape2D:
			var rectangle_shape := collision_shape.shape as RectangleShape2D
			effective_size = Vector2(
				absf(rectangle_shape.size.x * collision_shape.scale.x),
				absf(rectangle_shape.size.y * collision_shape.scale.y)
			)
		elif collision_shape.shape is CapsuleShape2D:
			var capsule_shape := collision_shape.shape as CapsuleShape2D
			effective_size = Vector2(
				absf(float(capsule_shape.radius) * 2.0 * collision_shape.scale.x),
				absf(float(capsule_shape.height) * collision_shape.scale.y)
			)
		elif collision_shape.shape is CircleShape2D:
			var circle_shape := collision_shape.shape as CircleShape2D
			effective_size = Vector2(
				absf(float(circle_shape.radius) * 2.0 * collision_shape.scale.x),
				absf(float(circle_shape.radius) * 2.0 * collision_shape.scale.y)
			)

	effective_size.x = maxf(1.0, effective_size.x)
	effective_size.y = maxf(1.0, effective_size.y)
	var rect_center := body_global_position + shape_offset
	return Rect2(rect_center - effective_size * 0.5, effective_size)


func get_solid_block_recovery_push(current_rect: Rect2, previous_rect: Rect2) -> Vector2:
	var world_node := get_world_node()
	if world_node == null:
		return Vector2.ZERO

	var block_manager: Variant = world_node.get("block_manager")
	if block_manager == null:
		return Vector2.ZERO

	var blocks_value: Variant = world_node.get("blocks")
	if not (blocks_value is Dictionary):
		return Vector2.ZERO
	var blocks: Dictionary = blocks_value
	if blocks.is_empty():
		return Vector2.ZERO

	var query_rect := current_rect.merge(previous_rect).grow(SOLID_COLLISION_QUERY_MARGIN)
	var candidate_grid_positions := get_candidate_grid_positions_for_rect(world_node, block_manager, query_rect)
	var best_push := Vector2.ZERO
	var best_push_length := INF

	for raw_grid_pos in candidate_grid_positions:
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		if not blocks.has(grid_pos):
			continue

		var block_data_value: Variant = blocks.get(grid_pos, {})
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		var block_type := str(block_data.get("type", "")).strip_edges().to_lower()
		if not is_solid_foreground_block(block_manager, block_type):
			continue

		var block_rect := get_foreground_block_collision_rect(world_node, block_manager, grid_pos, block_type)
		var push := Vector2.ZERO
		if current_rect.intersects(block_rect, false):
			push = get_recovery_push_for_block(current_rect, previous_rect, block_rect)
		if push == Vector2.ZERO:
			push = get_swept_recovery_push_for_block(current_rect, previous_rect, block_rect)
		if push == Vector2.ZERO:
			continue

		var push_length := push.length_squared()
		if best_push == Vector2.ZERO or push_length < best_push_length:
			best_push = push
			best_push_length = push_length

	return best_push


func get_candidate_grid_positions_for_rect(world_node: Node, block_manager: Variant, query_rect: Rect2) -> Array:
	if block_manager != null and block_manager.has_method("get_grid_positions_overlapping_rect"):
		var grid_positions_value: Variant = block_manager.get_grid_positions_overlapping_rect(query_rect)
		if grid_positions_value is Array:
			return grid_positions_value

	var block_size := get_world_float_setting(world_node, "BLOCK_SIZE", 32.0)
	var half_block := block_size * 0.5
	var min_x := int(floor((query_rect.position.x + half_block) / block_size))
	var min_y := int(floor((query_rect.position.y + half_block) / block_size))
	var max_x := int(floor((query_rect.position.x + query_rect.size.x + half_block) / block_size))
	var max_y := int(floor((query_rect.position.y + query_rect.size.y + half_block) / block_size))
	var result: Array = []

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			result.append(Vector2i(x, y))

	return result


func is_solid_foreground_block(block_manager: Variant, block_type: String) -> bool:
	if block_type == "":
		return false
	if block_manager == null or not block_manager.has_method("is_simple_full_solid_foreground_collision_block"):
		return false

	return bool(block_manager.is_simple_full_solid_foreground_collision_block(block_type))


func get_foreground_block_collision_rect(world_node: Node, block_manager: Variant, grid_pos: Vector2i, block_type: String) -> Rect2:
	if block_manager != null and block_manager.has_method("get_block_collision_rect_for_grid"):
		var rect_value: Variant = block_manager.get_block_collision_rect_for_grid(grid_pos, block_type)
		if rect_value is Rect2:
			return rect_value

	var block_size := get_world_float_setting(world_node, "BLOCK_SIZE", 32.0)
	var block_center := Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)
	var block_extent := Vector2(block_size, block_size)
	return Rect2(block_center - block_extent * 0.5, block_extent)


func get_recovery_push_for_block(current_rect: Rect2, previous_rect: Rect2, block_rect: Rect2) -> Vector2:
	var overlap := current_rect.intersection(block_rect)
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		return Vector2.ZERO

	var previous_left := previous_rect.position.x
	var previous_right := previous_rect.position.x + previous_rect.size.x
	var previous_top := previous_rect.position.y
	var previous_bottom := previous_rect.position.y + previous_rect.size.y
	var block_left := block_rect.position.x
	var block_right := block_rect.position.x + block_rect.size.x
	var block_top := block_rect.position.y
	var block_bottom := block_rect.position.y + block_rect.size.y

	if previous_bottom <= block_top:
		return add_recovery_epsilon(Vector2(0.0, -overlap.size.y))
	if previous_top >= block_bottom:
		return add_recovery_epsilon(Vector2(0.0, overlap.size.y))
	if previous_right <= block_left:
		return add_recovery_epsilon(Vector2(-overlap.size.x, 0.0))
	if previous_left >= block_right:
		return add_recovery_epsilon(Vector2(overlap.size.x, 0.0))

	var current_center := current_rect.get_center()
	var block_center := block_rect.get_center()
	var push_x := -overlap.size.x if current_center.x <= block_center.x else overlap.size.x
	var push_y := -overlap.size.y if current_center.y <= block_center.y else overlap.size.y

	if overlap.size.x < overlap.size.y:
		return add_recovery_epsilon(Vector2(push_x, 0.0))
	if overlap.size.y < overlap.size.x:
		return add_recovery_epsilon(Vector2(0.0, push_y))
	if absf(velocity.y) >= absf(velocity.x):
		return add_recovery_epsilon(Vector2(0.0, push_y))
	return add_recovery_epsilon(Vector2(push_x, 0.0))


func get_swept_recovery_push_for_block(current_rect: Rect2, previous_rect: Rect2, block_rect: Rect2) -> Vector2:
	var move_delta := current_rect.position - previous_rect.position
	if move_delta == Vector2.ZERO:
		return Vector2.ZERO

	var previous_left := previous_rect.position.x
	var previous_right := previous_rect.position.x + previous_rect.size.x
	var previous_top := previous_rect.position.y
	var previous_bottom := previous_rect.position.y + previous_rect.size.y
	var current_left := current_rect.position.x
	var current_right := current_rect.position.x + current_rect.size.x
	var current_top := current_rect.position.y
	var current_bottom := current_rect.position.y + current_rect.size.y
	var block_left := block_rect.position.x
	var block_right := block_rect.position.x + block_rect.size.x
	var block_top := block_rect.position.y
	var block_bottom := block_rect.position.y + block_rect.size.y

	var vertical_push := Vector2.ZERO
	var horizontal_push := Vector2.ZERO

	if swept_ranges_overlap(previous_left, previous_right, current_left, current_right, block_left, block_right):
		if move_delta.y > 0.0 and previous_bottom <= block_top and current_bottom > block_top:
			vertical_push = add_recovery_epsilon(Vector2(0.0, block_top - current_bottom))
		elif move_delta.y < 0.0 and previous_top >= block_bottom and current_top < block_bottom:
			vertical_push = add_recovery_epsilon(Vector2(0.0, block_bottom - current_top))

	if swept_ranges_overlap(previous_top, previous_bottom, current_top, current_bottom, block_top, block_bottom):
		if move_delta.x > 0.0 and previous_right <= block_left and current_right > block_left:
			horizontal_push = add_recovery_epsilon(Vector2(block_left - current_right, 0.0))
		elif move_delta.x < 0.0 and previous_left >= block_right and current_left < block_right:
			horizontal_push = add_recovery_epsilon(Vector2(block_right - current_left, 0.0))

	if vertical_push != Vector2.ZERO and horizontal_push != Vector2.ZERO:
		if absf(move_delta.y) >= absf(move_delta.x):
			return vertical_push
		return horizontal_push
	if vertical_push != Vector2.ZERO:
		return vertical_push
	return horizontal_push


func swept_ranges_overlap(previous_min: float, previous_max: float, current_min: float, current_max: float, block_min: float, block_max: float) -> bool:
	var sweep_min := minf(previous_min, current_min)
	var sweep_max := maxf(previous_max, current_max)
	return maxf(sweep_min, block_min) < minf(sweep_max, block_max)


func add_recovery_epsilon(push: Vector2) -> Vector2:
	if push.x < 0.0:
		push.x -= SOLID_COLLISION_RECOVERY_EPSILON
	elif push.x > 0.0:
		push.x += SOLID_COLLISION_RECOVERY_EPSILON

	if push.y < 0.0:
		push.y -= SOLID_COLLISION_RECOVERY_EPSILON
	elif push.y > 0.0:
		push.y += SOLID_COLLISION_RECOVERY_EPSILON

	return push


func report_solid_block_recovery(tick: int, correction: Vector2, reason: String) -> void:
	var netfox_manager := get_netfox_real_manager()
	if netfox_manager == null or not netfox_manager.has_method("is_netfox_collision_debug_enabled"):
		return
	if not bool(netfox_manager.call("is_netfox_collision_debug_enabled")):
		return
	if not netfox_manager.has_method("log_player_collision_debug"):
		return

	var normal := Vector2.ZERO
	if absf(correction.x) > absf(correction.y):
		normal.x = 1.0 if correction.x > 0.0 else -1.0
	elif correction.y != 0.0:
		normal.y = 1.0 if correction.y > 0.0 else -1.0

	netfox_manager.call(
		"log_player_collision_debug",
		self,
		tick,
		global_position,
		normal,
		"solid-block-recovery-" + reason
	)


func _process(_delta: float) -> void:
	_update_visuals_from_state(false)
	update_local_camera()
	update_debug_label()


func update_movement_state() -> void:
	if not is_on_floor():
		movement_state = "fall" if velocity.y > 0.0 else "jump"
	elif absf(velocity.x) > 6.0:
		movement_state = "run"
	else:
		movement_state = "idle"


func report_netfox_collision_debug(tick: int) -> void:
	var slide_count := get_slide_collision_count()
	if slide_count <= 0:
		return

	var netfox_manager := get_netfox_real_manager()
	if netfox_manager == null or not netfox_manager.has_method("is_netfox_collision_debug_enabled"):
		return
	if not bool(netfox_manager.call("is_netfox_collision_debug_enabled")):
		return
	if not netfox_manager.has_method("log_player_collision_debug"):
		return

	for index in range(slide_count):
		var collision := get_slide_collision(index)
		if collision == null:
			continue
		netfox_manager.call(
			"log_player_collision_debug",
			self,
			tick,
			collision.get_position(),
			collision.get_normal(),
			"slide-collision"
		)


func get_netfox_real_manager() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	var world_node := scene_root.get_node_or_null("World")
	if world_node == null:
		return null

	var manager = world_node.get("netfox_real_manager")
	if manager is Node:
		return manager

	return null


func update_action_state(input_punch_pressed: bool) -> void:
	if input_punch_pressed:
		punch_ticks_remaining = PUNCH_VISUAL_TICKS
	elif punch_ticks_remaining > 0:
		punch_ticks_remaining -= 1

	is_punching = punch_ticks_remaining > 0
	action_state = "punch" if is_punching else "none"


func setup_visuals() -> void:
	if dead_spirit_animated != null:
		dead_spirit_animated.visible = false

	if debug_label != null:
		debug_label.visible = debug_enabled

	setup_username_label()

	if player_visual == null:
		return

	for child in player_visual.find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite := child as AnimatedSprite2D
		if animated_sprite == null or animated_sprite.sprite_frames == null:
			continue
		if animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

	if face_expression_animated != null:
		face_expression_animated.visible = true


func setup_username_label() -> void:
	if username_label == null:
		username_label = Label.new()
		username_label.name = "UsernameLabel"
		add_child(username_label)

	username_label.position = Vector2(-48.0, -66.0)
	username_label.size = Vector2(96.0, 18.0)
	username_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	username_label.add_theme_font_size_override("font_size", 10)
	username_label.text = display_name if display_name.strip_edges() != "" else _get_default_display_name()
	username_label.visible = true


func set_display_name(new_display_name: String) -> void:
	display_name = sanitize_display_name(new_display_name)
	if display_name == "":
		display_name = _get_default_display_name()
	if username_label != null:
		username_label.text = display_name


func sanitize_display_name(raw_name: String) -> String:
	var clean_name := raw_name.strip_edges()
	if clean_name.length() > 24:
		clean_name = clean_name.substr(0, 24)
	return clean_name


func _get_default_display_name() -> String:
	if owning_peer_id > 0:
		return "Peer %d" % owning_peer_id
	return "Netfox"


func _update_visuals_from_state(is_fresh: bool) -> void:
	update_visual_direction()
	update_face_expression()
	update_body_animation()
	update_hand_item_direction()
	update_punch_visual(is_fresh)


func update_visual_direction() -> void:
	if player_visual == null:
		return

	var safe_facing := -1 if facing_dir < 0 else 1
	facing_dir = safe_facing
	var base_scale_x := absf(player_visual.scale.x)
	if base_scale_x <= 0.001:
		base_scale_x = 1.0
	player_visual.scale.x = base_scale_x * float(safe_facing)
	last_visual_scale_x = player_visual.scale.x


func update_face_expression() -> void:
	if face_expression_animated == null or face_expression_animated.sprite_frames == null:
		return

	var target_expression := "idle"
	if is_punching and face_expression_animated.sprite_frames.has_animation("punch"):
		target_expression = "punch"
	elif movement_state == "jump":
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
	if is_punching and movement_animation_player != null and movement_animation_player.has_animation("punch"):
		target_animation = "punch"
	elif movement_state == "run":
		target_animation = "walk"
	elif movement_state == "jump" or movement_state == "fall":
		target_animation = "jump"

	if current_visual_animation == target_animation:
		return

	reset_visual_pose()
	match target_animation:
		"walk":
			play_animation_if_available(movement_animation_player, "walk")
		"punch":
			play_animation_if_available(movement_animation_player, "punch")
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


func update_hand_item_direction() -> void:
	if hand_item == null:
		return

	var base_scale_x := absf(hand_item.scale.x)
	if base_scale_x <= 0.001:
		base_scale_x = 1.0
	hand_item.scale.x = base_scale_x


func update_punch_visual(is_fresh: bool) -> void:
	if not is_punching:
		if was_punching_last_visual_update:
			current_visual_animation = ""
			current_face_animation = ""
		was_punching_last_visual_update = false
		return

	if is_fresh:
		# One-time punch sounds/particles can hook here later without replaying during rollback.
		pass

	var progress := 1.0
	if PUNCH_VISUAL_TICKS > 0:
		progress = 1.0 - clampf(float(punch_ticks_remaining) / float(PUNCH_VISUAL_TICKS), 0.0, 1.0)
	var strike_weight := sin(progress * PI)
	if strike_weight < 0.05:
		strike_weight = 0.05

	if right_arm != null:
		right_arm.rotation = lerpf(right_arm.rotation, -0.95, strike_weight)
	if hand_item != null:
		hand_item.rotation = lerpf(hand_item.rotation, -0.70, strike_weight)

	was_punching_last_visual_update = true


func update_local_camera() -> void:
	if test_camera == null:
		return

	var is_local_owner := owning_peer_id == get_local_peer_id()
	if MovementMode.has_method("is_netfox_real_server_launch") and MovementMode.is_netfox_real_server_launch():
		is_local_owner = false

	test_camera.enabled = is_local_owner
	test_camera.visible = is_local_owner
	if is_local_owner:
		test_camera.make_current()


func configure_tick_interpolator_for_authority() -> void:
	if tick_interpolator == null:
		return

	var interpolate_position := should_interpolate_position()
	tick_interpolator.set("enabled", interpolate_position)
	tick_interpolator.set("enable_recording", interpolate_position)
	tick_interpolator.set("properties", INTERPOLATED_POSITION_PROPERTIES.duplicate() if interpolate_position else [])


func configure_rollback_synchronizer_for_authority() -> void:
	if rollback_synchronizer == null:
		return

	rollback_synchronizer.set("enable_prediction", false)
	rollback_synchronizer.set("enable_input_broadcast", false)


func should_interpolate_position() -> bool:
	var is_local_owner := owning_peer_id == get_local_peer_id()
	if MovementMode.has_method("is_netfox_real_server_launch") and MovementMode.is_netfox_real_server_launch():
		is_local_owner = false

	# TickInterpolator rewinds/applies visual state around rollback ticks. Keep it
	# off authoritative/server and local predicted bodies so it cannot fight the
	# CharacterBody2D state that rollback is simulating.
	if multiplayer.is_server():
		return false
	return not is_local_owner


func update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.visible = debug_enabled
	if not debug_enabled:
		return

	var input_authority := -1
	if player_input != null:
		input_authority = player_input.get_multiplayer_authority()

	var ownership_label := "LOCAL" if owning_peer_id == get_local_peer_id() else "REMOTE"
	var visual_scale_x := last_visual_scale_x
	if player_visual != null:
		visual_scale_x = player_visual.scale.x

	debug_label.text = "%s %s peer %d\nbody %d input %d data %s cam %s\nface %d visual %.1f rootz %d state %s action %s\npos %s vel %s floor %s world_ready %s\nlayer %d mask %d t%d" % [
		ownership_label,
		get_movement_mode_name(),
		owning_peer_id,
		get_multiplayer_authority(),
		input_authority,
		str(last_had_control_input),
		str(test_camera.enabled if test_camera != null else false),
		facing_dir,
		visual_scale_x,
		z_index,
		movement_state,
		action_state,
		Vector2(roundf(global_position.x), roundf(global_position.y)),
		Vector2(roundf(velocity.x), roundf(velocity.y)),
		str(is_on_floor()),
		str(is_world_collision_ready()),
		collision_layer,
		collision_mask,
		rollback_tick_count
	]


func has_control_input_for_tick(tick: int) -> bool:
	if player_input == null:
		return false

	if player_input.is_multiplayer_authority():
		return true

	if rollback_synchronizer != null and rollback_synchronizer.has_method("has_input"):
		return bool(rollback_synchronizer.call("has_input"))

	var network_rollback := get_node_or_null("/root/NetworkRollback")
	if network_rollback != null and network_rollback.has_method("has_input_for_tick"):
		return bool(network_rollback.call("has_input_for_tick", self, tick))

	return false


func get_local_peer_id() -> int:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return BODY_AUTHORITY
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return BODY_AUTHORITY
	return multiplayer.get_unique_id()


func _get_rollback_state_properties() -> Array:
	return [
		[".", "position"],
		[".", "velocity"],
		[".", "facing_dir"],
		[".", "movement_state"],
		[".", "is_punching"],
		[".", "action_state"],
		[".", "jump_hold_fall_pause_timer"]
	]


func _get_interpolated_properties() -> Array:
	return [
		[".", "position"]
	]


func is_netfox_debug_enabled() -> bool:
	if MovementMode.has_launch_arg(DEBUG_ARG):
		return true

	var env_value := OS.get_environment(DEBUG_ENV).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func get_collision_shape_size_text() -> String:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return "none"

	var shape := collision_shape.shape
	var size = shape.get("size")
	if size is Vector2:
		var effective_size := Vector2(absf(size.x * collision_shape.scale.x), absf(size.y * collision_shape.scale.y))
		return "%s raw=%s scale=%s effective=%s offset=%s" % [
			shape.get_class(),
			_format_vector2(size),
			_format_vector2(collision_shape.scale),
			_format_vector2(effective_size),
			_format_vector2(collision_shape.position)
		]

	var radius = shape.get("radius")
	var height = shape.get("height")
	if radius != null and height != null:
		var effective_radius := float(radius) * maxf(absf(collision_shape.scale.x), absf(collision_shape.scale.y))
		var effective_height := float(height) * absf(collision_shape.scale.y)
		return "%s radius=%.2f height=%.2f scale=%s effective_radius=%.2f effective_height=%.2f offset=%s" % [
			shape.get_class(),
			float(radius),
			float(height),
			_format_vector2(collision_shape.scale),
			effective_radius,
			effective_height,
			_format_vector2(collision_shape.position)
		]

	return shape.get_class()


func _format_vector2(value: Vector2) -> String:
	return "(%.2f,%.2f)" % [value.x, value.y]


func get_netfox_network_tick_rate() -> int:
	var network_time := get_node_or_null("/root/NetworkTime")
	if network_time == null:
		return 0

	var raw_tickrate = network_time.get("tickrate")
	if raw_tickrate is int or raw_tickrate is float:
		return int(raw_tickrate)

	return 0


func get_project_setting_text(setting_name: String) -> String:
	if ProjectSettings.has_setting(setting_name):
		return str(ProjectSettings.get_setting(setting_name))
	return "unset"


func get_network_physics_factor() -> float:
	var network_time := get_node_or_null("/root/NetworkTime")
	if network_time == null:
		return 1.0

	var raw_factor = network_time.get("physics_factor")
	if raw_factor is int or raw_factor is float:
		return max(0.001, float(raw_factor))

	return 1.0


func get_rollback_physics_factor() -> float:
	var factor := get_network_physics_factor()
	if not is_finite(factor) or factor <= 0.001:
		return 1.0
	return factor


func get_movement_mode_name() -> String:
	var movement_mode := get_node_or_null("/root/MovementMode")
	if movement_mode != null and movement_mode.has_method("get_mode_name"):
		return str(movement_mode.call("get_mode_name"))

	return "UNKNOWN"


func is_world_collision_ready() -> bool:
	var world_node := get_world_node()
	if world_node == null:
		clear_world_collision_ready_cache(null)
		return false

	var in_world_value = world_node.get("in_world")
	if in_world_value != null and not bool(in_world_value):
		clear_world_collision_ready_cache(world_node)
		return false

	if bool(world_node.get_meta("world_entry_in_progress", false)):
		clear_world_collision_ready_cache(world_node)
		return false

	if bool(world_node.get_meta("world_bulk_load_in_progress", false)):
		clear_world_collision_ready_cache(world_node)
		return false

	var applying_update = world_node.get("applying_network_world_update")
	if applying_update != null and bool(applying_update):
		clear_world_collision_ready_cache(world_node)
		return false

	var save_manager = world_node.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager and bool(save_manager.get("waiting_for_server_world_state")):
		clear_world_collision_ready_cache(world_node)
		return false

	var block_manager = world_node.get("block_manager")
	if block_manager == null:
		clear_world_collision_ready_cache(world_node)
		return false

	var blocks_value = world_node.get("blocks")
	if blocks_value is Dictionary and blocks_value.size() <= 0:
		clear_world_collision_ready_cache(world_node)
		return false

	var cache_key := get_world_collision_ready_cache_key(world_node, blocks_value)
	if is_cached_world_collision_ready(world_node, cache_key):
		if is_world_tilemap_collision_stream_ready(world_node):
			return true
		clear_world_collision_ready_cache(world_node)

	if not is_world_tilemap_collision_stream_ready(world_node):
		refresh_world_tilemap_collision_stream(world_node)
		if not is_world_tilemap_collision_stream_ready(world_node):
			return false

	mark_world_collision_stream_ready(world_node, cache_key)
	return true


func get_world_collision_ready_cache_key(world_node: Node, blocks_value) -> String:
	if world_node == null:
		return ""

	var world_name := ""
	var raw_world_name = world_node.get("current_world_name")
	if raw_world_name == null:
		raw_world_name = world_node.get("world_id")
	if raw_world_name != null:
		world_name = str(raw_world_name).strip_edges().to_upper()

	var block_count := 0
	if blocks_value is Dictionary:
		block_count = (blocks_value as Dictionary).size()

	var revision := 0
	var world_state_sync_manager = world_node.get("world_state_sync_manager")
	if world_state_sync_manager != null:
		var raw_generation = world_state_sync_manager.get("world_state_apply_generation")
		if raw_generation != null:
			revision = int(raw_generation)

	return "%s:%d:%d:%d" % [
		world_name,
		world_node.get_instance_id(),
		revision,
		block_count
	]


func is_cached_world_collision_ready(world_node: Node, cache_key: String) -> bool:
	if cache_key == "":
		return false
	if world_collision_ready_cached and world_collision_ready_cache_key == cache_key:
		return true
	if world_node == null:
		return false
	if not bool(world_node.get_meta(WORLD_COLLISION_READY_META, false)):
		return false
	if str(world_node.get_meta(WORLD_COLLISION_READY_CACHE_KEY_META, "")) != cache_key:
		return false

	world_collision_ready_cached = true
	world_collision_ready_cache_key = cache_key
	return true


func mark_world_collision_stream_ready(world_node: Node, cache_key: String) -> void:
	world_collision_ready_cached = cache_key != ""
	world_collision_ready_cache_key = cache_key
	if world_node == null or cache_key == "":
		return
	world_node.set_meta(WORLD_COLLISION_READY_META, true)
	world_node.set_meta(WORLD_COLLISION_READY_CACHE_KEY_META, cache_key)


func clear_world_collision_ready_cache(world_node: Node) -> void:
	world_collision_ready_cached = false
	world_collision_ready_cache_key = ""
	if world_node == null:
		return
	if world_node.has_meta(WORLD_COLLISION_READY_META):
		world_node.remove_meta(WORLD_COLLISION_READY_META)
	if world_node.has_meta(WORLD_COLLISION_READY_CACHE_KEY_META):
		world_node.remove_meta(WORLD_COLLISION_READY_CACHE_KEY_META)


func is_world_tilemap_collision_stream_ready(world_node: Node) -> bool:
	if world_node == null:
		return false

	var block_manager = world_node.get("block_manager")
	if block_manager == null:
		return false
	if block_manager.has_method("is_foreground_tilemap_collision_enabled") and not bool(block_manager.is_foreground_tilemap_collision_enabled()):
		return true

	var renderer = get_world_tilemap_renderer(block_manager)
	if renderer == null:
		return true
	if not renderer.has_method("get_streaming_summary"):
		return true

	var summary: Dictionary = renderer.get_streaming_summary()
	var cached_by_layer: Dictionary = summary.get("cached_by_layer", {})
	var active_by_layer: Dictionary = summary.get("active_by_layer", {})
	var cached_collision := int(cached_by_layer.get("foreground_collision", 0))
	if renderer.has_method("is_foreground_collision_stream_ready_for_world_positions"):
		return bool(renderer.call("is_foreground_collision_stream_ready_for_world_positions", [global_position]))
	if cached_collision > 0:
		return false

	var collision_summary: Dictionary = {}
	if block_manager.has_method("get_foreground_collision_optimization_summary"):
		collision_summary = block_manager.get_foreground_collision_optimization_summary()
		if int(collision_summary.get("ready", 0)) <= 0:
			return true

	if cached_collision <= 0:
		if not collision_summary.is_empty() and int(collision_summary.get("ready", 0)) > 0:
			return false
		return true

	var active_collision := int(active_by_layer.get("foreground_collision", 0))
	if active_collision > 0:
		return true

	return active_collision > 0


func refresh_world_tilemap_collision_stream(world_node: Node) -> void:
	if world_node == null:
		return

	var block_manager = world_node.get("block_manager")
	if block_manager == null:
		return

	var renderer = get_world_tilemap_renderer(block_manager)
	if renderer == null:
		return

	if renderer.has_method("refresh_streaming_for_world_positions"):
		renderer.call("refresh_streaming_for_world_positions", [global_position])
	elif renderer.has_method("refresh_streaming_now"):
		renderer.call("refresh_streaming_now")


func get_world_tilemap_renderer(block_manager: Node):
	if block_manager == null:
		return null
	if block_manager.has_method("ensure_tilemap_renderer"):
		return block_manager.ensure_tilemap_renderer()
	return block_manager.get("tilemap_renderer")


func _log_world_collision_wait_once() -> void:
	if not debug_enabled or world_collision_wait_logged:
		return

	world_collision_wait_logged = true
	var world_node := get_world_node()
	var blocks_count := 0
	var in_world_text := "false"
	var entry_in_progress_text := "false"
	var has_block_manager := false
	if world_node != null:
		in_world_text = str(world_node.get("in_world"))
		entry_in_progress_text = str(world_node.get_meta("world_entry_in_progress", false))
		has_block_manager = world_node.get("block_manager") != null
		var blocks_value = world_node.get("blocks")
		if blocks_value is Dictionary:
			blocks_count = blocks_value.size()

	print("[NetfoxPlayer] Waiting for world collision before rollback movement. path=%s in_world=%s entry_in_progress=%s block_manager=%s blocks=%d" % [
		get_path(),
		in_world_text,
		entry_in_progress_text,
		str(has_block_manager),
		blocks_count
	])


func clamp_to_world_bounds() -> void:
	var world_node := get_world_node()
	if world_node == null:
		return

	var block_size := get_world_float_setting(world_node, "BLOCK_SIZE", 32.0)
	var world_width := get_world_float_setting(world_node, "WORLD_WIDTH", 100.0)
	var world_height := get_world_float_setting(world_node, "WORLD_HEIGHT", 70.0)
	var min_x := 0.0
	var max_x := maxf(0.0, (world_width - 1.0) * block_size)
	var min_y := 0.0
	var max_y := maxf(0.0, (world_height - 1.0) * block_size)
	var old_position := global_position
	var clamped_position := Vector2(
		clampf(old_position.x, min_x, max_x),
		clampf(old_position.y, min_y, max_y)
	)

	if clamped_position == old_position:
		return

	global_position = clamped_position
	if clamped_position.x != old_position.x:
		velocity.x = 0.0
	if clamped_position.y != old_position.y:
		velocity.y = 0.0


func get_world_node() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var scene_world := current_scene.get_node_or_null("World")
		if scene_world != null:
			return scene_world
		if current_scene.has_method("is_player_in_world") or current_scene.get("blocks") != null:
			return current_scene

	var parent_node := get_parent()
	while parent_node != null:
		if parent_node.has_method("is_player_in_world") or parent_node.get("blocks") != null:
			return parent_node
		var sibling_world := parent_node.get_node_or_null("World")
		if sibling_world != null:
			return sibling_world
		parent_node = parent_node.get_parent()

	return get_node_or_null("/root/Main/World")


func get_world_float_setting(world_node: Node, property_name: String, fallback: float) -> float:
	if world_node == null:
		return fallback

	var raw_value = world_node.get(property_name)
	if raw_value is int or raw_value is float:
		return float(raw_value)

	return fallback
