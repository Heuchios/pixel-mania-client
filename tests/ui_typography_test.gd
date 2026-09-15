extends SceneTree

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var label := Label.new()
	label.name = "PriceLabel"
	label.set_meta("pixelmania_font_role", "preserve")
	label.add_theme_font_size_override("font_size", 12)
	root.add_child(label)
	await process_frame
	await process_frame
	assert(label.get_theme_font_size("font_size") == 24, "Legacy opt-outs must use body typography")
	label.add_theme_font_size_override("font_size", 13)
	await process_frame
	await process_frame
	assert(label.get_theme_font_size("font_size") == 24, "Runtime restyling must retain shared size")
	label.name = "CategoryTitleLabel"
	Style.apply_global_typography_to_node(label)
	assert(label.get_theme_font_size("font_size") == 36, "Section headers must match window titles")
	label.queue_free()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(640, 360)
	var shop: Control = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	root.add_child(shop)
	await create_timer(0.5).timeout
	assert(shop.shop_window.scale == Vector2.ONE, "Phone shop must reflow instead of shrinking text")
	assert(shop.get_category_grid("all").columns == 1)
	assert(shop.sidebar.get_parent() is ScrollContainer, "Phone categories must stay reachable")
	assert(shop.close_button.size == Vector2(48, 48), "Close button must use shared dimensions")
	assert(shop.close_button.icon.get_meta("atlas_region") == "close_button")
	assert(shop.item_scroll_track.size.x == 12)
	assert(shop.item_scroll_handle.size.x == 8)
	var card: Control = shop.get_category_grid("all").get_child(0)
	var pack_name: Label = card.get_node("NameLabel2")
	pack_name.text = "ULTIMATE EDITION"
	await process_frame
	assert(pack_name.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART)
	assert(pack_name.get_minimum_size().y <= pack_name.size.y, "Pack name must fit its text area")
	shop.queue_free()
	await process_frame
	print("[ui-typography] passed")
	quit()
