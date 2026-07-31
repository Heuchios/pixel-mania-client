extends SceneTree

const WorldScenePreloader = preload("res://Scripts/world_scene_preloader.gd")
const TIMEOUT_MSEC := 30000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	WorldScenePreloader.pause_optional_warmup()
	var started_at_msec: int = Time.get_ticks_msec()
	var scene_ready_msec: int = -1
	var item_database_ready_msec: int = -1
	var start_error := WorldScenePreloader.start()
	if start_error != OK:
		push_error("World scene preload failed to start: %s" % error_string(start_error))
		quit(1)
		return

	var deadline_msec := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		WorldScenePreloader.pump()
		var elapsed_msec: int = Time.get_ticks_msec() - started_at_msec
		if scene_ready_msec < 0 and WorldScenePreloader.get_loaded_scene() != null:
			scene_ready_msec = elapsed_msec
		if (
			item_database_ready_msec < 0
			and WorldScenePreloader.get_loaded_item_database_script() != null
		):
			item_database_ready_msec = elapsed_msec
		if WorldScenePreloader.is_ready():
			var loaded_world := WorldScenePreloader.get_loaded_scene()
			var loaded_item_database := WorldScenePreloader.get_loaded_item_database_script()
			if loaded_world == null or loaded_item_database == null:
				push_error("World preloader reported ready without required resources")
				quit(1)
				return
			if WorldScenePreloader.is_optional_warmup_started():
				push_error("Optional warmup started during critical world preload")
				quit(1)
				return
			var critical_progress := WorldScenePreloader.get_critical_progress()
			if critical_progress < 0.999:
				push_error(
					"Critical manager preload reported incomplete progress: %.3f"
					% critical_progress
				)
				quit(1)
				return
			if scene_ready_msec < 0:
				scene_ready_msec = elapsed_msec
			if item_database_ready_msec < 0:
				item_database_ready_msec = elapsed_msec
			var combined_progress: float = WorldScenePreloader.get_combined_progress()
			if combined_progress < 0.999:
				push_error(
					"Critical world preload reported incomplete progress: %.3f"
					% combined_progress
				)
				quit(1)
				return
			print(
				(
					"[world-scene-preloader] ready scene_msec=%d "
					+ "item_database_msec=%d elapsed_msec=%d progress=%.3f "
					+ "critical_progress=%.3f"
				)
				% [
					scene_ready_msec,
					item_database_ready_msec,
					elapsed_msec,
					combined_progress,
					critical_progress,
				]
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
