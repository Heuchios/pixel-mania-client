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

# ── Fishing state ─────────────────────────────────────────────
var state               = STATE_IDLE
var state_timer         = 0.0
var bobber              = null
var bobber_anim         = null
var current_lure_id     = ""
var pending_fish_id     = ""
var pending_fish_data   = {}
var server_fishing_session_id = ""
var waiting_for_server_catch = false

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

func use_fishing_rod_at_mouse(preferred_lure_id: String = ""):
	if world.fishing_active:
		handle_fishing_action()
		return

	var target_grid = world.get_mouse_grid_position()

	if not can_reach_fishing_grid(target_grid):
		world.show_notification("Water is too far away.")
		return

	if not is_fishable_water(target_grid):
		world.show_notification("Cast the fishing rod on water.")
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

	if world.equipped_tool != world.FISHING_ROD_ID:
		world.show_notification("Equip Fishing Rod first.")
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
			world.show_notification("Casting with " + world.get_item_display_name(lure_id, "lure") + "...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if request_server_fishing_start(target_grid, lure_id):
		world.show_notification("Casting with " + world.get_item_display_name(lure_id, "lure") + "...")
		return

	start_local_cast(target_grid, lure_id, true, "", {})


func start_local_cast(target_grid: Vector2i, lure_id: String, spend_lure: bool = true, session_id: String = "", fish_data: Dictionary = {}):
	if spend_lure:
		world.lure_inventory[lure_id] = max(0, int(world.lure_inventory.get(lure_id, 0)) - 1)

	world.fishing_lure_id   = lure_id
	world.fishing_target_grid = target_grid
	world.fishing_timer     = 0.0
	world.fishing_active    = true

	current_lure_id  = lure_id
	pending_fish_data = fish_data.duplicate(true)
	pending_fish_id  = str(pending_fish_data.get("fish_id", ""))
	server_fishing_session_id = session_id
	waiting_for_server_catch = false
	cast_selected_item_type = str(world.selected_item_type)
	cast_selected_item_category = str(world.selected_item_category)
	cast_world_name = str(world.current_world_name)
	state            = STATE_CASTING
	state_timer      = CAST_ANIMATION_TIME

	spawn_bobber(target_grid)
	play_bobber_anim("cast")
	_show_waiting_ui()

	world.update_all_ui()
	if spend_lure:
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

	return bool(network.send_inventory_transaction_request({
		"action": "fishing_start",
		"world": world.current_world_name,
		"target_x": target_grid.x,
		"target_y": target_grid.y,
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
	bobber.global_position = Vector2(
		target_grid.x * world.BLOCK_SIZE,
		target_grid.y * world.BLOCK_SIZE
	)
	bobber_anim = bobber.get_node_or_null("AnimationPlayer")


func play_bobber_anim(anim_name: String):
	if bobber_anim != null and bobber_anim.has_animation(anim_name):
		bobber_anim.play(anim_name)


func clear_bobber():
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()
	bobber      = null
	bobber_anim = null


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
	if not world.fishing_active:
		if state != STATE_IDLE:
			reset_fishing_state(false)
		return

	if _should_cancel_for_cleanup_rule():
		fail_fishing("Fish escaped...")
		return

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
		pending_fish_data = _roll_fish_entry(current_lure_id)

	pending_fish_id = str(pending_fish_data.get("fish_id", ""))

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

	var fish_name = world.get_item_display_name(pending_fish_id, "fish")
	var rarity    = "common"
	if world.item_database.has(pending_fish_id):
		rarity = str(world.item_database[pending_fish_id].get("rarity", "common"))

	if mg_fish_name != null:
		mg_fish_name.text = fish_name

	if mg_rarity_label != null:
		mg_rarity_label.text = rarity.capitalize()
		mg_rarity_label.add_theme_color_override("font_color", _rarity_color(rarity))

	if mg_fish_icon != null:
		mg_fish_icon.texture = world.fish_textures.get(pending_fish_id, null)

	if mg_lure_label != null:
		mg_lure_label.text = world.get_item_display_name(current_lure_id, "lure")


func _update_minigame(delta: float):
	mg_time_left = max(0.0, mg_time_left - delta)
	mg_fish_resist_phase += delta * mg_cursor_speed
	var fish_resist = 0.5 + sin(mg_fish_resist_phase) * 0.5
	var reeling := _is_reeling_input_down()

	if reeling:
		var safe_tension = clamp(1.0 - max(0.0, mg_tension - 0.62) * 0.82, 0.35, 1.0)
		mg_progress += mg_reel_rate * safe_tension * (1.0 - fish_resist * 0.20) * delta
		mg_tension += (mg_tension_gain + fish_resist * 0.20) * delta
	else:
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

	var owned_before: float = _get_owned_fish_weight(pending_fish_id)
	var catch_weight: float = _normalize_fish_weight(_roll_catch_weight(pending_fish_id))
	var catch_record: Dictionary = record_fish_catch(pending_fish_id, catch_weight)
	var was_new: bool = bool(catch_record.get("was_new", owned_before <= 0.0))
	_add_fish_weight_to_inventory(pending_fish_id, catch_weight)

	_show_catch_result(pending_fish_id, was_new, catch_weight)
	_show_catch_notification(pending_fish_id, catch_weight)
	_maybe_broadcast_legendary_catch(pending_fish_id)
	play_bobber_anim("reel_success")
	world.update_all_ui()
	world.save_player_data()
	reset_fishing_state(true)


func _normalize_fish_weight(weight) -> float:
	return snapped(max(0.0, float(weight)), 0.1)


func _get_owned_fish_weight(fish_id: String) -> float:
	if world == null or fish_id == "":
		return 0.0
	return _normalize_fish_weight(world.fish_inventory.get(fish_id, 0.0))


func _add_fish_weight_to_inventory(fish_id: String, weight) -> void:
	if world == null or fish_id == "":
		return
	var safe_weight: float = _normalize_fish_weight(weight)
	if safe_weight <= 0.0:
		return
	world.fish_inventory[fish_id] = _normalize_fish_weight(_get_owned_fish_weight(fish_id) + safe_weight)


func _apply_server_fish_inventory_result(data: Dictionary, fish_id: String, catch_weight) -> void:
	if world == null or fish_id == "":
		return

	var inventory_payload = data.get("fish_inventory", null)
	if inventory_payload is Dictionary and inventory_payload.has(fish_id):
		world.fish_inventory[fish_id] = _normalize_fish_weight(inventory_payload.get(fish_id, 0.0))
		return

	for key in ["owned_weight_lb", "total_weight_lb", "fish_weight_lb", "new_weight_lb"]:
		if data.has(key):
			world.fish_inventory[fish_id] = _normalize_fish_weight(data.get(key, 0.0))
			return

	_add_fish_weight_to_inventory(fish_id, catch_weight)


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
		if not bool(data.get("ok", false)):
			world.show_notification(str(data.get("message", "Could not start fishing.")))
			return true

		var target_grid = Vector2i(int(data.get("target_x", 0)), int(data.get("target_y", 0)))
		var lure_id = str(data.get("lure_id", ""))
		var fish_data = {
			"fish_id": str(data.get("fish_id", "")),
			"difficulty": int(data.get("difficulty", 1))
		}
		start_local_cast(target_grid, lure_id, false, str(data.get("session_id", "")), fish_data)
		return true

	if action == "fishing_complete":
		waiting_for_server_catch = false
		var message = str(data.get("message", "Fishing finished."))
		var caught_fish_id: String = ""
		var caught_weight: float = 0.0

		if bool(data.get("ok", false)):
			var fish_id = str(data.get("fish_id", ""))
			if fish_id != "":
				var server_weight: float = _normalize_fish_weight(float(data.get("catch_weight", _roll_catch_weight(fish_id))))
				caught_fish_id = fish_id
				caught_weight = server_weight
				var server_owned_before: float = _get_owned_fish_weight(fish_id)
				var server_record: Dictionary = record_fish_catch(fish_id, server_weight)
				var server_new: bool = bool(data.get("is_new", server_record.get("was_new", server_owned_before <= 0.0)))
				_apply_server_fish_inventory_result(data, fish_id, server_weight)
				_show_catch_result(fish_id, server_new, server_weight)
				_maybe_broadcast_legendary_catch(fish_id)
			if message.strip_edges() != "":
				world.show_notification(message)
			elif caught_fish_id != "":
				_show_catch_notification(caught_fish_id, caught_weight)
		else:
			world.show_notification(message)

		world.update_all_ui()
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
	world.fishing_active      = false
	world.fishing_timer       = 0.0
	world.fishing_lure_id     = ""
	world.fishing_target_grid = world.INVALID_GRID_POS
	state           = STATE_IDLE
	state_timer     = 0.0
	current_lure_id = ""
	pending_fish_id = ""
	pending_fish_data = {}
	server_fishing_session_id = ""
	cast_selected_item_type = ""
	cast_selected_item_category = ""
	cast_world_name = ""
	_hide_fishing_state_ui()

	if delay_bobber:
		call_deferred("clear_bobber")
	else:
		clear_bobber()


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
	for lure_id in ["golden_lure", "shiny_lure", "worm_lure"]:
		if world.lure_inventory.has(lure_id) and int(world.lure_inventory[lure_id]) > 0:
			return lure_id
	for lure_id in world.lure_inventory.keys():
		if int(world.lure_inventory[lure_id]) > 0:
			return str(lure_id)
	return ""


# ── Loot tables ───────────────────────────────────────────────

func roll_fish_for_lure(lure_id: String) -> String:
	return str(_roll_fish_entry(lure_id).get("fish_id", ""))


func _roll_fish_entry(lure_id: String) -> Dictionary:
	var table = get_fishing_table_for_lure(lure_id)
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


func get_fishing_table_for_lure(lure_id: String) -> Array:
	match lure_id:
		"worm_lure":
			return [
				{"fish_id": "pond_fish",    "weight": 65, "difficulty": 1},
				{"fish_id": "bluegill",     "weight": 28, "difficulty": 2},
				{"fish_id": "golden_carp",  "weight": 6,  "difficulty": 4},
				{"fish_id": "crystal_fish", "weight": 1,  "difficulty": 6}
			]
		"shiny_lure":
			return [
				{"fish_id": "pond_fish",    "weight": 38, "difficulty": 1},
				{"fish_id": "bluegill",     "weight": 42, "difficulty": 2},
				{"fish_id": "golden_carp",  "weight": 16, "difficulty": 4},
				{"fish_id": "crystal_fish", "weight": 4,  "difficulty": 6}
			]
		"golden_lure":
			return [
				{"fish_id": "bluegill",     "weight": 35, "difficulty": 2},
				{"fish_id": "golden_carp",  "weight": 50, "difficulty": 4},
				{"fish_id": "crystal_fish", "weight": 15, "difficulty": 6}
			]
		_:
			return [
				{"fish_id": "pond_fish", "weight": 80, "difficulty": 1},
				{"fish_id": "bluegill",  "weight": 20, "difficulty": 2}
			]


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
	var roll = randi_range(1, 100)
	if roll <= 65: return "worm_lure"
	if roll <= 93: return "shiny_lure"
	return "golden_lure"


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
		"shiny_lure":  return 0.045
		"golden_lure": return 0.075
		_:             return 0.0


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
	var catch_value: int = _calculate_fish_sale_value(rounded_weight, sell_value)

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
		"price_per_lb": sell_value
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
			"price_per_lb": _get_fish_sell_value(fish_id, item_data),
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
	if world != null and world.fish_inventory.has(fish_id) and float(world.fish_inventory.get(fish_id, 0.0)) > 0.0:
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


func _show_catch_result(fish_id: String, was_new: bool = false, catch_weight: float = -1.0):
	if fishing_ui == null or not fishing_ui.has_method("show_catch_result"):
		return
	fishing_ui.show_catch_result(_build_catch_result_data(fish_id, was_new, catch_weight))


func _build_catch_result_data(fish_id: String, was_new: bool, catch_weight: float = -1.0) -> Dictionary:
	var item_data: Dictionary = {}
	if world != null and world.item_database.has(fish_id):
		item_data = world.item_database[fish_id]

	var rarity: String = str(item_data.get("rarity", "common")).to_lower()
	var display_weight: float = catch_weight if catch_weight > 0.0 else _roll_display_weight_for_rarity(rarity)
	return {
		"fish_id": fish_id,
		"name": world.get_item_display_name(fish_id, "fish") if world != null else fish_id,
		"rarity": rarity,
		"weight": _format_fish_weight(display_weight),
		"value": _calculate_fish_sale_value(display_weight, _get_fish_sell_value(fish_id, item_data)),
		"price_per_lb": _get_fish_sell_value(fish_id, item_data),
		"is_new": was_new,
		"icon": world.fish_textures.get(fish_id, null) if world != null else null
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


func _show_catch_notification(fish_id: String, weight: float) -> void:
	if world == null or not world.has_method("show_notification"):
		return
	world.show_notification("Caught " + world.get_item_display_name(fish_id, "fish") + " weighing " + _format_fish_weight(weight) + "!")


func _get_fish_sell_value(fish_id: String, item_data: Dictionary) -> int:
	if world != null and world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_fish_sell_value"):
		return int(world.fish_monger_manager.get_fish_sell_value(fish_id))
	if item_data.has("sell_price_per_lb"):
		return max(0, int(item_data.get("sell_price_per_lb", 0)))
	if item_data.has("price_per_lb"):
		return max(0, int(item_data.get("price_per_lb", 0)))
	if item_data.has("sell_value"):
		return max(0, int(item_data.get("sell_value", 0)))
	if item_data.has("fish_sell_value"):
		return max(0, int(item_data.get("fish_sell_value", 0)))
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


func _calculate_fish_sale_value(weight: float, price_per_lb: int) -> int:
	var tenths: int = max(0, int(round(snapped(max(0.0, weight), 0.1) * 10.0)))
	if tenths <= 0 or price_per_lb <= 0:
		return 0
	return int(floor((float(price_per_lb) * float(tenths)) / 10.0))


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
	if str(world.equipped_tool) == world.FISHING_ROD_ID:
		return true
	return str(world.selected_item_category) == "tool" and str(world.selected_item_type) == world.FISHING_ROD_ID


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
	if world.has_method("is_chat_input_focused") and world.is_chat_input_focused():
		return true
	if _is_blocking_ui_open_for_fishing():
		return true
	if world.fishing_target_grid != world.INVALID_GRID_POS and not can_reach_fishing_grid(world.fishing_target_grid):
		return true
	if str(world.equipped_tool) != world.FISHING_ROD_ID:
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
