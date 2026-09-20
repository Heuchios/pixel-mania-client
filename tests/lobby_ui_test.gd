extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var lobby = load("res://Scenes/ui/lobby/LobbyScene.tscn").instantiate()
	lobby.set_script(load("res://tests/lobby_ui_fixture.gd"))
	root.add_child(lobby)
	lobby._apply_world_population_counts({"START": 0, "CANADA": 10, "AURORA": 3, "BUILD12": 1, "GOPARKOUR": 24, "VEND1": 5, "EMPTY": 0}, true)
	assert(lobby._build_world_entries().size() == 6)
	var row = lobby.active_world_rows.get_node("World_START")
	row.get_node("StartJoin").pressed.emit()
	assert(lobby.joined_world == "START")
	row.get_node("StartJoin").grab_focus()
	lobby.lobby_animation_time = 0.0
	for frame in range(3):
		lobby._update_lobby_button_animation(0.0 if frame == 0 else 0.14)
		assert(row.get_node("StartJoin").icon.region == Rect2((22 + frame) * 32, 64, 32, 32))
	row.get_node("StartJoin").release_focus()
	lobby._update_lobby_button_animation(0.0)
	assert(row.get_node("StartJoin").icon.region.position == Vector2(704, 64))
	var heart = row.get_node("FavoriteToggle")
	heart.button_pressed = true
	assert(lobby.saved_favorites == ["START"])
	assert(heart.icon.region == Rect2(0, 256, 32, 32))
	heart.button_pressed = false
	assert(lobby.saved_favorites.is_empty())
	assert(heart.icon.region == Rect2(32, 256, 32, 32))
	lobby.get_node("LeftButtons/OfficialButton").pressed.emit()
	assert(lobby.active_world_filter == "official")
	assert(lobby._build_world_entries() == [{"world": "START", "count": 0}])
	lobby.get_node("LeftButtons/WorldOfWeekButton").pressed.emit()
	assert(lobby.active_world_filter == "week")
	assert(lobby.active_world_empty_label.visible)
	lobby.world_of_the_week = "CANADA"
	assert(lobby._build_world_entries()[0].world == "CANADA")
	lobby.get_node("LeftButtons/RecentButton").pressed.emit()
	assert(lobby._build_world_entries()[0].world == "LAST")
	lobby.owned_world_names.assign(["MINE"])
	lobby.get_node("LeftButtons/MyWorldsButton").pressed.emit()
	assert(lobby._build_world_entries()[0].world == "MINE")
	lobby.get_node("LeftButtons/FavoritesButton").pressed.emit()
	assert(lobby.active_world_filter == "favorites")
	lobby.get_node("LeftButtons/ActiveButton").pressed.emit()
	assert(lobby.active_world_filter == "active")
	lobby.get_node("LeftButtons/ActiveButton").pressed.emit()
	assert(lobby.active_world_filter == "active")
	lobby.world_input.text = "CANADA"
	lobby.join_button.pressed.emit()
	assert(lobby.joined_world == "CANADA")
	lobby.world_input.text_submitted.emit("CANADA")
	assert(lobby.joined_world == "CANADA")
	lobby._on_landfill_status_received({"event_active": true})
	lobby.landfill_join_button.pressed.emit()
	assert(lobby.event_requests == 1)
	lobby.lobby_animation_time = 0.0
	for frame in range(4):
		lobby._update_lobby_button_animation(0.0 if frame == 0 else 0.22)
		assert(lobby.landfill_join_button.icon.region == Rect2(frame * 64, 288, 64, 64))
	lobby._on_landfill_status_received({"event_active": false})
	assert(not lobby.landfill_event_card.visible)
	lobby._on_landfill_status_received({"event_active": true})
	if "--render" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
		lobby.world_input.text = ""
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/lobby-updated.png")
	lobby.free()
	await process_frame
	print("[lobby-ui] PASS: filters, favorites, entry, event and atlas regions")
	quit()
