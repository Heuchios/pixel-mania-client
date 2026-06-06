extends Control

# PixelMania World Lock UI v1
# Uses shared PixelMania UI style. Does not modify save_manager.gd.

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const WORLD_LOCK_ROLE_OPTIONS = ["ADMIN", "BUILDER", "VISITOR"]
const DEFAULT_WORLD_LOCK_ROLE = "BUILDER"
const WORLD_LOCK_HEADER_HEIGHT := 78.0
const WORLD_LOCK_NAV_HEIGHT := 44.0
const WORLD_LOCK_WINDOW_WIDTH := 1120.0
const WORLD_LOCK_WINDOW_HEIGHT := 680.0
const ACCESS_LOOKUP_TIMEOUT_MS := 15000

var world = null
var ui_layer_ref = null
var target_grid_pos: Vector2i = Vector2i.ZERO

var panel = null
var title_label = null
var world_label = null
var owner_label = null
var status_label = null
var position_label = null
var lock_badge_panel = null
var lock_badge_label = null
var public_button = null
var slot_limit_label = null
var slot_limit_input = null
var set_slot_limit_button = null
var add_input = null
var add_role_picker = null
var add_button = null
var member_list_root = null
var hint_label = null
var menu_open: bool = false
var confirm_panel = null
var world_lock_panel_layout_size = Vector2.ZERO
var member_row_width: float = 398.0
var _pending_access_check_request_id: String = ""
var _pending_access_check_name: String = ""
var _pending_access_check_role: String = ""
var _access_check_timeout_deadline_ms: int = 0


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 160
	visible = false

	build_ui()

	if panel != null:
		panel.visible = false

	close_world_lock()


func _process(_delta):
	# Some existing gameplay UI visibility code can force UI children visible when entering a world.
	# Keep the root node harmless, and only show the actual panel when open_world_lock() is called.
	refresh_world_lock_panel_for_viewport()

	if not menu_open:
		if panel != null:
			panel.visible = false
		return

	if panel != null:
		panel.visible = true

	_process_access_lookup_timeout()
	update_panel_position()


func _process_access_lookup_timeout():
	if _pending_access_check_request_id == "":
		return

	if Time.get_ticks_msec() < _access_check_timeout_deadline_ms:
		return

	var pending_name = _pending_access_check_name
	_clear_access_lookup_wait()
	show_result({"ok": false, "message": "Lookup timed out for " + pending_name + ". Player may be offline, but the account must exist in the database."})


func get_world_lock_viewport_size() -> Vector2:
	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


func get_world_lock_margin_x(screen_size: Vector2) -> float:
	return clamp(screen_size.x * 0.035, 26.0, 76.0)


func get_world_lock_window_size_for_viewport(screen_size: Vector2) -> Vector2:
	return Vector2(
		min(WORLD_LOCK_WINDOW_WIDTH, max(420.0, screen_size.x - 32.0)),
		min(WORLD_LOCK_WINDOW_HEIGHT, max(460.0, screen_size.y - 32.0))
	)


func refresh_world_lock_panel_for_viewport():
	if panel == null:
		return

	var screen_size = get_world_lock_viewport_size()
	if world_lock_panel_layout_size == Vector2.ZERO:
		world_lock_panel_layout_size = screen_size
		return

	if world_lock_panel_layout_size.distance_to(screen_size) <= 2.0:
		return

	var was_open = menu_open
	build_ui()
	if panel != null:
		panel.visible = was_open
	if was_open:
		refresh()


func get_manager():
	if world == null:
		return null

	return world.world_lock_manager


func build_ui():
	for child in get_children():
		child.queue_free()
	confirm_panel = null

	var screen_size = get_world_lock_viewport_size()
	var window_size = get_world_lock_window_size_for_viewport(screen_size)
	world_lock_panel_layout_size = screen_size
	var margin_x = get_world_lock_margin_x(window_size)
	var content_width = max(420.0, window_size.x - margin_x * 2.0)
	var nav_y = WORLD_LOCK_HEADER_HEIGHT + 28.0
	var info_y = nav_y + WORLD_LOCK_NAV_HEIGHT + 22.0
	var info_h = 126.0
	if window_size.y < 560.0:
		nav_y = WORLD_LOCK_HEADER_HEIGHT + 12.0
		info_y = nav_y + WORLD_LOCK_NAV_HEIGHT + 16.0
		info_h = 110.0
	var section_y = info_y + info_h + 18.0
	var body_y = section_y + 38.0
	var body_h = max(170.0, window_size.y - body_y - 30.0)
	var content_gap = 18.0
	var stacked_layout = content_width < 820.0
	var action_width = clamp(content_width * 0.34, 304.0, 380.0)
	var member_width = content_width - action_width - content_gap
	var member_h = body_h
	var action_h = body_h
	var member_position = Vector2(margin_x, body_y)
	var action_position = Vector2(margin_x + member_width + content_gap, body_y)
	if stacked_layout:
		member_width = content_width
		action_width = content_width
		member_h = max(130.0, body_h * 0.52)
		action_h = max(232.0, body_h - member_h - content_gap)
		member_position = Vector2(margin_x, body_y)
		action_position = Vector2(margin_x, body_y + member_h + content_gap)
	member_row_width = max(320.0, member_width - 34.0)

	panel = Control.new()
	panel.name = "WorldLockPanel"
	panel.position = Vector2.ZERO
	panel.size = window_size
	panel.z_index = 160
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0, 22, 0
	))
	panel.add_child(shadow)

	var header = Panel.new()
	header.name = "TopBar"
	header.position = Vector2.ZERO
	header.size = Vector2(window_size.x, WORLD_LOCK_HEADER_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0, 22, 8
	))
	panel.add_child(header)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 22, 12
	))
	panel.add_child(panel_back)
	panel.move_child(panel_back, 1)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, WORLD_LOCK_HEADER_HEIGHT - 5.0)
	top_line.size = Vector2(window_size.x, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "WORLD LOCK"
	title_label.position = Vector2(margin_x, 10)
	title_label.size = Vector2(min(460.0, window_size.x * 0.42), 48)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title_label, 46 if window_size.x >= 1000.0 else 38)
	panel.add_child(title_label)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "ACCESS CONTROL"
	title_sub.position = Vector2(margin_x + 6.0, 58)
	title_sub.size = Vector2(210, 22)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	panel.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(window_size.x - margin_x - close_button.size.x, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.text = "X"
	apply_world_lock_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_world_lock)
	panel.add_child(close_button)

	var badge_width = 196.0 if window_size.x >= 960.0 else 164.0
	lock_badge_panel = Panel.new()
	lock_badge_panel.name = "LockStatusBadge"
	lock_badge_panel.position = Vector2(close_button.position.x - badge_width - 14.0, 14)
	lock_badge_panel.size = Vector2(badge_width, 48)
	lock_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3, 14, 8
	))
	panel.add_child(lock_badge_panel)

	var lock_icon = TextureRect.new()
	lock_icon.name = "LockIcon"
	lock_icon.position = lock_badge_panel.position + Vector2(10, 6)
	lock_icon.size = Vector2(36, 36)
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_icon.texture = get_world_lock_icon_texture()
	panel.add_child(lock_icon)

	lock_badge_label = Label.new()
	lock_badge_label.name = "LockStatusText"
	lock_badge_label.position = lock_badge_panel.position + Vector2(52, 7)
	lock_badge_label.size = Vector2(badge_width - 64.0, 30)
	lock_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lock_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(lock_badge_label, 20)
	panel.add_child(lock_badge_label)

	var lock_word = Label.new()
	lock_word.name = "WorldLockWord"
	lock_word.text = "LOCK"
	lock_word.position = Vector2(max(margin_x + 420.0, lock_badge_panel.position.x - 118.0), 20)
	lock_word.size = Vector2(104, 34)
	lock_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lock_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_word.visible = lock_word.position.x + lock_word.size.x + 10.0 < lock_badge_panel.position.x
	PixelUIStyle.apply_label_shadow(lock_word, 25)
	panel.add_child(lock_word)

	var nav_back = Panel.new()
	nav_back.name = "CategoryBack"
	nav_back.position = Vector2(margin_x, nav_y - 8.0)
	nav_back.size = Vector2(content_width, WORLD_LOCK_NAV_HEIGHT + 14.0)
	nav_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.82, 0.94, 1.0, 0.10),
		Color(0.42, 0.78, 1.0, 0.22),
		1, 6, 0
	))
	panel.add_child(nav_back)

	var nav_root = Control.new()
	nav_root.name = "WorldLockTabs"
	nav_root.position = Vector2(margin_x, nav_y)
	nav_root.size = Vector2(content_width, WORLD_LOCK_NAV_HEIGHT)
	nav_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(nav_root)
	create_world_lock_tab(nav_root, "WORLD INFO", 0, content_width)
	create_world_lock_tab(nav_root, "ACCESS LIST", 1, content_width)
	create_world_lock_tab(nav_root, "OWNER ACTIONS", 2, content_width)

	var info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.position = Vector2(margin_x, info_y)
	info_panel.size = Vector2(content_width, info_h)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		3, 6, 7
	))
	panel.add_child(info_panel)

	var info_icon_back = Panel.new()
	info_icon_back.name = "InfoIconBack"
	info_icon_back.position = info_panel.position + Vector2(18, 18)
	info_icon_back.size = Vector2(86, 86)
	info_icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style("legendary"))
	panel.add_child(info_icon_back)

	var info_icon_shadow = TextureRect.new()
	info_icon_shadow.name = "InfoLockShadow"
	info_icon_shadow.position = info_icon_back.position + Vector2(9, 11)
	info_icon_shadow.size = Vector2(66, 62)
	info_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon_shadow.modulate = Color(0, 0, 0, 0.36)
	info_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_icon_shadow.texture = get_world_lock_icon_texture()
	panel.add_child(info_icon_shadow)

	var info_icon = TextureRect.new()
	info_icon.name = "InfoLockIcon"
	info_icon.position = info_icon_back.position + Vector2(7, 7)
	info_icon.size = Vector2(66, 66)
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_icon.texture = get_world_lock_icon_texture()
	panel.add_child(info_icon)

	var info_text_x = info_panel.position.x + 122.0
	var info_text_w = max(220.0, info_panel.size.x - 146.0)
	world_label = make_info_label("WorldLabel", Vector2(info_text_x, info_panel.position.y + 16), Vector2(info_text_w, 26), 18)
	panel.add_child(world_label)

	owner_label = make_info_label("OwnerLabel", Vector2(info_text_x, info_panel.position.y + 44), Vector2(info_text_w, 26), 18)
	panel.add_child(owner_label)

	status_label = make_info_label("StatusLabel", Vector2(info_text_x, info_panel.position.y + 72), Vector2(info_text_w, 24), 16)
	panel.add_child(status_label)

	position_label = make_info_label("PositionLabel", Vector2(info_text_x, info_panel.position.y + 98), Vector2(info_text_w, 20), 13)
	panel.add_child(position_label)

	var access_title = Label.new()
	access_title.name = "AccessTitle"
	access_title.text = "ACCESS LIST"
	access_title.position = Vector2(member_position.x + 2, section_y)
	access_title.size = Vector2(member_width, 30)
	access_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	access_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(access_title, 24, Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(access_title)
	create_section_line("AccessLine", Vector2(access_title.position.x + 2, access_title.position.y + 31), member_width)

	var actions_title = Label.new()
	actions_title.name = "ActionsTitle"
	actions_title.text = "OWNER ACTIONS"
	actions_title.position = Vector2(action_position.x + 2, section_y if not stacked_layout else action_position.y - 38.0)
	actions_title.size = Vector2(action_width, 30)
	actions_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(actions_title, 24, Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(actions_title)
	create_section_line("ActionsLine", Vector2(actions_title.position.x + 2, actions_title.position.y + 31), action_width)

	var member_panel = Panel.new()
	member_panel.name = "MemberPanel"
	member_panel.position = member_position
	member_panel.size = Vector2(member_width, member_h)
	member_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	member_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3, 6, 7
	))
	panel.add_child(member_panel)

	var scroll = ScrollContainer.new()
	scroll.name = "MemberScroll"
	scroll.position = member_panel.position + Vector2(12, 12)
	scroll.size = member_panel.size - Vector2(24, 24)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.clip_contents = true
	panel.add_child(scroll)
	apply_world_lock_scrollbar_style(scroll)

	member_list_root = VBoxContainer.new()
	member_list_root.name = "MemberList"
	member_list_root.custom_minimum_size = Vector2(member_row_width, max(0.0, scroll.size.y - 4.0))
	member_list_root.add_theme_constant_override("separation", 8)
	member_list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(member_list_root)

	var action_panel = Panel.new()
	action_panel.name = "ActionPanel"
	action_panel.position = action_position
	action_panel.size = Vector2(action_width, action_h)
	action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3, 6, 7
	))
	panel.add_child(action_panel)

	var action_pad = 18.0
	var action_inner_w = action_panel.size.x - action_pad * 2.0
	var compact_actions = action_panel.size.y < 286.0
	var public_y = 18.0 if not compact_actions else 12.0
	var public_h = 44.0 if not compact_actions else 38.0
	var slot_label_y = 78.0 if not compact_actions else 56.0
	var slot_control_y = 102.0 if not compact_actions else 76.0
	var slot_control_h = 34.0 if not compact_actions else 30.0
	var add_label_y = 150.0 if not compact_actions else 116.0
	var add_input_y = 176.0 if not compact_actions else 136.0
	var add_input_h = 38.0 if not compact_actions else 32.0
	var add_button_y = 226.0 if not compact_actions else 178.0
	var add_button_h = 44.0 if not compact_actions else 36.0
	var hint_y = add_button_y + add_button_h + 10.0
	public_button = Button.new()
	public_button.name = "PublicBuildButton"
	public_button.position = action_panel.position + Vector2(action_pad, public_y)
	public_button.size = Vector2(action_inner_w, public_h)
	public_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(public_button, true, false, 18)
	public_button.pressed.connect(_on_public_build_pressed)
	panel.add_child(public_button)

	slot_limit_label = Label.new()
	slot_limit_label.name = "SlotLimitLabel"
	slot_limit_label.text = "TRUSTED BUILDER LIMIT"
	slot_limit_label.position = action_panel.position + Vector2(action_pad, slot_label_y)
	slot_limit_label.size = Vector2(action_inner_w, 20)
	slot_limit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_limit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(slot_limit_label, 12)
	panel.add_child(slot_limit_label)

	var slot_input_width = min(122.0, max(88.0, action_inner_w * 0.30))
	var slot_btn_width = max(110.0, action_inner_w - slot_input_width - 8.0)
	slot_limit_input = LineEdit.new()
	slot_limit_input.name = "SlotLimitInput"
	slot_limit_input.placeholder_text = "Limit"
	slot_limit_input.position = action_panel.position + Vector2(action_pad, slot_control_y)
	slot_limit_input.size = Vector2(slot_input_width, slot_control_h)
	slot_limit_input.text = ""
	slot_limit_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_limit_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_input_style(slot_limit_input, 16)
	slot_limit_input.text_submitted.connect(_on_slot_limit_text_submitted)
	panel.add_child(slot_limit_input)

	set_slot_limit_button = Button.new()
	set_slot_limit_button.name = "SetSlotLimitButton"
	set_slot_limit_button.text = "SET LIMIT"
	set_slot_limit_button.position = action_panel.position + Vector2(action_pad + slot_input_width + 8.0, slot_control_y)
	set_slot_limit_button.size = Vector2(slot_btn_width, slot_control_h)
	set_slot_limit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(set_slot_limit_button, true, false, 13)
	set_slot_limit_button.pressed.connect(_on_set_slot_limit_pressed)
	panel.add_child(set_slot_limit_button)

	var add_label = Label.new()
	add_label.name = "AddLabel"
	add_label.text = "ADD PLAYER ACCESS"
	add_label.position = action_panel.position + Vector2(action_pad, add_label_y)
	add_label.size = Vector2(action_inner_w, 20)
	add_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(add_label, 13)
	panel.add_child(add_label)

	var role_width = min(112.0, max(78.0, action_inner_w * 0.34))
	var input_width = action_inner_w - role_width - 8.0
	add_input = LineEdit.new()
	add_input.name = "AddInput"
	add_input.placeholder_text = "Username"
	add_input.position = action_panel.position + Vector2(action_pad, add_input_y)
	add_input.size = Vector2(input_width, add_input_h)
	add_input.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_input_style(add_input, 18)
	add_input.text_submitted.connect(_on_add_text_submitted)
	panel.add_child(add_input)

	add_role_picker = OptionButton.new()
	add_role_picker.name = "AddRolePicker"
	add_role_picker.position = action_panel.position + Vector2(action_pad + input_width + 8.0, add_input_y)
	add_role_picker.size = Vector2(role_width, add_input_h)
	add_role_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	for role_index in range(WORLD_LOCK_ROLE_OPTIONS.size()):
		add_role_picker.add_item(WORLD_LOCK_ROLE_OPTIONS[role_index], role_index)
	add_role_picker.selected = WORLD_LOCK_ROLE_OPTIONS.find(DEFAULT_WORLD_LOCK_ROLE)
	add_role_picker.disabled = true
	add_role_picker.focus_mode = Control.FOCUS_NONE
	apply_world_lock_arcade_button_style(add_role_picker, false, false, 13)
	panel.add_child(add_role_picker)

	add_button = Button.new()
	add_button.name = "AddButton"
	add_button.text = "ADD ACCESS"
	add_button.position = action_panel.position + Vector2(action_pad, add_button_y)
	add_button.size = Vector2(action_inner_w, add_button_h)
	add_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(add_button, true, false, 18)
	add_button.pressed.connect(_on_add_access_pressed)
	panel.add_child(add_button)

	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.text = "Only owner can edit access. Public build controls who can build."
	hint_label.position = action_panel.position + Vector2(action_pad, hint_y)
	hint_label.size = Vector2(action_inner_w, max(20.0, action_panel.size.y - hint_y - 12.0))
	hint_label.visible = action_panel.size.y >= hint_y + 20.0
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(hint_label, 12)
	panel.add_child(hint_label)
	panel.visible = menu_open
	update_panel_position()


func create_world_lock_tab(parent: Control, tab_text: String, tab_index: int, content_width: float):
	if parent == null:
		return
	var gap = 8.0
	var tab_count = 3.0
	var tab_width = clamp((content_width - gap * (tab_count - 1.0)) / tab_count, 96.0, 190.0)
	var tab = Button.new()
	tab.name = "Tab_" + tab_text.replace(" ", "_")
	tab.text = tab_text
	tab.position = Vector2(float(tab_index) * (tab_width + gap), 0)
	tab.size = Vector2(tab_width, 38)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.disabled = false
	tab.focus_mode = Control.FOCUS_NONE
	apply_world_lock_arcade_button_style(tab, tab_index == 0, false, 13)
	parent.add_child(tab)


func create_section_line(line_name: String, line_position: Vector2, line_width: float):
	var line = ColorRect.new()
	line.name = line_name
	line.position = line_position
	line.size = Vector2(max(180.0, line_width), 3)
	line.color = Color(0.42, 0.86, 1.0, 0.58)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)


func get_world_lock_icon_texture():
	if world != null:
		if world.has_method("get_inventory_icon_texture"):
			var icon_texture = world.get_inventory_icon_texture("world_lock", "block")
			if icon_texture != null:
				return icon_texture
		if world.block_textures.has("world_lock"):
			return world.block_textures["world_lock"]
	if ResourceLoader.exists("res://Assets/locks/world_lock.png"):
		return load("res://Assets/locks/world_lock.png")
	return null


func apply_world_lock_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.56), Color(0.10, 0.0, 0.02, 0.62), 3, 12, 3))
		return
	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return
	PixelUIStyle.apply_blue_button(button, font_size)


func apply_world_lock_input_style(line_edit: LineEdit, font_size: int = 18):
	if line_edit == null:
		return
	PixelUIStyle.apply_input(line_edit, font_size)


func apply_world_lock_scrollbar_style(scroll: ScrollContainer):
	if scroll == null:
		return
	var scrollbar = scroll.get_v_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func make_info_label(node_name: String, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(label, font_size)
	return label


func update_panel_position():
	if panel == null:
		return

	var screen_size = get_world_lock_viewport_size()
	panel.position = Vector2(
		(screen_size.x - panel.size.x) * 0.5,
		max(18.0, (screen_size.y - panel.size.y) * 0.5)
	)


func open_world_lock(grid_pos: Vector2i):
	target_grid_pos = grid_pos
	menu_open = true
	visible = true
	clear_confirmation_popup()

	if panel != null:
		panel.visible = true

	refresh()
	update_panel_position()
	PixelUIStyle.play_panel_open(panel)


func close_world_lock():
	menu_open = false
	_clear_access_lookup_wait()
	clear_confirmation_popup()

	if panel != null:
		panel.visible = false

	# Keep the root hidden too, but the important part is panel.visible = false.
	# This prevents the menu from appearing if another manager later sets UI children visible.
	visible = false

	if add_input != null:
		add_input.release_focus()


func is_open() -> bool:
	return menu_open


func is_world_lock_open() -> bool:
	return is_open()


func refresh():
	var manager = get_manager()

	if manager == null:
		return

	var world_name: String = "UNKNOWN"

	if world != null and world.has_method("get_current_world_display_name"):
		world_name = str(world.get_current_world_display_name())
	elif world != null:
		world_name = str(world.current_world_name)

	var locked_text: String = "NO"
	var owner_text: String = "None"
	var status_text: String = "This world is not locked."

	if bool(manager.is_locked):
		locked_text = "YES"
		owner_text = str(manager.owner_name)
		status_text = manager.get_info_text()

	if lock_badge_label != null:
		lock_badge_label.text = "LOCKED" if bool(manager.is_locked) else "UNLOCKED"

	if lock_badge_panel != null:
		var badge_fill = Color(0.36, 0.25, 0.06, 0.70) if bool(manager.is_locked) else Color(0.08, 0.30, 0.16, 0.66)
		var badge_border = Color(1.0, 0.78, 0.18, 0.92) if bool(manager.is_locked) else Color(0.28, 1.0, 0.52, 0.82)
		lock_badge_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			badge_fill,
			badge_border,
			3, 14, 8
		))

	world_label.text = "World: " + world_name + "      Locked: " + locked_text
	owner_label.text = "Owner: " + owner_text
	status_label.text = "Status: " + status_text
	position_label.text = "Lock position: " + manager.get_lock_position_text()

	var is_owner: bool = manager.is_current_player_owner()

	if bool(manager.public_build):
		public_button.text = "PUBLIC BUILD: ON"
	else:
		public_button.text = "PUBLIC BUILD: OFF"

	var slot_limit_text = str(manager.get_trusted_builder_slot_limit())
	if slot_limit_input != null:
		slot_limit_input.text = slot_limit_text

	public_button.disabled = not is_owner
	add_input.editable = is_owner
	add_button.disabled = not is_owner
	add_role_picker.disabled = not is_owner
	slot_limit_input.editable = is_owner
	if set_slot_limit_button != null:
		set_slot_limit_button.disabled = not is_owner

	if is_owner:
		apply_world_lock_arcade_button_style(public_button, bool(manager.public_build), false, 17)
		apply_world_lock_arcade_button_style(add_button, true, false, 18)
		apply_world_lock_arcade_button_style(add_role_picker, false, false, 13)
		apply_world_lock_arcade_button_style(set_slot_limit_button, true, false, 13)
	else:
		apply_world_lock_arcade_button_style(public_button, false, false, 17)
		apply_world_lock_arcade_button_style(add_button, false, false, 18)
		apply_world_lock_arcade_button_style(add_role_picker, false, false, 13)
		apply_world_lock_arcade_button_style(set_slot_limit_button, false, false, 13)

	var slot_summary = "Trusted Slots: " + manager.get_trusted_builder_slot_summary()
	if slot_limit_label != null:
		slot_limit_label.text = "TRUSTED BUILDER LIMIT (" + slot_summary + ")"
	if hint_label != null and is_owner:
		hint_label.text = "Adjust trusted builder cap (0-50). Existing trusted slots cannot exceed the limit."
	elif hint_label != null:
		hint_label.text = "Only the owner can edit access and trusted slot settings."

	refresh_member_list()


func _on_slot_limit_text_submitted(_text: String):
	_on_set_slot_limit_pressed()


func _on_set_slot_limit_pressed():
	var manager = get_manager()
	if manager == null:
		return

	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit access."})
		return

	if slot_limit_input == null:
		return

	var text_value = str(slot_limit_input.text).strip_edges()
	if text_value == "":
		show_result({"ok": false, "message": "Enter a slot limit value."})
		return

	if not text_value.is_valid_int():
		show_result({"ok": false, "message": "Enter a valid number for slot limit."})
		return

	var limit_value = int(text_value)
	var result: Dictionary = manager.set_trusted_builder_slot_limit(limit_value)
	show_result(result)
	refresh()


func _start_access_lookup_wait(request_id: String, username: String, selected_role: String = ""):
	_pending_access_check_request_id = request_id
	_pending_access_check_name = username.strip_edges()
	_pending_access_check_role = selected_role.strip_edges()
	_access_check_timeout_deadline_ms = Time.get_ticks_msec() + ACCESS_LOOKUP_TIMEOUT_MS


func _clear_access_lookup_wait():
	_pending_access_check_request_id = ""
	_pending_access_check_name = ""
	_pending_access_check_role = ""
	_access_check_timeout_deadline_ms = 0


func _get_access_lookup_context(request_context: Dictionary) -> Dictionary:
	if request_context == null:
		return {}

	if request_context.has("context") and request_context.get("context") is Dictionary:
		return request_context.get("context").duplicate(true)

	return request_context.duplicate(true)


func _is_access_lookup_available() -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if not network.has_method("can_send_authenticated_payload"):
		return false

	return bool(network.can_send_authenticated_payload())


func refresh_member_list():
	if member_list_root == null:
		return

	for child in member_list_root.get_children():
		child.queue_free()

	var manager = get_manager()

	if manager == null:
		return

	var access_list: Array = manager.get_access_list()

	if access_list.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No players have access yet."
		empty_label.custom_minimum_size = Vector2(member_row_width, 44)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelUIStyle.apply_small_label(empty_label, 15)
		member_list_root.add_child(empty_label)
		return

	for player_name in access_list:
		create_member_row(str(player_name))


func create_member_row(player_name: String):
	var manager = get_manager()
	if manager == null:
		return

	var row_width = max(320.0, member_row_width)
	var row_height = 52.0
	var remove_width = 106.0
	var role_width = 118.0
	if row_width < 430.0:
		remove_width = 86.0
		role_width = 102.0
	var remove_x = row_width - remove_width - 10.0
	var role_x = remove_x - role_width - 10.0
	var role_label_x = role_x - 50.0
	var name_width = max(70.0, role_label_x - 20.0)

	var row = Control.new()
	row.custom_minimum_size = Vector2(row_width, row_height)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	member_list_root.add_child(row)

	var bg = Panel.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(row_width, 48)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.045, 0.050, 0.068, 0.96),
		Color(0.66, 0.73, 0.86, 0.76),
		3, 5, 5
	))
	row.add_child(bg)

	var name_label = Label.new()
	name_label.text = player_name
	name_label.position = Vector2(14, 8)
	name_label.size = Vector2(name_width, 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 16)
	row.add_child(name_label)

	var role_label = Label.new()
	role_label.text = "Role:"
	role_label.position = Vector2(role_label_x, 9)
	role_label.size = Vector2(44, 28)
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(role_label, 12)
	row.add_child(role_label)

	var player_role: String = manager.normalize_role(manager.get_player_access_role(player_name))
	var selected_role = manager.get_role_title(player_role).to_upper()
	var role_selector = OptionButton.new()
	role_selector.name = "RoleSelector"
	role_selector.position = Vector2(role_x, 7)
	role_selector.size = Vector2(role_width, 32)
	role_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	for role_index in range(WORLD_LOCK_ROLE_OPTIONS.size()):
		role_selector.add_item(WORLD_LOCK_ROLE_OPTIONS[role_index], role_index)
	role_selector.selected = WORLD_LOCK_ROLE_OPTIONS.find(selected_role)
	role_selector.disabled = not manager.is_current_player_owner()
	role_selector.focus_mode = Control.FOCUS_NONE
	apply_world_lock_arcade_button_style(role_selector, false, false, 13)
	role_selector.item_selected.connect(_on_member_role_selected.bind(player_name))
	row.add_child(role_selector)

	var remove_button = Button.new()
	remove_button.text = "REMOVE"
	remove_button.position = Vector2(remove_x, 7)
	remove_button.size = Vector2(remove_width, 32)
	remove_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(remove_button, false, true, 13)
	remove_button.disabled = not manager.is_current_player_owner()
	remove_button.pressed.connect(_on_remove_access_pressed.bind(player_name))
	row.add_child(remove_button)


func _on_public_build_pressed():
	var manager = get_manager()

	if manager == null:
		return

	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can change public build."})
		return

	if manager.is_strict_mode_enabled() and not bool(manager.is_current_player_owner_session_verified()):
		show_result({"ok": false, "message": "Owner identity could not be verified. Re-sign in as the world owner account."})
		return

	var target_state = not bool(manager.public_build)
	var confirm_message = "Set World Public Build to " + ("ON" if target_state else "OFF") + "?"

	if target_state:
		confirm_message += "\nThis will make the world publicly editable and accessible to everyone in this world."
	else:
		confirm_message += "\nOnly the owner and granted access players will be able to build."

	_show_confirm_panel(
		confirm_message,
		func(): _apply_public_build_change(target_state)
	)


func _on_add_text_submitted(_text: String):
	_on_add_access_pressed()


func _on_add_access_pressed():
	var manager = get_manager()

	if manager == null:
		return

	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit access."})
		return

	var username_raw: String = str(add_input.text).strip_edges()

	if username_raw == "":
		show_result({"ok": false, "message": "Enter a username first."})
		return

	var selected_role = _get_selected_role(add_role_picker)
	if selected_role == "":
		selected_role = "BUILDER"

	var can_validate_username = _is_access_lookup_available()
	var network = get_node_or_null("/root/NetworkManager")

	if can_validate_username and network != null and network.has_method("send_player_state_request_with_context"):
		var request_id = network.send_player_state_request_with_context(username_raw, {
			"purpose": "world_lock_access_check",
			"requested_username": username_raw,
			"selected_role": selected_role
		})
		if request_id != "":
			_start_access_lookup_wait(request_id, username_raw, selected_role)
			_show_confirm_loading("Checking player " + username_raw + "...")
			return
		_show_confirm_loading("Server unavailable, please try again.")
		return

	if manager.is_strict_mode_enabled():
		show_result({"ok": false, "message": "Player lookup is required before granting access. Sign in with a verified account and stay connected."})
		return

	var result: Dictionary = manager.add_access_name(username_raw, selected_role)
	show_result(result)

	if bool(result.get("ok", false)):
		add_input.text = ""

	refresh()


func _on_remove_access_pressed(player_name: String):
	var manager = get_manager()

	if manager == null:
		return

	var result: Dictionary = manager.remove_access_name(player_name)
	show_result(result)
	refresh()


func handle_player_state_lookup_result(_request_id: String, data: Dictionary, request_context: Dictionary = {}):
	if _pending_access_check_request_id == "":
		return

	if _pending_access_check_request_id != "" and _request_id != "" and _request_id != _pending_access_check_request_id:
		return

	var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
	if request_purpose != "" and request_purpose != "world_lock_access_check":
		return

	var pending_name = _pending_access_check_name
	var pending_role = _pending_access_check_role
	var manager = get_manager()

	if manager == null:
		_clear_access_lookup_wait()
		return

	var lookup_context = _get_access_lookup_context(request_context)
	var requested_name = str(lookup_context.get("requested_username", pending_name)).strip_edges()
	var requested_role = str(lookup_context.get("selected_role", pending_role)).strip_edges()

	if requested_name == "":
		requested_name = pending_name
	if requested_role == "":
		requested_role = "BUILDER"

	var pending_normalized = manager.normalize_name(pending_name)
	var requested_normalized = manager.normalize_name(requested_name)
	if requested_normalized == "":
		requested_normalized = pending_normalized

	var found_name = _extract_username_from_lookup_result(data)
	if found_name == "":
		found_name = str(data.get("username", "")).strip_edges()
	var found_name_normalized = manager.normalize_name(found_name)

	var requested_username = requested_name.to_upper()
	if requested_username == "":
		requested_username = pending_normalized

	_clear_access_lookup_wait()

	if not _is_player_lookup_success(data):
		var server_message = _extract_lookup_error_message(data)
		if server_message == "":
			server_message = "Player not found."
		show_result({"ok": false, "message": server_message})
		return

	if found_name == "":
		if requested_username != "":
			found_name = requested_username
			found_name_normalized = manager.normalize_name(found_name)
		else:
			show_result({"ok": false, "message": "Player not found."})
			return

	var requested_name_normalized = manager.normalize_name(requested_username)
	if pending_normalized != "" and requested_name_normalized != "" and pending_normalized != requested_name_normalized:
		show_result({"ok": false, "message": "Lookup context mismatch. Please retry."})
		return

	if found_name_normalized != "":
		if requested_normalized != "" and found_name_normalized != requested_normalized and pending_normalized != "":
			show_result({"ok": false, "message": "Lookup response did not match target player."})
			return

	var confirmed_name_normalized = manager.normalize_name(found_name)

	if requested_name_normalized != "" and requested_name_normalized != confirmed_name_normalized:
		show_result({"ok": false, "message": "Player not found."})
		return

	if confirmed_name_normalized == "":
		show_result({"ok": false, "message": "Player not found."})
		return

	var confirmation_name = found_name
	var role_name = _normalize_role_option(requested_role)
	if role_name == "":
		role_name = _normalize_role_option(manager.get_role_title("BUILDER"))

	_show_confirm_panel(
		"Grant " + manager.get_role_title(role_name) + " access to " + confirmation_name + "?\nThey will be added to the world access list.",
		func(): _apply_add_access(confirmation_name, role_name),
		"GRANT ACCESS"
	)


func _on_member_role_selected(player_name: String, item_index: int):
	var manager = get_manager()
	if manager == null:
		return

	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit roles."})
		refresh_member_list()
		return

	var new_role = _normalize_role_option_by_index(item_index)
	if new_role == "":
		return

	var clean_name = manager.normalize_name(player_name)
	if clean_name == "":
		show_result({"ok": false, "message": "Invalid player name."})
		refresh_member_list()
		return

	var current_role = manager.normalize_role(manager.get_player_access_role(clean_name))
	if current_role == new_role:
		return

	var role_title = manager.get_role_title(new_role)
	_show_confirm_panel(
		"Set " + clean_name + " role to " + role_title + "?",
		func(): _apply_member_role_change(clean_name, new_role),
		"SET ROLE"
	)


func _apply_member_role_change(player_name: String, new_role: String):
	var manager = get_manager()
	if manager == null:
		return

	var result: Dictionary = manager.set_player_role(player_name, new_role)
	show_result(result)
	refresh()


func _normalize_role_option_by_index(item_index: int) -> String:
	if item_index < 0 or item_index >= WORLD_LOCK_ROLE_OPTIONS.size():
		return _normalize_role_option(DEFAULT_WORLD_LOCK_ROLE)

	return _normalize_role_option(WORLD_LOCK_ROLE_OPTIONS[item_index])


func _normalize_role_option(role_raw: String) -> String:
	var normalized_role = role_raw.strip_edges().to_upper()
	if normalized_role == "":
		return DEFAULT_WORLD_LOCK_ROLE

	if normalized_role == "ADMIN":
		return "ADMIN"
	if normalized_role == "VISITOR":
		return "VISITOR"
	if normalized_role == "BUILDER":
		return "BUILDER"
	return DEFAULT_WORLD_LOCK_ROLE


func _get_selected_role(picker: OptionButton) -> String:
	if picker == null:
		return "BUILDER"
	return _normalize_role_option_by_index(picker.get_selected_id())


func show_result(result: Dictionary):
	if world == null:
		return

	var message: String = str(result.get("message", ""))

	if message == "":
		return

	if world.has_method("show_notification"):
		world.show_notification(message)


func _show_confirm_loading(message: String):
	if world == null:
		return

	show_result({"ok": false, "message": message})


func _show_confirm_panel(message: String, on_confirm: Callable, confirm_text: String = "CONFIRM", on_cancel: Callable = Callable()):
	clear_confirmation_popup()

	if panel == null:
		return

	var blocker = ColorRect.new()
	blocker.name = "WorldLockConfirmBlocker"
	blocker.position = Vector2.ZERO
	blocker.size = panel.size
	blocker.z_index = 19
	blocker.color = Color(0.0, 0.0, 0.0, 0.42)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(blocker)

	confirm_panel = Panel.new()
	confirm_panel.name = "WorldLockConfirmPanel"
	confirm_panel.size = Vector2(540, 214)
	confirm_panel.position = (panel.size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 20
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 12
	))
	panel.add_child(confirm_panel)

	var label = Label.new()
	label.name = "ConfirmLabel"
	label.text = message
	label.position = Vector2(24, 20)
	label.size = Vector2(492, 106)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 14)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = confirm_text
	confirm.position = Vector2(42, 150)
	confirm.size = Vector2(206, 44)
	apply_world_lock_arcade_button_style(confirm, true, false, 16)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.pressed.connect(func():
		if on_confirm != null and on_confirm.is_valid():
			on_confirm.call()
		clear_confirmation_popup()
	)
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(292, 150)
	cancel.size = Vector2(206, 44)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(cancel, false, false, 16)
	cancel.pressed.connect(func():
		if on_cancel != null and on_cancel.is_valid():
			on_cancel.call()
		clear_confirmation_popup()
	)
	confirm_panel.add_child(cancel)


func clear_confirmation_popup():
	if panel != null:
		var blocker = panel.get_node_or_null("WorldLockConfirmBlocker")
		if blocker != null and is_instance_valid(blocker):
			blocker.queue_free()
	if confirm_panel != null and is_instance_valid(confirm_panel):
		confirm_panel.queue_free()
		confirm_panel = null


func _apply_public_build_change(target_state: bool):
	var manager = get_manager()
	if manager == null:
		return

	var result: Dictionary = manager.set_public_build(target_state)
	show_result(result)
	refresh()


func _extract_username_from_lookup_result(data: Dictionary, depth: int = 0) -> String:
	if data == null or depth > 8:
		return ""

	var account_name = str(data.get("username", "")).strip_edges()
	if account_name != "":
		return account_name

	account_name = str(data.get("account_username", "")).strip_edges()
	if account_name != "":
		return account_name

	var nested_data = data.get("data", null)
	if nested_data is Dictionary and not nested_data.is_empty():
		var nested_name = _extract_username_from_lookup_result(nested_data, depth + 1)
		if nested_name != "":
			return nested_name

	var account_data = data.get("account", null)
	if account_data is Dictionary:
		account_name = str(account_data.get("username", "")).strip_edges()
		if account_name != "":
			return account_name

		account_name = str(account_data.get("account_username", "")).strip_edges()
		if account_name != "":
			return account_name

		account_name = str(account_data.get("name", "")).strip_edges()
		if account_name != "":
			return account_name

	var player_data = data.get("player_data", null)
	if player_data is Dictionary:
		account_name = str(player_data.get("username", "")).strip_edges()
		if account_name != "":
			return account_name

		account_name = str(player_data.get("name", "")).strip_edges()
		if account_name != "":
			return account_name

		account_name = str(player_data.get("display_name", "")).strip_edges()
		if account_name != "":
			return account_name

		return str(player_data.get("account_username", "")).strip_edges()

	var account_info = data.get("account_data", null)
	if account_info is Dictionary and not account_info.is_empty():
		account_name = _extract_username_from_lookup_result(account_info, depth + 1)
		if account_name != "":
			return account_name

		account_name = str(account_info.get("account_username", "")).strip_edges()
		if account_name != "":
			return account_name

	return ""


func _is_player_lookup_success(data: Dictionary, depth: int = 0) -> bool:
	if data == null or depth > 8:
		return false

	var nested_data = data.get("data", null)
	if nested_data is Dictionary and not nested_data.is_empty():
		if _is_player_lookup_success(nested_data, depth + 1):
			return true

	var nested_account = data.get("account", null)
	if nested_account is Dictionary and not nested_account.is_empty():
		if _is_player_lookup_success(nested_account, depth + 1):
			return true

	var nested_player_data = data.get("player_data", null)
	if nested_player_data is Dictionary and not nested_player_data.is_empty():
		if _is_player_lookup_success(nested_player_data, depth + 1):
			return true

	var nested_account_data = data.get("account_data", null)
	if nested_account_data is Dictionary and not nested_account_data.is_empty():
		if _is_player_lookup_success(nested_account_data, depth + 1):
			return true

	var found_value = data.get("found", null)
	if found_value is bool:
		if not bool(found_value):
			return false
		return true

	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	if ok_value is bool and bool(ok_value):
		return true

	var found_name = _extract_username_from_lookup_result(data, depth + 1)
	if found_name != "":
		return true

	var username = str(data.get("username", "")).strip_edges()
	if username != "":
		return true

	return false


func _extract_lookup_error_message(data: Dictionary, depth: int = 0) -> String:
	if data == null or depth > 8:
		return ""

	var nested_data = data.get("data", null)
	if nested_data is Dictionary and not nested_data.is_empty():
		var nested_message = _extract_lookup_error_message(nested_data, depth + 1)
		if nested_message != "":
			return nested_message

	var message = str(data.get("message", "")).strip_edges()
	if message != "":
		return message

	var error_code = str(data.get("error", "")).strip_edges()
	if error_code != "":
		return error_code

	var result_message = str(data.get("result", "")).strip_edges()
	if result_message != "":
		return result_message

	var account_data = data.get("account_data", null)
	if account_data is Dictionary and not account_data.is_empty():
		var nested_error = _extract_lookup_error_message(account_data, depth + 1)
		if nested_error != "":
			return nested_error

	var account_nested = data.get("account", null)
	if account_nested is Dictionary and not account_nested.is_empty():
		var nested_error = _extract_lookup_error_message(account_nested, depth + 1)
		if nested_error != "":
			return nested_error

	var player_data = data.get("player_data", null)
	if player_data is Dictionary and not player_data.is_empty():
		var nested_error = _extract_lookup_error_message(player_data, depth + 1)
		if nested_error != "":
			return nested_error

	return ""


func _apply_add_access(username: String, role: String):
	var manager = get_manager()
	if manager == null:
		return

	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can grant access."})
		return

	if manager.is_strict_mode_enabled() and not bool(manager.is_current_player_owner_session_verified()):
		show_result({"ok": false, "message": "Owner identity could not be verified. Re-sign in as the world owner account."})
		return

	var clean_role = _normalize_role_option(role)
	if clean_role == "":
		show_result({"ok": false, "message": "Invalid role selected."})
		return

	var clean_name = manager.normalize_name(username)
	if clean_name == "":
		show_result({"ok": false, "message": "Player not found."})
		return

	var result: Dictionary = manager.add_access_name(clean_name, clean_role, true)
	show_result(result)
	if bool(result.get("ok", false)):
		add_input.text = ""
	refresh()
