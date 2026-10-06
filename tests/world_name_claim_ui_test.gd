extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var ui = load("res://Scenes/ui/locks/WorldLockGUI.tscn").instantiate()
	root.add_child(ui)
	ui.visible = true
	ui.window.visible = true
	ui.world_label.text = "World: SHOP"
	ui.owner_label.text = "Owner: ALICE"
	ui.receive_name_status({"name":"SHOP", "status":"claimed", "original_paid_gems":750000})
	await process_frame
	assert(ui._name_label.text.contains("750,000 gems (server verified)"))
	assert(ui._name_label.text.contains("Permanently claimed"))
	assert(not ui._name_button.visible, "Visitors must not see payment controls")
	assert(ui._name_label.get_global_rect().size.x <= ui._name_card.get_global_rect().size.x)
	assert(ui.window.get_global_rect().encloses(ui._name_card.get_global_rect()))
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-name-claim-desktop.png")
	ui._name_can_manage = true
	ui.receive_name_status({"name":"SHOP", "status":"reserved", "quoted_gems":750000,"original_paid_gems":null,"expires_at":"2026-10-20T18:00:00.000Z"})
	assert(ui._name_label.text.contains("Original claim paid: Not paid"))
	assert(ui._name_label.text.contains("750,000 gems by 2026-10-20 18:00:00 UTC"))
	assert(ui._name_button.visible and not ui._name_button.disabled)
	assert(not ui._name_input.visible)
	root.size = Vector2i(430, 780)
	await process_frame
	ui._fit_window_to_viewport()
	await process_frame
	assert(ui._name_card.get_parent() == ui._compact_body)
	assert(ui._name_card.position.y + ui._name_card.size.y <= ui._compact_body.custom_minimum_size.y)
	assert(ui._name_label.size.x <= ui._name_card.size.x)
	ui._compact_scroll.scroll_vertical = 9999
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-name-claim-mobile.png")
	ui.receive_name_status({"name":"WAUTO", "status":"generated", "original_paid_gems":null})
	assert(ui._name_input.visible)
	assert(ui._name_button.text == "RESERVE NAME")
	root.size = Vector2i(1280,960)
	await process_frame
	ui._fit_window_to_viewport()
	await process_frame
	assert(ui._name_card.get_parent() == ui.window)
	await create_timer(0.05).timeout
	assert(ui.window.get_global_rect().encloses(ui._name_card.get_global_rect()))
	ui.queue_free()
	await process_frame
	print("WORLD_NAME_CLAIM_UI_TEST_OK")
	quit()
