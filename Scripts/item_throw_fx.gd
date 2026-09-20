extends Node2D
## Cosmetic, reusable miniature item throw. No collision or damage authority.

@export var item_texture: Texture2D
@export var impact_color := Color(0.95, 0.08, 0.16)
@export var miniature_size: float = 22.0
@export var travel_speed: float = 170.0
@export var spins_per_second: float = 11.0
@export var arc_height: float = 14.0
@export var impact_radius: float = 38.0

const FADE_TIME := 0.56

var _destination := Vector2.ZERO
var _duration := 0.2
var _elapsed := 0.0
var _facing := 1.0
var _launched := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20
	set_process(_launched)


func launch_to(start: Vector2, target: Vector2, facing: int = 1) -> void:
	global_position = start
	_destination = target - start
	_duration = clampf(_destination.length() / maxf(travel_speed, 1.0), 0.38, 0.95)
	_facing = -1.0 if facing < 0 else 1.0
	_elapsed = 0.0
	_launched = true
	set_process(true)
	queue_redraw()


func _flight_position(time: float) -> Vector2:
	var progress := clampf(time / _duration, 0.0, 1.0)
	return _destination * progress + Vector2(0.0, -sin(progress * PI) * arc_height)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration + FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if not _launched or item_texture == null:
		return
	if _elapsed < _duration:
		var texture_size := item_texture.get_size()
		var draw_size := texture_size * miniature_size / maxf(texture_size.x, texture_size.y)
		draw_set_transform(_flight_position(_elapsed), _elapsed * TAU * spins_per_second * _facing)
		draw_texture_rect(item_texture, Rect2(-draw_size * 0.5, draw_size), false)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_impact(clampf((_elapsed - _duration) / FADE_TIME, 0.0, 1.0))


func _draw_impact(progress: float) -> void:
	var fade := 1.0 - progress
	var expansion := 1.0 - pow(fade, 3.0)
	var hot_color := Color(1.0, 0.88, 0.73)
	# Three staggered, filled blade sweeps replace the thin target-like rings.
	for sweep in range(3):
		var phase := clampf((progress - float(sweep) * 0.045) / 0.65, 0.0, 1.0)
		if phase <= 0.0 or phase >= 1.0:
			continue
		var sweep_radius := impact_radius * (0.38 + 0.65 * sin(phase * PI * 0.5))
		var angle := float(sweep) * TAU / 3.0 + phase * 1.3 * _facing
		var opacity := (1.0 - phase) * 0.95
		_draw_crescent(sweep_radius + 2.0, angle, 10.0 * (1.0 - phase), Color(0.28, 0.015, 0.055, opacity))
		_draw_crescent(sweep_radius, angle, 7.0 * (1.0 - phase), Color(impact_color, opacity))
		_draw_crescent(sweep_radius - 1.0, angle + 0.12, 2.5 * (1.0 - phase), Color(hot_color, opacity * 0.9))
	# Jagged layered core: a fast pale flash collapses into a crimson bloom.
	var core_fade := maxf(0.0, 1.0 - progress / 0.48)
	if core_fade > 0.0:
		var core_radius := (9.0 + expansion * 19.0) * core_fade
		_draw_starburst(core_radius + 3.0, Color(0.3, 0.01, 0.04, core_fade))
		_draw_starburst(core_radius, Color(impact_color, core_fade))
		_draw_starburst(core_radius * 0.65, Color(hot_color, core_fade))
	# Uneven shard lengths, speeds and gravity avoid a uniform circular outline.
	for index in range(24):
		var direction := Vector2.RIGHT.rotated(float(index) * 2.39996)
		var reach := impact_radius * (0.45 + float((index * 7) % 11) * 0.075)
		var point := _destination + direction * (4.0 + expansion * reach)
		point.y += progress * progress * (8.0 + float(index % 4) * 5.0)
		var shard_fade := clampf((1.0 - progress - float(index % 4) * 0.045) * 1.5, 0.0, 1.0)
		var shard_color := impact_color.lerp(hot_color, float(index % 4) * 0.23)
		var side := direction.orthogonal() * (1.0 + float(index % 3) * 0.65) * fade
		var tip := point + direction * (2.0 + 6.0 * fade)
		var shard := PackedVector2Array([(point + side).round(), tip.round(), (point - side).round(), (point - direction * 2.0).round()])
		if shard_fade > 0.0:
			draw_colored_polygon(shard, Color(shard_color, shard_fade))
		if index % 3 == 0:
			var ember := point - direction * 5.0 + Vector2(0.0, progress * 7.0)
			draw_rect(Rect2(ember.round(), Vector2(2, 2)), Color(hot_color, shard_fade * 0.7))


func _draw_crescent(radius: float, angle: float, thickness: float, tint: Color) -> void:
	var points := PackedVector2Array()
	const SEGMENTS := 12
	const SWEEP := 1.6
	for segment in range(SEGMENTS + 1):
		var portion := float(segment) / float(SEGMENTS)
		var direction := Vector2.RIGHT.rotated(angle + portion * SWEEP)
		points.append(_destination + direction * radius)
	for segment in range(SEGMENTS, -1, -1):
		var portion := float(segment) / float(SEGMENTS)
		var direction := Vector2.RIGHT.rotated(angle + portion * SWEEP)
		var taper := sin(portion * PI)
		points.append(_destination + direction * (radius - maxf(0.05, thickness * taper)))
	draw_colored_polygon(points, tint)


func _draw_starburst(radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for point_index in range(16):
		var direction := Vector2.RIGHT.rotated(float(point_index) * TAU / 16.0 + 0.2)
		var length_factor := (1.0 if point_index % 4 == 0 else 0.72) if point_index % 2 == 0 else 0.3
		points.append(_destination + direction * radius * length_factor)
	draw_colored_polygon(points, tint)
