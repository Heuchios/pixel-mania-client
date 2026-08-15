extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const WINDOW_SIZE := Vector2(1120.0, 680.0)
const ACCESS_LOOKUP_TIMEOUT_MS := 15000
const WORLD_LOCK_ROLE_OPTIONS := ["ADMIN", "BUILDER", "VISITOR"]
const DEFAULT_WORLD_LOCK_ROLE := "BUILDER"
const WORLD_LOCK_KEY_ITEM_ID := "world_lock_key"
const WORLD_LOCK_KEY_CATEGORY := "material"

const CLOSE_BUTTON_TEXTURE = preload("res://Assets/ui/pixelmania/close_button.png")
const BUTTON_YELLOW_NORMAL = preload("res://Assets/ui/pixelmania/button_normal.png")
const BUTTON_YELLOW_PRESSED = preload("res://Assets/ui/pixelmania/button_pressed.png")
const BUTTON_YELLOW_HOVER = preload("res://Assets/ui/pixelmania/button_hover.png")
const BUTTON_BLUE_NORMAL = preload("res://Assets/ui/inventory/button_blue_normal.png")
const BUTTON_BLUE_PRESSED = preload("res://Assets/ui/inventory/button_blue_pressed.png")
const BUTTON_BLUE_HOVER = preload("res://Assets/ui/inventory/button_blue_hover.png")
const TAB_NORMAL_TEXTURE = preload("res://Assets/ui/inventory/tab_normal.png")
const TAB_SELECTED_TEXTURE = preload("res://Assets/ui/inventory/tab_selected.png")
# Same green button kit WorldLockGUI.tscn itself uses for GetKeyButton / PublicBuildButton /
# SetLimitButton / AddAccessButton, so runtime-styled buttons (dynamically-created member row
# buttons, the confirm popup) match the scene's authored look instead of the old yellow/blue/red
# "arcade" palette.
const BUTTON_GREEN_NORMAL = preload("res://Assets/ui/green_button_normal_90x24.png")
const BUTTON_GREEN_PRESSED = preload("res://Assets/ui/green_button_pressed_90x24.png")
const BUTTON_GREEN_HOVER = preload("res://Assets/ui/green_button_hover_90x24.png")

var world = null
var ui_layer_ref = null
var target_grid_pos: Vector2i = Vector2i.ZERO
var menu_open := false
var confirm_panel: Panel = null
var confirm_blocker: ColorRect = null
var _pending_access_check_request_id := ""
var _pending_access_check_name := ""
var _pending_access_check_role := ""
var _access_check_timeout_deadline_ms := 0

@onready var backdrop: ColorRect = $Backdrop
@onready var dimmer: ColorRect = $Dimmer
@onready var window: Control = $Window
@onready var title_label: Label = $Window/TitleLabel
@onready var subtitle_label: Label = get_node_or_null("Window/SubtitleLabel") as Label
@onready var lock_label: Label = get_node_or_null("Window/LockLabel") as Label
@onready var lock_badge: Button = $Window/LockBadge
@onready var get_key_button: Button = get_node_or_null("Window/GetKeyButton") as Button
@onready var close_button: Button = $Window/CloseButton
@onready var world_info_tab: Button = get_node_or_null("Window/Tabs/WorldInfoTab") as Button
@onready var access_list_tab: Button = get_node_or_null("Window/Tabs/AccessListTab") as Button
@onready var owner_actions_tab: Button = get_node_or_null("Window/Tabs/OwnerActionsTab") as Button
@onready var lock_icon_shadow: TextureRect = $Window/LockIconShadow
@onready var lock_icon: TextureRect = $Window/LockIcon
@onready var world_label: Label = $Window/WorldLabel
@onready var locked_label: Label = $Window/LockedLabel
@onready var owner_label: Label = $Window/OwnerLabel
@onready var status_label: Label = $Window/StatusLabel
@onready var position_label: Label = $Window/PositionLabel
@onready var access_title: Label = $Window/AccessTitle
@onready var actions_title: Label = $Window/ActionsTitle
@onready var access_scroll: ScrollContainer = $Window/AccessCard/AccessScroll
@onready var member_list_root: VBoxContainer = $Window/AccessCard/AccessScroll/AccessList
@onready var empty_access_label: Label = $Window/AccessCard/EmptyAccessLabel
@onready var public_button: Button = $Window/ActionsCard/PublicBuildButton
@onready var slot_limit_label: Label = $Window/ActionsCard/LimitLabel
@onready var slot_limit_input: LineEdit = $Window/ActionsCard/LimitField/LimitInput
@onready var set_slot_limit_button: Button = $Window/ActionsCard/SetLimitButton
@onready var add_label: Label = $Window/ActionsCard/AddPlayerLabel
@onready var add_input: LineEdit = $Window/ActionsCard/UsernameField/UsernameInput
@onready var add_role_picker: OptionButton = $Window/ActionsCard/RolePicker
@onready var add_button: Button = $Window/ActionsCard/AddAccessButton
@onready var hint_label: Label = $Window/ActionsCard/HintLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 160
	visible = false
	window.pivot_offset = WINDOW_SIZE * 0.5
	_apply_texture_filter(self)
	_configure_static_ui()
	_fit_window_to_viewport()
	close_world_lock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		call_deferred("_fit_window_to_viewport")


func _process(_delta: float) -> void:
	if not menu_open:
		return
	_process_access_lookup_timeout()


func setup(parent_world, ui_node) -> void:
	world = parent_world
	ui_layer_ref = ui_node
	_sync_lock_icon_textures()
	if menu_open:
		refresh()


func _configure_static_ui() -> void:
	backdrop.visible = false
	dimmer.visible = false
	window.visible = false
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	window.mouse_filter = Control.MOUSE_FILTER_STOP

	PixelUIStyle.apply_label_shadow(title_label, 46)
	if subtitle_label != null:
		PixelUIStyle.apply_small_label(subtitle_label, 14)
	if lock_label != null:
		PixelUIStyle.apply_label_shadow(lock_label, 25)
	PixelUIStyle.apply_label_shadow(world_label, 20)
	PixelUIStyle.apply_label_shadow(locked_label, 20)
	PixelUIStyle.apply_label_shadow(owner_label, 18)
	PixelUIStyle.apply_label_shadow(status_label, 16)
	PixelUIStyle.apply_small_label(position_label, 13)
	PixelUIStyle.apply_label_shadow(access_title, 24, Color.WHITE)
	PixelUIStyle.apply_label_shadow(actions_title, 24, Color.WHITE)
	PixelUIStyle.apply_small_label(slot_limit_label, 12)
	PixelUIStyle.apply_small_label(add_label, 12)
	PixelUIStyle.apply_small_label(hint_label, 12)
	PixelUIStyle.apply_small_label(empty_access_label, 15)

	# CloseButton already has its own normal/pressed/hover textures authored directly in
	# WorldLockGUI.tscn -- don't override them with a different close-button asset here.
	apply_world_lock_tab_style(world_info_tab, true, 13)
	apply_world_lock_tab_style(access_list_tab, false, 13)
	apply_world_lock_tab_style(owner_actions_tab, false, 13)
	apply_world_lock_arcade_button_style(lock_badge, true, false, 18)
	apply_world_lock_arcade_button_style(get_key_button, true, false, 14)
	apply_world_lock_arcade_button_style(public_button, false, false, 18)
	apply_world_lock_arcade_button_style(set_slot_limit_button, true, false, 13)
	apply_world_lock_arcade_button_style(add_role_picker, false, false, 13)
	apply_world_lock_arcade_button_style(add_button, true, false, 18)

	apply_world_lock_input_style(slot_limit_input, 16)
	apply_world_lock_input_style(add_input, 16)
	apply_world_lock_scrollbar_style(access_scroll)

	lock_badge.focus_mode = Control.FOCUS_NONE
	lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_key_button != null:
		get_key_button.focus_mode = Control.FOCUS_NONE
	if world_info_tab != null:
		world_info_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if access_list_tab != null:
		access_list_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owner_actions_tab != null:
		owner_actions_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_role_picker.clear()
	for role_index in range(WORLD_LOCK_ROLE_OPTIONS.size()):
		add_role_picker.add_item(WORLD_LOCK_ROLE_OPTIONS[role_index], role_index)
	add_role_picker.selected = WORLD_LOCK_ROLE_OPTIONS.find(DEFAULT_WORLD_LOCK_ROLE)

	close_button.pressed.connect(close_world_lock)
	if get_key_button != null:
		get_key_button.pressed.connect(_on_get_key_pressed)
	public_button.pressed.connect(_on_public_build_pressed)
	set_slot_limit_button.pressed.connect(_on_set_slot_limit_pressed)
	slot_limit_input.text_submitted.connect(_on_slot_limit_text_submitted)
	add_input.text_submitted.connect(_on_add_text_submitted)
	add_button.pressed.connect(_on_add_access_pressed)

	_sync_lock_icon_textures()


func _fit_window_to_viewport() -> void:
	if not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		window.scale = Vector2.ONE
	else:
		var scale_amount := minf(
			1.0,
			minf((viewport_size.x - 24.0) / WINDOW_SIZE.x, (viewport_size.y - 24.0) / WINDOW_SIZE.y)
		)
		window.scale = Vector2.ONE * clampf(scale_amount, 0.28, 1.0)
	if confirm_panel != null and is_instance_valid(confirm_panel):
		confirm_panel.position = (viewport_size - confirm_panel.size) * 0.5


func _process_access_lookup_timeout() -> void:
	if _pending_access_check_request_id == "":
		return
	if Time.get_ticks_msec() < _access_check_timeout_deadline_ms:
		return
	var pending_name := _pending_access_check_name
	_clear_access_lookup_wait()
	show_result({
		"ok": false,
		"message": "Lookup timed out for " + pending_name + ". Player may be offline, but the account must exist in the database."
	})


func get_manager():
	if world == null:
		return null
	return world.world_lock_manager


func _sync_lock_icon_textures() -> void:
	var icon_texture = get_world_lock_icon_texture()
	lock_icon.texture = icon_texture
	lock_icon_shadow.texture = icon_texture
	lock_badge.icon = icon_texture


func open_world_lock(grid_pos: Vector2i) -> void:
	target_grid_pos = grid_pos
	menu_open = true
	visible = true
	dimmer.visible = true
	window.visible = true
	clear_confirmation_popup()
	_fit_window_to_viewport()
	refresh()
	PixelUIStyle.play_panel_open(window)


func close_world_lock() -> void:
	menu_open = false
	_clear_access_lookup_wait()
	clear_confirmation_popup()
	if add_input != null:
		add_input.release_focus()
	if slot_limit_input != null:
		slot_limit_input.release_focus()
	window.visible = false
	dimmer.visible = false
	visible = false


func is_open() -> bool:
	return menu_open


func is_world_lock_open() -> bool:
	return is_open()


func refresh() -> void:
	var manager = get_manager()
	if manager == null:
		return

	var world_name := "UNKNOWN"
	if world != null and world.has_method("get_current_world_display_name"):
		world_name = str(world.get_current_world_display_name())
	elif world != null:
		world_name = str(world.current_world_name)

	var locked_text := "NO"
	var owner_text := "None"
	var status_text := "This world is not locked."
	var is_locked := bool(manager.is_locked)
	if is_locked:
		locked_text = "YES"
		owner_text = str(manager.owner_name)
		status_text = manager.get_info_text()

	_sync_lock_icon_textures()
	lock_badge.text = "LOCKED" if is_locked else "UNLOCKED"
	apply_world_lock_arcade_button_style(lock_badge, is_locked, false, 18)

	world_label.text = "World: " + world_name
	locked_label.text = "Locked: " + locked_text
	owner_label.text = "Owner: " + owner_text
	status_label.text = "Status: " + status_text
	position_label.text = "Lock position: " + manager.get_lock_position_text()

	var is_owner := bool(manager.is_current_player_owner())
	var can_request_key := is_owner and is_locked
	if get_key_button != null:
		get_key_button.visible = can_request_key
		get_key_button.disabled = not can_request_key
		apply_world_lock_arcade_button_style(get_key_button, can_request_key, false, 14)

	public_button.text = "PUBLIC BUILD: ON" if bool(manager.public_build) else "PUBLIC BUILD: OFF"
	slot_limit_input.text = str(manager.get_trusted_builder_slot_limit())

	public_button.disabled = not is_owner
	add_input.editable = is_owner
	add_button.disabled = not is_owner
	add_role_picker.disabled = not is_owner
	slot_limit_input.editable = is_owner
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

	slot_limit_label.text = "TRUSTED BUILDER LIMIT (Trusted Slots: " + manager.get_trusted_builder_slot_summary() + ")"
	if is_owner:
		hint_label.text = "Adjust trusted builder cap (0-50). Existing trusted slots cannot exceed the limit."
	else:
		hint_label.text = "Only the owner can edit access and trusted slot settings."

	refresh_member_list()


func _on_get_key_pressed() -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the world owner can get this key."})
		return
	if not bool(manager.is_locked):
		show_result({"ok": false, "message": "This world is not locked."})
		return

	var lock_grid_pos := target_grid_pos
	if "lock_grid_pos" in manager and manager.lock_grid_pos is Vector2i:
		lock_grid_pos = manager.lock_grid_pos

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_inventory_transaction_request"):
		show_result({"ok": false, "message": "Network is not ready."})
		return

	var world_name := ""
	if world != null:
		world_name = str(world.current_world_name)
	if world_name == "" and world != null and world.has_method("get_current_world_display_name"):
		world_name = str(world.get_current_world_display_name())

	var request := {
		"action": "world_lock_get_key",
		"world": world_name,
		"x": lock_grid_pos.x,
		"y": lock_grid_pos.y,
	}
	print("[WorldLockKey][Client] sending request ", request)
	var sent := bool(network.send_inventory_transaction_request(request))
	if not sent:
		print("[WorldLockKey][Client] request send failed ", request)
		show_result({"ok": false, "message": "Could not request the World Lock Key yet."})


func _on_slot_limit_text_submitted(_text: String) -> void:
	_on_set_slot_limit_pressed()


func _on_set_slot_limit_pressed() -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit access."})
		return
	var text_value := str(slot_limit_input.text).strip_edges()
	if text_value == "":
		show_result({"ok": false, "message": "Enter a slot limit value."})
		return
	if not text_value.is_valid_int():
		show_result({"ok": false, "message": "Enter a valid number for slot limit."})
		return
	var result: Dictionary = manager.set_trusted_builder_slot_limit(int(text_value))
	show_result(result)
	refresh()


func _start_access_lookup_wait(request_id: String, username: String, selected_role: String = "") -> void:
	_pending_access_check_request_id = request_id
	_pending_access_check_name = username.strip_edges()
	_pending_access_check_role = selected_role.strip_edges()
	_access_check_timeout_deadline_ms = Time.get_ticks_msec() + ACCESS_LOOKUP_TIMEOUT_MS


func _clear_access_lookup_wait() -> void:
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


func refresh_member_list() -> void:
	for child in member_list_root.get_children():
		child.queue_free()

	var manager = get_manager()
	if manager == null:
		empty_access_label.visible = true
		return

	var access_list: Array = manager.get_access_list()
	empty_access_label.visible = access_list.is_empty()
	if access_list.is_empty():
		return

	for player_name in access_list:
		create_member_row(str(player_name))


func create_member_row(player_name: String) -> void:
	var manager = get_manager()
	if manager == null:
		return

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 52)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.045, 0.050, 0.068, 0.96),
		Color(0.66, 0.73, 0.86, 0.76),
		3, 5, 5
	))
	member_list_root.add_child(row_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	PixelUIStyle.apply_label_shadow(name_label, 16)
	row.add_child(name_label)

	var role_label := Label.new()
	role_label.text = "ROLE"
	role_label.custom_minimum_size = Vector2(40, 28)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(role_label, 12)
	row.add_child(role_label)

	var player_role: String = manager.normalize_role(manager.get_player_access_role(player_name))
	var selected_role: String = manager.get_role_title(player_role).to_upper()
	var role_selector := OptionButton.new()
	role_selector.custom_minimum_size = Vector2(118, 32)
	role_selector.focus_mode = Control.FOCUS_NONE
	role_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	for role_index in range(WORLD_LOCK_ROLE_OPTIONS.size()):
		role_selector.add_item(WORLD_LOCK_ROLE_OPTIONS[role_index], role_index)
	var selected_index := WORLD_LOCK_ROLE_OPTIONS.find(selected_role)
	if selected_index < 0:
		selected_index = WORLD_LOCK_ROLE_OPTIONS.find(DEFAULT_WORLD_LOCK_ROLE)
	role_selector.selected = selected_index
	role_selector.disabled = not manager.is_current_player_owner()
	apply_world_lock_arcade_button_style(role_selector, false, false, 13)
	role_selector.item_selected.connect(func(index: int):
		_on_member_role_selected(player_name, index)
	)
	row.add_child(role_selector)

	var remove_button := Button.new()
	remove_button.text = "REMOVE"
	remove_button.custom_minimum_size = Vector2(106, 32)
	remove_button.mouse_filter = Control.MOUSE_FILTER_STOP
	remove_button.disabled = not manager.is_current_player_owner()
	apply_world_lock_arcade_button_style(remove_button, false, true, 13)
	remove_button.pressed.connect(func():
		_on_remove_access_pressed(player_name)
	)
	row.add_child(remove_button)


func _on_public_build_pressed() -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can change public build."})
		return
	if manager.is_strict_mode_enabled() and not bool(manager.is_current_player_owner_session_verified()):
		show_result({"ok": false, "message": "Owner identity could not be verified. Re-sign in as the world owner account."})
		return

	var target_state := not bool(manager.public_build)
	var confirm_message := "Set World Public Build to " + ("ON" if target_state else "OFF") + "?"
	if target_state:
		confirm_message += "\nThis will make the world publicly editable and accessible to everyone in this world."
	else:
		confirm_message += "\nOnly the owner and granted access players will be able to build."

	_show_confirm_panel(
		confirm_message,
		func():
			_apply_public_build_change(target_state)
	)


func _on_add_text_submitted(_text: String) -> void:
	_on_add_access_pressed()


func _on_add_access_pressed() -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit access."})
		return

	var username_raw := str(add_input.text).strip_edges()
	if username_raw == "":
		show_result({"ok": false, "message": "Enter a username first."})
		return

	var selected_role := _get_selected_role(add_role_picker)
	if selected_role == "":
		selected_role = "BUILDER"

	var can_validate_username := _is_access_lookup_available()
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


func _on_remove_access_pressed(player_name: String) -> void:
	var manager = get_manager()
	if manager == null:
		return
	var result: Dictionary = manager.remove_access_name(player_name)
	show_result(result)
	refresh()


func handle_player_state_lookup_result(_request_id: String, data: Dictionary, request_context: Dictionary = {}) -> void:
	if _pending_access_check_request_id == "":
		return
	if _pending_access_check_request_id != "" and _request_id != "" and _request_id != _pending_access_check_request_id:
		return

	var request_purpose := str(request_context.get("purpose", "")).strip_edges().to_lower()
	if request_purpose != "" and request_purpose != "world_lock_access_check":
		return

	var pending_name := _pending_access_check_name
	var pending_role := _pending_access_check_role
	var manager = get_manager()
	if manager == null:
		_clear_access_lookup_wait()
		return

	var lookup_context := _get_access_lookup_context(request_context)
	var requested_name := str(lookup_context.get("requested_username", pending_name)).strip_edges()
	var requested_role := str(lookup_context.get("selected_role", pending_role)).strip_edges()
	if requested_name == "":
		requested_name = pending_name
	if requested_role == "":
		requested_role = "BUILDER"

	var pending_normalized: String = manager.normalize_name(pending_name)
	var requested_normalized: String = manager.normalize_name(requested_name)
	if requested_normalized == "":
		requested_normalized = pending_normalized

	var found_name: String = _extract_username_from_lookup_result(data)
	if found_name == "":
		found_name = str(data.get("username", "")).strip_edges()
	var found_name_normalized: String = manager.normalize_name(found_name)

	var requested_username: String = requested_name.to_upper()
	if requested_username == "":
		requested_username = pending_normalized

	_clear_access_lookup_wait()

	if not _is_player_lookup_success(data):
		var server_message: String = _extract_lookup_error_message(data)
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

	var requested_name_normalized: String = manager.normalize_name(requested_username)
	if pending_normalized != "" and requested_name_normalized != "" and pending_normalized != requested_name_normalized:
		show_result({"ok": false, "message": "Lookup context mismatch. Please retry."})
		return

	if found_name_normalized != "":
		if requested_normalized != "" and found_name_normalized != requested_normalized and pending_normalized != "":
			show_result({"ok": false, "message": "Lookup response did not match target player."})
			return

	var confirmed_name_normalized: String = manager.normalize_name(found_name)
	if requested_name_normalized != "" and requested_name_normalized != confirmed_name_normalized:
		show_result({"ok": false, "message": "Player not found."})
		return
	if confirmed_name_normalized == "":
		show_result({"ok": false, "message": "Player not found."})
		return

	var confirmation_name: String = found_name
	var role_name := _normalize_role_option(requested_role)
	if role_name == "":
		role_name = _normalize_role_option(manager.get_role_title("BUILDER"))

	_show_confirm_panel(
		"Grant " + manager.get_role_title(role_name) + " access to " + confirmation_name + "?\nThey will be added to the world access list.",
		func():
			_apply_add_access(confirmation_name, role_name),
		"GRANT ACCESS"
	)


func _on_member_role_selected(player_name: String, item_index: int) -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can edit roles."})
		refresh_member_list()
		return

	var new_role := _normalize_role_option_by_index(item_index)
	if new_role == "":
		return

	var clean_name: String = manager.normalize_name(player_name)
	if clean_name == "":
		show_result({"ok": false, "message": "Invalid player name."})
		refresh_member_list()
		return

	var current_role: String = manager.normalize_role(manager.get_player_access_role(clean_name))
	if current_role == new_role:
		return

	var role_title: String = manager.get_role_title(new_role)
	_show_confirm_panel(
		"Set " + clean_name + " role to " + role_title + "?",
		func():
			_apply_member_role_change(clean_name, new_role),
		"SET ROLE"
	)


func _apply_member_role_change(player_name: String, new_role: String) -> void:
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
	var normalized_role := role_raw.strip_edges().to_upper()
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


func show_result(result: Dictionary) -> void:
	if world == null:
		return
	var message := str(result.get("message", ""))
	if message == "":
		return
	if world.has_method("show_notification"):
		world.show_notification(message)


func _get_world_lock_key_count() -> int:
	if world == null:
		return 0
	var materials = world.get("material_inventory")
	if not (materials is Dictionary):
		return 0
	return maxi(0, int(materials.get(WORLD_LOCK_KEY_ITEM_ID, 0)))


func _is_world_lock_key_delta(delta: Dictionary) -> bool:
	var item_type := str(delta.get("item_id", delta.get("item_type", ""))).strip_edges()
	var category := str(delta.get("item_category", delta.get("category", ""))).strip_edges().to_lower()
	if category == "":
		category = WORLD_LOCK_KEY_CATEGORY
	return item_type == WORLD_LOCK_KEY_ITEM_ID and category == WORLD_LOCK_KEY_CATEGORY


func _extract_world_lock_key_delta(data: Dictionary) -> Dictionary:
	if data.has("inventory_delta") and data["inventory_delta"] is Dictionary:
		var single_delta: Dictionary = data["inventory_delta"]
		if _is_world_lock_key_delta(single_delta):
			return single_delta

	var raw_deltas = data.get("inventory_deltas", [])
	if raw_deltas is Array:
		for raw_delta in raw_deltas:
			if not (raw_delta is Dictionary):
				continue
			var delta: Dictionary = raw_delta
			if _is_world_lock_key_delta(delta):
				return delta

	return {}


func _hotbar_has_world_lock_key() -> bool:
	if world == null:
		return false
	var items = world.get("hotbar_items")
	var categories = world.get("hotbar_item_categories")
	if not (items is Array) or not (categories is Array):
		return false
	var slot_count = mini(items.size(), categories.size())
	for slot_index in range(slot_count):
		if str(items[slot_index]) == WORLD_LOCK_KEY_ITEM_ID and str(categories[slot_index]).strip_edges().to_lower() == WORLD_LOCK_KEY_CATEGORY:
			return true
	return false


func _sync_world_lock_key_inventory_result(data: Dictionary) -> void:
	if world == null or not bool(data.get("ok", false)):
		return

	var key_delta := _extract_world_lock_key_delta(data)
	print("[WorldLockKey][Client] sync result ok key_delta=", key_delta, " material_count_before=", _get_world_lock_key_count())
	if not key_delta.is_empty() and world.has_method("apply_network_inventory_delta"):
		var expected_count := int(key_delta.get("after_count", key_delta.get("count", -1)))
		if expected_count >= 0 and _get_world_lock_key_count() != expected_count:
			world.apply_network_inventory_delta(key_delta)

	if _get_world_lock_key_count() <= 0:
		return

	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(WORLD_LOCK_KEY_ITEM_ID, WORLD_LOCK_KEY_CATEGORY)
	if not _hotbar_has_world_lock_key() and world.has_method("assign_item_to_quick_hotbar"):
		world.assign_item_to_quick_hotbar(WORLD_LOCK_KEY_ITEM_ID, WORLD_LOCK_KEY_CATEGORY)


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	if str(data.get("action", "")) != "world_lock_get_key":
		return false
	print("[WorldLockKey][Client] result ", {
		"ok": bool(data.get("ok", false)),
		"message": str(data.get("message", "")),
		"inventory_delta": data.get("inventory_delta", {}),
		"inventory_deltas": data.get("inventory_deltas", [])
	})
	_sync_world_lock_key_inventory_result(data)
	show_result(data)
	refresh()
	return true


func _show_confirm_loading(message: String) -> void:
	if world == null:
		return
	show_result({"ok": false, "message": message})


func _show_confirm_panel(message: String, on_confirm: Callable, confirm_text: String = "CONFIRM", on_cancel: Callable = Callable()) -> void:
	clear_confirmation_popup()

	confirm_blocker = ColorRect.new()
	confirm_blocker.name = "WorldLockConfirmBlocker"
	confirm_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_blocker.anchor_right = 1.0
	confirm_blocker.anchor_bottom = 1.0
	confirm_blocker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_blocker.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_blocker.z_index = 198
	confirm_blocker.color = Color(0.0, 0.0, 0.0, 0.42)
	confirm_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_blocker)

	confirm_panel = Panel.new()
	confirm_panel.name = "WorldLockConfirmPanel"
	confirm_panel.size = Vector2(540.0, 214.0)
	confirm_panel.position = (get_viewport_rect().size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 199
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 12
	))
	add_child(confirm_panel)

	var label := Label.new()
	label.name = "ConfirmLabel"
	label.text = message
	label.position = Vector2(24.0, 20.0)
	label.size = Vector2(492.0, 106.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 14)
	confirm_panel.add_child(label)

	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = confirm_text
	confirm.position = Vector2(42.0, 150.0)
	confirm.size = Vector2(206.0, 44.0)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(confirm, true, false, 16)
	confirm.pressed.connect(func():
		if on_confirm != null and on_confirm.is_valid():
			on_confirm.call()
		clear_confirmation_popup()
	)
	confirm_panel.add_child(confirm)

	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(292.0, 150.0)
	cancel.size = Vector2(206.0, 44.0)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_world_lock_arcade_button_style(cancel, false, false, 16)
	cancel.pressed.connect(func():
		if on_cancel != null and on_cancel.is_valid():
			on_cancel.call()
		clear_confirmation_popup()
	)
	confirm_panel.add_child(cancel)


func clear_confirmation_popup() -> void:
	if confirm_blocker != null and is_instance_valid(confirm_blocker):
		confirm_blocker.queue_free()
	confirm_blocker = null
	if confirm_panel != null and is_instance_valid(confirm_panel):
		confirm_panel.queue_free()
	confirm_panel = null


func _apply_public_build_change(target_state: bool) -> void:
	var manager = get_manager()
	if manager == null:
		return
	var result: Dictionary = manager.set_public_build(target_state)
	show_result(result)
	refresh()


func _extract_username_from_lookup_result(data: Dictionary, depth: int = 0) -> String:
	if data == null or depth > 8:
		return ""

	var account_name := str(data.get("username", "")).strip_edges()
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

	var username := str(data.get("username", "")).strip_edges()
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

	var message := str(data.get("message", "")).strip_edges()
	if message != "":
		return message

	var error_code := str(data.get("error", "")).strip_edges()
	if error_code != "":
		return error_code

	var result_message := str(data.get("result", "")).strip_edges()
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


func _apply_add_access(username: String, role: String) -> void:
	var manager = get_manager()
	if manager == null:
		return
	if not manager.is_current_player_owner():
		show_result({"ok": false, "message": "Only the owner can grant access."})
		return
	if manager.is_strict_mode_enabled() and not bool(manager.is_current_player_owner_session_verified()):
		show_result({"ok": false, "message": "Owner identity could not be verified. Re-sign in as the world owner account."})
		return

	var clean_role := _normalize_role_option(role)
	if clean_role == "":
		show_result({"ok": false, "message": "Invalid role selected."})
		return

	var clean_name: String = manager.normalize_name(username)
	if clean_name == "":
		show_result({"ok": false, "message": "Player not found."})
		return

	var result: Dictionary = manager.add_access_name(clean_name, clean_role, true)
	show_result(result)
	if bool(result.get("ok", false)):
		add_input.text = ""
	refresh()


func get_world_lock_icon_texture():
	var lock_item_id := "world_lock"
	if world != null and world.has_method("get_world_lock_block_type"):
		lock_item_id = str(world.get_world_lock_block_type())
	if world != null:
		if world.has_method("get_inventory_icon_texture"):
			var icon_texture = world.get_inventory_icon_texture(lock_item_id, "block")
			if icon_texture != null:
				return icon_texture
		if world.block_textures.has(lock_item_id):
			return world.block_textures[lock_item_id]
	var lock_texture_path := "res://Assets/locks/world_lock.png"
	if lock_item_id == "super_world_lock":
		lock_texture_path = "res://Assets/locks/super_world_lock.png"
	if ResourceLoader.exists(lock_texture_path):
		return load(lock_texture_path)
	return null


func apply_close_texture_button_style(button: Button) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.icon = null
	button.add_theme_stylebox_override("normal", _make_texture_style(CLOSE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _make_texture_style(CLOSE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(CLOSE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("disabled", _make_texture_style(CLOSE_BUTTON_TEXTURE))


func apply_world_lock_tab_style(button: Button, selected: bool, font_size: int = 14) -> void:
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	button.focus_mode = Control.FOCUS_NONE
	var normal_texture = TAB_SELECTED_TEXTURE if selected else TAB_NORMAL_TEXTURE
	button.add_theme_stylebox_override("normal", _make_texture_style(normal_texture))
	button.add_theme_stylebox_override("pressed", _make_texture_style(TAB_SELECTED_TEXTURE))
	button.add_theme_stylebox_override("hover", _make_texture_style(TAB_SELECTED_TEXTURE))
	button.add_theme_stylebox_override("disabled", _make_texture_style(normal_texture))
	button.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.82, 0.95, 1.0, 0.92))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func apply_world_lock_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14) -> void:
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	# Always use the same green button kit WorldLockGUI.tscn authors for its own buttons
	# (GetKeyButton, PublicBuildButton, SetLimitButton, AddAccessButton), so every button in
	# this menu -- scene-authored or dynamically created (member rows, confirm popup) --
	# matches the scene's actual look. `selected` and `danger` are kept as parameters so
	# existing call sites don't need to change, but no longer switch to a different palette.
	button.add_theme_stylebox_override("normal", _make_texture_style(BUTTON_GREEN_NORMAL))
	button.add_theme_stylebox_override("pressed", _make_texture_style(BUTTON_GREEN_PRESSED))
	button.add_theme_stylebox_override("hover", _make_texture_style(BUTTON_GREEN_HOVER))
	button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.10, 0.14, 0.10, 0.50), Color(0.24, 0.34, 0.22, 0.42), 3, 12, 3))


func apply_world_lock_input_style(line_edit: LineEdit, font_size: int = 18) -> void:
	if line_edit == null:
		return
	line_edit.add_theme_font_size_override("font_size", font_size)
	PixelUIStyle.apply_game_font_to_node(line_edit)
	var empty_style := StyleBoxEmpty.new()
	line_edit.add_theme_stylebox_override("normal", empty_style)
	line_edit.add_theme_stylebox_override("focus", empty_style)
	line_edit.add_theme_color_override("font_color", PixelUIStyle.TEXT_LIGHT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.76, 0.90, 1.0, 0.74))
	line_edit.add_theme_color_override("caret_color", PixelUIStyle.GOLD_SOFT)
	line_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))


func apply_world_lock_scrollbar_style(scroll: ScrollContainer) -> void:
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


func _make_texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style


func _apply_texture_filter(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_apply_texture_filter(child)
