extends Node

var world = null

const MAX_WORLD_NETWORK_ENTRIES_PER_SECTION := 2500
const MAX_WORLD_COORD := 1000000
const MAX_WORLD_STATE_GROW_TIME_SECONDS := 3600.0 * 24.0 * 30.0
const MAX_DROP_PICKUP_DELAY_SECONDS := 120.0
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_SIGN_TEXT_LENGTH := 128
const DEBUG_ACTION_POSITION_FLOW := false


func _safe_int(value, fallback: int, min_value: int = -2147483648, max_value: int = 2147483647) -> int:
	if value is int or value is float:
		if value is float and not is_finite(value):
			return fallback
		return clamp(int(value), min_value, max_value)

	if value is String:
		var text = value.strip_edges()
		if text == "":
			return fallback
		if text.is_valid_int():
			return clamp(int(text), min_value, max_value)

	return fallback


func _safe_float(value, fallback: float, min_value: float = -1.0e9, max_value: float = 1.0e9) -> float:
	if value is int or value is float:
		var number = float(value)
		if not is_finite(number):
			return fallback
		return clamp(number, min_value, max_value)

	if value is String:
		var text = value.strip_edges()
		if text == "":
			return fallback
		var number = text.to_float()
		if not is_finite(number):
			return fallback
		return clamp(number, min_value, max_value)

	return fallback


func _safe_bool(value, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		if not is_finite(value):
			return fallback
		return value != 0.0
	if value is String:
		var text = value.strip_edges().to_lower()
		if text == "":
			return fallback
		match text:
			"1", "true", "yes", "on", "y":
				return true
			"0", "false", "no", "off", "n":
				return false
	return fallback


func _safe_string(value, fallback: String = "", max_length: int = 0) -> String:
	if value == null:
		return fallback
	var text = str(value).strip_edges()
	if text == "":
		return fallback
	if max_length > 0 and text.length() > max_length:
		text = text.substr(0, max_length)
	return text


func _safe_world_name(value) -> String:
	var raw_text = _safe_string(value, "", 64).strip_edges().to_lower()
	if raw_text == "":
		return ""
	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""
	for i in range(raw_text.length()):
		var character = raw_text.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	if result == "":
		return ""
	if result.length() > 64:
		result = result.substr(0, 64)
	return result.to_upper()


func _get_message_world_name(data: Dictionary) -> String:
	if not (data is Dictionary):
		return ""

	for key in ["world", "world_name", "world_id", "current_world_id"]:
		if not data.has(key):
			continue
		var clean_world = _safe_world_name(data.get(key, ""))
		if clean_world != "":
			return clean_world

	return ""


func _safe_grid_position(raw_x, raw_y) -> Vector2i:
	var max_x = 0
	var max_y = 0

	if world != null:
		max_x = max(world.WORLD_WIDTH - 1, 0)
		max_y = max(world.WORLD_HEIGHT - 1, 0)

	var safe_x = _safe_int(raw_x, 0, 0, max_x)
	var safe_y = _safe_int(raw_y, 0, 0, max_y)
	return Vector2i(safe_x, safe_y)


func _is_current_world_message(data: Dictionary) -> bool:
	if world == null:
		return false

	var incoming_world = _get_message_world_name(data)
	if incoming_world == "":
		incoming_world = _safe_world_name(world.current_world_name)
	if incoming_world == "":
		return false

	var local_world = _safe_world_name(world.current_world_name)
	if incoming_world == local_world:
		return true

	if is_waiting_for_server_world_entry():
		world.current_world_name = incoming_world
		return true

	return false


func _get_local_session_username() -> String:
	if world == null:
		return ""

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_active_session_username"):
		var session_name = _safe_string(network.get_active_session_username(), "", 64).strip_edges().to_upper()
		if session_name != "":
			return session_name

	if world.has_method("get_current_profile_name"):
		return _safe_string(world.get_current_profile_name(), "", 64).strip_edges().to_upper()

	return ""


func _is_local_player_confirmed_update(data: Dictionary) -> bool:
	var actor_name = _safe_string(data.get("username", data.get("account_username", "")), "", 64).strip_edges().to_upper()

	if actor_name == "":
		var player_data = data.get("player_data", {})
		if player_data is Dictionary:
			actor_name = _safe_string(player_data.get("account_username", player_data.get("username", "")), "", 64).strip_edges().to_upper()

	if actor_name == "":
		return false

	return actor_name == _get_local_session_username()


func _should_claim_confirmed_world_lock_place(data: Dictionary, layer: String, grid_pos: Vector2i, block_type: String) -> bool:
	if layer != "foreground" or block_type != "world_lock":
		return false

	if world == null or world.world_lock_manager == null:
		return false

	if bool(world.world_lock_manager.is_locked):
		return false

	if not world.has_method("on_world_lock_block_placed"):
		return false

	if not world.blocks.has(grid_pos):
		return false

	return _is_local_player_confirmed_update(data)


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][WorldStateSyncManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func is_waiting_for_server_world_entry() -> bool:
	if world == null or world.save_manager == null:
		return false
	if not ("waiting_for_server_world_state" in world.save_manager):
		return false
	return bool(world.save_manager.waiting_for_server_world_state)


func should_respawn_for_world_state(data: Dictionary) -> bool:
	if not _safe_bool(data.get("respawn_player", false), false):
		return false

	var reason = str(data.get("world_state_reason", data.get("reason", ""))).strip_edges().to_lower()
	if is_waiting_for_server_world_entry():
		return true

	if _safe_bool(data.get("force_respawn", false), false):
		return true

	if reason == "admin_clear" or reason == "admin_reset" or reason == "admin_reload" or reason == "death_respawn":
		return true

	return false


func get_world_state_debug_summary(data: Dictionary) -> Dictionary:
	var foreground = data.get("foreground", [])
	var background = data.get("background", [])
	var drops = data.get("drops", data.get("item_drops", []))
	return {
		"respawn_player": data.get("respawn_player", null),
		"force_respawn": data.get("force_respawn", null),
		"world_state_reason": str(data.get("world_state_reason", "")),
		"foreground_count": foreground.size() if foreground is Array else 0,
		"background_count": background.size() if background is Array else 0,
		"drop_count": drops.size() if drops is Array else 0
	}


func setup(world_ref):
	world = world_ref


func normalize_vending_state_payload(data: Dictionary, grid_pos: Vector2i) -> Dictionary:
	var state_payload: Dictionary = {}

	if data.has("state") and data.get("state") is Dictionary:
		state_payload = data.get("state").duplicate(true)
	else:
		state_payload = data.duplicate(true)

	state_payload["x"] = grid_pos.x
	state_payload["y"] = grid_pos.y

	var listing = state_payload.get("listing", {})
	if not (listing is Dictionary):
		state_payload["listing"] = {}

	var logs = state_payload.get("logs", [])
	if not (logs is Array):
		state_payload["logs"] = []

	state_payload["pending_wls"] = _safe_int(state_payload.get("pending_wls", 0), 0, 0, 1000000000)
	state_payload["can_manage"] = _safe_bool(state_payload.get("can_manage", false), false)

	return state_payload


func apply_network_world_state(data: Dictionary):
	if not _is_current_world_message(data):
		return

	debug_action_position_flow("world_state apply start", {
		"respawn_player": data.get("respawn_player", null),
		"force_respawn": data.get("force_respawn", null),
		"world_state_reason": str(data.get("world_state_reason", "")),
		"waiting_for_entry": is_waiting_for_server_world_entry()
	})

	if world.safe_ui != null and world.safe_ui.has_method("close_safe"):
		world.safe_ui.close_safe()

	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("close_fish_monger"):
		world.fish_monger_ui.close_fish_monger()

	if not world.is_smooth_world_load_visible():
		world.begin_smooth_world_load(world.current_world_name, false)

	world.update_smooth_world_load_message("Building " + str(world.current_world_name).to_upper() + "...")

	world.applying_network_world_update = true
	world.vending_states.clear()
	world.safe_states.clear()
	world.clear_world()

	var server_cleared_world = bool(data.get("cleared", data.get("world_cleared", data.get("clear_generated", false))))
	if not server_cleared_world:
		world.generate_world()

	var foreground = data.get("foreground", [])
	if foreground is Array:
		var processed = 0
		for entry in foreground:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"action": "place",
					"layer": "foreground",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64),
					"entrance_locked": _safe_bool(entry.get("entrance_locked", false), false),
					"sign_text": _safe_string(entry.get("sign_text", ""), "", MAX_SIGN_TEXT_LENGTH)
				})
				processed += 1

	var background = data.get("background", [])
	if background is Array:
		var processed = 0
		for entry in background:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"action": "place",
					"layer": "background",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64)
				})
				processed += 1

	var removed_foreground = data.get("removed_foreground", [])
	if removed_foreground is Array:
		var processed = 0
		for entry in removed_foreground:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"action": "break",
					"layer": "foreground",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64)
				})
				processed += 1

	var removed_background = data.get("removed_background", [])
	if removed_background is Array:
		var processed = 0
		for entry in removed_background:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"action": "break",
					"layer": "background",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64)
				})
				processed += 1

	var seeds = data.get("seeds", [])
	if seeds is Array:
		var processed = 0
		for entry in seeds:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_seed_update({
					"world": world.current_world_name,
					"action": "place",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"seed_type": _safe_string(entry.get("seed_type", ""), "", 64),
					"grow_time": _safe_float(entry.get("grow_time", world.SEED_GROW_TIME), float(world.SEED_GROW_TIME), 0.0, MAX_WORLD_STATE_GROW_TIME_SECONDS),
					"max_grow_time": _safe_float(entry.get("max_grow_time", world.SEED_GROW_TIME), float(world.SEED_GROW_TIME), 0.0, MAX_WORLD_STATE_GROW_TIME_SECONDS),
					"mature": _safe_bool(entry.get("mature", false), false),
					"mutated": _safe_bool(entry.get("mutated", false), false)
				})
				processed += 1

	var interactions = data.get("interactions", [])
	if interactions is Array:
		var processed = 0
		for entry in interactions:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_world_interaction_update(entry)
				processed += 1

	var world_lock_state = data.get("world_lock", {})
	if world_lock_state is Dictionary:
		apply_network_world_interaction_update({
			"world": world.current_world_name,
			"action": "world_lock_state",
			"state": world_lock_state
		})

	var drops = data.get("drops", data.get("item_drops", []))
	if drops is Array:
		if world.drop_manager != null and world.drop_manager.has_method("clear"):
			world.drop_manager.clear()

		var drop_world = _get_message_world_name(data)
		if drop_world == "":
			drop_world = _safe_world_name(world.current_world_name)

		var processed = 0
		for entry in drops:
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				var drop_payload = {
					"world": drop_world,
					"drop_id": _safe_string(entry.get("drop_id", entry.get("id", "")), "", 64),
					"item_type": _safe_string(entry.get("item_type", entry.get("item_id", entry.get("block_type", entry.get("type", "")))), "", 64),
					"item_category": _safe_string(entry.get("item_category", entry.get("category", "")), "", 64),
					"is_seed": _safe_bool(entry.get("is_seed", false), false),
					"amount": _safe_int(entry.get("amount", 1), 1, 1, MAX_DROP_TILE_AMOUNT),
					"x": _safe_float(entry.get("x", 0.0), 0.0, float(-MAX_WORLD_COORD), float(MAX_WORLD_COORD)),
					"y": _safe_float(entry.get("y", 0.0), 0.0, float(-MAX_WORLD_COORD), float(MAX_WORLD_COORD)),
					"pickup_delay": _safe_float(entry.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
				}
				if entry.has("stack_grid_x") or entry.has("grid_x") or entry.has("tile_x"):
					drop_payload["stack_grid_x"] = _safe_int(entry.get("stack_grid_x", entry.get("grid_x", entry.get("tile_x", 0))), 0, 0, MAX_WORLD_COORD)
				if entry.has("stack_grid_y") or entry.has("grid_y") or entry.has("tile_y"):
					drop_payload["stack_grid_y"] = _safe_int(entry.get("stack_grid_y", entry.get("grid_y", entry.get("tile_y", 0))), 0, 0, MAX_WORLD_COORD)
				world.apply_network_item_drop_create(drop_payload)
				processed += 1

	world.ensure_entrance_gate()

	if should_respawn_for_world_state(data):
		debug_action_position_flow("world_state respawning player", get_world_state_debug_summary(data))
		world.respawn_player()
	elif bool(data.get("respawn_player", false)):
		debug_action_position_flow("world_state skipped respawn outside entry/reload", get_world_state_debug_summary(data))

	world.applying_network_world_update = false

	if world.save_manager != null and world.save_manager.has_method("finish_world_entry_after_load"):
		world.save_manager.finish_world_entry_after_load(false, true)
	else:
		world.finish_smooth_world_load()

	if world.has_method("queue_refresh_all_vending_machine_previews"):
		world.queue_refresh_all_vending_machine_previews()
	elif world.has_method("refresh_all_vending_machine_previews"):
		world.refresh_all_vending_machine_previews()

	debug_action_position_flow("world_state apply end", {
		"respawn_player": data.get("respawn_player", null),
		"world_state_reason": str(data.get("world_state_reason", ""))
	})


func apply_network_block_update(data: Dictionary):
	if not _is_current_world_message(data):
		return

	var old_flag = world.applying_network_world_update
	world.applying_network_world_update = true

	var action = _safe_string(data.get("action", ""), "", 16).to_lower()
	if action != "break" and action != "place":
		world.applying_network_world_update = old_flag
		return

	var layer = _safe_string(data.get("layer", "foreground"), "", 16).to_lower()
	if layer != "foreground" and layer != "background":
		world.applying_network_world_update = old_flag
		return

	var grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
	var block_type = _safe_string(data.get("block_type", ""), "", 64)
	var should_claim_world_lock_place := false

	if action == "break":
		debug_action_position_flow("apply_network_block_update break start", {
			"layer": layer,
			"x": grid_pos.x,
			"y": grid_pos.y,
			"block_type": block_type
		})
		if layer == "background":
			if world.block_manager != null and world.block_manager.has_method("remove_background_block_without_drop"):
				world.block_manager.remove_background_block_without_drop(grid_pos)
		else:
			world.vending_states.erase(grid_pos)
			world.safe_states.erase(grid_pos)
			if world.block_manager != null and world.block_manager.has_method("remove_block_without_drop"):
				world.block_manager.remove_block_without_drop(grid_pos)
		debug_action_position_flow("apply_network_block_update break end", {
			"layer": layer,
			"x": grid_pos.x,
			"y": grid_pos.y,
			"block_type": block_type
		})

	elif action == "place" and block_type != "":
		if layer == "background":
			if world.block_manager != null and world.block_manager.has_method("replace_background_block_without_drop"):
				world.block_manager.replace_background_block_without_drop(grid_pos, block_type)
		else:
			if world.block_manager != null and world.block_manager.has_method("replace_block_without_drop"):
				world.block_manager.replace_block_without_drop(grid_pos, block_type)
			should_claim_world_lock_place = _should_claim_confirmed_world_lock_place(data, layer, grid_pos, block_type)

		if world.blocks.has(grid_pos):
			if data.has("entrance_locked") and str(world.blocks[grid_pos].get("type", "")) == "wooden_entrance":
				world.set_wooden_entrance_locked(grid_pos, _safe_bool(data.get("entrance_locked", false), false))

			if data.has("sign_text") and str(world.blocks[grid_pos].get("type", "")) == "sign":
				world.blocks[grid_pos]["sign_text"] = _safe_string(data.get("sign_text", ""), "", MAX_SIGN_TEXT_LENGTH)
				world.update_sign_text_visual(grid_pos)

			if world.vending_states.has(grid_pos) or world.is_vending_machine_block_type(block_type):
				world.update_vending_machine_preview(grid_pos)

	world.applying_network_world_update = old_flag

	if should_claim_world_lock_place:
		world.on_world_lock_block_placed(grid_pos)


func apply_network_world_interaction_update(data: Dictionary):
	if not _is_current_world_message(data):
		return

	var old_flag = world.applying_network_world_update
	world.applying_network_world_update = true

	var action = _safe_string(data.get("action", ""), "", 24).to_lower()

	if action == "wooden_entrance_state":
		var entrance_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(entrance_grid_pos) and str(world.blocks[entrance_grid_pos].get("type", "")) == "wooden_entrance":
			world.set_wooden_entrance_locked(entrance_grid_pos, _safe_bool(data.get("locked", false), false))

	elif action == "sign_text":
		var sign_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(sign_grid_pos) and str(world.blocks[sign_grid_pos].get("type", "")) == "sign":
			world.blocks[sign_grid_pos]["sign_text"] = _safe_string(data.get("text", ""), "", MAX_SIGN_TEXT_LENGTH)
			world.update_sign_text_visual(sign_grid_pos)

	elif action == "world_lock_state":
		var state = data.get("state", {})
		if state is Dictionary and world.world_lock_manager != null and world.world_lock_manager.has_method("load_save_data"):
			world.world_lock_manager.load_save_data(state)

	elif action == "vend_state":
		var vend_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var state_payload = normalize_vending_state_payload(data, vend_grid_pos)
		world.vending_states[vend_grid_pos] = state_payload
		world.update_vending_machine_preview(vend_grid_pos)
		if world.vending_ui != null and world.vending_ui.has_method("handle_vend_state"):
			world.vending_ui.handle_vend_state(state_payload)

	elif action == "safe_state":
		var safe_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var state_payload = {}
		if data is Dictionary and data.has("state") and data.get("state") is Dictionary:
			state_payload["state"] = data.get("state").duplicate(true)
		else:
			state_payload["state"] = {}
		world.safe_states[safe_grid_pos] = state_payload
		if world.safe_ui != null and world.safe_ui.has_method("handle_safe_state"):
			world.safe_ui.handle_safe_state(data)

	world.applying_network_world_update = old_flag


func apply_network_seed_update(data: Dictionary):
	if not _is_current_world_message(data):
		return

	var old_flag = world.applying_network_world_update
	world.applying_network_world_update = true

	var action = _safe_string(data.get("action", ""), "", 16).to_lower()
	if action != "place" and action != "splice" and action != "remove":
		world.applying_network_world_update = old_flag
		return

	var grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
	var seed_type = _safe_string(data.get("seed_type", ""), "", 64)

	if (action == "place" or action == "splice") and seed_type != "":
		if world.seed_system != null and world.seed_system.has_method("remove_seed_at") and world.has_planted_seed(grid_pos):
			world.seed_system.remove_seed_at(grid_pos)

		world.create_planted_seed(
			grid_pos,
			seed_type,
			_safe_float(data.get("grow_time", world.SEED_GROW_TIME), float(world.SEED_GROW_TIME), 0.0, MAX_WORLD_STATE_GROW_TIME_SECONDS),
			_safe_float(data.get("max_grow_time", world.SEED_GROW_TIME), float(world.SEED_GROW_TIME), 0.0, MAX_WORLD_STATE_GROW_TIME_SECONDS)
		)

		if world.seed_system != null and world.seed_system.has_method("set_seed_mutated"):
			world.seed_system.set_seed_mutated(grid_pos, _safe_bool(data.get("mutated", false), false))

		if world.seed_system != null and world.seed_system.has_method("set_seed_mature") and _safe_bool(data.get("mature", false), false):
			world.seed_system.set_seed_mature(grid_pos, true)
	elif action == "remove":
		if world.seed_system != null and world.seed_system.has_method("remove_seed_at"):
			world.seed_system.remove_seed_at(grid_pos)

	world.applying_network_world_update = old_flag
