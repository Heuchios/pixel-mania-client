extends Node

const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")

var world = null

const MAX_WORLD_NETWORK_ENTRIES_PER_SECTION := 8000
const MAX_WORLD_COORD := 1000000
const MAX_WORLD_STATE_GROW_TIME_SECONDS := 3600.0 * 24.0 * 30.0
const MAX_DROP_ID_LENGTH := 96
const MAX_DROP_PICKUP_DELAY_SECONDS := 120.0
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_BLOCK_HIT_METRIC := 1024
const MAX_SIGN_TEXT_LENGTH := 128
const MAX_MAILBOX_MESSAGE_LENGTH := 128
const MAX_BULLETIN_BOARD_MESSAGE_LENGTH := 220
const MAX_BULLETIN_BOARD_MESSAGES := 30
const MAX_CCTV_EVENTS := 20
const MAX_DOOR_ID_LENGTH := 32
const MAX_DOOR_NAME_LENGTH := 64
const MAX_DOOR_DESTINATION_LENGTH := 80
const TACKLE_BOX_DEFAULT_COOLDOWN_MS := 14400000
const CHICKEN_DEFAULT_PRODUCTION_MS := 43200000
const CHICKEN_DEFAULT_HUNGER_MS := 604800000
const COW_DEFAULT_PRODUCTION_MS := 43200000
const COW_DEFAULT_HUNGER_MS := 604800000
const DUCK_DEFAULT_PRODUCTION_MS := 43200000
const DUCK_DEFAULT_HUNGER_MS := 604800000
const DEBUG_ACTION_POSITION_FLOW := false
const WORLD_STATE_APPLY_MIN_BATCH_SIZE := 128
const WORLD_STATE_APPLY_MAX_BATCH_SIZE := 2048
const WORLD_STATE_APPLY_DESKTOP_BUDGET_USEC := 6000
const WORLD_STATE_APPLY_MOBILE_BUDGET_USEC := 3500
const WORLD_STATE_SPAWN_PRIORITY_RADIUS := 12
# Give the loading CanvasLayer a chance to draw before heavy world-state work.
const WORLD_STATE_OVERLAY_DRAW_FRAMES := 2

var world_state_apply_generation: int = 0
var active_world_state_apply_generation: int = 0
var block_revision_world: String = ""
var latest_block_revision: int = 0
var block_cell_revisions: Dictionary = {}
var world_state_apply_batch_started_usec: int = 0


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


func _get_world_state_apply_budget_usec() -> int:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return WORLD_STATE_APPLY_MOBILE_BUDGET_USEC
	return WORLD_STATE_APPLY_DESKTOP_BUDGET_USEC


func _should_yield_world_state_apply(entries_since_yield: int) -> bool:
	if entries_since_yield < WORLD_STATE_APPLY_MIN_BATCH_SIZE:
		return false
	var now_usec: int = Time.get_ticks_usec()
	if (
		entries_since_yield < WORLD_STATE_APPLY_MAX_BATCH_SIZE
		and now_usec - world_state_apply_batch_started_usec < _get_world_state_apply_budget_usec()
	):
		return false
	world_state_apply_batch_started_usec = now_usec
	return true


func _block_cell_revision_key(layer: String, grid_pos: Vector2i) -> String:
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer != "background":
		clean_layer = "foreground"
	return "%s:%d:%d" % [clean_layer, grid_pos.x, grid_pos.y]


func _reset_block_revision_tracking(world_name: String, world_revision: int = 0) -> void:
	block_revision_world = _safe_world_name(world_name)
	latest_block_revision = maxi(0, world_revision)
	block_cell_revisions.clear()


func _record_block_revision(layer: String, grid_pos: Vector2i, revision: int) -> void:
	if revision <= 0:
		return
	var key := _block_cell_revision_key(layer, grid_pos)
	block_cell_revisions[key] = maxi(int(block_cell_revisions.get(key, 0)), revision)
	latest_block_revision = maxi(latest_block_revision, revision)


func _should_ignore_stale_block_update(layer: String, grid_pos: Vector2i, revision: int, is_from_world_state: bool) -> bool:
	if revision <= 0 or is_from_world_state:
		return false
	var key := _block_cell_revision_key(layer, grid_pos)
	return revision <= int(block_cell_revisions.get(key, 0))


func is_toggle_block_type(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("toggle_block", false))

	return false


func apply_toggle_block_state(grid_pos: Vector2i, toggle_on: bool):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_toggle_block_type(block_type):
		return

	var state_key = str(world.item_database[block_type].get("toggle_state_key", "toggle_on"))
	world.blocks[grid_pos][state_key] = toggle_on

	if world.block_manager != null and world.block_manager.has_method("update_toggle_block_visual"):
		world.block_manager.update_toggle_block_visual(grid_pos)


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


func _parse_world_layer_key(raw_key) -> Dictionary:
	var key := str(raw_key).strip_edges()
	var parts := key.split(",", false)
	if parts.size() < 2:
		return {}
	var x_text := str(parts[0]).strip_edges()
	var y_text := str(parts[1]).strip_edges()
	if not x_text.is_valid_int() or not y_text.is_valid_int():
		return {}
	return {
		"x": _safe_int(x_text, 0, 0, MAX_WORLD_COORD),
		"y": _safe_int(y_text, 0, 0, MAX_WORLD_COORD)
	}


func _normalize_world_layer_entries(raw_layer) -> Array:
	var entries: Array = []
	if raw_layer is Array:
		for raw_entry in raw_layer:
			if raw_entry is Dictionary:
				# Stream payloads are immutable for the lifetime of a full-state apply.
				# Keep references here instead of cloning every block before immediately
				# reading it into the authoritative world rebuild.
				entries.append(raw_entry)
		return entries

	if raw_layer is Dictionary:
		for raw_key in (raw_layer as Dictionary).keys():
			var parsed_key := _parse_world_layer_key(raw_key)
			if parsed_key.is_empty():
				continue
			var raw_value = (raw_layer as Dictionary).get(raw_key)
			var entry := {
				"x": parsed_key.get("x", 0),
				"y": parsed_key.get("y", 0)
			}
			if raw_value is Dictionary:
				for field in (raw_value as Dictionary).keys():
					entry[field] = raw_value[field]
			else:
				entry["item_id"] = raw_value
			entries.append(entry)
	return entries


func _prioritize_world_layer_entries_for_spawn(entries: Array, data: Dictionary) -> Array:
	if entries.size() <= 1 or not data.has("spawn_grid_x") or not data.has("spawn_grid_y"):
		return entries

	var spawn_grid := Vector2i(
		_safe_int(data.get("spawn_grid_x", 0), 0, 0, MAX_WORLD_COORD),
		_safe_int(data.get("spawn_grid_y", 0), 0, 0, MAX_WORLD_COORD)
	)
	var nearby_entries: Array = []
	var remaining_entries: Array = []
	nearby_entries.resize(0)
	remaining_entries.resize(0)
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry := raw_entry as Dictionary
			var entry_x := _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD)
			var entry_y := _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD)
			if absi(entry_x - spawn_grid.x) <= WORLD_STATE_SPAWN_PRIORITY_RADIUS and absi(entry_y - spawn_grid.y) <= WORLD_STATE_SPAWN_PRIORITY_RADIUS:
				nearby_entries.append(entry)
				continue
		remaining_entries.append(raw_entry)

	if nearby_entries.is_empty() or remaining_entries.is_empty():
		return entries
	nearby_entries.append_array(remaining_entries)
	return nearby_entries


func _profile_world_entry_stage(stage: String, extra: Dictionary = {}) -> void:
	var network = null
	if world != null:
		network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("record_world_entry_stage"):
		network.record_world_entry_stage(stage, extra)


func _update_world_build_progress(applied: int, total: int) -> void:
	if world == null or not world.has_method("update_smooth_world_load_message"):
		return
	var percent := 100 if total <= 0 else clampi(int(floor(float(applied) * 100.0 / float(total))), 0, 100)
	world.update_smooth_world_load_message("Building world " + str(percent) + "%")


func _resolve_block_type_from_entry(entry: Dictionary) -> String:
	var block_type := _safe_string(entry.get("block_type", entry.get("type", "")), "", 64)
	if block_type != "":
		return block_type
	return ITEM_ATLAS_DB.resolve_item_key(entry.get("item_id", entry.get("id", "")))


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
		if local_world == "":
			world.current_world_name = incoming_world
			return true
		return false

	return false


func is_world_state_apply_current(apply_generation: int) -> bool:
	if world == null:
		return false
	if active_world_state_apply_generation != 0:
		return active_world_state_apply_generation == apply_generation
	return apply_generation == world_state_apply_generation


func _clear_world_state_apply_if_current(apply_generation: int) -> void:
	if active_world_state_apply_generation != apply_generation:
		return
	active_world_state_apply_generation = 0
	if world == null:
		return
	world.applying_network_world_update = false
	_set_world_bulk_load_active(false)


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


func _append_unique_text(values: Array, value, max_length: int = 96, uppercase: bool = false) -> void:
	var clean := _safe_string(value, "", max_length).strip_edges()
	if clean == "":
		return
	if uppercase:
		clean = clean.to_upper()
	if not values.has(clean):
		values.append(clean)


func _get_local_network_player_ids() -> Array:
	var ids := []
	if world == null:
		return ids

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return ids

	if network.has_method("get_live_websocket_player_id"):
		_append_unique_text(ids, network.get_live_websocket_player_id())
	if network.has_method("get_active_game_player_id"):
		_append_unique_text(ids, network.get_active_game_player_id())
	_append_unique_text(ids, network.get("player_id"))
	_append_unique_text(ids, network.get("game_player_id"))
	return ids


func _block_update_targets_local_player_for_instant_death(data: Dictionary) -> bool:
	var local_ids := _get_local_network_player_ids()
	var kill_ids = data.get("kill_player_ids", [])
	if kill_ids is Array:
		for raw_id in kill_ids:
			var clean_id := _safe_string(raw_id, "", 96)
			if clean_id != "" and local_ids.has(clean_id):
				return true

	var single_kill_id := _safe_string(data.get("kill_player_id", ""), "", 96)
	if single_kill_id != "" and local_ids.has(single_kill_id):
		return true

	var local_username := _get_local_session_username()
	if local_username == "":
		return false

	var kill_usernames = data.get("kill_usernames", [])
	if kill_usernames is Array:
		for raw_username in kill_usernames:
			var clean_username := _safe_string(raw_username, "", 64).strip_edges().to_upper()
			if clean_username != "" and clean_username == local_username:
				return true

	var single_username := _safe_string(data.get("kill_username", ""), "", 64).strip_edges().to_upper()
	return single_username != "" and single_username == local_username


func _apply_block_update_instant_death_if_targeted(data: Dictionary, already_targeted: bool = false) -> void:
	if not already_targeted and not _block_update_targets_local_player_for_instant_death(data):
		return
	if world != null and world.has_method("damage_player"):
		world.damage_player(999999)


func _has_network_actor(data: Dictionary) -> bool:
	if _safe_string(data.get("player_id", ""), "", 64).strip_edges() != "":
		return true
	if _safe_string(data.get("username", data.get("account_username", "")), "", 64).strip_edges() != "":
		return true
	return false


func _should_claim_confirmed_world_lock_place(data: Dictionary, layer: String, grid_pos: Vector2i, block_type: String) -> bool:
	if layer != "foreground":
		return false

	var is_lock_block := block_type == "world_lock" or block_type == "super_world_lock"
	if world != null and world.has_method("is_world_lock_block_type"):
		is_lock_block = bool(world.is_world_lock_block_type(block_type))
	if not is_lock_block:
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


func trace_world_block_apply_event(event: String, data: Dictionary = {}) -> void:
	if world == null or world.block_manager == null:
		return
	if world.block_manager.has_method("trace_authoritative_place_event"):
		world.block_manager.trace_authoritative_place_event("apply_" + event, data)


func is_world_block_trace_enabled() -> bool:
	if world == null or world.block_manager == null:
		return false
	if world.block_manager.has_method("is_place_trace_enabled"):
		return bool(world.block_manager.is_place_trace_enabled())
	return false


func get_world_block_trace_cell(layer: String, grid_pos: Vector2i) -> Dictionary:
	if world == null or world.block_manager == null:
		return {}
	if world.block_manager.has_method("get_place_trace_cell_state"):
		return world.block_manager.get_place_trace_cell_state(layer, grid_pos)
	return {}


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


func should_use_entrance_gate_spawn_for_world_state(data: Dictionary) -> bool:
	var reason = str(data.get("world_state_reason", data.get("reason", ""))).strip_edges().to_lower()

	if is_waiting_for_server_world_entry():
		return true

	if world != null and bool(world.get_meta("world_entry_force_entrance_spawn", false)):
		return true

	if _safe_bool(data.get("spawn_at_entrance_gate", data.get("use_entrance_gate_spawn", false)), false):
		return true

	if reason == "door_enter":
		return false

	if _safe_bool(data.get("respawn_player", false), false):
		return true

	return reason == "join_world" or reason == "admin_clear" or reason == "admin_reset" or reason == "admin_reload" or reason == "death_respawn"


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


func notify_world_collision_snapshot_rebuilding(reason: String) -> void:
	if world == null:
		return
	var netfox_manager: Variant = world.get("netfox_real_manager")
	if netfox_manager != null and netfox_manager.has_method("notify_world_collision_changed"):
		netfox_manager.notify_world_collision_changed(reason)
	var custom_manager: Variant = world.get("custom_authoritative_movement_manager")
	if custom_manager != null and custom_manager.has_method("clear_server_collision_baseline"):
		custom_manager.clear_server_collision_baseline(reason)


func notify_world_collision_snapshot_rebuilt(reason: String) -> void:
	if world == null:
		return
	var custom_manager: Variant = world.get("custom_authoritative_movement_manager")
	if custom_manager != null and custom_manager.has_method("refresh_server_collision_baseline"):
		custom_manager.refresh_server_collision_baseline(reason)
	var netfox_manager: Variant = world.get("netfox_real_manager")
	if netfox_manager != null and netfox_manager.has_method("notify_world_collision_changed"):
		netfox_manager.notify_world_collision_changed(reason)


func mark_world_collision_snapshot_changed(reason: String) -> void:
	world_state_apply_generation += 1
	notify_world_collision_snapshot_rebuilt(reason)


func _set_world_bulk_load_active(active: bool, reason: String = "") -> void:
	if world == null:
		return
	world.set_meta("world_bulk_load_in_progress", active)
	world.set_meta("world_bulk_load_reason", reason if active else "")


func _is_world_bulk_load_active() -> bool:
	if world == null:
		return false
	return bool(world.get_meta("world_bulk_load_in_progress", false))


func get_existing_block_type_for_particles(layer: String, grid_pos: Vector2i, fallback: String = "") -> Dictionary:
	var result = {
		"exists": false,
		"block_type": fallback
	}

	if world == null:
		return result

	if layer == "foreground":
		if world.blocks.has(grid_pos):
			result["exists"] = true
			result["block_type"] = str(world.blocks[grid_pos].get("type", fallback))
		return result

	if world.block_manager == null:
		return result

	var background_blocks = world.block_manager.get("background_blocks")
	if background_blocks is Dictionary and background_blocks.has(grid_pos):
		var block_data = background_blocks[grid_pos]
		result["exists"] = true
		if block_data is Dictionary:
			result["block_type"] = str(block_data.get("type", fallback))

	return result


func spawn_network_block_break_particles(layer: String, grid_pos: Vector2i, fallback_block_type: String):
	var block_data = get_existing_block_type_for_particles(layer, grid_pos, fallback_block_type)
	if not bool(block_data.get("exists", false)):
		return
	if world != null and world.has_method("spawn_block_break_particles"):
		world.spawn_block_break_particles(grid_pos, str(block_data.get("block_type", fallback_block_type)), layer)


func spawn_network_block_place_particles(layer: String, grid_pos: Vector2i, fallback_block_type: String):
	var block_data = get_existing_block_type_for_particles(layer, grid_pos, fallback_block_type)
	if not bool(block_data.get("exists", false)):
		return
	if world != null and world.has_method("spawn_block_place_particles"):
		world.spawn_block_place_particles(grid_pos, str(block_data.get("block_type", fallback_block_type)), layer)


func spawn_network_block_hit_particles(layer: String, grid_pos: Vector2i, fallback_block_type: String, source_tool: String = "", source_data: Dictionary = {}):
	var block_data = get_existing_block_type_for_particles(layer, grid_pos, fallback_block_type)
	if not bool(block_data.get("exists", false)):
		return
	if world != null and world.has_method("spawn_block_hit_particles"):
		world.spawn_block_hit_particles(grid_pos, str(block_data.get("block_type", fallback_block_type)), layer)
	if source_tool != "" and world != null:
		if world.has_method("spawn_neptune_trident_network_hit_particles"):
			world.spawn_neptune_trident_network_hit_particles(grid_pos, str(block_data.get("block_type", fallback_block_type)), layer, source_tool, source_data)
		elif world.has_method("spawn_neptune_trident_block_hit_particles"):
			world.spawn_neptune_trident_block_hit_particles(grid_pos, str(block_data.get("block_type", fallback_block_type)), layer, source_tool)


func update_network_block_hit_visual(layer: String, grid_pos: Vector2i, data: Dictionary):
	if world == null:
		return

	var hit_count := _safe_int(data.get("hit_count", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if hit_count <= 0:
		var hit_power := _safe_int(data.get("hit_power", 1), 1, 0, MAX_BLOCK_HIT_METRIC)
		hit_count = int(world.block_hit_progress.get(grid_pos, 0)) + max(1, hit_power)
	var damage_reset_msec: int = _safe_int(data.get("damage_reset_ms", 0), 0, 0, 30000)
	var damage_reset_seconds: float = float(world.BLOCK_DAMAGE_RESET_DELAY)
	if damage_reset_msec > 0:
		damage_reset_seconds = maxf(0.05, float(damage_reset_msec) / 1000.0)

	world.block_hit_progress[grid_pos] = hit_count
	world.block_hit_timers[grid_pos] = damage_reset_seconds

	if world.block_manager == null:
		return

	if layer == "background":
		if world.block_manager.has_method("update_background_block_crack_visual"):
			world.block_manager.update_background_block_crack_visual(grid_pos)
	else:
		if world.block_manager.has_method("update_block_crack_visual"):
			world.block_manager.update_block_crack_visual(grid_pos)


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


func sanitize_mailbox_state(raw_state: Dictionary) -> Dictionary:
	var result := {
		"messages": [],
		"can_empty": _safe_bool(raw_state.get("can_empty", raw_state.get("can_manage", false)), false),
		"can_manage": _safe_bool(raw_state.get("can_manage", raw_state.get("can_empty", false)), false)
	}

	var messages = raw_state.get("messages", [])
	if messages is Array:
		for entry in messages:
			if not (entry is Dictionary):
				continue
			if result["messages"].size() >= 20:
				break
			result["messages"].append({
				"from": _safe_string(entry.get("from", entry.get("sender", "Player")), "Player", 64),
				"message": _safe_string(entry.get("message", entry.get("text", "")), "", MAX_MAILBOX_MESSAGE_LENGTH),
				"sent_at": _safe_string(entry.get("sent_at", entry.get("created_at", "")), "", 64)
			})

	return result


func sanitize_donation_box_state(raw_state: Dictionary) -> Dictionary:
	var result := {
		"owner_username": _safe_string(raw_state.get("owner_username", ""), "", 64),
		"owner_name": _safe_string(raw_state.get("owner_name", raw_state.get("owner_username", "")), "", 64),
		"donations": [],
		"donation_count": _safe_int(raw_state.get("donation_count", 0), 0, 0, 100000),
		"max_donations": _safe_int(raw_state.get("max_donations", 30), 30, 1, 100),
		"has_donations": _safe_bool(raw_state.get("has_donations", false), false),
		"can_manage": _safe_bool(raw_state.get("can_manage", false), false)
	}

	var donations = raw_state.get("donations", [])
	if donations is Array:
		for entry_value in donations:
			if not (entry_value is Dictionary):
				continue
			if result["donations"].size() >= int(result["max_donations"]):
				break
			var entry: Dictionary = entry_value
			result["donations"].append({
				"donation_id": _safe_string(entry.get("donation_id", ""), "", 96),
				"donor_username": _safe_string(entry.get("donor_username", ""), "", 64),
				"donor_name": _safe_string(entry.get("donor_name", entry.get("donor_username", "Player")), "Player", 64),
				"item_id": _safe_string(entry.get("item_id", entry.get("item_type", "")), "", 96),
				"item_type": _safe_string(entry.get("item_type", entry.get("item_id", "")), "", 96),
				"item_category": _safe_string(entry.get("item_category", "block"), "block", 32),
				"amount": _safe_int(entry.get("amount", 1), 1, 1, 1000000000),
				"donated_at": _safe_string(entry.get("donated_at", ""), "", 64)
			})

	if int(result["donation_count"]) <= 0:
		result["donation_count"] = result["donations"].size()
	result["has_donations"] = bool(result["has_donations"]) or int(result["donation_count"]) > 0
	return result


func sanitize_bulletin_board_state(raw_state: Dictionary) -> Dictionary:
	var result := {
		"messages": [],
		"capacity": _safe_int(raw_state.get("capacity", MAX_BULLETIN_BOARD_MESSAGES), MAX_BULLETIN_BOARD_MESSAGES, 1, MAX_BULLETIN_BOARD_MESSAGES),
		"can_clear": _safe_bool(raw_state.get("can_clear", raw_state.get("can_manage", false)), false),
		"can_manage": _safe_bool(raw_state.get("can_manage", raw_state.get("can_clear", false)), false),
		"updated_at": _safe_string(raw_state.get("updated_at", ""), "", 64)
	}

	var messages_value: Variant = raw_state.get("messages", [])
	if messages_value is Array:
		for entry_value in messages_value:
			if not (entry_value is Dictionary):
				continue
			if result["messages"].size() >= MAX_BULLETIN_BOARD_MESSAGES:
				break
			var entry: Dictionary = entry_value
			var player_name := _safe_string(entry.get("player_name", entry.get("username", entry.get("from", "Player"))), "Player", 64)
			var posted_at := _safe_string(entry.get("posted_at", entry.get("created_at", entry.get("sent_at", ""))), "", 64)
			result["messages"].append({
				"player_name": player_name,
				"username": player_name,
				"message": _safe_string(entry.get("message", entry.get("text", "")), "", MAX_BULLETIN_BOARD_MESSAGE_LENGTH),
				"posted_at": posted_at
			})

	return result


func sanitize_cctv_state(raw_state: Dictionary) -> Dictionary:
	var result := {
		"entries": [],
		"entry_count": _safe_int(raw_state.get("entry_count", 0), 0, 0, MAX_CCTV_EVENTS),
		"max_entries": _safe_int(raw_state.get("max_entries", MAX_CCTV_EVENTS), MAX_CCTV_EVENTS, 1, MAX_CCTV_EVENTS),
		"has_entries": _safe_bool(raw_state.get("has_entries", false), false),
		"can_view": _safe_bool(raw_state.get("can_view", false), false),
		"updated_at": _safe_string(raw_state.get("updated_at", ""), "", 64)
	}

	var entries_value: Variant = raw_state.get("entries", [])
	if entries_value is Array:
		for entry_value in entries_value:
			if not (entry_value is Dictionary):
				continue
			if result["entries"].size() >= MAX_CCTV_EVENTS:
				break
			var entry: Dictionary = entry_value
			var event_type := _safe_string(entry.get("event_type", entry.get("event", "enter")), "enter", 24).to_lower()
			if event_type != "leave":
				event_type = "enter"
			result["entries"].append({
				"event_type": event_type,
				"event": event_type,
				"username": _safe_string(entry.get("username", ""), "", 64),
				"player_name": _safe_string(entry.get("player_name", entry.get("display_name", "Player")), "Player", 64),
				"display_name": _safe_string(entry.get("display_name", entry.get("player_name", "Player")), "Player", 64),
				"at": _safe_string(entry.get("at", entry.get("timestamp", "")), "", 64)
			})

	var visible_count := int(result["entries"].size())
	var current_count := int(result.get("entry_count", 0))
	result["entry_count"] = max(current_count, visible_count)
	result["has_entries"] = bool(result["has_entries"]) or int(result["entry_count"]) > 0 or visible_count > 0
	return result


func sanitize_tackle_box_state(raw_state: Dictionary) -> Dictionary:
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var next_harvest_at_ms := _safe_float(raw_state.get("next_harvest_at_ms", raw_state.get("next_ready_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var cooldown_ms := _safe_int(raw_state.get("cooldown_ms", raw_state.get("harvest_cooldown_ms", TACKLE_BOX_DEFAULT_COOLDOWN_MS)), TACKLE_BOX_DEFAULT_COOLDOWN_MS, 0, 2147483647)
	var remaining_ms := int(maxf(0.0, next_harvest_at_ms - now_ms)) if next_harvest_at_ms > 0.0 else 0

	return {
		"next_harvest_at": _safe_string(raw_state.get("next_harvest_at", raw_state.get("ready_at", "")), "", 64),
		"next_harvest_at_ms": next_harvest_at_ms,
		"last_harvested_at": _safe_string(raw_state.get("last_harvested_at", raw_state.get("harvested_at", "")), "", 64),
		"last_harvested_at_ms": _safe_float(raw_state.get("last_harvested_at_ms", raw_state.get("harvested_at_ms", 0.0)), 0.0, 0.0, 1.0e15),
		"cooldown_ms": cooldown_ms,
		"remaining_ms": remaining_ms,
		"ready": remaining_ms <= 0,
		"can_harvest": remaining_ms <= 0
	}


func sanitize_chicken_state(raw_state: Dictionary) -> Dictionary:
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var production_ms := _safe_int(raw_state.get("production_ms", CHICKEN_DEFAULT_PRODUCTION_MS), CHICKEN_DEFAULT_PRODUCTION_MS, 0, 2147483647)
	var hunger_ms := _safe_int(raw_state.get("hunger_ms", CHICKEN_DEFAULT_HUNGER_MS), CHICKEN_DEFAULT_HUNGER_MS, 0, 2147483647)
	var next_harvest_at_ms := _safe_float(raw_state.get("next_harvest_at_ms", raw_state.get("next_ready_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var fed_at_ms := _safe_float(raw_state.get("fed_at_ms", 0.0), 0.0, 0.0, 1.0e15)
	var last_harvested_at_ms := _safe_float(raw_state.get("last_harvested_at_ms", raw_state.get("harvested_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var hungry_since_at_ms := _safe_float(raw_state.get("hungry_since_at_ms", raw_state.get("hungry_since_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var dies_at_ms := _safe_float(raw_state.get("dies_at_ms", raw_state.get("starves_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	if dies_at_ms <= 0.0 and hungry_since_at_ms > 0.0 and hunger_ms > 0:
		dies_at_ms = hungry_since_at_ms + float(hunger_ms)
	elif hungry_since_at_ms <= 0.0 and dies_at_ms > 0.0 and hunger_ms > 0:
		hungry_since_at_ms = maxf(0.0, dies_at_ms - float(hunger_ms))

	var status := _safe_string(raw_state.get("status", raw_state.get("phase", "hungry")), "hungry", 32).strip_edges().to_lower()
	if next_harvest_at_ms > 0.0:
		status = "ready" if now_ms >= next_harvest_at_ms else "producing"
	elif bool(raw_state.get("ready", raw_state.get("can_harvest", false))):
		status = "ready"
	elif status != "ready":
		status = "hungry"

	var remaining_ms := 0
	if status == "producing":
		remaining_ms = int(maxf(0.0, next_harvest_at_ms - now_ms))
	elif status == "hungry" and dies_at_ms > 0.0:
		remaining_ms = int(maxf(0.0, dies_at_ms - now_ms))

	return {
		"status": status,
		"fed_at": _safe_string(raw_state.get("fed_at", ""), "", 64),
		"fed_at_ms": fed_at_ms,
		"next_harvest_at": _safe_string(raw_state.get("next_harvest_at", raw_state.get("ready_at", "")), "", 64),
		"next_harvest_at_ms": next_harvest_at_ms,
		"last_harvested_at": _safe_string(raw_state.get("last_harvested_at", raw_state.get("harvested_at", "")), "", 64),
		"last_harvested_at_ms": last_harvested_at_ms,
		"hungry_since_at": _safe_string(raw_state.get("hungry_since_at", ""), "", 64),
		"hungry_since_at_ms": hungry_since_at_ms,
		"dies_at": _safe_string(raw_state.get("dies_at", raw_state.get("starves_at", "")), "", 64),
		"dies_at_ms": dies_at_ms,
		"production_ms": production_ms,
		"hunger_ms": hunger_ms,
		"remaining_ms": remaining_ms,
		"ready": status == "ready",
		"can_harvest": status == "ready",
		"can_feed": status == "hungry"
	}


func sanitize_cow_state(raw_state: Dictionary) -> Dictionary:
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var production_ms := _safe_int(raw_state.get("production_ms", COW_DEFAULT_PRODUCTION_MS), COW_DEFAULT_PRODUCTION_MS, 0, 2147483647)
	var hunger_ms := _safe_int(raw_state.get("hunger_ms", COW_DEFAULT_HUNGER_MS), COW_DEFAULT_HUNGER_MS, 0, 2147483647)
	var next_harvest_at_ms := _safe_float(raw_state.get("next_harvest_at_ms", raw_state.get("next_ready_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var fed_at_ms := _safe_float(raw_state.get("fed_at_ms", 0.0), 0.0, 0.0, 1.0e15)
	var last_harvested_at_ms := _safe_float(raw_state.get("last_harvested_at_ms", raw_state.get("harvested_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var hungry_since_at_ms := _safe_float(raw_state.get("hungry_since_at_ms", raw_state.get("hungry_since_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var dies_at_ms := _safe_float(raw_state.get("dies_at_ms", raw_state.get("starves_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	if dies_at_ms <= 0.0 and hungry_since_at_ms > 0.0 and hunger_ms > 0:
		dies_at_ms = hungry_since_at_ms + float(hunger_ms)
	elif hungry_since_at_ms <= 0.0 and dies_at_ms > 0.0 and hunger_ms > 0:
		hungry_since_at_ms = maxf(0.0, dies_at_ms - float(hunger_ms))

	var status := _safe_string(raw_state.get("status", raw_state.get("phase", "hungry")), "hungry", 32).strip_edges().to_lower()
	if next_harvest_at_ms > 0.0:
		status = "ready" if now_ms >= next_harvest_at_ms else "producing"
	elif bool(raw_state.get("ready", raw_state.get("can_harvest", false))):
		status = "ready"
	elif status != "ready":
		status = "hungry"

	var remaining_ms := 0
	if status == "producing":
		remaining_ms = int(maxf(0.0, next_harvest_at_ms - now_ms))
	elif status == "hungry" and dies_at_ms > 0.0:
		remaining_ms = int(maxf(0.0, dies_at_ms - now_ms))

	return {
		"status": status,
		"fed_at": _safe_string(raw_state.get("fed_at", ""), "", 64),
		"fed_at_ms": fed_at_ms,
		"next_harvest_at": _safe_string(raw_state.get("next_harvest_at", raw_state.get("ready_at", "")), "", 64),
		"next_harvest_at_ms": next_harvest_at_ms,
		"last_harvested_at": _safe_string(raw_state.get("last_harvested_at", raw_state.get("harvested_at", "")), "", 64),
		"last_harvested_at_ms": last_harvested_at_ms,
		"hungry_since_at": _safe_string(raw_state.get("hungry_since_at", ""), "", 64),
		"hungry_since_at_ms": hungry_since_at_ms,
		"dies_at": _safe_string(raw_state.get("dies_at", raw_state.get("starves_at", "")), "", 64),
		"dies_at_ms": dies_at_ms,
		"production_ms": production_ms,
		"hunger_ms": hunger_ms,
		"remaining_ms": remaining_ms,
		"ready": status == "ready",
		"can_harvest": status == "ready",
		"can_feed": status == "hungry"
	}

func sanitize_duck_state(raw_state: Dictionary) -> Dictionary:
	var now_ms := Time.get_unix_time_from_system() * 1000.0
	var production_ms := _safe_int(raw_state.get("production_ms", DUCK_DEFAULT_PRODUCTION_MS), DUCK_DEFAULT_PRODUCTION_MS, 0, 2147483647)
	var hunger_ms := _safe_int(raw_state.get("hunger_ms", DUCK_DEFAULT_HUNGER_MS), DUCK_DEFAULT_HUNGER_MS, 0, 2147483647)
	var next_harvest_at_ms := _safe_float(raw_state.get("next_harvest_at_ms", raw_state.get("next_ready_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var fed_at_ms := _safe_float(raw_state.get("fed_at_ms", 0.0), 0.0, 0.0, 1.0e15)
	var last_harvested_at_ms := _safe_float(raw_state.get("last_harvested_at_ms", raw_state.get("harvested_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var hungry_since_at_ms := _safe_float(raw_state.get("hungry_since_at_ms", raw_state.get("hungry_since_ms", 0.0)), 0.0, 0.0, 1.0e15)
	var dies_at_ms := _safe_float(raw_state.get("dies_at_ms", raw_state.get("starves_at_ms", 0.0)), 0.0, 0.0, 1.0e15)
	if dies_at_ms <= 0.0 and hungry_since_at_ms > 0.0 and hunger_ms > 0:
		dies_at_ms = hungry_since_at_ms + float(hunger_ms)
	elif hungry_since_at_ms <= 0.0 and dies_at_ms > 0.0 and hunger_ms > 0:
		hungry_since_at_ms = maxf(0.0, dies_at_ms - float(hunger_ms))

	var status := _safe_string(raw_state.get("status", raw_state.get("phase", "hungry")), "hungry", 32).strip_edges().to_lower()
	if next_harvest_at_ms > 0.0:
		status = "ready" if now_ms >= next_harvest_at_ms else "producing"
	elif bool(raw_state.get("ready", raw_state.get("can_harvest", false))):
		status = "ready"
	elif status != "ready":
		status = "hungry"

	var remaining_ms := 0
	if status == "producing":
		remaining_ms = int(maxf(0.0, next_harvest_at_ms - now_ms))
	elif status == "hungry" and dies_at_ms > 0.0:
		remaining_ms = int(maxf(0.0, dies_at_ms - now_ms))

	return {
		"status": status,
		"fed_at": _safe_string(raw_state.get("fed_at", ""), "", 64),
		"fed_at_ms": fed_at_ms,
		"next_harvest_at": _safe_string(raw_state.get("next_harvest_at", raw_state.get("ready_at", "")), "", 64),
		"next_harvest_at_ms": next_harvest_at_ms,
		"last_harvested_at": _safe_string(raw_state.get("last_harvested_at", raw_state.get("harvested_at", "")), "", 64),
		"last_harvested_at_ms": last_harvested_at_ms,
		"hungry_since_at": _safe_string(raw_state.get("hungry_since_at", ""), "", 64),
		"hungry_since_at_ms": hungry_since_at_ms,
		"dies_at": _safe_string(raw_state.get("dies_at", raw_state.get("starves_at", "")), "", 64),
		"dies_at_ms": dies_at_ms,
		"production_ms": production_ms,
		"hunger_ms": hunger_ms,
		"remaining_ms": remaining_ms,
		"ready": status == "ready",
		"can_harvest": status == "ready",
		"can_feed": status == "hungry"
	}


func sanitize_dice_state(raw_state: Dictionary) -> Dictionary:
	var face := _safe_int(raw_state.get("face", raw_state.get("rolled_number", 1)), 1, 1, 6)
	return {
		"face": face,
		"rolled_number": face,
		"rolled_by": _safe_string(raw_state.get("rolled_by", raw_state.get("username", "")), "", 64),
		"rolled_at": _safe_string(raw_state.get("rolled_at", raw_state.get("updated_at", "")), "", 64),
		"roll_id": _safe_string(raw_state.get("roll_id", raw_state.get("source_id", "")), "", 64)
	}


func sanitize_display_state(raw_state: Dictionary) -> Dictionary:
	var result := {
		"slot": {},
		"can_manage": _safe_bool(raw_state.get("can_manage", false), false)
	}

	var slot = raw_state.get("slot", raw_state.get("item", {}))
	if slot is Dictionary:
		var item_id = _safe_string(slot.get("item_id", slot.get("item_type", "")), "", 64)
		var category = _safe_string(slot.get("item_category", "block"), "block", 64)
		if item_id != "":
			result["slot"] = {
				"item_id": item_id,
				"item_type": item_id,
				"item_category": category,
				"amount": 1
			}

	return result


func wait_for_world_state_loading_overlay_to_draw(reason: String = "") -> void:
	if world == null:
		return
	if not world.has_method("is_smooth_world_load_visible"):
		return
	if not bool(world.is_smooth_world_load_visible()):
		return
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return
	for _i in range(WORLD_STATE_OVERLAY_DRAW_FRAMES):
		await tree.process_frame
	debug_action_position_flow("loading overlay draw wait complete", {"reason": reason})


func _refresh_state_grid_visuals_after_reveal(state_value: Variant, method_name: String, apply_generation: int, batch_size: int = 32) -> bool:
	if world == null:
		return false

	var tree: SceneTree = world.get_tree()
	if tree == null:
		return false
	if not (state_value is Dictionary):
		return true
	if not world.has_method(method_name):
		return true

	var processed: int = 0
	for raw_grid_pos in (state_value as Dictionary).keys():
		if not is_world_state_apply_current(apply_generation):
			return false
		if raw_grid_pos is Vector2i:
			world.call(method_name, raw_grid_pos)
			processed += 1
			if processed >= batch_size:
				processed = 0
				await tree.process_frame

	return is_world_state_apply_current(apply_generation)


func _refresh_world_state_visuals_after_reveal(apply_generation: int) -> void:
	if world == null:
		return

	var tree: SceneTree = world.get_tree()
	if tree == null:
		return

	for _i in range(3):
		await tree.process_frame
		if not is_world_state_apply_current(apply_generation):
			return

	if not await _refresh_state_grid_visuals_after_reveal(world.get("vending_states"), "update_vending_machine_preview", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("mailbox_states"), "update_mailbox_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("donation_box_states"), "update_donation_box_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("tackle_box_states"), "update_tackle_box_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("chicken_states"), "update_chicken_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("cow_states"), "update_cow_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("duck_states"), "update_duck_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("dice_states"), "update_dice_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("anti_punch_states"), "update_anti_punch_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("anti_talk_states"), "update_anti_talk_visual", apply_generation):
		return
	if not await _refresh_state_grid_visuals_after_reveal(world.get("anti_gravity_states"), "update_anti_gravity_visual", apply_generation):
		return

	if is_world_state_apply_current(apply_generation) and world.has_method("update_checkpoint_visual"):
		var checkpoint_grid: Variant = world.get("active_checkpoint_grid")
		if checkpoint_grid is Vector2i:
			world.update_checkpoint_visual(checkpoint_grid)


func apply_network_world_state(data: Dictionary):
	if not _is_current_world_message(data):
		return
	var incoming_world := _get_message_world_name(data)
	if incoming_world == "":
		incoming_world = _safe_world_name(world.current_world_name)
	var incoming_block_revision := _safe_int(data.get("block_revision", 0), 0, 0)
	var same_revision_world := block_revision_world != "" and block_revision_world == incoming_world
	if same_revision_world and not is_waiting_for_server_world_entry() and latest_block_revision > 0:
		if incoming_block_revision <= 0 or incoming_block_revision < latest_block_revision:
			debug_action_position_flow("ignored stale world block snapshot", {
				"world": incoming_world,
				"incoming_block_revision": incoming_block_revision,
				"latest_block_revision": latest_block_revision,
				"world_state_reason": str(data.get("world_state_reason", ""))
			})
			return
	_reset_block_revision_tracking(incoming_world, incoming_block_revision)

	world_state_apply_generation += 1
	var apply_generation: int = world_state_apply_generation
	active_world_state_apply_generation = apply_generation
	var entries_since_yield: int = 0
	var apply_started_usec: int = Time.get_ticks_usec()
	var first_built_frame_recorded: bool = false
	world_state_apply_batch_started_usec = apply_started_usec
	# Claim the full-state apply before the first await. NetworkManager pauses
	# packet dispatch while this flag is set, so another snapshot cannot begin a
	# competing clear/rebuild during the loading-overlay draw wait.
	world.applying_network_world_update = true
	_set_world_bulk_load_active(true, "applying_network_world_state")
	_profile_world_entry_stage("client_world_apply_start", {
		"block_revision": incoming_block_revision,
		"world_revision": _safe_int(data.get("world_revision", 0), 0, 0)
	})

	debug_action_position_flow("world_state apply start", {
		"respawn_player": data.get("respawn_player", null),
		"force_respawn": data.get("force_respawn", null),
		"world_state_reason": str(data.get("world_state_reason", "")),
		"waiting_for_entry": is_waiting_for_server_world_entry()
	})

	if world.safe_ui != null and world.safe_ui.has_method("close_safe"):
		world.safe_ui.close_safe()

	if world.donation_box_ui != null and world.donation_box_ui.has_method("close_donation_box"):
		world.donation_box_ui.close_donation_box()

	if world.mailbox_ui != null and world.mailbox_ui.has_method("close_mailbox"):
		world.mailbox_ui.close_mailbox()

	if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("close_bulletin_board"):
		world.bulletin_board_ui.close_bulletin_board()

	if world.display_ui != null and world.display_ui.has_method("close_display"):
		world.display_ui.close_display()

	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("close_fish_monger"):
		world.fish_monger_ui.close_fish_monger()

	if world.cctv_ui != null and world.cctv_ui.has_method("close_cctv"):
		world.cctv_ui.close_cctv()

	if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("close_oil_refinery"):
		world.oil_refinery_ui.close_oil_refinery()

	if world.battery_charger_ui != null and world.battery_charger_ui.has_method("close_battery_charger"):
		world.battery_charger_ui.close_battery_charger()

	if "generator_ui" in world and world.generator_ui != null and world.generator_ui.has_method("close_generator"):
		world.generator_ui.close_generator()

	if not world.is_smooth_world_load_visible():
		world.begin_smooth_world_load(world.current_world_name, false)

	world.update_smooth_world_load_message("Building " + str(world.current_world_name).to_upper() + "...")
	await wait_for_world_state_loading_overlay_to_draw("world_state_before_clear_and_build")
	if not is_world_state_apply_current(apply_generation) or not _is_current_world_message(data):
		_clear_world_state_apply_if_current(apply_generation)
		return

	notify_world_collision_snapshot_rebuilding("world-state-rebuild-start")
	world.vending_states.clear()
	world.safe_states.clear()
	world.donation_box_states.clear()
	world.mailbox_states.clear()
	world.bulletin_board_states.clear()
	world.display_states.clear()
	world.tackle_box_states.clear()
	world.chicken_states.clear()
	world.cow_states.clear()
	world.duck_states.clear()
	world.dice_states.clear()
	world.oil_refinery_states.clear()
	world.battery_charger_states.clear()
	world.anti_punch_states.clear()
	world.anti_talk_states.clear()
	world.anti_gravity_states.clear()
	world.theme_machine_states.clear()
	if world.has_method("reset_world_background_theme"):
		world.reset_world_background_theme()
	world.cctv_state = {}
	world.active_checkpoint_grid = world.INVALID_GRID_POS
	world.active_checkpoint_world = ""
	world.clear_world()
	_profile_world_entry_stage("client_old_world_cleared")

	var raw_foreground = data.get("foreground", [])
	var raw_background = data.get("background", [])
	var foreground: Array = _normalize_world_layer_entries(raw_foreground)
	var background: Array = _normalize_world_layer_entries(raw_background)
	# Compact dictionary snapshots contain one authoritative value per grid cell,
	# so they can be safely reordered for progressive construction. Legacy arrays
	# retain their original ordering in case they contain duplicate coordinates.
	if raw_foreground is Dictionary:
		foreground = _prioritize_world_layer_entries_for_spawn(foreground, data)
	if raw_background is Dictionary:
		background = _prioritize_world_layer_entries_for_spawn(background, data)
	var build_entry_total: int = foreground.size() + background.size()
	var build_entry_applied: int = 0
	_update_world_build_progress(0, build_entry_total)
	_profile_world_entry_stage("client_world_payload_normalized", {
		"foreground_count": foreground.size(),
		"background_count": background.size()
	})
	var has_explicit_foreground: bool = not foreground.is_empty()
	var has_explicit_background: bool = not background.is_empty()
	var server_cleared_world: bool = bool(data.get("cleared", data.get("world_cleared", data.get("clear_generated", false))))

	# World-entry performance fix:
	# If the server sent actual foreground blocks, build only that payload.
	# A background-only payload should not suppress generated foreground terrain.
	if not server_cleared_world and not has_explicit_foreground:
		if world.has_method("update_smooth_world_load_message"):
			world.update_smooth_world_load_message("Generating " + str(world.current_world_name).to_upper() + "...")
		world.generate_world()
		await world.get_tree().process_frame
		if not is_world_state_apply_current(apply_generation):
			_clear_world_state_apply_if_current(apply_generation)
			return
		if has_explicit_background and world.block_manager != null and world.block_manager.has_method("clear_background_blocks"):
			world.block_manager.clear_background_blocks()

	if foreground is Array:
		var processed = 0
		for entry in foreground:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				var foreground_block_type := _resolve_block_type_from_entry(entry)
				var foreground_block_update := {
					"world": world.current_world_name,
					"_from_world_state": true,
					"action": "place",
					"layer": "foreground",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": foreground_block_type,
					"item_id": _safe_int(entry.get("item_id", ITEM_ATLAS_DB.get_item_id_for_key(foreground_block_type)), 0, 0, MAX_WORLD_COORD),
					"block_revision": _safe_int(entry.get("block_revision", 0), 0, 0),
					"placement_request_id": _safe_string(entry.get("placement_request_id", ""), "", 96),
					"entrance_locked": _safe_bool(entry.get("entrance_locked", false), false),
					"sign_text": _safe_string(entry.get("sign_text", ""), "", MAX_SIGN_TEXT_LENGTH),
					"toggle_on": _safe_bool(entry.get("toggle_on", false), false),
					"door_id": _safe_string(entry.get("door_id", ""), "", MAX_DOOR_ID_LENGTH),
					"door_destination": _safe_string(entry.get("door_destination", entry.get("destination", "")), "", MAX_DOOR_DESTINATION_LENGTH),
					"door_target_world": _safe_string(entry.get("door_target_world", ""), "", 64),
					"door_target_id": _safe_string(entry.get("door_target_id", ""), "", MAX_DOOR_ID_LENGTH)
				}
				if entry.has("door_name") or entry.has("name"):
					foreground_block_update["door_name"] = _safe_string(entry.get("door_name", entry.get("name", "")), "", MAX_DOOR_NAME_LENGTH)
				apply_network_block_update(foreground_block_update)
				processed += 1
				build_entry_applied += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					_update_world_build_progress(build_entry_applied, build_entry_total)
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return
					if not first_built_frame_recorded:
						first_built_frame_recorded = true
						_profile_world_entry_stage("client_first_built_frame", {
							"applied_entries": build_entry_applied,
							"total_entries": build_entry_total,
							"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
						})

	# Small worlds may fit inside one frame-budget batch. Yield once here so the
	# spawn-prioritized foreground can be presented while the rest of the
	# authoritative snapshot continues under the loading overlay.
	if not first_built_frame_recorded:
		_update_world_build_progress(build_entry_applied, build_entry_total)
		await world.get_tree().process_frame
		if not is_world_state_apply_current(apply_generation):
			_clear_world_state_apply_if_current(apply_generation)
			return
		first_built_frame_recorded = true
		_profile_world_entry_stage("client_first_built_frame", {
			"applied_entries": build_entry_applied,
			"total_entries": build_entry_total,
			"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
		})

	_profile_world_entry_stage("client_foreground_built", {
		"count": foreground.size(),
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})

	if background is Array:
		var processed = 0
		for entry in background:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				var background_block_type := _resolve_block_type_from_entry(entry)
				apply_network_block_update({
					"world": world.current_world_name,
					"_from_world_state": true,
					"action": "place",
					"layer": "background",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": background_block_type,
					"item_id": _safe_int(entry.get("item_id", ITEM_ATLAS_DB.get_item_id_for_key(background_block_type)), 0, 0, MAX_WORLD_COORD),
					"block_revision": _safe_int(entry.get("block_revision", 0), 0, 0),
					"placement_request_id": _safe_string(entry.get("placement_request_id", ""), "", 96)
				})
				processed += 1
				build_entry_applied += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					_update_world_build_progress(build_entry_applied, build_entry_total)
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	_update_world_build_progress(build_entry_applied, build_entry_total)
	_profile_world_entry_stage("client_background_built", {
		"count": background.size(),
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})

	var removed_foreground = data.get("removed_foreground", [])
	if removed_foreground is Array:
		var processed = 0
		for entry in removed_foreground:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"_from_world_state": true,
					"action": "break",
					"layer": "foreground",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64),
					"block_revision": _safe_int(entry.get("block_revision", 0), 0, 0),
					"mutation_request_id": _safe_string(entry.get("mutation_request_id", ""), "", 96)
				})
				processed += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	var removed_background = data.get("removed_background", [])
	if removed_background is Array:
		var processed = 0
		for entry in removed_background:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				apply_network_block_update({
					"world": world.current_world_name,
					"_from_world_state": true,
					"action": "break",
					"layer": "background",
					"x": _safe_int(entry.get("x", 0), 0, 0, MAX_WORLD_COORD),
					"y": _safe_int(entry.get("y", 0), 0, 0, MAX_WORLD_COORD),
					"block_type": _safe_string(entry.get("block_type", ""), "", 64),
					"block_revision": _safe_int(entry.get("block_revision", 0), 0, 0),
					"mutation_request_id": _safe_string(entry.get("mutation_request_id", ""), "", 96)
				})
				processed += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	if world.block_manager != null and world.block_manager.has_method("reconcile_authoritative_place_predictions_after_snapshot"):
		world.block_manager.reconcile_authoritative_place_predictions_after_snapshot(foreground, background)

	var seeds = data.get("seeds", [])
	if seeds is Array:
		var processed = 0
		for entry in seeds:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
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
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	if world.has_method("apply_network_wire_visibility_refresh"):
		world.apply_network_wire_visibility_refresh({
			"world": world.current_world_name,
			"visible": _safe_bool(data.get("electrical_layer_visible", false), false),
			"electrical_layer": data.get("electrical_layer", data.get("electrical_tiles", [])),
			"generator_links": data.get("generator_links", []),
			"oil_refinery_links": data.get("oil_refinery_links", []),
			"battery_charger_links": data.get("battery_charger_links", []),
			"pole_links": data.get("pole_links", [])
		})

	var generator_states = data.get("generator_states", [])
	if generator_states is Array:
		if world.block_manager != null and world.block_manager.has_method("clear_transformer_power_visuals"):
			world.block_manager.clear_transformer_power_visuals()
		for entry in generator_states:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if entry is Dictionary and world.has_method("apply_network_generator_data_update"):
				world.apply_network_generator_data_update(entry)

	var interactions = data.get("interactions", [])
	if interactions is Array:
		var processed = 0
		for entry in interactions:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				var interaction_entry: Dictionary = entry.duplicate(false)
				interaction_entry["_from_world_state"] = true
				apply_network_world_interaction_update(interaction_entry)
				processed += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	var world_lock_state = data.get("world_lock", {})
	if world_lock_state is Dictionary:
		apply_network_world_interaction_update({
			"world": world.current_world_name,
			"action": "world_lock_state",
			"state": world_lock_state
		})

	var area_locks_state = data.get("area_locks", [])
	if area_locks_state is Array:
		apply_network_world_interaction_update({
			"world": world.current_world_name,
			"action": "area_lock_state",
			"state": {"area_locks": area_locks_state}
		})

	var cctv_state_value: Variant = data.get("cctv_state", {})
	if cctv_state_value is Dictionary:
		world.cctv_state = sanitize_cctv_state(cctv_state_value)

	var drops = data.get("drops", data.get("item_drops", []))
	if drops is Array:
		if world.drop_manager != null and world.drop_manager.has_method("trace_drop_pickup_event"):
			world.drop_manager.trace_drop_pickup_event("world_state_drops_clear", {
				"type": "world_state",
				"world": _get_message_world_name(data),
				"world_state_reason": str(data.get("world_state_reason", "")),
				"drop_count": drops.size()
			}, {})
		if world.drop_manager != null and world.drop_manager.has_method("clear"):
			world.drop_manager.clear()

		var drop_world = _get_message_world_name(data)
		if drop_world == "":
			drop_world = _safe_world_name(world.current_world_name)

		var processed = 0
		for entry in drops:
			if not is_world_state_apply_current(apply_generation):
				_clear_world_state_apply_if_current(apply_generation)
				return
			if processed >= MAX_WORLD_NETWORK_ENTRIES_PER_SECTION:
				break
			if entry is Dictionary:
				var drop_payload = {
					"world": drop_world,
					"drop_id": _safe_string(entry.get("drop_id", entry.get("id", "")), "", MAX_DROP_ID_LENGTH),
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
				drop_payload["_from_world_state"] = true
				if world.drop_manager != null and world.drop_manager.has_method("trace_drop_pickup_event"):
					world.drop_manager.trace_drop_pickup_event("world_state_drop_apply", drop_payload, {})
				world.apply_network_item_drop_create(drop_payload)
				processed += 1
				entries_since_yield += 1
				if _should_yield_world_state_apply(entries_since_yield):
					entries_since_yield = 0
					await world.get_tree().process_frame
					if not is_world_state_apply_current(apply_generation):
						_clear_world_state_apply_if_current(apply_generation)
						return

	world.ensure_entrance_gate()

	var force_player_position := _safe_bool(data.get("force_player_position", false), false)
	var use_entrance_gate_spawn := should_use_entrance_gate_spawn_for_world_state(data)
	var is_entry_spawn_forced := is_waiting_for_server_world_entry() or bool(world.get_meta("world_entry_force_entrance_spawn", false))
	var used_entrance_gate_snap: bool = false
	if should_respawn_for_world_state(data):
		if use_entrance_gate_spawn and world.has_method("force_place_player_at_current_entrance_gate"):
			debug_action_position_flow("world_state placing respawn player at entrance", get_world_state_debug_summary(data))
			used_entrance_gate_snap = bool(world.force_place_player_at_current_entrance_gate(true))
		else:
			debug_action_position_flow("world_state respawning player", get_world_state_debug_summary(data))
			world.respawn_player()
	elif is_entry_spawn_forced and (not force_player_position or use_entrance_gate_spawn):
		debug_action_position_flow("world_state placing entry player at entrance", get_world_state_debug_summary(data))
		if world.has_method("force_place_player_at_current_entrance_gate"):
			used_entrance_gate_snap = bool(world.force_place_player_at_current_entrance_gate(true))
		else:
			world.place_player_at_entrance_immediate()
	elif bool(data.get("respawn_player", false)):
		debug_action_position_flow("world_state skipped respawn outside entry/reload", get_world_state_debug_summary(data))

	if force_player_position and not use_entrance_gate_spawn and not is_entry_spawn_forced and world.has_method("apply_server_door_spawn"):
		world.apply_server_door_spawn(data)
	if is_entry_spawn_forced and not used_entrance_gate_snap and world.has_method("force_place_player_at_current_entrance_gate"):
		# Entry paths must never leave the player on stale/remote coordinates if the
		# initial placement branch did not succeed.
		debug_action_position_flow("world_state fallback entry spawn", get_world_state_debug_summary(data))
		world.force_place_player_at_current_entrance_gate(true)
	_profile_world_entry_stage("client_world_objects_applied", {
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})

	# Bulk loading skipped per-block neighbor variant refreshes. Fix stacked dirt,
	# water depth, tree/vine top-middle-bottom, and horizontal platform joins before
	# the loading overlay is allowed to fade out.
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Entering world...")
	_profile_world_entry_stage("client_world_finalize_start")
	if world.block_manager != null and world.block_manager.has_method("finalize_world_load_block_variants"):
		await world.block_manager.finalize_world_load_block_variants()
	elif world.block_manager != null and world.block_manager.has_method("refresh_all_foreground_block_textures"):
		world.block_manager.refresh_all_foreground_block_textures()
		await world.get_tree().process_frame
	if not is_world_state_apply_current(apply_generation) or not _is_current_world_message(data):
		_clear_world_state_apply_if_current(apply_generation)
		return
	_profile_world_entry_stage("client_world_finalize_complete", {
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})
	# finalize_world_load_block_variants() ends after a process frame and a forced
	# active-chunk refresh, so this is the first frame with the authoritative
	# foreground/background visuals reconciled. The loading overlay can still be
	# visible; controls are measured separately when it is actually dismissed.
	_profile_world_entry_stage("client_full_built_frame", {
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})

	notify_world_collision_snapshot_rebuilt("world-state-rebuild-complete")
	_profile_world_entry_stage("client_collision_ready", {
		"elapsed_ms": snappedf(float(Time.get_ticks_usec() - apply_started_usec) / 1000.0, 0.001)
	})
	_clear_world_state_apply_if_current(apply_generation)
	var requires_server_ready: bool = _safe_bool(data.get("world_entry_requires_ready", false), false)
	if requires_server_ready:
		var network: Node = world.get_node_or_null("/root/NetworkManager")
		var ready_sent := false
		if network != null and network.has_method("notify_world_entry_spawn_ready"):
			ready_sent = bool(network.notify_world_entry_spawn_ready(data))
		if not ready_sent:
			if world.has_method("update_smooth_world_load_message"):
				world.update_smooth_world_load_message("Confirming world state...")
			if network != null and network.has_method("request_current_world_entry_snapshot_restart"):
				network.request_current_world_entry_snapshot_restart("client_ready_validation_failed")
	else:
		if world.save_manager != null and world.save_manager.has_method("finish_world_entry_after_load"):
			world.save_manager.finish_world_entry_after_load(false, true, true)
		else:
			world.finish_smooth_world_load()
	call_deferred("_refresh_world_state_visuals_after_reveal", apply_generation)

	debug_action_position_flow("world_state apply end", {
		"respawn_player": data.get("respawn_player", null),
		"world_state_reason": str(data.get("world_state_reason", ""))
	})


func apply_network_block_reconcile(data: Dictionary) -> void:
	if not _is_current_world_message(data):
		return

	var outcome := "unmatched"
	if world != null and world.block_manager != null and world.block_manager.has_method("handle_authoritative_place_reconcile"):
		outcome = str(world.block_manager.handle_authoritative_place_reconcile(data))
	if outcome == "pending" or outcome == "mismatched":
		return

	var incoming_world := _get_message_world_name(data)
	if incoming_world == "":
		incoming_world = _safe_world_name(world.current_world_name)
	var global_revision := _safe_int(data.get("block_revision", 0), 0, 0)
	if block_revision_world == "" or block_revision_world != incoming_world:
		_reset_block_revision_tracking(incoming_world, global_revision)
	else:
		latest_block_revision = maxi(latest_block_revision, global_revision)

	var layer := _safe_string(data.get("layer", "foreground"), "foreground", 16).to_lower()
	if layer != "background":
		layer = "foreground"
	var grid_pos := _safe_grid_position(data.get("x", 0), data.get("y", 0))
	var cell_revision := _safe_int(data.get("cell_revision", 0), 0, 0)
	if outcome == "confirmed":
		_record_block_revision(layer, grid_pos, cell_revision)
		return

	var requested_block_type := _safe_string(data.get("requested_block_type", ""), "", 64)
	var authoritative_block_type := _safe_string(data.get("authoritative_block_type", ""), "", 64)
	if authoritative_block_type == "":
		authoritative_block_type = ITEM_ATLAS_DB.resolve_item_key(data.get("authoritative_item_id", ""))
	var authoritative_present := _safe_bool(data.get("authoritative_present", false), false)
	var update := {
		"world": incoming_world,
		"_from_reconcile": true,
		"action": "place" if authoritative_present else "break",
		"layer": layer,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"block_type": authoritative_block_type if authoritative_present else requested_block_type,
		"item_id": _safe_int(data.get("authoritative_item_id", ITEM_ATLAS_DB.get_item_id_for_key(authoritative_block_type)), 0, 0, MAX_WORLD_COORD),
		"block_revision": cell_revision,
		"request_id": _safe_string(data.get("authoritative_placement_request_id", data.get("request_id", "")), "", 96),
	}
	apply_network_block_update(update)
	latest_block_revision = maxi(latest_block_revision, global_revision)


func apply_network_block_update(data: Dictionary):
	if not _is_current_world_message(data):
		return

	var old_flag = world.applying_network_world_update
	world.applying_network_world_update = true

	var action = _safe_string(data.get("action", ""), "", 16).to_lower()
	if action != "hit" and action != "break" and action != "place":
		world.applying_network_world_update = old_flag
		return

	var layer = _safe_string(data.get("layer", "foreground"), "", 16).to_lower()
	if layer != "foreground" and layer != "background":
		world.applying_network_world_update = old_flag
		return

	var grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
	var incoming_world := _get_message_world_name(data)
	if incoming_world == "":
		incoming_world = _safe_world_name(world.current_world_name)
	if block_revision_world == "" or block_revision_world != incoming_world:
		_reset_block_revision_tracking(incoming_world, 0)
	var block_revision := _safe_int(data.get("block_revision", 0), 0, 0)
	var is_from_world_state := _safe_bool(data.get("_from_world_state", false), false)
	var is_from_world_event := _safe_bool(data.get("_from_world_event", false), false)
	var is_from_reconcile := _safe_bool(data.get("_from_reconcile", false), false)
	if _should_ignore_stale_block_update(layer, grid_pos, block_revision, is_from_world_state):
		if action == "place" and world != null and world.block_manager != null and world.block_manager.has_method("confirm_predicted_authoritative_place"):
			world.block_manager.confirm_predicted_authoritative_place(data)
		world.applying_network_world_update = old_flag
		return
	var block_type = _safe_string(data.get("block_type", ""), "", 64)
	if block_type == "":
		block_type = ITEM_ATLAS_DB.resolve_item_key(data.get("item_id", ""))
	var atlas_item_id := _safe_int(data.get("item_id", ITEM_ATLAS_DB.get_item_id_for_key(block_type)), 0, 0, MAX_WORLD_COORD)
	var source_tool = _safe_string(data.get("source_tool", ""), "", 64)
	var existing_collision_type := _get_foreground_collision_block_type(grid_pos)
	var trace_enabled := is_world_block_trace_enabled()
	var trace_cell_before := {}
	if trace_enabled:
		trace_cell_before = get_world_block_trace_cell(layer, grid_pos)
	var existing_door_name_for_update := ""
	if layer == "foreground" and world != null and world.blocks.has(grid_pos):
		var existing_block_data = world.blocks.get(grid_pos, {})
		if existing_block_data is Dictionary:
			existing_door_name_for_update = _safe_string(existing_block_data.get("door_name", existing_block_data.get("name", "")), "", MAX_DOOR_NAME_LENGTH)
	var should_claim_world_lock_place := false
	var should_emit_confirmed_particles := true
	var confirmation_was_predicted := false
	var confirmed_place_already_applied := false
	var is_bulk_network_update := is_from_world_state or is_from_world_event or is_from_reconcile
	if is_bulk_network_update:
		should_emit_confirmed_particles = false
	var is_local_confirmed_update := _is_local_player_confirmed_update(data)
	# The authoritative placement echo always carries the exact request ID, but
	# older/public payloads do not consistently include an actor username. Exact
	# membership in this client's pending map is sufficient to identify its ack.
	if action == "place" and world != null and world.block_manager != null and world.block_manager.has_method("confirm_predicted_authoritative_place"):
		confirmation_was_predicted = bool(world.block_manager.confirm_predicted_authoritative_place(data))
		if confirmation_was_predicted:
			is_local_confirmed_update = true
	if confirmation_was_predicted:
		confirmed_place_already_applied = action == "place" and block_type != "" and get_existing_network_block_type(layer, grid_pos).strip_edges().to_lower() == block_type.strip_edges().to_lower()
		should_emit_confirmed_particles = false
	elif is_local_confirmed_update and world != null and world.has_method("should_use_server_authoritative_world_actions"):
		should_emit_confirmed_particles = bool(world.should_use_server_authoritative_world_actions())
	if trace_enabled:
		trace_world_block_apply_event("network_block_update_start", {
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"item_id": atlas_item_id,
			"request_id": _safe_string(data.get("request_id", data.get("action_id", "")), "", 96),
			"block_revision": block_revision,
			"from_world_state": is_from_world_state,
			"from_world_event": is_from_world_event,
			"from_reconcile": is_from_reconcile,
			"local_confirmed_update": is_local_confirmed_update,
			"confirmation_was_predicted": confirmation_was_predicted,
			"confirmed_place_already_applied": confirmed_place_already_applied,
			"should_emit_confirmed_particles": should_emit_confirmed_particles,
			"cell_before": trace_cell_before,
			"payload": data
		})

	if action == "hit":
		update_network_block_hit_visual(layer, grid_pos, data)
		if not is_local_confirmed_update:
			spawn_network_block_hit_particles(layer, grid_pos, block_type, source_tool, data)
			play_confirmed_block_punch_sound(grid_pos)

	elif action == "break":
		debug_action_position_flow("apply_network_block_update break start", {
			"layer": layer,
			"x": grid_pos.x,
			"y": grid_pos.y,
			"block_type": block_type,
			"item_id": atlas_item_id
		})
		if not is_bulk_network_update and not is_local_confirmed_update and _has_network_actor(data):
			spawn_network_block_hit_particles(layer, grid_pos, block_type, "", data)
		if should_emit_confirmed_particles:
			spawn_network_block_break_particles(layer, grid_pos, block_type)
		if not is_bulk_network_update and not is_local_confirmed_update and source_tool != "" and world != null:
			if world.has_method("spawn_neptune_trident_network_hit_particles"):
				world.spawn_neptune_trident_network_hit_particles(grid_pos, block_type, layer, source_tool, data)
			elif world.has_method("spawn_neptune_trident_block_hit_particles"):
				world.spawn_neptune_trident_block_hit_particles(grid_pos, block_type, layer, source_tool)
		if not is_bulk_network_update and not is_local_confirmed_update:
			play_confirmed_block_break_sound(grid_pos)
		if layer == "background":
			if world.block_manager != null and world.block_manager.has_method("remove_background_block_without_drop"):
				world.block_manager.remove_background_block_without_drop(grid_pos)
		else:
			world.vending_states.erase(grid_pos)
			world.safe_states.erase(grid_pos)
			world.donation_box_states.erase(grid_pos)
			world.mailbox_states.erase(grid_pos)
			world.bulletin_board_states.erase(grid_pos)
			world.display_states.erase(grid_pos)
			world.tackle_box_states.erase(grid_pos)
			world.chicken_states.erase(grid_pos)
			world.cow_states.erase(grid_pos)
			world.duck_states.erase(grid_pos)
			world.dice_states.erase(grid_pos)
			world.oil_refinery_states.erase(grid_pos)
			world.battery_charger_states.erase(grid_pos)
			world.anti_gravity_states.erase(grid_pos)
			world.theme_machine_states.erase(grid_pos)
			if world.active_checkpoint_grid == grid_pos:
				world.active_checkpoint_grid = world.INVALID_GRID_POS
				world.active_checkpoint_world = ""
			if world.block_manager != null and world.block_manager.has_method("remove_block_without_drop"):
				world.block_manager.remove_block_without_drop(grid_pos)
		debug_action_position_flow("apply_network_block_update break end", {
			"layer": layer,
			"x": grid_pos.x,
			"y": grid_pos.y,
			"block_type": block_type,
			"item_id": atlas_item_id
		})

	elif action == "place" and block_type != "":
		if layer == "background":
			if not confirmed_place_already_applied and world.block_manager != null and world.block_manager.has_method("replace_background_block_without_drop"):
				world.block_manager.replace_background_block_without_drop(grid_pos, block_type)
			if should_emit_confirmed_particles:
				spawn_network_block_place_particles(layer, grid_pos, block_type)
		else:
			if not confirmed_place_already_applied and world.block_manager != null:
				if is_from_world_event and world.block_manager.has_method("replace_event_block_without_drop"):
					world.block_manager.replace_event_block_without_drop(grid_pos, block_type)
				elif world.block_manager.has_method("replace_block_without_drop"):
					world.block_manager.replace_block_without_drop(grid_pos, block_type)
			if not is_bulk_network_update and not confirmed_place_already_applied and world.block_manager != null and world.block_manager.has_method("initialize_tackle_box_cooldown_on_place"):
				world.block_manager.initialize_tackle_box_cooldown_on_place(grid_pos, block_type)
			if not is_bulk_network_update and not confirmed_place_already_applied and world.block_manager != null and world.block_manager.has_method("initialize_chicken_hunger_on_place"):
				world.block_manager.initialize_chicken_hunger_on_place(grid_pos, block_type)
			if not is_bulk_network_update and not confirmed_place_already_applied and world.block_manager != null and world.block_manager.has_method("initialize_cow_hunger_on_place"):
				world.block_manager.initialize_cow_hunger_on_place(grid_pos, block_type)
			if not is_bulk_network_update and not confirmed_place_already_applied and world.block_manager != null and world.block_manager.has_method("initialize_duck_hunger_on_place"):
				world.block_manager.initialize_duck_hunger_on_place(grid_pos, block_type)
			if not is_bulk_network_update and world.block_manager != null and world.block_manager.has_method("reset_dice_visual_on_place"):
				world.block_manager.reset_dice_visual_on_place(grid_pos, block_type)
			should_claim_world_lock_place = _should_claim_confirmed_world_lock_place(data, layer, grid_pos, block_type)
			if should_emit_confirmed_particles:
				spawn_network_block_place_particles(layer, grid_pos, block_type)

		if should_emit_confirmed_particles:
			play_confirmed_block_place_sound(grid_pos)

		if world.blocks.has(grid_pos):
			var placed_block_type = str(world.blocks[grid_pos].get("type", ""))
			if data.has("entrance_locked") and world.is_wooden_entrance_block(placed_block_type):
				world.set_wooden_entrance_locked(grid_pos, _safe_bool(data.get("entrance_locked", false), false))

			if data.has("sign_text") and world.is_sign_block(placed_block_type):
				world.blocks[grid_pos]["sign_text"] = _safe_string(data.get("sign_text", ""), "", MAX_SIGN_TEXT_LENGTH)
				world.update_sign_text_visual(grid_pos)

			if data.has("toggle_on") and is_toggle_block_type(placed_block_type):
				apply_toggle_block_state(grid_pos, _safe_bool(data.get("toggle_on", false), false))

			if data.has("door_id") or data.has("door_name") or data.has("name") or data.has("door_destination") or data.has("door_target_world") or data.has("door_target_id") or data.has("door_password_configured"):
				if world.has_method("apply_door_state_to_block"):
					var incoming_door_name := existing_door_name_for_update
					if data.has("door_name") or data.has("name"):
						incoming_door_name = _safe_string(data.get("door_name", data.get("name", "")), "", MAX_DOOR_NAME_LENGTH)
					world.apply_door_state_to_block(
						grid_pos,
						_safe_string(data.get("door_id", ""), "", MAX_DOOR_ID_LENGTH),
						_safe_string(data.get("door_destination", data.get("destination", "")), "", MAX_DOOR_DESTINATION_LENGTH),
						_safe_bool(data.get("entrance_locked", false), false),
						_safe_string(data.get("door_target_world", ""), "", 64),
						_safe_string(data.get("door_target_id", ""), "", MAX_DOOR_ID_LENGTH),
						"",
						_safe_bool(data.get("door_password_configured", false), false),
						false,
						incoming_door_name
					)

			if world.vending_states.has(grid_pos) or world.is_vending_machine_block_type(block_type):
				world.update_vending_machine_preview(grid_pos)

	var apply_instant_death := _block_update_targets_local_player_for_instant_death(data)
	world.applying_network_world_update = old_flag
	if apply_instant_death:
		_apply_block_update_instant_death_if_targeted(data, true)
	if not is_bulk_network_update and not _is_world_bulk_load_active() and world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()

	if should_claim_world_lock_place:
		world.on_world_lock_block_placed(grid_pos, block_type)
	if action == "break" or action == "place":
		_record_block_revision(layer, grid_pos, block_revision)

	if trace_enabled:
		trace_world_block_apply_event("network_block_update_done", {
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"item_id": atlas_item_id,
			"request_id": _safe_string(data.get("request_id", data.get("action_id", "")), "", 96),
			"block_revision": block_revision,
			"from_world_state": is_from_world_state,
			"from_world_event": is_from_world_event,
			"from_reconcile": is_from_reconcile,
			"local_confirmed_update": is_local_confirmed_update,
			"confirmation_was_predicted": confirmation_was_predicted,
			"confirmed_place_already_applied": confirmed_place_already_applied,
			"should_emit_confirmed_particles": should_emit_confirmed_particles,
			"cell_before": trace_cell_before,
			"cell_after": get_world_block_trace_cell(layer, grid_pos),
			"payload": data
		})

	if MovementMode.is_netfox_real() and not is_from_world_event and (action == "break" or action == "place"):
		if not old_flag and _did_network_block_update_change_collision(action, layer, grid_pos, block_type, existing_collision_type):
			world_state_apply_generation += 1
		var netfox_real_manager = world.get("netfox_real_manager") if world != null else null
		if netfox_real_manager != null and netfox_real_manager.has_method("notify_world_collision_changed"):
			netfox_real_manager.notify_world_collision_changed("block-" + action + "-" + layer)


func _get_foreground_collision_block_type(grid_pos: Vector2i) -> String:
	if world == null or not world.blocks.has(grid_pos):
		return ""

	var block_data = world.blocks.get(grid_pos, {})
	var block_type := ""
	if block_data is Dictionary:
		block_type = _safe_string(block_data.get("type", ""), "", 64)
	else:
		block_type = _safe_string(block_data, "", 64)

	if _is_collision_block_type(block_type):
		return block_type
	return ""


func _did_network_block_update_change_collision(
	action: String,
	layer: String,
	_grid_pos: Vector2i,
	block_type: String,
	existing_collision_type: String
) -> bool:
	if layer != "foreground":
		return false

	var next_collision_type := ""
	if action == "place":
		next_collision_type = block_type if _is_collision_block_type(block_type) else ""
	elif action == "break":
		next_collision_type = ""
	else:
		return false

	return existing_collision_type != next_collision_type


func _is_collision_block_type(block_type: String) -> bool:
	var clean_type = _safe_string(block_type, "", 64)
	if clean_type == "":
		return false

	var block_manager = world.block_manager if world != null else null
	if block_manager != null:
		if block_manager.has_method("is_background_block_type") and bool(block_manager.is_background_block_type(clean_type)):
			return false
		if block_manager.has_method("is_non_collideable_block") and bool(block_manager.is_non_collideable_block(clean_type)):
			return false

	return true


func get_grid_sound_position(grid_pos: Vector2i) -> Vector2:
	if world != null and world.has_method("get_block_center_world_position"):
		return world.get_block_center_world_position(grid_pos)
	var block_size := 32.0
	if world != null:
		var world_block_size = world.get("BLOCK_SIZE")
		if world_block_size is int or world_block_size is float:
			block_size = float(world_block_size)
	return Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)



func get_existing_network_block_type(layer: String, grid_pos: Vector2i) -> String:
	if world == null:
		return ""
	var clean_layer := layer.strip_edges().to_lower()
	if clean_layer == "background":
		if world.block_manager != null:
			var background_value = world.block_manager.get("background_blocks")
			if background_value is Dictionary and background_value.has(grid_pos):
				var background_block = background_value.get(grid_pos, {})
				if background_block is Dictionary:
					return _safe_string(background_block.get("type", ""), "", 64)
		return ""
	if world.blocks.has(grid_pos):
		var block_value = world.blocks.get(grid_pos, {})
		if block_value is Dictionary:
			return _safe_string(block_value.get("type", ""), "", 64)
	return ""

func play_confirmed_block_place_sound(grid_pos: Vector2i):
	if world != null and world.has_method("play_sound_place"):
		world.play_sound_place(get_grid_sound_position(grid_pos))


func play_confirmed_block_punch_sound(grid_pos: Vector2i):
	if world != null and world.has_method("play_sound_punch"):
		world.play_sound_punch(get_grid_sound_position(grid_pos))


func play_confirmed_block_break_sound(grid_pos: Vector2i):
	if world != null and world.has_method("play_sound_break"):
		world.play_sound_break(get_grid_sound_position(grid_pos))
	elif world != null and world.has_method("play_sound_punch"):
		world.play_sound_punch(get_grid_sound_position(grid_pos))


func apply_network_world_interaction_update(data: Dictionary):
	if not _is_current_world_message(data):
		return

	var old_flag = world.applying_network_world_update
	world.applying_network_world_update = true

	var action = _safe_string(data.get("action", ""), "", 40).to_lower()
	var is_local_confirmed_update := _is_local_player_confirmed_update(data)

	if action == "wooden_entrance_state":
		var entrance_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(entrance_grid_pos) and world.is_wooden_entrance_block(str(world.blocks[entrance_grid_pos].get("type", ""))):
			world.set_wooden_entrance_locked(entrance_grid_pos, _safe_bool(data.get("locked", false), false))

	elif action == "door_state":
		var door_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(door_grid_pos) and world.has_method("apply_door_state_to_block"):
			var existing_locked = _safe_bool(world.blocks[door_grid_pos].get("entrance_locked", false), false)
			var existing_door_name = _safe_string(world.blocks[door_grid_pos].get("door_name", world.blocks[door_grid_pos].get("name", "")), "", MAX_DOOR_NAME_LENGTH)
			var incoming_door_name = existing_door_name
			if data.has("door_name") or data.has("name"):
				incoming_door_name = _safe_string(data.get("door_name", data.get("name", "")), "", MAX_DOOR_NAME_LENGTH)
			world.apply_door_state_to_block(
				door_grid_pos,
				_safe_string(data.get("door_id", ""), "", MAX_DOOR_ID_LENGTH),
				_safe_string(data.get("destination", data.get("door_destination", "")), "", MAX_DOOR_DESTINATION_LENGTH),
				_safe_bool(data.get("locked", existing_locked), existing_locked),
				_safe_string(data.get("target_world", data.get("door_target_world", "")), "", 64),
				_safe_string(data.get("target_door_id", data.get("door_target_id", "")), "", MAX_DOOR_ID_LENGTH),
				"",
				_safe_bool(data.get("password_configured", data.get("door_password_configured", false)), false),
				false,
				incoming_door_name
			)

	elif action == "sign_text":
		var sign_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(sign_grid_pos) and world.is_sign_block(str(world.blocks[sign_grid_pos].get("type", ""))):
			world.blocks[sign_grid_pos]["sign_text"] = _safe_string(data.get("text", ""), "", MAX_SIGN_TEXT_LENGTH)
			world.update_sign_text_visual(sign_grid_pos)

	elif action == "ceiling_lamp_state":
		var lamp_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		apply_toggle_block_state(lamp_grid_pos, _safe_bool(data.get("on", false), false))

	elif action == "world_lock_state":
		var state = data.get("state", {})
		if state is Dictionary and world.world_lock_manager != null and world.world_lock_manager.has_method("load_save_data"):
			world.world_lock_manager.load_save_data(state)
			if world.world_lock_manager.has_method("reconcile_world_lock_state_with_blocks"):
				world.world_lock_manager.reconcile_world_lock_state_with_blocks()

	elif action == "area_lock_state":
		var state = data.get("state", {})
		if state is Dictionary and world.world_lock_manager != null and world.world_lock_manager.has_method("load_area_locks_save_data"):
			world.world_lock_manager.load_area_locks_save_data(state.get("area_locks", []))

	elif action == "vend_state":
		var vend_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var state_payload = normalize_vending_state_payload(data, vend_grid_pos)
		world.vending_states[vend_grid_pos] = state_payload
		world.update_vending_machine_preview(vend_grid_pos)
		if world.vending_ui != null and world.vending_ui.has_method("handle_vend_state"):
			world.vending_ui.handle_vend_state(state_payload)

	elif action == "vend_purchase_sound":
		var vend_sound_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.blocks.has(vend_sound_grid_pos) and world.is_vending_machine_block_type(str(world.blocks[vend_sound_grid_pos].get("type", ""))):
			if world.has_method("play_sound_vend_purchase"):
				world.play_sound_vend_purchase(get_grid_sound_position(vend_sound_grid_pos))

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

	elif action == "donation_box_state":
		var donation_grid_pos := _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var raw_donation_state: Dictionary = data.get("state", data) if data.get("state", data) is Dictionary else {}
		var donation_state := sanitize_donation_box_state(raw_donation_state)
		world.donation_box_states[donation_grid_pos] = {"state": donation_state}
		if world.has_method("update_donation_box_visual"):
			world.update_donation_box_visual(donation_grid_pos)
		if world.donation_box_ui != null and world.donation_box_ui.has_method("handle_donation_box_state"):
			var ui_payload := donation_state.duplicate(true)
			ui_payload["x"] = donation_grid_pos.x
			ui_payload["y"] = donation_grid_pos.y
			world.donation_box_ui.handle_donation_box_state(ui_payload)

	elif action == "donation_box_visual_state":
		var donation_visual_grid_pos := _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var existing_payload = world.donation_box_states.get(donation_visual_grid_pos, {})
		var existing_state: Dictionary = {}
		if existing_payload is Dictionary:
			existing_state = existing_payload.get("state", existing_payload).duplicate(true)
		existing_state["donation_count"] = _safe_int(data.get("donation_count", 0), 0, 0, 100000)
		existing_state["has_donations"] = _safe_bool(data.get("has_donations", false), false)
		world.donation_box_states[donation_visual_grid_pos] = {"state": existing_state}
		if world.has_method("update_donation_box_visual"):
			world.update_donation_box_visual(donation_visual_grid_pos)
		if world.donation_box_ui != null and world.donation_box_ui.has_method("handle_donation_box_visual_state"):
			world.donation_box_ui.handle_donation_box_visual_state(data)

	elif action == "mailbox_state":
		var mailbox_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var mailbox_state_payload := {}
		if data.has("state"):
			var raw_mailbox_state = data.get("state", null)
			if raw_mailbox_state is Dictionary:
				mailbox_state_payload["state"] = sanitize_mailbox_state(raw_mailbox_state)
			else:
				mailbox_state_payload["state"] = sanitize_mailbox_state({})
		else:
			mailbox_state_payload["state"] = sanitize_mailbox_state(data)
		world.mailbox_states[mailbox_grid_pos] = mailbox_state_payload
		if world.has_method("update_mailbox_visual"):
			world.update_mailbox_visual(mailbox_grid_pos)
		if world.mailbox_ui != null and world.mailbox_ui.has_method("handle_mailbox_state"):
			world.mailbox_ui.handle_mailbox_state(data)

	elif action == "bulletin_board_state":
		var board_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var board_state_payload := {}
		if data.has("state"):
			var raw_board_state: Variant = data.get("state", null)
			if raw_board_state is Dictionary:
				board_state_payload["state"] = sanitize_bulletin_board_state(raw_board_state)
			else:
				board_state_payload["state"] = sanitize_bulletin_board_state({})
		else:
			board_state_payload["state"] = sanitize_bulletin_board_state(data)
		world.bulletin_board_states[board_grid_pos] = board_state_payload
		if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("handle_bulletin_board_state"):
			world.bulletin_board_ui.handle_bulletin_board_state(data)

	elif action == "tackle_box_state":
		var tackle_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var tackle_state_payload := {}
		if data.has("state"):
			var raw_tackle_state = data.get("state", null)
			if raw_tackle_state is Dictionary:
				tackle_state_payload["state"] = sanitize_tackle_box_state(raw_tackle_state)
			else:
				tackle_state_payload["state"] = sanitize_tackle_box_state({})
		else:
			tackle_state_payload["state"] = sanitize_tackle_box_state(data)
		world.tackle_box_states[tackle_grid_pos] = tackle_state_payload
		if world.has_method("update_tackle_box_visual"):
			world.update_tackle_box_visual(tackle_grid_pos)
		if is_local_confirmed_update and str(data.get("operation", "")).to_lower() == "harvest":
			var tackle_block_type := str(data.get("block_type", "")).strip_edges().to_lower()
			var water_well_harvest := false
			var atm_machine_harvest := false
			if world.has_method("is_water_well_block_type"):
				water_well_harvest = bool(world.is_water_well_block_type(tackle_block_type))
				if not water_well_harvest and world.blocks.has(tackle_grid_pos):
					var local_tackle_block_data = world.blocks.get(tackle_grid_pos, {})
					if local_tackle_block_data is Dictionary:
						var local_tackle_block_type := str(local_tackle_block_data.get("type", "")).strip_edges().to_lower()
						water_well_harvest = bool(world.is_water_well_block_type(local_tackle_block_type))
			if world.has_method("is_atm_machine_block_type"):
				atm_machine_harvest = bool(world.is_atm_machine_block_type(tackle_block_type))
				if not atm_machine_harvest and world.blocks.has(tackle_grid_pos):
					var local_atm_block_data = world.blocks.get(tackle_grid_pos, {})
					if local_atm_block_data is Dictionary:
						var local_atm_block_type := str(local_atm_block_data.get("type", "")).strip_edges().to_lower()
						atm_machine_harvest = bool(world.is_atm_machine_block_type(local_atm_block_type))
			if not water_well_harvest and not atm_machine_harvest:
				world.show_notification("Tackle Box harvested.")

	elif action == "chicken_state":
		var chicken_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var chicken_state_payload := {}
		if data.has("state"):
			var raw_chicken_state = data.get("state", null)
			if raw_chicken_state is Dictionary:
				chicken_state_payload["state"] = sanitize_chicken_state(raw_chicken_state)
			else:
				chicken_state_payload["state"] = sanitize_chicken_state({})
		else:
			chicken_state_payload["state"] = sanitize_chicken_state(data)
		world.chicken_states[chicken_grid_pos] = chicken_state_payload
		if world.has_method("update_chicken_visual"):
			world.update_chicken_visual(chicken_grid_pos)

	elif action == "cow_state":
		var cow_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var cow_state_payload := {}
		if data.has("state"):
			var raw_cow_state = data.get("state", null)
			if raw_cow_state is Dictionary:
				cow_state_payload["state"] = sanitize_cow_state(raw_cow_state)
			else:
				cow_state_payload["state"] = sanitize_cow_state({})
		else:
			cow_state_payload["state"] = sanitize_cow_state(data)
		world.cow_states[cow_grid_pos] = cow_state_payload
		if world.has_method("update_cow_visual"):
			world.update_cow_visual(cow_grid_pos)

	elif action == "duck_state":
		var duck_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var duck_state_payload := {}
		if data.has("state"):
			var raw_duck_state = data.get("state", null)
			if raw_duck_state is Dictionary:
				duck_state_payload["state"] = sanitize_duck_state(raw_duck_state)
			else:
				duck_state_payload["state"] = sanitize_duck_state({})
		else:
			duck_state_payload["state"] = sanitize_duck_state(data)
		world.duck_states[duck_grid_pos] = duck_state_payload
		if world.has_method("update_duck_visual"):
			world.update_duck_visual(duck_grid_pos)

	elif action == "dice_roll":
		var dice_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var is_from_world_state := _safe_bool(data.get("_from_world_state", false), false)
		var dice_state_payload := {}
		if data.has("state"):
			var raw_dice_state = data.get("state", null)
			if raw_dice_state is Dictionary:
				dice_state_payload["state"] = sanitize_dice_state(raw_dice_state)
			else:
				dice_state_payload["state"] = sanitize_dice_state({})
		else:
			dice_state_payload["state"] = sanitize_dice_state(data)
		world.dice_states[dice_grid_pos] = dice_state_payload
		var dice_state: Dictionary = dice_state_payload.get("state", {})
		if is_from_world_state:
			if world.has_method("update_dice_visual"):
				world.update_dice_visual(dice_grid_pos)
		elif world.has_method("play_dice_roll_animation"):
			world.play_dice_roll_animation(
				dice_grid_pos,
				_safe_int(dice_state.get("face", 1), 1, 1, 6),
				_safe_string(dice_state.get("roll_id", data.get("roll_id", "")), "", 64)
			)
		elif world.has_method("update_dice_visual"):
			world.update_dice_visual(dice_grid_pos)
		if not is_from_world_state and not is_local_confirmed_update and world.has_method("play_sound_punch"):
			world.play_sound_punch(get_grid_sound_position(dice_grid_pos))

	elif action == "checkpoint_activate":
		var checkpoint_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.has_method("apply_checkpoint_activation"):
			world.apply_checkpoint_activation(checkpoint_grid_pos, false, false)

	elif action == "anti_punch_state":
		var anti_punch_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var anti_enabled := _safe_bool(data.get("enabled", false), false)
		if anti_enabled:
			world.anti_punch_states[anti_punch_grid_pos] = {"state": {"enabled": true}}
		else:
			world.anti_punch_states.erase(anti_punch_grid_pos)
		if world.has_method("update_anti_punch_visual"):
			world.update_anti_punch_visual(anti_punch_grid_pos)

	elif action == "anti_talk_state":
		var anti_talk_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var anti_talk_enabled := _safe_bool(data.get("enabled", false), false)
		if anti_talk_enabled:
			world.anti_talk_states[anti_talk_grid_pos] = {"state": {"enabled": true}}
		else:
			world.anti_talk_states.erase(anti_talk_grid_pos)
		if world.has_method("update_anti_talk_visual"):
			world.update_anti_talk_visual(anti_talk_grid_pos)

	elif action == "anti_gravity_state":
		var anti_gravity_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var anti_gravity_enabled := _safe_bool(data.get("enabled", false), false)
		if anti_gravity_enabled:
			world.anti_gravity_states[anti_gravity_grid_pos] = {"state": {"enabled": true}}
		else:
			world.anti_gravity_states.erase(anti_gravity_grid_pos)
		if world.has_method("update_anti_gravity_visual"):
			world.update_anti_gravity_visual(anti_gravity_grid_pos)

	elif action == "theme_machine_state":
		var theme_machine_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var theme_machine_enabled := _safe_bool(data.get("enabled", false), false)
		var theme_name := _safe_string(data.get("theme", "night"), "night", 32).to_lower()
		if world.has_method("apply_theme_machine_state"):
			world.apply_theme_machine_state(theme_machine_grid_pos, theme_machine_enabled, false, false, theme_name)

	elif action == "oil_refinery_state":
		var refinery_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if not (world.oil_refinery_states is Dictionary):
			world.oil_refinery_states = {}
		var refinery_state: Dictionary = {}
		if world.oil_refinery_states.has(refinery_grid_pos) and world.oil_refinery_states[refinery_grid_pos] is Dictionary:
			refinery_state = world.oil_refinery_states[refinery_grid_pos].duplicate(true)
		for key in data.keys():
			if key == "type" or key == "world" or key == "action":
				continue
			refinery_state[key] = data[key]
		world.oil_refinery_states[refinery_grid_pos] = refinery_state
		var refinery_ui_open := false
		if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("is_oil_refinery_open"):
			refinery_ui_open = bool(world.oil_refinery_ui.is_oil_refinery_open())
		if refinery_ui_open and world.oil_refinery_ui.has_method("handle_oil_refinery_state"):
			world.oil_refinery_ui.handle_oil_refinery_state(data)
		elif world.has_method("refresh_oil_refinery_visual"):
			world.refresh_oil_refinery_visual(refinery_grid_pos)
		if world.electricity_manager != null and world.electricity_manager.has_method("apply_oil_refinery_link_for_refinery"):
			var pole_grid := Vector2i(999999, 999999)
			if _safe_bool(data.get("linked_pole", false), false) and data.has("linked_pole_x") and data.has("linked_pole_y"):
				pole_grid = _safe_grid_position(data.get("linked_pole_x", 0), data.get("linked_pole_y", 0))
			world.electricity_manager.apply_oil_refinery_link_for_refinery(refinery_grid_pos, pole_grid)

	elif action == "battery_charger_state":
		var charger_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if not (world.battery_charger_states is Dictionary):
			world.battery_charger_states = {}
		var charger_state: Dictionary = {}
		if world.battery_charger_states.has(charger_grid_pos) and world.battery_charger_states[charger_grid_pos] is Dictionary:
			charger_state = world.battery_charger_states[charger_grid_pos].duplicate(true)
		for key in data.keys():
			if key == "type" or key == "world" or key == "action":
				continue
			charger_state[key] = data[key]
		world.battery_charger_states[charger_grid_pos] = charger_state
		var charger_ui_open := false
		if world.battery_charger_ui != null and world.battery_charger_ui.has_method("is_battery_charger_open"):
			charger_ui_open = bool(world.battery_charger_ui.is_battery_charger_open())
		if charger_ui_open and world.battery_charger_ui.has_method("handle_battery_charger_state"):
			world.battery_charger_ui.handle_battery_charger_state(data)
		elif world.has_method("refresh_battery_charger_visual"):
			world.refresh_battery_charger_visual(charger_grid_pos)
		if world.electricity_manager != null and world.electricity_manager.has_method("apply_battery_charger_link_for_charger"):
			var charger_pole_grid := Vector2i(999999, 999999)
			if _safe_bool(data.get("linked_pole", false), false) and data.has("linked_pole_x") and data.has("linked_pole_y"):
				charger_pole_grid = _safe_grid_position(data.get("linked_pole_x", 0), data.get("linked_pole_y", 0))
			world.electricity_manager.apply_battery_charger_link_for_charger(charger_grid_pos, charger_pole_grid)

	elif action == "cctv_state":
		var raw_cctv_state: Variant = data.get("state", data)
		if raw_cctv_state is Dictionary:
			world.cctv_state = sanitize_cctv_state(raw_cctv_state)
		else:
			world.cctv_state = sanitize_cctv_state({})
		if world.has_method("refresh_all_cctv_visuals"):
			world.refresh_all_cctv_visuals()
		if world.cctv_ui != null and world.cctv_ui.has_method("handle_cctv_state"):
			world.cctv_ui.handle_cctv_state(data)

	elif action == "display_state":
		var display_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var display_state_payload := {}
		if data.has("state"):
			var raw_display_state = data.get("state", null)
			if raw_display_state is Dictionary:
				display_state_payload["state"] = sanitize_display_state(raw_display_state)
			else:
				display_state_payload["state"] = sanitize_display_state({})
		else:
			display_state_payload["state"] = sanitize_display_state(data)
		world.display_states[display_grid_pos] = display_state_payload
		if world.has_method("update_display_visual"):
			world.update_display_visual(display_grid_pos)
		if world.display_ui != null and world.display_ui.has_method("handle_display_state"):
			world.display_ui.handle_display_state(data)

	elif action == "springboard_animation":
		var springboard_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		if world.has_method("play_springboard_block_animation"):
			world.play_springboard_block_animation(springboard_grid_pos)
		if not is_local_confirmed_update and world.has_method("play_sound_jump"):
			world.play_sound_jump(get_grid_sound_position(springboard_grid_pos))

	elif action == "entrance_pass":
		var entrance_pass_grid_pos = _safe_grid_position(data.get("x", 0), data.get("y", 0))
		var walk_direction = -1 if _safe_int(data.get("walk_direction", 1), 1, -1, 1) < 0 else 1
		if world.blocks.has(entrance_pass_grid_pos) and world.is_wooden_entrance_block(str(world.blocks[entrance_pass_grid_pos].get("type", ""))):
			if world.has_method("play_entrance_pass_animation"):
				world.play_entrance_pass_animation(entrance_pass_grid_pos, walk_direction)
			if world.has_method("play_sound_entrance"):
				world.play_sound_entrance(get_grid_sound_position(entrance_pass_grid_pos))

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
		play_confirmed_block_place_sound(grid_pos)
	elif action == "remove":
		if world.seed_system != null and world.seed_system.has_method("remove_seed_at"):
			var should_play_tree_break_sound := false
			if world.seed_system.has_method("get_seed_break_particle_data"):
				var particle_data = world.seed_system.get_seed_break_particle_data(grid_pos)
				if bool(particle_data.get("mature", false)) and world.has_method("spawn_tree_break_particles"):
					world.spawn_tree_break_particles(grid_pos, str(particle_data.get("block_type", "")))
					should_play_tree_break_sound = true
			world.seed_system.remove_seed_at(grid_pos)
			if should_play_tree_break_sound:
				play_confirmed_block_break_sound(grid_pos)

	world.applying_network_world_update = old_flag
