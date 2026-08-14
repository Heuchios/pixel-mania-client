extends Node

const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")

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
var last_server_player_state_saved_at := ""
var last_server_player_state_applied_ms := 0
var network_player_state_request_in_flight := false
var network_player_state_request_username := ""
var network_player_state_request_started_ms := 0
var world_entry_final_entrance_snap_id := 0
# Re-entrancy guard for return_to_lobby_after_failed_world_entry(). Several failure
# sources can fire for one bad join (a server rejection AND the client-side retry ladder
# timing out, for example); only the first may drive the exit.
var returning_to_lobby_after_failed_entry := false

# Turn this on only when you want console proof that saving is happening.
# Leaving it false avoids printing "World saved." every second.
var print_save_messages := false
const WORLD_ENTRY_FINAL_ENTRANCE_SNAP_FRAMES := 2
const PLAYER_SAVE_FOLDER = "user://players/"
const LOBBY_PROFILE_PATH = "user://pixelmania_profile.cfg"
# Must match world_menu_ui.gd's LOBBY_SCENE. Only used by the last-resort direct scene
# change in return_to_lobby_after_failed_world_entry(); the normal exit still routes
# through world_menu_ui.return_to_lobby_menu().
const LOBBY_SCENE_PATH = "res://Scenes/ui/lobby/LobbyScene.tscn"
# How long return_to_lobby_after_failed_world_entry() waits before confirming the lobby
# actually loaded. Deliberately longer than WORLD_EXIT_BLOCK_UPDATE_DRAIN_TIMEOUT_MS (1800)
# below: a user-initiated return_to_lobby_menu(true) that is already parked awaiting that
# drain must be allowed to finish and save, rather than being pre-empted by this watchdog.
# Still short enough that a genuinely stuck client is not left staring at nothing.
const LOBBY_RETURN_VERIFY_SECONDS := 2.5
const LEGACY_PLAYER_MIGRATION_MARKER = "user://players/_legacy_player_data_migrated.txt"
const LEGACY_SERVER_INVENTORY_IMPORT_MARKER_PREFIX = "user://players/_legacy_server_inventory_import_confirmed_"
const LEGACY_SERVER_INVENTORY_IMPORT_MAX_ATTEMPTS := 3
const LEGACY_SERVER_INVENTORY_IMPORT_REVISION := 3
const PLAYER_INVENTORY_SAVE_KEYS = [
	"inventory",
	"seed_inventory",
	"tool_inventory",
	"back_inventory",
	"hat_inventory",
	"hair_inventory",
	"eyewear_inventory",
	"beard_inventory",
	"body_accessory_inventory",
	"shirt_inventory",
	"pants_inventory",
	"shoes_inventory",
	"ride_inventory",
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
	"equipped_hat_item",
	"equipped_hair_item",
	"equipped_eyewear_item",
	"equipped_beard_item",
	"equipped_body_accessory_item",
	"equipped_shirt_item",
	"equipped_pants_item",
	"equipped_shoes_item",
	"equipped_ride_item"
]
const MAX_INVENTORY_STACK := 400
const MAX_INVENTORY_STRING_LEN := 64
const MAX_PLAYER_HEALTH := 10
const MAX_PLAYER_LEVEL := 100
const DUPLICATE_SERVER_PLAYER_STATE_WINDOW_MS := 1500
const SERVER_PLAYER_STATE_FRESH_MS := 30000
const NETWORK_PLAYER_STATE_REQUEST_TIMEOUT_MS := 15000
const DEBUG_ACTION_POSITION_FLOW := false
const WORLD_EXIT_BLOCK_UPDATE_DRAIN_TIMEOUT_MS := 1800
# World entry performance: when the server is expected to send the real world state,
# do not build a full generated world first. The loading overlay can cover an empty
# base while we wait for the authoritative block payload.
const FAST_WORLD_ENTRY_SKIP_SERVER_BASE_GENERATION := true
# Let the loading CanvasLayer render before any heavy save/clear/load work starts.
const WORLD_ENTRY_OVERLAY_DRAW_FRAMES := 2


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
	if value is String:
		var text := str(value).strip_edges()
		if text.is_valid_int():
			return clamp(int(text), min_value, max_value)
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


func select_first_hotbar_slot_silent():
	if world == null:
		return
	if not (world.hotbar_items is Array) or not (world.hotbar_item_categories is Array):
		return
	if world.hotbar_items.is_empty() or world.hotbar_item_categories.is_empty():
		return

	var item_type = _safe_string(world.hotbar_items[0], "", MAX_INVENTORY_STRING_LEN)
	var category = _safe_string(world.hotbar_item_categories[0], "", MAX_INVENTORY_STRING_LEN)
	if item_type == "" or category == "" or category == "empty":
		return

	world.selected_item_type = item_type
	world.selected_item_category = category


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


func _saved_layer_key(grid_pos: Vector2i) -> String:
	return str(grid_pos.x) + "," + str(grid_pos.y)


func _parse_saved_layer_key(raw_key) -> Dictionary:
	var parts := str(raw_key).strip_edges().split(",", false)
	if parts.size() < 2:
		return {}
	var x_text := str(parts[0]).strip_edges()
	var y_text := str(parts[1]).strip_edges()
	if not x_text.is_valid_int() or not y_text.is_valid_int():
		return {}
	return {
		"x": _safe_int(x_text, 0, 0, max(world.WORLD_WIDTH - 1, 0)),
		"y": _safe_int(y_text, 0, 0, max(world.WORLD_HEIGHT - 1, 0))
	}


func _normalize_saved_layer_entries(raw_layer) -> Array:
	var result: Array = []
	if raw_layer is Array:
		for raw_entry in raw_layer:
			if raw_entry is Dictionary:
				result.append((raw_entry as Dictionary).duplicate(true))
		return result

	if raw_layer is Dictionary:
		for raw_key in (raw_layer as Dictionary).keys():
			var parsed_key := _parse_saved_layer_key(raw_key)
			if parsed_key.is_empty():
				continue
			var raw_value = (raw_layer as Dictionary).get(raw_key)
			var entry := {
				"x": parsed_key.get("x", 0),
				"y": parsed_key.get("y", 0)
			}
			if raw_value is Dictionary:
				for field in (raw_value as Dictionary).keys():
					entry[field] = raw_value[field]
			else:
				entry["item_id"] = raw_value
			result.append(entry)
	return result


func _resolve_saved_block_type(block_data: Dictionary) -> String:
	var block_type := _safe_string(block_data.get("type", block_data.get("block_type", "")), "", MAX_INVENTORY_STRING_LEN)
	if block_type != "":
		return block_type
	return ITEM_ATLAS_DB.resolve_item_key(block_data.get("item_id", block_data.get("id", "")))


func _get_saved_atlas_item_id(block_type: String, block_data: Dictionary = {}) -> int:
	var explicit_id := _safe_int(block_data.get("item_id", 0), 0, 0, 2147483647)
	if explicit_id > 0:
		return explicit_id
	if world != null and world.item_database.has(block_type):
		explicit_id = _safe_int(world.item_database[block_type].get("atlas_item_id", 0), 0, 0, 2147483647)
		if explicit_id > 0:
			return explicit_id
	return ITEM_ATLAS_DB.get_item_id_for_key(block_type)


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
			retire_block_node_collision_for_removal(block_node)
			block_node.queue_free()

	background_blocks.clear()


func retire_block_node_collision_for_removal(block_node) -> void:
	if block_node == null or not is_instance_valid(block_node):
		return

	var manager = get_block_manager_ref()
	if manager != null and manager.has_method("retire_block_node_for_removal"):
		manager.retire_block_node_for_removal(block_node)
		return

	if block_node is CollisionObject2D:
		var collision_object := block_node as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	for child in block_node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
		retire_block_node_collision_for_removal(child)


func should_loaded_block_get_missing_background(block_type: String, grid_pos: Vector2i) -> bool:
	if block_type != "dirt" and block_type != "stone" and block_type != "lava":
		return false

	if grid_pos.y <= world.SURFACE_Y:
		return false

	if grid_pos.y >= world.BEDROCK_START_Y:
		return false

	return true


func load_background_blocks_from_data(saved_background_blocks):
	saved_background_blocks = _normalize_saved_layer_entries(saved_background_blocks)

	for block_data in saved_background_blocks:
		if not (block_data is Dictionary):
			continue

		if not block_data.has("x") or not block_data.has("y"):
			continue

		var block_type = _resolve_saved_block_type(block_data)
		if block_type == "":
			continue

		var grid_pos = Vector2i(
			_safe_int(block_data.get("x", 0), 0, 0, max(world.WORLD_WIDTH - 1, 0)),
			_safe_int(block_data.get("y", 0), 0, 0, max(world.WORLD_HEIGHT - 1, 0))
		)
		if not world.is_grid_inside_world(grid_pos):
			continue

		if world.item_database.has(block_type) or world.block_textures.has(block_type):
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


func set_gameplay_world_active(active: bool, sync_world_nodes: bool = true):
	if world.player != null:
		world.player.visible = active
		world.player.velocity = Vector2.ZERO
		world.player.set_physics_process(active and not world.noclip_enabled)

	if not sync_world_nodes:
		if world.seed_system != null and world.seed_system is CanvasItem:
			world.seed_system.visible = active
		return

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks[grid_pos]
		var block_node = block_data.get("node", null) if block_data is Dictionary else null

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


func is_world_entry_loading_active() -> bool:
	if world == null:
		return false

	if bool(world.get_meta("world_entry_in_progress", false)):
		return true

	if world.has_method("is_smooth_world_load_visible") and bool(world.is_smooth_world_load_visible()):
		return true

	return false


func hide_world_menu_overlay_for_loading() -> void:
	if world == null:
		return

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()

	if world.ui_layer == null:
		return

	var world_menu_overlay: Node = world.ui_layer.get_node_or_null("WorldMenuOverlay")
	if world_menu_overlay != null and world_menu_overlay is CanvasItem:
		(world_menu_overlay as CanvasItem).visible = false


func set_gameplay_ui_visible(active: bool):
	if world.ui_layer == null:
		return

	var loading_active: bool = is_world_entry_loading_active()

	for child in world.ui_layer.get_children():
		# Keep the world menu controller alive, but do not force its overlay visible.
		if child.name == "WorldMenuUI":
			child.visible = true
			continue

		if child.name == "ChatUI":
			child.visible = active and not loading_active
			continue

		if child.name == "WorldMenuOverlay":
			# During world entry/loading, do NOT show the world menu as the fallback screen.
			# The dedicated WorldLoadingOverlay CanvasLayer should be the only visible screen.
			if loading_active:
				child.visible = false
			elif active:
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
	if world.has_method("close_wooden_entrance_confirm"):
		world.close_wooden_entrance_confirm()
	if world.has_method("close_door_editor"):
		world.close_door_editor()
	world.close_crafting()
	world.close_furnace()
	world.close_sign()
	world.close_inventory_window()
	world.close_player_menu()
	if world.has_method("close_game_menu"):
		world.close_game_menu()
	if world.has_method("close_trade_ui"):
		world.close_trade_ui()
	if world.has_method("close_area_lock_ui"):
		world.close_area_lock_ui()

func notify_network_join_current_world():
	if _is_dev_test_login_active():
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and (network.has_method("send_join_world_if_needed") or network.has_method("send_join_world")):
		var sent := false
		if network.has_method("send_join_world_if_needed"):
			sent = bool(network.send_join_world_if_needed(world.current_world_name))
		else:
			sent = bool(network.send_join_world(world.current_world_name))
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


# ============================================================
# FAILED WORLD ENTRY -> LOBBY RECOVERY
# ============================================================
# The single authoritative exit for every unsuccessful world entry.
#
# Why this exists (this was the grey-screen bug): handle_server_world_entry_rejected()
# and handle_client_world_loading_failed() below both used to end with a bare
#
#     if world.world_menu_ui != null and world.world_menu_ui.has_method("return_to_lobby_menu"):
#         world.world_menu_ui.call_deferred("return_to_lobby_menu", false)
#     elif world.world_menu_ui != null and world.world_menu_ui.has_method("open_main_menu"):
#         world.world_menu_ui.call_deferred("open_main_menu")
#
# with NO else branch. world.world_menu_ui is null for the entire duration of a join that
# never succeeds: world.gd's _ready() never calls setup_world_menu_ui(), and the only
# thing that builds it lazily is start_optional_world_ui_warmup(), whose sole caller is
# _finish_world_entry_noncritical_work() -- i.e. it only ever runs AFTER a world entry has
# already completed. So on a failed join both branches were silently skipped and nothing
# navigated anywhere, while the lines immediately above had already set in_world = false and
# called set_gameplay_world_active(false) (hides the player, every block, background block
# and dropped item), set_gameplay_ui_visible(false) (hides every ui_layer child) and
# cancel_smooth_world_load() (hides the loading overlay). main.tscn has no ColorRect or
# authored background and its TileMapLayers were still empty because world data never
# arrived, so the viewport fell through to the project's default clear colour -- the grey
# screen -- with the player permanently stranded there.
#
# Build the world menu on demand (the same lazy pattern world.gd's
# return_to_lobby_from_landfill_race() already uses correctly) so the normal,
# re-entrancy-guarded return_to_lobby_menu() path runs: it settles pending authoritative
# block edits, persists lobby profile state and only then changes scene. Reusing it keeps one
# exit path rather than a second half-complete implementation. Only if that genuinely cannot
# be built do we fall back to changing scene directly, so no UI construction failure can
# strand the player again.
#
# Note it will NOT send leave_world for us: world_menu_ui._notify_network_leave_for_lobby()
# is gated on world.in_world, and both callers clear that before getting here. Both therefore
# call notify_network_leave_world() themselves first, while the world name is still known.
#
# Safe to call twice: the guard makes every call after the first a no-op, and
# return_to_lobby_menu() carries its own return_to_lobby_menu_in_progress guard as well.
func return_to_lobby_after_failed_world_entry(reason: String = "world_entry_failed") -> void:
	if world == null or not is_instance_valid(world):
		return
	if returning_to_lobby_after_failed_entry:
		return
	returning_to_lobby_after_failed_entry = true

	debug_action_position_flow("return_to_lobby_after_failed_world_entry", {
		"reason": reason,
		"world": str(world.current_world_name),
		"had_world_menu_ui": world.world_menu_ui != null
	})

	# Drop the standing "please join this world" intent BEFORE the world menu is built.
	# Two reasons, both load-bearing:
	#  1. world_menu_ui.setup() ends with call_deferred("_try_auto_enter_pending_lobby_world"),
	#     which immediately re-enters whatever pending join it can find. Building the menu
	#     here with the intent still set would re-join the world we just failed to enter and
	#     fail again -- an endless join/fail loop instead of a return to the lobby.
	#  2. pending_join_enabled also drives NetworkManager.handle_account_auth_ok()'s
	#     auto-resend after a reconnect, so leaving it set means a later reconnect silently
	#     retries a join the player has already been told failed.
	# cancel_active_join_request() does NOT cover this -- it only invalidates the in-flight
	# request id, not the standing intent. The player is being returned to the lobby exactly
	# so they can choose again.
	_clear_pending_join_after_failed_world_entry()

	if world.world_menu_ui == null and world.has_method("setup_world_menu_ui"):
		world.setup_world_menu_ui()

	if world.world_menu_ui != null and is_instance_valid(world.world_menu_ui):
		# The menu only needs to EXIST so its return_to_lobby_menu() can run. Keep it
		# hidden: set_gameplay_ui_visible(false) has already hidden every other ui_layer
		# child by this point, so showing a freshly built menu would flash it for a frame.
		world.world_menu_ui.visible = false
		if world.world_menu_ui.has_method("return_to_lobby_menu"):
			world.world_menu_ui.call_deferred("return_to_lobby_menu", false)
			_verify_lobby_return_took_effect()
			return

	push_warning(
		"[WorldEntryRecovery] World menu UI unavailable (reason=" + str(reason)
		+ "); changing to the lobby scene directly."
	)
	call_deferred("_change_scene_to_lobby_directly")


func _verify_lobby_return_took_effect() -> void:
	# world_menu_ui.return_to_lobby_menu() ends in change_scene_to_file() but discards the
	# returned Error, and it latches its own return_to_lobby_menu_in_progress guard before
	# getting there. So if that scene load ever fails, BOTH that guard and ours stay latched
	# and every later failure source no-ops -- stranding the player on the grey screen exactly
	# as the original bug did. Nothing else would notice. Re-check shortly afterwards and
	# force the change ourselves if we are somehow still in the world scene.
	#
	# On the normal path the scene change frees the world (and this manager with it), so the
	# is_instance_valid() checks below simply end the coroutine.
	if world == null or not is_instance_valid(world):
		return
	var scene_tree: SceneTree = world.get_tree()
	if scene_tree == null:
		return

	# Connect rather than await. On the normal path the scene change frees this manager (it
	# is a child of the world node) while the SceneTreeTimer belongs to the SceneTree and
	# outlives it, so awaiting would resume into a freed instance and print
	# "Resumed function ... after await, but class instance is gone" on EVERY successful
	# recovery -- harmless, but it reads as a real error in the log. A signal connection is
	# severed automatically when the receiver is freed, so once the lobby is up this check
	# simply never runs.
	var verify_timer := scene_tree.create_timer(LOBBY_RETURN_VERIFY_SECONDS)
	verify_timer.timeout.connect(_on_lobby_return_verify_timeout, CONNECT_ONE_SHOT)


func _on_lobby_return_verify_timeout() -> void:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return

	push_warning(
		"[WorldEntryRecovery] Lobby return did not take effect within "
		+ str(LOBBY_RETURN_VERIFY_SECONDS) + "s; forcing a direct scene change."
	)
	# Un-latch first: _change_scene_to_lobby_directly() re-latches on failure only, and a
	# spent-but-ineffective guard must never be what keeps the player stuck.
	returning_to_lobby_after_failed_entry = false
	_change_scene_to_lobby_directly()


# Stashed in the lobby profile config rather than shown here: show_notification() would render
# into ui_layer children that set_gameplay_ui_visible(false) just hid and that the scene change
# frees in the same frame, so the player never actually sees it. LobbyScene reads and clears
# this on _ready() and shows it in its own status label -- i.e. cleanup, then lobby restored,
# then the reason, in that order.
func _store_world_join_failure_message_for_lobby(message: String) -> void:
	var clean_message := str(message).strip_edges()
	if clean_message == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(LOBBY_PROFILE_PATH)
	cfg.set_value("world_join_failure", "message", clean_message)
	var save_error := cfg.save(LOBBY_PROFILE_PATH)
	if save_error != OK:
		push_warning(
			"[WorldEntryRecovery] Could not store the join failure message: "
			+ error_string(save_error)
		)


func _clear_pending_join_after_failed_world_entry() -> void:
	if world != null and is_instance_valid(world):
		var network = world.get_node_or_null("/root/NetworkManager")
		# consume_pending_join() clears unconditionally; clear_completed_pending_join_for_world()
		# deliberately no-ops when the names disagree, which is not what we want here.
		if network != null and network.has_method("consume_pending_join"):
			network.consume_pending_join()

	# world_menu_ui._try_auto_enter_pending_lobby_world() falls back to reading this config
	# section whenever NetworkManager has no in-memory pending join, and login_screen.gd,
	# lobby_menu.gd and world_menu_ui.gd all write enabled=true into it -- so clearing only
	# the in-memory copy would still leave an auto-rejoin armed on disk.
	var cfg := ConfigFile.new()
	cfg.load(LOBBY_PROFILE_PATH)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	var save_error := cfg.save(LOBBY_PROFILE_PATH)
	if save_error != OK:
		push_warning(
			"[WorldEntryRecovery] Could not clear the pending-join config: "
			+ error_string(save_error)
		)


func _change_scene_to_lobby_directly() -> void:
	if world == null or not is_instance_valid(world):
		return
	var scene_tree: SceneTree = world.get_tree()
	if scene_tree == null:
		return
	var change_error: int = scene_tree.change_scene_to_file(LOBBY_SCENE_PATH)
	if change_error != OK:
		# Clear the guard so a later failure (or the retry ladder) can try again rather
		# than being permanently suppressed by a one-off scene-change error.
		returning_to_lobby_after_failed_entry = false
		push_error(
			"[WorldEntryRecovery] Could not change to the lobby scene: "
			+ error_string(change_error)
		)


func handle_server_world_entry_rejected(data: Dictionary) -> bool:
	# DELIBERATELY still gated on waiting_for_server_world_state, which is set only by
	# enter_world_by_name() and begin_server_door_world_entry(). It is tempting to relax this
	# to "any world entry is in flight" so the lobby -> main.tscn auto-join path (where
	# NetworkManager sends join_world directly and this flag stays false) gets a faster exit
	# than waiting out the retry ladder. Do not: this function's reason handling is a
	# DENYLIST -- anything not in retryable_reasons below is treated as terminal. Making it
	# the first responder on that path would turn self-healing rejections into hard ejections,
	# most importantly world_route_redirect / world_route_unavailable, which fire routinely
	# right after a server restart and which handle_world_route_redirect() declines to
	# intercept whenever the redirect target is the host we are already on. That is the exact
	# regression world_loading_ui_manager.gd's TERMINAL_JOIN_WORLD_REJECTION_REASONS comment
	# records as having "broke joining EVERY world". That file owns retryability for this
	# path via an ALLOWLIST and must keep it; returning false here hands it over correctly.
	if world == null or not waiting_for_server_world_state:
		return false

	var reason: String = str(data.get("reason", "")).strip_edges().to_lower()
	var message: String = str(data.get("message", "Could not enter that world.")).strip_edges()
	var retryable_reasons := [
		"database_error",
		"world_state_refresh_failed",
		"player_state_refresh_failed",
		"world_persistence_flush_failed",
		"player_persistence_flush_failed",
		"persistence_flush_failed",
		"postgres_authority_unavailable",
		"postgres_unavailable",
		# The server is still holding an earlier entry for this connection. Tearing the
		# overlay down here would abandon a load the server considers healthy (and, when
		# the earlier entry really is stuck, drop the player at the lobby instead of
		# letting the retry ladder outlive the server's provisional-entry timeout).
		"world_entry_already_loading"
	]
	if reason in retryable_reasons or message.to_lower().contains("still loading"):
		if world.has_method("update_smooth_world_load_message"):
			world.update_smooth_world_load_message(message + " Retrying...")
		return true

	# Release the entry server-side while the world name is still known and BEFORE in_world is
	# cleared, exactly as handle_client_world_loading_failed() does. The lobby exit below
	# cannot do it for us: world_menu_ui._notify_network_leave_for_lobby() is gated on
	# in_world, which is false by the time it runs. Without this, a rejected door transition
	# from world A to world B navigates to the lobby while the server still holds presence in
	# A, and the server keeps this connection's provisional entry open -- which makes every
	# later join_world on the same connection fail with "A world is already loading."
	notify_network_leave_world(str(world.current_world_name).strip_edges())

	waiting_for_server_world_state = false
	world_entry_pending_announce = false
	world.set_meta("world_entry_in_progress", false)
	world.set_meta("world_entry_force_entrance_spawn", false)
	world.set_meta("world_bulk_load_in_progress", false)
	world.set_meta("world_bulk_load_reason", "")
	world.in_world = false
	set_gameplay_world_active(false)
	set_gameplay_ui_visible(false)
	if world.has_method("cancel_smooth_world_load"):
		world.cancel_smooth_world_load()

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("cancel_active_join_request"):
		network.cancel_active_join_request()

	var rejection_reason: String = reason if reason != "" else "world_entry_rejected"
	var rejection_message: String = message if message != "" else "Could not enter that world."
	_store_world_join_failure_message_for_lobby(rejection_message)
	return_to_lobby_after_failed_world_entry("server_rejected:" + rejection_reason)
	return true


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

	# The server holds this entry in its provisional "snapshot_sent" state until it is told
	# otherwise, and only world_entry_ready or leave_world tell it. Abandoning the load
	# silently left that entry pending, and every later join_world on this connection was
	# rejected with "A world is already loading." until the game was restarted. Release it
	# here, while the world name is still known and before in_world is cleared -- the lobby
	# return path below is gated on in_world, so this does not double-send.
	notify_network_leave_world(str(world.current_world_name).strip_edges())

	waiting_for_server_world_state = false
	world_entry_pending_announce = false
	world_entry_final_entrance_snap_id += 1
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

	# Hand the reason to the lobby rather than calling world.show_notification() here. That
	# used to be a deferred call into ui_layer children which set_gameplay_ui_visible(false)
	# had just hidden and which the scene change frees in the same frame, so the player never
	# got a single rendered frame of it -- the failure looked like an unexplained bounce.
	# Storing it means cleanup -> lobby restored -> reason shown, and the message cannot
	# delay or block the exit.
	_store_world_join_failure_message_for_lobby(clean_message)
	return_to_lobby_after_failed_world_entry("client_load_failed:" + clean_reason)
	return true


func notify_netfox_world_left(world_name: String, reason: String = "world-left") -> void:
	if world == null or not MovementMode.is_netfox_real():
		return

	var manager = world.get("netfox_real_manager")
	if manager != null and manager.has_method("notify_world_left"):
		manager.notify_world_left(world_name, reason)


func notify_netfox_world_entry_started(world_name: String, reason: String = "world-entry-started") -> void:
	if world == null or not MovementMode.is_netfox_real():
		return

	var manager = world.get("netfox_real_manager")
	if manager != null and manager.has_method("notify_world_entry_started"):
		manager.notify_world_entry_started(world_name, reason)


func notify_netfox_world_entry_ready(world_name: String, reason: String = "world-entry-ready") -> void:
	if world == null or not MovementMode.is_netfox_real():
		return

	var manager = world.get("netfox_real_manager")
	if manager != null and manager.has_method("notify_world_entry_ready"):
		manager.notify_world_entry_ready(world_name, reason)


func notify_network_leave_world(world_name: String):
	if world_name.strip_edges() == "":
		return

	notify_netfox_world_left(world_name, "notify_network_leave_world")

	if _is_dev_test_login_active():
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_leave_world"):
		network.send_leave_world(world_name)

	if world.has_method("clear_remote_players"):
		world.clear_remote_players()

	if world.player_manager != null and world.player_manager.has_method("reset_multiplayer_sync_state"):
		world.player_manager.reset_multiplayer_sync_state()


func get_pending_authoritative_block_update_count() -> int:
	if world == null or world.block_manager == null:
		return 0
	if not world.block_manager.has_method("get_pending_authoritative_block_update_count"):
		return 0
	return int(world.block_manager.get_pending_authoritative_block_update_count())


func wait_for_pending_authoritative_block_updates(reason: String = "world_transition") -> bool:
	if world == null or world.block_manager == null:
		return true
	if not world.block_manager.has_method("has_pending_authoritative_block_updates"):
		return true
	if not bool(world.block_manager.has_pending_authoritative_block_updates()):
		return true

	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Saving world changes...")

	var drained := true
	if world.block_manager.has_method("wait_for_pending_authoritative_block_updates"):
		drained = bool(await world.block_manager.wait_for_pending_authoritative_block_updates(WORLD_EXIT_BLOCK_UPDATE_DRAIN_TIMEOUT_MS))
	else:
		drained = not bool(world.block_manager.has_pending_authoritative_block_updates())

	if not drained:
		push_warning("PixelMania: leaving world with pending authoritative block updates after " + reason + ". pending=" + str(get_pending_authoritative_block_update_count()))
	return drained


func exit_to_main_menu(save_current_world: bool = true):
	var previous_world_name = world.current_world_name
	var preserve_loading_overlay_for_pending_join := has_pending_lobby_join()

	if world.in_world:
		await wait_for_pending_authoritative_block_updates("exit_to_main_menu")

	if save_current_world and world.in_world:
		save_world()

	waiting_for_server_world_state = false
	world_entry_pending_announce = false
	world_entry_final_entrance_snap_id += 1
	world.set_meta("world_entry_force_entrance_spawn", false)

	if world.has_method("cancel_smooth_world_load") and not preserve_loading_overlay_for_pending_join:
		world.cancel_smooth_world_load()
	elif preserve_loading_overlay_for_pending_join:
		show_pending_lobby_join_loading_overlay()

	if world.in_world:
		notify_network_leave_world(previous_world_name)

	world.close_chat_panel()
	world.close_shop()
	if world.has_method("close_fish_monger_ui"):
		world.close_fish_monger_ui()
	if world.has_method("close_wooden_entrance_confirm"):
		world.close_wooden_entrance_confirm()
	if world.has_method("close_door_editor"):
		world.close_door_editor()
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


func has_pending_lobby_join() -> bool:
	if world != null:
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("has_pending_join") and bool(network.has_pending_join()):
			return true

	var cfg := ConfigFile.new()
	if cfg.load(LOBBY_PROFILE_PATH) != OK:
		return false

	if not bool(cfg.get_value("pending_join", "enabled", false)):
		return false

	var pending_world_name := str(cfg.get_value("pending_join", "world_name", "")).strip_edges()
	if pending_world_name != "":
		return true

	return str(cfg.get_value("profile", "last_world", "")).strip_edges() != ""


func show_pending_lobby_join_loading_overlay() -> void:
	if world == null:
		return
	if not world.has_method("begin_smooth_world_load"):
		return

	var pending_world_name := get_pending_lobby_join_world_name()
	if pending_world_name == "":
		pending_world_name = "START"
	pending_world_name = pending_world_name.to_upper()

	world.begin_smooth_world_load(pending_world_name, true)
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + pending_world_name + "...")


func get_pending_lobby_join_world_name() -> String:
	if world != null:
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("has_pending_join") and bool(network.has_pending_join()):
			var network_world = str(network.get("pending_join_world_name")).strip_edges()
			if network_world != "":
				return network_world

	var cfg := ConfigFile.new()
	if cfg.load(LOBBY_PROFILE_PATH) != OK:
		return ""

	if not bool(cfg.get_value("pending_join", "enabled", false)):
		return ""

	var pending_world_name := str(cfg.get_value("pending_join", "world_name", "")).strip_edges()
	if pending_world_name != "":
		return pending_world_name

	return str(cfg.get_value("profile", "last_world", "")).strip_edges()


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


func show_world_entry_loading_overlay(target_world_name: String, wait_for_server_state: bool, message: String = "") -> void:
	if world == null:
		return
	var clean_world_name: String = str(target_world_name).strip_edges().to_upper()
	if clean_world_name == "":
		clean_world_name = str(world.current_world_name).strip_edges().to_upper()
	hide_world_menu_overlay_for_loading()

	if world.has_method("begin_smooth_world_load"):
		world.begin_smooth_world_load(clean_world_name, wait_for_server_state)
	if message.strip_edges() != "" and world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message(message)
	elif world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + clean_world_name + "...")


func wait_for_loading_overlay_to_draw(reason: String = "") -> void:
	if world == null:
		return
	if not world.has_method("is_smooth_world_load_visible"):
		return
	if not bool(world.is_smooth_world_load_visible()):
		return
	var tree: SceneTree = world.get_tree()
	if tree == null:
		return
	for _i in range(WORLD_ENTRY_OVERLAY_DRAW_FRAMES):
		await tree.process_frame
	debug_action_position_flow("loading overlay draw wait complete", {"reason": reason})


func place_player_at_current_entrance_gate_for_world_entry(sync_to_server: bool = true) -> bool:
	if world == null:
		return false

	if world.has_method("force_place_player_at_current_entrance_gate"):
		return bool(world.force_place_player_at_current_entrance_gate(sync_to_server))

	if world.has_method("place_player_at_entrance_immediate"):
		world.place_player_at_entrance_immediate()
		return true

	return false


func schedule_final_entrance_gate_snap_for_world_entry(sync_to_server: bool = true) -> void:
	if world == null:
		return

	world_entry_final_entrance_snap_id += 1
	var snap_id := world_entry_final_entrance_snap_id
	var expected_world := str(world.current_world_name).strip_edges().to_upper()
	_run_final_entrance_gate_snap_for_world_entry.call_deferred(snap_id, expected_world, sync_to_server)


func _run_final_entrance_gate_snap_for_world_entry(snap_id: int, expected_world: String, sync_to_server: bool):
	var tree := get_tree()
	if tree == null:
		return

	for _i in range(WORLD_ENTRY_FINAL_ENTRANCE_SNAP_FRAMES):
		await tree.process_frame

	if snap_id != world_entry_final_entrance_snap_id:
		return
	if world == null or not bool(world.in_world):
		return
	if str(world.current_world_name).strip_edges().to_upper() != expected_world:
		return

	place_player_at_current_entrance_gate_for_world_entry(sync_to_server)


func enter_world_by_name(raw_name: String):
	var sanitized_name: String = sanitize_world_name(raw_name)
	debug_action_position_flow("enter_world_by_name start", {
		"raw_name": raw_name,
		"sanitized_name": sanitized_name
	})

	if sanitized_name == "":
		sanitized_name = world.DEFAULT_WORLD_NAME.to_lower()

	var target_world_name: String = sanitized_name.to_upper()
	var expect_server_world_state: bool = bool(should_expect_server_world_state())

	# Show the loading screen BEFORE save_world(), clear_world(), load_world(), or server
	# state application. Otherwise Godot cannot draw the CanvasLayer until after the
	# heavy synchronous work finishes, which makes it look like the scene never showed.
	show_world_entry_loading_overlay(
		target_world_name,
		expect_server_world_state,
		"Loading " + target_world_name + (" from server..." if expect_server_world_state else "...")
	)
	await wait_for_loading_overlay_to_draw("enter_world_before_save_clear_load")

	if world.in_world:
		var previous_world_name = world.current_world_name
		await wait_for_pending_authoritative_block_updates("enter_world_by_name")
		save_world()
		if previous_world_name.strip_edges().to_upper() != sanitized_name.to_upper():
			notify_network_leave_world(previous_world_name)
	else:
		if world.has_method("clear_remote_players"):
			world.clear_remote_players()

	world.current_world_name = target_world_name
	world.in_world = true
	world.set_meta("world_entry_in_progress", true)
	# Normal world entry should always spawn at the current live entrance gate.
	# This prevents old saved/server player coordinates from overriding a moved gate.
	world.set_meta("world_entry_force_entrance_spawn", true)
	world.set_meta("world_bulk_load_in_progress", true)
	world.set_meta("world_bulk_load_reason", "world_entry")
	waiting_for_server_world_state = expect_server_world_state
	world_entry_pending_announce = true
	notify_netfox_world_entry_started(target_world_name, "enter_world_by_name")
	debug_action_position_flow("enter_world_by_name waiting state", {
		"waiting_for_server_world_state": waiting_for_server_world_state
	})

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()
	hide_world_menu_overlay_for_loading()
	close_all_gameplay_popups()
	set_gameplay_ui_visible(false)
	set_gameplay_world_active(false)

	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Clearing old world...")
	await wait_for_loading_overlay_to_draw("enter_world_before_clear_world")
	clear_world()

	var network = world.get_node_or_null("/root/NetworkManager")
	if waiting_for_server_world_state and network != null and network.has_method("request_server_connection"):
		network.request_server_connection(false)

	if waiting_for_server_world_state:
		load_clean_server_world_base(true)
		if should_use_server_world_state():
			notify_network_join_current_world()
		return

	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + world.current_world_name + "...")
	await wait_for_loading_overlay_to_draw("enter_world_before_load_world")
	load_world()

	notify_network_join_current_world()
	finish_world_entry_after_load(true, true)


func handle_network_door_enter_ok(data: Dictionary):
	if MovementMode.is_netfox_real():
		return

	var target_world = sanitize_world_name(str(data.get("world", world.current_world_name)))
	if target_world == "":
		apply_same_world_door_spawn_with_transition(data)
		return

	var current_world = sanitize_world_name(str(world.current_world_name))
	var needs_world_state = bool(data.get("requires_world_state", false)) or target_world.to_upper() != current_world.to_upper()
	if needs_world_state:
		begin_server_door_world_entry_with_transition(data, target_world)
		return

	apply_same_world_door_spawn_with_transition(data)


func begin_local_door_exit_fade(finished_callable: Callable) -> bool:
	if not MovementMode.is_websocket():
		return false
	if world == null or world.player == null or not is_instance_valid(world.player):
		return false

	if world.player is CharacterBody2D:
		world.player.velocity = Vector2.ZERO
		world.player.set_physics_process(false)

	if world.player_manager != null and world.player_manager.has_method("play_local_player_world_exit_fade"):
		return bool(world.player_manager.play_local_player_world_exit_fade(finished_callable))

	return false


func apply_same_world_door_spawn_with_transition(data: Dictionary):
	var transition_data := data.duplicate(true)
	var finished_callable := Callable(self, "_finish_same_world_door_spawn_transition").bind(transition_data)
	if begin_local_door_exit_fade(finished_callable):
		return

	_finish_same_world_door_spawn_transition(transition_data)


func _finish_same_world_door_spawn_transition(data: Dictionary):
	if world.has_method("apply_server_door_spawn"):
		world.apply_server_door_spawn(data)

	if MovementMode.is_websocket() and world.player_manager != null and world.player_manager.has_method("play_local_player_world_enter_fade"):
		world.player_manager.play_local_player_world_enter_fade()


func begin_server_door_world_entry_with_transition(data: Dictionary, target_world: String):
	var transition_data := data.duplicate(true)
	var transition_world := target_world
	var finished_callable := Callable(self, "_begin_server_door_world_entry_after_fade").bind(transition_data, transition_world)
	if begin_local_door_exit_fade(finished_callable):
		return

	_begin_server_door_world_entry_after_fade(transition_data, transition_world)


func _begin_server_door_world_entry_after_fade(data: Dictionary, target_world: String):
	begin_server_door_world_entry(data, target_world)


func begin_server_door_world_entry(data: Dictionary, target_world: String):
	var sanitized_name: String = sanitize_world_name(target_world)
	if sanitized_name == "":
		return

	var target_world_name: String = sanitized_name.to_upper()
	show_world_entry_loading_overlay(target_world_name, true, "Entering " + target_world_name + "...")
	await wait_for_loading_overlay_to_draw("door_entry_before_save_clear")

	if world.in_world:
		save_world()

	if world.has_method("clear_remote_players"):
		world.clear_remote_players()

	world.current_world_name = target_world_name
	world.in_world = true
	world.set_meta("world_entry_in_progress", true)
	# Cross-world entries should resolve the destination world's live Entrance Gate
	# after the server world-state has loaded. Same-world doors still use their
	# door coordinate path and never enter this world-load flow.
	world.set_meta("world_entry_force_entrance_spawn", true)
	world.set_meta("world_bulk_load_in_progress", true)
	world.set_meta("world_bulk_load_reason", "door_world_entry")
	waiting_for_server_world_state = true
	world_entry_pending_announce = true
	notify_netfox_world_entry_started(target_world_name, "door_world_entry")

	close_all_gameplay_popups()
	set_gameplay_ui_visible(false)
	set_gameplay_world_active(false)
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Clearing old world...")
	await wait_for_loading_overlay_to_draw("door_entry_before_clear_world")
	clear_world()

	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Entering " + world.current_world_name + "...")

	debug_action_position_flow("begin_server_door_world_entry", {
		"world": world.current_world_name,
		"x": data.get("x", data.get("portal_spawn_x", null)),
		"y": data.get("y", data.get("portal_spawn_y", null))
	})


func finish_world_entry_after_load(save_after_finish: bool = true, announce_enter: bool = true, server_world_state_finalized: bool = false, defer_noncritical_work: bool = false):
	debug_action_position_flow("finish_world_entry_after_load start", {
		"save_after_finish": save_after_finish,
		"announce_enter": announce_enter,
		"server_world_state_finalized": server_world_state_finalized,
		"was_waiting_for_server_world_state": waiting_for_server_world_state
	})
	waiting_for_server_world_state = false
	world.in_world = true
	world.set_meta("world_entry_in_progress", false)

	# If this was a local/generated load path, queue one final variant pass. Server
	# world-state already awaits finalize_world_load_block_variants() before calling
	# this method, but this keeps local loads safe too.
	if not server_world_state_finalized and world.block_manager != null and world.block_manager.has_method("refresh_all_foreground_block_textures"):
		world.block_manager.refresh_all_foreground_block_textures()

	# The heavy world build is finished by the time this method runs. Clear the
	# bulk-load flag before normal gameplay resumes.
	world.set_meta("world_bulk_load_in_progress", false)
	world.set_meta("world_bulk_load_reason", "")
	notify_netfox_world_entry_ready(world.current_world_name, "finish_world_entry_after_load")

	set_gameplay_world_active(true, not server_world_state_finalized)
	close_all_gameplay_popups()
	set_gameplay_ui_visible(true)

	if world.world_menu_ui != null and world.world_menu_ui.has_method("close_menu"):
		world.world_menu_ui.close_menu()

	if world.player != null and not world.noclip_enabled:
		world.player.visible = true
		world.player.set_physics_process(true)

	if bool(world.get_meta("world_entry_force_entrance_spawn", false)):
		place_player_at_current_entrance_gate_for_world_entry(true)
		schedule_final_entrance_gate_snap_for_world_entry(true)
	world.set_meta("world_entry_force_entrance_spawn", false)

	world.setup_world_camera_limits()
	world.set_default_camera_zoom_silent()
	world.clamp_player_to_world()
	if world.block_manager != null and world.block_manager.has_method("schedule_world_entry_tilemap_visual_reconciliation"):
		world.block_manager.schedule_world_entry_tilemap_visual_reconciliation()
	world.normalize_hotbar()
	select_first_hotbar_slot_silent()
	if world.has_method("refresh_hotbar_live"):
		world.refresh_hotbar_live()
	else:
		world.setup_hotbar()
	world.update_equipment_visual()
	if MovementMode.is_websocket() and world.player_manager != null and world.player_manager.has_method("play_local_player_world_enter_fade"):
		world.player_manager.play_local_player_world_enter_fade()
	if world.has_method("finish_smooth_world_load"):
		world.finish_smooth_world_load()

	var completed_world_name := str(world.current_world_name)
	var should_announce := announce_enter and world_entry_pending_announce
	world_entry_pending_announce = false
	if defer_noncritical_work:
		call_deferred("_finish_world_entry_noncritical_after_frame", completed_world_name, save_after_finish, should_announce)
	else:
		_finish_world_entry_noncritical_work(completed_world_name, save_after_finish, should_announce)

	debug_action_position_flow("finish_world_entry_after_load end", {
		"save_after_finish": save_after_finish,
		"announce_enter": announce_enter,
		"defer_noncritical_work": defer_noncritical_work
	})


func _finish_world_entry_noncritical_after_frame(completed_world_name: String, save_after_finish: bool, should_announce: bool) -> void:
	var scene_tree: SceneTree = world.get_tree() if world != null else null
	if scene_tree != null:
		await scene_tree.process_frame
	_finish_world_entry_noncritical_work(completed_world_name, save_after_finish, should_announce)


func _finish_world_entry_noncritical_work(completed_world_name: String, save_after_finish: bool, should_announce: bool) -> void:
	if world == null or str(world.current_world_name) != completed_world_name:
		return
	world.restore_chat_ui_after_world_enter()
	world.update_all_ui()
	if should_announce:
		world.show_notification("Entered world: " + completed_world_name)
		_send_world_entry_chat_message()
	if save_after_finish:
		save_world()
	if world.has_method("start_optional_world_ui_warmup"):
		world.start_optional_world_ui_warmup()



func _send_world_entry_chat_message():
	var world_name = world.current_world_name

	if world.world_lock_manager != null and world.world_lock_manager.has_method("reconcile_world_lock_state_with_blocks"):
		world.world_lock_manager.reconcile_world_lock_state_with_blocks()

	var lock_text = "World is not locked."
	if world.world_lock_manager != null and world.world_lock_manager.is_locked:
		var owner_name = str(world.world_lock_manager.owner_name).strip_edges()
		if owner_name == "":
			owner_name = "unknown"
		lock_text = "World is locked by \"%s\"." % owner_name

	var other_player_count = _get_world_entry_other_player_count(world_name)
	var player_text = "There are %d other players here." % other_player_count
	if other_player_count == 1:
		player_text = "There is 1 other player here."

	var active_features = _get_world_entry_active_features()
	var active_text = "No world effects are active."
	if not active_features.is_empty():
		active_text = "%s %s active." % [_format_world_entry_list(active_features), "are" if active_features.size() != 1 else "is"]

	var msg = "Entered \"%s\". %s %s %s" % [world_name, lock_text, player_text, active_text]

	if world.chat_ui != null and world.chat_ui.has_method("add_chat_message"):
		world.chat_ui.add_chat_message("System", msg)


func _get_world_entry_other_player_count(world_name: String) -> int:
	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return 0
	if network.has_method("get_world_other_player_count"):
		return max(0, int(network.get_world_other_player_count(world_name)))
	if not network.has_method("get_world_player_count"):
		return 0

	return max(0, int(network.get_world_player_count(world_name)))


func _get_world_entry_active_features() -> Array:
	var active_features = []
	if world.block_manager == null:
		return active_features

	if world.block_manager.has_method("is_anti_punch_enabled") and world.block_manager.is_anti_punch_enabled():
		active_features.append("anti punch")
	if world.block_manager.has_method("is_anti_talk_enabled") and world.block_manager.is_anti_talk_enabled():
		active_features.append("anti talk")
	if world.block_manager.has_method("is_anti_gravity_enabled") and world.block_manager.is_anti_gravity_enabled():
		active_features.append("anti gravity")

	return active_features


func _format_world_entry_list(entries: Array) -> String:
	if entries.is_empty():
		return ""
	if entries.size() == 1:
		return str(entries[0])
	if entries.size() == 2:
		return "%s and %s" % [str(entries[0]), str(entries[1])]

	var text = ""
	for i in range(entries.size()):
		if i > 0:
			if i == entries.size() - 1:
				text += ", and "
			else:
				text += ", "
		text += str(entries[i])
	return text


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
		"inventory_slot_count": world.get_inventory_slot_count() if world.has_method("get_inventory_slot_count") else 20,
		"inventory": world.inventory,
		"seed_inventory": world.seed_inventory,
		"tool_inventory": world.tool_inventory,
		"back_inventory": world.back_inventory,
		"hat_inventory": world.hat_inventory,
		"hair_inventory": world.hair_inventory,
		"eyewear_inventory": world.eyewear_inventory,
		"beard_inventory": world.beard_inventory,
		"body_accessory_inventory": world.body_accessory_inventory,
		"shirt_inventory": world.shirt_inventory,
		"pants_inventory": world.pants_inventory,
		"shoes_inventory": world.shoes_inventory,
		"ride_inventory": world.ride_inventory,
		"currency_inventory": world.currency_inventory,
		"material_inventory": world.material_inventory,
		"lure_inventory": world.lure_inventory,
		"fish_inventory": get_fish_inventory_count_save_data(),
		"fish_inventory_unit": "count",
		"fishing_records": world.fishing_manager.get_fishing_records_save_data() if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_records_save_data") else {},
		"equipped_tool": str(world.equipped_tool) if world.equipped_tool != null else "",
		"equipped_back_item": str(world.equipped_back_item) if world.equipped_back_item != null else "",
		"equipped_hat_item": str(world.equipped_hat_item) if world.equipped_hat_item != null else "",
		"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
		"equipped_eyewear_item": str(world.equipped_eyewear_item) if world.equipped_eyewear_item != null else "",
		"equipped_beard_item": str(world.equipped_beard_item) if world.equipped_beard_item != null else "",
		"equipped_body_accessory_item": str(world.equipped_body_accessory_item) if world.equipped_body_accessory_item != null else "",
		"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
		"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
		"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else "",
		"equipped_ride_item": str(world.equipped_ride_item) if world.equipped_ride_item != null else ""
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
				var fish_source_count: int = safe_fish_count_from_save(source_inventory.get(item_name, 0.0), str(source_data.get("fish_inventory_unit", "")))
				var fish_target_count: int = safe_fish_count_from_save(target_inventory.get(item_name, 0.0), str(target_data.get("fish_inventory_unit", "count")))
				if fish_source_count > fish_target_count:
					target_inventory[item_name] = fish_source_count
				continue

			var item_source_count = int(source_inventory.get(item_name, 0))
			var item_target_count = int(target_inventory.get(item_name, 0))

			if item_source_count > item_target_count:
				target_inventory[item_name] = item_source_count

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


func request_network_player_state(force: bool = false):
	if not is_registered_account_active():
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var username := get_current_player_profile_name()
	var now_ms := Time.get_ticks_msec()
	if not force:
		var normalized_username := username.strip_edges().to_lower()
		if normalized_username != "" and normalized_username == last_server_player_state_username:
			if now_ms - last_server_player_state_applied_ms <= SERVER_PLAYER_STATE_FRESH_MS:
				return
		if network_player_state_request_in_flight and normalized_username == network_player_state_request_username:
			if now_ms - network_player_state_request_started_ms <= NETWORK_PLAYER_STATE_REQUEST_TIMEOUT_MS:
				return
			network_player_state_request_in_flight = false

	if network.has_method("send_account_state_save"):
		var email = ""
		if world.has_method("get_current_profile_email"):
			email = str(world.get_current_profile_email())
		network.send_account_state_save(username, email)

	if try_send_legacy_server_inventory_import():
		return

	if network.has_method("send_player_state_request"):
		if bool(network.send_player_state_request(username)):
			network_player_state_request_in_flight = true
			network_player_state_request_username = username.strip_edges().to_lower()
			network_player_state_request_started_ms = now_ms


func load_player_data(request_server_state: bool = true):
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
				if request_server_state:
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
				save_player_data(request_server_state)
				mark_legacy_global_player_data_migrated()
				print("Migrated global player data to account: " + get_current_player_profile_name())
				loading_player_data = false
				if request_server_state:
					request_network_player_state()
				return

	if not is_registered_account_active():
		var legacy_data = load_legacy_player_data_from_world_name(world.DEFAULT_WORLD_NAME)

		if legacy_data is Dictionary and has_useful_player_data(legacy_data):
			apply_player_data(legacy_data)
			world.player_data_loaded_from_file = true
			save_player_data(request_server_state)
			print("Migrated player data from START world save.")
			loading_player_data = false
			if request_server_state:
				request_network_player_state()
			return

	reset_player_data_to_defaults()
	world.player_data_loaded_from_file = false
	save_player_data(request_server_state)
	loading_player_data = false
	if request_server_state:
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

	if str(data.get("equipped_hat_item", "")) != "":
		return true

	if str(data.get("equipped_hair_item", "")) != "":
		return true

	if str(data.get("equipped_eyewear_item", "")) != "":
		return true

	if str(data.get("equipped_beard_item", "")) != "":
		return true

	if str(data.get("equipped_body_accessory_item", "")) != "":
		return true

	if str(data.get("equipped_shirt_item", "")) != "":
		return true

	if str(data.get("equipped_pants_item", "")) != "":
		return true

	if str(data.get("equipped_shoes_item", "")) != "":
		return true

	if str(data.get("equipped_ride_item", "")) != "":
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
	world.equipped_hat_item = ""
	world.equipped_hair_item = ""
	world.equipped_eyewear_item = ""
	world.equipped_beard_item = ""
	world.equipped_body_accessory_item = ""
	world.equipped_shirt_item = ""
	world.equipped_pants_item = ""
	world.equipped_shoes_item = ""
	world.equipped_ride_item = ""

	world.inventory.clear()
	world.seed_inventory.clear()
	world.tool_inventory.clear()
	world.back_inventory.clear()
	world.hat_inventory.clear()
	world.hair_inventory.clear()
	world.eyewear_inventory.clear()
	world.beard_inventory.clear()
	world.body_accessory_inventory.clear()
	world.shirt_inventory.clear()
	world.pants_inventory.clear()
	world.shoes_inventory.clear()
	world.ride_inventory.clear()
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
			"hat":
				world.hat_inventory[item_id] = starting_count
			"hair":
				world.hair_inventory[item_id] = starting_count
			"eyewear":
				world.eyewear_inventory[item_id] = starting_count
			"beard":
				world.beard_inventory[item_id] = starting_count
			"body_accessory":
				world.body_accessory_inventory[item_id] = starting_count
			"shirt":
				world.shirt_inventory[item_id] = starting_count
			"pants":
				world.pants_inventory[item_id] = starting_count
			"shoes":
				world.shoes_inventory[item_id] = starting_count
			"ride":
				world.ride_inventory[item_id] = starting_count
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


func apply_player_data(data: Dictionary, skip_hotbar_render: bool = false):
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

	world.player_level = _safe_int(data.get("player_level", data.get("level", world.player_level)), world.player_level, 1, MAX_PLAYER_LEVEL)
	world.player_xp = _safe_int(data.get("player_xp", data.get("xp", world.player_xp)), world.player_xp, 0)
	world.player_xp_needed = _safe_int(data.get("player_xp_needed", data.get("xp_needed", world.player_xp_needed)), world.player_xp_needed, 0)
	world.player_total_xp = _safe_int(data.get("player_total_xp", data.get("total_xp", world.player_total_xp)), world.player_total_xp, 0)
	world.player_title = _safe_string(data.get("player_title", world.player_title), "Explorer", MAX_INVENTORY_STRING_LEN)
	world.player_health = _safe_int(data.get("player_health", world.player_health), world.player_health, 0, MAX_PLAYER_HEALTH)
	if world.has_method("apply_inventory_slot_count"):
		world.apply_inventory_slot_count(data.get("inventory_slot_count", data.get("inventory_slots", world.inventory_slot_count)), false)

	apply_saved_inventory_counts(world.inventory, data.get("inventory", {}), false)
	apply_saved_inventory_counts(world.seed_inventory, data.get("seed_inventory", {}), false)
	apply_saved_inventory_counts(world.tool_inventory, data.get("tool_inventory", {}), true)
	apply_saved_inventory_counts(world.back_inventory, data.get("back_inventory", {}), true)
	apply_saved_inventory_counts(world.hat_inventory, data.get("hat_inventory", {}), true)
	apply_saved_inventory_counts(world.hair_inventory, data.get("hair_inventory", {}), true)
	apply_saved_inventory_counts(world.eyewear_inventory, data.get("eyewear_inventory", {}), true)
	apply_saved_inventory_counts(world.beard_inventory, data.get("beard_inventory", {}), true)
	apply_saved_inventory_counts(world.body_accessory_inventory, data.get("body_accessory_inventory", {}), true)
	apply_saved_inventory_counts(world.shirt_inventory, data.get("shirt_inventory", {}), true)
	apply_saved_inventory_counts(world.pants_inventory, data.get("pants_inventory", {}), true)
	apply_saved_inventory_counts(world.shoes_inventory, data.get("shoes_inventory", {}), true)
	apply_saved_inventory_counts(world.ride_inventory, data.get("ride_inventory", {}), true)
	apply_saved_inventory_counts(world.currency_inventory, data.get("currency_inventory", {}), true)
	apply_saved_inventory_counts(world.material_inventory, data.get("material_inventory", {}), true)
	apply_saved_inventory_counts(world.lure_inventory, data.get("lure_inventory", {}), true)
	apply_saved_fish_count_inventory(data.get("fish_inventory", {}), true, str(data.get("fish_inventory_unit", "")))
	world.normalize_hotbar()
	# skip_hotbar_render lets callers that are about to immediately re-render the
	# hotbar again (e.g. apply_network_player_state restoring the local loadout
	# right after this) suppress this intermediate rebuild, so the expensive
	# setup_scene_hotbar() full rebuild happens once per update instead of twice.
	if not skip_hotbar_render:
		world.setup_hotbar()
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

	var loaded_equipped_hat_item = data.get("equipped_hat_item", world.equipped_hat_item)

	if loaded_equipped_hat_item == null:
		loaded_equipped_hat_item = ""

	world.equipped_hat_item = _safe_string(loaded_equipped_hat_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hat_item != "" and (not world.hat_inventory.has(world.equipped_hat_item) or _safe_int(world.hat_inventory[world.equipped_hat_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hat_item = ""

	var loaded_equipped_hair_item = data.get("equipped_hair_item", world.equipped_hair_item)

	if loaded_equipped_hair_item == null:
		loaded_equipped_hair_item = ""

	world.equipped_hair_item = _safe_string(loaded_equipped_hair_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hair_item != "" and (not world.hair_inventory.has(world.equipped_hair_item) or _safe_int(world.hair_inventory[world.equipped_hair_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hair_item = ""

	var loaded_equipped_eyewear_item = data.get("equipped_eyewear_item", world.equipped_eyewear_item)

	if loaded_equipped_eyewear_item == null:
		loaded_equipped_eyewear_item = ""

	world.equipped_eyewear_item = _safe_string(loaded_equipped_eyewear_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_eyewear_item != "" and (not world.eyewear_inventory.has(world.equipped_eyewear_item) or _safe_int(world.eyewear_inventory[world.equipped_eyewear_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_eyewear_item = ""

	var loaded_equipped_beard_item = data.get("equipped_beard_item", world.equipped_beard_item)

	if loaded_equipped_beard_item == null:
		loaded_equipped_beard_item = ""

	world.equipped_beard_item = _safe_string(loaded_equipped_beard_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_beard_item != "" and (not world.beard_inventory.has(world.equipped_beard_item) or _safe_int(world.beard_inventory[world.equipped_beard_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_beard_item = ""

	var loaded_equipped_body_accessory_item = data.get("equipped_body_accessory_item", world.equipped_body_accessory_item)

	if loaded_equipped_body_accessory_item == null:
		loaded_equipped_body_accessory_item = ""

	world.equipped_body_accessory_item = _safe_string(loaded_equipped_body_accessory_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_body_accessory_item != "" and (not world.body_accessory_inventory.has(world.equipped_body_accessory_item) or _safe_int(world.body_accessory_inventory[world.equipped_body_accessory_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_body_accessory_item = ""

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

	var loaded_equipped_ride_item = data.get("equipped_ride_item", world.equipped_ride_item)

	if loaded_equipped_ride_item == null:
		loaded_equipped_ride_item = ""

	world.equipped_ride_item = _safe_string(loaded_equipped_ride_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_ride_item != "" and (not world.ride_inventory.has(world.equipped_ride_item) or _safe_int(world.ride_inventory[world.equipped_ride_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_ride_item = ""

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


func restore_local_transaction_loadout(snapshot: Dictionary, skip_hotbar_render: bool = false):
	if world == null:
		return

	var previous_primary_tool = str(snapshot.get("primary_hotbar_tool", "punch"))
	if previous_primary_tool == "punch" or previous_primary_tool == "wrench":
		world.primary_hotbar_tool = previous_primary_tool

	# Restore the LOCAL selected item/category before touching hotbar_items or
	# calling normalize_hotbar() below. apply_player_data() (called right before
	# this function, earlier in apply_network_player_state) just set
	# world.selected_item_type/category from the SERVER's copy, which can be
	# stale or simply different from what the player has selected locally right
	# now. normalize_hotbar() force-inserts whatever world.selected_item_type
	# currently is into hotbar slot 2 if it isn't already present in the array
	# -- so if we normalize before restoring the local selection, the server's
	# stale selected item gets spliced into the freshly-restored local hotbar,
	# displacing a real slot. This is the same stale-selection phantom-insert
	# bug as the original hotbar shuffle fix, just triggered from the network
	# sync path instead of a local inventory click. Same fix: select before
	# rebuilding the hotbar array.
	var previous_selected_type = str(snapshot.get("selected_item_type", world.selected_item_type))
	var previous_selected_category = str(snapshot.get("selected_item_category", world.selected_item_category))
	if can_restore_local_loadout_item(previous_selected_type, previous_selected_category):
		world.selected_item_type = previous_selected_type
		world.selected_item_category = previous_selected_category

	var previous_hotbar_items = snapshot.get("hotbar_items", [])
	var previous_hotbar_categories = snapshot.get("hotbar_item_categories", [])
	if previous_hotbar_items is Array and previous_hotbar_categories is Array and previous_hotbar_items.size() > 0:
		world.hotbar_items = previous_hotbar_items.duplicate(true)
		world.hotbar_item_categories = previous_hotbar_categories.duplicate(true)
		world.normalize_hotbar()
		# See apply_player_data's skip_hotbar_render: apply_network_player_state
		# does exactly one final setup_hotbar() after this returns, so skip the
		# intermediate rebuild here too instead of rendering twice per update.
		if not skip_hotbar_render:
			world.setup_hotbar()

	var previous_equipped_tool = str(snapshot.get("equipped_tool", ""))
	if previous_equipped_tool == "" or can_restore_local_loadout_item(previous_equipped_tool, "tool"):
		world.equipped_tool = previous_equipped_tool

	var previous_back_item = str(snapshot.get("equipped_back_item", ""))
	if previous_back_item == "" or can_restore_local_loadout_item(previous_back_item, "back"):
		world.equipped_back_item = previous_back_item

	var previous_hat_item = str(snapshot.get("equipped_hat_item", ""))
	if previous_hat_item == "" or can_restore_local_loadout_item(previous_hat_item, "hat"):
		world.equipped_hat_item = previous_hat_item

	var previous_hair_item = str(snapshot.get("equipped_hair_item", ""))
	if previous_hair_item == "" or can_restore_local_loadout_item(previous_hair_item, "hair"):
		world.equipped_hair_item = previous_hair_item

	var previous_eyewear_item = str(snapshot.get("equipped_eyewear_item", ""))
	if previous_eyewear_item == "" or can_restore_local_loadout_item(previous_eyewear_item, "eyewear"):
		world.equipped_eyewear_item = previous_eyewear_item

	var previous_beard_item = str(snapshot.get("equipped_beard_item", ""))
	if previous_beard_item == "" or can_restore_local_loadout_item(previous_beard_item, "beard"):
		world.equipped_beard_item = previous_beard_item

	var previous_body_accessory_item = str(snapshot.get("equipped_body_accessory_item", ""))
	if previous_body_accessory_item == "" or can_restore_local_loadout_item(previous_body_accessory_item, "body_accessory"):
		world.equipped_body_accessory_item = previous_body_accessory_item

	var previous_shirt_item = str(snapshot.get("equipped_shirt_item", ""))
	if previous_shirt_item == "" or can_restore_local_loadout_item(previous_shirt_item, "shirt"):
		world.equipped_shirt_item = previous_shirt_item

	var previous_pants_item = str(snapshot.get("equipped_pants_item", ""))
	if previous_pants_item == "" or can_restore_local_loadout_item(previous_pants_item, "pants"):
		world.equipped_pants_item = previous_pants_item

	var previous_shoes_item = str(snapshot.get("equipped_shoes_item", ""))
	if previous_shoes_item == "" or can_restore_local_loadout_item(previous_shoes_item, "shoes"):
		world.equipped_shoes_item = previous_shoes_item

	var previous_ride_item = str(snapshot.get("equipped_ride_item", ""))
	if previous_ride_item == "" or can_restore_local_loadout_item(previous_ride_item, "ride"):
		world.equipped_ride_item = previous_ride_item

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

	var payload_saved_at := _safe_string(player_data.get("saved_at", ""), "", MAX_INVENTORY_STRING_LEN)
	var payload_hash = get_player_data_dedup_hash(player_data)
	var now_ms = Time.get_ticks_msec()
	var current_local_hash = get_current_player_state_dedup_hash()
	if normalized_username == last_server_player_state_username and payload_saved_at != "" and payload_saved_at == last_server_player_state_saved_at and current_local_hash == payload_hash:
		network_player_state_request_in_flight = false
		return
	if current_local_hash == payload_hash:
		last_server_player_state_username = normalized_username
		last_server_player_state_hash = payload_hash
		last_server_player_state_saved_at = payload_saved_at
		last_server_player_state_applied_ms = now_ms
		network_player_state_request_in_flight = false
		return

	if normalized_username == last_server_player_state_username and payload_hash == last_server_player_state_hash and current_local_hash == payload_hash:
		if now_ms - last_server_player_state_applied_ms <= DUPLICATE_SERVER_PLAYER_STATE_WINDOW_MS:
			network_player_state_request_in_flight = false
			return

	if _safe_int(player_data.get("legacy_client_inventory_import_revision", 0), 0, 0, LEGACY_SERVER_INVENTORY_IMPORT_REVISION) >= LEGACY_SERVER_INVENTORY_IMPORT_REVISION:
		mark_legacy_server_inventory_import_confirmed()

	var preserve_local_loadout = bool(data.get("preserve_local_loadout", false))
	var should_select_first_hotbar_slot = not preserve_local_loadout and str(data.get("purpose", "")).strip_edges().to_lower() == "active_profile"
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
			"equipped_hat_item": str(world.equipped_hat_item) if world.equipped_hat_item != null else "",
			"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
			"equipped_eyewear_item": str(world.equipped_eyewear_item) if world.equipped_eyewear_item != null else "",
		"equipped_beard_item": str(world.equipped_beard_item) if world.equipped_beard_item != null else "",
			"equipped_body_accessory_item": str(world.equipped_body_accessory_item) if world.equipped_body_accessory_item != null else "",
			"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
			"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
			"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else "",
			"equipped_ride_item": str(world.equipped_ride_item) if world.equipped_ride_item != null else ""
		}

	applying_server_player_data = true
	# apply_player_data() and restore_local_transaction_loadout() each used to call
	# world.setup_hotbar() independently, so every single server player_state push
	# (which happens on nearly every inventory-affecting event -- not just literal
	# "player_state" messages, but trade/inventory_delta/etc acks too, often every
	# ~90ms in bursts) triggered two full hotbar rebuilds back-to-back. That double
	# rebuild is what caused the hotbar to visibly flicker/reset during rapid
	# item pickup. Both sub-calls now skip their own intermediate render, and we
	# render the settled hotbar exactly once below, mirroring the same
	# render-once pattern already used for update_equipment_visual().
	apply_player_data(player_data, true)
	if preserve_local_loadout:
		restore_local_transaction_loadout(local_loadout_snapshot, true)
	elif should_select_first_hotbar_slot:
		world.normalize_hotbar()
		select_first_hotbar_slot_silent()
	# Rendering exactly once per call was still not enough on its own: this
	# function fires on nearly every server round-trip, not just discrete hotbar
	# edits, and world.setup_hotbar() always does the expensive full rebuild
	# (destroys/reinstantiates or reparents the Hotbar scene and rebuilds all 6
	# slot nodes) even when the resulting hotbar_items are identical to what's
	# already on screen. world.update_hotbar() is the cheap incremental path --
	# it only updates each existing slot's icon/frame/count/selection in place,
	# and transparently falls back to the full rebuild only when the scene
	# structurally needs it (no hotbar yet, e.g. first login, or slot count
	# changed). Using it here removes the per-sync flicker while staying correct.
	world.update_hotbar()
	world.player_data_loaded_from_file = true
	save_player_data(false)
	applying_server_player_data = false
	# Equipment refreshes were suppressed for the whole apply above, because the
	# server copy is written before the local loadout is restored over it. Render
	# the settled loadout exactly once, so the previously equipped item is never
	# put on screen on the way through.
	world.update_equipment_visual()
	last_server_player_state_username = normalized_username
	last_server_player_state_hash = payload_hash
	last_server_player_state_saved_at = payload_saved_at
	last_server_player_state_applied_ms = now_ms
	network_player_state_request_in_flight = false

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


func runtime_fish_value_to_count(raw_value) -> int:
	if raw_value is int:
		return max(0, int(raw_value))
	if raw_value is float:
		var raw_float: float = float(raw_value)
		if not is_finite(raw_float) or raw_float <= 0.0:
			return 0
		return max(0, int(floor(raw_float)))
	if raw_value is String:
		var text = raw_value.strip_edges()
		if text.is_valid_int():
			return max(0, int(text))
		if text.is_valid_float():
			return max(0, int(floor(float(text))))
	return 0


func legacy_fish_tenths_to_count(raw_value) -> int:
	var tenths: int = runtime_fish_value_to_count(raw_value)
	if tenths <= 0:
		return 0
	return max(1, int(round(float(tenths) / 10.0)))


func get_fish_inventory_count_save_data() -> Dictionary:
	var result: Dictionary = {}
	if world == null or not (world.fish_inventory is Dictionary):
		return result
	for item_name in world.fish_inventory.keys():
		var clean_item_name: String = _safe_string(item_name, "", MAX_INVENTORY_STRING_LEN)
		if clean_item_name == "":
			continue
		var count: int = runtime_fish_value_to_count(world.fish_inventory.get(item_name, 0))
		if count > 0:
			result[clean_item_name] = count
	return result


func safe_fish_count_from_save(raw_value, unit: String = "") -> int:
	if raw_value is Dictionary:
		if raw_value.has("count"):
			return runtime_fish_value_to_count(raw_value.get("count", 0))
		if raw_value.has("weight_tenths"):
			return legacy_fish_tenths_to_count(raw_value.get("weight_tenths", 0))
		if raw_value.has("amount"):
			raw_value = raw_value.get("amount", 0.0)
		elif raw_value.has("weight_lb"):
			raw_value = raw_value.get("weight_lb", 0.0)
		else:
			return 0

	if unit == "tenths_lb":
		return legacy_fish_tenths_to_count(raw_value)
	return runtime_fish_value_to_count(raw_value)


func apply_saved_fish_count_inventory(saved_inventory, _preserve_default_if_missing: bool, unit: String = ""):
	if not (saved_inventory is Dictionary):
		saved_inventory = {}

	world.fish_inventory.clear()

	for item_name in saved_inventory.keys():
		var clean_item_name: String = _safe_string(item_name, "", MAX_INVENTORY_STRING_LEN)
		if clean_item_name == "":
			continue
		var safe_count: int = safe_fish_count_from_save(saved_inventory.get(item_name, 0.0), unit)
		if safe_count > 0:
			world.fish_inventory[clean_item_name] = safe_count


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
		"inventory_slot_count": _safe_int(player_data.get("inventory_slot_count", player_data.get("inventory_slots", 20)), 20, 20, 300),
		"equipped_tool": _safe_string(player_data.get("equipped_tool", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_back_item": _safe_string(player_data.get("equipped_back_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_hat_item": _safe_string(player_data.get("equipped_hat_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_hair_item": _safe_string(player_data.get("equipped_hair_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_eyewear_item": _safe_string(player_data.get("equipped_eyewear_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_beard_item": _safe_string(player_data.get("equipped_beard_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_body_accessory_item": _safe_string(player_data.get("equipped_body_accessory_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_shirt_item": _safe_string(player_data.get("equipped_shirt_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_pants_item": _safe_string(player_data.get("equipped_pants_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_shoes_item": _safe_string(player_data.get("equipped_shoes_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"equipped_ride_item": _safe_string(player_data.get("equipped_ride_item", ""), "", MAX_INVENTORY_STRING_LEN),
		"inventory": player_data.get("inventory", {}) if player_data.get("inventory", null) is Dictionary else {},
		"seed_inventory": player_data.get("seed_inventory", {}) if player_data.get("seed_inventory", null) is Dictionary else {},
		"tool_inventory": player_data.get("tool_inventory", {}) if player_data.get("tool_inventory", null) is Dictionary else {},
		"back_inventory": player_data.get("back_inventory", {}) if player_data.get("back_inventory", null) is Dictionary else {},
		"hat_inventory": player_data.get("hat_inventory", {}) if player_data.get("hat_inventory", null) is Dictionary else {},
		"hair_inventory": player_data.get("hair_inventory", {}) if player_data.get("hair_inventory", null) is Dictionary else {},
		"eyewear_inventory": player_data.get("eyewear_inventory", {}) if player_data.get("eyewear_inventory", null) is Dictionary else {},
		"beard_inventory": player_data.get("beard_inventory", {}) if player_data.get("beard_inventory", null) is Dictionary else {},
		"body_accessory_inventory": player_data.get("body_accessory_inventory", {}) if player_data.get("body_accessory_inventory", null) is Dictionary else {},
		"shirt_inventory": player_data.get("shirt_inventory", {}) if player_data.get("shirt_inventory", null) is Dictionary else {},
		"pants_inventory": player_data.get("pants_inventory", {}) if player_data.get("pants_inventory", null) is Dictionary else {},
		"shoes_inventory": player_data.get("shoes_inventory", {}) if player_data.get("shoes_inventory", null) is Dictionary else {},
		"ride_inventory": player_data.get("ride_inventory", {}) if player_data.get("ride_inventory", null) is Dictionary else {},
		"currency_inventory": player_data.get("currency_inventory", {}) if player_data.get("currency_inventory", null) is Dictionary else {},
		"material_inventory": player_data.get("material_inventory", {}) if player_data.get("material_inventory", null) is Dictionary else {},
		"lure_inventory": player_data.get("lure_inventory", {}) if player_data.get("lure_inventory", null) is Dictionary else {},
		"fish_inventory": player_data.get("fish_inventory", {}) if player_data.get("fish_inventory", null) is Dictionary else {},
		"fish_inventory_unit": _safe_string(player_data.get("fish_inventory_unit", ""), "", MAX_INVENTORY_STRING_LEN),
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
		"inventory_slot_count": world.get_inventory_slot_count() if world.has_method("get_inventory_slot_count") else 20,
		"equipped_tool": _safe_string(world.equipped_tool, "", MAX_INVENTORY_STRING_LEN),
		"equipped_back_item": _safe_string(world.equipped_back_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_hat_item": _safe_string(world.equipped_hat_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_hair_item": _safe_string(world.equipped_hair_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_eyewear_item": _safe_string(world.equipped_eyewear_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_beard_item": _safe_string(world.equipped_beard_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_body_accessory_item": _safe_string(world.equipped_body_accessory_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_shirt_item": _safe_string(world.equipped_shirt_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_pants_item": _safe_string(world.equipped_pants_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_shoes_item": _safe_string(world.equipped_shoes_item, "", MAX_INVENTORY_STRING_LEN),
		"equipped_ride_item": _safe_string(world.equipped_ride_item, "", MAX_INVENTORY_STRING_LEN),
		"inventory": world.inventory.duplicate(true) if world.inventory is Dictionary else {},
		"seed_inventory": world.seed_inventory.duplicate(true) if world.seed_inventory is Dictionary else {},
		"tool_inventory": world.tool_inventory.duplicate(true) if world.tool_inventory is Dictionary else {},
		"back_inventory": world.back_inventory.duplicate(true) if world.back_inventory is Dictionary else {},
		"hat_inventory": world.hat_inventory.duplicate(true) if world.hat_inventory is Dictionary else {},
		"hair_inventory": world.hair_inventory.duplicate(true) if world.hair_inventory is Dictionary else {},
		"eyewear_inventory": world.eyewear_inventory.duplicate(true) if world.eyewear_inventory is Dictionary else {},
		"beard_inventory": world.beard_inventory.duplicate(true) if world.beard_inventory is Dictionary else {},
		"body_accessory_inventory": world.body_accessory_inventory.duplicate(true) if world.body_accessory_inventory is Dictionary else {},
		"shirt_inventory": world.shirt_inventory.duplicate(true) if world.shirt_inventory is Dictionary else {},
		"pants_inventory": world.pants_inventory.duplicate(true) if world.pants_inventory is Dictionary else {},
		"shoes_inventory": world.shoes_inventory.duplicate(true) if world.shoes_inventory is Dictionary else {},
		"ride_inventory": world.ride_inventory.duplicate(true) if world.ride_inventory is Dictionary else {},
		"currency_inventory": world.currency_inventory.duplicate(true) if world.currency_inventory is Dictionary else {},
		"material_inventory": world.material_inventory.duplicate(true) if world.material_inventory is Dictionary else {},
		"lure_inventory": world.lure_inventory.duplicate(true) if world.lure_inventory is Dictionary else {},
		"fish_inventory": get_fish_inventory_count_save_data(),
		"fish_inventory_unit": "count",
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
	if _is_dev_test_login_active():
		return false
	if _is_netfox_real_server_launch():
		return false

	var clean_world_name = str(world.current_world_name).strip_edges()
	if clean_world_name == "":
		return false

	return true


func should_expect_server_world_state() -> bool:
	if world == null:
		return false
	if _is_dev_test_login_active():
		return false
	if _is_netfox_real_server_launch():
		return false

	var clean_world_name = str(world.current_world_name).strip_edges()
	if clean_world_name == "":
		return false

	return true


func load_clean_server_world_base(skip_clear: bool = false):
	debug_action_position_flow("load_clean_server_world_base start")
	if not skip_clear:
		clear_world()

	# Important performance fix:
	# Do not generate/build a full local terrain copy while waiting for the server
	# world_state. The server will send the real foreground/background blocks and
	# world_state_sync_manager.gd will build those in batches. Building a generated
	# world here and then clearing/rebuilding it again was causing a huge freeze on
	# world entry.
	world.set_meta("world_bulk_load_in_progress", true)
	world.set_meta("world_bulk_load_reason", "waiting_for_server_world_state")
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + str(world.current_world_name).to_upper() + " from server...")

	if not FAST_WORLD_ENTRY_SKIP_SERVER_BASE_GENERATION:
		world.generate_world()
		world.ensure_entrance_gate()
		debug_action_position_flow("load_clean_server_world_base place at entrance")
		place_player_at_current_entrance_gate_for_world_entry(true)
		world.setup_world_camera_limits()
		world.set_default_camera_zoom_silent()
		world.clamp_player_to_world()

	if world.has_method("load_world_lock_save_data"):
		world.load_world_lock_save_data({})
	if world.has_method("load_area_locks_save_data"):
		world.load_area_locks_save_data([])

	ensure_player_data_loaded_for_world_entry()
	world.update_equipment_visual()
	# Keep UI light while waiting for server state; avoid rebuilding gameplay UI
	# before the real world has been applied.
	debug_action_position_flow("load_clean_server_world_base end")


func ensure_player_data_loaded_for_world_entry():
	if world == null:
		return
	if bool(world.player_data_loaded_from_file):
		return

	load_player_data(false)


func _is_dev_test_login_active() -> bool:
	return MovementMode != null and MovementMode.has_method("is_dev_test_login_active") and bool(MovementMode.is_dev_test_login_active())


func _is_netfox_real_server_launch() -> bool:
	return MovementMode != null and MovementMode.has_method("is_netfox_real_server_launch") and bool(MovementMode.is_netfox_real_server_launch())


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
		"hat_inventory": world.hat_inventory,
		"hair_inventory": world.hair_inventory,
		"eyewear_inventory": world.eyewear_inventory,
		"beard_inventory": world.beard_inventory,
		"body_accessory_inventory": world.body_accessory_inventory,
		"shirt_inventory": world.shirt_inventory,
		"pants_inventory": world.pants_inventory,
		"shoes_inventory": world.shoes_inventory,
		"ride_inventory": world.ride_inventory,
		"currency_inventory": world.currency_inventory,
		"material_inventory": world.material_inventory,
		"lure_inventory": world.lure_inventory,
		"fish_inventory": get_fish_inventory_count_save_data(),
		"fish_inventory_unit": "count",
		"fishing_records": world.fishing_manager.get_fishing_records_save_data() if world.fishing_manager != null and world.fishing_manager.has_method("get_fishing_records_save_data") else {},
		"equipped_tool": str(world.equipped_tool) if world.equipped_tool != null else "",
		"equipped_back_item": str(world.equipped_back_item) if world.equipped_back_item != null else "",
		"equipped_hat_item": str(world.equipped_hat_item) if world.equipped_hat_item != null else "",
		"equipped_hair_item": str(world.equipped_hair_item) if world.equipped_hair_item != null else "",
		"equipped_eyewear_item": str(world.equipped_eyewear_item) if world.equipped_eyewear_item != null else "",
		"equipped_beard_item": str(world.equipped_beard_item) if world.equipped_beard_item != null else "",
		"equipped_body_accessory_item": str(world.equipped_body_accessory_item) if world.equipped_body_accessory_item != null else "",
		"equipped_shirt_item": str(world.equipped_shirt_item) if world.equipped_shirt_item != null else "",
		"equipped_pants_item": str(world.equipped_pants_item) if world.equipped_pants_item != null else "",
		"equipped_shoes_item": str(world.equipped_shoes_item) if world.equipped_shoes_item != null else "",
		"equipped_ride_item": str(world.equipped_ride_item) if world.equipped_ride_item != null else "",
		"world_lock": world.get_world_lock_save_data() if world.has_method("get_world_lock_save_data") else {},
		"area_locks": world.get_area_locks_save_data() if world.has_method("get_area_locks_save_data") else [],
		"electrical_layer": world.get_electrical_save_data() if world.has_method("get_electrical_save_data") else [],
		"foreground": {},
		"background": {},
		"blocks": [],
		"background_blocks": [],
		"item_drops": [],
		"planted_seeds": []
	}

	for grid_pos in world.blocks.keys():
		var block_type := str(world.blocks[grid_pos].get("type", ""))
		var atlas_item_id := _get_saved_atlas_item_id(block_type, world.blocks[grid_pos])
		if atlas_item_id > 0:
			save_data["foreground"][_saved_layer_key(grid_pos)] = atlas_item_id
		save_data["blocks"].append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": block_type,
			"item_id": atlas_item_id,
			"entrance_locked": bool(world.blocks[grid_pos].get("entrance_locked", false)),
			"sign_text": str(world.blocks[grid_pos].get("sign_text", "")),
			"toggle_on": bool(world.blocks[grid_pos].get("toggle_on", false))
		})

	var background_blocks = get_background_blocks_dictionary()

	for grid_pos in background_blocks.keys():
		var background_type := str(background_blocks[grid_pos].get("type", ""))
		var background_item_id := _get_saved_atlas_item_id(background_type, background_blocks[grid_pos])
		if background_item_id > 0:
			save_data["background"][_saved_layer_key(grid_pos)] = background_item_id
		save_data["background_blocks"].append({
			"x": grid_pos.x,
			"y": grid_pos.y,
			"type": background_type,
			"item_id": background_item_id
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
		place_player_at_current_entrance_gate_for_world_entry(true)
		world.setup_world_camera_limits()
		world.set_default_camera_zoom_silent()
		world.clamp_player_to_world()
		if world.has_method("load_world_lock_save_data"):
			world.load_world_lock_save_data({})
		if world.has_method("load_area_locks_save_data"):
			world.load_area_locks_save_data([])

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
		place_player_at_current_entrance_gate_for_world_entry(true)
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
	if world.has_method("load_area_locks_save_data"):
		var saved_world_lock = data.get("world_lock", {})
		var nested_area_locks = saved_world_lock.get("area_locks", []) if saved_world_lock is Dictionary else []
		world.load_area_locks_save_data(data.get("area_locks", nested_area_locks))
	if world.has_method("load_electrical_save_data"):
		world.load_electrical_save_data(data.get("electrical_layer", data.get("electrical_tiles", [])))

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

	world.player_health = _safe_int(data.get("player_health", 10), 10, 0, MAX_PLAYER_HEALTH)

	var saved_inventory = data.get("inventory", {})

	apply_saved_inventory_counts(world.inventory, saved_inventory, false)

	apply_saved_inventory_counts(world.seed_inventory, data.get("seed_inventory", {}), false)
	apply_saved_inventory_counts(world.tool_inventory, data.get("tool_inventory", {}), true)
	apply_saved_inventory_counts(world.back_inventory, data.get("back_inventory", {}), true)
	apply_saved_inventory_counts(world.hat_inventory, data.get("hat_inventory", {}), true)
	apply_saved_inventory_counts(world.hair_inventory, data.get("hair_inventory", {}), true)
	apply_saved_inventory_counts(world.eyewear_inventory, data.get("eyewear_inventory", {}), true)
	apply_saved_inventory_counts(world.beard_inventory, data.get("beard_inventory", {}), true)
	apply_saved_inventory_counts(world.body_accessory_inventory, data.get("body_accessory_inventory", {}), true)
	apply_saved_inventory_counts(world.shirt_inventory, data.get("shirt_inventory", {}), true)
	apply_saved_inventory_counts(world.pants_inventory, data.get("pants_inventory", {}), true)
	apply_saved_inventory_counts(world.shoes_inventory, data.get("shoes_inventory", {}), true)
	apply_saved_inventory_counts(world.ride_inventory, data.get("ride_inventory", {}), true)
	apply_saved_inventory_counts(world.currency_inventory, data.get("currency_inventory", {}), true)
	apply_saved_inventory_counts(world.material_inventory, data.get("material_inventory", {}), true)
	apply_saved_inventory_counts(world.lure_inventory, data.get("lure_inventory", {}), true)
	apply_saved_fish_count_inventory(data.get("fish_inventory", {}), true, str(data.get("fish_inventory_unit", "")))
	world.normalize_hotbar()
	world.setup_hotbar()
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

	var loaded_equipped_hat_item = data.get("equipped_hat_item", world.equipped_hat_item)
	if loaded_equipped_hat_item == null:
		loaded_equipped_hat_item = ""
	world.equipped_hat_item = _safe_string(loaded_equipped_hat_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hat_item != "" and (not world.hat_inventory.has(world.equipped_hat_item) or _safe_int(world.hat_inventory[world.equipped_hat_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hat_item = ""

	var loaded_equipped_hair_item = data.get("equipped_hair_item", world.equipped_hair_item)
	if loaded_equipped_hair_item == null:
		loaded_equipped_hair_item = ""
	world.equipped_hair_item = _safe_string(loaded_equipped_hair_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_hair_item != "" and (not world.hair_inventory.has(world.equipped_hair_item) or _safe_int(world.hair_inventory[world.equipped_hair_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_hair_item = ""

	var loaded_equipped_eyewear_item = data.get("equipped_eyewear_item", world.equipped_eyewear_item)
	if loaded_equipped_eyewear_item == null:
		loaded_equipped_eyewear_item = ""
	world.equipped_eyewear_item = _safe_string(loaded_equipped_eyewear_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_eyewear_item != "" and (not world.eyewear_inventory.has(world.equipped_eyewear_item) or _safe_int(world.eyewear_inventory[world.equipped_eyewear_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_eyewear_item = ""

	var loaded_equipped_beard_item = data.get("equipped_beard_item", world.equipped_beard_item)
	if loaded_equipped_beard_item == null:
		loaded_equipped_beard_item = ""
	world.equipped_beard_item = _safe_string(loaded_equipped_beard_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_beard_item != "" and (not world.beard_inventory.has(world.equipped_beard_item) or _safe_int(world.beard_inventory[world.equipped_beard_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_beard_item = ""

	var loaded_equipped_body_accessory_item = data.get("equipped_body_accessory_item", world.equipped_body_accessory_item)
	if loaded_equipped_body_accessory_item == null:
		loaded_equipped_body_accessory_item = ""
	world.equipped_body_accessory_item = _safe_string(loaded_equipped_body_accessory_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_body_accessory_item != "" and (not world.body_accessory_inventory.has(world.equipped_body_accessory_item) or _safe_int(world.body_accessory_inventory[world.equipped_body_accessory_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_body_accessory_item = ""

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

	var loaded_equipped_ride_item = data.get("equipped_ride_item", world.equipped_ride_item)
	if loaded_equipped_ride_item == null:
		loaded_equipped_ride_item = ""
	world.equipped_ride_item = _safe_string(loaded_equipped_ride_item, "", MAX_INVENTORY_STRING_LEN)

	if world.equipped_ride_item != "" and (not world.ride_inventory.has(world.equipped_ride_item) or _safe_int(world.ride_inventory[world.equipped_ride_item], 0, 0, MAX_INVENTORY_STACK) <= 0):
		world.equipped_ride_item = ""

	var saved_blocks = _normalize_saved_layer_entries(data.get("foreground", data.get("blocks", [])))

	for block_data in saved_blocks:
		if not (block_data is Dictionary):
			continue

		if not block_data.has("x") or not block_data.has("y"):
			continue

		var block_type = _resolve_saved_block_type(block_data)
		if block_type == "":
			continue

		var grid_pos = Vector2i(
			_safe_int(block_data.get("x", 0), 0, 0, max(world.WORLD_WIDTH - 1, 0)),
			_safe_int(block_data.get("y", 0), 0, 0, max(world.WORLD_HEIGHT - 1, 0))
		)
		if not world.is_grid_inside_world(grid_pos):
			continue

		if world.item_database.has(block_type) or world.block_textures.has(block_type):
			world.create_block(grid_pos, block_type)

			if world.is_wooden_entrance_block(block_type):
				world.set_wooden_entrance_locked(grid_pos, _safe_bool(block_data.get("entrance_locked", false), false))

			if world.is_sign_block(block_type) and world.blocks.has(grid_pos):
				world.blocks[grid_pos]["sign_text"] = _safe_string(block_data.get("sign_text", ""), "", 128)
				world.update_sign_text_visual(grid_pos)

			if world.blocks.has(grid_pos) and world.item_database.has(block_type) and bool(world.item_database[block_type].get("toggle_block", false)):
				var state_key = str(world.item_database[block_type].get("toggle_state_key", "toggle_on"))
				world.blocks[grid_pos][state_key] = _safe_bool(block_data.get("toggle_on", false), false)
				if world.block_manager != null and world.block_manager.has_method("update_toggle_block_visual"):
					world.block_manager.update_toggle_block_visual(grid_pos)

	var saved_background_blocks = _normalize_saved_layer_entries(data.get("background", data.get("background_blocks", [])))

	load_background_blocks_from_data(saved_background_blocks)

	if saved_background_blocks.size() == 0:
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
	place_player_at_current_entrance_gate_for_world_entry(true)

	# Current system keeps player inventory/equipment global, not per world.
	# This restores player data after old world saves try to load old inventory fields.
	load_player_data_from_current_or_legacy(data)

	world.setup_world_camera_limits()
	world.set_default_camera_zoom_silent()
	world.clamp_player_to_world()
	if world.world_lock_manager != null and world.world_lock_manager.has_method("reconcile_world_lock_state_with_blocks"):
		world.world_lock_manager.reconcile_world_lock_state_with_blocks()
	world.update_equipment_visual()
	world.update_all_ui()

	print("World loaded: " + world.current_world_name)


func clear_world():
	clear_background_blocks()
	if world.has_method("clear_electrical_layer"):
		world.clear_electrical_layer()
	if world.block_manager != null and world.block_manager.has_method("clear_all_tilemap_cells"):
		world.block_manager.clear_all_tilemap_cells()

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks[grid_pos]
		if block_data is Dictionary and world.block_manager != null and world.block_manager.has_method("clear_foreground_crack_visual_for_data"):
			world.block_manager.clear_foreground_crack_visual_for_data(block_data)
		var block_node = block_data.get("node", null) if block_data is Dictionary else null
		if block_node != null and is_instance_valid(block_node):
			retire_block_node_collision_for_removal(block_node)
			block_node.queue_free()

	world.blocks.clear()
	world.terrain_surface_y.clear()
	world.block_hit_progress.clear()
	world.block_hit_timers.clear()
	if world.has_method("load_world_lock_save_data"):
		world.load_world_lock_save_data({})
	if world.world_lock_manager != null and world.world_lock_manager.has_method("load_area_locks_save_data"):
		world.world_lock_manager.load_area_locks_save_data([])
	if "active_checkpoint_grid" in world:
		world.active_checkpoint_grid = world.INVALID_GRID_POS
	if "active_checkpoint_world" in world:
		world.active_checkpoint_world = ""
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
