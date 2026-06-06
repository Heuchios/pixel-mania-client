extends Node

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const DROP_PICKUP_SCAN_INTERVAL := 1.0 / 60.0
const DROP_MAX_PICKUPS_PER_SCAN := 3
const DROP_PICKUP_REQUEST_TIMEOUT := 1.5
const DROP_PICKUP_REQUEST_MATCH_WINDOW_SECONDS := 2.0
const DROP_PICKUP_MAGNET_SPEED := 18.0
const DROP_PICKUP_REQUEST_ALPHA := 0.64
const MAX_DROP_ID_LENGTH := 64
const MAX_ITEM_ID_LENGTH := 64
const MAX_ITEM_CATEGORY_LENGTH := 64
const MAX_DROP_STACK_SIZE := 200
const MAX_REQUEST_ID_LENGTH := 64
const MAX_USERNAME_LENGTH := 64
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_DROP_PICKUP_DELAY_SECONDS := 120.0
const MAX_WORLD_COORD := 1000000.0
const DROP_PICKUP_REJECT_RETRY_COOLDOWN := 1.5
const DEBUG_ACTION_POSITION_FLOW := false
const DEBUG_DROP_PICKUP_FLOW := false
const DEBUG_DROP_PICKUP_AUDIT := false
const DROP_COUNT_LABEL_SIZE := Vector2(38, 16)
const DROP_COUNT_WORLD_OFFSET := Vector2(0, 9)
const DROP_COUNT_BASE_FONT_SIZE := 15
const DROP_COUNT_BASE_OUTLINE_SIZE := 3
const STACK_FULL_NOTIFICATION_COOLDOWN := 1.2
const PICKUP_RESULT_UNKNOWN_AMOUNT := -1
var world = null
var local_drop_sequence := 0
var drops_by_id := {}
var drops_by_cell := {}
var drop_pickup_scan_elapsed := 0.0
var stack_full_notification_cooldown := 0.0
var drop_count_overlay: Control = null
var applying_server_drop_payload := false


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
	ensure_drop_count_overlay()
	rebuild_drop_indexes()
	drop_pickup_scan_elapsed = 0.0


func ensure_drop_count_overlay() -> Control:
	if world == null or world.ui_layer == null:
		return null

	if drop_count_overlay == null or not is_instance_valid(drop_count_overlay):
		drop_count_overlay = world.ui_layer.get_node_or_null("DropCountOverlay")
		if drop_count_overlay == null:
			drop_count_overlay = Control.new()
			drop_count_overlay.name = "DropCountOverlay"
			world.ui_layer.add_child(drop_count_overlay)

	drop_count_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_count_overlay.z_index = 85
	drop_count_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_count_overlay.offset_left = 0.0
	drop_count_overlay.offset_top = 0.0
	drop_count_overlay.offset_right = 0.0
	drop_count_overlay.offset_bottom = 0.0
	drop_count_overlay.visible = true

	return drop_count_overlay


func create_drop_count_controls(drop_data: Dictionary):
	var overlay = ensure_drop_count_overlay()
	if overlay == null:
		return

	remove_drop_count_controls(drop_data)

	var count_label = Label.new()
	count_label.name = "DropCount"
	count_label.size = DROP_COUNT_LABEL_SIZE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	count_label.visible = false
	overlay.add_child(count_label)

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


func get_world_to_screen_position(world_position: Vector2) -> Vector2:
	if world == null:
		return world_position

	var overlay = ensure_drop_count_overlay()
	if overlay == null:
		return world_position

	var canvas_transform = overlay.get_viewport().get_canvas_transform()
	return canvas_transform * world_position


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
	var position = Vector2(
		_safe_float(drop_data.get("x", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		_safe_float(drop_data.get("y", 0.0), 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD)
	)

	if is_instance_valid(drop_node):
		position = drop_node.global_position

	if not is_finite(position.x) or not is_finite(position.y):
		position = Vector2.ZERO

	var payload_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var payload_is_weight: bool = _is_fish_drop_category(payload_category)
	return {
		"drop_id": _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH),
		"item_type": _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH),
		"item_category": payload_category,
		"is_seed": _safe_bool(drop_data.get("is_seed", false), false),
		"amount": _safe_drop_amount(drop_data.get("amount", 1.0), 1.0, 0.1 if payload_is_weight else 1.0, float(MAX_DROP_TILE_AMOUNT), payload_is_weight),
		"x": position.x,
		"y": position.y,
		"stack_grid_x": _safe_int(drop_data.get("stack_grid_x", _safe_int(round(position.x / world.BLOCK_SIZE), 0, 0, 999999)), 0, 0, 999999),
		"stack_grid_y": _safe_int(drop_data.get("stack_grid_y", _safe_int(round(position.y / world.BLOCK_SIZE), 0, 0, 999999)), 0, 0, 999999),
		"pickup_delay": _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)
	}


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
			"drop_id": get_pickup_drop_id(drop_data)
		}
		if payload["drop_id"] == "":
			return false
		var pickup_category: String = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		var pickup_is_weight: bool = _is_fish_drop_category(pickup_category)
		var pickup_amount: float = _safe_drop_amount(drop_data.get("pickup_requested_amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), pickup_is_weight)
		if pickup_amount > 0.0:
			payload["amount"] = pickup_amount
			payload["item_type"] = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
			payload["item_category"] = pickup_category
		var already_sent_drop_id = _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		var request_age = _safe_float(drop_data.get("pickup_requested_age", 0.0), 0.0, 0.0, DROP_PICKUP_REQUEST_TIMEOUT * 2.0)
		if bool(drop_data.get("pickup_request_sent", false)) and already_sent_drop_id == payload["drop_id"] and request_age < DROP_PICKUP_REQUEST_TIMEOUT:
			return true
		var local_player_id = _safe_string(network.get("player_id"), "", MAX_REQUEST_ID_LENGTH)
		drop_data["pickup_requested_by"] = local_player_id
		drop_data["pickup_requested_drop_id"] = _safe_string(payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
		drop_data["pickup_request_ms"] = Time.get_ticks_msec()
		drop_data["pickup_request_sent"] = true

		# Client only requests pickup. Server must authoritatively validate and compute amount.
		debug_drop_pickup_flow("send pickup request", drop_data, {
			"payload": payload.duplicate(true)
		})
		debug_action_position_flow("pickup request send", {
			"drop_id": str(payload.get("drop_id", ""))
		})
		var sent = bool(network.send_world_item_drop_pickup(payload))
		debug_action_position_flow("pickup request end", {
			"drop_id": str(payload.get("drop_id", "")),
			"sent": sent
		})
		return sent
	return false


func get_item_drop_texture(item_type: String, item_category: String):
	if world == null:
		return null

	if item_category == "block" and world.block_textures.has(item_type):
		return world.block_textures[item_type]

	if item_category == "seed" and world.seed_textures.has(item_type):
		return world.seed_textures[item_type]

	if item_category == "tool" and world.tool_textures.has(item_type):
		return world.tool_textures[item_type]

	if item_category == "currency" and world.currency_textures.has(item_type):
		return world.currency_textures[item_type]

	if item_category == "material" and world.material_textures.has(item_type):
		return world.material_textures[item_type]

	if item_category == "lure" and world.lure_textures.has(item_type):
		return world.lure_textures[item_type]

	if item_category == "fish" and world.fish_textures.has(item_type):
		return world.fish_textures[item_type]

	if item_category == "back" and world.back_textures.has(item_type):
		return world.back_textures[item_type]

	if item_category == "hair" and world.hair_textures.has(item_type):
		return world.hair_textures[item_type]

	if item_category == "shirt" and world.shirt_textures.has(item_type):
		return world.shirt_textures[item_type]

	if item_category == "pants" and world.pants_textures.has(item_type):
		return world.pants_textures[item_type]

	if item_category == "shoes" and world.shoes_textures.has(item_type):
		return world.shoes_textures[item_type]

	if world.item_database.has(item_type):
		var loaded_texture = AtlasTextureFactory.load_texture(world.item_database[item_type].get("texture", null))

		if loaded_texture != null:
			match item_category:
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
				"hair":
					world.hair_textures[item_type] = loaded_texture
				"shirt":
					world.shirt_textures[item_type] = loaded_texture
				"pants":
					world.pants_textures[item_type] = loaded_texture
				"shoes":
					world.shoes_textures[item_type] = loaded_texture

			return loaded_texture

	return null


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
				elif world.hair_textures.has(item_type):
					item_category = "hair"
				elif world.pants_textures.has(item_type):
					item_category = "pants"
				elif world.shoes_textures.has(item_type):
					item_category = "shoes"
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
	var stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
	if stack_limit <= 0:
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

	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = get_item_drop_texture(item_type, item_category)

	if item_category == "seed":
		sprite.scale = Vector2(0.75, 0.75)
	elif item_category == "tool":
		sprite.scale = Vector2(0.55, 0.55)
	elif item_category == "currency":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "material":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "lure":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "fish":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "back":
		if item_type == "legendary_wings":
			sprite.scale = Vector2(0.05, 0.05)
		else:
			sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "hair":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "shirt":
		sprite.scale = Vector2(0.62, 0.62)
	elif item_category == "pants":
		sprite.scale = Vector2(0.62, 0.62)
	else:
		sprite.scale = Vector2(0.5, 0.5)

	drop.z_index = 40
	sprite.z_index = 40
	drop.add_child(sprite)

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
	sync_drop_node_metadata(drop_data)
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
	if amount <= 0:
		return false
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH).to_lower()
	if item_category == "fish":
		return amount > 0.0
	if amount > 1:
		return true

	return item_category == "block" or item_category == "seed" or _safe_bool(drop_data.get("is_seed", false), false)


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
		var item_type: String = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		var item_name: String = item_type.capitalize()
		if world != null and world.has_method("get_item_display_name"):
			item_name = world.get_item_display_name(item_type, "fish")
		count_text = item_name + " " + ("%.1f lb" % amount)
	elif should_show_drop_count_label(drop_data, amount):
		count_text = format_stack_count(int(round(amount)))
	count_label.text = count_text
	count_label.visible = count_text != ""

	if count_text != "":
		update_drop_count_screen_position(drop_data)


func update_drop_count_screen_position(drop_data: Dictionary):
	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
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

	var screen_scale = get_drop_count_screen_scale()
	var label_base_size: Vector2 = DROP_COUNT_LABEL_SIZE
	if _is_fish_drop_category(str(drop_data.get("item_category", ""))):
		label_base_size = Vector2(132, DROP_COUNT_LABEL_SIZE.y)
	var label_size = label_base_size * screen_scale
	var font_size = max(6, int(round(float(DROP_COUNT_BASE_FONT_SIZE) * screen_scale)))
	var outline_size = max(1, int(round(float(DROP_COUNT_BASE_OUTLINE_SIZE) * screen_scale)))
	var screen_position = get_world_to_screen_position(drop_node.global_position + DROP_COUNT_WORLD_OFFSET)
	count_label.size = label_size
	count_label.position = Vector2(
		round(screen_position.x - label_size.x * 0.5),
		round(screen_position.y)
	)
	count_label.add_theme_font_size_override("font_size", font_size)
	count_label.add_theme_constant_override("outline_size", outline_size)
	count_label.modulate.a = drop_node.modulate.a


func is_drop_stack_covered(drop_data) -> bool:
	if world == null:
		return false

	var stack_grid = Vector2i(
		_safe_int(drop_data.get("stack_grid_x", 0), 0, 0, 999999),
		_safe_int(drop_data.get("stack_grid_y", 0), 0, 0, 999999)
	)
	return world.blocks.has(stack_grid)


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
	if world.hair_inventory.has(safe_item_type):
		return {"inventory": world.hair_inventory, "category": "hair"}
	if world.shirt_inventory.has(safe_item_type):
		return {"inventory": world.shirt_inventory, "category": "shirt"}
	if world.pants_inventory.has(safe_item_type):
		return {"inventory": world.pants_inventory, "category": "pants"}
	if world.shoes_inventory.has(safe_item_type):
		return {"inventory": world.shoes_inventory, "category": "shoes"}
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
		"hair":
			return {"inventory": world.hair_inventory, "category": "hair"}
		"shirt":
			return {"inventory": world.shirt_inventory, "category": "shirt"}
		"pants":
			return {"inventory": world.pants_inventory, "category": "pants"}
		"shoes":
			return {"inventory": world.shoes_inventory, "category": "shoes"}
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
	var current_count: float = _safe_drop_amount(latest_inventory.get(safe_item_type, 0.0), 0.0, 0.0, float(latest_limit), latest_is_weight)
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
		latest_inventory[safe_item_type] = next_weight
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

	var stack_limit = _get_stack_limit_for_drop_item(item_type, item_category)
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

	var planned_add = _get_max_addable_to_inventory(item_type, item_category, drop_amount, safe_drop_id)
	if planned_add <= 0:
		show_stack_full_notification()
		return 0

	drop_data["pickup_requested"] = true
	drop_data["pickup_requested_age"] = 0.0
	drop_data["pickup_in_progress"] = true
	drop_data["pickup_requested_amount"] = planned_add
	if not send_network_drop_pickup(drop_data):
		_clear_drop_pickup_flags(drop_data)
		return 0

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
		if not is_requesting and not is_in_progress:
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


func has_better_same_item_pickup_candidate(drop_data: Dictionary, player_position: Vector2, pickup_range_sq: float, available_room: float) -> bool:
	if world == null:
		return false

	var drop_node = drop_data.get("node", null)
	if not is_instance_valid(drop_node):
		return false

	var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	var is_weight: bool = _is_fish_drop_category(item_category)
	var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)

	for raw_candidate in world.dropped_items:
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

	drop_pickup_scan_elapsed += delta
	stack_full_notification_cooldown = max(0.0, stack_full_notification_cooldown - delta)

	var should_scan_pickups := drop_pickup_scan_elapsed >= DROP_PICKUP_SCAN_INTERVAL
	if should_scan_pickups:
		drop_pickup_scan_elapsed = 0.0

	var has_player := world.player != null
	var player_position := Vector2.ZERO
	var pickup_range_sq := 0.0
	var pickups_this_scan := 0
	var picked_stack_keys_this_scan := {}

	if has_player:
		player_position = world.player.global_position
		pickup_range_sq = float(world.PICKUP_RANGE * world.PICKUP_RANGE)

	for i in range(world.dropped_items.size() - 1, -1, -1):
		var drop_data = world.dropped_items[i]
		var drop_node = drop_data["node"]

		if not is_instance_valid(drop_node):
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
		if pickup_requested:
			var pickup_requested_age: float = _safe_float(drop_data.get("pickup_requested_age", 0.0), 0.0, 0.0, DROP_PICKUP_REQUEST_TIMEOUT * 2.0) + delta
			drop_data["pickup_requested_age"] = pickup_requested_age

			if pickup_requested_age >= DROP_PICKUP_REQUEST_TIMEOUT:
				_clear_drop_pickup_flags(drop_data)
				drop_node.modulate.a = 1.0
				drop_node.scale = Vector2.ONE
				if is_instance_valid(drop_node):
					drop_data["start_y"] = drop_node.position.y
				world.dropped_items[i] = drop_data
				pickup_requested = false
			elif has_player:
				var magnet_alpha = clamp(delta * DROP_PICKUP_MAGNET_SPEED, 0.0, 1.0)
				drop_node.global_position = drop_node.global_position.lerp(player_position, magnet_alpha)
				drop_node.modulate.a = DROP_PICKUP_REQUEST_ALPHA
				drop_node.scale = drop_node.scale.lerp(Vector2(0.86, 0.86), magnet_alpha)
				update_drop_count_screen_position(drop_data)
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
			var blocked_until_ms = int(drop_data.get("pickup_blocked_until_ms", 0))
			if blocked_until_ms > Time.get_ticks_msec():
				continue
			elif blocked_until_ms > 0:
				drop_data.erase("pickup_blocked_until_ms")

			var pickup_delay = _safe_float(drop_data.get("pickup_delay", 0.0), 0.0, 0.0, MAX_DROP_PICKUP_DELAY_SECONDS)

			if drop_data["age"] >= pickup_delay and player_position.distance_squared_to(drop_node.global_position) <= pickup_range_sq:
				if is_drop_stack_covered(drop_data):
					continue

				var drop_item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
				var drop_item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
				var drop_target = get_inventory_target_for_drop(drop_item_type, drop_item_category)
				var drop_target_category = _safe_string(drop_target.get("category", drop_item_category), drop_item_category, MAX_ITEM_CATEGORY_LENGTH)
				var pickup_stack_key = drop_target_category + ":" + drop_item_type
				if picked_stack_keys_this_scan.has(pickup_stack_key):
					continue

				if get_pending_pickup_amount_for_stack(drop_item_type, drop_target_category) > 0:
					continue

				var is_weight_drop: bool = _is_fish_drop_category(drop_target_category)
				var drop_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight_drop)
				var available_room: float = get_drop_inventory_room(drop_data)
				if available_room <= 0:
					show_stack_full_notification()
					continue

				if has_better_same_item_pickup_candidate(drop_data, player_position, pickup_range_sq, available_room):
					continue

				var pickup_amount = _calculate_pickup_add_amount(drop_item_type, drop_target_category, drop_amount)
				if pickup_amount > available_room:
					pickup_amount = available_room
				if should_use_server_authoritative_world_actions():
					if bool(drop_data.get("pickup_requested", false)):
						continue
					drop_data["pickup_requested"] = true
					drop_data["pickup_requested_age"] = 0.0
					drop_data["pickup_requested_amount"] = pickup_amount
					drop_data["pickup_in_progress"] = true
					world.dropped_items[i] = drop_data
					if not send_network_drop_pickup(drop_data):
						drop_data["pickup_requested"] = false
						drop_data["pickup_requested_age"] = 0.0
						drop_data["pickup_in_progress"] = false
						drop_data.erase("pickup_requested_amount")
						world.dropped_items[i] = drop_data
					else:
						picked_stack_keys_this_scan[pickup_stack_key] = true
						pickups_this_scan += 1
					continue

				if not collect_drop(drop_data):
					world.dropped_items[i] = drop_data
					continue

				send_network_drop_pickup(drop_data)
				remove_drop_count_controls(drop_data)
				unregister_drop(drop_data)
				drop_node.queue_free()
				world.dropped_items.remove_at(i)
				picked_stack_keys_this_scan[pickup_stack_key] = true
				pickups_this_scan += 1


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
		world.update_all_ui()
		return false

	world.update_all_ui()
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
		{"label": "Case 1: inventory 50/200 + drop 200", "inv_before": 50},
		{"label": "Case 2: inventory 0/200 + drop 200", "inv_before": 0},
		{"label": "Case 3: inventory 199/200 + drop 200", "inv_before": 199},
		{"label": "Case 4: inventory 200/200 + drop 200", "inv_before": 200}
	]

	for scenario in scenarios:
		var start_count = _safe_int(scenario["inv_before"], 0, 0, stack_limit)
		world.inventory[item_type] = start_count
		var drop_amount = 200
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


func remove_drop_by_id(drop_id: String) -> bool:
	if world == null:
		return false

	var clean_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if clean_id == "":
		return false

	if drops_by_id.has(clean_id):
		var indexed_drop: Dictionary = drops_by_id[clean_id]
		var indexed_node = indexed_drop.get("node", null)
		var aliases = _get_drop_stack_ids(indexed_drop)
		if aliases.size() > 1:
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
				update_drop_count_label(indexed_drop)
				if world != null:
					world.update_all_ui()
				return true

		if is_instance_valid(indexed_node):
			indexed_node.queue_free()
		remove_drop_count_controls(indexed_drop)
		unregister_drop(indexed_drop)
		world.dropped_items.erase(indexed_drop)
		return true

	for i in range(world.dropped_items.size() - 1, -1, -1):
		var drop_data = world.dropped_items[i]
		if str(drop_data.get("drop_id", "")) != clean_id:
			continue

		var drop_node = drop_data.get("node", null)
		if is_instance_valid(drop_node):
			drop_node.queue_free()

		remove_drop_count_controls(drop_data)
		unregister_drop(drop_data)
		world.dropped_items.remove_at(i)
		return true

	return false


func cancel_pending_pickup_for_drop(drop_id: String) -> void:
	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	if safe_drop_id == "":
		return

	var drop_data = get_drop_by_id(safe_drop_id)
	if drop_data.is_empty():
		return

	_clear_drop_pickup_flags(drop_data)

	var drop_node = drop_data.get("node", null)
	if is_instance_valid(drop_node):
		drop_node.modulate.a = 1.0
		drop_node.scale = Vector2.ONE
		drop_node.position = Vector2(drop_node.position.x, drop_node.position.y)
		drop_data["start_y"] = drop_node.position.y


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
		var drop_node = drop_data.get("node", null)
		if is_instance_valid(drop_node):
			drop_node.modulate.a = 1.0
			drop_node.scale = Vector2.ONE
			drop_data["start_y"] = drop_node.position.y


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


func handle_rejected_drop_pickup(drop_id: String, message: String = "") -> bool:
	var safe_drop_id = _safe_string(drop_id, "", MAX_DROP_ID_LENGTH)
	var clean_message = _safe_string(message, "", 256).to_lower()

	if safe_drop_id == "":
		if clean_message.find("not available") >= 0:
			var pending_drop = get_pending_drop_for_rejection("")
			if pending_drop.is_empty():
				cancel_all_pending_pickups()
				return false
			safe_drop_id = _safe_string(pending_drop.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
			if safe_drop_id == "":
				safe_drop_id = get_pickup_drop_id(pending_drop)
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
		cancel_all_pending_pickups()
		return false

	if safe_drop_id == "" and not drop_data.is_empty():
		safe_drop_id = _safe_string(drop_data.get("pickup_requested_drop_id", ""), "", MAX_DROP_ID_LENGTH)
		if safe_drop_id == "":
			safe_drop_id = get_pickup_drop_id(drop_data)
	if not drop_data.is_empty():
		debug_drop_pickup_flow("server rejected pickup", drop_data, {
			"message": message,
			"rejected_drop_id": safe_drop_id,
			"world_drop_count": world.dropped_items.size() if world != null else 0,
			"exists_locally": true
		})

	if clean_message.find("inventory full") >= 0 or clean_message.find("could not add") >= 0:
		if drop_data.is_empty():
			cancel_all_pending_pickups()
			return false

		_clear_drop_pickup_flags(drop_data)
		drop_data["pickup_blocked_until_ms"] = Time.get_ticks_msec() + int(DROP_PICKUP_REJECT_RETRY_COOLDOWN * 1000.0)
		var rejected_drop_node = drop_data.get("node", null)
		if is_instance_valid(rejected_drop_node):
			rejected_drop_node.modulate.a = 1.0
			rejected_drop_node.scale = Vector2.ONE
			drop_data["start_y"] = rejected_drop_node.position.y
		show_stack_full_notification()
		if world != null and world.has_method("request_network_player_state"):
			world.request_network_player_state()
		return true

	if clean_message.find("not available") >= 0:
		if drop_data.is_empty():
			cancel_all_pending_pickups()
			return false

		var aliases = _get_drop_stack_ids(drop_data)
		if aliases.size() > 1 and safe_drop_id != "":
			var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			var is_weight: bool = _is_fish_drop_category(item_category)
			var current_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			var stale_amount: float = _safe_drop_amount(_get_drop_stack_amount_for_id(drop_data, safe_drop_id), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			if stale_amount <= 0.0:
				stale_amount = 0.1 if is_weight else 1.0
			drop_data["amount"] = _safe_drop_amount(max(0.0, current_amount - stale_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			unregister_drop_id(drop_data, safe_drop_id)
			_clear_drop_pickup_flags(drop_data)

			var remaining_amount: float = _safe_drop_amount(drop_data.get("amount", 0.0), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), is_weight)
			if remaining_amount > 0.0 and not _get_drop_stack_ids(drop_data).is_empty():
				update_drop_count_label(drop_data)
				var item_type = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
				var planned_add = _get_max_addable_to_inventory(
					item_type,
					item_category,
					remaining_amount,
					get_pickup_drop_id(drop_data)
				)
				if planned_add > 0:
					drop_data["pickup_requested"] = true
					drop_data["pickup_requested_age"] = 0.0
					drop_data["pickup_in_progress"] = true
					drop_data["pickup_requested_amount"] = planned_add
					if send_network_drop_pickup(drop_data):
						return true
				_clear_drop_pickup_flags(drop_data)
				return true

			remove_drop_by_id(safe_drop_id)
			return true

		_clear_drop_pickup_flags(drop_data)
		var drop_node = drop_data.get("node", null)
		if is_instance_valid(drop_node):
			drop_node.modulate.a = 1.0
			drop_node.scale = Vector2.ONE
			drop_data["start_y"] = drop_node.position.y
		return false

	if safe_drop_id != "":
		cancel_pending_pickup_for_drop(safe_drop_id)
	else:
		cancel_all_pending_pickups()
	return false


func apply_network_item_drop_create(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	if drop_id == "":
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


func apply_network_item_drop_update(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	if drop_id == "":
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
	if is_stacked_alias_update:
		amount = _safe_drop_amount(previous_amount - max(0.0, alias_previous_amount - alias_remote_amount), 0.0, 0.0, float(MAX_DROP_TILE_AMOUNT), current_is_weight)

	var did_apply_player_state = bool(data.get("_server_inventory_update_applied", false))
	var applied_amount: float = 0.0
	if not did_apply_player_state and bool(data.get("_apply_pickup_inventory", true)) and _is_drop_pickup_response_for_local_client(drop_data, data):
		var pickup_previous_amount = alias_previous_amount if is_stacked_alias_update else previous_amount
		var pickup_remote_amount = alias_remote_amount if is_stacked_alias_update else amount
		applied_amount = _apply_authoritative_pickup_to_inventory(drop_data, pickup_previous_amount, pickup_remote_amount)
		if applied_amount > 0:
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

	if amount <= 0:
		remove_drop_by_id(drop_id)
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
		drop_node.modulate.a = 1.0
		drop_node.scale = Vector2.ONE

	if is_instance_valid(drop_node) and data.has("x") and data.has("y"):
		unregister_drop(drop_data)
		var position = Vector2(
			_safe_float(data.get("x", 0.0), drop_data.get("x", 0.0), -MAX_WORLD_COORD, MAX_WORLD_COORD),
			_safe_float(data.get("y", 0.0), drop_data.get("y", 0.0), -MAX_WORLD_COORD, MAX_WORLD_COORD)
		)
		if data.has("stack_grid_x") and data.has("stack_grid_y"):
			var server_stack_grid = _safe_grid_position(data.get("stack_grid_x"), data.get("stack_grid_y"))
			position = Vector2(server_stack_grid.x * world.BLOCK_SIZE, server_stack_grid.y * world.BLOCK_SIZE)
		drop_node.global_position = position
		var stack_grid = get_drop_stack_grid(position)
		drop_data["x"] = position.x
		drop_data["y"] = position.y
		drop_data["stack_grid_x"] = stack_grid.x
		drop_data["stack_grid_y"] = stack_grid.y
		drop_data["start_y"] = drop_node.position.y
		register_drop(drop_data)
	else:
		register_drop(drop_data)

	update_drop_count_label(drop_data)
	if world != null:
		world.update_all_ui()


func apply_network_item_drop_remove(data: Dictionary):
	if not is_drop_message_for_current_world(data):
		return

	debug_action_position_flow("pickup/remove apply start", {
		"drop_id": str(data.get("drop_id", "")),
		"type": str(data.get("type", ""))
	})
	var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	var drop_data = get_drop_by_id(drop_id)
	if drop_data.is_empty():
		debug_action_position_flow("pickup/remove apply end", {
			"drop_id": str(data.get("drop_id", ""))
		})
		return

	var did_apply_player_state = bool(data.get("_server_inventory_update_applied", false))
	if not did_apply_player_state and bool(data.get("_apply_pickup_inventory", true)) and _is_drop_pickup_response_for_local_client(drop_data, data):
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
		_apply_authoritative_pickup_to_inventory(drop_data, previous_amount, remote_amount)

	_clear_drop_pickup_flags(drop_data)
	remove_drop_by_id(drop_id)
	if world != null:
		world.update_all_ui()
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
	var safe_amount: float = _safe_drop_amount(amount, 1.0, 0.1 if _is_fish_drop_category(clean_category) else 1.0, float(MAX_DROP_STACK_SIZE), _is_fish_drop_category(clean_category))

	if not can_drop_inventory_item_at_front(true):
		return false

	var drop_grid_pos = get_front_drop_grid_position()
	var drop_world_position = get_front_drop_world_position()
	var sent = bool(network.send_inventory_transaction_request({
		"action": "drop_inventory_item",
		"world": world.current_world_name,
		"item_type": clean_item_type,
		"item_category": clean_category,
		"amount": safe_amount,
		"x": _safe_float(drop_world_position.x, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		"y": _safe_float(drop_world_position.y, 0.0, -MAX_WORLD_COORD, MAX_WORLD_COORD),
		"stack_grid_x": drop_grid_pos.x,
		"stack_grid_y": drop_grid_pos.y
	}))
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
	var safe_amount: float = _safe_drop_amount(amount, 1.0, 0.1 if _is_fish_drop_category(clean_category) else 1.0, float(MAX_DROP_STACK_SIZE), _is_fish_drop_category(clean_category))

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
