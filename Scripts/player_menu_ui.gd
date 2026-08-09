extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const PROFILE_W := 760.0
const PROFILE_H := 500.0
const PROFILE_HEADER_H := 78.0
const LOCKED_WORLDS_W := 650.0
const LOCKED_WORLDS_H := 430.0
const LOCKED_WORLD_ROW_H := 74.0
const REMOTE_PROFILE_LOOKUP_TIMEOUT := 5.0

var world = null

var panel = null
var overlay = null
var is_menu_open = false

var player_name_label = null
var level_label = null
var xp_label = null
var playtime_label = null
var gems_label = null
var world_label = null
var health_label = null
var hand_label = null
var back_label = null
var shirt_label = null
var pants_label = null
var account_label = null
var status_badge_label = null
var avatar_label = null
var action_panel = null
var worlds_button = null
var titles_button = null
var trade_button = null
var friend_button = null
var close_action_button = null
var locked_worlds_blocker = null
var locked_worlds_panel = null
var locked_worlds_rows_root = null
var locked_worlds_empty_label = null
var profile_mode := "local"
var remote_profile_data := {}
var remote_profile_lookup_status := ""
var remote_profile_request_id := ""
var remote_profile_requested_username := ""
var server_locked_world_entries: Array = []
var locked_worlds_loading := false
var locked_worlds_request_id := ""
var locked_worlds_error := ""


func setup(parent_world):
	world = parent_world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 145
	connect_owned_locked_worlds_feed()

	build_menu()
	close_menu()


func connect_owned_locked_worlds_feed():
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return
	if not network.has_signal("owned_locked_worlds_received"):
		return

	var callback := Callable(self, "_on_owned_locked_worlds_received")
	if not network.is_connected("owned_locked_worlds_received", callback):
		network.connect("owned_locked_worlds_received", callback)


func _process(_delta):
	if is_menu_open:
		update_menu_info()


func build_menu():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.50)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Control.new()
	panel.name = "PlayerMenuPanel"
	panel.size = Vector2(PROFILE_W, PROFILE_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	add_child(panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		22,
		0
	))
	panel.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		22,
		12
	))
	panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(PROFILE_W, PROFILE_HEADER_H)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		22,
		8
	))
	panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, PROFILE_HEADER_H - 5.0)
	top_line.size = Vector2(PROFILE_W, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "PLAYER PROFILE"
	title.position = Vector2(34, 8)
	title.size = Vector2(440, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 44)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "ACCOUNT DETAILS"
	subtitle.position = Vector2(40, 58)
	subtitle.size = Vector2(260, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 14)
	panel.add_child(subtitle)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(PROFILE_W - 84, 14)
	close_button.size = Vector2(52, 48)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_profile_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_menu)
	panel.add_child(close_button)

	create_profile_layout()
	create_action_buttons()
	create_locked_worlds_panel()

	update_position()
	update_menu_info()


func create_profile_layout():
	hand_label = null
	back_label = null
	shirt_label = null
	pants_label = null
	gems_label = null
	health_label = null

	var name_card = Panel.new()
	name_card.name = "NameCard"
	name_card.position = Vector2(34, 98)
	name_card.size = Vector2(PROFILE_W - 68, 118)
	name_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.12, 0.28, 0.40, 0.52),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		15,
		8
	))
	panel.add_child(name_card)

	var name_gloss = ColorRect.new()
	name_gloss.name = "NameGloss"
	name_gloss.position = Vector2(18, 14)
	name_gloss.size = Vector2(name_card.size.x - 36, 18)
	name_gloss.color = Color(0.74, 0.94, 1.0, 0.08)
	name_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_card.add_child(name_gloss)

	var avatar_back = Panel.new()
	avatar_back.name = "AvatarBack"
	avatar_back.position = Vector2(24, 20)
	avatar_back.size = Vector2(80, 80)
	avatar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.030, 0.052, 0.105, 0.98),
		Color(1.0, 0.80, 0.12, 0.92),
		3,
		14,
		6
	))
	name_card.add_child(avatar_back)

	avatar_label = Label.new()
	avatar_label.name = "AvatarLabel"
	avatar_label.text = "P"
	avatar_label.position = Vector2.ZERO
	avatar_label.size = avatar_back.size
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(avatar_label, 42, Color(0.90, 0.98, 1.0, 1.0))
	avatar_back.add_child(avatar_label)

	player_name_label = Label.new()
	player_name_label.name = "PlayerName"
	player_name_label.text = "USO"
	player_name_label.position = Vector2(126, 22)
	player_name_label.size = Vector2(360, 42)
	player_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_name_label.clip_text = true
	player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(player_name_label, 34)
	name_card.add_child(player_name_label)

	account_label = Label.new()
	account_label.name = "AccountLabel"
	account_label.text = "Account Profile"
	account_label.position = Vector2(128, 66)
	account_label.size = Vector2(350, 22)
	account_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	account_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(account_label, 14)
	name_card.add_child(account_label)

	var badge = Panel.new()
	badge.name = "StatusBadge"
	badge.position = Vector2(name_card.size.x - 190, 34)
	badge.size = Vector2(158, 48)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.95, 0.68, 0.08, 0.98),
		Color(1.0, 0.90, 0.22, 0.95),
		3,
		12,
		6
	))
	name_card.add_child(badge)

	status_badge_label = Label.new()
	status_badge_label.name = "BadgeLabel"
	status_badge_label.text = "ONLINE"
	status_badge_label.position = Vector2.ZERO
	status_badge_label.size = badge.size
	status_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status_badge_label, 17)
	badge.add_child(status_badge_label)

	var stats_back = Panel.new()
	stats_back.name = "StatsBack"
	stats_back.position = Vector2(34, 236)
	stats_back.size = Vector2(PROFILE_W - 68, 168)
	stats_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		2,
		14,
		6
	))
	panel.add_child(stats_back)

	var stats_gloss = ColorRect.new()
	stats_gloss.name = "StatsGloss"
	stats_gloss.position = Vector2(18, 12)
	stats_gloss.size = Vector2(stats_back.size.x - 36, 16)
	stats_gloss.color = Color(0.65, 0.90, 1.0, 0.05)
	stats_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_back.add_child(stats_gloss)

	var stats_title = Label.new()
	stats_title.name = "StatsTitle"
	stats_title.text = "ACCOUNT"
	stats_title.position = Vector2(44, 232)
	stats_title.size = Vector2(250, 28)
	stats_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(stats_title, 24, Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(stats_title)

	create_section_line("StatsLine", Vector2(44, 263), PROFILE_W - 88)

	level_label = create_stat_card("LEVEL", "1", Vector2(52, 282), Vector2(324, 60))
	xp_label = create_stat_card("XP", "0 / 300", Vector2(388, 282), Vector2(320, 60))
	world_label = create_stat_card("CURRENT WORLD", "Unknown", Vector2(52, 354), Vector2(324, 60))
	playtime_label = create_stat_card("STATUS", "Account profile", Vector2(388, 354), Vector2(320, 60))


func create_section_line(line_name: String, line_position: Vector2, line_width: float):
	var line = ColorRect.new()
	line.name = line_name
	line.position = line_position
	line.size = Vector2(line_width, 3)
	line.color = Color(0.42, 0.82, 1.0, 0.46)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)


func create_stat_card(title_text: String, value_text: String, card_position: Vector2, card_size: Vector2) -> Label:
	var card = Panel.new()
	card.name = title_text.replace(" ", "") + "Card"
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.82, 0.94, 1.0, 0.10),
		Color(0.42, 0.78, 1.0, 0.34),
		3,
		12,
		5
	))
	panel.add_child(card)

	var title = Label.new()
	title.name = "Title"
	title.text = title_text
	title.position = Vector2(14, 8)
	title.size = Vector2(card_size.x - 28, 18)
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title, 12)
	card.add_child(title)

	var value = Label.new()
	value.name = "Value"
	value.text = value_text
	value.position = Vector2(14, 29)
	value.size = Vector2(card_size.x - 28, 26)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(value, 17)
	card.add_child(value)

	return value


func create_action_buttons():
	action_panel = Panel.new()
	action_panel.name = "ActionPanel"
	action_panel.position = Vector2(34, PROFILE_H - 70)
	action_panel.size = Vector2(PROFILE_W - 68, 46)
	action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		2,
		12,
		3
	))
	panel.add_child(action_panel)

	worlds_button = make_action_button("WORLDS", Vector2(12, 6), true, Vector2(154, 34))
	worlds_button.pressed.connect(_on_worlds_pressed)
	action_panel.add_child(worlds_button)

	titles_button = make_action_button("TITLES", Vector2(178, 6), false, Vector2(154, 34))
	titles_button.pressed.connect(_on_titles_pressed)
	action_panel.add_child(titles_button)

	trade_button = make_action_button("TRADE", Vector2(12, 6), true, Vector2(178, 34))
	trade_button.visible = false
	trade_button.pressed.connect(_on_trade_pressed)
	action_panel.add_child(trade_button)

	friend_button = make_action_button("ADD FRIEND", Vector2(202, 6), false, Vector2(178, 34))
	friend_button.visible = false
	friend_button.pressed.connect(_on_friend_pressed)
	action_panel.add_child(friend_button)

	close_action_button = make_action_button("CLOSE", Vector2(action_panel.size.x - 166, 6), false, Vector2(154, 34))
	close_action_button.pressed.connect(close_menu)
	action_panel.add_child(close_action_button)

	update_action_buttons()


func create_locked_worlds_panel():
	locked_worlds_blocker = ColorRect.new()
	locked_worlds_blocker.name = "LockedWorldsBlocker"
	locked_worlds_blocker.color = Color(0.0, 0.0, 0.0, 0.36)
	locked_worlds_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_worlds_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	locked_worlds_blocker.visible = false
	locked_worlds_blocker.gui_input.connect(_on_locked_worlds_blocker_gui_input)
	add_child(locked_worlds_blocker)

	locked_worlds_panel = Control.new()
	locked_worlds_panel.name = "LockedWorldsPanel"
	locked_worlds_panel.size = Vector2(LOCKED_WORLDS_W, LOCKED_WORLDS_H)
	locked_worlds_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_worlds_panel.visible = false
	locked_worlds_panel.gui_input.connect(_on_panel_gui_input)
	add_child(locked_worlds_panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = locked_worlds_panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		20,
		0
	))
	locked_worlds_panel.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = locked_worlds_panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		20,
		12
	))
	locked_worlds_panel.add_child(panel_back)

	var header = Panel.new()
	header.name = "Header"
	header.position = Vector2.ZERO
	header.size = Vector2(LOCKED_WORLDS_W, PROFILE_HEADER_H)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		20,
		8
	))
	locked_worlds_panel.add_child(header)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, PROFILE_HEADER_H - 5.0)
	top_line.size = Vector2(LOCKED_WORLDS_W, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_worlds_panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "LOCKED WORLDS"
	title.position = Vector2(30, 8)
	title.size = Vector2(410, 48)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 38)
	locked_worlds_panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "YOUR ACTIVE LOCKS"
	subtitle.position = Vector2(36, 56)
	subtitle.size = Vector2(260, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 13)
	locked_worlds_panel.add_child(subtitle)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(LOCKED_WORLDS_W - 76, 14)
	close_button.size = Vector2(48, 46)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_profile_arcade_button_style(close_button, false, true, 22)
	close_button.pressed.connect(close_locked_worlds_panel)
	locked_worlds_panel.add_child(close_button)

	var list_back = Panel.new()
	list_back.name = "ListBack"
	list_back.position = Vector2(28, 100)
	list_back.size = Vector2(LOCKED_WORLDS_W - 56, LOCKED_WORLDS_H - 126)
	list_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		5
	))
	locked_worlds_panel.add_child(list_back)

	var scroll = ScrollContainer.new()
	scroll.name = "LockedWorldsScroll"
	scroll.position = Vector2(36, 108)
	scroll.size = Vector2(LOCKED_WORLDS_W - 72, LOCKED_WORLDS_H - 142)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_worlds_panel.add_child(scroll)

	locked_worlds_rows_root = Control.new()
	locked_worlds_rows_root.name = "LockedWorldsRows"
	locked_worlds_rows_root.size = scroll.size
	locked_worlds_rows_root.custom_minimum_size = scroll.size
	locked_worlds_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(locked_worlds_rows_root)

	locked_worlds_empty_label = Label.new()
	locked_worlds_empty_label.name = "EmptyLabel"
	locked_worlds_empty_label.text = "No currently locked worlds owned by this profile."
	locked_worlds_empty_label.position = Vector2(52, 230)
	locked_worlds_empty_label.size = Vector2(LOCKED_WORLDS_W - 104, 42)
	locked_worlds_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_worlds_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_worlds_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(locked_worlds_empty_label, 18, PixelUIStyle.TEXT_SOFT)
	locked_worlds_panel.add_child(locked_worlds_empty_label)

	call_deferred("apply_locked_worlds_scrollbar_style")


func make_action_button(button_text: String, button_position: Vector2, yellow: bool = false, button_size: Vector2 = Vector2(104, 30)) -> Button:
	var button = Button.new()
	button.name = "Button_" + button_text
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	apply_profile_arcade_button_style(button, yellow, false, 13)

	return button


func apply_profile_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
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


func apply_locked_worlds_scrollbar_style():
	if locked_worlds_panel == null:
		return

	var scroll = locked_worlds_panel.get_node_or_null("LockedWorldsScroll")
	if scroll == null or not (scroll is ScrollContainer):
		return

	var scrollbar = scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func update_position():
	if panel == null:
		return

	var screen_size = get_viewport_rect().size
	var max_x = max(12.0, screen_size.x - panel.size.x - 12.0)
	var max_y = max(46.0, screen_size.y - panel.size.y - 24.0)
	panel.position = Vector2(
		clamp((screen_size.x - panel.size.x) / 2.0, 12.0, max_x),
		clamp((screen_size.y - panel.size.y) / 2.0, 46.0, max_y)
	)

	if locked_worlds_panel != null:
		var locked_max_x = max(12.0, screen_size.x - locked_worlds_panel.size.x - 12.0)
		var locked_max_y = max(46.0, screen_size.y - locked_worlds_panel.size.y - 24.0)
		locked_worlds_panel.position = Vector2(
			clamp((screen_size.x - locked_worlds_panel.size.x) / 2.0, 12.0, locked_max_x),
			clamp((screen_size.y - locked_worlds_panel.size.y) / 2.0, 46.0, locked_max_y)
		)


func update_menu_info():
	if world == null:
		return

	update_position()
	update_action_buttons()

	var profile_data = get_active_profile_data()
	var equipment_data = get_active_equipment_data(profile_data)

	if player_name_label != null:
		var profile_name = get_display_profile_name()

		player_name_label.text = profile_name.to_upper()
		if avatar_label != null:
			avatar_label.text = profile_name.substr(0, 1).to_upper() if profile_name.strip_edges() != "" else "P"

	if account_label != null:
		account_label.text = "REMOTE PLAYER" if profile_mode == "remote" else "LOCAL ACCOUNT"

	if status_badge_label != null:
		if profile_mode == "remote":
			if remote_profile_lookup_status == "loading":
				status_badge_label.text = "CHECKING"
			elif remote_profile_lookup_status == "missing":
				status_badge_label.text = "NOT FOUND"
			elif is_remote_profile_online():
				status_badge_label.text = "ONLINE"
			else:
				status_badge_label.text = "OFFLINE"
		else:
			status_badge_label.text = "ONLINE"

	if level_label != null:
		if profile_mode == "remote":
			level_label.text = str(profile_data.get("player_level", profile_data.get("level", "-"))) if profile_data.has("player_data_version") or profile_data.has("player_level") or profile_data.has("level") else "-"
		elif "player_level" in world:
			level_label.text = str(int(world.player_level))
		else:
			level_label.text = "1"

	if xp_label != null:
		var xp_value = 0
		var xp_needed = 300

		if profile_mode == "remote":
			xp_value = int(profile_data.get("player_xp", profile_data.get("xp", 0)))
			xp_needed = int(profile_data.get("player_xp_needed", profile_data.get("xp_needed", 300)))
			xp_label.text = ("MAX" if xp_needed <= 0 else str(xp_value) + " / " + str(xp_needed)) if profile_data.has("player_data_version") or profile_data.has("player_xp") or profile_data.has("xp") else "-"
		elif "player_xp" in world:
			xp_value = int(world.player_xp)
			if "player_xp_needed" in world:
				xp_needed = int(world.player_xp_needed)
			xp_label.text = "MAX" if xp_needed <= 0 else str(xp_value) + " / " + str(xp_needed)
		else:
			xp_label.text = str(xp_value) + " / " + str(xp_needed)

	if gems_label != null:
		var gems = 0

		if profile_mode == "remote":
			var remote_currency = profile_data.get("currency_inventory", {})
			if remote_currency is Dictionary:
				var remote_gems = int(remote_currency.get("gem", 0))
				gems_label.text = format_gem_amount(remote_gems)
			else:
				gems_label.text = "-"
		elif "currency_inventory" in world:
			gems_label.text = world.get_currency_display_text("gem")
		else:
			gems_label.text = format_gem_amount(gems)

	if health_label != null:
		if profile_mode == "remote":
			health_label.text = str(int(profile_data.get("player_health", 3))) + " HP" if profile_data.has("player_data_version") or profile_data.has("player_health") else "-"
		elif "player_health" in world:
			health_label.text = str(int(world.player_health)) + " HP"
		else:
			health_label.text = "3 HP"

	if world_label != null:
		var world_name = ""

		if profile_mode == "remote":
			world_name = str(remote_profile_data.get("world", remote_profile_data.get("current_world", "")))
			if world_name.strip_edges() == "" and remote_profile_lookup_status != "loading" and remote_profile_lookup_status != "missing" and not is_remote_profile_online():
				world_name = "Offline"
		elif world.has_method("get_current_world_display_name"):
			world_name = str(world.get_current_world_display_name())
		elif "current_world_name" in world:
			world_name = str(world.current_world_name)

		if world_name.strip_edges() == "":
			world_name = "Unknown"

		world_label.text = world_name.to_upper()

	if hand_label != null:
		hand_label.text = format_profile_item_name(str(equipment_data.get("hand", profile_data.get("equipped_tool", ""))))
	if back_label != null:
		back_label.text = format_profile_item_name(str(equipment_data.get("back", profile_data.get("equipped_back_item", ""))))
	if shirt_label != null:
		shirt_label.text = format_profile_item_name(str(equipment_data.get("shirt", profile_data.get("equipped_shirt_item", ""))))
	if pants_label != null:
		pants_label.text = format_profile_item_name(str(equipment_data.get("pants", profile_data.get("equipped_pants_item", ""))))

	if playtime_label != null:
		if profile_mode == "remote":
			if remote_profile_lookup_status == "loading":
				playtime_label.text = "Checking..."
			elif remote_profile_lookup_status == "missing":
				playtime_label.text = "Not found"
			elif is_remote_profile_online():
				playtime_label.text = "Online now"
			elif str(remote_profile_data.get("last_seen_at", "")).strip_edges() != "":
				playtime_label.text = "Last seen " + format_profile_date(str(remote_profile_data.get("last_seen_at", "")))
			else:
				playtime_label.text = "Offline"
		else:
			playtime_label.text = "Saved account"


func get_active_profile_data() -> Dictionary:
	if profile_mode == "remote":
		var nested = remote_profile_data.get("player_data", {})
		if nested is Dictionary:
			return nested
		return remote_profile_data

	if world != null and world.save_manager != null and world.save_manager.has_method("get_player_save_data"):
		var local_data = world.save_manager.get_player_save_data()
		if local_data is Dictionary:
			return local_data

	return {}


func get_active_equipment_data(profile_data: Dictionary) -> Dictionary:
	var equipment_data = {}

	if profile_mode == "remote":
		var remote_equipment = remote_profile_data.get("equipment_slots", {})
		if remote_equipment is Dictionary:
			equipment_data = remote_equipment.duplicate(true)

		var saved_equipment = profile_data.get("equipment_slots", {})
		if saved_equipment is Dictionary:
			for key in saved_equipment.keys():
				equipment_data[key] = saved_equipment[key]
	else:
		equipment_data = {
			"hand": str(world.equipped_tool),
			"back": str(world.equipped_back_item),
			"hat": str(world.equipped_hat_item),
			"hair": str(world.equipped_hair_item),
			"eyewear": str(world.equipped_eyewear_item),
			"beard": str(world.equipped_beard_item),
			"body_accessory": str(world.equipped_body_accessory_item),
			"shirt": str(world.equipped_shirt_item),
			"pants": str(world.equipped_pants_item)
		}

	if not equipment_data.has("hand"):
		equipment_data["hand"] = str(profile_data.get("equipped_tool", ""))
	if not equipment_data.has("back"):
		equipment_data["back"] = str(profile_data.get("equipped_back_item", ""))
	if not equipment_data.has("hat"):
		equipment_data["hat"] = str(profile_data.get("equipped_hat_item", ""))
	if not equipment_data.has("hair"):
		equipment_data["hair"] = str(profile_data.get("equipped_hair_item", ""))
	if not equipment_data.has("eyewear"):
		equipment_data["eyewear"] = str(profile_data.get("equipped_eyewear_item", ""))
	if not equipment_data.has("beard"):
		equipment_data["beard"] = str(profile_data.get("equipped_beard_item", ""))
	if not equipment_data.has("body_accessory"):
		equipment_data["body_accessory"] = str(profile_data.get("equipped_body_accessory_item", ""))
	if not equipment_data.has("shirt"):
		equipment_data["shirt"] = str(profile_data.get("equipped_shirt_item", ""))
	if not equipment_data.has("pants"):
		equipment_data["pants"] = str(profile_data.get("equipped_pants_item", ""))

	return equipment_data


func format_profile_item_name(item_id: String) -> String:
	var clean_id = item_id.strip_edges()
	if clean_id == "":
		return "None"

	if world != null and world.has_method("get_item_display_name"):
		var item_category = "block"
		if world.item_database.has(clean_id):
			item_category = str(world.item_database[clean_id].get("category", "block"))
		return str(world.get_item_display_name(clean_id, item_category))

	return clean_id.replace("_", " ").capitalize()


func format_gem_amount(amount: int) -> String:
	if world != null and world.has_method("format_currency_amount"):
		return world.format_currency_amount(amount)

	var digits = str(max(0, amount))
	var result = ""
	var group_count = 0

	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1

	return result


func format_profile_date(value: String) -> String:
	var clean = value.strip_edges()
	if clean.length() >= 10:
		return clean.substr(0, 10)
	return clean


func is_remote_profile_online() -> bool:
	if profile_mode != "remote":
		return false

	if remote_profile_data.has("online"):
		return bool(remote_profile_data.get("online", false))

	return str(remote_profile_data.get("player_id", "")).strip_edges() != "" and remote_profile_lookup_status != "missing"


func get_remote_profile_lookup_username() -> String:
	var requested_username: String = remote_profile_requested_username.strip_edges()
	if requested_username != "":
		return requested_username

	return str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()


func profile_usernames_match(left: String, right: String) -> bool:
	var clean_left: String = left.strip_edges()
	var clean_right: String = right.strip_edges()
	if clean_left == "" or clean_right == "":
		return false

	return clean_left.to_lower() == clean_right.to_lower()


func extract_profile_response_username(data: Dictionary) -> String:
	var direct_keys: Array[String] = ["username", "account_username", "name"]
	for key: String in direct_keys:
		var value: String = str(data.get(key, "")).strip_edges()
		if value != "":
			return value

	var nested_keys: Array[String] = ["account", "account_data", "player_data", "data"]
	for nested_key: String in nested_keys:
		var nested_value: Variant = data.get(nested_key, {})
		if nested_value is Dictionary:
			var nested_data: Dictionary = nested_value
			for key: String in direct_keys:
				var value: String = str(nested_data.get(key, "")).strip_edges()
				if value != "":
					return value

	return ""


func get_display_profile_name() -> String:
	if profile_mode == "remote":
		var remote_name = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
		return remote_name if remote_name != "" else "Player"

	var profile_name = ""

	if world.has_method("get_current_profile_name"):
		profile_name = str(world.get_current_profile_name()).strip_edges()

	return profile_name if profile_name != "" else "USO"


func update_action_buttons():
	var has_pending_trade = profile_mode == "remote" and world != null and world.has_method("has_pending_trade_from_player") and world.has_pending_trade_from_player(remote_profile_data)
	var remote_online = is_remote_profile_online()
	var friend_status: String = get_remote_friend_status()
	var panel_width: float = action_panel.size.x if action_panel != null else PROFILE_W - 68

	if trade_button != null:
		trade_button.visible = profile_mode == "remote" and remote_online
		trade_button.text = "ACCEPT" if has_pending_trade else "TRADE"
		trade_button.position = Vector2(12, 6)
		trade_button.size = Vector2(178, 34)
		apply_profile_arcade_button_style(trade_button, true, false, 13)
	if friend_button != null:
		friend_button.visible = profile_mode == "remote" and friend_status != "self"
		friend_button.disabled = friend_status == "outgoing" or friend_status == "friends"
		match friend_status:
			"friends":
				friend_button.text = "FRIENDS"
			"outgoing":
				friend_button.text = "PENDING"
			"incoming":
				friend_button.text = "ACCEPT"
			_:
				friend_button.text = "ADD FRIEND"
		friend_button.position = Vector2(202 if trade_button != null and trade_button.visible else 12, 6)
		friend_button.size = Vector2(178, 34)
		apply_profile_arcade_button_style(friend_button, friend_status == "incoming", false, 13)
	if worlds_button != null:
		worlds_button.visible = profile_mode != "remote"
		worlds_button.position = Vector2(12, 6)
		worlds_button.size = Vector2(154, 34)
	if titles_button != null:
		titles_button.visible = profile_mode != "remote"
		titles_button.position = Vector2(178, 6)
		titles_button.size = Vector2(154, 34)
	if close_action_button != null:
		close_action_button.position = Vector2(panel_width - 166, 6)
		close_action_button.size = Vector2(154, 34)


func get_remote_friend_status() -> String:
	if profile_mode != "remote":
		return "none"

	var username: String = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if username == "":
		return "none"

	var status: String = str(remote_profile_data.get("friend_status", "")).strip_edges().to_lower()
	if status == "" and world != null and world.has_method("get_friend_status_for_username"):
		status = str(world.get_friend_status_for_username(username)).strip_edges().to_lower()
	if status == "":
		status = "none"
	return status


func _on_worlds_pressed():
	open_locked_worlds_panel()


func open_locked_worlds_panel():
	if locked_worlds_panel == null:
		return

	refresh_locked_worlds_list()
	request_owned_locked_worlds_refresh()
	update_position()
	if locked_worlds_blocker != null:
		locked_worlds_blocker.visible = true
	locked_worlds_panel.visible = true
	PixelUIStyle.play_panel_open(locked_worlds_panel, Vector2(0.96, 0.96), 0.16)


func close_locked_worlds_panel():
	if locked_worlds_blocker != null:
		locked_worlds_blocker.visible = false
	if locked_worlds_panel != null:
		locked_worlds_panel.visible = false


func request_owned_locked_worlds_refresh():
	if profile_mode != "local":
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_owned_locked_worlds"):
		locked_worlds_loading = false
		locked_worlds_error = "Owned locked worlds are unavailable."
		refresh_locked_worlds_list()
		return

	locked_worlds_request_id = "profile_owned_" + str(Time.get_ticks_msec())
	locked_worlds_loading = true
	locked_worlds_error = ""
	refresh_locked_worlds_list()

	if not bool(network.request_owned_locked_worlds(locked_worlds_request_id)):
		locked_worlds_loading = false
		locked_worlds_error = "Sign in to load owned locked worlds."
		refresh_locked_worlds_list()


func _on_owned_locked_worlds_received(data: Dictionary):
	if locked_worlds_request_id != "":
		var response_request_id = str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != locked_worlds_request_id:
			return

	locked_worlds_loading = false
	locked_worlds_error = ""

	if not bool(data.get("ok", true)):
		server_locked_world_entries.clear()
		locked_worlds_error = str(data.get("message", "Could not load locked worlds.")).strip_edges()
		if locked_worlds_error == "":
			locked_worlds_error = "Could not load locked worlds."
		refresh_locked_worlds_list()
		return

	var incoming = data.get("worlds", [])
	server_locked_world_entries.clear()
	if incoming is Array:
		for raw_entry in incoming:
			if raw_entry is Dictionary:
				server_locked_world_entries.append(raw_entry.duplicate(true))

	refresh_locked_worlds_list()


func refresh_locked_worlds_list():
	if locked_worlds_rows_root == null:
		return

	for child in locked_worlds_rows_root.get_children():
		child.queue_free()

	var entries = get_owned_locked_world_entries()

	if locked_worlds_empty_label != null:
		locked_worlds_empty_label.visible = entries.is_empty()
		if locked_worlds_loading:
			locked_worlds_empty_label.text = "Loading locked worlds from server..."
		elif locked_worlds_error != "":
			locked_worlds_empty_label.text = locked_worlds_error
		else:
			locked_worlds_empty_label.text = "No currently locked worlds owned by this profile."

	var scroll_size = Vector2(LOCKED_WORLDS_W - 72, LOCKED_WORLDS_H - 142)
	if entries.is_empty():
		locked_worlds_rows_root.custom_minimum_size = scroll_size
		locked_worlds_rows_root.size = scroll_size
		return

	var gap = 10.0
	locked_worlds_rows_root.custom_minimum_size = Vector2(
		scroll_size.x,
		max(scroll_size.y, entries.size() * (LOCKED_WORLD_ROW_H + gap) - gap + 8.0)
	)
	locked_worlds_rows_root.size = locked_worlds_rows_root.custom_minimum_size

	for i in range(entries.size()):
		create_locked_world_row(entries[i], Vector2(0, i * (LOCKED_WORLD_ROW_H + gap)))


func get_owned_locked_world_entries() -> Array:
	var entries = []
	var seen_worlds = {}
	var owner_name = normalize_profile_name(get_display_profile_name())

	if owner_name == "":
		return entries

	add_current_locked_world_entry(entries, seen_worlds, owner_name)
	add_server_locked_world_entries(entries, seen_worlds, owner_name)

	if world == null:
		return entries

	if world.save_manager != null and world.save_manager.has_method("ensure_world_save_folder"):
		world.save_manager.ensure_world_save_folder()

	var dir = DirAccess.open(world.WORLD_SAVE_FOLDER)
	if dir == null:
		return entries

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".json"):
			add_locked_world_entry_from_file(entries, seen_worlds, owner_name, world.WORLD_SAVE_FOLDER + file_name, file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(Callable(self, "sort_locked_world_entries"))
	return entries


func mark_current_world_as_seen(seen_worlds: Dictionary):
	if world == null:
		return

	var world_name = str(world.current_world_name).strip_edges()
	if world_name == "":
		return

	seen_worlds[normalize_world_key(world_name)] = true


func add_current_locked_world_entry(entries: Array, seen_worlds: Dictionary, owner_name: String):
	if world == null or world.world_lock_manager == null:
		return
	if not bool(world.world_lock_manager.is_locked):
		return
	if not is_valid_lock_position(int(world.world_lock_manager.lock_grid_pos.x), int(world.world_lock_manager.lock_grid_pos.y)):
		return
	if not current_world_has_lock_at_position(world.world_lock_manager.lock_grid_pos):
		return

	var lock_owner = normalize_profile_name(str(world.world_lock_manager.owner_name))
	if lock_owner != owner_name:
		return

	var world_name = str(world.current_world_name).strip_edges()
	if world_name == "":
		world_name = "UNKNOWN"

	var key = normalize_world_key(world_name)
	seen_worlds[key] = true

	var access_count = 0
	if world.world_lock_manager.allowed_players is Array:
		access_count = world.world_lock_manager.allowed_players.size()

	entries.append({
		"world_name": world_name.to_upper(),
		"owner_name": lock_owner,
		"lock_grid_x": int(world.world_lock_manager.lock_grid_pos.x),
		"lock_grid_y": int(world.world_lock_manager.lock_grid_pos.y),
		"access_count": access_count,
		"public_build": bool(world.world_lock_manager.public_build),
		"trusted_builder_slot_limit": int(world.world_lock_manager.trusted_builder_slot_limit),
		"current": true
	})


func add_server_locked_world_entries(entries: Array, seen_worlds: Dictionary, owner_name: String):
	for raw_entry in server_locked_world_entries:
		if not (raw_entry is Dictionary):
			continue

		var lock_owner = normalize_profile_name(str(raw_entry.get("owner_name", "")))
		if lock_owner != owner_name:
			continue

		var world_name = str(raw_entry.get("world_name", "")).strip_edges().to_upper()
		if world_name == "":
			continue

		var key = normalize_world_key(world_name)
		if seen_worlds.has(key):
			continue
		seen_worlds[key] = true

		entries.append({
			"world_name": world_name,
			"owner_name": lock_owner,
			"lock_grid_x": int(raw_entry.get("lock_grid_x", 999999)),
			"lock_grid_y": int(raw_entry.get("lock_grid_y", 999999)),
			"access_count": max(0, int(raw_entry.get("access_count", 0))),
			"public_build": bool(raw_entry.get("public_build", false)),
			"trusted_builder_slot_limit": max(0, int(raw_entry.get("trusted_builder_slot_limit", 0))),
			"current": false,
			"source_label": str(raw_entry.get("source_label", "SERVER"))
		})


func add_locked_world_entry_from_file(entries: Array, seen_worlds: Dictionary, owner_name: String, file_path: String, file_name: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		return

	var lock_data = parsed.get("world_lock", {})
	if not (lock_data is Dictionary):
		return
	if not bool(lock_data.get("is_locked", false)):
		return

	var lock_x = int(lock_data.get("lock_grid_x", 999999))
	var lock_y = int(lock_data.get("lock_grid_y", 999999))
	if not is_valid_lock_position(lock_x, lock_y):
		return
	if not saved_world_has_lock_at_position(parsed, lock_x, lock_y):
		return

	var lock_owner = normalize_profile_name(str(lock_data.get("owner_name", "")))
	if lock_owner != owner_name:
		return

	var world_name = str(parsed.get("world_name", "")).strip_edges()
	if world_name == "":
		world_name = file_name.replace(".json", "").to_upper()

	var key = normalize_world_key(world_name)
	if seen_worlds.has(key):
		return
	seen_worlds[key] = true

	var allowed = lock_data.get("allowed_players", [])
	var access_count = allowed.size() if allowed is Array else 0

	entries.append({
		"world_name": world_name.to_upper(),
		"owner_name": lock_owner,
		"lock_grid_x": lock_x,
		"lock_grid_y": lock_y,
		"access_count": access_count,
		"public_build": bool(lock_data.get("public_build", false)),
		"trusted_builder_slot_limit": int(lock_data.get("trusted_builder_slot_limit", 0)),
		"current": false
	})


func is_valid_lock_position(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < 999000 and y < 999000


func current_world_has_lock_at_position(lock_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not world.blocks.has(lock_pos):
		return false
	var block_type := str(world.blocks[lock_pos].get("type", ""))
	if world.has_method("is_world_lock_block_type"):
		return bool(world.is_world_lock_block_type(block_type))
	return block_type == "world_lock" or block_type == "super_world_lock"


func saved_world_has_lock_at_position(world_data: Dictionary, lock_x: int, lock_y: int) -> bool:
	var blocks = world_data.get("blocks", [])
	if not (blocks is Array):
		return false

	for block_data in blocks:
		if not (block_data is Dictionary):
			continue
		if int(block_data.get("x", 999999)) != lock_x:
			continue
		if int(block_data.get("y", 999999)) != lock_y:
			continue
		var block_type := str(block_data.get("type", ""))
		if world != null and world.has_method("is_world_lock_block_type"):
			return bool(world.is_world_lock_block_type(block_type))
		return block_type == "world_lock" or block_type == "super_world_lock"

	return false


func create_locked_world_row(entry: Dictionary, row_position: Vector2):
	var row_width = LOCKED_WORLDS_W - 88

	var row = Panel.new()
	row.name = "LockedWorld_" + str(entry.get("world_name", "WORLD"))
	row.position = row_position
	row.size = Vector2(row_width, LOCKED_WORLD_ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.026, 0.058, 0.100, 0.92),
		Color(0.18, 0.45, 0.72, 0.55),
		3,
		12,
		5
	))
	locked_worlds_rows_root.add_child(row)

	var world_name = str(entry.get("world_name", "WORLD"))
	var title = Label.new()
	title.name = "WorldName"
	title.text = world_name
	title.position = Vector2(16, 10)
	title.size = Vector2(row_width - 184, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 21)
	row.add_child(title)

	var lock_pos = get_lock_position_text_from_entry(entry)
	var build_text = "PUBLIC BUILD ON" if bool(entry.get("public_build", false)) else "OWNER ACCESS"
	var detail = "Lock: " + lock_pos + "  |  " + build_text + "  |  Access: " + str(int(entry.get("access_count", 0)))
	var detail_label = Label.new()
	detail_label.name = "WorldDetail"
	detail_label.text = detail
	detail_label.position = Vector2(18, 42)
	detail_label.size = Vector2(row_width - 190, 22)
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.clip_text = true
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(detail_label, 13)
	row.add_child(detail_label)

	var status_button = Button.new()
	status_button.name = "WorldOpenButton"
	status_button.text = "CURRENT" if bool(entry.get("current", false)) else "ENTER"
	status_button.position = Vector2(row_width - 132, 18)
	status_button.size = Vector2(110, 38)
	status_button.mouse_filter = Control.MOUSE_FILTER_STOP
	status_button.disabled = bool(entry.get("current", false))
	apply_profile_arcade_button_style(status_button, true, false, 14)
	status_button.pressed.connect(_on_locked_world_enter_pressed.bind(world_name))
	row.add_child(status_button)


func normalize_profile_name(raw_name: String) -> String:
	return raw_name.strip_edges().to_upper()


func normalize_world_key(raw_name: String) -> String:
	return raw_name.strip_edges().to_upper()


func sort_locked_world_entries(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("current", false)) != bool(b.get("current", false)):
		return bool(a.get("current", false))
	return str(a.get("world_name", "")) < str(b.get("world_name", ""))


func get_lock_position_text_from_entry(entry: Dictionary) -> String:
	var x = int(entry.get("lock_grid_x", 999999))
	var y = int(entry.get("lock_grid_y", 999999))
	if x >= 999000:
		return "Unknown"
	return str(x) + ", " + str(y)


func _on_locked_world_enter_pressed(world_name: String):
	close_locked_worlds_panel()
	close_menu()
	if world != null and world.has_method("enter_world_by_name"):
		world.enter_world_by_name(world_name)


func _on_titles_pressed():
	notify("Titles will be added later.")


func _on_trade_pressed():
	if profile_mode != "remote":
		return

	if world != null and world.has_method("has_pending_trade_from_player") and world.has_pending_trade_from_player(remote_profile_data):
		if world.has_method("accept_trade_from_player"):
			world.accept_trade_from_player(remote_profile_data)
			close_menu()
			return

	if world != null and world.has_method("request_trade_with_player"):
		world.request_trade_with_player(remote_profile_data)
		close_menu()
	else:
		notify("Trading is not ready yet.")


func _on_friend_pressed():
	if profile_mode != "remote":
		return

	var username: String = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if username == "":
		notify("Could not find that player.")
		return

	var friend_status: String = get_remote_friend_status()
	if friend_status == "incoming":
		if world != null and world.has_method("accept_friend_request_from"):
			world.accept_friend_request_from(username)
			close_menu()
			return
	elif friend_status == "none":
		if world != null and world.has_method("request_friend_with_player"):
			remote_profile_data["friend_status"] = "outgoing"
			world.request_friend_with_player(remote_profile_data)
			update_action_buttons()
			close_menu()
			return

	notify("Friends are not ready yet.")


func notify(message: String):
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)


func open_menu():
	profile_mode = "local"
	remote_profile_data.clear()
	remote_profile_lookup_status = ""
	remote_profile_request_id = ""
	remote_profile_requested_username = ""
	is_menu_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_menu_info()
	PixelUIStyle.play_panel_open(panel)


func open_remote_profile(player_data: Dictionary):
	profile_mode = "remote"
	remote_profile_data = player_data.duplicate(true)
	if not remote_profile_data.has("online") and str(remote_profile_data.get("player_id", "")).strip_edges() != "":
		remote_profile_data["online"] = true
	remote_profile_request_id = ""
	remote_profile_requested_username = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if is_remote_profile_online():
		remote_profile_lookup_status = "online"
	elif str(remote_profile_data.get("lookup_source", "")).strip_edges().to_lower() == "command":
		remote_profile_lookup_status = "offline"
	else:
		remote_profile_lookup_status = "loading"
	is_menu_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_menu_info()
	PixelUIStyle.play_panel_open(panel)
	request_remote_profile_details()


func request_remote_profile_details():
	if world == null:
		return

	var username = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if username == "":
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_state_request_with_context"):
		return

	var request_id = str(network.send_player_state_request_with_context(username, {
		"purpose": "remote_player_profile",
		"username": username,
		"requested_username": username,
		"remote_player": remote_profile_data.duplicate(true)
	}))

	if request_id != "" and playtime_label != null:
		remote_profile_request_id = request_id
		remote_profile_requested_username = username
		if not is_remote_profile_online() and remote_profile_lookup_status != "offline":
			remote_profile_lookup_status = "loading"
		update_menu_info()
		call_deferred("_wait_for_remote_profile_lookup", request_id, username)


func _wait_for_remote_profile_lookup(request_id: String, username: String):
	await get_tree().create_timer(REMOTE_PROFILE_LOOKUP_TIMEOUT).timeout

	if profile_mode != "remote":
		return
	if remote_profile_request_id != request_id:
		return
	if remote_profile_lookup_status != "loading":
		return

	var current_username: String = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if current_username != "" and username.strip_edges() != "" and current_username.to_lower() != username.strip_edges().to_lower():
		return

	remote_profile_data["online"] = false
	remote_profile_lookup_status = "offline"
	remote_profile_request_id = ""
	update_menu_info()


func handle_player_state_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	if profile_mode != "remote":
		return

	if remote_profile_request_id != "" and request_id != "" and request_id != remote_profile_request_id:
		return

	var current_requested_username: String = get_remote_profile_lookup_username()
	var requested_username: String = str(request_context.get("requested_username", request_context.get("username", current_requested_username))).strip_edges()
	if requested_username == "":
		requested_username = current_requested_username

	if current_requested_username != "" and requested_username != "" and not profile_usernames_match(current_requested_username, requested_username):
		return

	var response_username: String = extract_profile_response_username(data)
	if response_username != "" and requested_username != "" and not profile_usernames_match(response_username, requested_username):
		return

	var account_data_value: Variant = data.get("account", {})
	var account_username: String = ""
	if account_data_value is Dictionary:
		var account_data: Dictionary = account_data_value
		account_username = extract_profile_response_username(account_data)
		if account_username != "" and requested_username != "" and not profile_usernames_match(account_username, requested_username):
			return

	var player_data_value: Variant = data.get("player_data", {})
	if player_data_value is Dictionary:
		var player_data_preview: Dictionary = player_data_value
		var player_data_username: String = extract_profile_response_username(player_data_preview)
		if player_data_username != "" and requested_username != "" and not profile_usernames_match(player_data_username, requested_username):
			return

	if not bool(data.get("found", true)):
		if requested_username != "":
			remote_profile_data["username"] = requested_username
			remote_profile_data["name"] = requested_username
		remote_profile_lookup_status = "missing"
		remote_profile_request_id = ""
		update_menu_info()
		return

	if response_username == "":
		response_username = requested_username

	if response_username != "":
		remote_profile_data["username"] = response_username
		remote_profile_data["name"] = response_username

	for key: String in ["online", "world", "current_world", "last_seen_at", "created_at", "player_id", "role", "friend_status", "profile_bio"]:
		if data.has(key):
			remote_profile_data[key] = data[key]

	if account_data_value is Dictionary:
		var account_data: Dictionary = account_data_value
		if account_username != "":
			remote_profile_data["username"] = account_username
			remote_profile_data["name"] = account_username
		if str(account_data.get("last_seen_at", "")).strip_edges() != "" and not remote_profile_data.has("last_seen_at"):
			remote_profile_data["last_seen_at"] = str(account_data.get("last_seen_at", "")).strip_edges()
		if str(account_data.get("created_at", "")).strip_edges() != "" and not remote_profile_data.has("created_at"):
			remote_profile_data["created_at"] = str(account_data.get("created_at", "")).strip_edges()

	var equipment_slots = data.get("equipment_slots", {})
	if equipment_slots is Dictionary:
		remote_profile_data["equipment_slots"] = equipment_slots.duplicate(true)

	if player_data_value is Dictionary:
		var player_data: Dictionary = player_data_value
		remote_profile_data["player_data"] = player_data.duplicate(true)

	remote_profile_request_id = ""
	remote_profile_lookup_status = "online" if is_remote_profile_online() else "offline"
	update_menu_info()


func handle_friend_message(data: Dictionary) -> void:
	if profile_mode != "remote":
		return

	var username: String = str(remote_profile_data.get("username", remote_profile_data.get("name", ""))).strip_edges()
	if username == "":
		return

	var message_type: String = str(data.get("type", "")).strip_edges().to_lower()
	match message_type:
		"friend_request_sent":
			var target_username: String = str(data.get("target_username", "")).strip_edges()
			if profile_usernames_match(username, target_username):
				remote_profile_data["friend_status"] = str(data.get("friend_status", "outgoing")).strip_edges().to_lower()
		"friend_request_received":
			var from_username: String = str(data.get("from_username", data.get("requester_username", ""))).strip_edges()
			if profile_usernames_match(username, from_username):
				remote_profile_data["friend_status"] = "incoming"
		"friend_request_accepted", "friend_response_result":
			var friend_username: String = str(data.get("friend_username", data.get("from_username", ""))).strip_edges()
			if profile_usernames_match(username, friend_username) and bool(data.get("accepted", true)):
				remote_profile_data["friend_status"] = "friends"
		"friend_request_declined":
			var declined_username: String = str(data.get("friend_username", data.get("from_username", ""))).strip_edges()
			if profile_usernames_match(username, declined_username):
				remote_profile_data["friend_status"] = "none"
		"friend_state":
			if world != null and world.has_method("get_friend_status_for_username"):
				remote_profile_data["friend_status"] = str(world.get_friend_status_for_username(username)).strip_edges().to_lower()

	update_action_buttons()


func close_menu():
	is_menu_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_locked_worlds_panel()


func toggle_menu():
	if is_menu_open:
		close_menu()
	else:
		open_menu()


func is_open() -> bool:
	return is_menu_open


func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()

	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()


func _on_locked_worlds_blocker_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()

	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
