@tool
extends Node2D

@export var preview_emitting: bool = true
@export var auto_restart_preview: bool = true
@export_range(0.2, 3.0, 0.02) var preview_interval: float = 0.85
@export_range(0.4, 2.0, 0.05) var particle_scale: float = 1.0
@export var mirror_direction: bool = false
@export var loop_in_game: bool = false

const EFFECT_Z_INDEX := 4085
const FLASH_LIFETIME := 0.16
const SHOCKWAVE_LIFETIME := 0.26
const PHOENIX_PLUME_LIFETIME := 0.34
const LIGHT_FADE_TIME := 0.3
const FLASH_STREAK_COUNT := 10
const SHOCKWAVE_POINTS := 26
const GPU_EMITTER_NAMES := [
	"FlameWisps",
	"PhoenixFeathers",
	"EmberSparks",
	"GlowEmbers",
	"SmokePuff"
]

var rng := RandomNumberGenerator.new()
var gpu_emitters: Array[GPUParticles2D] = []
var impact_light: PointLight2D
var flash_age := 999.0
var preview_timer := 0.0
var one_shot := false

var streak_angle: PackedFloat32Array = []
var streak_length_mult: PackedFloat32Array = []
var streak_alpha_mult: PackedFloat32Array = []
var shockwave_jitter: PackedFloat32Array = []


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	rng.randomize()
	impact_light = get_node_or_null("ImpactLight") as PointLight2D
	_collect_gpu_emitters()
	if preview_emitting:
		restart()
	else:
		set_process(false)


func start() -> void:
	preview_emitting = true
	one_shot = false
	restart()


func stop() -> void:
	preview_emitting = false
	one_shot = false
	flash_age = 999.0
	_stop_gpu_emitters()
	if impact_light:
		impact_light.energy = 0.0
	queue_redraw()
	set_process(false)


func restart() -> void:
	flash_age = 0.0
	preview_timer = preview_interval
	_reroll_draw_randomness()
	_restart_gpu_emitters()
	set_process(true)
	queue_redraw()


## Call this from combat code when the sword lands a hit: instance the scene,
## set global_position to the impact point, add_child it into the world layer,
## then call play_once(facing_direction). The scene frees itself when done.
func play_once(facing_direction: int = 1) -> void:
	mirror_direction = facing_direction < 0
	preview_emitting = false
	auto_restart_preview = false
	loop_in_game = false
	one_shot = true
	restart()


func _process(delta: float) -> void:
	flash_age += delta

	if preview_emitting and auto_restart_preview:
		preview_timer -= delta
		if preview_timer <= 0.0:
			restart()
			return

	if one_shot and flash_age > SHOCKWAVE_LIFETIME + 0.7:
		queue_free()
		return

	if not preview_emitting and not one_shot and not loop_in_game and flash_age > SHOCKWAVE_LIFETIME + 0.7:
		set_process(false)

	_update_light()
	queue_redraw()


func _collect_gpu_emitters() -> void:
	gpu_emitters.clear()
	for emitter_name in GPU_EMITTER_NAMES:
		var emitter := get_node_or_null(emitter_name) as GPUParticles2D
		if emitter == null:
			continue
		if emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate(true)
		emitter.emitting = false
		gpu_emitters.append(emitter)


func _restart_gpu_emitters() -> void:
	if not is_inside_tree():
		return
	if gpu_emitters.is_empty():
		_collect_gpu_emitters()

	var facing_scale := Vector2(-1.0 if mirror_direction else 1.0, 1.0) * particle_scale
	for emitter in gpu_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.scale = facing_scale
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func _stop_gpu_emitters() -> void:
	for emitter in gpu_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false


## Random angles/lengths/jitter are rolled once per burst and held fixed for its
## duration so the flash reads as one coherent (if irregular) crack of fire rather
## than flickering static every frame.
func _reroll_draw_randomness() -> void:
	streak_angle.clear()
	streak_length_mult.clear()
	streak_alpha_mult.clear()
	for _i in range(FLASH_STREAK_COUNT):
		streak_angle.append(rng.randf_range(0.0, TAU))
		streak_length_mult.append(rng.randf_range(0.7, 1.35))
		streak_alpha_mult.append(rng.randf_range(0.35, 0.85))

	shockwave_jitter.clear()
	for _i in range(SHOCKWAVE_POINTS + 1):
		shockwave_jitter.append(rng.randf_range(0.78, 1.22))


func _update_light() -> void:
	if impact_light == null:
		return
	var t := clampf(flash_age / LIGHT_FADE_TIME, 0.0, 1.0)
	var fade := 1.0 - _smoothstep(0.0, 1.0, t)
	impact_light.energy = 1.9 * fade * particle_scale
	impact_light.texture_scale = lerpf(0.62, 1.28, t) * particle_scale


func _draw() -> void:
	_draw_phoenix_plume()
	_draw_shockwave()
	_draw_flash()


func _draw_flash() -> void:
	var t := clampf(flash_age / FLASH_LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		return

	var alpha := (1.0 - t) * 0.96
	var core_radius := lerpf(3.0, 14.5, t) * particle_scale
	draw_circle(Vector2.ZERO, core_radius * 2.45, Color(0.78, 0.08, 0.02, alpha * 0.14))
	draw_circle(Vector2.ZERO, core_radius * 1.72, Color(1.0, 0.34, 0.04, alpha * 0.34))
	draw_circle(Vector2.ZERO, core_radius * 1.18, Color(1.0, 0.64, 0.08, alpha * 0.44))
	draw_circle(Vector2.ZERO, core_radius * 0.58, Color(1.0, 0.98, 0.8, alpha * 0.92))

	var base_length := lerpf(12.0, 36.0, t) * particle_scale
	for i in range(streak_angle.size()):
		var direction := Vector2.RIGHT.rotated(streak_angle[i])
		var length := base_length * streak_length_mult[i]
		var line_alpha := alpha * streak_alpha_mult[i]
		draw_line(
			direction * length * 0.15,
			direction * length,
			Color(1.0, 0.6, 0.08, line_alpha),
			maxf(0.8, 2.0 * particle_scale * (1.0 - t)),
			true
		)


func _draw_phoenix_plume() -> void:
	var t := clampf(flash_age / PHOENIX_PLUME_LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		return

	var reveal := _ease_out_cubic(clampf(t / 0.72, 0.0, 1.0))
	var fade := 1.0 - _smoothstep(0.42, 1.0, t)
	if reveal <= 0.01 or fade <= 0.01:
		return

	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for feather_index in range(3):
			var feather_tilt := float(feather_index) / 2.0
			var length := lerpf(21.0, 39.0, feather_tilt) * particle_scale
			var rise := lerpf(16.0, 30.0, feather_tilt) * particle_scale
			var outward := side * lerpf(0.62, 1.0, feather_tilt)
			var points := _make_plume_feather_path(outward, length, rise, reveal)
			var line_alpha := fade * lerpf(0.46, 0.76, feather_tilt)
			var line_width := lerpf(2.1, 1.1, feather_tilt) * particle_scale
			_draw_plume_feather(points, line_width, line_alpha)


func _make_plume_feather_path(outward: float, length: float, rise: float, reveal: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 14
	var visible_steps := maxi(2, int(ceil(float(steps) * clampf(reveal, 0.0, 1.0))))
	var facing_scale := -1.0 if mirror_direction else 1.0

	for i in range(visible_steps + 1):
		var p := float(i) / float(steps)
		var taper := sin(p * PI)
		var x := outward * facing_scale * length * p
		var y := -rise * sin(p * PI * 0.58) - (p * 7.0 * particle_scale)
		var curl := outward * facing_scale * taper * 5.0 * particle_scale
		points.append(Vector2(x + curl, y))

	return points


func _draw_plume_feather(points: PackedVector2Array, width: float, alpha: float) -> void:
	if points.size() < 2 or alpha <= 0.01:
		return

	draw_polyline(points, Color(0.78, 0.08, 0.01, 0.16 * alpha), maxf(1.0, width * 4.2), false)
	draw_polyline(points, Color(1.0, 0.36, 0.02, 0.34 * alpha), maxf(0.8, width * 2.5), false)
	draw_polyline(points, Color(1.0, 0.78, 0.18, 0.72 * alpha), maxf(0.65, width), false)

	var tip := points[points.size() - 1]
	draw_circle(tip, maxf(1.6, width * 1.35), Color(1.0, 0.92, 0.46, 0.22 * alpha))


func _draw_shockwave() -> void:
	var t := clampf(flash_age / SHOCKWAVE_LIFETIME, 0.0, 1.0)
	if t >= 1.0 or shockwave_jitter.is_empty():
		return

	var fade := 1.0 - _smoothstep(0.3, 1.0, t)
	if fade <= 0.01:
		return

	var base_radius := lerpf(3.0, 32.0, _ease_out_cubic(t)) * particle_scale
	var width := lerpf(3.2, 0.55, t) * particle_scale
	var color := Color(1.0, 0.42, 0.04, fade * 0.46)
	var hot_color := Color(1.0, 0.86, 0.28, fade * 0.28)

	var points := PackedVector2Array()
	for i in range(SHOCKWAVE_POINTS + 1):
		var angle := (float(i) / float(SHOCKWAVE_POINTS)) * TAU
		var radius := base_radius * shockwave_jitter[i]
		points.append(Vector2.RIGHT.rotated(angle) * radius)

	draw_polyline(points, color, maxf(0.5, width), true)
	draw_polyline(points, hot_color, maxf(0.5, width * 0.45), true)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
