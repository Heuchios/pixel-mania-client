extends Node2D

const PORT := 24565
const ADDRESS := "127.0.0.1"
const PLAYER_SCENE := preload("res://Scenes/player/netfox_player.tscn")
const BLOCK_SCENE := preload("res://Scenes/block.tscn")
const ITEM_DATABASE_PATH := "res://Scripts/item_database.gd"
const BODY_AUTHORITY := 1
const BLOCK_SIZE := 32
const WORLD_COLLISION_LAYER_MASK := 1
const LOG_PREFIX := "[NetfoxWorldCollisionTest]"
const NETFOX_DEBUG_ARG := "--netfox-debug-logs"
const NETFOX_DEBUG_ENV := "NETFOX_DEBUG_LOGS"
const COLLISION_DEBUG_ARG := "--netfox-collision-debug"
const COLLISION_DEBUG_ENV := "NETFOX_COLLISION_DEBUG"
const SERVER_PLAYER_ARG := "--server-player"
const SERVER_PLAYER_ENV := "NETFOX_SERVER_PLAYER"
const COLLISION_STATUS_FRAME_INTERVAL := 120
const TEST_BLOCK_TYPES := ["dirt", "stone", "wood_platform", "cave_background", "water"]

var spawned_players: Dictionary = {}
var blocks: Dictionary = {}
var background_blocks: Dictionary = {}
var item_database: Dictionary = {}
var block_textures: Dictionary = {}
var mode: String = "standalone"
var netfox_debug_logs: bool = false
var collision_debug_logs: bool = false
var spawn_server_player: bool = false

@onready var players_root: Node2D = $Players
@onready var world_root: Node2D = $World
@onready var background_root: Node2D = $World/BackgroundBlocks
@onready var solid_root: Node2D = $World/SolidBlocks
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	netfox_debug_logs = _is_flag_enabled(NETFOX_DEBUG_ARG, NETFOX_DEBUG_ENV)
	collision_debug_logs = _is_flag_enabled(COLLISION_DEBUG_ARG, COLLISION_DEBUG_ENV)
	spawn_server_player = _is_flag_enabled(SERVER_PLAYER_ARG, SERVER_PLAYER_ENV)
	_configure_netfox_logging()
	_mute_audio_for_server_or_headless()
	MovementMode.set_mode(MovementMode.Mode.NETFOX_TEST)
	_load_block_database()
	_build_test_world()
	_connect_multiplayer_signals()
	_parse_launch_mode()
	_update_info_label()


func _process(_delta: float) -> void:
	_update_info_label()
	if collision_debug_logs and Engine.get_process_frames() % COLLISION_STATUS_FRAME_INTERVAL == 0:
		_log_local_collision_status()


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
		print("%s Launch with --server or --client to run the isolated world collision test." % LOG_PREFIX)
		print("%s Add %s or set %s=1 for verbose Netfox logs." % [LOG_PREFIX, NETFOX_DEBUG_ARG, NETFOX_DEBUG_ENV])
		print("%s Add %s or set %s=1 for collision status logs." % [LOG_PREFIX, COLLISION_DEBUG_ARG, COLLISION_DEBUG_ENV])
		print("%s Add %s or set %s=1 to spawn a playable Player_1 on the server." % [LOG_PREFIX, SERVER_PLAYER_ARG, SERVER_PLAYER_ENV])


func start_server() -> void:
	mode = "server"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		push_error("%s Failed to start ENet server on port %d: %s" % [LOG_PREFIX, PORT, error])
		return

	multiplayer.multiplayer_peer = peer
	print("%s Server started on %s:%d peer=%d" % [LOG_PREFIX, ADDRESS, PORT, multiplayer.get_unique_id()])
	if spawn_server_player:
		_spawn_player(BODY_AUTHORITY, _get_spawn_position(BODY_AUTHORITY))
	else:
		print("%s Dedicated server player spawn disabled. Add %s or set %s=1 to spawn Player_1." % [
			LOG_PREFIX,
			SERVER_PLAYER_ARG,
			SERVER_PLAYER_ENV
		])


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
	return Vector2(128.0 + float(spawned_players.size()) * 96.0, 224.0)


func _load_block_database() -> void:
	var item_database_script = load(ITEM_DATABASE_PATH)
	if item_database_script != null:
		item_database = item_database_script.ITEMS.duplicate(true)

	for block_type in TEST_BLOCK_TYPES:
		var item_data = item_database.get(block_type, {})
		if not (item_data is Dictionary):
			continue

		var texture := _load_item_texture(item_data)
		if texture != null:
			block_textures[block_type] = texture


func _build_test_world() -> void:
	_clear_world()

	for x in range(-3, 32):
		if x == 13 or x == 14:
			continue
		_create_block(Vector2i(x, 10), "dirt")
		_create_block(Vector2i(x, 11), "stone")

	for x in range(-3, 32):
		_create_background_block(Vector2i(x, 9), "cave_background")

	for y in range(7, 10):
		_create_block(Vector2i(18, y), "stone")

	for x in range(6, 10):
		_create_block(Vector2i(x, 8), "wood_platform")

	for x in range(21, 25):
		_create_block(Vector2i(x, 8), "stone")

	_create_background_block(Vector2i(3, 7), "cave_background")
	_create_background_block(Vector2i(4, 7), "cave_background")
	_create_block(Vector2i(26, 9), "water")

	print("%s Built local PixelMania-style test world: solid=%d background=%d." % [
		LOG_PREFIX,
		blocks.size(),
		background_blocks.size()
	])


func _clear_world() -> void:
	for child in solid_root.get_children():
		child.queue_free()
	for child in background_root.get_children():
		child.queue_free()
	blocks.clear()
	background_blocks.clear()


func _create_block(grid_pos: Vector2i, block_type: String) -> void:
	if _is_background_block_type(block_type):
		_create_background_block(grid_pos, block_type)
		return
	if blocks.has(grid_pos):
		return

	var block := _instantiate_block(grid_pos, block_type, false)
	solid_root.add_child(block)
	blocks[grid_pos] = {
		"node": block,
		"type": block_type
	}


func _create_background_block(grid_pos: Vector2i, block_type: String) -> void:
	if background_blocks.has(grid_pos):
		return

	var block := _instantiate_block(grid_pos, block_type, true)
	background_root.add_child(block)
	background_blocks[grid_pos] = {
		"node": block,
		"type": block_type
	}


func _instantiate_block(grid_pos: Vector2i, block_type: String, background: bool) -> Node2D:
	var block := BLOCK_SCENE.instantiate() as Node2D
	block.name = "%s_%d_%d" % [block_type, grid_pos.x, grid_pos.y]
	block.position = Vector2(grid_pos.x * BLOCK_SIZE, grid_pos.y * BLOCK_SIZE)
	block.set_meta("grid_pos", grid_pos)
	block.set_meta("block_type", block_type)
	block.set_meta("background", background)
	_apply_block_visual(block, block_type, background)
	_configure_block_collision(block, block_type, background)
	return block


func _apply_block_visual(block: Node, block_type: String, background: bool) -> void:
	var visual := block.get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return

	var texture = block_textures.get(block_type, null)
	if texture != null:
		visual.texture = texture

	var item_data: Dictionary = item_database.get(block_type, {})
	visual.centered = bool(item_data.get("visual_centered", true))
	visual.position = _parse_block_vector2(item_data.get("visual_offset", Vector2.ZERO), Vector2.ZERO)
	visual.z_as_relative = true
	visual.z_index = -20 if background else 0
	visual.modulate = Color(1.0, 1.0, 1.0, 0.5) if background else Color.WHITE


func _configure_block_collision(block: Node, block_type: String, background: bool) -> void:
	if block is CollisionObject2D:
		var collision_object := block as CollisionObject2D
		collision_object.collision_layer = 0 if background else WORLD_COLLISION_LAYER_MASK
		collision_object.collision_mask = 0

	_apply_original_collision_layout(block, block_type)

	if _is_platform_collision_block_type(block_type):
		_set_original_block_collision_disabled(block, true)
		_add_platform_collision(block)
	elif background or _is_background_block_type(block_type) or _is_non_collideable_block(block_type):
		_set_original_block_collision_disabled(block, true)
	else:
		_set_original_block_collision_disabled(block, false)


func _apply_original_collision_layout(block: Node, block_type: String) -> void:
	var collision := block.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return

	var default_size := Vector2(float(BLOCK_SIZE), float(BLOCK_SIZE))
	var item_data: Dictionary = item_database.get(block_type, {})
	var collision_size := _parse_block_vector2(
		item_data.get("collision_size", item_data.get("visual_size", default_size)),
		default_size
	)
	var collision_offset := _parse_block_vector2(
		item_data.get("collision_offset", item_data.get("visual_offset", Vector2.ZERO)),
		Vector2.ZERO
	)
	var rect_shape := collision.shape.duplicate() as RectangleShape2D if collision.shape is RectangleShape2D else RectangleShape2D.new()
	rect_shape.size = collision_size
	collision.shape = rect_shape
	collision.position = collision_offset


func _set_original_block_collision_disabled(node: Node, disabled: bool) -> void:
	for child in node.get_children():
		if str(child.name).begins_with("WoodPlatform"):
			continue
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = disabled
		_set_original_block_collision_disabled(child, disabled)


func _add_platform_collision(block: Node) -> void:
	var collision_body := _get_block_collision_body(block)
	if collision_body == null:
		return

	var top_shape := RectangleShape2D.new()
	top_shape.size = Vector2(BLOCK_SIZE, 6)

	var top_collision := CollisionShape2D.new()
	top_collision.name = "WoodPlatformTopCollision"
	top_collision.shape = top_shape
	top_collision.position = Vector2(0, -13)
	top_collision.one_way_collision = true
	top_collision.one_way_collision_margin = 8.0
	collision_body.add_child(top_collision)


func _get_block_collision_body(node: Node) -> CollisionObject2D:
	if node is CollisionObject2D:
		return node as CollisionObject2D
	for child in node.get_children():
		var found := _get_block_collision_body(child)
		if found != null:
			return found
	return null


func _is_background_block_type(block_type: String) -> bool:
	var item_data: Dictionary = item_database.get(block_type, {})
	return bool(item_data.get("background_block", false)) or str(item_data.get("place_layer", "")) == "background"


func _is_platform_collision_block_type(block_type: String) -> bool:
	var item_data: Dictionary = item_database.get(block_type, {})
	return bool(item_data.get("platform_collision", false))


func _is_non_collideable_block(block_type: String) -> bool:
	var item_data: Dictionary = item_database.get(block_type, {})
	if item_data.has("collidable"):
		return not bool(item_data.get("collidable", true))
	if item_data.has("no_collision"):
		return bool(item_data.get("no_collision", false))
	return false


func _parse_block_vector2(raw_value, fallback := Vector2.ZERO) -> Vector2:
	if raw_value is Vector2:
		return raw_value
	if raw_value is Vector2i:
		return Vector2(float(raw_value.x), float(raw_value.y))
	if raw_value is Array and raw_value.size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	if raw_value is Dictionary:
		return Vector2(float(raw_value.get("x", fallback.x)), float(raw_value.get("y", fallback.y)))
	return fallback


func _load_item_texture(item_data: Dictionary) -> Texture2D:
	var texture_spec = item_data.get("texture", "")
	if texture_spec is String:
		var path := str(texture_spec)
		return load(path) if path != "" and ResourceLoader.exists(path) else null

	if not (texture_spec is Dictionary):
		return null

	var atlas_path := str(texture_spec.get("atlas", ""))
	if atlas_path == "" or not ResourceLoader.exists(atlas_path):
		return null

	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		return null

	var region := Rect2()
	if texture_spec.has("region"):
		var raw_region = texture_spec.get("region")
		if raw_region is Array and raw_region.size() >= 4:
			region = Rect2(float(raw_region[0]), float(raw_region[1]), float(raw_region[2]), float(raw_region[3]))
	elif texture_spec.has("cell"):
		var cell_size := _parse_block_vector2(texture_spec.get("cell_size", [BLOCK_SIZE, BLOCK_SIZE]), Vector2(BLOCK_SIZE, BLOCK_SIZE))
		var cell := _parse_block_vector2(texture_spec.get("cell", [0, 0]), Vector2.ZERO)
		region = Rect2(cell * cell_size, cell_size)
	elif texture_spec.has("index"):
		var cell_size := _parse_block_vector2(texture_spec.get("cell_size", [BLOCK_SIZE, BLOCK_SIZE]), Vector2(BLOCK_SIZE, BLOCK_SIZE))
		var columns := maxi(1, int(texture_spec.get("columns", 1)))
		var index := int(texture_spec.get("index", 0))
		region = Rect2(Vector2(index % columns, index / columns) * cell_size, cell_size)

	if region.size == Vector2.ZERO:
		return atlas

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas
	atlas_texture.region = region
	return atlas_texture


func _get_local_player() -> Node:
	var peer_id := _get_local_peer_id()
	if peer_id == 0:
		peer_id = BODY_AUTHORITY
	return players_root.get_node_or_null("Player_%d" % peer_id)


func _get_block_type_under_position(world_position: Vector2) -> String:
	var grid_pos := Vector2i(int(round(world_position.x / BLOCK_SIZE)), int(floor((world_position.y + 33.0) / BLOCK_SIZE)))
	if blocks.has(grid_pos):
		return str(blocks[grid_pos].get("type", ""))
	if background_blocks.has(grid_pos):
		return "background:" + str(background_blocks[grid_pos].get("type", ""))
	return "air"


func _log_local_collision_status() -> void:
	var player := _get_local_player()
	if player == null:
		return

	print("%s Collision peer=%d player=%s pos=%s vel=%s floor=%s under=%s layer=%d mask=%d rollback_tick=%d" % [
		LOG_PREFIX,
		_get_local_peer_id(),
		player.get_path(),
		Vector2(roundf(player.global_position.x), roundf(player.global_position.y)),
		Vector2(roundf(player.get("velocity").x), roundf(player.get("velocity").y)),
		str(player.is_on_floor() if player.has_method("is_on_floor") else false),
		_get_block_type_under_position(player.global_position),
		int(player.get("collision_layer")),
		int(player.get("collision_mask")),
		int(player.get("rollback_tick_count"))
	])


func _update_info_label() -> void:
	if info_label == null:
		return

	var peer_id := _get_local_peer_id()
	var status := "offline"
	if peer_id != 0:
		status = "server" if multiplayer.is_server() else "client"

	var player := _get_local_player()
	var player_path := "none"
	var player_position := Vector2.ZERO
	var player_velocity := Vector2.ZERO
	var floor_text := "false"
	var under_block := "air"
	var layer_mask := "0/0"
	var rollback_tick := 0
	if player != null:
		player_path = str(player.get_path())
		player_position = Vector2(roundf(player.global_position.x), roundf(player.global_position.y))
		player_velocity = Vector2(roundf(player.get("velocity").x), roundf(player.get("velocity").y))
		floor_text = str(player.is_on_floor() if player.has_method("is_on_floor") else false)
		under_block = _get_block_type_under_position(player.global_position)
		layer_mask = "%d/%d" % [int(player.get("collision_layer")), int(player.get("collision_mask"))]
		rollback_tick = int(player.get("rollback_tick_count"))

	info_label.text = "Netfox World Collision Test %s\npeer %d mode %s players %d blocks %d bg %d\n%s\npos %s vel %s floor %s under %s\nlayer/mask %s rollback %d" % [
		mode,
		peer_id,
		status,
		players_root.get_child_count(),
		blocks.size(),
		background_blocks.size(),
		player_path,
		player_position,
		player_velocity,
		floor_text,
		under_block,
		layer_mask,
		rollback_tick
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


func _is_flag_enabled(arg_name: String, env_name: String) -> bool:
	if MovementMode.has_launch_arg(arg_name):
		return true

	var env_value := OS.get_environment(env_name).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func _mute_audio_for_server_or_headless() -> void:
	if not MovementMode.has_launch_arg("--server") and DisplayServer.get_name() != "headless":
		return

	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
