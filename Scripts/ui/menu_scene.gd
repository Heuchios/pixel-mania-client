extends Control
class_name PixelGameMenuScene

signal close_pressed
signal back_pressed
signal action_pressed(action_id: String, index: int, action_data: Resource)
signal player_info_pressed
signal friends_pressed
signal respawn_pressed
signal settings_pressed
signal lobby_pressed

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const MenuButtonDataScript = preload("res://Scripts/ui/menu_button_data.gd")

const PLAYER_INFO_ICON_PATH := "res://Assets/ui/icons/player_info.png"
const FRIENDS_ICON_PATH := "res://Assets/ui/icons/friends.png"
const RESPAWN_ICON_PATH := "res://Assets/ui/icons/respawn.png"
const SETTINGS_ICON_PATH := "res://Assets/ui/icons/settings.png"
const LOBBY_ICON_PATH := "res://Assets/ui/icons/lobby.png"

@export_category("How To Customize")
@export_multiline var editor_note: String = "This menu is intentionally scene-authored. Edit the actual child nodes, labels, panels, buttons, positions, sizes, and icon TextureRects directly in the Scene tree. The Apply Exported Content/Styles/Layout toggles default off so your direct edits stay untouched; turn them on only when you want inspector-driven preview values to rewrite the nodes."

@export_category("Content")
@export var title_text: String = "MENU":
	set(value):
		title_text = value
		_queue_refresh()
@export var subtitle_text: String = "GAME OPTIONS":
	set(value):
		subtitle_text = value
		_queue_refresh()
@export var close_button_text: String = "X":
	set(value):
		close_button_text = value
		_queue_refresh()
@export var back_button_text: String = "BACK":
	set(value):
		back_button_text = value
		_queue_refresh()
@export var menu_actions: Array[Resource] = []:
	set(value):
		menu_actions = value
		_queue_refresh()
@export var show_sample_actions_when_empty: bool = true:
	set(value):
		show_sample_actions_when_empty = value
		_queue_refresh()
@export var show_action_labels: bool = false:
	set(value):
		show_action_labels = value
		_queue_refresh()
@export var apply_exported_content_on_ready: bool = false:
	set(value):
		apply_exported_content_on_ready = value
		_queue_refresh()
@export var apply_exported_styles_on_ready: bool = false:
	set(value):
		apply_exported_styles_on_ready = value
		_queue_refresh()
@export var apply_exported_layout_on_ready: bool = false:
	set(value):
		apply_exported_layout_on_ready = value
		_queue_refresh()

@export_category("Behavior")
@export var start_hidden: bool = false
@export var close_button_hides_scene: bool = true
@export var back_button_hides_scene: bool = true
@export var auto_close_on_action_pressed: bool = false
@export var play_open_animation: bool = true
@export var show_dimmer: bool = true:
	set(value):
		show_dimmer = value
		_queue_refresh()
@export var show_close_button: bool = true:
	set(value):
		show_close_button = value
		_queue_refresh()
@export var show_back_button: bool = true:
	set(value):
		show_back_button = value
		_queue_refresh()
@export var show_gloss_details: bool = true:
	set(value):
		show_gloss_details = value
		_queue_refresh()
@export var show_icon_shadows: bool = true:
	set(value):
		show_icon_shadows = value
		_queue_refresh()
@export var auto_fit_to_viewport: bool = true:
	set(value):
		auto_fit_to_viewport = value
		_queue_refresh()

@export_category("Layout")
@export var center_window_in_viewport: bool = true:
	set(value):
		center_window_in_viewport = value
		_queue_refresh()
@export var window_size: Vector2 = Vector2(460.0, 560.0):
	set(value):
		window_size = value
		_queue_refresh()
@export var viewport_margin: Vector2 = Vector2(32.0, 32.0):
	set(value):
		viewport_margin = value
		_queue_refresh()
@export var shadow_offset: Vector2 = Vector2(11.0, 14.0):
	set(value):
		shadow_offset = value
		_queue_refresh()
@export var highlight_inset: float = 6.0:
	set(value):
		highlight_inset = value
		_queue_refresh()
@export var header_rect: Rect2 = Rect2(8.0, 8.0, 444.0, 84.0):
	set(value):
		header_rect = value
		_queue_refresh()
@export var title_rect: Rect2 = Rect2(28.0, 10.0, 260.0, 52.0):
	set(value):
		title_rect = value
		_queue_refresh()
@export var subtitle_rect: Rect2 = Rect2(34.0, 60.0, 260.0, 22.0):
	set(value):
		subtitle_rect = value
		_queue_refresh()
@export var close_button_rect: Rect2 = Rect2(374.0, 20.0, 54.0, 50.0):
	set(value):
		close_button_rect = value
		_queue_refresh()
@export var body_shadow_rect: Rect2 = Rect2(42.0, 118.0, 376.0, 360.0):
	set(value):
		body_shadow_rect = value
		_queue_refresh()
@export var body_rect: Rect2 = Rect2(34.0, 110.0, 392.0, 366.0):
	set(value):
		body_rect = value
		_queue_refresh()
@export var actions_origin: Vector2 = Vector2(24.0, 22.0):
	set(value):
		actions_origin = value
		_queue_refresh()
@export var action_button_size: Vector2 = Vector2(344.0, 54.0):
	set(value):
		action_button_size = value
		_queue_refresh()
@export_range(0.0, 40.0, 1.0) var action_button_gap: float = 14.0:
	set(value):
		action_button_gap = value
		_queue_refresh()
@export var action_icon_size: Vector2 = Vector2(42.0, 42.0):
	set(value):
		action_icon_size = value
		_queue_refresh()
@export var action_label_rect: Rect2 = Rect2(84.0, 8.0, 220.0, 38.0):
	set(value):
		action_label_rect = value
		_queue_refresh()
@export var back_button_rect: Rect2 = Rect2(58.0, 492.0, 344.0, 48.0):
	set(value):
		back_button_rect = value
		_queue_refresh()

@export_category("Textures")
@export var player_info_icon_texture: Texture2D = preload("res://Assets/ui/icons/player_info.png"):
	set(value):
		player_info_icon_texture = value
		_queue_refresh()
@export var friends_icon_texture: Texture2D = preload("res://Assets/ui/icons/friends.png"):
	set(value):
		friends_icon_texture = value
		_queue_refresh()
@export var respawn_icon_texture: Texture2D = preload("res://Assets/ui/icons/respawn.png"):
	set(value):
		respawn_icon_texture = value
		_queue_refresh()
@export var settings_icon_texture: Texture2D = preload("res://Assets/ui/icons/settings.png"):
	set(value):
		settings_icon_texture = value
		_queue_refresh()
@export var lobby_icon_texture: Texture2D = preload("res://Assets/ui/icons/lobby.png"):
	set(value):
		lobby_icon_texture = value
		_queue_refresh()

@export_category("Colors")
@export var dimmer_color: Color = Color(0.0, 0.0, 0.0, 0.50):
	set(value):
		dimmer_color = value
		_queue_refresh()
@export var panel_fill_color: Color = Color(0.060, 0.135, 0.200, 0.62):
	set(value):
		panel_fill_color = value
		_queue_refresh()
@export var panel_border_color: Color = Color(0.420, 0.780, 1.000, 0.66):
	set(value):
		panel_border_color = value
		_queue_refresh()
@export var header_fill_color: Color = Color(0.070, 0.150, 0.235, 0.62):
	set(value):
		header_fill_color = value
		_queue_refresh()
@export var body_fill_color: Color = Color(0.820, 0.940, 1.000, 0.105):
	set(value):
		body_fill_color = value
		_queue_refresh()
@export var title_color: Color = Color.WHITE:
	set(value):
		title_color = value
		_queue_refresh()
@export var subtitle_color: Color = Color(0.86, 0.96, 1.0, 1.0):
	set(value):
		subtitle_color = value
		_queue_refresh()
@export var action_label_color: Color = Color.WHITE:
	set(value):
		action_label_color = value
		_queue_refresh()
@export var blue_button_color: Color = Color(0.10, 0.24, 0.34, 0.58):
	set(value):
		blue_button_color = value
		_queue_refresh()
@export var blue_button_hover_color: Color = Color(0.16, 0.34, 0.46, 0.74):
	set(value):
		blue_button_hover_color = value
		_queue_refresh()
@export var blue_button_pressed_color: Color = Color(0.07, 0.18, 0.27, 0.78):
	set(value):
		blue_button_pressed_color = value
		_queue_refresh()
@export var blue_button_border_color: Color = Color(0.42, 0.78, 1.0, 0.42):
	set(value):
		blue_button_border_color = value
		_queue_refresh()
@export var selected_button_color: Color = Color(1.0, 0.84, 0.05, 1.0):
	set(value):
		selected_button_color = value
		_queue_refresh()
@export var selected_button_border_color: Color = Color(0.96, 0.50, 0.02, 1.0):
	set(value):
		selected_button_border_color = value
		_queue_refresh()
@export var close_button_color: Color = Color(0.66, 0.10, 0.16, 0.92):
	set(value):
		close_button_color = value
		_queue_refresh()
@export var close_button_border_color: Color = Color(1.0, 0.34, 0.38, 0.54):
	set(value):
		close_button_border_color = value
		_queue_refresh()
@export var gloss_color: Color = Color(0.80, 0.96, 1.0, 0.22):
	set(value):
		gloss_color = value
		_queue_refresh()
@export var icon_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.38):
	set(value):
		icon_shadow_color = value
		_queue_refresh()

@export_category("Typography")
@export_range(18, 72, 1) var title_font_size: int = 48:
	set(value):
		title_font_size = value
		_queue_refresh()
@export_range(10, 36, 1) var subtitle_font_size: int = 14:
	set(value):
		subtitle_font_size = value
		_queue_refresh()
@export_range(10, 36, 1) var action_font_size: int = 18:
	set(value):
		action_font_size = value
		_queue_refresh()
@export_range(10, 36, 1) var back_font_size: int = 18:
	set(value):
		back_font_size = value
		_queue_refresh()
@export_range(10, 36, 1) var close_font_size: int = 24:
	set(value):
		close_font_size = value
		_queue_refresh()

@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect
@onready var center_container: CenterContainer = get_node_or_null("CenterContainer") as CenterContainer
@onready var menu_window: Control = get_node_or_null("CenterContainer/MenuWindow") as Control
@onready var header_panel: Panel = get_node_or_null("CenterContainer/MenuWindow/Header") as Panel
@onready var body_panel: Panel = get_node_or_null("CenterContainer/MenuWindow/BodyPanel") as Panel
@onready var actions_root: Control = get_node_or_null("CenterContainer/MenuWindow/BodyPanel/ActionsRoot") as Control
@onready var back_button: Button = get_node_or_null("CenterContainer/MenuWindow/BackButton") as Button
@onready var close_button: Button = get_node_or_null("CenterContainer/MenuWindow/CloseButton") as Button

var _refresh_queued := false
var _is_open := true
var _authored_window_scale := Vector2.ONE
var _authored_window_modulate := Color.WHITE
var _is_fitting_overlay := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_is_open = not start_hidden
	if menu_window != null:
		_authored_window_scale = menu_window.scale
		_authored_window_modulate = menu_window.modulate
	_connect_static_buttons()
	fit_overlay_to_viewport()
	refresh_preview()
	if start_hidden:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		fit_overlay_to_viewport()
		if _uses_exported_node_updates():
			_update_window_scale()


func refresh_preview() -> void:
	if not is_inside_tree():
		return
	if apply_exported_layout_on_ready:
		apply_exported_layout()
	if apply_exported_styles_on_ready:
		apply_exported_styles()
	if apply_exported_content_on_ready:
		apply_exported_content()
	if _uses_exported_node_updates():
		_update_visibility_flags()
		_update_window_scale()


func apply_exported_layout() -> void:
	if menu_window == null:
		return

	menu_window.custom_minimum_size = window_size
	menu_window.size = window_size
	menu_window.pivot_offset = window_size * 0.5
	_set_rect("CenterContainer/MenuWindow/DropShadow", Rect2(shadow_offset, window_size))
	_set_rect("CenterContainer/MenuWindow/WindowBack", Rect2(Vector2.ZERO, window_size))
	var inset := maxf(0.0, highlight_inset)
	_set_rect("CenterContainer/MenuWindow/OuterHighlight", Rect2(Vector2(inset, inset), window_size - Vector2(inset * 2.0, inset * 2.0)))
	_set_rect("CenterContainer/MenuWindow/Header", header_rect)
	_set_rect("CenterContainer/MenuWindow/Header/TitleLabel", title_rect)
	_set_rect("CenterContainer/MenuWindow/Header/SubtitleLabel", subtitle_rect)
	_set_rect("CenterContainer/MenuWindow/CloseButton", close_button_rect)
	_set_rect("CenterContainer/MenuWindow/BodyShadow", body_shadow_rect)
	_set_rect("CenterContainer/MenuWindow/BodyPanel", body_rect)
	_set_rect("CenterContainer/MenuWindow/BackButton", back_button_rect)
	_layout_body_details()
	_layout_action_buttons()
	_layout_button_details(back_button)


func apply_exported_content() -> void:
	_set_label_text("CenterContainer/MenuWindow/Header/TitleLabel", title_text)
	_set_label_text("CenterContainer/MenuWindow/Header/SubtitleLabel", subtitle_text)

	if close_button != null:
		close_button.text = close_button_text
	if back_button != null:
		back_button.text = back_button_text

	_apply_actions_content()


func apply_exported_styles() -> void:
	if dimmer != null:
		dimmer.color = dimmer_color

	_style_panel("CenterContainer/MenuWindow/DropShadow", Color(0.0, 0.0, 0.0, 0.32), Color(0.0, 0.0, 0.0, 0.0), 0, 22, 0)
	_style_panel("CenterContainer/MenuWindow/WindowBack", panel_fill_color, panel_border_color, 4, 22, 12)
	_style_panel("CenterContainer/MenuWindow/OuterHighlight", Color(0.0, 0.0, 0.0, 0.0), Color(0.36, 0.74, 1.0, 0.22), 1, 17, 0)
	_style_panel("CenterContainer/MenuWindow/Header", header_fill_color, Color(0.18, 0.46, 0.76, 0.72), 3, 16, 7)
	_style_panel("CenterContainer/MenuWindow/BodyShadow", Color(0.0, 0.0, 0.0, 0.22), Color(0.0, 0.0, 0.0, 0.0), 0, 16, 0)
	_style_panel("CenterContainer/MenuWindow/BodyPanel", body_fill_color, Color(0.18, 0.46, 0.76, 0.72), 3, 14, 8)

	_style_label("CenterContainer/MenuWindow/Header/TitleLabel", title_font_size, title_color, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label("CenterContainer/MenuWindow/Header/SubtitleLabel", subtitle_font_size, subtitle_color, HORIZONTAL_ALIGNMENT_LEFT)

	if close_button != null:
		_apply_button_style(
			close_button,
			close_button_color,
			Color(0.88, 0.16, 0.24, 0.98),
			Color(0.42, 0.04, 0.10, 0.96),
			close_button_border_color,
			close_font_size,
			4,
			12,
			8
		)
	if back_button != null:
		_apply_button_style(
			back_button,
			selected_button_color,
			Color(1.0, 0.94, 0.20, 1.0),
			Color(0.90, 0.58, 0.02, 1.0),
			selected_button_border_color,
			back_font_size,
			5,
			12,
			6
		)

	_apply_actions_style()
	_apply_gloss_style()


func set_actions_from_dictionaries(action_dicts: Array) -> void:
	var parsed_actions: Array[Resource] = []
	for raw_action in action_dicts:
		if raw_action is Dictionary:
			parsed_actions.append(_action_from_dictionary(raw_action))
		elif raw_action is Resource:
			parsed_actions.append(raw_action)

	menu_actions = parsed_actions
	show_sample_actions_when_empty = false
	apply_exported_content()
	apply_exported_styles()


func open_menu() -> void:
	_is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	fit_overlay_to_viewport()
	if _uses_exported_node_updates():
		_update_visibility_flags()
	if menu_window != null and play_open_animation:
		_play_authored_panel_open()


func close_menu() -> void:
	_is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle_menu() -> void:
	if is_open():
		close_menu()
	else:
		open_menu()


func is_open() -> bool:
	return _is_open and visible


func fit_overlay_to_viewport(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if _is_fitting_overlay:
		return

	var target_size := viewport_size
	if (target_size.x <= 0.0 or target_size.y <= 0.0) and is_inside_tree():
		target_size = get_viewport_rect().size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return

	_is_fitting_overlay = true
	_fit_full_rect_control(self, target_size)
	_fit_full_rect_control(dimmer, target_size)
	_fit_full_rect_control(center_container, target_size)
	if center_container != null:
		center_container.queue_sort()
	if center_window_in_viewport:
		_center_menu_window(target_size)
	_is_fitting_overlay = false


func _queue_refresh() -> void:
	if not is_inside_tree():
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	_refresh_queued = false
	refresh_preview()


func _uses_exported_node_updates() -> bool:
	return apply_exported_content_on_ready or apply_exported_styles_on_ready or apply_exported_layout_on_ready


func _fit_full_rect_control(control: Control, target_size: Vector2) -> void:
	if control == null:
		return

	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = target_size.x
	control.offset_bottom = target_size.y
	control.position = Vector2.ZERO
	control.size = target_size


func _center_menu_window(target_size: Vector2) -> void:
	if menu_window == null:
		return

	var panel_size := menu_window.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = menu_window.custom_minimum_size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = window_size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return

	menu_window.position = (target_size - panel_size) * 0.5


func _play_authored_panel_open() -> void:
	if menu_window == null:
		return

	menu_window.pivot_offset = menu_window.size * 0.5
	menu_window.scale = _authored_window_scale * 0.96
	menu_window.modulate = Color(
		_authored_window_modulate.r,
		_authored_window_modulate.g,
		_authored_window_modulate.b,
		0.0
	)
	var tween := menu_window.create_tween()
	tween.set_parallel(true)
	tween.tween_property(menu_window, "scale", _authored_window_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_window, "modulate", _authored_window_modulate, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _connect_static_buttons() -> void:
	if close_button != null:
		var close_callable := Callable(self, "_on_close_pressed")
		if not close_button.pressed.is_connected(close_callable):
			close_button.pressed.connect(close_callable)

	if back_button != null:
		var back_callable := Callable(self, "_on_back_pressed")
		if not back_button.pressed.is_connected(back_callable):
			back_button.pressed.connect(back_callable)

	var action_buttons := _get_action_buttons()
	for i in range(action_buttons.size()):
		var button := action_buttons[i]
		if button == null:
			continue
		var action_callable := Callable(self, "_on_action_button_pressed").bind(i)
		if not button.pressed.is_connected(action_callable):
			button.pressed.connect(action_callable)


func _on_close_pressed() -> void:
	close_pressed.emit()
	if close_button_hides_scene:
		close_menu()


func _on_back_pressed() -> void:
	back_pressed.emit()
	if back_button_hides_scene:
		close_menu()


func _on_action_button_pressed(index: int) -> void:
	var effective_actions := _get_effective_actions()
	if index < 0 or index >= effective_actions.size():
		return

	var action_data: Resource = effective_actions[index]
	var action_id := str(_resource_value(action_data, "action_id", "action_" + str(index))).strip_edges()
	action_pressed.emit(action_id, index, action_data)
	match action_id:
		"player_info":
			player_info_pressed.emit()
		"friends":
			friends_pressed.emit()
		"respawn":
			respawn_pressed.emit()
		"settings":
			settings_pressed.emit()
		"lobby", "main_menu", "worlds":
			lobby_pressed.emit()

	if auto_close_on_action_pressed:
		close_menu()


func _update_visibility_flags() -> void:
	if dimmer != null:
		dimmer.visible = show_dimmer
	if close_button != null:
		close_button.visible = show_close_button
	if back_button != null:
		back_button.visible = show_back_button
	for detail_path in [
		"CenterContainer/MenuWindow/Header/HeaderGloss",
		"CenterContainer/MenuWindow/Header/HeaderSpark",
		"CenterContainer/MenuWindow/BodyPanel/BodyGloss",
		"CenterContainer/MenuWindow/BodyPanel/BodyFloorShade",
	]:
		var detail := get_node_or_null(detail_path) as CanvasItem
		if detail != null:
			detail.visible = show_gloss_details
	_update_icon_shadow_visibility()


func _update_window_scale() -> void:
	if menu_window == null or not auto_fit_to_viewport or not is_inside_tree():
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var available := Vector2(
		max(1.0, viewport_size.x - viewport_margin.x * 2.0),
		max(1.0, viewport_size.y - viewport_margin.y * 2.0)
	)
	var scale_value: float = min(1.0, min(available.x / maxf(1.0, window_size.x), available.y / maxf(1.0, window_size.y)))
	menu_window.scale = Vector2(scale_value, scale_value)
	menu_window.pivot_offset = window_size * 0.5


func _layout_body_details() -> void:
	var body_gloss := get_node_or_null("CenterContainer/MenuWindow/BodyPanel/BodyGloss") as ColorRect
	if body_gloss != null:
		body_gloss.position = Vector2(14.0, 14.0)
		body_gloss.size = Vector2(maxf(1.0, body_rect.size.x - 28.0), 18.0)

	var body_floor := get_node_or_null("CenterContainer/MenuWindow/BodyPanel/BodyFloorShade") as ColorRect
	if body_floor != null:
		body_floor.position = Vector2(16.0, maxf(0.0, body_rect.size.y - 14.0))
		body_floor.size = Vector2(maxf(1.0, body_rect.size.x - 32.0), 4.0)

	if actions_root != null:
		actions_root.position = actions_origin
		actions_root.size = Vector2(maxf(1.0, action_button_size.x), maxf(1.0, action_button_size.y * 5.0 + action_button_gap * 4.0))


func _layout_action_buttons() -> void:
	var action_buttons := _get_action_buttons()
	for i in range(action_buttons.size()):
		var button := action_buttons[i]
		if button == null:
			continue
		button.position = Vector2(0.0, float(i) * (action_button_size.y + action_button_gap))
		button.size = action_button_size
		button.custom_minimum_size = action_button_size
		_layout_action_button_children(button)
		_layout_button_details(button)


func _layout_action_button_children(button: Button) -> void:
	var icon := button.get_node_or_null("Icon") as TextureRect
	var icon_shadow := button.get_node_or_null("IconShadow") as TextureRect
	var label := button.get_node_or_null("ActionLabel") as Label
	var icon_position := Vector2(
		(action_button_size.x - action_icon_size.x) * 0.5,
		(action_button_size.y - action_icon_size.y) * 0.5 - 2.0
	)
	if show_action_labels:
		icon_position = Vector2(24.0, (action_button_size.y - action_icon_size.y) * 0.5)

	if icon != null:
		icon.position = icon_position
		icon.size = action_icon_size
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_shadow != null:
		icon_shadow.position = icon_position + Vector2(4.0, 5.0)
		icon_shadow.size = action_icon_size
		icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label != null:
		label.position = action_label_rect.position
		label.size = action_label_rect.size
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout_button_details(button: Button) -> void:
	if button == null:
		return
	var gloss := button.get_node_or_null("ButtonGloss") as ColorRect
	if gloss != null:
		gloss.position = Vector2(12.0, 7.0)
		gloss.size = Vector2(maxf(1.0, button.size.x - 24.0), 2.0)
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wash := button.get_node_or_null("ButtonUpperWash") as ColorRect
	if wash != null:
		wash.position = Vector2(10.0, 10.0)
		wash.size = Vector2(maxf(1.0, button.size.x - 20.0), 10.0)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := button.get_node_or_null("ButtonBottomShade") as ColorRect
	if shade != null:
		shade.position = Vector2(12.0, maxf(0.0, button.size.y - 8.0))
		shade.size = Vector2(maxf(1.0, button.size.x - 24.0), 3.0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_actions_content() -> void:
	var action_buttons := _get_action_buttons()
	var effective_actions := _get_effective_actions()
	for i in range(action_buttons.size()):
		var button := action_buttons[i]
		if button == null:
			continue
		var has_action := i < effective_actions.size()
		button.visible = has_action
		if not has_action:
			continue
		_apply_action_to_button(button, effective_actions[i], i)


func _apply_action_to_button(button: Button, action: Resource, index: int) -> void:
	var label_text := str(_resource_value(action, "label", "BUTTON"))
	var action_id := str(_resource_value(action, "action_id", "action_" + str(index))).strip_edges()
	var icon_texture := _texture_from_value(_resource_value(action, "icon_texture", null))
	var visible_value := bool(_resource_value(action, "visible", true))
	var disabled_value := bool(_resource_value(action, "disabled", false))
	var tooltip := str(_resource_value(action, "tooltip", ""))

	button.visible = visible_value
	button.disabled = disabled_value
	button.tooltip_text = tooltip
	button.text = ""

	var icon := button.get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.texture = icon_texture
		icon.visible = icon_texture != null
	var icon_shadow := button.get_node_or_null("IconShadow") as TextureRect
	if icon_shadow != null:
		icon_shadow.texture = icon_texture
		icon_shadow.visible = show_icon_shadows and icon_texture != null
		icon_shadow.modulate = icon_shadow_color
	var label := button.get_node_or_null("ActionLabel") as Label
	if label != null:
		label.text = label_text
		label.visible = show_action_labels or icon_texture == null
		_style_label_node(label, action_font_size, action_label_color, HORIZONTAL_ALIGNMENT_LEFT)
		if icon_texture == null:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = Vector2.ZERO
			label.size = action_button_size
		else:
			label.position = action_label_rect.position
			label.size = action_label_rect.size
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_actions_style() -> void:
	var action_buttons := _get_action_buttons()
	var effective_actions := _get_effective_actions()
	for i in range(action_buttons.size()):
		var button := action_buttons[i]
		if button == null or i >= effective_actions.size():
			continue
		var action := effective_actions[i]
		var selected := bool(_resource_value(action, "selected", false))
		var style_name := str(_resource_value(action, "button_style", "blue")).strip_edges().to_lower()
		var fill := blue_button_color
		var hover := blue_button_hover_color
		var pressed := blue_button_pressed_color
		var border := blue_button_border_color
		match style_name:
			"yellow":
				fill = selected_button_color
				hover = Color(1.0, 0.94, 0.20, 1.0)
				pressed = Color(0.90, 0.58, 0.02, 1.0)
				border = selected_button_border_color
			"green":
				fill = Color(0.18, 0.70, 0.24, 0.98)
				hover = Color(0.28, 0.88, 0.34, 0.98)
				pressed = Color(0.10, 0.48, 0.16, 0.98)
				border = Color(0.05, 0.30, 0.06, 1.0)
			"red":
				fill = close_button_color
				hover = Color(0.88, 0.16, 0.24, 0.98)
				pressed = Color(0.42, 0.04, 0.10, 0.96)
				border = close_button_border_color
			"custom":
				fill = _color_from_value(_resource_value(action, "custom_fill_color", fill), fill)
				hover = _color_from_value(_resource_value(action, "custom_hover_color", hover), hover)
				pressed = _color_from_value(_resource_value(action, "custom_pressed_color", pressed), pressed)
				border = _color_from_value(_resource_value(action, "custom_border_color", border), border)

		if selected:
			fill = selected_button_color
			hover = Color(1.0, 0.94, 0.20, 1.0)
			pressed = Color(0.90, 0.58, 0.02, 1.0)
			border = selected_button_border_color
		_apply_button_style(button, fill, hover, pressed, border, action_font_size, 3, 12, 5)


func _apply_gloss_style() -> void:
	var header_gloss := get_node_or_null("CenterContainer/MenuWindow/Header/HeaderGloss") as ColorRect
	if header_gloss != null:
		header_gloss.color = Color(gloss_color.r, gloss_color.g, gloss_color.b, minf(gloss_color.a, 0.10))
	var header_spark := get_node_or_null("CenterContainer/MenuWindow/Header/HeaderSpark") as ColorRect
	if header_spark != null:
		header_spark.color = gloss_color
	var body_gloss := get_node_or_null("CenterContainer/MenuWindow/BodyPanel/BodyGloss") as ColorRect
	if body_gloss != null:
		body_gloss.color = Color(gloss_color.r, gloss_color.g, gloss_color.b, minf(gloss_color.a, 0.07))
	var body_floor := get_node_or_null("CenterContainer/MenuWindow/BodyPanel/BodyFloorShade") as ColorRect
	if body_floor != null:
		body_floor.color = Color(0.0, 0.0, 0.0, 0.22)

	var buttons := _get_action_buttons()
	if back_button != null:
		buttons.append(back_button)
	for button in buttons:
		var gloss := button.get_node_or_null("ButtonGloss") as ColorRect
		if gloss != null:
			gloss.color = Color(1.0, 1.0, 1.0, 0.12)
		var wash := button.get_node_or_null("ButtonUpperWash") as ColorRect
		if wash != null:
			wash.color = Color(0.62, 0.90, 1.0, 0.045)
		var shade := button.get_node_or_null("ButtonBottomShade") as ColorRect
		if shade != null:
			shade.color = Color(0.0, 0.0, 0.0, 0.20)


func _update_icon_shadow_visibility() -> void:
	for button in _get_action_buttons():
		var icon := button.get_node_or_null("Icon") as TextureRect
		var shadow := button.get_node_or_null("IconShadow") as TextureRect
		if shadow != null:
			shadow.visible = show_icon_shadows and icon != null and icon.texture != null
			shadow.modulate = icon_shadow_color


func _get_action_buttons() -> Array[Button]:
	var result: Array[Button] = []
	if actions_root == null:
		return result
	for child in actions_root.get_children():
		if child is Button:
			result.append(child as Button)
	return result


func _get_effective_actions() -> Array[Resource]:
	if not menu_actions.is_empty():
		return menu_actions
	if not show_sample_actions_when_empty:
		return []

	var actions: Array[Resource] = []
	actions.append(_make_action("PLAYER INFO", "player_info", player_info_icon_texture, "blue"))
	actions.append(_make_action("FRIENDS", "friends", friends_icon_texture, "blue"))
	actions.append(_make_action("RESPAWN", "respawn", respawn_icon_texture, "red"))
	actions.append(_make_action("SETTINGS", "settings", settings_icon_texture, "blue"))
	actions.append(_make_action("WORLDS", "lobby", lobby_icon_texture, "blue"))
	return actions


func _make_action(label_text: String, action_id: String, icon_texture: Texture2D, style_name: String) -> Resource:
	var action: Resource = MenuButtonDataScript.new()
	action.set("label", label_text)
	action.set("action_id", action_id)
	action.set("icon_texture", icon_texture)
	action.set("button_style", style_name)
	return action


func _action_from_dictionary(data: Dictionary) -> Resource:
	var action: Resource = MenuButtonDataScript.new()
	action.set("label", str(data.get("label", "BUTTON")))
	action.set("action_id", str(data.get("action_id", "button")))
	action.set("icon_texture", _texture_from_value(data.get("icon_texture", null)))
	action.set("button_style", str(data.get("button_style", "blue")))
	action.set("tooltip", str(data.get("tooltip", "")))
	action.set("selected", bool(data.get("selected", false)))
	action.set("disabled", bool(data.get("disabled", false)))
	action.set("visible", bool(data.get("visible", true)))
	action.set("custom_fill_color", _color_from_value(data.get("custom_fill_color", Color(0.12, 0.28, 0.40, 0.78)), Color(0.12, 0.28, 0.40, 0.78)))
	action.set("custom_hover_color", _color_from_value(data.get("custom_hover_color", Color(0.18, 0.38, 0.52, 0.86)), Color(0.18, 0.38, 0.52, 0.86)))
	action.set("custom_pressed_color", _color_from_value(data.get("custom_pressed_color", Color(0.08, 0.20, 0.30, 0.92)), Color(0.08, 0.20, 0.30, 0.92)))
	action.set("custom_border_color", _color_from_value(data.get("custom_border_color", Color(0.42, 0.78, 1.0, 0.62)), Color(0.42, 0.78, 1.0, 0.62)))
	action.set("metadata", data.get("metadata", {}))
	return action


func _style_panel(path: String, fill: Color, border: Color, border_width: int, radius: int, shadow_size: int) -> void:
	var panel := get_node_or_null(path) as Panel
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(fill, border, border_width, radius, shadow_size))


func _style_label(path: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> void:
	var label := get_node_or_null(path) as Label
	_style_label_node(label, font_size, color, alignment)


func _style_label_node(label: Label, font_size: int, color: Color, alignment: HorizontalAlignment) -> void:
	if label == null:
		return
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	PixelUIStyle.apply_game_font_to_node(label)


func _apply_button_style(button: Button, fill: Color, hover: Color, pressed: Color, border: Color, font_size: int, border_width: int, radius: int, shadow_size: int) -> void:
	if button == null:
		return
	PixelUIStyle.apply_button_text(button, font_size)
	button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(fill, border, border_width, radius, shadow_size))
	button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(hover, border, border_width, radius, shadow_size + 1))
	button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(pressed, border.darkened(0.35), border_width, radius, max(0, shadow_size - 1)))
	button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(fill.darkened(0.45), border.darkened(0.55), border_width, radius, max(0, shadow_size - 2)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _set_rect(path: String, rect: Rect2) -> void:
	var control := get_node_or_null(path) as Control
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size


func _set_label_text(path: String, text_value: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = text_value


func _resource_value(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _texture_from_value(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	if value is String:
		var path := str(value)
		if path != "" and ResourceLoader.exists(path):
			var loaded_resource := load(path)
			if loaded_resource is Texture2D:
				return loaded_resource as Texture2D
	return null


func _color_from_value(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String:
		var html_color := Color.from_string(str(value), fallback)
		return html_color
	return fallback
