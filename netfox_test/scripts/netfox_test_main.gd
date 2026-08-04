extends Node2D

const PORT := 24565
const ADDRESS := "127.0.0.1"
const PLAYER_SCENE := preload("res://netfox_test/scenes/netfox_test_player.tscn")
const BODY_AUTHORITY := 1

var spawned_players: Dictionary = {}
var mode: String = "standalone"

@onready var players_root: Node2D = $Players
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	MovementMode.set_mode(MovementMode.Mode.NETFOX_TEST)
	_connect_multiplayer_signals()
	_parse_launch_mode()
	_update_info_label()


func _process(_delta: float) -> void:
	_update_info_label()


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
		print("[NetfoxTest] Launch with --server or --client to run the isolated Netfox test.")


func start_server() -> void:
	mode = "server"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		push_error("[NetfoxTest] Failed to start ENet server on port %d: %s" % [PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	print("[NetfoxTest] Server started on %s:%d peer=%d" % [ADDRESS, PORT, multiplayer.get_unique_id()])
	_spawn_player(BODY_AUTHORITY, _get_spawn_position(BODY_AUTHORITY))


func start_client() -> void:
	mode = "client"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ADDRESS, PORT)
	if error != OK:
		push_error("[NetfoxTest] Failed to connect ENet client to %s:%d: %s" % [ADDRESS, PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	print("[NetfoxTest] Client connecting to %s:%d" % [ADDRESS, PORT])


func _on_connected_to_server() -> void:
	print("[NetfoxTest] Client connected as peer %d; requesting spawn." % multiplayer.get_unique_id())
	request_spawn.rpc_id(BODY_AUTHORITY)


func _on_connection_failed() -> void:
	push_error("[NetfoxTest] Client connection failed.")


func _on_server_disconnected() -> void:
	print("[NetfoxTest] Server disconnected; clearing test players.")
	_clear_players()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("[NetfoxTest] Peer connected: %d. Waiting for spawn request." % peer_id)


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

	print("[NetfoxTest] Server received spawn request from peer %d." % requester_id)
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
		print("[NetfoxTest] Ignored duplicate spawn for %s at %s." % [player_name, players_root.get_node(player_name).get_path()])
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = player_name
	player.position = spawn_position
	players_root.add_child(player)
	spawned_players[peer_id] = spawn_position

	if player.has_method("setup_authority"):
		player.setup_authority(peer_id)

	print("[NetfoxTest] Spawned %s at %s pos=%s on peer %d." % [player_name, player.get_path(), spawn_position, multiplayer.get_unique_id()])


func _despawn_player(peer_id: int) -> void:
	var player_name := "Player_%d" % peer_id
	var player := players_root.get_node_or_null(player_name)
	if player != null:
		player.queue_free()
	spawned_players.erase(peer_id)


func _clear_players() -> void:
	for child in players_root.get_children():
		child.queue_free()
	spawned_players.clear()


func _get_spawn_position(_peer_id: int) -> Vector2:
	return Vector2(160.0 + float(spawned_players.size()) * 96.0, 240.0)


func _update_info_label() -> void:
	if info_label == null:
		return

	var peer_id := multiplayer.get_unique_id()
	var status := "offline"
	if multiplayer.multiplayer_peer != null:
		status = "server" if multiplayer.is_server() else "client"

	info_label.text = "Netfox Test %s\npeer %d mode %s\nplayers %d\n--server or --client" % [
		mode,
		peer_id,
		status,
		players_root.get_child_count()
	]
