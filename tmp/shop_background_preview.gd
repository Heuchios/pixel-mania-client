extends SceneTree
func _init(): call_deferred("run")
func run():
	var controller = load("res://Scripts/shop_ui.gd").new()
	assert(controller._shop_card_background({}, {"rarity":"common"}) == "shop_card_normal")
	assert(controller._shop_card_background({}, {"rarity":"legendary"}) == "shop_card_legendary")
	assert(controller._shop_card_background({"once_per_account":true}, {"rarity":"legendary"}) == "shop_card_special")
	assert(controller._shop_card_background({"section":"special"}, {"rarity":"common"}) == "shop_card_normal")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	viewport.add_child(shop)
	var card = shop._category_grids[0].get_child(0)
	card.set_meta("item_id", "preview")
	for kind in ["normal", "legendary", "special"]:
		var region: String = "shop_card_" + kind
		controller._apply_shop_card_background(card, region)
		shop._open_detail(card)
		await create_timer(.35).timeout
		assert(shop.detail_icon_slot.texture == UIAtlasDB.get_texture(region))
		assert(shop.detail_icon_slot.texture.region.size == Vector2(96,96))
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("D:/Pixelmania/shop-background-" + kind + ".png")
	controller.free()
	print("[shop-backgrounds] all three mappings and detail inheritance passed")
	quit()
