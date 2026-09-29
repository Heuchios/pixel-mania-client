extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1100,760)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui=load("res://Scenes/ui/trade/TradeScene.tscn").instantiate()
	ui.set_script(load("res://tmp/trade_layout_fixture.gd"))
	viewport.add_child(ui)
	var state={"type":"trade_state","status":"active","requester_player_id":"local","target_player_id":"remote","requester_username":"USO","target_username":"UCE","offers":{"local":[],"remote":[]},"accepted":{}}
	ui.handle_trade_message(state)
	await capture(viewport,"trade-empty")
	state.offers.local=[{"item_id":"crystal_fish","item_category":"fish","amount":25}]
	state.offers.remote=[{"item_id":"crystal_fish","item_category":"fish","amount":10}]
	state.accepted={"remote":true}
	ui.handle_trade_message(state)
	assert(ui.remote_check_label.visible and not ui.local_check_label.visible)
	assert(ui.local_slots[0].get_node("ClearButton").visible)
	await capture(viewport,"trade-updated")
	state.status="final_pending"
	ui.handle_trade_message(state)
	assert(ui.final_overlay.visible and ui.accept_button.disabled)
	assert(not ui.local_slots[0].get_node("ClearButton").visible)
	await capture(viewport,"trade-final")
	state.status="active"
	ui.handle_trade_message(state)
	viewport.size=Vector2i(640,400)
	ui.update_position()
	assert(ui.panel.position.x>=0 and ui.panel.position.y>=0)
	await capture(viewport,"trade-compact")
	print("Trade preview: offers, acceptance state, final confirmation and compact fit passed.")
	quit()
func capture(viewport,filename):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
