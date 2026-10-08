@tool
extends "res://Scripts/void_trident_hit_fx.gd"
## Share the bounded particle lifecycle; render a blade-shaped dimensional cut.


func _draw() -> void:
	if age >= LIFETIME:
		return
	_draw_shards()
	_draw_saber_rift()
	_draw_contact_flash()


func _cut_axis() -> Vector2:
	return Vector2(0.72 * facing, -0.694).normalized()


func _draw_contact_flash() -> void:
	var t := clampf(age / 0.085, 0.0, 1.0)
	if t >= 1.0:
		return
	var axis := _cut_axis()
	var normal := axis.orthogonal()
	var length := lerpf(10.0, 26.0, 1.0 - pow(1.0 - t, 3.0))
	var alpha := pow(1.0 - t, 1.3)
	draw_line(-axis * length, axis * length, Color(0.57, 0.08, 0.96, alpha * 0.18), 6.0, false)
	draw_colored_polygon(PackedVector2Array([
		-axis * length, normal * 1.3, axis * length, -normal * 1.3
	]), Color(0.96, 0.83, 1.0, alpha))
	draw_line(-normal * 5.0, normal * 5.0, Color(0.83, 0.46, 1.0, alpha * 0.7), 0.65, false)


func _draw_saber_rift() -> void:
	var t := clampf(age / 0.43, 0.0, 1.0)
	if t >= 1.0:
		return
	var opening := 1.0 - pow(1.0 - clampf(t / 0.24, 0.0, 1.0), 3.0)
	var closing := 1.0 - smoothstep(0.32, 1.0, t)
	var alpha := opening * (1.0 - smoothstep(0.55, 1.0, t))
	var length := 23.0 * opening * (0.55 + 0.45 * closing)
	var width := 4.2 * opening * closing
	if width <= 0.01 or alpha <= 0.01:
		return
	var axis := _cut_axis()
	var normal := axis.orthogonal()
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in range(25):
		var p := float(i) / 24.0
		var along := lerpf(-length, length, p)
		var envelope := pow(maxf(0.0, sin(p * PI)), 0.85)
		var jagged := 0.82 + 0.18 * sin(p * 35.0 + 1.3)
		var bend := sin(p * TAU) * 1.5 * closing
		upper.append(axis * along + normal * (bend + width * envelope * jagged))
		lower.append(axis * along + normal * (bend - width * envelope * jagged))
	var outline := upper.duplicate()
	for i in range(lower.size() - 2, 0, -1):
		outline.append(lower[i])
	draw_colored_polygon(outline, Color(0.025, 0.009, 0.065, alpha * 0.95))
	for edge in [upper, lower]:
		draw_polyline(edge, Color(0.45, 0.06, 0.78, alpha * 0.23), 3.0 * closing + 0.3, false)
		draw_polyline(edge, Color(0.78, 0.28, 1.0, alpha * 0.9), 0.9, false)
		draw_polyline(edge, Color(0.94, 0.68, 1.0, alpha * 0.55), 0.35, false)


func _shard_position(shard: Dictionary, t: float) -> Vector2:
	var spread := 1.0 - pow(1.0 - clampf(t / 0.26, 0.0, 1.0), 3.0)
	var inward := 1.0 - smoothstep(0.34, 1.0, t)
	var angle := float(shard.angle) + float(shard.spin) * t * 0.25 * facing
	var radius := float(shard.radius) * spread * inward
	var axis := _cut_axis()
	return axis * cos(angle) * radius * 0.85 + axis.orthogonal() * sin(angle) * radius * 0.62


func _draw_shards() -> void:
	for shard in shards:
		var t := (age - float(shard.delay)) / float(shard.lifetime)
		if t <= 0.0 or t >= 1.0:
			continue
		var alpha := smoothstep(0.0, 0.07, t) * (1.0 - smoothstep(0.50, 1.0, t))
		var point := _shard_position(shard, t)
		var tail := _shard_position(shard, maxf(0.0, t - 0.06))
		var size := float(shard.size) * (1.0 - t * 0.6)
		var axis := Vector2.from_angle(float(shard.angle) + t * 4.0 * facing) * size
		var normal := axis.orthogonal() * 0.55
		var cooling := smoothstep(0.1, 0.8, t)
		var color := Color("e1a9ff").lerp(Color("562575"), cooling)
		draw_line(tail, point, Color(0.60, 0.15, 0.88, alpha * 0.45), 0.6, false)
		if bool(shard.bright):
			draw_line(point - axis, point + axis, Color(color, alpha), 0.7, false)
			draw_line(point - normal, point + normal, Color(0.95, 0.75, 1.0, alpha * (1.0 - cooling)), 0.5, false)
		else:
			draw_colored_polygon(PackedVector2Array([point - axis, point + normal, point + axis, point - normal]), Color(0.10, 0.02, 0.18, alpha * 0.85))
			draw_line(point + normal, point + axis, Color(color, alpha * 0.9), 0.55, false)
