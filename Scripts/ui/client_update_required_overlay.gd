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
const DESKTOP_DOWNLOAD_URL := "https://pixelmaniagame.com/#downloads"
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


func _on_client_update_required(payload: Dictionary) -> void:
	active_payload = payload.duplicate(true) if payload is Dictionary else {}
	_ensure_built()
	_refresh_text()
	visible = true
	if root_control != null:
		root_control.visible = true


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
				update_button.text = "DOWNLOAD LATEST VERSION"

	if instruction_label != null:
		if platform == "desktop":
			instruction_label.text = "Desktop builds do not update themselves. Download the latest PixelMania installer and run it over your current install."
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
			if server_url.begins_with("market://"):
				urls.append(server_url)
			urls.append(PLAY_STORE_APP_URL)
			if server_url != "" and server_url.contains("play.google.com"):
				urls.append(server_url)
			urls.append(PLAY_STORE_WEB_URL)
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
	var opened := false
	var attempted := PackedStringArray()
	for url in _build_update_urls():
		attempted.append(str(url))
		if OS.shell_open(str(url)) == OK:
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
