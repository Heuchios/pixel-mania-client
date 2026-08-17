extends CharacterBody2D

const PlayerShadowScript = preload("res://Scripts/player_shadow.gd")

const SPEED = 150.0
const JUMP_VELOCITY = -430.0
const GROUND_ACCELERATION = 3200.0
const AIR_ACCELERATION = 2200.0
const GROUND_FRICTION = 3400.0
const SLIPPERY_ACCELERATION = 280.0
const SLIPPERY_FRICTION = 18.0
const SLIPPERY_SPEED_MULTIPLIER = 1.65
const SLIDE_ANIMATION_MIN_SPEED = 6.0
const PUNCH_KNOCKBACK_SLIDE_DURATION = 0.38
const PUNCH_KNOCKBACK_SLIDE_ACCELERATION = 520.0
const PUNCH_KNOCKBACK_SLIDE_FRICTION = 820.0
const LEDGE_MIN_SUPPORT_WIDTH = 8.0
const LEDGE_AUTO_FALL_NUDGE = 4.0
const LEDGE_FALL_START_VELOCITY = 36.0
const JUMP_BUFFER_TIME = 0.10
const COYOTE_TIME = 0.10
const JUMP_RELEASE_VELOCITY_FACTOR = 0.55
const FALL_GRAVITY_MULTIPLIER = 0.82
const LOW_JUMP_GRAVITY_MULTIPLIER = 1.12
const MAX_FALL_SPEED = 520.0
const ANTI_GRAVITY_JUMP_MULTIPLIER = 1.15
const ANTI_GRAVITY_ASCENT_GRAVITY_MULTIPLIER = 0.88
const ANTI_GRAVITY_FALL_MULTIPLIER = 0.35
const ANTI_GRAVITY_MAX_FALL_SPEED_MULTIPLIER = 0.38
const WATER_SPEED_MULTIPLIER = 0.55
const WATER_ACCELERATION = 1200.0
const WATER_FRICTION = 1600.0
const WATER_GRAVITY_MULTIPLIER = 0.28
const WATER_MAX_FALL_SPEED = 140.0
const WATER_SWIM_JUMP_VELOCITY = -230.0
const WATER_SPLASH_MOVE_COOLDOWN = 0.34
const WATER_SPLASH_MOVE_SPEED = 45.0
const WATER_BUBBLE_INTERVAL_MIN = 2.1
const WATER_BUBBLE_INTERVAL_MAX = 4.0
const WATER_BUBBLE_INITIAL_DELAY_MIN = 0.45
const WATER_BUBBLE_INITIAL_DELAY_MAX = 1.4
const WATER_BUBBLE_MOUTH_OFFSET_X = 6.0
const WATER_BUBBLE_MOUTH_OFFSET_Y = -12.0
const WATER_SURFACE_PARTICLE_INTERVAL = 0.095
## Splash impulse fed to the rippling water surface, in px/s per unit of the
## existing particle intensity. Entry bursts arrive at 0.85-1.6 and swim wakes
## at 0.46, so this puts a hard landing near 450 px/s and a swim wake near 130.
const WATER_SURFACE_RIPPLE_IMPULSE = 280.0
const WATER_CONTACT_EDGE_INSET = 0.75
const WATER_FEET_CONTACT_HEIGHT = 2.0
const WATER_CONTACT_MIN_OVERLAP = 0.1
const BASE_BODY_Z_INDEX = 0
const BASE_BACK_Z_INDEX = -2
const BASE_FRONT_Z_INDEX = 1
const BASE_PANT_Z_INDEX = 1
const BASE_HAIR_Z_INDEX = 2
const BASE_SHOES_Z_INDEX = 2
const BASE_TOOL_Z_INDEX = 2
const BASE_PLAYER_Z_INDEX = 3900
const WATER_PLAYER_Z_INDEX_OFFSET = 0
const WATER_CHILD_Z_INDEX_OFFSET = 0
const WATER_BLOCK_ID = "water"
const SPRINGBOARD_DEFAULT_JUMP_VELOCITY = -420.0
const LAVA_BLOCK_ID = "lava"
const FIRE_BLOCK_ID = "fire"
const LAVA_DEFAULT_RADIAL_KNOCKBACK_VELOCITY = 470.0
const LAVA_FIRE_PARTICLE_INTERVAL = 0.055
const LAVA_FIRE_SOUND_INTERVAL = 0.42
const LAVA_REBOUND_CONTACT_COOLDOWN = 0.12
const INSTANT_HAZARD_DEATH_COOLDOWN = 0.45
const PINBALL_KNOCKBACK_COOLDOWN = 0.12
const PINBALL_DEFAULT_KNOCKBACK_VELOCITY = 335.0
const PINBALL_DEFAULT_VERTICAL_VELOCITY = -335.0
const PINBALL_CONTACT_MARGIN = 4.0
const INVALID_LAVA_GRID_POS = Vector2i(-999999, -999999)
const SOLID_COLLISION_QUERY_MARGIN := 1.0
const SOLID_COLLISION_RECOVERY_EPSILON := 0.05
const MAX_SOLID_COLLISION_RECOVERY_ITERATIONS := 4
## move_and_slide() resolves collisions on its own and, by design, can leave up to its own
## safe margin (~0.08px) of residual penetration afterward -- that is normal, already-correct
## physics state, not a stuck player. recover_airborne_block_corner_overlap() must only step in
## for a genuinely larger overlap (actually wedged into a corner/overhang); anything smaller than
## this is Godot's own resolution and re-correcting it here just fights move_and_slide's output,
## which produced the rubbery/jittery feel when brushing walls and corners while airborne.
const SOLID_COLLISION_RECOVERY_MIN_CORRECTION := 0.6
const SURFACE_SAMPLE_FACTORS = [-0.45, 0.0, 0.45]
const PLAYER_FLOOR_MAX_ANGLE := 0.6108652381980153 # 35 degrees
const PLAYER_FLOOR_SNAP_LENGTH := 0.0
const PLAYER_SLIDE_ON_CEILING := true
const CEILING_RELEASE_MIN_FALL_VELOCITY := 24.0
const CEILING_RELEASE_IMPACT_FALL_RATIO := 0.08
const CEILING_RELEASE_MAX_FALL_VELOCITY := 36.0
const CEILING_CONTACT_NORMAL_Y_THRESHOLD := 0.35
const CEILING_CORNER_NORMAL_X_THRESHOLD := 0.15
const CEILING_UNSTICK_NUDGE := 1.0
const CEILING_CORNER_UNSTICK_NUDGE := 0.35
## Debounce for release_airborne_block_corner_contact(), NOT a game-feel tuning knob for any
## single bonk. Flying/jumping continuously into a multi-tile ceiling can lose and re-gain
## overhead contact tile-by-tile every few frames (each tile boundary is its own legitimate,
## correctly-classified ceiling hit) while the player keeps holding upward thrust into it. Without
## a cooldown, EVERY one of those re-contacts reran the full response -- forced velocity, a 1px
## position snap, and a jump-state cancel -- once per tile, which is what reads as "bouncing off
## the corner of blocks" when sliding/flying along an uneven or multi-tile ceiling. This does not
## change how any individual release behaves, only how often a fresh one is allowed to fire.
const CEILING_RELEASE_REFIRE_COOLDOWN := 0.12
const COLLISION_TRACE_ARG := "--pm-collision-trace"
const COLLISION_TRACE_ENV := "PIXELMANIA_COLLISION_TRACE"
const COLLISION_TRACE_MAX_LINES_ENV := "PIXELMANIA_COLLISION_TRACE_MAX_LINES"
const COLLISION_TRACE_DEFAULT_MAX_LINES := 240
const COLLISION_TRACE_EDITOR_DEFAULT_MAX_LINES := 500
const COLLISION_TRACE_EDITOR_AUTO_ENABLE := true

# Back item jump rules:
# - No back item = normal single jump
# - Any normal back item = 2 total jumps
# - Legendary Wings = infinite jumps
const LEGENDARY_WINGS_ID = "legendary_wings"
const WORLD_COLLISION_LAYER_MASK := 1
const PLAYER_COLLISION_LAYER_MASK := 2
const NETFOX_MOVEMENT_NODE_NAMES := [
	"RollbackSynchronizer",
	"TickInterpolator",
	"NetfoxInput",
	"PlayerInput"
]
const NETFOX_MOVEMENT_SCRIPT_MARKERS := [
	"netfox",
	"rollback_synchronizer",
	"tick_interpolator",
	"netfox_input",
	"player_input"
]

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var air_jumps_used = 0
var jump_was_down = false
var jump_is_down = false
var jump_just_pressed = false
var jump_just_released = false
var jump_buffer_timer = 0.0
var coyote_timer = 0.0
var variable_jump_active = false
var variable_jump_release_velocity = JUMP_VELOCITY * JUMP_RELEASE_VELOCITY_FACTOR
var player_shadow = null
var last_slippery_surface_data: Dictionary = {}
var airborne_slippery_surface_data: Dictionary = {}
var cached_world_controller = null
var cached_collision_shape = null
var cached_body_sprite = null
var cached_back_sprite = null
var cached_visual_in_water := false
var cached_visual_z_valid := false
var movement_surface_cache_active := false
var movement_surface_cache_token := 0
var water_cache_token := -1
var water_cache_position := Vector2.ZERO
var water_cache_result := false
var was_standing_on_water := false
var water_splash_cooldown := 0.0
var water_surface_particle_cooldown := 0.0
var water_bubble_timer := 0.0
var was_underwater_for_bubbles := false
var lava_fire_particle_cooldown := 0.0
var lava_fire_sound_cooldown := 0.0
var lava_rebound_contact_cooldown := 0.0
var ceiling_release_refire_cooldown := 0.0
var last_lava_rebound_grid := INVALID_LAVA_GRID_POS
var instant_hazard_death_cooldown := 0.0
var instant_hazard_requires_clear := false
var pinball_knockback_cooldown := 0.0
var last_pinball_knockback_grid := INVALID_LAVA_GRID_POS
var standing_slippery_cache_token := -1
var standing_slippery_cache_position := Vector2.ZERO
var standing_slippery_cache_on_floor := false
var standing_slippery_cache_data: Dictionary = {}
var punch_knockback_slide_timer := 0.0
var collision_trace_enabled: bool = false
var collision_trace_lines_left: int = 0
var collision_trace_release_followup_frames_left: int = 0
var collision_trace_release_followup_id: int = 0


func _enter_tree() -> void:
	configure_player_collision_layers()
	configure_player_floor_collision()


func _ready():
	configure_player_collision_layers()
	configure_player_floor_collision()
	warn_if_netfox_nodes_active_in_websocket_mode()
	setup_player_collision_trace()
	cache_player_visual_nodes()
	cache_collision_shape()
	_apply_player_visual_z_indices(false)
	setup_player_shadow()


func _process(_delta: float) -> void:
	update_player_shadow()


func setup_player_shadow() -> void:
	var player_visual = get_node_or_null("PlayerVisual")
	if player_visual == null:
		return

	player_shadow = get_node_or_null("PlayerShadow")
	if player_shadow == null:
		player_shadow = Node2D.new()
		player_shadow.name = "PlayerShadow"
		player_shadow.set_script(PlayerShadowScript)
		add_child(player_shadow)

	if player_shadow.has_method("setup"):
		player_shadow.setup(player_visual)


func update_player_shadow() -> void:
	if player_shadow == null or not is_instance_valid(player_shadow):
		setup_player_shadow()


func configure_player_collision_layers() -> void:
	collision_layer = PLAYER_COLLISION_LAYER_MASK
	collision_mask = WORLD_COLLISION_LAYER_MASK


func configure_player_floor_collision() -> void:
	# Diagonal block-corner hits should not briefly pause falling or ceiling-slide.
	up_direction = Vector2.UP
	floor_max_angle = PLAYER_FLOOR_MAX_ANGLE
	floor_snap_length = PLAYER_FLOOR_SNAP_LENGTH
	slide_on_ceiling = PLAYER_SLIDE_ON_CEILING


func _physics_process(delta):
	if not MovementMode.is_websocket():
		return

	run_player_movement_step(delta)


func warn_if_netfox_nodes_active_in_websocket_mode() -> void:
	if not MovementMode.is_websocket():
		return

	if has_netfox_movement_node(self):
		print("Real player has Netfox nodes while MovementMode is WEBSOCKET. Remove/disable them for Phase 1.")


func has_netfox_movement_node(root: Node) -> bool:
	for child in root.get_children():
		if is_netfox_movement_node(child):
			return true
		if has_netfox_movement_node(child):
			return true

	return false


func is_netfox_movement_node(node: Node) -> bool:
	var node_name := str(node.name)
	if NETFOX_MOVEMENT_NODE_NAMES.has(node_name):
		return true

	var node_class_name := str(node.get_class())
	if NETFOX_MOVEMENT_NODE_NAMES.has(node_class_name):
		return true

	var script_resource = node.get_script()
	if script_resource != null:
		var script_path := str(script_resource.resource_path).to_lower()
		for marker in NETFOX_MOVEMENT_SCRIPT_MARKERS:
			if script_path.find(marker) != -1:
				return true

		if script_resource.has_method("get_global_name"):
			var global_name := str(script_resource.get_global_name())
			if NETFOX_MOVEMENT_NODE_NAMES.has(global_name):
				return true

	return false


func run_player_movement_step(delta: float) -> void:
	normalize_movement_runtime_state()
	if is_player_dead_or_respawning():
		velocity = Vector2.ZERO
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		variable_jump_active = false
		return
	movement_surface_cache_active = true
	invalidate_movement_surface_cache()
	var on_floor_before_move = is_on_floor()
	var in_water_before_move = is_standing_on_water()
	var vertical_velocity_before_move = velocity.y
	update_slippery_surface_memory()

	if on_floor_before_move:
		air_jumps_used = 0
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	var direction = 0.0
	var movement_locked = is_movement_input_locked()
	var trace_release_followup_this_frame: bool = collision_trace_release_followup_frames_left > 0

	update_jump_input_state()

	if movement_locked:
		variable_jump_active = false
	else:
		direction = get_horizontal_input_direction()

		if jump_just_pressed:
			jump_buffer_timer = JUMP_BUFFER_TIME

	if movement_locked:
		jump_buffer_timer = 0.0
	elif jump_buffer_timer > 0.0:
		if try_jump():
			jump_buffer_timer = 0.0
		else:
			jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	update_variable_jump_release()
	apply_gravity(delta)
	apply_horizontal_movement(direction, delta)
	update_punch_knockback_slide_timer(delta)

	var position_before_slide: Vector2 = global_position
	var horizontal_velocity_before_move: float = velocity.x
	var vertical_velocity_before_move_for_collision: float = velocity.y
	move_and_slide()
	var collision_trace_position_before_release: Vector2 = global_position
	var collision_trace_velocity_before_release: Vector2 = velocity
	var collision_trace_floor_before_release: bool = is_on_floor()
	var collision_trace_ceiling_before_release: bool = is_on_ceiling()
	var collision_trace_slide_info: Array = collect_collision_trace_slides() if collision_trace_enabled else []
	var released_airborne_corner_contact: bool = release_airborne_block_corner_contact(horizontal_velocity_before_move, vertical_velocity_before_move_for_collision)
	var airborne_corner_recovery: Vector2 = recover_airborne_block_corner_overlap(position_before_slide, collision_trace_slide_info)
	trace_player_collision_contact(
		horizontal_velocity_before_move,
		vertical_velocity_before_move_for_collision,
		collision_trace_position_before_release,
		collision_trace_velocity_before_release,
		collision_trace_floor_before_release,
		collision_trace_ceiling_before_release,
		collision_trace_slide_info,
		released_airborne_corner_contact
	)
	trace_airborne_corner_recovery(airborne_corner_recovery)
	if trace_release_followup_this_frame:
		trace_player_collision_release_followup(collision_trace_slide_info, released_airborne_corner_contact)
		collision_trace_release_followup_frames_left = maxi(0, collision_trace_release_followup_frames_left - 1)
	if released_airborne_corner_contact:
		collision_trace_release_followup_id += 1
		collision_trace_release_followup_frames_left = 3
	sync_multiplayer_movement_after_physics(delta)
	invalidate_movement_surface_cache()
	lava_fire_particle_cooldown = max(0.0, lava_fire_particle_cooldown - delta)
	lava_fire_sound_cooldown = max(0.0, lava_fire_sound_cooldown - delta)
	lava_rebound_contact_cooldown = max(0.0, lava_rebound_contact_cooldown - delta)
	ceiling_release_refire_cooldown = max(0.0, ceiling_release_refire_cooldown - delta)
	if lava_rebound_contact_cooldown <= 0.0:
		last_lava_rebound_grid = INVALID_LAVA_GRID_POS
	water_surface_particle_cooldown = max(0.0, water_surface_particle_cooldown - delta)
	instant_hazard_death_cooldown = max(0.0, instant_hazard_death_cooldown - delta)
	pinball_knockback_cooldown = max(0.0, pinball_knockback_cooldown - delta)
	if pinball_knockback_cooldown <= 0.0:
		last_pinball_knockback_grid = INVALID_LAVA_GRID_POS
	update_instant_hazard_contact()
	update_pinball_knockback()
	update_lava_rebound()
	update_lava_fire_contact_particles()
	update_springboard_bounce()
	update_ledge_auto_fall(vertical_velocity_before_move)
	update_player_water_depth()
	update_water_splash_particles(delta, in_water_before_move, vertical_velocity_before_move)
	update_water_surface_contact_particles()
	update_underwater_bubbles(delta)

	if is_on_floor():
		air_jumps_used = 0
		coyote_timer = COYOTE_TIME
		update_slippery_surface_memory()
	movement_surface_cache_active = false


func release_airborne_block_corner_contact(horizontal_velocity_before_move: float, vertical_velocity_before_move: float) -> bool:
	if is_on_floor():
		return false

	var was_moving_up: bool = vertical_velocity_before_move < -0.01
	var has_overhead_contact: bool = is_on_ceiling()
	# Tracks any collision this frame that pushes back with SOME downward-facing component,
	# however slight -- as opposed to has_overhead_contact below, which only counts a normal
	# once it clears the strict ceiling thresholds. This exists solely for the near-zero-
	# velocity fallback beneath the loop; a pure side-wall normal (normal.y ~= 0) must never
	# set this, or that fallback fires the ceiling-release response on an ordinary wall touch.
	var has_any_downward_facing_normal: bool = false
	var corner_nudge_x: float = 0.0
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector2 = collision.get_normal()
		if normal.y > 0.01:
			has_any_downward_facing_normal = true
		if normal.y <= CEILING_CONTACT_NORMAL_Y_THRESHOLD:
			continue
		# A block-corner normal can clear the threshold above while still being MORE horizontal
		# than vertical (e.g. (0.6, 0.4)) -- that is a wall/corner brush, not a ceiling hit, and
		# must not force the synthetic downward velocity/nudge below. Only treat contact as
		# "overhead" once it is actually more ceiling-like than wall-like.
		if normal.y <= absf(normal.x):
			continue

		has_overhead_contact = true
		if absf(normal.x) > CEILING_CORNER_NORMAL_X_THRESHOLD:
			corner_nudge_x += 1.0 if normal.x > 0.0 else -1.0

	var should_release_overhead_contact: bool = was_moving_up and has_overhead_contact
	# This fallback used to key off has_any_slide_collision (get_slide_collision_count() > 0),
	# i.e. ANY contact at all -- including a pure side-wall normal like (1, 0), whose normal.y is
	# 0 and therefore never comes close to a ceiling. Jumping alongside a wall naturally carries
	# vertical velocity through ~0 at the jump's apex; with the old check, being wall-adjacent at
	# that exact moment was enough to fire the full ceiling-release response (forced minimum fall
	# velocity, 1px downward position snap, jump-state cancellation) on a contact that was never a
	# ceiling hit. That is the bounce/jerk felt when jumping beside a wall or holding into one
	# in the air, and it fired independently of the ceiling-vs-corner normal fix above because it
	# does not go through the per-normal classification at all. Requiring an actual downward-
	# facing normal component here restricts the fallback to contacts that could plausibly be a
	# missed ceiling case, and makes it impossible for a horizontal wall touch to trigger it.
	if not should_release_overhead_contact and not (was_moving_up and has_any_downward_facing_normal and absf(velocity.y) <= 0.01):
		return false

	# See CEILING_RELEASE_REFIRE_COOLDOWN: this is a genuinely new, correctly-classified overhead
	# contact, but if one already fired within the cooldown window, skip re-applying the forced
	# velocity/position-snap/jump-cancel again. move_and_slide() itself still blocks upward motion
	# into the ceiling every frame regardless of this cooldown, so the player can never move
	# through it; this only limits how often the EXTRA "unstick" response re-fires.
	if ceiling_release_refire_cooldown > 0.0:
		return false
	ceiling_release_refire_cooldown = CEILING_RELEASE_REFIRE_COOLDOWN

	variable_jump_active = false
	coyote_timer = 0.0
	var release_fall_velocity: float = maxf(
		CEILING_RELEASE_MIN_FALL_VELOCITY,
		minf(absf(vertical_velocity_before_move) * CEILING_RELEASE_IMPACT_FALL_RATIO, CEILING_RELEASE_MAX_FALL_VELOCITY)
	)
	velocity.y = maxf(velocity.y, release_fall_velocity)
	global_position.y += CEILING_UNSTICK_NUDGE
	if absf(horizontal_velocity_before_move) > absf(velocity.x) and absf(horizontal_velocity_before_move) > 0.01:
		velocity.x = horizontal_velocity_before_move
	if absf(corner_nudge_x) > 0.01:
		global_position.x += clampf(corner_nudge_x, -1.0, 1.0) * CEILING_CORNER_UNSTICK_NUDGE
		invalidate_movement_surface_cache()
	return true


func recover_airborne_block_corner_overlap(previous_global_position: Vector2, slide_info: Array) -> Vector2:
	if is_on_floor() or get_slide_collision_count() <= 0:
		return Vector2.ZERO
	if not has_airborne_corner_or_wall_contact(slide_info):
		return Vector2.ZERO

	var total_correction := Vector2.ZERO
	var reference_rect := get_player_collision_rect_at(previous_global_position)

	for _iteration in range(MAX_SOLID_COLLISION_RECOVERY_ITERATIONS):
		var current_rect := get_player_collision_rect_at(global_position)
		var correction := get_solid_block_recovery_push(current_rect, reference_rect)
		# See SOLID_COLLISION_RECOVERY_MIN_CORRECTION: ignore sub-margin overlap that
		# move_and_slide() already considers resolved, instead of re-correcting it (and zeroing
		# velocity below) every single frame the player brushes a wall or corner.
		if correction == Vector2.ZERO or correction.length() < SOLID_COLLISION_RECOVERY_MIN_CORRECTION:
			break

		global_position += correction
		total_correction += correction
		reference_rect = get_player_collision_rect_at(global_position)
		if absf(correction.x) > 0.0:
			velocity.x = 0.0
		if correction.y > 0.0:
			velocity.y = maxf(velocity.y, CEILING_RELEASE_MIN_FALL_VELOCITY)
		elif correction.y < 0.0 and velocity.y > 0.0:
			velocity.y = 0.0

	if total_correction != Vector2.ZERO:
		invalidate_movement_surface_cache()
	return total_correction


func has_airborne_corner_or_wall_contact(slide_info: Array) -> bool:
	if slide_info.is_empty():
		for collision_index in range(get_slide_collision_count()):
			var collision: KinematicCollision2D = get_slide_collision(collision_index)
			if collision == null:
				continue
			var normal: Vector2 = collision.get_normal()
			if absf(normal.x) > CEILING_CORNER_NORMAL_X_THRESHOLD or normal.y > CEILING_CONTACT_NORMAL_Y_THRESHOLD:
				return true
		return false

	for raw_info in slide_info:
		if not (raw_info is Dictionary):
			continue
		var info: Dictionary = raw_info
		var normal_x: float = float(info.get("normal_x", 0.0))
		var normal_y: float = float(info.get("normal_y", 0.0))
		if absf(normal_x) > CEILING_CORNER_NORMAL_X_THRESHOLD or normal_y > CEILING_CONTACT_NORMAL_Y_THRESHOLD:
			return true
	return false


func setup_player_collision_trace() -> void:
	collision_trace_enabled = is_player_collision_trace_enabled()
	collision_trace_lines_left = get_player_collision_trace_max_lines()
	if collision_trace_enabled:
		print("[PM_COLLISION_TRACE] enabled max_lines=%d flag=%s env=%s editor_auto=%s" % [
			collision_trace_lines_left,
			COLLISION_TRACE_ARG,
			COLLISION_TRACE_ENV,
			str(is_player_collision_trace_editor_auto_enabled())
		])


func is_player_collision_trace_enabled() -> bool:
	if MovementMode != null and MovementMode.has_method("has_launch_arg") and bool(MovementMode.has_launch_arg(COLLISION_TRACE_ARG)):
		return true
	var env_value: String = OS.get_environment(COLLISION_TRACE_ENV).strip_edges()
	if not env_value.is_empty():
		return is_truthy_collision_trace_value(env_value)
	return is_player_collision_trace_editor_auto_enabled()


func is_player_collision_trace_editor_auto_enabled() -> bool:
	return COLLISION_TRACE_EDITOR_AUTO_ENABLE and OS.has_feature("editor")


func is_truthy_collision_trace_value(raw_value: String) -> bool:
	var clean_value: String = raw_value.strip_edges().to_lower()
	return ["1", "true", "yes", "on", "enabled"].has(clean_value)


func get_player_collision_trace_max_lines() -> int:
	var env_value: String = OS.get_environment(COLLISION_TRACE_MAX_LINES_ENV).strip_edges()
	if env_value.is_valid_int():
		return clampi(int(env_value), 1, 5000)
	if is_player_collision_trace_editor_auto_enabled():
		return COLLISION_TRACE_EDITOR_DEFAULT_MAX_LINES
	return COLLISION_TRACE_DEFAULT_MAX_LINES


func collect_collision_trace_slides() -> Array:
	var result: Array = []
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue

		var normal: Vector2 = collision.get_normal()
		var info: Dictionary = {
			"index": collision_index,
			"normal": normal,
			"normal_x": normal.x,
			"normal_y": normal.y,
			"position": collision.get_position(),
			"travel": collision.get_travel(),
			"remainder": collision.get_remainder()
		}

		var collider: Object = collision.get_collider()
		if collider is Node:
			var collider_node: Node = collider as Node
			info["collider"] = str(collider_node.get_path())
			info["collider_class"] = str(collider_node.get_class())
			if collider_node is TileMapLayer:
				var tilemap_layer: TileMapLayer = collider_node as TileMapLayer
				var collider_rid: RID = collision.get_collider_rid()
				if collider_rid.is_valid():
					var tilemap_coords: Vector2i = tilemap_layer.get_coords_for_body_rid(collider_rid)
					info["tilemap_coords"] = tilemap_coords
					info["tilemap_source"] = tilemap_layer.get_cell_source_id(tilemap_coords)
					info["tilemap_atlas"] = tilemap_layer.get_cell_atlas_coords(tilemap_coords)
		elif collider != null:
			info["collider"] = str(collider)
			info["collider_class"] = str(collider.get_class())

		var grid_pos: Vector2i = get_grid_pos_from_collision(collision)
		if grid_pos != INVALID_LAVA_GRID_POS:
			info["grid"] = grid_pos
			info["block"] = get_block_type_at_grid(grid_pos)

		var contact_grid_pos: Vector2i = get_collision_trace_contact_grid(collision)
		if contact_grid_pos != INVALID_LAVA_GRID_POS:
			info["contact_grid"] = contact_grid_pos
			info["contact_block"] = get_block_type_at_grid(contact_grid_pos)

		result.append(info)
	return result


func get_collision_trace_contact_grid(collision: KinematicCollision2D) -> Vector2i:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INVALID_LAVA_GRID_POS
	var normal: Vector2 = collision.get_normal()
	if normal.length_squared() <= 0.01:
		return INVALID_LAVA_GRID_POS
	var block_size: float = get_world_block_size(world)
	if block_size <= 0.0:
		return INVALID_LAVA_GRID_POS
	var sample_position: Vector2 = collision.get_position() - normal.normalized() * maxf(2.0, block_size * 0.08)
	return Vector2i(
		int(round(sample_position.x / block_size)),
		int(round(sample_position.y / block_size))
	)


func trace_player_collision_contact(
	horizontal_velocity_before_move: float,
	vertical_velocity_before_move: float,
	position_before_release: Vector2,
	velocity_before_release: Vector2,
	floor_before_release: bool,
	ceiling_before_release: bool,
	slide_info: Array,
	contact_released: bool
) -> void:
	if not collision_trace_enabled or collision_trace_lines_left <= 0:
		return

	var has_bottom_contact: bool = false
	var has_bottom_corner_contact: bool = false
	var has_side_or_corner_contact: bool = false
	var has_vertical_remainder_without_travel: bool = false
	for raw_info in slide_info:
		if not (raw_info is Dictionary):
			continue
		var info: Dictionary = raw_info
		var normal_x: float = float(info.get("normal_x", 0.0))
		var normal_y: float = float(info.get("normal_y", 0.0))
		var travel: Vector2 = info.get("travel", Vector2.ZERO)
		var remainder: Vector2 = info.get("remainder", Vector2.ZERO)
		if absf(normal_x) > CEILING_CORNER_NORMAL_X_THRESHOLD:
			has_side_or_corner_contact = true
		if absf(remainder.y) > 1.0 and absf(travel.y) <= 0.1:
			has_vertical_remainder_without_travel = true
		if normal_y > CEILING_CONTACT_NORMAL_Y_THRESHOLD:
			has_bottom_contact = true
			if absf(normal_x) > CEILING_CORNER_NORMAL_X_THRESHOLD:
				has_bottom_corner_contact = true

	var upward_cancelled: bool = vertical_velocity_before_move < -0.01 and absf(velocity_before_release.y) <= 0.01 and not floor_before_release
	var upward_slowed: bool = vertical_velocity_before_move < -0.01 and velocity_before_release.y > vertical_velocity_before_move + 20.0
	var horizontal_slowed: bool = absf(horizontal_velocity_before_move) > 0.01 and absf(velocity_before_release.x) < absf(horizontal_velocity_before_move) * 0.65
	var vertical_blocked: bool = not floor_before_release and vertical_velocity_before_move > 20.0 and has_vertical_remainder_without_travel
	var suspicious_airborne_side_contact: bool = not floor_before_release and has_side_or_corner_contact and (upward_slowed or vertical_blocked or absf(velocity_before_release.y) <= 0.01)
	if not (has_bottom_contact or has_bottom_corner_contact or suspicious_airborne_side_contact or upward_cancelled or ceiling_before_release or contact_released):
		return

	collision_trace_lines_left -= 1
	print("[PM_COLLISION_TRACE] bottom=%s bottom_corner=%s side_or_corner=%s released=%s upward_cancelled=%s upward_slowed=%s horizontal_slowed=%s vertical_blocked=%s pos_before_release=%s pos_after_release=%s vel_before_slide=%s vel_before_release=%s vel_after_release=%s floor_before=%s ceiling_before=%s floor_after=%s ceiling_after=%s slides=%s lines_left=%d" % [
		str(has_bottom_contact),
		str(has_bottom_corner_contact),
		str(has_side_or_corner_contact),
		str(contact_released),
		str(upward_cancelled),
		str(upward_slowed),
		str(horizontal_slowed),
		str(vertical_blocked),
		format_collision_trace_vector(position_before_release),
		format_collision_trace_vector(global_position),
		format_collision_trace_vector(Vector2(horizontal_velocity_before_move, vertical_velocity_before_move)),
		format_collision_trace_vector(velocity_before_release),
		format_collision_trace_vector(velocity),
		str(floor_before_release),
		str(ceiling_before_release),
		str(is_on_floor()),
		str(is_on_ceiling()),
		format_collision_trace_slides(slide_info),
		collision_trace_lines_left
	])


func trace_player_collision_release_followup(slide_info: Array, released_again: bool) -> void:
	if not collision_trace_enabled or collision_trace_lines_left <= 0:
		return
	collision_trace_lines_left -= 1
	print("[PM_COLLISION_TRACE_FOLLOWUP] id=%d frames_left=%d released_again=%s pos=%s vel=%s floor=%s ceiling=%s slides=%d slide_info=%s lines_left=%d" % [
		collision_trace_release_followup_id,
		collision_trace_release_followup_frames_left,
		str(released_again),
		format_collision_trace_vector(global_position),
		format_collision_trace_vector(velocity),
		str(is_on_floor()),
		str(is_on_ceiling()),
		get_slide_collision_count(),
		format_collision_trace_slides(slide_info),
		collision_trace_lines_left
	])


func trace_airborne_corner_recovery(correction: Vector2) -> void:
	if correction == Vector2.ZERO or not collision_trace_enabled or collision_trace_lines_left <= 0:
		return
	collision_trace_lines_left -= 1
	print("[PM_COLLISION_RECOVERY] correction=%s pos=%s vel=%s floor=%s ceiling=%s slides=%d lines_left=%d" % [
		format_collision_trace_vector(correction),
		format_collision_trace_vector(global_position),
		format_collision_trace_vector(velocity),
		str(is_on_floor()),
		str(is_on_ceiling()),
		get_slide_collision_count(),
		collision_trace_lines_left
	])


func format_collision_trace_vector(value: Vector2) -> String:
	return "(%.2f, %.2f)" % [value.x, value.y]


func format_collision_trace_slides(slide_info: Array) -> String:
	var parts: Array = []
	for raw_info in slide_info:
		if not (raw_info is Dictionary):
			continue
		var info: Dictionary = raw_info
		var text: String = "#%d n=%s pos=%s travel=%s remainder=%s collider=%s" % [
			int(info.get("index", -1)),
			format_collision_trace_vector(info.get("normal", Vector2.ZERO)),
			format_collision_trace_vector(info.get("position", Vector2.ZERO)),
			format_collision_trace_vector(info.get("travel", Vector2.ZERO)),
			format_collision_trace_vector(info.get("remainder", Vector2.ZERO)),
			str(info.get("collider", ""))
		]
		if info.has("grid"):
			text += " grid=%s block=%s" % [str(info.get("grid")), str(info.get("block", ""))]
		if info.has("contact_grid"):
			text += " contact_grid=%s contact_block=%s" % [str(info.get("contact_grid")), str(info.get("contact_block", ""))]
		if info.has("tilemap_coords"):
			text += " tilemap_coords=%s source=%s atlas=%s" % [
				str(info.get("tilemap_coords")),
				str(info.get("tilemap_source", "")),
				str(info.get("tilemap_atlas", ""))
			]
		parts.append(text)
	return "[" + "; ".join(parts) + "]"


func sync_multiplayer_movement_after_physics(delta: float) -> void:
	if not MovementMode.is_websocket():
		return

	var w = get_world_controller()
	if w == null or not is_instance_valid(w):
		return

	# This flag tells PlayerManager to ignore the old render-frame movement send
	# from World._process(), preventing device/FPS-dependent packet timing.
	set_meta("multiplayer_movement_sync_from_physics", true)

	var manager = null
	if "player_manager" in w:
		manager = w.player_manager

	if manager != null:
		if manager.has_method("update_multiplayer_movement"):
			manager.update_multiplayer_movement(delta, true)
		# Keep remote root movement on the same fixed physics clock as the local
		# player/camera. This reduces camera-relative jitter when both players move.
		if manager.has_method("update_remote_player_positions_from_physics"):
			manager.update_remote_player_positions_from_physics(delta)
		return

	# Fallback for older worlds. The patched PlayerManager path above is preferred.
	if w.has_method("update_multiplayer_movement"):
		w.update_multiplayer_movement(delta)


func get_player_collision_rect_at(body_global_position: Vector2) -> Rect2:
	var collision_shape := cache_collision_shape() as CollisionShape2D
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

	effective_size.x = maxf(1.0, effective_size.x)
	effective_size.y = maxf(1.0, effective_size.y)
	var rect_center := body_global_position + shape_offset
	return Rect2(rect_center - effective_size * 0.5, effective_size)


func get_solid_block_recovery_push(current_rect: Rect2, previous_rect: Rect2) -> Vector2:
	var world_node := get_world_controller() as Node
	if world_node == null:
		return Vector2.ZERO

	var block_manager: Variant = world_node.get("block_manager")
	var blocks_value: Variant = world_node.get("blocks")
	if not (blocks_value is Dictionary):
		return Vector2.ZERO
	var blocks: Dictionary = blocks_value
	if blocks.is_empty():
		return Vector2.ZERO

	var query_rect := current_rect.merge(previous_rect).grow(SOLID_COLLISION_QUERY_MARGIN)
	var candidate_grid_positions := get_candidate_grid_positions_for_rect(world_node, block_manager, query_rect)
	var best_push := Vector2.ZERO
	var best_push_length: float = INF

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
		var block_type: String = str(block_data.get("type", "")).strip_edges().to_lower()
		if not is_solid_foreground_recovery_block(world_node, block_manager, block_type):
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

	var block_size := get_world_block_size(world_node)
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


func is_solid_foreground_recovery_block(world_node: Node, block_manager: Variant, block_type: String) -> bool:
	if block_type == "":
		return false
	if block_manager != null and block_manager.has_method("is_simple_full_solid_foreground_collision_block"):
		return bool(block_manager.is_simple_full_solid_foreground_collision_block(block_type))
	return is_floor_support_block_type(world_node, block_type)


func get_foreground_block_collision_rect(world_node: Node, block_manager: Variant, grid_pos: Vector2i, block_type: String) -> Rect2:
	if block_manager != null and block_manager.has_method("get_block_collision_rect_for_grid"):
		var rect_value: Variant = block_manager.get_block_collision_rect_for_grid(grid_pos, block_type)
		if rect_value is Rect2:
			return rect_value

	var block_size := get_world_block_size(world_node)
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

	# None of the four checks above matched, which means the player's rect was not cleanly
	# outside the block on any single side even in the PREVIOUS frame -- i.e. this is sustained,
	# ambiguous multi-frame contact (e.g. climbing alongside a wall while holding into a
	# protruding block corner), not a "just became embedded from one clear direction" event.
	# This used to guess a push axis by comparing overlap.size.x vs overlap.size.y and eject the
	# player that way every frame the ambiguous overlap persisted. move_and_slide() already
	# resolves this kind of continuous corner contact correctly on its own each frame; guessing
	# an axis and teleporting the player out of it here fights the player's own held input
	# (pressing back into the same corner immediately re-creates the same overlap next frame),
	# producing a repeating push-resist-push cycle -- the "bounced back from the corner" feel
	# reported when holding movement into a wall/corner while airborne. Leaving this case alone
	# and trusting move_and_slide()'s own resolution is the fix; only the four unambiguous
	# "definitely embedded from one clear side" cases above still get an active recovery push.
	return Vector2.ZERO


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


func normalize_movement_runtime_state() -> void:
	air_jumps_used = maxi(0, int(safe_movement_number(air_jumps_used, 0.0)))
	jump_was_down = safe_movement_bool(jump_was_down, false)
	jump_is_down = safe_movement_bool(jump_is_down, false)
	jump_just_pressed = safe_movement_bool(jump_just_pressed, false)
	jump_just_released = safe_movement_bool(jump_just_released, false)
	jump_buffer_timer = safe_movement_number(jump_buffer_timer, 0.0)
	coyote_timer = safe_movement_number(coyote_timer, 0.0)
	variable_jump_active = safe_movement_bool(variable_jump_active, false)
	variable_jump_release_velocity = safe_movement_number(variable_jump_release_velocity, JUMP_VELOCITY * JUMP_RELEASE_VELOCITY_FACTOR)
	water_splash_cooldown = safe_movement_number(water_splash_cooldown, 0.0)
	pinball_knockback_cooldown = safe_movement_number(pinball_knockback_cooldown, 0.0)
	punch_knockback_slide_timer = safe_movement_number(punch_knockback_slide_timer, 0.0)

	if not (last_slippery_surface_data is Dictionary):
		last_slippery_surface_data = {}
	if not (airborne_slippery_surface_data is Dictionary):
		airborne_slippery_surface_data = {}


func safe_movement_number(value, fallback: float = 0.0) -> float:
	if value is int or value is float:
		var number := float(value)
		if is_finite(number):
			return number

	return fallback


func safe_movement_bool(value, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0

	return fallback


func invalidate_movement_surface_cache():
	movement_surface_cache_token += 1
	water_cache_token = -1
	standing_slippery_cache_token = -1


func update_slippery_surface_memory():
	if is_standing_on_water():
		last_slippery_surface_data.clear()
		airborne_slippery_surface_data.clear()
		return

	if not is_on_floor():
		return

	var standing_slippery_surface_data = get_standing_slippery_surface_data()
	if standing_slippery_surface_data.is_empty():
		last_slippery_surface_data.clear()
		airborne_slippery_surface_data.clear()
	else:
		last_slippery_surface_data = standing_slippery_surface_data.duplicate(true)


func preserve_slippery_surface_for_air():
	var standing_slippery_surface_data = get_standing_slippery_surface_data()
	if standing_slippery_surface_data.is_empty():
		standing_slippery_surface_data = last_slippery_surface_data

	if standing_slippery_surface_data.is_empty():
		airborne_slippery_surface_data.clear()
	else:
		airborne_slippery_surface_data = standing_slippery_surface_data.duplicate(true)


func get_active_slippery_surface_data() -> Dictionary:
	var standing_slippery_surface_data = get_standing_slippery_surface_data()
	if not standing_slippery_surface_data.is_empty():
		return standing_slippery_surface_data

	if not is_on_floor() and not airborne_slippery_surface_data.is_empty():
		return airborne_slippery_surface_data

	return {}


func is_sliding_on_slideable_surface() -> bool:
	if not is_on_floor():
		return false

	if is_standing_on_water():
		return false

	if abs(velocity.x) <= SLIDE_ANIMATION_MIN_SPEED:
		return false

	if is_punch_knockback_sliding():
		return true

	return not get_active_slippery_surface_data().is_empty()


func apply_player_punch_slide(knockback_x: float, duration: float = PUNCH_KNOCKBACK_SLIDE_DURATION) -> void:
	var safe_knockback_x: float = clampf(knockback_x, -1200.0, 1200.0)
	if abs(safe_knockback_x) <= 0.01:
		return

	velocity.x = safe_knockback_x
	punch_knockback_slide_timer = maxf(punch_knockback_slide_timer, maxf(duration, 0.05))


func is_punch_knockback_sliding() -> bool:
	return punch_knockback_slide_timer > 0.0 and abs(velocity.x) > SLIDE_ANIMATION_MIN_SPEED


func update_punch_knockback_slide_timer(delta: float) -> void:
	if punch_knockback_slide_timer <= 0.0:
		return

	punch_knockback_slide_timer = maxf(0.0, punch_knockback_slide_timer - delta)


func update_player_water_depth():
	if is_standing_on_water():
		_apply_player_visual_z_indices(true)
	else:
		_apply_player_visual_z_indices(false)


func update_water_splash_particles(delta: float, in_water_before_move: bool, vertical_velocity_before_move: float):
	water_splash_cooldown = max(0.0, water_splash_cooldown - delta)

	var in_water = is_standing_on_water()
	was_standing_on_water = in_water

	if in_water and not in_water_before_move:
		var fall_intensity = clampf(abs(vertical_velocity_before_move) / WATER_MAX_FALL_SPEED, 0.0, 1.0)
		spawn_water_splash_particles(0.85 + fall_intensity * 0.75)
		water_splash_cooldown = WATER_SPLASH_MOVE_COOLDOWN
		return

	if in_water and abs(velocity.x) >= WATER_SPLASH_MOVE_SPEED and water_splash_cooldown <= 0.0:
		spawn_water_splash_particles(0.46)
		water_splash_cooldown = WATER_SPLASH_MOVE_COOLDOWN


func spawn_water_splash_particles(intensity: float = 1.0):
	var world = get_world_controller()
	if world == null or not world.has_method("spawn_water_splash_particles"):
		return

	world.spawn_water_splash_particles(get_water_splash_position(), intensity)
	ripple_water_surface(intensity)


## Kick the rippling water surface wherever a splash particle burst happens, so
## the two always agree. Purely visual: the surface manager owns no state the
## server cares about, so this is safe to skip entirely when it is absent.
func ripple_water_surface(intensity: float) -> void:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return
	var manager = world.get("water_surface_manager")
	if manager == null or not is_instance_valid(manager):
		return
	if not manager.has_method("disturb_span"):
		return

	var collision_rect := get_player_collision_rect_at(global_position)
	manager.disturb_span(
		collision_rect.position.x,
		collision_rect.end.x,
		-absf(intensity) * WATER_SURFACE_RIPPLE_IMPULSE,
		collision_rect.end.y
	)


func update_water_surface_contact_particles():
	if water_surface_particle_cooldown > 0.0:
		return

	var water_surface_y := get_water_contact_surface_y()
	if water_surface_y == INF:
		return

	var half_extents = _get_collision_half_extents()
	if global_position.y - half_extents.y >= water_surface_y - 1.0:
		return

	spawn_water_surface_contact_particles(water_surface_y, 1.18)


func spawn_water_surface_contact_particles(water_surface_y: float, intensity: float = 1.0):
	if water_surface_particle_cooldown > 0.0:
		return

	var world = get_world_controller()
	if world == null or not world.has_method("spawn_player_water_splash_particles"):
		return

	world.spawn_player_water_splash_particles(global_position, _get_collision_half_extents(), water_surface_y, intensity)
	water_surface_particle_cooldown = WATER_SURFACE_PARTICLE_INTERVAL


func get_water_splash_position() -> Vector2:
	var half_extents = _get_collision_half_extents()
	return global_position + Vector2(0.0, half_extents.y - 3.0)


func update_underwater_bubbles(delta: float):
	var underwater := is_underwater_for_bubbles()
	if not underwater:
		water_bubble_timer = 0.0
		was_underwater_for_bubbles = false
		return

	if not was_underwater_for_bubbles:
		was_underwater_for_bubbles = true
		water_bubble_timer = randf_range(WATER_BUBBLE_INITIAL_DELAY_MIN, WATER_BUBBLE_INITIAL_DELAY_MAX)
		return

	water_bubble_timer -= delta
	if water_bubble_timer > 0.0:
		return

	spawn_underwater_bubbles_particles(randi_range(1, 3))
	water_bubble_timer = randf_range(WATER_BUBBLE_INTERVAL_MIN, WATER_BUBBLE_INTERVAL_MAX)


func spawn_underwater_bubbles_particles(count: int = 1):
	var world = get_world_controller()
	if world == null or not world.has_method("spawn_underwater_bubbles_particles"):
		return

	world.spawn_underwater_bubbles_particles(get_underwater_bubble_mouth_position(), count)


func get_underwater_bubble_mouth_position() -> Vector2:
	var facing_direction := get_water_bubble_facing_direction()
	return global_position + Vector2(WATER_BUBBLE_MOUTH_OFFSET_X * facing_direction, WATER_BUBBLE_MOUTH_OFFSET_Y)


func get_water_bubble_facing_direction() -> float:
	var world = get_world_controller()
	if world != null and "player_facing_direction" in world:
		return 1.0 if int(world.player_facing_direction) >= 0 else -1.0

	if abs(velocity.x) > 0.01:
		return sign(velocity.x)

	return 1.0


func is_underwater_for_bubbles() -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return false

	var block_size := get_world_block_size(world)
	var facing_direction := get_water_bubble_facing_direction()
	var sample_offsets := [
		Vector2(WATER_BUBBLE_MOUTH_OFFSET_X * facing_direction, WATER_BUBBLE_MOUTH_OFFSET_Y),
		Vector2(0.0, -12.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, 8.0)
	]

	for offset in sample_offsets:
		var sample_offset: Vector2 = offset
		var sample_position: Vector2 = global_position + sample_offset
		var grid_pos := world_point_to_centered_water_grid(sample_position, block_size)
		if grid_position_has_water_for_bubbles(grid_pos):
			return true

	return false


func grid_position_has_water_for_bubbles(grid_pos: Vector2i) -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return false

	var block_sets := [world.get("blocks")]
	if "block_manager" in world and world.block_manager != null:
		var manager_background_blocks = world.block_manager.get("background_blocks")
		if manager_background_blocks is Dictionary:
			block_sets.append(manager_background_blocks)

	var legacy_background_blocks = world.get("background_blocks")
	if legacy_background_blocks is Dictionary:
		block_sets.append(legacy_background_blocks)

	for block_set in block_sets:
		if not (block_set is Dictionary):
			continue
		if not block_set.has(grid_pos):
			continue

		var block_data = block_set[grid_pos]
		var block_type := ""
		if block_data is Dictionary:
			block_type = str(block_data.get("type", "")).strip_edges().to_lower()
		else:
			block_type = str(block_data).strip_edges().to_lower()

		if block_type == WATER_BLOCK_ID:
			return true

	return false


func update_springboard_bounce():
	if not is_on_floor():
		return

	var springboard_data = get_standing_springboard_data()
	if springboard_data.is_empty():
		return

	var jump_velocity = float(springboard_data.get("springboard_velocity", SPRINGBOARD_DEFAULT_JUMP_VELOCITY))
	velocity.y = jump_velocity
	air_jumps_used = 0
	coyote_timer = 0.0
	variable_jump_active = false

	var world = get_world_controller()
	if world != null and world.has_method("play_springboard_block_animation") and springboard_data.has("grid_pos"):
		world.play_springboard_block_animation(springboard_data["grid_pos"])
	if world != null and world.has_method("send_springboard_block_animation") and springboard_data.has("grid_pos"):
		world.send_springboard_block_animation(springboard_data["grid_pos"])

	if world != null and world.has_method("play_sound_jump"):
		world.play_sound_jump(global_position)


func get_standing_springboard_data() -> Dictionary:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = 32.0
	var block_size_value = world.get("BLOCK_SIZE")
	if block_size_value is int or block_size_value is float:
		block_size = float(block_size_value)

	var half_extents = _get_collision_half_extents()
	var feet_y = global_position.y + half_extents.y
	var sample_y = feet_y + 2.0

	for sample_factor in SURFACE_SAMPLE_FACTORS:
		var x_offset = half_extents.x * float(sample_factor)
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)

		if not blocks.has(sample_grid):
			continue

		var block_data = blocks[sample_grid]
		var block_type = str(block_data.get("type", ""))
		var item_data = get_world_item_data(world, block_type)
		if is_springboard_block_data(item_data, block_type):
			var result = item_data.duplicate(true)
			if not result.has("springboard_velocity"):
				result["springboard_velocity"] = SPRINGBOARD_DEFAULT_JUMP_VELOCITY
			result["grid_pos"] = sample_grid
			return result

	return {}


func get_world_item_data(world, block_type: String) -> Dictionary:
	if world == null or block_type == "":
		return {}

	var item_database = world.get("item_database")
	if item_database is Dictionary and item_database.has(block_type):
		return item_database[block_type]

	return {}


func is_springboard_block_data(item_data: Dictionary, block_type: String) -> bool:
	if bool(item_data.get("springboard", false)):
		return true

	return block_type == "mushroom" or block_type == "mushroom_1" or block_type == "mushroom_2"


func update_instant_hazard_contact():
	if is_instant_hazard_damage_blocked():
		return

	var hazard_grid_pos = get_touching_instant_hazard_grid()
	if instant_hazard_requires_clear:
		if hazard_grid_pos == INVALID_LAVA_GRID_POS:
			instant_hazard_requires_clear = false
		return

	if instant_hazard_death_cooldown > 0.0:
		return

	if hazard_grid_pos == INVALID_LAVA_GRID_POS:
		return

	apply_instant_hazard_death(hazard_grid_pos)


func is_instant_hazard_damage_blocked() -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return true

	var health_value = world.get("player_health")
	if health_value is int or health_value is float:
		if int(health_value) <= 0:
			return true

	var player_manager = world.get("player_manager")
	if player_manager != null:
		var respawn_running = player_manager.get("respawn_sequence_running")
		if respawn_running is bool and respawn_running:
			return true

	return false


func get_touching_instant_hazard_grid() -> Vector2i:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INVALID_LAVA_GRID_POS

	var block_size = get_world_block_size(world)
	var half_extents = _get_collision_half_extents()

	var sample_offsets = [
		Vector2(-half_extents.x - 2.0, -half_extents.y * 0.72),
		Vector2(0.0, -half_extents.y - 2.0),
		Vector2(half_extents.x + 2.0, -half_extents.y * 0.72),
		Vector2(-half_extents.x - 2.0, 0.0),
		Vector2(0.0, 0.0),
		Vector2(half_extents.x + 2.0, 0.0),
		Vector2(-half_extents.x - 2.0, half_extents.y * 0.72),
		Vector2(0.0, half_extents.y + 2.0),
		Vector2(half_extents.x + 2.0, half_extents.y * 0.72)
	]

	for offset in sample_offsets:
		var sample_position: Vector2 = global_position + offset
		var sample_grid := Vector2i(
			int(round(sample_position.x / block_size)),
			int(round(sample_position.y / block_size))
		)
		if is_instant_death_block_at_grid(sample_grid):
			return sample_grid

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision == null:
			continue
		var collision_grid = get_grid_pos_from_collision(collision)
		if collision_grid != INVALID_LAVA_GRID_POS and is_instant_death_block_at_grid(collision_grid):
			return collision_grid

	return INVALID_LAVA_GRID_POS


func is_instant_death_block_at_grid(grid_pos: Vector2i) -> bool:
	var block_type = get_block_type_at_grid(grid_pos)
	if block_type == "":
		return false

	var item_data = get_world_item_data(get_world_controller(), block_type)
	return bool(item_data.get("instant_death", false)) or bool(item_data.get("hazard_instant_death", false))


func apply_instant_hazard_death(_hazard_grid_pos: Vector2i):
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return
	if not world.has_method("damage_player"):
		return

	instant_hazard_death_cooldown = INSTANT_HAZARD_DEATH_COOLDOWN
	instant_hazard_requires_clear = true
	velocity = Vector2.ZERO
	world.damage_player(999999)


func reset_instant_hazard_after_respawn():
	instant_hazard_death_cooldown = maxf(instant_hazard_death_cooldown, INSTANT_HAZARD_DEATH_COOLDOWN)
	instant_hazard_requires_clear = true


func update_pinball_knockback():
	if is_on_floor():
		var standing_pinball: Dictionary = get_standing_pinball_data()
		if not standing_pinball.is_empty():
			var standing_grid_pos: Vector2i = standing_pinball.get("grid_pos", INVALID_LAVA_GRID_POS)
			if not should_skip_pinball_knockback_for_grid(standing_grid_pos):
				apply_pinball_knockback(Vector2.UP, standing_pinball, standing_grid_pos)
				return

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision == null:
			continue

		var pinball_grid_pos: Vector2i = get_grid_pos_from_collision(collision)
		if pinball_grid_pos == INVALID_LAVA_GRID_POS or not is_pinball_block_at_grid(pinball_grid_pos):
			continue
		if should_skip_pinball_knockback_for_grid(pinball_grid_pos):
			continue

		var block_type: String = get_block_type_at_grid(pinball_grid_pos)
		var item_data: Dictionary = get_world_item_data(get_world_controller(), block_type)
		apply_pinball_knockback(collision.get_normal(), item_data, pinball_grid_pos)
		return

	var touching_pinball: Dictionary = get_touching_pinball_data()
	if touching_pinball.is_empty():
		return

	var touching_grid_pos: Vector2i = touching_pinball.get("grid_pos", INVALID_LAVA_GRID_POS)
	if should_skip_pinball_knockback_for_grid(touching_grid_pos):
		return

	apply_pinball_knockback(Vector2.ZERO, touching_pinball, touching_grid_pos)


func should_skip_pinball_knockback_for_grid(pinball_grid_pos: Vector2i) -> bool:
	return pinball_knockback_cooldown > 0.0 and pinball_grid_pos == last_pinball_knockback_grid


func get_standing_pinball_data() -> Dictionary:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = get_world_block_size(world)
	var half_extents = _get_collision_half_extents()
	var sample_y = global_position.y + half_extents.y + 2.0

	for sample_factor in SURFACE_SAMPLE_FACTORS:
		var x_offset = half_extents.x * float(sample_factor)
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)
		if not is_pinball_block_at_grid(sample_grid):
			continue

		var block_type = get_block_type_at_grid(sample_grid)
		var result = get_world_item_data(world, block_type).duplicate(true)
		result["grid_pos"] = sample_grid
		return result

	return {}


func get_touching_pinball_data() -> Dictionary:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var block_size: float = get_world_block_size(world)
	if block_size <= 0.0:
		return {}

	var half_extents: Vector2 = _get_collision_half_extents()
	var margin: float = maxf(0.0, PINBALL_CONTACT_MARGIN)
	var block_half: float = block_size * 0.5
	var player_min: Vector2 = global_position - half_extents - Vector2(margin, margin)
	var player_max: Vector2 = global_position + half_extents + Vector2(margin, margin)
	var player_rect := Rect2(player_min, player_max - player_min)
	var min_x: int = int(floor((player_min.x - block_half) / block_size))
	var max_x: int = int(ceil((player_max.x + block_half) / block_size))
	var min_y: int = int(floor((player_min.y - block_half) / block_size))
	var max_y: int = int(ceil((player_max.y + block_half) / block_size))
	var best_result: Dictionary = {}
	var best_distance_sq: float = INF

	for grid_y in range(min_y, max_y + 1):
		for grid_x in range(min_x, max_x + 1):
			var sample_grid := Vector2i(grid_x, grid_y)
			if not is_pinball_block_at_grid(sample_grid):
				continue
			if should_skip_pinball_knockback_for_grid(sample_grid):
				continue

			var tile_center: Vector2 = get_grid_center_world_position(sample_grid, world)
			var tile_rect := Rect2(
				tile_center - Vector2(block_half, block_half),
				Vector2(block_size, block_size)
			)
			if not player_rect.intersects(tile_rect, true):
				continue

			var distance_sq: float = global_position.distance_squared_to(tile_center)
			if distance_sq >= best_distance_sq:
				continue

			var block_type: String = get_block_type_at_grid(sample_grid)
			var result: Dictionary = get_world_item_data(world, block_type).duplicate(true)
			result["grid_pos"] = sample_grid
			best_result = result
			best_distance_sq = distance_sq

	return best_result


func is_pinball_block_at_grid(grid_pos: Vector2i) -> bool:
	var block_type = get_block_type_at_grid(grid_pos)
	if block_type == "":
		return false
	var item_data = get_world_item_data(get_world_controller(), block_type)
	return bool(item_data.get("pinball_block", false))


func apply_pinball_knockback(normal: Vector2, item_data: Dictionary, pinball_grid_pos: Vector2i = INVALID_LAVA_GRID_POS):
	var world = get_world_controller()
	pinball_knockback_cooldown = PINBALL_KNOCKBACK_COOLDOWN
	last_pinball_knockback_grid = pinball_grid_pos

	var knockback_velocity = float(item_data.get("pinball_knockback_velocity", PINBALL_DEFAULT_KNOCKBACK_VELOCITY))
	var vertical_velocity = float(item_data.get("pinball_vertical_velocity", PINBALL_DEFAULT_VERTICAL_VELOCITY))
	var knockback_direction := get_pinball_knockback_direction(normal, pinball_grid_pos, world)
	velocity.x = knockback_direction.x * knockback_velocity
	velocity.y = knockback_direction.y * abs(vertical_velocity)
	variable_jump_active = false
	if knockback_direction.y < -0.05:
		air_jumps_used = 0
	coyote_timer = 0.0
	punch_knockback_slide_timer = maxf(punch_knockback_slide_timer, PINBALL_KNOCKBACK_COOLDOWN)

	if world != null and world.has_method("play_springboard_block_animation") and pinball_grid_pos != INVALID_LAVA_GRID_POS:
		world.play_springboard_block_animation(pinball_grid_pos)
	if world != null and world.has_method("send_springboard_block_animation") and pinball_grid_pos != INVALID_LAVA_GRID_POS:
		world.send_springboard_block_animation(pinball_grid_pos)
	if world != null and world.has_method("play_sound_jump"):
		world.play_sound_jump(global_position)


func get_pinball_knockback_direction(normal: Vector2, pinball_grid_pos: Vector2i, world) -> Vector2:
	if world != null and pinball_grid_pos != INVALID_LAVA_GRID_POS:
		var pinball_center: Vector2 = get_grid_center_world_position(pinball_grid_pos, world)
		var contact_position: Vector2 = get_body_contact_position(pinball_center)
		var away_from_center: Vector2 = contact_position - pinball_center
		if away_from_center.length_squared() <= 0.01:
			away_from_center = global_position - pinball_center
		if away_from_center.length_squared() > 0.01:
			return away_from_center.normalized()

	if normal.length_squared() > 0.01:
		return normal.normalized()

	if velocity.length_squared() > 0.01:
		return -velocity.normalized()

	return Vector2.UP


func get_grid_center_world_position(grid_pos: Vector2i, world) -> Vector2:
	var block_size: float = get_world_block_size(world)
	if world != null and world.has_method("get_block_center_world_position"):
		return world.get_block_center_world_position(grid_pos)
	return Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)


func get_body_contact_position(block_center: Vector2) -> Vector2:
	var half_extents: Vector2 = _get_collision_half_extents()
	var min_position: Vector2 = global_position - half_extents
	var max_position: Vector2 = global_position + half_extents
	return Vector2(
		clampf(block_center.x, min_position.x, max_position.x),
		clampf(block_center.y, min_position.y, max_position.y)
	)


func get_grid_pos_from_collision(collision) -> Vector2i:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INVALID_LAVA_GRID_POS

	var collider = collision.get_collider()
	if collider == null:
		return INVALID_LAVA_GRID_POS

	var collider_node = collider
	if collider_node is CollisionShape2D:
		collider_node = collider_node.get_parent()

	if collider_node is TileMapLayer:
		var tilemap_layer := collider_node as TileMapLayer
		var collider_rid: RID = collision.get_collider_rid()
		if collider_rid.is_valid():
			var tile_coords := tilemap_layer.get_coords_for_body_rid(collider_rid)
			if get_block_type_at_grid(tile_coords) != "":
				return tile_coords
		return INVALID_LAVA_GRID_POS

	if not (collider_node is Node2D):
		return INVALID_LAVA_GRID_POS

	var block_size = get_world_block_size(world)
	return Vector2i(
		int(round(collider_node.global_position.x / block_size)),
		int(round(collider_node.global_position.y / block_size))
	)


func update_lava_rebound():
	if is_on_floor():
		var standing_lava_data = get_standing_lava_rebound_data()
		if not standing_lava_data.is_empty():
			var lava_grid_pos = standing_lava_data.get("grid_pos", INVALID_LAVA_GRID_POS)
			apply_lava_rebound(Vector2.UP, standing_lava_data, lava_grid_pos)
			return

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision == null:
			continue

		var lava_grid_pos = get_lava_grid_pos_from_collision(collision)
		if lava_grid_pos == INVALID_LAVA_GRID_POS:
			continue

		var normal = collision.get_normal()
		var block_type = get_block_type_at_grid(lava_grid_pos)
		var item_data = get_world_item_data(get_world_controller(), block_type)
		apply_lava_rebound(normal, item_data, lava_grid_pos)
		return


func get_standing_lava_rebound_data() -> Dictionary:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = get_world_block_size(world)
	var half_extents = _get_collision_half_extents()
	var feet_y = global_position.y + half_extents.y
	var sample_y = feet_y + 2.0

	var best_lava_grid = INVALID_LAVA_GRID_POS
	var best_lava_distance = INF

	for sample_factor in SURFACE_SAMPLE_FACTORS:
		var x_offset = half_extents.x * float(sample_factor)
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)

		if not is_lava_rebound_block_at_grid(sample_grid):
			continue

		var block_center_x = float(sample_grid.x) * block_size
		var lava_distance = abs(global_position.x - block_center_x)
		if best_lava_grid == INVALID_LAVA_GRID_POS or lava_distance < best_lava_distance:
			best_lava_grid = sample_grid
			best_lava_distance = lava_distance

	if best_lava_grid != INVALID_LAVA_GRID_POS:
		var block_type = get_block_type_at_grid(best_lava_grid)
		var result = get_world_item_data(world, block_type).duplicate(true)
		result["grid_pos"] = best_lava_grid
		return result

	return {}


func get_lava_grid_pos_from_collision(collision) -> Vector2i:
	var grid_pos := get_grid_pos_from_collision(collision)

	if is_lava_rebound_block_at_grid(grid_pos):
		return grid_pos

	grid_pos = get_lava_grid_pos_from_collision_contact(collision)
	if is_lava_rebound_block_at_grid(grid_pos):
		return grid_pos

	return INVALID_LAVA_GRID_POS


func get_lava_grid_pos_from_collision_contact(collision) -> Vector2i:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INVALID_LAVA_GRID_POS

	var normal: Vector2 = collision.get_normal()
	if normal.length_squared() <= 0.01:
		return INVALID_LAVA_GRID_POS

	var block_size: float = get_world_block_size(world)
	var contact_position: Vector2 = collision.get_position()
	var inside_tile_position: Vector2 = contact_position - normal.normalized() * maxf(2.0, block_size * 0.08)
	var sample_grid := Vector2i(
		int(round(inside_tile_position.x / block_size)),
		int(round(inside_tile_position.y / block_size))
	)

	if is_lava_rebound_block_at_grid(sample_grid):
		return sample_grid

	return INVALID_LAVA_GRID_POS


func get_world_block_size(world) -> float:
	var block_size = 32.0
	if world == null:
		return block_size

	var block_size_value = world.get("BLOCK_SIZE")
	if block_size_value is int or block_size_value is float:
		block_size = float(block_size_value)

	return block_size


func get_block_type_at_grid(grid_pos: Vector2i) -> String:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return ""

	var blocks = world.get("blocks")
	if not blocks is Dictionary or not blocks.has(grid_pos):
		return ""

	return str(blocks[grid_pos].get("type", ""))


func is_lava_rebound_block_at_grid(grid_pos: Vector2i) -> bool:
	var block_type = get_block_type_at_grid(grid_pos)
	if block_type == "":
		return false

	var item_data = get_world_item_data(get_world_controller(), block_type)
	if bool(item_data.get("lava_rebound", false)):
		return true

	return block_type == LAVA_BLOCK_ID


func update_lava_fire_contact_particles():
	if lava_fire_particle_cooldown > 0.0:
		return

	if not is_touching_lava_or_fire_block():
		return

	spawn_lava_fire_contact_particles(1.0)


func is_touching_lava_or_fire_block() -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return false

	var collision_rect := get_player_collision_rect_at(global_position)
	for raw_grid_pos in get_candidate_grid_positions_for_rect(world, world.get("block_manager"), collision_rect):
		if not (raw_grid_pos is Vector2i):
			continue

		var sample_grid := Vector2i(raw_grid_pos.x, raw_grid_pos.y)
		if is_lava_or_fire_contact_block_at_grid(sample_grid):
			return true

	return false


func is_lava_or_fire_contact_block_at_grid(grid_pos: Vector2i) -> bool:
	var block_type = get_block_type_at_grid(grid_pos)
	if block_type == "":
		return false

	var clean_block_type = block_type.strip_edges().to_lower()
	if clean_block_type == LAVA_BLOCK_ID or clean_block_type == FIRE_BLOCK_ID:
		return true

	var item_data = get_world_item_data(get_world_controller(), block_type)
	return bool(item_data.get("lava_rebound", false))


func spawn_lava_fire_contact_particles(intensity: float = 1.0):
	if lava_fire_particle_cooldown > 0.0:
		return

	var world = get_world_controller()
	if world == null:
		return

	if world.has_method("spawn_player_fire_particles"):
		world.spawn_player_fire_particles(global_position, _get_collision_half_extents(), intensity)
	play_lava_fire_hit_sound()
	lava_fire_particle_cooldown = LAVA_FIRE_PARTICLE_INTERVAL


func play_lava_fire_hit_sound():
	if lava_fire_sound_cooldown > 0.0:
		return

	var world = get_world_controller()
	if world == null or not world.has_method("play_sound_lava_fire_hit"):
		return

	world.play_sound_lava_fire_hit(global_position)
	lava_fire_sound_cooldown = LAVA_FIRE_SOUND_INTERVAL


func apply_lava_rebound(normal: Vector2, item_data: Dictionary, lava_grid_pos: Vector2i = INVALID_LAVA_GRID_POS):
	if lava_rebound_contact_cooldown > 0.0 and lava_grid_pos == last_lava_rebound_grid:
		return

	lava_rebound_contact_cooldown = LAVA_REBOUND_CONTACT_COOLDOWN
	last_lava_rebound_grid = lava_grid_pos
	spawn_lava_fire_contact_particles(1.35)
	apply_lava_contact_damage()
	variable_jump_active = false

	var knockback_velocity = get_lava_radial_knockback_velocity(item_data)
	var knockback_direction = get_lava_radial_knockback_direction(normal, lava_grid_pos)
	velocity = knockback_direction * knockback_velocity
	punch_knockback_slide_timer = maxf(punch_knockback_slide_timer, LAVA_REBOUND_CONTACT_COOLDOWN)
	if knockback_direction.y < -0.05:
		air_jumps_used = 0
	coyote_timer = 0.0


func get_lava_radial_knockback_velocity(item_data: Dictionary) -> float:
	if item_data.has("lava_radial_knockback_velocity"):
		return float(item_data.get("lava_radial_knockback_velocity", LAVA_DEFAULT_RADIAL_KNOCKBACK_VELOCITY))

	var top_velocity = abs(float(item_data.get("lava_top_velocity", LAVA_DEFAULT_RADIAL_KNOCKBACK_VELOCITY)))
	var side_velocity = abs(float(item_data.get("lava_side_knockback_velocity", LAVA_DEFAULT_RADIAL_KNOCKBACK_VELOCITY)))
	var bottom_velocity = abs(float(item_data.get("lava_bottom_knockback_velocity", LAVA_DEFAULT_RADIAL_KNOCKBACK_VELOCITY)))
	return maxf(top_velocity, maxf(side_velocity, bottom_velocity))


func get_lava_radial_knockback_direction(normal: Vector2, lava_grid_pos: Vector2i) -> Vector2:
	var world = get_world_controller()
	if world != null and lava_grid_pos != INVALID_LAVA_GRID_POS:
		var lava_center: Vector2 = get_grid_center_world_position(lava_grid_pos, world)
		var contact_position: Vector2 = get_body_contact_position(lava_center)
		var away_from_center: Vector2 = contact_position - lava_center
		if away_from_center.length_squared() <= 0.01:
			away_from_center = global_position - lava_center
		if away_from_center.length_squared() > 0.01:
			return away_from_center.normalized()

	if normal.length_squared() > 0.01:
		return normal.normalized()

	if velocity.length_squared() > 0.01:
		return -velocity.normalized()

	return Vector2.UP


func apply_lava_contact_damage():
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return
	if not world.has_method("damage_player"):
		return

	if float(world.lava_damage_timer) > 0.0:
		return

	world.damage_player(1)
	world.lava_damage_timer = world.LAVA_DAMAGE_DELAY


func get_water_contact_surface_y() -> float:
	var collision_rect := get_player_collision_rect_at(global_position)
	var horizontal_inset := minf(WATER_CONTACT_EDGE_INSET, collision_rect.size.x * 0.25)
	var contact_rect := Rect2(
		collision_rect.position + Vector2(horizontal_inset, 0.0),
		Vector2(maxf(0.0, collision_rect.size.x - horizontal_inset * 2.0), collision_rect.size.y)
	)
	return get_water_surface_y_overlapping_rect(contact_rect)


func get_water_surface_y_overlapping_rect(contact_rect: Rect2) -> float:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INF
	if contact_rect.size.x <= 0.0 or contact_rect.size.y <= 0.0:
		return INF

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return INF

	var block_size := get_world_block_size(world)
	var edge_epsilon := 0.001
	var first_grid := world_point_to_centered_water_grid(contact_rect.position + Vector2(edge_epsilon, edge_epsilon), block_size)
	var last_grid := world_point_to_centered_water_grid(contact_rect.end - Vector2(edge_epsilon, edge_epsilon), block_size)
	var tile_size := Vector2(block_size, block_size)
	var tile_half_size := tile_size * 0.5
	var best_surface_y := INF

	for grid_y in range(first_grid.y, last_grid.y + 1):
		for grid_x in range(first_grid.x, last_grid.x + 1):
			var grid_pos := Vector2i(grid_x, grid_y)
			if not is_water_contact_block_at_grid(grid_pos):
				continue

			var tile_center := Vector2(float(grid_x) * block_size, float(grid_y) * block_size)
			var overlap := contact_rect.intersection(Rect2(tile_center - tile_half_size, tile_size))
			if overlap.size.x <= WATER_CONTACT_MIN_OVERLAP or overlap.size.y <= WATER_CONTACT_MIN_OVERLAP:
				continue

			best_surface_y = minf(best_surface_y, tile_center.y - tile_half_size.y)

	return best_surface_y


func world_point_to_centered_water_grid(world_position: Vector2, block_size: float) -> Vector2i:
	var safe_block_size := maxf(1.0, block_size)
	var half_block_size := safe_block_size * 0.5
	return Vector2i(
		int(floor((world_position.x + half_block_size) / safe_block_size)),
		int(floor((world_position.y + half_block_size) / safe_block_size))
	)


func is_water_contact_block_at_grid(grid_pos: Vector2i) -> bool:
	var block_type = get_block_type_at_grid(grid_pos)
	if block_type == "":
		return false

	var clean_block_type = block_type.strip_edges().to_lower()
	return clean_block_type == WATER_BLOCK_ID


func is_standing_on_water() -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return false

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return false

	if movement_surface_cache_active and water_cache_token == movement_surface_cache_token and water_cache_position == global_position:
		return water_cache_result

	var collision_rect := get_player_collision_rect_at(global_position)
	var horizontal_inset := minf(WATER_CONTACT_EDGE_INSET, collision_rect.size.x * 0.25)
	var feet_height := minf(WATER_FEET_CONTACT_HEIGHT, collision_rect.size.y)
	var feet_rect := Rect2(
		Vector2(collision_rect.position.x + horizontal_inset, collision_rect.end.y - feet_height),
		Vector2(maxf(0.0, collision_rect.size.x - horizontal_inset * 2.0), feet_height)
	)
	var result := get_water_surface_y_overlapping_rect(feet_rect) != INF

	if movement_surface_cache_active:
		water_cache_token = movement_surface_cache_token
		water_cache_position = global_position
		water_cache_result = result

	return result


func update_ledge_auto_fall(fall_speed_before_move: float = 0.0):
	if not is_on_floor() or velocity.y < 0.0:
		return

	var support_data = get_floor_support_data()
	if support_data.is_empty():
		return

	var support_width = float(support_data.get("support_width", 0.0))
	if support_width <= 0.0 or support_width >= LEDGE_MIN_SUPPORT_WIDTH:
		return

	var fall_direction = float(support_data.get("fall_direction", 0.0))
	if abs(fall_direction) <= 0.01:
		return

	global_position.x += fall_direction * LEDGE_AUTO_FALL_NUDGE
	invalidate_movement_surface_cache()
	var restored_fall_velocity: float = maxf(LEDGE_FALL_START_VELOCITY, fall_speed_before_move)
	velocity.y = maxf(velocity.y, restored_fall_velocity)
	coyote_timer = 0.0


func get_floor_support_data() -> Dictionary:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = get_world_block_size(world)
	var half_block = block_size * 0.5
	var half_extents = _get_collision_half_extents()
	var foot_left = global_position.x - half_extents.x
	var foot_right = global_position.x + half_extents.x
	var foot_y = global_position.y + half_extents.y + 2.0
	var grid_y = int(floor((foot_y + half_block) / block_size))
	var min_grid_x = int(floor((foot_left + half_block + 0.01) / block_size))
	var max_grid_x = int(floor((foot_right + half_block - 0.01) / block_size))
	var support_width = 0.0
	var support_center_sum = 0.0

	for grid_x in range(min_grid_x, max_grid_x + 1):
		var grid_pos = Vector2i(grid_x, grid_y)
		if not blocks.has(grid_pos):
			continue

		var block_type = str(blocks[grid_pos].get("type", ""))
		if not is_floor_support_block_type(world, block_type):
			continue

		var block_left = float(grid_x) * block_size - half_block
		var block_right = float(grid_x) * block_size + half_block
		var overlap_left = max(foot_left, block_left)
		var overlap_right = min(foot_right, block_right)
		var overlap_width = max(0.0, overlap_right - overlap_left)
		if overlap_width <= 0.0:
			continue

		support_width += overlap_width
		support_center_sum += ((overlap_left + overlap_right) * 0.5) * overlap_width

	if support_width <= 0.0:
		return {}

	var support_center = support_center_sum / support_width
	var fall_direction = 1.0 if global_position.x >= support_center else -1.0
	if abs(global_position.x - support_center) <= 0.01:
		fall_direction = sign(velocity.x)
	if abs(fall_direction) <= 0.01:
		fall_direction = get_horizontal_input_direction()

	return {
		"support_width": support_width,
		"fall_direction": fall_direction
	}


func is_floor_support_block_type(world, block_type: String) -> bool:
	if block_type == "":
		return false

	var item_data = get_world_item_data(world, block_type)
	if item_data.has("collidable"):
		return bool(item_data.get("collidable", true))

	if bool(item_data.get("no_collision", false)):
		return false

	if bool(item_data.get("background_block", false)):
		return false

	if bool(item_data.get("sign_block", false)):
		return false

	return true


func get_standing_slippery_surface_data() -> Dictionary:
	if not is_on_floor():
		return {}

	if movement_surface_cache_active and standing_slippery_cache_token == movement_surface_cache_token and standing_slippery_cache_position == global_position and standing_slippery_cache_on_floor == is_on_floor():
		return standing_slippery_cache_data

	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = get_world_block_size(world)
	var half_extents = _get_collision_half_extents()
	var sample_y = global_position.y + half_extents.y + 2.0
	var result: Dictionary = {}

	for sample_factor in SURFACE_SAMPLE_FACTORS:
		var x_offset = half_extents.x * float(sample_factor)
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)

		if not blocks.has(sample_grid):
			continue

		var block_type = str(blocks[sample_grid].get("type", ""))
		var item_data = get_world_item_data(world, block_type)
		if is_slideable_surface_data(item_data):
			result = item_data
			break

	if movement_surface_cache_active:
		standing_slippery_cache_token = movement_surface_cache_token
		standing_slippery_cache_position = global_position
		standing_slippery_cache_on_floor = is_on_floor()
		standing_slippery_cache_data = result

	return result


func get_standing_slow_surface_data() -> Dictionary:
	if not is_on_floor():
		return {}

	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return {}

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return {}

	var block_size = get_world_block_size(world)
	var half_extents = _get_collision_half_extents()
	var sample_y = global_position.y + half_extents.y + 2.0

	for sample_factor in SURFACE_SAMPLE_FACTORS:
		var x_offset = half_extents.x * float(sample_factor)
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)

		if not blocks.has(sample_grid):
			continue

		var block_type = str(blocks[sample_grid].get("type", ""))
		var item_data = get_world_item_data(world, block_type)
		if is_slow_surface_data(item_data):
			return item_data

	return {}


func is_slow_surface_data(item_data: Dictionary) -> bool:
	return bool(item_data.get("slow_surface", false)) or item_data.has("movement_speed_multiplier") or item_data.has("jump_velocity_multiplier")


func is_slideable_surface_data(item_data: Dictionary) -> bool:
	return bool(item_data.get("slippery", false)) or bool(item_data.get("slideable", false)) or bool(item_data.get("slides_player", false))


func _get_collision_half_extents() -> Vector2:
	var collision_shape = cache_collision_shape()
	if collision_shape == null:
		return Vector2(8.0, 8.0)

	var shape = collision_shape.shape
	if shape == null:
		return Vector2(8.0, 8.0)

	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		return rect_shape.size * 0.5 * Vector2(abs(collision_shape.scale.x), abs(collision_shape.scale.y))
	if shape is CapsuleShape2D:
		var capsule_shape = shape as CapsuleShape2D
		return Vector2(
			float(capsule_shape.radius) * abs(collision_shape.scale.x),
			float(capsule_shape.height) * 0.5 * abs(collision_shape.scale.y)
		)
	if shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var radius = float(circle_shape.radius)
		return Vector2(radius * abs(collision_shape.scale.x), radius * abs(collision_shape.scale.y))

	return Vector2(8.0, 8.0)


func cache_collision_shape():
	if cached_collision_shape != null and is_instance_valid(cached_collision_shape):
		return cached_collision_shape

	cached_collision_shape = get_node_or_null("CollisionShape2D")
	return cached_collision_shape


func cache_player_visual_nodes():
	if cached_body_sprite == null or not is_instance_valid(cached_body_sprite):
		cached_body_sprite = get_node_or_null("Sprite2D")
	if cached_back_sprite == null or not is_instance_valid(cached_back_sprite):
		cached_back_sprite = get_node_or_null("BackSocket/BackSprite")


func _apply_player_visual_z_indices(in_water: bool):
	if cached_visual_z_valid and cached_visual_in_water == in_water:
		return

	cache_player_visual_nodes()
	var player_z_offset = WATER_PLAYER_Z_INDEX_OFFSET if in_water else 0
	var child_z_offset = WATER_CHILD_Z_INDEX_OFFSET if in_water else 0

	self.z_as_relative = false
	self.z_index = BASE_PLAYER_Z_INDEX + player_z_offset

	if is_instance_valid(cached_body_sprite):
		cached_body_sprite.z_index = BASE_BODY_Z_INDEX + child_z_offset
	if is_instance_valid(cached_back_sprite):
		cached_back_sprite.z_index = BASE_BACK_Z_INDEX + child_z_offset

	cached_visual_in_water = in_water
	cached_visual_z_valid = true


func apply_gravity(delta: float):
	if is_on_floor():
		return

	if is_standing_on_water():
		velocity.y = min(
			velocity.y + gravity * WATER_GRAVITY_MULTIPLIER * delta,
			WATER_MAX_FALL_SPEED
		)
		return

	var gravity_multiplier := 1.0
	var max_fall_speed := MAX_FALL_SPEED
	var anti_gravity_enabled := is_world_anti_gravity_enabled()
	if velocity.y > 0.0:
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER
		if anti_gravity_enabled:
			gravity_multiplier *= ANTI_GRAVITY_FALL_MULTIPLIER
			max_fall_speed *= ANTI_GRAVITY_MAX_FALL_SPEED_MULTIPLIER
	elif velocity.y < 0.0 and not jump_is_down:
		gravity_multiplier = LOW_JUMP_GRAVITY_MULTIPLIER

	if velocity.y < 0.0 and anti_gravity_enabled:
		gravity_multiplier *= ANTI_GRAVITY_ASCENT_GRAVITY_MULTIPLIER

	velocity.y = min(velocity.y + gravity * gravity_multiplier * delta, max_fall_speed)


func apply_horizontal_movement(direction: float, delta: float):
	var in_water = is_standing_on_water()
	if in_water:
		last_slippery_surface_data.clear()
		airborne_slippery_surface_data.clear()

	var slippery_surface_data = get_active_slippery_surface_data()
	var on_slippery_surface = not slippery_surface_data.is_empty()
	var slow_surface_data = get_standing_slow_surface_data()
	var speed_multiplier := WATER_SPEED_MULTIPLIER if in_water else 1.0
	if not in_water and not slow_surface_data.is_empty():
		speed_multiplier *= clampf(float(slow_surface_data.get("movement_speed_multiplier", 1.0)), 0.05, 1.0)
	if on_slippery_surface and not in_water:
		speed_multiplier *= maxf(1.0, float(slippery_surface_data.get("slippery_speed_multiplier", SLIPPERY_SPEED_MULTIPLIER)))
	var target_speed = direction * SPEED * speed_multiplier
	var acceleration = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION

	if direction == 0.0:
		acceleration = GROUND_FRICTION if is_on_floor() else AIR_ACCELERATION

	if on_slippery_surface and not in_water:
		if direction == 0.0:
			acceleration = float(slippery_surface_data.get("slippery_friction", SLIPPERY_FRICTION))
		else:
			acceleration = float(slippery_surface_data.get("slippery_acceleration", SLIPPERY_ACCELERATION))
	elif is_punch_knockback_sliding() and not in_water:
		acceleration = PUNCH_KNOCKBACK_SLIDE_FRICTION if direction == 0.0 else PUNCH_KNOCKBACK_SLIDE_ACCELERATION

	if in_water:
		acceleration = WATER_FRICTION if direction == 0.0 else WATER_ACCELERATION

	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)


func update_jump_input_state() -> void:
	var jump_down = is_jump_pressed()
	jump_is_down = jump_down
	jump_just_pressed = (jump_down and not jump_was_down) or Input.is_action_just_pressed("jump")
	jump_just_released = (not jump_down and jump_was_down) or Input.is_action_just_released("jump")
	jump_was_down = jump_down


func update_variable_jump_release() -> void:
	if velocity.y >= 0.0:
		variable_jump_active = false
		return

	if not jump_just_released or not variable_jump_active:
		return

	if velocity.y < variable_jump_release_velocity:
		velocity.y = variable_jump_release_velocity

	variable_jump_active = false


func get_horizontal_input_direction() -> float:
	var direction = Input.get_axis("move_left", "move_right")

	if Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0

	if Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	return clamp(direction, -1.0, 1.0)


func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)


func is_movement_input_locked() -> bool:
	var w = get_world_controller()

	if w != null and w.has_method("is_movement_locked"):
		return bool(w.is_movement_locked())

	return false


func is_player_dead_or_respawning() -> bool:
	var w = get_world_controller()

	if w != null and w.has_method("is_player_dead_or_respawning"):
		return bool(w.is_player_dead_or_respawning())

	return false


func is_world_anti_gravity_enabled() -> bool:
	var w = get_world_controller()
	if w != null and w.has_method("is_anti_gravity_enabled"):
		return bool(w.is_anti_gravity_enabled())
	return false


func get_world_controller():
	if cached_world_controller != null and is_instance_valid(cached_world_controller) and cached_world_controller.has_method("is_movement_locked"):
		return cached_world_controller

	var parent = get_parent()

	if parent != null:
		var sibling_world = parent.get_node_or_null("World")

		if sibling_world != null and sibling_world.has_method("is_movement_locked"):
			cached_world_controller = sibling_world
			return sibling_world

	var node = parent

	while node != null:
		if node.has_method("is_movement_locked"):
			cached_world_controller = node
			return node

		var world_child = node.get_node_or_null("World")

		if world_child != null and world_child.has_method("is_movement_locked"):
			cached_world_controller = world_child
			return world_child

		node = node.get_parent()

	return null


func try_jump() -> bool:
	if is_standing_on_water():
		do_swim_jump()
		return true

	if is_on_floor() or coyote_timer > 0.0:
		preserve_slippery_surface_for_air()
		do_jump()
		coyote_timer = 0.0
		return true

	var extra_air_jumps = get_extra_air_jumps_allowed()

	# -1 means infinite air jumps.
	if extra_air_jumps < 0:
		do_jump()
		return true

	if air_jumps_used < extra_air_jumps:
		air_jumps_used += 1
		do_jump()
		return true

	return false


func do_jump():
	var jump_velocity := JUMP_VELOCITY * get_jump_velocity_multiplier()
	if is_world_anti_gravity_enabled():
		jump_velocity *= ANTI_GRAVITY_JUMP_MULTIPLIER
	velocity.y = jump_velocity
	variable_jump_release_velocity = jump_velocity * JUMP_RELEASE_VELOCITY_FACTOR
	variable_jump_active = true
	if is_in_water_for_jump_sound():
		play_water_jump_sound()
	else:
		play_jump_sound()


func get_jump_velocity_multiplier() -> float:
	var slow_surface_data = get_standing_slow_surface_data()
	if slow_surface_data.is_empty():
		return 1.0
	return clampf(float(slow_surface_data.get("jump_velocity_multiplier", 1.0)), 0.05, 1.0)


func do_swim_jump():
	velocity.y = min(velocity.y, WATER_SWIM_JUMP_VELOCITY)
	spawn_water_splash_particles(0.80)
	water_splash_cooldown = WATER_SPLASH_MOVE_COOLDOWN
	play_water_jump_sound()


func is_in_water_for_jump_sound() -> bool:
	return is_standing_on_water() or is_underwater_for_bubbles() or get_water_contact_surface_y() != INF


func play_jump_sound():
	var w = get_world_controller()
	if w != null and w.has_method("play_sound_jump"):
		w.play_sound_jump(global_position)


func play_water_jump_sound():
	var w = get_world_controller()
	if w != null and w.has_method("play_sound_water_jump"):
		w.play_sound_water_jump(global_position)
		return

	play_jump_sound()


func get_extra_air_jumps_allowed() -> int:
	var back_item = get_equipped_back_item_id()
	if back_item == "":
		return 0

	var jump_type = "double"
	var world = get_world_controller()
	if world != null:
		var item_database = world.get("item_database")
		if item_database is Dictionary and item_database.has(back_item):
			jump_type = str(item_database[back_item].get("jump_type", "double"))

	match jump_type:
		"infinite":
			return -1
		"double":
			# 2 total jumps = ground jump + 1 air jump.
			return 1
		"none":
			return 0

	return -1 if back_item == LEGENDARY_WINGS_ID else 1


func get_equipped_back_item_id() -> String:
	var world = get_world_controller()
	if world != null:
		var world_back_item = world.get("equipped_back_item")
		if world_back_item != null:
			return str(world_back_item)

	var node = get_parent()

	while node != null:
		var value = node.get("equipped_back_item")

		if value != null:
			return str(value)

		node = node.get_parent()

	return ""
