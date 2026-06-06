extends Node

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

var world = null
var player = null
var player_visual = null

var head_animated = null
var right_hand_animated = null
var left_hand_animated = null
var body_animated = null
var pants_animated = null
var right_foot_animated = null
var left_foot_animated = null

var hat_item_animated = null
var hair_item_animated = null
var facial_item_animated = null
var right_sleeve_animated = null
var right_hand_item_animated = null
var left_sleeve_animated = null
var left_hand_item_animated = null
var hand_item_animated = null
var body_accessory_item_animated = null
var shirt_item_animated = null
var pants_item_animated = null
var right_foot_item_animated = null
var left_foot_item_animated = null
var back_item_animated = null
var wearable_body_part_nodes = {}
var wearable_body_part_editor_positions = {}
var wearable_part_nodes = {}
var wearable_part_editor_positions = {}
var wearable_part_editor_scales = {}
var wearable_part_item_ids = {}
var wearable_animation_state = ""

var back_socket = null
var back_sprite = null
var back_socket_editor_position = Vector2.ZERO
var back_socket_right_marker = null
var back_socket_left_marker = null

var equipped_shoes_item = ""
var shoes_item_data = {}

var equipped_back_item = ""
var loaded_back_item = ""

var back_idle_texture = null
var back_flap_frames: Array = []
var back_anim_timer = 0.0
var back_anim_index = 0
var back_input_flap_timer = 0.0
var back_item_data = {}

var profile_equipment_saving_enabled = false
var last_profile_saved_tool = "__unset__"
var last_profile_saved_back_item = "__unset__"

const LOBBY_PROFILE_PATH = "user://pixelmania_profile.cfg"

const DEFAULT_BACK_FLAP_SPEED = 0.30
const DEFAULT_BACK_INPUT_FLAP_TIME = 0.28

# Back Item Default Slot v1
# BackSocket position is now editor-based. These constants are fallback values only.
# Most future wings/backpacks/capes only need item_database data + sprites.
const DEFAULT_BACK_SOCKET_RIGHT = Vector2(0, -12)
const DEFAULT_BACK_SOCKET_LEFT = Vector2(0, -12)
const DEFAULT_BACK_IDLE_SPRITE_OFFSET_RIGHT = Vector2(0, -10)
const DEFAULT_BACK_IDLE_SPRITE_OFFSET_LEFT = Vector2(0, -10)
const DEFAULT_BACK_FLAP_SPRITE_OFFSET_RIGHT = Vector2(0, -18)
const DEFAULT_BACK_FLAP_SPRITE_OFFSET_LEFT = Vector2(0, -18)
const DEFAULT_BACK_TARGET_WIDTH = 96.0
const DEFAULT_BACK_SCALE = 1.0
const DEFAULT_BACK_Z_INDEX = -20
const DEFAULT_BODY_LAYER_ANIMATED = Vector2(0, -8)
const DEFAULT_HEAD_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_BODY_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_PANTS_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_RIGHT_HAND_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_LEFT_HAND_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_LEFT_FOOT_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED
const DEFAULT_RIGHT_FOOT_ANIMATED = DEFAULT_BODY_LAYER_ANIMATED

# Hand item placement is editor-driven under RightHand/LeftHand.
const HAND_SLOT_SIZE = Vector2(32, 32)
const DEFAULT_RIGHT_HAND_ITEM_OFFSET = Vector2(1, -2)
const DEFAULT_LEFT_HAND_ITEM_OFFSET = Vector2(-2, -2)
const DEFAULT_HEAD_ITEM_OFFSET = Vector2(0, -14)
const DEFAULT_BODY_ITEM_OFFSET = Vector2(1, 4)
const DEFAULT_RIGHT_SLEEVE_OFFSET = Vector2(-5, 2)
const DEFAULT_LEFT_SLEEVE_OFFSET = Vector2(6, 3)
const DEFAULT_PANTS_ITEM_OFFSET = Vector2(0, 10)
const DEFAULT_FOOT_ITEM_OFFSET = Vector2(1, 14)
const DEFAULT_HAND_SCALE = 1.0
const DEFAULT_HAND_ROTATION_RIGHT = -10.0
const DEFAULT_HAND_ROTATION_LEFT = -10.0
const STANDARD_WEARABLE_ANIMATIONS = ["idle", "walk", "jump", "fall", "punch"]

func setup(parent_world, player_node):
	world = parent_world
	player = player_node
	player_visual = player.get_node_or_null("PlayerVisual") if player != null else null

	setup_back_socket()
	setup_wearable_animated_parts()

	update_equipped_tool_visual("", 1)
	update_equipped_back_visual("", 1)
	update_equipped_hair_visual("", 1)
	update_equipped_shirt_visual("", 1)
	update_equipped_pants_visual("", 1)
	update_equipped_shoes_visual("", 1)
	call_deferred("_enable_profile_equipment_saving")


func _process(delta):
	update_back_item_animation(delta)
	update_wearable_animation_state(delta)


func setup_back_socket():
	if player == null:
		return

	player_visual = player.get_node_or_null("PlayerVisual")
	back_socket = player.get_node_or_null("PlayerVisual/BackSlot")
	back_socket_right_marker = player.get_node_or_null("PlayerVisual/BackSlotRight")
	back_socket_left_marker = player.get_node_or_null("PlayerVisual/BackSlotLeft")

	# This is the editor-placed back item position.
	# Move BackSlot/BackItemAnimated in the 2D editor to tune wings/backpacks/capes.
	if back_socket != null:
		back_socket_editor_position = back_socket.position
		back_socket.visible = false

	back_sprite = player.get_node_or_null("PlayerVisual/BackSlot/BackItemAnimated")
	back_item_animated = back_sprite

	if back_sprite != null and back_sprite is AnimatedSprite2D:
		back_sprite.visible = false
		back_sprite.centered = true


func setup_wearable_animated_parts():
	if player == null:
		return

	player_visual = player.get_node_or_null("PlayerVisual")
	remove_legacy_wearable_slots()
	wearable_body_part_nodes.clear()
	wearable_body_part_editor_positions.clear()
	wearable_part_nodes.clear()
	wearable_part_editor_positions.clear()
	wearable_part_editor_scales.clear()
	wearable_part_item_ids.clear()

	head_animated = setup_body_part_node("head", "PlayerVisual/Head/BaseHeadAnimated", DEFAULT_HEAD_ANIMATED, 0)
	right_hand_animated = setup_body_part_node("right_arm", "PlayerVisual/RightArm/BaseRightArmAnimated", DEFAULT_RIGHT_HAND_ANIMATED, 0)
	left_hand_animated = setup_body_part_node("left_arm", "PlayerVisual/LeftArm/BaseLeftArmAnimated", DEFAULT_LEFT_HAND_ANIMATED, 0)
	body_animated = setup_body_part_node("body", "PlayerVisual/Body/BaseBodyAnimated", DEFAULT_BODY_ANIMATED, 0)
	pants_animated = setup_body_part_node("bottom", "PlayerVisual/Bottom/BaseBottomAnimated", DEFAULT_PANTS_ANIMATED, 0)
	right_foot_animated = setup_body_part_node("right_foot", "PlayerVisual/RightFoot/BaseRightFootAnimated", DEFAULT_RIGHT_FOOT_ANIMATED, 0)
	left_foot_animated = setup_body_part_node("left_foot", "PlayerVisual/LeftFoot/BaseLeftFootAnimated", DEFAULT_LEFT_FOOT_ANIMATED, 0)

	back_item_animated = setup_wearable_part_node("back", "PlayerVisual/BackSlot/BackItemAnimated", null, DEFAULT_BACK_IDLE_SPRITE_OFFSET_RIGHT, 0)
	hat_item_animated = setup_wearable_part_node("hat", "PlayerVisual/Head/HatAnimated", null, DEFAULT_HEAD_ITEM_OFFSET, 3)
	hair_item_animated = setup_wearable_part_node("hair", "PlayerVisual/Head/HairAnimated", null, DEFAULT_HEAD_ITEM_OFFSET, 2)
	facial_item_animated = setup_wearable_part_node("facial", "PlayerVisual/Head/FaceExpressionAnimated", null, DEFAULT_HEAD_ITEM_OFFSET, 3)
	right_sleeve_animated = setup_wearable_part_node("right_sleeve", "PlayerVisual/RightArm/RightSleeveAnimated", null, DEFAULT_RIGHT_SLEEVE_OFFSET, 1)
	left_sleeve_animated = setup_wearable_part_node("left_sleeve", "PlayerVisual/LeftArm/LeftSleeveAnimated", null, DEFAULT_LEFT_SLEEVE_OFFSET, 1)
	body_accessory_item_animated = setup_wearable_part_node("body_accessory", "PlayerVisual/Body/NecklaceAnimated", null, DEFAULT_BODY_ITEM_OFFSET, 2)
	shirt_item_animated = setup_wearable_part_node("shirt", "PlayerVisual/Body/ShirtBodyAnimated", null, DEFAULT_BODY_ITEM_OFFSET, 1)
	pants_item_animated = setup_wearable_part_node("pants", "PlayerVisual/Bottom/PantsAnimated", null, DEFAULT_PANTS_ITEM_OFFSET, 1)
	right_foot_item_animated = setup_wearable_part_node("right_foot_item", "PlayerVisual/RightFoot/RightShoeAnimated", null, DEFAULT_FOOT_ITEM_OFFSET, 2)
	left_foot_item_animated = setup_wearable_part_node("left_foot_item", "PlayerVisual/LeftFoot/LeftShoeAnimated", null, DEFAULT_FOOT_ITEM_OFFSET, 2)
	hand_item_animated = setup_wearable_part_node("hand_item", "PlayerVisual/HandItem/HandItemAnimated", null, DEFAULT_RIGHT_HAND_ITEM_OFFSET, 2)
	right_hand_item_animated = hand_item_animated
	left_hand_item_animated = hand_item_animated


func setup_body_part_node(part_key: String, node_name: String, default_position: Vector2, _default_z_index: int):
	var part = player.get_node_or_null(node_name)
	if part != null and not (part is AnimatedSprite2D):
		return null

	if part == null:
		return null

	part.visible = true
	part.centered = true
	wearable_body_part_nodes[part_key] = part
	wearable_body_part_editor_positions[part_key] = part.position
	return part


func setup_wearable_part_node(part_key: String, node_name: String, parent_node, default_position: Vector2, _default_z_index: int):
	var part = player.get_node_or_null(node_name)
	if part == null and parent_node != null:
		part = parent_node.get_node_or_null(node_name)
	if part != null and not (part is AnimatedSprite2D):
		return null

	if part == null:
		return null

	part.visible = false
	part.centered = true
	wearable_part_nodes[part_key] = part
	wearable_part_editor_positions[part_key] = part.position
	wearable_part_editor_scales[part_key] = part.scale if part.scale != Vector2.ZERO else Vector2.ONE
	return part


func remove_legacy_wearable_slots():
	if player == null:
		return

	for node_name in [
		"HandSocket",
		"HandSocketRight",
		"HandSocketLeft",
		"FrontSocket",
		"FrontSlot",
		"ShirtRightArmSlot",
		"RightArmSlot",
		"ShirtLeftArmSlot",
		"LeftArmSlot",
		"ShirtBodyAnimated",
		"RightArmAnimated",
		"LeftArmAnimated",
		"HeadAnimated",
		"RightHandAnimated",
		"LeftHandAnimated",
		"BodyAnimated",
		"PantsAnimated",
		"RightFootAnimated",
		"LeftFootAnimated",
		"PantSlot",
		"PantsSlot",
		"PantSocket",
		"PantsSocket",
		"ShoesSlot",
		"LeftShoeSlot",
		"RightShoeSlot",
		"LeftShoeAnimated",
		"RightShoeAnimated",
		"HairSlot",
		"HairSocket",
		"HairAnimated",
		"HatSlot"
	]:
		var legacy_node = player.get_node_or_null(node_name)
		if legacy_node != null:
			legacy_node.queue_free()


func get_wearable_part(part_key: String):
	if wearable_part_nodes.has(part_key):
		return wearable_part_nodes[part_key]

	setup_wearable_animated_parts()

	if wearable_part_nodes.has(part_key):
		return wearable_part_nodes[part_key]

	return null


func hide_wearable_part(part_key: String):
	var part = get_wearable_part(part_key)
	if part == null:
		return

	part.visible = false
	wearable_part_item_ids.erase(part_key)


func hide_wearable_parts(part_keys: Array):
	for part_key in part_keys:
		hide_wearable_part(str(part_key))


func set_wearable_part(
	part_key: String,
	item_id: String,
	item_data: Dictionary,
	texture_specs: Array,
	_part_position: Vector2,
	_is_facing_left: bool,
	_flip_with_facing: bool = true,
	_scale_value: float = 1.0,
	_z_value: int = 1
):
	var part = get_wearable_part(part_key)
	if part == null:
		return false

	var current_item_id = str(wearable_part_item_ids.get(part_key, ""))
	if current_item_id != item_id or part.sprite_frames == null:
		var sprite_frames = build_wearable_sprite_frames(item_data, part_key, texture_specs)
		if sprite_frames == null:
			hide_wearable_part(part_key)
			return false
		part.sprite_frames = sprite_frames
		wearable_part_item_ids[part_key] = item_id

	part.visible = true
	play_wearable_part_animation(part, get_current_wearable_animation_name())
	return true


func get_wearable_part_base_scale(part_key: String) -> Vector2:
	if wearable_part_editor_scales.has(part_key):
		var scale_value = wearable_part_editor_scales[part_key]
		if scale_value is Vector2 and scale_value != Vector2.ZERO:
			return scale_value

	return Vector2.ONE


func get_wearable_part_base_position(part_key: String, fallback: Vector2) -> Vector2:
	if wearable_part_editor_positions.has(part_key):
		var position = wearable_part_editor_positions[part_key]
		if position is Vector2:
			return position

	return fallback


func get_body_part_base_position(part_key: String, fallback: Vector2) -> Vector2:
	if wearable_body_part_editor_positions.has(part_key):
		var position = wearable_body_part_editor_positions[part_key]
		if position is Vector2:
			return position

	return fallback


func to_body_part_local_position(absolute_position: Vector2, _body_part_key: String, fallback_body_position: Vector2) -> Vector2:
	return absolute_position - fallback_body_position


func build_wearable_sprite_frames(item_data: Dictionary, part_key: String, fallback_texture_specs: Array):
	var sprite_frames = SpriteFrames.new()
	for animation_name in sprite_frames.get_animation_names():
		sprite_frames.remove_animation(animation_name)

	var added_any = add_animation_map_to_sprite_frames(sprite_frames, item_data, part_key)
	if not added_any:
		added_any = add_single_animation_to_sprite_frames(sprite_frames, "idle", fallback_texture_specs, float(item_data.get("animation_fps", 6.0)), true)

	if not added_any:
		return null

	ensure_standard_wearable_animations(sprite_frames)
	return sprite_frames


func ensure_standard_wearable_animations(sprite_frames: SpriteFrames):
	if sprite_frames == null:
		return

	var fallback_animation = "idle"
	if not sprite_frames.has_animation(fallback_animation):
		var names = sprite_frames.get_animation_names()
		if names.size() <= 0:
			return
		fallback_animation = str(names[0])

	for animation_name in STANDARD_WEARABLE_ANIMATIONS:
		if sprite_frames.has_animation(animation_name):
			continue
		copy_sprite_frames_animation(sprite_frames, fallback_animation, str(animation_name))


func copy_sprite_frames_animation(sprite_frames: SpriteFrames, source_animation: String, target_animation: String):
	if sprite_frames == null:
		return

	if not sprite_frames.has_animation(source_animation):
		return

	if sprite_frames.has_animation(target_animation):
		return

	sprite_frames.add_animation(target_animation)
	sprite_frames.set_animation_speed(target_animation, sprite_frames.get_animation_speed(source_animation))
	sprite_frames.set_animation_loop(target_animation, sprite_frames.get_animation_loop(source_animation))

	var frame_count = sprite_frames.get_frame_count(source_animation)
	for frame_index in range(frame_count):
		var texture = sprite_frames.get_frame_texture(source_animation, frame_index)
		var duration = sprite_frames.get_frame_duration(source_animation, frame_index)
		if texture != null:
			sprite_frames.add_frame(target_animation, texture, duration)


func add_animation_map_to_sprite_frames(sprite_frames: SpriteFrames, item_data: Dictionary, part_key: String) -> bool:
	var animation_map = get_animation_map_for_part(item_data, part_key)
	if animation_map.is_empty():
		return false

	var added_any = false
	for animation_name_value in animation_map.keys():
		var animation_name = str(animation_name_value)
		var animation_spec = animation_map[animation_name_value]
		var fps = float(item_data.get("animation_fps", 6.0))
		var loop = true
		var frame_specs = []

		if animation_spec is Dictionary:
			var animation_spec_dict: Dictionary = animation_spec
			if animation_spec_dict.has("frames") or animation_spec_dict.has("textures"):
				frame_specs = get_array_from_data(animation_spec_dict.get("frames", animation_spec_dict.get("textures", [])))
				fps = float(animation_spec_dict.get("fps", animation_spec_dict.get("speed", fps)))
				loop = bool(animation_spec_dict.get("loop", true))
			else:
				frame_specs = [animation_spec_dict]
		elif animation_spec is Array:
			frame_specs = animation_spec
		else:
			frame_specs = [animation_spec]

		if add_single_animation_to_sprite_frames(sprite_frames, animation_name, frame_specs, fps, loop):
			added_any = true

	return added_any


func add_single_animation_to_sprite_frames(sprite_frames: SpriteFrames, animation_name: String, frame_specs: Array, fps: float, loop: bool) -> bool:
	if animation_name == "":
		return false

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(animation_name, max(0.1, fps))
	sprite_frames.set_animation_loop(animation_name, loop)

	var added_count = 0
	for frame_spec in frame_specs:
		var texture = AtlasTextureFactory.load_texture(frame_spec)
		if texture == null:
			continue

		sprite_frames.add_frame(animation_name, texture)
		added_count += 1

	if added_count <= 0:
		sprite_frames.remove_animation(animation_name)
		return false

	return true


func get_animation_map_for_part(item_data: Dictionary, part_key: String) -> Dictionary:
	var part_animation_key = part_key + "_animations"
	var direct_map = item_data.get(part_animation_key, {})
	if direct_map is Dictionary and not direct_map.is_empty():
		return direct_map

	var all_animations = item_data.get("animations", {})
	if all_animations is Dictionary:
		var animations_dict: Dictionary = all_animations
		if animations_dict.has(part_key):
			var part_animation_map = animations_dict.get(part_key, {})
			if part_animation_map is Dictionary:
				return part_animation_map

		if not animation_dictionary_is_part_grouped(animations_dict):
			return animations_dict

	return {}


func animation_dictionary_is_part_grouped(animation_map: Dictionary) -> bool:
	for value in animation_map.values():
		if value is Dictionary:
			var value_dict: Dictionary = value
			if not (value_dict.has("frames") or value_dict.has("textures") or value_dict.has("path") or value_dict.has("texture_path") or value_dict.has("atlas")):
				return true

	return false


func get_array_from_data(value) -> Array:
	if value is Array:
		return value

	if value == null:
		return []

	return [value]


func update_wearable_animation_state(_delta: float):
	var animation_name = get_current_wearable_animation_name()
	if animation_name == wearable_animation_state:
		return

	wearable_animation_state = animation_name
	for part_key in wearable_part_nodes.keys():
		if str(part_key) == "facial":
			continue

		var part = wearable_part_nodes[part_key]
		if part is AnimatedSprite2D and part.visible:
			play_wearable_part_animation(part, animation_name)


func get_current_wearable_animation_name() -> String:
	if player != null and player is CharacterBody2D:
		if not player.is_on_floor():
			if player.velocity.y > 8.0:
				return "fall"
			return "jump"

		if abs(player.velocity.x) > 6.0:
			return "walk"

	return "idle"


func play_wearable_part_animation(part: AnimatedSprite2D, animation_name: String):
	if part == null or part.sprite_frames == null:
		return

	var target_animation = animation_name
	if not part.sprite_frames.has_animation(target_animation):
		if part.sprite_frames.has_animation("idle"):
			target_animation = "idle"
		else:
			var names = part.sprite_frames.get_animation_names()
			if names.size() <= 0:
				return
			target_animation = str(names[0])

	var animation_changed = part.animation != target_animation
	if animation_changed:
		part.animation = target_animation

	if part.sprite_frames.get_frame_count(target_animation) <= 1:
		part.stop()
		part.frame = 0
	elif animation_changed or not part.is_playing():
		part.play(target_animation)


func update_equipped_tool_visual(equipped_tool: String, facing_direction: int):
	if player == null:
		return

	if profile_equipment_saving_enabled:
		save_lobby_equipment_state_if_changed(str(equipped_tool), get_current_back_item_for_profile())

	if hand_item_animated == null:
		setup_wearable_animated_parts()

	if equipped_tool == "":
		hide_tool()
		return

	if world == null or not world.tool_textures.has(equipped_tool):
		hide_tool()
		return

	var item_data = {}

	if world != null and world.item_database.has(equipped_tool):
			item_data = world.item_database[equipped_tool]

	if not bool(item_data.get("hand_item", true)):
		hide_tool()
		return

	var texture = world.tool_textures[equipped_tool]

	if texture == null:
		hide_tool()
		return

	apply_hand_item_transform(equipped_tool, texture, item_data, facing_direction)


func get_safe_back_socket_editor_position() -> Vector2:
	if back_socket_editor_position == null:
		if back_socket != null:
			back_socket_editor_position = back_socket.position
		else:
			back_socket_editor_position = DEFAULT_BACK_SOCKET_RIGHT

	return back_socket_editor_position


func get_editor_back_socket_position(is_facing_left: bool) -> Vector2:
	# Wings/back items are usually centered behind the player.
	# Default behavior: use the SAME BackSocket position when turning.
	# This prevents wings from jumping/offsetting sideways.
	#
	# Optional advanced setup:
	# - Add BackSocketRight and BackSocketLeft marker nodes under Player.
	# - The code will use those exact marker positions.
	#
	# Optional item override:
	# - "mirror_back_socket": true makes the socket mirror X when facing left.
	var editor_position = get_safe_back_socket_editor_position()

	if is_facing_left:
		if back_socket_left_marker != null:
			return back_socket_left_marker.position

		if bool(back_item_data.get("mirror_back_socket", false)):
			return Vector2(-editor_position.x, editor_position.y)

		return editor_position

	if back_socket_right_marker != null:
		return back_socket_right_marker.position

	return editor_position


func apply_hand_item_transform(item_id: String, texture, item_data: Dictionary, facing_direction: int):
	if texture == null:
		return

	var is_facing_left = facing_direction < 0
	set_wearable_part("hand_item", item_id, item_data, [texture], Vector2.ZERO, is_facing_left, false, 1.0, 0)


func get_hand_item_local_position(item_data: Dictionary, is_facing_left: bool, fallback_position: Vector2) -> Vector2:
	var offset = get_vector_from_data(item_data.get("hand_sprite_offset", [fallback_position.x, fallback_position.y]), fallback_position)
	if is_facing_left:
		return get_vector_from_data(item_data.get("hand_sprite_offset_left", [-offset.x, offset.y]), Vector2(-offset.x, offset.y))

	return offset


func get_hand_item_rotation(item_data: Dictionary, is_facing_left: bool) -> float:
	if is_facing_left:
		return float(item_data.get("hand_rotation_left", -float(item_data.get("hand_rotation", DEFAULT_HAND_ROTATION_RIGHT))))

	return float(item_data.get("hand_rotation", DEFAULT_HAND_ROTATION_RIGHT))



func update_equipped_back_visual(back_item, facing_direction: int):
	if player == null:
		return

	if back_item == null:
		back_item = ""

	back_item = str(back_item)

	if profile_equipment_saving_enabled:
		save_lobby_equipment_state_if_changed(get_current_tool_item_for_profile(), back_item)

	if back_socket == null or back_sprite == null:
		setup_back_socket()

	if back_socket == null or back_sprite == null:
		return

	if back_item == "":
		back_socket.visible = false
		hide_wearable_part("back")
		equipped_back_item = ""
		loaded_back_item = ""
		return

	var item_data = get_back_item_data(back_item)

	if item_data.is_empty():
		back_socket.visible = false
		hide_wearable_part("back")
		return

	if loaded_back_item != back_item:
		load_back_item_visual_data(back_item)

	equipped_back_item = back_item
	back_socket.visible = true

	var is_facing_left = facing_direction < 0
	var sprite_frames = build_back_item_sprite_frames()
	if sprite_frames == null:
		back_socket.visible = false
		hide_wearable_part("back")
		return

	if str(wearable_part_item_ids.get("back", "")) != back_item or back_sprite.sprite_frames == null:
		back_sprite.sprite_frames = sprite_frames
		wearable_part_item_ids["back"] = back_item

	back_sprite.visible = true
	play_wearable_part_animation(back_sprite, get_current_wearable_animation_name())


func update_equipped_hair_visual(hair_item, facing_direction: int):
	if player == null:
		return

	if hair_item == null:
		hair_item = ""

	hair_item = str(hair_item)

	if hair_item == "":
		hide_wearable_part("hair")
		return

	var item_data = {}
	if world != null and world.item_database.has(hair_item):
		var raw_data = world.item_database[hair_item]
		if raw_data is Dictionary:
			item_data = raw_data

	var texture = null
	if world != null and world.hair_textures.has(hair_item):
		texture = world.hair_textures[hair_item]
	else:
		texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))

	if texture == null:
		hide_wearable_part("hair")
		return

	var is_facing_left = facing_direction < 0
	var part_position = Vector2.ZERO
	var scale_value = float(item_data.get("slot_scale", 1.0))
	var z_value = int(item_data.get("slot_z_index", 2))
	set_wearable_part("hair", hair_item, item_data, [texture], part_position, is_facing_left, bool(item_data.get("hair_flip_with_facing", true)), scale_value, z_value)


func update_equipped_shirt_visual(shirt_item, facing_direction: int):
	if player == null:
		return

	if shirt_item == null:
		shirt_item = ""

	shirt_item = str(shirt_item)

	if shirt_item == "":
		hide_wearable_parts(["shirt", "right_sleeve", "left_sleeve"])
		return

	var item_data = {}
	if world != null and world.item_database.has(shirt_item):
		var raw_data = world.item_database[shirt_item]
		if raw_data is Dictionary:
			item_data = raw_data

	var texture = null
	if world != null and world.shirt_textures.has(shirt_item):
		texture = world.shirt_textures[shirt_item]
	else:
		texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))

	if texture == null:
		hide_wearable_parts(["shirt", "right_sleeve", "left_sleeve"])
		return

	var is_facing_left = facing_direction < 0
	var body_position = Vector2.ZERO
	var front_scale_value = float(item_data.get("slot_scale", 1.0))
	var front_z_value = int(item_data.get("front_z_index", item_data.get("slot_z_index", 1)))
	set_wearable_part("shirt", shirt_item, item_data, [texture], body_position, is_facing_left, bool(item_data.get("front_flip_with_facing", true)), front_scale_value, front_z_value)
	update_shirt_arm_items(item_data, is_facing_left, shirt_item)


func update_equipped_pants_visual(pants_item, facing_direction: int):
	if player == null:
		return

	if pants_item == null:
		pants_item = ""

	pants_item = str(pants_item)

	if pants_item == "":
		hide_wearable_part("pants")
		return

	var item_data = {}
	if world != null and world.item_database.has(pants_item):
		var raw_data = world.item_database[pants_item]
		if raw_data is Dictionary:
			item_data = raw_data

	var texture = null
	if world != null and world.pants_textures.has(pants_item):
		texture = world.pants_textures[pants_item]
	else:
		texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))

	if texture == null:
		hide_wearable_part("pants")
		return

	var is_facing_left = facing_direction < 0
	var part_position = Vector2.ZERO
	var scale_value = float(item_data.get("slot_scale", 1.0))
	var z_value = int(item_data.get("slot_z_index", 1))
	set_wearable_part("pants", pants_item, item_data, [texture], part_position, is_facing_left, bool(item_data.get("pants_flip_with_facing", true)), scale_value, z_value)


func update_equipped_shoes_visual(shoes_item, facing_direction: int):
	if player == null:
		return

	if shoes_item == null:
		shoes_item = ""

	shoes_item = str(shoes_item)

	if shoes_item == "":
		hide_wearable_parts(["left_foot_item", "right_foot_item"])
		equipped_shoes_item = ""
		shoes_item_data = {}
		return

	var item_data = {}
	if world != null and world.item_database.has(shoes_item):
		var raw_data = world.item_database[shoes_item]
		if raw_data is Dictionary:
			item_data = raw_data

	var left_texture = AtlasTextureFactory.load_texture(item_data.get("left_shoe_texture", null))
	var right_texture = AtlasTextureFactory.load_texture(item_data.get("right_shoe_texture", null))
	var pair_texture = null
	if world != null and world.shoes_textures.has(shoes_item):
		pair_texture = world.shoes_textures[shoes_item]
	else:
		pair_texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))

	if left_texture == null:
		left_texture = pair_texture
	if right_texture == null:
		right_texture = pair_texture

	if left_texture == null or right_texture == null:
		hide_wearable_parts(["left_foot_item", "right_foot_item"])
		return

	equipped_shoes_item = shoes_item
	shoes_item_data = item_data
	var is_facing_left = facing_direction < 0
	var scale_value = float(item_data.get("shoe_scale", item_data.get("slot_scale", 1.0)))
	var z_value = int(item_data.get("shoe_z_index", item_data.get("slot_z_index", 2)))
	set_wearable_part("left_foot_item", shoes_item, item_data, [left_texture], Vector2.ZERO, is_facing_left, true, scale_value, z_value)
	set_wearable_part("right_foot_item", shoes_item, item_data, [right_texture], Vector2.ZERO, is_facing_left, true, scale_value, z_value)


func update_shirt_arm_items(item_data: Dictionary, is_facing_left: bool, shirt_item: String):
	var right_arm_texture = AtlasTextureFactory.load_texture(item_data.get("right_arm_texture", item_data.get("arm_texture", null)))
	var left_arm_texture = AtlasTextureFactory.load_texture(item_data.get("left_arm_texture", item_data.get("left_sleeve_texture", null)))
	if left_arm_texture == null:
		left_arm_texture = right_arm_texture

	if right_arm_texture == null or left_arm_texture == null:
		hide_wearable_parts(["right_sleeve", "left_sleeve"])
		return

	var scale_value = float(item_data.get("arm_scale", item_data.get("slot_scale", 1.0)))
	var z_value = int(item_data.get("arm_z_index", item_data.get("slot_z_index", 1)))

	set_wearable_part("right_sleeve", shirt_item, item_data, [right_arm_texture], Vector2.ZERO, is_facing_left, true, scale_value, z_value)
	set_wearable_part("left_sleeve", shirt_item, item_data, [left_arm_texture], Vector2.ZERO, not is_facing_left, true, scale_value, z_value)


func hide_shirt_arm_items():
	hide_wearable_parts(["right_sleeve", "left_sleeve"])


func update_shoes_animation(delta: float):
	update_wearable_animation_state(delta)


func apply_shoes_transform(facing_direction: int):
	if equipped_shoes_item == "":
		return

	update_equipped_shoes_visual(equipped_shoes_item, facing_direction)


func hide_shoes():
	hide_wearable_parts(["left_foot_item", "right_foot_item"])


func get_front_sprite_offset(item_data: Dictionary, is_facing_left: bool) -> Vector2:
	return get_slot_item_offset(item_data, is_facing_left)


func get_slot_item_offset(item_data: Dictionary, is_facing_left: bool) -> Vector2:
	var fallback = get_vector_from_data(item_data.get("slot_offset", [0, 0]), Vector2.ZERO)

	if is_facing_left:
		return get_vector_from_data(item_data.get("slot_offset_left", [fallback.x, fallback.y]), fallback)

	return fallback



func load_back_item_visual_data(back_item: String):
	loaded_back_item = back_item
	equipped_back_item = back_item
	back_item_data = get_back_item_data(back_item)

	back_idle_texture = null
	back_flap_frames.clear()
	back_anim_timer = 0.0
	back_anim_index = 0
	back_input_flap_timer = 0.0

	if back_item_data.is_empty():
		return

	var sprite_folder = str(back_item_data.get("sprite_folder", ""))

	if sprite_folder != "" and not sprite_folder.ends_with("/"):
		sprite_folder += "/"

	var idle_candidates = []

	var idle_sprite = str(back_item_data.get("idle_sprite", ""))

	if idle_sprite != "":
		idle_candidates.append(make_sprite_path(sprite_folder, idle_sprite))

	if back_item_data.has("texture"):
		idle_candidates.append(back_item_data.get("texture"))

	# Helpful fallback for the current project folder.
	if back_item == "legendary_wings":
		idle_candidates.append("res://Assets/player/back_item/legendary_wings/legendary_wings_idle.png")
		idle_candidates.append("res://Assets/player/back_item/legendary_wings/legendary_wings_flap1.png")
		idle_candidates.append("res://Assets/player/back_item/legendary_wings/legendary_wings_flap2.png")

	back_idle_texture = load_first_existing_texture(idle_candidates)

	var flap_frame_names = back_item_data.get("flap_frames", [])

	if flap_frame_names is Array:
		for frame_name in flap_frame_names:
			if frame_name is Dictionary or frame_name is Texture2D:
				var frame_texture = AtlasTextureFactory.load_texture(frame_name)
				if frame_texture != null:
					back_flap_frames.append(frame_texture)
				continue

			var frame_path = make_sprite_path(sprite_folder, str(frame_name))

			if ResourceLoader.exists(frame_path):
				var frame_texture = load(frame_path)

				if frame_texture != null:
					back_flap_frames.append(frame_texture)

	if bool(back_item_data.get("scan_flap_frames", true)) and sprite_folder != "":
		load_flap_frames_from_directory(sprite_folder)

	if back_idle_texture == null and back_flap_frames.size() > 0:
		back_idle_texture = back_flap_frames[0]

	if back_idle_texture != null:
		if world != null:
			world.back_textures[back_item] = back_idle_texture


func build_back_item_sprite_frames():
	var idle_specs = []
	if back_idle_texture != null:
		idle_specs.append(back_idle_texture)
	elif back_flap_frames.size() > 0:
		idle_specs.append(back_flap_frames[0])

	if idle_specs.is_empty():
		return null

	var sprite_frames = SpriteFrames.new()
	for animation_name in sprite_frames.get_animation_names():
		sprite_frames.remove_animation(animation_name)

	var idle_fps = float(back_item_data.get("animation_fps", 6.0))
	add_single_animation_to_sprite_frames(sprite_frames, "idle", idle_specs, idle_fps, true)
	add_single_animation_to_sprite_frames(sprite_frames, "walk", idle_specs, idle_fps, true)
	add_single_animation_to_sprite_frames(sprite_frames, "punch", idle_specs, idle_fps, false)

	var air_specs = back_flap_frames.duplicate()
	if air_specs.is_empty():
		air_specs = idle_specs

	var air_fps = 1.0 / max(0.01, get_back_flap_speed())
	add_single_animation_to_sprite_frames(sprite_frames, "jump", air_specs, air_fps, true)
	add_single_animation_to_sprite_frames(sprite_frames, "fall", air_specs, air_fps, true)
	ensure_standard_wearable_animations(sprite_frames)
	return sprite_frames


func update_back_item_animation(delta):
	if equipped_back_item == "":
		return

	var part = get_wearable_part("back")
	if part is AnimatedSprite2D and part.visible:
		play_wearable_part_animation(part, get_current_wearable_animation_name())


func update_back_item_input_flap_timer(delta: float):
	if back_input_flap_timer == null:
		back_input_flap_timer = 0.0

	if back_input_flap_timer > 0.0:
		back_input_flap_timer = max(0.0, float(back_input_flap_timer) - delta)

	if Input.is_action_pressed("ui_accept"):
		back_input_flap_timer = get_back_input_flap_time()

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP):
		back_input_flap_timer = get_back_input_flap_time()


func should_back_item_flap() -> bool:
	if back_item_data.is_empty():
		return false

	if not bool(back_item_data.get("flap_animation", false)):
		return false

	if back_input_flap_timer == null:
		back_input_flap_timer = 0.0

	if float(back_input_flap_timer) > 0.0:
		return true

	if player == null:
		return false

	if player is CharacterBody2D:
		if abs(player.velocity.y) > 8.0:
			return true

		if not player.is_on_floor():
			return true

	return false



func get_back_socket_offset(is_facing_left: bool) -> Vector2:
	if is_facing_left:
		return get_vector_from_data(
			back_item_data.get("back_offset_left", back_item_data.get("back_offset", [0, 0])),
			Vector2.ZERO
		)

	return get_vector_from_data(
		back_item_data.get("back_offset", [0, 0]),
		Vector2.ZERO
	)


func get_back_idle_sprite_offset(is_facing_left: bool) -> Vector2:
	if is_facing_left:
		return get_vector_from_data(
			back_item_data.get("idle_sprite_offset_left", [DEFAULT_BACK_IDLE_SPRITE_OFFSET_LEFT.x, DEFAULT_BACK_IDLE_SPRITE_OFFSET_LEFT.y]),
			DEFAULT_BACK_IDLE_SPRITE_OFFSET_LEFT
		)

	return get_vector_from_data(
		back_item_data.get("idle_sprite_offset", [DEFAULT_BACK_IDLE_SPRITE_OFFSET_RIGHT.x, DEFAULT_BACK_IDLE_SPRITE_OFFSET_RIGHT.y]),
		DEFAULT_BACK_IDLE_SPRITE_OFFSET_RIGHT
	)


func get_back_flap_sprite_offset(is_facing_left: bool) -> Vector2:
	if is_facing_left:
		return get_vector_from_data(
			back_item_data.get("flap_sprite_offset_left", [DEFAULT_BACK_FLAP_SPRITE_OFFSET_LEFT.x, DEFAULT_BACK_FLAP_SPRITE_OFFSET_LEFT.y]),
			DEFAULT_BACK_FLAP_SPRITE_OFFSET_LEFT
		)

	return get_vector_from_data(
		back_item_data.get("flap_sprite_offset", [DEFAULT_BACK_FLAP_SPRITE_OFFSET_RIGHT.x, DEFAULT_BACK_FLAP_SPRITE_OFFSET_RIGHT.y]),
		DEFAULT_BACK_FLAP_SPRITE_OFFSET_RIGHT
	)




func get_back_idle_pivot_offset(is_facing_left: bool) -> Vector2:
	# Per-item correction for the actual sprite artwork.
	# This is the "snapping point" adjustment for this specific back item.
	if is_facing_left:
		return get_vector_from_data(
			back_item_data.get("back_pivot_offset_left", back_item_data.get("back_pivot_offset", [0, 0])),
			Vector2.ZERO
		)

	return get_vector_from_data(
		back_item_data.get("back_pivot_offset", [0, 0]),
		Vector2.ZERO
	)


func get_back_flap_pivot_offset(is_facing_left: bool) -> Vector2:
	# Optional separate correction for flap frames.
	# If not set, it falls back to the idle pivot offset.
	if is_facing_left:
		return get_vector_from_data(
			back_item_data.get(
				"flap_pivot_offset_left",
				back_item_data.get("flap_pivot_offset", back_item_data.get("back_pivot_offset_left", back_item_data.get("back_pivot_offset", [0, 0])))
			),
			Vector2.ZERO
		)

	return get_vector_from_data(
		back_item_data.get("flap_pivot_offset", back_item_data.get("back_pivot_offset", [0, 0])),
		Vector2.ZERO
	)

func apply_back_item_texture(texture):
	return


func apply_back_sprite_auto_scale(texture):
	return



func apply_back_sprite_state_offset(is_flapping: bool):
	return



func get_back_item_data(back_item: String) -> Dictionary:
	if world != null and world.item_database.has(back_item):
		var item_data = world.item_database[back_item]

		if item_data is Dictionary:
			return item_data

	return {}


func get_back_flap_speed() -> float:
	return float(back_item_data.get("flap_speed", DEFAULT_BACK_FLAP_SPEED))


func get_back_input_flap_time() -> float:
	return float(back_item_data.get("input_flap_time", DEFAULT_BACK_INPUT_FLAP_TIME))


func should_flip_back_item_with_facing(is_facing_left: bool) -> bool:
	if not is_facing_left:
		return false

	return bool(back_item_data.get("back_flip_with_facing", true))


func make_sprite_path(sprite_folder: String, file_name: String) -> String:
	if file_name == "":
		return ""

	if file_name.begins_with("res://"):
		return file_name

	return sprite_folder + file_name


func load_first_existing_texture(paths: Array):
	return AtlasTextureFactory.load_first_existing(paths)


func load_flap_frames_from_directory(directory_path: String):
	var dir = DirAccess.open(directory_path)

	if dir == null:
		return

	var file_names = []
	dir.list_dir_begin()

	while true:
		var file_name = dir.get_next()

		if file_name == "":
			break

		if dir.current_is_dir():
			continue

		var lower_name = file_name.to_lower()

		if not lower_name.ends_with(".png"):
			continue

		if lower_name.find("flap") == -1:
			continue

		file_names.append(file_name)

	dir.list_dir_end()
	file_names.sort()

	for file_name in file_names:
		var path = directory_path + file_name

		if ResourceLoader.exists(path):
			var texture = load(path)

			if texture != null and not back_flap_frames.has(texture):
				back_flap_frames.append(texture)


func get_vector_from_data(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	return fallback



func _enable_profile_equipment_saving():
	profile_equipment_saving_enabled = true
	save_lobby_equipment_state_if_changed(get_current_tool_item_for_profile(), get_current_back_item_for_profile())


func get_current_tool_item_for_profile() -> String:
	if world == null:
		return ""

	var value = world.get("equipped_tool")

	if value == null:
		return ""

	return str(value)


func get_current_back_item_for_profile() -> String:
	if world == null:
		return str(equipped_back_item)

	var value = world.get("equipped_back_item")

	if value == null:
		return str(equipped_back_item)

	return str(value)


func save_lobby_equipment_state_if_changed(tool_item: String, back_item: String):
	if not profile_equipment_saving_enabled:
		return

	if tool_item == null:
		tool_item = ""

	if back_item == null:
		back_item = ""

	tool_item = str(tool_item)
	back_item = str(back_item)

	if tool_item == last_profile_saved_tool and back_item == last_profile_saved_back_item:
		return

	last_profile_saved_tool = tool_item
	last_profile_saved_back_item = back_item

	var cfg = ConfigFile.new()
	cfg.load(LOBBY_PROFILE_PATH)
	cfg.set_value("equipment", "equipped_tool", tool_item)
	cfg.set_value("equipment", "equipped_back_item", back_item)
	cfg.save(LOBBY_PROFILE_PATH)


func hide_tool():
	hide_wearable_part("hand_item")


func hide_back_item():
	if back_socket != null:
		back_socket.visible = false
	hide_wearable_part("back")


func hide_front_item():
	hide_wearable_parts(["shirt", "right_sleeve", "left_sleeve"])


func hide_shoe_item():
	hide_shoes()
