@tool
extends Node2D

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_apply_emitting()
		_apply_process_state()
		queue_redraw()

@export_range(4.0, 512.0, 1.0) var flow_length_px := 96.0:
	set(value):
		flow_length_px = maxf(4.0, value)
		_apply_flow_settings()
		queue_redraw()

@export_range(16.0, 420.0, 1.0) var flow_speed_px := 132.0:
	set(value):
		flow_speed_px = maxf(16.0, value)
		_apply_flow_settings()
		queue_redraw()

@export_range(1.0, 10.0, 0.5) var wire_thickness_px := 1.5:
	set(value):
		wire_thickness_px = maxf(1.0, value)
		_apply_flow_settings()
		queue_redraw()

@export var show_wire_preview_line := true:
	set(value):
		show_wire_preview_line = value
		queue_redraw()

@export_range(1, 6, 1) var pulse_count := 2:
	set(value):
		pulse_count = maxi(1, value)
		queue_redraw()

@export_range(6.0, 96.0, 1.0) var pulse_length_px := 16.0:
	set(value):
		pulse_length_px = maxf(6.0, value)
		queue_redraw()

@export_range(0.0, 8.0, 0.25) var pulse_jitter_px := 1.25:
	set(value):
		pulse_jitter_px = maxf(0.0, value)
		queue_redraw()

@export_range(0.5, 5.0, 0.25) var pulse_core_width_px := 0.65:
	set(value):
		pulse_core_width_px = maxf(0.5, value)
		queue_redraw()

@export var draw_cpu_pulses := false:
	set(value):
		draw_cpu_pulses = value
		_apply_process_state()
		queue_redraw()

const EFFECT_Z_INDEX := 4088
const FLOW_LIFETIME_MIN_SECONDS := 0.10
const FLOW_LIFETIME_MAX_SECONDS := 40.0
const FLOW_PREWARM_MAX_SECONDS := 6.0
const FLOW_ENDPOINT_PADDING_MIN_PX := 6.0
const FLOW_ENDPOINT_PADDING_RATIO := 0.03

var particle_layers: Array[GPUParticles2D] = []
var pulse_time := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	_collect_particle_layers()
	_apply_flow_settings()
	_apply_emitting()
	_apply_process_state()


func start() -> void:
	preview_emitting = true
	_apply_emitting()
	_apply_process_state()
	queue_redraw()


func stop() -> void:
	preview_emitting = false
	_apply_emitting()
	_apply_process_state()
	queue_redraw()


func restart() -> void:
	pulse_time = 0.0
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.restart()
		layer.emitting = preview_emitting
	queue_redraw()


func set_wire_segment(start_position: Vector2, end_position: Vector2) -> void:
	global_position = start_position
	var offset := end_position - start_position
	if offset.length_squared() < 1.0:
		return
	rotation = offset.angle()
	flow_length_px = offset.length()
	_apply_flow_settings()


func set_local_wire_segment(start_position: Vector2, end_position: Vector2) -> void:
	position = start_position
	var offset := end_position - start_position
	if offset.length_squared() < 1.0:
		return
	rotation = offset.angle()
	flow_length_px = offset.length()
	_apply_flow_settings()


func set_flow_length(length_px: float) -> void:
	flow_length_px = length_px
	_apply_flow_settings()


func _collect_particle_layers() -> void:
	particle_layers.clear()
	for child in get_children():
		if not (child is GPUParticles2D):
			continue
		var layer := child as GPUParticles2D
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)
		layer.emitting = false
		particle_layers.append(layer)


func _apply_emitting() -> void:
	if not is_inside_tree():
		return
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = preview_emitting


func _apply_process_state() -> void:
	if not is_inside_tree():
		return
	set_process((preview_emitting and draw_cpu_pulses) or Engine.is_editor_hint())


func _apply_flow_settings() -> void:
	if not is_inside_tree():
		return
	if particle_layers.is_empty():
		_collect_particle_layers()

	var length := maxf(4.0, flow_length_px)
	var speed := maxf(16.0, flow_speed_px)
	var endpoint_padding := maxf(FLOW_ENDPOINT_PADDING_MIN_PX, length * FLOW_ENDPOINT_PADDING_RATIO)
	var visibility_height := maxf(8.0, wire_thickness_px * 3.0 + pulse_jitter_px * 2.0)

	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue

		var clean_name := layer.name.to_lower()
		var speed_mult := 1.0
		if clean_name.contains("core"):
			speed_mult = 1.08
		elif clean_name.contains("flicker"):
			speed_mult = 1.18

		var layer_speed := speed * speed_mult
		layer.lifetime = clampf((length + endpoint_padding) / layer_speed, FLOW_LIFETIME_MIN_SECONDS, FLOW_LIFETIME_MAX_SECONDS)
		layer.preprocess = minf(layer.lifetime, FLOW_PREWARM_MAX_SECONDS)
		layer.visibility_rect = Rect2(
			Vector2(-4.0, -visibility_height * 0.5),
			Vector2(length + endpoint_padding + 8.0, visibility_height)
		)

		var material := layer.process_material
		if material is ParticleProcessMaterial:
			material.emission_box_extents = Vector3(1.0, maxf(0.5, wire_thickness_px * 0.35), 0.0)
			material.initial_velocity_min = layer_speed
			material.initial_velocity_max = layer_speed


func _process(delta: float) -> void:
	if not preview_emitting and not Engine.is_editor_hint():
		set_process(false)
		return

	if preview_emitting:
		pulse_time += delta
		if draw_cpu_pulses or show_wire_preview_line:
			queue_redraw()


func _draw() -> void:
	var length := maxf(4.0, flow_length_px)
	if show_wire_preview_line:
		var guide_width := maxf(1.0, wire_thickness_px)
		draw_line(Vector2.ZERO, Vector2(length, 0.0), Color(0.24, 0.13, 0.02, 0.58), guide_width + 2.0, false)
		draw_line(Vector2.ZERO, Vector2(length, 0.0), Color(0.86, 0.55, 0.05, 0.34), guide_width, false)

	if not preview_emitting or not draw_cpu_pulses:
		return

	var track_length := length + maxf(1.0, pulse_length_px)
	var spacing := track_length / float(maxi(1, pulse_count))
	for index in range(maxi(1, pulse_count)):
		var head_x := fmod(pulse_time * flow_speed_px + spacing * float(index), track_length)
		var tail_x := head_x - pulse_length_px
		_draw_linear_pulse(tail_x, head_x, index)


func _draw_linear_pulse(tail_x: float, head_x: float, seed: int) -> void:
	var length := maxf(4.0, flow_length_px)
	var start_x := clampf(tail_x, 0.0, length)
	var end_x := clampf(head_x, 0.0, length)
	if end_x - start_x < 2.0:
		return

	var points := _make_pulse_points(start_x, end_x, seed)
	if points.size() < 2:
		return

	var pulse_progress := clampf((end_x - start_x) / maxf(1.0, pulse_length_px), 0.0, 1.0)
	var alpha := clampf(0.32 + pulse_progress * 0.68, 0.0, 1.0)
	var glow_width := maxf(1.25, pulse_core_width_px * 2.5)
	var body_width := maxf(0.8, pulse_core_width_px * 1.55)
	var core_width := maxf(0.5, pulse_core_width_px)

	draw_polyline(points, Color(1.00, 0.42, 0.00, 0.26 * alpha), glow_width, false)
	draw_polyline(points, Color(1.00, 0.78, 0.06, 0.78 * alpha), body_width, false)
	draw_polyline(points, Color(1.00, 0.98, 0.72, 0.98 * alpha), core_width, false)

	for point_index in range(1, points.size() - 1):
		if (point_index + seed) % 3 != 0:
			continue
		var point := points[point_index]
		var side := -1.0 if (point_index + seed) % 2 == 0 else 1.0
		var branch_end := point + Vector2(2.0, side * 2.0)
		draw_line(point, branch_end, Color(1.0, 0.86, 0.22, 0.66 * alpha), maxf(0.5, pulse_core_width_px), false)
		_draw_pixel_mote(branch_end, Color(1.0, 0.92, 0.38, 0.82 * alpha))

	_draw_pixel_mote(points[points.size() - 1], Color(1.0, 0.98, 0.64, alpha))


func _make_pulse_points(start_x: float, end_x: float, seed: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var step := 4.0
	var x := start_x
	while x < end_x:
		points.append(Vector2(x, _get_pulse_y(x, seed)))
		x += step
	points.append(Vector2(end_x, _get_pulse_y(end_x, seed)))
	return points


func _get_pulse_y(x: float, seed: int) -> float:
	var jitter := maxf(0.0, pulse_jitter_px)
	if jitter <= 0.0:
		return 0.0
	var wave := sin(x * 0.58 + float(seed) * 1.73 + pulse_time * 18.0)
	var snap := roundf(wave * jitter)
	return clampf(snap, -jitter, jitter)


func _draw_pixel_mote(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), color, true)
