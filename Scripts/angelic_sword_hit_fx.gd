@tool
extends Node2D
## A short pearl-white cut that disperses into glints, dust and ivory feathers.

const LIFETIME := 1.05
const PARTICLE_COUNT := 28
const SPARKLE_TEXTURE := preload("res://Assets/effects/angel_wing_sparkle.svg")

@export var preview_emitting := true
@export var auto_restart_preview := true
@export_range(1.1, 3.0, 0.05) var preview_interval := 1.35

var age := LIFETIME
var facing := 1.0
var one_shot := false
var preview_age := 0.0
var particles: Array[Dictionary] = []
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
	particles.clear()
	queue_redraw()
	set_process(false)


func restart() -> void:
	age = 0.0
	preview_age = 0.0
	particles.clear()
	for index in range(PARTICLE_COUNT):
		var kind := "feather" if index < 4 else ("sparkle" if index < 12 else "dust")
		var angle := float(index) * TAU / 4.0 if kind == "feather" else (float(index - 4) * TAU / 8.0 if kind == "sparkle" else float(index - 12) * TAU / 16.0)
		angle += rng.randf_range(-0.18, 0.18)
		var speed := rng.randf_range(32.0, 52.0) if kind == "feather" else rng.randf_range(45.0, 95.0)
		particles.append({
			"kind": kind, "velocity": Vector2.from_angle(angle) * speed,
			"delay": rng.randf_range(0.0, 0.055),
			"lifetime": rng.randf_range(0.72, 0.90) if kind == "feather" else rng.randf_range(0.42, 0.78),
			"size": rng.randf_range(5.0, 7.0) if kind == "feather" else rng.randf_range(0.6, 1.55),
			"drag": 2.5 if kind == "feather" else 3.5,
			"phase": rng.randf_range(0.0, TAU), "angle": rng.randf_range(-0.65, 0.65),
			"warmth": rng.randf()
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	preview_age += delta
	if age >= LIFETIME:
		particles.clear()
		if one_shot:
			queue_free()
		elif preview_emitting and auto_restart_preview:
			if preview_age >= preview_interval:
				restart()
		else:
			set_process(false)
	queue_redraw()


func _particle_position(particle: Dictionary, elapsed: float) -> Vector2:
	var travel := (1.0 - exp(-float(particle.drag) * elapsed)) / float(particle.drag)
	var point: Vector2 = particle.velocity * travel
	point.y += (9.0 if particle.kind == "feather" else -6.0) * elapsed * elapsed
	point.x += (sin(elapsed * 4.0 + float(particle.phase)) - sin(float(particle.phase))) * 2.0
	point.x *= facing
	return point


func _draw() -> void:
	if age >= LIFETIME:
		return
	_draw_contact()
	for particle in particles:
		var elapsed := age - float(particle.delay)
		var t := elapsed / float(particle.lifetime)
		if t <= 0.0 or t >= 1.0:
			continue
		var alpha := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.38, 1.0, t))
		var point := _particle_position(particle, elapsed)
		var size := float(particle.size) * lerpf(1.0, 0.55, t)
		if particle.kind == "feather":
			var flutter := sin(elapsed * 5.0 + float(particle.phase)) * 0.35
			_draw_feather(point, size, (float(particle.angle) + flutter) * facing, alpha)
		elif particle.kind == "sparkle":
			var twinkle := 0.65 + 0.35 * pow(sin(elapsed * 8.0 + float(particle.phase)), 2.0)
			_draw_glint(point, size, alpha * twinkle)
		else:
			var tint := Color("dfeaff").lerp(Color("fff3ce"), float(particle.warmth))
			draw_rect(Rect2(point - Vector2.ONE * size * 0.4, Vector2.ONE * size * 0.8), Color(tint, alpha * 0.85))


func _draw_contact() -> void:
	var t := clampf(age / 0.16, 0.0, 1.0)
	if t >= 1.0:
		return
	var alpha := pow(1.0 - t, 1.35)
	var axis := Vector2(0.72 * facing, -0.694).normalized()
	var normal := axis.orthogonal()
	var length := lerpf(9.0, 27.0, 1.0 - pow(1.0 - t, 3.0))
	var width := lerpf(2.3, 0.25, t)
	draw_circle(Vector2.ZERO, 8.0 + t * 8.0, Color(0.82, 0.88, 1.0, alpha * 0.07))
	for layer in range(3):
		var radius: float = width * [2.5, 1.0, 0.4][layer]
		var tint: Color = [Color(0.78, 0.86, 1.0, alpha * 0.12), Color(1.0, 0.92, 0.68, alpha * 0.8), Color(1.0, 1.0, 1.0, alpha)][layer]
		draw_colored_polygon(PackedVector2Array([-axis * length, normal * radius, axis * length, -normal * radius]), tint)
	_draw_glint(Vector2.ZERO, 3.0 + t * 4.0, alpha)


func _draw_glint(point: Vector2, size: float, alpha: float) -> void:
	draw_texture_rect(SPARKLE_TEXTURE, Rect2(point - Vector2.ONE * size * 2.0, Vector2.ONE * size * 4.0), false, Color(1.0, 1.0, 1.0, alpha * 0.22))
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0, -size), point + Vector2(size * 0.2, -size * 0.2),
		point + Vector2(size, 0), point + Vector2(size * 0.2, size * 0.2),
		point + Vector2(0, size), point + Vector2(-size * 0.2, size * 0.2),
		point + Vector2(-size, 0), point + Vector2(-size * 0.2, -size * 0.2)
	]), Color(1.0, 0.99, 0.93, alpha))


func _draw_feather(point: Vector2, size: float, angle: float, alpha: float) -> void:
	var axis := Vector2(sin(angle), cos(angle)) * size * 0.5
	var side := axis.orthogonal() * 0.36
	draw_colored_polygon(PackedVector2Array([
		point - axis, point - axis * 0.4 + side, point + axis * 0.45 + side * 0.7,
		point + axis, point + axis * 0.3 - side * 0.8, point - axis * 0.5 - side * 0.8
	]), Color(1.0, 0.96, 0.83, alpha * 0.8))
	draw_line(point - axis * 0.75, point + axis * 1.1, Color(1.0, 1.0, 1.0, alpha), 0.35, false)
	for step in [-0.25, 0.2]:
		var center := point + axis * float(step)
		draw_line(center - axis * 0.15 + side * 0.7, center, Color(1.0, 1.0, 0.94, alpha * 0.8), 0.25, false)
