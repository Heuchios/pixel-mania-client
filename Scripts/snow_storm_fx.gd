extends Node2D

@export var start_emitting := false
@export var follow_view := true
@export var spawn_margin := 96.0
@export var min_emission_width := 640.0

const SNOW_Z_INDEX := 4089
const EMISSION_HEIGHT := 28.0

var emitting := false
var particle_layers: Array[GPUParticles2D] = []


func _ready():
	z_as_relative = false
	z_index = SNOW_Z_INDEX
	collect_particle_layers()
	set_emitting(start_emitting)
	set_process(true)


func start():
	set_emitting(true)


func stop():
	set_emitting(false)


func set_emitting(active: bool):
	emitting = active
	visible = active
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = active


func clear():
	set_emitting(false)
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.restart()
		layer.emitting = false


func _process(_delta: float):
	if not _is_world_active():
		clear()
		return

	if follow_view:
		update_emitters_for_view()


func collect_particle_layers():
	particle_layers.clear()
	_collect_particle_layers_recursive(self)

	for layer in particle_layers:
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)
		layer.emitting = false


func _collect_particle_layers_recursive(node: Node):
	for child in node.get_children():
		if child is GPUParticles2D:
			particle_layers.append(child)
		_collect_particle_layers_recursive(child)


func update_emitters_for_view():
	var view_rect = _get_visible_world_rect()
	var view_center_x = view_rect.position.x + view_rect.size.x * 0.5
	var emitter_y = view_rect.position.y - spawn_margin * 0.35
	var emission_width = max(min_emission_width, view_rect.size.x + spawn_margin * 2.0)

	global_position = Vector2(view_center_x, emitter_y)

	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue

		var particle_material = layer.process_material
		if particle_material is ParticleProcessMaterial:
			particle_material.emission_box_extents = Vector3(emission_width * 0.5, EMISSION_HEIGHT, 0.0)


func _get_visible_world_rect() -> Rect2:
	var viewport_rect = get_viewport_rect()
	var inverse_canvas = get_viewport().get_canvas_transform().affine_inverse()
	var top_left = inverse_canvas * viewport_rect.position
	var bottom_right = inverse_canvas * (viewport_rect.position + viewport_rect.size)
	var left = min(top_left.x, bottom_right.x)
	var top = min(top_left.y, bottom_right.y)
	var right = max(top_left.x, bottom_right.x)
	var bottom = max(top_left.y, bottom_right.y)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _is_world_active() -> bool:
	var parent = get_parent()
	if parent != null and "in_world" in parent:
		return bool(parent.in_world)

	return true
