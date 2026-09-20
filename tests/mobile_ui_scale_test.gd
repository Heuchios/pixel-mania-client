extends SceneTree
const ScaleManager = preload("res://Scripts/ui/mobile_ui_scale.gd")
class MobileSettings extends "res://Scripts/ui/settings_panel.gd":
	func _is_mobile_platform() -> bool:
		return true

var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var manager := ScaleManager.new()
	root.add_child(manager)
	manager.set_process(false)
	var path := "res://tmp/mobile_scale_test_%s.cfg" % Time.get_ticks_usec()
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_volume", 0.4)
	config.set_value("mobile_controls", "jump_scale", 1.1)
	config.save(path)
	manager.set_ui_scale(1.25, path)
	check(is_equal_approx(ScaleManager.load_scale(path), 1.25), "Saved scale survives reload")
	config.load(path)
	check(config.get_value("audio", "sfx_volume") == 0.4, "Audio survives save")
	check(config.get_value("mobile_controls", "jump_scale") == 1.1, "Control customization survives save")
	check(ScaleManager.clean_scale("invalid") == 1.0, "Invalid setting defaults safely")
	check(ScaleManager.clean_scale(NAN) == 1.0, "Non-finite setting defaults safely")
	check(ScaleManager.clean_scale(20) == 1.25, "Large setting clamped")
	check(ScaleManager.clean_scale(0) == 0.75, "Small setting clamped")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var wrapper := Control.new()
	layer.add_child(wrapper)
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Control.new()
	wrapper.add_child(panel)
	panel.size = Vector2(400, 200)
	panel.position = Vector2(1500, 860)
	var child := Label.new()
	panel.add_child(child)
	child.text = "Nested text"
	for screen in [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1280, 720)]:
		panel.position = screen - panel.size - Vector2(20, 20)
		for value in [0.75, 1.25, 1.0]:
			manager.ui_scale = value
			manager.apply_branch(wrapper, screen)
			var applied := panel.scale
			manager.apply_branch(wrapper, screen)
			check(panel.scale.is_equal_approx(applied), "No compounded scale")
			check(panel.scale.is_equal_approx(Vector2.ONE * value), "Panel follows selected scale")
			check(child.scale == Vector2.ONE, "Nested controls not scaled twice")
			var rect := panel.get_global_rect()
			check(rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= screen.x + 0.01 and rect.end.y <= screen.y + 0.01, "Panel stays within display")
	check(panel.pivot_offset == Vector2.ZERO, "Default restores authored pivot")
	manager.set_ui_scale(1.0, path)
	check(ScaleManager.load_scale(path) == 1.0, "Reset persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings = load("res://Scenes/ui/settings/SettingsPanel.tscn").instantiate()
	settings.set_script(MobileSettings)
	root.add_child(settings)
	await process_frame
	check(settings.ui_scale_slider != null, "Mobile settings exposes slider")
	check(settings.ui_scale_slider.min_value == 75 and settings.ui_scale_slider.max_value == 125, "Slider bounds")
	check(settings.ui_scale_row.position.y >= settings.mobile_controls_row.position.y + 44, "Slider follows controls row")
	check(settings.ui_scale_row.position.y + 44 <= settings.window.size.y, "Scale row fits settings panel")
	settings.queue_free()
	layer.queue_free()
	manager.queue_free()
	await process_frame
	print("MOBILE_UI_SCALE_TEST: %d failures" % failures)
	quit(1 if failures else 0)
