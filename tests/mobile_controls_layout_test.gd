extends SceneTree

const SETTINGS_SCENE = preload("res://Scenes/ui/settings/SettingsPanel.tscn")
const TEST_SETTINGS_PATH := "user://pixelmania_mobile_controls_layout_test.cfg"


class MockWorld:
	extends Node

	const CAMERA_ZOOM_STEP := 0.12

	var in_world := true
	var zoom_total := 0.0
	var punch_animation_count := 0
	var punch_block_count := 0
	var modal_layer: Control = null

	func get_ui_hud_layer() -> Node:
		return self

	func get_ui_modal_layer() -> Node:
		return modal_layer

	func is_movement_locked() -> bool:
		return false

	func is_major_ui_open() -> bool:
		return false

	func can_use_camera_zoom() -> bool:
		return true

	func zoom_camera(step: float) -> void:
		zoom_total += step

	func play_player_punch_animation() -> void:
		punch_animation_count += 1

	func punch_facing_block() -> void:
		punch_block_count += 1


class MobileControlsForTest:
	extends "res://Scripts/mobile_controls.gd"

	func _is_mobile_platform() -> bool:
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var test_settings_absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		assert(DirAccess.remove_absolute(test_settings_absolute_path) == OK)

	var mock_world := MockWorld.new()
	root.add_child(mock_world)
	var modal_layer := Control.new()
	modal_layer.name = "ModalLayer"
	mock_world.add_child(modal_layer)
	mock_world.modal_layer = modal_layer

	var controls := MobileControlsForTest.new()
	controls.name = "MobileControls"
	controls.set("settings_save_path", TEST_SETTINGS_PATH)
	mock_world.add_child(controls)
	controls.call("setup", mock_world)
	await process_frame

	var action_buttons: Dictionary = controls.get("action_buttons")
	assert(action_buttons.size() == 6)
	for action in ["move_left", "move_right", "jump", "punch", "zoom_in", "zoom_out"]:
		assert(action_buttons.has(action))
		assert(action_buttons[action] is Panel)
		assert((action_buttons[action] as Panel).size.x > 1.0)
		assert((action_buttons[action] as Panel).size.y > 1.0)
	var editor_overlay := controls.get_node("LayoutEditorOverlay") as ColorRect
	var editor_toolbar := controls.get_node("LayoutEditorToolbar") as PanelContainer
	assert(editor_overlay.get_index() == 0)
	assert(editor_toolbar.get_index() == controls.get_child_count() - 1)
	for action in action_buttons:
		var action_button := action_buttons[action] as Panel
		assert(action_button.get_index() > editor_overlay.get_index())
		assert(action_button.get_index() < editor_toolbar.get_index())

	var normal_parent := controls.get_parent()
	var normal_child_index := controls.get_index()
	controls.call("_move_to_layout_editor_layer")
	assert(controls.get_parent() == modal_layer)
	assert(controls.z_index == 300)
	controls.call("_restore_from_layout_editor_layer")
	assert(controls.get_parent() == normal_parent)
	assert(controls.get_index() == normal_child_index)
	assert(controls.z_index == 140)

	controls.set_process(false)
	controls.visible = true
	editor_overlay.visible = false
	editor_toolbar.visible = false

	var left_button := action_buttons["move_left"] as Panel
	var left_touch := InputEventScreenTouch.new()
	left_touch.index = 5
	left_touch.position = left_button.get_global_rect().get_center()
	left_touch.pressed = true
	Input.parse_input_event(left_touch)
	await process_frame
	assert(Input.is_action_pressed("move_left"))
	left_touch.pressed = false
	Input.parse_input_event(left_touch)
	await process_frame
	assert(not Input.is_action_pressed("move_left"))

	var zoom_button := action_buttons["zoom_in"] as Panel
	var zoom_touch := InputEventScreenTouch.new()
	zoom_touch.index = 6
	zoom_touch.position = zoom_button.get_global_rect().get_center()
	zoom_touch.pressed = true
	Input.parse_input_event(zoom_touch)
	await process_frame
	assert(mock_world.zoom_total > 0.0)
	zoom_touch.pressed = false
	Input.parse_input_event(zoom_touch)
	await process_frame

	var punch_button := action_buttons["punch"] as Panel
	var punch_touch := InputEventScreenTouch.new()
	punch_touch.index = 7
	punch_touch.position = punch_button.get_global_rect().get_center()
	punch_touch.pressed = true
	Input.parse_input_event(punch_touch)
	await process_frame
	assert(mock_world.punch_animation_count >= 1)
	assert(mock_world.punch_block_count == mock_world.punch_animation_count)
	punch_touch.pressed = false
	Input.parse_input_event(punch_touch)
	await physics_frame
	await process_frame
	assert(not Input.is_action_pressed("punch"))

	controls.set("control_layout", {})
	controls.set("has_custom_layout", false)
	controls.set("layout_customization_active", true)
	controls.set("selected_layout_action", "move_left")
	controls.visible = true
	editor_overlay.visible = true
	editor_toolbar.visible = true
	controls.call("_layout_controls")
	var jump_button_for_input := action_buttons["jump"] as Panel
	var touch_position := jump_button_for_input.get_global_rect().get_center()
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 9
	touch_press.position = touch_position
	touch_press.pressed = true
	Input.parse_input_event(touch_press)
	await process_frame
	assert(str(controls.get("selected_layout_action")) == "jump")

	var jump_position_before_drag := jump_button_for_input.position
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 9
	touch_drag.position = touch_position + Vector2(-36.0, -24.0)
	touch_drag.relative = Vector2(-36.0, -24.0)
	Input.parse_input_event(touch_drag)
	var emulated_mouse_drag := InputEventMouseMotion.new()
	emulated_mouse_drag.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse_drag.position = touch_drag.position
	emulated_mouse_drag.relative = touch_drag.relative
	emulated_mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(emulated_mouse_drag)
	await process_frame
	var applied_drag_delta := jump_button_for_input.position - jump_position_before_drag
	assert(applied_drag_delta.distance_to(Vector2(-36.0, -24.0)) <= 2.0)

	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 9
	touch_release.position = touch_drag.position
	touch_release.pressed = false
	Input.parse_input_event(touch_release)
	await process_frame

	controls.set("control_layout", {})
	controls.set("has_custom_layout", false)
	controls.set("layout_customization_active", true)
	controls.set("selected_layout_action", "jump")
	controls.call("_ensure_working_custom_layout")

	var captured_layout: Dictionary = controls.get("control_layout")
	assert(bool(controls.get("has_custom_layout")))
	assert(captured_layout.size() == 6)
	assert(captured_layout["jump"]["center"] is Vector2)
	assert(is_equal_approx(float(captured_layout["jump"]["scale"]), 1.0))

	var jump_button := action_buttons["jump"] as Panel
	var size_before := jump_button.size
	controls.call("_resize_selected_control", 0.10)
	var resized_layout: Dictionary = controls.get("control_layout")
	assert(is_equal_approx(float(resized_layout["jump"]["scale"]), 1.10))
	assert(jump_button.size.x > size_before.x)
	assert(jump_button.size.y > size_before.y)

	var center_before: Vector2 = resized_layout["jump"]["center"]
	controls.call("_move_layout_control", "jump", Vector2(-48.0, -32.0))
	var moved_layout: Dictionary = controls.get("control_layout")
	var center_after: Vector2 = moved_layout["jump"]["center"]
	assert(not center_after.is_equal_approx(center_before))

	controls.call("_move_layout_control", "jump", Vector2(-100000.0, -100000.0))
	var safe_rect: Rect2 = controls.call("_get_safe_layout_rect", controls.get_viewport_rect().size)
	var editor_bounds: Rect2 = controls.call("_get_editor_control_bounds", safe_rect)
	assert(jump_button.position.x >= safe_rect.position.x - 0.01)
	assert(jump_button.position.y >= editor_bounds.position.y - 0.01)

	var cancel_snapshot: Dictionary = (controls.get("control_layout") as Dictionary).duplicate(true)
	var snapshot_scale := float(cancel_snapshot["jump"]["scale"])
	controls.set("layout_snapshot", cancel_snapshot)
	controls.set("snapshot_had_custom_layout", true)
	controls.call("_resize_selected_control", 0.10)
	controls.call("cancel_layout_customization")
	var cancelled_layout: Dictionary = controls.get("control_layout")
	assert(is_equal_approx(float(cancelled_layout["jump"]["scale"]), snapshot_scale))
	assert(bool(controls.get("has_custom_layout")))
	assert(not bool(controls.get("layout_customization_active")))

	assert(bool(controls.call("_save_layout_preferences")))
	assert(FileAccess.file_exists(TEST_SETTINGS_PATH))
	var seeded_cfg := ConfigFile.new()
	seeded_cfg.set_value("audio", "sfx_volume", 0.37)
	assert(seeded_cfg.save(TEST_SETTINGS_PATH) == OK)
	assert(bool(controls.call("_save_layout_preferences")))
	var saved_cfg := ConfigFile.new()
	assert(saved_cfg.load(TEST_SETTINGS_PATH) == OK)
	assert(is_equal_approx(float(saved_cfg.get_value("audio", "sfx_volume", 0.0)), 0.37))
	assert(bool(saved_cfg.get_value("mobile_controls", "customized", false)))
	assert(saved_cfg.get_value("mobile_controls", "jump_center", null) is Vector2)
	assert(is_equal_approx(float(saved_cfg.get_value("mobile_controls", "jump_scale", 0.0)), snapshot_scale))

	controls.set("control_layout", {})
	controls.set("has_custom_layout", false)
	controls.call("_load_layout_preferences")
	assert(bool(controls.get("has_custom_layout")))
	assert((controls.get("control_layout") as Dictionary).size() == 6)

	controls.set("layout_customization_active", true)
	controls.call("reset_layout_customization")
	assert(bool(controls.get("has_custom_layout")))
	assert(bool(controls.get("layout_save_as_defaults")))
	assert((controls.get("control_layout") as Dictionary).size() == 6)
	assert(bool(controls.call("save_layout_customization")))
	assert(not bool(controls.get("layout_customization_active")))
	assert(not bool(controls.get("has_custom_layout")))
	assert((controls.get("control_layout") as Dictionary).is_empty())
	var reset_cfg := ConfigFile.new()
	assert(reset_cfg.load(TEST_SETTINGS_PATH) == OK)
	assert(not reset_cfg.has_section("mobile_controls"))
	assert(is_equal_approx(float(reset_cfg.get_value("audio", "sfx_volume", 0.0)), 0.37))

	var partial_cfg := ConfigFile.new()
	partial_cfg.set_value("mobile_controls", "layout_version", 1)
	partial_cfg.set_value("mobile_controls", "customized", true)
	partial_cfg.set_value("mobile_controls", "jump_center", Vector2(0.7, 0.6))
	partial_cfg.set_value("mobile_controls", "jump_scale", 1.15)
	assert(partial_cfg.save(TEST_SETTINGS_PATH) == OK)
	controls.call("_load_layout_preferences")
	assert((controls.get("control_layout") as Dictionary).size() == 1)
	assert((controls.get("control_layout") as Dictionary).has("jump"))
	controls.set("control_layout", {})
	controls.set("has_custom_layout", false)
	root.size = Vector2i(800, 480)
	controls.call("_layout_controls")
	await process_frame

	var settings := SETTINGS_SCENE.instantiate()
	root.add_child(settings)
	await process_frame
	assert(settings.get_node_or_null("Window/MobileControlsRow") is Control)
	assert(settings.get_node_or_null("Window/MobileControlsRow/CustomizeButton") is Button)
	var settings_dimmer := settings.get_node("Dimmer") as ColorRect
	assert(settings_dimmer.visible)
	assert(settings_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP)
	settings.call("setup", mock_world)
	assert(settings.call("_get_mobile_controls_node") == controls)
	settings.call("_on_customize_mobile_controls_pressed")
	assert(bool(controls.get("layout_customization_active")))
	assert(controls.get_parent() == modal_layer)
	assert(not (settings.get_node("Window") as Control).visible)
	assert(not settings_dimmer.visible)
	assert(bool(controls.get("layout_save_as_defaults")))
	var editor_toolbar_rect := (controls.get("editor_toolbar") as Control).get_global_rect()
	for action in ["move_left", "move_right", "jump", "punch", "zoom_in", "zoom_out"]:
		var editor_button_rect := (action_buttons[action] as Control).get_global_rect()
		assert(not editor_button_rect.intersects(editor_toolbar_rect))
	controls.call("cancel_layout_customization")
	assert(not bool(controls.get("layout_customization_active")))
	assert(controls.get_parent() == mock_world)
	assert((settings.get_node("Window") as Control).visible)
	assert(settings_dimmer.visible)
	assert(settings_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP)
	settings.call("_on_customize_mobile_controls_pressed")
	controls.set("selected_layout_action", "jump")
	controls.call("_resize_selected_control", 0.05)
	assert(not bool(controls.get("layout_save_as_defaults")))
	assert(bool(controls.call("save_layout_customization")))
	assert(not bool(controls.get("layout_customization_active")))
	assert(controls.get_parent() == mock_world)
	assert((settings.get_node("Window") as Control).visible)
	assert(settings_dimmer.visible)
	var integration_saved_cfg := ConfigFile.new()
	assert(integration_saved_cfg.load(TEST_SETTINGS_PATH) == OK)
	assert(bool(integration_saved_cfg.get_value("mobile_controls", "customized", false)))
	root.size = Vector2i(800, 480)
	settings.call("_fit_window_to_viewport")
	await process_frame
	var close_rect := (settings.get_node("Window/CloseButton") as Control).get_global_rect()
	var window_skin_rect := (settings.get_node("Window/WindowSkin") as Control).get_global_rect()
	assert(close_rect.position.y >= -0.01)
	assert(close_rect.end.y <= 480.01)
	assert(window_skin_rect.position.y >= -0.01)
	assert(window_skin_rect.end.y <= 480.01)
	root.size = Vector2i(1280, 720)

	var controls_source := FileAccess.get_file_as_string("res://Scripts/mobile_controls.gd")
	assert(controls_source.contains("user://pixelmania_settings.cfg"))
	assert(controls_source.contains("action + \"_center\""))
	assert(controls_source.contains("action + \"_scale\""))
	assert(controls_source.contains("cfg.save(settings_save_path)"))

	assert(DirAccess.remove_absolute(test_settings_absolute_path) == OK)
	print("[mobile-controls-layout] success")
	quit(0)
