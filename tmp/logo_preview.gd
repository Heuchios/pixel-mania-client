extends SceneTree
func _init():
	call_deferred("run")
func run():
	root.size = Vector2i(1920,1080)
	for config in [["login","res://Scenes/ui/login/LoginScene.tscn","res://tmp/login_layout_fixture.gd"],["lobby","res://Scenes/ui/lobby/LobbyScene.tscn","res://tests/lobby_ui_fixture.gd"],["loading","res://Scenes/ui/WorldLoadingOverlay/WorldLoadingOverlay.tscn",""]]:
		var ui = load(config[1]).instantiate()
		if config[2] != "": ui.set_script(load(config[2]))
		root.add_child(ui)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/logo-"+config[0]+".png")
		ui.free()
	quit()
