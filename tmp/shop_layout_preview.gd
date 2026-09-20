extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1487, 935)
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	root.add_child(shop)
	var db = load("res://Scripts/item_database.gd").new()
	var ids = ["crafting_station", "vending_machine", "safe", "fish_monger", "anti_punch", "anti_talk", "anti_gravity", "snow_repellent"]
	var prices = [80, 7500, 7500, 15000, 25000, 25000, 150000, 75000]
	var cards = shop.ensure_grid_card_count("stations_special", 8)
	for i in range(8):
		var data = db.get_item_data(ids[i])
		cards[i].get_node("NameLabel").text = data.get("display_name", data.get("name", ids[i]))
		cards[i].get_node("NameLabel2").text = ""
		cards[i].get_node("PriceLabel").text = str(prices[i]) + " GEMS"
		cards[i].get_node("IconSlot/Icon").texture = load("res://Scripts/atlas_texture_factory.gd").load_texture(data.get("inventory_icon", data.get("texture")))
	shop._sidebar_buttons[3].button_pressed = true
	shop.get_node("ShopWindow/Margin/Layout/Header/BalanceChip/BalanceLabel").text = "9,135,290"
	await create_timer(0.8).timeout
	print("LAYOUT ", shop.item_scroll.size, " grid ", shop.get_category_grid("stations_special").size)
	assert(shop.get_category_grid("stations_special").size.y <= shop.item_scroll.size.y, "Second row clipped")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/shop-layout-implemented.png")
	db.free()
	shop.queue_free()
	quit()
