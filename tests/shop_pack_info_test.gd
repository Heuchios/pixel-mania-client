extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
var preview := false

func _initialize():
	preview = "--preview" in OS.get_cmdline_user_args()
	call_deferred("run")

func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	viewport.add_child(shop)
	await process_frame
	var info = shop.pack_info
	var card: Button = shop._category_grids[0].get_child(0)
	var purchases := [0]
	shop.buy_requested.connect(func(_id, _amount, _price, _gem): purchases[0] += 1)
	for id in info.packs:
		card.set_meta("item_id", id)
		card.set_meta("is_gem_pack", false)
		card.get_node("NameLabel").text = DB.ITEMS[id].display_name
		shop._open_detail(card)
		await process_frame
		assert(info.info_button.visible)
		assert(info.info_button.get_index() + 1 == shop.detail_buy_button.get_index())
		info.info_button.pressed.emit()
		await process_frame
		assert(info.is_open())
		var first_open_rect: Rect2 = info.panel.get_rect()
		assert(first_open_rect.size.is_equal_approx(Vector2(580, 560)), "First opening must use the intended panel size")
		assert(first_open_rect.position.is_equal_approx((shop.size - first_open_rect.size) * 0.5), "First opening must be centered")
		await create_timer(0.1).timeout
		assert(info.panel.get_rect().is_equal_approx(first_open_rect), "Content layout must not resize the panel")
		info.close()
		info.open()
		await process_frame
		assert(info.panel.get_rect().is_equal_approx(first_open_rect), "Reopening must use the same size and position")
		assert(info.rows.get_child_count() == info.packs[id].rewards.size())
		var total := 0.0
		for reward in info.packs[id].rewards:
			total += float(reward.chance)
		assert(is_equal_approx(total, 1.0))
		info.close()
	assert(purchases[0] == 0, "Info must never purchase a pack")
	assert(info.format_chance(0.001) == "0.1%", "Hair chase odds must remain visible")
	assert(info.format_chance(0.6) == "60%")
	card.set_meta("item_id", "world_lock")
	shop._open_detail(card)
	assert(not info.info_button.visible)
	card.set_meta("item_id", "lure_pack")
	card.set_meta("is_gem_pack", true)
	shop._open_detail(card)
	assert(not info.info_button.visible, "Guaranteed gem bundles have no random loot info")
	card.set_meta("is_gem_pack", false)
	card.set_meta("price", 25)
	card.get_node("PriceLabel").text = "25 GEMS"
	card.get_node("NameLabel").text = "Lure Pack"
	card.get_node("IconSlot/Icon").texture = Factory.load_texture(DB.ITEMS.lure_pack.texture)
	card.tooltip_text = "Gives 5 random fishing lures."
	shop.set_available_gems(1000)
	shop._open_detail(card)
	await capture(viewport, "shop-pack-info-button")
	assert(info.info_button.get_global_rect().end.y <= shop.detail_buy_button.get_global_rect().position.y)
	info.open()
	await capture(viewport, "shop-pack-info-desktop")
	viewport.size = Vector2i(844, 390)
	await capture(viewport, "shop-pack-info-phone")
	assert(info.panel.position.x >= 0 and info.panel.position.y >= 0)
	assert(info.panel.get_rect().end.x <= shop.size.x and info.panel.get_rect().end.y <= shop.size.y)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	shop._unhandled_key_input(escape)
	assert(not info.is_open() and shop.detail_overlay.visible, "Back closes odds and returns to the pack")
	viewport.free()
	print("SHOP_PACK_INFO_OK: all packs, percentages, buy isolation, close, and mobile fit")
	quit()

func capture(viewport: SubViewport, label: String):
	await create_timer(0.4).timeout
	if preview:
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("D:/Pixelmania/work/" + label + ".png")
