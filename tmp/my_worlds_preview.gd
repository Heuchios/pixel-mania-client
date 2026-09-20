extends SceneTree
func _init():
	call_deferred("run")
func run():
	root.size = Vector2i(1280, 900)
	var ui = load("res://Scenes/ui/player_profile/PlayerProfileScene.tscn").instantiate()
	root.add_child(ui)
	ui.build_menu()
	ui.locked_worlds_blocker.show()
	ui.locked_worlds_panel.show()
	ui.locked_worlds_empty_label.hide()
	ui.locked_worlds_rows_root.custom_minimum_size = Vector2(0, 614)
	var names = ["TEST", "FARM", "OIL", "SHOWCASE", "A_VERY_LONG_WORLD_NAME", "HOME"]
	for i in range(names.size()):
		ui.create_locked_world_row({"world_name":names[i], "current":i==0, "public_build":i==1, "access_count":4, "lock_grid_x":30, "lock_grid_y":63}, Vector2(0,i*100))
	ui.position_locked_worlds_panel(ui.get_viewport_rect().size)
	ui.locked_worlds_panel.get_node("WorldCount").text = "6 WORLDS"
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/my-worlds-updated.png")
	root.size = Vector2i(800,600)
	root.content_scale_size = Vector2i(800,600)
	await process_frame
	ui.position_locked_worlds_panel(ui.get_viewport_rect().size)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/my-worlds-compact.png")
	ui.free()
	quit()
