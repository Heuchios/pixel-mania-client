extends Node

class CollisionDebugOverlay:
	extends Node2D

	var manager: Node = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if manager == null or not is_instance_valid(manager):
			return
		if manager.has_method("_draw_collision_debug_overlay"):
			manager.call("_draw_collision_debug_overlay", self)

const PLAYER_SCENE := preload("res://Scenes/player/netfox_player.tscn")
const CHAT_BUBBLE_COMPONENT := preload("res://Scripts/chat_bubble_component.gd")

const DEFAULT_PORT := 24566
const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_MAX_CLIENTS := 50
const BODY_AUTHORITY := 1
const LOG_PREFIX := "[NetfoxReal]"
const DEBUG_ARG := "--netfox-real-debug"
const DEBUG_ENV := "NETFOX_REAL_DEBUG"
const HOST_ARG := "--netfox-host"
const PORT_ARG := "--netfox-port"
const ROLE_ARG := "--netfox-role"
const MAX_CLIENTS_ARG := "--netfox-max-clients"
const HOST_ENV := "PIXELMANIA_NETFOX_HOST"
const PORT_ENV := "PIXELMANIA_NETFOX_PORT"
const MAX_CLIENTS_ENV := "PIXELMANIA_NETFOX_MAX_CLIENTS"
const HOST_PROJECT_SETTING := "pixelmania/netfox/host"
const PORT_PROJECT_SETTING := "pixelmania/netfox/port"
const MAX_CLIENTS_PROJECT_SETTING := "pixelmania/netfox/max_clients"
const PLAYER_AUDIT_ARG := "--netfox-player-audit"
const PLAYER_AUDIT_ENV := "NETFOX_PLAYER_AUDIT"
const SERVER_PLAYER_ARG := "--server-player"
const SERVER_PLAYER_ENV := "NETFOX_SERVER_PLAYER"
const PLAYERS_ROOT_NAME := "Players"
const WEBSOCKET_PLAYER_NAME := "Player"
const REMOTE_PLAYER_Z_OFFSET := -300
const STATE_BRIDGE_INTERVAL_SECONDS := 0.05
const CLIENT_CONNECT_TIMEOUT_SECONDS := 8.0
const SPAWN_ACK_TIMEOUT_SECONDS := 10.0
const SPAWN_REJECTION_RETRY_DELAY_MSEC := 2000
const NETFOX_STATUS_LOG_INTERVAL_MSEC := 1500
const PLAYER_PUNCH_GRID_HORIZONTAL_TOLERANCE := 36.0
const PLAYER_PUNCH_GRID_VERTICAL_TOLERANCE := 58.0
const NETFOX_ROLLBACK_HISTORY_LIMIT := 240
const NETFOX_ROLLBACK_INPUT_BROADCAST := false
const SERVER_WORLD_STATE_DEV_ENDPOINT := "/dev/netfox/world-state"
const SERVER_WORLD_STATE_LIVE_ENDPOINT := "/netfox/server/world-state"
const SERVER_REGISTER_ROUTE_ENDPOINT := "/netfox/server/register-route"
const SERVER_VERIFY_SPAWN_TICKET_ENDPOINT := "/netfox/server/verify-spawn-ticket"
const SERVER_WORLD_STATE_TOKEN_ARG := "--netfox-server-token"
const SERVER_WORLD_STATE_TOKEN_ENV := "PIXELMANIA_NETFOX_SERVER_TOKEN"
const BACKEND_SERVER_WORLD_STATE_TOKEN_ENV := "NETFOX_SERVER_WORLD_STATE_TOKEN"
const SERVER_WORLD_STATE_TIMEOUT_SECONDS := 15.0
const SERVER_ROUTE_REGISTER_TIMEOUT_SECONDS := 5.0
const SERVER_ROUTE_REGISTER_INTERVAL_MSEC := 15000
const SERVER_SPAWN_TICKET_VERIFY_TIMEOUT_SECONDS := 8.0
const SPAWN_TICKET_WAIT_TIMEOUT_SECONDS := 8.0
const SPAWN_TICKET_REQUEST_RETRY_MSEC := 1000
const PUBLIC_HOST_ARG := "--netfox-public-host"
const PUBLIC_PORT_ARG := "--netfox-public-port"
const PUBLIC_HOST_ENV := "PIXELMANIA_NETFOX_PUBLIC_HOST"
const PUBLIC_PORT_ENV := "PIXELMANIA_NETFOX_PUBLIC_PORT"
const CORRECTION_DEBUG_ARG := "--netfox-correction-debug"
const CORRECTION_DEBUG_ENV := "NETFOX_CORRECTION_DEBUG"
const COLLISION_DEBUG_ARG := "--netfox-collision-debug"
const COLLISION_DEBUG_ENV := "NETFOX_COLLISION_DEBUG"
const PHASE7_IDENTITY_LOG_PREFIX := "[Phase7Identity]"
const PHASE7_IDENTITY_DEBUG_ARG := "--netfox-identity-debug"
const PHASE7_IDENTITY_DEBUG_ENV := "NETFOX_IDENTITY_DEBUG"
const CORRECTION_DISTANCE_THRESHOLD := 2.0
const CORRECTION_LOG_MIN_INTERVAL_MSEC := 250
const COLLISION_LOG_MIN_INTERVAL_MSEC := 250
const COLLISION_AUDIT_MIN_INTERVAL_MSEC := 1000
const WORLD_COLLISION_FINGERPRINT_MIN_INTERVAL_MSEC := 1000
const COLLISION_READY_REFRESH_MIN_INTERVAL_MSEC := 100
const COLLISION_AUDIT_MAX_DETAILS := 16
const COLLISION_DEBUG_COLOR := Color(1.0, 0.1, 0.1, 0.18)
const COLLISION_DEBUG_OUTLINE_COLOR := Color(1.0, 0.8, 0.1, 0.55)
const WORLD_COLLISION_READY_META := "netfox_tilemap_collision_stream_ready"
const WORLD_COLLISION_READY_CACHE_KEY_META := "netfox_tilemap_collision_stream_cache_key"

var world: Node = null
var players_root: Node2D = null
var spawned_players: Dictionary = {}
var player_display_names: Dictionary = {}
var player_identity_payloads: Dictionary = {}
var pending_spawn_requests: Dictionary = {}
var spawning_peer_ids: Dictionary = {}
var spawn_verification_peer_ids: Dictionary = {}
var player_visibility_confirmations: Dictionary = {}
var mode := "standalone"
var host := DEFAULT_ADDRESS
var port := DEFAULT_PORT
var max_clients := DEFAULT_MAX_CLIENTS
var debug_enabled := false
var player_audit_enabled := false
var spawn_server_player := false
var spawn_request_sent := false
var spawn_request_in_progress := false
var spawn_request_generation := 0
var spawn_rejected_until_msec := 0
var last_spawn_rejection_reason := ""
var startup_timing_logged := false
var client_connect_deadline_msec := 0
var spawn_ack_deadline_msec := 0
var last_netfox_status_log_msec := 0
var last_netfox_status_key := ""
var last_pending_spawn_status_log_msec := 0
var debug_label: Label = null
var state_bridge_timer := 0.0
var netfox_chat_bubbles: Dictionary = {}
var client_route_retry_pending := false
var route_registration_in_progress := false
var last_route_registration_msec := 0
var route_registration_token_missing_logged := false
var last_route_registration_wait_log_msec := 0
var server_world_load_started := false
var server_world_load_complete := false
var server_world_load_failed := false
var correction_debug_enabled := false
var collision_debug_enabled := false
var phase7_identity_debug_enabled := false
var world_collision_fingerprint_logged := false
var last_world_collision_fingerprint_text := ""
var last_world_collision_fingerprint_log_msec := 0
var last_correction_log_msec_by_peer: Dictionary = {}
var last_collision_log_msec_by_key: Dictionary = {}
var last_collision_audit_msec := 0
var world_collision_ready_cached := false
var world_collision_ready_cache_key := ""
var last_collision_stream_refresh_msec := 0
var collision_debug_overlay: Node2D = null
var phase7_identity_logged_keys: Dictionary = {}


func get_overhead_layer():
	if world == null:
		return null
	if world.has_method("get_ui_overhead_layer"):
		return world.get_ui_overhead_layer()
	var ui_layer = world.get("ui_layer") if world.get("ui_layer") != null else null
	return ui_layer


func setup(world_ref: Node) -> void:
	world = world_ref
	if world == null or not MovementMode.is_netfox_real():
		return

	debug_enabled = _is_flag_enabled(DEBUG_ARG, DEBUG_ENV)
	player_audit_enabled = debug_enabled or _is_flag_enabled(PLAYER_AUDIT_ARG, PLAYER_AUDIT_ENV)
	correction_debug_enabled = debug_enabled or _is_flag_enabled(CORRECTION_DEBUG_ARG, CORRECTION_DEBUG_ENV)
	collision_debug_enabled = debug_enabled or _is_flag_enabled(COLLISION_DEBUG_ARG, COLLISION_DEBUG_ENV)
	phase7_identity_debug_enabled = debug_enabled or _is_flag_enabled(PHASE7_IDENTITY_DEBUG_ARG, PHASE7_IDENTITY_DEBUG_ENV)
	spawn_server_player = _is_flag_enabled(SERVER_PLAYER_ARG, SERVER_PLAYER_ENV)
	_apply_netfox_tickrate_settings("setup")
	_apply_netfox_input_routing_settings("setup")
	_setup_players_root()
	_disable_websocket_player()
	_clear_legacy_websocket_player_visuals("setup")
	_connect_multiplayer_signals()
	_connect_correction_debug_signal()
	_setup_debug_overlay()
	_setup_collision_debug_overlay()
	_parse_launch_mode()
	if mode != "client":
		_log_netfox_startup_timing_deferred("setup")
	_audit_player_nodes("setup")


func _process(_delta: float) -> void:
	if not MovementMode.is_netfox_real():
		return

	_sync_trusted_state_bridge(_delta)
	_tick_server_route_registration()
	_watch_netfox_connection_status()
	_ensure_client_spawn_request_for_active_world()
	_update_netfox_chat_bubbles()
	_sync_local_player_identity_metadata()
	_sync_spawned_player_positions_from_scene()
	_process_pending_spawn_requests()
	_log_world_collision_fingerprint_once("ready")
	if debug_enabled:
		_update_debug_overlay()
	if collision_debug_overlay != null and is_instance_valid(collision_debug_overlay):
		collision_debug_overlay.queue_redraw()


func notify_world_left(world_name: String = "", reason: String = "world-left") -> void:
	if not MovementMode.is_netfox_real():
		return

	_reset_world_collision_runtime_state()
	_reset_client_spawn_request_state(reason)

	if mode != "client":
		return

	var local_peer_id := _get_local_peer_id()
	if _is_multiplayer_connected() and local_peer_id > BODY_AUTHORITY:
		request_leave_world.rpc_id(BODY_AUTHORITY, world_name.strip_edges().to_upper(), reason)

	_clear_players()
	print("%s Client cleared Netfox players for world leave. world=%s reason=%s peer=%d" % [
		LOG_PREFIX,
		world_name.strip_edges().to_upper(),
		reason,
		local_peer_id
	])


func notify_world_entry_started(_world_name: String = "", reason: String = "world-entry-started") -> void:
	if not MovementMode.is_netfox_real():
		return

	_reset_world_collision_runtime_state()
	_reset_client_spawn_request_state(reason)

	if mode != "client":
		return

	_clear_players()
	if _is_multiplayer_connected():
		call_deferred("_request_spawn_when_network_time_ready")


func notify_world_entry_ready(_world_name: String = "", _reason: String = "world-entry-ready") -> void:
	if not MovementMode.is_netfox_real():
		return
	if mode != "client" or not _is_multiplayer_connected():
		return
	if _has_valid_local_netfox_player():
		return

	call_deferred("_request_spawn_when_network_time_ready")


func _reset_client_spawn_request_state(reason: String = "") -> void:
	if mode != "client":
		return

	spawn_request_generation += 1
	spawn_request_in_progress = false
	spawn_request_sent = false
	spawn_ack_deadline_msec = 0
	spawn_rejected_until_msec = 0
	last_spawn_rejection_reason = ""
	last_netfox_status_key = ""
	if debug_enabled:
		print("%s Reset client spawn request state. reason=%s generation=%d" % [
			LOG_PREFIX,
			reason,
			spawn_request_generation
		])


func _reset_world_collision_runtime_state() -> void:
	_clear_world_collision_ready_cache()
	world_collision_fingerprint_logged = false
	last_world_collision_fingerprint_text = ""
	last_collision_stream_refresh_msec = 0


func _has_valid_local_netfox_player() -> bool:
	if world == null:
		return false

	var local_player = world.get("player")
	if local_player == null or not is_instance_valid(local_player):
		return false
	if not (local_player is Node):
		return false

	var peer_id := _get_peer_id_for_player(local_player)
	return peer_id == _get_local_peer_id()


func is_local_player_ready_for_world() -> bool:
	if not MovementMode.is_netfox_real():
		return true
	if mode == "server":
		return _is_server_world_authoritative_ready()
	if mode != "client":
		return true
	if not _is_multiplayer_connected():
		return false
	if not _has_valid_local_netfox_player():
		return false

	var local_world: String = _get_current_world_id()
	var player_world: String = _get_world_id_for_peer(_get_local_peer_id())
	if local_world != "" and player_world != "" and local_world != player_world:
		return false

	return _is_world_collision_ready()


func _ensure_client_spawn_request_for_active_world() -> void:
	if mode != "client":
		return
	if spawn_request_sent or spawn_request_in_progress:
		return
	if not _is_multiplayer_connected():
		return
	if world == null:
		return
	var now_msec: int = Time.get_ticks_msec()
	if spawn_rejected_until_msec > now_msec:
		return

	var in_world_value = world.get("in_world")
	if in_world_value != null and not bool(in_world_value):
		return
	if bool(world.get_meta("world_entry_in_progress", false)):
		return
	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		return
	if bool(world.get("applying_network_world_update")):
		return
	if _has_valid_local_netfox_player():
		return

	call_deferred("_request_spawn_when_network_time_ready")


func _exit_tree() -> void:
	var correction_callback := Callable(self, "_on_netfox_authoritative_state")
	if NetworkSynchronizationServer._on_state.is_connected(correction_callback):
		NetworkSynchronizationServer._on_state.disconnect(correction_callback)
	_clear_players(true)
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _setup_players_root() -> void:
	var main_root := world.get_parent()
	if main_root == null:
		return

	players_root = main_root.get_node_or_null(PLAYERS_ROOT_NAME) as Node2D
	if players_root == null:
		players_root = Node2D.new()
		players_root.name = PLAYERS_ROOT_NAME
		main_root.add_child(players_root)

	players_root.z_as_relative = false
	players_root.z_index = int(world.get("LOCAL_PLAYER_Z_INDEX")) if world.get("LOCAL_PLAYER_Z_INDEX") != null else 3900


func _disable_websocket_player() -> void:
	var main_root := world.get_parent()
	if main_root == null:
		return

	var websocket_player := main_root.get_node_or_null(WEBSOCKET_PLAYER_NAME)
	if websocket_player == null:
		world.set("player", null)
		return

	websocket_player.set_process(false)
	websocket_player.set_physics_process(false)
	websocket_player.set_process_input(false)
	websocket_player.set_process_unhandled_input(false)
	if websocket_player is CanvasItem:
		(websocket_player as CanvasItem).visible = false

	for shape in websocket_player.find_children("*", "CollisionShape2D", true, false):
		if shape is CollisionShape2D:
			(shape as CollisionShape2D).disabled = true

	websocket_player.set_meta("netfox_disabled_websocket_player", true)
	world.set("player", null)
	print("%s Disabled WebSocket Player node for %s mode." % [LOG_PREFIX, MovementMode.get_mode_name()])


func _restore_websocket_player_for_fallback(reason: String = "", fallback_position = null, fallback_velocity = null) -> void:
	var main_root: Node = null
	if world != null:
		main_root = world.get_parent()
	if main_root == null:
		return

	var websocket_player := main_root.get_node_or_null(WEBSOCKET_PLAYER_NAME)
	if websocket_player == null:
		return

	if fallback_position is Vector2 and websocket_player is Node2D:
		(websocket_player as Node2D).global_position = fallback_position
	if fallback_velocity is Vector2 and websocket_player is CharacterBody2D:
		(websocket_player as CharacterBody2D).velocity = fallback_velocity

	websocket_player.set_process(true)
	websocket_player.set_physics_process(true)
	websocket_player.set_process_input(true)
	websocket_player.set_process_unhandled_input(true)
	if websocket_player is CanvasItem:
		(websocket_player as CanvasItem).visible = true

	for shape in websocket_player.find_children("*", "CollisionShape2D", true, false):
		if shape is CollisionShape2D:
			(shape as CollisionShape2D).disabled = false

	websocket_player.set_meta("netfox_disabled_websocket_player", false)
	world.set("player", websocket_player)
	if world.has_method("ensure_player_draw_on_top"):
		world.ensure_player_draw_on_top()
	if world.has_method("update_username_label"):
		world.update_username_label()
	print("%s Restored WebSocket Player fallback. reason=%s" % [LOG_PREFIX, reason])


func _fallback_to_websocket_movement(reason: String) -> void:
	if _retry_netfox_client_without_websocket_fallback(reason):
		return

	var fallback_position = null
	var fallback_velocity = null
	var local_player: Node = null
	if world != null:
		local_player = world.get("player") as Node
	if local_player is Node2D:
		fallback_position = (local_player as Node2D).global_position
	var raw_velocity = local_player.get("velocity") if local_player != null else null
	if raw_velocity is Vector2:
		fallback_velocity = raw_velocity

	print("%s Falling back to WebSocket movement. reason=%s" % [LOG_PREFIX, reason])
	if MovementMode != null and MovementMode.has_method("set_mode"):
		MovementMode.set_mode(MovementMode.Mode.WEBSOCKET)
	_clear_players()
	_restore_websocket_player_for_fallback(reason, fallback_position, fallback_velocity)


func _retry_netfox_client_without_websocket_fallback(reason: String) -> bool:
	if mode != "client":
		return false
	if not MovementMode.is_netfox_real():
		return false
	if not _should_wait_for_backend_spawn_ticket():
		return false

	client_connect_deadline_msec = 0
	_reset_client_spawn_request_state("netfox-retry-" + reason)
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_clear_players()

	if client_route_retry_pending:
		return true

	client_route_retry_pending = true
	push_warning("%s Skipping WebSocket fallback in NETFOX_REAL client mode. reason=%s route=%s" % [
		LOG_PREFIX,
		reason,
		_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
	])
	call_deferred("_run_deferred_netfox_client_retry", reason)
	return true


func _run_deferred_netfox_client_retry(reason: String) -> void:
	await get_tree().create_timer(2.0).timeout
	client_route_retry_pending = false
	if not is_inside_tree() or mode != "client" or not MovementMode.is_netfox_real():
		return
	print("%s Retrying Netfox client startup after %s." % [LOG_PREFIX, reason])
	_start_client_after_backend_route_ready()


func _clear_legacy_websocket_player_visuals(reason: String = "") -> void:
	var removed := 0
	var main_root: Node = null
	if world != null:
		main_root = world.get_parent()
	if main_root != null:
		removed += _queue_legacy_child_nodes(main_root, [], ["RemotePlayer_", "RemoteFishingBobber_"])

	if world != null:
		var remote_players_root := world.get_node_or_null("RemotePlayers")
		if remote_players_root != null and is_instance_valid(remote_players_root):
			remote_players_root.queue_free()
			removed += 1
		removed += _queue_legacy_child_nodes(world, ["PlayerWorldFadeFX"], ["RemotePlayer_", "RemoteFishingBobber_"])

	var ui_cleanup_layers = []
	var ui_layer = world.get("ui_layer") if world != null and world.get("ui_layer") != null else null
	if ui_layer is Node:
		ui_cleanup_layers.append(ui_layer)
	var overhead_layer = get_overhead_layer()
	if overhead_layer is Node and not ui_cleanup_layers.has(overhead_layer):
		ui_cleanup_layers.append(overhead_layer)
	for cleanup_layer in ui_cleanup_layers:
		removed += _queue_legacy_child_nodes(cleanup_layer, [], ["RemoteUsernameLabel_", "RemoteChatBubbleUI_", "RemoteChatBubble_", "NetfoxChatBubbleUI_"])

	if players_root != null:
		for player_node in players_root.get_children():
			removed += _queue_legacy_child_nodes(player_node, ["PlayerWorldFadeFX"], [])

	if removed > 0:
		print("%s Removed %d legacy WebSocket player visual node(s) in NETFOX_REAL. reason=%s" % [LOG_PREFIX, removed, reason])


func _queue_legacy_child_nodes(parent: Node, exact_names: Array, prefixes: Array) -> int:
	if parent == null or not is_instance_valid(parent):
		return 0

	var removed := 0
	for child in parent.get_children():
		if child == null or not is_instance_valid(child):
			continue

		var child_name := str(child.name)
		var should_remove := exact_names.has(child_name)
		if not should_remove:
			for prefix in prefixes:
				if child_name.begins_with(str(prefix)):
					should_remove = true
					break

		if should_remove:
			child.queue_free()
			removed += 1

	return removed


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
	if not NetworkTime.after_client_sync.is_connected(_on_network_time_client_synced):
		NetworkTime.after_client_sync.connect(_on_network_time_client_synced)


func _connect_correction_debug_signal() -> void:
	if not MovementMode.is_netfox_real():
		return
	if not correction_debug_enabled:
		return

	var callback := Callable(self, "_on_netfox_authoritative_state")
	if not NetworkSynchronizationServer._on_state.is_connected(callback):
		NetworkSynchronizationServer._on_state.connect(callback)


func _on_netfox_authoritative_state(snapshot) -> void:
	if not correction_debug_enabled:
		return
	if snapshot == null:
		return
	if not snapshot.has_method("get_subjects"):
		return

	for subject in snapshot.get_subjects():
		if not (subject is Node2D):
			continue

		var player := subject as Node2D
		if not _is_audit_netfox_player(player):
			continue
		if not snapshot.has_method("has_property") or not snapshot.has_property(player, ^"position"):
			continue

		var authoritative_position = snapshot.get_property(player, ^"position")
		if not (authoritative_position is Vector2):
			continue

		var local_position := player.position
		var correction_distance := local_position.distance_to(authoritative_position)
		if correction_distance <= CORRECTION_DISTANCE_THRESHOLD:
			continue

		var peer_id := _get_audit_peer_id(player)
		var now_msec := Time.get_ticks_msec()
		var last_log_msec := int(last_correction_log_msec_by_peer.get(peer_id, 0))
		if now_msec - last_log_msec < CORRECTION_LOG_MIN_INTERVAL_MSEC:
			continue
		last_correction_log_msec_by_peer[peer_id] = now_msec

		var velocity := Vector2.ZERO
		var authoritative_velocity = snapshot.get_property(player, ^"velocity") if snapshot.has_property(player, ^"velocity") else null
		if authoritative_velocity is Vector2:
			velocity = authoritative_velocity
		else:
			var raw_velocity = player.get("velocity")
			if raw_velocity is Vector2:
				velocity = raw_velocity

		_print_player_collision_context(
			"rollback-correction",
			player,
			int(snapshot.tick),
			correction_distance,
			authoritative_position,
			Vector2.ZERO,
			false,
			velocity,
			local_position,
			authoritative_position
		)


func _parse_launch_mode() -> void:
	host = _resolve_host()
	port = _resolve_port()
	max_clients = _resolve_max_clients()
	var requested_role: String = "standalone"
	if MovementMode.has_method("get_netfox_role"):
		requested_role = str(MovementMode.get_netfox_role("standalone"))
	var wants_server: bool = MovementMode.has_launch_arg("--server") or MovementMode.has_launch_arg("--netfox-server") or requested_role == "server"
	var wants_client: bool = MovementMode.has_launch_arg("--client") or MovementMode.has_launch_arg("--netfox-client") or requested_role == "client"
	if wants_server and not wants_client:
		start_server()
	elif wants_client and not wants_server:
		mode = "client"
		call_deferred("_start_client_after_backend_route_ready")
	else:
		mode = "standalone"
		print("%s Standalone NETFOX_REAL mode. Set --netfox-server/--netfox-client, --server/--client, or pixelmania/netfox/default_role for networked movement." % LOG_PREFIX)
		call_deferred("_spawn_standalone_player_when_world_ready")


func _spawn_standalone_player_when_world_ready() -> void:
	while is_inside_tree() and mode == "standalone" and not _is_peer_ready_for_spawn(_get_local_peer_id()):
		await get_tree().process_frame
	if not is_inside_tree() or mode != "standalone":
		return
	var peer_id := _get_local_peer_id()
	if spawned_players.has(peer_id):
		return
	_spawn_player(peer_id, _get_spawn_position(peer_id), _get_local_display_name(), _get_local_identity_payload())


func _resolve_host() -> String:
	var launch_host: String = _get_first_launch_arg_value([HOST_ARG, "--host"], "")
	if launch_host.strip_edges() != "":
		return launch_host.strip_edges()

	var env_host: String = OS.get_environment(HOST_ENV).strip_edges()
	if env_host != "":
		return env_host

	var route: Dictionary = _get_backend_netfox_spawn_route()
	var route_host: String = str(route.get("host", "")).strip_edges()
	if route_host != "":
		return route_host

	if ProjectSettings.has_setting(HOST_PROJECT_SETTING):
		var project_host: String = str(ProjectSettings.get_setting(HOST_PROJECT_SETTING, DEFAULT_ADDRESS)).strip_edges()
		if project_host != "":
			return project_host

	return DEFAULT_ADDRESS


func _resolve_port() -> int:
	var launch_port: String = _get_first_launch_arg_value([PORT_ARG, "--port"], "")
	if launch_port.strip_edges() != "":
		return _parse_positive_int(launch_port, DEFAULT_PORT, 1, 65535)

	var env_port: String = OS.get_environment(PORT_ENV).strip_edges()
	if env_port != "":
		return _parse_positive_int(env_port, DEFAULT_PORT, 1, 65535)

	var route: Dictionary = _get_backend_netfox_spawn_route()
	var route_port: int = int(route.get("port", 0))
	if route_port > 0:
		return _parse_positive_int(str(route_port), DEFAULT_PORT, 1, 65535)

	if ProjectSettings.has_setting(PORT_PROJECT_SETTING):
		return _parse_positive_int(str(ProjectSettings.get_setting(PORT_PROJECT_SETTING, DEFAULT_PORT)), DEFAULT_PORT, 1, 65535)

	return DEFAULT_PORT


func _has_explicit_netfox_host_override() -> bool:
	if _get_first_launch_arg_value([HOST_ARG, "--host"], "").strip_edges() != "":
		return true
	return OS.get_environment(HOST_ENV).strip_edges() != ""


func _has_explicit_netfox_port_override() -> bool:
	if _get_first_launch_arg_value([PORT_ARG, "--port"], "").strip_edges() != "":
		return true
	return OS.get_environment(PORT_ENV).strip_edges() != ""


func _is_default_netfox_target(candidate_host: String, candidate_port: int) -> bool:
	var clean_host: String = candidate_host.strip_edges().to_lower()
	var is_default_host: bool = clean_host == "" or clean_host == DEFAULT_ADDRESS or clean_host == "localhost" or clean_host == "::1"
	return is_default_host and candidate_port == DEFAULT_PORT


func _has_configured_netfox_target_override() -> bool:
	var has_explicit_host: bool = _has_explicit_netfox_host_override()
	var has_explicit_port: bool = _has_explicit_netfox_port_override()
	if has_explicit_host or has_explicit_port:
		var explicit_host: String = _get_first_launch_arg_value([HOST_ARG, "--host"], "").strip_edges()
		if explicit_host == "":
			explicit_host = OS.get_environment(HOST_ENV).strip_edges()
		if explicit_host == "":
			explicit_host = host.strip_edges()
		if explicit_host == "":
			explicit_host = DEFAULT_ADDRESS

		var explicit_port_text: String = _get_first_launch_arg_value([PORT_ARG, "--port"], "").strip_edges()
		if explicit_port_text == "":
			explicit_port_text = OS.get_environment(PORT_ENV).strip_edges()

		var explicit_port: int = DEFAULT_PORT
		if explicit_port_text != "":
			explicit_port = _parse_positive_int(explicit_port_text, DEFAULT_PORT, 1, 65535)
		elif port > 0:
			explicit_port = port

		return not _is_default_netfox_target(explicit_host, explicit_port)

	var project_host: String = ""
	if ProjectSettings.has_setting(HOST_PROJECT_SETTING):
		project_host = str(ProjectSettings.get_setting(HOST_PROJECT_SETTING, "")).strip_edges()

	var project_port: int = DEFAULT_PORT
	if ProjectSettings.has_setting(PORT_PROJECT_SETTING):
		project_port = _parse_positive_int(str(ProjectSettings.get_setting(PORT_PROJECT_SETTING, DEFAULT_PORT)), DEFAULT_PORT, 1, 65535)

	if project_host == "" and project_port == DEFAULT_PORT:
		return false
	return not _is_default_netfox_target(project_host, project_port)


func _is_debug_or_editor_build() -> bool:
	return OS.has_feature("editor") or OS.has_feature("debug")


func _is_local_netfox_target() -> bool:
	var clean_host: String = host.strip_edges().to_lower()
	return clean_host == DEFAULT_ADDRESS or clean_host == "localhost" or clean_host == "::1"


func _can_use_direct_netfox_target_without_backend_route() -> bool:
	if mode != "client":
		return false
	if not _is_debug_or_editor_build():
		return false
	if host.strip_edges() == "" or port <= 0:
		return false
	return _has_configured_netfox_target_override()


func _should_require_backend_netfox_route() -> bool:
	if not _should_wait_for_backend_identity():
		return false
	if mode != "client":
		return false
	return not _can_use_direct_netfox_target_without_backend_route()


func _get_backend_netfox_spawn_route(world_name: String = "") -> Dictionary:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("get_netfox_spawn_route"):
		return {}

	var requested_world: String = world_name.strip_edges().to_upper()
	if requested_world == "":
		requested_world = _get_current_world_id()

	var route_value: Variant = network.get_netfox_spawn_route(requested_world)
	if route_value is Dictionary:
		return route_value.duplicate(true)
	return {}


func _get_backend_netfox_spawn_route_debug_text(world_name: String = "") -> String:
	var requested_world: String = world_name.strip_edges().to_upper()
	if requested_world == "":
		requested_world = _get_current_world_id()

	var route: Dictionary = _get_backend_netfox_spawn_route(requested_world)
	if route.is_empty():
		return "missing world=%s" % requested_world

	return "world=%s host=%s port=%d source=%s ticket=%s route_expires=%d ticket_expires=%d" % [
		str(route.get("world", requested_world)),
		str(route.get("host", "")),
		int(route.get("port", 0)),
		str(route.get("route_source", "")),
		str(str(route.get("ticket", "")).strip_edges() != ""),
		int(route.get("route_expires_at_ms", 0)),
		int(route.get("ticket_expires_at_ms", 0))
	]


func _refresh_client_route_from_backend(reason: String = "route-refresh") -> bool:
	if mode != "client":
		return false

	var route: Dictionary = _get_backend_netfox_spawn_route(_get_current_world_id())
	if route.is_empty():
		return false

	var route_host: String = str(route.get("host", "")).strip_edges()
	var route_port: int = int(route.get("port", 0))
	if route_host == "" or route_port <= 0:
		push_warning("%s Ignoring incomplete backend Netfox route. reason=%s %s" % [
			LOG_PREFIX,
			reason,
			_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
		])
		return false

	if not _has_explicit_netfox_host_override():
		host = route_host
	if not _has_explicit_netfox_port_override():
		port = _parse_positive_int(str(route_port), DEFAULT_PORT, 1, 65535)

	print("%s Client Netfox route ready. reason=%s target=%s:%d %s" % [
		LOG_PREFIX,
		reason,
		host,
		port,
		_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
	])
	return host.strip_edges() != "" and port > 0


func _resolve_max_clients() -> int:
	var launch_value: String = _get_first_launch_arg_value([MAX_CLIENTS_ARG], "")
	if launch_value.strip_edges() != "":
		return _parse_positive_int(launch_value, DEFAULT_MAX_CLIENTS, 1, 512)

	var env_value: String = OS.get_environment(MAX_CLIENTS_ENV).strip_edges()
	if env_value != "":
		return _parse_positive_int(env_value, DEFAULT_MAX_CLIENTS, 1, 512)

	if ProjectSettings.has_setting(MAX_CLIENTS_PROJECT_SETTING):
		return _parse_positive_int(str(ProjectSettings.get_setting(MAX_CLIENTS_PROJECT_SETTING, DEFAULT_MAX_CLIENTS)), DEFAULT_MAX_CLIENTS, 1, 512)

	return DEFAULT_MAX_CLIENTS


func _get_first_launch_arg_value(flag_names: Array, default_value: String = "") -> String:
	for flag_name in flag_names:
		var value: String = str(MovementMode.get_launch_arg_value(str(flag_name), ""))
		if value.strip_edges() != "":
			return value
	return default_value


func _parse_positive_int(value, fallback: int, min_value: int, max_value: int) -> int:
	var clean: String = str(value).strip_edges()
	if not clean.is_valid_int():
		return fallback
	return clampi(int(clean), min_value, max_value)


func _apply_netfox_tickrate_settings(reason: String) -> void:
	var target_tickrate := _parse_positive_int(
		str(ProjectSettings.get_setting("netfox/time/tickrate", 60)),
		60,
		1,
		240
	)
	var max_ticks_per_frame := _parse_positive_int(
		str(ProjectSettings.get_setting("netfox/time/max_ticks_per_frame", 8)),
		8,
		1,
		64
	)
	var sync_to_physics := bool(ProjectSettings.get_setting("netfox/time/sync_to_physics", true))

	ProjectSettings.set_setting("netfox/time/tickrate", target_tickrate)
	ProjectSettings.set_setting("netfox/time/max_ticks_per_frame", max_ticks_per_frame)
	ProjectSettings.set_setting("netfox/time/sync_to_physics", sync_to_physics)
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", target_tickrate)

	# Netfox caches these settings when its autoload enters the tree. Pin the
	# cached values before ENet starts so the handshake advertises the same rate
	# on dedicated servers and editor clients.
	Engine.physics_ticks_per_second = target_tickrate
	NetworkTime.set("_tickrate", target_tickrate)
	NetworkTime.set("_max_ticks_per_frame", max_ticks_per_frame)
	NetworkTime.set("_sync_to_physics", sync_to_physics)

	if debug_enabled:
		print("%s Applied tickrate settings reason=%s tickrate=%d physics_ticks=%d max_ticks_per_frame=%d sync_to_physics=%s" % [
			LOG_PREFIX,
			reason,
			NetworkTime.tickrate,
			Engine.physics_ticks_per_second,
			max_ticks_per_frame,
			str(sync_to_physics)
		])


func _apply_netfox_input_routing_settings(reason: String) -> void:
	ProjectSettings.set_setting("netfox/rollback/enable_input_broadcast", NETFOX_ROLLBACK_INPUT_BROADCAST)
	NetworkSynchronizationServer.set("_rb_enable_input_broadcast", NETFOX_ROLLBACK_INPUT_BROADCAST)

	if debug_enabled:
		print("%s Applied input routing reason=%s input_broadcast=%s" % [
			LOG_PREFIX,
			reason,
			str(NETFOX_ROLLBACK_INPUT_BROADCAST)
		])


func start_server() -> void:
	mode = "server"
	_apply_netfox_tickrate_settings("server-start")
	_apply_netfox_input_routing_settings("server-start")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		push_error("%s Failed to start ENet server on port %d: %s" % [LOG_PREFIX, port, error])
		return

	multiplayer.multiplayer_peer = peer
	client_connect_deadline_msec = 0
	print("%s ENet server started on UDP port %d advertised=%s:%d peer=%d mode=%s max_clients=%d." % [
		LOG_PREFIX,
		port,
		_get_server_route_public_host(),
		_get_server_route_public_port(),
		multiplayer.get_unique_id(),
		MovementMode.get_mode_name(),
		max_clients
	])
	_log_server_route_registration_config("server-start")
	_log_netfox_status("server-started", true)
	_log_netfox_startup_timing_deferred("server-start")
	call_deferred("_register_server_route_with_backend", "server-start")
	if spawn_server_player:
		call_deferred("_spawn_server_player_when_world_ready")
	else:
		print("%s Dedicated server player spawn disabled. Add %s or set %s=1 to spawn Player_1." % [
			LOG_PREFIX,
			SERVER_PLAYER_ARG,
			SERVER_PLAYER_ENV
		])

	if _should_load_server_world_collision_from_backend():
		call_deferred("_load_server_world_collision_from_backend")


func _spawn_server_player_when_world_ready() -> void:
	while is_inside_tree() and mode == "server" and not _is_peer_ready_for_spawn(BODY_AUTHORITY):
		await get_tree().process_frame

	if not is_inside_tree() or mode != "server":
		return
	if spawned_players.has(BODY_AUTHORITY):
		return

	_spawn_player(BODY_AUTHORITY, _get_spawn_position(BODY_AUTHORITY), _get_local_display_name(), _get_local_identity_payload())


func _start_client_after_backend_route_ready() -> void:
	mode = "client"
	while is_inside_tree() and mode == "client" and MovementMode.is_netfox_real():
		var route_ready: bool = await _wait_for_backend_route_before_client_connect()
		if route_ready:
			if mode == "client" and MovementMode.is_netfox_real():
				start_client()
			return

		push_warning("%s Netfox client could not obtain a backend route yet; keeping NETFOX_REAL active and retrying. target=%s:%d route=%s" % [
			LOG_PREFIX,
			host,
			port,
			_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
		])
		await get_tree().create_timer(2.0).timeout


func _wait_for_backend_route_before_client_connect() -> bool:
	if not _should_require_backend_netfox_route():
		if _can_use_direct_netfox_target_without_backend_route():
			print("%s Using configured Netfox target without backend route. target=%s:%d route=%s" % [
				LOG_PREFIX,
				host,
				port,
				_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
			])
		return true

	if _refresh_client_route_from_backend("pre-connect-existing"):
		return true

	var deadline_msec: int = 0
	var last_request_msec: int = 0
	var last_status_msec: int = 0
	var request_sent_once: bool = false

	while is_inside_tree() and mode == "client" and MovementMode.is_netfox_real():
		if _refresh_client_route_from_backend("pre-connect-wait"):
			return true

		var now_msec: int = Time.get_ticks_msec()
		if last_request_msec <= 0 or now_msec - last_request_msec >= SPAWN_TICKET_REQUEST_RETRY_MSEC:
			last_request_msec = now_msec
			var request_sent: bool = _request_backend_spawn_ticket()
			if request_sent and not request_sent_once:
				request_sent_once = true
				deadline_msec = now_msec + int(SPAWN_TICKET_WAIT_TIMEOUT_SECONDS * 1000.0)

		if last_status_msec <= 0 or now_msec - last_status_msec >= NETFOX_STATUS_LOG_INTERVAL_MSEC:
			last_status_msec = now_msec
			print("%s Waiting for backend Netfox route before ENet connect. world=%s ticket_request_sent=%s route=%s" % [
				LOG_PREFIX,
				_get_current_world_id(),
				str(request_sent_once),
				_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
			])

		if request_sent_once and deadline_msec > 0 and now_msec >= deadline_msec:
			return false

		await get_tree().process_frame

	return false


func start_client() -> void:
	mode = "client"
	_reset_client_spawn_request_state("client-start")
	_apply_netfox_tickrate_settings("client-start")
	_apply_netfox_input_routing_settings("client-start")
	if _should_require_backend_netfox_route() and not _refresh_client_route_from_backend("client-create"):
		push_error("%s Refusing ENet client connect without a backend Netfox route; retrying route wait. target=%s:%d route=%s" % [
			LOG_PREFIX,
			host,
			port,
			_get_backend_netfox_spawn_route_debug_text(_get_current_world_id())
		])
		call_deferred("_start_client_after_backend_route_ready")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		push_error("%s Failed to connect ENet client to %s:%d: %s" % [LOG_PREFIX, host, port, error])
		_fallback_to_websocket_movement("client_create_failed")
		return

	multiplayer.multiplayer_peer = peer
	client_connect_deadline_msec = Time.get_ticks_msec() + int(CLIENT_CONNECT_TIMEOUT_SECONDS * 1000.0)
	print("%s ENet client connecting to %s:%d mode=%s." % [
		LOG_PREFIX,
		host,
		port,
		MovementMode.get_mode_name()
	])
	_log_netfox_status("client-connecting", true)


func _on_connected_to_server() -> void:
	client_connect_deadline_msec = 0
	print("%s Client connected as peer %d; waiting for NetworkTime before spawn request." % [LOG_PREFIX, multiplayer.get_unique_id()])
	_log_netfox_status("client-connected", true)
	_request_spawn_when_network_time_ready()


func _on_connection_failed() -> void:
	push_error("%s ENet client connection failed." % LOG_PREFIX)
	_fallback_to_websocket_movement("connection_failed")


func _on_server_disconnected() -> void:
	print("%s ENet server disconnected; clearing Netfox players." % LOG_PREFIX)
	client_connect_deadline_msec = 0
	_reset_client_spawn_request_state("server-disconnected")
	pending_spawn_requests.clear()
	spawning_peer_ids.clear()
	spawn_verification_peer_ids.clear()
	player_visibility_confirmations.clear()
	_fallback_to_websocket_movement("server_disconnected")


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("%s Peer connected: %d. Waiting for spawn request." % [LOG_PREFIX, peer_id])
	_log_netfox_status("peer-connected-" + str(peer_id), true)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawned_players.erase(peer_id)
		player_display_names.erase(peer_id)
		pending_spawn_requests.erase(peer_id)
		player_identity_payloads.erase(peer_id)
		spawning_peer_ids.erase(peer_id)
		spawn_verification_peer_ids.erase(peer_id)
		_clear_player_visibility_confirmation(peer_id)
		despawn_player.rpc(peer_id)
	_despawn_player(peer_id)


func _watch_netfox_connection_status() -> void:
	if mode != "client" and mode != "server":
		return

	if mode == "client" and client_connect_deadline_msec > 0:
		var now_msec: int = Time.get_ticks_msec()
		if now_msec >= client_connect_deadline_msec and not _is_multiplayer_connected():
			client_connect_deadline_msec = 0
			push_error("%s ENet client connection timed out after %.1fs." % [LOG_PREFIX, CLIENT_CONNECT_TIMEOUT_SECONDS])
			_log_netfox_status("client-connect-timeout", true)
			_fallback_to_websocket_movement("connection_timeout")
			return

	_watch_client_spawn_ack()
	_watch_server_pending_spawns()
	if debug_enabled:
		_log_netfox_status("poll", false)


func _watch_client_spawn_ack() -> void:
	if mode != "client" or not spawn_request_sent:
		return
	if not _is_multiplayer_connected():
		spawn_ack_deadline_msec = 0
		return

	var local_player = world.get("player") if world != null else null
	if local_player != null and is_instance_valid(local_player):
		spawn_ack_deadline_msec = 0
		return

	var now_msec: int = Time.get_ticks_msec()
	if spawn_ack_deadline_msec <= 0:
		spawn_ack_deadline_msec = now_msec + int(SPAWN_ACK_TIMEOUT_SECONDS * 1000.0)
		return
	if now_msec < spawn_ack_deadline_msec:
		return

	print("%s NETFOX_SPAWN_WAIT_TIMEOUT peer=%d waited=%.1fs connection=%s network_time_synced=%s world_ready=%s blocks=%d hint=check_server_output_for_spawn_request_or_queued_spawn" % [
		LOG_PREFIX,
		_get_local_peer_id(),
		SPAWN_ACK_TIMEOUT_SECONDS,
		_get_connection_status_text(_get_multiplayer_connection_status()),
		str(NetworkTime.is_initial_sync_done()),
		str(_is_world_collision_ready()),
		_get_world_block_count()
	])
	_log_netfox_status("spawn-wait-timeout", true)
	_reset_client_spawn_request_state("spawn-wait-timeout")
	call_deferred("_request_spawn_when_network_time_ready")


func _watch_server_pending_spawns() -> void:
	if mode != "server" or pending_spawn_requests.is_empty():
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - last_pending_spawn_status_log_msec < NETFOX_STATUS_LOG_INTERVAL_MSEC:
		return

	last_pending_spawn_status_log_msec = now_msec
	var pending_peer_text: Array[String] = []
	for peer_id in pending_spawn_requests.keys():
		var queued_peer_id := int(peer_id)
		pending_peer_text.append("%d:synced=%s" % [
			queued_peer_id,
			str(NetworkTime.is_client_synced(queued_peer_id))
		])

	print("%s NETFOX_PENDING_SPAWNS count=%d peers=%s server_network_time_synced=%s world_ready=%s blocks=%d collision_blocks=%d" % [
		LOG_PREFIX,
		pending_spawn_requests.size(),
		",".join(pending_peer_text),
		str(NetworkTime.is_initial_sync_done()),
		str(_is_world_collision_ready()),
		_get_world_block_count(),
		_get_world_collision_block_count()
	])


func _log_netfox_status(reason: String = "status", force: bool = false) -> void:
	if not MovementMode.is_netfox_real():
		return
	if not force and not debug_enabled:
		return

	var now_msec: int = Time.get_ticks_msec()
	var local_peer_id: int = _get_local_peer_id()
	var connection_status: int = _get_multiplayer_connection_status()
	var status_text: String = _get_connection_status_text(connection_status)
	var spawned_count: int = spawned_players.size()
	var pending_count: int = pending_spawn_requests.size()
	var local_player = world.get("player") if world != null else null
	var has_local_player: bool = local_player != null and is_instance_valid(local_player)
	var world_ready: bool = _is_world_collision_ready()
	var route_text: String = _get_backend_netfox_spawn_route_debug_text(_get_current_world_id()) if mode == "client" else ""
	var status_key: String = "%s|%s|%d|%d|%d|%s|%s|%s|%s|%d" % [
		mode,
		status_text,
		local_peer_id,
		spawned_count,
		pending_count,
		str(has_local_player),
		str(world_ready),
		str(spawn_request_sent),
		host,
		port
	]
	if not force and status_key == last_netfox_status_key and now_msec - last_netfox_status_log_msec < NETFOX_STATUS_LOG_INTERVAL_MSEC:
		return

	last_netfox_status_key = status_key
	last_netfox_status_log_msec = now_msec
	print("%s NETFOX_STATUS reason=%s mode=%s role=%s connection=%s peer=%d spawned=%d pending_spawns=%d local_player=%s spawn_request_sent=%s world_ready=%s target=%s:%d route=%s websocket_movement_disabled=%s" % [
		LOG_PREFIX,
		reason,
		MovementMode.get_mode_name(),
		mode,
		status_text,
		local_peer_id,
		spawned_count,
		pending_count,
		str(has_local_player),
		str(spawn_request_sent),
		str(world_ready),
		host,
		port,
		route_text,
		str(not MovementMode.is_websocket())
	])


func _get_multiplayer_connection_status() -> int:
	var api := get_multiplayer()
	if api == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	var peer := api.multiplayer_peer
	if peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return peer.get_connection_status()


func _get_connection_status_text(status: int) -> String:
	match status:
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "connected"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "connecting"
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "disconnected"
		_:
			return "unknown"


func _get_spawn_rejection_message(reason: String, server_world: String = "", requested_world: String = "") -> String:
	var clean_reason: String = reason.strip_edges()
	var clean_server_world: String = server_world.strip_edges().to_upper()
	var clean_requested_world: String = requested_world.strip_edges().to_upper()
	match clean_reason:
		"world_mismatch":
			return "Netfox server is hosting %s, but this client requested %s." % [
				clean_server_world if clean_server_world != "" else "another world",
				clean_requested_world if clean_requested_world != "" else "an unknown world"
			]
		"server_world_load_failed":
			return "Netfox server failed to load world %s from backend." % [
				clean_server_world if clean_server_world != "" else clean_requested_world
			]
		"server_world_not_ready":
			return "Netfox server is still loading world %s." % [
				clean_server_world if clean_server_world != "" else clean_requested_world
			]
		"spawn_ticket_missing":
			return "Netfox spawn ticket is missing. Rejoin the world or request a fresh ticket."
		"spawn_ticket_expired":
			return "Netfox spawn ticket expired. Rejoin the world to request a fresh ticket."
		"spawn_ticket_verify_failed":
			return "Netfox server could not verify your spawn ticket with the backend."
		"spawn_ticket_invalid", "spawn_ticket_bad_signature", "spawn_ticket_malformed":
			return "Netfox spawn ticket was rejected by the backend."
		_:
			return "Netfox server rejected player spawn: " + clean_reason


func _request_spawn_when_network_time_ready() -> void:
	if spawn_request_sent or spawn_request_in_progress:
		return
	spawn_request_in_progress = true
	var request_generation := spawn_request_generation

	if not NetworkTime.is_initial_sync_done():
		print("%s Waiting for NetworkTime.after_sync before sending spawn request. peer=%d tick=%d" % [
			LOG_PREFIX,
			multiplayer.get_unique_id(),
			NetworkTime.tick
		])
		await NetworkTime.after_sync

	if not _is_spawn_request_generation_current(request_generation):
		_finish_spawn_request_task(request_generation)
		return
	if spawn_request_sent:
		_finish_spawn_request_task(request_generation)
		return
	if not _is_multiplayer_connected():
		_finish_spawn_request_task(request_generation)
		return
	if not _is_backend_identity_ready_for_spawn():
		print("%s Waiting for authenticated backend identity before Netfox spawn. peer=%d" % [
			LOG_PREFIX,
			multiplayer.get_unique_id()
		])
		await _wait_for_backend_identity_ready()

	if not _is_spawn_request_generation_current(request_generation):
		_finish_spawn_request_task(request_generation)
		return
	if spawn_request_sent:
		_finish_spawn_request_task(request_generation)
		return
	if not _is_multiplayer_connected():
		_finish_spawn_request_task(request_generation)
		return
	if not _is_backend_spawn_ticket_ready_for_spawn():
		print("%s Waiting for backend Netfox spawn ticket before spawn request. peer=%d world=%s" % [
			LOG_PREFIX,
			multiplayer.get_unique_id(),
			_get_current_world_id()
		])
		await _wait_for_backend_spawn_ticket_ready()

	if not _is_spawn_request_generation_current(request_generation):
		_finish_spawn_request_task(request_generation)
		return
	if spawn_request_sent:
		_finish_spawn_request_task(request_generation)
		return
	if not _is_multiplayer_connected():
		_finish_spawn_request_task(request_generation)
		return
	if not _is_world_collision_ready():
		print("%s Waiting for local world collision readiness before Netfox spawn request. peer=%d blocks=%d entry_in_progress=%s" % [
			LOG_PREFIX,
			multiplayer.get_unique_id(),
			_get_world_block_count(),
			str(world.get_meta("world_entry_in_progress", false) if world != null else false)
		])
		await _wait_for_local_world_collision_ready_for_spawn()

	if not _is_spawn_request_generation_current(request_generation):
		_finish_spawn_request_task(request_generation)
		return
	if spawn_request_sent:
		_finish_spawn_request_task(request_generation)
		return
	if not _is_multiplayer_connected():
		_finish_spawn_request_task(request_generation)
		return

	spawn_request_sent = true
	_finish_spawn_request_task(request_generation)
	_log_netfox_startup_timing("client-after-sync")
	print("%s NetworkTime synced; requesting Netfox player spawn. peer=%d tick=%d" % [
		LOG_PREFIX,
		multiplayer.get_unique_id(),
		NetworkTime.tick
	])
	spawn_ack_deadline_msec = Time.get_ticks_msec() + int(SPAWN_ACK_TIMEOUT_SECONDS * 1000.0)
	_log_netfox_status("spawn-request-sent", true)
	request_spawn.rpc_id(BODY_AUTHORITY, _get_local_identity_payload())


func _is_spawn_request_generation_current(request_generation: int) -> bool:
	return request_generation == spawn_request_generation


func _finish_spawn_request_task(request_generation: int) -> void:
	if request_generation == spawn_request_generation:
		spawn_request_in_progress = false


func _is_backend_identity_ready_for_spawn() -> bool:
	if not _should_wait_for_backend_identity():
		return true

	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	if not network.has_method("is_server_session_authenticated") or not bool(network.is_server_session_authenticated()):
		return false
	if network.has_method("get_active_session_username") and str(network.get_active_session_username()).strip_edges() == "":
		return false

	return true


func _should_wait_for_backend_identity() -> bool:
	if mode != "client":
		return false
	if MovementMode.has_method("is_dev_test_login_active") and MovementMode.is_dev_test_login_active():
		return false
	if MovementMode.has_method("should_run_websocket_backend"):
		return bool(MovementMode.should_run_websocket_backend())
	return false


func _should_wait_for_backend_spawn_ticket() -> bool:
	return _should_require_backend_netfox_route()


func _is_backend_spawn_ticket_ready_for_spawn() -> bool:
	if not _should_wait_for_backend_spawn_ticket():
		return true

	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("has_netfox_spawn_ticket_for_world"):
		return false
	return bool(network.has_netfox_spawn_ticket_for_world(_get_current_world_id()))


func _request_backend_spawn_ticket() -> bool:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_netfox_spawn_ticket_request"):
		return false
	return bool(network.send_netfox_spawn_ticket_request(_get_current_world_id()))


func _wait_for_backend_identity_ready() -> void:
	while is_inside_tree() and _is_multiplayer_connected() and not _is_backend_identity_ready_for_spawn():
		await get_tree().process_frame


func _wait_for_backend_spawn_ticket_ready() -> void:
	if not _should_wait_for_backend_spawn_ticket():
		return

	var deadline_msec: int = Time.get_ticks_msec() + int(SPAWN_TICKET_WAIT_TIMEOUT_SECONDS * 1000.0)
	var last_request_msec := 0
	while is_inside_tree() and _is_multiplayer_connected() and not _is_backend_spawn_ticket_ready_for_spawn():
		var now_msec: int = Time.get_ticks_msec()
		if last_request_msec <= 0 or now_msec - last_request_msec >= SPAWN_TICKET_REQUEST_RETRY_MSEC:
			last_request_msec = now_msec
			_request_backend_spawn_ticket()
		if now_msec >= deadline_msec:
			push_warning("%s Timed out waiting for backend Netfox spawn ticket. peer=%d world=%s" % [
				LOG_PREFIX,
				multiplayer.get_unique_id(),
				_get_current_world_id()
			])
			return
		await get_tree().process_frame


func _wait_for_local_world_collision_ready_for_spawn() -> void:
	while is_inside_tree() and _is_multiplayer_connected() and not _is_world_collision_ready():
		await get_tree().process_frame


func _on_network_time_client_synced(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not pending_spawn_requests.has(peer_id):
		return

	var identity_payload := _sanitize_identity_payload(pending_spawn_requests.get(peer_id, {}), peer_id)
	var acceptance: Dictionary = _get_spawn_acceptance(peer_id, identity_payload)
	if not bool(acceptance.get("accepted", false)):
		if bool(acceptance.get("queue", false)):
			return
		pending_spawn_requests.erase(peer_id)
		_reject_spawn_request(peer_id, acceptance)
		return
	if not _is_peer_ready_for_spawn(peer_id):
		return

	pending_spawn_requests.erase(peer_id)
	print("%s NetworkTime synced for peer %d; processing queued spawn request." % [LOG_PREFIX, peer_id])
	_handle_spawn_request(peer_id, identity_payload)


func _get_spawn_acceptance(_peer_id: int, identity_payload: Dictionary) -> Dictionary:
	var server_world: String = _get_server_authoritative_world_id()
	var requested_world: String = _get_identity_world_id(identity_payload)
	if requested_world == "" and server_world != "":
		requested_world = server_world
		identity_payload["world_id"] = server_world
		identity_payload["world"] = server_world

	if server_world_load_failed:
		return {
			"accepted": false,
			"queue": false,
			"reason": "server_world_load_failed",
			"server_world": server_world,
			"requested_world": requested_world
		}

	if server_world != "" and requested_world != "" and requested_world != server_world:
		return {
			"accepted": false,
			"queue": false,
			"reason": "world_mismatch",
			"server_world": server_world,
			"requested_world": requested_world
		}

	if not _is_server_world_authoritative_ready():
		return {
			"accepted": false,
			"queue": true,
			"reason": "server_world_not_ready",
			"server_world": server_world,
			"requested_world": requested_world
		}

	if _requires_backend_spawn_ticket_verification() and not bool(identity_payload.get("netfox_spawn_ticket_verified", false)) and str(identity_payload.get("netfox_spawn_ticket", "")).strip_edges() == "":
		return {
			"accepted": false,
			"queue": false,
			"reason": "spawn_ticket_missing",
			"server_world": server_world,
			"requested_world": requested_world
		}

	return {
		"accepted": true,
		"queue": false,
		"reason": "",
		"server_world": server_world,
		"requested_world": requested_world
	}


func _queue_spawn_request(requester_id: int, identity_payload: Dictionary, reason: String) -> void:
	pending_spawn_requests[requester_id] = identity_payload
	print("%s Queued spawn request from peer %d. reason=%s tick=%d synced=%s server_ready=%s world_ready=%s blocks=%d collision_blocks=%d server_world=%s requested_world=%s" % [
		LOG_PREFIX,
		requester_id,
		reason,
		NetworkTime.tick,
		str(NetworkTime.is_client_synced(requester_id)),
		str(_is_server_world_authoritative_ready()),
		str(_is_world_collision_ready()),
		_get_world_block_count(),
		_get_world_collision_block_count(),
		_get_server_authoritative_world_id(),
		_get_identity_world_id(identity_payload)
	])


func _reject_spawn_request(peer_id: int, acceptance: Dictionary) -> void:
	pending_spawn_requests.erase(peer_id)
	spawning_peer_ids.erase(peer_id)
	spawn_verification_peer_ids.erase(peer_id)
	player_display_names.erase(peer_id)
	player_identity_payloads.erase(peer_id)
	_clear_player_visibility_confirmation(peer_id)
	var reason: String = str(acceptance.get("reason", "unknown"))
	var server_world: String = str(acceptance.get("server_world", "")).strip_edges().to_upper()
	var requested_world: String = str(acceptance.get("requested_world", "")).strip_edges().to_upper()
	print("%s Rejected spawn request from peer %d. reason=%s server_world=%s requested_world=%s server_ready=%s load_started=%s load_complete=%s load_failed=%s blocks=%d collision_blocks=%d" % [
		LOG_PREFIX,
		peer_id,
		reason,
		server_world,
		requested_world,
		str(_is_server_world_authoritative_ready()),
		str(server_world_load_started),
		str(server_world_load_complete),
		str(server_world_load_failed),
		_get_world_block_count(),
		_get_world_collision_block_count()
	])
	if peer_id > BODY_AUTHORITY:
		spawn_rejected.rpc_id(peer_id, reason, server_world, requested_world)


@rpc("any_peer", "call_remote", "reliable")
func request_spawn(identity_payload = {}) -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	if requester_id <= BODY_AUTHORITY:
		return

	var clean_identity := _sanitize_identity_payload(identity_payload, requester_id)
	var clean_display_name := _get_identity_display_name(clean_identity, requester_id)
	player_display_names[requester_id] = clean_display_name
	var acceptance: Dictionary = _get_spawn_acceptance(requester_id, clean_identity)
	if not bool(acceptance.get("accepted", false)):
		if bool(acceptance.get("queue", false)):
			_queue_spawn_request(requester_id, clean_identity, str(acceptance.get("reason", "server_world_not_ready")))
		else:
			_reject_spawn_request(requester_id, acceptance)
		return
	if not _is_peer_ready_for_spawn(requester_id):
		_queue_spawn_request(requester_id, clean_identity, "network_time_or_collision_not_ready")
		return

	_handle_spawn_request(requester_id, clean_identity)


@rpc("any_peer", "call_remote", "reliable")
func request_leave_world(world_name: String = "", reason: String = "client-world-leave") -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	if requester_id <= BODY_AUTHORITY:
		return

	pending_spawn_requests.erase(requester_id)
	spawning_peer_ids.erase(requester_id)
	spawn_verification_peer_ids.erase(requester_id)
	_clear_player_visibility_confirmation(requester_id)

	var player_name := "Player_%d" % requester_id
	var had_player := spawned_players.has(requester_id)
	if players_root != null and players_root.get_node_or_null(player_name) != null:
		had_player = true

	if had_player:
		despawn_player.rpc(requester_id)
		_despawn_player(requester_id)

	print("%s Server accepted Netfox world leave peer=%d world=%s reason=%s had_player=%s" % [
		LOG_PREFIX,
		requester_id,
		world_name.strip_edges().to_upper(),
		reason,
		str(had_player)
	])


func _handle_spawn_request(requester_id: int, identity_payload = {}) -> void:
	if not multiplayer.is_server():
		return
	if requester_id <= BODY_AUTHORITY:
		return

	var clean_identity := _sanitize_identity_payload(identity_payload, requester_id)
	var acceptance: Dictionary = _get_spawn_acceptance(requester_id, clean_identity)
	if not bool(acceptance.get("accepted", false)):
		if bool(acceptance.get("queue", false)):
			_queue_spawn_request(requester_id, clean_identity, str(acceptance.get("reason", "server_world_not_ready")))
		else:
			_reject_spawn_request(requester_id, acceptance)
		return
	if _requires_backend_spawn_ticket_verification() and not bool(clean_identity.get("netfox_spawn_ticket_verified", false)):
		if spawn_verification_peer_ids.has(requester_id):
			return
		spawn_verification_peer_ids[requester_id] = true
		var verification: Dictionary = await _verify_spawn_ticket_with_backend(requester_id, clean_identity)
		spawn_verification_peer_ids.erase(requester_id)
		if not bool(verification.get("ok", false)):
			acceptance["accepted"] = false
			acceptance["queue"] = false
			acceptance["reason"] = str(verification.get("reason", "spawn_ticket_invalid"))
			acceptance["message"] = str(verification.get("message", ""))
			_reject_spawn_request(requester_id, acceptance)
			return

		var verified_identity_value: Variant = verification.get("identity", clean_identity)
		if verified_identity_value is Dictionary:
			clean_identity = _sanitize_identity_payload(verified_identity_value, requester_id)
			clean_identity["netfox_spawn_ticket_verified"] = true
			acceptance = _get_spawn_acceptance(requester_id, clean_identity)
			if not bool(acceptance.get("accepted", false)):
				if bool(acceptance.get("queue", false)):
					_queue_spawn_request(requester_id, clean_identity, str(acceptance.get("reason", "server_world_not_ready")))
				else:
					_reject_spawn_request(requester_id, acceptance)
				return
	clean_identity.erase("netfox_spawn_ticket")
	clean_identity.erase("netfox_ticket_expires_at_ms")
	if spawning_peer_ids.has(requester_id):
		return

	spawning_peer_ids[requester_id] = true
	var display_name := _get_identity_display_name(clean_identity, requester_id)
	player_display_names[requester_id] = display_name
	player_identity_payloads[requester_id] = clean_identity
	print("%s Server received spawn request from peer %d username=%s websocket_player_id=%s game_player_id=%s world_id=%s." % [
		LOG_PREFIX,
		requester_id,
		str(clean_identity.get("username", "")),
		str(clean_identity.get("websocket_player_id", "")),
		str(clean_identity.get("game_player_id", "")),
		str(clean_identity.get("world_id", ""))
	])
	_sync_spawned_player_positions_from_scene()
	var existing_replay_peer_ids: Array[int] = []
	for existing_peer_id in spawned_players.keys():
		var existing_id := int(existing_peer_id)
		existing_replay_peer_ids.append(existing_id)
		_send_existing_player_spawn_to_peer(requester_id, existing_id)

	if not spawned_players.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		_sync_spawned_player_positions_from_scene()
		for existing_id in existing_replay_peer_ids:
			_send_existing_player_spawn_to_peer(requester_id, existing_id)

	if spawned_players.has(requester_id):
		_send_player_spawn_snapshot_to_peer(requester_id, requester_id, "existing-self-spawn")
		spawning_peer_ids.erase(requester_id)
		return

	var spawn_position := _get_spawn_position(requester_id)
	_refresh_world_collision_streaming_for_positions([spawn_position], "pre-spawn-%d" % requester_id)
	_spawn_player(requester_id, spawn_position, display_name, clean_identity)
	await get_tree().process_frame
	_send_player_spawn_to_observers(requester_id, spawn_position, display_name, clean_identity)
	spawning_peer_ids.erase(requester_id)


func _is_peer_ready_for_spawn(peer_id: int) -> bool:
	if mode == "server" and not _is_server_world_authoritative_ready():
		return false
	if not _is_world_collision_ready():
		return false
	if not _has_valid_entrance_spawn_position():
		return false
	if mode == "standalone":
		return true
	if peer_id <= BODY_AUTHORITY:
		return NetworkTime.is_initial_sync_done()
	return NetworkTime.is_initial_sync_done() and NetworkTime.is_client_synced(peer_id)


func _process_pending_spawn_requests() -> void:
	if not multiplayer.is_server() or pending_spawn_requests.is_empty():
		return

	var ready_peer_ids: Array = []
	var rejected_peer_ids: Array = []
	for peer_id in pending_spawn_requests.keys():
		var queued_peer_id := int(peer_id)
		var identity_payload := _sanitize_identity_payload(pending_spawn_requests.get(queued_peer_id, {}), queued_peer_id)
		var acceptance: Dictionary = _get_spawn_acceptance(queued_peer_id, identity_payload)
		if not bool(acceptance.get("accepted", false)):
			if bool(acceptance.get("queue", false)):
				continue
			rejected_peer_ids.append([queued_peer_id, acceptance])
			continue
		if not _is_peer_ready_for_spawn(queued_peer_id):
			continue

		ready_peer_ids.append(queued_peer_id)

	for rejected_entry in rejected_peer_ids:
		if not (rejected_entry is Array) or rejected_entry.size() < 2:
			continue
		var rejected_acceptance: Dictionary = rejected_entry[1]
		_reject_spawn_request(int(rejected_entry[0]), rejected_acceptance)

	if ready_peer_ids.is_empty():
		return

	print("%s Releasing %d queued spawn request(s)." % [LOG_PREFIX, ready_peer_ids.size()])
	for queued_peer_id in ready_peer_ids:
		var identity_payload := _sanitize_identity_payload(pending_spawn_requests.get(queued_peer_id, {}), queued_peer_id)
		pending_spawn_requests.erase(queued_peer_id)
		print("%s Processing queued spawn for peer %d after world collision became ready." % [LOG_PREFIX, queued_peer_id])
		_handle_spawn_request(queued_peer_id, identity_payload)


func _is_world_collision_ready() -> bool:
	if not _has_world_collision_data():
		_clear_world_collision_ready_cache()
		return false

	if bool(world.get_meta("world_entry_in_progress", false)):
		_clear_world_collision_ready_cache()
		return false

	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		_clear_world_collision_ready_cache()
		return false

	var applying_update = world.get("applying_network_world_update")
	if applying_update != null and bool(applying_update):
		_clear_world_collision_ready_cache()
		return false

	var save_manager = world.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager and bool(save_manager.get("waiting_for_server_world_state")):
		_clear_world_collision_ready_cache()
		return false

	var cache_key := _get_world_collision_ready_cache_key()
	if _is_cached_world_collision_ready(cache_key):
		if _is_tilemap_collision_stream_ready():
			return true
		_clear_world_collision_ready_cache()

	if not _is_tilemap_collision_stream_ready():
		_refresh_world_collision_streaming_for_positions(_get_world_collision_focus_positions(), "collision-readiness")
		if not _is_tilemap_collision_stream_ready():
			return false

	_mark_world_collision_stream_ready(cache_key)
	return true


func _get_world_collision_ready_cache_key() -> String:
	if world == null:
		return ""
	return "%s:%d:%d:%d" % [
		_get_current_world_id(),
		world.get_instance_id(),
		_get_world_collision_revision(),
		_get_world_block_count()
	]


func _is_cached_world_collision_ready(cache_key: String) -> bool:
	if cache_key == "":
		return false
	if world_collision_ready_cached and world_collision_ready_cache_key == cache_key:
		return true
	if world == null:
		return false
	if not bool(world.get_meta(WORLD_COLLISION_READY_META, false)):
		return false
	if str(world.get_meta(WORLD_COLLISION_READY_CACHE_KEY_META, "")) != cache_key:
		return false

	world_collision_ready_cached = true
	world_collision_ready_cache_key = cache_key
	return true


func _mark_world_collision_stream_ready(cache_key: String) -> void:
	world_collision_ready_cached = cache_key != ""
	world_collision_ready_cache_key = cache_key
	if world == null or cache_key == "":
		return
	world.set_meta(WORLD_COLLISION_READY_META, true)
	world.set_meta(WORLD_COLLISION_READY_CACHE_KEY_META, cache_key)


func _clear_world_collision_ready_cache() -> void:
	world_collision_ready_cached = false
	world_collision_ready_cache_key = ""
	if world == null:
		return
	if world.has_meta(WORLD_COLLISION_READY_META):
		world.remove_meta(WORLD_COLLISION_READY_META)
	if world.has_meta(WORLD_COLLISION_READY_CACHE_KEY_META):
		world.remove_meta(WORLD_COLLISION_READY_CACHE_KEY_META)


func _has_world_collision_data() -> bool:
	if world == null:
		return false

	var in_world_value = world.get("in_world")
	if in_world_value != null and not bool(in_world_value):
		return false

	var block_manager = world.get("block_manager")
	if block_manager == null:
		return false

	var blocks_value = world.get("blocks")
	if blocks_value is Dictionary and blocks_value.size() <= 0:
		return false

	return true


func _get_world_block_count() -> int:
	if world == null:
		return 0

	var blocks_value = world.get("blocks")
	if blocks_value is Dictionary:
		return blocks_value.size()

	return 0


func _get_world_collision_block_count() -> int:
	if world == null:
		return 0

	var blocks_value = world.get("blocks")
	if not (blocks_value is Dictionary):
		return 0

	var collision_count := 0
	for grid_pos in blocks_value.keys():
		var block_data = blocks_value.get(grid_pos, {})
		var block_type := ""
		if block_data is Dictionary:
			block_type = str(block_data.get("type", ""))
		if block_type == "":
			continue
		if not _is_collision_block_type(block_type):
			continue
		collision_count += 1

	return collision_count


func _is_tilemap_collision_stream_ready() -> bool:
	if world == null:
		return false

	var block_manager = world.get("block_manager")
	if block_manager == null:
		return false
	if block_manager.has_method("is_foreground_tilemap_collision_enabled") and not bool(block_manager.is_foreground_tilemap_collision_enabled()):
		return true

	var renderer = _get_world_tilemap_renderer()
	if renderer == null:
		return true
	if not renderer.has_method("get_streaming_summary"):
		return true

	var summary: Dictionary = renderer.get_streaming_summary()
	var cached_by_layer: Dictionary = summary.get("cached_by_layer", {})
	var active_by_layer: Dictionary = summary.get("active_by_layer", {})
	var cached_collision := int(cached_by_layer.get("foreground_collision", 0))
	if renderer.has_method("is_foreground_collision_stream_ready_for_world_positions"):
		return bool(renderer.call("is_foreground_collision_stream_ready_for_world_positions", _get_world_collision_focus_positions()))
	var active_collision := int(active_by_layer.get("foreground_collision", 0))
	if active_collision > 0:
		return true
	if cached_collision > 0:
		return false

	var collision_summary: Dictionary = {}
	if block_manager.has_method("get_foreground_collision_optimization_summary"):
		collision_summary = block_manager.get_foreground_collision_optimization_summary()
		var ready_candidates := int(collision_summary.get("ready", 0))
		if ready_candidates <= 0:
			return true

	if cached_collision <= 0:
		if not collision_summary.is_empty() and int(collision_summary.get("ready", 0)) > 0:
			return false
		return true

	return active_collision > 0


func _get_world_tilemap_renderer():
	if world == null:
		return null

	var block_manager = world.get("block_manager")
	if block_manager == null:
		return null

	if block_manager.has_method("ensure_tilemap_renderer"):
		return block_manager.ensure_tilemap_renderer()
	return block_manager.get("tilemap_renderer")


func _get_world_collision_focus_positions() -> Array:
	var positions: Array = []
	if world == null:
		return positions

	var local_player = world.get("player")
	if local_player is Node2D and is_instance_valid(local_player):
		positions.append((local_player as Node2D).global_position)

	if positions.is_empty():
		var spawn_position := _get_spawn_position(_get_local_peer_id())
		if is_finite(spawn_position.x) and is_finite(spawn_position.y):
			positions.append(spawn_position)

	return positions


func _refresh_world_collision_streaming_for_positions(world_positions: Array, reason: String) -> void:
	if world == null:
		return

	var renderer = _get_world_tilemap_renderer()
	if renderer == null:
		return

	if reason == "collision-readiness":
		var now_msec := Time.get_ticks_msec()
		if now_msec - last_collision_stream_refresh_msec < COLLISION_READY_REFRESH_MIN_INTERVAL_MSEC:
			return
		last_collision_stream_refresh_msec = now_msec

	if renderer.has_method("refresh_streaming_for_world_positions"):
		renderer.call("refresh_streaming_for_world_positions", world_positions)
	elif renderer.has_method("refresh_streaming_now"):
		renderer.call("refresh_streaming_now")

	if debug_enabled and renderer.has_method("get_streaming_summary"):
		var summary: Dictionary = renderer.get_streaming_summary()
		var active_by_layer: Dictionary = summary.get("active_by_layer", {})
		print("%s Refreshed world collision streaming reason=%s positions=%s active_collision_cells=%d active_chunks=%d cached_collision_cells=%d" % [
			LOG_PREFIX,
			reason,
			str(world_positions),
			int(active_by_layer.get("foreground_collision", 0)),
			int(summary.get("active_chunks", 0)),
			int((summary.get("cached_by_layer", {}) as Dictionary).get("foreground_collision", 0)) if summary.get("cached_by_layer", {}) is Dictionary else 0
		])


func _log_world_collision_fingerprint_once(reason: String) -> void:
	if world_collision_fingerprint_logged:
		return
	if not (debug_enabled or collision_debug_enabled):
		return
	if not _is_world_collision_ready():
		return

	world_collision_fingerprint_logged = true
	_log_world_collision_fingerprint(reason, true)


func notify_world_collision_changed(reason: String = "block-update") -> void:
	_clear_world_collision_ready_cache()
	if not (debug_enabled or collision_debug_enabled):
		return
	_log_world_collision_fingerprint(reason, false)


func _log_world_collision_fingerprint(reason: String, force: bool = false) -> void:
	if not (debug_enabled or collision_debug_enabled):
		return
	if not _is_world_collision_ready():
		return

	var fingerprint := _get_world_collision_fingerprint()
	var fingerprint_text := "%s:%d:%d:%d:%s:%d" % [
		str(fingerprint.get("world_id", "")),
		int(fingerprint.get("block_count", 0)),
		int(fingerprint.get("background_block_count", 0)),
		int(fingerprint.get("collision_block_count", 0)),
		str(fingerprint.get("collision_hash", "")),
		int(fingerprint.get("revision", 0))
	]
	if not force and fingerprint_text == last_world_collision_fingerprint_text:
		return
	if not force:
		var now_msec := Time.get_ticks_msec()
		if now_msec - last_world_collision_fingerprint_log_msec < WORLD_COLLISION_FINGERPRINT_MIN_INTERVAL_MSEC:
			return

	last_world_collision_fingerprint_text = fingerprint_text
	last_world_collision_fingerprint_log_msec = Time.get_ticks_msec()
	print("%s world collision fingerprint reason=%s role=%s peer=%d world=%s blocks=%d background_blocks=%d collision_blocks=%d chunks=%d revision=%d collision_hash=%s tile_size=%.2f world_origin=%s chunk_origin=%s network_tick_rate=%d physics_tick_rate=%d" % [
		LOG_PREFIX,
		reason,
		"server" if multiplayer.is_server() else mode,
		_get_local_peer_id(),
		str(fingerprint.get("world_id", "")),
		int(fingerprint.get("block_count", 0)),
		int(fingerprint.get("background_block_count", 0)),
		int(fingerprint.get("collision_block_count", 0)),
		int(fingerprint.get("chunk_count", 0)),
		int(fingerprint.get("revision", 0)),
		str(fingerprint.get("collision_hash", "")),
		float(fingerprint.get("tile_size", 0.0)),
		str(fingerprint.get("world_origin", "n/a")),
		str(fingerprint.get("chunk_origin", "n/a")),
		NetworkTime.tickrate,
		Engine.physics_ticks_per_second
	])
	_audit_collision_nodes(reason, force)


func _get_world_collision_fingerprint() -> Dictionary:
	var result := {
		"world_id": _get_current_world_id(),
		"block_count": 0,
		"background_block_count": 0,
		"collision_block_count": 0,
		"chunk_count": _get_world_chunk_count(),
		"revision": _get_world_collision_revision(),
		"collision_hash": "0",
		"tile_size": _get_world_block_size(),
		"world_origin": _get_world_origin_text(),
		"chunk_origin": _get_chunk_origin_text()
	}
	if world == null:
		return result

	var blocks_value = world.get("blocks")
	if not (blocks_value is Dictionary):
		return result

	var collision_entries: Array[String] = []
	result["block_count"] = blocks_value.size()
	for grid_pos in blocks_value.keys():
		var block_type := _get_block_type_from_data(blocks_value.get(grid_pos, {}))
		if block_type == "":
			continue
		if not _is_collision_block_type(block_type):
			continue

		collision_entries.append("%s:%s" % [_grid_key_to_text(grid_pos), block_type])

	collision_entries.sort()
	result["collision_block_count"] = collision_entries.size()
	result["collision_hash"] = _hash_string_entries(collision_entries)

	var block_manager = world.get("block_manager")
	if block_manager != null:
		var background_blocks = block_manager.get("background_blocks")
		if background_blocks is Dictionary:
			result["background_block_count"] = background_blocks.size()

	return result


func _get_world_chunk_count() -> int:
	if world == null:
		return 0

	var chunk_manager = world.get("chunk_manager")
	if chunk_manager != null:
		var chunks = chunk_manager.get("chunks")
		if chunks is Dictionary:
			return chunks.size()

	var raw_chunks = world.get("chunks")
	if raw_chunks is Dictionary:
		return raw_chunks.size()

	return 0


func _get_world_collision_revision() -> int:
	if world == null:
		return 0

	var world_state_sync_manager = world.get("world_state_sync_manager")
	if world_state_sync_manager != null:
		var raw_generation = world_state_sync_manager.get("world_state_apply_generation")
		if raw_generation != null:
			return int(raw_generation)

	return 0


func _get_current_world_id() -> String:
	var launch_world := _get_launch_world_id()
	if world == null:
		return launch_world

	var raw_world = world.get("current_world_name")
	if raw_world == null:
		raw_world = world.get("world_id")
	var current_world := str(raw_world).strip_edges().to_upper()
	if launch_world != "" and (current_world == "" or current_world == "START"):
		return launch_world
	return current_world


func _get_server_authoritative_world_id() -> String:
	var launch_world: String = _get_launch_world_id()
	if launch_world != "":
		return launch_world
	var current_world: String = _get_current_world_id()
	if current_world != "":
		return current_world
	return "START"


func _get_identity_world_id(identity_payload: Dictionary) -> String:
	var world_id: String = str(identity_payload.get("world_id", identity_payload.get("world", ""))).strip_edges().to_upper()
	if world_id != "":
		return world_id
	return _get_server_authoritative_world_id() if mode == "server" else _get_current_world_id()


func _is_server_world_authoritative_ready() -> bool:
	if mode != "server":
		return true
	if server_world_load_failed:
		return false
	if _should_load_server_world_collision_from_backend() and not server_world_load_complete:
		return false
	return _is_world_collision_ready()


func _get_launch_world_id() -> String:
	if not MovementMode.has_launch_arg("--world"):
		return ""
	return MovementMode.get_dev_test_world_name("NETFOX_TEST").strip_edges().to_upper()


func _get_block_type_from_data(block_data) -> String:
	if block_data is Dictionary:
		return str(block_data.get("type", "")).strip_edges()
	return str(block_data).strip_edges()


func _is_collision_block_type(block_type: String) -> bool:
	var clean_type := block_type.strip_edges()
	if clean_type == "":
		return false

	var block_manager = world.get("block_manager") if world != null else null
	if block_manager != null:
		if block_manager.has_method("is_background_block_type") and bool(block_manager.is_background_block_type(clean_type)):
			return false
		if block_manager.has_method("is_non_collideable_block") and bool(block_manager.is_non_collideable_block(clean_type)):
			return false

	return true


func is_netfox_collision_debug_enabled() -> bool:
	return collision_debug_enabled


func log_player_collision_debug(
	player: Node2D,
	tick: int,
	collision_position: Vector2,
	collision_normal: Vector2,
	reason: String = "slide-collision"
) -> void:
	if not collision_debug_enabled:
		return
	if player == null or not is_instance_valid(player):
		return

	var peer_id := _get_audit_peer_id(player)
	var log_key := "%d:%s" % [peer_id, reason]
	var now_msec := Time.get_ticks_msec()
	var last_log_msec := int(last_collision_log_msec_by_key.get(log_key, 0))
	if now_msec - last_log_msec < COLLISION_LOG_MIN_INTERVAL_MSEC:
		return
	last_collision_log_msec_by_key[log_key] = now_msec

	var velocity := Vector2.ZERO
	var raw_velocity = player.get("velocity")
	if raw_velocity is Vector2:
		velocity = raw_velocity

	_print_player_collision_context(
		reason,
		player,
		tick,
		0.0,
		collision_position,
		collision_normal,
		true,
		velocity,
		player.position,
		player.position
	)


func audit_collision_nodes(reason: String = "manual") -> void:
	_audit_collision_nodes(reason, true)


func _print_player_collision_context(
	reason: String,
	player: Node2D,
	tick: int,
	correction_distance: float,
	collision_position: Vector2,
	collision_normal: Vector2,
	has_collision_point: bool,
	velocity: Vector2,
	predicted_position: Vector2,
	authoritative_position: Vector2
) -> void:
	if player == null or not is_instance_valid(player):
		return

	var peer_id := _get_audit_peer_id(player)
	var identity := _get_player_identity(player, peer_id)
	var block_size := _get_world_block_size()
	var safe_facing := 1
	var raw_facing = player.get("facing_dir")
	if raw_facing != null and int(raw_facing) < 0:
		safe_facing = -1

	var global_position := player.global_position
	var player_tile := _world_position_to_grid(global_position)
	var under_tile := _world_position_to_grid(global_position + Vector2(0.0, block_size * 0.55))
	var front_tile := _world_position_to_grid(global_position + Vector2(float(safe_facing) * block_size * 0.55, 0.0))
	var collision_tile: Vector2i = _world_position_to_grid(collision_position) if has_collision_point else _world_position_to_grid(authoritative_position)
	var collision_point_text: String = _format_vector2(collision_position) if has_collision_point else "n/a"
	var normal_text: String = _format_vector2(collision_normal) if has_collision_point else "n/a"
	var fingerprint := _get_world_collision_fingerprint()
	var movement_state: String = str(player.get("movement_state")) if player.get("movement_state") != null else ""
	var floor_text: String = str(player.is_on_floor() if player.has_method("is_on_floor") else false)

	print("%s collision-debug reason=%s role=%s peer=%d player_id=%s profile=%s username=%s path=%s tick=%d world=%s pos=%s player_tile=%s velocity=%s state=%s floor=%s correction=%.2f predicted=%s authoritative=%s collision_point=%s normal=%s revision=%d collision_hash=%s blocks=%d collision_blocks=%d chunks=%d under={%s} front={%s} collision={%s}" % [
		LOG_PREFIX,
		reason,
		"server" if multiplayer.is_server() else mode,
		peer_id,
		str(identity.get("game_player_id", "")),
		str(identity.get("profile_id", "")),
		str(identity.get("username", "")),
		str(player.get_path()),
		tick,
		_get_current_world_id(),
		_format_vector2(global_position),
		_grid_key_to_text(player_tile),
		_format_vector2(velocity),
		movement_state,
		floor_text,
		correction_distance,
		_format_vector2(predicted_position),
		_format_vector2(authoritative_position),
		collision_point_text,
		normal_text,
		int(fingerprint.get("revision", 0)),
		str(fingerprint.get("collision_hash", "")),
		int(fingerprint.get("block_count", 0)),
		int(fingerprint.get("collision_block_count", 0)),
		int(fingerprint.get("chunk_count", 0)),
		_describe_tile_collision_info(_get_tile_collision_info(under_tile)),
		_describe_tile_collision_info(_get_tile_collision_info(front_tile)),
		_describe_tile_collision_info(_get_tile_collision_info(collision_tile))
	])


func _world_position_to_grid(world_position: Vector2) -> Vector2i:
	var block_size := _get_world_block_size()
	return Vector2i(
		int(round(world_position.x / block_size)),
		int(round(world_position.y / block_size))
	)


func _get_tile_collision_info(grid_pos: Vector2i) -> Dictionary:
	var info := {
		"grid": grid_pos,
		"layer": "air",
		"source_layer": "air",
		"block_type": "air",
		"solid": false,
		"collision_enabled": false,
		"node_path": "none",
		"foreground_type": "",
		"foreground_collision_enabled": false,
		"tilemap_collision_enabled": false,
		"background_type": "",
		"background_collision_enabled": false
	}
	if world == null:
		return info

	var blocks = world.get("blocks")
	if blocks is Dictionary and blocks.has(grid_pos):
		var block_data = blocks.get(grid_pos, {})
		var block_type := _get_block_type_from_data(block_data)
		var block_node = null
		if block_data is Dictionary:
			block_node = block_data.get("node", null)
		info["layer"] = "foreground"
		info["source_layer"] = "foreground"
		info["block_type"] = block_type
		info["foreground_type"] = block_type
		info["solid"] = _is_collision_block_type(block_type)
		var tilemap_collision_enabled := _has_foreground_tilemap_collision_cell(grid_pos)
		info["collision_enabled"] = _node_has_enabled_collision(block_node) or tilemap_collision_enabled
		info["foreground_collision_enabled"] = bool(info["collision_enabled"])
		info["tilemap_collision_enabled"] = tilemap_collision_enabled
		if block_node != null and is_instance_valid(block_node):
			info["node_path"] = str(block_node.get_path())
		elif tilemap_collision_enabled:
			info["node_path"] = "tilemap-only"
		else:
			info["node_path"] = "missing-node"

	var block_manager = world.get("block_manager")
	if block_manager != null:
		var background_blocks = block_manager.get("background_blocks")
		if background_blocks is Dictionary and background_blocks.has(grid_pos):
			var background_data = background_blocks.get(grid_pos, {})
			var background_type := _get_block_type_from_data(background_data)
			var background_node = null
			if background_data is Dictionary:
				background_node = background_data.get("node", null)
			var background_collision_enabled := _node_has_enabled_collision(background_node)
			info["background_type"] = background_type
			info["background_collision_enabled"] = background_collision_enabled
			if str(info.get("layer", "air")) == "air":
				info["layer"] = "background"
				info["source_layer"] = "cave_background" if background_type.begins_with("cave_background") else "background"
				info["block_type"] = background_type
				info["solid"] = false
				info["collision_enabled"] = background_collision_enabled
				info["node_path"] = str(background_node.get_path()) if background_node != null and is_instance_valid(background_node) else "missing-node"

	return info


func _has_foreground_tilemap_collision_cell(grid_pos: Vector2i) -> bool:
	var renderer = _get_world_tilemap_renderer()
	if renderer == null:
		return false
	if renderer.has_method("has_foreground_collision_cell"):
		return bool(renderer.call("has_foreground_collision_cell", grid_pos))
	return false


func _describe_tile_collision_info(info: Dictionary) -> String:
	return "grid=%s layer=%s source=%s type=%s solid=%s collision_enabled=%s fg=%s fg_collision=%s tilemap_collision=%s bg=%s bg_collision=%s node=%s" % [
		_grid_key_to_text(info.get("grid", Vector2i.ZERO)),
		str(info.get("layer", "air")),
		str(info.get("source_layer", "air")),
		str(info.get("block_type", "air")),
		str(bool(info.get("solid", false))),
		str(bool(info.get("collision_enabled", false))),
		str(info.get("foreground_type", "")),
		str(bool(info.get("foreground_collision_enabled", false))),
		str(bool(info.get("tilemap_collision_enabled", false))),
		str(info.get("background_type", "")),
		str(bool(info.get("background_collision_enabled", false))),
		str(info.get("node_path", "none"))
	]


func _node_has_enabled_collision(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if node is CollisionShape2D:
		return not (node as CollisionShape2D).disabled

	if node is CollisionObject2D:
		var collision_object := node as CollisionObject2D
		if collision_object.collision_layer == 0 and collision_object.collision_mask == 0:
			return false
		return _node_has_enabled_collision_shape(node)

	for child in node.get_children():
		if _node_has_enabled_collision(child):
			return true

	return false


func _node_has_enabled_collision_shape(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	for child in node.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			return true
		if _node_has_enabled_collision_shape(child):
			return true

	return false


func _setup_collision_debug_overlay() -> void:
	if not collision_debug_enabled or world == null:
		return
	if collision_debug_overlay != null and is_instance_valid(collision_debug_overlay):
		return

	var overlay := CollisionDebugOverlay.new()
	overlay.name = "NetfoxCollisionDebugOverlay"
	overlay.manager = self
	overlay.z_as_relative = false
	overlay.z_index = 3600
	world.add_child(overlay)
	collision_debug_overlay = overlay


func _draw_collision_debug_overlay(overlay: Node2D) -> void:
	if not collision_debug_enabled or world == null or overlay == null:
		return

	var blocks = world.get("blocks")
	if not (blocks is Dictionary):
		return

	for grid_pos in blocks.keys():
		var block_type := _get_block_type_from_data(blocks.get(grid_pos, {}))
		if not _is_collision_block_type(block_type):
			continue

		var rect := _get_collision_debug_rect(grid_pos, block_type)
		overlay.draw_rect(rect, COLLISION_DEBUG_COLOR, true)
		overlay.draw_rect(rect, COLLISION_DEBUG_OUTLINE_COLOR, false, 1.0)


func _get_collision_debug_rect(grid_pos, block_type: String) -> Rect2:
	if grid_pos is Vector2:
		grid_pos = Vector2i(int(round(grid_pos.x)), int(round(grid_pos.y)))
	if not (grid_pos is Vector2i):
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var block_manager = world.get("block_manager") if world != null else null
	if block_manager != null and block_manager.has_method("get_block_collision_rect_for_grid"):
		var rect = block_manager.get_block_collision_rect_for_grid(grid_pos, block_type)
		if rect is Rect2:
			return rect

	var block_size := _get_world_block_size()
	var center := Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)
	return Rect2(center - Vector2(block_size, block_size) * 0.5, Vector2(block_size, block_size))


func _audit_collision_nodes(reason: String, force: bool = false) -> void:
	if not collision_debug_enabled or world == null:
		return

	var now_msec := Time.get_ticks_msec()
	if not force and now_msec - last_collision_audit_msec < COLLISION_AUDIT_MIN_INTERVAL_MSEC:
		return
	last_collision_audit_msec = now_msec

	var enabled_block_bodies := 0
	var stale_enabled := 0
	var background_enabled := 0
	var non_solid_enabled := 0
	var duplicate_enabled := 0
	var enabled_by_grid: Dictionary = {}
	var details: Array[String] = []
	for candidate in world.find_children("*", "CollisionObject2D", true, false):
		if not (candidate is CollisionObject2D):
			continue
		if not _looks_like_block_collision_node(candidate):
			continue
		if not _node_has_enabled_collision(candidate):
			continue

		var collision_object := candidate as CollisionObject2D
		enabled_block_bodies += 1
		var grid_pos := _world_position_to_grid(collision_object.global_position)
		var grid_key := _grid_key_to_text(grid_pos)
		enabled_by_grid[grid_key] = int(enabled_by_grid.get(grid_key, 0)) + 1
		if int(enabled_by_grid[grid_key]) > 1:
			duplicate_enabled += 1

		var info := _get_tile_collision_info(grid_pos)
		var layer := str(info.get("layer", "air"))
		var is_solid := bool(info.get("solid", false))
		var should_report := false
		var issue := ""
		if _is_under_background_blocks(collision_object):
			background_enabled += 1
			should_report = true
			issue = "background"
		elif layer == "air":
			stale_enabled += 1
			should_report = true
			issue = "stale"
		elif layer == "background":
			background_enabled += 1
			should_report = true
			issue = "background"
		elif not is_solid:
			non_solid_enabled += 1
			should_report = true
			issue = "non_solid"
		elif int(enabled_by_grid[grid_key]) > 1:
			should_report = true
			issue = "duplicate"

		if should_report and details.size() < COLLISION_AUDIT_MAX_DETAILS:
			details.append("%s path=%s body_pos=%s tile={%s}" % [
				issue,
				str(collision_object.get_path()),
				_format_vector2(collision_object.global_position),
				_describe_tile_collision_info(info)
			])

	print("%s collision node audit reason=%s role=%s peer=%d enabled_block_bodies=%d stale_enabled=%d background_enabled=%d non_solid_enabled=%d duplicate_enabled=%d world=%s blocks=%d collision_blocks=%d revision=%d collision_hash=%s" % [
		LOG_PREFIX,
		reason,
		"server" if multiplayer.is_server() else mode,
		_get_local_peer_id(),
		enabled_block_bodies,
		stale_enabled,
		background_enabled,
		non_solid_enabled,
		duplicate_enabled,
		_get_current_world_id(),
		_get_world_block_count(),
		_get_world_collision_block_count(),
		_get_world_collision_revision(),
		str(_get_world_collision_fingerprint().get("collision_hash", "0"))
	])
	for detail in details:
		print("%s collision node audit detail %s" % [LOG_PREFIX, detail])


func _looks_like_block_collision_node(node: Node) -> bool:
	if node == null:
		return false
	if str(node.scene_file_path).ends_with("Scenes/block.tscn"):
		return true
	if node.get_node_or_null("Visual") is Sprite2D:
		return true
	var parent := node.get_parent()
	while parent != null:
		if str(parent.name) == "BackgroundBlocks":
			return true
		parent = parent.get_parent()
	return false


func _is_under_background_blocks(node: Node) -> bool:
	var parent := node
	while parent != null:
		if str(parent.name) == "BackgroundBlocks":
			return true
		parent = parent.get_parent()
	return false


func _grid_key_to_text(grid_pos) -> String:
	if grid_pos is Vector2i:
		return "%d,%d" % [grid_pos.x, grid_pos.y]
	if grid_pos is Vector2:
		return "%d,%d" % [int(round(grid_pos.x)), int(round(grid_pos.y))]
	return str(grid_pos)


func _hash_string_entries(entries: Array[String]) -> String:
	var state_hash := 5381
	for entry in entries:
		for index in range(entry.length()):
			state_hash = int(((state_hash << 5) + state_hash + entry.unicode_at(index)) & 0x7fffffff)
	return str(state_hash)


func _format_vector2(value: Vector2) -> String:
	return "(%.2f, %.2f)" % [value.x, value.y]


func _should_load_server_world_collision_from_backend() -> bool:
	if mode != "server":
		return false
	return _get_server_world_state_token() != ""


func notify_server_world_ready_from_local_bootstrap(world_name: String = "") -> void:
	if mode != "server":
		return

	server_world_load_started = true
	server_world_load_failed = false
	server_world_load_complete = true
	_reset_world_collision_runtime_state()
	var clean_world: String = world_name.strip_edges().to_upper()
	if clean_world == "":
		clean_world = _get_server_authoritative_world_id()
	print("%s Server local world ready world=%s blocks=%d collision_blocks=%d world_collision_ready=%s queued_spawns=%d." % [
		LOG_PREFIX,
		clean_world,
		_get_world_block_count(),
		_get_world_collision_block_count(),
		str(_is_world_collision_ready()),
		pending_spawn_requests.size()
	])
	_process_pending_spawn_requests()
	call_deferred("_register_server_route_with_backend", "local-world-ready")


func _load_server_world_collision_from_backend() -> void:
	if server_world_load_started or server_world_load_complete:
		return

	server_world_load_started = true
	server_world_load_failed = false
	var requested_world := _get_server_authoritative_world_id()
	if requested_world == "":
		requested_world = MovementMode.get_dev_test_world_name("START")
	var backend_url := _get_backend_api_base_url()
	var endpoint := _get_server_world_state_endpoint()
	var headers := _get_server_world_state_headers()
	print("%s Server loading world %s from backend %s%s..." % [LOG_PREFIX, requested_world, backend_url, endpoint])

	var managers_ready := await _wait_for_world_state_managers_ready(10.0)
	if not managers_ready:
		_fail_server_world_load("World managers were not ready before timeout.")
		return

	_prepare_server_world_entry(requested_world)

	var request := HTTPRequest.new()
	request.name = "NetfoxServerWorldStateRequest"
	request.timeout = SERVER_WORLD_STATE_TIMEOUT_SECONDS
	add_child(request)

	var url := "%s%s?world=%s" % [backend_url, endpoint, requested_world.uri_encode()]
	var error := request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		_fail_server_world_load("Could not start backend world-state request. error=%s url=%s" % [str(error), url])
		return

	var response = await request.request_completed
	request.queue_free()

	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		response_code = int(response[1])
		body = response[3]

	var body_text := body.get_string_from_utf8()
	if response_code != 200:
		var auth_hint := ""
		if response_code == 401:
			auth_hint = " Set NETFOX_SERVER_WORLD_STATE_TOKEN or NETFOX_SERVER_WORLD_STATE_TOKEN_HASH on the backend, then launch Godot with the matching raw token via --netfox-server-token or PIXELMANIA_NETFOX_SERVER_TOKEN."
		elif response_code == 503:
			auth_hint = " Configure NETFOX_SERVER_WORLD_STATE_TOKEN or NETFOX_SERVER_WORLD_STATE_TOKEN_HASH on the backend and reload it."
		_fail_server_world_load("Backend world-state request failed. status=%d body=%s" % [
			response_code,
			body_text.substr(0, min(240, body_text.length())) + auth_hint
		])
		return

	var parsed = JSON.parse_string(body_text)
	if not (parsed is Dictionary):
		_fail_server_world_load("Backend world-state response was not valid JSON.")
		return
	if not bool(parsed.get("ok", false)):
		_fail_server_world_load("Backend rejected world-state request: %s" % str(parsed.get("error", "unknown error")))
		return

	var payload = parsed.get("world_state", {})
	if not (payload is Dictionary):
		_fail_server_world_load("Backend world-state payload was missing.")
		return

	if not payload.has("foreground") and payload.has("blocks"):
		payload["foreground"] = payload.get("blocks", [])
	if not payload.has("background") and payload.has("background_blocks"):
		payload["background"] = payload.get("background_blocks", [])
	payload["world"] = requested_world
	payload["world_name"] = requested_world
	payload["world_id"] = requested_world
	payload["respawn_player"] = false
	payload["force_player_position"] = false
	payload["world_state_reason"] = "netfox_archive_server_world_load"

	var block_count := int(parsed.get("block_count", 0))
	var collision_count := int(parsed.get("collision_block_count", 0))
	print("%s Server world load success world=%s blocks=%d collision_blocks=%d queued_spawns=%d." % [
		LOG_PREFIX,
		requested_world,
		block_count,
		collision_count,
		pending_spawn_requests.size()
	])

	if world.has_method("apply_network_world_state"):
		world.apply_network_world_state(payload)
	else:
		_fail_server_world_load("World node cannot apply network world state.")
		return

	var apply_ok := await _wait_for_server_world_collision_ready(20.0)
	if not apply_ok:
		_fail_server_world_load("World state applied but collision was not ready. blocks=%d entry_in_progress=%s" % [
			_get_world_block_count(),
			str(world.get_meta("world_entry_in_progress", false))
		])
		return

	server_world_load_complete = true
	print("%s Server world ready world=%s blocks=%d collision_blocks=%d world_collision_ready=%s queued_spawns=%d." % [
		LOG_PREFIX,
		requested_world,
		_get_world_block_count(),
		_get_world_collision_block_count(),
		str(_is_world_collision_ready()),
		pending_spawn_requests.size()
	])
	_log_world_collision_fingerprint("server-world-ready", true)
	_process_pending_spawn_requests()
	call_deferred("_register_server_route_with_backend", "server-world-ready")


func _wait_for_world_state_managers_ready(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() <= deadline:
		if world != null and world.get("block_manager") != null and world.get("save_manager") != null and world.get("world_state_sync_manager") != null:
			return true
		await get_tree().process_frame

	return world != null and world.get("block_manager") != null and world.get("save_manager") != null and world.get("world_state_sync_manager") != null


func _prepare_server_world_entry(world_name: String) -> void:
	if world == null:
		return

	world.set("current_world_name", world_name)
	world.set("in_world", true)
	world.set_meta("world_entry_in_progress", true)

	var save_manager = world.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager:
		save_manager.waiting_for_server_world_state = true

	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		network.set("current_world_name", world_name)

	if world.has_method("begin_smooth_world_load"):
		world.begin_smooth_world_load(world_name, true)
	if world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message("Loading " + world_name + " on Netfox server...")


func _wait_for_server_world_collision_ready(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() <= deadline:
		if _is_world_collision_ready():
			return true
		await get_tree().process_frame

	return _is_world_collision_ready()


func _fail_server_world_load(message: String) -> void:
	server_world_load_failed = true
	if world != null:
		world.set_meta("world_entry_in_progress", false)
	push_error("%s Server world load failed: %s" % [LOG_PREFIX, message])


func _get_backend_api_base_url() -> String:
	var api_base := MovementMode.get_launch_arg_value("--pixelmania-api-base", "").strip_edges()
	if api_base == "":
		var network := get_node_or_null("/root/NetworkManager")
		if network != null:
			if network.has_method("configure_network_urls"):
				network.configure_network_urls()
			var active_api = network.get("active_api_base")
			if active_api != null:
				api_base = str(active_api).strip_edges()

	if api_base == "":
		api_base = _infer_api_base_from_ws_url(MovementMode.get_launch_arg_value("--pixelmania-ws-url", ""))

	if api_base == "":
		api_base = "http://127.0.0.1:8080"

	return _trim_trailing_slashes(api_base)


func _tick_server_route_registration() -> void:
	if mode != "server" or route_registration_in_progress:
		return
	if _get_server_world_state_token() == "":
		_log_server_route_registration_token_missing("heartbeat")
		return
	if not _is_server_route_advertisable():
		_log_server_route_registration_wait("heartbeat")
		return

	var now_msec: int = Time.get_ticks_msec()
	if last_route_registration_msec > 0 and now_msec - last_route_registration_msec < SERVER_ROUTE_REGISTER_INTERVAL_MSEC:
		return

	_register_server_route_with_backend("heartbeat")


func _register_server_route_with_backend(reason: String = "heartbeat") -> void:
	if mode != "server" or route_registration_in_progress:
		return
	if _get_server_world_state_token() == "":
		_log_server_route_registration_token_missing(reason)
		return
	if not _is_server_route_advertisable():
		_log_server_route_registration_wait(reason)
		return

	route_registration_in_progress = true
	var request := HTTPRequest.new()
	request.name = "NetfoxServerRouteRegisterRequest"
	request.timeout = SERVER_ROUTE_REGISTER_TIMEOUT_SECONDS
	add_child(request)

	var headers: PackedStringArray = _get_server_world_state_headers()
	headers.append("Content-Type: application/json")
	var request_body: String = JSON.stringify({
		"world": _get_server_authoritative_world_id(),
		"host": _get_server_route_public_host(),
		"port": _get_server_route_public_port(),
		"max_clients": max_clients
	})
	var url: String = "%s%s" % [_get_backend_api_base_url(), SERVER_REGISTER_ROUTE_ENDPOINT]
	if debug_enabled:
		print("%s Registering Netfox route. reason=%s url=%s world=%s public=%s:%d token_present=%s" % [
			LOG_PREFIX,
			reason,
			url,
			_get_server_authoritative_world_id(),
			_get_server_route_public_host(),
			_get_server_route_public_port(),
			str(_get_server_world_state_token() != "")
		])
	var error: int = request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	if error != OK:
		request.queue_free()
		route_registration_in_progress = false
		push_warning("%s Could not start Netfox route registration. reason=%s error=%s" % [LOG_PREFIX, reason, str(error)])
		return

	var response: Variant = await request.request_completed
	request.queue_free()
	route_registration_in_progress = false
	last_route_registration_msec = Time.get_ticks_msec()

	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		response_code = int(response[1])
		body = response[3]

	var body_text: String = body.get_string_from_utf8()
	if response_code != 200:
		push_warning("%s Netfox route registration failed. reason=%s status=%d body=%s" % [
			LOG_PREFIX,
			reason,
			response_code,
			body_text.substr(0, min(240, body_text.length()))
		])
		return

	if debug_enabled:
		print("%s Netfox route registered. reason=%s world=%s public=%s:%d" % [
			LOG_PREFIX,
			reason,
			_get_server_authoritative_world_id(),
			_get_server_route_public_host(),
			_get_server_route_public_port()
		])


func _is_server_route_advertisable() -> bool:
	if mode != "server":
		return false
	if server_world_load_failed:
		return false
	if _should_load_server_world_collision_from_backend() and not server_world_load_complete:
		return false
	return _is_world_collision_ready()


func _log_server_route_registration_config(reason: String) -> void:
	print("%s Route registration config reason=%s api=%s world=%s advertised=%s:%d token_present=%s world_ready=%s" % [
		LOG_PREFIX,
		reason,
		_get_backend_api_base_url(),
		_get_server_authoritative_world_id(),
		_get_server_route_public_host(),
		_get_server_route_public_port(),
		str(_get_server_world_state_token() != ""),
		str(_is_server_route_advertisable())
	])


func _log_server_route_registration_token_missing(reason: String) -> void:
	if route_registration_token_missing_logged:
		return
	route_registration_token_missing_logged = true
	push_warning("%s Netfox route registration disabled: no server token is available. reason=%s api=%s world=%s advertised=%s:%d. Pass --netfox-server-token or set %s." % [
		LOG_PREFIX,
		reason,
		_get_backend_api_base_url(),
		_get_server_authoritative_world_id(),
		_get_server_route_public_host(),
		_get_server_route_public_port(),
		SERVER_WORLD_STATE_TOKEN_ENV
	])


func _log_server_route_registration_wait(reason: String) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if last_route_registration_wait_log_msec > 0 and now_msec - last_route_registration_wait_log_msec < SERVER_ROUTE_REGISTER_INTERVAL_MSEC:
		return
	last_route_registration_wait_log_msec = now_msec
	print("%s Waiting before Netfox route registration. reason=%s world=%s world_load_complete=%s world_load_failed=%s collision_ready=%s blocks=%d collision_blocks=%d" % [
		LOG_PREFIX,
		reason,
		_get_server_authoritative_world_id(),
		str(server_world_load_complete),
		str(server_world_load_failed),
		str(_is_world_collision_ready()),
		_get_world_block_count(),
		_get_world_collision_block_count()
	])


func _get_server_route_public_host() -> String:
	var launch_host: String = MovementMode.get_launch_arg_value(PUBLIC_HOST_ARG, "").strip_edges()
	if launch_host != "":
		return launch_host

	var env_host: String = OS.get_environment(PUBLIC_HOST_ENV).strip_edges()
	if env_host != "":
		return env_host

	if host.strip_edges() != "":
		return host.strip_edges()
	return DEFAULT_ADDRESS


func _get_server_route_public_port() -> int:
	var launch_port: String = MovementMode.get_launch_arg_value(PUBLIC_PORT_ARG, "").strip_edges()
	if launch_port != "":
		return _parse_positive_int(launch_port, port, 1, 65535)

	var env_port: String = OS.get_environment(PUBLIC_PORT_ENV).strip_edges()
	if env_port != "":
		return _parse_positive_int(env_port, port, 1, 65535)

	return port


func _requires_backend_spawn_ticket_verification() -> bool:
	return mode == "server" and _get_server_world_state_token() != ""


func _verify_spawn_ticket_with_backend(peer_id: int, identity_payload: Dictionary) -> Dictionary:
	if not _requires_backend_spawn_ticket_verification():
		return {
			"ok": true,
			"identity": identity_payload
		}

	var ticket: String = str(identity_payload.get("netfox_spawn_ticket", "")).strip_edges()
	if ticket == "":
		return {
			"ok": false,
			"reason": "spawn_ticket_missing",
			"message": "Netfox spawn ticket was missing."
		}

	var request := HTTPRequest.new()
	request.name = "NetfoxSpawnTicketVerifyRequest"
	request.timeout = SERVER_SPAWN_TICKET_VERIFY_TIMEOUT_SECONDS
	add_child(request)

	var headers: PackedStringArray = _get_server_world_state_headers()
	headers.append("Content-Type: application/json")
	var request_body: String = JSON.stringify({
		"ticket": ticket,
		"world": _get_server_authoritative_world_id(),
		"peer_id": peer_id
	})
	var url: String = "%s%s" % [_get_backend_api_base_url(), SERVER_VERIFY_SPAWN_TICKET_ENDPOINT]
	var error: int = request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	if error != OK:
		request.queue_free()
		return {
			"ok": false,
			"reason": "spawn_ticket_verify_failed",
			"message": "Could not start Netfox spawn ticket verification."
		}

	var response: Variant = await request.request_completed
	request.queue_free()

	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		response_code = int(response[1])
		body = response[3]

	var body_text: String = body.get_string_from_utf8()
	var parsed_value: Variant = JSON.parse_string(body_text)
	if response_code != 200:
		var reason := "spawn_ticket_invalid"
		var message := body_text.substr(0, min(240, body_text.length()))
		if parsed_value is Dictionary:
			reason = str(parsed_value.get("reason", reason))
			message = str(parsed_value.get("error", message))
		return {
			"ok": false,
			"reason": reason,
			"message": message
		}

	if not (parsed_value is Dictionary):
		return {
			"ok": false,
			"reason": "spawn_ticket_verify_failed",
			"message": "Backend spawn ticket verification returned invalid JSON."
		}

	if not bool(parsed_value.get("ok", false)):
		return {
			"ok": false,
			"reason": str(parsed_value.get("reason", "spawn_ticket_invalid")),
			"message": str(parsed_value.get("error", "Netfox spawn ticket was rejected."))
		}

	var verified_identity_value: Variant = parsed_value.get("identity", {})
	if not (verified_identity_value is Dictionary):
		return {
			"ok": false,
			"reason": "spawn_ticket_verify_failed",
			"message": "Backend spawn ticket verification returned no identity."
		}

	var verified_identity: Dictionary = verified_identity_value.duplicate(true)
	verified_identity["netfox_spawn_ticket_verified"] = true
	return {
		"ok": true,
		"identity": verified_identity
	}


func _get_server_world_state_endpoint() -> String:
	if _get_server_world_state_token() != "":
		return SERVER_WORLD_STATE_LIVE_ENDPOINT
	return SERVER_WORLD_STATE_DEV_ENDPOINT


func _get_server_world_state_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	var token := _get_server_world_state_token()
	if token != "":
		headers.append("Authorization: Bearer " + token)
		headers.append("X-Netfox-Server-Token: " + token)
	return headers


func _get_server_world_state_token() -> String:
	var token := MovementMode.get_launch_arg_value(SERVER_WORLD_STATE_TOKEN_ARG, "").strip_edges()
	if token == "":
		token = OS.get_environment(SERVER_WORLD_STATE_TOKEN_ENV).strip_edges()
	if token == "":
		token = OS.get_environment(BACKEND_SERVER_WORLD_STATE_TOKEN_ENV).strip_edges()
	return token


func _infer_api_base_from_ws_url(ws_url: String) -> String:
	var clean_url := ws_url.strip_edges()
	if clean_url == "":
		return ""

	var inferred := ""
	if clean_url.begins_with("ws://"):
		inferred = "http://" + clean_url.substr(5)
	elif clean_url.begins_with("wss://"):
		inferred = "https://" + clean_url.substr(6)
	else:
		return ""

	if inferred.ends_with("/ws"):
		inferred = inferred.substr(0, inferred.length() - 3)
	return _trim_trailing_slashes(inferred)


func _trim_trailing_slashes(value: String) -> String:
	var clean_value := value.strip_edges()
	while clean_value.ends_with("/") and clean_value.length() > 0:
		clean_value = clean_value.substr(0, clean_value.length() - 1)
	return clean_value


@rpc("authority", "call_remote", "reliable")
func spawn_player(peer_id: int, spawn_position: Vector2, display_name: String = "", identity_payload = {}) -> void:
	_spawn_player(peer_id, spawn_position, display_name, identity_payload)


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	_despawn_player(peer_id)


@rpc("authority", "call_remote", "reliable")
func spawn_rejected(reason: String, server_world: String = "", requested_world: String = "") -> void:
	if mode != "client":
		return

	_reset_client_spawn_request_state("spawn-rejected-" + reason)
	spawn_rejected_until_msec = Time.get_ticks_msec() + SPAWN_REJECTION_RETRY_DELAY_MSEC
	last_spawn_rejection_reason = reason
	_clear_players()

	var message: String = _get_spawn_rejection_message(reason, server_world, requested_world)
	push_warning("%s %s" % [LOG_PREFIX, message])
	if world != null and world.has_method("update_smooth_world_load_message"):
		world.update_smooth_world_load_message(message)
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)


@rpc("any_peer", "call_remote", "reliable")
func confirm_player_registered(subject_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var confirming_peer_id := multiplayer.get_remote_sender_id()
	if confirming_peer_id <= BODY_AUTHORITY or subject_peer_id <= 0:
		return

	_record_player_visibility_confirmation(subject_peer_id, confirming_peer_id, "client-registered")


func _spawn_player(peer_id: int, spawn_position: Vector2, display_name: String = "", identity_payload = {}) -> void:
	if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
		push_error("%s Refused to spawn peer %d without a resolved Entrance Gate position." % [LOG_PREFIX, peer_id])
		return
	if players_root == null:
		_setup_players_root()
	if players_root == null:
		push_error("%s Cannot spawn player; Players root is missing." % LOG_PREFIX)
		return

	var player_name := "Player_%d" % peer_id
	var clean_identity := _sanitize_identity_payload(identity_payload, peer_id)
	if str(clean_identity.get("display_name", "")).strip_edges() == "" and display_name.strip_edges() != "":
		clean_identity["display_name"] = _sanitize_display_name(display_name, peer_id)
	var clean_display_name := _get_identity_display_name(clean_identity, peer_id)

	var existing := players_root.get_node_or_null(player_name)
	if existing != null and existing.is_queued_for_deletion():
		players_root.remove_child(existing)
		existing = null
	if existing != null:
		_apply_player_identity(existing, peer_id, clean_identity)
		if existing.has_method("set_display_name"):
			existing.set_display_name(clean_display_name)
		_refresh_world_collision_streaming_for_positions([spawn_position], "duplicate-spawn-%d" % peer_id)
		_prepare_player_for_netfox_replication(existing, peer_id)
		_configure_player_draw_order(existing, peer_id)
		_apply_remote_spawn_visual_position(existing, peer_id, spawn_position, "duplicate-spawn")
		_refresh_world_collision_streaming_for_positions([spawn_position], "duplicate-spawn-applied-%d" % peer_id)
		_finish_player_spawn_registration(existing, peer_id, "duplicate-spawn")
		if peer_id == _get_local_peer_id():
			_activate_local_player(existing)
		print("%s Ignored duplicate spawn for %s at %s." % [LOG_PREFIX, player_name, existing.get_path()])
		_log_phase7_identity(existing, peer_id, "duplicate-spawn")
		_audit_phase7_identity_mapping("duplicate-spawn-" + player_name)
		_audit_player_nodes("duplicate-spawn-" + player_name)
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = player_name
	_apply_player_identity(player, peer_id, clean_identity)
	players_root.add_child(player)
	if player is Node2D:
		(player as Node2D).global_position = spawn_position
	_refresh_world_collision_streaming_for_positions([spawn_position], "spawn-%d" % peer_id)
	spawned_players[peer_id] = _get_current_player_position_for_peer(peer_id, spawn_position)
	player_display_names[peer_id] = clean_display_name
	player_identity_payloads[peer_id] = clean_identity

	_prepare_player_for_netfox_replication(player, peer_id)
	if player.has_method("set_display_name"):
		player.set_display_name(clean_display_name)

	_configure_player_draw_order(player, peer_id)
	_apply_remote_spawn_visual_position(player, peer_id, spawn_position, "spawn")
	_finish_player_spawn_registration(player, peer_id, "spawn")
	if peer_id == _get_local_peer_id():
		_activate_local_player(player)

	print("%s NETFOX_SPAWN_READY peer=%d local=%s player=%s path=%s pos=%s total_spawned=%d display_name=%s world=%s" % [
		LOG_PREFIX,
		peer_id,
		str(peer_id == _get_local_peer_id()),
		player.name,
		str(player.get_path()),
		str((player as Node2D).global_position if player is Node2D else spawn_position),
		spawned_players.size(),
		clean_display_name,
		str(clean_identity.get("world_id", _get_current_world_id()))
	])
	_log_netfox_status("spawn-ready-" + str(peer_id), true)
	_log_player_authority(player, peer_id)
	_log_phase7_identity(player, peer_id, "spawn")
	_audit_phase7_identity_mapping("spawn-" + player_name)
	_clear_legacy_websocket_player_visuals("spawn-" + player_name)
	_audit_player_nodes("spawn-" + player_name)


func _prepare_player_for_netfox_replication(player: Node, peer_id: int) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("setup_authority"):
		player.setup_authority(peer_id)
	else:
		player.set_multiplayer_authority(BODY_AUTHORITY)
		var player_input := player.get_node_or_null("PlayerInput")
		if player_input != null:
			player_input.set_multiplayer_authority(peer_id)
		_process_player_netfox_settings(player)

	_register_player_identity_nodes(player)


func _process_player_netfox_settings(player: Node) -> void:
	var rollback_synchronizer := player.get_node_or_null("RollbackSynchronizer")
	if rollback_synchronizer != null and rollback_synchronizer.has_method("process_settings"):
		rollback_synchronizer.process_settings()

	var tick_interpolator := player.get_node_or_null("TickInterpolator")
	if tick_interpolator != null and tick_interpolator.has_method("process_settings"):
		tick_interpolator.process_settings()


func _register_player_identity_nodes(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.is_inside_tree():
		NetworkIdentityServer.register_node(player)

	var player_input := player.get_node_or_null("PlayerInput")
	if player_input != null and player_input.is_inside_tree():
		NetworkIdentityServer.register_node(player_input)

	NetworkIdentityServer.flush_queue()


func _finish_player_spawn_registration(player: Node, peer_id: int, reason: String) -> void:
	if player == null or not is_instance_valid(player):
		return

	if multiplayer.is_server():
		_configure_player_state_visibility(player, peer_id, reason)
		return

	_confirm_player_registered_with_server(peer_id, reason)


func _confirm_player_registered_with_server(peer_id: int, reason: String) -> void:
	if peer_id <= 0:
		return
	if not _is_multiplayer_connected():
		return

	confirm_player_registered.rpc_id(BODY_AUTHORITY, peer_id)
	if debug_enabled:
		print("%s Confirmed local registration for Player_%d reason=%s." % [LOG_PREFIX, peer_id, reason])


func _configure_player_state_visibility(player: Node, subject_peer_id: int, reason: String) -> void:
	var visibility_filter := _get_player_visibility_filter(player)
	if visibility_filter == null:
		return

	visibility_filter.set_visibility_for(0, false)
	_apply_player_visibility_confirmations(subject_peer_id, reason)


func _get_player_visibility_filter(player: Node) -> PeerVisibilityFilter:
	if player == null or not is_instance_valid(player):
		return null

	var rollback_synchronizer := player.get_node_or_null("RollbackSynchronizer")
	if rollback_synchronizer == null:
		return null

	var raw_filter = rollback_synchronizer.get("visibility_filter")
	if raw_filter is PeerVisibilityFilter:
		return raw_filter

	return null


func _record_player_visibility_confirmation(subject_peer_id: int, confirming_peer_id: int, reason: String) -> void:
	if subject_peer_id <= 0 or confirming_peer_id <= BODY_AUTHORITY:
		return

	var confirmations = player_visibility_confirmations.get(subject_peer_id, {})
	if not (confirmations is Dictionary):
		confirmations = {}
	confirmations[confirming_peer_id] = true
	player_visibility_confirmations[subject_peer_id] = confirmations
	_apply_player_visibility_confirmations(subject_peer_id, reason)


func _apply_player_visibility_confirmations(subject_peer_id: int, reason: String = "") -> void:
	if not multiplayer.is_server():
		return
	if players_root == null:
		return

	var player := players_root.get_node_or_null("Player_%d" % subject_peer_id)
	if player == null or not is_instance_valid(player):
		return

	var visibility_filter := _get_player_visibility_filter(player)
	if visibility_filter == null:
		return

	visibility_filter.set_visibility_for(0, false)
	var confirmations = player_visibility_confirmations.get(subject_peer_id, {})
	if not (confirmations is Dictionary):
		confirmations = {}

	var visible_peers: Array[int] = []
	var peers := multiplayer.get_peers()
	for peer_id in peers:
		var can_see := bool(confirmations.get(peer_id, false)) and _can_peer_observe_player(peer_id, subject_peer_id)
		visibility_filter.set_visibility_for(peer_id, can_see)
		if can_see:
			visible_peers.append(peer_id)
			_queue_player_identity_for_peer(player, peer_id)

	visibility_filter.update_visibility(peers)
	NetworkIdentityServer.flush_queue()

	if debug_enabled:
		print("%s Player_%d rollback visibility peers=%s reason=%s." % [
			LOG_PREFIX,
			subject_peer_id,
			str(visible_peers),
			reason
		])


func _can_peer_observe_player(observer_peer_id: int, subject_peer_id: int) -> bool:
	if observer_peer_id == subject_peer_id:
		return true

	var observer_world := _get_world_id_for_peer(observer_peer_id)
	var subject_world := _get_world_id_for_peer(subject_peer_id)
	if observer_world == "" or subject_world == "":
		return true

	return observer_world == subject_world


func _get_world_id_for_peer(peer_id: int) -> String:
	var identity = player_identity_payloads.get(peer_id, {})
	if identity is Dictionary:
		var world_id := str(identity.get("world_id", identity.get("world", ""))).strip_edges().to_upper()
		if world_id != "":
			return world_id

	return _get_current_world_id()


func _queue_player_identity_for_peer(player: Node, peer_id: int) -> void:
	if player == null or not is_instance_valid(player) or peer_id <= BODY_AUTHORITY:
		return

	NetworkIdentityServer.queue_identifier_for(player, peer_id)
	var player_input := player.get_node_or_null("PlayerInput")
	if player_input != null and is_instance_valid(player_input):
		NetworkIdentityServer.queue_identifier_for(player_input, peer_id)


func _clear_player_visibility_confirmation(peer_id: int) -> void:
	player_visibility_confirmations.erase(peer_id)

	for subject_key in player_visibility_confirmations.keys():
		var confirmations = player_visibility_confirmations.get(subject_key, {})
		if not (confirmations is Dictionary):
			continue
		confirmations.erase(peer_id)
		if confirmations.is_empty():
			player_visibility_confirmations.erase(subject_key)
		else:
			player_visibility_confirmations[subject_key] = confirmations
			_apply_player_visibility_confirmations(int(subject_key), "peer-disconnected")


func _configure_player_draw_order(player: Node, peer_id: int) -> void:
	if player == null or not (player is CanvasItem):
		return

	var player_canvas := player as CanvasItem
	player_canvas.z_as_relative = false
	player_canvas.z_index = _get_local_player_z_index() if peer_id == _get_local_peer_id() else _get_remote_player_z_index()


func _get_local_player_z_index() -> int:
	if world != null and world.get("LOCAL_PLAYER_Z_INDEX") != null:
		return int(world.get("LOCAL_PLAYER_Z_INDEX"))
	return 3900


func _get_remote_player_z_index() -> int:
	return _get_local_player_z_index() + REMOTE_PLAYER_Z_OFFSET


func _apply_remote_spawn_visual_position(player: Node, peer_id: int, spawn_position: Vector2, reason: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if peer_id == _get_local_peer_id():
		return
	if not (player is Node2D):
		return
	if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
		return

	(player as Node2D).global_position = spawn_position
	var tick_interpolator := player.get_node_or_null("TickInterpolator")
	if tick_interpolator != null and tick_interpolator.has_method("teleport"):
		tick_interpolator.call("teleport")

	if debug_enabled:
		print("%s Applied remote spawn visual position peer=%d pos=%s reason=%s" % [
			LOG_PREFIX,
			peer_id,
			str(spawn_position),
			reason
		])


func _despawn_player(peer_id: int) -> void:
	var player_name := "Player_%d" % peer_id
	if players_root == null:
		return

	var player := players_root.get_node_or_null(player_name)
	if player != null:
		_mark_player_despawned(player)
		if world.get("player") == player:
			_clear_local_player_bindings(player)
		player.queue_free()
	spawned_players.erase(peer_id)
	player_display_names.erase(peer_id)
	player_identity_payloads.erase(peer_id)
	spawning_peer_ids.erase(peer_id)
	spawn_verification_peer_ids.erase(peer_id)
	_clear_player_visibility_confirmation(peer_id)
	_clear_phase7_identity_log_for_peer(peer_id)
	_clear_netfox_chat_bubble_for_peer(peer_id)
	_audit_phase7_identity_mapping("despawn-" + player_name)
	_audit_player_nodes("despawn-" + player_name)


func _clear_players(immediate: bool = false) -> void:
	if players_root == null:
		return

	_clear_local_player_bindings()
	for child in players_root.get_children():
		_mark_player_despawned(child)
		if immediate:
			players_root.remove_child(child)
			child.free()
		else:
			child.queue_free()
	spawned_players.clear()
	player_display_names.clear()
	player_identity_payloads.clear()
	spawning_peer_ids.clear()
	spawn_verification_peer_ids.clear()
	player_visibility_confirmations.clear()
	phase7_identity_logged_keys.clear()
	_clear_netfox_chat_bubbles()
	_audit_phase7_identity_mapping("clear-players")
	_audit_player_nodes("clear-players")


func _clear_local_player_bindings(player_node: Node = null) -> void:
	var current_player = world.get("player") if world != null else null
	if player_node != null and current_player != player_node:
		return

	if world != null:
		world.set("player", null)
		var equipment_manager = world.get("equipment_manager")
		if equipment_manager != null and equipment_manager.has_method("clear_player_references"):
			equipment_manager.clear_player_references()


func _sync_spawned_player_positions_from_scene() -> void:
	if not multiplayer.is_server():
		return
	if players_root == null:
		return

	for raw_peer_id in spawned_players.keys():
		var peer_id := int(raw_peer_id)
		spawned_players[peer_id] = _get_current_player_position_for_peer(peer_id, spawned_players.get(raw_peer_id, Vector2.ZERO))


func _get_current_player_position_for_peer(peer_id: int, fallback_position: Vector2 = Vector2.ZERO) -> Vector2:
	if players_root == null:
		return fallback_position

	var player := players_root.get_node_or_null("Player_%d" % peer_id) as Node2D
	if player == null or not is_instance_valid(player):
		return fallback_position

	return player.global_position


func _send_existing_player_spawn_to_peer(target_peer_id: int, subject_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if target_peer_id <= BODY_AUTHORITY:
		return
	if subject_peer_id <= 0 or subject_peer_id == target_peer_id:
		return
	if not spawned_players.has(subject_peer_id):
		return
	if not _can_peer_observe_player(target_peer_id, subject_peer_id):
		return

	_apply_player_visibility_confirmations(subject_peer_id, "existing-player-spawn")
	_send_player_spawn_snapshot_to_peer(target_peer_id, subject_peer_id, "existing-player-spawn")


func _send_player_spawn_to_observers(subject_peer_id: int, spawn_position: Vector2, display_name: String, identity_payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if subject_peer_id <= BODY_AUTHORITY:
		return

	var peers := multiplayer.get_peers()
	for target_peer_id in peers:
		if int(target_peer_id) <= BODY_AUTHORITY:
			continue
		if not _can_peer_observe_player(int(target_peer_id), subject_peer_id):
			continue
		spawn_player.rpc_id(int(target_peer_id), subject_peer_id, spawn_position, display_name, identity_payload)


func _send_player_spawn_snapshot_to_peer(target_peer_id: int, subject_peer_id: int, reason: String = "spawn-snapshot") -> void:
	if not multiplayer.is_server():
		return
	if target_peer_id <= BODY_AUTHORITY:
		return
	if subject_peer_id <= 0:
		return
	if not spawned_players.has(subject_peer_id):
		return
	if not _can_peer_observe_player(target_peer_id, subject_peer_id):
		return

	var position := _get_current_player_position_for_peer(subject_peer_id, spawned_players.get(subject_peer_id, Vector2.ZERO))
	spawn_player.rpc_id(
		target_peer_id,
		subject_peer_id,
		position,
		str(player_display_names.get(subject_peer_id, "")),
		player_identity_payloads.get(subject_peer_id, {})
	)
	if debug_enabled:
		print("%s Sent %s Player_%d to peer %d pos=%s" % [
			LOG_PREFIX,
			reason,
			subject_peer_id,
			target_peer_id,
			str(position)
		])


func _sync_local_player_identity_metadata() -> void:
	if world == null:
		return

	var local_player := world.get("player") as Node
	if local_player == null or not is_instance_valid(local_player):
		return

	var peer_id := _get_peer_id_for_player(local_player)
	if peer_id != _get_local_peer_id():
		return

	var identity := _get_local_identity_payload()
	_apply_player_identity(local_player, peer_id, identity)
	if local_player.has_method("set_display_name"):
		local_player.set_display_name(_get_identity_display_name(identity, peer_id))
	_log_phase7_identity(local_player, peer_id, "identity-refresh")


func _mark_player_despawned(player: Node) -> void:
	var rollback_synchronizer := player.get_node_or_null("RollbackSynchronizer")
	if rollback_synchronizer != null and rollback_synchronizer.has_method("despawn"):
		rollback_synchronizer.despawn()


func _activate_local_player(player_node: Node) -> void:
	world.set("player", player_node)
	spawn_ack_deadline_msec = 0
	if player_node is CanvasItem:
		(player_node as CanvasItem).visible = true

	if world.has_method("ensure_player_draw_on_top"):
		world.ensure_player_draw_on_top()
	_configure_player_draw_order(player_node, int(player_node.get("owning_peer_id")) if player_node.get("owning_peer_id") != null else _get_local_peer_id())
	if world.has_method("update_username_label"):
		world.update_username_label()

	var chat_ui = world.get("chat_ui") if world.get("chat_ui") != null else null
	if chat_ui != null and chat_ui.has_method("set_player"):
		chat_ui.set_player(player_node)

	print("%s Local active player scene=netfox_player path=%s websocket_movement_disabled=%s." % [
		LOG_PREFIX,
		player_node.get_path(),
		str(not MovementMode.is_websocket())
	])


func _sync_trusted_state_bridge(delta: float) -> void:
	state_bridge_timer -= delta
	if state_bridge_timer > 0.0:
		return

	state_bridge_timer = STATE_BRIDGE_INTERVAL_SECONDS
	if world == null:
		return

	var local_player := world.get("player") as Node
	if local_player == null or not is_instance_valid(local_player) or not (local_player is Node2D):
		return

	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_netfox_trusted_player_state"):
		return

	var velocity := Vector2.ZERO
	var raw_velocity = local_player.get("velocity")
	if raw_velocity is Vector2:
		velocity = raw_velocity

	var facing := 1
	var raw_facing = local_player.get("facing_dir")
	if raw_facing != null:
		facing = -1 if int(raw_facing) < 0 else 1

	var world_name := _get_current_world_id()

	var tick := 0
	var raw_tick = local_player.get("rollback_tick_count")
	if raw_tick != null:
		tick = int(raw_tick)

	network.send_netfox_trusted_player_state(
		(local_player as Node2D).global_position,
		velocity,
		facing,
		world_name,
		_get_local_peer_id(),
		tick
	)


func _log_player_authority(player: Node, peer_id: int) -> void:
	var player_input := player.get_node_or_null("PlayerInput")
	var identity := _get_player_identity(player, peer_id)
	print("%s player=%s path=%s peer_id=%d websocket_player_id=%s account_id=%s profile_id=%s game_player_id=%s username=%s world_id=%s is_local_player=%s body_authority=%d input_authority=%d mode=%s." % [
		LOG_PREFIX,
		player.name,
		player.get_path(),
		peer_id,
		str(identity.get("websocket_player_id", "")),
		str(identity.get("account_id", "")),
		str(identity.get("profile_id", "")),
		str(identity.get("game_player_id", "")),
		str(identity.get("username", "")),
		str(identity.get("world_id", "")),
		str(peer_id == _get_local_peer_id()),
		player.get_multiplayer_authority(),
		player_input.get_multiplayer_authority() if player_input != null else -1,
		MovementMode.get_mode_name()
	])


func _get_spawn_position(_peer_id: int) -> Vector2:
	if world != null and world.has_method("get_entrance_gate_spawn_position"):
		var entrance_position: Vector2 = world.get_entrance_gate_spawn_position()
		if is_finite(entrance_position.x) and is_finite(entrance_position.y):
			return entrance_position

	return Vector2(INF, INF)


func _has_valid_entrance_spawn_position() -> bool:
	var spawn_position := _get_spawn_position(_get_local_peer_id())
	return is_finite(spawn_position.x) and is_finite(spawn_position.y)


func _get_local_peer_id() -> int:
	if not is_inside_tree():
		return BODY_AUTHORITY
	var api := get_multiplayer()
	if api == null:
		return BODY_AUTHORITY
	var peer := api.multiplayer_peer
	if peer == null:
		return BODY_AUTHORITY
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return BODY_AUTHORITY
	return api.get_unique_id()


func _is_multiplayer_connected() -> bool:
	if not is_inside_tree():
		return false
	var api := get_multiplayer()
	if api == null:
		return false
	var peer := api.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _log_netfox_startup_timing_deferred(reason: String) -> void:
	for _i in range(12):
		await get_tree().process_frame
		if mode == "server" and NetworkTime.is_initial_sync_done():
			break
		if mode != "server":
			break
	_log_netfox_startup_timing(reason)


func _log_netfox_startup_timing(reason: String) -> void:
	if startup_timing_logged:
		return

	startup_timing_logged = true
	var rollback_history_limit := int(ProjectSettings.get_setting("netfox/rollback/history_limit", NETFOX_ROLLBACK_HISTORY_LIMIT))
	var state_history_limit := int(ProjectSettings.get_setting("netfox/state_synchronizer/history_limit", rollback_history_limit))
	var tickrate := int(ProjectSettings.get_setting("netfox/time/tickrate", NetworkTime.tickrate))
	var max_ticks_per_frame := int(ProjectSettings.get_setting("netfox/time/max_ticks_per_frame", NetworkTime.max_ticks_per_frame))
	var sync_to_physics := bool(ProjectSettings.get_setting("netfox/time/sync_to_physics", false))
	var input_delay := int(ProjectSettings.get_setting("netfox/rollback/input_delay", NetworkRollback.input_delay))
	var input_redundancy := int(ProjectSettings.get_setting("netfox/rollback/input_redundancy", NetworkRollback.input_redundancy))
	var input_broadcast := bool(ProjectSettings.get_setting("netfox/rollback/enable_input_broadcast", false))
	var role: String = "server" if multiplayer.is_server() else mode
	var peer_id := _get_local_peer_id()

	print("%s startup reason=%s movement_mode=%s role=%s peer=%d rollback_history_limit=%d actual_rollback_history=%d input_history_limit=%d state_sync_history_limit=%d network_tick_rate=%d actual_network_tick_rate=%d physics_tick_rate=%d max_ticks_per_frame=%d input_delay=%d input_redundancy=%d input_broadcast=%s sync_to_physics=%s network_time_synced=%s world_collision_ready=%s world_blocks=%d websocket_movement_disabled=%s" % [
		LOG_PREFIX,
		reason,
		MovementMode.get_mode_name(),
		role,
		peer_id,
		rollback_history_limit,
		NetworkRollback.history_limit,
		NetworkRollback.history_limit,
		state_history_limit,
		tickrate,
		NetworkTime.tickrate,
		Engine.physics_ticks_per_second,
		max_ticks_per_frame,
		input_delay,
		input_redundancy,
		str(input_broadcast),
		str(sync_to_physics),
		str(NetworkTime.is_initial_sync_done()),
		str(_is_world_collision_ready()),
		_get_world_block_count(),
		str(not MovementMode.is_websocket())
	])


func _get_game_player_id() -> String:
	var network := get_node_or_null("/root/NetworkManager")
	if network == null:
		return ""

	if network.has_method("get_active_game_player_id"):
		return str(network.get_active_game_player_id()).strip_edges()

	var raw_player_id = network.get("player_id")
	return str(raw_player_id).strip_edges()


func _get_local_display_name() -> String:
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_active_session_username"):
		var session_name := str(network.get_active_session_username()).strip_edges()
		if session_name != "":
			return session_name

	if world != null and world.has_method("get_current_profile_name"):
		var profile_name := str(world.get_current_profile_name()).strip_edges()
		if profile_name != "":
			return profile_name

	return _sanitize_display_name("", _get_local_peer_id())


func _get_local_identity_payload() -> Dictionary:
	var peer_id := _get_local_peer_id()
	var world_name := _get_current_world_id()

	var payload := {
		"peer_id": peer_id,
		"display_name": _get_local_display_name(),
		"username": _get_local_display_name(),
		"account_username": _get_local_display_name(),
		"websocket_player_id": "",
		"game_player_id": "",
		"account_id": "",
		"profile_id": "",
		"world_id": world_name,
		"world": world_name,
		"backend_authenticated": false,
		"is_local_player": true
	}

	var network := get_node_or_null("/root/NetworkManager")
	if network != null:
		var identity = {}
		if network.has_method("get_active_identity_payload"):
			identity = network.get_active_identity_payload(world_name)
		if identity is Dictionary:
			for key in identity.keys():
				payload[key] = identity[key]
		if str(payload.get("username", "")).strip_edges() == "" and network.has_method("get_active_session_username"):
			payload["username"] = str(network.get_active_session_username()).strip_edges()
		if str(payload.get("display_name", "")).strip_edges() == "":
			payload["display_name"] = str(payload.get("username", "")).strip_edges()

	var route: Dictionary = _get_backend_netfox_spawn_route(world_name)
	if not route.is_empty():
		payload["netfox_spawn_ticket"] = str(route.get("ticket", "")).strip_edges()
		payload["netfox_ticket_expires_at_ms"] = int(route.get("ticket_expires_at_ms", 0))
		payload["netfox_route_host"] = str(route.get("host", "")).strip_edges()
		payload["netfox_route_port"] = int(route.get("port", 0))

	payload["peer_id"] = peer_id
	payload["is_local_player"] = true
	return _sanitize_identity_payload(payload, peer_id)


func _sanitize_identity_payload(identity_payload, peer_id: int) -> Dictionary:
	var source: Dictionary = {}
	if identity_payload is Dictionary:
		source = identity_payload
	var username := _sanitize_display_name(str(source.get("username", source.get("account_username", source.get("display_name", "")))), peer_id)
	var display_name := _sanitize_display_name(str(source.get("display_name", username)), peer_id)
	var world_id := str(source.get("world_id", source.get("world", ""))).strip_edges().to_upper()
	var fallback_world_id := _get_server_authoritative_world_id() if mode == "server" else _get_current_world_id()
	if fallback_world_id != "" and (world_id == "" or (world_id == "START" and fallback_world_id != "START")):
		world_id = fallback_world_id
	return {
		"peer_id": peer_id,
		"display_name": display_name,
		"username": username,
		"account_username": username,
		"websocket_player_id": _sanitize_identity_id(str(source.get("websocket_player_id", ""))),
		"game_player_id": _sanitize_identity_id(str(source.get("game_player_id", ""))),
		"account_id": _sanitize_identity_id(str(source.get("account_id", ""))),
		"profile_id": _sanitize_identity_id(str(source.get("profile_id", ""))),
		"world_id": world_id,
		"world": world_id,
		"backend_authenticated": bool(source.get("backend_authenticated", false)),
		"netfox_spawn_ticket": str(source.get("netfox_spawn_ticket", "")).strip_edges().substr(0, 4096),
		"netfox_ticket_expires_at_ms": int(source.get("netfox_ticket_expires_at_ms", 0)),
		"netfox_route_host": str(source.get("netfox_route_host", "")).strip_edges().substr(0, 255),
		"netfox_route_port": int(source.get("netfox_route_port", 0)),
		"netfox_spawn_ticket_verified": bool(source.get("netfox_spawn_ticket_verified", false)),
		"netfox_ticket_id": _sanitize_identity_id(str(source.get("netfox_ticket_id", ""))),
		"is_local_player": peer_id == _get_local_peer_id()
	}


func _sanitize_identity_id(raw_value: String) -> String:
	var clean := raw_value.strip_edges()
	if clean.length() > 96:
		clean = clean.substr(0, 96)
	return clean


func _get_identity_display_name(identity: Dictionary, peer_id: int) -> String:
	var display_name := str(identity.get("display_name", "")).strip_edges()
	if display_name == "":
		display_name = str(identity.get("username", identity.get("account_username", ""))).strip_edges()
	return _sanitize_display_name(display_name, peer_id)


func _apply_player_identity(player: Node, peer_id: int, identity_payload: Dictionary) -> void:
	if player == null:
		return

	var clean_identity := _sanitize_identity_payload(identity_payload, peer_id)
	var display_name := _get_identity_display_name(clean_identity, peer_id)
	clean_identity["display_name"] = display_name
	player.set_meta("netfox_peer_id", peer_id)
	player.set_meta("netfox_identity", clean_identity)
	player.set_meta("netfox_display_name", display_name)
	player.set_meta("websocket_player_id", str(clean_identity.get("websocket_player_id", "")))
	player.set_meta("game_player_id", str(clean_identity.get("game_player_id", "")))
	player.set_meta("account_id", str(clean_identity.get("account_id", "")))
	player.set_meta("profile_id", str(clean_identity.get("profile_id", "")))
	player.set_meta("username", str(clean_identity.get("username", "")))
	player.set_meta("world_id", str(clean_identity.get("world_id", "")))
	player.set_meta("is_local_player", peer_id == _get_local_peer_id())
	player_identity_payloads[peer_id] = clean_identity
	player_display_names[peer_id] = display_name


func _get_player_identity(player: Node, peer_id: int) -> Dictionary:
	if player != null and player.has_meta("netfox_identity"):
		var identity = player.get_meta("netfox_identity")
		if identity is Dictionary:
			return _sanitize_identity_payload(identity, peer_id)
	if player_identity_payloads.has(peer_id):
		return _sanitize_identity_payload(player_identity_payloads.get(peer_id, {}), peer_id)
	return _sanitize_identity_payload({}, peer_id)


func _log_phase7_identity(player: Node, peer_id: int, reason: String) -> void:
	if not phase7_identity_debug_enabled:
		return
	if player == null or not is_instance_valid(player):
		return

	var identity := _get_player_identity(player, peer_id)
	var username := str(identity.get("username", identity.get("display_name", ""))).strip_edges()
	var account_id := str(identity.get("account_id", "")).strip_edges()
	var profile_id := str(identity.get("profile_id", "")).strip_edges()
	var game_player_id := str(identity.get("game_player_id", "")).strip_edges()
	var websocket_session := str(identity.get("websocket_player_id", "")).strip_edges()
	var world_id := str(identity.get("world_id", identity.get("world", _get_current_world_id()))).strip_edges().to_upper()
	var node_path := str(player.get_path())
	var log_key := "%d|%s|%s" % [peer_id, game_player_id, node_path]
	if phase7_identity_logged_keys.has(log_key):
		return

	phase7_identity_logged_keys[log_key] = true
	print("%s username=%s account_id=%s profile_id=%s game_player_id=%s websocket_session=%s world=%s peer=%d node=%s local=%s reason=%s" % [
		PHASE7_IDENTITY_LOG_PREFIX,
		username,
		account_id,
		profile_id,
		game_player_id,
		websocket_session,
		world_id,
		peer_id,
		node_path,
		str(peer_id == _get_local_peer_id()),
		reason
	])


func _audit_phase7_identity_mapping(reason: String) -> void:
	if not phase7_identity_debug_enabled or players_root == null:
		return

	var player_count := 0
	var peer_counts := {}
	var game_player_id_counts := {}
	for child in players_root.get_children():
		if not _is_audit_netfox_player(child):
			continue

		var peer_id := _get_audit_peer_id(child)
		var identity := _get_player_identity(child, peer_id)
		var game_player_id := str(identity.get("game_player_id", "")).strip_edges()
		player_count += 1
		peer_counts[peer_id] = int(peer_counts.get(peer_id, 0)) + 1
		if game_player_id != "":
			game_player_id_counts[game_player_id] = int(game_player_id_counts.get(game_player_id, 0)) + 1

	var duplicate_peers := _get_duplicate_identity_keys(peer_counts)
	var duplicate_game_player_ids := _get_duplicate_identity_keys(game_player_id_counts)
	print("%s audit reason=%s players=%d unique_peers=%d unique_game_player_ids=%d duplicate_peers=%s duplicate_game_player_ids=%s" % [
		PHASE7_IDENTITY_LOG_PREFIX,
		reason,
		player_count,
		peer_counts.size(),
		game_player_id_counts.size(),
		str(duplicate_peers),
		str(duplicate_game_player_ids)
	])


func _get_duplicate_identity_keys(counts: Dictionary) -> Array:
	var duplicate_keys: Array = []
	for key in counts.keys():
		if int(counts.get(key, 0)) > 1:
			duplicate_keys.append(key)
	return duplicate_keys


func _clear_phase7_identity_log_for_peer(peer_id: int) -> void:
	var peer_prefix := "%d|" % peer_id
	var keys_to_clear: Array = []
	for key in phase7_identity_logged_keys.keys():
		if str(key).begins_with(peer_prefix):
			keys_to_clear.append(key)
	for key in keys_to_clear:
		phase7_identity_logged_keys.erase(key)


func _sanitize_display_name(raw_display_name: String, peer_id: int) -> String:
	var clean_name := raw_display_name.strip_edges()
	if clean_name == "":
		clean_name = "Peer %d" % peer_id
	if clean_name.length() > 24:
		clean_name = clean_name.substr(0, 24)
	return clean_name


func _setup_debug_overlay() -> void:
	if not debug_enabled or world == null:
		return

	var ui_layer = world.get("ui_layer")
	if ui_layer == null or not (ui_layer is Node):
		return

	debug_label = Label.new()
	debug_label.name = "NetfoxRealDebugLabel"
	debug_label.position = Vector2(20, 140)
	debug_label.z_index = 4095
	(ui_layer as Node).add_child(debug_label)
	_update_debug_overlay()


func _update_debug_overlay() -> void:
	if debug_label == null or not is_instance_valid(debug_label):
		return

	var local_player: Node = null
	if world != null:
		local_player = world.get("player") as Node
	var player_path := "none"
	var body_authority := -1
	var input_authority := -1
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var floor_text := "false"
	var under_block := "air"
	var facing_dir := 0
	var movement_state := "none"
	var action_state := "none"
	var visual_scale_x := 0.0
	var camera_enabled := false
	var ownership_label := "none"
	if local_player != null:
		player_path = str(local_player.get_path())
		body_authority = local_player.get_multiplayer_authority()
		var player_input: Node = local_player.get_node_or_null("PlayerInput")
		input_authority = player_input.get_multiplayer_authority() if player_input != null else -1
		facing_dir = int(local_player.get("facing_dir")) if local_player.get("facing_dir") != null else 0
		movement_state = str(local_player.get("movement_state")) if local_player.get("movement_state") != null else "none"
		action_state = str(local_player.get("action_state")) if local_player.get("action_state") != null else "none"
		var player_visual := local_player.get_node_or_null("PlayerVisual") as Node2D
		visual_scale_x = player_visual.scale.x if player_visual != null else 0.0
		if local_player.has_method("get_local_peer_id") and int(local_player.call("get_local_peer_id")) == int(local_player.get("owning_peer_id")):
			ownership_label = "local"
		else:
			ownership_label = "remote"
		var camera := local_player.get_node_or_null("Camera2D") as Camera2D
		camera_enabled = bool(camera.enabled) if camera != null else false
		if local_player is Node2D:
			position = Vector2(roundf((local_player as Node2D).global_position.x), roundf((local_player as Node2D).global_position.y))
			under_block = _get_block_type_under_position((local_player as Node2D).global_position)
		var raw_velocity = local_player.get("velocity")
		if raw_velocity is Vector2:
			velocity = Vector2(roundf(raw_velocity.x), roundf(raw_velocity.y))
		if local_player.has_method("is_on_floor"):
			floor_text = str(local_player.is_on_floor())

	debug_label.text = "NETFOX_REAL\nmode %s peer %d %s ws_movement_disabled %s\nworld %s player %s\nbody %d input %d cam %s\nface %d visual %.1f state %s action %s\npos %s vel %s floor %s under %s" % [
		mode,
		_get_local_peer_id(),
		ownership_label,
		str(not MovementMode.is_websocket()),
		str(world.get("current_world_name")) if world != null else "",
		player_path,
		body_authority,
		input_authority,
		str(camera_enabled),
		facing_dir,
		visual_scale_x,
		movement_state,
		action_state,
		position,
		velocity,
		floor_text,
		under_block
	]


func audit_player_nodes(reason: String = "manual") -> void:
	_audit_player_nodes(reason)


func _audit_player_nodes(reason: String) -> void:
	if not player_audit_enabled:
		return

	var candidates := _get_player_audit_candidates()
	var netfox_visible_by_peer := {}
	print("%s Player node audit reason=%s count=%d mode=%s local_peer=%d" % [
		LOG_PREFIX,
		reason,
		candidates.size(),
		MovementMode.get_mode_name(),
		_get_local_peer_id()
	])

	for node in candidates:
		if node == null or not is_instance_valid(node):
			continue

		var peer_id := _get_audit_peer_id(node)
		var is_netfox_player := _is_audit_netfox_player(node)
		var is_websocket_proxy := _is_audit_websocket_proxy(node)
		var visible_text := _get_audit_visible_text(node)
		var position_text := _get_audit_position_text(node)
		var parent_path: String = str(node.get_parent().get_path()) if node.get_parent() != null else "none"
		if is_netfox_player and _is_audit_visible(node):
			netfox_visible_by_peer[peer_id] = int(netfox_visible_by_peer.get(peer_id, 0)) + 1

		print("%s audit node path=%s player_id=%s peer_id=%d is_netfox_player=%s is_websocket_proxy=%s visible=%s position=%s parent=%s" % [
			LOG_PREFIX,
			node.get_path(),
			_get_audit_player_id(node),
			peer_id,
			str(is_netfox_player),
			str(is_websocket_proxy),
			visible_text,
			position_text,
			parent_path
		])

	print("%s audit visible_netfox_players_by_peer=%s websocket_remote_players_active=false" % [
		LOG_PREFIX,
		str(netfox_visible_by_peer)
	])


func _get_player_audit_candidates() -> Array:
	var candidates: Array = []
	var seen := {}
	var main_root: Node = null
	if world != null:
		main_root = world.get_parent()
	_append_audit_candidate(candidates, seen, main_root.get_node_or_null(WEBSOCKET_PLAYER_NAME) if main_root != null else null)
	_append_audit_candidate(candidates, seen, main_root.get_node_or_null(PLAYERS_ROOT_NAME) if main_root != null else null)

	if players_root != null:
		for child in players_root.get_children():
			_append_audit_candidate(candidates, seen, child)
			_append_audit_candidate(candidates, seen, child.get_node_or_null("PlayerVisual"))
			_append_audit_candidate(candidates, seen, child.get_node_or_null("PlayerWorldFadeFX"))

	if world != null:
		var remote_players_root := world.get_node_or_null("RemotePlayers")
		_append_audit_candidate(candidates, seen, remote_players_root)
		if remote_players_root != null:
			for child in remote_players_root.get_children():
				_append_audit_candidate(candidates, seen, child)

		for child in world.get_children():
			var child_name := str(child.name)
			if child_name.begins_with("RemotePlayer_") or child_name.begins_with("RemoteFishingBobber_") or child_name == "PlayerWorldFadeFX":
				_append_audit_candidate(candidates, seen, child)

		var ui_audit_layers = []
		var ui_layer = world.get("ui_layer") if world.get("ui_layer") != null else null
		if ui_layer is Node:
			ui_audit_layers.append(ui_layer)
		var overhead_layer = get_overhead_layer()
		if overhead_layer is Node and not ui_audit_layers.has(overhead_layer):
			ui_audit_layers.append(overhead_layer)
		for audit_layer in ui_audit_layers:
			for child in (audit_layer as Node).get_children():
				var child_name := str(child.name)
				if child_name.begins_with("RemoteUsernameLabel_") or child_name.begins_with("RemoteChatBubbleUI_") or child_name.begins_with("RemoteChatBubble_") or child_name.begins_with("NetfoxChatBubbleUI_"):
					_append_audit_candidate(candidates, seen, child)

	return candidates


func _append_audit_candidate(candidates: Array, seen: Dictionary, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	var key := str(node.get_path())
	if seen.has(key):
		return

	seen[key] = true
	candidates.append(node)


func _get_audit_player_id(node: Node) -> String:
	if node == null:
		return ""
	if node.has_meta("websocket_player_id"):
		var websocket_id := str(node.get_meta("websocket_player_id", "")).strip_edges()
		if websocket_id != "":
			return websocket_id
	if node.has_meta("game_player_id"):
		var game_id := str(node.get_meta("game_player_id", "")).strip_edges()
		if game_id != "":
			return game_id
	if node.has_meta("remote_id"):
		return str(node.get_meta("remote_id", ""))
	if node.has_meta("netfox_display_name"):
		return str(node.get_meta("netfox_display_name", ""))
	return ""


func _get_audit_peer_id(node: Node) -> int:
	if node == null:
		return 0

	var raw_peer = node.get("owning_peer_id")
	if raw_peer != null:
		return int(raw_peer)

	if node.has_meta("netfox_peer_id"):
		return int(node.get_meta("netfox_peer_id", 0))

	return _peer_id_from_player_name(str(node.name))


func _is_audit_netfox_player(node: Node) -> bool:
	if node == null:
		return false

	var script = node.get_script()
	if script is Script and str((script as Script).resource_path) == "res://Scripts/player/netfox_player_controller.gd":
		return true

	if node.has_meta("netfox_peer_id"):
		return true

	return node.get_parent() == players_root and str(node.name).begins_with("Player_")


func _is_audit_websocket_proxy(node: Node) -> bool:
	if node == null:
		return false

	var node_name := str(node.name)
	if node_name == WEBSOCKET_PLAYER_NAME or node_name.begins_with("RemotePlayer_"):
		return true

	var parent := node.get_parent()
	while parent != null:
		if str(parent.name) == "RemotePlayers":
			return true
		parent = parent.get_parent()

	return false


func _is_audit_visible(node: Node) -> bool:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		return canvas_item.visible and canvas_item.is_visible_in_tree()
	return true


func _get_audit_visible_text(node: Node) -> String:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		return "%s/tree=%s" % [str(canvas_item.visible), str(canvas_item.is_visible_in_tree())]
	return "not_canvas"


func _get_audit_position_text(node: Node) -> String:
	if node is Node2D:
		var node_2d := node as Node2D
		return str(Vector2(roundf(node_2d.global_position.x), roundf(node_2d.global_position.y)))
	return "n/a"


func _get_block_type_under_position(world_position: Vector2) -> String:
	if world == null:
		return "air"

	var block_size: float = float(world.get("BLOCK_SIZE")) if world.get("BLOCK_SIZE") != null else 32.0
	var grid_pos := Vector2i(
		int(round(world_position.x / block_size)),
		int(floor((world_position.y + 33.0) / block_size))
	)
	var blocks = world.get("blocks")
	if blocks is Dictionary and blocks.has(grid_pos):
		var block_data = blocks[grid_pos]
		if block_data is Dictionary:
			return str(block_data.get("type", "solid"))
		return "solid"

	var block_manager = world.get("block_manager")
	if block_manager != null:
		var background_blocks = block_manager.get("background_blocks")
		if background_blocks is Dictionary and background_blocks.has(grid_pos):
			var background_data = background_blocks[grid_pos]
			if background_data is Dictionary:
				return "background:" + str(background_data.get("type", "background"))
			return "background"

	return "air"


func show_remote_chat_bubble(remote_id: String, message: String, remote_name: String = "") -> void:
	if world == null or players_root == null:
		return

	var clean_message := message.strip_edges()
	if clean_message == "":
		return

	var remote_player := _find_netfox_chat_player(remote_id, remote_name)
	if remote_player == null:
		return

	var chat_key := _get_netfox_chat_key(remote_player, remote_id, remote_name)
	var bubble = netfox_chat_bubbles.get(chat_key, null)
	if bubble == null or not is_instance_valid(bubble):
		bubble = _create_netfox_chat_bubble(chat_key, remote_player)
		if bubble == null:
			return
		netfox_chat_bubbles[chat_key] = bubble

	if not bubble.has_method("show_chat_message"):
		return

	bubble.show_chat_message(clean_message)
	_position_netfox_chat_bubble(chat_key)


func _find_netfox_chat_player(remote_id: String, remote_name: String = "") -> Node2D:
	if players_root == null:
		return null

	var clean_id := remote_id.strip_edges()
	if clean_id.is_valid_int():
		var by_peer := players_root.get_node_or_null("Player_%d" % int(clean_id)) as Node2D
		if by_peer != null and is_instance_valid(by_peer):
			return by_peer

	var clean_name := remote_name.strip_edges().to_lower()
	if clean_name == "":
		clean_name = clean_id.to_lower()
	if clean_name == "":
		return null

	for child in players_root.get_children():
		var player := child as Node2D
		if player == null or not is_instance_valid(player):
			continue

		var display_name := _get_netfox_player_display_name(player).to_lower()
		if display_name != "" and display_name == clean_name:
			return player

	return null


func _get_netfox_chat_key(remote_player: Node2D, remote_id: String, remote_name: String = "") -> String:
	var peer_id := _get_peer_id_for_player(remote_player)
	if peer_id > 0:
		return "peer_%d" % peer_id

	var clean_id := remote_id.strip_edges()
	if clean_id != "":
		return "id_" + _sanitize_node_name_fragment(clean_id)

	return "name_" + _sanitize_node_name_fragment(remote_name.strip_edges())


func _create_netfox_chat_bubble(chat_key: String, remote_player: Node2D):
	var ui_layer = get_overhead_layer()
	if not (ui_layer is Node):
		return null

	var bubble_name := "NetfoxChatBubbleUI_" + _sanitize_node_name_fragment(chat_key).substr(0, 32)
	var cleanup_layers = [ui_layer]
	var root_ui_layer = world.get("ui_layer") if world != null and world.get("ui_layer") != null else null
	if root_ui_layer is Node and root_ui_layer != ui_layer:
		cleanup_layers.append(root_ui_layer)
	for cleanup_layer in cleanup_layers:
		for child in (cleanup_layer as Node).get_children():
			if child != null and str(child.name) == bubble_name:
				child.queue_free()

	var bubble = CHAT_BUBBLE_COMPONENT.new()
	bubble.name = bubble_name
	bubble.visible = false
	bubble.set_meta("netfox_peer_id", _get_peer_id_for_player(remote_player))
	(ui_layer as Node).add_child(bubble)
	return bubble


func _update_netfox_chat_bubbles() -> void:
	if netfox_chat_bubbles.is_empty():
		return

	var cleanup_keys: Array = []
	for chat_key in netfox_chat_bubbles.keys():
		var bubble = netfox_chat_bubbles[chat_key]
		if bubble == null or not is_instance_valid(bubble):
			cleanup_keys.append(chat_key)
			continue
		if not bubble.visible:
			continue
		_position_netfox_chat_bubble(str(chat_key))

	for chat_key in cleanup_keys:
		netfox_chat_bubbles.erase(chat_key)


func _position_netfox_chat_bubble(chat_key: String) -> void:
	if not netfox_chat_bubbles.has(chat_key):
		return

	var bubble = netfox_chat_bubbles[chat_key]
	if bubble == null or not is_instance_valid(bubble):
		return

	var peer_id := int(bubble.get_meta("netfox_peer_id", 0))
	if peer_id <= 0 or players_root == null:
		return

	var remote_player := players_root.get_node_or_null("Player_%d" % peer_id) as Node2D
	if remote_player == null or not is_instance_valid(remote_player):
		bubble.visible = false
		return

	if bubble.size.x <= 0.0 or bubble.size.y <= 0.0:
		return

	var anchor_screen_pos := _get_netfox_chat_anchor_screen_position(remote_player)
	var bubble_position := Vector2(
		round(anchor_screen_pos.x - bubble.size.x / 2.0),
		round(anchor_screen_pos.y - bubble.size.y)
	)
	bubble.position = CHAT_BUBBLE_COMPONENT.clamp_screen_position(
		bubble_position,
		bubble.size,
		bubble.get_viewport()
	)


func _get_netfox_chat_anchor_screen_position(remote_player: Node2D) -> Vector2:
	var viewport := get_viewport()
	if viewport == null or remote_player == null or not is_instance_valid(remote_player):
		return Vector2.ZERO

	var username_label = remote_player.get_node_or_null("UsernameLabel")
	if username_label is Control:
		var label_top_center_world: Vector2 = username_label.global_position + Vector2(username_label.size.x * 0.5, 0.0)
		var label_anchor_screen: Vector2 = CHAT_BUBBLE_COMPONENT.world_to_screen_position(viewport, label_top_center_world)
		label_anchor_screen.y -= CHAT_BUBBLE_COMPONENT.get_username_gap_screen_px()
		return label_anchor_screen

	var anchor := remote_player.get_node_or_null("ChatBubbleAnchor")
	var anchor_world_position := remote_player.global_position + Vector2(0.0, -CHAT_BUBBLE_COMPONENT.get_anchor_offset_world_px())
	if anchor is Node2D:
		anchor_world_position = (anchor as Node2D).global_position

	return CHAT_BUBBLE_COMPONENT.world_to_screen_position(viewport, anchor_world_position)


func _clear_netfox_chat_bubble_for_peer(peer_id: int) -> void:
	var cleanup_keys: Array = []
	for chat_key in netfox_chat_bubbles.keys():
		var bubble = netfox_chat_bubbles[chat_key]
		if bubble != null and is_instance_valid(bubble) and int(bubble.get_meta("netfox_peer_id", 0)) == peer_id:
			bubble.queue_free()
			cleanup_keys.append(chat_key)

	for chat_key in cleanup_keys:
		netfox_chat_bubbles.erase(chat_key)


func _clear_netfox_chat_bubbles() -> void:
	for bubble in netfox_chat_bubbles.values():
		if bubble != null and is_instance_valid(bubble):
			bubble.queue_free()
	netfox_chat_bubbles.clear()


func _get_netfox_player_display_name(player: Node) -> String:
	if player == null:
		return ""

	var peer_id := _get_peer_id_for_player(player)
	var display_name := str(player_display_names.get(peer_id, player.get_meta("netfox_display_name", ""))).strip_edges()
	if display_name != "":
		return display_name

	var raw_display = player.get("display_name")
	if raw_display != null:
		display_name = str(raw_display).strip_edges()
		if display_name != "":
			return display_name

	return ""


func _get_peer_id_for_player(player: Node) -> int:
	if player == null:
		return 0

	var raw_peer = player.get("owning_peer_id")
	if raw_peer != null:
		return int(raw_peer)

	if player.has_meta("netfox_peer_id"):
		return int(player.get_meta("netfox_peer_id", 0))

	return _peer_id_from_player_name(str(player.name))


func _sanitize_node_name_fragment(value: String) -> String:
	var clean := value.strip_edges()
	var result := ""
	for index in range(clean.length()):
		var character := clean.substr(index, 1)
		var code := clean.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		result += character if is_digit or is_upper or is_lower else "_"

	if result == "":
		return "unknown"
	return result


func request_player_punch_at_grid(grid_pos: Vector2i) -> bool:
	if world == null or world.get("player") == null:
		return false
	if world.has_method("is_grid_inside_world") and not world.is_grid_inside_world(grid_pos):
		return false
	if world.has_method("can_reach_grid") and not world.can_reach_grid(grid_pos):
		return false

	var block_size := _get_world_block_size()
	var target_position := Vector2(float(grid_pos.x) * block_size, float(grid_pos.y) * block_size)
	var target_data := get_remote_player_near_world_position(
		target_position,
		PLAYER_PUNCH_GRID_HORIZONTAL_TOLERANCE,
		PLAYER_PUNCH_GRID_VERTICAL_TOLERANCE,
		true
	)
	if target_data.is_empty():
		return false

	return send_player_punch_request(target_data)


func request_player_punch_at_screen_position(screen_pos: Vector2) -> bool:
	if world == null or world.get("player") == null:
		return false

	var target_data := get_remote_player_at_screen_position(screen_pos)
	if target_data.is_empty():
		return false

	return send_player_punch_request(target_data)


func get_remote_player_at_screen_position(screen_pos: Vector2) -> Dictionary:
	if world == null or players_root == null:
		return {}

	var world_position := _screen_to_world_position(screen_pos)
	return get_remote_player_near_world_position(world_position, 28.0, 56.0, false)


func get_remote_player_in_interaction_range() -> Dictionary:
	if world == null or players_root == null:
		return {}

	var local_player := world.get("player") as Node2D
	if local_player == null or not is_instance_valid(local_player):
		return {}

	var facing := 1
	var raw_facing = local_player.get("facing_dir")
	if raw_facing != null:
		facing = -1 if int(raw_facing) < 0 else 1

	var closest_data: Dictionary = {}
	var closest_score := INF
	var interaction_range := _get_world_interaction_range()
	for child in players_root.get_children():
		var remote_player := child as Node2D
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var peer_id: int = int(remote_player.get("owning_peer_id")) if remote_player.get("owning_peer_id") != null else _peer_id_from_player_name(str(remote_player.name))
		if peer_id == _get_local_peer_id():
			continue

		var offset := remote_player.global_position - local_player.global_position
		var direct_distance := local_player.global_position.distance_to(remote_player.global_position)
		var forward_distance := offset.x * float(facing)
		var vertical_distance := absf(offset.y)
		if direct_distance > interaction_range:
			continue
		if forward_distance < -18.0:
			continue
		if vertical_distance > 74.0:
			continue

		var score := direct_distance + vertical_distance * 0.35 - forward_distance * 0.10
		if score >= closest_score:
			continue

		closest_score = score
		closest_data = _get_netfox_remote_player_profile_data(peer_id, remote_player, direct_distance)

	return closest_data


func get_remote_player_profile_by_username(username: String) -> Dictionary:
	if players_root == null:
		return {}

	var clean_username := username.strip_edges().to_lower()
	if clean_username == "":
		return {}

	for child in players_root.get_children():
		var remote_player := child as Node2D
		if remote_player == null or not is_instance_valid(remote_player):
			continue

		var peer_id: int = int(remote_player.get("owning_peer_id")) if remote_player.get("owning_peer_id") != null else _peer_id_from_player_name(str(remote_player.name))
		if peer_id == _get_local_peer_id():
			continue

		var display_name := str(player_display_names.get(peer_id, remote_player.get_meta("netfox_display_name", ""))).strip_edges()
		if display_name.to_lower() == clean_username:
			return _get_netfox_remote_player_profile_data(peer_id, remote_player, 0.0)

	return {}


func get_remote_player_near_world_position(world_position: Vector2, horizontal_tolerance: float, vertical_tolerance: float, require_forward: bool = false) -> Dictionary:
	if world == null or players_root == null:
		return {}

	var local_player := world.get("player") as Node2D
	if local_player == null or not is_instance_valid(local_player):
		return {}

	var facing := _get_local_punch_facing_for_position(world_position)
	var closest_data: Dictionary = {}
	var closest_score := INF
	var interaction_range := _get_world_interaction_range()
	for child in players_root.get_children():
		var remote_player := child as Node2D
		if remote_player == null or not is_instance_valid(remote_player):
			continue
		var peer_id: int = int(remote_player.get("owning_peer_id")) if remote_player.get("owning_peer_id") != null else _peer_id_from_player_name(remote_player.name)
		if peer_id == _get_local_peer_id():
			continue

		var remote_position := remote_player.global_position
		var offset_from_player := remote_position - local_player.global_position
		if require_forward and offset_from_player.x * float(facing) < -10.0:
			continue

		var horizontal_distance := absf(remote_position.x - world_position.x)
		var vertical_distance := absf(remote_position.y - world_position.y)
		if horizontal_distance > horizontal_tolerance or vertical_distance > vertical_tolerance:
			continue

		var direct_distance := local_player.global_position.distance_to(remote_position)
		if direct_distance > interaction_range:
			continue

		var score := horizontal_distance + vertical_distance * 0.55 + direct_distance * 0.08
		if score >= closest_score:
			continue

		closest_score = score
		closest_data = _get_netfox_remote_player_profile_data(peer_id, remote_player, direct_distance)

	return closest_data


func send_player_punch_request(target_data: Dictionary) -> bool:
	if world == null or world.get("player") == null or target_data.is_empty():
		return false

	var target_position := Vector2(
		float(target_data.get("x", 0.0)),
		float(target_data.get("y", 0.0))
	)
	var local_player := world.get("player") as Node2D
	if local_player == null:
		return false
	if local_player.global_position.distance_to(target_position) > _get_world_interaction_range():
		return false

	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_player_punch"):
		return false

	var facing := _get_local_punch_facing_for_position(target_position)
	if world.has_method("set_player_facing_direction"):
		world.set_player_facing_direction(facing, false)
	if str(world.get("equipped_tool")).strip_edges().to_lower() == "ant_sword" and world.has_method("spawn_hand_item_swing_particles"):
		world.spawn_hand_item_swing_particles(target_position, "ant_sword")

	var target_id := str(target_data.get("player_id", "")).strip_edges()
	var target_username := str(target_data.get("username", target_data.get("name", ""))).strip_edges()
	return bool(network.send_player_punch(target_id, target_username, target_position, facing, str(world.get("current_world_name"))))


func _get_netfox_remote_player_profile_data(peer_id: int, remote_player: Node2D, distance: float) -> Dictionary:
	var identity := _get_player_identity(remote_player, peer_id)
	var display_name := str(player_display_names.get(peer_id, identity.get("display_name", remote_player.get_meta("netfox_display_name", "")))).strip_edges()
	if display_name == "":
		display_name = "Peer %d" % peer_id

	return {
		"player_id": str(identity.get("websocket_player_id", identity.get("game_player_id", ""))),
		"game_player_id": str(identity.get("game_player_id", "")),
		"profile_id": str(identity.get("profile_id", "")),
		"account_id": str(identity.get("account_id", "")),
		"netfox_peer_id": peer_id,
		"name": display_name,
		"username": str(identity.get("username", display_name)),
		"account_username": str(identity.get("account_username", identity.get("username", display_name))),
		"x": remote_player.global_position.x,
		"y": remote_player.global_position.y,
		"distance": distance
	}


func _screen_to_world_position(screen_pos: Vector2) -> Vector2:
	if world == null:
		return screen_pos

	var viewport := world.get_viewport()
	if viewport == null:
		return screen_pos

	return viewport.get_canvas_transform().affine_inverse() * screen_pos


func _get_local_punch_facing_for_position(target_position: Vector2) -> int:
	if world == null:
		return 1

	var local_player := world.get("player") as Node2D
	if local_player == null:
		return 1

	var delta_x := target_position.x - local_player.global_position.x
	if absf(delta_x) > 1.0:
		return -1 if delta_x < 0.0 else 1

	var raw_facing = local_player.get("facing_dir")
	if raw_facing != null:
		return -1 if int(raw_facing) < 0 else 1

	return 1


func _get_world_block_size() -> float:
	if world != null and world.get("BLOCK_SIZE") != null:
		return float(world.get("BLOCK_SIZE"))
	return 32.0


func _get_world_origin_text() -> String:
	if world is Node2D:
		var world_node := world as Node2D
		return _format_vector2(world_node.global_position)
	return "n/a"


func _get_chunk_origin_text() -> String:
	if world == null:
		return "n/a"

	var chunk_manager = world.get("chunk_manager")
	if chunk_manager != null:
		var raw_origin = chunk_manager.get("origin")
		if raw_origin is Vector2:
			return _format_vector2(raw_origin)
		if raw_origin is Vector2i:
			return _grid_key_to_text(raw_origin)

	return "n/a"


func _get_world_interaction_range() -> float:
	if world != null and world.get("INTERACTION_PIXEL_RANGE") != null:
		return float(world.get("INTERACTION_PIXEL_RANGE"))
	return 128.0


func _peer_id_from_player_name(player_name: String) -> int:
	var clean_name := player_name.strip_edges()
	if clean_name.begins_with("Player_"):
		return int(clean_name.substr("Player_".length()))
	return 0


func _is_flag_enabled(arg_name: String, env_name: String) -> bool:
	if MovementMode.has_launch_arg(arg_name):
		return true

	var env_value := OS.get_environment(env_name).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)
