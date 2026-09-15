extends Control

## Growtopia-style Shop layout - the live, wired-up Shop scene.
##
## EVERYTHING VISUAL LIVES IN THE SCENE, NOT IN THIS SCRIPT.
## Every panel, button, icon, item card, and piece of text - the sidebar
## buttons, all item cards across every category tab, the detail popup's
## own layout - is a real, authored node sitting in ShopSceneRedesign.tscn.
## Open the scene in the Godot editor (no need to press Play) and you will
## see all of it: select any node in the Scene panel and the Inspector
## lets you swap its texture, edit its text, tweak its color, resize it,
## etc. This script never builds or styles any of that, so nothing you
## change in the editor gets overwritten or reset when you press Play.
##
## This script owns the handful of things that can't be static data: which
## category tab is currently showing, opening/closing the detail popup for
## whichever item was clicked, and small interaction juice (hover lift,
## button squish, buy sparkle burst, panel open/close animation).
##
## Real data (which real item_id/price backs each card, the live gem
## balance, actually executing a purchase) is owned by Scripts/shop_ui.gd,
## the same separation shop_item_card.gd/gem_pack_card.gd already used for
## the old scene: this script reports back to its owner via signals instead
## of reaching into shop_ui.gd itself, so it still has no hard dependency
## on shop_ui.gd, world, NetworkManager, item_database, or save data.
## shop_ui.gd calls ensure_grid_card_count() once per category to make sure
## there are enough cards for the real item list (duplicating the last
## authored card in a grid as a template for any it's short on - the same
## "duplicate a template" pattern the sidebar's own category buttons used
## to use), then writes real icon/name/price data and item metadata
## (set_meta("item_id"/"amount"/"price"/"is_gem_pack")) onto each card
## directly. Clicking a card still just opens the detail popup, exactly as
## before; pressing the detail popup's own Buy button now reads that
## metadata and emits buy_requested(item_id, amount, price, is_gem_pack),
## which shop_ui.gd connects to and routes into the real purchase flow
## (in-game gems for regular items, Stripe/Google Play for Gem Store packs).
##
## Adding a new item: duplicate any Card_* button (Ctrl+D) inside its
## category's grid, drop it in place, and edit its Icon texture, IconSlot
## modulate (rarity tint), NameLabel text, PriceLabel text, and the card's
## own Tooltip text (used as the description in the popup) - all directly
## in the Inspector, no script edits. shop_ui.gd overwrites the name/price/
## icon/tooltip with real data at runtime anyway, so these are previews for
## editing purposes, not the actual live values - what matters is that the
## card exists so shop_ui.gd's real item list has somewhere to bind to.
##
## Adding a new sidebar/category tab: duplicate a Btn_* button under
## Sidebar and a Grid_* container under ItemScroll (keep their positions
## in sync - the sidebar button at index N controls the grid at index N),
## then add that button to the same ButtonGroup and give the new grid
## `visible = false`. Also give shop_ui.gd's get_shop_items_for_category()
## a case for the new category key so real items actually get bound to it.

## Emitted when the detail popup's Buy button is pressed, carrying whatever
## metadata shop_ui.gd bound onto the clicked card (see ensure_grid_card_count()
## and the class doc above). shop_ui.gd is the only intended listener; this
## script never validates the purchase itself.
signal buy_requested(item_id: String, amount: int, price: int, is_gem_pack: bool)

## Emitted when the player presses the header's Close button. shop_ui.gd
## connects this to its real close_shop() (which just hides shop_panel -
## the same persistent instance is reused every time the shop reopens, see
## setup_shop_panel()/cache_shop_scene_references() in shop_ui.gd). This
## script must NEVER queue_free() itself on close: shop_ui.gd never creates
## a second instance, so destroying this one would permanently break the
## shop until the whole scene reloaded.
signal close_requested

## Emitted when the reward popup's Buy Again button is pressed, carrying
## whatever item_id/amount/price show_reward_popup() was last told to use for
## it - shop_ui.gd is the only intended listener.
signal reward_buy_again_requested(item_id: String, amount: int, price: int)

const STAR_TEXTURE: Texture2D = preload("res://Assets/effects/confetti_star.svg")

@onready var shop_window: Panel = $ShopWindow
@onready var get_gems_button: Button = $ShopWindow/Margin/Layout/Header/GetGemsButton
@onready var close_button: Button = $ShopWindow/Margin/Layout/Header/CloseButton
@onready var balance_chip: Panel = $ShopWindow/Margin/Layout/Header/BalanceChip
@onready var sidebar: VBoxContainer = $ShopWindow/Margin/Layout/Body/Sidebar
@onready var category_title_label: Label = $ShopWindow/Margin/Layout/Body/MainPane/CategoryTitleLabel
@onready var item_scroll: ScrollContainer = $ShopWindow/Margin/Layout/Body/MainPane/ItemScrollRow/ItemScroll
@onready var item_scroll_slider: Control = $ShopWindow/Margin/Layout/Body/MainPane/ItemScrollRow/ItemScrollSlider
@onready var item_scroll_track: NinePatchRect = $ShopWindow/Margin/Layout/Body/MainPane/ItemScrollRow/ItemScrollSlider/Track
@onready var item_scroll_handle: NinePatchRect = $ShopWindow/Margin/Layout/Body/MainPane/ItemScrollRow/ItemScrollSlider/Handle
@onready var detail_overlay: Control = $DetailOverlay
@onready var dim: ColorRect = $DetailOverlay/Dim
@onready var detail_card: Panel = $DetailOverlay/DetailCard
@onready var detail_icon_slot: TextureRect = $DetailOverlay/DetailCard/DetailIconSlot
@onready var detail_icon: TextureRect = $DetailOverlay/DetailCard/DetailIconSlot/DetailIcon
@onready var detail_name_label: Label = $DetailOverlay/DetailCard/Margin/Column/DetailNameLabel
@onready var detail_desc_label: Label = $DetailOverlay/DetailCard/Margin/Column/DetailDescLabel
@onready var detail_close_button: Button = $DetailOverlay/DetailCard/Margin/Column/TopRow/DetailCloseButton
@onready var detail_buy_button: Button = $DetailOverlay/DetailCard/Margin/Column/DetailBuyButton

@onready var reward_overlay: Control = $PurchaseRewardOverlay
@onready var reward_glow_back: Panel = $PurchaseRewardOverlay/GlowBack
@onready var reward_card: Panel = $PurchaseRewardOverlay/RewardCard
@onready var reward_subtitle_label: Label = $PurchaseRewardOverlay/RewardCard/Subtitle
@onready var reward_scroll: ScrollContainer = $PurchaseRewardOverlay/RewardCard/RewardScroll
@onready var reward_items_container: Control = $PurchaseRewardOverlay/RewardCard/RewardScroll/RewardItems
@onready var reward_buy_again_button: Button = $PurchaseRewardOverlay/RewardCard/ButtonRow/BuyAgainButton
@onready var reward_close_button: Button = $PurchaseRewardOverlay/RewardCard/ButtonRow/CloseButton

# What show_reward_popup() should report back if the Buy Again button is
# pressed - see _on_reward_buy_again_pressed() below.
var _reward_buy_again_item_id := ""
var _reward_buy_again_amount := 1
var _reward_buy_again_price := 0

# Sidebar button i -> the category grid it should reveal. Paired by child
# order, so a sidebar button and its matching grid must stay at the same
# index (see the "adding a new sidebar tab" note above).
var _sidebar_buttons: Array[Button] = []
var _category_grids: Array[GridContainer] = []

# The card currently shown in the detail popup, so _on_detail_buy_pressed()
# knows what to report via buy_requested() - set by _open_detail() from
# whatever shop_ui.gd (or nothing yet, if this scene is opened stand-alone in
# the editor) stored on the card via set_meta().
var _detail_item_id := ""
var _detail_amount := 1
var _detail_price := 0
var _detail_is_gem_pack := false
var _available_gems := 0
var _detail_price_text := ""
var _shop_fit_scale := 1.0
var _panel_open_tweens: Dictionary = {}

# Custom scrollbar drag state (see "item scroll slider" section below) - one
# Track+Handle pair lives outside ItemScroll's own ScrollContainer, as a
# sibling under ItemScrollRow, so it's shared by every category tab rather
# than duplicated per tab: only one Grid_* is ever visible at a time inside
# ItemScroll, so the same Handle simply follows whichever tab's scroll range
# is currently active.
var _item_scroll_handle_dragging := false
var _item_scroll_handle_touch_index := -1
var _item_scroll_handle_drag_offset_y := 0.0
var _item_scroll_layout_sync_queued := false


func _ready() -> void:
	_sidebar_buttons.assign(sidebar.get_children())
	_category_grids.assign(item_scroll.get_children())
	# Keep categories reachable on short phone screens without shrinking text.
	var category_scroll := ScrollContainer.new()
	category_scroll.name = "CategoryScroll"
	category_scroll.custom_minimum_size.x = 140
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := sidebar.get_parent()
	body.add_child(category_scroll)
	body.move_child(category_scroll, 0)
	sidebar.reparent(category_scroll)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in _sidebar_buttons:
		button.custom_minimum_size = Vector2(124, 44)
		button.custom_maximum_size = Vector2(-1, -1)
	category_title_label.custom_minimum_size = Vector2(0, 40)

	for i in range(_sidebar_buttons.size()):
		var button := _sidebar_buttons[i]
		button.toggled.connect(_on_sidebar_button_toggled.bind(i))
		_wire_hover_lift(button)

	for grid in _category_grids:
		for card in grid.get_children():
			if card is Button:
				_wire_card_interactions(card)

	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not get_gems_button.pressed.is_connected(_on_get_gems_pressed):
		get_gems_button.pressed.connect(_on_get_gems_pressed)
	detail_close_button.pressed.connect(_close_detail)
	detail_buy_button.pressed.connect(_on_detail_buy_pressed)
	dim.gui_input.connect(_on_dim_gui_input)

	reward_buy_again_button.pressed.connect(_on_reward_buy_again_pressed)
	reward_close_button.pressed.connect(hide_reward_popup)
	reward_overlay.visible = false

	_setup_item_scroll_slider()
	resized.connect(_fit_shop_window)
	_fit_shop_window()

	detail_overlay.visible = false
	_play_panel_open(shop_window)


# ------------------------------------------------------------- header ----

func _on_close_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func():
		# Restore full opacity before handing off - shop_ui.gd's close_shop()
		# only sets visible = false, it never touches modulate, so leaving
		# this at 0 would make the panel invisible the next time it's shown.
		modulate.a = 1.0
		close_requested.emit()
	)


func _on_get_gems_pressed() -> void:
	var tween := balance_chip.create_tween()
	tween.tween_property(balance_chip, "scale", Vector2(1.1, 1.1), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(balance_chip, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Jump to the Gem Store tab, same as clicking its sidebar icon.
	for i in range(_sidebar_buttons.size()):
		if _sidebar_buttons[i].tooltip_text == "Gem Store":
			_sidebar_buttons[i].button_pressed = true
			break


# ------------------------------------------------------------ category ----

func _on_sidebar_button_toggled(toggled_on: bool, index: int) -> void:
	if not toggled_on:
		return
	category_title_label.text = _sidebar_buttons[index].tooltip_text.to_upper()
	for i in range(_category_grids.size()):
		_category_grids[i].visible = (i == index)

	# A newly-selected tab almost certainly has a different scrollable range
	# than the one just left (more/fewer rows), so start it scrolled to the
	# top rather than carrying over wherever the last tab happened to be,
	# and re-sync the custom Handle to match.
	item_scroll.scroll_vertical = 0
	_queue_item_scroll_slider_sync()


# Looks up a category's grid by the same key shop_ui.gd already uses for
# icons/display names (SHOP_CATEGORY_ICON_PATHS) - "all" -> Grid_all,
# "gem_store" -> Grid_gem_store, "stations_special" -> Grid_stations_special,
# etc. Returns null if that category has no grid yet (see the "adding a new
# sidebar tab" note above).
func get_category_grid(category_key: String) -> GridContainer:
	var grid_node = item_scroll.get_node_or_null("Grid_" + category_key)
	return grid_node if grid_node is GridContainer else null


## Makes sure `category_key`'s grid has at least `count` interactive cards,
## duplicating its last authored Card_* as a template for any it's short on
## (wiring each duplicate's press/hover exactly like an authored one - see
## _wire_card_interactions()), and hides any authored cards beyond `count`
## rather than deleting them (so re-running this after a data reload never
## loses hand-authored extras). Returns the full list of cards in child
## order, `count` of which are left visible - shop_ui.gd binds real item
## data onto whatever this returns.
func ensure_grid_card_count(category_key: String, count: int) -> Array:
	var grid := get_category_grid(category_key)
	if grid == null:
		return []

	var cards: Array = []
	for child in grid.get_children():
		if child is Button:
			cards.append(child)

	if cards.is_empty():
		return []

	while cards.size() < count:
		var template: Button = cards[cards.size() - 1]
		var new_card: Button = template.duplicate()
		grid.add_child(new_card)
		_wire_card_interactions(new_card)
		cards.append(new_card)

	for i in range(cards.size()):
		cards[i].visible = i < count

	return cards


## Called by shop_ui.gd's open_shop() every time the shop is (re)opened, so it
## never surfaces mid-scroll or on whatever category/detail state it was left
## on last time - jumps back to the Featured tab (sidebar index 0, Btn_all),
## closes the detail popup if it was left open, and scrolls the item list
## back to the top.
func reset_to_default_view() -> void:
	if _sidebar_buttons.size() > 0:
		_sidebar_buttons[0].button_pressed = true
	item_scroll.scroll_vertical = 0
	if detail_overlay.visible:
		_on_detail_closed()
	# button_pressed = true above only emits "toggled" (and therefore only
	# re-syncs the custom scrollbar Handle via _on_sidebar_button_toggled())
	# when Featured wasn't already the active tab - cover the "it already was"
	# case explicitly too, so the Handle is never left stale on reopen.
	_queue_item_scroll_slider_sync()


func _wire_card_interactions(card: Button) -> void:
	card.custom_minimum_size.y = 250
	for label_name in ["NameLabel", "NameLabel2"]:
		var label := card.get_node_or_null(label_name) as Label
		if label != null:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = false
			label.offset_top = 8 if label_name == "NameLabel" else 56
			label.offset_bottom = 56 if label_name == "NameLabel" else 104
	var art := card.get_node_or_null("IconSlot") as Control
	if art != null:
		art.offset_bottom = 214
		var icon := art.get_node_or_null("Icon") as Control
		if icon != null:
			icon.offset_top = 104
	var price := card.get_node_or_null("PriceLabel") as Control
	if price != null:
		price.offset_top = 216
		price.offset_bottom = 246
	if not card.pressed.is_connected(_on_item_card_pressed):
		card.pressed.connect(_on_item_card_pressed.bind(card))
	_wire_hover_lift(card)


# ------------------------------------------------------ item scroll slider ----
# A custom-skinned scrollbar (Track + Handle, both real authored TextureRect
# nodes under ItemScrollRow/ItemScrollSlider - swap their `texture` in the
# Inspector for a different look, no script changes needed) standing in for
# ItemScroll's native one (hidden via `vertical_scroll_mode = 3` in the
# .tscn). There's exactly one ItemScroll shared by every category tab - only
# the currently-selected Grid_* is visible inside it - so this single Handle
# already follows whichever tab is active with no per-tab duplication;
# _on_sidebar_button_toggled() above just re-syncs it (and resets scroll to
# the top) whenever the tab actually changes.

func _setup_item_scroll_slider() -> void:
	if item_scroll_slider == null or item_scroll_track == null or item_scroll_handle == null:
		return

	var internal_scrollbar: VScrollBar = item_scroll.get_v_scroll_bar()
	if internal_scrollbar != null:
		if not internal_scrollbar.value_changed.is_connected(_on_item_scroll_changed):
			internal_scrollbar.value_changed.connect(_on_item_scroll_changed)
		if not internal_scrollbar.changed.is_connected(_queue_item_scroll_slider_sync):
			internal_scrollbar.changed.connect(_queue_item_scroll_slider_sync)

	if not item_scroll_track.gui_input.is_connected(_on_item_scroll_track_gui_input):
		item_scroll_track.gui_input.connect(_on_item_scroll_track_gui_input)
	if not item_scroll_handle.gui_input.is_connected(_on_item_scroll_handle_gui_input):
		item_scroll_handle.gui_input.connect(_on_item_scroll_handle_gui_input)

	if not item_scroll.resized.is_connected(_queue_item_scroll_slider_sync):
		item_scroll.resized.connect(_queue_item_scroll_slider_sync)
	if not item_scroll.resized.is_connected(_reflow_product_grid):
		item_scroll.resized.connect(_reflow_product_grid)
	if not item_scroll_track.resized.is_connected(_queue_item_scroll_slider_sync):
		item_scroll_track.resized.connect(_queue_item_scroll_slider_sync)

	_queue_item_scroll_slider_sync()


func _queue_item_scroll_slider_sync() -> void:
	if _item_scroll_layout_sync_queued:
		return
	_item_scroll_layout_sync_queued = true
	call_deferred("_sync_item_scroll_slider")


func _sync_item_scroll_slider() -> void:
	_item_scroll_layout_sync_queued = false
	if item_scroll_slider == null or item_scroll_track == null or item_scroll_handle == null:
		return

	var max_scroll: float = _item_scroll_maximum()
	var has_scroll_range: bool = max_scroll > 0.5

	item_scroll_slider.visible = true
	item_scroll_track.mouse_filter = Control.MOUSE_FILTER_STOP if has_scroll_range else Control.MOUSE_FILTER_IGNORE
	item_scroll_handle.mouse_filter = Control.MOUSE_FILTER_STOP if has_scroll_range else Control.MOUSE_FILTER_IGNORE
	item_scroll_handle.visible = has_scroll_range

	if not has_scroll_range:
		item_scroll.scroll_vertical = 0
		_item_scroll_handle_dragging = false
		_item_scroll_handle_touch_index = -1
		return

	var normalized_scroll: float = clampf(float(item_scroll.scroll_vertical) / max_scroll, 0.0, 1.0)
	var handle_travel: float = _item_scroll_handle_travel()
	var handle_position: Vector2 = item_scroll_handle.position
	handle_position.y = normalized_scroll * handle_travel
	item_scroll_handle.position = handle_position


func _item_scroll_maximum() -> float:
	var internal_scrollbar: VScrollBar = item_scroll.get_v_scroll_bar()
	if internal_scrollbar == null:
		return 0.0
	return maxf(0.0, float(internal_scrollbar.max_value) - float(internal_scrollbar.page))


func _item_scroll_handle_travel() -> float:
	return maxf(0.0, item_scroll_track.size.y - item_scroll_handle.size.y)


func _item_scroll_slider_local_y(screen_position: Vector2) -> float:
	return (item_scroll_slider.get_global_transform_with_canvas().affine_inverse() * screen_position).y


func _set_item_scroll_from_handle_top(handle_top: float) -> void:
	var max_scroll: float = _item_scroll_maximum()
	var handle_travel: float = _item_scroll_handle_travel()
	if max_scroll <= 0.5 or handle_travel <= 0.0:
		item_scroll.scroll_vertical = 0
		_sync_item_scroll_slider()
		return
	var normalized_scroll: float = clampf(handle_top / handle_travel, 0.0, 1.0)
	item_scroll.scroll_vertical = int(round(normalized_scroll * max_scroll))


func _handle_item_scroll_pointer_event(event: InputEvent, center_handle_on_press: bool) -> void:
	if _item_scroll_maximum() <= 0.5:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_item_scroll_handle_dragging = true
			_item_scroll_handle_touch_index = -1
			var pointer_y: float = _item_scroll_slider_local_y(get_viewport().get_mouse_position())
			_item_scroll_handle_drag_offset_y = item_scroll_handle.size.y * 0.5 if center_handle_on_press else pointer_y - item_scroll_handle.position.y
			_set_item_scroll_from_handle_top(pointer_y - _item_scroll_handle_drag_offset_y)
		else:
			_item_scroll_handle_dragging = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _item_scroll_handle_dragging and _item_scroll_handle_touch_index == -1:
		var pointer_y: float = _item_scroll_slider_local_y(get_viewport().get_mouse_position())
		_set_item_scroll_from_handle_top(pointer_y - _item_scroll_handle_drag_offset_y)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_item_scroll_handle_dragging = true
			_item_scroll_handle_touch_index = touch.index
			var pointer_y: float = _item_scroll_slider_local_y(touch.position)
			_item_scroll_handle_drag_offset_y = item_scroll_handle.size.y * 0.5 if center_handle_on_press else pointer_y - item_scroll_handle.position.y
			_set_item_scroll_from_handle_top(pointer_y - _item_scroll_handle_drag_offset_y)
		elif touch.index == _item_scroll_handle_touch_index:
			_item_scroll_handle_dragging = false
			_item_scroll_handle_touch_index = -1
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _item_scroll_handle_dragging and drag.index == _item_scroll_handle_touch_index:
			var pointer_y: float = _item_scroll_slider_local_y(drag.position)
			_set_item_scroll_from_handle_top(pointer_y - _item_scroll_handle_drag_offset_y)
			get_viewport().set_input_as_handled()


func _on_item_scroll_track_gui_input(event: InputEvent) -> void:
	_handle_item_scroll_pointer_event(event, true)


func _on_item_scroll_handle_gui_input(event: InputEvent) -> void:
	_handle_item_scroll_pointer_event(event, false)


func _on_item_scroll_changed(_value: float) -> void:
	_sync_item_scroll_slider()


# -------------------------------------------------------- detail popup ----

func _on_item_card_pressed(card: Button) -> void:
	_open_detail(card)


func _open_detail(card: Button) -> void:
	var card_icon_slot: TextureRect = card.get_node("IconSlot")
	var card_icon: TextureRect = card_icon_slot.get_node("Icon")
	var card_name_label: Label = card.get_node("NameLabel")
	var card_price_label: Label = card.get_node("PriceLabel")

	detail_icon_slot.modulate = card_icon_slot.modulate
	detail_icon.texture = card_icon.texture
	detail_name_label.text = card_name_label.text
	detail_desc_label.text = card.tooltip_text
	_detail_price_text = card_price_label.text

	_detail_item_id = str(card.get_meta("item_id", ""))
	_detail_amount = int(card.get_meta("amount", 1))
	_detail_price = int(card.get_meta("price", 0))
	_detail_is_gem_pack = bool(card.get_meta("is_gem_pack", false))
	_refresh_detail_affordability()

	detail_overlay.visible = true
	detail_card.modulate = Color(1, 1, 1, 1)
	detail_card.scale = Vector2.ONE
	_play_panel_open(detail_card)


func _close_detail() -> void:
	var tween := detail_card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(detail_card, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(detail_card, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_on_detail_closed)


func _on_detail_closed() -> void:
	detail_overlay.visible = false
	detail_card.modulate = Color(1, 1, 1, 1)
	detail_card.scale = Vector2.ONE


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_detail()


func _on_detail_buy_pressed() -> void:
	# No sparkle/toast here - shop_ui.gd still has to actually talk to the
	# server before this purchase is real. Playing success juice this early
	# would lie about a purchase the server might still reject. See
	# show_purchase_success_feedback().
	if not detail_buy_button.disabled and _detail_item_id != "":
		buy_requested.emit(_detail_item_id, _detail_amount, _detail_price, _detail_is_gem_pack)


## Balance is supplied by the shop manager; browsing remains available.
func set_available_gems(gems: int) -> void:
	_available_gems = maxi(0, gems)
	_refresh_detail_affordability()
	if reward_buy_again_button.visible:
		reward_buy_again_button.disabled = _available_gems < _reward_buy_again_price


func _refresh_detail_affordability() -> void:
	if detail_buy_button == null:
		return
	var affordable := _detail_is_gem_pack or _available_gems >= _detail_price
	detail_buy_button.disabled = _detail_item_id.is_empty() or not affordable
	detail_buy_button.text = "BUY  " + _detail_price_text if affordable else "NEED %s MORE GEMS" % (_detail_price - _available_gems)
	detail_buy_button.tooltip_text = "" if affordable else "You can keep browsing or use Get Gems to add gems."


func _fit_shop_window() -> void:
	if shop_window == null:
		return
	for tween in _panel_open_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_panel_open_tweens.clear()
	for panel in [shop_window, detail_card, reward_card]:
		panel.modulate.a = 1.0
	# Reflow product columns before applying any last-resort fit scale.
	var available := Vector2(maxf(616.0, size.x - 24.0), maxf(300.0, size.y - 24.0))
	shop_window.size = Vector2(minf(1100.0, available.x), minf(700.0, available.y))
	shop_window.position = (size - shop_window.size) * 0.5
	_reflow_product_grid.call_deferred()
	_shop_fit_scale = minf(1.0, minf(maxf(1.0, size.x - 24.0) / shop_window.size.x, maxf(1.0, size.y - 24.0) / shop_window.size.y))
	shop_window.pivot_offset = shop_window.size * 0.5
	shop_window.scale = Vector2.ONE * _shop_fit_scale
	for popup in [detail_card, reward_card]:
		popup.pivot_offset = popup.size * 0.5
		popup.scale = Vector2.ONE * minf(1.0, minf(maxf(1.0, size.x - 24.0) / popup.size.x, maxf(1.0, size.y - 24.0) / popup.size.y))


func _reflow_product_grid() -> void:
	if item_scroll == null or item_scroll.size.x <= 0.0:
		return
	# Measure the actual content viewport, including the space reserved for
	# the scrollbar. A small width adjustment fits four readable cards.
	for grid in _category_grids:
		var gap := float(grid.get_theme_constant("h_separation"))
		var columns := clampi(int((item_scroll.size.x + gap) / (200.0 + gap)), 1, 4)
		var card_width := minf(210.0, floorf((item_scroll.size.x - gap * (columns - 1)) / columns))
		for card in grid.get_children():
			if card is Control:
				card.custom_minimum_size.x = card_width
		grid.columns = columns


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if reward_overlay.visible:
		hide_reward_popup()
	elif detail_overlay.visible:
		_close_detail()
	else:
		_on_close_pressed()
	get_viewport().set_input_as_handled()


## Called by shop_ui.gd once a purchase this popup requested has actually
## gone through (see finalize_shop_purchase() in shop_ui.gd) - this is the
## right place for the "you bought it" sparkle/toast, not the button press
## itself (see the comment on _on_detail_buy_pressed()).
func show_purchase_success_feedback() -> void:
	_play_buy_feedback(detail_buy_button)


# ---------------------------------------------------- purchase reward ----
# The "YOU GOT!" popup shown after a purchase completes. shop_ui.gd fills in
# the subtitle text and the Buy Again target (it's the one that knows what
# was actually bought and whether buying it again is even possible) and
# writes the actual reward-item tiles directly into reward_items_container -
# those tiles carry real item icons/rarity pulled from item_database, which
# this script deliberately has no access to (see the class doc above), so
# they can't be authored here the way a static label could be.

func show_reward_popup(subtitle_text: String, can_buy_again: bool, buy_again_disabled: bool, buy_again_item_id: String, buy_again_amount: int, buy_again_price: int) -> void:
	reward_subtitle_label.text = subtitle_text
	_reward_buy_again_item_id = buy_again_item_id
	_reward_buy_again_amount = buy_again_amount
	_reward_buy_again_price = buy_again_price
	reward_buy_again_button.visible = can_buy_again
	reward_buy_again_button.disabled = buy_again_disabled

	reward_overlay.visible = true
	reward_card.pivot_offset = reward_card.size * 0.5
	var reward_fit := minf(1.0, minf(maxf(1.0, size.x - 24.0) / reward_card.size.x, maxf(1.0, size.y - 24.0) / reward_card.size.y))
	reward_card.scale = Vector2(0.84, 0.84) * reward_fit
	reward_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	reward_glow_back.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	_panel_open_tweens[reward_card] = tween
	tween.tween_property(reward_card, "scale", Vector2.ONE * reward_fit, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_glow_back, "modulate", Color(1.0, 1.0, 1.0, 0.72), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_reward_popup() -> void:
	reward_overlay.visible = false


func _on_reward_buy_again_pressed() -> void:
	reward_buy_again_requested.emit(_reward_buy_again_item_id, _reward_buy_again_amount, _reward_buy_again_price)


# --------------------------------------------------------------- juice ----
# Pure interaction feedback below this line - hover lift, buy squish/spark/
# toast, panel pop-in/out. None of it reads or sets art/text content, so
# none of it fights with whatever you customize in the editor.

func _play_panel_open(panel: Control, start_scale: Vector2 = Vector2(0.96, 0.96), duration: float = 0.16) -> void:
	var previous: Tween = _panel_open_tweens.get(panel)
	if previous != null and previous.is_valid():
		previous.kill()
	panel.pivot_offset = panel.size * 0.5
	var fit := minf(1.0, minf(maxf(1.0, size.x - 24.0) / panel.size.x, maxf(1.0, size.y - 24.0) / panel.size.y))
	panel.scale = start_scale * fit
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := panel.create_tween()
	_panel_open_tweens[panel] = tween
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE * fit, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), min(duration, 0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _wire_hover_lift(control: Control) -> void:
	control.pivot_offset = control.custom_minimum_size * 0.5
	control.mouse_entered.connect(func():
		var tween := control.create_tween()
		tween.set_parallel(true)
		tween.tween_property(control, "scale", Vector2(1.045, 1.045), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "rotation_degrees", randf_range(-2.0, 2.0), 0.1)
	)
	control.mouse_exited.connect(func():
		var tween := control.create_tween()
		tween.set_parallel(true)
		tween.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "rotation_degrees", 0.0, 0.12)
	)


func _play_buy_feedback(button: Button) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var button_rect := button.get_global_rect()
	var burst_origin: Vector2 = button_rect.position + button_rect.size * 0.5
	for i in range(6):
		var spark := TextureRect.new()
		spark.texture = STAR_TEXTURE
		spark.custom_minimum_size = Vector2(10, 10)
		spark.size = spark.custom_minimum_size
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		spark.global_position = burst_origin - spark.size * 0.5
		var direction := Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0))
		var spark_tween := spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", spark.global_position + direction * 46.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		spark_tween.chain().tween_callback(spark.queue_free)

	var toast := Label.new()
	toast.text = "Purchased!"
	toast.add_theme_font_size_override("font_size", 14)
	toast.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 1.0))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 1)
	add_child(toast)
	toast.global_position = burst_origin + Vector2(-60, -34)
	var toast_tween := toast.create_tween()
	toast_tween.set_parallel(true)
	toast_tween.tween_property(toast, "position:y", toast.position.y - 26.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	toast_tween.chain().tween_callback(toast.queue_free)
