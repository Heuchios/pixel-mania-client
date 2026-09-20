extends SceneTree

class RecordingBoard extends "res://Scripts/ui/quest_board_ui.gd":
	var captured: Dictionary = {}
	func _request(action: String, data: Dictionary = {}) -> void:
		captured = {"action": action, "data": data.duplicate(true)}

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := find_button(child, caption)
		if found != null:
			return found
	return null

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
	panel.set_script(RecordingBoard)
	root.add_child(panel)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_board_snapshot.json"))
	panel.load_snapshot(fixture)
	panel.show()
	await create_timer(0.5).timeout
	assert(panel.is_quest_board_open())
	assert(panel.content.get_child_count() > 0)
	assert(panel.get_node_or_null("Panel/Margin/Layout/Tabs/Storybook") == null)
	assert(panel.get_node_or_null("Panel/Margin/Layout/Tabs/Rewards") == null)
	assert(panel.title.get_theme_color("font_shadow_color").a == 0.0)
	assert(panel.title.get_theme_constant("outline_size") == 0)
	for tab in ["storybook", "rewards", "today"]:
		panel._change_tab(tab)
		await process_frame
		assert(panel.content.get_child_count() > 0)
	for tier in ["favor_0", "trip_0"]:
		var active_fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_active_%s.json" % tier))
		panel.load_snapshot(active_fixture)
		panel._select_active(tier)
		await process_frame
		assert(panel.selected_tier == tier)
		assert(panel.content.get_child_count() > 0)
		panel._clear_answer()
		if tier != "story":
			panel._change_tab("today")
			assert(find_button(panel.content, "NOT COMPLETE").disabled)
			assert(find_button(panel.content, "CLAIM REWARD") == null)
			active_fixture.active[tier].solved = true
			panel.load_snapshot(active_fixture)
			find_button(panel.content, "CLAIM REWARD").pressed.emit()
			assert(panel.captured.action == "quest_choose")
			assert(panel.captured.data.instance_id == active_fixture.active[tier].id)
			assert(panel.captured.data.tier == tier)
	var archive_fixture = JSON.parse_string(FileAccess.get_file_as_string("D:/Pixelmania/PixelMania/PixelManiaServer/test-output/quest_archive.json"))
	panel.load_snapshot(archive_fixture)
	panel._change_tab("storybook")
	assert(panel.current_tab == "today")
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
