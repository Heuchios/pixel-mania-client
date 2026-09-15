extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var sheet := load(UIAtlasDB.UI_ATLAS_TEXTURE_PATH) as Texture2D
	var bounds := Rect2(Vector2.ZERO, sheet.get_size())
	for name in UIAtlasDB.REGIONS:
		var texture := UIAtlasDB.get_texture(name) as AtlasTexture
		check(texture != null, "Missing atlas texture: " + name)
		check(bounds.encloses(UIAtlasDB.get_region_rect(name)), "Out-of-bounds region: " + name)
		check(texture.region == UIAtlasDB.get_region_rect(name), "Stale generated region: " + name)
		check(UIAtlasDB.get_stylebox(name).region_rect == texture.region, "Texture/style mismatch: " + name)
	check(UIAtlasDB.get_stylebox("input_field").texture_margin_left == 3, "Input slicing lost")
	var local_style := UIAtlasDB.get_stylebox("blue_button").duplicate() as StyleBoxTexture
	local_style.modulate_color = Color.RED
	check(UIAtlasDB.get_stylebox("blue_button").modulate_color == Color.WHITE, "Local state changed the shared style")
	_scan_scenes("res://Scenes/ui")
	var inventory: Control = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(inventory)
	await process_frame
	check(inventory.get_node("Window/WindowSkin").texture.get_meta("atlas_region") == "outer_panel", "Inventory outer panel must be light lavender")
	inventory.set_inventory_items([
		{"id": "test_rare", "display_name": "Rare", "category": "block", "count": 4, "rarity": "rare"},
		{"id": "test_material", "display_name": "Material", "category": "material", "count": 1},
	])
	await process_frame
	for slot in inventory.slot_nodes.values():
		check(slot.get_node("Frame").texture is AtlasTexture, "Live inventory reverted to PNG frame")
	inventory.queue_free()
	await process_frame
	var shop: Control = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	check(shop.shop_window.get_theme_stylebox("panel").get_meta("atlas_region") == "outer_panel", "Shop outer panel must be light lavender")
	check(shop.get_node("ShopWindow/Margin/Layout/Header/TitleLabel").get_theme_stylebox("normal").get_meta("atlas_region") == "inner_panel", "Shop header must be dark purple")
	var grid: GridContainer = shop.get_category_grid("all")
	var card: Button = grid.get_child(0)
	card.set_meta("item_id", "test_item")
	card.set_meta("price", 100)
	card.set_meta("amount", 1)
	card.set_meta("is_gem_pack", false)
	shop.set_available_gems(20)
	shop._open_detail(card)
	var requests: Array = []
	shop.buy_requested.connect(func(id: String, _amount: int, _price: int, _gem_pack: bool): requests.append(id))
	check(shop.detail_buy_button.disabled, "Unaffordable purchase enabled")
	check(not card.disabled, "Unaffordable item cannot be browsed")
	shop._on_detail_buy_pressed()
	check(requests.is_empty(), "Disabled purchase emitted a request")
	shop.set_available_gems(100)
	check(not shop.detail_buy_button.disabled, "Affordable purchase disabled")
	shop._on_detail_buy_pressed()
	check(requests == ["test_item"], "Affordable purchase did not emit exactly once")
	shop.set_available_gems(0)
	check(shop.detail_buy_button.disabled, "Open popup did not track balance decrease")
	card.set_meta("is_gem_pack", true)
	shop._open_detail(card)
	check(not shop.detail_buy_button.disabled, "Gem checkout incorrectly gated on in-game balance")
	shop._on_detail_closed()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for viewport_size in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		root.size = viewport_size
		await process_frame
		shop._fit_shop_window()
		await create_timer(0.2).timeout
		check(Rect2(Vector2.ZERO, viewport_size).encloses(shop.shop_window.get_global_rect()), "Shop clips at " + str(viewport_size))
	shop.ensure_grid_card_count("all", 40)
	await process_frame
	await process_frame
	shop._sync_item_scroll_slider()
	check(shop._item_scroll_maximum() > 0, "Long category is not scrollable")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = shop.item_scroll_track.get_global_rect().end - Vector2(2, 2)
	shop._handle_item_scroll_pointer_event(touch, true)
	check(shop.item_scroll.scroll_vertical > 0, "Touch scrollbar did not scroll")
	touch.pressed = false
	shop._handle_item_scroll_pointer_event(touch, false)
	check(not shop._item_scroll_handle_dragging, "Touch scrollbar drag stuck after release")
	shop.queue_free()
	await process_frame
	print("[ui-atlas-migration] failures=", failures)
	quit(1 if failures else 0)

func _scan_scenes(folder: String) -> void:
	for directory in DirAccess.get_directories_at(folder):
		_scan_scenes(folder.path_join(directory))
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".tscn"):
			continue
		var path := folder.path_join(file)
		var packed := load(path) as PackedScene
		check(packed != null, "Failed to load " + path)
		if packed != null:
			var node := packed.instantiate()
			check(node != null, "Failed to instantiate " + path)
			if node != null:
				node.free()
