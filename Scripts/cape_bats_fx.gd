@tool
extends Node2D
## A dense bat swarm released by the accepted-jump hook.

@export var bat_color := Color(0.22, 0.06, 0.32)
const MAX_BATS := 96
const BURST_COUNT := 36

var wings: AnimatedSprite2D
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var moving := false
var anchor_cache: Dictionary = {}
var previous_origin := Vector2.ZERO
var tracking := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_priority = 90
	rng.randomize()
	set_process(false)


func bind_wings(sprite: AnimatedSprite2D) -> void:
	if wings == sprite:
		return
	wings = sprite
	anchor_cache.clear()
	clear()


func set_moving(value: bool) -> void:
	moving = value


func clear() -> void:
	particles.clear()
	tracking = false
	queue_redraw()
	set_process(false)


func _can_emit() -> bool:
	return is_instance_valid(wings) and wings.is_visible_in_tree() and is_visible_in_tree()


func _cape_tips() -> Array[Vector2]:
	if not is_instance_valid(wings) or wings.sprite_frames == null:
		return []
	var texture := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame)
	if texture == null:
		return []
	var key := texture.get_instance_id()
	if anchor_cache.has(key):
		return anchor_cache[key]
	var pixels := texture.get_image()
	if pixels == null:
		return []
	if pixels.is_compressed():
		pixels.decompress()
	var used := pixels.get_used_rect()
	var tips: Array[Vector2] = []
	var mid := float(used.position.x) + float(used.size.x) * 0.5
	for side in [-1.0, 1.0]:
		var best := Vector2.ZERO
		var best_score := -INF
		for x in range(used.position.x, used.end.x):
			if signf(float(x) - mid) != side:
				continue
			for y in range(used.end.y - 1, used.position.y + int(used.size.y * 0.55) - 1, -1):
				if pixels.get_pixel(x, y).a <= 0.5:
					continue
				var score := absf(float(x) - mid) * 0.65 + float(y - used.position.y) * 0.35
				if score > best_score:
					best_score = score
					best = Vector2(x + 0.5, y + 0.5)
				break
		if best_score > -INF:
			tips.append(best)
	anchor_cache[key] = tips
	return tips


func _cape_point(pixel: Vector2) -> Vector2:
	var texture := wings.sprite_frames.get_frame_texture(wings.animation, wings.frame)
	var point := pixel - (texture.get_size() * 0.5 if wings.centered else Vector2.ZERO) + wings.offset
	if wings.flip_h:
		point.x *= -1.0
	if wings.flip_v:
		point.y *= -1.0
	return wings.to_global(point)


func trigger_flap() -> void:
	if not _can_emit():
		return
	var tips := _cape_tips()
	if tips.size() < 2:
		return
	var world_scale := wings.global_transform.x.length()
	previous_origin = wings.global_position
	tracking = true
	for index in range(BURST_COUNT):
		var origin := _cape_point(tips[index % 2])
		var side := signf(origin.x - wings.global_position.x)
		if is_zero_approx(side):
			side = -1.0 if index % 2 == 0 else 1.0
		var spread := float(index / 2) / float(BURST_COUNT / 2 - 1)
		var swooper := index < 6
		var angle := lerpf(deg_to_rad(-100.0), deg_to_rad(32.0), spread) + rng.randf_range(-0.12, 0.12)
		if swooper:
			angle = deg_to_rad(-65.0 + float(index / 2) * 43.0) + rng.randf_range(-0.08, 0.08)
		var direction := Vector2(cos(angle) * side, sin(angle))
		var hero := index % 6 < 2
		origin += Vector2(side * rng.randf_range(-1.0, 3.0), rng.randf_range(-3.0, 2.0)) * world_scale
		if swooper:
			origin.y -= 5.0 * world_scale
		particles.append({
			"origin": origin,
			"velocity": direction * rng.randf_range(56.0, 94.0) * world_scale,
			"kick": direction * rng.randf_range(24.0, 35.0) * world_scale,
			"age": 0.0, "delay": rng.randf_range(0.0, 0.023),
			"lifetime": rng.randf_range(0.50, 0.68) if swooper else rng.randf_range(0.85, 1.20),
			"size": (rng.randf_range(1.58, 2.04) if swooper else (rng.randf_range(0.82, 1.12) if hero else rng.randf_range(0.55, 0.82))) * world_scale,
			"opacity": 1.0 if swooper else (rng.randf_range(0.90, 1.0) if hero else rng.randf_range(0.78, 0.96)),
			"swooper": swooper,
			"phase": rng.randf_range(0, TAU), "flap_hz": rng.randf_range(6.8, 8.6),
			"side": side, "bank": side * rng.randf_range(0.08, 0.24),
			"world_scale": world_scale
		})
	while particles.size() > MAX_BATS:
		particles.pop_front()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _can_emit():
		clear()
		return
	var origin := wings.global_position
	if tracking and origin.distance_to(previous_origin) > 128.0 * wings.global_transform.x.length():
		clear()
		return
	previous_origin = origin
	tracking = true
	for index in range(particles.size() - 1, -1, -1):
		particles[index].age += delta
		if float(particles[index].age) >= float(particles[index].lifetime):
			particles.remove_at(index)
	queue_redraw()
	if particles.is_empty():
		set_process(false)


func bat_position(bat: Dictionary) -> Vector2:
	var age := maxf(0.0, float(bat.age) - float(bat.delay))
	var drift := (1.0 - exp(-2.4 * age)) / 2.4
	var blast: Vector2 = bat.kick * (1.0 - exp(-20.0 * age))
	var curl := Vector2(float(bat.side) * (sin(age * 5.0 + float(bat.phase)) - sin(float(bat.phase))) * age * 3.0, -8.0 * age * age) * float(bat.world_scale)
	return bat.origin + blast + bat.velocity * drift + curl


func _wing_outline(side: float, flap: float) -> PackedVector2Array:
	var shoulder := -0.8 - flap * 1.1
	var wrist := -0.5 - flap * 1.6
	var tip := -1.0 - flap * 2.4
	var span := 0.83 + flap * 0.12
	var points := PackedVector2Array([
		Vector2(0.65, -0.65), Vector2(2.0, shoulder), Vector2(4.0, wrist),
		Vector2(6.2, tip), Vector2(5.3, tip + 2.1), Vector2(4.5, wrist + 0.9),
		Vector2(3.6, wrist + 2.7), Vector2(2.7, shoulder + 1.9), Vector2(0.8, 1.2)
	])
	for index in range(points.size()):
		points[index].x *= side * span
		points[index] = points[index].snapped(Vector2.ONE * 0.25)
	return points


func _draw() -> void:
	var inherited_scale := maxf(0.001, global_transform.x.length())
	for bat in particles:
		var age := float(bat.age) - float(bat.delay)
		if age < 0.0:
			continue
		var t := float(bat.age) / float(bat.lifetime)
		var alpha := smoothstep(0.0, 0.012, age) * (1.0 - smoothstep(0.48 if bat.swooper else 0.62, 1.0, t)) * float(bat.opacity)
		var flap := sin(age * TAU * float(bat.flap_hz) + float(bat.phase))
		var bank := float(bat.bank) + sin(age * 4.0 + float(bat.phase)) * 0.12
		var pop := lerpf(0.55, 1.40 if bat.swooper else 1.08, 1.0 - pow(1.0 - clampf(age / 0.075, 0.0, 1.0), 3.0))
		var size := float(bat.size) / inherited_scale * pop * lerpf(1.0, 0.50 if bat.swooper else 0.72, smoothstep(0.40 if bat.swooper else 0.62, 1.0, t))
		var point := to_local(bat_position(bat)).snapped(Vector2.ONE * 0.25)
		draw_set_transform(point, bank, Vector2.ONE * size)
		var outline := Color(bat_color.darkened(0.65), alpha)
		var wing_color := bat_color.darkened(0.10) if bat_color.r > 0.8 else bat_color.lightened(0.15)
		var membrane := Color(wing_color, alpha)
		var shaded := Color(wing_color.darkened(0.30), alpha)
		var highlight := Color(wing_color.lightened(0.28), alpha * 0.8)
		for side in [-1.0, 1.0]:
			var wing := _wing_outline(side, flap)
			draw_colored_polygon(wing, outline)
			var inner := PackedVector2Array()
			for vertex in wing:
				inner.append(vertex.lerp(Vector2(side * 1.3, 0.0), 0.16))
			draw_colored_polygon(inner, membrane)
			draw_colored_polygon(PackedVector2Array([inner[0], inner[2], inner[6], inner[7]]), shaded)
			draw_line(inner[1], inner[2], highlight, 0.40, false)
			draw_line(inner[2], inner[3], highlight, 0.40, false)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-1.15, -1.2), Vector2(-1.1, -2.0), Vector2(-0.55, -2.7),
			Vector2(0, -1.8), Vector2(0.55, -2.7), Vector2(1.1, -2.0),
			Vector2(1.15, -1.2), Vector2(1.15, 0.4), Vector2(0.55, 1.6),
			Vector2(0, 2.0), Vector2(-0.55, 1.6), Vector2(-1.15, 0.4)
		]), outline)
		draw_rect(Rect2(-0.35, -0.7, 0.7, 1.7), Color(bat_color.lightened(0.12), alpha * 0.7))
		var eye := Color(1.0, 0.70, 0.74, alpha) if bat_color.r > 0.8 else Color(1.0, 0.22, 0.38, alpha)
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(side * 0.58 - 0.22, -1.25), Vector2(0.44, 0.5)), eye)
	draw_set_transform(Vector2.ZERO)
