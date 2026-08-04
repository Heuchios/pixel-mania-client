@tool
extends Node2D

@export_enum("Idle", "Moving", "Both") var preview_mode := 2:
	set(value):
		preview_mode = value
		apply_preview_mode()

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		apply_preview_mode()

var idle_layers: Array[GPUParticles2D] = []
var trail_layers: Array[GPUParticles2D] = []


func _ready() -> void:
	collect_layers()
	apply_preview_mode()


func set_moving(moving: bool) -> void:
	preview_mode = 1 if moving else 0
	apply_preview_mode()


func set_idle() -> void:
	preview_mode = 0
	apply_preview_mode()


func set_both_preview() -> void:
	preview_mode = 2
	apply_preview_mode()


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


func apply_preview_mode() -> void:
	if not is_inside_tree():
		return

	if idle_layers.is_empty() and trail_layers.is_empty():
		collect_layers()

	var show_idle := preview_emitting and (preview_mode == 0 or preview_mode == 2)
	var show_trail := preview_emitting and (preview_mode == 1 or preview_mode == 2)
	set_layers_emitting(idle_layers, show_idle)
	set_layers_emitting(trail_layers, show_trail)


func set_layers_emitting(layers: Array[GPUParticles2D], emitting: bool) -> void:
	for layer in layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = emitting
