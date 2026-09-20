extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var ui = load("res://Scenes/ui/locks/WorldLockGUI.tscn").instantiate()
	ui.set_script(load("res://tmp/world_lock_layout_fixture.gd"))
	root.add_child(ui)
	ui.show()
	ui.window.show()
	ui.world_label.text = "World: TEST"
	ui.owner_label.text = "Owner: USO"
	ui.lock_badge.text = "LOCKED"
	ui.slot_limit_label.text = "BUILDER SLOTS: 4/50"
	ui.slot_limit_input.text = "50"
	ui.public_button.text = "PUBLIC BUILD: OFF"
	ui.hint_label.text = "Builder limit: 0–50 slots."
	ui.empty_access_label.hide()
	for username in ["CHAR", "LUCIFER", "RAYAN", "UCE"]:
		ui.create_member_row(username)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/world-lock-updated.png")
	root.size = Vector2i(1600, 720)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/world-lock-wide.png")
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/world-lock-compact.png")
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await create_timer(0.2).timeout
	assert(ui.slot_limit_input.text == "50")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/world-lock-updated.png")
	ui.free()
	await process_frame
	quit()
