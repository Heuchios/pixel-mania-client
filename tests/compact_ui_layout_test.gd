extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(640, 360)
	for scene in ["inventory/InventoryScene", "locks/WorldLockGUI"]:
		var ui = load("res://Scenes/ui/" + scene + ".tscn").instantiate()
		root.add_child(ui)
		ui.show()
		ui.window.show()
		if scene.begins_with("inventory"):
			ui.set_inventory_items([{"id":"long_count", "display_name":"A very long item name to check truncation", "category":"block", "count":1280}])
		await create_timer(0.4).timeout
		assert(ui.window.scale == Vector2.ONE, "Compact window must not shrink text")
		assert(Rect2(Vector2.ZERO, Vector2(640,360)).encloses(ui.window.get_global_rect()))
		if scene.begins_with("inventory"):
			assert(ui.inventory_grid.columns <= 4)
			assert(ui.inventory_grid.get_combined_minimum_size().x <= ui.inventory_scroll.size.x)
		else:
			assert(ui._compact_scroll.visible)
			assert(ui.add_button.pressed.is_connected(ui._on_add_access_pressed))
		if "--render" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("D:/Pixelmania/atlas-ui-tools/compact-" + scene.get_file() + ".png")
		root.size = Vector2i(1920,1080)
		await create_timer(0.2).timeout
		if scene.begins_with("inventory"):
			assert(ui.inventory_grid.columns == ui.slot_columns)
		else:
			assert(ui.world_label.get_parent() == ui.window)
		ui.queue_free()
		await process_frame
		root.size = Vector2i(640,360)
	print("[compact-ui-layout] passed")
	quit()
