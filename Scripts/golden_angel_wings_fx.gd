extends Node2D
## Slow golden starfall, with a few drifting tip feathers on accepted jumps.
## Stars and soft dust use WingPurpleStardustParticlesFX's particle textures.
## Particles stay in world space so moving wings leave a natural, fading wake.

const STAR_TEXTURE := preload("res://Assets/effects/confetti_star.svg")
const DUST_TEXTURE := preload("res://Assets/effects/angel_wing_sparkle.svg")
const MAX_PARTICLES := 112
const IDLE_RATE := 18.0
const MOVING_RATE := 42.0

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
	# This hook runs for accepted jumps, not the looping wing animation.
	# Emit feathers in pairs so both tips shed the same small amount.
	for index in range(4):
		_emit_particle("feather", true)
	for index in range(10):
		_emit_particle("dust" if index % 4 == 0 else "star", true)
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
	# Sample the lower feather silhouette of each actual atlas pose, leaving the
	# empty center alone. This keeps every emitter attached during the upstroke.
	for x in range(1, pixels.get_width() - 1, 2):
		if absf(float(x) - pixels.get_width() * 0.5) < 8.0:
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
	# Alternate wings so a low idle emission rate still feels balanced.
	next_side *= -1.0
	var candidates: Array[Vector2] = []
	var width := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame).get_width()
	for edge in edges:
		if signf(float(edge.x) - width * 0.5) == next_side:
			candidates.append(edge)
	if candidates.is_empty():
		return
	var world_scale := wings.global_transform.x.length()
	var trailing := moving or burst
	if kind == "":
		kind = "star" if rng.randf() < (0.48 if trailing else 0.60) else "dust"
	var feather := kind == "feather"
	var star := kind == "star"
	var anchor := candidates[rng.randi_range(0, candidates.size() - 1)]
	if feather:
		# Silhouette points are ordered left to right. Use the outer tip of
		# the current pose; mirrored wings are handled by _wing_point().
		anchor = candidates[0] if next_side < 0.0 else candidates[-1]
	var point := _wing_point(anchor)
	# Longer lives and gentler drift keep the reference's stars and dust
	# readable without turning movement into a fast shower of sparks.
	var lifetime := (1.15 if star else 1.35) if trailing else (1.65 if star else 1.85)
	lifetime *= rng.randf_range(0.9, 1.1)
	var size := rng.randf_range(0.66, 2.04) if star else rng.randf_range(0.54, 1.8)
	if trailing:
		size *= 0.9
	var spread := deg_to_rad(28.0 if trailing else 20.0)
	var velocity := Vector2.DOWN.rotated(rng.randf_range(-spread, spread)) * rng.randf_range(5.0 if trailing else 3.0, 13.0 if trailing else 8.0) * world_scale
	velocity += actor_velocity * 0.025
	var gravity := 5.0 if trailing else 4.0
	var damping := rng.randf_range(1.2, 2.8)
	var rotation := rng.randf_range(-PI, PI)
	var spin := rng.randf_range(-2.2, 2.2) if trailing else rng.randf_range(-1.2, 1.2)
	if feather:
		lifetime = rng.randf_range(2.2, 2.7)
		size = rng.randf_range(1.5, 1.9)
		var outward := signf(point.x - wings.global_position.x)
		velocity = Vector2(outward * rng.randf_range(0.8, 1.8), rng.randf_range(2.0, 4.0)) * world_scale
		gravity = 1.8
		damping = 0.7
		rotation = rng.randf_range(-0.5, 0.5)
		spin = rng.randf_range(-0.2, 0.2)
	particles.append({
		"position": point, "velocity": velocity, "scale": world_scale,
		"kind": kind, "age": 0.0, "lifetime": lifetime, "size": size,
		"gravity": gravity, "damping": damping,
		"phase": rng.randf_range(0.0, TAU), "rotation": rotation,
		"spin": spin,
		"warmth": rng.randf()
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
		particle.velocity = particle.velocity.move_toward(Vector2.ZERO, float(particle.damping) * float(particle.scale) * delta)
		particle.velocity.y += float(particle.gravity) * float(particle.scale) * delta
		particle.position += particle.velocity * delta
		particle.rotation += float(particle.spin) * delta
		if particle.kind == "feather":
			particle.position.x += sin(float(particle.age) * 3.2 + float(particle.phase)) * 2.2 * float(particle.scale) * delta
	credit += delta * (MOVING_RATE if moving else IDLE_RATE)
	while credit >= 1.0:
		credit -= 1.0
		_emit_particle()
	queue_redraw()


func _draw() -> void:
	if not _can_emit():
		return
	_draw_edge_glints()
	for particle in particles:
		var t := float(particle.age) / float(particle.lifetime)
		var alpha := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.55, 1.0, t))
		var point: Vector2 = particle.position
		var size := float(particle.size) * float(particle.scale) * (1.0 - smoothstep(0.7, 1.0, t) * 0.25)
		var tint := Color("ffbd38").lerp(Color("fff1b0"), float(particle.warmth))
		if particle.kind == "feather":
			var flutter := sin(float(particle.age) * 3.2 + float(particle.phase)) * 0.3
			_draw_feather(point, size, float(particle.rotation) + flutter, alpha, tint)
		elif particle.kind == "star":
			_draw_particle_texture(STAR_TEXTURE, point, size, float(particle.rotation), Color(tint, alpha * 0.9))
		else:
			var twinkle := 0.7 + 0.3 * pow(sin(float(particle.age) * 4.0 + float(particle.phase)), 2.0)
			_draw_particle_texture(DUST_TEXTURE, point, size, float(particle.rotation), Color(tint, alpha * twinkle * 0.48))


func _draw_feather(world_point: Vector2, size: float, angle: float, alpha: float, tint: Color) -> void:
	var axis := Vector2(sin(angle), cos(angle)) * size * 1.7
	var side := axis.orthogonal() * 0.30
	var outline := PackedVector2Array([
		to_local(world_point - axis),
		to_local(world_point - axis * 0.4 + side),
		to_local(world_point + axis * 0.5 + side * 0.6),
		to_local(world_point + axis),
		to_local(world_point + axis * 0.35 - side * 0.75),
		to_local(world_point - axis * 0.55 - side * 0.8)
	])
	draw_colored_polygon(outline, Color(tint.lerp(Color("fff4d7"), 0.65), alpha * 0.75))
	var line_width := maxf(0.3, size * 0.18 / maxf(0.01, global_transform.x.length()))
	draw_line(to_local(world_point - axis * 0.8), to_local(world_point + axis * 1.15), Color(1.0, 0.96, 0.82, alpha * 0.9), line_width)
	for step in [-0.35, 0.05, 0.4]:
		var center := world_point + axis * float(step)
		draw_line(to_local(center - axis * 0.15 + side * 0.6), to_local(center), Color(1.0, 0.88, 0.55, alpha * 0.55), line_width * 0.7)


func _draw_particle_texture(texture: Texture2D, world_point: Vector2, world_radius: float, angle: float, tint: Color) -> void:
	var point := to_local(world_point)
	var axis := to_local(world_point + Vector2.from_angle(angle) * world_radius) - point
	draw_set_transform(point, axis.angle(), Vector2.ONE * axis.length())
	draw_texture_rect(texture, Rect2(-Vector2.ONE, Vector2.ONE * 2.0), false, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_glint(world_point: Vector2, size: float, alpha: float, tint: Color) -> void:
	_draw_particle_texture(DUST_TEXTURE, world_point, size, 0.0, Color(tint, alpha))


func _draw_edge_glints() -> void:
	var edges := _edge_points()
	if edges.size() < 4:
		return
	var world_scale := wings.global_transform.x.length()
	for index in range(4):
		var phase := fposmod(clock * 0.32 + index * 0.271, 1.0)
		var shine := pow(maxf(0.0, sin(phase * TAU)), 10.0)
		var pulse := exp(-flap_age * 7.0) * 0.5
		var edge_index := clampi(int((float(index) + 0.5) / 4.0 * edges.size()), 0, edges.size() - 1)
		_draw_glint(_wing_point(edges[edge_index]), (0.65 + shine * 0.65 + pulse) * world_scale, (shine * 0.65 + pulse) * 0.75, Color("fff3cc"))
