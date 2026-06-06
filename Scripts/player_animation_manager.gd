extends Node

const WALK_FRAME_TIME = 0.16
const IDLE_FRAME_TIME = 0.45
const BODY_PART_TEXTURE_FOLDER = "res://Assets/player/body_parts/"
const BODY_PART_FRAME_SEARCH_LIMIT = 8
const BODY_LAYER_POSITION = Vector2(0, -8)
const BODY_PART_NODE_CONFIG = [
	{"key": "left_arm", "node": "PlayerVisual/LeftArm/BaseLeftArmAnimated", "prefix": "left_hand"},
	{"key": "right_foot", "node": "PlayerVisual/RightFoot/BaseRightFootAnimated", "prefix": "right_foot"},
	{"key": "left_foot", "node": "PlayerVisual/LeftFoot/BaseLeftFootAnimated", "prefix": "left_foot"},
	{"key": "bottom", "node": "PlayerVisual/Bottom/BaseBottomAnimated", "prefix": "bottom"},
	{"key": "body", "node": "PlayerVisual/Body/BaseBodyAnimated", "prefix": "body"},
	{"key": "right_arm", "node": "PlayerVisual/RightArm/BaseRightArmAnimated", "prefix": "right_hand"},
	{"key": "head", "node": "PlayerVisual/Head/BaseHeadAnimated", "prefix": "head"},
]

var world = null
var player = null
var player_visual = null
var movement_animation_player = null
var current_movement_animation_player = null
var face_expression_animated = null
var dead_spirit_animated = null
var player_sprite = null
var body_part_nodes = {}
var use_layered_body = false
var current_layered_animation = ""
var current_movement_animation = ""
var current_face_expression_animation = ""
var current_dead_spirit_animation = ""

var idle_texture = null
var idle_textures = []
var walk_textures = []
var jump_texture = null

var idle_timer = 0.0
var idle_frame_index = 0
var walk_timer = 0.0
var walk_frame_index = 0
var current_texture = null


func setup(parent_world, player_node):
	world = parent_world
	player = player_node
	player_visual = player.get_node_or_null("PlayerVisual") if player != null else null
	movement_animation_player = player.get_node_or_null("AnimationPlayer") if player != null else null
	face_expression_animated = player.get_node_or_null("PlayerVisual/Head/FaceExpressionAnimated") if player != null else null
	dead_spirit_animated = get_dead_spirit_animated_node()
	if dead_spirit_animated != null:
		dead_spirit_animated.visible = false

	setup_player_sprite()
	setup_layered_body_parts()
	load_player_animation_textures()
	update_player_animation(0.0, 1)


func setup_player_sprite():
	if player == null:
		return

	player_sprite = player.get_node_or_null("Sprite2D")

	if player_sprite == null:
		player_sprite = player.get_node_or_null("Sprite")

	if player_sprite == null:
		var sprite_nodes = player.find_children("*", "Sprite2D", true, false)

		if sprite_nodes.size() > 0:
			player_sprite = sprite_nodes[0]

	if player_sprite == null:
		player_sprite = Sprite2D.new()
		player_sprite.name = "Sprite2D"
		player_sprite.position = BODY_LAYER_POSITION
		player.add_child(player_sprite)

	player_sprite.z_index = 0


func setup_layered_body_parts():
	body_part_nodes.clear()
	use_layered_body = false
	current_layered_animation = ""

	if player == null:
		return

	player_visual = player.get_node_or_null("PlayerVisual")
	var prepared_nodes = []

	for config in BODY_PART_NODE_CONFIG:
		var node_name = str(config["node"])
		var part = player.get_node_or_null(node_name)

		if part != null and not (part is AnimatedSprite2D):
			continue

		if part == null:
			continue

		part.visible = true
		part.centered = true

		if part.sprite_frames == null:
			continue

		var idle_animation = get_available_animation_name(part, "idle")
		if idle_animation == "":
			continue

		part.animation = idle_animation
		part.frame = 0
		prepared_nodes.append({"key": str(config["key"]), "node": part})

	use_layered_body = prepared_nodes.size() == BODY_PART_NODE_CONFIG.size()

	if not use_layered_body:
		for entry in prepared_nodes:
			var partial_part = entry["node"]
			if partial_part is AnimatedSprite2D:
				partial_part.visible = false
		if player_sprite != null:
			player_sprite.visible = true
		return

	for entry in prepared_nodes:
		body_part_nodes[entry["key"]] = entry["node"]

	if player_sprite != null:
		player_sprite.visible = false

	play_layered_animation("idle")


func build_layered_body_sprite_frames(prefix: String):
	var idle_paths = get_layered_body_frame_paths(prefix, "idle")
	if idle_paths.is_empty():
		return null

	var walk_paths = get_layered_body_frame_paths(prefix, "walk")
	if walk_paths.is_empty():
		walk_paths = idle_paths

	var jump_paths = get_layered_body_frame_paths(prefix, "jump")
	if jump_paths.is_empty():
		jump_paths = [idle_paths[0]]

	var fall_paths = get_layered_body_frame_paths(prefix, "fall")
	if fall_paths.is_empty():
		fall_paths = jump_paths

	var punch_paths = get_layered_body_frame_paths(prefix, "punch")
	if punch_paths.is_empty():
		punch_paths = idle_paths

	var sprite_frames = SpriteFrames.new()
	for animation_name in sprite_frames.get_animation_names():
		sprite_frames.remove_animation(animation_name)

	add_layered_animation(sprite_frames, "idle", idle_paths, 1.0 / IDLE_FRAME_TIME, true)
	add_layered_animation(sprite_frames, "walk", walk_paths, 1.0 / WALK_FRAME_TIME, true)
	add_layered_animation(sprite_frames, "jump", jump_paths, 1.0, false)
	add_layered_animation(sprite_frames, "fall", fall_paths, 1.0, false)
	add_layered_animation(sprite_frames, "punch", punch_paths, 1.0 / IDLE_FRAME_TIME, false)
	return sprite_frames


func get_layered_body_frame_paths(prefix: String, animation_name: String) -> Array:
	var paths = []

	for frame_index in range(1, BODY_PART_FRAME_SEARCH_LIMIT + 1):
		var path = "%s%s_%s_%d.png" % [BODY_PART_TEXTURE_FOLDER, prefix, animation_name, frame_index]
		if ResourceLoader.exists(path):
			paths.append(path)

	return paths


func add_layered_animation(sprite_frames: SpriteFrames, animation_name: String, paths: Array, fps: float, loop: bool) -> bool:
	if paths.is_empty():
		return false

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(animation_name, max(0.1, fps))
	sprite_frames.set_animation_loop(animation_name, loop)

	var added_count = 0
	for path in paths:
		var texture = load(str(path))
		if texture == null:
			continue
		sprite_frames.add_frame(animation_name, texture)
		added_count += 1

	if added_count <= 0:
		sprite_frames.remove_animation(animation_name)
		return false

	return true


func load_player_animation_textures():
	idle_textures.clear()
	walk_textures.clear()

	idle_texture = load_first_existing([
		"res://Assets/player/body/player_idle.png"
	])

	var idle_2 = load_first_existing([
		"res://Assets/player/body/player_idle_2.png"
	])

	var idle_3 = load_first_existing([
		"res://Assets/player/body/player_idle_3.png"
	])

	jump_texture = load_first_existing([
		"res://Assets/player/body/player_jump.png"
	])

	var walk_1 = load_first_existing([
		"res://Assets/player/body/player_walk_1.png"
	])

	var walk_2 = load_first_existing([
		"res://Assets/player/body/player_walk_2.png"
	])

	if walk_1 != null:
		walk_textures.append(walk_1)

	if walk_2 != null:
		walk_textures.append(walk_2)

	if idle_texture == null and player_sprite != null:
		idle_texture = player_sprite.texture

	if idle_texture != null:
		idle_textures.append(idle_texture)

	if idle_2 != null and not idle_textures.has(idle_2):
		idle_textures.append(idle_2)

	if idle_3 != null and not idle_textures.has(idle_3):
		idle_textures.append(idle_3)

	if idle_texture != null:
		set_sprite_texture(idle_texture)

	if player_sprite != null:
		player_sprite.visible = not use_layered_body


func load_first_existing(paths: Array):
	for path in paths:
		if ResourceLoader.exists(str(path)):
			return load(str(path))

	return null


func update_player_animation(delta: float, facing_direction: int):
	if player == null:
		return

	var animation_name = get_player_animation_name()
	update_movement_animation_player(animation_name)
	update_face_expression_animation(animation_name)

	if use_layered_body:
		play_layered_animation(animation_name)
		update_facing(facing_direction)
		return

	if player_sprite == null:
		return

	if animation_name == "jump" and jump_texture != null:
		reset_walk_animation()
		reset_idle_animation()
		set_sprite_texture(jump_texture)
		update_facing(facing_direction)
		return

	if animation_name == "walk" and walk_textures.size() > 0:
		reset_idle_animation()
		walk_timer += delta

		if walk_timer >= WALK_FRAME_TIME:
			walk_timer = 0.0
			walk_frame_index = (walk_frame_index + 1) % walk_textures.size()

		set_sprite_texture(walk_textures[walk_frame_index])
	else:
		reset_walk_animation()

		if idle_textures.size() > 0:
			idle_timer += delta

			if idle_timer >= IDLE_FRAME_TIME:
				idle_timer = 0.0
				idle_frame_index = (idle_frame_index + 1) % idle_textures.size()

			set_sprite_texture(idle_textures[idle_frame_index])
		elif idle_texture != null:
			set_sprite_texture(idle_texture)

	update_facing(facing_direction)


func update_face_expression_animation(movement_state: String):
	var expression_name = get_face_expression_animation_name(movement_state)
	if update_dead_spirit_visual(expression_name):
		if face_expression_animated != null:
			face_expression_animated.visible = false
		return

	if face_expression_animated == null:
		return

	if not (face_expression_animated is AnimatedSprite2D):
		return

	play_face_expression_animation(expression_name)


func get_dead_spirit_animated_node():
	if player == null:
		return null

	var spirit = player.get_node_or_null("DeadSpiritAnimated")
	if spirit == null:
		spirit = player.get_node_or_null("AnimatedSprite2D")

	if spirit is AnimatedSprite2D:
		return spirit

	return null


func update_dead_spirit_visual(expression_name: String) -> bool:
	if dead_spirit_animated == null:
		dead_spirit_animated = get_dead_spirit_animated_node()

	if dead_spirit_animated == null:
		restore_normal_player_visual()
		return false

	if expression_name != "dead_spirit":
		dead_spirit_animated.visible = false
		restore_normal_player_visual()
		return false

	if player_visual != null:
		player_visual.visible = false
	if player_sprite != null:
		player_sprite.visible = false

	dead_spirit_animated.visible = true
	play_dead_spirit_animation()
	return true


func restore_normal_player_visual():
	if player_visual != null:
		player_visual.visible = true
	if player_sprite != null:
		player_sprite.visible = not use_layered_body


func play_dead_spirit_animation():
	if dead_spirit_animated == null or dead_spirit_animated.sprite_frames == null:
		return

	var target_animation = get_available_dead_spirit_animation_name()
	if target_animation == "":
		return

	if current_dead_spirit_animation != target_animation:
		current_dead_spirit_animation = target_animation
		dead_spirit_animated.play(target_animation)
	elif not dead_spirit_animated.is_playing() and dead_spirit_animated.sprite_frames.get_frame_count(target_animation) > 1:
		dead_spirit_animated.play(target_animation)


func get_available_dead_spirit_animation_name() -> String:
	if dead_spirit_animated == null or dead_spirit_animated.sprite_frames == null:
		return ""

	for candidate in ["dead_spirit", "dead spirit", "Dead Spirit", "deadspirit", "DeadSpirit"]:
		if dead_spirit_animated.sprite_frames.has_animation(str(candidate)):
			return str(candidate)

	var names = dead_spirit_animated.sprite_frames.get_animation_names()
	if names.size() > 0:
		return str(names[0])

	return ""


func get_face_expression_animation_name(movement_state: String) -> String:
	if player != null:
		var override_expression = str(player.get_meta("face_expression_override", "")).strip_edges()
		if override_expression != "":
			return override_expression

		var hurt_until_msec = int(player.get_meta("face_hurt_until_msec", 0))
		if hurt_until_msec > Time.get_ticks_msec():
			return "hurt"

	if is_chat_typing_for_face_expression():
		return "talk"

	if is_player_underwater_for_face_expression():
		return "underwater"

	if player != null:
		var punch_until_msec = int(player.get_meta("face_punch_until_msec", 0))
		if punch_until_msec > Time.get_ticks_msec():
			return "punch"

	if movement_state == "jump":
		return "jump"

	if movement_state == "fall":
		return "fall"

	return "idle"


func is_chat_typing_for_face_expression() -> bool:
	if world == null:
		return false

	if world.has_method("is_chat_input_focused") and world.is_chat_input_focused():
		return true

	return false


func is_player_underwater_for_face_expression() -> bool:
	if player == null:
		return false

	if player.has_method("is_standing_on_water"):
		if bool(player.is_standing_on_water()):
			return true

	if world == null:
		return false

	var block_size = 32.0
	var block_size_value = world.get("BLOCK_SIZE")
	if block_size_value is int or block_size_value is float:
		block_size = float(block_size_value)

	var sample_offsets = [
		Vector2(0.0, -24.0),
		Vector2(0.0, -12.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, 10.0)
	]

	for offset in sample_offsets:
		var sample_position = player.global_position + offset
		var floor_grid_pos = Vector2i(
			int(floor(sample_position.x / block_size)),
			int(floor(sample_position.y / block_size))
		)
		if grid_position_has_water_for_face_expression(floor_grid_pos):
			return true

		var round_grid_pos = Vector2i(
			int(round(sample_position.x / block_size)),
			int(round(sample_position.y / block_size))
		)
		if grid_position_has_water_for_face_expression(round_grid_pos):
			return true

	if world.has_method("get_player_grid_position"):
		var player_grid_pos = world.get_player_grid_position()
		if player_grid_pos is Vector2i and grid_position_has_water_for_face_expression(player_grid_pos):
			return true

	return false


func grid_position_has_water_for_face_expression(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	var block_sets = [
		world.get("blocks"),
		world.get("background_blocks")
	]

	for block_set in block_sets:
		if not (block_set is Dictionary):
			continue

		if not block_set.has(grid_pos):
			continue

		var block_data = block_set[grid_pos]
		var block_type = ""
		if block_data is Dictionary:
			block_type = str(block_data.get("type", "")).strip_edges().to_lower()
		else:
			block_type = str(block_data).strip_edges().to_lower()

		if block_type == "water":
			return true

	return false


func is_player_punching_for_face_expression() -> bool:
	if world == null:
		return false

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false

	var selected_item = world.get("selected_item_type")
	return selected_item != null and str(selected_item) == "punch"


func play_face_expression_animation(animation_name: String):
	if face_expression_animated == null or not (face_expression_animated is AnimatedSprite2D):
		return

	if face_expression_animated.sprite_frames == null:
		face_expression_animated.visible = false
		return

	var target_animation = get_available_face_expression_animation_name(animation_name)
	if target_animation == "":
		face_expression_animated.visible = false
		return

	face_expression_animated.visible = true
	if current_face_expression_animation != target_animation:
		current_face_expression_animation = target_animation
		face_expression_animated.play(target_animation)
	elif not face_expression_animated.is_playing() and face_expression_animated.sprite_frames.get_frame_count(target_animation) > 1:
		face_expression_animated.play(target_animation)


func get_available_face_expression_animation_name(animation_name: String) -> String:
	if face_expression_animated == null or face_expression_animated.sprite_frames == null:
		return ""

	var candidates = [animation_name]
	match animation_name:
		"underwater":
			candidates.append_array(["under_water", "under water", "Underwater", "Under Water"])
		"dead_spirit":
			candidates.append_array(["dead spirit", "Dead Spirit", "deadspirit", "DeadSpirit"])
		"talk":
			candidates.append_array(["talking", "Talking"])

	for candidate in candidates:
		var clean_candidate = str(candidate)
		if face_expression_animated.sprite_frames.has_animation(clean_candidate):
			return clean_candidate

	return get_available_animation_name(face_expression_animated, animation_name)


func update_movement_animation_player(animation_name: String):
	var target_animation = ""
	if animation_name == "walk":
		target_animation = "walk"
	elif animation_name == "jump":
		target_animation = "jump"
	elif animation_name == "idle":
		target_animation = "idle"

	if target_animation != "":
		var target_player = get_movement_animation_player(target_animation)
		if target_player == null:
			reset_current_movement_animation_player()
			return

		var actual_animation = get_movement_animation_name(target_player, target_animation)
		if actual_animation == "":
			reset_current_movement_animation_player()
			return

		if current_movement_animation_player != null and current_movement_animation_player != target_player:
			reset_current_movement_animation_player()

		current_movement_animation_player = target_player
		if current_movement_animation != actual_animation:
			current_movement_animation = actual_animation
			target_player.play(actual_animation)
		elif not target_player.is_playing():
			target_player.play(actual_animation)
		return

	reset_current_movement_animation_player()


func get_movement_animation_player(animation_name: String):
	if movement_animation_player != null and movement_animation_player.has_animation(animation_name):
		return movement_animation_player

	if movement_animation_player != null:
		var child_player = movement_animation_player.get_node_or_null(animation_name)
		if child_player == null:
			child_player = movement_animation_player.get_node_or_null(animation_name.capitalize())
		if child_player is AnimationPlayer and child_player.has_animation(animation_name):
			return child_player

	if player != null:
		var direct_player = player.get_node_or_null(animation_name)
		if direct_player == null:
			direct_player = player.get_node_or_null(animation_name.capitalize())
		if direct_player is AnimationPlayer and direct_player.has_animation(animation_name):
			return direct_player

	return null


func get_movement_animation_name(animation_player, animation_name: String) -> String:
	if animation_player == null:
		return ""

	if animation_player.has_animation(animation_name):
		return animation_name

	var capitalized_name = animation_name.capitalize()
	if animation_player.has_animation(capitalized_name):
		return capitalized_name

	var lower_name = animation_name.to_lower()
	if animation_player.has_animation(lower_name):
		return lower_name

	return ""


func reset_current_movement_animation_player():
	if current_movement_animation_player == null:
		current_movement_animation = ""
		return

	if current_movement_animation != "":
		current_movement_animation_player.stop()
		if current_movement_animation_player.has_animation(current_movement_animation):
			current_movement_animation_player.seek(0.0, true)

	current_movement_animation = ""
	current_movement_animation_player = null


func update_movement_animation_player_legacy_walk(animation_name: String):
	if movement_animation_player == null:
		return

	if animation_name == "walk" and movement_animation_player.has_animation("walk"):
		if current_movement_animation != "walk":
			current_movement_animation = "walk"
			movement_animation_player.play("walk")
		elif not movement_animation_player.is_playing():
			movement_animation_player.play("walk")
		return

	if current_movement_animation != "":
		current_movement_animation = ""
		movement_animation_player.stop()
		if movement_animation_player.has_animation("walk"):
			movement_animation_player.seek(0.0, true)


func get_player_animation_name() -> String:
	var velocity = Vector2.ZERO

	if player is CharacterBody2D:
		velocity = player.velocity

	var on_floor = true
	if player is CharacterBody2D:
		on_floor = player.is_on_floor()

	if not on_floor:
		if velocity.y > 8.0:
			return "fall"
		return "jump"

	if abs(velocity.x) > 6.0:
		return "walk"

	return "idle"


func play_layered_animation(animation_name: String):
	if not use_layered_body:
		return

	if animation_name == current_layered_animation:
		return

	current_layered_animation = animation_name

	for part in body_part_nodes.values():
		if not (part is AnimatedSprite2D):
			continue

		if part.sprite_frames == null:
			continue

		var target_animation = get_available_animation_name(part, animation_name)
		if target_animation == "":
			continue

		var animation_changed = part.animation != target_animation
		if animation_changed:
			part.animation = target_animation

		if part.sprite_frames.get_frame_count(target_animation) <= 1:
			part.stop()
			part.frame = 0
		elif animation_changed or not part.is_playing():
			part.play(target_animation)


func get_available_animation_name(part: AnimatedSprite2D, animation_name: String) -> String:
	if part == null or part.sprite_frames == null:
		return ""

	if part.sprite_frames.has_animation(animation_name):
		return animation_name

	if part.sprite_frames.has_animation("idle"):
		return "idle"

	var names = part.sprite_frames.get_animation_names()
	if names.size() > 0:
		return str(names[0])

	return ""


func update_facing(facing_direction: int):
	if facing_direction == 0:
		return

	var facing_left = facing_direction < 0

	if player_sprite != null:
		player_sprite.flip_h = facing_left

	if player_visual != null:
		var base_scale_x = abs(player_visual.scale.x)
		if base_scale_x <= 0.0:
			base_scale_x = 1.0
		player_visual.scale.x = -base_scale_x if facing_left else base_scale_x
		return

	for part in body_part_nodes.values():
		if part is AnimatedSprite2D:
			part.flip_h = facing_left


func reset_walk_animation():
	walk_timer = 0.0
	walk_frame_index = 0


func reset_idle_animation():
	idle_timer = 0.0
	idle_frame_index = 0


func set_sprite_texture(texture):
	if texture == null or player_sprite == null:
		return

	if current_texture == texture:
		return

	current_texture = texture
	player_sprite.texture = texture


func reload_animation_textures():
	setup_layered_body_parts()
	load_player_animation_textures()
