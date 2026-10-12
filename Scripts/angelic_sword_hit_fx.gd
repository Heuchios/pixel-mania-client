@tool
extends Node2D
## A brilliant ruby impact that shatters into tumbling, faceted crystal shards.

const LIFETIME := 1.15
const PARTICLE_COUNT := 36
const RubyGem := preload("res://Scripts/ruby_gem_particle.gd")

@export var preview_emitting := true
@export var auto_restart_preview := true
@export_range(1.2, 3.0, 0.05) var preview_interval := 1.45

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
		var kind := "gem" if index < 8 else ("chip" if index < 22 else "spark")
		var angle := float(index) * TAU / 8.0 if kind == "gem" else (float(index - 8) * TAU / 14.0 if kind == "chip" else float(index - 22) * TAU / 14.0)
		angle += rng.randf_range(-0.15, 0.15)
		var speed := rng.randf_range(140.0, 190.0) if kind == "gem" else rng.randf_range(95.0, 170.0)
		particles.append({
			"kind": kind, "velocity": Vector2.from_angle(angle) * speed,
			"delay": rng.randf_range(0.0, 0.025),
			"lifetime": rng.randf_range(0.78, 1.02) if kind == "gem" else rng.randf_range(0.48, 0.82),
			"size": rng.randf_range(3.0, 4.4) if kind == "gem" else (rng.randf_range(1.2, 2.4) if kind == "chip" else rng.randf_range(0.6, 1.1)),
			"drag": 4.5 if kind == "gem" else 4.0,
			"phase": rng.randf_range(0.0, TAU), "angle": rng.randf_range(-PI, PI),
			"spin": rng.randf_range(-4.0, 4.0)
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
	point.y += (22.0 if particle.kind == "gem" else 12.0) * elapsed * elapsed
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
		var alpha := smoothstep(0.0, 0.045, t) * (1.0 - smoothstep(0.48, 1.0, t))
		var point := _particle_position(particle, elapsed)
		var size := float(particle.size) * lerpf(1.0, 0.65, t)
		if particle.kind != "spark":
			var angle := (float(particle.angle) + elapsed * float(particle.spin)) * facing
			var glint := pow(maxf(0.0, sin(elapsed * 8.0 + float(particle.phase))), 4.0)
			RubyGem.draw_gem(self, point, size, angle, alpha, glint)
		else:
			_draw_glint(point, size, alpha)


func _draw_contact() -> void:
	var t := clampf(age / 0.30, 0.0, 1.0)
	if t >= 1.0:
		return
	var alpha := 1.0 - smoothstep(0.18, 1.0, t)
	var axis := Vector2(0.72 * facing, -0.694).normalized()
	var normal := axis.orthogonal()
	var bloom := 1.0 - pow(1.0 - clampf(t / 0.35, 0.0, 1.0), 3.0)
	# A broad ruby flash stays legible against both pale blocks and dark caves.
	RubyGem.draw_glow(self, Vector2.ZERO, 18.0 + bloom * 17.0, alpha * 0.60)
	var cut_t := clampf(age / 0.23, 0.0, 1.0)
	if cut_t < 1.0:
		var cut_alpha := pow(1.0 - cut_t, 1.1)
		var length := lerpf(14.0, 37.0, 1.0 - pow(1.0 - cut_t, 3.0))
		var width := lerpf(4.2, 0.65, cut_t)
		for layer in range(3):
			var radius: float = width * [2.2, 1.0, 0.26][layer]
			var tint: Color = [Color(0.68, 0.015, 0.16, cut_alpha * 0.22), Color(1.0, 0.055, 0.23, cut_alpha), Color(1.0, 0.82, 0.87, cut_alpha)][layer]
			draw_colored_polygon(PackedVector2Array([-axis * length, normal * radius, axis * length, -normal * radius]), tint)
	var size := lerpf(5.0, 11.0, bloom) * (1.0 - smoothstep(0.3, 1.0, t) * 0.55)
	RubyGem.draw_gem(self, Vector2.ZERO, size, (PI * 0.25 + t * 0.15) * facing, alpha, 1.0 - t)
	_draw_glint(Vector2.ZERO, 4.0, maxf(0.0, 1.0 - age / 0.09))


func _draw_glint(point: Vector2, size: float, alpha: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0, -size), point + Vector2(size * 0.2, -size * 0.2),
		point + Vector2(size, 0), point + Vector2(size * 0.2, size * 0.2),
		point + Vector2(0, size), point + Vector2(-size * 0.2, size * 0.2),
		point + Vector2(-size, 0), point + Vector2(-size * 0.2, -size * 0.2)
	]), Color(1.0, 0.52, 0.63, alpha))
