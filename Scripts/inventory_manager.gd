extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const HOTBAR_SLOT_COUNT = 6
const HOTBAR_HEIGHT = 104.0
const HOTBAR_SLOT_SIZE = 72
const HOTBAR_SLOT_GAP = 8
const HOTBAR_SLOT_STEP = HOTBAR_SLOT_SIZE + HOTBAR_SLOT_GAP
const HOTBAR_PAD_X = 12
const HOTBAR_PAD_Y = 9
const HOTBAR_HANDLE_HEIGHT = 24
const HOTBAR_INVENTORY_GAP = 0.0
const INVENTORY_DRAWER_WIDTH = 1100.0
const INVENTORY_DRAWER_HEIGHT = 560.0
const INVENTORY_OPEN_SPEED = 8.0
const INVENTORY_SETTLE_EPSILON = 0.002
const INVENTORY_RELEASE_OPEN_THRESHOLD = 0.50
const INVENTORY_RELEASE_VELOCITY_THRESHOLD = 0.72
const ITEM_HOLD_TIME = 0.45
const EQUIP_DOUBLE_TAP_TIME_MS = 350
const UI_STYLE_PATH = "res://Assets/ui/inventory/"
const UI_PANEL_MARGIN = 28.0
const UI_BUTTON_MARGIN = 22.0
const UI_SLOT_MARGIN = 24.0
const UI_TAB_MARGIN = 18.0
const INVENTORY_SLOT_SIZE = 82.0
const INVENTORY_SLOT_GAP = 16.0
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
var trade_select_blocker = null
var vend_select_active = false
var safe_select_active = false
var inventory_alive_time = 0.0
var ui_stylebox_cache = {}

var drag_handle_active = false
var drag_handle_start_y = 0.0
var drag_handle_start_amount = 0.0
var drag_handle_last_y = 0.0
var drag_handle_last_time_ms = 0
var drag_handle_velocity = 0.0

var inventory_gameplay_passthrough_call = false

var inventory_drawer_amount = 0.0
var inventory_drawer_target = 0.0



func get_ui_texture(file_name: String):
	var path = UI_STYLE_PATH + file_name
	if ResourceLoader.exists(path):
		return load(path)
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


func apply_inventory_kit_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14) -> bool:
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


func get_slot_texture_name(rarity: String, selected: bool) -> String:
	if selected:
		return "slot_selected.png"
	match rarity:
		"common":    return "slot_normal.png"
		"uncommon":  return "slot_normal.png"
		"rare":      return "slot_rare.png"
		"epic":      return "slot_epic.png"
		"legendary": return "slot_legendary.png"
		"currency":  return "slot_normal.png"
		_:           return "slot_normal.png"


func get_rarity_fill_color(rarity: String, alpha: float = 0.98) -> Color:
	match rarity:
		"uncommon":  return Color(0.08, 0.45, 0.22, alpha)
		"rare":      return Color(0.08, 0.28, 0.76, alpha)
		"epic":      return Color(0.36, 0.13, 0.70, alpha)
		"legendary": return Color(0.84, 0.46, 0.05, alpha)
		"currency":  return Color(0.03, 0.52, 0.62, alpha)
		_:           return Color(0.10, 0.24, 0.34, alpha)


func get_rarity_border_color(rarity: String) -> Color:
	match rarity:
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


func set_child_visible(root_node, node_name: String, is_visible: bool):
	if root_node == null:
		return
	var node = root_node.get_node_or_null(node_name)
	if node != null:
		node.visible = is_visible


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
	return clamp(screen_size.x * 0.035, 26.0, 76.0)


func get_inventory_window_size_for_viewport(screen_size: Vector2) -> Vector2:
	return Vector2(
		min(INVENTORY_DRAWER_WIDTH, max(420.0, screen_size.x - 32.0)),
		min(INVENTORY_DRAWER_HEIGHT, max(360.0, screen_size.y - 32.0))
	)


func get_hotbar_visual_height() -> float:
	return HOTBAR_SLOT_SIZE + HOTBAR_PAD_Y * 2 + HOTBAR_HANDLE_HEIGHT + 2


func get_hotbar_closed_y(screen_size: Vector2) -> float:
	return max(0.0, screen_size.y - get_hotbar_visual_height())


func get_hotbar_open_y(screen_size: Vector2) -> float:
	var window_size = get_inventory_window_size_for_viewport(screen_size)
	var unit_height = get_hotbar_visual_height() + HOTBAR_INVENTORY_GAP + window_size.y
	return clamp(screen_size.y - unit_height, 0.0, get_hotbar_closed_y(screen_size))


func get_inventory_drawer_drag_height() -> float:
	var screen_size = get_inventory_viewport_size()
	return max(120.0, get_hotbar_closed_y(screen_size) - get_hotbar_open_y(screen_size))


func refresh_inventory_window_for_viewport():
	if inventory_window == null:
		return

	var screen_size = get_inventory_viewport_size()
	if inventory_window_layout_size == Vector2.ZERO:
		inventory_window_layout_size = screen_size
		return

	if inventory_window_layout_size.distance_to(screen_size) <= 2.0:
		return

	var was_visible = inventory_window.visible
	setup_inventory_window()
	inventory_window.visible = was_visible


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
	glow.color = Color(0.38, 0.70, 1.0, 0.06)
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
	update_all_ui()


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
	update_gem_counter()
	update_inventory_window_position()
	update_inventory_ambient(delta)


func update_all_ui():
	update_hotbar()
	update_inventory_window()
	update_gem_counter()


func is_inventory_open() -> bool:
	if inventory_gameplay_passthrough_call:
		return false
	return inventory_drawer_amount > 0.05 or inventory_drawer_target > 0.05


func is_inventory_search_focused() -> bool:
	if inventory_search_input == null:
		return false
	return inventory_search_input.has_focus()


func _input(event):
	handle_inventory_gameplay_passthrough(event)


func handle_inventory_gameplay_passthrough(event):
	if world == null:
		return
	if trade_select_active or vend_select_active or safe_select_active:
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
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		if is_inventory_control_at_point(event.position):
			return
		use_selected_item_passthrough()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
		if is_inventory_control_at_point(event.position):
			return
		use_selected_item_passthrough()
		get_viewport().set_input_as_handled()


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
	update_hotbar()
	update_inventory_window()
	update_gem_counter()


func control_contains_point(control, point: Vector2) -> bool:
	if control == null or not (control is Control):
		return false
	if not control.visible:
		return false
	return control.get_global_rect().has_point(point)


func is_inventory_control_at_point(point: Vector2) -> bool:
	if control_contains_point(inventory_search_input, point):
		return true
	if control_contains_point(inventory_button, point):
		return true
	if control_contains_point(hotbar_handle, point):
		return true
	for slot_index in hotbar_slots.keys():
		if control_contains_point(hotbar_slots[slot_index], point):
			return true
	if inventory_window != null:
		var close_button = inventory_window.get_node_or_null("CloseButton")
		if control_contains_point(close_button, point):
			return true
	for tab_name in inventory_tab_buttons.keys():
		if control_contains_point(inventory_tab_buttons[tab_name], point):
			return true
	for slot_key in inventory_slots.keys():
		if control_contains_point(inventory_slots[slot_key], point):
			return true
	if inventory_detail_panel != null and control_contains_point(inventory_detail_panel, point):
		return true
	if item_context_menu != null and item_context_menu.visible and control_contains_point(item_context_menu, point):
		return true
	if inventory_scroll_container != null and control_contains_point(inventory_scroll_container, point):
		return true
	return false


func begin_trade_item_select(slot_index: int):
	trade_select_active = true
	trade_select_slot_index = slot_index
	vend_select_active = false
	safe_select_active = false
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = 240
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
		inventory_window.z_index = 90
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
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = 240
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
		inventory_window.z_index = 90
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_vend_item_selecting() -> bool:
	return vend_select_active


func begin_safe_item_select():
	safe_select_active = true
	vend_select_active = false
	trade_select_active = false
	trade_select_slot_index = -1
	hide_item_context_menu()
	show_trade_select_blocker()
	if inventory_window != null:
		inventory_window.visible = true
		inventory_window.z_index = 240
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
		inventory_window.z_index = 90
	if close_drawer:
		inventory_drawer_target = 0.0
		if inventory_search_input != null:
			inventory_search_input.release_focus()
	update_inventory_window()


func is_safe_item_selecting() -> bool:
	return safe_select_active


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
	if not trade_select_active and not vend_select_active and not safe_select_active:
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()


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
	if item_type == "world_lock":
		return false
	if item_type == "vend_empty" or item_type == "vend_pending" or item_type == "vend_sold":
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


func can_drop_item_from_inventory(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if item_type == "punch":
		return false
	if world != null and world.item_database.has(item_type):
		return bool(world.item_database[item_type].get("dropable", true))
	return true


func select_hotbar_slot(slot_index: int):
	if slot_index < 0 or slot_index >= world.hotbar_items.size():
		return
	var item_type = world.hotbar_items[slot_index]
	var category = world.hotbar_item_categories[slot_index]
	if item_type == "" or category == "empty":
		return
	world.select_item(item_type, category)


func assign_item_to_quick_hotbar(item_type: String, category: String):
	if item_type == "" or category == "" or category == "empty":
		return
	if item_type == "punch" or item_type == "wrench":
		return
	normalize_hotbar()
	for i in range(world.hotbar_items.size() - 1, 0, -1):
		if world.hotbar_items[i] == item_type and world.hotbar_item_categories[i] == category:
			world.hotbar_items.remove_at(i)
			world.hotbar_item_categories.remove_at(i)
	world.hotbar_items.insert(1, item_type)
	world.hotbar_item_categories.insert(1, category)
	while world.hotbar_items.size() > HOTBAR_SLOT_COUNT:
		world.hotbar_items.pop_back()
		world.hotbar_item_categories.pop_back()
	normalize_hotbar()
	setup_hotbar()


func can_show_in_hotbar(item_type: String, category: String, allow_empty_count: bool = false) -> bool:
	if item_type == "" or category == "empty":
		return false
	if category == "currency":
		return false
	if category == "tool":
		return item_type == "punch" or item_type == "wrench"
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
	for i in range(1, world.hotbar_items.size()):
		var item_type = world.hotbar_items[i]
		var category = world.hotbar_item_categories[i]
		var is_selected_pin = world.selected_item_category == category and world.selected_item_type == item_type
		append_hotbar_item(new_items, new_categories, item_type, category, is_selected_pin)

	if world.selected_item_category != "tool" and not hotbar_contains(new_items, new_categories, world.selected_item_type, world.selected_item_category):
		if can_show_in_hotbar(world.selected_item_type, world.selected_item_category, true):
			new_items.insert(1, world.selected_item_type)
			new_categories.insert(1, world.selected_item_category)

	for block_name in world.block_items:
		append_hotbar_item(new_items, new_categories, block_name, "block")
	var seed_items = []
	for seed_name in world.seed_inventory.keys():
		seed_items.append(seed_name)
	seed_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for seed_name in seed_items:
		append_hotbar_item(new_items, new_categories, seed_name, "seed")
	var lure_items = []
	for lure_name in world.lure_inventory.keys():
		lure_items.append(lure_name)
	lure_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for lure_name in lure_items:
		append_hotbar_item(new_items, new_categories, lure_name, "lure")
	while new_items.size() > HOTBAR_SLOT_COUNT:
		new_items.pop_back()
		new_categories.pop_back()
	world.hotbar_items = new_items
	world.hotbar_item_categories = new_categories
	if world.selected_item_category != "tool":
		if not can_show_in_hotbar(world.selected_item_type, world.selected_item_category, true):
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
	if category == "hair":
		if world.hair_textures.has(item_type):
			return world.hair_textures[item_type]
	if category == "shirt":
		if world.shirt_textures.has(item_type):
			return world.shirt_textures[item_type]
	if category == "pants":
		if world.pants_textures.has(item_type):
			return world.pants_textures[item_type]
	if category == "shoes":
		if world.shoes_textures.has(item_type):
			return world.shoes_textures[item_type]
	if world.item_database.has(item_type):
		var texture = AtlasTextureFactory.load_texture(world.item_database[item_type].get("texture", null))
		if texture != null:
			return texture
	return null


func get_inventory_icon_texture(item_type: String, category: String):
	if world != null and world.has_method("get_inventory_icon_texture"):
		return world.get_inventory_icon_texture(item_type, category)

	return null


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
		return int(ceil(max(0.0, float(world.fish_inventory[item_type]))))
	if category == "currency" and world.currency_inventory.has(item_type):
		return int(world.currency_inventory[item_type])
	if category == "back" and world.back_inventory.has(item_type):
		return int(world.back_inventory[item_type])
	if category == "hair" and world.hair_inventory.has(item_type):
		return int(world.hair_inventory[item_type])
	if category == "shirt" and world.shirt_inventory.has(item_type):
		return int(world.shirt_inventory[item_type])
	if category == "pants" and world.pants_inventory.has(item_type):
		return int(world.pants_inventory[item_type])
	if category == "shoes" and world.shoes_inventory.has(item_type):
		return int(world.shoes_inventory[item_type])
	return 0


func get_fish_weight_lb(item_type: String) -> float:
	if world == null or not world.fish_inventory.has(item_type):
		return 0.0
	return normalize_fish_weight(world.fish_inventory[item_type])


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


func fish_weight_to_tenths(weight) -> int:
	var value := 0.0
	if weight is int or weight is float:
		value = float(weight)
	elif weight is String:
		var text = weight.strip_edges()
		if text.is_valid_float():
			value = float(text)
	if not is_finite(value) or value <= 0.0:
		return 0
	return max(0, int(round(value * 10.0)))


func fish_tenths_to_weight(tenths: int) -> float:
	return float(max(0, tenths)) / 10.0


func normalize_fish_weight(weight) -> float:
	return fish_tenths_to_weight(fish_weight_to_tenths(weight))


func get_item_weight_tenths(item_id: String) -> int:
	if world == null or not world.fish_inventory.has(item_id):
		return 0
	return fish_weight_to_tenths(world.fish_inventory[item_id])


func has_fish_weight(item_id: String, weight) -> bool:
	var requested_tenths: int = fish_weight_to_tenths(weight)
	if requested_tenths <= 0:
		return false
	return get_item_weight_tenths(item_id) >= requested_tenths


func add_fish_weight(item_id: String, weight) -> bool:
	if world == null or item_id == "" or not is_weight_item(item_id):
		return false
	var add_tenths: int = fish_weight_to_tenths(weight)
	if add_tenths <= 0:
		return false
	var current_tenths: int = get_item_weight_tenths(item_id)
	world.fish_inventory[item_id] = fish_tenths_to_weight(current_tenths + add_tenths)
	return true


func remove_fish_weight(item_id: String, weight, show_error: bool = false) -> bool:
	if world == null or item_id == "" or not is_weight_item(item_id):
		return false
	var requested_tenths: int = fish_weight_to_tenths(weight)
	if requested_tenths <= 0:
		if show_error and world.has_method("show_notification"):
			world.show_notification("Choose at least 0.1 lb.")
		return false
	var current_tenths: int = get_item_weight_tenths(item_id)
	if current_tenths < requested_tenths:
		if show_error and world.has_method("show_notification"):
			world.show_notification("You only have " + format_fish_weight(fish_tenths_to_weight(current_tenths)) + ".")
		return false
	var remaining_tenths: int = max(0, current_tenths - requested_tenths)
	if remaining_tenths <= 0:
		world.fish_inventory.erase(item_id)
	else:
		world.fish_inventory[item_id] = fish_tenths_to_weight(remaining_tenths)
	return true


func format_fish_weight(amount) -> String:
	return "%.1f lb" % normalize_fish_weight(amount)


func format_inventory_amount(item_type: String, category: String, amount = null) -> String:
	if category == "fish":
		return format_fish_weight(get_fish_weight_lb(item_type) if amount == null else amount)
	return "x" + str(int(amount) if amount != null else get_item_count(item_type, category))


func get_item_display_name(item_type: String, category: String) -> String:
	if category == "tool" and item_type == "punch":
		return "Punch"
	if world.item_database.has(item_type):
		return str(world.item_database[item_type].get("display_name", item_type.capitalize()))
	if category == "seed":
		return item_type.replace("_seed", "").capitalize() + " Seed"
	return item_type.capitalize()


func setup_hotbar():
	normalize_hotbar()
	if ui_layer_ref == null:
		return
	hotbar_root = ui_layer_ref.get_node_or_null("Hotbar")
	if hotbar_root == null:
		hotbar_root = Control.new()
		hotbar_root.name = "Hotbar"
		ui_layer_ref.add_child(hotbar_root)
	hotbar_root.z_index = 110
	hotbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in hotbar_root.get_children():
		child.queue_free()
	hotbar_slots.clear()
	var slot_count  = world.hotbar_items.size()
	var bar_w       = slot_count * HOTBAR_SLOT_STEP - HOTBAR_SLOT_GAP + HOTBAR_PAD_X * 2
	var bar_h       = HOTBAR_SLOT_SIZE + HOTBAR_PAD_Y * 2
	var handle_w    = min(172.0, max(142.0, bar_w - 20.0))
	hotbar_handle = Panel.new()
	hotbar_handle.name = "InventorySlideHandle"
	hotbar_handle.position = Vector2((bar_w - handle_w) * 0.5, 0)
	hotbar_handle.size = Vector2(handle_w, HOTBAR_HANDLE_HEIGHT)
	hotbar_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	hotbar_handle.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.025, 0.059, 0.114, 0.95), Color(0.22, 0.60, 1.0, 0.62), 3, 12, 7))
	hotbar_handle.gui_input.connect(_on_hotbar_handle_gui_input)
	hotbar_root.add_child(hotbar_handle)
	var handle_top = ColorRect.new()
	handle_top.name = "HandleTopAccent"
	handle_top.position = Vector2(0, 0)
	handle_top.size = Vector2(handle_w, 2)
	handle_top.color = Color(0.78, 0.94, 1.0, 0.82)
	handle_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_handle.add_child(handle_top)
	var handle_label = Label.new()
	handle_label.name = "HandleLabel"
	handle_label.text = "BAG"
	handle_label.position = Vector2(0, 3)
	handle_label.size = Vector2(handle_w, 16)
	handle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(handle_label, 11)
	hotbar_handle.add_child(handle_label)
	var bar_border = Panel.new()
	bar_border.name = "BarBorder"
	bar_border.position = Vector2(0, HOTBAR_HANDLE_HEIGHT)
	bar_border.size = Vector2(bar_w + 2, bar_h + 2)
	bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_border.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.022, 0.034, 0.075, 0.88), Color(0.04, 0.16, 0.28, 0.92), 3, 14, 8))
	hotbar_root.add_child(bar_border)
	var bar_bg = ColorRect.new()
	bar_bg.name = "BarBackground"
	bar_bg.position = Vector2(1, HOTBAR_HANDLE_HEIGHT + 1)
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.color = Color(0.022, 0.047, 0.102, 0.90)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_root.add_child(bar_bg)
	var shimmer = ColorRect.new()
	shimmer.name = "Shimmer"
	shimmer.position = Vector2(8, HOTBAR_HANDLE_HEIGHT + 4)
	shimmer.size = Vector2(bar_w - 14, 2)
	shimmer.color = Color(0.78, 0.94, 1.0, 0.22)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_root.add_child(shimmer)
	var bottom_glow = ColorRect.new()
	bottom_glow.name = "BottomGlow"
	bottom_glow.position = Vector2(10, HOTBAR_HANDLE_HEIGHT + bar_h - 6)
	bottom_glow.size = Vector2(bar_w - 18, 3)
	bottom_glow.color = Color(0.70, 0.32, 1.0, 0.16)
	bottom_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_root.add_child(bottom_glow)
	var sep_x = HOTBAR_PAD_X + HOTBAR_SLOT_STEP - int(floor(float(HOTBAR_SLOT_GAP) * 0.5)) + 1
	var sep = ColorRect.new()
	sep.name = "ToolSeparator"
	sep.position = Vector2(sep_x, HOTBAR_HANDLE_HEIGHT + 8)
	sep.size = Vector2(1, bar_h - 10)
	sep.color = Color(0.38, 0.68, 0.78, 0.24)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_root.add_child(sep)
	for i in range(slot_count):
		var item_type = world.hotbar_items[i]
		var category  = world.hotbar_item_categories[i]
		var is_tool_slot = (i == 0)
		var slot_x = HOTBAR_PAD_X + i * HOTBAR_SLOT_STEP + 1
		var slot_y = HOTBAR_PAD_Y + HOTBAR_HANDLE_HEIGHT + 1
		var slot = Panel.new()
		slot.name = "Slot_" + str(i)
		slot.position = Vector2(slot_x, slot_y)
		slot.size = Vector2(HOTBAR_SLOT_SIZE, HOTBAR_SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_hotbar_slot_gui_input.bind(i))
		slot.set_meta("item_type", item_type)
		slot.set_meta("category", category)
		hotbar_root.add_child(slot)
		slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.12, 0.27, 0.52, 0.48) if is_tool_slot else Color(0.09, 0.18, 0.38, 0.48), Color(0.34, 0.78, 1.0, 0.30), 3, 13, 4))
		var inner = Panel.new()
		inner.name = "Inner"
		inner.position = Vector2(2, 2)
		inner.size = Vector2(HOTBAR_SLOT_SIZE - 4, HOTBAR_SLOT_SIZE - 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.016, 0.042, 0.086, 0.54), Color(0.54, 0.84, 1.0, 0.16), 2, 10, 1))
		slot.add_child(inner)
		var hotbar_top_shine = ColorRect.new()
		hotbar_top_shine.name = "TopShine"
		hotbar_top_shine.position = Vector2(11, 8)
		hotbar_top_shine.size = Vector2(HOTBAR_SLOT_SIZE - 22, 2)
		hotbar_top_shine.color = Color(1.0, 1.0, 1.0, 0.09)
		hotbar_top_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(hotbar_top_shine)
		var hotbar_bottom_shade = ColorRect.new()
		hotbar_bottom_shade.name = "BottomShade"
		hotbar_bottom_shade.position = Vector2(11, HOTBAR_SLOT_SIZE - 12)
		hotbar_bottom_shade.size = Vector2(HOTBAR_SLOT_SIZE - 22, 3)
		hotbar_bottom_shade.color = Color(0.0, 0.0, 0.0, 0.18)
		hotbar_bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(hotbar_bottom_shade)
		var slot_number = Label.new()
		slot_number.name = "SlotNumber"
		slot_number.text = str(i + 1)
		slot_number.position = Vector2(4, 2)
		slot_number.size = Vector2(18, 14)
		slot_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_number.add_theme_font_size_override("font_size", 10)
		slot_number.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0, 0.80))
		slot.add_child(slot_number)
		var rarity_pip = Panel.new()
		rarity_pip.name = "RarityPip"
		rarity_pip.position = Vector2(HOTBAR_SLOT_SIZE - 17, 5)
		rarity_pip.size = Vector2(10, 10)
		rarity_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rarity_pip.visible = not is_tool_slot
		rarity_pip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			get_rarity_fill_color(get_item_rarity(item_type, category), 0.95),
			get_rarity_border_color(get_item_rarity(item_type, category)),
			2, 5, 1
		))
		slot.add_child(rarity_pip)
		if category == "tool" and item_type == "punch":
			var punch_texture: Texture2D = load_hotbar_punch_icon_texture()
			if punch_texture == null:
				var lbl = Label.new()
				lbl.name = "PunchIcon"
				lbl.text = "P"
				lbl.position = Vector2(0, 4)
				lbl.size = Vector2(HOTBAR_SLOT_SIZE, 42)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl.add_theme_font_size_override("font_size", 32)
				lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.95))
				lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
				lbl.add_theme_constant_override("outline_size", 2)
				slot.add_child(lbl)
			else:
				var punch_icon_size = Vector2(HOTBAR_SLOT_SIZE - 16, HOTBAR_SLOT_SIZE - 16)
				var punch_icon_shadow = TextureRect.new()
				punch_icon_shadow.name = "PunchIconShadow"
				punch_icon_shadow.texture = punch_texture
				punch_icon_shadow.position = Vector2(11, 12)
				punch_icon_shadow.size = punch_icon_size
				punch_icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				punch_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				punch_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.34)
				punch_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(punch_icon_shadow)

				var punch_icon = TextureRect.new()
				punch_icon.name = "PunchIcon"
				punch_icon.texture = punch_texture
				punch_icon.position = Vector2(8, 7)
				punch_icon.size = punch_icon_size
				punch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				punch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				punch_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
				punch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(punch_icon)
		elif category == "tool" and item_type == "wrench":
			var wrench_texture: Texture2D = load_hotbar_wrench_icon_texture()
			if wrench_texture == null:
				var lbl = Label.new()
				lbl.name = "WrenchIcon"
				lbl.text = "W"
				lbl.position = Vector2(0, 5)
				lbl.size = Vector2(HOTBAR_SLOT_SIZE, 42)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl.add_theme_font_size_override("font_size", 30)
				lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 0.95))
				lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
				lbl.add_theme_constant_override("outline_size", 2)
				slot.add_child(lbl)
			else:
				var wrench_icon_size = Vector2(HOTBAR_SLOT_SIZE - 16, HOTBAR_SLOT_SIZE - 16)
				var wrench_icon_shadow = TextureRect.new()
				wrench_icon_shadow.name = "WrenchIconShadow"
				wrench_icon_shadow.texture = wrench_texture
				wrench_icon_shadow.position = Vector2(11, 12)
				wrench_icon_shadow.size = wrench_icon_size
				wrench_icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				wrench_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				wrench_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.34)
				wrench_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(wrench_icon_shadow)

				var wrench_icon = TextureRect.new()
				wrench_icon.name = "WrenchIcon"
				wrench_icon.texture = wrench_texture
				wrench_icon.position = Vector2(8, 7)
				wrench_icon.size = wrench_icon_size
				wrench_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				wrench_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				wrench_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
				wrench_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(wrench_icon)
		else:
			var icon_shadow = TextureRect.new()
			icon_shadow.name = "IconShadow"
			icon_shadow.position = Vector2(13, 13)
			icon_shadow.size = Vector2(HOTBAR_SLOT_SIZE - 20, HOTBAR_SLOT_SIZE - 20)
			icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.26)
			icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_shadow.texture = get_item_texture(item_type, category)
			slot.add_child(icon_shadow)
			var icon = TextureRect.new()
			icon.name = "Icon"
			icon.position = Vector2(10, 9)
			icon.size = Vector2(HOTBAR_SLOT_SIZE - 20, HOTBAR_SLOT_SIZE - 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = get_item_texture(item_type, category)
			slot.add_child(icon)
		var count_badge = Panel.new()
		count_badge.name = "CountBadge"
		count_badge.position = Vector2(HOTBAR_SLOT_SIZE - 56, HOTBAR_SLOT_SIZE - 22)
		count_badge.size = Vector2(52, 18)
		count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_badge.visible = false
		count_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.00, 0.03, 0.06, 0.82),
			Color(0.66, 0.90, 1.0, 0.34),
			1, 8, 0
		))
		slot.add_child(count_badge)
		var count_lbl = Label.new()
		count_lbl.name = "Count"
		count_lbl.position = Vector2(HOTBAR_SLOT_SIZE - 56, HOTBAR_SLOT_SIZE - 22)
		count_lbl.size = Vector2(50, 18)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.96, 1.0))
		count_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		count_lbl.add_theme_constant_override("outline_size", 2)
		slot.add_child(count_lbl)
		hotbar_slots[i] = slot
	update_hotbar_position()
	update_hotbar()


func _on_hotbar_handle_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_handle_active = true
			drag_handle_start_y = get_viewport().get_mouse_position().y
			drag_handle_start_amount = inventory_drawer_amount
			drag_handle_last_y = drag_handle_start_y
			drag_handle_last_time_ms = Time.get_ticks_msec()
			drag_handle_velocity = 0.0
		else:
			finish_handle_drag()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and drag_handle_active:
		update_drawer_drag(get_viewport().get_mouse_position().y)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed:
			drag_handle_active = true
			drag_handle_start_y = event.position.y
			drag_handle_start_amount = inventory_drawer_amount
			drag_handle_last_y = drag_handle_start_y
			drag_handle_last_time_ms = Time.get_ticks_msec()
			drag_handle_velocity = 0.0
		else:
			finish_handle_drag()
		get_viewport().set_input_as_handled()
	if event is InputEventScreenDrag and drag_handle_active:
		update_drawer_drag(event.position.y)
		get_viewport().set_input_as_handled()


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
	inventory_drawer_target = clamp(inventory_drawer_amount, 0.0, 1.0)
	drag_handle_velocity = 0.0
	update_inventory_window()


func get_hotbar_anchor_open_y() -> float:
	if hotbar_root != null:
		return hotbar_root.position.y + get_hotbar_visual_height()
	var screen_size = get_inventory_viewport_size()
	return lerp(get_hotbar_closed_y(screen_size), get_hotbar_open_y(screen_size), inventory_drawer_amount) + get_hotbar_visual_height()


func _on_hotbar_slot_gui_input(event: InputEvent, slot_index: int):
	if slot_index < 0 or slot_index >= world.hotbar_items.size():
		return
	var item_type = world.hotbar_items[slot_index]
	var category = world.hotbar_item_categories[slot_index]
	var slot = null
	if hotbar_slots.has(slot_index):
		slot = hotbar_slots[slot_index]
	if trade_select_active or vend_select_active or safe_select_active:
		var selectable = can_select_item_for_trade(item_type, category)
		if vend_select_active:
			selectable = can_select_item_for_vend(item_type, category)
		elif safe_select_active:
			selectable = can_select_item_for_safe(item_type, category)
		if not selectable:
			if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			show_item_context_menu(item_type, category, slot)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.pressed:
			show_item_context_menu(item_type, category, slot)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
			return
	if slot_index == 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var now = Time.get_ticks_msec()
			var is_double_tap = event.double_click or (now - hotbar_slot_zero_last_tap_ms <= 350)
			hotbar_slot_zero_last_tap_ms = now
			if is_double_tap and world.has_method("toggle_primary_hotbar_tool"):
				world.toggle_primary_hotbar_tool()
			else:
				world.select_item(item_type, category)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.pressed:
			var now_touch = Time.get_ticks_msec()
			var is_double_touch = now_touch - hotbar_slot_zero_last_tap_ms <= 350
			hotbar_slot_zero_last_tap_ms = now_touch
			if is_double_touch and world.has_method("toggle_primary_hotbar_tool"):
				world.toggle_primary_hotbar_tool()
			else:
				world.select_item(item_type, category)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			show_item_context_menu(item_type, category, slot)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_item_hold(item_type, category, slot, event.double_click, "hotbar")
			else:
				finish_item_hold(item_type, category)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			start_item_hold(item_type, category, slot, is_equip_double_tap(item_type, category, "hotbar"), "hotbar")
		else:
			finish_item_hold(item_type, category)
		get_viewport().set_input_as_handled()


func get_hotbar_visual_width() -> float:
	if world == null or world.hotbar_items.size() <= 0:
		return float(HOTBAR_SLOT_SIZE)
	var slot_count = world.hotbar_items.size()
	return float(slot_count * HOTBAR_SLOT_STEP - HOTBAR_SLOT_GAP + HOTBAR_PAD_X * 2 + 2)


func update_hotbar_position():
	if hotbar_root == null:
		return
	var hotbar_visible: bool = not is_gameplay_hud_blocked()
	hotbar_root.visible = hotbar_visible
	if not hotbar_visible:
		return
	var screen_size = get_inventory_viewport_size()
	var bar_total_w = get_hotbar_visual_width()
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
	normalize_hotbar()
	if hotbar_visuals_need_rebuild():
		setup_hotbar()
		return
	for i in range(world.hotbar_items.size()):
		if not hotbar_slots.has(i):
			continue
		var item_type = world.hotbar_items[i]
		var category = world.hotbar_item_categories[i]
		var slot = hotbar_slots[i]
		var is_selected  = world.selected_item_category == category and world.selected_item_type == item_type
		var is_tool_slot = (i == 0)
		var inner = slot.get_node_or_null("Inner")
		var count = slot.get_node_or_null("Count")
		var count_badge = slot.get_node_or_null("CountBadge")
		var rarity_pip = slot.get_node_or_null("RarityPip")
		var top_shine = slot.get_node_or_null("TopShine")
		var bottom_shade = slot.get_node_or_null("BottomShade")
		var rarity = get_item_rarity(item_type, category)
		if is_selected:
			slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.93), Color(1.0, 0.88, 0.30, 0.95), 4, 13, 7))
			if inner != null and inner is Panel:
				inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.38, 0.22, 0.045, 0.76), Color(1.0, 0.90, 0.40, 0.52), 2, 10, 2))
		elif is_tool_slot:
			slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.16, 0.35, 0.62, 0.58), Color(0.26, 0.74, 1.0, 0.52), 3, 13, 5))
			if inner != null and inner is Panel:
				inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.022, 0.050, 0.095, 0.52), Color(0.64, 0.90, 1.0, 0.20), 2, 10, 1))
		else:
			slot.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.10, 0.22, 0.46, 0.52), Color(0.26, 0.66, 1.0, 0.40), 3, 13, 5))
			if inner != null and inner is Panel:
				inner.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.022, 0.050, 0.105, 0.50), Color(0.58, 0.84, 1.0, 0.16), 2, 10, 1))
		if top_shine != null and top_shine is ColorRect:
			top_shine.visible = true
			top_shine.color = Color(1.0, 1.0, 1.0, 0.18 if is_selected else 0.09)
		if bottom_shade != null and bottom_shade is ColorRect:
			bottom_shade.visible = true
			bottom_shade.color = Color(0.0, 0.0, 0.0, 0.24 if is_selected else 0.18)
		if rarity_pip != null and rarity_pip is Panel:
			rarity_pip.visible = not is_tool_slot
			rarity_pip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				get_rarity_fill_color(rarity, 0.95),
				get_rarity_border_color(rarity),
				2, 5, 1
			))
		if count != null:
			if category == "tool":
				count.text = ""
			elif category == "fish":
				var fish_weight = get_fish_weight_lb(item_type)
				count.text = format_inventory_amount(item_type, category, fish_weight) if fish_weight > 0.0 else ""
			else:
				var qty = get_item_count(item_type, category)
				count.text = "x" + format_stack_count(qty) if qty > 0 else ""
			if count_badge != null:
				count_badge.visible = count.text != ""


func setup_inventory_button():
	if ui_layer_ref == null:
		return
	inventory_button = ui_layer_ref.get_node_or_null("InventoryButton")
	if inventory_button == null:
		inventory_button = Button.new()
		inventory_button.name = "InventoryButton"
		ui_layer_ref.add_child(inventory_button)
	inventory_button.text = ""
	inventory_button.size = BAG_BUTTON_SIZE
	inventory_button.z_index = 80
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
	var screen_size = get_viewport_rect().size
	var button_x: float = screen_size.x - 124.0
	if inventory_button.size.x <= 72.0:
		button_x = screen_size.x - 102.0
	inventory_button.position = Vector2(max(8.0, button_x), 88)


func setup_gem_counter():
	if ui_layer_ref == null:
		return
	gem_panel = ui_layer_ref.get_node_or_null("GemPanel")
	if gem_panel == null:
		gem_panel = Control.new()
		gem_panel.name = "GemPanel"
		ui_layer_ref.add_child(gem_panel)
	gem_panel.size = Vector2(232, 36)
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
	if gem_icon != null:
		if world.currency_textures.has("gem"):
			gem_icon.texture = world.currency_textures["gem"]
	if gem_count_label != null:
		gem_count_label.text = "x" + world.get_currency_display_text("gem")
	var header_gem_label = null
	if inventory_window != null:
		header_gem_label = inventory_window.get_node_or_null("HeaderGemLabel")
	if header_gem_label != null and header_gem_label is Label:
		header_gem_label.text = world.get_currency_display_text("gem")


func is_floating_hud_blocked() -> bool:
	if world != null and world.has_method("is_movement_blocking_ui_open"):
		return bool(world.is_movement_blocking_ui_open())

	return false


func is_gameplay_hud_blocked() -> bool:
	if world != null and world.has_method("is_gameplay_hud_blocked"):
		return bool(world.is_gameplay_hud_blocked())

	if world != null and world.has_method("is_movement_blocking_ui_open"):
		return bool(world.is_movement_blocking_ui_open()) and not is_inventory_open()

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


func setup_inventory_window():
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
	inventory_window.z_index = 90
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
		"back", "hair", "shirt", "pants", "shoes":
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


func set_inventory_detail_node_visible(node_name: String, is_visible: bool):
	if inventory_detail_panel == null:
		return
	var node = inventory_detail_panel.get_node_or_null(node_name)
	if node != null:
		node.visible = is_visible


func select_inventory_detail_item(item_type: String, category: String):
	if item_type == "" or category == "" or category == "empty":
		return
	inventory_detail_item_type = item_type
	inventory_detail_item_category = category
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = get_slot_for_item(item_type, category)
	if category == "fish":
		setup_fish_weight_controls(get_fish_weight_lb(item_type))
	else:
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

	var name_label = inventory_detail_panel.get_node_or_null("DetailName")
	if name_label != null and name_label is Label:
		name_label.text = display_name

	var meta_label = inventory_detail_panel.get_node_or_null("DetailMeta")
	if meta_label != null and meta_label is Label:
		meta_label.text = category.capitalize() + "  |  " + get_rarity_display_name(rarity) + "  |  " + format_inventory_amount(item_type, category, get_fish_weight_lb(item_type) if category == "fish" else count)
		meta_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 1.0))

	var description = inventory_detail_panel.get_node_or_null("DetailDescription")
	if description != null and description is Label:
		description.text = get_item_description(item_type, category)

	if category == "fish":
		setup_fish_weight_controls(get_fish_weight_lb(item_type))
		var amount_title = inventory_detail_panel.get_node_or_null("AmountLabel")
		if amount_title != null and amount_title is Label:
			amount_title.text = "Weight"
	else:
		setup_context_amount_controls(count)
		var amount_title = inventory_detail_panel.get_node_or_null("AmountLabel")
		if amount_title != null and amount_title is Label:
			amount_title.text = "Amount"

	var trade_mode = trade_select_active or vend_select_active or safe_select_active
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
	var available_amount: float = get_fish_weight_lb(item_type) if category == "fish" else float(get_item_count(item_type, category))
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

	var remaining_amount: float = get_fish_weight_lb(item_type) if category == "fish" else float(get_item_count(item_type, category))
	if remaining_amount <= 0.0:
		inventory_detail_item_type = ""
		inventory_detail_item_category = ""
	update_inventory_window()
	update_hotbar()


func _on_inventory_search_changed(new_text: String):
	hide_item_context_menu()
	inventory_search_text = new_text.strip_edges().to_lower()
	if inventory_scroll_container != null:
		inventory_scroll_container.scroll_vertical = 0
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
	update_inventory_window()


func _on_inventory_tab_gui_input(event: InputEvent, tab_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_tab_pressed(tab_name)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		_on_inventory_tab_pressed(tab_name)
		get_viewport().set_input_as_handled()


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
		return str(world.item_database[item_type].get("rarity", "common"))
	return "common"


func get_rarity_display_name(rarity: String) -> String:
	match rarity:
		"common":    return "Common"
		"uncommon":  return "Uncommon"
		"rare":      return "Rare"
		"epic":      return "Epic"
		"legendary": return "Legendary"
		"currency":  return "Currency"
		_:           return rarity.capitalize()


func get_rarity_color(rarity: String) -> Color:
	match rarity:
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
	var rarity_badge = slot.get_node_or_null("RarityBadge")
	if rarity_badge != null and rarity_badge is Panel:
		rarity_badge.visible = true
		rarity_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			get_rarity_fill_color(rarity, 0.96),
			get_rarity_border_color(rarity),
			2, 8, 1
		))
	var rarity_label = slot.get_node_or_null("Rarity")
	if rarity_label != null and rarity_label is Label:
		rarity_label.visible = true


func get_rarity_letter_color(rarity: String) -> Color:
	match rarity:
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
	var hair_items = []
	for hair_name in world.hair_inventory.keys():
		hair_items.append(hair_name)
	hair_items.sort_custom(Callable(self, "sort_item_ids_by_order"))
	for hair_name in hair_items:
		if world.item_database.has(hair_name) and bool(world.item_database[hair_name].get("hidden", false)):
			continue
		all_slot_keys.append("hair:" + hair_name)
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
	for slot_key in all_slot_keys:
		var parts = slot_key.split(":")
		var category = parts[0]
		var item_type = parts[1]
		var slot = Panel.new()
		slot.name = "Slot_" + slot_key
		slot.size = Vector2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
		slot.visible = false
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if trade_select_active or vend_select_active or safe_select_active:
		var selectable = can_select_item_for_trade(item_type, category)
		if vend_select_active:
			selectable = can_select_item_for_vend(item_type, category)
		elif safe_select_active:
			selectable = can_select_item_for_safe(item_type, category)
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			if not selectable:
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				get_viewport().set_input_as_handled()
				return
			select_inventory_detail_item(item_type, category)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.pressed:
			if not selectable:
				if world != null and world.has_method("show_notification"):
					world.show_notification("That item cannot be selected.")
				get_viewport().set_input_as_handled()
				return
			select_inventory_detail_item(item_type, category)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			select_inventory_detail_item(item_type, category)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				select_inventory_detail_item(item_type, category)
				assign_item_to_quick_hotbar(item_type, category)
				world.select_item(item_type, category)
				if event.double_click and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
					world.toggle_equip_item(item_type, category)
				update_inventory_window()
				update_hotbar()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			var double_tap = is_equip_double_tap(item_type, category, "inventory")
			select_inventory_detail_item(item_type, category)
			assign_item_to_quick_hotbar(item_type, category)
			world.select_item(item_type, category)
			if double_tap and world.has_method("is_item_equipable") and world.is_item_equipable(item_type, category) and world.has_method("toggle_equip_item"):
				world.toggle_equip_item(item_type, category)
			update_inventory_window()
			update_hotbar()
		get_viewport().set_input_as_handled()


func get_slot_for_item(item_type: String, category: String):
	var slot_key = category + ":" + item_type
	if inventory_slots.has(slot_key):
		return inventory_slots[slot_key]
	return null


func is_equip_double_tap(item_type: String, category: String, source: String) -> bool:
	var now = Time.get_ticks_msec()
	var tap_key = source + ":" + category + ":" + item_type
	var is_double_tap = tap_key == equip_last_tap_key and now - equip_last_tap_ms <= EQUIP_DOUBLE_TAP_TIME_MS
	equip_last_tap_key = tap_key
	equip_last_tap_ms = now
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
		world.select_item(item_type, category)
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
	if trade_select_active or vend_select_active or safe_select_active:
		item_context_menu.size = Vector2(250, 178)
		if trade_button != null:
			trade_button.visible = true
			if vend_select_active:
				trade_button.text = "Add To Vending"
			elif safe_select_active:
				trade_button.text = "Add To Safe"
			else:
				trade_button.text = "Add To Trade"
			trade_button.position = Vector2(12, 84)
		if trade_cancel_button != null:
			trade_cancel_button.visible = true
			trade_cancel_button.position = Vector2(12, 122)
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
	hold_item_type = item_type
	hold_item_category = category
	hold_slot = slot
	if inventory_window != null and inventory_drawer_target <= 0.05 and inventory_drawer_amount <= 0.05:
		open_inventory_window()
	select_inventory_detail_item(item_type, category)


func hide_item_context_menu():
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
			else:
				add_context_item_to_trade(item_type, category, stack_amount)
			return
	if trade_select_active or vend_select_active or safe_select_active:
		cancel_trade_item_popup()
		return
	match action:
		"info":   show_item_info(item_type, category)
		"drop":   drop_inventory_item(item_type, category, amount)
		"trash":  trash_inventory_item(item_type, category, amount)
	hide_item_context_menu()
	cancel_item_hold()
	update_inventory_window()
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
	var safe_max: float = snapped(max(0.1, max_weight), 0.1)
	var default_weight: float = safe_max
	context_amount_updating = true
	if context_amount_slider != null:
		context_amount_slider.min_value = 0.1
		context_amount_slider.max_value = safe_max
		context_amount_slider.step = 0.1
		context_amount_slider.value = default_weight
	if context_amount_input != null:
		context_amount_input.text = "%.1f" % default_weight
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
		var typed_weight: float = float(clean_text)
		set_context_amount_value(typed_weight, false)
		return

	if clean_text == "" or not clean_text.is_valid_int():
		return
	var typed_amount: int = int(clean_text)
	if typed_amount <= 0:
		typed_amount = 1
	set_context_amount_value(float(typed_amount), false)


func set_context_amount_value(amount: float, update_text: bool):
	var is_fish_amount: bool = is_context_amount_for_fish()
	var max_amount: float = 1.0
	if context_amount_slider != null:
		max_amount = float(context_amount_slider.max_value)
	var min_amount: float = 0.1 if is_fish_amount else 1.0
	var step_amount: float = 0.1 if is_fish_amount else 1.0
	var safe_amount: float = snapped(clampf(float(amount), min_amount, max_amount), step_amount)
	context_amount_updating = true
	if context_amount_slider != null:
		context_amount_slider.value = safe_amount
	if update_text and context_amount_input != null:
		context_amount_input.text = "%.1f" % safe_amount if is_fish_amount else str(int(round(safe_amount)))
	context_amount_updating = false


func get_context_amount(item_type: String, category: String) -> float:
	var limit: float = get_fish_weight_lb(item_type) if category == "fish" else float(get_item_count(item_type, category))
	var amount: float = 0.0 if category == "fish" else 1.0
	if context_amount_input != null:
		var clean_text = context_amount_input.text.strip_edges()
		if category == "fish" and clean_text.is_valid_float():
			amount = float(clean_text)
		elif category != "fish":
			amount = float(int(clean_text))
	elif context_amount_slider != null:
		amount = float(context_amount_slider.value)
	if category == "fish":
		if amount <= 0.0:
			return 0.0
		amount = normalize_fish_weight(clampf(amount, 0.1, max(0.1, limit)))
	else:
		amount = float(clamp(int(round(amount)), 1, max(1, int(limit))))
	return amount


func show_item_info(item_type: String, category: String):
	var display_name = get_item_display_name(item_type, category)
	var count = get_item_count(item_type, category)
	var rarity = get_item_rarity(item_type, category)
	var rarity_name = get_rarity_display_name(rarity)
	if world != null and world.has_method("show_notification"):
		world.show_notification(display_name + " | " + rarity_name + " | " + format_inventory_amount(item_type, category, get_fish_weight_lb(item_type) if category == "fish" else count))


func drop_inventory_item(item_type: String, category: String, amount: float):
	if not can_drop_item_from_inventory(item_type, category):
		if world.has_method("show_notification"):
			world.show_notification("That item cannot be dropped.")
		return
	if category == "fish":
		var safe_weight: float = normalize_fish_weight(amount)
		if safe_weight <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 0.1 lb.")
			return
		if not has_fish_weight(item_type, safe_weight):
			if world.has_method("show_notification"):
				world.show_notification("You only have " + format_fish_weight(get_fish_weight_lb(item_type)) + ".")
			return
		amount = safe_weight
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
		var safe_weight: float = normalize_fish_weight(amount)
		if safe_weight <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 0.1 lb.")
			return
		if not has_fish_weight(item_type, safe_weight):
			if world.has_method("show_notification"):
				world.show_notification("You only have " + format_fish_weight(get_fish_weight_lb(item_type)) + ".")
			return
		amount = safe_weight
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

	return bool(network.send_inventory_transaction_request({
		"action": "trash_inventory_item",
		"world": world.current_world_name if world != null else "",
		"item_type": item_type,
		"item_category": category,
		"amount": snapped(max(0.1, amount), 0.1) if category == "fish" else max(1, int(round(amount)))
	}))


func remove_inventory_item(item_type: String, category: String, amount: float) -> bool:
	if category == "fish" and world.fish_inventory.has(item_type):
		return remove_fish_weight(item_type, amount, true)

	var whole_amount: int = max(1, int(round(amount)))
	var count = get_item_count(item_type, category)
	if count < whole_amount:
		if world.has_method("show_notification"):
			world.show_notification("You only have " + str(count) + ".")
		return false
	if category == "block" and world.inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.inventory, item_type, category, whole_amount)
		return true
	if category == "seed" and world.seed_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.seed_inventory, item_type, category, whole_amount)
		return true
	if category == "tool" and world.tool_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.tool_inventory, item_type, category, whole_amount)
		if world.equipped_tool == item_type and int(world.tool_inventory[item_type]) <= 0 and world.has_method("unequip_tool"):
			world.unequip_tool()
		return true
	if category == "material" and world.material_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.material_inventory, item_type, category, whole_amount)
		return true
	if category == "lure" and world.lure_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.lure_inventory, item_type, category, whole_amount)
		return true
	if category == "currency" and world.currency_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.currency_inventory, item_type, category, whole_amount)
		return true
	if category == "back" and world.back_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.back_inventory, item_type, category, whole_amount)
		if world.equipped_back_item == item_type and int(world.back_inventory[item_type]) <= 0:
			world.equipped_back_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		return true
	if category == "hair" and world.hair_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.hair_inventory, item_type, category, whole_amount)
		if world.equipped_hair_item == item_type and int(world.hair_inventory[item_type]) <= 0:
			world.equipped_hair_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		return true
	if category == "shirt" and world.shirt_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.shirt_inventory, item_type, category, whole_amount)
		if world.equipped_shirt_item == item_type and int(world.shirt_inventory[item_type]) <= 0:
			world.equipped_shirt_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		return true
	if category == "pants" and world.pants_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.pants_inventory, item_type, category, whole_amount)
		if world.equipped_pants_item == item_type and int(world.pants_inventory[item_type]) <= 0:
			world.equipped_pants_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		return true
	if category == "shoes" and world.shoes_inventory.has(item_type):
		world.spend_item_from_inventory_stack(world.shoes_inventory, item_type, category, whole_amount)
		if world.equipped_shoes_item == item_type and int(world.shoes_inventory[item_type]) <= 0:
			world.equipped_shoes_item = ""
			if world.has_method("update_equipment_visual"):
				world.update_equipment_visual()
		return true
	if world.has_method("show_notification"):
		world.show_notification("Cannot remove " + get_item_display_name(item_type, category) + ".")
	return false


func update_inventory_window_position():
	if inventory_window == null:
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
		hotbar_y + get_hotbar_visual_height() + HOTBAR_INVENTORY_GAP
	)


func get_inventory_grid_view_size() -> Vector2:
	var grid_size = Vector2(1028.0, 292.0)
	if inventory_scroll_container != null:
		grid_size = inventory_scroll_container.size
	grid_size.x = max(INVENTORY_SLOT_SIZE, grid_size.x - INVENTORY_SCROLLBAR_RESERVE)
	return grid_size


func open_inventory_window():
	if inventory_window == null:
		return
	if is_gameplay_hud_blocked():
		return
	inventory_window.visible = true
	for slot_key in inventory_slots.keys():
		inventory_slots[slot_key].visible = false
	inventory_drawer_target = 1.0
	update_inventory_window()


func close_inventory_window():
	if inventory_window == null:
		return
	if trade_select_active:
		end_trade_item_select(false)
	if vend_select_active:
		end_vend_item_select(false)
	if safe_select_active:
		end_safe_item_select(false)
	hide_item_context_menu()
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
	if inventory_window == null:
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
			var count = snapped(max(0.0, float(world.fish_inventory[fish_name])), 0.1)
			if count > 0.0:
				visible_items.append({"type": fish_name, "category": "fish", "count": count})
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
	var columns = max(1, int(floor((grid_width + INVENTORY_SLOT_GAP) / (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_GAP))))
	var rows = max(1, int(ceil(float(filtered_items.size()) / float(columns))))
	if inventory_grid_root != null:
		inventory_grid_root.custom_minimum_size = Vector2(
			grid_width,
			max(grid_height, rows * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_GAP) - INVENTORY_SLOT_GAP + INVENTORY_GRID_BOTTOM_PAD)
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
		slot.position = Vector2(column * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_GAP), row * (INVENTORY_SLOT_SIZE + INVENTORY_SLOT_GAP))
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
			match rarity:
				"common":    rarity_label.text = "C"
				"uncommon":  rarity_label.text = "U"
				"rare":      rarity_label.text = "R"
				"epic":      rarity_label.text = "E"
				"legendary": rarity_label.text = "L"
				"currency":  rarity_label.text = "$"
				_:           rarity_label.text = ""
			rarity_label.add_theme_color_override("font_color", get_rarity_letter_color(rarity))
		var count_label = slot.get_node_or_null("Count")
		if count_label != null:
			if category == "fish" and float(count) > 0.0:
				count_label.text = format_inventory_amount(item_type, category, get_fish_weight_lb(item_type))
			elif count > 1:
				count_label.text = format_stack_count(count)
			elif category == "tool" or category == "back" or category == "hair" or category == "shirt" or category == "pants" or category == "shoes":
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
		var current_icon_texture = get_item_texture(item_type, category)
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
		var name_label = slot.get_node_or_null("Name")
		if name_label != null:
			name_label.text = ""
			name_label.visible = false
		slot.tooltip_text = get_item_display_name(item_type, category) + " " + format_inventory_amount(item_type, category, get_fish_weight_lb(item_type) if category == "fish" else count)
		var equipped_label = slot.get_node_or_null("EquippedLabel")
		if equipped_label != null:
			equipped_label.visible = (category == "tool" and world.equipped_tool == item_type) or (category == "back" and world.equipped_back_item == item_type) or (category == "hair" and world.equipped_hair_item == item_type) or (category == "shirt" and world.equipped_shirt_item == item_type) or (category == "pants" and world.equipped_pants_item == item_type) or (category == "shoes" and world.equipped_shoes_item == item_type)

	update_inventory_detail_panel()
