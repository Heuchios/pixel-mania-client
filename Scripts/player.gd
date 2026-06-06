extends CharacterBody2D

const SPEED = 175.0
const JUMP_VELOCITY = -420.0
const GROUND_ACCELERATION = 3200.0
const AIR_ACCELERATION = 2200.0
const GROUND_FRICTION = 3400.0
const JUMP_BUFFER_TIME = 0.10
const COYOTE_TIME = 0.10
const FALL_GRAVITY_MULTIPLIER = 1.18
const LOW_JUMP_GRAVITY_MULTIPLIER = 1.42
const MAX_FALL_SPEED = 760.0
const WATER_SPEED_MULTIPLIER = 0.55
const WATER_ACCELERATION = 1200.0
const WATER_FRICTION = 1600.0
const WATER_GRAVITY_MULTIPLIER = 0.28
const WATER_MAX_FALL_SPEED = 140.0
const WATER_SWIM_JUMP_VELOCITY = -230.0
const BASE_BODY_Z_INDEX = 0
const BASE_BACK_Z_INDEX = -2
const BASE_FRONT_Z_INDEX = 1
const BASE_PANT_Z_INDEX = 1
const BASE_HAIR_Z_INDEX = 2
const BASE_SHOES_Z_INDEX = 2
const BASE_TOOL_Z_INDEX = 2
const BASE_PLAYER_Z_INDEX = 100
const WATER_PLAYER_Z_INDEX_OFFSET = 0
const WATER_CHILD_Z_INDEX_OFFSET = 0
const WATER_BLOCK_ID = "water"
const SPRINGBOARD_DEFAULT_JUMP_VELOCITY = JUMP_VELOCITY
const LAVA_BLOCK_ID = "lava"
const LAVA_DEFAULT_TOP_VELOCITY = JUMP_VELOCITY
const LAVA_DEFAULT_SIDE_KNOCKBACK_VELOCITY = 300.0
const LAVA_DEFAULT_BOTTOM_KNOCKBACK_VELOCITY = 280.0
const LAVA_REBOUND_NORMAL_THRESHOLD = 0.55
const INVALID_LAVA_GRID_POS = Vector2i(-999999, -999999)

# Back item jump rules:
# - No back item = normal single jump
# - Any normal back item = 2 total jumps
# - Legendary Wings = infinite jumps
const LEGENDARY_WINGS_ID = "legendary_wings"

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var air_jumps_used = 0
var jump_was_down = false
var jump_buffer_timer = 0.0
var coyote_timer = 0.0


func _ready():
	_apply_player_visual_z_indices(false)


func _physics_process(delta):
	var on_floor_before_move = is_on_floor()

	if on_floor_before_move:
		air_jumps_used = 0
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	var direction = 0.0
	var movement_locked = is_movement_input_locked()

	if movement_locked:
		refresh_jump_pressed_state()
	else:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			direction -= 1.0

		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			direction += 1.0

		if is_jump_just_pressed():
			jump_buffer_timer = JUMP_BUFFER_TIME

	if movement_locked:
		jump_buffer_timer = 0.0
	elif jump_buffer_timer > 0.0:
		if try_jump():
			jump_buffer_timer = 0.0
		else:
			jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	apply_gravity(delta)
	apply_horizontal_movement(direction, delta)

	move_and_slide()
	update_lava_rebound()
	update_springboard_bounce()
	update_player_water_depth()

	if is_on_floor():
		air_jumps_used = 0
		coyote_timer = COYOTE_TIME


func update_player_water_depth():
	if is_standing_on_water():
		_apply_player_visual_z_indices(true)
	else:
		_apply_player_visual_z_indices(false)


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

	var world = get_world_controller()
	if world != null and world.has_method("play_springboard_block_animation") and springboard_data.has("grid_pos"):
		world.play_springboard_block_animation(springboard_data["grid_pos"])

	if world != null and world.has_method("play_sound_jump"):
		world.play_sound_jump()


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
	var sample_x_offsets = [
		-half_extents.x * 0.45,
		0.0,
		half_extents.x * 0.45
	]

	for x_offset in sample_x_offsets:
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


func update_lava_rebound():
	if is_on_floor():
		var standing_lava_data = get_standing_lava_rebound_data()
		if not standing_lava_data.is_empty():
			apply_lava_rebound(Vector2.UP, standing_lava_data)
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
		apply_lava_rebound(normal, item_data)
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
	var sample_x_offsets = [
		-half_extents.x * 0.45,
		0.0,
		half_extents.x * 0.45
	]

	for x_offset in sample_x_offsets:
		var sample_grid = Vector2i(
			int(round((global_position.x + x_offset) / block_size)),
			int(round(sample_y / block_size))
		)

		if not is_lava_rebound_block_at_grid(sample_grid):
			continue

		var block_type = get_block_type_at_grid(sample_grid)
		return get_world_item_data(world, block_type)

	return {}


func get_lava_grid_pos_from_collision(collision) -> Vector2i:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return INVALID_LAVA_GRID_POS

	var collider = collision.get_collider()
	if collider == null:
		return INVALID_LAVA_GRID_POS

	var collider_node = collider
	if collider_node is CollisionShape2D:
		collider_node = collider_node.get_parent()

	if not (collider_node is Node2D):
		return INVALID_LAVA_GRID_POS

	var block_size = get_world_block_size(world)
	var grid_pos = Vector2i(
		int(round(collider_node.global_position.x / block_size)),
		int(round(collider_node.global_position.y / block_size))
	)

	if is_lava_rebound_block_at_grid(grid_pos):
		return grid_pos

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


func apply_lava_rebound(normal: Vector2, item_data: Dictionary):
	apply_lava_contact_damage()

	if normal.y < -LAVA_REBOUND_NORMAL_THRESHOLD:
		velocity.y = float(item_data.get("lava_top_velocity", LAVA_DEFAULT_TOP_VELOCITY))
		air_jumps_used = 0
		coyote_timer = 0.0
		play_jump_sound()
		return

	if normal.y > LAVA_REBOUND_NORMAL_THRESHOLD:
		velocity.y = float(item_data.get("lava_bottom_knockback_velocity", LAVA_DEFAULT_BOTTOM_KNOCKBACK_VELOCITY))
		coyote_timer = 0.0
		return

	if abs(normal.x) > LAVA_REBOUND_NORMAL_THRESHOLD:
		velocity.x = normal.x * float(item_data.get("lava_side_knockback_velocity", LAVA_DEFAULT_SIDE_KNOCKBACK_VELOCITY))
		coyote_timer = 0.0


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


func is_standing_on_water() -> bool:
	var world = get_world_controller()
	if world == null or not is_instance_valid(world):
		return false

	var blocks = world.get("blocks")
	if not blocks is Dictionary:
		return false

	var block_size = 32.0
	var block_size_value = world.get("BLOCK_SIZE")
	if block_size_value is int or block_size_value is float:
		block_size = float(block_size_value)
	var half_extents = _get_collision_half_extents()
	var feet_y = global_position.y + half_extents.y
	var sample_x_offsets = [
		-half_extents.x * 0.35,
		0.0,
		half_extents.x * 0.35
	]

	for x_offset in sample_x_offsets:
		var sample_x = global_position.x + x_offset
		var sample_grid = Vector2i(
			int(floor(sample_x / block_size)),
			int(floor(feet_y / block_size))
		)
		if not blocks.has(sample_grid):
			continue
		var block_data = blocks[sample_grid]
		var block_type = str(block_data.get("type", "")).to_lower()
		if block_type == WATER_BLOCK_ID:
			return true

	return false


func _get_collision_half_extents() -> Vector2:
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		return Vector2(8.0, 8.0)

	var shape = collision_shape.shape
	if shape == null:
		return Vector2(8.0, 8.0)

	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		return rect_shape.size * 0.5 * Vector2(abs(collision_shape.scale.x), abs(collision_shape.scale.y))

	return Vector2(8.0, 8.0)


func _apply_player_visual_z_indices(in_water: bool):
	var player_z_offset = WATER_PLAYER_Z_INDEX_OFFSET if in_water else 0
	var child_z_offset = WATER_CHILD_Z_INDEX_OFFSET if in_water else 0
	var body_sprite = get_node_or_null("Sprite2D")
	var back_sprite = get_node_or_null("BackSocket/BackSprite")

	self.z_index = BASE_PLAYER_Z_INDEX + player_z_offset

	if is_instance_valid(body_sprite):
		body_sprite.z_index = BASE_BODY_Z_INDEX + child_z_offset
	if is_instance_valid(back_sprite):
		back_sprite.z_index = BASE_BACK_Z_INDEX + child_z_offset


func apply_gravity(delta: float):
	if is_on_floor():
		return

	if is_standing_on_water():
		velocity.y = min(
			velocity.y + gravity * WATER_GRAVITY_MULTIPLIER * delta,
			WATER_MAX_FALL_SPEED
		)
		return

	var gravity_multiplier = 1.0
	if velocity.y > 0.0:
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER
	elif velocity.y < 0.0 and not is_jump_pressed():
		gravity_multiplier = LOW_JUMP_GRAVITY_MULTIPLIER

	velocity.y = min(velocity.y + gravity * gravity_multiplier * delta, MAX_FALL_SPEED)


func apply_horizontal_movement(direction: float, delta: float):
	var in_water = is_standing_on_water()
	var target_speed = direction * SPEED * (WATER_SPEED_MULTIPLIER if in_water else 1.0)
	var acceleration = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION

	if direction == 0.0:
		acceleration = GROUND_FRICTION if is_on_floor() else AIR_ACCELERATION

	if in_water:
		acceleration = WATER_FRICTION if direction == 0.0 else WATER_ACCELERATION

	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)


func is_jump_just_pressed() -> bool:
	var jump_down = is_jump_pressed()
	var just_pressed = jump_down and not jump_was_down
	jump_was_down = jump_down

	return just_pressed


func refresh_jump_pressed_state():
	jump_was_down = is_jump_pressed()


func is_jump_pressed() -> bool:
	return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)


func is_movement_input_locked() -> bool:
	var w = get_world_controller()

	if w != null and w.has_method("is_movement_locked"):
		return bool(w.is_movement_locked())

	return false


func get_world_controller():
	var parent = get_parent()

	if parent != null:
		var sibling_world = parent.get_node_or_null("World")

		if sibling_world != null and sibling_world.has_method("is_movement_locked"):
			return sibling_world

	var node = parent

	while node != null:
		if node.has_method("is_movement_locked"):
			return node

		var world_child = node.get_node_or_null("World")

		if world_child != null and world_child.has_method("is_movement_locked"):
			return world_child

		node = node.get_parent()

	return null


func try_jump() -> bool:
	if is_standing_on_water():
		do_swim_jump()
		return true

	if is_on_floor() or coyote_timer > 0.0:
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
	velocity.y = JUMP_VELOCITY
	play_jump_sound()


func do_swim_jump():
	velocity.y = min(velocity.y, WATER_SWIM_JUMP_VELOCITY)
	play_jump_sound()


func play_jump_sound():
	var w = get_node_or_null("../../World")
	if w == null:
		w = get_node_or_null("../World")
	if w != null and w.has_method("play_sound_jump"):
		w.play_sound_jump()


func get_extra_air_jumps_allowed() -> int:
	var back_item = get_equipped_back_item_id()

	if back_item == LEGENDARY_WINGS_ID:
		return -1

	if back_item != "":
		# 2 total jumps = ground jump + 1 air jump.
		return 1

	return 0


func get_equipped_back_item_id() -> String:
	var node = get_parent()

	while node != null:
		var value = node.get("equipped_back_item")

		if value != null:
			return str(value)

		node = node.get_parent()

	return ""
