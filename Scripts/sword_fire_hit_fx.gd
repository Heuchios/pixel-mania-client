@tool
extends Node2D

@export var preview_emitting: bool = true
@export var auto_restart_preview: bool = true
@export_range(0.2, 3.0, 0.02) var preview_interval: float = 0.85
@export_range(0.4, 2.0, 0.05) var particle_scale: float = 1.0
@export var mirror_direction: bool = false
@export var loop_in_game: bool = false

const EFFECT_Z_INDEX := 4085
const FLASH_LIFETIME := 0.09
const SHOCKWAVE_LIFETIME := 0.22
const PHOENIX_PLUME_LIFETIME := 0.38
const LIGHT_FADE_TIME := 0.22
const FLASH_STREAK_COUNT := 7
const SHOCKWAVE_POINTS := 36
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
var burst_lifetime := 0.85

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
	_update_burst_lifetime()
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
	_update_burst_lifetime()
	_update_light()
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

	if (preview_emitting and auto_restart_preview) or (loop_in_game and not Engine.is_editor_hint()):
		preview_timer -= delta
		if preview_timer <= 0.0:
			restart()
			return

	if one_shot and flash_age > burst_lifetime:
		queue_free()
		return

	if not preview_emitting and not one_shot and not loop_in_game and flash_age > burst_lifetime:
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


func _update_burst_lifetime() -> void:
	burst_lifetime = maxf(PHOENIX_PLUME_LIFETIME, maxf(SHOCKWAVE_LIFETIME, LIGHT_FADE_TIME))
	for emitter in gpu_emitters:
		# A one-shot emitter can spawn its last particle after the initial hit.
		# Wait for that particle's full fade instead of cutting off the embers.
		burst_lifetime = maxf(burst_lifetime, emitter.lifetime * (2.0 - emitter.explosiveness) + 0.06)


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
		emitter.show()
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func _stop_gpu_emitters() -> void:
	for emitter in gpu_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		emitter.hide()


## Random angles/lengths/jitter are rolled once per burst and held fixed for its
## duration so the flash reads as one coherent (if irregular) crack of fire rather
## than flickering static every frame.
func _reroll_draw_randomness() -> void:
	streak_angle.clear()
	streak_length_mult.clear()
	streak_alpha_mult.clear()
	for _i in range(FLASH_STREAK_COUNT):
		streak_angle.append(float(_i) * TAU / FLASH_STREAK_COUNT + rng.randf_range(-0.15, 0.15))
		streak_length_mult.append(rng.randf_range(0.72, 1.1))
		streak_alpha_mult.append(rng.randf_range(0.65, 0.95))

	shockwave_jitter.clear()
	for _i in range(SHOCKWAVE_POINTS + 1):
		shockwave_jitter.append(rng.randf_range(0.97, 1.03))
	shockwave_jitter[SHOCKWAVE_POINTS] = shockwave_jitter[0]


func _update_light() -> void:
	if impact_light == null:
		return
	var t := clampf(flash_age / LIGHT_FADE_TIME, 0.0, 1.0)
	var fade := 1.0 - _smoothstep(0.0, 1.0, t)
	impact_light.energy = 1.45 * fade * particle_scale
	impact_light.texture_scale = lerpf(0.46, 0.90, t) * particle_scale


func _draw() -> void:
	_draw_phoenix_plume()
	_draw_shockwave()
	_draw_flash()


func _draw_flash() -> void:
	var t := clampf(flash_age / FLASH_LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		return

	var alpha := pow(1.0 - t, 1.4)
	var core_radius := lerpf(3.0, 8.0, _ease_out_cubic(t)) * particle_scale
	draw_circle(Vector2.ZERO, core_radius * 1.8, Color(1.0, 0.26, 0.015, alpha * 0.14))
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 0.68, 0.12, alpha * 0.45))
	# A narrow hot slash gives the contact a clear direction before the fire opens.
	var facing := -1.0 if mirror_direction else 1.0
	var slash_axis := Vector2(0.68 * facing, -0.74)
	var slash_normal := Vector2(-slash_axis.y, slash_axis.x)
	var slash_length := lerpf(9.0, 22.0, _ease_out_cubic(t)) * particle_scale
	draw_colored_polygon(PackedVector2Array([
		-slash_axis * slash_length, -slash_normal * 2.1 * particle_scale,
		slash_axis * slash_length, slash_normal * 2.1 * particle_scale
	]), Color(1.0, 0.96, 0.74, alpha))
	draw_circle(Vector2.ZERO, core_radius * 0.4, Color(1.0, 1.0, 0.93, alpha))

	var base_length := lerpf(5.0, 23.0, _ease_out_cubic(t)) * particle_scale
	for i in range(streak_angle.size()):
		var direction := Vector2.RIGHT.rotated(streak_angle[i])
		var length := base_length * streak_length_mult[i]
		var line_alpha := alpha * streak_alpha_mult[i]
		draw_line(
			direction * length * 0.35,
			direction * length,
			Color(1.0, 0.6, 0.08, line_alpha),
			maxf(0.65, 1.4 * particle_scale * (1.0 - t)),
			false
		)


func _draw_phoenix_plume() -> void:
	var t := clampf(flash_age / PHOENIX_PLUME_LIFETIME, 0.0, 1.0)
	if t >= 1.0:
		return

	var reveal := _ease_out_cubic(clampf(t / 0.48, 0.0, 1.0))
	var fade := 1.0 - _smoothstep(0.20, 1.0, t)
	if reveal <= 0.01 or fade <= 0.01:
		return

	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for feather_index in range(4):
			var feather_tilt := float(feather_index) / 3.0
			var length := lerpf(17.0, 30.0, feather_tilt) * particle_scale
			var rise := lerpf(10.0, 26.0, feather_tilt) * particle_scale
			var outward := side
			var points := _make_plume_feather_path(outward, length, rise, reveal)
			var width := lerpf(4.6, 3.0, feather_tilt) * particle_scale * sqrt(fade) * reveal
			_draw_plume_feather(points, width, fade)


func _make_plume_feather_path(outward: float, length: float, rise: float, reveal: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 18
	var facing_scale := -1.0 if mirror_direction else 1.0

	var lift := pow(clampf(flash_age / PHOENIX_PLUME_LIFETIME, 0.0, 1.0), 1.5) * 10.0 * particle_scale
	for i in range(steps + 1):
		var p := float(i) / float(steps)
		var taper := sin(p * PI)
		var x := outward * facing_scale * length * p * reveal
		var y := -rise * sin(p * PI * 0.62) * reveal - lift * p
		var curl := outward * facing_scale * taper * 4.0 * particle_scale * reveal
		points.append(Vector2(x + curl, y))

	return points


func _draw_plume_feather(points: PackedVector2Array, width: float, alpha: float) -> void:
	if points.size() < 2 or alpha <= 0.01:
		return

	_draw_flame_ribbon(points, width * 1.55, Color(0.98, 0.18, 0.015, alpha * 0.18))
	_draw_flame_ribbon(points, width, Color(1.0, 0.36, 0.025, alpha * 0.85))
	_draw_flame_ribbon(points, width * 0.50, Color(1.0, 0.77, 0.17, alpha * 0.95))
	_draw_flame_ribbon(points, width * 0.17, Color(1.0, 0.96, 0.65, alpha * 0.65))


func _draw_flame_ribbon(points: PackedVector2Array, width: float, color: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(points.size()):
		var p := float(i) / float(points.size() - 1)
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var taper := pow(sin(p * PI), 0.8) * (1.0 - p * 0.35)
		left.append(points[i] + normal * width * taper)
		right.append(points[i] - normal * width * taper)
	# One tapered outline per layer keeps repeated impacts inexpensive.
	for i in range(right.size() - 2, 0, -1):
		left.append(right[i])
	draw_colored_polygon(left, color)


func _draw_shockwave() -> void:
	var t := clampf(flash_age / SHOCKWAVE_LIFETIME, 0.0, 1.0)
	if t >= 1.0 or shockwave_jitter.is_empty():
		return

	var fade := 1.0 - _smoothstep(0.3, 1.0, t)
	if fade <= 0.01:
		return

	var base_radius := lerpf(3.0, 25.0, _ease_out_cubic(t)) * particle_scale
	var width := lerpf(2.1, 0.4, t) * particle_scale
	var color := Color(1.0, 0.42, 0.04, fade * 0.42)
	var hot_color := Color(1.0, 0.86, 0.28, fade * 0.35)

	var points := PackedVector2Array()
	for i in range(SHOCKWAVE_POINTS + 1):
		var angle := (float(i) / float(SHOCKWAVE_POINTS)) * TAU
		var radius := base_radius * shockwave_jitter[i]
		points.append(Vector2.RIGHT.rotated(angle) * radius)

	for i in range(1, points.size()):
		if i % 12 >= 9:
			continue
		draw_line(points[i - 1], points[i], color, maxf(0.5, width), false)
		draw_line(points[i - 1], points[i], hot_color, maxf(0.4, width * 0.4), false)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
