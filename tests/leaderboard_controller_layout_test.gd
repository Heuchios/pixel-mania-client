extends SceneTree
const Controller = preload("res://Scripts/ui/leaderboard_controller.gd")
const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
func _init():
	call_deferred("run")
func run():
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,1000)
	var preview_path := OS.get_environment("LEADERBOARD_PREVIEW_BACKGROUND")
	if not preview_path.is_empty():
		var preview_image := Image.load_from_file(preview_path)
		if preview_image != null:
			var background := TextureRect.new()
			background.texture = ImageTexture.create_from_image(preview_image)
			background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			root.add_child(background)
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var controller = Controller.new()
	root.add_child(controller)
	controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controller._build_scene()
	controller._render()
	await process_frame
	await process_frame
	var ui = controller.scene_instance
	var base = "CenterContainer/LeaderboardWindow/"
	assert(ui.apply_exported_styles_on_ready)
	assert(not ui.show_sample_data_when_empty)
	assert(ui.get_node(base + "HeaderPanel/TitleLabel").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	var find_button = ui.get_node(base + "SideColumn/SideArtPanel/FindMeButton")
	assert(find_button.disabled)
	assert(ui.get_node(base + "TablePanel/EmptyState").visible)
	assert(not ui.rows_clip.get_v_scroll_bar().visible)
	var guide = ui.get_node(base + "SideColumn/SideArtPanel/Guide")
	assert(guide.position.y + guide.size.y < find_button.position.y, "Guide must not overlap Find Me")
	for title in ["RankHeader", "PlayerHeader", "PointsHeader"]:
		var label = ui.get_node(base + "TablePanel/HeaderRow/" + title)
		Style.apply_global_typography_to_node(label)
		assert(label.get_theme_font_size("font_size") == Style.DEFAULT_TEXT_FONT_SIZE, "Theme refresh must not enlarge table headings")
		assert(label.get_combined_minimum_size().x <= label.size.x, "Table heading fits its column")
	var weekly = ui.get_node(base + "SideColumn/Tabs/TabWeekly")
	var landfill = ui.get_node(base + "SideColumn/Tabs/TabLandfill")
	var inactive_style = weekly.get_theme_stylebox("normal")
	assert(inactive_style.region_rect != landfill.get_theme_stylebox("normal").region_rect)
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-live-empty.png")
	controller.leaderboard_loading = true
	controller._render()
	await process_frame
	assert(ui.get_node(base + "TablePanel/EmptyState/Message").text == "Loading leaderboard...")
	controller.leaderboard_loading = false
	controller.leaderboard_error = "Leaderboard is unavailable right now."
	controller._render()
	await process_frame
	assert(ui.get_node(base + "TablePanel/EmptyState/Message").text == controller.leaderboard_error)
	controller.leaderboard_error = ""
	weekly.pressed.emit()
	await process_frame
	await process_frame
	assert(landfill.get_theme_stylebox("normal").region_rect == inactive_style.region_rect)
	assert(ui.title_text == "WEEKLY")
	assert(controller.selected_tab == 1, "An actual tab press reaches the controller")
	assert(ui.get_node(base + "TablePanel/EmptyState/Message").text.contains("coming soon"))
	ui.select_tab(0)
	controller.selected_tab = 0
	controller.entries = [{"username":"PreviewPlayer", "rank":1, "kilograms":1250}]
	controller.your_rank = 1
	controller.your_kilograms = 1250
	controller._render()
	await process_frame
	await process_frame
	assert(not find_button.disabled)
	find_button.pressed.emit()
	assert(ui.get_node(base + "TablePanel/RowsClip/RowsRoot/LeaderboardRow1/PlayerName").text == "PreviewPlayer")
	assert(not ui.get_node(base + "TablePanel/EmptyState").visible)
	controller.entries.clear()
	for i in range(8):
		controller.entries.append({"username":"AReallyLongLeaderboardPlayerName" if i == 0 else "PreviewPlayer%d" % i, "rank":i+1, "kilograms":987654321-i*100})
	controller.landfill_status_known = true
	controller.landfill_event_active = true
	controller.landfill_ends_at_ms = int(Time.get_unix_time_from_system() * 1000) + 604800000
	controller._render()
	await process_frame
	await process_frame
	var first_row = ui.get_node(base + "TablePanel/RowsClip/RowsRoot/LeaderboardRow1")
	assert(ui.rows_clip.get_v_scroll_bar().visible, "Scrollbar appears for overflowing rows")
	for pair in [["RankHeader", "RankNumber"], ["PlayerHeader", "PlayerName"], ["PointsHeader", "Points"]]:
		var heading: Rect2 = ui.get_node(base + "TablePanel/HeaderRow/" + pair[0]).get_global_rect()
		var cell: Rect2 = first_row.get_node(pair[1]).get_global_rect()
		assert(absf(heading.position.x - cell.position.x) < 1 and absf(heading.end.x - cell.end.x) < 1, "Headers align with row columns")
	assert(first_row.get_node("PlayerName").get_rect().end.x < first_row.get_node("Points").position.x, "Long names never overlap scores")
	for stat in ["YourRankStat", "YourPointsStat", "EventEndsStat"]:
		var summary = ui.get_node(base + "SummaryPanel/" + stat)
		assert(is_equal_approx(summary.get_node("Label").get_rect().get_center().x, summary.get_node("Value").get_rect().get_center().x), "Summary label and value share a center")
	for dimensions in [Vector2i(1440,1000), Vector2i(800,600), Vector2i(640,360), Vector2i(360,640)]:
		root.size = dimensions
		controller._fit_to_viewport()
		await process_frame
		await process_frame
		var bounds: Rect2 = ui.leaderboard_window.get_global_rect()
		var viewport_size: Vector2 = ui.get_viewport_rect().size
		assert(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= viewport_size.x + 1 and bounds.end.y <= viewport_size.y + 1, "Leaderboard stays within the viewport")
		assert(bounds.get_center().distance_to(viewport_size * 0.5) < 1, "Leaderboard remains centered")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-%dx%d.png" % [dimensions.x, dimensions.y])
	controller.free()
	print("[leaderboard-controller-layout] success")
	quit()
