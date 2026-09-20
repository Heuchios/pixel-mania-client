extends SceneTree
func _initialize():
	call_deferred("check")
func check():
	var menu = load("res://Scenes/ui/menu/MenuScene.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var header = menu.get_node("CenterContainer/MenuWindow/Header")
	var title = header.get_node("TitleLabel")
	assert(not header.get_node("SubtitleLabel").visible)
	assert(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert(title.get_theme_font_size("font_size") == 60)
	assert(is_equal_approx(title.position.x + title.size.x / 2, header.size.x / 2))
	print("MENU_HEADER_OK")
	quit()
