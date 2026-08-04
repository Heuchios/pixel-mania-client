@tool
extends Node2D

@export_enum("Idle", "Moving", "Both") var preview_mode := 2:
	set(value):
		preview_mode = value
		_apply_preview_mode()

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_apply_preview_mode()

@export var rotate_with_player := true

var idle_layers: Array[GPUParticles2D] = []
var trail_layers: Array[GPUParticles2D] = []


func _ready() -> void:
	collect_layers()
	_apply_preview_mode()


func set_moving(moving: bool) -> void:
	preview_mode = 1 if moving else 0
	_apply_preview_mode()


func set_idle() -> void:
	preview_mode = 0
	_apply_preview_mode()


func set_both_preview() -> void:
	preview_mode = 2
	_apply_preview_mode()


func set_player_rotation(angle_radians: float) -> void:
	if not rotate_with_player:
		return
	rotation = angle_radians


func set_facing_direction(facing_sign: float) -> void:
	scale.x = 1.0 if facing_sign >= 0.0 else -1.0


func set_facing_right() -> void:
	scale.x = 1.0


func set_facing_left() -> void:
	scale.x = -1.0


func collect_layers() -> void:
	idle_layers.clear()
	trail_layers.clear()
	for child in get_children():
		if not (child is GPUParticles2D):
			continue
		var particle_layer := child as GPUParticles2D
		if particle_layer.name.to_lower().contains("trail"):
			trail_layers.append(particle_layer)
		else:
			idle_layers.append(particle_layer)

		if particle_layer.process_material != null:
			particle_layer.process_material = particle_layer.process_material.duplicate(true)


func _apply_preview_mode() -> void:
	if not is_inside_tree():
		return

	if idle_layers.is_empty() and trail_layers.is_empty():
		collect_layers()

	var show_idle := preview_emitting and (preview_mode == 0 or preview_mode == 2)
	var show_trail := preview_emitting and (preview_mode == 1 or preview_mode == 2)
	_set_layers_emitting(idle_layers, show_idle)
	_set_layers_emitting(trail_layers, show_trail)


func _set_layers_emitting(layers: Array[GPUParticles2D], emitting: bool) -> void:
	for layer in layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = emitting
