extends SceneTree

func _initialize():
	_run.call_deferred()

func _run():
	root.size = Vector2i(1280, 850)
	root.content_scale_size = Vector2i(1280, 850)
	var background := ColorRect.new()
	background.color = Color("111c36")
	background.size = Vector2(1280, 850)
	root.add_child(background)
	var ui = load("res://Scenes/ui/leaderboard/LeaderboardScene.tscn").instantiate()
	root.add_child(ui)
	ui.set_personal_summary("4", 6410, "7D 02H 03M")
	await create_timer(0.35).timeout
	for row in ui._get_row_nodes():
		row.get_node("RankCup").set_process(false)
	for frame in range(5):
		for row in ui._get_row_nodes():
			var cup = row.get_node("RankCup")
			cup.frame_index = frame
			cup._update_texture()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-cups-%d.png" % frame)
	print("leaderboard_cups_preview: rendered")
	ui.free()
	quit()
