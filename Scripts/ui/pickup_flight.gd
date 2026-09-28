extends Node2D

# A cosmetic HUD flight; inventory amounts are already authoritative.
const DURATION := 1.15
var elapsed := 0.0
var start_screen := Vector2.ZERO
var target: Control
var icon := Sprite2D.new()
var icon_scale := Vector2.ONE
var trail: Array[Vector2] = []
var last_trail_sample := -1.0
var tint := Color(0.75, 0.92, 1.0)
var arrived: Callable
var world
var source_world := ""

func setup(texture: Texture2D, metrics: Dictionary, origin: Vector2, destination: Control, gem: bool, owner_world, callback: Callable):
	start_screen = origin
	target = destination
	world = owner_world
	source_world = str(world.current_world_name)
	arrived = callback
	z_as_relative = false
	z_index = 200
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.offset = metrics.get("offset", Vector2.ZERO)
	var visible_size: Vector2 = metrics.get("size", texture.get_size())
	icon_scale = Vector2.ONE * ((40.0 if gem else 36.0) / maxf(1.0, maxf(visible_size.x, visible_size.y)))
	icon.scale = icon_scale
	add_child(icon)
	if gem:
		tint = Color(0.4, 1.0, 0.85)
	update_visual(0.0)

func _process(delta: float):
	if not is_instance_valid(world) or str(world.current_world_name) != source_world or not is_instance_valid(target) or not target.is_visible_in_tree():
		queue_free()
		return
	elapsed += delta
	update_visual(clampf(elapsed / DURATION, 0.0, 1.0))
	if elapsed >= DURATION:
		if arrived.is_valid():
			arrived.call()
		queue_free()

func update_visual(progress: float):
	# Resolve the real control every frame, including canvas transforms and HUD resize.
	var end_screen := target.get_global_transform_with_canvas() * (target.size * 0.5)
	var travel := clampf((progress - 0.10) / 0.90, 0.0, 1.0)
	var eased := (1.0 - cos(travel * PI)) * 0.5
	var arc := clampf(start_screen.distance_to(end_screen) * 0.14, 36.0, 90.0)
	var point := start_screen.lerp(end_screen, eased) + Vector2(0, -sin(travel * PI) * arc)
	icon.position = get_global_transform_with_canvas().affine_inverse() * point
	var arrival := clampf((progress - 0.82) / 0.18, 0.0, 1.0)
	var pop := 1.0 + sin(clampf(progress / 0.18, 0.0, 1.0) * PI) * 0.18
	icon.scale = icon_scale * pop * lerpf(1.0, 0.45, arrival)
	icon.modulate.a = 1.0 - arrival * 0.55
	icon.rotation = sin(travel * TAU) * 0.16
	if elapsed - last_trail_sample >= 0.025:
		trail.append(icon.position)
		last_trail_sample = elapsed
		if trail.size() > 7:
			trail.pop_front()
	queue_redraw()

func _draw():
	for i in range(1, trail.size()):
		var strength := float(i) / float(trail.size())
		draw_line(trail[i - 1], trail[i], Color(tint, strength * 0.55), 1.0 + strength * 3.0, true)
	if is_instance_valid(icon):
		draw_circle(icon.position, 21.0, Color(tint, 0.12 * icon.modulate.a))
