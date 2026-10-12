extends SceneTree

var policy: Node
var captures := ""

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String, delta: float = 0.0) -> Image:
	policy._process(delta)
	policy.set_process(false)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(captures.path_join(name + ".png"))
	return frame

func _run() -> void:
	captures = ProjectSettings.globalize_path("user://window-transition-captures")
	DirAccess.make_dir_recursive_absolute(captures)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(800, 600)
	policy = root.get_node("WindowTransitions")
	var background := ColorRect.new()
	background.color = Color("10192e")
	background.size = Vector2(800, 600)
	root.add_child(background)
	var outer := Control.new()
	root.add_child(outer)
	var owner_control := Control.new()
	owner_control.hide()
	outer.add_child(owner_control)
	var panel := Panel.new()
	panel.position = Vector2(100, 100)
	panel.size = Vector2(600, 400)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7c9ee")
	panel.add_theme_stylebox_override("panel", style)
	owner_control.add_child(panel)
	var label := Label.new()
	label.text = "SMOOTH WINDOW TRANSITIONS\n\nRapid reopen preserves the current motion.\n\nClosing immediately releases input."
	label.position = Vector2(32, 40)
	label.add_theme_font_override("font", load("res://Assets/font/font.ttf"))
	label.add_theme_color_override("font_color", Color("301b3a"))
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	var hidden_content := Panel.new()
	hidden_content.position = Vector2(250, 250)
	hidden_content.size = Vector2(100, 80)
	hidden_content.hide()
	panel.add_child(hidden_content)
	policy.register_window(owner_control, panel)
	var closed_frame := await _capture("closed")
	var background_pixel := closed_frame.get_pixel(400, 350)
	owner_control.show()
	var first := await _capture("opening-first-frame")
	assert(first.get_pixel(400, 350).is_equal_approx(background_pixel), "No full-size flash before opening")
	var opening := await _capture("opening", 0.10)
	assert(opening.get_pixel(400, 350).r > background_pixel.r)
	var opened := await _capture("open", 0.30)
	assert(opened.get_pixel(400, 350).r > opening.get_pixel(400, 350).r)
	owner_control.hide()
	assert(not owner_control.is_visible_in_tree())
	var close_first := await _capture("closing-first-frame")
	assert(close_first.get_pixel(400, 350).is_equal_approx(opened.get_pixel(400, 350)), "Exit starts from the rendered window without a snap")
	var closing := await _capture("closing", 0.08)
	assert(closing.get_pixel(400, 350).r < opened.get_pixel(400, 350).r)
	assert(closing.get_pixel(400, 350).r > background_pixel.r, "A hidden window still renders its exit")
	var id := panel.get_instance_id()
	var before: Dictionary = policy.active[id].duplicate()
	owner_control.show()
	assert(policy.active[id].scale == before.scale and policy.active[id].offset == before.offset)
	assert(policy.active[id].alpha_velocity == before.alpha_velocity)
	await _capture("reopening", 0.08)
	await _capture("reopened", 0.30)
	owner_control.hide()
	var finished := await _capture("closed-again", 0.30)
	assert(finished.get_pixel(400, 350).is_equal_approx(background_pixel), "No ghost remains after closing")
	owner_control.show()
	await _capture("before-scene-hide", 0.30)
	owner_control.hide()
	outer.hide()
	var hidden := await _capture("scene-hidden", 0.04)
	assert(hidden.get_pixel(400, 350).is_equal_approx(background_pixel), "Closing windows cannot leak across scenes")
	outer.free()
	background.free()
	# Actual windows: desktop and narrow mobile layouts, entrance and exit.
	for viewport_size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = viewport_size
		for scene_path in ["res://Scenes/ui/shop/ShopSceneRedesign.tscn", "res://Scenes/ui/settings/SettingsPanel.tscn", "res://Scenes/ui/vending/VendingMachineGUI.tscn", "res://Scenes/ui/menu/MenuScene.tscn"]:
			var ui = load(scene_path).instantiate()
			root.add_child(ui)
			await process_frame
			ui.hide()
			policy._process(1.0)
			if ui.has_method("open_menu"):
				ui.open_menu()
			elif ui.has_method("open_settings"):
				ui.open_settings()
			else:
				ui.show()
			var prefix := "%d-%s" % [viewport_size.x, scene_path.get_file().get_basename()]
			await _capture(prefix + "-opening", 0.10)
			await _capture(prefix + "-open", 0.30)
			if ui.has_method("open_menu"):
				var window: Control = ui.menu_window
				var drawn := Rect2(window.get_global_transform().origin, window.size * window.get_global_transform().get_scale())
				assert(drawn.position.x >= -0.01 and drawn.position.y >= -0.01 and drawn.end.x <= viewport_size.x + 0.01 and drawn.end.y <= viewport_size.y + 0.01, "The menu remains entirely visible on short phone screens")
			ui.hide()
			await _capture(prefix + "-closing", 0.08)
			await _capture(prefix + "-closed", 0.30)
			ui.free()
	print("window_transitions_render_test: PASS; captures=" + captures)
	quit()
