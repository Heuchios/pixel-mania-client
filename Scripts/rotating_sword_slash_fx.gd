@tool
extends Node2D

@export var preview_emitting := true
@export var auto_restart_preview := true
@export_range(0.2, 2.0, 0.02) var preview_interval := 0.56
@export_range(0.12, 0.75, 0.01) var slash_lifetime := 0.28
@export_range(0.4, 2.0, 0.05) var slash_scale := 1.0
@export_range(18.0, 80.0, 1.0) var slash_radius := 42.0
@export_range(90.0, 360.0, 1.0) var sweep_degrees := 326.0
@export_range(-180.0, 180.0, 1.0) var arc_rotation_degrees := -8.0
@export_range(0.5, 8.0, 0.25) var slash_width := 2.6
@export var mirror_direction := false
@export var auto_free_on_one_shot := true
@export var core_color := Color(1.0, 0.98, 0.78, 1.0)
@export var edge_color := Color(0.62, 0.88, 1.0, 1.0)
@export var glow_color := Color(0.18, 0.56, 1.0, 1.0)

const EFFECT_Z_INDEX := 4092
const SPARK_COUNT := 26

var rng := RandomNumberGenerator.new()
var slash_age := 999.0
var preview_timer := 0.0
var one_shot := false
var sparks: Array = []


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	rng.randomize()
	if preview_emitting:
		restart()
	else:
		set_process(false)


func start() -> void:
	preview_emitting = true
	one_shot = false
	restart()


func stop() -> void:
	preview_emitting = false
	one_shot = false
	clear()
	set_process(false)


func restart() -> void:
	slash_age = 0.0
	preview_timer = preview_interval
	_spawn_edge_sparks()
	set_process(true)
	queue_redraw()


func play_once(facing_direction: int = 1) -> void:
	mirror_direction = facing_direction < 0
	preview_emitting = false
	auto_restart_preview = false
	one_shot = true
	restart()


func clear() -> void:
	slash_age = 999.0
	sparks.clear()
	queue_redraw()


func _process(delta: float) -> void:
	slash_age += delta
	_update_sparks(delta)

	if preview_emitting and auto_restart_preview:
		preview_timer -= delta
		if preview_timer <= 0.0:
			restart()
			return

	if one_shot and slash_age > slash_lifetime + 0.24 and sparks.is_empty():
		if auto_free_on_one_shot:
			queue_free()
		else:
			set_process(false)
		return

	if not preview_emitting and not one_shot and slash_age > slash_lifetime + 0.12 and sparks.is_empty():
		set_process(false)

	queue_redraw()


func _draw() -> void:
	if slash_age <= slash_lifetime:
		var t := clampf(slash_age / maxf(0.01, slash_lifetime), 0.0, 1.0)
		var reveal := _ease_out_quart(clampf(t / 0.68, 0.0, 1.0))
		var fade := 1.0 - _smoothstep(0.56, 1.0, t)
		var flash := 1.0 - _smoothstep(0.30, 0.86, t)
		var main_path := _visible_path(_make_arc_path(Vector2.ZERO, 1.0), reveal)
		var inner_path := _visible_path(_make_arc_path(Vector2(-2.0, 3.0), 0.80), clampf(reveal - 0.05, 0.0, 1.0))
		var outer_path := _visible_path(_make_arc_path(Vector2(2.0, -3.0), 1.12), clampf(reveal - 0.02, 0.0, 1.0))

		_draw_slash_path(outer_path, fade * 0.44, slash_width * 0.70, edge_color, glow_color)
		_draw_slash_path(inner_path, fade * 0.34, slash_width * 0.58, Color(0.76, 0.95, 1.0, 1.0), glow_color)
		_draw_slash_path(main_path, fade, slash_width, core_color, glow_color)
		_draw_tip_flash(main_path, reveal, flash)

	_draw_sparks()


func _draw_slash_path(points: PackedVector2Array, alpha: float, width: float, body: Color, glow: Color) -> void:
	if points.size() < 2 or alpha <= 0.01:
		return
	draw_polyline(points, Color(glow.r, glow.g, glow.b, 0.18 * alpha), maxf(2.0, width * 4.2), false)
	draw_polyline(points, Color(body.r, body.g, body.b, 0.62 * alpha), maxf(1.0, width * 2.0), false)
	draw_polyline(points, Color(1.0, 1.0, 0.94, 0.92 * alpha), maxf(0.6, width * 0.48), false)


func _draw_tip_flash(points: PackedVector2Array, reveal: float, alpha: float) -> void:
	if points.size() < 2 or reveal < 0.70 or alpha <= 0.01:
		return
	var tip := points[points.size() - 1]
	var radius := lerpf(8.0, 2.0, reveal) * slash_scale
	draw_circle(tip, radius, Color(edge_color.r, edge_color.g, edge_color.b, 0.20 * alpha))
	draw_line(tip + Vector2(-5.0, 0.0), tip + Vector2(5.0, 0.0), Color(1.0, 1.0, 0.92, 0.82 * alpha), 1.0, false)
	draw_line(tip + Vector2(0.0, -5.0), tip + Vector2(0.0, 5.0), Color(1.0, 1.0, 0.92, 0.82 * alpha), 1.0, false)


func _draw_sparks() -> void:
	for spark in sparks:
		var age := float(spark.get("age", 0.0))
		if age < 0.0:
			continue
		var lifetime := maxf(0.01, float(spark.get("lifetime", 0.2)))
		var t := clampf(age / lifetime, 0.0, 1.0)
		var alpha := 1.0 - _smoothstep(0.18, 1.0, t)
		if alpha <= 0.01:
			continue
		var spark_position := spark.get("position", Vector2.ZERO) as Vector2
		var velocity := spark.get("velocity", Vector2.ZERO) as Vector2
		var size := float(spark.get("size", 2.0))
		var color := spark.get("color", Color.WHITE) as Color
		var tail := velocity.normalized() * size * float(spark.get("stretch", 4.0))
		draw_line(spark_position - tail, spark_position, Color(color.r, color.g, color.b, color.a * alpha), maxf(0.7, size * 0.34), false)
		draw_circle(spark_position, maxf(0.55, size * 0.34), Color(1.0, 1.0, 0.96, 0.68 * alpha))


func _make_arc_path(offset: Vector2, radius_mult: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var facing := -1.0 if mirror_direction else 1.0
	var center := Vector2(9.0 * facing, 0.0) * slash_scale + Vector2(offset.x * facing, offset.y)
	var radius := Vector2(slash_radius, slash_radius * 0.68) * slash_scale * radius_mult
	var arc_rotation := deg_to_rad(arc_rotation_degrees * facing)
	var start_angle := deg_to_rad(222.0)
	var end_angle := start_angle - deg_to_rad(sweep_degrees)
	var steps := 42

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		var taper := sin(t * PI)
		var lift := sin(t * TAU * 1.15) * 1.2 * slash_scale * taper
		var point := Vector2(cos(angle) * radius.x * facing, sin(angle) * radius.y + lift)
		point = point.rotated(arc_rotation) + center
		points.append(point)

	return points


func _visible_path(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var visible_points := PackedVector2Array()
	if points.size() < 2 or progress <= 0.0:
		return visible_points

	var scaled := clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var full_count := clampi(int(floor(scaled)), 1, points.size() - 1)
	for i in range(full_count + 1):
		visible_points.append(points[i])

	if full_count < points.size() - 1:
		var partial := scaled - float(full_count)
		visible_points.append(points[full_count].lerp(points[full_count + 1], partial))

	return visible_points


func _spawn_edge_sparks() -> void:
	sparks.clear()
	var path := _make_arc_path(Vector2.ZERO, 1.0)
	if path.size() < 4:
		return

	for _i in range(SPARK_COUNT):
		var idx := rng.randi_range(maxi(2, int(path.size() * 0.46)), path.size() - 2)
		var point := path[idx]
		var tangent := (path[idx + 1] - path[idx - 1]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var direction := (tangent * rng.randf_range(0.34, 1.2) + normal * side * rng.randf_range(0.12, 0.86)).normalized()
		var speed := rng.randf_range(46.0, 148.0) * slash_scale
		var palette := [
			Color(1.0, 1.0, 0.92, 0.94),
			Color(0.72, 0.92, 1.0, 0.84),
			Color(0.36, 0.72, 1.0, 0.76),
			Color(1.0, 0.84, 0.40, 0.70)
		]
		sparks.append({
			"age": rng.randf_range(-0.06, 0.11),
			"lifetime": rng.randf_range(0.16, 0.36),
			"position": point + normal * side * rng.randf_range(0.0, 4.0) * slash_scale,
			"velocity": direction * speed,
			"gravity": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(22.0, 68.0)) * slash_scale,
			"damping": rng.randf_range(0.72, 0.88),
			"size": rng.randf_range(1.5, 3.5) * slash_scale,
			"stretch": rng.randf_range(2.0, 5.6),
			"color": palette[rng.randi_range(0, palette.size() - 1)]
		})


func _update_sparks(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var spark := sparks[i] as Dictionary
		var age := float(spark.get("age", 0.0)) + delta
		var lifetime := float(spark.get("lifetime", 0.2))
		if age > lifetime:
			sparks.remove_at(i)
			continue
		var velocity := spark.get("velocity", Vector2.ZERO) as Vector2
		var spark_position := spark.get("position", Vector2.ZERO) as Vector2
		var gravity := spark.get("gravity", Vector2.ZERO) as Vector2
		var damping := float(spark.get("damping", 0.82))
		velocity += gravity * delta
		spark_position += velocity * delta
		velocity *= pow(damping, delta * 60.0)
		spark["age"] = age
		spark["velocity"] = velocity
		spark["position"] = spark_position
		sparks[i] = spark


func _ease_out_quart(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 4.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
