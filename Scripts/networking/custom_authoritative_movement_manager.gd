extends Node

const Protocol = preload("res://custom_movement_test/scripts/custom_movement_protocol.gd")
const SnapshotInterpolator = preload("res://custom_movement_test/scripts/custom_snapshot_interpolator.gd")
const RemotePlayerScene = preload("res://custom_movement_test/scenes/custom_real_player.tscn")

const LOCAL_PLAYER_Z_INDEX := 4096
const REMOTE_ROOT_NAME := "Players"
const DEFAULT_PHASE_I_WORLD := "TEST"
const SERVER_WORLD_STATE_DEV_ENDPOINT := "/dev/custom-movement/world-state"
const SERVER_WORLD_STATE_LIVE_ENDPOINT := "/custom-movement/server/world-state"
const SERVER_WORLD_STATE_TOKEN_ARG := "--custom-movement-server-token"
const SERVER_WORLD_STATE_TOKEN_ENV := "CUSTOM_MOVEMENT_SERVER_WORLD_STATE_TOKEN"
const SERVER_WORLD_STATE_TIMEOUT_SECONDS := 30.0
const CEILING_CONTACT_FALL_START_VELOCITY := 24.0
const CEILING_CONTACT_IMPACT_FALL_RATIO := 0.08
const CEILING_CONTACT_MAX_FALL_START_VELOCITY := 36.0
const CEILING_CONTACT_NORMAL_Y_THRESHOLD := 0.35
const CEILING_CORNER_NORMAL_X_THRESHOLD := 0.15
const CEILING_UNSTICK_NUDGE := 1.0
const CEILING_CORNER_UNSTICK_NUDGE := 0.35

var world = null
var players_root: Node2D = null
var is_server := false
var is_client := false
var host := Protocol.ADDRESS
var port := Protocol.PORT
var requested_world_name := DEFAULT_PHASE_I_WORLD
var active_client_world := ""
var debug_enabled := false

var server_tick := 0
var snapshot_timer := 0.0
var server_players: Dictionary = {}
var server_peer_worlds: Dictionary = {}
var server_peer_identities: Dictionary = {}
var server_input_queues: Dictionary = {}
var server_last_processed_input: Dictionary = {}
var server_last_input: Dictionary = {}

var local_peer_id := 0
var client_input_sequence := 0
var client_tick := 0
var last_processed_input := 0
var local_prediction_error := 0.0
var correction_mode := "none"
var local_predicted_position := Vector2.ZERO
var local_predicted_velocity := Vector2.ZERO
var last_server_authoritative_position := Vector2.ZERO
var last_server_authoritative_velocity := Vector2.ZERO
var last_server_tick := 0
var input_history: Dictionary = {}
var client_players: Dictionary = {}
var local_player = null
var interpolator = SnapshotInterpolator.new()
var map_debug_key := ""
var status_debug_key := ""
var collision_debug_key := ""
var last_logged_collision_entries: Array[String] = []
var server_collision_baseline_blocks: Dictionary = {}
var server_collision_baseline_ready := false
var client_ready_acknowledged := false
var last_client_ready_sent_msec := 0


func setup(world_ref) -> void:
	world = world_ref
	if world == null or MovementMode == null or not MovementMode.is_custom_authoritative():
		set_process(false)
		set_physics_process(false)
		return

	name = "CustomAuthoritativeMovementManager"
	_parse_launch_args()
	players_root = _get_or_create_players_root()
	active_client_world = _get_world_name()
	Engine.physics_ticks_per_second = Protocol.PHYSICS_TICK_RATE
	_connect_multiplayer_signals()

	var scene_path := ""
	if get_tree() != null and get_tree().current_scene != null:
		scene_path = str(get_tree().current_scene.scene_file_path)
	if scene_path == "":
		scene_path = "res://Scenes/main.tscn"
	print("[PhaseI] Actual game lifecycle test active scene=%s movement=%s" % [scene_path, MovementMode.get_mode_name()])
	print("[CustomMovementRPC] manager_path=%s role=%s scene=%s" % [
		str(get_path()),
		"server" if is_server else "client" if is_client else "idle",
		scene_path,
	])
	print("[PhaseI] Custom movement config " + Protocol.config_summary())

	if is_server:
		call_deferred("_start_server")
	elif is_client:
		call_deferred("_start_client")


func _process(_delta: float) -> void:
	_poll_custom_multiplayer()
	if is_server:
		_restore_server_collision_baseline_if_needed()
		_log_movement_status_if_changed()
		_log_collision_summary_if_changed()
		return
	if not is_client:
		return
	_ensure_local_player_registered()
	_watch_world_lifecycle()
	_log_phase_i_mapping_if_changed()
	_log_movement_status_if_changed()
	_log_collision_summary_if_changed()
	_retry_client_ready_if_needed()


func _physics_process(delta: float) -> void:
	_poll_custom_multiplayer()
	if is_server:
		_server_physics(delta)
	elif is_client:
		_client_physics(delta)


func _poll_custom_multiplayer() -> void:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.poll()


func _parse_launch_args() -> void:
	var wants_server := MovementMode.has_launch_arg("--server") or MovementMode.has_launch_arg("--custom-movement-server")
	var wants_client := MovementMode.has_launch_arg("--client") or MovementMode.has_launch_arg("--custom-movement-client")
	is_server = wants_server and not wants_client
	is_client = wants_client and not wants_server
	debug_enabled = MovementMode.has_launch_arg("--custom-movement-debug") or MovementMode.has_launch_arg("--phase-i-debug")
	host = MovementMode.get_launch_arg_value("--host", Protocol.ADDRESS)
	port = int(MovementMode.get_launch_arg_value("--port", str(Protocol.PORT)))
	requested_world_name = _safe_world_name(MovementMode.get_launch_arg_value("--world", DEFAULT_PHASE_I_WORLD), DEFAULT_PHASE_I_WORLD)


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
	if multiplayer.has_signal("peer_packet") and not multiplayer.peer_packet.is_connected(_on_peer_packet):
		multiplayer.peer_packet.connect(_on_peer_packet)
	if debug_enabled:
		print("[CustomMovementPacket] peer_packet_signal=%s send_bytes_method=%s" % [
			str(multiplayer.has_signal("peer_packet")),
			str(multiplayer.has_method("send_bytes")),
		])


func _start_server() -> void:
	_prepare_server_world()
	var backend_world_loaded := false
	if _should_load_server_world_state_from_backend():
		backend_world_loaded = await _load_backend_world_state_http_for_server(requested_world_name)
	var world_ready := await _wait_for_server_world_collision_ready(30.0 if backend_world_loaded else 10.0)
	if not world_ready:
		push_error("[PhaseI] Custom movement server refused to start without a loaded Entrance Gate and collision state.")
		return
	_disable_real_player_on_movement_server()
	_capture_server_collision_baseline()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, Protocol.MAX_CLIENTS)
	if error != OK:
		push_error("[PhaseI] Failed to start actual-game custom movement server on port %d: %s" % [port, error])
		return

	multiplayer.multiplayer_peer = peer
	if MovementMode != null and MovementMode.has_method("enforce_netfox_runtime_state"):
		MovementMode.enforce_netfox_runtime_state()
	print("[PhaseI] Actual-game custom movement server started host=%s port=%d world=%s" % [Protocol.ADDRESS, port, _get_world_name()])
	_log_movement_status_if_changed(true)
	_log_collision_summary_if_changed(true)


func _start_client() -> void:
	var world_ready := await _wait_for_client_world_ready()
	if not world_ready:
		push_warning("[Movement] CUSTOM_AUTHORITATIVE client did not connect to ENet because the game world was not ready.")
		return
	_ensure_local_player_registered()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		push_error("[PhaseI] Failed to connect actual-game custom movement client to %s:%d: %s" % [host, port, error])
		return

	multiplayer.multiplayer_peer = peer
	if MovementMode != null and MovementMode.has_method("enforce_netfox_runtime_state"):
		MovementMode.enforce_netfox_runtime_state()
	print("[PhaseI] Actual-game custom movement client connecting host=%s port=%d world=%s" % [host, port, _get_world_name()])
	_log_movement_status_if_changed(true)
	_log_collision_summary_if_changed(true)


func _wait_for_client_world_ready() -> bool:
	while is_inside_tree() and is_client and MovementMode != null and MovementMode.is_custom_authoritative():
		if _is_client_world_ready_for_movement():
			return true
		await get_tree().process_frame
	return false


func _is_client_world_ready_for_movement() -> bool:
	if world == null:
		return false
	if "in_world" in world and not bool(world.get("in_world")):
		return false
	if "applying_network_world_update" in world and bool(world.get("applying_network_world_update")):
		return false
	if bool(world.get_meta("world_entry_in_progress", false)):
		return false
	if bool(world.get_meta("world_bulk_load_in_progress", false)):
		return false
	var save_manager = world.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager and bool(save_manager.get("waiting_for_server_world_state")):
		return false
	var blocks_value = world.get("blocks")
	if not (blocks_value is Dictionary) or blocks_value.size() <= 0:
		return false
	return _has_valid_entrance_spawn_position()


func _prepare_server_world() -> void:
	if world == null:
		return
	world.current_world_name = requested_world_name
	world.in_world = true
	_disable_real_player_on_movement_server()
	if _load_backend_world_state_json_for_server(requested_world_name):
		return
	if world.save_manager != null and world.save_manager.has_method("load_clean_server_world_base"):
		world.save_manager.load_clean_server_world_base()
	elif world.has_method("generate_world"):
		world.clear_world()
		world.generate_world()
		if world.has_method("ensure_entrance_gate"):
			world.ensure_entrance_gate()


func _disable_real_player_on_movement_server() -> void:
	if not is_server or world == null or world.player == null or not is_instance_valid(world.player):
		return
	world.player.visible = false
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_input(false)
	world.player.set_process_unhandled_input(false)
	if world.player is CollisionObject2D:
		var collision_object := world.player as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if world.player is CharacterBody2D:
		(world.player as CharacterBody2D).velocity = Vector2.ZERO


func _capture_server_collision_baseline() -> void:
	server_collision_baseline_blocks.clear()
	server_collision_baseline_ready = false
	if not is_server or world == null:
		return
	var blocks_value = world.get("blocks")
	if not (blocks_value is Dictionary):
		return
	var blocks: Dictionary = blocks_value
	for raw_grid_pos in blocks.keys():
		var grid_pos := _grid_position_from_key(raw_grid_pos)
		var block_data_value = blocks.get(raw_grid_pos, {})
		if block_data_value is Dictionary:
			server_collision_baseline_blocks[grid_pos] = block_data_value.duplicate(true)
	server_collision_baseline_ready = not server_collision_baseline_blocks.is_empty()
	print("[MovementCollision] server_collision_baseline_captured world=%s blocks=%d" % [
		_get_world_name(),
		server_collision_baseline_blocks.size(),
	])


func clear_server_collision_baseline(_reason: String = "world-state-rebuild") -> void:
	if not is_server:
		return
	server_collision_baseline_blocks.clear()
	server_collision_baseline_ready = false
	collision_debug_key = ""


func refresh_server_collision_baseline(_reason: String = "world-state-rebuilt") -> void:
	if not is_server:
		return
	_capture_server_collision_baseline()
	collision_debug_key = ""


func _restore_server_collision_baseline_if_needed() -> void:
	if not is_server or not server_collision_baseline_ready or world == null:
		return
	var blocks_value = world.get("blocks")
	if not (blocks_value is Dictionary):
		return
	var blocks: Dictionary = blocks_value
	var restored := 0
	for grid_pos in server_collision_baseline_blocks.keys():
		if blocks.has(grid_pos):
			continue
		var baseline_data: Dictionary = server_collision_baseline_blocks.get(grid_pos, {})
		var block_type := _block_type_from_data(baseline_data)
		if block_type == "":
			continue
		if world.block_manager != null and world.block_manager.has_method("replace_block_without_drop"):
			world.block_manager.replace_block_without_drop(grid_pos, block_type)
		else:
			blocks[grid_pos] = baseline_data.duplicate(true)
		restored += 1
		if restored >= 8:
			break
	if restored > 0:
		print("[MovementCollision] server_collision_baseline_restored world=%s count=%d" % [_get_world_name(), restored])


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	client_ready_acknowledged = false
	last_client_ready_sent_msec = 0
	_ensure_local_player_registered()
	print("[PhaseI] Client connected to actual-game custom movement server peer=%d world=%s" % [local_peer_id, _get_world_name()])
	_log_movement_status_if_changed(true)
	call_deferred("_send_client_ready_to_server", "connected")


func _on_connection_failed() -> void:
	push_error("[PhaseI] Actual-game custom movement client connection failed.")
	print("[MovementFallback] CUSTOM_AUTHORITATIVE movement connection failed. WebSocket durable systems may stay connected, but WebSocket movement remains disabled in this run. Restart with --websocket-movement to use the emergency fallback.")
	_send_custom_trusted_clear("movement_connection_failed", _get_world_name())


func _on_server_disconnected() -> void:
	print("[PhaseI] Actual-game custom movement server disconnected; clearing client runtime.")
	print("[MovementFallback] CUSTOM_AUTHORITATIVE movement server disconnected. Trusted movement state cleared; restart with --websocket-movement for emergency fallback.")
	_send_custom_trusted_clear("movement_server_disconnected", _get_world_name())
	_clear_client_runtime("server_disconnected")


func _on_peer_connected(peer_id: int) -> void:
	if is_server:
		print("[PhaseI] peer_connected peer=%d" % int(peer_id))


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server:
		return
	var player_path := _server_player_path(peer_id)
	_server_remove_player(peer_id)
	for target_peer_id in multiplayer.get_peers():
		_send_enet_message(int(target_peer_id), {"type": "despawn_player", "peer_id": int(peer_id), "reason": "peer_disconnected"}, true)
	print("[PhaseI] peer_disconnected peer=%d player=%s cleanup=true trusted_state_cleared=true remote_node_removed=true" % [
		int(peer_id),
		player_path,
	])


func _on_peer_packet(peer_id: int, packet_bytes: PackedByteArray) -> void:
	var decoded = bytes_to_var(packet_bytes)
	if not (decoded is Dictionary):
		return
	var message: Dictionary = decoded
	var message_type := str(message.get("type", "")).strip_edges().to_lower()
	if debug_enabled and message_type != "input" and message_type != "snapshot":
		print("[CustomMovementPacket] received role=%s peer=%d type=%s" % [
			"server" if is_server else "client" if is_client else "idle",
			int(peer_id),
			message_type,
		])
	match message_type:
		"client_ready":
			var ready_identity = message.get("identity", {})
			if ready_identity is Dictionary:
				_server_handle_client_ready(int(peer_id), ready_identity)
		"client_world_changed":
			var world_identity = message.get("identity", {})
			if world_identity is Dictionary:
				_server_handle_client_world_changed(int(peer_id), world_identity)
		"input":
			var input_packet = message.get("packet", {})
			if input_packet is Dictionary:
				_server_handle_input(int(peer_id), input_packet)
		"server_world_room_reset":
			client_world_room_reset(str(message.get("world", _get_world_name())))
		"spawn_player":
			var spawn = message.get("spawn", {})
			if spawn is Dictionary:
				client_spawn_player(spawn)
		"despawn_player":
			client_despawn_player(int(message.get("peer_id", 0)), str(message.get("reason", "despawn")))
		"snapshot":
			var snapshot = message.get("snapshot", {})
			if snapshot is Dictionary:
				client_receive_snapshot(snapshot)
		"collision_summary":
			var summary = message.get("summary", {})
			if summary is Dictionary:
				client_receive_collision_summary(summary)


func _send_enet_message(target_peer_id: int, message: Dictionary, reliable: bool = true) -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	var mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	var error: int = multiplayer.send_bytes(var_to_bytes(message), int(target_peer_id), mode)
	var message_type := str(message.get("type", ""))
	if debug_enabled and message_type != "input" and message_type != "snapshot":
		print("[CustomMovementPacket] sent role=%s target=%d type=%s reliable=%s error=%s" % [
			"server" if is_server else "client" if is_client else "idle",
			int(target_peer_id),
			message_type,
			str(reliable),
			str(error),
		])
	if error != OK and (reliable or debug_enabled):
		push_warning("[CustomMovementPacket] send failed target=%d type=%s error=%s" % [
			int(target_peer_id),
			str(message.get("type", "")),
			str(error),
		])
	return error == OK


@rpc("any_peer", "call_remote", "reliable")
func server_client_ready(identity: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_server_handle_client_ready(sender, identity)


func _server_handle_client_ready(sender: int, identity: Dictionary) -> void:
	if not is_server or sender <= 0:
		return
	print("[CustomMovementRPC] server_client_ready received peer=%d world=%s identity_world=%s" % [
		sender,
		_get_world_name(),
		str(identity.get("world", "")),
	])

	var world_name := _safe_world_name(str(identity.get("world", requested_world_name)), requested_world_name)
	_server_set_peer_identity(sender, identity, world_name)
	var new_player = _server_add_player(sender, world_name, true)
	if new_player == null:
		return

	_send_enet_message(sender, {"type": "server_world_room_reset", "world": world_name}, true)
	_send_enet_message(sender, {"type": "collision_summary", "summary": _get_actual_collision_summary()}, true)
	for peer_id in server_players.keys():
		if _server_peer_world(peer_id) != world_name:
			continue
		var spawn_player = server_players[peer_id]
		_send_enet_message(sender, {"type": "spawn_player", "spawn": _make_spawn_payload(int(peer_id), spawn_player, world_name)}, true)
		_send_enet_message(sender, {"type": "snapshot", "snapshot": _make_server_snapshot(int(peer_id), spawn_player)}, false)

	for target_peer_id in multiplayer.get_peers():
		if int(target_peer_id) == sender:
			continue
		if _server_peer_world(int(target_peer_id)) != world_name:
			continue
		_send_enet_message(int(target_peer_id), {"type": "spawn_player", "spawn": _make_spawn_payload(sender, new_player, world_name)}, true)


@rpc("any_peer", "call_remote", "reliable")
func server_client_world_changed(identity: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_server_handle_client_world_changed(sender, identity)


func _server_handle_client_world_changed(sender: int, identity: Dictionary) -> void:
	if not is_server or sender <= 0:
		return

	var old_world := _server_peer_world(sender)
	var new_world := _safe_world_name(str(identity.get("world", requested_world_name)), requested_world_name)
	if new_world == "":
		new_world = requested_world_name
	_server_set_peer_identity(sender, identity, new_world)

	for target_peer_id in multiplayer.get_peers():
		if int(target_peer_id) == sender:
			continue
		if _server_peer_world(int(target_peer_id)) == old_world:
			_send_enet_message(int(target_peer_id), {"type": "despawn_player", "peer_id": sender, "reason": "world_leave"}, true)

	var player = _server_add_player(sender, new_world, true)
	if player == null:
		return
	_send_enet_message(sender, {"type": "server_world_room_reset", "world": new_world}, true)
	_send_enet_message(sender, {"type": "collision_summary", "summary": _get_actual_collision_summary()}, true)
	for peer_id in server_players.keys():
		if _server_peer_world(peer_id) != new_world:
			continue
		var spawn_player = server_players[peer_id]
		_send_enet_message(sender, {"type": "spawn_player", "spawn": _make_spawn_payload(int(peer_id), spawn_player, new_world)}, true)
		_send_enet_message(sender, {"type": "snapshot", "snapshot": _make_server_snapshot(int(peer_id), spawn_player)}, false)

	for target_peer_id in multiplayer.get_peers():
		if int(target_peer_id) == sender:
			continue
		if _server_peer_world(int(target_peer_id)) == new_world:
			_send_enet_message(int(target_peer_id), {"type": "spawn_player", "spawn": _make_spawn_payload(sender, player, new_world)}, true)

	print("[PhaseI] peer_world_changed peer=%d old_world=%s new_world=%s cleanup=true trusted_state_cleared=true" % [sender, old_world, new_world])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func server_receive_input(packet: Dictionary) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_server_handle_input(sender, packet)


func _server_handle_input(sender: int, packet: Dictionary) -> void:
	if not is_server or sender <= 0:
		return
	if not server_players.has(sender):
		_server_add_player(sender, _server_peer_world(sender), true)
	if not server_players.has(sender):
		return

	var clean_packet := Protocol.sanitize_input(packet, sender)
	clean_packet["peer_id"] = sender
	var queue: Array = server_input_queues.get(sender, [])
	queue.append(clean_packet)
	while queue.size() > Protocol.MAX_INPUT_QUEUE_PER_PEER:
		queue.pop_front()
	server_input_queues[sender] = queue


@rpc("authority", "call_remote", "reliable")
func client_world_room_reset(world_name: String) -> void:
	if is_server:
		return
	client_ready_acknowledged = true
	var clean_world := _safe_world_name(world_name, _get_world_name())
	active_client_world = clean_world
	_clear_remote_players("world_room_reset", false)
	interpolator.clear()
	input_history.clear()
	last_processed_input = 0
	local_prediction_error = 0.0
	correction_mode = "none"
	print("[PhaseI] client_world_room_reset world=%s snapshot_buffers_cleared=true remote_nodes_cleared=true" % clean_world)
	_log_movement_status_if_changed(true)


@rpc("authority", "call_remote", "reliable")
func client_spawn_player(spawn: Dictionary) -> void:
	if is_server:
		return
	var peer_id := int(spawn.get("peer_id", 0))
	if peer_id <= 0:
		return
	var spawn_world := _safe_world_name(str(spawn.get("world", _get_world_name())), _get_world_name())
	if spawn_world != _get_world_name():
		return

	var spawn_position: Vector2 = _vector_from_payload(spawn.get("position", Vector2.ZERO))
	var display_name := str(spawn.get("username", "Peer %d" % peer_id)).strip_edges()
	var is_local := peer_id == local_peer_id
	if is_local:
		_ensure_local_player_registered()
		if local_player != null:
			_force_player_state(local_player, spawn_position, Vector2.ZERO, int(spawn.get("facing_dir", 1)), "idle")
			local_predicted_position = spawn_position
			last_server_authoritative_position = spawn_position
			client_players[peer_id] = local_player
			_apply_local_player_draw_order()
			print("[CustomMovementSpawn] local_player peer=%d world=%s node=%s prediction=true camera=true" % [peer_id, spawn_world, str(local_player.get_path())])
			_log_phase_i_mapping_if_changed(true)
		return

	var existing_remote = client_players.get(peer_id, null)
	if existing_remote != null and is_instance_valid(existing_remote):
		_force_player_state(existing_remote, spawn_position, Vector2.ZERO, int(spawn.get("facing_dir", 1)), "idle")
		interpolator.clear_peer(peer_id)
		interpolator.add_snapshot(Protocol.make_snapshot(peer_id, last_server_tick, spawn_position, Vector2.ZERO, int(spawn.get("facing_dir", 1)), "idle", 0))
		print("[CustomMovementSpawn] remote_player_updated peer=%d world=%s node=%s interpolation=true local_input=false" % [peer_id, spawn_world, str(existing_remote.get_path())])
		return

	_remove_remote_player(peer_id, "duplicate_spawn", false)
	var remote_player = RemotePlayerScene.instantiate()
	remote_player.name = "Player_%d" % peer_id
	players_root.add_child(remote_player)
	if remote_player.has_method("setup"):
		remote_player.setup(peer_id, false, false, display_name)
	_force_player_state(remote_player, spawn_position, Vector2.ZERO, int(spawn.get("facing_dir", 1)), "idle")
	client_players[peer_id] = remote_player
	interpolator.clear_peer(peer_id)
	interpolator.add_snapshot(Protocol.make_snapshot(peer_id, last_server_tick, spawn_position, Vector2.ZERO, 1, "idle", 0))
	print("[PhaseIMap] username=%s profile=%s world=%s peer=%d node=%s" % [
		display_name,
		str(spawn.get("profile_id", "")),
		spawn_world,
		peer_id,
		str(remote_player.get_path()),
	])
	print("[CustomMovementSpawn] remote_player peer=%d world=%s node=%s interpolation=true local_input=false" % [peer_id, spawn_world, str(remote_player.get_path())])


@rpc("authority", "call_remote", "reliable")
func client_receive_collision_summary(server_summary: Dictionary) -> void:
	if is_server:
		return
	var local_summary := _get_actual_collision_summary()
	var server_hash := str(server_summary.get("collision_hash", ""))
	var local_hash := str(local_summary.get("collision_hash", ""))
	var server_world := _safe_world_name(str(server_summary.get("world", "")), _get_world_name())
	var local_world := _safe_world_name(str(local_summary.get("world", "")), _get_world_name())
	var hashes_match := server_hash != "" and local_hash != "" and server_hash == local_hash and server_world == local_world
	print("[MovementCollision] world=%s server_blocks=%d client_blocks=%d server_solid=%d client_solid=%d server_hash=%s client_hash=%s revision=%s match=%s" % [
		local_world,
		int(server_summary.get("block_count", 0)),
		int(local_summary.get("block_count", 0)),
		int(server_summary.get("solid_collision_count", 0)),
		int(local_summary.get("solid_collision_count", 0)),
		server_hash,
		local_hash,
		str(local_summary.get("revision", 0)),
		str(hashes_match),
	])
	if not hashes_match:
		push_warning("[MovementCollision] Client/server world collision mismatch. Movement may reject or diverge until both load the same world state.")


@rpc("authority", "call_remote", "reliable")
func client_despawn_player(peer_id: int, reason: String = "despawn") -> void:
	if is_server:
		return
	var remote_removed := _remove_remote_player(peer_id, reason, true)
	interpolator.clear_peer(peer_id)
	if int(peer_id) == local_peer_id:
		_send_custom_trusted_clear(reason, active_client_world)
		input_history.clear()
		last_processed_input = 0
	print("[PhaseI] peer_disconnected peer=%d player=%s cleanup=true trusted_state_cleared=%s remote_node_removed=%s" % [
		int(peer_id),
		"local" if int(peer_id) == local_peer_id else "remote",
		str(int(peer_id) == local_peer_id),
		str(remote_removed),
	])


@rpc("authority", "call_remote", "unreliable_ordered")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if is_server:
		return
	var peer_id := int(snapshot.get("peer_id", 0))
	if peer_id <= 0:
		return
	var snapshot_world := _safe_world_name(str(snapshot.get("world", _get_world_name())), _get_world_name())
	if snapshot_world != _get_world_name():
		return
	if peer_id == local_peer_id:
		_client_reconcile_local_player(snapshot)
		return
	if not client_players.has(peer_id):
		client_spawn_player({
			"peer_id": peer_id,
			"position": Protocol.snapshot_position(snapshot),
			"world": snapshot_world,
			"username": str(snapshot.get("username", "Peer %d" % peer_id)),
			"profile_id": str(snapshot.get("profile_id", "")),
			"facing_dir": int(snapshot.get("facing_dir", 1)),
		})
	interpolator.add_snapshot(snapshot)


func _server_add_player(peer_id: int, world_name: String, reset_position: bool = false):
	var clean_world := _safe_world_name(world_name, requested_world_name)
	var spawn_position := Vector2(INF, INF)
	if reset_position or not server_players.has(peer_id):
		spawn_position = _spawn_position_for_peer(peer_id, clean_world)
		if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
			push_error("[PhaseI] Refused to spawn peer %d without a resolved Entrance Gate position." % peer_id)
			return null
	server_peer_worlds[peer_id] = clean_world
	if server_players.has(peer_id):
		var existing = server_players[peer_id]
		if reset_position:
			_force_player_state(existing, spawn_position, Vector2.ZERO, 1, "idle")
			server_input_queues[peer_id] = []
			server_last_processed_input[peer_id] = 0
		return existing

	var player = RemotePlayerScene.instantiate()
	player.name = "Player_%d" % int(peer_id)
	players_root.add_child(player)
	if player.has_method("setup"):
		player.setup(peer_id, false, true, "Server %d" % int(peer_id))
	_force_player_state(player, spawn_position, Vector2.ZERO, 1, "idle")
	server_players[peer_id] = player
	server_input_queues[peer_id] = []
	server_last_processed_input[peer_id] = 0
	server_last_input[peer_id] = Protocol.make_input(peer_id, 0, 0.0, false, 1, server_tick)
	print("[PhaseI] server_spawn peer=%d world=%s node=%s players=%d" % [int(peer_id), clean_world, str(player.get_path()), server_players.size()])
	return player


func _server_remove_player(peer_id: int) -> void:
	var player = server_players.get(peer_id, null)
	if player != null and is_instance_valid(player):
		player.queue_free()
	server_players.erase(peer_id)
	server_peer_worlds.erase(peer_id)
	server_peer_identities.erase(peer_id)
	server_input_queues.erase(peer_id)
	server_last_processed_input.erase(peer_id)
	server_last_input.erase(peer_id)


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
	_simulate_player_packet(player, packet, delta)
	server_last_input[peer_id] = packet
	if acknowledge:
		server_last_processed_input[peer_id] = max(int(server_last_processed_input.get(peer_id, 0)), int(packet.get("input_sequence", 0)))


func _server_send_snapshots() -> void:
	for target_peer_id in multiplayer.get_peers():
		var target_world := _server_peer_world(int(target_peer_id))
		for peer_id in server_players.keys():
			if _server_peer_world(int(peer_id)) != target_world:
				continue
			_send_enet_message(int(target_peer_id), {"type": "snapshot", "snapshot": _make_server_snapshot(int(peer_id), server_players[peer_id])}, false)


func _make_server_snapshot(peer_id: int, player) -> Dictionary:
	var snapshot := Protocol.make_snapshot(
		peer_id,
		server_tick,
		_get_player_position(player),
		_get_player_velocity(player),
		_get_player_facing(player),
		_get_player_movement_state(player),
		int(server_last_processed_input.get(peer_id, 0)),
		_get_player_jump_hold_fall_pause_timer(player)
	)
	var world_name := _server_peer_world(peer_id)
	var identity: Dictionary = server_peer_identities.get(peer_id, {})
	snapshot["world"] = world_name
	snapshot["username"] = str(identity.get("username", "Peer %d" % peer_id))
	snapshot["profile_id"] = str(identity.get("profile_id", identity.get("game_player_id", "")))
	return snapshot


func _make_spawn_payload(peer_id: int, player, world_name: String) -> Dictionary:
	var identity: Dictionary = server_peer_identities.get(peer_id, {})
	return {
		"peer_id": int(peer_id),
		"position": _get_player_position(player),
		"velocity": _get_player_velocity(player),
		"facing_dir": _get_player_facing(player),
		"movement_state": _get_player_movement_state(player),
		"world": _safe_world_name(world_name, requested_world_name),
		"username": str(identity.get("username", "Peer %d" % peer_id)),
		"profile_id": str(identity.get("profile_id", identity.get("game_player_id", ""))),
	}


func _client_physics(delta: float) -> void:
	if local_player == null or local_peer_id <= 0:
		_update_remote_interpolation(delta)
		return
	_client_send_input_and_predict(delta)
	_update_remote_interpolation(delta)


func _client_send_input_and_predict(delta: float) -> void:
	client_input_sequence += 1
	client_tick += 1
	var move_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var jump_held := Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
	var facing := _get_player_facing(local_player)
	if move_x > 0.01:
		facing = 1
	elif move_x < -0.01:
		facing = -1
	var packet := Protocol.make_input(local_peer_id, client_input_sequence, move_x, jump_pressed, facing, client_tick, jump_held)
	_simulate_player_packet(local_player, packet, delta)
	_apply_local_player_draw_order()
	local_predicted_position = _get_player_position(local_player)
	local_predicted_velocity = _get_player_velocity(local_player)
	_store_input_history(packet)
	_send_enet_message(0, {"type": "input", "packet": packet}, false)


func _client_reconcile_local_player(snapshot: Dictionary) -> void:
	if local_player == null:
		return
	var acknowledged_input := int(snapshot.get("last_processed_input", 0))
	last_processed_input = max(last_processed_input, acknowledged_input)
	var authoritative_position := Protocol.snapshot_position(snapshot)
	var authoritative_velocity := Protocol.snapshot_velocity(snapshot)
	last_server_authoritative_position = authoritative_position
	last_server_authoritative_velocity = authoritative_velocity
	last_server_tick = int(snapshot.get("server_tick", last_server_tick))
	_send_custom_trusted_state(false)

	var prediction_position := _get_player_position(local_player)
	if input_history.has(acknowledged_input):
		var acknowledged_entry: Dictionary = input_history[acknowledged_input]
		prediction_position = acknowledged_entry.get("predicted_position", prediction_position)
	local_prediction_error = prediction_position.distance_to(authoritative_position)
	correction_mode = _correction_mode_for_error(local_prediction_error)
	_remove_acknowledged_inputs(acknowledged_input)
	if correction_mode == "none":
		return

	var previous_position := _get_player_position(local_player)
	_force_player_state(
		local_player,
		authoritative_position,
		authoritative_velocity,
		int(snapshot.get("facing_dir", _get_player_facing(local_player))),
		str(snapshot.get("movement_state", "")),
		Protocol.snapshot_jump_hold_fall_pause_timer(snapshot)
	)
	_replay_unacknowledged_inputs()
	var replayed_position := _get_player_position(local_player)
	var replayed_velocity := _get_player_velocity(local_player)
	match correction_mode:
		"smooth":
			_set_player_position(local_player, previous_position.lerp(replayed_position, Protocol.LOCAL_SMOOTH_CORRECTION_BLEND))
		"fast":
			_set_player_position(local_player, previous_position.lerp(replayed_position, Protocol.LOCAL_FAST_CORRECTION_BLEND))
		"snap":
			if local_prediction_error >= Protocol.HARD_SNAP_CORRECTION_PIXELS:
				_set_player_position(local_player, replayed_position)
			else:
				_set_player_position(local_player, previous_position.lerp(replayed_position, Protocol.LOCAL_STRONG_CORRECTION_BLEND))
	_set_player_velocity(local_player, replayed_velocity)
	local_predicted_position = _get_player_position(local_player)
	local_predicted_velocity = _get_player_velocity(local_player)


func _update_remote_interpolation(delta: float) -> void:
	for peer_id in client_players.keys():
		if int(peer_id) == local_peer_id:
			continue
		var player = client_players[peer_id]
		if player == null or not is_instance_valid(player):
			continue
		var state: Dictionary = interpolator.get_render_state(int(peer_id))
		if state.is_empty():
			continue
		_apply_remote_render_state(player, state, delta)


func _apply_remote_render_state(player, state: Dictionary, delta: float) -> void:
	var target_position: Vector2 = state.get("position", _get_player_position(player))
	var distance := _get_player_position(player).distance_to(target_position)
	var should_snap := bool(state.get("teleport_snap", false)) or distance >= Protocol.REMOTE_RENDER_SNAP_PIXELS
	var render_position := target_position
	if not should_snap and distance > Protocol.REMOTE_RENDER_CLOSE_ENOUGH_PIXELS:
		var smooth_rate := Protocol.REMOTE_RENDER_FAST_SMOOTH_RATE if distance >= Protocol.REMOTE_RENDER_FAST_DISTANCE_PIXELS else Protocol.REMOTE_RENDER_SMOOTH_RATE
		var alpha := clampf(1.0 - exp(-smooth_rate * maxf(delta, Protocol.FIXED_DELTA)), 0.0, 1.0)
		render_position = _get_player_position(player).lerp(target_position, alpha)
	_force_player_state(
		player,
		render_position,
		state.get("velocity", _get_player_velocity(player)),
		int(state.get("facing_dir", _get_player_facing(player))),
		str(state.get("movement_state", _get_player_movement_state(player)))
	)


func _simulate_player_packet(player, packet: Dictionary, delta: float) -> void:
	if player == null or not is_instance_valid(player) or not (player is CharacterBody2D):
		return
	var body := player as CharacterBody2D
	var move_x := clampf(float(packet.get("move_x", 0.0)), -1.0, 1.0)
	var jump_pressed := bool(packet.get("jump_pressed", false))
	var jump_held := bool(packet.get("jump_held", jump_pressed))
	var pause_timer := _get_player_jump_hold_fall_pause_timer(player)
	var facing := int(packet.get("facing_dir", _get_player_facing(player)))
	if facing != 0:
		_set_player_facing(player, facing)
	var target_speed := move_x * Protocol.SPEED
	if absf(move_x) > 0.01:
		body.velocity.x = move_toward(body.velocity.x, target_speed, Protocol.ACCELERATION * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, Protocol.FRICTION * delta)

	if not jump_held:
		pause_timer = 0.0
	if jump_pressed and body.is_on_floor():
		body.velocity.y = Protocol.JUMP_VELOCITY
		pause_timer = Protocol.JUMP_HOLD_FALL_PAUSE_TIME
	if not body.is_on_floor():
		if jump_held and pause_timer > 0.0 and body.velocity.y >= 0.0:
			pause_timer = maxf(0.0, pause_timer - delta)
			body.velocity.y = 0.0
		else:
			var gravity_multiplier := Protocol.FALL_GRAVITY_MULTIPLIER if body.velocity.y > 0.0 else 1.0
			body.velocity.y = min(body.velocity.y + Protocol.GRAVITY * gravity_multiplier * delta, Protocol.MAX_FALL_SPEED)
	elif body.velocity.y > 0.0:
		body.velocity.y = 0.0
		pause_timer = 0.0
	var horizontal_velocity_before_slide: float = body.velocity.x
	var vertical_velocity_before_slide: float = body.velocity.y
	body.move_and_slide()
	if _release_body_ceiling_collision_pause(body, horizontal_velocity_before_slide, vertical_velocity_before_slide):
		pause_timer = 0.0
	if body.is_on_floor():
		pause_timer = 0.0
	_set_player_jump_hold_fall_pause_timer(player, pause_timer)
	_set_player_movement_state(player, Protocol.movement_state_for(body.is_on_floor(), body.velocity))


func _release_body_ceiling_collision_pause(body: CharacterBody2D, horizontal_velocity_before_slide: float, vertical_velocity_before_slide: float) -> bool:
	if body == null or body.is_on_floor():
		return false

	var was_moving_up: bool = vertical_velocity_before_slide < -0.01
	var has_any_slide_collision: bool = body.get_slide_collision_count() > 0
	var has_overhead_contact: bool = body.is_on_ceiling()
	var corner_nudge_x: float = 0.0
	for collision_index in range(body.get_slide_collision_count()):
		var collision: KinematicCollision2D = body.get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector2 = collision.get_normal()
		if normal.y <= CEILING_CONTACT_NORMAL_Y_THRESHOLD:
			continue

		has_overhead_contact = true
		if absf(normal.x) > CEILING_CORNER_NORMAL_X_THRESHOLD:
			corner_nudge_x += 1.0 if normal.x > 0.0 else -1.0

	var should_release_overhead_contact: bool = was_moving_up and has_overhead_contact
	if not should_release_overhead_contact and not (was_moving_up and has_any_slide_collision and absf(body.velocity.y) <= 0.01):
		return false

	var release_fall_velocity: float = maxf(
		CEILING_CONTACT_FALL_START_VELOCITY,
		minf(absf(vertical_velocity_before_slide) * CEILING_CONTACT_IMPACT_FALL_RATIO, CEILING_CONTACT_MAX_FALL_START_VELOCITY)
	)
	body.velocity.y = maxf(body.velocity.y, release_fall_velocity)
	body.global_position.y += CEILING_UNSTICK_NUDGE
	if absf(horizontal_velocity_before_slide) > absf(body.velocity.x) and absf(horizontal_velocity_before_slide) > 0.01:
		body.velocity.x = horizontal_velocity_before_slide
	if absf(corner_nudge_x) > 0.01:
		body.global_position.x += clampf(corner_nudge_x, -1.0, 1.0) * CEILING_CORNER_UNSTICK_NUDGE
	return true


func _force_player_state(player, position_value: Vector2, velocity_value: Vector2, facing_value: int, state_value: String = "", pause_timer_value: float = -1.0) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("force_state"):
		player.force_state(position_value, velocity_value, facing_value, state_value, pause_timer_value)
		return
	_set_player_position(player, position_value)
	_set_player_velocity(player, velocity_value)
	_set_player_facing(player, facing_value)
	if pause_timer_value >= 0.0:
		_set_player_jump_hold_fall_pause_timer(player, pause_timer_value)
	if state_value.strip_edges() != "":
		_set_player_movement_state(player, state_value)


func _ensure_local_player_registered() -> void:
	if not is_client or world == null or world.player == null:
		return
	local_player = world.player
	if local_peer_id > 0:
		client_players[local_peer_id] = local_player
	_apply_local_player_draw_order()


func _apply_local_player_draw_order() -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	world.player.z_as_relative = false
	world.player.z_index = LOCAL_PLAYER_Z_INDEX
	var parent_node: Node = world.player.get_parent()
	if parent_node != null:
		parent_node.move_child(world.player, parent_node.get_child_count() - 1)
	var camera: Camera2D = world.player.get_node_or_null("Camera2D") as Camera2D
	if camera != null and world.in_world:
		camera.enabled = true
		camera.make_current()


func _watch_world_lifecycle() -> void:
	var next_world := _get_world_name()
	if next_world == "":
		return
	if active_client_world == "":
		active_client_world = next_world
		return
	if next_world == active_client_world:
		return
	var previous_world := active_client_world
	active_client_world = next_world
	_clear_remote_players("world_switch", true)
	interpolator.clear()
	input_history.clear()
	last_processed_input = 0
	last_server_tick = 0
	_send_custom_trusted_clear("world_switch", previous_world)
	if local_peer_id > 0 and multiplayer.multiplayer_peer != null:
		if client_ready_acknowledged:
			_send_enet_message(0, {"type": "client_world_changed", "identity": _make_client_identity_payload()}, true)
		else:
			_send_client_ready_to_server("world_switch_before_ack")
	print("[PhaseI] world_switch old_world=%s new_world=%s cleanup=true trusted_state_cleared=true snapshot_buffers_cleared=true" % [previous_world, next_world])


func _retry_client_ready_if_needed() -> void:
	if not is_client or client_ready_acknowledged:
		return
	if local_peer_id <= 0 or not _is_movement_connected():
		return
	var now := Time.get_ticks_msec()
	if now - last_client_ready_sent_msec < 1000:
		return
	_send_client_ready_to_server("retry")


func _send_client_ready_to_server(reason: String = "ready") -> void:
	if not is_client or local_peer_id <= 0 or not _is_movement_connected():
		return
	var now := Time.get_ticks_msec()
	if last_client_ready_sent_msec > 0 and now - last_client_ready_sent_msec < 300:
		return
	last_client_ready_sent_msec = Time.get_ticks_msec()
	var identity := _make_client_identity_payload()
	print("[CustomMovementRPC] client_ready send peer=%d world=%s path=%s reason=%s backend_authenticated=%s" % [
		local_peer_id,
		str(identity.get("world", "")),
		str(get_path()),
		reason,
		str(identity.get("backend_authenticated", false)),
	])
	_send_enet_message(0, {"type": "client_ready", "identity": identity}, true)


func _clear_client_runtime(reason: String) -> void:
	_clear_remote_players(reason, false)
	interpolator.clear()
	client_players.clear()
	if local_peer_id > 0 and local_player != null:
		client_players[local_peer_id] = local_player
	input_history.clear()
	last_processed_input = 0
	local_prediction_error = 0.0
	correction_mode = "none"
	last_server_tick = 0


func _clear_remote_players(reason: String, log_removed: bool) -> void:
	var remote_ids: Array = []
	for peer_id in client_players.keys():
		if int(peer_id) != local_peer_id:
			remote_ids.append(int(peer_id))
	for peer_id in remote_ids:
		_remove_remote_player(int(peer_id), reason, log_removed)


func _remove_remote_player(peer_id: int, reason: String, log_removed: bool) -> bool:
	if int(peer_id) == local_peer_id:
		return false
	var removed := false
	var player = client_players.get(peer_id, null)
	if player != null and is_instance_valid(player):
		player.queue_free()
		removed = true
	client_players.erase(peer_id)
	if players_root != null:
		var stale := players_root.get_node_or_null("Player_%d" % int(peer_id))
		if stale != null and is_instance_valid(stale):
			stale.queue_free()
			removed = true
	interpolator.clear_peer(peer_id)
	if log_removed:
		print("[PhaseI] remote_removed peer=%d reason=%s snapshot_buffer_cleared=true node_removed=%s" % [int(peer_id), reason, str(removed)])
	return removed


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


func _trim_input_history() -> void:
	while input_history.size() > Protocol.MAX_INPUT_HISTORY:
		var sequences := input_history.keys()
		sequences.sort()
		input_history.erase(sequences[0])


func _remove_acknowledged_inputs(acknowledged_input: int) -> void:
	for sequence in input_history.keys():
		if int(sequence) <= acknowledged_input:
			input_history.erase(sequence)


func _replay_unacknowledged_inputs() -> void:
	var sequences := input_history.keys()
	sequences.sort()
	for sequence in sequences:
		var entry: Dictionary = input_history[sequence]
		_simulate_player_packet(local_player, entry.get("input", {}), Protocol.FIXED_DELTA)
	local_predicted_position = _get_player_position(local_player)
	local_predicted_velocity = _get_player_velocity(local_player)


func _correction_mode_for_error(error_pixels: float) -> String:
	if error_pixels < Protocol.SMALL_CORRECTION_PIXELS:
		return "none"
	if error_pixels < Protocol.FAST_CORRECTION_PIXELS:
		return "smooth"
	if error_pixels < Protocol.SNAP_CORRECTION_PIXELS:
		return "fast"
	return "snap"


func _send_custom_trusted_state(force: bool = false) -> bool:
	var network := _get_network_manager()
	if network == null or not network.has_method("send_custom_trusted_player_state"):
		return false
	if local_peer_id <= 0 or last_server_tick <= 0:
		return false
	var node_path := str(local_player.get_path()) if local_player != null and is_instance_valid(local_player) else ""
	return bool(network.send_custom_trusted_player_state(
		last_server_authoritative_position,
		last_server_authoritative_velocity,
		_get_player_facing(local_player),
		_get_world_name(),
		local_peer_id,
		last_server_tick,
		node_path,
		force
	))


func _send_custom_trusted_clear(reason: String, world_name: String) -> bool:
	var network := _get_network_manager()
	if network == null or not network.has_method("send_custom_trusted_player_state_clear"):
		return false
	return bool(network.send_custom_trusted_player_state_clear(world_name, local_peer_id, reason))


func _make_client_identity_payload() -> Dictionary:
	var payload := {
		"world": _get_world_name(),
		"peer_id": local_peer_id,
		"username": "",
		"profile_id": "",
		"game_player_id": "",
		"account_id": "",
		"node_path": str(local_player.get_path()) if local_player != null and is_instance_valid(local_player) else "",
	}
	var network := _get_network_manager()
	if network != null and network.has_method("get_active_identity_payload"):
		var identity: Dictionary = network.get_active_identity_payload(_get_world_name())
		for key in identity.keys():
			payload[key] = identity[key]
	if str(payload.get("username", "")).strip_edges() == "" and world != null and world.has_method("get_current_profile_name"):
		payload["username"] = str(world.get_current_profile_name())
	return payload


func _server_set_peer_identity(peer_id: int, identity: Dictionary, world_name: String) -> void:
	var clean_world := _safe_world_name(world_name, requested_world_name)
	server_peer_worlds[peer_id] = clean_world
	var stored := identity.duplicate(true)
	stored["world"] = clean_world
	stored["peer_id"] = peer_id
	server_peer_identities[peer_id] = stored


func _log_phase_i_mapping_if_changed(force: bool = false) -> void:
	if local_peer_id <= 0 or local_player == null:
		return
	var identity := _make_client_identity_payload()
	var username := str(identity.get("username", identity.get("account_username", ""))).strip_edges()
	var profile := str(identity.get("profile_id", identity.get("game_player_id", ""))).strip_edges()
	var world_name := _get_world_name()
	var node_path := str(local_player.get_path())
	var next_key := "%s|%s|%s|%d|%s" % [username, profile, world_name, local_peer_id, node_path]
	if not force and next_key == map_debug_key:
		return
	map_debug_key = next_key
	print("[PhaseIMap] username=%s profile=%s world=%s peer=%d node=%s" % [
		username,
		profile,
		world_name,
		local_peer_id,
		node_path,
	])


func _log_movement_status_if_changed(force: bool = false) -> void:
	var backend_status := _get_backend_status()
	var collision_summary := _get_actual_collision_summary()
	var movement_connected := _is_movement_connected()
	var player_spawned := local_player != null and is_instance_valid(local_player)
	var world_loaded := world != null and bool(world.get("in_world"))
	var collision_ready := int(collision_summary.get("solid_collision_count", 0)) > 0
	var role := "server" if is_server else "client" if is_client else "idle"
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%d" % [
		role,
		str(backend_status.get("connected", false)),
		str(backend_status.get("authenticated", false)),
		str(movement_connected),
		str(player_spawned),
		str(world_loaded),
		str(collision_ready),
		str(collision_summary.get("world", "")),
		str(collision_summary.get("collision_hash", "")),
		MovementMode.get_mode_name(),
		local_peer_id,
	]
	if not force and key == status_debug_key:
		return
	status_debug_key = key
	print("[CustomMovementStatus] mode=%s role=%s backend_connected=%s backend_authenticated=%s movement_connected=%s player_spawned=%s world_loaded=%s collision_ready=%s world=%s peer=%d collision_hash=%s blocks=%d solid=%d" % [
		MovementMode.get_mode_name(),
		role,
		str(backend_status.get("connected", false)),
		str(backend_status.get("authenticated", false)),
		str(movement_connected),
		str(player_spawned),
		str(world_loaded),
		str(collision_ready),
		str(collision_summary.get("world", "")),
		local_peer_id,
		str(collision_summary.get("collision_hash", "")),
		int(collision_summary.get("block_count", 0)),
		int(collision_summary.get("solid_collision_count", 0)),
	])


func _log_collision_summary_if_changed(force: bool = false) -> void:
	var summary := _get_actual_collision_summary()
	var key := "%s|%s|%s|%s|%s" % [
		str(summary.get("world", "")),
		str(summary.get("revision", 0)),
		str(summary.get("block_count", 0)),
		str(summary.get("solid_collision_count", 0)),
		str(summary.get("collision_hash", "")),
	]
	if not force and key == collision_debug_key:
		return
	var current_entries := _get_actual_collision_entries()
	if debug_enabled and not last_logged_collision_entries.is_empty() and current_entries != last_logged_collision_entries:
		_log_collision_entry_delta(last_logged_collision_entries, current_entries)
	last_logged_collision_entries = current_entries
	collision_debug_key = key
	print("[MovementCollision] role=%s world=%s block_count=%d solid_collision_count=%d revision=%s collision_hash=%s collision_ready=%s" % [
		"server" if is_server else "client" if is_client else "idle",
		str(summary.get("world", "")),
		int(summary.get("block_count", 0)),
		int(summary.get("solid_collision_count", 0)),
		str(summary.get("revision", 0)),
		str(summary.get("collision_hash", "")),
		str(int(summary.get("solid_collision_count", 0)) > 0),
	])


func _get_backend_status() -> Dictionary:
	var network := _get_network_manager()
	if network == null:
		return {"connected": false, "authenticated": false}
	var connected_value := false
	if "connected" in network:
		connected_value = bool(network.get("connected"))
	var authenticated_value := false
	if network.has_method("is_server_session_authenticated"):
		authenticated_value = bool(network.is_server_session_authenticated())
	elif "server_session_authenticated" in network:
		authenticated_value = bool(network.get("server_session_authenticated"))
	return {
		"connected": connected_value,
		"authenticated": authenticated_value,
	}


func _is_movement_connected() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return false
	var peer := multiplayer.multiplayer_peer
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	if is_server:
		return true
	return local_peer_id > 0


func _get_actual_collision_summary() -> Dictionary:
	var block_count := 0
	var solid_count := 0
	var entries := _get_actual_collision_entries()
	if world != null:
		var blocks_value: Variant = world.get("blocks")
		if blocks_value is Dictionary:
			var foreground_blocks: Dictionary = blocks_value
			for raw_grid_pos in foreground_blocks.keys():
				var _grid_pos := _grid_position_from_key(raw_grid_pos)
				var block_data_value: Variant = foreground_blocks.get(raw_grid_pos, {})
				var block_type := _block_type_from_data(block_data_value)
				if block_type == "":
					continue
				block_count += 1
				if _is_solid_collision_block(block_type, block_data_value):
					solid_count += 1
	var joined := "|".join(entries)
	var collision_hash := "empty"
	if joined != "":
		collision_hash = _sha256_text(joined).substr(0, 16)
	return {
		"world": _get_world_name(),
		"block_count": block_count,
		"solid_collision_count": solid_count,
		"collision_hash": collision_hash,
		"revision": _get_world_state_revision(),
	}


func _get_actual_collision_entries() -> Array[String]:
	var entries: Array[String] = []
	if world == null:
		return entries
	var blocks_value: Variant = world.get("blocks")
	if not (blocks_value is Dictionary):
		return entries
	var foreground_blocks: Dictionary = blocks_value
	for raw_grid_pos in foreground_blocks.keys():
		var grid_pos := _grid_position_from_key(raw_grid_pos)
		var block_data_value: Variant = foreground_blocks.get(raw_grid_pos, {})
		var block_type := _block_type_from_data(block_data_value)
		if block_type == "":
			continue
		if _is_solid_collision_block(block_type, block_data_value):
			entries.append("%d,%d,%s" % [grid_pos.x, grid_pos.y, block_type])
	entries.sort()
	return entries


func _log_collision_entry_delta(previous_entries: Array[String], current_entries: Array[String]) -> void:
	var previous := {}
	var current := {}
	for entry in previous_entries:
		previous[entry] = true
	for entry in current_entries:
		current[entry] = true
	var removed: Array[String] = []
	var added: Array[String] = []
	for entry in previous.keys():
		if not current.has(entry):
			removed.append(str(entry))
	for entry in current.keys():
		if not previous.has(entry):
			added.append(str(entry))
	removed.sort()
	added.sort()
	print("[MovementCollisionDelta] role=%s removed=%s added=%s" % [
		"server" if is_server else "client" if is_client else "idle",
		str(removed.slice(0, min(8, removed.size()))),
		str(added.slice(0, min(8, added.size()))),
	])


func _get_world_state_revision() -> int:
	if world == null:
		return 0
	var sync_manager: Variant = world.get("world_state_sync_manager")
	if sync_manager != null and "world_state_apply_generation" in sync_manager:
		return int(sync_manager.get("world_state_apply_generation"))
	return 0


func _grid_position_from_key(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return Vector2i.ZERO


func _block_type_from_data(value) -> String:
	if value is Dictionary:
		return str(value.get("type", value.get("block_type", ""))).strip_edges().to_lower()
	return ""


func _is_solid_collision_block(block_type: String, block_data_value) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "":
		return false
	if world != null:
		var item_database_value: Variant = world.get("item_database")
		if item_database_value is Dictionary:
			var item_database: Dictionary = item_database_value
			if item_database.has(clean_type):
				var item_data_value: Variant = item_database.get(clean_type, {})
				if item_data_value is Dictionary:
					var item_data: Dictionary = item_data_value
					if item_data.has("collidable") and not bool(item_data.get("collidable", true)):
						return false
					if bool(item_data.get("no_collision", false)):
						return false
		var block_manager = world.get("block_manager")
		if block_manager != null and block_manager.has_method("is_simple_full_solid_foreground_collision_block"):
			return bool(block_manager.is_simple_full_solid_foreground_collision_block(clean_type))
	if block_data_value is Dictionary and bool(block_data_value.get("solid", false)):
		return true
	return clean_type != "water"


func _sha256_text(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _load_backend_world_state_json_for_server(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name, requested_world_name)
	var path := "res://backend/worlds/%s.json" % clean_world
	if not FileAccess.file_exists(path):
		return false
	var body := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(body)
	if not (parsed is Dictionary):
		push_warning("[MovementCollision] Movement server could not parse backend world JSON: " + path)
		return false
	var payload: Dictionary = parsed.duplicate(true)
	if not payload.has("foreground") and payload.has("blocks"):
		payload["foreground"] = payload.get("blocks", [])
	if not payload.has("background") and payload.has("background_blocks"):
		payload["background"] = payload.get("background_blocks", [])
	payload["world"] = clean_world
	payload["world_name"] = clean_world
	payload["world_id"] = clean_world
	payload["respawn_player"] = false
	payload["force_player_position"] = false
	payload["world_state_reason"] = "custom_authoritative_movement_server_json_fallback_world_load"
	if world.has_method("apply_network_world_state"):
		world.apply_network_world_state(payload)
		print("[MovementCollision] server_world_state_loaded source=%s world=%s blocks=%d background=%d" % [
			path,
			clean_world,
			int(payload.get("foreground", []).size()) if payload.get("foreground", []) is Array else 0,
			int(payload.get("background", []).size()) if payload.get("background", []) is Array else 0,
		])
		return true
	return false


func _should_load_server_world_state_from_backend() -> bool:
	return _get_backend_api_base_url() != ""


func _load_backend_world_state_http_for_server(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name, requested_world_name)
	var api_base := _get_backend_api_base_url()
	if api_base == "":
		return false

	var request := HTTPRequest.new()
	request.name = "CustomMovementServerWorldStateRequest"
	request.timeout = SERVER_WORLD_STATE_TIMEOUT_SECONDS
	add_child(request)

	var endpoint := _get_server_world_state_endpoint()
	var headers := _get_server_world_state_headers()
	var url := "%s%s?world=%s" % [api_base, endpoint, clean_world.uri_encode()]
	print("[MovementCollision] server_world_state_request world=%s url=%s token=%s" % [
		clean_world,
		url,
		"yes" if _get_server_world_state_token() != "" else "no",
	])

	var error := request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		push_warning("[MovementCollision] Could not start server backend world-state request. error=%s fallback=local_json" % str(error))
		return false

	var response = await request.request_completed
	request.queue_free()

	var result_code := HTTPRequest.RESULT_CANT_CONNECT
	var response_code := 0
	var body := PackedByteArray()
	if response is Array and response.size() >= 4:
		result_code = int(response[0]) as HTTPRequest.Result
		response_code = int(response[1])
		body = response[3]

	var body_text := body.get_string_from_utf8()
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[MovementCollision] Server backend world-state request failed. result=%d status=%d body=%s fallback=local_json" % [
			result_code,
			response_code,
			body_text.substr(0, min(240, body_text.length())),
		])
		return false

	var parsed = JSON.parse_string(body_text)
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		push_warning("[MovementCollision] Server backend world-state response was invalid or rejected. fallback=local_json")
		return false

	var payload = parsed.get("world_state", {})
	if not (payload is Dictionary):
		push_warning("[MovementCollision] Server backend world-state payload was missing. fallback=local_json")
		return false

	var applied := _apply_server_world_state_payload(payload, clean_world, "custom_authoritative_movement_server_backend_world_load")
	if not applied:
		push_warning("[MovementCollision] Server backend world-state payload could not be applied. fallback=local_json")
		return false

	await _wait_for_server_world_collision_ready(5.0)
	var summary := _get_actual_collision_summary()
	print("[MovementCollision] server_world_state_loaded source=%s world=%s blocks=%d background=%d collision_blocks=%d collision_hash=%s revision=%s" % [
		url,
		clean_world,
		int(parsed.get("block_count", 0)),
		int(parsed.get("background_block_count", 0)),
		int(summary.get("solid_collision_count", 0)),
		str(summary.get("collision_hash", "")),
		str(summary.get("revision", 0)),
	])
	return true


func _apply_server_world_state_payload(raw_payload, world_name: String, reason: String) -> bool:
	if world == null or not world.has_method("apply_network_world_state"):
		return false
	if not (raw_payload is Dictionary):
		return false

	var payload: Dictionary = raw_payload.duplicate(true)
	if not payload.has("foreground") and payload.has("blocks"):
		payload["foreground"] = payload.get("blocks", [])
	if not payload.has("background") and payload.has("background_blocks"):
		payload["background"] = payload.get("background_blocks", [])
	payload["world"] = world_name
	payload["world_name"] = world_name
	payload["world_id"] = world_name
	payload["respawn_player"] = false
	payload["force_player_position"] = false
	payload["world_state_reason"] = reason
	world.apply_network_world_state(payload)
	return true


func _wait_for_server_world_collision_ready(timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000.0)
	while is_inside_tree() and Time.get_ticks_msec() <= deadline:
		if _is_world_collision_ready():
			return true
		await get_tree().process_frame
	return _is_world_collision_ready()


func _is_world_collision_ready() -> bool:
	if world == null:
		return false
	if "in_world" in world and not bool(world.get("in_world")):
		return false
	if "applying_network_world_update" in world and bool(world.get("applying_network_world_update")):
		return false
	if bool(world.get_meta("world_entry_in_progress", false)):
		return false
	var save_manager = world.get("save_manager")
	if save_manager != null and "waiting_for_server_world_state" in save_manager and bool(save_manager.get("waiting_for_server_world_state")):
		return false
	var block_manager = world.get("block_manager")
	if block_manager == null:
		return false
	var blocks_value = world.get("blocks")
	return blocks_value is Dictionary and blocks_value.size() > 0 and _has_valid_entrance_spawn_position()


func _get_backend_api_base_url() -> String:
	var api_base := MovementMode.get_launch_arg_value("--pixelmania-api-base", "").strip_edges()
	if api_base == "":
		api_base = OS.get_environment("PIXELMANIA_API_BASE").strip_edges()
	if api_base == "":
		api_base = _infer_api_base_from_ws_url(MovementMode.get_launch_arg_value("--pixelmania-ws-url", ""))
	return _trim_trailing_slashes(api_base)


func _get_server_world_state_endpoint() -> String:
	if _get_server_world_state_token() != "":
		return SERVER_WORLD_STATE_LIVE_ENDPOINT
	return SERVER_WORLD_STATE_DEV_ENDPOINT


func _get_server_world_state_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	var token := _get_server_world_state_token()
	if token != "":
		headers.append("Authorization: Bearer " + token)
	return headers


func _get_server_world_state_token() -> String:
	var token := MovementMode.get_launch_arg_value(SERVER_WORLD_STATE_TOKEN_ARG, "").strip_edges()
	if token == "":
		token = OS.get_environment(SERVER_WORLD_STATE_TOKEN_ENV).strip_edges()
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


func _get_or_create_players_root() -> Node2D:
	if world == null:
		return null
	var root: Node = world.get_parent()
	var existing: Node2D = null
	if root != null:
		existing = root.get_node_or_null(REMOTE_ROOT_NAME) as Node2D
	if existing == null and root != null:
		existing = Node2D.new()
		existing.name = REMOTE_ROOT_NAME
		root.add_child(existing)
	existing.z_as_relative = false
	existing.z_index = 3900
	return existing


func _spawn_position_for_peer(_peer_id: int, _world_name: String) -> Vector2:
	if world != null and world.has_method("get_entrance_gate_spawn_position"):
		var spawn_position = world.get_entrance_gate_spawn_position()
		if spawn_position is Vector2 and is_finite(spawn_position.x) and is_finite(spawn_position.y):
			return spawn_position
	return Vector2(INF, INF)


func _has_valid_entrance_spawn_position() -> bool:
	var spawn_position := _spawn_position_for_peer(0, _get_world_name())
	return is_finite(spawn_position.x) and is_finite(spawn_position.y)


func _server_peer_world(peer_id: int) -> String:
	var clean := _safe_world_name(str(server_peer_worlds.get(peer_id, requested_world_name)), requested_world_name)
	if clean == "":
		clean = requested_world_name
	return clean


func _server_player_path(peer_id: int) -> String:
	var player = server_players.get(peer_id, null)
	if player != null and is_instance_valid(player):
		return str(player.get_path())
	return ""


func _get_world_name() -> String:
	if world == null:
		return requested_world_name
	return _safe_world_name(str(world.current_world_name), requested_world_name)


func _safe_world_name(raw_world_name: String, default_value: String = DEFAULT_PHASE_I_WORLD) -> String:
	var clean := str(raw_world_name).strip_edges()
	if clean == "":
		clean = default_value
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result := ""
	for i in range(clean.length()):
		var character := clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	if result == "":
		result = default_value
	return result.to_upper()


func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")


func _vector_from_payload(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _get_player_position(player) -> Vector2:
	if player != null and is_instance_valid(player) and player is Node2D:
		return player.global_position
	return Vector2.ZERO


func _set_player_position(player, value: Vector2) -> void:
	if player != null and is_instance_valid(player) and player is Node2D:
		player.global_position = value


func _get_player_velocity(player) -> Vector2:
	if player != null and is_instance_valid(player) and player is CharacterBody2D:
		return player.velocity
	return Vector2.ZERO


func _set_player_velocity(player, value: Vector2) -> void:
	if player != null and is_instance_valid(player) and player is CharacterBody2D:
		player.velocity = value


func _get_player_facing(player) -> int:
	if player != null and is_instance_valid(player):
		if player.has_method("get"):
			var value = player.get("facing_dir")
			if value is int or value is float:
				return -1 if int(value) < 0 else 1
		var visual: Node2D = player.get_node_or_null("PlayerVisual") as Node2D
		if visual != null:
			return -1 if visual.scale.x < 0.0 else 1
	if world != null:
		return -1 if int(world.player_facing_direction) < 0 else 1
	return 1


func _set_player_facing(player, facing: int) -> void:
	var clean := -1 if int(facing) < 0 else 1
	if player != null and is_instance_valid(player):
		if player.has_method("set_facing_dir"):
			player.set_facing_dir(clean)
		else:
			var visual: Node2D = player.get_node_or_null("PlayerVisual") as Node2D
			if visual != null:
				visual.scale.x = float(clean)
			player.set_meta("facing_dir", clean)
	if player == local_player and world != null:
		world.player_facing_direction = clean


func _get_player_movement_state(player) -> String:
	if player != null and is_instance_valid(player):
		var value = player.get("movement_state")
		if value is String and str(value).strip_edges() != "":
			return str(value)
		var meta_value = player.get_meta("movement_state", "")
		if str(meta_value).strip_edges() != "":
			return str(meta_value)
	return Protocol.movement_state_for(player != null and player is CharacterBody2D and player.is_on_floor(), _get_player_velocity(player))


func _set_player_movement_state(player, state_value: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var clean := str(state_value).strip_edges()
	if clean == "":
		clean = "idle"
	var has_property := false
	for property in player.get_property_list():
		if str(property.get("name", "")) == "movement_state":
			has_property = true
			break
	if has_property:
		player.set("movement_state", clean)
	player.set_meta("movement_state", clean)


func _get_player_jump_hold_fall_pause_timer(player) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	for property in player.get_property_list():
		if str(property.get("name", "")) == "jump_hold_fall_pause_timer":
			var value = player.get("jump_hold_fall_pause_timer")
			if value is int or value is float:
				return maxf(0.0, float(value))
			return 0.0
	return maxf(0.0, float(player.get_meta("jump_hold_fall_pause_timer", 0.0)))


func _set_player_jump_hold_fall_pause_timer(player, value: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var clean := maxf(0.0, value)
	var has_property := false
	for property in player.get_property_list():
		if str(property.get("name", "")) == "jump_hold_fall_pause_timer":
			has_property = true
			break
	if has_property:
		player.set("jump_hold_fall_pause_timer", clean)
	player.set_meta("jump_hold_fall_pause_timer", clean)
