extends Node2D
class_name CustomRealWorldCollision

const ItemDatabase = preload("res://Scripts/item_database.gd")

const DEFAULT_WORLD_NAME := "TEST"
const TILE_SIZE := 32
const WORLD_ORIGIN := Vector2.ZERO
const CHUNK_ORIGIN := Vector2i.ZERO
const SOLID_COLLISION_LAYER := 1
const DEFAULT_SPAWN_POSITION := Vector2(320.0, 350.0)
const BEDROCK_TEXTURE := "res://Assets/blocks/Tier_1/basic blocks/bedrock_block.png"

@export var world_name := DEFAULT_WORLD_NAME
@export var collision_debug_visible := false
@export var draw_textures := true

var requested_world_name := DEFAULT_WORLD_NAME
var loaded_world_name := ""
var world_revision := ""
var world_source_path := ""
var world_width := 0
var world_height := 0
var spawn_position := DEFAULT_SPAWN_POSITION
var collision_ready := false
var collision_revision := 0

var item_database: Dictionary = {}
var foreground_tiles: Dictionary = {}
var background_tiles: Dictionary = {}
var solid_tiles: Dictionary = {}
var unknown_foreground_blocks: Dictionary = {}
var collision_hash := "none"

var collision_root: StaticBody2D = null
var texture_cache: Dictionary = {}


func _ready() -> void:
	item_database = _load_item_database()
	setup_world(_get_launch_world_name(world_name))


func is_real_world_collision() -> bool:
	return true


func setup_world(new_world_name: String = DEFAULT_WORLD_NAME) -> void:
	requested_world_name = new_world_name.strip_edges()
	if requested_world_name == "":
		requested_world_name = DEFAULT_WORLD_NAME

	foreground_tiles.clear()
	background_tiles.clear()
	solid_tiles.clear()
	unknown_foreground_blocks.clear()
	collision_ready = false
	loaded_world_name = requested_world_name
	world_revision = ""
	world_source_path = ""
	world_width = 0
	world_height = 0
	spawn_position = DEFAULT_SPAWN_POSITION
	_clear_collision_root()
	collision_revision = 0

	var payload := _load_world_payload(requested_world_name)
	if payload.is_empty():
		collision_hash = "missing"
		push_warning("[CustomMovementWorld] Could not load world '%s'." % requested_world_name)
		queue_redraw()
		return

	loaded_world_name = str(payload.get("world_name", requested_world_name)).strip_edges()
	if loaded_world_name == "":
		loaded_world_name = requested_world_name
	world_revision = str(payload.get("world_version", payload.get("revision", ""))).strip_edges()
	collision_revision = _safe_int(payload.get("collision_revision", payload.get("revision_number", 0)), 0, 0, 2147483647)
	world_width = _safe_int(payload.get("world_width", 0), 0, 0, 1000000)
	world_height = _safe_int(payload.get("world_height", 0), 0, 0, 1000000)
	spawn_position = _read_spawn_position(payload)

	_load_tiles_from_array(payload.get("background_blocks", payload.get("background", [])), background_tiles, false)
	_load_tiles_from_array(payload.get("blocks", payload.get("foreground_blocks", [])), foreground_tiles, true)
	_rebuild_solid_tiles()
	_build_collision_bodies()
	collision_hash = _calculate_collision_hash()
	collision_ready = true
	queue_redraw()

	print("[CustomMovementWorld] Loaded world=%s revision=%s source=%s tile_size=%d foreground=%d background=%d solid_collision_count=%d collision_hash=%s unknown_foreground=%d" % [
		loaded_world_name,
		world_revision,
		world_source_path,
		TILE_SIZE,
		foreground_tiles.size(),
		background_tiles.size(),
		solid_tiles.size(),
		collision_hash,
		unknown_foreground_blocks.size(),
	])


func set_collision_debug_visible(enabled: bool) -> void:
	collision_debug_visible = enabled
	queue_redraw()


func get_spawn_position() -> Vector2:
	return spawn_position


func get_collision_hash() -> String:
	return collision_hash


func get_world_debug_summary() -> Dictionary:
	return {
		"world_id": loaded_world_name,
		"world_name": loaded_world_name,
		"requested_world_name": requested_world_name,
		"world_revision": world_revision,
		"collision_revision": collision_revision,
		"world_source": world_source_path,
		"tile_size": TILE_SIZE,
		"block_count": get_block_count(),
		"foreground_count": foreground_tiles.size(),
		"background_count": background_tiles.size(),
		"solid_collision_count": solid_tiles.size(),
		"collision_hash": collision_hash,
		"collision_ready": collision_ready,
		"world_origin": WORLD_ORIGIN,
		"chunk_origin": CHUNK_ORIGIN,
		"world_width": world_width,
		"world_height": world_height,
		"spawn_position": spawn_position,
		"unknown_foreground_count": unknown_foreground_blocks.size(),
	}


func apply_world_state_payload(payload: Dictionary) -> Dictionary:
	if not (payload is Dictionary):
		return {"ok": false, "reason": "invalid_payload"}

	var source := payload
	if payload.get("world_state", null) is Dictionary:
		source = payload.get("world_state")

	var before_revision := collision_revision
	var before_hash := collision_hash
	var next_world_name := str(source.get("world_name", payload.get("world", loaded_world_name))).strip_edges()
	if next_world_name != "":
		loaded_world_name = next_world_name
		requested_world_name = next_world_name

	foreground_tiles.clear()
	background_tiles.clear()
	solid_tiles.clear()
	unknown_foreground_blocks.clear()
	_load_tiles_from_array(source.get("background_blocks", source.get("background", [])), background_tiles, false)
	_load_tiles_from_array(source.get("blocks", source.get("foreground_blocks", source.get("foreground", []))), foreground_tiles, true)
	_rebuild_collision_after_tile_change()
	return {
		"ok": true,
		"revision_before": before_revision,
		"revision_after": collision_revision,
		"hash_before": before_hash,
		"hash_after": collision_hash,
	}


func apply_block_update(update: Dictionary) -> Dictionary:
	if not (update is Dictionary):
		return {"ok": false, "reason": "invalid_update"}

	var action := str(update.get("action", "")).strip_edges().to_lower()
	if action == "hit":
		return {"ok": true, "changed": false, "reason": "hit_only", "revision_before": collision_revision, "revision_after": collision_revision, "hash_before": collision_hash, "hash_after": collision_hash}
	if action != "place" and action != "break":
		return {"ok": false, "reason": "unsupported_action"}

	var layer := str(update.get("layer", "foreground")).strip_edges().to_lower()
	if layer != "background":
		layer = "foreground"
	var grid_pos := Vector2i(
		_safe_int(update.get("x", 0), 0, -1000000, 1000000),
		_safe_int(update.get("y", 0), 0, -1000000, 1000000)
	)
	var block_id := _normalize_legacy_block_id(str(update.get("block_type", "")).strip_edges().to_lower())
	var target := background_tiles if layer == "background" else foreground_tiles
	var before_revision := collision_revision
	var before_hash := collision_hash

	if action == "break":
		target.erase(grid_pos)
	else:
		if block_id == "" or block_id == "air":
			return {"ok": false, "reason": "missing_block_type"}
		target[grid_pos] = block_id

	_rebuild_collision_after_tile_change()
	return {
		"ok": true,
		"changed": true,
		"action": action,
		"layer": layer,
		"grid_pos": grid_pos,
		"block_id": block_id,
		"revision_before": before_revision,
		"revision_after": collision_revision,
		"hash_before": before_hash,
		"hash_after": collision_hash,
	}


func get_block_count() -> int:
	return foreground_tiles.size() + background_tiles.size()


func get_tile_size() -> int:
	return TILE_SIZE


func get_foreground_tile_snapshot() -> Dictionary:
	return foreground_tiles.duplicate(true)


func get_background_tile_snapshot() -> Dictionary:
	return background_tiles.duplicate(true)


func get_tile_info_at_world(world_position: Vector2) -> Dictionary:
	return get_tile_info_at_grid(world_to_grid(world_position))


func get_tile_info_at_grid(grid_pos: Vector2i) -> Dictionary:
	var block_id := "air"
	var layer := "air"
	if foreground_tiles.has(grid_pos):
		block_id = str(foreground_tiles.get(grid_pos, "air"))
		layer = "foreground"
	elif background_tiles.has(grid_pos):
		block_id = str(background_tiles.get(grid_pos, "air"))
		layer = "background"

	return {
		"grid_pos": grid_pos,
		"block_id": block_id,
		"block_name": _get_block_display_name(block_id),
		"layer": layer,
		"solid": _is_foreground_collision_block(block_id) if layer == "foreground" else false,
	}


func world_to_grid(world_position: Vector2) -> Vector2i:
	var half_tile := float(TILE_SIZE) * 0.5
	return Vector2i(
		int(floor((world_position.x - WORLD_ORIGIN.x + half_tile) / float(TILE_SIZE))),
		int(floor((world_position.y - WORLD_ORIGIN.y + half_tile) / float(TILE_SIZE)))
	)


func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return WORLD_ORIGIN + Vector2(float(grid_pos.x * TILE_SIZE), float(grid_pos.y * TILE_SIZE))


func _draw() -> void:
	_draw_tile_set(background_tiles, true)
	_draw_tile_set(foreground_tiles, false)
	if collision_debug_visible:
		_draw_collision_overlay()


func _draw_tile_set(tile_set: Dictionary, background: bool) -> void:
	var positions := tile_set.keys()
	_sort_grid_positions(positions)
	for grid_pos in positions:
		var block_id := str(tile_set.get(grid_pos, "air"))
		var center: Vector2 = grid_to_world_center(grid_pos)
		var block_rect := Rect2(center - Vector2(float(TILE_SIZE), float(TILE_SIZE)) * 0.5, Vector2(float(TILE_SIZE), float(TILE_SIZE)))
		var texture = _get_block_texture(block_id)
		var tint := Color(1, 1, 1, 0.58) if background else Color.WHITE
		if draw_textures and texture != null:
			draw_texture_rect(texture, block_rect, false, tint)
		else:
			draw_rect(block_rect, _get_block_color(block_id, background), true)
		if not background:
			draw_rect(block_rect, Color(0.0, 0.0, 0.0, 0.22), false, 1.0)


func _draw_collision_overlay() -> void:
	var positions := solid_tiles.keys()
	_sort_grid_positions(positions)
	for grid_pos in positions:
		var solid_data: Dictionary = solid_tiles.get(grid_pos, {})
		var shape_kind := str(solid_data.get("shape", "full"))
		var center: Vector2 = grid_to_world_center(grid_pos)
		var rect := Rect2(center - Vector2(float(TILE_SIZE), float(TILE_SIZE)) * 0.5, Vector2(float(TILE_SIZE), float(TILE_SIZE)))
		if shape_kind == "platform":
			rect = Rect2(center + Vector2(float(-TILE_SIZE) * 0.5, -16.0), Vector2(float(TILE_SIZE), 6.0))
		draw_rect(rect, Color(0.15, 0.95, 1.0, 0.20), true)
		draw_rect(rect, Color(0.25, 1.0, 1.0, 0.85), false, 2.0)


func _load_item_database() -> Dictionary:
	if ItemDatabase.ITEMS is Dictionary:
		return ItemDatabase.ITEMS
	return {}


func _get_launch_world_name(default_name: String) -> String:
	var args: Array = []
	for arg in OS.get_cmdline_args():
		args.append(str(arg))
	for arg in OS.get_cmdline_user_args():
		var clean_arg := str(arg)
		if not args.has(clean_arg):
			args.append(clean_arg)

	for i in range(args.size()):
		var arg := str(args[i])
		if arg == "--world" and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with("--world="):
			return arg.substr("--world=".length())
	return default_name


func _load_world_payload(raw_world_name: String) -> Dictionary:
	for file_stem in _candidate_world_file_stems(raw_world_name):
		var path := "user://worlds/%s.json" % file_stem
		if not FileAccess.file_exists(path):
			continue

		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			world_source_path = path
			return parsed
	return {}


func _candidate_world_file_stems(raw_world_name: String) -> Array:
	var clean := _sanitize_world_name(raw_world_name)
	var candidates: Array = []
	if clean != "":
		candidates.append(clean)
	if clean == "custom_test":
		candidates.append("test")
	elif clean == "test":
		candidates.append("custom_test")
	elif clean == "":
		candidates.append("test")

	var unique: Array = []
	for candidate in candidates:
		if not unique.has(candidate):
			unique.append(candidate)
	return unique


func _sanitize_world_name(raw_world_name: String) -> String:
	var clean := raw_world_name.strip_edges().to_lower()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	return result


func _load_tiles_from_array(saved_tiles, target: Dictionary, foreground: bool) -> void:
	if not (saved_tiles is Array):
		return

	for saved_tile in saved_tiles:
		if not (saved_tile is Dictionary):
			continue
		var block_id := _normalize_legacy_block_id(str(saved_tile.get("type", "air")).strip_edges().to_lower())
		if block_id == "" or block_id == "air":
			continue

		var grid_pos := Vector2i(
			_safe_int(saved_tile.get("x", 0), 0, -1000000, 1000000),
			_safe_int(saved_tile.get("y", 0), 0, -1000000, 1000000)
		)
		if world_width > 0 and (grid_pos.x < 0 or grid_pos.x >= world_width):
			continue
		if world_height > 0 and (grid_pos.y < 0 or grid_pos.y >= world_height):
			continue

		if foreground:
			target[grid_pos] = block_id
		elif _is_background_block(block_id):
			target[grid_pos] = block_id


func _normalize_legacy_block_id(block_id: String) -> String:
	if block_id == "crafting_station_left":
		return "crafting_station"
	if block_id == "crafting_station_right":
		return ""
	if block_id == "wood_block":
		return "wood"
	return block_id


func _rebuild_solid_tiles() -> void:
	solid_tiles.clear()
	for grid_pos in foreground_tiles.keys():
		var block_id := str(foreground_tiles.get(grid_pos, "air"))
		if not _is_foreground_collision_block(block_id):
			continue
		var shape_kind := "platform" if _is_platform_collision_block(block_id) else "full"
		solid_tiles[grid_pos] = {
			"type": block_id,
			"shape": shape_kind,
		}


func _rebuild_collision_after_tile_change() -> void:
	_rebuild_solid_tiles()
	_clear_collision_root()
	_build_collision_bodies()
	collision_revision += 1
	collision_hash = _calculate_collision_hash()
	collision_ready = true
	queue_redraw()


func _is_foreground_collision_block(block_id: String) -> bool:
	var clean_id := block_id.strip_edges().to_lower()
	if clean_id == "" or clean_id == "air":
		return false
	if clean_id == "bedrock":
		return true

	var item_data := _get_item_data(clean_id)
	if item_data.is_empty():
		unknown_foreground_blocks[clean_id] = true
		return false
	if str(item_data.get("category", "")).strip_edges().to_lower() != "block":
		return false
	if _is_background_block(clean_id):
		return false
	if item_data.has("collidable") and not bool(item_data.get("collidable", true)):
		return false
	if item_data.has("Collidable") and not bool(item_data.get("Collidable", true)):
		return false
	if item_data.has("no_collision") and bool(item_data.get("no_collision", false)):
		return false
	return true


func _is_background_block(block_id: String) -> bool:
	var clean_id := block_id.strip_edges().to_lower()
	var item_data := _get_item_data(clean_id)
	if item_data.is_empty():
		return clean_id.ends_with("_background") or clean_id.ends_with("_bg")
	if bool(item_data.get("background_block", false)):
		return true
	return str(item_data.get("place_layer", "")).strip_edges().to_lower() == "background"


func _is_platform_collision_block(block_id: String) -> bool:
	var item_data := _get_item_data(block_id)
	return bool(item_data.get("platform_collision", false))


func _get_item_data(block_id: String) -> Dictionary:
	if item_database.has(block_id):
		var value = item_database[block_id]
		if value is Dictionary:
			return value
	return {}


func _get_block_display_name(block_id: String) -> String:
	if block_id == "air":
		return "Air"
	if block_id == "bedrock":
		return "Bedrock"
	return str(_get_item_data(block_id).get("display_name", block_id))


func _get_block_texture(block_id: String):
	if texture_cache.has(block_id):
		return texture_cache[block_id]

	var path := ""
	if block_id == "bedrock":
		path = BEDROCK_TEXTURE
	else:
		var item_data := _get_item_data(block_id)
		if item_data.has("texture"):
			var texture_value = item_data.get("texture")
			if texture_value is String:
				path = str(texture_value)
		if path == "":
			var frames = item_data.get("animation_frames", [])
			if frames is Array and not frames.is_empty():
				path = str(frames[0])

	var texture = null
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	texture_cache[block_id] = texture
	return texture


func _get_block_color(block_id: String, background: bool) -> Color:
	var hash_value := 0
	for byte_value in block_id.to_utf8_buffer():
		hash_value = int((hash_value * 131) + int(byte_value)) & 0xffffffff
	var hue := float(hash_value % 360) / 360.0
	var alpha := 0.50 if background else 1.0
	return Color.from_hsv(hue, 0.45, 0.78, alpha)


func _read_spawn_position(payload: Dictionary) -> Vector2:
	var x := _safe_float(payload.get("player_x", DEFAULT_SPAWN_POSITION.x), DEFAULT_SPAWN_POSITION.x, -1000000.0, 1000000.0)
	var y := _safe_float(payload.get("player_y", DEFAULT_SPAWN_POSITION.y), DEFAULT_SPAWN_POSITION.y, -1000000.0, 1000000.0)
	return Vector2(x, y)


func _build_collision_bodies() -> void:
	collision_root = StaticBody2D.new()
	collision_root.name = "SolidCollision"
	collision_root.collision_layer = SOLID_COLLISION_LAYER
	collision_root.collision_mask = 0
	add_child(collision_root)

	var positions := solid_tiles.keys()
	_sort_grid_positions(positions)
	for grid_pos in positions:
		var solid_data: Dictionary = solid_tiles.get(grid_pos, {})
		var shape_kind := str(solid_data.get("shape", "full"))
		var shape := RectangleShape2D.new()
		var collision_shape := CollisionShape2D.new()
		collision_shape.name = "Collision_%d_%d" % [grid_pos.x, grid_pos.y]
		if shape_kind == "platform":
			shape.size = Vector2(float(TILE_SIZE), 6.0)
			collision_shape.position = grid_to_world_center(grid_pos) + Vector2(0.0, -13.0)
			collision_shape.one_way_collision = true
			collision_shape.one_way_collision_margin = 8.0
		else:
			shape.size = Vector2(float(TILE_SIZE), float(TILE_SIZE))
			collision_shape.position = grid_to_world_center(grid_pos)
		collision_shape.shape = shape
		collision_root.add_child(collision_shape)


func _clear_collision_root() -> void:
	var existing := get_node_or_null("SolidCollision")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	collision_root = null


func _calculate_collision_hash() -> String:
	var signatures: Array = []
	signatures.append("world=%s;revision=%s;tile=%d;width=%d;height=%d" % [
		loaded_world_name,
		str(world_revision) + ":" + str(collision_revision),
		TILE_SIZE,
		world_width,
		world_height,
	])
	for grid_pos in solid_tiles.keys():
		var solid_data: Dictionary = solid_tiles.get(grid_pos, {})
		signatures.append("%d,%d,%s,%s" % [
			int(grid_pos.x),
			int(grid_pos.y),
			str(solid_data.get("type", "air")),
			str(solid_data.get("shape", "full")),
		])
	signatures.sort()

	var hash_value := 2166136261
	for signature in signatures:
		for byte_value in str(signature).to_utf8_buffer():
			hash_value = int((hash_value ^ int(byte_value)) * 16777619) & 0xffffffff
	return "%08x" % hash_value


func _sort_grid_positions(positions: Array) -> void:
	positions.sort_custom(func(a, b):
		if int(a.x) == int(b.x):
			return int(a.y) < int(b.y)
		return int(a.x) < int(b.x)
	)


func _safe_int(value, fallback: int, min_value: int, max_value: int) -> int:
	if value is int:
		return clamp(int(value), min_value, max_value)
	if value is float:
		return clamp(int(value), min_value, max_value)
	if value is String and str(value).is_valid_int():
		return clamp(int(str(value)), min_value, max_value)
	return fallback


func _safe_float(value, fallback: float, min_value: float, max_value: float) -> float:
	if value is int or value is float:
		var clean := float(value)
		if is_finite(clean):
			return clamp(clean, min_value, max_value)
	if value is String and str(value).is_valid_float():
		var clean_string := float(str(value))
		if is_finite(clean_string):
			return clamp(clean_string, min_value, max_value)
	return fallback
