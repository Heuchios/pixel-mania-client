@tool
extends Node2D
## A cosmetic singularity: three tine strikes, a turning rift, then an implosion.

const LIFETIME := 0.72
const SHARD_COUNT := 28
const RIFT_LIFETIME := 0.48

@export var preview_emitting := true
@export var auto_restart_preview := true
@export_range(0.8, 3.0, 0.05) var preview_interval := 1.2

var age := LIFETIME
var facing := 1.0
var one_shot := false
var preview_age := 0.0
var shards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	z_index = 4085
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	if preview_emitting:
		restart()
	else:
		set_process(false)


func play_once(facing_direction: int = 1) -> void:
	facing = -1.0 if facing_direction < 0 else 1.0
	preview_emitting = false
	auto_restart_preview = false
	one_shot = true
	restart()


func start() -> void:
	preview_emitting = true
	one_shot = false
	restart()


func stop() -> void:
	preview_emitting = false
	one_shot = false
	age = LIFETIME
	shards.clear()
	queue_redraw()
	set_process(false)


func restart() -> void:
	age = 0.0
	preview_age = 0.0
	shards.clear()
	for i in range(SHARD_COUNT):
		shards.append({
			"angle": float(i) * TAU / SHARD_COUNT + rng.randf_range(-0.12, 0.12),
			"radius": rng.randf_range(18.0, 32.0),
			"delay": rng.randf_range(0.0, 0.055),
			"lifetime": rng.randf_range(0.43, 0.64),
			"size": rng.randf_range(0.65, 1.45),
			"spin": rng.randf_range(1.6, 3.0),
			"bright": i % 4 == 0
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	preview_age += delta
	if age >= LIFETIME:
		shards.clear()
		if one_shot:
			queue_free()
		elif preview_emitting and auto_restart_preview:
			if preview_age >= preview_interval:
				restart()
		else:
			set_process(false)
	queue_redraw()


func _draw() -> void:
	if age >= LIFETIME:
		return
	_draw_shards()
	_draw_rift()
	_draw_tine_flash()


func _draw_tine_flash() -> void:
	var t := clampf(age / 0.13, 0.0, 1.0)
	if t >= 1.0:
		return
	var alpha := pow(1.0 - t, 1.5)
	var axis := Vector2(0.74 * facing, -0.67)
	var normal := axis.orthogonal()
	var length := lerpf(5.0, 24.0, 1.0 - pow(1.0 - t, 3.0))
	for tine in range(-1, 2):
		var center := normal * float(tine) * 5.0
		var tine_length := length * (1.0 if tine == 0 else 0.72)
		var shape := PackedVector2Array([center - axis * tine_length, center + normal * 1.6, center + axis * tine_length, center - normal * 1.6])
		draw_line(center - axis * tine_length, center + axis * tine_length, Color(0.65, 0.08, 1.0, alpha * 0.28), 5.0, false)
		draw_colored_polygon(shape, Color(0.91, 0.63, 1.0, alpha))
	draw_circle(Vector2.ZERO, 3.0 * (1.0 - t), Color(0.99, 0.9, 1.0, alpha))


func _draw_rift() -> void:
	var t := clampf(age / RIFT_LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		return
	var opening := 1.0 - pow(1.0 - clampf(t / 0.24, 0.0, 1.0), 3.0)
	var collapse := 1.0 - smoothstep(0.35, 1.0, t)
	var radius := 10.0 * opening * collapse
	var alpha := (1.0 - smoothstep(0.55, 1.0, t)) * opening
	# The dark center makes the violet rim read as a tear, even over bright blocks.
	draw_circle(Vector2.ZERO, radius * 1.7, Color(0.33, 0.03, 0.65, alpha * 0.13))
	draw_circle(Vector2.ZERO, radius, Color(0.025, 0.009, 0.07, alpha * 0.92))
	for arm in range(3):
		var points := PackedVector2Array()
		for step in range(25):
			var p := float(step) / 24.0
			var angle := float(arm) * TAU / 3.0 + p * 2.4 + age * 8.0 * facing
			var distance := radius * lerpf(0.72, 2.0, p)
			points.append(Vector2(cos(angle), sin(angle) * 0.82) * distance)
		draw_polyline(points, Color(0.46, 0.05, 0.85, alpha * 0.22), 3.4 * collapse + 0.2, false)
		draw_polyline(points, Color(0.76, 0.23, 1.0, alpha * 0.85), 1.1 * collapse + 0.2, false)
		var rim := PackedVector2Array()
		for step in range(13):
			var angle := arm * TAU / 3.0 + float(step) / 12.0 * 1.5 + age * 6.0 * facing
			rim.append(Vector2.from_angle(angle) * radius)
		draw_polyline(rim, Color(0.9, 0.6, 1.0, alpha * 0.8), 0.7, false)
	# A faint outward ripple contrasts with the inward-moving debris.
	var ring_t := clampf(age / 0.26, 0.0, 1.0)
	if ring_t < 1.0:
		var ring_radius := lerpf(4.0, 29.0, 1.0 - pow(1.0 - ring_t, 3.0))
		for arc in range(3):
			var angle := float(arc) * TAU / 3.0 + 0.3 * facing
			draw_arc(Vector2.ZERO, ring_radius, angle, angle + 1.6, 15, Color(0.61, 0.17, 1.0, pow(1.0 - ring_t, 2.0) * 0.5), 0.75, false)


func _shard_position(shard: Dictionary, t: float) -> Vector2:
	var expansion := 1.0 - pow(1.0 - clampf(t / 0.22, 0.0, 1.0), 3.0)
	var inward := 1.0 - smoothstep(0.24, 1.0, t)
	var radius := float(shard.radius) * expansion * inward
	var angle := float(shard.angle) + float(shard.spin) * t * t * facing
	return Vector2(cos(angle), sin(angle) * 0.86) * radius


func _draw_shards() -> void:
	for shard in shards:
		var t := (age - float(shard.delay)) / float(shard.lifetime)
		if t <= 0.0 or t >= 1.0:
			continue
		var alpha := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.45, 1.0, t))
		var point := _shard_position(shard, t)
		var tail := _shard_position(shard, maxf(0.0, t - 0.045))
		var size := float(shard.size) * (1.0 - t * 0.55)
		var axis := Vector2.from_angle(float(shard.angle) + t * 5.0 * facing) * size
		var normal := axis.orthogonal() * 0.5
		draw_line(tail, point, Color(0.57, 0.12, 0.94, alpha * 0.45), 0.6, false)
		draw_circle(point, size * 2.0, Color(0.5, 0.08, 0.9, alpha * 0.13))
		var color := Color(0.91, 0.71, 1.0, alpha) if bool(shard.bright) else Color(0.68, 0.25, 1.0, alpha)
		draw_colored_polygon(PackedVector2Array([point - axis, point + normal, point + axis, point - normal]), color)
