extends Node

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const FishingMinigameUI = preload("res://Scripts/ui/fishing_minigame_ui.gd")

# PixelMania Fishing Manager v2
#
# Minigame UI is built entirely in code — no scene file dependency.
# States: IDLE → CASTING → WAITING → BITE → MINIGAME → (catch or fail)

var world = null

const BOBBER_SCENE_PATH = "res://Scenes/fishing_bobber.tscn"

# ── State constants ───────────────────────────────────────────
const STATE_IDLE      = "idle"
const STATE_CASTING   = "casting"
const STATE_WAITING   = "waiting"
const STATE_BITE      = "bite"
const STATE_MINIGAME  = "minigame"

# ── Timing ────────────────────────────────────────────────────
const CAST_ANIMATION_TIME  = 0.35
const BITE_MIN_TIME        = 2.0
const BITE_MAX_TIME        = 5.5
const REACTION_WINDOW_TIME = 2.2
const MINIGAME_DURATION    = 5.0
const CATCH_POPUP_DURATION = 3.6
# How long the client waits for the server to acknowledge a "fishing_start" request before
# giving up and re-enabling casting. Without this, a dropped/lost server response (network
# hiccup, especially common on mobile connections) left the client stuck showing "Casting
# with X..." forever: fishing_active never gets set to true (that only happens once the
# server's ack arrives, in start_local_cast()), so there was nothing to time out and no way
# to retry short of leaving the world.
const CAST_ACK_TIMEOUT_TIME = 8.0
# How long the reeling minigame allows the player to do nothing before the fish gets away.
# Previously there was no timeout at all: mg_progress/mg_tension are clamped to >= 0.0, so an
# idle (or AFK, or mobile reel-button-missed) player just sat at 0 forever with the minigame
# never resolving either way.
const MINIGAME_AFK_TIMEOUT_TIME = 20.0
const FISHING_LINE_SEGMENTS = 16
const FISHING_LINE_SAG = 26.0
const FISHING_LINE_WAVE_AMPLITUDE = 2.0
const FISHING_LINE_WAVE_FREQUENCY = 1.6
const FISHING_LINE_WAVE_SPEED = 4.2
const FISHING_BOBBER_Z_OFFSET = -4

# ── Fishing state ─────────────────────────────────────────────
var state               = STATE_IDLE
var state_timer         = 0.0
var bobber              = null
var bobber_anim         = null
var fishing_line        = null
var fishing_line_start  = null
var fishing_line_end    = null
var fishing_line_wave_phase = 0.0
var current_lure_id     = ""
var pending_fish_id     = ""
var pending_reward_category = "fish"
var pending_fish_data   = {}
var server_fishing_session_id = ""
var waiting_for_server_catch = false
var awaiting_cast_ack    = false
var cast_ack_timer       = 0.0

# ── Minigame state ────────────────────────────────────────────
var mg_cursor_t         = 0.0
var mg_cursor_dir       = 1.0
var mg_green_start      = 0.38
var mg_green_size       = 0.24
var mg_cursor_speed     = 1.35
var mg_time_left        = 0.0
var mg_progress         = 0.0
var mg_tension          = 0.0
var mg_fish_resist_phase = 0.0
var mg_reel_rate        = 0.22
var mg_tension_gain     = 0.22
var mg_tension_release  = 0.32
var mg_progress_decay   = 0.030
var mg_afk_timer        = 0.0

# ── Dedicated fishing UI ──────────────────────────────────────
var fishing_ui          = null
var cast_selected_item_type = ""
var cast_selected_item_category = ""
var cast_world_name     = ""

# ── Fishing records / journal data ────────────────────────────
const FISHING_RECORDS_VERSION := 1
const RARITY_SCORE := {
	"common": 1,
	"uncommon": 2,
	"rare": 3,
	"epic": 4,
	"legendary": 5
}

var fishing_records: Dictionary = {}

# ── Catch popup state ─────────────────────────────────────────
var catch_popup_timer   = 0.0

# ── Minigame UI nodes ─────────────────────────────────────────
var mg_panel            = null
var mg_fish_icon        = null
var mg_fish_name        = null
var mg_rarity_label     = null
var mg_lure_label       = null
var mg_time_bar_fill    = null
var mg_bar_bg           = null
var mg_green_zone       = null
var mg_cursor_bar       = null
var mg_hint_label       = null

# ── Catch popup UI nodes ──────────────────────────────────────
var catch_popup         = null
var catch_icon          = null
var catch_name_label    = null
var catch_rarity_label  = null


# ── Setup ─────────────────────────────────────────────────────

func setup(world_ref):
	world = world_ref
	ensure_fishing_records()
	_setup_fishing_ui()
	reset_fishing_state(false)


func is_fishing_active() -> bool:
	if world != null and "fishing_active" in world and bool(world.fishing_active):
		return true

	return state != STATE_IDLE or waiting_for_server_catch


# ── Public API ────────────────────────────────────────────────

func is_fishing_rod_item(item_id: String) -> bool:
	if world != null and world.has_method("is_fishing_rod_item"):
		return bool(world.is_fishing_rod_item(item_id))
	var clean_item_id := normalize_fishing_rod_id(item_id)
	return clean_item_id in [
		"wooden_fishing_rod",
		"bamboo_fishing_rod",
		"fiberglass_fishing_rod",
		"platinum_rod",
		"golden_fishing_rod",
		"neptune_rod"
	]


func normalize_fishing_rod_id(item_id: String) -> String:
	var clean_item_id := str(item_id).strip_edges()
	match clean_item_id:
		"fishing_rod":
			return "bamboo_fishing_rod"
		"platinum_prestige_rod":
			return "golden_fishing_rod"
		_:
			return clean_item_id


func get_active_fishing_rod_id() -> String:
	if world == null:
		return ""
	if str(world.selected_item_category) == "tool" and is_fishing_rod_item(str(world.selected_item_type)):
		return str(world.selected_item_type)
	if is_fishing_rod_item(str(world.equipped_tool)):
		return str(world.equipped_tool)
	return ""


func use_fishing_rod_at_mouse(preferred_lure_id: String = ""):
	if world.fishing_active:
		handle_fishing_action()
		return

	if awaiting_cast_ack:
		world.show_notification("Still casting, please wait...")
		return

	var target_grid = world.get_mouse_grid_position()

	if not can_reach_fishing_grid(target_grid):
		world.show_notification("Water must be within 4 tiles.")
		return

	if not is_fishable_water(target_grid):
		world.show_notification("Cast a fishing rod on water.")
		return

	var lure_id = ""
	if preferred_lure_id != "" and world.lure_inventory.has(preferred_lure_id) and int(world.lure_inventory[preferred_lure_id]) > 0:
		lure_id = preferred_lure_id
	else:
		lure_id = get_best_available_lure()

	if lure_id == "":
		world.show_notification("You need a lure to fish.")
		return

	start_cast(target_grid, lure_id)


func use_selected_lure_at_mouse():
	if world.fishing_active:
		handle_fishing_action()
		return

	if not is_fishing_rod_item(str(world.equipped_tool)):
		world.show_notification("Equip a fishing rod first.")
		return

	if not world.lure_inventory.has(world.selected_item_type) or int(world.lure_inventory[world.selected_item_type]) <= 0:
		world.show_notification("You don't have any " + world.get_item_display_name(world.selected_item_type, "lure") + ".")
		return

	use_fishing_rod_at_mouse(world.selected_item_type)


func cancel_fishing():
	if not world.fishing_active:
		return
	world.show_notification("Fishing cancelled.")
	if fishing_ui != null and fishing_ui.has_method("hide_all"):
		fishing_ui.hide_all()
	play_bobber_anim("reel_fail")
	if server_fishing_session_id != "":
		request_server_fishing_complete(false)
	reset_fishing_state(true)


# ── Cast ──────────────────────────────────────────────────────

func start_cast(target_grid: Vector2i, lure_id: String):
	if world != null and world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if request_server_fishing_start(target_grid, lure_id):
			awaiting_cast_ack = true
			cast_ack_timer    = 0.0
			world.show_notification("Casting with " + world.get_item_display_name(lure_id, "lure") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if request_server_fishing_start(target_grid, lure_id):
		awaiting_cast_ack = true
		cast_ack_timer    = 0.0
		world.show_notification("Casting with " + world.get_item_display_name(lure_id, "lure") + "...")
		return

	start_local_cast(target_grid, lure_id, true, "", {})


func start_local_cast(target_grid: Vector2i, lure_id: String, spend_lure: bool = true, session_id: String = "", fish_data: Dictionary = {}):
	awaiting_cast_ack = false
	cast_ack_timer    = 0.0
	if spend_lure:
		world.lure_inventory[lure_id] = max(0, int(world.lure_inventory.get(lure_id, 0)) - 1)

	world.fishing_lure_id   = lure_id
	world.fishing_target_grid = target_grid
	world.fishing_timer     = 0.0
	world.fishing_active    = true

	current_lure_id  = lure_id
	pending_fish_data = fish_data.duplicate(true)
	pending_fish_id  = str(pending_fish_data.get("item_id", pending_fish_data.get("fish_id", "")))
	pending_reward_category = str(pending_fish_data.get("item_category", pending_fish_data.get("category", "fish"))).strip_edges()
	if pending_reward_category == "" and str(pending_fish_data.get("fish_id", "")) != "":
		pending_reward_category = "fish"
	server_fishing_session_id = session_id
	waiting_for_server_catch = false
	cast_selected_item_type = str(world.selected_item_type)
	cast_selected_item_category = str(world.selected_item_category)
	cast_world_name = str(world.current_world_name)
	state            = STATE_CASTING
	state_timer      = CAST_ANIMATION_TIME

	spawn_bobber(target_grid)
	play_bobber_anim("cast")
	flush_fishing_visual_sync()
	_show_waiting_ui()

	if spend_lure:
		world.update_all_ui()
		world.save_player_data()
	world.show_notification("Casting with " + world.get_item_display_name(lure_id, "lure") + "...")


func request_server_fishing_start(target_grid: Vector2i, lure_id: String) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("has_active_session") and not bool(network.has_active_session()):
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	var rod_id := get_active_fishing_rod_id()
	if rod_id == "":
		return false

	return bool(network.send_inventory_transaction_request({
		"action": "fishing_start",
		"world": world.current_world_name,
		"target_x": target_grid.x,
		"target_y": target_grid.y,
		"rod_id": rod_id,
		"lure_id": lure_id
	}))


# ── Bobber ────────────────────────────────────────────────────

func spawn_bobber(target_grid: Vector2i):
	clear_bobber()

	if not ResourceLoader.exists(BOBBER_SCENE_PATH):
		return

	var scene = load(BOBBER_SCENE_PATH)
	if scene == null:
		return

	bobber = scene.instantiate()
	world.add_child(bobber)
	apply_bobber_draw_order()
	bobber.global_position = Vector2(
		target_grid.x * world.BLOCK_SIZE,
		target_grid.y * world.BLOCK_SIZE
	)
	bobber_anim = bobber.get_node_or_null("AnimationPlayer")
	fishing_line_wave_phase = 0.0
	cache_fishing_line_nodes()
	update_fishing_line(0.0)


func play_bobber_anim(anim_name: String):
	if bobber_anim != null and bobber_anim.has_animation(anim_name):
		bobber_anim.play(anim_name)


func apply_bobber_draw_order():
	if bobber == null or not is_instance_valid(bobber) or not (bobber is CanvasItem):
		return

	var player_z := 0
	if world != null and world.player != null and world.player is CanvasItem:
		player_z = int(world.player.z_index)

	bobber.z_as_relative = false
	bobber.z_index = player_z + FISHING_BOBBER_Z_OFFSET


func clear_bobber():
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()
	bobber      = null
	bobber_anim = null
	fishing_line = null
	fishing_line_start = null
	fishing_line_end = null
	fishing_line_wave_phase = 0.0


func cache_fishing_line_nodes():
	fishing_line = null
	fishing_line_start = null
	fishing_line_end = null

	if bobber != null and is_instance_valid(bobber):
		fishing_line = bobber.get_node_or_null("FishingLine")
		fishing_line_end = bobber.get_node_or_null("Sprite2D/FishingLineEnd")
		if fishing_line_end == null:
			fishing_line_end = bobber.get_node_or_null("FishingLineEnd")

	fishing_line_start = get_fishing_line_start_marker(get_fishing_line_rod_id(), true)


func update_fishing_line(delta: float = 0.0):
	if fishing_line == null or not is_instance_valid(fishing_line):
		return

	if delta > 0.0:
		fishing_line_wave_phase = wrapf(fishing_line_wave_phase + delta * FISHING_LINE_WAVE_SPEED, 0.0, PI * 2.0)

	var start_global_position = get_fishing_line_start_global_position()

	if fishing_line_end == null or not is_instance_valid(fishing_line_end):
		if bobber != null and is_instance_valid(bobber):
			fishing_line_end = bobber.get_node_or_null("Sprite2D/FishingLineEnd")

	if start_global_position == null or fishing_line_end == null:
		fishing_line.visible = false
		return

	fishing_line.visible = true
	var start_pos: Vector2 = fishing_line.to_local(start_global_position)
	var end_pos: Vector2 = fishing_line.to_local(fishing_line_end.global_position)
	fishing_line.points = get_wavy_fishing_line_points(start_pos, end_pos)


func refresh_fishing_line_after_transforms():
	if world == null or not world.fishing_active:
		return
	update_fishing_line(0.0)


func get_wavy_fishing_line_points(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var line_delta: Vector2 = end_pos - start_pos
	var line_length: float = line_delta.length()

	if line_length <= 0.1:
		points.append(start_pos)
		points.append(end_pos)
		return points

	var normal := Vector2(-line_delta.y, line_delta.x).normalized()
	var sag_scale: float = clamp(line_length / 240.0, 0.35, 1.4)
	var wave_amplitude := FISHING_LINE_WAVE_AMPLITUDE
	if state == STATE_BITE:
		wave_amplitude *= 1.8
	elif state == STATE_MINIGAME:
		wave_amplitude *= 1.25

	for i in range(FISHING_LINE_SEGMENTS + 1):
		var t: float = float(i) / float(FISHING_LINE_SEGMENTS)
		var fade: float = sin(t * PI)
		var sag: Vector2 = Vector2.DOWN * FISHING_LINE_SAG * sag_scale * fade
		var wave: Vector2 = normal * sin((t * FISHING_LINE_WAVE_FREQUENCY * PI * 2.0) + fishing_line_wave_phase) * wave_amplitude * fade
		points.append(start_pos.lerp(end_pos, t) + sag + wave)

	return points


func get_fishing_line_start_global_position():
	var rod_id := get_fishing_line_rod_id()
	var rod_marker = get_fishing_line_start_marker(rod_id, false)
	if rod_marker != null:
		return rod_marker.global_position

	var hand_item_sprite = get_hand_item_sprite_node()
	if hand_item_sprite is Node2D:
		var rod_data := get_fishing_rod_item_data(rod_id)
		if rod_data.has("fishing_line_tip_offset"):
			var texture_size := get_hand_item_sprite_texture_size(hand_item_sprite, rod_id)
			var facing_left := get_current_player_fishing_facing() < 0
			var tip_local_position := get_fishing_line_tip_local_position(hand_item_sprite, rod_data, texture_size, facing_left)
			return hand_item_sprite.to_global(tip_local_position)

		var fallback_texture_size := get_fishing_rod_texture_size(rod_id)
		if fallback_texture_size != Vector2.ZERO:
			return hand_item_sprite.to_global(get_texture_right_edge_local_position(hand_item_sprite, fallback_texture_size))

	var fallback_marker = get_fishing_line_start_marker(rod_id, true)
	if fallback_marker != null:
		return fallback_marker.global_position

	return null


func get_fishing_line_start_marker(rod_id: String = "", include_generic: bool = true):
	if world == null or world.player == null:
		return null

	if rod_id != "":
		for marker_path in [
			"PlayerVisual/HandItem/FishingLineStart_" + rod_id,
			"PlayerVisual/HandItem/HandItemAnimated/FishingLineStart_" + rod_id
		]:
			var rod_marker = world.player.get_node_or_null(marker_path)
			if rod_marker is Node2D:
				return rod_marker

	if include_generic:
		for marker_path in [
			"PlayerVisual/HandItem/FishingLineStart",
			"PlayerVisual/HandItem/HandItemAnimated/FishingLineStart",
			"PlayerVisual/HandItem/PlatinumPrestigeRod/FishingLineStart"
		]:
			var marker = world.player.get_node_or_null(marker_path)
			if marker is Node2D:
				return marker

		var hand_item = world.player.get_node_or_null("PlayerVisual/HandItem")
		if hand_item != null:
			var marker = hand_item.find_child("FishingLineStart", true, false)
			if marker is Node2D:
				return marker

	return null


func get_fishing_line_rod_id() -> String:
	if world == null:
		return ""
	if is_fishing_rod_item(str(world.equipped_tool)):
		return str(world.equipped_tool)
	if cast_selected_item_type != "" and is_fishing_rod_item(cast_selected_item_type):
		return cast_selected_item_type
	if str(world.selected_item_category) == "tool" and is_fishing_rod_item(str(world.selected_item_type)):
		return str(world.selected_item_type)
	return get_active_fishing_rod_id()


func get_fishing_rod_item_data(rod_id: String) -> Dictionary:
	if world == null or rod_id == "":
		return {}
	if world.item_database.has(rod_id):
		var item_data = world.item_database[rod_id]
		if item_data is Dictionary:
			return item_data
	return {}


func get_hand_item_sprite_node():
	if world == null or world.player == null:
		return null
	return world.player.get_node_or_null("PlayerVisual/HandItem/HandItemAnimated")


func get_current_player_fishing_facing() -> int:
	if world == null:
		return 1

	if world.player != null:
		var player_facing = world.player.get("facing_dir")
		if player_facing != null:
			return -1 if int(player_facing) < 0 else 1

	return -1 if int(world.player_facing_direction) < 0 else 1


func is_hand_item_sprite_rendering_rod(rod_id: String) -> bool:
	if world == null:
		return false
	var clean_rod_id := normalize_fishing_rod_id(rod_id)
	if clean_rod_id == "":
		return false
	return normalize_fishing_rod_id(str(world.equipped_tool)) == clean_rod_id


func get_hand_item_sprite_texture_size(hand_item_sprite, rod_id: String) -> Vector2:
	if is_hand_item_sprite_rendering_rod(rod_id):
		var texture = get_hand_item_sprite_texture(hand_item_sprite)
		if texture != null:
			return texture.get_size()
	return get_fishing_rod_texture_size(rod_id)


func get_hand_item_sprite_texture(hand_item_sprite):
	if hand_item_sprite is AnimatedSprite2D:
		var sprite := hand_item_sprite as AnimatedSprite2D
		if sprite.sprite_frames == null:
			return null
		var animation_name: StringName = sprite.animation
		if not sprite.sprite_frames.has_animation(animation_name):
			return null
		var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
		if frame_count <= 0:
			return null
		var frame_index := clampi(sprite.frame, 0, frame_count - 1)
		return sprite.sprite_frames.get_frame_texture(animation_name, frame_index)

	if hand_item_sprite is Sprite2D:
		return (hand_item_sprite as Sprite2D).texture

	return null


func get_fishing_line_tip_local_position(hand_item_sprite, rod_data: Dictionary, texture_size: Vector2, facing_left: bool) -> Vector2:
	var has_left_tip := facing_left and rod_data.has("fishing_line_tip_offset_left")
	var tip_value = rod_data.get("fishing_line_tip_offset_left", Vector2.ZERO) if has_left_tip else rod_data.get("fishing_line_tip_offset", Vector2.ZERO)
	var tip_position := get_vector2_from_data(tip_value, Vector2.ZERO)

	if texture_size == Vector2.ZERO:
		return tip_position

	if facing_left and not has_left_tip and is_hand_item_sprite_flipped(hand_item_sprite):
		tip_position.x = texture_size.x - tip_position.x

	if is_hand_item_sprite_centered(hand_item_sprite):
		tip_position -= texture_size * 0.5

	return tip_position


func get_texture_right_edge_local_position(hand_item_sprite, texture_size: Vector2) -> Vector2:
	if is_hand_item_sprite_centered(hand_item_sprite):
		return Vector2(texture_size.x * 0.5, 0.0)
	return Vector2(texture_size.x, texture_size.y * 0.5)


func is_hand_item_sprite_centered(hand_item_sprite) -> bool:
	if hand_item_sprite is AnimatedSprite2D:
		return bool((hand_item_sprite as AnimatedSprite2D).centered)
	if hand_item_sprite is Sprite2D:
		return bool((hand_item_sprite as Sprite2D).centered)
	return false


func is_hand_item_sprite_flipped(hand_item_sprite) -> bool:
	if hand_item_sprite is AnimatedSprite2D:
		return bool((hand_item_sprite as AnimatedSprite2D).flip_h)
	if hand_item_sprite is Sprite2D:
		return bool((hand_item_sprite as Sprite2D).flip_h)
	return false


func get_fishing_rod_texture_size(rod_id: String) -> Vector2:
	if world == null or rod_id == "":
		return Vector2.ZERO
	if world.tool_textures.has(rod_id):
		var texture = world.tool_textures[rod_id]
		if texture != null:
			return texture.get_size()
	return Vector2.ZERO


func get_vector2_from_data(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


# ── Input dispatch ────────────────────────────────────────────

func handle_fishing_action():
	match state:
		STATE_BITE:
			start_minigame()
		STATE_MINIGAME:
			pass
		STATE_CASTING, STATE_WAITING:
			world.show_notification("Wait for a bite...")
		_:
			pass


# ── Update loop ───────────────────────────────────────────────

func update_fishing(delta: float):
	# This check must run even while fishing_active is still false: the client doesn't flip
	# fishing_active to true until start_local_cast() runs, which only happens once the
	# server's "fishing_start" ack arrives (see start_cast()/handle_inventory_transaction_result).
	# If that ack is dropped, awaiting_cast_ack would otherwise stay true forever with nothing
	# ever ticking it down.
	if awaiting_cast_ack:
		cast_ack_timer += delta
		if cast_ack_timer >= CAST_ACK_TIMEOUT_TIME:
			awaiting_cast_ack = false
			cast_ack_timer    = 0.0
			world.show_notification("Casting failed. Try again.")

	if not world.fishing_active:
		if state != STATE_IDLE:
			reset_fishing_state(false)
		return

	if _should_cancel_for_cleanup_rule():
		fail_fishing("Fish escaped...")
		return

	update_fishing_line(delta)
	call_deferred("refresh_fishing_line_after_transforms")

	match state:
		STATE_CASTING:
			state_timer -= delta
			if state_timer <= 0.0:
				state       = STATE_WAITING
				state_timer = randf_range(BITE_MIN_TIME, BITE_MAX_TIME)
				play_bobber_anim("idle_float")
				_show_waiting_ui()

		STATE_WAITING:
			state_timer -= delta
			if state_timer <= 0.0:
				trigger_bite()

		STATE_BITE:
			if _is_reeling_input_down():
				start_minigame()
				return
			state_timer -= delta
			_update_bite_ui()
			if state_timer <= 0.0:
				fail_fishing("The fish got away!")

		STATE_MINIGAME:
			_update_minigame(delta)


# ── Bite ──────────────────────────────────────────────────────

func trigger_bite():
	if not is_fishable_water(world.fishing_target_grid):
		fail_fishing("The fish got away!")
		return

	if pending_fish_data.is_empty():
		pending_fish_data = _roll_fish_entry(current_lure_id, get_active_fishing_rod_id())

	pending_fish_id = str(pending_fish_data.get("item_id", pending_fish_data.get("fish_id", "")))
	pending_reward_category = str(pending_fish_data.get("item_category", pending_fish_data.get("category", "fish"))).strip_edges()
	if pending_reward_category == "" and str(pending_fish_data.get("fish_id", "")) != "":
		pending_reward_category = "fish"

	if pending_fish_id == "":
		fail_fishing("Nothing bit the lure.")
		return

	state       = STATE_BITE
	state_timer = REACTION_WINDOW_TIME

	play_bobber_anim("bite")
	if fishing_ui != null and fishing_ui.has_method("show_bite"):
		fishing_ui.show_bite(REACTION_WINDOW_TIME)


# ── Minigame ──────────────────────────────────────────────────

func start_minigame():
	state         = STATE_MINIGAME
	mg_time_left  = MINIGAME_DURATION
	mg_afk_timer  = 0.0
	_configure_minigame(pending_fish_id, current_lure_id)
	if fishing_ui != null and fishing_ui.has_method("show_reeling"):
		fishing_ui.show_reeling(mg_progress, mg_tension, false)


func _configure_minigame(_fish_id: String, lure_id: String):
	var difficulty  = int(pending_fish_data.get("difficulty", 1))
	var lure_bonus  = _lure_bonus(lure_id)

	mg_green_size   = clamp(0.34 - (difficulty * 0.035) + lure_bonus, 0.13, 0.38)
	mg_cursor_speed = clamp(1.0 + (difficulty * 0.18) - (lure_bonus * 1.2), 0.9, 2.2)
	mg_green_start  = randf_range(0.10, 0.88 - mg_green_size)
	mg_cursor_t     = 0.0
	mg_cursor_dir   = 1.0
	mg_progress     = 0.0
	mg_tension      = clamp(0.08 + difficulty * 0.018, 0.06, 0.24)
	mg_fish_resist_phase = randf_range(0.0, TAU)
	mg_reel_rate = clamp(0.28 - difficulty * 0.012 + lure_bonus * 0.70, 0.16, 0.34)
	mg_tension_gain = clamp(0.18 + difficulty * 0.035 - lure_bonus * 0.48, 0.16, 0.46)
	mg_tension_release = clamp(0.34 + lure_bonus * 0.65, 0.30, 0.52)
	mg_progress_decay = clamp(0.030 + difficulty * 0.004, 0.026, 0.065)


func _populate_mg_info():
	if world == null:
		return

	var reward_category := get_pending_reward_category()
	var fish_name = world.get_item_display_name(pending_fish_id, reward_category)
	var rarity    = "common"
	if world.item_database.has(pending_fish_id):
		rarity = str(world.item_database[pending_fish_id].get("rarity", "common"))

	if mg_fish_name != null:
		mg_fish_name.text = fish_name

	if mg_rarity_label != null:
		mg_rarity_label.text = rarity.capitalize()
		mg_rarity_label.add_theme_color_override("font_color", _rarity_color(rarity))

	if mg_fish_icon != null:
		mg_fish_icon.texture = get_reward_texture(pending_fish_id, reward_category)

	if mg_lure_label != null:
		mg_lure_label.text = world.get_item_display_name(current_lure_id, "lure")


func _update_minigame(delta: float):
	mg_time_left = max(0.0, mg_time_left - delta)
	mg_fish_resist_phase += delta * mg_cursor_speed
	var fish_resist = 0.5 + sin(mg_fish_resist_phase) * 0.5
	var reeling := _is_reeling_input_down()

	if reeling:
		mg_afk_timer = 0.0
		var safe_tension = clamp(1.0 - max(0.0, mg_tension - 0.62) * 0.82, 0.35, 1.0)
		mg_progress += mg_reel_rate * safe_tension * (1.0 - fish_resist * 0.20) * delta
		mg_tension += (mg_tension_gain + fish_resist * 0.20) * delta
	else:
		mg_afk_timer += delta
		mg_progress -= mg_progress_decay * delta
		mg_tension -= mg_tension_release * delta

	mg_progress = clamp(mg_progress, 0.0, 1.0)
	mg_tension = clamp(mg_tension, 0.0, 1.0)

	if fishing_ui != null and fishing_ui.has_method("show_reeling"):
		fishing_ui.show_reeling(mg_progress, mg_tension, reeling)

	if mg_progress >= 1.0:
		catch_fish()
		return

	if mg_tension >= 1.0:
		fail_fishing("The fish snapped the line!")
		return

	# No timeout previously existed here at all -- mg_progress/mg_tension are clamped to
	# >= 0.0, so an AFK (or unresponsive-input) player just sat at 0 forever with the
	# minigame never resolving. 20 continuous seconds of no reeling input now ends it.
	if mg_afk_timer >= MINIGAME_AFK_TIMEOUT_TIME:
		fail_fishing("The fish swam away while you were away.")
		return


func try_finish_minigame():
	if mg_cursor_t >= mg_green_start and mg_cursor_t <= (mg_green_start + mg_green_size):
		catch_fish()
	else:
		fail_fishing("Missed! The fish escaped.")


# ── Catch / Fail ──────────────────────────────────────────────

func catch_fish():
	if pending_fish_id == "":
		fail_fishing("Nothing bit the lure.")
		return

	if server_fishing_session_id != "":
		if request_server_fishing_complete(true):
			play_bobber_anim("reel_success")
			waiting_for_server_catch = true
			reset_fishing_state(true)
			return

		fail_fishing("Connection required to finish fishing.")
		return

	var reward_category := get_pending_reward_category()
	if reward_category != "fish":
		var added := add_reward_to_inventory(pending_fish_id, reward_category, 1)
		if added <= 0:
			fail_fishing("Could not save fishing reward.")
			return
		_show_catch_result(pending_fish_id, false, -1.0, reward_category)
		_show_catch_notification(pending_fish_id, reward_category)
		_maybe_spawn_fishing_reward_confetti(pending_fish_id, reward_category)
		play_bobber_anim("reel_success")
		world.update_all_ui()
		world.save_player_data()
		reset_fishing_state(true)
		return

	var owned_before: float = _get_owned_fish_weight(pending_fish_id)
	var catch_weight: float = _normalize_fish_weight(_roll_catch_weight(pending_fish_id))
	var catch_record: Dictionary = record_fish_catch(pending_fish_id, catch_weight)
	var was_new: bool = bool(catch_record.get("was_new", owned_before <= 0.0))
	_add_fish_weight_to_inventory(pending_fish_id, catch_weight)

	_show_catch_result(pending_fish_id, was_new, catch_weight)
	_show_catch_notification(pending_fish_id, "fish")
	_maybe_broadcast_legendary_catch(pending_fish_id)
	_maybe_spawn_fishing_reward_confetti(pending_fish_id, "fish")
	play_bobber_anim("reel_success")
	world.update_all_ui()
	world.save_player_data()
	reset_fishing_state(true)


func _normalize_fish_weight(weight) -> float:
	return snapped(max(0.0, float(weight)), 0.1)


func _fish_weight_to_tenths(weight) -> int:
	return _fish_inventory_value_to_tenths(weight)


func _fish_inventory_value_to_tenths(value) -> int:
	if value is int:
		return max(0, int(value))
	if value is float:
		var raw_float: float = float(value)
		if not is_finite(raw_float) or raw_float <= 0.0:
			return 0
		return max(0, int(floor(raw_float)))
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_int():
			return max(0, int(text))
		if text.is_valid_float():
			return max(0, int(floor(float(text))))
	return 0


func _fish_tenths_to_weight(tenths: int) -> float:
	return float(max(0, tenths))


func _legacy_tenths_to_fish_count(value) -> int:
	var tenths: int = _fish_inventory_value_to_tenths(value)
	if tenths <= 0:
		return 0
	return max(1, int(round(float(tenths) / 10.0)))


func _get_owned_fish_weight(fish_id: String) -> float:
	if world == null or fish_id == "":
		return 0.0
	return _fish_tenths_to_weight(_fish_inventory_value_to_tenths(world.fish_inventory.get(fish_id, 0)))


func _add_fish_weight_to_inventory(fish_id: String, weight) -> void:
	if world == null or fish_id == "":
		return
	var safe_weight: float = _normalize_fish_weight(weight)
	if safe_weight <= 0.0:
		return
	var current_count: int = _fish_inventory_value_to_tenths(world.fish_inventory.get(fish_id, 0))
	world.fish_inventory[fish_id] = current_count + 1
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(fish_id, "fish")


func has_inventory_delta_payload(data: Dictionary) -> bool:
	var raw_delta = null
	if data.has("inventory_delta"):
		raw_delta = data.get("inventory_delta")
	elif data.has("inventory_deltas"):
		raw_delta = data.get("inventory_deltas")
	else:
		return false
	return (raw_delta is Dictionary and not raw_delta.is_empty()) or (raw_delta is Array and raw_delta.size() > 0)


func _apply_server_fish_inventory_result(data: Dictionary, fish_id: String, catch_weight) -> void:
	if world == null or fish_id == "":
		return
	if has_inventory_delta_payload(data):
		return

	var inventory_payload = data.get("fish_inventory", null)
	if inventory_payload is Dictionary and inventory_payload.has(fish_id):
		if str(data.get("fish_inventory_unit", data.get("unit", ""))) == "tenths_lb":
			world.fish_inventory[fish_id] = _legacy_tenths_to_fish_count(inventory_payload.get(fish_id, 0))
		else:
			world.fish_inventory[fish_id] = _fish_inventory_value_to_tenths(inventory_payload.get(fish_id, 0))
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(fish_id, "fish")
		return

	for tenths_key in ["owned_weight_tenths", "total_weight_tenths", "fish_weight_tenths", "new_weight_tenths", "weight_tenths"]:
		if data.has(tenths_key):
			world.fish_inventory[fish_id] = _legacy_tenths_to_fish_count(data.get(tenths_key, 0))
			if world.has_method("refresh_ui_after_item_change"):
				world.refresh_ui_after_item_change(fish_id, "fish")
			return

	for key in ["owned_weight_lb", "total_weight_lb", "fish_weight_lb", "new_weight_lb"]:
		if data.has(key):
			world.fish_inventory[fish_id] = _fish_inventory_value_to_tenths(data.get(key, 0.0))
			if world.has_method("refresh_ui_after_item_change"):
				world.refresh_ui_after_item_change(fish_id, "fish")
			return

	_add_fish_weight_to_inventory(fish_id, catch_weight)


func _apply_server_reward_inventory_result(data: Dictionary, item_id: String, category: String) -> void:
	if world == null or item_id == "":
		return
	if has_inventory_delta_payload(data):
		return

	var safe_category := normalize_reward_category(category)
	var inventory = get_reward_inventory_for_category(safe_category)
	if not (inventory is Dictionary):
		return

	var inventory_field := get_inventory_field_for_reward_category(safe_category)
	var player_data = data.get("player_data", null)
	if player_data is Dictionary:
		var player_inventory = player_data.get(inventory_field, null)
		if player_inventory is Dictionary and player_inventory.has(item_id):
			inventory[item_id] = int(player_inventory.get(item_id, 0))
			if world.has_method("refresh_ui_after_item_change"):
				world.refresh_ui_after_item_change(item_id, safe_category)
			return

	var inventory_payload = data.get(inventory_field, null)
	if inventory_payload is Dictionary and inventory_payload.has(item_id):
		inventory[item_id] = int(inventory_payload.get(item_id, 0))
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(item_id, safe_category)
		return

	add_reward_to_inventory(item_id, safe_category, 1)


func add_reward_to_inventory(item_id: String, category: String, amount: int) -> int:
	if world == null or item_id == "":
		return 0

	var safe_category := normalize_reward_category(category)
	var inventory = get_reward_inventory_for_category(safe_category)
	if not (inventory is Dictionary):
		return 0

	if world.has_method("add_item_to_inventory_stack"):
		return int(world.add_item_to_inventory_stack(inventory, item_id, safe_category, amount))

	var current_count: int = max(0, int(inventory.get(item_id, 0)))
	var next_count: int = current_count + max(0, amount)
	inventory[item_id] = next_count
	if next_count != current_count and world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(item_id, safe_category)
	return next_count - current_count


func normalize_reward_category(category: String) -> String:
	var safe_category := str(category).strip_edges().to_lower()
	if safe_category in ["block", "seed", "tool", "back", "hat", "hair", "eyewear", "shirt", "pants", "shoes", "ride", "currency", "material", "lure", "fish"]:
		return safe_category
	var pending_category := pending_reward_category.strip_edges().to_lower()
	if pending_category in ["block", "seed", "tool", "back", "hat", "hair", "eyewear", "shirt", "pants", "shoes", "ride", "currency", "material", "lure", "fish"]:
		return pending_category
	return "fish"


func get_pending_reward_category() -> String:
	return normalize_reward_category(pending_reward_category)


func get_inventory_field_for_reward_category(category: String) -> String:
	match normalize_reward_category(category):
		"block":
			return "inventory"
		"seed":
			return "seed_inventory"
		"tool":
			return "tool_inventory"
		"back":
			return "back_inventory"
		"hat":
			return "hat_inventory"
		"hair":
			return "hair_inventory"
		"eyewear":
			return "eyewear_inventory"
		"shirt":
			return "shirt_inventory"
		"pants":
			return "pants_inventory"
		"shoes":
			return "shoes_inventory"
		"ride":
			return "ride_inventory"
		"currency":
			return "currency_inventory"
		"material":
			return "material_inventory"
		"lure":
			return "lure_inventory"
		"fish":
			return "fish_inventory"
		_:
			return ""


func get_reward_inventory_for_category(category: String):
	if world == null:
		return null

	match normalize_reward_category(category):
		"block":
			return world.inventory
		"seed":
			return world.seed_inventory
		"tool":
			return world.tool_inventory
		"back":
			return world.back_inventory
		"hat":
			return world.hat_inventory
		"hair":
			return world.hair_inventory
		"eyewear":
			return world.eyewear_inventory
		"shirt":
			return world.shirt_inventory
		"pants":
			return world.pants_inventory
		"shoes":
			return world.shoes_inventory
		"ride":
			return world.ride_inventory
		"currency":
			return world.currency_inventory
		"material":
			return world.material_inventory
		"lure":
			return world.lure_inventory
		"fish":
			return world.fish_inventory
		_:
			return null


func get_reward_texture(item_id: String, category: String):
	if world == null or item_id == "":
		return null

	var safe_category := normalize_reward_category(category)
	if world.has_method("get_inventory_icon_texture"):
		var icon_texture = world.get_inventory_icon_texture(item_id, safe_category)
		if icon_texture != null:
			return icon_texture
	if world.has_method("get_item_texture"):
		var item_texture = world.get_item_texture(item_id, safe_category)
		if item_texture != null:
			return item_texture

	match safe_category:
		"fish":
			return world.fish_textures.get(item_id, null)
		"material":
			return world.material_textures.get(item_id, null)
		"lure":
			return world.lure_textures.get(item_id, null)
		"tool":
			return world.tool_textures.get(item_id, null)
		"currency":
			return world.currency_textures.get(item_id, null)
		"block":
			return world.block_textures.get(item_id, null)
		"seed":
			return world.seed_textures.get(item_id, null)
		_:
			return null


func request_server_fishing_complete(success: bool) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("has_active_session") and not bool(network.has_active_session()):
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	return bool(network.send_inventory_transaction_request({
		"action": "fishing_complete",
		"world": world.current_world_name,
		"session_id": server_fishing_session_id,
		"success": success
	}))


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action = str(data.get("action", ""))
	if action != "fishing_start" and action != "fishing_complete":
		return false

	if action == "fishing_start":
		awaiting_cast_ack = false
		cast_ack_timer    = 0.0
		if not bool(data.get("ok", false)):
			world.show_notification(str(data.get("message", "Could not start fishing.")))
			return true

		var target_grid = Vector2i(int(data.get("target_x", 0)), int(data.get("target_y", 0)))
		var lure_id = str(data.get("lure_id", ""))
		var fish_data = {
			"item_id": str(data.get("item_id", data.get("fish_id", ""))),
			"item_category": str(data.get("item_category", "fish")),
			"fish_id": str(data.get("fish_id", "")),
			"difficulty": int(data.get("difficulty", 1))
		}
		start_local_cast(target_grid, lure_id, false, str(data.get("session_id", "")), fish_data)
		return true

	if action == "fishing_complete":
		waiting_for_server_catch = false
		var message = str(data.get("message", "Fishing finished."))
		var caught_fish_id: String = ""

		if bool(data.get("ok", false)):
			var reward_id := str(data.get("item_id", data.get("fish_id", "")))
			var reward_category := str(data.get("item_category", "fish")).strip_edges()
			if reward_category == "":
				reward_category = "fish"
			var fish_id = str(data.get("fish_id", ""))
			if reward_id != "" and reward_category == "fish":
				if fish_id == "":
					fish_id = reward_id
				var server_weight: float = _normalize_fish_weight(float(data.get("catch_weight", _roll_catch_weight(fish_id))))
				caught_fish_id = fish_id
				var server_owned_before: float = _get_owned_fish_weight(fish_id)
				var server_record: Dictionary = record_fish_catch(fish_id, server_weight)
				var server_new: bool = bool(data.get("is_new", server_record.get("was_new", server_owned_before <= 0.0)))
				_apply_server_fish_inventory_result(data, fish_id, server_weight)
				_show_catch_result(fish_id, server_new, server_weight)
				_maybe_broadcast_legendary_catch(fish_id)
				if not bool(data.get("reward_fx_sent", false)):
					_maybe_spawn_fishing_reward_confetti(fish_id, "fish")
			elif reward_id != "":
				_apply_server_reward_inventory_result(data, reward_id, reward_category)
				_show_catch_result(reward_id, false, -1.0, reward_category)
				if not bool(data.get("reward_fx_sent", false)):
					_maybe_spawn_fishing_reward_confetti(reward_id, reward_category)
			if message.strip_edges() != "":
				world.show_notification(message)
			elif caught_fish_id != "":
				_show_catch_notification(caught_fish_id, "fish")
			elif reward_id != "":
				_show_catch_notification(reward_id, reward_category)
		else:
			world.show_notification(message)

		world.save_player_data()
		return true

	return false


func fail_fishing(message: String):
	world.show_notification(message)
	if fishing_ui != null and fishing_ui.has_method("show_escape"):
		fishing_ui.show_escape()
	play_bobber_anim("reel_fail")
	if server_fishing_session_id != "":
		request_server_fishing_complete(false)
	reset_fishing_state(true)


func reset_fishing_state(delay_bobber: bool = true):
	awaiting_cast_ack = false
	cast_ack_timer    = 0.0
	world.fishing_active      = false
	world.fishing_timer       = 0.0
	world.fishing_lure_id     = ""
	world.fishing_target_grid = world.INVALID_GRID_POS
	state           = STATE_IDLE
	state_timer     = 0.0
	current_lure_id = ""
	pending_fish_id = ""
	pending_reward_category = "fish"
	pending_fish_data = {}
	server_fishing_session_id = ""
	cast_selected_item_type = ""
	cast_selected_item_category = ""
	cast_world_name = ""
	flush_fishing_visual_sync()
	_hide_fishing_state_ui()

	if delay_bobber:
		call_deferred("clear_bobber")
	else:
		clear_bobber()


func flush_fishing_visual_sync():
	if world != null and world.has_method("flush_multiplayer_position"):
		world.flush_multiplayer_position(false, true)


func finish_fishing():
	if world.fishing_active:
		trigger_bite()


# ── Queries ───────────────────────────────────────────────────

func can_reach_fishing_grid(grid_pos: Vector2i) -> bool:
	if world.player == null:
		return false
	var center   = Vector2(grid_pos.x * world.BLOCK_SIZE, grid_pos.y * world.BLOCK_SIZE)
	return world.player.global_position.distance_to(center) <= world.FISHING_CAST_PIXEL_RANGE


func is_fishable_water(grid_pos: Vector2i) -> bool:
	if not world.blocks.has(grid_pos):
		return false
	return str(world.blocks[grid_pos].get("type", "")) == "water"


func get_best_available_lure() -> String:
	for lure_id in ["void_worm_lure", "bonito_lure", "cotton_cordel_lure", "golden_lure", "shiny_lure", "worm_lure", "hook"]:
		if world.lure_inventory.has(lure_id) and int(world.lure_inventory[lure_id]) > 0:
			return lure_id
	for lure_id in world.lure_inventory.keys():
		var safe_lure_id := str(lure_id)
		if safe_lure_id == "lure_pack":
			continue
		if int(world.lure_inventory[lure_id]) > 0:
			return safe_lure_id
	return ""


# ── Loot tables ───────────────────────────────────────────────

func roll_fish_for_lure(lure_id: String, rod_id: String = "") -> String:
	var entry := _roll_fish_entry(lure_id, rod_id)
	return str(entry.get("item_id", entry.get("fish_id", "")))


func _roll_fish_entry(lure_id: String, rod_id: String = "") -> Dictionary:
	var table = get_fishing_table_for_lure(lure_id, rod_id)
	if table.is_empty():
		return {}

	var total = 0
	for entry in table:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return {}

	var roll    = randi_range(1, total)
	var running = 0
	for entry in table:
		running += int(entry.get("weight", 0))
		if roll <= running:
			return entry

	return table[0]


func get_fishing_table_for_lure(lure_id: String, rod_id: String = "") -> Array:
	var safe_lure_id := lure_id.strip_edges()
	if safe_lure_id == "magnet_lure":
		return _filter_fishing_table_for_rod(get_magnetic_fishing_table(), rod_id)

	return build_fishing_table_from_rarity_weights(get_fishing_rarity_weights(safe_lure_id), rod_id)


func get_fishing_rarity_weights(lure_id: String) -> Dictionary:
	match lure_id:
		"hook", "worm_lure":
			return {"common": 8000, "uncommon": 1600, "rare": 300, "epic": 90, "legendary": 10}
		"shiny_lure":
			return {"common": 3000, "uncommon": 6100, "rare": 800, "epic": 90, "legendary": 10}
		"golden_lure":
			return {"common": 2000, "uncommon": 3000, "rare": 4500, "epic": 490, "legendary": 10}
		"bonito_lure", "cotton_cordel_lure":
			return {"common": 1000, "uncommon": 2000, "rare": 3000, "epic": 3500, "legendary": 500}
		"void_worm_lure":
			return {"common": 1000, "uncommon": 1500, "rare": 2000, "epic": 2000, "legendary": 3500}
		_:
			return {"common": 8000, "uncommon": 1600, "rare": 300, "epic": 90, "legendary": 10}


func get_fishing_rarity_pools() -> Dictionary:
	return {
		"common": [
			{"fish_id": "pond_fish_small"},
			{"fish_id": "pond_fish_med"},
			{"fish_id": "pond_fish_large"},
			{"fish_id": "cat_fish_small"},
			{"fish_id": "cat_fish_med"},
			{"fish_id": "cat_fish_large"},
			{"fish_id": "sea_horse_small"},
			{"fish_id": "sea_horse_med"},
			{"fish_id": "sea_horse_large"}
		],
		"uncommon": [
			{"fish_id": "bone_fish_small"},
			{"fish_id": "bone_fish_med"},
			{"fish_id": "bone_fish_large"},
			{"fish_id": "stingray_small"},
			{"fish_id": "stingray_med"},
			{"fish_id": "stingray_large"}
		],
		"rare": [
			{"fish_id": "lava_fish_small"},
			{"fish_id": "lava_fish_med"},
			{"fish_id": "lava_fish_large"},
			{"fish_id": "alien_fish_small"},
			{"fish_id": "alien_fish_med"},
			{"fish_id": "alien_fish_large"}
		],
		"epic": [
			{"fish_id": "barracuda_small"},
			{"fish_id": "barracuda_med"},
			{"fish_id": "barracuda_large"},
			{"fish_id": "shark_small"},
			{"fish_id": "shark_med"},
			{"fish_id": "shark_large"}
		],
		"legendary": [
			{"fish_id": "tail_of_trident"},
			{"fish_id": "mermaid"},
			{"fish_id": "megalodon"},
			{"fish_id": "kraken"},
			{"fish_id": "sea_eater"}
		]
	}


func get_neptune_rod_special_fishing_rewards(rod_id: String) -> Array:
	var rewards := [
		{"item_id": "golden_statue", "item_category": "block", "weight": 10, "difficulty": 9, "required_rod_id": "neptune_rod"}
	]
	return _filter_fishing_table_for_rod(rewards, rod_id)


func build_fishing_table_from_rarity_weights(rarity_weights: Dictionary, rod_id: String = "") -> Array:
	var table := []
	var pools := get_fishing_rarity_pools()
	for rarity in ["common", "uncommon", "rare", "epic", "legendary"]:
		var group_weight := int(rarity_weights.get(rarity, 0))
		if group_weight <= 0:
			continue
		var special_rewards: Array = get_neptune_rod_special_fishing_rewards(rod_id) if rarity == "common" else []
		var special_weight: int = 0
		for special_entry in special_rewards:
			special_weight += max(0, int(special_entry.get("weight", 0)))
		if special_weight > 0:
			group_weight = max(0, group_weight - special_weight)
		var pool = _filter_fishing_table_for_rod(pools.get(rarity, []), rod_id)
		table.append_array(distribute_fishing_weight(group_weight, pool))
		if special_rewards.size() > 0:
			table.append_array(special_rewards)
	return table


func distribute_fishing_weight(group_weight: int, entries: Array) -> Array:
	var weighted_entries := []
	if group_weight <= 0 or entries.is_empty():
		return weighted_entries

	var base_weight := int(floor(float(group_weight) / float(entries.size())))
	var remainder := group_weight % entries.size()
	for entry_value in entries:
		var entry: Dictionary = entry_value.duplicate(true)
		var entry_weight := base_weight
		if remainder > 0:
			entry_weight += 1
			remainder -= 1
		if entry_weight <= 0:
			continue
		entry["weight"] = entry_weight
		entry["difficulty"] = get_fishing_entry_difficulty(entry)
		weighted_entries.append(entry)
	return weighted_entries


func get_fishing_entry_difficulty(entry: Dictionary) -> int:
	var configured := int(entry.get("difficulty", 0))
	if configured > 0:
		return configured

	var item_id := str(entry.get("item_id", entry.get("fish_id", "")))
	if world != null and world.item_database.has(item_id) and world.item_database[item_id] is Dictionary:
		return max(1, int(world.item_database[item_id].get("difficulty", 1)))
	return 1


func get_magnetic_fishing_table() -> Array:
	return [
		{"item_id": "seaweed", "item_category": "material", "weight": 18, "difficulty": 1},
		{"item_id": "trash_can", "item_category": "material", "weight": 16, "difficulty": 1},
		{"item_id": "coral", "item_category": "material", "weight": 13, "difficulty": 2},
		{"item_id": "clam", "item_category": "material", "weight": 13, "difficulty": 2},
		{"item_id": "compass", "item_category": "material", "weight": 9, "difficulty": 3},
		{"item_id": "pearl", "item_category": "material", "weight": 8, "difficulty": 3},
		{"item_id": "rusty_bicycle", "item_category": "material", "weight": 7, "difficulty": 4},
		{"item_id": "lost_chapter", "item_category": "material", "weight": 5, "difficulty": 5},
		{"item_id": "topaz_necklace", "item_category": "material", "weight": 4, "difficulty": 6},
		{"item_id": "toxic_waste", "item_category": "material", "weight": 4, "difficulty": 6},
		{"item_id": "naval_mines", "item_category": "material", "weight": 2, "difficulty": 7},
		{"item_id": "atlantic_chest", "item_category": "block", "weight": 1, "difficulty": 6}
	]


func _filter_fishing_table_for_rod(table: Array, rod_id: String) -> Array:
	var clean_rod_id := normalize_fishing_rod_id(rod_id)
	var filtered := []
	for entry in table:
		var required_rod_id := normalize_fishing_rod_id(str(entry.get("required_rod_id", "")))
		if required_rod_id == "" or required_rod_id == clean_rod_id:
			filtered.append(entry)
	return filtered


func open_lure_pack(amount: int = 1):
	var safe = max(1, amount)
	for i in range(safe * world.LURE_PACK_SIZE):
		var lure_id = roll_lure_from_pack()
		if not world.lure_inventory.has(lure_id):
			world.lure_inventory[lure_id] = 0
		world.lure_inventory[lure_id] += 1
	world.update_all_ui()
	world.save_player_data()
	world.show_notification("Opened Lure Pack x" + str(safe) + ".")


func roll_lure_from_pack() -> String:
	var table := [
		{"item_id": "hook", "weight": 300},
		{"item_id": "worm_lure", "weight": 300},
		{"item_id": "shiny_lure", "weight": 180},
		{"item_id": "golden_lure", "weight": 100},
		{"item_id": "magnet_lure", "weight": 60},
		{"item_id": "bonito_lure", "weight": 30},
		{"item_id": "cotton_cordel_lure", "weight": 25},
		{"item_id": "void_worm_lure", "weight": 5}
	]
	var total := 0
	for entry in table:
		total += int(entry.get("weight", 0))
	var roll = randi_range(1, max(1, total))
	var running := 0
	for entry in table:
		running += int(entry.get("weight", 0))
		if roll <= running:
			return str(entry.get("item_id", "worm_lure"))
	return "worm_lure"


# ── Minigame UI (pure code) ───────────────────────────────────

const MG_W  = 780.0
const MG_H  = 338.0
const BAR_X = 38.0
const BAR_Y = 204.0
const BAR_W = 704.0
const BAR_H = 58.0


func _build_minigame_ui():
	if world == null or world.ui_layer == null:
		return

	var old = world.ui_layer.get_node_or_null("FishingMinigamePanel")
	if old != null:
		old.queue_free()

	# ── Main panel ─────────────────────────────────────────────
	mg_panel = Control.new()
	mg_panel.name = "FishingMinigamePanel"
	mg_panel.size = Vector2(MG_W, MG_H)
	mg_panel.z_index = 200
	mg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.ui_layer.add_child(mg_panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = mg_panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		20,
		0
	))
	mg_panel.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = mg_panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		20,
		12
	))
	mg_panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(MG_W, 78)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		20,
		8
	))
	mg_panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, 73)
	top_line.size = Vector2(MG_W, 4)
	top_line.color = Color(0.30, 0.38, 0.78, 0.55)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "FISHING"
	title.position = Vector2(36, 8)
	title.size = Vector2(300, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 46)
	mg_panel.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "HOOK THE FISH"
	title_sub.position = Vector2(42, 58)
	title_sub.size = Vector2(220, 22)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	mg_panel.add_child(title_sub)

	var status_badge = Panel.new()
	status_badge.name = "StatusBadge"
	status_badge.position = Vector2(MG_W - 250, 16)
	status_badge.size = Vector2(212, 46)
	status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.030, 0.060, 0.110, 0.98),
		Color(1.0, 0.80, 0.12, 0.92),
		3,
		12,
		6
	))
	mg_panel.add_child(status_badge)

	var status = Label.new()
	status.name = "StatusTitle"
	status.text = "TARGET ZONE"
	status.position = Vector2(MG_W - 238, 23)
	status.size = Vector2(188, 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status, 18, PixelUIStyle.GOLD_SOFT)
	mg_panel.add_child(status)

	var fish_card = Panel.new()
	fish_card.name = "FishCard"
	fish_card.position = Vector2(38, 96)
	fish_card.size = Vector2(432, 88)
	fish_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		5
	))
	mg_panel.add_child(fish_card)

	# Fish icon slot
	var icon_back = Panel.new()
	icon_back.name = "FishIconBack"
	icon_back.position = Vector2(52, 106)
	icon_back.size = Vector2(68, 68)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style("common"))
	mg_panel.add_child(icon_back)

	mg_fish_icon = TextureRect.new()
	mg_fish_icon.name = "FishIcon"
	mg_fish_icon.position = Vector2(60, 114)
	mg_fish_icon.size = Vector2(52, 52)
	mg_fish_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mg_fish_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mg_fish_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_panel.add_child(mg_fish_icon)

	# Fish name
	mg_fish_name = Label.new()
	mg_fish_name.name = "FishName"
	mg_fish_name.position = Vector2(136, 106)
	mg_fish_name.size = Vector2(284, 32)
	mg_fish_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_fish_name.clip_text = true
	mg_fish_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(mg_fish_name, 22)
	mg_panel.add_child(mg_fish_name)

	# Rarity label
	mg_rarity_label = Label.new()
	mg_rarity_label.name = "RarityLabel"
	mg_rarity_label.position = Vector2(136, 140)
	mg_rarity_label.size = Vector2(260, 24)
	mg_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(mg_rarity_label, 15)
	mg_panel.add_child(mg_rarity_label)

	# Lure label
	var lure_card = Panel.new()
	lure_card.name = "LureCard"
	lure_card.position = Vector2(492, 96)
	lure_card.size = Vector2(250, 88)
	lure_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lure_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		5
	))
	mg_panel.add_child(lure_card)

	var lure_title = Label.new()
	lure_title.text = "ACTIVE LURE"
	lure_title.position = Vector2(18, 12)
	lure_title.size = Vector2(214, 22)
	lure_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lure_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lure_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(lure_title, 13)
	lure_card.add_child(lure_title)

	mg_lure_label = Label.new()
	mg_lure_label.name = "LureLabel"
	mg_lure_label.position = Vector2(18, 40)
	mg_lure_label.size = Vector2(214, 34)
	mg_lure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mg_lure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_lure_label.clip_text = true
	mg_lure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(mg_lure_label, 18, PixelUIStyle.GOLD_SOFT)
	lure_card.add_child(mg_lure_label)

	var bar_title = Label.new()
	bar_title.text = "CATCH TIMING"
	bar_title.position = Vector2(BAR_X, BAR_Y - 30)
	bar_title.size = Vector2(180, 22)
	bar_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(bar_title, 13)
	mg_panel.add_child(bar_title)

	# Time header
	var time_header = Label.new()
	time_header.text = "TIME LEFT"
	time_header.position = Vector2(BAR_X, 278)
	time_header.size = Vector2(120, 18)
	time_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(time_header, 13)
	mg_panel.add_child(time_header)

	# Time bar background
	var time_bg = Panel.new()
	time_bg.position = Vector2(BAR_X, 300)
	time_bg.size = Vector2(BAR_W, 18)
	time_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.04, 0.08, 0.10, 0.95),
		Color(0.01, 0.03, 0.04, 1.0),
		2,
		6,
		1
	))
	mg_panel.add_child(time_bg)

	mg_time_bar_fill = ColorRect.new()
	mg_time_bar_fill.name = "TimeBarFill"
	mg_time_bar_fill.position = Vector2(BAR_X + 3, 303)
	mg_time_bar_fill.size = Vector2(BAR_W - 6, 12)
	mg_time_bar_fill.color = Color(0.28, 0.88, 0.52, 0.92)
	mg_time_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_panel.add_child(mg_time_bar_fill)

	# Fishing bar background
	mg_bar_bg = Panel.new()
	mg_bar_bg.name = "FishingBarBg"
	mg_bar_bg.position = Vector2(BAR_X, BAR_Y)
	mg_bar_bg.size = Vector2(BAR_W, BAR_H)
	mg_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_bar_bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.030, 0.060, 0.105, 0.94),
		Color(0.30, 0.52, 0.82, 0.72),
		3,
		14,
		7
	))
	mg_panel.add_child(mg_bar_bg)

	mg_green_zone = ColorRect.new()
	mg_green_zone.name = "GreenZone"
	mg_green_zone.position = Vector2(BAR_X, BAR_Y + 7)
	mg_green_zone.size = Vector2(110, BAR_H - 14)
	mg_green_zone.color = Color(0.20, 0.78, 0.32, 0.80)
	mg_green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_panel.add_child(mg_green_zone)

	mg_cursor_bar = ColorRect.new()
	mg_cursor_bar.name = "CursorBar"
	mg_cursor_bar.position = Vector2(BAR_X, BAR_Y - 7)
	mg_cursor_bar.size = Vector2(8, BAR_H + 14)
	mg_cursor_bar.color = Color(1.0, 1.0, 1.0, 0.96)
	mg_cursor_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_panel.add_child(mg_cursor_bar)

	mg_hint_label = Label.new()
	mg_hint_label.name = "HintLabel"
	mg_hint_label.text = "CLICK WHEN IN THE GREEN!"
	mg_hint_label.position = Vector2(BAR_X + 190, BAR_Y - 30)
	mg_hint_label.size = Vector2(BAR_W - 190, 24)
	mg_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mg_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(mg_hint_label, 18, PixelUIStyle.TEXT_SOFT)
	mg_panel.add_child(mg_hint_label)

	mg_panel.visible = false
	_position_mg_panel()


func _show_mg_panel(show: bool):
	if mg_panel != null and is_instance_valid(mg_panel):
		mg_panel.visible = show
		if show:
			PixelUIStyle.play_panel_open(mg_panel, Vector2(0.98, 0.98), 0.14)


func _position_mg_panel():
	if mg_panel == null:
		return
	var ss = mg_panel.get_viewport_rect().size
	var max_x = max(12.0, ss.x - MG_W - 12.0)
	var max_y = max(76.0, ss.y - MG_H - 24.0)
	mg_panel.position = Vector2(
		clamp((ss.x - MG_W) / 2.0, 12.0, max_x),
		clamp(ss.y - MG_H - 150.0, 76.0, max_y)
	)


func _update_mg_visuals():
	if mg_panel == null or not is_instance_valid(mg_panel):
		return

	# Green zone position
	if mg_green_zone != null:
		mg_green_zone.position.x = BAR_X + BAR_W * mg_green_start
		mg_green_zone.size.x     = BAR_W * mg_green_size

	# Cursor position
	if mg_cursor_bar != null:
		mg_cursor_bar.position.x = BAR_X + BAR_W * mg_cursor_t - mg_cursor_bar.size.x * 0.5

	# Cursor-in-green check — visual feedback
	var in_green = mg_cursor_t >= mg_green_start and mg_cursor_t <= (mg_green_start + mg_green_size)

	if mg_cursor_bar != null:
		mg_cursor_bar.color = Color(1.0, 0.94, 0.18, 1.0) if in_green else Color(1.0, 1.0, 1.0, 0.96)

	if mg_green_zone != null:
		mg_green_zone.color = Color(0.28, 1.0, 0.44, 0.92) if in_green else Color(0.22, 0.80, 0.35, 0.78)

	if mg_hint_label != null:
		if in_green:
			mg_hint_label.text = "CLICK NOW!"
			mg_hint_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.18, 1.0))
		else:
			mg_hint_label.text = "CLICK WHEN IN THE GREEN!"
			mg_hint_label.add_theme_color_override("font_color", Color(0.70, 0.88, 0.96, 0.88))

	# Time bar
	if mg_time_bar_fill != null:
		var ratio = clamp(mg_time_left / MINIGAME_DURATION, 0.0, 1.0)
		mg_time_bar_fill.size.x = (BAR_W - 6.0) * ratio

		if ratio < 0.25:
			mg_time_bar_fill.color = Color(0.95, 0.28, 0.22, 0.92)
		elif ratio < 0.55:
			mg_time_bar_fill.color = Color(0.95, 0.74, 0.18, 0.92)
		else:
			mg_time_bar_fill.color = Color(0.28, 0.88, 0.52, 0.92)


# ── Fish caught popup ─────────────────────────────────────────

const POPUP_W = 440.0
const POPUP_H = 360.0


func _build_catch_popup():
	if world == null or world.ui_layer == null:
		return

	var old = world.ui_layer.get_node_or_null("FishCatchPopup")
	if old != null:
		old.queue_free()

	catch_popup = Control.new()
	catch_popup.name = "FishCatchPopup"
	catch_popup.size = Vector2(POPUP_W, POPUP_H)
	catch_popup.z_index = 210
	catch_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_popup.visible = false
	world.ui_layer.add_child(catch_popup)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = catch_popup.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		20,
		0
	))
	catch_popup.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = catch_popup.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		20,
		12
	))
	catch_popup.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(POPUP_W, 76)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		20,
		8
	))
	catch_popup.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, 71)
	top_line.size = Vector2(POPUP_W, 4)
	top_line.color = Color(0.30, 0.38, 0.78, 0.55)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_popup.add_child(top_line)

	var caught_lbl = Label.new()
	caught_lbl.name = "CaughtTitle"
	caught_lbl.text = "FISH CAUGHT"
	caught_lbl.position = Vector2(28, 12)
	caught_lbl.size = Vector2(POPUP_W - 56.0, 40)
	caught_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caught_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caught_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(caught_lbl, 32, PixelUIStyle.GOLD_SOFT)
	catch_popup.add_child(caught_lbl)

	var reward_text = Label.new()
	reward_text.name = "RewardText"
	reward_text.text = "ADDED TO BAG"
	reward_text.position = Vector2(0, 82)
	reward_text.size = Vector2(POPUP_W, 30)
	reward_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(reward_text, 18, Color(0.34, 1.0, 0.52, 1.0))
	catch_popup.add_child(reward_text)

	var glow = Panel.new()
	glow.name = "RewardGlow"
	glow.position = Vector2(96, 118)
	glow.size = Vector2(248, 154)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.95, 0.72, 0.18, 0.16),
		Color(1.0, 0.80, 0.22, 0.28),
		3,
		30,
		16
	))
	catch_popup.add_child(glow)

	var icon_back = Panel.new()
	icon_back.name = "CatchIconBack"
	icon_back.position = Vector2(128, 128)
	icon_back.size = Vector2(184, 132)
	icon_back.pivot_offset = icon_back.size * 0.5
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.card_style_featured())
	catch_popup.add_child(icon_back)

	catch_icon = TextureRect.new()
	catch_icon.name = "CatchIcon"
	catch_icon.position = Vector2(150, 142)
	catch_icon.size = Vector2(140, 102)
	catch_icon.pivot_offset = catch_icon.size * 0.5
	catch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	catch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_popup.add_child(catch_icon)

	catch_name_label = Label.new()
	catch_name_label.name = "CatchName"
	catch_name_label.position = Vector2(28, 276)
	catch_name_label.size = Vector2(POPUP_W - 48.0, 30)
	catch_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catch_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(catch_name_label, 22)
	catch_popup.add_child(catch_name_label)

	catch_rarity_label = Label.new()
	catch_rarity_label.name = "CatchRarity"
	catch_rarity_label.position = Vector2(28, 308)
	catch_rarity_label.size = Vector2(POPUP_W - 48.0, 26)
	catch_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catch_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(catch_rarity_label, 16)
	catch_popup.add_child(catch_rarity_label)


func _show_catch_popup(fish_id: String):
	if catch_popup == null or not is_instance_valid(catch_popup):
		_build_catch_popup()
	if catch_popup == null:
		return

	var fish_name = world.get_item_display_name(fish_id, "fish")
	var rarity    = "common"
	if world.item_database.has(fish_id):
		rarity = str(world.item_database[fish_id].get("rarity", "common"))

	if catch_name_label != null:
		catch_name_label.text = fish_name

	if catch_rarity_label != null:
		catch_rarity_label.text = rarity.capitalize()
		catch_rarity_label.add_theme_color_override("font_color", _rarity_color(rarity))

	if catch_icon != null:
		catch_icon.texture = world.fish_textures.get(fish_id, null)

	var icon_back = catch_popup.get_node_or_null("CatchIconBack")
	if icon_back != null:
		icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))

	# Center on screen
	var ss = catch_popup.get_viewport_rect().size
	var max_x = max(12.0, ss.x - POPUP_W - 12.0)
	var max_y = max(40.0, ss.y - POPUP_H - 24.0)
	catch_popup.position = Vector2(
		clamp((ss.x - POPUP_W) / 2.0, 12.0, max_x),
		clamp((ss.y - POPUP_H) / 2.0 - 30.0, 40.0, max_y)
	)

	catch_popup.visible  = true
	catch_popup_timer    = CATCH_POPUP_DURATION
	PixelUIStyle.play_panel_open(catch_popup, Vector2(0.86, 0.86), 0.20)

	if icon_back != null:
		icon_back.scale = Vector2(0.92, 0.92)
		var card_tween = icon_back.create_tween()
		card_tween.tween_property(icon_back, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(icon_back, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if catch_icon != null:
		catch_icon.scale = Vector2(0.72, 0.72)
		var icon_tween = catch_icon.create_tween()
		icon_tween.tween_property(catch_icon, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		icon_tween.tween_property(catch_icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ── Helpers ───────────────────────────────────────────────────

func _lure_bonus(lure_id: String) -> float:
	match lure_id:
		"shiny_lure":
			return 0.045
		"golden_lure":
			return 0.075
		"bonito_lure", "cotton_cordel_lure":
			return 0.095
		"void_worm_lure":
			return 0.12
		"magnet_lure":
			return 0.04
		_:
			return 0.0


func _default_fishing_records() -> Dictionary:
	return {
		"version": FISHING_RECORDS_VERSION,
		"total_fish_caught": 0,
		"total_fishing_xp": 0,
		"fishing_level": 1,
		"biggest_fish_per_species": {},
		"total_caught_per_species": {},
		"first_catch_discovered": {},
		"best_value_per_species": {},
		"rarest_catch": {}
	}


func ensure_fishing_records() -> void:
	if fishing_records.is_empty():
		fishing_records = _default_fishing_records()

	for key in _default_fishing_records().keys():
		if not fishing_records.has(key):
			fishing_records[key] = _default_fishing_records()[key]

	if not (fishing_records.get("biggest_fish_per_species", {}) is Dictionary):
		fishing_records["biggest_fish_per_species"] = {}
	if not (fishing_records.get("total_caught_per_species", {}) is Dictionary):
		fishing_records["total_caught_per_species"] = {}
	if not (fishing_records.get("first_catch_discovered", {}) is Dictionary):
		fishing_records["first_catch_discovered"] = {}
	if not (fishing_records.get("best_value_per_species", {}) is Dictionary):
		fishing_records["best_value_per_species"] = {}
	if not (fishing_records.get("rarest_catch", {}) is Dictionary):
		fishing_records["rarest_catch"] = {}

	fishing_records["version"] = FISHING_RECORDS_VERSION
	fishing_records["total_fish_caught"] = max(0, int(fishing_records.get("total_fish_caught", 0)))
	fishing_records["total_fishing_xp"] = max(0, int(fishing_records.get("total_fishing_xp", 0)))
	fishing_records["fishing_level"] = max(1, int(fishing_records.get("fishing_level", 1)))


func reset_fishing_records() -> void:
	fishing_records = _default_fishing_records()


func apply_fishing_records(data: Dictionary) -> void:
	if data.is_empty():
		ensure_fishing_records()
		return
	fishing_records = data.duplicate(true)
	if fishing_records.has("biggest_fish_by_species") and not fishing_records.has("biggest_fish_per_species"):
		fishing_records["biggest_fish_per_species"] = fishing_records.get("biggest_fish_by_species", {})
	ensure_fishing_records()


func get_fishing_records_save_data() -> Dictionary:
	ensure_fishing_records()
	return fishing_records.duplicate(true)


func _get_record_dictionary(key: String) -> Dictionary:
	ensure_fishing_records()
	var value = fishing_records.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func record_fish_catch(fish_id: String, weight: float) -> Dictionary:
	ensure_fishing_records()
	var safe_fish_id: String = fish_id.strip_edges()
	if safe_fish_id == "":
		return {"was_new": false, "weight": 0.0}

	var rounded_weight: float = snapped(max(0.1, weight), 0.1)
	var rarity: String = _get_fish_rarity(safe_fish_id)
	var item_data: Dictionary = _get_fish_item_data(safe_fish_id)
	var sell_value: int = _get_fish_sell_value(safe_fish_id, item_data)
	var species_counts: Dictionary = _get_record_dictionary("total_caught_per_species")
	var biggest: Dictionary = _get_record_dictionary("biggest_fish_per_species")
	var discovered: Dictionary = _get_record_dictionary("first_catch_discovered")
	var best_values: Dictionary = _get_record_dictionary("best_value_per_species")
	var previous_count: int = max(0, int(species_counts.get(safe_fish_id, 0)))
	var was_new: bool = previous_count <= 0 and not discovered.has(safe_fish_id)
	var catch_value: int = _calculate_fish_sale_value(1, sell_value)

	species_counts[safe_fish_id] = previous_count + 1
	if rounded_weight > float(biggest.get(safe_fish_id, 0.0)):
		biggest[safe_fish_id] = rounded_weight
	if catch_value > int(best_values.get(safe_fish_id, 0)):
		best_values[safe_fish_id] = catch_value
	if not discovered.has(safe_fish_id):
		discovered[safe_fish_id] = {
			"fish_id": safe_fish_id,
			"discovered_at": int(Time.get_unix_time_from_system())
		}

	fishing_records["total_caught_per_species"] = species_counts
	fishing_records["biggest_fish_per_species"] = biggest
	fishing_records["first_catch_discovered"] = discovered
	fishing_records["best_value_per_species"] = best_values
	fishing_records["total_fish_caught"] = max(0, int(fishing_records.get("total_fish_caught", 0))) + 1
	fishing_records["total_fishing_xp"] = max(0, int(fishing_records.get("total_fishing_xp", 0))) + _get_fishing_xp_for_catch(safe_fish_id, rarity)
	fishing_records["fishing_level"] = _calculate_fishing_level(int(fishing_records.get("total_fishing_xp", 0)))
	_update_rarest_catch(safe_fish_id, rarity, rounded_weight, catch_value)

	return {
		"was_new": was_new,
		"weight": rounded_weight,
		"rarity": rarity,
		"value": catch_value,
		"value_per_fish": sell_value
	}


func _update_rarest_catch(fish_id: String, rarity: String, weight: float, sell_value: int) -> void:
	var current: Dictionary = _get_record_dictionary("rarest_catch")
	var current_rarity: String = str(current.get("rarity", "common")).to_lower()
	var current_score: int = int(RARITY_SCORE.get(current_rarity, 0))
	var new_score: int = int(RARITY_SCORE.get(rarity, 0))
	var should_replace: bool = current.is_empty() or new_score > current_score
	if not should_replace and new_score == current_score:
		should_replace = sell_value > int(current.get("value", 0)) or weight > float(current.get("weight", 0.0))
	if should_replace:
		fishing_records["rarest_catch"] = {
			"fish_id": fish_id,
			"name": world.get_item_display_name(fish_id, "fish") if world != null else fish_id,
			"rarity": rarity,
			"weight": weight,
			"value": sell_value
		}


func _get_fishing_xp_for_catch(fish_id: String, rarity: String) -> int:
	var difficulty: int = int(_get_fish_item_data(fish_id).get("difficulty", 1))
	match rarity:
		"uncommon":
			return 18 + difficulty * 2
		"rare":
			return 35 + difficulty * 3
		"epic":
			return 70 + difficulty * 4
		"legendary":
			return 150 + difficulty * 6
		_:
			return 10 + difficulty


func _calculate_fishing_level(total_xp: int) -> int:
	var level: int = 1
	var remaining: int = max(0, total_xp)
	while level < 100:
		var needed: int = 80 + (level - 1) * 45
		if remaining < needed:
			break
		remaining -= needed
		level += 1
	return level


func get_fishing_journal_summary() -> Dictionary:
	ensure_fishing_records()
	var fish_ids: Array = _get_all_fish_ids()
	var discovered: Dictionary = _get_record_dictionary("first_catch_discovered")
	var discovered_count: int = 0
	for fish_id in fish_ids:
		if _is_fish_discovered(str(fish_id), discovered):
			discovered_count += 1
	var total_species: int = max(1, fish_ids.size())
	return {
		"completion_percent": int(round(float(discovered_count) / float(total_species) * 100.0)),
		"discovered_count": discovered_count,
		"total_species": fish_ids.size(),
		"total_fish_caught": int(fishing_records.get("total_fish_caught", 0)),
		"total_fishing_xp": int(fishing_records.get("total_fishing_xp", 0)),
		"fishing_level": int(fishing_records.get("fishing_level", 1)),
		"rarest_catch": _get_record_dictionary("rarest_catch")
	}


func get_fishing_journal_entries(rarity_filter: String = "all") -> Array:
	ensure_fishing_records()
	var entries: Array = []
	var filter_value: String = rarity_filter.strip_edges().to_lower()
	var species_counts: Dictionary = _get_record_dictionary("total_caught_per_species")
	var biggest: Dictionary = _get_record_dictionary("biggest_fish_per_species")
	var discovered: Dictionary = _get_record_dictionary("first_catch_discovered")
	var best_values: Dictionary = _get_record_dictionary("best_value_per_species")

	for fish_id_value in _get_all_fish_ids():
		var fish_id: String = str(fish_id_value)
		var item_data: Dictionary = _get_fish_item_data(fish_id)
		var rarity: String = str(item_data.get("rarity", "common")).to_lower()
		if filter_value != "all" and rarity != filter_value:
			continue
		var is_discovered: bool = _is_fish_discovered(fish_id, discovered)
		entries.append({
			"fish_id": fish_id,
			"name": world.get_item_display_name(fish_id, "fish") if world != null else fish_id,
			"rarity": rarity,
			"location": str(item_data.get("location", "Any Water")),
			"discovered": is_discovered,
			"biggest_weight": float(biggest.get(fish_id, 0.0)),
			"total_caught": int(species_counts.get(fish_id, 0)),
			"best_value": int(best_values.get(fish_id, 0)),
			"value_per_fish": _get_fish_sell_value(fish_id, item_data),
			"icon": world.fish_textures.get(fish_id, null) if world != null else null,
			"order": int(item_data.get("order", 99999))
		})

	return entries


func open_fishing_journal() -> void:
	if fishing_ui == null:
		_setup_fishing_ui()
	if fishing_ui != null and fishing_ui.has_method("open_journal"):
		fishing_ui.open_journal()


func _is_fish_discovered(fish_id: String, discovered: Dictionary) -> bool:
	if discovered.has(fish_id):
		return true
	if fishing_records.has("total_caught_per_species"):
		var species_counts: Dictionary = _get_record_dictionary("total_caught_per_species")
		if int(species_counts.get(fish_id, 0)) > 0:
			return true
	if world != null and world.fish_inventory.has(fish_id) and _fish_inventory_value_to_tenths(world.fish_inventory.get(fish_id, 0)) > 0:
		return true
	return false


func _get_all_fish_ids() -> Array:
	var fish_ids: Array = []
	if world == null:
		return fish_ids
	for fish_id_value in world.fish_items:
		var fish_id: String = str(fish_id_value)
		if fish_id != "" and not fish_ids.has(fish_id):
			fish_ids.append(fish_id)
	for item_id_value in world.item_database.keys():
		var item_id: String = str(item_id_value)
		var item_data: Dictionary = _get_fish_item_data(item_id)
		if str(item_data.get("category", "")) == "fish" and not fish_ids.has(item_id):
			fish_ids.append(item_id)
	fish_ids.sort_custom(Callable(self, "_sort_fish_ids_by_order"))
	return fish_ids


func _sort_fish_ids_by_order(a, b) -> bool:
	var a_data: Dictionary = _get_fish_item_data(str(a))
	var b_data: Dictionary = _get_fish_item_data(str(b))
	var a_order: int = int(a_data.get("order", 99999))
	var b_order: int = int(b_data.get("order", 99999))
	if a_order == b_order:
		return str(a) < str(b)
	return a_order < b_order


func _get_fish_item_data(fish_id: String) -> Dictionary:
	if world != null and world.item_database.has(fish_id) and world.item_database[fish_id] is Dictionary:
		return world.item_database[fish_id] as Dictionary
	return {}


func _get_fish_rarity(fish_id: String) -> String:
	return str(_get_fish_item_data(fish_id).get("rarity", "common")).to_lower()


func _setup_fishing_ui():
	if world == null or world.ui_layer == null:
		return

	var existing = world.ui_layer.get_node_or_null("FishingMinigameUI")
	if existing != null and existing.has_method("show_waiting"):
		fishing_ui = existing
	else:
		if existing != null:
			existing.queue_free()
		fishing_ui = Control.new()
		fishing_ui.name = "FishingMinigameUI"
		fishing_ui.set_script(FishingMinigameUI)
		world.ui_layer.add_child(fishing_ui)

	if fishing_ui != null and fishing_ui.has_method("setup"):
		fishing_ui.setup(world)


func _show_waiting_ui():
	if fishing_ui != null and fishing_ui.has_method("show_waiting"):
		fishing_ui.show_waiting(world.get_item_display_name(current_lure_id, "lure"))


func _update_bite_ui():
	if fishing_ui != null and fishing_ui.has_method("update_bite_timer"):
		fishing_ui.update_bite_timer(state_timer, REACTION_WINDOW_TIME)


func _hide_fishing_state_ui():
	if fishing_ui != null and fishing_ui.has_method("hide_fishing_state"):
		fishing_ui.hide_fishing_state()


func _show_catch_result(fish_id: String, was_new: bool = false, catch_weight: float = -1.0, category: String = "fish"):
	if fishing_ui == null or not fishing_ui.has_method("show_catch_result"):
		return
	fishing_ui.show_catch_result(_build_catch_result_data(fish_id, was_new, catch_weight, category))


func _build_catch_result_data(fish_id: String, was_new: bool, _catch_weight: float = -1.0, category: String = "fish") -> Dictionary:
	var item_data: Dictionary = {}
	if world != null and world.item_database.has(fish_id):
		item_data = world.item_database[fish_id]

	var safe_category := normalize_reward_category(category)
	var rarity: String = str(item_data.get("rarity", "common")).to_lower()
	var sell_value: int = _get_fish_sell_value(fish_id, item_data) if safe_category == "fish" else 0
	return {
		"fish_id": fish_id,
		"item_id": fish_id,
		"item_category": safe_category,
		"name": world.get_item_display_name(fish_id, safe_category) if world != null else fish_id,
		"rarity": rarity,
		"amount": "x1",
		"value": _calculate_fish_sale_value(1, sell_value),
		"value_per_fish": sell_value,
		"is_new": was_new,
		"icon": get_reward_texture(fish_id, safe_category)
	}


func _roll_display_weight_for_rarity(rarity: String) -> float:
	match rarity:
		"uncommon":
			return randf_range(1.2, 4.5)
		"rare":
			return randf_range(3.0, 9.0)
		"epic":
			return randf_range(6.0, 16.0)
		"legendary":
			return randf_range(12.0, 32.0)
		_:
			return randf_range(0.6, 2.4)


func _roll_catch_weight(fish_id: String) -> float:
	var item_data: Dictionary = _get_fish_item_data(fish_id)
	var rarity: String = str(item_data.get("rarity", "common")).to_lower()
	var min_weight: float = float(item_data.get("min_weight_lb", 0.0))
	var max_weight: float = float(item_data.get("max_weight_lb", 0.0))
	if min_weight > 0.0 and max_weight >= min_weight:
		return snapped(randf_range(min_weight, max_weight), 0.1)
	return snapped(_roll_display_weight_for_rarity(rarity), 0.1)


func _format_fish_weight(weight: float) -> String:
	return "%.1f lb" % snapped(weight, 0.1)


func _show_catch_notification(fish_id: String, category: String = "fish") -> void:
	if world == null or not world.has_method("show_notification"):
		return
	var safe_category := normalize_reward_category(category)
	world.show_notification("Caught " + world.get_item_display_name(fish_id, safe_category) + " x1!")


func _maybe_spawn_fishing_reward_confetti(item_id: String, category: String = "fish") -> void:
	if world == null:
		return

	var rarity := _get_reward_rarity(item_id, category)
	if rarity != "epic" and rarity != "legendary":
		return

	var ui_position := _get_fishing_reward_confetti_ui_position()
	if is_finite(ui_position.x) and is_finite(ui_position.y):
		if world.has_method("spawn_fishing_reward_confetti_ui_particles"):
			if bool(world.spawn_fishing_reward_confetti_ui_particles(ui_position, rarity)):
				return

	if world.has_method("spawn_fishing_reward_confetti_particles"):
		world.spawn_fishing_reward_confetti_particles(_get_fishing_reward_confetti_position(), rarity)


func get_fishing_reward_confetti_ui_position() -> Vector2:
	return _get_fishing_reward_confetti_ui_position()


func _get_reward_rarity(item_id: String, _category: String = "fish") -> String:
	var safe_item_id := item_id.strip_edges()
	if safe_item_id == "" or world == null:
		return "common"

	if world.item_database.has(safe_item_id) and world.item_database[safe_item_id] is Dictionary:
		return str(world.item_database[safe_item_id].get("rarity", "common")).strip_edges().to_lower()

	return "common"


func _get_fishing_reward_confetti_position() -> Vector2:
	if world != null and world.player != null and is_instance_valid(world.player):
		return world.player.global_position + Vector2(0.0, -38.0)

	return Vector2.ZERO


func _get_fishing_reward_confetti_ui_position() -> Vector2:
	if fishing_ui != null and is_instance_valid(fishing_ui) and fishing_ui.has_method("get_catch_card_confetti_position"):
		return fishing_ui.get_catch_card_confetti_position()

	return Vector2(INF, INF)


func _get_fish_sell_value(fish_id: String, item_data: Dictionary) -> int:
	if world != null and world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_fish_sell_value"):
		return int(world.fish_monger_manager.get_fish_sell_value(fish_id))
	if item_data.has("sell_value"):
		return max(0, int(item_data.get("sell_value", 0)))
	if item_data.has("fish_sell_value"):
		return max(0, int(item_data.get("fish_sell_value", 0)))
	if item_data.has("sell_price"):
		return max(0, int(item_data.get("sell_price", 0)))
	if item_data.has("sell_price_per_lb"):
		return max(0, int(item_data.get("sell_price_per_lb", 0)))
	if item_data.has("price_per_lb"):
		return max(0, int(item_data.get("price_per_lb", 0)))
	match str(item_data.get("rarity", "common")):
		"uncommon":
			return 6
		"rare":
			return 16
		"epic":
			return 42
		"legendary":
			return 120
		_:
			return 3


func _calculate_fish_sale_value(count: int, value_per_fish: int) -> int:
	if count <= 0 or value_per_fish <= 0:
		return 0
	return count * value_per_fish


func _maybe_broadcast_legendary_catch(fish_id: String):
	var item_data: Dictionary = {}
	if world != null and world.item_database.has(fish_id):
		item_data = world.item_database[fish_id]
	if str(item_data.get("rarity", "common")).to_lower() != "legendary":
		return

	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null or not network.has_method("send_broadcast_message"):
		return
	var player_name := "Someone"
	if "player_name" in world:
		player_name = str(world.player_name)
	network.send_broadcast_message(player_name + " caught a legendary " + world.get_item_display_name(fish_id, "fish") + "!")


func _update_target_indicator():
	if fishing_ui == null or not fishing_ui.has_method("show_target_indicator"):
		return
	if world == null or not bool(world.in_world) or world.fishing_active:
		fishing_ui.hide_target_indicator()
		return
	if not _is_fishing_rod_ready_for_targeting():
		fishing_ui.hide_target_indicator()
		return

	var target_grid = world.get_mouse_grid_position()
	if can_reach_fishing_grid(target_grid) and is_fishable_water(target_grid):
		fishing_ui.show_target_indicator(target_grid)
	else:
		fishing_ui.hide_target_indicator()


func _is_fishing_rod_ready_for_targeting() -> bool:
	if world == null:
		return false
	if is_fishing_rod_item(str(world.equipped_tool)):
		return true
	return str(world.selected_item_category) == "tool" and is_fishing_rod_item(str(world.selected_item_type))


func _is_reeling_input_down() -> bool:
	if world != null:
		if world.has_method("is_chat_input_focused") and world.is_chat_input_focused():
			return false
		if world.has_method("is_any_text_input_focused") and world.is_any_text_input_focused():
			return false
	if fishing_ui != null and fishing_ui.has_method("is_reel_button_down") and bool(fishing_ui.is_reel_button_down()):
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	if Input.is_key_pressed(KEY_E):
		return true
	if Input.is_key_pressed(KEY_SPACE):
		return true
	return false


func _should_cancel_for_cleanup_rule() -> bool:
	if world == null:
		return true
	if not bool(world.in_world):
		return true
	if world.player == null:
		return true
	if cast_world_name != "" and str(world.current_world_name) != cast_world_name:
		return true
	if _is_blocking_ui_open_for_fishing():
		return true
	if world.fishing_target_grid != world.INVALID_GRID_POS and not can_reach_fishing_grid(world.fishing_target_grid):
		return true
	if not is_fishing_rod_item(str(world.equipped_tool)) and not (str(world.selected_item_category) == "tool" and is_fishing_rod_item(str(world.selected_item_type))):
		return true
	if cast_selected_item_type != "" and str(world.selected_item_type) != cast_selected_item_type:
		return true
	if cast_selected_item_category != "" and str(world.selected_item_category) != cast_selected_item_category:
		return true
	return false


func _is_blocking_ui_open_for_fishing() -> bool:
	if world == null:
		return true
	if world.has_method("is_player_menu_open") and world.is_player_menu_open(): return true
	if world.has_method("is_game_menu_open") and world.is_game_menu_open(): return true
	if world.has_method("is_world_menu_open") and world.is_world_menu_open(): return true
	if world.has_method("is_crafting_open") and world.is_crafting_open(): return true
	if world.has_method("is_furnace_open") and world.is_furnace_open(): return true
	if world.has_method("is_sign_open") and world.is_sign_open(): return true
	if world.has_method("is_shop_open") and world.is_shop_open(): return true
	if world.has_method("is_world_lock_ui_open") and world.is_world_lock_ui_open(): return true
	if world.has_method("is_trade_open") and world.is_trade_open(): return true
	if world.has_method("is_vending_open") and world.is_vending_open(): return true
	if world.has_method("is_safe_open") and world.is_safe_open(): return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
	if world.has_method("is_developer_panel_open") and world.is_developer_panel_open(): return true
	return false


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.75, 0.85, 0.90, 1.0)
		"uncommon":  return Color(0.28, 0.95, 0.45, 1.0)
		"rare":      return Color(0.28, 0.55, 1.00, 1.0)
		"epic":      return Color(0.72, 0.30, 1.00, 1.0)
		"legendary": return Color(1.00, 0.66, 0.12, 1.0)
		_:           return Color(0.75, 0.85, 0.90, 1.0)


# ── Legacy wrappers (world.gd compatibility) ──────────────────

func create_minigame_ui():
	_setup_fishing_ui()

func show_minigame_ui(show: bool):
	if fishing_ui == null:
		_setup_fishing_ui()
	if fishing_ui == null:
		return
	if show and fishing_ui.has_method("show_reeling"):
		fishing_ui.show_reeling(mg_progress, mg_tension, false)
	elif fishing_ui.has_method("hide_fishing_state"):
		fishing_ui.hide_fishing_state()

func update_minigame_visuals():
	if fishing_ui != null and fishing_ui.has_method("show_reeling") and state == STATE_MINIGAME:
		fishing_ui.show_reeling(mg_progress, mg_tension, _is_reeling_input_down())
