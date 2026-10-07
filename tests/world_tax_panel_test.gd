extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1000, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var panel = load("res://Scripts/ui/world_tax_panel.gd").new()
	root.add_child(panel)
	panel.show()
	panel.info = {"enabled":true,"owned_count":5,"amount_due":1000,"current_bill_gems":1000,"next_due_at":"2026-10-20T20:00:00Z","blocked":true,
		"bills":[{"amount_gems":1000,"due_at":"2026-10-06T20:00:00Z","grace_until":"2026-10-13T20:00:00Z"}],"history":[],"worlds":["SHOP","FARM","FISH","HOME","TEST"]}
	panel.render_status()
	await process_frame
	assert(panel.summary_label.text.contains("OVERDUE"))
	assert(not panel.pay_button.disabled)
	assert(panel.details_label.text.contains("Grace ends"))
	assert(panel.details_label.text.contains("SHOP"))
	panel.pending_id = "expected"
	panel.receive_result({"request_id":"old","ok":true,"world_tax":{"enabled":false}})
	assert(panel.pending_id == "expected", "Old replies must not replace current bills")
	panel.receive_result({"request_id":"expected","ok":false,"message":"Not enough gems"})
	assert(panel.pay_button.disabled)
	assert(panel.message_label.text == "Not enough gems")
	panel.render_status()
	panel.message_label.text = ""
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-tax-desktop.png")
	root.size = Vector2i(430, 780)
	await process_frame
	await process_frame
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel.card.get_global_rect()), "Tax panel must fit mobile")
	assert(panel.card.get_global_rect().encloses(panel.pay_button.get_global_rect()))
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/world-tax-mobile.png")
	panel.info = {"enabled":true,"owned_count":3,"amount_due":0,"current_bill_gems":0,"next_due_at":"2026-10-20T20:00:00Z","bills":[],"history":[],"worlds":[]}
	panel.render_status()
	assert(panel.pay_button.disabled)
	panel.pending_id = "timeout"
	panel.deadline = 1
	panel._process(0)
	assert(panel.pending_id == "")
	assert(panel.pay_button.disabled)
	assert(not panel.refresh_button.disabled)
	panel.close_panel()
	assert(not panel.visible)
	panel.queue_free()
	print("WORLD_TAX_PANEL_TEST_OK")
	quit()
