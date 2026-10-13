@tool
extends Node2D
## Small pixel bats drift away from the cape; the equipment manager owns its poses.

@export var bat_color := Color(0.22, 0.06, 0.32)
const MAX_BATS := 16
const WING_POSES := [
	[Vector2i(-4, -1), Vector2i(-3, -2), Vector2i(-2, -1), Vector2i(2, -1), Vector2i(3, -2), Vector2i(4, -1)],
	[Vector2i(-4, 1), Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 1)]
]
var wings: AnimatedSprite2D
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var moving := false
var credit := 0.0
var clock := 0.0
var side := 1.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()

func bind_wings(sprite: AnimatedSprite2D) -> void:
	if wings == sprite:
		return
	wings = sprite
	clear()

func set_moving(value: bool) -> void:
	moving = value

func clear() -> void:
	particles.clear()
	credit = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(wings) and not wings.is_visible_in_tree():
		clear()
		return
	clock += delta
	credit += delta * (6.0 if moving else 3.0)
	while credit >= 1.0:
		credit -= 1.0
		if particles.size() < MAX_BATS:
			side = -side
			var origin := wings.position if is_instance_valid(wings) else Vector2(0, -6)
			particles.append({"position": origin + Vector2(side * rng.randf_range(8, 13), -5),
				"velocity": Vector2(side * rng.randf_range(6, 13), rng.randf_range(-14, -8)),
				"age": 0.0, "lifetime": rng.randf_range(1.1, 1.8), "phase": rng.randf_range(0, TAU)})
	for i in range(particles.size() - 1, -1, -1):
		var bat: Dictionary = particles[i]
		bat.age += delta
		if bat.age >= bat.lifetime:
			particles.remove_at(i)
		else:
			bat.position += bat.velocity * delta
	queue_redraw()

func _draw() -> void:
	for bat in particles:
		var origin: Vector2 = (bat.position + Vector2(0, sin(clock * 7.0 + bat.phase))).round()
		var alpha := minf(1.0, float(bat.age) * 8.0) * clampf((float(bat.lifetime) - float(bat.age)) * 3.0, 0.0, 1.0)
		var tint := Color(bat_color, alpha)
		var pose: Array = WING_POSES[int(floor(clock * 10.0 + bat.phase)) % 2]
		draw_rect(Rect2(origin + Vector2(-1, -1), Vector2(3, 3)), tint)
		draw_rect(Rect2(origin + Vector2(-1, -2), Vector2(1, 1)), tint)
		draw_rect(Rect2(origin + Vector2(1, -2), Vector2(1, 1)), tint)
		for pixel in pose:
			draw_rect(Rect2(origin + Vector2(pixel), Vector2(1, 2)), tint)
		draw_rect(Rect2(origin, Vector2(1, 1)), Color(1.0, 0.65, 0.85, alpha))
