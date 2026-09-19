extends SceneTree

const Seeds = preload("res://Scripts/seed_system.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	for count in [500, 3000]:
		var seeds = Seeds.new()
		root.add_child(seeds)
		var texture := GradientTexture2D.new()
		texture.width = 32
		texture.height = 32
		seeds.seed_tree_textures = {"dirt": [texture, texture, texture, texture]}
		for i in range(count):
			seeds.create_planted_seed(Vector2i(i % 100, i / 100), "dirt_seed", 60.0, 60.0)
		var samples: Array[float] = []
		for i in range(20):
			var start := Time.get_ticks_usec()
			seeds.update_seed_system(0.25)
			samples.append((Time.get_ticks_usec() - start) / 1000.0)
		var start := Time.get_ticks_usec()
		seeds.update_seed_system(14.0)
		var transition_ms := (Time.get_ticks_usec() - start) / 1000.0
		var transition_frames := 1
		# Finish the current pass, then a complete pass at the new time. Check every
		# tree, so merely deferring work cannot make this benchmark appear to pass.
		while seeds.growth_work_index < seeds.growth_work.size():
			start = Time.get_ticks_usec()
			seeds.update_seed_system(0.0)
			transition_ms = maxf(transition_ms, (Time.get_ticks_usec() - start) / 1000.0)
			transition_frames += 1
		seeds.update_seed_system(0.25)
		while seeds.growth_work_index < seeds.growth_work.size():
			start = Time.get_ticks_usec()
			seeds.update_seed_system(0.0)
			transition_ms = maxf(transition_ms, (Time.get_ticks_usec() - start) / 1000.0)
			transition_frames += 1
		for tree in seeds.planted_seeds.values():
			assert(tree.stage == 1)
		start = Time.get_ticks_usec()
		for i in range(100):
			seeds.get_seed_grid_overlapping_player(Vector2i(-5, -5), Vector2(-160, -160))
		var hover_ms := (Time.get_ticks_usec() - start) / 100000.0
		samples.sort()
		print("SEED_GROWTH_PROFILE ", JSON.stringify({"trees": count, "steady_p50_ms": samples[10], "steady_max_ms": samples[-1], "transition_max_frame_ms": transition_ms, "transition_frames": transition_frames, "hover_ms": hover_ms}))
		seeds.update_seed_system(60.0)
		while seeds.growth_work_index < seeds.growth_work.size():
			seeds.update_seed_system(0.0)
		seeds.update_seed_system(0.25)
		while seeds.growth_work_index < seeds.growth_work.size():
			seeds.update_seed_system(0.0)
		assert(seeds.growing_seed_grids.is_empty(), "Mature ordinary trees leave the growth queue")
		for tree in seeds.planted_seeds.values():
			assert(tree.mature and tree.stage == 3)
		seeds.queue_free()
		await process_frame
	quit()
