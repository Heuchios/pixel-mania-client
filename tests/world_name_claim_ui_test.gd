extends SceneTree

class PreviewWorld extends RefCounted:
	var current_world_name := "TEST"
	var world_lock_manager = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 1040)
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
	assert(ui._name_label.text.contains("Claimed"))
	ui.receive_name_status({"name":"SHOP", "status":"claimed", "original_paid_gems":750000, "unlocked_until":"2026-10-20T18:00:00Z"})
	assert(ui._name_label.text.contains("Replace the World Lock before 2026-10-20 18:00:00 UTC"))
	assert(not ui._name_button.visible, "Visitors must not see payment controls")
	assert(not ui._name_input.visible, "Claimed worlds must not offer another name search")
	assert(not ui._name_search_button.is_visible_in_tree())
	assert(not ui._name_search_label.visible)
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
	assert(ui._name_input.visible)
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
	assert(ui._name_button.disabled, "Reservation requires a successful search")
	ui._name_input.text = "shop"
	ui._receive_name_quote({"name":"SHOP","price_gems":750000,"available":true,"can_reserve":true})
	assert(ui._name_search_label.text.contains("750,000 gems"))
	assert(not ui._name_button.disabled)
	ui._name_input.text = "farm"
	ui._name_input.text_changed.emit("farm")
	assert(ui._name_quote.is_empty() and ui._name_button.disabled, "Editing invalidates the old quote")
	ui._receive_name_quote({"name":"SHOP","price_gems":750000,"available":true,"can_reserve":true})
	assert(ui._name_quote.is_empty(), "Late result for an edited query must not enable reservation")
	ui._receive_name_quote({"name":"FARM","price_gems":250000,"available":false,"can_reserve":false,"reason":"This name is already in use."})
	assert(ui._name_button.disabled and ui._name_search_label.text.contains("already in use"))
	await process_frame
	ui._fit_window_to_viewport()
	await process_frame
	assert(ui._name_card.position.y + ui._name_card.size.y <= ui._compact_body.custom_minimum_size.y)
	ui.world = PreviewWorld.new()
	ui._name_input.text = "SHOP"
	ui._name_input.text_changed.emit("SHOP")
	ui._name_request_id = "search-2"
	ui._name_request_deadline = Time.get_ticks_msec() + 15000
	var response := {"action":"world_name_search","world":"TEST","request_id":"search-1","ok":true,"can_manage":true,"world_name_claim":{"name":"WAUTO","status":"generated"},"world_name_search":{"name":"SHOP","price_gems":750000,"available":true,"can_reserve":true}}
	ui.handle_inventory_transaction_result(response)
	assert(ui._name_quote.is_empty() and ui._name_request_id == "search-2", "Old responses cannot finish a newer search")
	response.request_id = "search-2"
	ui.handle_inventory_transaction_result(response)
	assert(ui._name_request_id == "" and not ui._name_button.disabled)
	await process_frame
	ui._fit_window_to_viewport()
	await process_frame
	ui._compact_scroll.scroll_vertical = 9999
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-name-search-mobile.png")
	root.size = Vector2i(1280,1040)
	await process_frame
	ui._fit_window_to_viewport()
	await process_frame
	assert(ui._name_card.get_parent() == ui.window)
	await create_timer(0.05).timeout
	assert(ui.window.get_global_rect().encloses(ui._name_card.get_global_rect()))
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-name-search-desktop.png")
	ui.queue_free()
	await process_frame
	print("WORLD_NAME_CLAIM_UI_TEST_OK")
	quit()
