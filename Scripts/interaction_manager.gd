extends Node

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const ELECTRIC_TOOL_ITEM := "electric_tool"
const DOOR_MOVER_ITEM_TYPE := "door_mover"

var world = null
var door_mover_source_grid := Vector2i(999999, 999999)
var wooden_entrance_confirm_overlay = null
var wooden_entrance_confirm_panel = null
var wooden_entrance_confirm_grid := Vector2i(999999, 999999)
var wooden_entrance_confirm_locked := false
var theme_machine_confirm_overlay = null
var theme_machine_confirm_panel = null
var theme_machine_confirm_grid := Vector2i(999999, 999999)
var theme_machine_confirm_enabled := false
var theme_machine_confirm_theme := "night"
var door_editor_overlay = null
var door_editor_panel = null
var door_name_input: LineEdit = null
var door_id_input: LineEdit = null
var door_destination_input: LineEdit = null
var door_locked_checkbox: CheckBox = null
var door_password_input: LineEdit = null
var door_password_clear_checkbox: CheckBox = null
var door_editor_grid := Vector2i(999999, 999999)
var password_door_overlay = null
var password_door_panel = null
var password_door_input: LineEdit = null
var password_door_grid := Vector2i(999999, 999999)
var door_enter_cooldown_until_msec := 0
var last_auto_door_grid := Vector2i(999999, 999999)

const MAX_DOOR_ID_LENGTH := 32
const MAX_DOOR_NAME_LENGTH := 64
const MAX_DOOR_DESTINATION_LENGTH := 80
const MAX_DOOR_PASSWORD_LENGTH := 32
const DOOR_ENTER_COOLDOWN_MSEC := 1400


func setup(world_ref):
	world = world_ref


func use_selected_item_at_mouse():
	if world.is_chat_input_focused():
		return

	if world.is_player_menu_open():
		return

	if world.has_method("is_game_menu_open") and world.is_game_menu_open():
		return

	if world.is_world_menu_open():
		return

	if world.is_crafting_open():
		return

	if world.is_furnace_open():
		return

	if world.is_sign_open():
		return

	if world.is_shop_open():
		return

	if world.is_world_lock_ui_open():
		return

	if world.has_method("is_wooden_entrance_confirm_open") and world.is_wooden_entrance_confirm_open():
		return

	if world.has_method("is_theme_machine_confirm_open") and world.is_theme_machine_confirm_open():
		return

	if is_door_editor_open():
		return

	if is_password_door_entry_open():
		return

	if world.has_method("is_vending_open") and world.is_vending_open():
		return

	if world.has_method("is_safe_open") and world.is_safe_open():
		return

	if world.has_method("is_donation_box_open") and world.is_donation_box_open():
		return

	if world.has_method("is_mailbox_open") and world.is_mailbox_open():
		return

	if world.has_method("is_bulletin_board_open") and world.is_bulletin_board_open():
		return

	if world.has_method("is_display_open") and world.is_display_open():
		return

	if world.has_method("is_fish_monger_open") and world.is_fish_monger_open():
		return

	if world.has_method("is_cctv_open") and world.is_cctv_open():
		return

	if world.has_method("is_oil_refinery_open") and world.is_oil_refinery_open():
		return
	if world.has_method("is_battery_charger_open") and world.is_battery_charger_open():
		return

	if world.selected_item_category == "tool" and world.has_method("is_fishing_rod_item") and bool(world.is_fishing_rod_item(world.selected_item_type)):
		world.use_fishing_rod_at_mouse()
		return

	if world.selected_item_category == "lure":
		world.use_selected_lure_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "entrance_mover":
		world.use_entrance_mover_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "lock_mover":
		world.use_lock_mover_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == DOOR_MOVER_ITEM_TYPE:
		use_door_mover_at_mouse()
		return

	var clicked_grid = world.get_mouse_grid_position()
	if world.has_method("try_display_selected_item_at") and bool(world.try_display_selected_item_at(clicked_grid)):
		return

	if str(world.selected_item_category).strip_edges().to_lower() == "fish":
		if world.has_method("try_display_selected_fish_at") and bool(world.try_display_selected_fish_at(clicked_grid)):
			return
		world.show_notification("Tap a Fish Hanger to display that fish.")
		return

	if str(world.selected_item_category).strip_edges().to_lower() == "material" and str(world.selected_item_type).strip_edges().to_lower() == "grain":
		if world.has_method("try_feed_chicken_at") and bool(world.try_feed_chicken_at(clicked_grid)):
			return
		if world.has_method("try_feed_duck_at") and bool(world.try_feed_duck_at(clicked_grid)):
			return
		world.show_notification("Use Grain on a hungry Chicken or Duck.")
		return

	if str(world.selected_item_category).strip_edges().to_lower() == "material" and str(world.selected_item_type).strip_edges().to_lower() == "wheat":
		if world.has_method("try_feed_cow_at") and bool(world.try_feed_cow_at(clicked_grid)):
			return
		world.show_notification("Use Wheat on a hungry Cow.")
		return

	if world.has_method("try_link_oil_refinery_pole_at") and bool(world.try_link_oil_refinery_pole_at(clicked_grid)):
		return

	if world.has_method("try_link_battery_charger_pole_at") and bool(world.try_link_battery_charger_pole_at(clicked_grid)):
		return

	if world.has_method("try_link_generator_pad_at") and bool(world.try_link_generator_pad_at(clicked_grid)):
		return

	if world.selected_item_category == "tool" and world.selected_item_type == ELECTRIC_TOOL_ITEM:
		if world.has_method("try_electric_tool_link_at") and bool(world.try_electric_tool_link_at(clicked_grid)):
			return

	var clicked_entrance_gate = world.get_entrance_gate_near_grid(clicked_grid)

	if clicked_entrance_gate != world.INVALID_GRID_POS:
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "punch":
		if world.has_method("prepare_mouse_punch_facing"):
			world.prepare_mouse_punch_facing()
		if world.has_method("play_player_punch_animation"):
			world.play_player_punch_animation()
		world.break_block_at_mouse()
		return

	if world.selected_item_category == "tool" and world.selected_item_type == "wrench":
		interact_with_mouse()
		return

	if world.selected_item_category == "block":
		world.place_block_at_mouse()
		return

	if world.selected_item_category == "seed":
		world.plant_seed_at_mouse()
		return


func place_selected_item_at_mouse():
	use_selected_item_at_mouse()


func interact_with_mouse():
	if world.has_method("get_remote_player_at_screen_position"):
		var pointer_screen_pos = world.get_pointer_screen_position() if world.has_method("get_pointer_screen_position") else world.get_viewport().get_mouse_position()
		var remote_player = world.get_remote_player_at_screen_position(pointer_screen_pos)
		if remote_player is Dictionary and not remote_player.is_empty():
			var remote_position = Vector2(float(remote_player.get("x", 0.0)), float(remote_player.get("y", 0.0)))
			if world.player != null and world.player.global_position.distance_to(remote_position) > world.INTERACTION_PIXEL_RANGE:
				world.show_notification("Too far away.")
				return

			if world.has_method("open_remote_player_profile"):
				world.open_remote_player_profile(remote_player)
				return

	var grid_pos = world.get_mouse_grid_position()
	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	interact_with_grid(grid_pos)


func interact_with_facing_tile():
	if world.has_method("get_remote_player_in_interaction_range"):
		var remote_player = world.get_remote_player_in_interaction_range()
		if remote_player is Dictionary and not remote_player.is_empty():
			if world.has_method("open_remote_player_profile"):
				world.open_remote_player_profile(remote_player)
				return

	var player_grid = world.get_player_grid_position()
	var grid_pos = Vector2i(player_grid.x + world.player_facing_direction, player_grid.y)

	if world.blocks.has(grid_pos):
		interact_with_grid(grid_pos)
		return

	# Try one tile lower too, because stations usually sit at foot level.
	var lower_pos = Vector2i(grid_pos.x, grid_pos.y + 1)

	if world.blocks.has(lower_pos):
		interact_with_grid(lower_pos)
		return

	if world.has_method("is_visible_generator_at") and bool(world.is_visible_generator_at(grid_pos)):
		world.open_generator_ui(grid_pos)
		return

	if world.has_method("is_visible_generator_at") and bool(world.is_visible_generator_at(lower_pos)):
		world.open_generator_ui(lower_pos)
		return

	world.show_notification("Nothing to interact with.")


func interact_with_grid(grid_pos: Vector2i):
	grid_pos = get_anchor_grid_for_block_area(grid_pos)
	if not world.blocks.has(grid_pos):
		if world.has_method("is_visible_generator_at") and bool(world.is_visible_generator_at(grid_pos)):
			world.open_generator_ui(grid_pos)
			return
		world.show_notification("Nothing to interact with.")
		return

	var block_type = str(world.blocks[grid_pos]["type"])

	if is_door_block(block_type):
		if is_password_door_block(block_type) and not can_current_player_edit_password_door():
			open_password_door_entry(grid_pos)
		else:
			open_door_editor(grid_pos)
		return

	if world.has_method("can_current_player_interact_with_block_at") and not world.can_current_player_interact_with_block_at(block_type, grid_pos):
		if is_safe_block(block_type):
			if world.world_lock_manager != null and world.world_lock_manager.is_locked:
				world.show_notification("Only the world owner can open this safe.")
			else:
				world.show_notification("Lock this world before using safes.")
		elif is_display_block(block_type):
			world.show_notification("Only the world owner can use this display.")
		elif is_vending_machine_block(block_type):
			world.show_notification("Lock this world before using vending machines.")
		elif is_wooden_entrance_block(block_type):
			world.show_notification("Only the world owner or world admins can lock this entrance.")
		elif is_toggle_block(block_type):
			world.show_notification("Only players with build access can toggle this.")
		elif is_anti_punch_block(block_type):
			world.show_notification("Only the world owner or world admins can toggle anti-punch.")
		elif is_anti_talk_block(block_type):
			world.show_notification("Only the world owner or world admins can toggle anti-talk.")
		elif is_anti_gravity_block(block_type):
			world.show_notification("Only the world owner or world admins can toggle anti-gravity.")
		elif is_theme_machine_block(block_type):
			world.show_notification("Only world or area-lock builders can use this Theme Machine.")
		elif is_cctv_block(block_type):
			world.show_notification("Only the world owner or world admins can view CCTV.")
		elif is_oil_refinery_block(block_type):
			world.show_notification("Only the world owner or world admins can use the oil refinery.")
		elif is_battery_charger_block(block_type):
			world.show_notification("Only the world owner or world admins can use the battery charger.")
		else:
			world.show_notification("This world is locked.")
		return

	if world.has_method("is_world_lock_block_type") and world.is_world_lock_block_type(block_type):
		if world.has_method("open_world_lock_ui"):
			world.open_world_lock_ui(grid_pos)
		return

	if world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(block_type):
		if world.has_method("open_area_lock_ui"):
			world.open_area_lock_ui(grid_pos)
		return

	if world.is_entrance_gate_block(block_type):
		if world.can_use_entrance_gate():
			world.exit_world_from_entrance_gate()
		return

	if is_transformer_block(block_type):
		world.open_generator_ui(grid_pos)
		return

	if is_crafting_station_block(block_type):
		world.open_crafting_station(grid_pos)
		return

	if is_furnace_block(block_type):
		world.open_furnace_station(grid_pos)
		return

	if is_wooden_entrance_block(block_type):
		open_wooden_entrance_confirm(grid_pos)
		return

	if world.is_sign_block(block_type):
		world.open_sign_editor(grid_pos)
		return

	if is_toggle_block(block_type):
		toggle_block_state(grid_pos)
		return

	if is_punch_toggle_machine_block(block_type):
		world.show_notification("Punch " + get_block_display_name(block_type) + " to turn it on or off.")
		return

	if is_vending_machine_block(block_type):
		open_vending_ui(grid_pos)
		return

	if is_safe_block(block_type):
		open_safe_ui(grid_pos)
		return

	if is_donation_box_block(block_type):
		open_donation_box_ui(grid_pos)
		return

	if is_mailbox_block(block_type):
		open_mailbox_ui(grid_pos)
		return

	if is_bulletin_board_block(block_type):
		open_bulletin_board_ui(grid_pos)
		return

	if is_fish_hanger_block(block_type):
		world.show_notification("Select a fish and tap the Fish Hanger. Punch it to take the fish back.")
		return

	if is_display_block(block_type):
		world.show_notification("Select an inventory item and tap the display. Punch it to take the item back.")
		return

	if is_fish_monger_block(block_type):
		open_fish_monger_ui(grid_pos)
		return

	if is_cctv_block(block_type):
		open_cctv_ui(grid_pos)
		return

	if is_oil_refinery_block(block_type):
		open_oil_refinery_ui(grid_pos)
		return

	if is_battery_charger_block(block_type):
		open_battery_charger_ui(grid_pos)
		return

	world.show_notification("Nothing to interact with.")


func get_anchor_grid_for_block_area(grid_pos: Vector2i) -> Vector2i:
	if world != null and world.has_method("get_anchor_grid_for_block_area"):
		return world.get_anchor_grid_for_block_area(grid_pos)

	if world != null and world.blocks.has(grid_pos):
		return grid_pos

	if world != null:
		return world.INVALID_GRID_POS

	return Vector2i(999999, 999999)


func get_clicked_door_grid(raw_grid_pos: Vector2i) -> Vector2i:
	var anchor_grid := get_anchor_grid_for_block_area(raw_grid_pos)
	if world != null and anchor_grid != world.INVALID_GRID_POS and world.blocks.has(anchor_grid):
		var anchor_type := str(world.blocks[anchor_grid].get("type", ""))
		if is_door_block(anchor_type):
			return anchor_grid

	if world != null and world.blocks.has(raw_grid_pos):
		var raw_type := str(world.blocks[raw_grid_pos].get("type", ""))
		if is_door_block(raw_type):
			return raw_grid_pos

	return world.INVALID_GRID_POS if world != null else Vector2i(999999, 999999)


func reject_door_mover_target(message: String, show_message: bool = true) -> bool:
	if show_message and world != null and world.has_method("show_notification"):
		world.show_notification(message)
	return false


func is_door_mover_source_valid() -> bool:
	if world == null:
		return false
	if door_mover_source_grid == world.INVALID_GRID_POS:
		return false
	if not world.blocks.has(door_mover_source_grid):
		return false

	return is_door_block(str(world.blocks[door_mover_source_grid].get("type", "")))


func select_door_mover_source(door_grid: Vector2i) -> bool:
	if world == null or door_grid == world.INVALID_GRID_POS or not world.blocks.has(door_grid):
		return false

	if not is_door_block(str(world.blocks[door_grid].get("type", ""))):
		return false

	if not can_current_player_configure_door():
		world.show_notification("Only the owner or trusted builders can move this door.")
		return false

	door_mover_source_grid = door_grid
	world.show_notification("Door selected. Click an empty spot to move it.")
	return true


func can_move_door_to(old_grid_pos: Vector2i, new_grid_pos: Vector2i, show_message: bool = true) -> bool:
	if world == null:
		return false

	if old_grid_pos == world.INVALID_GRID_POS or not world.blocks.has(old_grid_pos):
		door_mover_source_grid = world.INVALID_GRID_POS
		return reject_door_mover_target("Door missing. Select a door again.", show_message)

	var door_type := str(world.blocks[old_grid_pos].get("type", ""))
	if not is_door_block(door_type):
		door_mover_source_grid = world.INVALID_GRID_POS
		return reject_door_mover_target("Select a door first.", show_message)

	if not can_current_player_configure_door():
		return reject_door_mover_target("Only the owner or trusted builders can move this door.", show_message)

	if old_grid_pos == new_grid_pos:
		return reject_door_mover_target("Door is already there.", show_message)

	if not world.is_grid_inside_world(new_grid_pos):
		return reject_door_mover_target("Outside world bounds.", show_message)

	if world.blocks.has(new_grid_pos):
		return reject_door_mover_target("That spot is already occupied.", show_message)

	if world.has_planted_seed(new_grid_pos):
		return reject_door_mover_target("A seed is already planted there.", show_message)

	if world.is_block_inside_player(new_grid_pos):
		return reject_door_mover_target("Move away from that spot first.", show_message)

	if world.block_manager != null and world.block_manager.has_method("get_block_collision_rect_for_grid") and world.block_manager.has_method("does_rect_overlap_reserved_object"):
		var collision_rect: Rect2 = world.block_manager.get_block_collision_rect_for_grid(new_grid_pos, door_type)
		if bool(world.block_manager.does_rect_overlap_reserved_object(collision_rect, old_grid_pos)):
			return reject_door_mover_target("Need enough empty space.", show_message)

	return true


func should_request_server_door_move() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func request_server_door_move(old_grid_pos: Vector2i, new_grid_pos: Vector2i) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		world.show_notification("Connection required.")
		return false

	var sent := false
	if network.has_method("send_door_move"):
		sent = bool(network.send_door_move(old_grid_pos, new_grid_pos, world.current_world_name))
	elif network.has_method("send_world_interaction_update"):
		sent = bool(network.send_world_interaction_update({
			"action": "door_move",
			"old_x": old_grid_pos.x,
			"old_y": old_grid_pos.y,
			"x": new_grid_pos.x,
			"y": new_grid_pos.y
		}, world.current_world_name))

	if not sent:
		world.show_notification("Almost ready. Try again in a moment.")
		return false

	door_mover_source_grid = world.INVALID_GRID_POS
	world.show_notification("Moving Door...")
	return true


func move_door_to(old_grid_pos: Vector2i, new_grid_pos: Vector2i) -> bool:
	if not can_move_door_to(old_grid_pos, new_grid_pos):
		return false

	var door_data: Dictionary = world.blocks[old_grid_pos]
	var door_type := str(door_data.get("type", ""))
	var door_state := get_door_state(old_grid_pos).duplicate(true)
	world.remove_block_without_drop(old_grid_pos)
	world.create_block(new_grid_pos, door_type)

	apply_door_state_to_block(
		new_grid_pos,
		str(door_state.get("door_id", "")),
		str(door_state.get("destination", "")),
		bool(door_state.get("locked", false)),
		str(door_state.get("target_world", "")),
		str(door_state.get("target_door_id", "")),
		str(door_state.get("password", "")),
		bool(door_state.get("password_configured", false)),
		str(door_state.get("password", "")) != "",
		str(door_state.get("door_name", ""))
	)

	door_mover_source_grid = world.INVALID_GRID_POS
	if world.has_method("play_sound_place"):
		world.play_sound_place(Vector2(new_grid_pos.x * world.BLOCK_SIZE, new_grid_pos.y * world.BLOCK_SIZE))
	if world.has_method("show_notification"):
		world.show_notification("Door moved.")
	if world.has_method("save_world"):
		world.save_world()
	return true


func use_door_mover_at_mouse():
	if world == null:
		return

	if not world.tool_inventory.has(DOOR_MOVER_ITEM_TYPE) or int(world.tool_inventory[DOOR_MOVER_ITEM_TYPE]) <= 0:
		world.show_notification("You do not have a Door Mover.")
		door_mover_source_grid = world.INVALID_GRID_POS
		return

	var clicked_grid: Vector2i = world.get_mouse_grid_position()
	if not world.is_grid_inside_world(clicked_grid):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(clicked_grid):
		world.show_notification("Too far away.")
		return

	var clicked_door_grid := get_clicked_door_grid(clicked_grid)
	if not is_door_mover_source_valid():
		if not select_door_mover_source(clicked_door_grid):
			world.show_notification("Click a door first.")
		return

	if clicked_door_grid != world.INVALID_GRID_POS and clicked_door_grid != door_mover_source_grid:
		select_door_mover_source(clicked_door_grid)
		return

	var source_grid := door_mover_source_grid
	if should_request_server_door_move():
		if can_move_door_to(source_grid, clicked_grid):
			request_server_door_move(source_grid, clicked_grid)
		return

	if move_door_to(source_grid, clicked_grid):
		world.tool_inventory[DOOR_MOVER_ITEM_TYPE] = max(0, int(world.tool_inventory[DOOR_MOVER_ITEM_TYPE]) - 1)
		if int(world.tool_inventory[DOOR_MOVER_ITEM_TYPE]) <= 0 and world.selected_item_type == DOOR_MOVER_ITEM_TYPE:
			world.selected_item_type = world.primary_hotbar_tool
			world.selected_item_category = "tool"
		world.update_all_ui()


func is_interactable_block(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges()
	if clean_type == "":
		return false

	if is_door_block(clean_type):
		return true
	if world != null and world.has_method("is_world_lock_block_type") and world.is_world_lock_block_type(clean_type):
		return true
	if world != null and world.has_method("is_area_lock_block_type") and world.is_area_lock_block_type(clean_type):
		return true
	if world != null and world.has_method("is_entrance_gate_block") and world.is_entrance_gate_block(clean_type):
		return true
	if is_transformer_block(clean_type):
		return true
	if is_crafting_station_block(clean_type):
		return true
	if is_furnace_block(clean_type):
		return true
	if is_wooden_entrance_block(clean_type):
		return true
	if world != null and world.has_method("is_sign_block") and world.is_sign_block(clean_type):
		return true
	if is_toggle_block(clean_type):
		return true
	if is_anti_punch_block(clean_type):
		return true
	if is_anti_talk_block(clean_type):
		return true
	if is_anti_gravity_block(clean_type):
		return true
	if is_theme_machine_block(clean_type):
		return true
	if is_vending_machine_block(clean_type):
		return true
	if is_safe_block(clean_type):
		return true
	if is_donation_box_block(clean_type):
		return true
	if is_mailbox_block(clean_type):
		return true
	if is_bulletin_board_block(clean_type):
		return true
	if is_display_block(clean_type):
		return true
	if is_fish_monger_block(clean_type):
		return true
	if is_cctv_block(clean_type):
		return true
	if is_oil_refinery_block(clean_type):
		return true
	if is_battery_charger_block(clean_type):
		return true

	return false


func is_wooden_entrance_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		var item_data = world.item_database[block_type]
		return bool(item_data.get("entrance_block", false)) or item_data.has("entrance_frames")

	return block_type == "wooden_entrance"


func is_transformer_block(block_type: String) -> bool:
	var clean := str(block_type).strip_edges().to_lower()
	if clean == "generator" or clean == "transformer":
		return true
	if world != null and world.item_database.has(clean):
		return str(world.item_database[clean].get("electrical_device_type", "")).strip_edges().to_lower() == "generator"
	return false


func is_door_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		var item_data = world.item_database[block_type]
		return bool(item_data.get("door_block", false))

	var clean = block_type.strip_edges().to_lower()
	return clean == "door" or clean.ends_with("_door")


func is_auto_enter_door_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		var item_data = world.item_database[block_type]
		return bool(item_data.get("auto_door_enter", false)) or bool(item_data.get("portal_block", false))

	return false


func is_password_door_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		var item_data = world.item_database[block_type]
		return bool(item_data.get("password_door", false))

	return str(block_type).strip_edges().to_lower() == "password_door"


func is_cctv_block(block_type: String) -> bool:
	if world != null and world.has_method("is_cctv_block_type"):
		return bool(world.is_cctv_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("cctv_block", false))
	return str(block_type).strip_edges().to_lower() == "cctv"

func is_oil_refinery_block(block_type: String) -> bool:
	if world != null and world.has_method("is_oil_refinery_block_type"):
		return bool(world.is_oil_refinery_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("oil_refinery_block", false))
	return str(block_type).strip_edges().to_lower() == "oil_refinery"


func is_battery_charger_block(block_type: String) -> bool:
	if world != null and world.has_method("is_battery_charger_block_type"):
		return bool(world.is_battery_charger_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("battery_charger_block", false))
	return str(block_type).strip_edges().to_lower() == "battery_charger"


func get_background_block_type(grid_pos: Vector2i) -> String:
	if world == null or world.block_manager == null:
		return ""
	var background_value = world.block_manager.get("background_blocks")
	if not (background_value is Dictionary):
		return ""
	var background_blocks: Dictionary = background_value
	if not background_blocks.has(grid_pos):
		return ""
	var block_data = background_blocks.get(grid_pos, {})
	if not (block_data is Dictionary):
		return ""
	return str(block_data.get("type", ""))


func sanitize_door_id(raw_value) -> String:
	var text = str(raw_value).strip_edges().to_upper()
	var allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result = ""
	for i in range(text.length()):
		var character = text.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
		if result.length() >= MAX_DOOR_ID_LENGTH:
			break
	return result


func sanitize_door_name(raw_value) -> String:
	var text = str(raw_value).replace("\r", " ").replace("\n", " ").strip_edges()
	if text.length() > MAX_DOOR_NAME_LENGTH:
		text = text.substr(0, MAX_DOOR_NAME_LENGTH)
	return text


func sanitize_door_world_name(raw_value) -> String:
	var text = str(raw_value).strip_edges()
	if text == "":
		return ""
	if world != null and world.has_method("sanitize_world_name"):
		return str(world.sanitize_world_name(text)).strip_edges().to_upper()
	var allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result = ""
	text = text.to_upper()
	for i in range(text.length()):
		var character = text.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	return result


func normalize_door_destination_text(raw_value) -> String:
	var text = str(raw_value).strip_edges()
	if text.length() > MAX_DOOR_DESTINATION_LENGTH:
		text = text.substr(0, MAX_DOOR_DESTINATION_LENGTH)
	return text


func sanitize_door_password(raw_value) -> String:
	var text = str(raw_value).strip_edges()
	if text.length() > MAX_DOOR_PASSWORD_LENGTH:
		text = text.substr(0, MAX_DOOR_PASSWORD_LENGTH)
	return text


func parse_door_destination(raw_value) -> Dictionary:
	var text = normalize_door_destination_text(raw_value)
	var current_world = sanitize_door_world_name(world.current_world_name if world != null else "")
	if text == "":
		return {
			"world": "",
			"door_id": "",
			"destination": ""
		}

	var target_world = current_world
	var target_id = ""
	var parts = text.split(":", false)

	if parts.size() >= 3 and str(parts[1]).strip_edges().to_lower() == "door":
		target_world = sanitize_door_world_name(parts[0])
		target_id = sanitize_door_id(parts[2])
	elif parts.size() >= 2:
		if str(parts[0]).strip_edges().to_lower() == "door":
			target_id = sanitize_door_id(parts[1])
		else:
			target_world = sanitize_door_world_name(parts[0])
			target_id = sanitize_door_id(parts[1])
	else:
		target_world = sanitize_door_world_name(text)

	if target_world == "":
		target_world = current_world

	return {
		"world": target_world,
		"door_id": target_id,
		"destination": text
	}


func can_current_player_configure_door() -> bool:
	if world != null and world.has_method("can_current_player_configure_door"):
		return bool(world.can_current_player_configure_door())

	if world != null and world.has_method("can_current_player_build"):
		return bool(world.can_current_player_build())

	return true


func can_current_player_edit_password_door() -> bool:
	if world == null:
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("is_developer_session") and bool(network.is_developer_session()):
		return true

	if world.world_lock_manager != null:
		if world.world_lock_manager.has_method("is_current_player_owner"):
			var is_owner := bool(world.world_lock_manager.is_current_player_owner())
			if not is_owner:
				return false
			if world.world_lock_manager.has_method("is_current_player_owner_session_verified"):
				return bool(world.world_lock_manager.is_current_player_owner_session_verified())
			return true

	return false


func can_current_player_toggle_door_lock() -> bool:
	if world != null and world.has_method("can_current_player_toggle_door_lock"):
		return bool(world.can_current_player_toggle_door_lock())

	return can_current_player_toggle_wooden_entrance()


func get_door_state(grid_pos: Vector2i) -> Dictionary:
	if world == null or not world.blocks.has(grid_pos):
		return {}

	var block_data = world.blocks[grid_pos]
	var destination = normalize_door_destination_text(block_data.get("door_destination", block_data.get("destination", "")))
	var parsed = parse_door_destination(destination)
	return {
		"door_id": sanitize_door_id(block_data.get("door_id", "")),
		"door_name": sanitize_door_name(block_data.get("door_name", block_data.get("name", ""))),
		"destination": destination,
		"target_world": sanitize_door_world_name(block_data.get("door_target_world", parsed.get("world", ""))),
		"target_door_id": sanitize_door_id(block_data.get("door_target_id", parsed.get("door_id", ""))),
		"locked": bool(block_data.get("entrance_locked", false)),
		"password": sanitize_door_password(block_data.get("door_password", "")),
		"password_configured": bool(block_data.get("door_password_configured", sanitize_door_password(block_data.get("door_password", "")) != ""))
	}


func apply_door_state_to_block(
	grid_pos: Vector2i,
	door_id: String,
	destination: String,
	locked: bool,
	target_world: String = "",
	target_door_id: String = "",
	password: String = "",
	password_configured: bool = false,
	password_changed: bool = false,
	door_name: String = ""
):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_door_block(block_type):
		return

	var parsed = parse_door_destination(destination)
	var clean_door_id = sanitize_door_id(door_id)
	var clean_door_name = sanitize_door_name(door_name)
	var clean_destination = normalize_door_destination_text(destination)
	var clean_target_world = sanitize_door_world_name(target_world)
	var clean_target_id = sanitize_door_id(target_door_id)
	if clean_target_world == "":
		clean_target_world = str(parsed.get("world", ""))
	if clean_target_id == "":
		clean_target_id = str(parsed.get("door_id", ""))

	world.blocks[grid_pos]["door_id"] = clean_door_id
	if clean_door_name == "":
		world.blocks[grid_pos].erase("door_name")
		world.blocks[grid_pos].erase("name")
	else:
		world.blocks[grid_pos]["door_name"] = clean_door_name
	world.blocks[grid_pos]["door_destination"] = clean_destination
	world.blocks[grid_pos]["door_target_world"] = clean_target_world
	world.blocks[grid_pos]["door_target_id"] = clean_target_id
	world.blocks[grid_pos]["entrance_locked"] = locked
	if is_password_door_block(block_type):
		if password_changed:
			var clean_password = sanitize_door_password(password)
			if clean_password == "":
				world.blocks[grid_pos].erase("door_password")
				world.blocks[grid_pos]["door_password_configured"] = false
			else:
				world.blocks[grid_pos]["door_password"] = clean_password
				world.blocks[grid_pos]["door_password_configured"] = true
		elif password_configured:
			world.blocks[grid_pos]["door_password_configured"] = true
	else:
		world.blocks[grid_pos].erase("door_password")
		world.blocks[grid_pos].erase("door_password_configured")

	if is_wooden_entrance_block(block_type):
		if world.block_manager != null and world.block_manager.has_method("refresh_wooden_entrance_collision"):
			world.block_manager.refresh_wooden_entrance_collision(grid_pos)
		update_wooden_entrance_visual(grid_pos)


func is_door_editor_open() -> bool:
	return door_editor_panel != null and is_instance_valid(door_editor_panel)


func close_door_editor():
	if door_editor_overlay != null and is_instance_valid(door_editor_overlay):
		door_editor_overlay.queue_free()
	door_editor_overlay = null

	if door_editor_panel != null and is_instance_valid(door_editor_panel):
		door_editor_panel.queue_free()
	door_editor_panel = null
	door_name_input = null
	door_id_input = null
	door_destination_input = null
	door_locked_checkbox = null
	door_password_input = null
	door_password_clear_checkbox = null
	door_editor_grid = Vector2i(999999, 999999)


func add_door_editor_label(text: String, pos: Vector2, size: Vector2, font_size: int = 15) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(label, font_size)
	door_editor_panel.add_child(label)
	return label


func open_door_editor(grid_pos: Vector2i):
	close_door_editor()

	if world == null or world.ui_layer == null:
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("That door is gone.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_door_block(block_type):
		world.show_notification("Nothing to interact with.")
		return

	var password_door := is_password_door_block(block_type)
	if password_door and not can_current_player_edit_password_door():
		world.show_notification("Only the world owner can edit this password door.")
		return

	if not can_current_player_configure_door():
		world.show_notification("Only the owner or trusted builders can edit this door.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_method("close_inventory_window"):
		world.close_inventory_window()
	if world.has_method("close_sign"):
		world.close_sign()
	if world.has_method("close_crafting"):
		world.close_crafting()
	if world.has_method("close_furnace"):
		world.close_furnace()

	door_editor_grid = grid_pos
	var state = get_door_state(grid_pos)
	var viewport_size = world.get_viewport_rect().size
	var button_y := 310
	var panel_height := 382
	if password_door:
		button_y = 388
		panel_height = 460

	door_editor_overlay = ColorRect.new()
	door_editor_overlay.name = "DoorEditorOverlay"
	door_editor_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	door_editor_overlay.color = Color(0.0, 0.0, 0.0, 0.38)
	door_editor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	door_editor_overlay.z_index = 218
	world.ui_layer.add_child(door_editor_overlay)

	door_editor_panel = Panel.new()
	door_editor_panel.name = "DoorEditorPanel"
	door_editor_panel.size = Vector2(560, panel_height)
	door_editor_panel.position = (viewport_size - door_editor_panel.size) * 0.5
	door_editor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	door_editor_panel.z_index = 219
	door_editor_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	world.ui_layer.add_child(door_editor_panel)

	var title = Label.new()
	title.text = get_block_display_name(block_type).to_upper()
	title.position = Vector2(24, 18)
	title.size = Vector2(458, 36)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 25)
	door_editor_panel.add_child(title)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(500, 20)
	close_button.size = Vector2(38, 34)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_door_editor)
	door_editor_panel.add_child(close_button)

	add_door_editor_label("NAME", Vector2(32, 78), Vector2(158, 26), 15)
	door_name_input = LineEdit.new()
	door_name_input.position = Vector2(176, 72)
	door_name_input.size = Vector2(340, 42)
	door_name_input.placeholder_text = "Farm Door"
	door_name_input.text = str(state.get("door_name", ""))
	door_name_input.max_length = MAX_DOOR_NAME_LENGTH
	door_name_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(door_name_input, 18)
	door_editor_panel.add_child(door_name_input)

	add_door_editor_label("DOOR ID", Vector2(32, 136), Vector2(158, 26), 15)
	door_id_input = LineEdit.new()
	door_id_input.position = Vector2(176, 130)
	door_id_input.size = Vector2(340, 42)
	door_id_input.placeholder_text = "A1"
	door_id_input.text = str(state.get("door_id", ""))
	door_id_input.max_length = MAX_DOOR_ID_LENGTH
	door_id_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(door_id_input, 18)
	door_editor_panel.add_child(door_id_input)

	add_door_editor_label("DESTINATION", Vector2(32, 194), Vector2(158, 26), 15)
	door_destination_input = LineEdit.new()
	door_destination_input.position = Vector2(176, 188)
	door_destination_input.size = Vector2(340, 42)
	door_destination_input.placeholder_text = "START, door:A1, or START:door:A1"
	door_destination_input.text = str(state.get("destination", ""))
	door_destination_input.max_length = MAX_DOOR_DESTINATION_LENGTH
	door_destination_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(door_destination_input, 18)
	door_editor_panel.add_child(door_destination_input)

	door_locked_checkbox = CheckBox.new()
	door_locked_checkbox.text = "LOCKED"
	door_locked_checkbox.position = Vector2(174, 246)
	door_locked_checkbox.size = Vector2(160, 34)
	door_locked_checkbox.button_pressed = bool(state.get("locked", false))
	door_locked_checkbox.disabled = not can_current_player_toggle_door_lock()
	door_locked_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_button_text(door_locked_checkbox, 15)
	door_editor_panel.add_child(door_locked_checkbox)

	if password_door:
		add_door_editor_label("PASSWORD", Vector2(32, 294), Vector2(158, 26), 15)
		door_password_input = LineEdit.new()
		door_password_input.position = Vector2(176, 288)
		door_password_input.size = Vector2(340, 42)
		door_password_input.placeholder_text = "Leave blank to keep password"
		door_password_input.text = ""
		door_password_input.max_length = MAX_DOOR_PASSWORD_LENGTH
		door_password_input.secret = true
		door_password_input.mouse_filter = Control.MOUSE_FILTER_STOP
		PixelUIStyle.apply_input(door_password_input, 18)
		door_editor_panel.add_child(door_password_input)

		door_password_clear_checkbox = CheckBox.new()
		door_password_clear_checkbox.text = "CLEAR PASSWORD"
		door_password_clear_checkbox.position = Vector2(174, 340)
		door_password_clear_checkbox.size = Vector2(220, 34)
		door_password_clear_checkbox.button_pressed = false
		door_password_clear_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
		PixelUIStyle.apply_button_text(door_password_clear_checkbox, 15)
		door_editor_panel.add_child(door_password_clear_checkbox)

	var enter_button = Button.new()
	enter_button.text = "ENTER"
	enter_button.position = Vector2(30, button_y)
	enter_button.size = Vector2(116, 44)
	enter_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_green_button(enter_button, 15)
	enter_button.pressed.connect(func():
		var enter_grid = door_editor_grid
		close_door_editor()
		try_enter_door_at(enter_grid, false)
	)
	door_editor_panel.add_child(enter_button)

	var clear_button = Button.new()
	clear_button.text = "CLEAR"
	clear_button.position = Vector2(158, button_y)
	clear_button.size = Vector2(116, 44)
	clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(clear_button, 15)
	clear_button.pressed.connect(func():
		if door_name_input != null:
			door_name_input.text = ""
		if door_id_input != null:
			door_id_input.text = ""
		if door_destination_input != null:
			door_destination_input.text = ""
	)
	door_editor_panel.add_child(clear_button)

	var cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(286, button_y)
	cancel_button.size = Vector2(116, 44)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(cancel_button, 15)
	cancel_button.pressed.connect(close_door_editor)
	door_editor_panel.add_child(cancel_button)

	var save_button = Button.new()
	save_button.text = "SAVE"
	save_button.position = Vector2(414, button_y)
	save_button.size = Vector2(116, 44)
	save_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(save_button, 15)
	save_button.pressed.connect(save_door_editor_state)
	door_editor_panel.add_child(save_button)

	PixelUIStyle.play_panel_open(door_editor_panel, Vector2(0.96, 0.96), 0.14)
	if door_name_input != null:
		door_name_input.grab_focus()


func save_door_editor_state():
	var grid_pos = door_editor_grid
	if world == null:
		close_door_editor()
		return

	if not world.blocks.has(grid_pos):
		close_door_editor()
		world.show_notification("That door is gone.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_door_block(block_type):
		close_door_editor()
		world.show_notification("That door is gone.")
		return

	if not can_current_player_configure_door():
		close_door_editor()
		world.show_notification("Only the owner or trusted builders can edit this door.")
		return

	var door_name = sanitize_door_name(door_name_input.text if door_name_input != null else "")
	var door_id = sanitize_door_id(door_id_input.text if door_id_input != null else "")
	var destination = normalize_door_destination_text(door_destination_input.text if door_destination_input != null else "")
	var locked = bool(world.blocks[grid_pos].get("entrance_locked", false))
	if door_locked_checkbox != null and can_current_player_toggle_door_lock():
		locked = door_locked_checkbox.button_pressed
	var parsed = parse_door_destination(destination)
	var password_changed := false
	var door_password := ""
	if is_password_door_block(block_type):
		if not can_current_player_edit_password_door():
			close_door_editor()
			world.show_notification("Only the world owner can edit this password.")
			return
		var clear_password := door_password_clear_checkbox != null and door_password_clear_checkbox.button_pressed
		var typed_password := sanitize_door_password(door_password_input.text if door_password_input != null else "")
		if clear_password:
			password_changed = true
			door_password = ""
		elif typed_password != "":
			password_changed = true
			door_password = typed_password

	apply_door_state_to_block(
		grid_pos,
		door_id,
		destination,
		locked,
		str(parsed.get("world", "")),
		str(parsed.get("door_id", "")),
		door_password,
		door_password != "",
		password_changed,
		door_name
	)
	send_network_door_state(grid_pos, door_id, destination, locked, door_password, password_changed, door_name)
	close_door_editor()
	if door_name != "" or door_id != "" or destination != "" or password_changed:
		world.show_notification("Door saved.")
	else:
		world.show_notification("Door link cleared.")


func send_network_door_state(grid_pos: Vector2i, door_id: String, destination: String, locked: bool, password: String = "", password_changed: bool = false, door_name: String = ""):
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null:
		if network.has_method("send_door_state"):
			network.send_door_state(grid_pos, door_id, destination, locked, world.current_world_name, password, password_changed, sanitize_door_name(door_name))
		elif network.has_method("send_world_interaction_update"):
			var payload := {
				"action": "door_state",
				"x": grid_pos.x,
				"y": grid_pos.y,
				"door_id": door_id,
				"door_name": sanitize_door_name(door_name),
				"name": sanitize_door_name(door_name),
				"destination": destination,
				"locked": locked
			}
			if password_changed:
				payload["password_changed"] = true
				payload["password"] = sanitize_door_password(password)
			network.send_world_interaction_update(payload, world.current_world_name)


func is_password_door_entry_open() -> bool:
	return password_door_panel != null and is_instance_valid(password_door_panel)


func close_password_door_entry():
	if password_door_overlay != null and is_instance_valid(password_door_overlay):
		password_door_overlay.queue_free()
	password_door_overlay = null

	if password_door_panel != null and is_instance_valid(password_door_panel):
		password_door_panel.queue_free()
	password_door_panel = null
	password_door_input = null
	password_door_grid = Vector2i(999999, 999999)


func open_password_door_entry(grid_pos: Vector2i):
	close_password_door_entry()

	if world == null or world.ui_layer == null:
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("That door is gone.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_password_door_block(block_type):
		world.show_notification("Nothing to interact with.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_method("close_inventory_window"):
		world.close_inventory_window()
	if world.has_method("close_sign"):
		world.close_sign()
	if world.has_method("close_crafting"):
		world.close_crafting()
	if world.has_method("close_furnace"):
		world.close_furnace()

	password_door_grid = grid_pos
	var viewport_size = world.get_viewport_rect().size

	password_door_overlay = ColorRect.new()
	password_door_overlay.name = "PasswordDoorOverlay"
	password_door_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	password_door_overlay.color = Color(0.0, 0.0, 0.0, 0.38)
	password_door_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	password_door_overlay.z_index = 218
	world.ui_layer.add_child(password_door_overlay)

	password_door_panel = Panel.new()
	password_door_panel.name = "PasswordDoorPanel"
	password_door_panel.size = Vector2(460, 236)
	password_door_panel.position = (viewport_size - password_door_panel.size) * 0.5
	password_door_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	password_door_panel.z_index = 219
	password_door_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	world.ui_layer.add_child(password_door_panel)

	var title = Label.new()
	title.text = "PASSWORD DOOR"
	title.position = Vector2(24, 18)
	title.size = Vector2(350, 36)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 24)
	password_door_panel.add_child(title)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(400, 20)
	close_button.size = Vector2(38, 34)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_password_door_entry)
	password_door_panel.add_child(close_button)

	var label = Label.new()
	label.text = "PASSWORD"
	label.position = Vector2(32, 82)
	label.size = Vector2(140, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(label, 15)
	password_door_panel.add_child(label)

	password_door_input = LineEdit.new()
	password_door_input.position = Vector2(154, 76)
	password_door_input.size = Vector2(260, 42)
	password_door_input.placeholder_text = "Enter password"
	password_door_input.max_length = MAX_DOOR_PASSWORD_LENGTH
	password_door_input.secret = true
	password_door_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(password_door_input, 18)
	password_door_panel.add_child(password_door_input)
	password_door_input.text_submitted.connect(func(_text):
		submit_password_door_entry()
	)

	var cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(78, 160)
	cancel_button.size = Vector2(132, 44)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(cancel_button, 15)
	cancel_button.pressed.connect(close_password_door_entry)
	password_door_panel.add_child(cancel_button)

	var enter_button = Button.new()
	enter_button.text = "ENTER"
	enter_button.position = Vector2(248, 160)
	enter_button.size = Vector2(132, 44)
	enter_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_green_button(enter_button, 15)
	enter_button.pressed.connect(submit_password_door_entry)
	password_door_panel.add_child(enter_button)

	PixelUIStyle.play_panel_open(password_door_panel, Vector2(0.96, 0.96), 0.14)
	password_door_input.grab_focus()


func submit_password_door_entry():
	var grid_pos = password_door_grid
	var password = sanitize_door_password(password_door_input.text if password_door_input != null else "")
	close_password_door_entry()
	try_enter_door_at(grid_pos, true, password)


func try_enter_door_at(grid_pos: Vector2i, force: bool = false, password: String = "") -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_door_block(block_type):
		return false

	var now_msec = Time.get_ticks_msec()
	if not force and now_msec < door_enter_cooldown_until_msec:
		return false

	if is_password_door_block(block_type) and not force:
		open_password_door_entry(grid_pos)
		return true

	var state = get_door_state(grid_pos)
	var target_id = sanitize_door_id(state.get("target_door_id", ""))
	var target_world = sanitize_door_world_name(state.get("target_world", ""))
	var destination = normalize_door_destination_text(state.get("destination", ""))
	if destination == "":
		return false
	if target_id == "" and target_world == "":
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_door_enter"):
		world.show_notification("Door travel is not ready.")
		return false

	if not bool(network.send_door_enter(grid_pos, world.current_world_name, sanitize_door_password(password))):
		world.show_notification("Door travel is not ready.")
		return false

	door_enter_cooldown_until_msec = now_msec + DOOR_ENTER_COOLDOWN_MSEC
	world.show_notification("Entering door...")
	return true


func update_auto_door_entry(player_grid: Vector2i):
	if world == null:
		return

	if player_grid == last_auto_door_grid:
		return

	last_auto_door_grid = player_grid
	if not world.blocks.has(player_grid):
		return

	var block_type = str(world.blocks[player_grid].get("type", ""))
	if not is_door_block(block_type):
		return
	if not is_auto_enter_door_block(block_type):
		return

	try_enter_door_at(player_grid, false)


func set_door_enter_cooldown(duration_msec: int = DOOR_ENTER_COOLDOWN_MSEC):
	door_enter_cooldown_until_msec = Time.get_ticks_msec() + max(0, duration_msec)
	last_auto_door_grid = Vector2i(999999, 999999)


func is_toggle_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("toggle_block", false))

	return false


func is_anti_punch_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_punch_block", false))

	return block_type.strip_edges().to_lower() == "anti_punch"


func is_anti_talk_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_talk_block", false))

	return block_type.strip_edges().to_lower() == "anti_talk"


func is_anti_gravity_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("anti_gravity_block", false))

	return block_type.strip_edges().to_lower() == "anti_gravity"


func is_theme_machine_block(block_type: String) -> bool:
	if world != null and world.has_method("is_theme_machine_block_type"):
		return bool(world.is_theme_machine_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("theme_machine_block", false))

	var clean_type := block_type.strip_edges().to_lower()
	return clean_type == "night_theme_machine" or clean_type == "snow_theme_machine" or clean_type == "theme_machine"


func is_punch_toggle_machine_block(block_type: String) -> bool:
	return (
		is_anti_punch_block(block_type)
		or is_anti_talk_block(block_type)
		or is_anti_gravity_block(block_type)
		or is_theme_machine_block(block_type)
	)


func get_block_display_name(block_type: String) -> String:
	if world != null and world.item_database.has(block_type):
		return str(world.item_database[block_type].get("display_name", block_type.replace("_", " ").capitalize()))

	return block_type.replace("_", " ").capitalize()


func get_theme_machine_theme_for_block(block_type: String) -> String:
	if world != null and world.item_database.has(block_type):
		var item_theme := str(world.item_database[block_type].get("theme_machine_theme", "")).strip_edges().to_lower()
		if item_theme != "":
			return item_theme

	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "snow_theme_machine":
		return "snow"
	return "night"


func get_theme_machine_theme_label(theme_name: String) -> String:
	var clean_theme := theme_name.strip_edges().to_lower()
	if clean_theme == "snow":
		return "Snow"
	if clean_theme == "night":
		return "Night"
	return clean_theme.capitalize()


func is_vending_machine_block(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func is_safe_block(block_type: String) -> bool:
	return block_type == "safe"


func is_donation_box_block(block_type: String) -> bool:
	if world != null and world.has_method("is_donation_box_block_type"):
		return bool(world.is_donation_box_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("donation_box_block", false))
	return block_type.strip_edges().to_lower() == "donation_box"


func is_mailbox_block(block_type: String) -> bool:
	if world != null and world.has_method("is_mailbox_block_type"):
		return bool(world.is_mailbox_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("mailbox_block", false))
	return block_type == "mail_box" or block_type == "blue_mail_box"

func is_bulletin_board_block(block_type: String) -> bool:
	if world != null and world.has_method("is_bulletin_board_block_type"):
		return bool(world.is_bulletin_board_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("bulletin_board_block", false))
	return block_type == "bulletin_board"


func is_display_block(block_type: String) -> bool:
	if world != null and world.has_method("is_display_block_type"):
		return bool(world.is_display_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("display_block", false))
	return block_type == "display_box" or block_type == "display_case"


func is_fish_hanger_block(block_type: String) -> bool:
	if world != null and world.has_method("is_fish_hanger_block_type"):
		return bool(world.is_fish_hanger_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("fish_hanger_block", false))
	return block_type == "fish_hanger"


func is_fish_monger_block(block_type: String) -> bool:
	return block_type == "fish_monger"


func open_vending_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_vending_ui"):
		world.open_vending_ui(grid_pos)
	else:
		world.show_notification("Vending UI is not ready.")


func open_safe_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_safe_ui"):
		world.open_safe_ui(grid_pos)
	else:
		world.show_notification("Safe UI is not ready.")


func open_donation_box_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_donation_box_ui"):
		world.open_donation_box_ui(grid_pos)
	else:
		world.show_notification("Donation Box UI is not ready.")


func open_mailbox_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_mailbox_ui"):
		world.open_mailbox_ui(grid_pos)
	else:
		world.show_notification("Mailbox UI is not ready.")

func open_bulletin_board_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_bulletin_board_ui"):
		world.open_bulletin_board_ui(grid_pos)
	else:
		world.show_notification("Bulletin Board UI is not ready.")


func open_display_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_display_ui"):
		world.open_display_ui(grid_pos)
	else:
		world.show_notification("Display UI is not ready.")


func open_fish_monger_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_fish_monger_ui"):
		world.open_fish_monger_ui(grid_pos)
	else:
		world.show_notification("Fish Monger UI is not ready.")

func open_cctv_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_cctv_ui"):
		world.open_cctv_ui(grid_pos)
	else:
		world.show_notification("CCTV UI is not ready.")

func open_oil_refinery_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_oil_refinery_ui"):
		world.open_oil_refinery_ui(grid_pos)


func open_battery_charger_ui(grid_pos: Vector2i):
	if world != null and world.has_method("open_battery_charger_ui"):
		world.open_battery_charger_ui(grid_pos)
	else:
		world.show_notification("Oil Refinery UI is not ready.")


func can_current_player_toggle_wooden_entrance() -> bool:
	if world != null and world.has_method("can_current_player_toggle_wooden_entrance"):
		return bool(world.can_current_player_toggle_wooden_entrance())

	return true


func can_current_player_use_theme_machine(grid_pos: Vector2i) -> bool:
	if world != null and world.has_method("can_current_player_use_theme_machine_at"):
		return bool(world.can_current_player_use_theme_machine_at(grid_pos))
	if world != null and world.has_method("can_current_player_build_at"):
		return bool(world.can_current_player_build_at(grid_pos))

	return true


func is_wooden_entrance_confirm_open() -> bool:
	return wooden_entrance_confirm_panel != null and is_instance_valid(wooden_entrance_confirm_panel)


func close_wooden_entrance_confirm():
	if wooden_entrance_confirm_overlay != null and is_instance_valid(wooden_entrance_confirm_overlay):
		wooden_entrance_confirm_overlay.queue_free()
	wooden_entrance_confirm_overlay = null

	if wooden_entrance_confirm_panel != null and is_instance_valid(wooden_entrance_confirm_panel):
		wooden_entrance_confirm_panel.queue_free()
	wooden_entrance_confirm_panel = null
	wooden_entrance_confirm_grid = Vector2i(999999, 999999)
	wooden_entrance_confirm_locked = false


func is_theme_machine_confirm_open() -> bool:
	return theme_machine_confirm_panel != null and is_instance_valid(theme_machine_confirm_panel)


func close_theme_machine_confirm():
	if theme_machine_confirm_overlay != null and is_instance_valid(theme_machine_confirm_overlay):
		theme_machine_confirm_overlay.queue_free()
	theme_machine_confirm_overlay = null

	if theme_machine_confirm_panel != null and is_instance_valid(theme_machine_confirm_panel):
		theme_machine_confirm_panel.queue_free()
	theme_machine_confirm_panel = null
	theme_machine_confirm_grid = Vector2i(999999, 999999)
	theme_machine_confirm_enabled = false
	theme_machine_confirm_theme = "night"


func is_theme_machine_enabled_at(grid_pos: Vector2i) -> bool:
	if world != null and "theme_machine_states" in world and world.theme_machine_states is Dictionary:
		if world.theme_machine_states.has(grid_pos):
			var state_value: Variant = world.theme_machine_states.get(grid_pos, {})
			if state_value is Dictionary:
				var state: Dictionary = state_value
				if state.has("state") and state.get("state") is Dictionary:
					var nested_state: Dictionary = state.get("state", {})
					return bool(nested_state.get("enabled", false))
				return bool(state.get("enabled", false))
	return false


func open_theme_machine_confirm(grid_pos: Vector2i):
	close_theme_machine_confirm()

	if world == null:
		return

	if world.ui_layer == null:
		world.show_notification("Theme Machine controls are not ready.")
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("Nothing to interact with.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_theme_machine_block(block_type):
		world.show_notification("Nothing to interact with.")
		return
	var theme_name := get_theme_machine_theme_for_block(block_type)
	var theme_label := get_theme_machine_theme_label(theme_name)

	if not can_current_player_use_theme_machine(grid_pos):
		world.show_notification("Only world or area-lock builders can use this " + get_block_display_name(block_type) + ".")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var currently_enabled = is_theme_machine_enabled_at(grid_pos)
	var target_enabled = not currently_enabled
	theme_machine_confirm_grid = grid_pos
	theme_machine_confirm_enabled = target_enabled
	theme_machine_confirm_theme = theme_name

	var viewport_size = world.get_viewport_rect().size

	theme_machine_confirm_overlay = ColorRect.new()
	theme_machine_confirm_overlay.name = "ThemeMachineConfirmOverlay"
	theme_machine_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_machine_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.36)
	theme_machine_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	theme_machine_confirm_overlay.z_index = 210
	world.ui_layer.add_child(theme_machine_confirm_overlay)

	theme_machine_confirm_panel = Panel.new()
	theme_machine_confirm_panel.name = "ThemeMachineConfirmPanel"
	theme_machine_confirm_panel.size = Vector2(470, 238)
	theme_machine_confirm_panel.position = (viewport_size - theme_machine_confirm_panel.size) * 0.5
	theme_machine_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	theme_machine_confirm_panel.z_index = 211
	theme_machine_confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	world.ui_layer.add_child(theme_machine_confirm_panel)

	var title = Label.new()
	title.name = "Title"
	title.text = get_block_display_name(block_type).to_upper()
	title.position = Vector2(26, 18)
	title.size = Vector2(418, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 25)
	theme_machine_confirm_panel.add_child(title)

	var current_text = theme_label + " theme is active" if currently_enabled else theme_label + " theme is inactive"
	var target_text = "Turn the " + theme_label.to_lower() + " theme on?" if target_enabled else "Turn the " + theme_label.to_lower() + " theme off?"
	var message = Label.new()
	message.name = "Message"
	message.text = current_text + "\n" + target_text
	message.position = Vector2(38, 66)
	message.size = Vector2(394, 78)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(message, 18)
	theme_machine_confirm_panel.add_child(message)

	var confirm = Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = "TURN ON" if target_enabled else "TURN OFF"
	confirm.position = Vector2(34, 166)
	confirm.size = Vector2(188, 46)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 15)
	confirm.pressed.connect(func(): confirm_theme_machine_state())
	theme_machine_confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(248, 166)
	cancel.size = Vector2(188, 46)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(cancel, 15)
	cancel.pressed.connect(close_theme_machine_confirm)
	theme_machine_confirm_panel.add_child(cancel)

	PixelUIStyle.play_panel_open(theme_machine_confirm_panel, Vector2(0.96, 0.96), 0.14)


func confirm_theme_machine_state():
	var grid_pos = theme_machine_confirm_grid
	var target_enabled = theme_machine_confirm_enabled
	var theme_name = theme_machine_confirm_theme
	close_theme_machine_confirm()

	if world == null:
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("That Theme Machine is gone.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_theme_machine_block(block_type):
		world.show_notification("That Theme Machine is gone.")
		return
	theme_name = get_theme_machine_theme_for_block(block_type)
	var theme_label := get_theme_machine_theme_label(theme_name)

	if not can_current_player_use_theme_machine(grid_pos):
		world.show_notification("Only world or area-lock builders can use this " + get_block_display_name(block_type) + ".")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var currently_enabled = is_theme_machine_enabled_at(grid_pos)
	if currently_enabled == target_enabled:
		world.show_notification(theme_label + " theme is already " + ("on." if target_enabled else "off."))
		return

	if world.has_method("apply_theme_machine_state"):
		world.apply_theme_machine_state(grid_pos, target_enabled, true, true, theme_name)
	else:
		world.show_notification("Theme Machine controls are not ready.")


func open_wooden_entrance_confirm(grid_pos: Vector2i):
	close_wooden_entrance_confirm()

	if world == null:
		return

	if world.ui_layer == null:
		world.show_notification("Entrance controls are not ready.")
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("Nothing to interact with.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_wooden_entrance_block(block_type):
		world.show_notification("Nothing to interact with.")
		return

	if not can_current_player_toggle_wooden_entrance():
		world.show_notification("Only the world owner or world admins can lock this entrance.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var currently_locked = bool(world.blocks[grid_pos].get("entrance_locked", false))
	var target_locked = not currently_locked
	wooden_entrance_confirm_grid = grid_pos
	wooden_entrance_confirm_locked = target_locked

	var viewport_size = world.get_viewport_rect().size

	wooden_entrance_confirm_overlay = ColorRect.new()
	wooden_entrance_confirm_overlay.name = "WoodenEntranceConfirmOverlay"
	wooden_entrance_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	wooden_entrance_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.36)
	wooden_entrance_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	wooden_entrance_confirm_overlay.z_index = 210
	world.ui_layer.add_child(wooden_entrance_confirm_overlay)

	wooden_entrance_confirm_panel = Panel.new()
	wooden_entrance_confirm_panel.name = "WoodenEntranceConfirmPanel"
	wooden_entrance_confirm_panel.size = Vector2(470, 238)
	wooden_entrance_confirm_panel.position = (viewport_size - wooden_entrance_confirm_panel.size) * 0.5
	wooden_entrance_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	wooden_entrance_confirm_panel.z_index = 211
	wooden_entrance_confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	world.ui_layer.add_child(wooden_entrance_confirm_panel)

	var title = Label.new()
	title.name = "Title"
	title.text = get_block_display_name(block_type).to_upper()
	title.position = Vector2(26, 18)
	title.size = Vector2(418, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 25)
	wooden_entrance_confirm_panel.add_child(title)

	var current_text = "Currently locked" if currently_locked else "Currently unlocked"
	var target_text = "Lock this entrance?" if target_locked else "Unlock this entrance?"
	var message = Label.new()
	message.name = "Message"
	message.text = current_text + "\n" + target_text
	message.position = Vector2(38, 66)
	message.size = Vector2(394, 78)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(message, 18)
	wooden_entrance_confirm_panel.add_child(message)

	var confirm = Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = "CONFIRM LOCK" if target_locked else "CONFIRM UNLOCK"
	confirm.position = Vector2(34, 166)
	confirm.size = Vector2(188, 46)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(confirm, 14)
	confirm.pressed.connect(func(): confirm_wooden_entrance_state())
	wooden_entrance_confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.name = "CancelButton"
	cancel.text = "CANCEL"
	cancel.position = Vector2(248, 166)
	cancel.size = Vector2(188, 46)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(cancel, 15)
	cancel.pressed.connect(close_wooden_entrance_confirm)
	wooden_entrance_confirm_panel.add_child(cancel)

	PixelUIStyle.play_panel_open(wooden_entrance_confirm_panel, Vector2(0.96, 0.96), 0.14)


func confirm_wooden_entrance_state():
	var grid_pos = wooden_entrance_confirm_grid
	var target_locked = wooden_entrance_confirm_locked
	close_wooden_entrance_confirm()

	if world == null:
		return

	if not world.blocks.has(grid_pos):
		world.show_notification("That entrance is gone.")
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_wooden_entrance_block(block_type):
		world.show_notification("That entrance is gone.")
		return

	if not can_current_player_toggle_wooden_entrance():
		world.show_notification("Only the world owner or world admins can lock this entrance.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var currently_locked = bool(world.blocks[grid_pos].get("entrance_locked", false))
	if currently_locked == target_locked:
		world.show_notification(get_block_display_name(block_type) + " is already " + ("locked." if target_locked else "unlocked."))
		return

	set_wooden_entrance_locked(grid_pos, target_locked)
	world.show_notification(get_block_display_name(block_type) + (" locked." if target_locked else " unlocked."))


func set_wooden_entrance_locked(grid_pos: Vector2i, locked: bool):
	if not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos]["type"])

	if not is_wooden_entrance_block(block_type):
		return

	world.blocks[grid_pos]["entrance_locked"] = locked

	if world.block_manager != null and world.block_manager.has_method("refresh_wooden_entrance_collision"):
		world.block_manager.refresh_wooden_entrance_collision(grid_pos)

	update_wooden_entrance_visual(grid_pos)

	send_network_wooden_entrance_state(grid_pos, locked)


func toggle_wooden_entrance(grid_pos: Vector2i):
	open_wooden_entrance_confirm(grid_pos)


func send_network_wooden_entrance_state(grid_pos: Vector2i, locked: bool):
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		network.send_world_interaction_update({
			"action": "wooden_entrance_state",
			"x": grid_pos.x,
			"y": grid_pos.y,
			"locked": locked
		}, world.current_world_name)


func toggle_block_state(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos):
		return

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_toggle_block(block_type):
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	var item_data = world.item_database[block_type]
	var state_key = str(item_data.get("toggle_state_key", "toggle_on"))
	var next_on = not bool(world.blocks[grid_pos].get(state_key, false))
	world.blocks[grid_pos][state_key] = next_on

	if world.block_manager != null and world.block_manager.has_method("update_toggle_block_visual"):
		world.block_manager.update_toggle_block_visual(grid_pos)

	send_network_toggle_block_state(grid_pos, block_type, next_on)
	world.show_notification(get_block_display_name(block_type) + (" on." if next_on else " off."))


func try_punch_toggle_machine_at(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type := str(world.blocks[grid_pos].get("type", ""))
	if not is_punch_toggle_machine_block(block_type):
		return false

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return false

	if is_anti_punch_block(block_type):
		return toggle_anti_punch_state(grid_pos)
	elif is_anti_talk_block(block_type):
		return toggle_anti_talk_state(grid_pos)
	elif is_anti_gravity_block(block_type):
		return toggle_anti_gravity_state(grid_pos)
	return toggle_theme_machine_state(grid_pos)


func toggle_theme_machine_state(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type := str(world.blocks[grid_pos].get("type", ""))
	if not is_theme_machine_block(block_type):
		return false

	if not can_current_player_use_theme_machine(grid_pos):
		world.show_notification("Only world or area-lock builders can use this " + get_block_display_name(block_type) + ".")
		return false

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return false

	if not world.has_method("apply_theme_machine_state"):
		world.show_notification("Theme Machine controls are not ready.")
		return false

	var theme_name := get_theme_machine_theme_for_block(block_type)
	return bool(world.apply_theme_machine_state(
		grid_pos,
		not is_theme_machine_enabled_at(grid_pos),
		true,
		true,
		theme_name
	))


func toggle_anti_punch_state(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_anti_punch_block(block_type):
		return false

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return false

	if world.has_method("can_current_player_toggle_anti_punch") and not world.can_current_player_toggle_anti_punch():
		world.show_notification("Only the world owner or world admins can toggle anti-punch.")
		return false

	if world.has_method("apply_anti_punch_state"):
		return bool(world.apply_anti_punch_state(grid_pos, not is_anti_punch_enabled(grid_pos), true, true))
	return false


func is_anti_punch_enabled(grid_pos: Vector2i) -> bool:
	if world != null and "anti_punch_states" in world and world.anti_punch_states is Dictionary:
		if world.anti_punch_states.has(grid_pos):
			var state_value: Variant = world.anti_punch_states.get(grid_pos, {})
			if state_value is Dictionary:
				var state: Dictionary = state_value
				if state.has("state") and state.get("state") is Dictionary:
					var nested_state: Dictionary = state.get("state", {})
					return bool(nested_state.get("enabled", false))
				return bool(state.get("enabled", false))
	return false


func toggle_anti_talk_state(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_anti_talk_block(block_type):
		return false

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return false

	if world.has_method("can_current_player_toggle_anti_talk") and not world.can_current_player_toggle_anti_talk():
		world.show_notification("Only the world owner or world admins can toggle anti-talk.")
		return false

	if world.has_method("apply_anti_talk_state"):
		return bool(world.apply_anti_talk_state(grid_pos, not is_anti_talk_enabled(grid_pos), true, true))
	return false


func is_anti_talk_enabled(grid_pos: Vector2i) -> bool:
	if world != null and "anti_talk_states" in world and world.anti_talk_states is Dictionary:
		if world.anti_talk_states.has(grid_pos):
			var state_value: Variant = world.anti_talk_states.get(grid_pos, {})
			if state_value is Dictionary:
				var state: Dictionary = state_value
				if state.has("state") and state.get("state") is Dictionary:
					var nested_state: Dictionary = state.get("state", {})
					return bool(nested_state.get("enabled", false))
				return bool(state.get("enabled", false))
	return false


func toggle_anti_gravity_state(grid_pos: Vector2i) -> bool:
	if world == null or not world.blocks.has(grid_pos):
		return false

	var block_type = str(world.blocks[grid_pos].get("type", ""))
	if not is_anti_gravity_block(block_type):
		return false

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return false

	if world.has_method("can_current_player_toggle_anti_gravity") and not world.can_current_player_toggle_anti_gravity():
		world.show_notification("Only the world owner or world admins can toggle anti-gravity.")
		return false

	if world.has_method("apply_anti_gravity_state"):
		return bool(world.apply_anti_gravity_state(grid_pos, not is_anti_gravity_enabled(grid_pos), true, true))
	return false


func is_anti_gravity_enabled(grid_pos: Vector2i) -> bool:
	if world != null and "anti_gravity_states" in world and world.anti_gravity_states is Dictionary:
		if world.anti_gravity_states.has(grid_pos):
			var state_value: Variant = world.anti_gravity_states.get(grid_pos, {})
			if state_value is Dictionary:
				var state: Dictionary = state_value
				if state.has("state") and state.get("state") is Dictionary:
					var nested_state: Dictionary = state.get("state", {})
					return bool(nested_state.get("enabled", false))
				return bool(state.get("enabled", false))
	return false


func send_network_toggle_block_state(grid_pos: Vector2i, block_type: String, toggle_on: bool):
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var action = block_type + "_state"
	if world.item_database.has(block_type):
		action = str(world.item_database[block_type].get("toggle_action", action))

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		network.send_world_interaction_update({
			"action": action,
			"x": grid_pos.x,
			"y": grid_pos.y,
			"on": toggle_on
		}, world.current_world_name)


func update_wooden_entrance_visual(grid_pos: Vector2i):
	if world == null or world.block_manager == null:
		return

	if world.block_manager.has_method("update_wooden_entrance_visual"):
		world.block_manager.update_wooden_entrance_visual(grid_pos)


func is_crafting_station_block(block_type: String) -> bool:
	return block_type == "crafting_station"


func get_crafting_station_left_pos(grid_pos: Vector2i) -> Vector2i:
	return grid_pos


func should_server_create_break_drops() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func place_crafting_station_at_mouse():
	if not world.inventory.has("crafting_station"):
		return

	if world.inventory["crafting_station"] <= 0:
		world.show_notification("You don't have a Crafting Station.")
		return

	var grid_pos = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(grid_pos):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(grid_pos):
		world.show_notification("Too far away.")
		return

	if world.has_method("can_current_player_build") and not world.can_current_player_build():
		world.show_notification("This world is locked.")
		return

	if not world.can_place_block_here(grid_pos):
		world.show_notification("Need an empty tile.")
		return

	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if send_network_station_place(grid_pos):
			world.show_notification("Placing Crafting Station...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	world.create_block(grid_pos, "crafting_station")

	send_network_station_place(grid_pos)

	world.inventory["crafting_station"] -= 1
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change("crafting_station", "block")
	else:
		world.update_all_ui()


func break_crafting_station(grid_pos: Vector2i):
	if world.has_method("can_current_player_break_block") and not world.can_current_player_break_block("crafting_station"):
		world.show_notification("This world is locked.")
		return

	var station_pos = get_crafting_station_left_pos(grid_pos)

	if world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if send_network_station_remove(station_pos):
			world.show_notification("Breaking Crafting Station...")
		else:
			world.show_notification("Almost ready. Try again in a moment.")
		return

	var drop_position = Vector2(station_pos.x * world.BLOCK_SIZE, station_pos.y * world.BLOCK_SIZE)

	if world.blocks.has(station_pos):
		var block_data = world.blocks[station_pos]
		var block_node = block_data.get("node", null) if block_data is Dictionary else null
		if world.block_manager != null and world.block_manager.has_method("clear_tilemap_cell"):
			world.block_manager.clear_tilemap_cell(station_pos, false)

		if is_instance_valid(block_node):
			var crack_overlay = block_node.get_node_or_null("CrackOverlay")
			if crack_overlay != null:
				crack_overlay.queue_free()

			block_node.queue_free()

		world.blocks.erase(station_pos)
		world.block_hit_progress.erase(station_pos)
		world.block_hit_timers.erase(station_pos)

	send_network_station_remove(station_pos)

	if not should_server_create_break_drops():
		world.create_item_drop("crafting_station", drop_position, false, "block", 0.0, 1)
		world.try_drop_gems("crafting_station", drop_position)


func is_furnace_block(block_type: String) -> bool:
	return block_type == "furnace"


func send_network_station_place(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_block_update"):
		return false

	return bool(network.send_world_block_update("place", "foreground", grid_pos, "crafting_station", world.current_world_name))


func send_network_station_remove(grid_pos: Vector2i) -> bool:
	if world == null:
		return false

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_block_update"):
		return false

	return bool(network.send_world_block_update("break", "foreground", grid_pos, "crafting_station", world.current_world_name))
