extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for script_path in ["world.gd", "interaction_manager.gd", "input_manager.gd", "player_manager.gd", "fishing_manager.gd", "world_lock_manager.gd"]:
		var script = load("res://Scripts/" + script_path)
		assert(script != null and script.can_instantiate(), script_path + " failed to parse")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1487, 935)
	var scene = load("res://Scenes/ui/quests/QuestBoardScene.tscn")
	assert(scene != null)
	var panel = scene.instantiate()
	root.add_child(panel)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_board_snapshot.json"))
	panel.load_snapshot(fixture)
	panel.show()
	await create_timer(0.5).timeout
	assert(panel.is_quest_board_open())
	assert(panel.content.get_child_count() > 0)
	for tab in ["storybook", "rewards", "today"]:
		panel._change_tab(tab)
		await process_frame
		assert(panel.content.get_child_count() > 0)
	for tier in ["favor", "trip", "story"]:
		var active_fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_active_%s.json" % tier))
		panel.load_snapshot(active_fixture)
		panel._select_active(tier)
		await process_frame
		assert(panel.selected_tier == tier)
		assert(panel.content.get_child_count() > 0)
		panel._clear_answer()
	var archive_fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_archive.json"))
	panel.load_snapshot(archive_fixture)
	panel._change_tab("storybook")
	assert(panel.content.get_child_count() == 25)
	root.size = Vector2i(640, 360)
	await create_timer(0.2).timeout
	panel._fit()
	assert(panel.panel.size.x <= 624)
	root.size = Vector2i(1487, 935)
	panel.load_snapshot(fixture)
	panel._change_tab("today")
	panel.close_quest_board()
	assert(not panel.visible)
	panel.show()
	await create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/quest-board-implemented.png")
	print("QUEST_UI_PASS: scene, snapshot, tabs, close")
	panel.queue_free()
	quit()
