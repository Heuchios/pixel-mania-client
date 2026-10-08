extends Node2D
## A living flame edge, buoyant embers and a short ignition on accepted jumps.
## Reads the current wing pose only; the equipment manager owns its animation.

const FLAME_TEXTURE := preload("res://Assets/effects/dragon_wing_flame.svg")
const EMBER_TEXTURE := preload("res://Assets/effects/dragon_wing_ember.svg")
const GLOW_TEXTURE := preload("res://Assets/effects/lava_glow.svg")
const MAX_PARTICLES := 128
const IDLE_RATE := 22.0
const MOVING_RATE := 54.0
const JUMP_PARTICLES := 24

var wings: AnimatedSprite2D
var particles: Array[Dictionary] = []
var edge_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()
var moving := false
var clock := 0.0
var flap_age := 10.0
var credit := 0.0
var previous_origin := Vector2.ZERO
var tracking := false
var actor_velocity := Vector2.ZERO
var next_side := 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_priority = 90
	rng.randomize()
	clock = rng.randf_range(0.0, TAU)


func bind_wings(sprite: AnimatedSprite2D) -> void:
	if wings == sprite:
		return
	wings = sprite
	edge_cache.clear()
	clear()


func set_moving(value: bool) -> void:
	moving = value


func clear() -> void:
	particles.clear()
	credit = 0.0
	flap_age = 10.0
	tracking = false
	actor_velocity = Vector2.ZERO
	queue_redraw()


func trigger_flap() -> void:
	if not _can_emit():
		return
	flap_age = 0.0
	# Eight flame wisps and sixteen sparks, evenly split between the tips.
	for index in range(JUMP_PARTICLES):
		_emit_particle("flame" if index < 8 else "ember", true)
	queue_redraw()


func _can_emit() -> bool:
	return is_instance_valid(wings) and wings.is_visible_in_tree() and is_visible_in_tree()


func _edge_points() -> Array:
	if not is_instance_valid(wings) or wings.sprite_frames == null:
		return []
	var texture := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame)
	if texture == null:
		return []
	var key := texture.get_instance_id()
	if edge_cache.has(key):
		return edge_cache[key]
	var edges: Array[Vector2] = []
	var pixels := texture.get_image()
	if pixels == null:
		return edges
	if pixels.is_compressed():
		pixels.decompress()
	# Anchor to the actual silhouette in every pose, keeping fire off the body.
	for x in range(1, pixels.get_width() - 1, 2):
		if absf(float(x) - pixels.get_width() * 0.5) < 9.0:
			continue
		for y in range(pixels.get_height() - 1, -1, -1):
			if pixels.get_pixel(x, y).a > 0.5:
				edges.append(Vector2(x + 0.5, y + 0.5))
				break
	edge_cache[key] = edges
	return edges


func _wing_point(pixel: Vector2) -> Vector2:
	var texture := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame)
	var point := pixel
	if wings.centered:
		point -= texture.get_size() * 0.5
	point += wings.offset
	if wings.flip_h:
		point.x *= -1.0
	if wings.flip_v:
		point.y *= -1.0
	return wings.to_global(point)


func _emit_particle(kind: String = "", burst: bool = false) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	var edges := _edge_points()
	if edges.is_empty():
		return
	next_side *= -1.0
	var candidates: Array[Vector2] = []
	var width := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame).get_width()
	for edge in edges:
		if signf(float(edge.x) - width * 0.5) == next_side:
			candidates.append(edge)
	if candidates.is_empty():
		return
	var anchor := candidates[rng.randi_range(0, candidates.size() - 1)]
	if burst:
		anchor = candidates[0] if next_side < 0.0 else candidates[-1]
	var point := _wing_point(anchor)
	var world_scale := wings.global_transform.x.length()
	var outward := signf(point.x - wings.global_position.x)
	if kind == "":
		kind = "flame" if rng.randf() < (0.38 if moving else 0.25) else "ember"
	var flame := kind == "flame"
	var velocity := Vector2(outward * rng.randf_range(0.5, 3.0), -rng.randf_range(5.0, 12.0)) * world_scale
	velocity += actor_velocity.limit_length(80.0 * world_scale) * 0.06
	if burst:
		# Brief downward/outward downwash, then buoyancy lifts the fading sparks.
		velocity = Vector2(outward * rng.randf_range(12.0, 26.0), rng.randf_range(6.0, 22.0)) * world_scale
	var lifetime := rng.randf_range(0.6, 0.95) if flame else rng.randf_range(1.1, 1.7)
	var size := rng.randf_range(3.0, 5.5) if flame else rng.randf_range(0.45, 0.85)
	if flame and (moving or burst):
		size *= 1.35
	particles.append({
		"position": point, "velocity": velocity, "scale": world_scale,
		"kind": kind, "burst": burst, "age": 0.0, "lifetime": lifetime,
		"size": size, "phase": rng.randf_range(0.0, TAU),
		"lean": outward * rng.randf_range(0.15, 0.5),
		"lift": rng.randf_range(12.0, 20.0) if burst else rng.randf_range(2.0, 5.0)
	})


func _process(delta: float) -> void:
	clock += delta
	flap_age += delta
	if not _can_emit():
		clear()
		return
	var origin := wings.global_position
	var world_scale := maxf(0.01, wings.global_transform.x.length())
	if delta > 0.20 or (tracking and origin.distance_to(previous_origin) > 96.0 * world_scale):
		clear()
	actor_velocity = (origin - previous_origin) / maxf(delta, 0.001) if tracking else Vector2.ZERO
	previous_origin = origin
	tracking = true
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle.age += delta
		if particle.age >= particle.lifetime:
			particles.remove_at(index)
			continue
		particle.velocity.x = move_toward(float(particle.velocity.x), 0.0, 4.0 * float(particle.scale) * delta)
		particle.velocity.y -= float(particle.lift) * float(particle.scale) * delta
		particle.position += particle.velocity * delta
		particle.position.x += sin(float(particle.age) * 4.5 + float(particle.phase)) * 2.5 * float(particle.scale) * delta
	credit += delta * (MOVING_RATE if moving else IDLE_RATE)
	while credit >= 1.0:
		credit -= 1.0
		_emit_particle()
	queue_redraw()


func _draw() -> void:
	if not _can_emit():
		return
	_draw_burning_edges()
	for particle in particles:
		var t := float(particle.age) / float(particle.lifetime)
		var alpha := smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.35, 1.0, t))
		var point: Vector2 = particle.position
		var size := float(particle.size) * float(particle.scale) * lerpf(1.0, 0.3, t)
		if particle.kind == "flame":
			var curl := float(particle.lean) + sin(float(particle.age) * 7.0 + float(particle.phase)) * 0.3
			_draw_flame(point, size, curl, alpha * 0.72)
		else:
			var flicker := 0.75 + 0.25 * pow(sin(float(particle.age) * 5.0 + float(particle.phase)), 2.0)
			var tint := Color(1.0, lerpf(1.0, 0.35, t), lerpf(1.0, 0.2, t), alpha * flicker)
			_draw_sprite(GLOW_TEXTURE, point, Vector2.ONE * size * 4.0, 0.0, Color(1.0, 0.45, 0.15, alpha * 0.20))
			_draw_sprite(EMBER_TEXTURE, point, Vector2.ONE * size * 2.0, float(particle.phase) + float(particle.age), tint)


func _draw_burning_edges() -> void:
	var edges := _edge_points()
	if edges.size() < 6:
		return
	var world_scale := wings.global_transform.x.length()
	var ignition := exp(-flap_age * 6.0)
	for index in range(6):
		var edge_index := clampi(int((float(index) + 0.5) / 6.0 * edges.size()), 0, edges.size() - 1)
		var point := _wing_point(edges[edge_index])
		var outward := signf(point.x - wings.global_position.x)
		var flicker := 0.5 + 0.5 * sin(clock * 5.0 + index * 2.4)
		var length := (2.2 + flicker * 1.8 + ignition * 6.0 + (1.0 if moving else 0.0)) * world_scale
		var lean := outward * (0.45 + 0.18 * sin(clock * 3.7 + index))
		_draw_sprite(GLOW_TEXTURE, point, Vector2.ONE * (6.0 + ignition * 5.0) * world_scale, 0.0, Color(1.0, 0.55, 0.2, 0.16 + ignition * 0.12))
		_draw_flame(point, length, lean, 0.45 + flicker * 0.16 + ignition * 0.20)


func _draw_flame(base: Vector2, length: float, lean: float, alpha: float) -> void:
	var direction := Vector2(lean, -1.0).normalized()
	_draw_sprite(FLAME_TEXTURE, base + direction * length * 0.45, Vector2(length * 0.60, length), direction.angle() + PI * 0.5, Color(1.0, 1.0, 1.0, alpha))


func _draw_sprite(texture: Texture2D, world_point: Vector2, world_size: Vector2, angle: float, tint: Color) -> void:
	var point := to_local(world_point)
	# Preserve both world axes so a mirrored FX socket cannot invert the flames.
	var axis_x := to_local(world_point + Vector2.from_angle(angle)) - point
	var axis_y := to_local(world_point + Vector2.from_angle(angle + PI * 0.5)) - point
	draw_set_transform_matrix(Transform2D(axis_x, axis_y, point))
	draw_texture_rect(texture, Rect2(-world_size * 0.5, world_size), false, tint)
	draw_set_transform(Vector2.ZERO)
