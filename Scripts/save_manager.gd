extends Node

var world = null

var autosave_interval := 1.0
var autosave_timer: Timer = null
var save_queued := false
var save_request_id := 0
var is_saving_now := false
var loading_player_data := false
var applying_server_player_data := false
var waiting_for_server_world_state := false
var world_entry_pending_announce := false
var legacy_server_inventory_import_in_flight := false
var legacy_server_inventory_import_attempts := 0
var last_server_player_state_username := ""
var last_server_player_state_hash := 0
var last_server_player_state_applied_ms := 0

# Turn this on only when you want console proof that saving is happening.
# Leaving it false avoids printing "World saved." every second.
var print_save_messages := false
const PLAYER_SAVE_FOLDER = "user://players/"
const LEGACY_PLAYER_MIGRATION_MARKER = "user://players/_legacy_player_data_migrated.txt"
const LEGACY_SERVER_INVENTORY_IMPORT_MARKER_PREFIX = "user://players/_legacy_server_inventory_import_confirmed_"
const LEGACY_SERVER_INVENTORY_IMPORT_MAX_ATTEMPTS := 3
const LEGACY_SERVER_INVENTORY_IMPORT_REVISION := 3
const PLAYER_INVENTORY_SAVE_KEYS = [
	"inventory",
	"seed_inventory",
	"tool_inventory",
	"back_inventory",
	"hair_inventory",
	"shirt_inventory",
	"pants_inventory",
	"shoes_inventory",
	"currency_inventory",
	"material_inventory",
	"lure_inventory",
	"fish_inventory"
]
const PLAYER_LOADOUT_SAVE_KEYS = [
	"selected_item_type",
	"selected_item_category",
	"primary_hotbar_tool",
	"equipped_tool",
	"equipped_back_item",
	"equipped_hair_item",
	"equipped_shirt_item",
	"equipped_pants_item",
	"equipped_shoes_item"
]
const MAX_INVENTORY_STACK := 200
const MAX_INVENTORY_STRING_LEN := 64
const MAX_PLAYER_HEALTH := 10
const MAX_PLAYER_LEVEL := 100
const DUPLICATE_SERVER_PLAYER_STATE_WINDOW_MS := 1500
const DEBUG_ACTION_POSITION_FLOW := false


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var player_pos_text = "none"
	if world != null and world.player != null:
		player_pos_text = str(world.player.global_position)
	var world_name_text = str(world.current_world_name) if world != null else ""
	print("[PM_FLOW][SaveManager] " + message + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func _safe_int(value, fallback: int, min_value: int = 0, max_value: int = 2147483647) -> int:
	if value is int:
		var num = int(value)
		return clamp(num, min_value, max_value)
	if value is float:
		var num = float(value)
		if not is_finite(num):
			return fallback
		return clamp(int(num), min_value, max_value)
	return fallback


func _safe_string(value, fallback: String = "", max_length: int = 0) -> String:
	if value == null:
		return fallback

	var text = str(value).strip_edges()
	if text == "":
		return fallback

	if max_length > 0 and text.length() > max_length:
		text = text.substr(0, max_length)

	return text


func _safe_float(value, fallback: float, min_value: float = -1.0e9, max_value: float = 1.0e9) -> float:
	if value is int or value is float:
		var num = float(value)
		if not is_finite(num):
			return fallback
		return clamp(num, min_value, max_value)

	return fallback


func _safe_bool(value, fallback: bool = false) -> bool:
	if value is bool:
		return value
	return fallback


func setup(world_ref, _autosave_interval: float = 1.0):
	world = world_ref
	autosave_interval = _autosave_interval

	if autosave_interval < 0.25:
		autosave_interval = 0.25

	start_autosave_timer()


func start_autosave_timer():
	if autosave_timer != null and is_instance_valid(autosave_timer):
		autosave_timer.stop()
		autosave_timer.queue_free()

	autosave_timer = Timer.new()
	autosave_timer.one_shot = false
	autosave_timer.wait_time = autosave_interval
	autosave_timer.autostart = false
	add_child(autosave_timer)

	if not autosave_timer.timeout.is_connected(_on_autosave_timeout):
		autosave_timer.timeout.connect(_on_autosave_timeout)

	autosave_timer.start()


func _on_autosave_timeout():
	request_save()


func request_save(instant: bool = false):
	if world == null:
		return

	if not world.in_world:
		return

	if should_use_server_world_state():
		return

	if instant:
		save_request_id += 1
		save_queued = false
		save_world()
		return

	if save_queued:
		return

	save_queued = true
	save_request_id += 1
	var queued_id = save_request_id
	_run_queued_save(queued_id)


func _run_queued_save(queued_id: int) -> void:
	await get_tree().create_timer(0.15).timeout

	if queued_id != save_request_id:
		return

	save_queued = false
	save_world()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_save(true)


func get_block_manager_ref():
	if world == null:
		return null

	var manager = world.get("block_manager")

	if manager != null:
		return manager

	return null


func get_background_blocks_dictionary() -> Dictionary:
	var manager = get_block_manager_ref()

	if manager != null and "background_blocks" in manager:
		return manager.background_blocks

	if world != null and "background_blocks" in world:
		return world.background_blocks

	return {}


func create_saved_background_block(grid_pos: Vector2i, block_type: String):
	if world == null:
		return

	if world.has_method("create_background_block"):
		world.create_background_block(grid_pos, block_type)
		return

	var manager = get_block_manager_ref()

	if manager != null and manager.has_method("create_background_block"):
		manager.create_background_block(grid_pos, block_type)


func clear_background_blocks():
	var manager = get_block_manager_ref()

	if manager != null and manager.has_method("clear_background_blocks"):
		manager.clear_background_blocks()
		return

	var background_blocks = get_background_blocks_dictionary()

	for grid_pos in background_blocks.keys():
		var block_node = background_blocks[grid_pos].get("node", null)

		if block_node != null and is_instance_valid(block_node):
			block_node.queue_free()

	background_blocks.clear()


func should_loaded_block_get_missing_background(block_type: String, grid_pos: Vector2i) -> bool:
	if block_type != "dirt" and block_type != "stone" and block_type != "lava":
		return false

	if grid_pos.y <= world.SURFACE_Y:
		return false

	if grid_pos.y >= world.BEDROCK_START_Y:
		return false

	return true


func load_background_blocks_from_data(saved_background_blocks):
	if not (saved_background_blocks is Array):
		saved_background_blocks = []

	for block_data in saved_background_blocks:
		if not (block_data is Dictionary):
			continue

		if not block_data.has("x") or not block_data.has("y") or not block_data.has("type"):
			continue

		var block_type = _safe_string(block_data.get("type", ""), "", MAX_INVENTORY_STRING_LEN)
		if block_type == "":
			continue

		var grid_pos = Vector2i(
			_safe_int(block_data.get("x", 0), 0, 0, max(world.WORLD_WIDTH - 1, 0)),
			_safe_int(block_data.get("y", 0), 0, 0, max(world.WORLD_HEIGHT - 1, 0))
		)
		if not world.is_grid_inside_world(grid_pos):
			continue

		if world.block_textures.has(block_type):
			create_saved_background_block(grid_pos, block_type)


func add_missing_backgrounds_for_loaded_blocks():
	var background_blocks = get_background_blocks_dictionary()

	for grid_pos in world.blocks.keys():
		var block_type = str(world.blocks[grid_pos].get("type", ""))

		if background_blocks.has(grid_pos):
			continue

		if should_loaded_block_get_missing_background(block_type, grid_pos):
			create_saved_background_block(grid_pos, "cave_background")


func sanitize_world_name(raw_name: String) -> String:
	var clean = raw_name.strip_edges()

	if clean == "":
		clean = world.DEFAULT_WORLD_NAME

	clean = clean.to_lower()

	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""

	for i in range(clean.length()):
		var character = clean.substr(i, 1)

		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	if result == "":
		result = world.DEFAULT_WORLD_NAME.to_lower()

	if result.length() > 64:
		result = result.substr(0, 64)

	return result


func is_player_in_world() -> bool:
	return world.in_world == true


func get_current_world_display_name() -> String:
	if world.in_world != true:
		return "NOT IN WORLD"

	return world.current_world_name


func ensure_world_save_folder():
	if not DirAccess.dir_exists_absolute(world.WORLD_SAVE_FOLDER):
		DirAccess.make_dir_recursive_absolute(world.WORLD_SAVE_FOLDER)


func ensure_player_save_folder():
	if not DirAccess.dir_exists_absolute(PLAYER_SAVE_FOLDER):
		DirAccess.make_dir_recursive_absolute(PLAYER_SAVE_FOLDER)


func get_current_save_path() -> String:
	ensure_world_save_folder()
	return world.WORLD_SAVE_FOLDER + sanitize_world_name(world.current_world_name) + ".json"


func sanitize_player_name_for_path(raw_name: String) -> String:
	var clean = raw_name.strip_edges().to_lower()

	if clean == "":
		clean = "guest"

	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""

	for i in range(clean.length()):
		var character = clean.substr(i, 1)

		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	if result == "":
		result = "guest"

	return result


func get_current_player_profile_name() -> String:
	if world != null and world.has_method("get_current_profile_name"):
		return str(world.get_current_profile_name()).strip_edges()

	return ""


func get_current_player_save_path() -> String:
	ensure_player_save_folder()
	return PLAYER_SAVE_FOLDER + sanitize_player_name_for_path(get_current_player_profile_name()) + ".json"


func get_legacy_server_inventory_import_marker_path() -> String:
	ensure_player_save_folder()
	return LEGACY_SERVER_INVENTORY_IMPORT_MARKER_PREFIX + str(LEGACY_SERVER_INVENTORY_IMPORT_REVISION) + "_" + sanitize_player_name_for_path(get_current_player_profile_name()) + ".txt"


func mark_legacy_server_inventory_import_confirmed():
	var file = FileAccess.open(get_legacy_server_inventory_import_marker_path(), FileAccess.WRITE)

	if file == null:
		return

	file.store_string(Time.get_datetime_string_from_system())
	file.close()


func was_legacy_server_inventory_import_confirmed() -> bool:
	return FileAccess.file_exists(get_legacy_server_inventory_import_marker_path())


func is_registered_account_active() -> bool:
	if world != null and world.has_method("has_active_profile"):
		return bool(world.has_active_profile())

	return get_current_player_profile_name() != ""


func can_migrate_legacy_global_player_data() -> bool:
	return is_registered_account_active() and FileAccess.file_exists(world.PLAYER_SAVE_PATH) and not FileAccess.file_exists(LEGACY_PLAYER_MIGRATION_MARKER)


func mark_legacy_global_player_data_migrated():
	ensure_player_save_folder()
	var file = FileAccess.open(LEGACY_PLAYER_MIGRATION_MARKER, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(get_current_player_profile_name())
	file.close()


func set_gameplay_world_active(active: bool):
	if world.player != null:
		world.player.visible = active
		world.player.velocity = Vector2.ZERO
		world.player.set_physics_process(active and not world.noclip_enabled)

	for grid_pos in world.blocks.keys():
		var block_node = world.blocks[grid_pos]["node"]

		if is_instance_valid(block_node):
			block_node.visible = active

	var background_blocks = get_background_blocks_dictionary()

	for grid_pos in background_blocks.keys():
		var background_node = background_blocks[grid_pos].get("node", null)

		if background_node != null and is_instance_valid(background_node):
			background_node.visible = active

	for drop_data in world.dropped_items:
		var drop_node = drop_data["node"]

		if is_instance_valid(drop_node):
			drop_node.visible = active

	if world.seed_system != null and world.seed_system is CanvasItem:
		world.seed_system.visible = active


func is_popup_ui_node_name(node_name: String) -> bool:
	if node_name == "PlayerMenuUI":
		return true

	if node_name == "GameMenuUI":
		return true

	if node_name == "TradeUI":
		return true

	if node_name == "VendingUI":
		return true

	if node_name == "FishMongerUI":
		return true

	if node_name == "CraftingPanel":
		return true

	if node_name == "FurnacePanel":
		return true

	if node_name == "SignPanel":
		return true

	if node_name == "ShopPanel":
		return true

	if node_name == "ChatPanel":
		return true

	if node_name == "ChatWindow":
		return true

	if node_name == "InventoryWindow":
		return true

	if node_name == "ItemContextMenu":
		return true

	if node_name == "WorldMenuOverlay":
		return true

	if node_name == "GameMenuOverlay":
		return true

	if node_name.contains("Panel") and node_name != "InventoryLabel":
		return true

	if node_name.contains("Overlay"):
		return true

	return false


func set_gameplay_ui_visible(active: bool):
	if world.ui_layer == null:
		return

	for child in world.ui_layer.get_children():
		# Keep the world menu controller alive, but do not force its overlay visible.
		if child.name == "WorldMenuUI":
			child.visible = true
			continue

		if child.name == "ChatUI":
			child.visible = active
			continue

		if child.name == "WorldMenuOverlay":
			if active:
				child.visible = false
			else:
				child.visible = true
			continue

		# When entering a world, only show normal HUD/buttons.
		# Do not force popups open.
		if active:
			if is_popup_ui_node_name(str(child.name)):
				child.visible = false
			else:
				child.visible = true
		else:
			child.visible = false


func close_all_gameplay_popups():
	world.close_chat_panel()
	world.close_shop()
	if world.has_method("close_vending_ui"):
		world.close_vending_ui()
	if world.has_method("close_safe_ui"):
		world.close_safe_ui()
	if world.has_method("close_fish_monger_ui"):
		world.close_fish_monger_ui()
	world.close_crafting()
	world.close_furnace()
	world.close_sign()
	world.close_inventory_window()
	world.close_player_menu()
	if world.has_method("close_game_menu"):
		world.close_game_menu()
	if world.has_method("close_trade_ui"):
		world.close_trade_ui()

func notify_network_join_current_world():
	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_join_world"):
		var sent = bool(network.send_join_world(world.current_world_name))
		if not sent and network.has_method("set_pending_join"):
			network.set_pending_join(world.current_world_name, get_current_player_profile_name())

	if world.player_manager != null and world.player_manager.has_method("reset_multiplayer_sync_state"):
		world.player_manager.reset_multiplayer_sync_state()


func retry_server_world_entry(reason: String = "world_state_timeout") -> bool:
	if world == null or not waiting_for_server_world_state:
		return false
	if bool(world.get("applying_network_world_update")):
		return false

	var target_world: String = sanitize_world_name(str(world.current_world_name))
	if target_world == "":
		return false
	target_world = target_world.to_upper()

	world.set_meta("world_entry_in_progress", true)
	world.set_meta("world_bulk_load_in_progress", true)
	world.set_meta("world_bulk_load_reason", "waiting_for_server_world_state")
	set_gameplay_world_active(false)
	set_gameplay_ui_visible(false)
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Still loading " + target_world + " from server...")

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	if network.has_method("has_active_join_request_for_world"):
		if bool(network.has_active_join_request_for_world(target_world)) and network.has_method("cancel_active_join_request"):
			network.cancel_active_join_request()
	if network.has_method("set_pending_join"):
		network.set_pending_join(target_world, get_current_player_profile_name())

	var sent := false
	if network.has_method("is_server_session_authenticated") and bool(network.is_server_session_authenticated()):
		if network.has_method("send_join_world"):
			sent = bool(network.send_join_world(target_world))
	if not sent and network.has_method("request_server_connection"):
		network.request_server_connection(false)

	debug_action_position_flow("retry_server_world_entry", {
		"world": target_world,
		"reason": reason,
		"sent": sent
	})
	return sent


func handle_server_world_entry_rejected(data: Dictionary) -> bool:
	if world == null or not waiting_for_server_world_state:
		return false

	var reason: String = str(data.get("reason", "")).strip_edges().to_lower()
	var message: String = str(data.get("message", "Could not enter that world.")).strip_edges()
	if reason.ends_with("_failed") or message.to_lower().contains("still loading"):
		if world.has_method("update_smooth_world_load_message"):
			world.update_smooth_world_load_message(message + " Retrying...")
		return true

	return handle_client_world_loading_failed(reason, message)


func handle_client_world_loading_failed(reason: String, message: String) -> bool:
	if world == null:
		return false

	var clean_reason := str(reason).strip_edges()
	if clean_reason == "":
		clean_reason = "client_world_loading_failed"
	var clean_message := str(message).strip_edges()
	if clean_message == "":
		clean_message = "Could not load the world. Returning to the lobby."

	debug_action_position_flow("handle_client_world_loading_failed", {
		"reason": clean_reason,
		"world": str(world.current_world_name)
	})

	waiting_for_server_world_state = false
	world_entry_pending_announce = false
	world.set_meta("world_entry_in_progress", false)
	world.set_meta("world_entry_force_entrance_spawn", false)
	world.set_meta("world_bulk_load_in_progress", false)
	world.set_meta("world_bulk_load_reason", "")
	world.in_world = false
	set_gameplay_world_active(false)
	set_gameplay_ui_visible(false)

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("cancel_active_join_request"):
		network.cancel_active_join_request()

	if world.has_method("cancel_smooth_world_load"):
		world.cancel_smooth_world_load()

	if world.world_menu_ui != null and world.world_menu_ui.has_method("return_to_lobby_menu"):
		world.world_menu_ui.call_deferred("return_to_lobby_menu", false)
	elif world.world_menu_ui != null and world.world_menu_ui.has_method("open_main_menu"):
		world.world_menu_ui.call_deferred("open_main_menu")

	if world.has_method("show_notification"):
		world.call_deferred("show_notification", clean_message)
	return true

func notify_network_leave_world(world_name: String):
	if world_name.strip_edges() == "":
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_leave_world"):
		network.send_leave_world(world_name)

	if world.has_method("clear_remote_players"):
		world.clear_remote_players()

	if world.player_manager != null and world.player_manager.has_method("reset_multiplayer_sync_state"):
		world.player_manager.reset_multiplayer_sync_state()


func exit_to_main_menu(save_current_world: bool = true):
	var previous_world_name = world.current_world_name

	if save_current_world and world.in_world:
		save_world()

	waiting_for_server_world_state = false
	world_entry_pending_announce = false

	if world.has_method("cancel_smooth_world_load"):
		world.cancel_smooth_world_load()

	if world.in_world:
		notify_network_leave_world(previous_world_name)

	world.close_chat_panel()
	world.close_shop()
	if world.has_method("close_fish_monger_ui"):
		world.close_fish_monger_ui()
	world.close_crafting()
	world.close_furnace()
	world.close_inventory_window()
	world.close_player_menu()
	if world.has_method("close_game_menu"):
		world.close_game_menu()
	if world.has_method("close_trade_ui"):
		world.close_trade_ui()

	world.in_world = false
	clear_world()
	set_gameplay_world_active(false)
	set_gameplay_ui_visible(false)

	if world.world_menu_ui != null and world.world_menu_ui.has_method("open_main_menu"):
		world.world_menu_ui.open_main_menu()
	elif world.world_menu_ui != null and world.world_menu_ui.has_method("open_menu"):
		world.world_menu_ui.open_menu("", true)


func exit_to_world_menu():
	if world.world_menu_ui != null and world.world_menu_ui.has_method("return_to_lobby_menu"):
		world.world_menu_ui.return_to_lobby_menu(true)
		return

	exit_to_main_menu(true)


func resume_current_world():
	if not world.in_world:
		if world.world_menu_ui != null and world.world_menu_ui.has_method("open_main_menu"):
			world.world_menu_ui.open_main_menu()
		return

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()

	set_gameplay_ui_visible(true)

	if world.player != null and not world.noclip_enabled:
		world.player.visible = true
		world.player.set_physics_process(true)


func enter_world_by_name(raw_name: String):
	var sanitized_name = sanitize_world_name(raw_name)
	debug_action_position_flow("enter_world_by_name start", {
		"raw_name": raw_name,
		"sanitized_name": sanitized_name
	})

	if sanitized_name == "":
		sanitized_name = world.DEFAULT_WORLD_NAME.to_lower()

	if world.in_world:
		var previous_world_name = world.current_world_name
		save_world()
		if previous_world_name.strip_edges().to_upper() != sanitized_name.to_upper():
			notify_network_leave_world(previous_world_name)
	else:
		if world.has_method("clear_remote_players"):
			world.clear_remote_players()

	world.current_world_name = sanitized_name.to_upper()
	world.in_world = true
	world.set_meta("world_entry_in_progress", true)
	waiting_for_server_world_state = should_expect_server_world_state()
	world_entry_pending_announce = true
	debug_action_position_flow("enter_world_by_name waiting state", {
		"waiting_for_server_world_state": waiting_for_server_world_state
	})

	clear_world()
	set_gameplay_ui_visible(false)
	set_gameplay_world_active(false)

	if world.has_method("begin_smooth_world_load"):
		world.begin_smooth_world_load(world.current_world_name, waiting_for_server_world_state)

	if waiting_for_server_world_state and world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + world.current_world_name + " from server...")

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()

	var network = world.get_node_or_null("/root/NetworkManager")
	if waiting_for_server_world_state and network != null and network.has_method("request_server_connection"):
		network.request_server_connection(true)

	load_world()

	if waiting_for_server_world_state:
		set_gameplay_world_active(false)
		if should_use_server_world_state():
			notify_network_join_current_world()
		return

	notify_network_join_current_world()
	finish_world_entry_after_load(true, true)


func finish_world_entry_after_load(save_after_finish: bool = true, announce_enter: bool = true):
	debug_action_position_flow("finish_world_entry_after_load start", {
		"save_after_finish": save_after_finish,
		"announce_enter": announce_enter,
		"was_waiting_for_server_world_state": waiting_for_server_world_state
	})
	waiting_for_server_world_state = false
	world.set_meta("world_entry_in_progress", false)

	set_gameplay_world_active(true)
	close_all_gameplay_popups()
	set_gameplay_ui_visible(true)

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()

	if world.player != null and not world.noclip_enabled:
		world.player.visible = true
		world.player.set_physics_process(true)

	world.restore_chat_ui_after_world_enter()
	world.setup_world_camera_limits()
	world.set_default_camera_zoom_silent()
	world.clamp_player_to_world()
	world.update_equipment_visual()
	world.update_all_ui()

	if world.has_method("finish_smooth_world_load"):
		world.finish_smooth_world_load()

	if announce_enter and world_entry_pending_announce:
		world.show_notification("Entered world: " + world.current_world_name)
		_send_world_entry_chat_message()

	world_entry_pending_announce = false

	if save_after_finish:
		save_world()

	debug_action_position_flow("finish_world_entry_after_load end", {
		"save_after_finish": save_after_finish,
		"announce_enter": announce_enter
	})



func _send_world_entry_chat_message():
	var world_name = world.current_world_name

	var owner_text = "No Owner"
	if world.world_lock_manager != null:
		var wlm = world.world_lock_manager
		if wlm.is_locked and wlm.owner_name != "":
			owner_text = wlm.owner_name

	# Players = 1 for now, ready for multiplayer
	var player_count = 1

	var msg = "World: %s  |  Owner: %s  |  Players: %d" % [world_name, owner_text, player_count]

	if world.chat_ui != null and world.chat_ui.has_method("add_chat_message"):
		world.chat_ui.add_chat_message("System", msg)


func get_player_save_data() -> Dictionary:
	return {
		"player_data_version": world.PLAYER_DATA_VERSION,
		"account_username": get_current_player_profile_name(),
		"selected_item_type": world.selected_item_type,
		"selected_item_category": world.selected_item_category,
		"primary_hotbar_tool": world.primary_hotbar_tool,
		"hotbar_items": world.hotbar_items,
		"hotbar_item_categories": world.hotbar_item_categories,
		"player_level": _safe_int(world.player_level, 1, 1, MAX_PLAYER_LEVEL),
		"player_xp": _safe_int(world.player_xp, 0, 0),
		"player_xp_needed": _safe_int(world.player_xp_needed, 300, 0),
		"player_total_xp": _safe_int(world.player_total_xp, 0, 0),
		"player_title": _safe_string(world.player_title, "Explorer", MAX_INVENTORY_STRING_LEN),
		"player_health": world.player_health,
		"inventory": world.inventory,
		"seed_inventory": world.seed_inventory,
		"tool_inventory": world.tool_inventory,
		"back_inventory": world.back_inventory,
		"hair_inventory": world.hair_inventory,
		"shirt_inventory": world.shirt_inventory,
		"pants_inventory": world.pants_inventory,
		"shoes_inventory": world.shoes_inventory,
		"currency_inventory": world.currency_inventory,
		"material_inventory": world.material_inventory,
		"lure_inventory": world.lure_inventory,
		"fish_inventory": world.fish_inventory,
		"fishing_records": world.fishing_manager.get_fishing_records_save_data() if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_records_save_data") else {},
		"equipped_tool": str(world.equipped_tool) if world.equipped_tool != null else "",
		"equipped_back_item": str(world.equipped_back_item) if world.equipped_back_item != null else "",
		"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
		"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
		"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
		"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else ""
	}


func save_player_data(sync_to_server: bool = true):
	var player_data = get_player_save_data()

	var file = FileAccess.open(get_current_player_save_path(), FileAccess.WRITE)

	if file == null:
		print("Could not save player data.")
		return

	file.store_string(JSON.stringify(player_data))
	file.close()

	if sync_to_server and not loading_player_data and not applying_server_player_data:
		notify_network_player_state_save(player_data)


func notify_network_player_state_save(player_data: Dictionary):
	if not is_registered_account_active():
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_player_state_save"):
		network.send_player_state_save(player_data)


func load_current_player_save_dictionary() -> Dictionary:
	return load_json_dictionary_from_path(get_current_player_save_path())


func load_json_dictionary_from_path(save_path: String) -> Dictionary:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)
	if data is Dictionary:
		return data

	return {}


func add_legacy_player_data_candidate(candidates: Array, seen_paths: Dictionary, save_path: String) -> void:
	if save_path == "" or seen_paths.has(save_path):
		return

	seen_paths[save_path] = true
	var data = load_json_dictionary_from_path(save_path)

	if data.is_empty():
		return

	candidates.append(data)


func get_legacy_player_data_candidates(preferred_player_data: Dictionary = {}) -> Array:
	var candidates = []
	var seen_paths = {}

	if not preferred_player_data.is_empty():
		candidates.append(preferred_player_data)

	add_legacy_player_data_candidate(candidates, seen_paths, get_current_player_save_path())

	if world == null:
		return candidates

	add_legacy_player_data_candidate(candidates, seen_paths, world.PLAYER_SAVE_PATH)
	add_legacy_player_data_candidate(candidates, seen_paths, get_world_save_path_for_name(get_current_player_profile_name()))
	add_legacy_player_data_candidate(candidates, seen_paths, get_world_save_path_for_name(world.DEFAULT_WORLD_NAME))

	if str(world.current_world_name).strip_edges() != "":
		add_legacy_player_data_candidate(candidates, seen_paths, get_world_save_path_for_name(world.current_world_name))

	return candidates


func merge_legacy_inventory_counts(target_data: Dictionary, source_data: Dictionary) -> void:
	for inventory_key in PLAYER_INVENTORY_SAVE_KEYS:
		var source_inventory = source_data.get(inventory_key, {})

		if not (source_inventory is Dictionary):
			continue

		var target_inventory = target_data.get(inventory_key, {})

		if not (target_inventory is Dictionary):
			target_inventory = {}

		for item_name in source_inventory.keys():
			if inventory_key == "fish_inventory":
				var source_weight: float = safe_fish_weight_from_save(source_inventory.get(item_name, 0.0))
				var target_weight: float = safe_fish_weight_from_save(target_inventory.get(item_name, 0.0))
				if source_weight > target_weight:
					target_inventory[item_name] = source_weight
				continue

			var source_count = int(source_inventory.get(item_name, 0))
			var target_count = int(target_inventory.get(item_name, 0))

			if source_count > target_count:
				target_inventory[item_name] = source_count

		target_data[inventory_key] = target_inventory


func fill_missing_legacy_loadout_data(target_data: Dictionary, source_data: Dictionary) -> void:
	for loadout_key in PLAYER_LOADOUT_SAVE_KEYS:
		if str(target_data.get(loadout_key, "")).strip_edges() == "" and str(source_data.get(loadout_key, "")).strip_edges() != "":
			target_data[loadout_key] = source_data.get(loadout_key)

	if not (target_data.get("hotbar_items", []) is Array) or target_data.get("hotbar_items", []).is_empty():
		if source_data.get("hotbar_items", []) is Array:
			target_data["hotbar_items"] = source_data.get("hotbar_items", []).duplicate(true)

	if not (target_data.get("hotbar_item_categories", []) is Array) or target_data.get("hotbar_item_categories", []).is_empty():
		if source_data.get("hotbar_item_categories", []) is Array:
			target_data["hotbar_item_categories"] = source_data.get("hotbar_item_categories", []).duplicate(true)


func build_legacy_server_inventory_import_data(preferred_player_data: Dictionary = {}) -> Dictionary:
	var candidates = get_legacy_player_data_candidates(preferred_player_data)
	var import_data = {}

	for candidate in candidates:
		if not (candidate is Dictionary):
			continue

		if import_data.is_empty():
			import_data = candidate.duplicate(true)
		else:
			merge_legacy_inventory_counts(import_data, candidate)
			fill_missing_legacy_loadout_data(import_data, candidate)

	if not import_data.is_empty() and str(import_data.get("account_username", "")).strip_edges() == "":
		import_data["account_username"] = get_current_player_profile_name()

	return import_data


func try_send_legacy_server_inventory_import(player_data: Dictionary = {}) -> bool:
	if legacy_server_inventory_import_in_flight:
		return true

	if not is_registered_account_active():
		return false

	if was_legacy_server_inventory_import_confirmed():
		return false

	if legacy_server_inventory_import_attempts >= LEGACY_SERVER_INVENTORY_IMPORT_MAX_ATTEMPTS:
		return false

	var import_player_data = build_legacy_server_inventory_import_data(player_data)

	if not has_useful_player_data(import_player_data):
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_state_save"):
		return false

	var sent = bool(network.send_player_state_save(import_player_data, {
		"legacy_client_inventory_import": true,
		"legacy_client_inventory_import_revision": LEGACY_SERVER_INVENTORY_IMPORT_REVISION
	}))

	if not sent:
		return false

	legacy_server_inventory_import_in_flight = true
	legacy_server_inventory_import_attempts += 1
	_request_network_player_state_after_legacy_import()
	return true


func _request_network_player_state_after_legacy_import() -> void:
	await get_tree().create_timer(0.35).timeout
	legacy_server_inventory_import_in_flight = false
	request_network_player_state()


func request_network_player_state():
	if not is_registered_account_active():
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	if network.has_method("send_account_state_save"):
		var email = ""
		if world.has_method("get_current_profile_email"):
			email = str(world.get_current_profile_email())
		network.send_account_state_save(get_current_player_profile_name(), email)

	if try_send_legacy_server_inventory_import():
		return

	if network.has_method("send_player_state_request"):
		network.send_player_state_request(get_current_player_profile_name())


func load_player_data():
	loading_player_data = true
	var player_save_path = get_current_player_save_path()

	if FileAccess.file_exists(player_save_path):
		var file = FileAccess.open(player_save_path, FileAccess.READ)

		if file != null:
			var json_text = file.get_as_text()
			file.close()

			var data = JSON.parse_string(json_text)

			if data is Dictionary:
				apply_player_data(data)
				world.player_data_loaded_from_file = true
				loading_player_data = false
				request_network_player_state()
				return

	if can_migrate_legacy_global_player_data():
		var file = FileAccess.open(world.PLAYER_SAVE_PATH, FileAccess.READ)

		if file != null:
			var json_text = file.get_as_text()
			file.close()

			var data = JSON.parse_string(json_text)

			if data is Dictionary:
				apply_player_data(data)
				world.player_data_loaded_from_file = true
				save_player_data()
				mark_legacy_global_player_data_migrated()
				print("Migrated global player data to account: " + get_current_player_profile_name())
				loading_player_data = false
				request_network_player_state()
				return

	if not is_registered_account_active():
		var legacy_data = load_legacy_player_data_from_world_name(world.DEFAULT_WORLD_NAME)

		if legacy_data is Dictionary and has_useful_player_data(legacy_data):
			apply_player_data(legacy_data)
			world.player_data_loaded_from_file = true
			save_player_data()
			print("Migrated player data from START world save.")
			loading_player_data = false
			request_network_player_state()
			return

	reset_player_data_to_defaults()
	world.player_data_loaded_from_file = false
	save_player_data()
	loading_player_data = false
	request_network_player_state()


func load_player_data_from_current_or_legacy(world_data: Dictionary):
	if is_registered_account_active():
		load_player_data()
		return

	if FileAccess.file_exists(get_current_player_save_path()):
		load_player_data()
		return

	if world.player_data_loaded_from_file:
		return

	# If there is no global player file yet, migrate from the current old world save if it has useful player data.
	if has_useful_player_data(world_data):
		apply_player_data(world_data)
		world.player_data_loaded_from_file = true
		save_player_data()
		print("Migrated player data from current world save.")
		return


func load_legacy_player_data_from_world_name(world_name: String) -> Dictionary:
	var world_save_path = get_world_save_path_for_name(world_name)

	if not FileAccess.file_exists(world_save_path):
		return {}

	var file = FileAccess.open(world_save_path, FileAccess.READ)

	if file == null:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)

	if data is Dictionary:
		return data

	return {}


func has_useful_player_data(data: Dictionary) -> bool:
	if str(data.get("equipped_tool", "")) != "":
		return true

	if str(data.get("equipped_back_item", "")) != "":
		return true

	if str(data.get("equipped_hair_item", "")) != "":
		return true

	if str(data.get("equipped_shirt_item", "")) != "":
		return true

	if str(data.get("equipped_pants_item", "")) != "":
		return true

	if str(data.get("equipped_shoes_item", "")) != "":
		return true

	for inventory_key in PLAYER_INVENTORY_SAVE_KEYS:
		var saved_inventory = data.get(inventory_key, {})

		if not (saved_inventory is Dictionary):
			continue

		for item_name in saved_inventory.keys():
			if _safe_int(saved_inventory.get(item_name, 0), 0, 0, MAX_INVENTORY_STACK) > 0:
				return true

	return false


func reset_player_data_to_defaults():
	world.selected_item_type = "punch"
	world.selected_item_category = "tool"
	world.primary_hotbar_tool = "punch"
	world.hotbar_items = ["punch", "dirt", "grass", "stone", "wood", "leaf"]
	world.hotbar_item_categories = ["tool", "block", "block", "block", "block", "block"]
	world.player_level = 1
	world.player_xp = 0
	world.player_xp_needed = 300
	world.player_total_xp = 0
	world.player_title = "Explorer"
	world.player_health = 10
	world.equipped_tool = ""
	world.equipped_back_item = ""
	world.equipped_hair_item = ""
	world.equipped_shirt_item = ""
	world.equipped_pants_item = ""
	world.equipped_shoes_item = ""

	world.inventory.clear()
	world.seed_inventory.clear()
	world.tool_inventory.clear()
	world.back_inventory.clear()
	world.hair_inventory.clear()
	world.shirt_inventory.clear()
	world.pants_inventory.clear()
	world.shoes_inventory.clear()
	world.currency_inventory.clear()
	world.material_inventory.clear()
	world.lure_inventory.clear()
	world.fish_inventory.clear()
	if world.fishing_manager != null and world.fishing_manager.has_method("reset_fishing_records"):
		world.fishing_manager.reset_fishing_records()

	for item_id in world.item_database.keys():
		var item_data = world.item_database[item_id]
		var category = str(item_data.get("category", ""))
		var starting_count = int(item_data.get("starting_count", 0))

		match category:
			"block":
				world.inventory[item_id] = 0
			"seed":
				world.seed_inventory[item_id] = 0
			"tool":
				world.tool_inventory[item_id] = starting_count
			"back":
				world.back_inventory[item_id] = starting_count
			"hair":
				world.hair_inventory[item_id] = starting_count
			"shirt":
				world.shirt_inventory[item_id] = starting_count
			"pants":
				world.pants_inventory[item_id] = starting_count
			"shoes":
				world.shoes_inventory[item_id] = starting_count
			"currency":
				if world.has_method("clamp_item_stack_count"):
					world.currency_inventory[item_id] = world.clamp_item_stack_count(item_id, category, starting_count)
				else:
					world.currency_inventory[item_id] = min(starting_count, MAX_INVENTORY_STACK)
			"material":
				world.material_inventory[item_id] = starting_count
			"lure":
				world.lure_inventory[item_id] = starting_count
			"fish":
				world.fish_inventory[item_id] = starting_count

	world.normalize_hotbar()
	world.setup_hotbar()
	world.update_equipment_visual()
	world.update_all_ui()


func apply_player_data(data: Dictionary):
	world.selected_item_type = _safe_string(data.get("selected_item_type", data.get("selected_block_type", world.selected_item_type)), world.selected_item_type, MAX_INVENTORY_STRING_LEN)
	world.selected_item_category = _safe_string(data.get("selected_item_category", world.selected_item_category), world.selected_item_category, MAX_INVENTORY_STRING_LEN)
	world.primary_hotbar_tool = _safe_string(data.get("primary_hotbar_tool", world.primary_hotbar_tool), world.primary_hotbar_tool, MAX_INVENTORY_STRING_LEN)

	if world.primary_hotbar_tool != "punch" and world.primary_hotbar_tool != "wrench":
		world.primary_hotbar_tool = "punch"

	var saved_hotbar_items = data.get("hotbar_items", [])
	var saved_hotbar_categories = data.get("hotbar_item_categories", [])

	if saved_hotbar_items is Array and saved_hotbar_categories is Array and saved_hotbar_items.size() > 0:
		world.hotbar_items.clear()
		world.hotbar_item_categories.clear()

		for i in range(min(saved_hotbar_items.size(), saved_hotbar_categories.size())):
			world.hotbar_items.append(_safe_string(saved_hotbar_items[i], "", MAX_INVENTORY_STRING_LEN))
			world.hotbar_item_categories.append(_safe_string(saved_hotbar_categories[i], "", MAX_INVENTORY_STRING_LEN))
	else:
		var quick_item_type = _safe_string(data.get("quick_hotbar_item_type", world.hotbar_items[1] if world.hotbar_items.size() > 1 else ""), "", MAX_INVENTORY_STRING_LEN)
		var quick_item_category = _safe_string(data.get("quick_hotbar_item_category", world.hotbar_item_categories[1] if world.hotbar_item_categories.size() > 1 else "empty"), "empty", MAX_INVENTORY_STRING_LEN)

		if quick_item_type != "" and (quick_item_category == "block" or quick_item_category == "seed"):
			world.hotbar_items = ["punch", quick_item_type, "grass", "stone", "wood", "leaf"]
			world.hotbar_item_categories = ["tool", quick_item_category, "block", "block", "block", "block"]

	world.normalize_hotbar()
	world.setup_hotbar()

	world.player_level = _safe_int(data.get("player_level", data.get("level", world.player_level)), world.player_level, 1, MAX_PLAYER_LEVEL)
	world.player_xp = _safe_int(data.get("player_xp", data.get("xp", world.player_xp)), world.player_xp, 0)
	world.player_xp_needed = _safe_int(data.get("player_xp_needed", data.get("xp_needed", world.player_xp_needed)), world.player_xp_needed, 0)
	world.player_total_xp = _safe_int(data.get("player_total_xp", data.get("total_xp", world.player_total_xp)), world.player_total_xp, 0)
	world.player_title = _safe_string(data.get("player_title", world.player_title), "Explorer", MAX_INVENTORY_STRING_LEN)
	world.player_health = _safe_int(data.get("player_health", world.player_health), world.player_health, 0, MAX_PLAYER_HEALTH)

	apply_saved_inventory_counts(world.inventory, data.get("inventory", {}), false)
	apply_saved_inventory_counts(world.seed_inventory, data.get("seed_inventory", {}), false)
	apply_saved_inventory_counts(world.tool_inventory, data.get("tool_inventory", {}), true)
	apply_saved_inventory_counts(world.back_inventory, data.get("back_inventory", {}), true)
	apply_saved_inventory_counts(world.hair_inventory, data.get("hair_inventory", {}), true)
	apply_saved_inventory_counts(world.shirt_inventory, data.get("shirt_inventory", {}), true)
	apply_saved_inventory_counts(world.pants_inventory, data.get("pants_inventory", {}), true)
	apply_saved_inventory_counts(world.shoes_inventory, data.get("shoes_inventory", {}), true)
	apply_saved_inventory_counts(world.currency_inventory, data.get("currency_inventory", {}), true)
	apply_saved_inventory_counts(world.material_inventory, data.get("material_inventory", {}), true)
	apply_saved_inventory_counts(world.lure_inventory, data.get("lure_inventory", {}), true)
	apply_saved_fish_weight_inventory(data.get("fish_inventory", {}), true)
	if world.fishing_manager != null and world.fishing_manager.has_method("apply_fishing_records"):
		var fishing_records_data = data.get("fishing_records", {})
		var fishing_records_dictionary: Dictionary = (fishing_records_data as Dictionary) if fishing_records_data is Dictionary else {}
		world.fishing_manager.apply_fishing_records(fishing_records_dictionary)

	var loaded_equipped_tool = data.get("equipped_tool", world.equipped_tool)

	if loaded_equipped_tool == null:
		loaded_equipped_tool = ""

	world.equipped_tool = _safe_string(loaded_equipped_tool, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_tool != "" and (not world.tool_inventory.has(world.equipped_tool) or _safe_int(world.tool_inventory[world.equipped_tool], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_tool = ""

	var loaded_equipped_back_item = data.get("equipped_back_item", world.equipped_back_item)

	if loaded_equipped_back_item == null:
		loaded_equipped_back_item = ""

	world.equipped_back_item = _safe_string(loaded_equipped_back_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_back_item != "" and (not world.back_inventory.has(world.equipped_back_item) or _safe_int(world.back_inventory[world.equipped_back_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_back_item = ""

	var loaded_equipped_hair_item = data.get("equipped_hair_item", world.equipped_hair_item)

	if loaded_equipped_hair_item == null:
		loaded_equipped_hair_item = ""

	world.equipped_hair_item = _safe_string(loaded_equipped_hair_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hair_item != "" and (not world.hair_inventory.has(world.equipped_hair_item) or _safe_int(world.hair_inventory[world.equipped_hair_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hair_item = ""

	var loaded_equipped_shirt_item = data.get("equipped_shirt_item", world.equipped_shirt_item)

	if loaded_equipped_shirt_item == null:
		loaded_equipped_shirt_item = ""

	world.equipped_shirt_item = _safe_string(loaded_equipped_shirt_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_shirt_item != "" and (not world.shirt_inventory.has(world.equipped_shirt_item) or _safe_int(world.shirt_inventory[world.equipped_shirt_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_shirt_item = ""

	var loaded_equipped_pants_item = data.get("equipped_pants_item", world.equipped_pants_item)

	if loaded_equipped_pants_item == null:
		loaded_equipped_pants_item = ""

	world.equipped_pants_item = _safe_string(loaded_equipped_pants_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_pants_item != "" and (not world.pants_inventory.has(world.equipped_pants_item) or _safe_int(world.pants_inventory[world.equipped_pants_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_pants_item = ""

	var loaded_equipped_shoes_item = data.get("equipped_shoes_item", world.equipped_shoes_item)

	if loaded_equipped_shoes_item == null:
		loaded_equipped_shoes_item = ""

	world.equipped_shoes_item = _safe_string(loaded_equipped_shoes_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_shoes_item != "" and (not world.shoes_inventory.has(world.equipped_shoes_item) or _safe_int(world.shoes_inventory[world.equipped_shoes_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_shoes_item = ""

	world.update_equipment_visual()
	world.update_all_ui()


func can_restore_local_loadout_item(item_type: String, category: String) -> bool:
	if item_type == "":
		return false

	if category == "tool" and (item_type == "punch" or item_type == "wrench"):
		return true

	if world == null or not world.has_method("get_item_count"):
		return false

	return int(world.get_item_count(item_type, category)) > 0


func restore_local_transaction_loadout(snapshot: Dictionary):
	if world == null:
		return

	var previous_primary_tool = str(snapshot.get("primary_hotbar_tool", "punch"))
	if previous_primary_tool == "punch" or previous_primary_tool == "wrench":
		world.primary_hotbar_tool = previous_primary_tool

	var previous_hotbar_items = snapshot.get("hotbar_items", [])
	var previous_hotbar_categories = snapshot.get("hotbar_item_categories", [])
	if previous_hotbar_items is Array and previous_hotbar_categories is Array and previous_hotbar_items.size() > 0:
		world.hotbar_items = previous_hotbar_items.duplicate(true)
		world.hotbar_item_categories = previous_hotbar_categories.duplicate(true)
		world.normalize_hotbar()
		world.setup_hotbar()

	var previous_selected_type = str(snapshot.get("selected_item_type", world.selected_item_type))
	var previous_selected_category = str(snapshot.get("selected_item_category", world.selected_item_category))
	if can_restore_local_loadout_item(previous_selected_type, previous_selected_category):
		world.selected_item_type = previous_selected_type
		world.selected_item_category = previous_selected_category

	var previous_equipped_tool = str(snapshot.get("equipped_tool", ""))
	if previous_equipped_tool == "" or can_restore_local_loadout_item(previous_equipped_tool, "tool"):
		world.equipped_tool = previous_equipped_tool

	var previous_back_item = str(snapshot.get("equipped_back_item", ""))
	if previous_back_item == "" or can_restore_local_loadout_item(previous_back_item, "back"):
		world.equipped_back_item = previous_back_item

	var previous_hair_item = str(snapshot.get("equipped_hair_item", ""))
	if previous_hair_item == "" or can_restore_local_loadout_item(previous_hair_item, "hair"):
		world.equipped_hair_item = previous_hair_item

	var previous_shirt_item = str(snapshot.get("equipped_shirt_item", ""))
	if previous_shirt_item == "" or can_restore_local_loadout_item(previous_shirt_item, "shirt"):
		world.equipped_shirt_item = previous_shirt_item

	var previous_pants_item = str(snapshot.get("equipped_pants_item", ""))
	if previous_pants_item == "" or can_restore_local_loadout_item(previous_pants_item, "pants"):
		world.equipped_pants_item = previous_pants_item

	var previous_shoes_item = str(snapshot.get("equipped_shoes_item", ""))
	if previous_shoes_item == "" or can_restore_local_loadout_item(previous_shoes_item, "shoes"):
		world.equipped_shoes_item = previous_shoes_item

	world.update_equipment_visual()
	world.update_all_ui()


func apply_network_player_state(data: Dictionary):
	if data.has("found") and not bool(data.get("found", true)):
		try_send_legacy_server_inventory_import()
		return

	var player_data = data.get("player_data", data)

	if not (player_data is Dictionary):
		return

	if player_data.is_empty():
		debug_action_position_flow("ignored empty network player state", {
			"type": str(data.get("type", "")),
			"username": str(data.get("username", ""))
		})
		return

	var server_username = str(data.get("username", player_data.get("account_username", ""))).strip_edges()
	var local_username = get_current_player_profile_name()

	if server_username != "" and local_username != "" and server_username.to_lower() != local_username.to_lower():
		return

	var normalized_username = server_username.to_lower()
	if normalized_username == "":
		normalized_username = local_username.to_lower()

	var payload_hash = get_player_data_dedup_hash(player_data)
	var now_ms = Time.get_ticks_msec()
	var current_local_hash = get_current_player_state_dedup_hash()
	if current_local_hash == payload_hash:
		last_server_player_state_username = normalized_username
		last_server_player_state_hash = payload_hash
		last_server_player_state_applied_ms = now_ms
		return

	if normalized_username == last_server_player_state_username and payload_hash == last_server_player_state_hash:
		if now_ms - last_server_player_state_applied_ms <= DUPLICATE_SERVER_PLAYER_STATE_WINDOW_MS:
			return

	if _safe_int(player_data.get("legacy_client_inventory_import_revision", 0), 0, 0, LEGACY_SERVER_INVENTORY_IMPORT_REVISION) >= LEGACY_SERVER_INVENTORY_IMPORT_REVISION:
		mark_legacy_server_inventory_import_confirmed()

	var preserve_local_loadout = bool(data.get("preserve_local_loadout", false))
	var local_loadout_snapshot = {}
	if preserve_local_loadout and world != null:
		local_loadout_snapshot = {
			"selected_item_type": world.selected_item_type,
			"selected_item_category": world.selected_item_category,
			"primary_hotbar_tool": world.primary_hotbar_tool,
			"hotbar_items": world.hotbar_items.duplicate(true),
			"hotbar_item_categories": world.hotbar_item_categories.duplicate(true),
			"equipped_tool": str(world.equipped_tool) if world.equipped_tool != null else "",
			"equipped_back_item": str(world.equipped_back_item) if world.equipped_back_item != null else "",
			"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
			"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
			"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
			"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else ""
		}

	applying_server_player_data = true
	apply_player_data(player_data)
	if preserve_local_loadout:
		restore_local_transaction_loadout(local_loadout_snapshot)
	world.player_data_loaded_from_file = true
	save_player_data(false)
	applying_server_player_data = false
	last_server_player_state_username = normalized_username
	last_server_player_state_hash = payload_hash
	last_server_player_state_applied_ms = now_ms

	debug_action_position_flow("applied network player state", {
		"username": (server_username if server_username != "" else local_username),
		"preserve_local_loadout": preserve_local_loadout
	})


func apply_saved_inventory_counts(target_inventory: Dictionary, saved_inventory, preserve_default_if_missing: bool):
	if not (saved_inventory is Dictionary):
		saved_inventory = {}

	for item_name in target_inventory.keys():
		if saved_inventory.has(item_name):
			var category = ""
			if world != null and world.item_database.has(item_name):
				category = str(world.item_database[item_name].get("category", ""))
			var amount_limit = get_inventory_count_limit(item_name, category)
			var safe_amount = _safe_int(saved_inventory.get(item_name, 0), 0, 0, amount_limit)
			if world != null and world.has_method("clamp_item_stack_count"):
				target_inventory[item_name] = world.clamp_item_stack_count(item_name, category, safe_amount)
			else:
				target_inventory[item_name] = safe_amount
		elif not preserve_default_if_missing:
			target_inventory[item_name] = 0


func safe_fish_weight_from_save(raw_value) -> float:
	if raw_value is Dictionary:
		if raw_value.has("weight_tenths"):
			return float(max(0, int(raw_value.get("weight_tenths", 0)))) / 10.0
		if raw_value.has("weight_lb"):
			raw_value = raw_value.get("weight_lb", 0.0)
		elif raw_value.has("amount"):
			raw_value = raw_value.get("amount", 0.0)
		else:
			return 0.0

	var value := 0.0
	if raw_value is int or raw_value is float:
		value = float(raw_value)
	elif raw_value is String:
		var text = raw_value.strip_edges()
		if text.is_valid_float():
			value = float(text)

	if not is_finite(value) or value <= 0.0:
		return 0.0
	return float(max(0, int(round(value * 10.0)))) / 10.0


func apply_saved_fish_weight_inventory(saved_inventory, _preserve_default_if_missing: bool):
	if not (saved_inventory is Dictionary):
		saved_inventory = {}

	world.fish_inventory.clear()

	for item_name in saved_inventory.keys():
		var clean_item_name: String = _safe_string(item_name, "", MAX_INVENTORY_STRING_LEN)
		if clean_item_name == "":
			continue
		var safe_weight: float = safe_fish_weight_from_save(saved_inventory.get(item_name, 0.0))
		if safe_weight > 0.0:
			world.fish_inventory[clean_item_name] = safe_weight


func get_player_data_dedup_hash(player_data: Dictionary) -> int:
	var normalized_payload := {
		"selected_item_type": _safe_string(player_data.get("selected_item_type", player_data.get("selected_block_type", "")), "", MAX_INVENTORY_STRING_LEN),
		"selected_item_category": _safe_string(player_data.get("selected_item_category", ""), "", MAX_INVENTORY_STRING_LEN),
		"primary_hotbar_tool": _safe_string(player_data.get("primary_hotbar_tool", ""), "", MAX_INVENTORY_STRING_LEN),
		"hotbar_items": player_data.get("hotbar_items", []) if player_data.get("hotbar_items", null) is Array else [],
		"hotbar_item_categories": player_data.get("hotbar_item_categories", []) if player_data.get("hotbar_item_categories", null) is Array else [],
		"quick_hotbar_item_type": _safe_string(player_data.get("quick_hotbar_item_type", ""), "", MAX_INVENTORY_STRING_LEN),
		"quick_hotbar_item_category": _safe_string(player_data.get("quick_hotbar_item_category", ""), "", MAX_INVENTORY_STRING_LEN),
		"player_level": _safe_int(player_data.get("player_level", player_data.get("level", 1)), 1, 1, MAX_PLAYER_LEVEL),
		"player_xp": _safe_int(player_data.get("player_xp", player_data.get("xp", 0)), 0, 0),
		"player_xp_needed": _safe_int(player_data.get("player_xp_needed", player_data.get("xp_needed", 300)), 300, 0),
		"player_total_xp": _safe_int(player_data.get("player_total_xp", player_data.get("total_xp", 0)), 0, 0),
		"player_title": _safe_string(player_data.get("player_title", "Explorer"), "Explorer", MAX_INVENTORY_STRING_LEN),
		"player_health": _safe_int(player_data.get("player_health", 0), 0, 0, MAX_PLAYER_HEALTH),
		"equipped_tool": _safe_string(player_data.get("equipped_tool", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_back_item": _safe_string(player_data.get("equipped_back_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_hair_item": _safe_string(player_data.get("equipped_hair_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_shirt_item": _safe_string(player_data.get("equipped_shirt_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_pants_item": _safe_string(player_data.get("equipped_pants_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_shoes_item": _safe_string(player_data.get("equipped_shoes_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"inventory": player_data.get("inventory", {}) if player_data.get("inventory", null) is Dictionary else {},
		"seed_inventory": player_data.get("seed_inventory", {}) if player_data.get("seed_inventory", null) is Dictionary else {},
		"tool_inventory": player_data.get("tool_inventory", {}) if player_data.get("tool_inventory", null) is Dictionary else {},
		"back_inventory": player_data.get("back_inventory", {}) if player_data.get("back_inventory", null) is Dictionary else {},
		"hair_inventory": player_data.get("hair_inventory", {}) if player_data.get("hair_inventory", null) is Dictionary else {},
		"shirt_inventory": player_data.get("shirt_inventory", {}) if player_data.get("shirt_inventory", null) is Dictionary else {},
		"pants_inventory": player_data.get("pants_inventory", {}) if player_data.get("pants_inventory", null) is Dictionary else {},
		"shoes_inventory": player_data.get("shoes_inventory", {}) if player_data.get("shoes_inventory", null) is Dictionary else {},
		"currency_inventory": player_data.get("currency_inventory", {}) if player_data.get("currency_inventory", null) is Dictionary else {},
		"material_inventory": player_data.get("material_inventory", {}) if player_data.get("material_inventory", null) is Dictionary else {},
		"lure_inventory": player_data.get("lure_inventory", {}) if player_data.get("lure_inventory", null) is Dictionary else {},
		"fish_inventory": player_data.get("fish_inventory", {}) if player_data.get("fish_inventory", null) is Dictionary else {},
		"fishing_records": player_data.get("fishing_records", {}) if player_data.get("fishing_records", null) is Dictionary else {}
	}
	return hash(normalized_payload)


func get_current_player_state_dedup_hash() -> int:
	if world == null:
		return -1

	var normalized_payload := {
		"selected_item_type": _safe_string(world.selected_item_type, "", MAX_INVENTORY_STRING_LEN),
		"selected_item_category": _safe_string(world.selected_item_category, "", MAX_INVENTORY_STRING_LEN),
		"primary_hotbar_tool": _safe_string(world.primary_hotbar_tool, "", MAX_INVENTORY_STRING_LEN),
		"hotbar_items": world.hotbar_items.duplicate(true) if world.hotbar_items is Array else [],
		"hotbar_item_categories": world.hotbar_item_categories.duplicate(true) if world.hotbar_item_categories is Array else [],
		"quick_hotbar_item_type": "",
		"quick_hotbar_item_category": "",
		"player_level": _safe_int(world.player_level, 1, 1, MAX_PLAYER_LEVEL),
		"player_xp": _safe_int(world.player_xp, 0, 0),
		"player_xp_needed": _safe_int(world.player_xp_needed, 300, 0),
		"player_total_xp": _safe_int(world.player_total_xp, 0, 0),
		"player_title": _safe_string(world.player_title, "Explorer", MAX_INVENTORY_STRING_LEN),
		"player_health": _safe_int(world.player_health, 0, 0, MAX_PLAYER_HEALTH),
		"equipped_tool": _safe_string(world.equipped_tool, "", MAX_INVENTORY_STRING_LEN),
		"equipped_back_item": _safe_string(world.equipped_back_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_hair_item": _safe_string(world.equipped_hair_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_shirt_item": _safe_string(world.equipped_shirt_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_pants_item": _safe_string(world.equipped_pants_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_shoes_item": _safe_string(world.equipped_shoes_item, "", MAX_INVENTORY_STRING_LEN),
		"inventory": world.inventory.duplicate(true) if world.inventory is Dictionary else {},
		"seed_inventory": world.seed_inventory.duplicate(true) if world.seed_inventory is Dictionary else {},
		"tool_inventory": world.tool_inventory.duplicate(true) if world.tool_inventory is Dictionary else {},
		"back_inventory": world.back_inventory.duplicate(true) if world.back_inventory is Dictionary else {},
		"hair_inventory": world.hair_inventory.duplicate(true) if world.hair_inventory is Dictionary else {},
		"shirt_inventory": world.shirt_inventory.duplicate(true) if world.shirt_inventory is Dictionary else {},
		"pants_inventory": world.pants_inventory.duplicate(true) if world.pants_inventory is Dictionary else {},
		"shoes_inventory": world.shoes_inventory.duplicate(true) if world.shoes_inventory is Dictionary else {},
		"currency_inventory": world.currency_inventory.duplicate(true) if world.currency_inventory is Dictionary else {},
		"material_inventory": world.material_inventory.duplicate(true) if world.material_inventory is Dictionary else {},
		"lure_inventory": world.lure_inventory.duplicate(true) if world.lure_inventory is Dictionary else {},
		"fish_inventory": world.fish_inventory.duplicate(true) if world.fish_inventory is Dictionary else {},
		"fishing_records": world.fishing_manager.get_fishing_records_save_data() if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_records_save_data") else {}
	}
	return hash(normalized_payload)


func get_inventory_count_limit(item_name: String, category: String) -> int:
	if world != null and world.has_method("get_stack_limit_for_item"):
		return max(1, int(world.get_stack_limit_for_item(item_name, category)))

	return MAX_INVENTORY_STACK


func get_world_save_path_for_name(world_name: String) -> String:
	ensure_world_save_folder()
	return world.WORLD_SAVE_FOLDER + sanitize_world_name(world_name) + ".json"


func should_use_server_world_state() -> bool:
	if world == null:
		return false

	var clean_world_name = str(world.current_world_name).strip_edges()
	if clean_world_name == "":
		return false

	return true


func should_expect_server_world_state() -> bool:
	if world == null:
		return false

	var clean_world_name = str(world.current_world_name).strip_edges()
	if clean_world_name == "":
		return false

	return true


func load_clean_server_world_base():
	debug_action_position_flow("load_clean_server_world_base start")
	clear_world()
	world.generate_world()
	world.ensure_entrance_gate()
	debug_action_position_flow("load_clean_server_world_base place at entrance")
	world.place_player_at_entrance_immediate()
	world.setup_world_camera_limits()
	world.set_default_camera_zoom_silent()
	world.clamp_player_to_world()

	if world.has_method("load_world_lock_save_data"):
		world.load_world_lock_save_data({})

	load_player_data()
	world.update_equipment_visual()
	world.update_all_ui()
	debug_action_position_flow("load_clean_server_world_base end")


func save_world():
	if world == null:
		return

	if not world.in_world:
		return

	if is_saving_now:
		return

	is_saving_now = true

	if waiting_for_server_world_state or should_use_server_world_state():
		is_saving_now = false
		return

	save_player_data()

	var save_data = {
		"world_version": world.WORLD_VERSION,
		"world_name": world.current_world_name,
		"world_width": world.WORLD_WIDTH,
		"world_height": world.WORLD_HEIGHT,
		"selected_item_type": world.selected_item_type,
		"selected_item_category": world.selected_item_category,
		"primary_hotbar_tool": world.primary_hotbar_tool,
		"selected_block_type": world.selected_item_type,
		"quick_hotbar_item_type": world.hotbar_items[1] if world.hotbar_items.size() > 1 else "",
		"quick_hotbar_item_category": world.hotbar_item_categories[1] if world.hotbar_item_categories.size() > 1 else "empty",
		"hotbar_items": world.hotbar_items,
		"hotbar_item_categories": world.hotbar_item_categories,
		"player_health": world.player_health,
		"player_x": world.player.global_position.x if world.player != null else 0.0,
		"player_y": world.player.global_position.y if world.player != null else 0.0,
		"inventory": world.inventory,
		"seed_inventory": world.seed_inventory,
		"tool_inventory": world.tool_inventory,
		"back_inventory": world.back_inventory,
		"hair_inventory": world.hair_inventory,
		"shirt_inventory": world.shirt_inventory,
		"pants_inventory": world.pants_inventory,
		"shoes_inventory": world.shoes_inventory,
		"currency_inventory": world.currency_inventory,
		"material_inventory": world.material_inventory,
		"lure_inventory": world.lure_inventory,
		"fish_inventory": world.fish_inventory,
		"fishing_records": world.fishing_manager.get_fishing_records_save_data() if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_records_save_data") else {},
		"equipped_tool": str(world.equipped_tool) if world.equipped_tool != null else "",
		"equipped_back_item": str(world.equipped_back_item) if world.equipped_back_item != null else "",
		"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
		"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
		"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
		"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else "",
		"world_lock": world.get_world_lock_save_data() if world.has_method("get_world_lock_save_data") else {},
		"blocks": [],
		"background_blocks": [],
		"item_drops": [],
		"planted_seeds": []
	}

	for grid_pos in world.blocks.keys():
		save_data["blocks"].append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": world.blocks[grid_pos]["type"],
			"entrance_locked": bool(world.blocks[grid_pos].get("entrance_locked", false)),
			"sign_text": str(world.blocks[grid_pos].get("sign_text", ""))
		})

	var background_blocks = get_background_blocks_dictionary()

	for grid_pos in background_blocks.keys():
		save_data["background_blocks"].append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": background_blocks[grid_pos]["type"]
		})

	for drop_data in world.dropped_items:
		var drop_node = drop_data["node"]

		if is_instance_valid(drop_node):
			save_data["item_drops"].append({
				"drop_id": str(drop_data.get("drop_id", "")),
				"x": drop_node.global_position.x,
				"y": drop_node.global_position.y,
				"type": drop_data["item_type"],
				"item_category": drop_data.get("item_category", ""),
				"is_seed": drop_data["is_seed"],
				"amount": drop_data.get("amount", 1),
				"stack_grid_x": drop_data.get("stack_grid_x", int(round(drop_node.global_position.x / world.BLOCK_SIZE))),
				"stack_grid_y": drop_data.get("stack_grid_y", int(round(drop_node.global_position.y / world.BLOCK_SIZE)))
			})

	if world.seed_system != null and world.seed_system.has_method("get_save_data"):
		save_data["planted_seeds"] = world.seed_system.get_save_data()

	var save_path = get_current_save_path()
	var file = FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		print("Could not save world.")
		is_saving_now = false
		return

	file.store_string(JSON.stringify(save_data))
	file.close()

	is_saving_now = false

	if print_save_messages:
		print("World saved.")


func load_world():
	if not world.in_world:
		return

	if waiting_for_server_world_state or should_use_server_world_state():
		debug_action_position_flow("load_world using clean server base", {
			"waiting_for_server_world_state": waiting_for_server_world_state,
			"should_use_server_world_state": should_use_server_world_state()
		})
		load_clean_server_world_base()
		return

	var save_path = get_current_save_path()

	if not FileAccess.file_exists(save_path):
		print("No save file found for world: " + world.current_world_name)
		clear_world()
		world.generate_world()
		world.place_player_at_entrance_immediate()
		world.setup_world_camera_limits()
		world.set_default_camera_zoom_silent()
		world.clamp_player_to_world()
		if world.has_method("load_world_lock_save_data"):
			world.load_world_lock_save_data({})

		load_player_data()
		world.update_equipment_visual()
		world.update_all_ui()
		save_world()
		return

	clear_world()

	var file = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		print("Could not load world.")
		return

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)

	if data == null:
		print("Save file is broken.")
		return

	var saved_world_version = _safe_int(data.get("world_version", -1), -1, -1, 1000000)

	if saved_world_version != world.WORLD_VERSION:
		print("Old save version found. Creating new world with terrain directly above bedrock.")
		clear_world()
		world.generate_world()
		world.place_player_at_entrance_immediate()
		world.setup_world_camera_limits()
		world.set_default_camera_zoom_silent()
		world.clamp_player_to_world()
		load_player_data()
		world.update_equipment_visual()
		world.update_all_ui()
		save_world()
		return

	if world.has_method("load_world_lock_save_data"):
		world.load_world_lock_save_data(data.get("world_lock", {}))

	world.selected_item_type = _safe_string(data.get("selected_item_type", data.get("selected_block_type", "punch")), "punch", MAX_INVENTORY_STRING_LEN)
	world.selected_item_category = _safe_string(data.get("selected_item_category", "tool"), "tool", MAX_INVENTORY_STRING_LEN)
	world.primary_hotbar_tool = _safe_string(data.get("primary_hotbar_tool", "punch"), "punch", MAX_INVENTORY_STRING_LEN)

	if world.primary_hotbar_tool != "punch" and world.primary_hotbar_tool != "wrench":
		world.primary_hotbar_tool = "punch"

	if world.selected_item_category == "tool" and world.selected_item_type != "punch" and not world.tool_inventory.has(world.selected_item_type):
		world.selected_item_category = "block"

	var saved_hotbar_items = data.get("hotbar_items", [])
	var saved_hotbar_categories = data.get("hotbar_item_categories", [])

	if saved_hotbar_items is Array and saved_hotbar_categories is Array and saved_hotbar_items.size() > 0:
		world.hotbar_items.clear()
		world.hotbar_item_categories.clear()

		for i in range(min(saved_hotbar_items.size(), saved_hotbar_categories.size())):
			world.hotbar_items.append(_safe_string(saved_hotbar_items[i], "", MAX_INVENTORY_STRING_LEN))
			world.hotbar_item_categories.append(_safe_string(saved_hotbar_categories[i], "", MAX_INVENTORY_STRING_LEN))
	else:
		var quick_item_type = _safe_string(data.get("quick_hotbar_item_type", "dirt"), "dirt", MAX_INVENTORY_STRING_LEN)
		var quick_item_category = _safe_string(data.get("quick_hotbar_item_category", "block"), "block", MAX_INVENTORY_STRING_LEN)

		if quick_item_category == "block" or quick_item_category == "seed":
			world.hotbar_items = ["punch", quick_item_type, "grass", "stone", "wood", "leaf"]
			world.hotbar_item_categories = ["tool", quick_item_category, "block", "block", "block", "block"]

	world.normalize_hotbar()
	world.setup_hotbar()

	world.player_health = _safe_int(data.get("player_health", 10), 10, 0, MAX_PLAYER_HEALTH)

	var saved_inventory = data.get("inventory", {})

	apply_saved_inventory_counts(world.inventory, saved_inventory, false)

	apply_saved_inventory_counts(world.seed_inventory, data.get("seed_inventory", {}), false)
	apply_saved_inventory_counts(world.tool_inventory, data.get("tool_inventory", {}), true)
	apply_saved_inventory_counts(world.back_inventory, data.get("back_inventory", {}), true)
	apply_saved_inventory_counts(world.hair_inventory, data.get("hair_inventory", {}), true)
	apply_saved_inventory_counts(world.shirt_inventory, data.get("shirt_inventory", {}), true)
	apply_saved_inventory_counts(world.pants_inventory, data.get("pants_inventory", {}), true)
	apply_saved_inventory_counts(world.shoes_inventory, data.get("shoes_inventory", {}), true)
	apply_saved_inventory_counts(world.currency_inventory, data.get("currency_inventory", {}), true)
	apply_saved_inventory_counts(world.material_inventory, data.get("material_inventory", {}), true)
	apply_saved_inventory_counts(world.lure_inventory, data.get("lure_inventory", {}), true)
	apply_saved_fish_weight_inventory(data.get("fish_inventory", {}), true)
	if world.fishing_manager != null and world.fishing_manager.has_method("apply_fishing_records"):
		var fishing_records_data = data.get("fishing_records", {})
		var fishing_records_dictionary: Dictionary = (fishing_records_data as Dictionary) if fishing_records_data is Dictionary else {}
		world.fishing_manager.apply_fishing_records(fishing_records_dictionary)

	var loaded_equipped_tool = data.get("equipped_tool", world.equipped_tool)
	if loaded_equipped_tool == null:
		loaded_equipped_tool = ""
	world.equipped_tool = _safe_string(loaded_equipped_tool, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_tool != "" and (not world.tool_inventory.has(world.equipped_tool) or _safe_int(world.tool_inventory[world.equipped_tool], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_tool = ""

	var loaded_equipped_back_item = data.get("equipped_back_item", world.equipped_back_item)
	if loaded_equipped_back_item == null:
		loaded_equipped_back_item = ""
	world.equipped_back_item = _safe_string(loaded_equipped_back_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_back_item != "" and (not world.back_inventory.has(world.equipped_back_item) or _safe_int(world.back_inventory[world.equipped_back_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_back_item = ""

	var loaded_equipped_hair_item = data.get("equipped_hair_item", world.equipped_hair_item)
	if loaded_equipped_hair_item == null:
		loaded_equipped_hair_item = ""
	world.equipped_hair_item = _safe_string(loaded_equipped_hair_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hair_item != "" and (not world.hair_inventory.has(world.equipped_hair_item) or _safe_int(world.hair_inventory[world.equipped_hair_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hair_item = ""

	var loaded_equipped_shirt_item = data.get("equipped_shirt_item", world.equipped_shirt_item)
	if loaded_equipped_shirt_item == null:
		loaded_equipped_shirt_item = ""
	world.equipped_shirt_item = _safe_string(loaded_equipped_shirt_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_shirt_item != "" and (not world.shirt_inventory.has(world.equipped_shirt_item) or _safe_int(world.shirt_inventory[world.equipped_shirt_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_shirt_item = ""

	var loaded_equipped_pants_item = data.get("equipped_pants_item", world.equipped_pants_item)
	if loaded_equipped_pants_item == null:
		loaded_equipped_pants_item = ""
	world.equipped_pants_item = _safe_string(loaded_equipped_pants_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_pants_item != "" and (not world.pants_inventory.has(world.equipped_pants_item) or _safe_int(world.pants_inventory[world.equipped_pants_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_pants_item = ""

	var loaded_equipped_shoes_item = data.get("equipped_shoes_item", world.equipped_shoes_item)
	if loaded_equipped_shoes_item == null:
		loaded_equipped_shoes_item = ""
	world.equipped_shoes_item = _safe_string(loaded_equipped_shoes_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_shoes_item != "" and (not world.shoes_inventory.has(world.equipped_shoes_item) or _safe_int(world.shoes_inventory[world.equipped_shoes_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_shoes_item = ""

	var saved_blocks = data.get("blocks", [])

	if not (saved_blocks is Array):
		saved_blocks = []

	for block_data in saved_blocks:
		if not (block_data is Dictionary):
			continue

		if not block_data.has("x") or not block_data.has("y") or not block_data.has("type"):
			continue

		var block_type = _safe_string(block_data.get("type", ""), "", MAX_INVENTORY_STRING_LEN)
		if block_type == "":
			continue

		var grid_pos = Vector2i(
			_safe_int(block_data.get("x", 0), 0, 0, max(world.WORLD_WIDTH - 1, 0)),
			_safe_int(block_data.get("y", 0), 0, 0, max(world.WORLD_HEIGHT - 1, 0))
		)
		if not world.is_grid_inside_world(grid_pos):
			continue

		if world.block_textures.has(block_type):
			world.create_block(grid_pos, block_type)

			if block_type == "wooden_entrance":
				world.set_wooden_entrance_locked(grid_pos, _safe_bool(block_data.get("entrance_locked", false), false))

			if block_type == "sign" and world.blocks.has(grid_pos):
				world.blocks[grid_pos]["sign_text"] = _safe_string(block_data.get("sign_text", ""), "", 128)
				world.update_sign_text_visual(grid_pos)

	var saved_background_blocks = data.get("background_blocks", [])

	load_background_blocks_from_data(saved_background_blocks)

	if not (saved_background_blocks is Array) or saved_background_blocks.size() == 0:
		add_missing_backgrounds_for_loaded_blocks()

	var saved_item_drops = data.get("item_drops", [])

	if not (saved_item_drops is Array):
		saved_item_drops = []

	for drop_data in saved_item_drops:
		if not (drop_data is Dictionary):
			continue

		if not drop_data.has("x") or not drop_data.has("y") or not drop_data.has("type"):
			continue

		var item_type = _safe_string(drop_data.get("type", ""), "", MAX_INVENTORY_STRING_LEN)
		if item_type == "":
			continue

		var item_position = Vector2(
			_safe_float(drop_data.get("x", 0.0), 0.0, -1000000.0, 1000000.0),
			_safe_float(drop_data.get("y", 0.0), 0.0, -1000000.0, 1000000.0)
		)
		var is_seed = _safe_bool(drop_data.get("is_seed", false), item_type == "seed" or item_type.ends_with("_seed"))
		var item_category = _safe_string(drop_data.get("item_category", ""), "", MAX_INVENTORY_STRING_LEN)
		var amount = _safe_int(drop_data.get("amount", 1), 1, 1, MAX_INVENTORY_STACK)
		var drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_INVENTORY_STRING_LEN)

		world.create_item_drop(item_type, item_position, is_seed, item_category, 0.0, amount, drop_id, false)

	var saved_planted_seeds = data.get("planted_seeds", [])

	if not (saved_planted_seeds is Array):
		saved_planted_seeds = []

	if world.seed_system != null and world.seed_system.has_method("load_seed_data"):
		world.seed_system.load_seed_data(saved_planted_seeds)

	world.ensure_entrance_gate()
	world.place_player_at_entrance_immediate()

	# Current system keeps player inventory/equipment global, not per world.
	# This restores player data after old world saves try to load old inventory fields.
	load_player_data_from_current_or_legacy(data)

	world.setup_world_camera_limits()
	world.set_default_camera_zoom_silent()
	world.clamp_player_to_world()
	world.update_equipment_visual()
	world.update_all_ui()

	print("World loaded: " + world.current_world_name)


func clear_world():
	clear_background_blocks()

	for grid_pos in world.blocks.keys():
		world.blocks[grid_pos]["node"].queue_free()

	world.blocks.clear()
	world.terrain_surface_y.clear()
	world.block_hit_progress.clear()
	world.block_hit_timers.clear()
	clear_dropped_items()
	world.clear_planted_seeds()



func clear_dropped_items():
	if world.drop_manager != null and world.drop_manager.has_method("clear"):
		world.drop_manager.clear()
		return

	for drop_data in world.dropped_items:
		var drop_node = drop_data["node"]

		if is_instance_valid(drop_node):
			drop_node.queue_free()

	world.dropped_items.clear()
