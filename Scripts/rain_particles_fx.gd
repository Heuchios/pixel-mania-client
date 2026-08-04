@tool
extends Node2D

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_set_emitting(value)

@export var follow_view := true:
	set(value):
		follow_view = value
		set_process(value and preview_emitting)

@export var spawn_margin := 128.0
@export var min_emission_width := 720.0
@export_range(1.0, 20.0, 0.5) var splash_probe_rate := 8.0

const RAIN_Z_INDEX := 4090
const EMISSION_HEIGHT := 32.0
const RAIN_BLOCK_COLLISION_MASK := 1
const RAIN_SURFACE_NORMAL_LIMIT := -0.45

var rain_layers: Array[GPUParticles2D] = []
var splash_probe_rng := RandomNumberGenerator.new()
var splash_probe_accumulator := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = RAIN_Z_INDEX
	splash_probe_rng.randomize()
	_collect_rain_layers(self)

	for layer in rain_layers:
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)
		layer.emitting = false

	_set_emitting(preview_emitting)
	set_process(follow_view and preview_emitting)
	if follow_view:
		_update_emitters_for_view()


func start() -> void:
	preview_emitting = true
	visible = true
	_set_emitting(true)
	if follow_view:
		set_process(true)


func stop() -> void:
	preview_emitting = false
	_set_emitting(false)
	visible = false
	set_process(false)


func clear() -> void:
	_set_emitting(false)
	visible = false
	set_process(false)
	for layer in rain_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.restart()
		layer.emitting = false


func set_emitting(active: bool) -> void:
	preview_emitting = active
	visible = active
	_set_emitting(active)
	set_process(follow_view and active)


func _process(_delta: float) -> void:
	_update_emitters_for_view()
	_update_splash_probes(_delta)


func _update_splash_probes(delta: float) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	var parent := get_parent()
	if parent == null or not parent.has_method("spawn_water_splash_particles"):
		return
	if "in_world" in parent and not bool(parent.in_world):
		return

	var visible_rect := _get_visible_world_rect()
	if visible_rect.size.x <= 1.0 or visible_rect.size.y <= 1.0:
		return

	var probe_interval := 1.0 / maxf(1.0, splash_probe_rate)
	splash_probe_accumulator += delta
	var probe_count := 0
	while splash_probe_accumulator >= probe_interval and probe_count < 3:
		splash_probe_accumulator -= probe_interval
		probe_count += 1
		_probe_for_rain_splash(visible_rect)

	splash_probe_accumulator = minf(splash_probe_accumulator, probe_interval)


func _probe_for_rain_splash(visible_rect: Rect2) -> void:
	var probe_x := splash_probe_rng.randf_range(visible_rect.position.x, visible_rect.end.x)
	var from_position := Vector2(
		probe_x,
		visible_rect.position.y - spawn_margin
	)
	var to_position := Vector2(
		probe_x,
		visible_rect.end.y + spawn_margin
	)
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position,
		RAIN_BLOCK_COLLISION_MASK
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var normal_value: Variant = hit.get("normal", Vector2.UP)
	var surface_normal: Vector2 = normal_value if normal_value is Vector2 else Vector2.UP
	if surface_normal.y > RAIN_SURFACE_NORMAL_LIMIT:
		return

	var collider: Variant = hit.get("collider", null)
	if collider is CharacterBody2D or collider is RigidBody2D:
		return

	var impact_position: Variant = hit.get("position", Vector2.ZERO)
	if impact_position is not Vector2:
		return

	var parent := get_parent()
	parent.spawn_water_splash_particles(impact_position, 0.34)


func _collect_rain_layers(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles2D:
			rain_layers.append(child)
		_collect_rain_layers(child)


func _set_emitting(active: bool) -> void:
	for layer in rain_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = active


func _update_emitters_for_view() -> void:
	var view_rect := _get_visible_world_rect()
	var emission_width := maxf(min_emission_width, view_rect.size.x + spawn_margin * 2.0)
	var emitter_x := view_rect.position.x + view_rect.size.x * 0.5
	var emitter_y := view_rect.position.y - spawn_margin * 0.35
	global_position = Vector2(emitter_x, emitter_y)

	var local_visibility_rect := Rect2(
		-emission_width * 0.5 - spawn_margin,
		-EMISSION_HEIGHT - spawn_margin,
		emission_width + spawn_margin * 2.0,
		view_rect.size.y + spawn_margin * 3.0
	)

	for layer in rain_layers:
		if layer == null or not is_instance_valid(layer):
			continue

		layer.visibility_rect = local_visibility_rect
		var particle_material := layer.process_material
		if particle_material is ParticleProcessMaterial:
			particle_material.emission_box_extents = Vector3(
				emission_width * 0.5,
				EMISSION_HEIGHT,
				0.0
			)


func _get_visible_world_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas * viewport_rect.position
	var bottom_right := inverse_canvas * (viewport_rect.position + viewport_rect.size)
	var left := minf(top_left.x, bottom_right.x)
	var top := minf(top_left.y, bottom_right.y)
	var right := maxf(top_left.x, bottom_right.x)
	var bottom := maxf(top_left.y, bottom_right.y)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
