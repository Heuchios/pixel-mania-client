extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board = load("res://Scripts/bulletin_board_ui.gd").new()
	viewport.add_child(board)
	board.setup(null)
	board.open_bulletin_board(Vector2i.ZERO)
	assert(board.post_button.disabled)
	await capture(viewport,"bulletin-empty")
	board.message_input.text = "Welcome to our world!"
	board._on_message_text_changed()
	assert(not board.post_button.disabled)
	for child in board.messages_root.get_children():
		board.messages_root.remove_child(child)
		child.queue_free()
	board.add_message_row({"player_name":"World Owner", "message":"Welcome! Share your ideas for the world here. Please keep messages friendly.", "posted_at":"2026-10-07T12:00:00"})
	board.add_message_row({"player_name":"Visitor", "message":"The fishing area looks great!", "posted_at":"2026-10-07T12:05:00"})
	await capture(viewport,"bulletin-updated")
	board.close_bulletin_board()
	var donation = load("res://Scripts/donation_box_ui.gd").new()
	viewport.add_child(donation)
	donation.setup(null,null)
	donation.donation_box_open_requested = true
	donation.visible = true
	donation.current_state = {"can_manage":true,"donations":[]}
	donation.refresh_ui()
	await capture(viewport,"donation-empty")
	assert(donation.retrieve_all_button.disabled)
	donation.current_state = {"can_manage":true,"donations":[{"item_id":"wooden_chair","amount":12,"donor_name":"Visitor"},{"item_id":"gasoline","amount":5,"donor_name":"Friendly Player"}]}
	donation.refresh_ui()
	assert(not donation.retrieve_all_button.disabled)
	await capture(viewport,"donation-updated")
	viewport.size = Vector2i(640,480)
	await capture(viewport,"donation-compact")
	assert(donation.panel.position.x >= 0 and donation.panel.position.y >= 0)
	donation.close_donation_box()
	board.open_bulletin_board(Vector2i.ZERO)
	await capture(viewport,"bulletin-compact")
	assert(board.panel.position.x >= 0 and board.panel.position.y >= 0)
	print("[community-ui] empty/populated, input state, retrieval state, compact fit passed")
	quit()
func capture(viewport, filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")

