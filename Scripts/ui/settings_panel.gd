extends Control
class_name SettingsPanel

signal close_requested

const WINDOW_SIZE := Vector2(560, 360)
const WINDOW_VISUAL_SIZE := Vector2(564, 674)
const SETTINGS_SAVE_PATH := "user://pixelmania_settings.cfg"
const SETTINGS_SECTION := "audio"
const CHAT_SETTINGS_SECTION := "chat"
const SFX_VOLUME_KEY := "sfx_volume"
const CHAT_CONTENT_FILTER_KEY := "content_filter_enabled"
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_CHAT_CONTENT_FILTER_ENABLED := true

@onready var window: Control = $Window
@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect
@onready var close_button: Button = $Window/CloseButton
@onready var full_screen_row: Control = get_node_or_null("Window/FullScreenRow") as Control
@onready var full_screen_checkmark: TextureButton = get_node_or_null("Window/FullScreenRow/FullScreenCheckmark") as TextureButton
@onready var sfx_slider: HSlider = get_node_or_null("Window/SfxRow/SfxSlider") as HSlider
@onready var sfx_value_label: Label = get_node_or_null("Window/SfxRow/SfxValueLabel") as Label
@onready var chat_filter_row: Control = get_node_or_null("Window/ChatFilterRow") as Control
@onready var chat_filter_checkmark: TextureButton = get_node_or_null("Window/ChatFilterRow/ChatFilterCheckmark") as TextureButton
@onready var mobile_controls_row: Control = get_node_or_null("Window/MobileControlsRow") as Control
@onready var customize_mobile_controls_button: Button = get_node_or_null("Window/MobileControlsRow/CustomizeButton") as Button

var world_ref: Node = null
var mobile_controls_ref: Node = null


func _ready() -> void:
	_fit_window_to_viewport()
	if close_button != null and not close_button.pressed.is_connected(close_settings):
		close_button.pressed.connect(close_settings)
	_setup_full_screen_toggle()
	_setup_sfx_slider()
	_setup_chat_filter_toggle()
	_setup_mobile_controls_row()


func setup(world_node: Node) -> void:
	world_ref = world_node
	_apply_saved_sfx_volume()
	_apply_saved_chat_filter()
	_setup_mobile_controls_row()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		call_deferred("_fit_window_to_viewport")


func open_settings() -> void:
	visible = true
	if dimmer != null:
		dimmer.visible = true
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if window != null:
		window.visible = true
	_sync_full_screen_toggle_state()
	_sync_sfx_slider_from_world()
	_sync_chat_filter_toggle_state()
	_setup_mobile_controls_row()
	_fit_window_to_viewport()


func close_settings() -> void:
	if (
		mobile_controls_ref != null
		and is_instance_valid(mobile_controls_ref)
		and mobile_controls_ref.has_method("is_layout_customization_active")
		and bool(mobile_controls_ref.call("is_layout_customization_active"))
	):
		mobile_controls_ref.call("cancel_layout_customization")
	if window != null:
		window.visible = true
	if dimmer != null:
		dimmer.visible = true
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	close_requested.emit()


func _setup_full_screen_toggle() -> void:
	if full_screen_checkmark == null:
		return

	_sync_full_screen_toggle_state()
	if not full_screen_checkmark.toggled.is_connected(_on_full_screen_toggled):
		full_screen_checkmark.toggled.connect(_on_full_screen_toggled)
	if full_screen_row != null and not full_screen_row.gui_input.is_connected(_on_full_screen_row_gui_input):
		full_screen_row.gui_input.connect(_on_full_screen_row_gui_input)


func _on_full_screen_row_gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if full_screen_checkmark == null:
		return

	var new_value: bool = not full_screen_checkmark.button_pressed
	full_screen_checkmark.set_pressed_no_signal(new_value)
	_on_full_screen_toggled(new_value)


func _on_full_screen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _is_full_screen_enabled() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _sync_full_screen_toggle_state() -> void:
	if full_screen_checkmark == null:
		return

	full_screen_checkmark.set_pressed_no_signal(_is_full_screen_enabled())


func _setup_sfx_slider() -> void:
	if sfx_slider == null:
		return

	_set_sfx_slider_value_no_signal(_load_sfx_volume())
	if not sfx_slider.value_changed.is_connected(_on_sfx_slider_value_changed):
		sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)


func _setup_chat_filter_toggle() -> void:
	if chat_filter_checkmark == null:
		return

	chat_filter_checkmark.set_pressed_no_signal(_load_chat_filter_enabled())
	if not chat_filter_checkmark.toggled.is_connected(_on_chat_filter_toggled):
		chat_filter_checkmark.toggled.connect(_on_chat_filter_toggled)
	if chat_filter_row != null and not chat_filter_row.gui_input.is_connected(_on_chat_filter_row_gui_input):
		chat_filter_row.gui_input.connect(_on_chat_filter_row_gui_input)


func _apply_saved_sfx_volume() -> void:
	var volume_linear := _load_sfx_volume()
	_set_sfx_slider_value_no_signal(volume_linear)
	_apply_sfx_volume(volume_linear)


func _apply_saved_chat_filter() -> void:
	_apply_chat_filter_enabled(_load_chat_filter_enabled())


func _sync_chat_filter_toggle_state() -> void:
	if chat_filter_checkmark == null:
		return

	chat_filter_checkmark.set_pressed_no_signal(_get_current_chat_filter_enabled())


func _sync_sfx_slider_from_world() -> void:
	var volume_linear := _get_current_sfx_volume()
	_set_sfx_slider_value_no_signal(volume_linear)


func _on_sfx_slider_value_changed(value: float) -> void:
	var volume_linear := clampf(value / 100.0, 0.0, 1.0)
	_apply_sfx_volume(volume_linear)
	_save_sfx_volume(volume_linear)


func _on_chat_filter_row_gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if chat_filter_checkmark == null:
		return

	var new_value: bool = not chat_filter_checkmark.button_pressed
	chat_filter_checkmark.set_pressed_no_signal(new_value)
	_on_chat_filter_toggled(new_value)


func _on_chat_filter_toggled(enabled: bool) -> void:
	_apply_chat_filter_enabled(enabled)
	_save_chat_filter_enabled(enabled)


func _apply_sfx_volume(volume_linear: float) -> void:
	var clean_volume := clampf(volume_linear, 0.0, 1.0)
	if world_ref != null and world_ref.has_method("set_sfx_volume"):
		world_ref.set_sfx_volume(clean_volume)
	_update_sfx_value_label(clean_volume)


func _get_current_sfx_volume() -> float:
	if world_ref != null and world_ref.has_method("get_sfx_volume"):
		return clampf(float(world_ref.get_sfx_volume()), 0.0, 1.0)

	return _load_sfx_volume()


func _apply_chat_filter_enabled(enabled: bool) -> void:
	if world_ref != null and world_ref.has_method("set_chat_content_filter_enabled"):
		world_ref.set_chat_content_filter_enabled(enabled)
	if chat_filter_checkmark != null:
		chat_filter_checkmark.set_pressed_no_signal(enabled)


func _get_current_chat_filter_enabled() -> bool:
	if world_ref != null and world_ref.has_method("is_chat_content_filter_enabled"):
		return bool(world_ref.is_chat_content_filter_enabled())

	return _load_chat_filter_enabled()


func _load_sfx_volume() -> float:
	var cfg := ConfigFile.new()
	var load_result := cfg.load(SETTINGS_SAVE_PATH)
	if load_result != OK:
		return DEFAULT_SFX_VOLUME

	return clampf(float(cfg.get_value(SETTINGS_SECTION, SFX_VOLUME_KEY, DEFAULT_SFX_VOLUME)), 0.0, 1.0)


func _save_sfx_volume(volume_linear: float) -> void:
	var cfg := ConfigFile.new()
	var load_result := cfg.load(SETTINGS_SAVE_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_warning("SettingsPanel: could not read the existing settings file, so it was not overwritten.")
		return
	cfg.set_value(SETTINGS_SECTION, SFX_VOLUME_KEY, clampf(volume_linear, 0.0, 1.0))
	var save_result := cfg.save(SETTINGS_SAVE_PATH)
	if save_result != OK:
		push_warning("SettingsPanel: failed to save SFX volume setting.")


func _load_chat_filter_enabled() -> bool:
	var cfg := ConfigFile.new()
	var load_result := cfg.load(SETTINGS_SAVE_PATH)
	if load_result != OK:
		return DEFAULT_CHAT_CONTENT_FILTER_ENABLED

	return bool(cfg.get_value(CHAT_SETTINGS_SECTION, CHAT_CONTENT_FILTER_KEY, DEFAULT_CHAT_CONTENT_FILTER_ENABLED))


func _save_chat_filter_enabled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	var load_result := cfg.load(SETTINGS_SAVE_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_warning("SettingsPanel: could not read the existing settings file, so it was not overwritten.")
		return
	cfg.set_value(CHAT_SETTINGS_SECTION, CHAT_CONTENT_FILTER_KEY, enabled)
	var save_result := cfg.save(SETTINGS_SAVE_PATH)
	if save_result != OK:
		push_warning("SettingsPanel: failed to save chat filter setting.")


func _set_sfx_slider_value_no_signal(volume_linear: float) -> void:
	if sfx_slider == null:
		_update_sfx_value_label(volume_linear)
		return

	var clean_volume := clampf(volume_linear, 0.0, 1.0)
	sfx_slider.set_value_no_signal(roundf(clean_volume * 100.0))
	_update_sfx_value_label(clean_volume)


func _update_sfx_value_label(volume_linear: float) -> void:
	if sfx_value_label == null:
		return

	sfx_value_label.text = str(int(roundf(clampf(volume_linear, 0.0, 1.0) * 100.0))) + "%"


func _setup_mobile_controls_row() -> void:
	if mobile_controls_row != null:
		mobile_controls_row.visible = _is_mobile_platform()
	if customize_mobile_controls_button == null:
		return

	customize_mobile_controls_button.visible = _is_mobile_platform()
	if not customize_mobile_controls_button.pressed.is_connected(_on_customize_mobile_controls_pressed):
		customize_mobile_controls_button.pressed.connect(_on_customize_mobile_controls_pressed)


func _on_customize_mobile_controls_pressed() -> void:
	var controls := _get_mobile_controls_node()
	if controls == null or not controls.has_method("begin_layout_customization"):
		push_warning("SettingsPanel: mobile controls are not available to customize.")
		return

	var finish_callback := Callable(self, "_on_mobile_controls_layout_finished")
	if controls.has_signal("layout_customization_finished") and not controls.is_connected("layout_customization_finished", finish_callback):
		controls.connect("layout_customization_finished", finish_callback)

	if window != null:
		window.visible = false
	if dimmer != null:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(controls.call("begin_layout_customization")):
		if window != null:
			window.visible = true
		if dimmer != null:
			dimmer.visible = true
			dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		push_warning("SettingsPanel: mobile control customization could not be started.")


func _on_mobile_controls_layout_finished(_saved: bool) -> void:
	if not visible:
		return

	if window != null:
		window.visible = true
	if dimmer != null:
		dimmer.visible = true
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_full_screen_toggle_state()
	_sync_sfx_slider_from_world()
	_fit_window_to_viewport()


func _get_mobile_controls_node() -> Node:
	if mobile_controls_ref != null and is_instance_valid(mobile_controls_ref):
		return mobile_controls_ref
	if world_ref == null:
		return null

	var hud_layer: Node = null
	if world_ref.has_method("get_ui_hud_layer"):
		hud_layer = world_ref.call("get_ui_hud_layer") as Node
	if hud_layer != null:
		mobile_controls_ref = hud_layer.get_node_or_null("MobileControls")

	if mobile_controls_ref == null:
		var ui_layer_value: Variant = world_ref.get("ui_layer")
		if ui_layer_value is Node:
			mobile_controls_ref = ui_layer_value.get_node_or_null("MobileControls")

	return mobile_controls_ref


func _is_mobile_platform() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _fit_window_to_viewport() -> void:
	if window == null:
		return

	var viewport_size := get_viewport_rect().size
	var available_size := Vector2(
		max(viewport_size.x - 32.0, 1.0),
		max(viewport_size.y - 32.0, 1.0)
	)
	var width_scale: float = available_size.x / WINDOW_VISUAL_SIZE.x
	var height_scale: float = available_size.y / WINDOW_VISUAL_SIZE.y
	var scale_amount: float = minf(1.0, minf(width_scale, height_scale))
	window.scale = Vector2.ONE * scale_amount
	window.pivot_offset = WINDOW_SIZE * 0.5
