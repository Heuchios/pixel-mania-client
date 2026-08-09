extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const EquipmentManagerScript = preload("res://Scripts/equipment_manager.gd")
const PlayerAnimationManagerScript = preload("res://Scripts/player_animation_manager.gd")
const PlayerShadowScript = preload("res://Scripts/player_shadow.gd")
const PlayerWorldFadeFXScene = preload("res://Scenes/particles/PlayerWorldFadeFX.tscn")
const MovementModeScript = preload("res://Scripts/networking/movement_mode.gd")

var world = null
var MovementMode: Node = null

const DEBUG_ACTION_POSITION_FLOW := false
const DEBUG_REMOTE_APPEARANCE_FLOW := false
const MOVEMENT_SYNC_DEBUG_ARG := "--movement-sync-debug"
const HURT_FACE_EXPRESSION_TIME_MSEC := 550
const PUNCH_FACE_EXPRESSION_TIME_MSEC := 300
const PLACE_ANIMATION_TIME_MSEC := 300
const REMOTE_ANT_SWORD_SLASH_DEDUPE_MSEC := 140
const DEAD_FACE_EXPRESSION_TIME := 1.0
const DEAD_SPIRIT_FACE_EXPRESSION_TIME := 3.0
const PLAYER_WORLD_FADE_FX_NODE_NAME := "PlayerWorldFadeFX"

var respawn_sequence_running := false
var respawn_sequence_id := 0
var movement_sync_debug_enabled := false


func _resolve_movement_mode_singleton() -> void:
	if is_instance_valid(MovementMode):
		return

	var root_node: Node = null
	if world != null and is_instance_valid(world):
		var world_tree = world.get_tree()
		if world_tree != null:
			root_node = world_tree.root
	elif get_tree() != null:
		root_node = get_tree().root

	if root_node != null:
		var movement_mode_singleton = root_node.get_node_or_null("MovementMode")
		if is_instance_valid(movement_mode_singleton):
			MovementMode = movement_mode_singleton
			return

	var fallback_mode = MovementModeScript.new()
	if fallback_mode == null:
		return
	MovementMode = fallback_mode
	if MovementMode.has_method("_ready"):
		MovementMode.call("_ready")


func debug_action_position_flow(message: String) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][PlayerManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text)


func debug_remote_appearance_flow(message: String, data: Dictionary = {}) -> void:
	if not DEBUG_REMOTE_APPEARANCE_FLOW:
		return
	print("[APPEARANCE][Client] " + message + " " + str(data))


func setup(world_ref):
	world = world_ref
	_resolve_movement_mode_singleton()
	movement_sync_debug_enabled = MovementMode.has_method("has_launch_arg") and bool(MovementMode.has_launch_arg(MOVEMENT_SYNC_DEBUG_ARG))
	remote_position_snapshot_generation += 1
	remote_pending_position_snapshots.clear()
	if MovementMode.is_netfox_real():
		clear_remote_players()
		clear_legacy_websocket_remote_visual_nodes()


func update_back_item_jump_reset():
	if not MovementMode.is_websocket():
		return

	if world.player == null:
		return

	if world.player is CharacterBody2D:
		if world.player.is_on_floor():
			world.back_item_air_jumps_used = 0

func try_back_item_air_jump(event: InputEvent) -> bool:
	if not MovementMode.is_websocket():
		return false

	if world.player == null:
		return false

	if not (world.player is CharacterBody2D):
		return false

	# Your normal world.player script handles the ground jump.
	# This function only adds extra air jumps from back items.
	if not is_jump_press_event(event):
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

func is_jump_press_event(event: InputEvent) -> bool:
	if event == null:
		return false

	return event.is_action_pressed("jump")

func perform_back_item_air_jump():
	if not MovementMode.is_websocket():
		return

	if world.player == null:
		return

	if not (world.player is CharacterBody2D):
		return

	var jump_velocity := float(world.BACK_ITEM_JUMP_VELOCITY)
	if world.has_method("is_anti_gravity_enabled") and bool(world.is_anti_gravity_enabled()):
		jump_velocity *= 1.15
	world.player.velocity.y = jump_velocity
	var should_play_water_jump := false
	if world.player.has_method("is_in_water_for_jump_sound"):
		should_play_water_jump = bool(world.player.is_in_water_for_jump_sound())
	if should_play_water_jump and world.has_method("play_sound_water_jump"):
		world.play_sound_water_jump(world.player.global_position)
	elif world.has_method("play_sound_jump"):
		world.play_sound_jump(world.player.global_position)

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
	if not MovementMode.is_websocket():
		return

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

		# Keep momentum intact while input is locked so slippery surfaces
		# (like ice) continue using existing slide/friction behavior.

	if not should_lock and world.chat_typing_movement_locked:
		world.chat_typing_movement_locked = false

func toggle_noclip():
	if not MovementMode.is_websocket():
		return

	world.set_noclip_enabled(not world.noclip_enabled)

func set_noclip_enabled(enabled: bool):
	if not MovementMode.is_websocket():
		return

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
	if not MovementMode.is_websocket():
		return

	if not world.noclip_enabled:
		return

	if world.player == null:
		return

	if world.has_method("is_movement_locked") and world.is_movement_locked():
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
		return

	var direction = Vector2(Input.get_axis("move_left", "move_right"), 0.0)

	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1

	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1

	if Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	direction.x = clamp(direction.x, -1.0, 1.0)

	if direction.length() > 0:
		direction = direction.normalized()
		world.player.global_position += direction * world.NOCLIP_SPEED * delta

	# Keep the world.player frozen when no keys are pressed.
	# This prevents slow gravity drift while noclip is active.
	if world.player is CharacterBody2D:
		world.player.velocity = Vector2.ZERO

func update_player_facing_direction():
	if not MovementMode.is_websocket():
		return

	if world.has_method("is_movement_locked") and world.is_movement_locked():
		return

	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		set_player_facing_direction(-1)
		return

	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		set_player_facing_direction(1)
		return

	if world.player != null:
		if world.player.velocity.x < -1:
			set_player_facing_direction(-1)
		elif world.player.velocity.x > 1:
			set_player_facing_direction(1)


func set_player_facing_direction(facing_direction: int, sync_now: bool = false) -> bool:
	if world == null:
		return false

	var safe_facing: int = -1 if facing_direction < 0 else 1
	var changed: bool = int(world.player_facing_direction) != safe_facing
	world.player_facing_direction = safe_facing

	if changed:
		apply_player_facing_direction()

	if sync_now and (changed or last_sent_network_facing != safe_facing):
		flush_multiplayer_position(false, true)

	return changed


func face_grid_position(grid_pos: Vector2i, sync_now: bool = false) -> bool:
	if world == null or world.player == null:
		return false

	var player_grid_pos = world.get_player_grid_position()
	if grid_pos.x == player_grid_pos.x:
		return false

	var target_facing: int = -1 if grid_pos.x < player_grid_pos.x else 1
	return set_player_facing_direction(target_facing, sync_now)


func apply_player_facing_direction():
	if world == null:
		return

	var safe_facing: int = -1 if int(world.player_facing_direction) < 0 else 1

	if world.player_animation_manager != null and world.player_animation_manager.has_method("update_facing"):
		world.player_animation_manager.update_facing(safe_facing)

	if world.has_method("update_equipment_visual"):
		world.update_equipment_visual()

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
	if not MovementMode.is_websocket():
		return

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
	if not MovementMode.is_websocket():
		return

	if world.player == null:
		return

	world.lava_damage_timer -= delta

	var player_grid_pos = world.get_player_grid_position()
	var block_below_player = Vector2i(player_grid_pos.x, player_grid_pos.y + 1)

	if world.is_lava_block(player_grid_pos) or world.is_lava_block(block_below_player):
		if world.lava_damage_timer <= 0:
			world.damage_player(1)
			world.lava_damage_timer = world.LAVA_DAMAGE_DELAY


func update_checkpoint_contact() -> bool:
	if not MovementMode.is_websocket():
		return false
	if world == null or world.player == null or not world.in_world:
		return false

	var checkpoint_grid := get_checkpoint_contact_grid()
	if checkpoint_grid == world.INVALID_GRID_POS:
		return false

	if world.has_method("activate_checkpoint"):
		return bool(world.activate_checkpoint(checkpoint_grid))
	return false


func get_checkpoint_contact_grid() -> Vector2i:
	if world == null or world.player == null:
		return Vector2i.ZERO

	var player_grid: Vector2i = world.get_player_grid_position()
	var player_position: Vector2 = world.player.global_position
	var max_horizontal := float(world.BLOCK_SIZE) * 0.75
	var max_vertical := float(world.BLOCK_SIZE) * 1.45

	for y_offset in range(-1, 3):
		for x_offset in range(-1, 2):
			var grid_pos := Vector2i(player_grid.x + x_offset, player_grid.y + y_offset)
			if not is_checkpoint_contact_candidate(grid_pos):
				continue
			var checkpoint_position := Vector2(
				float(grid_pos.x * world.BLOCK_SIZE),
				float(grid_pos.y * world.BLOCK_SIZE)
			)
			if abs(player_position.x - checkpoint_position.x) <= max_horizontal and abs(player_position.y - checkpoint_position.y) <= max_vertical:
				return grid_pos

	return world.INVALID_GRID_POS


func is_checkpoint_contact_candidate(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.is_grid_inside_world(grid_pos):
		return false
	if not world.blocks.has(grid_pos):
		return false

	var block_data = world.blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return false

	if world.has_method("is_checkpoint_block_type"):
		return bool(world.is_checkpoint_block_type(str(block_data.get("type", ""))))
	return false


func damage_player(amount: int):
	if not MovementMode.is_websocket():
		return

	if respawn_sequence_running or world.player_health <= 0:
		return

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
		flush_multiplayer_position(false, true)

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
	flush_multiplayer_position(false, true)


func play_player_punch_animation():
	if not MovementMode.is_websocket():
		return

	if world == null or world.player == null:
		return

	# Visual-only punch state rides the normal movement sync; avoid a forced packet flush here.
	var punch_animation_name = get_current_player_punch_animation_name()
	world.player.set_meta("punch_animation_name", punch_animation_name)
	world.player.set_meta("face_punch_until_msec", Time.get_ticks_msec() + PUNCH_FACE_EXPRESSION_TIME_MSEC)

	var animation_player = world.player.get_node_or_null("AnimationPlayer")
	if play_animation_on_player(animation_player, punch_animation_name):
		return
	if punch_animation_name != "punch" and play_animation_on_player(animation_player, "punch"):
		return

	if animation_player != null:
		var child_player = animation_player.get_node_or_null("punch")
		if child_player == null:
			child_player = animation_player.get_node_or_null("Punch")
		if play_animation_on_player(child_player, punch_animation_name):
			return
		if punch_animation_name != "punch" and play_animation_on_player(child_player, "punch"):
			return

	var direct_player = world.player.get_node_or_null("punch")
	if direct_player == null:
		direct_player = world.player.get_node_or_null("Punch")
	if play_animation_on_player(direct_player, punch_animation_name):
		return
	if punch_animation_name != "punch":
		play_animation_on_player(direct_player, "punch")


func play_player_place_animation() -> void:
	if world == null or world.player == null:
		return

	world.player.set_meta("place_animation_until_msec", Time.get_ticks_msec() + PLACE_ANIMATION_TIME_MSEC)
	var animation_player = world.player.get_node_or_null("AnimationPlayer")
	play_animation_on_player(animation_player, "place_animation")


func get_current_player_punch_animation_name() -> String:
	if world == null:
		return "punch"

	var equipped_tool = str(world.get("equipped_tool")).strip_edges()
	return get_punch_animation_name_for_item(equipped_tool)


func get_punch_animation_name_for_item(item_id: String) -> String:
	var clean_item_id = item_id.strip_edges()
	if clean_item_id == "":
		return "punch"

	if world == null:
		return "punch"

	var item_database = world.get("item_database")
	if not (item_database is Dictionary) or not item_database.has(clean_item_id):
		return "punch"

	var item_data = item_database[clean_item_id]
	if not (item_data is Dictionary):
		return "punch"

	var animation_name = str(item_data.get("punch_animation", "")).strip_edges()
	if animation_name == "":
		return "punch"

	return animation_name


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
	if not MovementMode.is_websocket():
		return

	if world != null and bool(world.get_meta("world_entry_in_progress", false)):
		place_player_at_entrance_immediate()
		return

	if respawn_sequence_running:
		return

	respawn_sequence_running = true
	respawn_sequence_id += 1
	var sequence_id = respawn_sequence_id

	if world.player != null:
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
			world.player.set_physics_process(false)
		apply_respawn_animation_state("dead")

	get_tree().create_timer(DEAD_FACE_EXPRESSION_TIME).timeout.connect(Callable(self, "_show_dead_spirit_before_respawn").bind(sequence_id))


func _show_dead_spirit_before_respawn(sequence_id: int):
	if not MovementMode.is_websocket():
		return

	if sequence_id != respawn_sequence_id:
		return

	if world.player != null:
		apply_respawn_animation_state("dead_spirit")

	get_tree().create_timer(DEAD_SPIRIT_FACE_EXPRESSION_TIME).timeout.connect(Callable(self, "_complete_respawn_sequence").bind(sequence_id))


func _complete_respawn_sequence(sequence_id: int):
	if not MovementMode.is_websocket():
		return

	if sequence_id != respawn_sequence_id:
		return

	complete_respawn_player()
	respawn_sequence_running = false


func complete_respawn_player():
	if not MovementMode.is_websocket():
		return

	world.player_health = 10
	world.lava_damage_timer = 0.0

	if world.player != null:
		world.player.set_meta("face_expression_override", "")
		world.player.set_meta("face_hurt_until_msec", 0)
		refresh_local_respawn_animation_visuals("")
		var spawn_pos = get_current_respawn_spawn_position()
		if not is_finite(spawn_pos.x) or not is_finite(spawn_pos.y):
			return
		debug_action_position_flow("respawn_player setting position to " + str(spawn_pos))
		world.player.global_position = spawn_pos
		world.player.velocity = Vector2.ZERO
		if world.player.has_method("reset_instant_hazard_after_respawn"):
			world.player.reset_instant_hazard_after_respawn()
		world.player.set_physics_process(true)
		var camera = world.get_player_camera()
		if camera != null and camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		flush_respawn_position_to_server()

	world.update_all_ui()


func place_player_at_entrance_immediate():
	if not MovementMode.is_websocket():
		return

	respawn_sequence_running = false
	respawn_sequence_id += 1
	world.player_health = 10
	world.lava_damage_timer = 0.0

	if world.player != null:
		world.player.set_meta("face_expression_override", "")
		world.player.set_meta("face_hurt_until_msec", 0)
		refresh_local_respawn_animation_visuals("")
		var spawn_pos = get_current_entrance_gate_spawn_position()
		if not is_finite(spawn_pos.x) or not is_finite(spawn_pos.y):
			return
		debug_action_position_flow("place_player_at_entrance_immediate setting position to " + str(spawn_pos))
		world.player.global_position = spawn_pos
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO
			if world.player.has_method("reset_instant_hazard_after_respawn"):
				world.player.reset_instant_hazard_after_respawn()
			world.player.set_physics_process(true)
		var camera = world.get_player_camera()
		if camera != null and camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		flush_respawn_position_to_server()

	world.update_all_ui()


func apply_respawn_animation_state(animation_state: String) -> void:
	if world == null or world.player == null:
		return

	var clean_state := animation_state.strip_edges().to_lower()
	if clean_state != "dead" and clean_state != "dead_spirit":
		return

	world.player.set_meta("face_expression_override", clean_state)
	refresh_local_respawn_animation_visuals(clean_state)
	sync_respawn_animation_state_to_server(clean_state)


func refresh_local_respawn_animation_visuals(animation_state: String) -> void:
	if world == null:
		return

	var clean_state := animation_state.strip_edges().to_lower()
	if clean_state != "dead" and clean_state != "dead_spirit":
		clean_state = ""

	if world.player_animation_manager != null and world.player_animation_manager.has_method("update_player_animation"):
		var facing: int = -1 if int(world.player_facing_direction) < 0 else 1
		world.player_animation_manager.update_player_animation(0.0, facing)

	if world.equipment_manager != null:
		if world.equipment_manager.has_method("set_forced_animation_state"):
			world.equipment_manager.set_forced_animation_state(clean_state)
		if world.equipment_manager.has_method("update_wearable_animation_state"):
			world.equipment_manager.update_wearable_animation_state(0.0)
		if world.equipment_manager.has_method("update_back_item_animation"):
			world.equipment_manager.update_back_item_animation(0.0)


func sync_respawn_animation_state_to_server(animation_state: String) -> bool:
	if not MovementMode.is_websocket():
		return false
	if world == null or world.player == null or not world.in_world:
		return false

	var clean_state := animation_state.strip_edges().to_lower()
	if clean_state != "dead" and clean_state != "dead_spirit":
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_position"):
		return false

	var current_position = world.player.global_position
	var current_facing: int = -1 if int(world.player_facing_direction) < 0 else 1
	var current_lava_fire_state := false
	if network.has_method("get_player_motion_state"):
		current_lava_fire_state = bool(network.get_player_motion_state().get("in_lava_fire", false))
	var sent := bool(network.send_player_position(current_position, current_facing, world.current_world_name, false, true, clean_state))
	if sent:
		network_position_timer = get_network_position_send_interval()
		network_heartbeat_timer = get_network_position_heartbeat_interval()
		last_sent_network_position = current_position
		last_sent_network_facing = current_facing
		last_sent_network_animation_state = clean_state
		last_sent_network_lava_fire_state = current_lava_fire_state
		last_sent_network_fishing_key = get_local_fishing_sync_key()
		last_sent_network_damage_key = get_local_damage_flash_sync_key()
	return sent


func get_current_entrance_gate_spawn_position() -> Vector2:
	if world != null and world.has_method("get_entrance_gate_spawn_position"):
		var spawn = world.get_entrance_gate_spawn_position()
		if spawn is Vector2 and is_finite(spawn.x) and is_finite(spawn.y):
			return spawn
	return Vector2(INF, INF)


func get_current_respawn_spawn_position() -> Vector2:
	var checkpoint_spawn := get_current_checkpoint_spawn_position()
	if is_finite(checkpoint_spawn.x) and is_finite(checkpoint_spawn.y):
		return checkpoint_spawn
	return get_current_entrance_gate_spawn_position()


func get_current_checkpoint_spawn_position() -> Vector2:
	if world == null or not ("active_checkpoint_grid" in world) or not ("active_checkpoint_world" in world):
		return Vector2(INF, INF)

	var checkpoint_world := str(world.active_checkpoint_world).strip_edges().to_upper()
	var current_world := str(world.current_world_name).strip_edges().to_upper()
	if checkpoint_world == "" or checkpoint_world != current_world:
		return Vector2(INF, INF)

	var checkpoint_grid: Vector2i = world.active_checkpoint_grid
	if checkpoint_grid == world.INVALID_GRID_POS:
		return Vector2(INF, INF)
	if not world.blocks.has(checkpoint_grid):
		return Vector2(INF, INF)

	var block_data = world.blocks.get(checkpoint_grid, {})
	if not (block_data is Dictionary):
		return Vector2(INF, INF)
	if world.has_method("is_checkpoint_block_type") and not bool(world.is_checkpoint_block_type(str(block_data.get("type", "")))):
		return Vector2(INF, INF)

	return Vector2(
		float(checkpoint_grid.x * world.BLOCK_SIZE),
		float(checkpoint_grid.y * world.BLOCK_SIZE)
	)


func flush_respawn_position_to_server() -> bool:
	if not MovementMode.is_websocket():
		return false
	if world == null or world.player == null or not world.in_world:
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_position"):
		return false

	var current_position = world.player.global_position
	var current_facing: int = -1 if int(world.player_facing_direction) < 0 else 1
	var sent := bool(network.send_player_position(current_position, current_facing, world.current_world_name, false, true, "respawn"))
	if sent:
		network_position_timer = get_network_position_send_interval()
		network_heartbeat_timer = get_network_position_heartbeat_interval()
		last_sent_network_position = current_position
		last_sent_network_facing = current_facing
		last_sent_network_animation_state = "idle"
		last_sent_network_lava_fire_state = false
		last_sent_network_fishing_key = get_local_fishing_sync_key()
		last_sent_network_damage_key = get_local_damage_flash_sync_key()
	return sent


# --- Multiplayer Polish v2: remote player visuals + smoothing ---
const CHAT_BUBBLE_COMPONENT = preload("res://Scripts/chat_bubble_component.gd")
const WEBSOCKET_SNAPSHOT_BUFFER = preload("res://Scripts/networking/websocket_snapshot_buffer.gd")
var remote_players := {}
var remote_name_labels := {}
var remote_debug_labels := {}
var remote_chat_bubbles := {}
var remote_chat_pending_messages := {}
var remote_pending_position_snapshots := {}
var remote_position_snapshot_generation := 0
var remote_name_font: Font = null
var remote_players_root = null
var remote_visual_stabilization_deferred_queued := false
var network_position_timer := 0.0
var network_heartbeat_timer := 0.0
var last_sent_network_animation_state := ""
var last_sent_network_lava_fire_state := false
var last_sent_network_position := Vector2(999999, 999999)
var last_sent_network_facing := 0
var last_sent_network_fishing_key := ""
var last_sent_network_damage_key := ""
var last_player_punch_request_msec := 0
var remote_action_sequences := {}
var remote_action_server_times := {}
const NETWORK_POSITION_SEND_INTERVAL := 0.016
const NETWORK_POSITION_SEND_INTERVAL_MAX_SECONDS := 0.2
const NETWORK_POSITION_HEARTBEAT_INTERVAL := 0.1
const NETWORK_POSITION_HEARTBEAT_NO_OTHER_MULTIPLIER := 10.0
const NETWORK_POSITION_HEARTBEAT_FEW_OTHER_MULTIPLIER := 5.0
const NETWORK_POSITION_HEARTBEAT_CROWDED_OTHER_MULTIPLIER := 2.0
const NETWORK_POSITION_HEARTBEAT_MAX_SECONDS := 1.5
const NETWORK_POSITION_MIN_DISTANCE := 0.35
const NETWORK_POSITION_FLUSH_MIN_DISTANCE := 0.35
const REMOTE_NAME_LABEL_WIDTH := 300.0
const REMOTE_NAME_LABEL_HEIGHT := 34.0
const REMOTE_DEBUG_LABEL_WIDTH := 300.0
const REMOTE_DEBUG_LABEL_HEIGHT := 120.0
const REMOTE_DEBUG_LABEL_FONT_SIZE := 12
const REMOTE_NAME_LABEL_MARGIN_ABOVE_HEAD_WORLD_PX := 18.0
const REMOTE_NAME_LABEL_FALLBACK_OFFSET_WORLD_PX := 66.0
const REMOTE_NAME_FONT_PATH := "res://Assets/font/font.ttf"
const REMOTE_NAME_FONT_SIZE_META := &"pixelmania_font_size"
const REMOTE_NAME_FONT_SIZE := 28
const REMOTE_NAME_OUTLINE_SIZE := 10
const REMOTE_NAME_WORLD_Z_FALLBACK := 3899
const REMOTE_NAME_SCREEN_POSITION_META := "remote_name_screen_position"
const REMOTE_NAME_ABSOLUTE_Z_META := "remote_name_absolute_world_z"
const WORLD_LOCK_OWNER_NAME_COLOR := Color(1.0, 0.623529, 0.109804, 1.0)
const SUPER_WORLD_LOCK_OWNER_NAME_COLOR := Color(1.0, 0.08, 0.82, 1.0)
const WORLD_LOCK_ACCESS_NAME_COLOR := Color(1.0, 0.768627, 0.419608, 1.0)
const WORLD_LOCK_NAME_COLOR_DEFAULT := Color(1.0, 1.0, 1.0, 1.0)
const REMOTE_NAME_DEFAULT_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.92)
const REMOTE_NAME_DEFAULT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const PURPLE_GLOW_REMOTE_NAME_KEY := "white"
const PURPLE_GLOW_REMOTE_NAME_COLOR := Color(0.92, 0.48, 1.0, 1.0)
const PURPLE_GLOW_REMOTE_NAME_COLOR_BRIGHT := Color(1.0, 0.72, 1.0, 1.0)
const PURPLE_GLOW_REMOTE_OUTLINE_COLOR := Color(0.52, 0.04, 1.0, 0.96)
const PURPLE_GLOW_REMOTE_OUTLINE_COLOR_BRIGHT := Color(0.86, 0.24, 1.0, 1.0)
const PURPLE_GLOW_REMOTE_SHADOW_COLOR := Color(0.48, 0.0, 1.0, 0.82)
const PURPLE_GLOW_REMOTE_SHADOW_COLOR_BRIGHT := Color(0.78, 0.18, 1.0, 0.96)
const PURPLE_GLOW_REMOTE_PULSE_SPEED := 3.0
const REMOTE_PLAYERS_ROOT_Z_INDEX := 120
const REMOTE_PLAYER_Z_INDEX := 128
const REMOTE_PLAYER_Z_STRIDE := 192
const REMOTE_PLAYER_BODY_Z_INDEX := 0
const REMOTE_PLAYER_BACK_Z_INDEX := -30
const REMOTE_PLAYER_EQUIPMENT_Z_INDEX := 2
const REMOTE_PLAYER_HAND_Z_INDEX := 60
const REMOTE_MOVEMENT_SEQUENCE_MAX := 2147483647
const REMOTE_MOVEMENT_SEQUENCE_WRAP_WINDOW := 1073741824
const REMOTE_PLAYER_ENABLE_VISUAL_POSITION_SNAPPING := false
const REMOTE_POSITION_SMOOTH_RATE := 34.0
const REMOTE_POSITION_SNAP_DISTANCE := 160.0
const REMOTE_POSITION_SETTLE_DISTANCE := 0.15
const REMOTE_POSITION_VELOCITY_LEAD_MAX_SECONDS := 0.0
const REMOTE_POSITION_MAX_VELOCITY_LEAD_PIXELS := 0.0
const REMOTE_SNAPSHOT_INTERVAL_MAX_MS := 5000.0
const REMOTE_SNAPSHOT_INTERVAL_MIN_MS := 1.0
const REMOTE_PENDING_POSITION_SNAPSHOT_MAX_AGE_MS := 5000
const REMOTE_PENDING_POSITION_SNAPSHOT_MAX_ENTRIES := 128
# Camera-relative jitter fix:
# Remote player root positions should be smoothed from the physics tick, matching
# the local CharacterBody2D/camera timing. If remote roots are moved from render
# frames while the camera follows a physics-driven local player, remote players can
# look smooth while local is idle but jitter when both local and remote move.
const REMOTE_POSITION_UPDATE_FROM_PHYSICS := true
const INTERPOLATION_DELAY_MS := 70
const REMOTE_PRESENTATION_OFFSET_DECAY_RATE := 18.0
const REMOTE_DEBUG_LOG_THROTTLE_MS := 300
const REMOTE_WALK_FRAME_TIME := 0.16
const REMOTE_IDLE_FRAME_TIME := 0.45
const REMOTE_WALK_SPEED_THRESHOLD := 8.0
const REMOTE_POSITION_WALK_MIN_DISTANCE := 2.0
const REMOTE_JUMP_SPEED_THRESHOLD := 8.0
const REMOTE_AIRBORNE_STALE_EPS_VELOCITY := 8.0
const REMOTE_AIRBORNE_STALE_DISTANCE := 1.5
const REMOTE_AIRBORNE_STALE_TIMEOUT_MS := 260.0
const REMOTE_WALK_PHASE_SPEED := 13.0
const REMOTE_IDLE_PHASE_SPEED := 3.0
const REMOTE_PLAYER_STALE_TIMEOUT := 20.0
const REMOTE_PLAYER_STALE_VISUAL_WARNING_TIMEOUT := 3.5
const MAX_REMOTE_PLAYER_COORD := 1000000.0
const MAX_REMOTE_PLAYER_NAME_LENGTH := 24
const PLAYER_PUNCH_REQUEST_COOLDOWN_MSEC := 160
const PLAYER_PUNCH_GRID_HORIZONTAL_TOLERANCE := 36.0
const PLAYER_PUNCH_GRID_VERTICAL_TOLERANCE := 58.0
const PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_X_SCALE := 0.07
const PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_Y_SCALE := 0.0
const PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_MAX_PIXELS := 14.0
const PLAYER_PUNCH_KNOCKBACK_MAX := 1200.0
const PLAYER_PUNCH_REMOTE_COLLISION_SAMPLE_OFFSETS = [
	Vector2(-7.5, -7.5),
	Vector2(7.5, -7.5),
	Vector2(-7.5, 0.0),
	Vector2(7.5, 0.0),
	Vector2(-7.5, 7.5),
	Vector2(7.5, 7.5)
]
const REMOTE_WATER_SPLASH_MOVE_COOLDOWN_MSEC := 420
const REMOTE_WATER_SPLASH_MOVE_SPEED := 55.0
const REMOTE_WATER_BUBBLE_INTERVAL_MIN_MSEC := 2100
const REMOTE_WATER_BUBBLE_INTERVAL_MAX_MSEC := 4000
const REMOTE_WATER_BUBBLE_INITIAL_DELAY_MIN_MSEC := 450
const REMOTE_WATER_BUBBLE_INITIAL_DELAY_MAX_MSEC := 1400
const REMOTE_WATER_BUBBLE_MOUTH_OFFSET_X := 6.0
const REMOTE_WATER_BUBBLE_MOUTH_OFFSET_Y := -12.0
const REMOTE_WATER_SAMPLE_FACTORS = [-0.35, 0.0, 0.35]
const REMOTE_WATER_BLOCK_ID := "water"
const REMOTE_LAVA_FIRE_PARTICLE_COOLDOWN_MSEC := 55
const REMOTE_LAVA_FIRE_SOUND_COOLDOWN_MSEC := 420
const REMOTE_LAVA_FIRE_BODY_HALF_EXTENTS := Vector2(10.0, 16.0)
const REMOTE_PLAYER_VISIBILITY_MARGIN_SCREEN_PX := 384.0
const REMOTE_LAVA_FIRE_SAMPLE_OFFSETS = [
	Vector2(-6.0, -12.0),
	Vector2(0.0, -12.0),
	Vector2(6.0, -12.0),
	Vector2(-8.0, 0.0),
	Vector2(8.0, 0.0),
	Vector2(-6.0, 12.0),
	Vector2(0.0, 12.0),
	Vector2(6.0, 12.0)
]
const REMOTE_FISHING_BOBBER_SCENE_PATH := "res://Scenes/fishing_bobber.tscn"
const REMOTE_FISHING_LINE_SEGMENTS := 16
const REMOTE_FISHING_LINE_SAG := 26.0
const REMOTE_FISHING_LINE_WAVE_AMPLITUDE := 2.0
const REMOTE_FISHING_LINE_WAVE_FREQUENCY := 1.6
const REMOTE_FISHING_LINE_WAVE_SPEED := 4.2
const REMOTE_FISHING_BOBBER_Z_OFFSET := -4

var remote_idle_texture = null
var remote_idle_textures: Array = []
var remote_walk_textures: Array = []
var remote_jump_texture = null
var visible_remote_player_nodes := 0


func get_overhead_layer():
	if world == null:
		return null
	if world.has_method("get_ui_overhead_layer"):
		return world.get_ui_overhead_layer()
	if "ui_layer" in world:
		return world.ui_layer
	return null


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


func _safe_remote_movement_sequence(value, fallback: int = 0, min_value: int = 0, max_value: int = REMOTE_MOVEMENT_SEQUENCE_MAX) -> int:
	if value is int or value is float:
		return clamp(int(value), min_value, max_value)
	if value is String:
		var raw_value = value.strip_edges()
		if raw_value.is_empty():
			return fallback
		if raw_value.is_valid_int():
			return clamp(int(raw_value), min_value, max_value)
		if raw_value.is_valid_float():
			return clamp(int(float(raw_value)), min_value, max_value)
	return fallback


func _is_remote_movement_sequence_newer(new_sequence: int, previous_sequence: int) -> bool:
	var safe_previous = int(max(0, previous_sequence))
	var safe_new = int(max(0, new_sequence))
	if safe_new <= 0 or safe_previous <= 0:
		return false
	if safe_new > safe_previous:
		return true
	if safe_previous > REMOTE_MOVEMENT_SEQUENCE_MAX - REMOTE_MOVEMENT_SEQUENCE_WRAP_WINDOW and safe_new <= REMOTE_MOVEMENT_SEQUENCE_WRAP_WINDOW:
		return true
	return false


func _extract_remote_movement_sequence(player_data: Dictionary) -> int:
	var sequence = _safe_remote_movement_sequence(player_data.get("movement_sequence", 0), 0, 0, REMOTE_MOVEMENT_SEQUENCE_MAX)
	if sequence <= 0:
		sequence = _safe_remote_movement_sequence(player_data.get("server_movement_sequence", 0), 0, 0, REMOTE_MOVEMENT_SEQUENCE_MAX)
	if sequence <= 0:
		sequence = _safe_remote_movement_sequence(player_data.get("accepted_sequence", 0), 0, 0, REMOTE_MOVEMENT_SEQUENCE_MAX)
	return sequence


func _is_remote_snapshot_payload_newer(candidate_payload: Dictionary, reference_payload: Dictionary) -> bool:
	if not (candidate_payload is Dictionary):
		return false
	if not (reference_payload is Dictionary):
		return true

	var candidate_sequence := _extract_remote_movement_sequence(candidate_payload)
	var reference_sequence := _extract_remote_movement_sequence(reference_payload)
	if candidate_sequence > 0 and reference_sequence > 0:
		if _is_remote_movement_sequence_newer(candidate_sequence, reference_sequence):
			return true
		if candidate_sequence == reference_sequence:
			var candidate_snapshot_time := _extract_remote_snapshot_time_msec(candidate_payload, 0)
			var reference_snapshot_time := _extract_remote_snapshot_time_msec(reference_payload, 0)
			return candidate_snapshot_time > reference_snapshot_time
		return false
	if candidate_sequence > 0:
		return true
	if reference_sequence > 0:
		return false

	var candidate_time := _extract_remote_snapshot_time_msec(candidate_payload, 0)
	var reference_time := _extract_remote_snapshot_time_msec(reference_payload, 0)
	return candidate_time > reference_time


func _log_remote_movement_drop(remote_player, reason: String, details: Dictionary = {}) -> void:
	if not movement_sync_debug_enabled:
		return
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var now_msec := Time.get_ticks_msec()
	var last_log_msec := int(remote_player.get_meta("remote_movement_drop_log_msec", 0))
	if now_msec - last_log_msec < REMOTE_DEBUG_LOG_THROTTLE_MS:
		return
	remote_player.set_meta("remote_movement_drop_log_msec", now_msec)

	var payload := {
		"event": "drop",
		"reason": reason,
		"player_id": str(remote_player.get_meta("remote_id", "")),
		"sequence": int(remote_player.get_meta("remote_movement_sequence", 0)),
		"world": _safe_remote_world_name(world.current_world_name) if world != null else "",
	}
	for key in details.keys():
		payload[key] = details[key]
	print("[MovementSync][Remote] " + str(payload))


func get_visible_world_rect(margin_screen_px: float = 0.0) -> Rect2:
	var viewport = get_viewport()
	if viewport == null:
		return Rect2(Vector2(-MAX_REMOTE_PLAYER_COORD, -MAX_REMOTE_PLAYER_COORD), Vector2(MAX_REMOTE_PLAYER_COORD * 2.0, MAX_REMOTE_PLAYER_COORD * 2.0))

	var screen_rect: Rect2 = viewport.get_visible_rect().grow(margin_screen_px)
	var inverse_transform: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var corners = [
		screen_rect.position,
		screen_rect.position + Vector2(screen_rect.size.x, 0.0),
		screen_rect.position + Vector2(0.0, screen_rect.size.y),
		screen_rect.position + screen_rect.size
	]
	var min_point: Vector2 = inverse_transform * corners[0]
	var max_point: Vector2 = min_point

	for corner in corners:
		var world_point: Vector2 = inverse_transform * corner
		min_point.x = minf(min_point.x, world_point.x)
		min_point.y = minf(min_point.y, world_point.y)
		max_point.x = maxf(max_point.x, world_point.x)
		max_point.y = maxf(max_point.y, world_point.y)

	return Rect2(min_point, max_point - min_point)


func is_world_position_visible(world_position: Vector2, visible_world_rect: Rect2) -> bool:
	if visible_world_rect.size.x <= 0.0 or visible_world_rect.size.y <= 0.0:
		return true
	return visible_world_rect.has_point(world_position)


func is_remote_player_visual_active(remote_player, visible_world_rect: Rect2) -> bool:
	if remote_player == null or not is_instance_valid(remote_player):
		return false
	return is_world_position_visible(remote_player.global_position, visible_world_rect)


func set_remote_player_visual_active(remote_player, active: bool) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	remote_player.set_meta("visible_in_camera", active)
	if remote_player is CanvasItem and bool(remote_player.visible) != active:
		remote_player.visible = active

func process_multiplayer_remote_visuals(delta: float):
	if not MovementMode.is_websocket():
		return

	update_remote_players_visuals(delta)
	update_remote_name_labels()
	if remote_debug_labels.size() > 0:
		clear_remote_debug_labels()
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
	remote_players_root.z_index = REMOTE_PLAYERS_ROOT_Z_INDEX


func refresh_remote_player_draw_order():
	if remote_players.is_empty():
		return

	var ordered_ids = remote_players.keys()
	ordered_ids.sort()

	for index in range(ordered_ids.size()):
		var remote_id = ordered_ids[index]
		var remote_player = remote_players.get(remote_id, null)
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		remote_player.set_meta("remote_draw_order", index)
		configure_remote_player_draw_order(remote_player, index)


func configure_remote_player_draw_order(remote_player, order_index: int = 0):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	remote_player.z_as_relative = false
	remote_player.z_index = REMOTE_PLAYER_Z_INDEX + order_index * REMOTE_PLAYER_Z_STRIDE
	normalize_remote_canvas_item_z_mode(remote_player)


func normalize_remote_canvas_item_z_mode(node, root_node = null):
	if node == null or not is_instance_valid(node):
		return

	if root_node == null:
		root_node = node

	if node is CanvasItem and node != root_node and node != remote_players_root:
		node.z_as_relative = not bool(node.get_meta(REMOTE_NAME_ABSOLUTE_Z_META, false))

	for child in node.get_children():
		normalize_remote_canvas_item_z_mode(child, root_node)


func get_remote_visual_pixel_snap_offset(remote_player, player_visual: Node2D, base_position: Vector2) -> Vector2:
	if not REMOTE_PLAYER_ENABLE_VISUAL_POSITION_SNAPPING:
		return Vector2.ZERO
	if remote_player == null or not is_instance_valid(remote_player) or not (remote_player is Node2D):
		return Vector2.ZERO
	if player_visual == null or not is_instance_valid(player_visual):
		return Vector2.ZERO

	var viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO

	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var inverse_transform: Transform2D = canvas_transform.affine_inverse()
	var visual_world_position: Vector2 = remote_player.to_global(base_position)
	var visual_screen_position: Vector2 = canvas_transform * visual_world_position
	var snapped_screen_position := Vector2(round(visual_screen_position.x), round(visual_screen_position.y))
	var snapped_world_position: Vector2 = inverse_transform * snapped_screen_position
	var unsnapped_world_position: Vector2 = inverse_transform * visual_screen_position
	var snapped_local_position: Vector2 = remote_player.to_local(visual_world_position + snapped_world_position - unsnapped_world_position)
	return snapped_local_position - base_position


func cache_remote_visual_base_transform(player_visual: Node2D) -> void:
	if player_visual == null:
		return

	if not player_visual.has_meta("remote_visual_base_position"):
		player_visual.set_meta("remote_visual_base_position", player_visual.position)
	if not player_visual.has_meta("remote_visual_base_scale"):
		player_visual.set_meta("remote_visual_base_scale", player_visual.scale)


func apply_remote_visual_stabilization(remote_player) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var player_visual = remote_player.get_node_or_null("PlayerVisual")
	if player_visual == null or not (player_visual is Node2D):
		return

	cache_remote_visual_base_transform(player_visual)

	var base_position_value = player_visual.get_meta("remote_visual_base_position", player_visual.position)
	var base_position: Vector2 = base_position_value if base_position_value is Vector2 else player_visual.position
	var snap_offset := get_remote_visual_pixel_snap_offset(remote_player, player_visual, base_position)
	var presentation_value = remote_player.get_meta("remote_presentation_offset", Vector2.ZERO)
	var presentation_offset: Vector2 = presentation_value if presentation_value is Vector2 else Vector2.ZERO
	player_visual.position = base_position + snap_offset + presentation_offset
	remote_player.set_meta("remote_visual_snap_offset", snap_offset)

	var base_scale_value = player_visual.get_meta("remote_visual_base_scale", player_visual.scale)
	var base_scale: Vector2 = base_scale_value if base_scale_value is Vector2 else player_visual.scale
	var scale_x: float = abs(base_scale.x)
	if scale_x <= 0.0:
		scale_x = 1.0
	var facing: int = int(remote_player.get_meta("facing", 1))
	player_visual.scale = Vector2(-scale_x if facing < 0 else scale_x, base_scale.y)


func queue_remote_visual_stabilization(remote_player) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	# Only schedule deferred pixel-snapping stabilization when it is actually enabled.
	# With snapping disabled, doing this every frame can still cause tiny one-frame
	# transform corrections after normal animation/facing updates.
	if not REMOTE_PLAYER_ENABLE_VISUAL_POSITION_SNAPPING:
		return

	remote_player.set_meta("remote_visual_stabilization_pending", true)
	if remote_visual_stabilization_deferred_queued:
		return

	remote_visual_stabilization_deferred_queued = true
	if RenderingServer.has_signal("frame_pre_draw"):
		RenderingServer.frame_pre_draw.connect(_flush_remote_visual_stabilization, CONNECT_ONE_SHOT)
	if DisplayServer.get_name().to_lower() == "headless":
		var tree := get_tree()
		if tree != null and tree.has_signal("process_frame"):
			tree.process_frame.connect(_flush_remote_visual_stabilization, CONNECT_ONE_SHOT)
		else:
			call_deferred("_flush_remote_visual_stabilization")


func _flush_remote_visual_stabilization() -> void:
	_disconnect_remote_visual_stabilization_signals()
	remote_visual_stabilization_deferred_queued = false

	for remote_id in remote_players.keys():
		var remote_player = remote_players.get(remote_id, null)
		if remote_player == null or not is_instance_valid(remote_player):
			continue
		if not bool(remote_player.get_meta("remote_visual_stabilization_pending", false)):
			continue

		remote_player.set_meta("remote_visual_stabilization_pending", false)
		apply_remote_visual_stabilization(remote_player)


func _disconnect_remote_visual_stabilization_signals() -> void:
	var flush_callable := Callable(self, "_flush_remote_visual_stabilization")
	if RenderingServer.has_signal("frame_pre_draw") and RenderingServer.frame_pre_draw.is_connected(flush_callable):
		RenderingServer.frame_pre_draw.disconnect(flush_callable)

	var tree := get_tree()
	if tree != null and tree.has_signal("process_frame") and tree.process_frame.is_connected(flush_callable):
		tree.process_frame.disconnect(flush_callable)


func get_safe_remote_punch_visual_offset(base_position: Vector2, raw_offset: Vector2) -> Vector2:
	if raw_offset.length_squared() <= 0.01:
		return Vector2.ZERO

	var offset := raw_offset
	if offset.length() > PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_MAX_PIXELS:
		offset = offset.normalized() * PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_MAX_PIXELS

	var block_size := maxf(1.0, get_remote_world_block_size())
	var step_size := maxf(1.0, block_size * 0.25)
	var steps: int = maxi(1, int(ceil(offset.length() / step_size)))
	var safe_offset := Vector2.ZERO
	for index in range(1, steps + 1):
		var candidate := offset * (float(index) / float(steps))
		if is_remote_punch_visual_position_blocked(base_position + candidate):
			break
		safe_offset = candidate

	return safe_offset


func is_remote_punch_visual_position_blocked(position: Vector2) -> bool:
	if world == null:
		return false

	for sample_offset in PLAYER_PUNCH_REMOTE_COLLISION_SAMPLE_OFFSETS:
		var typed_offset: Vector2 = sample_offset
		if is_remote_punch_visual_sample_blocked(position + typed_offset):
			return true

	return false


func is_remote_punch_visual_sample_blocked(sample_position: Vector2) -> bool:
	var block_size := maxf(1.0, get_remote_world_block_size())
	var grid_pos := Vector2i(
		int(floor(sample_position.x / block_size)),
		int(floor(sample_position.y / block_size))
	)
	var block_type := get_remote_foreground_block_type(grid_pos)
	if block_type == "":
		return false

	return is_remote_foreground_block_solid_for_punch(block_type)


func get_remote_foreground_block_type(grid_pos: Vector2i) -> String:
	if world == null:
		return ""

	var foreground_blocks = world.get("blocks")
	if not (foreground_blocks is Dictionary):
		return ""
	if not foreground_blocks.has(grid_pos):
		return ""

	return get_remote_block_type_from_data(foreground_blocks[grid_pos])


func is_remote_foreground_block_solid_for_punch(block_type: String) -> bool:
	if world == null:
		return false

	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false

	if "block_manager" in world and world.block_manager != null:
		if world.block_manager.has_method("is_simple_full_solid_foreground_collision_block"):
			return bool(world.block_manager.is_simple_full_solid_foreground_collision_block(clean_type))
		if world.block_manager.has_method("is_background_block_type") and bool(world.block_manager.is_background_block_type(clean_type)):
			return false
		if world.block_manager.has_method("is_platform_collision_block_type") and bool(world.block_manager.is_platform_collision_block_type(clean_type)):
			return false
		if world.block_manager.has_method("is_non_collideable_block") and bool(world.block_manager.is_non_collideable_block(clean_type)):
			return false

	if world.has_method("is_non_collideable_block") and bool(world.is_non_collideable_block(clean_type)):
		return false

	return true


func update_remote_visual_position(remote_player, delta: float) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return
	_update_remote_visual_position_v1(remote_player, delta)


func _update_remote_visual_position_v1(remote_player, delta: float) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var buffered_position = get_remote_buffered_render_position(remote_player)
	if buffered_position is Vector2:
		var remote_animation_state = str(remote_player.get_meta("animation_state", "idle"))
		var is_airborne_for_collision_checks := remote_animation_state in ["jump", "fall"] or not bool(remote_player.get_meta("network_on_floor", true))
		var safe_position: Vector2 = buffered_position
		if not is_airborne_for_collision_checks:
			safe_position = get_safe_remote_render_position(remote_player.global_position, buffered_position)
		remote_player.set_meta("smoothed_position", safe_position)
		remote_player.global_position = safe_position
		var authoritative_value = remote_player.get_meta("authoritative_position", safe_position)
		var authoritative_position: Vector2 = authoritative_value if authoritative_value is Vector2 else safe_position
		remote_player.set_meta("remote_render_drift_px", safe_position.distance_to(authoritative_position))
		return

	# Fallback for first packet / no buffer yet.
	var target_value = remote_player.get_meta("target_position", remote_player.global_position)
	if not (target_value is Vector2):
		return

	var target_position: Vector2 = target_value

	# Do not add frame-by-frame velocity lead in WebSocket V1. It can make remote
	# players shimmer when the local camera and remote player are both moving,
	# because packet age changes every render frame. Keep target_position stable and
	# let smoothing handle the catch-up.
	if REMOTE_POSITION_VELOCITY_LEAD_MAX_SECONDS > 0.0 and REMOTE_POSITION_MAX_VELOCITY_LEAD_PIXELS > 0.0:
		var last_receive_msec := int(remote_player.get_meta("remote_last_receive_msec", Time.get_ticks_msec()))
		var packet_age_seconds := clampf(float(Time.get_ticks_msec() - last_receive_msec) / 1000.0, 0.0, REMOTE_POSITION_VELOCITY_LEAD_MAX_SECONDS)
		var network_velocity := Vector2(
			float(remote_player.get_meta("network_velocity_x", 0.0)),
			float(remote_player.get_meta("network_velocity_y", 0.0))
		)
		var velocity_lead := network_velocity * packet_age_seconds
		if velocity_lead.length() > REMOTE_POSITION_MAX_VELOCITY_LEAD_PIXELS:
			velocity_lead = velocity_lead.normalized() * REMOTE_POSITION_MAX_VELOCITY_LEAD_PIXELS
		target_position += velocity_lead

	var smoothed_value = remote_player.get_meta("smoothed_position", remote_player.global_position)
	var current_position: Vector2 = remote_player.global_position
	if smoothed_value is Vector2:
		current_position = smoothed_value

	var distance_to_target := current_position.distance_to(target_position)
	var next_position: Vector2 = target_position
	if delta > 0.0 and distance_to_target < REMOTE_POSITION_SNAP_DISTANCE:
		var blend := clampf(1.0 - exp(-REMOTE_POSITION_SMOOTH_RATE * delta), 0.0, 1.0)
		next_position = current_position.lerp(target_position, blend)
		if next_position.distance_to(target_position) <= REMOTE_POSITION_SETTLE_DISTANCE:
			next_position = target_position

	remote_player.set_meta("smoothed_position", next_position)
	remote_player.global_position = next_position


func _get_remote_snapshot_buffer(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return null
	var buffer = remote_player.get_meta("remote_snapshot_buffer", null)
	if buffer == null or not buffer.has_method("push_snapshot"):
		buffer = WEBSOCKET_SNAPSHOT_BUFFER.new()
		remote_player.set_meta("remote_snapshot_buffer", buffer)
	return buffer


func _get_remote_interpolation_delay_ms(remote_player = null) -> int:
	var buffer = _get_remote_snapshot_buffer(remote_player)
	if buffer != null:
		return int(round(float(buffer.get_stats().get("interpolation_delay_ms", INTERPOLATION_DELAY_MS))))
	return INTERPOLATION_DELAY_MS


func append_remote_position_snapshot(remote_player, server_time_msec: int, receive_time_msec: int, sequence: int, position: Vector2, velocity: Vector2) -> bool:
	var buffer = _get_remote_snapshot_buffer(remote_player)
	if buffer == null:
		return false
	var accepted: bool = bool(buffer.push_snapshot(server_time_msec, receive_time_msec, sequence, position, velocity))
	var stats: Dictionary = buffer.get_stats()
	remote_player.set_meta("remote_buffer_size", int(stats.get("buffer_size", 0)))
	remote_player.set_meta("remote_interpolation_delay_ms", float(stats.get("interpolation_delay_ms", INTERPOLATION_DELAY_MS)))
	remote_player.set_meta("remote_arrival_jitter_ms", float(stats.get("jitter_ewma_ms", 0.0)))
	remote_player.set_meta("remote_rejected_snapshot_count", int(stats.get("rejected_snapshot_count", 0)))
	remote_player.set_meta("remote_render_drift_px", remote_player.global_position.distance_to(position))
	_maybe_log_remote_movement_sync(remote_player, stats, accepted)
	return accepted


func reset_remote_position_snapshot_buffer(remote_player, server_time_msec: int, receive_time_msec: int, sequence: int, position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	var buffer = _get_remote_snapshot_buffer(remote_player)
	if buffer == null:
		return
	buffer.reset(server_time_msec, receive_time_msec, sequence, position, velocity)
	remote_player.set_meta("remote_buffer_size", 1)
	remote_player.set_meta("remote_previous_snapshot_msec", server_time_msec)
	remote_player.set_meta("remote_next_snapshot_msec", server_time_msec)
	remote_player.set_meta("remote_interpolation_alpha", 1.0)
	remote_player.set_meta("remote_interpolation_progress_ms", 0)
	remote_player.set_meta("remote_dead_reckoning_active", false)
	remote_player.set_meta("remote_dead_reckon_ms", 0)


func get_remote_buffered_render_position(remote_player):
	var buffer = _get_remote_snapshot_buffer(remote_player)
	if buffer == null:
		return null
	var sample: Dictionary = buffer.sample(int(Time.get_ticks_msec()))
	if sample.is_empty() or not (sample.get("position", null) is Vector2):
		return null
	var previous_time := int(sample.get("previous_time_ms", 0))
	var next_time := int(sample.get("next_time_ms", previous_time))
	var extrapolation_ms := float(sample.get("extrapolation_ms", 0.0))
	remote_player.set_meta("remote_previous_snapshot_msec", previous_time)
	remote_player.set_meta("remote_next_snapshot_msec", next_time)
	remote_player.set_meta("remote_interpolation_alpha", float(sample.get("alpha", 0.0)))
	remote_player.set_meta("remote_interpolation_progress_ms", maxi(0, int(float(sample.get("render_time_ms", previous_time))) - previous_time))
	remote_player.set_meta("remote_dead_reckoning_active", str(sample.get("mode", "")) == "extrapolate")
	remote_player.set_meta("remote_dead_reckon_ms", int(round(extrapolation_ms)))
	remote_player.set_meta("remote_buffer_size", int(buffer.get_stats().get("buffer_size", 0)))
	return sample.get("position")


func _maybe_log_remote_movement_sync(remote_player, stats: Dictionary, accepted: bool) -> void:
	if not movement_sync_debug_enabled or remote_player == null or not is_instance_valid(remote_player):
		return
	var now_msec := Time.get_ticks_msec()
	var previous_log_msec := int(remote_player.get_meta("remote_sync_debug_log_msec", 0))
	if accepted and now_msec - previous_log_msec < 1000:
		return
	remote_player.set_meta("remote_sync_debug_log_msec", now_msec)
	print("[MovementSync][Remote] id=%s accepted=%s sequence=%d buffer=%d delay_ms=%.2f jitter_ms=%.2f drift_px=%.2f rejected=%d" % [
		str(remote_player.get_meta("remote_id", "")),
		str(accepted),
		int(stats.get("last_sequence", 0)),
		int(stats.get("buffer_size", 0)),
		float(stats.get("interpolation_delay_ms", 0.0)),
		float(stats.get("jitter_ewma_ms", 0.0)),
		float(remote_player.get_meta("remote_render_drift_px", 0.0)),
		int(stats.get("rejected_snapshot_count", 0))
	])


func update_remote_water_splash(remote_player, target_position: Vector2, had_position: bool, velocity_x: float, velocity_y: float, target_speed_hint: float):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if world == null or not world.has_method("spawn_water_splash_particles"):
		return

	var in_water := is_remote_position_on_water(target_position)
	var was_in_water := bool(remote_player.get_meta("in_water", false))
	remote_player.set_meta("in_water", in_water)

	if not had_position:
		return

	var now_msec := Time.get_ticks_msec()
	var ready_msec := int(remote_player.get_meta("water_splash_ready_msec", 0))
	if in_water and not was_in_water:
		var enter_intensity := 0.78 + clampf(abs(velocity_y) / 140.0, 0.0, 1.0) * 0.55
		world.spawn_water_splash_particles(get_remote_water_splash_position(target_position), enter_intensity)
		remote_player.set_meta("water_splash_ready_msec", now_msec + REMOTE_WATER_SPLASH_MOVE_COOLDOWN_MSEC)
		return

	var horizontal_speed = maxf(abs(velocity_x), target_speed_hint)
	if in_water and horizontal_speed >= REMOTE_WATER_SPLASH_MOVE_SPEED and now_msec >= ready_msec:
		world.spawn_water_splash_particles(get_remote_water_splash_position(target_position), 0.42)
		remote_player.set_meta("water_splash_ready_msec", now_msec + REMOTE_WATER_SPLASH_MOVE_COOLDOWN_MSEC)


func is_remote_position_on_water(position: Vector2) -> bool:
	if world == null:
		return false

	var block_size := get_remote_world_block_size()
	var sample_y := position.y + 8.0
	for sample_factor in REMOTE_WATER_SAMPLE_FACTORS:
		var sample_position := Vector2(position.x + 8.0 * float(sample_factor), sample_y)
		var sample_grid := get_remote_grid_for_centered_world_point(sample_position, block_size)
		if remote_grid_position_has_water(sample_grid):
			return true

	return false


func get_remote_water_splash_position(position: Vector2) -> Vector2:
	return position + Vector2(0.0, 5.0)


func update_remote_underwater_bubbles(remote_player, target_position: Vector2):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if world == null or not world.has_method("spawn_underwater_bubbles_particles"):
		return

	var facing := int(remote_player.get_meta("facing", 1))
	if not is_remote_position_underwater_for_bubbles(target_position, facing):
		remote_player.set_meta("water_bubble_ready_msec", 0)
		return

	var now_msec := Time.get_ticks_msec()
	var ready_msec := int(remote_player.get_meta("water_bubble_ready_msec", 0))
	if ready_msec <= 0:
		remote_player.set_meta("water_bubble_ready_msec", now_msec + randi_range(REMOTE_WATER_BUBBLE_INITIAL_DELAY_MIN_MSEC, REMOTE_WATER_BUBBLE_INITIAL_DELAY_MAX_MSEC))
		return

	if now_msec < ready_msec:
		return

	world.spawn_underwater_bubbles_particles(get_remote_underwater_bubble_mouth_position(target_position, facing), randi_range(1, 3))
	remote_player.set_meta("water_bubble_ready_msec", now_msec + randi_range(REMOTE_WATER_BUBBLE_INTERVAL_MIN_MSEC, REMOTE_WATER_BUBBLE_INTERVAL_MAX_MSEC))


func update_remote_lava_fire_particles(remote_player, target_position: Vector2, network_in_lava_fire: bool = false):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if world == null:
		return

	var is_touching: bool = network_in_lava_fire or is_remote_position_touching_lava_or_fire(target_position)
	if not is_touching:
		remote_player.set_meta("network_lava_fire_touching", false)
		remote_player.set_meta("lava_fire_particle_ready_msec", 0)
		return

	var now_msec := Time.get_ticks_msec()
	var was_touching := bool(remote_player.get_meta("network_lava_fire_touching", false))
	var ready_msec := int(remote_player.get_meta("lava_fire_particle_ready_msec", 0))
	if not was_touching or now_msec >= ready_msec:
		if world.has_method("spawn_player_fire_particles"):
			var intensity: float = 1.35 if not was_touching else 1.0
			world.spawn_player_fire_particles(target_position, REMOTE_LAVA_FIRE_BODY_HALF_EXTENTS, intensity)
		remote_player.set_meta("lava_fire_particle_ready_msec", now_msec + REMOTE_LAVA_FIRE_PARTICLE_COOLDOWN_MSEC)

	remote_player.set_meta("network_lava_fire_touching", true)
	play_remote_lava_fire_hit_sound(remote_player, now_msec)


func play_remote_lava_fire_hit_sound(remote_player, now_msec: int):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if world == null or not world.has_method("play_sound_lava_fire_hit"):
		return

	var ready_msec := int(remote_player.get_meta("lava_fire_sound_ready_msec", 0))
	if now_msec < ready_msec:
		return

	world.play_sound_lava_fire_hit(remote_player.global_position)
	remote_player.set_meta("lava_fire_sound_ready_msec", now_msec + REMOTE_LAVA_FIRE_SOUND_COOLDOWN_MSEC)


func update_remote_damage_flash(remote_player, active: bool, remaining_msec: int, token: int):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var safe_remaining: int = clampi(remaining_msec, 0, HURT_FACE_EXPRESSION_TIME_MSEC)
	var safe_token: int = maxi(0, token)
	var effective_active: bool = active and safe_remaining > 0
	remote_player.set_meta("damage_flash_active", effective_active)
	remote_player.set_meta("damage_flash_token", safe_token)

	if effective_active:
		remote_player.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + safe_remaining)
		return

	remote_player.set_meta("face_hurt_until_msec", 0)


func is_remote_position_underwater_for_bubbles(position: Vector2, facing: int) -> bool:
	if world == null:
		return false

	var block_size := get_remote_world_block_size()
	var safe_facing: int = 1 if facing >= 0 else -1
	var sample_offsets := [
		Vector2(REMOTE_WATER_BUBBLE_MOUTH_OFFSET_X * float(safe_facing), REMOTE_WATER_BUBBLE_MOUTH_OFFSET_Y),
		Vector2(0.0, -12.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, 8.0)
	]

	for offset in sample_offsets:
		var sample_offset: Vector2 = offset
		var sample_position: Vector2 = position + sample_offset
		var grid_pos := get_remote_grid_for_centered_world_point(sample_position, block_size)
		if remote_grid_position_has_water(grid_pos):
			return true

	return false


func get_remote_underwater_bubble_mouth_position(position: Vector2, facing: int) -> Vector2:
	var safe_facing: int = 1 if facing >= 0 else -1
	return position + Vector2(REMOTE_WATER_BUBBLE_MOUTH_OFFSET_X * float(safe_facing), REMOTE_WATER_BUBBLE_MOUTH_OFFSET_Y)


func is_remote_position_touching_lava_or_fire(position: Vector2) -> bool:
	if world == null:
		return false

	var block_size := get_remote_world_block_size()
	for offset in REMOTE_LAVA_FIRE_SAMPLE_OFFSETS:
		var sample_offset: Vector2 = offset
		var sample_position: Vector2 = position + sample_offset
		var floor_grid_pos := Vector2i(
			int(floor(sample_position.x / block_size)),
			int(floor(sample_position.y / block_size))
		)
		if remote_grid_position_has_lava_or_fire(floor_grid_pos):
			return true

		var round_grid_pos := Vector2i(
			int(round(sample_position.x / block_size)),
			int(round(sample_position.y / block_size))
		)
		if remote_grid_position_has_lava_or_fire(round_grid_pos):
			return true

	return false


func remote_grid_position_has_water(grid_pos: Vector2i) -> bool:
	for block_type in get_remote_grid_block_types(grid_pos):
		if block_type == REMOTE_WATER_BLOCK_ID:
			return true

	return false


func remote_grid_position_has_lava_or_fire(grid_pos: Vector2i) -> bool:
	for block_type in get_remote_grid_block_types(grid_pos):
		if block_type == "lava" or block_type == "fire":
			return true
		if is_remote_lava_rebound_block_type(block_type):
			return true

	return false


func get_remote_grid_block_types(grid_pos: Vector2i) -> Array:
	var block_types: Array = []
	if world == null:
		return block_types

	for block_set in get_remote_block_sets():
		if not (block_set is Dictionary):
			continue
		if not block_set.has(grid_pos):
			continue

		var block_type := get_remote_block_type_from_data(block_set[grid_pos])
		if block_type != "":
			block_types.append(block_type)

	return block_types


func get_remote_block_sets() -> Array:
	var block_sets: Array = []
	if world == null:
		return block_sets

	var foreground_blocks = world.get("blocks")
	if foreground_blocks is Dictionary:
		block_sets.append(foreground_blocks)

	if "block_manager" in world and world.block_manager != null:
		var manager_background_blocks = world.block_manager.get("background_blocks")
		if manager_background_blocks is Dictionary:
			block_sets.append(manager_background_blocks)

	var legacy_background_blocks = world.get("background_blocks")
	if legacy_background_blocks is Dictionary:
		block_sets.append(legacy_background_blocks)

	return block_sets


func get_remote_block_type_from_data(block_data) -> String:
	if block_data is Dictionary:
		return str(block_data.get("type", "")).strip_edges().to_lower()

	return str(block_data).strip_edges().to_lower()


func is_remote_lava_rebound_block_type(block_type: String) -> bool:
	if world == null or block_type == "":
		return false

	var item_database = world.get("item_database")
	if not (item_database is Dictionary) or not item_database.has(block_type):
		return false

	var item_data = item_database[block_type]
	if not (item_data is Dictionary):
		return false

	return bool(item_data.get("lava_rebound", false))


func should_play_remote_jump_sound(previous_remote_animation_state: String, animation_state: String, had_position: bool) -> bool:
	if not had_position:
		return false
	if animation_state != "jump":
		return false
	return previous_remote_animation_state != "jump"


func should_play_remote_water_jump_sound(position: Vector2, facing: int, network_in_water: bool) -> bool:
	if network_in_water:
		return true
	return is_remote_position_on_water(position) or is_remote_position_underwater_for_bubbles(position, facing)


func play_remote_jump_sound(position: Vector2, facing: int, network_in_water: bool):
	if world == null:
		return

	if should_play_remote_water_jump_sound(position, facing, network_in_water) and world.has_method("play_sound_water_jump"):
		world.play_sound_water_jump(position)
		return

	if world.has_method("play_sound_jump"):
		world.play_sound_jump(position)


func get_remote_fishing_target_position(remote_player) -> Vector2:
	var target_grid = remote_player.get_meta("fishing_target_grid", Vector2i(-1, -1))
	if not (target_grid is Vector2i):
		return Vector2.ZERO

	var block_size := get_remote_world_block_size()
	return Vector2(float(target_grid.x) * block_size, float(target_grid.y) * block_size)


func get_remote_fishing_bobber(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return null

	var bobber = remote_player.get_meta("remote_fishing_bobber", null)
	if bobber != null and is_instance_valid(bobber):
		return bobber

	if world == null or not ResourceLoader.exists(REMOTE_FISHING_BOBBER_SCENE_PATH):
		return null

	var scene = load(REMOTE_FISHING_BOBBER_SCENE_PATH)
	if scene == null:
		return null

	bobber = scene.instantiate()
	bobber.name = "RemoteFishingBobber_" + str(remote_player.get_meta("remote_id", "")).substr(0, 8)
	if bobber is CanvasItem:
		bobber.z_as_relative = false
		bobber.z_index = int(remote_player.z_index) + REMOTE_FISHING_BOBBER_Z_OFFSET
	world.add_child(bobber)
	remote_player.set_meta("remote_fishing_bobber", bobber)
	play_remote_fishing_bobber_animation(bobber, "cast")
	return bobber


func play_remote_fishing_bobber_animation(bobber, animation_name: String):
	if bobber == null or not is_instance_valid(bobber):
		return
	var animation_player = bobber.get_node_or_null("AnimationPlayer")
	if animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)


func update_remote_fishing_visual(remote_player, delta: float):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	if not bool(remote_player.get_meta("fishing_active", false)):
		clear_remote_fishing_visual(remote_player)
		return

	var bobber = get_remote_fishing_bobber(remote_player)
	if bobber == null or not is_instance_valid(bobber):
		return

	bobber.global_position = get_remote_fishing_target_position(remote_player)
	var animation_player = bobber.get_node_or_null("AnimationPlayer")
	if animation_player != null and not animation_player.is_playing() and animation_player.has_animation("idle_float"):
		animation_player.play("idle_float")

	var line = bobber.get_node_or_null("FishingLine")
	if line == null or not (line is Line2D):
		return

	var line_end = bobber.get_node_or_null("Sprite2D/FishingLineEnd")
	if line_end == null:
		line_end = bobber.get_node_or_null("FishingLineEnd")

	var start_global_position = get_remote_fishing_line_start_global_position(remote_player)
	if start_global_position == null or line_end == null or not is_instance_valid(line_end):
		line.visible = false
		return

	var phase := float(remote_player.get_meta("remote_fishing_line_phase", 0.0))
	if delta > 0.0:
		phase = wrapf(phase + delta * REMOTE_FISHING_LINE_WAVE_SPEED, 0.0, PI * 2.0)
		remote_player.set_meta("remote_fishing_line_phase", phase)

	line.visible = true
	var start_pos: Vector2 = line.to_local(start_global_position)
	var end_pos: Vector2 = line.to_local(line_end.global_position)
	line.points = get_remote_wavy_fishing_line_points(start_pos, end_pos, phase)


func get_remote_fishing_line_start_global_position(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return null

	var rod_id := str(remote_player.get_meta("fishing_rod_id", "")).strip_edges()
	if rod_id != "":
		for marker_path in [
			"PlayerVisual/HandItem/FishingLineStart_" + rod_id,
			"PlayerVisual/HandItem/HandItemAnimated/FishingLineStart_" + rod_id
		]:
			var rod_marker = remote_player.get_node_or_null(marker_path)
			if rod_marker is Node2D:
				return rod_marker.global_position

	for marker_path in [
		"PlayerVisual/HandItem/FishingLineStart",
		"PlayerVisual/HandItem/HandItemAnimated/FishingLineStart",
		"PlayerVisual/HandItem/PlatinumPrestigeRod/FishingLineStart"
	]:
		var marker = remote_player.get_node_or_null(marker_path)
		if marker is Node2D:
			return marker.global_position

	var hand_item = remote_player.get_node_or_null("PlayerVisual/HandItem")
	if hand_item != null:
		var found_marker = hand_item.find_child("FishingLineStart", true, false)
		if found_marker is Node2D:
			return found_marker.global_position

	var hand_sprite = remote_player.get_node_or_null("PlayerVisual/HandItem/HandItemAnimated")
	if hand_sprite is Node2D:
		var rod_data = get_remote_item_data(rod_id)
		if rod_data.has("fishing_line_tip_offset"):
			return hand_sprite.to_global(get_remote_vector_from_data(rod_data.get("fishing_line_tip_offset", Vector2.ZERO), Vector2.ZERO))

	return remote_player.global_position + Vector2(10.0 * float(int(remote_player.get_meta("facing", 1))), -10.0)


func get_remote_wavy_fishing_line_points(start_pos: Vector2, end_pos: Vector2, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var line_delta: Vector2 = end_pos - start_pos
	var line_length: float = line_delta.length()

	if line_length <= 0.1:
		points.append(start_pos)
		points.append(end_pos)
		return points

	var normal := Vector2(-line_delta.y, line_delta.x).normalized()
	var sag_scale: float = clamp(line_length / 240.0, 0.35, 1.4)

	for i in range(REMOTE_FISHING_LINE_SEGMENTS + 1):
		var t: float = float(i) / float(REMOTE_FISHING_LINE_SEGMENTS)
		var fade: float = sin(t * PI)
		var sag: Vector2 = Vector2.DOWN * REMOTE_FISHING_LINE_SAG * sag_scale * fade
		var wave: Vector2 = normal * sin((t * REMOTE_FISHING_LINE_WAVE_FREQUENCY * PI * 2.0) + phase) * REMOTE_FISHING_LINE_WAVE_AMPLITUDE * fade
		points.append(start_pos.lerp(end_pos, t) + sag + wave)

	return points


func clear_remote_fishing_visual(remote_player):
	if remote_player == null:
		return

	var bobber = null
	if remote_player.has_meta("remote_fishing_bobber"):
		bobber = remote_player.get_meta("remote_fishing_bobber")
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()
	remote_player.set_meta("remote_fishing_bobber", null)
	remote_player.set_meta("remote_fishing_line_phase", 0.0)


func get_remote_world_block_size() -> float:
	var block_size := 32.0
	if world == null:
		return block_size

	var world_block_size = world.get("BLOCK_SIZE")
	if world_block_size is int or world_block_size is float:
		block_size = float(world_block_size)

	return block_size


func update_multiplayer_movement(delta: float, from_physics_step: bool = false):
	if not MovementMode.is_websocket():
		return

	if world == null:
		return

	if not world.in_world:
		return

	if world.player == null:
		return
	if is_world_entry_position_sync_blocked():
		return

	# Device-dependent jitter fix:
	# Local player movement is produced in _physics_process(), but the world
	# wrapper may still call this from _process(). Once the player script marks
	# physics-based sync as active, ignore render-frame calls so outgoing
	# packets are sampled right after move_and_slide() on every device.
	if not from_physics_step and bool(world.player.get_meta("multiplayer_movement_sync_from_physics", false)):
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
	var current_motion_state := {}
	if network.has_method("get_player_motion_state"):
		current_motion_state = network.get_player_motion_state()
	var current_animation_state = str(current_motion_state.get("animation_state", ""))
	if network.has_method("get_player_animation_state"):
		if current_animation_state == "":
			current_animation_state = str(network.get_player_animation_state())
	var animation_changed = current_animation_state != "" and current_animation_state != last_sent_network_animation_state
	var current_lava_fire_state := bool(current_motion_state.get("in_lava_fire", false))
	var lava_fire_changed: bool = current_lava_fire_state != last_sent_network_lava_fire_state
	var current_facing: int = -1 if int(world.player_facing_direction) < 0 else 1
	var facing_changed: bool = current_facing != last_sent_network_facing
	var current_fishing_key := get_local_fishing_sync_key()
	var fishing_changed: bool = current_fishing_key != last_sent_network_fishing_key
	var current_damage_key := get_local_damage_flash_sync_key()
	var damage_changed: bool = current_damage_key != last_sent_network_damage_key

	if not moved_enough and not should_send_heartbeat and not animation_changed and not lava_fire_changed and not facing_changed and not fishing_changed and not damage_changed:
		return

	var sent := bool(network.send_player_position(current_position, current_facing, world.current_world_name, true))

	if sent:
		network_position_timer = get_network_position_send_interval()
		network_heartbeat_timer = get_network_position_heartbeat_interval()
		last_sent_network_position = current_position
		last_sent_network_animation_state = current_animation_state
		last_sent_network_lava_fire_state = current_lava_fire_state
		last_sent_network_facing = current_facing
		last_sent_network_fishing_key = current_fishing_key
		last_sent_network_damage_key = current_damage_key


func flush_multiplayer_position(allow_join: bool = false, bypass_rate_limit: bool = false) -> bool:
	if not MovementMode.is_websocket():
		return false

	if world == null:
		return false

	if not world.in_world:
		return false

	if world.player == null:
		return false
	if is_world_entry_position_sync_blocked():
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("send_player_position"):
		return false

	var current_position = world.player.global_position
	var current_facing: int = -1 if int(world.player_facing_direction) < 0 else 1
	if bypass_rate_limit and is_multiplayer_position_flush_redundant(network, current_position, current_facing):
		debug_action_position_flow("flush_multiplayer_position skipped duplicate allow_join=" + str(allow_join))
		return true

	debug_action_position_flow("flush_multiplayer_position allow_join=" + str(allow_join) + " bypass_rate_limit=" + str(bypass_rate_limit))
	var sent := bool(network.send_player_position(current_position, current_facing, world.current_world_name, allow_join, bypass_rate_limit))
	if sent:
		network_position_timer = get_network_position_send_interval()
		network_heartbeat_timer = get_network_position_heartbeat_interval()
		last_sent_network_position = current_position
		last_sent_network_facing = current_facing
		if network.has_method("get_player_animation_state"):
			last_sent_network_animation_state = str(network.get_player_animation_state())
		if network.has_method("get_player_motion_state"):
			last_sent_network_lava_fire_state = bool(network.get_player_motion_state().get("in_lava_fire", false))
		last_sent_network_fishing_key = get_local_fishing_sync_key()
		last_sent_network_damage_key = get_local_damage_flash_sync_key()

	return sent


func is_world_entry_position_sync_blocked() -> bool:
	if world == null:
		return true
	if bool(world.get_meta("world_entry_in_progress", false)):
		return true
	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		return true
	if "applying_network_world_update" in world and bool(world.applying_network_world_update):
		return true
	var save_manager = world.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager:
		return bool(save_manager.waiting_for_server_world_state)
	return false


func get_safe_remote_render_position(current_position: Vector2, proposed_position: Vector2) -> Vector2:
	if current_position.distance_squared_to(proposed_position) <= 0.01:
		return proposed_position
	if is_remote_punch_visual_position_blocked(current_position) and not is_remote_punch_visual_position_blocked(proposed_position):
		return proposed_position

	var path := proposed_position - current_position
	var step_size := maxf(2.0, get_remote_world_block_size() * 0.25)
	var steps := maxi(1, int(ceil(path.length() / step_size)))
	var safe_position := current_position
	for index in range(1, steps + 1):
		var candidate := current_position + path * (float(index) / float(steps))
		if is_remote_punch_visual_position_blocked(candidate):
			break
		safe_position = candidate
	return safe_position


func get_remote_grid_for_centered_world_point(world_position: Vector2, block_size: float) -> Vector2i:
	var safe_block_size := maxf(1.0, block_size)
	var half_block_size := safe_block_size * 0.5
	return Vector2i(
		int(floor((world_position.x + half_block_size) / safe_block_size)),
		int(floor((world_position.y + half_block_size) / safe_block_size))
	)


func is_multiplayer_position_flush_redundant(network: Node, current_position: Vector2, current_facing: int) -> bool:
	if current_position.distance_to(last_sent_network_position) >= NETWORK_POSITION_FLUSH_MIN_DISTANCE:
		return false
	if current_facing != last_sent_network_facing:
		return false

	var current_animation_state: String = ""
	if network != null and network.has_method("get_player_animation_state"):
		current_animation_state = str(network.get_player_animation_state())
	if current_animation_state != "" and current_animation_state != last_sent_network_animation_state:
		return false

	var current_lava_fire_state: bool = last_sent_network_lava_fire_state
	if network != null and network.has_method("get_player_motion_state"):
		current_lava_fire_state = bool(network.get_player_motion_state().get("in_lava_fire", false))
	if current_lava_fire_state != last_sent_network_lava_fire_state:
		return false

	if get_local_fishing_sync_key() != last_sent_network_fishing_key:
		return false
	if get_local_damage_flash_sync_key() != last_sent_network_damage_key:
		return false

	return true


func get_network_position_heartbeat_interval() -> float:
	if world == null:
		return NETWORK_POSITION_HEARTBEAT_INTERVAL

	var network = world.get_node_or_null("/root/NetworkManager")
	var world_name := "START"
	var other_player_count := 0

	if "current_world_name" in world:
		world_name = str(world.current_world_name).strip_edges().to_upper()
		if world_name == "":
			world_name = "START"

	if network != null and network.has_method("get_world_other_player_count"):
		other_player_count = int(network.get_world_other_player_count(world_name))
	if network != null and network.has_method("get_server_guided_position_heartbeat_ms"):
		var guided_ms := float(network.get_server_guided_position_heartbeat_ms(world_name))
		if guided_ms > 0.0:
			return clamp(guided_ms / 1000.0, float(NETWORK_POSITION_HEARTBEAT_INTERVAL), float(NETWORK_POSITION_HEARTBEAT_MAX_SECONDS))

	var multiplier := NETWORK_POSITION_HEARTBEAT_CROWDED_OTHER_MULTIPLIER
	if other_player_count <= 0:
		multiplier = NETWORK_POSITION_HEARTBEAT_NO_OTHER_MULTIPLIER
	elif other_player_count <= 4:
		multiplier = NETWORK_POSITION_HEARTBEAT_FEW_OTHER_MULTIPLIER

	return clamp(
		float(NETWORK_POSITION_HEARTBEAT_INTERVAL) * multiplier,
		float(NETWORK_POSITION_HEARTBEAT_INTERVAL),
		float(NETWORK_POSITION_HEARTBEAT_MAX_SECONDS)
	)

func get_network_position_send_interval() -> float:
	if world == null:
		return NETWORK_POSITION_SEND_INTERVAL

	var network = world.get_node_or_null("/root/NetworkManager")
	var world_name := "START"

	if "current_world_name" in world:
		world_name = str(world.current_world_name).strip_edges().to_upper()
		if world_name == "":
			world_name = "START"

	if network != null and network.has_method("get_server_guided_position_broadcast_ms"):
		var broadcast_ms := float(network.get_server_guided_position_broadcast_ms(world_name))
		if broadcast_ms > 0.0:
			return clamp(
				broadcast_ms / 1000.0,
				float(NETWORK_POSITION_SEND_INTERVAL),
				float(NETWORK_POSITION_SEND_INTERVAL_MAX_SECONDS)
			)

	return NETWORK_POSITION_SEND_INTERVAL


func get_local_damage_flash_sync_key() -> String:
	if world == null or world.player == null:
		return "0"

	var token := int(world.player.get_meta("hurt_modulate_sequence_id", 0))
	var hurt_until_msec := int(world.player.get_meta("face_hurt_until_msec", 0))
	var active := hurt_until_msec > Time.get_ticks_msec()
	return ("1:" if active else "0:") + str(token)


func get_local_fishing_sync_key() -> String:
	if world == null:
		return "0"
	if not ("fishing_active" in world) or not bool(world.get("fishing_active")):
		return "0"

	var target_grid = world.get("fishing_target_grid") if "fishing_target_grid" in world else null
	if not (target_grid is Vector2i):
		return "0"

	var lure_id: String = str(world.get("fishing_lure_id")) if "fishing_lure_id" in world else ""
	var rod_id := ""
	if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_line_rod_id"):
		rod_id = str(world.fishing_manager.get_fishing_line_rod_id())
	return "1:" + str(target_grid.x) + ":" + str(target_grid.y) + ":" + lure_id + ":" + rod_id


func _safe_remote_world_name(raw_world) -> String:
	var world_text = str(raw_world).strip_edges()
	if world_text == "":
		return ""
	return world_text.to_upper()


func _get_pending_remote_position_snapshot(remote_id: String, remote_world: String) -> Dictionary:
	if remote_id == "":
		return {}
	if not remote_pending_position_snapshots.has(remote_id):
		return {}
	var snapshot_entry = remote_pending_position_snapshots.get(remote_id, {})
	if not (snapshot_entry is Dictionary):
		remote_pending_position_snapshots.erase(remote_id)
		return {}

	var snapshot_world = _safe_remote_world_name(snapshot_entry.get("world", ""))
	var snapshot_generation = int(snapshot_entry.get("snapshot_generation", 0))
	var queued_msec = int(snapshot_entry.get("queued_msec", 0))
	if snapshot_generation != remote_position_snapshot_generation:
		remote_pending_position_snapshots.erase(remote_id)
		return {}
	if snapshot_world != _safe_remote_world_name(remote_world):
		remote_pending_position_snapshots.erase(remote_id)
		return {}
	if queued_msec > 0 and REMOTE_PENDING_POSITION_SNAPSHOT_MAX_AGE_MS > 0:
		if Time.get_ticks_msec() - queued_msec > REMOTE_PENDING_POSITION_SNAPSHOT_MAX_AGE_MS:
			remote_pending_position_snapshots.erase(remote_id)
			return {}

	var payload = snapshot_entry.get("payload", {})
	if not (payload is Dictionary):
		remote_pending_position_snapshots.erase(remote_id)
		return {}
	remote_pending_position_snapshots.erase(remote_id)
	return payload.duplicate(true)


func _set_pending_remote_position_snapshot(remote_id: String, remote_world: String, payload: Dictionary) -> void:
	if remote_id == "" or not (payload is Dictionary):
		return
	var clean_world = _safe_remote_world_name(remote_world)
	if clean_world == "":
		return

	var existing_entry = remote_pending_position_snapshots.get(remote_id, {})
	if existing_entry is Dictionary:
		var existing_payload = existing_entry.get("payload", {})
		if existing_payload is Dictionary and not _is_remote_snapshot_payload_newer(payload, existing_payload):
			return

	var snapshot_entry := {
		"world": clean_world,
		"snapshot_generation": remote_position_snapshot_generation,
		"queued_msec": Time.get_ticks_msec(),
		"payload": payload.duplicate(true)
	}
	remote_pending_position_snapshots[remote_id] = snapshot_entry

	while remote_pending_position_snapshots.size() > REMOTE_PENDING_POSITION_SNAPSHOT_MAX_ENTRIES and remote_pending_position_snapshots.size() > 0:
		var keys = remote_pending_position_snapshots.keys()
		if keys.size() <= 0:
			break
		var oldest_id = keys[0]
		var oldest_msec = int(snapshot_entry.get("queued_msec", Time.get_ticks_msec()))
		for candidate_id in keys:
			var candidate_entry = remote_pending_position_snapshots.get(candidate_id, {})
			if not (candidate_entry is Dictionary):
				remote_pending_position_snapshots.erase(candidate_id)
				continue
			var candidate_msec = int(candidate_entry.get("queued_msec", 0))
			if candidate_msec < oldest_msec:
				oldest_msec = candidate_msec
				oldest_id = candidate_id
		remote_pending_position_snapshots.erase(oldest_id)

func handle_network_existing_players(players_data):
	if not MovementMode.is_websocket():
		return

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
	if not MovementMode.is_websocket():
		return

	setup_remote_players_root()

	var remote_id = str(player_data.get("player_id", ""))
	if remote_id == "":
		return

	var local_world: String = ""
	if world != null and "current_world_name" in world:
		local_world = _safe_remote_world_name(world.current_world_name)
	if local_world == "":
		local_world = "START"

	var remote_world = _safe_remote_world_name(player_data.get("world", local_world))
	if remote_world == "":
		remote_world = local_world
	if remote_world != local_world:
		remove_remote_player(remote_id)
		return

	var remote_name = get_remote_player_name_from_payload(player_data)
	var remote_identity = get_remote_player_identity_from_payload(player_data)
	remove_duplicate_remote_players_for_identity(remote_identity, remote_id)
	var remote_role = clean_remote_player_role(str(player_data.get("role", "player")))

	var remote_player = get_or_create_remote_player(remote_id, remote_name, remote_world)
	if remote_player == null:
		_set_pending_remote_position_snapshot(remote_id, remote_world, player_data)
		return
	var is_join_event: bool = str(player_data.get("type", "")).strip_edges().to_lower() == "player_joined"
	var position_reason := str(player_data.get("position_reason", player_data.get("reason", ""))).strip_edges().to_lower()
	var is_direct_root_correction := is_join_event \
		or bool(player_data.get("respawn_teleport", false)) \
		or bool(player_data.get("teleport", false)) \
		or bool(player_data.get("force_player_position", false)) \
		or ["respawn", "teleport", "world_join", "join_world", "door_enter"].has(position_reason)
	var previous_remote_snapshot_msec := int(remote_player.get_meta("remote_snapshot_timestamp_msec", 0))
	var movement_sequence := _extract_remote_movement_sequence(player_data)
	var previous_movement_sequence := int(remote_player.get_meta("remote_movement_sequence", 0))
	if not is_join_event and not is_direct_root_correction and movement_sequence > 0 and previous_movement_sequence > 0 and not _is_remote_movement_sequence_newer(movement_sequence, previous_movement_sequence):
		_log_remote_movement_drop(remote_player, "stale_sequence", {
			"remote_id": remote_id,
			"incoming_sequence": movement_sequence,
			"previous_sequence": previous_movement_sequence,
			"world": remote_world,
		})
		return
	var receive_msec := int(Time.get_ticks_msec())
	var snapshot_time_msec := _extract_remote_snapshot_time_msec(player_data, receive_msec)
	if snapshot_time_msec <= 0:
		snapshot_time_msec = max(receive_msec, previous_remote_snapshot_msec + 1)
	if not is_direct_root_correction and movement_sequence <= 0 and previous_remote_snapshot_msec > 0 and snapshot_time_msec <= previous_remote_snapshot_msec:
		_log_remote_movement_drop(remote_player, "stale_snapshot_time", {
			"remote_id": remote_id,
			"incoming_snapshot_time_msec": snapshot_time_msec,
			"previous_snapshot_time_msec": previous_remote_snapshot_msec,
			"world": remote_world,
		})
		return
	var snapshot_interval_msec := 0
	if previous_remote_snapshot_msec > 0:
		snapshot_interval_msec = snapshot_time_msec - previous_remote_snapshot_msec
		if snapshot_interval_msec <= 0:
			snapshot_interval_msec = int(REMOTE_SNAPSHOT_INTERVAL_MIN_MS)
		else:
			snapshot_interval_msec = int(clampf(float(snapshot_interval_msec), REMOTE_SNAPSHOT_INTERVAL_MIN_MS, REMOTE_SNAPSHOT_INTERVAL_MAX_MS))
	var snapshot_intervals = remote_player.get_meta("remote_snapshot_intervals", [])
	if not (snapshot_intervals is Array):
		snapshot_intervals = []
	snapshot_intervals.append(snapshot_interval_msec)
	while snapshot_intervals.size() > 5:
		snapshot_intervals.pop_front()
	remote_player.set_meta("remote_snapshot_intervals", snapshot_intervals)
	var new_target = Vector2(
		_safe_float(player_data.get("x", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD),
		_safe_float(player_data.get("y", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD)
	)
	var had_position = bool(remote_player.get_meta("has_position", false))
	var old_target_value = remote_player.get_meta("target_position", remote_player.global_position)
	var old_target: Vector2 = remote_player.global_position
	if old_target_value is Vector2:
		old_target = old_target_value
	var network_velocity_x = _safe_float(player_data.get("velocity_x", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD)
	var network_velocity_y = _safe_float(player_data.get("velocity_y", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD)
	var network_on_floor = bool(player_data.get("on_floor", true))
	var remote_chat_typing_payload = player_data.get("chat_typing", false)
	var remote_chat_typing = remote_chat_typing_payload is bool and remote_chat_typing_payload
	var next_target_position: Vector2 = new_target
	var target_delta: float = old_target.distance_to(next_target_position)
	var target_speed_hint: float = target_delta / max(NETWORK_POSITION_SEND_INTERVAL, 0.001)
	var has_network_velocity: bool = player_data.has("velocity_x") or player_data.has("velocity_y")
	var snapshot_velocity := Vector2(network_velocity_x, network_velocity_y)
	if not has_network_velocity and had_position:
		var snapshot_delta_time := maxf(float(receive_msec - int(remote_player.get_meta("remote_last_receive_msec", receive_msec - 1))) / 1000.0, 0.001)
		snapshot_velocity = (next_target_position - old_target) / snapshot_delta_time
	var speed_hint: float = abs(snapshot_velocity.x) if has_network_velocity else target_speed_hint
	var vertical_hint: float = float(next_target_position.y - old_target.y) / max(NETWORK_POSITION_SEND_INTERVAL, 0.001)
	var animation_state = clean_remote_animation_state(str(player_data.get("animation_state", "")))
	var now_msec := int(Time.get_ticks_msec())
	var previous_animation_state_from_meta = str(remote_player.get_meta("animation_state", "idle"))
	var hurt_animation_until := int(remote_player.get_meta("remote_hurt_animation_until_msec", 0))
	var action_animation_until := int(remote_player.get_meta("remote_action_animation_until_msec", 0))
	if now_msec < hurt_animation_until:
		animation_state = "hurt"
	elif now_msec < action_animation_until:
		var remote_action_animation_state := clean_remote_animation_state(str(remote_player.get_meta("remote_action_animation_state", "")))
		if remote_action_animation_state == "punch" or remote_action_animation_state == "place_animation":
			animation_state = remote_action_animation_state
	var has_authoritative_animation_state = animation_state != ""
	var facing_raw = _safe_int(player_data.get("facing", 1), 1, -1, 1)
	var safe_facing = 1 if facing_raw >= 0 else -1
	var network_in_water = bool(player_data.get("in_water", false))
	var network_in_lava_fire = bool(player_data.get("in_lava_fire", false))
	var has_damage_flash_payload := player_data.has("damage_flash_active")
	var damage_flash_active: bool = bool(player_data.get("damage_flash_active", animation_state == "hurt"))
	var damage_flash_remaining_msec: int = _safe_int(player_data.get("damage_flash_remaining_ms", HURT_FACE_EXPRESSION_TIME_MSEC if animation_state == "hurt" else 0), 0, 0, HURT_FACE_EXPRESSION_TIME_MSEC)
	var damage_flash_token := _safe_int(player_data.get("damage_flash_token", 0), 0, 0, 2147483647)
	var remote_fishing_active := bool(player_data.get("fishing_active", false))
	var remote_fishing_target := Vector2i(
		_safe_int(player_data.get("fishing_target_x", -1), -1, -1, 1000000),
		_safe_int(player_data.get("fishing_target_y", -1), -1, -1, 1000000)
	)

	if has_authoritative_animation_state:
		if animation_state in ["punch", "place_animation", "hurt", "dead", "dead_spirit"]:
			pass
		elif animation_state == "walk":
			if has_network_velocity and network_on_floor and abs(network_velocity_x) <= REMOTE_WALK_SPEED_THRESHOLD:
				animation_state = "idle"
			elif not network_on_floor:
				animation_state = "fall" if network_velocity_y > REMOTE_JUMP_SPEED_THRESHOLD else "jump"
			elif abs(network_velocity_x) > REMOTE_WALK_SPEED_THRESHOLD:
				animation_state = "walk"
			else:
				animation_state = "idle"
		elif animation_state in ["jump", "fall"] and network_on_floor:
			animation_state = "walk" if abs(network_velocity_x) > REMOTE_WALK_SPEED_THRESHOLD else "idle"
		elif not network_on_floor:
			animation_state = "fall" if network_velocity_y > REMOTE_JUMP_SPEED_THRESHOLD else "jump"
		elif abs(network_velocity_x) > REMOTE_WALK_SPEED_THRESHOLD:
			animation_state = "walk"
		else:
			animation_state = "idle"
	elif has_network_velocity:
		if not network_on_floor:
			animation_state = "fall" if network_velocity_y > REMOTE_JUMP_SPEED_THRESHOLD else "jump"
		elif abs(network_velocity_x) > REMOTE_WALK_SPEED_THRESHOLD:
			animation_state = "walk"
		else:
			animation_state = "idle"
	else:
		if not network_on_floor:
			animation_state = "fall" if network_velocity_y > REMOTE_JUMP_SPEED_THRESHOLD else "jump"
		elif had_position and abs(vertical_hint) > 70.0:
			animation_state = "jump"
		elif target_delta >= REMOTE_POSITION_WALK_MIN_DISTANCE and target_speed_hint > REMOTE_WALK_SPEED_THRESHOLD:
			animation_state = "walk"
		else:
			animation_state = "idle"

	var airborne_stale_msec = int(remote_player.get_meta("remote_airborne_stale_msec", 0))
	if animation_state in ["jump", "fall"] and previous_animation_state_from_meta in ["jump", "fall"] and not network_on_floor:
		var vertical_delta := next_target_position.y - old_target.y
		if abs(network_velocity_y) <= REMOTE_AIRBORNE_STALE_EPS_VELOCITY and abs(vertical_delta) <= REMOTE_AIRBORNE_STALE_DISTANCE:
			airborne_stale_msec = now_msec if airborne_stale_msec <= 0 else max(airborne_stale_msec, now_msec)
		else:
			airborne_stale_msec = 0
		if airborne_stale_msec > 0 and now_msec - airborne_stale_msec >= int(REMOTE_AIRBORNE_STALE_TIMEOUT_MS):
			animation_state = "walk" if abs(network_velocity_x) > REMOTE_WALK_SPEED_THRESHOLD else "idle"
			airborne_stale_msec = 0
		remote_player.set_meta("remote_airborne_stale_msec", airborne_stale_msec)
	else:
		remote_player.set_meta("remote_airborne_stale_msec", 0)

	var visual_speed_hint = 0.0 if animation_state == "idle" else speed_hint

	var should_snap_remote_position := false
	if not had_position:
		remote_player.set_meta("has_position", true)
		should_snap_remote_position = true
	elif is_direct_root_correction:
		should_snap_remote_position = true
	elif target_delta >= REMOTE_POSITION_SNAP_DISTANCE:
		# Large gaps are normally teleports/respawns/world joins, not normal walking.
		# Snap these so remote players do not slide across the map.
		should_snap_remote_position = true

	if previous_animation_state_from_meta != animation_state:
		if should_play_remote_jump_sound(previous_animation_state_from_meta, animation_state, had_position):
			play_remote_jump_sound(next_target_position, safe_facing, network_in_water)
		remote_player.set_meta("walk_timer", 0.0)
		remote_player.set_meta("walk_frame", 0)
		remote_player.set_meta("idle_timer", 0.0)
		remote_player.set_meta("idle_frame", 0)
		remote_player.set_meta("animation_phase", 0.0)
		debug_remote_appearance_flow("remote animation state changed", {
			"player_id": remote_id,
			"username": remote_name,
			"from": previous_animation_state_from_meta,
			"to": animation_state,
			"facing": player_data.get("facing", 1)
		})

	remote_player.set_meta("target_position", next_target_position)
	if should_snap_remote_position:
		reset_remote_position_snapshot_buffer(remote_player, snapshot_time_msec, receive_msec, movement_sequence, next_target_position, snapshot_velocity)
		remote_player.set_meta("smoothed_position", next_target_position)
		remote_player.global_position = next_target_position
	else:
		if not append_remote_position_snapshot(remote_player, snapshot_time_msec, receive_msec, movement_sequence, next_target_position, snapshot_velocity):
			return
	remote_player.set_meta("authoritative_position", next_target_position)
	remote_player.set_meta("remote_last_position_msec", snapshot_time_msec)
	remote_player.set_meta("remote_last_receive_msec", receive_msec)
	remote_player.set_meta("remote_snapshot_timestamp_msec", snapshot_time_msec)
	remote_player.set_meta("remote_speed", visual_speed_hint)
	remote_player.set_meta("remote_velocity_y", vertical_hint)
	remote_player.set_meta("network_velocity_x", network_velocity_x)
	remote_player.set_meta("network_velocity_y", network_velocity_y)
	remote_player.set_meta("network_on_floor", network_on_floor)
	remote_player.set_meta("animation_state", animation_state)
	remote_player.set_meta("remote_chat_typing", remote_chat_typing)
	remote_player.set_meta("network_in_lava_fire", network_in_lava_fire)
	remote_player.set_meta("remote_debug_version", MovementMode.get_websocket_movement_version())
	remote_player.set_meta("remote_latest_snapshot_position", next_target_position)
	remote_player.set_meta("remote_last_snapshot_msec", snapshot_time_msec)
	remote_player.set_meta("remote_movement_sequence", movement_sequence)
	var remote_visual_active := is_world_position_visible(next_target_position, get_visible_world_rect(REMOTE_PLAYER_VISIBILITY_MARGIN_SCREEN_PX))
	set_remote_player_visual_active(remote_player, remote_visual_active)
	if remote_visual_active:
		ensure_remote_player_shared_visual_pipeline(remote_player)
	if has_damage_flash_payload or animation_state == "hurt":
		update_remote_damage_flash(remote_player, damage_flash_active, damage_flash_remaining_msec, damage_flash_token)
	remote_player.set_meta("fishing_active", remote_fishing_active)
	remote_player.set_meta("fishing_target_grid", remote_fishing_target)
	remote_player.set_meta("fishing_lure_id", str(player_data.get("fishing_lure_id", "")))
	remote_player.set_meta("fishing_rod_id", str(player_data.get("fishing_rod_id", "")))
	remote_player.set_meta("facing", safe_facing)
	if remote_visual_active:
		update_remote_water_splash(remote_player, next_target_position, had_position, network_velocity_x, network_velocity_y, target_speed_hint)
		update_remote_underwater_bubbles(remote_player, next_target_position)
		update_remote_lava_fire_particles(remote_player, next_target_position, network_in_lava_fire)
	else:
		clear_remote_fishing_visual(remote_player)
	remote_player.set_meta("remote_name", remote_name)
	remote_player.set_meta("remote_identity", remote_identity)
	remote_player.set_meta("remote_role", remote_role)
	remote_player.set_meta("stale_time", 0.0)
	remote_player.set_meta("remote_stale_warning_emitted", false)

	var equipment_slots = {}
	if player_data.has("equipment_slots") and player_data.get("equipment_slots") is Dictionary:
		equipment_slots = normalize_remote_equipment_slots(player_data.get("equipment_slots"))
	else:
		equipment_slots = normalize_remote_equipment_slots({
			"hand": str(player_data.get("equipped_tool", "")),
			"back": str(player_data.get("equipped_back_item", player_data.get("equipped_back", ""))),
			"hat": str(player_data.get("equipped_hat_item", "")),
			"hair": str(player_data.get("equipped_hair_item", "")),
			"eyewear": str(player_data.get("equipped_eyewear_item", "")),
			"beard": str(player_data.get("equipped_beard_item", "")),
			"body_accessory": str(player_data.get("equipped_body_accessory_item", "")),
			"shirt": str(player_data.get("equipped_shirt_item", "")),
			"pants": str(player_data.get("equipped_pants_item", "")),
			"shoes": str(player_data.get("equipped_shoes_item", "")),
			"ride": str(player_data.get("equipped_ride_item", ""))
		})

	var previous_equipment_key = str(remote_player.get_meta("equipment_slots_debug_key", ""))
	var next_equipment_key = get_equipment_slots_debug_key(equipment_slots)
	remote_player.set_meta("equipment_slots", equipment_slots)
	remote_player.set_meta("equipment_slots_debug_key", next_equipment_key)
	if previous_equipment_key != next_equipment_key:
		debug_remote_appearance_flow("received remote appearance update", {
			"player_id": remote_id,
			"username": remote_name,
			"equipment_slots": equipment_slots
		})

	if remote_visual_active:
		maybe_spawn_remote_ant_sword_punch_slash(remote_player, previous_animation_state_from_meta, animation_state)

	if remote_visual_active:
		update_remote_player_name(remote_player, remote_name)
		update_remote_player_facing(remote_player)
		update_remote_shared_player_animation(remote_player, 0.0)
		update_remote_equipment_visuals(remote_player)
		update_remote_fishing_visual(remote_player, 0.0)
		queue_remote_visual_stabilization(remote_player)
		remote_player.set_meta("pending_visual_refresh", false)
	else:
		remote_player.set_meta("pending_visual_refresh", true)
	if not bool(remote_player.get_meta("world_enter_fade_played", false)):
		remote_player.set_meta("world_enter_fade_played", true)
		if remote_visual_active:
			play_player_world_enter_fade(remote_player)
	if remote_visual_active and is_join_event and world != null and world.has_method("play_sound_join_world"):
		world.play_sound_join_world(next_target_position)
	if remote_visual_active:
		_drain_remote_chat_message_queue(remote_id)


func _extract_remote_snapshot_time_msec(player_data: Dictionary, fallback_msec: int) -> int:
	for key in ["server_time_msec", "server_time", "timestamp_msec", "timestamp", "packet_time", "packet_timestamp"]:
		if not player_data.has(key):
			continue
		var raw_value = player_data.get(key, fallback_msec)
		if not (raw_value is int or raw_value is float):
			if raw_value is String:
				var raw_text = raw_value.strip_edges()
				if raw_text.is_valid_float():
					return int(float(raw_text))
			continue
		var snapshot_msec := int(raw_value)
		if snapshot_msec > 0:
			return snapshot_msec
	return fallback_msec


func handle_network_player_left(remote_id: String):
	remove_remote_player(remote_id)


func clear_remote_player_ui(remote_id: String) -> void:
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

	_clear_remote_debug_label(remote_id)


func update_remote_debug_labels():
	return


func create_or_update_remote_debug_label(remote_id: String, remote_player) -> void:
	if remote_id == "" or remote_player == null or not is_instance_valid(remote_player):
		return
	var layer = get_overhead_layer()
	if world == null or layer == null:
		return

	var label = remote_debug_labels.get(remote_id, null)
	if label == null or not is_instance_valid(label):
		label = Label.new()
		label.name = "RemoteMovementDebugLabel_" + remote_id.substr(0, 8)
		label.size = Vector2(REMOTE_DEBUG_LABEL_WIDTH, REMOTE_DEBUG_LABEL_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 71
		label.add_theme_font_size_override("font_size", REMOTE_DEBUG_LABEL_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.93, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text = ""
		layer.add_child(label)
		remote_debug_labels[remote_id] = label


func _update_remote_debug_label(remote_player) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return
	var remote_id = str(remote_player.get_meta("remote_id", ""))
	if remote_id == "":
		return

	if remote_debug_labels.has(remote_id):
		var stale_debug_label = remote_debug_labels[remote_id]
		if stale_debug_label != null and is_instance_valid(stale_debug_label):
			stale_debug_label.visible = false

	if not remote_debug_labels.has(remote_id):
		create_or_update_remote_debug_label(remote_id, remote_player)
	if not remote_debug_labels.has(remote_id):
		return

	var label = remote_debug_labels[remote_id]
	if label == null or not is_instance_valid(label):
		return

	if are_remote_name_labels_hidden_by_ui() or not remote_players.has(remote_id):
		label.visible = false
		return

	if not bool(remote_player.get_meta("visible_in_camera", true)):
		label.visible = false
		return

	var rendered_position = remote_player.global_position
	var latest_position_value = remote_player.get_meta("remote_latest_snapshot_position", remote_player.global_position)
	if not (latest_position_value is Vector2):
		latest_position_value = remote_player.global_position

	var previous_snapshot_msec := int(remote_player.get_meta("remote_previous_snapshot_msec", -1))
	var next_snapshot_msec := int(remote_player.get_meta("remote_next_snapshot_msec", -1))
	var snapshot_intervals = remote_player.get_meta("remote_snapshot_intervals", [])
	var interval_count := 0
	var interval_sum := 0.0
	var interval_avg := 0.0
	var interval_abs_deviation := 0.0
	if snapshot_intervals is Array:
		for interval_value in snapshot_intervals:
			if interval_value is int or interval_value is float:
				interval_sum += float(interval_value)
				interval_count += 1
	if interval_count > 0:
		interval_avg = interval_sum / float(interval_count)
		for interval_value in snapshot_intervals:
			if interval_value is int or interval_value is float:
				interval_abs_deviation += abs(float(interval_value) - interval_avg)
		if interval_count > 1:
			interval_abs_deviation = interval_abs_deviation / float(interval_count)
	var interpolation_alpha := float(remote_player.get_meta("remote_interpolation_alpha", 0.0))
	var interpolation_progress_ms := int(remote_player.get_meta("remote_interpolation_progress_ms", 0))
	var dead_reckon_ms := int(remote_player.get_meta("remote_dead_reckon_ms", 0))
	var dead_reckon_active := bool(remote_player.get_meta("remote_dead_reckoning_active", false))
	var buffer_size := int(remote_player.get_meta("remote_buffer_size", 0))
	var version := str(remote_player.get_meta("remote_debug_version", MovementMode.get_websocket_movement_version()))

	label.text = (
		"Movement: " + version + "\n"
		+ "Remote ID: " + remote_id + "\n"
		+ "Buffer: " + str(buffer_size) + "\n"
		+ "Delay: " + str(_get_remote_interpolation_delay_ms(remote_player)) + "ms\n"
		+ "Jitter: " + str(round(interval_avg * 100.0) / 100.0) + "±" + str(round(interval_abs_deviation * 100.0) / 100.0) + "ms (" + str(interval_count) + ")\n"
		+ "Prev: " + str(previous_snapshot_msec) + "\n"
		+ "Next: " + str(next_snapshot_msec) + "\n"
		+ "Alpha: " + str(round(interpolation_alpha * 100.0) / 100.0) + "\n"
		+ "Rendered Position: " + _format_remote_debug_position(rendered_position) + "\n"
		+ "Latest Position: " + _format_remote_debug_position(latest_position_value) + "\n"
		+ "Interpolation Progress: " + str(interpolation_progress_ms) + "ms\n"
		+ "Dead Reckon: " + str(dead_reckon_active) + " (" + str(dead_reckon_ms) + "ms)"
	)

	var anchor_position = get_remote_name_anchor_screen_position(remote_player)
	label.position = Vector2(
		round(anchor_position.x - REMOTE_DEBUG_LABEL_WIDTH * 0.5),
		round(anchor_position.y - REMOTE_DEBUG_LABEL_HEIGHT)
	)
	label.visible = true


func _format_remote_debug_position(value) -> String:
	if value is Vector2:
		return "(" + str(round(value.x)) + ", " + str(round(value.y)) + ")"
	return "n/a"


func _clear_remote_debug_label(remote_id: String) -> void:
	if remote_id == "":
		return

	if not remote_debug_labels.has(remote_id):
		return

	var label = remote_debug_labels[remote_id]
	remote_debug_labels.erase(remote_id)
	if label != null and is_instance_valid(label):
		label.queue_free()


func clear_remote_debug_labels() -> void:
	for remote_id in remote_debug_labels.keys():
		var label = remote_debug_labels[remote_id]
		if label != null and is_instance_valid(label):
			label.queue_free()

	remote_debug_labels.clear()



func normalize_remote_equipment_slots(raw_slots) -> Dictionary:
	var slots = {
		"hand": "",
		"back": "",
		"hat": "",
		"hair": "",
		"eyewear": "",
		"beard": "",
		"body_accessory": "",
		"shirt": "",
		"pants": "",
		"shoes": "",
		"ride": ""
	}

	if raw_slots is Dictionary:
		for key in raw_slots.keys():
			var clean_key = str(key).strip_edges().to_lower()
			if clean_key == "":
				continue
			slots[clean_key] = str(raw_slots[key])

	return slots


func get_equipment_slots_debug_key(equipment_slots) -> String:
	if not (equipment_slots is Dictionary):
		return ""

	var keys = equipment_slots.keys()
	keys.sort()
	var result = ""
	for key in keys:
		if result != "":
			result += "|"
		result += str(key) + "=" + str(equipment_slots[key])
	return result


func get_remote_player_profile_data(remote_id: String, remote_player, screen_distance: float = 0.0) -> Dictionary:
	if remote_player == null or not is_instance_valid(remote_player):
		return {}

	var equipment_slots = remote_player.get_meta("equipment_slots", {})
	if not (equipment_slots is Dictionary):
		equipment_slots = {}

	var authoritative_value = remote_player.get_meta("authoritative_position", remote_player.global_position)
	var authoritative_position: Vector2 = authoritative_value if authoritative_value is Vector2 else remote_player.global_position
	return {
		"player_id": remote_id,
		"name": str(remote_player.get_meta("remote_name", "Player")),
		"username": str(remote_player.get_meta("remote_name", "Player")),
		"role": str(remote_player.get_meta("remote_role", "player")),
		"world": str(world.current_world_name),
		"x": authoritative_position.x,
		"y": authoritative_position.y,
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


func request_player_punch_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or world.player == null:
		return false
	if not world.is_grid_inside_world(grid_pos):
		return false
	if not world.can_reach_grid(grid_pos):
		return false

	var target_position := Vector2(
		float(grid_pos.x * world.BLOCK_SIZE),
		float(grid_pos.y * world.BLOCK_SIZE)
	)
	var target_data: Dictionary = get_remote_player_near_world_position(
		target_position,
		PLAYER_PUNCH_GRID_HORIZONTAL_TOLERANCE,
		PLAYER_PUNCH_GRID_VERTICAL_TOLERANCE,
		true
	)
	if target_data.is_empty():
		return false

	return send_player_punch_request(target_data)


func request_player_punch_at_screen_position(screen_pos: Vector2) -> bool:
	if world == null or world.player == null:
		return false

	var target_data: Dictionary = get_remote_player_at_screen_position(screen_pos)
	if target_data.is_empty():
		return false

	return send_player_punch_request(target_data)


func get_remote_player_near_world_position(world_position: Vector2, horizontal_tolerance: float, vertical_tolerance: float, require_forward: bool = false) -> Dictionary:
	if world == null or world.player == null or remote_players.size() == 0:
		return {}

	var facing: int = get_local_punch_facing_for_position(world_position)
	var closest_data: Dictionary = {}
	var closest_score: float = INF

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var authoritative_value = remote_player.get_meta("authoritative_position", remote_player.global_position)
		var remote_position: Vector2 = authoritative_value if authoritative_value is Vector2 else remote_player.global_position
		var offset_from_player: Vector2 = remote_position - world.player.global_position
		if require_forward and offset_from_player.x * float(facing) < -10.0:
			continue

		var horizontal_distance: float = abs(remote_position.x - world_position.x)
		var vertical_distance: float = abs(remote_position.y - world_position.y)
		if horizontal_distance > horizontal_tolerance or vertical_distance > vertical_tolerance:
			continue

		var direct_distance: float = world.player.global_position.distance_to(remote_position)
		if direct_distance > world.INTERACTION_PIXEL_RANGE:
			continue

		var score: float = horizontal_distance + vertical_distance * 0.55 + direct_distance * 0.08
		if score >= closest_score:
			continue

		closest_score = score
		closest_data = get_remote_player_profile_data(str(remote_id), remote_player, direct_distance)

	return closest_data


func send_player_punch_request(target_data: Dictionary) -> bool:
	if world == null or world.player == null or target_data.is_empty():
		return false

	var target_position := Vector2(
		_safe_float(target_data.get("x", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD),
		_safe_float(target_data.get("y", 0.0), 0.0, -MAX_REMOTE_PLAYER_COORD, MAX_REMOTE_PLAYER_COORD)
	)
	if world.player.global_position.distance_to(target_position) > world.INTERACTION_PIXEL_RANGE:
		return false

	if world.has_method("is_anti_punch_enabled") and bool(world.is_anti_punch_enabled()):
		if world.has_method("play_player_punch_animation"):
			world.play_player_punch_animation()
		if world.has_method("show_notification"):
			world.show_notification("Anti-punch is enabled in this world.")
		return false

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - last_player_punch_request_msec < PLAYER_PUNCH_REQUEST_COOLDOWN_MSEC:
		return true

	var target_id: String = str(target_data.get("player_id", "")).strip_edges()
	var target_username: String = str(target_data.get("username", target_data.get("name", ""))).strip_edges()
	if target_id == "" and target_username == "":
		return false

	var facing: int = get_local_punch_facing_for_position(target_position)
	if world.has_method("set_player_facing_direction"):
		world.set_player_facing_direction(facing, false)
	if world.has_method("play_player_punch_animation"):
		world.play_player_punch_animation()
	if str(world.get("equipped_tool")).strip_edges().to_lower() == "ant_sword" and world.has_method("spawn_hand_item_swing_particles"):
		world.spawn_hand_item_swing_particles(target_position, "ant_sword")

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_punch"):
		return false

	var sent: bool = bool(network.send_player_punch(target_id, target_username, target_position, facing, world.current_world_name))
	if sent:
		last_player_punch_request_msec = now_msec
	return sent


func get_local_punch_facing_for_position(target_position: Vector2) -> int:
	if world == null or world.player == null:
		return 1

	var delta_x: float = target_position.x - world.player.global_position.x
	if abs(delta_x) > 1.0:
		return -1 if delta_x < 0.0 else 1

	if "player_facing_direction" in world:
		return -1 if int(world.player_facing_direction) < 0 else 1

	return 1


func handle_network_player_punch_knockback(data: Dictionary):
	if not MovementMode.is_websocket():
		return

	if world == null:
		return

	if world.has_method("is_anti_punch_enabled") and bool(world.is_anti_punch_enabled()):
		return
	if not accept_remote_action_event(data):
		return

	var attacker_remote_id := resolve_remote_attacker_id_from_punch_payload(data)
	if attacker_remote_id != "":
		apply_remote_player_action_animation(attacker_remote_id, "punch", int(data.get("facing", 1)))

	var knockback := Vector2(
		_safe_float(data.get("knockback_x", 0.0), 0.0, -PLAYER_PUNCH_KNOCKBACK_MAX, PLAYER_PUNCH_KNOCKBACK_MAX),
		_safe_float(data.get("knockback_y", 0.0), 0.0, -PLAYER_PUNCH_KNOCKBACK_MAX, PLAYER_PUNCH_KNOCKBACK_MAX)
	)
	if knockback.length_squared() <= 0.01:
		return

	if is_local_player_punch_target(data):
		apply_local_player_punch_knockback(knockback)
		return

	var remote_id: String = resolve_remote_player_id_from_punch_payload(data)
	if remote_id == "":
		return

	apply_remote_player_punch_visual_knockback(remote_id, knockback)


func accept_remote_action_event(data: Dictionary) -> bool:
	var actor_key := str(data.get("attacker_player_id", data.get("player_id", ""))).strip_edges()
	if actor_key == "":
		actor_key = str(data.get("attacker_username", data.get("username", ""))).strip_edges().to_lower()
	if actor_key == "":
		return true

	var sequence := _safe_int(data.get("action_sequence", 0), 0, 0, 2147483647)
	if sequence > 0:
		var previous_sequence := int(remote_action_sequences.get(actor_key, 0))
		if previous_sequence > 0 and sequence <= previous_sequence:
			return false
		remote_action_sequences[actor_key] = sequence
		return true

	var server_time := _safe_int(data.get("server_time", data.get("server_time_msec", 0)), 0, 0, 9223372036854775807)
	if server_time <= 0:
		return true
	var previous_server_time := int(remote_action_server_times.get(actor_key, 0))
	if previous_server_time > 0 and server_time <= previous_server_time:
		return false
	remote_action_server_times[actor_key] = server_time
	return true


func resolve_remote_attacker_id_from_punch_payload(data: Dictionary) -> String:
	var attacker_id := str(data.get("attacker_player_id", data.get("player_id", ""))).strip_edges()
	if attacker_id != "" and remote_players.has(attacker_id):
		return attacker_id
	var attacker_username := str(data.get("attacker_username", data.get("username", ""))).strip_edges().to_lower()
	if attacker_username == "":
		return ""
	for remote_id in remote_players.keys():
		var remote_player = remote_players.get(remote_id, null)
		if remote_player != null and is_instance_valid(remote_player):
			if str(remote_player.get_meta("remote_name", "")).strip_edges().to_lower() == attacker_username:
				return str(remote_id)
	return ""


func apply_remote_player_action_animation(remote_id: String, animation_state: String, facing: int, duration_msec: int = PLAYER_PUNCH_REQUEST_COOLDOWN_MSEC) -> void:
	var remote_player = remote_players.get(remote_id, null)
	if remote_player == null or not is_instance_valid(remote_player):
		return
	var previous_remote_animation_state := str(remote_player.get_meta("animation_state", "idle"))
	remote_player.set_meta("facing", -1 if facing < 0 else 1)
	remote_player.set_meta("remote_action_animation_state", animation_state)
	remote_player.set_meta("remote_action_animation_until_msec", Time.get_ticks_msec() + maxi(1, duration_msec))
	remote_player.set_meta("animation_state", animation_state)
	if previous_remote_animation_state != animation_state:
		remote_player.set_meta("animation_phase", 0.0)
		maybe_spawn_remote_ant_sword_punch_slash(remote_player, previous_remote_animation_state, animation_state)
	update_remote_shared_player_animation(remote_player, 0.0)
	update_remote_player_facing(remote_player)


func play_remote_player_place_animation(data: Dictionary) -> void:
	if not MovementMode.is_websocket() or world == null:
		return
	var remote_id := resolve_remote_attacker_id_from_punch_payload(data)
	if remote_id == "":
		return
	var remote_player = remote_players.get(remote_id, null)
	if remote_player == null or not is_instance_valid(remote_player):
		return
	var facing := int(remote_player.get_meta("facing", 1))
	if data.has("facing"):
		facing = _safe_int(data.get("facing", facing), facing, -1, 1)
	elif data.has("actor_facing"):
		facing = _safe_int(data.get("actor_facing", facing), facing, -1, 1)
	var player_data = data.get("player_data", {})
	if player_data is Dictionary and player_data.has("facing"):
		facing = _safe_int(player_data.get("facing", facing), facing, -1, 1)
	apply_remote_player_action_animation(remote_id, "place_animation", facing, PLACE_ANIMATION_TIME_MSEC)


func is_local_player_punch_target(data: Dictionary) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null:
		return false

	var target_id: String = str(data.get("target_player_id", data.get("target_id", ""))).strip_edges()
	var local_id: String = str(network.get("player_id")).strip_edges()
	if target_id != "" and local_id != "" and target_id == local_id:
		return true

	var target_username: String = str(data.get("target_username", "")).strip_edges().to_lower()
	if target_username == "":
		return false

	var local_username := ""
	if network.has_method("get_active_session_username"):
		local_username = str(network.get_active_session_username()).strip_edges().to_lower()
	else:
		local_username = str(network.get("session_username")).strip_edges().to_lower()

	return local_username != "" and target_username == local_username


func apply_local_player_punch_knockback(knockback: Vector2):
	if not MovementMode.is_websocket():
		return

	if world == null or world.player == null:
		return

	var body: CharacterBody2D = world.player as CharacterBody2D
	if body == null:
		return

	if body.has_method("apply_player_punch_slide"):
		body.apply_player_punch_slide(knockback.x)
	else:
		body.velocity.x = knockback.x
	body.set_physics_process(true)
	body.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + HURT_FACE_EXPRESSION_TIME_MSEC)
	var visual = body.get_node_or_null("PlayerVisual")
	if visual is CanvasItem:
		visual.modulate = Color.WHITE
	flush_multiplayer_position(false, true)


func resolve_remote_player_id_from_punch_payload(data: Dictionary) -> String:
	var target_id: String = str(data.get("target_player_id", data.get("target_id", ""))).strip_edges()
	if target_id != "" and remote_players.has(target_id):
		return target_id

	var target_username: String = str(data.get("target_username", "")).strip_edges().to_lower()
	if target_username == "":
		return ""

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var remote_name: String = str(remote_player.get_meta("remote_name", "")).strip_edges().to_lower()
		if remote_name == target_username:
			return str(remote_id)

	return ""


func apply_remote_player_punch_visual_knockback(remote_id: String, knockback: Vector2):
	if not MovementMode.is_websocket():
		return

	if not remote_players.has(remote_id):
		return

	var remote_player = remote_players[remote_id]
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var target_value = remote_player.get_meta("authoritative_position", remote_player.global_position)
	var base_position: Vector2 = remote_player.global_position
	if target_value is Vector2:
		base_position = target_value

	var visual_offset := Vector2(
		knockback.x * PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_X_SCALE,
		knockback.y * PLAYER_PUNCH_REMOTE_VISUAL_NUDGE_Y_SCALE
	)
	visual_offset = get_safe_remote_punch_visual_offset(base_position, visual_offset)
	var current_offset_value = remote_player.get_meta("remote_presentation_offset", Vector2.ZERO)
	var current_offset: Vector2 = current_offset_value if current_offset_value is Vector2 else Vector2.ZERO
	remote_player.set_meta("remote_presentation_offset", current_offset + visual_offset)
	remote_player.set_meta("animation_state", "hurt")
	remote_player.set_meta("remote_hurt_animation_until_msec", Time.get_ticks_msec() + HURT_FACE_EXPRESSION_TIME_MSEC)
	remote_player.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + HURT_FACE_EXPRESSION_TIME_MSEC)
	var visual = remote_player.get_node_or_null("PlayerVisual")
	if visual is CanvasItem:
		visual.modulate = Color.WHITE
	update_remote_shared_player_animation(remote_player, 0.0)
	update_remote_player_facing(remote_player)
	apply_remote_visual_stabilization(remote_player)


func update_remote_presentation_offset(remote_player, delta: float) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return
	var offset_value = remote_player.get_meta("remote_presentation_offset", Vector2.ZERO)
	var offset: Vector2 = offset_value if offset_value is Vector2 else Vector2.ZERO
	if offset.length_squared() > 0.0025:
		var blend := clampf(1.0 - exp(-REMOTE_PRESENTATION_OFFSET_DECAY_RATE * maxf(0.0, delta)), 0.0, 1.0)
		offset = offset.lerp(Vector2.ZERO, blend)
		if offset.length_squared() <= 0.0025:
			offset = Vector2.ZERO
		remote_player.set_meta("remote_presentation_offset", offset)
	apply_remote_visual_stabilization(remote_player)


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


func get_or_create_remote_player(remote_id: String, remote_name: String, remote_world: String = ""):
	if remote_id == "":
		return null

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
	remote_player.set_meta("remote_draw_order", remote_players.size())
	remote_player.set_meta("remote_id", remote_id)
	remote_player.set_meta("remote_name", remote_name)
	remote_player.set_meta("remote_identity", get_remote_player_identity_key(remote_name))
	remote_player.set_meta("remote_role", "player")
	remote_player.set_meta("facing", 1)
	remote_player.set_meta("target_position", Vector2.ZERO)
	remote_player.set_meta("smoothed_position", Vector2.ZERO)
	remote_player.set_meta("has_position", false)
	remote_player.set_meta("remote_speed", 0.0)
	remote_player.set_meta("remote_velocity_y", 0.0)
	remote_player.set_meta("remote_airborne_stale_msec", 0)
	remote_player.set_meta("animation_state", "idle")
	remote_player.set_meta("animation_phase", 0.0)
	remote_player.set_meta("walk_timer", 0.0)
	remote_player.set_meta("walk_frame", 0)
	remote_player.set_meta("idle_timer", 0.0)
	remote_player.set_meta("idle_frame", 0)
	remote_player.set_meta("stale_time", 0.0)
	remote_player.set_meta("remote_buffer_size", 0)
	remote_player.set_meta("remote_snapshot_buffer", WEBSOCKET_SNAPSHOT_BUFFER.new())
	remote_player.set_meta("remote_previous_snapshot_msec", -1)
	remote_player.set_meta("remote_next_snapshot_msec", -1)
	remote_player.set_meta("remote_interpolation_alpha", 0.0)
	remote_player.set_meta("remote_last_seen_velocity", Vector2.ZERO)
	remote_player.set_meta("remote_last_seen_velocity_time_msec", Time.get_ticks_msec())
	remote_player.set_meta("remote_latest_snapshot_position", Vector2.ZERO)
	remote_player.set_meta("remote_latest_snapshot_time_msec", Time.get_ticks_msec())
	remote_player.set_meta("remote_dead_reckoning_active", false)
	remote_player.set_meta("remote_presentation_offset", Vector2.ZERO)
	remote_player.set_meta("authoritative_position", Vector2.ZERO)
	remote_player.set_meta("remote_debug_version", MovementMode.get_websocket_movement_version())
	remote_player.set_meta("remote_chat_typing", false)
	remote_player.set_meta("equipment_slots", {})
	remote_player.set_meta("equipment_slots_debug_key", "")
	remote_players_root.add_child(remote_player)

	var has_shared_visual = ensure_remote_player_shared_visual_pipeline(remote_player)

	if not has_shared_visual:
		var back_sprite = Sprite2D.new()
		back_sprite.name = "BackSprite"
		back_sprite.z_as_relative = true
		back_sprite.z_index = REMOTE_PLAYER_BACK_Z_INDEX
		back_sprite.visible = false
		remote_player.add_child(back_sprite)

		var body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		body_sprite.z_as_relative = true
		body_sprite.z_index = REMOTE_PLAYER_BODY_Z_INDEX
		body_sprite.texture = remote_idle_texture
		copy_local_player_sprite_settings(body_sprite)
		body_sprite.set_meta("base_position", body_sprite.position)
		body_sprite.set_meta("base_rotation_degrees", body_sprite.rotation_degrees)
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
		equipment_root.z_as_relative = true
		equipment_root.z_index = REMOTE_PLAYER_EQUIPMENT_Z_INDEX
		remote_player.add_child(equipment_root)

	ensure_remote_player_shadow(remote_player)
	_ensure_remote_chat_bubble_anchor(remote_player)

	remote_players[remote_id] = remote_player
	refresh_remote_player_draw_order()

	var normalized_world := _safe_remote_world_name(remote_world)
	if normalized_world == "":
		if world != null and "current_world_name" in world:
			normalized_world = _safe_remote_world_name(world.current_world_name)
	if normalized_world == "":
		normalized_world = "START"

	var pending_snapshot = _get_pending_remote_position_snapshot(remote_id, normalized_world)
	if pending_snapshot.size() > 0:
		pending_snapshot["world"] = normalized_world
		handle_network_player_position(pending_snapshot)
	return remote_player


func ensure_remote_player_shared_visual_pipeline(remote_player) -> bool:
	if remote_player == null or not is_instance_valid(remote_player):
		return false
	if world == null or world.player == null:
		return false
	if bool(remote_player.get_meta("shared_visual_pipeline_ready", false)):
		_hide_remote_legacy_visual_nodes(remote_player)
		ensure_remote_player_shadow(remote_player)
		configure_remote_player_draw_order(remote_player, int(remote_player.get_meta("remote_draw_order", 0)))
		return true

	var player_visual = remote_player.get_node_or_null("PlayerVisual")
	if player_visual == null:
		var local_visual = world.player.get_node_or_null("PlayerVisual")
		if local_visual == null:
			return false

		player_visual = local_visual.duplicate()
		player_visual.name = "PlayerVisual"
		remote_player.add_child(player_visual)
		if player_visual is Node2D:
			var base_scale_x = abs(player_visual.scale.x)
			if base_scale_x <= 0.0:
				base_scale_x = 1.0
			player_visual.scale.x = base_scale_x
			player_visual.set_meta("base_scale_x", base_scale_x)
			player_visual.set_meta("base_scale_y", player_visual.scale.y)
			cache_remote_visual_base_transform(player_visual)
		if player_visual is CanvasItem:
			player_visual.modulate = Color.WHITE
			player_visual.visible = true
		debug_remote_appearance_flow("created shared remote PlayerVisual", {
			"player_id": str(remote_player.get_meta("remote_id", "")),
			"username": str(remote_player.get_meta("remote_name", ""))
		})
	elif player_visual is Node2D:
		cache_remote_visual_base_transform(player_visual)

	clone_remote_player_support_node(remote_player, "Sprite2D")
	clone_remote_player_support_node(remote_player, "DeadSpiritAnimated")
	clone_remote_player_support_node(remote_player, "AnimationPlayer")
	clone_remote_player_support_node(remote_player, "Jump")
	clone_remote_player_support_node(remote_player, "idle")
	setup_remote_visual_managers(remote_player)
	_hide_remote_legacy_visual_nodes(remote_player)
	ensure_remote_player_shadow(remote_player, player_visual)
	configure_remote_player_draw_order(remote_player, int(remote_player.get_meta("remote_draw_order", 0)))
	remote_player.set_meta("shared_visual_pipeline_ready", true)
	return true


func ensure_remote_player_shadow(remote_player, source_node = null):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var shadow_source = source_node
	if shadow_source == null:
		shadow_source = remote_player.get_node_or_null("PlayerVisual")
	if shadow_source == null:
		shadow_source = remote_player.get_node_or_null("BodySprite")
	if shadow_source == null:
		return

	var player_shadow = remote_player.get_node_or_null("PlayerShadow")
	if player_shadow == null:
		player_shadow = Node2D.new()
		player_shadow.name = "PlayerShadow"
		player_shadow.set_script(PlayerShadowScript)
		remote_player.add_child(player_shadow)

	if player_shadow.has_method("setup"):
		player_shadow.setup(shadow_source)


func clone_remote_player_support_node(remote_player, node_name: String):
	if remote_player == null or not is_instance_valid(remote_player):
		return
	if remote_player.get_node_or_null(node_name) != null:
		return
	if world == null or world.player == null:
		return

	var source_node = world.player.get_node_or_null(node_name)
	if source_node == null:
		return

	var node_clone = source_node.duplicate()
	node_clone.name = node_name
	if node_clone is CanvasItem:
		node_clone.z_as_relative = true
		if node_name == "Sprite2D" or node_name == "DeadSpiritAnimated":
			node_clone.visible = false
	remote_player.add_child(node_clone)


func setup_remote_visual_managers(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var equipment_manager = remote_player.get_node_or_null("RemoteEquipmentManager")
	if equipment_manager == null:
		equipment_manager = Node.new()
		equipment_manager.name = "RemoteEquipmentManager"
		equipment_manager.set_script(EquipmentManagerScript)
		remote_player.add_child(equipment_manager)
	if equipment_manager.has_method("setup"):
		equipment_manager.setup(world, remote_player, false)
	equipment_manager.set_process(false)

	var animation_manager = remote_player.get_node_or_null("RemoteAnimationManager")
	if animation_manager == null:
		animation_manager = Node.new()
		animation_manager.name = "RemoteAnimationManager"
		animation_manager.set_script(PlayerAnimationManagerScript)
		remote_player.add_child(animation_manager)
	if animation_manager.has_method("setup"):
		animation_manager.setup(world, remote_player)


func get_remote_equipment_manager(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return null
	return remote_player.get_node_or_null("RemoteEquipmentManager")


func get_remote_animation_manager(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return null
	return remote_player.get_node_or_null("RemoteAnimationManager")


func _hide_remote_legacy_visual_nodes(remote_player):
	if remote_player == null or not is_instance_valid(remote_player):
		return

	for node_name in ["BodySprite", "BackSprite", "FallbackBody", "EquipmentSlots"]:
		var legacy_node = remote_player.get_node_or_null(node_name)
		if legacy_node != null and legacy_node is CanvasItem:
			legacy_node.visible = false


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


func play_local_player_world_enter_fade():
	if not MovementMode.is_websocket():
		return

	if world == null or world.player == null or not is_instance_valid(world.player):
		return

	play_player_world_enter_fade(world.player)


func play_player_world_enter_fade(player_node):
	if not MovementMode.is_websocket():
		return

	var fx = spawn_player_world_fade_fx(player_node)
	if fx == null:
		return

	var target = get_player_world_fade_target(player_node)
	if fx.has_method("play_enter"):
		fx.play_enter(target)


func play_player_world_exit_fade(player_node, finished_callable: Callable = Callable()) -> bool:
	if not MovementMode.is_websocket():
		return false

	var fx = spawn_player_world_fade_fx(player_node)
	if fx == null:
		return false

	if finished_callable.is_valid() and fx.has_signal("fade_finished"):
		fx.fade_finished.connect(Callable(self, "_on_player_world_exit_fade_finished").bind(finished_callable), CONNECT_ONE_SHOT)

	var target = get_player_world_fade_target(player_node)
	if fx.has_method("play_exit"):
		fx.play_exit(target)
		return true

	return false


func spawn_player_world_fade_fx(player_node):
	if not MovementMode.is_websocket():
		return null

	if player_node == null or not is_instance_valid(player_node):
		return null

	var existing = player_node.get_node_or_null(PLAYER_WORLD_FADE_FX_NODE_NAME)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	var fx = PlayerWorldFadeFXScene.instantiate()
	if fx == null:
		return null

	fx.name = PLAYER_WORLD_FADE_FX_NODE_NAME
	player_node.add_child(fx)
	return fx


func get_player_world_fade_target(player_node):
	if player_node == null or not is_instance_valid(player_node):
		return null

	for path in ["PlayerVisual", "BodySprite", "Sprite2D"]:
		var target = player_node.get_node_or_null(path)
		if target is CanvasItem:
			return target

	return null


func _on_player_world_exit_fade_finished(mode: String, finished_callable: Callable):
	if mode != "exit":
		return
	if finished_callable.is_valid():
		finished_callable.call()


func update_remote_player_positions_from_physics(delta: float) -> void:
	if not MovementMode.is_websocket():
		return
	if not REMOTE_POSITION_UPDATE_FROM_PHYSICS:
		return
	if remote_players.size() == 0:
		return

	# Call this from the world/player _physics_process() so remote smoothing and
	# local camera movement happen on the same tick.
	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue
		update_remote_visual_position(remote_player, delta)
		remote_player.set_meta("remote_position_updated_from_physics", true)


func update_remote_players_visuals(delta: float):
	if not MovementMode.is_websocket():
		return

	if remote_players.size() == 0:
		return

	var warning_world = _safe_remote_world_name(world.current_world_name) if world != null else "START"
	var visible_world_rect: Rect2 = get_visible_world_rect(REMOTE_PLAYER_VISIBILITY_MARGIN_SCREEN_PX)
	visible_remote_player_nodes = 0

	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var stale_time = float(remote_player.get_meta("stale_time", 0.0)) + delta
		remote_player.set_meta("stale_time", stale_time)
		if stale_time >= REMOTE_PLAYER_STALE_TIMEOUT:
			remove_remote_player(remote_id)
			continue

		var now_msec = Time.get_ticks_msec()
		var last_receive_msec = int(remote_player.get_meta("remote_last_receive_msec", now_msec))
		var stale_warning_emitted = bool(remote_player.get_meta("remote_stale_warning_emitted", false))
		if not stale_warning_emitted and now_msec - last_receive_msec >= int(REMOTE_PLAYER_STALE_VISUAL_WARNING_TIMEOUT * 1000.0):
			print("[MovementSync][Remote][Warn] remote player snapshot stale while visible world_id=%s remote_id=%s age_ms=%d last_receive_msec=%d current_msec=%d movement_sequence=%d" % [
				warning_world,
				remote_id,
				now_msec - last_receive_msec,
				last_receive_msec,
				now_msec,
				int(remote_player.get_meta("remote_movement_sequence", 0))
			])
			remote_player.set_meta("remote_stale_warning_emitted", true)

		if not REMOTE_POSITION_UPDATE_FROM_PHYSICS:
			update_remote_visual_position(remote_player, delta)
		update_remote_presentation_offset(remote_player, delta)
		var visual_active := is_remote_player_visual_active(remote_player, visible_world_rect)
		set_remote_player_visual_active(remote_player, visual_active)
		if not visual_active:
			clear_remote_fishing_visual(remote_player)
			continue

		visible_remote_player_nodes += 1
		ensure_remote_player_shared_visual_pipeline(remote_player)
		if bool(remote_player.get_meta("pending_visual_refresh", false)):
			update_remote_player_name(remote_player, str(remote_player.get_meta("remote_name", "Player")))
			update_remote_player_facing(remote_player)
			update_remote_shared_player_animation(remote_player, 0.0)
			update_remote_equipment_visuals(remote_player)
			remote_player.set_meta("pending_visual_refresh", false)
		update_remote_player_animation(remote_player, delta)
		update_remote_player_facing(remote_player)
		queue_remote_visual_stabilization(remote_player)
		update_remote_lava_fire_particles(remote_player, remote_player.global_position, bool(remote_player.get_meta("network_in_lava_fire", false)))
		update_remote_fishing_visual(remote_player, delta)

func reset_multiplayer_sync_state():
	network_position_timer = 0.0
	network_heartbeat_timer = 0.0
	last_sent_network_animation_state = ""
	last_sent_network_lava_fire_state = false
	last_sent_network_position = Vector2(999999, 999999)
	last_sent_network_facing = 0
	last_sent_network_fishing_key = ""
	last_sent_network_damage_key = ""

func update_remote_player_animation(remote_player, delta: float):
	if remote_player == null:
		return

	if update_remote_shared_player_animation(remote_player, delta):
		return

	ensure_remote_player_textures_loaded()

	var body_sprite = remote_player.get_node_or_null("BodySprite")
	if body_sprite == null or not (body_sprite is Sprite2D):
		return

	var speed = float(remote_player.get_meta("remote_speed", 0.0))
	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	if animation_state == "fall" and remote_jump_texture == null:
		animation_state = "jump"
	remote_player.set_meta("animation_state", animation_state)
	var walking = animation_state == "walk" and remote_walk_textures.size() > 0
	var phase_speed = REMOTE_WALK_PHASE_SPEED if walking else REMOTE_IDLE_PHASE_SPEED
	if animation_state == "jump" or animation_state == "fall":
		phase_speed = REMOTE_IDLE_PHASE_SPEED
	var animation_phase = float(remote_player.get_meta("animation_phase", 0.0)) + delta * phase_speed
	remote_player.set_meta("animation_phase", animation_phase)

	if (animation_state == "jump" or animation_state == "fall") and remote_jump_texture != null:
		remote_player.set_meta("walk_timer", 0.0)
		remote_player.set_meta("walk_frame", 0)
		remote_player.set_meta("idle_timer", 0.0)
		remote_player.set_meta("idle_frame", 0)
		body_sprite.texture = remote_jump_texture
		apply_remote_animation_pose(remote_player, body_sprite, animation_state, animation_phase)
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

	apply_remote_animation_pose(remote_player, body_sprite, animation_state, animation_phase)

	# Decay speed so the remote player returns to idle after movement stops.
	remote_player.set_meta("remote_speed", lerp(speed, 0.0, clamp(delta * 8.0, 0.0, 1.0)))


func update_remote_shared_player_animation(remote_player, delta: float) -> bool:
	var animation_manager = get_remote_animation_manager(remote_player)
	if animation_manager == null:
		return false

	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	if animation_state == "":
		animation_state = "idle"
	remote_player.set_meta("animation_state", animation_state)
	remote_player.set_meta("punch_animation_name", get_remote_player_punch_animation_name(remote_player))

	if animation_manager.has_method("set_forced_animation_state"):
		animation_manager.set_forced_animation_state(animation_state)
	if animation_manager.has_method("update_player_animation"):
		animation_manager.update_player_animation(delta, int(remote_player.get_meta("facing", 1)))

	var equipment_manager = get_remote_equipment_manager(remote_player)
	if equipment_manager != null:
		if equipment_manager.has_method("set_forced_animation_state"):
			equipment_manager.set_forced_animation_state(animation_state)
		if equipment_manager.has_method("update_wearable_animation_state"):
			equipment_manager.update_wearable_animation_state(delta)
		if equipment_manager.has_method("update_back_item_animation"):
			equipment_manager.update_back_item_animation(delta)

	var speed = float(remote_player.get_meta("remote_speed", 0.0))
	remote_player.set_meta("remote_speed", lerp(speed, 0.0, clamp(delta * 8.0, 0.0, 1.0)))
	return true


func get_remote_player_punch_animation_name(remote_player) -> String:
	if remote_player == null:
		return "punch"

	var equipment_slots = normalize_remote_equipment_slots(remote_player.get_meta("equipment_slots", {}))
	return get_punch_animation_name_for_item(str(equipment_slots.get("hand", "")))


func maybe_spawn_remote_ant_sword_punch_slash(remote_player, previous_remote_animation_state: String, animation_state: String) -> void:
	if world == null or remote_player == null or not is_instance_valid(remote_player):
		return
	if previous_remote_animation_state == "punch" or animation_state != "punch":
		return

	var equipment_slots = normalize_remote_equipment_slots(remote_player.get_meta("equipment_slots", {}))
	if str(equipment_slots.get("hand", "")).strip_edges().to_lower() != "ant_sword":
		return

	var now_msec := Time.get_ticks_msec()
	var recent_msec := now_msec - int(remote_player.get_meta("last_ant_sword_slash_fx_msec", 0))
	if recent_msec >= 0 and recent_msec < REMOTE_ANT_SWORD_SLASH_DEDUPE_MSEC:
		return

	if world.has_method("spawn_ant_sword_actor_swing_particles"):
		var facing := int(remote_player.get_meta("facing", 1))
		if bool(world.spawn_ant_sword_actor_swing_particles(remote_player, facing)):
			remote_player.set_meta("last_ant_sword_slash_fx_msec", now_msec)


func apply_remote_animation_pose(remote_player, body_sprite: Sprite2D, animation_state: String, phase: float):
	if remote_player == null or body_sprite == null:
		return

	var base_position = body_sprite.get_meta("base_position", body_sprite.position)
	if not (base_position is Vector2):
		base_position = body_sprite.position
	var base_rotation = float(body_sprite.get_meta("base_rotation_degrees", body_sprite.rotation_degrees))
	var facing_left = int(remote_player.get_meta("facing", 1)) < 0
	var direction = -1.0 if facing_left else 1.0

	var bob = 0.0
	var x_offset = 0.0
	var tilt = 0.0
	if animation_state == "walk":
		bob = -abs(sin(phase)) * 1.25
		tilt = direction * sin(phase) * 1.5
	elif animation_state == "jump":
		bob = -1.5
	elif animation_state == "fall":
		bob = 1.0
	elif animation_state == "punch" or animation_state == "place_animation":
		x_offset = direction * 1.5
		bob = -0.5
		tilt = direction * -5.0

	body_sprite.position = base_position + Vector2(x_offset, bob)
	body_sprite.rotation_degrees = base_rotation + tilt
	refresh_remote_equipment_slot_transforms(remote_player)

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
	if ["idle", "walk", "jump", "fall", "punch", "place_animation", "hurt", "dead", "dead_spirit"].has(clean):
		return clean
	return ""

func clean_remote_player_name(remote_name: String) -> String:
	var clean_name = remote_name.strip_edges()
	if clean_name == "":
		return "Player"

	if clean_name.to_lower() == "uso":
		return "USO"

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
		remove_remote_player(stale_id, false, true)


func clean_remote_player_role(remote_role: String) -> String:
	var clean_role = remote_role.strip_edges().to_lower()
	if clean_role == "admin" or clean_role == "developer":
		return "admin"
	if clean_role == "designer":
		return "designer"
	return "player"


func is_purple_glow_remote_name(remote_name: String) -> bool:
	return remote_name.strip_edges().to_lower() == PURPLE_GLOW_REMOTE_NAME_KEY


func get_remote_name_style_key(remote_name: String) -> String:
	if is_purple_glow_remote_name(remote_name):
		return "purple_glow"
	return "default"


func get_remote_name_font() -> Font:
	if remote_name_font == null and ResourceLoader.exists(REMOTE_NAME_FONT_PATH):
		var loaded_font: Resource = load(REMOTE_NAME_FONT_PATH)
		if loaded_font is Font:
			remote_name_font = loaded_font
	return remote_name_font


func apply_remote_name_label_font(label: Label) -> void:
	if label == null:
		return

	var font := get_remote_name_font()
	if font == null:
		return

	label.add_theme_font_override("font", font)
	if label.label_settings != null:
		label.label_settings.font = font


func update_remote_player_name(remote_player, remote_name: String):
	if remote_player == null:
		return

	var clean_name = clean_remote_player_name(remote_name)
	var previous_name: String = str(remote_player.get_meta("remote_name", ""))
	remote_player.set_meta("remote_name", clean_name)
	var clean_role = clean_remote_player_role(str(remote_player.get_meta("remote_role", "player")))

	var remote_id = str(remote_player.get_meta("remote_id", ""))
	if remote_id != "":
		var previous_label_role: String = str(remote_player.get_meta("remote_name_label_role", ""))
		var label = remote_name_labels.get(remote_id, null)
		if previous_name == clean_name and previous_label_role == clean_role and label != null and is_instance_valid(label):
			return
		remote_player.set_meta("remote_name_label_role", clean_role)
		create_or_update_remote_name_label(remote_id, clean_name, clean_role)


func create_or_update_remote_name_label(remote_id: String, remote_name: String, remote_role: String = "player"):
	if world == null or not remote_players.has(remote_id):
		return

	var remote_player = remote_players.get(remote_id, null)
	if remote_player == null or not is_instance_valid(remote_player) or not (remote_player is Node2D):
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
		label.set_meta(REMOTE_NAME_FONT_SIZE_META, REMOTE_NAME_FONT_SIZE)
		label.add_theme_font_size_override("font_size", REMOTE_NAME_FONT_SIZE)
		apply_remote_name_label_font(label)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", REMOTE_NAME_DEFAULT_OUTLINE_COLOR)
		label.add_theme_color_override("font_shadow_color", REMOTE_NAME_DEFAULT_SHADOW_COLOR)
		label.add_theme_constant_override("outline_size", REMOTE_NAME_OUTLINE_SIZE)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		remote_player.add_child(label)
		remote_name_labels[remote_id] = label
	elif label.get_parent() != remote_player:
		label.reparent(remote_player, false)

	label.set_meta(REMOTE_NAME_ABSOLUTE_Z_META, true)
	label.z_as_relative = false
	label.z_index = get_remote_name_world_z_index()

	label.set_meta(REMOTE_NAME_FONT_SIZE_META, REMOTE_NAME_FONT_SIZE)
	label.add_theme_font_size_override("font_size", REMOTE_NAME_FONT_SIZE)
	apply_remote_name_label_font(label)
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

		if not remote_players.has(remote_id):
			label.visible = false
			continue

		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player):
			label.visible = false
			continue

		if not bool(remote_player.get_meta("visible_in_camera", true)):
			label.visible = false
			continue

		var clean_name = str(remote_player.get_meta("remote_name", "")).strip_edges()
		if clean_name == "":
			label.visible = false
			continue

		var animation_state: String = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
		if animation_state == "dead_spirit":
			label.visible = false
			continue

		if label.text != clean_name:
			label.text = clean_name
		var desired_size: Vector2 = Vector2(REMOTE_NAME_LABEL_WIDTH, REMOTE_NAME_LABEL_HEIGHT)
		if label.size != desired_size:
			label.size = desired_size

		var remote_role: String = clean_remote_player_role(str(remote_player.get_meta("remote_role", label.get_meta("remote_role", "player"))))
		var world_lock_state: String = _get_remote_player_world_lock_state(clean_name)
		var previous_role: String = str(label.get_meta("remote_role", ""))
		var previous_world_lock_state: String = str(label.get_meta("world_lock_state", ""))
		var name_style_key: String = get_remote_name_style_key(clean_name)
		var previous_name_style_key: String = str(label.get_meta("name_style_key", ""))
		var should_update_style: bool = remote_role == "admin" or name_style_key == "purple_glow" or previous_role != remote_role or previous_world_lock_state != world_lock_state or previous_name_style_key != name_style_key
		if should_update_style:
			label.set_meta("remote_role", remote_role)
			label.set_meta("world_lock_state", world_lock_state)
			apply_remote_name_label_role_style(label, remote_role, world_lock_state)

		update_remote_name_label_world_transform(label, remote_player)

		label.visible = not hide_labels


func get_remote_name_world_z_index() -> int:
	if world != null and world.player is CanvasItem:
		var local_player_z := int(world.player.z_index)
		if local_player_z > REMOTE_PLAYER_Z_INDEX:
			return local_player_z - 1
	return REMOTE_NAME_WORLD_Z_FALLBACK


func update_remote_name_label_world_transform(label: Label, remote_player: Node2D) -> void:
	if label == null or not is_instance_valid(label) or remote_player == null or not is_instance_valid(remote_player):
		return

	if label.get_parent() != remote_player:
		label.reparent(remote_player, false)

	var viewport := get_viewport()
	if viewport == null:
		return

	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var anchor_screen: Vector2 = get_remote_name_anchor_screen_position(remote_player)
	var top_left_screen := Vector2(
		anchor_screen.x - REMOTE_NAME_LABEL_WIDTH / 2.0,
		anchor_screen.y - REMOTE_NAME_LABEL_HEIGHT
	)
	var top_left_world: Vector2 = canvas_transform.affine_inverse() * top_left_screen
	var canvas_scale_x := maxf(canvas_transform.x.length(), 0.001)
	var canvas_scale_y := maxf(canvas_transform.y.length(), 0.001)
	var parent_scale_x := maxf(absf(remote_player.global_scale.x), 0.001)
	var parent_scale_y := maxf(absf(remote_player.global_scale.y), 0.001)

	label.position = remote_player.to_local(top_left_world)
	label.rotation = -remote_player.global_rotation
	label.scale = Vector2(
		1.0 / (canvas_scale_x * parent_scale_x),
		1.0 / (canvas_scale_y * parent_scale_y)
	)
	label.set_meta(REMOTE_NAME_SCREEN_POSITION_META, top_left_screen)
	label.set_meta(REMOTE_NAME_ABSOLUTE_Z_META, true)
	label.z_as_relative = false
	label.z_index = get_remote_name_world_z_index()


func get_remote_name_anchor_screen_position(remote_player) -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	var fallback_world_position = remote_player.global_position + Vector2(0.0, -REMOTE_NAME_LABEL_FALLBACK_OFFSET_WORLD_PX)

	var body_sprite = remote_player.get_node_or_null("BodySprite")
	if body_sprite == null:
		body_sprite = remote_player.get_node_or_null("Sprite2D")
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

	var name_style_key: String = get_remote_name_style_key(label.text)
	label.set_meta("name_style_key", name_style_key)
	if name_style_key == "purple_glow":
		apply_remote_name_label_purple_glow(label)
		return

	apply_remote_name_label_default_glow(label)
	if clean_remote_player_role(role) == "admin":
		var hue = fmod((float(Time.get_ticks_msec()) / 1000.0) * 0.22, 1.0)
		label.add_theme_color_override("font_color", Color.from_hsv(hue, 0.88, 1.0))
	elif str(world_lock_state).strip_edges().to_lower() == "owner":
		label.add_theme_color_override("font_color", get_world_lock_owner_name_color())
	elif str(world_lock_state).strip_edges().to_lower() == "access":
		label.add_theme_color_override("font_color", WORLD_LOCK_ACCESS_NAME_COLOR)
	else:
		label.add_theme_color_override("font_color", WORLD_LOCK_NAME_COLOR_DEFAULT)


func apply_remote_name_label_default_glow(label: Label):
	if label == null or not is_instance_valid(label):
		return

	label.add_theme_color_override("font_outline_color", REMOTE_NAME_DEFAULT_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", REMOTE_NAME_DEFAULT_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", REMOTE_NAME_OUTLINE_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func apply_remote_name_label_purple_glow(label: Label):
	if label == null or not is_instance_valid(label):
		return

	var pulse := (sin(float(Time.get_ticks_msec()) / 1000.0 * PURPLE_GLOW_REMOTE_PULSE_SPEED) + 1.0) * 0.5
	label.add_theme_color_override("font_color", PURPLE_GLOW_REMOTE_NAME_COLOR.lerp(PURPLE_GLOW_REMOTE_NAME_COLOR_BRIGHT, pulse))
	label.add_theme_color_override("font_outline_color", PURPLE_GLOW_REMOTE_OUTLINE_COLOR.lerp(PURPLE_GLOW_REMOTE_OUTLINE_COLOR_BRIGHT, pulse))
	label.add_theme_color_override("font_shadow_color", PURPLE_GLOW_REMOTE_SHADOW_COLOR.lerp(PURPLE_GLOW_REMOTE_SHADOW_COLOR_BRIGHT, pulse))
	label.add_theme_constant_override("outline_size", REMOTE_NAME_OUTLINE_SIZE)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func get_world_lock_owner_name_color() -> Color:
	if world != null and world.has_method("is_super_world_lock_active") and bool(world.is_super_world_lock_active()):
		return SUPER_WORLD_LOCK_OWNER_NAME_COLOR

	return WORLD_LOCK_OWNER_NAME_COLOR


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
	if world == null or get_overhead_layer() == null:
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
	var layer = get_overhead_layer()
	if world == null or layer == null:
		return null

	var bubble_name = "RemoteChatBubbleUI_" + remote_id.substr(0, 8)
	var legacy_name = "RemoteChatBubble_" + remote_id.substr(0, 8)

	var cleanup_parents = [layer]
	if "ui_layer" in world and world.ui_layer != null and world.ui_layer != layer:
		cleanup_parents.append(world.ui_layer)
	for parent in cleanup_parents:
		if parent == null:
			continue
		for child in parent.get_children():
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
	layer.add_child(bubble)
	return bubble


func update_remote_chat_bubbles(_delta: float):
	if remote_chat_bubbles.size() == 0:
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

		var remote_player = remote_players[remote_id]
		if remote_player == null or not is_instance_valid(remote_player) or not bool(remote_player.get_meta("visible_in_camera", true)):
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

	var anchor_screen_pos = _get_remote_chat_anchor_screen_position(remote_player, remote_id)
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


func _get_remote_chat_anchor_screen_position(remote_player, remote_id: String = "") -> Vector2:
	if remote_id != "" and remote_name_labels.has(remote_id):
		var username_label = remote_name_labels[remote_id]
		if username_label is Control:
			var screen_position_value = username_label.get_meta(REMOTE_NAME_SCREEN_POSITION_META, null)
			if screen_position_value is Vector2:
				return Vector2(
					screen_position_value.x + username_label.size.x * 0.5,
					screen_position_value.y - CHAT_BUBBLE_COMPONENT.get_username_gap_screen_px()
				)

	var viewport = get_viewport()
	if viewport != null and remote_player != null and is_instance_valid(remote_player):
		var anchor_world_position = _get_remote_chat_anchor_world_position(remote_player)
		return CHAT_BUBBLE_COMPONENT.world_to_screen_position(viewport, anchor_world_position)

	return Vector2.ZERO

func update_remote_player_facing(remote_player):
	if remote_player == null:
		return

	var facing = int(remote_player.get_meta("facing", 1))
	var player_visual = remote_player.get_node_or_null("PlayerVisual")
	if player_visual != null and player_visual is Node2D:
		var base_scale_x = abs(float(player_visual.get_meta("base_scale_x", abs(player_visual.scale.x))))
		if base_scale_x <= 0.0:
			base_scale_x = 1.0
		player_visual.scale.x = -base_scale_x if facing < 0 else base_scale_x

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

	if update_remote_shared_equipment_visuals(remote_player):
		return

	var equipment_slots = remote_player.get_meta("equipment_slots", {})
	if not (equipment_slots is Dictionary):
		equipment_slots = {}

	var equipment_root = remote_player.get_node_or_null("EquipmentSlots")
	if equipment_root == null:
		equipment_root = Node2D.new()
		equipment_root.name = "EquipmentSlots"
		equipment_root.z_as_relative = true
		equipment_root.z_index = REMOTE_PLAYER_EQUIPMENT_Z_INDEX
		remote_player.add_child(equipment_root)

	var known_slots = [
		"back", "hand", "hair", "eyewear", "beard", "body_accessory", "head", "hat", "eyes", "face",
		"shirt", "pants", "legs", "feet", "shoes", "ride",
		"neck", "aura"
	]

	for slot_name in known_slots:
		var item_id = str(equipment_slots.get(slot_name, ""))
		update_remote_equipment_slot(remote_player, equipment_root, slot_name, item_id)


func update_remote_shared_equipment_visuals(remote_player) -> bool:
	var equipment_manager = get_remote_equipment_manager(remote_player)
	if equipment_manager == null:
		return false

	var equipment_slots = normalize_remote_equipment_slots(remote_player.get_meta("equipment_slots", {}))
	var facing = int(remote_player.get_meta("facing", 1))
	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	if animation_state == "":
		animation_state = "idle"
	var applied_key = get_equipment_slots_debug_key(equipment_slots)
	var previous_applied_key = str(remote_player.get_meta("applied_equipment_slots_debug_key", ""))
	var previous_applied_facing = int(remote_player.get_meta("applied_equipment_facing", 0))
	if previous_applied_key == applied_key and previous_applied_facing == facing:
		return true

	if equipment_manager.has_method("set_forced_animation_state"):
		equipment_manager.set_forced_animation_state(animation_state)
	if equipment_manager.has_method("update_equipped_tool_visual"):
		equipment_manager.update_equipped_tool_visual(str(equipment_slots.get("hand", "")), facing)
	if equipment_manager.has_method("update_equipped_back_visual"):
		equipment_manager.update_equipped_back_visual(str(equipment_slots.get("back", "")), facing)
	if equipment_manager.has_method("update_equipped_hat_visual"):
		equipment_manager.update_equipped_hat_visual(str(equipment_slots.get("hat", "")), facing)
	if equipment_manager.has_method("update_equipped_hair_visual"):
		equipment_manager.update_equipped_hair_visual(str(equipment_slots.get("hair", "")), facing)
	if equipment_manager.has_method("update_equipped_eyewear_visual"):
		equipment_manager.update_equipped_eyewear_visual(str(equipment_slots.get("eyewear", "")), facing)
	if equipment_manager.has_method("update_equipped_beard_visual"):
		equipment_manager.update_equipped_beard_visual(str(equipment_slots.get("beard", "")), facing)
	if equipment_manager.has_method("update_equipped_body_accessory_visual"):
		equipment_manager.update_equipped_body_accessory_visual(str(equipment_slots.get("body_accessory", "")), facing)
	if equipment_manager.has_method("update_equipped_shirt_visual"):
		equipment_manager.update_equipped_shirt_visual(str(equipment_slots.get("shirt", "")), facing)
	if equipment_manager.has_method("update_equipped_pants_visual"):
		equipment_manager.update_equipped_pants_visual(str(equipment_slots.get("pants", "")), facing)
	if equipment_manager.has_method("update_equipped_shoes_visual"):
		equipment_manager.update_equipped_shoes_visual(str(equipment_slots.get("shoes", "")), facing)
	if equipment_manager.has_method("update_equipped_ride_visual"):
		equipment_manager.update_equipped_ride_visual(str(equipment_slots.get("ride", "")), facing)

	remote_player.set_meta("applied_equipment_slots_debug_key", applied_key)
	remote_player.set_meta("applied_equipment_facing", facing)
	debug_remote_appearance_flow("remote visual applied equipment", {
		"player_id": str(remote_player.get_meta("remote_id", "")),
		"username": str(remote_player.get_meta("remote_name", "")),
		"equipment_slots": equipment_slots,
		"facing": facing,
		"animation_state": animation_state
	})
	return true


func refresh_remote_equipment_slot_transforms(remote_player):
	if remote_player == null:
		return

	var equipment_slots = remote_player.get_meta("equipment_slots", {})
	if not (equipment_slots is Dictionary):
		return

	var equipment_root = remote_player.get_node_or_null("EquipmentSlots")
	if equipment_root == null:
		return

	var known_slots = [
		"back", "hand", "hair", "eyewear", "beard", "body_accessory", "head", "hat", "eyes", "face",
		"shirt", "pants", "legs", "feet", "shoes", "ride",
		"neck", "aura"
	]

	for slot_name in known_slots:
		var item_id = str(equipment_slots.get(slot_name, ""))
		if item_id == "":
			continue
		var slot_sprite = equipment_root.get_node_or_null("Slot_" + slot_name.capitalize())
		if slot_sprite == null or not (slot_sprite is Sprite2D):
			continue
		var item_data = get_remote_item_data(item_id)
		apply_remote_equipment_slot_transform(remote_player, slot_sprite, slot_name, item_data, slot_sprite.texture)


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
		slot_sprite.z_as_relative = true
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

		if slot_name == "hat" and "hat_textures" in world and world.hat_textures.has(item_id):
			return world.hat_textures[item_id]

		if slot_name == "hair" and world.hair_textures.has(item_id):
			return world.hair_textures[item_id]

		if slot_name == "eyewear" and world.eyewear_textures.has(item_id):
			return world.eyewear_textures[item_id]

		if slot_name == "beard" and world.beard_textures.has(item_id):
			return world.beard_textures[item_id]

		if slot_name == "body_accessory" and world.body_accessory_textures.has(item_id):
			return world.body_accessory_textures[item_id]

		if slot_name == "shirt" and world.shirt_textures.has(item_id):
			return world.shirt_textures[item_id]

		if slot_name == "pants" and world.pants_textures.has(item_id):
			return world.pants_textures[item_id]

		if slot_name == "shoes" and world.shoes_textures.has(item_id):
			return world.shoes_textures[item_id]

		if slot_name == "ride" and world.ride_textures.has(item_id):
			return world.ride_textures[item_id]

		if world.tool_textures.has(item_id):
			return world.tool_textures[item_id]

		if world.back_textures.has(item_id):
			return world.back_textures[item_id]

		if "hat_textures" in world and world.hat_textures.has(item_id):
			return world.hat_textures[item_id]

		if world.hair_textures.has(item_id):
			return world.hair_textures[item_id]

		if world.eyewear_textures.has(item_id):
			return world.eyewear_textures[item_id]

		if world.beard_textures.has(item_id):
			return world.beard_textures[item_id]

		if world.body_accessory_textures.has(item_id):
			return world.body_accessory_textures[item_id]

		if world.shirt_textures.has(item_id):
			return world.shirt_textures[item_id]

		if world.pants_textures.has(item_id):
			return world.pants_textures[item_id]

		if world.shoes_textures.has(item_id):
			return world.shoes_textures[item_id]

		if world.ride_textures.has(item_id):
			return world.ride_textures[item_id]

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
			apply_remote_hand_item_transform(remote_player, slot_sprite, item_data, texture, facing_left)
		"back":
			apply_remote_back_item_transform(remote_player, slot_sprite, item_data, texture, facing_left)
		_:
			apply_remote_generic_slot_transform(remote_player, slot_sprite, slot_name, item_data, facing_left)


func apply_remote_hand_item_transform(remote_player, slot_sprite: Sprite2D, _item_data: Dictionary, _texture, facing_left: bool):
	var scene_transform = get_remote_hand_scene_transform(facing_left)
	slot_sprite.position = scene_transform.get("position", Vector2.ZERO)
	slot_sprite.rotation_degrees = float(scene_transform.get("rotation_degrees", 0.0))
	slot_sprite.scale = scene_transform.get("scale", Vector2.ONE)
	slot_sprite.z_index = REMOTE_PLAYER_HAND_Z_INDEX
	slot_sprite.position += get_remote_slot_animation_offset(remote_player, "hand", facing_left)
	slot_sprite.rotation_degrees += get_remote_hand_animation_rotation(remote_player, facing_left)


func get_local_player_scene_position(node_path: String, fallback: Vector2) -> Vector2:
	if world == null or world.player == null:
		return fallback

	var node = world.player.get_node_or_null(node_path)
	if node == null or not (node is Node2D):
		return fallback

	var scene_position = Vector2.ZERO
	var current = node
	while current != null and current != world.player:
		if current is Node2D:
			scene_position += current.position
		current = current.get_parent()

	return scene_position


func get_local_player_faced_scene_position(node_path: String, fallback: Vector2, facing_left: bool) -> Vector2:
	var scene_position = get_local_player_scene_position(node_path, fallback)
	if not facing_left:
		return scene_position

	var visual_position = get_local_player_scene_position("PlayerVisual", Vector2.ZERO)
	return Vector2(visual_position.x - (scene_position.x - visual_position.x), scene_position.y)


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


func apply_remote_back_item_transform(remote_player, slot_sprite: Sprite2D, item_data: Dictionary, _texture, facing_left: bool):
	var sprite_facing_left = facing_left and bool(item_data.get("back_flip_with_facing", true))
	slot_sprite.flip_h = sprite_facing_left

	slot_sprite.position = get_local_player_faced_scene_position("PlayerVisual/BackSlot/BackItemAnimated", Vector2(0, -12), facing_left)
	slot_sprite.position += get_remote_slot_animation_offset(remote_player, "back", facing_left)
	slot_sprite.scale = get_local_player_scene_scale("PlayerVisual/BackSlot/BackItemAnimated", Vector2.ONE)
	slot_sprite.z_index = int(item_data.get("back_z_index", REMOTE_PLAYER_BACK_Z_INDEX))


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


func apply_remote_generic_slot_transform(remote_player, slot_sprite: Sprite2D, slot_name: String, item_data: Dictionary, facing_left: bool):
	var default_offsets = {
		"hair": Vector2(0, -28),
		"eyewear": Vector2(0, -28),
		"beard": Vector2(0, -22),
		"head": Vector2(0, -30),
		"hat": Vector2(0, -38),
		"eyes": Vector2(0, -23),
		"face": Vector2(0, -18),
		"shirt": Vector2(0, -5),
		"pants": Vector2(0, 8),
		"legs": Vector2(0, 8),
		"feet": Vector2(0, 8),
		"shoes": Vector2(0, 8),
		"ride": Vector2.ZERO,
		"neck": Vector2(0, -12),
		"aura": Vector2(0, -8),
		"body_accessory": Vector2(0, -12)
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
	elif slot_name == "hair" or slot_name == "eyewear" or slot_name == "beard":
		base_position = get_remote_hair_slot_position(facing_left)

	slot_sprite.position = base_position + (offset_left if facing_left else offset) + get_remote_slot_animation_offset(remote_player, slot_name, facing_left)
	var scale_value = float(item_data.get("front_scale", item_data.get("slot_scale", 1.0))) if slot_name == "shirt" else float(item_data.get("slot_scale", 1.0))
	slot_sprite.scale = Vector2(scale_value, scale_value)
	slot_sprite.z_index = int(item_data.get("front_z_index", item_data.get("slot_z_index", REMOTE_PLAYER_EQUIPMENT_Z_INDEX))) if slot_name == "shirt" else int(item_data.get("slot_z_index", REMOTE_PLAYER_EQUIPMENT_Z_INDEX))


func get_remote_slot_animation_offset(remote_player, slot_name: String, facing_left: bool) -> Vector2:
	if remote_player == null:
		return Vector2.ZERO

	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	var phase = float(remote_player.get_meta("animation_phase", 0.0))
	var direction = -1.0 if facing_left else 1.0

	if animation_state == "walk":
		if slot_name == "hand":
			return Vector2(direction * sin(phase) * 1.5, cos(phase) * 1.5)
		if ["shirt", "back", "ride", "neck", "aura", "body_accessory"].has(slot_name):
			return Vector2(0.0, -abs(sin(phase)) * 1.0)
		if ["pants", "legs", "feet", "shoes"].has(slot_name):
			return Vector2(0.0, sin(phase) * 1.25)
		if ["hair", "eyewear", "beard", "head", "hat", "eyes", "face"].has(slot_name):
			return Vector2(0.0, -abs(sin(phase)) * 0.75)
	if animation_state == "jump":
		return Vector2(0.0, -1.5)
	if animation_state == "fall":
		return Vector2(0.0, 1.0)
	if animation_state == "punch" or animation_state == "place_animation":
		if slot_name == "hand":
			return Vector2(direction * 3.0, -1.0)
		return Vector2(direction * 1.0, -0.5)
	return Vector2.ZERO


func get_remote_hand_animation_rotation(remote_player, facing_left: bool) -> float:
	if remote_player == null:
		return 0.0

	var animation_state = clean_remote_animation_state(str(remote_player.get_meta("animation_state", "idle")))
	var phase = float(remote_player.get_meta("animation_phase", 0.0))
	var direction = -1.0 if facing_left else 1.0

	if animation_state == "walk":
		return direction * sin(phase) * 5.0
	if animation_state == "jump":
		return direction * -8.0
	if animation_state == "fall":
		return direction * 6.0
	if animation_state == "punch" or animation_state == "place_animation":
		return direction * -18.0
	return 0.0


func get_remote_pant_slot_position(_facing_left: bool) -> Vector2:
	if world == null or world.player == null:
		return Vector2.ZERO

	var animated = world.player.get_node_or_null("PlayerVisual/Bottom")
	if animated != null:
		return get_local_player_scene_position("PlayerVisual/Bottom", animated.position)

	return Vector2.ZERO


func get_remote_hair_slot_position(_facing_left: bool) -> Vector2:
	if world == null or world.player == null:
		return Vector2(0, -28)

	var animated = world.player.get_node_or_null("PlayerVisual/Head")
	if animated != null:
		return get_local_player_scene_position("PlayerVisual/Head", animated.position)

	return Vector2(0, -28)


func get_remote_front_socket_position(_facing_left: bool) -> Vector2:
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


func remove_remote_player(remote_id: String, fade_out: bool = true, force_free: bool = false):
	if remote_id == "":
		return

	if not remote_players.has(remote_id):
		remote_pending_position_snapshots.erase(remote_id)
		return

	var remote_player = remote_players[remote_id]
	remote_players.erase(remote_id)
	remote_action_sequences.erase(remote_id)
	remote_action_server_times.erase(remote_id)
	remote_pending_position_snapshots.erase(remote_id)

	if remote_player != null and is_instance_valid(remote_player):
		remote_player.set_meta("remote_snapshot_intervals", [])
		clear_remote_fishing_visual(remote_player)
		if force_free:
			remote_player.queue_free()
		else:
			var fade_started := false
			if fade_out:
				fade_started = play_player_world_exit_fade(remote_player, Callable(self, "_free_remote_player_node").bind(remote_player))
			if not fade_started:
				remote_player.queue_free()

	clear_remote_player_ui(remote_id)
	_clear_remote_debug_label(remote_id)
	refresh_remote_player_draw_order()


func _free_remote_player_node(remote_player):
	if remote_player != null and is_instance_valid(remote_player):
		remote_player.queue_free()


func clear_remote_players():
	remote_pending_position_snapshots.clear()
	for remote_id in remote_players.keys():
		var remote_player = remote_players[remote_id]
		if remote_player != null and is_instance_valid(remote_player):
			remote_player.set_meta("remote_snapshot_intervals", [])
			remote_player.set_meta("remote_snapshot_buffer", null)
			remote_player.set_meta("remote_buffer_size", 0)
			clear_remote_fishing_visual(remote_player)
			remote_player.queue_free()

	remote_players.clear()
	remote_action_sequences.clear()
	remote_action_server_times.clear()

	for remote_id in remote_name_labels.keys():
		var label = remote_name_labels[remote_id]
		if label != null and is_instance_valid(label):
			label.queue_free()

	remote_name_labels.clear()

	for remote_id in remote_debug_labels.keys():
		var debug_label = remote_debug_labels[remote_id]
		if debug_label != null and is_instance_valid(debug_label):
			debug_label.queue_free()

	remote_debug_labels.clear()

	for remote_id in remote_chat_bubbles.keys():
		var bubble = remote_chat_bubbles[remote_id]
		if bubble != null and is_instance_valid(bubble):
			bubble.queue_free()

	remote_chat_bubbles.clear()
	remote_chat_pending_messages.clear()
	clear_legacy_websocket_remote_visual_nodes()


func clear_legacy_websocket_remote_visual_nodes() -> void:
	if world == null:
		return

	var stale_root = world.get_node_or_null("RemotePlayers")
	if stale_root != null and is_instance_valid(stale_root):
		stale_root.queue_free()
	remote_players_root = null

	for child in world.get_children():
		if _is_legacy_remote_visual_node(child):
			child.queue_free()

	var ui_cleanup_layers = []
	var ui_layer = world.get("ui_layer") if world.get("ui_layer") != null else null
	if ui_layer is Node:
		ui_cleanup_layers.append(ui_layer)
	var overhead_layer = get_overhead_layer()
	if overhead_layer is Node and not ui_cleanup_layers.has(overhead_layer):
		ui_cleanup_layers.append(overhead_layer)
	for cleanup_layer in ui_cleanup_layers:
		for child in (cleanup_layer as Node).get_children():
			if _is_legacy_remote_ui_node(child):
				child.queue_free()


func _is_legacy_remote_visual_node(node: Node) -> bool:
	if node == null:
		return false

	var node_name := str(node.name)
	return node_name.begins_with("RemotePlayer_") \
		or node_name.begins_with("RemoteFishingBobber_") \
		or node_name == PLAYER_WORLD_FADE_FX_NODE_NAME


func _is_legacy_remote_ui_node(node: Node) -> bool:
	if node == null:
		return false

	var node_name := str(node.name)
	return node_name.begins_with("RemoteUsernameLabel_") \
		or node_name.begins_with("RemoteChatBubbleUI_") \
		or node_name.begins_with("RemoteChatBubble_")
