@tool
extends Node2D

@export var preview_emitting := true
@export var auto_restart_preview := true
@export var preview_interval := 1.35
@export var one_shot_duration := 2.0

const EFFECT_Z_INDEX := 4095

var particle_layers: Array[GPUParticles2D] = []
var preview_timer := 0.0
var one_shot_timer := 0.0
var one_shot := false


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	collect_particle_layers()
	set_process(true)

	if preview_emitting:
		restart()


func start() -> void:
	preview_emitting = true
	one_shot = false
	restart()


func stop() -> void:
	preview_emitting = false
	one_shot = false
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = false


func play_once() -> void:
	preview_emitting = false
	auto_restart_preview = false
	one_shot = true
	restart()


func restart() -> void:
	if particle_layers.is_empty():
		collect_particle_layers()

	preview_timer = preview_interval
	one_shot_timer = 0.0
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = false
		layer.restart()
		layer.emitting = true

	set_process(true)


func collect_particle_layers() -> void:
	particle_layers.clear()
	_collect_particle_layers_recursive(self)

	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)
		layer.emitting = false


func _collect_particle_layers_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles2D:
			particle_layers.append(child)
		_collect_particle_layers_recursive(child)


func _process(delta: float) -> void:
	if one_shot:
		one_shot_timer += delta
		if one_shot_timer >= one_shot_duration:
			queue_free()
		return

	if not Engine.is_editor_hint():
		return

	if not preview_emitting or not auto_restart_preview:
		return

	preview_timer -= delta
	if preview_timer <= 0.0:
		restart()
