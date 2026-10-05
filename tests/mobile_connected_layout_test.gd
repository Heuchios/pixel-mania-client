extends SceneTree

class PhoneScale extends "res://Scripts/ui/mobile_ui_scale.gd":
	func is_mobile() -> bool:
		return true

class ControlsWorld extends Node:
	var in_world := true
	var ui_layer: CanvasLayer
	func get_ui_hud_layer() -> Node:
		return ui_layer

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Pixelmania/work/" + filename + ".png")

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var scaling = root.get_node("MobileUIScale")
	scaling.set_script(PhoneScale)
	scaling.set_process(true)
	scaling.ui_scale = 1.5
	var login = load("res://Scenes/ui/login/LoginScene.tscn").instantiate()
	login.set_script(load("res://tests/fixtures/mobile_login_fixture.gd"))
	root.add_child(login)
	for dimensions in [Vector2i(1300, 600), Vector2i(1280, 720), Vector2i(640, 360)]:
		root.size = dimensions
		for value in [0.75, 1.0, 1.25, 1.5]:
			scaling.ui_scale = value
			await process_frame
			await process_frame
			var news: Control = login.get_node("NewsPanel")
			var form: Control = login.get_node("LoginPanel/Form")
			assert(not news.get_global_rect().intersects(form.get_global_rect()), "News overlaps login form")
			assert(login.get_viewport_rect().encloses(form.get_global_rect()), "Login form offscreen")
			assert(login.get_viewport_rect().encloses(login.get_node("LoginPanel/Logo").get_global_rect()), "Logo offscreen")
	root.size = Vector2i(1300, 600)
	scaling.ui_scale = 1.5
	await process_frame
	await process_frame
	await capture("phone-150-login")
	login.free()

	var lobby = load("res://Scenes/ui/lobby/LobbyScene.tscn").instantiate()
	lobby.set_script(load("res://tests/fixtures/mobile_lobby_fixture.gd"))
	lobby.mobile = true
	root.add_child(lobby)
	lobby._configure_mobile_lobby()
	lobby._apply_world_population_counts({"START": 0, "TEST": 2}, true)
	for active in [true, false]:
		lobby._on_landfill_status_received({"event_active": active})
		await process_frame
		await process_frame
		var bounds: Rect2 = lobby.get_node("WorldsPanel").get_global_rect().merge(lobby.get_node("LeftButtons").get_global_rect())
		if active:
			assert(not bounds.intersects(lobby.landfill_event_card.get_global_rect()))
		else:
			assert(absf(bounds.get_center().x - lobby.get_viewport_rect().size.x * 0.5) < 2, "Inactive event leaves lobby off center")
	await capture("phone-150-lobby")
	lobby.free()

	var layer := CanvasLayer.new()
	root.add_child(layer)
	var manager = load("res://Scripts/inventory_manager.gd").new()
	layer.add_child(manager)
	manager.set_process(false)
	var hotbar = load("res://Scenes/ui/hotbar/Hotbar.tscn").instantiate()
	layer.add_child(hotbar)
	hotbar.size = Vector2(manager.get_hotbar_base_visual_width(), manager.get_hotbar_base_visual_height())
	manager.hotbar_root = hotbar
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	layer.add_child(inventory)
	inventory.position = Vector2.ZERO
	manager.inventory_window = inventory
	inventory.set_inventory_items(inventory._make_preview_items())
	var chat = load("res://Scenes/ui/chat/ChatScene.tscn").instantiate()
	layer.add_child(chat)
	chat.set_process(false)
	var corner_buttons: Array[Control] = []
	for index in range(2):
		var button := Button.new()
		button.size = Vector2(64, 64)
		layer.add_child(button)
		corner_buttons.append(button)
	corner_buttons.append(chat.chat_button)
	var controls_world := ControlsWorld.new()
	layer.add_child(controls_world)
	controls_world.ui_layer = layer
	var controls = load("res://tests/fixtures/mobile_controls_fixture.gd").new()
	layer.add_child(controls)
	controls.settings_save_path = "res://tmp/mobile_connected_unused.cfg"
	controls.setup(controls_world)
	for dimensions in [Vector2i(1300, 600), Vector2i(1280, 720), Vector2i(640, 360)]:
		root.size = dimensions
		await process_frame
		for value in [0.75, 1.0, 1.25, 1.5]:
			scaling.ui_scale = value
			for amount in [0.0, 0.25, 0.5, 1.0, 0.0]:
				manager.inventory_drawer_amount = amount
				manager.inventory_drawer_target = amount
				manager.update_hotbar_position()
				manager.update_inventory_window_position()
				chat.chat_panel_amount = amount
				chat.chat_panel_target = amount
				chat.update_chat_position()
				for index in range(3):
					scaling.layout_corner_button(corner_buttons[index], index, root.get_visible_rect().size)
				await process_frame
				await process_frame
				assert(root.get_visible_rect().encloses(hotbar.get_global_rect()), "Hotbar offscreen")
				if amount > 0:
					assert(absf(inventory.window.get_node("WindowSkin").get_global_rect().position.y - hotbar.get_global_rect().end.y) < 1, "Drawer separates from hotbar")
				if amount == 1:
					var drawer_bounds: Rect2 = inventory.window.get_node("WindowSkin").get_global_rect().merge(inventory.tabs.get_global_rect())
					assert(root.get_visible_rect().encloses(drawer_bounds), "Open drawer clips outside viewport")
					for action in ["move_left", "move_right", "jump", "punch", "zoom_in", "zoom_out"]:
						assert(not controls.action_buttons[action].get_global_rect().intersects(inventory.inventory_scroll.get_global_rect()), "Touch control covers item grid: " + action)
					for action in ["jump", "punch"]:
						for button in corner_buttons:
							assert(not controls.action_buttons[action].get_global_rect().intersects(button.get_global_rect()), "Action button overlaps HUD column")
				if amount == 0:
					assert(absf(chat.chat_handle.get_global_rect().position.y - 8) < 1, "Closed chat handle drifts from top")
				assert(not corner_buttons[0].get_global_rect().intersects(corner_buttons[1].get_global_rect()), "Home overlaps shop")
				assert(not corner_buttons[1].get_global_rect().intersects(corner_buttons[2].get_global_rect()), "Shop overlaps chat")
	# Exercise touch hit testing at the transformed handle, not just the stored position.
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = chat.chat_handle.get_global_rect().get_center()
	touch.pressed = true
	assert(chat.handle_global_chat_handle_touch_input(touch))
	touch.pressed = false
	assert(chat.handle_global_chat_handle_touch_input(touch))
	assert(chat.chat_panel_target == 1.0, "Tapping transformed chat handle opens drawer")
	chat.chat_panel_amount = 1.0
	chat.update_chat_position()
	touch.position = chat.chat_handle.get_global_rect().get_center()
	touch.pressed = true
	assert(chat.handle_global_chat_handle_touch_input(touch))
	var drag := InputEventScreenDrag.new()
	drag.index = touch.index
	drag.position = touch.position - Vector2(0, chat.get_authored_chat_drag_height())
	assert(chat.handle_global_chat_handle_touch_input(drag))
	touch.position = drag.position
	touch.pressed = false
	assert(chat.handle_global_chat_handle_touch_input(touch))
	assert(is_zero_approx(chat.chat_panel_target), "Dragging scaled chat handle back up closes drawer")
	root.size = Vector2i(1300, 600)
	scaling.ui_scale = 1.5
	await process_frame
	manager.inventory_drawer_amount = 1.0
	manager.inventory_drawer_target = 1.0
	manager.update_hotbar_position()
	manager.update_inventory_window_position()
	chat.chat_panel_amount = 0.0
	chat.chat_panel_target = 0.0
	chat.update_chat_position()
	for index in range(3):
		scaling.layout_corner_button(corner_buttons[index], index, root.get_visible_rect().size)
	await process_frame
	await process_frame
	assert(not chat.chat_handle.get_global_rect().intersects(hotbar.get_node("InventorySlideHandle").get_global_rect()), "Closed chat and open inventory handles overlap")
	# A real viewport touch must select the item under the drawn slot.
	var selected: Array = []
	inventory.item_selected.connect(func(item: Dictionary): selected.append(item))
	var first_slot: Control = inventory.slot_nodes.values()[0]
	touch.position = first_slot.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	assert(not selected.is_empty(), "Touching scaled inventory slot does not select it")
	for action in ["move_left", "move_right", "jump", "punch", "zoom_in", "zoom_out"]:
		assert(not controls.action_buttons[action].get_global_rect().intersects(inventory.inventory_scroll.get_global_rect()), "Touch control overlaps item grid: " + action)
	await capture("phone-150-inventory")
	inventory.close_button.pressed.emit()
	assert(not inventory.visible, "Inventory close stops showing the drawer")
	layer.free()
	print("MOBILE_CONNECTED_LAYOUT_PASS")
	quit()
