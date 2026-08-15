extends SceneTree

const GameMenuScript := preload("res://Scripts/game_menu_ui.gd")


class MockWorld:
	extends Node

	var hud_layer: Control = null
	var game_menu = null
	var calls: Array[String] = []
	var notifications: Array[String] = []
	var in_world := true

	func is_player_in_world() -> bool:
		return in_world

	func get_ui_hud_layer() -> Node:
		return hud_layer

	func open_game_menu() -> void:
		calls.append("open_game_menu")
		if game_menu != null and game_menu.has_method("open_menu"):
			game_menu.open_menu()

	func open_player_menu() -> void:
		calls.append("open_player_menu")

	func open_friends_panel() -> void:
		calls.append("open_friends_panel")

	func respawn_player() -> void:
		calls.append("respawn_player")

	func show_notification(message: String) -> void:
		notifications.append(message)

	func open_settings_panel() -> void:
		calls.append("open_settings_panel")

	func exit_to_world_menu() -> void:
		calls.append("exit_to_world_menu")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame

	var ui_layer := Control.new()
	ui_layer.name = "UILayer"
	root.add_child(ui_layer)

	var hud_layer := Control.new()
	hud_layer.name = "HUDLayer"
	root.add_child(hud_layer)

	var world := MockWorld.new()
	world.hud_layer = hud_layer
	root.add_child(world)

	var game_menu := Control.new()
	game_menu.name = "GameMenuUI"
	game_menu.set_script(GameMenuScript)
	ui_layer.add_child(game_menu)
	world.game_menu = game_menu
	game_menu.setup(world, ui_layer)
	await process_frame

	var menu_scene := game_menu.get("menu_scene_instance") as Control
	if menu_scene == null:
		fail_test("GameMenuUI did not instantiate MenuScene.tscn.")
		return
	if menu_scene.scene_file_path != "res://Scenes/ui/menu/MenuScene.tscn":
		fail_test("GameMenuUI instantiated the wrong menu scene.")
		return
	if bool(menu_scene.get("apply_exported_content_on_ready")):
		fail_test("Scene-backed game menu should preserve authored content by default.")
		return
	var viewport_size := game_menu.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		fail_test("Test viewport has no usable size.")
		return
	game_menu.update_overlay_position()
	await process_frame
	if not game_menu.size.is_equal_approx(viewport_size):
		fail_test("GameMenuUI did not fill the viewport.")
		return
	if not menu_scene.size.is_equal_approx(viewport_size):
		fail_test("Scene-backed menu did not fill the viewport.")
		return
	var center_container := menu_scene.get_node("CenterContainer") as CenterContainer
	if not center_container.size.is_equal_approx(viewport_size):
		fail_test("Menu CenterContainer did not fill the viewport. expected=%s actual=%s root=%s game_menu=%s" % [viewport_size, center_container.size, menu_scene.size, game_menu.size])
		return
	var menu_window := menu_scene.get_node("CenterContainer/MenuWindow") as Control
	var expected_panel_position := (viewport_size - (menu_window.size * menu_window.scale)) * 0.5
	if menu_window.global_position.distance_to(expected_panel_position) > 4.0:
		fail_test("Scene-backed menu panel was not centered in the viewport. expected=%s actual=%s size=%s scale=%s viewport=%s center=%s" % [expected_panel_position, menu_window.global_position, menu_window.size, menu_window.scale, viewport_size, center_container.size])
		return
	var title_label := menu_scene.get_node("CenterContainer/MenuWindow/Header/TitleLabel") as Label
	title_label.text = "RUNTIME AUTHORED"
	game_menu.update_overlay_position()
	await process_frame
	if title_label.text != "RUNTIME AUTHORED":
		fail_test("GameMenuUI update path overwrote a direct scene edit.")
		return
	if game_menu.is_open():
		fail_test("GameMenuUI should start closed after setup.")
		return

	var hud_menu_button := hud_layer.get_node_or_null("GameMenuButton") as Button
	if hud_menu_button == null:
		fail_test("HUD menu button was not created.")
		return

	hud_menu_button.pressed.emit()
	await process_frame
	if not game_menu.is_open():
		fail_test("HUD menu button did not open the scene-backed menu.")
		return
	if world.calls != ["open_game_menu"]:
		fail_test("HUD menu button did not use the existing world open_game_menu path.")
		return

	var player_button := menu_scene.get_node_or_null("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonPlayerInfo") as Button
	if player_button == null:
		fail_test("Scene-backed player info button is missing.")
		return
	player_button.pressed.emit()
	await process_frame
	if game_menu.is_open():
		fail_test("Player info action did not close the game menu.")
		return
	if not world.calls.has("open_player_menu"):
		fail_test("Player info action did not call world.open_player_menu().")
		return

	game_menu.open_menu()
	await process_frame
	var respawn_button := menu_scene.get_node_or_null("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonRespawn") as Button
	if respawn_button == null:
		fail_test("Scene-backed respawn button is missing.")
		return
	respawn_button.pressed.emit()
	await process_frame
	if not world.calls.has("respawn_player"):
		fail_test("Respawn action did not call world.respawn_player().")
		return
	if world.notifications != ["Respawned at the Entrance Gate."]:
		fail_test("Respawn action did not preserve the existing notification.")
		return

	game_menu.open_menu()
	await process_frame
	var settings_button := menu_scene.get_node_or_null("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonSettings") as Button
	if settings_button == null:
		fail_test("Scene-backed settings button is missing.")
		return
	settings_button.pressed.emit()
	await process_frame
	if not world.calls.has("open_settings_panel"):
		fail_test("Settings action did not call world.open_settings_panel().")
		return

	game_menu.open_menu()
	await process_frame
	var back_button := menu_scene.get_node_or_null("CenterContainer/MenuWindow/BackButton") as Button
	if back_button == null:
		fail_test("Scene-backed back button is missing.")
		return
	back_button.pressed.emit()
	await process_frame
	if game_menu.is_open():
		fail_test("Back button did not close the scene-backed menu.")
		return

	game_menu.queue_free()
	world.queue_free()
	hud_layer.queue_free()
	ui_layer.queue_free()
	print("[game-menu-scene-wiring] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[game-menu-scene-wiring] " + message)
	quit(1)
