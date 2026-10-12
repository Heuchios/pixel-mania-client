extends Control

# Use the same confetti scenes as fishing rewards, inside the reward window.
const EPIC_CONFETTI := preload("res://Scenes/particles/EpicFishingRewardConfettiFX.tscn")
const LEGENDARY_CONFETTI := preload("res://Scenes/particles/LegendaryFishingRewardConfettiFX.tscn")
const MAX_PARTICLES := 180
var mode := "idle"
var elapsed := 0.0
var particles: Array[Dictionary] = []
var accent := Color("ffda79")
var gem_texture: Texture2D
var tier := 0
var rng := RandomNumberGenerator.new()
var flight_origin := Vector2.ZERO
var flight_target := Vector2.ZERO
var confetti_effect: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	visibility_changed.connect(_sync_processing)
	_sync_processing()

func _sync_processing() -> void:
	var active := is_visible_in_tree()
	set_process(active)
	if is_instance_valid(confetti_effect):
		confetti_effect.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		for layer in confetti_effect.particle_layers:
			layer.speed_scale = 1.0 if active else 0.0

func set_mode(value: String, reward: Dictionary = {}, texture: Texture2D = null) -> void:
	mode = value
	elapsed = 0.0
	_clear_confetti()
	particles.clear()
	gem_texture = texture
	var gems := int(reward.get("gems", 0))
	tier = 2 if gems >= 5000 else (1 if gems >= 1000 else 0)
	accent = [Color("8cff99"), Color("80d9ff"), Color("ffda79")][tier]
	if mode == "celebrate":
		_start_confetti()
	_sync_processing()
	queue_redraw()

func _clear_confetti() -> void:
	if is_instance_valid(confetti_effect):
		remove_child(confetti_effect)
		confetti_effect.queue_free()
	confetti_effect = null

func _start_confetti() -> void:
	confetti_effect = (LEGENDARY_CONFETTI if tier == 2 else EPIC_CONFETTI).instantiate()
	confetti_effect.preview_emitting = false
	confetti_effect.auto_restart_preview = false
	add_child(confetti_effect)
	# The world version is drawn above all gameplay. Here it inherits this
	# clipped UI region and follows the window when the viewport is resized.
	confetti_effect.z_as_relative = true
	confetti_effect.z_index = 0
	confetti_effect.position = size * 0.5
	confetti_effect.scale = Vector2.ONE * (1.45 if tier == 2 else 1.0)
	for layer in confetti_effect.particle_layers:
		layer.local_coords = true
		if tier == 0:
			layer.amount = maxi(1, roundi(layer.amount * 0.28))
			layer.lifetime *= 0.85
			var material := layer.process_material as ParticleProcessMaterial
			material.initial_velocity_min *= 0.65
			material.initial_velocity_max *= 0.65
			material.scale_min *= 0.8
			material.scale_max *= 0.8
	confetti_effect.play_once()

func tick() -> void:
	for i in range(3):
		_spawn(Vector2(size.x * 0.5, 18), Vector2(rng.randf_range(-45, 45), rng.randf_range(25, 70)), 0.3)

func collect(origin: Vector2, target: Vector2, texture: Texture2D) -> void:
	set_mode("collect", {}, texture)
	flight_origin = origin
	flight_target = target

func _spawn(point: Vector2, velocity: Vector2, lifetime: float) -> void:
	if particles.size() >= MAX_PARTICLES: return
	particles.append({"point": point, "velocity": velocity, "age": 0.0,
		"life": lifetime, "size": rng.randf_range(2.0, 4.5)})

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.age += delta
		if p.age >= p.life:
			particles.remove_at(i)
			continue
		p.point += p.velocity * delta
	queue_redraw()

func _star(point: Vector2, radius: float, color: Color) -> void:
	point = point.round()
	radius = maxf(1, roundf(radius))
	draw_rect(Rect2(point - Vector2(radius * 2, radius * 2), Vector2.ONE * radius * 4), Color(color, color.a * 0.07))
	draw_rect(Rect2(point - Vector2(radius, 1), Vector2(radius * 2 + 1, 2)), color)
	draw_rect(Rect2(point - Vector2(1, radius), Vector2(2, radius * 2 + 1)), color)
	draw_rect(Rect2(point - Vector2.ONE, Vector2.ONE * 2), Color(1, 1, 1, color.a))

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
	if mode == "idle":
		for i in range(7):
			var point := Vector2(fposmod(i * 131.0 + 33, size.x), 22 + fposmod(i * 51.0, maxf(1, size.y - 44)))
			_star(point, 2, Color(1, 0.9, 0.65, 0.22 + sin(elapsed * 2.0 + i) * 0.16))
	for p in particles:
		var alpha := clampf((p.life - p.age) * 2.8, 0, 1)
		var point: Vector2 = p.point
		var color := Color(accent, alpha)
		var tail: Vector2 = point - p.velocity * 0.05
		draw_line(tail.round(), point.round(), Color(accent, alpha * 0.35), 2)
		draw_rect(Rect2(point.round(), Vector2.ONE * p.size), color)
