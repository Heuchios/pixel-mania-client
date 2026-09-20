extends SceneTree

const START_WORLD := "START"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var lobby_scene := load("res://Scenes/ui/lobby/LobbyScene.tscn") as PackedScene
	assert(lobby_scene != null)
	var lobby: Node = lobby_scene.instantiate()
	lobby._setup_active_world_list()

	_assert_visible_worlds(lobby, [START_WORLD])
	_assert_start_hub_style(lobby)

	lobby._apply_world_population_counts({"START": 0, "TEST": 2, "EMPTY": 0}, true)
	_assert_visible_worlds(lobby, [START_WORLD, "TEST"])

	lobby._apply_world_population_counts({}, true)
	_assert_visible_worlds(lobby, [START_WORLD])

	lobby.active_world_row_template.free()
	lobby.active_world_row_template = null
	lobby.free()
	print("[lobby-start-world-entry] success")
	quit(0)


func _assert_visible_worlds(lobby, expected_worlds: Array[String]) -> void:
	var actual_worlds: Array[String] = []
	for child in lobby.active_world_rows.get_children():
		if child == lobby.active_world_empty_label:
			continue
		actual_worlds.append(str(child.get_meta("world_name", "")))
	assert(actual_worlds == expected_worlds)
	assert(not lobby.active_world_empty_label.visible)


func _assert_start_hub_style(lobby) -> void:
	var start_row: Node = lobby.active_world_rows.get_node_or_null("World_START")
	assert(start_row != null)
	assert(start_row.get_node("HubIcon").text == "H")
	assert(start_row.get_node("StartName").text == "START [0]")
	assert(start_row.get_node("StartMeta").text == "OFFICIAL | OPEN | 0 players")
	assert(start_row.get_node("OfficialBadge").text == "OFFICIAL HUB")
	var favorite_toggle := start_row.get_node("FavoriteToggle") as Button
	assert(favorite_toggle != null)
	assert(favorite_toggle.toggle_mode)
	favorite_toggle.set_pressed_no_signal(false)
	lobby._apply_favorite_toggle_visual(favorite_toggle)
	assert(favorite_toggle.icon.region == Rect2(32, 256, 32, 32))
	favorite_toggle.set_pressed_no_signal(true)
	lobby._apply_favorite_toggle_visual(favorite_toggle)
	assert(favorite_toggle.icon.region == Rect2(0, 256, 32, 32))
	assert(is_equal_approx(favorite_toggle.modulate.a, 1.0))
