extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	viewport.add_child(shop)
	var controller = load("res://tmp/reward_slot_fixture.gd").new()
	viewport.add_child(controller)
	shop.show_reward_popup("Lure Pack opened", true, false, "lure_pack", 1, 100)
	controller.populate_purchase_reward_slots(shop.reward_items_container, [{"item_id":"worm_lure", "amount":1}, {"item_id":"hook", "amount":3}, {"item_id":"shiny_lure", "amount":2}], shop.reward_scroll.size)
	await capture(viewport, "shop-rewards-updated")
	assert(shop.reward_items_container.get_node("Reward_hook/Amount").text == "3")
	assert(shop.reward_items_container.get_node("Reward_hook").get_theme_stylebox("panel").get_meta("atlas_region") == "inv_slot_normal")
	assert(shop.reward_close_button.text == "DONE")
	viewport.size = Vector2i(640,480)
	await capture(viewport, "shop-rewards-compact")
	shop.reward_close_button.pressed.emit()
	assert(not shop.reward_overlay.visible)
	print("[shop-rewards] inventory slots, quantities, close and compact preview passed")
	quit()
func capture(viewport, filename):
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/" + filename + ".png")
