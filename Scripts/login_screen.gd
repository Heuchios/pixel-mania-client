extends Control

const PROFILE_PATH := "user://pixelmania_profile.cfg"
const LOBBY_SCENE := "res://Scenes/lobby_menu.tscn"
const BACKGROUND_TEXTURES := [
	"res://Assets/ui/backgrounds/mountain_background.png",
]
const BACKGROUND_FRAME_ORDER := [0]
const BACKGROUND_FRAME_SECONDS := 0.35
const AccountManagerScript = preload("res://Scripts/account_manager.gd")
const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const WorldScenePreloader = preload("res://Scripts/world_scene_preloader.gd")
const LOGIN_PANEL_W := 520.0
const LOGIN_PANEL_H := 500.0
const LOGIN_FIELD_W := 470.0
const LOGIN_FIELD_H := 52.0
const LOGIN_BUTTON_W := 214.0
const LOGIN_BUTTON_H := 58.0
const EXIT_BUTTON_W := 240.0
const EXIT_BUTTON_H := 34.0

var background_rect: TextureRect
var background_textures: Array = []
var background_frame_cursor := 0
var background_frame_timer := 0.0
var username_input: LineEdit
var email_input: LineEdit
var password_input: LineEdit
var remember_password_check: CheckBox
var message_label: Label
var server_status_panel: PanelContainer
var server_status_dot: Panel
var server_status_label: Label
var version_label: Label
var account_manager = null
var saved_session_username := ""
var saved_session_email := ""
var saved_session_token := ""
var saved_session_role := "player"
var auth_busy := false
var pending_auth_request_id := ""
var pending_auth_response := {}
var server_status_refresh_timer := 0.0


func _ready() -> void:
	WorldScenePreloader.start()
	_setup_account_manager()
	_build_screen()
	_connect_network_auth_signal()
	_load_saved_account()
	_update_server_status_indicator(_is_network_connected(_get_network_manager()))
	_show_network_login_notice()


func _process(delta: float) -> void:
	WorldScenePreloader.pump()
	_update_background_animation(delta)

	server_status_refresh_timer -= delta
	if server_status_refresh_timer > 0.0:
		return

	server_status_refresh_timer = 0.35
	_update_server_status_indicator(_is_network_connected(_get_network_manager()))


func _setup_account_manager() -> void:
	account_manager = Node.new()
	account_manager.name = "LoginAccountManager"
	account_manager.set_script(AccountManagerScript)
	add_child(account_manager)

	if account_manager.has_method("setup"):
		account_manager.setup(null)


func _connect_network_auth_signal() -> void:
	var network = get_node_or_null("/root/NetworkManager")

	if network == null:
		return

	if network.has_signal("server_auth_finished") and not network.server_auth_finished.is_connected(_on_server_auth_finished):
		network.server_auth_finished.connect(_on_server_auth_finished)

	if network.has_signal("server_connection_changed") and not network.server_connection_changed.is_connected(_on_server_connection_changed):
		network.server_connection_changed.connect(_on_server_connection_changed)


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_add_real_background()
	_add_dark_gradient_overlay()
	_add_server_status_indicator()

	var center := Control.new()
	center.name = "LoginPanel"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -LOGIN_PANEL_W * 0.5
	center.offset_top = -LOGIN_PANEL_H * 0.5
	center.offset_right = LOGIN_PANEL_W * 0.5
	center.offset_bottom = LOGIN_PANEL_H * 0.5
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	var logo := Label.new()
	logo.name = "Title"
	logo.text = "PIXELMANIA"
	logo.position = Vector2(0, 24)
	logo.size = Vector2(LOGIN_PANEL_W, 70)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(logo, 52)
	center.add_child(logo)

	var field_x := (LOGIN_PANEL_W - LOGIN_FIELD_W) * 0.5
	var field_size := Vector2(LOGIN_FIELD_W, LOGIN_FIELD_H)
	username_input = _make_login_input("UsernameInput", "Username", Vector2(field_x, 118), field_size)
	username_input.text_submitted.connect(_on_username_submitted)
	center.add_child(username_input)

	email_input = _make_login_input("EmailInput", "Email", Vector2(field_x, 188), field_size)
	email_input.text_submitted.connect(_on_email_submitted)
	center.add_child(email_input)

	password_input = _make_login_input("PasswordInput", "Password", Vector2(field_x, 258), field_size, true)
	password_input.text_submitted.connect(_on_password_submitted)
	center.add_child(password_input)

	remember_password_check = CheckBox.new()
	remember_password_check.name = "RememberPasswordCheck"
	remember_password_check.text = "Remember password"
	remember_password_check.position = Vector2(field_x, 320)
	remember_password_check.size = Vector2(260, 30)
	remember_password_check.mouse_filter = Control.MOUSE_FILTER_STOP
	remember_password_check.add_theme_font_size_override("font_size", 16)
	remember_password_check.add_theme_color_override("font_color", Color.WHITE)
	remember_password_check.add_theme_color_override("font_hover_color", Color.WHITE)
	remember_password_check.add_theme_color_override("font_pressed_color", Color.WHITE)
	remember_password_check.add_theme_color_override("font_shadow_color", Color.BLACK)
	remember_password_check.add_theme_constant_override("shadow_offset_x", 2)
	remember_password_check.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(remember_password_check)

	var register_button := _make_big_button("Register", Color(0.25, 0.66, 1.0), Color(0.08, 0.30, 0.78))
	register_button.position = Vector2(37, 358)
	register_button.size = Vector2(LOGIN_BUTTON_W, LOGIN_BUTTON_H)
	register_button.pressed.connect(_on_register_pressed)
	center.add_child(register_button)

	var sign_button := _make_big_button("Sign On", Color(0.40, 0.95, 0.16), Color(0.12, 0.58, 0.07))
	sign_button.position = Vector2(269, 358)
	sign_button.size = Vector2(LOGIN_BUTTON_W, LOGIN_BUTTON_H)
	sign_button.pressed.connect(_on_sign_on_pressed)
	center.add_child(sign_button)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = ""
	message_label.position = Vector2(field_x, 420)
	message_label.size = Vector2(LOGIN_FIELD_W, 26)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(message_label)

	var exit_button := _make_small_button("Exit", Color(0.95, 0.18, 0.18), Color(0.48, 0.02, 0.04))
	exit_button.position = Vector2((LOGIN_PANEL_W - EXIT_BUTTON_W) * 0.5, 452)
	exit_button.size = Vector2(EXIT_BUTTON_W, EXIT_BUTTON_H)
	exit_button.pressed.connect(_on_exit_pressed)
	center.add_child(exit_button)

	PixelUIStyle.play_panel_open(center, Vector2(0.98, 0.98), 0.22)


func _add_server_status_indicator() -> void:
	server_status_panel = PanelContainer.new()
	server_status_panel.name = "ServerStatusIndicator"
	server_status_panel.anchor_left = 1.0
	server_status_panel.anchor_top = 0.0
	server_status_panel.anchor_right = 1.0
	server_status_panel.anchor_bottom = 0.0
	server_status_panel.offset_left = -234
	server_status_panel.offset_top = 24
	server_status_panel.offset_right = -24
	server_status_panel.offset_bottom = 62
	server_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	server_status_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.010, 0.016, 0.022, 0.96),
		Color(0.0, 0.0, 0.0, 0.98),
		4,
		18,
		8
	))
	add_child(server_status_panel)

	var row := HBoxContainer.new()
	row.name = "StatusRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	server_status_panel.add_child(row)

	server_status_dot = Panel.new()
	server_status_dot.name = "StatusDot"
	server_status_dot.custom_minimum_size = Vector2(12, 30)
	server_status_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(server_status_dot)

	server_status_label = Label.new()
	server_status_label.name = "StatusLabel"
	server_status_label.text = "Server Offline"
	server_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	server_status_label.add_theme_font_size_override("font_size", 16)
	server_status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	server_status_label.add_theme_constant_override("shadow_offset_x", 2)
	server_status_label.add_theme_constant_override("shadow_offset_y", 2)
	server_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(server_status_label)

	_update_server_status_indicator(false)


func _add_version_label() -> void:
	version_label = Label.new()
	version_label.name = "ClientVersionLabel"
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -180
	version_label.offset_top = -42
	version_label.offset_right = -22
	version_label.offset_bottom = -16
	version_label.text = "v" + _get_client_version_text()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.76))
	version_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	version_label.add_theme_constant_override("shadow_offset_x", 2)
	version_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(version_label)


func _get_client_version_text() -> String:
	var network = _get_network_manager()
	if network != null and network.has_method("get_client_version"):
		var version = str(network.get_client_version()).strip_edges()
		if version != "":
			return version

	return "unknown"


func _status_dot_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _update_server_status_indicator(is_online: bool) -> void:
	if server_status_label == null or server_status_dot == null:
		return

	var color := Color(0.36, 1.0, 0.24) if is_online else Color(1.0, 0.20, 0.20)
	server_status_label.text = "Server Online" if is_online else "Server Offline"
	server_status_label.add_theme_color_override("font_color", color)
	server_status_dot.add_theme_stylebox_override("panel", _status_dot_style(color))


func _add_real_background() -> void:
	background_textures.clear()
	for texture_path in BACKGROUND_TEXTURES:
		if not ResourceLoader.exists(str(texture_path)):
			continue

		var texture := load(str(texture_path))
		if texture is Texture2D:
			background_textures.append(texture)

	var bg := TextureRect.new()
	bg.name = "MountainBackground"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if not background_textures.is_empty():
		bg.texture = background_textures[0]
	else:
		bg.modulate = Color(0.02, 0.02, 0.09)

	background_rect = bg
	add_child(bg)


func _update_background_animation(delta: float) -> void:
	if background_rect == null or background_textures.size() <= 1:
		return

	background_frame_timer += delta
	if background_frame_timer < BACKGROUND_FRAME_SECONDS:
		return

	background_frame_timer = 0.0
	background_frame_cursor = (background_frame_cursor + 1) % BACKGROUND_FRAME_ORDER.size()
	var texture_index := int(BACKGROUND_FRAME_ORDER[background_frame_cursor])
	if texture_index >= 0 and texture_index < background_textures.size():
		background_rect.texture = background_textures[texture_index]


func _add_dark_gradient_overlay() -> void:
	var shade := ColorRect.new()
	shade.name = "BackgroundShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.10)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _make_login_input(node_name: String, placeholder: String, input_position: Vector2, input_size: Vector2, secret_input: bool = false) -> LineEdit:
	var input := LineEdit.new()
	input.name = node_name
	input.placeholder_text = placeholder
	input.position = input_position
	input.size = input_size
	input.custom_minimum_size = input_size
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.secret = secret_input
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_login_input_style(input, 22)
	return input


func _apply_login_input_style(line_edit: LineEdit, font_size: int = 22) -> void:
	if line_edit == null:
		return

	line_edit.add_theme_font_size_override("font_size", font_size)
	line_edit.add_theme_stylebox_override("normal", PixelUIStyle.style_box(
		Color(0.015, 0.040, 0.070, 0.95),
		Color(0.002, 0.008, 0.014, 1.0),
		4,
		17,
		7
	))
	line_edit.add_theme_stylebox_override("focus", PixelUIStyle.style_box(
		Color(0.022, 0.058, 0.095, 0.98),
		Color(0.70, 0.86, 1.0, 0.95),
		4,
		17,
		8
	))
	line_edit.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.78, 0.88, 0.96, 0.64))
	line_edit.add_theme_color_override("caret_color", Color(0.95, 0.76, 0.10, 1.0))
	line_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))


func _apply_login_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 16) -> void:
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.62, 0.08, 0.15, 0.98), Color(0.18, 0.01, 0.05, 1.0), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.12, 0.22, 0.98), Color(1.0, 0.38, 0.40, 0.72), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.40, 0.03, 0.09, 0.98), Color(0.12, 0.0, 0.02, 1.0), 3, 12, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.72), Color(0.10, 0.0, 0.02, 0.92), 3, 12, 3))
		return

	if selected:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.95, 0.68, 0.08, 0.98), Color(1.0, 0.90, 0.22, 0.95), 3, 8, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(1.0, 0.76, 0.12, 0.98), Color(1.0, 0.96, 0.38, 1.0), 3, 8, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.72, 0.36, 0.04, 0.98), Color(0.42, 0.15, 0.01, 1.0), 3, 8, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.48, 0.34, 0.05, 0.76), Color(0.74, 0.58, 0.12, 0.78), 3, 8, 3))
		return

	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.060, 0.080, 0.145, 0.78), Color(0.45, 0.74, 1.0, 0.22), 2, 8, 2))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.09, 0.16, 0.30, 0.92), Color(0.50, 0.92, 1.0, 0.65), 2, 8, 4))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.04, 0.10, 0.22, 0.98), Color(0.18, 0.48, 0.86, 0.85), 2, 8, 2))
	button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.030, 0.045, 0.080, 0.62), Color(0.16, 0.28, 0.48, 0.30), 2, 8, 1))


func _make_big_button(text: String, top_color: Color, bottom_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(LOGIN_BUTTON_W, LOGIN_BUTTON_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_color_button_style(button, top_color, bottom_color, 24, 15, 4, 8)
	return button


func _make_small_button(text: String, top_color: Color, bottom_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(EXIT_BUTTON_W, EXIT_BUTTON_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_color_button_style(button, top_color, bottom_color, 14, 11, 3, 6)
	return button


func _apply_color_button_style(button: Button, fill: Color, border: Color, font_size: int, radius: int, border_width: int, shadow_size: int) -> void:
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(fill, border, border_width, radius, shadow_size))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(fill.lightened(0.08), border.lightened(0.08), border_width, radius, shadow_size + 1))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(fill.darkened(0.14), border.darkened(0.12), border_width, radius, max(2, shadow_size - 2)))
	button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(fill.darkened(0.35), border.darkened(0.30), border_width, radius, 3))


func _style_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style


func _load_saved_account() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PROFILE_PATH)
	if err == OK:
		var username = str(cfg.get_value("profile", "username", ""))
		saved_session_username = username.strip_edges()
		saved_session_email = str(cfg.get_value("profile", "email", "")).strip_edges()
		username_input.text = username
		email_input.text = saved_session_email
		var remember_login = bool(cfg.get_value("profile", "remember_login", cfg.get_value("profile", "remember_password", false)))
		remember_password_check.button_pressed = remember_login
		saved_session_token = str(cfg.get_value("profile", "session_token", "")).strip_edges() if remember_login else ""
		saved_session_role = str(cfg.get_value("profile", "role", "player")).strip_edges().to_lower()
		password_input.text = ""
		_clear_local_password_cache(cfg)
		cfg.set_value("profile", "remember_login", remember_login)
		if not remember_login:
			cfg.set_value("profile", "session_token", "")
		cfg.save(PROFILE_PATH)

		if email_input.text.strip_edges() == "" and account_manager != null and account_manager.has_method("get_email_for_username"):
			email_input.text = account_manager.get_email_for_username(username)


func _on_username_submitted(_text: String) -> void:
	if email_input.text.strip_edges() == "":
		email_input.grab_focus()
	else:
		password_input.grab_focus()


func _on_email_submitted(_text: String) -> void:
	password_input.grab_focus()


func _on_password_submitted(_text: String) -> void:
	_on_sign_on_pressed()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_server_auth_finished(data) -> void:
	if not (data is Dictionary):
		return

	var request_id = str(data.get("request_id", "")).strip_edges()
	if request_id == "" or request_id != pending_auth_request_id:
		return

	pending_auth_response = data.duplicate(true)


func _on_server_connection_changed(server_connected: bool) -> void:
	_update_server_status_indicator(server_connected)
	_show_network_login_notice()


func _get_network_manager():
	return get_node_or_null("/root/NetworkManager")


func _is_network_connected(network) -> bool:
	if network == null:
		return false

	if network.has_method("is_connected_to_server"):
		return bool(network.is_connected_to_server())

	if "connected" in network:
		return bool(network.get("connected"))

	return false


func _show_network_login_notice() -> void:
	var network = _get_network_manager()
	if network == null or not network.has_method("get_login_notice_message"):
		return

	var notice = str(network.get_login_notice_message()).strip_edges()
	if notice != "":
		_show_message(notice)


func _clear_network_login_notice() -> void:
	var network = _get_network_manager()
	if network != null and network.has_method("set_login_notice_message"):
		network.set_login_notice_message("")


func _is_android_runtime() -> bool:
	return OS.has_feature("android") or OS.get_name().to_lower() == "android"


func _server_connection_failed_message() -> String:
	var message := "Could not reach the server. Check your connection and try again."
	var network = _get_network_manager()
	if _is_android_runtime() and network != null and network.has_method("get_connection_debug_summary"):
		var detail = str(network.get_connection_debug_summary()).strip_edges()
		if detail != "":
			message += "\n" + detail
	return message


func _wait_for_server_connection(timeout_seconds: float = 10.0) -> bool:
	if _is_android_runtime():
		timeout_seconds = max(timeout_seconds, 16.0)

	var deadline = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var first_attempt := true
	var next_status_update := 0

	while Time.get_ticks_msec() < deadline:
		var network = _get_network_manager()
		if _is_network_connected(network):
			_connect_network_auth_signal()
			return true

		if network != null:
			_connect_network_auth_signal()
			if network.has_method("request_server_connection"):
				network.request_server_connection(first_attempt)
				first_attempt = false

			if Time.get_ticks_msec() >= next_status_update:
				var state_text = "connecting"
				if network.has_method("get_server_connection_state_text"):
					state_text = str(network.get_server_connection_state_text())
				_show_message("Connecting to server... " + state_text)
				next_status_update = Time.get_ticks_msec() + 750

		await get_tree().process_frame

	return false


func _wait_for_auth_response(request_id: String, timeout_seconds: float = 8.0) -> Dictionary:
	pending_auth_request_id = request_id
	pending_auth_response.clear()
	var deadline = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)

	while Time.get_ticks_msec() < deadline:
		if not pending_auth_response.is_empty():
			var response = pending_auth_response.duplicate(true)
			pending_auth_response.clear()
			pending_auth_request_id = ""
			return response

		await get_tree().process_frame

	pending_auth_request_id = ""
	return {"ok": false, "message": "Connection timed out. Try again."}


func _validate_register_input(username: String, email: String, password: String) -> Dictionary:
	if account_manager == null:
		return {"ok": false, "message": "Account system not ready."}

	var username_validation = account_manager.validate_username(username)
	if not bool(username_validation.get("ok", false)):
		return username_validation

	var email_validation = account_manager.validate_email(email)
	if not bool(email_validation.get("ok", false)):
		return email_validation

	var password_validation = account_manager.validate_password(password)
	if not bool(password_validation.get("ok", false)):
		return password_validation

	return {"ok": true}


func _cache_server_account(username: String, email: String) -> void:
	if account_manager != null and account_manager.has_method("cache_server_account"):
		account_manager.cache_server_account(username, email)


func _on_register_pressed() -> void:
	if auth_busy:
		return

	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	var validation = _validate_register_input(username, email, password)
	if not bool(validation.get("ok", false)):
		_show_message(str(validation.get("message", "Could not register account.")))
		return

	_clear_network_login_notice()
	auth_busy = true
	_show_message("Connecting to server...")

	var connected_ok = await _wait_for_server_connection()
	if not connected_ok:
		auth_busy = false
		_show_message(_server_connection_failed_message())
		return

	var network = _get_network_manager()
	if network == null or not network.has_method("send_account_register"):
		auth_busy = false
		_show_message("Server account system not ready.")
		return

	var request_id = str(network.send_account_register(username, email, password))
	if request_id == "":
		auth_busy = false
		_show_message("Could not contact server.")
		return

	var result = await _wait_for_auth_response(request_id)
	auth_busy = false
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not register account.")))
		return

	if bool(result.get("requires_email_verification", false)):
		_show_message(str(result.get("message", "Check your email to verify this account before signing on.")))
		password_input.text = ""
		return

	var server_username = str(result.get("username", username))
	var server_email = str(result.get("email", email))
	var session_token = str(result.get("session_token", ""))
	var role = str(result.get("role", "player"))
	if session_token == "":
		_show_message("Check your email to verify this account before signing on.")
		return

	_cache_server_account(server_username, server_email)
	_save_active_account(server_username, server_email, session_token, role)
	password_input.text = ""
	_show_message("Account registered.")
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_sign_on_pressed() -> void:
	if auth_busy:
		return

	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text

	if username == "":
		_show_message("Enter your username.")
		return

	_clear_network_login_notice()
	auth_busy = true
	_show_message("Signing on...")

	var connected_ok = await _wait_for_server_connection()
	if not connected_ok:
		auth_busy = false
		_show_message(_server_connection_failed_message())
		return

	var network = _get_network_manager()
	if network == null:
		auth_busy = false
		_show_message("Server account system not ready.")
		return

	var request_id = ""

	var email_matches_saved = email == "" or email.to_lower() == saved_session_email.to_lower()
	if password == "" and saved_session_token != "" and username.to_lower() == saved_session_username.to_lower() and email_matches_saved:
		if network.has_method("send_account_token_login"):
			request_id = str(network.send_account_token_login(username, saved_session_token))
	else:
		if account_manager != null and account_manager.has_method("validate_email"):
			var email_validation = account_manager.validate_email(email)
			if not bool(email_validation.get("ok", false)):
				auth_busy = false
				_show_message(str(email_validation.get("message", "Enter your email address.")))
				return

		if account_manager != null and account_manager.has_method("validate_password"):
			var password_validation = account_manager.validate_password(password)
			if not bool(password_validation.get("ok", false)):
				auth_busy = false
				_show_message(str(password_validation.get("message", "Enter your password.")))
				return

		if network.has_method("send_account_login"):
			request_id = str(network.send_account_login(username, email, password))

	if request_id == "":
		auth_busy = false
		_show_message("Could not contact server.")
		return

	var result = await _wait_for_auth_response(request_id)
	auth_busy = false
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not sign on.")))
		return

	if bool(result.get("requires_email_verification", false)):
		_show_message(str(result.get("message", "Verify your email before signing on.")))
		return

	var server_username = str(result.get("username", username))
	var server_email = str(result.get("email", ""))
	var session_token = str(result.get("session_token", ""))
	var role = str(result.get("role", "player"))
	if session_token == "":
		_show_message("Verify your email before signing on.")
		return

	_cache_server_account(server_username, server_email)
	_save_active_account(server_username, server_email, session_token, role)
	password_input.text = ""
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _save_active_account(username: String, email: String, token: String, role: String = "player") -> void:
	_set_network_session(username, email, token, role)

	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	var should_remember_login = remember_password_check != null and remember_password_check.button_pressed
	cfg.set_value("profile", "username", username)
	cfg.set_value("profile", "email", email)
	cfg.set_value("profile", "session_token", token if should_remember_login else "")
	cfg.set_value("profile", "role", role)
	cfg.set_value("profile", "remember_login", should_remember_login)
	_clear_local_password_cache(cfg)
	cfg.save(PROFILE_PATH)
	saved_session_username = username
	saved_session_email = email
	saved_session_token = token if should_remember_login else ""
	saved_session_role = role


func _clear_local_password_cache(cfg: ConfigFile) -> void:
	cfg.set_value("profile", "remember_password", false)
	cfg.set_value("profile", "saved_password", "")
	cfg.set_value("profile", "password", "")


func _set_network_session(username: String, email: String, token: String, role: String = "player") -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("set_active_session"):
		network.set_active_session(username, email, token, role)


func _show_message(text: String) -> void:
	message_label.text = text
