extends Node2D

signal fade_finished(mode: String)

@export var target_path: NodePath = NodePath("../PlayerVisual")
@export var enter_duration := 0.44
@export var exit_duration := 0.34
@export var enter_glow_alpha := 0.28
@export var exit_glow_alpha := 0.22
@export var auto_free_after_play := true

var target_visual: CanvasItem = null
var active_tween: Tween = null
var final_alpha := 1.0
var finished := false
var composite: CanvasGroup
const BASE_ALPHA_META := &"world_fade_base_alpha"


func _ready() -> void:
	z_as_relative = true
	_set_glow_alpha(0.0)


func _process(_delta: float) -> void:
	if is_instance_valid(composite) and is_instance_valid(target_visual):
		composite.transform = target_visual.transform


func play_enter(target_node: Node = null) -> void:
	target_visual = resolve_target(target_node)
	final_alpha = _remember_alpha()
	_build_composite()
	_set_target_alpha(0.0)
	_set_glow_alpha(0.0)
	restart_particles("enter")
	play_fade("enter", 0.0, final_alpha, enter_glow_alpha, 0.0, enter_duration)


func play_exit(target_node: Node = null) -> void:
	target_visual = resolve_target(target_node)
	final_alpha = _remember_alpha()
	_build_composite()
	_set_glow_alpha(0.0)
	restart_particles("exit")
	play_fade("exit", get_target_alpha(final_alpha), 0.0, exit_glow_alpha, 0.0, exit_duration)


func resolve_target(target_node: Node = null) -> CanvasItem:
	if target_node is CanvasItem:
		return target_node

	if String(target_path) != "":
		var configured_target = get_node_or_null(target_path)
		if configured_target is CanvasItem:
			return configured_target

	var parent_node = get_parent()
	if parent_node != null:
		for path in ["PlayerVisual", "BodySprite", "Sprite2D"]:
			var fallback_target = parent_node.get_node_or_null(path)
			if fallback_target is CanvasItem:
				return fallback_target

	return null


func play_fade(mode: String, from_alpha: float, to_alpha: float, from_glow: float, to_glow: float, duration: float) -> void:
	if active_tween != null:
		active_tween.kill()

	finished = false
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_method(Callable(self, "_set_target_alpha"), from_alpha, to_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_method(func(progress: float): _set_glow_alpha(lerpf(0.0, from_glow, sin(progress * PI)) + to_glow), 0.0, 1.0, duration)
	active_tween.finished.connect(Callable(self, "_on_fade_tween_finished").bind(mode), CONNECT_ONE_SHOT)


func restart_particles(mode: String) -> void:
	for child in find_children("*", "GPUParticles2D", true, false):
		child.emitting = false
		child.visible = child.name == ("EnterMotes" if mode == "enter" else "ExitMotes")
		if child.visible:
			child.restart()
			child.emitting = true


func _remember_alpha() -> float:
	if not is_instance_valid(target_visual):
		return 1.0
	if not target_visual.has_meta(BASE_ALPHA_META):
		target_visual.set_meta(BASE_ALPHA_META, get_target_alpha(1.0))
	return float(target_visual.get_meta(BASE_ALPHA_META))


func cancel() -> void:
	if active_tween != null:
		active_tween.kill()
	_release_composite(final_alpha)
	_set_target_alpha(final_alpha)
	_set_glow_alpha(0.0)
	if is_instance_valid(target_visual):
		target_visual.remove_meta(BASE_ALPHA_META)
	finished = true


func _exit_tree() -> void:
	if not finished:
		cancel()


func get_target_alpha(fallback: float) -> float:
	if target_visual == null or not is_instance_valid(target_visual):
		return fallback

	return composite.self_modulate.a if is_instance_valid(composite) else clampf(target_visual.self_modulate.a if target_visual is CanvasGroup else target_visual.modulate.a, 0.0, 1.0)


func _set_target_alpha(alpha: float) -> void:
	if target_visual == null or not is_instance_valid(target_visual):
		return

	var next_modulate: Color = composite.self_modulate if is_instance_valid(composite) else (target_visual.self_modulate if target_visual is CanvasGroup else target_visual.modulate)
	next_modulate.a = clampf(alpha, 0.0, 1.0)
	if is_instance_valid(composite):
		composite.self_modulate = next_modulate
	elif target_visual is CanvasGroup:
		target_visual.self_modulate = next_modulate
	else:
		target_visual.modulate = next_modulate


func _set_glow_alpha(alpha: float) -> void:
	var glow = get_node_or_null("ArrivalGlow")
	if glow is CanvasItem:
		var next_modulate: Color = glow.modulate
		next_modulate.a = clampf(alpha, 0.0, 1.0)
		glow.modulate = next_modulate


func _on_fade_tween_finished(mode: String) -> void:
	finished = true
	_release_composite(final_alpha if mode == "enter" else 0.0)
	_set_glow_alpha(0.0)
	if mode == "enter" and is_instance_valid(target_visual):
		target_visual.remove_meta(BASE_ALPHA_META)
	if mode == "enter":
		_set_target_alpha(final_alpha)
	elif mode == "exit":
		_set_target_alpha(0.0)

	fade_finished.emit(mode)
	if auto_free_after_play:
		queue_free()


func _build_composite() -> void:
	if not target_visual is Node2D or target_visual is Sprite2D or target_visual is CanvasGroup:
		return
	if is_instance_valid(composite):
		_release_composite(final_alpha)
	# Flatten a visual-only copy in painter order. CanvasGroup cannot composite
	# descendants with nonzero Z; original outfit hierarchy stays untouched.
	composite = CanvasGroup.new()
	get_parent().add_child(composite)
	composite.transform = target_visual.transform
	composite.z_index = target_visual.z_index
	var layers: Array[Dictionary] = []
	_collect_layers(target_visual, target_visual.z_index, layers)
	layers.sort_custom(func(a, b): return a.z < b.z if a.z != b.z else a.order < b.order)
	for entry in layers:
		var source: Node2D = entry.node
		var copy: Node2D = source.duplicate(0)
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
		copy.set_script(null)
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		copy.z_index = 0
		copy.z_as_relative = true
		copy.show_behind_parent = false
		composite.add_child(copy)
		copy.transform = target_visual.global_transform.affine_inverse() * source.global_transform
	target_visual.modulate.a = 0.0
	composite.self_modulate = Color(target_visual.modulate, final_alpha)


func _collect_layers(node: Node, inherited_z: int, layers: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		var depth := inherited_z
		if child is Node2D:
			depth = child.z_index + (inherited_z if child.z_as_relative else 0)
			if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D:
				layers.append({"node":child, "z":depth, "order":layers.size()})
		_collect_layers(child, depth, layers)


func _release_composite(alpha: float) -> void:
	if not is_instance_valid(composite):
		return
	composite.queue_free()
	composite.hide()
	composite = null
	if is_instance_valid(target_visual):
		target_visual.modulate.a = alpha
