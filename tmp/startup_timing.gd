extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var preloader = load("res://Scripts/world_scene_preloader.gd")
	preloader.start()
	preloader.start_optional_warmup()
	var warm_start := Time.get_ticks_msec()
	while not preloader.is_fully_warmed() and Time.get_ticks_msec() - warm_start < 15000:
		preloader.pump()
		await process_frame
	print("PREWARM ", preloader.get_visual_warmup_progress())
	var scene = load("res://Scenes/main.tscn").instantiate()
	var world = scene.get_node("World")
	world.set_script(load("res://tmp/startup_timing_world.gd"))
	var started := Time.get_ticks_usec()
	root.add_child(scene)
	print("DETAIL_TIMINGS ", world.detail_timings)
	print("SETUP_TOTAL_MS ", (Time.get_ticks_usec()-started)/1000.0)
	await process_frame
	await process_frame
	scene.free()
	quit()
