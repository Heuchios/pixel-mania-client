extends SceneTree
const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900,440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var back := Panel.new()
	back.size = viewport.size
	back.add_theme_stylebox_override("panel", Style.section_style())
	viewport.add_child(back)
	for i in range(5):
		var label := Label.new()
		label.text = ["EMPTY", "QUARTER", "HALF", "FULL", "LEGACY XP"][i]
		label.position = Vector2(32,28+i*76)
		Style.apply_small_label(label,16)
		back.add_child(label)
		if i<4:
			var bar := ProgressBar.new()
			bar.position=Vector2(280,32+i*76)
			bar.size=Vector2(550,24)
			bar.value=[0,25,50,100][i]
			bar.show_percentage=false
			back.add_child(bar)
			Style.apply_progress_bar(bar)
		else:
			var track := ColorRect.new()
			track.position=Vector2(280,336)
			track.size=Vector2(550,24)
			back.add_child(track)
			var fill := ColorRect.new()
			fill.size=Vector2(275,24)
			track.add_child(fill)
			Style.apply_progress_bar(track,fill)
	for path in ["generator_ui", "battery_charger_ui", "oil_refinery_ui", "lobby_menu", "notification_ui", "ui/lobby_scene", "ui/player_profile_scene", "ui/fishing_minigame_ui", "ui/quest_board_ui"]:
		var script = load("res://Scripts/"+path+".gd")
		assert(script.can_instantiate(),path)
	var scene = load("res://Scenes/ui/WorldLoadingOverlay/WorldLoadingOverlay.tscn").instantiate()
	viewport.add_child(scene)
	scene.get_node("LoadingCanvas").hide()
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/progress-bars.png")
	var index := 0
	for node in back.get_children():
		if node is ProgressBar:
			var visual = node.get_node("AtlasProgressVisual")
			assert(is_equal_approx(visual.clip.size.x / visual.artwork.size.x, [0.0,.25,.5,1.0][index]))
			assert(visual.clip.visible == (index != 0))
			node.size = Vector2(240, 40)
			visual._process(0)
			assert(visual.size == Vector2(240,24))
			assert(visual.position.y == 8)
			index += 1
	print("[atlas-progress] migrated scripts, empty/partial/full fills and proportional resize passed")
	quit()
