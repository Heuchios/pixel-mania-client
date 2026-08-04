@tool
extends Node2D

@export var preview_emitting := true
@export var auto_restart_preview := true
@export_range(0.2, 2.0, 0.02) var preview_interval := 0.58
@export_range(0.12, 0.8, 0.01) var slash_lifetime := 0.34
@export_range(0.4, 2.0, 0.05) var slash_scale := 1.0
@export_range(-180.0, 180.0, 1.0) var slash_rotation_degrees := -8.0
@export_range(28.0, 92.0, 1.0) var slash_length := 58.0
@export_range(8.0, 44.0, 1.0) var slash_curve_height := 24.0
@export_range(0.5, 8.0, 0.25) var slash_width := 2.2
@export var mirror_direction := false

const EFFECT_Z_INDEX := 4091
const GPU_EMITTER_NAMES := [
	"TrailGoldChips",
	"TipWhiteSparks",
	"AmberDust"
]

var slash_age := 999.0
var preview_timer := 0.0
var one_shot := false
var gpu_emitters: Array[GPUParticles2D] = []


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
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
	slash_age = 999.0
	_stop_gpu_emitters()
	queue_redraw()
	set_process(false)


func restart() -> void:
	slash_age = 0.0
	preview_timer = preview_interval
	_restart_gpu_emitters()
	set_process(true)
	queue_redraw()


func play_once(facing_direction: int = 1) -> void:
	mirror_direction = facing_direction < 0
	preview_emitting = false
	auto_restart_preview = false
	one_shot = true
	restart()


func _process(delta: float) -> void:
	slash_age += delta

	if preview_emitting and auto_restart_preview:
		preview_timer -= delta
		if preview_timer <= 0.0:
			restart()
			return

	if one_shot and slash_age > slash_lifetime + 0.28:
		queue_free()
		return

	if not preview_emitting and not one_shot and slash_age > slash_lifetime + 0.08:
		set_process(false)

	queue_redraw()


func _draw() -> void:
	if slash_age > slash_lifetime:
		return

	var t := clampf(slash_age / maxf(0.01, slash_lifetime), 0.0, 1.0)
	var reveal := _ease_out_cubic(clampf(t / 0.62, 0.0, 1.0))
	var fade := 1.0 - _smoothstep(0.60, 1.0, t)
	var hit_flash := 1.0 - _smoothstep(0.42, 0.88, t)

	var main_path := _visible_path(_make_slash_path(Vector2.ZERO, 1.0), reveal)
	var lower_path := _visible_path(_make_slash_path(Vector2(0.0, 4.0), 0.78), clampf(reveal - 0.08, 0.0, 1.0))
	var upper_path := _visible_path(_make_slash_path(Vector2(0.0, -3.0), 0.88), clampf(reveal - 0.03, 0.0, 1.0))

	_draw_slash_layers(lower_path, fade * 0.54, slash_width * 0.72, Color(1.0, 0.42, 0.02, 1.0), Color(0.42, 0.14, 0.02, 1.0))
	_draw_slash_layers(upper_path, fade * 0.62, slash_width * 0.82, Color(1.0, 0.70, 0.08, 1.0), Color(0.84, 0.30, 0.02, 1.0))
	_draw_slash_layers(main_path, fade, slash_width, Color(1.0, 0.83, 0.12, 1.0), Color(1.0, 0.40, 0.0, 1.0))
	_draw_edge_flash(main_path, reveal, fade)
	_draw_mandible_teeth(main_path, reveal, fade)
	_draw_tip_flash(main_path, reveal, hit_flash)


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
	for emitter in gpu_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func _stop_gpu_emitters() -> void:
	for emitter in gpu_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false


func _draw_slash_layers(points: PackedVector2Array, alpha: float, width: float, body: Color, glow: Color) -> void:
	if points.size() < 2 or alpha <= 0.01:
		return
	draw_polyline(points, Color(glow.r, glow.g, glow.b, 0.20 * alpha), maxf(2.0, width * 3.3), false)
	draw_polyline(points, Color(body.r, body.g, body.b, 0.76 * alpha), maxf(1.0, width * 1.7), false)
	draw_polyline(points, Color(1.0, 0.98, 0.72, 0.94 * alpha), maxf(0.6, width * 0.46), false)


func _draw_mandible_teeth(points: PackedVector2Array, reveal: float, alpha: float) -> void:
	if points.size() < 5 or alpha <= 0.01:
		return
	for i in range(3, points.size() - 2, 4):
		var path_t := float(i) / float(maxi(1, points.size() - 1))
		if path_t > reveal:
			continue
		var tangent := (points[i + 1] - points[i - 1]).normalized()
		if tangent.length_squared() < 0.01:
			continue
		var normal := Vector2(-tangent.y, tangent.x)
		var side := -1.0 if i % 2 == 0 else 1.0
		var tooth_len := lerpf(4.8, 2.2, path_t) * slash_scale
		var start := points[i] + tangent * 1.2
		var end := start + normal * side * tooth_len + tangent * 1.4
		draw_line(start, end, Color(1.0, 0.92, 0.38, 0.78 * alpha), maxf(0.7, slash_width * 0.34), false)


func _draw_tip_flash(points: PackedVector2Array, reveal: float, alpha: float) -> void:
	if points.size() < 2 or reveal < 0.72 or alpha <= 0.01:
		return
	var tip := points[points.size() - 1]
	var radius := lerpf(7.0, 2.0, reveal) * slash_scale
	draw_circle(tip, radius, Color(1.0, 0.58, 0.03, 0.18 * alpha))
	draw_line(tip + Vector2(-4.0, 0.0), tip + Vector2(4.0, 0.0), Color(1.0, 0.96, 0.62, 0.82 * alpha), 1.0, false)
	draw_line(tip + Vector2(0.0, -4.0), tip + Vector2(0.0, 4.0), Color(1.0, 0.96, 0.62, 0.82 * alpha), 1.0, false)


func _draw_edge_flash(points: PackedVector2Array, reveal: float, alpha: float) -> void:
	if points.size() < 2 or alpha <= 0.01:
		return

	var edge := points[0]
	var pulse := 1.0 - _smoothstep(0.0, 0.38, reveal)
	draw_circle(edge, lerpf(5.5, 1.5, reveal) * slash_scale, Color(1.0, 0.72, 0.08, 0.22 * alpha * pulse))
	draw_line(edge + Vector2(-3.0, 0.0), edge + Vector2(6.0, 0.0), Color(1.0, 0.96, 0.62, 0.60 * alpha), 1.0, false)


func _make_slash_path(offset: Vector2, size_mult: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var vertical_sign := -1.0 if mirror_direction else 1.0
	var length := slash_length * slash_scale * size_mult
	var curve_height := slash_curve_height * slash_scale * size_mult
	var rotation := deg_to_rad(slash_rotation_degrees * vertical_sign)
	var steps := 30

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var taper := sin(t * PI)
		var x := length * t
		var y := (lerpf(0.0, 8.0, t) - curve_height * taper) * vertical_sign
		var wave := sin(t * TAU * 1.15) * 1.2 * slash_scale * taper * vertical_sign
		var point := Vector2(x, y + wave).rotated(rotation) + Vector2(offset.x, offset.y * vertical_sign)
		points.append(point)

	return points


func _visible_path(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var visible := PackedVector2Array()
	if points.size() < 2 or progress <= 0.0:
		return visible

	var scaled := clampf(progress, 0.0, 1.0) * float(points.size() - 1)
	var full_count := clampi(int(floor(scaled)), 1, points.size() - 1)
	for i in range(full_count + 1):
		visible.append(points[i])

	if full_count < points.size() - 1:
		var partial := scaled - float(full_count)
		visible.append(points[full_count].lerp(points[full_count + 1], partial))

	return visible


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
