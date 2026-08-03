extends Node

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")
const ColourCycleModulation = preload("res://Scripts/colour_cycle_modulation.gd")
const DROP_PICKUP_SCAN_INTERVAL := 1.0 / 30.0
const DROP_MAX_PICKUPS_PER_SCAN := 80
const DROP_PICKUP_REQUEST_TIMEOUT := 3.0
const DROP_PICKUP_REQUEST_MATCH_WINDOW_SECONDS := 2.0
const DROP_PICKUP_VACUUM_DURATION := 1.20
const DROP_PICKUP_VACUUM_FINISH_DURATION := 0.18
const DROP_PICKUP_VACUUM_ARC_HEIGHT := 24.0
const DROP_PICKUP_VACUUM_TARGET_OFFSET := Vector2(0.0, -12.0)
const DROP_PICKUP_VACUUM_START_POP_SCALE := 1.12
const DROP_PICKUP_VACUUM_SPIN_DEGREES := 170.0
const DROP_PICKUP_REQUEST_ALPHA := 0.48
const DROP_PICKUP_REQUEST_SCALE := Vector2(0.36, 0.36)
const DROP_MAX_SERVER_PICKUPS_IN_FLIGHT := 4
const DROP_MAX_SERVER_PICKUP_QUEUE := 256
# Keep client pickup pressure below the backend's 12/sec pickup guard.
const DROP_PICKUP_SEND_RATE_PER_SECOND := 8.0
const DROP_PICKUP_SEND_BURST := 4.0
const DROP_PICKUP_BUSY_RETRY_COOLDOWN := 0.12
const DROP_PICKUP_RATE_LIMIT_RETRY_COOLDOWN := 0.35
const DROP_PICKUP_UNREACHABLE_RETRY_COOLDOWN := 0.25
const MAX_DROP_ID_LENGTH := 96
const MAX_ITEM_ID_LENGTH := 64
const MAX_ITEM_CATEGORY_LENGTH := 64
const MAX_DROP_STACK_SIZE := 400
const MAX_REQUEST_ID_LENGTH := 64
const MAX_USERNAME_LENGTH := 64
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_DROP_PICKUP_DELAY_SECONDS := 120.0
const MAX_WORLD_COORD := 1000000.0
const DROP_PICKUP_REJECT_RETRY_COOLDOWN := 1.5
const DROP_PICKUP_FULL_STACK_RETRY_COOLDOWN := 0.75
const DROP_MAX_BULK_PICKUP_IDS := 64
const DEBUG_ACTION_POSITION_FLOW := false
const DEBUG_DROP_PICKUP_FLOW := false
const DEBUG_DROP_PICKUP_AUDIT := false
const DROP_PICKUP_TRACE_ARG := "--debug-drop-pickup"
const DROP_PICKUP_TRACE_MAX_LINES := 160
const USE_LEGACY_CLIENT_LOCAL_DROPS := false
const DROP_COUNT_LABEL_SIZE := Vector2(38, 16)
const DROP_COUNT_WORLD_OFFSET := Vector2(0, 9)
const DROP_COUNT_BASE_FONT_SIZE := 15
const DROP_COUNT_BASE_OUTLINE_SIZE := 3
const DROP_WORLD_Z_INDEX := 40
const DROP_COUNT_WORLD_Z_INDEX := DROP_WORLD_Z_INDEX + 1
const DROP_VISUAL_ROOT_NAME := "DropVisuals"
const GEM_DROP_VISUAL_STACK_SIZE := 40
const GEM_DROP_SMALL_MAX := 5
const GEM_DROP_MEDIUM_MAX := 15
const GEM_DROP_LARGE_MAX := 25
const GEM_DROP_VARIANT_TEXTURE_PATHS := {
	"small": "res://Assets/currency/small_gem.png",
	"medium": "res://Assets/currency/medium_gem.png",
	"large": "res://Assets/currency/large_gem.png",
	"huge": "res://Assets/currency/huge_gem.png"
}
const GEM_DROP_BASE_OFFSETS := [
	Vector2.ZERO,
	Vector2(-7, -4),
	Vector2(7, -4),
	Vector2(-8, 6),
	Vector2(8, 6),
	Vector2(0, -9),
	Vector2(-12, 1),
	Vector2(12, 1),
	Vector2(-4, 11),
	Vector2(4, 11),
	Vector2(-13, -10),
	Vector2(13, -10)
]
const STACK_FULL_NOTIFICATION_COOLDOWN := 1.2
const PICKUP_RESULT_UNKNOWN_AMOUNT := -1
const SEED_DROP_PREVIEW_NODE_NAME := "SeedPreviewSprite"
const DROP_TEXTURE_SHADOW_NAME := "TextureShadow"
const DROP_TEXTURE_SHADOW_OFFSET := Vector2(1.5, 1.5)
const DROP_TEXTURE_SHADOW_ALPHA := 0.38
const DROP_VISIBILITY_MARGIN_SCREEN_PX := 224.0
const PICKUP_UI_REFRESH_BATCH_MS := 80
# Visual reconciliation guard: after the server confirms a pickup/remove,
# ignore late create/update packets for the same unique drop id.
const DROP_REMOVED_TOMBSTONE_MS := 12000
# Bulk pickup performance guards. These keep mass pickup from creating hundreds
# of tweens/UI refreshes/server queue scans in one frame.
const DROP_MAX_PICKUP_FINISH_VISUALS_PER_FRAME := 4
const DROP_MAX_PICKUP_VACUUM_UPDATES_PER_FRAME := 8
const DROP_BETTER_CANDIDATE_CHECK_MAX_CANDIDATES := 24
const DROP_QUEUE_PROCESS_INTERVAL_MS := 8
const DROP_BULK_PICKUP_UI_ALWAYS_BATCH := true
const DROP_PICKUP_DIAGNOSTIC_PRINT_INTERVAL_MS := 1000
var world = null
var local_drop_sequence := 0
var drops_by_id := {}
var drops_by_cell := {}
var drop_pickup_scan_elapsed := 0.0
var drop_pickup_send_tokens := DROP_PICKUP_SEND_BURST
var drop_pickup_token_refill_ms := 0
var stack_full_notification_cooldown := 0.0
var drop_pickup_busy_until_ms := 0
var applying_server_drop_payload := false
var visible_drop_nodes := 0
var pending_pickup_ui_refreshes: Dictionary = {}
var pending_pickup_ui_flush_at_ms := 0
var drop_pickup_finish_visuals_this_frame := 0
var drop_pickup_vacuum_updates_this_frame := 0
var drop_queued_pickup_next_process_ms := 0
var drop_pickup_debug_scan_counts: Dictionary = {}
var drop_pickup_debug_nearest: Dictionary = {}
var drop_pickup_debug_last_print_ms := 0
var drop_pickup_debug_last_print_key := ""
var recently_removed_drop_ids: Dictionary = {}
var drop_pickup_trace_enabled := false
var drop_pickup_trace_lines_left := 0
var drop_pickup_trace_sequence := 0
var gem_drop_variant_textures: Dictionary = {}


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][DropManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func debug_drop_pickup_flow(message: String, drop_data: Dictionary = {}, extra_data: Dictionary = {}) -> void:
	if not DEBUG_DROP_PICKUP_FLOW:
		return

	var world_name_text = str(world.current_world_name) if world != null else ""
	var drop_summary := {}
	if drop_data is Dictionary and not drop_data.is_empty():
		var summary_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var summary_is_weight: bool = _is_fish_drop_category(summary_category)
		drop_summary = {
			"drop_id": _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH),
			"ids": _get_drop_stack_ids(drop_data).duplicate(),
			"amount": _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), summary_is_weight),
			"requested": bool(drop_data.get("pickup_requested", false)),
			"in_progress": bool(drop_data.get("pickup_in_progress", false)),
			"requested_drop_id": _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		}
	print("[PM_DROP_PICKUP] " + message + " world=" + world_name_text + " drop=" + str(drop_summary) + " data=" + str(extra_data))


func configure_drop_pickup_trace() -> void:
	var launch_enabled := false
	if MovementMode != null and MovementMode.has_method("has_launch_arg"):
		launch_enabled = bool(MovementMode.has_launch_arg(DROP_PICKUP_TRACE_ARG))
	var env_value := OS.get_environment("PIXELMANIA_DROP_PICKUP_TRACE").strip_edges().to_lower()
	var env_enabled := env_value == "1" or env_value == "true" or env_value == "yes" or env_value == "on"
	drop_pickup_trace_enabled = launch_enabled or env_enabled
	drop_pickup_trace_lines_left = DROP_PICKUP_TRACE_MAX_LINES if drop_pickup_trace_enabled else 0
	drop_pickup_trace_sequence = 0
	if drop_pickup_trace_enabled:
		print("[PM_DROP_PICKUP_TRACE] enabled max_lines=" + str(DROP_PICKUP_TRACE_MAX_LINES))


func is_drop_pickup_trace_enabled() -> bool:
	return drop_pickup_trace_enabled and drop_pickup_trace_lines_left > 0


func trace_drop_pickup_event(event: String, data: Dictionary = {}, drop_data: Dictionary = {}) -> void:
	if not is_drop_pickup_trace_enabled():
		return

	drop_pickup_trace_sequence += 1
	drop_pickup_trace_lines_left -= 1
	var clean_drop_id := ""
	if data is Dictionary:
		clean_drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "" and drop_data is Dictionary:
		clean_drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)

	var local_drop: Dictionary = get_drop_by_id(clean_drop_id) if clean_drop_id != "" else {}
	if local_drop.is_empty() and drop_data is Dictionary and not drop_data.is_empty():
		local_drop = drop_data

	var local_category := _safe_string(local_drop.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH) if local_drop is Dictionary else ""
	var local_is_weight := _is_fish_drop_category(local_category)
	var trace_payload := {
		"seq": drop_pickup_trace_sequence,
		"event": _safe_string(event, "unknown", 64),
		"type": _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH) if data is Dictionary else "",
		"action": _safe_string(data.get("action", ""), "", MAX_ITEM_ID_LENGTH) if data is Dictionary else "",
		"world": _safe_string(data.get("world", ""), "", 96) if data is Dictionary else "",
		"drop_id": clean_drop_id,
		"drop_ids": data.get("drop_ids", []) if data is Dictionary else [],
		"removed_drop_ids": data.get("removed_drop_ids", []) if data is Dictionary else [],
		"item_type": _safe_string(data.get("item_type", data.get("item_id", "")), "", MAX_ITEM_ID_LENGTH) if data is Dictionary else "",
		"amount": data.get("amount", null) if data is Dictionary else null,
		"remaining": data.get("remaining", data.get("remaining_amount", null)) if data is Dictionary else null,
		"message": _safe_string(data.get("message", ""), "", 128) if data is Dictionary else "",
		"reason": _safe_string(data.get("reason", ""), "", 64) if data is Dictionary else "",
		"bulk": bool(data.get("bulk_pickup", false)) if data is Dictionary else false,
		"from_world_state": bool(data.get("_from_world_state", false)) if data is Dictionary else false,
		"local_exists": not local_drop.is_empty(),
		"local_amount": _safe_drop_amount(local_drop.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), local_is_weight) if not local_drop.is_empty() else 0.0,
		"local_pending": is_drop_pickup_pending(local_drop) if not local_drop.is_empty() else false,
		"local_aliases": _get_drop_stack_ids(local_drop).duplicate() if not local_drop.is_empty() else [],
		"tombstoned": was_drop_id_recently_removed(clean_drop_id) if clean_drop_id != "" else false,
		"local_drop_count": world.dropped_items.size() if world != null else -1
	}
	print("[PM_DROP_PICKUP_TRACE] " + JSON.stringify(trace_payload))


func _safe_int(value, fallback: int, min_value: int = -2147483648, max_value: int = 2147483647) -> int:
	if value is int or value is float:
		return clamp(int(value), min_value, max_value)

	if value is String:
		var text = value.strip_edges()
		if text.is_valid_int():
			return clamp(int(text), min_value, max_value)

	return fallback


func _safe_float(value, fallback: float, min_value: float = -1.0e9, max_value: float = 1.0e9) -> float:
	if value is int or value is float:
		var num = float(value)
		if not is_finite(num):
			return fallback
		return clamp(num, min_value, max_value)
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_float():
			var parsed_num = float(text)
			if not is_finite(parsed_num):
				return fallback
			return clamp(parsed_num, min_value, max_value)
	return fallback


func _is_fish_drop_category(category: String) -> bool:
	return _safe_string(category, "", MAX_ITEM_CATEGORY_LENGTH).to_lower() == "fish"


func _safe_drop_amount(value, fallback: float = 0.0, min_value: float = 0.0, max_value: float = MAX_DROP_TILE_AMOUNT, is_weight: bool = false) -> float:
	if is_weight:
		return snapped(_safe_float(value, fallback, min_value, max_value), 0.1)
	return float(_safe_int(value, int(round(fallback)), int(round(min_value)), int(round(max_value))))


func _weight_to_tenths(weight) -> int:
	var safe_weight: float = _safe_drop_amount(weight, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), true)
	if safe_weight <= 0.0:
		return 0
	return max(0, int(round(safe_weight * 10.0)))


func _tenths_to_weight(tenths: int) -> float:
	return float(max(0, tenths)) / 10.0


func _inventory_fish_value_to_tenths(value) -> int:
	if value is int:
		return max(0, int(value))
	if value is float:
		var raw_float: float = float(value)
		if not is_finite(raw_float) or raw_float <= 0.0:
			return 0
		if abs(raw_float - round(raw_float)) > 0.0001:
			return _weight_to_tenths(raw_float)
		return max(0, int(round(raw_float)))
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_int():
			return max(0, int(text))
		if text.is_valid_float():
			return _weight_to_tenths(float(text))
	return 0


func _safe_bool(value, fallback: bool = false) -> bool:
	if value is bool:
		return value
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


func prune_recently_removed_drop_ids() -> void:
	if recently_removed_drop_ids.is_empty():
		return

	var now_ms: int = Time.get_ticks_msec()
	var expired_ids: Array = []
	for raw_drop_id in recently_removed_drop_ids.keys():
		var expiry_ms: int = _safe_int(recently_removed_drop_ids.get(raw_drop_id, 0), 0, 0, 922337203685477)
		if expiry_ms <= now_ms:
			expired_ids.append(raw_drop_id)

	for raw_drop_id in expired_ids:
		recently_removed_drop_ids.erase(raw_drop_id)


func mark_drop_id_recently_removed(drop_id: String) -> void:
	var clean_drop_id: String = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return

	prune_recently_removed_drop_ids()
	recently_removed_drop_ids[clean_drop_id] = Time.get_ticks_msec() + DROP_REMOVED_TOMBSTONE_MS


func mark_drop_ids_recently_removed(drop_ids: Array) -> void:
	for raw_drop_id in drop_ids:
		mark_drop_id_recently_removed(_safe_string(raw_drop_id, "", MAX_DROP_ID_LENGTH))


func was_drop_id_recently_removed(drop_id: String) -> bool:
	var clean_drop_id: String = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return false

	prune_recently_removed_drop_ids()
	if not recently_removed_drop_ids.has(clean_drop_id):
		return false

	var expiry_ms: int = _safe_int(recently_removed_drop_ids.get(clean_drop_id, 0), 0, 0, 922337203685477)
	if expiry_ms <= Time.get_ticks_msec():
		recently_removed_drop_ids.erase(clean_drop_id)
		return false
	return true


func is_drop_pickup_pending(drop_data: Dictionary) -> bool:
	if drop_data == null or drop_data.is_empty():
		return false
	return bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false))


func has_pickup_result_fields(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false

	var message_type: String = _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if message_type == "world_item_drop_pickup" or message_type == "world_drop_pickup" or message_type == "world_item_drop_remove" or message_type == "world_drop_remove" or message_type == "drop_removed":
		return true
	if bool(data.get("bulk_pickup", false)):
		return true

	for removed_key in ["removed", "is_removed", "remove", "removed_from_world", "drop_removed"]:
		if data.has(removed_key) and bool(data.get(removed_key, false)):
			return true

	for remaining_key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
		if data.has(remaining_key):
			return true

	for picked_key in ["added_amount", "picked_amount", "picked", "result_amount"]:
		if data.has(picked_key):
			return true

	var removed_ids_value: Variant = data.get("removed_drop_ids", [])
	if removed_ids_value is Array and removed_ids_value.size() > 0:
		return true

	var pickup_results_value: Variant = data.get("pickup_results", [])
	if pickup_results_value is Array and pickup_results_value.size() > 0:
		return true

	return false


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


func reset_drop_pickup_debug_scan() -> void:
	drop_pickup_debug_scan_counts.clear()
	drop_pickup_debug_nearest = {
		"reason": "no_drops",
		"distance_sq": INF,
		"distance_px": -1.0,
		"range_px": 0.0
	}


func get_drop_debug_position(drop_data: Dictionary) -> Vector2:
	if drop_data != null and not drop_data.is_empty():
		var drop_node = drop_data.get("node", null)
		if is_instance_valid(drop_node):
			return drop_node.global_position

		return Vector2(
			_safe_float(drop_data.get("x", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
			_safe_float(drop_data.get("y", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
		)

	return Vector2.ZERO


func record_drop_pickup_debug(reason: String, drop_data: Dictionary = {}, player_position: Vector2 = Vector2.ZERO, pickup_range_sq: float = 0.0, extra: Dictionary = {}) -> void:
	var clean_reason := _safe_string(reason, "unknown", 64)
	drop_pickup_debug_scan_counts[clean_reason] = int(drop_pickup_debug_scan_counts.get(clean_reason, 0)) + 1

	var drop_position := get_drop_debug_position(drop_data)
	var distance_sq := INF
	if not drop_data.is_empty():
		distance_sq = player_position.distance_squared_to(drop_position)

	var current_distance_sq := float(drop_pickup_debug_nearest.get("distance_sq", INF))
	var current_reason := _safe_string(drop_pickup_debug_nearest.get("reason", ""), "", 64)
	if not drop_pickup_debug_nearest.is_empty() and current_reason != "no_drops" and current_distance_sq <= distance_sq:
		return

	var item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_weight := _is_fish_drop_category(item_category)
	var detail: Dictionary = {
		"reason": clean_reason,
		"drop_id": _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH),
		"item_type": _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH),
		"item_category": item_category,
		"amount": _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight),
		"distance_sq": distance_sq,
		"distance_px": sqrt(distance_sq) if distance_sq < INF else -1.0,
		"range_px": sqrt(max(0.0, pickup_range_sq)),
		"player_x": player_position.x,
		"player_y": player_position.y,
		"drop_x": drop_position.x,
		"drop_y": drop_position.y,
		"stack_grid_x": _safe_int(drop_data.get("stack_grid_x", -1), -1, -1, 999999),
		"stack_grid_y": _safe_int(drop_data.get("stack_grid_y", -1), -1, -1, 999999),
		"age": _safe_float(drop_data.get("age", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS * 2.0),
		"pickup_delay": _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS),
		"requested": bool(drop_data.get("pickup_requested", false)),
		"in_progress": bool(drop_data.get("pickup_in_progress", false)),
		"request_sent": bool(drop_data.get("pickup_request_sent", false))
	}
	for key in extra.keys():
		detail[key] = extra[key]
	drop_pickup_debug_nearest = detail


func record_drop_pickup_server_event(reason: String, drop_data: Dictionary = {}, extra: Dictionary = {}) -> void:
	var player_position := Vector2.ZERO
	var pickup_range_sq := 0.0
	if world != null:
		if world.player != null:
			player_position = world.player.global_position
		pickup_range_sq = float(world.PICKUP_RANGE * world.PICKUP_RANGE)
	record_drop_pickup_debug(reason, drop_data, player_position, pickup_range_sq, extra)
	if DEBUG_DROP_PICKUP_AUDIT:
		print("[PM_DROP_PICKUP_SERVER] " + str(drop_pickup_debug_nearest))


func maybe_print_drop_pickup_debug() -> void:
	if not DEBUG_DROP_PICKUP_AUDIT:
		return
	if drop_pickup_debug_nearest.is_empty():
		return

	var reason := _safe_string(drop_pickup_debug_nearest.get("reason", ""), "", 64)
	if reason == "" or reason == "no_drops":
		return

	var now_ms := Time.get_ticks_msec()
	var print_key := reason + ":" + _safe_string(drop_pickup_debug_nearest.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if print_key == drop_pickup_debug_last_print_key and now_ms - drop_pickup_debug_last_print_ms < DROP_PICKUP_DIAGNOSTIC_PRINT_INTERVAL_MS:
		return
	if now_ms - drop_pickup_debug_last_print_ms < DROP_PICKUP_DIAGNOSTIC_PRINT_INTERVAL_MS:
		return

	drop_pickup_debug_last_print_ms = now_ms
	drop_pickup_debug_last_print_key = print_key
	print("[PM_DROP_PICKUP_DIAG] " + str(drop_pickup_debug_nearest) + " counts=" + str(drop_pickup_debug_scan_counts))


func _safe_non_negative_int(raw_value, fallback: int, min_value: int = 0, max_value: int = 2147483647) -> int:
	if raw_value is int:
		var safe_int = int(raw_value)
		if safe_int < min_value:
			return fallback
		return clamp(safe_int, min_value, max_value)

	if raw_value is float:
		if not is_finite(float(raw_value)):
			return fallback
		var safe_float = float(raw_value)
		if safe_float < float(min_value):
			return fallback
		return clamp(int(safe_float), min_value, max_value)

	if raw_value is String:
		var raw_text = raw_value.strip_edges()
		if raw_text.is_valid_int():
			var safe_int = int(raw_text)
			if safe_int < min_value:
				return fallback
			return clamp(safe_int, min_value, max_value)
		if raw_text.is_valid_float():
			var safe_float = float(raw_text)
			if not is_finite(safe_float):
				return fallback
			if safe_float < float(min_value):
				return fallback
			return clamp(int(safe_float), min_value, max_value)
		return fallback

	return fallback


func _safe_inventory_count_for_item(item_type: String, item_category: String) -> float:
	var slot = _safe_stack_target_for_item(item_type, item_category)
	if slot.is_empty():
		return 0

	var inventory = slot.get("inventory", {})
	if not (inventory is Dictionary):
		return 0

	var safe_category = _safe_string(slot.get("category", item_category), item_category, MAX_ITEM_CATEGORY_LENGTH)
	if safe_category == "":
		return 0

	var stack_limit = int(slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(item_type, safe_category)))
	if stack_limit <= 0:
		stack_limit = MAX_DROP_STACK_SIZE

	if _is_fish_drop_category(safe_category):
		return _tenths_to_weight(_inventory_fish_value_to_tenths(inventory.get(item_type, 0)))

	return _safe_drop_amount(inventory.get(item_type, 0.0), 0.0, 0.0, float(stack_limit), _is_fish_drop_category(safe_category))


func _log_drop_pickup_contract_case(case_label: String, item_type: String, inv_before: float, inv_after: float, drop_before: float, drop_after: float, force_print: bool = false) -> void:
	if not DEBUG_DROP_PICKUP_AUDIT and not force_print:
		return

	var added = max(0, inv_after - inv_before)
	print("[PM_DROP][PickupAudit] " + case_label + " item=" + item_type + " inv_before=" + str(inv_before) + " inv_after=" + str(inv_after) + " drop_before=" + str(drop_before) + " drop_after=" + str(drop_after) + " added=" + str(added))


func _extract_pickup_payload_quantities(data: Dictionary, fallback_amount: float, max_value: int = MAX_DROP_STACK_SIZE, is_weight: bool = false) -> Dictionary:
	var safe_fallback: float = _safe_drop_amount(fallback_amount, 0.0, 0.0, float(max_value), is_weight)
	var result = {
		"remaining": safe_fallback,
		"remaining_valid": false,
		"added": 0,
		"added_valid": false,
		"remaining_derived": false
	}

	if data == null or not (data is Dictionary):
		return result

	var fallback_invalid = -1
	for removed_key in ["removed", "is_removed", "remove", "removed_from_world", "drop_removed"]:
		if not data.has(removed_key):
			continue

		var removed_value = data.get(removed_key)
		if removed_value is bool:
			if bool(removed_value):
				result["remaining"] = 0
				result["remaining_valid"] = true
				return result
		else:
			var parsed = _safe_non_negative_int(removed_value, fallback_invalid, 1, 1)
			if parsed >= 0:
				result["remaining"] = 0
				result["remaining_valid"] = true
				return result

	for key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
		if not data.has(key):
			continue
		var parsed: float = _safe_drop_amount(data.get(key), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(max_value), is_weight)
		if parsed >= 0.0:
			result["remaining"] = parsed
			result["remaining_valid"] = true
			return result

	for key in ["added_amount", "picked_amount", "picked", "result_amount"]:
		if not data.has(key):
			continue

		var parsed: float = _safe_drop_amount(data.get(key), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(max_value), is_weight)
		if parsed >= 0.0:
			result["added"] = parsed
			result["added_valid"] = true
			break

	if not result["remaining_valid"] and not result["added_valid"] and data.has("amount"):
		var parsed: float = _safe_drop_amount(data.get("amount"), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(max_value), is_weight)
		if parsed >= 0.0:
			var message_type = _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
			if message_type == "world_item_drop_pickup" or message_type == "world_drop_pickup":
				result["added"] = parsed
				result["added_valid"] = true
			else:
				result["remaining"] = parsed
				result["remaining_valid"] = true

	if not result["remaining_valid"] and result["added_valid"]:
		result["remaining"] = max(0, safe_fallback - result["added"])
		result["remaining_derived"] = true

	return result


func _safe_grid_position(raw_x, raw_y) -> Vector2i:
	if world == null:
		return Vector2i.ZERO

	var max_x = max(world.WORLD_WIDTH - 1, 0)
	var max_y = max(world.WORLD_HEIGHT - 1, 0)
	return Vector2i(
		_safe_int(raw_x, 0, 0, max_x),
		_safe_int(raw_y, 0, 0, max_y)
	)


func setup(world_ref):
	world = world_ref
	configure_drop_pickup_trace()
	rebuild_drop_indexes()
	drop_pickup_scan_elapsed = 0.0
	pending_pickup_ui_refreshes.clear()
	pending_pickup_ui_flush_at_ms = 0
	drop_queued_pickup_next_process_ms = 0
	reset_drop_pickup_debug_scan()
	reset_drop_pickup_send_budget()
	recently_removed_drop_ids.clear()


func create_drop_count_controls(drop_data: Dictionary):
	var drop_node = drop_data.get("node", null)
	if drop_node == null or not is_instance_valid(drop_node) or not (drop_node is Node2D):
		return

	remove_drop_count_controls(drop_data)

	var count_label = Label.new()
	count_label.name = "DropCount"
	count_label.size = DROP_COUNT_LABEL_SIZE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.z_as_relative = false
	count_label.z_index = DROP_COUNT_WORLD_Z_INDEX
	count_label.add_theme_font_size_override("font_size", DROP_COUNT_BASE_FONT_SIZE)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	count_label.add_theme_constant_override("outline_size", DROP_COUNT_BASE_OUTLINE_SIZE)
	count_label.visible = false
	drop_node.add_child(count_label)

	drop_data["count_label_ui"] = count_label


func remove_drop_count_controls(drop_data: Dictionary):
	var count_badge = drop_data.get("count_badge_ui", null)
	if is_instance_valid(count_badge):
		count_badge.queue_free()

	var count_label = drop_data.get("count_label_ui", null)
	if is_instance_valid(count_label):
		count_label.queue_free()

	drop_data.erase("count_badge_ui")
	drop_data.erase("count_label_ui")


func get_drop_count_screen_scale() -> float:
	if world == null:
		return 1.0

	var zoom = float(world.current_camera_zoom) if "current_camera_zoom" in world else 1.0
	var default_zoom = float(world.CAMERA_ZOOM_DEFAULT) if "CAMERA_ZOOM_DEFAULT" in world else 3.0
	if default_zoom <= 0.0:
		default_zoom = 1.0
	return clamp(zoom / default_zoom, 0.45, 2.4)


func get_visible_world_rect(margin_screen_px: float = 0.0) -> Rect2:
	var viewport = get_viewport()
	if viewport == null:
		return Rect2(Vector2(-MAX_WORLD_COORD, -MAX_WORLD_COORD), Vector2(MAX_WORLD_COORD * 2.0, MAX_WORLD_COORD * 2.0))

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


func is_drop_in_visible_world_rect(drop_node, visible_world_rect: Rect2) -> bool:
	if drop_node == null or not is_instance_valid(drop_node):
		return false
	if visible_world_rect.size.x <= 0.0 or visible_world_rect.size.y <= 0.0:
		return true
	return visible_world_rect.has_point(drop_node.global_position)


func set_drop_visual_active(drop_data: Dictionary, drop_node, active: bool, amount: float = -1.0) -> void:
	if drop_node == null or not is_instance_valid(drop_node):
		return

	if drop_node.visible != active:
		drop_node.visible = active

	var count_label = drop_data.get("count_label_ui", null)
	if not is_instance_valid(count_label):
		return

	if not active:
		count_label.visible = false
		return

	if amount < 0.0:
		var label_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		amount = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), _is_fish_drop_category(label_category))
	count_label.visible = str(count_label.text).strip_edges() != "" and should_show_drop_count_label(drop_data, amount)


func rebuild_drop_indexes():
	drops_by_id.clear()
	drops_by_cell.clear()

	if world == null:
		return

	for raw_drop_data in world.dropped_items:
		if raw_drop_data is Dictionary:
			register_drop(raw_drop_data)
			update_drop_count_label(raw_drop_data)


func get_drop_cell_key(stack_grid: Vector2i) -> String:
	return str(stack_grid.x) + ":" + str(stack_grid.y)


func get_drop_cell_from_data(drop_data: Dictionary) -> Vector2i:
	return Vector2i(
		_safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999),
		_safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
	)


func _get_cell_drops(stack_grid: Vector2i) -> Array:
	var cell_key = get_drop_cell_key(stack_grid)
	return drops_by_cell.get(cell_key, [])


func get_nearby_drop_candidates(player_position: Vector2, pickup_range_sq: float) -> Array:
	if world == null:
		return []

	var block_size = max(1.0, float(world.BLOCK_SIZE))
	var pickup_range = sqrt(max(0.0, pickup_range_sq))
	var cell_radius = int(ceil(pickup_range / block_size)) + 1
	var center_grid = get_drop_stack_grid(player_position)
	var candidates: Array = []

	for y in range(center_grid.y - cell_radius, center_grid.y + cell_radius + 1):
		for x in range(center_grid.x - cell_radius, center_grid.x + cell_radius + 1):
			var cell_drops = _get_cell_drops(Vector2i(x, y))
			for drop_data in cell_drops:
				candidates.append(drop_data)

	return candidates


func _add_drop_candidate_ids(drop_data: Dictionary, candidate_ids: Dictionary) -> void:
	var had_id := false
	for raw_drop_id in _get_drop_stack_ids(drop_data):
		var clean_drop_id: String = _safe_string(raw_drop_id, "", MAX_DROP_ID_LENGTH)
		if clean_drop_id == "":
			continue
		had_id = true
		candidate_ids[clean_drop_id] = true

	var primary_drop_id: String = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if primary_drop_id != "":
		had_id = true
		candidate_ids[primary_drop_id] = true

	if not had_id:
		candidate_ids[""] = true


func _drop_matches_candidate_ids(drop_data: Dictionary, candidate_ids: Dictionary) -> bool:
	if candidate_ids.is_empty():
		return false

	var had_id := false
	for raw_drop_id in _get_drop_stack_ids(drop_data):
		var clean_drop_id: String = _safe_string(raw_drop_id, "", MAX_DROP_ID_LENGTH)
		if clean_drop_id == "":
			continue
		had_id = true
		if candidate_ids.has(clean_drop_id):
			return true

	var primary_drop_id: String = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if primary_drop_id != "":
		had_id = true
		if candidate_ids.has(primary_drop_id):
			return true

	return not had_id and candidate_ids.has("")


func get_drop_total_amount_on_tile(stack_grid: Vector2i) -> float:
	if world == null:
		return 0.0

	var total := 0.0
	var cell_drops = _get_cell_drops(stack_grid)

	for drop_data in cell_drops:
		var drop_node = drop_data.get("node", null)
		if not is_instance_valid(drop_node):
			continue

		var item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		total += _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), _is_fish_drop_category(item_category))

	return min(total, float(MAX_DROP_TILE_AMOUNT))


func get_drop_remaining_capacity_on_tile(stack_grid: Vector2i) -> float:
	return max(0.0, float(MAX_DROP_TILE_AMOUNT) - get_drop_total_amount_on_tile(stack_grid))


func register_drop(drop_data: Dictionary):
	var drop_ids: Array = _get_drop_stack_ids(drop_data)
	var cell_key = get_drop_cell_key(get_drop_cell_from_data(drop_data))
	if not drops_by_cell.has(cell_key):
		drops_by_cell[cell_key] = []

	for drop_id in drop_ids:
		var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
		if clean_drop_id != "":
			if drops_by_id.has(clean_drop_id):
				var existing_drop_data = drops_by_id[clean_drop_id]
				if existing_drop_data != drop_data:
					var existing_ids: Array = _get_drop_stack_ids(existing_drop_data)
					existing_ids.erase(clean_drop_id)
					existing_drop_data["drop_stack_ids"] = existing_ids
					if existing_ids.is_empty():
						var stale_node = existing_drop_data.get("node", null)
						if is_instance_valid(stale_node):
							stale_node.queue_free()
						remove_drop_count_controls(existing_drop_data)
						unregister_drop(existing_drop_data)
						if world != null:
							var stale_index = world.dropped_items.find(existing_drop_data)
							if stale_index >= 0:
								world.dropped_items.remove_at(stale_index)
					else:
						drops_by_id[clean_drop_id] = existing_drop_data

			drops_by_id[clean_drop_id] = drop_data

	var cell_drops: Array = drops_by_cell[cell_key]
	if not cell_drops.has(drop_data):
		cell_drops.append(drop_data)
	sync_drop_node_metadata(drop_data)


func unregister_drop(drop_data: Dictionary):
	var drop_ids: Array = _get_drop_stack_ids(drop_data)
	for drop_id in drop_ids:
		var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
		if clean_drop_id != "":
			drops_by_id.erase(clean_drop_id)

	var cell_key = get_drop_cell_key(get_drop_cell_from_data(drop_data))
	if drops_by_cell.has(cell_key):
		var cell_drops: Array = drops_by_cell[cell_key]
		cell_drops.erase(drop_data)
		if cell_drops.is_empty():
			drops_by_cell.erase(cell_key)


func _get_drop_stack_ids(drop_data: Dictionary) -> Array:
	var clean_drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	var aliases = drop_data.get("drop_stack_ids", null)
	if aliases is Array:
		return aliases

	var initialized_ids = []
	if clean_drop_id != "":
		initialized_ids.append(clean_drop_id)
	drop_data["drop_stack_ids"] = initialized_ids
	return initialized_ids


func _get_drop_stack_amounts(drop_data: Dictionary) -> Dictionary:
	if drop_data == null or drop_data.is_empty():
		return {}

	var amounts = drop_data.get("drop_stack_amounts", null)
	if amounts is Dictionary:
		return amounts

	var initialized_amounts: Dictionary = {}
	var aliases = _get_drop_stack_ids(drop_data)
	var is_weight: bool = _is_fish_drop_category(str(drop_data.get("item_category", "")))
	var total_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if aliases.size() <= 1:
		var primary_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if primary_id != "":
			initialized_amounts[primary_id] = total_amount
	else:
		var remaining = total_amount
		for alias_id in aliases:
			var clean_alias = _safe_string(alias_id, "", MAX_DROP_ID_LENGTH)
			if clean_alias == "":
				continue
			var alias_amount: float = min(1.0, remaining) if remaining > 0.0 else 0.0
			initialized_amounts[clean_alias] = alias_amount
			remaining -= alias_amount

	drop_data["drop_stack_amounts"] = initialized_amounts
	return initialized_amounts


func _remember_drop_stack_amount(drop_data: Dictionary, drop_id: String, amount: float) -> void:
	var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return

	var amounts = _get_drop_stack_amounts(drop_data)
	amounts[clean_drop_id] = _safe_drop_amount(amount, 0.0, 0.0, float(MAX_DROP_STACK_SIZE), _is_fish_drop_category(str(drop_data.get("item_category", ""))))


func _forget_drop_stack_amount(drop_data: Dictionary, drop_id: String) -> void:
	var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return

	var amounts = drop_data.get("drop_stack_amounts", null)
	if amounts is Dictionary:
		amounts.erase(clean_drop_id)


func _get_drop_stack_amount_for_id(drop_data: Dictionary, drop_id: String) -> float:
	var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return 0

	var amounts = _get_drop_stack_amounts(drop_data)
	var is_weight: bool = _is_fish_drop_category(str(drop_data.get("item_category", "")))
	if amounts.has(clean_drop_id):
		return _safe_drop_amount(amounts.get(clean_drop_id, 0.0), 0.0, 0.0, float(MAX_DROP_STACK_SIZE), is_weight)

	return min(1.0, _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_STACK_SIZE), is_weight))


func add_drop_stack_id(drop_data: Dictionary, drop_id: String, stack_amount: float = 0.0, make_primary: bool = false) -> void:
	var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return

	var aliases = _get_drop_stack_ids(drop_data)
	if not aliases.has(clean_drop_id):
		aliases.append(clean_drop_id)
	if stack_amount > 0.0:
		_remember_drop_stack_amount(drop_data, clean_drop_id, stack_amount)
	if make_primary:
		drop_data["drop_id"] = clean_drop_id
	drops_by_id[clean_drop_id] = drop_data
	sync_drop_node_metadata(drop_data)


func sync_drop_node_metadata(drop_data: Dictionary) -> void:
	if drop_data == null or drop_data.is_empty():
		return

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	var clean_drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	var stack_ids = _get_drop_stack_ids(drop_data).duplicate()
	drop_node.set_meta("drop_id", clean_drop_id)
	drop_node.set_meta("server_drop_id", clean_drop_id)
	drop_node.set_meta("drop_stack_ids", stack_ids)
	_rebuild_drop_visuals(drop_data)


func get_pickup_drop_id(drop_data: Dictionary) -> String:
	if drop_data == null or drop_data.is_empty():
		return ""

	var aliases = _get_drop_stack_ids(drop_data)
	for i in range(aliases.size() - 1, -1, -1):
		var alias_id = aliases[i]
		var clean_alias = _safe_string(alias_id, "", MAX_DROP_ID_LENGTH)
		if clean_alias != "" and _get_drop_stack_amount_for_id(drop_data, clean_alias) > 0:
			return clean_alias

	var primary_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if primary_id != "":
		return primary_id

	for alias_id in aliases:
		var clean_alias = _safe_string(alias_id, "", MAX_DROP_ID_LENGTH)
		if clean_alias != "":
			return clean_alias

	return ""


func get_pickup_request_drop_id(drop_data: Dictionary) -> String:
	if drop_data == null or drop_data.is_empty():
		return ""

	# Server-authoritative lookup uses the drop_id field as source of truth.
	# Fall back to alias stack IDs only when primary id is missing.
	var primary_drop_id: String = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if primary_drop_id != "":
		return primary_drop_id

	return get_pickup_drop_id(drop_data)


func get_pickup_source_amount_for_drop(drop_data: Dictionary, pickup_drop_id: String = "") -> float:
	if drop_data == null or drop_data.is_empty():
		return 0.0

	var item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_weight: bool = _is_fish_drop_category(item_category)
	var total_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if total_amount <= 0.0:
		return 0.0

	var clean_pickup_id := _safe_string(pickup_drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_pickup_id == "":
		clean_pickup_id = get_pickup_drop_id(drop_data)

	var aliases: Array = _get_drop_stack_ids(drop_data)
	if clean_pickup_id != "" and aliases.size() > 1 and aliases.has(clean_pickup_id):
		var alias_amount: float = _get_drop_stack_amount_for_id(drop_data, clean_pickup_id)
		var minimum_amount: float = 0.1 if is_weight else 1.0
		return min(total_amount, max(minimum_amount, alias_amount))

	return total_amount


func unregister_drop_id(drop_data: Dictionary, drop_id: String) -> void:
	var clean_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "":
		return

	var aliases = _get_drop_stack_ids(drop_data)
	aliases.erase(clean_drop_id)
	_forget_drop_stack_amount(drop_data, clean_drop_id)
	if _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH) == clean_drop_id:
		drop_data["drop_id"] = _safe_string(aliases[aliases.size() - 1], "", MAX_DROP_ID_LENGTH) if aliases.size() > 0 else ""
	drops_by_id.erase(clean_drop_id)
	sync_drop_node_metadata(drop_data)


func get_network_manager():
	if world == null:
		return null

	return world.get_node_or_null("/root/NetworkManager")


func should_send_network_drop_update() -> bool:
	if world == null:
		return false

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return false

	return true


func is_applying_network_world_update() -> bool:
	if world == null:
		return false
	if "applying_network_world_update" in world:
		return bool(world.applying_network_world_update)
	return false


func should_use_server_authoritative_world_actions() -> bool:
	if USE_LEGACY_CLIENT_LOCAL_DROPS:
		return false
	if world == null:
		return false
	if world.has_method("should_use_server_authoritative_world_actions"):
		if not bool(world.should_use_server_authoritative_world_actions()):
			return false
	else:
		return false
	var network = get_network_manager()
	if network == null:
		return false
	if network.has_method("is_server_session_authenticated"):
		return bool(network.is_server_session_authenticated())
	return bool(network.get("server_session_authenticated"))


func generate_drop_id() -> String:
	local_drop_sequence += 1
	var owner_id = "local"
	var network = get_network_manager()

	if network != null:
		var network_player_id = network.get("player_id")
		if network_player_id != null:
			owner_id = str(network_player_id).strip_edges()

	if owner_id == "":
		owner_id = "local"

	return owner_id + "_" + str(Time.get_ticks_msec()) + "_" + str(local_drop_sequence)


func get_drop_by_id(drop_id: String) -> Dictionary:
	if world == null:
		return {}

	var clean_id = drop_id.strip_edges()
	if clean_id == "":
		return {}

	if drops_by_id.has(clean_id):
		var indexed_drop: Dictionary = drops_by_id[clean_id]
		var indexed_node = indexed_drop.get("node", null)
		if is_instance_valid(indexed_node):
			return indexed_drop
		drops_by_id.erase(clean_id)

	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if str(drop_data.get("drop_id", "")) == clean_id:
			var drop_node = drop_data.get("node", null)
			if is_instance_valid(drop_node):
				register_drop(drop_data)
				return drop_data

	return {}


func get_drop_network_payload(drop_data: Dictionary) -> Dictionary:
	var drop_node = drop_data.get("node", null)
	var drop_position = Vector2(
		_safe_float(drop_data.get("x", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		_safe_float(drop_data.get("y", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
	)

	if is_instance_valid(drop_node):
		drop_position = drop_node.global_position

	if not is_finite(drop_position.x) or not is_finite(drop_position.y):
		drop_position = Vector2.ZERO

	var payload_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var payload_amount: float = _safe_drop_amount(drop_data.get("amount", 1.0), 1.0, 1.0, float(MAX_DROP_TILE_AMOUNT), false)
	var payload: Dictionary = {
		"drop_id": _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH),
		"item_type": _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH),
		"item_category": payload_category,
		"is_seed": _safe_bool(drop_data.get("is_seed", false), false),
		"amount": payload_amount,
		"x": drop_position.x,
		"y": drop_position.y,
		"stack_grid_x": _safe_int(drop_data.get("stack_grid_x", _safe_int(round(drop_position.x / world.BLOCK_SIZE), 0, 0, 999999)), 0, 0, 999999),
		"stack_grid_y": _safe_int(drop_data.get("stack_grid_y", _safe_int(round(drop_position.y / world.BLOCK_SIZE), 0, 0, 999999)), 0, 0, 999999),
		"pickup_delay": _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
	}
	return payload


func send_network_drop_create(drop_data: Dictionary) -> bool:
	if not should_send_network_drop_update():
		return false

	var network = get_network_manager()
	if network != null and network.has_method("send_world_item_drop_create"):
		return bool(network.send_world_item_drop_create(get_drop_network_payload(drop_data), world.current_world_name))
	return false


func send_network_drop_update(drop_data: Dictionary) -> bool:
	if not should_send_network_drop_update():
		return false

	var network = get_network_manager()
	if network != null and network.has_method("send_world_item_drop_update"):
		return bool(network.send_world_item_drop_update(get_drop_network_payload(drop_data), world.current_world_name))
	return false


func send_network_drop_pickup(drop_data: Dictionary) -> bool:
	if not should_send_network_drop_update():
		return false

	var network = get_network_manager()
	if network != null and network.has_method("send_world_item_drop_pickup"):
		var payload = {
			"drop_id": get_pickup_request_drop_id(drop_data)
		}
		if drop_data.has("stack_grid_x"):
			payload["stack_grid_x"] = _safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999)
		if drop_data.has("stack_grid_y"):
			payload["stack_grid_y"] = _safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
		if payload["drop_id"] == "":
			return false
		var pickup_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var pickup_amount: float = _safe_drop_amount(drop_data.get("pickup_requested_amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), false)
		if pickup_amount > 0.0:
			payload["amount"] = pickup_amount
			payload["item_type"] = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			payload["item_category"] = pickup_category
		var already_sent_drop_id = _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		var request_age = _safe_float(drop_data.get("pickup_requested_age", 0.0), 0.0, 0.0, DROP_PICKUP_REQUEST_TIMEOUT * 2.0)
		if bool(drop_data.get("pickup_request_sent", false)) and already_sent_drop_id == payload["drop_id"] and request_age < DROP_PICKUP_REQUEST_TIMEOUT:
			return true
		var local_player_id = _safe_string(network.get("player_id"), "", MAX_REQUEST_ID_LENGTH)
		if local_player_id != "":
			payload["requested_by"] = local_player_id
			payload["picker_id"] = local_player_id
		drop_data["pickup_requested_by"] = local_player_id
		drop_data["pickup_requested_drop_id"] = _safe_string(payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		var now_ms := Time.get_ticks_msec()
		drop_data["pickup_request_ms"] = now_ms
		drop_data["pickup_request_sent"] = false

		# Client only requests pickup. Server must authoritatively validate and compute amount.
		debug_drop_pickup_flow("send pickup request", drop_data, {
			"payload": payload.duplicate(true)
		})
		trace_drop_pickup_event("client_send_pickup", payload, drop_data)
		debug_action_position_flow("pickup request send", {
			"drop_id": str(payload.get("drop_id", ""))
		})
		var sent = bool(network.send_world_item_drop_pickup(payload))
		if sent:
			drop_data["pickup_request_sent"] = true
			drop_data["pickup_request_ms"] = now_ms
			debug_action_position_flow("pickup request end", {
				"drop_id": str(payload.get("drop_id", "")),
				"sent": true
			})
			return true

		drop_data["pickup_request_sent"] = false
		drop_data["pickup_request_ms"] = now_ms
		drop_data["pickup_blocked_until_ms"] = now_ms + int(DROP_PICKUP_BUSY_RETRY_COOLDOWN * 1000.0)
		debug_action_position_flow("pickup request end", {
			"drop_id": str(payload.get("drop_id", "")),
			"sent": false
		})
		return false
	return false


func get_drop_pickup_network_payload(drop_data: Dictionary, local_player_id: String = "") -> Dictionary:
	var payload: Dictionary = {
		"drop_id": get_pickup_request_drop_id(drop_data)
	}
	if drop_data.has("stack_grid_x"):
		payload["stack_grid_x"] = _safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999)
	if drop_data.has("stack_grid_y"):
		payload["stack_grid_y"] = _safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
	var pickup_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var pickup_amount: float = _safe_drop_amount(drop_data.get("pickup_requested_amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), false)
	if pickup_amount > 0.0:
		payload["amount"] = pickup_amount
		payload["item_type"] = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = pickup_category
	if local_player_id != "":
		payload["requested_by"] = local_player_id
		payload["picker_id"] = local_player_id
	return payload


func get_same_tile_queued_pickup_batch(anchor_drop: Dictionary) -> Array:
	var batch: Array = []
	if world == null or anchor_drop == null or anchor_drop.is_empty():
		return batch

	var anchor_grid: Vector2i = get_drop_cell_from_data(anchor_drop)
	var cell_drops: Array = _get_cell_drops(anchor_grid)
	var seen_ids: Dictionary = {}
	var anchor_id: String = get_pickup_drop_id(anchor_drop)
	if anchor_id != "":
		seen_ids[anchor_id] = true
		batch.append(anchor_drop)

	for raw_candidate in cell_drops:
		if batch.size() >= DROP_MAX_BULK_PICKUP_IDS:
			break
		if not (raw_candidate is Dictionary):
			continue

		var candidate: Dictionary = raw_candidate
		var candidate_id: String = get_pickup_drop_id(candidate)
		if candidate_id == "" or seen_ids.has(candidate_id):
			continue
		if not bool(candidate.get("pickup_requested", false)):
			continue
		if bool(candidate.get("pickup_in_progress", false)) or bool(candidate.get("pickup_request_sent", false)):
			continue
		if not is_queued_drop_pickup_still_reachable(candidate):
			continue

		seen_ids[candidate_id] = true
		batch.append(candidate)

	return batch


func send_network_drop_pickup_bulk(drop_entries: Array) -> bool:
	if not should_send_network_drop_update():
		return false

	if drop_entries.size() <= 1:
		if drop_entries.size() == 1 and drop_entries[0] is Dictionary:
			return send_network_drop_pickup(drop_entries[0])
		return false

	var network = get_network_manager()
	if network == null or not network.has_method("send_world_item_drop_pickup_bulk"):
		if drop_entries[0] is Dictionary:
			var fallback_drop: Dictionary = drop_entries[0]
			return send_network_drop_pickup(fallback_drop)
		return false

	var local_player_id: String = _safe_string(network.get("player_id"), "", MAX_REQUEST_ID_LENGTH)
	var payloads: Array = []
	var pending_drops: Array = []
	var now_ms := Time.get_ticks_msec()

	for raw_drop in drop_entries:
		if not (raw_drop is Dictionary):
			continue
		var drop_data: Dictionary = raw_drop
		var payload: Dictionary = get_drop_pickup_network_payload(drop_data, local_player_id)
		var clean_drop_id: String = _safe_string(payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if clean_drop_id == "":
			continue
		payloads.append(payload)
		pending_drops.append(drop_data)

	if payloads.size() <= 1:
		if pending_drops.size() == 1:
			var single_drop: Dictionary = pending_drops[0]
			single_drop["pickup_in_progress"] = true
			single_drop["pickup_requested_age"] = 0.0
			return send_network_drop_pickup(single_drop)
		return false

	for raw_pending in pending_drops:
		var pending_drop: Dictionary = raw_pending
		var pending_payload: Dictionary = get_drop_pickup_network_payload(pending_drop, local_player_id)
		pending_drop["pickup_in_progress"] = true
		pending_drop["pickup_requested_age"] = 0.0
		pending_drop["pickup_requested_by"] = local_player_id
		pending_drop["pickup_requested_drop_id"] = _safe_string(pending_payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		pending_drop["pickup_request_ms"] = now_ms
		pending_drop["pickup_request_sent"] = false

	debug_drop_pickup_flow("send bulk pickup request", pending_drops[0], {
		"count": payloads.size(),
		"payloads": payloads.duplicate(true)
	})
	trace_drop_pickup_event("client_send_bulk_pickup", {
		"drop_ids": _get_payload_drop_ids(payloads),
		"count": payloads.size()
	}, pending_drops[0])
	debug_action_position_flow("bulk pickup request send", {
		"count": payloads.size()
	})

	var sent := bool(network.send_world_item_drop_pickup_bulk(payloads))
	for raw_pending in pending_drops:
		var pending_drop: Dictionary = raw_pending
		pending_drop["pickup_request_ms"] = now_ms
		pending_drop["pickup_request_sent"] = sent
		if not sent:
			pending_drop["pickup_in_progress"] = false
			pending_drop["pickup_blocked_until_ms"] = now_ms + int(DROP_PICKUP_BUSY_RETRY_COOLDOWN * 1000.0)

	debug_action_position_flow("bulk pickup request end", {
		"count": payloads.size(),
		"sent": sent
	})
	return sent


func get_item_drop_texture(item_type: String, item_category: String):
	if world == null:
		return null

	var clean_category: String = item_category.strip_edges().to_lower()

	if clean_category == "block":
		var atlas_icon := get_atlas_block_item_icon(item_type)
		if atlas_icon != null:
			world.block_textures[item_type] = atlas_icon
			return atlas_icon

	if clean_category == "block" and world.block_textures.has(item_type):
		return world.block_textures[item_type]

	if clean_category == "seed" and world.has_method("get_seed_drop_icon_texture"):
		var seed_icon = world.get_seed_drop_icon_texture(item_type)
		if seed_icon != null:
			return seed_icon

	if clean_category == "seed" and world.seed_textures.has(item_type):
		return world.seed_textures[item_type]

	if clean_category != "block" and clean_category != "seed" and world.item_database.has(item_type):
		var preview_item_data: Dictionary = world.item_database[item_type]
		var explicit_preview_icon: Texture2D = AtlasTextureFactory.load_texture(preview_item_data.get("inventory_icon", null))
		if explicit_preview_icon != null:
			return explicit_preview_icon

	if clean_category == "tool" and world.tool_textures.has(item_type):
		return world.tool_textures[item_type]

	if clean_category == "currency" and world.currency_textures.has(item_type):
		return world.currency_textures[item_type]

	if clean_category == "material" and world.material_textures.has(item_type):
		return world.material_textures[item_type]

	if clean_category == "lure" and world.lure_textures.has(item_type):
		return world.lure_textures[item_type]

	if clean_category == "fish" and world.fish_textures.has(item_type):
		return world.fish_textures[item_type]

	if clean_category == "back" and world.back_textures.has(item_type):
		return world.back_textures[item_type]

	if clean_category == "hat" and world.hat_textures.has(item_type):
		return world.hat_textures[item_type]

	if clean_category == "hair" and world.hair_textures.has(item_type):
		return world.hair_textures[item_type]

	if clean_category == "eyewear" and world.eyewear_textures.has(item_type):
		return world.eyewear_textures[item_type]

	if clean_category == "shirt" and world.shirt_textures.has(item_type):
		return world.shirt_textures[item_type]

	if clean_category == "pants" and world.pants_textures.has(item_type):
		return world.pants_textures[item_type]

	if clean_category == "shoes" and world.shoes_textures.has(item_type):
		return world.shoes_textures[item_type]

	if clean_category == "ride" and world.ride_textures.has(item_type):
		return world.ride_textures[item_type]

	if world.item_database.has(item_type):
		var item_data: Dictionary = world.item_database[item_type]

		if clean_category == "block":
			var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_type)))
			if atlas_item_id > 0:
				var atlas_tile_set: TileSet = null
				if world.has_method("get_item_atlas_tile_set"):
					atlas_tile_set = world.get_item_atlas_tile_set()
				var atlas_texture: Texture2D = ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)
				if atlas_texture != null:
					world.block_textures[item_type] = atlas_texture
					return atlas_texture

		var loaded_texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))

		if loaded_texture != null:
			match clean_category:
				"block":
					world.block_textures[item_type] = loaded_texture
				"seed":
					world.seed_textures[item_type] = loaded_texture
				"tool":
					world.tool_textures[item_type] = loaded_texture
				"currency":
					world.currency_textures[item_type] = loaded_texture
				"material":
					world.material_textures[item_type] = loaded_texture
				"lure":
					world.lure_textures[item_type] = loaded_texture
				"fish":
					world.fish_textures[item_type] = loaded_texture
				"back":
					world.back_textures[item_type] = loaded_texture
				"hat":
					world.hat_textures[item_type] = loaded_texture
				"hair":
					world.hair_textures[item_type] = loaded_texture
				"eyewear":
					world.eyewear_textures[item_type] = loaded_texture
				"shirt":
					world.shirt_textures[item_type] = loaded_texture
				"pants":
					world.pants_textures[item_type] = loaded_texture
				"shoes":
					world.shoes_textures[item_type] = loaded_texture
				"ride":
					world.ride_textures[item_type] = loaded_texture

			return loaded_texture

	return null


func get_atlas_block_item_icon(item_type: String) -> Texture2D:
	if world == null or not world.item_database.has(item_type):
		return null

	var item_data = world.item_database[item_type]
	if not (item_data is Dictionary):
		return null

	var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_type)))
	if atlas_item_id <= 0:
		return null

	var atlas_tile_set: TileSet = null
	if world.has_method("get_item_atlas_tile_set"):
		atlas_tile_set = world.get_item_atlas_tile_set()

	return ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)


func _is_gem_drop_item(item_type: String, item_category: String) -> bool:
	return _safe_string(item_type, "", MAX_ITEM_ID_LENGTH) == "gem" and _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH).to_lower() == "currency"


func get_colour_cycle_item_data(item_type: String) -> Dictionary:
	var clean_item := _safe_string(item_type, "", MAX_ITEM_ID_LENGTH).to_lower()
	if clean_item == "" or world == null or not world.item_database.has(clean_item):
		return {}
	var item_data: Variant = world.item_database.get(clean_item, {})
	if item_data is Dictionary and ColourCycleModulation.is_colour_cycle_item(item_data):
		return item_data
	return {}


func is_colour_cycle_drop_item(item_type: String, item_category: String) -> bool:
	return _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH).to_lower() == "block" and not get_colour_cycle_item_data(item_type).is_empty()


func get_drop_colour_cycle_modulate(item_type: String, drop_node) -> Color:
	var item_data := get_colour_cycle_item_data(item_type)
	if item_data.is_empty():
		return Color.WHITE
	var phase_seed := 0.0
	if drop_node is Node2D:
		var grid_pos := Vector2i(
			int(floor((drop_node as Node2D).global_position.x / 32.0)),
			int(floor((drop_node as Node2D).global_position.y / 32.0))
		)
		phase_seed = ColourCycleModulation.get_grid_phase_seed(grid_pos)
	return ColourCycleModulation.get_colour_cycle_modulate(item_data, phase_seed)


func apply_drop_colour_cycle_visual(drop_data: Dictionary) -> void:
	if drop_data == null or drop_data.is_empty():
		return
	var drop_node = drop_data.get("node", null)
	if drop_node == null or not is_instance_valid(drop_node):
		return
	var visual_root = drop_node.get_node_or_null(DROP_VISUAL_ROOT_NAME)
	if visual_root == null:
		return
	var sprite := visual_root.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var item_type := _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category := _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_colour_cycle_drop: bool = bool(drop_data.get("colour_cycle_drop", false))
	if not drop_data.has("colour_cycle_drop"):
		is_colour_cycle_drop = is_colour_cycle_drop_item(item_type, item_category)
		drop_data["colour_cycle_drop"] = is_colour_cycle_drop
	if not is_colour_cycle_drop:
		sprite.self_modulate = Color.WHITE
		return
	sprite.self_modulate = get_drop_colour_cycle_modulate(item_type, drop_node)


func _get_drop_visual_scale(item_category: String, item_type: String) -> Vector2:
	var clean_category := _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
	match clean_category:
		"seed":
			return Vector2(0.75, 0.75)
		"tool":
			return Vector2(0.55, 0.55)
		"currency", "material", "lure", "fish", "hat", "hair", "eyewear", "shirt", "pants", "shoes", "ride":
			return Vector2(0.62, 0.62)
		"back":
			if item_type == "legendary_wings":
				return Vector2(0.05, 0.05)
			return Vector2(0.62, 0.62)
		_:
			return Vector2(0.5, 0.5)


func _ensure_drop_visual_root(drop_node) -> Node2D:
	if drop_node == null or not is_instance_valid(drop_node):
		return null

	var visual_root = drop_node.get_node_or_null(DROP_VISUAL_ROOT_NAME)
	if visual_root != null and not (visual_root is Node2D):
		drop_node.remove_child(visual_root)
		visual_root.queue_free()
		visual_root = null

	if visual_root == null:
		visual_root = Node2D.new()
		visual_root.name = DROP_VISUAL_ROOT_NAME
		drop_node.add_child(visual_root)

	return visual_root


func _clear_drop_visual_root(visual_root: Node2D) -> void:
	if visual_root == null or not is_instance_valid(visual_root):
		return

	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()


func _get_gem_drop_variant_key_for_amount(amount: int) -> String:
	var safe_amount: int = clamp(amount, 1, GEM_DROP_VISUAL_STACK_SIZE)
	if safe_amount <= GEM_DROP_SMALL_MAX:
		return "small"
	if safe_amount <= GEM_DROP_MEDIUM_MAX:
		return "medium"
	if safe_amount <= GEM_DROP_LARGE_MAX:
		return "large"
	return "huge"


func _get_gem_drop_variant_texture_for_amount(amount: int) -> Texture2D:
	var variant_key := _get_gem_drop_variant_key_for_amount(amount)
	if gem_drop_variant_textures.has(variant_key):
		var cached = gem_drop_variant_textures[variant_key]
		if cached is Texture2D:
			return cached

	var variant_path := str(GEM_DROP_VARIANT_TEXTURE_PATHS.get(variant_key, ""))
	var loaded_texture: Texture2D = null
	if variant_path != "":
		loaded_texture = load(variant_path) as Texture2D
	if loaded_texture != null:
		gem_drop_variant_textures[variant_key] = loaded_texture
		return loaded_texture

	return get_item_drop_texture("gem", "currency")


func _get_gem_drop_compound_chunks(amount: float) -> Array:
	var safe_total := _safe_int(round(amount), 0, 0, MAX_DROP_TILE_AMOUNT)
	var chunks: Array = []
	var remaining := safe_total
	while remaining > 0:
		var chunk_amount: int = min(remaining, GEM_DROP_VISUAL_STACK_SIZE)
		chunks.append(chunk_amount)
		remaining -= chunk_amount
	return chunks


func _get_gem_drop_compound_offset(index: int) -> Vector2:
	if index <= 0:
		return Vector2.ZERO

	var base_offset: Vector2 = GEM_DROP_BASE_OFFSETS[index % GEM_DROP_BASE_OFFSETS.size()]
	var ring := int(floor(float(index) / float(GEM_DROP_BASE_OFFSETS.size())))
	var spread := 1.0 + float(ring) * 0.45
	return Vector2(
		round(base_offset.x * spread),
		round(base_offset.y * spread - float(ring) * 2.0)
	)


func _build_drop_visual_sprite(texture: Texture2D, scale: Vector2, position: Vector2, item_category: String, z_index: int = 0) -> Array:
	var parts: Array = []
	if texture == null:
		return parts

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = position
	sprite.scale = scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index

	var shadow := create_drop_texture_shadow(sprite, item_category)
	if shadow != null:
		parts.append(shadow)
	parts.append(sprite)
	return parts


func _rebuild_drop_visuals(drop_data: Dictionary) -> void:
	if drop_data == null or drop_data.is_empty():
		return

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	var visual_root := _ensure_drop_visual_root(drop_node)
	if visual_root == null:
		return
	_clear_drop_visual_root(visual_root)

	var item_type := _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category := _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	drop_data["colour_cycle_drop"] = is_colour_cycle_drop_item(item_type, item_category)
	var sprite_scale := _get_drop_visual_scale(item_category, item_type)

	if _is_gem_drop_item(item_type, item_category):
		var amount := _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), false)
		var chunk_amounts := _get_gem_drop_compound_chunks(amount)
		for i in range(chunk_amounts.size()):
			var gem_texture := _get_gem_drop_variant_texture_for_amount(int(chunk_amounts[i]))
			for part in _build_drop_visual_sprite(gem_texture, sprite_scale, _get_gem_drop_compound_offset(i), item_category, i):
				visual_root.add_child(part)
		return

	var base_texture = get_item_drop_texture(item_type, item_category)
	var visual_parts := _build_drop_visual_sprite(base_texture, sprite_scale, Vector2.ZERO, item_category)
	for part in visual_parts:
		visual_root.add_child(part)

	if not visual_parts.is_empty():
		var base_sprite = visual_parts[visual_parts.size() - 1]
		if base_sprite is Sprite2D:
			update_seed_drop_preview_sprite(base_sprite, item_type, item_category)
			apply_drop_colour_cycle_visual(drop_data)


func remove_seed_drop_preview_sprite(base_sprite: Sprite2D):
	if base_sprite == null:
		return

	var existing = base_sprite.get_node_or_null(SEED_DROP_PREVIEW_NODE_NAME)
	if existing != null:
		base_sprite.remove_child(existing)
		existing.queue_free()


func update_seed_drop_preview_sprite(base_sprite: Sprite2D, item_type: String, item_category: String):
	if base_sprite == null:
		return

	if item_category != "seed":
		remove_seed_drop_preview_sprite(base_sprite)
		return

	if world == null or not world.has_method("get_seed_drop_preview_layout"):
		remove_seed_drop_preview_sprite(base_sprite)
		return

	var layout: Dictionary = world.get_seed_drop_preview_layout(item_type)
	if layout.is_empty():
		remove_seed_drop_preview_sprite(base_sprite)
		return

	var preview_texture = layout.get("preview_texture", null)
	var box_size: Vector2i = layout.get("box_size", Vector2i.ZERO)
	var preview_size: Vector2i = layout.get("preview_size", Vector2i.ZERO)
	var destination: Vector2i = layout.get("destination", Vector2i.ZERO)
	if preview_texture == null or box_size.x <= 0 or box_size.y <= 0 or preview_size.x <= 0 or preview_size.y <= 0:
		remove_seed_drop_preview_sprite(base_sprite)
		return

	var preview_sprite = base_sprite.get_node_or_null(SEED_DROP_PREVIEW_NODE_NAME)
	if preview_sprite == null or not (preview_sprite is Sprite2D):
		if preview_sprite != null:
			base_sprite.remove_child(preview_sprite)
			preview_sprite.queue_free()
		preview_sprite = Sprite2D.new()
		preview_sprite.name = SEED_DROP_PREVIEW_NODE_NAME
		preview_sprite.centered = true
		preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_sprite.z_index = 0
		base_sprite.add_child(preview_sprite)

	preview_sprite.texture = preview_texture
	preview_sprite.position = Vector2(destination) - (Vector2(box_size) * 0.5) + (Vector2(preview_size) * 0.5)
	preview_sprite.scale = Vector2(
		float(preview_size.x) / max(1.0, float(preview_texture.get_width())),
		float(preview_size.y) / max(1.0, float(preview_texture.get_height()))
	)
	preview_sprite.visible = true


func should_create_drop_texture_shadow(item_category: String) -> bool:
	return item_category.strip_edges() != ""


func create_drop_texture_shadow(sprite: Sprite2D, item_category: String) -> Sprite2D:
	if sprite == null or sprite.texture == null:
		return null

	if not should_create_drop_texture_shadow(item_category):
		return null

	var shadow := Sprite2D.new()
	shadow.name = DROP_TEXTURE_SHADOW_NAME
	shadow.texture = sprite.texture
	shadow.centered = sprite.centered
	shadow.scale = sprite.scale
	shadow.position = sprite.position + DROP_TEXTURE_SHADOW_OFFSET
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.modulate = Color(0.0, 0.0, 0.0, DROP_TEXTURE_SHADOW_ALPHA)
	shadow.z_index = -1
	return shadow


func get_database_item_category(item_type: String, fallback_category: String = "item") -> String:
	if world == null:
		return fallback_category

	if world.item_database.has(item_type):
		var category = str(world.item_database[item_type].get("category", fallback_category))

		if category != "":
			return category

	return fallback_category


func format_stack_count(count: int) -> String:
	if count >= 1000000:
		return str(int(floor(float(count) / 1000000.0))) + "m"
	if count >= 10000:
		return str(int(floor(float(count) / 1000.0))) + "k"
	return str(count)


func spawn_item_drop(item_type: String, drop_position: Vector2, is_seed: bool):
	if world == null:
		return

	var final_position = drop_position + Vector2(randf_range(-6, 6), 0)
	create_item_drop(item_type, final_position, is_seed)


func create_item_drop(
	item_type: String,
	item_position: Vector2,
	is_seed: bool,
	item_category: String = "",
	pickup_delay: float = 0.0,
	amount: float = 1.0,
	drop_id: String = "",
	sync_to_server: bool = true
):
	if world == null:
		return

	if should_use_server_authoritative_world_actions():
		if sync_to_server:
			debug_drop_pickup_flow("blocked client-created authoritative drop", {}, {
				"item_type": str(item_type),
				"item_category": str(item_category),
				"amount": amount
			})
			return
		if not applying_server_drop_payload and not is_applying_network_world_update():
			debug_drop_pickup_flow("blocked non-server authoritative drop payload", {}, {
				"item_type": str(item_type),
				"item_category": str(item_category),
				"amount": amount,
				"drop_id": str(drop_id)
			})
			return

	item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return

	item_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	var safe_pickup_delay = _safe_float(pickup_delay, 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
	is_seed = _safe_bool(is_seed, false)
	var has_external_drop_id = drop_id.strip_edges() != ""
	var clean_drop_id = drop_id.strip_edges()
	if clean_drop_id == "":
		clean_drop_id = generate_drop_id()

	if item_category == "":
		if is_seed:
			item_category = "seed"
		else:
			item_category = get_database_item_category(item_type, "")
			if item_category == "":
				if world.block_textures.has(item_type):
					item_category = "block"
				elif world.tool_textures.has(item_type):
					item_category = "tool"
				elif world.currency_textures.has(item_type):
					item_category = "currency"
				elif world.material_textures.has(item_type):
					item_category = "material"
				elif world.lure_textures.has(item_type):
					item_category = "lure"
				elif world.fish_textures.has(item_type):
					item_category = "fish"
				elif world.back_textures.has(item_type):
					item_category = "back"
				elif world.hat_textures.has(item_type):
					item_category = "hat"
				elif world.hair_textures.has(item_type):
					item_category = "hair"
				elif world.eyewear_textures.has(item_type):
					item_category = "eyewear"
				elif world.pants_textures.has(item_type):
					item_category = "pants"
				elif world.shoes_textures.has(item_type):
					item_category = "shoes"
				elif world.ride_textures.has(item_type):
					item_category = "ride"
				else:
					item_category = "item"

	var is_weight_drop: bool = _is_fish_drop_category(item_category)
	var safe_amount: float = _safe_drop_amount(amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)

	var stack_grid = get_drop_stack_grid(item_position)
	var remaining_amount = safe_amount
	if remaining_amount <= 0:
		return

	var existing_stack: Dictionary = get_drop_by_id(clean_drop_id)

	if not existing_stack.is_empty():
		var existing_stack_ids: Array = _get_drop_stack_ids(existing_stack)
		if existing_stack_ids.has(clean_drop_id):
			var current_type = _safe_string(existing_stack.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			var current_category = _safe_string(existing_stack.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			if current_type != item_type or current_category != item_category:
				# If an external packet reuses an ID for a different item type/category,
				# prefer replacing the old drop state instead of spawning a duplicate or
				# silently discarding the incoming payload.
				remove_drop_by_id(clean_drop_id)
				existing_stack = {}
			else:
				if has_external_drop_id and not sync_to_server and is_drop_pickup_pending(existing_stack):
					# A late create/update for a drop that is already being picked up should not
					# cancel the local pickup visual and snap the item back onto the floor.
					debug_drop_pickup_flow("ignored duplicate server create for pending pickup", existing_stack, {
						"drop_id": clean_drop_id
					})
					return

				var current_amount: float = _safe_drop_amount(existing_stack.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
				if has_external_drop_id and not sync_to_server:
					var new_alias_amount: float = _safe_drop_amount(min(MAX_DROP_TILE_AMOUNT, remaining_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
					if existing_stack_ids.size() > 1:
						var previous_alias_amount: float = _get_drop_stack_amount_for_id(existing_stack, clean_drop_id)
						existing_stack["amount"] = _safe_drop_amount(current_amount - previous_alias_amount + new_alias_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
					else:
						existing_stack["amount"] = new_alias_amount
					_remember_drop_stack_amount(existing_stack, clean_drop_id, new_alias_amount)
					existing_stack["drop_id"] = clean_drop_id
					_clear_drop_pickup_flags(existing_stack)
				else:
					var add_amount: float = _safe_drop_amount(remaining_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
					var stack_room: float = max(0.0, float(MAX_DROP_TILE_AMOUNT) - current_amount)
					add_amount = min(add_amount, stack_room)
					existing_stack["amount"] = _safe_drop_amount(min(float(MAX_DROP_TILE_AMOUNT), current_amount + add_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
				existing_stack["x"] = item_position.x
				existing_stack["y"] = item_position.y
				existing_stack["stack_grid_x"] = stack_grid.x
				existing_stack["stack_grid_y"] = stack_grid.y
				existing_stack["is_seed"] = is_seed
				existing_stack["pickup_delay"] = max(
					_safe_float(existing_stack.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS),
					safe_pickup_delay
				)
				sync_drop_node_metadata(existing_stack)
				update_drop_count_label(existing_stack)
				if sync_to_server:
					send_network_drop_update(existing_stack)
				return

	if get_drop_total_amount_on_tile(stack_grid) >= MAX_DROP_TILE_AMOUNT:
		return

	var created_stack_for_drop_id = false
	var should_merge_into_existing_stack = true
	while remaining_amount > 0:
		var merge_stack = get_mergeable_drop_stack(item_type, item_category, stack_grid) if should_merge_into_existing_stack else {}
		if not merge_stack.is_empty():
			if not created_stack_for_drop_id:
				created_stack_for_drop_id = true
			var added = _add_to_existing_drop_stack(merge_stack, remaining_amount)
			if added <= 0:
				break

			if has_external_drop_id:
				add_drop_stack_id(merge_stack, clean_drop_id, added, true)
			remaining_amount -= added
			merge_stack["pickup_delay"] = max(_safe_float(merge_stack.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS), safe_pickup_delay)
			sync_drop_node_metadata(merge_stack)
			update_drop_count_label(merge_stack)
			if sync_to_server:
				send_network_drop_update(merge_stack)

			continue

		var tile_room = get_drop_remaining_capacity_on_tile(stack_grid)
		if tile_room <= 0:
			return

		var next_stack_amount = min(remaining_amount, MAX_DROP_TILE_AMOUNT, tile_room)
		if next_stack_amount <= 0:
			return

		var stack_drop_id = clean_drop_id
		if created_stack_for_drop_id or sync_to_server:
			stack_drop_id = generate_drop_id()
		created_stack_for_drop_id = true

		_create_single_drop(
			item_type,
			item_category,
			stack_drop_id,
			next_stack_amount,
			item_position,
			stack_grid,
			safe_pickup_delay,
			sync_to_server
		)
		remaining_amount -= next_stack_amount


func get_drop_stack_grid(item_position: Vector2) -> Vector2i:
	if world == null:
		return Vector2i.ZERO

	var safe_x = _safe_float(item_position.x, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
	var safe_y = _safe_float(item_position.y, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)

	return Vector2i(
		_safe_int(round(safe_x / world.BLOCK_SIZE), 0, 0, max(world.WORLD_WIDTH - 1, 0)),
		_safe_int(round(safe_y / world.BLOCK_SIZE), 0, 0, max(world.WORLD_HEIGHT - 1, 0))
	)


func get_drop_visual_position(stack_grid: Vector2i, stack_index: int) -> Vector2:
	if world == null:
		return Vector2.ZERO

	var offsets = [Vector2(0, 0), Vector2(-9, -4), Vector2(9, -4), Vector2(-9, 6), Vector2(9, 6), Vector2(0, -10), Vector2(-14, 0), Vector2(14, 0), Vector2(-12, -12), Vector2(12, -12), Vector2(-6, 12), Vector2(6, 12), Vector2(0, -14)]
	var offset = offsets[stack_index % offsets.size()]
	return Vector2(stack_grid.x * world.BLOCK_SIZE, stack_grid.y * world.BLOCK_SIZE) + offset


func get_existing_drop_stack(item_type: String, item_category: String, stack_grid: Vector2i):
	if world == null:
		return null

	var cell_drops: Array = drops_by_cell.get(get_drop_cell_key(stack_grid), [])

	for drop_data in cell_drops:
		var drop_node = drop_data.get("node", null)

		if not is_instance_valid(drop_node):
			continue

		if str(drop_data.get("item_type", "")) != item_type:
			continue

		if str(drop_data.get("item_category", "")) != item_category:
			continue

		if _safe_int(drop_data.get("stack_grid_x", 999999), 0, 0, 999999) != stack_grid.x:
			continue

		if _safe_int(drop_data.get("stack_grid_y", 999999), 0, 0, 999999) != stack_grid.y:
			continue

		return drop_data

	return {}


func get_mergeable_drop_stack(item_type: String, item_category: String, stack_grid: Vector2i) -> Dictionary:
	if world == null:
		return {}

	var cell_drops = _get_cell_drops(stack_grid)
	for drop_data in cell_drops:
		var drop_node = drop_data.get("node", null)

		if not is_instance_valid(drop_node):
			continue

		if str(drop_data.get("item_type", "")) != item_type:
			continue

		if str(drop_data.get("item_category", "")) != item_category:
			continue

		var is_weight: bool = _is_fish_drop_category(item_category)
		var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
		if current_amount >= float(MAX_DROP_TILE_AMOUNT):
			continue

		return drop_data

	return {}


func _add_to_existing_drop_stack(drop_data: Dictionary, amount_to_add: float) -> float:
	if world == null or drop_data.is_empty():
		return 0

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_weight: bool = _is_fish_drop_category(item_category)
	var _stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if _stack_limit <= 0:
		return 0

	var amount: float = _safe_drop_amount(amount_to_add, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if amount <= 0:
		return 0

	var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	var stack_grid = get_drop_cell_from_data(drop_data)
	var tile_total_without_stack: float = maxf(0.0, get_drop_total_amount_on_tile(stack_grid) - current_amount)
	var tile_room: float = maxf(0.0, float(MAX_DROP_TILE_AMOUNT) - tile_total_without_stack)
	var stack_room: float = maxf(0.0, float(MAX_DROP_TILE_AMOUNT) - current_amount)
	var add_amount: float = _safe_drop_amount(min(amount, tile_room, stack_room), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)

	if add_amount <= 0:
		return 0

	drop_data["amount"] = _safe_drop_amount(current_amount + add_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	return add_amount


func _create_single_drop(
	item_type: String,
	item_category: String,
	clean_drop_id: String,
	amount: float,
	item_position: Vector2,
	stack_grid: Vector2i,
	pickup_delay: float,
	sync_to_server: bool
) -> void:
	var item_stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if item_stack_limit <= 0:
		return

	var amount_to_create: float = snapped(max(0.1, float(amount)), 0.1) if item_category == "fish" else float(_safe_int(amount, 1, 1, MAX_DROP_TILE_AMOUNT))
	if amount_to_create <= 0:
		return

	var same_tile_stack_count = get_drop_stack_count_on_tile(stack_grid)
	var visual_position = item_position
	var use_exact_visual_position = not sync_to_server and clean_drop_id != ""
	if not use_exact_visual_position:
		visual_position = get_drop_visual_position(stack_grid, same_tile_stack_count)

	var drop = Node2D.new()
	drop.name = "Drop_" + item_type + "_" + clean_drop_id
	drop.global_position = visual_position

	drop.z_index = DROP_WORLD_Z_INDEX

	world.add_child(drop)

	var initial_stack_amounts: Dictionary = {}
	initial_stack_amounts[clean_drop_id] = amount_to_create

	var drop_data = {
		"node": drop,
		"drop_id": clean_drop_id,
		"drop_stack_ids": [clean_drop_id],
		"drop_stack_amounts": initial_stack_amounts,
		"item_type": item_type,
		"item_category": item_category,
		"is_seed": item_category == "seed",
		"amount": amount_to_create,
		"x": visual_position.x,
		"y": visual_position.y,
		"stack_grid_x": stack_grid.x,
		"stack_grid_y": stack_grid.y,
		"pickup_delay": pickup_delay,
		"age": 0.0,
		"start_y": drop.position.y,
		"bob_offset": randf() * TAU
	}

	create_drop_count_controls(drop_data)
	world.dropped_items.append(drop_data)
	register_drop(drop_data)
	update_drop_count_label(drop_data)

	if sync_to_server:
		send_network_drop_create(drop_data)


func get_drop_stack_count_on_tile(stack_grid: Vector2i) -> int:
	if world == null:
		return 0

	var count = 0
	var cell_drops: Array = drops_by_cell.get(get_drop_cell_key(stack_grid), [])

	for drop_data in cell_drops:
		var drop_node = drop_data.get("node", null)

		if not is_instance_valid(drop_node):
			continue

		count += 1

	return count


func should_show_drop_count_label(drop_data: Dictionary, amount: float) -> bool:
	if amount <= 1.0:
		return false
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
	if _is_gem_drop_item(_safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH), item_category):
		return false

	return true


func update_drop_count_label(drop_data):
	var drop_node = drop_data.get("node", null)

	if not is_instance_valid(drop_node):
		remove_drop_count_controls(drop_data)
		return

	var stale_badge = drop_data.get("count_badge_ui", null)
	if is_instance_valid(stale_badge):
		stale_badge.queue_free()
	drop_data.erase("count_badge_ui")

	var count_label = drop_data.get("count_label_ui", null)

	if not is_instance_valid(count_label):
		create_drop_count_controls(drop_data)
		count_label = drop_data.get("count_label_ui", null)

	if not is_instance_valid(count_label):
		return

	var is_weight: bool = _is_fish_drop_category(str(drop_data.get("item_category", "")))
	var amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	var count_text: String = ""
	if is_weight and should_show_drop_count_label(drop_data, amount):
		count_text = format_stack_count(int(round(amount)))
	elif should_show_drop_count_label(drop_data, amount):
		count_text = format_stack_count(int(round(amount)))
	count_label.text = count_text
	count_label.visible = count_text != ""

	if count_text != "":
		update_drop_count_screen_position(drop_data)


func get_drop_count_world_position(_drop_data: Dictionary, drop_node) -> Vector2:
	return drop_node.global_position + DROP_COUNT_WORLD_OFFSET


func update_drop_count_screen_position(drop_data: Dictionary):
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node) or not (drop_node is Node2D):
		remove_drop_count_controls(drop_data)
		return

	var count_label = drop_data.get("count_label_ui", null)
	if not is_instance_valid(count_label):
		update_drop_count_label(drop_data)
		count_label = drop_data.get("count_label_ui", null)
		if not is_instance_valid(count_label):
			return

	if not count_label.visible:
		return

	if count_label.get_parent() != drop_node:
		count_label.reparent(drop_node, false)

	var viewport: Viewport = count_label.get_viewport()
	if viewport == null:
		return

	var drop_node_2d := drop_node as Node2D
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var screen_scale: float = get_drop_count_screen_scale()
	var label_screen_size: Vector2 = DROP_COUNT_LABEL_SIZE * screen_scale
	var screen_position: Vector2 = canvas_transform * get_drop_count_world_position(drop_data, drop_node_2d)
	var top_left_screen := Vector2(
		round(screen_position.x - label_screen_size.x * 0.5),
		round(screen_position.y)
	)
	var top_left_world: Vector2 = canvas_transform.affine_inverse() * top_left_screen
	var canvas_scale_x := maxf(canvas_transform.x.length(), 0.001)
	var canvas_scale_y := maxf(canvas_transform.y.length(), 0.001)
	var parent_scale_x := maxf(absf(drop_node_2d.global_scale.x), 0.001)
	var parent_scale_y := maxf(absf(drop_node_2d.global_scale.y), 0.001)

	count_label.size = DROP_COUNT_LABEL_SIZE
	count_label.position = drop_node_2d.to_local(top_left_world)
	count_label.rotation = -drop_node_2d.global_rotation
	count_label.scale = Vector2(
		screen_scale / (canvas_scale_x * parent_scale_x),
		screen_scale / (canvas_scale_y * parent_scale_y)
	)
	count_label.z_as_relative = false
	count_label.z_index = DROP_COUNT_WORLD_Z_INDEX
	if int(count_label.get_meta("drop_font_size", -1)) != DROP_COUNT_BASE_FONT_SIZE:
		count_label.add_theme_font_size_override("font_size", DROP_COUNT_BASE_FONT_SIZE)
		count_label.set_meta("drop_font_size", DROP_COUNT_BASE_FONT_SIZE)
	if int(count_label.get_meta("drop_outline_size", -1)) != DROP_COUNT_BASE_OUTLINE_SIZE:
		count_label.add_theme_constant_override("outline_size", DROP_COUNT_BASE_OUTLINE_SIZE)
		count_label.set_meta("drop_outline_size", DROP_COUNT_BASE_OUTLINE_SIZE)
	if not is_equal_approx(count_label.modulate.a, 1.0):
		count_label.modulate.a = 1.0


func is_drop_stack_covered(drop_data) -> bool:
	if world == null:
		return false

	var stack_grid = Vector2i(
		_safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999),
		_safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
	)
	if not world.blocks.has(stack_grid):
		return false

	var block_data = world.blocks.get(stack_grid, {})
	var block_type := ""
	if block_data is Dictionary:
		block_type = _safe_string(block_data.get("type", block_data.get("block_type", "")), "", MAX_ITEM_ID_LENGTH).to_lower()

	if block_type == "":
		return true

	if world.item_database.has(block_type):
		var item_data: Dictionary = world.item_database[block_type]
		if bool(item_data.get("occupies_collision_area", false)):
			return true
		if item_data.has("collidable"):
			return bool(item_data.get("collidable", true))
		if item_data.has("no_collision"):
			return not bool(item_data.get("no_collision", false))

	if world.has_method("is_non_collideable_block") and bool(world.is_non_collideable_block(block_type)):
		return false

	return true


func get_inventory_target_for_drop(item_type: String, item_category: String) -> Dictionary:
	if world == null:
		return {}

	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_item_type == "":
		return {}

	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
	var database_category = ""
	if world.item_database.has(safe_item_type):
		database_category = _safe_string(world.item_database[safe_item_type].get("category", ""), "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
	if database_category != "":
		safe_category = database_category

	var target = _inventory_target_for_category(safe_category)
	if not target.is_empty():
		var target_inventory = target.get("inventory", {})
		if _is_known_item_for_inventory(safe_item_type, safe_category, target_inventory):
			return target
		return {}

	# Fallback for legacy/local compatibility where database route is unavailable.
	if world.seed_inventory.has(safe_item_type):
		return {"inventory": world.seed_inventory, "category": "seed"}
	if world.tool_inventory.has(safe_item_type):
		return {"inventory": world.tool_inventory, "category": "tool"}
	if world.currency_inventory.has(safe_item_type):
		return {"inventory": world.currency_inventory, "category": "currency"}
	if world.material_inventory.has(safe_item_type):
		return {"inventory": world.material_inventory, "category": "material"}
	if world.lure_inventory.has(safe_item_type):
		return {"inventory": world.lure_inventory, "category": "lure"}
	if world.fish_inventory.has(safe_item_type):
		return {"inventory": world.fish_inventory, "category": "fish"}
	if world.back_inventory.has(safe_item_type):
		return {"inventory": world.back_inventory, "category": "back"}
	if world.hat_inventory.has(safe_item_type):
		return {"inventory": world.hat_inventory, "category": "hat"}
	if world.hair_inventory.has(safe_item_type):
		return {"inventory": world.hair_inventory, "category": "hair"}
	if world.eyewear_inventory.has(safe_item_type):
		return {"inventory": world.eyewear_inventory, "category": "eyewear"}
	if world.shirt_inventory.has(safe_item_type):
		return {"inventory": world.shirt_inventory, "category": "shirt"}
	if world.pants_inventory.has(safe_item_type):
		return {"inventory": world.pants_inventory, "category": "pants"}
	if world.shoes_inventory.has(safe_item_type):
		return {"inventory": world.shoes_inventory, "category": "shoes"}
	if world.ride_inventory.has(safe_item_type):
		return {"inventory": world.ride_inventory, "category": "ride"}
	if world.inventory.has(safe_item_type):
		return {"inventory": world.inventory, "category": "block"}

	return {}


func _inventory_target_for_category(category: String) -> Dictionary:
	match category:
		"seed":
			return {"inventory": world.seed_inventory, "category": "seed"}
		"tool":
			return {"inventory": world.tool_inventory, "category": "tool"}
		"currency":
			return {"inventory": world.currency_inventory, "category": "currency"}
		"material":
			return {"inventory": world.material_inventory, "category": "material"}
		"lure":
			return {"inventory": world.lure_inventory, "category": "lure"}
		"fish":
			return {"inventory": world.fish_inventory, "category": "fish"}
		"back":
			return {"inventory": world.back_inventory, "category": "back"}
		"hat":
			return {"inventory": world.hat_inventory, "category": "hat"}
		"hair":
			return {"inventory": world.hair_inventory, "category": "hair"}
		"eyewear":
			return {"inventory": world.eyewear_inventory, "category": "eyewear"}
		"shirt":
			return {"inventory": world.shirt_inventory, "category": "shirt"}
		"pants":
			return {"inventory": world.pants_inventory, "category": "pants"}
		"shoes":
			return {"inventory": world.shoes_inventory, "category": "shoes"}
		"ride":
			return {"inventory": world.ride_inventory, "category": "ride"}
		"block":
			return {"inventory": world.inventory, "category": "block"}

	return {}


func _is_known_item_for_inventory(item_type: String, category: String, inventory: Dictionary) -> bool:
	if world == null or item_type == "" or not (inventory is Dictionary):
		return false

	if world.item_database.has(item_type):
		var database_category = _safe_string(world.item_database[item_type].get("category", ""), "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
		if database_category != "" and database_category != category:
			return false
		return true

	return inventory.has(item_type)
func _clean_drop_inventory_category(item_type: String, item_category: String = "") -> String:
	var safe_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_type == "":
		return ""

	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	var target = get_inventory_target_for_drop(safe_type, safe_category)
	if target.is_empty():
		return ""

	return _safe_string(target.get("category", safe_category), safe_category, MAX_ITEM_CATEGORY_LENGTH)


func _resolve_inventory_slot_for_drop(item_type: String, item_category: String) -> Dictionary:
	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_item_type == "":
		return {}

	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	var target = get_inventory_target_for_drop(safe_item_type, safe_category)
	if target.is_empty():
		return {}

	var target_inventory = target.get("inventory", {})
	if not (target_inventory is Dictionary):
		return {}

	var target_category = _safe_string(target.get("category", safe_category), safe_category, MAX_ITEM_CATEGORY_LENGTH)
	if target_category == "" or not _is_known_item_for_inventory(safe_item_type, target_category, target_inventory):
		return {}

	return {"inventory": target_inventory, "category": target_category}


func _clear_drop_pickup_flags(drop_data: Dictionary) -> void:
	if drop_data == null or drop_data.is_empty():
		return

	drop_data["pickup_requested"] = false
	drop_data["pickup_requested_age"] = 0.0
	drop_data["pickup_in_progress"] = false
	drop_data.erase("pickup_requested_amount")
	drop_data.erase("pickup_requested_by")
	drop_data.erase("pickup_requested_drop_id")
	drop_data.erase("pickup_request_ms")
	drop_data.erase("pickup_request_sent")
	drop_data.erase("pickup_blocked_until_ms")


func _block_drop_pickup_retry(drop_data: Dictionary, cooldown_seconds: float) -> void:
	if drop_data == null or drop_data.is_empty():
		return
	if cooldown_seconds <= 0.0:
		return

	drop_data["pickup_blocked_until_ms"] = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)


func _reject_pending_drop_pickup(drop_data: Dictionary, cooldown_seconds: float = DROP_PICKUP_REJECT_RETRY_COOLDOWN) -> void:
	if drop_data == null or drop_data.is_empty():
		return

	_clear_drop_pickup_flags(drop_data)
	_block_drop_pickup_retry(drop_data, cooldown_seconds)
	restore_drop_pickup_visual(drop_data)


func reset_drop_pickup_send_budget() -> void:
	drop_pickup_send_tokens = DROP_PICKUP_SEND_BURST
	drop_pickup_token_refill_ms = Time.get_ticks_msec()


func refill_drop_pickup_send_budget() -> void:
	var now_ms := Time.get_ticks_msec()
	if drop_pickup_token_refill_ms <= 0:
		drop_pickup_token_refill_ms = now_ms
		drop_pickup_send_tokens = DROP_PICKUP_SEND_BURST
		return

	var elapsed_seconds: float = max(0.0, float(now_ms - drop_pickup_token_refill_ms) / 1000.0)
	if elapsed_seconds <= 0.0:
		return

	drop_pickup_send_tokens = min(DROP_PICKUP_SEND_BURST, drop_pickup_send_tokens + elapsed_seconds * DROP_PICKUP_SEND_RATE_PER_SECOND)
	drop_pickup_token_refill_ms = now_ms


func try_consume_drop_pickup_send_token() -> bool:
	refill_drop_pickup_send_budget()
	if drop_pickup_send_tokens < 1.0:
		return false

	drop_pickup_send_tokens -= 1.0
	return true


func get_server_pickups_in_flight() -> int:
	if world == null:
		return 0

	var count := 0
	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)):
			count += 1

	return count


func get_server_pickup_request_count() -> int:
	if world == null:
		return 0

	var count := 0
	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)):
			count += 1

	return count


func get_drop_pickup_debug_stats() -> Dictionary:
	refill_drop_pickup_send_budget()
	var stats := {
		"requested": 0,
		"queued": 0,
		"in_flight": 0,
		"sent": 0,
		"blocked": 0,
		"pending_stacks": 0,
		"send_tokens": drop_pickup_send_tokens,
		"max_in_flight": DROP_MAX_SERVER_PICKUPS_IN_FLIGHT,
		"max_queue": DROP_MAX_SERVER_PICKUP_QUEUE,
		"send_rate": DROP_PICKUP_SEND_RATE_PER_SECOND,
		"busy_ms": max(0, drop_pickup_busy_until_ms - Time.get_ticks_msec()),
		"debug_reason": _safe_string(drop_pickup_debug_nearest.get("reason", ""), "", 64),
		"debug_drop_id": _safe_string(drop_pickup_debug_nearest.get("drop_id", ""), "", MAX_DROP_ID_LENGTH),
		"debug_item_type": _safe_string(drop_pickup_debug_nearest.get("item_type", ""), "", MAX_ITEM_ID_LENGTH),
		"debug_distance_px": float(drop_pickup_debug_nearest.get("distance_px", -1.0)),
		"debug_range_px": float(drop_pickup_debug_nearest.get("range_px", 0.0)),
		"debug_nearest": drop_pickup_debug_nearest.duplicate(true),
		"debug_skip_counts": drop_pickup_debug_scan_counts.duplicate(true)
	}
	if world == null:
		return stats

	var pending_stack_keys := {}
	var now_ms := Time.get_ticks_msec()
	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		var is_requested := bool(drop_data.get("pickup_requested", false))
		var is_in_progress := bool(drop_data.get("pickup_in_progress", false))
		var is_request_sent := bool(drop_data.get("pickup_request_sent", false))
		if is_requested:
			stats["requested"] = int(stats["requested"]) + 1
			var item_type := _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			var item_category := _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			var target := get_inventory_target_for_drop(item_type, item_category)
			var target_category := _safe_string(target.get("category", item_category), item_category, MAX_ITEM_CATEGORY_LENGTH) if not target.is_empty() else item_category
			if item_type != "" and target_category != "":
				pending_stack_keys[target_category + ":" + item_type] = true
		if is_in_progress or is_request_sent:
			stats["in_flight"] = int(stats["in_flight"]) + 1
		elif is_requested:
			stats["queued"] = int(stats["queued"]) + 1
		if is_request_sent:
			stats["sent"] = int(stats["sent"]) + 1
		if int(drop_data.get("pickup_blocked_until_ms", 0)) > now_ms:
			stats["blocked"] = int(stats["blocked"]) + 1

	stats["pending_stacks"] = pending_stack_keys.size()
	return stats


func mark_drop_pickup_requested(drop_data: Dictionary, pickup_amount: float) -> void:
	drop_data["pickup_requested"] = true
	drop_data["pickup_requested_age"] = 0.0
	drop_data["pickup_requested_amount"] = pickup_amount
	drop_data["pickup_in_progress"] = false
	drop_data.erase("pickup_requested_by")
	drop_data.erase("pickup_requested_drop_id")
	drop_data.erase("pickup_request_ms")
	drop_data.erase("pickup_request_sent")
	apply_pending_pickup_visual(drop_data)


func cancel_queued_drop_pickup(drop_data: Dictionary, cooldown_seconds: float = 0.0) -> void:
	if drop_data == null or drop_data.is_empty():
		return

	_clear_drop_pickup_flags(drop_data)
	if cooldown_seconds > 0.0:
		drop_data["pickup_blocked_until_ms"] = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)
	restore_drop_pickup_visual(drop_data)


func try_send_queued_drop_pickup(drop_data: Dictionary) -> bool:
	if world == null or not should_use_server_authoritative_world_actions():
		return false
	if not bool(drop_data.get("pickup_requested", false)):
		return false
	var player_position: Vector2 = world.player.global_position if world.player != null else Vector2.ZERO
	var pickup_range_sq := float(world.PICKUP_RANGE * world.PICKUP_RANGE)
	if bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)):
		record_drop_pickup_debug("already_in_flight", drop_data, player_position, pickup_range_sq)
		return false
	if not is_queued_drop_pickup_still_reachable(drop_data):
		record_drop_pickup_debug("queued_unreachable", drop_data, player_position, pickup_range_sq)
		cancel_queued_drop_pickup(drop_data, DROP_PICKUP_UNREACHABLE_RETRY_COOLDOWN)
		return false
	if get_server_pickups_in_flight() >= DROP_MAX_SERVER_PICKUPS_IN_FLIGHT:
		record_drop_pickup_debug("in_flight_limit", drop_data, player_position, pickup_range_sq)
		return false
	if not try_consume_drop_pickup_send_token():
		record_drop_pickup_debug("send_token_empty", drop_data, player_position, pickup_range_sq)
		return false

	var pickup_batch: Array = get_same_tile_queued_pickup_batch(drop_data)
	if pickup_batch.size() > 1:
		if not send_network_drop_pickup_bulk(pickup_batch):
			record_drop_pickup_debug("send_failed", drop_data, player_position, pickup_range_sq, {
				"bulk_count": pickup_batch.size()
			})
			var retry_ms := Time.get_ticks_msec() + int(DROP_PICKUP_BUSY_RETRY_COOLDOWN * 1000.0)
			for raw_pending in pickup_batch:
				if raw_pending is Dictionary:
					var pending_drop: Dictionary = raw_pending
					_clear_drop_pickup_flags(pending_drop)
					pending_drop["pickup_blocked_until_ms"] = retry_ms
					restore_drop_pickup_visual(pending_drop)
			return false

		record_drop_pickup_debug("sent_bulk_to_server", drop_data, player_position, pickup_range_sq, {
			"bulk_count": pickup_batch.size()
		})
		return true

	drop_data["pickup_in_progress"] = true
	drop_data["pickup_requested_age"] = 0.0
	if not send_network_drop_pickup(drop_data):
		record_drop_pickup_debug("send_failed", drop_data, player_position, pickup_range_sq)
		_clear_drop_pickup_flags(drop_data)
		restore_drop_pickup_visual(drop_data)
		return false

	record_drop_pickup_debug("sent_to_server", drop_data, player_position, pickup_range_sq)
	return true


func cancel_unreachable_queued_drop_pickups() -> int:
	if world == null:
		return 0

	var canceled_count := 0
	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if not bool(drop_data.get("pickup_requested", false)):
			continue
		if bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)):
			continue
		if is_queued_drop_pickup_still_reachable(drop_data):
			continue

		var player_position: Vector2 = world.player.global_position if world.player != null else Vector2.ZERO
		record_drop_pickup_debug("queued_unreachable", drop_data, player_position, float(world.PICKUP_RANGE * world.PICKUP_RANGE))
		cancel_queued_drop_pickup(drop_data, DROP_PICKUP_UNREACHABLE_RETRY_COOLDOWN)
		canceled_count += 1

	return canceled_count


func process_queued_drop_pickups(force: bool = false) -> int:
	if world == null or not should_use_server_authoritative_world_actions():
		return 0

	var now_ms := Time.get_ticks_msec()
	if not force and now_ms < drop_queued_pickup_next_process_ms:
		return 0
	drop_queued_pickup_next_process_ms = now_ms + DROP_QUEUE_PROCESS_INTERVAL_MS

	cancel_unreachable_queued_drop_pickups()
	if Time.get_ticks_msec() < drop_pickup_busy_until_ms:
		return 0

	var sent_count := 0
	var in_flight_count := get_server_pickups_in_flight()
	while in_flight_count < DROP_MAX_SERVER_PICKUPS_IN_FLIGHT:
		var queued_drop: Dictionary = {}
		for raw_drop_data in world.dropped_items:
			if not (raw_drop_data is Dictionary):
				continue

			var drop_data: Dictionary = raw_drop_data
			if not bool(drop_data.get("pickup_requested", false)):
				continue
			if bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)):
				continue
			if not is_queued_drop_pickup_still_reachable(drop_data):
				cancel_queued_drop_pickup(drop_data, DROP_PICKUP_UNREACHABLE_RETRY_COOLDOWN)
				continue

			queued_drop = drop_data
			break

		if queued_drop.is_empty():
			break
		if not try_send_queued_drop_pickup(queued_drop):
			break
		sent_count += 1
		in_flight_count = get_server_pickups_in_flight()

	return sent_count


func _get_payload_drop_ids(payloads: Array) -> Array:
	var result: Array = []
	for raw_payload in payloads:
		if not (raw_payload is Dictionary):
			continue
		var payload: Dictionary = raw_payload
		var clean_drop_id: String = _safe_string(payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if clean_drop_id != "":
			result.append(clean_drop_id)
	return result


func apply_pending_pickup_visual(drop_data: Dictionary) -> void:
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	var count_label = drop_data.get("count_label_ui", null)
	if is_instance_valid(count_label):
		count_label.visible = false

	if not bool(drop_data.get("pickup_vacuum_active", false)):
		var start_alpha: float = clampf(drop_node.modulate.a, 0.0, 1.0)
		drop_data["pickup_vacuum_active"] = true
		drop_data["pickup_vacuum_elapsed"] = 0.0
		drop_data["pickup_vacuum_start_position"] = drop_node.global_position
		drop_data["pickup_vacuum_start_scale"] = drop_node.scale
		drop_data["pickup_vacuum_start_alpha"] = maxf(start_alpha, 0.85)
		drop_data["pickup_vacuum_start_rotation"] = drop_node.rotation
		drop_data["pickup_vacuum_spin_direction"] = -1.0 if randf() < 0.5 else 1.0

	var start_scale_value = drop_data.get("pickup_vacuum_start_scale", drop_node.scale)
	var start_scale: Vector2 = start_scale_value if start_scale_value is Vector2 else drop_node.scale
	drop_node.scale = start_scale * DROP_PICKUP_VACUUM_START_POP_SCALE
	drop_node.modulate.a = float(drop_data.get("pickup_vacuum_start_alpha", 1.0))
	update_drop_count_screen_position(drop_data)


func get_drop_pickup_vacuum_target_position(drop_data: Dictionary, fallback_position: Vector2) -> Vector2:
	var cached_target = drop_data.get("pickup_vacuum_target_position", null)
	if cached_target is Vector2:
		var cached_target_position: Vector2 = cached_target
		if abs(cached_target_position.x) < 9.9e19 and abs(cached_target_position.y) < 9.9e19 and is_finite(cached_target_position.x) and is_finite(cached_target_position.y):
			return cached_target_position

	if world != null and world.has_method("get_drop_pickup_vacuum_world_target_position"):
		var item_type: String = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		var item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var resolved_category: String = _clean_drop_inventory_category(item_type, item_category)
		if resolved_category != "":
			item_category = resolved_category
		var ui_target_value = world.get_drop_pickup_vacuum_world_target_position(item_type, item_category, fallback_position)
		if ui_target_value is Vector2:
			var ui_target: Vector2 = ui_target_value
			if abs(ui_target.x) < 9.9e19 and abs(ui_target.y) < 9.9e19 and is_finite(ui_target.x) and is_finite(ui_target.y):
				drop_data["pickup_vacuum_target_position"] = ui_target
				return ui_target

	if world != null and world.player != null:
		var player_target: Vector2 = world.player.global_position + DROP_PICKUP_VACUUM_TARGET_OFFSET
		drop_data["pickup_vacuum_target_position"] = player_target
		return player_target
	drop_data["pickup_vacuum_target_position"] = fallback_position
	return fallback_position


func get_drop_world_position_for_pickup(drop_data: Dictionary) -> Vector2:
	var start_position_value = drop_data.get("pickup_vacuum_start_position", null)
	if start_position_value is Vector2 and is_finite(start_position_value.x) and is_finite(start_position_value.y):
		return start_position_value

	var data_position = Vector2(
		_safe_float(drop_data.get("x", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		_safe_float(drop_data.get("y", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
	)
	if is_finite(data_position.x) and is_finite(data_position.y):
		return data_position

	var drop_node = drop_data.get("node", null)
	if is_instance_valid(drop_node):
		return drop_node.global_position

	return Vector2.ZERO


func is_queued_drop_pickup_still_reachable(drop_data: Dictionary) -> bool:
	if world == null or world.player == null:
		return false

	var drop_position := get_drop_world_position_for_pickup(drop_data)
	var pickup_range_sq := float(world.PICKUP_RANGE * world.PICKUP_RANGE)
	return world.player.global_position.distance_squared_to(drop_position) <= pickup_range_sq


func animate_drop_pickup_vacuum(drop_data: Dictionary, target_position: Vector2, delta: float) -> void:
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	if not bool(drop_data.get("pickup_vacuum_active", false)):
		apply_pending_pickup_visual(drop_data)

	var elapsed: float = _safe_float(drop_data.get("pickup_vacuum_elapsed", 0.0), 0.0, 0.0, DROP_PICKUP_REQUEST_TIMEOUT * 2.0) + delta
	drop_data["pickup_vacuum_elapsed"] = elapsed

	var progress: float = clampf(elapsed / maxf(DROP_PICKUP_VACUUM_DURATION, 0.01), 0.0, 1.0)
	var eased_progress: float = (1.0 - cos(progress * PI)) * 0.5

	var start_position_value = drop_data.get("pickup_vacuum_start_position", drop_node.global_position)
	var start_position: Vector2 = start_position_value if start_position_value is Vector2 else drop_node.global_position
	var arc_offset := Vector2(0.0, -sin(progress * PI) * DROP_PICKUP_VACUUM_ARC_HEIGHT)
	drop_node.global_position = start_position.lerp(target_position, eased_progress) + arc_offset

	var start_scale_value = drop_data.get("pickup_vacuum_start_scale", Vector2.ONE)
	var start_scale: Vector2 = start_scale_value if start_scale_value is Vector2 else Vector2.ONE
	drop_node.scale = start_scale.lerp(DROP_PICKUP_REQUEST_SCALE, eased_progress)

	var start_alpha: float = _safe_float(drop_data.get("pickup_vacuum_start_alpha", 1.0), 1.0, 0.0, 1.0)
	drop_node.modulate.a = lerpf(start_alpha, DROP_PICKUP_REQUEST_ALPHA, eased_progress)

	var start_rotation: float = _safe_float(drop_data.get("pickup_vacuum_start_rotation", drop_node.rotation), drop_node.rotation, -TAU * 32.0, TAU * 32.0)
	var spin_direction: float = -1.0 if _safe_float(drop_data.get("pickup_vacuum_spin_direction", 1.0), 1.0, -1.0, 1.0) < 0.0 else 1.0
	drop_node.rotation = start_rotation + deg_to_rad(DROP_PICKUP_VACUUM_SPIN_DEGREES) * spin_direction * eased_progress
	update_drop_count_screen_position(drop_data)


func clear_drop_pickup_vacuum_state(drop_data: Dictionary) -> void:
	drop_data.erase("pickup_vacuum_active")
	drop_data.erase("pickup_vacuum_elapsed")
	drop_data.erase("pickup_vacuum_start_position")
	drop_data.erase("pickup_vacuum_start_scale")
	drop_data.erase("pickup_vacuum_start_alpha")
	drop_data.erase("pickup_vacuum_start_rotation")
	drop_data.erase("pickup_vacuum_spin_direction")
	drop_data.erase("pickup_vacuum_target_position")


func reset_drop_pickup_frame_budgets() -> void:
	drop_pickup_finish_visuals_this_frame = 0
	drop_pickup_vacuum_updates_this_frame = 0


func can_play_drop_pickup_finish_visual() -> bool:
	if DROP_MAX_PICKUP_FINISH_VISUALS_PER_FRAME <= 0:
		return false
	if drop_pickup_finish_visuals_this_frame >= DROP_MAX_PICKUP_FINISH_VISUALS_PER_FRAME:
		return false
	drop_pickup_finish_visuals_this_frame += 1
	return true


func can_update_drop_pickup_vacuum_visual() -> bool:
	if DROP_MAX_PICKUP_VACUUM_UPDATES_PER_FRAME <= 0:
		return false
	if drop_pickup_vacuum_updates_this_frame >= DROP_MAX_PICKUP_VACUUM_UPDATES_PER_FRAME:
		return false
	drop_pickup_vacuum_updates_this_frame += 1
	return true


func finish_drop_pickup_vacuum_node(drop_data: Dictionary, target_position: Vector2 = Vector2(1.0e20, 1.0e20)) -> void:
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	# Mass pickup can otherwise create hundreds of tweens and feedback calls.
	# Play only a few visible fly-to-inventory effects per frame; instantly free
	# the rest. The inventory data has already been applied before this point.
	if not can_play_drop_pickup_finish_visual():
		drop_node.queue_free()
		return

	var final_target: Vector2 = target_position
	if abs(final_target.x) >= 9.9e19 or abs(final_target.y) >= 9.9e19 or not is_finite(final_target.x) or not is_finite(final_target.y):
		final_target = get_drop_pickup_vacuum_target_position(drop_data, drop_node.global_position)

	var item_type: String = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var resolved_category: String = _clean_drop_inventory_category(item_type, item_category)
	if resolved_category != "":
		item_category = resolved_category
	var tween = drop_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(drop_node, "global_position", final_target, DROP_PICKUP_VACUUM_FINISH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(drop_node, "scale", Vector2(0.30, 0.30), DROP_PICKUP_VACUUM_FINISH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(drop_node, "modulate:a", 0.0, DROP_PICKUP_VACUUM_FINISH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(Callable(self, "_finish_drop_pickup_vacuum").bind(drop_node, item_type, item_category))


func _finish_drop_pickup_vacuum(drop_node, item_type: String, item_category: String) -> void:
	if world != null and world.has_method("play_drop_pickup_target_feedback"):
		world.play_drop_pickup_target_feedback(item_type, item_category)
	if is_instance_valid(drop_node):
		drop_node.queue_free()


func restore_drop_pickup_visual(drop_data: Dictionary) -> void:
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return

	var restore_position := get_drop_world_position_for_pickup(drop_data)
	var should_reindex: bool = drop_node.global_position.distance_squared_to(restore_position) > 0.01
	if should_reindex:
		unregister_drop(drop_data)
		drop_node.global_position = restore_position
		var stack_grid := get_drop_stack_grid(restore_position)
		drop_data["x"] = restore_position.x
		drop_data["y"] = restore_position.y
		drop_data["stack_grid_x"] = stack_grid.x
		drop_data["stack_grid_y"] = stack_grid.y
		register_drop(drop_data)

	var start_scale_value = drop_data.get("pickup_vacuum_start_scale", Vector2.ONE)
	var start_scale: Vector2 = start_scale_value if start_scale_value is Vector2 else Vector2.ONE
	var start_rotation: float = _safe_float(drop_data.get("pickup_vacuum_start_rotation", drop_node.rotation), drop_node.rotation, -TAU * 32.0, TAU * 32.0)
	var start_alpha: float = _safe_float(drop_data.get("pickup_vacuum_start_alpha", 1.0), 1.0, 0.0, 1.0)
	drop_node.modulate.a = start_alpha
	drop_node.scale = start_scale
	drop_node.rotation = start_rotation
	clear_drop_pickup_vacuum_state(drop_data)
	drop_data["start_y"] = drop_node.position.y
	update_drop_count_label(drop_data)
	update_drop_count_screen_position(drop_data)


func _safe_stack_target_for_item(item_type: String, item_category: String) -> Dictionary:
	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_item_type == "":
		return {}

	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	var slot = _resolve_inventory_slot_for_drop(safe_item_type, safe_category)
	if slot.is_empty():
		return {}

	var target_inventory = slot.get("inventory", {})
	if not (target_inventory is Dictionary):
		return {}

	var target_category = _safe_string(slot.get("category", safe_category), safe_category, MAX_ITEM_CATEGORY_LENGTH)
	if target_category == "":
		return {}

	return {
		"item_type": safe_item_type,
		"inventory": target_inventory,
		"category": target_category,
		"stack_limit": _get_inventory_stack_limit_for_drop_item(safe_item_type, target_category)
	}


func _get_stack_limit_for_drop_item(item_type: String, item_category: String) -> int:
	if world == null:
		return 1

	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	if safe_item_type == "" or safe_category == "":
		return 1

	var stack_limit = world.get_stack_limit_for_item(safe_item_type, safe_category) if world.has_method("get_stack_limit_for_item") else MAX_DROP_STACK_SIZE
	if stack_limit < 1:
		return 1
	return min(stack_limit, MAX_DROP_STACK_SIZE)


func _get_inventory_stack_limit_for_drop_item(item_type: String, item_category: String) -> int:
	if world == null:
		return 1

	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	if safe_item_type == "" or safe_category == "":
		return 1

	var stack_limit = world.get_stack_limit_for_item(safe_item_type, safe_category) if world.has_method("get_stack_limit_for_item") else MAX_DROP_STACK_SIZE
	if stack_limit < 1:
		return 1
	return int(stack_limit)


func get_available_stack_space(item_type: String, item_category: String = "", ignore_drop_id: String = "") -> float:
	if world == null:
		return 0

	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	var safe_category = _safe_string(item_category, "", MAX_ITEM_CATEGORY_LENGTH)
	var safe_ignore_drop_id = _safe_string(ignore_drop_id, "", MAX_DROP_ID_LENGTH)
	var slot = _safe_stack_target_for_item(safe_item_type, safe_category)
	if slot.is_empty():
		return 0

	var current_inventory: Dictionary = slot["inventory"]
	var target_category = _safe_string(slot.get("category", safe_category), safe_category, MAX_ITEM_CATEGORY_LENGTH)
	var stack_limit = int(slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(safe_item_type, target_category)))
	if stack_limit <= 0:
		return 0

	var is_weight: bool = _is_fish_drop_category(target_category)
	var pending_pickup_amount: float = get_pending_pickup_amount_for_stack(safe_item_type, target_category, safe_ignore_drop_id)
	var safe_pending_pickup_amount: float = _safe_drop_amount(pending_pickup_amount, 0.0, 0.0, float(stack_limit), is_weight)

	var current_count: float = _safe_drop_amount(current_inventory.get(safe_item_type, 0.0), 0.0, 0.0, float(stack_limit), is_weight)
	# Fill existing stacks first. This project currently stores one stack per item/category.
	return max(0.0, float(stack_limit) - current_count - safe_pending_pickup_amount)


func can_add_item(item_type: String, amount: float, item_category: String = "", ignore_drop_id: String = "") -> bool:
	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_item_type == "":
		return false

	var slot = _safe_stack_target_for_item(safe_item_type, item_category)
	if slot.is_empty():
		return false

	var target_category = _safe_string(slot.get("category", item_category), item_category, MAX_ITEM_CATEGORY_LENGTH)
	var stack_limit = int(slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(safe_item_type, target_category)))
	if stack_limit <= 0:
		return false

	var safe_amount: float = _safe_drop_amount(amount, 0.0, 0.0, float(stack_limit), _is_fish_drop_category(target_category))
	if safe_amount <= 0:
		return false

	var available_after_pending = get_available_stack_space(item_type, target_category, ignore_drop_id)
	return available_after_pending >= safe_amount


func _get_max_addable_to_inventory(item_type: String, item_category: String, drop_amount: float, ignore_drop_id: String = "") -> float:
	var slot = _safe_stack_target_for_item(item_type, item_category)
	if slot.is_empty():
		return 0

	var target_category = _safe_string(slot.get("category", item_category), item_category, MAX_ITEM_CATEGORY_LENGTH)
	if target_category == "":
		return 0

	var stack_limit = int(slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(item_type, target_category)))
	if stack_limit <= 0:
		return 0

	var available_space = get_available_stack_space(item_type, target_category, ignore_drop_id)
	if available_space <= 0:
		return 0

	var is_weight: bool = _is_fish_drop_category(target_category)
	var safe_drop_amount: float = _safe_drop_amount(drop_amount, 0.0, 0.0, float(stack_limit), is_weight)
	if safe_drop_amount <= 0:
		return 0

	# Fill the destination inventory stack first (single stack per item in current system).
	return min(safe_drop_amount, available_space)


func _apply_authoritative_pickup_to_inventory(drop_data: Dictionary, previous_amount: float, remote_amount: float, requested_amount: float = -1.0) -> float:
	if world == null or drop_data == null or drop_data.is_empty():
		return 0

	var was_requested = bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false))
	if not was_requested:
		return 0

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return 0
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	item_category = _clean_drop_inventory_category(item_type, item_category)
	if item_category == "":
		return 0
	var stack_limit = _get_inventory_stack_limit_for_drop_item(item_type, item_category)
	if stack_limit <= 0:
		return 0

	var is_weight: bool = _is_fish_drop_category(item_category)
	var safe_previous_amount: float = _safe_drop_amount(previous_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if safe_previous_amount <= 0:
		return 0

	var safe_remote_amount: float = _safe_drop_amount(remote_amount, safe_previous_amount, 0.0, safe_previous_amount, is_weight)

	var safe_requested_amount: float = _safe_drop_amount(requested_amount, -1.0, -1.0, safe_previous_amount, is_weight)
	if safe_requested_amount <= 0:
		safe_requested_amount = _safe_drop_amount(drop_data.get("pickup_requested_amount", 0.0), -1.0, -1.0, safe_previous_amount, is_weight)
	if safe_requested_amount < 0:
		safe_requested_amount = 0

	var drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	var observed_taken: float = _safe_drop_amount(safe_previous_amount - safe_remote_amount, 0.0, 0.0, safe_previous_amount, is_weight)
	if safe_requested_amount > 0:
		observed_taken = min(observed_taken, safe_requested_amount)
	if observed_taken <= 0:
		return 0

	var inv_before: float = _safe_inventory_count_for_item(item_type, item_category)
	var added: float = add_item_server_authoritative(item_type, observed_taken, item_category, drop_id)
	if added < observed_taken:
		if world != null and world.has_method("request_network_player_state"):
			world.request_network_player_state()
		if observed_taken > 0:
			show_stack_full_notification()
	if added <= 0:
		return 0

	var inv_after: float = _safe_inventory_count_for_item(item_type, item_category)
	_log_drop_pickup_contract_case("authoritative.apply", item_type, inv_before, inv_after, safe_previous_amount, max(0, safe_previous_amount - added))
	return added


func _calculate_pickup_add_amount(item_type: String, item_category: String, drop_amount: float, ignore_drop_id: String = "") -> float:
	return _get_max_addable_to_inventory(item_type, item_category, drop_amount, ignore_drop_id)


func should_batch_pickup_inventory_ui() -> bool:
	# Pickup UI should be batched even when the inventory drawer is closed.
	# Otherwise mass pickup can call update_all_ui()/hotbar refresh once per item.
	if DROP_BULK_PICKUP_UI_ALWAYS_BATCH:
		return world != null
	return world != null and world.has_method("is_inventory_open") and world.is_inventory_open()


func get_pickup_ui_refresh_key(item_type: String, item_category: String) -> String:
	return item_category + ":" + item_type


func flush_pickup_inventory_ui_refreshes(force: bool = false) -> void:
	if pending_pickup_ui_refreshes.is_empty():
		pending_pickup_ui_flush_at_ms = 0
		return

	var now_ms: int = Time.get_ticks_msec()
	if not force and pending_pickup_ui_flush_at_ms > 0 and now_ms < pending_pickup_ui_flush_at_ms:
		return

	var refresh_entries: Array = pending_pickup_ui_refreshes.values()
	pending_pickup_ui_refreshes.clear()
	pending_pickup_ui_flush_at_ms = 0

	for entry in refresh_entries:
		if not (entry is Dictionary):
			continue
		refresh_pickup_inventory_ui_now(str(entry.get("item_type", "")), str(entry.get("item_category", "")))


func queue_pickup_inventory_ui_refresh(item_type: String, item_category: String) -> void:
	if item_type == "" or item_category == "":
		return
	var key: String = get_pickup_ui_refresh_key(item_type, item_category)
	pending_pickup_ui_refreshes[key] = {
		"item_type": item_type,
		"item_category": item_category
	}
	var next_flush_ms: int = Time.get_ticks_msec() + PICKUP_UI_REFRESH_BATCH_MS
	if pending_pickup_ui_flush_at_ms <= 0 or next_flush_ms < pending_pickup_ui_flush_at_ms:
		pending_pickup_ui_flush_at_ms = next_flush_ms


func refresh_pickup_inventory_ui_now(item_type: String, item_category: String) -> void:
	if world == null:
		return
	var resolved_category: String = _clean_drop_inventory_category(item_type, item_category)
	if resolved_category == "":
		resolved_category = item_category
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(item_type, resolved_category)
	else:
		world.update_all_ui()


func refresh_pickup_inventory_ui(item_type: String, item_category: String) -> void:
	if world == null:
		return
	var resolved_category: String = _clean_drop_inventory_category(item_type, item_category)
	if resolved_category == "":
		resolved_category = item_category
	if should_batch_pickup_inventory_ui():
		queue_pickup_inventory_ui_refresh(item_type, resolved_category)
		return
	refresh_pickup_inventory_ui_now(item_type, resolved_category)


func add_item_server_authoritative(item_type: String, amount: float, item_category: String = "", ignore_drop_id: String = "") -> float:
	if world == null:
		return 0

	var resolved_category = _clean_drop_inventory_category(item_type, item_category)
	var safe_ignore_drop_id = _safe_string(ignore_drop_id, "", MAX_DROP_ID_LENGTH)
	var slot = _safe_stack_target_for_item(item_type, resolved_category)
	if slot.is_empty():
		return 0

	var safe_item_type: String = slot.get("item_type", "")
	var safe_category: String = _safe_string(slot.get("category", resolved_category), resolved_category, MAX_ITEM_CATEGORY_LENGTH)
	var target_inventory: Dictionary = slot.get("inventory", {})
	var stack_limit: int = int(slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(safe_item_type, safe_category)))
	if target_inventory == null or safe_item_type == "" or stack_limit <= 0:
		return 0

	var is_weight: bool = _is_fish_drop_category(safe_category)
	var safe_amount: float = _safe_drop_amount(amount, 0.0, 0.0, float(stack_limit), is_weight)
	if safe_amount <= 0:
		return 0

	var add_amount: float = _calculate_pickup_add_amount(safe_item_type, safe_category, safe_amount, safe_ignore_drop_id)
	if add_amount <= 0:
		return 0

	var latest_slot = _safe_stack_target_for_item(safe_item_type, safe_category)
	if latest_slot.is_empty():
		return 0

	var latest_inventory = latest_slot.get("inventory", {})
	if not (latest_inventory is Dictionary):
		return 0

	var latest_category = _safe_string(latest_slot.get("category", safe_category), safe_category, MAX_ITEM_CATEGORY_LENGTH)
	var latest_limit = int(latest_slot.get("stack_limit", _get_inventory_stack_limit_for_drop_item(safe_item_type, latest_category)))
	if latest_limit <= 0:
		return 0

	var latest_is_weight: bool = _is_fish_drop_category(latest_category)
	var current_count: float = _tenths_to_weight(_inventory_fish_value_to_tenths(latest_inventory.get(safe_item_type, 0))) if latest_is_weight else _safe_drop_amount(latest_inventory.get(safe_item_type, 0.0), 0.0, 0.0, float(latest_limit), false)
	var available_space: float = max(0.0, float(latest_limit) - current_count)
	if available_space <= 0:
		return 0

	add_amount = min(add_amount, available_space)
	add_amount = _safe_drop_amount(max(0.0, add_amount), 0.0, 0.0, available_space, latest_is_weight)
	if add_amount <= 0:
		return 0

	var added_amount: float = 0.0
	if latest_is_weight:
		var next_weight: float = _safe_drop_amount(current_count + add_amount, 0.0, 0.0, float(latest_limit), true)
		latest_inventory[safe_item_type] = _weight_to_tenths(next_weight)
		added_amount = _safe_drop_amount(next_weight - current_count, 0.0, 0.0, add_amount, true)
	else:
		added_amount = float(world.add_item_to_inventory_stack(latest_inventory, safe_item_type, latest_category, int(round(add_amount))))
	if added_amount <= 0:
		return 0

	added_amount = min(added_amount, add_amount)
	added_amount = min(added_amount, max(0.0, float(latest_limit) - current_count))
	if added_amount <= 0:
		return 0

	var latest_count: float = _safe_drop_amount(latest_inventory.get(safe_item_type, 0.0), 0.0, 0.0, float(latest_limit), latest_is_weight)
	_log_drop_pickup_contract_case("server_authoritative.add", safe_item_type, current_count, latest_count, 0, 0)
	return added_amount


func try_pickup_drop(player_id: String, drop_id: String) -> float:
	if world == null or world.player == null:
		return 0

	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if safe_drop_id == "":
		return 0

	var request_player_id = _safe_string(player_id, "", MAX_ITEM_ID_LENGTH)
	if request_player_id != "":
		var network = get_network_manager()
		var local_player_id = _safe_string(network.get("player_id"), "", MAX_ITEM_ID_LENGTH) if network != null else ""
		if local_player_id != "" and local_player_id != request_player_id:
			return 0

	var drop_data = get_drop_by_id(safe_drop_id)
	if drop_data.is_empty():
		return 0

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return 0
	if bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_requested", false)):
		return 0

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return 0

	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	item_category = _clean_drop_inventory_category(item_type, item_category)
	if item_category == "":
		_clear_drop_pickup_flags(drop_data)
		return 0

	var _stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	var is_weight: bool = _is_fish_drop_category(item_category)
	var drop_amount: float = _safe_drop_amount(drop_data.get("amount", 1.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if drop_amount <= 0:
		remove_drop_by_id(safe_drop_id)
		return 0

	if not should_use_server_authoritative_world_actions():
		var before_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
		if not collect_drop(drop_data):
			var after_amount: float = _safe_drop_amount(drop_data.get("amount", before_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			return max(0.0, before_amount - after_amount)

		return before_amount

	if not is_drop_pickup_allowed(drop_data):
		show_stack_full_notification()
		return 0

	var pickup_source_amount: float = get_pickup_source_amount_for_drop(drop_data, safe_drop_id)
	var planned_add: float = _get_max_addable_to_inventory(item_type, item_category, pickup_source_amount, safe_drop_id)
	if planned_add <= 0:
		show_stack_full_notification()
		return 0

	mark_drop_pickup_requested(drop_data, planned_add)
	process_queued_drop_pickups()

	return planned_add


func is_drop_pickup_allowed(drop_data: Dictionary) -> bool:
	if world == null or world.player == null:
		return false
	if drop_data == null or drop_data.is_empty():
		return false

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return false
	if world.player.global_position.distance_squared_to(drop_node.global_position) > float(world.PICKUP_RANGE * world.PICKUP_RANGE):
		return false

	var safe_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var safe_category = _clean_drop_inventory_category(
		safe_type,
		_safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	)
	var safe_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), _is_fish_drop_category(safe_category))
	if safe_type == "" or safe_amount <= 0 or safe_category == "":
		return false

	var stack_limit = _get_stack_limit_for_drop_item(safe_type, safe_category)
	if stack_limit <= 0:
		return false

	if get_inventory_target_for_drop(safe_type, safe_category).is_empty():
		return false

	var pickup_delay = _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
	if _safe_float(drop_data.get("age", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS) < pickup_delay:
		return false

	if is_drop_stack_covered({
		"node": drop_node,
		"stack_grid_x": _safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999),
		"stack_grid_y": _safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
	}):
		return false

	return get_drop_inventory_room(drop_data, safe_category) > 0


func get_drop_inventory_room(drop_data: Dictionary, item_category: String = "") -> float:
	if world == null:
		return 0

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return 0

	var resolved_category = _clean_drop_inventory_category(item_type, item_category)
	var target = get_inventory_target_for_drop(item_type, resolved_category)
	if target.is_empty():
		return 0

	var target_category = _safe_string(target.get("category", resolved_category), resolved_category, MAX_ITEM_CATEGORY_LENGTH)
	return get_available_stack_space(item_type, target_category)


func get_pending_pickup_amount_for_stack(item_type: String, target_category: String, ignore_drop_id: String = "") -> float:
	if world == null:
		return 0

	var safe_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if safe_item_type == "":
		return 0

	var safe_category = _safe_string(target_category, "", MAX_ITEM_CATEGORY_LENGTH)
	if safe_category == "":
		return 0

	var stack_limit = _get_inventory_stack_limit_for_drop_item(safe_item_type, safe_category)
	if stack_limit <= 0:
		return 0
	var safe_ignore_drop_id = _safe_string(ignore_drop_id, "", MAX_DROP_ID_LENGTH)

	var is_weight: bool = _is_fish_drop_category(safe_category)
	var pending_amount: float = 0.0
	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var pending_drop: Dictionary = raw_drop_data
		var is_requesting = bool(pending_drop.get("pickup_requested", false))
		var is_in_progress = bool(pending_drop.get("pickup_in_progress", false))
		var is_request_sent = bool(pending_drop.get("pickup_request_sent", false))
		if not is_requesting and not is_in_progress and not is_request_sent:
			continue

		var candidate_stack_ids: Array = _get_drop_stack_ids(pending_drop)
		if safe_ignore_drop_id != "" and candidate_stack_ids.has(safe_ignore_drop_id):
			continue

		var pending_item_type = _safe_string(pending_drop.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		if pending_item_type != safe_item_type:
			continue

		var pending_category = _safe_string(pending_drop.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var pending_target = get_inventory_target_for_drop(pending_item_type, pending_category)
		if pending_target.is_empty():
			continue

		var pending_target_category = _safe_string(pending_target.get("category", pending_category), pending_category, MAX_ITEM_CATEGORY_LENGTH)
		if pending_target_category != safe_category:
			continue

		pending_amount += _safe_drop_amount(pending_drop.get("pickup_requested_amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)

	return min(pending_amount, stack_limit)


func has_better_same_item_pickup_candidate(drop_data: Dictionary, player_position: Vector2, pickup_range_sq: float, _available_room: float, nearby_candidates: Array = []) -> bool:
	if world == null:
		return false

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return false

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_weight: bool = _is_fish_drop_category(item_category)
	var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	var candidates = nearby_candidates if not nearby_candidates.is_empty() else world.dropped_items

	for raw_candidate in candidates:
		if not (raw_candidate is Dictionary):
			continue

		var candidate: Dictionary = raw_candidate
		var candidate_node = candidate.get("node", null)
		if candidate_node == drop_node or not is_instance_valid(candidate_node):
			continue

		if bool(candidate.get("pickup_requested", false)):
			continue

		if _safe_string(candidate.get("item_type", ""), "", MAX_ITEM_ID_LENGTH) != item_type:
			continue

		if _safe_string(candidate.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH) != item_category:
			continue

		var candidate_amount: float = _safe_drop_amount(candidate.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
		if candidate_amount <= current_amount:
			continue

		if is_drop_stack_covered(candidate):
			continue

		var candidate_delay = _safe_float(candidate.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
		var candidate_age = _safe_float(candidate.get("age", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS * 2.0)
		if candidate_age < candidate_delay:
			continue

		if player_position.distance_squared_to(candidate_node.global_position) > pickup_range_sq:
			continue

		return true

	return false


func show_stack_full_notification() -> void:
	if world == null:
		return

	if stack_full_notification_cooldown > 0.0:
		return

	stack_full_notification_cooldown = STACK_FULL_NOTIFICATION_COOLDOWN
	if world.has_method("show_notification"):
		world.show_notification("Inventory full")


func update_drops(delta):
	if world == null:
		return

	reset_drop_pickup_frame_budgets()
	drop_pickup_scan_elapsed += delta
	stack_full_notification_cooldown = max(0.0, stack_full_notification_cooldown - delta)
	flush_pickup_inventory_ui_refreshes()

	var should_scan_pickups := drop_pickup_scan_elapsed >= DROP_PICKUP_SCAN_INTERVAL
	if should_scan_pickups:
		drop_pickup_scan_elapsed = 0.0

	var has_player := world.player != null
	var player_position := Vector2.ZERO
	var pickup_range_sq := 0.0
	var pickups_this_scan := 0
	var pending_pickup_amount_cache: Dictionary = {}
	var nearby_pickup_candidates: Array = []
	var nearby_pickup_candidate_ids: Dictionary = {}
	var now_msec := Time.get_ticks_msec()
	var use_server_authoritative_pickups := should_use_server_authoritative_world_actions()
	var server_pickup_request_count := get_server_pickup_request_count() if use_server_authoritative_pickups else 0
	var visible_world_rect: Rect2 = get_visible_world_rect(DROP_VISIBILITY_MARGIN_SCREEN_PX)
	visible_drop_nodes = 0
	if should_scan_pickups:
		reset_drop_pickup_debug_scan()
		if not has_player and world.dropped_items.size() > 0:
			record_drop_pickup_debug("no_player", {}, Vector2.ZERO, 0.0)

	if has_player:
		player_position = world.player.global_position
		pickup_range_sq = float(world.PICKUP_RANGE * world.PICKUP_RANGE)
		if should_scan_pickups:
			nearby_pickup_candidates = get_nearby_drop_candidates(player_position, pickup_range_sq)
			# Keep pickup scans bounded when a large pile is nearby. The loop below
			# still picks up across multiple scans, but avoids one-frame spikes.
			if nearby_pickup_candidates.size() > DROP_MAX_PICKUPS_PER_SCAN * 4:
				nearby_pickup_candidates = nearby_pickup_candidates.slice(0, DROP_MAX_PICKUPS_PER_SCAN * 4)
			for candidate in nearby_pickup_candidates:
				if not (candidate is Dictionary):
					continue
				_add_drop_candidate_ids(candidate, nearby_pickup_candidate_ids)

	for i in range(world.dropped_items.size() - 1, -1, -1):
		var drop_data = world.dropped_items[i]
		if not (drop_data is Dictionary):
			world.dropped_items.remove_at(i)
			continue

		var drop_node = drop_data.get("node", null)

		if not is_instance_valid(drop_node):
			if should_scan_pickups and has_player:
				record_drop_pickup_debug("invalid_node", drop_data, player_position, pickup_range_sq)
			remove_drop_count_controls(drop_data)
			unregister_drop(drop_data)
			world.dropped_items.remove_at(i)
			continue

		drop_data["age"] += delta
		world.dropped_items[i] = drop_data
		var update_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var update_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), _is_fish_drop_category(update_category))
		if should_show_drop_count_label(drop_data, update_amount) and not is_instance_valid(drop_data.get("count_label_ui", null)):
			update_drop_count_label(drop_data)

		var pickup_requested := bool(drop_data.get("pickup_requested", false))
		var visual_active := pickup_requested or is_drop_in_visible_world_rect(drop_node, visible_world_rect)
		set_drop_visual_active(drop_data, drop_node, visual_active, update_amount)
		if visual_active:
			visible_drop_nodes += 1
			apply_drop_colour_cycle_visual(drop_data)

		if pickup_requested:
			var pickup_requested_age: float = _safe_float(drop_data.get("pickup_requested_age", 0.0), 0.0, 0.0, DROP_PICKUP_REQUEST_TIMEOUT * 2.0) + delta
			drop_data["pickup_requested_age"] = pickup_requested_age
			var pickup_sent := bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false))

			if pickup_sent and pickup_requested_age >= DROP_PICKUP_REQUEST_TIMEOUT:
				_reject_pending_drop_pickup(drop_data, DROP_PICKUP_REJECT_RETRY_COOLDOWN)
				world.dropped_items[i] = drop_data
				pickup_requested = false
			elif has_player:
				if can_update_drop_pickup_vacuum_visual():
					animate_drop_pickup_vacuum(drop_data, get_drop_pickup_vacuum_target_position(drop_data, player_position), delta)
				else:
					# Extra queued pickups stay lightweight and hidden instead of animating
					# hundreds of sprites toward the inventory in the same frame.
					drop_node.visible = false
				world.dropped_items[i] = drop_data
				continue

		if not visual_active:
			if should_scan_pickups and has_player and pickups_this_scan < DROP_MAX_PICKUPS_PER_SCAN:
				if not _drop_matches_candidate_ids(drop_data, nearby_pickup_candidate_ids):
					record_drop_pickup_debug("outside_candidate_cells", drop_data, player_position, pickup_range_sq)
					world.dropped_items[i] = drop_data
					continue
			else:
				world.dropped_items[i] = drop_data
				continue

		if not pickup_requested:
			if drop_node.modulate.a < 0.99:
				drop_node.modulate.a = move_toward(drop_node.modulate.a, 1.0, delta * 12.0)
			if drop_node.scale.distance_to(Vector2.ONE) > 0.01:
				drop_node.scale = drop_node.scale.move_toward(Vector2.ONE, delta * 12.0)

		var bob_offset = _safe_float(drop_data.get("bob_offset", 0.0), 0.0, 0.0, 1000.0)
		var start_y = _safe_float(drop_data.get("start_y", drop_node.position.y), drop_node.position.y, -MAX_WORLD_COORD, MAX_WORLD_COORD)
		var new_position = drop_node.position
		new_position.y = start_y + sin(drop_data["age"] * 4.0 + bob_offset) * 3.0
		drop_node.position = new_position
		update_drop_count_screen_position(drop_data)

		if should_scan_pickups and has_player and pickups_this_scan < DROP_MAX_PICKUPS_PER_SCAN:
			if not _drop_matches_candidate_ids(drop_data, nearby_pickup_candidate_ids):
				record_drop_pickup_debug("outside_candidate_cells", drop_data, player_position, pickup_range_sq)
				continue

			var blocked_until_ms = int(drop_data.get("pickup_blocked_until_ms", 0))
			if blocked_until_ms > now_msec:
				record_drop_pickup_debug("retry_cooldown", drop_data, player_position, pickup_range_sq, {
					"cooldown_ms": blocked_until_ms - now_msec
				})
				continue
			elif blocked_until_ms > 0:
				drop_data.erase("pickup_blocked_until_ms")

			var pickup_delay = _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)

			if drop_data["age"] < pickup_delay:
				record_drop_pickup_debug("pickup_delay", drop_data, player_position, pickup_range_sq)
				continue

			if player_position.distance_squared_to(drop_node.global_position) > pickup_range_sq:
				record_drop_pickup_debug("out_of_range", drop_data, player_position, pickup_range_sq)
				continue

			if is_drop_stack_covered(drop_data):
				record_drop_pickup_debug("covered_by_block", drop_data, player_position, pickup_range_sq)
				continue

			var drop_item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			var drop_item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			var drop_target = get_inventory_target_for_drop(drop_item_type, drop_item_category)
			if drop_item_type == "" or drop_target.is_empty():
				record_drop_pickup_debug("no_inventory_target", drop_data, player_position, pickup_range_sq, {
					"raw_item_type": str(drop_data.get("item_type", "")),
					"raw_item_category": str(drop_data.get("item_category", ""))
				})
				continue
			var drop_target_category = _safe_string(drop_target.get("category", drop_item_category), drop_item_category, MAX_ITEM_CATEGORY_LENGTH)
			if drop_target_category == "":
				record_drop_pickup_debug("empty_target_category", drop_data, player_position, pickup_range_sq)
				continue
			var pickup_stack_key = drop_target_category + ":" + drop_item_type

			var pending_pickup_amount: float = 0.0
			if pending_pickup_amount_cache.has(pickup_stack_key):
				pending_pickup_amount = float(pending_pickup_amount_cache[pickup_stack_key])
			else:
				pending_pickup_amount = get_pending_pickup_amount_for_stack(drop_item_type, drop_target_category)
				pending_pickup_amount_cache[pickup_stack_key] = pending_pickup_amount

			var is_weight_drop: bool = _is_fish_drop_category(drop_target_category)
			var stack_limit := _get_inventory_stack_limit_for_drop_item(drop_item_type, drop_target_category)
			if stack_limit <= 0:
				record_drop_pickup_debug("bad_stack_limit", drop_data, player_position, pickup_range_sq)
				continue
			var inventory_count: float = _safe_inventory_count_for_item(drop_item_type, drop_target_category)
			var safe_pending_amount: float = _safe_drop_amount(pending_pickup_amount, 0.0, 0.0, float(stack_limit), is_weight_drop)
			var available_room: float = max(0.0, float(stack_limit) - inventory_count - safe_pending_amount)
			if available_room <= 0:
				record_drop_pickup_debug("inventory_full", drop_data, player_position, pickup_range_sq, {
					"inventory_count": inventory_count,
					"pending_amount": safe_pending_amount,
					"stack_limit": stack_limit
				})
				drop_data["pickup_blocked_until_ms"] = now_msec + int(DROP_PICKUP_FULL_STACK_RETRY_COOLDOWN * 1000.0)
				world.dropped_items[i] = drop_data
				show_stack_full_notification()
				continue

			# Bulk pickup fix: do not skip smaller same-item drops here.
			# Pending amount accounting below already prevents overfilling stacks,
			# and the old "better same item nearby" skip made piles drain one
			# matching item stack at a time.

			var pickup_drop_id := get_pickup_drop_id(drop_data)
			var pickup_source_amount: float = get_pickup_source_amount_for_drop(drop_data, pickup_drop_id)
			var pickup_amount: float = _calculate_pickup_add_amount(drop_item_type, drop_target_category, pickup_source_amount, pickup_drop_id)
			if pickup_amount > available_room:
				pickup_amount = available_room
			if pickup_amount <= 0:
				record_drop_pickup_debug("pickup_amount_zero", drop_data, player_position, pickup_range_sq)
				drop_data["pickup_blocked_until_ms"] = now_msec + int(DROP_PICKUP_FULL_STACK_RETRY_COOLDOWN * 1000.0)
				world.dropped_items[i] = drop_data
				show_stack_full_notification()
				continue
			if use_server_authoritative_pickups:
				if bool(drop_data.get("pickup_requested", false)):
					record_drop_pickup_debug("already_requested", drop_data, player_position, pickup_range_sq)
					continue
				if server_pickup_request_count >= DROP_MAX_SERVER_PICKUP_QUEUE:
					record_drop_pickup_debug("queue_full", drop_data, player_position, pickup_range_sq)
					continue
				record_drop_pickup_debug("queued", drop_data, player_position, pickup_range_sq, {
					"pickup_amount": pickup_amount
				})
				mark_drop_pickup_requested(drop_data, pickup_amount)
				world.dropped_items[i] = drop_data
				pending_pickup_amount_cache[pickup_stack_key] = pending_pickup_amount + pickup_amount
				server_pickup_request_count += 1
				# Process the server pickup queue once after this update loop, not once
				# per requested drop. This avoids repeated full dropped_items scans.
				pickups_this_scan += 1
				continue

			if not collect_drop(drop_data):
				record_drop_pickup_debug("local_collect_failed", drop_data, player_position, pickup_range_sq)
				world.dropped_items[i] = drop_data
				continue

			record_drop_pickup_debug("local_collected", drop_data, player_position, pickup_range_sq)
			send_network_drop_pickup(drop_data)
			remove_drop_count_controls(drop_data)
			unregister_drop(drop_data)
			apply_pending_pickup_visual(drop_data)
			finish_drop_pickup_vacuum_node(drop_data, get_drop_pickup_vacuum_target_position(drop_data, player_position))
			world.dropped_items.remove_at(i)
			pickups_this_scan += 1

	process_queued_drop_pickups()
	if should_scan_pickups:
		maybe_print_drop_pickup_debug()


func collect_drop(drop_data) -> bool:
	if world == null:
		return false

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return false

	var item_category = _clean_drop_inventory_category(item_type, _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH))
	var stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if stack_limit <= 0:
		return false
	var is_weight: bool = _is_fish_drop_category(item_category)
	var amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	if amount <= 0:
		return false

	var inv_before = _safe_inventory_count_for_item(item_type, item_category)

	var collected_amount = add_item_server_authoritative(item_type, amount, item_category)
	if collected_amount <= 0:
		show_stack_full_notification()
		return false

	var remaining_amount: float = _safe_drop_amount(amount - collected_amount, 0.0, 0.0, amount, is_weight)
	var inv_after = _safe_inventory_count_for_item(item_type, item_category)
	_log_drop_pickup_contract_case("collect_drop", item_type, inv_before, inv_after, amount, remaining_amount)
	if remaining_amount > 0:
		drop_data["amount"] = remaining_amount
		update_drop_count_label(drop_data)
		send_network_drop_update(drop_data)
		refresh_pickup_inventory_ui(item_type, item_category)
		return false

	refresh_pickup_inventory_ui(item_type, item_category)
	return true


func run_drop_pickup_contract_debug_cases(force_print: bool = false) -> void:
	if (not force_print and not DEBUG_DROP_PICKUP_AUDIT) or world == null:
		return
	if not world.inventory is Dictionary:
		return

	var item_type = "dirt"
	var item_category = "block"
	var stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if stack_limit <= 0:
		return

	var had_inventory_entry = world.inventory.has(item_type)
	var original_count = _safe_int(world.inventory.get(item_type, 0), 0, 0, stack_limit)

	var scenarios = [
		{"label": "Case 1: inventory 50/400 + drop 400", "inv_before": 50},
		{"label": "Case 2: inventory 0/400 + drop 400", "inv_before": 0},
		{"label": "Case 3: inventory 399/400 + drop 400", "inv_before": 399},
		{"label": "Case 4: inventory 400/400 + drop 400", "inv_before": 400}
	]

	for scenario in scenarios:
		var start_count = _safe_int(scenario["inv_before"], 0, 0, stack_limit)
		world.inventory[item_type] = start_count
		var drop_amount = 400
		var collected = add_item_server_authoritative(item_type, drop_amount, item_category)
		var clamped_collected = clamp(collected, 0, drop_amount)
		var inv_after = _safe_inventory_count_for_item(item_type, item_category)
		var drop_after = max(0, drop_amount - clamped_collected)
		_log_drop_pickup_contract_case(str(scenario["label"]), item_type, start_count, inv_after, drop_amount, drop_after, true)

	# Restore original inventory slot after debug run.
	if had_inventory_entry:
		world.inventory[item_type] = original_count
	else:
		world.inventory.erase(item_type)

	print("[PM_DROP][PickupAudit] Case 5 note: current inventory model keeps one stack per item; existing stack is filled before any other slot logic.")


func _extract_drop_amount_from_payload(data: Dictionary, fallback_amount: float, is_weight: bool = false) -> float:
	if not (data is Dictionary):
		return _safe_drop_amount(fallback_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)

	var stack_limit = MAX_DROP_TILE_AMOUNT

	var safe_fallback: float = _safe_drop_amount(fallback_amount, 0.0, 0.0, float(stack_limit), is_weight)
	if is_weight:
		for tenths_key in ["weight_tenths", "amount_tenths", "remaining_weight_tenths", "remaining_amount_tenths", "drop_weight_tenths"]:
			if data.has(tenths_key):
				var tenths_amount: int = _safe_int(data.get(tenths_key, 0), 0, 0, stack_limit * 10)
				return _safe_drop_amount(_tenths_to_weight(tenths_amount), safe_fallback, 0.0, float(stack_limit), true)
		if str(data.get("unit", "")) == "tenths_lb" and data.has("amount"):
			var unit_tenths_amount: int = _safe_int(data.get("amount", 0), 0, 0, stack_limit * 10)
			return _safe_drop_amount(_tenths_to_weight(unit_tenths_amount), safe_fallback, 0.0, float(stack_limit), true)

	var quantities = _extract_pickup_payload_quantities(data, safe_fallback, stack_limit, is_weight)
	if bool(quantities.get("remaining_valid", false)):
		return _safe_drop_amount(quantities.get("remaining", safe_fallback), safe_fallback, 0.0, float(stack_limit), is_weight)

	if bool(quantities.get("added_valid", false)):
		var added_amount: float = _safe_drop_amount(quantities.get("added", 0.0), 0.0, 0.0, float(stack_limit), is_weight)
		if added_amount > safe_fallback:
			return safe_fallback
		return _safe_drop_amount(safe_fallback - added_amount, 0.0, 0.0, float(stack_limit), is_weight)

	return safe_fallback


func _extract_drop_pickup_requester_id(data: Dictionary) -> String:
	if data == null or not (data is Dictionary):
		return ""

	var candidate_keys = [
		"requested_by",
		"picker_id",
		"player_id",
		"actor_id",
		"pickup_player_id",
		"picked_by_id"
	]
	for key in candidate_keys:
		if not data.has(key):
			continue

		var raw_value = data.get(key)
		if raw_value is String or raw_value is int:
			var candidate = _safe_string(raw_value, "", MAX_REQUEST_ID_LENGTH)
			if candidate != "":
				return candidate

	return ""


func _extract_drop_pickup_requester_name(data: Dictionary) -> String:
	if data == null or not (data is Dictionary):
		return ""

	var candidate_keys = [
		"requested_by_name",
		"player_name",
		"picker_name",
		"username",
		"account_username"
	]
	for key in candidate_keys:
		if not data.has(key):
			continue

		var raw_value = data.get(key)
		if raw_value is String:
			var candidate = _safe_string(raw_value, "", MAX_USERNAME_LENGTH)
			if candidate != "":
				return candidate

	return ""


func _is_drop_pickup_response_for_local_client(drop_data: Dictionary, data: Dictionary) -> bool:
	if not (drop_data is Dictionary) or drop_data.is_empty():
		return false

	var was_requested = bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false))
	var network = get_network_manager()
	var local_player_id = _safe_string(network.get("player_id"), "", MAX_REQUEST_ID_LENGTH) if network != null else ""
	var request_is_local = false
	var requested_by = _safe_string(drop_data.get("pickup_requested_by", ""), "", MAX_REQUEST_ID_LENGTH)
	var request_ms = _safe_int(drop_data.get("pickup_request_ms", 0), 0, 0, int(1e15))
	if requested_by != "" and requested_by == local_player_id and request_ms > 0:
		request_is_local = (Time.get_ticks_msec() - request_ms) <= int(DROP_PICKUP_REQUEST_MATCH_WINDOW_SECONDS * 1000)

	var local_player_name = _safe_string(network.get("player_name"), "", MAX_USERNAME_LENGTH) if network != null else ""
	var requester_id = _extract_drop_pickup_requester_id(data)
	var requester_name = _extract_drop_pickup_requester_name(data)
	var has_request_identity = requester_id != "" or requester_name != ""
	var message_type = _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if (message_type == "world_item_drop_update" or message_type == "world_drop_update" or message_type == "drop_updated") and not has_pickup_result_fields(data):
		return false

	if not was_requested and not request_is_local:
		if network == null:
			return has_request_identity == false
		if requester_id != "":
			if local_player_id == "":
				return false
			return requester_id == local_player_id
		if requester_name != "" and local_player_name != "":
			return requester_name.to_lower() == local_player_name.to_lower()
		return false

	if network == null:
		return true

	if not has_request_identity:
		return (was_requested or request_is_local) and (message_type == "world_item_drop_pickup" or message_type == "world_drop_pickup" or message_type == "world_item_drop_update" or message_type == "world_drop_update")

	if requester_id != "":
		if local_player_id == "":
			return true
		return requester_id == local_player_id

	if requester_name != "" and local_player_name != "":
		return requester_name.to_lower() == local_player_name.to_lower()

	return false


func is_drop_message_for_current_world(data: Dictionary) -> bool:
	if world == null:
		return false

	var message_world = _get_message_world_name(data)
	if message_world == "":
		message_world = _safe_world_name(world.current_world_name)
	var local_world = _safe_world_name(world.current_world_name)
	if message_world == local_world:
		return true

	if world.save_manager != null and "waiting_for_server_world_state" in world.save_manager and bool(world.save_manager.waiting_for_server_world_state):
		world.current_world_name = message_world
		return true

	return false


func remove_drop_by_id(drop_id: String, finish_vacuum: bool = false, force_entire_stack: bool = false) -> bool:
	if world == null:
		return false

	var clean_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_id == "":
		return false

	if drops_by_id.has(clean_id):
		var indexed_drop: Dictionary = drops_by_id[clean_id]
		var indexed_node = indexed_drop.get("node", null)
		var aliases = _get_drop_stack_ids(indexed_drop)
		if aliases.size() > 1 and not force_entire_stack:
			var item_category: String = _safe_string(indexed_drop.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			var is_weight: bool = _is_fish_drop_category(item_category)
			var current_amount: float = _safe_drop_amount(indexed_drop.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			var alias_amount: float = _safe_drop_amount(_get_drop_stack_amount_for_id(indexed_drop, clean_id), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			if alias_amount <= 0.0:
				alias_amount = 0.1 if is_weight else 1.0
			var remaining_amount: float = _safe_drop_amount(max(0.0, current_amount - alias_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			if remaining_amount > 0:
				indexed_drop["amount"] = remaining_amount
				unregister_drop_id(indexed_drop, clean_id)
				if finish_vacuum:
					restore_drop_pickup_visual(indexed_drop)
				update_drop_count_label(indexed_drop)
				return true

		remove_drop_count_controls(indexed_drop)
		unregister_drop(indexed_drop)
		world.dropped_items.erase(indexed_drop)
		if is_instance_valid(indexed_node):
			if finish_vacuum:
				finish_drop_pickup_vacuum_node(indexed_drop)
			else:
				indexed_node.queue_free()
		return true

	for i in range(world.dropped_items.size() - 1, -1, -1):
		var drop_data = world.dropped_items[i]
		if str(drop_data.get("drop_id", "")) != clean_id:
			continue

		var drop_node = drop_data.get("node", null)
		remove_drop_count_controls(drop_data)
		unregister_drop(drop_data)
		world.dropped_items.remove_at(i)
		if is_instance_valid(drop_node):
			if finish_vacuum:
				finish_drop_pickup_vacuum_node(drop_data)
			else:
				drop_node.queue_free()
		return true

	return false


func should_force_remove_entire_drop_stack(drop_data: Dictionary, removed_id_lookup: Dictionary) -> bool:
	if drop_data == null or drop_data.is_empty():
		return false

	var aliases := _get_drop_stack_ids(drop_data)
	if aliases.size() <= 1:
		return true

	for raw_alias in aliases:
		var clean_alias := _safe_string(raw_alias, "", MAX_DROP_ID_LENGTH)
		if clean_alias == "":
			continue
		if not removed_id_lookup.has(clean_alias):
			return false

	return true


func cancel_pending_pickup_for_drop(drop_id: String) -> void:
	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if safe_drop_id == "":
		return

	var drop_data = get_drop_by_id(safe_drop_id)
	if drop_data.is_empty():
		return

	_clear_drop_pickup_flags(drop_data)
	restore_drop_pickup_visual(drop_data)
	process_queued_drop_pickups()


func cancel_all_pending_pickups() -> void:
	if world == null:
		return

	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if not bool(drop_data.get("pickup_requested", false)) and not bool(drop_data.get("pickup_in_progress", false)):
			continue

		_clear_drop_pickup_flags(drop_data)
		restore_drop_pickup_visual(drop_data)
	process_queued_drop_pickups()


func get_pending_drop_for_rejection(drop_id: String) -> Dictionary:
	if world == null:
		return {}

	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if safe_drop_id != "":
		var direct_drop = get_drop_by_id(safe_drop_id)
		if not direct_drop.is_empty():
			return direct_drop

	for raw_drop_data in world.dropped_items:
		if not (raw_drop_data is Dictionary):
			continue

		var drop_data: Dictionary = raw_drop_data
		if not bool(drop_data.get("pickup_requested", false)) and not bool(drop_data.get("pickup_in_progress", false)):
			continue

		if safe_drop_id == "":
			return drop_data

		var requested_drop_id = _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if requested_drop_id == safe_drop_id:
			return drop_data

		if _get_drop_stack_ids(drop_data).has(safe_drop_id):
			return drop_data

	return {}


func _append_unique_drop_id(target: Array, seen: Dictionary, raw_drop_id) -> void:
	var clean_drop_id: String = _safe_string(raw_drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_drop_id == "" or seen.has(clean_drop_id):
		return
	seen[clean_drop_id] = true
	target.append(clean_drop_id)


func get_bulk_rejected_pickup_ids(details: Dictionary, primary_drop_id: String = "") -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	_append_unique_drop_id(result, seen, primary_drop_id)

	var raw_drop_ids: Variant = details.get("drop_ids", [])
	if raw_drop_ids is Array:
		for raw_id in raw_drop_ids:
			_append_unique_drop_id(result, seen, raw_id)

	var raw_pickup_results: Variant = details.get("pickup_results", [])
	if raw_pickup_results is Array:
		for raw_result in raw_pickup_results:
			if not (raw_result is Dictionary):
				continue
			var result_entry: Dictionary = raw_result
			_append_unique_drop_id(result, seen, result_entry.get("drop_id", result_entry.get("id", "")))

	return result


func get_failed_bulk_pickup_ids(data: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var raw_pickup_results: Variant = data.get("pickup_results", [])
	if not (raw_pickup_results is Array):
		return result

	for raw_result in raw_pickup_results:
		if not (raw_result is Dictionary):
			continue
		var result_entry: Dictionary = raw_result
		if bool(result_entry.get("ok", false)):
			continue
		_append_unique_drop_id(result, seen, result_entry.get("drop_id", result_entry.get("id", "")))

	return result


func handle_rejected_drop_pickup(drop_id: String, message: String = "", details: Dictionary = {}) -> bool:
	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	var clean_message = _safe_string(message, "", 256).to_lower()
	var server_reason = _safe_string(details.get("reason", ""), "", 64).to_lower()
	var is_rate_limited := server_reason == "rate_limited" or clean_message.find("slow down") >= 0 or clean_message.find("rate limit") >= 0
	trace_drop_pickup_event("server_reject", details, get_pending_drop_for_rejection(safe_drop_id))
	var rejection_extra := {
		"message": message,
		"drop_id": safe_drop_id,
		"server_reason": server_reason,
		"world": _safe_string(details.get("world", ""), "", 96),
		"current_world": _safe_string(details.get("current_world", ""), "", 96),
		"requested_world": _safe_string(details.get("requested_world", ""), "", 96),
		"position_source": _safe_string(details.get("position_source", ""), "", 64),
		"age_ms": int(details.get("age_ms", -1))
	}
	var rejected_bulk_ids: Array = get_bulk_rejected_pickup_ids(details, safe_drop_id)
	if rejected_bulk_ids.size() > 1:
		var bulk_cooldown_seconds := DROP_PICKUP_REJECT_RETRY_COOLDOWN
		if is_rate_limited:
			bulk_cooldown_seconds = DROP_PICKUP_RATE_LIMIT_RETRY_COOLDOWN
			drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(bulk_cooldown_seconds * 1000.0)
		elif clean_message.find("inventory is busy") >= 0 or clean_message.find("inventory busy") >= 0:
			bulk_cooldown_seconds = DROP_PICKUP_BUSY_RETRY_COOLDOWN
			drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(bulk_cooldown_seconds * 1000.0)
		elif clean_message.find("inventory full") >= 0 or clean_message.find("could not add") >= 0:
			show_stack_full_notification()

		var handled_bulk_rejection := false
		for raw_rejected_id in rejected_bulk_ids:
			var rejected_id: String = _safe_string(raw_rejected_id, "", MAX_DROP_ID_LENGTH)
			var rejected_drop: Dictionary = get_pending_drop_for_rejection(rejected_id)
			if rejected_drop.is_empty():
				continue
			record_drop_pickup_server_event("server_rejected_bulk", rejected_drop, {
				"message": message,
				"drop_id": rejected_id,
				"server_reason": server_reason
			})
			_reject_pending_drop_pickup(rejected_drop, bulk_cooldown_seconds)
			handled_bulk_rejection = true

		if handled_bulk_rejection:
			process_queued_drop_pickups()
			return true

	var rejection_debug_reason := "server_rejected"
	if server_reason != "":
		rejection_debug_reason = "server_rejected_" + server_reason
	elif is_rate_limited:
		rejection_debug_reason = "server_rejected_rate_limited"
	elif clean_message.find("too far") >= 0:
		rejection_debug_reason = "server_rejected_too_far"
	elif clean_message.find("stale") >= 0:
		rejection_debug_reason = "server_rejected_stale_position"
	elif clean_message.find("position") >= 0 and clean_message.find("ready") >= 0:
		rejection_debug_reason = "server_rejected_position_missing"
	elif clean_message.find("inventory is busy") >= 0 or clean_message.find("inventory busy") >= 0:
		rejection_debug_reason = "server_rejected_busy"
	elif clean_message.find("inventory full") >= 0:
		rejection_debug_reason = "server_rejected_inventory_full"
	elif clean_message.find("could not add") >= 0:
		rejection_debug_reason = "server_rejected_add_failed"
	elif clean_message.find("not available") >= 0:
		rejection_debug_reason = "server_rejected_not_available"

	if safe_drop_id == "":
		if is_rate_limited:
			drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(DROP_PICKUP_RATE_LIMIT_RETRY_COOLDOWN * 1000.0)
			var rate_limited_drop = get_pending_drop_for_rejection("")
			record_drop_pickup_server_event(rejection_debug_reason, rate_limited_drop, rejection_extra)
			if not rate_limited_drop.is_empty():
				_clear_drop_pickup_flags(rate_limited_drop)
				rate_limited_drop["pickup_blocked_until_ms"] = drop_pickup_busy_until_ms
				restore_drop_pickup_visual(rate_limited_drop)
			return true
		elif clean_message.find("inventory is busy") >= 0 or clean_message.find("inventory busy") >= 0:
			drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(DROP_PICKUP_BUSY_RETRY_COOLDOWN * 1000.0)
			var busy_drop = get_pending_drop_for_rejection("")
			record_drop_pickup_server_event(rejection_debug_reason, busy_drop, rejection_extra)
			if not busy_drop.is_empty():
				_clear_drop_pickup_flags(busy_drop)
				busy_drop["pickup_blocked_until_ms"] = drop_pickup_busy_until_ms
				restore_drop_pickup_visual(busy_drop)
			else:
				cancel_all_pending_pickups()
			return true
		elif clean_message.find("not available") >= 0:
			var pending_drop = get_pending_drop_for_rejection("")
			if pending_drop.is_empty():
				cancel_all_pending_pickups()
				return false
			safe_drop_id = _safe_string(pending_drop.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
			if safe_drop_id == "":
				safe_drop_id = get_pickup_drop_id(pending_drop)
			rejection_extra["drop_id"] = safe_drop_id
			debug_drop_pickup_flow("server rejected pickup without drop id", pending_drop, {
				"message": message,
				"resolved_drop_id": safe_drop_id
			})
		else:
			cancel_all_pending_pickups()
			return false

	var drop_data = get_pending_drop_for_rejection(safe_drop_id)
	if drop_data.is_empty() and clean_message.find("not available") >= 0:
		debug_drop_pickup_flow("server rejected pickup for unknown local drop", {}, {
			"message": message,
			"requested_drop_id": safe_drop_id,
			"world_drop_count": world.dropped_items.size() if world != null else 0,
			"exists_locally": false
		})
		record_drop_pickup_server_event("server_rejected_not_available_unknown", {}, {
			"message": message,
			"drop_id": safe_drop_id,
			"server_reason": server_reason,
			"world": rejection_extra.get("world", ""),
			"current_world": rejection_extra.get("current_world", ""),
			"requested_world": rejection_extra.get("requested_world", "")
		})
		cancel_all_pending_pickups()
		return false

	if safe_drop_id == "" and not drop_data.is_empty():
		safe_drop_id = _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if safe_drop_id == "":
			safe_drop_id = get_pickup_drop_id(drop_data)
	rejection_extra["drop_id"] = safe_drop_id
	if not drop_data.is_empty():
		debug_drop_pickup_flow("server rejected pickup", drop_data, {
			"message": message,
			"rejected_drop_id": safe_drop_id,
			"world_drop_count": world.dropped_items.size() if world != null else 0,
			"exists_locally": true
		})
	record_drop_pickup_server_event(rejection_debug_reason, drop_data, {
		"message": message,
		"drop_id": safe_drop_id,
		"server_reason": server_reason,
		"world": rejection_extra.get("world", ""),
		"current_world": rejection_extra.get("current_world", ""),
		"requested_world": rejection_extra.get("requested_world", ""),
		"position_source": rejection_extra.get("position_source", ""),
		"age_ms": rejection_extra.get("age_ms", -1)
	})

	if is_rate_limited:
		drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(DROP_PICKUP_RATE_LIMIT_RETRY_COOLDOWN * 1000.0)
		if drop_data.is_empty():
			return true

		_clear_drop_pickup_flags(drop_data)
		drop_data["pickup_blocked_until_ms"] = drop_pickup_busy_until_ms
		restore_drop_pickup_visual(drop_data)
		return true

	if clean_message.find("inventory is busy") >= 0 or clean_message.find("inventory busy") >= 0:
		drop_pickup_busy_until_ms = Time.get_ticks_msec() + int(DROP_PICKUP_BUSY_RETRY_COOLDOWN * 1000.0)
		if drop_data.is_empty():
			return true

		_clear_drop_pickup_flags(drop_data)
		drop_data["pickup_blocked_until_ms"] = drop_pickup_busy_until_ms
		restore_drop_pickup_visual(drop_data)
		return true

	if clean_message.find("inventory full") >= 0 or clean_message.find("could not add") >= 0:
		if drop_data.is_empty():
			cancel_all_pending_pickups()
			return false

		_reject_pending_drop_pickup(drop_data, DROP_PICKUP_REJECT_RETRY_COOLDOWN)
		show_stack_full_notification()
		if world != null and world.has_method("request_network_player_state"):
			world.request_network_player_state()
		return true

	if clean_message.find("not available") >= 0:
		if drop_data.is_empty():
			cancel_all_pending_pickups()
			return false

		# "Not available" can mean a temporary server/drop lock race, not that
		# the drop vanished. Keep local world state until an authoritative
		# update/remove arrives from the server.
		_reject_pending_drop_pickup(drop_data, DROP_PICKUP_REJECT_RETRY_COOLDOWN)
		process_queued_drop_pickups()
		return true

	if safe_drop_id != "":
		cancel_pending_pickup_for_drop(safe_drop_id)
	else:
		cancel_all_pending_pickups()
	return false


func is_pickup_result_payload(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false
	if has_pickup_result_fields(data):
		return true
	var message_type: String = _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if message_type == "world_item_drop_pickup" or message_type == "world_drop_pickup" or message_type == "world_item_drop_remove" or message_type == "world_drop_remove" or message_type == "drop_removed":
		return true
	if bool(data.get("bulk_pickup", false)):
		return true
	if bool(data.get("removed", false)) or bool(data.get("drop_removed", false)) or bool(data.get("removed_from_world", false)):
		return true
	var removed_ids: Variant = data.get("removed_drop_ids", [])
	if removed_ids is Array and removed_ids.size() > 0:
		return true
	var pickup_results: Variant = data.get("pickup_results", [])
	if pickup_results is Array and pickup_results.size() > 0:
		return true
	return false


func apply_network_item_drop_create(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	trace_drop_pickup_event("apply_create_start", data, get_drop_by_id(drop_id))
	if drop_id == "":
		return
	if was_drop_id_recently_removed(drop_id):
		trace_drop_pickup_event("apply_create_ignored_tombstone", data, {})
		debug_drop_pickup_flow("ignored stale server drop create after pickup/remove", {}, {
			"drop_id": drop_id
		})
		return

	var existing_create_drop: Dictionary = get_drop_by_id(drop_id)
	if not existing_create_drop.is_empty() and is_drop_pickup_pending(existing_create_drop):
		debug_drop_pickup_flow("ignored server drop create while pickup pending", existing_create_drop, {
			"drop_id": drop_id
		})
		return

	var raw_item_type = data.get("item_type", data.get("item_id", data.get("block_type", "")))
	if _safe_string(raw_item_type, "", MAX_ITEM_ID_LENGTH) == "":
		var message_type = _safe_string(data.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
		if message_type != "drop_spawned" and message_type != "world_item_drop_create" and message_type != "world_drop_create":
			raw_item_type = data.get("type", "")
	var item_type = _safe_string(raw_item_type, "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return

	var item_category = _safe_string(data.get("item_category", data.get("category", "")), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_seed = _safe_bool(data.get("is_seed", item_category == "seed" or item_type.ends_with("_seed")), item_category == "seed" or item_type.ends_with("_seed"))
	if item_category == "":
		if is_seed:
			item_category = "seed"
		else:
			item_category = get_database_item_category(item_type, "")
	var stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if stack_limit <= 0:
		return
	var is_weight: bool = _is_fish_drop_category(item_category)
	var amount: float = _safe_drop_amount(data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
	var item_position = Vector2(
		_safe_float(data.get("x", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		_safe_float(data.get("y", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
	)
	if data.has("stack_grid_x") and data.has("stack_grid_y"):
		var server_stack_grid = _safe_grid_position(data.get("stack_grid_x"), data.get("stack_grid_y"))
		item_position = Vector2(server_stack_grid.x * world.BLOCK_SIZE, server_stack_grid.y * world.BLOCK_SIZE)
	var pickup_delay = _safe_float(data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)

	debug_drop_pickup_flow("server drop create", {}, {
		"drop_id": drop_id,
		"item_type": item_type,
		"item_category": item_category,
		"amount": amount,
		"x": item_position.x,
		"y": item_position.y,
		"stack_grid_x": data.get("stack_grid_x", null),
		"stack_grid_y": data.get("stack_grid_y", null)
	})
	var old_applying_server_drop_payload = applying_server_drop_payload
	applying_server_drop_payload = true
	create_item_drop(item_type, item_position, is_seed, item_category, pickup_delay, amount, drop_id, false)
	applying_server_drop_payload = old_applying_server_drop_payload
	trace_drop_pickup_event("apply_create_done", data, get_drop_by_id(drop_id))


func apply_network_item_drop_update(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	trace_drop_pickup_event("apply_update_start", data, get_drop_by_id(drop_id))
	if drop_id == "":
		return
	if was_drop_id_recently_removed(drop_id):
		trace_drop_pickup_event("apply_update_ignored_tombstone", data, {})
		debug_drop_pickup_flow("ignored stale server drop update after pickup/remove", {}, {
			"drop_id": drop_id,
			"type": str(data.get("type", ""))
		})
		return

	var drop_data: Dictionary = get_drop_by_id(drop_id)
	debug_drop_pickup_flow("server drop update", drop_data, {
		"drop_id": drop_id,
		"type": str(data.get("type", "")),
		"amount": data.get("amount", null),
		"remaining": data.get("remaining", null),
		"remaining_amount": data.get("remaining_amount", null)
	})
	if drop_data.is_empty():
		# Pickup confirmations/results must never recreate a drop that the server already removed.
		# This prevents the local ghost-drop rollback where the item appears again until rejoin.
		if is_pickup_result_payload(data):
			if apply_network_bulk_drop_pickup_result(data):
				return
			process_queued_drop_pickups()
			return
		apply_network_item_drop_create(data)
		return

	var current_is_weight: bool = _is_fish_drop_category(str(drop_data.get("item_category", "")))
	var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), current_is_weight)
	var current_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var current_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var stack_limit = _get_stack_limit_for_drop_item(current_type, current_category)
	if stack_limit <= 0:
		remove_drop_by_id(drop_id)
		return
	current_amount = _safe_drop_amount(current_amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), current_is_weight)
	drop_data["amount"] = current_amount
	if current_amount <= 0:
		remove_drop_by_id(drop_id)
		process_queued_drop_pickups()
		return

	var payload_has_pickup_result_fields: bool = has_pickup_result_fields(data)
	if is_drop_pickup_pending(drop_data) and not payload_has_pickup_result_fields:
		# This is usually an older create/update packet from the break/drop that arrived
		# after the player already requested pickup. Do not let it clear pickup flags
		# and visually snap the item back to the tile.
		debug_drop_pickup_flow("ignored stale drop update while pickup pending", drop_data, {
			"drop_id": drop_id,
			"type": str(data.get("type", ""))
		})
		return

	var amount: float = _extract_drop_amount_from_payload(data, current_amount, current_is_weight)
	amount = _safe_drop_amount(amount, 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), current_is_weight)
	var payload_item_type = _safe_string(data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if payload_item_type != "" and payload_item_type != _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH):
		debug_action_position_flow("drop update ignored due item mismatch", {
			"drop_id": drop_id,
			"local_item": str(drop_data.get("item_type", "")),
			"remote_item": payload_item_type
		})
		return

	var previous_amount: float = current_amount
	var stacked_ids = _get_drop_stack_ids(drop_data)
	var is_stacked_alias_update = stacked_ids.size() > 1 and stacked_ids.has(drop_id)
	var alias_previous_amount: float = _get_drop_stack_amount_for_id(drop_data, drop_id) if is_stacked_alias_update else previous_amount
	var alias_remote_amount: float = _safe_drop_amount(amount, 0.0, 0.0, alias_previous_amount, current_is_weight) if is_stacked_alias_update else amount
	var is_local_pickup_response: bool = payload_has_pickup_result_fields and _is_drop_pickup_response_for_local_client(drop_data, data)
	if is_stacked_alias_update:
		amount = _safe_drop_amount(previous_amount - max(0.0, alias_previous_amount - alias_remote_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), current_is_weight)

	var did_apply_player_state = bool(data.get("_server_inventory_update_applied", false))
	var applied_amount: float = 0.0
	if not did_apply_player_state and bool(data.get("_apply_pickup_inventory", true)) and is_local_pickup_response:
		var pickup_previous_amount = alias_previous_amount if is_stacked_alias_update else previous_amount
		var pickup_remote_amount = alias_remote_amount if is_stacked_alias_update else amount
		applied_amount = _apply_authoritative_pickup_to_inventory(drop_data, pickup_previous_amount, pickup_remote_amount)
		if applied_amount > 0:
			var pickup_item_type: String = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			var pickup_item_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			refresh_pickup_inventory_ui(pickup_item_type, pickup_item_category)
			amount = max(0, previous_amount - applied_amount)
			if is_stacked_alias_update:
				alias_remote_amount = max(0, alias_previous_amount - applied_amount)

	# Never increase drop count locally from an authoritative update payload.
	# If the server sends a higher amount than we know locally, keep local.
	# This protects us from stale/replayed packets and avoids inventory ghosting.
	if amount > current_amount:
		debug_action_position_flow("drop update rejected increase", {
			"drop_id": drop_id,
			"received": amount,
			"current": current_amount
		})
		amount = current_amount

	if is_local_pickup_response:
		record_drop_pickup_server_event("server_result_remove" if amount <= 0 else "server_result_update", drop_data, {
			"message_type": str(data.get("type", "")),
			"remaining_amount": amount,
			"applied_amount": applied_amount,
			"drop_id": drop_id
		})

	if amount <= 0:
		var should_finish_vacuum: bool = bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)) or is_local_pickup_response
		var removed_id_lookup: Dictionary = {}
		removed_id_lookup[drop_id] = true
		var force_entire_stack := should_force_remove_entire_drop_stack(drop_data, removed_id_lookup)
		mark_drop_id_recently_removed(drop_id)
		trace_drop_pickup_event("apply_update_remove", data, drop_data)
		remove_drop_by_id(drop_id, should_finish_vacuum, force_entire_stack)
		process_queued_drop_pickups()
		return

	drop_data["amount"] = amount
	if is_stacked_alias_update:
		if alias_remote_amount <= 0:
			unregister_drop_id(drop_data, drop_id)
		else:
			_remember_drop_stack_amount(drop_data, drop_id, alias_remote_amount)
	_clear_drop_pickup_flags(drop_data)

	var drop_node = drop_data.get("node", null)
	if is_instance_valid(drop_node):
		restore_drop_pickup_visual(drop_data)

	if is_instance_valid(drop_node) and data.has("x") and data.has("y"):
		unregister_drop(drop_data)
		var drop_position = Vector2(
			_safe_float(data.get("x", 0.0), drop_data.get("x", 0.0), -MAX_WORLD_COORD, MAX_WORLD_COORD),
			_safe_float(data.get("y", 0.0), drop_data.get("y", 0.0), -MAX_WORLD_COORD, MAX_WORLD_COORD)
		)
		if data.has("stack_grid_x") and data.has("stack_grid_y"):
			var server_stack_grid = _safe_grid_position(data.get("stack_grid_x"), data.get("stack_grid_y"))
			drop_position = Vector2(server_stack_grid.x * world.BLOCK_SIZE, server_stack_grid.y * world.BLOCK_SIZE)
		drop_node.global_position = drop_position
		var stack_grid = get_drop_stack_grid(drop_position)
		drop_data["x"] = drop_position.x
		drop_data["y"] = drop_position.y
		drop_data["stack_grid_x"] = stack_grid.x
		drop_data["stack_grid_y"] = stack_grid.y
		drop_data["start_y"] = drop_node.position.y
		register_drop(drop_data)
	else:
		register_drop(drop_data)

	update_drop_count_label(drop_data)
	trace_drop_pickup_event("apply_update_done", data, drop_data)
	process_queued_drop_pickups()


func apply_network_bulk_drop_pickup_result(data: Dictionary) -> bool:
	if not is_drop_message_for_current_world(data):
		return false
	trace_drop_pickup_event("apply_bulk_pickup_start", data, {})

	var raw_removed_ids: Variant = data.get("removed_drop_ids", [])
	var raw_drop_ids: Variant = data.get("drop_ids", [])
	var raw_updated_drops: Variant = data.get("updated_drops", [])
	var has_updated_drops: bool = false
	if raw_updated_drops is Array and raw_updated_drops.size() > 0:
		has_updated_drops = true
	var removed_ids: Array = []
	var seen_removed_ids: Dictionary = {}

	if raw_removed_ids is Array:
		for raw_id in raw_removed_ids:
			var clean_id := _safe_string(raw_id, "", MAX_DROP_ID_LENGTH)
			if clean_id == "" or seen_removed_ids.has(clean_id):
				continue
			seen_removed_ids[clean_id] = true
			removed_ids.append(clean_id)

	# Older bulk responses may only include drop_ids. Treat those as removed only
	# when the server did not also send explicit updated_drops.
	if removed_ids.is_empty() and not has_updated_drops and raw_drop_ids is Array:
		for raw_id in raw_drop_ids:
			var clean_id := _safe_string(raw_id, "", MAX_DROP_ID_LENGTH)
			if clean_id == "" or seen_removed_ids.has(clean_id):
				continue
			seen_removed_ids[clean_id] = true
			removed_ids.append(clean_id)

	if removed_ids.is_empty() and not has_updated_drops:
		var single_drop_id := _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
		var single_removed := bool(data.get("bulk_pickup", false)) or bool(data.get("removed", false)) or bool(data.get("drop_removed", false)) or bool(data.get("removed_from_world", false))
		if not single_removed:
			for remaining_key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
				if not data.has(remaining_key):
					continue
				var parsed_remaining: float = _safe_drop_amount(data.get(remaining_key), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(PICKUP_RESULT_UNKNOWN_AMOUNT), float(MAX_DROP_TILE_AMOUNT), false)
				if parsed_remaining == 0.0:
					single_removed = true
				break
		if single_drop_id != "" and single_removed:
			removed_ids.append(single_drop_id)

	if removed_ids.is_empty() and not has_updated_drops:
		return false

	debug_drop_pickup_flow("server bulk pickup result", {}, {
		"removed_ids": removed_ids.duplicate(),
		"updated_count": raw_updated_drops.size() if raw_updated_drops is Array else 0,
		"drop_ids": raw_drop_ids if raw_drop_ids is Array else []
	})

	var did_apply_player_state = bool(data.get("_server_inventory_update_applied", false))
	var should_apply_pickup_inventory = not did_apply_player_state and bool(data.get("_apply_pickup_inventory", true))

	if not removed_ids.is_empty():
		mark_drop_ids_recently_removed(removed_ids)

	if has_updated_drops:
		for raw_update in raw_updated_drops:
			if not (raw_update is Dictionary):
				continue
			var update_payload: Dictionary = raw_update.duplicate(true)
			if not update_payload.has("type"):
				update_payload["type"] = "world_item_drop_update"
			if not update_payload.has("world") and data.has("world"):
				update_payload["world"] = data.get("world")
			update_payload["_server_inventory_update_applied"] = did_apply_player_state
			update_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory
			apply_network_item_drop_update(update_payload)

	for failed_drop_id in get_failed_bulk_pickup_ids(data):
		var failed_drop: Dictionary = get_pending_drop_for_rejection(failed_drop_id)
		if failed_drop.is_empty():
			continue
		_reject_pending_drop_pickup(failed_drop, DROP_PICKUP_REJECT_RETRY_COOLDOWN)

	if should_apply_pickup_inventory:
		for clean_id in removed_ids:
			var removed_drop_data: Dictionary = get_drop_by_id(clean_id)
			if removed_drop_data.is_empty() or not _is_drop_pickup_response_for_local_client(removed_drop_data, data):
				continue
			var previous_type = _safe_string(removed_drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			var previous_category = _safe_string(removed_drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			var previous_is_weight: bool = _is_fish_drop_category(previous_category)
			var previous_amount: float = _safe_drop_amount(removed_drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), previous_is_weight)
			var stacked_ids = _get_drop_stack_ids(removed_drop_data)
			if stacked_ids.size() > 1 and stacked_ids.has(clean_id):
				previous_amount = min(previous_amount, max(0.1 if previous_is_weight else 1.0, _get_drop_stack_amount_for_id(removed_drop_data, clean_id)))
			var added_amount: float = _apply_authoritative_pickup_to_inventory(removed_drop_data, previous_amount, 0.0)
			if added_amount > 0.0:
				refresh_pickup_inventory_ui(previous_type, previous_category)

	for clean_id in removed_ids:
		var removed_drop_data: Dictionary = get_drop_by_id(clean_id)
		var force_entire_stack := should_force_remove_entire_drop_stack(removed_drop_data, seen_removed_ids)
		remove_drop_by_id(clean_id, true, force_entire_stack)

	# Clear pickup flags from any remaining visual stack aliases that were part of
	# this same bulk request. If all aliases were removed, these lookups are empty.
	if raw_drop_ids is Array:
		for raw_id in raw_drop_ids:
			var clean_id := _safe_string(raw_id, "", MAX_DROP_ID_LENGTH)
			if clean_id == "":
				continue
			var remaining_drop := get_drop_by_id(clean_id)
			if remaining_drop.is_empty():
				continue
			_clear_drop_pickup_flags(remaining_drop)
			restore_drop_pickup_visual(remaining_drop)
			update_drop_count_label(remaining_drop)

	process_queued_drop_pickups()
	trace_drop_pickup_event("apply_bulk_pickup_done", data, {})
	return true


func apply_network_item_drop_remove(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	var raw_bulk_drop_ids = data.get("drop_ids", [])
	var raw_bulk_removed_ids = data.get("removed_drop_ids", [])
	var raw_bulk_updated_drops = data.get("updated_drops", [])
	if bool(data.get("bulk_pickup", false)) or (raw_bulk_drop_ids is Array and raw_bulk_drop_ids.size() > 0) or (raw_bulk_removed_ids is Array and raw_bulk_removed_ids.size() > 0) or (raw_bulk_updated_drops is Array and raw_bulk_updated_drops.size() > 0):
		if apply_network_bulk_drop_pickup_result(data):
			return

	debug_action_position_flow("pickup/remove apply start", {
		"drop_id": str(data.get("drop_id", "")),
		"type": str(data.get("type", ""))
	})
	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	trace_drop_pickup_event("apply_remove_start", data, get_drop_by_id(drop_id))
	if drop_id != "":
		mark_drop_id_recently_removed(drop_id)
	var drop_data = get_drop_by_id(drop_id)
	if drop_data.is_empty():
		debug_action_position_flow("pickup/remove apply end", {
			"drop_id": str(data.get("drop_id", ""))
		})
		return

	var did_apply_player_state = bool(data.get("_server_inventory_update_applied", false))
	var is_local_pickup_remove_response := _is_drop_pickup_response_for_local_client(drop_data, data)
	if is_local_pickup_remove_response:
		record_drop_pickup_server_event("server_result_remove", drop_data, {
			"message_type": str(data.get("type", "")),
			"remaining_amount": data.get("remaining_amount", data.get("remaining", 0)),
			"drop_id": drop_id
		})
	if not did_apply_player_state and bool(data.get("_apply_pickup_inventory", true)) and is_local_pickup_remove_response:
		var previous_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		var previous_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var stack_limit = _get_stack_limit_for_drop_item(previous_type, previous_category)
		if stack_limit <= 0:
			stack_limit = 0
		var previous_is_weight: bool = _is_fish_drop_category(previous_category)
		var previous_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), previous_is_weight)
		var stacked_ids = _get_drop_stack_ids(drop_data)
		if stacked_ids.size() > 1 and stacked_ids.has(drop_id):
			previous_amount = min(previous_amount, max(0.1 if previous_is_weight else 1.0, _get_drop_stack_amount_for_id(drop_data, drop_id)))
		var remote_amount: float = _extract_drop_amount_from_payload(data, 0.0, previous_is_weight)
		remote_amount = _safe_drop_amount(remote_amount, 0.0, 0.0, previous_amount, previous_is_weight)
		var added_amount: float = _apply_authoritative_pickup_to_inventory(drop_data, previous_amount, remote_amount)
		if added_amount > 0.0:
			refresh_pickup_inventory_ui(previous_type, previous_category)

	var should_finish_vacuum: bool = bool(drop_data.get("pickup_requested", false)) or bool(drop_data.get("pickup_in_progress", false)) or bool(drop_data.get("pickup_request_sent", false)) or is_local_pickup_remove_response
	_clear_drop_pickup_flags(drop_data)
	var removed_id_lookup: Dictionary = {}
	removed_id_lookup[drop_id] = true
	var force_entire_stack := should_force_remove_entire_drop_stack(drop_data, removed_id_lookup)
	remove_drop_by_id(drop_id, should_finish_vacuum, force_entire_stack)
	process_queued_drop_pickups()
	trace_drop_pickup_event("apply_remove_done", data, get_drop_by_id(drop_id))
	debug_action_position_flow("pickup/remove apply end", {
		"drop_id": str(data.get("drop_id", ""))
	})


func get_front_drop_grid_position() -> Vector2i:
	if world == null:
		return Vector2i.ZERO

	var player_grid_pos = world.get_player_grid_position()
	return Vector2i(player_grid_pos.x + world.player_facing_direction, player_grid_pos.y)


func get_front_drop_world_position() -> Vector2:
	if world == null:
		return Vector2.ZERO

	var drop_grid_pos = get_front_drop_grid_position()
	return Vector2(drop_grid_pos.x * world.BLOCK_SIZE, drop_grid_pos.y * world.BLOCK_SIZE)


func is_drop_grid_blocked_by_block(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	if world.blocks.has(grid_pos):
		return true

	if world.block_manager != null and world.block_manager.has_method("get_anchor_grid_for_block_area"):
		var anchor_grid = world.block_manager.get_anchor_grid_for_block_area(grid_pos)
		return anchor_grid != world.INVALID_GRID_POS

	return false


func can_drop_inventory_item_at_front(show_notification: bool = false) -> bool:
	if world == null:
		return false

	var drop_grid_pos = get_front_drop_grid_position()

	if not world.is_grid_inside_world(drop_grid_pos):
		if show_notification:
			world.show_notification("Cannot drop outside world.")
		return false

	if is_drop_grid_blocked_by_block(drop_grid_pos):
		if show_notification:
			world.show_notification("Can't drop on a block.")
		return false

	return true


func request_server_drop_inventory_item(item_type: String, category: String, amount: float) -> bool:
	if world == null:
		return false

	if not should_use_server_authoritative_world_actions():
		return false

	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Almost ready. Try again in a moment.")
		return false

	var clean_item_type = _safe_string(item_type, "", MAX_ITEM_ID_LENGTH)
	if clean_item_type == "":
		return false

	var clean_category = _safe_string(category, "", MAX_ITEM_CATEGORY_LENGTH)
	var safe_amount: float = _safe_drop_amount(amount, 1.0, 1.0, float(MAX_DROP_STACK_SIZE), false)

	if not can_drop_inventory_item_at_front(true):
		return false

	var drop_grid_pos = get_front_drop_grid_position()
	var drop_world_position = get_front_drop_world_position()
	var payload_amount: float = float(int(round(safe_amount)))
	var payload: Dictionary = {
		"action": "drop_inventory_item",
		"world": world.current_world_name,
		"item_type": clean_item_type,
		"item_category": clean_category,
		"amount": payload_amount,
		"x": _safe_float(drop_world_position.x, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		"y": _safe_float(drop_world_position.y, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		"stack_grid_x": drop_grid_pos.x,
		"stack_grid_y": drop_grid_pos.y
	}
	var sent = bool(network.send_inventory_transaction_request(payload))
	if not sent:
		world.show_notification("Almost ready. Try again in a moment.")
	return sent


func drop_inventory_item_to_world(item_type: String, category: String) -> bool:
	if world == null or world.player == null:
		return false

	if should_use_server_authoritative_world_actions():
		return request_server_drop_inventory_item(item_type, category, 1)

	if not can_drop_inventory_item_at_front(true):
		return false

	create_item_drop(
		_safe_string(item_type, "", MAX_ITEM_ID_LENGTH),
		get_front_drop_world_position(),
		_safe_string(category, "", MAX_ITEM_CATEGORY_LENGTH) == "seed",
		_safe_string(category, "", MAX_ITEM_CATEGORY_LENGTH),
		1.0,
		1
	)
	return true


func drop_inventory_item_stack_to_world(item_type: String, category: String, amount: float) -> bool:
	if world == null or world.player == null:
		return false

	var clean_category = _safe_string(category, "", MAX_ITEM_CATEGORY_LENGTH)
	var safe_amount: float = _safe_drop_amount(amount, 1.0, 1.0, float(MAX_DROP_STACK_SIZE), false)

	if should_use_server_authoritative_world_actions():
		return request_server_drop_inventory_item(item_type, category, safe_amount)

	if not can_drop_inventory_item_at_front(true):
		return false

	create_item_drop(
		_safe_string(item_type, "", MAX_ITEM_ID_LENGTH),
		get_front_drop_world_position(),
		clean_category == "seed",
		clean_category,
		1.0,
		safe_amount
	)
	return true


func clear():
	if world == null:
		return

	for drop_data in world.dropped_items:
		var drop_node = drop_data["node"]

		if is_instance_valid(drop_node):
			drop_node.queue_free()
		remove_drop_count_controls(drop_data)

	world.dropped_items.clear()
	drops_by_id.clear()
	drops_by_cell.clear()
	drop_pickup_scan_elapsed = 0.0
	pending_pickup_ui_refreshes.clear()
	pending_pickup_ui_flush_at_ms = 0
	drop_queued_pickup_next_process_ms = 0
	reset_drop_pickup_debug_scan()
	reset_drop_pickup_send_budget()
