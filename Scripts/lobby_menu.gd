extends Control

const PROFILE_PATH := "user://pixelmania_profile.cfg"
const PLAYER_SAVE_FOLDER := "user://players/"
const WORLD_SCENE := "res://Scenes/main.tscn"
const LOGIN_SCENE := "res://Scenes/login_screen.tscn"
const PLAYER_IDLE_TEXTURE := "res://Assets/player/body/player_idle.png"
const BACKGROUND_TEXTURE := "res://Assets/ui/backgrounds/mountain_background.png"
const GRASS_BLOCK_TEXTURE := "res://Assets/blocks/basic blocks/grass_block.png"
const DIRT_BLOCK_TEXTURE := "res://Assets/blocks/basic blocks/dirt_block.png"
const LOBBY_HUB_WORLD := "START"
const MAX_ACTIVE_WORLD_ROWS := 6
const WORLD_POPULATION_REFRESH_SECONDS := 5.0
const PLAYER_MAX_LEVEL := 100
const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

var world_input: LineEdit
var status_label: Label
var username_label: Label
var profile_level_label: Label
var profile_xp_label: Label
var profile_xp_fill: ColorRect
var profile_xp_spark: ColorRect
var profile_gems_label: Label
var profile_total_xp_label: Label
var recent_worlds_list: VBoxContainer
var recent_worlds_title: Label
var recent_worlds_subtitle: Label
var recent_worlds_chip_label: Label
var active_worlds_button: Button
var world_list_mode := "active"
var world_population_cache: Dictionary = {}
var world_population_timer: Timer


func _ready() -> void:
	_build_screen()
	_load_profile()
	_connect_world_population_feed()
	_start_world_population_timer()
	_request_world_population_refresh()
	call_deferred("_start_lobby_idle_animation")


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_add_real_background()
	_add_background_shade()
	_add_lobby_energy_layers()
	_add_top_bar()
	_add_left_profile_panel()
	_add_recent_worlds_panel()
	_add_world_join_panel()
	_add_right_buttons()


func _add_real_background() -> void:
	var texture := load(BACKGROUND_TEXTURE)

	var bg := TextureRect.new()
	bg.name = "RealPixelMountainBackground"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if texture != null:
		bg.texture = texture
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		bg.modulate = Color(0.12, 0.55, 0.94)

	add_child(bg)


func _add_background_shade() -> void:
	var shade := ColorRect.new()
	shade.name = "BackgroundShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _add_lobby_energy_layers() -> void:
	var sky_lift := ColorRect.new()
	sky_lift.name = "SkyLift"
	sky_lift.anchor_left = 0.0
	sky_lift.anchor_top = 0.11
	sky_lift.anchor_right = 1.0
	sky_lift.anchor_bottom = 0.40
	sky_lift.color = Color(0.10, 0.58, 1.0, 0.10)
	sky_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky_lift)

	var horizon := ColorRect.new()
	horizon.name = "HorizonGlow"
	horizon.anchor_left = 0.0
	horizon.anchor_top = 0.73
	horizon.anchor_right = 1.0
	horizon.anchor_bottom = 0.81
	horizon.color = Color(0.35, 1.0, 0.55, 0.11)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizon)

	var foreground := ColorRect.new()
	foreground.name = "ForegroundDepth"
	foreground.anchor_left = 0.0
	foreground.anchor_top = 0.82
	foreground.anchor_right = 1.0
	foreground.anchor_bottom = 1.0
	foreground.color = Color(0.0, 0.04, 0.02, 0.28)
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foreground)

	_add_energy_stripe("CyanEnergyStripe", 0.07, 0.132, 0.44, 0.138, Color(0.25, 0.95, 1.0, 0.42), -0.012)
	_add_energy_stripe("GoldEnergyStripe", 0.55, 0.135, 0.88, 0.141, Color(1.0, 0.78, 0.18, 0.34), 0.010)
	_add_energy_stripe("GreenGroundStripe", 0.21, 0.805, 0.67, 0.812, Color(0.38, 1.0, 0.48, 0.18), -0.008)

	for i in range(9):
		var glint := ColorRect.new()
		glint.name = "PixelGlint" + str(i)
		var x := 0.08 + float((i * 17) % 82) / 100.0
		var y := 0.18 + float((i * 23) % 54) / 100.0
		glint.anchor_left = x
		glint.anchor_top = y
		glint.anchor_right = x
		glint.anchor_bottom = y
		glint.offset_left = 0
		glint.offset_top = 0
		glint.offset_right = 4
		glint.offset_bottom = 4
		glint.color = Color(1.0, 0.90, 0.24, 0.25) if i % 2 == 0 else Color(0.24, 0.94, 1.0, 0.20)
		glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glint)


func _add_energy_stripe(stripe_name: String, left: float, top: float, right: float, bottom: float, color: Color, rotation_amount: float) -> void:
	var stripe := ColorRect.new()
	stripe.name = stripe_name
	stripe.anchor_left = left
	stripe.anchor_top = top
	stripe.anchor_right = right
	stripe.anchor_bottom = bottom
	stripe.color = color
	stripe.rotation = rotation_amount
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)


func _add_top_bar() -> void:
	var top_bar := Panel.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.115
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		0,
		8
	))
	add_child(top_bar)

	var top_line := ColorRect.new()
	top_line.name = "TopBarLine"
	top_line.anchor_left = 0.0
	top_line.anchor_top = 0.108
	top_line.anchor_right = 1.0
	top_line.anchor_bottom = 0.112
	top_line.color = Color(0.25, 0.82, 1.0, 0.70)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)

	var gold_line := ColorRect.new()
	gold_line.name = "TopGoldLine"
	gold_line.anchor_left = 0.0
	gold_line.anchor_top = 0.112
	gold_line.anchor_right = 1.0
	gold_line.anchor_bottom = 0.116
	gold_line.color = Color(1.0, 0.78, 0.12, 0.38)
	gold_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gold_line)

	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "LOBBY"
	logo.anchor_left = 0.02
	logo.anchor_top = 0.0
	logo.anchor_right = 0.26
	logo.anchor_bottom = 0.082
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(logo, 54)
	add_child(logo)

	var subtitle := Label.new()
	subtitle.name = "LobbySubtitle"
	subtitle.text = "PIXELMANIA"
	subtitle.anchor_left = 0.026
	subtitle.anchor_top = 0.068
	subtitle.anchor_right = 0.22
	subtitle.anchor_bottom = 0.108
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(subtitle, 14)
	add_child(subtitle)

	var live_badge := Panel.new()
	live_badge.name = "LiveLobbyBadge"
	live_badge.anchor_left = 0.265
	live_badge.anchor_top = 0.028
	live_badge.anchor_right = 0.360
	live_badge.anchor_bottom = 0.086
	live_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.055, 0.250, 0.165, 0.78),
		Color(0.35, 1.0, 0.55, 0.72),
		2,
		12,
		5
	))
	add_child(live_badge)

	var badge_label := Label.new()
	badge_label.name = "LiveLobbyBadgeLabel"
	badge_label.text = "LIVE LOBBY"
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(badge_label, 15, Color(0.72, 1.0, 0.78, 1.0))
	live_badge.add_child(badge_label)

	var icons := HBoxContainer.new()
	icons.name = "TopIconButtons"
	icons.anchor_left = 0.40
	icons.anchor_top = 0.022
	icons.anchor_right = 0.77
	icons.anchor_bottom = 0.102
	icons.add_theme_constant_override("separation", 10)
	add_child(icons)

	var is_first_top_button := true

	for icon_text in ["▶", "⚙", "👤", "≡", "🤝"]:
		var b := _make_icon_button(icon_text)
		if is_first_top_button:
			b.text = "P"
			b.tooltip_text = "Switch profile"
			b.pressed.connect(_on_profile_switch_pressed)
			is_first_top_button = false
		icons.add_child(b)

	var lobby_label := Label.new()
	lobby_label.name = "LobbyLabel"
	lobby_label.text = "LOBBY  ⌂"
	lobby_label.anchor_left = 0.88
	lobby_label.anchor_top = 0.008
	lobby_label.anchor_right = 0.99
	lobby_label.anchor_bottom = 0.10
	lobby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lobby_label.add_theme_font_size_override("font_size", 38)
	lobby_label.add_theme_color_override("font_color", Color.WHITE)
	lobby_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	lobby_label.add_theme_constant_override("shadow_offset_x", 4)
	lobby_label.add_theme_constant_override("shadow_offset_y", 4)
	lobby_label.text = "ACTIVE"
	lobby_label.anchor_left = 0.84
	lobby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(lobby_label, 28, PixelUIStyle.GOLD_SOFT)
	add_child(lobby_label)


func _add_left_profile_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ProfilePanel"
	panel.anchor_left = 0.025
	panel.anchor_top = 0.185
	panel.anchor_right = 0.285
	panel.anchor_bottom = 0.58
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.020, 0.020, 0.048, 0.90),
		Color(0.20, 0.64, 0.95, 0.72),
		3,
		18,
		12
	))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var profile_card := PanelContainer.new()
	profile_card.name = "ProfileHero"
	profile_card.custom_minimum_size = Vector2(0, 96)
	profile_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.055, 0.185, 0.340, 0.86),
		Color(0.25, 0.88, 1.0, 0.80),
		3,
		14,
		7
	))
	box.add_child(profile_card)

	var profile_margin := MarginContainer.new()
	profile_margin.add_theme_constant_override("margin_left", 12)
	profile_margin.add_theme_constant_override("margin_right", 12)
	profile_margin.add_theme_constant_override("margin_top", 10)
	profile_margin.add_theme_constant_override("margin_bottom", 10)
	profile_card.add_child(profile_margin)

	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 12)
	profile_margin.add_child(profile_row)

	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(72, 72)
	avatar_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.12, 0.08, 0.02, 0.92),
		PixelUIStyle.GOLD_SOFT,
		3,
		12,
		5
	))
	profile_row.add_child(avatar_frame)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(64, 64)
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var avatar_texture = load(PLAYER_IDLE_TEXTURE)
	if avatar_texture != null:
		avatar.texture = avatar_texture
	avatar_frame.add_child(avatar)

	var name_stack := VBoxContainer.new()
	name_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_stack.add_theme_constant_override("separation", 2)
	profile_row.add_child(name_stack)

	username_label = Label.new()
	username_label.text = "Player"
	PixelUIStyle.apply_label_shadow(username_label, 30)
	name_stack.add_child(username_label)

	var ready_label := Label.new()
	ready_label.text = "READY TO EXPLORE"
	PixelUIStyle.apply_small_label(ready_label, 13)
	name_stack.add_child(ready_label)

	profile_level_label = Label.new()
	profile_level_label.text = "LEVEL 1  |  EXPLORER"
	profile_level_label.add_theme_font_size_override("font_size", 28)
	profile_level_label.add_theme_color_override("font_color", Color.WHITE)
	PixelUIStyle.apply_section_title(profile_level_label, 22)
	box.add_child(profile_level_label)

	box.add_child(_make_meter("0 / 300"))
	box.add_child(_make_currency_row("GM", "0", Color(0.12, 0.62, 1.0), "gems"))
	box.add_child(_make_currency_row("XP", "0", Color(1.0, 0.72, 0.04), "total_xp"))


func _make_meter(text: String) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(380, 30)
	holder.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.035, 0.030, 0.070, 0.95),
		Color(0.12, 0.22, 0.46, 0.90),
		2,
		14,
		4
	))

	var fill := ColorRect.new()
	fill.name = "MeterFill"
	fill.position = Vector2(4, 4)
	fill.size = Vector2(0, 22)
	fill.color = Color(0.15, 0.72, 1.0, 0.50)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	profile_xp_fill = fill

	var spark := ColorRect.new()
	spark.name = "MeterSpark"
	spark.position = Vector2(4, 4)
	spark.size = Vector2(26, 22)
	spark.color = Color(1.0, 0.86, 0.18, 0.52)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(spark)
	profile_xp_spark = spark

	var label := Label.new()
	label.name = "MeterLabel"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(label, 18, PixelUIStyle.TEXT_LIGHT)
	holder.add_child(label)
	profile_xp_label = label
	return holder


func _make_currency_row(icon_text: String, amount: String, color: Color, bind_to: String = "") -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(0, 54)
	holder.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.030, 0.055, 0.095, 0.72),
		Color(color.r, color.g, color.b, 0.42),
		2,
		12,
		4
	))

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 8)
	row_margin.add_theme_constant_override("margin_right", 8)
	row_margin.add_theme_constant_override("margin_top", 3)
	row_margin.add_theme_constant_override("margin_bottom", 3)
	holder.add_child(row_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_margin.add_child(row)

	var icon := Label.new()
	icon.text = icon_text
	icon.custom_minimum_size = Vector2(48, 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 34)
	icon.add_theme_color_override("font_color", color)
	row.add_child(icon)

	var amount_label := Label.new()
	amount_label.text = amount
	amount_label.custom_minimum_size = Vector2(160, 48)
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 30)
	amount_label.add_theme_color_override("font_color", Color.WHITE)
	amount_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	amount_label.add_theme_constant_override("shadow_offset_x", 3)
	amount_label.add_theme_constant_override("shadow_offset_y", 3)
	row.add_child(amount_label)
	if bind_to == "gems":
		profile_gems_label = amount_label
	elif bind_to == "total_xp":
		profile_total_xp_label = amount_label

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(54, 48)
	PixelUIStyle.apply_blue_button(plus, 30)
	row.add_child(plus)

	return holder


func _add_recent_worlds_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "RecentWorldsPanel"
	panel.anchor_left = 0.315
	panel.anchor_top = 0.18
	panel.anchor_right = 0.725
	panel.anchor_bottom = 0.76
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		20,
		14
	))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header_panel := PanelContainer.new()
	header_panel.name = "WorldListHeader"
	header_panel.custom_minimum_size = Vector2(0, 78)
	header_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.065, 0.145, 0.275, 0.86),
		Color(0.40, 0.94, 1.0, 0.58),
		2,
		15,
		5
	))
	box.add_child(header_panel)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 14)
	header_margin.add_theme_constant_override("margin_right", 14)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header_panel.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header_margin.add_child(header_row)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	header_row.add_child(title_stack)

	var title := Label.new()
	title.name = "RecentWorldsTitle"
	title.text = "ACTIVE WORLDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUIStyle.apply_label_shadow(title, 34)
	title_stack.add_child(title)
	recent_worlds_title = title

	var subtitle := Label.new()
	subtitle.name = "RecentWorldsSubtitle"
	subtitle.text = "SAVED WORLD DATA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUIStyle.apply_small_label(subtitle, 14)
	title_stack.add_child(subtitle)
	recent_worlds_subtitle = subtitle

	var header_chip := PanelContainer.new()
	header_chip.custom_minimum_size = Vector2(112, 42)
	header_chip.add_theme_stylebox_override("panel", PixelUIStyle.status_badge_style("good"))
	header_row.add_child(header_chip)

	var chip_label := Label.new()
	chip_label.text = "LIVE"
	chip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(chip_label, 18, Color(0.72, 1.0, 0.78, 1.0))
	header_chip.add_child(chip_label)
	recent_worlds_chip_label = chip_label

	recent_worlds_list = VBoxContainer.new()
	recent_worlds_list.name = "RecentWorldsList"
	recent_worlds_list.add_theme_constant_override("separation", 8)
	box.add_child(recent_worlds_list)

	_refresh_recent_worlds_panel()


func _refresh_recent_worlds_panel() -> void:
	if recent_worlds_list == null:
		return

	for child in recent_worlds_list.get_children():
		child.queue_free()

	_update_world_list_heading()
	var active_worlds := _get_visible_world_entries()

	if active_worlds.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No server-owned locked worlds in this feed yet." if world_list_mode == "owned" else "No recent or live worlds yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 100)
		PixelUIStyle.apply_label_shadow(empty_label, 20, PixelUIStyle.TEXT_SOFT)
		recent_worlds_list.add_child(empty_label)
		return

	var max_rows: int = min(MAX_ACTIVE_WORLD_ROWS, int(active_worlds.size()))

	for i in range(max_rows):
		var row := _make_active_world_button(active_worlds[i], i)
		recent_worlds_list.add_child(row)


func _update_world_list_heading() -> void:
	if recent_worlds_title != null:
		recent_worlds_title.text = "CURRENTLY OWNED WORLDS" if world_list_mode == "owned" else "ACTIVE WORLDS"
	if recent_worlds_subtitle != null:
		recent_worlds_subtitle.visible = world_list_mode == "owned"
		recent_worlds_subtitle.text = "LOCKED BY YOU" if world_list_mode == "owned" else ""
	if recent_worlds_chip_label != null:
		recent_worlds_chip_label.text = "LOCKED" if world_list_mode == "owned" else "LIVE"


func _get_visible_world_entries() -> Array:
	if world_list_mode == "owned":
		return _get_owned_locked_world_entries()

	return _get_active_world_entries()


func _make_active_world_button(entry: Dictionary, index: int) -> Button:
	var world_name: String = _normalize_world_name(str(entry.get("world_name", "")))
	var button := Button.new()
	button.name = "ActiveWorld_" + world_name
	button.custom_minimum_size = Vector2(0, 72)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE

	var selected := index == 0
	var is_start_hub := world_name == LOBBY_HUB_WORLD and world_list_mode == "active"
	var normal_color := PixelUIStyle.GLASS_SECTION
	var border_color := Color(0.45, 0.74, 1.0, 0.42)
	if is_start_hub:
		normal_color = Color(0.190, 0.135, 0.030, 0.93)
		border_color = Color(1.0, 0.78, 0.14, 0.86)
	elif selected:
		normal_color = Color(0.16, 0.35, 0.62, 0.78)
		border_color = Color(0.26, 0.74, 1.0, 0.52)

	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(normal_color, border_color, 2, 10, 4))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.18, 0.36, 0.50, 0.76), Color(0.86, 0.95, 1.0, 0.82), 2, 10, 6))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.08, 0.20, 0.30, 0.78), Color(0.18, 0.48, 0.86, 0.85), 2, 10, 3))
	button.pressed.connect(_on_recent_world_pressed.bind(world_name))

	var content := Control.new()
	content.name = "CardContent"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var accent := ColorRect.new()
	accent.name = "WorldAccent"
	accent.position = Vector2(0, 8)
	accent.size = Vector2(5, 56)
	accent.color = Color(1.0, 0.76, 0.12, 0.88) if is_start_hub else Color(0.23, 0.93, 1.0, 0.72)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent)

	var icon_back := Panel.new()
	icon_back.name = "WorldIconBack"
	icon_back.position = Vector2(10, 10)
	icon_back.size = Vector2(50, 50)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.34, 0.20, 0.02, 0.92) if is_start_hub else Color(0.025, 0.360, 0.430, 0.90),
		PixelUIStyle.GOLD_SOFT if is_start_hub else Color(0.14, 0.95, 1.0, 0.74),
		2,
		12,
		2
	))
	content.add_child(icon_back)

	var icon := Label.new()
	icon.name = "WorldIcon"
	icon.text = "H" if is_start_hub else "W"
	icon.position = Vector2.ZERO
	icon.size = icon_back.size
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(icon, 24, PixelUIStyle.TEXT_LIGHT)
	icon_back.add_child(icon)

	var name_label := Label.new()
	name_label.name = "WorldName"
	name_label.text = world_name
	name_label.position = Vector2(72, 8)
	name_label.size = Vector2(280, 26)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 22)
	content.add_child(name_label)

	if is_start_hub:
		var official := Label.new()
		official.name = "OfficialBadge"
		official.text = "OFFICIAL HUB"
		official.position = Vector2(272, 10)
		official.size = Vector2(118, 22)
		official.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		official.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		official.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(official, 12, PixelUIStyle.GOLD_SOFT)
		content.add_child(official)

	var meta_label := Label.new()
	meta_label.name = "WorldMeta"
	meta_label.text = _get_active_world_meta_text(entry)
	meta_label.position = Vector2(74, 36)
	meta_label.size = Vector2(390, 22)
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(meta_label, 13)
	content.add_child(meta_label)

	var status := Label.new()
	status.name = "PlayerCount"
	status.text = _get_player_count_label(world_name)
	var status_chip := Panel.new()
	status_chip.name = "PlayerCountChip"
	status_chip.position = Vector2(456, 8)
	status_chip.size = Vector2(112, 26)
	status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.025, 0.165, 0.205, 0.82),
		Color(0.22, 0.94, 1.0, 0.70),
		2,
		12,
		3
	))
	content.add_child(status_chip)
	status.position = Vector2.ZERO
	status.size = status_chip.size
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(status, 13, PixelUIStyle.ACCENT_CYAN)
	status_chip.add_child(status)

	var join_label := Label.new()
	join_label.name = "JoinLabel"
	join_label.text = "JOIN"
	join_label.position = Vector2(466, 37)
	join_label.size = Vector2(92, 26)
	join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(join_label, 18, Color(1.0, 0.95, 0.25, 1.0))
	content.add_child(join_label)

	return button


func _get_active_world_meta_text(entry: Dictionary) -> String:
	var world_name: String = _normalize_world_name(str(entry.get("world_name", "")))
	var source := str(entry.get("source_label", "SAVED"))
	var lock_text := "LOCKED" if bool(entry.get("is_locked", false)) else "OPEN"

	var owner := str(entry.get("owner_name", "")).strip_edges()
	if owner == "":
		owner = "none"

	if world_list_mode == "owned":
		return "OWNER | access " + str(int(entry.get("access_count", 0))) + " | " + _get_player_count_text(world_name)

	if not bool(entry.get("has_save", false)):
		return source + " | " + lock_text + " | " + _get_player_count_text(world_name)

	return source + " | owner " + owner + " | " + lock_text + " | " + _get_player_count_text(world_name)


func _get_player_count_label(world_name: String) -> String:
	var count: int = _get_world_player_count(world_name)

	if count < 0:
		return "LIVE"
	if count == 1:
		return "1 PLAYER"

	return str(count) + " PLAYERS"


func _get_player_count_text(world_name: String) -> String:
	var count: int = _get_world_player_count(world_name)

	if count < 0:
		return "players live"
	if count == 1:
		return "1 player"

	return str(count) + " players"


func _get_world_player_count(world_name: String) -> int:
	var clean_world: String = _normalize_world_name(world_name)

	if clean_world == "":
		return -1
	if world_population_cache.has(clean_world):
		return int(world_population_cache.get(clean_world, -1))

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_world_player_count"):
		return int(network.get_world_player_count(clean_world))

	return -1


func _get_active_world_entries() -> Array:
	var entries: Array = []
	var seen: Dictionary = {}
	var recent_names: Array = _get_recent_world_names()

	for i in range(recent_names.size()):
		var world_name: String = _normalize_world_name(str(recent_names[i]))

		if world_name == "":
			continue

		var source_label: String = "LAST" if i == 0 else "RECENT"
		var entry: Dictionary = _make_unsaved_world_entry(world_name, source_label, i)
		var key: String = _sanitize_world_file_name(world_name)

		if key == "":
			key = world_name.to_lower()

		seen[key] = true
		entries.append(entry)

	for live_world_name in world_population_cache.keys():
		var clean_live_world: String = _normalize_world_name(str(live_world_name))
		var live_key: String = _sanitize_world_file_name(clean_live_world)

		if clean_live_world == "":
			continue
		if live_key == "":
			live_key = clean_live_world.to_lower()
		if seen.has(live_key):
			continue
		if int(world_population_cache.get(clean_live_world, 0)) <= 0:
			continue

		seen[live_key] = true
		entries.append({
			"world_name": clean_live_world,
			"source_label": "LIVE",
			"has_save": false,
			"is_locked": false,
			"owner_name": "",
			"world_width": 0,
			"world_height": 0,
			"block_count": 0,
			"drop_count": 0,
			"seed_count": 0,
			"modified_time": Time.get_unix_time_from_system(),
			"sort_group": 50
		})

	_pin_start_world_entry(entries, seen)
	entries.sort_custom(_sort_active_world_entries)
	return entries


func _get_owned_locked_world_entries() -> Array:
	return []


func _pin_start_world_entry(entries: Array, seen: Dictionary) -> void:
	var start_key: String = _sanitize_world_file_name(LOBBY_HUB_WORLD)

	for entry in entries:
		if _normalize_world_name(str(entry.get("world_name", ""))) != LOBBY_HUB_WORLD:
			continue

		entry["source_label"] = "OFFICIAL"
		entry["sort_group"] = -100
		seen[start_key] = true
		return

	var start_entry := _make_unsaved_world_entry(LOBBY_HUB_WORLD, "OFFICIAL", -100)
	start_entry["modified_time"] = Time.get_unix_time_from_system()
	entries.append(start_entry)
	seen[start_key] = true


func _sort_active_world_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_world: String = _normalize_world_name(str(a.get("world_name", "")))
	var b_world: String = _normalize_world_name(str(b.get("world_name", "")))

	if a_world == LOBBY_HUB_WORLD and b_world != LOBBY_HUB_WORLD:
		return true
	if b_world == LOBBY_HUB_WORLD and a_world != LOBBY_HUB_WORLD:
		return false

	var a_group: int = int(a.get("sort_group", 100))
	var b_group: int = int(b.get("sort_group", 100))

	if a_group != b_group:
		return a_group < b_group

	var a_time: int = int(a.get("modified_time", 0))
	var b_time: int = int(b.get("modified_time", 0))

	if a_time != b_time:
		return a_time > b_time

	return str(a.get("world_name", "")) < str(b.get("world_name", ""))


func _make_unsaved_world_entry(world_name: String, source_label: String, sort_group: int) -> Dictionary:
	return {
		"world_name": _normalize_world_name(world_name),
		"source_label": source_label,
		"has_save": false,
		"is_locked": false,
		"owner_name": "",
		"access_count": 0,
		"lock_grid_x": 999999,
		"lock_grid_y": 999999,
		"public_build": false,
		"world_width": 0,
		"world_height": 0,
		"block_count": 0,
		"drop_count": 0,
		"seed_count": 0,
		"modified_time": 0,
		"sort_group": sort_group
	}


func _sanitize_world_file_name(raw_name: String) -> String:
	var clean := raw_name.strip_edges().to_lower()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""

	for i in range(clean.length()):
		var character := clean.substr(i, 1)

		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	return result


func _make_recent_world_button(world_name: String, index: int) -> Button:
	var button := Button.new()
	button.name = "RecentWorld_" + world_name
	button.custom_minimum_size = Vector2(0, 66)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE

	var normal_color: Color = PixelUIStyle.GLASS_SECTION
	var border_color: Color = PixelUIStyle.GLASS_BORDER

	if index == 0:
		normal_color = Color(0.14, 0.50, 0.82, 0.98)
		border_color = Color(0.02, 0.12, 0.42, 1.0)

	button.add_theme_stylebox_override("normal", _style_box(normal_color, border_color, 4, 14))
	button.add_theme_stylebox_override("hover", _style_box(normal_color.lightened(0.08), border_color, 4, 14))
	button.add_theme_stylebox_override("pressed", _style_box(normal_color.darkened(0.10), border_color, 4, 14))
	button.pressed.connect(_on_recent_world_pressed.bind(world_name))

	var content := Control.new()
	content.name = "CardContent"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var icon := Label.new()
	icon.name = "WorldIcon"
	icon.text = "🌎"
	icon.position = Vector2(12, 10)
	icon.size = Vector2(46, 46)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var name_label := Label.new()
	name_label.name = "WorldName"
	name_label.text = world_name
	name_label.position = Vector2(64, 7)
	name_label.size = Vector2(280, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var meta_label := Label.new()
	meta_label.name = "WorldMeta"
	meta_label.text = _get_recent_world_meta_text(world_name, index)
	meta_label.position = Vector2(66, 35)
	meta_label.size = Vector2(340, 22)
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_label.add_theme_font_size_override("font_size", 14)
	meta_label.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0, 1.0))
	meta_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	meta_label.add_theme_constant_override("shadow_offset_x", 1)
	meta_label.add_theme_constant_override("shadow_offset_y", 1)
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(meta_label)

	var lock_label := Label.new()
	lock_label.name = "LockStatus"
	lock_label.text = "🔓"
	lock_label.position = Vector2(398, 13)
	lock_label.size = Vector2(34, 34)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.add_theme_font_size_override("font_size", 22)
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(lock_label)

	var join_label := Label.new()
	join_label.name = "JoinLabel"
	join_label.text = "JOIN"
	join_label.position = Vector2(438, 10)
	join_label.size = Vector2(88, 44)
	join_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join_label.add_theme_font_size_override("font_size", 22)
	join_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.25, 1.0))
	join_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	join_label.add_theme_constant_override("shadow_offset_x", 2)
	join_label.add_theme_constant_override("shadow_offset_y", 2)
	join_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(join_label)

	return button


func _get_recent_world_meta_text(world_name: String, index: int) -> String:
	var player_count: int = 1 + ((world_name.length() + index * 3) % 24)
	var activity_text: String = "Recently visited"

	if index == 0:
		activity_text = "Last world"

	return activity_text + "  •  " + str(player_count) + " online"


func _on_recent_world_pressed(world_name: String) -> void:
	var clean_name: String = _normalize_world_name(world_name)

	if world_input != null:
		world_input.text = clean_name

	_on_join_pressed()


func _get_recent_world_names() -> Array:
	var cfg = ConfigFile.new()
	cfg.load(PROFILE_PATH)

	var raw_recent = cfg.get_value("profile", "recent_worlds", [])
	var last_world: String = _normalize_world_name(str(cfg.get_value("profile", "last_world", "")))
	var results: Array = []

	if last_world != "":
		results.append(last_world)

	if raw_recent is Array:
		for value in raw_recent:
			var clean_name: String = _normalize_world_name(str(value))

			if clean_name == "":
				continue

			if not results.has(clean_name):
				results.append(clean_name)

	return results


func _save_recent_world_name(world_name: String) -> void:
	var clean_name: String = _normalize_world_name(world_name)

	if clean_name == "":
		return

	var cfg = ConfigFile.new()
	cfg.load(PROFILE_PATH)

	var old_recent = cfg.get_value("profile", "recent_worlds", [])
	var new_recent: Array = [clean_name]

	if old_recent is Array:
		for value in old_recent:
			var old_name: String = _normalize_world_name(str(value))

			if old_name == "":
				continue

			if old_name == clean_name:
				continue

			if not new_recent.has(old_name):
				new_recent.append(old_name)

			if new_recent.size() >= 8:
				break

	cfg.set_value("profile", "recent_worlds", new_recent)
	cfg.save(PROFILE_PATH)


func _normalize_world_name(world_name: String) -> String:
	var clean = world_name.strip_edges().to_lower()
	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""
	for i in range(clean.length()):
		var character = clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	return result.to_upper()


func _normalize_profile_name(profile_name: String) -> String:
	return profile_name.strip_edges().to_upper()


func _sanitize_player_name_for_path(raw_name: String) -> String:
	var clean = raw_name.strip_edges().to_lower()
	if clean == "":
		clean = "guest"

	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""
	for i in range(clean.length()):
		var character = clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	return result if result != "" else "guest"


func _load_profile_progression_data(profile_name: String) -> Dictionary:
	var save_path = PLAYER_SAVE_FOLDER + _sanitize_player_name_for_path(profile_name) + ".json"
	if not FileAccess.file_exists(save_path):
		return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}

	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var nested = data.get("player_data", null)
		if nested is Dictionary:
			return nested
		return data

	return {}


func _get_xp_needed_for_level(level: int) -> int:
	var safe_level = clamp(level, 1, PLAYER_MAX_LEVEL)
	if safe_level >= PLAYER_MAX_LEVEL:
		return 0

	var level_index = safe_level - 1
	return 300 + (level_index * 120) + int(floor(pow(float(level_index), 1.6) * 42.0))


func _get_profile_title(level: int) -> String:
	if level >= 100:
		return "PIXEL LEGEND"
	if level >= 80:
		return "WORLDSMITH"
	if level >= 60:
		return "ARCHITECT"
	if level >= 40:
		return "TRAILBLAZER"
	if level >= 25:
		return "CRAFTER"
	if level >= 10:
		return "BUILDER"
	return "EXPLORER"


func _format_lobby_amount(value: int) -> String:
	var text = str(max(0, value))
	var result = ""
	var count = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text.substr(i, 1) + result
		count += 1
	return result


func _refresh_profile_progression() -> void:
	var profile_name = _get_current_profile_name()
	var data = _load_profile_progression_data(profile_name)
	var level: int = clamp(int(data.get("player_level", data.get("level", 1))), 1, PLAYER_MAX_LEVEL)
	var xp: int = max(0, int(data.get("player_xp", data.get("xp", 0))))
	var xp_needed: int = max(0, int(data.get("player_xp_needed", data.get("xp_needed", _get_xp_needed_for_level(level)))))
	var total_xp: int = max(0, int(data.get("player_total_xp", data.get("total_xp", 0))))
	var title = str(data.get("player_title", _get_profile_title(level))).strip_edges().to_upper()
	if title == "":
		title = _get_profile_title(level)

	if profile_level_label != null:
		profile_level_label.text = "LEVEL " + str(level) + "  |  " + title

	if profile_xp_label != null:
		profile_xp_label.text = "MAX" if xp_needed <= 0 else str(xp) + " / " + str(xp_needed)

	var ratio = 1.0 if xp_needed <= 0 else clamp(float(xp) / float(max(1, xp_needed)), 0.0, 1.0)
	if profile_xp_fill != null:
		profile_xp_fill.size = Vector2(round(372.0 * ratio), profile_xp_fill.size.y)
	if profile_xp_spark != null:
		profile_xp_spark.visible = ratio > 0.0
		profile_xp_spark.position = Vector2(4.0 + max(0.0, round(372.0 * ratio) - 13.0), profile_xp_spark.position.y)

	var currency = data.get("currency_inventory", {})
	var gems = 0
	if currency is Dictionary:
		gems = max(0, int(currency.get("gem", 0)))
	if profile_gems_label != null:
		profile_gems_label.text = _format_lobby_amount(gems)
	if profile_total_xp_label != null:
		profile_total_xp_label.text = _format_lobby_amount(total_xp)


func _get_current_profile_name() -> String:
	var session_username: String = _get_network_session_username()

	if session_username != "":
		return session_username

	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		var profile_name: String = str(cfg.get_value("profile", "username", "")).strip_edges()
		if profile_name != "":
			return profile_name

	if username_label != null:
		return username_label.text.strip_edges()

	return ""


func _add_world_join_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "WorldJoinPanel"
	panel.anchor_left = 0.67
	panel.anchor_top = 0.795
	panel.anchor_right = 0.985
	panel.anchor_bottom = 0.935
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.025, 0.018, 0.045, 0.92),
		Color(0.32, 0.80, 1.0, 0.78),
		3,
		18,
		13
	))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 8)
	margin.add_child(main_row)

	var left_stack := VBoxContainer.new()
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.add_theme_constant_override("separation", 6)
	main_row.add_child(left_stack)

	var active_button := Button.new()
	active_button.name = "ActiveWorldsButton"
	active_button.text = "ACTIVE WORLDS  👥"
	active_button.custom_minimum_size = Vector2(0, 38)
	active_button.focus_mode = Control.FOCUS_NONE
	active_button.add_theme_font_size_override("font_size", 18)
	active_button.add_theme_color_override("font_color", Color.WHITE)
	active_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	active_button.add_theme_constant_override("shadow_offset_x", 2)
	active_button.add_theme_constant_override("shadow_offset_y", 2)
	active_button.add_theme_stylebox_override("normal", _style_box(Color(0.15, 0.55, 0.90, 0.98), Color(0.02, 0.12, 0.42, 1.0), 4, 12))
	active_button.add_theme_stylebox_override("hover", _style_box(Color(0.20, 0.64, 1.0, 0.98), Color(0.02, 0.12, 0.42, 1.0), 4, 12))
	active_button.add_theme_stylebox_override("pressed", _style_box(Color(0.10, 0.42, 0.74, 0.98), Color(0.02, 0.12, 0.42, 1.0), 4, 12))
	PixelUIStyle.apply_blue_button(active_button, 17)
	active_button.text = "ACTIVE WORLDS"
	active_button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(
		Color(0.10, 0.46, 0.86, 0.98),
		Color(0.36, 0.92, 1.0, 0.90),
		4,
		12,
		7
	))
	active_button.pressed.connect(_on_active_worlds_pressed)
	left_stack.add_child(active_button)
	active_worlds_button = active_button

	var input_card := PanelContainer.new()
	input_card.name = "WorldInputCard"
	input_card.custom_minimum_size = Vector2(0, 58)
	input_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		2,
		12,
		5
	))
	left_stack.add_child(input_card)

	var input_margin := MarginContainer.new()
	input_margin.add_theme_constant_override("margin_left", 10)
	input_margin.add_theme_constant_override("margin_right", 10)
	input_margin.add_theme_constant_override("margin_top", 6)
	input_margin.add_theme_constant_override("margin_bottom", 6)
	input_card.add_child(input_margin)

	var input_stack := VBoxContainer.new()
	input_stack.add_theme_constant_override("separation", 2)
	input_margin.add_child(input_stack)

	var input_label := Label.new()
	input_label.name = "WorldInputLabel"
	input_label.text = "ENTER WORLD NAME"
	input_label.add_theme_font_size_override("font_size", 12)
	input_label.add_theme_color_override("font_color", Color(0.78, 0.93, 1.0, 1.0))
	input_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	input_label.add_theme_constant_override("shadow_offset_x", 1)
	input_label.add_theme_constant_override("shadow_offset_y", 1)
	PixelUIStyle.apply_small_label(input_label, 12)
	input_stack.add_child(input_label)

	world_input = LineEdit.new()
	world_input.name = "WorldInput"
	world_input.placeholder_text = "Type world name..."
	world_input.custom_minimum_size = Vector2(0, 32)
	world_input.add_theme_font_size_override("font_size", 20)
	world_input.add_theme_stylebox_override("normal", _style_box(Color(0.96, 0.98, 1.0, 1.0), Color(0.01, 0.04, 0.08), 4, 8))
	world_input.add_theme_stylebox_override("focus", _style_box(Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.86, 0.20, 1.0), 4, 8))
	world_input.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10, 1.0))
	world_input.add_theme_color_override("font_placeholder_color", Color(0.05, 0.08, 0.12, 0.45))
	world_input.add_theme_font_size_override("font_size", 20)
	PixelUIStyle.apply_input(world_input, 20)
	world_input.text_submitted.connect(_on_world_text_submitted)
	input_stack.add_child(world_input)

	var join := Button.new()
	join.name = "JoinButton"
	join.text = "JOIN"
	join.custom_minimum_size = Vector2(96, 94)
	join.focus_mode = Control.FOCUS_NONE
	join.add_theme_font_size_override("font_size", 22)
	join.add_theme_color_override("font_color", Color.WHITE)
	join.add_theme_color_override("font_shadow_color", Color.BLACK)
	join.add_theme_constant_override("shadow_offset_x", 3)
	join.add_theme_constant_override("shadow_offset_y", 3)
	join.add_theme_stylebox_override("normal", _style_box(Color(1.0, 0.84, 0.05, 1.0), Color(0.96, 0.50, 0.02, 1.0), 5, 14))
	join.add_theme_stylebox_override("hover", _style_box(Color(1.0, 0.94, 0.20, 1.0), Color(0.96, 0.50, 0.02, 1.0), 5, 14))
	join.add_theme_stylebox_override("pressed", _style_box(Color(0.90, 0.58, 0.02, 1.0), Color(0.60, 0.28, 0.01, 1.0), 5, 14))
	PixelUIStyle.apply_yellow_button(join, 22)
	join.add_theme_stylebox_override("normal", PixelUIStyle.style_box(
		Color(1.0, 0.82, 0.04, 1.0),
		Color(1.0, 0.38, 0.04, 1.0),
		5,
		16,
		9
	))
	join.add_theme_stylebox_override("hover", PixelUIStyle.style_box(
		Color(1.0, 0.94, 0.16, 1.0),
		Color(1.0, 0.55, 0.05, 1.0),
		5,
		16,
		10
	))
	join.pressed.connect(_on_join_pressed)
	main_row.add_child(join)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.anchor_left = 0.67
	status_label.anchor_top = 0.760
	status_label.anchor_right = 0.98
	status_label.anchor_bottom = 0.792
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(status_label)


func _add_right_buttons() -> void:
	var side := VBoxContainer.new()
	side.name = "RightSideButtons"
	side.anchor_left = 0.92
	side.anchor_top = 0.14
	side.anchor_right = 0.985
	side.anchor_bottom = 0.70
	side.add_theme_constant_override("separation", 22)
	add_child(side)

	for txt in ["♕", "★", "🔒", "🪐"]:
		var b := _make_round_button(txt)
		side.add_child(b)

	_wire_right_side_buttons(side)


func _wire_right_side_buttons(side: VBoxContainer) -> void:
	if side == null:
		return

	for i in range(side.get_child_count()):
		var button = side.get_child(i)

		if not (button is Button):
			continue

		if i == 2:
			button.tooltip_text = "Show owned locked worlds"
			if not button.pressed.is_connected(_on_lock_worlds_pressed):
				button.pressed.connect(_on_lock_worlds_pressed)
		elif i == 3:
			button.tooltip_text = "Go to START"
			if not button.pressed.is_connected(_on_start_world_pressed):
				button.pressed.connect(_on_start_world_pressed)


func _make_icon_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(88, 88)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_stylebox_override("normal", _style_box(Color(0.37, 0.72, 1.0), Color(0.04, 0.15, 0.50), 5, 16))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.50, 0.80, 1.0), Color(0.04, 0.15, 0.50), 5, 16))
	PixelUIStyle.apply_button_text(b, 34)
	b.add_theme_stylebox_override("normal", PixelUIStyle.style_box(
		Color(0.030, 0.065, 0.125, 0.94),
		Color(0.22, 0.78, 1.0, 0.90),
		3,
		18,
		8
	))
	b.add_theme_stylebox_override("hover", PixelUIStyle.style_box(
		Color(0.100, 0.200, 0.330, 0.98),
		PixelUIStyle.GOLD_SOFT,
		3,
		18,
		10
	))
	b.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(
		Color(0.015, 0.032, 0.060, 0.98),
		PixelUIStyle.GOLD_SOFT,
		3,
		18,
		5
	))
	return b


func _make_round_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(104, 104)
	b.add_theme_font_size_override("font_size", 42)
	b.add_theme_stylebox_override("normal", _style_box(Color(0.35, 0.72, 1.0), Color(0.05, 0.13, 0.62), 6, 52))
	b.add_theme_stylebox_override("hover", _style_box(Color(0.48, 0.82, 1.0), Color(0.05, 0.13, 0.62), 6, 52))
	PixelUIStyle.apply_button_text(b, 42)
	b.add_theme_stylebox_override("normal", PixelUIStyle.style_box(
		Color(0.025, 0.055, 0.110, 0.94),
		Color(0.20, 0.72, 1.0, 0.88),
		3,
		52,
		10
	))
	b.add_theme_stylebox_override("hover", PixelUIStyle.style_box(
		Color(0.090, 0.205, 0.335, 0.98),
		PixelUIStyle.GOLD_SOFT,
		3,
		52,
		12
	))
	b.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(
		Color(0.015, 0.032, 0.060, 0.98),
		PixelUIStyle.GOLD_SOFT,
		3,
		52,
		5
	))
	return b


func _style_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 5)
	return style


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PROFILE_PATH)
	var session_username := _get_network_session_username()

	if err == OK:
		var username := session_username
		if username == "":
			username = str(cfg.get_value("profile", "username", "Player"))

		username_label.text = username
		world_input.text = str(cfg.get_value("profile", "last_world", ""))
	elif session_username != "":
		username_label.text = session_username

	_refresh_profile_progression()
	_refresh_recent_worlds_panel()


func _connect_world_population_feed() -> void:
	var network = get_node_or_null("/root/NetworkManager")

	if network == null:
		return

	if network.has_method("get_world_population_counts"):
		_apply_world_population_counts(network.get_world_population_counts(), false)

	var callback := Callable(self, "_on_world_population_changed")
	if network.has_signal("world_population_changed") and not network.is_connected("world_population_changed", callback):
		network.connect("world_population_changed", callback)


func _start_world_population_timer() -> void:
	if world_population_timer != null:
		return

	world_population_timer = Timer.new()
	world_population_timer.name = "WorldPopulationRefreshTimer"
	world_population_timer.wait_time = WORLD_POPULATION_REFRESH_SECONDS
	world_population_timer.autostart = true
	world_population_timer.timeout.connect(_request_world_population_refresh)
	add_child(world_population_timer)


func _request_world_population_refresh() -> void:
	var network = get_node_or_null("/root/NetworkManager")

	if network == null:
		return
	if network.has_method("get_world_population_counts"):
		_apply_world_population_counts(network.get_world_population_counts(), false)
	if not network.has_method("request_world_population"):
		return

	network.request_world_population(_get_known_world_names_for_population_request())


func _get_known_world_names_for_population_request() -> Array:
	var names: Array = [LOBBY_HUB_WORLD]
	var entries: Array = _get_visible_world_entries()

	for entry in entries:
		if not (entry is Dictionary):
			continue

		var world_name: String = _normalize_world_name(str(entry.get("world_name", "")))
		if world_name == "":
			continue
		if names.has(world_name):
			continue

		names.append(world_name)

	return names


func _on_world_population_changed(world_counts: Dictionary) -> void:
	_apply_world_population_counts(world_counts, true)


func _apply_world_population_counts(world_counts: Dictionary, refresh: bool) -> void:
	var changed := false

	for world_name in world_counts.keys():
		var clean_world: String = _normalize_world_name(str(world_name))

		if clean_world == "":
			continue

		var count: int = max(0, int(world_counts.get(world_name, 0)))

		if int(world_population_cache.get(clean_world, -1)) != count:
			world_population_cache[clean_world] = count
			changed = true

	if refresh and changed:
		_refresh_recent_worlds_panel()


func _start_lobby_idle_animation() -> void:
	_pulse_node_alpha("CyanEnergyStripe", 0.45, 1.0, 1.35)
	_pulse_node_alpha("GoldEnergyStripe", 0.40, 1.0, 1.75)
	_pulse_node_alpha("HorizonGlow", 0.65, 1.0, 2.20)

	for i in range(9):
		_pulse_node_alpha("PixelGlint" + str(i), 0.25, 1.0, 0.90 + float(i % 4) * 0.18)

	var join_button = find_child("JoinButton", true, false)
	if join_button != null and join_button is Control:
		join_button.pivot_offset = join_button.size * 0.5
		var join_tween := create_tween()
		join_tween.set_loops()
		join_tween.tween_property(join_button, "scale", Vector2(1.025, 1.025), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		join_tween.tween_property(join_button, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse_node_alpha(node_name: String, low_alpha: float, high_alpha: float, duration: float) -> void:
	var node := get_node_or_null(node_name)

	if node == null:
		return

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", low_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", high_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_world_text_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_active_worlds_pressed() -> void:
	world_list_mode = "active"
	_refresh_recent_worlds_panel()
	_request_world_population_refresh()


func _on_lock_worlds_pressed() -> void:
	world_list_mode = "owned"
	_refresh_recent_worlds_panel()
	_request_world_population_refresh()


func _on_start_world_pressed() -> void:
	_join_world_name(LOBBY_HUB_WORLD)


func _on_join_pressed() -> void:
	_join_world_name(world_input.text)


func _join_world_name(raw_world_name: String) -> void:
	var world_name: String = _normalize_world_name(raw_world_name)

	if world_name.is_empty():
		status_label.text = "Enter a world name first."
		return

	world_input.text = world_name
	_save_recent_world_name(world_name)

	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)

	var profile_name := _get_network_session_username()
	if profile_name == "":
		profile_name = str(cfg.get_value("profile", "username", "")).strip_edges()
	if profile_name == "" and username_label != null:
		profile_name = username_label.text.strip_edges()

	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("set_pending_join"):
		network.set_pending_join(world_name, profile_name)

	cfg.set_value("profile", "last_world", world_name)
	cfg.set_value("pending_join", "enabled", true)
	cfg.set_value("pending_join", "world_name", world_name)
	cfg.set_value("pending_join", "profile_name", profile_name)
	cfg.save(PROFILE_PATH)

	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_profile_switch_pressed() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("clear_active_session"):
		network.clear_active_session()

	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(PROFILE_PATH)

	get_tree().change_scene_to_file(LOGIN_SCENE)


func _get_network_session_username() -> String:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_active_session_username"):
		return str(network.get_active_session_username()).strip_edges()

	return ""
