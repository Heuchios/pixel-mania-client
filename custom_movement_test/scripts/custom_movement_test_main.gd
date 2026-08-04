extends Node2D
class_name CustomMovementTestMain

const Protocol = preload("res://custom_movement_test/scripts/custom_movement_protocol.gd")
const SnapshotInterpolator = preload("res://custom_movement_test/scripts/custom_snapshot_interpolator.gd")
const PLAYER_SCENE := preload("res://custom_movement_test/scenes/custom_real_player.tscn")
const InventoryManagerScript = preload("res://Scripts/inventory_manager.gd")
const DropManagerScript = preload("res://Scripts/drop_manager.gd")
const ItemDatabaseScript = preload("res://Scripts/item_database.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const RPC_ROOT_NAME := "CustomMovementTest"
const WEBSOCKET_BLOCK_ACTION_REACH_PIXELS := 128.0
const BLOCK_SIZE := 32
const WORLD_WIDTH := 100
const WORLD_HEIGHT := 70
const PICKUP_RANGE := 28.0
const HOTBAR_SLOT_COUNT := 6
const MAX_ITEM_STACK_SIZE := 400
const GEM_CURRENCY_ITEM_ID := "gem"
const GEM_CURRENCY_CAP := 100000000000
const CAMERA_ZOOM_DEFAULT := 3.0
const INVALID_GRID_POS := Vector2i(999999, 999999)
const SEED_BOX_TEXTURE_PATH := "res://Assets/seeds/seed_box.png"
const SEED_ICON_PREVIEW_MAX_SIZE := 10
const SEED_ICON_PREVIEW_TOP := 13
const SEED_ICON_PREVIEW_OFFSET := Vector2i(-4, -2)
const SEED_DROP_ICON_PREVIEW_MAX_SIZE := 10
const SEED_DROP_ICON_PREVIEW_TOP := 14
const SEED_DROP_ICON_PREVIEW_OFFSET := Vector2i(-3, -2)
const DEFAULT_CUSTOM_WORLD := "TEST"

@onready var players_root: Node2D = $Players
@onready var local_players_root: Node2D = $LocalPlayers
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = _find_info_label()
@onready var test_world: Node = get_node_or_null("World")
@onready var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
@onready var inventory_label: Label = get_node_or_null("UI/InventoryLabel") as Label

var is_server := false
var is_client := false
var debug_console_enabled := false
var auto_input_enabled := false
var collision_debug_enabled := false
var real_world_test_enabled := false
var requested_world_name := ""
var current_world_name := DEFAULT_CUSTOM_WORLD
var in_world := true
var phase_g_block_actions_notice_printed := false
var backend_actions_enabled := false
var backend_dev_login_requested := false
var backend_dev_profile_name := "uso"
var backend_login_request_sent := false
var backend_login_last_request_msec := 0
var backend_login_attempts := 0
var backend_auth_error_message := ""
var fallback_backend_login_requested := false
var backend_actions_ready := false
var backend_ws_connected := false
var backend_authenticated := false
var backend_session_id := ""
var backend_account_id := ""
var backend_profile_id := ""
var backend_game_player_id := ""
var backend_username := ""
var backend_world_id := DEFAULT_CUSTOM_WORLD
var backend_inventory_loaded := false
var backend_world_joined := false
var backend_join_world_request_sent := false
var backend_player_state_request_sent := false
var selected_place_block := "dirt"
var selected_place_layer := "foreground"
var last_backend_player_state: Dictionary = {}
var processed_block_update_keys: Dictionary = {}
var processed_block_update_order: Array = []
var processed_inventory_delta_keys: Dictionary = {}
var processed_inventory_delta_order: Array = []
var max_runtime_seconds := 0.0
var runtime_seconds := 0.0
var log_file_path := ""
var log_file: FileAccess = null
var remote_interpolation_delay_ms := Protocol.INTERPOLATION_DELAY_MS
var server_tick := 0
var snapshot_timer := 0.0
var debug_log_timer := 0.0
var host := Protocol.ADDRESS
var port := Protocol.PORT

var server_players: Dictionary = {}
var server_input_queues: Dictionary = {}
var server_last_processed_input: Dictionary = {}
var server_last_input: Dictionary = {}
var server_spawn_slots: Dictionary = {}
var server_next_spawn_slot := 0

var local_peer_id := 0
var client_input_sequence := 0
var client_tick := 0
var last_processed_input := 0
var local_prediction_error := 0.0
var local_predicted_position := Vector2.ZERO
var local_predicted_velocity := Vector2.ZERO
var last_server_authoritative_position := Vector2.ZERO
var last_server_authoritative_velocity := Vector2.ZERO
var last_server_tick := 0
var correction_mode := "none"
var input_history: Dictionary = {}
var client_players: Dictionary = {}
var local_player = null
var interpolator := SnapshotInterpolator.new()

var player = null
var player_facing_direction := 1
var current_camera_zoom := CAMERA_ZOOM_DEFAULT
var inventory_manager = null
var drop_manager = null
var block_manager = null
var save_manager = null
var applying_network_world_update := false
var item_database: Dictionary = {}
var splice_recipes: Dictionary = {}
var tier_1_splice_balance: Dictionary = {}
var inventory: Dictionary = {}
var seed_inventory: Dictionary = {}
var tool_inventory: Dictionary = {}
var back_inventory: Dictionary = {}
var hair_inventory: Dictionary = {}
var eyewear_inventory: Dictionary = {}
var shirt_inventory: Dictionary = {}
var pants_inventory: Dictionary = {}
var shoes_inventory: Dictionary = {}
var currency_inventory: Dictionary = {}
var material_inventory: Dictionary = {}
var lure_inventory: Dictionary = {}
var fish_inventory: Dictionary = {}
var block_textures: Dictionary = {}
var seed_textures: Dictionary = {}
var tool_textures: Dictionary = {}
var back_textures: Dictionary = {}
var hair_textures: Dictionary = {}
var eyewear_textures: Dictionary = {}
var shirt_textures: Dictionary = {}
var pants_textures: Dictionary = {}
var shoes_textures: Dictionary = {}
var currency_textures: Dictionary = {}
var material_textures: Dictionary = {}
var lure_textures: Dictionary = {}
var fish_textures: Dictionary = {}
var seed_icon_texture_cache: Dictionary = {}
var seed_drop_icon_texture_cache: Dictionary = {}
var block_items: Array = []
var tool_items: Array = []
var back_items: Array = []
var hair_items: Array = []
var eyewear_items: Array = []
var shirt_items: Array = []
var pants_items: Array = []
var shoes_items: Array = []
var material_items: Array = []
var lure_items: Array = []
var fish_items: Array = []
var hotbar_items: Array = ["punch", "dirt", "grass", "stone", "wood", "leaf"]
var hotbar_item_categories: Array = ["tool", "block", "block", "block", "block", "block"]
var selected_item_type := "punch"
var selected_item_category := "tool"
var primary_hotbar_tool := "punch"
var equipped_tool := ""
var equipped_back_item := ""
var equipped_hair_item := ""
var equipped_eyewear_item := ""
var equipped_shirt_item := ""
var equipped_pants_item := ""
var equipped_shoes_item := ""
var blocks: Dictionary = {}
var dropped_items: Array = []


func _ready() -> void:
	if _is_phase_i_launch():
		print("[PhaseI] INVALID TEST: isolated custom movement scene is not accepted for Phase I.")
	_normalize_rpc_root_name()
	Engine.physics_ticks_per_second = Protocol.PHYSICS_TICK_RATE
	_parse_launch_args()
	_open_optional_log_file()
	_configure_real_world_test()
	_setup_real_world_inventory_bridge()
	_connect_multiplayer_signals()

	if is_server:
		_start_server()
	elif is_client:
		_start_client()
	else:
		_show_idle_instructions()


func _normalize_rpc_root_name() -> void:
	name = RPC_ROOT_NAME


func _process(_delta: float) -> void:
	_update_runtime_limit(_delta)
	_update_backend_bridge(_delta)
	_sync_real_ui_player_adapter()
	_update_real_item_drops(_delta)
	_update_camera()
	_update_info_label()
	_update_player_debug_labels()
	_update_debug_console(_delta)


func _physics_process(delta: float) -> void:
	if is_server:
		_server_physics(delta)
	elif is_client:
		_client_physics(delta)


func _parse_launch_args() -> void:
	var args := _all_args()
	var wants_server := args.has("--server") or args.has("--custom-movement-server")
	var wants_client := args.has("--client") or args.has("--custom-movement-client")
	is_server = wants_server and not wants_client
	is_client = wants_client and not wants_server
	debug_console_enabled = args.has("--custom-movement-debug")
	auto_input_enabled = args.has("--custom-movement-auto-input")
	collision_debug_enabled = args.has("--custom-collision-debug-on")
	real_world_test_enabled = args.has("--custom-movement-real-world-test")
	requested_world_name = _get_arg_value("--world", "")
	current_world_name = _safe_world_name(requested_world_name, DEFAULT_CUSTOM_WORLD)
	backend_actions_enabled = real_world_test_enabled and (args.has("--custom-movement-backend") or args.has("--custom-actions-enabled"))
	backend_dev_login_requested = args.has("--backend-dev-login") or backend_actions_enabled
	backend_dev_profile_name = _sanitize_dev_profile_name(_get_arg_value("--dev-profile", "uso"))
	selected_place_block = _sanitize_block_id(_get_arg_value("--custom-place-block", "dirt"), "dirt")
	selected_place_layer = _sanitize_layer(_get_arg_value("--custom-place-layer", "foreground"))
	max_runtime_seconds = max(0.0, float(_get_arg_value("--custom-movement-max-seconds", "0")))
	log_file_path = _get_arg_value("--custom-movement-log-file", "")
	remote_interpolation_delay_ms = clampi(
		int(_get_arg_value("--custom-interpolation-delay-ms", str(Protocol.INTERPOLATION_DELAY_MS))),
		0,
		250
	)
	interpolator.set_interpolation_delay_ms(remote_interpolation_delay_ms)
	host = _get_arg_value("--host", Protocol.ADDRESS)
	port = int(_get_arg_value("--port", str(Protocol.PORT)))


func _all_args() -> Array:
	var combined: Array = []
	for arg in OS.get_cmdline_args():
		combined.append(str(arg))
	for arg in OS.get_cmdline_user_args():
		var clean_arg := str(arg)
		if not combined.has(clean_arg):
			combined.append(clean_arg)
	return combined


func _is_phase_i_launch() -> bool:
	var args := _all_args()
	return args.has("--phase-i") or args.has("--phase-i-test")


func _get_arg_value(flag_name: String, default_value: String) -> String:
	var args := _all_args()
	for i in range(args.size()):
		var arg := str(args[i])
		if arg == flag_name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with(flag_name + "="):
			return arg.substr(flag_name.length() + 1)
	return default_value


func _safe_world_name(raw_world_name: String, default_value: String = DEFAULT_CUSTOM_WORLD) -> String:
	var clean := raw_world_name.strip_edges()
	if clean == "":
		clean = default_value.strip_edges()
	if clean == "":
		clean = DEFAULT_CUSTOM_WORLD
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	if result == "":
		result = DEFAULT_CUSTOM_WORLD
	return result.to_upper()


func _sanitize_dev_profile_name(raw_name: String) -> String:
	var clean := raw_name.strip_edges()
	if clean == "":
		clean = "uso"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		var code := clean.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or character == "_":
			result += character
	if result == "":
		result = "uso"
	return result.substr(0, min(result.length(), 24))


func _sanitize_block_id(raw_block_id: String, default_value: String = "dirt") -> String:
	var clean := raw_block_id.strip_edges().to_lower()
	if clean == "":
		clean = default_value
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
	if result == "":
		result = default_value
	return result


func _sanitize_layer(raw_layer: String) -> String:
	return "background" if raw_layer.strip_edges().to_lower() == "background" else "foreground"


func _open_optional_log_file() -> void:
	if log_file_path.strip_edges() == "":
		return

	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if log_file == null:
		push_warning("[CustomMovementTest] Could not open log file: %s" % log_file_path)
		return
	_log("[CustomMovementTest] File log started: %s" % log_file_path)


func _find_info_label() -> Label:
	var label: Label = get_node_or_null("InfoLabel") as Label
	if label != null:
		return label
	return get_node_or_null("DebugLabel") as Label


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")


func _connect_backend_bridge_signal() -> void:
	var network := _get_network_manager()
	if network == null:
		return
	var auth_callback := Callable(self, "_on_backend_auth_finished")
	if network.has_signal("server_auth_finished") and not network.is_connected("server_auth_finished", auth_callback):
		network.connect("server_auth_finished", auth_callback)
	if network.has_method("sync_active_world_name_from_server"):
		network.sync_active_world_name_from_server(current_world_name)
	if network.has_method("request_server_connection"):
		network.request_server_connection()
	_update_backend_session_state(network)


func _on_backend_auth_finished(data: Dictionary) -> void:
	if not backend_actions_enabled:
		return
	var network := _get_network_manager()
	_update_backend_session_state(network, data)
	if bool(data.get("ok", false)):
		current_world_name = _safe_world_name(str(data.get("world", current_world_name)), current_world_name)
		backend_world_id = current_world_name
		backend_auth_error_message = ""
		_log("[PhaseH] Backend auth ready connected=%s authenticated=%s username=%s account_id=%s profile_id=%s game_player_id=%s world=%s" % [
			str(backend_ws_connected),
			str(backend_authenticated),
			backend_username,
			backend_account_id,
			backend_profile_id,
			backend_game_player_id,
			current_world_name,
		])
	else:
		backend_login_request_sent = false
		backend_auth_error_message = str(data.get("message", data.get("error", "")))
		_log("[PhaseH] Backend auth rejected during custom movement test: ok=%s message=%s type=%s" % [
			str(bool(data.get("ok", false))),
			str(data.get("message", data.get("error", ""))),
			str(data.get("type", "")),
		])


func _update_backend_bridge(_delta: float) -> void:
	if not backend_actions_enabled or not is_client:
		return

	var network := _get_network_manager()
	_update_backend_session_state(network)
	if network == null:
		return

	if network.has_method("sync_active_world_name_from_server"):
		network.sync_active_world_name_from_server(current_world_name)

	if backend_authenticated:
		if not backend_join_world_request_sent and network.has_method("send_join_world"):
			backend_join_world_request_sent = bool(network.send_join_world(current_world_name))
			_log("[PhaseH] Backend join world request world=%s sent=%s" % [current_world_name, str(backend_join_world_request_sent)])
		if not backend_player_state_request_sent:
			backend_player_state_request_sent = true
			request_network_player_state()
		var next_ready := backend_world_joined and backend_inventory_loaded
		if next_ready and not backend_actions_ready:
			backend_actions_ready = true
			_log("[PhaseH] Backend actions ready connected=%s authenticated=%s profile_id=%s game_player_id=%s world=%s inventory_loaded=%s peer=%d" % [
				str(backend_ws_connected),
				str(backend_authenticated),
				backend_profile_id,
				backend_game_player_id,
				current_world_name,
				str(backend_inventory_loaded),
				local_peer_id,
			])
		elif not next_ready:
			backend_actions_ready = false
		return

	if backend_dev_login_requested and _should_send_backend_dev_login(network):
		var request_id := ""
		if network.has_method("send_backend_dev_login"):
			request_id = str(network.send_backend_dev_login(backend_dev_profile_name, current_world_name))
		if request_id == "":
			request_id = _send_custom_backend_dev_login_fallback(network, backend_dev_profile_name, current_world_name)
		if request_id != "":
			backend_login_request_sent = true
			backend_login_last_request_msec = Time.get_ticks_msec()
			backend_login_attempts += 1
			_log("[PhaseH] Sent backend dev login profile=%s world=%s request=%s attempt=%d connected=%s" % [
				backend_dev_profile_name,
				current_world_name,
				request_id,
				backend_login_attempts,
				str(backend_ws_connected),
			])
		else:
			backend_login_last_request_msec = Time.get_ticks_msec()
			_log("[PhaseH] Unable to request backend dev login yet for profile=%s world=%s connected=%s auth_error=%s" % [
				backend_dev_profile_name,
				current_world_name,
				str(backend_ws_connected),
				backend_auth_error_message,
			])


func _update_backend_session_state(network: Node = null, auth_data: Dictionary = {}) -> void:
	if network == null:
		network = _get_network_manager()
	if network == null:
		backend_ws_connected = false
		backend_authenticated = false
		return

	if network.has_method("is_connected_to_server"):
		backend_ws_connected = bool(network.is_connected_to_server())
	else:
		backend_ws_connected = false
	if network.has_method("is_server_session_authenticated"):
		backend_authenticated = bool(network.is_server_session_authenticated())
	else:
		backend_authenticated = false

	if network.has_method("get_active_session_username"):
		backend_username = str(network.get_active_session_username())
	if backend_username == "":
		backend_username = str(auth_data.get("username", backend_dev_profile_name))
	if network.has_method("get_active_account_id"):
		backend_account_id = str(network.get_active_account_id())
	if backend_account_id == "":
		backend_account_id = str(auth_data.get("account_id", ""))
	if network.has_method("get_active_profile_id"):
		backend_profile_id = str(network.get_active_profile_id())
	if backend_profile_id == "":
		backend_profile_id = str(auth_data.get("profile_id", auth_data.get("postgres_player_id", "")))
	if network.has_method("get_active_game_player_id"):
		backend_game_player_id = str(network.get_active_game_player_id())
	if backend_game_player_id == "":
		backend_game_player_id = str(auth_data.get("game_player_id", auth_data.get("websocket_player_id", "")))
	if backend_profile_id == "" and backend_game_player_id != "":
		backend_profile_id = backend_game_player_id
	if auth_data.has("session_id") or auth_data.has("session_token"):
		backend_session_id = str(auth_data.get("session_id", auth_data.get("session_token", ""))).strip_edges()
	elif "session_token" in network and str(network.get("session_token")).strip_edges() != "":
		backend_session_id = str(network.get("session_token")).strip_edges()
	if backend_session_id != "":
		backend_session_id = "present"

	var next_world := _safe_world_name(str(auth_data.get("world", auth_data.get("current_world", current_world_name))), current_world_name)
	if next_world != "":
		backend_world_id = next_world
		current_world_name = next_world


func _get_backend_connection_url() -> String:
	var network := _get_network_manager()
	if network == null:
		return "missing"
	if "last_connection_attempt_url" in network:
		var url := str(network.get("last_connection_attempt_url")).strip_edges()
		if url != "":
			return url
	return "unknown"


func _get_backend_connection_state_text() -> String:
	var network := _get_network_manager()
	if network == null:
		return "missing NetworkManager"
	if network.has_method("get_server_connection_state_text"):
		return str(network.get_server_connection_state_text())
	return "connected" if backend_ws_connected else "not connected"


func _should_send_backend_dev_login(network: Node) -> bool:
	if not backend_dev_login_requested:
		return false
	if network == null or not network.has_method("is_connected_to_server") or not bool(network.is_connected_to_server()):
		return false
	if backend_authenticated:
		return false
	if backend_auth_error_message.strip_edges() != "":
		return false
	if not backend_login_request_sent:
		return true
	if backend_login_attempts >= 3:
		return false
	return Time.get_ticks_msec() - backend_login_last_request_msec >= 2500


func _send_custom_backend_dev_login_fallback(network: Node, username: String, world_name: String) -> String:
	if not network.has_method("is_connected_to_server") or not bool(network.is_connected_to_server()):
		return ""
	if not network.has_method("make_auth_request_id"):
		_log("[PhaseH] Backend fallback failed: NetworkManager missing make_auth_request_id.")
		return ""
	if not network.has_method("send_message"):
		_log("[PhaseH] Backend fallback failed: NetworkManager missing send_message.")
		return ""

	if not _should_use_backend_auth_fallback():
		return ""

	var clean_username := _sanitize_dev_profile_name(str(username))
	var clean_world := _safe_world_name(str(world_name), DEFAULT_CUSTOM_WORLD)
	var request_id: String = str(network.make_auth_request_id())
	if request_id == "":
		return ""

	var payload = {
		"type": "dev_backend_login",
		"request_id": request_id,
		"username": clean_username,
		"world": clean_world,
		"movement_mode": str(MovementMode.get_mode_name()) if MovementMode != null and MovementMode.has_method("get_mode_name") else "CUSTOM_AUTHORITATIVE",
		"dev_login": true,
	}

	if bool(network.send_message(payload)):
		_log("[PhaseH] Sent fallback backend dev login request via send_message: profile=%s world=%s request=%s" % [clean_username, clean_world, request_id])
		return request_id

	_log("[PhaseH] Backend fallback failed: send_message returned false for profile=%s world=%s request=%s" % [clean_username, clean_world, request_id])
	return ""


func _should_use_backend_auth_fallback() -> bool:
	if not fallback_backend_login_requested:
		fallback_backend_login_requested = true
		_log("[PhaseH] Using backend auth fallback for custom movement test (send_backend_dev_login not usable).")
	return true


func request_network_player_state() -> void:
	var network := _get_network_manager()
	if network != null and network.has_method("send_player_state_request"):
		var sent := bool(network.send_player_state_request(backend_dev_profile_name))
		_log("[PhaseH] Backend player state request profile=%s sent=%s" % [backend_dev_profile_name, str(sent)])


func apply_network_player_state(data: Dictionary) -> void:
	_update_backend_session_state()
	last_backend_player_state = data.duplicate(true)
	var player_data: Dictionary = data.get("player_data", {}) if data.get("player_data", {}) is Dictionary else {}
	_apply_backend_player_data(player_data)
	backend_inventory_loaded = not player_data.is_empty()
	backend_username = str(data.get("username", backend_username))
	backend_world_id = _safe_world_name(str(data.get("world", current_world_name)), current_world_name)
	update_all_ui()
	_log("[PhaseH] Inventory state profile=%s inventory_loaded=%s selected=%s place_count=%d world=%s" % [
		str(data.get("username", backend_dev_profile_name)),
		str(backend_inventory_loaded),
		str(player_data.get("selected_item_type", "")),
		int(inventory.get(selected_place_block, 0)),
		backend_world_id,
	])


func handle_player_state_lookup_result(_request_id: String, data: Dictionary, _context: Dictionary) -> void:
	apply_network_player_state(data)


func get_current_profile_name() -> String:
	return backend_dev_profile_name


func handle_network_player_position(_data: Dictionary) -> void:
	pass


func handle_network_existing_players(_players: Array) -> void:
	backend_world_joined = true
	backend_world_id = current_world_name
	_log("[PhaseH] Backend join world ok world=%s existing_players=%d" % [current_world_name, _players.size()])


func _setup_real_world_inventory_bridge() -> void:
	if not real_world_test_enabled:
		return
	if ui_layer == null:
		return
	_setup_real_item_database()
	_sync_blocks_from_collision_world()
	setup_drop_manager()
	setup_inventory_manager()
	update_all_ui()
	_log("[CustomMovementInventory] Real inventory/drop UI attached to custom movement test. reach=%.0fpx (%d tiles)" % [
		WEBSOCKET_BLOCK_ACTION_REACH_PIXELS,
		int(round(WEBSOCKET_BLOCK_ACTION_REACH_PIXELS / float(BLOCK_SIZE))),
	])


func _setup_real_item_database() -> void:
	item_database = ItemDatabaseScript.ITEMS.duplicate(true) if ItemDatabaseScript.ITEMS is Dictionary else {}
	splice_recipes = ItemDatabaseScript.SPLICE_RECIPES.duplicate(true) if ItemDatabaseScript.SPLICE_RECIPES is Dictionary else {}
	tier_1_splice_balance = ItemDatabaseScript.TIER_1_SPLICE_BALANCE.duplicate(true) if ItemDatabaseScript.TIER_1_SPLICE_BALANCE is Dictionary else {}
	_clear_real_inventory_catalogs()

	for item_id in item_database.keys():
		var item_data = item_database[item_id]
		if not (item_data is Dictionary):
			continue
		var category := str(item_data.get("category", "")).strip_edges().to_lower()
		var starting_count := int(item_data.get("starting_count", 0))
		match category:
			"block":
				inventory[item_id] = 0
				if not bool(item_data.get("hidden", false)):
					block_items.append(item_id)
				var block_texture := load_item_texture_spec(item_data)
				if block_texture != null:
					block_textures[item_id] = block_texture
			"seed":
				seed_inventory[item_id] = 0
				var seed_texture: Texture2D = get_seed_icon_texture(str(item_id))
				if seed_texture != null:
					seed_textures[item_id] = seed_texture
			"tool":
				tool_inventory[item_id] = starting_count
				tool_items.append(item_id)
				var tool_texture := load_item_texture_spec(item_data)
				if tool_texture != null:
					tool_textures[item_id] = tool_texture
			"back":
				back_inventory[item_id] = starting_count
				back_items.append(item_id)
				var back_texture := load_item_texture_spec(item_data)
				if back_texture != null:
					back_textures[item_id] = back_texture
			"hair":
				hair_inventory[item_id] = starting_count
				hair_items.append(item_id)
				var hair_texture := load_item_texture_spec(item_data)
				if hair_texture != null:
					hair_textures[item_id] = hair_texture
			"eyewear":
				eyewear_inventory[item_id] = starting_count
				eyewear_items.append(item_id)
				var eyewear_texture := load_item_texture_spec(item_data)
				if eyewear_texture != null:
					eyewear_textures[item_id] = eyewear_texture
			"shirt":
				shirt_inventory[item_id] = starting_count
				shirt_items.append(item_id)
				var shirt_texture := load_item_texture_spec(item_data)
				if shirt_texture != null:
					shirt_textures[item_id] = shirt_texture
			"pants":
				pants_inventory[item_id] = starting_count
				pants_items.append(item_id)
				var pants_texture := load_item_texture_spec(item_data)
				if pants_texture != null:
					pants_textures[item_id] = pants_texture
			"shoes":
				shoes_inventory[item_id] = starting_count
				shoes_items.append(item_id)
				var shoes_texture := load_item_texture_spec(item_data)
				if shoes_texture != null:
					shoes_textures[item_id] = shoes_texture
			"currency":
				currency_inventory[item_id] = clamp_item_stack_count(str(item_id), category, starting_count)
				var currency_texture := load_item_texture_spec(item_data)
				if currency_texture != null:
					currency_textures[item_id] = currency_texture
			"material":
				material_inventory[item_id] = starting_count
				material_items.append(item_id)
				var material_texture := load_item_texture_spec(item_data)
				if material_texture != null:
					material_textures[item_id] = material_texture
			"lure":
				lure_inventory[item_id] = starting_count
				lure_items.append(item_id)
				var lure_texture := load_item_texture_spec(item_data)
				if lure_texture != null:
					lure_textures[item_id] = lure_texture
			"fish":
				fish_inventory[item_id] = starting_count
				fish_items.append(item_id)
				var fish_texture := load_item_texture_spec(item_data)
				if fish_texture != null:
					fish_textures[item_id] = fish_texture

	for item_list in [block_items, tool_items, back_items, hair_items, eyewear_items, shirt_items, pants_items, shoes_items, material_items, lure_items, fish_items]:
		item_list.sort_custom(Callable(self, "sort_item_ids_by_order"))
	var bedrock_texture := load_texture_spec("res://Assets/blocks/Tier_1/basic blocks/bedrock_block.png")
	if bedrock_texture != null:
		block_textures["bedrock"] = bedrock_texture


func _clear_real_inventory_catalogs() -> void:
	inventory.clear()
	seed_inventory.clear()
	tool_inventory.clear()
	back_inventory.clear()
	hair_inventory.clear()
	eyewear_inventory.clear()
	shirt_inventory.clear()
	pants_inventory.clear()
	shoes_inventory.clear()
	currency_inventory.clear()
	material_inventory.clear()
	lure_inventory.clear()
	fish_inventory.clear()
	block_textures.clear()
	seed_textures.clear()
	tool_textures.clear()
	back_textures.clear()
	hair_textures.clear()
	eyewear_textures.clear()
	shirt_textures.clear()
	pants_textures.clear()
	shoes_textures.clear()
	currency_textures.clear()
	material_textures.clear()
	lure_textures.clear()
	fish_textures.clear()
	seed_icon_texture_cache.clear()
	seed_drop_icon_texture_cache.clear()
	block_items.clear()
	tool_items.clear()
	back_items.clear()
	hair_items.clear()
	eyewear_items.clear()
	shirt_items.clear()
	pants_items.clear()
	shoes_items.clear()
	material_items.clear()
	lure_items.clear()
	fish_items.clear()


func _apply_backend_player_data(player_data: Dictionary) -> void:
	if player_data.is_empty():
		return
	_apply_inventory_counts(inventory, player_data.get("inventory", {}), false)
	_apply_inventory_counts(seed_inventory, player_data.get("seed_inventory", {}), false)
	_apply_inventory_counts(tool_inventory, player_data.get("tool_inventory", {}), true)
	_apply_inventory_counts(back_inventory, player_data.get("back_inventory", {}), true)
	_apply_inventory_counts(hair_inventory, player_data.get("hair_inventory", {}), true)
	_apply_inventory_counts(eyewear_inventory, player_data.get("eyewear_inventory", {}), true)
	_apply_inventory_counts(shirt_inventory, player_data.get("shirt_inventory", {}), true)
	_apply_inventory_counts(pants_inventory, player_data.get("pants_inventory", {}), true)
	_apply_inventory_counts(shoes_inventory, player_data.get("shoes_inventory", {}), true)
	_apply_inventory_counts(currency_inventory, player_data.get("currency_inventory", {}), true)
	_apply_inventory_counts(material_inventory, player_data.get("material_inventory", {}), true)
	_apply_inventory_counts(lure_inventory, player_data.get("lure_inventory", {}), true)
	_apply_inventory_counts(fish_inventory, player_data.get("fish_inventory", {}), true)
	_apply_hotbar_from_backend(player_data)
	selected_item_type = str(player_data.get("selected_item_type", selected_item_type))
	selected_item_category = str(player_data.get("selected_item_category", selected_item_category))
	primary_hotbar_tool = str(player_data.get("primary_hotbar_tool", primary_hotbar_tool))
	equipped_tool = str(player_data.get("equipped_tool", equipped_tool))
	equipped_back_item = str(player_data.get("equipped_back_item", equipped_back_item))
	equipped_hair_item = str(player_data.get("equipped_hair_item", equipped_hair_item))
	equipped_eyewear_item = str(player_data.get("equipped_eyewear_item", equipped_eyewear_item))
	equipped_shirt_item = str(player_data.get("equipped_shirt_item", equipped_shirt_item))
	equipped_pants_item = str(player_data.get("equipped_pants_item", equipped_pants_item))
	equipped_shoes_item = str(player_data.get("equipped_shoes_item", equipped_shoes_item))


func _apply_inventory_counts(target_inventory: Dictionary, saved_inventory, preserve_default_if_missing: bool) -> void:
	if not (saved_inventory is Dictionary):
		if not preserve_default_if_missing:
			for key in target_inventory.keys():
				target_inventory[key] = 0
		return
	if not preserve_default_if_missing:
		for key in target_inventory.keys():
			target_inventory[key] = 0
	for raw_key in saved_inventory.keys():
		var item_id := str(raw_key)
		if item_id == "":
			continue
		target_inventory[item_id] = int(saved_inventory.get(raw_key, 0))


func _apply_hotbar_from_backend(player_data: Dictionary) -> void:
	var saved_items = player_data.get("hotbar_items", null)
	var saved_categories = player_data.get("hotbar_item_categories", null)
	if saved_items is Array and saved_categories is Array:
		hotbar_items = saved_items.duplicate(true)
		hotbar_item_categories = saved_categories.duplicate(true)
	elif player_data.has("quick_hotbar_item_type"):
		var quick_item := str(player_data.get("quick_hotbar_item_type", "")).strip_edges()
		var quick_category := str(player_data.get("quick_hotbar_item_category", "block")).strip_edges()
		if quick_item != "":
			hotbar_items = ["punch", quick_item, "dirt", "grass", "stone", "wood"]
			hotbar_item_categories = ["tool", quick_category, "block", "block", "block", "block"]
	_normalize_hotbar_arrays()


func _normalize_hotbar_arrays() -> void:
	while hotbar_items.size() < HOTBAR_SLOT_COUNT:
		hotbar_items.append("")
	while hotbar_item_categories.size() < HOTBAR_SLOT_COUNT:
		hotbar_item_categories.append("empty")
	while hotbar_items.size() > HOTBAR_SLOT_COUNT:
		hotbar_items.pop_back()
	while hotbar_item_categories.size() > HOTBAR_SLOT_COUNT:
		hotbar_item_categories.pop_back()
	if hotbar_items.is_empty() or str(hotbar_items[0]) == "":
		hotbar_items[0] = get_primary_hotbar_tool()
		hotbar_item_categories[0] = "tool"


func setup_inventory_manager() -> void:
	if ui_layer == null:
		return
	inventory_manager = ui_layer.get_node_or_null("InventoryManager")
	if inventory_manager == null:
		inventory_manager = Control.new()
		inventory_manager.name = "InventoryManager"
		inventory_manager.set_script(InventoryManagerScript)
		ui_layer.add_child(inventory_manager)
	if inventory_manager.has_method("setup"):
		inventory_manager.setup(self, ui_layer)


func setup_drop_manager() -> void:
	if drop_manager == null:
		drop_manager = Node.new()
		drop_manager.name = "DropManager"
		drop_manager.set_script(DropManagerScript)
		add_child(drop_manager)
	if drop_manager.has_method("setup"):
		drop_manager.setup(self)


func update_all_ui() -> void:
	update_hotbar()
	update_inventory_window()
	if inventory_manager != null and inventory_manager.has_method("update_gem_counter"):
		inventory_manager.update_gem_counter()
	if inventory_label != null:
		inventory_label.text = "Selected: %s x%d" % [get_item_display_name(selected_item_type, selected_item_category), get_item_count(selected_item_type, selected_item_category)]


func setup_hotbar() -> void:
	if inventory_manager != null and inventory_manager.has_method("setup_hotbar"):
		inventory_manager.setup_hotbar()


func update_hotbar() -> void:
	if inventory_manager != null and inventory_manager.has_method("update_hotbar"):
		inventory_manager.update_hotbar()


func update_inventory_window() -> void:
	if inventory_manager != null and inventory_manager.has_method("update_inventory_window"):
		inventory_manager.update_inventory_window()


func open_inventory_window() -> void:
	if inventory_manager != null and inventory_manager.has_method("open_inventory_window"):
		inventory_manager.open_inventory_window()


func close_inventory_window() -> void:
	if inventory_manager != null and inventory_manager.has_method("close_inventory_window"):
		inventory_manager.close_inventory_window()


func toggle_inventory_window() -> void:
	if inventory_manager != null and inventory_manager.has_method("toggle_inventory_window"):
		inventory_manager.toggle_inventory_window()


func normalize_hotbar() -> void:
	if inventory_manager != null and inventory_manager.has_method("normalize_hotbar"):
		inventory_manager.normalize_hotbar()
	else:
		_normalize_hotbar_arrays()


func select_hotbar_slot(slot_index: int) -> void:
	if inventory_manager != null and inventory_manager.has_method("select_hotbar_slot"):
		inventory_manager.select_hotbar_slot(slot_index)


func assign_item_to_quick_hotbar(item_type: String, category: String) -> void:
	if inventory_manager != null and inventory_manager.has_method("assign_item_to_quick_hotbar"):
		inventory_manager.assign_item_to_quick_hotbar(item_type, category)


func select_item(item_type: String, category: String) -> void:
	var clean_item := item_type.strip_edges()
	var clean_category := category.strip_edges().to_lower()
	if clean_item == "":
		return
	selected_item_type = clean_item
	selected_item_category = clean_category
	if clean_category == "block":
		selected_place_block = clean_item
		var item_data := get_item_data(clean_item)
		selected_place_layer = _sanitize_layer(str(item_data.get("place_layer", selected_place_layer)))
	update_all_ui()


func get_primary_hotbar_tool() -> String:
	return primary_hotbar_tool if primary_hotbar_tool.strip_edges() != "" else "punch"


func toggle_primary_hotbar_tool() -> void:
	primary_hotbar_tool = "punch"
	if not hotbar_items.is_empty():
		hotbar_items[0] = primary_hotbar_tool
		hotbar_item_categories[0] = "tool"
	update_all_ui()


func get_item_count(item_type: String, category: String) -> int:
	match category:
		"block":
			return int(inventory.get(item_type, 0))
		"seed":
			return int(seed_inventory.get(item_type, 0))
		"tool":
			return int(tool_inventory.get(item_type, 0))
		"back":
			return int(back_inventory.get(item_type, 0))
		"hair":
			return int(hair_inventory.get(item_type, 0))
		"eyewear":
			return int(eyewear_inventory.get(item_type, 0))
		"shirt":
			return int(shirt_inventory.get(item_type, 0))
		"pants":
			return int(pants_inventory.get(item_type, 0))
		"shoes":
			return int(shoes_inventory.get(item_type, 0))
		"currency":
			return int(currency_inventory.get(item_type, 0))
		"material":
			return int(material_inventory.get(item_type, 0))
		"lure":
			return int(lure_inventory.get(item_type, 0))
		"fish":
			return int(fish_inventory.get(item_type, 0))
	return 0


func _infer_inventory_category(item_type: String, fallback_category: String = "") -> String:
	var clean_category := fallback_category.strip_edges().to_lower()
	if clean_category != "":
		return clean_category
	var item_data := get_item_data(item_type)
	if not item_data.is_empty():
		clean_category = str(item_data.get("category", "")).strip_edges().to_lower()
		if clean_category != "":
			return clean_category
	if inventory.has(item_type):
		return "block"
	if seed_inventory.has(item_type):
		return "seed"
	if tool_inventory.has(item_type):
		return "tool"
	if back_inventory.has(item_type):
		return "back"
	if hair_inventory.has(item_type):
		return "hair"
	if eyewear_inventory.has(item_type):
		return "eyewear"
	if shirt_inventory.has(item_type):
		return "shirt"
	if pants_inventory.has(item_type):
		return "pants"
	if shoes_inventory.has(item_type):
		return "shoes"
	if currency_inventory.has(item_type):
		return "currency"
	if material_inventory.has(item_type):
		return "material"
	if lure_inventory.has(item_type):
		return "lure"
	if fish_inventory.has(item_type):
		return "fish"
	return ""


func _get_inventory_for_category(category: String) -> Dictionary:
	match category.strip_edges().to_lower():
		"block":
			return inventory
		"seed":
			return seed_inventory
		"tool":
			return tool_inventory
		"back":
			return back_inventory
		"hair":
			return hair_inventory
		"eyewear":
			return eyewear_inventory
		"shirt":
			return shirt_inventory
		"pants":
			return pants_inventory
		"shoes":
			return shoes_inventory
		"currency":
			return currency_inventory
		"material":
			return material_inventory
		"lure":
			return lure_inventory
		"fish":
			return fish_inventory
	return {}


func apply_network_inventory_delta(delta: Dictionary) -> bool:
	if not (delta is Dictionary):
		return false
	var item_type := str(delta.get("item_id", delta.get("item_type", ""))).strip_edges()
	if item_type == "":
		return false
	var category := _infer_inventory_category(item_type, str(delta.get("item_category", delta.get("category", ""))))
	if category == "":
		return false
	var delta_key := _inventory_delta_key(delta, item_type, category)
	if delta_key != "" and processed_inventory_delta_keys.has(delta_key):
		update_all_ui()
		_log_custom_inventory_update(item_type, category)
		return true
	var target_inventory := _get_inventory_for_category(category)
	if target_inventory.is_empty() and not target_inventory.has(item_type):
		return false

	var current_count := int(target_inventory.get(item_type, 0))
	var next_count := current_count
	var has_authoritative_count := false
	for count_key in ["after_count", "after_amount", "new_count", "count"]:
		if delta.has(count_key):
			next_count = int(delta.get(count_key, current_count))
			has_authoritative_count = true
			break
	if not has_authoritative_count:
		if delta.has("delta"):
			next_count = current_count + int(delta.get("delta", 0))
		elif delta.has("amount"):
			next_count = current_count + int(delta.get("amount", 0))
		else:
			return false

	target_inventory[item_type] = clamp_item_stack_count(item_type, category, next_count)
	backend_inventory_loaded = true
	if delta_key != "":
		_remember_inventory_delta_key(delta_key)
	update_all_ui()
	_log_custom_inventory_update(item_type, category)
	return true


func _inventory_delta_key(delta: Dictionary, item_type: String, category: String) -> String:
	var stable_id := str(delta.get("request_id", delta.get("transaction_id", delta.get("source_id", "")))).strip_edges()
	var drop_id := str(delta.get("drop_id", "")).strip_edges()
	if stable_id != "":
		return "id:%s|%s|%s|%s" % [stable_id, drop_id, item_type, category]
	if drop_id != "":
		return "drop:%s|%s|%s|%s|%s|%s" % [
			drop_id,
			item_type,
			category,
			str(delta.get("before_count", delta.get("before_amount", ""))),
			str(delta.get("after_count", delta.get("after_amount", ""))),
			str(delta.get("delta", "")),
		]
	if delta.has("after_count") or delta.has("after_amount") or delta.has("new_count") or delta.has("count"):
		return ""
	return "%s|%s|%s|%s|%s" % [
		item_type,
		category,
		str(delta.get("before_count", delta.get("before_amount", ""))),
		str(delta.get("delta", "")),
		str(delta.get("amount", "")),
	]


func _remember_inventory_delta_key(delta_key: String) -> void:
	processed_inventory_delta_keys[delta_key] = Time.get_ticks_msec()
	processed_inventory_delta_order.append(delta_key)
	while processed_inventory_delta_order.size() > 256:
		var old_key := str(processed_inventory_delta_order.pop_front())
		processed_inventory_delta_keys.erase(old_key)


func _extract_inventory_log_item(data: Dictionary) -> Dictionary:
	var raw_delta = data.get("inventory_delta", data.get("inventory_deltas", null))
	if raw_delta is Dictionary:
		var delta_item := str(raw_delta.get("item_id", raw_delta.get("item_type", ""))).strip_edges()
		if delta_item != "":
			return {
				"item": delta_item,
				"category": _infer_inventory_category(delta_item, str(raw_delta.get("item_category", raw_delta.get("category", "")))),
			}
	if raw_delta is Array:
		for raw_entry in raw_delta:
			if not (raw_entry is Dictionary):
				continue
			var entry_item := str(raw_entry.get("item_id", raw_entry.get("item_type", ""))).strip_edges()
			if entry_item != "":
				return {
					"item": entry_item,
					"category": _infer_inventory_category(entry_item, str(raw_entry.get("item_category", raw_entry.get("category", "")))),
				}
	var rewards = data.get("rewards", [])
	if rewards is Array:
		for raw_reward in rewards:
			if not (raw_reward is Dictionary):
				continue
			var reward_item := str(raw_reward.get("item_id", raw_reward.get("item_type", ""))).strip_edges()
			if reward_item != "":
				return {
					"item": reward_item,
					"category": _infer_inventory_category(reward_item, str(raw_reward.get("item_category", raw_reward.get("category", "")))),
				}
	var player_data = data.get("player_data", {})
	if player_data is Dictionary:
		var selected_item := str(player_data.get("selected_item_type", "")).strip_edges()
		if selected_item != "":
			return {
				"item": selected_item,
				"category": _infer_inventory_category(selected_item, str(player_data.get("selected_item_category", ""))),
			}
	var fallback_item := str(data.get("item_id", data.get("item_type", data.get("block_type", selected_item_type)))).strip_edges()
	if fallback_item == "":
		fallback_item = selected_place_block
	return {
		"item": fallback_item,
		"category": _infer_inventory_category(fallback_item, selected_item_category),
	}


func _log_custom_inventory_update(item_type: String, category: String) -> void:
	var clean_item := item_type.strip_edges()
	if clean_item == "":
		return
	var clean_category := _infer_inventory_category(clean_item, category)
	_log("[CustomClientApply] inventory_update item=%s count=%d hotbar_refreshed=true" % [
		clean_item,
		get_item_count(clean_item, clean_category),
	])


func get_item_display_name(item_type: String, _category: String = "") -> String:
	if item_database.has(item_type) and item_database[item_type] is Dictionary:
		return str(item_database[item_type].get("display_name", item_type.capitalize()))
	return item_type.capitalize()


func get_item_data(item_type: String) -> Dictionary:
	if item_database.has(item_type) and item_database[item_type] is Dictionary:
		return item_database[item_type]
	return {}


func get_inventory_icon_texture(item_type: String, category: String = ""):
	match category:
		"block":
			return block_textures.get(item_type, null)
		"seed":
			return seed_textures.get(item_type, null)
		"tool":
			return tool_textures.get(item_type, null)
		"back":
			return back_textures.get(item_type, null)
		"hair":
			return hair_textures.get(item_type, null)
		"eyewear":
			return eyewear_textures.get(item_type, null)
		"shirt":
			return shirt_textures.get(item_type, null)
		"pants":
			return pants_textures.get(item_type, null)
		"shoes":
			return shoes_textures.get(item_type, null)
		"currency":
			return currency_textures.get(item_type, null)
		"material":
			return material_textures.get(item_type, null)
		"lure":
			return lure_textures.get(item_type, null)
		"fish":
			return fish_textures.get(item_type, null)
	return load_item_texture_spec(get_item_data(item_type))


func get_item_drop_texture(item_type: String, item_category: String):
	if drop_manager != null and drop_manager.has_method("get_item_drop_texture"):
		return drop_manager.get_item_drop_texture(item_type, item_category)
	return get_inventory_icon_texture(item_type, item_category)


func sort_item_ids_by_order(a: String, b: String) -> bool:
	var order_a := 9999
	var order_b := 9999
	if item_database.has(a) and item_database[a] is Dictionary:
		order_a = int(item_database[a].get("order", 9999))
	if item_database.has(b) and item_database[b] is Dictionary:
		order_b = int(item_database[b].get("order", 9999))
	return order_a < order_b


func is_gem_currency(item_type: String, _category: String = "currency") -> bool:
	return item_type == GEM_CURRENCY_ITEM_ID


func get_stack_limit_for_item(item_type: String, category: String = "") -> int:
	if is_gem_currency(item_type, category):
		return GEM_CURRENCY_CAP
	var configured_stack_limit := MAX_ITEM_STACK_SIZE
	var item_data := get_item_data(item_type)
	if not item_data.is_empty():
		if item_data.has("max_stack"):
			configured_stack_limit = int(item_data.get("max_stack", MAX_ITEM_STACK_SIZE))
		if not bool(item_data.get("stackable", true)):
			return 1
	return int(clamp(configured_stack_limit, 1, MAX_ITEM_STACK_SIZE))


func clamp_item_stack_count(item_type: String, category: String, count: int) -> int:
	return int(clamp(count, 0, get_stack_limit_for_item(item_type, category)))


func add_item_to_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> int:
	var current_count: int = max(0, int(target_inventory.get(item_type, 0)))
	var next_count: int = clamp_item_stack_count(item_type, category, current_count + max(0, amount))
	target_inventory[item_type] = next_count
	return next_count - current_count


func spend_item_from_inventory_stack(target_inventory: Dictionary, item_type: String, category: String, amount: int) -> bool:
	var safe_amount: int = max(0, amount)
	var current_count: int = max(0, int(target_inventory.get(item_type, 0)))
	if current_count < safe_amount:
		return false
	target_inventory[item_type] = clamp_item_stack_count(item_type, category, current_count - safe_amount)
	return true


func format_currency_amount(value: int) -> String:
	var digits := str(max(0, value))
	var result := ""
	var group_count := 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1
	return result


func get_currency_display_text(item_type: String = GEM_CURRENCY_ITEM_ID) -> String:
	return format_currency_amount(clamp_item_stack_count(item_type, "currency", int(currency_inventory.get(item_type, 0))))


func load_texture_spec(texture_spec) -> Texture2D:
	return AtlasTextureFactory.load_texture(texture_spec)


func load_item_texture_spec(item_data: Dictionary, texture_key: String = "texture") -> Texture2D:
	if not item_data.has(texture_key):
		return null
	return load_texture_spec(item_data.get(texture_key))


func get_seed_icon_texture(seed_type: String):
	return _get_seed_box_texture(seed_type, seed_icon_texture_cache)


func get_seed_drop_icon_texture(seed_type: String):
	return _get_seed_box_texture(seed_type, seed_drop_icon_texture_cache)


func _get_seed_box_texture(seed_type: String, cache: Dictionary):
	var clean_seed_type := seed_type.strip_edges()
	if clean_seed_type == "":
		return null
	if cache.has(clean_seed_type):
		return cache[clean_seed_type]
	var seed_box_texture := load_texture_spec(SEED_BOX_TEXTURE_PATH)
	cache[clean_seed_type] = seed_box_texture
	return seed_box_texture


func get_seed_icon_preview_layout(seed_type: String) -> Dictionary:
	return _get_seed_box_preview_layout(seed_type, SEED_ICON_PREVIEW_MAX_SIZE, SEED_ICON_PREVIEW_TOP, SEED_ICON_PREVIEW_OFFSET)


func get_seed_drop_preview_layout(seed_type: String) -> Dictionary:
	return _get_seed_box_preview_layout(seed_type, SEED_DROP_ICON_PREVIEW_MAX_SIZE, SEED_DROP_ICON_PREVIEW_TOP, SEED_DROP_ICON_PREVIEW_OFFSET)


func _get_seed_box_preview_layout(seed_type: String, preview_max_size: int, preview_top: int, preview_offset: Vector2i) -> Dictionary:
	var clean_seed_type := seed_type.strip_edges()
	if clean_seed_type == "":
		return {}
	var seed_box_texture := load_texture_spec(SEED_BOX_TEXTURE_PATH)
	if seed_box_texture == null:
		return {}
	var block_texture := load_item_texture_spec(get_item_data(get_seed_preview_block_type(clean_seed_type)))
	if block_texture == null:
		return {}
	var box_size := Vector2i(seed_box_texture.get_width(), seed_box_texture.get_height())
	var preview_size := _fit_texture_size(Vector2i(block_texture.get_width(), block_texture.get_height()), preview_max_size)
	var destination := Vector2i(
		int(round(float(box_size.x - preview_size.x) * 0.5)),
		preview_top + int(round(float(preview_max_size - preview_size.y) * 0.5))
	) + preview_offset
	destination.x = clampi(destination.x, 0, max(0, box_size.x - preview_size.x))
	destination.y = clampi(destination.y, 0, max(0, box_size.y - preview_size.y))
	return {
		"box_texture": seed_box_texture,
		"box_size": box_size,
		"preview_texture": block_texture,
		"preview_size": preview_size,
		"destination": destination,
		"block_type": get_seed_preview_block_type(clean_seed_type),
	}


func get_seed_preview_block_type(seed_type: String) -> String:
	var clean_seed_type := seed_type.strip_edges()
	if item_database.has(clean_seed_type) and item_database[clean_seed_type] is Dictionary:
		var grows_into := str(item_database[clean_seed_type].get("grows_into", "")).strip_edges()
		if grows_into != "":
			return grows_into
	if clean_seed_type.ends_with("_seed"):
		return clean_seed_type.substr(0, clean_seed_type.length() - "_seed".length())
	return clean_seed_type


func _fit_texture_size(source_size: Vector2i, max_side: int) -> Vector2i:
	if source_size.x <= 0 or source_size.y <= 0:
		return Vector2i(max_side, max_side)
	var scale: float = min(float(max_side) / float(source_size.x), float(max_side) / float(source_size.y))
	return Vector2i(max(1, int(round(float(source_size.x) * scale))), max(1, int(round(float(source_size.y) * scale))))


func _sync_real_ui_player_adapter() -> void:
	if not real_world_test_enabled:
		return
	player = local_player if local_player != null and is_instance_valid(local_player) else null
	if player != null:
		var facing_value = player.get("facing_dir")
		if facing_value is int or facing_value is float:
			player_facing_direction = -1 if int(facing_value) < 0 else 1
	var active_camera: Camera2D = null
	if player != null and player.has_method("is_camera_enabled") and bool(player.is_camera_enabled()):
		active_camera = player.get_node_or_null("Camera2D") as Camera2D
	if active_camera != null:
		current_camera_zoom = active_camera.zoom.x
	elif camera != null:
		current_camera_zoom = camera.zoom.x


func _update_real_item_drops(delta: float) -> void:
	if not real_world_test_enabled or drop_manager == null:
		return
	if drop_manager.has_method("update_drops"):
		drop_manager.update_drops(delta)


func _get_local_drop_count() -> int:
	return dropped_items.size()


func _has_local_drop_id(drop_id: String) -> bool:
	var clean_drop_id := drop_id.strip_edges()
	if clean_drop_id == "":
		return false
	if drop_manager != null and drop_manager.has_method("get_drop_by_id"):
		var drop_data = drop_manager.get_drop_by_id(clean_drop_id)
		if drop_data is Dictionary and not drop_data.is_empty():
			return true
	for raw_drop_data in dropped_items:
		if not (raw_drop_data is Dictionary):
			continue
		if str(raw_drop_data.get("drop_id", "")).strip_edges() == clean_drop_id:
			return true
	return false


func _extract_drop_id(data: Dictionary) -> String:
	return str(data.get("drop_id", data.get("id", ""))).strip_edges()


func _sync_blocks_from_collision_world() -> void:
	blocks.clear()
	if test_world == null or not test_world.has_method("get_foreground_tile_snapshot"):
		return
	var snapshot_value = test_world.get_foreground_tile_snapshot()
	if not (snapshot_value is Dictionary):
		return
	for grid_pos in snapshot_value.keys():
		if not (grid_pos is Vector2i):
			continue
		blocks[grid_pos] = {
			"type": str(snapshot_value.get(grid_pos, "air")),
		}


func should_use_server_authoritative_world_actions() -> bool:
	return backend_actions_enabled and backend_actions_ready


func create_item_drop(
	item_type: String,
	item_position: Vector2,
	is_seed: bool,
	item_category: String = "",
	pickup_delay: float = 0.0,
	amount: float = 1.0,
	drop_id: String = "",
	sync_to_server: bool = true
) -> void:
	if drop_manager != null and drop_manager.has_method("create_item_drop"):
		drop_manager.create_item_drop(item_type, item_position, is_seed, item_category, pickup_delay, amount, drop_id, sync_to_server)


func update_item_drops(delta: float) -> void:
	_update_real_item_drops(delta)


func collect_drop(drop_data) -> bool:
	if drop_manager != null and drop_manager.has_method("collect_drop"):
		return bool(drop_manager.collect_drop(drop_data))
	return false


func apply_network_item_drop_create(data: Dictionary) -> void:
	var drop_id := _extract_drop_id(data)
	var before_count := _get_local_drop_count()
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_create"):
		drop_manager.apply_network_item_drop_create(data)
	update_all_ui()
	var applied := _has_local_drop_id(drop_id) or _get_local_drop_count() > before_count
	_log("[CustomClientApply] drop_update id=%s action=create applied=%s" % [drop_id, str(applied)])


func apply_network_item_drop_update(data: Dictionary) -> void:
	var drop_id := _extract_drop_id(data)
	var before_present := _has_local_drop_id(drop_id)
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_update"):
		drop_manager.apply_network_item_drop_update(data)
	update_all_ui()
	var after_present := _has_local_drop_id(drop_id)
	_log("[CustomClientApply] drop_update id=%s action=update applied=%s" % [drop_id, str(before_present or after_present)])


func apply_network_item_drop_remove(data: Dictionary) -> void:
	var drop_id := _extract_drop_id(data)
	var before_present := _has_local_drop_id(drop_id)
	if drop_manager != null and drop_manager.has_method("apply_network_item_drop_remove"):
		drop_manager.apply_network_item_drop_remove(data)
	update_all_ui()
	var applied := before_present and not _has_local_drop_id(drop_id)
	_log("[CustomClientApply] drop_update id=%s action=remove applied=%s" % [drop_id, str(applied)])


func cancel_pending_pickup_for_drop(drop_id: String) -> void:
	if drop_manager != null and drop_manager.has_method("cancel_pending_pickup_for_drop"):
		drop_manager.cancel_pending_pickup_for_drop(drop_id)


func handle_rejected_drop_pickup(drop_id: String, message: String = "") -> bool:
	var clean_drop_id := drop_id.strip_edges()
	if drop_manager != null and drop_manager.has_method("handle_rejected_drop_pickup"):
		var handled := bool(drop_manager.handle_rejected_drop_pickup(drop_id, message))
		_log("[CustomClientApply] drop_update id=%s action=reject applied=%s reason=%s" % [clean_drop_id, str(_has_local_drop_id(clean_drop_id)), message])
		return handled
	if message.strip_edges() != "":
		show_notification(message)
	_log("[CustomClientApply] drop_update id=%s action=reject applied=%s reason=%s" % [clean_drop_id, str(_has_local_drop_id(clean_drop_id)), message])
	return false


func drop_inventory_item_to_world(item_type: String, category: String) -> bool:
	_send_custom_trusted_state(true)
	if drop_manager != null and drop_manager.has_method("drop_inventory_item_to_world"):
		return bool(drop_manager.drop_inventory_item_to_world(item_type, category))
	return false


func drop_inventory_item_stack_to_world(item_type: String, category: String, amount: float) -> bool:
	_send_custom_trusted_state(true)
	if drop_manager != null and drop_manager.has_method("drop_inventory_item_stack_to_world"):
		return bool(drop_manager.drop_inventory_item_stack_to_world(item_type, category, amount))
	return false


func get_player_grid_position() -> Vector2i:
	if player == null or not is_instance_valid(player):
		return Vector2i.ZERO
	return Vector2i(int(round(player.global_position.x / float(BLOCK_SIZE))), int(round(player.global_position.y / float(BLOCK_SIZE))))


func is_grid_inside_world(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < WORLD_WIDTH and grid_pos.y >= 0 and grid_pos.y < WORLD_HEIGHT


func get_drop_pickup_vacuum_world_target_position(_item_type: String, _category: String, fallback_world_position: Vector2) -> Vector2:
	if player != null and is_instance_valid(player):
		return player.global_position + Vector2(0.0, -18.0)
	return fallback_world_position


func play_drop_pickup_target_feedback(_item_type: String, _category: String) -> void:
	pass


func save_player_data() -> void:
	pass


func show_notification(message: String) -> void:
	var clean_message := message.strip_edges()
	if clean_message == "":
		return
	_log("[CustomMovementNotice] " + clean_message)
	if inventory_label != null:
		inventory_label.text = clean_message


func use_selected_item_at_mouse() -> void:
	if selected_item_category == "block":
		_request_backend_block_place(get_global_mouse_position())
	else:
		_request_backend_block_break(get_global_mouse_position())


func handle_inventory_transaction_result(data: Dictionary) -> void:
	var applied_delta := false
	if data.get("player_data", null) is Dictionary:
		_apply_backend_player_data(data.get("player_data"))
		backend_inventory_loaded = true
	else:
		var raw_delta = data.get("inventory_delta", data.get("inventory_deltas", null))
		if raw_delta is Dictionary:
			applied_delta = apply_network_inventory_delta(raw_delta)
		elif raw_delta is Array:
			for raw_entry in raw_delta:
				if raw_entry is Dictionary and apply_network_inventory_delta(raw_entry):
					applied_delta = true
	update_all_ui()
	var log_item := _extract_inventory_log_item(data)
	if log_item is Dictionary and not log_item.is_empty():
		_log_custom_inventory_update(str(log_item.get("item", "")), str(log_item.get("category", "")))
	elif applied_delta:
		_log_custom_inventory_update(selected_item_type, selected_item_category)


func is_inventory_open() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_open"):
		return bool(inventory_manager.is_inventory_open())
	return false


func is_inventory_search_focused() -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_search_focused"):
		return bool(inventory_manager.is_inventory_search_focused())
	return false


func is_inventory_ui_at_point(point: Vector2) -> bool:
	if inventory_manager != null and inventory_manager.has_method("is_inventory_ui_at_point"):
		return bool(inventory_manager.is_inventory_ui_at_point(point))
	return false


func handle_inventory_wheel(event: InputEvent) -> bool:
	if inventory_manager != null and inventory_manager.has_method("handle_inventory_wheel"):
		return bool(inventory_manager.handle_inventory_wheel(event))
	return false


func is_chat_input_focused() -> bool:
	return false


func is_any_text_input_focused() -> bool:
	return is_inventory_search_focused()


func is_player_menu_open() -> bool:
	return false


func is_game_menu_open() -> bool:
	return false


func is_notification_panel_open() -> bool:
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


func is_world_lock_ui_open() -> bool:
	return false


func is_trade_open() -> bool:
	return false


func is_vending_open() -> bool:
	return false


func is_safe_open() -> bool:
	return false


func is_fish_monger_open() -> bool:
	return false


func is_developer_panel_open() -> bool:
	return false


func is_movement_blocking_ui_open() -> bool:
	return is_inventory_open()


func is_gameplay_hud_blocked() -> bool:
	return false


func is_item_equipable(_item_type: String, _category: String) -> bool:
	return false


func toggle_equip_item(_item_type: String, _category: String) -> bool:
	return false


func update_equipment_visual() -> void:
	pass


func add_inventory_item_to_trade(_slot_index: int, _item_type: String, _category: String, _amount: float) -> bool:
	return false


func add_inventory_item_to_vend(_item_type: String, _category: String, _amount: float) -> bool:
	return false


func add_inventory_item_to_safe(_item_type: String, _category: String, _amount: float) -> bool:
	return false


func _configure_real_world_test() -> void:
	if test_world != null and test_world.has_method("is_real_world_collision"):
		real_world_test_enabled = true
	if _should_setup_requested_world():
		test_world.setup_world(requested_world_name)
	if real_world_test_enabled:
		var summary := _get_world_debug_summary()
		var loaded_world := str(summary.get("world_name", summary.get("world_id", current_world_name))).strip_edges()
		current_world_name = _safe_world_name(loaded_world, current_world_name)
		if backend_actions_enabled:
			_log("[PhaseH] Backend inventory/block actions enabled for custom movement real-world test. world=%s profile=%s place_block=%s layer=%s" % [current_world_name, backend_dev_profile_name, selected_place_block, selected_place_layer])
			_connect_backend_bridge_signal()
		else:
			_log("[PhaseG] Block actions disabled during real-world movement test.")
			_log("[PhaseG] Backend, inventory, block editing, locks, economy, shop, chat, vending, fishing, admin tools, and saving are not connected in this isolated movement scene.")


func _should_setup_requested_world() -> bool:
	if requested_world_name.strip_edges() == "":
		return false
	if test_world == null or not test_world.has_method("setup_world"):
		return false

	var summary := _get_world_debug_summary()
	var loaded_requested := str(summary.get("requested_world_name", "")).strip_edges().to_lower()
	var wanted := requested_world_name.strip_edges().to_lower()
	return loaded_requested != wanted


func _start_server() -> void:
	_set_root_camera_enabled(false)
	_configure_collision_debug_overlay()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, Protocol.MAX_CLIENTS)
	if error != OK:
		push_error("[CustomMovementTest] Failed to start ENet server on port %d: %s" % [port, error])
		return

	multiplayer.multiplayer_peer = peer
	_log("[CustomMovementTest] Server started on %s:%d" % [Protocol.ADDRESS, port])
	_print_startup_config("server")
	_log_world_collision_summary("server")


func _start_client() -> void:
	_set_root_camera_enabled(false)
	_configure_collision_debug_overlay()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		push_error("[CustomMovementTest] Failed to connect ENet client to %s:%d: %s" % [host, port, error])
		return

	multiplayer.multiplayer_peer = peer
	_log("[CustomMovementTest] Client connecting to %s:%d" % [host, port])
	_print_startup_config("client")
	_log_world_collision_summary("client")


func _show_idle_instructions() -> void:
	_set_root_camera_enabled(true)
	_configure_collision_debug_overlay()
	info_label.text = "Custom movement test\nLaunch with --server or --client."


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_log("[CustomMovementTest] Client connected as peer %d" % local_peer_id)
	rpc_id(1, "server_client_ready")


func _on_connection_failed() -> void:
	push_error("[CustomMovementTest] Client connection failed.")


func _on_server_disconnected() -> void:
	_log("[CustomMovementTest] Server disconnected.")
	_clear_client_players()


func _on_peer_connected(peer_id: int) -> void:
	if is_server:
		_log("[CustomMovementTest] Peer connected: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_server:
		_log("[CustomMovementTest] Peer disconnected: %d" % peer_id)
		_server_remove_player(peer_id)
		rpc("client_despawn_player", peer_id)


@rpc("any_peer", "reliable")
func server_client_ready() -> void:
	if not is_server:
		return

	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 0:
		return

	var new_player = _server_add_player(sender)
	for peer_id in server_players.keys():
		var player = server_players[peer_id]
		rpc_id(sender, "client_spawn_player", int(peer_id), player.global_position)
		rpc_id(sender, "client_receive_snapshot", _make_server_snapshot(int(peer_id), player))
	rpc_id(sender, "client_receive_collision_hash", _get_collision_hash())

	for target_peer_id in multiplayer.get_peers():
		if int(target_peer_id) == sender:
			continue
		rpc_id(int(target_peer_id), "client_spawn_player", sender, new_player.global_position)


@rpc("any_peer", "unreliable_ordered")
func server_receive_input(packet: Dictionary) -> void:
	if not is_server:
		return

	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 0:
		return

	if not server_players.has(sender):
		_server_add_player(sender)

	var clean_packet: Dictionary = Protocol.sanitize_input(packet, sender)
	clean_packet["peer_id"] = sender

	var queue: Array = server_input_queues.get(sender, [])
	queue.append(clean_packet)
	while queue.size() > Protocol.MAX_INPUT_QUEUE_PER_PEER:
		queue.pop_front()
	server_input_queues[sender] = queue


@rpc("authority", "reliable")
func client_spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	if is_server:
		return
	if client_players.has(peer_id):
		return

	var player = PLAYER_SCENE.instantiate()
	var is_local: bool = int(peer_id) == multiplayer.get_unique_id()
	player.name = "Player_%d" % int(peer_id)
	var spawn_root := local_players_root if is_local else players_root
	spawn_root.add_child(player)
	player.setup(peer_id, is_local, false)
	player.global_position = spawn_position
	client_players[peer_id] = player

	if is_local:
		local_peer_id = int(peer_id)
		local_player = player
		self.player = player
		local_predicted_position = spawn_position
		local_predicted_velocity = Vector2.ZERO
		last_server_authoritative_position = spawn_position
		last_server_authoritative_velocity = Vector2.ZERO
	else:
		interpolator.add_snapshot(Protocol.make_snapshot(peer_id, server_tick, spawn_position, Vector2.ZERO, 1, "idle", 0))

	var role: String = "local" if is_local else "remote"
	_log("[CustomMovementTest] Spawned %s player peer %d; players=%d" % [role, int(peer_id), client_players.size()])


@rpc("authority", "reliable")
func client_despawn_player(peer_id: int) -> void:
	if is_server:
		return

	var player: Node = client_players.get(peer_id, null)
	if player != null and is_instance_valid(player):
		player.queue_free()
	client_players.erase(peer_id)
	interpolator.clear_peer(peer_id)
	if local_peer_id == int(peer_id):
		local_peer_id = 0
		local_player = null
		player = null
		input_history.clear()
		last_processed_input = 0
		local_prediction_error = 0.0
		correction_mode = "none"


@rpc("authority", "reliable")
func client_receive_collision_hash(server_collision_hash: String) -> void:
	if is_server:
		return

	var client_collision_hash := _get_collision_hash()
	var prefix := _collision_log_prefix()
	if client_collision_hash != server_collision_hash:
		_log("%s COLLISION MISMATCH server=%s client=%s" % [
			prefix,
			server_collision_hash,
			client_collision_hash,
		])
		return
	_log("%s COLLISION MATCH hash=%s" % [prefix, client_collision_hash])


@rpc("authority", "unreliable_ordered")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if is_server:
		return

	var peer_id := int(snapshot.get("peer_id", 0))
	if peer_id <= 0:
		return

	if peer_id == local_peer_id:
		_client_reconcile_local_player(snapshot)
		return

	if not client_players.has(peer_id):
		client_spawn_player(peer_id, Protocol.snapshot_position(snapshot))
	interpolator.add_snapshot(snapshot)


func _server_add_player(peer_id: int):
	if server_players.has(peer_id):
		return server_players[peer_id]

	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % int(peer_id)
	players_root.add_child(player)
	player.setup(peer_id, false, true)
	player.global_position = _spawn_position_for_peer(peer_id)
	server_players[peer_id] = player
	server_input_queues[peer_id] = []
	server_last_processed_input[peer_id] = 0
	server_last_input[peer_id] = Protocol.make_input(peer_id, 0, 0.0, false, 1, server_tick)
	_log("[CustomMovementTest] Server spawned peer %d at %s; players=%d" % [int(peer_id), str(player.global_position), server_players.size()])
	return player


func _server_remove_player(peer_id: int) -> void:
	var player: Node = server_players.get(peer_id, null)
	if player != null and is_instance_valid(player):
		player.queue_free()
	server_players.erase(peer_id)
	server_input_queues.erase(peer_id)
	server_last_processed_input.erase(peer_id)
	server_last_input.erase(peer_id)
	server_spawn_slots.erase(peer_id)


func _server_physics(delta: float) -> void:
	server_tick += 1
	for peer_id in server_players.keys():
		var player = server_players[peer_id]
		var queue: Array = server_input_queues.get(peer_id, [])
		var processed_input := false

		while not queue.is_empty():
			var packet: Dictionary = queue.pop_front()
			_server_simulate_packet(int(peer_id), player, packet, Protocol.FIXED_DELTA)
			processed_input = true

		if not processed_input:
			var idle_packet: Dictionary = server_last_input.get(peer_id, Protocol.make_input(int(peer_id), 0, 0.0, false, 1, server_tick)).duplicate(true)
			idle_packet["move_x"] = 0.0
			idle_packet["jump_pressed"] = false
			idle_packet["jump_held"] = false
			_server_simulate_packet(int(peer_id), player, idle_packet, delta, false)

		server_input_queues[peer_id] = queue

	snapshot_timer += delta
	if snapshot_timer >= Protocol.SNAPSHOT_INTERVAL:
		snapshot_timer = fmod(snapshot_timer, Protocol.SNAPSHOT_INTERVAL)
		_server_send_snapshots()


func _server_simulate_packet(peer_id: int, player, packet: Dictionary, delta: float, acknowledge: bool = true) -> void:
	player.simulate_movement_packet(packet, delta)
	server_last_input[peer_id] = packet
	if acknowledge:
		server_last_processed_input[peer_id] = max(int(server_last_processed_input.get(peer_id, 0)), int(packet.get("input_sequence", 0)))


func _server_send_snapshots() -> void:
	for peer_id in server_players.keys():
		var player = server_players[peer_id]
		rpc("client_receive_snapshot", _make_server_snapshot(int(peer_id), player))


func _make_server_snapshot(peer_id: int, player) -> Dictionary:
	return Protocol.make_snapshot(
		peer_id,
		server_tick,
		player.global_position,
		player.velocity,
		player.facing_dir,
		player.movement_state,
		int(server_last_processed_input.get(peer_id, 0)),
		float(player.get("jump_hold_fall_pause_timer"))
	)


func _client_physics(delta: float) -> void:
	if local_player == null or local_peer_id <= 0:
		_update_remote_interpolation(delta)
		return

	_client_send_input_and_predict(delta)
	_update_remote_interpolation(delta)


func _client_send_input_and_predict(delta: float) -> void:
	client_input_sequence += 1
	client_tick += 1

	var move_x: float = _get_move_x_input()
	var jump_pressed: bool = _get_jump_pressed_input()
	var jump_held: bool = _get_jump_held_input()
	var facing: int = local_player.facing_dir
	if move_x > 0.01:
		facing = 1
	elif move_x < -0.01:
		facing = -1

	var packet: Dictionary = Protocol.make_input(local_peer_id, client_input_sequence, move_x, jump_pressed, facing, client_tick, jump_held)
	local_player.simulate_movement_packet(packet, delta)
	local_predicted_position = local_player.global_position
	local_predicted_velocity = local_player.velocity
	_store_input_history(packet)
	rpc_id(1, "server_receive_input", packet)


func _get_move_x_input() -> float:
	if auto_input_enabled:
		var phase_seconds: float = float(client_tick % (Protocol.PHYSICS_TICK_RATE * 4)) / float(Protocol.PHYSICS_TICK_RATE)
		return 1.0 if phase_seconds < 2.0 else -1.0

	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")


func _get_jump_pressed_input() -> bool:
	if auto_input_enabled:
		return client_tick % (Protocol.PHYSICS_TICK_RATE * 3) == Protocol.PHYSICS_TICK_RATE

	return Input.is_action_just_pressed("jump")


func _get_jump_held_input() -> bool:
	if auto_input_enabled:
		var phase_tick := client_tick % (Protocol.PHYSICS_TICK_RATE * 3)
		return phase_tick >= Protocol.PHYSICS_TICK_RATE and phase_tick < Protocol.PHYSICS_TICK_RATE * 2

	return Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)


func _client_reconcile_local_player(snapshot: Dictionary) -> void:
	if local_player == null:
		return

	var acknowledged_input: int = int(snapshot.get("last_processed_input", 0))
	last_processed_input = max(last_processed_input, acknowledged_input)

	var authoritative_position: Vector2 = Protocol.snapshot_position(snapshot)
	var authoritative_velocity: Vector2 = Protocol.snapshot_velocity(snapshot)
	last_server_authoritative_position = authoritative_position
	last_server_authoritative_velocity = authoritative_velocity
	last_server_tick = int(snapshot.get("server_tick", last_server_tick))
	_send_custom_trusted_state(false)

	var prediction_position: Vector2 = local_player.global_position
	if input_history.has(acknowledged_input):
		var acknowledged_entry: Dictionary = input_history[acknowledged_input]
		prediction_position = acknowledged_entry.get("predicted_position", prediction_position)
	local_prediction_error = prediction_position.distance_to(authoritative_position)
	correction_mode = _correction_mode_for_error(local_prediction_error)

	_remove_acknowledged_inputs(acknowledged_input)

	if correction_mode == "none":
		return

	var previous_position: Vector2 = local_player.global_position

	local_player.force_state(
		authoritative_position,
		authoritative_velocity,
		int(snapshot.get("facing_dir", local_player.facing_dir)),
		str(snapshot.get("movement_state", "")),
		Protocol.snapshot_jump_hold_fall_pause_timer(snapshot)
	)
	_replay_unacknowledged_inputs()

	var replayed_position: Vector2 = local_player.global_position
	var replayed_velocity: Vector2 = local_player.velocity
	match correction_mode:
		"smooth":
			local_player.global_position = previous_position.lerp(replayed_position, Protocol.LOCAL_SMOOTH_CORRECTION_BLEND)
		"fast":
			local_player.global_position = previous_position.lerp(replayed_position, Protocol.LOCAL_FAST_CORRECTION_BLEND)
		"snap":
			if local_prediction_error >= Protocol.HARD_SNAP_CORRECTION_PIXELS:
				local_player.global_position = replayed_position
			else:
				local_player.global_position = previous_position.lerp(replayed_position, Protocol.LOCAL_STRONG_CORRECTION_BLEND)
	local_player.velocity = replayed_velocity
	local_predicted_position = local_player.global_position
	local_predicted_velocity = local_player.velocity


func _send_custom_trusted_state(force: bool = false) -> bool:
	if not backend_actions_enabled or not is_client:
		return false
	if local_peer_id <= 0 or last_server_tick <= 0:
		return false
	var network := _get_network_manager()
	if network == null or not network.has_method("send_custom_trusted_player_state"):
		return false
	var facing := 1
	if local_player != null and is_instance_valid(local_player):
		facing = int(local_player.facing_dir)
	var node_path := str(local_player.get_path()) if local_player != null and is_instance_valid(local_player) else ""
	return bool(network.send_custom_trusted_player_state(
		last_server_authoritative_position,
		last_server_authoritative_velocity,
		facing,
		current_world_name,
		local_peer_id,
		last_server_tick,
		node_path,
		force
	))


func _store_input_history(packet: Dictionary) -> void:
	var sequence := int(packet.get("input_sequence", 0))
	if sequence <= 0:
		return

	input_history[sequence] = {
		"input_sequence": sequence,
		"input": packet.duplicate(true),
		"predicted_position": local_predicted_position,
		"predicted_velocity": local_predicted_velocity,
		"client_tick": int(packet.get("client_tick", client_tick)),
		"stored_msec": Time.get_ticks_msec(),
	}
	_trim_input_history()


func _correction_mode_for_error(error_pixels: float) -> String:
	if error_pixels < Protocol.SMALL_CORRECTION_PIXELS:
		return "none"
	if error_pixels < Protocol.FAST_CORRECTION_PIXELS:
		return "smooth"
	if error_pixels < Protocol.SNAP_CORRECTION_PIXELS:
		return "fast"
	return "snap"


func _remove_acknowledged_inputs(acknowledged_input: int) -> void:
	for sequence in input_history.keys():
		if int(sequence) <= acknowledged_input:
			input_history.erase(sequence)


func _replay_unacknowledged_inputs() -> void:
	var sequences := input_history.keys()
	sequences.sort()
	for sequence in sequences:
		var entry: Dictionary = input_history[sequence]
		var packet: Dictionary = entry.get("input", {})
		local_player.simulate_movement_packet(packet, Protocol.FIXED_DELTA)
	local_predicted_position = local_player.global_position
	local_predicted_velocity = local_player.velocity


func _trim_input_history() -> void:
	while input_history.size() > Protocol.MAX_INPUT_HISTORY:
		var sequences := input_history.keys()
		sequences.sort()
		input_history.erase(sequences[0])


func _update_remote_interpolation(delta: float) -> void:
	for peer_id in client_players.keys():
		if int(peer_id) == local_peer_id:
			continue

		var player = client_players[peer_id]
		var state: Dictionary = interpolator.get_render_state(int(peer_id))
		if state.is_empty():
			continue

		_apply_remote_render_state(player, state, delta)


func _apply_remote_render_state(player, state: Dictionary, delta: float) -> void:
	var target_position: Vector2 = state.get("position", player.global_position)
	var distance: float = player.global_position.distance_to(target_position)
	var should_snap: bool = bool(state.get("teleport_snap", false)) or distance >= Protocol.REMOTE_RENDER_SNAP_PIXELS
	var render_position: Vector2 = target_position
	if not should_snap and distance > Protocol.REMOTE_RENDER_CLOSE_ENOUGH_PIXELS:
		var smooth_rate: float = Protocol.REMOTE_RENDER_FAST_SMOOTH_RATE if distance >= Protocol.REMOTE_RENDER_FAST_DISTANCE_PIXELS else Protocol.REMOTE_RENDER_SMOOTH_RATE
		var alpha: float = clampf(1.0 - exp(-smooth_rate * maxf(delta, Protocol.FIXED_DELTA)), 0.0, 1.0)
		render_position = player.global_position.lerp(target_position, alpha)

	player.force_state(
		render_position,
		state.get("velocity", player.velocity),
		int(state.get("facing_dir", player.facing_dir)),
		str(state.get("movement_state", player.movement_state))
	)


func _clear_client_players() -> void:
	for peer_id in client_players.keys():
		var player: Node = client_players[peer_id]
		if player != null and is_instance_valid(player):
			player.queue_free()
	client_players.clear()
	interpolator.clear()
	local_peer_id = 0
	local_player = null
	player = null
	input_history.clear()
	last_processed_input = 0
	local_prediction_error = 0.0
	local_predicted_position = Vector2.ZERO
	local_predicted_velocity = Vector2.ZERO
	last_server_authoritative_position = Vector2.ZERO
	last_server_authoritative_velocity = Vector2.ZERO
	last_server_tick = 0
	correction_mode = "none"


func _update_runtime_limit(delta: float) -> void:
	if max_runtime_seconds <= 0.0:
		return

	runtime_seconds += delta
	if runtime_seconds < max_runtime_seconds:
		return

	_log("[CustomMovementTest] Max runtime %.1fs reached; quitting." % max_runtime_seconds)
	get_tree().quit()


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	if not server_spawn_slots.has(peer_id):
		server_spawn_slots[peer_id] = server_next_spawn_slot
		server_next_spawn_slot += 1
	var index: int = int(server_spawn_slots.get(peer_id, 0))
	if test_world != null and test_world.has_method("get_spawn_position"):
		var spawn_value = test_world.get_spawn_position()
		if spawn_value is Vector2:
			return spawn_value + Vector2(float(index) * 48.0, 0.0)
	return Vector2(320.0 + (float(index % 6) * 80.0), 350.0)


func _configure_collision_debug_overlay() -> void:
	if test_world == null:
		return
	if test_world.has_method("set_collision_debug_visible"):
		test_world.set_collision_debug_visible(collision_debug_enabled)


func _get_collision_hash() -> String:
	if test_world == null or not test_world.has_method("get_collision_hash"):
		return "none"
	return str(test_world.get_collision_hash())


func _get_world_debug_summary() -> Dictionary:
	if test_world == null or not test_world.has_method("get_world_debug_summary"):
		return {}
	var summary = test_world.get_world_debug_summary()
	if summary is Dictionary:
		return summary
	return {}


func _collision_log_prefix() -> String:
	return "[CustomMovementWorld]" if real_world_test_enabled else "[CustomMovementCollision]"


func _log_world_collision_summary(role: String) -> void:
	var summary := _get_world_debug_summary()
	if summary.is_empty():
		return
	_log("%s %s movement_system=CUSTOM_AUTHORITATIVE world_name=%s world_revision=%s world_id=%s tile_size=%d block_count=%d foreground_count=%d background_count=%d solid_collision_count=%d collision_hash=%s collision_ready=%s world_origin=%s chunk_origin=%s source=%s overlay=%s" % [
		_collision_log_prefix(),
		role,
		str(summary.get("world_name", summary.get("world_id", ""))),
		str(summary.get("world_revision", "")),
		str(summary.get("world_id", "")),
		int(summary.get("tile_size", 0)),
		int(summary.get("block_count", 0)),
		int(summary.get("foreground_count", 0)),
		int(summary.get("background_count", 0)),
		int(summary.get("solid_collision_count", 0)),
		str(summary.get("collision_hash", "")),
		str(bool(summary.get("collision_ready", true))),
		str(summary.get("world_origin", Vector2.ZERO)),
		str(summary.get("chunk_origin", Vector2i.ZERO)),
		str(summary.get("world_source", "")),
		str(collision_debug_enabled),
	])


func _get_player_collision_debug(player) -> Dictionary:
	if player == null or test_world == null:
		return {}
	if not is_instance_valid(player):
		return {}
	if not test_world.has_method("get_tile_info_at_world"):
		return {}

	var facing := 1
	var facing_value = player.get("facing_dir")
	if facing_value is int or facing_value is float:
		facing = int(facing_value)
	var under_position: Vector2 = player.global_position + Vector2(0.0, 20.0)
	var front_position: Vector2 = player.global_position + Vector2(float(facing) * 20.0, 0.0)
	var under_info_value = test_world.get_tile_info_at_world(under_position)
	var front_info_value = test_world.get_tile_info_at_world(front_position)
	var under_info: Dictionary = _dictionary_from_variant(under_info_value)
	var front_info: Dictionary = _dictionary_from_variant(front_info_value)
	return {
		"under": under_info,
		"front": front_info,
		"collision_hash": _get_collision_hash(),
		"is_on_floor": bool(player.is_on_floor()),
	}


func _format_tile_debug(info: Dictionary) -> String:
	if info.is_empty():
		return "none"
	return "%s@%s solid=%s" % [
		str(info.get("block_id", "air")),
		str(info.get("grid_pos", Vector2i.ZERO)),
		str(bool(info.get("solid", false))),
	]


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _build_world_debug_overlay(player) -> String:
	var summary := _get_world_debug_summary()
	if summary.is_empty():
		return ""

	var tile_debug := _get_player_collision_debug(player)
	var under_info: Dictionary = _dictionary_from_variant(tile_debug.get("under", {}))
	var front_info: Dictionary = _dictionary_from_variant(tile_debug.get("front", {}))
	return "\nmovement system: CUSTOM_AUTHORITATIVE\nworld_name: %s\nworld_revision: %s\nworld_id: %s\ncollision ready: %s\ntile_size: %d\nblock_count: %d\nforeground_count: %d\nbackground_count: %d\nsolid_collision_count: %d\ncollision_hash: %s\nworld_origin: %s\nchunk_origin: %s\nis_on_floor: %s\ntile under: %s\ntile front: %s" % [
		str(summary.get("world_name", summary.get("world_id", ""))),
		str(summary.get("world_revision", "")),
		str(summary.get("world_id", "")),
		str(bool(summary.get("collision_ready", true))),
		int(summary.get("tile_size", 0)),
		int(summary.get("block_count", 0)),
		int(summary.get("foreground_count", 0)),
		int(summary.get("background_count", 0)),
		int(summary.get("solid_collision_count", 0)),
		str(summary.get("collision_hash", "")),
		str(summary.get("world_origin", Vector2.ZERO)),
		str(summary.get("chunk_origin", Vector2i.ZERO)),
		str(bool(tile_debug.get("is_on_floor", false))),
		_format_tile_debug(under_info),
		_format_tile_debug(front_info),
	]


func _set_root_camera_enabled(enabled: bool) -> void:
	if camera == null:
		return
	camera.enabled = enabled


func _player_camera_enabled(player) -> bool:
	if player == null:
		return false
	if not is_instance_valid(player):
		return false
	if player.has_method("is_camera_enabled"):
		return bool(player.is_camera_enabled())
	var player_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	return player_camera != null and player_camera.enabled


func _update_camera() -> void:
	if camera == null:
		return
	if not camera.enabled:
		return
	if local_player != null:
		camera.global_position = local_player.global_position + Vector2(0.0, -80.0)


func _update_info_label() -> void:
	if info_label == null:
		return

	var mode: String = "server" if is_server else ("client" if is_client else "idle")
	var active_peer: int = multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	if local_player != null:
		position = local_player.global_position
		velocity = local_player.velocity
	elif is_server and not server_players.is_empty():
		var first_peer: int = int(server_players.keys()[0])
		var first_player = server_players[first_peer]
		position = first_player.global_position
		velocity = first_player.velocity

	var display_server_tick := server_tick if is_server else last_server_tick
	var snapshot_stats: Dictionary = interpolator.get_stats()
	var world_debug_text := _build_world_debug_overlay(local_player)
	var remote_debug_text := _build_remote_debug_overlay()
	info_label.text = "Custom Movement Test\nmode: %s\nbackend: %s\npeer_id: %d\ninput_sequence: %d\nlast_processed_input: %d\ninput history size: %d\nlocal predicted position: %s\nserver authoritative position: %s\nprediction error: %.2f px\ncorrection mode: %s\nserver_tick: %d\nsnapshot rate: %d/s\nreceived snapshots: %.1f/s\ndropped snapshots: %d\navg snapshot interval: %.1f ms\nsnapshot buffer size: %d\nping: %s\nposition: %s\nvelocity: %s\ncamera enabled: %s\nplayers: %d%s%s" % [
		mode,
		_get_backend_status_text(),
		active_peer,
		client_input_sequence,
		last_processed_input,
		input_history.size(),
		_format_vector(local_predicted_position),
		_format_vector(last_server_authoritative_position),
		local_prediction_error,
		correction_mode,
		display_server_tick,
		Protocol.SNAPSHOT_RATE,
		float(snapshot_stats.get("received_snapshots_per_second", 0.0)),
		int(snapshot_stats.get("dropped_snapshots", 0)),
		float(snapshot_stats.get("average_snapshot_interval_ms", 0.0)),
		interpolator.get_total_buffer_size(),
		_get_ping_text(),
		_format_vector(position),
		_format_vector(velocity),
		str(_player_camera_enabled(local_player)),
		_get_visible_player_count(),
		world_debug_text,
		remote_debug_text
	]


func _update_player_debug_labels() -> void:
	if is_server:
		for peer_id in server_players.keys():
			var player = server_players[peer_id]
			var tile_debug := _get_player_collision_debug(player)
			var under_info: Dictionary = _dictionary_from_variant(tile_debug.get("under", {}))
			var front_info: Dictionary = _dictionary_from_variant(tile_debug.get("front", {}))
			player.set_debug_lines([
				"server peer %d" % int(peer_id),
				player.movement_state,
				"ack %d" % int(server_last_processed_input.get(peer_id, 0)),
				"facing %d cam %s" % [player.facing_dir, str(_player_camera_enabled(player))],
				"floor %s" % str(bool(tile_debug.get("is_on_floor", false))),
				"under %s" % _format_tile_debug(under_info),
				"front %s" % _format_tile_debug(front_info),
				"vel %s" % _format_vector(player.velocity),
				_format_vector(player.global_position),
			])
		return

	for peer_id in client_players.keys():
		var player = client_players[peer_id]
		var clean_peer_id := int(peer_id)
		if clean_peer_id == local_peer_id:
			var local_tile_debug := _get_player_collision_debug(player)
			var local_under_info: Dictionary = _dictionary_from_variant(local_tile_debug.get("under", {}))
			var local_front_info: Dictionary = _dictionary_from_variant(local_tile_debug.get("front", {}))
			player.set_debug_lines([
				"local peer %d" % clean_peer_id,
				player.movement_state,
				"seq %d ack %d" % [client_input_sequence, last_processed_input],
				"hist %d err %.2f" % [input_history.size(), local_prediction_error],
				"facing %d cam %s" % [player.facing_dir, str(_player_camera_enabled(player))],
				"floor %s" % str(bool(local_tile_debug.get("is_on_floor", false))),
				"under %s" % _format_tile_debug(local_under_info),
				"front %s" % _format_tile_debug(local_front_info),
				"vel %s" % _format_vector(player.velocity),
				_format_vector(player.global_position),
			])
			continue

		var debug: Dictionary = interpolator.get_debug(clean_peer_id)
		var remote_tile_debug := _get_player_collision_debug(player)
		var remote_under_info: Dictionary = _dictionary_from_variant(remote_tile_debug.get("under", {}))
		var remote_front_info: Dictionary = _dictionary_from_variant(remote_tile_debug.get("front", {}))
		player.set_debug_lines([
			"remote peer %d" % clean_peer_id,
			player.movement_state,
			"buf %d a %.2f" % [interpolator.get_buffer_size(clean_peer_id), float(debug.get("interpolation_alpha", 0.0))],
			"tick %d>%d dr %s" % [
				int(debug.get("previous_snapshot_tick", -1)),
				int(debug.get("next_snapshot_tick", -1)),
				str(bool(debug.get("dead_reckoning", false)))
			],
			"facing %d cam %s" % [player.facing_dir, str(_player_camera_enabled(player))],
			"floor %s" % str(bool(remote_tile_debug.get("is_on_floor", false))),
			"under %s" % _format_tile_debug(remote_under_info),
			"front %s" % _format_tile_debug(remote_front_info),
			"latest %.1f px" % float(debug.get("latest_snapshot_distance", 0.0)),
			"vel %s" % _format_vector(player.velocity),
			_format_vector(player.global_position),
		])


func _build_remote_debug_overlay() -> String:
	if not is_client:
		return ""

	var text := ""
	for peer_id in client_players.keys():
		var clean_peer_id := int(peer_id)
		if clean_peer_id == local_peer_id:
			continue

		var debug: Dictionary = interpolator.get_debug(clean_peer_id)
		var line := "remote %d: buf %d delay %dms render %d tick %d>%d alpha %.2f dr %s latest %.1fpx" % [
			clean_peer_id,
			int(debug.get("buffer_size", 0)),
			int(debug.get("interpolation_delay_ms", Protocol.INTERPOLATION_DELAY_MS)),
			int(debug.get("render_time_msec", 0)),
			int(debug.get("previous_snapshot_tick", -1)),
			int(debug.get("next_snapshot_tick", -1)),
			float(debug.get("interpolation_alpha", 0.0)),
			str(bool(debug.get("dead_reckoning", false))),
			float(debug.get("latest_snapshot_distance", 0.0)),
		]
		text += "\n" + line
	return text


func _build_remote_debug_console() -> String:
	if not is_client:
		return "none"

	var text := ""
	for peer_id in client_players.keys():
		var clean_peer_id := int(peer_id)
		if clean_peer_id == local_peer_id:
			continue

		var debug: Dictionary = interpolator.get_debug(clean_peer_id)
		var line := "peer %d buf=%d delay=%dms render=%d tick=%d>%d alpha=%.2f dead_reckon=%s latest_dist=%.1f" % [
			clean_peer_id,
			int(debug.get("buffer_size", 0)),
			int(debug.get("interpolation_delay_ms", Protocol.INTERPOLATION_DELAY_MS)),
			int(debug.get("render_time_msec", 0)),
			int(debug.get("previous_snapshot_tick", -1)),
			int(debug.get("next_snapshot_tick", -1)),
			float(debug.get("interpolation_alpha", 0.0)),
			str(bool(debug.get("dead_reckoning", false))),
			float(debug.get("latest_snapshot_distance", 0.0)),
		]
		if text != "":
			text += "; "
		text += line

	if text == "":
		return "none"
	return text


func _get_backend_status_text() -> String:
	if not backend_actions_enabled:
		return "disabled"
	if not is_client:
		return "server-side disabled"

	var network := _get_network_manager()
	_update_backend_session_state(network)
	if network == null:
		return "missing NetworkManager"

	var connection_text := "unknown"
	if network.has_method("get_server_connection_state_text"):
		connection_text = str(network.get_server_connection_state_text())
	elif network.has_method("is_connected_to_server"):
		connection_text = "connected" if bool(network.is_connected_to_server()) else "not connected"

	if backend_actions_ready:
		return "ready %s profile=%s world=%s inventory=%s" % [connection_text, backend_dev_profile_name, backend_world_id, str(backend_inventory_loaded)]
	return "%s auth=%s profile=%s world=%s inventory=%s" % [
		connection_text,
		str(backend_authenticated),
		backend_dev_profile_name,
		backend_world_id,
		str(backend_inventory_loaded),
	]


func apply_network_world_state(data: Dictionary) -> void:
	if not backend_actions_enabled:
		return
	current_world_name = _safe_world_name(str(data.get("world", current_world_name)), current_world_name)
	backend_world_id = current_world_name
	backend_world_joined = true
	if test_world == null or not test_world.has_method("apply_world_state_payload"):
		return
	var before_summary := _get_world_debug_summary()
	var result = test_world.apply_world_state_payload(data)
	var after_summary := _get_world_debug_summary()
	if result is Dictionary and bool(result.get("ok", false)):
		_sync_blocks_from_collision_world()
		_log("[CustomActionCollision] source=backend_world_state world=%s revision_before=%s revision_after=%s hash_before=%s hash_after=%s" % [
			current_world_name,
			str(before_summary.get("collision_revision", "")),
			str(after_summary.get("collision_revision", "")),
			str(before_summary.get("collision_hash", "")),
			str(after_summary.get("collision_hash", "")),
		])


func apply_network_block_update(data: Dictionary) -> void:
	if not backend_actions_enabled:
		return
	_apply_approved_block_update(data, "backend", true)


@rpc("any_peer", "reliable")
func server_receive_approved_block_update(update: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or not server_players.has(sender):
		return
	var clean_update := _sanitize_approved_block_update(update)
	if clean_update.is_empty():
		return
	_apply_approved_block_update(clean_update, "movement_server_peer_%d" % sender, false)
	rpc("client_apply_approved_block_update", clean_update)


@rpc("authority", "reliable")
func client_apply_approved_block_update(update: Dictionary) -> void:
	if is_server or not backend_actions_enabled:
		return
	_apply_approved_block_update(update, "movement_server", false)


func _apply_approved_block_update(data: Dictionary, source: String, forward_to_server: bool) -> bool:
	var update := _sanitize_approved_block_update(data)
	if update.is_empty():
		return false
	var update_key := _block_update_key(update)
	if processed_block_update_keys.has(update_key):
		return false
	_remember_block_update_key(update_key)

	var before_summary := _get_world_debug_summary()
	var result := {}
	if test_world != null and test_world.has_method("apply_block_update"):
		var previous_applying_network_world_update := applying_network_world_update
		applying_network_world_update = true
		var applied = test_world.apply_block_update(update)
		applying_network_world_update = previous_applying_network_world_update
		if applied is Dictionary:
			result = applied
	var after_summary := _get_world_debug_summary()
	_sync_blocks_from_collision_world()
	var action := str(update.get("action", ""))
	var visual_changed := bool(result.get("ok", false)) and action != "hit"
	var collision_changed := visual_changed and str(before_summary.get("collision_hash", "")) != str(after_summary.get("collision_hash", ""))
	_log("[CustomClientApply] block_update action=%s tile=(%d,%d) block=%s applied_visual=%s applied_collision=%s" % [
		action,
		int(update.get("x", 0)),
		int(update.get("y", 0)),
		str(update.get("block_type", "")),
		str(visual_changed),
		str(collision_changed or visual_changed),
	])
	_log("[CustomActionCollision] source=%s world=%s action=%s layer=%s target=(%d,%d) block=%s result=%s reason=%s revision_before=%s revision_after=%s hash_before=%s hash_after=%s" % [
		source,
		str(update.get("world", current_world_name)),
		action,
		str(update.get("layer", "")),
		int(update.get("x", 0)),
		int(update.get("y", 0)),
		str(update.get("block_type", "")),
		str(bool(result.get("ok", false))),
		str(result.get("reason", "applied")),
		str(before_summary.get("collision_revision", "")),
		str(after_summary.get("collision_revision", "")),
		str(before_summary.get("collision_hash", "")),
		str(after_summary.get("collision_hash", "")),
	])
	_show_block_action_feedback(update, result)
	if forward_to_server and is_client and str(update.get("action", "")) != "hit" and multiplayer.multiplayer_peer != null:
		rpc_id(1, "server_receive_approved_block_update", update)
	return bool(result.get("ok", false))


func _show_block_action_feedback(update: Dictionary, result: Dictionary) -> void:
	var action := str(update.get("action", "")).strip_edges().to_lower()
	var block_type := str(update.get("block_type", "")).strip_edges()
	var display_name := get_item_display_name(block_type, "block") if block_type != "" else "block"
	if action == "hit":
		var hit_count := int(update.get("hit_count", 0))
		var max_hits := int(update.get("max_hits", 0))
		if hit_count > 0 and max_hits > 0:
			show_notification("Hit %s %d/%d" % [display_name, hit_count, max_hits])
		else:
			show_notification("Hit %s" % display_name)
		return
	if action == "break" and bool(result.get("ok", false)):
		show_notification("Broke %s." % display_name)
		return
	if action == "place" and bool(result.get("ok", false)):
		show_notification("Placed %s." % display_name)


func _sanitize_approved_block_update(data: Dictionary) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var action := str(data.get("action", "")).strip_edges().to_lower()
	if action != "place" and action != "break" and action != "hit":
		return {}
	var layer := _sanitize_layer(str(data.get("layer", "foreground")))
	var block_type := _sanitize_block_id(str(data.get("block_type", "")), "")
	var world_name := _safe_world_name(str(data.get("world", current_world_name)), current_world_name)
	return {
		"type": "world_block_update",
		"server_action_id": str(data.get("server_action_id", data.get("request_id", ""))),
		"action": action,
		"layer": layer,
		"x": int(data.get("x", 0)),
		"y": int(data.get("y", 0)),
		"block_type": block_type,
		"world": world_name,
		"hit_count": int(data.get("hit_count", 0)),
		"max_hits": int(data.get("max_hits", 0)),
	}


func _block_update_key(update: Dictionary) -> String:
	var server_id := str(update.get("server_action_id", "")).strip_edges()
	if server_id != "":
		return "id:" + server_id
	return "%s|%s|%s|%d|%d|%s|%d|%d" % [
		str(update.get("world", current_world_name)),
		str(update.get("action", "")),
		str(update.get("layer", "")),
		int(update.get("x", 0)),
		int(update.get("y", 0)),
		str(update.get("block_type", "")),
		int(update.get("hit_count", 0)),
		int(update.get("max_hits", 0)),
	]


func _remember_block_update_key(update_key: String) -> void:
	processed_block_update_keys[update_key] = Time.get_ticks_msec()
	processed_block_update_order.append(update_key)
	while processed_block_update_order.size() > 256:
		var old_key := str(processed_block_update_order.pop_front())
		processed_block_update_keys.erase(old_key)


func _get_visible_player_count() -> int:
	if is_server:
		return server_players.size()
	return client_players.size()


func _update_debug_console(delta: float) -> void:
	if not debug_console_enabled or not is_client:
		return

	debug_log_timer += delta
	if debug_log_timer < 1.0:
		return

	debug_log_timer = 0.0
	var snapshot_stats: Dictionary = interpolator.get_stats()
	_log("[CustomMovementTestDebug] peer=%d seq=%d ack=%d history=%d predicted=%s server=%s error=%.2f correction=%s server_tick=%d snapshot_rate=%d received=%.1f/s dropped=%d avg_interval=%.1fms collision_hash=%s ping=%s players=%d remote=%s" % [
		local_peer_id,
		client_input_sequence,
		last_processed_input,
		input_history.size(),
		_format_vector(local_predicted_position),
		_format_vector(last_server_authoritative_position),
		local_prediction_error,
		correction_mode,
		last_server_tick,
		Protocol.SNAPSHOT_RATE,
		float(snapshot_stats.get("received_snapshots_per_second", 0.0)),
		int(snapshot_stats.get("dropped_snapshots", 0)),
		float(snapshot_stats.get("average_snapshot_interval_ms", 0.0)),
		_get_collision_hash(),
		_get_ping_text(),
		client_players.size(),
		_build_remote_debug_console(),
	])


func _unhandled_input(event: InputEvent) -> void:
	if not real_world_test_enabled:
		return
	if handle_inventory_wheel(event):
		return
	if event is InputEventMouseButton and (is_inventory_ui_at_point(event.position) or is_inventory_open()):
		return
	if backend_actions_enabled:
		if not is_client:
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_request_backend_block_break(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_request_backend_block_place(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
		for action_name in ["break_block", "hit_block"]:
			if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
				_request_backend_block_break(_get_front_target_world_position())
				get_viewport().set_input_as_handled()
				return
		if InputMap.has_action("place_block") and event.is_action_pressed("place_block"):
			_request_backend_block_place(_get_front_target_world_position())
			get_viewport().set_input_as_handled()
			return
		return
	if event is InputEventMouseButton and event.pressed:
		_log_phase_g_block_actions_disabled_once()
		return
	for action_name in ["place_block", "break_block", "hit_block", "interact"]:
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			_log_phase_g_block_actions_disabled_once()
			return


func _get_front_target_world_position() -> Vector2:
	if local_player == null or not is_instance_valid(local_player):
		return get_global_mouse_position()
	var facing := 1
	var facing_value = local_player.get("facing_dir")
	if facing_value is int or facing_value is float:
		facing = -1 if int(facing_value) < 0 else 1
	return local_player.global_position + Vector2(float(facing) * 36.0, 0.0)


func _request_backend_block_break(world_position: Vector2) -> void:
	if not _can_send_backend_block_action("break"):
		return
	var tile_info := _get_tile_info(world_position)
	if tile_info.is_empty():
		return
	var layer := str(tile_info.get("layer", "air"))
	var block_id := str(tile_info.get("block_id", "air"))
	if layer == "air" or block_id == "" or block_id == "air":
		_log("[CustomActionClient] break skipped: no block at %s" % str(tile_info.get("grid_pos", Vector2i.ZERO)))
		return
	var grid_pos: Vector2i = tile_info.get("grid_pos", Vector2i.ZERO)
	if not _can_reach_backend_grid_action(grid_pos, "break"):
		return
	var network := _get_network_manager()
	_send_custom_trusted_state(true)
	if network != null and network.has_method("send_world_block_update"):
		var sent := bool(network.send_world_block_update("break", layer, grid_pos, block_id, current_world_name, {"source_tool": "punch"}))
		_log("[CustomActionClient] action=break target=%s layer=%s block=%s sent=%s trusted_tick=%d" % [str(grid_pos), layer, block_id, str(sent), last_server_tick])
		if not sent:
			_log_block_action_send_failure("break", layer, grid_pos, block_id)


func _request_backend_block_place(world_position: Vector2) -> void:
	if not _can_send_backend_block_action("place"):
		return
	if selected_item_category != "block":
		show_notification("Select a block first.")
		return
	var place_block := _sanitize_block_id(selected_item_type, selected_place_block)
	if int(inventory.get(place_block, 0)) <= 0:
		show_notification("No %s left." % get_item_display_name(place_block, "block"))
		return
	var item_data := get_item_data(place_block)
	var place_layer := _sanitize_layer(str(item_data.get("place_layer", selected_place_layer)))
	var grid_pos := _world_to_grid(world_position)
	if not _can_reach_backend_grid_action(grid_pos, "place"):
		return
	var network := _get_network_manager()
	_send_custom_trusted_state(true)
	if network != null and network.has_method("send_world_block_update"):
		var sent := bool(network.send_world_block_update("place", place_layer, grid_pos, place_block, current_world_name))
		_log("[CustomActionClient] action=place target=%s layer=%s block=%s sent=%s trusted_tick=%d" % [str(grid_pos), place_layer, place_block, str(sent), last_server_tick])
		if not sent:
			_log_block_action_send_failure("place", place_layer, grid_pos, place_block)


func _can_send_backend_block_action(action: String) -> bool:
	_update_backend_session_state()
	if not backend_ws_connected:
		_log_action_preflight(action, "backend_disconnected")
		_log("[CustomActionClient] %s rejected before send: backend websocket disconnected." % action)
		return false
	if not backend_authenticated:
		_log_action_preflight(action, "backend_session_not_authenticated")
		_log("[CustomActionClient] %s rejected before send: backend session not authenticated." % action)
		return false
	if not backend_world_joined:
		_log_action_preflight(action, "world_not_joined")
		_log("[CustomActionClient] %s rejected before send: backend world not joined yet." % action)
		return false
	if not backend_inventory_loaded:
		_log_action_preflight(action, "inventory_not_loaded")
		_log("[CustomActionClient] %s rejected before send: backend inventory not loaded yet." % action)
		return false
	if last_server_tick <= 0:
		_log_action_preflight(action, "trusted_position_missing")
		_log("[CustomActionClient] %s rejected before send: no authoritative movement snapshot yet." % action)
		return false
	if not real_world_test_enabled:
		_log_action_preflight(action, "real_world_bridge_disabled")
		_log("[CustomActionClient] %s rejected before send: real-world bridge is disabled." % action)
		return false
	if test_world == null:
		_log_action_preflight(action, "world_node_missing")
		return false
	var network := _get_network_manager()
	if network == null:
		_log_action_preflight(action, "network_manager_missing")
		_log("[CustomActionClient] %s rejected before send: NetworkManager not found." % action)
		return false
	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		_update_backend_session_state(network)
		_log_action_preflight(action, "backend_disconnected")
		var connection_text = "unknown"
		if network.has_method("get_server_connection_state_text"):
			connection_text = str(network.get_server_connection_state_text())
		_log("[CustomActionClient] %s rejected before send: backend websocket disconnected (%s)." % [action, connection_text])
		return false
	if network.has_method("is_server_session_authenticated") and not bool(network.is_server_session_authenticated()):
		_update_backend_session_state(network)
		_log_action_preflight(action, "backend_session_not_authenticated")
		_log("[CustomActionClient] %s rejected before send: backend session not authenticated." % action)
		return false
	if current_world_name.strip_edges() == "":
		_log_action_preflight(action, "missing_world")
		_log("[CustomActionClient] %s rejected before send: missing current world name." % action)
		return false
	return true


func _log_action_preflight(action: String, reason: String) -> void:
	_update_backend_session_state()
	_log("[CustomActionPreflight] backend_connected=%s backend_authenticated=%s profile_id=%s world=%s inventory_loaded=%s trusted_position=%s action=%s reason=%s account_id=%s game_player_id=%s username=%s world_joined=%s backend_url=%s backend_state=%s auth_error=%s" % [
		str(backend_ws_connected),
		str(backend_authenticated),
		backend_profile_id,
		current_world_name,
		str(backend_inventory_loaded),
		str(last_server_tick > 0),
		action,
		reason,
		backend_account_id,
		backend_game_player_id,
		backend_username,
		str(backend_world_joined),
		_get_backend_connection_url(),
		_get_backend_connection_state_text(),
		backend_auth_error_message,
	])


func _log_block_action_send_failure(action: String, layer: String, grid_pos: Vector2i, block_id: String) -> void:
	var network := _get_network_manager()
	var state := "missing NetworkManager"
	var connected := "n/a"
	var authenticated := "n/a"
	if network != null:
		if network.has_method("get_server_connection_state_text"):
			state = str(network.get_server_connection_state_text())
		else:
			state = "n/a"
		if network.has_method("is_connected_to_server"):
			connected = str(network.is_connected_to_server())
		if network.has_method("is_server_session_authenticated"):
			authenticated = str(network.is_server_session_authenticated())

	_log("[CustomActionClient] %s failed after send: target=%s layer=%s block=%s world=%s connected=%s auth=%s ws=%s snapshot_tick=%d" % [
		action,
		str(grid_pos),
		layer,
		block_id,
		current_world_name,
		connected,
		authenticated,
		state,
		last_server_tick,
	])


func _can_reach_backend_grid_action(grid_pos: Vector2i, action: String) -> bool:
	var origin := _get_backend_block_action_origin()
	var target := _grid_to_reach_point(grid_pos)
	var distance := origin.distance_to(target)
	if distance <= WEBSOCKET_BLOCK_ACTION_REACH_PIXELS:
		return true

	_log("[CustomActionClient] %s skipped: target=%s distance=%.1fpx max=%.1fpx (4 tiles)" % [
		action,
		str(grid_pos),
		distance,
		WEBSOCKET_BLOCK_ACTION_REACH_PIXELS,
	])
	return false


func _get_backend_block_action_origin() -> Vector2:
	if last_server_tick > 0:
		return last_server_authoritative_position
	if local_player != null and is_instance_valid(local_player):
		return local_player.global_position
	return Vector2.ZERO


func _grid_to_reach_point(grid_pos: Vector2i) -> Vector2:
	var tile_size := float(_get_world_tile_size())
	return Vector2(float(grid_pos.x) * tile_size, float(grid_pos.y) * tile_size)


func _get_world_tile_size() -> int:
	if test_world != null and test_world.has_method("get_tile_size"):
		return int(test_world.get_tile_size())
	var summary := _get_world_debug_summary()
	return max(1, int(summary.get("tile_size", 32)))


func _get_tile_info(world_position: Vector2) -> Dictionary:
	if test_world == null or not test_world.has_method("get_tile_info_at_world"):
		return {}
	var value = test_world.get_tile_info_at_world(world_position)
	if value is Dictionary:
		return value
	return {}


func _world_to_grid(world_position: Vector2) -> Vector2i:
	if test_world != null and test_world.has_method("world_to_grid"):
		var value = test_world.world_to_grid(world_position)
		if value is Vector2i:
			return value
	return Vector2i(int(round(world_position.x / 32.0)), int(round(world_position.y / 32.0)))


func _log_phase_g_block_actions_disabled_once() -> void:
	if phase_g_block_actions_notice_printed:
		return
	phase_g_block_actions_notice_printed = true
	_log("[PhaseG] Block actions disabled during real-world movement test.")


func _get_ping_text() -> String:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or not (peer is ENetMultiplayerPeer):
		return "n/a"

	var enet_peer := peer as ENetMultiplayerPeer
	var remote_peer_id := 1
	if is_server:
		var peers: Array = multiplayer.get_peers()
		if peers.is_empty():
			return "n/a"
		remote_peer_id = int(peers[0])

	var packet_peer: ENetPacketPeer = enet_peer.get_peer(remote_peer_id)
	if packet_peer == null:
		return "n/a"

	var round_trip_ms := int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	if round_trip_ms <= 0:
		return "n/a"
	return "%d ms" % round_trip_ms


func _print_startup_config(role: String) -> void:
	_log("[CustomMovementTest] %s movement config: %s ACTIVE_INTERPOLATION_DELAY_MS=%d" % [
		role,
		Protocol.config_summary(),
		interpolator.get_interpolation_delay_ms(),
	])


func _format_vector(value: Vector2) -> String:
	return "(%.1f, %.1f)" % [value.x, value.y]


func _log(message: String) -> void:
	print(message)
	if log_file == null:
		return
	log_file.store_line(message)
	log_file.flush()
