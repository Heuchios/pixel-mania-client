extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

var world = null

const DEBUG_ACTION_POSITION_FLOW := false
const HURT_FACE_EXPRESSION_TIME_MSEC := 550
const PUNCH_FACE_EXPRESSION_TIME_MSEC := 260
const DEAD_FACE_EXPRESSION_TIME := 1.0
const DEAD_SPIRIT_FACE_EXPRESSION_TIME := 3.0

var respawn_sequence_running := false
var respawn_sequence_id := 0


func debug_action_position_flow(message: String) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][PlayerManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text)


func setup(world_ref):
	world = world_ref


func update_back_item_jump_reset():
	if world.player == null:
		return

	if world.player is CharacterBody2D:
		if world.player.is_on_floor():
			world.back_item_air_jumps_used = 0

func try_back_item_air_jump(event: InputEventKey) -> bool:
	if world.player == null:
		return false

	if not (world.player is CharacterBody2D):
		return false

	# Your normal world.player script handles the ground jump.
	# This function only adds extra air jumps from back items.
	var is_jump_key = event.keycode == KEY_W or event.keycode == KEY_UP

	if not is_jump_key:
		return false

	if world.player.is_on_floor():
		world.back_item_air_jumps_used = 0
		return false

	var allowed_air_jumps = world.get_allowed_back_item_air_jumps()

	if allowed_air_jumps == 0:
		return false

	if allowed_air_jumps < 0:
		world.perform_back_item_air_jump()
		return true

	if world.back_item_air_jumps_used < allowed_air_jumps:
		world.back_item_air_jumps_used += 1
		world.perform_back_item_air_jump()
		return true

	return false

func perform_back_item_air_jump():
	if world.player == null:
		return

	if not (world.player is CharacterBody2D):
		return

	world.player.velocity.y = world.BACK_ITEM_JUMP_VELOCITY

	# Force the wings to start flapping immediately.
	if world.equipment_manager != null and world.equipment_manager.has_method("update_back_item_animation"):
		world.equipment_manager.update_back_item_animation(0.2)

func get_allowed_back_item_air_jumps() -> int:
	if world.equipped_back_item == "":
		return 0

	var jump_type = "double"

	if world.item_database.has(world.equipped_back_item):
		jump_type = str(world.item_database[world.equipped_back_item].get("jump_type", "double"))

	match jump_type:
		"infinite":
			# -1 means infinite air jumps.
			return -1

		"double":
			# 2 total jumps = ground jump + 1 air jump.
			return 1

		"none":
			return 0

		_:
			# Future back items default to 2 total jumps unless the database says otherwise.
			return 1

func update_chat_typing_movement_lock():
	if world.player == null:
		return

	var should_lock = false
	if world.has_method("is_movement_locked"):
		should_lock = bool(world.is_movement_locked())
	else:
		should_lock = world.is_any_text_input_focused() or world.is_chat_input_focused() or world.is_sign_text_focused() or world.is_inventory_search_focused() or world.is_world_menu_open() or world.is_world_name_input_focused()

	# Noclip manages physics separately, but it should still stop when UI owns input.
	if world.noclip_enabled:
		world.chat_typing_movement_locked = should_lock
		return

	if should_lock and not world.chat_typing_movement_locked:
		world.chat_typing_movement_locked = true

		if world.player is CharacterBody2D:
			world.player.velocity.x = 0.0

	if not should_lock and world.chat_typing_movement_locked:
		world.chat_typing_movement_locked = false

func toggle_noclip():
	world.set_noclip_enabled(not world.noclip_enabled)

func set_noclip_enabled(enabled: bool):
	if world.noclip_enabled == enabled:
		return

	world.noclip_enabled = enabled

	if world.player != null:
		if world.noclip_enabled:
			# Stop the world.player's own gravity/movement code while noclip is active.
			# World.gd controls movement during noclip instead.
			if not world.chat_typing_movement_locked:
				world.player_physics_enabled_before_noclip = world.player.is_physics_processing()

			world.player.set_physics_process(false)
		else:
			# Important fix:
			# Always restore world.player physics after noclip turns off.
			# Before, if /noc was typed while chat had focus, the saved state could be false,
			# causing the world.player to stay frozen.
			world.chat_typing_movement_locked = false
			world.player.set_physics_process(true)

	world.set_player_collision_enabled(not world.noclip_enabled)

	if world.player != null and world.player is CharacterBody2D:
		world.player.velocity = Vector2.ZERO

	if world.noclip_enabled:
		world.show_notification("Noclip enabled.")
	else:
		world.show_notification("Noclip disabled.")

	world.update_all_ui()

func is_noclip_enabled() -> bool:
	return world.noclip_enabled

func set_player_collision_enabled(enabled: bool):
	if world.player == null:
		return

	for child in world.player.get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled

	var deep_shapes = world.player.find_children("*", "CollisionShape2D", true, false)

	for shape in deep_shapes:
		shape.disabled = not enabled

func update_noclip_movement(delta):
	if not world.noclip_enabled:
		return

	if world.player == null:
		return

	if world.has_method("is_movement_locked") and world.is_movement_locked():
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
		return

	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	if direction.length() > 0:
		direction = direction.normalized()
		world.player.global_position += direction * world.NOCLIP_SPEED * delta

	# Keep the world.player frozen when no keys are pressed.
	# This prevents slow gravity drift while noclip is active.
	if world.player is CharacterBody2D:
		world.player.velocity = Vector2.ZERO

func update_player_facing_direction():
	if world.has_method("is_movement_locked") and world.is_movement_locked():
		return

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		world.player_facing_direction = -1
		return

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		world.player_facing_direction = 1
		return

	if world.player != null:
		if world.player.velocity.x < -1:
			world.player_facing_direction = -1
		elif world.player.velocity.x > 1:
			world.player_facing_direction = 1

func setup_world_camera_limits():
	var camera = world.get_player_camera()

	if camera == null:
		return

	# Use the real visual edge of the block grid, not world.WORLD_WIDTH * world.BLOCK_SIZE.
	# This removes the empty half-block strip on the right/bottom edges.
	camera.limit_left = int(world.WORLD_VISUAL_LEFT)
	camera.limit_top = int(world.WORLD_VISUAL_TOP)
	camera.limit_right = int(world.WORLD_VISUAL_RIGHT)
	camera.limit_bottom = int(world.WORLD_VISUAL_BOTTOM)

	# Sharp, responsive pixel movement reads cleaner than smoothed following in this style.
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = 0.0
	camera.limit_smoothed = true

	# Drag margins can make the camera feel like it is showing outside edges.
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false

	world.apply_camera_zoom()
	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()

func get_player_camera():
	if world.player == null:
		return null

	var camera = world.player.get_node_or_null("Camera2D")

	if camera != null and camera is Camera2D:
		return camera

	var found_camera = world.player.find_child("Camera2D", true, false)

	if found_camera != null and found_camera is Camera2D:
		return found_camera

	return null

func apply_camera_zoom():
	var camera = world.get_player_camera()

	if camera == null:
		return

	world.current_camera_zoom = clamp(world.current_camera_zoom, world.CAMERA_ZOOM_MIN, world.CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(world.current_camera_zoom, world.current_camera_zoom)

func zoom_camera(amount: float):
	world.current_camera_zoom = clamp(world.current_camera_zoom + amount, world.CAMERA_ZOOM_MIN, world.CAMERA_ZOOM_MAX)
	world.apply_camera_zoom()

	if amount > 0.0:
		world.show_notification("Zoom In: " + str(snapped(world.current_camera_zoom, 0.01)) + "x")
	else:
		world.show_notification("Zoom Out: " + str(snapped(world.current_camera_zoom, 0.01)) + "x")

func reset_camera_zoom():
	world.current_camera_zoom = world.CAMERA_ZOOM_DEFAULT
	world.apply_camera_zoom()
	world.show_notification("Zoom Reset")

func set_default_camera_zoom_silent():
	world.current_camera_zoom = world.CAMERA_ZOOM_DEFAULT
	world.apply_camera_zoom()

func can_use_camera_zoom(ignore_chat_text_focus: bool = false) -> bool:
	if world.has_method("is_movement_blocking_ui_open") and world.is_movement_blocking_ui_open():
		return false

	var chat_input_focused: bool = bool(world.is_chat_input_focused())
	if world.is_any_text_input_focused() and not (ignore_chat_text_focus and chat_input_focused):
		return false

	if chat_input_focused and not ignore_chat_text_focus:
		return false

	if world.is_inventory_search_focused():
		return false

	if world.is_inventory_open():
		return false

	if world.is_shop_open():
		return false

	if world.is_crafting_open():
		return false

	if world.is_player_menu_open():
		return false

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return false

	if world.is_world_menu_open():
		return false

	if world.has_method("is_trade_open") and world.is_trade_open():
		return false

	return true

func clamp_player_to_world():
	if world.player == null:
		return

	# Keep the world.player center inside the usable world.
	var min_x = 0.0
	var max_x = float((world.WORLD_WIDTH - 1) * world.BLOCK_SIZE)

	var min_y = 0.0
	var max_y = float((world.WORLD_HEIGHT - 1) * world.BLOCK_SIZE)

	var old_position = world.player.global_position

	var clamped_position = Vector2(
		clamp(old_position.x, min_x, max_x),
		clamp(old_position.y, min_y, max_y)
	)

	if clamped_position != old_position:
		debug_action_position_flow("clamp_player_to_world changing position from " + str(old_position) + " to " + str(clamped_position))
		world.player.global_position = clamped_position

		if world.player is CharacterBody2D:
			if clamped_position.x != old_position.x:
				world.player.velocity.x = 0

			if clamped_position.y != old_position.y:
				world.player.velocity.y = 0

func check_lava_damage(delta):
	if world.player == null:
		return

	world.lava_damage_timer -= delta

	var player_grid_pos = world.get_player_grid_position()
	var block_below_player = Vector2i(player_grid_pos.x, player_grid_pos.y + 1)

	if world.is_lava_block(player_grid_pos) or world.is_lava_block(block_below_player):
		if world.lava_damage_timer <= 0:
			world.damage_player(1)
			world.lava_damage_timer = world.LAVA_DAMAGE_DELAY

func damage_player(amount: int):
	world.player_health -= amount

	if world.player_health <= 0:
		world.player_health = 0
		debug_action_position_flow("damage_player triggering respawn amount=" + str(amount))
		world.respawn_player()
		world.update_all_ui()
		return

	if world.player != null:
		world.player.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + HURT_FACE_EXPRESSION_TIME_MSEC)
		play_player_hurt_animation()

	world.update_all_ui()


func play_player_hurt_animation():
	if world == null or world.player == null:
		return

	start_player_hurt_modulate_reset_timer()

	var animation_player = world.player.get_node_or_null("AnimationPlayer")
	if animation_player is AnimationPlayer and animation_player.has_animation("hurt"):
		animation_player.play("hurt")
		return

	if animation_player != null:
		var child_player = animation_player.get_node_or_null("hurt")
		if child_player == null:
			child_player = animation_player.get_node_or_null("Hurt")
		if child_player is AnimationPlayer and child_player.has_animation("hurt"):
			child_player.play("hurt")


func start_player_hurt_modulate_reset_timer():
	if world == null or world.player == null:
		return

	var sequence_id = int(world.player.get_meta("hurt_modulate_sequence_id", 0)) + 1
	world.player.set_meta("hurt_modulate_sequence_id", sequence_id)
	get_tree().create_timer(float(HURT_FACE_EXPRESSION_TIME_MSEC) / 1000.0).timeout.connect(Callable(self, "_reset_player_hurt_modulate").bind(sequence_id))


func _reset_player_hurt_modulate(sequence_id: int):
	if world == null or world.player == null:
		return

	if int(world.player.get_meta("hurt_modulate_sequence_id", 0)) != sequence_id:
		return

	var visual = world.player.get_node_or_null("PlayerVisual")
	if visual is CanvasItem:
		visual.modulate = Color.WHITE


func play_player_punch_animation():
	if world == null or world.player == null:
		return

	world.player.set_meta("face_punch_until_msec", Time.get_ticks_msec() + PUNCH_FACE_EXPRESSION_TIME_MSEC)

	var animation_player = world.player.get_node_or_null("AnimationPlayer")
	if play_animation_on_player(animation_player, "punch"):
		return

	if animation_player != null:
		var child_player = animation_player.get_node_or_null("punch")
		if child_player == null:
			child_player = animation_player.get_node_or_null("Punch")
		if play_animation_on_player(child_player, "punch"):
			return

	var direct_player = world.player.get_node_or_null("punch")
	if direct_player == null:
		direct_player = world.player.get_node_or_null("Punch")
	play_animation_on_player(direct_player, "punch")


func play_animation_on_player(animation_player, animation_name: String) -> bool:
	if not (animation_player is AnimationPlayer):
		return false

	var actual_animation = animation_name
	if not animation_player.has_animation(actual_animation):
		var capitalized_name = animation_name.capitalize()
		if animation_player.has_animation(capitalized_name):
			actual_animation = capitalized_name
		else:
			return false

	animation_player.stop()
	animation_player.play(actual_animation)
	return true

func respawn_player():
	if world != null and bool(world.get_meta("world_entry_in_progress", false)):
		place_player_at_entrance_immediate()
		return

	if respawn_sequence_running:
		return

	respawn_sequence_running = true
	respawn_sequence_id += 1
	var sequence_id = respawn_sequence_id

	if world.player != null:
		world.player.set_meta("face_expression_override", "dead")
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
			world.player.set_physics_process(false)

	get_tree().create_timer(DEAD_FACE_EXPRESSION_TIME).timeout.connect(Callable(self, "_show_dead_spirit_before_respawn").bind(sequence_id))


func _show_dead_spirit_before_respawn(sequence_id: int):
	if sequence_id != respawn_sequence_id:
		return

	if world.player != null:
		world.player.set_meta("face_expression_override", "dead_spirit")

	get_tree().create_timer(DEAD_SPIRIT_FACE_EXPRESSION_TIME).timeout.connect(Callable(self, "_complete_respawn_sequence").bind(sequence_id))


func _complete_respawn_sequence(sequence_id: int):
	if sequence_id != respawn_sequence_id:
		return

	complete_respawn_player()
	respawn_sequence_running = false


func complete_respawn_player():
	world.player_health = 10
	world.lava_damage_timer = 0.0

	if world.player != null:
		world.player.set_meta("face_expression_override", "")
		world.player.set_meta("face_hurt_until_msec", 0)
		var spawn_pos = world.get_entrance_gate_spawn_position()
		debug_action_position_flow("respawn_player setting position to " + str(spawn_pos))
		world.player.global_position = spawn_pos
		world.player.velocity = Vector2.ZERO
		world.player.set_physics_process(true)
		var camera = world.get_player_camera()
		if camera != null and camera.has_method("reset_smoothing"):
			camera.reset_smoothing()

	world.update_all_ui()


func place_player_at_entrance_immediate():
	respawn_sequence_running = false
	respawn_sequence_id += 1
	world.player_health = 10
	world.lava_damage_timer = 0.0

	if world.player != null:
		world.player.set_meta("face_expression_override", "")
		world.player.set_meta("face_hurt_until_msec", 0)
		var spawn_pos = world.get_entrance_gate_spawn_position()
		debug_action_position_flow("place_player_at_entrance_immediate setting position to " + str(spawn_pos))
		world.player.global_position = spawn_pos
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
			world.player.set_physics_process(true)
		var camera = world.get_player_camera()
		if camera != null and camera.has_method("reset_smoothing"):
			camera.reset_smoothing()

	world.update_all_ui()


# --- Multiplayer Polish v2: remote player visuals + smoothing ---
const CHAT_BUBBLE_COMPONENT = preload("res://Scripts/chat_bubble_component.gd")
var remote_players := {}
var remote_name_labels := {}
var remote_chat_bubbles := {}
var remote_chat_pending_messages := {}
var remote_players_root = null
var network_position_timer := 0.0
var network_heartbeat_timer := 0.0
var last_sent_network_position := Vector2(999999, 999999)
const NETWORK_POSITION_SEND_INTERVAL := 0.05
const NETWORK_POSITION_HEARTBEAT_INTERVAL := 1.0
const NETWORK_POSITION_MIN_DISTANCE := 1.0

const REMOTE_NAME_LABEL_WIDTH := 300.0
const REMOTE_NAME_LABEL_HEIGHT := 30.0
const REMOTE_NAME_LABEL_MARGIN_ABOVE_HEAD_WORLD_PX := 10.0
const REMOTE_NAME_LABEL_FALLBACK_OFFSET_WORLD_PX := 58.0
const REMOTE_NAME_FONT_SIZE := 26
const REMOTE_NAME_OUTLINE_SIZE := 8
const WORLD_LOCK_OWNER_NAME_COLOR := Color(1.0, 0.623529, 0.109804, 1.0)
const WORLD_LOCK_ACCESS_NAME_COLOR := Color(1.0, 0.768627, 0.419608, 1.0)
const WORLD_LOCK_NAME_COLOR_DEFAULT := Color(1.0, 1.0, 1.0, 1.0)
const REMOTE_PLAYER_Z_INDEX := 95
const REMOTE_INTERPOLATION_SPEED := 15.0
const REMOTE_WALK_FRAME_TIME := 0.16
const REMOTE_IDLE_FRAME_TIME := 0.45
const REMOTE_WALK_SPEED_THRESHOLD := 8.0
const REMOTE_PLAYER_STALE_TIMEOUT := 4.0
const MAX_REMOTE_PLAYER_COORD := 1000000.0
const MAX_REMOTE_PLAYER_NAME_LENGTH := 24

var remote_idle_texture = null
var remote_idle_textures: Array = []
var remote_walk_textures: Array = []
var remote_jump_texture = null

func _safe_float(value, fallback: float, min_value: float = -1.0e9, max_value: float = 1.0e9) -> float:
	if value is int or value is float:
		var num = float(value)
		if not is_finite(num):
			return fallback
		return clamp(num, min_value, max_value)
	return fallback


func _safe_int(value, fallback: int, min_value: int = -2147483648, max_value: int = 2147483647) -> int:
	if value is int or value is float:
		return clamp(int(value), min_value, max_value)
	return fallback

func process_multiplayer_remote_visuals(delta: float):
	update_remote_players_visuals(delta)
	update_remote_name_labels()
	update_remote_chat_bubbles(delta)

func setup_remote_players_root():
	if world == null:
		return

	if remote_players_root != null and is_instance_valid(remote_players_root):
		return

	remote_players_root = world.get_node_or_null("RemotePlayers")

	if remote_players_root == null:
		remote_players_root = Node2D.new()
		remote_players_root.name = "RemotePlayers"
		world.add_child(remote_players_root)

	remote_players_root.z_as_relative = false
	remote_players_root.z_index = REMOTE_PLAYER_Z_INDEX

func update_multiplayer_movement(delta: float):
	if world == null:
		return

	if not world.in_world:
		return

	if world.player == null:
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	if not network.has_method("send_player_position"):
		return

	network_position_timer -= delta
	network_heartbeat_timer -= delta

	var can_send_movement = network_position_timer <= 0.0
	var should_send_heartbeat = network_heartbeat_timer <= 0.0

	if not can_send_movement and not should_send_heartbeat:
		return

	var current_position = world.player.global_position
	var moved_enough = current_position.distance_to(last_sent_network_position) >= NETWORK_POSITION_MIN_DISTANCE

	if not moved_enough and not should_send_heartbeat:
		return

	var sent = bool(network.send_player_position(current_position, world.player_facing_direction, world.current_world_name, true))
	if sent:
		network_position_timer = NETWORK_POSITION_SEND_INTERVAL
		network_heartbeat_timer = NETWORK_POSITION_HEARTBEAT_INTERVAL
		last_sent_network_position = current_position


func flush_multiplayer_position(allow_join: bool = false, bypass_rate_limit: bool = false) -> bool:
	if world == null:
		return false

	if not world.in_world:
		return false

	if world.player == null:
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_player_position"):
		return false

	var current_position = world.player.global_position
	debug_action_position_flow("flush_multiplayer_position allow_join=" + str(allow_join) + " bypass_rate_limit=" + str(bypass_rate_limit))
	var sent = bool(network.send_player_position(current_position, world.player_facing_direction, world.current_world_name, allow_join, bypass_rate_limit))
	if sent:
		network_position_timer = NETWORK_POSITION_SEND_INTERVAL
		network_heartbeat_timer = NETWORK_POSITION_HEARTBEAT_INTERVAL
		last_sent_network_position = current_position

	return sent

func handle_network_existing_players(players_data):
	if typeof(players_data) != TYPE_ARRAY:
		return

	var active_remote_ids = {}

	for player_data in players_data:
		if typeof(player_data) == TYPE_DICTIONARY:
			var remote_id = str(player_data.get("player_id", ""))
			if remote_id != "":
				active_remote_ids[remote_id] = true
			handle_network_player_position(player_data)

	for remote_id in remote_players.keys():
		if not active_remote_ids.has(remote_id):
			remove_remote_player(remote_id)

func handle_network_player_position(player_data: Dictionary):
	setup_remote_players_root()

	var remote_id = str(player_data.get("player_id", ""))
	if remote_id == "":
		return

	var remote_world = str(player_data.get("world", world.current_world_name)).to_upper()
	if remote_world != str(world.current_world_name).to_upper():
		remove_remote_player(remote_id)
		return

	var remote_name = get_remote_player_name_from_payload(player_data)
	var remote_identity = get_remote_player_identity_from_payload(player_data)
	remove_duplicate_remote_players_for_identity(remote_identity, remote_id)
	var remote_role = clean_remote_player_role(str(player_data.get("role", "player")))

	var remote_player = get_or_create_remote_player(remote_id, remote_name)
	if remote_player == null:
		return

	var new_target = Vector2(
		_safe_float(player_data.get("x", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD),
		_safe_float(player_data.get("y", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD)
	)
	var had_position = bool(remote_player.get_meta("has_position", false))
	var old_target = remote_player.get_meta("target_position", remote_player.global_position)
	var speed_hint = float(old_target.distance_to(new_target)) / max(NETWORK_POSITION_SEND_INTERVAL, 0.001)
	var vertical_hint = float(new_target.y - old_target.y) / max(NETWORK_POSITION_SEND_INTERVAL, 0.001)
	var animation_state = clean_remote_animation_state(str(player_data.get("animation_state", "")))

	if animation_state == "":
		if had_position and abs(vertical_hint) > 70.0:
			animation_state = "jump"
		elif speed_hint > REMOTE_WALK_SPEED_THRESHOLD:
			animation_state = "walk"
		else:
			animation_state = "idle"

	# First packet should place instantly. Later packets are smoothed in _process().
	if not had_position:
		remote_player.global_position = new_target
		remote_player.set_meta("has_position", true)

	remote_player.set_meta("target_position", new_target)
	remote_player.set_meta("remote_speed", speed_hint)
	remote_player.set_meta("remote_velocity_y", vertical_hint)
	remote_player.set_meta("animation_state", animation_state)
	var facing_raw = _safe_int(player_data.get("facing", 1), 1, -1, 1)
	var safe_facing = 1 if facing_raw >= 0 else -1
	remote_player.set_meta("facing", safe_facing)
	remote_player.set_meta("remote_name", remote_name)
	remote_player.set_meta("remote_identity", remote_identity)
	remote_player.set_meta("remote_role", remote_role)
	remote_player.set_meta("stale_time", 0.0)

	var equipment_slots = {}
	if player_data.has("equipment_slots") and player_data.get("equipment_slots") is Dictionary:
		equipment_slots = player_data.get("equipment_slots")
	else:
		equipment_slots = {
			"hand": str(player_data.get("equipped_tool", "")),
			"back": str(player_data.get("equipped_back_item", player_data.get("equipped_back", ""))),
			"hair": str(player_data.get("equipped_hair_item", "")),
			"shirt": str(player_data.get("equipped_shirt_item", "")),
			"pants": str(player_data.get("equipped_pants_item", "")),
			"shoes": str(player_data.get("equipped_shoes_item", ""))
		}

	remote_player.set_meta("equipment_slots", equipment_slots)

	update_remote_player_name(remote_player, remote_name)
	update_remote_player_facing(remote_player)
	update_remote_equipment_visuals(remote_player)
	_drain_remote_chat_message_queue(remote_id)

func handle_network_player_left(remote_id: String):
	remove_remote_player(remote_id)


func get_remote_player_profile_data(remote_id: String, remote_player, screen_distance: float = 0.0) -> Dictionary:
	if remote_player == null or not is_instance_valid(remote_player):
		return {}

	var equipment_slots = remote_player.get_meta("equipment_slots", {})
	if not (equipment_slots is Dictionary):
		equipment_slots = {}

	return {
		"player_id": remote_id,
		"name": str(remote_player.get_meta("remote_name", "Player")),
		"username": str(remote_player.get_meta("remote_name", "Player")),
		"role": str(remote_player.get_meta("remote_role", "player")),
		"world": str(world.current_world_name),
		"x": remote_player.global_position.x,
		"y": remote_player.global_position.y,
		"distance": screen_distance,
		"equipment_slots": equipment_slots.duplicate(true)
	}


func get_remote_player_at_screen_position(screen_pos: Vector2) -> Dictionary:
	if world == null or remote_players.size() == 0:
		return {}

	var closest_data = {}
	var closest_distance = 999999.0
	var canvas_transform = get_viewport().get_canvas_transform()

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var remote_screen_pos = canvas_transform * remote_player.global_position
		var distance = remote_screen_pos.distance_to(screen_pos)
		if distance > 58.0 or distance >= closest_distance:
			continue

		closest_distance = distance
		closest_data = get_remote_player_profile_data(remote_id, remote_player, distance)

	return closest_data


func get_remote_player_in_interaction_range() -> Dictionary:
	if world == null or world.player == null or remote_players.size() == 0:
		return {}

	var closest_data = {}
	var closest_score = 999999.0
	var player_pos = world.player.global_position
	var facing = 1
	if "player_facing_direction" in world:
		facing = int(world.player_facing_direction)
	if facing == 0:
		facing = 1

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var offset = remote_player.global_position - player_pos
		var forward_distance = offset.x * float(facing)
		var vertical_distance = abs(offset.y)
		var direct_distance = player_pos.distance_to(remote_player.global_position)

		if direct_distance > world.INTERACTION_PIXEL_RANGE:
			continue
		if forward_distance < -18.0:
			continue
		if vertical_distance > 74.0:
			continue

		var score = direct_distance + vertical_distance * 0.35 - forward_distance * 0.10
		if score >= closest_score:
			continue

		closest_score = score
		closest_data = get_remote_player_profile_data(remote_id, remote_player, direct_distance)

	return closest_data


func get_remote_player_profile_by_username(username: String) -> Dictionary:
	var clean_username: String = username.strip_edges().to_lower()
	if clean_username == "" or remote_players.size() == 0:
		return {}

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var remote_name: String = str(remote_player.get_meta("remote_name", "")).strip_edges()
		if remote_name.to_lower() == clean_username:
			return get_remote_player_profile_data(str(remote_id), remote_player, 0.0)

	return {}


func get_or_create_remote_player(remote_id: String, remote_name: String):
	if remote_players.has(remote_id):
		var existing = remote_players[remote_id]
		if existing != null and is_instance_valid(existing):
			update_remote_player_name(existing, remote_name)
			return existing

	setup_remote_players_root()
	if remote_players_root == null:
		return null

	ensure_remote_player_textures_loaded()

	var remote_player = Node2D.new()
	remote_player.name = "RemotePlayer_" + remote_id.substr(0, 8)
	remote_player.z_as_relative = false
	remote_player.z_index = REMOTE_PLAYER_Z_INDEX
	remote_player.set_meta("remote_id", remote_id)
	remote_player.set_meta("remote_name", remote_name)
	remote_player.set_meta("remote_identity", get_remote_player_identity_key(remote_name))
	remote_player.set_meta("remote_role", "player")
	remote_player.set_meta("facing", 1)
	remote_player.set_meta("target_position", Vector2.ZERO)
	remote_player.set_meta("has_position", false)
	remote_player.set_meta("remote_speed", 0.0)
	remote_player.set_meta("remote_velocity_y", 0.0)
	remote_player.set_meta("animation_state", "idle")
	remote_player.set_meta("walk_timer", 0.0)
	remote_player.set_meta("walk_frame", 0)
	remote_player.set_meta("idle_timer", 0.0)
	remote_player.set_meta("idle_frame", 0)
	remote_player.set_meta("stale_time", 0.0)
	remote_player.set_meta("equipment_slots", {})
	remote_players_root.add_child(remote_player)

	# Remote shadow removed: it looked like a dark block under remote players.

	var back_sprite = Sprite2D.new()
	back_sprite.name = "BackSprite"
	back_sprite.z_as_relative = false
	back_sprite.z_index = REMOTE_PLAYER_Z_INDEX - 1
	back_sprite.visible = false
	remote_player.add_child(back_sprite)

	var body_sprite = Sprite2D.new()
	body_sprite.name = "BodySprite"
	body_sprite.z_as_relative = false
	body_sprite.z_index = REMOTE_PLAYER_Z_INDEX
	body_sprite.texture = remote_idle_texture
	copy_local_player_sprite_settings(body_sprite)
	remote_player.add_child(body_sprite)

	# Fallback only if the real player texture cannot be found.
	if body_sprite.texture == null:
		var fallback = Polygon2D.new()
		fallback.name = "FallbackBody"
		fallback.polygon = PackedVector2Array([
			Vector2(-9, -24), Vector2(9, -24), Vector2(11, 10), Vector2(7, 18), Vector2(-7, 18), Vector2(-11, 10)
		])
		fallback.color = Color(0.75, 0.88, 1.0, 0.92)
		remote_player.add_child(fallback)

	var equipment_root = Node2D.new()
	equipment_root.name = "EquipmentSlots"
	equipment_root.z_as_relative = false
	equipment_root.z_index = REMOTE_PLAYER_Z_INDEX + 2
	remote_player.add_child(equipment_root)
	_ensure_remote_chat_bubble_anchor(remote_player)

	create_or_update_remote_name_label(remote_id, remote_name, str(remote_player.get_meta("remote_role", "player")))

	remote_players[remote_id] = remote_player
	return remote_player


func _ensure_remote_chat_bubble_anchor(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var existing_anchor = remote_player.get_node_or_null("ChatBubbleAnchor")
	if existing_anchor is Node2D:
		existing_anchor.position = Vector2(0.0, -CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px())
		return

	var anchor = Marker2D.new()
	anchor.name = "ChatBubbleAnchor"
	anchor.position = Vector2(0.0, -CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px())
	remote_player.add_child(anchor)

func update_remote_players_visuals(delta: float):
	if remote_players.size() == 0:
		return

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var stale_time = float(remote_player.get_meta("stale_time", 0.0)) + delta
		remote_player.set_meta("stale_time", stale_time)
		if stale_time >= REMOTE_PLAYER_STALE_TIMEOUT:
			remove_remote_player(remote_id)
			continue

		var target_position = remote_player.get_meta("target_position", remote_player.global_position)
		remote_player.global_position = remote_player.global_position.lerp(target_position, clamp(delta * REMOTE_INTERPOLATION_SPEED, 0.0, 1.0))
		update_remote_player_animation(remote_player, delta)
		update_remote_player_facing(remote_player)

func reset_multiplayer_sync_state():
	network_position_timer = 0.0
	network_heartbeat_timer = 0.0
	last_sent_network_position = Vector2(999999, 999999)

func update_remote_player_animation(remote_player, delta: float):
	if remote_player == null:
		return

	ensure_remote_player_textures_loaded()

	var body_sprite = remote_player.get_node_or_null("BodySprite")
	if body_sprite == null or not (body_sprite is Sprite2D):
		return

	var speed = float(remote_player.get_meta("remote_speed", 0.0))
	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	var walking = (animation_state == "walk" or speed > REMOTE_WALK_SPEED_THRESHOLD) and remote_walk_textures.size() > 0

	if animation_state == "jump" and remote_jump_texture != null:
		remote_player.set_meta("walk_timer", 0.0)
		remote_player.set_meta("walk_frame", 0)
		remote_player.set_meta("idle_timer", 0.0)
		remote_player.set_meta("idle_frame", 0)
		body_sprite.texture = remote_jump_texture
		remote_player.set_meta("remote_speed", lerp(speed, 0.0, clamp(delta * 8.0, 0.0, 1.0)))
		return

	if walking:
		remote_player.set_meta("idle_timer", 0.0)
		remote_player.set_meta("idle_frame", 0)
		var timer = float(remote_player.get_meta("walk_timer", 0.0)) + delta
		var frame = int(remote_player.get_meta("walk_frame", 0))

		if timer >= REMOTE_WALK_FRAME_TIME:
			timer = 0.0
			frame = (frame + 1) % remote_walk_textures.size()

		remote_player.set_meta("walk_timer", timer)
		remote_player.set_meta("walk_frame", frame)
		body_sprite.texture = remote_walk_textures[frame]
	else:
		remote_player.set_meta("walk_timer", 0.0)
		remote_player.set_meta("walk_frame", 0)
		if remote_idle_textures.size() > 0:
			var idle_timer = float(remote_player.get_meta("idle_timer", 0.0)) + delta
			var idle_frame = int(remote_player.get_meta("idle_frame", 0))

			if idle_timer >= REMOTE_IDLE_FRAME_TIME:
				idle_timer = 0.0
				idle_frame = (idle_frame + 1) % remote_idle_textures.size()

			remote_player.set_meta("idle_timer", idle_timer)
			remote_player.set_meta("idle_frame", idle_frame)
			body_sprite.texture = remote_idle_textures[idle_frame]
		elif remote_idle_texture != null:
			body_sprite.texture = remote_idle_texture

	# Decay speed so the remote player returns to idle after movement stops.
	remote_player.set_meta("remote_speed", lerp(speed, 0.0, clamp(delta * 8.0, 0.0, 1.0)))

func ensure_remote_player_textures_loaded():
	if remote_idle_texture != null:
		return

	remote_idle_texture = get_remote_player_idle_texture()
	remote_idle_textures.clear()
	remote_walk_textures.clear()
	remote_jump_texture = load_first_existing_remote_texture([
		"res://Assets/player/body/player_jump.png"
	])

	if remote_idle_texture != null:
		remote_idle_textures.append(remote_idle_texture)

	var idle_2 = load_first_existing_remote_texture([
		"res://Assets/player/body/player_idle_2.png"
	])

	var idle_3 = load_first_existing_remote_texture([
		"res://Assets/player/body/player_idle_3.png"
	])

	if idle_2 != null and not remote_idle_textures.has(idle_2):
		remote_idle_textures.append(idle_2)

	if idle_3 != null and not remote_idle_textures.has(idle_3):
		remote_idle_textures.append(idle_3)

	var walk_1 = load_first_existing_remote_texture([
		"res://Assets/player/body/player_walk_1.png"
	])

	var walk_2 = load_first_existing_remote_texture([
		"res://Assets/player/body/player_walk_2.png"
	])

	if walk_1 != null:
		remote_walk_textures.append(walk_1)
	if walk_2 != null:
		remote_walk_textures.append(walk_2)

func get_remote_player_idle_texture():
	return load_first_existing_remote_texture([
		"res://Assets/player/body/player_idle.png"
	])

func get_local_player_sprite():
	if world == null or world.player == null:
		return null

	var local_sprite = world.player.get_node_or_null("Sprite2D")
	if local_sprite == null:
		local_sprite = world.player.get_node_or_null("Sprite")
	if local_sprite == null:
		var sprite_nodes = world.player.find_children("*", "Sprite2D", true, false)
		if sprite_nodes.size() > 0:
			local_sprite = sprite_nodes[0]

	return local_sprite

func copy_local_player_sprite_settings(body_sprite: Sprite2D):
	if body_sprite == null:
		return

	var local_sprite = get_local_player_sprite()
	if local_sprite == null or not (local_sprite is Sprite2D):
		return

	body_sprite.position = local_sprite.position
	body_sprite.offset = local_sprite.offset
	body_sprite.scale = local_sprite.scale
	body_sprite.centered = local_sprite.centered

func load_first_existing_remote_texture(paths: Array):
	for path in paths:
		if ResourceLoader.exists(str(path)):
			return load(str(path))
	return null

func clean_remote_animation_state(value: String) -> String:
	var clean = value.strip_edges().to_lower()
	if ["idle", "walk", "jump"].has(clean):
		return clean
	return ""

func clean_remote_player_name(remote_name: String) -> String:
	var clean_name = remote_name.strip_edges()
	if clean_name == "":
		return "Player"

	# Keep names like USO uppercase, but fix names like hassan -> Hassan.
	if clean_name == clean_name.to_upper():
		if clean_name.length() > MAX_REMOTE_PLAYER_NAME_LENGTH:
			clean_name = clean_name.substr(0, MAX_REMOTE_PLAYER_NAME_LENGTH)
		return clean_name

	if clean_name.length() > MAX_REMOTE_PLAYER_NAME_LENGTH:
		clean_name = clean_name.substr(0, MAX_REMOTE_PLAYER_NAME_LENGTH)

	if clean_name.length() == 1:
		return clean_name.to_upper()

	return clean_name.substr(0, 1).to_upper() + clean_name.substr(1)


func get_remote_player_raw_name_from_payload(player_data: Dictionary) -> String:
	for key in ["display_name", "account_username", "username", "name"]:
		if not player_data.has(key):
			continue

		var candidate = str(player_data.get(key, "")).strip_edges()
		if candidate != "":
			return candidate

	return ""


func get_remote_player_name_from_payload(player_data: Dictionary) -> String:
	var raw_name = get_remote_player_raw_name_from_payload(player_data)
	if raw_name == "":
		return "Player"

	return clean_remote_player_name(raw_name)


func get_remote_player_identity_key(raw_name: String) -> String:
	return raw_name.strip_edges().to_lower()


func get_remote_player_identity_from_payload(player_data: Dictionary) -> String:
	return get_remote_player_identity_key(get_remote_player_raw_name_from_payload(player_data))


func remove_duplicate_remote_players_for_identity(identity_key: String, keep_remote_id: String) -> void:
	var clean_identity = identity_key.strip_edges().to_lower()
	var clean_keep_id = keep_remote_id.strip_edges()
	if clean_identity == "":
		return

	var ids_to_remove = []
	for candidate_id in remote_players.keys():
		var candidate_player = remote_players[candidate_id]
		if candidate_player == null or not is_instance_valid(candidate_player):
			ids_to_remove.append(str(candidate_id))
			continue

		var candidate_identity = str(candidate_player.get_meta("remote_identity", "")).strip_edges().to_lower()
		if candidate_identity == "":
			candidate_identity = get_remote_player_identity_key(str(candidate_player.get_meta("remote_name", "")))

		if str(candidate_id) != clean_keep_id and candidate_identity == clean_identity:
			ids_to_remove.append(str(candidate_id))

	for stale_id in ids_to_remove:
		remove_remote_player(stale_id)


func clean_remote_player_role(remote_role: String) -> String:
	var clean_role = remote_role.strip_edges().to_lower()
	if clean_role == "admin" or clean_role == "developer":
		return "admin"
	return "player"


func update_remote_player_name(remote_player, remote_name: String):
	if remote_player == null:
		return

	var clean_name = clean_remote_player_name(remote_name)
	remote_player.set_meta("remote_name", clean_name)
	var clean_role = clean_remote_player_role(str(remote_player.get_meta("remote_role", "player")))

	var remote_id = str(remote_player.get_meta("remote_id", ""))
	if remote_id != "":
		create_or_update_remote_name_label(remote_id, clean_name, clean_role)


func create_or_update_remote_name_label(remote_id: String, remote_name: String, remote_role: String = "player"):
	if world == null or world.ui_layer == null:
		return

	var clean_name = clean_remote_player_name(remote_name)
	var clean_role = clean_remote_player_role(remote_role)

	var label = null
	if remote_name_labels.has(remote_id):
		label = remote_name_labels[remote_id]

	if label == null or not is_instance_valid(label):
		label = Label.new()
		label.name = "RemoteUsernameLabel_" + remote_id.substr(0, 8)
		label.size = Vector2(REMOTE_NAME_LABEL_WIDTH, REMOTE_NAME_LABEL_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 70
		label.add_theme_font_size_override("font_size", REMOTE_NAME_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		label.add_theme_constant_override("outline_size", REMOTE_NAME_OUTLINE_SIZE)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		world.ui_layer.add_child(label)
		remote_name_labels[remote_id] = label

	label.text = clean_name
	label.size = Vector2(REMOTE_NAME_LABEL_WIDTH, REMOTE_NAME_LABEL_HEIGHT)
	label.set_meta("remote_role", clean_role)
	var lock_state = _get_remote_player_world_lock_state(clean_name)
	label.set_meta("world_lock_state", lock_state)
	apply_remote_name_label_role_style(label, clean_role, lock_state)
	label.visible = true


func are_remote_name_labels_hidden_by_ui() -> bool:
	if world == null:
		return true

	if not world.in_world:
		return true

	if world.has_method("is_movement_blocking_ui_open") and world.is_movement_blocking_ui_open():
		return true
	if world.has_method("is_crafting_open") and world.is_crafting_open():
		return true
	if world.has_method("is_furnace_open") and world.is_furnace_open():
		return true
	if world.has_method("is_sign_open") and world.is_sign_open():
		return true
	if world.has_method("is_shop_open") and world.is_shop_open():
		return true
	if world.has_method("is_notification_panel_open") and world.is_notification_panel_open():
		return true
	if world.has_method("is_player_menu_open") and world.is_player_menu_open():
		return true
	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return true
	if world.has_method("is_friends_panel_open") and world.is_friends_panel_open():
		return true
	if world.has_method("is_world_menu_open") and world.is_world_menu_open():
		return true
	if world.has_method("is_world_lock_ui_open") and world.is_world_lock_ui_open():
		return true
	if world.has_method("is_trade_open") and world.is_trade_open():
		return true
	if world.has_method("is_vending_open") and world.is_vending_open():
		return true
	if world.has_method("is_safe_open") and world.is_safe_open():
		return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return true
	if world.has_method("is_developer_panel_open") and world.is_developer_panel_open():
		return true

	return false


func update_remote_name_labels():
	if remote_name_labels.size() == 0:
		return

	var hide_labels = are_remote_name_labels_hidden_by_ui()

	for remote_id in remote_name_labels.keys():
		var label = remote_name_labels[remote_id]

		if label == null or not is_instance_valid(label):
			continue

		if hide_labels or not remote_players.has(remote_id):
			label.visible = false
			continue

		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			label.visible = false
			continue

		var clean_name = str(remote_player.get_meta("remote_name", "")).strip_edges()
		if clean_name == "":
			label.visible = false
			continue

		label.text = clean_name
		label.size = Vector2(REMOTE_NAME_LABEL_WIDTH, REMOTE_NAME_LABEL_HEIGHT)

		var remote_role = clean_remote_player_role(str(remote_player.get_meta("remote_role", label.get_meta("remote_role", "player"))))
		var world_lock_state = _get_remote_player_world_lock_state(clean_name)
		label.set_meta("remote_role", remote_role)
		apply_remote_name_label_role_style(label, remote_role, world_lock_state)

		var anchor_pos = get_remote_name_anchor_screen_position(remote_player)
		label.position = Vector2(
			anchor_pos.x - REMOTE_NAME_LABEL_WIDTH / 2.0,
			anchor_pos.y - REMOTE_NAME_LABEL_HEIGHT
		)

		label.visible = true


func get_remote_name_anchor_screen_position(remote_player) -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	var fallback_world_position = remote_player.global_position + Vector2(0.0, -REMOTE_NAME_LABEL_FALLBACK_OFFSET_WORLD_PX)

	var body_sprite = remote_player.get_node_or_null("BodySprite")
	if body_sprite != null and body_sprite is Sprite2D and body_sprite.texture != null:
		var texture_height = float(body_sprite.texture.get_height()) * abs(body_sprite.global_scale.y)
		var top_y = body_sprite.global_position.y
		if body_sprite.centered:
			top_y -= texture_height * 0.5
		top_y -= REMOTE_NAME_LABEL_MARGIN_ABOVE_HEAD_WORLD_PX
		return canvas_transform * Vector2(body_sprite.global_position.x, top_y)

	return canvas_transform * fallback_world_position


func apply_remote_name_label_role_style(label: Label, role: String, world_lock_state: String = "none"):
	if label == null or not is_instance_valid(label):
		return

	if clean_remote_player_role(role) == "admin":
		var hue = fmod((float(Time.get_ticks_msec()) / 1000.0) * 0.22, 1.0)
		label.add_theme_color_override("font_color", Color.from_hsv(hue, 0.88, 1.0))
	elif str(world_lock_state).strip_edges().to_lower() == "owner":
		label.add_theme_color_override("font_color", WORLD_LOCK_OWNER_NAME_COLOR)
	elif str(world_lock_state).strip_edges().to_lower() == "access":
		label.add_theme_color_override("font_color", WORLD_LOCK_ACCESS_NAME_COLOR)
	else:
		label.add_theme_color_override("font_color", WORLD_LOCK_NAME_COLOR_DEFAULT)


func _get_remote_player_world_lock_state(player_name: String) -> String:
	if world == null:
		return "none"

	if not world.in_world:
		return "none"

	var lock_role = "none"
	if world.has_method("get_world_lock_access_role_for_player"):
		lock_role = str(world.get_world_lock_access_role_for_player(player_name)).strip_edges().to_lower()

	if lock_role == "owner":
		return "owner"

	if lock_role == "admin" or lock_role == "builder" or lock_role == "visitor":
		return "access"

	return "none"



# --- Remote Chat Bubbles: shared UI bubble component and safe queue ---
func show_remote_chat_bubble(remote_id: String, message: String, remote_name: String = ""):
	if world == null or world.ui_layer == null:
		return

	var trimmed_remote_id = resolve_remote_chat_player_id(str(remote_id), str(remote_name))
	var clean_message = str(message).strip_edges()
	if trimmed_remote_id == "" or clean_message == "":
		return

	if not remote_players.has(trimmed_remote_id):
		_queue_remote_chat_message(trimmed_remote_id, clean_message)
		return

	var remote_player = remote_players[trimmed_remote_id]
	if remote_player == null or not is_instance_valid(remote_player):
		_queue_remote_chat_message(trimmed_remote_id, clean_message)
		return

	_display_remote_chat_bubble(remote_player, trimmed_remote_id, clean_message)


func resolve_remote_chat_player_id(remote_id: String, remote_name: String = "") -> String:
	var clean_id = str(remote_id).strip_edges()
	if clean_id != "" and remote_players.has(clean_id):
		return clean_id

	var clean_name = str(remote_name).strip_edges().to_lower()
	if clean_name != "":
		for candidate_id in remote_players.keys():
			var remote_player = remote_players[candidate_id]
			if remote_player == null or not is_instance_valid(remote_player):
				continue
			var candidate_name = str(remote_player.get_meta("remote_name", "")).strip_edges().to_lower()
			if candidate_name == clean_name:
				return str(candidate_id)

	return clean_id


func _queue_remote_chat_message(remote_id: String, clean_message: String) -> void:
	if remote_id == "" or clean_message == "":
		return

	var queue = remote_chat_pending_messages.get(remote_id, [])
	if not (queue is Array):
		queue = []

	if queue.size() >= 6:
		queue = queue.slice(queue.size() - 5, queue.size())

	queue.append(clean_message)
	remote_chat_pending_messages[remote_id] = queue


func _drain_remote_chat_message_queue(remote_id: String):
	if remote_id == "":
		return

	if not remote_chat_pending_messages.has(remote_id):
		return

	if not remote_players.has(remote_id):
		return

	var remote_player = remote_players[remote_id]
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var queue = remote_chat_pending_messages.get(remote_id, [])
	remote_chat_pending_messages.erase(remote_id)
	if not (queue is Array):
		return

	for message in queue:
		if message is String:
			_display_remote_chat_bubble(remote_player, remote_id, str(message).strip_edges())


func _display_remote_chat_bubble(remote_player, remote_id: String, clean_message: String):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if world == null or world.ui_layer == null:
		return
	if world.has_method("is_chat_open") and world.is_chat_open():
		return

	var msg = str(clean_message).strip_edges()
	if msg == "":
		return

	var bubble = null
	if remote_chat_bubbles.has(remote_id):
		bubble = remote_chat_bubbles[remote_id]

	if bubble == null or not is_instance_valid(bubble):
		bubble = _create_remote_chat_bubble_node(remote_id)
		if bubble == null:
			return
		remote_chat_bubbles[remote_id] = bubble

	if not bubble.has_method("show_chat_message"):
		return

	bubble.show_chat_message(msg)
	_position_remote_chat_bubble(remote_id)


func _create_remote_chat_bubble_node(remote_id: String):
	if world == null or world.ui_layer == null:
		return null

	var bubble_name = "RemoteChatBubbleUI_" + remote_id.substr(0, 8)
	var legacy_name = "RemoteChatBubble_" + remote_id.substr(0, 8)

	for child in world.ui_layer.get_children():
		if child != null and (str(child.name) == bubble_name or str(child.name) == legacy_name):
			child.queue_free()

	var remote_player = remote_players.get(remote_id, null)
	if remote_player != null and is_instance_valid(remote_player):
		var old_world_bubble = remote_player.get_node_or_null("ChatBubble")
		if old_world_bubble != null:
			old_world_bubble.queue_free()

	var bubble = CHAT_BUBBLE_COMPONENT.new()
	bubble.name = bubble_name
	bubble.visible = false
	world.ui_layer.add_child(bubble)
	return bubble


func update_remote_chat_bubbles(_delta: float):
	if remote_chat_bubbles.size() == 0:
		return

	if world != null and world.has_method("is_chat_open") and world.is_chat_open():
		for bubble_node in remote_chat_bubbles.values():
			if bubble_node != null and is_instance_valid(bubble_node):
				if bubble_node.has_method("hide_chat_bubble"):
					bubble_node.hide_chat_bubble()
				else:
					bubble_node.visible = false
		return

	var ids_to_cleanup = []

	for remote_id in remote_chat_bubbles.keys():
		var bubble = remote_chat_bubbles[remote_id]
		if bubble == null or not is_instance_valid(bubble):
			ids_to_cleanup.append(remote_id)
			continue

		if not remote_players.has(remote_id):
			bubble.visible = false
			continue

		if not bubble.visible:
			continue

		_position_remote_chat_bubble(remote_id)

	for remote_id in ids_to_cleanup:
		remote_chat_bubbles.erase(remote_id)


func _position_remote_chat_bubble(remote_id: String):
	if world == null:
		return
	if remote_id == "" or not remote_players.has(remote_id) or not remote_chat_bubbles.has(remote_id):
		return

	var remote_player = remote_players[remote_id]
	var bubble = remote_chat_bubbles[remote_id]

	if remote_player == null or bubble == null:
		return
	if not is_instance_valid(remote_player) or not is_instance_valid(bubble):
		return

	var anchor_screen_pos = _get_remote_chat_anchor_screen_position(remote_player)
	if bubble.size.x <= 0.0 or bubble.size.y <= 0.0:
		return

	var bubble_position = Vector2(
		round(anchor_screen_pos.x - bubble.size.x / 2.0),
		round(anchor_screen_pos.y - bubble.size.y)
	)
	bubble.position = CHAT_BUBBLE_COMPONENT.clamp_screen_position(
		bubble_position,
		bubble.size,
		bubble.get_viewport()
	)


func _get_remote_chat_anchor_world_position(remote_player) -> Vector2:
	if remote_player == null:
		return Vector2.ZERO

	var anchor = remote_player.get_node_or_null("ChatBubbleAnchor")
	if anchor is Node2D:
		return anchor.global_position

	return remote_player.global_position + Vector2(0.0, -CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px())


func _get_remote_chat_anchor_screen_position(remote_player) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO

	var anchor_world_position = _get_remote_chat_anchor_world_position(remote_player)
	return CHAT_BUBBLE_COMPONENT.world_to_screen_position(viewport, anchor_world_position)

func update_remote_player_facing(remote_player):
	if remote_player == null:
		return

	var facing = int(remote_player.get_meta("facing", 1))
	var body_sprite = remote_player.get_node_or_null("BodySprite")
	if body_sprite != null and body_sprite is Sprite2D:
		body_sprite.flip_h = facing < 0

	var back_sprite = remote_player.get_node_or_null("BackSprite")
	if back_sprite != null and back_sprite is Sprite2D:
		back_sprite.flip_h = facing < 0

	var fallback = remote_player.get_node_or_null("FallbackBody")
	if fallback != null:
		fallback.scale.x = 1 if facing >= 0 else -1

func update_remote_back_item_visual(remote_player):
	update_remote_equipment_visuals(remote_player)


func update_remote_equipment_visuals(remote_player):
	if remote_player == null:
		return

	var equipment_slots = remote_player.get_meta("equipment_slots", {})
	if not (equipment_slots is Dictionary):
		equipment_slots = {}

	var equipment_root = remote_player.get_node_or_null("EquipmentSlots")
	if equipment_root == null:
		equipment_root = Node2D.new()
		equipment_root.name = "EquipmentSlots"
		equipment_root.z_as_relative = false
		equipment_root.z_index = REMOTE_PLAYER_Z_INDEX + 2
		remote_player.add_child(equipment_root)

	var known_slots = [
		"back", "hand", "hair", "head", "hat", "eyes", "face",
		"shirt", "pants", "legs", "feet", "shoes",
		"neck", "aura"
	]

	for slot_name in known_slots:
		var item_id = str(equipment_slots.get(slot_name, ""))
		update_remote_equipment_slot(remote_player, equipment_root, slot_name, item_id)


func update_remote_equipment_slot(remote_player, equipment_root, slot_name: String, item_id: String):
	if equipment_root == null:
		return

	var sprite_name = "Slot_" + slot_name.capitalize()
	var slot_sprite = equipment_root.get_node_or_null(sprite_name)

	if item_id == "":
		if slot_sprite != null:
			slot_sprite.visible = false
		return

	var item_data = get_remote_item_data(item_id)
	var texture = get_remote_item_texture(item_id, slot_name, item_data)

	if texture == null:
		if slot_sprite != null:
			slot_sprite.visible = false
		return

	if slot_sprite == null:
		slot_sprite = Sprite2D.new()
		slot_sprite.name = sprite_name
		slot_sprite.centered = true
		slot_sprite.z_as_relative = false
		equipment_root.add_child(slot_sprite)

	slot_sprite.texture = texture
	slot_sprite.visible = true
	apply_remote_equipment_slot_transform(remote_player, slot_sprite, slot_name, item_data, texture)


func get_remote_item_data(item_id: String) -> Dictionary:
	if world != null and world.item_database.has(item_id):
		var data = world.item_database[item_id]
		if data is Dictionary:
			return data

	return {}


func get_remote_item_texture(item_id: String, slot_name: String, item_data: Dictionary):
	if world != null:
		if slot_name == "hand" and world.tool_textures.has(item_id):
			return world.tool_textures[item_id]

		if slot_name == "back" and world.back_textures.has(item_id):
			return world.back_textures[item_id]

		if slot_name == "hair" and world.hair_textures.has(item_id):
			return world.hair_textures[item_id]

		if slot_name == "shirt" and world.shirt_textures.has(item_id):
			return world.shirt_textures[item_id]

		if slot_name == "pants" and world.pants_textures.has(item_id):
			return world.pants_textures[item_id]

		if slot_name == "shoes" and world.shoes_textures.has(item_id):
			return world.shoes_textures[item_id]

		if world.tool_textures.has(item_id):
			return world.tool_textures[item_id]

		if world.back_textures.has(item_id):
			return world.back_textures[item_id]

		if world.hair_textures.has(item_id):
			return world.hair_textures[item_id]

		if world.shirt_textures.has(item_id):
			return world.shirt_textures[item_id]

		if world.pants_textures.has(item_id):
			return world.pants_textures[item_id]

		if world.shoes_textures.has(item_id):
			return world.shoes_textures[item_id]

		if world.material_textures.has(item_id):
			return world.material_textures[item_id]

		if world.block_textures.has(item_id):
			return world.block_textures[item_id]

	var texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))
	if texture != null:
		return texture

	var sprite_folder = str(item_data.get("sprite_folder", ""))
	if sprite_folder != "" and not sprite_folder.ends_with("/"):
		sprite_folder += "/"

	var idle_sprite = str(item_data.get("idle_sprite", ""))
	if sprite_folder != "" and idle_sprite != "":
		var idle_path = sprite_folder + idle_sprite
		if ResourceLoader.exists(idle_path):
			return load(idle_path)

	return null


func apply_remote_equipment_slot_transform(remote_player, slot_sprite: Sprite2D, slot_name: String, item_data: Dictionary, texture):
	if remote_player == null or slot_sprite == null:
		return

	var facing = int(remote_player.get_meta("facing", 1))
	var facing_left = facing < 0

	slot_sprite.flip_h = facing_left
	slot_sprite.rotation_degrees = 0.0
	slot_sprite.offset = Vector2.ZERO

	match slot_name:
		"hand":
			apply_remote_hand_item_transform(slot_sprite, item_data, texture, facing_left)
		"back":
			apply_remote_back_item_transform(slot_sprite, item_data, texture, facing_left)
		_:
			apply_remote_generic_slot_transform(slot_sprite, slot_name, item_data, facing_left)


func apply_remote_hand_item_transform(slot_sprite: Sprite2D, _item_data: Dictionary, _texture, facing_left: bool):
	var scene_transform = get_remote_hand_scene_transform(facing_left)
	slot_sprite.position = scene_transform.get("position", Vector2.ZERO)
	slot_sprite.rotation_degrees = float(scene_transform.get("rotation_degrees", 0.0))
	slot_sprite.scale = scene_transform.get("scale", Vector2.ONE)
	slot_sprite.z_index = REMOTE_PLAYER_Z_INDEX + 20


func get_local_player_scene_position(node_path: String, fallback: Vector2) -> Vector2:
	if world == null or world.player == null:
		return fallback

	var node = world.player.get_node_or_null(node_path)
	if node == null or not (node is Node2D):
		return fallback

	var position = Vector2.ZERO
	var current = node
	while current != null and current != world.player:
		if current is Node2D:
			position += current.position
		current = current.get_parent()

	return position


func get_local_player_faced_scene_position(node_path: String, fallback: Vector2, facing_left: bool) -> Vector2:
	var position = get_local_player_scene_position(node_path, fallback)
	if not facing_left:
		return position

	var visual_position = get_local_player_scene_position("PlayerVisual", Vector2.ZERO)
	return Vector2(visual_position.x - (position.x - visual_position.x), position.y)


func get_local_player_scene_scale(node_path: String, fallback: Vector2 = Vector2.ONE) -> Vector2:
	if world == null or world.player == null:
		return fallback

	var node = world.player.get_node_or_null(node_path)
	if node == null or not (node is Node2D):
		return fallback

	var scale_value = node.scale
	if scale_value == Vector2.ZERO:
		return fallback

	return scale_value


func get_local_player_scene_rotation(node_path: String, fallback: float = 0.0) -> float:
	if world == null or world.player == null:
		return fallback

	var node = world.player.get_node_or_null(node_path)
	if node == null or not (node is Node2D):
		return fallback

	return float(node.rotation_degrees)


func get_remote_hand_scene_transform(facing_left: bool) -> Dictionary:
	return {
		"position": get_local_player_faced_scene_position("PlayerVisual/HandItem/HandItemAnimated", Vector2(0, -8), facing_left),
		"rotation_degrees": get_local_player_scene_rotation("PlayerVisual/HandItem/HandItemAnimated", 0.0),
		"scale": get_local_player_scene_scale("PlayerVisual/HandItem/HandItemAnimated", Vector2.ONE)
	}


func apply_remote_back_item_transform(slot_sprite: Sprite2D, item_data: Dictionary, texture, facing_left: bool):
	var sprite_facing_left = facing_left and bool(item_data.get("back_flip_with_facing", true))
	slot_sprite.flip_h = sprite_facing_left

	slot_sprite.position = get_local_player_faced_scene_position("PlayerVisual/BackSlot/BackItemAnimated", Vector2(0, -12), facing_left)
	slot_sprite.scale = get_local_player_scene_scale("PlayerVisual/BackSlot/BackItemAnimated", Vector2.ONE)
	slot_sprite.z_index = int(item_data.get("back_z_index", REMOTE_PLAYER_Z_INDEX - 20))


func get_remote_back_socket_position(facing_left: bool, item_data: Dictionary) -> Vector2:
	# Match the local BackSocket editor placement without using live/flipped local movement.
	# This fixes remote wings/back items being slightly shifted compared to the owner client.
	if world == null or world.player == null:
		return Vector2(0, -12)

	var right_marker = world.player.get_node_or_null("BackSocketRight")
	var left_marker = world.player.get_node_or_null("BackSocketLeft")

	if facing_left and left_marker != null:
		return left_marker.position

	if not facing_left and right_marker != null:
		return right_marker.position

	var socket = world.player.get_node_or_null("PlayerVisual/BackSlot")
	if socket != null:
		var p = get_local_player_scene_position("PlayerVisual/BackSlot", socket.position)
		if bool(item_data.get("mirror_back_socket", false)):
			return Vector2(abs(p.x), p.y) if facing_left else Vector2(-abs(p.x), p.y)
		return p

	return Vector2(0, -12)


func get_remote_back_item_offset(item_data: Dictionary, facing_left: bool) -> Vector2:
	var offset = get_remote_vector_from_data(item_data.get("back_offset", [0, 0]), Vector2.ZERO)

	if facing_left:
		return get_remote_vector_from_data(item_data.get("back_offset_left", [offset.x, offset.y]), offset)

	return offset


func apply_remote_generic_slot_transform(slot_sprite: Sprite2D, slot_name: String, item_data: Dictionary, facing_left: bool):
	var default_offsets = {
		"hair": Vector2(0, -28),
		"head": Vector2(0, -30),
		"hat": Vector2(0, -38),
		"eyes": Vector2(0, -23),
		"face": Vector2(0, -18),
		"shirt": Vector2(0, -5),
		"pants": Vector2(0, 8),
		"legs": Vector2(0, 8),
		"feet": Vector2(0, 8),
		"shoes": Vector2(0, 8),
		"neck": Vector2(0, -12),
		"aura": Vector2(0, -8)
	}

	var fallback = default_offsets.get(slot_name, Vector2.ZERO)
	var offset = get_remote_vector_from_data(item_data.get("slot_offset", [fallback.x, fallback.y]), fallback)
	var offset_left = get_remote_vector_from_data(item_data.get("slot_offset_left", [offset.x, offset.y]), offset)

	var base_position = Vector2.ZERO
	if slot_name == "shirt":
		base_position = get_remote_front_socket_position(facing_left)
		slot_sprite.rotation_degrees = float(item_data.get("front_rotation", 0.0))
	elif slot_name == "pants":
		base_position = get_remote_pant_slot_position(facing_left)
	elif slot_name == "hair":
		base_position = get_remote_hair_slot_position(facing_left)

	slot_sprite.position = base_position + (offset_left if facing_left else offset)
	var scale_value = float(item_data.get("front_scale", item_data.get("slot_scale", 1.0))) if slot_name == "shirt" else float(item_data.get("slot_scale", 1.0))
	slot_sprite.scale = Vector2(scale_value, scale_value)
	slot_sprite.z_index = int(item_data.get("front_z_index", item_data.get("slot_z_index", REMOTE_PLAYER_Z_INDEX + 10))) if slot_name == "shirt" else int(item_data.get("slot_z_index", REMOTE_PLAYER_Z_INDEX + 10))


func get_remote_pant_slot_position(_facing_left: bool) -> Vector2:
	if world == null or world.player == null:
		return Vector2.ZERO

	var animated = world.player.get_node_or_null("PlayerVisual/Bottom")
	if animated != null:
		return get_local_player_scene_position("PlayerVisual/Bottom", animated.position)

	return Vector2.ZERO


func get_remote_hair_slot_position(facing_left: bool) -> Vector2:
	if world == null or world.player == null:
		return Vector2(0, -28)

	var animated = world.player.get_node_or_null("PlayerVisual/Head")
	if animated != null:
		return get_local_player_scene_position("PlayerVisual/Head", animated.position)

	return Vector2(0, -28)


func get_remote_front_socket_position(facing_left: bool) -> Vector2:
	if world == null or world.player == null:
		return Vector2(0, -8)

	var animated = world.player.get_node_or_null("PlayerVisual/Body")
	if animated != null:
		return get_local_player_scene_position("PlayerVisual/Body", animated.position)

	return Vector2(0, -8)


func get_remote_vector_from_data(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	return fallback


func remove_remote_player(remote_id: String):
	if remote_id == "":
		return

	if not remote_players.has(remote_id):
		return

	var remote_player = remote_players[remote_id]
	remote_players.erase(remote_id)

	if remote_player != null and is_instance_valid(remote_player):
		remote_player.queue_free()

	if remote_name_labels.has(remote_id):
		var label = remote_name_labels[remote_id]
		remote_name_labels.erase(remote_id)
		if label != null and is_instance_valid(label):
			label.queue_free()

	if remote_chat_bubbles.has(remote_id):
		var bubble = remote_chat_bubbles[remote_id]
		remote_chat_bubbles.erase(remote_id)
		remote_chat_pending_messages.erase(remote_id)
		if bubble != null and is_instance_valid(bubble):
			bubble.queue_free()

func clear_remote_players():
	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player != null and is_instance_valid(remote_player):
			remote_player.queue_free()

	remote_players.clear()

	for remote_id in remote_name_labels.keys():
		var label = remote_name_labels[remote_id]
		if label != null and is_instance_valid(label):
			label.queue_free()

	remote_name_labels.clear()

	for remote_id in remote_chat_bubbles.keys():
		var bubble = remote_chat_bubbles[remote_id]
		if bubble != null and is_instance_valid(bubble):
			bubble.queue_free()

	remote_chat_bubbles.clear()
	remote_chat_pending_messages.clear()
