extends Control
class_name InventoryScene

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ColourCycleModulation = preload("res://Scripts/colour_cycle_modulation.gd")
const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const SelectedSlotFrameClock = preload("res://Scripts/ui/selected_slot_frame_clock.gd")

signal item_selected(item: Dictionary)
signal item_double_action_requested(item: Dictionary)
signal primary_action_requested(item: Dictionary)
signal drop_requested(item: Dictionary)
signal info_requested(item: Dictionary)
signal trash_requested(item: Dictionary)
signal item_action_popup_requested(item: Dictionary, screen_position: Vector2)
signal inventory_upgrade_requested(upgrade_data: Dictionary)
signal close_requested
signal tab_changed(tab_id: String)

const UI_PATH := "res://Assets/ui/inventory/"
const ROOT_UI_PATH := "res://Assets/ui/"
const HOTBAR_UI_PATH := "res://Assets/ui/hotbar/"
const WINDOW_SIZE := Vector2(1000, 640)
const WINDOW_VISUAL_SIZE := Vector2(1349, 657)
const MOBILE_GUI_SCALE_SETTING := "gui/theme/default_theme_scale"
const MAX_UNIFORM_GUI_SCALE := 1.5
const SLOT_SIZE := Vector2(96, 96)
const SLOT_FRAME_SIZE := Vector2(96, 96)
const SLOT_FRAME_POS := Vector2.ZERO
const ICON_SIZE := Vector2(64, 64)
const ICON_POS := Vector2(16, 14)
const INVENTORY_SLOT_MIN_COUNT := 20
const INVENTORY_SLOT_MAX_COUNT := 300
const INVENTORY_SLOT_UPGRADE_STEP := 20
const SLOT_GRID_H_SEPARATION := 12
const SLOT_GRID_V_SEPARATION := 12
const INVENTORY_BOTTOM_SCROLL_PADDING_RATIO := 0.5
const DROP_AMOUNT_MIN := 1
const SLOT_TOUCH_DOUBLE_TAP_TIME_MS := 550
const SLOT_TOUCH_SCROLL_DEADZONE := 12.0
const SLOT_LONG_PRESS_TIME_MS := 450
const SEED_BOX_PREVIEW_NODE_NAME := "SeedPreview"
const LOCK_METADATA_KEYS := ["lock_item", "world_lock_item", "world_lock", "lock_block", "is_lock"]
const INVENTORY_CAPACITY_CATEGORY := "inventory_capacity"
const INVENTORY_EMPTY_SLOT_PREFIX := "empty_slot_"
const INVENTORY_UPGRADE_SLOT_ID := "slot_upgrade"
const INVENTORY_UPGRADE_SLOT_TEXTURE := "slot_upgrade.png"
const MATERIAL_SLOT_TEXTURE := "material_slot.png"
const CLOTHES_SLOT_TEXTURE := "clothes_slot.png"
const EMPTY_SLOT_TEXTURE := "empty_slot.png"
const SLOT_TEMPLATE_LAYOUT_NODES := ["Frame", "SelectedFrame", "IconShadow", "Icon", "Count", "Equipped"]
const COLOUR_CYCLE_ICON_UPDATE_SECONDS := 0.10
const SELECTED_SLOT_FRAME_SECONDS := 0.30
const SELECTED_SLOT_FRAMES := [
	preload("res://Assets/ui/selected_1.png"),
	preload("res://Assets/ui/selected_2.png"),
	preload("res://Assets/ui/selected_3.png"),
]

const TABS := [
	{"id": "all", "label": "ALL"},
	{"id": "blocks", "label": "BLOCKS"},
	{"id": "seeds", "label": "SEEDS"},
	{"id": "tools", "label": "TOOLS"},
	{"id": "materials", "label": "LOOT"},
	{"id": "gear", "label": "GEAR"}
]

const TAB_CATEGORIES := {
	"blocks": ["block"],
	"seeds": ["seed"],
	"tools": ["tool"],
	"materials": ["material", "lure", "fish", "currency"],
	"gear": ["back", "hat", "hair", "eyewear", "beard", "shirt", "pants", "shoes", "ride"]
}

@export var use_preview_items: bool = false
@export var default_tab: String = "all"
@export var slot_columns: int = 10

var inventory_items: Array[Dictionary] = []
var current_tab: String = "all"
var selected_key: String = ""
var selected_item: Dictionary = {}
var tab_buttons: Dictionary = {}
var slot_nodes: Dictionary = {}
var slot_template_nodes: Array[Button] = []
var visible_slot_keys: Dictionary = {}
var colour_cycle_slot_keys: Dictionary = {}
var ui_texture_cache: Dictionary = {}
var last_live_refresh_changed_structure: bool = false
var colour_cycle_icon_update_elapsed: float = 0.0
var selected_slot_frame_index: int = 0
var inventory_scroll_handle_dragging: bool = false
var inventory_scroll_handle_touch_index: int = -1
var inventory_scroll_handle_drag_offset_y: float = 0.0
var syncing_drop_amount_controls: bool = false
var drop_amount: int = DROP_AMOUNT_MIN
var drop_amount_item_key: String = ""
var drop_amount_limit: int = DROP_AMOUNT_MIN
var gem_count: int = 0
var gem_text: String = ""
var inventory_source: Object = null
var last_slot_tap_key: String = ""
var last_slot_tap_time_ms: int = 0
var active_slot_touch_index: int = -1
var active_slot_touch_key: String = ""
var active_slot_touch_start_position := Vector2.ZERO
var active_slot_touch_scrolled := false
var active_slot_touch_started_ms: int = 0
var active_slot_long_press_opened: bool = false
var inventory_scroll_touch_index: int = -1
var inventory_scroll_touch_start_position := Vector2.ZERO
var inventory_scroll_touch_last_position := Vector2.ZERO
var inventory_scroll_touch_value := 0.0
var inventory_scroll_touch_dragging := false
var inventory_scroll_layout_sync_queued := false
var drawer_transform_managed := false

@onready var window: Control = $Window
@onready var tabs: BoxContainer = $Window/Tabs
@onready var search_input: LineEdit = $Window/SearchInput
@onready var gem_counter_label: Label = get_node_or_null("Window/HeaderSkin/GemCounterLabel") as Label
@onready var inventory_scroll: ScrollContainer = $Window/InventoryScroll
@onready var inventory_scroll_slider: Control = get_node_or_null("Window/InventoryScrollSlider") as Control
@onready var inventory_scroll_track: TextureRect = get_node_or_null("Window/InventoryScrollSlider/Track") as TextureRect
@onready var inventory_scroll_handle: TextureRect = get_node_or_null("Window/InventoryScrollSlider/Handle") as TextureRect
@onready var inventory_grid: GridContainer = $Window/InventoryScroll/InventoryGrid
@onready var empty_state: Label = $Window/EmptyState
@onready var detail_title: Label = $Window/DetailTitle
@onready var detail_rarity: Label = $Window/DetailRarity
@onready var detail_category: Label = $Window/DetailCategory
@onready var detail_description: RichTextLabel = $Window/DetailDescription
@onready var detail_frame: TextureRect = $Window/DetailPreviewSlot/Frame
@onready var detail_selected_frame: TextureRect = $Window/DetailPreviewSlot/SelectedFrame
@onready var detail_icon_shadow: TextureRect = $Window/DetailPreviewSlot/IconShadow
@onready var detail_icon: TextureRect = $Window/DetailPreviewSlot/Icon
@onready var selected_label: Label = $Window/FooterSelectedLabel
@onready var count_label: Label = $Window/FooterCountLabel
@onready var close_button: Button = $Window/CloseButton
@onready var drop_amount_input: LineEdit = get_node_or_null("Window/DropAmountInput") as LineEdit
@onready var drop_amount_slider: HSlider = get_node_or_null("Window/DropAmountSlider") as HSlider
@onready var use_button: Button = $Window/UseButton
@onready var drop_button: Button = $Window/DropButton
@onready var info_button: Button = get_node_or_null("Window/InfoButton") as Button
@onready var trash_button: Button = get_node_or_null("Window/TrashButton") as Button


func _ready() -> void:
	current_tab = default_tab
	window.pivot_offset = WINDOW_SIZE * 0.5
	_fit_window_to_viewport()
	_apply_texture_filter(self)
	_style_static_nodes()
	_setup_mouse_passthrough()
	_setup_detail_preview_texture_rects()
	_setup_slot_templates()
	_setup_inventory_scroll_slider()
	_build_tabs()
	if gem_text != "":
		set_gem_text(gem_text)
	else:
		set_gem_count(gem_count)
	search_input.text_changed.connect(_on_search_changed)
	close_button.pressed.connect(close_inventory)
	use_button.pressed.connect(_on_use_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	if drop_amount_input != null:
		drop_amount_input.text_changed.connect(_on_drop_amount_input_changed)
		drop_amount_input.text_submitted.connect(_on_drop_amount_input_submitted)
		drop_amount_input.focus_exited.connect(_on_drop_amount_input_focus_exited)
	if drop_amount_slider != null:
		drop_amount_slider.value_changed.connect(_on_drop_amount_slider_changed)
	if info_button != null:
		info_button.pressed.connect(_on_info_pressed)
	if trash_button != null:
		trash_button.pressed.connect(_on_trash_pressed)

	if inventory_items.is_empty() and use_preview_items:
		set_inventory_items(_make_preview_items())
	else:
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		call_deferred("_fit_window_to_viewport")


func _process(delta: float) -> void:
	update_colour_cycle_icon_modulation_throttled(delta)
	update_selected_slot_frame_animation(delta)
	if active_slot_touch_index < 0 or active_slot_touch_key == "":
		return
	if active_slot_touch_scrolled or active_slot_long_press_opened:
		return
	if Time.get_ticks_msec() - active_slot_touch_started_ms < SLOT_LONG_PRESS_TIME_MS:
		return
	var item: Dictionary = _get_item_for_slot_key(active_slot_touch_key)
	if item.is_empty() or _is_empty_capacity_slot(item) or _is_inventory_upgrade_slot(item):
		return
	active_slot_long_press_opened = true
	last_slot_tap_key = ""
	last_slot_tap_time_ms = 0
	_select_slot_item(item)
	var popup_position: Vector2 = _slot_anchor_position(active_slot_touch_key, active_slot_touch_start_position)
	_clear_active_slot_touch()
	_clear_inventory_scroll_touch()
	item_action_popup_requested.emit(item.duplicate(true), popup_position)


func _input(event: InputEvent) -> void:
	if not visible or inventory_scroll == null:
		return

	if inventory_scroll_handle_dragging:
		if event is InputEventMouseMotion and inventory_scroll_handle_touch_index == -1:
			_handle_inventory_scroll_pointer_event(event, false)
			return
		if event is InputEventMouseButton:
			var mouse_button: InputEventMouseButton = event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				_handle_inventory_scroll_pointer_event(event, false)
				return
		if event is InputEventScreenDrag:
			var handle_drag: InputEventScreenDrag = event as InputEventScreenDrag
			if handle_drag.index == inventory_scroll_handle_touch_index:
				_handle_inventory_scroll_pointer_event(event, false)
				return
		if event is InputEventScreenTouch:
			var handle_touch: InputEventScreenTouch = event as InputEventScreenTouch
			if not handle_touch.pressed and handle_touch.index == inventory_scroll_handle_touch_index:
				_handle_inventory_scroll_pointer_event(event, false)
				return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if inventory_scroll_touch_index != -1 or not _control_contains_screen_point(inventory_scroll, touch.position):
				return
			inventory_scroll_touch_index = touch.index
			inventory_scroll_touch_start_position = touch.position
			inventory_scroll_touch_last_position = touch.position
			inventory_scroll_touch_value = float(inventory_scroll.scroll_vertical)
			inventory_scroll_touch_dragging = false
			return
		if touch.index != inventory_scroll_touch_index:
			return
		if inventory_scroll_touch_dragging:
			active_slot_touch_scrolled = true
			get_viewport().set_input_as_handled()
		_clear_inventory_scroll_touch()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index != inventory_scroll_touch_index:
			return
		if not inventory_scroll_touch_dragging and drag.position.distance_to(inventory_scroll_touch_start_position) > SLOT_TOUCH_SCROLL_DEADZONE:
			inventory_scroll_touch_dragging = true
			active_slot_touch_scrolled = true
			last_slot_tap_key = ""
			last_slot_tap_time_ms = 0
		if inventory_scroll_touch_dragging:
			_scroll_inventory_by_touch_delta(drag.position.y - inventory_scroll_touch_last_position.y)
			get_viewport().set_input_as_handled()
		inventory_scroll_touch_last_position = drag.position


func open_inventory(optional_items: Array = [], force_refresh: bool = true) -> void:
	var items_replaced := false
	if not optional_items.is_empty():
		set_inventory_items(optional_items)
		items_replaced = true
	visible = true
	if force_refresh and not items_replaced:
		_refresh()


func close_inventory() -> void:
	_clear_inventory_scroll_touch()
	_clear_active_slot_touch()
	search_input.release_focus()
	visible = false
	close_requested.emit()


func is_interactive_control_at_point(point: Vector2) -> bool:
	for control in [
		search_input,
		close_button,
		drop_amount_input,
		drop_amount_slider,
		inventory_scroll_slider,
		use_button,
		drop_button,
		info_button,
		trash_button
	]:
		if _control_contains_screen_point(control as Control, point):
			return true

	for raw_button in tab_buttons.values():
		if _control_contains_screen_point(raw_button as Control, point):
			return true

	for raw_slot in slot_nodes.values():
		if _control_contains_screen_point(raw_slot as Control, point):
			return true

	return false


func is_inventory_scroll_area_at_point(point: Vector2) -> bool:
	if _control_contains_screen_point(inventory_scroll_slider, point):
		return true
	return _control_contains_screen_point(inventory_scroll, point)


func set_inventory_items(new_items: Array) -> void:
	inventory_items.clear()
	for item in new_items:
		if item is Dictionary:
			var normalized: Dictionary = _normalize_item(item)
			if not normalized.is_empty():
				if not normalized.has("inventory_index"):
					normalized["inventory_index"] = inventory_items.size()
				inventory_items.append(normalized)

	if _can_refresh():
		_remove_stale_slot_nodes()
		_refresh()


func set_gem_count(value: int) -> void:
	gem_count = max(0, value)
	gem_text = _compact_count(gem_count)
	if gem_counter_label != null:
		gem_counter_label.text = gem_text


func set_gem_text(value: String) -> void:
	gem_text = value
	if gem_counter_label != null:
		gem_counter_label.text = gem_text


func set_primary_action_text(value: String) -> void:
	if use_button != null:
		use_button.text = value


func set_current_tab(tab_id: String) -> void:
	var known_tab: bool = false
	for tab_data in TABS:
		if str(tab_data["id"]) == tab_id:
			known_tab = true
			break
	if not known_tab or current_tab == tab_id:
		return
	current_tab = tab_id
	if inventory_scroll != null:
		inventory_scroll.scroll_vertical = 0
	if _can_refresh():
		_refresh()


func set_drawer_window_transform(top_left: Vector2, scale_amount: float) -> void:
	var window_node: Control = window
	if window_node == null:
		window_node = get_node_or_null("Window") as Control
	if window_node == null:
		return
	drawer_transform_managed = true
	window_node.anchor_left = 0.0
	window_node.anchor_top = 0.0
	window_node.anchor_right = 0.0
	window_node.anchor_bottom = 0.0
	window_node.offset_left = top_left.x
	window_node.offset_top = top_left.y
	window_node.offset_right = top_left.x + WINDOW_SIZE.x
	window_node.offset_bottom = top_left.y + WINDOW_SIZE.y
	window_node.pivot_offset = Vector2.ZERO
	window_node.scale = Vector2.ONE * clampf(scale_amount, 0.28, MAX_UNIFORM_GUI_SCALE)


func set_inventory_from_world(source: Object) -> void:
	if source == null:
		return

	inventory_source = source
	var item_database: Variant = source.get("item_database")
	var items: Array = []
	_append_world_inventory(items, source, "inventory", "block", item_database)
	_append_world_inventory(items, source, "seed_inventory", "seed", item_database)
	_append_world_inventory(items, source, "tool_inventory", "tool", item_database)
	_append_world_inventory(items, source, "material_inventory", "material", item_database)
	_append_world_inventory(items, source, "lure_inventory", "lure", item_database)
	_append_world_inventory(items, source, "fish_inventory", "fish", item_database)
	_append_world_inventory(items, source, "back_inventory", "back", item_database)
	_append_world_inventory(items, source, "hat_inventory", "hat", item_database)
	_append_world_inventory(items, source, "hair_inventory", "hair", item_database)
	_append_world_inventory(items, source, "eyewear_inventory", "eyewear", item_database)
	_append_world_inventory(items, source, "beard_inventory", "beard", item_database)
	_append_world_inventory(items, source, "shirt_inventory", "shirt", item_database)
	_append_world_inventory(items, source, "pants_inventory", "pants", item_database)
	_append_world_inventory(items, source, "shoes_inventory", "shoes", item_database)
	_append_world_inventory(items, source, "ride_inventory", "ride", item_database)
	_append_inventory_capacity_slots(items, source)
	set_inventory_items(items)


func refresh_live_from_world(source: Object) -> bool:
	if source == null:
		return false
	if not _can_refresh():
		return false

	inventory_source = source
	for item_index in range(inventory_items.size()):
		var item: Dictionary = inventory_items[item_index]
		if _is_capacity_slot(item):
			continue
		var item_id: String = str(item.get("id", ""))
		var category: String = str(item.get("category", ""))
		var count: int = _world_item_count(source, item_id, category)
		if count <= 0:
			return false

		item["count"] = count
		item["equipped"] = _world_item_equipped(source, item_id, category)
		item["equipable"] = _resolve_item_equipable(source, item_id, category)
		inventory_items[item_index] = item

		var slot_key: String = _item_key(item)
		if selected_key == slot_key:
			selected_item = item
		_refresh_slot_live(slot_key, item)

	_update_detail()
	_update_footer(_get_filtered_items())
	return true


func refresh_item_live_from_world(source: Object, item_id: String, category: String) -> bool:
	last_live_refresh_changed_structure = false
	if source == null:
		return false
	if not _can_refresh():
		return false

	var clean_item_id: String = item_id.strip_edges()
	var clean_category: String = category.strip_edges().to_lower()
	if clean_item_id == "" or clean_category == "":
		return true

	if clean_category == "currency":
		return true

	inventory_source = source
	var slot_key: String = _item_key_from_parts(clean_category, clean_item_id)
	var item_index: int = _find_inventory_item_index(slot_key)
	var count: int = _world_item_count(source, clean_item_id, clean_category)
	if _has_capacity_slots() and (item_index == -1 or count <= 0):
		return false
	if count <= 0:
		if item_index == -1:
			return true
		last_live_refresh_changed_structure = true
		inventory_items.remove_at(item_index)
		var removed_slot: Button = slot_nodes.get(slot_key, null) as Button
		if removed_slot != null and is_instance_valid(removed_slot):
			removed_slot.visible = false
			removed_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible_slot_keys.erase(slot_key)
		if selected_key == slot_key:
			selected_key = ""
			selected_item = {}
		var filtered_after_remove: Array = _get_filtered_items()
		_sync_selected_item(filtered_after_remove)
		_sync_filtered_slot_order_and_layout(filtered_after_remove)
		_update_selection_state()
		_update_detail()
		_update_footer(filtered_after_remove)
		return true
	if item_index == -1:
		last_live_refresh_changed_structure = true
		var new_item: Dictionary = _build_world_inventory_item(source, clean_item_id, clean_category, source.get("item_database"), inventory_items.size())
		if new_item.is_empty():
			return true
		inventory_items.append(new_item)
		var filtered_after_add: Array = _get_filtered_items()
		var visible_new_item: Dictionary = {}
		for filtered_item in filtered_after_add:
			if _item_key(filtered_item) == slot_key:
				visible_new_item = filtered_item
				break
		if not visible_new_item.is_empty():
			var new_slot: Button = slot_nodes.get(slot_key, null) as Button
			if new_slot == null or not is_instance_valid(new_slot):
				new_slot = _create_slot(visible_new_item, inventory_items.size() - 1)
				inventory_grid.add_child(new_slot)
				slot_nodes[slot_key] = new_slot
			else:
				_refresh_slot_live(slot_key, visible_new_item)
			new_slot.visible = true
			new_slot.mouse_filter = Control.MOUSE_FILTER_PASS
			visible_slot_keys[slot_key] = true
		_sync_filtered_slot_order_and_layout(filtered_after_add)
		_queue_inventory_scroll_slider_sync()
		_sync_selected_item(filtered_after_add)
		_update_selection_state()
		_update_detail()
		_update_footer(filtered_after_add)
		return true

	var item: Dictionary = inventory_items[item_index]
	item["count"] = count
	item["equipped"] = _world_item_equipped(source, clean_item_id, clean_category)
	item["equipable"] = _resolve_item_equipable(source, clean_item_id, clean_category)
	inventory_items[item_index] = item

	if selected_key == slot_key:
		selected_item = item
		_update_detail()
	_refresh_slot_live(slot_key, item)
	_update_selected_footer()
	return true


func did_last_live_refresh_change_structure() -> bool:
	return last_live_refresh_changed_structure


func _build_world_inventory_item(source: Object, item_id: String, category: String, item_database, inventory_index: int = -1) -> Dictionary:
	if source == null or item_id == "" or category == "":
		return {}
	var count: int = _world_item_count(source, item_id, category)
	if count <= 0:
		return {}

	var database_entry: Dictionary = {}
	if item_database is Dictionary and item_database.has(item_id) and item_database[item_id] is Dictionary:
		database_entry = item_database[item_id]
		if bool(database_entry.get("hidden", false)):
			return {}

	var payload: Dictionary = {
		"id": item_id,
		"display_name": str(database_entry.get("display_name", item_id.capitalize())),
		"category": category,
		"count": count,
		"rarity": _normalized_rarity(str(database_entry.get("rarity", "common"))),
		"description": str(database_entry.get("description", "")),
		"inventory_index": inventory_index if inventory_index >= 0 else inventory_items.size(),
		"sort_order": int(database_entry.get("order", 9999)),
		"equipable": _resolve_item_equipable(source, item_id, category)
	}

	for lock_key in LOCK_METADATA_KEYS:
		if database_entry.has(lock_key):
			payload[lock_key] = database_entry[lock_key]
	if database_entry.has("section"):
		payload["section"] = database_entry["section"]

	if database_entry.has("inventory_icon"):
		payload["icon_path"] = database_entry["inventory_icon"]
	elif database_entry.has("texture"):
		payload["texture"] = database_entry["texture"]

	if source.has_method("get_inventory_icon_texture"):
		var icon_texture: Variant = source.call("get_inventory_icon_texture", item_id, category)
		if icon_texture is Texture2D:
			payload["texture"] = icon_texture

	if category == "seed" and source.has_method("get_seed_icon_preview_layout"):
		var seed_preview_layout: Variant = source.call("get_seed_icon_preview_layout", item_id)
		if seed_preview_layout is Dictionary and not seed_preview_layout.is_empty():
			payload["seed_preview_layout"] = seed_preview_layout

	var equipped_property: String = _equipped_property_for_category(category)
	if equipped_property != "":
		payload["equipped"] = str(source.get(equipped_property)) == item_id

	payload["lock_item"] = _is_lock_item(payload)
	return payload


func set_selected_item(item_id: String, category: String) -> void:
	var next_selected_key: String = category + ":" + item_id
	if selected_key == next_selected_key and not selected_item.is_empty():
		return
	var previous_selected_key: String = selected_key
	selected_key = next_selected_key
	selected_item = {}
	for item in inventory_items:
		if _item_key(item) == selected_key:
			selected_item = item
			break
	if _can_refresh():
		_update_selection_state(previous_selected_key)


func clear_search() -> void:
	if search_input == null:
		return
	search_input.text = ""
	_refresh()


func _normalize_item(item: Dictionary) -> Dictionary:
	var result: Dictionary = item.duplicate(true)
	var id: String = str(result.get("id", result.get("type", result.get("item_type", "")))).strip_edges()
	var display_name: String = str(result.get("display_name", result.get("name", id.capitalize()))).strip_edges()
	if id == "":
		id = display_name.to_lower().replace(" ", "_")
	if id == "":
		return {}

	result["id"] = id
	result["display_name"] = display_name if display_name != "" else id.capitalize()
	result["category"] = str(result.get("category", result.get("item_category", "item"))).strip_edges().to_lower()
	result["count"] = _count_from_value(result.get("count", result.get("amount", 1)))
	result["rarity"] = _normalized_rarity(str(result.get("rarity", "common")))
	return result


func _append_world_inventory(output: Array, source: Object, property_name: String, category: String, item_database) -> void:
	var inventory_value: Variant = source.get(property_name)
	if not (inventory_value is Dictionary):
		return

	var inventory: Dictionary = inventory_value
	for raw_item_id in inventory.keys():
		var item_id: String = str(raw_item_id)
		var count: int = _count_from_value(inventory[raw_item_id])
		if count <= 0:
			continue

		var database_entry: Dictionary = {}
		if item_database is Dictionary and item_database.has(item_id) and item_database[item_id] is Dictionary:
			database_entry = item_database[item_id]
			if bool(database_entry.get("hidden", false)):
				continue

		var payload: Dictionary = {
			"id": item_id,
			"display_name": str(database_entry.get("display_name", item_id.capitalize())),
			"category": category,
			"count": count,
			"rarity": _normalized_rarity(str(database_entry.get("rarity", "common"))),
			"description": str(database_entry.get("description", "")),
			"inventory_index": output.size(),
			"sort_order": int(database_entry.get("order", 9999)),
			"equipable": _resolve_item_equipable(source, item_id, category)
		}

		for lock_key in LOCK_METADATA_KEYS:
			if database_entry.has(lock_key):
				payload[lock_key] = database_entry[lock_key]
		if database_entry.has("section"):
			payload["section"] = database_entry["section"]

		if database_entry.has("inventory_icon"):
			payload["icon_path"] = database_entry["inventory_icon"]
		elif database_entry.has("texture"):
			payload["texture"] = database_entry["texture"]

		if source.has_method("get_inventory_icon_texture"):
			var icon_texture: Variant = source.call("get_inventory_icon_texture", item_id, category)
			if icon_texture is Texture2D:
				payload["texture"] = icon_texture

		if category == "seed" and source.has_method("get_seed_icon_preview_layout"):
			var seed_preview_layout: Variant = source.call("get_seed_icon_preview_layout", item_id)
			if seed_preview_layout is Dictionary and not seed_preview_layout.is_empty():
				payload["seed_preview_layout"] = seed_preview_layout

		var equipped_property: String = _equipped_property_for_category(category)
		if equipped_property != "":
			payload["equipped"] = str(source.get(equipped_property)) == item_id

		payload["lock_item"] = _is_lock_item(payload)
		output.append(payload)


func _append_inventory_capacity_slots(output: Array, source: Object) -> void:
	var slot_count: int = _resolve_inventory_slot_count_from_source(source)
	var max_slots: int = INVENTORY_SLOT_MAX_COUNT
	var step: int = INVENTORY_SLOT_UPGRADE_STEP
	var preview: Dictionary = {}
	if source != null and source.has_method("get_inventory_upgrade_preview"):
		var raw_preview: Variant = source.call("get_inventory_upgrade_preview")
		if raw_preview is Dictionary:
			preview = raw_preview
			slot_count = _normalize_inventory_slot_count(int(preview.get("inventory_slot_count", preview.get("current_slots", slot_count))), max_slots, step)
			step = int(preview.get("step", step))
			max_slots = int(preview.get("max_slots", max_slots))
			slot_count = _normalize_inventory_slot_count(slot_count, max_slots, step)
	elif source != null and source.has_method("get_inventory_slot_count"):
		slot_count = _normalize_inventory_slot_count(int(source.call("get_inventory_slot_count")), max_slots, step)
	elif source != null:
		slot_count = _normalize_inventory_slot_count(int(source.get("inventory_slot_count")), max_slots, step)
	var owned_slot_count: int = output.size()
	var visible_slot_count: int = slot_count if slot_count > owned_slot_count else owned_slot_count
	for slot_index in range(owned_slot_count, visible_slot_count):
		output.append({
			"id": INVENTORY_EMPTY_SLOT_PREFIX + str(slot_index + 1),
			"display_name": "Empty Slot",
			"category": INVENTORY_CAPACITY_CATEGORY,
			"count": 0,
			"rarity": "normal",
			"description": "Inventory space.",
			"inventory_index": output.size(),
			"sort_order": 900000 + slot_index,
			"special_slot": "inventory_empty",
			"capacity_slot": true
		})

	if slot_count >= max_slots:
		return

	if preview.is_empty():
		preview = {
			"inventory_slot_count": slot_count,
			"current_slots": slot_count,
			"next_inventory_slot_count": min(slot_count + step, max_slots),
			"next_slots": min(slot_count + step, max_slots),
			"inventory_upgrade_cost": 0,
			"cost": 0,
			"max_slots": max_slots,
			"step": step
		}

	var cost: int = int(preview.get("cost", preview.get("inventory_upgrade_cost", 0)))
	var next_slots: int = int(preview.get("next_slots", preview.get("next_inventory_slot_count", min(slot_count + 20, 300))))
	output.append({
		"id": INVENTORY_UPGRADE_SLOT_ID,
		"display_name": "Slot Upgrade",
		"category": INVENTORY_CAPACITY_CATEGORY,
		"count": 0,
		"rarity": "legendary",
		"description": "Upgrade inventory to " + str(next_slots) + " slots for " + _compact_count(cost) + " gems.",
		"inventory_index": output.size(),
		"sort_order": 999999,
		"special_slot": "inventory_upgrade",
		"capacity_slot": true,
		"current_slots": slot_count,
		"next_slots": next_slots,
		"cost": cost,
		"inventory_upgrade_cost": cost,
		"max_slots": int(preview.get("max_slots", max_slots)),
		"step": int(preview.get("step", step))
	})


func _normalize_inventory_slot_count(slot_count: int, max_count: int = INVENTORY_SLOT_MAX_COUNT, step: int = INVENTORY_SLOT_UPGRADE_STEP) -> int:
	var safe_min_count: int = max(INVENTORY_SLOT_MIN_COUNT, 1)
	var safe_step: int = max(step, 1)
	var safe_max_count: int = max(safe_min_count, max_count)
	var clamped_count: int = clampi(slot_count, safe_min_count, safe_max_count)
	if clamped_count <= safe_min_count:
		return safe_min_count
	var upgrade_steps: int = int(ceil(float(clamped_count - safe_min_count) / float(safe_step)))
	return clampi(safe_min_count + upgrade_steps * safe_step, safe_min_count, safe_max_count)


func _resolve_inventory_slot_count_from_source(source: Object) -> int:
	var raw_slot_count: int = INVENTORY_SLOT_MIN_COUNT
	var max_slots: int = INVENTORY_SLOT_MAX_COUNT
	var step: int = INVENTORY_SLOT_UPGRADE_STEP

	if source == null:
		return _normalize_inventory_slot_count(raw_slot_count, max_slots, step)

	if source.has_method("get_inventory_upgrade_preview"):
		var raw_preview: Variant = source.call("get_inventory_upgrade_preview")
		if raw_preview is Dictionary:
			var preview: Dictionary = raw_preview
			max_slots = int(preview.get("max_slots", max_slots))
			step = int(preview.get("step", step))
			raw_slot_count = int(preview.get("inventory_slot_count", preview.get("current_slots", raw_slot_count)))
			return _normalize_inventory_slot_count(raw_slot_count, max_slots, step)

	if source.has_method("get_inventory_slot_count"):
		raw_slot_count = int(source.call("get_inventory_slot_count"))
	elif source.has_property("inventory_slot_count"):
		raw_slot_count = int(source.get("inventory_slot_count"))
	return _normalize_inventory_slot_count(raw_slot_count, max_slots, step)


func _count_usable_inventory_slots(items: Array) -> int:
	var count: int = 0
	for item in items:
		if item is Dictionary and not _is_capacity_slot(item):
			count += 1
	return count


func _is_capacity_slot(item: Dictionary) -> bool:
	return bool(item.get("capacity_slot", false)) or str(item.get("category", "")) == INVENTORY_CAPACITY_CATEGORY


func _is_empty_capacity_slot(item: Dictionary) -> bool:
	return _is_capacity_slot(item) and str(item.get("special_slot", "")) == "inventory_empty"


func _is_inventory_upgrade_slot(item: Dictionary) -> bool:
	return _is_capacity_slot(item) and str(item.get("special_slot", "")) == "inventory_upgrade"


func _has_capacity_slots() -> bool:
	for item in inventory_items:
		if item is Dictionary and _is_capacity_slot(item):
			return true
	return false


func _is_selectable_inventory_item(item: Dictionary) -> bool:
	return not item.is_empty() and not _is_empty_capacity_slot(item)


func _refresh() -> void:
	if not _can_refresh():
		return
	var filtered_items: Array = _get_filtered_items()
	_sync_selected_item(filtered_items)
	_refresh_grid(filtered_items)
	_update_detail()
	_update_footer(filtered_items)


func _sync_selected_item(filtered_items: Array) -> void:
	if filtered_items.is_empty():
		selected_key = ""
		selected_item = {}
		return

	var selected_still_visible: bool = false
	for item in filtered_items:
		if _item_key(item) == selected_key:
			selected_item = item
			selected_still_visible = true
			break

	if not selected_still_visible:
		selected_item = {}
		for item in filtered_items:
			if _is_selectable_inventory_item(item):
				selected_item = item
				break
		if selected_item.is_empty():
			selected_item = filtered_items[0]
		selected_key = _item_key(selected_item)


func _get_filtered_items() -> Array:
	var query: String = search_input.text.strip_edges().to_lower() if search_input != null else ""
	var filtered_items: Array = []
	for item in inventory_items:
		if not _tab_accepts_item(item):
			continue
		if query != "":
			if _is_capacity_slot(item):
				continue
			var haystack: String = (
				str(item.get("id", "")) + " " +
				str(item.get("display_name", "")) + " " +
				str(item.get("category", "")) + " " +
				str(item.get("rarity", ""))
			).to_lower()
			if haystack.find(query) == -1:
				continue
		filtered_items.append(item)
	return _sort_inventory_items(filtered_items)


func _sort_inventory_items(items: Array) -> Array:
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(Callable(self, "_compare_inventory_items"))
	return sorted_items


func _compare_inventory_items(a: Dictionary, b: Dictionary) -> bool:
	var a_is_lock: bool = _is_lock_item(a)
	var b_is_lock: bool = _is_lock_item(b)
	if a_is_lock != b_is_lock:
		return a_is_lock

	if a_is_lock and b_is_lock:
		var a_order: int = _item_sort_order(a)
		var b_order: int = _item_sort_order(b)
		if a_order != b_order:
			return a_order < b_order
		var a_name: String = _item_display_name(a).to_lower()
		var b_name: String = _item_display_name(b).to_lower()
		if a_name != b_name:
			return a_name < b_name

	return _item_inventory_index(a) < _item_inventory_index(b)


func _is_lock_item(item: Dictionary) -> bool:
	for lock_key in LOCK_METADATA_KEYS:
		if bool(item.get(lock_key, false)):
			return true

	if str(item.get("section", "")).strip_edges().to_lower() == "locks":
		return true

	var item_id: String = str(item.get("id", item.get("type", ""))).strip_edges().to_lower()
	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	if category == "block" and inventory_source != null and inventory_source.has_method("is_world_lock_block_type"):
		if bool(inventory_source.call("is_world_lock_block_type", item_id)):
			return true

	var display_name: String = _item_display_name(item).strip_edges().to_lower()
	return _lock_text_matches(item_id) or _lock_text_matches(display_name)


func _lock_text_matches(value: String) -> bool:
	if value == "":
		return false
	var normalized_value: String = value.replace("-", " ").replace("_", " ")
	for raw_token in normalized_value.split(" ", false):
		var token: String = str(raw_token).strip_edges().to_lower()
		if token == "lock" or token == "locks":
			return true
	return normalized_value == "lock" or normalized_value.ends_with(" lock")


func _item_sort_order(item: Dictionary) -> int:
	if item.has("sort_order"):
		return int(item.get("sort_order", 9999))
	return int(item.get("order", 9999))


func _item_inventory_index(item: Dictionary) -> int:
	return int(item.get("inventory_index", 0))


func _can_refresh() -> bool:
	return is_inside_tree() and search_input != null and inventory_grid != null and detail_title != null and selected_label != null and count_label != null


func _tab_accepts_item(item: Dictionary) -> bool:
	if _is_capacity_slot(item):
		return current_tab == "all"
	if current_tab == "all":
		return true
	if not TAB_CATEGORIES.has(current_tab):
		return true
	return str(item.get("category", "")).to_lower() in TAB_CATEGORIES[current_tab]


func _build_tabs() -> void:
	tab_buttons.clear()

	for tab_data in TABS:
		var tab_id: String = str(tab_data["id"])
		var button: Button = tabs.get_node_or_null("Tab_" + tab_id) as Button
		if button == null:
			continue
		var tab_callback: Callable = Callable(self, "_on_tab_pressed").bind(tab_id)
		if not button.pressed.is_connected(tab_callback):
			button.pressed.connect(tab_callback)
		tab_buttons[tab_id] = button


func _refresh_grid(filtered_items: Array) -> void:
	inventory_grid.columns = max(1, slot_columns)
	empty_state.visible = filtered_items.is_empty()

	var desired_visible_keys: Dictionary = {}
	for item in filtered_items:
		desired_visible_keys[_item_key(item)] = true

	for raw_slot_key in visible_slot_keys.keys():
		var hidden_slot_key: String = str(raw_slot_key)
		if desired_visible_keys.has(hidden_slot_key):
			continue
		var hidden_slot: Button = slot_nodes.get(hidden_slot_key, null) as Button
		if hidden_slot == null or not is_instance_valid(hidden_slot):
			continue
		hidden_slot.visible = false
		hidden_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hidden_slot.scale = Vector2.ONE

	for item_index in range(filtered_items.size()):
		var item: Dictionary = filtered_items[item_index]
		var slot_key: String = _item_key(item)
		var slot: Button = slot_nodes.get(slot_key, null) as Button
		if slot == null or not is_instance_valid(slot):
			slot = _create_slot(item, item_index)
			inventory_grid.add_child(slot)
			slot_nodes[slot_key] = slot
		else:
			_refresh_slot_live(slot_key, item)

		slot.visible = true
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
	visible_slot_keys = desired_visible_keys
	_sync_filtered_slot_order_and_layout(filtered_items)
	_queue_inventory_scroll_slider_sync()


func _setup_slot_templates() -> void:
	slot_template_nodes.clear()
	if inventory_grid == null:
		return
	for child in inventory_grid.get_children():
		if child is Button and str(child.name).begins_with("SlotTemplate_"):
			var button: Button = child as Button
			button.visible = false
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_template_nodes.append(button)


func _apply_slot_display_layout(slot: Button, _display_index: int) -> void:
	if slot == null or slot_template_nodes.is_empty():
		return
	# Every slot uses one canonical local layout. The old per-column templates
	# counter-shifted their children and cancelled the GridContainer spacing.
	const TEMPLATE_INDEX := 0
	if int(slot.get_meta("slot_template_index", -1)) == TEMPLATE_INDEX:
		return
	var template: Button = slot_template_nodes[TEMPLATE_INDEX]
	for node_name in SLOT_TEMPLATE_LAYOUT_NODES:
		var target_control: Control = slot.get_node_or_null(node_name) as Control
		var template_control: Control = template.get_node_or_null(node_name) as Control
		if target_control == null or template_control == null:
			continue
		target_control.position = template_control.position
		target_control.size = template_control.size
		target_control.pivot_offset = template_control.pivot_offset
	slot.set_meta("slot_template_index", TEMPLATE_INDEX)


func _sync_filtered_slot_order_and_layout(filtered_items: Array) -> void:
	var desired_order: Array[String] = []
	for display_index in range(filtered_items.size()):
		var slot_key: String = _item_key(filtered_items[display_index])
		desired_order.append(slot_key)
		var slot: Button = slot_nodes.get(slot_key, null) as Button
		if slot == null or not is_instance_valid(slot):
			continue
		_apply_slot_display_layout(slot, display_index)

	var current_order: Array[String] = []
	for child in inventory_grid.get_children():
		if not (child is Button) or not child.visible:
			continue
		var child_slot_key: String = str(child.get_meta("inventory_slot_key", ""))
		if child_slot_key != "":
			current_order.append(child_slot_key)
	if current_order == desired_order:
		return

	for slot_key in desired_order:
		var slot: Button = slot_nodes.get(slot_key, null) as Button
		if slot == null or not is_instance_valid(slot):
			continue
		inventory_grid.move_child(slot, inventory_grid.get_child_count() - 1)


func _create_slot(item: Dictionary, _item_index: int = 0) -> Button:
	var slot: Button = null
	var slot_key: String = _item_key(item)
	if not slot_template_nodes.is_empty():
		var template: Button = slot_template_nodes[0]
		slot = template.duplicate() as Button
	if slot == null:
		slot = Button.new()
	slot.name = "Slot_" + slot_key.replace(":", "_")
	slot.set_meta("inventory_slot_key", slot_key)
	slot.visible = true
	slot.custom_minimum_size = SLOT_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.text = ""
	slot.set_meta("special_slot", str(item.get("special_slot", "")))
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.clip_contents = false
	slot.pivot_offset = SLOT_SIZE * 0.5
	if not slot.has_theme_stylebox_override("normal"):
		slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	if not slot.has_theme_stylebox_override("hover"):
		slot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	if not slot.has_theme_stylebox_override("pressed"):
		slot.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	if not slot.has_theme_stylebox_override("focus"):
		slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var slot_input_callback: Callable = Callable(self, "_on_slot_gui_input").bind(slot_key)
	if not slot.gui_input.is_connected(slot_input_callback):
		slot.gui_input.connect(slot_input_callback)
	slot.mouse_entered.connect(_on_slot_hovered.bind(slot, true))
	slot.mouse_exited.connect(_on_slot_hovered.bind(slot, false))

	var frame: TextureRect = slot.get_node_or_null("Frame") as TextureRect
	if frame == null:
		frame = TextureRect.new()
		frame.name = "Frame"
		frame.position = SLOT_FRAME_POS
		frame.size = SLOT_FRAME_SIZE
		slot.add_child(frame)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var selected_frame: TextureRect = slot.get_node_or_null("SelectedFrame") as TextureRect
	if selected_frame == null:
		selected_frame = TextureRect.new()
		selected_frame.name = "SelectedFrame"
		selected_frame.position = SLOT_FRAME_POS
		selected_frame.size = SLOT_FRAME_SIZE
		slot.add_child(selected_frame)
	selected_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_frame.stretch_mode = TextureRect.STRETCH_SCALE
	selected_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_frame.visible = slot_key == selected_key

	var rarity_pip: CanvasItem = slot.get_node_or_null("RarityPip") as CanvasItem
	if rarity_pip != null:
		rarity_pip.visible = false

	var icon_shadow: TextureRect = slot.get_node_or_null("IconShadow") as TextureRect
	if icon_shadow == null:
		icon_shadow = TextureRect.new()
		icon_shadow.name = "IconShadow"
		icon_shadow.position = ICON_POS + Vector2(3, 4)
		icon_shadow.size = ICON_SIZE
		slot.add_child(icon_shadow)
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.35)
	icon_shadow.texture = _item_icon_texture(item)
	icon_shadow.visible = icon_shadow.texture != null and not _is_inventory_upgrade_slot(item)
	_remove_seed_box_icon_overlay(icon_shadow)

	var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = slot.get_node_or_null("ItemIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.position = ICON_POS
		icon.size = ICON_SIZE
		slot.add_child(icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _item_icon_texture(item)
	icon.visible = icon.texture != null and not _is_inventory_upgrade_slot(item)
	_update_seed_box_icon_overlay(icon, item)
	track_colour_cycle_slot(slot_key, item)
	_apply_colour_cycle_icon_modulation(icon, item, float(slot_key.hash() % 1000) / 1000.0)

	var count_text: String = _slot_count_text(item)
	var label: Label = slot.get_node_or_null("Count") as Label
	if label == null and count_text != "":
		label = Label.new()
		label.name = "Count"
		label.position = Vector2(55, 67)
		label.size = Vector2(38, 21)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label, 12, Color.WHITE)
		slot.add_child(label)
	if label != null:
		label.visible = count_text != ""
		label.text = count_text

	var equipped_label: Label = slot.get_node_or_null("Equipped") as Label
	var generated_equipped_label: bool = false
	if equipped_label == null:
		equipped_label = Label.new()
		equipped_label.name = "Equipped"
		slot.add_child(equipped_label)
		generated_equipped_label = true
		slot.set_meta("generated_equipped_label", true)
	if equipped_label != null:
		equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if generated_equipped_label:
			equipped_label.position = Vector2(5, 1)
			equipped_label.size = Vector2(28, 28)
			equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			equipped_label.add_theme_font_size_override("font_size", 20)
			equipped_label.add_theme_color_override("font_color", Color(0.1, 1.0, 0.18, 1.0))
			equipped_label.add_theme_color_override("font_shadow_color", PixelUIStyle.GLOBAL_TEXT_SHADOW_COLOR)
			equipped_label.add_theme_constant_override("shadow_offset_x", int(PixelUIStyle.GLOBAL_TEXT_SHADOW_OFFSET.x))
			equipped_label.add_theme_constant_override("shadow_offset_y", int(PixelUIStyle.GLOBAL_TEXT_SHADOW_OFFSET.y))
			equipped_label.text = "✓"
		equipped_label.visible = bool(item.get("equipped", false))

	_apply_slot_rarity_visuals(slot, item)

	slot.tooltip_text = _item_display_name(item) + " " + _detail_count_text(item)
	slot.set_meta("slot_live_signature", _slot_live_signature(item))
	return slot


func _update_detail() -> void:
	var has_selection: bool = not selected_item.is_empty()
	detail_title.text = _item_display_name(selected_item) if has_selection else "No Item"
	detail_rarity.text = _rarity_display(str(selected_item.get("rarity", ""))) if has_selection else ""
	detail_rarity.add_theme_color_override("font_color", _rarity_color(str(selected_item.get("rarity", "common"))))
	detail_category.text = str(selected_item.get("category", "")).to_upper() if has_selection else ""
	detail_description.text = _item_description(selected_item) if has_selection else ""

	var icon_texture: Texture2D = _item_icon_texture(selected_item) if has_selection else null
	detail_frame.texture = _slot_frame_texture(_slot_frame_file_for_item(selected_item))
	detail_selected_frame.texture = _current_selected_slot_texture()
	detail_selected_frame.visible = has_selection
	detail_icon_shadow.texture = icon_texture
	detail_icon_shadow.visible = icon_texture != null and not (has_selection and _is_inventory_upgrade_slot(selected_item))
	_remove_seed_box_icon_overlay(detail_icon_shadow)
	detail_icon.texture = icon_texture
	detail_icon.visible = icon_texture != null and not (has_selection and _is_inventory_upgrade_slot(selected_item))
	_update_seed_box_icon_overlay(detail_icon, selected_item if has_selection else {})
	_apply_colour_cycle_icon_modulation(detail_icon, selected_item if has_selection else {}, 0.0)
	_sync_drop_amount_controls()


func _update_footer(filtered_items: Array) -> void:
	_update_selected_footer()
	var occupied_slots: int = _count_usable_inventory_slots(inventory_items)
	var total_slots: int = _resolve_inventory_slot_count_from_source(inventory_source)
	if total_slots < occupied_slots:
		total_slots = occupied_slots
	count_label.text = str(occupied_slots) + " / " + str(total_slots) + " ITEMS"


func _update_selected_footer() -> void:
	if selected_item.is_empty():
		selected_label.text = "Selected: none"
	else:
		selected_label.text = "Selected: " + _item_display_name(selected_item) + " " + _detail_count_text(selected_item)


func _set_slot_selected(slot_key: String, is_selected: bool) -> void:
	if slot_key == "":
		return
	var slot_node: Node = slot_nodes.get(slot_key, null) as Node
	if slot_node == null or not is_instance_valid(slot_node):
		return
	var selected_frame: TextureRect = slot_node.get_node_or_null("SelectedFrame") as TextureRect
	if selected_frame != null:
		if is_selected:
			selected_frame.texture = _current_selected_slot_texture()
		selected_frame.visible = is_selected


func _update_selection_state(previous_selected_key: String = "") -> void:
	if previous_selected_key != selected_key:
		_set_slot_selected(previous_selected_key, false)
	_set_slot_selected(selected_key, true)
	_update_detail()
	_update_selected_footer()


func _on_tab_pressed(tab_id: String) -> void:
	current_tab = tab_id
	if inventory_scroll != null:
		inventory_scroll.scroll_vertical = 0
	tab_changed.emit(tab_id)
	_refresh()


func _on_search_changed(_new_text: String) -> void:
	if inventory_scroll != null:
		inventory_scroll.scroll_vertical = 0
	_refresh()


func _remove_stale_slot_nodes() -> void:
	var valid_keys: Dictionary = {}
	for item in inventory_items:
		valid_keys[_item_key(item)] = true

	for raw_slot_key in slot_nodes.keys().duplicate():
		var slot_key: String = str(raw_slot_key)
		if valid_keys.has(slot_key):
			continue
		var stale_slot: Node = slot_nodes[slot_key] as Node
		slot_nodes.erase(slot_key)
		visible_slot_keys.erase(slot_key)
		colour_cycle_slot_keys.erase(slot_key)
		if stale_slot != null and is_instance_valid(stale_slot):
			if stale_slot.get_parent() == inventory_grid:
				inventory_grid.remove_child(stale_slot)
			stale_slot.queue_free()


func _select_slot_item(item: Dictionary) -> void:
	if item.is_empty():
		return
	var previous_selected_key: String = selected_key
	selected_item = item
	selected_key = _item_key(item)
	if previous_selected_key != selected_key:
		_update_selection_state(previous_selected_key)
	item_selected.emit(selected_item)


func _is_slot_touch_double_tap(item: Dictionary) -> bool:
	var now: int = Time.get_ticks_msec()
	var tap_key: String = _item_key(item)
	var is_double_tap: bool = last_slot_tap_time_ms > 0 and tap_key == last_slot_tap_key and now - last_slot_tap_time_ms <= SLOT_TOUCH_DOUBLE_TAP_TIME_MS
	last_slot_tap_key = "" if is_double_tap else tap_key
	last_slot_tap_time_ms = 0 if is_double_tap else now
	return is_double_tap


func _is_mobile_touch_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _clear_inventory_scroll_touch() -> void:
	inventory_scroll_touch_index = -1
	inventory_scroll_touch_start_position = Vector2.ZERO
	inventory_scroll_touch_last_position = Vector2.ZERO
	inventory_scroll_touch_value = 0.0
	inventory_scroll_touch_dragging = false


func _scroll_inventory_by_touch_delta(screen_delta_y: float) -> void:
	if inventory_scroll == null:
		return
	var window_scale_y: float = 1.0
	if window != null:
		window_scale_y = maxf(0.01, absf(window.scale.y))
	inventory_scroll_touch_value -= screen_delta_y / window_scale_y
	var max_scroll: float = inventory_scroll_touch_value
	var internal_scrollbar: VScrollBar = inventory_scroll.get_v_scroll_bar()
	if internal_scrollbar != null:
		max_scroll = maxf(0.0, float(internal_scrollbar.max_value) - float(internal_scrollbar.page))
	inventory_scroll_touch_value = clampf(inventory_scroll_touch_value, 0.0, max_scroll)
	inventory_scroll.scroll_vertical = int(round(inventory_scroll_touch_value))


func _clear_active_slot_touch() -> void:
	active_slot_touch_index = -1
	active_slot_touch_key = ""
	active_slot_touch_start_position = Vector2.ZERO
	active_slot_touch_scrolled = false
	active_slot_touch_started_ms = 0
	active_slot_long_press_opened = false


func _handle_slot_touch_tap(slot_key: String) -> void:
	var item: Dictionary = _get_item_for_slot_key(slot_key)
	if item.is_empty() or _is_empty_capacity_slot(item):
		return
	var is_double_tap: bool = _is_slot_touch_double_tap(item)
	_select_slot_item(item)
	if _is_inventory_upgrade_slot(item):
		inventory_upgrade_requested.emit(item)
	elif is_double_tap:
		item_double_action_requested.emit(item)


func _on_inventory_touch_scroll_started() -> void:
	active_slot_touch_scrolled = true
	last_slot_tap_key = ""
	last_slot_tap_time_ms = 0


func _get_item_for_slot_key(slot_key: String) -> Dictionary:
	var item_index: int = _find_inventory_item_index(slot_key)
	if item_index == -1:
		return {}
	return inventory_items[item_index]


func _slot_anchor_position(slot_key: String, fallback_position: Vector2 = Vector2.ZERO) -> Vector2:
	var slot: Control = slot_nodes.get(slot_key, null) as Control
	if slot != null and is_instance_valid(slot):
		return slot.get_global_rect().get_center()
	return fallback_position


func _on_slot_gui_input(event: InputEvent, slot_key: String) -> void:
	var item: Dictionary = _get_item_for_slot_key(slot_key)
	if item.is_empty():
		return
	if _is_mobile_touch_platform() and event is InputEventMouseButton:
		accept_event()
		return
	if _is_empty_capacity_slot(item):
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_select_slot_item(item)
			if _is_inventory_upgrade_slot(item):
				inventory_upgrade_requested.emit(item)
			elif mouse_button.double_click:
				item_double_action_requested.emit(item)
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_select_slot_item(item)
			if _is_inventory_upgrade_slot(item):
				inventory_upgrade_requested.emit(item)
			else:
				item_action_popup_requested.emit(item.duplicate(true), _slot_anchor_position(slot_key, get_viewport().get_mouse_position()))
			accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			active_slot_touch_index = touch.index
			active_slot_touch_key = slot_key
			active_slot_touch_start_position = touch.position
			active_slot_touch_scrolled = false
			active_slot_touch_started_ms = Time.get_ticks_msec()
			active_slot_long_press_opened = false
		elif touch.index == active_slot_touch_index:
			var touch_key: String = active_slot_touch_key
			var was_scrolled: bool = active_slot_touch_scrolled or touch.position.distance_to(active_slot_touch_start_position) > SLOT_TOUCH_SCROLL_DEADZONE
			var opened_long_press: bool = active_slot_long_press_opened
			_clear_active_slot_touch()
			if not was_scrolled and not opened_long_press and touch_key == slot_key:
				_handle_slot_touch_tap(touch_key)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == active_slot_touch_index and drag.position.distance_to(active_slot_touch_start_position) > SLOT_TOUCH_SCROLL_DEADZONE:
			active_slot_touch_scrolled = true


func _on_slot_hovered(slot: Control, hovered: bool) -> void:
	if hovered:
		slot.scale = Vector2(1.045, 1.045)
	else:
		slot.scale = Vector2.ONE


func _on_use_pressed() -> void:
	if selected_item.is_empty():
		return
	if _is_inventory_upgrade_slot(selected_item):
		inventory_upgrade_requested.emit(selected_item)
		return
	if _is_capacity_slot(selected_item):
		return
	primary_action_requested.emit(_selected_payload_with_amount())


func _on_drop_pressed() -> void:
	if selected_item.is_empty():
		return
	if _is_capacity_slot(selected_item):
		return
	drop_requested.emit(_selected_payload_with_amount())


func _on_drop_amount_input_changed(new_text: String) -> void:
	if syncing_drop_amount_controls:
		return
	var text: String = new_text.strip_edges()
	if text == "":
		return
	if not text.is_valid_int():
		_sync_drop_amount_controls()
		return
	drop_amount = _clamp_drop_amount(int(text))
	_sync_drop_amount_controls()


func _on_drop_amount_input_submitted(_new_text: String) -> void:
	_sync_drop_amount_controls()


func _on_drop_amount_input_focus_exited() -> void:
	_sync_drop_amount_controls()


func _on_drop_amount_slider_changed(value: float) -> void:
	if syncing_drop_amount_controls:
		return
	drop_amount = _clamp_drop_amount(int(round(value)))
	_sync_drop_amount_controls()


func _sync_drop_amount_controls() -> void:
	if syncing_drop_amount_controls:
		return
	var available_count: int = _selected_available_count()
	var limit: int = max(DROP_AMOUNT_MIN, available_count)
	var has_available_selection: bool = not selected_item.is_empty() and available_count > 0
	var selected_amount_key: String = selected_key if has_available_selection else ""
	if drop_amount_item_key != selected_amount_key:
		drop_amount_item_key = selected_amount_key
		drop_amount = DROP_AMOUNT_MIN
	else:
		drop_amount = _clamp_drop_amount(drop_amount)
	drop_amount_limit = limit

	syncing_drop_amount_controls = true
	if drop_amount_input != null:
		drop_amount_input.editable = has_available_selection
		drop_amount_input.text = str(drop_amount)
		drop_amount_input.placeholder_text = str(DROP_AMOUNT_MIN)
		drop_amount_input.caret_column = drop_amount_input.text.length()
	if drop_amount_slider != null:
		drop_amount_slider.min_value = float(DROP_AMOUNT_MIN)
		drop_amount_slider.max_value = float(limit)
		drop_amount_slider.step = 1.0
		drop_amount_slider.rounded = true
		drop_amount_slider.value = float(drop_amount)
		drop_amount_slider.editable = has_available_selection and limit > DROP_AMOUNT_MIN
	syncing_drop_amount_controls = false


func _selected_available_count() -> int:
	if selected_item.is_empty():
		return 0
	if _is_capacity_slot(selected_item):
		return 0
	var item_id: String = str(selected_item.get("id", selected_item.get("type", ""))).strip_edges()
	var category: String = str(selected_item.get("category", "")).strip_edges().to_lower()
	if item_id == "" or category == "":
		return 0
	if inventory_source != null and is_instance_valid(inventory_source):
		return _world_item_count(inventory_source, item_id, category)
	return _count_from_value(selected_item.get("count", 0))


func _selected_drop_limit() -> int:
	return max(DROP_AMOUNT_MIN, _selected_available_count())


func _clamp_drop_amount(value: int) -> int:
	return clampi(value, DROP_AMOUNT_MIN, _selected_drop_limit())


func _on_info_pressed() -> void:
	if selected_item.is_empty():
		return
	if _is_capacity_slot(selected_item):
		return
	info_requested.emit(_selected_payload_with_amount())


func _on_trash_pressed() -> void:
	if selected_item.is_empty():
		return
	if _is_capacity_slot(selected_item):
		return
	trash_requested.emit(_selected_payload_with_amount())


func _selected_payload_with_amount() -> Dictionary:
	var payload: Dictionary = selected_item.duplicate(true)
	var safe_amount: int = _clamp_drop_amount(drop_amount)
	payload["amount"] = safe_amount
	payload["drop_amount"] = safe_amount
	return payload


func _setup_inventory_scroll_slider() -> void:
	if inventory_scroll == null or inventory_scroll_slider == null or inventory_scroll_track == null or inventory_scroll_handle == null:
		return

	inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	inventory_scroll.scroll_deadzone = int(SLOT_TOUCH_SCROLL_DEADZONE)
	var touch_scroll_callback: Callable = Callable(self, "_on_inventory_touch_scroll_started")
	if not inventory_scroll.scroll_started.is_connected(touch_scroll_callback):
		inventory_scroll.scroll_started.connect(touch_scroll_callback)

	var internal_scrollbar: VScrollBar = inventory_scroll.get_v_scroll_bar()
	if internal_scrollbar != null:
		var internal_callback: Callable = Callable(self, "_on_inventory_scroll_changed")
		if not internal_scrollbar.value_changed.is_connected(internal_callback):
			internal_scrollbar.value_changed.connect(internal_callback)
		var range_callback: Callable = Callable(self, "_queue_inventory_scroll_slider_sync")
		if not internal_scrollbar.changed.is_connected(range_callback):
			internal_scrollbar.changed.connect(range_callback)

	var track_input_callback: Callable = Callable(self, "_on_inventory_scroll_track_gui_input")
	if not inventory_scroll_track.gui_input.is_connected(track_input_callback):
		inventory_scroll_track.gui_input.connect(track_input_callback)
	var handle_input_callback: Callable = Callable(self, "_on_inventory_scroll_handle_gui_input")
	if not inventory_scroll_handle.gui_input.is_connected(handle_input_callback):
		inventory_scroll_handle.gui_input.connect(handle_input_callback)

	var resize_callback: Callable = Callable(self, "_queue_inventory_scroll_slider_sync")
	if not inventory_scroll.resized.is_connected(resize_callback):
		inventory_scroll.resized.connect(resize_callback)
	if not inventory_grid.resized.is_connected(resize_callback):
		inventory_grid.resized.connect(resize_callback)
	if not inventory_scroll_track.resized.is_connected(resize_callback):
		inventory_scroll_track.resized.connect(resize_callback)
	if not inventory_scroll_handle.resized.is_connected(resize_callback):
		inventory_scroll_handle.resized.connect(resize_callback)

	_queue_inventory_scroll_slider_sync()


func _queue_inventory_scroll_slider_sync() -> void:
	if inventory_scroll_layout_sync_queued:
		return
	inventory_scroll_layout_sync_queued = true
	call_deferred("_sync_inventory_scroll_layout")


func _sync_inventory_scroll_layout() -> void:
	_update_inventory_bottom_scroll_padding()
	_sync_inventory_scroll_slider()
	inventory_scroll_layout_sync_queued = false


func _update_inventory_bottom_scroll_padding() -> void:
	if inventory_scroll == null or inventory_grid == null:
		return

	var visible_slot_count: int = visible_slot_keys.size()
	var target_minimum_height := 0.0
	if visible_slot_count > 0:
		var column_count: int = maxi(1, inventory_grid.columns)
		var row_count: int = ceili(float(visible_slot_count) / float(column_count))
		var slot_rows_height: float = float(row_count) * SLOT_SIZE.y
		var row_spacing_height: float = float(maxi(0, row_count - 1) * SLOT_GRID_V_SEPARATION)
		var bottom_padding_height: float = maxf(0.0, inventory_scroll.size.y * INVENTORY_BOTTOM_SCROLL_PADDING_RATIO)
		target_minimum_height = slot_rows_height + row_spacing_height + bottom_padding_height

	var minimum_size: Vector2 = inventory_grid.custom_minimum_size
	if is_equal_approx(minimum_size.y, target_minimum_height):
		return
	minimum_size.y = target_minimum_height
	inventory_grid.custom_minimum_size = minimum_size


func _sync_inventory_scroll_slider() -> void:
	if inventory_scroll == null or inventory_scroll_slider == null or inventory_scroll_track == null or inventory_scroll_handle == null:
		return

	var internal_scrollbar: VScrollBar = inventory_scroll.get_v_scroll_bar()
	if internal_scrollbar == null:
		return

	var internal_max_scroll: float = maxf(0.0, float(internal_scrollbar.max_value) - float(internal_scrollbar.page))
	var has_scroll_range: bool = internal_max_scroll > 0.5
	var normalized_scroll: float = 0.0
	if has_scroll_range:
		normalized_scroll = clampf(float(inventory_scroll.scroll_vertical) / internal_max_scroll, 0.0, 1.0)
	inventory_scroll_slider.visible = true
	inventory_scroll_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_scroll_track.mouse_filter = Control.MOUSE_FILTER_STOP if has_scroll_range else Control.MOUSE_FILTER_IGNORE
	inventory_scroll_handle.mouse_filter = Control.MOUSE_FILTER_STOP if has_scroll_range else Control.MOUSE_FILTER_IGNORE
	var handle_travel: float = _inventory_scroll_handle_travel()
	var handle_position: Vector2 = inventory_scroll_handle.position
	handle_position.y = inventory_scroll_track.position.y + normalized_scroll * handle_travel
	inventory_scroll_handle.position = handle_position
	if not has_scroll_range:
		inventory_scroll.scroll_vertical = 0
		inventory_scroll_touch_value = 0.0
		inventory_scroll_handle_dragging = false
		inventory_scroll_handle_touch_index = -1


func _inventory_scroll_maximum() -> float:
	if inventory_scroll == null:
		return 0.0
	var internal_scrollbar: VScrollBar = inventory_scroll.get_v_scroll_bar()
	if internal_scrollbar == null:
		return 0.0
	return maxf(0.0, float(internal_scrollbar.max_value) - float(internal_scrollbar.page))


func _inventory_scroll_handle_travel() -> float:
	if inventory_scroll_track == null or inventory_scroll_handle == null:
		return 0.0
	return maxf(0.0, inventory_scroll_track.size.y - inventory_scroll_handle.size.y)


func _inventory_scroll_slider_local_y(screen_position: Vector2) -> float:
	if inventory_scroll_slider == null:
		return 0.0
	return (inventory_scroll_slider.get_global_transform_with_canvas().affine_inverse() * screen_position).y


func _set_inventory_scroll_from_handle_top(handle_top: float) -> void:
	if inventory_scroll == null or inventory_scroll_track == null:
		return
	var internal_max_scroll: float = _inventory_scroll_maximum()
	var handle_travel: float = _inventory_scroll_handle_travel()
	if internal_max_scroll <= 0.5 or handle_travel <= 0.0:
		inventory_scroll.scroll_vertical = 0
		_sync_inventory_scroll_slider()
		return
	var normalized_scroll: float = clampf((handle_top - inventory_scroll_track.position.y) / handle_travel, 0.0, 1.0)
	inventory_scroll.scroll_vertical = int(round(normalized_scroll * internal_max_scroll))


func _handle_inventory_scroll_pointer_event(event: InputEvent, center_handle_on_press: bool) -> void:
	if _inventory_scroll_maximum() <= 0.5 or inventory_scroll_handle == null:
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_clear_inventory_scroll_touch()
			inventory_scroll_handle_dragging = true
			inventory_scroll_handle_touch_index = -1
			var pointer_y: float = _inventory_scroll_slider_local_y(get_viewport().get_mouse_position())
			inventory_scroll_handle_drag_offset_y = inventory_scroll_handle.size.y * 0.5 if center_handle_on_press else pointer_y - inventory_scroll_handle.position.y
			_set_inventory_scroll_from_handle_top(pointer_y - inventory_scroll_handle_drag_offset_y)
		else:
			inventory_scroll_handle_dragging = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and inventory_scroll_handle_dragging and inventory_scroll_handle_touch_index == -1:
		var pointer_y: float = _inventory_scroll_slider_local_y(get_viewport().get_mouse_position())
		_set_inventory_scroll_from_handle_top(pointer_y - inventory_scroll_handle_drag_offset_y)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_clear_inventory_scroll_touch()
			inventory_scroll_handle_dragging = true
			inventory_scroll_handle_touch_index = touch.index
			var pointer_y: float = _inventory_scroll_slider_local_y(touch.position)
			inventory_scroll_handle_drag_offset_y = inventory_scroll_handle.size.y * 0.5 if center_handle_on_press else pointer_y - inventory_scroll_handle.position.y
			_set_inventory_scroll_from_handle_top(pointer_y - inventory_scroll_handle_drag_offset_y)
		elif touch.index == inventory_scroll_handle_touch_index:
			inventory_scroll_handle_dragging = false
			inventory_scroll_handle_touch_index = -1
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if inventory_scroll_handle_dragging and drag.index == inventory_scroll_handle_touch_index:
			var pointer_y: float = _inventory_scroll_slider_local_y(drag.position)
			_set_inventory_scroll_from_handle_top(pointer_y - inventory_scroll_handle_drag_offset_y)
			get_viewport().set_input_as_handled()


func _on_inventory_scroll_track_gui_input(event: InputEvent) -> void:
	_handle_inventory_scroll_pointer_event(event, true)


func _on_inventory_scroll_handle_gui_input(event: InputEvent) -> void:
	_handle_inventory_scroll_pointer_event(event, false)


func _on_inventory_scroll_changed(_value: float) -> void:
	if inventory_scroll_slider == null:
		return
	_sync_inventory_scroll_slider()


func _setup_mouse_passthrough() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if window != null:
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tabs != null:
		tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if inventory_grid != null:
		inventory_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if inventory_scroll != null:
		inventory_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE if _is_mobile_touch_platform() else Control.MOUSE_FILTER_PASS

	for node_path in [
		"Dimmer",
		"Window/WindowSkin",
		"Window/HeaderSkin",
		"Window/HeaderSkin/GemCounterBack",
		"Window/HeaderSkin/GemIconSlot",
		"Window/HeaderSkin/GemIcon",
		"Window/HeaderSkin/GemCounterLabel",
		"Window/SubtitleLabel",
		"Window/TabSkin",
		"Window/GridSkin",
		"Window/EmptyState",
		"Window/DetailSkin",
		"Window/DetailTitle",
		"Window/DetailRarity",
		"Window/DetailCategory",
		"Window/DetailPreviewSlot",
		"Window/DetailPreviewSlot/Frame",
		"Window/DetailPreviewSlot/SelectedFrame",
		"Window/DetailPreviewSlot/IconShadow",
		"Window/DetailPreviewSlot/Icon",
		"Window/DetailDescription",
		"Window/FooterSkin",
		"Window/FooterSelectedLabel",
		"Window/FooterCountLabel"
	]:
		var decorative_control: Control = get_node_or_null(node_path) as Control
		if decorative_control != null:
			decorative_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for control in [
		search_input,
		close_button,
		drop_amount_input,
		drop_amount_slider,
		use_button,
		drop_button,
		info_button,
		trash_button
	]:
		var interactive_control: Control = control as Control
		if interactive_control != null:
			interactive_control.mouse_filter = Control.MOUSE_FILTER_STOP
	if inventory_scroll_slider != null:
		inventory_scroll_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _control_contains_screen_point(control: Control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.has_point(point)


func _style_static_nodes() -> void:
	var title_label: Label = get_node_or_null("Window/TitleLabel") as Label
	if title_label != null:
		_apply_label_style(title_label, 28, Color(0.96, 0.99, 1.0, 1.0))
	_apply_label_style($Window/SubtitleLabel, 13, Color(0.74, 0.92, 1.0, 0.92))
	_apply_label_style(empty_state, 18, Color(0.7, 0.88, 0.96, 0.8))
	_apply_label_style(detail_title, 20, Color(0.96, 0.99, 1.0, 1.0))
	_apply_label_style(detail_rarity, 14, Color(0.65, 0.9, 1.0, 1.0))
	_apply_label_style(detail_category, 12, Color(0.74, 0.92, 1.0, 0.86))
	_apply_label_style(selected_label, 14, Color(0.9, 0.98, 1.0, 1.0))
	_apply_label_style(count_label, 13, Color(0.95, 0.85, 0.35, 1.0))
	_apply_label_style(gem_counter_label, 16, Color(1.0, 0.9, 0.34, 1.0))

	detail_description.add_theme_font_size_override("normal_font_size", 13)
	detail_description.add_theme_color_override("default_color", Color(0.78, 0.92, 0.98, 0.92))
	detail_description.bbcode_enabled = false
	detail_description.fit_content = false
	detail_description.scroll_active = false

	inventory_grid.add_theme_constant_override("h_separation", SLOT_GRID_H_SEPARATION)
	inventory_grid.add_theme_constant_override("v_separation", SLOT_GRID_V_SEPARATION)


func _setup_detail_preview_texture_rects() -> void:
	for texture_rect in [detail_frame, detail_selected_frame, detail_icon_shadow, detail_icon]:
		if texture_rect == null:
			continue
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_label_style(label: Label, font_size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _make_texture_stylebox(file_name: String, margin: float) -> StyleBoxTexture:
	var texture: Texture2D = _load_ui_texture(file_name)
	if texture == null:
		return null
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.draw_center = true
	return style


func _flat_box(fill: Color, border: Color, border_width: int, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = shadow_size
	return style


func _load_texture_path(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is Texture2D:
		return resource
	return null


func _load_ui_texture(file_name: String) -> Texture2D:
	if ui_texture_cache.has(file_name):
		return ui_texture_cache[file_name] as Texture2D
	var path: String = UI_PATH + file_name
	if not ResourceLoader.exists(path):
		path = ROOT_UI_PATH + file_name
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is Texture2D:
		ui_texture_cache[file_name] = resource
		return resource as Texture2D
	return null


func _load_hotbar_slot_texture(file_name: String) -> Texture2D:
	var cache_key: String = "hotbar:" + file_name
	if ui_texture_cache.has(cache_key):
		return ui_texture_cache[cache_key] as Texture2D
	var texture: Texture2D = _load_texture_path(HOTBAR_UI_PATH + file_name)
	if texture != null:
		ui_texture_cache[cache_key] = texture
	return texture


func _slot_frame_texture(file_name: String) -> Texture2D:
	var texture: Texture2D = _load_hotbar_slot_texture(file_name)
	if texture != null:
		return texture
	return _load_ui_texture(file_name)


func _current_selected_slot_texture() -> Texture2D:
	if SELECTED_SLOT_FRAMES.is_empty():
		return null
	selected_slot_frame_index = SelectedSlotFrameClock.frame_index(
		SELECTED_SLOT_FRAMES.size(),
		SELECTED_SLOT_FRAME_SECONDS
	)
	return SELECTED_SLOT_FRAMES[selected_slot_frame_index] as Texture2D


func update_selected_slot_frame_animation(_delta: float) -> void:
	if not visible or SELECTED_SLOT_FRAMES.is_empty():
		return
	var next_frame_index: int = SelectedSlotFrameClock.frame_index(
		SELECTED_SLOT_FRAMES.size(),
		SELECTED_SLOT_FRAME_SECONDS
	)
	if next_frame_index == selected_slot_frame_index:
		return
	selected_slot_frame_index = next_frame_index
	var selected_texture: Texture2D = SELECTED_SLOT_FRAMES[selected_slot_frame_index] as Texture2D
	if selected_key != "":
		var selected_slot: Button = slot_nodes.get(selected_key, null) as Button
		if selected_slot != null and is_instance_valid(selected_slot):
			var selected_frame: TextureRect = selected_slot.get_node_or_null("SelectedFrame") as TextureRect
			if selected_frame != null and selected_frame.visible:
				selected_frame.texture = selected_texture
	if detail_selected_frame != null and detail_selected_frame.visible:
		detail_selected_frame.texture = selected_texture


func _colour_cycle_item_data(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	if ColourCycleModulation.is_colour_cycle_item(item):
		return item
	if inventory_source != null and is_instance_valid(inventory_source) and inventory_source.has_method("get_item_data"):
		var source_item_data: Variant = inventory_source.call("get_item_data", str(item.get("id", "")))
		if source_item_data is Dictionary and ColourCycleModulation.is_colour_cycle_item(source_item_data):
			return source_item_data
	return {}


func _is_colour_cycle_item(item: Dictionary) -> bool:
	return str(item.get("category", "")).strip_edges().to_lower() == "block" and not _colour_cycle_item_data(item).is_empty()


func _colour_cycle_icon_modulate(item: Dictionary, phase_seed: float = 0.0) -> Color:
	var item_data := _colour_cycle_item_data(item)
	if item_data.is_empty():
		return Color.WHITE
	return ColourCycleModulation.get_colour_cycle_modulate(item_data, phase_seed)


func _apply_colour_cycle_icon_modulation(icon: TextureRect, _item: Dictionary, _phase_seed: float = 0.0) -> void:
	if icon == null:
		return
	icon.self_modulate = Color.WHITE


func track_colour_cycle_slot(slot_key: String, _item: Dictionary) -> void:
	if slot_key == "":
		return
	colour_cycle_slot_keys.erase(slot_key)


func update_colour_cycle_icon_modulation_throttled(_delta: float) -> void:
	if not colour_cycle_slot_keys.is_empty():
		update_colour_cycle_icon_modulation()
		colour_cycle_slot_keys.clear()
	colour_cycle_icon_update_elapsed = 0.0


func update_colour_cycle_icon_modulation() -> void:
	for slot_key in colour_cycle_slot_keys.keys():
		var slot: Control = slot_nodes.get(slot_key, null)
		if slot == null or not is_instance_valid(slot):
			colour_cycle_slot_keys.erase(slot_key)
			continue
		var item: Dictionary = _get_item_for_slot_key(str(slot_key))
		if not _is_colour_cycle_item(item):
			colour_cycle_slot_keys.erase(slot_key)
			var stale_icon := slot.get_node_or_null("Icon") as TextureRect
			if stale_icon != null:
				stale_icon.self_modulate = Color.WHITE
			continue
		var icon := slot.get_node_or_null("Icon") as TextureRect
		_apply_colour_cycle_icon_modulation(icon, item, float(str(slot_key).hash() % 1000) / 1000.0)
	if detail_icon != null:
		_apply_colour_cycle_icon_modulation(detail_icon, selected_item, 0.0)


func _item_icon_texture(item: Dictionary) -> Texture2D:
	if item.is_empty():
		return null
	if _is_seed_item(item):
		if inventory_source != null and is_instance_valid(inventory_source) and inventory_source.has_method("get_seed_drop_icon_texture"):
			var seed_box_texture: Variant = inventory_source.call("get_seed_drop_icon_texture", str(item.get("id", "")))
			if seed_box_texture is Texture2D:
				return seed_box_texture
		var seed_layout := _seed_preview_layout(item)
		var box_texture: Variant = seed_layout.get("box_texture", null)
		if box_texture is Texture2D:
			return box_texture
	for key in ["icon_texture", "texture", "icon_path", "icon", "inventory_icon"]:
		if not item.has(key):
			continue
		var texture: Texture2D = AtlasTextureFactory.load_texture(item[key])
		if texture != null:
				return texture
	return null


func _is_seed_item(item: Dictionary) -> bool:
	var item_id: String = str(item.get("id", "")).strip_edges()
	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	return category == "seed" or item_id.ends_with("_seed")


func _remove_seed_box_icon_overlay(icon: TextureRect) -> void:
	if icon == null:
		return
	var existing: Node = icon.get_node_or_null(SEED_BOX_PREVIEW_NODE_NAME)
	if existing != null:
		icon.remove_child(existing)
		existing.queue_free()


func _update_seed_box_icon_overlay(icon: TextureRect, item: Dictionary) -> void:
	if icon == null:
		return
	if item.is_empty() or not _is_seed_item(item) or icon.texture == null:
		_remove_seed_box_icon_overlay(icon)
		return

	var layout: Dictionary = _seed_preview_layout(item)
	if layout.is_empty():
		_remove_seed_box_icon_overlay(icon)
		return

	var preview_value: Variant = layout.get("preview_texture", null)
	var preview_texture: Texture2D = preview_value as Texture2D
	var box_size: Vector2i = _layout_vector2i(layout, "box_size")
	var preview_size: Vector2i = _layout_vector2i(layout, "preview_size")
	var destination: Vector2i = _layout_vector2i(layout, "destination")
	if preview_texture == null or box_size.x <= 0 or box_size.y <= 0 or preview_size.x <= 0 or preview_size.y <= 0:
		_remove_seed_box_icon_overlay(icon)
		return
	if icon.size.x <= 0.0 or icon.size.y <= 0.0:
		_remove_seed_box_icon_overlay(icon)
		return

	var preview: TextureRect = icon.get_node_or_null(SEED_BOX_PREVIEW_NODE_NAME) as TextureRect
	if preview == null:
		var stale_preview: Node = icon.get_node_or_null(SEED_BOX_PREVIEW_NODE_NAME)
		if stale_preview != null:
			icon.remove_child(stale_preview)
			stale_preview.queue_free()
		preview = TextureRect.new()
		preview.name = SEED_BOX_PREVIEW_NODE_NAME
		icon.add_child(preview)

	var source_size := Vector2(
		float(max(1, int(preview_texture.get_width()))),
		float(max(1, int(preview_texture.get_height())))
	)
	var fit_scale: float = min(icon.size.x / float(box_size.x), icon.size.y / float(box_size.y))
	var box_display_size: Vector2 = Vector2(box_size) * fit_scale
	var box_offset: Vector2 = (icon.size - box_display_size) * 0.5
	preview.texture = preview_texture
	preview.position = box_offset + Vector2(destination) * fit_scale
	preview.size = source_size
	preview.scale = Vector2(
		(float(preview_size.x) / source_size.x) * fit_scale,
		(float(preview_size.y) / source_size.y) * fit_scale
	)
	preview.pivot_offset = Vector2.ZERO
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.visible = true


func _seed_preview_layout(item: Dictionary) -> Dictionary:
	var layout_value: Variant = item.get("seed_preview_layout", {})
	if layout_value is Dictionary and not layout_value.is_empty():
		return layout_value

	if inventory_source != null and is_instance_valid(inventory_source) and inventory_source.has_method("get_seed_icon_preview_layout"):
		var source_layout_value: Variant = inventory_source.call("get_seed_icon_preview_layout", str(item.get("id", "")))
		if source_layout_value is Dictionary:
			return source_layout_value

	return {}


func _layout_vector2i(layout: Dictionary, key: String) -> Vector2i:
	var value: Variant = layout.get(key, Vector2i.ZERO)
	if value is Vector2i:
		return value
	if value is Vector2:
		var vector_value: Vector2 = value
		return Vector2i(int(round(vector_value.x)), int(round(vector_value.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		var dictionary: Dictionary = value
		return Vector2i(
			int(dictionary.get("x", dictionary.get("width", 0))),
			int(dictionary.get("y", dictionary.get("height", 0)))
		)
	return Vector2i.ZERO


func _slot_frame_file(rarity: String) -> String:
	match _normalized_rarity(rarity):
		"common":
			return "slot_common.png"
		"uncommon":
			return "slot_uncommon.png"
		"rare":
			return "slot_rare.png"
		"epic":
			return "slot_epic.png"
		"legendary":
			return "slot_legendary.png"
		_:
			return "slot_normal.png"


func _resolve_item_equipable(source: Object, item_id: String, category: String) -> bool:
	if source != null and source.has_method("is_item_equipable"):
		return bool(source.call("is_item_equipable", item_id, category))
	return _is_equipment_category(category)


func _is_material_item(item: Dictionary) -> bool:
	return str(item.get("category", "")).strip_edges().to_lower() == "material"


func _is_equipable_item(item: Dictionary) -> bool:
	if item.has("equipable"):
		return bool(item.get("equipable", false))
	return _is_equipment_category(str(item.get("category", "")))


func _slot_frame_file_for_item(item: Dictionary) -> String:
	if _is_empty_capacity_slot(item):
		return EMPTY_SLOT_TEXTURE
	if _is_inventory_upgrade_slot(item):
		return INVENTORY_UPGRADE_SLOT_TEXTURE
	if _is_material_item(item):
		return MATERIAL_SLOT_TEXTURE
	if _is_equipable_item(item):
		return CLOTHES_SLOT_TEXTURE
	return _slot_frame_file(_normalized_rarity(str(item.get("rarity", "common"))))


func _normalized_rarity(rarity: String) -> String:
	return rarity.strip_edges().to_lower()


func _apply_slot_rarity_visuals(slot: Button, item: Dictionary) -> void:
	if slot == null:
		return
	var frame_file_name: String = _slot_frame_file_for_item(item)
	var visual_key: String = str(slot.get_meta("special_slot", "")) + ":" + frame_file_name
	if str(slot.get_meta("rarity_visual_key", "")) == visual_key:
		return
	var frame: TextureRect = slot.get_node_or_null("Frame") as TextureRect
	if frame != null:
		var frame_texture: Texture2D = _slot_frame_texture(frame_file_name)
		if frame_texture != null:
			frame.texture = frame_texture
	var selected_frame: TextureRect = slot.get_node_or_null("SelectedFrame") as TextureRect
	if selected_frame != null:
		var selected_texture: Texture2D = _current_selected_slot_texture()
		if selected_texture != null:
			selected_frame.texture = selected_texture
	var rarity_pip: Panel = slot.get_node_or_null("RarityPip") as Panel
	if rarity_pip != null:
		rarity_pip.visible = false
	slot.set_meta("rarity_visual_key", visual_key)


func _item_key(item: Dictionary) -> String:
	return str(item.get("category", "item")) + ":" + str(item.get("id", ""))


func _item_key_from_parts(category: String, item_id: String) -> String:
	return category + ":" + item_id


func _find_inventory_item_index(slot_key: String) -> int:
	for item_index in range(inventory_items.size()):
		var item: Dictionary = inventory_items[item_index]
		if _item_key(item) == slot_key:
			return item_index
	return -1


func _inventory_property_for_category(category: String) -> String:
	match category:
		"block":
			return "inventory"
		"seed":
			return "seed_inventory"
		"tool":
			return "tool_inventory"
		"material":
			return "material_inventory"
		"lure":
			return "lure_inventory"
		"fish":
			return "fish_inventory"
		"back":
			return "back_inventory"
		"hat":
			return "hat_inventory"
		"hair":
			return "hair_inventory"
		"eyewear":
			return "eyewear_inventory"
		"beard":
			return "beard_inventory"
		"shirt":
			return "shirt_inventory"
		"pants":
			return "pants_inventory"
		"shoes":
			return "shoes_inventory"
		"ride":
			return "ride_inventory"
		"currency":
			return "currency_inventory"
		_:
			return ""


func _world_item_count(source: Object, item_id: String, category: String) -> int:
	if source == null:
		return 0
	if source.has_method("get_item_count"):
		var method_count: Variant = source.call("get_item_count", item_id, category)
		return _count_from_value(method_count)

	var property_name: String = _inventory_property_for_category(category)
	if property_name == "":
		return 0
	var inventory_value: Variant = source.get(property_name)
	if not (inventory_value is Dictionary):
		return 0
	var inventory: Dictionary = inventory_value
	return _count_from_value(inventory.get(item_id, 0))


func _world_item_equipped(source: Object, item_id: String, category: String) -> bool:
	if source == null:
		return false
	var equipped_property: String = _equipped_property_for_category(category)
	return equipped_property != "" and str(source.get(equipped_property)) == item_id


func _slot_live_signature(item: Dictionary) -> String:
	return "|".join([
		str(item.get("special_slot", "")),
		_normalized_rarity(str(item.get("rarity", "common"))),
		_slot_frame_file_for_item(item),
		_slot_count_text(item),
		"1" if bool(item.get("equipped", false)) else "0",
		_item_display_name(item),
		_detail_count_text(item)
	])


func _refresh_slot_live(slot_key: String, item: Dictionary) -> void:
	var slot: Button = slot_nodes.get(slot_key, null) as Button
	if slot == null:
		return
	var selected_frame: TextureRect = slot.get_node_or_null("SelectedFrame") as TextureRect
	if selected_frame != null:
		var is_selected: bool = slot_key == selected_key
		if is_selected:
			selected_frame.texture = _current_selected_slot_texture()
		selected_frame.visible = is_selected
	var live_signature: String = _slot_live_signature(item)
	if str(slot.get_meta("slot_live_signature", "")) == live_signature:
		return

	slot.set_meta("special_slot", str(item.get("special_slot", "")))
	_apply_slot_rarity_visuals(slot, item)

	var count_text: String = _slot_count_text(item)
	var label: Label = slot.get_node_or_null("Count") as Label
	if label != null:
		label.visible = count_text != ""
		label.text = count_text

	var equipped_label: Label = slot.get_node_or_null("Equipped") as Label
	if equipped_label != null:
		equipped_label.visible = bool(item.get("equipped", false))
		if bool(slot.get_meta("generated_equipped_label", false)):
			equipped_label.text = "✓"

	slot.tooltip_text = _item_display_name(item) + " " + _detail_count_text(item)
	slot.set_meta("slot_live_signature", live_signature)


func _item_display_name(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	return str(item.get("display_name", item.get("name", item.get("id", ""))))


func _item_description(item: Dictionary) -> String:
	var description: String = str(item.get("description", "")).strip_edges()
	if description != "":
		return description
	if _is_empty_capacity_slot(item):
		return "Inventory space."
	var category: String = str(item.get("category", "item")).capitalize()
	return category + " item ready for the active inventory action."


func _slot_count_text(item: Dictionary) -> String:
	if _is_capacity_slot(item):
		return ""
	var count: int = _count_from_value(item.get("count", 0))
	if count <= 1 and not _is_equipment_category(str(item.get("category", ""))):
		return ""
	return _compact_count(count)


func _detail_count_text(item: Dictionary) -> String:
	if _is_capacity_slot(item):
		return ""
	var count: int = _count_from_value(item.get("count", 0))
	return "x" + _compact_count(count)


func _count_from_value(value) -> int:
	if value is int:
		return max(0, int(value))
	if value is float:
		return max(0, int(floor(float(value))))
	if value is String:
		var text: String = str(value).strip_edges()
		if text.is_valid_int():
			return max(0, int(text))
		if text.is_valid_float():
			return max(0, int(floor(float(text))))
	if value is Dictionary:
		var dictionary: Dictionary = value
		return _count_from_value(dictionary.get("count", dictionary.get("amount", 0)))
	return 0


func _compact_count(count: int) -> String:
	if count >= 1000000:
		return str(int(floor(float(count) / 1000000.0))) + "m"
	if count >= 10000:
		return str(int(floor(float(count) / 1000.0))) + "k"
	return str(count)


func _rarity_display(rarity: String) -> String:
	return _normalized_rarity(rarity).capitalize()


func _rarity_color(rarity: String) -> Color:
	match _normalized_rarity(rarity):
		"uncommon":
			return Color(0.45, 1.0, 0.52, 1.0)
		"rare":
			return Color(0.40, 0.76, 1.0, 1.0)
		"epic":
			return Color(0.92, 0.56, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.78, 0.22, 1.0)
		"currency":
			return Color(0.45, 1.0, 1.0, 1.0)
		_:
			return Color(0.82, 0.95, 1.0, 1.0)


func _rarity_pip_fill_color(rarity: String) -> Color:
	var normalized_rarity: String = _normalized_rarity(rarity)
	if normalized_rarity == "common" or normalized_rarity == "":
		return Color(0.10, 0.24, 0.34, 0.95)
	var color: Color = _rarity_color(normalized_rarity)
	return Color(color.r * 0.78, color.g * 0.78, color.b * 0.78, 0.95)


func _is_equipment_category(category: String) -> bool:
	return category in ["tool", "back", "hat", "hair", "eyewear", "beard", "shirt", "pants", "shoes", "ride"]


func _equipped_property_for_category(category: String) -> String:
	match category:
		"tool":
			return "equipped_tool"
		"back":
			return "equipped_back_item"
		"hat":
			return "equipped_hat_item"
		"hair":
			return "equipped_hair_item"
		"eyewear":
			return "equipped_eyewear_item"
		"beard":
			return "equipped_beard_item"
		"shirt":
			return "equipped_shirt_item"
		"pants":
			return "equipped_pants_item"
		"shoes":
			return "equipped_shoes_item"
		"ride":
			return "equipped_ride_item"
		_:
			return ""


func _fit_window_to_viewport() -> void:
	if not is_inside_tree() or window == null or drawer_transform_managed:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		window.scale = Vector2.ONE
		return
	var target_scale := 1.0
	if _is_mobile_touch_platform():
		target_scale = clampf(
			float(ProjectSettings.get_setting_with_override(MOBILE_GUI_SCALE_SETTING)),
			1.0,
			MAX_UNIFORM_GUI_SCALE
		)
	var fit_scale: float = minf(
		(viewport_size.x - 24.0) / WINDOW_VISUAL_SIZE.x,
		(viewport_size.y - 24.0) / WINDOW_VISUAL_SIZE.y
	)
	var scale_amount := clampf(minf(target_scale, fit_scale), 0.28, target_scale)
	window.scale = Vector2.ONE * scale_amount


func _apply_texture_filter(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_apply_texture_filter(child)


func _make_preview_items() -> Array:
	return [
		{"id": "dirt_block", "display_name": "Dirt Block", "category": "block", "count": 124, "rarity": "common", "icon_path": "res://Assets/inventory_icons/dirt_block.png", "description": "A basic building block for rough terrain and starter builds."},
		{"id": "grass_block", "display_name": "Grass Block", "category": "block", "count": 96, "rarity": "common", "icon_path": "res://Assets/inventory_icons/grass_block.png", "description": "A bright natural block for surface worlds."},
		{"id": "glass_panel", "display_name": "Glass Panel", "category": "block", "count": 32, "rarity": "rare", "icon_path": "res://Assets/inventory_icons/glass_panel.png", "description": "A refined transparent panel for windows and display builds."},
		{"id": "gem_block", "display_name": "Gem Block", "category": "block", "count": 8, "rarity": "epic", "icon_path": "res://Assets/inventory_icons/gem_block.png", "description": "A polished block with a bright gem sheen."},
		{"id": "world_lock", "display_name": "World Lock", "category": "block", "count": 3, "rarity": "legendary", "icon_path": "res://Assets/inventory_icons/world_lock.png", "description": "Protects a world and marks ownership."},
		{"id": "dirt_seed", "display_name": "Dirt Seed", "category": "seed", "count": 48, "rarity": "common", "icon_path": "res://Assets/inventory_icons/dirt_seed.png", "description": "Plant and splice this to grow more dirt blocks."},
		{"id": "blue_block_seed", "display_name": "Blue Block Seed", "category": "seed", "count": 21, "rarity": "uncommon", "icon_path": "res://Assets/inventory_icons/blue_block_seed.png", "description": "A seed for growing blue block trees."},
		{"id": "rose_seed", "display_name": "Rose Seed", "category": "seed", "count": 14, "rarity": "uncommon", "icon_path": "res://Assets/inventory_icons/rose_seed.png", "description": "A flower seed for decorative splices."},
		{"id": "pickaxe", "display_name": "Pickaxe", "category": "tool", "count": 1, "rarity": "common", "icon_path": "res://Assets/inventory_icons/pickaxe.png", "description": "A reliable tool for breaking blocks.", "equipped": true},
		{"id": "fishing_rod", "display_name": "Fishing Rod", "category": "tool", "count": 1, "rarity": "rare", "icon_path": "res://Assets/inventory_icons/fishing_rod.png", "description": "Cast into water to catch fish and treasure."},
		{"id": "sakura_sword", "display_name": "Sakura Sword", "category": "tool", "count": 1, "rarity": "epic", "icon_path": "res://Assets/inventory_icons/sakura_sword.png", "description": "A sharp event weapon with a blossom trail."},
		{"id": "metal_scrap", "display_name": "Metal Scrap", "category": "material", "count": 73, "rarity": "common", "icon_path": "res://Assets/inventory_icons/metal_scrap.png", "description": "A crafting material recovered from junk."},
		{"id": "refined_glass", "display_name": "Refined Glass", "category": "material", "count": 18, "rarity": "rare", "icon_path": "res://Assets/inventory_icons/refined_glass.png", "description": "A clean furnace output for advanced recipes."},
		{"id": "golden_lure", "display_name": "Golden Lure", "category": "lure", "count": 6, "rarity": "epic", "icon_path": "res://Assets/inventory_icons/golden_lure.png", "description": "A high-value lure for better fishing rewards."},
		{"id": "crystal_fish", "display_name": "Crystal Fish", "category": "fish", "count": 2, "rarity": "legendary", "icon_path": "res://Assets/inventory_icons/crystal_fish.png", "description": "A rare catch with a crystalline glow."},
		{"id": "evilangel_wings", "display_name": "Evil Angel Wings", "category": "back", "count": 1, "rarity": "legendary", "icon_path": "res://Assets/inventory_icons/evilangel_wings.png", "description": "A dramatic back item for character fashion."},
		{"id": "purple_shirt", "display_name": "Purple Shirt", "category": "shirt", "count": 1, "rarity": "uncommon", "icon_path": "res://Assets/inventory_icons/purple_shirt.png", "description": "A wearable shirt cosmetic."},
		{"id": "purple_pants", "display_name": "Purple Pants", "category": "pants", "count": 1, "rarity": "uncommon", "icon_path": "res://Assets/inventory_icons/purple_pants.png", "description": "A wearable pants cosmetic."},
		{"id": "gem", "display_name": "Gem", "category": "currency", "count": 1280, "rarity": "currency", "icon_path": "res://Assets/inventory_icons/gem.png", "description": "Premium currency used across shops and rewards."}
	]
