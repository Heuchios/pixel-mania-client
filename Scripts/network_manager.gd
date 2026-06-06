extends Node

signal server_auth_finished(data)
signal server_connection_changed(is_connected)
signal world_population_changed(world_counts)

var socket := WebSocketPeer.new()
var connected := false
var player_id := ""
var player_name := "Guest"
var session_username := ""
var session_email := ""
var session_token := ""
var session_role := "player"
var session_authenticated := false
var server_session_authenticated := false
var developer_pin_required := false
var developer_pin_unlocked := false
var current_world_name := "START"
var pending_join_enabled := false
var pending_join_world_name := ""
var pending_join_profile_name := ""
var pending_server_player_state := {}
var pending_player_state_requests := {}
var world_population_counts := {}
var world_population_players := {}
var login_notice_message := ""
var auth_request_counter := 0
var developer_pin_unlock_request_counter := 0
var reconnect_timer := 0.0
var server_url_index := 0
var active_api_base := ""
var active_server_urls: Array[String] = []
var last_connection_attempt_url := ""
var last_connection_error := ""
var last_connection_started_at := 0
var last_close_code := -1
var last_close_reason := ""
var last_ready_state := WebSocketPeer.STATE_CLOSED
var login_redirect_pending := false

const API_BASE := "https://api.pixelmaniagame.com"
const WS_URL := "wss://api.pixelmaniagame.com/ws"
const CLIENT_VERSION := "1.0.1"
const CLIENT_PLATFORM := "godot"
const DEBUG_SERVER_PACKETS := false
const DEBUG_ACTION_POSITION_FLOW := false
const DEBUG_PLAYER_STATE_LOOKUP := false
const PLAYER_STATE_REQUEST_TIMEOUT_MS := 15000
const SERVER_URLS := [WS_URL]
const NETWORK_API_OVERRIDE_SETTING := "pixelmania/network/api_base"
const NETWORK_WS_OVERRIDE_SETTING := "pixelmania/network/ws_url"
const RECONNECT_INTERVAL := 2.0
const PROFILE_PATH := "user://pixelmania_profile.cfg"
const LOGIN_SCENE := "res://Scenes/login_screen.tscn"
const MAX_CHAT_MESSAGE_LENGTH := 220
const MAX_BROADCAST_LENGTH := 260
const MAX_SERVER_MESSAGE_TYPE_LENGTH := 64
const MAX_SERVER_MESSAGE_BYTES := 32768
const MAX_USERNAME_LENGTH := 64
const MAX_WORLD_NAME_LENGTH := 64
const MAX_ITEM_ID_LENGTH := 64
const MAX_REQUEST_ID_LENGTH := 64
const MAX_COORDINATE := 1000000
const MAX_ITEM_CATEGORY_LENGTH := 64
const MAX_ITEM_STACK_SIZE := 200
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_ITEM_PRICE := 999999
const MAX_INVENTORY_TRANSACTION_RATE_PER_SECOND := 20
const MAX_WORLD_BLOCK_RATE_PER_SECOND := 30
const MAX_WORLD_SEED_RATE_PER_SECOND := 20
const MAX_WORLD_INTERACTION_RATE_PER_SECOND := 20
const MAX_WORLD_DROP_RATE_PER_SECOND := 24
const MAX_CHAT_RATE_PER_SECOND := 8
const MAX_BROADCAST_RATE_PER_SECOND := 5
const MAX_PULL_RATE_PER_SECOND := 6
const MAX_WORLD_SEED_GROW_TIME_SECONDS := 3600.0 * 24.0 * 30.0
const MAX_BLOCK_HIT_METRIC := 1024
const MAX_PLAYER_POSITION_RATE_PER_SECOND := 45
const MAX_TRADE_RATE_PER_SECOND := 14
const MAX_FRIEND_RATE_PER_SECOND := 8
const MAX_TRADE_SLOT_INDEX := 31
const MAX_TRADE_ID_LENGTH := 96
const MAX_WORLD_POPULATION_RATE_PER_SECOND := 10
const MAX_WORLD_POPULATION_REQUEST_SIZE := 64
const MAX_WORLD_INTERACTION_TEXT_LENGTH := 128
const MIN_PLAYER_COORDINATE := -1000000
const MAX_PLAYER_COORDINATE := 1000000
const WORLD_POPULATION_RESET_UNRESPONSIVE_AFTER_SECONDS := 600.0
const PICKUP_REMAINING_AMOUNT_UNKNOWN := -2147483648

const WORLD_BLOCK_ACTIONS := ["hit", "place", "break"]
const WORLD_BLOCK_LAYERS := ["foreground", "background"]
const WORLD_SEED_ACTIONS := ["place", "splice", "remove"]
const WORLD_INTERACTION_ACTIONS := [
	"wooden_entrance_state",
	"sign_text",
	"world_lock_state",
	"vend_state",
	"safe_state",
	"entrance_gate_move"
]

const INVENTORY_TRANSACTION_ACTIONS := [
	"craft_recipe",
	"furnace_recipe",
	"safe_get_state",
	"safe_deposit",
	"safe_withdraw",
	"seed_splice",
	"seed_place",
	"seed_harvest",
	"trash_inventory_item",
	"fish_monger_sell",
	"fish_monger_sell_all",
	"fishing_start",
	"fishing_complete",
	"drop_inventory_item",
	"shop_buy",
	"vend_get_state",
	"vend_set_listing",
	"vend_buy",
	"vend_collect",
	"vend_cancel"
]

const AUTH_ROLE_PLAYER := "player"
const AUTH_ROLE_MODERATOR := "moderator"
const AUTH_ROLE_DEVELOPER := "developer"
const AUTH_ROLE_ADMIN := "admin"

var _send_rate_counters := {}


func debug_action_position_flow(message: String, extra_data: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return

	var player_pos_text = "none"
	var world_name_text = ""
	var world_node = get_world_node()
	if world_node != null:
		world_name_text = str(world_node.get("current_world_name")) if "current_world_name" in world_node else ""
		var local_player = world_node.get("player") if "player" in world_node else null
		if local_player != null:
			player_pos_text = str(local_player.global_position)

	print("[PM_FLOW][NetworkManager] " + message + " net_world=" + current_world_name + " world=" + world_name_text + " player_pos=" + player_pos_text + " data=" + str(extra_data))


func _ready():
	configure_network_urls()
	connect_to_server()


func _process(delta):
	socket.poll()

	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED and last_ready_state != WebSocketPeer.STATE_CLOSED:
		last_close_code = socket.get_close_code()
		last_close_reason = socket.get_close_reason()
		if last_connection_error == "" and not connected:
			last_connection_error = "closed before opening"
	last_ready_state = state

	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		server_session_authenticated = false
		last_connection_error = ""
		last_close_code = -1
		last_close_reason = ""
		server_connection_changed.emit(true)
		print("Connected to PixelMania server")
		send_message(make_login_payload())
		if has_active_session():
			send_account_token_login(session_username, session_token)

	if state == WebSocketPeer.STATE_CLOSED and connected:
		var had_active_session := has_active_session()
		var close_code := last_close_code
		var close_reason := last_close_reason
		connected = false
		server_session_authenticated = false
		server_connection_changed.emit(false)
		if had_active_session:
			_end_authenticated_session(
				_make_disconnect_login_notice(close_code, close_reason),
				_should_clear_saved_login_for_close(close_code, close_reason),
				false
			)

	if state == WebSocketPeer.STATE_CLOSED:
		reconnect_timer -= delta
		if reconnect_timer <= 0.0:
			advance_server_url()
			reconnect_timer = RECONNECT_INTERVAL
			connect_to_server()

	while socket.get_available_packet_count() > 0:
		var packet = socket.get_packet().get_string_from_utf8()
		handle_server_message(packet)

	apply_pending_server_player_state_if_ready()


func configure_network_urls() -> void:
	active_api_base = API_BASE
	active_server_urls = [WS_URL]

	if not should_allow_network_override():
		return

	var api_override = str(ProjectSettings.get_setting(NETWORK_API_OVERRIDE_SETTING, "")).strip_edges()
	var ws_override = str(ProjectSettings.get_setting(NETWORK_WS_OVERRIDE_SETTING, "")).strip_edges()

	for arg in OS.get_cmdline_user_args():
		var clean_arg = str(arg).strip_edges()
		if clean_arg.begins_with("--pixelmania-api-base="):
			api_override = clean_arg.trim_prefix("--pixelmania-api-base=").strip_edges()
		elif clean_arg.begins_with("--pixelmania-ws-url="):
			ws_override = clean_arg.trim_prefix("--pixelmania-ws-url=").strip_edges()

	if api_override.begins_with("http://") or api_override.begins_with("https://"):
		active_api_base = api_override

	if ws_override.begins_with("ws://") or ws_override.begins_with("wss://"):
		active_server_urls = [ws_override]


func should_allow_network_override() -> bool:
	if OS.has_feature("android") or OS.get_name().to_lower() == "android":
		return false

	return OS.has_feature("editor") or OS.has_feature("debug") or OS.get_name() == "Windows"


func connect_to_server(force: bool = false) -> void:
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		return

	if state == WebSocketPeer.STATE_CONNECTING:
		if not force:
			return
		socket.close()

	if active_server_urls.is_empty():
		return

	socket = WebSocketPeer.new()
	var server_url = active_server_urls[server_url_index % active_server_urls.size()]
	last_connection_attempt_url = server_url
	last_connection_started_at = Time.get_ticks_msec()
	last_connection_error = ""
	last_close_code = -1
	last_close_reason = ""
	last_ready_state = WebSocketPeer.STATE_CLOSED

	var error = OK
	if server_url.begins_with("wss://"):
		error = socket.connect_to_url(server_url, TLSOptions.client())
	else:
		error = socket.connect_to_url(server_url)

	if error != OK:
		last_connection_error = "connect_to_url error " + str(error)
		print("Server connection failed: ", error, " url=", server_url)
		advance_server_url()
		reconnect_timer = RECONNECT_INTERVAL
	else:
		print("Connecting to PixelMania server: ", server_url)


func request_server_connection(force: bool = false) -> void:
	if active_server_urls.is_empty():
		configure_network_urls()
	connect_to_server(force)


func advance_server_url() -> void:
	if active_server_urls.size() <= 1:
		return
	server_url_index = (server_url_index + 1) % active_server_urls.size()


func is_connected_to_server() -> bool:
	return connected and socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_server_session_authenticated() -> bool:
	return is_connected_to_server() and server_session_authenticated and has_active_session()


func can_send_authenticated_payload() -> bool:
	return is_server_session_authenticated()


func get_server_connection_state_text() -> String:
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			return "connected"
		WebSocketPeer.STATE_CONNECTING:
			return "connecting"
		WebSocketPeer.STATE_CLOSING:
			return "closing"
		_:
			if last_connection_error != "":
				return last_connection_error
			return "closed"


func get_connection_debug_summary() -> String:
	var parts = PackedStringArray()
	parts.append("url=" + last_connection_attempt_url)
	parts.append("state=" + get_server_connection_state_text())
	if last_close_code != -1:
		parts.append("close_code=" + str(last_close_code))
	if last_close_reason != "":
		parts.append("close_reason=" + last_close_reason)
	return " ".join(parts)


func get_login_notice_message() -> String:
	return login_notice_message


func set_login_notice_message(message: String) -> void:
	login_notice_message = message


func get_active_session_username() -> String:
	return session_username.strip_edges()


func get_active_session_email() -> String:
	return session_email.strip_edges()


func get_active_session_role() -> String:
	return session_role.strip_edges().to_lower()


func get_client_version() -> String:
	return CLIENT_VERSION


func is_developer_session() -> bool:
	return get_active_session_role() == AUTH_ROLE_DEVELOPER or get_active_session_role() == AUTH_ROLE_ADMIN


func is_moderator_session() -> bool:
	var role = get_active_session_role()
	return role == AUTH_ROLE_DEVELOPER or role == AUTH_ROLE_ADMIN or role == AUTH_ROLE_MODERATOR


func is_developer_pin_required() -> bool:
	return developer_pin_required


func is_developer_pin_unlocked() -> bool:
	return developer_pin_unlocked


func has_active_session() -> bool:
	return session_authenticated and session_username.strip_edges() != "" and session_token.strip_edges() != ""


func set_active_session(username: String, email: String = "", token: String = "", role: String = AUTH_ROLE_PLAYER) -> void:
	session_username = username.strip_edges()
	session_email = email.strip_edges()
	session_token = token.strip_edges()
	session_role = role.strip_edges().to_lower()
	if session_role == "":
		session_role = AUTH_ROLE_PLAYER
	session_authenticated = session_username != "" and session_token != ""
	if session_authenticated:
		player_name = session_username


func clear_runtime_session() -> void:
	session_username = ""
	session_email = ""
	session_token = ""
	session_role = "player"
	session_authenticated = false
	server_session_authenticated = false
	developer_pin_required = false
	developer_pin_unlocked = false


func clear_active_session() -> void:
	clear_runtime_session()


func _end_authenticated_session(message: String, clear_saved_login: bool = false, close_socket: bool = false) -> void:
	var notice = message.strip_edges()
	if notice == "":
		notice = "Disconnected from server. Sign on again."

	login_notice_message = notice
	pending_join_enabled = false
	pending_join_world_name = ""
	pending_join_profile_name = ""
	pending_server_player_state.clear()
	pending_player_state_requests.clear()
	world_population_counts.clear()
	world_population_players.clear()
	clear_runtime_session()
	player_name = "Guest"

	_clear_pending_join_profile_config()
	if clear_saved_login:
		_clear_saved_session_token()

	if close_socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "Session ended.")

	_queue_login_redirect()


func _clear_pending_join_profile_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(PROFILE_PATH)


func _clear_saved_session_token() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_PATH)
	cfg.set_value("profile", "session_token", "")
	cfg.set_value("profile", "remember_login", false)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(PROFILE_PATH)


func _make_disconnect_login_notice(close_code: int, close_reason: String) -> String:
	var reason = close_reason.strip_edges()
	if close_code == 1008 or reason.to_lower().find("restricted") != -1:
		return "Account restricted. Sign on again."
	if close_code == 4001 or reason.to_lower().find("elsewhere") != -1:
		return "This account signed on somewhere else."
	if reason != "":
		return "Disconnected from server: " + reason
	return "Disconnected from server. Sign on again."


func _should_clear_saved_login_for_close(close_code: int, close_reason: String) -> bool:
	var reason = close_reason.strip_edges().to_lower()
	return close_code == 1008 or close_code == 4001 or reason.find("restricted") != -1 or reason.find("elsewhere") != -1


func _message_has_session_ending_punishment(data: Dictionary) -> bool:
	if data == null:
		return false
	var punishment = data.get("punishment", null)
	if not (punishment is Dictionary):
		return false
	var punishment_type = str(punishment.get("punishment_type", punishment.get("type", ""))).strip_edges().to_lower()
	return punishment_type == "ban" or punishment_type == "lockout"


func _is_login_scene_active() -> bool:
	var scene = get_tree().current_scene
	if scene == null:
		return false
	return str(scene.scene_file_path) == LOGIN_SCENE or scene.name == "LoginScreen"


func _queue_login_redirect() -> void:
	if login_redirect_pending or _is_login_scene_active():
		return
	login_redirect_pending = true
	call_deferred("_redirect_to_login_scene")


func _redirect_to_login_scene() -> void:
	login_redirect_pending = false
	if _is_login_scene_active():
		return
	get_tree().change_scene_to_file(LOGIN_SCENE)


func make_auth_request_id() -> String:
	auth_request_counter += 1
	return str(Time.get_ticks_msec()) + "_" + str(auth_request_counter)


func make_login_payload() -> Dictionary:
	var payload = {
		"type": "login",
		"name": player_name
	}
	if has_active_session():
		payload["username"] = session_username
		payload["email"] = session_email
		payload["session_token"] = session_token
		payload["role"] = session_role
	return payload


func send_message(data: Dictionary) -> bool:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false

	var outgoing = data.duplicate(true)
	outgoing["client_version"] = CLIENT_VERSION
	outgoing["client_platform"] = CLIENT_PLATFORM
	var payload_text = JSON.stringify(outgoing)
	if payload_text.to_utf8_buffer().size() > MAX_SERVER_MESSAGE_BYTES:
		return false
	socket.send_text(payload_text)
	return true


func attach_session_auth(payload: Dictionary) -> Dictionary:
	payload["client_version"] = CLIENT_VERSION
	payload["client_platform"] = CLIENT_PLATFORM
	if has_active_session():
		if not payload.has("username"):
			payload["username"] = session_username
		if not payload.has("email"):
			payload["email"] = session_email
		payload["session_token"] = session_token
	return payload


func send_account_register(username: String, email: String, password: String) -> String:
	if not is_connected_to_server():
		return ""
	var request_id = make_auth_request_id()
	send_message({
		"type": "account_register",
		"request_id": request_id,
		"username": username.strip_edges(),
		"email": email.strip_edges(),
		"password": password
	})
	return request_id


func send_account_login(username: String, email: String, password: String) -> String:
	if not is_connected_to_server():
		return ""
	var request_id = make_auth_request_id()
	send_message({
		"type": "account_login",
		"request_id": request_id,
		"username": username.strip_edges(),
		"email": email.strip_edges(),
		"password": password
	})
	return request_id


func send_account_token_login(username: String, token: String) -> String:
	if not is_connected_to_server():
		return ""
	var clean_token = token.strip_edges()
	if clean_token == "":
		return ""
	var request_id = make_auth_request_id()
	send_message({
		"type": "account_token_login",
		"request_id": request_id,
		"username": username.strip_edges(),
		"session_token": clean_token
	})
	return request_id


func send_account_state_save(username: String = "", email: String = "", token: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	var clean_username = username.strip_edges()
	if clean_username == "":
		clean_username = session_username
	var clean_email = email.strip_edges()
	if clean_email == "":
		clean_email = session_email
	var clean_token = token.strip_edges()
	if clean_token == "":
		clean_token = session_token
	return send_message({
		"type": "account_state_save",
		"username": clean_username,
		"email": clean_email,
		"session_token": clean_token
	})


func send_friend_list_request() -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("friend", MAX_FRIEND_RATE_PER_SECOND):
		return false
	return send_message(attach_session_auth({
		"type": "friend_list_request",
		"request_id": make_auth_request_id()
	}))


func send_friend_request(target_username: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("friend", MAX_FRIEND_RATE_PER_SECOND):
		return false
	var clean_username: String = _safe_string(target_username, "", MAX_USERNAME_LENGTH)
	if clean_username == "":
		return false
	return send_message(attach_session_auth({
		"type": "friend_request",
		"request_id": make_auth_request_id(),
		"target_username": clean_username
	}))


func send_friend_response(from_username: String, accepted: bool) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("friend", MAX_FRIEND_RATE_PER_SECOND):
		return false
	var clean_username: String = _safe_string(from_username, "", MAX_USERNAME_LENGTH)
	if clean_username == "":
		return false
	return send_message(attach_session_auth({
		"type": "friend_response",
		"request_id": make_auth_request_id(),
		"from_username": clean_username,
		"accepted": accepted
	}))


func send_player_state_request(username: String = "") -> bool:
	return send_player_state_request_with_context(username, {"purpose": "active_profile"}) != ""


func send_player_state_request_with_context(username: String = "", context: Dictionary = {}) -> String:
	if not is_server_session_authenticated():
		return ""
	var clean_username = username.strip_edges()
	if clean_username == "":
		clean_username = session_username
	if clean_username == "":
		return ""
	var request_id = make_auth_request_id()
	var request_started_ms = Time.get_ticks_msec()
	var payload = {
		"type": "player_state_request",
		"request_id": request_id,
		"username": clean_username
	}
	var request_purpose = str(context.get("purpose", "")).strip_edges()
	if request_purpose != "":
		payload["purpose"] = request_purpose
	if context.has("requested_username"):
		payload["requested_username"] = str(context.get("requested_username", "")).strip_edges()
	if context.has("selected_role"):
		payload["selected_role"] = str(context.get("selected_role", "")).strip_edges()
	if context.has("limit"):
		payload["limit"] = int(context.get("limit", 0))
	var request_sent = send_message(attach_session_auth(payload))
	if not request_sent:
		return ""
	var request_entry: Dictionary = {
		"username": clean_username,
		"context": context.duplicate(true),
		"created_at_ms": request_started_ms,
		"timeout_ms": request_started_ms + PLAYER_STATE_REQUEST_TIMEOUT_MS
	}
	for key in context.keys():
		request_entry[key] = context[key]
	pending_player_state_requests[request_id] = request_entry
	_log_player_state_lookup("queued player state request", {
		"request_id": request_id,
		"username": clean_username,
		"purpose": str(request_entry.get("purpose", "")),
		"timeout_ms": request_entry["timeout_ms"]
	})
	return request_id


func send_player_state_save(player_data: Dictionary, extra_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		return false
	var clean_username = str(player_data.get("account_username", "")).strip_edges()
	if clean_username == "":
		clean_username = session_username
	if clean_username == "":
		return false
	var payload = player_data.duplicate(true)
	for key in extra_data.keys():
		payload[key] = extra_data[key]
	payload["type"] = "player_state_save"
	payload["username"] = clean_username
	payload["account_username"] = clean_username
	payload["email"] = session_email
	payload["session_token"] = session_token
	payload["world"] = current_world_name
	return send_message(payload)


func _extract_player_state_request_id(data: Dictionary) -> String:
	if data == null:
		return ""

	var direct_request_id = str(data.get("request_id", "")).strip_edges()
	if direct_request_id != "":
		return direct_request_id

	for key in ["data", "player_data", "account", "account_data"]:
		var nested_data = data.get(key, null)
		if nested_data is Dictionary:
			var nested_request_id = _extract_player_state_request_id(nested_data)
			if nested_request_id != "":
				return nested_request_id

	return ""


func _cleanup_expired_player_state_requests() -> void:
	if pending_player_state_requests.is_empty():
		return

	var now_ms = Time.get_ticks_msec()
	var expired: Array = []
	for request_id in pending_player_state_requests.keys():
		var request_data = pending_player_state_requests[request_id]
		if not (request_data is Dictionary):
			expired.append(request_id)
			continue

		var timeout_ms = int(request_data.get("timeout_ms", 0))
		if timeout_ms <= 0:
			continue

		if now_ms > timeout_ms:
			expired.append(request_id)

	for expired_request_id in expired:
		pending_player_state_requests.erase(expired_request_id)
		_log_player_state_lookup("expired player state request", {"request_id": expired_request_id})


func _log_player_state_lookup(message: String, data: Dictionary = {}) -> void:
	if not DEBUG_PLAYER_STATE_LOOKUP:
		return
	print("[PM_LOOKUP] " + message + " | " + str(data))


func set_pending_join(world_name: String, profile_name: String = "") -> void:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return
	pending_join_enabled = true
	pending_join_world_name = clean_world
	pending_join_profile_name = profile_name.strip_edges()


func has_pending_join() -> bool:
	return pending_join_enabled and pending_join_world_name.strip_edges() != ""


func get_world_player_count(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0
	return int(world_population_counts.get(clean_world, 0))


func request_world_population(world_names: Array = []) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_population", MAX_WORLD_POPULATION_RATE_PER_SECOND):
		return false
	if not (world_names is Array):
		world_names = []

	var sanitized_worlds = []
	var seen = {}
	for raw_name in world_names:
		var clean_world = _safe_world_name(raw_name)
		if clean_world == "":
			continue
		if seen.has(clean_world):
			continue
		seen[clean_world] = true
		sanitized_worlds.append(clean_world)
		if sanitized_worlds.size() >= MAX_WORLD_POPULATION_REQUEST_SIZE:
			break

	return send_message(attach_session_auth({
		"type": "world_population_request",
		"worlds": sanitized_worlds
	}))


func consume_pending_join() -> Dictionary:
	var data = {
		"enabled": pending_join_enabled,
		"world_name": pending_join_world_name,
		"profile_name": pending_join_profile_name
	}
	pending_join_enabled = false
	pending_join_world_name = ""
	pending_join_profile_name = ""
	return data


func send_join_world(world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	sync_player_name_from_world()
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"
	current_world_name = clean_world
	debug_action_position_flow("send_join_world", {
		"world": current_world_name
	})
	return send_message(attach_session_auth({
		"type": "join_world",
		"world": current_world_name
	}))


func send_leave_world(world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return false
	return send_message(attach_session_auth({
		"type": "leave_world",
		"world": clean_world
	}))


func send_chat_message(message: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("chat", MAX_CHAT_RATE_PER_SECOND):
		return false
	var clean_message = _safe_string(message, "", MAX_CHAT_MESSAGE_LENGTH)
	if clean_message == "":
		return false
	sync_player_name_from_world()
	return send_message(attach_session_auth({
		"type": "chat",
		"message": clean_message
	}))


func send_broadcast_message(message: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("broadcast", MAX_BROADCAST_RATE_PER_SECOND):
		return false
	var clean_message = _safe_string(message, "", MAX_BROADCAST_LENGTH)
	if clean_message == "":
		return false
	sync_player_name_from_world()
	var clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		clean_world = "START"
	return send_message(attach_session_auth({
		"type": "broadcast",
		"message": clean_message,
		"world": clean_world
	}))


func send_pull_player_request(target_username: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("pull", MAX_PULL_RATE_PER_SECOND):
		return false
	var clean_username: String = _safe_string(target_username, "", MAX_USERNAME_LENGTH)
	if clean_username == "":
		return false
	var clean_world: String = _safe_world_name(current_world_name)
	if clean_world == "":
		clean_world = "START"
	flush_current_world_position_for_action("pull_player_request")
	return send_message(attach_session_auth({
		"type": "pull_player_request",
		"request_id": make_auth_request_id(),
		"target_username": clean_username,
		"world": clean_world
	}))


func send_world_block_update(action: String, layer: String, grid_pos: Vector2i, block_type: String, world_name: String, extra_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_block_update", MAX_WORLD_BLOCK_RATE_PER_SECOND):
		return false
	var clean_action = _safe_string(action, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_BLOCK_ACTIONS.has(clean_action):
		return false
	var clean_layer = _safe_string(layer, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_BLOCK_LAYERS.has(clean_layer):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "world_block_update",
		"action": clean_action,
		"layer": clean_layer,
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE),
		"block_type": _safe_string(block_type, "", MAX_ITEM_ID_LENGTH),
		"world": clean_world
	}
	if extra_data.has("hit_power"):
		payload["hit_power"] = _safe_int(extra_data.get("hit_power", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if extra_data.has("hit_count"):
		payload["hit_count"] = _safe_int(extra_data.get("hit_count", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if extra_data.has("max_hits"):
		payload["max_hits"] = _safe_int(extra_data.get("max_hits", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_world_seed_update(action: String, grid_pos: Vector2i, seed_type: String, grow_time: float, max_grow_time: float, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_seed_update", MAX_WORLD_SEED_RATE_PER_SECOND):
		return false
	var clean_action = _safe_string(action, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_SEED_ACTIONS.has(clean_action):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	var payload = {
		"type": "world_seed_update",
		"action": clean_action,
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE),
		"seed_type": _safe_string(seed_type, "", MAX_ITEM_ID_LENGTH),
		"grow_time": _safe_float(grow_time, 0.0, 0.0, MAX_WORLD_SEED_GROW_TIME_SECONDS),
		"max_grow_time": _safe_float(max_grow_time, 0.0, 0.0, MAX_WORLD_SEED_GROW_TIME_SECONDS),
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_world_interaction_update(interaction_data: Dictionary, world_name: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_interaction_update", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var payload = interaction_data.duplicate(true)
	var clean_action = _safe_string(payload.get("action", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_INTERACTION_ACTIONS.has(clean_action):
		return false
	payload["type"] = "world_interaction_update"
	payload["action"] = clean_action
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(str(payload.get("world", current_world_name)))
	payload["world"] = clean_world
	match clean_action:
		"wooden_entrance_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["locked"] = _safe_bool(payload.get("locked", false), false)
		"sign_text":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["text"] = _safe_string(payload.get("text", ""), "", MAX_WORLD_INTERACTION_TEXT_LENGTH)
		"world_lock_state":
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
			payload["requested_by"] = _safe_string(payload.get("requested_by", ""), "", MAX_USERNAME_LENGTH)
			payload["owner_verified"] = _safe_bool(payload.get("owner_verified", false), false)
			payload["strict_mode"] = _safe_bool(payload.get("strict_mode", false), false)
		"vend_state", "safe_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"entrance_gate_move":
			payload["old_x"] = _safe_int(payload.get("old_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["old_y"] = _safe_int(payload.get("old_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_world_item_drop_create(drop_data: Dictionary, world_name: String) -> bool:
	return send_world_item_drop_message("world_item_drop_create", drop_data, world_name)


func send_world_item_drop_update(drop_data: Dictionary, world_name: String) -> bool:
	return send_world_item_drop_message("world_item_drop_update", drop_data, world_name)


func send_world_item_drop_pickup(drop_data: Dictionary, _world_name: String = "") -> bool:
	if not (drop_data is Dictionary):
		return false
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_drop_pickup", MAX_WORLD_DROP_RATE_PER_SECOND):
		return false

	var safe_drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if safe_drop_id == "":
		return false

	var payload = {
		"type": "world_item_drop_pickup",
		"drop_id": safe_drop_id
	}

	# Pickup is authoritative: the server resolves the world from the session.
	# Include the current action position too so pickup distance validation does
	# not depend on a separate movement packet arriving first.
	var world_node = get_world_node()
	if world_node != null and is_world_node_active():
		var action_world = _safe_world_name(current_world_name)
		if "current_world_name" in world_node:
			action_world = _safe_world_name(str(world_node.get("current_world_name")))
		if action_world != "":
			payload["world"] = action_world
		if "player_facing_direction" in world_node:
			payload["facing"] = 1 if int(world_node.get("player_facing_direction")) >= 0 else -1
		if "player" in world_node:
			var local_player = world_node.get("player")
			if local_player != null:
				var action_position = local_player.global_position
				payload["x"] = clamp(float(action_position.x), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
				payload["y"] = clamp(float(action_position.y), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)

	flush_current_world_position_for_action("world_item_drop_pickup")
	return send_message(attach_session_auth(payload))


func send_world_item_drop_message(message_type: String, drop_data: Dictionary, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_drop", MAX_WORLD_DROP_RATE_PER_SECOND):
		return false
	var clean_message_type = _safe_string(message_type, "", MAX_ITEM_ID_LENGTH).to_lower()
	if clean_message_type == "world_item_drop_pickup":
		return send_world_item_drop_pickup(drop_data)
	if clean_message_type != "world_item_drop_create" and clean_message_type != "world_item_drop_update":
		return false
	var payload = drop_data.duplicate(true)
	payload["type"] = clean_message_type
	payload["world"] = _safe_world_name(world_name)
	if payload["world"] == "":
		payload["world"] = _safe_world_name(current_world_name)
	if payload["world"] == "":
		return false
	payload["drop_id"] = _safe_string(payload.get("drop_id", ""), "", MAX_REQUEST_ID_LENGTH)
	payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	payload["is_seed"] = _safe_bool(payload.get("is_seed", false), false)
	payload["amount"] = snapped(_safe_float(payload.get("amount", 1.0), 1.0, 0.1, float(MAX_DROP_TILE_AMOUNT)), 0.1) if payload["item_category"] == "fish" else _safe_int(payload.get("amount", 1), 1, 1, MAX_DROP_TILE_AMOUNT)
	var raw_x = payload.get("x", 0.0)
	var raw_y = payload.get("y", 0.0)
	if raw_x is float or raw_x is int:
		if not is_finite(float(raw_x)):
			raw_x = 0.0
		else:
			raw_x = clamp(float(raw_x), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
	else:
		raw_x = 0.0
	if raw_y is float or raw_y is int:
		if not is_finite(float(raw_y)):
			raw_y = 0.0
		else:
			raw_y = clamp(float(raw_y), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
	else:
		raw_y = 0.0
	payload["x"] = raw_x
	payload["y"] = raw_y

	var raw_pickup_delay = payload.get("pickup_delay", 0.0)
	if raw_pickup_delay is float or raw_pickup_delay is int:
		if is_finite(float(raw_pickup_delay)):
			payload["pickup_delay"] = clamp(float(raw_pickup_delay), 0.0, 30.0)
		else:
			payload["pickup_delay"] = 0.0
	else:
		payload["pickup_delay"] = 0.0
	if payload.has("requested_by"):
		payload["requested_by"] = _safe_string(payload.get("requested_by", ""), "", MAX_REQUEST_ID_LENGTH)
	if payload.get("stack_grid_x", 0) is int or payload.get("stack_grid_x", 0) is float:
		payload["stack_grid_x"] = _safe_int(payload.get("stack_grid_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	else:
		payload.erase("stack_grid_x")
	if payload.get("stack_grid_y", 0) is int or payload.get("stack_grid_y", 0) is float:
		payload["stack_grid_y"] = _safe_int(payload.get("stack_grid_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	else:
		payload.erase("stack_grid_y")
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_inventory_transaction_request(transaction_data: Dictionary) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("inventory_transaction", MAX_INVENTORY_TRANSACTION_RATE_PER_SECOND):
		return false
	if not (transaction_data is Dictionary):
		return false
	var payload = transaction_data.duplicate(true)
	payload["type"] = "inventory_transaction_request"
	payload["action"] = _safe_string(payload.get("action", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if not INVENTORY_TRANSACTION_ACTIONS.has(payload["action"]):
		return false
	if not payload.has("world"):
		payload["world"] = current_world_name
	payload["world"] = _safe_world_name(payload["world"])
	if payload["world"] == "":
		payload["world"] = _safe_world_name(current_world_name)
	if payload["world"] == "":
		return false
	if payload["action"] == "craft_recipe" or payload["action"] == "furnace_recipe":
		payload["station_id"] = _safe_string(payload.get("station_id", ""), "", MAX_ITEM_ID_LENGTH)
		if payload["station_id"] == "":
			return false
		payload["recipe_id"] = _safe_string(payload.get("recipe_id", ""), "", MAX_REQUEST_ID_LENGTH)
		if payload["recipe_id"] == "":
			return false
		payload["station_x"] = _safe_int(payload.get("station_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["station_y"] = _safe_int(payload.get("station_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	elif payload["action"] == "safe_get_state" or payload["action"] == "vend_get_state":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	elif payload["action"] == "safe_deposit" or payload["action"] == "safe_withdraw":
		payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		if payload["item_type"] == "" or payload["item_category"] == "":
			return false
		payload["amount"] = snapped(_safe_float(payload.get("amount", 0.0), 1.0, 0.1, float(MAX_ITEM_STACK_SIZE)), 0.1)
	elif payload["action"] == "seed_splice" or payload["action"] == "seed_place" or payload["action"] == "seed_harvest":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		if payload["action"] == "seed_splice" or payload["action"] == "seed_place":
			payload["seed_type"] = _safe_string(payload.get("seed_type", ""), "", MAX_ITEM_ID_LENGTH)
			if payload["seed_type"] == "":
				return false
		if payload["action"] == "seed_place":
			payload["grow_time"] = _safe_float(payload.get("grow_time", 0.0), 0.0, 0.0, MAX_PLAYER_COORDINATE * 10.0)
			payload["max_grow_time"] = _safe_float(payload.get("max_grow_time", 0.0), 0.0, 0.0, MAX_PLAYER_COORDINATE * 10.0)
	elif payload["action"] == "trash_inventory_item":
		payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		payload["amount"] = snapped(_safe_float(payload.get("amount", 0.0), 0.0, 0.0, float(MAX_ITEM_STACK_SIZE)), 0.1) if payload["item_category"] == "fish" else _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
		if payload["item_category"] == "fish" and float(payload["amount"]) <= 0.0:
			return false
		if payload["item_type"] == "" or payload["item_category"] == "":
			return false
	elif payload["action"] == "fish_monger_sell":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		var proposed_fish_type = payload.get("item_type", payload.get("item_id", ""))
		payload["item_type"] = _safe_string(proposed_fish_type, "", MAX_ITEM_ID_LENGTH)
		if payload["item_type"] == "":
			return false
		payload["item_category"] = _safe_string(payload.get("item_category", "fish"), "", MAX_ITEM_CATEGORY_LENGTH)
		if payload["item_category"] == "":
			return false
		payload["amount"] = snapped(_safe_float(payload.get("amount", 0.0), 0.0, 0.0, float(MAX_ITEM_STACK_SIZE)), 0.1)
		if float(payload["amount"]) <= 0.0:
			return false
	elif payload["action"] == "fish_monger_sell_all":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	elif payload["action"] == "fishing_start":
		payload["target_x"] = _safe_int(payload.get("target_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["target_y"] = _safe_int(payload.get("target_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["lure_id"] = _safe_string(payload.get("lure_id", ""), "", MAX_ITEM_ID_LENGTH)
	elif payload["action"] == "fishing_complete":
		payload["session_id"] = _safe_string(payload.get("session_id", ""), "", MAX_REQUEST_ID_LENGTH)
		payload["success"] = _safe_bool(payload.get("success", false), false)
		if payload["session_id"] == "":
			return false
	elif payload["action"] == "drop_inventory_item":
		payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		if payload["item_type"] == "" or payload["item_category"] == "":
			return false
		payload["amount"] = snapped(_safe_float(payload.get("amount", 0.0), 0.0, 0.0, float(MAX_ITEM_STACK_SIZE)), 0.1) if payload["item_category"] == "fish" else _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
		if payload["item_category"] == "fish" and float(payload["amount"]) <= 0.0:
			return false
		payload["x"] = _safe_float(payload.get("x", 0.0), 0.0, float(-MAX_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
		payload["y"] = _safe_float(payload.get("y", 0.0), 0.0, float(-MAX_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
		payload["stack_grid_x"] = _safe_int(payload.get("stack_grid_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["stack_grid_y"] = _safe_int(payload.get("stack_grid_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	elif payload["action"] == "shop_buy":
		payload["item_id"] = _safe_string(payload.get("item_id", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		if payload["item_id"] == "" or payload["item_category"] == "":
			return false
		payload["amount"] = _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
		payload["price"] = _safe_int(payload.get("price", 0), 0, 0, MAX_ITEM_PRICE)
	elif payload["action"] == "vend_set_listing":
		payload["item_id"] = _safe_string(payload.get("item_id", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		if payload["item_id"] == "" or payload["item_category"] == "":
			return false
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["stock"] = _safe_int(payload.get("stock", 0), 1, 1, MAX_ITEM_STACK_SIZE)
		payload["amount_per_sale"] = _safe_int(payload.get("amount_per_sale", 1), 1, 1, MAX_ITEM_STACK_SIZE)
		payload["price_wls"] = _safe_int(payload.get("price_wls", 0), 0, 0, MAX_ITEM_PRICE)
	elif payload["action"] == "vend_buy":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["sale_count"] = _safe_int(payload.get("sale_count", 1), 1, 1, MAX_ITEM_STACK_SIZE)
	elif payload["action"] == "vend_collect" or payload["action"] == "vend_cancel":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)

	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_developer_command_request(command_text: String, request_id: String = "", command_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		return false
	var payload = command_data.duplicate(true)
	payload["type"] = "developer_command_request"
	payload["request_id"] = _safe_string(request_id, "cmd_" + str(Time.get_ticks_msec()), MAX_REQUEST_ID_LENGTH)
	payload["player_id"] = player_id
	payload["name"] = _safe_string(player_name, "Player", MAX_USERNAME_LENGTH)
	payload["command"] = _safe_string(command_text, "", MAX_BROADCAST_LENGTH)
	payload["world"] = _safe_world_name(current_world_name)
	if payload["world"] == "":
		payload["world"] = "START"
	return send_message(attach_session_auth(payload))


func send_developer_pin_unlock(pin: String) -> bool:
	if not is_connected_to_server():
		return false
	developer_pin_unlock_request_counter += 1
	return send_message(attach_session_auth({
		"type": "developer_pin_unlock",
		"request_id": "devpin_" + str(Time.get_ticks_msec()) + "_" + str(developer_pin_unlock_request_counter),
		"pin": _safe_string(pin, "", MAX_BROADCAST_LENGTH)
	}))


func send_trade_request(target_player_id: String, target_username: String = "") -> bool:
	return send_trade_payload({
		"type": "trade_request",
		"target_player_id": target_player_id,
		"target_username": target_username
	})


func send_trade_response(trade_id: String, accepted: bool) -> bool:
	return send_trade_payload({
		"type": "trade_response",
		"trade_id": trade_id,
		"accepted": accepted
	})


func send_trade_response_from_player(requester_username: String, accepted: bool) -> bool:
	return send_trade_payload({
		"type": "trade_response",
		"requester_username": requester_username,
		"accepted": accepted
	})


func send_trade_offer_update(trade_id: String, slot_index: int, item_id: String, item_category: String, amount: int) -> bool:
	return send_trade_payload({
		"type": "trade_offer_update",
		"trade_id": trade_id,
		"slot_index": slot_index,
		"item_id": item_id,
		"item_category": item_category,
		"amount": amount
	})


func send_trade_confirm(trade_id: String) -> bool:
	return send_trade_payload({"type": "trade_confirm", "trade_id": trade_id})


func send_trade_final_confirm(trade_id: String) -> bool:
	return send_trade_payload({"type": "trade_final_confirm", "trade_id": trade_id})


func send_trade_cancel(trade_id: String) -> bool:
	return send_trade_payload({"type": "trade_cancel", "trade_id": trade_id})


func send_trade_payload(payload: Dictionary) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("trade", MAX_TRADE_RATE_PER_SECOND):
		return false
	var clean_payload = payload.duplicate(true)
	var message_type = _safe_string(clean_payload.get("type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	match message_type:
		"trade_request":
			var target_player_id = _safe_string(clean_payload.get("target_player_id", ""), "", MAX_TRADE_ID_LENGTH)
			var target_username = _safe_string(clean_payload.get("target_username", ""), "", MAX_USERNAME_LENGTH)
			if target_player_id == "" and target_username == "":
				return false
			clean_payload["target_player_id"] = target_player_id
			clean_payload["target_username"] = target_username
		"trade_response":
			clean_payload["accepted"] = _safe_bool(clean_payload.get("accepted", false), false)
			var trade_id = _safe_string(clean_payload.get("trade_id", ""), "", MAX_TRADE_ID_LENGTH)
			var requester_username = _safe_string(clean_payload.get("requester_username", ""), "", MAX_USERNAME_LENGTH)
			if trade_id == "" and requester_username == "":
				return false
			clean_payload["trade_id"] = trade_id
			clean_payload["requester_username"] = requester_username
		"trade_offer_update":
			var trade_id = _safe_string(clean_payload.get("trade_id", ""), "", MAX_TRADE_ID_LENGTH)
			if trade_id == "":
				return false
			clean_payload["trade_id"] = trade_id
			clean_payload["slot_index"] = _safe_int(clean_payload.get("slot_index", 0), 0, 0, MAX_TRADE_SLOT_INDEX)
			clean_payload["item_id"] = _safe_string(clean_payload.get("item_id", ""), "", MAX_ITEM_ID_LENGTH)
			clean_payload["item_category"] = _safe_string(clean_payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			clean_payload["amount"] = _safe_int(clean_payload.get("amount", 0), 0, 0, MAX_ITEM_STACK_SIZE)
		"trade_confirm":
			var trade_id = _safe_string(clean_payload.get("trade_id", ""), "", MAX_TRADE_ID_LENGTH)
			if trade_id == "":
				return false
			clean_payload["trade_id"] = trade_id
		"trade_final_confirm":
			var trade_id = _safe_string(clean_payload.get("trade_id", ""), "", MAX_TRADE_ID_LENGTH)
			if trade_id == "":
				return false
			clean_payload["trade_id"] = trade_id
		"trade_cancel":
			var trade_id = _safe_string(clean_payload.get("trade_id", ""), "", MAX_TRADE_ID_LENGTH)
			if trade_id == "":
				return false
			clean_payload["trade_id"] = trade_id
		_:
			return false

	clean_payload["type"] = message_type
	return send_message(attach_session_auth(clean_payload))


func send_player_position(position: Vector2, facing: int, world_name: String, allow_join: bool = true, bypass_rate_limit: bool = false) -> bool:
	if not is_server_session_authenticated():
		return false
	if not bypass_rate_limit and not _can_send_rate_limited("player_position", MAX_PLAYER_POSITION_RATE_PER_SECOND):
		return false
	if not (position is Vector2):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"
	if clean_world != current_world_name:
		debug_action_position_flow("player_position world mismatch", {
			"requested_world": clean_world,
			"previous_network_world": current_world_name,
			"allow_join": allow_join,
		"auto_join_disabled": true
		})
		current_world_name = clean_world
	var safe_facing = 1 if facing >= 0 else -1
	var safe_x = _safe_float(position.x, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
	var safe_y = _safe_float(position.y, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
	return send_message(attach_session_auth({
		"type": "player_position",
		"name": player_name,
		"x": safe_x,
		"y": safe_y,
		"facing": safe_facing,
		"world": clean_world,
		"animation_state": get_player_animation_state(),
		"equipment_slots": get_equipment_slots()
	}))


func flush_world_position_for_payload(payload: Dictionary) -> void:
	if str(payload.get("world", "")).strip_edges() == "":
		return
	flush_current_world_position_for_action(str(payload.get("type", payload.get("action", ""))))


func flush_current_world_position_for_action(action_type: String) -> void:
	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return
	if world_node.has_method("flush_multiplayer_position"):
		debug_action_position_flow("flush position before world action", {
			"action_type": action_type,
		})
		world_node.flush_multiplayer_position(false, true)


func sync_active_world_name_from_server(world_name) -> void:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return

	current_world_name = clean_world
	var world_node = get_world_node()
	if world_node == null:
		return

	if "current_world_name" in world_node:
		world_node.set("current_world_name", clean_world)


func handle_server_message(raw: String) -> void:
	if raw == "":
		return
	if raw.to_utf8_buffer().size() > MAX_SERVER_MESSAGE_BYTES:
		return

	var json = JSON.new()
	var error = json.parse(raw)
	if error != OK:
		return
	var data = json.data
	if not (data is Dictionary):
		return
	_cleanup_expired_player_state_requests()
	if DEBUG_SERVER_PACKETS:
		print("SERVER:", data)
	var message_type = _safe_string(data.get("type", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH).to_lower()
	if message_type == "":
		return
	update_developer_pin_state_from_message(data)
	var world_node = null
	var safe_world = _get_message_world_name(data)

	match message_type:
		"connected":
			player_id = _safe_string(data.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH)
		"login_ok":
			player_name = _safe_string(data.get("name", player_name), player_name, MAX_USERNAME_LENGTH)
		"client_update_required":
			login_notice_message = str(data.get("message", "Please update PixelMania."))
			server_auth_finished.emit(data)
		"account_auth_ok":
			handle_account_auth_ok(data)
		"account_auth_error":
			var had_session_before_auth_error := has_active_session()
			server_session_authenticated = false
			server_auth_finished.emit(data)
			if had_session_before_auth_error and not _is_login_scene_active():
				_end_authenticated_session(
					str(data.get("message", "Sign on again.")),
					true,
					false
				)
		"account_session_replaced":
			handle_account_session_replaced(data)
		"join_world_ok":
			current_world_name = safe_world if safe_world != "" else current_world_name
			sync_active_world_name_from_server(current_world_name)
			sync_current_world_population_from_players(current_world_name, data.get("players", []))
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_existing_players"):
				world_node.handle_network_existing_players(data.get("players", []))
		"world_state":
			if safe_world != "":
				sync_active_world_name_from_server(safe_world)
			debug_action_position_flow("received world_state", {
				"world": safe_world,
				"respawn_player": data.get("respawn_player", null),
				"force_respawn": data.get("force_respawn", null),
				"world_state_reason": str(data.get("world_state_reason", ""))
			})
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_world_state"):
				world_node.apply_network_world_state(data)
		"world_block_update":
			if str(data.get("action", "")).to_lower() == "break":
				debug_action_position_flow("received block break update", data)
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_block_update"):
				world_node.apply_network_block_update(data)
		"world_seed_update":
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_seed_update"):
				world_node.apply_network_seed_update(data)
		"world_interaction_update":
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_world_interaction_update"):
				world_node.apply_network_world_interaction_update(data)
		"world_item_drop_create", "world_drop_create", "drop_spawned":
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_item_drop_create"):
				world_node.apply_network_item_drop_create(data)
		"world_item_drop_update", "world_drop_update", "drop_updated":
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_item_drop_update"):
				var drop_update_payload = data.duplicate(true)
				drop_update_payload["_server_inventory_update_applied"] = player_state_applied
				drop_update_payload["_apply_pickup_inventory"] = true
				world_node.apply_network_item_drop_update(drop_update_payload)
		"world_item_drop_pickup", "world_drop_pickup":
			debug_action_position_flow("received drop pickup/update packet", data)
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node == null or not is_world_node_active():
				return

			var pickup_payload = data.duplicate(true)
			pickup_payload["_server_inventory_update_applied"] = player_state_applied
			pickup_payload["_apply_pickup_inventory"] = true

			if world_node.has_method("apply_network_item_drop_update"):
				world_node.apply_network_item_drop_update(pickup_payload)
			else:
				world_node.apply_network_item_drop_remove(pickup_payload)
		"world_item_drop_remove", "world_drop_remove", "drop_removed":
			debug_action_position_flow("received drop remove update", data)
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_item_drop_remove"):
				var pickup_remove_payload = data.duplicate(true)
				pickup_remove_payload["_server_inventory_update_applied"] = player_state_applied
				pickup_remove_payload["_apply_pickup_inventory"] = true
				world_node.apply_network_item_drop_remove(pickup_remove_payload)
		"player_state":
			handle_player_state_message(data)
		"world_population", "world_population_update":
			var incoming = data.get("world_counts", {})
			if incoming is Dictionary:
				_apply_world_population_payload(incoming, data.get("clear_unreported", false))
			elif data.has("worlds") and data.get("worlds") is Dictionary:
				_apply_world_population_payload(data.get("worlds"), data.get("clear_unreported", false))
		"inventory_transaction_result":
			handle_inventory_transaction_result(data)
		"action_rejected":
			if _route_action_rejected_as_player_state_lookup(data):
				return
			handle_action_rejected(data)
		"rate_limited":
			if _route_action_rejected_as_player_state_lookup(data):
				return
			handle_action_rejected(data)
		"chat", "broadcast":
			handle_chat_message(data)
			if _message_has_session_ending_punishment(data):
				_end_authenticated_session(str(data.get("message", "Account restricted.")), true, true)
		"pull_player_result":
			handle_pull_player_result(data)
		"player_pulled":
			handle_player_pulled(data)
		"player_position", "player_joined":
			if _safe_string(data.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH) != player_id:
				remember_world_player(str(data.get("world", current_world_name)), str(data.get("player_id", "")))
				world_node = get_world_node()
				if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_position"):
					world_node.handle_network_player_position(data)
		"player_left":
			forget_world_player(str(data.get("world", current_world_name)), str(data.get("player_id", "")))
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_left"):
				world_node.handle_network_player_left(str(data.get("player_id", "")))
		"developer_command_verified", "developer_command_approved":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_verified_developer_command"):
				world_node.handle_verified_developer_command(str(data.get("command", "")), str(data.get("request_id", "")), str(data.get("message", "")))
		"developer_command_denied":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_denied_developer_command"):
				world_node.handle_denied_developer_command(str(data.get("command", "")), str(data.get("request_id", "")), str(data.get("message", "")))
		"item_grant", "developer_item_grant", "inventory_grant":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_item_grant"):
				world_node.handle_network_item_grant(data)
		"trade_request_received", "trade_request_sent", "trade_state", "trade_canceled", "trade_error", "trade_completed":
			if message_type == "trade_completed":
				apply_player_state_payload_if_present(data, false)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_trade_message"):
				world_node.handle_trade_message(data)
		"friend_state", "friend_request_received", "friend_request_sent", "friend_response_result", "friend_request_accepted", "friend_request_declined", "friend_error":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_friend_message"):
				world_node.handle_friend_message(data)
		_:
			if is_player_state_like_message_type(message_type):
				handle_player_state_message(data)
			elif should_route_as_player_state_payload(message_type, data):
				handle_player_state_message(data)


func _safe_pickup_remaining_amount(data: Dictionary) -> float:
	if data == null:
		return PICKUP_REMAINING_AMOUNT_UNKNOWN

	for removed_key in ["removed", "is_removed", "remove", "removed_from_world", "drop_removed"]:
		if data.has(removed_key) and _safe_bool(data.get(removed_key), false):
			return 0

	var max_remaining := float(MAX_DROP_TILE_AMOUNT)

	for key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "amount"]:
		if not data.has(key):
			continue
		var raw_amount = data.get(key)
		if raw_amount is int:
			var safe_remaining := float(raw_amount)
			if safe_remaining < 0:
				return PICKUP_REMAINING_AMOUNT_UNKNOWN
			if safe_remaining == 0:
				return 0
			return min(safe_remaining, max_remaining)
		if raw_amount is float:
			if not is_finite(float(raw_amount)):
				return PICKUP_REMAINING_AMOUNT_UNKNOWN
			var safe_remaining := float(raw_amount)
			if safe_remaining < 0:
				return PICKUP_REMAINING_AMOUNT_UNKNOWN
			if safe_remaining == 0:
				return 0
			return min(snapped(safe_remaining, 0.1), max_remaining)
		if raw_amount is String:
			var raw_text = raw_amount.strip_edges()
			if not raw_text.is_valid_float():
				return PICKUP_REMAINING_AMOUNT_UNKNOWN
			var safe_remaining := float(raw_text)
			if safe_remaining < 0:
				return PICKUP_REMAINING_AMOUNT_UNKNOWN
			if safe_remaining == 0:
				return 0
			return min(snapped(safe_remaining, 0.1), max_remaining)
		return PICKUP_REMAINING_AMOUNT_UNKNOWN

	return PICKUP_REMAINING_AMOUNT_UNKNOWN


func handle_account_auth_ok(data: Dictionary) -> void:
	var username = _safe_string(data.get("username", ""), "", MAX_USERNAME_LENGTH)
	var email = _safe_string(data.get("email", ""), "", 256)
	var token = _safe_string(data.get("session_token", session_token), "", 512)
	var role = _safe_string(data.get("role", "player"), "player", MAX_ITEM_ID_LENGTH).to_lower()
	if username != "" and token != "":
		session_username = username
		session_email = email
		session_token = token
		session_role = role if role != "" else "player"
		session_authenticated = true
		server_session_authenticated = true
		developer_pin_required = bool(data.get("developer_pin_required", false))
		developer_pin_unlocked = bool(data.get("developer_pin_unlocked", not developer_pin_required))
		player_name = username
		send_account_state_save(session_username, session_email, session_token)
		var world_node = get_world_node()
		if world_node != null and world_node.has_method("request_network_player_state"):
			world_node.request_network_player_state()
		if has_pending_join():
			send_join_world(pending_join_world_name)
		elif world_node != null and is_world_node_active():
			var active_world_name = current_world_name
			if "current_world_name" in world_node:
				active_world_name = _safe_world_name(world_node.get("current_world_name"))
			if active_world_name == "":
				active_world_name = current_world_name
			send_join_world(active_world_name)
	server_auth_finished.emit(data)


func update_developer_pin_state_from_message(data: Dictionary) -> void:
	if bool(data.get("requires_developer_pin", false)):
		developer_pin_required = true
		developer_pin_unlocked = false
	if data.has("developer_pin_required"):
		developer_pin_required = bool(data.get("developer_pin_required", developer_pin_required))
	if data.has("developer_pin_unlocked"):
		developer_pin_unlocked = bool(data.get("developer_pin_unlocked", developer_pin_unlocked))


func handle_account_session_replaced(data: Dictionary) -> void:
	_end_authenticated_session(
		str(data.get("message", "This account signed on somewhere else.")),
		true,
		true
	)


func handle_player_state_message(data: Dictionary) -> void:
	var request_id = _extract_player_state_request_id(data)
	_log_player_state_lookup("handling player state payload", {
		"request_id": request_id,
		"has_pending": not pending_player_state_requests.is_empty()
	})
	if request_id != "" and pending_player_state_requests.has(request_id):
		var request_context = pending_player_state_requests[request_id]
		pending_player_state_requests.erase(request_id)
		var world_node = get_world_node()
		if world_node != null and world_node.has_method("handle_player_state_lookup_result"):
			_log_player_state_lookup("matched exact request", {"request_id": request_id})
			world_node.handle_player_state_lookup_result(request_id, data.duplicate(true), request_context)
		return

	var fallback_context = _consume_pending_player_state_request_for_response(data)
	if not fallback_context.is_empty():
		var world_node = get_world_node()
		if world_node != null and world_node.has_method("handle_player_state_lookup_result"):
			_log_player_state_lookup("matched fallback request", {
				"request_id": request_id,
				"fallback_purpose": str(fallback_context.get("purpose", ""))
			})
			world_node.handle_player_state_lookup_result(request_id, data.duplicate(true), fallback_context)
			return

	if not is_player_state_for_active_profile(data):
		return
	pending_server_player_state = data.duplicate(true)
	apply_pending_server_player_state_if_ready()


func handle_inventory_transaction_result(data: Dictionary) -> void:
	var action = str(data.get("action", "")).strip_edges().to_lower()
	if action == "drop_pickup" or action == "world_block_break":
		var player_data_debug = data.get("player_data", null)
		debug_action_position_flow("received inventory transaction result", {
			"action": action,
			"ok": bool(data.get("ok", false)),
			"has_player_data": player_data_debug is Dictionary and not player_data_debug.is_empty()
		})
	if bool(data.get("ok", false)):
		var player_state_applied = apply_player_state_payload_if_present(data)
		if action == "drop_pickup" or action == "world_item_drop_pickup" or action == "world_drop_pickup":
			var pickup_result_drop_id = _safe_string(data.get("drop_id", ""), "", MAX_REQUEST_ID_LENGTH)
			var pickup_result_world_node = get_world_node()
			if pickup_result_world_node != null and is_world_node_active() and pickup_result_drop_id != "":
				var pickup_payload = data.duplicate(true)
				pickup_payload["type"] = "world_item_drop_pickup"
				pickup_payload["_server_inventory_update_applied"] = player_state_applied
				pickup_payload["_apply_pickup_inventory"] = not player_state_applied
				var has_explicit_remaining = false
				for remaining_key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
					if pickup_payload.has(remaining_key):
						has_explicit_remaining = true
						break
				if action == "drop_pickup" and not has_explicit_remaining and pickup_payload.has("amount"):
					pickup_payload.erase("amount")
				var remaining_amount = _safe_pickup_remaining_amount(pickup_payload)
				if action == "drop_pickup" and remaining_amount == PICKUP_REMAINING_AMOUNT_UNKNOWN and not has_explicit_remaining:
					remaining_amount = 0
				if remaining_amount == 0:
					if pickup_result_world_node.has_method("apply_network_item_drop_remove"):
						pickup_result_world_node.apply_network_item_drop_remove(pickup_payload)
				elif remaining_amount != PICKUP_REMAINING_AMOUNT_UNKNOWN:
					pickup_payload["amount"] = remaining_amount
					if pickup_result_world_node.has_method("apply_network_item_drop_update"):
						pickup_result_world_node.apply_network_item_drop_update(pickup_payload)
				elif pickup_result_world_node.has_method("cancel_pending_pickup_for_drop"):
					pickup_result_world_node.cancel_pending_pickup_for_drop(pickup_result_drop_id)
	elif action == "drop_pickup" or action == "world_item_drop_pickup" or action == "world_drop_pickup":
		var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_REQUEST_ID_LENGTH)
		var pickup_world_node = get_world_node()
		if pickup_world_node != null and is_world_node_active():
			if pickup_world_node.has_method("handle_rejected_drop_pickup"):
				if bool(pickup_world_node.handle_rejected_drop_pickup(drop_id, str(data.get("message", "")))):
					return
			elif pickup_world_node.has_method("cancel_pending_pickup_for_drop"):
				pickup_world_node.cancel_pending_pickup_for_drop(drop_id)
	var world_node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("handle_inventory_transaction_result"):
		world_node.handle_inventory_transaction_result(data)


func handle_action_rejected(data: Dictionary) -> void:
	var message = str(data.get("message", "Server rejected that action."))
	debug_action_position_flow("action rejected", {
		"action": str(data.get("action", "")),
		"message": message
	})
	var world_node = get_world_node()
	var normalized_action = str(data.get("action", "")).strip_edges().to_lower()
	if normalized_action == "world_item_drop_pickup" or normalized_action == "world_drop_pickup" or normalized_action == "drop_pickup":
		var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_REQUEST_ID_LENGTH)
		if world_node != null and is_world_node_active():
			if world_node.has_method("handle_rejected_drop_pickup"):
				if bool(world_node.handle_rejected_drop_pickup(drop_id, message)):
					return
			elif world_node.has_method("cancel_pending_pickup_for_drop"):
				world_node.cancel_pending_pickup_for_drop(drop_id)

	if world_node != null and is_world_node_active() and world_node.has_method("show_notification"):
		world_node.show_notification(message)
	else:
		var chat_ui = get_chat_ui_node()
		if chat_ui != null:
			chat_ui.add_chat_message("System", message)
	var action = normalized_action
	if action.begins_with("world_") and has_active_session() and not _is_player_state_lookup_related_action(action):
		send_player_state_request(session_username)


func handle_pull_player_result(data: Dictionary) -> void:
	var message: String = str(data.get("message", "")).strip_edges()
	if message == "":
		return

	var world_node: Node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("show_notification"):
		world_node.show_notification(message)
		return

	var chat_ui: Node = get_chat_ui_node()
	if chat_ui != null:
		chat_ui.add_chat_message("System", message)


func handle_player_pulled(data: Dictionary) -> void:
	var world_node: Node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("apply_server_player_pull"):
		world_node.apply_server_player_pull(data)
		return

	var message: String = str(data.get("message", "")).strip_edges()
	if message == "":
		return

	var chat_ui: Node = get_chat_ui_node()
	if chat_ui != null:
		chat_ui.add_chat_message("System", message)


func _is_player_state_lookup_related_action(action: String) -> bool:
	var normalized = action.strip_edges().to_lower()
	if normalized == "":
		return false

	if normalized == "player_state_request":
		return true
	if normalized == "world_lock_access_check":
		return true
	if normalized == "remote_player_profile":
		return true
	if normalized == "admin_inventory_lookup":
		return true
	if normalized == "admin_item_instance_lookup":
		return true

	return normalized.find("player") != -1 and normalized.find("state") != -1


func _route_action_rejected_as_player_state_lookup(data: Dictionary) -> bool:
	if pending_player_state_requests.is_empty():
		return false

	var action = str(data.get("action", "")).strip_edges().to_lower()
	if not _is_player_state_lookup_related_action(action) and not response_is_player_state_lookup_shape(data):
		return false

	var request_id = _extract_player_state_request_id(data)
	var world_node = get_world_node()

	if request_id != "" and pending_player_state_requests.has(request_id):
		var request_context = pending_player_state_requests[request_id]
		pending_player_state_requests.erase(request_id)
		_log_player_state_lookup("routed action_rejected by request id", {
			"request_id": request_id,
			"action": action
		})
		if world_node != null and world_node.has_method("handle_player_state_lookup_result"):
			world_node.handle_player_state_lookup_result(request_id, data.duplicate(true), request_context)
		return true

	var fallback_context = _consume_pending_player_state_request_for_response(data)
	if fallback_context.is_empty():
		if _is_player_state_lookup_related_action(action):
			var fallback_request_id := ""
			var fallback_request: Dictionary = {}
			for key in pending_player_state_requests.keys():
				var request_context = pending_player_state_requests[key]
				var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
				var should_pick = false
				if action == "world_lock_access_check":
					should_pick = request_purpose == "world_lock_access_check"
				elif action == "remote_player_profile":
					should_pick = request_purpose == "remote_player_profile"
				else:
					should_pick = request_purpose != ""
				if should_pick:
					fallback_request_id = key
					fallback_request = request_context.duplicate(true)
					break

			if fallback_request_id == "" and pending_player_state_requests.size() > 0:
				fallback_request_id = str(pending_player_state_requests.keys()[0])
				fallback_request = pending_player_state_requests[fallback_request_id].duplicate(true)

			if fallback_request_id != "":
				pending_player_state_requests.erase(fallback_request_id)
				fallback_context = fallback_request
				request_id = fallback_request_id
				_log_player_state_lookup("routed action_rejected by lookup action fallback", {
					"action": action,
					"request_id": request_id,
					"purpose": str(fallback_context.get("purpose", ""))
				})
		else:
			return false

	if fallback_context.is_empty():
		return false

	if not fallback_context.is_empty():
		_log_player_state_lookup("routed action_rejected by fallback", {
			"action": action,
			"request_id": request_id,
			"purpose": str(fallback_context.get("purpose", ""))
		})
		if world_node != null and world_node.has_method("handle_player_state_lookup_result"):
			world_node.handle_player_state_lookup_result(request_id, data.duplicate(true), fallback_context)
		return true

	return false


func handle_chat_message(data: Dictionary) -> void:
	var message_type: String = _safe_string(data.get("type", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH).to_lower()
	var message_limit: int = MAX_BROADCAST_LENGTH if message_type == "broadcast" else MAX_CHAT_MESSAGE_LENGTH
	var chat_message = _safe_string(data.get("message", ""), "", message_limit)
	if chat_message == "":
		return
	var sender_name = _safe_string(data.get("name", "Player"), "Player", MAX_USERNAME_LENGTH)
	var sender_id = _safe_string(data.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH)
	var world_node = get_world_node()
	var current_profile_name = ""
	if world_node != null and world_node.has_method("get_current_profile_name"):
		current_profile_name = str(world_node.get_current_profile_name()).strip_edges().to_lower()
	var is_local_sender = sender_id == player_id
	var source_world: String = _get_message_world_name(data)
	if not is_local_sender and sender_name != "" and current_profile_name != "":
		is_local_sender = sender_name.strip_edges().to_lower() == current_profile_name
	var chat_ui = get_chat_ui_node()
	if chat_ui != null:
		chat_ui.add_chat_message(sender_name, chat_message, {
			"type": message_type,
			"world": source_world,
			"player_id": sender_id
		})

		if is_local_sender and message_type != "broadcast":
			chat_ui.show_chat_bubble(chat_message)

	var is_remote_sender = not is_local_sender
	if is_remote_sender and world_node != null and sender_id != "system" and sender_name != "system" and message_type != "broadcast":
		if world_node.has_method("show_remote_chat_bubble"):
			world_node.show_remote_chat_bubble(sender_id, chat_message, sender_name)
		elif "player_manager" in world_node and world_node.player_manager != null and world_node.player_manager.has_method("show_remote_chat_bubble"):
			world_node.player_manager.show_remote_chat_bubble(sender_id, chat_message, sender_name)


func apply_player_state_payload_if_present(data: Dictionary, preserve_local_loadout: bool = true) -> bool:
	if not data.has("player_data"):
		return false
	var player_data = data.get("player_data")
	if not (player_data is Dictionary):
		return false
	if player_data.is_empty():
		debug_action_position_flow("ignored empty player_data payload", {
			"type": str(data.get("type", "")),
			"action": str(data.get("action", ""))
		})
		return false
	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return false
	if not world_node.has_method("apply_network_player_state"):
		return false
	world_node.apply_network_player_state({
		"type": "player_state",
		"found": true,
		"username": str(data.get("username", session_username)),
		"player_data": player_data,
		"preserve_local_loadout": preserve_local_loadout
	})
	return true


func is_player_state_for_active_profile(data: Dictionary) -> bool:
	var username = str(data.get("username", "")).strip_edges()
	if username == "":
		username = _extract_username_from_player_state_payload(data)
	if username == "":
		return false
	if has_active_session():
		return username.to_lower() == session_username.to_lower()
	var world_node = get_world_node()
	if world_node != null and world_node.has_method("get_current_profile_name"):
		return username.to_lower() == str(world_node.get_current_profile_name()).strip_edges().to_lower()
	return false


func should_route_as_player_state_payload(message_type: String, data: Dictionary) -> bool:
	if data == null:
		return false

	if pending_player_state_requests.is_empty():
		return false

	var direct_request_id = _extract_player_state_request_id(data)
	if direct_request_id != "":
		if pending_player_state_requests.has(direct_request_id):
			return true
		return false

	var direct_username = _extract_username_from_player_state_payload(data)
	if direct_username != "" and _is_any_pending_request_for_username(direct_username):
		return true

	if response_is_player_state_lookup_shape(data):
		return true

	var normalized_type = message_type.strip_edges().to_lower()
	return normalized_type == "player_state" or is_player_state_like_message_type(normalized_type)


func _consume_pending_player_state_request_for_response(data: Dictionary) -> Dictionary:
	if pending_player_state_requests.is_empty():
		return {}
	_cleanup_expired_player_state_requests()
	if pending_player_state_requests.is_empty():
		return {}

	var response_username = _extract_username_from_player_state_payload(data)
	if response_username != "":
		response_username = response_username.strip_edges().to_upper()
	var response_purpose = str(data.get("purpose", "")).strip_edges().to_lower()
	var world_node = get_world_node()
	var world_lock_ui_open = false
	if world_node != null and world_node.has_method("is_world_lock_ui_open"):
		world_lock_ui_open = bool(world_node.is_world_lock_ui_open())
	var response_is_lookup_shape = response_is_player_state_lookup_shape(data)

	var fallback_key = ""
	var fallback_request = {}
	var matching_keys: Array = []

	if response_purpose != "":
		for key in pending_player_state_requests.keys():
			var request_context = pending_player_state_requests[key]
			var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
			if request_purpose == response_purpose:
				var pending_username = str(request_context.get("requested_username", request_context.get("username", ""))).strip_edges().to_upper()
				if response_username != "" and pending_username != "" and response_username != pending_username:
					continue
				fallback_key = key
				fallback_request = request_context.duplicate(true)
				break

		if fallback_key != "":
			pending_player_state_requests.erase(fallback_key)
			return fallback_request

	for key in pending_player_state_requests.keys():
		var request_context = pending_player_state_requests[key]
		var pending_request_purpose = str(request_context.get("purpose", ""))
		var pending_username = str(request_context.get("requested_username", request_context.get("username", ""))).strip_edges().to_upper()

		if response_username != "" and pending_username != "" and response_username == pending_username:
			fallback_key = key
			fallback_request = request_context.duplicate(true)
			break

		if response_is_lookup_shape and pending_request_purpose != "":
			matching_keys.append(key)

	if response_is_lookup_shape and response_username == "":
		for key in matching_keys:
			var request_context = pending_player_state_requests[key]
			var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
			if world_lock_ui_open and request_purpose == "world_lock_access_check":
				fallback_key = key
				fallback_request = request_context.duplicate(true)
				break

		if fallback_key == "" and matching_keys.size() == 1:
			fallback_key = matching_keys[0]
			fallback_request = pending_player_state_requests[fallback_key].duplicate(true)

	if response_is_lookup_shape and world_lock_ui_open and fallback_key == "" and matching_keys.size() > 0:
		for key in matching_keys:
			var request_context = pending_player_state_requests[key]
			var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
			if request_purpose == "world_lock_access_check":
				fallback_key = key
				fallback_request = request_context.duplicate(true)
				break

	if fallback_key == "":
		_log_player_state_lookup("no fallback request match", {"keys": str(pending_player_state_requests.keys())})
		return {}

	_log_player_state_lookup("consumed fallback request", {"request_id": str(fallback_request.get("request_id", "")), "purpose": str(fallback_request.get("purpose", ""))})
	pending_player_state_requests.erase(fallback_key)
	return fallback_request


func response_is_player_state_lookup_shape(data: Dictionary) -> bool:
	if data == null:
		return false

	if data.has("found") or data.has("player_data") or data.has("account") or data.has("account_data") or data.has("username") or data.has("account_username"):
		return true

	var direct_username = _extract_username_from_player_state_payload(data)
	if direct_username != "":
		return true

	var nested_data = data.get("data", null)
	if nested_data is Dictionary:
		if nested_data.has("found") or nested_data.has("player_data") or nested_data.has("account") or nested_data.has("account_data"):
			return true
		var nested_request_id = str(nested_data.get("request_id", "")).strip_edges()
		if nested_request_id != "":
			return true

	var ok_value = data.get("ok", null)
	if ok_value is bool or ok_value is int or ok_value is String:
		return pending_player_state_requests.size() == 1

	return false


func _is_any_pending_request_for_username(response_username: String) -> bool:
	var normalized = response_username.strip_edges().to_upper()
	if normalized == "":
		return false

	for key in pending_player_state_requests.keys():
		var request_context = pending_player_state_requests[key]
		if not (request_context is Dictionary):
			continue
		var pending_username = str(request_context.get("requested_username", request_context.get("username", ""))).strip_edges().to_upper()
		if pending_username != "" and pending_username == normalized:
			return true

	return false


func is_player_state_like_message_type(message_type: String) -> bool:
	if message_type == "":
		return false

	var normalized = message_type.to_lower()
	if normalized == "player_state":
		return true
	if normalized.begins_with("player_state") || normalized.ends_with("player_state"):
		return true
	return normalized.find("player") != -1 and normalized.find("state") != -1 and normalized.find("lookup") != -1


func _extract_username_from_player_state_payload(data: Dictionary, depth: int = 0) -> String:
	if data == null or depth > 8:
		return ""

	var direct_candidates = ["username", "account_username", "name", "display_name"]
	for candidate in direct_candidates:
		var candidate_value = str(data.get(candidate, "")).strip_edges()
		if candidate_value != "":
			return candidate_value

	for nested_key in ["data", "player_data", "account", "account_data"]:
		var nested_data = data.get(nested_key, null)
		if nested_data is Dictionary and not nested_data.is_empty():
			var nested_username = _extract_username_from_player_state_payload(nested_data, depth + 1)
			if nested_username != "":
				return nested_username

	return ""


func apply_pending_server_player_state_if_ready() -> void:
	if pending_server_player_state.is_empty():
		return
	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return
	if not world_node.has_method("apply_network_player_state"):
		return
	world_node.apply_network_player_state(pending_server_player_state)
	pending_server_player_state.clear()


func get_world_node():
	var scene = get_tree().current_scene
	if scene == null:
		return null
	if scene.has_method("handle_network_player_position"):
		return scene
	var found = scene.find_child("World", true, false)
	if found != null and found.has_method("handle_network_player_position"):
		return found
	return null


func is_world_node_active() -> bool:
	var world_node = get_world_node()
	if world_node == null:
		return false
	if "in_world" in world_node:
		return bool(world_node.get("in_world"))
	return true


func get_chat_ui_node():
	var scene = get_tree().current_scene
	if scene == null:
		return null
	var chat_ui = scene.get_node_or_null("UI/ChatUI")
	if chat_ui == null:
		chat_ui = scene.find_child("ChatUI", true, false)
	return chat_ui


func get_current_profile_name_from_world() -> String:
	if has_active_session() and session_username.strip_edges() != "":
		return session_username.strip_edges()

	var world_node = get_world_node()
	if world_node != null and world_node.has_method("get_current_profile_name"):
		var profile_name = str(world_node.get_current_profile_name()).strip_edges()
		if profile_name != "":
			return profile_name
	return player_name


func sync_player_name_from_world() -> void:
	var latest_name = get_current_profile_name_from_world().strip_edges()
	if latest_name == "":
		latest_name = "Guest"
	if latest_name == player_name:
		return
	player_name = latest_name


func get_equipment_slots() -> Dictionary:
	var slots = {}
	var world_node = get_world_node()
	if world_node == null:
		return slots
	var hand_item = ""
	if "equipped_tool" in world_node:
		hand_item = str(world_node.get("equipped_tool"))
	var back_item = ""
	if "equipped_back_item" in world_node:
		back_item = str(world_node.get("equipped_back_item"))
	slots["hand"] = hand_item
	slots["back"] = back_item

	var future_slot_properties = {
		"hair": "equipped_hair_item",
		"shirt": "equipped_shirt_item",
		"pants": "equipped_pants_item",
		"shoes": "equipped_shoes_item"
	}

	for slot_name in future_slot_properties.keys():
		var property_name = str(future_slot_properties[slot_name])
		if property_name in world_node:
			slots[slot_name] = str(world_node.get(property_name))
	return slots


func get_player_animation_state() -> String:
	var world_node = get_world_node()
	if world_node == null:
		return "idle"
	var player_node = null
	if "player" in world_node:
		player_node = world_node.player
	if player_node != null and player_node is CharacterBody2D:
		if not player_node.is_on_floor():
			return "jump"
		if abs(player_node.velocity.x) > 6.0:
			return "walk"
	return "idle"


func sync_current_world_population_from_players(world_name: String, players_data) -> void:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return
	var ids = {}
	if players_data is Array:
		for entry in players_data:
			if entry is Dictionary:
				var id = str(entry.get("player_id", "")).strip_edges()
				if id != "":
					ids[id] = true
	world_population_players[clean_world] = ids
	world_population_counts[clean_world] = ids.size()
	world_population_changed.emit(world_population_counts.duplicate(true))


func _apply_world_population_payload(raw_counts: Dictionary, clear_unreported: bool = false) -> void:
	if raw_counts.is_empty():
		return

	var incoming_keys = {}
	var updated_counts = {}

	for raw_world in raw_counts.keys():
		var clean_world = _safe_world_name(raw_world)
		if clean_world == "":
			continue
		incoming_keys[clean_world] = true
		updated_counts[clean_world] = _safe_world_count(raw_counts.get(raw_world, 0))
		world_population_players[clean_world] = world_population_players.get(clean_world, {})

	if clear_unreported:
		for existing_world in world_population_players.keys():
			if not incoming_keys.has(existing_world):
				world_population_players.erase(existing_world)
		for existing_world in world_population_counts.keys():
			if not incoming_keys.has(existing_world):
				world_population_counts.erase(existing_world)

	for world_name in updated_counts.keys():
		world_population_counts[world_name] = updated_counts[world_name]

	world_population_changed.emit(world_population_counts.duplicate(true))


func remember_world_player(world_name: String, id: String) -> void:
	var clean_world = _safe_world_name(world_name)
	var clean_id = id.strip_edges()
	if clean_world == "" or clean_id == "" or clean_id == player_id:
		return
	var ids = world_population_players.get(clean_world, {})
	if not (ids is Dictionary):
		ids = {}
	ids[clean_id] = true
	world_population_players[clean_world] = ids
	world_population_counts[clean_world] = ids.size()
	world_population_changed.emit(world_population_counts.duplicate(true))


func forget_world_player(world_name: String, id: String) -> void:
	var clean_world = _safe_world_name(world_name)
	var clean_id = id.strip_edges()
	if clean_world == "" or clean_id == "":
		return
	var ids = world_population_players.get(clean_world, {})
	if ids is Dictionary:
		ids.erase(clean_id)
		world_population_players[clean_world] = ids
		world_population_counts[clean_world] = ids.size()
		world_population_changed.emit(world_population_counts.duplicate(true))


func get_world_population_counts() -> Dictionary:
	return world_population_counts.duplicate(true)


func _safe_int(value, fallback: int, min_value: int = -2147483648, max_value: int = 2147483647) -> int:
	if value is int:
		return clamp(value, min_value, max_value)
	if value is float:
		if not is_finite(float(value)):
			return fallback
		return clamp(int(value), min_value, max_value)
	if value is String:
		var text = value.strip_edges()
		if text == "":
			return fallback
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


func _safe_float(value, fallback: float, min_value: float = -1.0e9, max_value: float = 1.0e9) -> float:
	if value is int or value is float:
		var num = float(value)
		if not is_finite(num):
			return fallback
		return clamp(num, min_value, max_value)
	if value is String:
		var text = value.strip_edges()
		if text.is_valid_float():
			var parsed_num = float(text)
			if not is_finite(parsed_num):
				return fallback
			return clamp(parsed_num, min_value, max_value)
	return fallback


func _safe_bool(value, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		if not is_finite(float(value)):
			return fallback
		return float(value) != 0.0
	if value is String:
		var text = value.strip_edges().to_lower()
		if text == "":
			return fallback
		match text:
			"1", "true", "yes", "on", "y":
				return true
			"0", "false", "no", "off", "n":
				return false
	return fallback


func _safe_world_count(raw_count) -> int:
	if raw_count is int:
		return max(0, raw_count)
	if raw_count is float:
		if not is_finite(float(raw_count)):
			return 0
		return max(0, int(raw_count))
	return 0


func _safe_world_name(value) -> String:
	var raw_text = _safe_string(value, "", MAX_WORLD_NAME_LENGTH).strip_edges().to_lower()
	if raw_text == "":
		return ""
	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var result = ""
	for i in range(raw_text.length()):
		var character = raw_text.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"
	if result == "":
		return ""
	if result.length() > MAX_WORLD_NAME_LENGTH:
		result = result.substr(0, MAX_WORLD_NAME_LENGTH)
	return result.to_upper()


func _get_message_world_name(data: Dictionary) -> String:
	if not (data is Dictionary):
		return ""

	for key in ["world", "world_name", "world_id", "current_world_id"]:
		if not data.has(key):
			continue
		var clean_world = _safe_world_name(data.get(key, ""))
		if clean_world != "":
			return clean_world

	return ""


func _can_send_rate_limited(counter_key: String, max_per_second: int) -> bool:
	if max_per_second <= 0:
		return true
	var now = float(Time.get_ticks_msec()) * 0.001
	var bucket = _send_rate_counters.get(counter_key, {})
	if not (bucket is Dictionary):
		bucket = {}
	var window_start = float(bucket.get("window_start", now))
	var count = int(bucket.get("count", 0))
	if now - window_start >= 1.0:
		window_start = now
		count = 0
	if count >= max_per_second:
		return false
	count += 1
	bucket["window_start"] = window_start
	bucket["count"] = count
	_send_rate_counters[counter_key] = bucket
	return true
