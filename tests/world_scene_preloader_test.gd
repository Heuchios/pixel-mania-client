extends SceneTree

const WorldScenePreloader = preload("res://Scripts/world_scene_preloader.gd")
const TIMEOUT_MSEC := 30000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var start_error := WorldScenePreloader.start()
	if start_error != OK:
		push_error("World scene preload failed to start: %s" % error_string(start_error))
		quit(1)
		return

	var deadline_msec := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		WorldScenePreloader.pump()
		if WorldScenePreloader.is_ready():
			var loaded_world := WorldScenePreloader.get_loaded_scene()
			var loaded_item_database := WorldScenePreloader.get_loaded_item_database_script()
			if loaded_world == null or loaded_item_database == null:
				push_error("World preloader reported ready without required resources")
				quit(1)
				return
			print(
				"[world-scene-preloader] ready progress=%.3f"
				% WorldScenePreloader.get_combined_progress()
			)
			quit(0)
			return
		await process_frame

	push_error(
		"World scene preload timed out after %d ms (error=%s progress=%.3f)"
		% [
			TIMEOUT_MSEC,
			error_string(WorldScenePreloader.get_last_error()),
			WorldScenePreloader.get_combined_progress()
		]
	)
	quit(1)
