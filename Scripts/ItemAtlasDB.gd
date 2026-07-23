extends RefCounted
class_name ItemAtlasDB

const ATLAS_ITEMS_PATH := "res://Data/items/atlas_items.json"
const FALLBACK_ATLAS_TEXTURE_PATH := "res://image.png"
const DEFAULT_TILE_SIZE := Vector2i(32, 32)

static var _loaded := false
static var _loaded_modified_time := -1
static var _items_by_id: Dictionary = {}
static var _ids_by_key: Dictionary = {}
static var _icon_cache: Dictionary = {}


static func _get_source_modified_time() -> int:
	var global_path := ProjectSettings.globalize_path(ATLAS_ITEMS_PATH)
	if global_path == "":
		return -1
	return int(FileAccess.get_modified_time(global_path))


static func reload() -> void:
	_loaded = false
	_loaded_modified_time = -1
	_items_by_id.clear()
	_ids_by_key.clear()
	_icon_cache.clear()
	_ensure_loaded()


static func has_source_changed() -> bool:
	if not _loaded:
		return false
	return _get_source_modified_time() != _loaded_modified_time


static func _ensure_loaded() -> void:
	var current_modified_time := _get_source_modified_time()
	if _loaded and current_modified_time == _loaded_modified_time:
		return

	_loaded = true
	_loaded_modified_time = current_modified_time
	_items_by_id.clear()
	_ids_by_key.clear()
	_icon_cache.clear()

	var file := FileAccess.open(ATLAS_ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_warning("ItemAtlasDB: missing atlas item database at " + ATLAS_ITEMS_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("ItemAtlasDB: atlas item database JSON is invalid.")
		return

	var items = (parsed as Dictionary).get("items", [])
	if not (items is Array):
		push_warning("ItemAtlasDB: atlas item database must contain an items array.")
		return

	for raw_item in items:
		if raw_item is Dictionary:
			_register_item(raw_item as Dictionary)


static func _register_item(raw_item: Dictionary) -> void:
	var item_id := int(raw_item.get("id", 0))
	if item_id <= 0:
		return

	var item := raw_item.duplicate(true)
	item["id"] = item_id
	item["item_key"] = _normalize_item_key(item.get("item_key", ""))
	item["layer"] = _normalize_layer(item.get("layer", "foreground"))
	item["source_id"] = int(item.get("source_id", 0))
	item["alternative_tile"] = int(item.get("alternative_tile", 0))
	item["atlas_coords"] = _to_vector2i(item.get("atlas_coords", [0, 0]))
	item["atlas_enabled"] = bool(item.get("atlas_enabled", true))
	item["collision"] = bool(item.get("collision", false))
	item["collision_type"] = str(item.get("collision_type", "full" if bool(item.get("collision", false)) else "none")).strip_edges().to_lower()
	item["hardness"] = maxi(1, int(item.get("hardness", item.get("block_health", 1))))

	_items_by_id[item_id] = item
	var item_key := str(item.get("item_key", ""))
	if item_key != "":
		_ids_by_key[item_key] = item_id


static func _normalize_item_key(value) -> String:
	return str(value).strip_edges().to_lower()


static func _normalize_layer(value) -> String:
	var clean := str(value).strip_edges().to_lower()
	return "background" if clean == "background" else "foreground"


static func _to_vector2i(value, fallback := Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		return Vector2i(int(value.get("x", fallback.x)), int(value.get("y", fallback.y)))
	if value is String:
		var parts := str(value).split(",", false)
		if parts.size() >= 2 and str(parts[0]).strip_edges().is_valid_int() and str(parts[1]).strip_edges().is_valid_int():
			return Vector2i(int(str(parts[0]).strip_edges()), int(str(parts[1]).strip_edges()))
	return fallback


static func _to_array(value) -> Array:
	var coords := _to_vector2i(value)
	return [coords.x, coords.y]


static func _to_vector2i_array(value) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for raw_entry in value:
		result.append(_to_vector2i(raw_entry))
	return result


static func _get_items() -> Dictionary:
	_ensure_loaded()
	return _items_by_id


static func get_item(item_id: int) -> Dictionary:
	_ensure_loaded()
	var item = _items_by_id.get(int(item_id), {})
	if item is Dictionary:
		return (item as Dictionary).duplicate(true)
	return {}


static func has_item(item_id: int) -> bool:
	_ensure_loaded()
	return _items_by_id.has(int(item_id))


static func get_source_id(item_id: int) -> int:
	return int(get_item(item_id).get("source_id", 0))


static func get_atlas_coords(item_id: int) -> Vector2i:
	return _to_vector2i(get_item(item_id).get("atlas_coords", Vector2i.ZERO))


static func get_alternative_tile(item_id: int) -> int:
	return int(get_item(item_id).get("alternative_tile", 0))


static func get_layer(item_id: int) -> String:
	return _normalize_layer(get_item(item_id).get("layer", "foreground"))


static func is_foreground(item_id: int) -> bool:
	return get_layer(item_id) == "foreground"


static func is_background(item_id: int) -> bool:
	return get_layer(item_id) == "background"


static func has_collision(item_id: int) -> bool:
	var item := get_item(item_id)
	return bool(item.get("collision", false)) and get_layer(item_id) == "foreground"


static func get_item_key(item_id: int) -> String:
	return _normalize_item_key(get_item(item_id).get("item_key", ""))


static func get_item_id_for_key(item_key: String) -> int:
	_ensure_loaded()
	return int(_ids_by_key.get(_normalize_item_key(item_key), 0))


static func resolve_item_key(value) -> String:
	if value is int or value is float:
		return get_item_key(int(value))
	var text := str(value).strip_edges()
	if text.is_valid_int():
		var item_key := get_item_key(int(text))
		if item_key != "":
			return item_key
	return _normalize_item_key(text)


static func get_item_database_entries() -> Dictionary:
	_ensure_loaded()
	var result := {}
	for item_id in _items_by_id.keys():
		var item: Dictionary = _items_by_id[item_id]
		var item_key := str(item.get("item_key", ""))
		if item_key == "":
			continue
		if not bool(item.get("atlas_enabled", true)):
			result[item_key] = {
				"atlas_item_id": int(item_id)
			}
			continue

		var layer := _normalize_layer(item.get("layer", "foreground"))
		var platform_collision := bool(item.get("platform_collision", false))
		var entry := {
			"category": str(item.get("type", "block")),
			"display_name": str(item.get("name", item_key.capitalize())),
			"block_health": int(item.get("hardness", 1)),
			"atlas_item_id": int(item_id),
			"atlas_source_id": int(item.get("source_id", 0)),
			"source_id": int(item.get("source_id", 0)),
			"atlas_coords": _to_vector2i(item.get("atlas_coords", Vector2i.ZERO)),
			"alternative_tile": int(item.get("alternative_tile", 0)),
			"place_layer": layer,
			"solid": has_collision(int(item_id)),
			"collision_type": str(item.get("collision_type", "full" if has_collision(int(item_id)) else "none"))
		}
		if platform_collision:
			entry["platform_collision"] = true
		if layer == "background":
			entry["background_block"] = true
			entry["no_collision"] = true
			entry["collidable"] = false
		elif not has_collision(int(item_id)) and not platform_collision:
			entry["no_collision"] = true
			entry["collidable"] = false
		if bool(item.get("animated", false)):
			entry["animated"] = true
		var animation_frames := _to_vector2i_array(item.get("animation_frames", []))
		if animation_frames.size() > 1:
			entry["animation_atlas_coords"] = animation_frames
			entry["animation_frames"] = animation_frames
			entry["tileset_animation"] = false
			entry["animated"] = true
			if str(item.get("animation_trigger", "")).strip_edges().to_lower() == "on_enter" and item_key.find("entrance") >= 0:
				entry["entrance_block"] = true
				entry["entrance_tilemap_collision"] = has_collision(int(item_id))
				entry["entrance_idle_atlas_coords"] = _to_vector2i(item.get("atlas_coords", Vector2i.ZERO))
				entry["entrance_pass_atlas_frames"] = animation_frames
		for passthrough_key in [
			"checkpoint_block",
			"checkpoint_inactive_atlas_coords",
			"checkpoint_active_atlas_coords",
			"springboard_animation_atlas_frames",
			"entrance_block",
			"entrance_tilemap_collision",
			"entrance_idle_atlas_coords",
			"entrance_pass_atlas_coords",
			"entrance_pass_atlas_frames",
			"entrance_pass_animation_columns",
			"animation_trigger",
			"animation_frame_seconds",
			"running_animation_frames",
			"running_animation_loop_frames",
			"running_animation_frame_seconds",
			"drop_rules",
			"tree_drop_rules",
			"texture",
			"inventory_icon",
			"foreground_over_player",
			"display_block",
			"fish_hanger_block",
			"display_preview_max_size",
			"display_preview_alpha",
			"display_preview_offset",
			"display_glass_alpha",
			"display_glass_size",
			"donation_box_block",
			"donation_box_empty_texture",
			"donation_box_full_texture",
			"donation_box_empty_animation_frame",
			"donation_box_full_animation_frame",
			"door_block",
			"portal_block",
			"auto_door_enter",
			"interact_rules",
			"permissions",
			"punch_toggle_block",
			"toggle_active_block",
			"toggle_inactive_block",
			"toggle_drop_block",
			"hidden",
			"placeable",
			"dropable",
			"tradeable",
			"admin_grantable",
			"instant_death",
			"hazard_instant_death",
			"chicken_block",
			"chicken_feed_item_id",
			"chicken_feed_item_category",
			"chicken_production_seconds",
			"chicken_hunger_seconds",
			"chicken_reward_item_id",
			"chicken_golden_reward_item_id",
			"chicken_golden_reward_chance",
			"chicken_hungry_atlas_coords",
			"chicken_producing_atlas_coords",
			"chicken_ready_atlas_coords",
			"cow_block",
			"cow_feed_item_id",
			"cow_feed_item_category",
			"cow_production_seconds",
			"cow_hunger_seconds",
			"cow_reward_item_id",
			"cow_hungry_atlas_coords",
			"cow_producing_atlas_coords",
			"cow_ready_atlas_coords",
			"duck_block",
			"duck_feed_item_id",
			"duck_feed_item_category",
			"duck_production_seconds",
			"duck_hunger_seconds",
			"duck_reward_table",
			"duck_hungry_atlas_coords",
			"duck_producing_atlas_coords",
			"duck_ready_atlas_coords",
			"battery_charger_block",
			"water_well_block",
			"water_well_cooldown_seconds",
			"water_well_reward_item_id",
			"water_well_reward_item_category",
			"water_well_reward_amount_range",
			"water_well_producing_atlas_coords",
			"water_well_ready_atlas_coords",
			"water_lower_atlas_coords",
			"platform_variant_atlas_coords",
			"vertical_variant_atlas_coords",
			"connected_variant_atlas_coords",
			"connected_variant_textures"
		]:
			if item.has(passthrough_key):
				entry[passthrough_key] = item[passthrough_key]
		result[item_key] = entry
	return result


static func merge_item_database(item_database: Dictionary) -> Dictionary:
	var atlas_entries := get_item_database_entries()
	for item_key in atlas_entries.keys():
		var atlas_entry: Dictionary = atlas_entries[item_key]
		var merged := {}
		if item_database.has(item_key) and item_database[item_key] is Dictionary:
			merged = (item_database[item_key] as Dictionary).duplicate(true)

		for field in atlas_entry.keys():
			merged[field] = atlas_entry[field]
		item_database[item_key] = merged
	return item_database


static func get_item_icon(item_id: int, tile_set: TileSet = null) -> AtlasTexture:
	var item := get_item(item_id)
	if item.is_empty() or not bool(item.get("atlas_enabled", true)):
		return null

	var atlas_coords := _to_vector2i(item.get("atlas_coords", Vector2i.ZERO))
	var source_id := int(item.get("source_id", 0))
	var source_texture: Texture2D = null
	var region_size := DEFAULT_TILE_SIZE
	var margins := Vector2i.ZERO
	var separation := Vector2i.ZERO

	if tile_set != null and tile_set.has_source(source_id):
		var source = tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source := source as TileSetAtlasSource
			source_texture = atlas_source.texture
			region_size = atlas_source.texture_region_size
			margins = atlas_source.margins
			separation = atlas_source.separation
			if region_size == Vector2i.ZERO and tile_set.tile_size != Vector2i.ZERO:
				region_size = tile_set.tile_size

	if source_texture == null and ResourceLoader.exists(FALLBACK_ATLAS_TEXTURE_PATH):
		source_texture = load(FALLBACK_ATLAS_TEXTURE_PATH)

	if source_texture == null:
		return null

	var texture_key := source_texture.resource_path
	if texture_key == "":
		texture_key = str(source_texture.get_instance_id())
	var cache_key := "%d|%s|%s|%s|%s|%s" % [int(item_id), texture_key, str(source_id), str(atlas_coords), str(region_size), str(margins + separation)]
	if _icon_cache.has(cache_key):
		var cached = _icon_cache[cache_key]
		if cached is AtlasTexture:
			return cached

	var icon := AtlasTexture.new()
	icon.atlas = source_texture
	var step := region_size + separation
	icon.region = Rect2(
		Vector2(float(margins.x + atlas_coords.x * step.x), float(margins.y + atlas_coords.y * step.y)),
		Vector2(float(region_size.x), float(region_size.y))
	)
	_icon_cache[cache_key] = icon
	return icon
