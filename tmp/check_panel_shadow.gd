extends SceneTree
func _initialize():
	call_deferred("check")
func check():
	var styling = load("res://Scripts/ui/pixel_ui_style.gd")
	var panel = Panel.new()
	panel.size = Vector2(400, 300)
	panel.add_theme_stylebox_override("panel", styling.panel_style())
	root.add_child(panel)
	styling._apply_window_shadow(panel)
	styling._apply_window_shadow(panel)
	assert(panel.get_child_count() == 1)
	var shadow = panel.get_node("WindowDropShadow")
	assert(shadow.show_behind_parent and is_equal_approx(shadow.self_modulate.a, 0.4))
	panel.size = Vector2(600, 400)
	await process_frame
	print("PANEL_SHADOW_OK")
	quit()
