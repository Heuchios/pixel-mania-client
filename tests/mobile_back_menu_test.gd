extends SceneTree


class MockWorld:
	extends Node

	var in_world := true
	var fishing_active := false
	var fishing_manager = null
	var open_states: Dictionary = {}
	var calls: Array[String] = []

	func is_chat_input_focused() -> bool:
		return bool(open_states.get("chat", false))

	func release_chat_focus() -> void:
		open_states["chat"] = false
		calls.append("release_chat")

	func is_trade_open() -> bool:
		return bool(open_states.get("trade", false))

	func cancel_trade_ui() -> void:
		close_state("trade")

	func close_trade_ui() -> void:
		close_state("trade")

	func is_sign_open() -> bool:
		return bool(open_states.get("sign", false))

	func close_sign() -> void:
		close_state("sign")

	func is_world_lock_ui_open() -> bool:
		return bool(open_states.get("world_lock", false))

	func close_world_lock_ui() -> void:
		close_state("world_lock")

	func is_area_lock_ui_open() -> bool:
		return bool(open_states.get("area_lock", false))

	func close_area_lock_ui() -> void:
		close_state("area_lock")

	func is_door_editor_open() -> bool:
		return bool(open_states.get("door_editor", false))

	func close_door_editor() -> void:
		close_state("door_editor")

	func is_password_door_entry_open() -> bool:
		return bool(open_states.get("password_door", false))

	func close_password_door_entry() -> void:
		close_state("password_door")

	func is_theme_machine_confirm_open() -> bool:
		return bool(open_states.get("theme_machine", false))

	func close_theme_machine_confirm() -> void:
		close_state("theme_machine")

	func is_vending_open() -> bool:
		return bool(open_states.get("vending", false))

	func close_vending_ui() -> void:
		close_state("vending")

	func is_safe_open() -> bool:
		return bool(open_states.get("safe", false))

	func close_safe_ui() -> void:
		close_state("safe")

	func is_mailbox_open() -> bool:
		return bool(open_states.get("mailbox", false))

	func close_mailbox_ui() -> void:
		close_state("mailbox")

	func is_bulletin_board_open() -> bool:
		return bool(open_states.get("bulletin", false))

	func close_bulletin_board_ui() -> void:
		close_state("bulletin")

	func is_display_open() -> bool:
		return bool(open_states.get("display", false))

	func close_display_ui() -> void:
		close_state("display")

	func is_fish_monger_open() -> bool:
		return bool(open_states.get("fish_monger", false))

	func close_fish_monger_ui() -> void:
		close_state("fish_monger")

	func is_cctv_open() -> bool:
		return bool(open_states.get("cctv", false))

	func close_cctv_ui() -> void:
		close_state("cctv")

	func is_oil_refinery_open() -> bool:
		return bool(open_states.get("oil_refinery", false))

	func close_oil_refinery_ui() -> void:
		close_state("oil_refinery")

	func is_battery_charger_open() -> bool:
		return bool(open_states.get("battery_charger", false))

	func close_battery_charger_ui() -> void:
		close_state("battery_charger")

	func is_generator_open() -> bool:
		return bool(open_states.get("generator", false))

	func close_generator_ui() -> void:
		close_state("generator")

	func is_developer_panel_open() -> bool:
		return bool(open_states.get("developer", false))

	func close_developer_panel() -> void:
		close_state("developer")

	func is_player_menu_open() -> bool:
		return bool(open_states.get("player_menu", false))

	func close_player_menu() -> void:
		close_state("player_menu")

	func is_settings_panel_open() -> bool:
		return bool(open_states.get("settings", false))

	func close_settings_panel() -> void:
		close_state("settings")

	func is_friends_panel_open() -> bool:
		return bool(open_states.get("friends", false))

	func close_friends_panel() -> void:
		close_state("friends")

	func is_furnace_open() -> bool:
		return bool(open_states.get("furnace", false))

	func close_furnace() -> void:
		close_state("furnace")

	func is_crafting_open() -> bool:
		return bool(open_states.get("crafting", false))

	func close_crafting() -> void:
		close_state("crafting")

	func is_notification_panel_open() -> bool:
		return bool(open_states.get("notifications", false))

	func close_notification_panel() -> void:
		close_state("notifications")

	func is_shop_open() -> bool:
		return bool(open_states.get("shop", false))

	func close_shop() -> void:
		close_state("shop")

	func is_inventory_open() -> bool:
		return bool(open_states.get("inventory", false))

	func close_inventory_window() -> void:
		close_state("inventory")

	func is_game_menu_open() -> bool:
		return bool(open_states.get("game_menu", false))

	func open_game_menu() -> void:
		open_states["game_menu"] = true
		calls.append("open_game_menu")

	func close_game_menu() -> void:
		close_state("game_menu")

	func is_world_menu_open() -> bool:
		return bool(open_states.get("world_menu", false))

	func resume_current_world() -> void:
		close_state("world_menu")

	func toggle_player_menu() -> void:
		calls.append("toggle_player_menu")

	func close_state(state_name: String) -> void:
		open_states[state_name] = false
		calls.append("close_" + state_name)


class BackHandlerStub:
	extends Node

	var request_count := 0

	func handle_back_request() -> bool:
		request_count += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)):
		fail_test("Android system Back is still configured to quit the app.")
		return

	var input_script := load("res://Scripts/input_manager.gd") as Script
	var world_script := load("res://Scripts/world.gd") as Script
	if input_script == null or world_script == null:
		fail_test("Could not load the mobile back handlers.")
		return

	var notification_world = world_script.new()
	var back_handler := BackHandlerStub.new()
	notification_world.input_manager = back_handler
	notification_world.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if back_handler.request_count != 1:
		fail_test("World did not route the OS go-back notification.")
		return
	notification_world.free()
	back_handler.free()

	var world := MockWorld.new()
	root.add_child(world)
	var input_manager = input_script.new()
	input_manager.setup(world)

	if not bool(input_manager.handle_back_request()):
		fail_test("Back request was not handled while in a world.")
		return
	if not world.is_game_menu_open() or world.calls != ["open_game_menu"]:
		fail_test("Back request did not open the game menu.")
		return

	world.calls.clear()
	input_manager.handle_back_request()
	if world.is_game_menu_open() or world.calls != ["close_game_menu"]:
		fail_test("Back request did not close an already-open game menu.")
		return

	world.calls.clear()
	world.open_states["inventory"] = true
	input_manager.handle_back_request()
	if world.is_inventory_open() or world.calls != ["close_inventory"]:
		fail_test("Back request did not close the top inventory panel first.")
		return
	if world.is_game_menu_open():
		fail_test("Back request opened the game menu over the inventory.")
		return

	world.calls.clear()
	world.open_states["chat"] = true
	input_manager.handle_back_request()
	if world.is_chat_input_focused() or world.calls != ["release_chat"]:
		fail_test("Back request did not release chat focus first.")
		return

	input_manager.free()
	world.free()
	print("[mobile-back-menu] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[mobile-back-menu] " + message)
	quit(1)
