@tool
extends Node2D

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_apply_emitter_state()
		if is_inside_tree():
			set_process(_is_active())
			queue_redraw()

@export var auto_preview_splash := true:
	set(value):
		auto_preview_splash = value
		_apply_emitter_state()
		if is_inside_tree():
			queue_redraw()

@export_range(24.0, 520.0, 1.0) var beam_length_px := 220.0:
	set(value):
		beam_length_px = value
		_apply_beam_length()
		if is_inside_tree():
			queue_redraw()

@export_range(4.0, 32.0, 0.5) var beam_width := 13.0
@export_range(0.0, 14.0, 0.1) var wave_strength := 4.6
@export_range(0.1, 24.0, 0.1) var wave_speed := 8.0
@export var splash_interval := 0.12
@export var loop_in_game := false:
	set(value):
		loop_in_game = value
		_apply_emitter_state()
		if is_inside_tree():
			set_process(_is_active())
			queue_redraw()
@export var one_shot_duration := 0.95

const EFFECT_Z_INDEX := 4092

var source_layers: Array[GPUParticles2D] = []
var stream_layers: Array[GPUParticles2D] = []
var impact_layers: Array[GPUParticles2D] = []

var _time := 0.0
var _splash_timer := 0.0
var _impact_pulse_age := 999.0
var _one_shot := false
var _one_shot_timer := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	_collect_emitters()
	_apply_beam_length()
	_apply_emitter_state()
	set_process(true)


func start() -> void:
	preview_emitting = true
	_one_shot = false
	_one_shot_timer = 0.0
	_apply_emitter_state()
	set_process(true)


func stop() -> void:
	preview_emitting = false
	loop_in_game = false
	_one_shot = false
	_one_shot_timer = 0.0
	_apply_emitter_state()
	set_process(false)
	queue_redraw()


func play_once() -> void:
	preview_emitting = false
	loop_in_game = false
	_one_shot = true
	_one_shot_timer = 0.0
	_apply_emitter_state()
	trigger_impact_splash()
	set_process(true)


func set_beam_length(length_px: float) -> void:
	beam_length_px = clampf(length_px, 24.0, 520.0)
	_apply_beam_length()


func set_target_offset(offset: Vector2) -> void:
	if offset.length_squared() < 4.0:
		return
	beam_length_px = clampf(offset.length(), 24.0, 520.0)
	rotation = offset.angle()
	_apply_beam_length()


func trigger_impact_splash() -> void:
	_impact_pulse_age = 0.0
	for emitter in impact_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func _collect_emitters() -> void:
	source_layers.clear()
	stream_layers.clear()
	impact_layers.clear()

	for child in get_children():
		if not (child is GPUParticles2D):
			continue
		var emitter := child as GPUParticles2D
		var clean_name := emitter.name.to_lower()
		if clean_name.contains("source"):
			source_layers.append(emitter)
		elif clean_name.contains("impact") or clean_name.contains("splash"):
			impact_layers.append(emitter)
		else:
			stream_layers.append(emitter)

		if emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate(true)
		emitter.emitting = false


func _apply_emitter_state() -> void:
	if not is_inside_tree():
		return

	var active := _is_active()
	_set_emitters(source_layers, active)
	_set_emitters(stream_layers, active)
	_set_emitters(impact_layers, active and auto_preview_splash)


func _apply_beam_length() -> void:
	if not is_inside_tree():
		return

	var length := clampf(beam_length_px, 24.0, 520.0)
	for emitter in stream_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.position = Vector2(length * 0.5, 0.0)
		emitter.visibility_rect = Rect2(-length * 0.55, -24, length * 1.1, 48)
		var material := emitter.process_material
		if material is ParticleProcessMaterial:
			var extents: Vector3 = material.emission_box_extents
			material.emission_box_extents = Vector3(maxf(8.0, length * 0.5), extents.y, 0.0)

	for emitter in impact_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.position = Vector2(length, 0.0)


func _set_emitters(layers: Array[GPUParticles2D], active: bool) -> void:
	for emitter in layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = active


func _process(delta: float) -> void:
	if not _is_active():
		_set_emitters(source_layers, false)
		_set_emitters(stream_layers, false)
		if _one_shot:
			queue_free()
		else:
			set_process(false)
		return

	_time += delta
	_impact_pulse_age += delta

	if _one_shot:
		_one_shot_timer += delta
		if _one_shot_timer >= one_shot_duration:
			queue_free()
			return

	if auto_preview_splash:
		_splash_timer -= delta
		if _splash_timer <= 0.0:
			trigger_impact_splash()
			_splash_timer = maxf(0.06, splash_interval)

	queue_redraw()


func _draw() -> void:
	if not _is_active():
		return

	var path := _make_beam_path(28, 0.0)
	var upper_foam := _make_beam_path(24, -beam_width * 0.36)
	var lower_foam := _make_beam_path(24, beam_width * 0.36)
	var length := clampf(beam_length_px, 24.0, 520.0)
	var core_width := maxf(2.0, beam_width)

	draw_polyline(path, Color(0.02, 0.18, 0.82, 0.20), core_width * 2.45, true)
	draw_polyline(path, Color(0.04, 0.54, 1.0, 0.36), core_width * 1.58, true)
	draw_polyline(path, Color(0.32, 0.92, 1.0, 0.76), core_width * 0.88, true)
	draw_polyline(path, Color(0.92, 1.0, 1.0, 0.88), core_width * 0.28, true)
	draw_polyline(upper_foam, Color(0.76, 1.0, 1.0, 0.44), maxf(1.0, core_width * 0.20), true)
	draw_polyline(lower_foam, Color(0.70, 0.96, 1.0, 0.34), maxf(1.0, core_width * 0.18), true)

	_draw_stream_bubbles(length)
	_draw_source_churn(path[0])
	_draw_impact_churn(path[path.size() - 1])


func _make_beam_path(segments: int, offset_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var safe_segments := maxi(3, segments)
	var length := clampf(beam_length_px, 24.0, 520.0)
	for i in range(safe_segments + 1):
		var t := float(i) / float(safe_segments)
		var taper := sin(t * PI)
		var wave_a := sin(t * TAU * 2.2 + _time * wave_speed) * wave_strength * taper
		var wave_b := sin(t * TAU * 5.1 - _time * wave_speed * 0.64) * wave_strength * 0.34 * taper
		result.append(Vector2(t * length, offset_y + wave_a + wave_b))
	return result


func _draw_stream_bubbles(length: float) -> void:
	for i in range(9):
		var t := fmod(_time * (0.38 + float(i) * 0.018) + float(i) * 0.137, 1.0)
		var y := sin(t * TAU * 3.0 + float(i)) * beam_width * 0.34
		var radius := 0.9 + fmod(float(i) * 0.47, 1.6)
		var alpha := 0.16 + 0.14 * sin(t * PI)
		draw_circle(Vector2(length * t, y), radius, Color(0.82, 1.0, 1.0, alpha))


func _draw_source_churn(origin: Vector2) -> void:
	var pulse := 0.5 + sin(_time * 18.0) * 0.5
	draw_circle(origin, beam_width * (0.55 + pulse * 0.08), Color(0.16, 0.74, 1.0, 0.20))
	draw_circle(origin, beam_width * 0.24, Color(0.92, 1.0, 1.0, 0.70))


func _draw_impact_churn(end: Vector2) -> void:
	var progress := clampf(_impact_pulse_age / 0.18, 0.0, 1.0)
	var alpha := (1.0 - progress) * 0.58
	var radius := lerpf(beam_width * 0.45, beam_width * 1.32, progress)
	draw_circle(end, beam_width * 0.55, Color(0.62, 0.98, 1.0, 0.28))
	if alpha <= 0.0:
		return

	draw_circle(end, radius, Color(0.28, 0.78, 1.0, alpha * 0.34))
	draw_arc(end, radius * 1.2, -0.65, 0.65, 18, Color(0.86, 1.0, 1.0, alpha), maxf(1.0, beam_width * 0.13), true)


func _is_active() -> bool:
	return preview_emitting or loop_in_game or _one_shot
