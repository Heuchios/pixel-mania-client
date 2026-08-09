extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const TouchInputGuard = preload("res://Scripts/touch_input_guard.gd")
const HOTBAR_SCENE = preload("res://Scenes/ui/hotbar/Hotbar.tscn")
const INVENTORY_SCENE = preload("res://Scenes/ui/inventory/InventoryScene.tscn")
const INVENTORY_UPGRADE_CONFIRM_SCENE = preload("res://Scenes/ui/inventory/InventoryUpgradeConfirm.tscn")
const ITEM_ACTION_POPUP_SCENE = preload("res://Scenes/ui/inventory/ItemActionPopup.tscn")
const ColourCycleModulation = preload("res://Scripts/colour_cycle_modulation.gd")
const SelectedSlotFrameClock = preload("res://Scripts/ui/selected_slot_frame_clock.gd")
const HOTBAR_SLOT_COUNT = 6
const HOTBAR_HEIGHT = 104.0
const HOTBAR_SLOT_SIZE = 96
const HOTBAR_SLOT_GAP = 12
const HOTBAR_SLOT_STEP = HOTBAR_SLOT_SIZE + HOTBAR_SLOT_GAP
const HOTBAR_FRAME_LEFT_INSET = 34
const HOTBAR_FRAME_RIGHT_INSET = 12
const HOTBAR_PAD_Y = 11
const HOTBAR_HANDLE_HEIGHT = 24
const HOTBAR_HANDLE_TOUCH_PAD_TOP = 18.0
const HOTBAR_HANDLE_TOUCH_SIDE_PAD = 20.0
const HOTBAR_INVENTORY_GAP = 0.0
const MOBILE_HUD_MIN_SCALE := 1.08
const MOBILE_HUD_MAX_SCALE := 1.18
const HOTBAR_Z_INDEX = 176
const INVENTORY_BUTTON_Z_INDEX = 178
const INVENTORY_WINDOW_Z_INDEX = 175
const INVENTORY_MODAL_Z_INDEX = 240
const ITEM_ACTION_POPUP_Z_INDEX = 300
const INVENTORY_DRAWER_BASE_WIDTH = 1100.0
const INVENTORY_DRAWER_BASE_HEIGHT = 560.0
const INVENTORY_DRAWER_EXTRA_COLUMNS = 2.0
const INVENTORY_DRAWER_EXTRA_ROWS = 1.0
const INVENTORY_OPEN_SPEED = 8.0
const INVENTORY_SETTLE_EPSILON = 0.002
const INVENTORY_RELEASE_OPEN_THRESHOLD = 0.50
const INVENTORY_RELEASE_VELOCITY_THRESHOLD = 0.72
const ITEM_HOLD_TIME = 0.45
const EQUIP_DOUBLE_TAP_TIME_MS = 350
const TOUCH_EQUIP_DOUBLE_TAP_TIME_MS = 550
const UI_STYLE_PATH = "res://Assets/ui/inventory/"
const HOTBAR_STYLE_PATH = "res://Assets/ui/hotbar/"
const ROOT_UI_PATH = "res://Assets/ui/"
const HOTBAR_MATERIAL_SLOT_TEXTURE = "material_slot.png"
const HOTBAR_CLOTHES_SLOT_TEXTURE = "clothes_slot.png"
const HOTBAR_EMPTY_SLOT_TEXTURE = "empty_slot.png"
const UI_PANEL_MARGIN = 28.0
const UI_BUTTON_MARGIN = 22.0
const UI_SLOT_MARGIN = 24.0
const UI_TAB_MARGIN = 18.0
const INVENTORY_SLOT_SIZE = 82.0
const INVENTORY_SLOT_GAP = 16.0
const INVENTORY_SLOT_STEP = INVENTORY_SLOT_SIZE + INVENTORY_SLOT_GAP
const INVENTORY_WHEEL_SCROLL_AMOUNT = INVENTORY_SLOT_STEP
const INVENTORY_STRUCTURE_CHECK_INTERVAL_MS = 250
const INVENTORY_DRAWER_WIDTH = INVENTORY_DRAWER_BASE_WIDTH + INVENTORY_SLOT_STEP * INVENTORY_DRAWER_EXTRA_COLUMNS
const INVENTORY_DRAWER_HEIGHT = INVENTORY_DRAWER_BASE_HEIGHT + INVENTORY_SLOT_STEP * INVENTORY_DRAWER_EXTRA_ROWS
const INVENTORY_SCENE_WINDOW_SIZE = Vector2(1000.0, 640.0)
const INVENTORY_SCENE_VISUAL_SIZE = Vector2(1349.0, 657.0)
const MOBILE_GUI_SCALE_SETTING := "gui/theme/default_theme_scale"
const INVENTORY_ICON_FRAME_POSITION = Vector2(10.0, 9.0)
const INVENTORY_ICON_FRAME_SIZE = Vector2(62.0, 60.0)
const INVENTORY_ICON_POSITION = Vector2(12.0, 9.0)
const INVENTORY_ICON_SIZE = Vector2(58.0, 58.0)
const INVENTORY_ICON_SHADOW_OFFSET = Vector2(4.0, 6.0)
const INVENTORY_SCROLLBAR_RESERVE = 38.0
const INVENTORY_GRID_BOTTOM_PAD = 12.0
const INVENTORY_HEADER_HEIGHT = 92.0
const INVENTORY_TOOL_ROW_HEIGHT = 42.0
const INVENTORY_NAV_HEIGHT = 44.0
const BAG_ICON_PATH = "res://Assets/ui/icons/bag.png"
const BAG_BUTTON_SIZE = Vector2(64, 64)
const HOTBAR_PUNCH_ICON_PATH = "res://Assets/ui/icons/punch.png"
const HOTBAR_WRENCH_ICON_PATH = "res://Assets/ui/icons/wrench.png"
const WORLD_LOCK_ITEM_ID = "world_lock"
const SUPER_WORLD_LOCK_ITEM_ID = "super_world_lock"
const SUPER_WORLD_LOCK_EXCHANGE_RATE = 100
const OIL_REFINERY_BATTERY_ITEM_ID = "battery"
const OIL_REFINERY_BATTERY_ITEM_CATEGORY = "material"
const SEED_BOX_PREVIEW_NODE_NAME = "SeedPreview"
const PICKUP_TARGET_INVALID_SCREEN_POSITION = Vector2(1.0e20, 1.0e20)
const GEM_COUNTER_BASE_GLOW_COLOR = Color(0.38, 0.70, 1.0, 0.06)
const GEM_COUNTER_PICKUP_GLOW_COLOR = Color(0.72, 0.96, 1.0, 0.42)
const GEM_COUNTER_FEEDBACK_MIN_INTERVAL_MS = 180
const DEBUG_INVENTORY_UI = false
# Growtopia-style inventory updates: never rebuild the full inventory for normal
# place/break/pickup changes. Dirty slots are processed in small batches so bulk
# pickups cannot spike one frame.
const INVENTORY_DIRTY_SLOT_PROCESS_BUDGET := 8
# Pickup performance fix: when the bag is closed, do not refresh the inventory window
# for dirty item changes. Only HUD/hotbar/gem UI should update while closed.
const INVENTORY_CLOSED_REFRESH_THRESHOLD := 0.05
# Bulk pickup fix: during magnet/overlap pickup storms, coalesce HUD updates and
# pickup target lookups. This prevents hundreds of item pickups from updating
# labels/hotbar/searching UI controls in the same frame.
const PICKUP_HUD_REFRESH_INTERVAL_MS := 80
const PICKUP_TARGET_CACHE_MS := 400
const PICKUP_BULK_MIN_ITEMS := 8
# During mass pickup, do not resolve exact inventory/hotbar slot targets for every
# collected object. Use stable HUD anchors and let the final HUD/slot refresh happen
# once after the batch.
const PICKUP_BULK_USE_GENERIC_TARGET := true
const PICKUP_BULK_VISUAL_LIMIT := 6
const PICKUP_BULK_QUEUE_FREE_BUDGET_PER_FRAME := 48
const INVENTORY_UPDATE_SOURCE_LOCAL := "local"
const INVENTORY_UPDATE_SOURCE_SERVER := "server"
const INVENTORY_UPDATE_SOURCE_REMOTE := "remote"
const COLOUR_CYCLE_HOTBAR_UPDATE_SECONDS := 0.066
const HOTBAR_SELECTED_FRAME_SECONDS := 0.30
const HOTBAR_SELECTED_FRAMES := [
	preload("res://Assets/ui/selected_1.png"),
	preload("res://Assets/ui/selected_2.png"),
	preload("res://Assets/ui/selected_3.png"),
]

var world = null
var ui_layer_ref = null

var hotbar_root = null
var hotbar_slots = {}
var hotbar_handle = null
var hotbar_slot_zero_last_tap_ms = 0
var inventory_button = null
var gem_panel = null
var gem_icon = null
var gem_count_label = null

var inventory_window = null
var inventory_upgrade_popup = null
var item_action_popup = null
var inventory_tab = "all"
var inventory_scroll_container = null
var inventory_grid_root = null
var inventory_tab_root = null
var inventory_window_layout_size = Vector2.ZERO
var inventory_detail_panel = null
var inventory_detail_item_type = ""
var inventory_detail_item_category = ""
var inventory_slots = {}
var inventory_tab_buttons = {}
var inventory_search_input = null
var inventory_search_text = ""
var inventory_visible_slot_keys: Array = []
var inventory_visible_slot_counts: Dictionary = {}
var inventory_slot_dirty_keys: Array = []
var inventory_slot_dirty_set: Dictionary = {}
var inventory_window_live_cache_valid = false
var inventory_window_structure_dirty = true
var inventory_last_structure_check_ms = 0
var inventory_scene_cache_signature = ""
var colour_cycle_hotbar_update_elapsed: float = 0.0
var hotbar_selected_frame_index: int = 0

var item_context_menu = null
var context_amount_input = null
var context_amount_slider = null
var context_amount_updating = false
var hold_active = false
var hold_popup_opened = false
var hold_time = 0.0
var hold_item_type = ""
var hold_item_category = ""
var hold_slot = null
var hold_source = "inventory"
var equip_last_tap_key = ""
var equip_last_tap_ms = 0
var trade_select_active = false
var trade_select_slot_index = -1
var inventory_button_icon = null
var inventory_button_icon_shadow = null
var inventory_button_tween = null
var inventory_button_hovered = false
var gem_counter_feedback_tween = null
var gem_counter_last_feedback_ms = 0
var pickup_target_screen_cache: Dictionary = {}
var inventory_hud_refresh_queued := false
var inventory_hud_refresh_force := false
var inventory_last_hud_refresh_ms := 0
var inventory_hud_refresh_needs_hotbar := false
var inventory_hud_refresh_needs_gem_counter := false
var bulk_pickup_batch_depth := 0
var bulk_pickup_changed_items: Dictionary = {}
var bulk_pickup_expected_count := 0
var bulk_pickup_visuals_used := 0
var bulk_pickup_suppress_extra_visuals := false
var gem_counter_cached_display_text := ""
var trade_select_blocker = null
var vend_select_active = false
var safe_select_active = false
var donation_box_select_active = false
var display_select_active = false
var oil_refinery_battery_select_active = false
var inventory_alive_time = 0.0
var ui_stylebox_cache = {}

var drag_handle_active = false
var drag_handle_touch_index = -1
var drag_handle_start_y = 0.0
var drag_handle_start_amount = 0.0
var drag_handle_last_y = 0.0
var drag_handle_last_time_ms = 0
var drag_handle_velocity = 0.0

var inventory_gameplay_passthrough_call = false
var inventory_gameplay_hold_active = false
var inventory_window_refresh_suspended = false
var inventory_window_refresh_pending = false

var inventory_drawer_amount = 0.0
var inventory_drawer_target = 0.0



func get_ui_texture(file_name: String):
	var path = UI_STYLE_PATH + file_name
	if ResourceLoader.exists(path):
		return load(path)
	return null


func get_hotbar_ui_texture(file_name: String):
	var path = HOTBAR_STYLE_PATH + file_name
	if ResourceLoader.exists(path):
		return load(path)
	return null


func get_hotbar_slot_frame_texture(file_name: String) -> Texture2D:
	var hotbar_texture: Texture2D = get_hotbar_ui_texture(file_name) as Texture2D
	if hotbar_texture != null:
		return hotbar_texture
	var ui_texture: Texture2D = get_ui_texture(file_name) as Texture2D
	if ui_texture != null:
		return ui_texture
	var root_path: String = ROOT_UI_PATH + file_name
	if ResourceLoader.exists(root_path):
		var root_texture: Resource = ResourceLoader.load(root_path)
		return root_texture as Texture2D
	return null


func has_inventory_ui_kit() -> bool:
	return get_ui_texture("panel_window_large_blue.png") != null and get_ui_texture("slot_normal.png") != null


func make_texture_stylebox(file_name: String, margin: float = UI_PANEL_MARGIN):
	var cache_key = file_name + ":" + str(margin)
	if ui_stylebox_cache.has(cache_key):
		return ui_stylebox_cache[cache_key]
	var texture = get_ui_texture(file_name)
	if texture == null:
		return null
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.draw_center = true
	ui_stylebox_cache[cache_key] = style
	return style


func apply_texture_panel_style(node, file_name: String, margin: float = UI_PANEL_MARGIN) -> bool:
	if node == null:
		return false
	var style = make_texture_stylebox(file_name, margin)
	if style == null:
		return false
	if node is Panel:
		node.add_theme_stylebox_override("panel", style)
		return true
	if node is ColorRect:
		node.color = Color(1.0, 1.0, 1.0, 0.0)
		return true
	return false


func apply_texture_button_files(button: Button, normal_file: String, hover_file: String, pressed_file: String, font_size: int = 14, margin: float = UI_BUTTON_MARGIN) -> bool:
	if button == null:
		return false
	var button_min_side: float = max(1.0, min(button.size.x, button.size.y))
	var safe_margin: float = min(margin, max(6.0, button_min_side * 0.35))
	var normal_style = make_texture_stylebox(normal_file, safe_margin)
	if normal_style == null:
		return false
	var hover_style = make_texture_stylebox(hover_file, safe_margin)
	if hover_style == null:
		hover_style = normal_style
	var pressed_style = make_texture_stylebox(pressed_file, safe_margin)
	if pressed_style == null:
		pressed_style = normal_style
	PixelUIStyle.apply_button_text(button, font_size)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.78, 0.92, 1.0, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	button.add_theme_constant_override("outline_size", 2)
	return true


func apply_inventory_kit_button_style(_button: Button, _selected: bool = false, _danger: bool = false, _font_size: int = 14) -> bool:
	return false


func apply_inventory_close_button_style(button: Button) -> bool:
	if button == null:
		return false
	var close_texture = get_ui_texture("close_button.png")
	if close_texture == null:
		return false
	button.text = ""
	button.icon = close_texture
	button.expand_icon = true
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return true


func add_texture_skin(parent_node, skin_name: String, file_name: String, skin_position: Vector2, skin_size: Vector2):
	if parent_node == null:
		return null
	var texture = get_ui_texture(file_name)
	if texture == null:
		return null
	var skin = parent_node.get_node_or_null(skin_name)
	if skin == null:
		skin = TextureRect.new()
		skin.name = skin_name
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent_node.add_child(skin)
	skin.texture = texture
	skin.position = skin_position
	skin.size = skin_size
	skin.stretch_mode = TextureRect.STRETCH_SCALE
	skin.visible = true
	if parent_node.has_method("move_child"):
		parent_node.move_child(skin, 0)
	return skin


func make_color_rect_transparent(node):
	if node != null and node is ColorRect:
		node.color = Color(1.0, 1.0, 1.0, 0.0)


func style_panel_child(node_name: String, texture_name: String):
	if inventory_window == null:
		return
	var node = inventory_window.get_node_or_null(node_name)
	if node == null:
		return
	make_color_rect_transparent(node)
	add_texture_skin(node, "StyleSkin", texture_name, Vector2.ZERO, node.size)


func _is_equipable_hotbar_category(category: String) -> bool:
	match category.strip_edges().to_lower():
		"back":
			return true
		"hat":
			return true
		"hair":
			return true
		"eyewear":
			return true
		"shirt":
			return true
		"pants":
			return true
		"shoes":
			return true
		"ride":
			return true
		_:
			return false


func get_slot_texture_name(rarity: String, selected: bool, item_type: String = "", category: String = "") -> String:
	if selected:
		return "slot_selected.png"
	var normalized_category := category.strip_edges().to_lower()
	if normalized_category == "material":
		return HOTBAR_MATERIAL_SLOT_TEXTURE
	if _is_equipable_hotbar_category(normalized_category):
		return HOTBAR_CLOTHES_SLOT_TEXTURE
	if normalized_category != "tool" and item_type != "":
		var item_count: int = get_item_count(str(item_type), normalized_category)
		if item_count <= 0:
			return HOTBAR_EMPTY_SLOT_TEXTURE
	match normalize_item_rarity(rarity):
		"common":    return "slot_common.png"
		"uncommon":  return "slot_uncommon.png"
		"rare":      return "slot_rare.png"
		"epic":      return "slot_epic.png"
		"legendary": return "slot_legendary.png"
		"currency":  return "slot_normal.png"
		_:           return "slot_normal.png"


func normalize_item_rarity(rarity: String) -> String:
	return rarity.strip_edges().to_lower()


func get_rarity_fill_color(rarity: String, alpha: float = 0.98) -> Color:
	match normalize_item_rarity(rarity):
		"uncommon":  return Color(0.08, 0.45, 0.22, alpha)
		"rare":      return Color(0.08, 0.28, 0.76, alpha)
		"epic":      return Color(0.36, 0.13, 0.70, alpha)
		"legendary": return Color(0.84, 0.46, 0.05, alpha)
		"currency":  return Color(0.03, 0.52, 0.62, alpha)
		_:           return Color(0.10, 0.24, 0.34, alpha)


func get_rarity_border_color(rarity: String) -> Color:
	match normalize_item_rarity(rarity):
		"uncommon":  return Color(0.34, 0.95, 0.45, 1.0)
		"rare":      return Color(0.26, 0.62, 1.0, 1.0)
		"epic":      return Color(0.80, 0.46, 1.0, 1.0)
		"legendary": return Color(1.0, 0.78, 0.18, 1.0)
		"currency":  return Color(0.26, 1.0, 1.0, 1.0)
		_:           return Color(0.48, 0.76, 0.88, 1.0)


func apply_panel_depth(node, fill: Color, border: Color, border_width: int = 3, radius: int = 8, shadow_size: int = 0):
	if node == null:
		return
	if node is Panel:
		node.add_theme_stylebox_override("panel", PixelUIStyle.style_box(fill, border, border_width, radius, shadow_size))
	elif node is ColorRect:
		node.color = fill


func clear_panel_style(node):
	if node != null and node is Panel:
		node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func set_child_visible(root_node, node_name: String, _is_visible: bool):
	if root_node == null:
		return
	var node = root_node.get_node_or_null(node_name)
	if node != null:
		node.visible = _is_visible


func hide_node_if_present(root_node, node_name: String):
	if root_node == null:
		return
	var node = root_node.get_node_or_null(node_name)
	if node != null:
		node.visible = false


func hide_inventory_legacy_decor():
	if inventory_window == null:
		return
	for node_name in [
		"Shadow", "Border", "MainPanel", "OuterHighlight", "WarmGlow",
		"HeaderGloss", "HeaderSpark", "TopLine", "HeaderAccent",
		"GridWarmWash", "GridFloorGlow", "SearchInputSkin", "WindowStyleSkin"
	]:
		hide_node_if_present(inventory_window, node_name)


func apply_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return
	if apply_inventory_kit_button_style(button, selected, danger, font_size):
		return
	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.62, 0.08, 0.15, 0.98), Color(0.18, 0.01, 0.05, 1.0), 4, 12, 8))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.88, 0.12, 0.22, 0.98), Color(1.0, 0.44, 0.44, 0.82), 4, 12, 9))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.40, 0.03, 0.09, 0.98), Color(0.12, 0.0, 0.02, 1.0), 4, 12, 5))
		return
	if selected:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.95, 0.66, 0.07, 0.98), Color(1.0, 0.90, 0.18, 0.95), 4, 10, 8))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(1.0, 0.78, 0.12, 0.98), Color(1.0, 0.96, 0.38, 1.0), 4, 10, 9))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.72, 0.36, 0.04, 0.98), Color(0.42, 0.15, 0.01, 1.0), 4, 10, 5))
		return
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.10, 0.24, 0.34, 0.58), Color(0.42, 0.78, 1.0, 0.42), 3, 10, 5))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.15, 0.34, 0.48, 0.72), Color(0.70, 0.96, 1.0, 0.76), 3, 10, 7))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.070, 0.17, 0.27, 0.82), Color(0.30, 0.66, 1.0, 0.86), 3, 10, 4))


func apply_arcade_search_style(line_edit: LineEdit):
	if line_edit == null:
		return
	PixelUIStyle.apply_input(line_edit, 18)
	var input_style: StyleBox = null
	if input_style != null:
		line_edit.add_theme_stylebox_override("normal", input_style)
		line_edit.add_theme_stylebox_override("focus", input_style)
		line_edit.add_theme_stylebox_override("read_only", input_style)
	else:
		line_edit.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.18), Color(0.30, 0.72, 1.0, 0.68), 3, 12, 4))
		line_edit.add_theme_stylebox_override("focus", PixelUIStyle.style_box(Color(0.86, 0.97, 1.0, 0.27), Color(0.86, 0.96, 1.0, 0.98), 3, 12, 7))
	line_edit.add_theme_color_override("font_color", Color(0.98, 1.0, 1.0, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.76, 0.90, 1.0, 0.74))
	line_edit.add_theme_color_override("caret_color", Color(1.0, 0.82, 0.20, 1.0))


func apply_arcade_scrollbar_style():
	if inventory_scroll_container == null:
		return
	var scrollbar = inventory_scroll_container.get_v_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size = Vector2(16, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.08, 0.18, 0.26, 0.32), Color(0.24, 0.52, 0.74, 0.42), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.30, 0.68, 0.96, 0.86), Color(0.78, 0.96, 1.0, 0.68), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.46, 0.82, 1.0, 0.98), Color(0.90, 1.0, 1.0, 0.86), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.98), Color(1.0, 0.92, 0.40, 0.90), 2, 8, 6))


func format_stack_count(count: int) -> String:
	if count >= 1000000:
		return str(int(floor(float(count) / 1000000.0))) + "m"
	if count >= 10000:
		return str(int(floor(float(count) / 1000.0))) + "k"
	return str(count)


func format_inventory_number(value: int) -> String:
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


func get_inventory_viewport_size() -> Vector2:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


func get_inventory_margin_x(screen_size: Vector2) -> float:
	var margin_source_width = min(screen_size.x, INVENTORY_DRAWER_BASE_WIDTH)
	return clamp(margin_source_width * 0.035, 26.0, 76.0)


func get_inventory_window_size_for_viewport(screen_size: Vector2) -> Vector2:
	if is_inventory_scene_window():
		return INVENTORY_SCENE_WINDOW_SIZE * get_inventory_scene_window_scale_for_viewport(screen_size)
	var available_width = max(420.0, screen_size.x - 32.0)
	var available_height = max(360.0, screen_size.y - get_hotbar_visual_height(screen_size) - 32.0)
	return Vector2(
		min(INVENTORY_DRAWER_WIDTH, available_width),
		min(INVENTORY_DRAWER_HEIGHT, available_height)
	)


func get_inventory_scene_window_scale_for_viewport(screen_size: Vector2) -> float:
	var available_width: float = maxf(320.0, screen_size.x - 24.0)
	var available_height: float = maxf(240.0, screen_size.y - get_hotbar_visual_height(screen_size) - HOTBAR_INVENTORY_GAP - 24.0)
	var target_scale: float = get_mobile_gui_target_scale()
	var fit_scale: float = minf(
		available_width / INVENTORY_SCENE_VISUAL_SIZE.x,
		available_height / INVENTORY_SCENE_VISUAL_SIZE.y
	)
	return clampf(minf(target_scale, fit_scale), 0.28, target_scale)


func get_mobile_gui_target_scale() -> float:
	if not is_mobile_touch_platform():
		return 1.0
	var configured_scale := float(ProjectSettings.get_setting_with_override(MOBILE_GUI_SCALE_SETTING))
	return clampf(configured_scale, 1.0, 1.5)


func is_mobile_touch_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func should_ignore_mobile_mouse_event(event: InputEvent) -> bool:
	if TouchInputGuard.is_emulated_mouse_from_touch(event):
		return true
	return is_mobile_touch_platform() and event is InputEventMouseButton


func get_mobile_hud_scale(screen_size: Vector2 = Vector2.ZERO) -> float:
	if not is_mobile_touch_platform():
		return 1.0
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		screen_size = get_inventory_viewport_size()
	var raw_scale: float = minf(screen_size.x / 1280.0, screen_size.y / 720.0)
	return clampf(raw_scale, MOBILE_HUD_MIN_SCALE, MOBILE_HUD_MAX_SCALE)


func get_hotbar_base_visual_height() -> float:
	return HOTBAR_SLOT_SIZE + HOTBAR_PAD_Y * 2 + HOTBAR_HANDLE_TOUCH_PAD_TOP + HOTBAR_HANDLE_HEIGHT + 2


func get_hotbar_visual_height(screen_size: Vector2 = Vector2.ZERO) -> float:
	return get_hotbar_base_visual_height() * get_mobile_hud_scale(screen_size)


func get_hotbar_closed_y(screen_size: Vector2) -> float:
	return max(0.0, screen_size.y - get_hotbar_visual_height(screen_size))


func get_hotbar_open_y(screen_size: Vector2) -> float:
	var window_size = get_inventory_window_size_for_viewport(screen_size)
	var unit_height = get_hotbar_visual_height(screen_size) + HOTBAR_INVENTORY_GAP + window_size.y
	return clamp(screen_size.y - unit_height, 0.0, get_hotbar_closed_y(screen_size))


func get_inventory_drawer_drag_height() -> float:
	var screen_size = get_inventory_viewport_size()
	return max(120.0, get_hotbar_closed_y(screen_size) - get_hotbar_open_y(screen_size))


func refresh_inventory_window_for_viewport():
	if inventory_window == null:
		return

	var screen_size = get_inventory_viewport_size()
	if is_inventory_scene_window():
		inventory_window_layout_size = screen_size
		update_inventory_window_position()
		return

	if inventory_window_layout_size == Vector2.ZERO:
		inventory_window_layout_size = screen_size
		return

	if inventory_window_layout_size.distance_to(screen_size) <= 2.0:
		return

	var was_visible = inventory_window.visible
	setup_inventory_window()
	inventory_window.visible = was_visible
	mark_inventory_window_structure_dirty()


func apply_inventory_style():
	if inventory_window == null:
		return
	make_color_rect_transparent(inventory_window)
	add_texture_skin(inventory_window, "WindowStyleSkin", "panel_main.png", Vector2.ZERO, inventory_window.size)
	style_panel_child("TopBar", "panel_inner.png")
	style_panel_child("SelectedPanel", "panel_inner.png")
	style_panel_child("GridPanel", "panel_inner.png")
	style_panel_child("SidePanel", "panel_inner.png")
	var border = inventory_window.get_node_or_null("Border")
	apply_panel_depth(border, PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 4, 14, 10)
	var shadow = inventory_window.get_node_or_null("Shadow")
	apply_panel_depth(shadow, Color(0.0, 0.0, 0.0, 0.30), Color(0.0, 0.0, 0.0, 0.0), 0, 10, 0)
	var main_panel = inventory_window.get_node_or_null("MainPanel")
	apply_panel_depth(main_panel, Color(0.030, 0.105, 0.155, 0.86), Color(0.08, 0.22, 0.30, 0.65), 2, 7, 0)
	var grid_border = inventory_window.get_node_or_null("GridBorder")
	apply_panel_depth(grid_border, PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 14, 5)
	if inventory_search_input != null:
		add_texture_skin(inventory_window, "SearchInputSkin", "input_box.png", inventory_search_input.position - Vector2(4, 4), inventory_search_input.size + Vector2(8, 8))
	var close_button = inventory_window.get_node_or_null("CloseButton")
	if close_button != null and close_button is Button:
		apply_inventory_close_button_style(close_button)


func apply_shared_inventory_style():
	if inventory_window == null:
		return
	if inventory_window is ColorRect:
		inventory_window.color = Color(0.000, 0.004, 0.010, 0.00)

	var far_shadow = inventory_window.get_node_or_null("FarShadow")
	if far_shadow != null:
		far_shadow.visible = true
	apply_panel_depth(far_shadow, Color(0.0, 0.0, 0.0, 0.28), Color(0.0, 0.0, 0.0, 0.0), 0, 20, 0)
	var panel_back = inventory_window.get_node_or_null("PanelBack")
	if panel_back == null:
		panel_back = Panel.new()
		panel_back.name = "PanelBack"
		panel_back.position = Vector2.ZERO
		panel_back.size = inventory_window.size
		panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_window.add_child(panel_back)
		inventory_window.move_child(panel_back, 0)
	if panel_back is Panel:
		panel_back.size = inventory_window.size
		panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.050, 0.120, 0.175, 0.46),
			Color(0.18, 0.46, 0.76, 0.72),
			4, 14, 11
		))
	elif panel_back is ColorRect:
		panel_back.size = inventory_window.size
		panel_back.color = Color(0.050, 0.120, 0.175, 0.46)
	var shadow = inventory_window.get_node_or_null("Shadow")
	if shadow != null:
		shadow.visible = true
	apply_panel_depth(shadow, Color(0.0, 0.0, 0.0, 0.38), Color(0.0, 0.0, 0.0, 0.0), 0, 16, 0)
	var border = inventory_window.get_node_or_null("Border")
	if border != null:
		border.visible = true
	apply_panel_depth(border, Color(0.070, 0.150, 0.235, 0.30), Color(0.36, 0.78, 1.0, 0.58), 3, 14, 7)
	var main_panel = inventory_window.get_node_or_null("MainPanel")
	if main_panel != null:
		main_panel.visible = true
	apply_panel_depth(main_panel, Color(0.070, 0.150, 0.205, 0.24), Color(0.46, 0.82, 1.0, 0.22), 1, 11, 0)
	var outer_highlight = inventory_window.get_node_or_null("OuterHighlight")
	if outer_highlight != null:
		outer_highlight.visible = true
	apply_panel_depth(outer_highlight, Color(0.0, 0.0, 0.0, 0.0), Color(0.70, 0.96, 1.0, 0.32), 1, 12, 0)
	var top_bar = inventory_window.get_node_or_null("TopBar")
	if top_bar is Panel:
		top_bar.visible = true
		top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.070, 0.150, 0.235, 0.62),
			Color(0.030, 0.100, 0.170, 0.66),
			3, 10, 5
		))
	var selected_panel = inventory_window.get_node_or_null("SelectedPanel")
	apply_panel_depth(selected_panel, Color(0.82, 0.94, 1.0, 0.11), Color(0.36, 0.74, 1.0, 0.50), 2, 10, 4)
	var category_panel = inventory_window.get_node_or_null("CategoryPanel")
	apply_panel_depth(category_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.28, 0.52, 1.0, 0.00), 0, 10, 0)
	var category_nav_back = inventory_window.get_node_or_null("CategoryNavBack")
	if category_nav_back != null:
		if category_nav_back is Panel:
			category_nav_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				Color(0.82, 0.94, 1.0, 0.075),
				Color(0.42, 0.78, 1.0, 0.28),
				1, 9, 0
			))
		elif category_nav_back is ColorRect:
			category_nav_back.color = Color(0.82, 0.94, 1.0, 0.075)
	var grid_border = inventory_window.get_node_or_null("GridBorder")
	apply_panel_depth(grid_border, Color(0.060, 0.135, 0.200, 0.36), Color(0.34, 0.72, 1.0, 0.62), 3, 13, 6)
	var grid_panel = inventory_window.get_node_or_null("GridPanel")
	apply_panel_depth(grid_panel, Color(0.80, 0.94, 1.0, 0.10), Color(0.64, 0.92, 1.0, 0.20), 1, 11, 1)
	var side_panel = inventory_window.get_node_or_null("SidePanel")
	apply_panel_depth(side_panel, Color(0.060, 0.135, 0.200, 0.42), Color(0.40, 0.78, 1.0, 0.54), 3, 13, 5)
	var detail_panel = inventory_window.get_node_or_null("DetailPanel")
	apply_panel_depth(detail_panel, Color(0.060, 0.135, 0.200, 0.42), Color(0.40, 0.78, 1.0, 0.54), 3, 13, 5)
	var header_gem_chip = inventory_window.get_node_or_null("HeaderGemChip")
	apply_panel_depth(header_gem_chip, Color(0.82, 0.94, 1.0, 0.14), Color(0.30, 0.72, 1.0, 0.70), 3, 14, 7)
	var warm_glow = inventory_window.get_node_or_null("WarmGlow")
	if warm_glow != null and warm_glow is ColorRect:
		warm_glow.visible = true
		warm_glow.color = Color(0.54, 0.86, 1.0, 0.045)
	var header_gloss = inventory_window.get_node_or_null("HeaderGloss")
	if header_gloss != null and header_gloss is ColorRect:
		header_gloss.visible = true
		header_gloss.color = Color(0.80, 0.95, 1.0, 0.10)
	var header_spark = inventory_window.get_node_or_null("HeaderSpark")
	if header_spark != null and header_spark is ColorRect:
		header_spark.visible = true
		header_spark.color = Color(0.86, 0.98, 1.0, 0.34)
	var grid_warm_wash = inventory_window.get_node_or_null("GridWarmWash")
	if grid_warm_wash != null and grid_warm_wash is ColorRect:
		grid_warm_wash.visible = true
		grid_warm_wash.color = Color(0.82, 0.94, 1.0, 0.040)
	var grid_floor_glow = inventory_window.get_node_or_null("GridFloorGlow")
	if grid_floor_glow != null and grid_floor_glow is ColorRect:
		grid_floor_glow.visible = true
		grid_floor_glow.color = Color(0.54, 0.86, 1.0, 0.050)
	var title = inventory_window.get_node_or_null("Title")
	if title != null and title is Label:
		PixelUIStyle.apply_label_shadow(title, 48 if inventory_window.size.x >= 1000.0 else 40)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var selected_label = inventory_window.get_node_or_null("SelectedLabel")
	if selected_label != null and selected_label is Label:
		PixelUIStyle.apply_small_label(selected_label, 12)
		selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hint = inventory_window.get_node_or_null("Hint")
	if hint != null and hint is Label:
		PixelUIStyle.apply_small_label(hint, 11)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if inventory_search_input != null:
		apply_arcade_search_style(inventory_search_input)
	var close_button = inventory_window.get_node_or_null("CloseButton")
	if close_button != null and close_button is Button:
		close_button.size = Vector2(48, 48)
		if not apply_inventory_close_button_style(close_button):
			apply_arcade_button_style(close_button, false, true, 18)
			close_button.text = "X"
	var top_line = inventory_window.get_node_or_null("TopLine")
	if top_line == null and top_bar != null:
		top_line = ColorRect.new()
		top_line.name = "TopLine"
		top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_window.add_child(top_line)
		inventory_window.move_child(top_line, min(inventory_window.get_child_count() - 1, 2))
		top_line.position = Vector2(top_bar.position.x, top_bar.position.y + top_bar.size.y - 3.0)
		top_line.size = Vector2(top_bar.size.x, 3.0)
	if top_line != null and top_line is ColorRect:
		top_line.visible = true
		top_line.color = Color(0.42, 0.72, 1.0, 0.55)
	var header_accent = inventory_window.get_node_or_null("HeaderAccent")
	if header_accent != null and header_accent is ColorRect:
		header_accent.visible = true
		header_accent.color = Color(0.70, 0.96, 1.0, 0.24)
	apply_arcade_scrollbar_style()
	apply_inventory_tab_shared_style()


func apply_inventory_kit_window_style():
	if inventory_window == null:
		return
	hide_inventory_legacy_decor()
	apply_texture_panel_style(inventory_window.get_node_or_null("PanelBack"), "panel_window_large_blue.png", 32.0)
	clear_panel_style(inventory_window.get_node_or_null("Border"))
	clear_panel_style(inventory_window.get_node_or_null("OuterHighlight"))
	clear_panel_style(inventory_window.get_node_or_null("MainPanel"))
	apply_texture_panel_style(inventory_window.get_node_or_null("TopBar"), "panel_header_bar.png", 26.0)
	apply_texture_panel_style(inventory_window.get_node_or_null("SelectedPanel"), "input_box.png", 20.0)
	clear_panel_style(inventory_window.get_node_or_null("CategoryNavBack"))
	clear_panel_style(inventory_window.get_node_or_null("CategoryPanel"))
	apply_texture_panel_style(inventory_window.get_node_or_null("GridBorder"), "panel_inventory_grid.png", 28.0)
	clear_panel_style(inventory_window.get_node_or_null("GridPanel"))
	apply_texture_panel_style(inventory_window.get_node_or_null("SidePanel"), "panel_sidebar.png", 28.0)
	apply_texture_panel_style(inventory_window.get_node_or_null("DetailPanel"), "panel_sidebar.png", 28.0)
	apply_texture_panel_style(inventory_window.get_node_or_null("HeaderGemChip"), "input_box.png", 20.0)
	if inventory_search_input != null:
		apply_arcade_search_style(inventory_search_input)
	var close_button = inventory_window.get_node_or_null("CloseButton")
	if close_button != null and close_button is Button:
		apply_inventory_close_button_style(close_button)


func apply_inventory_tab_shared_style():
	for tab_name in inventory_tab_buttons.keys():
		var tab = inventory_tab_buttons[tab_name]
		if tab == null:
			continue
		var is_selected = tab_name == inventory_tab
		if tab is Button:
			apply_arcade_button_style(tab, is_selected, false, 13)
		elif tab is ColorRect:
			if is_selected:
				tab.color = Color(1.0, 0.88, 0.18, 0.98)
			else:
				tab.color = Color(0.08, 0.26, 0.55, 0.92)
		var label = tab.get_node_or_null("Label")
		if label != null and label is Label:
			if is_selected:
				PixelUIStyle.apply_label_shadow(label, 13, Color(1.0, 1.0, 1.0, 1.0))
			else:
				PixelUIStyle.apply_small_label(label, 13)


func apply_gem_counter_shared_style():
	if gem_panel == null:
		return
	var back = gem_panel.get_node_or_null("GemPanelBack")
	if back == null:
		back = Panel.new()
		back.name = "GemPanelBack"
		back.position = Vector2.ZERO
		back.size = gem_panel.size
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem_panel.add_child(back)
		gem_panel.move_child(back, 0)
	if back is Panel:
		back.size = gem_panel.size
		back.add_theme_stylebox_override(
			"panel",
			PixelUIStyle.style_box(
				Color(0.035, 0.090, 0.165, 0.98),
				Color(0.15, 0.28, 0.50, 0.82),
				2, 12, 10
			)
		)
	var glow = gem_panel.get_node_or_null("GemPanelGlow")
	if glow == null:
		glow = ColorRect.new()
		glow.name = "GemPanelGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem_panel.add_child(glow)
		gem_panel.move_child(glow, 1)
	glow.position = Vector2(2, 2)
	glow.size = Vector2(max(0.0, gem_panel.size.x - 4), max(0.0, gem_panel.size.y - 4))
	glow.color = GEM_COUNTER_BASE_GLOW_COLOR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gem_count_label != null:
		PixelUIStyle.apply_label_shadow(gem_count_label, 18)


func apply_context_menu_shared_style():
	if item_context_menu == null:
		return
	if item_context_menu is ColorRect:
		item_context_menu.color = PixelUIStyle.GLASS_PANEL_STRONG
	var amount_label = item_context_menu.get_node_or_null("AmountLabel")
	if amount_label != null and amount_label is Label:
		PixelUIStyle.apply_small_label(amount_label, 13)
	if context_amount_input != null:
		PixelUIStyle.apply_input(context_amount_input, 16)
	for child in item_context_menu.get_children():
		if child is Button:
			var child_name = str(child.name).to_lower()
			if child_name.find("trash") != -1 or child_name.find("trade_cancel") != -1:
				apply_arcade_button_style(child, false, true, 14)
			elif child_name.find("trade_add") != -1:
				apply_arcade_button_style(child, true, false, 14)
			else:
				apply_arcade_button_style(child, false, false, 14)


func setup(world_node, ui_node):
	world = world_node
	ui_layer_ref = ui_node
	setup_hotbar()
	setup_inventory_button()
	setup_gem_counter()
	setup_inventory_window()
	_ensure_item_action_popup()
	update_all_ui()


func get_hud_layer() -> Node:
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			return hud_layer

	return ui_layer_ref


func _process(delta):
	if world == null:
		return
	refresh_inventory_window_for_viewport()
	if not drag_handle_active:
		var drawer_ease = clamp(delta * INVENTORY_OPEN_SPEED, 0.0, 1.0)
		inventory_drawer_amount = lerp(inventory_drawer_amount, inventory_drawer_target, drawer_ease)
		if abs(inventory_drawer_amount - inventory_drawer_target) <= INVENTORY_SETTLE_EPSILON:
			inventory_drawer_amount = inventory_drawer_target
	update_hold_context_menu(delta)
	update_hotbar_position()
	update_inventory_button_position()
	update_gem_counter_position()
	update_inventory_window_position()
	process_dirty_inventory_slots()
	process_queued_inventory_hud_refresh()
	update_hotbar_colour_cycle_icons_throttled(delta)
	update_hotbar_selected_frame_animation(delta)
	update_inventory_ambient(delta)


func update_all_ui():
	# Lightweight HUD refresh for gameplay actions.
	# IMPORTANT: do not call refresh_inventory_window_live() here for every pickup/place/break.
	# That function can walk all visible slots or rebuild structure. Normal gameplay should
	# only mark changed item slots dirty, then process_dirty_inventory_slots() updates them.
	if is_inventory_window_refresh_active():
		if inventory_slot_dirty_keys.is_empty():
			update_inventory_window_chrome()
		else:
			process_dirty_inventory_slots()
	else:
		# The bag is closed. Keep data dirty for the next open, but do not refresh/rebuild UI now.
		if not inventory_slot_dirty_keys.is_empty():
			mark_inventory_window_structure_dirty()
	request_inventory_hud_refresh()


func is_inventory_open() -> bool:
	if inventory_gameplay_passthrough_call:
		return false
	if is_inventory_scene_window():
		return inventory_drawer_amount > 0.05 or inventory_drawer_target > 0.05 or inventory_window.visible
	return inventory_drawer_amount > 0.05 or inventory_drawer_target > 0.05


func is_inventory_window_refresh_active() -> bool:
	# This intentionally ignores inventory_window.visible. The scene window can stay
	# visible during drawer animation/closing, but while the drawer is closed we should
	# not rebuild or refresh inventory contents during pickups.
	return inventory_drawer_amount > INVENTORY_CLOSED_REFRESH_THRESHOLD or inventory_drawer_target > INVENTORY_CLOSED_REFRESH_THRESHOLD

func request_inventory_hud_refresh(force: bool = false, refresh_hotbar: bool = true, refresh_gem_counter: bool = true) -> void:
	inventory_hud_refresh_queued = true
	if force:
		inventory_hud_refresh_force = true
	inventory_hud_refresh_needs_hotbar = inventory_hud_refresh_needs_hotbar or refresh_hotbar
	inventory_hud_refresh_needs_gem_counter = inventory_hud_refresh_needs_gem_counter or refresh_gem_counter


func process_queued_inventory_hud_refresh() -> void:
	if not inventory_hud_refresh_queued:
		return
	var now_ms: int = Time.get_ticks_msec()
	if not inventory_hud_refresh_force and inventory_last_hud_refresh_ms > 0 and now_ms - inventory_last_hud_refresh_ms < PICKUP_HUD_REFRESH_INTERVAL_MS:
		return
	inventory_hud_refresh_queued = false
	inventory_hud_refresh_force = false
	inventory_last_hud_refresh_ms = now_ms
	if inventory_hud_refresh_needs_hotbar:
		refresh_hotbar_live()
	inventory_hud_refresh_needs_hotbar = false
	if inventory_hud_refresh_needs_gem_counter:
		update_gem_counter()
	inventory_hud_refresh_needs_gem_counter = false


func is_hotbar_item_changed(item_type: String, category: String) -> bool:
	if world == null:
		return false
	var hotbar_slot_count = min(world.hotbar_items.size(), world.hotbar_item_categories.size())
	for i in range(hotbar_slot_count):
		if str(world.hotbar_items[i]) == item_type and str(world.hotbar_item_categories[i]) == category:
			return true
	return false


func begin_bulk_pickup_batch(expected_count: int = 0, suppress_extra_visuals: bool = true) -> void:
	bulk_pickup_batch_depth += 1
	bulk_pickup_expected_count += max(0, expected_count)
	bulk_pickup_suppress_extra_visuals = bulk_pickup_suppress_extra_visuals or suppress_extra_visuals or expected_count >= PICKUP_BULK_MIN_ITEMS
	if bulk_pickup_batch_depth == 1:
		bulk_pickup_visuals_used = 0


func end_bulk_pickup_batch() -> void:
	bulk_pickup_batch_depth = max(0, bulk_pickup_batch_depth - 1)
	if bulk_pickup_batch_depth > 0:
		return
	if bulk_pickup_changed_items.is_empty():
		bulk_pickup_expected_count = 0
		bulk_pickup_visuals_used = 0
		bulk_pickup_suppress_extra_visuals = false
		request_inventory_hud_refresh()
		return
	var changed_items: Array = []
	for change in bulk_pickup_changed_items.values():
		changed_items.append(change)
	bulk_pickup_changed_items.clear()
	bulk_pickup_expected_count = 0
	bulk_pickup_visuals_used = 0
	bulk_pickup_suppress_extra_visuals = false
	notify_inventory_items_changed(changed_items, INVENTORY_UPDATE_SOURCE_LOCAL)
	request_inventory_hud_refresh(true)


func is_bulk_pickup_batch_active() -> bool:
	return bulk_pickup_batch_depth > 0 or bulk_pickup_expected_count >= PICKUP_BULK_MIN_ITEMS


func should_spawn_pickup_visual(item_type: String = "", category: String = "") -> bool:
	if not is_bulk_pickup_batch_active():
		return true
	if not bulk_pickup_suppress_extra_visuals:
		return true
	if is_gem_pickup_target(item_type, category):
		# Gem feedback is already throttled by GEM_COUNTER_FEEDBACK_MIN_INTERVAL_MS.
		return true
	if bulk_pickup_visuals_used >= PICKUP_BULK_VISUAL_LIMIT:
		return false
	bulk_pickup_visuals_used += 1
	return true


func notify_bulk_pickup_item_changed(item_type: String, category: String, source: String = INVENTORY_UPDATE_SOURCE_LOCAL) -> void:
	if item_type == "" or category == "" or category == "empty":
		return
	if not should_inventory_source_update_local_ui(source):
		return
	var slot_key: String = get_inventory_slot_key(item_type, category)
	if bulk_pickup_batch_depth > 0:
		bulk_pickup_changed_items[slot_key] = {"item_type": item_type, "category": category}
		return
	notify_inventory_item_changed(item_type, category, source)


func should_inventory_source_update_local_ui(source: String = INVENTORY_UPDATE_SOURCE_LOCAL) -> bool:
	var clean_source: String = str(source).strip_edges().to_lower()
	if clean_source == "":
		clean_source = INVENTORY_UPDATE_SOURCE_LOCAL
	# Remote players placing/breaking/picking up in the same world should update world
	# visuals/drops only. They must never refresh this client's inventory/hotbar UI.
	if clean_source == INVENTORY_UPDATE_SOURCE_REMOTE or clean_source == "remote_player" or clean_source == "other_player" or clean_source == "network_remote":
		return false
	return true



func is_inventory_search_focused() -> bool:
	if inventory_search_input == null:
		return false
	return inventory_search_input.has_focus()


func get_inventory_viewport_safe():
	var viewport = get_viewport()
	if viewport == null and world != null and world.has_method("get_viewport"):
		viewport = world.get_viewport()
	return viewport


func mark_inventory_input_as_handled() -> void:
	var viewport = get_inventory_viewport_safe()
	if viewport == null:
		return
	viewport.set_input_as_handled()


func get_inventory_mouse_position_safe() -> Vector2:
	var viewport = get_inventory_viewport_safe()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()


func _input(event):
	if TouchInputGuard.is_emulated_mouse_from_touch(event):
		return
	if is_item_action_popup_event(event):
		return
	if handle_active_drawer_drag_input(event):
		return
	if begin_handle_drag_input(event):
		return
	handle_inventory_gameplay_passthrough(event)


func handle_active_drawer_drag_input(event: InputEvent) -> bool:
	if not drag_handle_active:
		return false

	if event is InputEventScreenDrag and event.index == drag_handle_touch_index:
		update_drawer_drag(event.position.y)
		mark_inventory_input_as_handled()
		return true

	if event is InputEventScreenTouch and event.index == drag_handle_touch_index:
		if not event.pressed:
			finish_handle_drag()
		mark_inventory_input_as_handled()
		return true

	if drag_handle_touch_index == -1:
		if event is InputEventMouseMotion:
			update_drawer_drag(get_inventory_mouse_position_safe().y)
			mark_inventory_input_as_handled()
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				finish_handle_drag()
			mark_inventory_input_as_handled()
			return true

	return false


func begin_handle_drag_input(event: InputEvent) -> bool:
	if hotbar_handle == null or not (hotbar_handle is Control):
		return false

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return false
		if not control_contains_point(hotbar_handle, event.position):
			return false
		begin_handle_drag(event.position.y)
		mark_inventory_input_as_handled()
		return true

	if event is InputEventScreenTouch:
		if not event.pressed:
			return false
		if not control_contains_point(hotbar_handle, event.position):
			return false
		begin_handle_drag(event.position.y, event.index)
		mark_inventory_input_as_handled()
		return true

	return false


func handle_inventory_gameplay_passthrough(event):
	if world == null:
		return
	if is_item_selection_mode_active():
		return
	if is_other_ui_blocking_inventory_passthrough():
		return
	if inventory_search_input != null and inventory_search_input.has_focus():
		return
	if item_context_menu != null and item_context_menu.visible:
		return
	if inventory_drawer_amount <= 0.05 and inventory_drawer_target <= 0.05:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not event.pressed:
			stop_inventory_gameplay_hold()
			return
		if is_gameplay_ui_at_point(event.position):
			return
		if start_inventory_gameplay_hold(-1):
			use_selected_item_passthrough()
			mark_inventory_input_as_handled()
	elif event is InputEventScreenTouch:
		if not event.pressed:
			stop_inventory_gameplay_hold(event.index)
			return
		if is_gameplay_ui_at_point(event.position):
			return
		if world.has_method("set_mobile_pointer_screen_position"):
			world.set_mobile_pointer_screen_position(event.position)
		if start_inventory_gameplay_hold(event.index):
			use_selected_item_passthrough()
			mark_inventory_input_as_handled()
	elif event is InputEventScreenDrag:
		if is_gameplay_ui_at_point(event.position):
			stop_inventory_gameplay_hold(event.index)
			return
		if world != null and world.has_method("set_mobile_pointer_screen_position"):
			world.set_mobile_pointer_screen_position(event.position)


func is_other_ui_blocking_inventory_passthrough() -> bool:
	if world == null:
		return true
	if not world.in_world:
		return true
	if world.is_chat_input_focused():
		return true
	if world.has_method("is_any_text_input_focused") and world.is_any_text_input_focused():
		return true
	if world.is_player_menu_open():
		return true
	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return true
	if world.has_method("is_notification_panel_open") and world.is_notification_panel_open():
		return true
	if world.is_world_menu_open():
		return true
	if world.is_crafting_open():
		return true
	if world.is_furnace_open():
		return true
	if world.is_sign_open():
		return true
	if world.is_shop_open():
		return true
	if world.is_world_lock_ui_open():
		return true
	if world.has_method("is_trade_open") and world.is_trade_open():
		return true
	if world.has_method("is_vending_open") and world.is_vending_open():
		return true
	if world.has_method("is_safe_open") and world.is_safe_open():
		return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return true
	if world.has_method("is_developer_panel_open") and world.is_developer_panel_open():
		return true
	return false


func use_selected_item_passthrough():
	if world == null or not world.has_method("use_selected_item_at_mouse"):
		return
	inventory_gameplay_passthrough_call = true
	world.use_selected_item_at_mouse()
	inventory_gameplay_passthrough_call = false
	refresh_hotbar_live()
	update_gem_counter()
	request_inventory_hud_refresh()


func start_inventory_gameplay_hold(touch_index: int = -1) -> bool:
	if world == null:
		return false
	if world.input_manager != null and world.input_manager.has_method("start_inventory_gameplay_hold"):
		var started: bool = bool(world.input_manager.start_inventory_gameplay_hold(touch_index))
		if started:
			notify_inventory_gameplay_hold_started()
		return started
	return false


func stop_inventory_gameplay_hold(touch_index: int = -1) -> void:
	if world == null:
		return
	if world.input_manager != null and world.input_manager.has_method("stop_inventory_gameplay_hold"):
		world.input_manager.stop_inventory_gameplay_hold(touch_index)
	else:
		notify_inventory_gameplay_hold_stopped()


func notify_inventory_gameplay_hold_started() -> void:
	inventory_gameplay_hold_active = true
	set_inventory_window_refresh_suspended(true)


func notify_inventory_gameplay_hold_stopped() -> void:
	if not inventory_gameplay_hold_active and not inventory_window_refresh_suspended:
		return
	inventory_gameplay_hold_active = false
	set_inventory_window_refresh_suspended(false)
	refresh_hotbar_live()
	update_gem_counter()


func set_inventory_window_refresh_suspended(suspended: bool) -> void:
	inventory_window_refresh_suspended = suspended
	if suspended:
		return
	if inventory_window_refresh_pending:
		inventory_window_refresh_pending = false
		refresh_inventory_window_live()


func control_contains_point(control, point: Vector2) -> bool:
	if control == null or not (control is Control):
		return false
	if not control.visible:
		return false
	return control.get_global_rect().has_point(point)


func is_item_action_popup_open() -> bool:
	if item_action_popup == null or not is_instance_valid(item_action_popup):
		return false
	if item_action_popup.has_method("is_open"):
		return bool(item_action_popup.is_open())
	return item_action_popup is Control and (item_action_popup as Control).visible


func is_item_action_popup_at_point(point: Vector2) -> bool:
	if item_action_popup == null or not is_instance_valid(item_action_popup):
		return false
	if item_action_popup.has_method("owns_pointer_position"):
		return bool(item_action_popup.owns_pointer_position(point))
	return control_contains_point(item_action_popup, point)


func is_item_action_popup_event(event: InputEvent) -> bool:
	if item_action_popup == null or not is_instance_valid(item_action_popup):
		return false
	if item_action_popup.has_method("owns_pointer_event"):
		return bool(item_action_popup.owns_pointer_event(event))
	return false


func is_chat_ui_at_point(point: Vector2) -> bool:
	if world == null or not ("chat_ui" in world) or world.chat_ui == null:
		return false
	if world.chat_ui.has_method("is_chat_ui_at_point"):
		return bool(world.chat_ui.is_chat_ui_at_point(point))
	return false


func is_gameplay_ui_at_point(point: Vector2) -> bool:
	if world != null and world.has_method("is_gameplay_ui_at_point"):
		return bool(world.is_gameplay_ui_at_point(point))
	if is_chat_ui_at_point(point):
		return true
	return is_inventory_control_at_point(point)


func is_inventory_ui_at_point(point: Vector2) -> bool:
	if is_item_action_popup_at_point(point):
		return true
	if not is_inventory_open():
		return false
	if is_inventory_control_at_point(point):
		return true
	if item_context_menu != null and item_context_menu.visible and control_contains_point(item_context_menu, point):
		return true
	return false


func scroll_inventory_window_wheel(direction: int):
	if inventory_scroll_container == null:
		return
	var next_scroll = int(inventory_scroll_container.scroll_vertical) + direction * int(round(INVENTORY_WHEEL_SCROLL_AMOUNT))
	var scrollbar = inventory_scroll_container.get_v_scroll_bar()
	if scrollbar != null:
		var max_scroll = max(0, int(round(scrollbar.max_value - scrollbar.page)))
		next_scroll = clamp(next_scroll, 0, max_scroll)
	else:
		next_scroll = max(0, next_scroll)
	inventory_scroll_container.scroll_vertical = next_scroll


func handle_inventory_wheel(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	if not event.pressed:
		return false
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	if not is_inventory_scroll_area_at_point(event.position):
		return false

	var direction = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	scroll_inventory_window_wheel(direction)
	mark_inventory_input_as_handled()
	return true


func is_inventory_scene_control_at_point(point: Vector2) -> bool:
	if not is_inventory_scene_window():
		return false
	if inventory_window.has_method("is_interactive_control_at_point"):
		return bool(inventory_window.is_interactive_control_at_point(point))
	return false


func is_inventory_scroll_area_at_point(point: Vector2) -> bool:
	if is_inventory_scene_window() and inventory_window.has_method("is_inventory_scroll_area_at_point"):
		return bool(inventory_window.is_inventory_scroll_area_at_point(point))
	if inventory_scroll_container != null and control_contains_point(inventory_scroll_container, point):
		return true
	return false


func is_inventory_scene_node_at_point(node_path: String, point: Vector2) -> bool:
	if inventory_window == null:
		return false
	var control: Control = inventory_window.get_node_or_null(node_path) as Control
	return control_contains_point(control, point)


func is_inventory_control_at_point(point: Vector2) -> bool:
	if is_item_action_popup_at_point(point):
		return true
	if control_contains_point(inventory_search_input, point):
		return true
	if control_contains_point(inventory_button, point):
		return true
	if control_contains_point(hotbar_handle, point):
		return true
	for slot_index in hotbar_slots.keys():
		if control_contains_point(hotbar_slots[slot_index], point):
			return true
	if is_inventory_scene_control_at_point(point):
		return true
	if is_inventory_scroll_area_at_point(point):
		return true
	if inventory_window != null:
		for node_path in [
			"CloseButton",
			"DetailSelectButton",
			"DetailDropButton",
			"DetailInfoButton",
			"DetailTrashButton",
			"Window/CloseButton",
			"Window/SearchInput",
			"Window/DropAmountInput",
			"Window/DropAmountSlider",
			"Window/InventoryScrollSlider",
			"Window/UseButton",
			"Window/DropButton",
			"Window/InfoButton",
			"Window/TrashButton"
		]:
			if is_inventory_scene_node_at_point(node_path, point):
				return true
	for tab_name in inventory_tab_buttons.keys():
		if control_contains_point(inventory_tab_buttons[tab_name], point):
			return true
	for slot_key in inventory_slots.keys():
		if control_contains_point(inventory_slots[slot_key], point):
			return true
	if item_context_menu != null and item_context_menu.visible and control_contains_point(item_context_menu, point):
		return true
	if not is_inventory_scene_window():
		if inventory_detail_panel != null and control_contains_point(inventory_detail_panel, point):
			return true
		if inventory_scroll_container != null and control_contains_point(inventory_scroll_container, point):
			return true
	return false


func is_item_selection_mode_active() -> bool:
	return trade_select_active or vend_select_active or safe_select_active or donation_box_select_active or display_select_active or oil_refinery_battery_select_active


func begin_trade_item_select(slot_index: int):
	trade_select_active = true
	trade_select_slot_index = slot_index
	vend_select_active = false
	safe_select_active = false
	donation_box_select_active = false
	display_select_active = false
	oil_refinery_battery_select_active = false
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "all"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select an item to add to the trade.")


func end_trade_item_select(close_drawer: bool = false):
	trade_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_trade_item_selecting() -> bool:
	return trade_select_active


func begin_vend_item_select():
	vend_select_active = true
	trade_select_active = false
	safe_select_active = false
	donation_box_select_active = false
	display_select_active = false
	oil_refinery_battery_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "all"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select an item for the vending machine.")


func end_vend_item_select(close_drawer: bool = false):
	vend_select_active = false
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_vend_item_selecting() -> bool:
	return vend_select_active


func begin_safe_item_select():
	safe_select_active = true
	donation_box_select_active = false
	vend_select_active = false
	trade_select_active = false
	display_select_active = false
	oil_refinery_battery_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "all"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select an item for the safe.")


func end_safe_item_select(close_drawer: bool = false):
	safe_select_active = false
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_safe_item_selecting() -> bool:
	return safe_select_active


func begin_donation_box_item_select():
	donation_box_select_active = true
	safe_select_active = false
	vend_select_active = false
	trade_select_active = false
	display_select_active = false
	oil_refinery_battery_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "all"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select an item and amount to donate.")


func end_donation_box_item_select(close_drawer: bool = false):
	donation_box_select_active = false
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_donation_box_item_selecting() -> bool:
	return donation_box_select_active


func begin_display_item_select():
	display_select_active = true
	safe_select_active = false
	donation_box_select_active = false
	vend_select_active = false
	trade_select_active = false
	oil_refinery_battery_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "all"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select an item to display.")


func end_display_item_select(close_drawer: bool = false):
	display_select_active = false
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_display_item_selecting() -> bool:
	return display_select_active


func begin_oil_refinery_battery_select():
	oil_refinery_battery_select_active = true
	display_select_active = false
	safe_select_active = false
	donation_box_select_active = false
	vend_select_active = false
	trade_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_MODAL_Z_INDEX
	inventory_tab = "materials"
	inventory_drawer_target = 1.0
	update_inventory_window()
	if is_inventory_scene_window() and inventory_window.has_method("set_current_tab"):
		inventory_window.set_current_tab("materials")
	if world != null and world.has_method("show_notification"):
		world.show_notification("Select batteries for the oil refinery.")


func end_oil_refinery_battery_select(close_drawer: bool = false):
	oil_refinery_battery_select_active = false
	hide_item_context_menu()
	hide_trade_select_blocker()
	if inventory_window != null:
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_oil_refinery_battery_selecting() -> bool:
	return oil_refinery_battery_select_active


func show_trade_select_blocker():
	if ui_layer_ref == null:
		return
	if trade_select_blocker == null:
		trade_select_blocker = ui_layer_ref.get_node_or_null("TradeInventoryInputBlocker")
	if trade_select_blocker == null:
		trade_select_blocker = ColorRect.new()
		trade_select_blocker.name = "TradeInventoryInputBlocker"
		trade_select_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		trade_select_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
		trade_select_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		trade_select_blocker.gui_input.connect(_on_trade_select_blocker_gui_input)
		ui_layer_ref.add_child(trade_select_blocker)
	trade_select_blocker.z_index = 210
	trade_select_blocker.visible = true
	trade_select_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	place_trade_select_layers()


func place_trade_select_layers():
	if ui_layer_ref == null:
		return
	if trade_select_blocker != null and trade_select_blocker.get_parent() == ui_layer_ref:
		ui_layer_ref.move_child(trade_select_blocker, 0)
	if inventory_window != null and inventory_window.get_parent() == ui_layer_ref:
		ui_layer_ref.move_child(inventory_window, ui_layer_ref.get_child_count() - 1)
	if item_context_menu != null and item_context_menu.get_parent() == ui_layer_ref and item_context_menu.visible:
		ui_layer_ref.move_child(item_context_menu, ui_layer_ref.get_child_count() - 1)


func hide_trade_select_blocker():
	if trade_select_blocker != null:
		trade_select_blocker.visible = false
		trade_select_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_trade_select_blocker_gui_input(event: InputEvent):
	if not is_item_selection_mode_active():
		return
	if event is InputEventMouseButton and event.pressed:
		mark_inventory_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		mark_inventory_input_as_handled()


func can_select_item_for_trade(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if category == "currency":
		return false
	if item_type == "punch":
		return false
	if world != null and world.item_database.has(item_type):
		if not bool(world.item_database[item_type].get("tradeable", true)):
			return false
	return get_item_count(item_type, category) > 0


func can_select_item_for_vend(item_type: String, category: String) -> bool:
	if not can_select_item_for_trade(item_type, category):
		return false
	if is_world_lock_currency_item(item_type):
		return false
	if item_type == "vending_machine" or item_type == "vend_empty" or item_type == "vend_pending" or item_type == "vend_sold":
		return false
	if world != null and world.item_database.has(item_type):
		return bool(world.item_database[item_type].get("tradeable", true))
	return true


func can_select_item_for_safe(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if item_type == "punch":
		return false
	if item_type == "safe":
		return false
	if world != null and world.item_database.has(item_type):
		return not bool(world.item_database[item_type].get("hidden", false)) and get_item_count(item_type, category) > 0
	return get_item_count(item_type, category) > 0


func can_select_item_for_donation_box(item_type: String, category: String) -> bool:
	if not can_select_item_for_trade(item_type, category):
		return false
	if item_type.strip_edges().to_lower() == "donation_box":
		return false
	if is_world_lock_currency_item(item_type):
		return false
	if world != null and world.item_database.has(item_type):
		var item_data: Dictionary = world.item_database[item_type]
		if bool(item_data.get("hidden", false)) or not bool(item_data.get("tradeable", true)):
			return false
	return true


func can_select_item_for_display(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if item_type == "punch" or item_type == "safe":
		return false
	if world != null and world.has_method("is_display_block_type") and world.is_display_block_type(item_type):
		return false
	if world != null and world.item_database.has(item_type):
		if bool(world.item_database[item_type].get("hidden", false)):
			return false
	return get_item_count(item_type, category) > 0


func can_select_item_for_oil_refinery_battery(item_type: String, category: String) -> bool:
	return item_type == OIL_REFINERY_BATTERY_ITEM_ID and category == OIL_REFINERY_BATTERY_ITEM_CATEGORY and get_item_count(item_type, category) > 0


func can_select_item_for_active_mode(item_type: String, category: String) -> bool:
	if vend_select_active:
		return can_select_item_for_vend(item_type, category)
	if safe_select_active:
		return can_select_item_for_safe(item_type, category)
	if donation_box_select_active:
		return can_select_item_for_donation_box(item_type, category)
	if display_select_active:
		return can_select_item_for_display(item_type, category)
	if oil_refinery_battery_select_active:
		return can_select_item_for_oil_refinery_battery(item_type, category)
	return can_select_item_for_trade(item_type, category)


func can_drop_item_from_inventory(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if item_type == "punch":
		return false
	if world != null and world.item_database.has(item_type):
		return bool(world.item_database[item_type].get("dropable", true))
	return true


func mark_manual_hotbar_selection() -> void:
	if world != null:
		world.set_meta("manual_hotbar_selection_msec", Time.get_ticks_msec())


func select_hotbar_item(item_type: String, category: String) -> void:
	if world == null:
		return
	if item_type == "" or category == "" or category == "empty":
		return
	mark_manual_hotbar_selection()
	world.select_item(item_type, category)
	refresh_hotbar_live()


func select_hotbar_slot(slot_index: int):
	if world == null:
		return
	normalize_hotbar()
	var slot_count = min(world.hotbar_items.size(), world.hotbar_item_categories.size(), HOTBAR_SLOT_COUNT)
	if slot_index < 0 or slot_index >= slot_count:
		return
	var item_type = str(world.hotbar_items[slot_index])
	var category = str(world.hotbar_item_categories[slot_index])
	select_hotbar_item(item_type, category)


func persist_hotbar_state():
	if world != null and world.has_method("save_player_data"):
		world.save_player_data()


func is_reserved_hotbar_tool(item_type: String, category: String) -> bool:
	return category == "tool" and (item_type == "punch" or item_type == "wrench")


func assign_item_to_quick_hotbar(item_type: String, category: String):
	if item_type == "" or category == "" or category == "empty":
		return
	if is_reserved_hotbar_tool(item_type, category):
		return
	if not can_show_in_hotbar(item_type, category):
		return
	normalize_hotbar()
	for i in range(world.hotbar_items.size() - 1, 0, -1):
		if world.hotbar_items[i] == item_type and world.hotbar_item_categories[i] == category:
			world.hotbar_items.remove_at(i)
			world.hotbar_item_categories.remove_at(i)
	var insert_index = 1 if world.hotbar_items.size() > 0 else 0
	world.hotbar_items.insert(insert_index, item_type)
	world.hotbar_item_categories.insert(insert_index, category)
	while world.hotbar_items.size() > HOTBAR_SLOT_COUNT:
		world.hotbar_items.pop_back()
		world.hotbar_item_categories.pop_back()
	update_scene_hotbar_slots(false)
	call_deferred("persist_hotbar_state")


func can_show_in_hotbar(item_type: String, category: String, allow_empty_count: bool = false) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if is_reserved_hotbar_tool(item_type, category):
		return true
	if world == null:
		return false
	if not world.item_database.has(item_type):
		return false
	if bool(world.item_database[item_type].get("hidden", false)):
		return false
	if allow_empty_count:
		return true
	return get_item_count(item_type, category) > 0


func hotbar_contains(new_items: Array, new_categories: Array, item_type: String, category: String) -> bool:
	for i in range(new_items.size()):
		if new_items[i] == item_type and new_categories[i] == category:
			return true
	return false


func append_hotbar_item(new_items: Array, new_categories: Array, item_type: String, category: String, allow_empty_count: bool = false):
	if new_items.size() >= HOTBAR_SLOT_COUNT:
		return
	if is_reserved_hotbar_tool(item_type, category):
		return
	if not can_show_in_hotbar(item_type, category, allow_empty_count):
		return
	if hotbar_contains(new_items, new_categories, item_type, category):
		return
	new_items.append(item_type)
	new_categories.append(category)


func normalize_hotbar():
	var primary_tool = "punch"
	if world != null and world.has_method("get_primary_hotbar_tool"):
		primary_tool = world.get_primary_hotbar_tool()
	var new_items = [primary_tool]
	var new_categories = ["tool"]
	var existing_hotbar_size = min(world.hotbar_items.size(), world.hotbar_item_categories.size())
	for i in range(1, existing_hotbar_size):
		var item_type = world.hotbar_items[i]
		var category = world.hotbar_item_categories[i]
		append_hotbar_item(new_items, new_categories, item_type, category)

	if not hotbar_contains(new_items, new_categories, world.selected_item_type, world.selected_item_category):
		if not is_reserved_hotbar_tool(world.selected_item_type, world.selected_item_category) and can_show_in_hotbar(world.selected_item_type, world.selected_item_category):
			new_items.insert(1, world.selected_item_type)
			new_categories.insert(1, world.selected_item_category)

	if new_items.size() < HOTBAR_SLOT_COUNT:
		for block_name in world.block_items:
			append_hotbar_item(new_items, new_categories, block_name, "block")
			if new_items.size() >= HOTBAR_SLOT_COUNT:
				break
	if new_items.size() < HOTBAR_SLOT_COUNT:
		var seed_items = []
		for seed_name in world.seed_inventory.keys():
			seed_items.append(seed_name)
		seed_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for seed_name in seed_items:
			append_hotbar_item(new_items, new_categories, seed_name, "seed")
			if new_items.size() >= HOTBAR_SLOT_COUNT:
				break
	if new_items.size() < HOTBAR_SLOT_COUNT:
		var lure_items = []
		for lure_name in world.lure_inventory.keys():
			lure_items.append(lure_name)
		lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for lure_name in lure_items:
			append_hotbar_item(new_items, new_categories, lure_name, "lure")
			if new_items.size() >= HOTBAR_SLOT_COUNT:
				break
	while new_items.size() > HOTBAR_SLOT_COUNT:
		new_items.pop_back()
		new_categories.pop_back()
	world.hotbar_items = new_items
	world.hotbar_item_categories = new_categories
	if is_reserved_hotbar_tool(world.selected_item_type, world.selected_item_category):
		if world.selected_item_type != primary_tool:
			world.selected_item_type = primary_tool
			world.selected_item_category = "tool"
	elif not can_show_in_hotbar(world.selected_item_type, world.selected_item_category):
		world.selected_item_type = primary_tool
		world.selected_item_category = "tool"


func get_item_texture(item_type: String, category: String):
	var icon_texture = get_inventory_icon_texture(item_type, category)
	if icon_texture != null:
		return icon_texture

	if category == "block":
		if world.block_textures.has(item_type):
			return world.block_textures[item_type]
	if category == "seed":
		if world.seed_textures.has(item_type):
			return world.seed_textures[item_type]
	if category == "tool":
		if world.tool_textures.has(item_type):
			return world.tool_textures[item_type]
	if category == "material":
		if world.material_textures.has(item_type):
			return world.material_textures[item_type]
	if category == "lure":
		if world.lure_textures.has(item_type):
			return world.lure_textures[item_type]
	if category == "fish":
		if world.fish_textures.has(item_type):
			return world.fish_textures[item_type]
	if category == "currency":
		if world.currency_textures.has(item_type):
			return world.currency_textures[item_type]
	if category == "back":
		var icon_paths = [
			"res://Assets/player/back_item/" + item_type + "/" + item_type + "_icon.png",
			"res://Assets/player/back_item/" + item_type + "/" + item_type + "_idle.png",
			"res://Assets/player/back_item/" + item_type + "/icon.png",
			"res://Assets/player/back_item/" + item_type + "/idle.png"
		]
		for icon_path in icon_paths:
			if ResourceLoader.exists(icon_path):
				return load(icon_path)
		if world.back_textures.has(item_type):
			return world.back_textures[item_type]
	if category == "hat":
		if world.hat_textures.has(item_type):
			return world.hat_textures[item_type]
	if category == "hair":
		if world.hair_textures.has(item_type):
			return world.hair_textures[item_type]
	if category == "eyewear":
		if world.eyewear_textures.has(item_type):
			return world.eyewear_textures[item_type]
	if category == "shirt":
		if world.shirt_textures.has(item_type):
			return world.shirt_textures[item_type]
	if category == "pants":
		if world.pants_textures.has(item_type):
			return world.pants_textures[item_type]
	if category == "shoes":
		if world.shoes_textures.has(item_type):
			return world.shoes_textures[item_type]
	if category == "ride":
		if world.ride_textures.has(item_type):
			return world.ride_textures[item_type]
	if world.item_database.has(item_type):
		var texture = AtlasTextureFactory.load_texture(world.item_database[item_type].get("texture", null))
		if texture != null:
			return texture
	return null


func get_inventory_icon_texture(item_type: String, category: String):
	if world != null and world.has_method("get_inventory_icon_texture"):
		return world.get_inventory_icon_texture(item_type, category)

	return null


func get_colour_cycle_item_data(item_type: String) -> Dictionary:
	var clean_item := str(item_type).strip_edges().to_lower()
	if clean_item == "" or world == null or not world.item_database.has(clean_item):
		return {}
	var item_data: Variant = world.item_database.get(clean_item, {})
	if item_data is Dictionary and ColourCycleModulation.is_colour_cycle_item(item_data):
		return item_data
	return {}


func is_colour_cycle_icon_item(item_type: String, category: String) -> bool:
	return str(category).strip_edges().to_lower() == "block" and not get_colour_cycle_item_data(item_type).is_empty()


func get_colour_cycle_icon_modulate(item_type: String, phase_seed: float = 0.0) -> Color:
	var item_data := get_colour_cycle_item_data(item_type)
	if item_data.is_empty():
		return Color.WHITE
	return ColourCycleModulation.get_colour_cycle_modulate(item_data, phase_seed)


func apply_colour_cycle_icon_modulation(icon: TextureRect, _item_type: String, _category: String, _phase_seed: float = 0.0) -> void:
	if icon == null:
		return
	icon.self_modulate = Color.WHITE


func update_hotbar_colour_cycle_icons_throttled(_delta: float) -> void:
	colour_cycle_hotbar_update_elapsed = 0.0
	return


func update_hotbar_colour_cycle_icons() -> void:
	if hotbar_slots.is_empty() or world == null:
		return
	for slot_index in hotbar_slots.keys():
		var slot = hotbar_slots[slot_index]
		if slot == null or not is_instance_valid(slot):
			continue
		var item_type := str(slot.get_meta("item_type", "")).strip_edges().to_lower()
		var category := str(slot.get_meta("category", "")).strip_edges().to_lower()
		var icon := slot.get_node_or_null("Icon") as TextureRect
		apply_colour_cycle_icon_modulation(icon, item_type, category, float(int(slot_index)) / 12.0)


func update_hotbar_selected_frame_animation(_delta: float) -> void:
	if hotbar_slots.is_empty() or HOTBAR_SELECTED_FRAMES.is_empty():
		hotbar_selected_frame_index = 0
		return

	var next_frame_index: int = SelectedSlotFrameClock.frame_index(
		HOTBAR_SELECTED_FRAMES.size(),
		HOTBAR_SELECTED_FRAME_SECONDS
	)
	if next_frame_index == hotbar_selected_frame_index:
		return
	hotbar_selected_frame_index = next_frame_index
	var selected_texture: Texture2D = HOTBAR_SELECTED_FRAMES[hotbar_selected_frame_index] as Texture2D
	for slot in hotbar_slots.values():
		if slot == null or not is_instance_valid(slot):
			continue
		var selected_frame := slot.get_node_or_null("SelectedFrame") as TextureRect
		if selected_frame != null and selected_frame.visible:
			selected_frame.texture = selected_texture


func is_seed_item(item_type: String, category: String) -> bool:
	return category == "seed" or item_type.ends_with("_seed")


func remove_seed_box_icon_overlay(icon: TextureRect):
	if icon == null:
		return

	var existing = icon.get_node_or_null(SEED_BOX_PREVIEW_NODE_NAME)
	if existing != null:
		icon.remove_child(existing)
		existing.queue_free()


func update_seed_box_icon_overlay(icon: TextureRect, item_type: String, category: String):
	if icon == null:
		return
	if not is_seed_item(item_type, category):
		remove_seed_box_icon_overlay(icon)
		return

	if world == null or not world.has_method("get_seed_icon_preview_layout"):
		remove_seed_box_icon_overlay(icon)
		return

	if world.has_method("get_seed_drop_icon_texture"):
		var seed_box_texture = world.get_seed_drop_icon_texture(item_type)
		if seed_box_texture is Texture2D:
			icon.texture = seed_box_texture

	var layout: Dictionary = world.get_seed_icon_preview_layout(item_type)
	if layout.is_empty():
		remove_seed_box_icon_overlay(icon)
		return

	var preview_texture = layout.get("preview_texture", null)
	var box_size: Vector2i = layout.get("box_size", Vector2i.ZERO)
	var preview_size: Vector2i = layout.get("preview_size", Vector2i.ZERO)
	var destination: Vector2i = layout.get("destination", Vector2i.ZERO)
	if preview_texture == null or box_size.x <= 0 or box_size.y <= 0 or preview_size.x <= 0 or preview_size.y <= 0:
		remove_seed_box_icon_overlay(icon)
		return
	if icon.size.x <= 0.0 or icon.size.y <= 0.0:
		remove_seed_box_icon_overlay(icon)
		return

	var preview = icon.get_node_or_null(SEED_BOX_PREVIEW_NODE_NAME)
	if preview == null or not (preview is TextureRect):
		if preview != null:
			icon.remove_child(preview)
			preview.queue_free()
		preview = TextureRect.new()
		preview.name = SEED_BOX_PREVIEW_NODE_NAME
		icon.add_child(preview)

	var preview_rect := preview as TextureRect
	var source_size := Vector2(
		float(max(1, int(preview_texture.get_width()))),
		float(max(1, int(preview_texture.get_height())))
	)
	var fit_scale: float = min(icon.size.x / float(box_size.x), icon.size.y / float(box_size.y))
	var box_display_size := Vector2(box_size) * fit_scale
	var box_offset := (icon.size - box_display_size) * 0.5
	preview_rect.texture = preview_texture
	preview_rect.position = box_offset + Vector2(destination) * fit_scale
	preview_rect.size = source_size
	preview_rect.scale = Vector2(
		(float(preview_size.x) / source_size.x) * fit_scale,
		(float(preview_size.y) / source_size.y) * fit_scale
	)
	preview_rect.pivot_offset = Vector2.ZERO
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
	preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_rect.visible = true


func load_hotbar_wrench_icon_texture() -> Texture2D:
	if ResourceLoader.exists(HOTBAR_WRENCH_ICON_PATH):
		var ui_icon_texture: Texture2D = load(HOTBAR_WRENCH_ICON_PATH) as Texture2D
		if ui_icon_texture != null:
			return ui_icon_texture

	return get_item_texture("wrench", "tool") as Texture2D


func load_hotbar_punch_icon_texture() -> Texture2D:
	if ResourceLoader.exists(HOTBAR_PUNCH_ICON_PATH):
		var ui_icon_texture: Texture2D = load(HOTBAR_PUNCH_ICON_PATH) as Texture2D
		if ui_icon_texture != null:
			return ui_icon_texture

	return get_item_texture("punch", "tool") as Texture2D


func get_item_count(item_type: String, category: String) -> int:
	if category == "block" and world.inventory.has(item_type):
		return int(world.inventory[item_type])
	if category == "seed" and world.seed_inventory.has(item_type):
		return int(world.seed_inventory[item_type])
	if category == "tool" and world.tool_inventory.has(item_type):
		return int(world.tool_inventory[item_type])
	if category == "material" and world.material_inventory.has(item_type):
		return int(world.material_inventory[item_type])
	if category == "lure" and world.lure_inventory.has(item_type):
		return int(world.lure_inventory[item_type])
	if category == "fish" and world.fish_inventory.has(item_type):
		return fish_inventory_value_to_count(world.fish_inventory[item_type])
	if category == "currency" and world.currency_inventory.has(item_type):
		return int(world.currency_inventory[item_type])
	if category == "back" and world.back_inventory.has(item_type):
		return int(world.back_inventory[item_type])
	if category == "hat" and world.hat_inventory.has(item_type):
		return int(world.hat_inventory[item_type])
	if category == "hair" and world.hair_inventory.has(item_type):
		return int(world.hair_inventory[item_type])
	if category == "eyewear" and world.eyewear_inventory.has(item_type):
		return int(world.eyewear_inventory[item_type])
	if category == "shirt" and world.shirt_inventory.has(item_type):
		return int(world.shirt_inventory[item_type])
	if category == "pants" and world.pants_inventory.has(item_type):
		return int(world.pants_inventory[item_type])
	if category == "shoes" and world.shoes_inventory.has(item_type):
		return int(world.shoes_inventory[item_type])
	if category == "ride" and world.ride_inventory.has(item_type):
		return int(world.ride_inventory[item_type])
	return 0


func get_fish_weight_lb(item_type: String) -> float:
	if world == null or not world.fish_inventory.has(item_type):
		return 0.0
	return float(get_item_count(item_type, "fish"))


func is_weight_item(item_id: String) -> bool:
	if world == null or item_id == "":
		return false
	if world.item_database.has(item_id):
		var item_data: Dictionary = world.item_database[item_id]
		if bool(item_data.get("is_fish", false)):
			return true
		if str(item_data.get("quantity_type", "")) == "weight":
			return true
		return str(item_data.get("category", "")) == "fish"
	return world.fish_inventory.has(item_id)


func fish_inventory_value_to_count(value) -> int:
	if value is int:
		return max(0, int(value))
	if value is float:
		var raw_float: float = float(value)
		if not is_finite(raw_float) or raw_float <= 0.0:
			return 0
		return max(0, int(floor(raw_float)))
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_int():
			return max(0, int(text))
		if text.is_valid_float():
			return max(0, int(floor(float(text))))
	return 0


func fish_weight_to_tenths(weight) -> int:
	return fish_inventory_value_to_count(weight)


func fish_inventory_value_to_tenths(value) -> int:
	return fish_inventory_value_to_count(value)


func fish_tenths_to_weight(tenths: int) -> float:
	return float(max(0, tenths))


func normalize_fish_weight(weight) -> float:
	return float(fish_inventory_value_to_count(weight))


func get_item_weight_tenths(item_id: String) -> int:
	if world == null or not world.fish_inventory.has(item_id):
		return 0
	return fish_inventory_value_to_count(world.fish_inventory[item_id])


func has_fish_weight(item_id: String, weight) -> bool:
	var requested_count: int = fish_inventory_value_to_count(weight)
	if requested_count <= 0:
		return false
	return get_item_weight_tenths(item_id) >= requested_count


func add_fish_weight(item_id: String, weight) -> bool:
	if world == null or item_id == "" or not is_weight_item(item_id):
		return false
	var add_count: int = fish_inventory_value_to_count(weight)
	if add_count <= 0:
		return false
	var current_count: int = get_item_weight_tenths(item_id)
	world.fish_inventory[item_id] = current_count + add_count
	notify_inventory_item_changed(item_id, "fish")
	return true


func remove_fish_weight(item_id: String, weight, show_error: bool = false) -> bool:
	if world == null or item_id == "" or not is_weight_item(item_id):
		return false
	var requested_count: int = fish_inventory_value_to_count(weight)
	if requested_count <= 0:
		if show_error and world.has_method("show_notification"):
			world.show_notification("Choose at least 1 fish.")
		return false
	var current_count: int = get_item_weight_tenths(item_id)
	if current_count < requested_count:
		if show_error and world.has_method("show_notification"):
			world.show_notification("You only have " + format_fish_weight(current_count) + ".")
		return false
	var remaining_count: int = max(0, current_count - requested_count)
	if remaining_count <= 0:
		world.fish_inventory.erase(item_id)
	else:
		world.fish_inventory[item_id] = remaining_count
	notify_inventory_item_changed(item_id, "fish")
	return true


func format_fish_weight(amount) -> String:
	return "x" + format_stack_count(fish_inventory_value_to_count(amount))


func format_inventory_amount(item_type: String, category: String, amount = null) -> String:
	if category == "fish":
		return format_fish_weight(get_item_count(item_type, category) if amount == null else amount)
	return "x" + str(int(amount) if amount != null else get_item_count(item_type, category))


func get_item_display_name(item_type: String, category: String) -> String:
	if category == "tool" and item_type == "punch":
		return "Punch"
	if world.item_database.has(item_type):
		return str(world.item_database[item_type].get("display_name", item_type.capitalize()))
	if category == "seed":
		return item_type.replace("_seed", "").capitalize() + " Seed"
	return item_type.capitalize()


func setup_scene_hotbar():
	if world == null:
		return
	normalize_hotbar()
	if ui_layer_ref == null:
		return

	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return

	var existing_hotbar = hud_layer.get_node_or_null("Hotbar")
	if existing_hotbar == null and hud_layer != ui_layer_ref:
		existing_hotbar = ui_layer_ref.get_node_or_null("Hotbar")

	if existing_hotbar == null or existing_hotbar.get_node_or_null("BarPanel") == null:
		if existing_hotbar != null:
			var existing_parent = existing_hotbar.get_parent()
			if existing_parent != null:
				existing_parent.remove_child(existing_hotbar)
			existing_hotbar.queue_free()
		hotbar_root = HOTBAR_SCENE.instantiate()
		hotbar_root.name = "Hotbar"
		hud_layer.add_child(hotbar_root)
	else:
		hotbar_root = existing_hotbar
		if hotbar_root.get_parent() != hud_layer:
			var old_parent = hotbar_root.get_parent()
			if old_parent != null:
				old_parent.remove_child(hotbar_root)
			hud_layer.add_child(hotbar_root)

	hotbar_root.z_index = HOTBAR_Z_INDEX
	hotbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_root.size = Vector2(get_hotbar_base_visual_width(), get_hotbar_base_visual_height())

	hotbar_handle = hotbar_root.get_node_or_null("InventorySlideHandle")
	if hotbar_handle != null:
		hotbar_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		var handle_callable = Callable(self, "_on_hotbar_handle_gui_input")
		if not hotbar_handle.gui_input.is_connected(handle_callable):
			hotbar_handle.gui_input.connect(handle_callable)

	hotbar_slots.clear()
	var slot_count = min(world.hotbar_items.size(), HOTBAR_SLOT_COUNT)
	for i in range(HOTBAR_SLOT_COUNT):
		var slot = hotbar_root.get_node_or_null("Slot_" + str(i))
		if slot == null:
			continue
		var active = i < slot_count
		slot.visible = active
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		if not active:
			continue
		var item_type = world.hotbar_items[i]
		var category = world.hotbar_item_categories[i]
		slot.set_meta("item_type", item_type)
		slot.set_meta("category", category)
		var slot_number = slot.get_node_or_null("SlotNumber")
		if slot_number != null and slot_number is Label:
			slot_number.text = str(i + 1)
		var slot_callable = Callable(self, "_on_hotbar_slot_gui_input").bind(i)
		if not slot.gui_input.is_connected(slot_callable):
			slot.gui_input.connect(slot_callable)
		hotbar_slots[i] = slot

	update_hotbar_position()
	update_scene_hotbar_slots(false)


func update_scene_hotbar_slot_frame(slot: Control, rarity: String, selected: bool, item_type: String = "", category: String = ""):
	var frame = slot.get_node_or_null("SlotFrame") as TextureRect
	var selected_frame = slot.get_node_or_null("SelectedFrame") as TextureRect
	if frame != null:
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		var frame_texture = get_hotbar_slot_frame_texture(get_slot_texture_name(rarity, false, item_type, category))
		if frame_texture != null:
			frame.texture = frame_texture
		frame.visible = true
	if selected_frame != null:
		selected_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		selected_frame.stretch_mode = TextureRect.STRETCH_SCALE
		hotbar_selected_frame_index = SelectedSlotFrameClock.frame_index(
			HOTBAR_SELECTED_FRAMES.size(),
			HOTBAR_SELECTED_FRAME_SECONDS
		)
		var selected_texture: Texture2D = HOTBAR_SELECTED_FRAMES[hotbar_selected_frame_index] as Texture2D
		if selected_texture != null:
			selected_frame.texture = selected_texture
		selected_frame.visible = selected


func update_scene_hotbar_slot_icon(slot: Control, item_type: String, category: String):
	var icon = slot.get_node_or_null("Icon") as TextureRect
	var icon_shadow = slot.get_node_or_null("IconShadow") as TextureRect
	var fallback_label = slot.get_node_or_null("FallbackLabel") as Label
	var icon_texture: Texture2D = null
	var fallback_text = ""

	if category == "tool" and item_type == "punch":
		icon_texture = load_hotbar_punch_icon_texture()
		fallback_text = "P"
	elif category == "tool" and item_type == "wrench":
		icon_texture = load_hotbar_wrench_icon_texture()
		fallback_text = "W"
	else:
		icon_texture = get_item_texture(item_type, category)
		fallback_text = "?"

	var has_texture = icon_texture != null
	if icon != null:
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.visible = has_texture
		icon.texture = icon_texture
		icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
		_apply_hotbar_slot_icon_layout(icon, icon_shadow, item_type, category)
		apply_colour_cycle_icon_modulation(icon, item_type, category, 0.0)
		if has_texture and category != "tool":
			update_seed_box_icon_overlay(icon, item_type, category)
		else:
			remove_seed_box_icon_overlay(icon)
	if icon_shadow != null:
		icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_shadow.visible = has_texture
		icon_shadow.texture = icon_texture
		icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.30)
	if fallback_label != null:
		fallback_label.visible = not has_texture
		fallback_label.text = fallback_text


func _get_hotbar_slot_icon_layout(item_type: String, _category: String, icon: TextureRect, icon_shadow: TextureRect) -> Dictionary:
	var item_data: Dictionary = {}
	if world != null and world.item_database.has(item_type) and world.item_database[item_type] is Dictionary:
		item_data = world.item_database[item_type]

	var layout = AtlasTextureFactory.get_wearable_icon_layout(item_data.get("inventory_icon", null))
	if layout.is_empty():
		layout = AtlasTextureFactory.get_wearable_icon_layout(item_data.get("icon", null))
	if layout.is_empty():
		layout = AtlasTextureFactory.get_wearable_icon_layout(item_data.get("icon_path", null))
	if layout.is_empty():
		layout = AtlasTextureFactory.get_wearable_icon_layout(item_data.get("texture", null))

	var fallback_position := icon.position
	var fallback_size := icon.size
	var fallback_scale := icon.scale
	var fallback_shadow_position := Vector2(
		fallback_position.x + 3.0,
		fallback_position.y + 4.0
	)
	var fallback_shadow_size := fallback_size
	var fallback_shadow_scale := icon_shadow.scale if icon_shadow != null else fallback_scale

	var resolved_position: Vector2 = layout.get("icon_position", fallback_position)
	var resolved_size: Vector2 = layout.get("icon_size", fallback_size)
	var resolved_shadow_position: Vector2 = layout.get("icon_shadow_position", fallback_shadow_position)
	var resolved_shadow_size: Vector2 = layout.get("icon_shadow_size", resolved_size)
	var resolved_scale := AtlasTextureFactory.get_scale_vector(
		layout.get("icon_scale", fallback_scale),
		fallback_scale
	)
	var resolved_shadow_scale := AtlasTextureFactory.get_scale_vector(
		layout.get("icon_shadow_scale", fallback_shadow_scale),
		fallback_shadow_scale
	)

	if layout.is_empty():
		# Keep current frame defaults when no metadata is set.
		resolved_position = icon.position
		resolved_size = icon.size
		resolved_shadow_position = layout.get(
			"icon_shadow_position",
			Vector2(
				fallback_position.x + 3.0,
				fallback_position.y + 4.0
			)
		)
		resolved_shadow_size = resolved_size
		resolved_scale = icon.scale
		resolved_shadow_scale = fallback_shadow_scale

	# Allow item data to override icon metadata explicitly.
	if item_data.has("inventory_icon_position"):
		resolved_position = AtlasTextureFactory.get_vector2(item_data.get("inventory_icon_position"), resolved_position)
	if item_data.has("icon_position"):
		resolved_position = AtlasTextureFactory.get_vector2(item_data.get("icon_position"), resolved_position)
	if item_data.has("inventory_icon_size"):
		resolved_size = AtlasTextureFactory.get_vector2(item_data.get("inventory_icon_size"), resolved_size)
	if item_data.has("icon_size"):
		resolved_size = AtlasTextureFactory.get_vector2(item_data.get("icon_size"), resolved_size)

	var icon_shadow_offset = AtlasTextureFactory.get_vector2(
		item_data.get("inventory_icon_shadow_offset", item_data.get("icon_shadow_offset", null)),
		resolved_shadow_position - resolved_position
	)
	if item_data.has("inventory_icon_shadow_offset") or item_data.has("icon_shadow_offset"):
		resolved_shadow_position = resolved_position + icon_shadow_offset

	if item_data.has("inventory_icon_shadow_size"):
		resolved_shadow_size = AtlasTextureFactory.get_vector2(item_data.get("inventory_icon_shadow_size"), resolved_shadow_size)
	if item_data.has("icon_shadow_size"):
		resolved_shadow_size = AtlasTextureFactory.get_vector2(item_data.get("icon_shadow_size"), resolved_shadow_size)

	if item_data.has("inventory_icon_scale") or item_data.has("icon_scale"):
		resolved_scale = AtlasTextureFactory.get_scale_vector(
			item_data.get("inventory_icon_scale", item_data.get("icon_scale", null)),
			resolved_scale
		)

	if item_data.has("inventory_icon_shadow_scale") or item_data.has("icon_shadow_scale"):
		resolved_shadow_scale = AtlasTextureFactory.get_scale_vector(
			item_data.get("inventory_icon_shadow_scale", item_data.get("icon_shadow_scale", null)),
			resolved_shadow_scale
		)

	layout.clear()
	layout["icon_position"] = AtlasTextureFactory.get_vector2(resolved_position, fallback_position)
	layout["icon_size"] = AtlasTextureFactory.get_vector2(resolved_size, fallback_size)
	layout["icon_scale"] = resolved_scale
	layout["icon_shadow_position"] = AtlasTextureFactory.get_vector2(resolved_shadow_position, fallback_shadow_position)
	layout["icon_shadow_size"] = AtlasTextureFactory.get_vector2(resolved_shadow_size, resolved_size)
	layout["icon_shadow_scale"] = resolved_shadow_scale

	return layout


func _apply_hotbar_slot_icon_layout(icon: TextureRect, icon_shadow: TextureRect, item_type: String, category: String) -> void:
	if icon == null:
		return

	var icon_layout := _get_hotbar_slot_icon_layout(item_type, category, icon, icon_shadow)
	icon.position = AtlasTextureFactory.get_vector2(icon_layout.get("icon_position", icon.position), icon.position)
	icon.size = AtlasTextureFactory.get_vector2(icon_layout.get("icon_size", icon.size), icon.size)
	icon.scale = AtlasTextureFactory.get_scale_vector(icon_layout.get("icon_scale", icon.scale), icon.scale)
	icon.pivot_offset = icon.size * 0.5

	if icon_shadow == null:
		return
	icon_shadow.position = AtlasTextureFactory.get_vector2(icon_layout.get("icon_shadow_position", icon_shadow.position), icon_shadow.position)
	icon_shadow.size = AtlasTextureFactory.get_vector2(icon_layout.get("icon_shadow_size", icon_shadow.size), icon_shadow.size)
	icon_shadow.scale = AtlasTextureFactory.get_scale_vector(icon_layout.get("icon_shadow_scale", icon_shadow.scale), icon_shadow.scale)
	icon_shadow.pivot_offset = icon_shadow.size * 0.5


func update_scene_hotbar_slot_count(slot: Control, item_type: String, category: String) -> void:
	var count = slot.get_node_or_null("Count")
	var count_badge = slot.get_node_or_null("CountBadge")
	if count != null and count is Label:
		if category == "tool":
			count.text = ""
		elif category == "fish":
			var fish_count: int = get_item_count(item_type, category)
			count.text = format_stack_count(fish_count) if fish_count > 0 else ""
		else:
			var qty: int = get_item_count(item_type, category)
			count.text = format_stack_count(qty) if qty > 0 else ""
		if count_badge != null:
			count_badge.visible = count.text != ""


func refresh_hotbar_live() -> void:
	if world == null:
		return
	var expected_slot_count: int = min(world.hotbar_items.size(), HOTBAR_SLOT_COUNT)
	if hotbar_root == null or hotbar_slots.size() != expected_slot_count:
		update_hotbar()
		return

	for i in range(expected_slot_count):
		if not hotbar_slots.has(i):
			update_hotbar()
			return
		var item_type: String = str(world.hotbar_items[i])
		var category: String = str(world.hotbar_item_categories[i])
		var slot = hotbar_slots[i]
		if str(slot.get_meta("item_type", "")) != item_type or str(slot.get_meta("category", "")) != category:
			update_hotbar()
			return
		if category != "tool" and get_item_count(item_type, category) <= 0:
			update_hotbar()
			return
		var is_selected: bool = world.selected_item_category == category and world.selected_item_type == item_type
		update_scene_hotbar_slot_frame(slot, get_item_rarity(item_type, category), is_selected, item_type, category)
		update_scene_hotbar_slot_count(slot, item_type, category)


func update_scene_hotbar_slots(normalize_first: bool = true):
	if world == null:
		return
	if normalize_first:
		normalize_hotbar()
	var expected_slot_count = min(world.hotbar_items.size(), HOTBAR_SLOT_COUNT)
	if hotbar_root == null or hotbar_slots.size() != expected_slot_count:
		setup_scene_hotbar()
		return

	for i in range(expected_slot_count):
		if not hotbar_slots.has(i):
			setup_scene_hotbar()
			return
		var item_type = world.hotbar_items[i]
		var category = world.hotbar_item_categories[i]
		var slot = hotbar_slots[i]
		slot.set_meta("item_type", item_type)
		slot.set_meta("category", category)
		var is_selected = world.selected_item_category == category and world.selected_item_type == item_type
		var rarity = get_item_rarity(item_type, category)

		update_scene_hotbar_slot_frame(slot, rarity, is_selected, item_type, category)
		update_scene_hotbar_slot_icon(slot, item_type, category)

		var rarity_pip = slot.get_node_or_null("RarityPip") as CanvasItem
		if rarity_pip != null:
			rarity_pip.visible = false

		update_scene_hotbar_slot_count(slot, item_type, category)


func setup_hotbar():
	setup_scene_hotbar()
	return


func _on_hotbar_handle_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_handle_drag(get_inventory_mouse_position_safe().y)
		else:
			finish_handle_drag()
		mark_inventory_input_as_handled()
	if event is InputEventMouseMotion and drag_handle_active:
		update_drawer_drag(get_inventory_mouse_position_safe().y)
		mark_inventory_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed:
			begin_handle_drag(event.position.y, event.index)
		elif event.index == drag_handle_touch_index:
			finish_handle_drag()
		mark_inventory_input_as_handled()
	if event is InputEventScreenDrag and drag_handle_active:
		if drag_handle_touch_index != -1 and event.index != drag_handle_touch_index:
			return
		update_drawer_drag(event.position.y)
		mark_inventory_input_as_handled()


func begin_handle_drag(start_y: float, touch_index: int = -1):
	drag_handle_active = true
	drag_handle_touch_index = touch_index
	drag_handle_start_y = start_y
	drag_handle_start_amount = inventory_drawer_amount
	drag_handle_last_y = drag_handle_start_y
	drag_handle_last_time_ms = Time.get_ticks_msec()
	drag_handle_velocity = 0.0


func update_drawer_drag(current_y: float):
	var now_ms = Time.get_ticks_msec()
	var elapsed = max(0.001, float(now_ms - drag_handle_last_time_ms) / 1000.0)
	var drag_height = get_inventory_drawer_drag_height()
	drag_handle_velocity = ((drag_handle_last_y - current_y) / drag_height) / elapsed
	drag_handle_last_y = current_y
	drag_handle_last_time_ms = now_ms
	var drag_up_distance = drag_handle_start_y - current_y
	inventory_drawer_amount = clamp(
		drag_handle_start_amount + drag_up_distance / drag_height,
		0.0, 1.0
	)
	inventory_drawer_target = inventory_drawer_amount
	update_hotbar_position()
	update_inventory_window_position()


func finish_handle_drag():
	if not drag_handle_active:
		return
	drag_handle_active = false
	drag_handle_touch_index = -1
	inventory_drawer_target = clamp(inventory_drawer_amount, 0.0, 1.0)
	drag_handle_velocity = 0.0
	update_inventory_window()


func get_hotbar_anchor_open_y() -> float:
	var screen_size = get_inventory_viewport_size()
	if hotbar_root != null:
		return hotbar_root.position.y + get_hotbar_visual_height(screen_size)
	return lerp(get_hotbar_closed_y(screen_size), get_hotbar_open_y(screen_size), inventory_drawer_amount) + get_hotbar_visual_height(screen_size)


func _on_hotbar_slot_gui_input(event: InputEvent, slot_index: int):
	var slot_count = min(world.hotbar_items.size(), world.hotbar_item_categories.size(), HOTBAR_SLOT_COUNT)
	if slot_index < 0 or slot_index >= slot_count:
		return
	if should_ignore_mobile_mouse_event(event):
		mark_inventory_input_as_handled()
		return
	var item_type = world.hotbar_items[slot_index]
	var category = world.hotbar_item_categories[slot_index]
	var slot = null
	if hotbar_slots.has(slot_index):
		slot = hotbar_slots[slot_index]
	if is_item_selection_mode_active():
		var selectable: bool = can_select_item_for_active_mode(item_type, category)
		if not selectable:
			if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				mark_inventory_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			show_item_context_menu(item_type, category, slot)
			mark_inventory_input_as_handled()
			return
		if event is InputEventScreenTouch and event.pressed:
			show_item_context_menu(item_type, category, slot)
			mark_inventory_input_as_handled()
			return
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			mark_inventory_input_as_handled()
			return
	if slot_index == 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var now = Time.get_ticks_msec()
			var is_double_tap = event.double_click or (hotbar_slot_zero_last_tap_ms > 0 and now - hotbar_slot_zero_last_tap_ms <= EQUIP_DOUBLE_TAP_TIME_MS)
			hotbar_slot_zero_last_tap_ms = 0 if is_double_tap else now
			if is_double_tap and world.has_method("toggle_primary_hotbar_tool"):
				mark_manual_hotbar_selection()
				world.toggle_primary_hotbar_tool()
			else:
				select_hotbar_item(item_type, category)
			mark_inventory_input_as_handled()
			return
		if event is InputEventScreenTouch:
			if event.pressed:
				var now_touch = Time.get_ticks_msec()
				var is_double_touch = hotbar_slot_zero_last_tap_ms > 0 and now_touch - hotbar_slot_zero_last_tap_ms <= TOUCH_EQUIP_DOUBLE_TAP_TIME_MS
				hotbar_slot_zero_last_tap_ms = 0 if is_double_touch else now_touch
				if is_double_touch and world.has_method("toggle_primary_hotbar_tool"):
					cancel_item_hold()
					mark_manual_hotbar_selection()
					world.toggle_primary_hotbar_tool()
				else:
					start_item_hold(item_type, category, slot, false, "hotbar")
			else:
				finish_item_hold(item_type, category)
			mark_inventory_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			show_item_context_menu(item_type, category, slot)
			mark_inventory_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			show_item_context_menu(item_type, category, slot)
			mark_inventory_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_item_hold(item_type, category, slot, event.double_click, "hotbar")
			else:
				finish_item_hold(item_type, category)
			mark_inventory_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			start_item_hold(item_type, category, slot, is_equip_double_tap(item_type, category, "hotbar"), "hotbar")
		else:
			finish_item_hold(item_type, category)
		mark_inventory_input_as_handled()


func get_hotbar_base_visual_width() -> float:
	return float(
		HOTBAR_FRAME_LEFT_INSET
		+ HOTBAR_SLOT_COUNT * HOTBAR_SLOT_SIZE
		+ (HOTBAR_SLOT_COUNT - 1) * HOTBAR_SLOT_GAP
		+ HOTBAR_FRAME_RIGHT_INSET
	)


func get_hotbar_visual_width(screen_size: Vector2 = Vector2.ZERO) -> float:
	return get_hotbar_base_visual_width() * get_mobile_hud_scale(screen_size)


func update_hotbar_position():
	if hotbar_root == null:
		return
	var hotbar_visible: bool = not is_gameplay_hud_blocked()
	hotbar_root.visible = hotbar_visible
	if not hotbar_visible:
		return
	var screen_size = get_inventory_viewport_size()
	var hud_scale: float = get_mobile_hud_scale(screen_size)
	hotbar_root.scale = Vector2.ONE * hud_scale
	var bar_total_w = get_hotbar_visual_width(screen_size)
	var closed_y = get_hotbar_closed_y(screen_size)
	var open_y = get_hotbar_open_y(screen_size)
	hotbar_root.position = Vector2(
		(screen_size.x - bar_total_w) / 2.0,
		lerp(closed_y, open_y, inventory_drawer_amount)
	)


func hotbar_visuals_need_rebuild() -> bool:
	if hotbar_slots.size() != world.hotbar_items.size():
		return true
	for i in range(world.hotbar_items.size()):
		if not hotbar_slots.has(i):
			return true
		var slot = hotbar_slots[i]
		if not slot.has_meta("item_type") or not slot.has_meta("category"):
			return true
		if str(slot.get_meta("item_type")) != str(world.hotbar_items[i]):
			return true
		if str(slot.get_meta("category")) != str(world.hotbar_item_categories[i]):
			return true
	return false


func update_hotbar():
	update_scene_hotbar_slots()


func setup_inventory_button():
	if ui_layer_ref == null:
		return
	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return
	inventory_button = hud_layer.get_node_or_null("InventoryButton")
	if inventory_button == null and hud_layer != ui_layer_ref:
		inventory_button = ui_layer_ref.get_node_or_null("InventoryButton")
	if inventory_button == null:
		inventory_button = Button.new()
		inventory_button.name = "InventoryButton"
		hud_layer.add_child(inventory_button)
	elif inventory_button.get_parent() != hud_layer:
		var old_parent = inventory_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(inventory_button)
		hud_layer.add_child(inventory_button)
	inventory_button.text = ""
	inventory_button.size = BAG_BUTTON_SIZE
	inventory_button.z_index = INVENTORY_BUTTON_Z_INDEX
	inventory_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_inventory_icon_button_style(inventory_button)
	setup_inventory_button_icon()
	if not inventory_button.pressed.is_connected(toggle_inventory_window):
		inventory_button.pressed.connect(toggle_inventory_window)
	if not inventory_button.mouse_entered.is_connected(_on_inventory_button_mouse_entered):
		inventory_button.mouse_entered.connect(_on_inventory_button_mouse_entered)
	if not inventory_button.mouse_exited.is_connected(_on_inventory_button_mouse_exited):
		inventory_button.mouse_exited.connect(_on_inventory_button_mouse_exited)
	if not inventory_button.button_down.is_connected(_on_inventory_button_down):
		inventory_button.button_down.connect(_on_inventory_button_down)
	if not inventory_button.button_up.is_connected(_on_inventory_button_up):
		inventory_button.button_up.connect(_on_inventory_button_up)
	update_inventory_button_position()


func setup_inventory_button_icon():
	if inventory_button == null:
		return

	for child in inventory_button.get_children():
		child.queue_free()

	inventory_button_icon = null
	inventory_button_icon_shadow = null

	if not ResourceLoader.exists(BAG_ICON_PATH):
		inventory_button.text = "BAG"
		inventory_button.size = Vector2(108, 42)
		apply_arcade_button_style(inventory_button, false, false, 15)
		return

	var icon_texture: Texture2D = load(BAG_ICON_PATH) as Texture2D
	if icon_texture == null:
		inventory_button.text = "BAG"
		inventory_button.size = Vector2(108, 42)
		apply_arcade_button_style(inventory_button, false, false, 15)
		return

	inventory_button_icon_shadow = TextureRect.new()
	inventory_button_icon_shadow.name = "BagIconShadow"
	inventory_button_icon_shadow.texture = icon_texture
	inventory_button_icon_shadow.position = Vector2(5, 7)
	inventory_button_icon_shadow.size = BAG_BUTTON_SIZE
	inventory_button_icon_shadow.pivot_offset = BAG_BUTTON_SIZE * 0.5
	inventory_button_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inventory_button_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_button_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	inventory_button.add_child(inventory_button_icon_shadow)

	inventory_button_icon = TextureRect.new()
	inventory_button_icon.name = "BagIcon"
	inventory_button_icon.texture = icon_texture
	inventory_button_icon.position = Vector2.ZERO
	inventory_button_icon.size = BAG_BUTTON_SIZE
	inventory_button_icon.pivot_offset = BAG_BUTTON_SIZE * 0.5
	inventory_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inventory_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_button_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	inventory_button.add_child(inventory_button_icon)


func apply_inventory_icon_button_style(button: Button):
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_inventory_button_mouse_entered():
	inventory_button_hovered = true
	animate_inventory_button_icon(false)


func _on_inventory_button_mouse_exited():
	inventory_button_hovered = false
	animate_inventory_button_icon(false)


func _on_inventory_button_down():
	animate_inventory_button_icon(true)


func _on_inventory_button_up():
	animate_inventory_button_icon(false)


func animate_inventory_button_icon(pressed: bool):
	if inventory_button_icon == null or inventory_button_icon_shadow == null:
		return

	if inventory_button_tween != null:
		inventory_button_tween.kill()

	var icon_position: Vector2 = Vector2.ZERO
	var shadow_position: Vector2 = Vector2(5, 7)
	var icon_scale: Vector2 = Vector2.ONE
	var shadow_alpha: float = 0.38
	var icon_alpha: float = 0.96

	if inventory_button_hovered:
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

	inventory_button_tween = create_tween()
	inventory_button_tween.set_parallel(true)
	inventory_button_tween.tween_property(inventory_button_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	inventory_button_tween.tween_property(inventory_button_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	inventory_button_tween.tween_property(inventory_button_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	inventory_button_tween.tween_property(inventory_button_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	inventory_button_tween.tween_property(inventory_button_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	inventory_button_tween.tween_property(inventory_button_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func update_inventory_button_position():
	if inventory_button == null:
		return
	var button_visible: bool = not is_floating_hud_blocked()
	inventory_button.visible = button_visible
	if not button_visible:
		return
	var screen_size: Vector2 = get_viewport_rect().size
	var hud_scale: float = get_mobile_hud_scale(screen_size)
	inventory_button.scale = Vector2.ONE * hud_scale
	var scaled_button_size: Vector2 = inventory_button.size * hud_scale
	var right_margin: float = 38.0 * hud_scale
	var button_x: float = screen_size.x - scaled_button_size.x - right_margin
	inventory_button.position = Vector2(max(8.0, button_x), 88.0)


func setup_gem_counter():
	if ui_layer_ref == null:
		return
	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return
	gem_panel = hud_layer.get_node_or_null("GemPanel")
	if gem_panel == null and hud_layer != ui_layer_ref:
		gem_panel = ui_layer_ref.get_node_or_null("GemPanel")
	if gem_panel == null:
		gem_panel = Control.new()
		gem_panel.name = "GemPanel"
		hud_layer.add_child(gem_panel)
	elif gem_panel.get_parent() != hud_layer:
		var old_parent = gem_panel.get_parent()
		if old_parent != null:
			old_parent.remove_child(gem_panel)
		hud_layer.add_child(gem_panel)
	gem_panel.size = Vector2(232, 36)
	gem_panel.pivot_offset = gem_panel.size * 0.5
	gem_panel.z_index = 80
	gem_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_icon = gem_panel.get_node_or_null("GemIcon")
	if gem_icon == null:
		gem_icon = TextureRect.new()
		gem_icon.name = "GemIcon"
		gem_panel.add_child(gem_icon)
	gem_icon.position = Vector2(8, 3)
	gem_icon.size = Vector2(30, 30)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_count_label = gem_panel.get_node_or_null("GemCountLabel")
	if gem_count_label == null:
		gem_count_label = Label.new()
		gem_count_label.name = "GemCountLabel"
		gem_panel.add_child(gem_count_label)
	gem_count_label.position = Vector2(42, 4)
	gem_count_label.size = Vector2(182, 28)
	gem_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_count_label.add_theme_font_size_override("font_size", 18)
	gem_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	apply_gem_counter_shared_style()
	update_gem_counter_position()
	update_gem_counter()


func update_gem_counter_position():
	if gem_panel == null:
		return
	var counter_visible: bool = not is_floating_hud_blocked()
	gem_panel.visible = counter_visible
	if not counter_visible:
		return
	var screen_size = get_viewport_rect().size
	gem_panel.position = Vector2(
		max(8.0, screen_size.x - gem_panel.size.x - 16.0),
		max(8.0, screen_size.y - gem_panel.size.y - 16.0)
	)


func update_gem_counter():
	if world == null or gem_panel == null:
		return

	var gem_text: String = str(world.get_currency_display_text("gem"))
	var hud_text: String = "x" + gem_text
	var inventory_refresh_active: bool = is_inventory_window_refresh_active()

	# When the bag is closed and the gem count did not change, skip all UI writes.
	# This matters because _process() calls update_gem_counter() every frame.
	if not inventory_refresh_active and gem_counter_cached_display_text == gem_text:
		return
	gem_counter_cached_display_text = gem_text

	if gem_icon != null and world.currency_textures.has("gem"):
		var gem_texture: Texture2D = world.currency_textures["gem"] as Texture2D
		if gem_texture != null and gem_icon.texture != gem_texture:
			gem_icon.texture = gem_texture
	if gem_count_label != null and gem_count_label.text != hud_text:
		gem_count_label.text = hud_text

	if not inventory_refresh_active:
		return

	var header_gem_label = null
	if inventory_window != null:
		header_gem_label = inventory_window.get_node_or_null("HeaderGemLabel")
	if header_gem_label != null and header_gem_label is Label and header_gem_label.text != gem_text:
		header_gem_label.text = gem_text
	if is_inventory_scene_window() and inventory_window.has_method("set_gem_text"):
		inventory_window.set_gem_text(gem_text)


func control_screen_center(control_node) -> Vector2:
	var screen_center: Vector2 = PICKUP_TARGET_INVALID_SCREEN_POSITION
	if control_node != null and is_instance_valid(control_node) and control_node is Control:
		var rect: Rect2 = control_node.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			screen_center = rect.position + rect.size * 0.5
	return screen_center


func is_gem_pickup_target(item_type: String, category: String) -> bool:
	if world != null and world.has_method("is_gem_currency"):
		return bool(world.is_gem_currency(item_type, category))
	return item_type == "gem" and category == "currency"


func get_pickup_target_icon_control(slot) -> Control:
	if slot == null or not is_instance_valid(slot):
		return null
	if not (slot is Control):
		return null
	var icon = slot.get_node_or_null("Icon")
	if icon != null and icon is Control and icon.is_visible_in_tree():
		return icon
	var punch_icon = slot.get_node_or_null("PunchIcon")
	if punch_icon != null and punch_icon is Control and punch_icon.is_visible_in_tree():
		return punch_icon
	var wrench_icon = slot.get_node_or_null("WrenchIcon")
	if wrench_icon != null and wrench_icon is Control and wrench_icon.is_visible_in_tree():
		return wrench_icon
	return slot


func find_hotbar_pickup_target_control(item_type: String, category: String) -> Control:
	if world == null or hotbar_root == null or not hotbar_root.is_visible_in_tree():
		return null
	var hotbar_size = min(world.hotbar_items.size(), world.hotbar_item_categories.size())
	for i in range(hotbar_size):
		if str(world.hotbar_items[i]) != item_type:
			continue
		if str(world.hotbar_item_categories[i]) != category:
			continue
		if not hotbar_slots.has(i):
			continue
		var slot = hotbar_slots[i]
		if slot != null and is_instance_valid(slot) and slot is Control and slot.is_visible_in_tree():
			return get_pickup_target_icon_control(slot)
	return null


func find_inventory_pickup_target_control(item_type: String, category: String) -> Control:
	if not is_inventory_open():
		return null
	var slot = get_slot_for_item(item_type, category)
	if slot != null and is_instance_valid(slot) and slot is Control and slot.is_visible_in_tree():
		return get_pickup_target_icon_control(slot)
	if inventory_window != null and inventory_window.is_visible_in_tree():
		var grid_border = inventory_window.get_node_or_null("GridBorder")
		if grid_border != null and grid_border is Control and grid_border.is_visible_in_tree():
			return grid_border
		return inventory_window
	return null


func get_pickup_target_control(item_type: String, category: String) -> Control:
	if PICKUP_BULK_USE_GENERIC_TARGET and is_bulk_pickup_batch_active() and not is_gem_pickup_target(item_type, category):
		if hotbar_handle != null and is_instance_valid(hotbar_handle) and hotbar_handle is Control and hotbar_handle.is_visible_in_tree():
			return hotbar_handle
		if hotbar_root != null and is_instance_valid(hotbar_root) and hotbar_root is Control and hotbar_root.is_visible_in_tree():
			return hotbar_root

	if is_gem_pickup_target(item_type, category):
		if gem_icon != null and is_instance_valid(gem_icon) and gem_icon is Control and gem_icon.is_visible_in_tree():
			return gem_icon
		if gem_panel != null and is_instance_valid(gem_panel) and gem_panel is Control and gem_panel.is_visible_in_tree():
			return gem_panel

	var inventory_target = find_inventory_pickup_target_control(item_type, category)
	if inventory_target != null:
		return inventory_target

	var hotbar_target = find_hotbar_pickup_target_control(item_type, category)
	if hotbar_target != null:
		return hotbar_target

	if hotbar_handle != null and is_instance_valid(hotbar_handle) and hotbar_handle is Control and hotbar_handle.is_visible_in_tree():
		return hotbar_handle
	if hotbar_root != null and is_instance_valid(hotbar_root) and hotbar_root is Control and hotbar_root.is_visible_in_tree():
		return hotbar_root
	return null


func _get_cached_pickup_target_screen_position(cache_key: String):
	if not pickup_target_screen_cache.has(cache_key):
		return null
	var cached = pickup_target_screen_cache.get(cache_key, {})
	if not (cached is Dictionary):
		pickup_target_screen_cache.erase(cache_key)
		return null
	var expires_ms: int = int(cached.get("expires_ms", 0))
	if Time.get_ticks_msec() > expires_ms:
		pickup_target_screen_cache.erase(cache_key)
		return null
	var cached_screen_position = cached.get("position", null)
	return cached_screen_position if cached_screen_position is Vector2 else null


func clear_pickup_target_screen_cache() -> void:
	pickup_target_screen_cache.clear()


func get_pickup_target_screen_position(item_type: String, category: String, fallback_screen_position: Vector2 = PICKUP_TARGET_INVALID_SCREEN_POSITION) -> Vector2:
	var cache_key: String = get_inventory_slot_key(item_type, category)
	if PICKUP_BULK_USE_GENERIC_TARGET and is_bulk_pickup_batch_active() and not is_gem_pickup_target(item_type, category):
		cache_key = "bulk:generic_pickup_target"
	var cached_position = _get_cached_pickup_target_screen_position(cache_key)
	if cached_position is Vector2:
		return cached_position

	var target_control = get_pickup_target_control(item_type, category)
	if target_control == null:
		return fallback_screen_position
	var target_screen_position = control_screen_center(target_control)
	if abs(target_screen_position.x) >= 9.9e19 or abs(target_screen_position.y) >= 9.9e19:
		return fallback_screen_position
	pickup_target_screen_cache[cache_key] = {
		"position": target_screen_position,
		"expires_ms": Time.get_ticks_msec() + PICKUP_TARGET_CACHE_MS
	}
	return target_screen_position


func get_pickup_target_world_position(item_type: String, category: String, fallback_world_position: Vector2) -> Vector2:
	var viewport = get_inventory_viewport_safe()
	if viewport == null:
		return fallback_world_position
	var fallback_screen_position: Vector2 = viewport.get_canvas_transform() * fallback_world_position
	var target_screen_position: Vector2 = get_pickup_target_screen_position(item_type, category, fallback_screen_position)
	if abs(target_screen_position.x) >= 9.9e19 or abs(target_screen_position.y) >= 9.9e19:
		return fallback_world_position
	return viewport.get_canvas_transform().affine_inverse() * target_screen_position


func play_pickup_target_feedback(item_type: String, category: String) -> void:
	if not should_spawn_pickup_visual(item_type, category):
		return
	if is_gem_pickup_target(item_type, category):
		play_gem_counter_pickup_feedback()


func play_gem_counter_pickup_feedback() -> void:
	if gem_panel == null or not is_instance_valid(gem_panel):
		return
	var now_ms: int = Time.get_ticks_msec()
	if gem_counter_last_feedback_ms > 0 and now_ms - gem_counter_last_feedback_ms < GEM_COUNTER_FEEDBACK_MIN_INTERVAL_MS:
		return
	gem_counter_last_feedback_ms = now_ms
	apply_gem_counter_shared_style()
	gem_panel.pivot_offset = gem_panel.size * 0.5
	if gem_counter_feedback_tween != null:
		gem_counter_feedback_tween.kill()
	gem_panel.scale = Vector2.ONE

	var glow = gem_panel.get_node_or_null("GemPanelGlow")
	if glow != null and glow is ColorRect:
		glow.color = GEM_COUNTER_BASE_GLOW_COLOR

	gem_counter_feedback_tween = create_tween()
	gem_counter_feedback_tween.set_parallel(true)
	gem_counter_feedback_tween.tween_property(gem_panel, "scale", Vector2(1.10, 1.10), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gem_counter_feedback_tween.tween_property(gem_panel, "scale", Vector2(0.98, 0.98), 0.14).set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gem_counter_feedback_tween.tween_property(gem_panel, "scale", Vector2.ONE, 0.24).set_delay(0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if glow != null and glow is ColorRect:
		gem_counter_feedback_tween.tween_property(glow, "color", GEM_COUNTER_PICKUP_GLOW_COLOR, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		gem_counter_feedback_tween.tween_property(glow, "color", GEM_COUNTER_BASE_GLOW_COLOR, 0.46).set_delay(0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func is_floating_hud_blocked() -> bool:
	return false


func is_gameplay_hud_blocked() -> bool:
	return false


func update_inventory_ambient(delta: float):
	if inventory_window == null:
		return
	if inventory_drawer_amount <= 0.01 and inventory_drawer_target <= 0.01:
		return

	inventory_alive_time += delta
	var slow_pulse = 0.5 + 0.5 * sin(inventory_alive_time * 1.45)
	var soft_pulse = 0.5 + 0.5 * sin(inventory_alive_time * 0.82 + 1.2)

	var warm_glow = inventory_window.get_node_or_null("WarmGlow")
	if warm_glow != null and warm_glow is ColorRect:
		warm_glow.color = Color(0.62, 0.36, 1.0, 0.026 + slow_pulse * 0.020)

	var grid_warm_wash = inventory_window.get_node_or_null("GridWarmWash")
	if grid_warm_wash != null and grid_warm_wash is ColorRect:
		grid_warm_wash.color = Color(0.28, 0.72, 1.0, 0.022 + soft_pulse * 0.018)

	var grid_floor_glow = inventory_window.get_node_or_null("GridFloorGlow")
	if grid_floor_glow != null and grid_floor_glow is ColorRect:
		grid_floor_glow.color = Color(0.74, 0.44, 1.0, 0.032 + slow_pulse * 0.026)

	var header_accent = inventory_window.get_node_or_null("HeaderAccent")
	if header_accent != null and header_accent is ColorRect:
		header_accent.color = Color(0.44, 0.86, 1.0, 0.38 + slow_pulse * 0.18)


func is_inventory_scene_window() -> bool:
	return inventory_window != null and is_instance_valid(inventory_window) and inventory_window.has_method("set_inventory_from_world")


func setup_inventory_scene_window() -> bool:
	if ui_layer_ref == null:
		return false

	var existing_window: Node = ui_layer_ref.get_node_or_null("InventoryWindow")
	if existing_window != null and not existing_window.has_method("set_inventory_from_world"):
		ui_layer_ref.remove_child(existing_window)
		existing_window.queue_free()
		existing_window = null

	if existing_window == null:
		inventory_window = INVENTORY_SCENE.instantiate()
		inventory_window.name = "InventoryWindow"
		ui_layer_ref.add_child(inventory_window)
	else:
		inventory_window = existing_window

	if not (inventory_window is Control):
		return false

	var window_control: Control = inventory_window as Control
	window_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_control.offset_left = 0.0
	window_control.offset_top = 0.0
	window_control.offset_right = 0.0
	window_control.offset_bottom = 0.0
	window_control.position = Vector2.ZERO
	window_control.visible = inventory_drawer_target > 0.05 or inventory_drawer_amount > 0.05
	window_control.z_index = INVENTORY_WINDOW_Z_INDEX
	window_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window_layout_size = get_inventory_viewport_size()

	inventory_slots.clear()
	inventory_tab_buttons.clear()
	inventory_scroll_container = inventory_window.get_node_or_null("Window/InventoryScroll")
	inventory_grid_root = inventory_window.get_node_or_null("Window/InventoryScroll/InventoryGrid")
	inventory_tab_root = inventory_window.get_node_or_null("Window/Tabs")
	inventory_detail_panel = inventory_window.get_node_or_null("Window/DetailSkin")
	inventory_search_input = inventory_window.get_node_or_null("Window/SearchInput")
	item_context_menu = null
	context_amount_input = inventory_window.get_node_or_null("Window/DropAmountInput")
	context_amount_slider = inventory_window.get_node_or_null("Window/DropAmountSlider")

	connect_inventory_scene_signals()
	refresh_inventory_scene_window()
	return true


func connect_inventory_scene_signals() -> void:
	if not is_inventory_scene_window():
		return

	var item_selected_callback: Callable = Callable(self, "_on_inventory_scene_item_selected")
	if not inventory_window.item_selected.is_connected(item_selected_callback):
		inventory_window.item_selected.connect(item_selected_callback)

	var item_double_action_callback: Callable = Callable(self, "_on_inventory_scene_item_double_action_requested")
	if not inventory_window.item_double_action_requested.is_connected(item_double_action_callback):
		inventory_window.item_double_action_requested.connect(item_double_action_callback)

	var primary_callback: Callable = Callable(self, "_on_inventory_scene_primary_action_requested")
	if not inventory_window.primary_action_requested.is_connected(primary_callback):
		inventory_window.primary_action_requested.connect(primary_callback)

	var drop_callback: Callable = Callable(self, "_on_inventory_scene_drop_requested")
	if not inventory_window.drop_requested.is_connected(drop_callback):
		inventory_window.drop_requested.connect(drop_callback)

	var info_callback: Callable = Callable(self, "_on_inventory_scene_info_requested")
	if not inventory_window.info_requested.is_connected(info_callback):
		inventory_window.info_requested.connect(info_callback)

	var trash_callback: Callable = Callable(self, "_on_inventory_scene_trash_requested")
	if not inventory_window.trash_requested.is_connected(trash_callback):
		inventory_window.trash_requested.connect(trash_callback)

	var popup_callback: Callable = Callable(self, "_on_inventory_scene_item_action_popup_requested")
	if inventory_window.has_signal("item_action_popup_requested") and not inventory_window.item_action_popup_requested.is_connected(popup_callback):
		inventory_window.item_action_popup_requested.connect(popup_callback)

	var upgrade_callback: Callable = Callable(self, "_on_inventory_scene_inventory_upgrade_requested")
	if inventory_window.has_signal("inventory_upgrade_requested") and not inventory_window.inventory_upgrade_requested.is_connected(upgrade_callback):
		inventory_window.inventory_upgrade_requested.connect(upgrade_callback)

	var close_callback: Callable = Callable(self, "_on_inventory_scene_close_requested")
	if not inventory_window.close_requested.is_connected(close_callback):
		inventory_window.close_requested.connect(close_callback)

	var tab_callback: Callable = Callable(self, "_on_inventory_scene_tab_changed")
	if not inventory_window.tab_changed.is_connected(tab_callback):
		inventory_window.tab_changed.connect(tab_callback)


func _append_inventory_scene_signature_parts(parts: Array, property_name: String, category: String) -> void:
	if world == null:
		return
	var inventory_value: Variant = world.get(property_name)
	if not (inventory_value is Dictionary):
		return
	var inventory: Dictionary = inventory_value
	var item_keys: Array = inventory.keys()
	item_keys.sort()
	for raw_item_id in item_keys:
		var item_id: String = str(raw_item_id)
		if world.item_database.has(item_id) and bool(world.item_database[item_id].get("hidden", false)):
			continue
		var count: int = get_item_count(item_id, category)
		if count <= 0:
			continue
		parts.append(category + ":" + item_id)


func get_inventory_scene_signature() -> String:
	var parts: Array = []
	if world != null and world.has_method("get_inventory_slot_count"):
		parts.append("inventory_slots:" + str(world.get_inventory_slot_count()))
	_append_inventory_scene_signature_parts(parts, "inventory", "block")
	_append_inventory_scene_signature_parts(parts, "seed_inventory", "seed")
	_append_inventory_scene_signature_parts(parts, "tool_inventory", "tool")
	_append_inventory_scene_signature_parts(parts, "material_inventory", "material")
	_append_inventory_scene_signature_parts(parts, "lure_inventory", "lure")
	_append_inventory_scene_signature_parts(parts, "fish_inventory", "fish")
	_append_inventory_scene_signature_parts(parts, "back_inventory", "back")
	_append_inventory_scene_signature_parts(parts, "hat_inventory", "hat")
	_append_inventory_scene_signature_parts(parts, "hair_inventory", "hair")
	_append_inventory_scene_signature_parts(parts, "eyewear_inventory", "eyewear")
	_append_inventory_scene_signature_parts(parts, "shirt_inventory", "shirt")
	_append_inventory_scene_signature_parts(parts, "pants_inventory", "pants")
	_append_inventory_scene_signature_parts(parts, "shoes_inventory", "shoes")
	_append_inventory_scene_signature_parts(parts, "ride_inventory", "ride")

	var signature := ""
	for part in parts:
		signature += str(part) + "\n"
	return signature


func get_inventory_primary_action_text() -> String:
	if vend_select_active:
		return "ADD TO VENDING"
	if safe_select_active:
		return "ADD TO SAFE"
	if donation_box_select_active:
		return "DONATE"
	if display_select_active:
		return "DISPLAY ITEM"
	if oil_refinery_battery_select_active:
		return "ADD BATTERY"
	if trade_select_active:
		return "ADD TO TRADE"
	return "USE"


func refresh_inventory_scene_chrome() -> void:
	if not is_inventory_scene_window() or world == null:
		return

	if inventory_window.has_method("set_primary_action_text"):
		inventory_window.set_primary_action_text(get_inventory_primary_action_text())

	if inventory_window.has_method("set_selected_item"):
		var selected_type: String = str(world.selected_item_type)
		var selected_category: String = str(world.selected_item_category)
		if is_item_selection_mode_active() and inventory_detail_item_type != "" and inventory_detail_item_category != "":
			selected_type = inventory_detail_item_type
			selected_category = inventory_detail_item_category
		if selected_type != "" and selected_category != "":
			inventory_window.set_selected_item(selected_type, selected_category)

	if inventory_window.has_method("set_gem_text") and world.has_method("get_currency_display_text"):
		inventory_window.set_gem_text(world.get_currency_display_text("gem"))
	elif inventory_window.has_method("set_gem_count"):
		inventory_window.set_gem_count(get_item_count("gem", "currency"))


func refresh_inventory_scene_window(force_rebuild: bool = false) -> void:
	if not is_inventory_scene_window() or world == null:
		return

	var next_signature: String = get_inventory_scene_signature()
	var refreshed_all_slots := false
	if force_rebuild or inventory_window_structure_dirty or not inventory_window_live_cache_valid or next_signature != inventory_scene_cache_signature:
		inventory_window.set_inventory_from_world(world)
		inventory_scene_cache_signature = next_signature
		refreshed_all_slots = true
	elif inventory_window.has_method("refresh_live_from_world") and not bool(inventory_window.refresh_live_from_world(world)):
		inventory_window.set_inventory_from_world(world)
		inventory_scene_cache_signature = get_inventory_scene_signature()
		refreshed_all_slots = true

	refresh_inventory_scene_chrome()
	if refreshed_all_slots:
		_clear_inventory_slot_dirty_queue()
	inventory_window_structure_dirty = false
	inventory_window_live_cache_valid = true


func _get_inventory_scene_item_type(item: Dictionary) -> String:
	return str(item.get("id", item.get("item_type", item.get("type", ""))))


func _get_inventory_scene_item_category(item: Dictionary) -> String:
	return str(item.get("category", item.get("item_category", "")))


func _get_inventory_scene_item_amount(item: Dictionary) -> float:
	var raw_amount: Variant = item.get("amount", item.get("drop_amount", 1))
	if raw_amount is int:
		return float(raw_amount)
	if raw_amount is float:
		return float(raw_amount)
	if raw_amount is String:
		var amount_text: String = str(raw_amount).strip_edges()
		if amount_text.is_valid_float():
			return float(amount_text)
	return 0.0


func _get_inventory_scene_stack_amount(item_type: String, category: String, item: Dictionary) -> int:
	var amount: int = int(round(_get_inventory_scene_item_amount(item)))
	var available: int = get_item_count(item_type, category)
	return clampi(amount, 0, max(0, available))


func _store_inventory_scene_detail_item(item_type: String, category: String) -> void:
	inventory_detail_item_type = item_type
	inventory_detail_item_category = category
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = null


func _can_inventory_scene_select_item(item_type: String, category: String) -> bool:
	return can_select_item_for_active_mode(item_type, category)


func _select_inventory_scene_item_for_gameplay(item_type: String, category: String) -> void:
	_store_inventory_scene_detail_item(item_type, category)
	assign_item_to_quick_hotbar(item_type, category)
	if world != null:
		world.select_item(item_type, category)
	refresh_hotbar_live()


func _on_inventory_scene_item_selected(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "":
		return

	if is_item_selection_mode_active():
		if not _can_inventory_scene_select_item(item_type, category):
			if world != null and world.has_method("show_notification"):
				world.show_notification("That item cannot be selected.")
			return
		_store_inventory_scene_detail_item(item_type, category)
		return

	_select_inventory_scene_item_for_gameplay(item_type, category)


func _on_inventory_scene_item_double_action_requested(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "":
		return
	if is_item_selection_mode_active():
		return

	if try_convert_world_lock_stack(item_type, category):
		return

	_select_inventory_scene_item_for_gameplay(item_type, category)
	if world != null and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
		world.toggle_equip_item(item_type, category)
		refresh_inventory_scene_window()
		update_hotbar()


func _on_inventory_scene_primary_action_requested(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "":
		return

	var stack_amount: int = max(1, _get_inventory_scene_stack_amount(item_type, category, item))
	if is_item_selection_mode_active():
		if not _can_inventory_scene_select_item(item_type, category):
			if world != null and world.has_method("show_notification"):
				world.show_notification("That item cannot be selected.")
			return
		if vend_select_active:
			add_context_item_to_vend(item_type, category, stack_amount)
		elif safe_select_active:
			add_context_item_to_safe(item_type, category, stack_amount)
		elif donation_box_select_active:
			add_context_item_to_donation_box(item_type, category, stack_amount)
		elif display_select_active:
			add_context_item_to_display(item_type, category)
		elif oil_refinery_battery_select_active:
			add_context_item_to_oil_refinery_battery(item_type, category, stack_amount)
		else:
			add_context_item_to_trade(item_type, category, stack_amount)
		refresh_inventory_scene_window()
		update_hotbar()
		return

	_select_inventory_scene_item_for_gameplay(item_type, category)
	if world != null and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
		world.toggle_equip_item(item_type, category)
	refresh_inventory_scene_window()


func _on_inventory_scene_drop_requested(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	var stack_amount: int = _get_inventory_scene_stack_amount(item_type, category, item)
	if item_type == "" or category == "":
		return
	if stack_amount <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose at least 1 item.")
		return
	drop_inventory_item(item_type, category, float(stack_amount))


func _on_inventory_scene_info_requested(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "":
		return
	show_item_info(item_type, category)


func _on_inventory_scene_trash_requested(item: Dictionary) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	var stack_amount: int = _get_inventory_scene_stack_amount(item_type, category, item)
	if item_type == "" or category == "":
		return
	if stack_amount <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose at least 1 item.")
		return
	trash_inventory_item(item_type, category, float(stack_amount))


func _on_inventory_scene_item_action_popup_requested(item: Dictionary, screen_position: Vector2) -> void:
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "":
		return
	if is_item_selection_mode_active() and not _can_inventory_scene_select_item(item_type, category):
		if world != null and world.has_method("show_notification"):
			world.show_notification("That item cannot be selected.")
		return
	_show_item_action_popup(_build_item_action_payload(item_type, category, item), screen_position)


func _ensure_item_action_popup() -> Control:
	if item_action_popup != null and is_instance_valid(item_action_popup):
		return item_action_popup as Control
	if ui_layer_ref == null:
		return null

	item_action_popup = ITEM_ACTION_POPUP_SCENE.instantiate()
	item_action_popup.name = "ItemActionPopup"
	ui_layer_ref.add_child(item_action_popup)
	if item_action_popup is Control:
		var popup_control: Control = item_action_popup as Control
		popup_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		popup_control.offset_left = 0.0
		popup_control.offset_top = 0.0
		popup_control.offset_right = 0.0
		popup_control.offset_bottom = 0.0
		popup_control.z_index = ITEM_ACTION_POPUP_Z_INDEX

	_connect_item_action_popup_signal("use_requested", "_on_inventory_scene_primary_action_requested")
	_connect_item_action_popup_signal("drop_requested", "_on_inventory_scene_drop_requested")
	_connect_item_action_popup_signal("info_requested", "_on_inventory_scene_info_requested")
	_connect_item_action_popup_signal("trash_requested", "_on_inventory_scene_trash_requested")
	_connect_item_action_popup_signal("closed", "_on_item_action_popup_closed")
	return item_action_popup as Control


func _connect_item_action_popup_signal(signal_name: StringName, method_name: StringName) -> void:
	if item_action_popup == null or not item_action_popup.has_signal(signal_name):
		return
	var callback: Callable = Callable(self, method_name)
	if not item_action_popup.is_connected(signal_name, callback):
		item_action_popup.connect(signal_name, callback)


func _on_item_action_popup_closed() -> void:
	cancel_item_hold()


func _build_item_action_payload(item_type: String, category: String, base_item: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = base_item.duplicate(true)
	var available_count: int = get_item_count(item_type, category)
	if is_reserved_hotbar_tool(item_type, category):
		available_count = maxi(1, available_count)
	var database_entry: Dictionary = {}
	if world != null and world.item_database.has(item_type) and world.item_database[item_type] is Dictionary:
		database_entry = world.item_database[item_type]
	payload["id"] = item_type
	payload["type"] = item_type
	payload["item_type"] = item_type
	payload["category"] = category
	payload["item_category"] = category
	payload["type_label"] = category
	payload["display_name"] = get_item_display_name(item_type, category)
	payload["count"] = maxi(1, available_count)
	payload["available_count"] = maxi(1, available_count)
	payload["rarity"] = get_item_rarity(item_type, category)
	payload["description"] = str(payload.get("description", database_entry.get("description", "")))
	payload["spliceable"] = bool(payload.get("spliceable", false)) \
		or str(database_entry.get("seed", "")).strip_edges() != "" \
		or database_entry.has("recipe")
	payload["can_use"] = true
	payload["can_drop"] = can_drop_item_from_inventory(item_type, category)
	payload["can_trash"] = item_type != "punch"
	return payload


func _show_item_action_popup(item: Dictionary, screen_position: Vector2 = Vector2.ZERO) -> void:
	var popup: Control = _ensure_item_action_popup()
	if popup == null:
		return
	var item_type: String = _get_inventory_scene_item_type(item)
	var category: String = _get_inventory_scene_item_category(item)
	if item_type == "" or category == "" or category == "empty":
		return
	if get_item_count(item_type, category) <= 0 and not is_reserved_hotbar_tool(item_type, category):
		return
	hold_item_type = item_type
	hold_item_category = category
	if popup.has_method("open_popup"):
		popup.open_popup(item, get_item_texture(item_type, category), screen_position)
	else:
		popup.visible = true


func _item_context_anchor_position(slot) -> Vector2:
	if slot is Vector2:
		return slot as Vector2
	if slot is Control and is_instance_valid(slot):
		return (slot as Control).get_global_rect().get_center()
	return Vector2.ZERO


func _on_inventory_scene_inventory_upgrade_requested(upgrade_data: Dictionary) -> void:
	show_inventory_upgrade_popup(upgrade_data)


func _get_inventory_upgrade_preview(upgrade_data: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = upgrade_data.duplicate(true)
	if world != null and world.has_method("get_inventory_upgrade_preview"):
		var source_preview: Variant = world.get_inventory_upgrade_preview()
		if source_preview is Dictionary:
			preview = source_preview.duplicate(true)
	return preview


func show_inventory_upgrade_popup(upgrade_data: Dictionary = {}) -> void:
	if ui_layer_ref == null:
		return
	var preview: Dictionary = _get_inventory_upgrade_preview(upgrade_data)
	var current_slots: int = int(preview.get("current_slots", preview.get("inventory_slot_count", 20)))
	var max_slots: int = int(preview.get("max_slots", 300))
	if current_slots >= max_slots:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Inventory is already fully upgraded.")
		return

	var popup: Control = _ensure_inventory_upgrade_popup()
	if popup == null:
		return
	if popup.has_method("open"):
		popup.open(preview)
	else:
		popup.visible = true


func _ensure_inventory_upgrade_popup() -> Control:
	if inventory_upgrade_popup != null and is_instance_valid(inventory_upgrade_popup):
		return inventory_upgrade_popup as Control
	if ui_layer_ref == null:
		return null

	inventory_upgrade_popup = INVENTORY_UPGRADE_CONFIRM_SCENE.instantiate()
	inventory_upgrade_popup.name = "InventoryUpgradeConfirm"
	ui_layer_ref.add_child(inventory_upgrade_popup)
	if inventory_upgrade_popup is Control:
		var popup_control: Control = inventory_upgrade_popup as Control
		popup_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		popup_control.offset_left = 0.0
		popup_control.offset_top = 0.0
		popup_control.offset_right = 0.0
		popup_control.offset_bottom = 0.0
		popup_control.z_index = INVENTORY_MODAL_Z_INDEX

	var confirmed_callback := Callable(self, "_on_inventory_upgrade_popup_confirmed")
	if inventory_upgrade_popup.has_signal("confirmed") and not inventory_upgrade_popup.confirmed.is_connected(confirmed_callback):
		inventory_upgrade_popup.confirmed.connect(confirmed_callback)

	var cancelled_callback := Callable(self, "_on_inventory_upgrade_popup_cancelled")
	if inventory_upgrade_popup.has_signal("cancelled") and not inventory_upgrade_popup.cancelled.is_connected(cancelled_callback):
		inventory_upgrade_popup.cancelled.connect(cancelled_callback)
	if inventory_upgrade_popup.has_signal("close_requested") and not inventory_upgrade_popup.close_requested.is_connected(cancelled_callback):
		inventory_upgrade_popup.close_requested.connect(cancelled_callback)

	return inventory_upgrade_popup as Control


func _on_inventory_upgrade_popup_confirmed(_upgrade_data: Dictionary = {}) -> void:
	if world == null or not world.has_method("request_inventory_slot_upgrade"):
		return
	world.request_inventory_slot_upgrade()


func _on_inventory_upgrade_popup_cancelled() -> void:
	pass


func _on_inventory_scene_close_requested() -> void:
	close_inventory_window()


func _on_inventory_scene_tab_changed(tab_id: String) -> void:
	inventory_tab = "back" if tab_id == "gear" else tab_id


func setup_inventory_window():
	if setup_inventory_scene_window():
		return
	if ui_layer_ref == null:
		return
	inventory_window = ui_layer_ref.get_node_or_null("InventoryWindow")
	if inventory_window == null:
		inventory_window = ColorRect.new()
		inventory_window.name = "InventoryWindow"
		ui_layer_ref.add_child(inventory_window)

	var screen_size = get_inventory_viewport_size()
	var window_size = get_inventory_window_size_for_viewport(screen_size)
	inventory_window_layout_size = screen_size
	inventory_window.size = window_size
	inventory_window.color = Color(0.000, 0.004, 0.010, 0.00)
	inventory_window.visible = true
	inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
	inventory_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not inventory_window.gui_input.is_connected(_on_inventory_window_gui_input):
		inventory_window.gui_input.connect(_on_inventory_window_gui_input)

	for child in inventory_window.get_children():
		child.queue_free()
	inventory_slots.clear()
	inventory_tab_buttons.clear()
	inventory_scroll_container = null
	inventory_tab_root = null
	inventory_detail_panel = null

	var using_inventory_kit = false
	var margin_x = get_inventory_margin_x(window_size)
	var content_width = max(420.0, window_size.x - margin_x * 2.0)
	var tool_y = INVENTORY_HEADER_HEIGHT + (16.0 if using_inventory_kit else 8.0)
	var nav_y = tool_y + (50.0 if using_inventory_kit else 40.0)
	var grid_y = nav_y + INVENTORY_NAV_HEIGHT + (18.0 if using_inventory_kit else 12.0)
	if window_size.y < 500.0:
		tool_y = INVENTORY_HEADER_HEIGHT + 4.0
		nav_y = tool_y + 36.0
		grid_y = nav_y + INVENTORY_NAV_HEIGHT + 8.0
	var grid_height = max(220.0 if using_inventory_kit else 190.0, window_size.y - grid_y - (32.0 if using_inventory_kit else 24.0))
	var detail_width = 300.0 if using_inventory_kit and content_width >= 860.0 else (264.0 if content_width >= 820.0 else 0.0)
	var detail_gap = (18.0 if using_inventory_kit else 16.0) if detail_width > 0.0 else 0.0
	var grid_content_width = content_width - detail_width - detail_gap

	var far_shadow = Panel.new()
	far_shadow.name = "FarShadow"
	far_shadow.position = Vector2(16, 18)
	far_shadow.size = inventory_window.size
	far_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(far_shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = inventory_window.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(panel_back)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(7, 7)
	shadow.size = inventory_window.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(shadow)

	var border = Panel.new()
	border.name = "Border"
	border.position = Vector2(0, 0)
	border.size = inventory_window.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(border)

	var main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.position = Vector2(8, 8)
	main_panel.size = inventory_window.size - Vector2(16, 16)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(main_panel)

	var outer_highlight = Panel.new()
	outer_highlight.name = "OuterHighlight"
	outer_highlight.position = Vector2(7, 7)
	outer_highlight.size = inventory_window.size - Vector2(14, 14)
	outer_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(outer_highlight)

	var warm_glow = ColorRect.new()
	warm_glow.name = "WarmGlow"
	warm_glow.position = Vector2(margin_x, grid_y - 10.0)
	warm_glow.size = Vector2(content_width, grid_height + 22.0)
	warm_glow.color = Color(0.62, 0.36, 1.0, 0.035)
	warm_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(warm_glow)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(8, 8)
	top_bar.size = Vector2(window_size.x - 16.0, INVENTORY_HEADER_HEIGHT - 8.0)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(top_bar)

	var header_gloss = ColorRect.new()
	header_gloss.name = "HeaderGloss"
	header_gloss.position = Vector2(margin_x + 2.0, 18)
	header_gloss.size = Vector2(content_width - 4.0, 18)
	header_gloss.color = Color(0.78, 0.94, 1.0, 0.08)
	header_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(header_gloss)

	var header_spark = ColorRect.new()
	header_spark.name = "HeaderSpark"
	header_spark.position = Vector2(margin_x + 4.0, 17)
	header_spark.size = Vector2(content_width - 8.0, 2)
	header_spark.color = Color(0.78, 0.96, 1.0, 0.32)
	header_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(header_spark)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(12, INVENTORY_HEADER_HEIGHT - 6.0)
	top_line.size = Vector2(window_size.x - 24.0, 4)
	top_line.color = Color(0.28, 0.62, 1.0, 0.54)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(top_line)

	var header_accent = ColorRect.new()
	header_accent.name = "HeaderAccent"
	header_accent.position = Vector2(margin_x, INVENTORY_HEADER_HEIGHT - 1.0)
	header_accent.size = Vector2(content_width, 3)
	header_accent.color = Color(0.44, 0.86, 1.0, 0.42)
	header_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(header_accent)

	var title = Label.new()
	title.name = "Title"
	title.text = "BAG"
	title.position = Vector2(margin_x, 12)
	title.size = Vector2(min(360.0, window_size.x * 0.38), 58)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 54 if window_size.x >= 1000.0 else 42)
	inventory_window.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = ""
	title_sub.position = Vector2(margin_x + 6.0, 60)
	title_sub.size = Vector2(210, 22)
	title_sub.visible = false
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	inventory_window.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(window_size.x - margin_x - close_button.size.x, 20)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_inventory_window)
	inventory_window.add_child(close_button)

	var chip_width = 276.0 if window_size.x >= 960.0 else 236.0
	var header_gem_chip = Panel.new()
	header_gem_chip.name = "HeaderGemChip"
	header_gem_chip.position = Vector2(close_button.position.x - chip_width - 14.0, 20)
	header_gem_chip.size = Vector2(chip_width, 48)
	header_gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_gem_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_INPUT,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 14, 8
	))
	inventory_window.add_child(header_gem_chip)

	var header_gem_icon = TextureRect.new()
	header_gem_icon.name = "HeaderGemIcon"
	header_gem_icon.position = header_gem_chip.position + Vector2(12, 6)
	header_gem_icon.size = Vector2(36, 36)
	header_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		header_gem_icon.texture = world.currency_textures["gem"]
	inventory_window.add_child(header_gem_icon)

	var header_gem_label = Label.new()
	header_gem_label.name = "HeaderGemLabel"
	header_gem_label.position = header_gem_chip.position + Vector2(56, 7)
	header_gem_label.size = Vector2(chip_width - 72.0, 28)
	header_gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(header_gem_label, 22, Color(1.0, 1.0, 1.0, 1.0))
	inventory_window.add_child(header_gem_label)

	var inventory_word = Label.new()
	inventory_word.name = "InventoryWord"
	inventory_word.text = ""
	inventory_word.position = Vector2(max(margin_x, header_gem_chip.position.x - 162.0), 20)
	inventory_word.size = Vector2(150, 34)
	inventory_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_word.visible = false
	PixelUIStyle.apply_label_shadow(inventory_word, 24)
	inventory_window.add_child(inventory_word)

	var search_width = min(360.0, max(220.0, content_width * 0.36))
	if content_width < 760.0:
		search_width = content_width
	inventory_search_input = LineEdit.new()
	inventory_search_input.name = "SearchInput"
	inventory_search_input.placeholder_text = "Search items..."
	inventory_search_input.position = Vector2(margin_x, tool_y)
	inventory_search_input.size = Vector2(search_width, 38.0 if using_inventory_kit else 34.0)
	inventory_search_input.text = inventory_search_text
	inventory_search_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_arcade_search_style(inventory_search_input)
	if not inventory_search_input.text_changed.is_connected(_on_inventory_search_changed):
		inventory_search_input.text_changed.connect(_on_inventory_search_changed)
	inventory_window.add_child(inventory_search_input)

	var selected_panel = Panel.new()
	selected_panel.name = "SelectedPanel"
	selected_panel.position = Vector2(margin_x + search_width + 14.0, tool_y - 1.0)
	selected_panel.size = Vector2(max(0.0, content_width - search_width - 14.0), 38.0 if using_inventory_kit else 36.0)
	if content_width < 760.0:
		selected_panel.visible = false
	selected_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(selected_panel)

	var selected_label = Label.new()
	selected_label.name = "SelectedLabel"
	selected_label.position = selected_panel.position + Vector2(12, 8)
	selected_label.size = Vector2(max(0.0, selected_panel.size.x - 24.0), 22)
	selected_label.clip_text = true
	selected_label.visible = selected_panel.visible
	selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(selected_label, 13)
	inventory_window.add_child(selected_label)

	var category_nav_back = Panel.new()
	category_nav_back.name = "CategoryNavBack"
	category_nav_back.position = Vector2(margin_x, nav_y - (4.0 if using_inventory_kit else 8.0))
	category_nav_back.size = Vector2(content_width, INVENTORY_NAV_HEIGHT + (8.0 if using_inventory_kit else 14.0))
	category_nav_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(category_nav_back)

	var category_panel = Panel.new()
	category_panel.name = "CategoryPanel"
	category_panel.position = Vector2(margin_x, nav_y)
	category_panel.size = Vector2(content_width, INVENTORY_NAV_HEIGHT)
	category_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(category_panel)

	inventory_tab_root = category_panel
	var tab_items = [
		["all", "ALL"],
		["blocks", "BLOCKS"],
		["seeds", "SEEDS"],
		["tools", "TOOLS"],
		["materials", "LOOT"],
		["back", "GEAR"]
	]
	var tab_count = float(max(1, tab_items.size()))
	var tab_gap = 10.0 if using_inventory_kit else 8.0
	var left_pad = 10.0
	var right_pad = 10.0
	var tab_height = 38.0
	var raw_tab_w = (category_panel.size.x - left_pad - right_pad - (tab_gap * float(tab_items.size() - 1))) / tab_count
	var min_tab_width = 86.0
	if category_panel.size.x < 760.0:
		min_tab_width = 70.0
	if category_panel.size.x < 560.0:
		min_tab_width = 58.0
	var tab_width = clamp(raw_tab_w, min_tab_width, 172.0)
	var tab_x = left_pad
	for tab_data in tab_items:
		var tab_size = Vector2(tab_width, tab_height)
		create_inventory_tab_button(tab_data[0], tab_data[1], Vector2(tab_x, 3), tab_size)
		tab_x += tab_width + tab_gap

	var grid_pad = 20.0 if using_inventory_kit else 14.0
	var grid_border = Panel.new()
	grid_border.name = "GridBorder"
	grid_border.position = Vector2(margin_x, grid_y)
	grid_border.size = Vector2(grid_content_width, grid_height)
	grid_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(grid_border)

	var grid_panel = Panel.new()
	grid_panel.name = "GridPanel"
	grid_panel.position = Vector2(margin_x + 8.0, grid_y + 8.0)
	grid_panel.size = Vector2(grid_content_width - 16.0, grid_height - 16.0)
	grid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(grid_panel)

	var grid_warm_wash = ColorRect.new()
	grid_warm_wash.name = "GridWarmWash"
	grid_warm_wash.position = Vector2(margin_x + 8.0, grid_y + 8.0)
	grid_warm_wash.size = Vector2(grid_content_width - 16.0, grid_height - 16.0)
	grid_warm_wash.color = Color(0.26, 0.72, 1.0, 0.024)
	grid_warm_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(grid_warm_wash)

	var grid_floor_glow = ColorRect.new()
	grid_floor_glow.name = "GridFloorGlow"
	grid_floor_glow.position = Vector2(margin_x + 8.0, grid_y + grid_height - 34.0)
	grid_floor_glow.size = Vector2(grid_content_width - 16.0, 26)
	grid_floor_glow.color = Color(0.74, 0.44, 1.0, 0.038)
	grid_floor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_window.add_child(grid_floor_glow)

	inventory_scroll_container = ScrollContainer.new()
	inventory_scroll_container.name = "InventoryScroll"
	inventory_scroll_container.position = Vector2(margin_x + grid_pad, grid_y + grid_pad)
	inventory_scroll_container.size = Vector2(grid_content_width - grid_pad * 2.0, grid_height - grid_pad * 2.0)
	inventory_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	inventory_scroll_container.clip_contents = true
	inventory_window.add_child(inventory_scroll_container)
	apply_arcade_scrollbar_style()

	if detail_width > 0.0:
		create_inventory_detail_panel(Vector2(margin_x + grid_content_width + detail_gap, grid_y), Vector2(detail_width, grid_height))

	inventory_grid_root = Control.new()
	inventory_grid_root.name = "InventoryGrid"
	inventory_grid_root.position = Vector2.ZERO
	var safe_grid_size = get_inventory_grid_view_size()
	inventory_grid_root.size = safe_grid_size
	inventory_grid_root.custom_minimum_size = safe_grid_size
	inventory_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_scroll_container.add_child(inventory_grid_root)
	create_inventory_grid_slots()
	apply_shared_inventory_style()
	update_inventory_window_position()
	update_inventory_window()


func get_item_description(item_type: String, category: String) -> String:
	if world != null and world.item_database.has(item_type):
		var item_data = world.item_database[item_type]
		for field_name in ["description", "tooltip", "info"]:
			var value = str(item_data.get(field_name, ""))
			if value != "":
				return value

	match category:
		"block":
			return "A placeable world block."
		"seed":
			return "Plant or splice this seed."
		"tool":
			return "A usable tool."
		"material":
			return "A crafting material."
		"lure":
			return "Used for fishing."
		"fish":
			return "A caught fish."
		"currency":
			return "A currency item."
		"back", "hat", "hair", "eyewear", "shirt", "pants", "shoes", "ride":
			return "Wearable equipment."
		_:
			return "Inventory item."


func create_inventory_detail_panel(panel_position: Vector2, panel_size: Vector2):
	inventory_detail_panel = Panel.new()
	inventory_detail_panel.name = "DetailPanel"
	inventory_detail_panel.position = panel_position
	inventory_detail_panel.size = panel_size
	inventory_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_detail_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.060, 0.135, 0.200, 0.42),
		Color(0.40, 0.78, 1.0, 0.54),
		3, 13, 5
	))
	inventory_window.add_child(inventory_detail_panel)

	var title = Label.new()
	title.name = "DetailTitle"
	title.text = "ITEM DETAILS"
	title.position = Vector2(14, 8)
	title.size = Vector2(panel_size.x - 28.0, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title, 12)
	inventory_detail_panel.add_child(title)

	var empty = Label.new()
	empty.name = "DetailEmpty"
	empty.text = "Click an item\nto view details"
	empty.position = Vector2(24, panel_size.y * 0.48)
	empty.size = Vector2(panel_size.x - 48.0, 54)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(empty, 15)
	inventory_detail_panel.add_child(empty)

	var preview_size = 78.0
	var preview_y = 32.0
	var name_y = preview_y + preview_size + 8.0
	var meta_y = name_y + 24.0
	var description_y = meta_y + 22.0
	var amount_row_y = description_y + 36.0
	var slider_y = amount_row_y + 34.0
	var button_height = 34.0
	var button_gap = 8.0
	var button_row_2_y = panel_size.y - 10.0 - button_height
	var button_row_1_y = button_row_2_y - button_gap - button_height
	var split_button_gap = 10.0
	var split_button_width = (panel_size.x - 32.0 - split_button_gap) * 0.5

	var preview_back = Panel.new()
	preview_back.name = "DetailPreviewBack"
	preview_back.position = Vector2((panel_size.x - preview_size) * 0.5, preview_y)
	preview_back.size = Vector2(preview_size, preview_size)
	preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_detail_panel.add_child(preview_back)

	var preview_glow = ColorRect.new()
	preview_glow.name = "DetailPreviewGlow"
	preview_glow.position = preview_back.position + Vector2(8, 8)
	preview_glow.size = preview_back.size - Vector2(16, 16)
	preview_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_detail_panel.add_child(preview_glow)

	var icon_shadow = TextureRect.new()
	icon_shadow.name = "DetailIconShadow"
	icon_shadow.position = preview_back.position + Vector2(19, 22)
	icon_shadow.size = Vector2(52, 48)
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.modulate = Color(0, 0, 0, 0.34)
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_detail_panel.add_child(icon_shadow)

	var icon = TextureRect.new()
	icon.name = "DetailIcon"
	icon.position = preview_back.position + Vector2(15, 15)
	icon.size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_detail_panel.add_child(icon)

	var name_label = Label.new()
	name_label.name = "DetailName"
	name_label.position = Vector2(14, name_y)
	name_label.size = Vector2(panel_size.x - 28.0, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 18, Color(1.0, 1.0, 1.0, 1.0))
	inventory_detail_panel.add_child(name_label)

	var meta_label = Label.new()
	meta_label.name = "DetailMeta"
	meta_label.position = Vector2(14, meta_y)
	meta_label.size = Vector2(panel_size.x - 28.0, 20)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(meta_label, 12)
	inventory_detail_panel.add_child(meta_label)

	var description = Label.new()
	description.name = "DetailDescription"
	description.position = Vector2(16, description_y)
	description.size = Vector2(panel_size.x - 32.0, 32)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = true
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(description, 12)
	inventory_detail_panel.add_child(description)

	var amount_label = Label.new()
	amount_label.name = "AmountLabel"
	amount_label.text = "Amount"
	amount_label.position = Vector2(16, amount_row_y + 2.0)
	amount_label.size = Vector2(68, 24)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(amount_label, 12)
	inventory_detail_panel.add_child(amount_label)

	context_amount_input = LineEdit.new()
	context_amount_input.name = "AmountInput"
	context_amount_input.text = "1"
	context_amount_input.position = Vector2(88, amount_row_y)
	context_amount_input.size = Vector2(panel_size.x - 104.0, 32)
	context_amount_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_arcade_search_style(context_amount_input)
	if not context_amount_input.text_changed.is_connected(_on_context_amount_text_changed):
		context_amount_input.text_changed.connect(_on_context_amount_text_changed)
	inventory_detail_panel.add_child(context_amount_input)

	context_amount_slider = HSlider.new()
	context_amount_slider.name = "AmountSlider"
	context_amount_slider.position = Vector2(16, slider_y)
	context_amount_slider.size = Vector2(panel_size.x - 32.0, 16)
	context_amount_slider.min_value = 1
	context_amount_slider.max_value = 1
	context_amount_slider.step = 1
	context_amount_slider.value = 1
	context_amount_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	if not context_amount_slider.value_changed.is_connected(_on_context_amount_slider_changed):
		context_amount_slider.value_changed.connect(_on_context_amount_slider_changed)
	inventory_detail_panel.add_child(context_amount_slider)

	create_inventory_detail_button("DetailSelectButton", "SELECT", "select", Vector2(16, button_row_1_y), Vector2(split_button_width, button_height), true)
	create_inventory_detail_button("DetailInfoButton", "INFO", "info", Vector2(16 + split_button_width + split_button_gap, button_row_1_y), Vector2(split_button_width, button_height), false)
	create_inventory_detail_button("DetailDropButton", "DROP", "drop", Vector2(16, button_row_2_y), Vector2(split_button_width, button_height), false)
	create_inventory_detail_button("DetailTrashButton", "TRASH", "trash", Vector2(16 + split_button_width + split_button_gap, button_row_2_y), Vector2(split_button_width, button_height), false, true)
	create_inventory_detail_button("DetailAddButton", "ADD", "trade_add", Vector2(16, button_row_1_y), Vector2(panel_size.x - 32.0, button_height), true)
	create_inventory_detail_button("DetailCancelButton", "CANCEL", "trade_cancel", Vector2(16, button_row_2_y), Vector2(panel_size.x - 32.0, button_height), false, true)


func create_inventory_detail_button(node_name: String, button_text: String, action: String, button_position: Vector2, button_size: Vector2, selected_style: bool = false, danger: bool = false):
	var button = Button.new()
	button.name = node_name
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.clip_text = true
	apply_arcade_button_style(button, selected_style, danger, 12)
	button.pressed.connect(_on_inventory_detail_action.bind(action))
	inventory_detail_panel.add_child(button)


func set_inventory_detail_node_visible(node_name: String, should_show: bool):
	if inventory_detail_panel == null:
		return
	var node = inventory_detail_panel.get_node_or_null(node_name)
	if node != null:
		node.visible = should_show


func select_inventory_detail_item(item_type: String, category: String):
	if item_type == "" or category == "" or category == "empty":
		return
	inventory_detail_item_type = item_type
	inventory_detail_item_category = category
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = get_slot_for_item(item_type, category)
	setup_context_amount_controls(max(1, get_item_count(item_type, category)))
	update_inventory_detail_panel()


func update_inventory_detail_panel():
	if inventory_detail_panel == null:
		return

	var item_type = inventory_detail_item_type
	var category = inventory_detail_item_category
	var has_item = item_type != "" and category != "" and category != "empty" and get_item_count(item_type, category) > 0
	if not has_item:
		item_type = ""
		category = ""
		inventory_detail_item_type = ""
		inventory_detail_item_category = ""

	set_inventory_detail_node_visible("DetailEmpty", not has_item)
	for node_name in [
		"DetailPreviewBack", "DetailPreviewGlow", "DetailIconShadow", "DetailIcon",
		"DetailName", "DetailMeta", "DetailDescription", "AmountLabel", "AmountInput", "AmountSlider",
		"DetailSelectButton", "DetailInfoButton", "DetailDropButton", "DetailTrashButton",
		"DetailAddButton", "DetailCancelButton"
	]:
		set_inventory_detail_node_visible(node_name, has_item)

	if not has_item:
		return

	hold_item_type = item_type
	hold_item_category = category
	var count = get_item_count(item_type, category)
	var rarity = get_item_rarity(item_type, category)
	var accent = get_rarity_border_color(rarity)
	var display_name = get_item_display_name(item_type, category)
	var texture = get_item_texture(item_type, category)

	var preview_back = inventory_detail_panel.get_node_or_null("DetailPreviewBack")
	var preview_uses_texture: bool = false
	if preview_back != null and preview_back is Panel:
		var preview_style: StyleBox = null
		if preview_style != null:
			preview_uses_texture = true
			preview_back.add_theme_stylebox_override("panel", preview_style)
		else:
			preview_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				get_rarity_fill_color(rarity, 0.54),
				accent,
				3, 14, 7
			))

	var preview_glow = inventory_detail_panel.get_node_or_null("DetailPreviewGlow")
	if preview_glow != null and preview_glow is ColorRect:
		preview_glow.visible = not preview_uses_texture
		preview_glow.color = Color(accent.r, accent.g, accent.b, 0.13)

	var icon_shadow = inventory_detail_panel.get_node_or_null("DetailIconShadow")
	if icon_shadow != null and icon_shadow is TextureRect:
		icon_shadow.texture = texture
		icon_shadow.visible = texture != null

	var icon = inventory_detail_panel.get_node_or_null("DetailIcon")
	if icon != null and icon is TextureRect:
		icon.texture = texture
		update_seed_box_icon_overlay(icon, item_type, category)

	var name_label = inventory_detail_panel.get_node_or_null("DetailName")
	if name_label != null and name_label is Label:
		name_label.text = display_name

	var meta_label = inventory_detail_panel.get_node_or_null("DetailMeta")
	if meta_label != null and meta_label is Label:
		meta_label.text = category.capitalize() + "  |  " + get_rarity_display_name(rarity) + "  |  " + format_inventory_amount(item_type, category, count)
		meta_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 1.0))

	var description = inventory_detail_panel.get_node_or_null("DetailDescription")
	if description != null and description is Label:
		description.text = get_item_description(item_type, category)

	setup_context_amount_controls(count)
	var amount_title = inventory_detail_panel.get_node_or_null("AmountLabel")
	if amount_title != null and amount_title is Label:
		amount_title.text = "Amount"

	var trade_mode = is_item_selection_mode_active()
	var show_amount_controls = has_item and not display_select_active
	set_inventory_detail_node_visible("AmountLabel", show_amount_controls)
	set_inventory_detail_node_visible("AmountInput", show_amount_controls)
	set_inventory_detail_node_visible("AmountSlider", show_amount_controls)
	set_inventory_detail_node_visible("DetailSelectButton", has_item and not trade_mode)
	set_inventory_detail_node_visible("DetailInfoButton", has_item and not trade_mode)
	set_inventory_detail_node_visible("DetailDropButton", has_item and not trade_mode and can_drop_item_from_inventory(item_type, category))
	set_inventory_detail_node_visible("DetailTrashButton", has_item and not trade_mode)
	set_inventory_detail_node_visible("DetailAddButton", has_item and trade_mode)
	set_inventory_detail_node_visible("DetailCancelButton", has_item and trade_mode)

	var add_button = inventory_detail_panel.get_node_or_null("DetailAddButton")
	if add_button != null and add_button is Button:
		if vend_select_active:
			add_button.text = "ADD TO VENDING"
		elif safe_select_active:
			add_button.text = "ADD TO SAFE"
		elif donation_box_select_active:
			add_button.text = "DONATE"
		elif display_select_active:
			add_button.text = "DISPLAY ITEM"
		elif oil_refinery_battery_select_active:
			add_button.text = "ADD BATTERY"
		else:
			add_button.text = "ADD TO TRADE"

	var select_button = inventory_detail_panel.get_node_or_null("DetailSelectButton")
	if select_button != null and select_button is Button:
		if world != null and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category):
			select_button.text = "EQUIP"
		else:
			select_button.text = "SELECT"


func _on_inventory_detail_action(action: String):
	var item_type = inventory_detail_item_type
	var category = inventory_detail_item_category
	var available_amount: float = float(get_item_count(item_type, category))
	if item_type == "" or category == "" or available_amount <= 0.0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Select an item first.")
		return

	hold_item_type = item_type
	hold_item_category = category
	hold_slot = get_slot_for_item(item_type, category)
	var amount = get_context_amount(item_type, category)
	var stack_amount: int = max(1, int(round(amount)))

	match action:
		"trade_cancel":
			cancel_trade_item_popup()
			update_inventory_detail_panel()
			return
		"trade_add":
			if vend_select_active:
				add_context_item_to_vend(item_type, category, stack_amount)
			elif safe_select_active:
				add_context_item_to_safe(item_type, category, stack_amount)
			elif donation_box_select_active:
				add_context_item_to_donation_box(item_type, category, stack_amount)
			elif display_select_active:
				add_context_item_to_display(item_type, category)
			elif oil_refinery_battery_select_active:
				add_context_item_to_oil_refinery_battery(item_type, category, stack_amount)
			else:
				add_context_item_to_trade(item_type, category, stack_amount)
			update_inventory_detail_panel()
			return
		"select":
			assign_item_to_quick_hotbar(item_type, category)
			if world != null:
				world.select_item(item_type, category)
				if world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
					world.toggle_equip_item(item_type, category)
		"info":
			show_item_info(item_type, category)
		"drop":
			drop_inventory_item(item_type, category, amount)
		"trash":
			trash_inventory_item(item_type, category, amount)

	var remaining_amount: float = float(get_item_count(item_type, category))
	if remaining_amount <= 0.0:
		inventory_detail_item_type = ""
		inventory_detail_item_category = ""
	refresh_inventory_window_live()
	update_hotbar()


func _on_inventory_search_changed(new_text: String):
	hide_item_context_menu()
	inventory_search_text = new_text.strip_edges().to_lower()
	if inventory_scroll_container != null:
		inventory_scroll_container.scroll_vertical = 0
	mark_inventory_window_structure_dirty()
	update_inventory_window()


func _on_inventory_window_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		return
	if event is InputEventScreenTouch and event.pressed:
		return


func create_inventory_tab_button(tab_name: String, display_name: String, tab_position: Vector2, tab_size: Vector2 = Vector2(106, 37)):
	var tab = Button.new()
	tab.name = "Tab_" + tab_name
	tab.text = display_name
	tab.position = tab_position
	tab.size = tab_size
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.focus_mode = Control.FOCUS_NONE
	apply_arcade_button_style(tab, false, false, 13)
	tab.pressed.connect(_on_inventory_tab_pressed.bind(tab_name))
	var parent_node = inventory_tab_root if inventory_tab_root != null else inventory_window
	parent_node.add_child(tab)
	inventory_tab_buttons[tab_name] = tab
	apply_inventory_tab_shared_style()


func _on_inventory_tab_pressed(tab_name: String):
	inventory_tab = tab_name
	if inventory_scroll_container != null:
		inventory_scroll_container.scroll_vertical = 0
	mark_inventory_window_structure_dirty()
	update_inventory_window()


func _on_inventory_tab_gui_input(event: InputEvent, tab_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_tab_pressed(tab_name)
		mark_inventory_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		_on_inventory_tab_pressed(tab_name)
		mark_inventory_input_as_handled()


func sort_item_ids_by_order(a: String, b: String) -> bool:
	if world == null:
		return a < b
	if world.item_database.has(a) and world.item_database.has(b):
		var order_a = int(world.item_database[a].get("order", 9999))
		var order_b = int(world.item_database[b].get("order", 9999))
		if order_a == order_b:
			return a < b
		return order_a < order_b
	return a < b


func get_item_rarity(item_type: String, category: String = "") -> String:
	if category == "currency":
		return "currency"
	if world == null:
		return "common"
	if world.item_database.has(item_type):
		return normalize_item_rarity(str(world.item_database[item_type].get("rarity", "common")))
	return "common"


func get_rarity_display_name(rarity: String) -> String:
	match normalize_item_rarity(rarity):
		"common":    return "Common"
		"uncommon":  return "Uncommon"
		"rare":      return "Rare"
		"epic":      return "Epic"
		"legendary": return "Legendary"
		"currency":  return "Currency"
		_:           return rarity.capitalize()


func get_rarity_color(rarity: String) -> Color:
	match normalize_item_rarity(rarity):
		"common":    return Color(0.46, 0.88, 0.95, 0.65)
		"uncommon":  return Color(0.35, 0.95, 0.45, 0.90)
		"rare":      return Color(0.25, 0.55, 1.0, 0.95)
		"epic":      return Color(0.72, 0.30, 1.0, 0.95)
		"legendary": return Color(1.0, 0.66, 0.12, 0.98)
		"currency":  return Color(0.15, 0.95, 1.0, 0.95)
		_:           return Color(0.46, 0.88, 0.95, 0.65)


func apply_inventory_slot_style(slot, rarity: String, selected: bool, hovered: bool = false):
	if slot == null or not (slot is Panel):
		return
	slot.set_meta("inventory_slot_style_key", get_inventory_slot_style_key(rarity, selected, hovered))
	var border_color = get_rarity_border_color(rarity)
	var base_fill = get_rarity_fill_color(rarity, 0.34 if hovered else 0.24)
	var using_slot_texture = false
	if selected:
		slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(1.0, 0.76, 0.12, 0.96),
			Color(1.0, 0.96, 0.34, 1.0),
			4, 14, 8))
	else:
		slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			base_fill,
			Color(border_color.r, border_color.g, border_color.b, 0.90 if hovered else 0.66),
			3,
			14,
			8 if hovered else 5
		))
	var inner = slot.get_node_or_null("Inner")
	if inner != null and inner is Panel:
		if using_slot_texture:
			inner.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif selected:
			inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				Color(0.42, 0.22, 0.045, 0.76),
				Color(1.0, 0.90, 0.44, 0.68),
				2, 11, 3))
		else:
			inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				Color(0.82, 0.94, 1.0, 0.16 if hovered else 0.10),
				Color(0.72, 0.92, 1.0, 0.38 if hovered else 0.22),
				2, 11, 2 if hovered else 1))
	var icon_back = slot.get_node_or_null("IconBack")
	if icon_back != null and icon_back is Panel:
		if using_slot_texture:
			icon_back.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			icon_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				Color(0.42, 0.22, 0.045, 0.70) if selected else Color(0.82, 0.94, 1.0, 0.14 if hovered else 0.09),
				Color(border_color.r, border_color.g, border_color.b, 0.48 if selected else (0.36 if hovered else 0.22)),
				2, 13, 2 if hovered or selected else 1
			))
			if not selected:
				icon_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
					Color(0.82, 0.94, 1.0, 0.13 if hovered else 0.08),
					Color(border_color.r, border_color.g, border_color.b, 0.36 if hovered else 0.22),
					2, 13, 2 if hovered else 1
				))
	var legacy_child_visible = not using_slot_texture
	var icon_glow = slot.get_node_or_null("IconGlow")
	if icon_glow != null and icon_glow is ColorRect:
		icon_glow.visible = legacy_child_visible
		icon_glow.color = Color(border_color.r, border_color.g, border_color.b, 0.18 if selected else (0.13 if hovered else 0.075))
	var top_shine = slot.get_node_or_null("TopShine")
	if top_shine != null and top_shine is ColorRect:
		top_shine.visible = legacy_child_visible
		top_shine.color = Color(1.0, 1.0, 1.0, 0.24 if selected else (0.18 if hovered else 0.10))
	var left_shine = slot.get_node_or_null("LeftShine")
	if left_shine != null and left_shine is ColorRect:
		left_shine.visible = legacy_child_visible
		left_shine.color = Color(1.0, 1.0, 1.0, 0.14 if selected else (0.095 if hovered else 0.045))
	var bottom_shade = slot.get_node_or_null("BottomShade")
	if bottom_shade != null and bottom_shade is ColorRect:
		bottom_shade.visible = legacy_child_visible
		bottom_shade.color = Color(0.0, 0.0, 0.0, 0.24 if selected else 0.16)
	var icon_gloss = slot.get_node_or_null("IconGloss")
	if icon_gloss != null and icon_gloss is ColorRect:
		icon_gloss.visible = legacy_child_visible
		icon_gloss.color = Color(1.0, 1.0, 1.0, 0.18 if selected else (0.13 if hovered else 0.075))
	var icon_floor_shade = slot.get_node_or_null("IconFloorShade")
	if icon_floor_shade != null and icon_floor_shade is ColorRect:
		icon_floor_shade.visible = legacy_child_visible
		icon_floor_shade.color = Color(0.0, 0.0, 0.0, 0.24 if selected else (0.18 if hovered else 0.12))
	var icon_position = INVENTORY_ICON_POSITION
	var icon_shadow_position = INVENTORY_ICON_POSITION + INVENTORY_ICON_SHADOW_OFFSET
	var icon_scale = Vector2.ONE
	var shadow_scale = Vector2.ONE
	if hovered:
		icon_position += Vector2(-1.0, -2.0)
		icon_shadow_position += Vector2(2.0, 3.0)
		icon_scale = Vector2(1.045, 1.045)
		shadow_scale = Vector2(1.05, 1.05)
	if selected:
		icon_position += Vector2(0.0, -1.0)
		icon_shadow_position += Vector2(1.0, 2.0)
		icon_scale = Vector2(1.055, 1.055)
		shadow_scale = Vector2(1.06, 1.06)
	var icon_shadow = slot.get_node_or_null("IconShadow")
	if icon_shadow != null and icon_shadow is TextureRect:
		icon_shadow.position = icon_shadow_position
		icon_shadow.size = INVENTORY_ICON_SIZE
		icon_shadow.pivot_offset = INVENTORY_ICON_SIZE * 0.5
		icon_shadow.scale = shadow_scale
		icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.42 if selected else (0.38 if hovered else 0.30))
	var icon = slot.get_node_or_null("Icon")
	if icon != null and icon is TextureRect:
		icon.position = icon_position
		icon.size = INVENTORY_ICON_SIZE
		icon.pivot_offset = INVENTORY_ICON_SIZE * 0.5
		icon.scale = icon_scale
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if selected or hovered else 0.96)
		update_seed_box_icon_overlay(icon, str(slot.get_meta("item_type", "")), str(slot.get_meta("category", "")))
	var rarity_badge = slot.get_node_or_null("RarityBadge")
	if rarity_badge != null and rarity_badge is Panel:
		rarity_badge.visible = false
	var rarity_label = slot.get_node_or_null("Rarity")
	if rarity_label != null and rarity_label is Label:
		rarity_label.visible = false


func get_rarity_letter_color(rarity: String) -> Color:
	match normalize_item_rarity(rarity):
		"common":    return Color(0.90, 0.94, 1.0, 1.0)
		"uncommon":  return Color(0.55, 1.0, 0.55, 1.0)
		"rare":      return Color(0.45, 0.78, 1.0, 1.0)
		"epic":      return Color(0.92, 0.58, 1.0, 1.0)
		"legendary": return Color(1.0, 0.80, 0.22, 1.0)
		"currency":  return Color(0.45, 1.0, 1.0, 1.0)
		_:           return Color.WHITE


func create_inventory_grid_slots():
	if inventory_grid_root == null:
		return
	mark_inventory_window_structure_dirty()
	for child in inventory_grid_root.get_children():
		child.queue_free()
	inventory_slots.clear()
	var all_slot_keys = []
	for item_name in world.block_items:
		if world.item_database.has(item_name) and bool(world.item_database[item_name].get("hidden", false)):
			continue
		all_slot_keys.append("block:" + item_name)
	var seed_items = []
	for seed_name in world.seed_inventory.keys():
		seed_items.append(seed_name)
	seed_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for seed_name in seed_items:
		all_slot_keys.append("seed:" + seed_name)
	var tool_items = []
	for tool_name in world.tool_inventory.keys():
		tool_items.append(tool_name)
	tool_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for tool_name in tool_items:
		if world.item_database.has(tool_name) and bool(world.item_database[tool_name].get("hidden", false)):
			continue
		all_slot_keys.append("tool:" + tool_name)
	var material_items = []
	for material_name in world.material_inventory.keys():
		material_items.append(material_name)
	material_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for material_name in material_items:
		if world.item_database.has(material_name) and bool(world.item_database[material_name].get("hidden", false)):
			continue
		all_slot_keys.append("material:" + material_name)
	var lure_items = []
	for lure_name in world.lure_inventory.keys():
		lure_items.append(lure_name)
	lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for lure_name in lure_items:
		if world.item_database.has(lure_name) and bool(world.item_database[lure_name].get("hidden", false)):
			continue
		all_slot_keys.append("lure:" + lure_name)
	var fish_items = []
	for fish_name in world.fish_inventory.keys():
		fish_items.append(fish_name)
	fish_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for fish_name in fish_items:
		if world.item_database.has(fish_name) and bool(world.item_database[fish_name].get("hidden", false)):
			continue
		all_slot_keys.append("fish:" + fish_name)
	var back_items = []
	for back_name in world.back_inventory.keys():
		back_items.append(back_name)
	back_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for back_name in back_items:
		if world.item_database.has(back_name) and bool(world.item_database[back_name].get("hidden", false)):
			continue
		all_slot_keys.append("back:" + back_name)
	var hat_items = []
	for hat_name in world.hat_inventory.keys():
		hat_items.append(hat_name)
	hat_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for hat_name in hat_items:
		if world.item_database.has(hat_name) and bool(world.item_database[hat_name].get("hidden", false)):
			continue
		all_slot_keys.append("hat:" + hat_name)
	var hair_items = []
	for hair_name in world.hair_inventory.keys():
		hair_items.append(hair_name)
	hair_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for hair_name in hair_items:
		if world.item_database.has(hair_name) and bool(world.item_database[hair_name].get("hidden", false)):
			continue
		all_slot_keys.append("hair:" + hair_name)
	var eyewear_items = []
	for eyewear_name in world.eyewear_inventory.keys():
		eyewear_items.append(eyewear_name)
	eyewear_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for eyewear_name in eyewear_items:
		if world.item_database.has(eyewear_name) and bool(world.item_database[eyewear_name].get("hidden", false)):
			continue
		all_slot_keys.append("eyewear:" + eyewear_name)
	var shirt_items = []
	for shirt_name in world.shirt_inventory.keys():
		shirt_items.append(shirt_name)
	shirt_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for shirt_name in shirt_items:
		if world.item_database.has(shirt_name) and bool(world.item_database[shirt_name].get("hidden", false)):
			continue
		all_slot_keys.append("shirt:" + shirt_name)
	var pants_items = []
	for pants_name in world.pants_inventory.keys():
		pants_items.append(pants_name)
	pants_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for pants_name in pants_items:
		if world.item_database.has(pants_name) and bool(world.item_database[pants_name].get("hidden", false)):
			continue
		all_slot_keys.append("pants:" + pants_name)
	var shoes_items = []
	for shoes_name in world.shoes_inventory.keys():
		shoes_items.append(shoes_name)
	shoes_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for shoes_name in shoes_items:
		if world.item_database.has(shoes_name) and bool(world.item_database[shoes_name].get("hidden", false)):
			continue
		all_slot_keys.append("shoes:" + shoes_name)
	var ride_items = []
	for ride_name in world.ride_inventory.keys():
		ride_items.append(ride_name)
	ride_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for ride_name in ride_items:
		if world.item_database.has(ride_name) and bool(world.item_database[ride_name].get("hidden", false)):
			continue
		all_slot_keys.append("ride:" + ride_name)
	for slot_key in all_slot_keys:
		var parts = slot_key.split(":")
		var category = parts[0]
		var item_type = parts[1]
		var slot = Panel.new()
		slot.name = "Slot_" + slot_key
		slot.size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
		slot.visible = false
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.set_meta("item_type", item_type)
		slot.set_meta("category", category)
		slot.gui_input.connect(_on_inventory_slot_gui_input.bind(item_type, category))
		slot.mouse_entered.connect(_on_inventory_slot_mouse_entered.bind(item_type, category))
		slot.mouse_exited.connect(_on_inventory_slot_mouse_exited.bind(item_type, category))
		inventory_grid_root.add_child(slot)
		var inner = Panel.new()
		inner.name = "Inner"
		inner.position = Vector2(5, 5)
		inner.size = Vector2(INVENTORY_SLOT_SIZE - 10.0, INVENTORY_SLOT_SIZE - 10.0)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(inner)
		var icon_back = Panel.new()
		icon_back.name = "IconBack"
		icon_back.position = INVENTORY_ICON_FRAME_POSITION
		icon_back.size = INVENTORY_ICON_FRAME_SIZE
		icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_back)
		var icon_glow = ColorRect.new()
		icon_glow.name = "IconGlow"
		icon_glow.position = INVENTORY_ICON_FRAME_POSITION + Vector2(7.0, 8.0)
		icon_glow.size = INVENTORY_ICON_FRAME_SIZE - Vector2(14.0, 18.0)
		icon_glow.color = Color(0.4, 0.8, 1.0, 0.05)
		icon_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_glow)
		var top_shine = ColorRect.new()
		top_shine.name = "TopShine"
		top_shine.position = Vector2(13, 9)
		top_shine.size = Vector2(INVENTORY_SLOT_SIZE - 26.0, 2)
		top_shine.color = Color(1.0, 1.0, 1.0, 0.10)
		top_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(top_shine)
		var left_shine = ColorRect.new()
		left_shine.name = "LeftShine"
		left_shine.position = Vector2(9, 13)
		left_shine.size = Vector2(2, INVENTORY_SLOT_SIZE - 31.0)
		left_shine.color = Color(1.0, 1.0, 1.0, 0.055)
		left_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(left_shine)
		var bottom_shade = ColorRect.new()
		bottom_shade.name = "BottomShade"
		bottom_shade.position = Vector2(13, INVENTORY_SLOT_SIZE - 14.0)
		bottom_shade.size = Vector2(INVENTORY_SLOT_SIZE - 26.0, 3)
		bottom_shade.color = Color(0.0, 0.0, 0.0, 0.20)
		bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bottom_shade)
		var icon_floor_shade = ColorRect.new()
		icon_floor_shade.name = "IconFloorShade"
		icon_floor_shade.position = INVENTORY_ICON_FRAME_POSITION + Vector2(12.0, 53.0)
		icon_floor_shade.size = Vector2(38.0, 3.0)
		icon_floor_shade.color = Color(0.0, 0.0, 0.0, 0.16)
		icon_floor_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_floor_shade)
		var icon_shadow = TextureRect.new()
		icon_shadow.name = "IconShadow"
		icon_shadow.position = INVENTORY_ICON_POSITION + INVENTORY_ICON_SHADOW_OFFSET
		icon_shadow.size = INVENTORY_ICON_SIZE
		icon_shadow.pivot_offset = INVENTORY_ICON_SIZE * 0.5
		icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.30)
		icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_shadow.texture = get_item_texture(item_type, category)
		slot.add_child(icon_shadow)
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.position = INVENTORY_ICON_POSITION
		icon.size = INVENTORY_ICON_SIZE
		icon.pivot_offset = INVENTORY_ICON_SIZE * 0.5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
		icon.texture = get_item_texture(item_type, category)
		slot.add_child(icon)
		update_seed_box_icon_overlay(icon, item_type, category)
		var icon_gloss = ColorRect.new()
		icon_gloss.name = "IconGloss"
		icon_gloss.position = INVENTORY_ICON_FRAME_POSITION + Vector2(11.0, 7.0)
		icon_gloss.size = Vector2(40.0, 2.0)
		icon_gloss.color = Color(1.0, 1.0, 1.0, 0.075)
		icon_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_gloss)
		var name_label = Label.new()
		name_label.name = "Name"
		name_label.position = Vector2(7, 6)
		name_label.size = Vector2(INVENTORY_SLOT_SIZE - 34.0, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.visible = false
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
		name_label.add_theme_constant_override("outline_size", 1)
		slot.add_child(name_label)
		var count_badge = Panel.new()
		count_badge.name = "CountBadge"
		count_badge.position = Vector2(INVENTORY_SLOT_SIZE - 56.0, INVENTORY_SLOT_SIZE - 24.0)
		count_badge.size = Vector2(51, 19)
		count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_badge.visible = false
		count_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.01, 0.03, 0.05, 0.78),
			Color(0.55, 0.80, 0.92, 0.36),
			1, 8, 0
		))
		slot.add_child(count_badge)
		var count_label = Label.new()
		count_label.name = "Count"
		count_label.position = Vector2(INVENTORY_SLOT_SIZE - 56.0, INVENTORY_SLOT_SIZE - 24.0)
		count_label.size = Vector2(49, 19)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		count_label.add_theme_constant_override("outline_size", 2)
		slot.add_child(count_label)
		var equipped_label = Label.new()
		equipped_label.name = "EquippedLabel"
		equipped_label.text = "\u2713"
		equipped_label.position = Vector2(3, 1)
		equipped_label.size = Vector2(22, 22)
		equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipped_label.add_theme_font_size_override("font_size", 18)
		equipped_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.55, 1.0))
		equipped_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		equipped_label.add_theme_constant_override("outline_size", 2)
		equipped_label.visible = false
		slot.add_child(equipped_label)
		var rarity_badge = Panel.new()
		rarity_badge.name = "RarityBadge"
		rarity_badge.position = Vector2(INVENTORY_SLOT_SIZE - 27.0, 5)
		rarity_badge.size = Vector2(22, 22)
		rarity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rarity_badge.visible = false
		rarity_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			get_rarity_fill_color(get_item_rarity(item_type, category), 0.96),
			get_rarity_border_color(get_item_rarity(item_type, category)),
			2, 8, 1
		))
		slot.add_child(rarity_badge)
		var rarity_label = Label.new()
		rarity_label.name = "Rarity"
		rarity_label.position = Vector2(INVENTORY_SLOT_SIZE - 27.0, 5)
		rarity_label.size = Vector2(21, 21)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rarity_label.visible = false
		rarity_label.add_theme_font_size_override("font_size", 16)
		rarity_label.add_theme_color_override("font_color", Color.WHITE)
		rarity_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
		rarity_label.add_theme_constant_override("outline_size", 3)
		slot.add_child(rarity_label)
		apply_inventory_slot_style(slot, get_item_rarity(item_type, category), false)
		inventory_slots[slot_key] = slot


func _on_inventory_slot_mouse_entered(item_type: String, category: String):
	var slot = get_slot_for_item(item_type, category)
	if slot == null:
		return
	slot.set_meta("hovered", true)
	var selected = world != null and world.selected_item_category == category and world.selected_item_type == item_type
	selected = selected or (inventory_detail_item_category == category and inventory_detail_item_type == item_type)
	apply_inventory_slot_style(slot, get_item_rarity(item_type, category), selected, true)


func _on_inventory_slot_mouse_exited(item_type: String, category: String):
	var slot = get_slot_for_item(item_type, category)
	if slot == null:
		return
	slot.set_meta("hovered", false)
	var selected = world != null and world.selected_item_category == category and world.selected_item_type == item_type
	selected = selected or (inventory_detail_item_category == category and inventory_detail_item_type == item_type)
	apply_inventory_slot_style(slot, get_item_rarity(item_type, category), selected, false)


func _on_inventory_slot_gui_input(event: InputEvent, item_type: String, category: String):
	if should_ignore_mobile_mouse_event(event):
		mark_inventory_input_as_handled()
		return
	if is_item_selection_mode_active():
		var selectable: bool = can_select_item_for_active_mode(item_type, category)
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if not selectable:
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				mark_inventory_input_as_handled()
				return
			select_inventory_detail_item(item_type, category)
			mark_inventory_input_as_handled()
			return
		if event is InputEventScreenTouch and event.pressed:
			if not selectable:
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				mark_inventory_input_as_handled()
				return
			select_inventory_detail_item(item_type, category)
			mark_inventory_input_as_handled()
			return
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			mark_inventory_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			select_inventory_detail_item(item_type, category)
			mark_inventory_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click and try_convert_world_lock_stack(item_type, category):
					mark_inventory_input_as_handled()
					return
				select_inventory_detail_item(item_type, category)
				assign_item_to_quick_hotbar(item_type, category)
				world.select_item(item_type, category)
				if event.double_click and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
					world.toggle_equip_item(item_type, category)
				refresh_inventory_window_live()
				update_hotbar()
			mark_inventory_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			var double_tap = is_equip_double_tap(item_type, category, "inventory")
			if double_tap and try_convert_world_lock_stack(item_type, category):
				mark_inventory_input_as_handled()
				return
			select_inventory_detail_item(item_type, category)
			assign_item_to_quick_hotbar(item_type, category)
			world.select_item(item_type, category)
			if double_tap and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
				world.toggle_equip_item(item_type, category)
			refresh_inventory_window_live()
			update_hotbar()
		mark_inventory_input_as_handled()


func get_slot_for_item(item_type: String, category: String):
	var slot_key = category + ":" + item_type
	if inventory_slots.has(slot_key):
		return inventory_slots[slot_key]
	return null


func _clean_inventory_slot_id(raw_slot_id: String) -> String:
	var slot_id = str(raw_slot_id).strip_edges()
	if slot_id == "":
		return ""
	var safe_slot_id = slot_id.replace("\\", "/")
	if safe_slot_id.find(":") == -1:
		return safe_slot_id
	return safe_slot_id


func _split_inventory_slot_id(raw_slot_id: String) -> Array:
	var slot_id = _clean_inventory_slot_id(raw_slot_id)
	if slot_id == "":
		return ["", ""]
	var parts = slot_id.split(":", false)
	if parts.size() < 2:
		return ["", ""]
	var category = str(parts[0]).strip_edges()
	var item_type = ""
	for i in range(1, parts.size()):
		if item_type != "":
			item_type += ":"
		item_type += str(parts[i])
	return [item_type, category]


func mark_inventory_slot_dirty(item_id: String) -> void:
	var slot_key = _clean_inventory_slot_id(item_id)
	if slot_key == "":
		return
	if slot_key.find(":") == -1 and world != null and world.item_database.has(slot_key):
		var resolved_category := str(world.item_database[slot_key].get("category", "")).strip_edges().to_lower()
		if resolved_category != "":
			slot_key = get_inventory_slot_key(slot_key, resolved_category)
	if inventory_slot_dirty_set.has(slot_key):
		return
	inventory_slot_dirty_set[slot_key] = true
	inventory_slot_dirty_keys.append(slot_key)
	if DEBUG_INVENTORY_UI:
		print("[InventoryUI] dirty slot queued ", slot_key)


func notify_inventory_item_changed(item_type: String, category: String, source: String = INVENTORY_UPDATE_SOURCE_LOCAL) -> void:
	# Call this after any normal inventory count change:
	# pickup, break reward, place/spend, drop, trash, trade result, server delta.
	# It queues exactly one slot instead of refreshing/rebuilding the whole inventory.
	if item_type == "" or category == "" or category == "empty":
		return
	if not should_inventory_source_update_local_ui(source):
		return
	mark_inventory_slot_dirty(get_inventory_slot_key(item_type, category))
	var should_refresh_hotbar: bool = is_hotbar_item_changed(item_type, category)
	var should_refresh_gem: bool = category == "currency" or item_type == "gem"
	request_inventory_hud_refresh(false, should_refresh_hotbar, should_refresh_gem)


func notify_inventory_items_changed(changed_items: Array, source: String = INVENTORY_UPDATE_SOURCE_LOCAL) -> void:
	# Accepts entries like {"item_type": "dirt", "category": "block"}
	# or {"id": "dirt", "category": "block"}. Use this for bulk pickup.
	# Duplicate item ids are intentionally coalesced, so 200 dirt pickups update one slot.
	if not should_inventory_source_update_local_ui(source):
		return
	var coalesced: Dictionary = {}
	var gem_changed := false
	var hotbar_changed := false
	for change in changed_items:
		if not (change is Dictionary):
			continue
		var item_type := str(change.get("item_type", change.get("id", change.get("type", ""))))
		var category := str(change.get("category", change.get("item_category", "")))
		if item_type == "" or category == "" or category == "empty":
			continue
		var slot_key: String = get_inventory_slot_key(item_type, category)
		coalesced[slot_key] = {"item_type": item_type, "category": category}
		if is_hotbar_item_changed(item_type, category):
			hotbar_changed = true
		if category == "currency" or item_type == "gem":
			gem_changed = true
	for slot_key in coalesced.keys():
		mark_inventory_slot_dirty(str(slot_key))
	request_inventory_hud_refresh(gem_changed or coalesced.size() >= PICKUP_BULK_MIN_ITEMS, hotbar_changed, gem_changed)


func notify_remote_player_inventory_action_ignored(item_type: String, category: String) -> void:
	# Intentionally a no-op. Use this from network/world handlers when another player
	# picks up, places, breaks, drops, or consumes an item. The local client's inventory
	# must not refresh for remote player actions.
	if DEBUG_INVENTORY_UI:
		print("[InventoryUI] ignored remote inventory action ", category, ":", item_type)


func _keep_inventory_dirty_queue(remaining_keys: Array) -> void:
	_clear_inventory_slot_dirty_queue()
	for raw_key in remaining_keys:
		var slot_key := _clean_inventory_slot_id(str(raw_key))
		if slot_key == "" or inventory_slot_dirty_set.has(slot_key):
			continue
		inventory_slot_dirty_set[slot_key] = true
		inventory_slot_dirty_keys.append(slot_key)


func _clear_inventory_slot_dirty_queue() -> void:
	inventory_slot_dirty_keys.clear()
	inventory_slot_dirty_set.clear()



func _build_inventory_slot_node(item_type: String, category: String) -> Panel:
	if item_type == "" or category == "":
		return null

	var slot := Panel.new()
	slot.size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
	slot.visible = false
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.set_meta("item_type", item_type)
	slot.set_meta("category", category)
	slot.gui_input.connect(_on_inventory_slot_gui_input.bind(item_type, category))
	slot.mouse_entered.connect(_on_inventory_slot_mouse_entered.bind(item_type, category))
	slot.mouse_exited.connect(_on_inventory_slot_mouse_exited.bind(item_type, category))

	var inner := Panel.new()
	inner.name = "Inner"
	inner.position = Vector2(5, 5)
	inner.size = Vector2(INVENTORY_SLOT_SIZE - 10.0, INVENTORY_SLOT_SIZE - 10.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(inner)

	var icon_back := Panel.new()
	icon_back.name = "IconBack"
	icon_back.position = INVENTORY_ICON_FRAME_POSITION
	icon_back.size = INVENTORY_ICON_FRAME_SIZE
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_back)

	var icon_glow := ColorRect.new()
	icon_glow.name = "IconGlow"
	icon_glow.position = INVENTORY_ICON_FRAME_POSITION + Vector2(7.0, 8.0)
	icon_glow.size = INVENTORY_ICON_FRAME_SIZE - Vector2(14.0, 18.0)
	icon_glow.color = Color(0.4, 0.8, 1.0, 0.05)
	icon_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_glow)

	var top_shine := ColorRect.new()
	top_shine.name = "TopShine"
	top_shine.position = Vector2(13, 9)
	top_shine.size = Vector2(INVENTORY_SLOT_SIZE - 26.0, 2)
	top_shine.color = Color(1.0, 1.0, 1.0, 0.10)
	top_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(top_shine)

	var left_shine := ColorRect.new()
	left_shine.name = "LeftShine"
	left_shine.position = Vector2(9, 13)
	left_shine.size = Vector2(2, INVENTORY_SLOT_SIZE - 31.0)
	left_shine.color = Color(1.0, 1.0, 1.0, 0.055)
	left_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(left_shine)

	var bottom_shade := ColorRect.new()
	bottom_shade.name = "BottomShade"
	bottom_shade.position = Vector2(13, INVENTORY_SLOT_SIZE - 14.0)
	bottom_shade.size = Vector2(INVENTORY_SLOT_SIZE - 26.0, 3)
	bottom_shade.color = Color(0.0, 0.0, 0.0, 0.20)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bottom_shade)

	var icon_floor_shade := ColorRect.new()
	icon_floor_shade.name = "IconFloorShade"
	icon_floor_shade.position = INVENTORY_ICON_FRAME_POSITION + Vector2(12.0, 53.0)
	icon_floor_shade.size = Vector2(38.0, 3.0)
	icon_floor_shade.color = Color(0.0, 0.0, 0.0, 0.16)
	icon_floor_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_floor_shade)

	var current_icon_texture: Texture2D = get_item_texture(item_type, category) as Texture2D

	var icon_shadow := TextureRect.new()
	icon_shadow.name = "IconShadow"
	icon_shadow.position = INVENTORY_ICON_POSITION + INVENTORY_ICON_SHADOW_OFFSET
	icon_shadow.size = INVENTORY_ICON_SIZE
	icon_shadow.pivot_offset = INVENTORY_ICON_SIZE * 0.5
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.30)
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_shadow.texture = current_icon_texture
	slot.add_child(icon_shadow)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = INVENTORY_ICON_POSITION
	icon.size = INVENTORY_ICON_SIZE
	icon.pivot_offset = INVENTORY_ICON_SIZE * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	icon.texture = current_icon_texture
	slot.add_child(icon)
	update_seed_box_icon_overlay(icon, item_type, category)

	var icon_gloss := ColorRect.new()
	icon_gloss.name = "IconGloss"
	icon_gloss.position = INVENTORY_ICON_FRAME_POSITION + Vector2(11.0, 7.0)
	icon_gloss.size = Vector2(40.0, 2.0)
	icon_gloss.color = Color(1.0, 1.0, 1.0, 0.075)
	icon_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_gloss)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.position = Vector2(7, 6)
	name_label.size = Vector2(INVENTORY_SLOT_SIZE - 34.0, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.visible = false
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	name_label.add_theme_constant_override("outline_size", 1)
	slot.add_child(name_label)

	var count_badge := Panel.new()
	count_badge.name = "CountBadge"
	count_badge.position = Vector2(INVENTORY_SLOT_SIZE - 56.0, INVENTORY_SLOT_SIZE - 24.0)
	count_badge.size = Vector2(51, 19)
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.visible = false
	count_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.01, 0.03, 0.05, 0.78),
		Color(0.55, 0.80, 0.92, 0.36),
		1, 8, 0
	))
	slot.add_child(count_badge)

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.position = Vector2(INVENTORY_SLOT_SIZE - 56.0, INVENTORY_SLOT_SIZE - 24.0)
	count_label.size = Vector2(49, 19)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	count_label.add_theme_constant_override("outline_size", 2)
	slot.add_child(count_label)

	var equipped_label := Label.new()
	equipped_label.name = "EquippedLabel"
	equipped_label.text = "\u2713"
	equipped_label.position = Vector2(3, 1)
	equipped_label.size = Vector2(22, 22)
	equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipped_label.add_theme_font_size_override("font_size", 18)
	equipped_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.55, 1.0))
	equipped_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	equipped_label.add_theme_constant_override("outline_size", 2)
	equipped_label.visible = false
	slot.add_child(equipped_label)

	var rarity_badge := Panel.new()
	rarity_badge.name = "RarityBadge"
	rarity_badge.position = Vector2(INVENTORY_SLOT_SIZE - 27.0, 5)
	rarity_badge.size = Vector2(22, 22)
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_badge.visible = false
	rarity_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		get_rarity_fill_color(get_item_rarity(item_type, category), 0.96),
		get_rarity_border_color(get_item_rarity(item_type, category)),
		2, 8, 1
	))
	slot.add_child(rarity_badge)

	var rarity_label := Label.new()
	rarity_label.name = "Rarity"
	rarity_label.position = Vector2(INVENTORY_SLOT_SIZE - 27.0, 5)
	rarity_label.size = Vector2(21, 21)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_label.visible = false
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", Color.WHITE)
	rarity_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	rarity_label.add_theme_constant_override("outline_size", 3)
	slot.add_child(rarity_label)

	apply_inventory_slot_style(slot, get_item_rarity(item_type, category), false)
	return slot


func create_inventory_slot_if_needed(item_id: String) -> void:
	if inventory_grid_root == null:
		return
	var split_data = _split_inventory_slot_id(item_id)
	var category = split_data[1]
	var item_type = split_data[0]
	if item_type == "" or category == "":
		return
	if get_slot_for_item(item_type, category) != null:
		return
	var slot = _build_inventory_slot_node(item_type, category)
	if slot == null:
		return
	var slot_key = get_inventory_slot_key(item_type, category)
	slot.name = "Slot_" + slot_key
	slot.visible = false
	slot.set_meta("item_type", item_type)
	slot.set_meta("category", category)
	inventory_grid_root.add_child(slot)
	inventory_slots[slot_key] = slot
	slot.set_meta("inventory_slot_key", slot_key)


func get_incremental_inventory_slot_layout_index(slot: Control, columns: int) -> int:
	if slot == null:
		return -1
	var column: int = int(round(slot.position.x / INVENTORY_SLOT_STEP))
	var row: int = int(round(slot.position.y / INVENTORY_SLOT_STEP))
	column = clamp(column, 0, max(0, columns - 1))
	row = max(0, row)
	return row * columns + column


func get_next_incremental_inventory_slot_position() -> Vector2:
	var grid_size := get_inventory_grid_view_size()
	var columns: int = max(1, int(floor((grid_size.x + INVENTORY_SLOT_GAP) / INVENTORY_SLOT_STEP)))
	var max_layout_index := -1
	for raw_slot in inventory_slots.values():
		var visible_slot := raw_slot as Control
		if visible_slot == null or not is_instance_valid(visible_slot) or not visible_slot.visible:
			continue
		max_layout_index = max(max_layout_index, get_incremental_inventory_slot_layout_index(visible_slot, columns))
	var next_index := max_layout_index + 1
	return Vector2((next_index % columns) * INVENTORY_SLOT_STEP, int(floor(float(next_index) / float(columns))) * INVENTORY_SLOT_STEP)


func refresh_incremental_inventory_grid_extent() -> void:
	if inventory_grid_root == null:
		return
	var grid_size := get_inventory_grid_view_size()
	var columns: int = max(1, int(floor((grid_size.x + INVENTORY_SLOT_GAP) / INVENTORY_SLOT_STEP)))
	var max_layout_index := -1
	for raw_slot in inventory_slots.values():
		var visible_slot := raw_slot as Control
		if visible_slot == null or not is_instance_valid(visible_slot) or not visible_slot.visible:
			continue
		max_layout_index = max(max_layout_index, get_incremental_inventory_slot_layout_index(visible_slot, columns))
	var rows := 1
	if max_layout_index >= 0:
		rows = int(floor(float(max_layout_index) / float(columns))) + 1
	inventory_grid_root.custom_minimum_size = Vector2(
		grid_size.x,
		max(grid_size.y, rows * INVENTORY_SLOT_STEP - INVENTORY_SLOT_GAP + INVENTORY_GRID_BOTTOM_PAD)
	)
	inventory_grid_root.size = inventory_grid_root.custom_minimum_size


func update_inventory_slot(item_id: String) -> void:
	var split_data = _split_inventory_slot_id(item_id)
	var category = split_data[1]
	var item_type = split_data[0]
	if item_type == "" or category == "":
		return
	if is_inventory_scene_window():
		return

	var slot = get_slot_for_item(item_type, category)
	var should_be_visible = should_inventory_item_be_visible(item_type, category)
	var count = get_item_count(item_type, category)
	var slot_key = get_inventory_slot_key(item_type, category)

	if should_be_visible and count > 0:
		var was_visible: bool = slot != null and is_instance_valid(slot) and slot is Control and slot.visible
		if slot == null:
			create_inventory_slot_if_needed(slot_key)
			slot = get_slot_for_item(item_type, category)
		if slot == null:
			return
		if inventory_grid_root == null:
			return
		if not was_visible and slot is Control:
			slot.position = get_next_incremental_inventory_slot_position()
		slot.visible = true
		update_inventory_slot_state(slot, item_type, category, count, false)
		if not inventory_visible_slot_keys.has(slot_key):
			inventory_visible_slot_keys.append(slot_key)
		inventory_visible_slot_counts[slot_key] = count
		if not was_visible:
			refresh_incremental_inventory_grid_extent()
	else:
		remove_or_hide_inventory_slot(slot_key)

	if inventory_detail_item_type == item_type and inventory_detail_item_category == category:
		update_inventory_detail_panel()


func remove_or_hide_inventory_slot(item_id: String) -> void:
	var split_data = _split_inventory_slot_id(item_id)
	var category = split_data[1]
	var item_type = split_data[0]
	if item_type == "" or category == "":
		return
	var slot = get_slot_for_item(item_type, category)
	if slot != null and is_instance_valid(slot) and slot is Control:
		slot.visible = false
	var slot_key := _clean_inventory_slot_id(item_id)
	inventory_visible_slot_keys.erase(slot_key)
	inventory_visible_slot_counts.erase(slot_key)
	refresh_incremental_inventory_grid_extent()


func did_inventory_scene_live_refresh_change_structure() -> bool:
	if inventory_window != null and inventory_window.has_method("did_last_live_refresh_change_structure"):
		return bool(inventory_window.did_last_live_refresh_change_structure())
	# Older/fallback scene implementations cannot report this distinction.
	return true


func process_dirty_inventory_slots() -> void:
	if inventory_slot_dirty_keys.is_empty():
		return
	if inventory_window_refresh_suspended:
		return
	if world == null or inventory_window == null:
		return

	# The bag is closed. Keep the dirty queue for the next open, but do not touch
	# inventory contents while hidden.
	if not is_inventory_window_refresh_active():
		return

	# Scene-based inventory must support per-item live refresh. If it does not,
	# rebuild once at most, not once per dirty item. This is the main bulk-pickup spike fix.
	if is_inventory_scene_window():
		var scene_needs_full_rebuild := false
		var scene_structure_changed := false
		var scene_processed := 0
		var scene_remaining_keys: Array = []
		for slot_key in inventory_slot_dirty_keys:
			if scene_processed >= INVENTORY_DIRTY_SLOT_PROCESS_BUDGET:
				scene_remaining_keys.append(slot_key)
				continue
			var data = _split_inventory_slot_id(str(slot_key))
			var category = data[1]
			var item_type = data[0]
			if item_type == "" or category == "":
				continue
			if category == "currency":
				scene_processed += 1
				continue
			if inventory_window.has_method("refresh_item_live_from_world") and bool(inventory_window.refresh_item_live_from_world(world, item_type, category)):
				inventory_window_live_cache_valid = true
				scene_structure_changed = scene_structure_changed or did_inventory_scene_live_refresh_change_structure()
			else:
				scene_needs_full_rebuild = true
			scene_processed += 1

		if scene_needs_full_rebuild:
			# One full rebuild is acceptable for a new structure, but never do it once per item.
			mark_inventory_window_structure_dirty()
			refresh_inventory_scene_window(true)
			_clear_inventory_slot_dirty_queue()
		else:
			if scene_structure_changed:
				inventory_scene_cache_signature = get_inventory_scene_signature()
			_keep_inventory_dirty_queue(scene_remaining_keys)
			refresh_inventory_scene_chrome()
		request_inventory_hud_refresh()
		return

	update_inventory_window_chrome()
	var processed := 0
	var remaining_keys: Array = []
	for slot_key in inventory_slot_dirty_keys:
		if processed >= INVENTORY_DIRTY_SLOT_PROCESS_BUDGET:
			remaining_keys.append(slot_key)
			continue
		update_inventory_slot(str(slot_key))
		processed += 1
	_keep_inventory_dirty_queue(remaining_keys)
	request_inventory_hud_refresh()


func is_equip_double_tap(item_type: String, category: String, source: String) -> bool:
	var now = Time.get_ticks_msec()
	var tap_key = source + ":" + category + ":" + item_type
	var is_double_tap = equip_last_tap_ms > 0 and tap_key == equip_last_tap_key and now - equip_last_tap_ms <= TOUCH_EQUIP_DOUBLE_TAP_TIME_MS
	equip_last_tap_key = "" if is_double_tap else tap_key
	equip_last_tap_ms = 0 if is_double_tap else now
	return is_double_tap


func start_item_hold(item_type: String, category: String, slot, is_double_click: bool, source: String = "inventory"):
	hide_item_context_menu()
	hold_active = true
	hold_popup_opened = false
	hold_time = 0.0
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = slot
	hold_source = source
	if is_double_click and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category):
		cancel_item_hold()
		if source == "hotbar":
			select_hotbar_item(item_type, category)
		else:
			world.select_item(item_type, category)
		if world.has_method("toggle_equip_item"):
			world.toggle_equip_item(item_type, category)


func finish_item_hold(item_type: String, category: String):
	if not hold_active:
		return
	var opened_popup = hold_popup_opened
	var source = hold_source
	if opened_popup:
		hold_active = false
		hold_popup_opened = false
		hold_time = 0.0
		return
	cancel_item_hold()
	if source == "hotbar":
		select_hotbar_item(item_type, category)
		return
	assign_item_to_quick_hotbar(item_type, category)
	world.select_item(item_type, category)


func cancel_item_hold():
	hold_active = false
	hold_popup_opened = false
	hold_time = 0.0
	hold_item_type = ""
	hold_item_category = ""
	hold_slot = null
	hold_source = "inventory"


func update_hold_context_menu(delta):
	if not hold_active:
		return
	if hold_popup_opened:
		return
	hold_time += delta
	if hold_time >= ITEM_HOLD_TIME:
		hold_popup_opened = true
		show_item_context_menu(hold_item_type, hold_item_category, hold_slot)


func setup_item_context_menu():
	if inventory_window == null:
		return
	item_context_menu = inventory_window.get_node_or_null("ItemContextMenu")
	if item_context_menu == null:
		item_context_menu = ColorRect.new()
		item_context_menu.name = "ItemContextMenu"
		inventory_window.add_child(item_context_menu)
	item_context_menu.size = Vector2(250, 224)
	item_context_menu.color = Color(0.035, 0.12, 0.19, 0.98)
	item_context_menu.z_index = 260
	item_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	item_context_menu.visible = false
	for child in item_context_menu.get_children():
		child.queue_free()
	var amount_label = Label.new()
	amount_label.name = "AmountLabel"
	amount_label.text = "Amount"
	amount_label.position = Vector2(12, 10)
	amount_label.size = Vector2(70, 22)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(amount_label, 13)
	item_context_menu.add_child(amount_label)
	context_amount_input = LineEdit.new()
	context_amount_input.name = "AmountInput"
	context_amount_input.text = "1"
	context_amount_input.position = Vector2(86, 8)
	context_amount_input.size = Vector2(150, 30)
	context_amount_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(context_amount_input, 16)
	if not context_amount_input.text_changed.is_connected(_on_context_amount_text_changed):
		context_amount_input.text_changed.connect(_on_context_amount_text_changed)
	item_context_menu.add_child(context_amount_input)
	context_amount_slider = HSlider.new()
	context_amount_slider.name = "AmountSlider"
	context_amount_slider.position = Vector2(12, 48)
	context_amount_slider.size = Vector2(224, 24)
	context_amount_slider.min_value = 1
	context_amount_slider.max_value = 1
	context_amount_slider.step = 1
	context_amount_slider.value = 1
	context_amount_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	if not context_amount_slider.value_changed.is_connected(_on_context_amount_slider_changed):
		context_amount_slider.value_changed.connect(_on_context_amount_slider_changed)
	item_context_menu.add_child(context_amount_slider)
	create_context_button("Add To Trade", "trade_add", Vector2(12, 84))
	create_context_button("Cancel", "trade_cancel", Vector2(12, 122))
	create_context_button("Info", "info", Vector2(12, 84))
	create_context_button("Drop Amount", "drop", Vector2(12, 122))
	create_context_button("Trash Amount", "trash", Vector2(12, 160))
	apply_context_menu_shared_style()


func create_context_button(button_text: String, action: String, button_position: Vector2):
	var button = Button.new()
	button.name = "Context_" + action
	button.text = button_text
	button.position = button_position
	button.size = Vector2(226, 32)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if action == "trash" or action == "trade_cancel":
		apply_arcade_button_style(button, false, true, 14)
	elif action == "trade_add":
		apply_arcade_button_style(button, true, false, 14)
	else:
		apply_arcade_button_style(button, false, false, 14)
	button.pressed.connect(_on_context_menu_action.bind(action))
	item_context_menu.add_child(button)


func configure_context_menu_for_trade_mode():
	if item_context_menu == null:
		return

	var trade_button = item_context_menu.get_node_or_null("Context_trade_add")
	var trade_cancel_button = item_context_menu.get_node_or_null("Context_trade_cancel")
	var info_button = item_context_menu.get_node_or_null("Context_info")
	var drop_button = item_context_menu.get_node_or_null("Context_drop")
	var trash_button = item_context_menu.get_node_or_null("Context_trash")
	if is_item_selection_mode_active():
		item_context_menu.size = Vector2(250, 132) if display_select_active else Vector2(250, 178)
		if trade_button != null:
			trade_button.visible = true
			if vend_select_active:
				trade_button.text = "Add To Vending"
			elif safe_select_active:
				trade_button.text = "Add To Safe"
			elif donation_box_select_active:
				trade_button.text = "Donate"
			elif display_select_active:
				trade_button.text = "Display Item"
			elif oil_refinery_battery_select_active:
				trade_button.text = "Add Battery"
			else:
				trade_button.text = "Add To Trade"
			trade_button.position = Vector2(12, 48) if display_select_active else Vector2(12, 84)
		if trade_cancel_button != null:
			trade_cancel_button.visible = true
			trade_cancel_button.position = Vector2(12, 84) if display_select_active else Vector2(12, 122)
		if context_amount_input != null:
			context_amount_input.visible = not display_select_active
		if context_amount_slider != null:
			context_amount_slider.visible = not display_select_active
		var selection_amount_label = item_context_menu.get_node_or_null("AmountLabel")
		if selection_amount_label != null:
			selection_amount_label.visible = not display_select_active
		if info_button != null:
			info_button.visible = false
		if drop_button != null:
			drop_button.visible = false
		if trash_button != null:
			trash_button.visible = false
	else:
		item_context_menu.size = Vector2(250, 224)
		if trade_button != null:
			trade_button.visible = false
			trade_button.text = "Add To Trade"
		if trade_cancel_button != null:
			trade_cancel_button.visible = false
		if context_amount_input != null:
			context_amount_input.visible = true
		if context_amount_slider != null:
			context_amount_slider.visible = true
		var normal_amount_label = item_context_menu.get_node_or_null("AmountLabel")
		if normal_amount_label != null:
			normal_amount_label.visible = true
		if info_button != null:
			info_button.visible = true
			info_button.position = Vector2(12, 84)
		if drop_button != null:
			drop_button.visible = can_drop_item_from_inventory(hold_item_type, hold_item_category)
			drop_button.position = Vector2(12, 122)
		if trash_button != null:
			trash_button.visible = true
			trash_button.position = Vector2(12, 160)


func show_item_context_menu(item_type: String, category: String, slot):
	if item_type == "" or category == "empty":
		return
	if is_item_selection_mode_active() and not can_select_item_for_active_mode(item_type, category):
		if world != null and world.has_method("show_notification"):
			world.show_notification("That item cannot be selected.")
		return
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = slot
	var payload: Dictionary = _build_item_action_payload(item_type, category)
	_show_item_action_popup(payload, _item_context_anchor_position(slot))


func hide_item_context_menu():
	if item_action_popup != null and is_instance_valid(item_action_popup):
		if item_action_popup.has_method("close_popup"):
			item_action_popup.close_popup(false)
		else:
			item_action_popup.visible = false
	if item_context_menu != null:
		item_context_menu.visible = false


func _on_context_menu_action(action: String):
	var item_type = hold_item_type
	var category = hold_item_category
	var amount = get_context_amount(item_type, category)
	var stack_amount: int = max(1, int(round(amount)))
	match action:
		"trade_cancel":
			cancel_trade_item_popup()
			return
		"trade_add":
			if vend_select_active:
				add_context_item_to_vend(item_type, category, stack_amount)
			elif safe_select_active:
				add_context_item_to_safe(item_type, category, stack_amount)
			elif donation_box_select_active:
				add_context_item_to_donation_box(item_type, category, stack_amount)
			elif display_select_active:
				add_context_item_to_display(item_type, category)
			elif oil_refinery_battery_select_active:
				add_context_item_to_oil_refinery_battery(item_type, category, stack_amount)
			else:
				add_context_item_to_trade(item_type, category, stack_amount)
			return
	if is_item_selection_mode_active():
		cancel_trade_item_popup()
		return
	match action:
		"info":   show_item_info(item_type, category)
		"drop":   drop_inventory_item(item_type, category, amount)
		"trash":  trash_inventory_item(item_type, category, amount)
	hide_item_context_menu()
	cancel_item_hold()
	refresh_inventory_window_live()
	update_hotbar()


func cancel_trade_item_popup():
	hide_item_context_menu()
	cancel_item_hold()


func add_context_item_to_trade(item_type: String, category: String, amount: int):
	if not trade_select_active or trade_select_slot_index < 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose a trade slot first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent = false
	if world != null and world.has_method("add_inventory_item_to_trade"):
		sent = bool(world.add_inventory_item_to_trade(trade_select_slot_index, item_type, category, amount))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Trade UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_trade_item_select(true)


func add_context_item_to_vend(item_type: String, category: String, amount: int):
	if not vend_select_active:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose a vending slot first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent = false
	if world != null and world.has_method("add_inventory_item_to_vend"):
		sent = bool(world.add_inventory_item_to_vend(item_type, category, amount))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Vending UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_vend_item_select(true)


func add_context_item_to_safe(item_type: String, category: String, amount: int):
	if not safe_select_active:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose a safe slot first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent = false
	if world != null and world.has_method("add_inventory_item_to_safe"):
		sent = bool(world.add_inventory_item_to_safe(item_type, category, amount))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Safe UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_safe_item_select(true)


func add_context_item_to_donation_box(item_type: String, category: String, amount: int):
	if not donation_box_select_active:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Open a Donation Box first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent := false
	if world != null and world.has_method("add_inventory_item_to_donation_box"):
		sent = bool(world.add_inventory_item_to_donation_box(item_type, category, amount))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Donation Box UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_donation_box_item_select(true)


func add_context_item_to_display(item_type: String, category: String):
	if not display_select_active:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Choose a display first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent = false
	if world != null and world.has_method("add_inventory_item_to_display"):
		sent = bool(world.add_inventory_item_to_display(item_type, category, 1))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Display UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_display_item_select(true)


func add_context_item_to_oil_refinery_battery(item_type: String, category: String, amount: int):
	if not oil_refinery_battery_select_active:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Open an oil refinery first.")
		hide_item_context_menu()
		cancel_item_hold()
		return

	var sent: bool = false
	if world != null and world.has_method("add_inventory_item_to_oil_refinery"):
		sent = bool(world.add_inventory_item_to_oil_refinery(item_type, category, amount))
	else:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Oil refinery UI is not ready.")

	hide_item_context_menu()
	cancel_item_hold()
	if sent:
		end_oil_refinery_battery_select(true)


func setup_context_amount_controls(max_amount: int):
	var safe_max = max(1, max_amount)
	context_amount_updating = true
	if context_amount_slider != null:
		context_amount_slider.min_value = 1
		context_amount_slider.max_value = safe_max
		context_amount_slider.step = 1
		context_amount_slider.value = 1
	if context_amount_input != null:
		context_amount_input.text = "1"
	context_amount_updating = false


func setup_fish_weight_controls(max_weight: float):
	var safe_max: int = max(1, int(floor(max_weight)))
	context_amount_updating = true
	if context_amount_slider != null:
		context_amount_slider.min_value = 1
		context_amount_slider.max_value = safe_max
		context_amount_slider.step = 1
		context_amount_slider.value = safe_max
	if context_amount_input != null:
		context_amount_input.text = str(safe_max)
	context_amount_updating = false


func is_context_amount_for_fish() -> bool:
	return hold_item_category == "fish" or inventory_detail_item_category == "fish"


func _on_context_amount_slider_changed(value: float):
	if context_amount_updating:
		return
	set_context_amount_value(value, true)


func _on_context_amount_text_changed(new_text: String):
	if context_amount_updating:
		return
	var clean_text = new_text.strip_edges()
	if is_context_amount_for_fish():
		if not clean_text.is_valid_float():
			return
		var typed_count: int = int(floor(float(clean_text)))
		if typed_count <= 0:
			typed_count = 1
		set_context_amount_value(float(typed_count), false)
		return

	if clean_text == "" or not clean_text.is_valid_int():
		return
	var typed_amount: int = int(clean_text)
	if typed_amount <= 0:
		typed_amount = 1
	set_context_amount_value(float(typed_amount), false)


func set_context_amount_value(amount: float, update_text: bool):
	var max_amount: float = 1.0
	if context_amount_slider != null:
		max_amount = float(context_amount_slider.max_value)
	var min_amount: float = 1.0
	var step_amount: float = 1.0
	var safe_amount: float = snapped(clampf(float(amount), min_amount, max_amount), step_amount)
	context_amount_updating = true
	if context_amount_slider != null:
		context_amount_slider.value = safe_amount
	if update_text and context_amount_input != null:
		context_amount_input.text = str(int(round(safe_amount)))
	context_amount_updating = false


func get_context_amount(item_type: String, category: String) -> float:
	var limit: float = float(get_item_count(item_type, category))
	var amount: float = 1.0
	if context_amount_input != null:
		var clean_text = context_amount_input.text.strip_edges()
		if category == "fish" and clean_text.is_valid_float():
			amount = float(int(floor(float(clean_text))))
		elif category != "fish":
			amount = float(int(clean_text))
	elif context_amount_slider != null:
		amount = float(context_amount_slider.value)
	amount = float(clamp(int(round(amount)), 1, max(1, int(limit))))
	return amount


func show_item_info(item_type: String, category: String):
	var display_name = get_item_display_name(item_type, category)
	var count = get_item_count(item_type, category)
	var rarity = get_item_rarity(item_type, category)
	var rarity_name = get_rarity_display_name(rarity)
	if world != null and world.has_method("show_notification"):
		world.show_notification(display_name + " | " + rarity_name + " | " + format_inventory_amount(item_type, category, count))


func drop_inventory_item(item_type: String, category: String, amount: float):
	if not can_drop_item_from_inventory(item_type, category):
		if world.has_method("show_notification"):
			world.show_notification("That item cannot be dropped.")
		return
	if category == "fish":
		var safe_count: float = normalize_fish_weight(amount)
		if safe_count <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 1 fish.")
			return
		if not has_fish_weight(item_type, safe_count):
			if world.has_method("show_notification"):
				world.show_notification("You only have " + format_fish_weight(get_item_count(item_type, category)) + ".")
			return
		amount = safe_count
	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		var requested := false
		if world.has_method("drop_inventory_item_stack_to_world"):
			requested = bool(world.drop_inventory_item_stack_to_world(item_type, category, amount))
		elif world.has_method("drop_inventory_item_to_world") and int(round(amount)) == 1:
			requested = bool(world.drop_inventory_item_to_world(item_type, category))
		if requested:
			if world.has_method("show_notification"):
				world.show_notification("Dropping " + format_inventory_amount(item_type, category, amount) + " " + get_item_display_name(item_type, category) + "...")
		world.update_all_ui()
		return

	if world.drop_manager != null and world.drop_manager.has_method("can_drop_inventory_item_at_front"):
		if not bool(world.drop_manager.can_drop_inventory_item_at_front(true)):
			world.update_all_ui()
			return

	if not remove_inventory_item(item_type, category, amount):
		return
	if world.has_method("drop_inventory_item_stack_to_world"):
		world.drop_inventory_item_stack_to_world(item_type, category, amount)
	elif world.has_method("drop_inventory_item_to_world"):
		for i in range(int(round(amount))):
			world.drop_inventory_item_to_world(item_type, category)
	if world.has_method("show_notification"):
		world.show_notification("Dropped " + format_inventory_amount(item_type, category, amount) + " " + get_item_display_name(item_type, category) + ".")
	world.update_all_ui()


func trash_inventory_item(item_type: String, category: String, amount: float):
	if item_type == "punch":
		if world.has_method("show_notification"):
			world.show_notification("Punch cannot be trashed.")
		return
	if category == "fish":
		var safe_count: float = normalize_fish_weight(amount)
		if safe_count <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 1 fish.")
			return
		if not has_fish_weight(item_type, safe_count):
			if world.has_method("show_notification"):
				world.show_notification("You only have " + format_fish_weight(get_item_count(item_type, category)) + ".")
			return
		amount = safe_count
	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if request_server_inventory_trash(item_type, category, amount):
			if world.has_method("show_notification"):
				world.show_notification("Trashing " + format_inventory_amount(item_type, category, amount) + " " + get_item_display_name(item_type, category) + "...")
		else:
			if world.has_method("show_notification"):
				world.show_notification("Almost ready. Try again in a moment.")
		world.update_all_ui()
		return
	if not remove_inventory_item(item_type, category, amount):
		return
	if category == "tool" and world.equipped_tool == item_type and get_item_count(item_type, category) <= 0 and world.has_method("unequip_tool"):
		world.unequip_tool()
	if world.has_method("show_notification"):
		world.show_notification("Trashed " + format_inventory_amount(item_type, category, amount) + " " + get_item_display_name(item_type, category) + ".")
	world.update_all_ui()


func request_server_inventory_trash(item_type: String, category: String, amount: float) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null or not network.has_method("send_inventory_transaction_request"):
		return false
	if category == "fish":
		amount = normalize_fish_weight(amount)
		if amount <= 0.0 or not has_fish_weight(item_type, amount):
			return false
	var payload_amount: float = float(max(1, int(round(amount))))
	var payload: Dictionary = {
		"action": "trash_inventory_item",
		"world": world.current_world_name if world != null else "",
		"item_type": item_type,
		"item_category": category,
		"amount": payload_amount
	}

	return bool(network.send_inventory_transaction_request(payload))


func is_world_lock_currency_item(item_type: String) -> bool:
	return item_type == WORLD_LOCK_ITEM_ID or item_type == SUPER_WORLD_LOCK_ITEM_ID


func get_world_lock_conversion_validation(direction: String) -> Dictionary:
	if world == null:
		return {"ok": false, "message": "Inventory is not ready."}

	var world_lock_count := get_item_count(WORLD_LOCK_ITEM_ID, "block")
	var super_world_lock_count := get_item_count(SUPER_WORLD_LOCK_ITEM_ID, "block")
	var world_lock_limit: int = 400
	var super_world_lock_limit: int = 400
	if world.has_method("get_stack_limit_for_item"):
		world_lock_limit = int(world.get_stack_limit_for_item(WORLD_LOCK_ITEM_ID, "block"))
		super_world_lock_limit = int(world.get_stack_limit_for_item(SUPER_WORLD_LOCK_ITEM_ID, "block"))

	if direction == "to_super":
		if world_lock_count < SUPER_WORLD_LOCK_EXCHANGE_RATE:
			return {"ok": false, "message": "You need 100 World Locks to make a Super World Lock."}
		if super_world_lock_count >= super_world_lock_limit:
			return {"ok": false, "message": "Your Super World Lock stack is full."}
		return {"ok": true, "message": ""}

	if direction == "to_world_locks":
		if super_world_lock_count < 1:
			return {"ok": false, "message": "You need a Super World Lock to convert back."}
		if world_lock_count + SUPER_WORLD_LOCK_EXCHANGE_RATE > world_lock_limit:
			return {"ok": false, "message": "You need 100 empty World Lock stack space."}
		return {"ok": true, "message": ""}

	return {"ok": false, "message": "That lock cannot be converted."}


func try_convert_world_lock_stack(item_type: String, category: String) -> bool:
	if category != "block" or not is_world_lock_currency_item(item_type):
		return false

	var direction: String = "to_super" if item_type == WORLD_LOCK_ITEM_ID else "to_world_locks"
	var validation := get_world_lock_conversion_validation(direction)
	if not bool(validation.get("ok", false)):
		if world != null and world.has_method("show_notification"):
			world.show_notification(str(validation.get("message", "That lock cannot be converted.")))
		return true

	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if request_server_world_lock_conversion(direction):
			if world.has_method("show_notification"):
				world.show_notification(get_world_lock_conversion_progress_message(direction))
		elif world.has_method("show_notification"):
			world.show_notification("Almost ready. Try again in a moment.")
		world.update_all_ui()
		return true

	if not apply_local_world_lock_conversion(direction):
		return true

	world.update_all_ui()
	return true


func request_server_world_lock_conversion(direction: String) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null or not network.has_method("send_inventory_transaction_request"):
		return false

	var payload: Dictionary = {
		"action": "convert_world_lock",
		"direction": direction,
		"world": world.current_world_name if world != null else ""
	}
	return bool(network.send_inventory_transaction_request(payload))


func apply_local_world_lock_conversion(direction: String) -> bool:
	var validation := get_world_lock_conversion_validation(direction)
	if not bool(validation.get("ok", false)):
		if world != null and world.has_method("show_notification"):
			world.show_notification(str(validation.get("message", "That lock cannot be converted.")))
		return false

	var from_item := WORLD_LOCK_ITEM_ID
	var to_item := SUPER_WORLD_LOCK_ITEM_ID
	var from_amount := SUPER_WORLD_LOCK_EXCHANGE_RATE
	var to_amount := 1
	if direction == "to_world_locks":
		from_item = SUPER_WORLD_LOCK_ITEM_ID
		to_item = WORLD_LOCK_ITEM_ID
		from_amount = 1
		to_amount = SUPER_WORLD_LOCK_EXCHANGE_RATE

	if not world.spend_item_from_inventory_stack(world.inventory, from_item, "block", from_amount):
		if world.has_method("show_notification"):
			world.show_notification("That lock stack changed. Try again.")
		return false

	var added: int = int(world.add_item_to_inventory_stack(world.inventory, to_item, "block", to_amount))
	if added != to_amount:
		world.add_item_to_inventory_stack(world.inventory, from_item, "block", from_amount)
		if added > 0:
			world.spend_item_from_inventory_stack(world.inventory, to_item, "block", added)
		if world.has_method("show_notification"):
			world.show_notification("That lock stack changed. Try again.")
		return false

	notify_inventory_item_changed(from_item, "block")
	notify_inventory_item_changed(to_item, "block")
	select_inventory_detail_item(to_item, "block")
	world.select_item(to_item, "block")
	if world.has_method("save_player_data"):
		world.save_player_data()
	if world.has_method("show_notification"):
		world.show_notification(get_world_lock_conversion_done_message(direction))
	return true


func get_world_lock_conversion_progress_message(direction: String) -> String:
	if direction == "to_super":
		return "Converting 100 World Locks into 1 Super World Lock..."
	return "Converting 1 Super World Lock into 100 World Locks..."


func get_world_lock_conversion_done_message(direction: String) -> String:
	if direction == "to_super":
		return "Converted 100 World Locks into 1 Super World Lock."
	return "Converted 1 Super World Lock into 100 World Locks."


func remove_inventory_item(item_type: String, category: String, amount: float) -> bool:
	if category == "fish" and world.fish_inventory.has(item_type):
		var fish_removed := remove_fish_weight(item_type, amount, true)
		if fish_removed:
			notify_inventory_item_changed(item_type, category)
		return fish_removed

	var whole_amount: int = max(1, int(round(amount)))
	var count = get_item_count(item_type, category)
	if count < whole_amount:
		if world.has_method("show_notification"):
			world.show_notification("You only have " + str(count) + ".")
		return false
	if category == "block" and world.inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.inventory, item_type, category, whole_amount)
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "seed" and world.seed_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.seed_inventory, item_type, category, whole_amount)
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "tool" and world.tool_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.tool_inventory, item_type, category, whole_amount)
		if world.equipped_tool == item_type and int(world.tool_inventory[item_type]) <= 0 and world.has_method("unequip_tool"):
			world.unequip_tool()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "material" and world.material_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.material_inventory, item_type, category, whole_amount)
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "lure" and world.lure_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.lure_inventory, item_type, category, whole_amount)
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "currency" and world.currency_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.currency_inventory, item_type, category, whole_amount)
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "back" and world.back_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.back_inventory, item_type, category, whole_amount)
		if world.equipped_back_item == item_type and int(world.back_inventory[item_type]) <= 0:
			world.equipped_back_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "hat" and world.hat_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.hat_inventory, item_type, category, whole_amount)
		if world.equipped_hat_item == item_type and int(world.hat_inventory[item_type]) <= 0:
			world.equipped_hat_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "hair" and world.hair_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.hair_inventory, item_type, category, whole_amount)
		if world.equipped_hair_item == item_type and int(world.hair_inventory[item_type]) <= 0:
			world.equipped_hair_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "eyewear" and world.eyewear_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.eyewear_inventory, item_type, category, whole_amount)
		if world.equipped_eyewear_item == item_type and int(world.eyewear_inventory[item_type]) <= 0:
			world.equipped_eyewear_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "shirt" and world.shirt_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.shirt_inventory, item_type, category, whole_amount)
		if world.equipped_shirt_item == item_type and int(world.shirt_inventory[item_type]) <= 0:
			world.equipped_shirt_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "pants" and world.pants_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.pants_inventory, item_type, category, whole_amount)
		if world.equipped_pants_item == item_type and int(world.pants_inventory[item_type]) <= 0:
			world.equipped_pants_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "shoes" and world.shoes_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.shoes_inventory, item_type, category, whole_amount)
		if world.equipped_shoes_item == item_type and int(world.shoes_inventory[item_type]) <= 0:
			world.equipped_shoes_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if category == "ride" and world.ride_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.ride_inventory, item_type, category, whole_amount)
		if world.equipped_ride_item == item_type and int(world.ride_inventory[item_type]) <= 0:
			world.equipped_ride_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		notify_inventory_item_changed(item_type, category)
		return true
	if world.has_method("show_notification"):
		world.show_notification("Cannot remove " + get_item_display_name(item_type, category) + ".")
	return false


func update_inventory_window_position():
	if inventory_window == null:
		return
	if is_inventory_scene_window():
		var scene_should_be_visible: bool = inventory_drawer_target > 0.0 or inventory_drawer_amount > 0.01
		inventory_window.visible = scene_should_be_visible
		if not scene_should_be_visible:
			return
		var scene_screen_size: Vector2 = get_inventory_viewport_size()
		var scene_window_size: Vector2 = get_inventory_window_size_for_viewport(scene_screen_size)
		var scene_scale_amount: float = get_inventory_scene_window_scale_for_viewport(scene_screen_size)
		var scene_hotbar_y: float = lerp(
			get_hotbar_closed_y(scene_screen_size),
			get_hotbar_open_y(scene_screen_size),
			inventory_drawer_amount
		)
		if hotbar_root != null and hotbar_root.visible:
			scene_hotbar_y = hotbar_root.position.y
		var scene_top_left: Vector2 = Vector2(
			(scene_screen_size.x - scene_window_size.x) / 2.0,
			scene_hotbar_y + get_hotbar_visual_height(scene_screen_size) + HOTBAR_INVENTORY_GAP
		)
		if inventory_window.has_method("set_drawer_window_transform"):
			inventory_window.set_drawer_window_transform(scene_top_left, scene_scale_amount)
		else:
			var scene_window_child: Node = inventory_window.get_node_or_null("Window")
			if scene_window_child != null and scene_window_child is Control:
				(scene_window_child as Control).anchor_left = 0.0
				(scene_window_child as Control).anchor_top = 0.0
				(scene_window_child as Control).anchor_right = 0.0
				(scene_window_child as Control).anchor_bottom = 0.0
				(scene_window_child as Control).offset_left = scene_top_left.x
				(scene_window_child as Control).offset_top = scene_top_left.y
				(scene_window_child as Control).offset_right = scene_top_left.x + INVENTORY_SCENE_WINDOW_SIZE.x
				(scene_window_child as Control).offset_bottom = scene_top_left.y + INVENTORY_SCENE_WINDOW_SIZE.y
				(scene_window_child as Control).pivot_offset = Vector2.ZERO
				(scene_window_child as Control).scale = Vector2.ONE * scene_scale_amount
		return
	if inventory_drawer_target > 0.0 or inventory_drawer_amount > 0.01:
		inventory_window.visible = true
	var screen_size = get_inventory_viewport_size()
	var window_size = get_inventory_window_size_for_viewport(screen_size)
	if inventory_window.size.distance_to(window_size) > 2.0:
		inventory_window.size = window_size
	var open_x = (screen_size.x - inventory_window.size.x) / 2.0
	var hotbar_y = lerp(
		get_hotbar_closed_y(screen_size),
		get_hotbar_open_y(screen_size),
		inventory_drawer_amount
	)
	if hotbar_root != null and hotbar_root.visible:
		hotbar_y = hotbar_root.position.y
	inventory_window.position = Vector2(
		open_x,
		hotbar_y + get_hotbar_visual_height(screen_size) + HOTBAR_INVENTORY_GAP
	)


func get_inventory_grid_view_size() -> Vector2:
	var grid_size = Vector2(1028.0, 292.0)
	if inventory_scroll_container != null:
		grid_size = inventory_scroll_container.size
	grid_size.x = max(INVENTORY_SLOT_SIZE, grid_size.x - INVENTORY_SCROLLBAR_RESERVE)
	return grid_size


func mark_inventory_window_structure_dirty() -> void:
	inventory_window_structure_dirty = true
	inventory_window_live_cache_valid = false


func get_inventory_slot_key(item_type: String, category: String) -> String:
	return category + ":" + item_type


func append_visible_inventory_item(visible_items: Array, item_type: String, category: String, respect_hidden: bool = true) -> void:
	if item_type == "" or category == "":
		return
	if respect_hidden and world.item_database.has(item_type) and bool(world.item_database[item_type].get("hidden", false)):
		return
	var count: int = get_item_count(item_type, category)
	if count <= 0:
		return
	visible_items.append({
		"type": item_type,
		"category": category,
		"count": count,
		"key": get_inventory_slot_key(item_type, category)
	})


func get_sorted_inventory_keys(inventory: Dictionary) -> Array:
	var item_keys: Array = []
	for item_name in inventory.keys():
		item_keys.append(str(item_name))
	item_keys.sort_custom(Callable(self, "sort_item_ids_by_order"))
	return item_keys


func append_visible_inventory_items_for_keys(visible_items: Array, item_keys: Array, category: String, respect_hidden: bool = true) -> void:
	for item_name in item_keys:
		append_visible_inventory_item(visible_items, str(item_name), category, respect_hidden)


func build_visible_inventory_items() -> Array:
	var visible_items: Array = []
	if world == null:
		return visible_items

	if inventory_tab == "all" or inventory_tab == "blocks":
		append_visible_inventory_items_for_keys(visible_items, world.block_items, "block", true)

	if inventory_tab == "all" or inventory_tab == "seeds":
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.seed_inventory), "seed", false)

	if inventory_tab == "all" or inventory_tab == "tools":
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.tool_inventory), "tool", true)

	if inventory_tab == "all" or inventory_tab == "materials":
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.material_inventory), "material", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.lure_inventory), "lure", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.fish_inventory), "fish", true)

	if inventory_tab == "all" or inventory_tab == "back":
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.back_inventory), "back", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.hat_inventory), "hat", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.hair_inventory), "hair", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.eyewear_inventory), "eyewear", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.shirt_inventory), "shirt", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.pants_inventory), "pants", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.shoes_inventory), "shoes", true)
		append_visible_inventory_items_for_keys(visible_items, get_sorted_inventory_keys(world.ride_inventory), "ride", true)

	if inventory_search_text == "":
		return visible_items

	var filtered_items: Array = []
	for item_data in visible_items:
		var item_type: String = str(item_data.get("type", ""))
		var category: String = str(item_data.get("category", ""))
		var display_name: String = get_item_display_name(item_type, category).to_lower()
		if item_type.to_lower().find(inventory_search_text) != -1 or display_name.find(inventory_search_text) != -1:
			filtered_items.append(item_data)
	return filtered_items


func get_inventory_visible_slot_keys(visible_items: Array) -> Array:
	var visible_keys: Array = []
	for item_data in visible_items:
		var item_type: String = str(item_data.get("type", ""))
		var category: String = str(item_data.get("category", ""))
		visible_keys.append(str(item_data.get("key", get_inventory_slot_key(item_type, category))))
	return visible_keys


func do_inventory_visible_keys_match(visible_keys: Array) -> bool:
	if visible_keys.size() != inventory_visible_slot_keys.size():
		return false
	for i in range(visible_keys.size()):
		if str(visible_keys[i]) != str(inventory_visible_slot_keys[i]):
			return false
	return true


func cache_visible_inventory_items(visible_items: Array) -> void:
	inventory_visible_slot_keys = get_inventory_visible_slot_keys(visible_items)
	inventory_visible_slot_counts.clear()
	for item_data in visible_items:
		var item_type: String = str(item_data.get("type", ""))
		var category: String = str(item_data.get("category", ""))
		var key: String = str(item_data.get("key", get_inventory_slot_key(item_type, category)))
		inventory_visible_slot_counts[key] = int(item_data.get("count", 0))
	inventory_window_live_cache_valid = true
	inventory_window_structure_dirty = false


func update_inventory_window_chrome() -> void:
	if inventory_window == null or world == null:
		return
	if is_inventory_scene_window():
		refresh_inventory_scene_chrome()
		return
	var header_gem_label = inventory_window.get_node_or_null("HeaderGemLabel")
	if header_gem_label != null and header_gem_label is Label:
		header_gem_label.text = world.get_currency_display_text("gem")
	var selected_label = inventory_window.get_node_or_null("SelectedLabel")
	if selected_label != null:
		if trade_select_active:
			selected_label.text = "Select an item for trade, choose amount, then press Add To Trade."
		elif vend_select_active:
			selected_label.text = "Select an item for vending, choose stock amount, then press Add To Vending."
		elif safe_select_active:
			selected_label.text = "Select an item for the safe, choose amount, then press Add To Safe."
		elif donation_box_select_active:
			selected_label.text = "Select an item, choose an amount, then press Donate."
		elif display_select_active:
			selected_label.text = "Select one item to display."
		elif oil_refinery_battery_select_active:
			selected_label.text = "Select batteries for the oil refinery, choose amount, then press Add Battery."
		else:
			var selected_type = str(world.selected_item_type)
			var selected_category = str(world.selected_item_category)
			if selected_type != "" and selected_category != "":
				selected_label.text = "Selected: " + get_item_display_name(selected_type, selected_category)
			else:
				selected_label.text = ""


func get_inventory_slot_count_text(item_type: String, category: String, count: int) -> String:
	if category == "fish" and float(count) > 0.0:
		return format_inventory_amount(item_type, category, count)
	if count > 1:
		return format_stack_count(count)
	if category == "tool" or category == "back" or category == "hat" or category == "hair" or category == "eyewear" or category == "shirt" or category == "pants" or category == "shoes" or category == "ride":
		return str(count)
	return ""


func get_inventory_slot_style_key(rarity: String, selected: bool, hovered: bool) -> String:
	return normalize_item_rarity(rarity) + ":" + ("1" if selected else "0") + ":" + ("1" if hovered else "0")


func is_inventory_item_equipped(item_type: String, category: String) -> bool:
	if world == null:
		return false
	return (category == "tool" and world.equipped_tool == item_type) or (category == "back" and world.equipped_back_item == item_type) or (category == "hat" and world.equipped_hat_item == item_type) or (category == "hair" and world.equipped_hair_item == item_type) or (category == "eyewear" and world.equipped_eyewear_item == item_type) or (category == "shirt" and world.equipped_shirt_item == item_type) or (category == "pants" and world.equipped_pants_item == item_type) or (category == "shoes" and world.equipped_shoes_item == item_type) or (category == "ride" and world.equipped_ride_item == item_type)


func update_inventory_slot_state(slot, item_type: String, category: String, count: int, refresh_static_visuals: bool = false) -> void:
	if slot == null or world == null:
		return

	var slot_key: String = get_inventory_slot_key(item_type, category)
	var selected_key: String = str(world.selected_item_category) + ":" + str(world.selected_item_type)
	var detail_key: String = inventory_detail_item_category + ":" + inventory_detail_item_type
	var rarity: String = get_item_rarity(item_type, category)
	var hovered: bool = bool(slot.get_meta("hovered", false))
	var selected: bool = slot_key == selected_key or slot_key == detail_key
	var style_key: String = get_inventory_slot_style_key(rarity, selected, hovered)
	if refresh_static_visuals or str(slot.get_meta("inventory_slot_style_key", "")) != style_key:
		apply_inventory_slot_style(slot, rarity, selected, hovered)

	var rarity_label = slot.get_node_or_null("Rarity")
	if rarity_label != null and (refresh_static_visuals or str(slot.get_meta("inventory_slot_rarity_key", "")) != rarity):
		rarity_label.visible = false
		rarity_label.text = ""
		slot.set_meta("inventory_slot_rarity_key", rarity)

	var count_text: String = get_inventory_slot_count_text(item_type, category, count)
	var count_label = slot.get_node_or_null("Count")
	if count_label != null and count_label is Label and count_label.text != count_text:
		count_label.text = count_text
	var count_badge = slot.get_node_or_null("CountBadge")
	if count_badge != null and count_badge.visible != (count_text != ""):
		count_badge.visible = count_text != ""

	if refresh_static_visuals:
		var current_icon_texture: Texture2D = get_item_texture(item_type, category) as Texture2D
		var icon_shadow = slot.get_node_or_null("IconShadow")
		if icon_shadow != null:
			icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_shadow.texture = current_icon_texture
			icon_shadow.visible = current_icon_texture != null
		var icon = slot.get_node_or_null("Icon")
		if icon != null:
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = current_icon_texture
			if icon is TextureRect:
				update_seed_box_icon_overlay(icon, item_type, category)
		var name_label = slot.get_node_or_null("Name")
		if name_label != null:
			name_label.text = ""
			name_label.visible = false

	var item_tooltip_text: String = get_item_display_name(item_type, category) + " " + format_inventory_amount(item_type, category, count)
	if slot.tooltip_text != item_tooltip_text:
		slot.tooltip_text = item_tooltip_text
	var equipped_label = slot.get_node_or_null("EquippedLabel")
	if equipped_label != null:
		var equipped_visible: bool = is_inventory_item_equipped(item_type, category)
		if equipped_label.visible != equipped_visible:
			equipped_label.visible = equipped_visible


func should_run_inventory_structure_check() -> bool:
	var now: int = Time.get_ticks_msec()
	if inventory_last_structure_check_ms > 0 and now - inventory_last_structure_check_ms < INVENTORY_STRUCTURE_CHECK_INTERVAL_MS:
		return false
	inventory_last_structure_check_ms = now
	return true


func maybe_refresh_inventory_window_structure() -> bool:
	if not should_run_inventory_structure_check():
		return false

	var visible_items: Array = build_visible_inventory_items()
	var visible_keys: Array = get_inventory_visible_slot_keys(visible_items)
	if not do_inventory_visible_keys_match(visible_keys):
		update_inventory_window()
		return true

	cache_visible_inventory_items(visible_items)
	return false


func refresh_inventory_window_live() -> void:
	if inventory_window_refresh_suspended:
		inventory_window_refresh_pending = true
		return
	if inventory_window == null or world == null:
		return
	if not inventory_slot_dirty_keys.is_empty():
		process_dirty_inventory_slots()
		return
	if is_inventory_scene_window():
		refresh_inventory_scene_window()
		return
	if inventory_window_structure_dirty or not inventory_window_live_cache_valid:
		update_inventory_window()
		return

	update_inventory_window_chrome()
	var visible_items: Array = []
	for cached_slot_key in inventory_visible_slot_keys:
		var slot_key: String = str(cached_slot_key)
		if not inventory_slots.has(slot_key):
			update_inventory_window()
			return
		var slot = inventory_slots[slot_key]
		var item_type: String = str(slot.get_meta("item_type", ""))
		var category: String = str(slot.get_meta("category", ""))
		var count: int = get_item_count(item_type, category)
		if count <= 0:
			mark_inventory_window_structure_dirty()
			update_inventory_window()
			return
		update_inventory_slot_state(slot, item_type, category, count, false)
		visible_items.append({
			"type": item_type,
			"category": category,
			"count": count,
			"key": slot_key
		})

	cache_visible_inventory_items(visible_items)
	if maybe_refresh_inventory_window_structure():
		return
	update_inventory_detail_panel()


func should_inventory_item_be_visible(item_type: String, category: String) -> bool:
	if not is_inventory_open():
		return false
	if item_type == "" or category == "":
		return false
	if category == "currency":
		return false
	if world == null:
		return false
	if world.item_database.has(item_type) and bool(world.item_database[item_type].get("hidden", false)):
		return false
	if get_item_count(item_type, category) <= 0:
		return false
	match inventory_tab:
		"all":
			pass
		"blocks":
			if category != "block":
				return false
		"seeds":
			if category != "seed":
				return false
		"tools":
			if category != "tool":
				return false
		"materials":
			if category != "material" and category != "lure" and category != "fish":
				return false
		"back":
			if category != "back" and category != "hat" and category != "hair" and category != "eyewear" and category != "shirt" and category != "pants" and category != "shoes" and category != "ride":
				return false
		_:
			return false
	if inventory_search_text == "":
		return true
	var display_name: String = get_item_display_name(item_type, category).to_lower()
	return item_type.to_lower().find(inventory_search_text) != -1 or display_name.find(inventory_search_text) != -1


func refresh_inventory_item_live(item_type: String, category: String) -> void:
	if inventory_window_refresh_suspended:
		inventory_window_refresh_pending = true
		return
	if inventory_window == null or world == null:
		return
	if is_inventory_scene_window():
		if category == "currency":
			refresh_inventory_scene_chrome()
			return
		if inventory_window.has_method("refresh_item_live_from_world") and bool(inventory_window.refresh_item_live_from_world(world, item_type, category)):
			refresh_inventory_scene_chrome()
			if did_inventory_scene_live_refresh_change_structure():
				inventory_scene_cache_signature = get_inventory_scene_signature()
			inventory_window_live_cache_valid = true
			return
		inventory_window_structure_dirty = true
		if DEBUG_INVENTORY_UI:
			print("[InventoryUI] scene item live refresh deferred to next structure rebuild ", category, ":", item_type)
		return

	if category == "currency":
		if inventory_detail_item_type == item_type and inventory_detail_item_category == category:
			update_inventory_detail_panel()
		return

	update_inventory_window_chrome()
	var slot_key: String = get_inventory_slot_key(item_type, category)
	update_inventory_slot(slot_key)
	request_inventory_hud_refresh(category == "currency" or item_type == "gem")


func open_inventory_window():
	if inventory_window == null:
		return
	if is_gameplay_hud_blocked():
		return
	if is_inventory_scene_window():
		inventory_drawer_target = 1.0
		inventory_window.visible = true
		inventory_window.z_index = INVENTORY_WINDOW_Z_INDEX
		if inventory_window_structure_dirty or not inventory_window_live_cache_valid:
			update_inventory_window()
		elif not inventory_slot_dirty_keys.is_empty():
			process_dirty_inventory_slots()
		else:
			refresh_inventory_scene_chrome()
		if inventory_window.has_method("open_inventory"):
			inventory_window.open_inventory([], false)
		return
	inventory_window.visible = true
	inventory_drawer_target = 1.0
	if inventory_window_structure_dirty or not inventory_window_live_cache_valid:
		update_inventory_window()
	elif not inventory_slot_dirty_keys.is_empty():
		process_dirty_inventory_slots()
	else:
		update_inventory_window_chrome()


func close_inventory_window():
	if inventory_window == null:
		return
	if trade_select_active:
		end_trade_item_select(false)
	if vend_select_active:
		end_vend_item_select(false)
	if safe_select_active:
		end_safe_item_select(false)
	if donation_box_select_active:
		end_donation_box_item_select(false)
	if display_select_active:
		end_display_item_select(false)
	if oil_refinery_battery_select_active:
		end_oil_refinery_battery_select(false)
	hide_item_context_menu()
	if inventory_upgrade_popup != null and is_instance_valid(inventory_upgrade_popup):
		inventory_upgrade_popup.visible = false
	if is_inventory_scene_window():
		inventory_drawer_target = 0.0
		inventory_window.visible = true
		if inventory_search_input != null:
			inventory_search_input.release_focus()
		update_inventory_window_position()
		return
	inventory_drawer_target = 0.0
	# FIX: release search focus so typing goes back to the game.
	if inventory_search_input != null:
		inventory_search_input.release_focus()


func toggle_inventory_window():
	if inventory_window == null:
		return
	if inventory_drawer_target > 0.5 or inventory_drawer_amount > 0.5:
		close_inventory_window()
	else:
		open_inventory_window()


func update_inventory_window():
	if inventory_window_refresh_suspended:
		inventory_window_refresh_pending = true
		return
	if inventory_window == null:
		return
	if is_inventory_scene_window():
		refresh_inventory_scene_window()
		return
	var header_gem_label = inventory_window.get_node_or_null("HeaderGemLabel")
	if header_gem_label != null and header_gem_label is Label:
		header_gem_label.text = world.get_currency_display_text("gem")
	var selected_label = inventory_window.get_node_or_null("SelectedLabel")
	if selected_label != null:
		if trade_select_active:
			selected_label.text = "Select an item for trade, choose amount, then press Add To Trade."
		elif vend_select_active:
			selected_label.text = "Select an item for vending, choose stock amount, then press Add To Vending."
		elif safe_select_active:
			selected_label.text = "Select an item for the safe, choose amount, then press Add To Safe."
		elif donation_box_select_active:
			selected_label.text = "Select an item, choose an amount, then press Donate."
		elif display_select_active:
			selected_label.text = "Select one item to display."
		elif oil_refinery_battery_select_active:
			selected_label.text = "Select batteries for the oil refinery, choose amount, then press Add Battery."
		else:
			var selected_type = str(world.selected_item_type)
			var selected_category = str(world.selected_item_category)
			if selected_type != "" and selected_category != "":
				selected_label.text = "Selected: " + get_item_display_name(selected_type, selected_category)
			else:
				selected_label.text = ""
	apply_inventory_tab_shared_style()
	var visible_items = []
	if inventory_tab == "all" or inventory_tab == "blocks":
		for item_name in world.block_items:
			if world.item_database.has(item_name) and bool(world.item_database[item_name].get("hidden", false)):
				continue
			var count = int(world.inventory[item_name])
			if count > 0:
				visible_items.append({"type": item_name, "category": "block", "count": count})
	if inventory_tab == "all" or inventory_tab == "seeds":
		var seed_items = []
		for seed_name in world.seed_inventory.keys():
			seed_items.append(seed_name)
		seed_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for seed_name in seed_items:
			var count = int(world.seed_inventory[seed_name])
			if count > 0:
				visible_items.append({"type": seed_name, "category": "seed", "count": count})
	if inventory_tab == "all" or inventory_tab == "tools":
		var tool_items = []
		for tool_name in world.tool_inventory.keys():
			tool_items.append(tool_name)
		tool_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for tool_name in tool_items:
			if world.item_database.has(tool_name) and bool(world.item_database[tool_name].get("hidden", false)):
				continue
			var count = int(world.tool_inventory[tool_name])
			if count > 0:
				visible_items.append({"type": tool_name, "category": "tool", "count": count})
	if inventory_tab == "all" or inventory_tab == "materials":
		var material_items = []
		for material_name in world.material_inventory.keys():
			material_items.append(material_name)
		material_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for material_name in material_items:
			if world.item_database.has(material_name) and bool(world.item_database[material_name].get("hidden", false)):
				continue
			var count = int(world.material_inventory[material_name])
			if count > 0:
				visible_items.append({"type": material_name, "category": "material", "count": count})
		var lure_items = []
		for lure_name in world.lure_inventory.keys():
			lure_items.append(lure_name)
		lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for lure_name in lure_items:
			if world.item_database.has(lure_name) and bool(world.item_database[lure_name].get("hidden", false)):
				continue
			var count = int(world.lure_inventory[lure_name])
			if count > 0:
				visible_items.append({"type": lure_name, "category": "lure", "count": count})
		var fish_items = []
		for fish_name in world.fish_inventory.keys():
			fish_items.append(fish_name)
		fish_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for fish_name in fish_items:
			if world.item_database.has(fish_name) and bool(world.item_database[fish_name].get("hidden", false)):
				continue
			var fish_count: int = get_item_count(fish_name, "fish")
			if fish_count > 0:
				visible_items.append({"type": fish_name, "category": "fish", "count": fish_count})
	if inventory_tab == "all" or inventory_tab == "back":
		var back_items = []
		for back_name in world.back_inventory.keys():
			back_items.append(back_name)
		back_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for back_name in back_items:
			if world.item_database.has(back_name) and bool(world.item_database[back_name].get("hidden", false)):
				continue
			var count = int(world.back_inventory[back_name])
			if count > 0:
				visible_items.append({"type": back_name, "category": "back", "count": count})
		var hat_items = []
		for hat_name in world.hat_inventory.keys():
			hat_items.append(hat_name)
		hat_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for hat_name in hat_items:
			if world.item_database.has(hat_name) and bool(world.item_database[hat_name].get("hidden", false)):
				continue
			var count = int(world.hat_inventory[hat_name])
			if count > 0:
				visible_items.append({"type": hat_name, "category": "hat", "count": count})
		var hair_items = []
		for hair_name in world.hair_inventory.keys():
			hair_items.append(hair_name)
		hair_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for hair_name in hair_items:
			if world.item_database.has(hair_name) and bool(world.item_database[hair_name].get("hidden", false)):
				continue
			var count = int(world.hair_inventory[hair_name])
			if count > 0:
				visible_items.append({"type": hair_name, "category": "hair", "count": count})
		var eyewear_items = []
		for eyewear_name in world.eyewear_inventory.keys():
			eyewear_items.append(eyewear_name)
		eyewear_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for eyewear_name in eyewear_items:
			if world.item_database.has(eyewear_name) and bool(world.item_database[eyewear_name].get("hidden", false)):
				continue
			var count = int(world.eyewear_inventory[eyewear_name])
			if count > 0:
				visible_items.append({"type": eyewear_name, "category": "eyewear", "count": count})
		var shirt_items = []
		for shirt_name in world.shirt_inventory.keys():
			shirt_items.append(shirt_name)
		shirt_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for shirt_name in shirt_items:
			if world.item_database.has(shirt_name) and bool(world.item_database[shirt_name].get("hidden", false)):
				continue
			var count = int(world.shirt_inventory[shirt_name])
			if count > 0:
				visible_items.append({"type": shirt_name, "category": "shirt", "count": count})
		var pants_items = []
		for pants_name in world.pants_inventory.keys():
			pants_items.append(pants_name)
		pants_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for pants_name in pants_items:
			if world.item_database.has(pants_name) and bool(world.item_database[pants_name].get("hidden", false)):
				continue
			var count = int(world.pants_inventory[pants_name])
			if count > 0:
				visible_items.append({"type": pants_name, "category": "pants", "count": count})
		var shoes_items = []
		for shoes_name in world.shoes_inventory.keys():
			shoes_items.append(shoes_name)
		shoes_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for shoes_name in shoes_items:
			if world.item_database.has(shoes_name) and bool(world.item_database[shoes_name].get("hidden", false)):
				continue
			var count = int(world.shoes_inventory[shoes_name])
			if count > 0:
				visible_items.append({"type": shoes_name, "category": "shoes", "count": count})
		var ride_items = []
		for ride_name in world.ride_inventory.keys():
			ride_items.append(ride_name)
		ride_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
		for ride_name in ride_items:
			if world.item_database.has(ride_name) and bool(world.item_database[ride_name].get("hidden", false)):
				continue
			var count = int(world.ride_inventory[ride_name])
			if count > 0:
				visible_items.append({"type": ride_name, "category": "ride", "count": count})
	for slot_key in inventory_slots.keys():
		inventory_slots[slot_key].visible = false
	var filtered_items = []
	for item_data in visible_items:
		var item_type = item_data["type"]
		var category = item_data["category"]
		var display_name = get_item_display_name(item_type, category).to_lower()
		if inventory_search_text == "" or item_type.to_lower().find(inventory_search_text) != -1 or display_name.find(inventory_search_text) != -1:
			filtered_items.append(item_data)
	var grid_size = get_inventory_grid_view_size()
	var grid_width = grid_size.x
	var grid_height = grid_size.y
	if inventory_scroll_container != null:
		inventory_scroll_container.scroll_horizontal = 0
	var columns = max(1, int(floor((grid_width + INVENTORY_SLOT_GAP) / INVENTORY_SLOT_STEP)))
	var rows = max(1, int(ceil(float(filtered_items.size()) / float(columns))))
	if inventory_grid_root != null:
		inventory_grid_root.custom_minimum_size = Vector2(
			grid_width,
			max(grid_height, rows * INVENTORY_SLOT_STEP - INVENTORY_SLOT_GAP + INVENTORY_GRID_BOTTOM_PAD)
		)
		inventory_grid_root.size = inventory_grid_root.custom_minimum_size
	for i in range(filtered_items.size()):
		var item_data = filtered_items[i]
		var item_type = item_data["type"]
		var category = item_data["category"]
		var count = item_data["count"]
		var slot_key = category + ":" + item_type
		if not inventory_slots.has(slot_key):
			continue
		var slot = inventory_slots[slot_key]
		var column = i % columns
		var row = int(floor(float(i) / float(columns)))
		slot.position = Vector2(column * INVENTORY_SLOT_STEP, row * INVENTORY_SLOT_STEP)
		slot.visible = true
		var selected_key = world.selected_item_category + ":" + world.selected_item_type
		var detail_key = inventory_detail_item_category + ":" + inventory_detail_item_type
		var rarity = get_item_rarity(item_type, category)
		var hovered = bool(slot.get_meta("hovered", false))
		if slot_key == selected_key or slot_key == detail_key:
			apply_inventory_slot_style(slot, rarity, true, hovered)
		else:
			apply_inventory_slot_style(slot, rarity, false, hovered)
		var rarity_label = slot.get_node_or_null("Rarity")
		if rarity_label != null:
			rarity_label.visible = false
			rarity_label.text = ""
		var count_label = slot.get_node_or_null("Count")
		if count_label != null:
			if category == "fish" and float(count) > 0.0:
				count_label.text = format_inventory_amount(item_type, category, count)
			elif count > 1:
				count_label.text = format_stack_count(count)
			elif category == "tool" or category == "back" or category == "hat" or category == "hair" or category == "eyewear" or category == "shirt" or category == "pants" or category == "shoes" or category == "ride":
				count_label.text = str(count)
			else:
				count_label.text = ""
		var count_badge = slot.get_node_or_null("CountBadge")
		if count_badge != null:
			count_badge.visible = count_label != null and count_label.text != ""
			if count_badge is Panel:
				count_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
					Color(0.08, 0.20, 0.30, 0.72),
					Color(0.86, 0.98, 1.0, 0.36),
					1, 7, 1
				))
		var current_icon_texture: Texture2D = get_item_texture(item_type, category) as Texture2D
		var icon_shadow = slot.get_node_or_null("IconShadow")
		if icon_shadow != null:
			icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_shadow.texture = current_icon_texture
			icon_shadow.visible = current_icon_texture != null
		var icon = slot.get_node_or_null("Icon")
		if icon != null:
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = current_icon_texture
			if icon is TextureRect:
				update_seed_box_icon_overlay(icon, item_type, category)
		var name_label = slot.get_node_or_null("Name")
		if name_label != null:
			name_label.text = ""
			name_label.visible = false
		slot.tooltip_text = get_item_display_name(item_type, category) + " " + format_inventory_amount(item_type, category, count)
		var equipped_label = slot.get_node_or_null("EquippedLabel")
		if equipped_label != null:
			equipped_label.visible = (category == "tool" and world.equipped_tool == item_type) or (category == "back" and world.equipped_back_item == item_type) or (category == "hat" and world.equipped_hat_item == item_type) or (category == "hair" and world.equipped_hair_item == item_type) or (category == "eyewear" and world.equipped_eyewear_item == item_type) or (category == "shirt" and world.equipped_shirt_item == item_type) or (category == "pants" and world.equipped_pants_item == item_type) or (category == "shoes" and world.equipped_shoes_item == item_type) or (category == "ride" and world.equipped_ride_item == item_type)

	cache_visible_inventory_items(filtered_items)
	update_inventory_detail_panel()
