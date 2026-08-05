extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const SHOP_HEADER_HEIGHT := 78.0
const SHOP_NAV_HEIGHT := 44.0
const SHOP_SECTION_HEADER_HEIGHT := 38.0
const SHOP_CARD_GAP_X := 16.0
const SHOP_CARD_GAP_Y := 14.0
const SHOP_SECTION_GAP := 30.0
const SHOP_PRICE_BAR_HEIGHT := 42.0
const SHOP_ICON_PATH := "res://Assets/ui/icons/shop.png"
const SHOP_BUTTON_SIZE := Vector2(64, 64)
const SHOP_BUTTON_Y := 160.0

var world = null
var ui_layer_ref = null

var shop_button = null
var shop_button_icon = null
var shop_button_icon_shadow = null
var shop_button_tween = null
var shop_button_hovered := false
var shop_panel = null
var shop_category_root = null
var shop_category_buttons = {}
var shop_scroll_container = null
var shop_items_root = null
var shop_gem_label = null
var purchase_reward_popup = null
var gem_hud = null
var gem_hud_icon = null
var gem_hud_label = null
var shop_panel_layout_size = Vector2.ZERO
var selected_shop_category = "all"
var shop_last_purchase_context = {}

var shop_items = [
	{
		"item_id": "small_lock",
		"amount": 1,
		"price": 500,
		"section": "locks",
		"description": "Protect a small 10-tile area and manage builder access."
	},
	{
		"item_id": "medium_lock",
		"amount": 1,
		"price": 1000,
		"section": "locks",
		"description": "Protect a medium 48-tile area and manage builder access."
	},
	{
		"item_id": "big_lock",
		"amount": 1,
		"price": 1500,
		"section": "locks",
		"description": "Protect a big 80-tile area and manage builder access."
	},
	{
		"item_id": "world_lock",
		"amount": 1,
		"price": 3500,
		"section": "locks",
		"description": "Protect one world and control building access."
	},
	{
		"item_id": "crafting_station",
		"amount": 1,
		"price": 80,
		"section": "stations",
		"description": "Main station for tools and special recipes."
	},
	{
		"item_id": "vend_empty",
		"amount": 1,
		"price": 7500,
		"section": "special",
		"description": "Sell items to other players for World Locks.",
	},
	{
		"item_id": "safe",
		"amount": 1,
		"price": 7500,
		"section": "special",
		"description": "Owner-only storage for valuable items.",
	},
	{
		"item_id": "fish_monger",
		"amount": 1,
		"price": 15000,
		"section": "special",
		"description": "A friendly vendor who buys your caught fish for gems.",
	},
	{
		"item_id": "anti_punch",
		"amount": 1,
		"price": 25000,
		"section": "special",
		"description": "Lets owners block player punch knockback in their world.",
	},
	{
		"item_id": "anti_talk",
		"amount": 1,
		"price": 25000,
		"section": "special",
		"description": "Lets owners block normal chat and popup text in their world.",
	},
	{
		"item_id": "anti_gravity",
		"amount": 1,
		"price": 150000,
		"section": "special",
		"description": "Lets owners enable higher jumps and slower falling in their world.",
	},
	{
		"item_id": "snow_repellent",
		"amount": 1,
		"price": 75000,
		"section": "special",
		"description": "Blocks Snow Storm events from spawning in the world.",
	},
	{
		"item_id": "night_theme_machine",
		"amount": 1,
		"price": 125000,
		"section": "special",
		"description": "Lets trusted builders switch the world to a night parallax background.",
	},
	{
		"item_id": "snow_theme_machine",
		"amount": 1,
		"price": 125000,
		"section": "special",
		"description": "Lets trusted builders switch the world to a snow parallax background.",
	},
	{
		"item_id": "city_theme_machine",
		"amount": 1,
		"price": 125000,
		"section": "special",
		"description": "Lets trusted builders switch the world to a city parallax background.",
	},
	{
		"item_id": "cctv",
		"amount": 1,
		"price": 15000,
		"section": "special",
		"description": "Tracks the latest world enter and leave activity for owners.",
	},
	{
		"item_id": "basic_items_pack",
		"amount": 1,
		"price": 500,
		"section": "clothes",
		"description": "Opens into one random basic wearable item.",
	},
	{
		"item_id": "hairpack",
		"amount": 1,
		"price": 1500,
		"section": "clothes",
		"description": "Opens into one random hair style.",
	},
	{
		"item_id": "red_tractor",
		"amount": 1,
		"price": 100000,
		"section": "clothes",
		"description": "A red tractor ride that auto-harvests ready seed-trees.",
	},
	{
		"item_id": "prestige_coloured_block_pack",
		"amount": 1,
		"price": 500,
		"section": "blocks",
		"description": "Gives 5 random prestige coloured blocks.",
	},
	{
		"item_id": "entrance_mover",
		"amount": 1,
		"price": 200,
		"section": "tools",
		"description": "Move your world's Entrance Gate."
	},
	{
		"item_id": "lock_mover",
		"amount": 1,
		"price": 17000,
		"section": "tools",
		"description": "Move your World Lock or Super World Lock."
	},
	{
		"item_id": "door_mover",
		"amount": 1,
		"price": 500,
		"section": "tools",
		"description": "Move a door and keep its settings."
	},
	{
		"item_id": "electric_tool",
		"amount": 1,
		"price": 5000,
		"section": "tools",
		"description": "Link electrical wires between transformers, pads, and devices."
	},
	{
		"item_id": "bamboo_rod",
		"amount": 1,
		"price": 5000,
		"section": "fishing",
		"description": "A simple rod for casting into water with lures."
	},
	{
		"item_id": "fiberglass_rod",
		"amount": 1,
		"price": 15000,
		"section": "fishing",
		"description": "A stronger fishing rod ready for future upgrades."
	},
	{
		"item_id": "tungsten_rod",
		"amount": 1,
		"price": 50000,
		"section": "fishing",
		"description": "A heavy-duty fishing rod ready for future upgrades."
	},
		{
			"item_id": "lure_pack",
			"amount": 1,
			"price": 25,
			"section": "fishing",
			"description": "Gives 5 random fishing lures."
		},
		{
			"item_id": "tackle_box",
			"amount": 1,
			"price": 9500,
			"section": "fishing",
			"description": "A harvestable tackle box that refills with lures every 4 hours."
		}
	]


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	setup_shop_button()
	setup_gem_hud()
	setup_shop_panel()

	var issues = validate_shop_items()

	for issue in issues:
		print("Shop warning: " + str(issue))

	close_shop()


func _process(_delta):
	refresh_shop_panel_for_viewport()
	update_shop_button_position()
	update_shop_panel_position()
	update_shop_info()


func refresh_shop_panel_for_viewport():
	if shop_panel == null:
		return

	var screen_size = get_shop_viewport_size()
	if shop_panel_layout_size == Vector2.ZERO:
		shop_panel_layout_size = screen_size
		return

	if shop_panel_layout_size.distance_to(screen_size) <= 2.0:
		return

	var was_visible = shop_panel.visible
	setup_shop_panel()
	shop_panel.visible = was_visible


func get_shop_viewport_size() -> Vector2:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


func get_shop_margin_x(screen_size: Vector2) -> float:
	return clamp(screen_size.x * 0.035, 26.0, 76.0)


func get_hud_layer() -> Node:
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			return hud_layer

	return ui_layer_ref


func setup_shop_button():
	if ui_layer_ref == null:
		return
	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return

	shop_button = hud_layer.get_node_or_null("ShopButton")
	if shop_button == null and hud_layer != ui_layer_ref:
		shop_button = ui_layer_ref.get_node_or_null("ShopButton")

	if shop_button == null:
		shop_button = Button.new()
		shop_button.name = "ShopButton"
		hud_layer.add_child(shop_button)
	elif shop_button.get_parent() != hud_layer:
		var old_parent = shop_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(shop_button)
		hud_layer.add_child(shop_button)

	shop_button.text = ""
	shop_button.size = SHOP_BUTTON_SIZE
	shop_button.z_index = 184
	shop_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_shop_icon_button_style(shop_button)
	setup_shop_button_icon()

	if not shop_button.pressed.is_connected(toggle_shop):
		shop_button.pressed.connect(toggle_shop)
	if not shop_button.mouse_entered.is_connected(_on_shop_button_mouse_entered):
		shop_button.mouse_entered.connect(_on_shop_button_mouse_entered)
	if not shop_button.mouse_exited.is_connected(_on_shop_button_mouse_exited):
		shop_button.mouse_exited.connect(_on_shop_button_mouse_exited)
	if not shop_button.button_down.is_connected(_on_shop_button_down):
		shop_button.button_down.connect(_on_shop_button_down)
	if not shop_button.button_up.is_connected(_on_shop_button_up):
		shop_button.button_up.connect(_on_shop_button_up)

	update_shop_button_position()


func setup_shop_button_icon():
	if shop_button == null:
		return

	for child in shop_button.get_children():
		child.queue_free()

	if not ResourceLoader.exists(SHOP_ICON_PATH):
		shop_button.text = "SHOP"
		shop_button.size = Vector2(108, 42)
		apply_shop_arcade_button_style(shop_button, false, false, 15)
		return

	var icon_texture: Texture2D = load(SHOP_ICON_PATH) as Texture2D
	if icon_texture == null:
		shop_button.text = "SHOP"
		shop_button.size = Vector2(108, 42)
		apply_shop_arcade_button_style(shop_button, false, false, 15)
		return

	shop_button_icon_shadow = TextureRect.new()
	shop_button_icon_shadow.name = "ShopIconShadow"
	shop_button_icon_shadow.texture = icon_texture
	shop_button_icon_shadow.position = Vector2(5, 7)
	shop_button_icon_shadow.size = SHOP_BUTTON_SIZE
	shop_button_icon_shadow.pivot_offset = SHOP_BUTTON_SIZE * 0.5
	shop_button_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_button_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_button_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	shop_button.add_child(shop_button_icon_shadow)

	shop_button_icon = TextureRect.new()
	shop_button_icon.name = "ShopIcon"
	shop_button_icon.texture = icon_texture
	shop_button_icon.position = Vector2.ZERO
	shop_button_icon.size = SHOP_BUTTON_SIZE
	shop_button_icon.pivot_offset = SHOP_BUTTON_SIZE * 0.5
	shop_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_button_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	shop_button.add_child(shop_button_icon)


func apply_shop_icon_button_style(button: Button):
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_shop_button_mouse_entered():
	shop_button_hovered = true
	animate_shop_button_icon(false)


func _on_shop_button_mouse_exited():
	shop_button_hovered = false
	animate_shop_button_icon(false)


func _on_shop_button_down():
	animate_shop_button_icon(true)


func _on_shop_button_up():
	animate_shop_button_icon(false)


func animate_shop_button_icon(pressed: bool):
	if shop_button_icon == null or shop_button_icon_shadow == null:
		return

	if shop_button_tween != null:
		shop_button_tween.kill()

	var icon_position: Vector2 = Vector2.ZERO
	var shadow_position: Vector2 = Vector2(5, 7)
	var icon_scale: Vector2 = Vector2.ONE
	var shadow_alpha: float = 0.38
	var icon_alpha: float = 0.96

	if shop_button_hovered:
		icon_position = Vector2(-2, -3)
		shadow_position = Vector2(7, 10)
		icon_scale = Vector2(1.06, 1.06)
		shadow_alpha = 0.48
		icon_alpha = 1.0

	if pressed:
		icon_position = Vector2(1, 2)
		shadow_position = Vector2(3, 4)
		icon_scale = Vector2(0.96, 0.96)
		shadow_alpha = 0.28

	shop_button_tween = create_tween()
	shop_button_tween.set_parallel(true)
	shop_button_tween.tween_property(shop_button_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shop_button_tween.tween_property(shop_button_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shop_button_tween.tween_property(shop_button_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shop_button_tween.tween_property(shop_button_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shop_button_tween.tween_property(shop_button_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shop_button_tween.tween_property(shop_button_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func setup_gem_hud():
	if ui_layer_ref == null:
		return

	gem_hud = ui_layer_ref.get_node_or_null("GemHud")
	if gem_hud != null:
		gem_hud.queue_free()
	gem_hud = null
	gem_hud_icon = null
	gem_hud_label = null


func update_gem_hud_position():
	if gem_hud != null and is_instance_valid(gem_hud):
		gem_hud.queue_free()
	gem_hud = null
	gem_hud_icon = null
	gem_hud_label = null


func setup_shop_panel():
	if ui_layer_ref == null:
		return

	shop_panel = ui_layer_ref.get_node_or_null("ShopPanel")

	if shop_panel == null:
		shop_panel = Control.new()
		shop_panel.name = "ShopPanel"
		ui_layer_ref.add_child(shop_panel)

	var screen_size = get_shop_viewport_size()
	shop_panel_layout_size = screen_size
	shop_panel.position = Vector2.ZERO
	shop_panel.size = screen_size
	shop_panel.z_index = 220
	shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if shop_panel is ColorRect:
		shop_panel.color = Color(1, 1, 1, 0)

	for child in shop_panel.get_children():
		child.queue_free()
	shop_category_buttons.clear()
	shop_category_root = null
	shop_scroll_container = null
	shop_items_root = null
	shop_gem_label = null
	purchase_reward_popup = null

	var margin_x = get_shop_margin_x(screen_size)
	var content_width = max(420.0, screen_size.x - margin_x * 2.0)
	var nav_y = SHOP_HEADER_HEIGHT + 28.0
	var grid_y = nav_y + SHOP_NAV_HEIGHT + 34.0
	if screen_size.y < 560.0:
		nav_y = SHOP_HEADER_HEIGHT + 12.0
		grid_y = nav_y + SHOP_NAV_HEIGHT + 20.0
	var scroll_height = max(190.0, screen_size.y - grid_y - 30.0)

	var panel_back = ColorRect.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = shop_panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.color = Color(0.055, 0.105, 0.145, 0.40)
	shop_panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(screen_size.x, SHOP_HEADER_HEIGHT)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0, 0, 8
	))
	shop_panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, SHOP_HEADER_HEIGHT - 5.0)
	top_line.size = Vector2(screen_size.x, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "GEM SHOP"
	title.position = Vector2(margin_x, 6)
	title.size = Vector2(min(560.0, screen_size.x * 0.50), 66)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 56 if screen_size.x >= 1000.0 else 42)
	shop_panel.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "STORE"
	title_sub.position = Vector2(margin_x + 6.0, 60)
	title_sub.size = Vector2(210, 22)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	shop_panel.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(screen_size.x - margin_x - close_button.size.x, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.text = "X"
	apply_shop_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_shop)
	shop_panel.add_child(close_button)

	var chip_width = 276.0 if screen_size.x >= 960.0 else 236.0
	var gem_chip = Panel.new()
	gem_chip.name = "GemChip"
	gem_chip.position = Vector2(close_button.position.x - chip_width - 14.0, 14)
	gem_chip.size = Vector2(chip_width, 48)
	gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 14, 8
	))
	shop_panel.add_child(gem_chip)

	var gem_icon = TextureRect.new()
	gem_icon.name = "GemIcon"
	gem_icon.position = gem_chip.position + Vector2(12, 6)
	gem_icon.size = Vector2(36, 36)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		gem_icon.texture = world.currency_textures["gem"]
	shop_panel.add_child(gem_icon)

	shop_gem_label = Label.new()
	shop_gem_label.name = "GemLabel"
	shop_gem_label.position = gem_chip.position + Vector2(56, 7)
	shop_gem_label.size = Vector2(chip_width - 72.0, 28)
	shop_gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shop_gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(shop_gem_label, 22, Color(1.0, 1.0, 1.0, 1.0))
	shop_panel.add_child(shop_gem_label)

	var shop_word = Label.new()
	shop_word.name = "ShopWord"
	shop_word.text = "SHOP"
	shop_word.position = Vector2(max(margin_x, gem_chip.position.x - 112.0), 20)
	shop_word.size = Vector2(100, 34)
	shop_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_word.visible = shop_word.position.x + shop_word.size.x + 10.0 < gem_chip.position.x
	PixelUIStyle.apply_label_shadow(shop_word, 25)
	shop_panel.add_child(shop_word)

	var nav_back = Panel.new()
	nav_back.name = "CategoryBack"
	nav_back.position = Vector2(margin_x, nav_y - 8.0)
	nav_back.size = Vector2(content_width, SHOP_NAV_HEIGHT + 14.0)
	nav_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.82, 0.94, 1.0, 0.10),
		Color(0.42, 0.78, 1.0, 0.22),
		1, 6, 0
	))
	shop_panel.add_child(nav_back)

	shop_category_root = Control.new()
	shop_category_root.name = "CategoryTabs"
	shop_category_root.position = Vector2(margin_x, nav_y)
	shop_category_root.size = Vector2(content_width, SHOP_NAV_HEIGHT)
	shop_category_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(shop_category_root)
	create_shop_category_tabs()

	shop_scroll_container = ScrollContainer.new()
	shop_scroll_container.name = "ShopScroll"
	shop_scroll_container.position = Vector2(margin_x, grid_y)
	shop_scroll_container.size = Vector2(content_width, scroll_height)
	shop_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	shop_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_scroll_container.clip_contents = true
	shop_panel.add_child(shop_scroll_container)

	shop_items_root = Control.new()
	shop_items_root.name = "ShopItems"
	shop_items_root.position = Vector2.ZERO
	shop_items_root.size = shop_scroll_container.size
	shop_items_root.custom_minimum_size = shop_scroll_container.size
	shop_items_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_scroll_container.add_child(shop_items_root)

	create_shop_item_cards()
	apply_shop_scrollbar_style()
	update_shop_panel_position()
	update_shop_info()


func get_shop_item_section(item: Dictionary) -> String:
	return str(item.get("section", "featured"))


func get_shop_item_description(item: Dictionary) -> String:
	return str(item.get("description", ""))


func is_shop_item_valid(item: Dictionary) -> bool:
	if world == null:
		return false

	var item_id = str(item.get("item_id", ""))

	if item_id == "":
		return false

	return world.item_database.has(item_id)


func validate_shop_items() -> Array:
	var issues = []

	if world == null:
		return issues

	for item in shop_items:
		var item_id = str(item.get("item_id", ""))

		if item_id == "":
			issues.append("Shop item missing item_id.")
			continue

		if not world.item_database.has(item_id):
			issues.append("Shop item missing from item_database: " + item_id)

		if int(item.get("amount", 0)) <= 0:
			issues.append("Shop item has invalid amount: " + item_id)

		if int(item.get("price", -1)) < 0:
			issues.append("Shop item has invalid price: " + item_id)

	return issues


func get_shop_categories() -> Array:
	var categories = ["all"]
	for item in shop_items:
		if not (item is Dictionary) or not is_shop_item_valid(item):
			continue
		var category = get_shop_item_section(item).strip_edges().to_lower()
		if category == "":
			category = "featured"
		if not categories.has(category):
			categories.append(category)
	return categories


func get_shop_category_display_name(category: String) -> String:
	match category:
		"all":
			return "Featured"
		"stations":
			return "Stations"
		"tools":
			return "Tools"
		"fishing":
			return "Fishing"
		"clothes":
			return "Clothes"
		"locks":
			return "Locks"
		"special":
			return "Special"
		_:
			return category.capitalize()


func create_shop_category_tabs():
	if shop_category_root == null:
		return

	for child in shop_category_root.get_children():
		child.queue_free()

	shop_category_buttons.clear()
	var categories = get_shop_categories()
	var gap = 10.0
	var tab_count = max(1, categories.size())
	var button_width = floor((shop_category_root.size.x - gap * float(tab_count - 1)) / float(tab_count))
	var min_button_width = 96.0
	if shop_category_root.size.x < 760.0:
		min_button_width = 76.0
	if shop_category_root.size.x < 560.0:
		min_button_width = 62.0
	button_width = clamp(button_width, min_button_width, 150.0)
	var tab_x = 0.0
	for category in categories:
		var button = Button.new()
		button.name = "Category_" + category
		button.text = get_shop_category_display_name(category).to_upper()
		button.position = Vector2(tab_x, 0)
		button.size = Vector2(button_width, 38)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_shop_category_pressed.bind(category))
		shop_category_root.add_child(button)
		shop_category_buttons[category] = button
		tab_x += button_width + gap

	apply_shop_category_styles()


func apply_shop_category_styles():
	for category in shop_category_buttons.keys():
		var button = shop_category_buttons[category]
		if button == null:
			continue
		apply_shop_arcade_button_style(button, category == selected_shop_category, false, 13)


func apply_shop_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		return
	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return
	PixelUIStyle.apply_blue_button(button, font_size)


func apply_shop_price_button_style(button: Button, font_size: int = 22):
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.14, 0.86, 0.06, 0.92), Color(0.24, 1.0, 0.22, 0.50), 3, 6, 5))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.22, 0.98, 0.09, 0.98), Color(0.56, 1.0, 0.42, 0.72), 3, 6, 6))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.08, 0.58, 0.04, 0.96), Color(0.08, 0.48, 0.02, 0.78), 3, 6, 3))


func get_shop_item_entry(item_id: String) -> Dictionary:
	for item in shop_items:
		if not (item is Dictionary):
			continue
		if str(item.get("item_id", "")) == item_id:
			return item
	return {}


func apply_shop_card_style(card: Panel, is_featured: bool):
	if card == null:
		return
	var fill = Color(0.18, 0.32, 0.43, 0.42)
	var border = Color(0.72, 0.92, 1.0, 0.46)
	if is_featured:
		fill = Color(0.36, 0.30, 0.10, 0.54)
		border = Color(1.0, 0.82, 0.18, 0.86)
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(fill, border, 3, 8, 7))


func apply_shop_scrollbar_style():
	if shop_scroll_container == null:
		return
	var scrollbar = shop_scroll_container.get_h_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size = Vector2(16, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func _on_shop_category_pressed(category: String):
	selected_shop_category = category
	if shop_scroll_container != null:
		shop_scroll_container.scroll_horizontal = 0
	apply_shop_category_styles()
	create_shop_item_cards()


func format_shop_price(value: int) -> String:
	var digits = str(max(0, value))
	var result = ""
	var group_count = 0

	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1

	return result


func get_shop_card_size() -> Vector2:
	if shop_scroll_container == null:
		return Vector2(310, 154)

	var available_width = shop_scroll_container.size.x
	var visible_columns = 4
	if available_width < 1080.0:
		visible_columns = 3
	if available_width < 760.0:
		visible_columns = 2

	var card_width = floor((available_width - SHOP_CARD_GAP_X * float(visible_columns - 1)) / float(visible_columns))
	card_width = clamp(card_width, 246.0, 340.0)

	var available_height = shop_scroll_container.size.y - SHOP_SECTION_HEADER_HEIGHT
	var card_height = floor((available_height - SHOP_CARD_GAP_Y) / 2.0)
	card_height = clamp(card_height, 116.0, 160.0)

	return Vector2(card_width, card_height)


func get_shop_section_accent(section: String) -> Color:
	match section:
		"locks":
			return Color(1.0, 0.78, 0.12, 1.0)
		"stations":
			return Color(0.30, 0.86, 1.0, 1.0)
		"tools":
			return Color(0.34, 1.0, 0.50, 1.0)
		"fishing":
			return Color(0.28, 0.72, 1.0, 1.0)
		"clothes":
			return Color(0.78, 0.40, 1.0, 1.0)
		"special":
			return Color(1.0, 0.38, 0.58, 1.0)
		_:
			return Color(0.76, 0.93, 1.0, 1.0)


func get_shop_section_title(section: String) -> String:
	return "* " + get_shop_category_display_name(section).to_upper()


func get_filtered_shop_groups() -> Array:
	var groups = []
	var group_indexes = {}

	for item in shop_items:
		if not is_shop_item_valid(item):
			continue

		var section = get_shop_item_section(item).strip_edges().to_lower()
		if section == "":
			section = "featured"

		if selected_shop_category != "all" and section != selected_shop_category:
			continue

		var group_key = section if selected_shop_category == "all" else selected_shop_category
		if not group_indexes.has(group_key):
			group_indexes[group_key] = groups.size()
			groups.append({
				"section": group_key,
				"items": []
			})

		var group_index = int(group_indexes[group_key])
		var group = groups[group_index]
		var group_items = group["items"]
		group_items.append(item)
		group["items"] = group_items
		groups[group_index] = group

	return groups


func create_shop_section_heading(section: String, heading_position: Vector2, heading_width: float):
	if shop_items_root == null:
		return

	var accent = get_shop_section_accent(section)
	var heading = Label.new()
	heading.name = "Section_" + section
	heading.text = get_shop_section_title(section)
	heading.position = heading_position
	heading.size = Vector2(max(heading_width, 240.0), 30)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(heading, 24, Color(1.0, 1.0, 1.0, 1.0))
	shop_items_root.add_child(heading)

	var underline = ColorRect.new()
	underline.name = "SectionLine_" + section
	underline.position = heading_position + Vector2(2, 31)
	underline.size = Vector2(max(heading_width, 180.0), 3)
	underline.color = Color(accent.r, accent.g, accent.b, 0.58)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_items_root.add_child(underline)


func create_shop_item_cards():
	if shop_items_root == null:
		return

	for child in shop_items_root.get_children():
		child.queue_free()

	var visible_index = 0
	var card_size = get_shop_card_size()
	var card_width = card_size.x
	var card_height = card_size.y
	var gap_x = SHOP_CARD_GAP_X
	var gap_y = SHOP_CARD_GAP_Y
	var visible_rows = 2
	var content_x = 0.0
	var content_height = SHOP_SECTION_HEADER_HEIGHT + visible_rows * card_height + gap_y
	var groups = get_filtered_shop_groups()

	for group in groups:
		var section = str(group.get("section", "featured"))
		var items = group.get("items", [])
		if items.is_empty():
			continue

		var group_columns = max(1, int(ceil(float(items.size()) / float(visible_rows))))
		var group_width = group_columns * (card_width + gap_x) - gap_x
		create_shop_section_heading(section, Vector2(content_x, 0), group_width)

		for i in range(items.size()):
			var item = items[i]
			var column = int(floor(float(i) / float(visible_rows)))
			var row = i % visible_rows
			var card_position = Vector2(
				content_x + column * (card_width + gap_x),
				SHOP_SECTION_HEADER_HEIGHT + row * (card_height + gap_y)
			)

			create_shop_item_card(item, card_position, visible_index, card_size)
			visible_index += 1

		content_x += group_width + SHOP_SECTION_GAP

	var minimum_width = 0.0
	var minimum_height = 0.0
	if shop_scroll_container != null:
		minimum_width = shop_scroll_container.size.x
		minimum_height = shop_scroll_container.size.y
	var content_width = max(minimum_width, max(0.0, content_x - SHOP_SECTION_GAP) + 8.0)
	shop_items_root.custom_minimum_size = Vector2(content_width, max(minimum_height, content_height))
	shop_items_root.size = shop_items_root.custom_minimum_size

	if visible_index == 0:
		var empty_label = Label.new()
		empty_label.name = "Empty"
		empty_label.text = "No items in this category yet."
		empty_label.position = Vector2(20, 18)
		empty_label.size = Vector2(500, 32)
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(empty_label, 18)
		shop_items_root.add_child(empty_label)


func create_shop_item_card(item: Dictionary, card_position: Vector2, card_index: int, card_size: Vector2):
	var item_id = str(item.get("item_id", ""))
	var amount = int(item.get("amount", 1))
	var price = int(item.get("price", 1))
	var section = get_shop_item_section(item).strip_edges().to_lower()
	if section == "":
		section = "featured"
	var accent = get_shop_section_accent(section)

	var item_data = {}
	var rarity = "common"

	if world != null and world.item_database.has(item_id):
		item_data = world.item_database[item_id]
		rarity = str(item_data.get("rarity", "common"))

	var card = Panel.new()
	card.name = "ShopCard_" + item_id
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.pivot_offset = card.size * 0.5
	card.tooltip_text = get_shop_item_description(item)
	card.clip_contents = true
	apply_shop_card_style(card, card_index == 0)

	shop_items_root.add_child(card)

	var art_height = max(70.0, card.size.y - SHOP_PRICE_BAR_HEIGHT - 6.0)

	var art_back = Panel.new()
	art_back.name = "ArtBack"
	art_back.position = Vector2(5, 5)
	art_back.size = Vector2(card.size.x - 10.0, art_height)
	art_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_back.clip_contents = true
	art_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.70, 0.72, 0.73, 0.88),
		Color(0.08, 0.09, 0.12, 1.0),
		2, 2, 0
	))
	card.add_child(art_back)

	for ray_index in range(5):
		var ray = ColorRect.new()
		ray.name = "Ray_" + str(ray_index)
		ray.position = Vector2(-22.0 + float(ray_index) * 64.0, -8.0)
		ray.size = Vector2(28, art_height + 42.0)
		ray.rotation_degrees = -28.0
		ray.color = Color(1.0, 1.0, 1.0, 0.16 if ray_index % 2 == 0 else 0.08)
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_back.add_child(ray)

	var accent_wash = ColorRect.new()
	accent_wash.name = "AccentWash"
	accent_wash.position = Vector2(art_back.size.x * 0.55, 0)
	accent_wash.size = Vector2(art_back.size.x * 0.45, art_back.size.y)
	accent_wash.color = Color(accent.r, accent.g, accent.b, 0.18)
	accent_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_back.add_child(accent_wash)

	var icon_back = Panel.new()
	icon_back.name = "IconBack"
	var icon_back_size = min(88.0, max(60.0, art_height - 22.0))
	icon_back.position = Vector2((card.size.x - icon_back_size) * 0.5, 14)
	icon_back.size = Vector2(icon_back_size, icon_back_size)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	card.add_child(icon_back)

	var icon_shadow = TextureRect.new()
	icon_shadow.name = "IconShadow"
	icon_shadow.position = icon_back.position + Vector2(5, 6)
	icon_shadow.size = icon_back.size - Vector2(16, 16)
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.texture = get_item_texture(item_id)
	icon_shadow.modulate = Color(0, 0, 0, 0.36)
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_shadow)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.position = icon_back.position + Vector2(8, 6)
	icon.size = icon_back.size - Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = get_item_texture(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var badge = Panel.new()
	badge.name = "SectionBadge"
	badge.position = Vector2(card.size.x - 96.0, 11)
	badge.size = Vector2(82, 22)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent.r * 0.30, accent.g * 0.24, accent.b * 0.28, 0.88),
		Color(accent.r, accent.g, accent.b, 0.74),
		2, 7, 2
	))
	card.add_child(badge)

	var badge_label = Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.text = section.to_upper()
	badge_label.position = badge.position
	badge_label.size = badge.size
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.clip_text = true
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(badge_label, 10)
	card.add_child(badge_label)

	var name_back = ColorRect.new()
	name_back.name = "NameBack"
	name_back.position = Vector2(5, art_height - 23.0)
	name_back.size = Vector2(card.size.x - 10.0, 28)
	name_back.color = Color(0, 0, 0, 0.46)
	name_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_back)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = get_item_display_name(item_id) + " x" + str(amount)
	name_label.position = Vector2(12, art_height - 22.0)
	name_label.size = Vector2(card.size.x - 24.0, 26)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 15, Color(1.0, 1.0, 1.0, 1.0))
	card.add_child(name_label)

	var buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = ""
	var buy_button_size = Vector2(card.size.x - 10.0, SHOP_PRICE_BAR_HEIGHT)
	buy_button.size = buy_button_size
	buy_button.position = Vector2(5, card.size.y - buy_button_size.y - 5.0)
	buy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	buy_button.tooltip_text = "Buy " + get_item_display_name(item_id)
	apply_shop_price_button_style(buy_button, 22)
	buy_button.pressed.connect(_on_shop_buy_button_pressed.bind(buy_button, item_id, amount, price))
	buy_button.pivot_offset = Vector2(buy_button.size.x * 0.5, buy_button.size.y * 0.5)
	card.add_child(buy_button)

	var price_icon = TextureRect.new()
	price_icon.name = "PriceGem"
	price_icon.position = Vector2(14, 7)
	price_icon.size = Vector2(28, 28)
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	price_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		price_icon.texture = world.currency_textures["gem"]
	buy_button.add_child(price_icon)

	var price_label = Label.new()
	price_label.name = "Price"
	price_label.text = format_shop_price(price)
	price_label.position = Vector2(46, 3)
	price_label.size = Vector2(max(94.0, buy_button.size.x - 122.0), 34)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(price_label, 22, Color(1.0, 1.0, 1.0, 1.0))
	buy_button.add_child(price_label)

	var buy_label = Label.new()
	buy_label.name = "BuyText"
	buy_label.text = "BUY"
	buy_label.position = Vector2(buy_button.size.x - 64.0, 7)
	buy_label.size = Vector2(52, 28)
	buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(buy_label, 15, Color(0.90, 1.0, 0.78, 1.0))
	buy_button.add_child(buy_label)


func _on_shop_buy_button_pressed(button: Button, item_id: String, amount: int, price: int):
	play_shop_buy_button_feedback(button)
	buy_item(item_id, amount, price)


func _on_shop_buy_again_pressed(item_id: String, amount: int, price: int):
	buy_item(item_id, amount, price)


func play_shop_buy_button_feedback(button: Button):
	if button == null or not is_instance_valid(button):
		return

	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func buy_item(item_id: String, amount: int, price: int):
	if world == null:
		return

	var item_entry = get_shop_item_entry(item_id)
	if item_entry.is_empty():
		notify("That item is not available right now.")
		return

	var canonical_amount = max(1, int(item_entry.get("amount", amount)))
	var canonical_price = max(0, int(item_entry.get("price", price)))

	if request_server_shop_purchase(item_id, canonical_amount, canonical_price):
		shop_last_purchase_context = {
			"item_id": item_id,
			"amount": canonical_amount,
			"price": canonical_price
		}
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network != null:
		notify("Connection required.")
		return

	var gems = int(world.currency_inventory.get("gem", 0))

	if gems < canonical_price:
		notify("Not enough gems.")
		return

	if not world.item_database.has(item_id):
		notify("That item is not available right now.")
		return

	world.currency_inventory["gem"] = world.clamp_item_stack_count("gem", "currency", gems - canonical_price)

	var inventory_before = get_inventory_snapshot()

	if item_id == "lure_pack" and world.has_method("open_lure_pack"):
		world.open_lure_pack(canonical_amount)
	elif item_id == "basic_items_pack":
		open_basic_items_pack(canonical_amount)
	elif item_id == "hairpack":
		open_hair_pack(canonical_amount)
	elif item_id == "prestige_coloured_block_pack":
		open_prestige_coloured_block_pack(canonical_amount)
	else:
		add_item_to_inventory(item_id, canonical_amount)

	var rewards = get_inventory_delta(inventory_before)
	finalize_shop_purchase(item_id, canonical_amount, canonical_price, rewards)


func has_inventory_delta_payload(data: Dictionary) -> bool:
	var raw_delta = null
	if data.has("inventory_delta"):
		raw_delta = data.get("inventory_delta")
	elif data.has("inventory_deltas"):
		raw_delta = data.get("inventory_deltas")
	return (raw_delta is Dictionary and not raw_delta.is_empty()) or (raw_delta is Array and raw_delta.size() > 0)


func finalize_shop_purchase(item_id: String, amount: int, price: int, rewards: Array, refresh_inventory: bool = true):
	show_shop_card_purchase_feedback(item_id)

	if refresh_inventory and world.has_method("update_all_ui"):
		world.update_all_ui()

	if refresh_inventory and world.has_method("save_player_data"):
		world.save_player_data()

	update_shop_info()

	notify("Purchased " + get_item_display_name(item_id) + " x" + str(amount) + ".")
	notify_purchase_rewards(item_id, rewards, amount, price)


func show_shop_card_purchase_feedback(item_id: String):
	if shop_items_root == null:
		return

	var card = shop_items_root.get_node_or_null("ShopCard_" + item_id)
	if card == null or not is_instance_valid(card):
		return

	for child in card.get_children():
		if str(child.name).begins_with("ShopPurchase_"):
			child.queue_free()

	var glow = ColorRect.new()
	glow.name = "ShopPurchase_Glow"
	glow.position = Vector2.ZERO
	glow.size = card.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color(0.0, 0.0, 0.0, 0.0)
	card.add_child(glow)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(0.98, 0.98), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.10).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "color", Color(1.0, 0.84, 0.18, 0.28), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "color", Color(1.0, 1.0, 1.0, 0.0), 0.20).set_delay(0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func request_server_shop_purchase(item_id: String, amount: int, price: int) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("has_active_session") and not bool(network.has_active_session()):
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	var item_data = world.item_database.get(item_id, {})
	var item_category = str(item_data.get("category", ""))

	return bool(network.send_inventory_transaction_request({
		"action": "shop_buy",
		"item_id": item_id,
		"item_category": item_category,
		"amount": amount,
		"price": price
	}))


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	if str(data.get("action", "")) != "shop_buy":
		return false

	var message = str(data.get("message", "Shop transaction finished."))
	var is_success = bool(data.get("ok", false))

	if is_success:
		var purchase_item_id = str(data.get("item_id", shop_last_purchase_context.get("item_id", "")))
		var purchase_amount = int(data.get("amount", shop_last_purchase_context.get("amount", 1)))
		var purchase_price = int(data.get("price", shop_last_purchase_context.get("price", 0)))
		var rewards = data.get("rewards", [])
		if not (rewards is Array):
			rewards = []
		notify(message)
		finalize_shop_purchase(purchase_item_id, purchase_amount, purchase_price, rewards, not has_inventory_delta_payload(data))
		shop_last_purchase_context = {}
	else:
		notify(message)
		shop_last_purchase_context = {}

	update_shop_info()
	return true



func open_basic_items_pack(amount: int = 1):
	var safe_amount = max(1, amount)
	for i in range(safe_amount):
		add_item_to_inventory(roll_basic_item_from_pack(), 1)

	if world != null and world.has_method("show_notification"):
		world.show_notification("Opened Basic Items Pack x" + str(safe_amount) + ".")


func roll_basic_item_from_pack() -> String:
	return roll_item_from_pack("basic_items_pack", "messy_brown_hair")


func open_hair_pack(amount: int = 1):
	var safe_amount = max(1, amount)
	for i in range(safe_amount):
		add_item_to_inventory(roll_hair_from_pack(), 1)

	if world != null and world.has_method("show_notification"):
		world.show_notification("Opened Hair Pack x" + str(safe_amount) + ".")


func roll_hair_from_pack() -> String:
	return roll_item_from_pack("hairpack", "black_afro")


func open_prestige_coloured_block_pack(amount: int = 1):
	var safe_amount = max(1, amount)
	for i in range(safe_amount * 5):
		add_item_to_inventory(roll_item_from_pack("prestige_coloured_block_pack", "ps_blue_block"), 1)

	if world != null and world.has_method("show_notification"):
		world.show_notification("Opened Prestige Coloured Block Pack x" + str(safe_amount) + ".")


func roll_item_from_pack(pack_item_id: String, fallback_item_id: String) -> String:
	if world != null and world.item_database.has(pack_item_id):
		var pack_data = world.item_database[pack_item_id]
		if pack_data is Dictionary:
			var rewards = pack_data.get("pack_rewards", [])
			var valid_rewards = []
			var total_weight := 0
			if rewards is Array:
				for reward_entry in rewards:
					var clean_reward_id := ""
					var reward_weight := 1
					if reward_entry is Dictionary:
						clean_reward_id = str(reward_entry.get("item_id", ""))
						reward_weight = max(0, int(reward_entry.get("weight", 0)))
					else:
						clean_reward_id = str(reward_entry)

					if clean_reward_id != "" and reward_weight > 0 and world.item_database.has(clean_reward_id):
						valid_rewards.append({
							"item_id": clean_reward_id,
							"weight": reward_weight
						})
						total_weight += reward_weight
			if valid_rewards.size() > 0 and total_weight > 0:
				var roll := randi() % total_weight
				for reward in valid_rewards:
					roll -= int(reward.get("weight", 0))
					if roll < 0:
						return str(reward.get("item_id", fallback_item_id))

	return fallback_item_id


func get_inventory_snapshot() -> Dictionary:
	var snapshot = {}

	if world == null:
		return snapshot

	add_inventory_dictionary_to_snapshot(snapshot, "block", world.inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "seed", world.seed_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "tool", world.tool_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "currency", world.currency_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "material", world.material_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "lure", world.lure_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "fish", world.fish_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "back", world.back_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "hat", world.hat_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "hair", world.hair_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "eyewear", world.eyewear_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "beard", world.beard_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "shirt", world.shirt_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "pants", world.pants_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "shoes", world.shoes_inventory)
	add_inventory_dictionary_to_snapshot(snapshot, "ride", world.ride_inventory)

	return snapshot


func add_inventory_dictionary_to_snapshot(snapshot: Dictionary, category: String, source_dictionary: Dictionary):
	for item_id in source_dictionary.keys():
		snapshot[category + ":" + str(item_id)] = int(source_dictionary[item_id])


func get_inventory_delta(before_snapshot: Dictionary) -> Array:
	var rewards = []

	if world == null:
		return rewards

	add_inventory_delta_from_dictionary(rewards, before_snapshot, "block", world.inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "seed", world.seed_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "tool", world.tool_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "currency", world.currency_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "material", world.material_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "lure", world.lure_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "fish", world.fish_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "back", world.back_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "hat", world.hat_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "hair", world.hair_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "eyewear", world.eyewear_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "beard", world.beard_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "shirt", world.shirt_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "pants", world.pants_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "shoes", world.shoes_inventory)
	add_inventory_delta_from_dictionary(rewards, before_snapshot, "ride", world.ride_inventory)

	return rewards


func add_inventory_delta_from_dictionary(rewards: Array, before_snapshot: Dictionary, category: String, source_dictionary: Dictionary):
	for item_id in source_dictionary.keys():
		var key = category + ":" + str(item_id)
		var before_count = int(before_snapshot.get(key, 0))
		var after_count = int(source_dictionary[item_id])
		var gained = after_count - before_count

		if gained > 0:
			rewards.append({
				"item_id": str(item_id),
				"category": category,
				"amount": gained
			})


func notify_purchase_rewards(purchased_item_id: String, rewards: Array, purchased_amount: int = 1, purchased_price: int = 0):
	show_purchase_reward_popup(purchased_item_id, rewards, purchased_amount, purchased_price)


func get_reward_summary_text(rewards: Array) -> String:
	var parts = []

	for reward in rewards:
		var item_id = str(reward.get("item_id", ""))
		var amount = int(reward.get("amount", 0))
		var category = str(reward.get("category", ""))

		if amount <= 0:
			continue

		if category == "fish":
			parts.append(get_item_display_name(item_id) + " " + ("%.1f lb" % (float(amount) / 10.0)))
		else:
			parts.append(get_item_display_name(item_id) + " x" + str(amount))

	if parts.size() == 0:
		return "No items"

	return ", ".join(parts)


func close_purchase_reward_popup():
	if purchase_reward_popup != null:
		purchase_reward_popup.queue_free()
		purchase_reward_popup = null


func show_purchase_reward_popup(purchased_item_id: String, rewards: Array, purchased_amount: int = 1, purchased_price: int = 0):
	if shop_panel == null:
		notify("Received: " + get_reward_summary_text(rewards))
		return

	var reward_entries = normalize_reward_entries(rewards)
	var amount = max(1, int(purchased_amount))
	var price = max(0, int(purchased_price))
	if reward_entries.size() == 0 and purchased_item_id != "":
		var fallback_data = world.item_database.get(purchased_item_id, {}) if world != null else {}
		reward_entries.append({
			"item_id": purchased_item_id,
			"category": str(fallback_data.get("category", "")),
			"amount": amount
		})

	close_purchase_reward_popup()

	purchase_reward_popup = Control.new()
	purchase_reward_popup.name = "PurchaseRewardPopup"
	purchase_reward_popup.position = Vector2.ZERO
	purchase_reward_popup.size = shop_panel.size
	purchase_reward_popup.z_index = 260
	purchase_reward_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_panel.add_child(purchase_reward_popup)

	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.position = Vector2.ZERO
	dim.size = shop_panel.size
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	purchase_reward_popup.add_child(dim)

	var card_width = 560.0
	if reward_entries.size() >= 4:
		card_width = 690.0
	var card_height = 398.0
	var card_position = Vector2((shop_panel.size.x - card_width) / 2.0, (shop_panel.size.y - card_height) / 2.0 + 10.0)

	for i in range(18):
		var sparkle = ColorRect.new()
		sparkle.name = "PrizeSparkle_" + str(i)
		var sparkle_size = 5.0 + float(i % 4) * 2.0
		sparkle.size = Vector2(sparkle_size, sparkle_size * 2.2)
		var side = -1.0 if i % 2 == 0 else 1.0
		var x_offset = side * (card_width * 0.46 + float(i % 5) * 14.0)
		var y_offset = -card_height * 0.36 + float((i * 31) % 270)
		sparkle.position = card_position + Vector2(card_width * 0.5 + x_offset, card_height * 0.5 + y_offset)
		sparkle.rotation_degrees = float((i * 29) % 180)
		sparkle.color = [
			Color(1.0, 0.82, 0.18, 0.74),
			Color(0.25, 0.95, 1.0, 0.62),
			Color(0.52, 1.0, 0.28, 0.58)
		][i % 3]
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		purchase_reward_popup.add_child(sparkle)

	var glow_back = Panel.new()
	glow_back.name = "GlowBack"
	glow_back.size = Vector2(card_width + 28.0, card_height + 28.0)
	glow_back.position = card_position - Vector2(14, 14)
	glow_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(1.0, 0.67, 0.08, 0.15),
		Color(0.25, 0.90, 1.0, 0.36),
		3, 24, 18
	))
	purchase_reward_popup.add_child(glow_back)

	var card = Panel.new()
	card.name = "RewardCard"
	card.size = Vector2(card_width, card_height)
	card.position = card_position
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.84, 0.84)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.025, 0.09, 0.15, 0.99),
		Color(1.0, 0.66, 0.10, 0.94),
		5, 20, 12
	))
	purchase_reward_popup.add_child(card)

	var top_glow = ColorRect.new()
	top_glow.name = "TopGlow"
	top_glow.position = Vector2(18, 16)
	top_glow.size = Vector2(card_width - 36.0, 58)
	top_glow.color = Color(1.0, 0.74, 0.16, 0.14)
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_glow)

	for i in range(9):
		var beam = ColorRect.new()
		beam.name = "PrizeBeam_" + str(i)
		beam.size = Vector2(16, 166)
		beam.position = Vector2(card_width * 0.5 - 8.0, 122)
		beam.pivot_offset = Vector2(8, 83)
		beam.rotation_degrees = -70.0 + float(i) * 17.5
		beam.color = Color(0.38, 0.92, 1.0, 0.045) if i % 2 == 0 else Color(1.0, 0.76, 0.18, 0.055)
		beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(beam)

	var shine = ColorRect.new()
	shine.name = "DiagonalShine"
	shine.position = Vector2(-70, 36)
	shine.size = Vector2(card_width + 140.0, 24)
	shine.rotation_degrees = -12
	shine.color = Color(1.0, 1.0, 1.0, 0.055)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shine)

	var header = Panel.new()
	header.name = "Header"
	header.position = Vector2(14, 14)
	header.size = Vector2(card_width - 28.0, 62)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.09, 0.08, 0.15, 0.98),
		Color(1.0, 0.72, 0.18, 0.78),
		3, 16, 5
	))
	card.add_child(header)

	var title = Label.new()
	title.name = "Title"
	title.text = "YOU GOT!"
	title.position = Vector2(30, 21)
	title.size = Vector2(card_width - 60.0, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 36, Color(1.0, 0.92, 0.30, 1.0))
	card.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	var item_name = purchased_item_id if purchased_item_id != "" else "item"
	if world != null and world.item_database.has(purchased_item_id):
		item_name = get_item_display_name(purchased_item_id)
	var price_text = ""
	if price > 0:
		price_text = "  - " + format_shop_price(price) + " gems"
	subtitle.text = "PURCHASE COMPLETE - " + str(amount) + "x " + item_name + price_text
	if purchased_item_id == "lure_pack":
		subtitle.text = "Lure Pack opened"
	elif purchased_item_id == "basic_items_pack":
		subtitle.text = "Basic Items Pack opened"
	elif purchased_item_id == "hairpack":
		subtitle.text = "Hair Pack opened"
	elif purchased_item_id == "prestige_coloured_block_pack":
		subtitle.text = "Prestige Coloured Block Pack opened"
	subtitle.position = Vector2(32, 84)
	subtitle.size = Vector2(card_width - 64.0, 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 18)
	card.add_child(subtitle)

	var rewards_back = Panel.new()
	rewards_back.name = "RewardsBack"
	rewards_back.position = Vector2(26, 116)
	rewards_back.size = Vector2(card_width - 52.0, 150)
	rewards_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.82),
		Color(0.22, 0.82, 1.0, 0.62),
		3, 18, 6
	))
	card.add_child(rewards_back)

	var rewards_highlight = ColorRect.new()
	rewards_highlight.name = "RewardsHighlight"
	rewards_highlight.position = Vector2(42, 126)
	rewards_highlight.size = Vector2(card_width - 84.0, 5)
	rewards_highlight.color = Color(1.0, 0.86, 0.24, 0.28)
	rewards_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rewards_highlight)

	var reward_scroll = ScrollContainer.new()
	reward_scroll.name = "RewardScroll"
	reward_scroll.position = Vector2(36, 128)
	reward_scroll.size = Vector2(card_width - 72.0, 126)
	reward_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	reward_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reward_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(reward_scroll)

	var reward_root = Control.new()
	reward_root.name = "RewardItems"
	reward_root.position = Vector2.ZERO
	reward_root.size = Vector2(reward_scroll.size.x, reward_scroll.size.y)
	reward_root.custom_minimum_size = reward_root.size
	reward_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_scroll.add_child(reward_root)

	populate_purchase_reward_slots(reward_root, reward_entries, reward_scroll.size)

	var can_buy_again = (purchased_item_id != "" and not get_shop_item_entry(purchased_item_id).is_empty())
	var button_width = 182.0
	var button_height = 42.0
	var button_gap = 16.0
	var button_y = 286.0
	var button_half = button_width * 2.0 + button_gap
	var left_x = (card_width - button_half) * 0.5

	var buy_again_button = Button.new()
	buy_again_button.name = "BuyAgainButton"
	buy_again_button.text = "BUY AGAIN"
	buy_again_button.position = Vector2(left_x, button_y)
	buy_again_button.size = Vector2(button_width, button_height)
	buy_again_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_shop_arcade_button_style(buy_again_button, true, false, 18)
	buy_again_button.pressed.connect(_on_shop_buy_again_pressed.bind(purchased_item_id, amount, price))
	buy_again_button.visible = can_buy_again
	if can_buy_again and world != null:
		buy_again_button.disabled = int(world.currency_inventory.get("gem", 0)) < price
	card.add_child(buy_again_button)

	var close_x = button_width + button_gap
	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE"
	close_button.position = Vector2(
		left_x + close_x if can_buy_again else (card_width - 252.0) / 2.0,
		button_y
	)
	close_button.size = Vector2(button_width, button_height) if can_buy_again else Vector2(252.0, button_height)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_shop_arcade_button_style(close_button, false, false, 18)
	close_button.pressed.connect(close_purchase_reward_popup)
	card.add_child(close_button)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_back, "modulate", Color(1.0, 1.0, 1.0, 0.72), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var sparkle_tween = create_tween()
	sparkle_tween.set_parallel(true)
	for sparkle in purchase_reward_popup.get_children():
		if str(sparkle.name).begins_with("PrizeSparkle_"):
			sparkle_tween.tween_property(sparkle, "position:y", sparkle.position.y + 12.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			sparkle_tween.tween_property(sparkle, "modulate", Color(1.0, 1.0, 1.0, 0.38), 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func normalize_reward_entries(rewards: Array) -> Array:
	var combined = {}

	for reward in rewards:
		if not (reward is Dictionary):
			continue
		var item_id = str(reward.get("item_id", ""))
		if item_id == "":
			continue
		var item_data = world.item_database.get(item_id, {}) if world != null else {}
		var category = str(reward.get("item_category", reward.get("category", item_data.get("category", ""))))
		var amount = int(reward.get("amount", 0))
		if amount <= 0:
			continue
		var key = category + ":" + item_id
		if not combined.has(key):
			combined[key] = {
				"item_id": item_id,
				"category": category,
				"amount": 0
			}
		combined[key]["amount"] = int(combined[key]["amount"]) + amount

	var result = []
	for key in combined.keys():
		result.append(combined[key])
	return result


func populate_purchase_reward_slots(root: Control, rewards: Array, scroll_size: Vector2):
	var slot_size = 92.0
	var gap = 20.0
	var total_width = max(scroll_size.x, rewards.size() * (slot_size + gap) - gap)
	root.custom_minimum_size = Vector2(total_width, scroll_size.y)
	root.size = root.custom_minimum_size
	var start_x = max(0.0, (scroll_size.x - (rewards.size() * (slot_size + gap) - gap)) / 2.0)

	for i in range(rewards.size()):
		var reward = rewards[i]
		create_purchase_reward_slot(root, reward, Vector2(start_x + i * (slot_size + gap), 8), slot_size, i)


func create_purchase_reward_slot(root: Control, reward: Dictionary, slot_position: Vector2, slot_size: float, slot_index: int):
	var item_id = str(reward.get("item_id", ""))
	var category = str(reward.get("category", ""))
	var amount = int(reward.get("amount", 0))
	var amount_text: String = ("%.1f lb" % (float(amount) / 10.0)) if category == "fish" else "x" + str(amount)
	var rarity = "common"
	if world != null and world.item_database.has(item_id):
		rarity = str(world.item_database[item_id].get("rarity", "common"))
	var accent = get_reward_popup_accent_color(rarity)

	var glow = Panel.new()
	glow.name = "RewardGlow_" + item_id
	glow.position = slot_position - Vector2(7, 7)
	glow.size = Vector2(slot_size + 14.0, slot_size + 14.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent.r, accent.g, accent.b, 0.12),
		Color(accent.r, accent.g, accent.b, 0.34),
		2, 18, 8
	))
	root.add_child(glow)

	var slot = Panel.new()
	slot.name = "Reward_" + item_id
	slot.position = slot_position
	slot.size = Vector2(slot_size, slot_size)
	slot.pivot_offset = Vector2(slot_size * 0.5, slot_size * 0.5)
	slot.scale = Vector2(0.62, 0.62)
	slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	slot.tooltip_text = get_item_display_name(item_id) + " " + amount_text
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.035, 0.12, 0.17, 0.98),
		accent,
		4, 14, 7
	))
	root.add_child(slot)

	var top_shine = ColorRect.new()
	top_shine.name = "TopShine"
	top_shine.position = Vector2(9, 7)
	top_shine.size = Vector2(slot_size - 18.0, 7)
	top_shine.color = Color(1.0, 1.0, 1.0, 0.22)
	top_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(top_shine)

	var inner = Panel.new()
	inner.name = "Inner"
	inner.position = Vector2(6, 6)
	inner.size = Vector2(slot_size - 12.0, slot_size - 12.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent.r * 0.12, accent.g * 0.16, accent.b * 0.20, 0.78),
		Color(0.86, 0.98, 1.0, 0.20),
		1, 11, 0
	))
	slot.add_child(inner)

	var icon_shadow = TextureRect.new()
	icon_shadow.name = "IconShadow"
	icon_shadow.position = Vector2(17, 19)
	icon_shadow.size = Vector2(slot_size - 28.0, slot_size - 32.0)
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.texture = get_item_texture(item_id)
	icon_shadow.modulate = Color(0, 0, 0, 0.34)
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_shadow)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(13, 15)
	icon.size = Vector2(slot_size - 28.0, slot_size - 32.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = get_item_texture(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var amount_back = Panel.new()
	amount_back.name = "AmountBack"
	var amount_back_width: float = 58.0 if category == "fish" else 44.0
	amount_back.position = Vector2(slot_size - amount_back_width - 6.0, slot_size - 25.0)
	amount_back.size = Vector2(amount_back_width, 20)
	amount_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.005, 0.020, 0.032, 0.94),
		Color(1.0, 0.86, 0.20, 0.62),
		2, 8, 2
	))
	slot.add_child(amount_back)

	var amount_label = Label.new()
	amount_label.name = "Amount"
	amount_label.text = amount_text
	amount_label.position = amount_back.position
	amount_label.size = amount_back.size - Vector2(4, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(amount_label, 14, Color(1.0, 0.94, 0.50, 1.0))
	slot.add_child(amount_label)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = get_item_display_name(item_id)
	name_label.position = Vector2(slot_position.x - 12.0, slot_position.y + slot_size + 4.0)
	name_label.size = Vector2(slot_size + 24.0, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	PixelUIStyle.apply_small_label(name_label, 12)
	root.add_child(name_label)

	var reveal_delay = 0.08 + float(slot_index) * 0.06
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate", Color(1.0, 1.0, 1.0, 0.88), 0.18).set_delay(reveal_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.23).set_delay(reveal_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.13).set_delay(reveal_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(name_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12).set_delay(reveal_delay + 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func get_reward_popup_accent_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color(1.0, 0.72, 0.08, 1.0)
		"epic":
			return Color(0.72, 0.35, 1.0, 1.0)
		"rare":
			return Color(0.22, 0.58, 1.0, 1.0)
		"uncommon":
			return Color(0.22, 0.92, 0.45, 1.0)
		"currency":
			return Color(0.13, 0.93, 1.0, 1.0)
		_:
			return Color(0.76, 0.93, 1.0, 1.0)



func add_item_to_inventory(item_id: String, amount: int):
	var item_data = world.item_database.get(item_id, {})
	var category = str(item_data.get("category", ""))

	if category == "block":
		if not world.inventory.has(item_id):
			world.inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.inventory, item_id, category, amount)
		return

	if category == "seed":
		if not world.seed_inventory.has(item_id):
			world.seed_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.seed_inventory, item_id, category, amount)
		return

	if category == "tool":
		if not world.tool_inventory.has(item_id):
			world.tool_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.tool_inventory, item_id, category, amount)
		return

	if category == "currency":
		if not world.currency_inventory.has(item_id):
			world.currency_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.currency_inventory, item_id, category, amount)
		return

	if category == "material":
		if not world.material_inventory.has(item_id):
			world.material_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.material_inventory, item_id, category, amount)
		return

	if category == "back":
		if not world.back_inventory.has(item_id):
			world.back_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.back_inventory, item_id, category, amount)
		return

	if category == "hat":
		if not world.hat_inventory.has(item_id):
			world.hat_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.hat_inventory, item_id, category, amount)
		return

	if category == "hair":
		if not world.hair_inventory.has(item_id):
			world.hair_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.hair_inventory, item_id, category, amount)
		return

	if category == "eyewear":
		if not world.eyewear_inventory.has(item_id):
			world.eyewear_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.eyewear_inventory, item_id, category, amount)
		return

	if category == "beard":
		if not world.beard_inventory.has(item_id):
			world.beard_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.beard_inventory, item_id, category, amount)
		return

	if category == "shirt":
		if not world.shirt_inventory.has(item_id):
			world.shirt_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.shirt_inventory, item_id, category, amount)
		return

	if category == "pants":
		if not world.pants_inventory.has(item_id):
			world.pants_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.pants_inventory, item_id, category, amount)
		return

	if category == "shoes":
		if not world.shoes_inventory.has(item_id):
			world.shoes_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.shoes_inventory, item_id, category, amount)
		return

	if category == "ride":
		if not world.ride_inventory.has(item_id):
			world.ride_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.ride_inventory, item_id, category, amount)
		return

	if category == "lure":
		if not world.lure_inventory.has(item_id):
			world.lure_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.lure_inventory, item_id, category, amount)
		return

	if category == "fish":
		if not world.fish_inventory.has(item_id):
			world.fish_inventory[item_id] = 0
		var current_fish_count: int = max(0, int(floor(float(world.fish_inventory.get(item_id, 0)))))
		world.fish_inventory[item_id] = current_fish_count + max(0, amount)
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(item_id, category)
		return


func get_item_texture(item_id: String):
	if world == null:
		return null

	var item_data = world.item_database.get(item_id, {})
	var category = str(item_data.get("category", ""))
	var icon_texture = get_inventory_icon_texture(item_id, category)
	if icon_texture != null:
		return icon_texture

	if category == "block" and world.block_textures.has(item_id):
		return world.block_textures[item_id]

	if category == "seed" and world.seed_textures.has(item_id):
		return world.seed_textures[item_id]

	if category == "tool" and world.tool_textures.has(item_id):
		return world.tool_textures[item_id]

	if category == "currency" and world.currency_textures.has(item_id):
		return world.currency_textures[item_id]

	if category == "material" and world.material_textures.has(item_id):
		return world.material_textures[item_id]

	if category == "lure" and world.lure_textures.has(item_id):
		return world.lure_textures[item_id]

	if category == "fish" and world.fish_textures.has(item_id):
		return world.fish_textures[item_id]

	if category == "back":
		var icon_paths = [
			"res://Assets/player/back_item/" + item_id + "/" + item_id + "_icon.png",
			"res://Assets/player/back_item/" + item_id + "/" + item_id + "_idle.png",
			"res://Assets/player/back_item/" + item_id + "/icon.png",
			"res://Assets/player/back_item/" + item_id + "/idle.png"
		]

		for icon_path in icon_paths:
			if ResourceLoader.exists(icon_path):
				return load(icon_path)

		if world.back_textures.has(item_id):
			return world.back_textures[item_id]

	if category == "hair" and world.hair_textures.has(item_id):
		return world.hair_textures[item_id]

	if category == "hat" and world.hat_textures.has(item_id):
		return world.hat_textures[item_id]

	if category == "eyewear" and world.eyewear_textures.has(item_id):
		return world.eyewear_textures[item_id]

	if category == "beard" and world.beard_textures.has(item_id):
		return world.beard_textures[item_id]

	if category == "shirt" and world.shirt_textures.has(item_id):
		return world.shirt_textures[item_id]

	if category == "pants" and world.pants_textures.has(item_id):
		return world.pants_textures[item_id]

	if category == "shoes" and world.shoes_textures.has(item_id):
		return world.shoes_textures[item_id]

	if category == "ride" and world.ride_textures.has(item_id):
		return world.ride_textures[item_id]

	var texture = AtlasTextureFactory.load_texture(item_data.get("texture", null))
	if texture != null:
		return texture

	return null


func get_inventory_icon_texture(item_id: String, category: String):
	if world != null and world.has_method("get_inventory_icon_texture"):
		return world.get_inventory_icon_texture(item_id, category)

	return null


func get_item_display_name(item_id: String) -> String:
	if world != null and world.item_database.has(item_id):
		return str(world.item_database[item_id].get("display_name", item_id.capitalize()))

	return item_id.capitalize()


func update_shop_button_position():
	if shop_button == null:
		return

	var button_visible: bool = not is_floating_hud_blocked()
	shop_button.visible = button_visible
	if not button_visible:
		return

	var screen_size = get_viewport_rect().size
	var button_x = screen_size.x - 124.0
	if shop_button.size.x <= 72.0:
		button_x = screen_size.x - 102.0
	shop_button.position = Vector2(max(8.0, button_x), SHOP_BUTTON_Y)


func is_floating_hud_blocked() -> bool:
	return false


func update_shop_panel_position():
	if shop_panel == null:
		return

	shop_panel.position = Vector2.ZERO
	shop_panel.size = get_shop_viewport_size()


func update_shop_info():
	if world == null:
		return

	var gem_count_text = world.get_currency_display_text("gem")

	if shop_gem_label != null:
		shop_gem_label.text = gem_count_text

	if gem_hud_label != null:
		gem_hud_label.text = "x" + gem_count_text


func open_shop():
	if shop_panel == null:
		return

	if world != null and world.has_method("is_inventory_open") and world.is_inventory_open():
		if world.has_method("close_inventory_window"):
			world.close_inventory_window()

	shop_panel.visible = true
	update_shop_info()
	PixelUIStyle.play_panel_open(shop_panel)


func close_shop():
	if shop_panel == null:
		return

	close_purchase_reward_popup()
	shop_panel.visible = false


func toggle_shop():
	if is_shop_open():
		close_shop()
	else:
		if world != null and world.has_method("open_shop"):
			world.open_shop()
		else:
			open_shop()


func is_shop_open() -> bool:
	return shop_panel != null and shop_panel.visible


func notify(message: String):
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)


# Compatibility helpers kept so older code can still call them if needed.
func apply_shop_style():
	pass


func get_card_style_texture(_item_id: String) -> String:
	return ""
