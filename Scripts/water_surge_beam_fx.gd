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
@export var one_shot_duration := 0.40
@export_range(80.0, 1600.0, 10.0) var travel_speed := 680.0

const EFFECT_Z_INDEX := 4092

var source_layers: Array[GPUParticles2D] = []
var stream_layers: Array[GPUParticles2D] = []
var impact_layers: Array[GPUParticles2D] = []

var _time := 0.0
var _splash_timer := 0.0
var _impact_pulse_age := 999.0
var _one_shot := false
var _one_shot_timer := 0.0
var _front_distance := 0.0
var _tail_distance := 0.0
var _draining := false
var _cleanup_age := 0.0
var _particle_tail_lifetime := 0.0
var _source_actor: WeakRef
var _source_provider := Callable()
var _target_world_position := Vector2.ZERO
var _impact_started_at := -999.0
var _last_impact_at := -999.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	process_priority = 110 # Follow the rendered hand after animation/equipment.
	_collect_emitters()
	if preview_emitting or loop_in_game:
		_front_distance = beam_length_px
	_apply_beam_length()
	_apply_emitter_state()
	set_process(_is_active())


func start() -> void:
	preview_emitting = true
	_one_shot = false
	_one_shot_timer = 0.0
	_front_distance = 0.0
	_tail_distance = 0.0
	_draining = false
	for emitter in source_layers + stream_layers + impact_layers:
		emitter.show()
	_apply_emitter_state()
	set_process(true)


func stop() -> void:
	preview_emitting = false
	loop_in_game = false
	_one_shot = false
	_one_shot_timer = 0.0
	_front_distance = 0.0
	_tail_distance = 0.0
	for emitter in source_layers + stream_layers + impact_layers:
		emitter.hide()
	_apply_emitter_state()
	set_process(false)
	queue_redraw()


func play_once() -> void:
	preview_emitting = false
	loop_in_game = false
	_one_shot = true
	_one_shot_timer = 0.0
	_front_distance = 0.0
	_tail_distance = 0.0
	_draining = false
	_cleanup_age = 0.0
	_impact_pulse_age = 999.0
	_impact_started_at = -999.0
	_last_impact_at = -999.0
	for emitter in source_layers + stream_layers + impact_layers:
		emitter.show()
	_apply_emitter_state()
	set_process(true)
	queue_redraw()


func can_refresh() -> bool:
	return _one_shot and not _draining


func refresh_jet(start_world: Vector2, target_world: Vector2, actor: Node2D = null, provider: Callable = Callable()) -> void:
	_target_world_position = target_world
	_source_actor = weakref(actor) if is_instance_valid(actor) else null
	_source_provider = provider
	_set_world_endpoints(start_world, target_world)
	if not _one_shot:
		play_once()
	# Refresh the firing lease, never the phase, travel front or emitter clocks.
	_one_shot_timer = 0.0
	set_process(true)


func finish() -> void:
	_draining = true
	preview_emitting = false
	loop_in_game = false
	_apply_emitter_state()


func _set_world_endpoints(start_world: Vector2, target_world: Vector2) -> void:
	global_position = start_world
	var offset: Vector2 = get_parent().to_local(target_world) - position
	set_target_offset(offset)


func _follow_source() -> bool:
	if _source_actor == null or _draining:
		return true
	var actor = _source_actor.get_ref()
	if not is_instance_valid(actor) or not actor.is_visible_in_tree():
		finish()
		return true
	if _source_provider.is_valid():
		var origin: Vector2 = _source_provider.call()
		if not origin.is_finite():
			finish()
		elif origin.distance_squared_to(global_position) > 128.0 * 128.0:
			stop()
			queue_free()
			return false
		else:
			_set_world_endpoints(origin, _target_world_position)
	return true


func set_beam_length(length_px: float) -> void:
	beam_length_px = clampf(length_px, 2.0, 520.0)
	_apply_beam_length()


func set_target_offset(offset: Vector2) -> void:
	if not offset.is_finite():
		return
	beam_length_px = clampf(offset.length(), 2.0, 520.0)
	rotation = offset.angle()
	_apply_beam_length()


func trigger_impact_splash() -> void:
	_impact_pulse_age = 0.0
	# Continuous splashing must not restart a full particle burst every few frames.
	_set_emitters(impact_layers, _has_impact() and auto_preview_splash)


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
		_particle_tail_lifetime = maxf(_particle_tail_lifetime, emitter.lifetime + 0.06)


func _apply_emitter_state() -> void:
	if not is_inside_tree():
		return

	var active := _is_active()
	_set_emitters(source_layers, active and not _draining)
	_set_emitters(stream_layers, active and _front_distance - _tail_distance > 1.0)
	_set_emitters(impact_layers, active and _has_impact() and auto_preview_splash)


func _apply_beam_length() -> void:
	if not is_inside_tree():
		return

	var length := clampf(beam_length_px, 2.0, 520.0)
	var tail := minf(_tail_distance, length)
	var front := clampf(_front_distance, tail, length)
	for emitter in stream_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.position = Vector2((tail + front) * 0.5, 0.0)
		emitter.visibility_rect = Rect2(-length * 0.55, -24, length * 1.1, 48)
		var material := emitter.process_material
		if material is ParticleProcessMaterial:
			var extents: Vector3 = material.emission_box_extents
			material.emission_box_extents = Vector3(maxf(0.1, (front - tail) * 0.5), extents.y, 0.0)

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
		_apply_emitter_state()
		set_process(false)
		return
	if not _follow_source():
		return

	_time += delta
	_impact_pulse_age += delta

	if _one_shot:
		_one_shot_timer += delta
		if _one_shot_timer >= one_shot_duration and not _draining:
			finish()

	_front_distance = minf(beam_length_px, _front_distance + travel_speed * delta)
	if _draining:
		_tail_distance = minf(beam_length_px, _tail_distance + travel_speed * delta)
		if _tail_distance >= beam_length_px:
			_cleanup_age += delta
			if _cleanup_age >= _particle_tail_lifetime:
				queue_free()
				return
	_apply_beam_length()
	_apply_emitter_state()

	if auto_preview_splash and _has_impact():
		if _impact_started_at < 0.0:
			_impact_started_at = _time
		_last_impact_at = _time
		_splash_timer -= delta
		if _splash_timer <= 0.0:
			trigger_impact_splash()
			_splash_timer = maxf(0.06, splash_interval)

	queue_redraw()


func _draw() -> void:
	if not _is_active():
		return
	if _front_distance - _tail_distance >= 0.1:
		var length := clampf(beam_length_px, 2.0, 520.0)
		var pressure := smoothstep(0.0, 10.0, _front_distance - _tail_distance)
		# Translucent, irregular water sheets. Highlights are separated foam
		# streaks below, rather than a solid luminous core down the whole jet.
		_draw_water_sheet(1.15, 0.0, Color(0.08, 0.38, 0.64, 0.30 * pressure))
		_draw_water_sheet(0.91, 0.15, Color(0.12, 0.67, 0.85, 0.58 * pressure))
		_draw_water_sheet(0.56, -0.20, Color(0.49, 0.87, 0.94, 0.36 * pressure))
		_draw_surface_foam(length, pressure)
		_draw_edge_droplets(length, pressure)
	if _time - _last_impact_at < 0.36:
		_draw_impact_churn(Vector2(beam_length_px, 0))


func _water_center(x: float) -> float:
	var t := clampf(x / maxf(beam_length_px, 2.0), 0.0, 1.0)
	var taper := sin(t * PI)
	return (sin(x * 0.13 - _time * wave_speed) + sin(x * 0.31 - _time * wave_speed * 1.7) * 0.22) * wave_strength * taper


func _water_radius(x: float) -> float:
	var t := clampf(x / maxf(beam_length_px, 2.0), 0.0, 1.0)
	var roughness := sin(x * 0.48 - _time * 27.0) * 0.16 + sin(x * 0.91 - _time * 41.0) * 0.10
	var end_taper := smoothstep(0.0, 4.0, x - _tail_distance + 1.0) * smoothstep(0.0, 4.0, _front_distance - x + 1.0)
	return beam_width * (0.40 + t * 0.13 + roughness) * lerpf(0.35, 1.0, end_taper)


func _draw_water_sheet(size: float, shift: float, color: Color) -> void:
	var segments := clampi(int(ceil((_front_distance - _tail_distance) / 2.5)), 3, 180)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(segments + 1):
		var x := lerpf(_tail_distance, _front_distance, float(i) / segments)
		var radius := _water_radius(x)
		var center := _water_center(x) + shift * radius
		upper.append(Vector2(x, center - radius * size))
		lower.append(Vector2(x, center + radius * size))
		var ripple := 0.82 + 0.18 * sin(x * 0.25 - _time * 19.0)
		colors.append(Color(color, color.a * ripple))
	var outline := upper
	for i in range(lower.size() - 1, -1, -1):
		outline.append(lower[i])
		colors.append(colors[i])
	draw_polygon(outline, colors)


func _make_beam_path(segments: int, offset_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(maxi(3, segments) + 1):
		var x := lerpf(_tail_distance, _front_distance, float(i) / maxi(3, segments))
		result.append(Vector2(x, _water_center(x) + offset_y))
	return result


func _draw_surface_foam(length: float, pressure: float) -> void:
	var count := clampi(int(ceil(length / 12.0)), 2, 44)
	for i in range(count):
		var x := fposmod(_time * travel_speed * 0.72 + float(i) * 12.7, length)
		if x < _tail_distance + 1.0 or x > _front_distance - 1.0:
			continue
		var streak_length := 2.0 + fposmod(float(i) * 1.73, 4.5)
		var start_x := maxf(_tail_distance, x - streak_length)
		var side := sin(float(i) * 7.31 + _time * 1.3) * 0.70
		var points := PackedVector2Array()
		for step in range(4):
			var px := lerpf(start_x, x, float(step) / 3.0)
			points.append(Vector2(px, _water_center(px) + _water_radius(px) * side))
		var alpha := (0.35 + 0.25 * pow(sin(float(i) + _time * 4.0), 2.0)) * pressure
		draw_polyline(points, Color(0.84, 0.97, 1.0, alpha), 0.65, true)
		if i % 3 == 0:
			draw_circle(points[3], 0.7, Color(0.91, 0.99, 1.0, alpha * 0.8))


func _draw_edge_droplets(length: float, pressure: float) -> void:
	for i in range(16):
		var age := fposmod(_time + float(i) * 0.073, 0.30)
		var launch_x := fposmod(float(i) * 0.618, 1.0) * length
		var x := launch_x + age * 45.0
		if x <= _tail_distance or x >= _front_distance:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := _water_radius(x) + age * (8.0 + float(i % 4) * 3.0)
		var point := Vector2(x, _water_center(x) + side * offset)
		var gravity := Vector2.DOWN.rotated(-global_rotation) * age * age * 24.0
		point += gravity
		var alpha := (1.0 - smoothstep(0.10, 0.30, age)) * pressure
		var velocity := Vector2(45.0, side * 14.0) + gravity * 8.0
		_draw_drop(point, velocity.normalized(), 0.55 + float(i % 3) * 0.16, alpha * 0.72)


func _draw_drop(point: Vector2, direction: Vector2, size: float, alpha: float) -> void:
	draw_line(point - direction * size * 1.7, point, Color(0.27, 0.72, 0.90, alpha * 0.75), size * 1.4, true)
	draw_line(point - direction * size * 0.7, point, Color(0.82, 0.97, 1.0, alpha), size * 0.7, true)


func _draw_impact_churn(end: Vector2) -> void:
	# A small fan of ballistic droplets reads as a water collision, not a flash.
	var elapsed := _time - _impact_started_at
	for i in range(18):
		var lifetime := 0.24 + float(i % 5) * 0.025
		var age := fposmod(elapsed + float(i) * 0.037, lifetime)
		if age > elapsed or _time - age > _last_impact_at:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var velocity := Vector2(-12.0 - float(i % 6) * 7.0, side * (22.0 + float(i % 5) * 10.0))
		var gravity := Vector2.DOWN.rotated(-global_rotation) * 105.0
		var point := end + velocity * age + gravity * age * age * 0.5
		var alpha := 1.0 - smoothstep(lifetime * 0.35, lifetime, age)
		_draw_drop(point, (velocity + gravity * age).normalized(), 0.65 + float(i % 3) * 0.25, alpha * 0.9)


func _is_active() -> bool:
	return preview_emitting or loop_in_game or _one_shot


func _has_impact() -> bool:
	return _front_distance >= beam_length_px and _tail_distance < beam_length_px
