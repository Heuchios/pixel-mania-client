extends Node2D

const TILE_SIZE := 32.0
const HALF_TILE := TILE_SIZE * 0.5
const DASH_LENGTH := 5.5
const DASH_GAP := 4.5
const DASH_WIDTH := 1.35
const DASH_SPEED := 4.0
const DASH_AMPLITUDE := 2.5
const COLOR_ACCESS := Color(0.25, 1.0, 0.35, 0.90)
const COLOR_PUBLIC := Color(1.0, 0.86, 0.16, 0.92)
const COLOR_DENIED := Color(1.0, 0.20, 0.18, 0.92)

var world_node = null
var lock_manager = null
var area_lock: Dictionary = {}
var last_draw_signature: String = ""
var dash_segments: Array = []
var animation_time: float = 0.0


func _ready() -> void:
	visible = true
	z_as_relative = false
	z_index = 950
	set_process(false)


func setup(world, manager) -> void:
	world_node = world
	lock_manager = manager
	refresh(true)


func refresh(force: bool = false) -> void:
	visible = true
	var next_signature: String = _build_draw_signature()
	if not force and next_signature == last_draw_signature:
		return
	last_draw_signature = next_signature
	_rebuild_dash_segments()


func show_area_lock(lock_data: Dictionary) -> void:
	area_lock = lock_data.duplicate(true)
	refresh()


func hide_area_lock() -> void:
	area_lock.clear()
	refresh()


func _process(delta: float) -> void:
	animation_time += delta
	if dash_segments.is_empty():
		set_process(false)
		return
	var wave: float = sin(animation_time * DASH_SPEED) * DASH_AMPLITUDE
	for raw_entry in dash_segments:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var line: Line2D = entry.get("line", null)
		if line == null or not is_instance_valid(line):
			continue
		var base_start: Vector2 = entry.get("start", Vector2.ZERO)
		var direction: Vector2 = entry.get("direction", Vector2.RIGHT)
		var edge_length: float = float(entry.get("edge_length", 0.0))
		var base_offset: float = float(entry.get("offset", 0.0))
		var max_offset: float = max(0.0, edge_length - DASH_LENGTH)
		var animated_offset: float = clamp(base_offset + wave, 0.0, max_offset)
		line.position = base_start + direction * animated_offset


func _get_locks_to_draw() -> Array:
	if lock_manager != null and lock_manager.has_method("get_area_locks_save_data"):
		return lock_manager.get_area_locks_save_data()
	if not area_lock.is_empty():
		return [area_lock]
	return []


func _build_draw_signature() -> String:
	var signature: String = ""
	if lock_manager == null:
		return "no-manager"
	if lock_manager.has_method("get_current_player_name"):
		signature += "player=" + str(lock_manager.get_current_player_name()) + "|"
	var locks: Array = _get_locks_to_draw()
	for raw_lock in locks:
		if not (raw_lock is Dictionary):
			continue
		var lock_data: Dictionary = raw_lock
		var color: Color = _get_highlight_color(lock_data)
		signature += str(lock_data.get("lock_id", ""))
		signature += "," + str(lock_data.get("lock_type", ""))
		signature += "," + str(lock_data.get("owner_name", ""))
		signature += "," + str(lock_data.get("lock_grid_x", 0))
		signature += "," + str(lock_data.get("lock_grid_y", 0))
		signature += "," + str(lock_data.get("max_tiles", 0))
		signature += "," + str(lock_data.get("public_build", false))
		signature += "," + str(lock_data.get("ignore_empty_space", false))
		signature += "," + str(lock_data.get("allowed_players", []))
		signature += "," + str(lock_data.get("player_roles", {}))
		signature += "," + str(color)
		if lock_manager.has_method("get_area_lock_positions"):
			signature += "," + str(lock_manager.get_area_lock_positions(lock_data))
		signature += ";"
	return signature


func _get_highlight_color(lock_data: Dictionary) -> Color:
	if lock_data.is_empty():
		return COLOR_DENIED
	if bool(lock_data.get("public_build", false)):
		return COLOR_PUBLIC
	if lock_manager != null and bool(lock_manager.can_current_player_build_in_area_lock(lock_data)):
		return COLOR_ACCESS
	return COLOR_DENIED


func _rebuild_dash_segments() -> void:
	for child in get_children():
		child.queue_free()
	dash_segments.clear()
	if lock_manager == null:
		set_process(false)
		return

	var locks: Array = _get_locks_to_draw()
	for raw_lock in locks:
		if not (raw_lock is Dictionary):
			continue
		var lock_data: Dictionary = raw_lock
		var color: Color = _get_highlight_color(lock_data)
		var positions: Array = lock_manager.get_area_lock_positions(lock_data)
		var position_lookup: Dictionary = {}
		for raw_pos in positions:
			if not (raw_pos is Vector2i):
				continue
			var grid_pos: Vector2i = raw_pos
			position_lookup[str(grid_pos.x) + ":" + str(grid_pos.y)] = true
		for raw_pos in positions:
			if not (raw_pos is Vector2i):
				continue
			var grid_pos: Vector2i = raw_pos
			_add_tile_outline_dashes(grid_pos, color, position_lookup)

	set_process(not dash_segments.is_empty())


func _has_locked_neighbor(position_lookup: Dictionary, grid_pos: Vector2i, offset: Vector2i) -> bool:
	var neighbor: Vector2i = grid_pos + offset
	return bool(position_lookup.get(str(neighbor.x) + ":" + str(neighbor.y), false))


func _add_tile_outline_dashes(grid_pos: Vector2i, color: Color, position_lookup: Dictionary) -> void:
	var center: Vector2 = Vector2(float(grid_pos.x) * TILE_SIZE, float(grid_pos.y) * TILE_SIZE)
	var top_left: Vector2 = center - Vector2(HALF_TILE, HALF_TILE)
	var draw_top: bool = not _has_locked_neighbor(position_lookup, grid_pos, Vector2i(0, -1))
	var draw_bottom: bool = not _has_locked_neighbor(position_lookup, grid_pos, Vector2i(0, 1))
	var draw_left: bool = not _has_locked_neighbor(position_lookup, grid_pos, Vector2i(-1, 0))
	var draw_right: bool = not _has_locked_neighbor(position_lookup, grid_pos, Vector2i(1, 0))

	if draw_top:
		_add_dashed_edge(top_left, top_left + Vector2(TILE_SIZE, 0.0), color)
	if draw_bottom:
		_add_dashed_edge(top_left + Vector2(0.0, TILE_SIZE), top_left + Vector2(TILE_SIZE, TILE_SIZE), color)
	if draw_left:
		_add_dashed_edge(top_left, top_left + Vector2(0.0, TILE_SIZE), color)
	if draw_right:
		_add_dashed_edge(top_left + Vector2(TILE_SIZE, 0.0), top_left + Vector2(TILE_SIZE, TILE_SIZE), color)


func _add_dashed_edge(start: Vector2, end: Vector2, color: Color) -> void:
	var edge: Vector2 = end - start
	var edge_length: float = edge.length()
	if edge_length <= 0.0:
		return
	var direction: Vector2 = edge / edge_length
	var cursor: float = 0.0
	while cursor < edge_length:
		var dash_end: float = min(cursor + DASH_LENGTH, edge_length)
		var dash_length: float = max(0.0, dash_end - cursor)
		if dash_length > 0.0:
			var line: Line2D = Line2D.new()
			line.width = DASH_WIDTH
			line.default_color = color
			line.points = PackedVector2Array([Vector2.ZERO, direction * dash_length])
			line.position = start + direction * cursor
			add_child(line)
			dash_segments.append({
				"line": line,
				"start": start,
				"direction": direction,
				"edge_length": edge_length,
				"offset": cursor
			})
		cursor += DASH_LENGTH + DASH_GAP
