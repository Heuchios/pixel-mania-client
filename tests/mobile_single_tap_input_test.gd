extends SceneTree

const InputManagerScript = preload("res://Scripts/input_manager.gd")
const TouchInputGuard = preload("res://Scripts/touch_input_guard.gd")


class MockWorld:
	extends Node

	var in_world := true
	var fishing_active := false
	var fishing_manager = null
	var inventory_manager = null
	var selected_item_category := "block"
	var selected_item_type := "dirt"
	var seed_inventory: Dictionary = {}
	var use_count := 0
	var pointer_position := Vector2.ZERO
	var pointer_active := false

	func use_selected_item_at_mouse() -> void:
		use_count += 1

	func set_mobile_pointer_screen_position(position: Vector2) -> void:
		pointer_position = position
		pointer_active = true

	func clear_mobile_pointer_screen_position() -> void:
		pointer_active = false

	func is_gameplay_ui_at_point(_point: Vector2) -> bool:
		return false

	func is_floating_hud_button_at_point(_point: Vector2) -> bool:
		return false

	func is_movement_locked() -> bool:
		return false

	func is_chat_input_focused() -> bool:
		return false

	func is_any_text_input_focused() -> bool:
		return false

	func is_player_menu_open() -> bool:
		return false

	func is_game_menu_open() -> bool:
		return false

	func is_world_menu_open() -> bool:
		return false

	func is_crafting_open() -> bool:
		return false

	func is_furnace_open() -> bool:
		return false

	func is_sign_open() -> bool:
		return false

	func is_shop_open() -> bool:
		return false

	func is_notification_panel_open() -> bool:
		return false

	func is_world_lock_ui_open() -> bool:
		return false

	func is_area_lock_ui_open() -> bool:
		return false

	func is_door_editor_open() -> bool:
		return false

	func is_trade_open() -> bool:
		return false

	func is_vending_open() -> bool:
		return false

	func is_safe_open() -> bool:
		return false

	func is_mailbox_open() -> bool:
		return false

	func is_bulletin_board_open() -> bool:
		return false

	func is_display_open() -> bool:
		return false

	func is_fish_monger_open() -> bool:
		return false

	func is_cctv_open() -> bool:
		return false

	func is_oil_refinery_open() -> bool:
		return false

	func is_battery_charger_open() -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 4
	touch_press.position = Vector2(420.0, 260.0)
	touch_press.pressed = true

	var emulated_mouse_press := InputEventMouseButton.new()
	emulated_mouse_press.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse_press.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse_press.position = touch_press.position
	emulated_mouse_press.pressed = true

	var physical_mouse_press := InputEventMouseButton.new()
	physical_mouse_press.device = 0
	physical_mouse_press.button_index = MOUSE_BUTTON_LEFT
	physical_mouse_press.position = touch_press.position
	physical_mouse_press.pressed = true

	if TouchInputGuard.is_emulated_mouse_from_touch(touch_press):
		fail_test("A real screen touch was classified as emulated mouse input.")
		return
	if not TouchInputGuard.is_emulated_mouse_from_touch(emulated_mouse_press):
		fail_test("The touch-emulated mouse event was not recognized.")
		return
	if TouchInputGuard.is_emulated_mouse_from_touch(physical_mouse_press):
		fail_test("A physical mouse event was incorrectly suppressed.")
		return

	var world := MockWorld.new()
	root.add_child(world)
	var input_manager = InputManagerScript.new()
	root.add_child(input_manager)
	input_manager.setup(world)

	input_manager.handle_unhandled_input(touch_press)
	input_manager.handle_unhandled_input(emulated_mouse_press)
	if world.use_count != 1:
		fail_test("One touch plus its emulated mouse copy dispatched %d gameplay actions." % world.use_count)
		return
	if int(input_manager.active_touch_index) != touch_press.index:
		fail_test("The emulated mouse press replaced the active touch owner.")
		return

	var emulated_mouse_release := emulated_mouse_press.duplicate() as InputEventMouseButton
	emulated_mouse_release.pressed = false
	input_manager.handle_unhandled_input(emulated_mouse_release)
	if int(input_manager.active_touch_index) != touch_press.index:
		fail_test("The emulated mouse release stopped the real touch hold.")
		return

	var touch_release := touch_press.duplicate() as InputEventScreenTouch
	touch_release.pressed = false
	input_manager.handle_unhandled_input(touch_release)
	if bool(input_manager.is_holding) or int(input_manager.active_touch_index) != -1:
		fail_test("The real touch release did not stop gameplay hold tracking.")
		return

	input_manager.handle_unhandled_input(physical_mouse_press)
	if world.use_count != 2:
		fail_test("The emulation filter blocked a real mouse gameplay action.")
		return
	var physical_mouse_release := physical_mouse_press.duplicate() as InputEventMouseButton
	physical_mouse_release.pressed = false
	input_manager.handle_unhandled_input(physical_mouse_release)

	input_manager.queue_free()
	world.queue_free()
	print("[mobile-single-tap-input] success")
	quit(0)


func fail_test(message: String) -> void:
	push_error("[mobile-single-tap-input] " + message)
	quit(1)
