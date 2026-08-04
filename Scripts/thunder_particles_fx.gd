@tool
extends Node2D

@export var preview_emitting: bool = true
@export var auto_restart_preview: bool = true
@export var preview_interval: float = 0.62
@export var target_offset: Vector2 = Vector2(82.0, -4.0)
@export var bolt_width: float = 2.2
@export var impact_scale: float = 1.0
@export var loop_in_game: bool = false

const EFFECT_Z_INDEX := 4086
const ARC_LIFETIME := 0.42

var rng := RandomNumberGenerator.new()
var bolts: Array = []
var sparks: Array = []
var rings: Array = []
var flash_age := 999.0
var preview_timer := 0.0
var one_shot := false
var tip_gpu_sparks: GPUParticles2D = null
var impact_gpu_sparks: GPUParticles2D = null


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	collect_gpu_emitters()
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


func set_target_offset(offset: Vector2) -> void:
	target_offset = _safe_target_offset(offset)


func restart() -> void:
	clear()
	preview_timer = preview_interval
	_spawn_thunder_arc()
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
	rings.clear()
	flash_age = 999.0
	stop_gpu_emitters()
	queue_redraw()


func _process(delta: float) -> void:
	if not preview_emitting and not loop_in_game and bolts.is_empty() and sparks.is_empty() and rings.is_empty():
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


func _spawn_thunder_arc() -> void:
	flash_age = 0.0
	var end: Vector2 = _safe_target_offset(target_offset)
	var length: float = end.length()
	var direction: Vector2 = end.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var segment_count: int = clampi(int(round(length / 4.0)), 8, 34)
	var jitter: float = clampf(length * 0.08, 5.0, 18.0)
	var width: float = maxf(1.4, bolt_width)

	var main_points := _make_arc_path(Vector2.ZERO, end, segment_count, jitter)
	_add_bolt(main_points, width, 0.0, 0.24, Color(0.95, 1.0, 1.0, 1.0), Color(0.00, 0.46, 1.0, 0.42))

	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var offset: Vector2 = perpendicular * rng.randf_range(1.5, 4.5) * side
		var arc_points := _make_arc_path(offset * 0.35, end + offset * 0.45, segment_count - 1, jitter * 0.62)
		_add_bolt(arc_points, width * rng.randf_range(0.48, 0.72), rng.randf_range(0.015, 0.05), 0.20, Color(0.50, 0.90, 1.0, 0.92), Color(0.12, 0.20, 1.0, 0.26))

	var branch_total: int = clampi(int(round(length / 18.0)), 4, 9)
	for _i in range(branch_total):
		if main_points.size() < 4:
			continue
		var branch_index: int = rng.randi_range(1, main_points.size() - 2)
		var start: Vector2 = main_points[branch_index]
		var branch_side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var branch_end: Vector2 = start + (direction * rng.randf_range(10.0, 26.0)) + (perpendicular * branch_side * rng.randf_range(12.0, 34.0))
		var branch_points := _make_arc_path(start, branch_end, rng.randi_range(4, 7), jitter * 0.42)
		_add_bolt(branch_points, width * rng.randf_range(0.36, 0.56), rng.randf_range(0.02, 0.09), 0.16, Color(0.66, 0.96, 1.0, 0.88), Color(0.08, 0.18, 1.0, 0.22))

	_spawn_start_sparks(direction, width)
	_spawn_impact_sparks(end, direction, width)
	restart_gpu_emitters(end, direction)
	set_process(true)


func collect_gpu_emitters() -> void:
	tip_gpu_sparks = get_node_or_null("TipGPUSparks") as GPUParticles2D
	impact_gpu_sparks = get_node_or_null("ImpactGPUSparks") as GPUParticles2D

	for emitter in [tip_gpu_sparks, impact_gpu_sparks]:
		if emitter == null:
			continue
		if emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate(true)
		emitter.emitting = false


func restart_gpu_emitters(end: Vector2, direction: Vector2) -> void:
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() < 0.01:
		safe_direction = Vector2.RIGHT

	restart_gpu_emitter(tip_gpu_sparks, Vector2.ZERO, safe_direction)
	restart_gpu_emitter(impact_gpu_sparks, end, -safe_direction)


func restart_gpu_emitter(emitter: GPUParticles2D, emitter_position: Vector2, direction: Vector2) -> void:
	if emitter == null or not is_instance_valid(emitter):
		return

	emitter.position = emitter_position
	var material := emitter.process_material
	if material is ParticleProcessMaterial:
		material.direction = Vector3(direction.x, direction.y, 0.0)

	emitter.emitting = false
	emitter.restart()
	emitter.emitting = true


func stop_gpu_emitters() -> void:
	for emitter in [tip_gpu_sparks, impact_gpu_sparks]:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false


func _spawn_start_sparks(direction: Vector2, width: float) -> void:
	for _i in range(12):
		var spark_direction: Vector2 = (direction.rotated(rng.randf_range(-1.4, 1.4)) * rng.randf_range(0.4, 1.0) - direction * rng.randf_range(0.15, 0.45)).normalized()
		_add_spark(Vector2.ZERO, spark_direction * rng.randf_range(36.0, 96.0), rng.randf_range(0.10, 0.20), rng.randf_range(0.9, 1.8) * width, Color(0.72, 0.95, 1.0, 0.82))


func _spawn_impact_sparks(end: Vector2, direction: Vector2, width: float) -> void:
	var scale_safe: float = clampf(impact_scale, 0.35, 1.45)
	var perpendicular := Vector2(-direction.y, direction.x)

	for _i in range(10):
		var fork_direction: Vector2 = (-direction * rng.randf_range(14.0, 32.0)) + (perpendicular * rng.randf_range(-24.0, 24.0))
		var fork_end: Vector2 = end + fork_direction * scale_safe
		var fork_points := _make_arc_path(end, fork_end, rng.randi_range(4, 7), rng.randf_range(2.8, 6.4) * scale_safe)
		_add_bolt(fork_points, width * rng.randf_range(0.38, 0.68) * scale_safe, rng.randf_range(0.0, 0.035), 0.17, Color(0.90, 1.0, 1.0, 0.96), Color(0.12, 0.45, 1.0, 0.30))

	for _i in range(32):
		var base_direction: Vector2 = (-direction * rng.randf_range(0.38, 1.0)) + (perpendicular * rng.randf_range(-0.90, 0.90))
		base_direction = base_direction.normalized()
		var color := Color(0.88, 1.0, 1.0, rng.randf_range(0.70, 0.96))
		if rng.randf() < 0.28:
			color = Color(0.18, 0.68, 1.0, rng.randf_range(0.62, 0.86))
		_add_spark(
			end + base_direction * rng.randf_range(0.0, 6.4) * scale_safe,
			base_direction * rng.randf_range(58.0, 164.0) * scale_safe,
			rng.randf_range(0.11, 0.25),
			rng.randf_range(0.76, 1.42) * width * scale_safe,
			color,
			Vector2(1.9, 3.8)
		)

	for i in range(2):
		rings.append({
			"age": -float(i) * 0.035,
			"lifetime": 0.22 + float(i) * 0.045,
			"position": end,
			"radius": rng.randf_range(4.2, 7.4) * scale_safe,
			"radius_velocity": rng.randf_range(34.0, 58.0) * scale_safe,
			"width": rng.randf_range(1.0, 1.55) * scale_safe,
			"color": Color(0.54, 0.92, 1.0, 0.56)
		})


func _add_spark(spark_position: Vector2, velocity: Vector2, lifetime: float, spark_size: float, color: Color, stretch_range: Vector2 = Vector2(2.6, 6.0)) -> void:
	sparks.append({
		"age": rng.randf_range(-0.015, 0.035),
		"lifetime": lifetime,
		"position": spark_position,
		"velocity": velocity,
		"gravity": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(10.0, 42.0)),
		"damping": rng.randf_range(0.72, 0.90),
		"size": spark_size,
		"stretch": rng.randf_range(stretch_range.x, stretch_range.y),
		"color": color
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


func _make_arc_path(start: Vector2, end: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var safe_segments: int = maxi(2, segments)
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	var phase: float = rng.randf_range(0.0, TAU)

	for i in range(safe_segments + 1):
		var t: float = float(i) / float(safe_segments)
		var taper: float = sin(t * PI)
		var wave: float = sin(t * TAU * 1.6 + phase) * jitter * 0.30 * taper
		var snap: float = rng.randf_range(-jitter, jitter) * taper
		var along_offset: float = rng.randf_range(-2.0, 2.0) * taper
		var point: Vector2 = start.lerp(end, t) + direction * along_offset + perpendicular * (snap + wave)
		if i == 0:
			point = start
		elif i == safe_segments:
			point = end
		points.append(point)

	return points


func _update_effect(delta: float) -> void:
	flash_age += delta
	_update_motion_list(bolts, delta)
	_update_motion_list(sparks, delta)
	_update_motion_list(rings, delta)


func _update_motion_list(list: Array, delta: float) -> void:
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

		if particle.has("radius_velocity"):
			particle["radius"] = float(particle.get("radius", 0.0)) + float(particle.get("radius_velocity", 0.0)) * delta

		particle["age"] = age
		list[i] = particle


func _draw() -> void:
	_draw_impact_flash()
	_draw_bolts()
	_draw_rings()
	_draw_sparks()


func _draw_impact_flash() -> void:
	var progress: float = clampf(flash_age / 0.16, 0.0, 1.0)
	if progress >= 1.0:
		return

	var end: Vector2 = _safe_target_offset(target_offset)
	var alpha: float = (1.0 - progress) * 0.78
	var radius: float = lerp(5.4, 19.0, progress) * clampf(impact_scale, 0.35, 1.45)
	draw_circle(end, radius * 0.66, Color(0.12, 0.58, 1.0, alpha * 0.30))
	draw_circle(end, maxf(2.2, radius * 0.26), Color(1.0, 1.0, 1.0, alpha))

	for i in range(9):
		var direction := Vector2.RIGHT.rotated(float(i) * TAU / 9.0 + 0.22)
		var side := -1.0 if i % 2 == 0 else 1.0
		var perpendicular := Vector2(-direction.y, direction.x)
		var finish_distance := radius * (0.86 if i % 2 == 0 else 0.58)
		var points := PackedVector2Array([
			end + direction * radius * 0.12,
			end + direction * finish_distance * 0.46 + perpendicular * radius * 0.18 * side,
			end + direction * finish_distance
		])
		draw_polyline(points, Color(0.86, 0.98, 1.0, alpha * (0.78 if i % 2 == 0 else 0.46)), maxf(1.0, radius * 0.10), false)


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

		var draw_amount: float = clampf(progress * 3.2, 0.0, 1.0)
		var points: PackedVector2Array = _slice_points(base_points, draw_amount)
		if points.size() < 2:
			continue

		var fade: float = 1.0 - smoothstep(0.42, 1.0, progress)
		var flicker: float = 0.68 + abs(sin(float(bolt.get("phase", 0.0)) + progress * 54.0)) * 0.32
		var color: Color = bolt.get("color", Color.WHITE)
		var glow: Color = bolt.get("glow", Color(0.0, 0.45, 1.0, 0.30))
		color.a *= fade * flicker
		glow.a *= fade * flicker * 0.62
		var width: float = float(bolt.get("width", 2.0)) * (1.0 - progress * 0.35)
		draw_polyline(points, glow, maxf(1.0, width * 2.2), false)
		draw_polyline(points, color, maxf(1.0, width), false)

		var head: Vector2 = points[points.size() - 1]
		draw_rect(Rect2(head - Vector2.ONE * maxf(1.0, width * 0.45), Vector2.ONE * maxf(2.0, width * 0.9)), Color(0.92, 1.0, 1.0, color.a * 0.72), true)

		if points.size() > 3 and progress < 0.78:
			for point_index in range(1, points.size() - 1, 3):
				var node_position: Vector2 = points[point_index]
				draw_rect(Rect2(node_position - Vector2.ONE, Vector2(2.0, 2.0)), Color(0.96, 1.0, 1.0, color.a * 0.54), true)


func _draw_rings() -> void:
	for ring in rings:
		var age: float = float(ring.get("age", 0.0))
		if age < 0.0:
			continue
		var lifetime: float = maxf(0.01, float(ring.get("lifetime", 0.24)))
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var color: Color = ring.get("color", Color(0.54, 0.92, 1.0, 0.72))
		color.a *= 1.0 - smoothstep(0.28, 1.0, progress)
		var ring_position: Vector2 = ring.get("position", Vector2.ZERO)
		var radius: float = float(ring.get("radius", 8.0))
		var width: float = maxf(1.0, float(ring.get("width", 1.2)) * (1.0 - progress * 0.4))
		draw_arc(ring_position, radius, 0.0, TAU, 28, color, width, false)


func _draw_sparks() -> void:
	for spark in sparks:
		var age: float = float(spark.get("age", 0.0))
		if age < 0.0:
			continue
		var lifetime: float = maxf(0.01, float(spark.get("lifetime", 0.18)))
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var color: Color = spark.get("color", Color.WHITE)
		color.a *= 1.0 - smoothstep(0.42, 1.0, progress)
		var spark_position: Vector2 = spark.get("position", Vector2.ZERO)
		var spark_size: float = maxf(0.8, float(spark.get("size", 2.0)) * lerp(1.0, 0.28, progress))
		var velocity: Vector2 = spark.get("velocity", Vector2.RIGHT)
		var direction: Vector2 = velocity.normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT
		var length: float = spark_size * float(spark.get("stretch", 4.0))
		draw_line(spark_position - direction * length * 0.35, spark_position + direction * length * 0.65, Color(0.0, 0.32, 1.0, color.a * 0.20), maxf(1.0, spark_size * 0.92), false)
		draw_line(spark_position - direction * length * 0.25, spark_position + direction * length * 0.55, color, maxf(1.0, spark_size * 0.36), false)


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
	var result := PackedVector2Array()
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


func _safe_target_offset(offset: Vector2) -> Vector2:
	if offset.length_squared() < 4.0:
		return Vector2(32.0, 0.0)
	return offset
