extends SceneTree

class PhoneScale extends "res://Scripts/ui/mobile_ui_scale.gd":
	func is_mobile() -> bool:
		return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var scaling = root.get_node("MobileUIScale")
	scaling.set_script(PhoneScale)
	scaling.set_process(true)
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	root.add_child(shop)
	for dimensions in [Vector2i(1280, 590), Vector2i(1300, 600), Vector2i(1280, 720), Vector2i(640, 360), Vector2i(600, 900)]:
		root.size = dimensions
		for value in [0.75, 1.0, 1.25, 1.5]:
			scaling.ui_scale = value
			scaling.scale_changed.emit(value)
			for i in range(6):
				await process_frame
			var rail: Rect2 = shop.category_rail.get_global_rect()
			var window: Rect2 = shop.shop_window.get_global_rect()
			assert(not rail.intersects(window), "Shop window covers category tabs")
			assert(shop.get_viewport_rect().grow(1).encloses(rail.merge(window)), "Shop group must fit the viewport")
			assert(shop.category_rail.scale.is_equal_approx(shop.shop_window.scale), "Rail and shop need one scale")
			for button in shop._sidebar_buttons:
				assert(button.get_global_rect().position.x >= rail.position.x, "Tab text starts outside rail")
				assert(button.get_global_rect().end.x <= rail.end.x + 1, "Tab clipped horizontally")
			shop._sidebar_buttons[2].button_pressed = true
			assert(shop._category_grids[2].visible, "Category tabs must remain interactive")
			shop._play_panel_open(shop.shop_window)
			await process_frame
			assert(not shop.category_rail.get_global_rect().intersects(shop.shop_window.get_global_rect()), "Open animation must preserve tab space")
	root.size = Vector2i(1280, 590)
	scaling.ui_scale = 1.25
	scaling.scale_changed.emit(1.25)
	shop._sidebar_buttons[0].button_pressed = true
	for i in range(6):
		await process_frame
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/1220-mobile-shop.png")
	shop.free()
	print("MOBILE_SHOP_LAYOUT_PASS: full category rail, shared scale, small/large phones, all UI scales and open animation")
	quit()
