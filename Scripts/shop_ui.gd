extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const SHOP_ICON_PATH := "res://Assets/ui/icons/shop.png"
const SHOP_BUTTON_SIZE := Vector2(64, 64)
const SHOP_BUTTON_Y := 100.0
const SHOP_SCENE_PATH := "res://Scenes/ui/shop/ShopSceneRedesign.tscn"

# Display data for the Gem Store's real-money packs, bound onto
# Grid_gem_store's cards by populate_gem_store_grid(). "id" must match a key
# in the server's GEM_PACKS table (PixelManiaServer/src/server_iap_routes.ts)
# - price and gem amount always come from that server-side table, never from
# the client; the fields below are curated display text/flags only. Add,
# remove, reorder, or reword a pack by editing this array - Grid_gem_store
# gains/loses cards to match automatically (see
# ShopSceneRedesign.gd's ensure_grid_card_count()).
const GEM_PACK_CARDS := [
	{"id": "pouch", "gems": 100, "price": "$0.99", "edition": "Pocket Edition"},
	{"id": "sack", "gems": 550, "price": "$4.99", "edition": "Starter Edition", "bonus": "+10% BONUS", "ribbon": "POPULAR"},
	{"id": "chest", "gems": 1200, "price": "$9.99", "edition": "Standard Edition", "bonus": "+20% BONUS", "ribbon": "BEST VALUE"},
	{"id": "vault", "gems": 3000, "price": "$19.99", "edition": "Deluxe Edition", "bonus": "+30% BONUS"},
	{"id": "mountain", "gems": 8000, "price": "$49.99", "edition": "Ultimate Edition", "bonus": "+45% BONUS", "featured": true},
]

# Editorial pick for the "Featured" tab (Grid_all, 6 cards) - there's no
# dedicated "featured" list in shop_items, and Grid_all has a fixed 6 slots
# rather than room for every item, so this is a curated highlight instead of
# an exhaustive listing (every item is still reachable from its own category
# tab). Card_all_0 is the user's own hand-designed "gem pack" card template,
# so it's bound to the Gem Store's top pack (its baked $49.99 price already
# matches "mountain" below) rather than a regular item. Edit this array to
# change what's featured - no scene editing needed.
const FEATURED_PICKS := [
	{"type": "gem_pack", "id": "mountain"},
	{"type": "item", "id": "world_lock"},
	{"type": "item", "id": "fish_monger"},
	{"type": "item", "id": "red_tractor"},
	{"type": "item", "id": "electric_tool"},
	{"type": "item", "id": "wire_cutter"},
	{"type": "item", "id": "tungsten_rod"},
]

# How long (ms) a purchase entry point stays refused after a press, so a
# rapid double-click/double-tap can't fire two purchase requests back to
# back. Purely a client-side debounce - the server (and, for Gem Store,
# Stripe/Google Play) remain the actual source of truth either way.
const SHOP_PURCHASE_DEBOUNCE_MS := 700

# get_shop_items_for_category("stations_special") folds both these
# shop_items sections into that one combined sidebar tab, since
# ShopSceneRedesign.tscn has a single merged "Stations & Special" grid
# rather than two separate ones.
const SHOP_SECTION_DISPLAY_MERGE := {
	"stations": "stations_special",
	"special": "stations_special",
}

# shop_items sections with no dedicated sidebar tab of their own fold into
# the closest existing one instead of getting dropped - see
# get_shop_items_for_category(). Today that's just "blocks" (a single item,
# prestige_coloured_block_pack) folding into the Clothes tab.
const SHOP_SECTION_FALLBACK_CATEGORY := {
	"blocks": "clothes",
}

var world = null
var ui_layer_ref = null

var shop_button = null
var shop_button_icon = null
var shop_button_icon_shadow = null
var shop_button_tween = null
var shop_button_hovered := false
var shop_panel = null
var shop_scene_wired := false
var shop_balance_label = null

# item_id (or, for Gem Store packs, "gem_pack:" + pack id) -> the live card
# Button bound to it - filled in by populate_all_shop_grids(), used by
# show_shop_card_purchase_feedback() to find a card without walking the
# whole scene tree.
var shop_card_by_key := {}

var shop_last_known_gems := -1
var shop_purchase_debounce_until := 0
var gem_hud = null
var gem_hud_icon = null
var gem_hud_label = null
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
		"item_id": "vending_machine",
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
		"description": "Auto-harvests ready trees. Uses 1 gasoline per tree for 15% more blocks and seeds on average.",
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
		"item_id": "fertilizer",
		"amount": 1,
		"price": 500,
		"section": "tools",
		"description": "Reduces a tree's remaining growth time by 1 hour. Consumed on use."
	},
	{
		"item_id": "super_fertilizer",
		"amount": 1,
		"price": 2100,
		"section": "tools",
		"description": "Reduces a tree's remaining growth time by 4 hours. Consumed on use."
	},
	{
		"item_id": "electric_tool",
		"amount": 1,
		"price": 5000,
		"section": "tools",
		"description": "Link electrical wires between transformers, pads, and devices."
	},
	{
		"item_id": "wire_cutter",
		"amount": 1,
		"price": 5000,
		"section": "tools",
		"description": "Cut wires to disconnect electrical circuits."
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
			"description": "A harvestable bait box that refills with lures every 4 hours."
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
	update_shop_button_position()
	update_shop_panel_position()
	update_shop_info()


func get_shop_viewport_size() -> Vector2:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


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

	shop_panel = ui_layer_ref.get_node_or_null("ShopUIScene")

	if shop_panel == null:
		var scene: PackedScene = load(SHOP_SCENE_PATH)
		if scene == null:
			push_warning("Shop: could not load " + SHOP_SCENE_PATH)
			return
		shop_panel = scene.instantiate()
		shop_panel.name = "ShopUIScene"
		ui_layer_ref.add_child(shop_panel)

	shop_panel.z_index = 220
	shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	cache_shop_scene_references()

	if not shop_scene_wired:
		wire_shop_scene_signals()
		shop_scene_wired = true

	populate_all_shop_grids()
	update_shop_panel_position()
	update_shop_info()


func cache_shop_scene_references():
	if shop_panel == null:
		return

	shop_balance_label = shop_panel.get_node_or_null("ShopWindow/Margin/Layout/Header/BalanceChip/BalanceLabel")


func wire_shop_scene_signals():
	if shop_panel == null:
		return

	# ShopSceneRedesign.gd owns opening/closing its own detail popup and
	# switching sidebar categories entirely on its own - the two things it
	# can't do by itself are actually closing the whole shop panel (its own
	# close button used to queue_free() the scene outright, which would
	# have destroyed this persistent, reused instance the first time a
	# player closed the shop - see close_requested below) and knowing what
	# a purchase actually costs or does (see buy_requested below).
	if shop_panel.has_signal("close_requested") and not shop_panel.close_requested.is_connected(close_shop):
		shop_panel.close_requested.connect(close_shop)

	if shop_panel.has_signal("buy_requested") and not shop_panel.buy_requested.is_connected(_on_redesign_buy_requested):
		shop_panel.buy_requested.connect(_on_redesign_buy_requested)

	# The purchase-reward popup is a permanent node in ShopSceneRedesign.tscn
	# too (PurchaseRewardOverlay) - see show_purchase_reward_popup() below.
	if shop_panel.has_signal("reward_buy_again_requested") and not shop_panel.reward_buy_again_requested.is_connected(_on_shop_buy_again_pressed):
		shop_panel.reward_buy_again_requested.connect(_on_shop_buy_again_pressed)

	wire_gem_store_iap_signals()


func wire_gem_store_iap_signals():
	var network = get_node_or_null("/root/NetworkManager")
	if network != null:
		if network.has_signal("iap_checkout_session_result") and not network.iap_checkout_session_result.is_connected(_on_iap_checkout_session_result):
			network.iap_checkout_session_result.connect(_on_iap_checkout_session_result)
		if network.has_signal("iap_purchase_result") and not network.iap_purchase_result.is_connected(_on_iap_purchase_result):
			network.iap_purchase_result.connect(_on_iap_purchase_result)


# ---------------------------------------------------------------------------
# Populating ShopSceneRedesign.tscn's static cards with real data
#
# Every card in ShopSceneRedesign.tscn is a real, permanently authored node
# (see ShopSceneRedesign.gd's class doc) instead of something built fresh
# each time the shop opens. This runs once, the first time the shop panel is
# created, and writes real item_id/amount/price plus icon/name/price display
# text onto whichever cards ShopSceneRedesign.gd's ensure_grid_card_count()
# hands back for each category - duplicating more cards from a grid's own
# last authored one if that category has more real items than hand-placed
# cards (Stations & Special today), and hiding any hand-placed extras a
# category doesn't need (Locks and Clothes today).
# ---------------------------------------------------------------------------
func populate_all_shop_grids():
	if shop_panel == null:
		return

	shop_card_by_key.clear()

	populate_item_grid("all", get_featured_shop_entries())
	populate_item_grid("locks", get_shop_items_for_category("locks"))
	populate_item_grid("stations_special", get_shop_items_for_category("stations_special"))
	populate_item_grid("clothes", get_shop_items_for_category("clothes"))
	populate_item_grid("tools", get_shop_items_for_category("tools"))
	populate_item_grid("fishing", get_shop_items_for_category("fishing"))
	populate_gem_store_grid()


# Resolves FEATURED_PICKS (see its own comment) into full item/pack
# dictionaries, silently skipping any pick whose id no longer exists so a
# renamed/removed item or pack can't crash the Featured tab.
func get_featured_shop_entries() -> Array:
	var entries = []
	for pick in FEATURED_PICKS:
		var pick_type = str(pick.get("type", "item"))
		var pick_id = str(pick.get("id", ""))
		if pick_type == "gem_pack":
			for pack_data in GEM_PACK_CARDS:
				if str(pack_data.get("id", "")) == pick_id:
					entries.append(pack_data)
					break
		else:
			var entry = get_shop_item_entry(pick_id)
			if not entry.is_empty() and is_shop_item_valid(entry):
				entries.append(entry)
	return entries


# Real shop_items entries for one sidebar category, in shop_items' own
# order - "stations_special" pulls from both the "stations" and "special"
# sections (SHOP_SECTION_DISPLAY_MERGE), and a section with no sidebar tab
# of its own (SHOP_SECTION_FALLBACK_CATEGORY) folds into whichever tab that
# maps to instead of being dropped.
func get_shop_items_for_category(category_key: String) -> Array:
	var items = []
	for item in shop_items:
		if not (item is Dictionary) or not is_shop_item_valid(item):
			continue
		var section = get_shop_item_section(item).strip_edges().to_lower()
		if section == "":
			section = "featured"
		section = str(SHOP_SECTION_DISPLAY_MERGE.get(section, section))
		section = str(SHOP_SECTION_FALLBACK_CATEGORY.get(section, section))
		if section == category_key:
			items.append(item)
	return items


# Binds `items` (shop_items entries, or - for the Featured tab only - a mix
# of shop_items entries and GEM_PACK_CARDS entries) onto category_key's
# grid, growing/shrinking its visible card count to match via
# ShopSceneRedesign.gd's ensure_grid_card_count().
func populate_item_grid(category_key: String, items: Array) -> void:
	if shop_panel == null or not shop_panel.has_method("ensure_grid_card_count"):
		return

	var cards = shop_panel.ensure_grid_card_count(category_key, items.size())
	for i in range(items.size()):
		if i >= cards.size():
			break
		var entry = items[i]
		if entry.has("gems"):
			bind_gem_pack_card(cards[i], entry)
		else:
			bind_item_card(cards[i], entry, category_key)


func populate_gem_store_grid() -> void:
	if shop_panel == null or not shop_panel.has_method("ensure_grid_card_count"):
		return

	var cards = shop_panel.ensure_grid_card_count("gem_store", GEM_PACK_CARDS.size())
	for i in range(GEM_PACK_CARDS.size()):
		if i >= cards.size():
			break
		bind_gem_pack_card(cards[i], GEM_PACK_CARDS[i])


# Writes one real shop_items entry onto a card: real icon/name/price text,
# plus set_meta("item_id"/"amount"/"price"/"is_gem_pack") so
# ShopSceneRedesign.gd's detail popup can report it back via buy_requested.
# On the Featured tab only, NameLabel2 (empty on every other card - see
# ShopSceneRedesign.tscn) shows the item's own category as a small tag,
# since Featured mixes categories together.
# Item/pack names vary a lot in length ("CCTV" vs "Night Theme Machine"), but
# NameLabel/NameLabel2's width is fixed by the shared card template (same
# rect on every card, see the project notes on the Card_all_0 template
# rollout) and clip_text was silently clipping long names from BOTH sides
# instead of wrapping - "Night Theme Machine" rendered as "ight Theme Machin".
# The shared card layout reserves two lines per label. Keep normal text
# readable and wrap long pack names instead of shrinking or clipping them.


func _set_shop_name_label_text(name_label: Label, text: String) -> void:
	if name_label == null:
		return
	name_label.text = text
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.set_meta("pixelmania_font_role", "body")
	name_label.add_theme_font_size_override("font_size", 24)


func bind_item_card(card: Button, item: Dictionary, category_key: String) -> void:
	var item_id = str(item.get("item_id", ""))
	var amount = int(item.get("amount", 1))
	var price = int(item.get("price", 0))
	var display_name = get_item_display_name(item_id)
	if amount > 1:
		display_name += " x" + str(amount)

	card.set_meta("item_id", item_id)
	card.set_meta("amount", amount)
	card.set_meta("price", price)
	card.set_meta("is_gem_pack", false)
	card.tooltip_text = get_shop_item_description(item)
	card.visible = true

	var icon_slot = card.get_node_or_null("IconSlot")
	var icon = icon_slot.get_node_or_null("Icon") if icon_slot != null else null
	if icon != null:
		icon.texture = get_item_texture(item_id)

	var name_label = card.get_node_or_null("NameLabel")
	_set_shop_name_label_text(name_label, display_name)

	var name_label2 = card.get_node_or_null("NameLabel2")
	if category_key == "all":
		var item_section = get_shop_item_section(item).strip_edges().to_lower()
		_set_shop_name_label_text(name_label2, get_shop_category_display_name(item_section).to_upper())
	else:
		_set_shop_name_label_text(name_label2, "")

	var price_label = card.get_node_or_null("PriceLabel")
	if price_label != null:
		price_label.text = format_shop_price(price) + " GEMS"

	shop_card_by_key[item_id] = card


# Writes one Gem Store pack onto a card: display text plus
# set_meta("item_id"/"is_gem_pack") so the detail popup's Buy button routes
# to the real-money purchase flow (Stripe/Google Play) instead of the
# in-game-gems one. price/amount meta stay at their bind_item_card defaults
# (0/1) since Gem Store purchases are priced and fulfilled server-side, not
# by anything the client sends - see _on_gem_pack_buy_pressed().
func bind_gem_pack_card(card: Button, pack_data: Dictionary) -> void:
	var pack_id = str(pack_data.get("id", ""))
	var gems = int(pack_data.get("gems", 0))
	var edition = str(pack_data.get("edition", ""))
	var price_text = str(pack_data.get("price", "$0.00"))

	card.set_meta("item_id", pack_id)
	card.set_meta("amount", 1)
	card.set_meta("price", 0)
	card.set_meta("is_gem_pack", true)
	card.tooltip_text = edition
	card.visible = true

	var icon_slot = card.get_node_or_null("IconSlot")
	var icon = icon_slot.get_node_or_null("Icon") if icon_slot != null else null
	if icon != null and world != null and world.currency_textures.has("gem"):
		icon.texture = world.currency_textures["gem"]

	var name_label = card.get_node_or_null("NameLabel")
	_set_shop_name_label_text(name_label, format_shop_price(gems) + " GEMS")

	var name_label2 = card.get_node_or_null("NameLabel2")
	_set_shop_name_label_text(name_label2, edition.to_upper())

	var price_label = card.get_node_or_null("PriceLabel")
	if price_label != null:
		price_label.text = price_text

	shop_card_by_key["gem_pack:" + pack_id] = card


# Routes ShopSceneRedesign.gd's detail-popup Buy press into whichever real
# purchase flow the card's own metadata (see bind_item_card()/
# bind_gem_pack_card() above) says it needs - both flows already existed
# for the old scene and are untouched here.
func _on_redesign_buy_requested(item_id: String, amount: int, price: int, is_gem_pack: bool) -> void:
	if is_gem_pack:
		_on_gem_pack_card_buy_pressed(item_id, _gem_pack_label(item_id))
	else:
		_on_shop_item_card_buy_pressed(item_id, amount, price)


func _gem_pack_label(pack_id: String) -> String:
	for pack_data in GEM_PACK_CARDS:
		if str(pack_data.get("id", "")) == pack_id:
			return format_shop_price(int(pack_data.get("gems", 0))) + " Gems"
	return "Gems"


# Gates every Gem Store pack purchase button press behind a rapid-click
# debounce, then goes straight into the actual checkout/purchase flow in
# _on_gem_pack_buy_pressed() below (no confirmation step - the debounce is
# the only guard against accidental double-taps).
func _on_gem_pack_card_buy_pressed(pack_id: String, pack_label: String):
	if Time.get_ticks_msec() < shop_purchase_debounce_until:
		return
	shop_purchase_debounce_until = Time.get_ticks_msec() + SHOP_PURCHASE_DEBOUNCE_MS

	_on_gem_pack_buy_pressed(pack_id, pack_label)


func _on_gem_pack_buy_pressed(pack_id: String, pack_label: String):
	if pack_id == "":
		# Bundles like the Starter Pack aren't in the server's GEM_PACKS table yet (they mix
		# gems with other items, which needs its own design pass) -- keep the honest stub here
		# until that's built.
		notify(pack_label + " isn't available yet - check back soon.")
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or (network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server())):
		notify("Connection required.")
		return

	if OS.get_name() == "Android":
		if not network.has_method("send_iap_submit_google_play_purchase_request"):
			notify("Purchases are not available yet.")
			return
		_start_google_play_purchase(pack_id, pack_label)
		return

	if not network.has_method("send_iap_create_stripe_checkout_request"):
		notify("Purchases are not available yet.")
		return

	notify("Opening checkout for " + pack_label + "...")
	network.send_iap_create_stripe_checkout_request(pack_id)


func _on_iap_checkout_session_result(data: Dictionary) -> void:
	if not bool(data.get("ok", false)):
		notify(str(data.get("error", "Could not start checkout. Try again.")))
		return

	var checkout_url = str(data.get("checkout_url", ""))
	if checkout_url == "":
		notify("Could not start checkout. Try again.")
		return

	# Payment happens entirely on Stripe's hosted page in the system browser -- the game never
	# touches card details, and gems are only credited once Stripe's server confirms payment
	# (see server_iap_routes.ts handleStripeWebhookHttpRequest). The Gem Store HUD updates on
	# its own once that happens; there is nothing to poll for here.
	OS.shell_open(checkout_url)
	notify("Complete your purchase in the browser that just opened.")


# The BillingClient autoload owns Play lifecycle and forwards receipts to the server.
# Preview is explicit and stops before native checkout or receipt submission.
func _start_google_play_purchase(pack_id: String, pack_label: String, preview_only: bool = false) -> Dictionary:
	var billing = get_node_or_null("/root/BillingClient")
	if billing == null:
		notify("Purchases are not available yet.")
		return {}
	if not billing.billing_message.is_connected(notify):
		billing.billing_message.connect(notify)
	var network = get_node_or_null("/root/NetworkManager")
	var username = str(network.session_username) if network != null else ""
	billing.set_obfuscated_account_id(username)
	if not preview_only:
		notify("Opening Google Play checkout for " + pack_label + "...")
	return billing.purchase("gems_" + pack_id, preview_only)

func _on_iap_purchase_result(data: Dictionary) -> void:
	if not bool(data.get("ok", false)):
		notify(str(data.get("error", "Purchase could not be completed.")))
		return

	var gems_granted = int(data.get("gems_granted", 0))
	if gems_granted > 0:
		notify("You received " + str(gems_granted) + " gems!")


# Category-tab switching (including "GetGemsButton jumps to the Gem Store
# tab") is now handled entirely inside ShopSceneRedesign.gd itself - see its
# _on_sidebar_button_toggled()/_on_get_gems_pressed(). Nothing here needs to
# drive it.


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


func get_shop_category_display_name(category: String) -> String:
	match category:
		"all":
			return "Featured"
		"gem_store":
			return "Gem Store"
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
		"stations_special":
			return "Stations & Special"
		_:
			return category.capitalize()


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


func get_shop_item_entry(item_id: String) -> Dictionary:
	for item in shop_items:
		if not (item is Dictionary):
			continue
		if str(item.get("item_id", "")) == item_id:
			return item
	return {}


# Category-tab switching used to be routed through here from the dynamic
# CategoryNav pills; ShopSceneRedesign.gd's static sidebar buttons now
# switch tabs (and reveal the right Grid_*) entirely on their own - see its
# _on_sidebar_button_toggled().


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


# Section-grouped headings, dynamic column counts, and building a fresh set
# of ShopItemCardScene instances per category switch were all specific to
# ShopScene.tscn's runtime-built layout. ShopSceneRedesign.tscn's cards are
# permanent authored nodes populated once by populate_all_shop_grids() (see
# above) instead, and its GridContainers keep whatever fixed column count is
# authored in the .tscn.


# No confirmation step - a rapid-click debounce is the only guard against
# accidental double-taps here, same as the Gem Store pack flow above.
func _on_shop_item_card_buy_pressed(item_id: String, amount: int, price: int) -> void:
	if Time.get_ticks_msec() < shop_purchase_debounce_until:
		return
	shop_purchase_debounce_until = Time.get_ticks_msec() + SHOP_PURCHASE_DEBOUNCE_MS
	buy_item(item_id, amount, price)


func _on_shop_buy_again_pressed(item_id: String, amount: int, price: int):
	if Time.get_ticks_msec() < shop_purchase_debounce_until:
		return
	shop_purchase_debounce_until = Time.get_ticks_msec() + SHOP_PURCHASE_DEBOUNCE_MS
	buy_item(item_id, amount, price)


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

	if shop_panel != null and shop_panel.has_method("show_purchase_success_feedback"):
		shop_panel.show_purchase_success_feedback()

	if refresh_inventory and world.has_method("update_all_ui"):
		world.update_all_ui()

	if refresh_inventory and world.has_method("save_player_data"):
		world.save_player_data()

	update_shop_info()

	notify("Purchased " + get_item_display_name(item_id) + " x" + str(amount) + ".")
	notify_purchase_rewards(item_id, rewards, amount, price)


func show_shop_card_purchase_feedback(item_id: String):
	var card = shop_card_by_key.get(item_id)
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
	if shop_panel != null and shop_panel.has_method("hide_reward_popup"):
		shop_panel.hide_reward_popup()


# The "YOU GOT!" popup is a permanent node in ShopSceneRedesign.tscn now
# (PurchaseRewardOverlay), styled with the Shop's own panel/button textures
# directly in the editor - this fills in the one-off text/target data and
# writes the actual reward-item tiles into shop_panel.reward_items_container
# (see populate_purchase_reward_slots()/create_purchase_reward_slot() below,
# unchanged - they still read real icon/rarity data from item_database, which
# ShopSceneRedesign.gd deliberately has no access to).
func show_purchase_reward_popup(purchased_item_id: String, rewards: Array, purchased_amount: int = 1, purchased_price: int = 0):
	if shop_panel == null:
		notify("Received: " + get_reward_summary_text(rewards))
		return
	if not shop_panel.has_method("show_reward_popup"):
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

	var item_name = purchased_item_id if purchased_item_id != "" else "item"
	if world != null and world.item_database.has(purchased_item_id):
		item_name = get_item_display_name(purchased_item_id)
	var price_text = ""
	if price > 0:
		price_text = "  - " + format_shop_price(price) + " gems"
	var subtitle_text = "PURCHASE COMPLETE - " + str(amount) + "x " + item_name + price_text
	if purchased_item_id == "lure_pack":
		subtitle_text = "Lure Pack opened"
	elif purchased_item_id == "basic_items_pack":
		subtitle_text = "Basic Items Pack opened"
	elif purchased_item_id == "hairpack":
		subtitle_text = "Hair Pack opened"
	elif purchased_item_id == "prestige_coloured_block_pack":
		subtitle_text = "Prestige Coloured Block Pack opened"

	var can_buy_again = (purchased_item_id != "" and not get_shop_item_entry(purchased_item_id).is_empty())
	var buy_again_disabled = false
	if can_buy_again and world != null:
		buy_again_disabled = int(world.currency_inventory.get("gem", 0)) < price

	var reward_root: Control = shop_panel.reward_items_container
	for child in reward_root.get_children():
		child.queue_free()

	shop_panel.show_reward_popup(subtitle_text, can_buy_again, buy_again_disabled, purchased_item_id, amount, price)

	populate_purchase_reward_slots(reward_root, reward_entries, shop_panel.reward_scroll.size)


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
	# Direct size assignment on a full-rect-anchored Control fights the anchor system (the
	# engine warns "size will be overridden after _ready()" and suggests set_deferred() --
	# harmless here since this only runs on setup/resize, not per-frame).
	shop_panel.set_deferred("size", get_shop_viewport_size())


func update_shop_info():
	if world == null:
		return

	var gems = int(world.currency_inventory.get("gem", 0))
	var gem_count_text = world.get_currency_display_text("gem")

	if shop_balance_label != null:
		shop_balance_label.text = gem_count_text

	if gem_hud_label != null:
		gem_hud_label.text = "x" + gem_count_text

	# update_shop_info() already runs every frame (see _process()) to keep the
	# gem label live, but recomputing which cards are affordable is only
	# worth doing when the gem count actually changed - not 60 times a second.
	if gems != shop_last_known_gems:
		shop_last_known_gems = gems
		refresh_shop_affordability(gems)


# Keep the open detail popup in sync without disabling item browsing.
func refresh_shop_affordability(gems: int = -1) -> void:
	if shop_panel == null or not shop_panel.has_method("set_available_gems"):
		return
	if gems < 0:
		gems = int(world.currency_inventory.get("gem", 0)) if world != null else 0
	shop_panel.set_available_gems(gems)


func open_shop():
	if shop_panel == null:
		return

	if world != null and world.has_method("is_inventory_open") and world.is_inventory_open():
		if world.has_method("close_inventory_window"):
			world.close_inventory_window()

	shop_panel.visible = true

	# Every time the shop opens: back to the Featured tab, detail popup
	# closed, product list scrolled to the top - a reopened shop should never
	# surface mid-scroll or mid-detail-popup from last time. The redesigned
	# scene's cards are permanent authored nodes populated once by
	# populate_all_shop_grids() (called from setup_shop_panel()), not rebuilt
	# per open, so there's no rebuild step here anymore.
	if shop_panel.has_method("reset_to_default_view"):
		shop_panel.reset_to_default_view()

	update_shop_info()
	refresh_shop_affordability()
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
