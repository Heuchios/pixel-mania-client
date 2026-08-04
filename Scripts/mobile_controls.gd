extends Control

signal layout_customization_finished(saved: bool)

const SETTINGS_SAVE_PATH := "user://pixelmania_settings.cfg"
const SETTINGS_SECTION := "mobile_controls"
const LAYOUT_VERSION := 1
const CONTROL_ACTIONS := ["move_left", "move_right", "jump", "punch", "zoom_in", "zoom_out"]
const CONTROL_LABELS := {
	"move_left": "MOVE LEFT",
	"move_right": "MOVE RIGHT",
	"jump": "JUMP",
	"punch": "PUNCH",
	"zoom_in": "ZOOM IN",
	"zoom_out": "ZOOM OUT"
}
const HELD_ACTIONS := ["move_left", "move_right", "jump", "punch"]
const PUNCH_HOLD_INITIAL_DELAY := 0.30
const PUNCH_HOLD_REPEAT_RATE := 0.30
const GAMEPLAY_CONTROLS_Z_INDEX := 190
const MOVE_BUTTON_SIZE := Vector2(96.0, 96.0)
const ACTION_BUTTON_SIZE := Vector2(104.0, 96.0)
const ZOOM_BUTTON_SIZE := Vector2(84.0, 84.0)
const MOBILE_CONTROL_MIN_SCALE := 1.20
const MOBILE_CONTROL_MAX_SCALE := 1.52
const CUSTOM_SIZE_MIN := 0.65
const CUSTOM_SIZE_MAX := 1.50
const CUSTOM_SIZE_STEP := 0.05
const CONTROL_EDGE_MARGIN := 12.0
const EDITOR_TOOLBAR_HEIGHT := 104.0
const EDITOR_TOOLBAR_MARGIN := 8.0
const BOTTOM_MARGIN := 34.0
const BUTTON_GAP := 24.0
const MIN_HOTBAR_GAP := 18.0
const FALLBACK_HOTBAR_WIDTH := 622.0
const FALLBACK_HOTBAR_HEIGHT := 162.0
const ICON_PADDING := 20.0
const MOVE_GROUP_LEFT_SHIFT := 34.0
const ACTION_GROUP_RIGHT_SHIFT := 34.0
const ZOOM_LEFT_MARGIN := 18.0
const ZOOM_VERTICAL_GAP := 16.0
const ICON_PATHS := {
	"move_left": "res://Assets/ui/mobile_buttons/left.png",
	"move_right": "res://Assets/ui/mobile_buttons/right.png",
	"jump": "res://Assets/ui/mobile_buttons/jump.png",
	"punch": "res://Assets/ui/mobile_buttons/punch.png",
	"zoom_in": "res://Assets/ui/mobile_buttons/zoom_in.png",
	"zoom_out": "res://Assets/ui/mobile_buttons/zoom_out.png"
}
const PRESSED_ICON_PATHS := {
	"move_left": "res://Assets/ui/mobile_buttons/left_pressed.png",
	"move_right": "res://Assets/ui/mobile_buttons/right_pressed.png",
	"jump": "res://Assets/ui/mobile_buttons/jump_pressed.png",
	"punch": "res://Assets/ui/mobile_buttons/punch_pressed.png"
}

var world = null
var settings_save_path := SETTINGS_SAVE_PATH
var active_action_touches := {}
var active_action_mouse := {}
var action_buttons := {}
var icon_texture_cache := {}
var punch_action_release_generation := 0
var punch_hold_timer := 0.0
var punch_hold_repeat_active := false
var control_layout: Dictionary = {}
var has_custom_layout := false
var layout_customization_active := false
var layout_snapshot: Dictionary = {}
var snapshot_had_custom_layout := false
var layout_save_as_defaults := false
var selected_layout_action := ""
var active_layout_touch_index := -1
var active_layout_mouse := false
var active_layout_action := ""
var editor_overlay: ColorRect = null
var editor_safe_area_outline: Panel = null
var editor_toolbar: PanelContainer = null
var editor_instruction_label: Label = null
var layout_editor_normal_parent: Node = null
var layout_editor_normal_z_index := GAMEPLAY_CONTROLS_Z_INDEX
var layout_editor_normal_child_index := -1


func setup(world_ref):
	world = world_ref
	_configure_root()
	_load_layout_preferences()
	_build_controls()
	_build_editor_ui()
	_layout_controls()
	_update_visibility()


func _process(delta):
	_layout_controls()
	_update_visibility()
	_update_punch_hold(delta)


func _input(event):
	if layout_customization_active:
		_handle_layout_editor_global_input(event)
		return

	if event is InputEventScreenTouch and not event.pressed:
		_release_touch_index(event.index)
	elif not _is_mobile_platform() and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_release_mouse_actions()


func _exit_tree():
	_release_all_actions()


func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all_actions()
		active_layout_touch_index = -1
		active_layout_mouse = false
		active_layout_action = ""


func _configure_root():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = GAMEPLAY_CONTROLS_Z_INDEX


func _build_controls():
	if action_buttons.size() > 0:
		return

	_add_hold_button("LeftButton", "move_left", true, Vector2.ZERO, MOVE_BUTTON_SIZE)
	_add_hold_button("RightButton", "move_right", true, Vector2.ZERO, MOVE_BUTTON_SIZE)
	_add_hold_button("JumpButton", "jump", false, Vector2.ZERO, ACTION_BUTTON_SIZE)
	_add_punch_button("PunchButton", Vector2.ZERO, ACTION_BUTTON_SIZE)
	_add_zoom_button("ZoomInButton", "zoom_in", Vector2.ZERO, ZOOM_BUTTON_SIZE)
	_add_zoom_button("ZoomOutButton", "zoom_out", Vector2.ZERO, ZOOM_BUTTON_SIZE)


func _add_hold_button(node_name: String, action: String, _left_side: bool, button_position: Vector2, button_size: Vector2):
	var button = _create_button(node_name, action, button_position, button_size)
	button.gui_input.connect(_on_hold_button_gui_input.bind(action))
	action_buttons[action] = button


func _add_punch_button(node_name: String, button_position: Vector2, button_size: Vector2):
	var button = _create_button(node_name, "punch", button_position, button_size)
	button.gui_input.connect(_on_punch_button_gui_input)
	action_buttons["punch"] = button


func _add_zoom_button(node_name: String, action: String, button_position: Vector2, button_size: Vector2):
	var button = _create_button(node_name, action, button_position, button_size)
	button.gui_input.connect(_on_zoom_button_gui_input.bind(action))
	action_buttons[action] = button


func _create_button(node_name: String, action: String, button_position: Vector2, button_size: Vector2) -> Panel:
	var button = Panel.new()
	button.name = node_name
	button.anchor_left = 0.0
	button.anchor_right = 0.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	_set_button_rect(button, button_position, button_size)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.clip_contents = true
	button.set_meta("mobile_control_action", action)
	_apply_button_style(button, false)
	add_child(button)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = _get_action_icon_texture(action, false)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = ICON_PADDING
	icon.offset_top = ICON_PADDING
	icon.offset_right = -ICON_PADDING
	icon.offset_bottom = -ICON_PADDING
	button.add_child(icon)

	return button


func _layout_controls():
	if action_buttons.size() <= 0:
		return

	var screen_size = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return

	var scale_value = get_mobile_control_scale(screen_size)
	var gap = BUTTON_GAP * scale_value
	var margin_bottom = BOTTOM_MARGIN * scale_value
	var min_hotbar_gap = MIN_HOTBAR_GAP * scale_value
	var move_group_left_shift = MOVE_GROUP_LEFT_SHIFT * scale_value
	var action_group_right_shift = ACTION_GROUP_RIGHT_SHIFT * scale_value
	var move_size = MOVE_BUTTON_SIZE * scale_value
	var action_size = ACTION_BUTTON_SIZE * scale_value
	var zoom_size = ZOOM_BUTTON_SIZE * scale_value
	var icon_padding = ICON_PADDING * scale_value
	var hotbar_rect = get_hotbar_screen_rect(screen_size)
	var inventory_drawer_offset := _get_inventory_drawer_offset(hotbar_rect, screen_size)

	var move_group_width = move_size.x * 2.0 + gap
	var left_space_width = max(0.0, hotbar_rect.position.x)
	var move_x = (left_space_width - move_group_width) * 0.5 - move_group_left_shift
	move_x = clamp(move_x, min_hotbar_gap, max(min_hotbar_gap, hotbar_rect.position.x - move_group_width - min_hotbar_gap))

	var action_group_width = action_size.x * 2.0 + gap
	var right_space_left = hotbar_rect.position.x + hotbar_rect.size.x
	var right_space_width = max(0.0, screen_size.x - right_space_left)
	var action_x = right_space_left + (right_space_width - action_group_width) * 0.5 + action_group_right_shift
	var action_min_x = right_space_left + min_hotbar_gap
	var action_max_x = screen_size.x - action_group_width - min_hotbar_gap
	if action_max_x < action_min_x:
		action_min_x = max(min_hotbar_gap, action_max_x)
	action_x = clamp(action_x, action_min_x, max(action_min_x, action_max_x))

	var bottom_y = screen_size.y - margin_bottom - max(move_size.y, action_size.y)
	var zoom_gap = ZOOM_VERTICAL_GAP * scale_value
	var zoom_group_height = zoom_size.y * 2.0 + zoom_gap
	var zoom_x = ZOOM_LEFT_MARGIN * scale_value
	var zoom_y = clamp(
		(screen_size.y - zoom_group_height) * 0.5,
		min_hotbar_gap,
		max(min_hotbar_gap, bottom_y - zoom_group_height - gap)
	)
	var safe_layout_rect := _get_safe_layout_rect(screen_size)

	_apply_layout_rect("move_left", Vector2(move_x, bottom_y), move_size, icon_padding, safe_layout_rect, inventory_drawer_offset)
	_apply_layout_rect("move_right", Vector2(move_x + move_size.x + gap, bottom_y), move_size, icon_padding, safe_layout_rect, inventory_drawer_offset)
	_apply_layout_rect("jump", Vector2(action_x, bottom_y), action_size, icon_padding, safe_layout_rect, inventory_drawer_offset)
	_apply_layout_rect("punch", Vector2(action_x + action_size.x + gap, bottom_y), action_size, icon_padding, safe_layout_rect, inventory_drawer_offset)
	_apply_layout_rect("zoom_in", Vector2(zoom_x, zoom_y), zoom_size, icon_padding, safe_layout_rect)
	_apply_layout_rect("zoom_out", Vector2(zoom_x, zoom_y + zoom_size.y + zoom_gap), zoom_size, icon_padding, safe_layout_rect)
	_layout_editor_ui(safe_layout_rect)


func _get_inventory_drawer_offset(hotbar_rect: Rect2, screen_size: Vector2) -> Vector2:
	return Vector2(0.0, minf(0.0, hotbar_rect.end.y - screen_size.y))


func _apply_layout_rect(
	action: String,
	default_position: Vector2,
	default_size: Vector2,
	default_icon_padding: float,
	safe_rect: Rect2,
	dynamic_offset: Vector2 = Vector2.ZERO
) -> void:
	var button_position := default_position
	var button_size := default_size
	var icon_padding := default_icon_padding

	if has_custom_layout:
		var layout_value: Variant = control_layout.get(action, null)
		if layout_value is Dictionary:
			var layout_entry: Dictionary = layout_value
			var size_scale := clampf(float(layout_entry.get("scale", 1.0)), CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX)
			var normalized_center_value: Variant = layout_entry.get("center", Vector2(-1.0, -1.0))
			if typeof(normalized_center_value) == TYPE_VECTOR2:
				var normalized_center: Vector2 = normalized_center_value
				normalized_center.x = clampf(normalized_center.x, 0.0, 1.0)
				normalized_center.y = clampf(normalized_center.y, 0.0, 1.0)
				var button_center := safe_rect.position + normalized_center * safe_rect.size
				button_size *= size_scale
				icon_padding *= size_scale
				button_position = _clamp_button_position(button_center - button_size * 0.5, button_size, safe_rect)

	button_position += dynamic_offset
	if not dynamic_offset.is_zero_approx():
		button_position = _clamp_button_position(button_position, button_size, safe_rect)

	_set_action_rect(action, button_position, button_size, icon_padding)


func _get_safe_layout_rect(screen_size: Vector2) -> Rect2:
	var safe_rect := Rect2(Vector2.ZERO, screen_size)
	if _is_mobile_platform():
		var screen_index := DisplayServer.window_get_current_screen()
		var display_size_i := DisplayServer.screen_get_size(screen_index)
		var display_safe_i := DisplayServer.get_display_safe_area()
		if display_size_i.x > 0 and display_size_i.y > 0 and display_safe_i.size.x > 0 and display_safe_i.size.y > 0:
			var display_origin_i := DisplayServer.screen_get_position(screen_index)
			var relative_safe_position := Vector2(display_safe_i.position - display_origin_i)
			var display_size := Vector2(display_size_i)
			safe_rect.position = relative_safe_position / display_size * screen_size
			safe_rect.size = Vector2(display_safe_i.size) / display_size * screen_size

	var edge_margin := CONTROL_EDGE_MARGIN
	safe_rect.position += Vector2.ONE * edge_margin
	safe_rect.size -= Vector2.ONE * edge_margin * 2.0
	if safe_rect.size.x < 1.0 or safe_rect.size.y < 1.0:
		return Rect2(Vector2.ZERO, screen_size)

	return safe_rect


func _clamp_button_position(button_position: Vector2, button_size: Vector2, safe_rect: Rect2) -> Vector2:
	var clamped_position := button_position
	var maximum_x := safe_rect.end.x - button_size.x
	var maximum_y := safe_rect.end.y - button_size.y

	if maximum_x < safe_rect.position.x:
		clamped_position.x = safe_rect.get_center().x - button_size.x * 0.5
	else:
		clamped_position.x = clampf(clamped_position.x, safe_rect.position.x, maximum_x)

	if maximum_y < safe_rect.position.y:
		clamped_position.y = safe_rect.get_center().y - button_size.y * 0.5
	else:
		clamped_position.y = clampf(clamped_position.y, safe_rect.position.y, maximum_y)

	return clamped_position


func _get_editor_control_bounds(safe_rect: Rect2) -> Rect2:
	var editor_bounds := safe_rect
	var reserved_top := EDITOR_TOOLBAR_HEIGHT + EDITOR_TOOLBAR_MARGIN * 2.0
	editor_bounds.position.y += reserved_top
	editor_bounds.size.y -= reserved_top
	if editor_bounds.size.y < 96.0:
		return safe_rect
	return editor_bounds


func get_mobile_control_scale(screen_size: Vector2) -> float:
	var raw_scale: float = minf(screen_size.x / 1280.0, screen_size.y / 720.0)
	return clampf(raw_scale, MOBILE_CONTROL_MIN_SCALE, MOBILE_CONTROL_MAX_SCALE)


func get_hotbar_screen_rect(screen_size: Vector2) -> Rect2:
	var ui_search_layers: Array = []
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			ui_search_layers.append(hud_layer)
	if world != null and "ui_layer" in world and world.ui_layer != null and not ui_search_layers.has(world.ui_layer):
		ui_search_layers.append(world.ui_layer)

	for layer in ui_search_layers:
		if not (layer is Node):
			continue
		var hotbar = layer.get_node_or_null("Hotbar")
		if hotbar is Control and hotbar.visible:
			var border = hotbar.get_node_or_null("BarBorder")
			if border is Control:
				var border_rect: Rect2 = border.get_global_rect()
				if border_rect.size.x > 1.0 and border_rect.size.y > 1.0:
					return border_rect
			var bar_panel = hotbar.get_node_or_null("BarPanel")
			if bar_panel is Control:
				var panel_rect: Rect2 = bar_panel.get_global_rect()
				if panel_rect.size.x > 1.0 and panel_rect.size.y > 1.0:
					return panel_rect
			var hotbar_rect: Rect2 = hotbar.get_global_rect()
			if hotbar_rect.size.x > 1.0 and hotbar_rect.size.y > 1.0:
				return hotbar_rect

	var fallback_size: Vector2 = Vector2(FALLBACK_HOTBAR_WIDTH, FALLBACK_HOTBAR_HEIGHT)
	return Rect2(
		Vector2((screen_size.x - fallback_size.x) * 0.5, screen_size.y - fallback_size.y),
		fallback_size
	)


func _set_action_rect(action: String, button_position: Vector2, button_size: Vector2, icon_padding: float):
	var button = action_buttons.get(action, null)
	if not (button is Panel):
		return

	_set_button_rect(button, button_position, button_size)
	_set_icon_padding(button, icon_padding)


func is_gameplay_control_at_point(point: Vector2) -> bool:
	if not is_visible_in_tree():
		return false

	for action in CONTROL_ACTIONS:
		var button_value: Variant = action_buttons.get(action, null)
		if not (button_value is Control):
			continue
		var button := button_value as Control
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true

	return false


func _set_button_rect(button: Control, button_position: Vector2, button_size: Vector2):
	button.offset_left = round(button_position.x)
	button.offset_top = round(button_position.y)
	button.offset_right = round(button_position.x + button_size.x)
	button.offset_bottom = round(button_position.y + button_size.y)


func _set_icon_padding(button: Control, icon_padding: float):
	var icon = button.get_node_or_null("Icon")
	if icon == null or not (icon is Control):
		return

	var padding = round(icon_padding)
	icon.offset_left = padding
	icon.offset_top = padding
	icon.offset_right = -padding
	icon.offset_bottom = -padding


func _build_editor_ui() -> void:
	if editor_overlay != null:
		return

	editor_overlay = ColorRect.new()
	editor_overlay.name = "LayoutEditorOverlay"
	editor_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	editor_overlay.offset_left = 0.0
	editor_overlay.offset_top = 0.0
	editor_overlay.offset_right = 0.0
	editor_overlay.offset_bottom = 0.0
	editor_overlay.color = Color(0.0, 0.02, 0.04, 0.34)
	editor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_overlay.z_index = -10
	editor_overlay.visible = false
	add_child(editor_overlay)
	move_child(editor_overlay, 0)

	editor_safe_area_outline = Panel.new()
	editor_safe_area_outline.name = "SafeAreaOutline"
	editor_safe_area_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_safe_area_outline.z_index = 1
	var safe_area_style := StyleBoxFlat.new()
	safe_area_style.bg_color = Color(0.02, 0.12, 0.16, 0.10)
	safe_area_style.border_color = Color(0.48, 0.90, 1.0, 0.56)
	safe_area_style.set_border_width_all(2)
	safe_area_style.set_corner_radius_all(8)
	editor_safe_area_outline.add_theme_stylebox_override("panel", safe_area_style)
	editor_overlay.add_child(editor_safe_area_outline)

	editor_toolbar = PanelContainer.new()
	editor_toolbar.name = "LayoutEditorToolbar"
	editor_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_toolbar.z_index = 20
	editor_toolbar.visible = false
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.015, 0.07, 0.10, 0.96)
	toolbar_style.border_color = Color(0.32, 0.78, 0.95, 0.92)
	toolbar_style.set_border_width_all(3)
	toolbar_style.set_corner_radius_all(10)
	toolbar_style.content_margin_left = 12.0
	toolbar_style.content_margin_right = 12.0
	toolbar_style.content_margin_top = 8.0
	toolbar_style.content_margin_bottom = 8.0
	editor_toolbar.add_theme_stylebox_override("panel", toolbar_style)
	add_child(editor_toolbar)

	var toolbar_content := VBoxContainer.new()
	toolbar_content.add_theme_constant_override("separation", 6)
	editor_toolbar.add_child(toolbar_content)

	editor_instruction_label = Label.new()
	editor_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	editor_instruction_label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	editor_instruction_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	editor_instruction_label.add_theme_constant_override("shadow_offset_x", 2)
	editor_instruction_label.add_theme_constant_override("shadow_offset_y", 2)
	editor_instruction_label.add_theme_font_size_override("font_size", 17)
	toolbar_content.add_child(editor_instruction_label)

	var toolbar_buttons := HBoxContainer.new()
	toolbar_buttons.add_theme_constant_override("separation", 8)
	toolbar_content.add_child(toolbar_buttons)

	toolbar_buttons.add_child(_create_editor_toolbar_button("SIZE -", _on_editor_smaller_pressed))
	toolbar_buttons.add_child(_create_editor_toolbar_button("SIZE +", _on_editor_bigger_pressed))
	toolbar_buttons.add_child(_create_editor_toolbar_button("DEFAULTS", reset_layout_customization))
	toolbar_buttons.add_child(_create_editor_toolbar_button("CANCEL", cancel_layout_customization, Color(0.48, 0.15, 0.17)))
	toolbar_buttons.add_child(_create_editor_toolbar_button("SAVE", save_layout_customization, Color(0.08, 0.38, 0.24)))


func _create_editor_toolbar_button(text_value: String, callback: Callable, base_color := Color(0.06, 0.25, 0.34)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = base_color
	normal_style.border_color = base_color.lightened(0.42)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = base_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = base_color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	return button


func _layout_editor_ui(safe_rect: Rect2) -> void:
	if not layout_customization_active:
		return
	if editor_overlay == null or editor_toolbar == null or editor_safe_area_outline == null:
		return

	_set_button_rect(editor_safe_area_outline, safe_rect.position, safe_rect.size)

	var toolbar_width := minf(720.0, maxf(1.0, safe_rect.size.x - EDITOR_TOOLBAR_MARGIN * 2.0))
	var toolbar_position := Vector2(
		safe_rect.get_center().x - toolbar_width * 0.5,
		safe_rect.position.y + EDITOR_TOOLBAR_MARGIN
	)
	_set_button_rect(editor_toolbar, toolbar_position, Vector2(toolbar_width, EDITOR_TOOLBAR_HEIGHT))


func begin_layout_customization() -> bool:
	if layout_customization_active:
		return true
	if not _is_mobile_platform() or world == null or not bool(world.get("in_world")):
		return false

	_layout_controls()
	layout_snapshot = _duplicate_layout(control_layout)
	snapshot_had_custom_layout = has_custom_layout
	layout_save_as_defaults = not has_custom_layout
	control_layout = _capture_current_layout()
	has_custom_layout = not control_layout.is_empty()

	layout_customization_active = true
	_move_to_layout_editor_layer()
	selected_layout_action = "move_left"
	active_layout_touch_index = -1
	active_layout_mouse = false
	active_layout_action = ""
	_release_all_actions()
	_layout_controls()
	_clamp_custom_controls_to_editor_bounds()
	_refresh_all_button_styles()
	_update_editor_instruction()
	_update_visibility()
	return true


func save_layout_customization() -> bool:
	if not layout_customization_active:
		return false
	var saving_adaptive_defaults := layout_save_as_defaults
	if not _save_layout_preferences():
		if editor_instruction_label != null:
			editor_instruction_label.text = "Could not save. Please try again."
		return false

	if saving_adaptive_defaults:
		control_layout.clear()
		has_custom_layout = false
	_finish_layout_customization(true)
	return true


func cancel_layout_customization() -> void:
	if not layout_customization_active:
		return

	control_layout = _duplicate_layout(layout_snapshot)
	has_custom_layout = snapshot_had_custom_layout
	_finish_layout_customization(false)


func reset_layout_customization() -> void:
	if not layout_customization_active:
		return

	control_layout.clear()
	has_custom_layout = false
	layout_save_as_defaults = true
	active_layout_touch_index = -1
	active_layout_mouse = false
	active_layout_action = ""
	_layout_controls()
	control_layout = _capture_current_layout()
	has_custom_layout = not control_layout.is_empty()
	_layout_controls()
	_clamp_custom_controls_to_editor_bounds()
	_refresh_all_button_styles()
	_update_editor_instruction()


func is_layout_customization_active() -> bool:
	return layout_customization_active


func _finish_layout_customization(saved: bool) -> void:
	layout_customization_active = false
	layout_snapshot.clear()
	snapshot_had_custom_layout = false
	layout_save_as_defaults = false
	selected_layout_action = ""
	active_layout_touch_index = -1
	active_layout_mouse = false
	active_layout_action = ""
	_restore_from_layout_editor_layer()
	_layout_controls()
	_release_all_actions()
	_refresh_all_button_styles()
	_update_visibility()
	layout_customization_finished.emit(saved)


func _move_to_layout_editor_layer() -> void:
	layout_editor_normal_parent = get_parent()
	layout_editor_normal_z_index = z_index
	layout_editor_normal_child_index = get_index()

	var editor_parent: Node = null
	if world != null and world.has_method("get_ui_modal_layer"):
		editor_parent = world.call("get_ui_modal_layer") as Node
	if editor_parent != null and editor_parent != get_parent():
		reparent(editor_parent)

	_configure_root()
	z_index = 300


func _restore_from_layout_editor_layer() -> void:
	var target_parent := layout_editor_normal_parent
	var target_child_index := layout_editor_normal_child_index
	var target_z_index := layout_editor_normal_z_index
	if target_parent != null and is_instance_valid(target_parent) and target_parent != get_parent():
		reparent(target_parent)
		if target_child_index >= 0:
			target_parent.move_child(self, mini(target_child_index, target_parent.get_child_count() - 1))

	_configure_root()
	z_index = target_z_index
	layout_editor_normal_parent = null
	layout_editor_normal_child_index = -1


func _on_editor_smaller_pressed() -> void:
	_resize_selected_control(-CUSTOM_SIZE_STEP)


func _on_editor_bigger_pressed() -> void:
	_resize_selected_control(CUSTOM_SIZE_STEP)


func _resize_selected_control(scale_delta: float) -> void:
	if not layout_customization_active or not CONTROL_ACTIONS.has(selected_layout_action):
		return

	_ensure_working_custom_layout()
	var layout_entry: Dictionary = control_layout.get(selected_layout_action, {})
	var old_scale := float(layout_entry.get("scale", 1.0))
	layout_entry["scale"] = snappedf(clampf(old_scale + scale_delta, CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX), CUSTOM_SIZE_STEP)
	control_layout[selected_layout_action] = layout_entry
	_layout_controls()
	_clamp_custom_controls_to_editor_bounds()
	_refresh_all_button_styles()
	_update_editor_instruction()


func _ensure_working_custom_layout() -> void:
	layout_save_as_defaults = false
	if has_custom_layout:
		return

	_layout_controls()
	control_layout = _capture_current_layout()
	has_custom_layout = true
	_clamp_custom_controls_to_editor_bounds()


func _clamp_custom_controls_to_editor_bounds() -> void:
	if not layout_customization_active or not has_custom_layout:
		return

	var screen_size := get_viewport_rect().size
	var safe_rect := _get_safe_layout_rect(screen_size)
	var editor_bounds := _get_editor_control_bounds(safe_rect)
	var layout_changed := false
	for action in CONTROL_ACTIONS:
		var button_value: Variant = action_buttons.get(action, null)
		var layout_value: Variant = control_layout.get(action, null)
		if not (button_value is Control) or not (layout_value is Dictionary):
			continue

		var button: Control = button_value
		var clamped_position := _clamp_button_position(button.position, button.size, editor_bounds)
		if clamped_position.is_equal_approx(button.position):
			continue

		var normalized_center := (clamped_position + button.size * 0.5 - safe_rect.position) / safe_rect.size
		normalized_center.x = clampf(normalized_center.x, 0.0, 1.0)
		normalized_center.y = clampf(normalized_center.y, 0.0, 1.0)
		var layout_entry: Dictionary = layout_value
		layout_entry["center"] = normalized_center
		control_layout[action] = layout_entry
		layout_changed = true

	if layout_changed:
		_layout_controls()


func _capture_current_layout() -> Dictionary:
	var captured_layout: Dictionary = {}
	var screen_size := get_viewport_rect().size
	var safe_rect := _get_safe_layout_rect(screen_size)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return captured_layout

	for action in CONTROL_ACTIONS:
		var button_value: Variant = action_buttons.get(action, null)
		if not (button_value is Control):
			continue

		var button: Control = button_value
		var button_center := button.position + button.size * 0.5
		var normalized_center := (button_center - safe_rect.position) / safe_rect.size
		normalized_center.x = clampf(normalized_center.x, 0.0, 1.0)
		normalized_center.y = clampf(normalized_center.y, 0.0, 1.0)

		var existing_scale := 1.0
		var existing_value: Variant = control_layout.get(action, null)
		if existing_value is Dictionary:
			existing_scale = clampf(float(existing_value.get("scale", 1.0)), CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX)

		captured_layout[action] = {
			"center": normalized_center,
			"scale": existing_scale
		}

	return captured_layout


func _duplicate_layout(source_layout: Dictionary) -> Dictionary:
	var copied_layout: Dictionary = {}
	for action_value in source_layout.keys():
		var action := str(action_value)
		var layout_value: Variant = source_layout.get(action_value, null)
		if layout_value is Dictionary:
			copied_layout[action] = layout_value.duplicate(true)
	return copied_layout


func _load_layout_preferences() -> void:
	control_layout.clear()
	has_custom_layout = false
	layout_save_as_defaults = false

	var cfg := ConfigFile.new()
	if cfg.load(settings_save_path) != OK:
		return
	if int(cfg.get_value(SETTINGS_SECTION, "layout_version", 0)) != LAYOUT_VERSION:
		return
	if not bool(cfg.get_value(SETTINGS_SECTION, "customized", false)):
		return

	for action in CONTROL_ACTIONS:
		var center_key: String = str(action) + "_center"
		if not cfg.has_section_key(SETTINGS_SECTION, center_key):
			continue
		var center_value: Variant = cfg.get_value(SETTINGS_SECTION, center_key)
		if typeof(center_value) != TYPE_VECTOR2:
			continue

		var normalized_center: Vector2 = center_value
		normalized_center.x = clampf(normalized_center.x, 0.0, 1.0)
		normalized_center.y = clampf(normalized_center.y, 0.0, 1.0)
		control_layout[action] = {
			"center": normalized_center,
			"scale": clampf(
				float(cfg.get_value(SETTINGS_SECTION, action + "_scale", 1.0)),
				CUSTOM_SIZE_MIN,
				CUSTOM_SIZE_MAX
			)
		}

	has_custom_layout = not control_layout.is_empty()


func _save_layout_preferences() -> bool:
	var cfg := ConfigFile.new()
	var load_result := cfg.load(settings_save_path)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_warning("MobileControls: could not read the existing settings file, so it was not overwritten.")
		return false
	if cfg.has_section(SETTINGS_SECTION):
		cfg.erase_section(SETTINGS_SECTION)

	if has_custom_layout and not layout_save_as_defaults:
		cfg.set_value(SETTINGS_SECTION, "layout_version", LAYOUT_VERSION)
		cfg.set_value(SETTINGS_SECTION, "customized", true)
		for action in CONTROL_ACTIONS:
			var layout_value: Variant = control_layout.get(action, null)
			if not (layout_value is Dictionary):
				continue

			var layout_entry: Dictionary = layout_value
			var center_value: Variant = layout_entry.get("center", null)
			if typeof(center_value) != TYPE_VECTOR2:
				continue

			cfg.set_value(SETTINGS_SECTION, action + "_center", center_value)
			cfg.set_value(
				SETTINGS_SECTION,
				action + "_scale",
				clampf(float(layout_entry.get("scale", 1.0)), CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX)
			)

	var save_result := cfg.save(settings_save_path)
	if save_result != OK:
		push_warning("MobileControls: failed to save the customized mobile control layout.")
		return false

	return true


func _handle_layout_editor_global_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == active_layout_touch_index:
		active_layout_touch_index = -1
		active_layout_action = ""
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		active_layout_mouse = false
		active_layout_action = ""


func _handle_layout_editor_button_input(event: InputEvent, action: String) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_layout_touch_index != -1 and active_layout_touch_index != event.index:
				accept_event()
				return
			selected_layout_action = action
			active_layout_action = action
			active_layout_touch_index = event.index
			_refresh_all_button_styles()
			_update_editor_instruction()
		elif active_layout_touch_index == event.index:
			active_layout_touch_index = -1
			active_layout_action = ""
		accept_event()
		return

	if event is InputEventScreenDrag and event.index == active_layout_touch_index and active_layout_action == action:
		_move_layout_control(action, event.relative)
		accept_event()
		return

	if (
		(event is InputEventMouseButton or event is InputEventMouseMotion)
		and (event.device == InputEvent.DEVICE_ID_EMULATION or active_layout_touch_index != -1)
	):
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected_layout_action = action
			active_layout_action = action
			active_layout_mouse = true
			_refresh_all_button_styles()
			_update_editor_instruction()
		else:
			active_layout_mouse = false
			active_layout_action = ""
		accept_event()
		return

	if event is InputEventMouseMotion and active_layout_mouse and active_layout_action == action:
		_move_layout_control(action, event.relative)
		accept_event()


func _move_layout_control(action: String, movement_delta: Vector2) -> void:
	var button_value: Variant = action_buttons.get(action, null)
	if not (button_value is Control):
		return

	_ensure_working_custom_layout()
	var button: Control = button_value
	var screen_size := get_viewport_rect().size
	var safe_rect := _get_safe_layout_rect(screen_size)
	var editor_bounds := _get_editor_control_bounds(safe_rect)
	var new_position := _clamp_button_position(button.position + movement_delta, button.size, editor_bounds)
	var new_center := new_position + button.size * 0.5
	var normalized_center := (new_center - safe_rect.position) / safe_rect.size
	normalized_center.x = clampf(normalized_center.x, 0.0, 1.0)
	normalized_center.y = clampf(normalized_center.y, 0.0, 1.0)

	var layout_entry: Dictionary = control_layout.get(action, {})
	layout_entry["center"] = normalized_center
	layout_entry["scale"] = clampf(float(layout_entry.get("scale", 1.0)), CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX)
	control_layout[action] = layout_entry
	_layout_controls()


func _update_editor_instruction() -> void:
	if editor_instruction_label == null:
		return

	var control_label := str(CONTROL_LABELS.get(selected_layout_action, "CONTROL"))
	var scale_value := 1.0
	var layout_value: Variant = control_layout.get(selected_layout_action, null)
	if has_custom_layout and layout_value is Dictionary:
		scale_value = clampf(float(layout_value.get("scale", 1.0)), CUSTOM_SIZE_MIN, CUSTOM_SIZE_MAX)

	editor_instruction_label.text = "Drag %s to move it  |  Size %d%%" % [
		control_label,
		int(roundf(scale_value * 100.0))
	]


func _refresh_all_button_styles() -> void:
	for action in CONTROL_ACTIONS:
		var button_value: Variant = action_buttons.get(action, null)
		if button_value is Panel:
			_apply_button_style(button_value, false)


func _on_hold_button_gui_input(event: InputEvent, action: String):
	if layout_customization_active:
		_handle_layout_editor_button_input(event, action)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_press_action(action)
			active_action_touches[action] = event.index
		elif active_action_touches.get(action, -1) == event.index:
			_release_action(action)
		accept_event()
		return

	if not _is_mobile_platform() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_action(action)
			active_action_mouse[action] = true
		else:
			_release_action(action)
		accept_event()


func _on_punch_button_gui_input(event: InputEvent):
	if layout_customization_active:
		_handle_layout_editor_button_input(event, "punch")
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if not _is_punch_held():
				_begin_punch_hold(event.index)
		elif active_action_touches.get("punch", -1) == event.index:
			_release_action("punch")
		accept_event()
		return

	if not _is_mobile_platform() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _is_punch_held():
				_begin_punch_hold(-1, true)
		elif bool(active_action_mouse.get("punch", false)):
			_release_action("punch")
		accept_event()


func _on_zoom_button_gui_input(event: InputEvent, action: String):
	if layout_customization_active:
		_handle_layout_editor_button_input(event, action)
		return

	if event is InputEventScreenTouch and event.pressed:
		_trigger_zoom(action)
		_flash_button(action)
		accept_event()
	elif not _is_mobile_platform() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_zoom(action)
		_flash_button(action)
		accept_event()


func _begin_punch_hold(touch_index: int = -1, use_mouse: bool = false) -> void:
	punch_action_release_generation += 1
	punch_hold_timer = 0.0
	punch_hold_repeat_active = false
	_press_action("punch")

	if touch_index >= 0:
		active_action_touches["punch"] = touch_index
	elif use_mouse:
		active_action_mouse["punch"] = true

	_trigger_punch(false)


func _is_punch_held() -> bool:
	return active_action_touches.has("punch") or bool(active_action_mouse.get("punch", false))


func _update_punch_hold(delta: float) -> void:
	if not _is_punch_held():
		return

	if world == null or not bool(world.get("in_world")) or not visible:
		_release_action("punch")
		return

	punch_hold_timer += delta
	var repeat_delay: float = PUNCH_HOLD_REPEAT_RATE if punch_hold_repeat_active else PUNCH_HOLD_INITIAL_DELAY
	if punch_hold_timer < repeat_delay:
		return

	punch_hold_timer = 0.0
	punch_hold_repeat_active = true
	_trigger_punch(false)


func _trigger_punch(pulse_input_action: bool = true):
	_queue_player_input_punch_pulse()
	if pulse_input_action:
		_pulse_punch_action()

	if world != null and world.has_method("play_player_punch_animation"):
		world.play_player_punch_animation()

	if world != null and world.has_method("punch_facing_reach_block"):
		world.punch_facing_reach_block()
	elif world != null and world.has_method("punch_facing_block"):
		world.punch_facing_block()


func _queue_player_input_punch_pulse() -> void:
	if world == null:
		return

	var player_node = world.get("player")
	if player_node == null or not (player_node is Node):
		return

	var player_input = player_node.get_node_or_null("PlayerInput")
	if player_input != null and player_input.has_method("queue_punch_press"):
		player_input.queue_punch_press()


func _pulse_punch_action() -> void:
	if not InputMap.has_action("punch"):
		return

	punch_action_release_generation += 1
	var release_generation := punch_action_release_generation
	Input.action_press("punch")
	_release_punch_action_after_input_sample(release_generation)


func _release_punch_action_after_input_sample(release_generation: int) -> void:
	if get_tree() == null:
		return

	await get_tree().physics_frame
	if get_tree() == null:
		return

	await get_tree().process_frame
	if release_generation != punch_action_release_generation:
		return

	Input.action_release("punch")


func _trigger_zoom(action: String):
	if world == null or not world.has_method("zoom_camera"):
		return

	if world.has_method("can_use_camera_zoom") and not bool(world.can_use_camera_zoom()):
		return

	var step = float(world.CAMERA_ZOOM_STEP) if "CAMERA_ZOOM_STEP" in world else 0.12
	if action == "zoom_out":
		step = -step

	world.zoom_camera(step)


func _press_action(action: String):
	if not HELD_ACTIONS.has(action):
		return

	if InputMap.has_action(action):
		Input.action_press(action)
	_set_button_pressed(action, true)


func _release_action(action: String):
	if not HELD_ACTIONS.has(action):
		return

	if action == "punch":
		punch_action_release_generation += 1
		punch_hold_timer = 0.0
		punch_hold_repeat_active = false

	if InputMap.has_action(action):
		Input.action_release(action)
	active_action_touches.erase(action)
	active_action_mouse.erase(action)
	_set_button_pressed(action, false)


func _release_touch_index(touch_index: int):
	for action in active_action_touches.keys().duplicate():
		if active_action_touches.get(action, -1) == touch_index:
			_release_action(action)


func _release_mouse_actions():
	for action in active_action_mouse.keys().duplicate():
		_release_action(action)


func _release_all_actions():
	punch_action_release_generation += 1
	punch_hold_timer = 0.0
	punch_hold_repeat_active = false

	for action in HELD_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
		_set_button_pressed(action, false)

	active_action_touches.clear()
	active_action_mouse.clear()


func _set_button_pressed(action: String, pressed: bool):
	var button = action_buttons.get(action, null)
	if button is Panel:
		_apply_button_style(button, pressed)


func _flash_button(action: String):
	_set_button_pressed(action, true)
	await get_tree().create_timer(0.08).timeout
	_set_button_pressed(action, false)


func _apply_button_style(button: Panel, pressed: bool):
	var style = StyleBoxFlat.new()
	var action := str(button.get_meta("mobile_control_action", ""))
	var is_selected := layout_customization_active and action == selected_layout_action
	if is_selected:
		style.bg_color = Color(0.16, 0.42, 0.52, 0.92)
		style.border_color = Color(1.0, 0.84, 0.24, 1.0)
		style.set_border_width_all(5)
	elif layout_customization_active:
		style.bg_color = Color(0.04, 0.16, 0.20, 0.86)
		style.border_color = Color(0.68, 0.92, 1.0, 0.80)
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.05, 0.10, 0.13, 0.68) if not pressed else Color(0.16, 0.50, 0.70, 0.84)
		style.border_color = Color(0.85, 0.95, 1.0, 0.48) if not pressed else Color(1.0, 1.0, 1.0, 0.86)
		style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("panel", style)
	_apply_button_icon(button, action, pressed)


func _apply_button_icon(button: Panel, action: String, pressed: bool) -> void:
	var icon := button.get_node_or_null("Icon") as TextureRect
	if icon == null:
		return

	icon.texture = _get_action_icon_texture(action, pressed and not layout_customization_active)


func _get_action_icon_texture(action: String, pressed: bool) -> Texture2D:
	var texture_path := _get_action_icon_path(action, pressed)
	if texture_path == "":
		return null
	if icon_texture_cache.has(texture_path):
		return icon_texture_cache[texture_path] as Texture2D
	if not ResourceLoader.exists(texture_path):
		if pressed:
			return _get_action_icon_texture(action, false)
		return null

	var loaded_texture := load(texture_path)
	if loaded_texture is Texture2D:
		icon_texture_cache[texture_path] = loaded_texture
		return loaded_texture

	return null


func _get_action_icon_path(action: String, pressed: bool) -> String:
	if pressed:
		var pressed_path := str(PRESSED_ICON_PATHS.get(action, ""))
		if pressed_path != "":
			return pressed_path

	return str(ICON_PATHS.get(action, ""))


func _update_visibility():
	var should_show = _should_show_controls()
	if visible != should_show and not should_show:
		_release_all_actions()

	visible = should_show
	if editor_overlay != null:
		editor_overlay.visible = layout_customization_active
	if editor_toolbar != null:
		editor_toolbar.visible = layout_customization_active


func _should_show_controls() -> bool:
	if world == null:
		return false

	if not bool(world.get("in_world")):
		return false

	if layout_customization_active:
		return _is_mobile_platform()

	if world.has_method("is_movement_locked") and bool(world.is_movement_locked()):
		return false

	return _is_mobile_platform()


func _is_mobile_platform() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
