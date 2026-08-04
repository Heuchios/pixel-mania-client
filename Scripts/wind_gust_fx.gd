@tool
extends Node2D

@export var preview_emitting: bool = true
@export var follow_view: bool = true
@export var spawn_margin: float = 96.0
@export var spawn_interval_min: float = 1.8
@export var spawn_interval_max: float = 3.4
@export var max_active_gusts: int = 1
@export var draw_time_min: float = 1.55
@export var draw_time_max: float = 2.35
@export var fade_time_min: float = 0.25
@export var fade_time_max: float = 0.45
@export_range(0.05, 0.95, 0.01) var trail_length_min: float = 0.10
@export_range(0.05, 0.95, 0.01) var trail_length_max: float = 0.18
@export var line_segments: int = 28
@export var field_width: float = 1180.0
@export var field_height: float = 420.0
@export var min_field_width: float = 640.0
@export var min_field_height: float = 360.0
@export var random_y_offset: float = 36.0

const WIND_Z_INDEX := 4090

var gusts: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawn_timer: float = 0.0
var trail_container: Node2D = null


func _ready():
	z_as_relative = false
	z_index = WIND_Z_INDEX
	rng.randomize()
	trail_container = get_node_or_null("TrailContainer") as Node2D
	if trail_container == null:
		trail_container = Node2D.new()
		trail_container.name = "TrailContainer"
		add_child(trail_container)

	_clear_trail_container()
	set_emitting(preview_emitting)


func start():
	set_emitting(true)


func stop():
	set_emitting(false)


func restart():
	_clear_trail_container()
	if preview_emitting:
		spawn_timer = 0.0
		set_process(true)


func set_emitting(active: bool):
	preview_emitting = active
	visible = active
	spawn_timer = 0.0
	if not active:
		clear()
	set_process(active)


func clear():
	_clear_trail_container()


func burst(count: int = 1):
	for i in range(count):
		_spawn_gust()


func _process(delta: float):
	if not _is_world_active():
		clear()
		return

	if follow_view:
		update_for_view()

	_update_gusts(delta)
	if not preview_emitting:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		if gusts.size() < max_active_gusts:
			_spawn_gust()
		spawn_timer = rng.randf_range(spawn_interval_min, spawn_interval_max)


func _spawn_gust():
	if trail_container == null:
		return

	var line_width: float = rng.randf_range(1.6, 3.2)
	var main_alpha: float = rng.randf_range(0.44, 0.64)
	var glow_alpha: float = main_alpha * 0.12
	var points: PackedVector2Array = _build_gust_path()
	var main_line: Line2D = _make_line("WindTrailLine", line_width, Color(0.92, 0.98, 1.0, main_alpha))
	var glow_line: Line2D = _make_line("WindTrailGlow", line_width * 2.0, Color(0.42, 0.78, 1.0, glow_alpha))

	trail_container.add_child(glow_line)
	trail_container.add_child(main_line)
	gusts.append({
		"age": 0.0,
		"draw_time": rng.randf_range(draw_time_min, draw_time_max),
		"fade_time": rng.randf_range(fade_time_min, fade_time_max),
		"trail_length": rng.randf_range(trail_length_min, trail_length_max),
		"points": points,
		"main_line": main_line,
		"glow_line": glow_line,
	})


func _make_line(line_name: String, width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.name = line_name
	line.width = width
	line.default_color = color
	line.width_curve = _make_width_curve()
	line.gradient = _make_trail_gradient(color)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	return line


func _make_width_curve() -> Curve:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _make_trail_gradient(color: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	var transparent: Color = color
	transparent.a = 0.0
	gradient.set_color(0, transparent)
	gradient.set_color(1, transparent)
	gradient.add_point(0.5, color)
	return gradient


func _build_gust_path() -> PackedVector2Array:
	var segments: int = maxi(4, line_segments)
	var start_x: float = rng.randf_range(spawn_margin * -0.35, spawn_margin * 0.45)
	var start_y: float = rng.randf_range(field_height * -0.5, field_height * 0.5)
	var length: float = rng.randf_range(field_width * 0.68, field_width * 1.05)
	var end_y: float = start_y + rng.randf_range(-random_y_offset, random_y_offset)
	var control_1: Vector2 = Vector2(
		start_x + length * rng.randf_range(0.24, 0.34),
		start_y + rng.randf_range(-random_y_offset, random_y_offset)
	)
	var control_2: Vector2 = Vector2(
		start_x + length * rng.randf_range(0.62, 0.78),
		end_y + rng.randf_range(-random_y_offset, random_y_offset)
	)
	var path_start: Vector2 = Vector2(start_x, start_y)
	var end: Vector2 = Vector2(start_x + length, end_y)
	var points: PackedVector2Array = PackedVector2Array()

	for index in range(segments + 1):
		var t: float = float(index) / float(segments)
		points.append(_cubic_bezier(path_start, control_1, control_2, end, t))

	return points


func _cubic_bezier(start_point: Vector2, control_1: Vector2, control_2: Vector2, end: Vector2, t: float) -> Vector2:
	var inverse_t: float = 1.0 - t
	return (
		start_point * inverse_t * inverse_t * inverse_t
		+ control_1 * 3.0 * inverse_t * inverse_t * t
		+ control_2 * 3.0 * inverse_t * t * t
		+ end * t * t * t
	)


func _update_gusts(delta: float):
	for index in range(gusts.size() - 1, -1, -1):
		var gust: Dictionary = gusts[index]
		var age: float = float(gust.get("age", 0.0)) + delta
		var draw_time: float = float(gust.get("draw_time", 1.2))
		var fade_time: float = float(gust.get("fade_time", 0.3))
		var fade_t: float = clampf((age - draw_time) / fade_time, 0.0, 1.0)

		if fade_t >= 1.0:
			_free_gust(gust)
			gusts.remove_at(index)
			continue

		gust["age"] = age
		var head_t: float = clampf(age / draw_time, 0.0, 1.0)
		var trail_length: float = float(gust.get("trail_length", 0.36))
		var tail_t: float = maxf(0.0, head_t - trail_length)
		var segment: PackedVector2Array = _slice_path(gust.get("points", PackedVector2Array()), tail_t, head_t)
		var fade_alpha: float = 1.0 - fade_t

		_set_line_state(gust.get("glow_line", null), segment, fade_alpha)
		_set_line_state(gust.get("main_line", null), segment, fade_alpha)


func _slice_path(points: PackedVector2Array, from_t: float, to_t: float) -> PackedVector2Array:
	if points.size() < 2 or to_t <= from_t:
		return PackedVector2Array()

	var max_index: float = float(points.size() - 1)
	var start_f: float = clampf(from_t, 0.0, 1.0) * max_index
	var end_f: float = clampf(to_t, 0.0, 1.0) * max_index
	var first_index: int = int(floor(start_f))
	var last_index: int = int(floor(end_f))
	var segment: PackedVector2Array = PackedVector2Array()

	segment.append(_interpolate_point(points, start_f))
	for index in range(first_index + 1, last_index + 1):
		if index > 0 and index < points.size():
			segment.append(points[index])
	segment.append(_interpolate_point(points, end_f))

	return segment


func _interpolate_point(points: PackedVector2Array, point_index: float) -> Vector2:
	var segment_index: int = clampi(int(floor(point_index)), 0, points.size() - 2)
	var local_t: float = clampf(point_index - float(segment_index), 0.0, 1.0)
	return points[segment_index].lerp(points[segment_index + 1], local_t)


func _set_line_state(line, points: PackedVector2Array, alpha: float):
	if line == null or not is_instance_valid(line):
		return

	line.points = points
	line.modulate.a = alpha


func update_for_view():
	var view_rect: Rect2 = _get_visible_world_rect()
	var view_center_y: float = view_rect.position.y + view_rect.size.y * 0.5
	field_width = maxf(min_field_width, view_rect.size.x + spawn_margin * 2.0)
	field_height = maxf(min_field_height, view_rect.size.y + spawn_margin)
	global_position = Vector2(view_rect.position.x - spawn_margin, view_center_y)


func _get_visible_world_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport_rect()
	var inverse_canvas: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inverse_canvas * viewport_rect.position
	var bottom_right: Vector2 = inverse_canvas * (viewport_rect.position + viewport_rect.size)
	var left: float = minf(top_left.x, bottom_right.x)
	var top: float = minf(top_left.y, bottom_right.y)
	var right: float = maxf(top_left.x, bottom_right.x)
	var bottom: float = maxf(top_left.y, bottom_right.y)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _is_world_active() -> bool:
	var parent = get_parent()
	if parent != null and "in_world" in parent:
		return bool(parent.in_world)

	return true


func _free_gust(gust: Dictionary):
	for key in ["main_line", "glow_line"]:
		var line = gust.get(key, null)
		if line != null and is_instance_valid(line):
			line.queue_free()


func _clear_trail_container():
	gusts.clear()
	if trail_container == null:
		return

	for child in trail_container.get_children():
		child.queue_free()
