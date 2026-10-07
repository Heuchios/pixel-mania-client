extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var player := Node2D.new()
	root.add_child(player)
	var visual := CanvasGroup.new()
	visual.self_modulate = Color(0.7, 0.8, 0.9, 0.8)
	player.add_child(visual)
	var scene = load("res://Scenes/particles/PlayerWorldFadeFX.tscn")
	var fx = scene.instantiate()
	fx.auto_free_after_play = false
	player.add_child(fx)
	fx.play_enter(visual)
	assert(is_zero_approx(visual.self_modulate.a))
	assert(fx.get_node("EnterMotes").visible and not fx.get_node("ExitMotes").visible)
	fx.active_tween.pause()
	fx.active_tween.custom_step(0.12)
	assert(visual.self_modulate.a > 0 and visual.self_modulate.a < 0.8)
	fx.cancel()
	assert(is_equal_approx(visual.self_modulate.a, 0.8))
	fx.play_exit(visual)
	assert(fx.get_node("ExitMotes").visible and not fx.get_node("EnterMotes").visible)
	fx.active_tween.pause()
	fx.active_tween.custom_step(0.4)
	assert(is_zero_approx(visual.self_modulate.a))
	fx.play_enter(visual)
	fx.active_tween.pause()
	fx.active_tween.custom_step(0.5)
	assert(is_equal_approx(visual.self_modulate.a, 0.8), "Re-entry must recover opacity after exit")
	assert(is_equal_approx(visual.self_modulate.r, 0.7), "Fade must preserve player tint")
	assert(fx.get_node_or_null("ArrivalGlow") == null, "No rectangular glow overlay")
	player.free()
	print("[player-fade] PASS: enter, exit, interruption, re-entry, tint and mode-specific particles")
	quit(0)

