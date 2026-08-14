extends Control

const PROFILE_PATH := "user://pixelmania_profile.cfg"
const LOBBY_SCENE := "res://Scenes/ui/lobby/LobbyScene.tscn"
const WORLD_SCENE := "res://Scenes/main.tscn"
const CUSTOM_MOVEMENT_TEST_SCENE := "res://custom_movement_test/scenes/custom_movement_test_main.tscn"
const CUSTOM_REAL_WORLD_MOVEMENT_TEST_SCENE := "res://custom_movement_test/scenes/custom_real_world_movement_test.tscn"
const DEV_TEST_USERNAME := "DevNetfox"
const DEV_TEST_EMAIL := "dev-netfox@local.invalid"
const DEV_TEST_SESSION_TOKEN := "dev-test-login-local-only"
const STARRY_NIGHT_LAYERS := [
	{"file": "Starry_night_Layer_8.png", "drift": Vector2.ZERO, "speed": 0.0, "phase": 0.0, "overscan": 0.0},
	{"file": "Starry_night_Layer_7.png", "drift": Vector2(18.0, 0.0), "speed": 0.32, "phase": 0.0, "overscan": 24.0},
	{"file": "Starry_night_Layer_6.png", "drift": Vector2(28.0, 0.0), "speed": 0.39, "phase": 2.1, "overscan": 34.0},
	{"file": "Starry_night_Layer_5.png", "drift": Vector2(40.0, 0.0), "speed": 0.46, "phase": 4.2, "overscan": 46.0},
]
const AccountManagerScript = preload("res://Scripts/account_manager.gd")
const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const WorldScenePreloader = preload("res://Scripts/world_scene_preloader.gd")
const NEWS_API_PATH := "/news"
const NEWS_FALLBACK_API_BASE := "https://api.pixelmaniagame.com"
const NEWS_REQUEST_TIMEOUT_SECONDS := 8.0
const NEWS_MAX_ENTRIES := 20

var parallax_background: Control
var parallax_layers: Array = []
var parallax_time := 0.0
var username_input: LineEdit
var email_input: LineEdit
var password_input: LineEdit
var remember_password_check: CheckBox
var message_label: Label
var server_status_panel: Control
var server_status_dot: Panel
var server_status_label: Label
var news_list_root: VBoxContainer
var empty_news_label: Label
var account_manager = null
var profile_path: String = PROFILE_PATH
var saved_session_username := ""
var saved_session_email := ""
var saved_session_token := ""
var saved_refresh_token := ""
var saved_session_role := "player"
var loading_saved_account := false
var auth_busy := false
var pending_auth_request_id := ""
var pending_auth_response := {}
var server_status_refresh_timer := 0.0
var netfox_launch_scene_change_in_progress := false


func _ready() -> void:
	if _try_custom_movement_test_redirect():
		return

	if _try_netfox_server_login_skip():
		return

	if _try_backend_dev_login_bypass():
		return

	if _try_dev_test_login_bypass():
		return

	WorldScenePreloader.start()
	_setup_login_sound()
	_setup_account_manager()
	if not _bind_login_scene_ui():
		return
	_connect_network_auth_signal()
	_load_saved_account()
	_update_server_status_indicator(_is_network_connected(_get_network_manager()))
	_show_network_login_notice()
	call_deferred("_try_enter_authenticated_netfox_launch_world")
	call_deferred("_fetch_login_news")


func _try_custom_movement_test_redirect() -> bool:
	if not MovementMode.has_method("is_custom_movement_test_launch_requested"):
		return false
	if not MovementMode.is_custom_movement_test_launch_requested():
		return false

	var scene_path := CUSTOM_MOVEMENT_TEST_SCENE
	if MovementMode.has_method("has_launch_arg") and MovementMode.has_launch_arg("--custom-movement-real-world-test"):
		scene_path = CUSTOM_REAL_WORLD_MOVEMENT_TEST_SCENE

	MovementMode.set_mode(MovementMode.Mode.CUSTOM_AUTHORITATIVE)
	print("[CustomMovementTest] Redirecting login launch to " + scene_path)
	get_tree().call_deferred("change_scene_to_file", scene_path)
	return true


func _try_netfox_server_login_skip() -> bool:
	if MovementMode.has_method("is_netfox_real_server_launch") and MovementMode.is_netfox_real_server_launch():
		print("[NetfoxReal] Server mode detected; skipping login UI.")
		call_deferred("_enter_netfox_server_world_scene")
		return true
	return false


func _enter_netfox_server_world_scene() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _try_backend_dev_login_bypass() -> bool:
	if not MovementMode.is_backend_dev_login_requested():
		return false

	if not MovementMode.is_backend_dev_login_allowed():
		MovementMode.report_backend_dev_login_rejected()
		return false

	# TODO: Remove backend-dev-login before production release.
	MovementMode.set_mode(MovementMode.Mode.NETFOX_REAL)
	_setup_account_manager()
	if not _bind_login_scene_ui():
		return false
	_connect_network_auth_signal()
	_show_message("Starting backend dev login...")
	call_deferred("_run_backend_dev_login_bypass")
	return true


func _run_backend_dev_login_bypass() -> void:
	auth_busy = true

	var world_name := MovementMode.get_dev_test_world_name("NETFOX_TEST")
	var profile_name := MovementMode.get_dev_profile_name(DEV_TEST_USERNAME)
	_show_message("Connecting as " + profile_name + "...")

	var connected_ok = await _wait_for_server_connection(12.0)
	if not connected_ok:
		auth_busy = false
		_show_message(_server_connection_failed_message())
		return

	var network = _get_network_manager()
	if network == null or not network.has_method("send_backend_dev_login"):
		auth_busy = false
		_show_message("Backend dev login is not available.")
		return

	if network.has_method("set_pending_join"):
		network.set_pending_join(world_name, profile_name)
	network.set("current_world_name", world_name)
	_write_pending_join_profile_config(world_name, profile_name, "", "", false)

	var request_id = str(network.send_backend_dev_login(profile_name, world_name))
	if request_id == "":
		auth_busy = false
		_show_message("Could not start backend dev login.")
		return

	var result = await _wait_for_auth_response(request_id, 10.0)
	auth_busy = false
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Backend dev login failed.")))
		return

	var server_username = str(result.get("username", profile_name))
	var server_email = str(result.get("email", "%s@dev.local.invalid" % server_username.to_lower()))
	var session_token = str(result.get("session_token", ""))
	var refresh_token = str(result.get("refresh_token", ""))
	var role = str(result.get("role", "player"))
	if session_token == "":
		_show_message("Backend dev login did not return a session.")
		return

	_cache_server_account(server_username, server_email)
	_save_active_account(server_username, server_email, session_token, role, refresh_token)
	if network.has_method("set_pending_join"):
		network.set_pending_join(world_name, server_username)
	network.set("current_world_name", world_name)
	_write_pending_join_profile_config(world_name, server_username, server_email, "", false, role)
	print("[BackendDevLogin] Authenticated %s for %s in %s mode." % [server_username, world_name, MovementMode.get_mode_name()])
	print("[NetfoxReal] Client dev login complete; entering world %s." % world_name)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _process(delta: float) -> void:
	WorldScenePreloader.pump()
	_update_background_parallax(delta)

	server_status_refresh_timer -= delta
	if server_status_refresh_timer > 0.0:
		return

	server_status_refresh_timer = 0.35
	_update_server_status_indicator(_is_network_connected(_get_network_manager()))


func _try_dev_test_login_bypass() -> bool:
	if not MovementMode.is_dev_test_login_requested():
		return false

	if not MovementMode.is_dev_test_login_allowed():
		MovementMode.report_dev_test_login_rejected()
		if not MovementMode.is_websocket() and not MovementMode.is_netfox_real_launch_requested():
			MovementMode.set_mode(MovementMode.Mode.WEBSOCKET)
		return false

	# TODO: Remove dev-test-login before production release.
	MovementMode.set_mode(MovementMode.Mode.NETFOX_REAL)
	_setup_account_manager()

	var world_name := MovementMode.get_dev_test_world_name("NETFOX_TEST")
	var profile_name := MovementMode.get_dev_profile_name(DEV_TEST_USERNAME)
	_prepare_dev_test_profile(world_name, profile_name)
	print("[DevTestLogin] Entering %s as %s in %s mode." % [world_name, profile_name, MovementMode.get_mode_name()])
	call_deferred("_enter_dev_test_world_scene")
	return true


func _prepare_dev_test_profile(world_name: String, profile_name: String) -> void:
	var clean_profile_name := profile_name.strip_edges()
	if clean_profile_name == "":
		clean_profile_name = DEV_TEST_USERNAME
	var dev_email := "%s@local.invalid" % clean_profile_name.to_lower()
	var dev_token := "%s-%s" % [DEV_TEST_SESSION_TOKEN, clean_profile_name.to_lower()]

	_set_network_session(clean_profile_name, dev_email, dev_token, "player")

	if account_manager != null:
		if account_manager.has_method("cache_dev_test_account"):
			account_manager.cache_dev_test_account(clean_profile_name, dev_email)
		elif account_manager.has_method("cache_server_account"):
			account_manager.cache_server_account(clean_profile_name, dev_email)

	var network = get_node_or_null("/root/NetworkManager")
	if network != null:
		if network.has_method("set_pending_join"):
			network.set_pending_join(world_name, clean_profile_name)
		network.set("current_world_name", world_name)

	_write_pending_join_profile_config(world_name, clean_profile_name, dev_email, "", false)


func _write_pending_join_profile_config(world_name: String, profile_name: String, email: String = "", token: String = "", remember_login: bool = false, role: String = "player", refresh_token: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	cfg.set_value("profile", "username", profile_name)
	cfg.set_value("profile", "email", email)
	cfg.set_value("profile", "session_token", token if remember_login else "")
	cfg.set_value("profile", "refresh_token", refresh_token if remember_login else "")
	cfg.set_value("profile", "role", role)
	cfg.set_value("profile", "remember_login", remember_login)
	cfg.set_value("profile", "last_world", world_name)
	_clear_local_password_cache(cfg)
	cfg.set_value("pending_join", "enabled", true)
	cfg.set_value("pending_join", "world_name", world_name)
	cfg.set_value("pending_join", "profile_name", profile_name)
	cfg.save(profile_path)


func _enter_dev_test_world_scene() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _setup_login_sound() -> void:
	# Plays on the MusicManager autoload (not a child of this scene) so it survives the
	# login -> lobby scene change instead of being freed and restarted from 0:00 -- see
	# music_manager.gd for why. Safe to call even if it's already looping (e.g. player came
	# back here via a logout/profile-switch from the lobby): it just no-ops.
	if MusicManager != null and MusicManager.has_method("start_login_loop"):
		MusicManager.start_login_loop()


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


func _bind_login_scene_ui() -> bool:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_scene_background_layers()

	username_input = get_node_or_null("LoginPanel/Form/UsernameField/UsernameInput") as LineEdit
	email_input = get_node_or_null("LoginPanel/Form/EmailField/EmailInput") as LineEdit
	password_input = get_node_or_null("LoginPanel/Form/PasswordField/PasswordInput") as LineEdit
	remember_password_check = get_node_or_null("LoginPanel/Form/RememberPasswordCheck") as CheckBox
	message_label = get_node_or_null("LoginPanel/Form/MessageLabel") as Label
	server_status_panel = get_node_or_null("ServerStatusPill") as Control
	server_status_dot = get_node_or_null("ServerStatusPill/StatusDot") as Panel
	server_status_label = get_node_or_null("ServerStatusPill/StatusLabel") as Label
	# News panel is optional -- an older/modified LoginScene without it should still let
	# players log in, so these are looked up softly rather than added to the required-node
	# `missing` list below.
	news_list_root = get_node_or_null("NewsPanel/NewsScroll/NewsList") as VBoxContainer
	empty_news_label = get_node_or_null("NewsPanel/EmptyNewsLabel") as Label

	var register_button := get_node_or_null("LoginPanel/Form/RegisterButton") as Button
	var sign_button := get_node_or_null("LoginPanel/Form/SignOnButton") as Button
	var reset_email_button := get_node_or_null("LoginPanel/Form/ResetEmailButton") as Button
	var reset_password_button := get_node_or_null("LoginPanel/Form/ResetPasswordButton") as Button
	var exit_button := get_node_or_null("LoginPanel/Form/ExitButton") as Button
	var missing: Array[String] = []
	_append_missing_node(missing, username_input, "LoginPanel/Form/UsernameField/UsernameInput")
	_append_missing_node(missing, email_input, "LoginPanel/Form/EmailField/EmailInput")
	_append_missing_node(missing, password_input, "LoginPanel/Form/PasswordField/PasswordInput")
	_append_missing_node(missing, remember_password_check, "LoginPanel/Form/RememberPasswordCheck")
	_append_missing_node(missing, message_label, "LoginPanel/Form/MessageLabel")
	_append_missing_node(missing, server_status_dot, "ServerStatusPill/StatusDot")
	_append_missing_node(missing, server_status_label, "ServerStatusPill/StatusLabel")
	_append_missing_node(missing, register_button, "LoginPanel/Form/RegisterButton")
	_append_missing_node(missing, sign_button, "LoginPanel/Form/SignOnButton")
	_append_missing_node(missing, reset_email_button, "LoginPanel/Form/ResetEmailButton")
	_append_missing_node(missing, reset_password_button, "LoginPanel/Form/ResetPasswordButton")
	_append_missing_node(missing, exit_button, "LoginPanel/Form/ExitButton")
	if not missing.is_empty():
		push_error("LoginScene is missing required nodes: " + ", ".join(missing))
		return false

	if not username_input.text_submitted.is_connected(_on_username_submitted):
		username_input.text_submitted.connect(_on_username_submitted)
	if not email_input.text_submitted.is_connected(_on_email_submitted):
		email_input.text_submitted.connect(_on_email_submitted)
	if not password_input.text_submitted.is_connected(_on_password_submitted):
		password_input.text_submitted.connect(_on_password_submitted)
	if not remember_password_check.toggled.is_connected(_on_remember_login_toggled):
		remember_password_check.toggled.connect(_on_remember_login_toggled)
	if not register_button.pressed.is_connected(_on_register_pressed):
		register_button.pressed.connect(_on_register_pressed)
	if not sign_button.pressed.is_connected(_on_sign_on_pressed):
		sign_button.pressed.connect(_on_sign_on_pressed)
	if not reset_email_button.pressed.is_connected(_on_reset_email_pressed):
		reset_email_button.pressed.connect(_on_reset_email_pressed)
	if not reset_password_button.pressed.is_connected(_on_reset_password_pressed):
		reset_password_button.pressed.connect(_on_reset_password_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

	var login_panel := get_node_or_null("LoginPanel") as Control
	if login_panel != null:
		PixelUIStyle.play_panel_open(login_panel, Vector2(0.98, 0.98), 0.22)

	return true


func _append_missing_node(missing: Array[String], node: Node, node_path: String) -> void:
	if node == null:
		missing.append(node_path)


func _bind_scene_background_layers() -> void:
	parallax_layers.clear()
	parallax_background = get_node_or_null("StarryNightBackground") as Control
	if parallax_background == null:
		return

	for layer_data in STARRY_NIGHT_LAYERS:
		var file_name := str(layer_data.get("file", "")).get_basename()
		var layer := parallax_background.get_node_or_null(file_name) as TextureRect
		if layer == null:
			var layer_suffix := file_name.substr(file_name.rfind("_") + 1)
			layer = parallax_background.get_node_or_null("Layer" + layer_suffix) as TextureRect
		if layer == null:
			continue

		layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		parallax_layers.append({
			"node": layer,
			"base_position": layer.position,
			"drift": layer_data.get("drift", Vector2.ZERO),
			"speed": float(layer_data.get("speed", 0.0)),
			"phase": float(layer_data.get("phase", 0.0)),
			"overscan": float(layer_data.get("overscan", 48.0)),
		})

	if not resized.is_connected(_layout_parallax_background):
		resized.connect(_layout_parallax_background)

	_layout_parallax_background()
	_update_background_parallax(0.0)


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


# ---- News panel ----
# Fetches GET <api-base>/news from the server (see server_phase11a_runtime.ts) and renders
# the returned entries into NewsPanel/NewsScroll/NewsList. The server reads its news.json
# fresh on every request, so editing that file on the server updates what players see here
# with no client rebuild and no server restart required.

func _get_news_api_base() -> String:
	var network = _get_network_manager()
	if network != null and "active_api_base" in network:
		var configured_base := str(network.get("active_api_base")).strip_edges()
		if configured_base != "":
			return configured_base
	return NEWS_FALLBACK_API_BASE


func _fetch_login_news() -> void:
	if news_list_root == null:
		return

	if empty_news_label != null:
		empty_news_label.visible = true
		empty_news_label.text = "Loading news..."

	var api_base := _get_news_api_base()
	var url := api_base + NEWS_API_PATH

	var request := HTTPRequest.new()
	request.name = "LoginNewsRequest"
	request.timeout = NEWS_REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error := request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		push_warning("[LoginNews] Could not start news request. error=%s" % str(error))
		_render_login_news([])
		return

	var response = await request.request_completed
	if not is_instance_valid(request):
		return
	request.queue_free()

	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		response_code = int(response[1])
		body = response[3]

	if response_code != 200:
		push_warning("[LoginNews] News request failed. status=%d" % response_code)
		_render_login_news([])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		push_warning("[LoginNews] News response was rejected or invalid.")
		_render_login_news([])
		return

	var entries: Array = parsed.get("entries", [])
	if not (entries is Array):
		entries = []
	_render_login_news(entries)


func _render_login_news(entries: Array) -> void:
	if news_list_root == null:
		return

	for child in news_list_root.get_children():
		child.queue_free()

	if entries.is_empty():
		if empty_news_label != null:
			empty_news_label.visible = true
			empty_news_label.text = "No news yet."
		return

	if empty_news_label != null:
		empty_news_label.visible = false

	for raw_entry in entries.slice(0, NEWS_MAX_ENTRIES):
		if not (raw_entry is Dictionary):
			continue
		_create_news_entry_row(raw_entry)


func _create_news_entry_row(entry: Dictionary) -> void:
	var date_text := str(entry.get("date", "")).strip_edges()
	var title_text := str(entry.get("title", "")).strip_edges()
	var body_text := str(entry.get("body", "")).strip_edges()
	if title_text == "" and body_text == "":
		return

	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	news_list_root.add_child(row)

	if title_text != "" or date_text != "":
		var header := Label.new()
		header.text = "[%s] %s" % [date_text, title_text] if date_text != "" else title_text
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
		header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		header.add_theme_constant_override("shadow_offset_x", 2)
		header.add_theme_constant_override("shadow_offset_y", 2)
		header.add_theme_font_size_override("font_size", 15)
		row.add_child(header)

	if body_text != "":
		var body_label := Label.new()
		body_label.text = body_text
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.92))
		body_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		body_label.add_theme_constant_override("shadow_offset_x", 1)
		body_label.add_theme_constant_override("shadow_offset_y", 1)
		body_label.add_theme_font_size_override("font_size", 13)
		row.add_child(body_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	row.add_child(spacer)


func _layout_parallax_background() -> void:
	if parallax_background == null:
		return

	var viewport_size := get_viewport_rect().size

	for layer_entry in parallax_layers:
		var layer = layer_entry.get("node", null)
		if layer == null or not is_instance_valid(layer):
			continue

		var margin := float(layer_entry.get("overscan", 48.0))
		var base_position := Vector2(-margin, -margin)
		layer.position = base_position
		layer.size = viewport_size + Vector2(margin * 2.0, margin * 2.0)
		layer_entry["base_position"] = base_position


func _update_background_parallax(delta: float) -> void:
	if parallax_background == null or parallax_layers.is_empty():
		return

	parallax_time += delta

	for layer_entry in parallax_layers:
		var layer = layer_entry.get("node", null)
		if layer == null or not is_instance_valid(layer):
			continue

		var base_position = layer_entry.get("base_position", Vector2.ZERO)
		if not (base_position is Vector2):
			base_position = Vector2.ZERO

		var drift = layer_entry.get("drift", Vector2.ZERO)
		if not (drift is Vector2):
			drift = Vector2.ZERO

		var speed := float(layer_entry.get("speed", 0.0))
		var phase := float(layer_entry.get("phase", 0.0))
		var wave_x: float = sin((parallax_time * speed) + phase) * drift.x
		layer.position = base_position + Vector2(wave_x, 0.0)


func _load_saved_account() -> void:
	loading_saved_account = true
	var cfg := ConfigFile.new()
	var err := cfg.load(profile_path)
	if err == OK:
		var username = str(cfg.get_value("profile", "username", ""))
		saved_session_username = username.strip_edges()
		saved_session_email = str(cfg.get_value("profile", "email", "")).strip_edges()
		username_input.text = username
		email_input.text = saved_session_email
		var remember_login = bool(cfg.get_value("profile", "remember_login", cfg.get_value("profile", "remember_password", false)))
		remember_password_check.button_pressed = remember_login
		saved_session_token = str(cfg.get_value("profile", "session_token", "")).strip_edges() if remember_login else ""
		saved_refresh_token = str(cfg.get_value("profile", "refresh_token", "")).strip_edges() if remember_login else ""
		saved_session_role = str(cfg.get_value("profile", "role", "player")).strip_edges().to_lower()
		password_input.text = ""
		_update_saved_login_password_placeholder()
		_clear_local_password_cache(cfg)
		cfg.set_value("profile", "remember_login", remember_login)
		if not remember_login:
			cfg.set_value("profile", "session_token", "")
			cfg.set_value("profile", "refresh_token", "")
		cfg.save(profile_path)

		if email_input.text.strip_edges() == "" and account_manager != null and account_manager.has_method("get_email_for_username"):
			email_input.text = account_manager.get_email_for_username(username)
	loading_saved_account = false


func _on_username_submitted(_text: String) -> void:
	if email_input.text.strip_edges() == "":
		email_input.grab_focus()
	else:
		password_input.grab_focus()


func _on_email_submitted(_text: String) -> void:
	password_input.grab_focus()


func _on_password_submitted(_text: String) -> void:
	_on_sign_on_pressed()


func _on_remember_login_toggled(enabled: bool) -> void:
	if loading_saved_account or enabled:
		return
	if saved_session_token != "" or saved_refresh_token != "":
		_clear_remembered_login_tokens()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_reset_email_pressed() -> void:
	if auth_busy:
		return

	var username := username_input.text.strip_edges()
	var new_email := email_input.text.strip_edges()
	var password := password_input.text

	var validation = _validate_email_change_input(username, new_email, password)
	if not bool(validation.get("ok", false)):
		_show_message(str(validation.get("message", "Could not start email change.")))
		return

	_clear_network_login_notice()
	auth_busy = true
	_show_message("Sending email change confirmation...")

	var connected_ok = await _wait_for_server_connection()
	if not connected_ok:
		auth_busy = false
		_show_message(_server_connection_failed_message())
		return

	var network = _get_network_manager()
	if network == null or not network.has_method("send_account_email_change_request"):
		auth_busy = false
		_show_message("Server account system not ready.")
		return

	var request_id = str(network.send_account_email_change_request(username, new_email, password))
	if request_id == "":
		auth_busy = false
		_show_message("Could not contact server.")
		return

	var result = await _wait_for_auth_response(request_id, 10.0)
	auth_busy = false
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not start email change.")))
		return

	password_input.text = ""
	_show_message(str(result.get("message", "Check your new email to confirm the change.")))


func _on_reset_password_pressed() -> void:
	if auth_busy:
		return

	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()

	var validation = _validate_password_reset_input(username, email)
	if not bool(validation.get("ok", false)):
		_show_message(str(validation.get("message", "Could not start password reset.")))
		return

	_clear_network_login_notice()
	auth_busy = true
	_show_message("Sending password reset email...")

	var connected_ok = await _wait_for_server_connection()
	if not connected_ok:
		auth_busy = false
		_show_message(_server_connection_failed_message())
		return

	var network = _get_network_manager()
	if network == null or not network.has_method("send_account_password_reset_request"):
		auth_busy = false
		_show_message("Server account system not ready.")
		return

	var request_id = str(network.send_account_password_reset_request(username, email))
	if request_id == "":
		auth_busy = false
		_show_message("Could not contact server.")
		return

	var result = await _wait_for_auth_response(request_id, 10.0)
	auth_busy = false
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("message", "Could not start password reset.")))
		return

	password_input.text = ""
	_show_message(str(result.get("message", "If that account matches, I sent a password reset email.")))


func _on_server_auth_finished(data) -> void:
	if not (data is Dictionary):
		return

	var request_id = str(data.get("request_id", "")).strip_edges()
	if pending_auth_request_id == "" and bool(data.get("ok", false)) and _should_enter_netfox_launch_world_after_login():
		call_deferred("_try_enter_authenticated_netfox_launch_world", data.duplicate(true))
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


func _validate_password_reset_input(username: String, email: String) -> Dictionary:
	if account_manager == null:
		return {"ok": false, "message": "Account system not ready."}

	var username_validation = account_manager.validate_username(username)
	if not bool(username_validation.get("ok", false)):
		return username_validation

	var email_validation = account_manager.validate_email(email)
	if not bool(email_validation.get("ok", false)):
		return email_validation

	return {"ok": true}


func _validate_email_change_input(username: String, new_email: String, password: String) -> Dictionary:
	if account_manager == null:
		return {"ok": false, "message": "Account system not ready."}

	var username_validation = account_manager.validate_username(username)
	if not bool(username_validation.get("ok", false)):
		return username_validation

	var email_validation = account_manager.validate_email(new_email)
	if not bool(email_validation.get("ok", false)):
		return email_validation

	var password_validation = account_manager.validate_password(password)
	if not bool(password_validation.get("ok", false)):
		return {"ok": false, "message": "Enter your current password."}

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
	var refresh_token = str(result.get("refresh_token", ""))
	var role = str(result.get("role", "player"))
	if session_token == "":
		_show_message("Check your email to verify this account before signing on.")
		return

	_cache_server_account(server_username, server_email)
	_save_active_account(server_username, server_email, session_token, role, refresh_token)
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
	var used_saved_login := false

	var email_matches_saved = email == "" or email.to_lower() == saved_session_email.to_lower()
	var has_saved_login := saved_refresh_token != "" or saved_session_token != ""
	if password == "" and has_saved_login and username.to_lower() == saved_session_username.to_lower() and email_matches_saved:
		request_id = _send_saved_login_request(network, username)
		used_saved_login = request_id != ""
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
		if used_saved_login and _saved_login_error_requires_clear(result):
			_clear_remembered_login_tokens()
		_show_message(str(result.get("message", "Could not sign on.")))
		return

	if bool(result.get("requires_email_verification", false)):
		_show_message(str(result.get("message", "Verify your email before signing on.")))
		return

	var server_username = str(result.get("username", username))
	var server_email = str(result.get("email", ""))
	var session_token = str(result.get("session_token", ""))
	var refresh_token = str(result.get("refresh_token", ""))
	if refresh_token == "" and used_saved_login:
		refresh_token = saved_refresh_token
	var role = str(result.get("role", "player"))
	if session_token == "":
		_show_message("Verify your email before signing on.")
		return

	_cache_server_account(server_username, server_email)
	_save_active_account(server_username, server_email, session_token, role, refresh_token)
	password_input.text = ""
	if _should_enter_netfox_launch_world_after_login():
		await _try_enter_authenticated_netfox_launch_world({
			"username": server_username,
			"email": server_email,
			"role": role,
		})
		return
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _save_active_account(username: String, email: String, token: String, role: String = "player", refresh_token: String = "") -> void:
	_set_network_session(username, email, token, role)

	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	var should_remember_login = remember_password_check != null and remember_password_check.button_pressed
	cfg.set_value("profile", "username", username)
	cfg.set_value("profile", "email", email)
	cfg.set_value("profile", "session_token", token if should_remember_login else "")
	cfg.set_value("profile", "refresh_token", refresh_token if should_remember_login else "")
	cfg.set_value("profile", "role", role)
	cfg.set_value("profile", "remember_login", should_remember_login)
	_clear_local_password_cache(cfg)
	cfg.save(profile_path)
	saved_session_username = username
	saved_session_email = email
	saved_session_token = token if should_remember_login else ""
	saved_refresh_token = refresh_token if should_remember_login else ""
	saved_session_role = role
	_update_saved_login_password_placeholder()


func _send_saved_login_request(network, username: String) -> String:
	if network == null:
		return ""
	if saved_refresh_token != "" and network.has_method("send_account_refresh_token_login"):
		return str(network.send_account_refresh_token_login(username, saved_refresh_token))
	if saved_session_token != "" and network.has_method("send_account_token_login"):
		return str(network.send_account_token_login(username, saved_session_token))
	return ""


func _saved_login_error_requires_clear(result: Dictionary) -> bool:
	var reason := str(result.get("reason", "")).strip_edges().to_lower()
	return ["missing_token", "invalid_or_expired", "invalid_refresh_token", "invalid_account_state"].has(reason)


func _clear_remembered_login_tokens() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	cfg.set_value("profile", "session_token", "")
	cfg.set_value("profile", "refresh_token", "")
	cfg.set_value("profile", "remember_login", false)
	_clear_local_password_cache(cfg)
	cfg.save(profile_path)
	saved_session_token = ""
	saved_refresh_token = ""
	if remember_password_check != null:
		remember_password_check.button_pressed = false
	_update_saved_login_password_placeholder()


func _update_saved_login_password_placeholder() -> void:
	if password_input == null:
		return
	var has_saved_login := saved_refresh_token != "" or saved_session_token != ""
	password_input.placeholder_text = "Saved login ready" if has_saved_login else "Password"


func _should_enter_netfox_launch_world_after_login() -> bool:
	return MovementMode.is_netfox_real_launch_requested() and MovementMode.has_method("is_netfox_real_client_launch") and MovementMode.is_netfox_real_client_launch() and MovementMode.get_launch_arg_value("--world", "").strip_edges() != ""


func _try_enter_authenticated_netfox_launch_world(auth_data: Dictionary = {}) -> void:
	if netfox_launch_scene_change_in_progress or not is_inside_tree():
		return
	if not _should_enter_netfox_launch_world_after_login():
		return

	var network = _get_network_manager()
	if network == null or not network.has_method("is_server_session_authenticated"):
		return
	if not bool(network.is_server_session_authenticated()):
		return

	var username := str(auth_data.get("username", saved_session_username)).strip_edges()
	if username == "" and network.has_method("get_active_session_username"):
		username = str(network.get_active_session_username()).strip_edges()
	var email := str(auth_data.get("email", saved_session_email)).strip_edges()
	if email == "" and network.has_method("get_active_session_email"):
		email = str(network.get_active_session_email()).strip_edges()
	var role := str(auth_data.get("role", saved_session_role)).strip_edges()
	if role == "":
		role = "player"
	if username == "":
		push_error("[WorldJoinHandoff] Authenticated session has no username; refusing world transition.")
		return

	netfox_launch_scene_change_in_progress = true
	var handoff_started_at := Time.get_ticks_msec()
	_prepare_authenticated_netfox_launch_world(username, email, role)
	print("[WorldJoinHandoff] Authenticated launch handoff started.")

	var world_scene: PackedScene = await _wait_for_preloaded_world_scene()
	if not is_inside_tree():
		return
	if world_scene == null:
		netfox_launch_scene_change_in_progress = false
		_show_message("Could not load the world scene. Try again.")
		return

	print("[WorldJoinHandoff] World scene ready elapsed_ms=%.3f" % float(Time.get_ticks_msec() - handoff_started_at))
	# Unlike the LOBBY_SCENE transitions above, this path enters the world directly and
	# skips the lobby menu entirely -- the menu loop should stop here, it won't be picked
	# back up by a lobby _ready() the way it would on the normal login -> lobby path.
	if MusicManager != null and MusicManager.has_method("stop_login_loop"):
		MusicManager.stop_login_loop()
	var change_error := get_tree().change_scene_to_packed(world_scene)
	if change_error != OK:
		netfox_launch_scene_change_in_progress = false
		push_error("[WorldJoinHandoff] World scene transition failed with error %d." % change_error)
		_show_message("Could not enter the world. Try again.")
		# Scene change didn't happen -- we're still on the login screen, so resume the loop
		# instead of leaving it stopped.
		if MusicManager != null and MusicManager.has_method("start_login_loop"):
			MusicManager.start_login_loop()


func _wait_for_preloaded_world_scene() -> PackedScene:
	var start_error: Error = WorldScenePreloader.start()
	if start_error != OK:
		push_error("[WorldJoinHandoff] Could not start world preload: %d." % start_error)
		return null

	var deadline_msec := Time.get_ticks_msec() + 15000
	while is_inside_tree() and Time.get_ticks_msec() < deadline_msec:
		WorldScenePreloader.pump()
		if WorldScenePreloader.is_ready():
			return WorldScenePreloader.get_loaded_scene()
		var load_error: Error = WorldScenePreloader.get_last_error()
		if load_error != OK:
			push_error("[WorldJoinHandoff] World preload failed with error %d." % load_error)
			return null
		await get_tree().process_frame

	push_error("[WorldJoinHandoff] Timed out waiting for the preloaded world scene.")
	return null


func _prepare_authenticated_netfox_launch_world(username: String, email: String, role: String = "player") -> void:
	var world_name := MovementMode.get_dev_test_world_name("NETFOX_TEST")
	var network = _get_network_manager()
	if network != null:
		if network.has_method("set_pending_join"):
			network.set_pending_join(world_name, username)
		network.set("current_world_name", world_name)
	var remember_login := saved_refresh_token != "" or saved_session_token != ""
	_write_pending_join_profile_config(world_name, username, email, saved_session_token, remember_login, role, saved_refresh_token)
	print("[NetfoxReal] Authenticated launch entering %s as %s." % [world_name, username])


func _clear_local_password_cache(cfg: ConfigFile) -> void:
	cfg.set_value("profile", "remember_password", false)
	cfg.set_value("profile", "saved_password", "")
	cfg.set_value("profile", "password", "")


func _set_network_session(username: String, email: String, token: String, role: String = "player") -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("set_active_session"):
		network.set_active_session(username, email, token, role)


func _show_message(text: String) -> void:
	if message_label == null or not is_instance_valid(message_label):
		print("[BackendDevLogin] " + text)
		return
	message_label.text = text
