extends Node

const TouchInputGuard = preload("res://Scripts/touch_input_guard.gd")

# PixelMania Input Manager v2
#
# Hold-to-repeat: holding left mouse button or touch continues placing/breaking.
# - First action fires immediately on press (no delay).
# - After HOLD_INITIAL_DELAY seconds the repeat begins.
# - Repeats every HOLD_REPEAT_RATE seconds until released.
# - Automatically cancels if blocking UI opens or the player enters chat.

const HOLD_INITIAL_DELAY = 0.30  # seconds before repeat kicks in
const HOLD_REPEAT_RATE   = 0.30  # seconds between repeats
const HOLD_SEED_HARVEST_INITIAL_DELAY = 0.0  # faster feedback for immediate seed harvest loops
const HOLD_SEED_HARVEST_REPEAT_RATE = 0.20  # aligned to faster harvest cadence
const HOLD_SEED_PLACE_INITIAL_DELAY = 0.0  # faster feedback for immediate seed planting loops
const HOLD_SEED_PLACE_REPEAT_RATE = 0.20  # aligned with seed planting responsiveness

var world = null

var is_holding         := false
var hold_timer         := 0.0
var hold_repeat_active := false  # true once past the initial delay
var active_touch_index := -1


func setup(world_ref):
	world = world_ref


func get_hotbar_slot_from_key_event(event: InputEventKey) -> int:
	var number_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
	var keypad_keys := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6]
	for i in range(number_keys.size()):
		if event.keycode == number_keys[i] or event.physical_keycode == number_keys[i]:
			return i
		if event.keycode == keypad_keys[i] or event.physical_keycode == keypad_keys[i]:
			return i
	return -1


func _process(delta):
	if not is_holding:
		return

	if world == null or not world.in_world:
		_stop_hold()
		return

	# Cancel hold the moment any UI steals focus.
	if _any_ui_blocking():
		_stop_hold()
		return
	if active_touch_index == -1:
		var pointer_position: Vector2 = world.get_viewport().get_mouse_position()
		if _is_gameplay_ui_at_point(pointer_position):
			_stop_hold()
			return

	hold_timer += delta

	var using_seed_harvest_hold = _is_seed_harvest_hold_repeat()
	var using_seed_place_hold = _is_seed_place_hold_repeat()

	if not hold_repeat_active:
		var initial_delay = HOLD_SEED_HARVEST_INITIAL_DELAY if using_seed_harvest_hold else HOLD_SEED_PLACE_INITIAL_DELAY if using_seed_place_hold else HOLD_INITIAL_DELAY
		if hold_timer >= initial_delay:
			hold_repeat_active = true
			hold_timer = 0.0
			world.use_selected_item_at_mouse()
	else:
		var repeat_rate = HOLD_SEED_HARVEST_REPEAT_RATE if using_seed_harvest_hold else HOLD_SEED_PLACE_REPEAT_RATE if using_seed_place_hold else HOLD_REPEAT_RATE
		if hold_timer >= repeat_rate:
			hold_timer = 0.0
			world.use_selected_item_at_mouse()


func _is_seed_harvest_hold_repeat() -> bool:
	if world == null:
		return false
	if world.selected_item_category != "tool" or str(world.selected_item_type).to_lower() != "punch":
		return false
	if not world.has_method("get_clicked_planted_seed_grid"):
		return false
	if not world.has_method("has_planted_seed"):
		return false
	if not world.has_method("can_harvest_seed_tree_now"):
		return false

	var clicked_seed_grid = world.get_clicked_planted_seed_grid()
	if not world.has_planted_seed(clicked_seed_grid):
		return false

	return bool(world.can_harvest_seed_tree_now(clicked_seed_grid))


func _is_seed_place_hold_repeat() -> bool:
	if world == null:
		return false
	if world.selected_item_category != "seed":
		return false
	var selected_seed_type := str(world.selected_item_type).strip_edges()
	if selected_seed_type == "":
		return false
	if "seed_inventory" in world and world.seed_inventory is Dictionary:
		if not world.seed_inventory.has(selected_seed_type):
			return false
		if int(world.seed_inventory[selected_seed_type]) <= 0:
			return false
	return true


func _stop_hold():
	var was_holding: bool = is_holding
	if active_touch_index != -1 and world != null and world.has_method("clear_mobile_pointer_screen_position"):
		world.clear_mobile_pointer_screen_position()
	active_touch_index = -1
	is_holding         = false
	hold_timer         = 0.0
	hold_repeat_active = false
	if was_holding and world != null and world.inventory_manager != null and world.inventory_manager.has_method("notify_inventory_gameplay_hold_stopped"):
		world.inventory_manager.notify_inventory_gameplay_hold_stopped()


func _any_ui_blocking() -> bool:
	if world.has_method("is_movement_locked") and world.is_movement_locked(): return true
	if world.is_chat_input_focused():   return true
	if world.is_player_menu_open():     return true
	if world.has_method("is_game_menu_open") and world.is_game_menu_open(): return true
	if world.is_world_menu_open():      return true
	if world.is_crafting_open():        return true
	if world.is_furnace_open():         return true
	if world.is_sign_open():            return true
	if world.is_shop_open():            return true
	if world.has_method("is_notification_panel_open") and world.is_notification_panel_open(): return true
	if world.is_world_lock_ui_open():   return true
	if world.has_method("is_area_lock_ui_open") and world.is_area_lock_ui_open():   return true
	if world.has_method("is_door_editor_open") and world.is_door_editor_open(): return true
	if world.has_method("is_trade_open") and world.is_trade_open(): return true
	if world.has_method("is_vending_open") and world.is_vending_open(): return true
	if world.has_method("is_safe_open") and world.is_safe_open(): return true
	if world.has_method("is_mailbox_open") and world.is_mailbox_open(): return true
	if world.has_method("is_bulletin_board_open") and world.is_bulletin_board_open(): return true
	if world.has_method("is_leaderboard_open") and world.is_leaderboard_open(): return true
	if world.has_method("is_display_open") and world.is_display_open(): return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
	if world.has_method("is_cctv_open") and world.is_cctv_open(): return true
	if world.has_method("is_oil_refinery_open") and world.is_oil_refinery_open(): return true
	if world.has_method("is_battery_charger_open") and world.is_battery_charger_open(): return true
	return false


func _is_gameplay_ui_at_point(point: Vector2) -> bool:
	if world == null:
		return false
	if world.has_method("is_gameplay_ui_at_point"):
		return bool(world.is_gameplay_ui_at_point(point))
	if world.has_method("is_inventory_ui_at_point") and world.is_inventory_ui_at_point(point):
		return true
	return false


func _is_floating_hud_button_at_point(point: Vector2) -> bool:
	if world == null:
		return false
	if world.has_method("is_floating_hud_button_at_point"):
		return bool(world.is_floating_hud_button_at_point(point))
	return false


func _activate_floating_hud_button_at_point(point: Vector2) -> bool:
	if world == null:
		return false
	if not world.has_method("activate_floating_hud_button_at_point"):
		return false
	if not bool(world.activate_floating_hud_button_at_point(point)):
		return false
	world.get_viewport().set_input_as_handled()
	return true


func _non_chat_ui_blocking() -> bool:
	if world.is_player_menu_open():     return true
	if world.has_method("is_game_menu_open") and world.is_game_menu_open(): return true
	if world.is_world_menu_open():      return true
	if world.is_crafting_open():        return true
	if world.is_furnace_open():         return true
	if world.is_sign_open():            return true
	if world.is_shop_open():            return true
	if world.has_method("is_notification_panel_open") and world.is_notification_panel_open(): return true
	if world.is_world_lock_ui_open():   return true
	if world.has_method("is_area_lock_ui_open") and world.is_area_lock_ui_open():   return true
	if world.has_method("is_door_editor_open") and world.is_door_editor_open(): return true
	if world.has_method("is_trade_open") and world.is_trade_open(): return true
	if world.has_method("is_vending_open") and world.is_vending_open(): return true
	if world.has_method("is_safe_open") and world.is_safe_open(): return true
	if world.has_method("is_mailbox_open") and world.is_mailbox_open(): return true
	if world.has_method("is_bulletin_board_open") and world.is_bulletin_board_open(): return true
	if world.has_method("is_leaderboard_open") and world.is_leaderboard_open(): return true
	if world.has_method("is_display_open") and world.is_display_open(): return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
	if world.has_method("is_cctv_open") and world.is_cctv_open(): return true
	if world.has_method("is_oil_refinery_open") and world.is_oil_refinery_open(): return true
	if world.has_method("is_battery_charger_open") and world.is_battery_charger_open(): return true
	if world.has_method("is_developer_panel_open") and world.is_developer_panel_open(): return true
	return false


func _handle_fishing_click_if_active() -> bool:
	if world == null:
		return false

	var fishing_is_active := false
	if "fishing_active" in world:
		fishing_is_active = bool(world.fishing_active)
	if not fishing_is_active and world.fishing_manager != null and world.fishing_manager.has_method("is_fishing_active"):
		fishing_is_active = bool(world.fishing_manager.is_fishing_active())

	if not fishing_is_active:
		return false

	if _non_chat_ui_blocking():
		return false
	if world.is_chat_input_focused() or world.is_any_text_input_focused():
		return false

	if world.fishing_manager != null and world.fishing_manager.has_method("handle_fishing_action"):
		_stop_hold()
		world.fishing_manager.handle_fishing_action()
		world.get_viewport().set_input_as_handled()
		return true

	return false


func _release_text_input_focus_from_pointer_click() -> bool:
	if world == null:
		return false

	var focus_owner = world.get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	if not (focus_owner is LineEdit) and not (focus_owner is TextEdit):
		return false

	if world.is_chat_input_focused() and world.has_method("release_chat_focus"):
		world.release_chat_focus()
	else:
		focus_owner.release_focus()

	if "chat_typing_movement_locked" in world:
		world.chat_typing_movement_locked = false

	_stop_hold()
	world.get_viewport().set_input_as_handled()
	return true


func start_inventory_gameplay_hold(touch_index: int = -1) -> bool:
	if world == null or not world.in_world:
		return false
	if _any_ui_blocking():
		return false

	active_touch_index = touch_index
	is_holding = true
	hold_timer = 0.0
	hold_repeat_active = false
	return true


func stop_inventory_gameplay_hold(touch_index: int = -1) -> void:
	if touch_index == -1 or active_touch_index == touch_index:
		_stop_hold()


func handle_back_request() -> bool:
	if world == null or not world.in_world:
		return false

	_stop_hold()
	if world.is_chat_input_focused():
		if world.has_method("release_chat_focus"):
			world.release_chat_focus()
	elif world.has_method("is_trade_open") and world.is_trade_open():
		if world.has_method("cancel_trade_ui"):
			world.cancel_trade_ui()
		else:
			world.close_trade_ui()
	elif world.fishing_active:
		if world.fishing_manager != null and world.fishing_manager.has_method("cancel_fishing"):
			world.fishing_manager.cancel_fishing()
	elif world.is_sign_open():
		world.close_sign()
	elif world.is_world_lock_ui_open():
		world.close_world_lock_ui()
	elif world.has_method("is_area_lock_ui_open") and world.is_area_lock_ui_open():
		world.close_area_lock_ui()
	elif world.has_method("is_door_editor_open") and world.is_door_editor_open():
		world.close_door_editor()
	elif world.has_method("is_password_door_entry_open") and world.is_password_door_entry_open():
		world.close_password_door_entry()
	elif world.has_method("is_theme_machine_confirm_open") and world.is_theme_machine_confirm_open():
		world.close_theme_machine_confirm()
	elif world.has_method("is_vending_open") and world.is_vending_open():
		world.close_vending_ui()
	elif world.has_method("is_safe_open") and world.is_safe_open():
		world.close_safe_ui()
	elif world.has_method("is_mailbox_open") and world.is_mailbox_open():
		world.close_mailbox_ui()
	elif world.has_method("is_bulletin_board_open") and world.is_bulletin_board_open():
		world.close_bulletin_board_ui()
	elif world.has_method("is_leaderboard_open") and world.is_leaderboard_open():
		world.close_leaderboard_ui()
	elif world.has_method("is_display_open") and world.is_display_open():
		world.close_display_ui()
	elif world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		world.close_fish_monger_ui()
	elif world.has_method("is_cctv_open") and world.is_cctv_open():
		world.close_cctv_ui()
	elif world.has_method("is_oil_refinery_open") and world.is_oil_refinery_open():
		world.close_oil_refinery_ui()
	elif world.has_method("is_battery_charger_open") and world.is_battery_charger_open():
		world.close_battery_charger_ui()
	elif world.has_method("is_generator_open") and world.is_generator_open():
		world.close_generator_ui()
	elif world.has_method("is_developer_panel_open") and world.is_developer_panel_open():
		world.close_developer_panel()
	elif world.has_method("is_player_menu_open") and world.is_player_menu_open():
		world.close_player_menu()
	elif world.has_method("is_settings_panel_open") and world.is_settings_panel_open():
		world.close_settings_panel()
	elif world.has_method("is_friends_panel_open") and world.is_friends_panel_open():
		world.close_friends_panel()
	elif world.is_furnace_open():
		world.close_furnace()
	elif world.is_crafting_open():
		world.close_crafting()
	elif world.has_method("is_notification_panel_open") and world.is_notification_panel_open():
		world.close_notification_panel()
	elif world.is_shop_open():
		world.close_shop()
	elif world.is_inventory_open():
		world.close_inventory_window()
	elif world.has_method("is_game_menu_open") and world.is_game_menu_open():
		world.close_game_menu()
	elif world.is_world_menu_open():
		world.resume_current_world()
	elif world.has_method("open_game_menu"):
		world.open_game_menu()
	else:
		world.toggle_player_menu()
	return true


func handle_input(event):
	if TouchInputGuard.is_emulated_mouse_from_touch(event):
		return
	if world == null:
		return
	if not world.in_world:
		return
	if not world.has_method("is_inventory_open") or not world.is_inventory_open():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _activate_floating_hud_button_at_point(event.position):
			return

	if event is InputEventScreenTouch and event.pressed:
		if _activate_floating_hud_button_at_point(event.position):
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if world.has_method("handle_inventory_wheel") and world.handle_inventory_wheel(event):
				return
			if _is_gameplay_ui_at_point(event.position):
				world.get_viewport().set_input_as_handled()
				return
			if world.can_use_camera_zoom(true):
				world.zoom_camera(world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if world.has_method("handle_inventory_wheel") and world.handle_inventory_wheel(event):
				return
			if _is_gameplay_ui_at_point(event.position):
				world.get_viewport().set_input_as_handled()
				return
			if world.can_use_camera_zoom(true):
				world.zoom_camera(-world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_hold()
		return

	if event is InputEventScreenTouch and not event.pressed:
		stop_inventory_gameplay_hold(event.index)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if world.can_use_camera_zoom():
			if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
				world.zoom_camera(world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
				return

			if event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
				world.zoom_camera(-world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
				return

			if event.keycode == KEY_0:
				world.reset_camera_zoom()
				world.get_viewport().set_input_as_handled()
				return


func handle_unhandled_input(event):
	if TouchInputGuard.is_emulated_mouse_from_touch(event):
		return
	if world == null:
		return

	if not world.in_world:
		return

	if world.is_world_menu_open() and not (event is InputEventKey):
		return

	# ── Mouse ──────────────────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _is_gameplay_ui_at_point(event.position):
				world.get_viewport().set_input_as_handled()
				return
			if world.can_use_camera_zoom(true):
				world.zoom_camera(world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _is_gameplay_ui_at_point(event.position):
				world.get_viewport().set_input_as_handled()
				return
			if world.can_use_camera_zoom(true):
				world.zoom_camera(-world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var on_floating_mouse_hud_button := _is_floating_hud_button_at_point(event.position)
				if not on_floating_mouse_hud_button and _release_text_input_focus_from_pointer_click():
					return
				if not on_floating_mouse_hud_button and _handle_fishing_click_if_active():
					return
				if _is_gameplay_ui_at_point(event.position):
					_stop_hold()
					if on_floating_mouse_hud_button:
						_activate_floating_hud_button_at_point(event.position)
						return
					world.get_viewport().set_input_as_handled()
					return
				if not _any_ui_blocking():
					# Fire immediately on press.
					world.use_selected_item_at_mouse()
					# Start hold tracking.
					is_holding         = true
					hold_timer         = 0.0
					hold_repeat_active = false
			else:
				_stop_hold()
			return

		# Right click intentionally unused.
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return

	# ── Touch ──────────────────────────────────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touch_index = event.index
			if world.has_method("set_mobile_pointer_screen_position"):
				world.set_mobile_pointer_screen_position(event.position)
			var on_floating_touch_hud_button := _is_floating_hud_button_at_point(event.position)
			if not on_floating_touch_hud_button and _release_text_input_focus_from_pointer_click():
				return
			if not on_floating_touch_hud_button and _handle_fishing_click_if_active():
				return
			if _is_gameplay_ui_at_point(event.position):
				_stop_hold()
				if on_floating_touch_hud_button:
					_activate_floating_hud_button_at_point(event.position)
					return
				world.get_viewport().set_input_as_handled()
				return
			if not _any_ui_blocking():
				world.use_selected_item_at_mouse()
				is_holding         = true
				hold_timer         = 0.0
				hold_repeat_active = false
			else:
				_stop_hold()
		else:
			if active_touch_index == event.index:
				_stop_hold()
		return

	if event is InputEventScreenDrag:
		if active_touch_index == event.index and world.has_method("set_mobile_pointer_screen_position"):
			world.set_mobile_pointer_screen_position(event.position)
			if _is_gameplay_ui_at_point(event.position):
				_stop_hold()
				world.get_viewport().set_input_as_handled()
		return

	# ── Keyboard ───────────────────────────────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if world.is_chat_input_focused() and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			world.send_chat_message()
			world.get_viewport().set_input_as_handled()
			return

		if world.is_any_text_input_focused() and event.keycode != KEY_ESCAPE:
			return

		if world.is_sign_text_focused() and event.keycode != KEY_ESCAPE:
			return

		if event.keycode == KEY_ESCAPE:
			handle_back_request()
			world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_T:
			if not _non_chat_ui_blocking():
				world.focus_chat_input()
				world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not _non_chat_ui_blocking():
				world.focus_chat_input()
				world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_J:
			if not _non_chat_ui_blocking() and not world.is_chat_input_focused() and world.fishing_manager != null and world.fishing_manager.has_method("open_fishing_journal"):
				world.fishing_manager.open_fishing_journal()
				world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			if _handle_fishing_click_if_active():
				return

		if _any_ui_blocking():
			return

		if event.is_action_pressed("jump"):
			world.get_viewport().set_input_as_handled()
			return

		if world.try_back_item_air_jump(event):
			world.get_viewport().set_input_as_handled()
			return

		if world.can_use_camera_zoom():
			if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
				world.zoom_camera(world.CAMERA_ZOOM_STEP)
				return

			if event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
				world.zoom_camera(-world.CAMERA_ZOOM_STEP)
				return

			if event.keycode == KEY_0:
				world.reset_camera_zoom()
				return

		if event.keycode == KEY_SPACE:
			if world.selected_item_category == "tool" and world.selected_item_type == "wrench":
				world.interact_with_facing_tile()
			else:
				world.punch_facing_block()
			return

		var hotbar_slot_index := get_hotbar_slot_from_key_event(event)
		if hotbar_slot_index >= 0:
			world.select_hotbar_slot(hotbar_slot_index)
			world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_I:
			world.toggle_inventory_window()

		if event.keycode == KEY_O:
			world.toggle_shop()

		if event.keycode == KEY_F5:
			world.save_world()

		if event.keycode == KEY_F9:
			world.load_world()
