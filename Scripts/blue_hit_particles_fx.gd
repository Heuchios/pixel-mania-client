@tool
extends Node2D

@export var preview_emitting: bool = true
@export var auto_restart_preview: bool = true
@export var preview_interval: float = 0.72
@export var particle_scale: float = 1.0
@export var mirror_direction: bool = false
@export var loop_in_game: bool = false

const EFFECT_Z_INDEX := 4080
const BURST_LIFETIME := 0.58

var rng := RandomNumberGenerator.new()
var bolts: Array = []
var sparks: Array = []
var flash_age := 999.0
var preview_timer := 0.0
var burst_age := BURST_LIFETIME
var one_shot := false


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	rng.randomize()
	set_process(true)
	if preview_emitting:
		restart()


func start() -> void:
	preview_emitting = true
	restart()


func stop() -> void:
	preview_emitting = false
	one_shot = false
	clear()
	set_process(false)


func restart() -> void:
	clear()
	preview_timer = preview_interval
	_spawn_electric_hit()
	queue_redraw()


func burst(count: int = 1) -> void:
	for _i in range(maxi(1, count)):
		_spawn_electric_hit()
	queue_redraw()


func play_once() -> void:
	preview_emitting = false
	auto_restart_preview = false
	loop_in_game = false
	one_shot = true
	restart()


func clear() -> void:
	bolts.clear()
	sparks.clear()
	flash_age = 999.0
	burst_age = BURST_LIFETIME
	queue_redraw()


func _process(delta: float) -> void:
	if not preview_emitting and not loop_in_game and bolts.is_empty() and sparks.is_empty():
		if one_shot:
			queue_free()
			return
		set_process(false)
		return

	_update_effect(delta)

	if Engine.is_editor_hint() or loop_in_game:
		preview_timer -= delta
		if auto_restart_preview and preview_emitting and preview_timer <= 0.0:
			restart()

	queue_redraw()


func _spawn_electric_hit() -> void:
	burst_age = 0.0
	flash_age = 0.0
	var scale_safe: float = maxf(0.35, particle_scale)
	var facing: float = -1.0 if mirror_direction else 1.0

	_spawn_primary_bolts(facing, scale_safe)
	_spawn_cross_arcs(scale_safe)
	_spawn_ion_sparks(scale_safe)
	_spawn_core_nodes(scale_safe)
	set_process(true)


func _spawn_primary_bolts(facing: float, scale_safe: float) -> void:
	var directions: Array = [
		Vector2(facing, 0.0),
		Vector2(facing, -0.32).normalized(),
		Vector2(facing, 0.32).normalized(),
		Vector2(-facing * 0.32, -1.0).normalized(),
		Vector2(-facing * 0.20, 1.0).normalized()
	]

	for i in range(directions.size()):
		var direction: Vector2 = directions[i]
		var length: float = rng.randf_range(44.0, 78.0) * scale_safe
		var width: float = (3.8 if i == 0 else rng.randf_range(1.8, 3.0)) * scale_safe
		var points: PackedVector2Array = _make_lightning_path(Vector2.ZERO, direction, length, 8, 10.0 * scale_safe)
		_add_bolt(points, width, rng.randf_range(0.0, 0.035), rng.randf_range(0.18, 0.30), Color(0.90, 1.0, 1.0, 1.0), Color(0.0, 0.48, 1.0, 0.42))

		if points.size() > 3:
			var branch_start: Vector2 = points[rng.randi_range(2, points.size() - 2)]
			var branch_dir: Vector2 = direction.rotated(rng.randf_range(-1.1, 1.1)).normalized()
			if branch_dir.dot(direction) < 0.10:
				branch_dir = direction.rotated(0.85 if rng.randf() < 0.5 else -0.85).normalized()
			var branch_points: PackedVector2Array = _make_lightning_path(branch_start, branch_dir, rng.randf_range(18.0, 38.0) * scale_safe, 4, 7.0 * scale_safe)
			_add_bolt(branch_points, rng.randf_range(1.0, 1.8) * scale_safe, rng.randf_range(0.02, 0.08), rng.randf_range(0.13, 0.23), Color(0.70, 0.95, 1.0, 0.92), Color(0.12, 0.24, 1.0, 0.24))


func _spawn_cross_arcs(scale_safe: float) -> void:
	for _i in range(5):
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(18.0, 34.0) * scale_safe
		var start: Vector2 = Vector2.RIGHT.rotated(angle) * radius * rng.randf_range(0.24, 0.55)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle + rng.randf_range(-0.62, 0.62)).normalized()
		var points: PackedVector2Array = _make_lightning_path(start, direction, rng.randf_range(18.0, 42.0) * scale_safe, 5, 8.5 * scale_safe)
		_add_bolt(points, rng.randf_range(1.0, 2.2) * scale_safe, rng.randf_range(0.0, 0.09), rng.randf_range(0.12, 0.24), Color(0.58, 0.88, 1.0, 0.86), Color(0.06, 0.18, 1.0, 0.24))


func _spawn_ion_sparks(scale_safe: float) -> void:
	var palette: Array = [
		Color(1.0, 1.0, 1.0, 0.98),
		Color(0.56, 0.90, 1.0, 0.92),
		Color(0.05, 0.55, 1.0, 0.88),
		Color(0.46, 0.28, 1.0, 0.82)
	]
	for _i in range(42):
		var direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		if rng.randf() < 0.58:
			direction.x = abs(direction.x) * (-1.0 if mirror_direction else 1.0)
			direction = direction.normalized()
		var speed: float = rng.randf_range(52.0, 196.0) * scale_safe
		sparks.append({
			"age": rng.randf_range(-0.03, 0.04),
			"lifetime": rng.randf_range(0.12, 0.34),
			"position": direction * rng.randf_range(1.0, 12.0) * scale_safe,
			"velocity": direction * speed,
			"gravity": Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(22.0, 78.0)) * scale_safe,
			"damping": rng.randf_range(0.70, 0.88),
			"size": rng.randf_range(1.4, 3.6) * scale_safe,
			"stretch": rng.randf_range(2.4, 6.8),
			"color": palette[rng.randi_range(0, palette.size() - 1)],
			"shape": "spark"
		})


func _spawn_core_nodes(scale_safe: float) -> void:
	for _i in range(10):
		var direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		sparks.append({
			"age": rng.randf_range(0.0, 0.08),
			"lifetime": rng.randf_range(0.16, 0.28),
			"position": direction * rng.randf_range(1.0, 18.0) * scale_safe,
			"velocity": direction * rng.randf_range(10.0, 44.0) * scale_safe,
			"gravity": Vector2.ZERO,
			"damping": rng.randf_range(0.58, 0.78),
			"size": rng.randf_range(2.4, 5.8) * scale_safe,
			"color": Color(0.88, 1.0, 1.0, rng.randf_range(0.78, 0.98)),
			"shape": "node"
		})


func _add_bolt(points: PackedVector2Array, width: float, delay: float, lifetime: float, color: Color, glow: Color) -> void:
	bolts.append({
		"age": -delay,
		"lifetime": lifetime,
		"points": points,
		"width": width,
		"color": color,
		"glow": glow,
		"phase": rng.randf_range(0.0, TAU)
	})


func _make_lightning_path(start: Vector2, direction: Vector2, length: float, segments: int, jitter: float) -> PackedVector2Array:
	var safe_segments: int = maxi(2, segments)
	var safe_direction: Vector2 = direction.normalized()
	if safe_direction.length_squared() < 0.01:
		safe_direction = Vector2.RIGHT
	var perpendicular: Vector2 = Vector2(-safe_direction.y, safe_direction.x)
	var points: PackedVector2Array = PackedVector2Array()

	for i in range(safe_segments + 1):
		var t: float = float(i) / float(safe_segments)
		var taper: float = sin(t * PI)
		var offset: float = rng.randf_range(-jitter, jitter) * taper
		var along: float = length * t + rng.randf_range(-2.5, 2.5) * taper
		points.append(start + safe_direction * along + perpendicular * offset)

	return points


func _update_effect(delta: float) -> void:
	burst_age += delta
	flash_age += delta
	_update_list(bolts, delta)
	_update_list(sparks, delta)


func _update_list(list: Array, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var particle: Dictionary = list[i]
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = maxf(0.01, float(particle.get("lifetime", 0.2)))
		if age >= lifetime:
			list.remove_at(i)
			continue

		if particle.has("velocity"):
			var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
			var gravity: Vector2 = particle.get("gravity", Vector2.ZERO)
			var particle_position: Vector2 = particle.get("position", Vector2.ZERO)
			var damping: float = float(particle.get("damping", 0.82))
			velocity += gravity * delta
			velocity *= pow(damping, delta * 8.0)
			particle_position += velocity * delta
			particle["velocity"] = velocity
			particle["position"] = particle_position

		particle["age"] = age
		list[i] = particle


func _draw() -> void:
	_draw_flash()
	_draw_bolts()
	_draw_sparks()


func _draw_flash() -> void:
	var progress: float = clampf(flash_age / 0.16, 0.0, 1.0)
	if progress >= 1.0:
		return

	var scale_safe: float = maxf(0.35, particle_scale)
	var alpha: float = (1.0 - progress) * 0.92
	var core_radius: float = lerp(8.0, 22.0, progress) * scale_safe
	draw_circle(Vector2.ZERO, core_radius * 1.9, Color(0.05, 0.35, 1.0, alpha * 0.22))
	draw_circle(Vector2.ZERO, core_radius, Color(0.80, 0.96, 1.0, alpha * 0.72))
	draw_circle(Vector2.ZERO, core_radius * 0.42, Color(1.0, 1.0, 1.0, alpha))

	var star_length: float = lerp(20.0, 54.0, progress) * scale_safe
	for i in range(8):
		var direction: Vector2 = Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
		var line_alpha: float = alpha * (0.72 if i % 2 == 0 else 0.42)
		draw_line(-direction * star_length * 0.22, direction * star_length, Color(0.70, 0.94, 1.0, line_alpha), maxf(1.0, 2.8 * scale_safe * (1.0 - progress)), true)


func _draw_bolts() -> void:
	for bolt in bolts:
		var age: float = float(bolt.get("age", 0.0))
		if age < 0.0:
			continue
		var lifetime: float = maxf(0.01, float(bolt.get("lifetime", 0.18)))
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var base_points: PackedVector2Array = bolt.get("points", PackedVector2Array())
		if base_points.size() < 2:
			continue

		var draw_amount: float = clampf(progress * 2.4, 0.0, 1.0)
		var points: PackedVector2Array = _slice_points(base_points, draw_amount)
		if points.size() < 2:
			continue

		var fade: float = 1.0 - smoothstep(0.46, 1.0, progress)
		var flicker: float = 0.70 + abs(sin(float(bolt.get("phase", 0.0)) + progress * 42.0)) * 0.30
		var color: Color = bolt.get("color", Color.WHITE)
		var glow: Color = bolt.get("glow", Color(0.0, 0.45, 1.0, 0.30))
		color.a *= fade * flicker
		glow.a *= fade * flicker
		var width: float = float(bolt.get("width", 2.0)) * (1.0 - progress * 0.35)
		draw_polyline(points, glow, maxf(1.0, width * 4.2), true)
		draw_polyline(points, color, maxf(1.0, width), true)

		if points.size() > 2 and progress < 0.74:
			for point in points:
				draw_circle(point, maxf(0.8, width * 0.45), Color(0.95, 1.0, 1.0, color.a * 0.48))


func _draw_sparks() -> void:
	for spark in sparks:
		var age: float = float(spark.get("age", 0.0))
		if age < 0.0:
			continue
		var lifetime: float = maxf(0.01, float(spark.get("lifetime", 0.22)))
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var color: Color = spark.get("color", Color.WHITE)
		color.a *= 1.0 - smoothstep(0.45, 1.0, progress)
		var spark_position: Vector2 = spark.get("position", Vector2.ZERO)
		var spark_size: float = float(spark.get("size", 2.0)) * lerp(1.0, 0.35, progress)
		var shape: String = str(spark.get("shape", "spark"))

		if shape == "node":
			draw_circle(spark_position, maxf(0.9, spark_size * 1.65), Color(0.0, 0.42, 1.0, color.a * 0.22))
			draw_circle(spark_position, maxf(0.7, spark_size), color)
			draw_circle(spark_position, maxf(0.4, spark_size * 0.42), Color(1.0, 1.0, 1.0, minf(1.0, color.a * 1.25)))
			continue

		var velocity: Vector2 = spark.get("velocity", Vector2.RIGHT)
		var direction: Vector2 = velocity.normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT
		var length: float = spark_size * float(spark.get("stretch", 3.0))
		draw_line(spark_position - direction * length * 0.36, spark_position + direction * length * 0.64, Color(0.0, 0.38, 1.0, color.a * 0.30), maxf(1.0, spark_size * 1.35), true)
		draw_line(spark_position - direction * length * 0.28, spark_position + direction * length * 0.58, color, maxf(1.0, spark_size * 0.42), true)


func _slice_points(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if points.size() < 2:
		return points

	var clamped_amount: float = clampf(amount, 0.0, 1.0)
	var total_length: float = 0.0
	for i in range(points.size() - 1):
		total_length += points[i].distance_to(points[i + 1])

	if total_length <= 0.01:
		return points

	var target_length: float = total_length * clamped_amount
	var result: PackedVector2Array = PackedVector2Array()
	result.append(points[0])
	var covered: float = 0.0
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var end: Vector2 = points[i + 1]
		var segment_length: float = start.distance_to(end)
		if covered + segment_length >= target_length:
			var local_amount: float = (target_length - covered) / maxf(0.01, segment_length)
			result.append(start.lerp(end, local_amount))
			return result
		result.append(end)
		covered += segment_length

	return result
