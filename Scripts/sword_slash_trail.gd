extends Node2D
## Weapon-specific blade afterimages, sampled after the rendered animation.
## Local and remote equipment use the same effect; no gameplay events are sent.

const TRAIL_LIFETIME := 0.105
const SAMPLE_RATE := 240.0
const MAX_SAMPLES := 32
const MAX_PARTICLES := 64
# Coordinates are measured in each centered 64x64 equipped atlas frame.
const STYLES := {
	"blue_saber": {"base": Vector2(-14, -1), "tip": Vector2(17, -1), "colors": [Color("0a4dff"), Color("0badff"), Color("33f5ff"), Color("d1ffff")], "particles": "", "rate": 0.0},
	"red_saber": {"base": Vector2(-14, -1), "tip": Vector2(17, -1), "colors": [Color("af0628"), Color("ff201d"), Color("ff7153"), Color("fff0da")], "particles": "", "rate": 0.0},
	"green_saber": {"base": Vector2(-14, -1), "tip": Vector2(17, -1), "colors": [Color("118c25"), Color("3ef51a"), Color("9dff4c"), Color("ecffce")], "particles": "", "rate": 0.0},
	"void_saber": {"base": Vector2(-14, -1), "tip": Vector2(20, -1), "colors": [Color("401286"), Color("903fe0"), Color("db85ff"), Color("f9dfff")], "particles": "void_ember", "rate": 90.0},
	"phoenix_sword": {"base": Vector2(-10, -1), "tip": Vector2(27, -1), "colors": [Color("ca2510"), Color("ff5c0b"), Color("ffb82e"), Color("fff2a6")], "particles": "flame", "rate": 100.0},
	"angelic_sword": {"base": Vector2(-7, -1), "tip": Vector2(28, -1), "colors": [Color("baccea"), Color("e0eaff"), Color("f7f7ef"), Color.WHITE], "particles": "sparkle", "rate": 90.0},
	"sakura_sword": {"base": Vector2(-14, -1), "tip": Vector2(15, -1), "colors": [Color("773ad1"), Color("c361e4"), Color("ffa5de"), Color("ffe8f6")], "particles": "flower", "rate": 34.0},
	"void_trident": {"base": Vector2(-4, -1), "tip": Vector2(28, -1), "colors": [Color("250c48"), Color("7623ce"), Color("ce52ff"), Color("edd4ff")], "particles": "void", "rate": 72.0},
	"blood_battleaxe": {"base": Vector2(-8, -1), "tip": Vector2(8, -1), "colors": [Color("490c20"), Color("b60b31"), Color("f3314e"), Color("ffb9b5")], "particles": "crimson", "rate": 72.0},
	"serpent_staff": {"base": Vector2(-10, -2), "tip": Vector2(9, -2), "colors": [Color("124a36"), Color("158947"), Color("8cd952"), Color("e8ffa1")], "particles": "venom", "rate": 56.0}
}
const SHOULDER_PIVOT := Vector2(-6.0, 2.0)
const BASE_TURN_SPEED := 1.0 / 0.30
const MAX_TURN_SPEED := 1.0 / 0.16

var blade: AnimatedSprite2D
var swing_animation: AnimationPlayer
var samples: Array[Dictionary] = []
var previous_base := Vector2.ZERO
var previous_tip := Vector2.ZERO
var previous_pivot := Vector2.ZERO
var previous_strength := 0.0
var previous_facing := 0.0
var sampling := false
var swing_active := false
var swing_phase := 0.0
var swing_end_phase := 1.0
var turn_speed := 0.0
var desired_turn_speed := BASE_TURN_SPEED
var clock := 0.0
var last_request_time := -10.0
var releasing := false
var release_age := 0.0
var release_duration := 0.0
var release_phase := 0.0
var release_speed := 0.0
var owns_pose := false
var hand_socket: Node2D
var right_arm: Node2D
var weapon_id := "blue_saber"
var blade_base := Vector2.ZERO
var blade_tip := Vector2.ZERO
var palette: Array = []
var particle_kind := ""
var particle_rate := 0.0
var particle_credit := 0.0
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var void_aura_front: Node2D


static func supports_weapon(item_id: String) -> bool:
	return STYLES.has(item_id)


func _ready() -> void:
	# AnimationPlayer and equipment poses must have settled before sampling.
	process_priority = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()


func setup(sprite: AnimatedSprite2D, animation_player: AnimationPlayer, item_id: String = "blue_saber") -> void:
	weapon_id = item_id
	var style: Dictionary = STYLES[item_id]
	blade_base = style.base
	blade_tip = style.tip
	palette = style.colors
	particle_kind = style.particles
	particle_rate = style.rate
	blade = sprite
	swing_animation = animation_player
	hand_socket = blade.get_parent() as Node2D
	right_arm = hand_socket.get_parent().get_node_or_null("RightArm") as Node2D
	if particle_kind == "void" and not is_instance_valid(void_aura_front):
		# Split the orbit around the actual sprite so motes pass behind and in front.
		void_aura_front = Node2D.new()
		void_aura_front.name = "VoidAuraFront"
		void_aura_front.z_index = 2 + blade.z_index
		add_child(void_aura_front)
		void_aura_front.draw.connect(_draw_void_aura.bind(true, void_aura_front))
	clear()


func request_swing() -> void:
	# Local playback and the shared pose manager may see the same action in one
	# frame. Coalesce that delivery without creating a queue of future swings.
	if clock - last_request_time < 0.035:
		return
	if swing_active:
		desired_turn_speed = clampf(1.0 / maxf(clock - last_request_time, 0.16), BASE_TURN_SPEED, MAX_TURN_SPEED)
		# Keep the current phase, including when a click arrives during release.
		swing_end_phase = maxf(swing_end_phase, ceil(swing_phase + 0.55))
	else:
		swing_phase = 0.0
		swing_end_phase = 1.0
		turn_speed = 0.0
		desired_turn_speed = BASE_TURN_SPEED
		swing_active = true
		owns_pose = true
	releasing = false
	last_request_time = clock


func _advance_swing(delta: float) -> void:
	var remaining_time := delta
	while swing_active and remaining_time > 0.00001:
		var step := minf(remaining_time, 1.0 / SAMPLE_RATE)
		remaining_time -= step
		if releasing:
			release_age = minf(release_age + step, release_duration)
			var t := release_age / release_duration
			swing_phase = swing_end_phase - (swing_end_phase - release_phase) * pow(1.0 - t, 2.0)
			turn_speed = release_speed * (1.0 - t)
			if t >= 1.0:
				swing_active = false
		else:
			turn_speed = move_toward(turn_speed, desired_turn_speed, 65.0 * step)
			swing_phase += turn_speed * step
			var remaining_phase := swing_end_phase - swing_phase
			if remaining_phase <= maxf(0.18, turn_speed * 0.04):
				releasing = true
				release_phase = swing_phase
				release_speed = turn_speed
				release_age = 0.0
				release_duration = maxf(0.01, 2.0 * remaining_phase / turn_speed)
	if owns_pose:
		# A single, fixed shoulder pivot makes both the blade and hand travel in
		# an actual circle. Repeated AnimationPlayer restarts cannot rewind it.
		var angle := fposmod(swing_phase, 1.0) * TAU
		var socket_position := SHOULDER_PIVOT - SHOULDER_PIVOT.rotated(angle)
		hand_socket.rotation = angle
		hand_socket.position = socket_position
		if is_instance_valid(right_arm):
			right_arm.rotation = angle
			right_arm.position = socket_position
		if not swing_active and swing_animation.current_animation != &"punch_sword":
			owns_pose = false


func clear() -> void:
	samples.clear()
	particles.clear()
	particle_credit = 0.0
	sampling = false
	queue_redraw()
	if is_instance_valid(void_aura_front):
		void_aura_front.queue_redraw()


func _process(delta: float) -> void:
	clock += delta
	if not is_instance_valid(blade) or not is_instance_valid(swing_animation):
		swing_active = false
		owns_pose = false
		clear()
		return
	if not blade.is_visible_in_tree() or not is_visible_in_tree():
		swing_active = false
		owns_pose = false
		clear()
		return
	# Damage, death and placement can interrupt the cosmetic follow-through.
	if swing_animation.current_animation in [&"hurt", &"dead", &"dead_spirit", &"place_animation"]:
		swing_active = false
		owns_pose = false
	var was_swing_active := swing_active
	_advance_swing(delta)

	for sample in samples:
		sample.age += delta
	while not samples.is_empty() and float(samples[0].age) >= TRAIL_LIFETIME:
		samples.pop_front()

	var facing := signf(blade.global_transform.determinant())
	if blade.flip_h:
		facing *= -1.0
	if blade.flip_v:
		facing *= -1.0
	if facing != previous_facing or delta > 0.12:
		clear()
	previous_facing = facing
	_update_particles(delta)

	# Include the final, zero-intensity endpoint instead of clipping off the
	# final fraction of the circle when the settling animation completes.
	var striking := swing_active or was_swing_active
	if striking:
		var base := _blade_point(blade_base)
		var tip := _blade_point(blade_tip)
		var pivot: Vector2 = hand_socket.get_parent().to_global(SHOULDER_PIVOT)
		# Taper emission with angular speed so the final edge closes softly.
		var strength := smoothstep(0.0, desired_turn_speed * 0.8, turn_speed)
		var blade_length := base.distance_to(tip)
		# Never connect a teleport, respawn, or large correction with a light streak.
		if sampling and base.distance_to(previous_base) > blade_length * 2.0:
			clear()
		if sampling:
			var old_direction := previous_tip - previous_pivot
			var direction := tip - pivot
			var swept_angle := angle_difference(old_direction.angle(), direction.angle())
			if swept_angle * facing < -0.00001:
				swept_angle += TAU * facing
			var steps := clampi(int(ceil(delta * SAMPLE_RATE)), 1, 24)
			for step in range(1, steps + 1):
				var weight := float(step) / float(steps)
				var sample_pivot := previous_pivot.lerp(pivot, weight)
				var angle_step := swept_angle * weight
				var sample_base := sample_pivot + (previous_base - previous_pivot).rotated(angle_step)
				var sample_tip := sample_pivot + old_direction.rotated(angle_step)
				if step == steps:
					sample_base = base
					sample_tip = tip
				_append_sample(sample_base, sample_tip, delta * (1.0 - weight), lerpf(previous_strength, strength, weight))
		else:
			_append_sample(base, tip, 0.0, strength)
		previous_base = base
		previous_tip = tip
		previous_pivot = pivot
		previous_strength = strength
		sampling = true
		_emit_particles(delta, strength, facing)
	else:
		sampling = false
	queue_redraw()
	if is_instance_valid(void_aura_front):
		void_aura_front.queue_redraw()


func _blade_point(point: Vector2) -> Vector2:
	point += blade.offset
	if not blade.centered:
		point += Vector2(32.0, 32.0)
	if blade.flip_h:
		point.x = -point.x
	if blade.flip_v:
		point.y = -point.y
	return blade.to_global(point)


func _append_sample(base: Vector2, tip: Vector2, age: float, strength: float) -> void:
	if age >= TRAIL_LIFETIME:
		return
	samples.append({"base": base, "tip": tip, "age": age, "strength": strength})
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()


func _draw() -> void:
	if particle_kind == "void" and is_instance_valid(blade) and blade.is_visible_in_tree():
		_draw_void_aura(false, self)
	for i in range(1, samples.size()):
		var older := samples[i - 1]
		var newer := samples[i]
		var base_a := to_local(older.base)
		var base_b := to_local(newer.base)
		var tip_a := to_local(older.tip)
		var tip_b := to_local(newer.tip)
		if tip_a.distance_squared_to(tip_b) < 0.0001:
			continue
		var fade_a := pow(1.0 - clampf(float(older.age) / TRAIL_LIFETIME, 0.0, 1.0), 1.7) * float(older.strength)
		var fade_b := pow(1.0 - clampf(float(newer.age) / TRAIL_LIFETIME, 0.0, 1.0), 1.7) * float(newer.strength)
		if particle_kind == "venom":
			fade_a *= 0.60
			fade_b *= 0.60
		# Transparent at the grip; strongest near the blade's outer edge.
		_draw_band(base_a, tip_a, base_b, tip_b, 0.12, 1.10, palette[0], fade_a * 0.20, fade_b * 0.20)
		_draw_band(base_a, tip_a, base_b, tip_b, 0.22, 1.0, palette[1], fade_a * 0.55, fade_b * 0.55)
		_draw_band(base_a, tip_a, base_b, tip_b, 0.64, 1.0, palette[2], fade_a * 0.60, fade_b * 0.60)
		var alpha := (fade_a + fade_b) * 0.5
		draw_line(tip_a, tip_b, Color(palette[1], alpha * 0.16), 5.0, false)
		draw_line(tip_a, tip_b, Color(palette[2], alpha * 0.60), 1.8, false)
		draw_line(tip_a, tip_b, Color(palette[3], alpha * 0.80), 0.7, false)
		if particle_kind == "void":
			# The two outer tines leave their own finer arcs around the main head.
			var normal_a := (tip_a - base_a).orthogonal() * (9.0 / 32.0)
			var normal_b := (tip_b - base_b).orthogonal() * (9.0 / 32.0)
			for side in [-1.0, 1.0]:
				var tine_a: Vector2 = tip_a + normal_a * side
				var tine_b: Vector2 = tip_b + normal_b * side
				draw_line(tine_a, tine_b, Color(palette[1], alpha * 0.22), 3.0, false)
				draw_line(tine_a, tine_b, Color(palette[2], alpha * 0.65), 0.8, false)
	_draw_particles()


func _draw_band(base_a: Vector2, tip_a: Vector2, base_b: Vector2, tip_b: Vector2, inner: float, outer: float, color: Color, alpha_a: float, alpha_b: float) -> void:
	var points := PackedVector2Array([
		base_a.lerp(tip_a, inner), base_a.lerp(tip_a, outer),
		base_b.lerp(tip_b, outer), base_b.lerp(tip_b, inner)
	])
	var colors := PackedColorArray([
		Color(color, 0.0), Color(color, alpha_a),
		Color(color, alpha_b), Color(color, 0.0)
	])
	# Explicit triangles avoid polygon triangulation failures during pose changes.
	draw_polygon(PackedVector2Array([points[0], points[1], points[2]]), PackedColorArray([colors[0], colors[1], colors[2]]))
	draw_polygon(PackedVector2Array([points[0], points[2], points[3]]), PackedColorArray([colors[0], colors[2], colors[3]]))


func _emit_particles(delta: float, strength: float, facing: float) -> void:
	if particle_rate <= 0.0 or samples.is_empty():
		return
	particle_credit += delta * particle_rate * strength
	var world_scale := blade.global_transform.x.length()
	while particle_credit >= 1.0:
		particle_credit -= 1.0
		if particles.size() >= MAX_PARTICLES:
			break
		var sample: Dictionary = samples[rng.randi_range(0, samples.size() - 1)]
		var base: Vector2 = sample.base
		var tip: Vector2 = sample.tip
		var radial := (tip - base).normalized()
		var tangent := Vector2(-radial.y, radial.x) * facing
		var velocity := tangent * rng.randf_range(4.0, 14.0)
		var lifetime := rng.randf_range(0.24, 0.42)
		var size := rng.randf_range(1.5, 2.5)
		match particle_kind:
			"flame":
				velocity += Vector2(rng.randf_range(-5.0, 5.0), -rng.randf_range(14.0, 28.0))
			"sparkle":
				velocity += radial * rng.randf_range(2.0, 8.0) + Vector2(0, -5)
				size = rng.randf_range(0.8, 2.3)
			"flower":
				velocity = velocity * 0.5 + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(3.0, 9.0))
				lifetime = rng.randf_range(0.45, 0.70)
				size = rng.randf_range(1.6, 2.6)
			"void":
				velocity += radial * rng.randf_range(7.0, 18.0)
				lifetime = rng.randf_range(0.26, 0.48)
				size = rng.randf_range(0.7, 1.7)
			"void_ember":
				velocity = tangent * rng.randf_range(12.0, 26.0) + radial * rng.randf_range(3.0, 10.0)
				lifetime = rng.randf_range(0.30, 0.56)
				size = rng.randf_range(0.65, 1.45)
			"crimson":
				velocity = tangent * rng.randf_range(17.0, 34.0) + radial * rng.randf_range(4.0, 13.0)
				lifetime = rng.randf_range(0.24, 0.46)
				size = rng.randf_range(0.7, 1.4)
			"venom":
				velocity = tangent * rng.randf_range(8.0, 20.0) + radial * rng.randf_range(3.0, 10.0)
				lifetime = rng.randf_range(0.28, 0.53)
				size = rng.randf_range(0.8, 1.6)
		particles.append({
			"position": base.lerp(tip, rng.randf_range(0.48, 1.04)),
			"velocity": velocity * world_scale,
			"scale": world_scale,
			"age": 0.0, "lifetime": lifetime, "size": size,
			"rotation": rng.randf_range(-PI, PI),
			"spin": rng.randf_range(-4.0, 4.0),
			"accent": rng.randf(), "seed": rng.randf_range(0.0, TAU),
			"purple": rng.randf() < 0.45
		})


func _update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle.age += delta
		if particle.age >= particle.lifetime:
			particles.remove_at(index)
			continue
		if particle_kind == "flower":
			particle.velocity.y += 13.0 * float(particle.scale) * delta
			particle.position.x += sin(float(particle.age) * 10.0 + float(particle.seed)) * 7.0 * float(particle.scale) * delta
		elif particle_kind == "void":
			particle.velocity = particle.velocity.rotated(delta * 3.0) * exp(-delta * 3.5)
		elif particle_kind == "void_ember":
			particle.velocity = particle.velocity.rotated(delta * float(particle.spin) * 0.5) * exp(-delta * 3.0)
		elif particle_kind == "crimson":
			particle.velocity *= exp(-delta * 2.0)
			particle.velocity.y += 42.0 * float(particle.scale) * delta
		elif particle_kind == "venom":
			particle.velocity *= exp(-delta * 2.5)
			particle.velocity.y += (28.0 if float(particle.accent) < 0.65 else -16.0) * float(particle.scale) * delta
			particle.position.x += sin(float(particle.age) * 13.0 + float(particle.seed)) * 5.0 * float(particle.scale) * delta
		particle.position += particle.velocity * delta
		particle.rotation += float(particle.spin) * delta


func _draw_particles() -> void:
	for particle in particles:
		var t := float(particle.age) / float(particle.lifetime)
		var alpha := (1.0 - smoothstep(0.20, 1.0, t)) * smoothstep(0.0, 0.06, t)
		var point := to_local(particle.position)
		var size := float(particle.size)
		match particle_kind:
			"venom":
				var radius := size * (1.0 - t * 0.4)
				if float(particle.accent) < 0.65:
					var tail := to_local(particle.position - particle.velocity * 0.045)
					draw_line(tail, point, Color(0.20, 0.62, 0.23, alpha * 0.5), radius * 0.8, false)
					draw_circle(point, radius, Color(0.44, 0.81, 0.20, alpha * 0.8))
					draw_circle(point - Vector2.ONE * radius * 0.25, radius * 0.3, Color(0.91, 1.0, 0.61, alpha))
				else:
					draw_circle(point, radius, Color(0.15, 0.45, 0.27, alpha * 0.13))
					draw_arc(point, radius, 0.4, 5.5, 12, Color(0.48, 0.85, 0.36, alpha * 0.65), 0.5, false)
			"crimson":
				var color := Color("ffc0b8").lerp(Color("9e1437"), smoothstep(0.05, 0.95, t))
				var tail := to_local(particle.position - particle.velocity * 0.065)
				draw_line(tail, point, Color(0.7, 0.025, 0.12, alpha * 0.15), size * 2.8, false)
				if float(particle.accent) < 0.72:
					draw_line(tail, point, Color(color, alpha), size * (1.0 - t * 0.5), false)
				else:
					var axis := Vector2.from_angle(float(particle.rotation)) * size
					var side := axis.orthogonal() * 0.65
					draw_colored_polygon(PackedVector2Array([point - axis, point + side, point + axis, point - side]), Color(0.32, 0.02, 0.08, alpha))
					draw_line(point + side, point + axis, Color(color, alpha), 0.5, false)
			"flame":
				if float(particle.accent) < 0.25:
					draw_rect(Rect2(point, Vector2.ONE * 0.8), Color(1.0, 0.78, 0.25, alpha), true)
				else:
					_draw_flame(point, size * (1.0 - t * 0.5), float(particle.age), float(particle.seed), alpha)
			"sparkle":
				var twinkle := 0.5 + 0.5 * pow(sin(float(particle.age) * 18.0 + float(particle.seed)), 2.0)
				if float(particle.accent) < 0.62:
					draw_rect(Rect2(point - Vector2.ONE * 0.4, Vector2.ONE * 0.8), Color(1.0, 1.0, 1.0, alpha * twinkle), true)
				else:
					var star := PackedVector2Array()
					for vertex in range(8):
						var radius := size if vertex % 2 == 0 else size * 0.21
						star.append(point + Vector2.from_angle(vertex * PI / 4.0 + float(particle.rotation) * 0.15) * radius)
					draw_colored_polygon(star, Color(1.0, 1.0, 1.0, alpha * twinkle))
			"flower":
				_draw_flower(point, size, float(particle.rotation), float(particle.accent), bool(particle.purple), alpha)
			"void":
				var axis := Vector2.from_angle(float(particle.rotation)) * size * (1.0 - t * 0.6)
				var normal := axis.orthogonal() * 0.45
				draw_circle(point, size * 2.0, Color(0.47, 0.08, 1.0, alpha * 0.12))
				draw_colored_polygon(PackedVector2Array([point - axis, point + normal, point + axis, point - normal]), Color(0.75, 0.35, 1.0, alpha))
				draw_line(point, point + axis, Color(0.94, 0.77, 1.0, alpha * 0.8), 0.5, false)
			"void_ember":
				var cooling := smoothstep(0.1, 0.95, t)
				var color := Color("e8bfff").lerp(Color("69268f"), cooling)
				var tail := to_local(particle.position - particle.velocity * 0.10)
				draw_line(tail, point, Color(0.48, 0.09, 0.78, alpha * 0.20), size * 2.1, false)
				if float(particle.accent) < 0.65:
					draw_line(tail, point, Color(color, alpha * 0.8), maxf(0.4, size * (1.0 - t)), false)
					draw_rect(Rect2(point - Vector2.ONE * 0.3, Vector2.ONE * 0.6), Color(0.97, 0.84, 1.0, alpha * (1.0 - cooling)), true)
				else:
					var axis := Vector2.from_angle(float(particle.rotation)) * size * (1.0 - t * 0.4)
					var normal := axis.orthogonal() * 0.55
					var chip := PackedVector2Array([point - axis, point + normal, point + axis, point - normal])
					draw_colored_polygon(chip, Color(0.12, 0.025, 0.22, alpha * 0.85))
					draw_line(point + normal, point + axis, Color(0.67, 0.3, 0.94, alpha * 0.9), 0.5, false)


func _draw_void_aura(front: bool, canvas: Node2D) -> void:
	if particle_kind != "void" or not is_instance_valid(blade) or not is_instance_valid(swing_animation) or not blade.is_visible_in_tree():
		return
	if swing_animation.current_animation in [&"hurt", &"dead", &"dead_spirit", &"place_animation"]:
		return
	var pulse := 0.5 + 0.5 * sin(clock * 2.4)
	if not front:
		var center := to_local(_blade_point(Vector2(17, -1)))
		canvas.draw_circle(center, 10.0 + pulse * 0.6, Color(0.42, 0.05, 0.82, 0.055 + pulse * 0.02))
	# Three small comets cross two tilted paths. Each tail tapers to nothing;
	# the near side brightens while the far side is occluded by the trident.
	for mote in range(3):
		var orbit := 1 if mote == 2 else 0
		var direction := -1.0 if orbit == 1 else 1.0
		var phase := clock * (1.55 if orbit == 0 else -1.2) + mote * PI
		var tail_length := 1.65 if orbit == 0 else 1.35
		for step in range(1, 19):
			var progress := float(step) / 18.0
			var angle := phase - direction * tail_length * (1.0 - progress)
			var previous_angle := angle - direction * tail_length / 18.0
			var depth := sin((angle + previous_angle) * 0.5)
			if (depth >= 0.0) != front:
				continue
			var a := _void_orbit_point(previous_angle, orbit, pulse)
			var b := _void_orbit_point(angle, orbit, pulse)
			var alpha := pow(progress, 1.7) * (0.40 + 0.25 * depth)
			canvas.draw_line(a, b, Color(0.53, 0.1, 1.0, alpha * 0.18), 1.6 * progress + 0.25, false)
			canvas.draw_line(a, b, Color(0.79, 0.40, 1.0, alpha), 0.25 + progress * 0.45, false)
		var depth := sin(phase)
		if (depth >= 0.0) != front:
			continue
		var point := _void_orbit_point(phase, orbit, pulse)
		var tangent := (point - _void_orbit_point(phase - direction * 0.08, orbit, pulse)).normalized()
		var size := 0.65 + (depth + 1.0) * 0.18
		var alpha := 0.62 + depth * 0.25
		var axis := tangent * size * 1.4
		var normal := tangent.orthogonal() * size * 0.55
		canvas.draw_circle(point, size * 2.0, Color(0.63, 0.13, 1.0, alpha * 0.10))
		canvas.draw_colored_polygon(PackedVector2Array([point - axis, point + normal, point + axis, point - normal]), Color(0.93, 0.71, 1.0, alpha))
		canvas.draw_line(point - axis * 0.35, point + axis * 0.5, Color(1.0, 0.93, 1.0, alpha * 0.9), 0.45, false)


func _void_orbit_point(angle: float, orbit: int, pulse: float) -> Vector2:
	var radii := Vector2(10.5, 14.0) if orbit == 0 else Vector2(7.5, 15.0)
	var offset := Vector2(cos(angle), sin(angle)) * (radii + Vector2.ONE * pulse * 0.3)
	offset = offset.rotated(0.36 if orbit == 0 else -0.50)
	return to_local(_blade_point(Vector2(17, -1) + offset))


func _draw_flame(point: Vector2, size: float, age: float, seed_value: float, alpha: float) -> void:
	var sway := sin(age * 21.0 + seed_value) * size * 0.6
	var height := size * (2.9 + sin(age * 25.0 + seed_value) * 0.35)
	draw_circle(point + Vector2(0, -height * 0.25), size * 1.8, Color(1.0, 0.22, 0.02, alpha * 0.12))
	var flame := PackedVector2Array([
		point + Vector2(-size, 0), point + Vector2(-size * 0.75, -height * 0.45),
		point + Vector2(-size * 0.25, -height * 0.62), point + Vector2(sway, -height),
		point + Vector2(size * 0.76, -height * 0.46), point + Vector2(size, 0),
		point + Vector2(0, size * 0.3)
	])
	draw_colored_polygon(flame, Color(1.0, 0.33, 0.025, alpha * 0.88))
	var core := PackedVector2Array([
		point + Vector2(-size * 0.55, 0), point + Vector2(sway * 0.4, -height * 0.64),
		point + Vector2(size * 0.55, 0), point + Vector2(0, size * 0.15)
	])
	draw_colored_polygon(core, Color(1.0, 0.81, 0.20, alpha))
	draw_circle(point, size * 0.32, Color(1.0, 0.97, 0.72, alpha))


func _draw_flower(point: Vector2, size: float, angle: float, accent: float, purple: bool, alpha: float) -> void:
	var color := Color("cb91ff") if purple else Color("f3a0dc")
	color.a = alpha
	if accent < 0.42:
		# Five separated petal lobes keep blossoms readable at game resolution.
		for petal in range(5):
			var offset := Vector2.from_angle(angle + petal * TAU / 5.0) * size * 0.65
			draw_circle(point + offset, size * 0.44, color)
		draw_circle(point, size * 0.28, Color(1.0, 0.93, 0.77, alpha))
	else:
		var petal := PackedVector2Array()
		for vertex in [Vector2(-0.9, 0), Vector2(-0.2, -0.48), Vector2(0.65, -0.3), Vector2(1.0, 0), Vector2(0.2, 0.5)]:
			petal.append(point + (vertex * size).rotated(angle))
		draw_colored_polygon(petal, color)
		draw_line(point, point + Vector2(size * 0.6, 0).rotated(angle), Color(1.0, 0.88, 0.98, alpha * 0.55), 0.5, false)
