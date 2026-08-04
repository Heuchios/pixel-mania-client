@tool
extends Node2D

@export var preview_emitting := true:
	set(value):
		preview_emitting = value
		_apply_preview_state()

@export_range(1.0, 420.0, 1.0) var beam_length_px := 200.0:
	set(value):
		beam_length_px = value
		_apply_beam_length()

@export var tip_spray_offset := Vector2(0.0, 0.0)
@export var auto_preview_impact := false
@export var impact_interval := 0.08
@export var impact_offset := Vector2(-6.0, 2.5)

var stream_layers: Array[GPUParticles2D] = []
var mist_layers: Array[GPUParticles2D] = []
var tip_layers: Array[GPUParticles2D] = []

var impact_timer := 0.0
var impact_nodes: Array[GPUParticles2D] = []


func _ready() -> void:
	_collect_layers()
	_apply_beam_length()
	_apply_preview_state()

	_collect_impact_nodes()
	set_process(auto_preview_impact)


func _process(delta: float) -> void:
	if not auto_preview_impact or not preview_emitting:
		return

	impact_timer -= delta
	if impact_timer <= 0.0:
		restart_tip_impact()
		impact_timer = max(impact_interval, 0.06)


func _collect_impact_nodes() -> void:
	impact_nodes.clear()
	for emitter in tip_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		impact_nodes.append(emitter)


func set_beam_length(length_px: float) -> void:
	beam_length_px = clampf(length_px, 1.0, 420.0)
	_apply_beam_length()


func set_beam_angle(angle_radians: float) -> void:
	rotation = angle_radians


func _collect_layers() -> void:
	stream_layers.clear()
	mist_layers.clear()
	tip_layers.clear()

	for child in get_children():
		if not (child is GPUParticles2D):
			continue
		var emitter := child as GPUParticles2D
		var name := emitter.name.to_lower()
		if name.contains("tip") or name.contains("splash") or name.contains("drip"):
			tip_layers.append(emitter)
		elif name.contains("mist"):
			mist_layers.append(emitter)
		else:
			stream_layers.append(emitter)

		if emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate(true)


func _apply_preview_state() -> void:
	if not is_inside_tree():
		return

	var show_stream := preview_emitting
	set_emitters(stream_layers, show_stream)
	set_emitters(mist_layers, show_stream)
	var show_impact := auto_preview_impact and preview_emitting
	set_emitters(tip_layers, show_impact)


func _apply_beam_length() -> void:
	if not is_inside_tree():
		return

	var clamped_length := clampf(beam_length_px, 1.0, 420.0)
	var length_offset := Vector2(clamped_length, 0.0) + tip_spray_offset
	for emitter in tip_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.position = length_offset + impact_offset

	for emitter in stream_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.scale = Vector2(clamped_length / 200.0, 1.0)

	for emitter in mist_layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.scale = Vector2(clamped_length / 200.0, 1.0)


func restart_tip_impact() -> void:
	for emitter in impact_nodes:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func trigger_impact_splash() -> void:
	restart_tip_impact()


func set_emitters(layers: Array[GPUParticles2D], emitting: bool) -> void:
	for emitter in layers:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = emitting
