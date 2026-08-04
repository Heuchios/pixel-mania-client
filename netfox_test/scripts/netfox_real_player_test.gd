extends Node2D

const PORT := 24565
const ADDRESS := "127.0.0.1"
const PLAYER_SCENE := preload("res://Scenes/player/netfox_player.tscn")
const BODY_AUTHORITY := 1
const LOG_PREFIX := "[NetfoxRealPlayerTest]"
const NETFOX_DEBUG_ARG := "--netfox-debug-logs"
const NETFOX_DEBUG_ENV := "NETFOX_DEBUG_LOGS"

var spawned_players: Dictionary = {}
var mode: String = "standalone"
var netfox_debug_logs: bool = false

@onready var players_root: Node2D = $Players
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	netfox_debug_logs = _is_netfox_debug_enabled()
	_configure_netfox_logging()
	_mute_audio_for_server_or_headless()
	MovementMode.set_mode(MovementMode.Mode.NETFOX_TEST)
	_connect_multiplayer_signals()
	_parse_launch_mode()
	_update_info_label()


func _process(_delta: float) -> void:
	_update_info_label()


func _exit_tree() -> void:
	_clear_players(true)
	var peer := multiplayer.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _parse_launch_mode() -> void:
	if MovementMode.has_launch_arg("--server"):
		start_server()
	elif MovementMode.has_launch_arg("--client"):
		start_client()
	else:
		mode = "standalone"
		print("%s Launch with --server or --client to run the isolated real-player Netfox test." % LOG_PREFIX)
		print("%s Add %s or set %s=1 for verbose Netfox logs." % [LOG_PREFIX, NETFOX_DEBUG_ARG, NETFOX_DEBUG_ENV])


func start_server() -> void:
	mode = "server"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		push_error("%s Failed to start ENet server on port %d: %s" % [LOG_PREFIX, PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	print("%s Server started on %s:%d peer=%d" % [LOG_PREFIX, ADDRESS, PORT, multiplayer.get_unique_id()])
	_spawn_player(BODY_AUTHORITY, _get_spawn_position(BODY_AUTHORITY))


func start_client() -> void:
	mode = "client"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ADDRESS, PORT)
	if error != OK:
		push_error("%s Failed to connect ENet client to %s:%d: %s" % [LOG_PREFIX, ADDRESS, PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	print("%s Client connecting to %s:%d" % [LOG_PREFIX, ADDRESS, PORT])


func _on_connected_to_server() -> void:
	print("%s Client connected as peer %d; requesting spawn." % [LOG_PREFIX, multiplayer.get_unique_id()])
	request_spawn.rpc_id(BODY_AUTHORITY)


func _on_connection_failed() -> void:
	push_error("%s Client connection failed." % LOG_PREFIX)


func _on_server_disconnected() -> void:
	print("%s Server disconnected; clearing test players." % LOG_PREFIX)
	_clear_players()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("%s Peer connected: %d. Waiting for spawn request." % [LOG_PREFIX, peer_id])


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawned_players.erase(peer_id)
		despawn_player.rpc(peer_id)
	_despawn_player(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_spawn() -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	if requester_id <= 1:
		return

	print("%s Server received spawn request from peer %d." % [LOG_PREFIX, requester_id])
	for existing_peer_id in spawned_players.keys():
		var existing_position: Vector2 = spawned_players[existing_peer_id]
		spawn_player.rpc_id(requester_id, int(existing_peer_id), existing_position)

	if spawned_players.has(requester_id):
		return

	var spawn_position := _get_spawn_position(requester_id)
	_spawn_player(requester_id, spawn_position)
	spawn_player.rpc(requester_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	_spawn_player(peer_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int) -> void:
	_despawn_player(peer_id)


func _spawn_player(peer_id: int, spawn_position: Vector2) -> void:
	var player_name := "Player_%d" % peer_id
	if players_root.has_node(player_name):
		print("%s Ignored duplicate spawn for %s at %s." % [LOG_PREFIX, player_name, players_root.get_node(player_name).get_path()])
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = player_name
	player.position = spawn_position
	players_root.add_child(player)
	spawned_players[peer_id] = spawn_position

	if player.has_method("setup_authority"):
		player.setup_authority(peer_id)

	print("%s Spawned %s at %s pos=%s on peer %d." % [LOG_PREFIX, player_name, player.get_path(), spawn_position, multiplayer.get_unique_id()])


func _despawn_player(peer_id: int) -> void:
	var player_name := "Player_%d" % peer_id
	var player := players_root.get_node_or_null(player_name)
	if player != null:
		_mark_player_despawned(player)
		player.queue_free()
	spawned_players.erase(peer_id)


func _clear_players(immediate: bool = false) -> void:
	for child in players_root.get_children():
		_mark_player_despawned(child)
		if immediate:
			players_root.remove_child(child)
			child.free()
		else:
			child.queue_free()
	spawned_players.clear()


func _mark_player_despawned(player: Node) -> void:
	var rollback_synchronizer := player.get_node_or_null("RollbackSynchronizer")
	if rollback_synchronizer != null and rollback_synchronizer.has_method("despawn"):
		rollback_synchronizer.despawn()


func _get_spawn_position(_peer_id: int) -> Vector2:
	return Vector2(160.0 + float(spawned_players.size()) * 96.0, 240.0)


func _update_info_label() -> void:
	if info_label == null:
		return

	var peer_id := _get_local_peer_id()
	var status := "offline"
	if peer_id != 0:
		status = "server" if multiplayer.is_server() else "client"

	info_label.text = "Netfox Real Player Test %s\npeer %d mode %s\nplayers %d\n--server or --client" % [
		mode,
		peer_id,
		status,
		players_root.get_child_count()
	]


func _get_local_peer_id() -> int:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return 0
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return 0
	return multiplayer.get_unique_id()


func _configure_netfox_logging() -> void:
	var log_level := NetfoxLogger.LOG_DEBUG if netfox_debug_logs else NetfoxLogger.LOG_WARN
	NetfoxLogger.log_level = log_level
	NetfoxLogger.module_log_level["netfox"] = log_level
	NetfoxLogger.module_log_level["netfox.extras"] = log_level


func _is_netfox_debug_enabled() -> bool:
	if MovementMode.has_launch_arg(NETFOX_DEBUG_ARG):
		return true

	var env_value := OS.get_environment(NETFOX_DEBUG_ENV).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func _mute_audio_for_server_or_headless() -> void:
	if not MovementMode.has_launch_arg("--server") and DisplayServer.get_name() != "headless":
		return

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
