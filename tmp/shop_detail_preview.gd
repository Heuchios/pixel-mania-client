extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop=load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	viewport.add_child(shop)
	var card = shop._category_grids[0].get_child(0)
	card.set_meta("item_id","appreciation_wings")
	card.set_meta("price",0)
	card.tooltip_text = "A thank-you gift for playing PixelMania. Claim one free pair per account."
	shop._open_detail(card)
	await capture(viewport,"shop-detail-updated")
	assert(shop.detail_buy_button.text == "CLAIM FREE")
	assert(shop.detail_icon_slot.size == Vector2(184,184))
	card.set_meta("item_id","lure_pack")
	card.set_meta("price",100)
	card.get_node("NameLabel").text="Lure Pack"
	card.tooltip_text="A selection of bait for your next fishing trip. Open Info to see the possible rewards."
	shop.set_available_gems(1000)
	shop._open_detail(card)
	await capture(viewport,"shop-detail-pack")
	assert(shop.pack_info.info_button.visible)
	assert(shop.detail_buy_button.get_global_rect().end.y <= shop.detail_card.get_global_rect().end.y)
	viewport.size=Vector2i(640,480)
	await capture(viewport,"shop-detail-compact")
	print("[shop-detail] free action, preview slot, pack info, compact layout passed")
	quit()
func capture(viewport,filename):
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
