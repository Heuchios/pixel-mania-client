extends SceneTree
const Controller = preload("res://Scripts/ui/leaderboard_controller.gd")
func _init():
	call_deferred("run")
func run():
	root.size = Vector2i(1440,1000)
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
	assert(ui.get_node(base + "HeaderPanel/TitleLabel").horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	var find_button = ui.get_node(base + "SideColumn/SideArtPanel/FindMeButton")
	assert(find_button.disabled)
	var weekly = ui.get_node(base + "SideColumn/Tabs/TabWeekly")
	var landfill = ui.get_node(base + "SideColumn/Tabs/TabLandfill")
	var inactive_style = weekly.get_theme_stylebox("normal")
	assert(inactive_style.region_rect != landfill.get_theme_stylebox("normal").region_rect)
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/leaderboard-live-empty.png")
	ui.select_tab(1)
	controller.selected_tab = 1
	controller._render_coming_soon()
	await process_frame
	await process_frame
	assert(landfill.get_theme_stylebox("normal").region_rect == inactive_style.region_rect)
	assert(ui.title_text == "WEEKLY")
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
	controller.free()
	print("[leaderboard-controller-layout] success")
	quit()
