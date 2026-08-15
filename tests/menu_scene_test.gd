extends SceneTree

const MENU_SCENE := preload("res://Scenes/ui/menu/MenuScene.tscn")
const MenuButtonData := preload("res://Scripts/ui/menu_button_data.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame

	if menu.get_node_or_null("CenterContainer/MenuWindow") == null:
		fail_test("Editable MenuWindow node is missing.")
		return
	if menu.get_node_or_null("CenterContainer/MenuWindow/Header/TitleLabel") == null:
		fail_test("Editable title label node is missing.")
		return
	if menu.get_node_or_null("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonPlayerInfo/Icon") == null:
		fail_test("Editable action icon node is missing.")
		return
	if menu.get_node_or_null("CenterContainer/MenuWindow/CloseButton") == null:
		fail_test("Editable close button node is missing.")
		return
	if menu.get_node_or_null("CenterContainer/MenuWindow/BackButton") == null:
		fail_test("Editable back button node is missing.")
		return
	if not menu.has_signal("action_pressed"):
		fail_test("Missing action_pressed signal.")
		return
	if not menu.has_signal("close_pressed"):
		fail_test("Missing close_pressed signal.")
		return
	if not menu.has_signal("back_pressed"):
		fail_test("Missing back_pressed signal.")
		return

	var title_label := menu.get_node("CenterContainer/MenuWindow/Header/TitleLabel") as Label
	title_label.text = "AUTHORED"
	menu.refresh_preview()
	if title_label.text != "AUTHORED":
		fail_test("refresh_preview() should not overwrite direct scene edits while exported content is disabled.")
		return
	var authored_viewport_size := Vector2(1280.0, 720.0)
	menu.fit_overlay_to_viewport(authored_viewport_size)
	await process_frame
	if not menu.size.is_equal_approx(authored_viewport_size):
		fail_test("MenuScene did not resize its root overlay to the requested viewport.")
		return
	var center_container := menu.get_node("CenterContainer") as CenterContainer
	if not center_container.size.is_equal_approx(authored_viewport_size):
		fail_test("MenuScene did not resize its center container to the requested viewport.")
		return
	if title_label.text != "AUTHORED":
		fail_test("fit_overlay_to_viewport() should not overwrite direct scene edits.")
		return

	menu.apply_exported_content_on_ready = true
	menu.apply_exported_styles_on_ready = true
	menu.apply_exported_layout_on_ready = true
	menu.refresh_preview()
	if title_label.text != "MENU":
		fail_test("Exported title did not render after enabling exported content.")
		return

	var player_button := menu.get_node("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonPlayerInfo") as Button
	var player_icon := player_button.get_node("Icon") as TextureRect
	if player_icon.texture == null:
		fail_test("Default player info icon did not render.")
		return

	var respawn_button := menu.get_node("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonRespawn") as Button
	var captured_default_actions: Array[String] = []
	menu.action_pressed.connect(func(action_id: String, _index: int, _data: Resource) -> void:
		captured_default_actions.append(action_id)
	)
	player_button.pressed.emit()
	respawn_button.pressed.emit()
	if captured_default_actions != ["player_info", "respawn"]:
		fail_test("Default action buttons did not emit the expected action ids.")
		return

	var custom_action: Resource = MenuButtonData.new()
	custom_action.set("label", "CUSTOM")
	custom_action.set("action_id", "custom_action")
	custom_action.set("button_style", "green")
	menu.show_action_labels = true
	menu.set_actions_from_dictionaries([custom_action])
	await process_frame

	var custom_button := menu.get_node("CenterContainer/MenuWindow/BodyPanel/ActionsRoot/ActionButtonPlayerInfo") as Button
	var custom_label := custom_button.get_node("ActionLabel") as Label
	if custom_label.text != "CUSTOM":
		fail_test("Custom action label did not render.")
		return
	if not custom_label.visible:
		fail_test("Custom action label should be visible when action labels are enabled.")
		return

	var captured_actions: Array[String] = []
	menu.action_pressed.connect(func(action_id: String, _index: int, _data: Resource) -> void:
		captured_actions.append(action_id)
	)
	custom_button.pressed.emit()
	if captured_actions != ["custom_action"]:
		fail_test("Custom action button did not emit action_pressed.")
		return

	menu.panel_fill_color = Color(0.21, 0.11, 0.32, 0.9)
	menu.refresh_preview()
	var window_back := menu.get_node("CenterContainer/MenuWindow/WindowBack") as Panel
	var window_style := window_back.get_theme_stylebox("panel") as StyleBoxFlat
	if window_style == null or not window_style.bg_color.is_equal_approx(Color(0.21, 0.11, 0.32, 0.9)):
		fail_test("Panel fill color export did not apply.")
		return

	var close_calls: Array[bool] = []
	menu.close_pressed.connect(func() -> void:
		close_calls.append(true)
	)
	menu.open_menu()
	var close_button := menu.get_node("CenterContainer/MenuWindow/CloseButton") as Button
	close_button.pressed.emit()
	if close_calls.is_empty():
		fail_test("Close button did not emit close_pressed.")
		return
	if menu.is_open():
		fail_test("Close button should hide the standalone menu by default.")
		return

	menu.free()
	print("[menu-scene] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[menu-scene] " + message)
	quit(1)
