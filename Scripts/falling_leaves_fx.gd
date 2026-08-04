@tool
extends Node2D

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_set_emitting(preview_emitting)

@export var follow_view := true
@export var spawn_margin := 96.0
@export var min_emission_width := 680.0
@export var wall_mode := true
@export var wall_emission_width := 340.0
@export var sway_enabled := true
@export_range(0.05, 3.0, 0.01) var sway_cycle_seconds := 5.5
@export_range(0.0, 18.0, 0.1) var sway_strength := 8.0

const LEAVES_Z_INDEX := 4315
const EMISSION_HEIGHT := 24.0

var leaf_layers: Array[GPUParticles2D] = []
var _layer_motion_data: Array[Dictionary] = []
var _sway_time := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = LEAVES_Z_INDEX
	_collect_layers(self)

	for index in range(leaf_layers.size()):
		var layer := leaf_layers[index]
		if layer == null or not is_instance_valid(layer):
			continue
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)
		layer.emitting = false

			var material := layer.process_material
			if material is ParticleProcessMaterial:
				var base_gravity: Vector3 = material.gravity
			_layer_motion_data.append({
				"layer": layer,
				"material": material,
				"phase": index * 0.75,
				"base_gravity": base_gravity,
				"speed_mult": 0.75 + index * 0.22,
			})

	_set_emitting(preview_emitting)
	set_process(follow_view or sway_enabled)
	if follow_view:
		_update_emitters_for_view()

func _process(delta: float) -> void:
	_sway_time += delta
	if follow_view:
		_update_emitters_for_view()
	_update_leaf_wall_sway(delta)


func _collect_layers(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles2D:
			leaf_layers.append(child)
		_collect_layers(child)


func _set_emitting(active: bool) -> void:
	for layer in leaf_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = active


func update_emitting(active: bool) -> void:
	preview_emitting = active
	_set_emitting(active)


func _update_emitters_for_view() -> void:
	var view_rect: Rect2 = _get_visible_world_rect()
	var width: float = wall_emission_width
	if not wall_mode:
		width = maxf(min_emission_width, view_rect.size.x + spawn_margin * 2.0)
	var top_offset: float = view_rect.position.y - 36.0
	global_position = Vector2(view_rect.position.x + view_rect.size.x * 0.5, top_offset)

	for layer in leaf_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		var material := layer.process_material
		if material is ParticleProcessMaterial:
			material.emission_box_extents = Vector3(width * 0.5, EMISSION_HEIGHT, 0.0)
			if wall_mode:
				material.damping_min = maxf(material.damping_min, 0.08)
				material.damping_max = maxf(material.damping_max, material.damping_min)


func _update_leaf_wall_sway(_delta: float) -> void:
	if not sway_enabled or not wall_mode:
		return
	if _layer_motion_data.is_empty():
		return
	if sway_cycle_seconds <= 0.0:
		return

	var base_cycle := TAU / sway_cycle_seconds
	for data in _layer_motion_data:
		var material_value: Variant = data.get("material", null)
		if not (material_value is ParticleProcessMaterial):
			continue
		var material: ParticleProcessMaterial = material_value
		if material == null or not is_instance_valid(material):
			continue
		var phase := float(data.get("phase", 0.0))
		var speed_mult := float(data.get("speed_mult", 1.0))
		var base_gravity_value: Variant = data.get("base_gravity", Vector3.ZERO)
		var base_gravity: Vector3 = base_gravity_value if base_gravity_value is Vector3 else Vector3.ZERO
		var sway := sin(_sway_time * base_cycle + phase) * sway_strength * speed_mult
		material.gravity = Vector3(
			base_gravity.x + sway,
			base_gravity.y,
			base_gravity.z
		)


func _get_visible_world_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport_rect()
	var inverse_canvas: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inverse_canvas * viewport_rect.position
	var bottom_right: Vector2 = inverse_canvas * (viewport_rect.position + viewport_rect.size)
	var left: float = minf(top_left.x, bottom_right.x)
	var top: float = minf(top_left.y, bottom_right.y)
	var right: float = maxf(top_left.x, bottom_right.x)
	var bottom: float = maxf(top_left.y, bottom_right.y)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
