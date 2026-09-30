extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	if "--render" not in OS.get_cmdline_user_args():
		return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1300, 584)
	var lobby = load("res://Scenes/ui/lobby/LobbyScene.tscn").instantiate()
	lobby.set_script(load("res://tests/fixtures/mobile_lobby_fixture.gd"))
	root.add_child(lobby)
	lobby._apply_world_population_counts({"START": 0, "TEST": 2, "LONGWORLDNAME123": 42}, true)
	lobby._on_landfill_status_received({"event_active": true})
	await process_frame
	await capture("D:/Pixelmania/work/mobile-lobby-before.png")
	lobby.mobile = true
	get_root().get_node("MobileUIScale").ui_scale = 1.25
	lobby._configure_mobile_lobby()
	lobby.active_world_list_signature = ""
	lobby._refresh_world_rows()
	await process_frame
	await process_frame
	await capture("D:/Pixelmania/work/mobile-lobby-after.png")
	for dimensions in [Vector2i(1300, 584), Vector2i(1280, 720), Vector2i(640, 360)]:
		root.size = dimensions
		for value in [0.75, 1.0, 1.25, 1.5]:
			get_root().get_node("MobileUIScale").ui_scale = value
			await process_frame
			await process_frame
			var worlds: Control = lobby.get_node("WorldsPanel")
			var join_panel: Control = lobby.get_node("JoinPanel")
			var event: Control = lobby.landfill_event_card
			assert(not worlds.get_global_rect().intersects(join_panel.get_global_rect()), "Join bar overlaps world list")
			assert(not worlds.get_global_rect().intersects(event.get_global_rect()), "Event overlaps world list")
			assert(not join_panel.get_global_rect().intersects(lobby.get_node("Logo").get_global_rect()), "Logo overlaps join bar")
			for panel in [worlds, join_panel, event, lobby.get_node("LeftButtons"), lobby.get_node("TopButtons/ProfileButton")]:
				assert(lobby.get_viewport_rect().encloses(panel.get_global_rect()), "Mobile lobby panel is offscreen")
			var row: Control = lobby.active_world_rows.get_node("World_START")
			var label: Label = row.get_node("StartName")
			assert(label.get_theme_font_size("font_size") == 36)
			assert(label.get_theme_font("font").get_height(36) <= row.size.y, "World text clips vertically")
			if value == 1.25:
				assert(36 * label.get_screen_transform().y.length() >= 16, "Default mobile world text too small")
			row.get_node("StartJoin").pressed.emit()
			assert(lobby.joined_world == "START")
	lobby.free()
	await process_frame
	print("MOBILE_LOBBY_READABILITY_PASS")
	quit()
