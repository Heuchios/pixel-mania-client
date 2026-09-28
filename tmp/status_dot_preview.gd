extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var dot = load("res://Scripts/ui/server_status_dot.gd").new()
	dot.size = Vector2(20, 20)
	root.add_child(dot)
	dot.set_online(true)
	await create_timer(0.1).timeout
	assert(dot._phase > 0.0 and dot.is_processing())
	var phase: float = dot._phase
	dot.set_online(true)
	assert(dot._phase == phase, "Status polling must not restart animation")
	dot.set_online(false)
	assert(not dot.is_processing() and dot._phase == 0.0)
	await process_frame
	dot.free()
	print("Status dot: pulse, repeated status polling, and offline state passed.")
	quit()
