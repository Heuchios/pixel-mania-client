extends Control

# Bounded native pixel particles; no full-screen fill or GPU emitters.
const MAX_PARTICLES := 180
var mode := "idle"
var elapsed := 0.0
var particles: Array[Dictionary] = []
var accent := Color("ffda79")
var gem_texture: Texture2D
var tier := 0
var spawn_clock := 0.0
var rng := RandomNumberGenerator.new()
var flight_origin := Vector2.ZERO
var flight_target := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	visibility_changed.connect(_sync_processing)
	_sync_processing()

func _sync_processing() -> void:
	set_process(is_visible_in_tree())

func set_mode(value: String, reward: Dictionary = {}, texture: Texture2D = null) -> void:
	mode = value
	elapsed = 0.0
	spawn_clock = 0.0
	particles.clear()
	gem_texture = texture
	var gems := int(reward.get("gems", 0))
	tier = 2 if gems >= 5000 else (1 if gems >= 1000 else 0)
	accent = [Color("8cff99"), Color("80d9ff"), Color("ffda79")][tier]
	if mode == "celebrate":
		for i in range(54 + tier * 42):
			var angle := rng.randf_range(-PI, PI)
			var direction := Vector2(cos(angle), sin(angle) * 0.55)
			_spawn(size * 0.5 + direction * rng.randf_range(28, 50), direction * rng.randf_range(150, 300 + tier * 60), rng.randf_range(0.85, 1.8), i % 5)
	_sync_processing()
	queue_redraw()

func tick() -> void:
	for i in range(3):
		_spawn(Vector2(size.x * 0.5, 18), Vector2(rng.randf_range(-45, 45), rng.randf_range(25, 70)), 0.3, 0)

func collect(origin: Vector2, target: Vector2, texture: Texture2D) -> void:
	set_mode("collect", {}, texture)
	flight_origin = origin
	flight_target = target

func _spawn(point: Vector2, velocity: Vector2, lifetime: float, kind: int) -> void:
	if particles.size() >= MAX_PARTICLES: return
	particles.append({"point": point, "velocity": velocity, "age": 0.0,
		"life": lifetime, "kind": kind, "size": rng.randf_range(2.0, 4.5), "seed": rng.randf_range(0, TAU)})

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.age += delta
		if p.age >= p.life:
			particles.remove_at(i)
			continue
		p.velocity += Vector2(0, 65 if mode == "celebrate" else 0) * delta
		p.point += p.velocity * delta
	if mode == "celebrate":
		spawn_clock += delta
		if spawn_clock >= 0.09 - tier * 0.02:
			spawn_clock = 0.0
			var angle := rng.randf_range(0, TAU)
			_spawn(size * 0.5 + Vector2(cos(angle) * 140, sin(angle) * 68), Vector2(0, -25), 1.1, 1)
	queue_redraw()

func _star(point: Vector2, radius: float, color: Color) -> void:
	point = point.round()
	radius = maxf(1, roundf(radius))
	draw_rect(Rect2(point - Vector2(radius * 2, radius * 2), Vector2.ONE * radius * 4), Color(color, color.a * 0.07))
	draw_rect(Rect2(point - Vector2(radius, 1), Vector2(radius * 2 + 1, 2)), color)
	draw_rect(Rect2(point - Vector2(1, radius), Vector2(2, radius * 2 + 1)), color)
	draw_rect(Rect2(point - Vector2.ONE, Vector2.ONE * 2), Color(1, 1, 1, color.a))

func _ring(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(9):
		points.append((center + Vector2.from_angle(float(i) * TAU / 8.0) * radius).round())
	draw_polyline(points, color, 2.0, false)

func _draw() -> void:
	if mode == "collect":
		for i in range(14):
			var t := clampf((elapsed - float(i) * 0.022) / 0.62, 0, 1)
			if t <= 0 or t >= 1: continue
			var bend := flight_origin.lerp(flight_target, 0.4) + Vector2(35 - i * 5, -100 - i * 3)
			var point := flight_origin.lerp(bend, t).lerp(bend.lerp(flight_target, t), t).round()
			var extent := 22.0 * (1.0 - t * 0.4)
			_star(point + Vector2(9, 9), 3, Color("ffda79"))
			if gem_texture != null: draw_texture_rect(gem_texture, Rect2(point - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false)
		return
	var center := size * 0.5
	if mode == "celebrate":
		for i in range(6 + tier * 3):
			var orbit := float(i) * TAU / float(6 + tier * 3) + elapsed * 0.35
			var point := center + Vector2(cos(orbit) * 146, sin(orbit) * 74)
			_star(point, 3 + sin(elapsed * 3 + i), Color(accent, 0.7))
		for i in range(12):
			var angle := float(i) * TAU / 12.0 + elapsed * 0.16
			var tip := Vector2(cos(angle) * 164, sin(angle) * 92)
			var edge := Vector2(cos(angle + 0.13) * 164, sin(angle + 0.13) * 92)
			draw_colored_polygon(PackedVector2Array([center, center + tip, center + edge]), Color(accent, 0.13))
		for i in range(2):
			var t := elapsed - float(i) * 0.16
			if t >= 0 and t < 0.8: _ring(center, 30 + t * 150, Color(accent, (1.0 - t / 0.8) * 0.6))
	elif mode == "idle":
		for i in range(7):
			var point := Vector2(fposmod(i * 131.0 + 33, size.x), 22 + fposmod(i * 51.0, maxf(1, size.y - 44)))
			_star(point, 2, Color(1, 0.9, 0.65, 0.22 + sin(elapsed * 2.0 + i) * 0.16))
	for p in particles:
		var alpha := clampf((p.life - p.age) * 2.8, 0, 1)
		var point: Vector2 = p.point
		var color := Color(accent, alpha)
		if int(p.kind) == 4 and gem_texture != null:
			var extent: float = 12 + p.size
			draw_texture_rect(gem_texture, Rect2(point.round() - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, Color(1, 1, 1, alpha))
		elif int(p.kind) == 1:
			_star(point, p.size * (0.7 + sin(p.age * 9 + p.seed) * 0.3), color)
		else:
			var tail: Vector2 = point - p.velocity * 0.05
			draw_line(tail.round(), point.round(), Color(accent, alpha * 0.35), 2)
			draw_rect(Rect2(point.round(), Vector2.ONE * p.size), color)
