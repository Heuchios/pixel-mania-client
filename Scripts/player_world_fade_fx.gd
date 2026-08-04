extends Node2D

signal fade_finished(mode: String)

@export var target_path: NodePath = NodePath("../PlayerVisual")
@export var enter_duration := 0.46
@export var exit_duration := 0.36
@export var enter_glow_alpha := 0.72
@export var exit_glow_alpha := 0.58
@export var auto_free_after_play := true

var target_visual: CanvasItem = null
var active_tween: Tween = null
var final_alpha := 1.0


func _ready() -> void:
	z_as_relative = true
	_set_glow_alpha(0.0)


func play_enter(target_node: Node = null) -> void:
	target_visual = resolve_target(target_node)
	final_alpha = get_target_alpha(1.0)
	_set_target_alpha(0.0)
	_set_glow_alpha(enter_glow_alpha)
	restart_particles()
	play_fade("enter", 0.0, final_alpha, enter_glow_alpha, 0.0, enter_duration)


func play_exit(target_node: Node = null) -> void:
	target_visual = resolve_target(target_node)
	final_alpha = get_target_alpha(1.0)
	_set_glow_alpha(exit_glow_alpha * 0.55)
	restart_particles()
	play_fade("exit", final_alpha, 0.0, exit_glow_alpha, 0.0, exit_duration)


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

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_method(Callable(self, "_set_target_alpha"), from_alpha, to_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_method(Callable(self, "_set_glow_alpha"), from_glow, to_glow, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.finished.connect(Callable(self, "_on_fade_tween_finished").bind(mode), CONNECT_ONE_SHOT)


func restart_particles() -> void:
	for child in find_children("*", "GPUParticles2D", true, false):
		if child is GPUParticles2D:
			child.emitting = false
			child.restart()
			child.emitting = true


func get_target_alpha(fallback: float) -> float:
	if target_visual == null or not is_instance_valid(target_visual):
		return fallback

	return clampf(target_visual.modulate.a, 0.0, 1.0)


func _set_target_alpha(alpha: float) -> void:
	if target_visual == null or not is_instance_valid(target_visual):
		return

	var next_modulate: Color = target_visual.modulate
	next_modulate.a = clampf(alpha, 0.0, 1.0)
	target_visual.modulate = next_modulate


func _set_glow_alpha(alpha: float) -> void:
	var glow = get_node_or_null("ArrivalGlow")
	if glow is CanvasItem:
		var next_modulate: Color = glow.modulate
		next_modulate.a = clampf(alpha, 0.0, 1.0)
		glow.modulate = next_modulate


func _on_fade_tween_finished(mode: String) -> void:
	if mode == "enter":
		_set_target_alpha(final_alpha)
	elif mode == "exit":
		_set_target_alpha(0.0)

	fade_finished.emit(mode)
	if auto_free_after_play:
		queue_free()
