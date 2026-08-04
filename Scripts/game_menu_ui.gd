extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const GAME_MENU_W := 460.0
const GAME_MENU_H := 560.0
const GAME_MENU_HEADER_H := 92.0
const GAME_MENU_ROW_H := 54.0
const GAME_MENU_ROW_GAP := 14.0
const MENU_ICON_PATH := "res://Assets/ui/icons/menu.png"
const MENU_BUTTON_SIZE := Vector2(64, 64)
const RESPAWN_ICON_PATH := "res://Assets/ui/icons/respawn.png"
const RESPAWN_BUTTON_SIZE := Vector2(64, 64)
const LOBBY_ICON_PATH := "res://Assets/ui/icons/lobby.png"
const PLAYER_INFO_ICON_PATH := "res://Assets/ui/icons/player_info.png"
const FRIENDS_ICON_PATH := "res://Assets/ui/icons/friends.png"
const SETTINGS_ICON_PATH := "res://Assets/ui/icons/settings.png"

var world = null
var ui_layer_ref = null

var menu_button = null
var menu_icon = null
var menu_icon_shadow = null
var menu_button_tween = null
var menu_button_hovered := false
var respawn_button = null
var respawn_button_icon = null
var respawn_button_icon_shadow = null
var respawn_button_tween = null
var respawn_button_hovered := false
var player_info_button = null
var player_info_button_icon = null
var friends_button = null
var friends_button_icon = null
var settings_button = null
var settings_button_icon = null
var lobby_button = null
var lobby_button_icon = null
var overlay = null
var panel = null
var is_open_flag := false


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 190

	setup_menu_button()
	build_overlay()
	close_menu()


func _process(_delta):
	update_menu_button_position()
	update_overlay_position()
	update_menu_button_visibility()


func get_hud_layer() -> Node:
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			return hud_layer

	return ui_layer_ref


func setup_menu_button():
	if ui_layer_ref == null:
		return
	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return

	menu_button = hud_layer.get_node_or_null("GameMenuButton")
	if menu_button == null and hud_layer != ui_layer_ref:
		menu_button = ui_layer_ref.get_node_or_null("GameMenuButton")
	if menu_button == null:
		menu_button = Button.new()
		menu_button.name = "GameMenuButton"
		hud_layer.add_child(menu_button)
	elif menu_button.get_parent() != hud_layer:
		var old_parent = menu_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(menu_button)
		hud_layer.add_child(menu_button)

	menu_button.text = ""
	menu_button.size = MENU_BUTTON_SIZE
	menu_button.z_index = 186
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_menu_icon_button_style(menu_button)
	setup_menu_button_icon()

	if not menu_button.pressed.is_connected(toggle_menu):
		menu_button.pressed.connect(toggle_menu)
	if not menu_button.mouse_entered.is_connected(_on_menu_button_mouse_entered):
		menu_button.mouse_entered.connect(_on_menu_button_mouse_entered)
	if not menu_button.mouse_exited.is_connected(_on_menu_button_mouse_exited):
		menu_button.mouse_exited.connect(_on_menu_button_mouse_exited)
	if not menu_button.button_down.is_connected(_on_menu_button_down):
		menu_button.button_down.connect(_on_menu_button_down)
	if not menu_button.button_up.is_connected(_on_menu_button_up):
		menu_button.button_up.connect(_on_menu_button_up)

	update_menu_button_position()


func setup_menu_button_icon():
	if menu_button == null:
		return

	for child in menu_button.get_children():
		child.queue_free()

	if not ResourceLoader.exists(MENU_ICON_PATH):
		menu_button.text = "MENU"
		menu_button.size = Vector2(108, 42)
		return

	var icon_texture: Texture2D = load(MENU_ICON_PATH) as Texture2D
	if icon_texture == null:
		menu_button.text = "MENU"
		menu_button.size = Vector2(108, 42)
		return

	menu_icon_shadow = TextureRect.new()
	menu_icon_shadow.name = "MenuIconShadow"
	menu_icon_shadow.texture = icon_texture
	menu_icon_shadow.position = Vector2(5, 7)
	menu_icon_shadow.size = MENU_BUTTON_SIZE
	menu_icon_shadow.pivot_offset = MENU_BUTTON_SIZE * 0.5
	menu_icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	menu_button.add_child(menu_icon_shadow)

	menu_icon = TextureRect.new()
	menu_icon.name = "MenuIcon"
	menu_icon.texture = icon_texture
	menu_icon.position = Vector2.ZERO
	menu_icon.size = MENU_BUTTON_SIZE
	menu_icon.pivot_offset = MENU_BUTTON_SIZE * 0.5
	menu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	menu_button.add_child(menu_icon)


func apply_menu_icon_button_style(button: Button):
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_menu_button_mouse_entered():
	menu_button_hovered = true
	animate_menu_button_icon(false)


func _on_menu_button_mouse_exited():
	menu_button_hovered = false
	animate_menu_button_icon(false)


func _on_menu_button_down():
	animate_menu_button_icon(true)


func _on_menu_button_up():
	animate_menu_button_icon(false)


func animate_menu_button_icon(pressed: bool):
	if menu_icon == null or menu_icon_shadow == null:
		return

	if menu_button_tween != null:
		menu_button_tween.kill()

	var icon_position := Vector2.ZERO
	var shadow_position := Vector2(5, 7)
	var icon_scale := Vector2.ONE
	var shadow_alpha := 0.38
	var icon_alpha := 0.96

	if menu_button_hovered:
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

	menu_button_tween = create_tween()
	menu_button_tween.set_parallel(true)
	menu_button_tween.tween_property(menu_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_button_tween.tween_property(menu_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_button_tween.tween_property(menu_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_button_tween.tween_property(menu_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_button_tween.tween_property(menu_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_button_tween.tween_property(menu_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func build_overlay():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "GameMenuOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.50)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(overlay)

	panel = Control.new()
	panel.name = "GameMenuPanel"
	panel.size = Vector2(GAME_MENU_W, GAME_MENU_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	overlay.add_child(panel)

	var far_shadow = Panel.new()
	far_shadow.name = "FarShadow"
	far_shadow.position = Vector2(15, 18)
	far_shadow.size = panel.size
	far_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.24),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		24,
		0
	))
	panel.add_child(far_shadow)

	var near_shadow = Panel.new()
	near_shadow.name = "NearShadow"
	near_shadow.position = Vector2(7, 8)
	near_shadow.size = panel.size
	near_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.38),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		22,
		0
	))
	panel.add_child(near_shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4,
		22,
		12
	))
	panel.add_child(panel_back)

	var outer_highlight = Panel.new()
	outer_highlight.name = "OuterHighlight"
	outer_highlight.position = Vector2(6, 6)
	outer_highlight.size = panel.size - Vector2(12, 12)
	outer_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_highlight.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.36, 0.74, 1.0, 0.22),
		1,
		17,
		0
	))
	panel.add_child(outer_highlight)

	var header = Panel.new()
	header.name = "Header"
	header.position = Vector2(8, 8)
	header.size = Vector2(GAME_MENU_W - 16, GAME_MENU_HEADER_H - 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		3,
		16,
		7
	))
	panel.add_child(header)

	var header_gloss = ColorRect.new()
	header_gloss.name = "HeaderGloss"
	header_gloss.position = Vector2(18, 18)
	header_gloss.size = Vector2(GAME_MENU_W - 36, 18)
	header_gloss.color = Color(0.80, 0.94, 1.0, 0.08)
	header_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_gloss)

	var header_spark = ColorRect.new()
	header_spark.name = "HeaderSpark"
	header_spark.position = Vector2(22, 17)
	header_spark.size = Vector2(GAME_MENU_W - 44, 2)
	header_spark.color = Color(0.80, 0.96, 1.0, 0.32)
	header_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_spark)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(12, GAME_MENU_HEADER_H - 6.0)
	top_line.size = Vector2(GAME_MENU_W - 24, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "MENU"
	title.position = Vector2(36, 14)
	title.size = Vector2(260, 52)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 48)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "GAME OPTIONS"
	subtitle.position = Vector2(42, 67)
	subtitle.size = Vector2(220, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 14)
	panel.add_child(subtitle)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(GAME_MENU_W - 86, 20)
	close_button.size = Vector2(54, 50)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_menu)
	panel.add_child(close_button)

	var body_shadow = Panel.new()
	body_shadow.name = "BodyShadow"
	body_shadow.position = Vector2(42, 118)
	body_shadow.size = Vector2(GAME_MENU_W - 84, 360)
	body_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.22),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		16,
		0
	))
	panel.add_child(body_shadow)

	var body_back = Panel.new()
	body_back.name = "BodyBack"
	body_back.position = Vector2(34, 110)
	body_back.size = Vector2(GAME_MENU_W - 68, 366)
	body_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		14,
		8
	))
	panel.add_child(body_back)

	var body_gloss = ColorRect.new()
	body_gloss.name = "BodyGloss"
	body_gloss.position = Vector2(48, 124)
	body_gloss.size = Vector2(GAME_MENU_W - 96, 18)
	body_gloss.color = Color(0.70, 0.92, 1.0, 0.07)
	body_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body_gloss)

	var body_floor = ColorRect.new()
	body_floor.name = "BodyFloorShade"
	body_floor.position = Vector2(50, 462)
	body_floor.size = Vector2(GAME_MENU_W - 100, 4)
	body_floor.color = Color(0.0, 0.0, 0.0, 0.22)
	body_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body_floor)

	var button_y = 132.0
	var gap = GAME_MENU_ROW_GAP
	player_info_button = make_player_info_button(Vector2(58, button_y))
	panel.add_child(player_info_button)
	button_y += GAME_MENU_ROW_H + gap
	friends_button = make_friends_button(Vector2(58, button_y))
	panel.add_child(friends_button)
	button_y += GAME_MENU_ROW_H + gap
	respawn_button = make_respawn_button(Vector2(58, button_y))
	panel.add_child(respawn_button)
	button_y += GAME_MENU_ROW_H + gap
	settings_button = make_settings_button(Vector2(58, button_y))
	panel.add_child(settings_button)
	button_y += GAME_MENU_ROW_H + gap
	lobby_button = make_lobby_button(Vector2(58, button_y))
	panel.add_child(lobby_button)

	var back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "BACK"
	back_button.position = Vector2(58, panel.size.y - 68)
	back_button.size = Vector2(GAME_MENU_W - 116, 48)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(back_button, true, false, 18)
	decorate_game_menu_button(back_button, true)
	back_button.pressed.connect(close_menu)
	panel.add_child(back_button)

	update_overlay_position()


func decorate_game_menu_button(button: Button, selected: bool = false) -> void:
	if button == null:
		return

	var top_gloss = ColorRect.new()
	top_gloss.name = "ButtonGloss"
	top_gloss.position = Vector2(12, 7)
	top_gloss.size = Vector2(max(1.0, button.size.x - 24.0), 2)
	top_gloss.color = Color(1.0, 1.0, 1.0, 0.26 if selected else 0.12)
	top_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(top_gloss)

	var upper_wash = ColorRect.new()
	upper_wash.name = "ButtonUpperWash"
	upper_wash.position = Vector2(10, 10)
	upper_wash.size = Vector2(max(1.0, button.size.x - 20.0), 10)
	upper_wash.color = Color(1.0, 0.96, 0.42, 0.08) if selected else Color(0.62, 0.90, 1.0, 0.045)
	upper_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(upper_wash)

	var bottom_shade = ColorRect.new()
	bottom_shade.name = "ButtonBottomShade"
	bottom_shade.position = Vector2(12, button.size.y - 8.0)
	bottom_shade.size = Vector2(max(1.0, button.size.x - 24.0), 3)
	bottom_shade.color = Color(0.0, 0.0, 0.0, 0.20)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(bottom_shade)


func make_menu_button(button_text: String, button_position: Vector2, callback: Callable) -> Button:
	var button = Button.new()
	button.name = "Button_" + button_text.replace(" ", "")
	button.text = button_text
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(callback)
	return button


func make_player_info_button(button_position: Vector2) -> Button:
	var button = Button.new()
	button.name = "Button_PlayerInfo"
	button.text = ""
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(_on_player_info_pressed)

	if not ResourceLoader.exists(PLAYER_INFO_ICON_PATH):
		button.text = "PLAYER INFO"
		return button

	var icon_texture: Texture2D = load(PLAYER_INFO_ICON_PATH) as Texture2D
	if icon_texture == null:
		button.text = "PLAYER INFO"
		return button

	player_info_button_icon = TextureRect.new()
	player_info_button_icon.name = "PlayerInfoIcon"
	player_info_button_icon.texture = icon_texture
	player_info_button_icon.size = Vector2(42, 42)
	player_info_button_icon.position = Vector2(
		(button.size.x - player_info_button_icon.size.x) / 2.0,
		(button.size.y - player_info_button_icon.size.y) / 2.0 - 2.0
	)
	player_info_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_info_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(player_info_button_icon)
	return button


func make_friends_button(button_position: Vector2) -> Button:
	var button = Button.new()
	button.name = "Button_Friends"
	button.text = ""
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(_on_friends_pressed)

	if not ResourceLoader.exists(FRIENDS_ICON_PATH):
		button.text = "FRIENDS"
		return button

	var icon_texture: Texture2D = load(FRIENDS_ICON_PATH) as Texture2D
	if icon_texture == null:
		button.text = "FRIENDS"
		return button

	friends_button_icon = TextureRect.new()
	friends_button_icon.name = "FriendsIcon"
	friends_button_icon.texture = icon_texture
	friends_button_icon.size = Vector2(42, 42)
	friends_button_icon.position = Vector2(
		(button.size.x - friends_button_icon.size.x) / 2.0,
		(button.size.y - friends_button_icon.size.y) / 2.0 - 2.0
	)
	friends_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	friends_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(friends_button_icon)
	return button


func make_respawn_button(button_position: Vector2) -> Button:
	var button = Button.new()
	button.name = "Button_Respawn"
	button.text = ""
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(_on_respawn_pressed)

	if not ResourceLoader.exists(RESPAWN_ICON_PATH):
		button.text = "RESPAWN"
		return button

	var icon_texture: Texture2D = load(RESPAWN_ICON_PATH) as Texture2D
	if icon_texture == null:
		button.text = "RESPAWN"
		return button

	respawn_button_icon = TextureRect.new()
	respawn_button_icon.name = "RespawnIcon"
	respawn_button_icon.texture = icon_texture
	respawn_button_icon.size = Vector2(42, 42)
	respawn_button_icon.position = Vector2(
		(button.size.x - respawn_button_icon.size.x) / 2.0,
		(button.size.y - respawn_button_icon.size.y) / 2.0 - 2.0
	)
	respawn_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	respawn_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(respawn_button_icon)
	return button


func make_settings_button(button_position: Vector2) -> Button:
	var button = Button.new()
	button.name = "Button_Settings"
	button.text = ""
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(_on_settings_pressed)

	if not ResourceLoader.exists(SETTINGS_ICON_PATH):
		button.text = "SETTINGS"
		return button

	var icon_texture: Texture2D = load(SETTINGS_ICON_PATH) as Texture2D
	if icon_texture == null:
		button.text = "SETTINGS"
		return button

	settings_button_icon = TextureRect.new()
	settings_button_icon.name = "SettingsIcon"
	settings_button_icon.texture = icon_texture
	settings_button_icon.size = Vector2(42, 42)
	settings_button_icon.position = Vector2(
		(button.size.x - settings_button_icon.size.x) / 2.0,
		(button.size.y - settings_button_icon.size.y) / 2.0 - 2.0
	)
	settings_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	settings_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(settings_button_icon)
	return button


func make_lobby_button(button_position: Vector2) -> Button:
	var button = Button.new()
	button.name = "Button_MainMenu"
	button.text = ""
	button.position = button_position
	button.size = Vector2(GAME_MENU_W - 116, GAME_MENU_ROW_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_game_menu_arcade_button_style(button, false, false, 18)
	decorate_game_menu_button(button)
	button.pressed.connect(_on_main_menu_pressed)

	if not ResourceLoader.exists(LOBBY_ICON_PATH):
		button.text = "MAIN MENU"
		return button

	var icon_texture: Texture2D = load(LOBBY_ICON_PATH) as Texture2D
	if icon_texture == null:
		button.text = "MAIN MENU"
		return button

	lobby_button_icon = TextureRect.new()
	lobby_button_icon.name = "LobbyIcon"
	lobby_button_icon.texture = icon_texture
	lobby_button_icon.size = Vector2(42, 42)
	lobby_button_icon.position = Vector2(
		(button.size.x - lobby_button_icon.size.x) / 2.0,
		(button.size.y - lobby_button_icon.size.y) / 2.0 - 2.0
	)
	lobby_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lobby_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lobby_button_icon)
	return button


func _on_respawn_button_mouse_entered():
	respawn_button_hovered = true
	animate_respawn_button_icon(false)


func _on_respawn_button_mouse_exited():
	respawn_button_hovered = false
	animate_respawn_button_icon(false)


func _on_respawn_button_down():
	animate_respawn_button_icon(true)


func _on_respawn_button_up():
	animate_respawn_button_icon(false)


func animate_respawn_button_icon(pressed: bool):
	if respawn_button_icon == null or respawn_button_icon_shadow == null:
		return

	if respawn_button_tween != null:
		respawn_button_tween.kill()

	var icon_position: Vector2 = Vector2.ZERO
	var shadow_position: Vector2 = Vector2(5, 7)
	var icon_scale: Vector2 = Vector2.ONE
	var shadow_alpha: float = 0.38
	var icon_alpha: float = 0.96

	if respawn_button_hovered:
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

	respawn_button_tween = create_tween()
	respawn_button_tween.set_parallel(true)
	respawn_button_tween.tween_property(respawn_button_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	respawn_button_tween.tween_property(respawn_button_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	respawn_button_tween.tween_property(respawn_button_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	respawn_button_tween.tween_property(respawn_button_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	respawn_button_tween.tween_property(respawn_button_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	respawn_button_tween.tween_property(respawn_button_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func apply_game_menu_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 4, 12, 8))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.88, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 4, 12, 9))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 4, 12, 5))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.56), Color(0.10, 0.0, 0.02, 0.62), 4, 12, 3))
		return
	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return
	PixelUIStyle.apply_blue_button(button, font_size)


func update_menu_button_position():
	if menu_button == null:
		return

	var screen_size = get_viewport_rect().size
	menu_button.position = Vector2(max(8.0, screen_size.x - 102.0), 16)


func update_menu_button_visibility():
	if menu_button == null:
		return

	var in_world = world != null and world.has_method("is_player_in_world") and world.is_player_in_world()
	menu_button.visible = in_world


func update_overlay_position():
	if overlay == null:
		return

	var screen_size = get_viewport_rect().size
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0

	if panel != null:
		var max_x = max(12.0, screen_size.x - panel.size.x - 12.0)
		var max_y = max(56.0, screen_size.y - panel.size.y - 24.0)
		panel.position = Vector2(
			clamp((screen_size.x - panel.size.x) / 2.0, 12.0, max_x),
			clamp((screen_size.y - panel.size.y) / 2.0, 56.0, max_y)
		)


func open_menu():
	if not (world != null and world.has_method("is_player_in_world") and world.is_player_in_world()):
		return

	is_open_flag = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	update_menu_button_visibility()
	PixelUIStyle.play_panel_open(panel)


func close_menu():
	is_open_flag = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	update_menu_button_visibility()


func toggle_menu():
	if is_open():
		close_menu()
	else:
		if world != null and world.has_method("open_game_menu"):
			world.open_game_menu()
		else:
			open_menu()


func is_open() -> bool:
	return is_open_flag and overlay != null and overlay.visible


func _on_player_info_pressed():
	close_menu()
	if world != null and world.has_method("open_player_menu"):
		world.open_player_menu()


func _on_friends_pressed():
	close_menu()
	if world != null and world.has_method("open_friends_panel"):
		world.open_friends_panel()


func _on_respawn_pressed():
	if world != null and world.has_method("respawn_player"):
		world.respawn_player()
		if world.has_method("show_notification"):
			world.show_notification("Respawned at the Entrance Gate.")
	close_menu()


func _on_settings_pressed():
	close_menu()
	if world != null and world.has_method("open_settings_panel"):
		world.open_settings_panel()


func _on_main_menu_pressed():
	close_menu()
	if world != null and world.has_method("exit_to_world_menu"):
		world.exit_to_world_menu()


func _on_overlay_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()


func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
