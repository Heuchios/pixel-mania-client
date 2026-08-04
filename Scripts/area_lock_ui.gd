extends Control

signal closed

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AreaLockHighlightOverlay = preload("res://Scripts/area_lock_highlight_overlay.gd")

var world_node = null
var lock_manager = null
var highlight_overlay = null
var target_lock_id: String = ""
var selected_player_name: String = ""
var ignore_empty_space_confirm_panel: Node = null
var access_confirm_panel: Node = null
var pending_access_name: String = ""
var pending_access_role: String = ""
var pending_access_verified: bool = false
var pending_remove_access_name: String = ""
var access_remove_confirm_panel: Node = null
var public_build_confirm_panel: Node = null

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/Header/TitleLabel
@onready var close_button: Button = $Panel/VBox/Header/CloseButton
@onready var info_label: Label = $Panel/VBox/InfoPanel/InfoLabel
@onready var public_build_check: CheckBox = $Panel/VBox/PublicBuildCheck
@onready var ignore_empty_space_check: CheckBox = $Panel/VBox/IgnoreEmptySpaceCheck
@onready var player_input: LineEdit = $Panel/VBox/AddRow/PlayerInput
@onready var role_option: OptionButton = $Panel/VBox/AddRow/RoleOption
@onready var add_button: Button = $Panel/VBox/AddRow/AddButton
@onready var access_list: VBoxContainer = $Panel/VBox/AccessScroll/AccessList
@onready var status_label: Label = $Panel/VBox/StatusLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close)
	add_button.pressed.connect(_on_add_pressed)
	public_build_check.toggled.connect(_on_public_build_toggled)
	ignore_empty_space_check.toggled.connect(_on_ignore_empty_space_toggled)
	role_option.clear()
	role_option.add_item("Builder")
	role_option.set_item_metadata(0, "builder")
	role_option.add_item("Admin")
	role_option.set_item_metadata(1, "admin")
	apply_pixel_style()


func apply_pixel_style() -> void:
	PixelUIStyle.apply_label_shadow(title_label)
	PixelUIStyle.apply_small_label(info_label)
	PixelUIStyle.apply_small_label(status_label)
	PixelUIStyle.apply_blue_button(add_button)
	PixelUIStyle.apply_yellow_button(close_button)
	PixelUIStyle.apply_input(player_input)
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.07, 0.09, 0.13, 0.96), Color(0.93, 0.74, 0.26), 3, 14))


func setup(world, manager) -> void:
	world_node = world
	lock_manager = manager


func ensure_highlight_overlay() -> void:
	if highlight_overlay != null and is_instance_valid(highlight_overlay):
		return
	if world_node == null:
		return
	if world_node.has_method("setup_area_lock_highlight_overlay"):
		world_node.setup_area_lock_highlight_overlay()
	var existing_overlay = world_node.get_node_or_null("AreaLockHighlightOverlay")
	if existing_overlay != null:
		highlight_overlay = existing_overlay
		if highlight_overlay.has_method("setup"):
			highlight_overlay.setup(world_node, lock_manager)
		return
	highlight_overlay = AreaLockHighlightOverlay.new()
	highlight_overlay.name = "AreaLockHighlightOverlay"
	world_node.add_child(highlight_overlay)
	highlight_overlay.setup(world_node, lock_manager)


func show_highlight(area_lock: Dictionary) -> void:
	ensure_highlight_overlay()
	if highlight_overlay != null and is_instance_valid(highlight_overlay):
		highlight_overlay.show_area_lock(area_lock)


func hide_highlight() -> void:
	if highlight_overlay != null and is_instance_valid(highlight_overlay):
		highlight_overlay.hide_area_lock()


func open_area_lock(grid_pos: Vector2i) -> void:
	if lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_position(grid_pos)
	if area_lock.is_empty():
		area_lock = lock_manager.get_area_lock_covering_position(grid_pos)
	if area_lock.is_empty():
		return
	target_lock_id = str(area_lock.get("lock_id", ""))
	visible = true
	move_to_front()
	refresh()


func close() -> void:
	hide_highlight()
	clear_ignore_empty_space_confirmation()
	clear_access_confirmation()
	clear_access_remove_confirmation()
	clear_public_build_confirmation()
	visible = false
	emit_signal("closed")


func is_open() -> bool:
	return visible


func refresh() -> void:
	if not visible:
		return
	clear_ignore_empty_space_confirmation()
	clear_access_confirmation()
	clear_access_remove_confirmation()
	clear_public_build_confirmation()
	if lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		hide_highlight()
		close()
		return
	var can_manage: bool = bool(lock_manager.can_current_player_manage_area_lock(area_lock))
	var lock_type: String = str(area_lock.get("lock_type", "small_lock"))
	title_label.text = "Small Lock"
	if lock_type == "medium_lock":
		title_label.text = "Medium Lock"
	elif lock_type == "big_lock":
		title_label.text = "Big Lock"
	info_label.text = lock_manager.get_area_lock_info_text(area_lock)
	public_build_check.set_pressed_no_signal(bool(area_lock.get("public_build", false)))
	public_build_check.disabled = not can_manage
	ignore_empty_space_check.set_pressed_no_signal(bool(area_lock.get("ignore_empty_space", false)))
	ignore_empty_space_check.disabled = not can_manage
	player_input.editable = can_manage
	role_option.disabled = not can_manage
	add_button.disabled = not can_manage
	status_label.text = "You can manage this area lock." if can_manage else "Only the lock owner or world owner can edit access."
	_render_access_list(area_lock, can_manage)
	show_highlight(area_lock)


func _render_access_list(area_lock: Dictionary, can_manage: bool) -> void:
	for child in access_list.get_children():
		child.queue_free()
	var entries: Array = lock_manager.get_area_lock_access_list(area_lock)
	if entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No trusted players yet."
		PixelUIStyle.apply_small_label(empty_label)
		access_list.add_child(empty_label)
		return
	for entry in entries:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label: Label = Label.new()
		name_label.text = str(entry.get("name", ""))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var role_label: Label = Label.new()
		role_label.text = str(entry.get("role", "builder")).capitalize()
		var remove_button: Button = Button.new()
		remove_button.text = "Remove"
		remove_button.disabled = not can_manage
		var player_name: String = str(entry.get("name", ""))
		var role_text: String = str(entry.get("role", "builder"))
		remove_button.pressed.connect(func():
			_show_remove_access_confirmation(player_name, role_text)
		)
		PixelUIStyle.apply_small_label(name_label)
		PixelUIStyle.apply_small_label(role_label)
		PixelUIStyle.apply_yellow_button(remove_button)
		row.add_child(name_label)
		row.add_child(role_label)
		row.add_child(remove_button)
		access_list.add_child(row)


func _on_public_build_toggled(enabled: bool) -> void:
	if not visible or lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		return
	var current_state: bool = bool(area_lock.get("public_build", false))
	if current_state == enabled:
		return
	_show_public_build_confirmation(enabled)


func _on_ignore_empty_space_toggled(enabled: bool) -> void:
	if not visible or lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		return

	var current_state: bool = bool(area_lock.get("ignore_empty_space", false))
	if current_state == enabled:
		return
	if not enabled:
		_apply_ignore_empty_space_state(false)
		return
	_show_ignore_empty_space_confirmation()


func _apply_public_build_state(enabled: bool) -> void:
	if lock_manager.set_area_lock_public_build(target_lock_id, enabled):
		refresh()
	else:
		_revert_public_build_checkbox()


func _revert_public_build_checkbox() -> void:
	if not visible or lock_manager == null:
		public_build_check.set_pressed_no_signal(false)
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		close()
		return
	public_build_check.set_pressed_no_signal(bool(area_lock.get("public_build", false)))


func _show_public_build_confirmation(enabled: bool) -> void:
	clear_public_build_confirmation()
	clear_ignore_empty_space_confirmation()
	clear_access_confirmation()
	clear_access_remove_confirmation()
	if panel == null or lock_manager == null:
		return

	var overlay = ColorRect.new()
	overlay.name = "PublicBuildConfirmOverlay"
	overlay.size = panel.size
	overlay.position = Vector2.ZERO
	overlay.z_index = 20
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(overlay)

	var confirm_panel = Panel.new()
	confirm_panel.name = "PublicBuildConfirmPanel"
	confirm_panel.size = Vector2(420, 180)
	confirm_panel.position = (panel.size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 21
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 12, 12
	))
	panel.add_child(confirm_panel)
	public_build_confirm_panel = confirm_panel

	var mode_label: String = "public build mode" if enabled else "trusted-only mode"
	var action_label: String = "Make this area lock public for everyone?" if enabled else "Restrict this area lock to trusted players?"
	var label = Label.new()
	label.text = "%s\nThis will switch this area lock to %s." % [action_label, mode_label]
	label.position = Vector2(18, 18)
	label.size = Vector2(384, 102)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 13)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.name = "ConfirmPublicBuildButton"
	confirm.text = "CONFIRM"
	confirm.position = Vector2(20, 132)
	confirm.size = Vector2(180, 38)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 13)
	confirm.pressed.connect(func():
		clear_public_build_confirmation()
		_apply_public_build_state(enabled)
	)
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelPublicBuildButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(220, 132)
	cancel.size = Vector2(180, 38)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(cancel, 13)
	cancel.pressed.connect(func():
		clear_public_build_confirmation()
		_revert_public_build_checkbox()
	)
	confirm_panel.add_child(cancel)


func _apply_remove_access(player_name: String) -> void:
	if lock_manager.remove_area_lock_access_name(target_lock_id, player_name):
		status_label.text = "%s removed from access list." % player_name
		refresh()
	else:
		status_label.text = "Could not remove %s." % player_name


func _show_remove_access_confirmation(player_name: String, role_text: String) -> void:
	pending_remove_access_name = player_name
	if not visible or panel == null or lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		return

	clear_access_remove_confirmation()
	clear_access_confirmation()
	clear_public_build_confirmation()

	var overlay = ColorRect.new()
	overlay.name = "AccessRemoveConfirmOverlay"
	overlay.size = panel.size
	overlay.position = Vector2.ZERO
	overlay.z_index = 20
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(overlay)

	var confirm_panel = Panel.new()
	confirm_panel.name = "AccessRemoveConfirmPanel"
	confirm_panel.size = Vector2(420, 180)
	confirm_panel.position = (panel.size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 21
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 12, 12
	))
	panel.add_child(confirm_panel)
	access_remove_confirm_panel = confirm_panel

	var label = Label.new()
	label.text = "Remove %s (%s) from trusted access?\nThis change cannot be undone." % [str(player_name), str(role_text).capitalize()]
	label.position = Vector2(18, 18)
	label.size = Vector2(384, 102)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 13)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.name = "ConfirmRemoveAccessButton"
	confirm.text = "CONFIRM"
	confirm.position = Vector2(20, 132)
	confirm.size = Vector2(180, 38)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 13)
	confirm.pressed.connect(func():
		clear_access_remove_confirmation()
		_apply_remove_access(pending_remove_access_name)
	)
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelRemoveAccessButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(220, 132)
	cancel.size = Vector2(180, 38)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(cancel, 13)
	cancel.pressed.connect(func():
		clear_access_remove_confirmation()
	)
	confirm_panel.add_child(cancel)


func clear_access_remove_confirmation() -> void:
	if panel != null:
		var overlay = panel.get_node_or_null("AccessRemoveConfirmOverlay")
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	if access_remove_confirm_panel != null and is_instance_valid(access_remove_confirm_panel):
		access_remove_confirm_panel.queue_free()
		access_remove_confirm_panel = null


func _apply_ignore_empty_space_state(enabled: bool) -> void:
	if lock_manager.set_area_lock_ignore_empty_space(target_lock_id, enabled):
		refresh()
	else:
		_revert_ignore_empty_space_checkbox()


func _revert_ignore_empty_space_checkbox() -> void:
	if not visible or lock_manager == null:
		ignore_empty_space_check.set_pressed_no_signal(false)
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		close()
		return
	ignore_empty_space_check.set_pressed_no_signal(bool(area_lock.get("ignore_empty_space", false)))


func _show_ignore_empty_space_confirmation() -> void:
	clear_ignore_empty_space_confirmation()
	clear_access_remove_confirmation()
	clear_access_confirmation()

	if panel == null:
		return

	var overlay = ColorRect.new()
	overlay.name = "IgnoreEmptySpaceConfirmOverlay"
	overlay.size = panel.size
	overlay.position = Vector2.ZERO
	overlay.z_index = 20
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(overlay)

	var confirm_panel = Panel.new()
	confirm_panel.name = "IgnoreEmptySpaceConfirmPanel"
	confirm_panel.size = Vector2(420, 188)
	confirm_panel.position = (panel.size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 21
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 12, 12
	))
	panel.add_child(confirm_panel)
	ignore_empty_space_confirm_panel = confirm_panel

	var label = Label.new()
	label.text = "Enable Ignore Empty Air?\nThis will only protect blocks connected to the lock.\nEmpty-air gaps will stay unprotected."
	label.position = Vector2(18, 18)
	label.size = Vector2(384, 100)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 13)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.name = "ConfirmIgnoreEmptySpaceButton"
	confirm.text = "CONFIRM"
	confirm.position = Vector2(20, 132)
	confirm.size = Vector2(180, 38)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 13)
	confirm.pressed.connect(func():
		clear_ignore_empty_space_confirmation()
		_apply_ignore_empty_space_state(true)
	)
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelIgnoreEmptySpaceButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(220, 132)
	cancel.size = Vector2(180, 38)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(cancel, 13)
	cancel.pressed.connect(func():
		clear_ignore_empty_space_confirmation()
		_revert_ignore_empty_space_checkbox()
	)
	confirm_panel.add_child(cancel)


func clear_ignore_empty_space_confirmation() -> void:
	if panel != null:
		var overlay = panel.get_node_or_null("IgnoreEmptySpaceConfirmOverlay")
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	if ignore_empty_space_confirm_panel != null and is_instance_valid(ignore_empty_space_confirm_panel):
		ignore_empty_space_confirm_panel.queue_free()
		ignore_empty_space_confirm_panel = null


func _on_add_pressed() -> void:
	if lock_manager == null:
		return
	var clean_name: String = str(lock_manager.normalize_name(player_input.text))
	if clean_name == "":
		status_label.text = "Enter a player name first."
		return
	selected_player_name = clean_name
	pending_access_name = clean_name
	var selected_role: String = str(role_option.get_item_metadata(role_option.selected))
	pending_access_role = selected_role
	var network: Node = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_player_state_request_with_context"):
		status_label.text = "Checking player..."
		var request_id: String = str(network.send_player_state_request_with_context(clean_name, {
			"purpose": "area_lock_access_check",
			"lock_id": target_lock_id,
			"selected_role": selected_role,
			"requested_username": clean_name
		}))
		if request_id != "":
			return
		status_label.text = "Server unavailable, adding locally."
		_show_add_access_confirmation(clean_name, selected_role, false)
	else:
		_show_add_access_confirmation(clean_name, selected_role, false)


func handle_player_state_lookup_result(_request_id: String, data: Dictionary, request_context: Dictionary = {}) -> bool:
	var purpose: String = str(request_context.get("purpose", ""))
	if purpose != "area_lock_access_check":
		return false
	if not visible:
		return true
	var requested: String = str(lock_manager.normalize_name(str(request_context.get("requested_username", selected_player_name))))
	var lookup_ok: bool = bool(data.get("ok", data.get("success", true)))
	if data.has("found"):
		lookup_ok = bool(data.get("found", false))
	if not lookup_ok:
		status_label.text = "Player not found: %s" % requested
		return true
	var found_name: String = str(lock_manager.normalize_name(str(data.get("username", data.get("name", requested)))))
	if found_name == "":
		found_name = requested
	if found_name != requested and requested != "":
		status_label.text = "Lookup response did not match %s." % requested
		return true
	var role: String = str(request_context.get("selected_role", "builder"))
	_show_add_access_confirmation(found_name, role, true)
	return true


func _apply_add_access(player_name: String, role: String, verified: bool) -> void:
	if lock_manager.add_area_lock_access_name(target_lock_id, player_name, role, verified):
		player_input.text = ""
		status_label.text = "%s added as %s." % [player_name, role]
		refresh()
	else:
		status_label.text = "Could not add %s." % player_name


func _show_add_access_confirmation(player_name: String, role: String, verified: bool) -> void:
	pending_access_name = player_name
	pending_access_role = role
	pending_access_verified = verified
	if not visible or panel == null or lock_manager == null:
		return
	var area_lock: Dictionary = lock_manager.get_area_lock_for_lock_id(target_lock_id)
	if area_lock.is_empty():
		return

	clear_access_confirmation()
	clear_access_remove_confirmation()

	var overlay = ColorRect.new()
	overlay.name = "AccessConfirmOverlay"
	overlay.size = panel.size
	overlay.position = Vector2.ZERO
	overlay.z_index = 20
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(overlay)

	var confirm_panel = Panel.new()
	confirm_panel.name = "AccessConfirmPanel"
	confirm_panel.size = Vector2(420, 180)
	confirm_panel.position = (panel.size - confirm_panel.size) * 0.5
	confirm_panel.z_index = 21
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.clip_contents = true
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 12, 12
	))
	panel.add_child(confirm_panel)
	access_confirm_panel = confirm_panel

	var role_text: String = str(role).capitalize()
	var label = Label.new()
	label.text = "Grant %s access as %s for this area lock?" % [str(player_name), role_text]
	label.position = Vector2(18, 18)
	label.size = Vector2(384, 102)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	PixelUIStyle.apply_label_shadow(label, 13)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.name = "ConfirmAddAccessButton"
	confirm.text = "CONFIRM"
	confirm.position = Vector2(20, 132)
	confirm.size = Vector2(180, 38)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 13)
	confirm.pressed.connect(func():
		clear_access_confirmation()
		_apply_add_access(pending_access_name, pending_access_role, pending_access_verified)
	)
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelAddAccessButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(220, 132)
	cancel.size = Vector2(180, 38)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(cancel, 13)
	cancel.pressed.connect(func():
		clear_access_confirmation()
	)
	confirm_panel.add_child(cancel)


func clear_access_confirmation() -> void:
	if panel != null:
		var overlay = panel.get_node_or_null("AccessConfirmOverlay")
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	if access_confirm_panel != null and is_instance_valid(access_confirm_panel):
		access_confirm_panel.queue_free()
		access_confirm_panel = null


func clear_public_build_confirmation() -> void:
	if panel != null:
		var overlay = panel.get_node_or_null("PublicBuildConfirmOverlay")
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	if public_build_confirm_panel != null and is_instance_valid(public_build_confirm_panel):
		public_build_confirm_panel.queue_free()
		public_build_confirm_panel = null
