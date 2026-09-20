extends CanvasLayer

# Blocking "you must update" gate.
#
# The server refuses every packet from an out-of-date build
# (server.ts -> isClientVersionAllowed / sendClientUpdateRequired) and also
# advertises `min_client_version` / `update_url` on the `connected` packet, so
# the client knows it is stale the moment its socket opens. NetworkManager
# latches that payload, ejects the player back to the login screen, and emits
# `client_update_required`; this autoload turns it into a full-screen gate with
# a store button so players are not left staring at a dead login screen.
#
# This is deliberately UI-only: it never mutates session, world or inventory
# state, and it never sends packets.

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

# Must match export_presets.cfg "package/unique_name".
const ANDROID_PACKAGE_NAME := "com.pixelmaniagame.pixelmania"
const PLAY_STORE_APP_URL := "market://details?id=" + ANDROID_PACKAGE_NAME
const PLAY_STORE_WEB_URL := "https://play.google.com/store/apps/details?id=" + ANDROID_PACKAGE_NAME
# Set once the App Store listing exists; until then iOS falls through to the
# server's update_url and then the website.
const IOS_APP_STORE_ID := ""
const DESKTOP_DOWNLOAD_URL := "https://api.pixelmaniagame.com/downloads/PixelManiaLauncher.exe"
const FALLBACK_UPDATE_URL := "https://pixelmaniagame.com"

var root_control: Control = null
var message_label: Label = null
var version_label: Label = null
var instruction_label: Label = null
var update_button: Button = null
var exit_button: Button = null
var hint_label: Label = null
var active_payload: Dictionary = {}
var _network = null
var _store_open_attempted := false
var _update_check: HTTPRequest


func _installed_version() -> String:
	if _platform_kind() == "android" and Engine.has_singleton("AndroidRuntime"):
		var runtime = Engine.get_singleton("AndroidRuntime")
		var context = runtime.getApplicationContext()
		var info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0)
		if info != null:
			return str(info.versionName)
	return str(_network.CLIENT_VERSION) if _network != null else ""


func _check_release() -> void:
	if _platform_kind() != "android" or OS.has_feature("editor"):
		return
	_update_check = HTTPRequest.new()
	_update_check.timeout = 15.0
	_update_check.body_size_limit = 65536
	_update_check.max_redirects = 0
	add_child(_update_check)
	_update_check.request_completed.connect(_on_release_checked)
	_update_check.request(str(_network.active_api_base).trim_suffix("/") + "/client/android-manifest")


func _on_release_checked(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		return # The existing server version gate still enforces compatibility.
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not bool(data.get("published", false)):
		return
	var minimum := str(data.get("min_client_version", ""))
	var current := _installed_version()
	if minimum.is_empty() or current.is_empty() or _network._compare_client_versions(current, minimum) >= 0:
		return
	_network._store_client_update_payload({
		"client_version": current, "min_client_version": minimum,
		"update_url": PLAY_STORE_WEB_URL,
		"message": "A new PixelMania update is ready on Google Play. Update to keep playing."
	})


func _ready() -> void:
	layer = 512
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_network = get_node_or_null("/root/NetworkManager")
	if _network == null:
		return

	if _network.has_signal("client_update_required"):
		_network.client_update_required.connect(_on_client_update_required)

	# The packet can land before this autoload is ready (NetworkManager is
	# registered first), so pick up an already latched payload.
	if _network.has_method("get_client_update_payload"):
		var latched: Dictionary = _network.get_client_update_payload()
		if not latched.is_empty():
			_on_client_update_required(latched)
	call_deferred("_check_release")


func _on_client_update_required(payload: Dictionary) -> void:
	active_payload = payload.duplicate(true) if payload is Dictionary else {}
	_ensure_built()
	_refresh_text()
	visible = true
	if root_control != null:
		root_control.visible = true
	if _platform_kind() == "android" and not _store_open_attempted:
		_store_open_attempted = true
		call_deferred("_on_update_pressed")


func is_gate_visible() -> bool:
	return visible


func _ensure_built() -> void:
	if root_control != null and is_instance_valid(root_control):
		return

	root_control = Control.new()
	root_control.name = "UpdateGate"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root_control)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.02, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(dim)

	var centerer := CenterContainer.new()
	centerer.name = "Centerer"
	centerer.set_anchors_preset(Control.PRESET_FULL_RECT)
	centerer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(centerer)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	panel.custom_minimum_size = Vector2(560, 0)
	centerer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "NEW UPDATE IS LIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUIStyle.apply_section_title(title)
	column.add_child(title)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(490, 0)
	PixelUIStyle.apply_label_shadow(message_label)
	column.add_child(message_label)

	version_label = Label.new()
	version_label.name = "VersionLabel"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUIStyle.apply_small_label(version_label, 16)
	column.add_child(version_label)

	instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.custom_minimum_size = Vector2(490, 0)
	instruction_label.visible = false
	PixelUIStyle.apply_small_label(instruction_label, 17)
	column.add_child(instruction_label)

	update_button = Button.new()
	update_button.name = "UpdateButton"
	update_button.text = "UPDATE NOW"
	update_button.custom_minimum_size = Vector2(0, 62)
	update_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(update_button, 26)
	update_button.pressed.connect(_on_update_pressed)
	column.add_child(update_button)

	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = false
	PixelUIStyle.apply_small_label(hint_label, 15)
	column.add_child(hint_label)

	exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "EXIT GAME"
	exit_button.custom_minimum_size = Vector2(0, 52)
	exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(exit_button, 22)
	exit_button.pressed.connect(_on_exit_pressed)
	column.add_child(exit_button)


func _refresh_text() -> void:
	if message_label != null:
		var message := str(active_payload.get("message", "")).strip_edges()
		if message == "":
			message = "A new PixelMania update is live. Update your client to keep playing."
		message_label.text = message

	if version_label != null:
		var current := str(active_payload.get("client_version", "")).strip_edges()
		var required := str(active_payload.get("min_client_version", "")).strip_edges()
		var parts := PackedStringArray()
		if current != "":
			parts.append("Your version: " + current)
		if required != "":
			parts.append("Required: " + required)
		version_label.text = "   -   ".join(parts)
		version_label.visible = not parts.is_empty()

	if hint_label != null:
		hint_label.visible = false

	var platform := _platform_kind()

	if update_button != null:
		match platform:
			"android":
				update_button.text = "UPDATE ON GOOGLE PLAY"
			"ios":
				update_button.text = "UPDATE ON THE APP STORE"
			_:
				update_button.text = "OPEN LAUNCHER" if not _launcher_path().is_empty() else "GET PC LAUNCHER"

	if instruction_label != null:
		if platform == "desktop":
			instruction_label.text = "Open the PixelMania Launcher to download the update, then press Play. Your account and progress are kept."
			instruction_label.visible = true
		else:
			instruction_label.text = ""
			instruction_label.visible = false


func _platform_kind() -> String:
	var os_name := OS.get_name().to_lower()
	if OS.has_feature("android") or os_name == "android":
		return "android"
	if OS.has_feature("ios") or os_name == "ios":
		return "ios"
	return "desktop"


# Order of preference per platform. Every list ends at the website so the button
# always does something, even if the server sent no update_url.
#   Android -> market:// deep link (opens the Play Store app directly), then the
#              https Play listing if the store app is missing.
#   iOS     -> the App Store listing once IOS_APP_STORE_ID is filled in.
#   Desktop -> the download page, since PC builds cannot self-update.
func _build_update_urls() -> Array[String]:
	var urls: Array[String] = []
	var server_url := str(active_payload.get("update_url", "")).strip_edges()

	match _platform_kind():
		"android":
			urls.append(PLAY_STORE_APP_URL)
			urls.append(PLAY_STORE_WEB_URL)
			return urls
		"ios":
			var ios_id := str(IOS_APP_STORE_ID).strip_edges()
			if ios_id != "":
				urls.append("itms-apps://itunes.apple.com/app/id" + ios_id)
				urls.append("https://apps.apple.com/app/id" + ios_id)
		_:
			urls.append(DESKTOP_DOWNLOAD_URL)

	if server_url != "" and not urls.has(server_url):
		urls.append(server_url)
	if not urls.has(FALLBACK_UPDATE_URL):
		urls.append(FALLBACK_UPDATE_URL)

	return urls


func _on_update_pressed() -> void:
	if _platform_kind() == "desktop":
		var launcher := _launcher_path()
		if not launcher.is_empty() and OS.create_process(launcher, []) > 0:
			get_tree().quit()
			return
	var opened := false
	var attempted := PackedStringArray()
	for url in _build_update_urls():
		attempted.append(str(url))
		if _open_update_url(str(url)) == OK:
			opened = true
			break

	if opened:
		return

	push_warning("[ClientUpdateGate] Could not open any update URL: " + ", ".join(attempted))
	if hint_label != null:
		var shown := ""
		match _platform_kind():
			"android":
				shown = PLAY_STORE_WEB_URL
			"desktop":
				shown = DESKTOP_DOWNLOAD_URL
			_:
				shown = str(active_payload.get("update_url", "")).strip_edges()
		if shown == "":
			shown = FALLBACK_UPDATE_URL
		hint_label.text = "Could not open the page. Update manually at:\n" + shown
		hint_label.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()


func _open_update_url(url: String) -> Error:
	return OS.shell_open(url)


func _launcher_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pixelmania-launcher="):
			var path := argument.trim_prefix("--pixelmania-launcher=")
			if path.is_absolute_path() and path.get_file().to_lower() == "pixelmanialauncher.exe" and FileAccess.file_exists(path):
				return path
	var adjacent := OS.get_executable_path().get_base_dir().path_join("PixelManiaLauncher.exe")
	return adjacent if FileAccess.file_exists(adjacent) else ""
