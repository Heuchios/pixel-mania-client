extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1440,1000)
	var ui = load("res://Scenes/ui/leaderboard/LeaderboardScene.tscn").instantiate()
	root.add_child(ui)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-updated.png")
	ui.show_sample_data_when_empty = false
	ui.set_entries_from_dictionaries([])
	ui.subtitle_text = "No scores yet — be the first to race!"
	ui.set_personal_summary("--",0,"10D 23H 24M")
	root.size = Vector2i(800,600)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-empty.png")
	ui.free()
	quit()
