extends "res://Scripts/item_throw_fx.gd"
## Blood Battleaxe's cosmetic throw, with a fading wake and double-edged cleave.

const WAKE_TIME := 0.12
const SPARK_COUNT := 28
var sparks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var cleave_angle := -0.48


func _init() -> void:
	travel_speed = 360.0
	spins_per_second = 5.5
	arc_height = 12.0
	impact_radius = 33.0
	rng.randomize()


func launch_to(start: Vector2, target: Vector2, facing: int = 1) -> void:
	super.launch_to(start, target, facing)
	# Keep the endpoint correct even under a scaled preview/world parent.
	_destination = to_local(target)
	_duration = clampf(_destination.length() / maxf(travel_speed, 1.0), 0.17, 0.42)
	cleave_angle = -0.48 + rng.randf_range(-0.12, 0.12)
	sparks.clear()
	for index in range(SPARK_COUNT):
		var angle := rng.randf_range(-PI, PI)
		# Most fragments follow the two edges; a few fly across the cut.
		if index % 3 != 0:
			angle = cleave_angle + PI * 0.5 + (PI if index % 2 == 0 else 0.0) + rng.randf_range(-0.65, 0.65)
		sparks.append({
			"direction": Vector2.from_angle(angle),
			"speed": rng.randf_range(42.0, 115.0),
			"delay": rng.randf_range(0.0, 0.025),
			"lifetime": rng.randf_range(0.26, 0.51),
			"size": rng.randf_range(0.65, 1.6),
			"spin": rng.randf_range(-6.0, 6.0),
			"chip": index % 4 == 0
		})


func _draw() -> void:
	if not _launched or item_texture == null:
		return
	_draw_flight_wake()
	if _elapsed < _duration:
		var draw_size := item_texture.get_size() * miniature_size / maxf(item_texture.get_width(), item_texture.get_height())
		for ghost in range(3, 0, -1):
			var time := _elapsed - float(ghost) * 0.024
			if time < 0.0:
				continue
			draw_set_transform(_flight_position(time), time * TAU * spins_per_second * _facing)
			draw_texture_rect(item_texture, Rect2(-draw_size * 0.5, draw_size), false, Color(1.0, 0.12, 0.23, 0.19 / float(ghost)))
		draw_set_transform(_flight_position(_elapsed), _elapsed * TAU * spins_per_second * _facing)
		draw_texture_rect(item_texture, Rect2(-draw_size * 0.5, draw_size), false)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_impact(clampf((_elapsed - _duration) / FADE_TIME, 0.0, 1.0))


func _draw_flight_wake() -> void:
	# Sample actual flight times so the tail drains into the hit instead of vanishing.
	var finish := minf(_elapsed, _duration)
	var begin := maxf(0.0, _elapsed - WAKE_TIME)
	if begin >= finish:
		return
	for edge in [-1.0, 1.0]:
		for step in range(1, 25):
			var time_a := lerpf(begin, finish, float(step - 1) / 24.0)
			var time_b := lerpf(begin, finish, float(step) / 24.0)
			var a := _wake_point(time_a, edge)
			var b := _wake_point(time_b, edge)
			var alpha := pow(clampf(1.0 - (_elapsed - time_a) / WAKE_TIME, 0.0, 1.0), 1.8)
			draw_line(a, b, Color(0.52, 0.015, 0.09, alpha * 0.18), 5.0, false)
			draw_line(a, b, Color(0.94, 0.035, 0.16, alpha * 0.62), 2.1, false)
			draw_line(a, b, Color(1.0, 0.52, 0.59, alpha * 0.65), 0.65, false)


func _wake_point(time: float, edge: float) -> Vector2:
	return _flight_position(time) + Vector2.from_angle(time * TAU * spins_per_second * _facing) * miniature_size * 0.31 * edge


func _draw_impact(progress: float) -> void:
	if progress >= 1.0:
		return
	draw_set_transform(_destination, 0.0, Vector2(_facing, 1.0))
	var age := progress * FADE_TIME
	# A broad leading blade and a smaller opposing edge echo the double axe head.
	_draw_cleave(age, cleave_angle, 1.0)
	if age > 0.025:
		_draw_cleave(age - 0.025, cleave_angle + PI, 0.62)
	var flash := 1.0 - smoothstep(0.0, 0.12, age)
	if flash > 0.0:
		var axis := Vector2.from_angle(cleave_angle + PI * 0.5)
		var side := axis.orthogonal()
		var length := 6.0 + 12.0 * flash
		draw_colored_polygon(PackedVector2Array([-axis * length, side * 5.0 * flash, axis * length, -side * 5.0 * flash]), Color(1.0, 0.22, 0.32, flash))
		draw_colored_polygon(PackedVector2Array([-axis * length * 0.75, side * 2.0 * flash, axis * length * 0.75, -side * 2.0 * flash]), Color(1.0, 0.9, 0.87, flash))
	for spark in sparks:
		var time := age - float(spark.delay)
		if time <= 0.0 or time >= float(spark.lifetime):
			continue
		var t := time / float(spark.lifetime)
		var alpha := 1.0 - smoothstep(0.18, 1.0, t)
		var point := _spark_position(spark, time)
		var tail := _spark_position(spark, maxf(0.0, time - 0.028))
		var size := float(spark.size) * (1.0 - t * 0.45)
		if bool(spark.chip):
			var axis: Vector2 = spark.direction.rotated(time * float(spark.spin)) * size * 1.7
			var side := axis.orthogonal() * 0.55
			draw_colored_polygon(PackedVector2Array([point - axis, point + side, point + axis, point - side]), Color(0.27, 0.025, 0.06, alpha))
			draw_line(point + side, point + axis, Color(0.93, 0.10, 0.22, alpha), 0.7, false)
		else:
			var color := Color("ffc1bf").lerp(Color("a9133a"), smoothstep(0.05, 0.95, t))
			draw_line(tail, point, Color(0.85, 0.035, 0.13, alpha * 0.16), size * 3.0, false)
			draw_line(tail, point, Color(color, alpha), size, false)
			draw_rect(Rect2(point - Vector2.ONE * size * 0.35, Vector2.ONE * size * 0.7), Color(1.0, 0.76, 0.73, alpha * (1.0 - t)), true)
	draw_set_transform(Vector2.ZERO)


func _spark_position(spark: Dictionary, time: float) -> Vector2:
	return spark.direction * (2.0 + float(spark.speed) * (1.0 - exp(-time * 2.2)) / 2.2) + Vector2(0.0, 42.0 * time * time)


func _draw_cleave(age: float, angle: float, size: float) -> void:
	var t := age / 0.29
	if t >= 1.0:
		return
	var fade := 1.0 - smoothstep(0.18, 1.0, t)
	var reveal := 1.0 - pow(1.0 - clampf(age / 0.065, 0.0, 1.0), 2.0)
	var radius := impact_radius * size * (0.82 + 0.22 * (1.0 - pow(1.0 - t, 3.0)))
	var center := Vector2(-radius * 0.87, 0.0).rotated(angle)
	for step in range(24):
		var u := float(step) / 24.0 * reveal
		var v := float(step + 1) / 24.0 * reveal
		var normal_a := Vector2.from_angle(angle - 1.35 + u * 2.7)
		var normal_b := Vector2.from_angle(angle - 1.35 + v * 2.7)
		var a := center + normal_a * radius
		var b := center + normal_b * radius
		var thickness_a := sin(u * PI) * 10.5 * size * fade
		var thickness_b := sin(v * PI) * 10.5 * size * fade
		# Explicit strips remain stable as the crescent tapers to zero.
		var inside_a := a - normal_a * thickness_a
		var inside_b := b - normal_b * thickness_b
		draw_polygon(PackedVector2Array([inside_a, a, b]), PackedColorArray([Color(0.26, 0.01, 0.055, 0.0), Color(0.87, 0.025, 0.12, fade * 0.85), Color(0.87, 0.025, 0.12, fade * 0.85)]))
		draw_polygon(PackedVector2Array([inside_a, b, inside_b]), PackedColorArray([Color(0.26, 0.01, 0.055, 0.0), Color(0.87, 0.025, 0.12, fade * 0.85), Color(0.26, 0.01, 0.055, 0.0)]))
		var edge_alpha := sin((u + v) * PI * 0.5) * fade
		draw_line(a, b, Color(1.0, 0.16, 0.29, edge_alpha * 0.28), 3.7 * size, false)
		draw_line(a, b, Color(1.0, 0.65, 0.67, edge_alpha * 0.88), 0.8 * size, false)
