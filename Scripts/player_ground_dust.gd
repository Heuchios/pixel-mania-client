extends Node2D
## Short, world-space dust puffs shared by local and remote floor contacts.

const NODE_NAME := "GroundDust"
const MAX_PARTICLES := 48
const TELEPORT_DISTANCE := 80.0
static var puff := PackedVector2Array([
	Vector2(-10, -1), Vector2(-10, -5), Vector2(-7, -5), Vector2(-7, -8),
	Vector2(-3, -8), Vector2(-3, -10), Vector2(2, -10), Vector2(2, -8),
	Vector2(6, -8), Vector2(6, -5), Vector2(9, -5), Vector2(9, -1),
	Vector2(11, -1), Vector2(11, 3), Vector2(8, 3), Vector2(8, 6),
	Vector2(3, 6), Vector2(3, 8), Vector2(-3, 8), Vector2(-3, 6),
	Vector2(-8, 6), Vector2(-8, 3), Vector2(-11, 3), Vector2(-11, -1)
])
static var light := PackedVector2Array([
	Vector2(-7, -2), Vector2(-7, -5), Vector2(-3, -5), Vector2(-3, -8),
	Vector2(1, -8), Vector2(1, -6), Vector2(5, -6), Vector2(5, -3),
	Vector2(7, -3), Vector2(7, 0), Vector2(3, 0), Vector2(3, 2),
	Vector2(-2, 2), Vector2(-2, 0), Vector2(-6, 0), Vector2(-6, -2)
])

var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var contact_initialized := false
var was_grounded := false
var previous_feet := Vector2.ZERO
var air_time := 0.0
var fall_speed := 0.0


static func attach(actor: Node2D) -> Node2D:
	var effect := actor.get_node_or_null(NODE_NAME)
	if effect == null:
		effect = new()
		effect.name = NODE_NAME
		actor.add_child(effect)
	return effect


func _ready() -> void:
	# Front feet and split trouser legs use higher layers than the rear foot.
	# Keep the whole contact cloud above both legs, below the torso (layer 30).
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	set_process(false)


func reset_contact() -> void:
	contact_initialized = false
	air_time = 0.0
	fall_speed = 0.0
	particles.clear()
	queue_redraw()
	set_process(false)


func observe_contact(feet: Vector2, grounded: bool, vertical_speed: float, delta: float, enabled: bool = true, discontinuity: bool = false, delay: float = 0.0) -> void:
	if not enabled or discontinuity or not feet.is_finite():
		reset_contact()
		return
	# Initial placement and teleports must not masquerade as landings.
	if not contact_initialized or previous_feet.distance_to(feet) > TELEPORT_DISTANCE or delta > 0.35:
		reset_contact()
		contact_initialized = true
		was_grounded = grounded
		previous_feet = feet
		return
	if not grounded:
		air_time += maxf(delta, 0.0)
		fall_speed = maxf(fall_speed, vertical_speed)
		if was_grounded and vertical_speed < -40.0:
			emit_burst(previous_feet, false, 1.0, delay)
	elif not was_grounded:
		fall_speed = maxf(fall_speed, vertical_speed)
		if air_time >= 0.055 and fall_speed >= 55.0:
			emit_burst(feet, true, clampf(fall_speed / 430.0, 0.45, 1.25), delay)
		air_time = 0.0
		fall_speed = 0.0
	was_grounded = grounded
	previous_feet = feet


func emit_burst(feet: Vector2, landing: bool, strength: float = 1.0, delay: float = 0.0) -> void:
	var count := (12 if landing else 8)
	var rise := 0.45 if landing else 1.0
	for index in range(count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var lane := float(index / 2) / float(count / 2 - 1)
		var fleck := index >= count - 2
		var size := rng.randf_range(3.5, 5.4) * (1.15 if landing else 0.85) * lerpf(0.85, 1.1, strength)
		if fleck:
			size *= 0.42
		particles.append({
			"origin": feet + Vector2(side * (2.0 + lane * 4.0), -size * (0.12 if landing else 0.45)),
			"velocity": Vector2(side * lerpf(24.0, 76.0, lane) * (strength if landing else 0.80), -rng.randf_range(12.0, 24.0) * (1.35 if fleck else 1.0) * rise),
			"age": -maxf(delay, 0.0) - rng.randf_range(0.0, 0.025),
			"lifetime": rng.randf_range(0.34, 0.49) + (0.04 if landing else 0.0),
			"size": size, "side": side, "rise": rise,
			"angle": rng.randf_range(-0.24, 0.24), "shade": rng.randf_range(0.92, 1.0)
		})
	while particles.size() > MAX_PARTICLES:
		particles.pop_front()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		particles[index].age += delta
		if float(particles[index].age) >= float(particles[index].lifetime):
			particles.remove_at(index)
	queue_redraw()
	if particles.is_empty():
		set_process(false)


func particle_position(particle: Dictionary) -> Vector2:
	var age := maxf(0.0, float(particle.age))
	var drift := (1.0 - exp(-5.5 * age)) / 5.5
	# Expansion slows first; small eddies then lift and disperse the cloud.
	return particle.origin + particle.velocity * drift + Vector2(float(particle.side) * sin(age * 9.0) * age * 2.0, -12.0 * age * age * float(particle.rise))


func _draw() -> void:
	for particle in particles:
		var age := float(particle.age)
		if age < 0.0:
			continue
		var t := age / float(particle.lifetime)
		var alpha := (1.0 - smoothstep(0.30, 1.0, t)) * 0.88
		var growth := lerpf(0.40, 1.25, 1.0 - pow(1.0 - minf(t / 0.35, 1.0), 3.0))
		var size := float(particle.size) * growth * lerpf(1.0, 0.55, smoothstep(0.55, 1.0, t)) / 11.0
		var point := to_local(particle_position(particle)).snapped(Vector2.ONE * 0.5)
		var angle := float(particle.angle) + float(particle.side) * age * 0.65
		draw_set_transform(point, angle, Vector2(size, size * lerpf(0.70, 1.0, t)))
		var shade := float(particle.shade)
		draw_colored_polygon(puff, Color(0.62 * shade, 0.64 * shade, 0.67 * shade, alpha * 0.75))
		draw_set_transform(point + Vector2(-0.35, -0.6), angle, Vector2(size * 0.84, size * 0.80))
		draw_colored_polygon(puff, Color(0.91 * shade, 0.92 * shade, 0.93 * shade, alpha))
		draw_colored_polygon(light, Color(1.0, 0.99, 0.96, alpha))
	draw_set_transform(Vector2.ZERO)
