extends Node2D

const TILE_SIZE := 32.0
const HALF_TILE := TILE_SIZE * 0.5
const DASH_LENGTH := 8.0
const DASH_PERIOD := 16.0
const DASH_SPEED := 14.0
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
	queue_redraw()


func _draw() -> void:
	var phase := fposmod(animation_time * DASH_SPEED, DASH_PERIOD)
	for edge in dash_segments:
		for span in get_dash_spans(edge, phase):
			draw_line(span[0], span[1], Color(0.06, 0.025, 0.10, 0.55), 3.0, false)
			draw_line(span[0], span[1], edge.color, 1.5, false)


func get_dash_spans(edge: Dictionary, phase: float) -> Array:
	var spans := []
	var start: Vector2 = edge.start
	var direction: Vector2 = (edge.end - start).normalized()
	var length: float = start.distance_to(edge.end)
	var cursor := fposmod(phase, DASH_PERIOD) - DASH_PERIOD
	while cursor < length:
		var from := maxf(cursor, 0.0)
		var to := minf(cursor + DASH_LENGTH, length)
		if to > from:
			spans.append(PackedVector2Array([start + direction * from, start + direction * to]))
		cursor += DASH_PERIOD
	return spans


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
	queue_redraw()
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
	queue_redraw()


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
		_add_dashed_edge(top_left + Vector2(TILE_SIZE, TILE_SIZE), top_left + Vector2(0.0, TILE_SIZE), color)
	if draw_left:
		_add_dashed_edge(top_left + Vector2(0.0, TILE_SIZE), top_left, color)
	if draw_right:
		_add_dashed_edge(top_left + Vector2(TILE_SIZE, 0.0), top_left + Vector2(TILE_SIZE, TILE_SIZE), color)


func _add_dashed_edge(start: Vector2, end: Vector2, color: Color) -> void:
	# Clockwise edges keep the protected area on their right. Every tile edge
	# is exactly two dash periods, so phase stays continuous through corners,
	# concave steps, holes, and the closing seam without clamping or bunching.
	dash_segments.append({"start": start, "end": end, "color": color})
