extends Node

# PixelMania Input Manager v2
#
# Hold-to-repeat: holding left mouse button or touch continues placing/breaking.
# - First action fires immediately on press (no delay).
# - After HOLD_INITIAL_DELAY seconds the repeat begins.
# - Repeats every HOLD_REPEAT_RATE seconds until released.
# - Automatically cancels if any UI opens or the player enters chat.

const HOLD_INITIAL_DELAY = 0.22  # seconds before repeat kicks in
const HOLD_REPEAT_RATE   = 0.13  # seconds between repeats

var world = null

var is_holding         := false
var hold_timer         := 0.0
var hold_repeat_active := false  # true once past the initial delay


func setup(world_ref):
	world = world_ref


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

	hold_timer += delta

	if not hold_repeat_active:
		if hold_timer >= HOLD_INITIAL_DELAY:
			hold_repeat_active = true
			hold_timer = 0.0
			world.use_selected_item_at_mouse()
	else:
		if hold_timer >= HOLD_REPEAT_RATE:
			hold_timer = 0.0
			world.use_selected_item_at_mouse()


func _stop_hold():
	is_holding         = false
	hold_timer         = 0.0
	hold_repeat_active = false


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
	if world.has_method("is_trade_open") and world.is_trade_open(): return true
	if world.has_method("is_vending_open") and world.is_vending_open(): return true
	if world.has_method("is_safe_open") and world.is_safe_open(): return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
	return false


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
	if world.has_method("is_trade_open") and world.is_trade_open(): return true
	if world.has_method("is_vending_open") and world.is_vending_open(): return true
	if world.has_method("is_safe_open") and world.is_safe_open(): return true
	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open(): return true
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


func handle_unhandled_input(event):
	if world == null:
		return

	if not world.in_world:
		return

	if world.is_world_menu_open() and not (event is InputEventKey):
		return

	# ── Mouse ──────────────────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if world.can_use_camera_zoom(true):
				world.zoom_camera(world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if world.can_use_camera_zoom(true):
				world.zoom_camera(-world.CAMERA_ZOOM_STEP)
				world.get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _handle_fishing_click_if_active():
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
			if _handle_fishing_click_if_active():
				return
			if not _any_ui_blocking():
				world.use_selected_item_at_mouse()
				is_holding         = true
				hold_timer         = 0.0
				hold_repeat_active = false
		else:
			_stop_hold()
		return

	# ── Keyboard ───────────────────────────────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if world.is_chat_input_focused() and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			world.send_chat_message()
			world.get_viewport().set_input_as_handled()
			return

		if world.is_chat_input_focused() and event.keycode == KEY_ESCAPE:
			if world.has_method("release_chat_focus"):
				world.release_chat_focus()
			world.get_viewport().set_input_as_handled()
			return

		if world.is_any_text_input_focused() and event.keycode != KEY_ESCAPE:
			return

		if world.is_sign_text_focused() and event.keycode != KEY_ESCAPE:
			return

		if event.keycode == KEY_ESCAPE:
			_stop_hold()
			if world.has_method("is_trade_open") and world.is_trade_open():
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
			elif world.has_method("is_vending_open") and world.is_vending_open():
				world.close_vending_ui()
			elif world.has_method("is_safe_open") and world.is_safe_open():
				world.close_safe_ui()
			elif world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
				world.close_fish_monger_ui()
			elif world.has_method("is_developer_panel_open") and world.is_developer_panel_open():
				world.close_developer_panel()
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
			else:
				if world.has_method("toggle_game_menu"):
					world.toggle_game_menu()
				else:
					world.toggle_player_menu()
			world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_T:
			if not _non_chat_ui_blocking() and not world.fishing_active:
				world.focus_chat_input()
				world.get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not _non_chat_ui_blocking() and not world.fishing_active:
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

		if event.keycode == KEY_1:
			world.select_hotbar_slot(0)

		if event.keycode == KEY_2:
			world.select_hotbar_slot(1)

		if event.keycode == KEY_3:
			world.select_hotbar_slot(2)

		if event.keycode == KEY_4:
			world.select_hotbar_slot(3)

		if event.keycode == KEY_5:
			world.select_hotbar_slot(4)

		if event.keycode == KEY_6:
			world.select_hotbar_slot(5)

		if event.keycode == KEY_I:
			world.toggle_inventory_window()

		if event.keycode == KEY_O:
			world.toggle_shop()

		if event.keycode == KEY_F5:
			world.save_world()

		if event.keycode == KEY_F9:
			world.load_world()
