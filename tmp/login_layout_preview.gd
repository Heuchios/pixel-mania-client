extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var ui = load("res://Scenes/ui/login/LoginScene.tscn").instantiate()
	ui.set_script(load("res://tmp/login_layout_fixture.gd"))
	root.add_child(ui)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/login-updated.png")
	ui._render_login_news([
		{"title": "Preview announcement", "date": "Sep 19", "body": "Sample text to check the larger news panel, wrapping, and spacing. Actual announcements continue to come from the news feed."},
		{"title": "Another preview", "body": "Longer updates have room to breathe and can be scrolled without covering the sign-in controls."}
	])
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/login-news-preview.png")
	root.size = Vector2i(1600, 720)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/login-wide-preview.png")
	ui.free()
	await process_frame
	quit()
