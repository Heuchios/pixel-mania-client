extends Node2D
## Cosmetic Serpent Staff venom impact; keeps cast timing without a projectile.
## Damage and hit timing remain owned by the existing gameplay code.

const IMPACT_TIME := 0.64
const DROP_COUNT := 18
const TRAVEL_SPEED := 240.0

var destination := Vector2.ZERO
var direction := Vector2.RIGHT
var distance := 0.0
var duration := 0.3
var age := 0.0
var facing := 1.0
var launched := false
var drops: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20
	rng.randomize()
	set_process(launched)


func launch_to(start: Vector2, target: Vector2, facing_direction: int = 1) -> void:
	global_position = start
	destination = to_local(target)
	distance = destination.length()
	facing = -1.0 if facing_direction < 0 else 1.0
	direction = destination.normalized() if distance > 0.001 else Vector2.RIGHT * facing
	duration = clampf(distance / TRAVEL_SPEED, 0.24, 0.48)
	age = 0.0
	launched = true
	drops.clear()
	for index in range(DROP_COUNT):
		var spray := Vector2.from_angle(rng.randf_range(-PI, PI))
		drops.append({
			"velocity": spray * rng.randf_range(30.0, 78.0) + Vector2(0.0, -12.0),
			"delay": rng.randf_range(0.0, 0.045),
			"lifetime": rng.randf_range(0.30, 0.55),
			"size": rng.randf_range(0.75, 1.9),
			"phase": rng.randf_range(0.0, TAU),
			"bubble": index % 3 == 0
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration + IMPACT_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if launched and age >= duration:
		_draw_venom_impact(age - duration)


func _drop_position(drop: Dictionary, time: float) -> Vector2:
	if bool(drop.bubble):
		return drop.velocity * time * 0.36 + Vector2(sin(time * 11.0 + float(drop.phase)) * time * 4.0, -22.0 * time)
	return drop.velocity * (1.0 - exp(-time * 2.0)) / 2.0 + Vector2(0.0, 45.0 * time * time)


func _draw_venom_impact(time: float) -> void:
	if time >= IMPACT_TIME:
		return
	draw_set_transform(destination)
	# Two pale fang marks strike quickly, then leave a soft green stain of vapor.
	var flash := 1.0 - smoothstep(0.0, 0.13, time)
	var normal := direction.orthogonal()
	if flash > 0.0:
		for side in [-1.0, 1.0]:
			var center: Vector2 = normal * side * 3.4
			var fang := PackedVector2Array([center - direction * 5.0 - normal * 1.2, center + direction * 6.0, center - direction * 3.0 + normal * 1.2])
			draw_circle(center, 4.0, Color(0.43, 0.79, 0.17, flash * 0.18))
			draw_colored_polygon(fang, Color(0.92, 1.0, 0.66, flash))
	var mist_alpha := smoothstep(0.0, 0.045, time) * (1.0 - smoothstep(0.12, 0.5, time))
	for cloud in range(5):
		var offset := Vector2.from_angle(float(cloud) * 2.399) * (3.0 + time * 12.0)
		offset.y -= time * 10.0
		draw_circle(offset, 3.0 + time * 6.0, Color(0.24, 0.52, 0.18, mist_alpha * 0.10))
	# Curling venom wisps open around the bite and thin away without a hard cut.
	var coil_t := clampf(time / 0.34, 0.0, 1.0)
	var coil_alpha := sin(coil_t * PI) * (1.0 - coil_t)
	for coil in range(2):
		for step in range(17):
			var u := float(step) / 18.0
			var v := float(step + 1) / 18.0
			var radius := 5.0 + coil_t * 14.0
			var start_angle := float(coil) * PI + time * 5.0 * facing
			var a := Vector2.from_angle(start_angle + u * 2.6) * radius * Vector2(1.0, 0.72)
			var b := Vector2.from_angle(start_angle + v * 2.6) * radius * Vector2(1.0, 0.72)
			var alpha := sin(u * PI) * coil_alpha
			draw_line(a, b, Color(0.38, 0.77, 0.22, alpha * 0.75), 1.8 * (1.0 - coil_t) + 0.3, false)
	for drop in drops:
		var lived := time - float(drop.delay)
		var t := lived / float(drop.lifetime)
		if t <= 0.0 or t >= 1.0:
			continue
		var alpha := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.30, 1.0, t))
		var point := _drop_position(drop, lived)
		var size := float(drop.size) * (1.0 - t * 0.35)
		if bool(drop.bubble):
			draw_circle(point, size * 1.3, Color(0.12, 0.40, 0.24, alpha * 0.15))
			draw_arc(point, size * 1.3, 0.3, 5.9, 12, Color(0.49, 0.83, 0.27, alpha * 0.7), 0.65, false)
			draw_circle(point - Vector2.ONE * size * 0.35, size * 0.3, Color(0.85, 1.0, 0.55, alpha * 0.85))
		else:
			var tail := _drop_position(drop, maxf(0.0, lived - 0.04))
			draw_line(tail, point, Color(0.24, 0.58, 0.12, alpha * 0.55), size, false)
			draw_circle(point, size, Color(0.50, 0.81, 0.16, alpha))
			draw_circle(point - Vector2.ONE * size * 0.25, size * 0.35, Color(0.90, 1.0, 0.56, alpha))
	draw_set_transform(Vector2.ZERO)
