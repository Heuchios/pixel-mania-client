extends SceneTree
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1200,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop=load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	viewport.add_child(shop)
	await capture(viewport,"shop-detached-tabs")
	for i in range(shop._sidebar_buttons.size()):
		shop._sidebar_buttons[i].button_pressed=true
		await process_frame
		assert(shop._category_grids[i].visible)
	shop._sidebar_buttons[0].button_pressed=true
	viewport.size=Vector2i(640,480)
	await capture(viewport,"shop-detached-compact")
	assert(shop.category_rail.position.x>=0)
	print("Shop categories and detached rail fit passed.")
	quit()
func capture(viewport,filename):
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/"+filename+".png")
