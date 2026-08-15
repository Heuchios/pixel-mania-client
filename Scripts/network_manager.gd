extends Node

signal server_auth_finished(data)
signal server_connection_changed(is_connected)
signal world_population_changed(world_counts)
signal owned_locked_worlds_received(data)
signal client_update_required(payload)
signal iap_checkout_session_result(data)
signal iap_purchase_result(data)
signal landfill_race_state_received(data)
signal landfill_race_results_received(data)
signal landfill_status_received(data)
signal landfill_join_result_received(data)
signal landfill_leaderboard_received(data)
signal landfill_claim_result_received(data)

const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")

var socket := WebSocketPeer.new()
var socket_generation: int = 0
var connected := false
var player_id := ""
var player_name := "Guest"
var account_id := ""
var profile_id := ""
var game_player_id := ""
var session_username := ""
var session_email := ""
var session_token := ""
var session_role := "player"
var session_authenticated := false
var server_session_authenticated := false
var pending_saved_refresh_token := ""
var saved_refresh_login_in_flight := false
var developer_pin_required := false
var developer_pin_unlocked := false
var current_world_name := "START"
var pending_join_enabled := false
var pending_join_world_name := ""
var pending_join_profile_name := ""
var pending_server_player_state := {}
var pending_server_world_state: Dictionary = {}
var pending_world_state_stream: Dictionary = {}
var world_entry_profile: Dictionary = {}
var active_join_request_id := ""
var active_join_world_name := ""
var active_join_request_pending := false
var active_world_entry_session_id := ""
var active_world_entry_revision := 0
var active_world_entry_block_revision := 0
var world_entry_requires_ready := false
var world_entry_ready_sent := false
var world_entry_active := false
var pending_world_entry_ready: Dictionary = {}
var world_entry_ready_retry_at_msec := 0
var pending_world_entry_block_updates: Array[Dictionary] = []
var pending_player_state_requests := {}
var world_population_counts := {}
var world_population_players := {}
var world_population_authoritative := {}
var world_movement_guidance := {}
var owned_locked_worlds_cache: Array = []
var login_notice_message := ""
var client_update_payload: Dictionary = {}
var auth_request_counter := 0
var developer_pin_unlock_request_counter := 0
var reconnect_timer := 0.0
var server_url_index := 0
var active_api_base := ""
var active_server_urls: Array[String] = []
var configured_server_urls: Array[String] = []
var allowed_world_route_urls: Array[String] = []
var last_connection_attempt_url := ""
var last_connection_error := ""
var last_connection_started_at := 0
var last_close_code := -1
var last_close_reason := ""
var last_ready_state := WebSocketPeer.STATE_CLOSED
var login_redirect_pending := false
var world_route_redirect_pending := false
var world_route_redirect_target_url := ""
var world_route_redirect_world_name := ""
var world_route_redirect_action := ""
var world_route_redirect_attempts := {}
var debug_last_sent_equipment_key := ""
var debug_last_sent_animation_state := ""
var movement_sequence := 0
var local_position_pending_payload: Dictionary = {}
var local_position_pending_world: String = ""
var local_position_pending_reason: String = ""
var local_position_pending_queued_msec: int = 0
var has_local_position_pending := false
var local_position_batch_window_msec := 0
var local_position_batch_budget := 0
var local_position_batch_world := ""
var local_position_batch_limit := 0
var local_position_batch_sends := 0
var local_position_batch_skips := 0
var local_position_queue_last_flush_msec := 0
var _last_local_position_debug_msec := 0
var last_accepted_position_sequence := 0
var last_rejected_position_sequence := 0
var world_event_tile_update_queue: Array[Dictionary] = []
var world_event_tile_update_queue_read_index := 0

const API_BASE := "https://api.pixelmaniagame.com"
const WS_URL := "wss://api.pixelmaniagame.com/ws-a"
var WORLD_ROUTE_WS_URLS: Array[String] = [
	"wss://api.pixelmaniagame.com/ws-a",
	"wss://api.pixelmaniagame.com/ws-b"
]
# Keep in sync with export_presets.cfg "version/name" on every release build.
# The server gates packets against this value via MIN_CLIENT_VERSION.
const CLIENT_VERSION := "1.1.0"
const CLIENT_PLATFORM := "godot"
const DEBUG_SERVER_PACKETS := false
const DEBUG_ACTION_POSITION_FLOW := false
const DEBUG_LOCAL_APPEARANCE_FLOW := false
const DEBUG_PLAYER_STATE_LOOKUP := false
const NETFOX_IDENTITY_DEBUG_ARG := "--netfox-identity-debug"
const NETFOX_IDENTITY_DEBUG_ENV := "NETFOX_IDENTITY_DEBUG"
const NETFOX_TRUSTED_POSITION_DEBUG_ARG := "--netfox-trusted-position-debug"
const NETFOX_TRUSTED_POSITION_DEBUG_ENV := "NETFOX_TRUSTED_POSITION_DEBUG"
const WORLD_ENTRY_PROFILE_ARG := "--world-entry-profile"
const WORLD_ENTRY_PROFILE_ENV := "PIXELMANIA_WORLD_ENTRY_PROFILE"
const WORLD_ENTRY_FRAME_STALL_THRESHOLD_MS := 33.334
# Upper bound on how long the profile stays open waiting for the loading overlay to
# report that controls were actually handed back. Only reached if the overlay reveal
# path never runs.
const WORLD_ENTRY_CONTROLS_WATCHDOG_MSEC := 5000
const PLAYER_STATE_REQUEST_TIMEOUT_MS := 15000
var SERVER_URLS: Array[String] = WORLD_ROUTE_WS_URLS.duplicate()
const NETWORK_API_OVERRIDE_SETTING := "pixelmania/network/api_base"
const NETWORK_WS_OVERRIDE_SETTING := "pixelmania/network/ws_url"
const NETWORK_WORLD_ROUTE_WS_URLS_SETTING := "pixelmania/network/world_route_ws_urls"
const NETWORK_SEND_SESSION_TOKEN_EVERY_MESSAGE_SETTING := "pixelmania/network/send_session_token_every_message"
const RECONNECT_INTERVAL := 2.0
const PROFILE_PATH := "user://pixelmania_profile.cfg"
const LOGIN_SCENE := "res://Scenes/ui/login/LoginScene.tscn"
var profile_path: String = PROFILE_PATH
const MAX_CHAT_MESSAGE_LENGTH := 220
const MAX_BROADCAST_LENGTH := 260
const MAX_SERVER_MESSAGE_TYPE_LENGTH := 64
const MAX_CLIENT_MESSAGE_BYTES := 65536
const MAX_SERVER_MESSAGE_BYTES := 1024 * 1024
const WORLD_STATE_STREAM_VERSION := 1
const MAX_WORLD_STATE_STREAM_CHUNKS := 256
const MAX_WORLD_STATE_STREAM_SECTIONS := 64
const MAX_WORLD_STATE_STREAM_ASSEMBLED_BYTES := 2 * 1024 * 1024
const MAX_WORLD_STATE_STREAM_WIRE_BYTES := 4 * 1024 * 1024
const WORLD_STATE_STREAM_TIMEOUT_MS := 15000
const WORLD_ENTRY_READY_RETRY_MS := 1000
const MAX_WORLD_ROUTE_URL_LENGTH := 256
const MAX_WORLD_ROUTE_REDIRECT_ATTEMPTS := 2
const MAX_SERVER_PACKETS_PER_FRAME := 96
const MAX_SERVER_PACKET_PROCESS_USEC := 10000
# The elapsed-time budget prevents event updates from monopolizing a frame.
# Keep the count cap high so inexpensive TileMap updates do not gain artificial delay.
const MAX_WORLD_EVENT_TILE_UPDATES_PER_FRAME := 1024
const MAX_WORLD_EVENT_TILE_UPDATE_PROCESS_USEC := 2500
const MAX_USERNAME_LENGTH := 64
const MAX_WORLD_NAME_LENGTH := 64
const MAX_ITEM_ID_LENGTH := 64
const MAX_REQUEST_ID_LENGTH := 64
const MAX_WORLD_ENTRY_SESSION_ID_LENGTH := 128
const MAX_DROP_ID_LENGTH := 96
const MAX_COORDINATE := 1000000
const MAX_ITEM_CATEGORY_LENGTH := 64
const MAX_ITEM_STACK_SIZE := 400
const MAX_DROP_TILE_AMOUNT := 2000
const MAX_BULK_DROP_PICKUP_IDS := 64
const MAX_ITEM_PRICE := 999999
const MAX_INVENTORY_TRANSACTION_RATE_PER_SECOND := 20
const MAX_INVENTORY_UPGRADE_RATE_PER_SECOND := 4
const MAX_WORLD_BLOCK_RATE_PER_SECOND := 30
const MAX_WORLD_BLOCK_RECONCILE_RATE_PER_SECOND := 8
const MAX_WORLD_ELECTRICAL_RATE_PER_SECOND := 30
const MAX_WORLD_SEED_RATE_PER_SECOND := 20
const MAX_WORLD_INTERACTION_RATE_PER_SECOND := 20
const MAX_WORLD_DROP_RATE_PER_SECOND := 24
const MAX_WORLD_DROP_PICKUP_RATE_PER_SECOND := 12
const MAX_CHAT_RATE_PER_SECOND := 8
const MAX_BROADCAST_RATE_PER_SECOND := 5
const MAX_PULL_RATE_PER_SECOND := 6
const MAX_WORLD_SEED_GROW_TIME_SECONDS := 3600.0 * 24.0 * 30.0
const MAX_BLOCK_HIT_METRIC := 1024
# Keep WebSocket movement responsive for current interpolation/backend.
# Lower this later only after remote interpolation buffer is retuned.
const MAX_PLAYER_POSITION_RATE_PER_SECOND := 60
const LOCAL_POSITION_QUEUE_FLUSH_DEBUG_INTERVAL_MS := 600
const LOCAL_POSITION_QUEUE_FLUSH_INTERVAL_MS := 120
const MAX_PLAYER_PUNCH_RATE_PER_SECOND := 8
const MAX_NETFOX_STATE_BRIDGE_RATE_PER_SECOND := 20
const MAX_TRADE_RATE_PER_SECOND := 14
const MAX_FRIEND_RATE_PER_SECOND := 8
const MAX_PLAYER_PROFILE_RATE_PER_SECOND := 2
const MAX_TRADE_SLOT_INDEX := 31
const MAX_TRADE_ID_LENGTH := 96
const MAX_WORLD_POPULATION_RATE_PER_SECOND := 10
const MAX_OWNED_LOCKED_WORLDS_RATE_PER_SECOND := 4
const MAX_LANDFILL_STATUS_RATE_PER_SECOND := 4
const MAX_LANDFILL_LEADERBOARD_RATE_PER_SECOND := 4
const MAX_LANDFILL_ACTION_RATE_PER_SECOND := 2
const MAX_WORLD_POPULATION_REQUEST_SIZE := 64
const MAX_WORLD_INTERACTION_TEXT_LENGTH := 128
const MAX_DOOR_ID_LENGTH := 32
const MAX_DOOR_NAME_LENGTH := 64
const MAX_DOOR_DESTINATION_LENGTH := 80
const MAX_DOOR_PASSWORD_LENGTH := 32
const MIN_PLAYER_COORDINATE := -1000000
const MAX_PLAYER_COORDINATE := 1000000
const WORLD_POPULATION_RESET_UNRESPONSIVE_AFTER_SECONDS := 600.0
const PICKUP_REMAINING_AMOUNT_UNKNOWN := -2147483648
const MOVEMENT_VISUAL_SYNC_INTERVAL_MS := 2500
const LOCAL_POSITION_BATCH_BUDGET_WINDOW_MS := 500
const LOCAL_POSITION_BATCH_BURST_SCALE := 1024.0
const AUTH_TOKEN_MESSAGE_TYPES := [
	"login",
	"account_register",
	"account_login",
	"account_token_login",
	"dev_backend_login",
	"developer_pin_unlock",
	"account_state_save",
	"netfox_spawn_ticket_request"
]
const MOVEMENT_VISUAL_SYNC_REASONS := ["spawn", "join", "respawn", "teleport", "force", "sync"]

const WORLD_BLOCK_ACTIONS := ["hit", "place", "break"]
const WORLD_BLOCK_LAYERS := ["foreground", "background"]
const WORLD_SEED_ACTIONS := ["place"]
const WORLD_INTERACTION_ACTIONS := [
	"door_state",
	"wooden_entrance_state",
	"ceiling_lamp_state",
	"sign_text",
	"world_lock_state",
	"area_lock_state",
	"vend_state",
	"safe_state",
	"mailbox_state",
	"bulletin_board_state",
	"display_state",
	"tackle_box_state",
	"chicken_state",
	"cow_state",
	"duck_state",
	"dice_roll",
	"checkpoint_activate",
	"anti_punch_state",
	"anti_talk_state",
	"anti_gravity_state",
	"theme_machine_state",
	"entrance_gate_move",
	"world_lock_move",
	"door_move",
	"entrance_pass",
	"springboard_animation"
]

const INVENTORY_TRANSACTION_ACTIONS := [
	"craft_recipe",
	"furnace_recipe",
	"safe_get_state",
	"safe_deposit",
	"safe_withdraw",
	"display_get_state",
	"display_deposit",
	"display_withdraw",
	"donation_box_get_state",
	"donation_box_donate",
	"donation_box_retrieve",
	"donation_box_retrieve_all",
	"seed_splice",
	"seed_place",
	"seed_harvest",
	"convert_world_lock",
	"world_lock_get_key",
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
const AUTH_ROLE_DESIGNER := "designer"
const AUTH_ROLE_DEVELOPER := "developer"
const AUTH_ROLE_ADMIN := "admin"

var _send_rate_counters := {}
var netfox_spawn_routes: Dictionary = {}
var _last_netfox_trusted_position_debug_msec := 0
var _last_movement_visual_sync_msec := 0
var _last_movement_visual_key := ""


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


func trace_world_block_event(event: String, data: Dictionary = {}) -> void:
	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return
	if not ("block_manager" in world_node):
		return
	var manager = world_node.get("block_manager")
	if manager != null and manager.has_method("trace_authoritative_place_event"):
		manager.trace_authoritative_place_event("network_" + event, data)


func debug_netfox_identity(message: String, extra_data: Dictionary = {}) -> void:
	if not is_netfox_identity_debug_enabled():
		return

	var identity := get_active_identity_payload(str(extra_data.get("world", current_world_name)))
	print("[NETFOX_IDENTITY][Client] " + message + " identity=" + str(identity) + " data=" + str(extra_data))


func debug_netfox_trusted_position(message: String, extra_data: Dictionary = {}) -> void:
	if not is_netfox_trusted_position_debug_enabled():
		return

	var identity := get_active_identity_payload(str(extra_data.get("world", current_world_name)))
	print("[NETFOX_TRUSTED_POSITION][Client] " + message + " identity=" + str(identity) + " data=" + str(extra_data))


func is_netfox_identity_debug_enabled() -> bool:
	if MovementMode != null and MovementMode.has_method("has_launch_arg") and MovementMode.has_launch_arg(NETFOX_IDENTITY_DEBUG_ARG):
		return true

	var env_value := OS.get_environment(NETFOX_IDENTITY_DEBUG_ENV).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func is_netfox_trusted_position_debug_enabled() -> bool:
	if MovementMode != null and MovementMode.has_method("has_launch_arg") and MovementMode.has_launch_arg(NETFOX_TRUSTED_POSITION_DEBUG_ARG):
		return true

	var env_value := OS.get_environment(NETFOX_TRUSTED_POSITION_DEBUG_ENV).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func is_world_entry_profile_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	if WORLD_ENTRY_PROFILE_ARG in OS.get_cmdline_args() or WORLD_ENTRY_PROFILE_ARG in OS.get_cmdline_user_args():
		return true
	var env_value := OS.get_environment(WORLD_ENTRY_PROFILE_ENV).strip_edges().to_lower()
	return ["1", "true", "yes", "on", "debug"].has(env_value)


func _sample_world_entry_memory_bytes() -> int:
	return maxi(0, int(Performance.get_monitor(Performance.MEMORY_STATIC)))


func begin_world_entry_profile(world_name: String, request_id: String) -> void:
	# The profile is now ALWAYS collected, not just in verbose/debug builds. Collecting a
	# stage is one Time.get_ticks_usec() read plus one small array append -- far too cheap
	# to matter next to the work it measures -- and without it there is no way to tell
	# where a slow join actually went in a release build, which is the only build players
	# ever run. is_world_entry_profile_enabled() now only controls the VERBOSE per-stage
	# [world-entry] JSON spam and the per-stage memory sampling (which is genuinely not
	# free, so it stays gated). The final [WORLD_JOIN_PROFILE] timeline always prints.
	var verbose := is_world_entry_profile_enabled()
	var now_usec := Time.get_ticks_usec()
	var memory_bytes := _sample_world_entry_memory_bytes() if verbose else 0
	world_entry_profile = {
		"active": true,
		"world": _safe_world_name(world_name),
		"request_id": _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH),
		"started_usec": now_usec,
		"last_stage_usec": now_usec,
		"first_response_usec": 0,
		"first_packet_available_usec": 0,
		"frames_since_join": 0,
		"first_world_byte_usec": 0,
		"wire_bytes": 0,
		"packet_count": 0,
		"parse_usec": 0,
		"peak_memory_bytes": memory_bytes,
		"max_frame_delta_ms": 0.0,
		"frame_stall_count": 0,
		"last_loading_percent": -1,
		"activated_at_msec": 0,
		"pending_controls_extra": {},
		"verbose": verbose,
		"stage_history": []
	}
	record_world_entry_stage("client_join_request")


func record_world_entry_stage(stage: String, extra: Dictionary = {}) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	var now_usec := Time.get_ticks_usec()
	var started_usec := int(world_entry_profile.get("started_usec", now_usec))
	var last_stage_usec := int(world_entry_profile.get("last_stage_usec", started_usec))
	world_entry_profile["last_stage_usec"] = now_usec

	# Always-on path: record the stage boundary into stage_history. This is the data the
	# final [WORLD_JOIN_PROFILE] timeline is built from, and it is deliberately cheap --
	# no memory sampling, no JSON, no string building.
	var stage_total_ms := snappedf(float(now_usec - started_usec) / 1000.0, 0.001)
	var stage_delta_ms := snappedf(float(now_usec - last_stage_usec) / 1000.0, 0.001)
	var stage_history: Variant = world_entry_profile.get("stage_history", [])
	if stage_history is Array:
		(stage_history as Array).append({
			"stage": stage,
			"stage_ms": stage_delta_ms,
			"total_ms": stage_total_ms
		})

	# Everything below is the VERBOSE path only.
	if not bool(world_entry_profile.get("verbose", false)):
		return

	var memory_bytes := _sample_world_entry_memory_bytes()
	var peak_memory_bytes := maxi(memory_bytes, int(world_entry_profile.get("peak_memory_bytes", memory_bytes)))
	world_entry_profile["peak_memory_bytes"] = peak_memory_bytes
	var event := {
		"event": "world_entry_stage",
		"stage": stage,
		"world": str(world_entry_profile.get("world", "")),
		"request_id": str(world_entry_profile.get("request_id", "")),
		"total_ms": stage_total_ms,
		"stage_ms": stage_delta_ms,
		"wire_bytes": int(world_entry_profile.get("wire_bytes", 0)),
		"packet_count": int(world_entry_profile.get("packet_count", 0)),
		"parse_ms": snappedf(float(world_entry_profile.get("parse_usec", 0)) / 1000.0, 0.001),
		"memory_bytes": memory_bytes,
		"peak_memory_bytes": peak_memory_bytes,
		"max_frame_delta_ms": snappedf(float(world_entry_profile.get("max_frame_delta_ms", 0.0)), 0.001),
		"frame_stall_count": int(world_entry_profile.get("frame_stall_count", 0))
	}
	for key in extra.keys():
		event[key] = extra[key]
	print("[world-entry] " + JSON.stringify(event))


func _record_world_entry_packet(message_type: String, wire_bytes: int, parse_usec: int) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	if not ["join_world_ok", "world_state", "world_state_stream_begin", "world_state_stream_chunk", "world_state_stream_end"].has(message_type):
		return
	world_entry_profile["wire_bytes"] = int(world_entry_profile.get("wire_bytes", 0)) + maxi(0, wire_bytes)
	world_entry_profile["packet_count"] = int(world_entry_profile.get("packet_count", 0)) + 1
	world_entry_profile["parse_usec"] = int(world_entry_profile.get("parse_usec", 0)) + maxi(0, parse_usec)
	if int(world_entry_profile.get("first_response_usec", 0)) <= 0:
		world_entry_profile["first_response_usec"] = Time.get_ticks_usec()
		record_world_entry_stage("client_first_response", {
			"message_type": message_type,
			"ttfb_ms": snappedf(float(int(world_entry_profile.get("first_response_usec", 0)) - int(world_entry_profile.get("started_usec", 0))) / 1000.0, 0.001)
		})
	if message_type != "join_world_ok" and int(world_entry_profile.get("first_world_byte_usec", 0)) <= 0:
		world_entry_profile["first_world_byte_usec"] = Time.get_ticks_usec()
		record_world_entry_stage("client_first_world_byte", {
			"message_type": message_type,
			"ttfwb_ms": snappedf(float(int(world_entry_profile.get("first_world_byte_usec", 0)) - int(world_entry_profile.get("started_usec", 0))) / 1000.0, 0.001)
		})


func _get_world_entry_transfer_ms() -> float:
	var first_world_byte_usec := int(world_entry_profile.get("first_world_byte_usec", 0))
	if first_world_byte_usec <= 0:
		return 0.0
	return snappedf(float(Time.get_ticks_usec() - first_world_byte_usec) / 1000.0, 0.001)


func _sample_world_entry_frame(delta: float) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	var delta_ms := maxf(0.0, delta * 1000.0)
	world_entry_profile["max_frame_delta_ms"] = maxf(
		float(world_entry_profile.get("max_frame_delta_ms", 0.0)),
		delta_ms
	)
	if delta_ms >= WORLD_ENTRY_FRAME_STALL_THRESHOLD_MS:
		world_entry_profile["frame_stall_count"] = int(world_entry_profile.get("frame_stall_count", 0)) + 1
	var memory_bytes := _sample_world_entry_memory_bytes()
	world_entry_profile["peak_memory_bytes"] = maxi(
		memory_bytes,
		int(world_entry_profile.get("peak_memory_bytes", memory_bytes))
	)
	# Watchdog: the loading overlay normally completes the profile once the player is
	# genuinely unlocked. If the overlay path never runs, close the profile out here
	# so a run always produces a terminal stage instead of a truncated report.
	var activated_at_msec := int(world_entry_profile.get("activated_at_msec", 0))
	if activated_at_msec > 0 and Time.get_ticks_msec() - activated_at_msec >= WORLD_ENTRY_CONTROLS_WATCHDOG_MSEC:
		complete_world_entry_profile({"completion_source": "watchdog"})


func update_world_entry_loading_progress(received_count: int, chunk_count: int) -> void:
	if chunk_count <= 0:
		return
	var percent := clampi(int(floor(float(received_count) * 100.0 / float(chunk_count))), 0, 100)
	if not world_entry_profile.is_empty():
		if percent == int(world_entry_profile.get("last_loading_percent", -1)):
			return
		world_entry_profile["last_loading_percent"] = percent
	var world_node: Node = get_world_node() as Node
	if world_node != null and world_node.has_method("update_smooth_world_load_message"):
		world_node.update_smooth_world_load_message("Loading world data " + str(percent) + "%")


func complete_world_entry_profile(extra: Dictionary = {}) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	# Carry through the activation details recorded when world_entry_active arrived so
	# the terminal stage still reports the revisions it always did, regardless of
	# whether the loading overlay or the watchdog closed the profile out.
	var merged_extra: Dictionary = {}
	var pending_extra: Variant = world_entry_profile.get("pending_controls_extra", {})
	if pending_extra is Dictionary:
		merged_extra = (pending_extra as Dictionary).duplicate()
	for key in extra.keys():
		merged_extra[key] = extra[key]
	var activated_at_msec := int(world_entry_profile.get("activated_at_msec", 0))
	if activated_at_msec > 0:
		merged_extra["reveal_tail_ms"] = maxi(0, Time.get_ticks_msec() - activated_at_msec)
	record_world_entry_stage("client_controls_enabled", merged_extra)
	_log_world_join_profile_summary()
	world_entry_profile["active"] = false


# Permanent, ALWAYS-ON join-latency telemetry. Prints one full ordered stage timeline per
# completed join -- the cumulative "at" time and the per-stage delta for every recorded
# boundary from join click to controls enabled -- with severity markers so the slow stage is
# visible at a glance instead of having to correlate many [world-entry] lines by hand:
#
#     (blank)  < 50ms    fine
#     "!"      >= 50ms   noticeable
#     "!!"     >= 100ms  significant bottleneck
#     "!!!"    >= 500ms  needs investigation
#
# Stored in last_world_join_profile_text so the /worldjoinprofile dev command can reprint the
# most recent one on demand. See world-join latency investigation.
const WORLD_JOIN_STAGE_WARN_MS := 50.0
const WORLD_JOIN_STAGE_SIGNIFICANT_MS := 100.0
const WORLD_JOIN_STAGE_INVESTIGATE_MS := 500.0
const WORLD_JOIN_TOTAL_TARGET_MS := 1000.0
const WORLD_JOIN_TOTAL_WARN_MS := 750.0

var last_world_join_profile_text: String = ""


func _world_join_stage_marker(stage_ms: float) -> String:
	if stage_ms >= WORLD_JOIN_STAGE_INVESTIGATE_MS:
		return "!!!"
	if stage_ms >= WORLD_JOIN_STAGE_SIGNIFICANT_MS:
		return "!!"
	if stage_ms >= WORLD_JOIN_STAGE_WARN_MS:
		return "!"
	return ""


func _log_world_join_profile_summary() -> void:
	if world_entry_profile.is_empty():
		return
	var started_usec := int(world_entry_profile.get("started_usec", 0))
	var total_ms := snappedf(
		float(int(world_entry_profile.get("last_stage_usec", 0)) - started_usec) / 1000.0,
		0.001
	)

	var slowest_stage := ""
	var slowest_stage_ms := 0.0
	var lines: PackedStringArray = []
	lines.append("========== WORLD JOIN PROFILE ==========")
	lines.append("World:   %s" % str(world_entry_profile.get("world", "")))
	lines.append("Request: %s" % str(world_entry_profile.get("request_id", "")))
	lines.append("")
	lines.append("%-38s %10s %10s" % ["STAGE", "AT(ms)", "DELTA(ms)"])
	lines.append("----------------------------------------------------------------")

	var stage_history: Variant = world_entry_profile.get("stage_history", [])
	if stage_history is Array:
		for entry in (stage_history as Array):
			if not (entry is Dictionary):
				continue
			var row := entry as Dictionary
			var stage_name := str(row.get("stage", ""))
			var stage_ms := float(row.get("stage_ms", 0.0))
			var at_ms := float(row.get("total_ms", 0.0))
			if stage_ms > slowest_stage_ms:
				slowest_stage_ms = stage_ms
				slowest_stage = stage_name
			lines.append("%-38s %10.1f %10.1f %s" % [stage_name, at_ms, stage_ms, _world_join_stage_marker(stage_ms)])

	var first_world_byte_usec := int(world_entry_profile.get("first_world_byte_usec", 0))
	var first_response_usec := int(world_entry_profile.get("first_response_usec", 0))
	var transfer_ms := 0.0
	if first_world_byte_usec > 0:
		transfer_ms = snappedf(float(first_world_byte_usec - started_usec) / 1000.0, 0.001)
	var server_roundtrip_ms := 0.0
	if first_response_usec > 0:
		server_roundtrip_ms = snappedf(float(first_response_usec - started_usec) / 1000.0, 0.001)

	var first_packet_available_usec := int(world_entry_profile.get("first_packet_available_usec", 0))
	var bytes_available_ms := 0.0
	if first_packet_available_usec > 0:
		bytes_available_ms = snappedf(float(first_packet_available_usec - started_usec) / 1000.0, 0.001)

	lines.append("----------------------------------------------------------------")
	lines.append("Frames rendered during join:    %8d" % int(world_entry_profile.get("frames_since_join", 0)))
	lines.append("Time to first bytes AVAILABLE:  %8.1f ms   <- server+network" % bytes_available_ms)
	lines.append("Time to first server response:  %8.1f ms   <- + client dispatch delay" % server_roundtrip_ms)
	lines.append("  (gap between those two = client not reading the socket)")
	lines.append("Time to first world byte:       %8.1f ms" % transfer_ms)
	lines.append("Snapshot wire bytes:            %8d" % int(world_entry_profile.get("wire_bytes", 0)))
	lines.append("Snapshot packets:               %8d" % int(world_entry_profile.get("packet_count", 0)))
	lines.append("Client JSON parse:              %8.1f ms" % (float(world_entry_profile.get("parse_usec", 0)) / 1000.0))
	lines.append("Frame stalls during join:       %8d" % int(world_entry_profile.get("frame_stall_count", 0)))
	lines.append("Worst frame delta:              %8.1f ms" % float(world_entry_profile.get("max_frame_delta_ms", 0.0)))
	lines.append("Slowest stage:  %s (%.1f ms)" % [slowest_stage, slowest_stage_ms])
	lines.append("TOTAL JOIN (click -> playable): %8.1f ms" % total_ms)
	lines.append("========================================")

	var report := "\n".join(lines)
	last_world_join_profile_text = report
	print(report)

	# Machine-readable one-liner, kept for log grepping / regression tooling.
	print("[WORLD_JOIN_PROFILE] " + JSON.stringify({
		"world": str(world_entry_profile.get("world", "")),
		"request_id": str(world_entry_profile.get("request_id", "")),
		"bytes_available_ms": bytes_available_ms,
		"frames_since_join": int(world_entry_profile.get("frames_since_join", 0)),
		"server_roundtrip_ms": server_roundtrip_ms,
		"transfer_ms": transfer_ms,
		"wire_bytes": int(world_entry_profile.get("wire_bytes", 0)),
		"packet_count": int(world_entry_profile.get("packet_count", 0)),
		"parse_ms": snappedf(float(world_entry_profile.get("parse_usec", 0)) / 1000.0, 0.001),
		"frame_stall_count": int(world_entry_profile.get("frame_stall_count", 0)),
		"slowest_stage": slowest_stage,
		"slowest_stage_ms": slowest_stage_ms,
		"TOTAL_JOIN_ms": total_ms
	}))

	if total_ms > WORLD_JOIN_TOTAL_TARGET_MS:
		push_warning(
			"[WORLD_JOIN_PROFILE] REGRESSION: world join exceeded %.0fms target (TOTAL_JOIN=%.1fms) -- slowest stage: %s (%.1fms)"
			% [WORLD_JOIN_TOTAL_TARGET_MS, total_ms, slowest_stage, slowest_stage_ms]
		)
	elif total_ms > WORLD_JOIN_TOTAL_WARN_MS:
		push_warning(
			"[WORLD_JOIN_PROFILE] world join above %.0fms soft budget (TOTAL_JOIN=%.1fms) -- slowest stage: %s (%.1fms)"
			% [WORLD_JOIN_TOTAL_WARN_MS, total_ms, slowest_stage, slowest_stage_ms]
		)


func cancel_world_entry_profile(reason: String) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	record_world_entry_stage("client_join_canceled", {"reason": reason})
	world_entry_profile["active"] = false


func _ready():
	configure_network_urls()
	if not MovementMode.should_run_websocket_backend():
		print("[Movement] WebSocket backend disabled for mode " + MovementMode.get_mode_name())
		return

	if MovementMode.is_netfox_real():
		print("[Movement] WebSocket backend active; movement packets disabled for mode " + MovementMode.get_mode_name())
		_load_saved_session_for_netfox_real_client_launch()
	elif MovementMode.is_custom_authoritative():
		print("[Movement] WebSocket backend active for durable systems; WebSocket player movement disabled for mode " + MovementMode.get_mode_name())

	connect_to_server()


func _process(delta: float) -> void:
	_sample_world_entry_frame(delta)
	if not MovementMode.should_run_websocket_backend():
		return

	# Keep this frame bound to one peer. A route packet can replace `socket` while
	# messages are being handled, and the retired peer must not tear down the new
	# peer's join state afterward.
	var frame_socket: WebSocketPeer = socket
	var frame_socket_generation: int = socket_generation
	frame_socket.poll()
	_sample_world_entry_socket_arrival(frame_socket)

	var state: int = frame_socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		server_session_authenticated = false
		last_connection_error = ""
		last_close_code = -1
		last_close_reason = ""
		server_connection_changed.emit(true)
		print("Connected to PixelMania server")
		send_message(make_login_payload())
		if _should_send_backend_dev_login_on_socket_open():
			_send_backend_dev_login_from_launch_args()
		elif pending_saved_refresh_token != "":
			send_account_refresh_token_login(session_username, pending_saved_refresh_token)
		elif has_active_session():
			send_account_token_login(session_username, session_token)

	process_server_packets_with_budget(frame_socket, frame_socket_generation)
	_process_network_followup()

	# Packet handling may have followed a world-route redirect and installed a
	# replacement peer. Never apply lifecycle state from the retired connection.
	if frame_socket_generation != socket_generation:
		return

	state = frame_socket.get_ready_state()
	# WebSocketPeer can retain packets after reporting CLOSED. Drain every queued
	# packet, including a completed world snapshot, before disconnect cleanup.
	if state == WebSocketPeer.STATE_CLOSED and frame_socket.get_available_packet_count() > 0:
		return

	if state == WebSocketPeer.STATE_CLOSED and last_ready_state != WebSocketPeer.STATE_CLOSED:
		last_close_code = frame_socket.get_close_code()
		last_close_reason = frame_socket.get_close_reason()
		if (
			active_join_request_pending
			or not pending_server_world_state.is_empty()
			or not pending_world_state_stream.is_empty()
			or world_route_redirect_pending
		):
			print("[world-entry] transport_closed ", JSON.stringify({
				"url": last_connection_attempt_url,
				"close_code": last_close_code,
				"close_reason": last_close_reason,
				"connected": connected,
				"authenticated": server_session_authenticated,
				"active_join_pending": active_join_request_pending,
				"active_join_world": active_join_world_name,
				"pending_snapshot": not pending_server_world_state.is_empty(),
				"pending_stream": not pending_world_state_stream.is_empty(),
				"redirect_pending": world_route_redirect_pending,
				"queued_packets": frame_socket.get_available_packet_count()
			}))
		if last_connection_error == "" and not connected:
			last_connection_error = "closed before opening"
	last_ready_state = state as WebSocketPeer.State

	if state == WebSocketPeer.STATE_CLOSED and connected:
		var had_active_session := has_active_session()
		var close_code := last_close_code
		var close_reason := last_close_reason
		connected = false
		server_session_authenticated = false
		server_connection_changed.emit(false)
		var session_must_end := _should_clear_saved_login_for_close(close_code, close_reason)
		if had_active_session and session_must_end and not world_route_redirect_pending:
			clear_world_event_tile_update_queue()
			_end_authenticated_session(
				_make_disconnect_login_notice(close_code, close_reason),
				true,
				false
			)
		elif had_active_session:
			print("[NetworkManager] Transient disconnect; preserving authenticated join state for reconnect.")

	if state == WebSocketPeer.STATE_CLOSED:
		reconnect_timer -= delta
		if reconnect_timer <= 0.0:
			reconnect_timer = RECONNECT_INTERVAL
			connect_to_server()


func _process_network_followup() -> void:
	process_world_event_tile_update_queue()
	process_pending_world_state_stream_timeout()
	apply_pending_server_world_state_if_ready()
	process_pending_world_entry_block_updates()
	process_pending_world_entry_ready_retry()
	apply_pending_server_player_state_if_ready()
	_process_local_position_queue()


# Splits "the server was slow" from "the client wasn't reading the socket".
#
# client_first_response is recorded when the client PROCESSES the first packet after a join
# request, which conflates two very different failures: the server genuinely taking that long
# to answer, versus the reply sitting unread in the socket buffer while the client's main
# thread was busy (scene instantiate, World._ready, a blocking build loop) or while packet
# dispatch was suppressed (process_server_packets_with_budget early-returns during a world
# state apply, and caps at MAX_SERVER_PACKETS_PER_FRAME / MAX_SERVER_PACKET_PROCESS_USEC).
#
# This runs immediately after poll(), before any dispatch or budget check, and stamps the
# moment bytes are actually AVAILABLE. It also counts frames since the join request:
#
#   client_first_packet_available ~= client_first_response  -> genuinely waiting on the server
#   client_first_packet_available <<  client_first_response -> client-side stall, look at
#                                                              frames_since_join to see whether
#                                                              the main thread was even running
func _sample_world_entry_socket_arrival(peer: WebSocketPeer) -> void:
	if world_entry_profile.is_empty() or not bool(world_entry_profile.get("active", false)):
		return
	world_entry_profile["frames_since_join"] = int(world_entry_profile.get("frames_since_join", 0)) + 1
	if int(world_entry_profile.get("first_packet_available_usec", 0)) > 0:
		return
	if peer == null or peer.get_available_packet_count() <= 0:
		return
	world_entry_profile["first_packet_available_usec"] = Time.get_ticks_usec()
	record_world_entry_stage("client_first_packet_available", {
		"frames_since_join": int(world_entry_profile.get("frames_since_join", 0))
	})


func process_server_packets_with_budget(peer: WebSocketPeer, generation: int) -> void:
	if is_world_state_apply_in_progress():
		return

	var processed: int = 0
	var started_usec: int = Time.get_ticks_usec()

	while peer.get_available_packet_count() > 0 and processed < MAX_SERVER_PACKETS_PER_FRAME:
		var packet_bytes: PackedByteArray = peer.get_packet()
		var packet: String = packet_bytes.get_string_from_utf8()
		handle_server_message(packet, packet_bytes.size())
		processed += 1
		if generation != socket_generation:
			break

		if is_world_state_apply_in_progress():
			break

		if Time.get_ticks_usec() - started_usec >= MAX_SERVER_PACKET_PROCESS_USEC:
			break


func is_world_state_apply_in_progress() -> bool:
	var world_node = get_world_node()
	if world_node == null:
		return false
	if "applying_network_world_update" in world_node:
		return bool(world_node.get("applying_network_world_update"))
	return false


func configure_network_urls() -> void:
	active_api_base = API_BASE
	active_server_urls = []
	for value in WORLD_ROUTE_WS_URLS:
		active_server_urls.append(str(value))
	configured_server_urls = active_server_urls.duplicate()

	if not should_allow_network_override():
		refresh_allowed_world_route_urls()
		return

	var api_override = str(ProjectSettings.get_setting(NETWORK_API_OVERRIDE_SETTING, "")).strip_edges()
	var ws_override = str(ProjectSettings.get_setting(NETWORK_WS_OVERRIDE_SETTING, "")).strip_edges()

	if MovementMode != null and MovementMode.has_method("get_launch_arg_value"):
		var launch_api_override := MovementMode.get_launch_arg_value("--pixelmania-api-base", "").strip_edges()
		var launch_ws_override := MovementMode.get_launch_arg_value("--pixelmania-ws-url", "").strip_edges()
		if launch_api_override != "":
			api_override = launch_api_override
		if launch_ws_override != "":
			ws_override = launch_ws_override

	if api_override.begins_with("http://") or api_override.begins_with("https://"):
		active_api_base = api_override

	if ws_override.begins_with("ws://") or ws_override.begins_with("wss://"):
		active_server_urls = [ws_override]

	configured_server_urls = active_server_urls.duplicate()
	refresh_allowed_world_route_urls()


func should_allow_network_override() -> bool:
	if OS.has_feature("android") or OS.get_name().to_lower() == "android":
		return false

	# Never allow production players to redirect the client to a custom API/WebSocket.
	# Keep overrides limited to editor/debug builds only.
	return OS.has_feature("editor") or OS.has_feature("debug")


func connect_to_server(force: bool = false) -> void:
	var state = socket.get_ready_state()
	if force:
		_invalidate_active_join_request_for_transport_change("forced_reconnect")
	if state == WebSocketPeer.STATE_OPEN:
		if not force:
			return
		socket.close(1000, "Reconnect requested.")
		if connected:
			connected = false
			server_session_authenticated = false
			server_connection_changed.emit(false)

	if state == WebSocketPeer.STATE_CONNECTING:
		if not force:
			return
		socket.close()

	if active_server_urls.is_empty():
		return

	socket_generation += 1
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = MAX_SERVER_MESSAGE_BYTES
	socket.outbound_buffer_size = MAX_CLIENT_MESSAGE_BYTES
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


func normalize_world_route_ws_url(value: String) -> String:
	var clean_url := str(value).strip_edges()
	if clean_url.length() > MAX_WORLD_ROUTE_URL_LENGTH:
		return ""
	if not (clean_url.begins_with("ws://") or clean_url.begins_with("wss://")):
		return ""
	while clean_url.ends_with("/") and clean_url.length() > 6:
		clean_url = clean_url.substr(0, clean_url.length() - 1)
	return clean_url


func append_unique_world_route_url(target: Array[String], value: String) -> void:
	var clean_url := normalize_world_route_ws_url(value)
	if clean_url == "":
		return
	if target.has(clean_url):
		return
	target.append(clean_url)


func get_configured_world_route_urls() -> Array[String]:
	var urls: Array[String] = []
	# Same rule as configure_network_urls()'s api_override/ws_override: a custom world-route
	# URL configured via ProjectSettings must never leak into a production build's trusted
	# redirect list. Without this gate, a release export carrying a staging pixelmania/network/
	# world_route_ws_urls value (set via Project Settings, independent of --pixelmania-* launch
	# args) would accept a server-directed redirect to that staging URL as trusted.
	if not should_allow_network_override():
		return urls
	var raw_value = ProjectSettings.get_setting(NETWORK_WORLD_ROUTE_WS_URLS_SETTING, [])
	if raw_value is Array:
		for entry in raw_value:
			append_unique_world_route_url(urls, str(entry))
	elif raw_value is PackedStringArray:
		for entry in raw_value:
			append_unique_world_route_url(urls, str(entry))
	else:
		var raw_text := str(raw_value).strip_edges()
		if raw_text != "":
			for entry in raw_text.split(",", false):
				append_unique_world_route_url(urls, str(entry))
	return urls


func refresh_allowed_world_route_urls() -> void:
	allowed_world_route_urls.clear()
	for url in SERVER_URLS:
		append_unique_world_route_url(allowed_world_route_urls, str(url))
	for url in configured_server_urls:
		append_unique_world_route_url(allowed_world_route_urls, str(url))
	for url in active_server_urls:
		append_unique_world_route_url(allowed_world_route_urls, str(url))
	for url in get_configured_world_route_urls():
		append_unique_world_route_url(allowed_world_route_urls, str(url))


func is_trusted_world_route_redirect_url(raw_url: String) -> bool:
	var clean_url := normalize_world_route_ws_url(raw_url)
	if clean_url == "":
		return false
	if should_allow_network_override():
		return true
	refresh_allowed_world_route_urls()
	return allowed_world_route_urls.has(clean_url)


func push_world_route_url_front(raw_url: String) -> bool:
	var clean_url := normalize_world_route_ws_url(raw_url)
	if clean_url == "":
		return false

	var next_urls: Array[String] = []
	next_urls.append(clean_url)
	for existing in active_server_urls:
		var existing_url := normalize_world_route_ws_url(str(existing))
		if existing_url == "" or existing_url == clean_url:
			continue
		next_urls.append(existing_url)

	active_server_urls = next_urls
	configured_server_urls = active_server_urls.duplicate()
	server_url_index = 0
	refresh_allowed_world_route_urls()
	return true


func clear_world_route_redirect_state(clear_attempts: bool = false) -> void:
	world_route_redirect_pending = false
	world_route_redirect_target_url = ""
	world_route_redirect_world_name = ""
	world_route_redirect_action = ""
	if clear_attempts:
		world_route_redirect_attempts.clear()


func handle_world_route_redirect(data: Dictionary) -> bool:
	var redirect_url := normalize_world_route_ws_url(str(data.get("redirect_ws_url", "")))
	var redirect_world := _safe_world_name(str(data.get("world", current_world_name)))
	var redirect_action := _safe_string(data.get("action", "join_world"), "join_world", MAX_SERVER_MESSAGE_TYPE_LENGTH).to_lower()
	if redirect_url == "" or redirect_world == "":
		return false
	if not has_active_session():
		return false
	if not is_trusted_world_route_redirect_url(redirect_url):
		push_warning("NetworkManager: refused untrusted world route redirect url=" + redirect_url)
		return false

	var current_url := normalize_world_route_ws_url(last_connection_attempt_url)
	if current_url == redirect_url:
		return false

	var attempt_key := redirect_world + "|" + redirect_url
	var attempt_count := int(world_route_redirect_attempts.get(attempt_key, 0))
	if attempt_count >= MAX_WORLD_ROUTE_REDIRECT_ATTEMPTS:
		push_warning("NetworkManager: refused repeated world route redirect world=" + redirect_world + " url=" + redirect_url)
		return false
	world_route_redirect_attempts[attempt_key] = attempt_count + 1

	world_route_redirect_pending = true
	world_route_redirect_target_url = redirect_url
	world_route_redirect_world_name = redirect_world
	world_route_redirect_action = redirect_action
	set_pending_join(redirect_world, session_username)
	current_world_name = redirect_world
	login_notice_message = "Moving to the correct world server..."
	if not push_world_route_url_front(redirect_url):
		clear_world_route_redirect_state(false)
		return false

	print("Routing PixelMania world ", redirect_world, " to ", redirect_url)
	connect_to_server(true)
	reconnect_timer = 0.0
	return true


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
	parts.append("batch_sends=" + str(local_position_batch_sends))
	parts.append("batch_skips=" + str(local_position_batch_skips))
	parts.append("batch_limit=" + str(local_position_batch_limit))
	parts.append("batch_remaining=" + str(local_position_batch_budget))
	if last_close_code != -1:
		parts.append("close_code=" + str(last_close_code))
	if last_close_reason != "":
		parts.append("close_reason=" + last_close_reason)
	return " ".join(parts)


func get_login_notice_message() -> String:
	return login_notice_message


func set_login_notice_message(message: String) -> void:
	login_notice_message = message


func get_client_update_payload() -> Dictionary:
	return client_update_payload.duplicate(true)


func is_client_update_required() -> bool:
	return not client_update_payload.is_empty()


# Compares dotted versions the same way the server does
# (PixelManiaServer/src/server_version_helpers.ts): three numeric parts, a
# leading "v" tolerated, anything after "-" or "+" ignored. Returns
# -1 / 0 / 1, or 0 when either side cannot be parsed so an unreadable version
# never locks a player out on the client side.
func _compare_client_versions(a: String, b: String) -> int:
	var left := _parse_client_version_parts(a)
	var right := _parse_client_version_parts(b)
	if left.is_empty() or right.is_empty():
		return 0
	for index in range(3):
		if left[index] > right[index]:
			return 1
		if left[index] < right[index]:
			return -1
	return 0


func _parse_client_version_parts(value: String) -> Array[int]:
	var parts: Array[int] = []
	var clean := value.strip_edges()
	if clean.begins_with("v") or clean.begins_with("V"):
		clean = clean.substr(1)
	clean = clean.split("-")[0].split("+")[0]
	if clean == "":
		return parts
	for chunk in clean.split("."):
		var digits := ""
		for character in chunk:
			if character < "0" or character > "9":
				break
			digits += character
		parts.append(int(digits) if digits != "" else 0)
		if parts.size() >= 3:
			break
	while parts.size() < 3:
		parts.append(0)
	return parts


# The server advertises the required version on the `connected` packet so the
# gate can appear immediately, rather than only after the first packet is
# rejected. The server still enforces this on every inbound message; this is a
# UX shortcut, never the authority.
func _check_connected_client_version(data: Dictionary) -> void:
	var minimum := str(data.get("min_client_version", "")).strip_edges()
	if minimum == "":
		return
	if _compare_client_versions(CLIENT_VERSION, minimum) >= 0:
		return

	_store_client_update_payload({
		"message": "A new PixelMania update is live. Update your client to version %s or newer to keep playing." % minimum,
		"client_version": CLIENT_VERSION,
		"min_client_version": minimum,
		"server_client_version": str(data.get("server_client_version", "")),
		"update_url": str(data.get("update_url", "")),
	})


func _store_client_update_payload(data: Dictionary) -> void:
	# The server rejects every packet from an out-of-date build, so this arrives
	# repeatedly. Latch the first payload and only act once so the update gate is
	# not rebuilt, and the player is not ejected twice, on each rejected message.
	var already_latched := not client_update_payload.is_empty()
	client_update_payload = {
		"message": str(data.get("message", "Please update PixelMania.")),
		"client_version": str(data.get("client_version", CLIENT_VERSION)),
		"min_client_version": str(data.get("min_client_version", "")),
		"server_client_version": str(data.get("server_client_version", "")),
		"update_url": str(data.get("update_url", "")),
	}
	if already_latched:
		return

	client_update_required.emit(client_update_payload.duplicate(true))

	# An out-of-date build cannot do anything useful in a world, so tear the
	# session down and send the player back to the login screen. Reuses the
	# existing disconnect path so world entry, join and route state are cleared
	# exactly as they are on any other forced sign-out. The saved login is kept
	# so the player can sign straight back in once they have updated.
	if has_active_session() or not _is_login_scene_active():
		_end_authenticated_session(str(client_update_payload.get("message", "")), false, true)


func get_active_session_username() -> String:
	return session_username.strip_edges()


func get_active_session_email() -> String:
	return session_email.strip_edges()


func get_active_account_id() -> String:
	return account_id.strip_edges()


func get_active_profile_id() -> String:
	return profile_id.strip_edges()


func get_active_game_player_id() -> String:
	if game_player_id.strip_edges() != "":
		return game_player_id.strip_edges()
	return player_id.strip_edges()


func get_live_websocket_player_id() -> String:
	return player_id.strip_edges()


func get_active_identity_payload(world_name: String = "") -> Dictionary:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)

	return {
		"websocket_player_id": get_live_websocket_player_id(),
		"game_player_id": get_active_game_player_id(),
		"account_id": get_active_account_id(),
		"profile_id": get_active_profile_id(),
		"username": get_active_session_username(),
		"account_username": get_active_session_username(),
		"world_id": clean_world,
		"world": clean_world,
		"backend_authenticated": is_server_session_authenticated()
	}


func _store_netfox_spawn_route_payload(route_payload) -> void:
	if not (route_payload is Dictionary):
		return

	var clean_world: String = _safe_world_name(route_payload.get("world", route_payload.get("world_id", current_world_name)))
	if clean_world == "":
		return

	var clean_route: Dictionary = route_payload.duplicate(true)
	clean_route["world"] = clean_world
	clean_route["world_id"] = clean_world
	netfox_spawn_routes[clean_world] = clean_route
	if MovementMode.is_netfox_real():
		print("[NetfoxReal] Stored backend spawn route. " + _format_netfox_spawn_route_for_log(clean_route))


func store_netfox_spawn_route_from_message(data: Dictionary) -> void:
	if data.has("netfox_route"):
		_store_netfox_spawn_route_payload(data.get("netfox_route"))
	elif data.has("ticket"):
		_store_netfox_spawn_route_payload(data)


func get_netfox_spawn_route(world_name: String = "") -> Dictionary:
	var clean_world: String = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		return {}

	var route_value: Variant = netfox_spawn_routes.get(clean_world, {})
	if not (route_value is Dictionary):
		return {}

	var route: Dictionary = route_value.duplicate(true)
	if route.is_empty():
		return {}

	if not _is_netfox_spawn_route_fresh(route):
		netfox_spawn_routes.erase(clean_world)
		if MovementMode.is_netfox_real():
			print("[NetfoxReal] Dropped unusable backend spawn route. " + _format_netfox_spawn_route_for_log(route))
		return {}
	return route


func has_netfox_spawn_ticket_for_world(world_name: String = "") -> bool:
	var route: Dictionary = get_netfox_spawn_route(world_name)
	var ticket: String = _safe_string(route.get("ticket", ""), "", 4096)
	return ticket != ""


func send_netfox_spawn_ticket_request(world_name: String = "") -> bool:
	if not is_connected_to_server() or not is_server_session_authenticated():
		if MovementMode.is_netfox_real():
			print("[NetfoxReal] Backend spawn ticket request blocked. connected=%s authenticated=%s active_session=%s world=%s" % [
				str(is_connected_to_server()),
				str(is_server_session_authenticated()),
				str(has_active_session()),
				_safe_world_name(world_name if world_name.strip_edges() != "" else current_world_name)
			])
		return false

	var clean_world: String = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		if MovementMode.is_netfox_real():
			print("[NetfoxReal] Backend spawn ticket request blocked. reason=missing_world")
		return false

	var sent: bool = send_message(attach_session_auth({
		"type": "netfox_spawn_ticket_request",
		"world": clean_world
	}))
	if MovementMode.is_netfox_real():
		print("[NetfoxReal] Backend spawn ticket request sent=%s world=%s" % [str(sent), clean_world])
	return sent


func _is_netfox_spawn_route_fresh(route: Dictionary) -> bool:
	var ticket: String = _safe_string(route.get("ticket", ""), "", 4096)
	if ticket == "":
		return false

	var expires_at_ms: int = int(route.get("ticket_expires_at_ms", 0))
	if expires_at_ms <= 0:
		return true

	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	return expires_at_ms - now_ms > 1000


func _format_netfox_spawn_route_for_log(route: Dictionary) -> String:
	var clean_world: String = _safe_world_name(route.get("world", route.get("world_id", current_world_name)))
	var ticket_present: bool = _safe_string(route.get("ticket", ""), "", 4096) != ""
	return "world=%s host=%s port=%d source=%s reason=%s ticket=%s ticket_expires_at_ms=%d route_expires_at_ms=%d" % [
		clean_world,
		_safe_string(route.get("host", ""), "", 255),
		int(route.get("port", 0)),
		_safe_string(route.get("route_source", ""), "", 64),
		_safe_string(route.get("reason", ""), "", 96),
		str(ticket_present),
		int(route.get("ticket_expires_at_ms", 0)),
		int(route.get("route_expires_at_ms", 0))
	]


func _log_netfox_spawn_ticket_response(data: Dictionary) -> void:
	if not MovementMode.is_netfox_real():
		return

	var route: Dictionary = {}
	var route_value: Variant = data.get("netfox_route", {})
	if route_value is Dictionary:
		route = route_value

	print("[NetfoxReal] Backend spawn ticket response ok=%s world=%s reason=%s message=%s %s" % [
		str(bool(data.get("ok", false))),
		_safe_world_name(data.get("world", current_world_name)),
		_safe_string(data.get("reason", ""), "", 96),
		_safe_string(data.get("message", ""), "", 160),
		_format_netfox_spawn_route_for_log(route) if not route.is_empty() else "route=missing"
	])


func get_active_session_role() -> String:
	return session_role.strip_edges().to_lower()


func get_client_version() -> String:
	return CLIENT_VERSION


func is_developer_session() -> bool:
	return get_active_session_role() == AUTH_ROLE_DEVELOPER or get_active_session_role() == AUTH_ROLE_ADMIN


func is_admin_command_session() -> bool:
	var role = get_active_session_role()
	return role == AUTH_ROLE_DEVELOPER or role == AUTH_ROLE_ADMIN or role == AUTH_ROLE_DESIGNER


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
	pending_saved_refresh_token = ""
	saved_refresh_login_in_flight = false
	if session_authenticated:
		player_name = session_username


func _load_saved_session_for_netfox_real_client_launch() -> void:
	if has_active_session():
		return
	if not MovementMode.has_method("is_netfox_real_client_launch") or not MovementMode.is_netfox_real_client_launch():
		return

	var cfg := ConfigFile.new()
	if cfg.load(profile_path) != OK:
		return

	var username := str(cfg.get_value("profile", "username", "")).strip_edges()
	var email := str(cfg.get_value("profile", "email", "")).strip_edges()
	var remember_login := bool(cfg.get_value("profile", "remember_login", cfg.get_value("profile", "remember_password", false)))
	var token := str(cfg.get_value("profile", "session_token", "")).strip_edges() if remember_login else ""
	var refresh_token := str(cfg.get_value("profile", "refresh_token", "")).strip_edges() if remember_login else ""
	var role := str(cfg.get_value("profile", "role", AUTH_ROLE_PLAYER)).strip_edges().to_lower()

	if username == "" or (token == "" and refresh_token == ""):
		return

	if refresh_token != "":
		session_username = username
		session_email = email
		session_role = role if role != "" else AUTH_ROLE_PLAYER
		player_name = username
		pending_saved_refresh_token = refresh_token
	else:
		set_active_session(username, email, token, role)
	if MovementMode.get_launch_arg_value("--world", "").strip_edges() != "":
		var launch_world := MovementMode.get_dev_test_world_name("NETFOX_TEST")
		set_pending_join(launch_world, username)
		current_world_name = _safe_world_name(launch_world)
	print("[NetfoxReal] Loaded remembered session for launch: username=%s world=%s" % [username, current_world_name])


func clear_runtime_session() -> void:
	account_id = ""
	profile_id = ""
	game_player_id = player_id
	session_username = ""
	session_email = ""
	session_token = ""
	session_role = "player"
	session_authenticated = false
	server_session_authenticated = false
	pending_saved_refresh_token = ""
	saved_refresh_login_in_flight = false
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
	pending_server_world_state.clear()
	pending_world_state_stream.clear()
	active_join_request_id = ""
	active_join_world_name = ""
	active_join_request_pending = false
	_reset_world_entry_session()
	pending_player_state_requests.clear()
	world_population_counts.clear()
	world_population_players.clear()
	world_population_authoritative.clear()
	world_movement_guidance.clear()
	owned_locked_worlds_cache.clear()
	clear_world_route_redirect_state(true)
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
	cfg.load(profile_path)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(profile_path)


func _clear_saved_session_token() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	cfg.set_value("profile", "session_token", "")
	cfg.set_value("profile", "refresh_token", "")
	cfg.set_value("profile", "remember_login", false)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	cfg.save(profile_path)
	pending_saved_refresh_token = ""
	saved_refresh_login_in_flight = false


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
	return str(scene.scene_file_path) == LOGIN_SCENE or scene.name == "LoginScreen" or scene.name == "LoginScene"


func _queue_login_redirect() -> void:
	if _should_suppress_login_redirect_for_custom_movement():
		return
	if login_redirect_pending or _is_login_scene_active():
		return
	login_redirect_pending = true
	call_deferred("_redirect_to_login_scene")


func _redirect_to_login_scene() -> void:
	login_redirect_pending = false
	if _should_suppress_login_redirect_for_custom_movement():
		return
	if _is_login_scene_active():
		return
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _should_suppress_login_redirect_for_custom_movement() -> bool:
	if MovementMode == null:
		return false
	if not MovementMode.has_method("is_custom_movement_launch_requested"):
		return false
	if not bool(MovementMode.is_custom_movement_launch_requested()):
		return false
	return MovementMode.is_backend_dev_login_requested() or MovementMode.has_launch_arg("--client") or MovementMode.has_launch_arg("--server")


func make_auth_request_id() -> String:
	auth_request_counter += 1
	return str(Time.get_ticks_msec()) + "_" + str(auth_request_counter)


func make_action_request_id(action_type: String) -> String:
	var clean_action: String = _safe_string(action_type, "action", 32).to_lower()
	if clean_action == "":
		clean_action = "action"
	return _safe_string(clean_action + "_" + make_auth_request_id(), "", MAX_REQUEST_ID_LENGTH)


func attach_action_request_identity(payload: Dictionary, action_type: String) -> void:
	var request_id: String = _safe_string(payload.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if request_id == "":
		request_id = _safe_string(payload.get("action_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if request_id == "":
		request_id = make_action_request_id(action_type)
	payload["request_id"] = request_id
	payload["action_id"] = request_id


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
	if not (data is Dictionary):
		return false

	var outgoing = data.duplicate(true)
	outgoing["client_version"] = CLIENT_VERSION
	outgoing["client_platform"] = CLIENT_PLATFORM
	if MovementMode.is_netfox_real() or MovementMode.is_custom_authoritative():
		outgoing["movement_mode"] = MovementMode.get_mode_name()
	_strip_session_token_from_non_auth_payload(outgoing)
	var payload_text = JSON.stringify(outgoing)
	if payload_text.to_utf8_buffer().size() > MAX_CLIENT_MESSAGE_BYTES:
		push_warning("NetworkManager: refused oversized client packet type=" + str(outgoing.get("type", "")))
		return false
	var send_error = socket.send_text(payload_text)
	return send_error == OK


func _strip_session_token_from_non_auth_payload(outgoing: Dictionary) -> void:
	if not (outgoing is Dictionary):
		return
	var message_type := _safe_string(outgoing.get("type", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH).to_lower()
	if message_type == "":
		return
	if _should_send_session_token_for_message(message_type):
		return
	outgoing.erase("session_token")


func _should_send_session_token_for_message(message_type: String) -> bool:
	var normalized := message_type.strip_edges().to_lower()
	if normalized == "":
		return false
	if bool(ProjectSettings.get_setting(NETWORK_SEND_SESSION_TOKEN_EVERY_MESSAGE_SETTING, false)):
		return true
	return AUTH_TOKEN_MESSAGE_TYPES.has(normalized)


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


func send_account_refresh_token_login(username: String, refresh_token: String) -> String:
	if not is_connected_to_server():
		return ""
	var clean_token := refresh_token.strip_edges()
	if clean_token == "":
		return ""
	var request_id := make_auth_request_id()
	if not send_message({
		"type": "account_token_login",
		"request_id": request_id,
		"username": username.strip_edges(),
		"refresh_token": clean_token
	}):
		return ""
	saved_refresh_login_in_flight = true
	return request_id


func send_account_password_reset_request(username: String, email: String) -> String:
	if not is_connected_to_server():
		return ""
	var request_id = make_auth_request_id()
	send_message({
		"type": "account_password_reset_request",
		"request_id": request_id,
		"username": username.strip_edges(),
		"email": email.strip_edges()
	})
	return request_id


func send_account_email_change_request(username: String, new_email: String, password: String) -> String:
	if not is_connected_to_server():
		return ""
	var request_id = make_auth_request_id()
	send_message({
		"type": "account_email_change_request",
		"request_id": request_id,
		"username": username.strip_edges(),
		"email": new_email.strip_edges(),
		"password": password
	})
	return request_id


func send_backend_dev_login(username: String, world_name: String = "NETFOX_TEST") -> String:
	if not is_connected_to_server():
		return ""
	if not MovementMode.is_backend_dev_login_active():
		return ""

	var clean_username := username.strip_edges()
	if clean_username == "":
		return ""

	var request_id = make_auth_request_id()
	send_message({
		"type": "dev_backend_login",
		"request_id": request_id,
		"username": clean_username,
		"world": _safe_world_name(world_name),
		"movement_mode": MovementMode.get_mode_name(),
		"dev_login": true
	})
	return request_id


func _should_send_backend_dev_login_on_socket_open() -> bool:
	if MovementMode == null:
		return false
	if not MovementMode.has_method("is_backend_dev_login_active") or not MovementMode.is_backend_dev_login_active():
		return false
	var trusted_client_launch := false
	if MovementMode.has_method("is_netfox_real_client_launch") and MovementMode.is_netfox_real_client_launch():
		trusted_client_launch = true
	if MovementMode.has_method("is_custom_movement_client_launch") and MovementMode.is_custom_movement_client_launch():
		trusted_client_launch = true
	if not trusted_client_launch:
		return false
	return MovementMode.is_custom_authoritative() or MovementMode.is_netfox_real()


func _send_backend_dev_login_from_launch_args() -> void:
	var default_world := "TEST" if MovementMode.is_custom_authoritative() else "NETFOX_TEST"
	var default_profile := "uso" if MovementMode.is_custom_authoritative() else "DevNetfox"
	var world_name := MovementMode.get_dev_test_world_name(default_world)
	var profile_name := MovementMode.get_dev_profile_name(default_profile)
	if profile_name.strip_edges() == "":
		return
	if has_method("set_pending_join"):
		set_pending_join(world_name, profile_name)
	current_world_name = _safe_world_name(world_name)
	var request_id := send_backend_dev_login(profile_name, world_name)
	if request_id != "":
		print("[BackendDevLogin] Sent launch dev login request profile=%s world=%s request_id=%s mode=%s" % [
			profile_name,
			world_name,
			request_id,
			MovementMode.get_mode_name(),
		])


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
	if context.has("window_hours"):
		payload["window_hours"] = int(context.get("window_hours", 0))
	if context.has("item_instance_id"):
		payload["item_instance_id"] = str(context.get("item_instance_id", "")).strip_edges()
	if context.has("public_item_instance_id"):
		payload["public_item_instance_id"] = str(context.get("public_item_instance_id", "")).strip_edges()
	if context.has("item_type"):
		payload["item_type"] = str(context.get("item_type", "")).strip_edges()
	if context.has("item_id"):
		payload["item_id"] = str(context.get("item_id", "")).strip_edges()
	if context.has("transaction_type"):
		payload["transaction_type"] = str(context.get("transaction_type", "")).strip_edges()
	if context.has("ledger_type"):
		payload["ledger_type"] = str(context.get("ledger_type", "")).strip_edges()
	if context.has("status"):
		payload["status"] = str(context.get("status", "")).strip_edges()
	if context.has("target_username"):
		payload["target_username"] = str(context.get("target_username", "")).strip_edges()
	if context.has("world"):
		payload["world"] = str(context.get("world", "")).strip_edges()
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


func send_player_profile_update(profile_bio: String, context: Dictionary = {}) -> String:
	if not is_server_session_authenticated():
		return ""
	if not _can_send_rate_limited("player_profile_update", MAX_PLAYER_PROFILE_RATE_PER_SECOND):
		return ""

	var clean_bio := profile_bio.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if clean_bio.length() > 160:
		clean_bio = clean_bio.left(160)
	var request_id := make_auth_request_id()
	var request_started_ms := Time.get_ticks_msec()
	var request_context := context.duplicate(true)
	request_context["purpose"] = "local_player_profile"
	request_context["username"] = session_username
	request_context["requested_username"] = session_username

	var request_sent := send_message(attach_session_auth({
		"type": "player_profile_update",
		"request_id": request_id,
		"username": session_username,
		"profile_bio": clean_bio
	}))
	if not request_sent:
		return ""

	pending_player_state_requests[request_id] = {
		"username": session_username,
		"requested_username": session_username,
		"purpose": "local_player_profile",
		"context": request_context,
		"created_at_ms": request_started_ms,
		"timeout_ms": request_started_ms + PLAYER_STATE_REQUEST_TIMEOUT_MS
	}
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


func send_inventory_upgrade_purchase_request(upgrade_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("inventory_upgrade_purchase", MAX_INVENTORY_UPGRADE_RATE_PER_SECOND):
		return false
	var payload := {
		"type": "inventory_upgrade_purchase",
		"request_id": make_auth_request_id(),
		"world": current_world_name
	}
	if upgrade_data is Dictionary:
		payload["expected_current_slots"] = int(upgrade_data.get("current_slots", upgrade_data.get("inventory_slot_count", 0)))
		payload["expected_next_slots"] = int(upgrade_data.get("next_slots", upgrade_data.get("next_inventory_slot_count", 0)))
		payload["expected_cost"] = int(upgrade_data.get("cost", upgrade_data.get("inventory_upgrade_cost", 0)))
	return send_message(attach_session_auth(payload))


func send_iap_create_stripe_checkout_request(pack_id: String) -> String:
	if not is_server_session_authenticated():
		return ""
	var request_id = make_auth_request_id()
	send_message(attach_session_auth({
		"type": "iap_create_stripe_checkout_request",
		"request_id": request_id,
		"pack_id": pack_id
	}))
	return request_id


func send_iap_submit_google_play_purchase_request(pack_id: String, purchase_token: String, product_id: String) -> String:
	if not is_server_session_authenticated():
		return ""
	var request_id = make_auth_request_id()
	send_message(attach_session_auth({
		"type": "iap_submit_google_play_purchase_request",
		"request_id": request_id,
		"pack_id": pack_id,
		"purchase_token": purchase_token,
		"product_id": product_id
	}))
	return request_id


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
	if active_join_world_name != clean_world:
		pending_server_world_state.clear()
		pending_world_state_stream.clear()
		active_join_request_id = ""
		active_join_world_name = ""
		active_join_request_pending = false
		_reset_world_entry_session()
	pending_join_enabled = true
	pending_join_world_name = clean_world
	pending_join_profile_name = profile_name.strip_edges()


func clear_completed_pending_join_for_world(world_name: String) -> void:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		return
	if pending_join_world_name != "" and pending_join_world_name != clean_world:
		return
	pending_join_enabled = false
	pending_join_world_name = ""
	pending_join_profile_name = ""


func persist_completed_world_join(world_name: String, _profile_name: String = "") -> void:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		return

	clear_completed_pending_join_for_world(clean_world)

	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	var old_recent = cfg.get_value("profile", "recent_worlds", [])
	var recent_worlds: Array = [clean_world]
	if old_recent is Array:
		for old_world_value in old_recent:
			var old_world := _safe_world_name(str(old_world_value))
			if old_world != "" and old_world != clean_world:
				recent_worlds.append(old_world)
			if recent_worlds.size() >= 8:
				break
	cfg.set_value("profile", "recent_worlds", recent_worlds)
	cfg.set_value("profile", "last_world", clean_world)
	cfg.set_value("pending_join", "enabled", false)
	cfg.set_value("pending_join", "world_name", "")
	cfg.set_value("pending_join", "profile_name", "")
	var save_error := cfg.save(profile_path)
	if save_error != OK:
		push_warning("Could not persist completed world join: " + error_string(save_error))


func has_pending_join() -> bool:
	return pending_join_enabled and pending_join_world_name.strip_edges() != ""


func get_world_player_count(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0
	return int(world_population_counts.get(clean_world, 0))


func get_world_other_player_count(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0

	var known_players = world_population_players.get(clean_world, {})
	if known_players is Dictionary and not known_players.is_empty():
		return known_players.size()

	var count = int(world_population_counts.get(clean_world, 0))
	if bool(world_population_authoritative.get(clean_world, false)) and clean_world == _safe_world_name(current_world_name):
		count -= 1
	return max(0, count)


func apply_server_movement_guidance(world_name: String, raw_guidance: Variant) -> void:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return

	if not (raw_guidance is Dictionary):
		world_movement_guidance.erase(clean_world)
		return

	var heartbeat_ms := _safe_int(raw_guidance.get("position_heartbeat_interval_ms", 0), 0, 1, 120000)
	var broadcast_ms := _safe_int(raw_guidance.get("position_broadcast_interval_ms", 0), 0, 0, 120000)
	var batch_items := _safe_int(raw_guidance.get("position_batch_max_items", 0), 0, 1, 4096)

	if heartbeat_ms <= 0:
		world_movement_guidance.erase(clean_world)
		return

	world_movement_guidance[clean_world] = {
		"position_heartbeat_interval_ms": heartbeat_ms,
		"position_broadcast_interval_ms": broadcast_ms,
		"position_batch_max_items": batch_items,
		"source": _safe_string(raw_guidance.get("source", ""), "", 64),
		"source_version": _safe_int(raw_guidance.get("source_version", 0), 0, 1, 64),
		"world_population_for_batching": _safe_int(raw_guidance.get("world_population_for_batching", 0), 0, 0, 1000000),
	}


func get_server_guided_position_heartbeat_ms(world_name: String) -> float:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0.0

	var guidance = world_movement_guidance.get(clean_world, {})
	if not (guidance is Dictionary):
		return 0.0

	return float(_safe_int(guidance.get("position_heartbeat_interval_ms", 0), 0, 0, 120000))


func get_server_guided_position_broadcast_ms(world_name: String) -> float:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0.0

	var guidance = world_movement_guidance.get(clean_world, {})
	if not (guidance is Dictionary):
		return 0.0

	return float(_safe_int(guidance.get("position_broadcast_interval_ms", 0), 0, 0, 120000))


func get_server_guided_position_batch_max_items(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0

	var guidance = world_movement_guidance.get(clean_world, {})
	if not (guidance is Dictionary):
		return 0

	return int(_safe_int(guidance.get("position_batch_max_items", 0), 0, 1, 4096))


func get_server_guided_world_population_for_batching(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		return 0

	var guidance = world_movement_guidance.get(clean_world, {})
	if not (guidance is Dictionary):
		return 0

	return int(_safe_int(guidance.get("world_population_for_batching", 0), 0, 0, 1000000))


func _get_world_population_for_batching(world_name: String) -> int:
	var guided_population = get_server_guided_world_population_for_batching(world_name)
	if guided_population > 0:
		return guided_population

	return get_world_player_count(world_name)


func _get_batch_density_scale(world_population: int) -> float:
	if world_population <= 12:
		return 1.0
	if world_population <= 24:
		return 0.85
	if world_population <= 48:
		return 0.7
	if world_population <= 72:
		return 0.55
	return 0.4


func _get_local_position_batch_limit(world_name: String) -> int:
	var clean_world = _safe_world_name(world_name)
	var guidance_batch_items = get_server_guided_position_batch_max_items(clean_world)
	if guidance_batch_items <= 0:
		guidance_batch_items = 1

	var base_limit = max(1, int(ceil(LOCAL_POSITION_BATCH_BURST_SCALE / float(guidance_batch_items))))
	var batch_population = _get_world_population_for_batching(clean_world)
	var density_scale = _get_batch_density_scale(batch_population)

	return max(1, int(ceil(float(base_limit) * density_scale)))


func _consume_local_position_batch_slot(world_name: String) -> bool:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"

	var now_msec = Time.get_ticks_msec()
	if local_position_batch_world != clean_world or local_position_batch_window_msec <= 0 or now_msec >= local_position_batch_window_msec:
		local_position_batch_world = clean_world
		local_position_batch_limit = _get_local_position_batch_limit(clean_world)
		local_position_batch_budget = local_position_batch_limit
		local_position_batch_window_msec = now_msec + LOCAL_POSITION_BATCH_BUDGET_WINDOW_MS

	if local_position_batch_budget > 0:
		local_position_batch_budget -= 1
		return true

	return false


func get_server_guided_player_position_rate_per_second(world_name: String, fallback_rate_per_second: int = MAX_PLAYER_POSITION_RATE_PER_SECOND) -> int:
	var broadcast_ms = get_server_guided_position_broadcast_ms(world_name)
	if broadcast_ms <= 0.0:
		return max(1, fallback_rate_per_second)

	var derived_rate = int(ceil(1000.0 / max(1.0, broadcast_ms)))
	return clamp(derived_rate, 1, max(1, fallback_rate_per_second))


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


func request_owned_locked_worlds(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("owned_locked_worlds", MAX_OWNED_LOCKED_WORLDS_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "owned_locked_worlds_request",
		"request_id": safe_request_id
	}))


# ---------------------------------------------------------------------------
# Landfill seasonal event: lobby-driven status polling, join, leaderboard, and
# prize claim requests. These mirror request_owned_locked_worlds's shape
# exactly (auth check -> rate limit check -> request_id sanitize/generate ->
# attach_session_auth send) since, like that request, they are issued from
# the lobby before a world node exists -- they must NOT depend on
# is_world_node_active() or any in-world delegation pattern.
# ---------------------------------------------------------------------------

func request_landfill_status(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("landfill_status", MAX_LANDFILL_STATUS_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "landfill_status_request",
		"request_id": safe_request_id
	}))


func request_landfill_join(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("landfill_join", MAX_LANDFILL_ACTION_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "landfill_join_request",
		"request_id": safe_request_id
	}))


# Asks the server to push the current race state for the world we are in. Used once on world
# entry so the HUD populates immediately instead of waiting for the next coalesced broadcast.
# Carries no state of its own -- it is a request, not a report.
func request_landfill_race_state(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("landfill_race_state", MAX_LANDFILL_STATUS_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "landfill_race_state_request",
		"request_id": safe_request_id
	}))


func request_landfill_leaderboard(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("landfill_leaderboard", MAX_LANDFILL_LEADERBOARD_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "landfill_leaderboard_request",
		"request_id": safe_request_id
	}))


func request_landfill_claim_prize(request_id: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("landfill_claim_prize", MAX_LANDFILL_ACTION_RATE_PER_SECOND):
		return false

	var safe_request_id = _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	if safe_request_id == "":
		safe_request_id = make_auth_request_id()

	return send_message(attach_session_auth({
		"type": "landfill_claim_prize_request",
		"request_id": safe_request_id
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
	var join_request_id: String = make_action_request_id("join_world")
	pending_server_world_state.clear()
	pending_world_state_stream.clear()
	_reset_world_entry_session()
	active_join_request_id = join_request_id
	active_join_world_name = clean_world
	active_join_request_pending = true
	current_world_name = clean_world
	begin_world_entry_profile(clean_world, join_request_id)
	var world_node: Node = get_world_node() as Node
	if world_node != null and world_node.has_method("update_smooth_world_load_message"):
		world_node.update_smooth_world_load_message("Finding world...")
	movement_sequence = 0
	_clear_local_position_payload_queue()
	last_accepted_position_sequence = 0
	last_rejected_position_sequence = 0
	debug_action_position_flow("send_join_world", {
		"world": current_world_name,
		"join_request_id": join_request_id
	})
	var sent: bool = send_message(attach_session_auth({
		"type": "join_world",
		"world": current_world_name,
		"request_id": join_request_id,
		"join_request_id": join_request_id,
		"world_entry_ready_v1": true
	}))
	if not sent:
		cancel_world_entry_profile("join_request_send_failed")
		active_join_request_id = ""
		active_join_world_name = ""
		active_join_request_pending = false
		_reset_world_entry_session()
	return sent


func has_active_join_request_for_world(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name)
	return (
		active_join_request_pending
		and clean_world != ""
		and active_join_request_id != ""
		and active_join_world_name == clean_world
	)


func has_join_lifecycle_for_world(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "" or active_join_request_id == "" or active_join_world_name != clean_world:
		return false
	return (
		active_join_request_pending
		or world_entry_requires_ready
		or world_entry_active
		or not pending_server_world_state.is_empty()
		or not pending_world_state_stream.is_empty()
	)


func has_incomplete_join_lifecycle_for_world(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "" or active_join_request_id == "" or active_join_world_name != clean_world:
		return false
	return (
		active_join_request_pending
		or (world_entry_requires_ready and not world_entry_active)
		or not pending_server_world_state.is_empty()
		or not pending_world_state_stream.is_empty()
	)


func send_join_world_if_needed(world_name: String) -> bool:
	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"
	if has_incomplete_join_lifecycle_for_world(clean_world):
		return true
	return send_join_world(clean_world)


func mark_active_join_request_complete() -> void:
	active_join_request_pending = false


func cancel_active_join_request() -> void:
	pending_server_world_state.clear()
	pending_world_state_stream.clear()
	_reset_world_entry_session()
	cancel_world_entry_profile("join_request_canceled")
	# Keep a non-empty tombstone so late responses from the canceled attempt are
	# rejected instead of being treated as legacy responses with no active join.
	active_join_request_id = make_action_request_id("cancel_join")
	active_join_world_name = ""
	active_join_request_pending = false


func _invalidate_active_join_request_for_transport_change(reason: String = "transport_change") -> void:
	if not active_join_request_pending:
		return
	debug_action_position_flow("invalidate active join for transport change", {
		"reason": reason,
		"world": active_join_world_name,
		"join_request_id": active_join_request_id
	})
	# The pending target remains intact, but this request belongs to the socket
	# being replaced and must not suppress a fresh join after authentication.
	cancel_active_join_request()


func play_local_join_world_sound(world_node = null) -> void:
	if world_node == null:
		world_node = get_world_node()
	if world_node == null or not world_node.has_method("play_sound_join_world"):
		return

	var source_position: Vector2 = Vector2(INF, INF)
	var player_node = world_node.get("player")
	if player_node is Node2D and is_instance_valid(player_node):
		source_position = player_node.global_position
	world_node.play_sound_join_world(source_position)


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
	if is_anti_talk_blocking_local_chat(clean_message):
		return false
	sync_player_name_from_world()
	return send_message(attach_session_auth({
		"type": "chat",
		"message": clean_message
	}))


func is_anti_talk_blocking_local_chat(message: String) -> bool:
	if message.strip_edges().to_lower().begins_with("/bc "):
		return false
	var world_node = get_world_node()
	if world_node == null:
		return false
	if not world_node.has_method("is_anti_talk_enabled") or not bool(world_node.is_anti_talk_enabled()):
		return false
	if world_node.has_method("can_current_player_bypass_anti_talk") and bool(world_node.can_current_player_bypass_anti_talk()):
		return false
	return true


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
	var payload := {
		"type": "pull_player_request",
		"request_id": make_auth_request_id(),
		"target_username": clean_username,
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_world_block_update(action: String, layer: String, grid_pos: Vector2i, block_type: String, world_name: String, extra_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		trace_world_block_event("send_blocked", {
			"reason": "not_authenticated",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"world": world_name,
			"request_id": str(extra_data.get("request_id", ""))
		})
		debug_netfox_identity("block action rejected before send", {
			"reason": "not_authenticated",
			"action": action,
			"layer": layer,
			"target_tile": grid_pos,
			"block_type": block_type,
			"world": world_name
		})
		return false
	if not _can_send_rate_limited("world_block_update", MAX_WORLD_BLOCK_RATE_PER_SECOND):
		trace_world_block_event("send_blocked", {
			"reason": "client_rate_limited",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"world": world_name,
			"request_id": str(extra_data.get("request_id", "")),
			"rate_per_second": MAX_WORLD_BLOCK_RATE_PER_SECOND
		})
		debug_netfox_identity("block action rejected before send", {
			"reason": "rate_limited",
			"action": action,
			"layer": layer,
			"target_tile": grid_pos,
			"block_type": block_type,
			"world": world_name
		})
		return false
	var clean_action = _safe_string(action, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_BLOCK_ACTIONS.has(clean_action):
		trace_world_block_event("send_blocked", {
			"reason": "invalid_action",
			"action": action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"world": world_name,
			"request_id": str(extra_data.get("request_id", ""))
		})
		return false
	var clean_layer = _safe_string(layer, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not WORLD_BLOCK_LAYERS.has(clean_layer):
		trace_world_block_event("send_blocked", {
			"reason": "invalid_layer",
			"action": clean_action,
			"layer": layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"world": world_name,
			"request_id": str(extra_data.get("request_id", ""))
		})
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		trace_world_block_event("send_blocked", {
			"reason": "missing_world",
			"action": clean_action,
			"layer": clean_layer,
			"grid_pos": grid_pos,
			"block_type": block_type,
			"request_id": str(extra_data.get("request_id", ""))
		})
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
	if extra_data.has("request_id"):
		payload["request_id"] = _safe_string(extra_data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if extra_data.has("action_id"):
		payload["action_id"] = _safe_string(extra_data.get("action_id", ""), "", MAX_REQUEST_ID_LENGTH)
	attach_action_request_identity(payload, "world_block_" + clean_action)
	# Keep block updates keyed by string block_type. Some deployed servers do not ship
	# Data/items/atlas_items.json, so sending atlas item_id can make valid blocks
	# look invalid server-side. The server can still compute/echo item_id when its
	# atlas database is available, but block_type is the authoritative identifier.
	if extra_data.has("hit_power"):
		payload["hit_power"] = _safe_int(extra_data.get("hit_power", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if extra_data.has("hit_count"):
		payload["hit_count"] = _safe_int(extra_data.get("hit_count", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if extra_data.has("max_hits"):
		payload["max_hits"] = _safe_int(extra_data.get("max_hits", 0), 0, 0, MAX_BLOCK_HIT_METRIC)
	if extra_data.has("damage_reset_ms"):
		payload["damage_reset_ms"] = _safe_int(extra_data.get("damage_reset_ms", 0), 0, 0, 30000)
	if extra_data.has("source_tool"):
		payload["source_tool"] = _safe_string(extra_data.get("source_tool", ""), "", MAX_ITEM_ID_LENGTH)
	if extra_data.has("water_bucket_action"):
		var water_bucket_action := _safe_string(extra_data.get("water_bucket_action", ""), "", 16).to_lower()
		if water_bucket_action == "pour" or water_bucket_action == "scoop":
			payload["water_bucket_action"] = water_bucket_action
	flush_world_position_for_payload(payload)
	debug_netfox_identity("block action send", {
		"action": clean_action,
		"layer": clean_layer,
		"target_tile": grid_pos,
		"block_type": payload.get("block_type", ""),
		"world": clean_world,
		"inventory_owner_id": get_active_game_player_id(),
		"allow_reject_reason": "sent_to_backend"
	})
	trace_world_block_event("send_payload", payload)
	var sent := send_message(attach_session_auth(payload))
	trace_world_block_event("send_result", {
		"sent": sent,
		"action": clean_action,
		"layer": clean_layer,
		"grid_pos": grid_pos,
		"block_type": payload.get("block_type", ""),
		"world": clean_world,
		"request_id": str(payload.get("request_id", ""))
	})
	return sent


func send_world_block_reconcile_request(request_id: String, block_action: String, layer: String, grid_pos: Vector2i, block_type: String, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_block_reconcile_request", MAX_WORLD_BLOCK_RECONCILE_RATE_PER_SECOND):
		return false

	var clean_request_id := _safe_string(request_id, "", MAX_REQUEST_ID_LENGTH)
	var clean_action := _safe_string(block_action, "place", MAX_ITEM_ID_LENGTH).to_lower()
	var clean_layer := _safe_string(layer, "foreground", MAX_ITEM_ID_LENGTH).to_lower()
	var clean_world := _safe_world_name(world_name)
	if clean_request_id == "":
		return false
	if not WORLD_BLOCK_ACTIONS.has(clean_action):
		return false
	if not WORLD_BLOCK_LAYERS.has(clean_layer):
		return false
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		return false

	var payload := {
		"type": "world_block_reconcile_request",
		"request_id": clean_request_id,
		"action_id": clean_request_id,
		"block_action": clean_action,
		"layer": clean_layer,
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE),
		"requested_block_type": _safe_string(block_type, "", MAX_ITEM_ID_LENGTH),
		"world": clean_world
	}
	return send_message(attach_session_auth(payload))


func send_electrical_layer_update(action: String, grid_pos: Vector2i, item_id: String, world_name: String, extra_data: Dictionary = {}) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("electrical_layer_update", MAX_WORLD_ELECTRICAL_RATE_PER_SECOND):
		return false
	var clean_action = _safe_string(action, "", MAX_ITEM_ID_LENGTH).to_lower()
	if clean_action != "place" and clean_action != "break" and clean_action != "remove":
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "electrical_layer_update",
		"action": clean_action,
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE),
		"block_type": _safe_string(item_id, "", MAX_ITEM_ID_LENGTH),
		"item_id": _safe_string(item_id, "", MAX_ITEM_ID_LENGTH),
		"world": clean_world
	}
	if extra_data.has("device_type"):
		payload["device_type"] = _safe_string(extra_data.get("device_type", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	if extra_data.has("signal_mode"):
		payload["signal_mode"] = _safe_string(extra_data.get("signal_mode", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_request_open_generator(grid_pos: Vector2i, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("request_open_generator", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "request_open_generator",
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_request_link_generator_pad(generator_grid: Vector2i, pad_grid: Vector2i, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("request_link_generator_pad", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "request_link_generator_pad",
		"generator_x": clamp(generator_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"generator_y": clamp(generator_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"pad_x": clamp(pad_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"pad_y": clamp(pad_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_request_link_generator_pole(generator_grid: Vector2i, pole_grid: Vector2i, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("request_link_generator_pole", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "request_link_generator_pole",
		"generator_x": clamp(generator_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"generator_y": clamp(generator_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"pole_x": clamp(pole_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"pole_y": clamp(pole_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_request_link_electric_poles(pole_a_grid: Vector2i, pole_b_grid: Vector2i, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("request_link_electric_poles", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "request_link_electric_poles",
		"pole_a_x": clamp(pole_a_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"pole_a_y": clamp(pole_a_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"pole_b_x": clamp(pole_b_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"pole_b_y": clamp(pole_b_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_request_wire_visibility_refresh(world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("request_wire_visibility_refresh", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var equipment_slots = get_equipment_slots()
	var payload = {
		"type": "request_wire_visibility_refresh",
		"world": clean_world,
		"equipment_slots": equipment_slots,
		"equipped_tool": str(equipment_slots.get("hand", ""))
	}
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_oil_refinery_request(refinery_grid: Vector2i, operation: String, extra_data: Dictionary = {}, world_name: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("oil_refinery_request", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_operation = _safe_string(operation, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not ["open", "toggle", "link_pole", "collect", "add_battery"].has(clean_operation):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "oil_refinery_request",
		"operation": clean_operation,
		"request_operation": clean_operation,
		"command": clean_operation,
		"action": clean_operation,
		"x": clamp(refinery_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(refinery_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	if extra_data.has("enabled"):
		payload["enabled"] = _safe_bool(extra_data.get("enabled", false), false)
	if extra_data.has("amount"):
		payload["amount"] = _safe_int(extra_data.get("amount", 0), 0, 0, MAX_ITEM_STACK_SIZE)
	if extra_data.has("pole_x") or extra_data.has("pole_y"):
		payload["pole_x"] = _safe_int(extra_data.get("pole_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["pole_y"] = _safe_int(extra_data.get("pole_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_battery_charger_request(charger_grid: Vector2i, operation: String, extra_data: Dictionary = {}, world_name: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("battery_charger_request", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_operation = _safe_string(operation, "", MAX_ITEM_ID_LENGTH).to_lower()
	if not ["open", "toggle", "link_pole", "collect"].has(clean_operation):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = current_world_name
	if clean_world == "":
		return false
	var payload = {
		"type": "battery_charger_request",
		"operation": clean_operation,
		"x": clamp(charger_grid.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(charger_grid.y, -MAX_COORDINATE, MAX_COORDINATE),
		"world": clean_world
	}
	if extra_data.has("enabled"):
		payload["enabled"] = _safe_bool(extra_data.get("enabled", false), false)
	if extra_data.has("running"):
		payload["enabled"] = _safe_bool(extra_data.get("running", false), false)
	if extra_data.has("pole_x") or extra_data.has("pole_y"):
		payload["pole_x"] = _safe_int(extra_data.get("pole_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["pole_y"] = _safe_int(extra_data.get("pole_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
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
		"door_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["door_id"] = _safe_string(payload.get("door_id", ""), "", MAX_DOOR_ID_LENGTH)
			payload["door_name"] = _safe_string(payload.get("door_name", payload.get("name", "")), "", MAX_DOOR_NAME_LENGTH)
			payload["name"] = payload["door_name"]
			payload["destination"] = _safe_string(payload.get("destination", payload.get("door_destination", "")), "", MAX_DOOR_DESTINATION_LENGTH)
			payload["locked"] = _safe_bool(payload.get("locked", false), false)
			payload["password_changed"] = _safe_bool(payload.get("password_changed", false), false)
			if bool(payload.get("password_changed", false)):
				payload["password"] = _safe_string(payload.get("password", ""), "", MAX_DOOR_PASSWORD_LENGTH)
			else:
				payload.erase("password")
		"ceiling_lamp_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["on"] = _safe_bool(payload.get("on", false), false)
		"sign_text":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["text"] = _safe_string(payload.get("text", ""), "", MAX_WORLD_INTERACTION_TEXT_LENGTH)
		"world_lock_state", "area_lock_state":
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
			payload["requested_by"] = _safe_string(payload.get("requested_by", ""), "", MAX_USERNAME_LENGTH)
			payload["owner_verified"] = _safe_bool(payload.get("owner_verified", false), false)
			payload["strict_mode"] = _safe_bool(payload.get("strict_mode", false), false)
		"vend_state", "safe_state", "display_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"mailbox_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
			payload["message"] = _safe_string(payload.get("message", ""), "", MAX_WORLD_INTERACTION_TEXT_LENGTH)
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"bulletin_board_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
			payload["message"] = _safe_string(payload.get("message", ""), "", MAX_WORLD_INTERACTION_TEXT_LENGTH)
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"tackle_box_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", "harvest"), "harvest", MAX_ITEM_ID_LENGTH).to_lower()
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"chicken_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", "harvest"), "harvest", MAX_ITEM_ID_LENGTH).to_lower()
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"cow_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", "harvest"), "harvest", MAX_ITEM_ID_LENGTH).to_lower()
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"duck_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["operation"] = _safe_string(payload.get("operation", "harvest"), "harvest", MAX_ITEM_ID_LENGTH).to_lower()
			if payload.get("state") is Dictionary:
				payload["state"] = payload["state"].duplicate(true)
			else:
				payload["state"] = {}
		"dice_roll":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		"checkpoint_activate":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		"theme_machine_state":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["enabled"] = _safe_bool(payload.get("enabled", false), false)
			payload["theme"] = _safe_string(payload.get("theme", "night"), "night", MAX_ITEM_ID_LENGTH).to_lower()
		"entrance_gate_move":
			payload["old_x"] = _safe_int(payload.get("old_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["old_y"] = _safe_int(payload.get("old_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		"world_lock_move":
			payload["old_x"] = _safe_int(payload.get("old_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["old_y"] = _safe_int(payload.get("old_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		"door_move":
			payload["old_x"] = _safe_int(payload.get("old_x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["old_y"] = _safe_int(payload.get("old_y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		"entrance_pass":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["walk_direction"] = -1 if _safe_int(payload.get("walk_direction", 1), 1, -1, 1) < 0 else 1
		"springboard_animation":
			payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
			payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_springboard_animation(grid_pos: Vector2i, world_name: String = "") -> bool:
	return send_world_interaction_update({
		"action": "springboard_animation",
		"x": grid_pos.x,
		"y": grid_pos.y
	}, world_name if world_name.strip_edges() != "" else current_world_name)

func send_entrance_pass(grid_pos: Vector2i, walk_direction: int = 1, world_name: String = "") -> bool:
	return send_world_interaction_update({
		"action": "entrance_pass",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"walk_direction": walk_direction
	}, world_name if world_name.strip_edges() != "" else current_world_name)


func send_door_state(grid_pos: Vector2i, door_id: String, destination: String, locked: bool, world_name: String = "", password: String = "", password_changed: bool = false, door_name: String = "") -> bool:
	var payload := {
		"action": "door_state",
		"x": grid_pos.x,
		"y": grid_pos.y,
		"door_id": door_id,
		"door_name": door_name,
		"name": door_name,
		"destination": destination,
		"locked": locked
	}
	if password_changed:
		payload["password_changed"] = true
		payload["password"] = _safe_string(password, "", MAX_DOOR_PASSWORD_LENGTH)
	return send_world_interaction_update(payload, world_name if world_name.strip_edges() != "" else current_world_name)


func send_door_move(old_grid_pos: Vector2i, new_grid_pos: Vector2i, world_name: String = "") -> bool:
	return send_world_interaction_update({
		"action": "door_move",
		"old_x": old_grid_pos.x,
		"old_y": old_grid_pos.y,
		"x": new_grid_pos.x,
		"y": new_grid_pos.y
	}, world_name if world_name.strip_edges() != "" else current_world_name)


func send_door_enter(grid_pos: Vector2i, world_name: String = "", password: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("door_enter", MAX_WORLD_INTERACTION_RATE_PER_SECOND):
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		return false
	var payload = {
		"type": "door_enter",
		"request_id": make_auth_request_id(),
		"world": clean_world,
		"x": clamp(grid_pos.x, -MAX_COORDINATE, MAX_COORDINATE),
		"y": clamp(grid_pos.y, -MAX_COORDINATE, MAX_COORDINATE)
	}
	if str(password).strip_edges() != "":
		payload["password"] = _safe_string(password, "", MAX_DOOR_PASSWORD_LENGTH)
	flush_world_position_for_payload(payload)
	return send_message(attach_session_auth(payload))


func send_world_item_drop_create(drop_data: Dictionary, world_name: String) -> bool:
	return send_world_item_drop_message("world_item_drop_create", drop_data, world_name)


func send_world_item_drop_update(drop_data: Dictionary, world_name: String) -> bool:
	return send_world_item_drop_message("world_item_drop_update", drop_data, world_name)


func trace_drop_pickup_network_event(event: String, payload: Dictionary) -> void:
	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return
	if not ("drop_manager" in world_node):
		return
	var drop_manager = world_node.drop_manager
	if drop_manager != null and drop_manager.has_method("trace_drop_pickup_event"):
		drop_manager.trace_drop_pickup_event(event, payload, {})


func send_world_item_drop_pickup(drop_data: Dictionary, _world_name: String = "") -> bool:
	if not (drop_data is Dictionary):
		return false
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_drop_pickup", MAX_WORLD_DROP_PICKUP_RATE_PER_SECOND):
		return false

	var safe_drop_id = _safe_string(drop_data.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	if safe_drop_id == "":
		return false

	var payload = {
		"type": "world_item_drop_pickup",
		"drop_id": safe_drop_id
	}
	if drop_data.has("bulk_pickup"):
		payload["bulk_pickup"] = _safe_bool(drop_data.get("bulk_pickup", true), true)
	if drop_data.has("bulk_pickup_same_tile"):
		payload["bulk_pickup_same_tile"] = _safe_bool(drop_data.get("bulk_pickup_same_tile", true), true)
	if drop_data.has("stack_grid_x"):
		payload["stack_grid_x"] = _safe_int(drop_data.get("stack_grid_x", 0), 0, 0, MAX_COORDINATE)
	if drop_data.has("stack_grid_y"):
		payload["stack_grid_y"] = _safe_int(drop_data.get("stack_grid_y", 0), 0, 0, MAX_COORDINATE)
	if drop_data.has("amount"):
		payload["amount"] = _safe_int(drop_data.get("amount", 0), 0, 0, MAX_DROP_TILE_AMOUNT)
	if drop_data.has("item_type"):
		payload["item_type"] = _safe_string(drop_data.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	if drop_data.has("item_category"):
		payload["item_category"] = _safe_string(drop_data.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	if drop_data.has("request_id"):
		payload["request_id"] = _safe_string(drop_data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if drop_data.has("action_id"):
		payload["action_id"] = _safe_string(drop_data.get("action_id", ""), "", MAX_REQUEST_ID_LENGTH)
	attach_action_request_identity(payload, "world_item_drop_pickup")

	# Pickup is authoritative: the server resolves the world from the session.
	# WebSocket mode includes an action position; NETFOX_REAL uses the live
	# Netfox state bridge instead.
	var world_node = get_world_node()
	if world_node != null and is_world_node_active():
		var action_world = _safe_world_name(current_world_name)
		if "current_world_name" in world_node:
			action_world = _safe_world_name(str(world_node.get("current_world_name")))
		if action_world != "":
			payload["world"] = action_world
		if MovementMode.is_websocket() and "player_facing_direction" in world_node:
			payload["facing"] = 1 if int(world_node.get("player_facing_direction")) >= 0 else -1
		if MovementMode.is_websocket() and "player" in world_node:
			var local_player = world_node.get("player")
			if local_player != null:
				var action_position = local_player.global_position
				payload["x"] = clamp(float(action_position.x), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
				payload["y"] = clamp(float(action_position.y), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)

	attach_current_action_position(payload)
	flush_current_world_position_for_action("world_item_drop_pickup")
	trace_drop_pickup_network_event("network_send_pickup_payload", payload)
	var sent := send_message(attach_session_auth(payload))
	var result_payload := payload.duplicate(true)
	result_payload["message"] = "sent" if sent else "send_failed"
	trace_drop_pickup_network_event("network_send_pickup_result", result_payload)
	return sent


func send_world_item_drop_pickup_bulk(drop_entries: Array, _world_name: String = "") -> bool:
	if not (drop_entries is Array):
		return false
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("world_drop_pickup", MAX_WORLD_DROP_PICKUP_RATE_PER_SECOND):
		return false

	var drop_ids: Array = []
	var pickups: Array = []
	var seen_drop_ids: Dictionary = {}
	var bulk_stack_grid := Vector2i(-1, -1)
	for raw_entry in drop_entries:
		var safe_drop_id := ""
		var entry_payload := {}
		if raw_entry is Dictionary:
			safe_drop_id = _safe_string(raw_entry.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
			if safe_drop_id != "":
				entry_payload["drop_id"] = safe_drop_id
				if raw_entry.has("amount"):
					entry_payload["amount"] = _safe_int(raw_entry.get("amount", 1), 1, 1, MAX_DROP_TILE_AMOUNT)
				if raw_entry.has("item_type"):
					entry_payload["item_type"] = _safe_string(raw_entry.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
				if raw_entry.has("item_category"):
					entry_payload["item_category"] = _safe_string(raw_entry.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
				if raw_entry.has("stack_grid_x") and raw_entry.has("stack_grid_y"):
					var stack_grid_x := _safe_int(raw_entry.get("stack_grid_x", 0), 0, 0, MAX_COORDINATE)
					var stack_grid_y := _safe_int(raw_entry.get("stack_grid_y", 0), 0, 0, MAX_COORDINATE)
					entry_payload["stack_grid_x"] = stack_grid_x
					entry_payload["stack_grid_y"] = stack_grid_y
					if bulk_stack_grid.x < 0:
						bulk_stack_grid = Vector2i(stack_grid_x, stack_grid_y)
		else:
			safe_drop_id = _safe_string(raw_entry, "", MAX_DROP_ID_LENGTH)
			if safe_drop_id != "":
				entry_payload["drop_id"] = safe_drop_id

		if safe_drop_id == "" or seen_drop_ids.has(safe_drop_id):
			continue
		seen_drop_ids[safe_drop_id] = true
		drop_ids.append(safe_drop_id)
		pickups.append(entry_payload)
		if drop_ids.size() >= MAX_BULK_DROP_PICKUP_IDS:
			break

	if drop_ids.is_empty():
		return false
	if drop_ids.size() == 1:
		var single_payload: Dictionary = {"drop_id": drop_ids[0]}
		if pickups[0] is Dictionary:
			single_payload = pickups[0].duplicate(true)
		single_payload["drop_id"] = drop_ids[0]
		if single_payload.has("stack_grid_x") and single_payload.has("stack_grid_y"):
			single_payload["bulk_pickup"] = true
			single_payload["bulk_pickup_same_tile"] = true
		return send_world_item_drop_pickup(single_payload)

	var payload = {
		"type": "world_item_drop_pickup",
		"request_id": make_auth_request_id(),
		"bulk_pickup": true,
		"drop_id": drop_ids[0],
		"drop_ids": drop_ids,
		"pickups": pickups
	}
	if bulk_stack_grid.x >= 0:
		payload["bulk_pickup_same_tile"] = true
		payload["stack_grid_x"] = bulk_stack_grid.x
		payload["stack_grid_y"] = bulk_stack_grid.y

	var world_node = get_world_node()
	if world_node != null and is_world_node_active():
		var action_world = _safe_world_name(current_world_name)
		if "current_world_name" in world_node:
			action_world = _safe_world_name(str(world_node.get("current_world_name")))
		if action_world != "":
			payload["world"] = action_world
		if MovementMode.is_websocket() and "player_facing_direction" in world_node:
			payload["facing"] = 1 if int(world_node.get("player_facing_direction")) >= 0 else -1
		if MovementMode.is_websocket() and "player" in world_node:
			var local_player = world_node.get("player")
			if local_player != null:
				var action_position = local_player.global_position
				payload["x"] = clamp(float(action_position.x), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
				payload["y"] = clamp(float(action_position.y), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)

	attach_current_action_position(payload)
	flush_current_world_position_for_action("world_item_drop_pickup")
	trace_drop_pickup_network_event("network_send_pickup_payload", payload)
	var sent := send_message(attach_session_auth(payload))
	var result_payload := payload.duplicate(true)
	result_payload["message"] = "sent" if sent else "send_failed"
	trace_drop_pickup_network_event("network_send_pickup_result", result_payload)
	return sent


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
	if payload.has("request_id"):
		payload["request_id"] = _safe_string(payload.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH)
	if payload.has("action_id"):
		payload["action_id"] = _safe_string(payload.get("action_id", ""), "", MAX_REQUEST_ID_LENGTH)
	attach_action_request_identity(payload, clean_message_type)
	payload["world"] = _safe_world_name(world_name)
	if payload["world"] == "":
		payload["world"] = _safe_world_name(current_world_name)
	if payload["world"] == "":
		return false
	payload["drop_id"] = _safe_string(payload.get("drop_id", ""), "", MAX_DROP_ID_LENGTH)
	payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
	payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
	payload["is_seed"] = _safe_bool(payload.get("is_seed", false), false)
	payload["amount"] = _safe_int(payload.get("amount", 1), 1, 1, MAX_DROP_TILE_AMOUNT)
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
	if payload.has("request_id"):
		payload["request_id"] = _safe_string(payload.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH)
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
	elif payload["action"] == "safe_get_state" or payload["action"] == "vend_get_state" or payload["action"] == "display_get_state":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
	elif payload["action"] == "safe_deposit" or payload["action"] == "safe_withdraw" or payload["action"] == "display_deposit" or payload["action"] == "display_withdraw":
		payload["item_type"] = _safe_string(payload.get("item_type", ""), "", MAX_ITEM_ID_LENGTH)
		payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		if payload["item_type"] == "" or payload["item_category"] == "":
			return false
		if str(payload["action"]).begins_with("display_"):
			payload["amount"] = 1
		else:
			payload["amount"] = snapped(_safe_float(payload.get("amount", 0.0), 1.0, 0.1, float(MAX_ITEM_STACK_SIZE)), 0.1)
	elif str(payload["action"]).begins_with("donation_box_"):
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		if payload["action"] == "donation_box_donate":
			var donation_item_id := _safe_string(payload.get("item_id", payload.get("item_type", "")), "", MAX_ITEM_ID_LENGTH)
			payload["item_id"] = donation_item_id
			payload["item_type"] = donation_item_id
			payload["item_category"] = _safe_string(payload.get("item_category", ""), "", MAX_ITEM_CATEGORY_LENGTH)
			payload["amount"] = _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
			if donation_item_id == "" or payload["item_category"] == "":
				return false
		elif payload["action"] == "donation_box_retrieve":
			payload["donation_id"] = _safe_string(payload.get("donation_id", ""), "", MAX_DROP_ID_LENGTH)
			if payload["donation_id"] == "":
				return false
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
		payload["amount"] = _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
		if payload["item_type"] == "" or payload["item_category"] == "":
			return false
	elif payload["action"] == "convert_world_lock":
		payload["direction"] = _safe_string(payload.get("direction", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
		if payload["direction"] != "to_super" and payload["direction"] != "to_world_locks":
			return false
	elif payload["action"] == "world_lock_get_key":
		payload["x"] = _safe_int(payload.get("x", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
		payload["y"] = _safe_int(payload.get("y", 0), 0, -MAX_COORDINATE, MAX_COORDINATE)
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
		payload["amount"] = _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
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
		payload["amount"] = _safe_int(payload.get("amount", 0), 1, 1, MAX_ITEM_STACK_SIZE)
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


func send_player_punch(target_player_id: String, target_username: String, target_position: Vector2, facing: int, world_name: String) -> bool:
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("player_punch", MAX_PLAYER_PUNCH_RATE_PER_SECOND):
		return false

	var clean_target_id: String = _safe_string(target_player_id, "", MAX_REQUEST_ID_LENGTH)
	var clean_target_username: String = _safe_string(target_username, "", MAX_USERNAME_LENGTH)
	if clean_target_id == "" and clean_target_username == "":
		return false

	var clean_world: String = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"

	var safe_facing: int = 1 if facing >= 0 else -1
	return send_message(attach_session_auth({
		"type": "player_punch",
		"request_id": make_auth_request_id(),
		"target_player_id": clean_target_id,
		"target_username": clean_target_username,
		"target_x": _safe_float(target_position.x, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE)),
		"target_y": _safe_float(target_position.y, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE)),
		"facing": safe_facing,
		"world": clean_world
	}))


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


func _should_send_full_movement_visual_sync(equipment_slots: Dictionary, fishing_state: Dictionary, damage_state: Dictionary, clean_position_reason: String, bypass_rate_limit: bool) -> bool:
	var now_msec := Time.get_ticks_msec()
	var visual_key := get_equipment_slots_debug_key(equipment_slots)
	visual_key += "|fishing=" + str(bool(fishing_state.get("active", false)))
	visual_key += ":" + str(fishing_state.get("target_x", -1))
	visual_key += ":" + str(fishing_state.get("target_y", -1))
	visual_key += ":" + str(fishing_state.get("lure_id", ""))
	visual_key += ":" + str(fishing_state.get("rod_id", ""))
	visual_key += "|damage=" + str(bool(damage_state.get("active", false)))
	visual_key += ":" + str(int(damage_state.get("token", 0)))

	if bypass_rate_limit or MOVEMENT_VISUAL_SYNC_REASONS.has(clean_position_reason):
		_last_movement_visual_key = visual_key
		_last_movement_visual_sync_msec = now_msec
		return true

	if visual_key != _last_movement_visual_key:
		_last_movement_visual_key = visual_key
		_last_movement_visual_sync_msec = now_msec
		return true

	if now_msec - _last_movement_visual_sync_msec >= MOVEMENT_VISUAL_SYNC_INTERVAL_MS:
		_last_movement_visual_sync_msec = now_msec
		return true

	return false


func send_player_position(position: Vector2, facing: int, world_name: String, allow_join: bool = true, bypass_rate_limit: bool = false, position_reason: String = "") -> bool:
	if not MovementMode.is_websocket():
		return false
	if not is_server_session_authenticated():
		return false
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"
	if not bypass_rate_limit and not _can_send_rate_limited("player_position", get_server_guided_player_position_rate_per_second(clean_world, MAX_PLAYER_POSITION_RATE_PER_SECOND)):
		_set_local_position_payload_queue(clean_world, _build_player_position_payload(position, facing, clean_world, allow_join, false, position_reason), "rate_limited")
		_maybe_log_local_position_queue_debug("local_rate_limited", clean_world, {
			"world": clean_world,
			"position_reason": _safe_string(position_reason, "", MAX_ITEM_ID_LENGTH),
		})
		return false
	if not (position is Vector2):
		return false
	if not _consume_local_position_batch_slot(clean_world):
		local_position_batch_skips += 1
		var batch_population = _get_world_population_for_batching(clean_world)
		_set_local_position_payload_queue(clean_world, _build_player_position_payload(position, facing, clean_world, allow_join, false, position_reason), "batch_limit")
		_maybe_log_local_position_queue_debug("local_batch_skip", clean_world, {
			"world": clean_world,
			"limit": local_position_batch_limit,
			"remaining": local_position_batch_budget,
			"batch_items": get_server_guided_position_batch_max_items(clean_world),
			"batch_world_population": batch_population,
			"position_reason": _safe_string(position_reason, "", MAX_ITEM_ID_LENGTH),
		})
		return false
	if clean_world != current_world_name:
		debug_action_position_flow("player_position world mismatch", {
			"requested_world": clean_world,
			"previous_network_world": current_world_name,
			"allow_join": allow_join,
			"auto_join_disabled": true
		})
		current_world_name = clean_world
	var safe_facing = 1 if facing >= 0 else -1
	var payload = _build_player_position_payload(position, safe_facing, clean_world, allow_join, true, position_reason)
	var sent = _send_local_player_position_payload(clean_world, payload)
	if sent:
		local_position_batch_sends += 1
		_clear_local_position_payload_queue()
		return true

	# This used to be unreachable (an unconditional `return sent` sat above it), so a failed
	# send was silently dropped instead of being queued for retry. Restoring it as the actual
	# else-branch it was written to be.
	local_position_batch_sends += 1
	_set_local_position_payload_queue(clean_world, _build_player_position_payload(position, safe_facing, clean_world, allow_join, false, position_reason), "send_failed")
	return false


func _build_player_position_payload(position: Vector2, safe_facing: int, clean_world: String, allow_join: bool, include_debug_state: bool, position_reason: String) -> Dictionary:
	var safe_x = _safe_float(position.x, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
	var safe_y = _safe_float(position.y, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE))
	var equipment_slots = get_equipment_slots()
	var motion_state = get_player_motion_state()
	var fishing_state = get_player_fishing_state()
	var damage_state = get_player_damage_visual_state()
	var animation_state = str(motion_state.get("animation_state", "idle"))
	var clean_position_reason = _safe_string(position_reason, "", MAX_ITEM_ID_LENGTH).to_lower()

	var payload := {
		"type": "player_position",
		"name": player_name,
		"x": safe_x,
		"y": safe_y,
		"facing": safe_facing,
		"world": clean_world,
		"allow_join": bool(allow_join),
		"animation_state": animation_state,
		"velocity_x": float(motion_state.get("velocity_x", 0.0)),
		"velocity_y": float(motion_state.get("velocity_y", 0.0)),
		"on_floor": bool(motion_state.get("on_floor", true)),
		"in_water": bool(motion_state.get("in_water", false)),
		"in_lava_fire": bool(motion_state.get("in_lava_fire", false)),
		"chat_typing": bool(motion_state.get("chat_typing", false))
	}

	# Fishing/damage are temporary visual state, not core movement state.
	# Send them on change and occasional resync instead of every position packet.
	if _should_send_full_movement_visual_sync(equipment_slots, fishing_state, damage_state, clean_position_reason, false):
		payload["visual_sync"] = true
		payload["equipment_slots"] = equipment_slots
		payload["equipped_tool"] = str(equipment_slots.get("hand", ""))
		payload["equipped_back_item"] = str(equipment_slots.get("back", ""))
		payload["equipped_back"] = str(equipment_slots.get("back", ""))
		payload["equipped_hat_item"] = str(equipment_slots.get("hat", ""))
		payload["equipped_hair_item"] = str(equipment_slots.get("hair", ""))
		payload["equipped_eyewear_item"] = str(equipment_slots.get("eyewear", ""))
		payload["equipped_beard_item"] = str(equipment_slots.get("beard", ""))
		payload["equipped_body_accessory_item"] = str(equipment_slots.get("body_accessory", ""))
		payload["equipped_shirt_item"] = str(equipment_slots.get("shirt", ""))
		payload["equipped_pants_item"] = str(equipment_slots.get("pants", ""))
		payload["equipped_shoes_item"] = str(equipment_slots.get("shoes", ""))
		payload["equipped_ride_item"] = str(equipment_slots.get("ride", ""))
		payload["damage_flash_active"] = bool(damage_state.get("active", false))
		payload["damage_flash_remaining_ms"] = int(damage_state.get("remaining_ms", 0))
		payload["damage_flash_token"] = int(damage_state.get("token", 0))
		payload["fishing_active"] = bool(fishing_state.get("active", false))
		payload["fishing_target_x"] = int(fishing_state.get("target_x", -1))
		payload["fishing_target_y"] = int(fishing_state.get("target_y", -1))
		payload["fishing_lure_id"] = str(fishing_state.get("lure_id", ""))
		payload["fishing_rod_id"] = str(fishing_state.get("rod_id", ""))
	if clean_position_reason != "":
		payload["position_reason"] = clean_position_reason
	if clean_position_reason == "respawn":
		payload["respawn_teleport"] = true

	if include_debug_state and DEBUG_LOCAL_APPEARANCE_FLOW:
		var equipment_key = get_equipment_slots_debug_key(equipment_slots)
		if equipment_key != debug_last_sent_equipment_key:
			debug_last_sent_equipment_key = equipment_key
			print("[APPEARANCE][Client] sending equipment snapshot ", {
				"world": clean_world,
				"equipment_slots": equipment_slots,
				"facing": safe_facing,
				"animation_state": animation_state
			})
		if animation_state != debug_last_sent_animation_state:
			debug_last_sent_animation_state = animation_state
			print("[APPEARANCE][Client] sending animation state ", {
				"world": clean_world,
				"animation_state": animation_state,
				"facing": safe_facing
			})

	return payload


func _send_local_player_position_payload(world_name: String, payload: Dictionary) -> bool:
	if not (payload is Dictionary):
		return false
	var outgoing := payload.duplicate(true)
	var next_movement_sequence = movement_sequence + 1
	if next_movement_sequence >= 2147483647:
		next_movement_sequence = 1
	outgoing["movement_sequence"] = next_movement_sequence
	var sent_at_msec := Time.get_ticks_msec()
	outgoing["client_time_msec"] = sent_at_msec
	var sent := send_message(attach_session_auth(outgoing))
	if sent:
		movement_sequence = next_movement_sequence
		_maybe_log_local_position_queue_debug("sent", world_name, {
			"world": world_name,
			"movement_sequence": next_movement_sequence,
			"queued_world": local_position_pending_world,
			"queued_reason": local_position_pending_reason,
			"reason": str(outgoing.get("position_reason", "")),
			"client_time_msec": sent_at_msec
		})
	return sent


func _process_local_position_queue() -> void:
	if not has_local_position_pending:
		return
	if not MovementMode.is_websocket():
		return
	if not is_server_session_authenticated():
		return
	if not (local_position_pending_payload is Dictionary):
		_clear_local_position_payload_queue()
		return

	var now_msec := Time.get_ticks_msec()
	if now_msec - local_position_queue_last_flush_msec < LOCAL_POSITION_QUEUE_FLUSH_INTERVAL_MS:
		return

	local_position_queue_last_flush_msec = now_msec
	var queue_age_msec := now_msec - local_position_pending_queued_msec
	if queue_age_msec < 0:
		queue_age_msec = 0

	var clean_world := _safe_world_name(local_position_pending_world)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		clean_world = "START"

	var max_rate_per_second = get_server_guided_player_position_rate_per_second(clean_world, MAX_PLAYER_POSITION_RATE_PER_SECOND)
	if not _can_send_rate_limited("player_position", max_rate_per_second):
		_maybe_log_local_position_queue_debug("local_queue_rate_limited", clean_world, {
			"world": clean_world,
			"queue_age_msec": queue_age_msec,
			"reason": local_position_pending_reason
		})
		return

	if not _consume_local_position_batch_slot(clean_world):
		_maybe_log_local_position_queue_debug("local_queue_batch_skip", clean_world, {
			"world": clean_world,
			"remaining": local_position_batch_budget,
			"limit": local_position_batch_limit,
			"queue_age_msec": queue_age_msec,
			"reason": local_position_pending_reason
		})
		return

	var sent := _send_local_player_position_payload(clean_world, local_position_pending_payload)
	local_position_batch_sends += 1
	if sent:
		_clear_local_position_payload_queue()
		_maybe_log_local_position_queue_debug("local_queue_flush_success", clean_world, {
			"world": clean_world,
			"queue_age_msec": queue_age_msec,
			"reason": local_position_pending_reason
		})
		return

	_maybe_log_local_position_queue_debug("local_queue_send_failed", clean_world, {
		"world": clean_world,
		"queue_age_msec": queue_age_msec,
		"reason": local_position_pending_reason
	})


func _set_local_position_payload_queue(world_name: String, payload: Dictionary, reason: String) -> void:
	var clean_world = _safe_world_name(world_name)
	if clean_world == "":
		clean_world = "START"
	if not (payload is Dictionary):
		return
	local_position_pending_payload = payload.duplicate(true)
	local_position_pending_world = clean_world
	local_position_pending_reason = _safe_string(reason, "pending")
	local_position_pending_queued_msec = Time.get_ticks_msec()
	has_local_position_pending = true


func _clear_local_position_payload_queue() -> void:
	local_position_pending_payload = {}
	local_position_pending_world = ""
	local_position_pending_reason = ""
	local_position_pending_queued_msec = 0
	has_local_position_pending = false
	local_position_queue_last_flush_msec = 0


func _maybe_log_local_position_queue_debug(event_name: String, world_name: String, details: Dictionary = {}) -> void:
	if not DEBUG_ACTION_POSITION_FLOW:
		return
	var now_msec = Time.get_ticks_msec()
	if now_msec - _last_local_position_debug_msec < LOCAL_POSITION_QUEUE_FLUSH_DEBUG_INTERVAL_MS:
		return
	_last_local_position_debug_msec = now_msec
	var payload = {
		"event": event_name,
		"world": world_name,
	}
	for key in details.keys():
		payload[key] = details[key]
	print("[MovementSync][Local] " + str(payload))

func send_netfox_trusted_player_state(position: Vector2, velocity: Vector2, facing: int, world_name: String, peer_id: int, tick: int = 0, bypass_rate_limit: bool = false) -> bool:
	if not MovementMode.is_netfox_real():
		return false
	return _send_trusted_player_state("netfox_trusted_player_state", position, velocity, facing, world_name, peer_id, tick, bypass_rate_limit, _get_local_netfox_player_path())


func send_custom_trusted_player_state(position: Vector2, velocity: Vector2, facing: int, world_name: String, peer_id: int, tick: int = 0, player_node_path: String = "", bypass_rate_limit: bool = false) -> bool:
	if not MovementMode.is_custom_authoritative():
		return false
	return _send_trusted_player_state("custom_trusted_player_state", position, velocity, facing, world_name, peer_id, tick, bypass_rate_limit, player_node_path)


func send_custom_trusted_player_state_clear(world_name: String, peer_id: int = 0, reason: String = "clear") -> bool:
	if not MovementMode.is_custom_authoritative():
		return false
	if not is_server_session_authenticated():
		return false
	if not _can_send_rate_limited("custom_state_bridge", MAX_NETFOX_STATE_BRIDGE_RATE_PER_SECOND):
		return false

	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		clean_world = "START"

	var payload := {
		"type": "custom_trusted_player_state_clear",
		"request_id": make_auth_request_id(),
		"movement_mode": MovementMode.get_mode_name(),
		"world": clean_world,
		"world_id": clean_world,
		"peer_id": max(peer_id, 0),
		"reason": _safe_string(reason, "clear", MAX_ITEM_ID_LENGTH)
	}
	var identity := get_active_identity_payload(clean_world)
	for key in identity.keys():
		if not payload.has(key):
			payload[key] = identity[key]
	return send_message(attach_session_auth(payload))


func _send_trusted_player_state(message_type: String, position: Vector2, velocity: Vector2, facing: int, world_name: String, peer_id: int, tick: int = 0, bypass_rate_limit: bool = false, player_node_path: String = "") -> bool:
	if not is_server_session_authenticated():
		return false
	var rate_key := "custom_state_bridge" if message_type == "custom_trusted_player_state" else "netfox_state_bridge"
	if not bypass_rate_limit and not _can_send_rate_limited(rate_key, MAX_NETFOX_STATE_BRIDGE_RATE_PER_SECOND):
		return false
	if not (position is Vector2):
		return false

	var clean_world := _safe_world_name(world_name)
	if clean_world == "":
		clean_world = _safe_world_name(current_world_name)
	if clean_world == "":
		return false

	var safe_facing := 1 if facing >= 0 else -1
	var payload := {
		"type": message_type,
		"request_id": make_auth_request_id(),
		"movement_mode": MovementMode.get_mode_name(),
		"world": clean_world,
		"world_id": clean_world,
		"x": _safe_float(position.x, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE)),
		"y": _safe_float(position.y, 0.0, float(MIN_PLAYER_COORDINATE), float(MAX_PLAYER_COORDINATE)),
		"velocity_x": _safe_float(velocity.x, 0.0, -2000.0, 2000.0),
		"velocity_y": _safe_float(velocity.y, 0.0, -2000.0, 2000.0),
		"facing": safe_facing,
		"facing_dir": safe_facing,
		"peer_id": max(peer_id, 0),
		"tick": max(tick, 0),
		"player_node_path": _safe_string(player_node_path, "", MAX_REQUEST_ID_LENGTH)
	}
	var identity := get_active_identity_payload(clean_world)
	for key in identity.keys():
		if not payload.has(key):
			payload[key] = identity[key]

	if is_netfox_trusted_position_debug_enabled():
		var now_msec := Time.get_ticks_msec()
		if bypass_rate_limit or now_msec - _last_netfox_trusted_position_debug_msec >= 1000:
			_last_netfox_trusted_position_debug_msec = now_msec
			debug_netfox_trusted_position("trusted position send", {
				"world": clean_world,
				"peer_id": peer_id,
				"node_path": player_node_path,
				"trusted_position": Vector2(roundf(position.x), roundf(position.y)),
				"velocity": Vector2(roundf(velocity.x), roundf(velocity.y)),
				"tick": tick,
				"bypass_rate_limit": bypass_rate_limit
			})
	return send_message(attach_session_auth(payload))


func attach_current_action_position(payload: Dictionary) -> void:
	if not (payload is Dictionary):
		return

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return

	var local_player = null
	if "player" in world_node:
		local_player = world_node.get("player")
	if local_player == null or not (local_player is Node2D):
		return

	var action_position: Vector2 = local_player.global_position
	if MovementMode.is_netfox_real() or MovementMode.is_custom_authoritative():
		payload["movement_mode"] = MovementMode.get_mode_name()
	payload["actor_x"] = clamp(float(action_position.x), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)
	payload["actor_y"] = clamp(float(action_position.y), -MAX_PLAYER_COORDINATE, MAX_PLAYER_COORDINATE)

	var action_world := _safe_world_name(current_world_name)
	if "current_world_name" in world_node:
		action_world = _safe_world_name(str(world_node.get("current_world_name")))
	if action_world != "":
		payload["actor_world"] = action_world

	if "player_facing_direction" in world_node:
		payload["actor_facing"] = 1 if int(world_node.get("player_facing_direction")) >= 0 else -1

	if MovementMode.is_netfox_real() or MovementMode.is_custom_authoritative():
		var raw_velocity = local_player.get("velocity")
		if raw_velocity is Vector2:
			payload["actor_velocity_x"] = _safe_float(raw_velocity.x, 0.0, -2000.0, 2000.0)
			payload["actor_velocity_y"] = _safe_float(raw_velocity.y, 0.0, -2000.0, 2000.0)

		var raw_facing = local_player.get("facing_dir")
		if raw_facing != null:
			payload["actor_facing"] = -1 if int(raw_facing) < 0 else 1

		var raw_peer = local_player.get("owning_peer_id")
		if raw_peer != null:
			payload["actor_peer_id"] = max(int(raw_peer), 0)
		elif local_player.has_meta("netfox_peer_id"):
			payload["actor_peer_id"] = max(int(local_player.get_meta("netfox_peer_id", 0)), 0)

		var raw_tick = local_player.get("rollback_tick_count")
		if raw_tick != null:
			payload["actor_tick"] = max(int(raw_tick), 0)

		payload["actor_player_node_path"] = _safe_string(str((local_player as Node).get_path()), "", MAX_REQUEST_ID_LENGTH)


func flush_world_position_for_payload(payload: Dictionary) -> void:
	attach_current_action_position(payload)
	if str(payload.get("world", "")).strip_edges() == "":
		return
	flush_current_world_position_for_action(str(payload.get("type", payload.get("action", ""))))


func flush_current_world_position_for_action(action_type: String) -> void:
	if MovementMode.is_netfox_real():
		flush_current_netfox_position_for_action(action_type)
		return

	if MovementMode.is_custom_authoritative():
		return

	if not MovementMode.is_websocket():
		return

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return
	if world_node.has_method("flush_multiplayer_position"):
		debug_action_position_flow("flush position before world action", {
			"action_type": action_type,
		})
		world_node.flush_multiplayer_position(false, true)


func flush_current_netfox_position_for_action(action_type: String) -> bool:
	if not MovementMode.is_netfox_real():
		return false
	if not is_server_session_authenticated():
		debug_netfox_identity("trusted position flush skipped", {
			"reason": "not_authenticated",
			"action_type": action_type,
			"world": current_world_name
		})
		return false

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		debug_netfox_identity("trusted position flush skipped", {
			"reason": "world_not_active",
			"action_type": action_type,
			"world": current_world_name
		})
		return false

	var local_player = world_node.get("player") if "player" in world_node else null
	if local_player == null or not (local_player is Node2D):
		debug_netfox_identity("trusted position flush skipped", {
			"reason": "missing_local_netfox_player",
			"action_type": action_type,
			"world": current_world_name
		})
		return false

	var velocity := Vector2.ZERO
	var raw_velocity = local_player.get("velocity")
	if raw_velocity is Vector2:
		velocity = raw_velocity

	var facing := 1
	var raw_facing = local_player.get("facing_dir")
	if raw_facing != null:
		facing = -1 if int(raw_facing) < 0 else 1

	var peer_id := 0
	var raw_peer = local_player.get("owning_peer_id")
	if raw_peer != null:
		peer_id = int(raw_peer)
	elif local_player.has_meta("netfox_peer_id"):
		peer_id = int(local_player.get_meta("netfox_peer_id", 0))

	var tick := 0
	var raw_tick = local_player.get("rollback_tick_count")
	if raw_tick != null:
		tick = int(raw_tick)

	var action_world := _safe_world_name(current_world_name)
	if "current_world_name" in world_node:
		action_world = _safe_world_name(str(world_node.get("current_world_name")))
	if action_world == "":
		action_world = _safe_world_name(current_world_name)

	return send_netfox_trusted_player_state(
		(local_player as Node2D).global_position,
		velocity,
		facing,
		action_world,
		peer_id,
		tick,
		true
	)


func _get_local_netfox_player_path() -> String:
	var world_node = get_world_node()
	if world_node == null:
		return ""

	var local_player = world_node.get("player") if "player" in world_node else null
	if local_player is Node:
		return str((local_player as Node).get_path())

	return ""


func sync_active_world_name_from_server(world_name, target_world_node: Node = null) -> void:
	var clean_world: String = _safe_world_name(world_name)
	if clean_world == "":
		return

	current_world_name = clean_world
	var world_node: Node = target_world_node
	if world_node == null or not is_instance_valid(world_node):
		world_node = get_world_node()

	if world_node != null and "current_world_name" in world_node:
		world_node.set("current_world_name", clean_world)


func handle_world_update_batch(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var updates = data.get("updates", [])
	if not (updates is Array) or updates.is_empty():
		return

	var batch_world: String = _get_message_world_name(data)
	for raw_update in updates:
		if not (raw_update is Dictionary):
			continue
		var update_payload: Dictionary = raw_update.duplicate(true)
		if not update_payload.has("world") or _safe_world_name(update_payload.get("world", "")) == "":
			update_payload["world"] = batch_world
		handle_world_update_payload(update_payload)


func handle_player_position_batch(data: Dictionary) -> void:
	if not MovementMode.is_websocket() or not is_message_for_active_world(data):
		return

	var world_node = get_world_node()
	var batch_world: String = _get_message_world_name(data)
	var batch_left = data.get("left", [])
	if batch_left is Array:
		for raw_left_entry in batch_left:
			if not (raw_left_entry is Dictionary):
				continue
			var left_entry: Dictionary = raw_left_entry.duplicate(true)
			if _get_message_world_name(left_entry) == "":
				left_entry["world"] = batch_world
			if not is_message_for_active_world(left_entry):
				continue
			var left_player_id := _safe_string(left_entry.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH)
			if left_player_id == "" or left_player_id == player_id:
				continue
			var batch_interest_cull := bool(left_entry.get("interest_cull", false)) or str(left_entry.get("reason", "")).strip_edges().to_lower() == "out_of_interest"
			if not batch_interest_cull:
				forget_world_player(str(left_entry.get("world", current_world_name)), left_player_id)
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_left"):
				world_node.handle_network_player_left(left_player_id)

	var batch_players = data.get("players", [])
	if batch_players is Array:
		for raw_player_entry in batch_players:
			if not (raw_player_entry is Dictionary):
				continue
			var player_entry: Dictionary = raw_player_entry.duplicate(true)
			if _get_message_world_name(player_entry) == "":
				player_entry["world"] = batch_world
			if not is_message_for_active_world(player_entry):
				continue
			var batch_player_id := _safe_string(player_entry.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH)
			if batch_player_id == "" or batch_player_id == player_id:
				continue
			remember_world_player(str(player_entry.get("world", current_world_name)), batch_player_id)
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_position"):
				world_node.handle_network_player_position(player_entry)


func handle_world_update_payload(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var message_type := _safe_string(data.get("type", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH).to_lower()
	var world_node = null
	match message_type:
		"world_block_update":
			if str(data.get("action", "")).to_lower() == "break":
				debug_action_position_flow("received batched block break update", data)
			trace_world_block_event("received_world_block_update", data)
			apply_player_state_payload_if_present(data)
			apply_progression_payload_if_present(data)
			if _queue_pending_world_entry_block_update_if_needed(data):
				return
			if not queue_world_block_update_behind_pending_event_updates(data):
				world_node = get_world_node()
				if world_node != null and is_world_node_active() and world_node.has_method("apply_network_block_update"):
					world_node.apply_network_block_update(data)
					_note_pending_world_entry_block_update(data)
		"world_block_reconcile":
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_block_reconcile"):
				world_node.apply_network_block_reconcile(data)
		"electrical_layer_update":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_electrical_layer_update"):
				world_node.apply_network_electrical_layer_update(data)
		"generator_data_update":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_generator_data_update"):
				world_node.apply_network_generator_data_update(data)
		"generator_generation_pulse":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_generator_generation_pulse"):
				world_node.apply_network_generator_generation_pulse(data)
		"refresh_wire_visibility":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_wire_visibility_refresh"):
				world_node.apply_network_wire_visibility_refresh(data)
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
				var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
				drop_update_payload["_server_inventory_update_applied"] = inventory_update_applied
				drop_update_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)
				world_node.apply_network_item_drop_update(drop_update_payload)
		"world_item_drop_pickup", "world_drop_pickup":
			debug_action_position_flow("received batched drop pickup/update packet", data)
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node == null or not is_world_node_active():
				return

			var pickup_payload = data.duplicate(true)
			var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
			pickup_payload["_server_inventory_update_applied"] = inventory_update_applied
			pickup_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)

			if world_node.has_method("apply_network_item_drop_update"):
				world_node.apply_network_item_drop_update(pickup_payload)
			else:
				world_node.apply_network_item_drop_remove(pickup_payload)
		"world_item_drop_remove", "world_drop_remove", "drop_removed":
			debug_action_position_flow("received batched drop remove update", data)
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_item_drop_remove"):
				var pickup_remove_payload = data.duplicate(true)
				var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
				pickup_remove_payload["_server_inventory_update_applied"] = inventory_update_applied
				pickup_remove_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)
				world_node.apply_network_item_drop_remove(pickup_remove_payload)


func handle_server_message(raw: String, wire_bytes: int = 0) -> void:
	if raw == "":
		return
	if wire_bytes <= 0:
		wire_bytes = raw.to_utf8_buffer().size()
	if wire_bytes > MAX_SERVER_MESSAGE_BYTES:
		return

	var parse_started_usec := Time.get_ticks_usec()
	var json = JSON.new()
	var error = json.parse(raw)
	var parse_usec := Time.get_ticks_usec() - parse_started_usec
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
	_record_world_entry_packet(message_type, wire_bytes, parse_usec)
	update_developer_pin_state_from_message(data)
	var world_node = null
	var safe_world = _get_message_world_name(data)

	match message_type:
		"connected":
			player_id = _safe_string(data.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH)
			if game_player_id.strip_edges() == "":
				game_player_id = player_id
			_check_connected_client_version(data)
		"login_ok":
			player_name = _safe_string(data.get("name", player_name), player_name, MAX_USERNAME_LENGTH)
		"client_update_required":
			login_notice_message = str(data.get("message", "Please update PixelMania."))
			_store_client_update_payload(data)
			server_auth_finished.emit(data)
		"account_auth_ok":
			handle_account_auth_ok(data)
		"account_auth_error":
			var had_session_before_auth_error := has_active_session()
			var saved_refresh_login_failed := saved_refresh_login_in_flight
			saved_refresh_login_in_flight = false
			server_session_authenticated = false
			if saved_refresh_login_failed and _auth_error_invalidates_saved_login(data):
				_clear_saved_session_token()
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
			if not _is_message_for_active_join_request(data):
				debug_action_position_flow("ignored stale join_world_ok request", {
					"incoming_join_request_id": _get_message_join_request_id(data),
					"active_join_request_id": active_join_request_id,
					"world": safe_world
				})
				return
			var guided_world = safe_world
			if guided_world == "":
				guided_world = _safe_world_name(str(data.get("world", current_world_name)))
			if guided_world == "":
				guided_world = _safe_world_name(current_world_name)
			if guided_world == "":
				guided_world = "START"
			if safe_world != "" and not is_message_for_active_world(data):
				debug_action_position_flow("ignored stale join_world_ok", {
					"incoming_world": safe_world,
					"current_world": current_world_name
				})
				return
			if not _accept_world_entry_session_from_join_ack(data):
				_handle_world_entry_rejected_message({
					"type": "world_entry_rejected",
					"reason": "missing_world_entry_session",
					"message": "The world entry session was incomplete. Please try again.",
					"world": guided_world,
					"join_request_id": _get_message_join_request_id(data)
				})
				return
			apply_server_movement_guidance(guided_world, data.get("network_movement_guidance", {}))
			current_world_name = guided_world
			store_netfox_spawn_route_from_message(data)
			clear_world_route_redirect_state(true)
			sync_active_world_name_from_server(current_world_name)
			if not apply_player_state_payload_if_present(data):
				queue_player_state_payload_if_present(data)
			sync_current_world_population_from_players(current_world_name, data.get("players", []))
			world_node = get_world_node()
			play_local_join_world_sound(world_node)
			if MovementMode.is_netfox_real():
				if world_node != null and is_world_node_active() and world_node.has_method("clear_remote_players"):
					world_node.clear_remote_players()
			elif world_node != null and is_world_node_active() and world_node.has_method("handle_network_existing_players"):
				world_node.handle_network_existing_players(data.get("players", []))
		"netfox_spawn_ticket":
			_log_netfox_spawn_ticket_response(data)
			store_netfox_spawn_route_from_message(data)
		"door_enter_ok":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_door_enter_ok"):
				world_node.handle_network_door_enter_ok(data)
			if safe_world != "":
				current_world_name = safe_world
		"world_state_stream_begin":
			_handle_world_state_stream_begin(data, wire_bytes)
		"world_state_stream_chunk":
			_handle_world_state_stream_chunk(data, wire_bytes)
		"world_state_stream_end":
			_handle_world_state_stream_end(data, wire_bytes)
		"world_entry_snapshot_restart":
			_handle_world_entry_snapshot_restart(data)
		"world_entry_catchup_wait":
			_handle_world_entry_catchup_wait(data)
		"world_entry_active":
			_handle_world_entry_active(data)
		"world_entry_rejected":
			_handle_world_entry_rejected_message(data)
		"world_state":
			if not _is_message_for_active_join_request(data):
				debug_action_position_flow("ignored stale world_state request", {
					"incoming_join_request_id": _get_message_join_request_id(data),
					"active_join_request_id": active_join_request_id,
					"world": safe_world
				})
				return
			if not _is_message_for_active_world_entry_session(data):
				debug_action_position_flow("ignored stale world_state entry session", {
					"incoming_world_entry_session_id": _get_message_world_entry_session_id(data),
					"active_world_entry_session_id": active_world_entry_session_id,
					"world": safe_world
				})
				return
			pending_world_state_stream.clear()
			if safe_world != "" and not is_message_for_active_world(data):
				debug_action_position_flow("ignored stale world_state", {
					"incoming_world": safe_world,
					"current_world": current_world_name,
					"world_state_reason": str(data.get("world_state_reason", ""))
				})
				return
			debug_action_position_flow("received world_state", {
				"world": safe_world,
				"respawn_player": data.get("respawn_player", null),
				"force_respawn": data.get("force_respawn", null),
				"world_state_reason": str(data.get("world_state_reason", ""))
			})
			if not _is_valid_server_world_state_payload(data):
				_retry_invalid_server_world_state(data)
				return
			if not _accept_world_entry_snapshot_metadata(data):
				return
			record_world_entry_stage("client_world_data_received", {
				"transport": "legacy",
				"wire_bytes": wire_bytes,
				"transfer_ms": _get_world_entry_transfer_ms()
			})
			world_node = get_world_node()
			if not _world_node_can_apply_server_world_state(world_node):
				_queue_pending_server_world_state(data, "world_scene_not_ready")
				return
			_apply_server_world_state_payload(data, world_node)
		"world_block_update":
			if str(data.get("action", "")).to_lower() == "break":
				debug_action_position_flow("received block break update", data)
			trace_world_block_event("received_world_block_update", data)
			apply_player_state_payload_if_present(data)
			apply_progression_payload_if_present(data)
			if _queue_pending_world_entry_block_update_if_needed(data):
				return
			if not queue_world_block_update_behind_pending_event_updates(data):
				world_node = get_world_node()
				if world_node != null and is_world_node_active() and world_node.has_method("apply_network_block_update"):
					world_node.apply_network_block_update(data)
					_note_pending_world_entry_block_update(data)
		"world_block_reconcile":
			apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_block_reconcile"):
				world_node.apply_network_block_reconcile(data)
		"electrical_layer_update":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_electrical_layer_update"):
				world_node.apply_network_electrical_layer_update(data)
		"generator_data_update":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_generator_data_update"):
				world_node.apply_network_generator_data_update(data)
		"generator_generation_pulse":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_generator_generation_pulse"):
				world_node.apply_network_generator_generation_pulse(data)
		"refresh_wire_visibility":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("apply_network_wire_visibility_refresh"):
				world_node.apply_network_wire_visibility_refresh(data)
		"world_update_batch":
			handle_world_update_batch(data)
		"event_started":
			handle_world_event_started(data)
		"event_ended":
			handle_world_event_ended(data)
		"event_system_message":
			handle_world_event_system_message(data)
		"event_tile_updates":
			handle_world_event_tile_updates(data)
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
				var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
				drop_update_payload["_server_inventory_update_applied"] = inventory_update_applied
				drop_update_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)
				world_node.apply_network_item_drop_update(drop_update_payload)
		"world_item_drop_pickup", "world_drop_pickup":
			debug_action_position_flow("received drop pickup/update packet", data)
			var player_state_applied = apply_player_state_payload_if_present(data)
			world_node = get_world_node()
			if world_node == null or not is_world_node_active():
				return

			var pickup_payload = data.duplicate(true)
			var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
			pickup_payload["_server_inventory_update_applied"] = inventory_update_applied
			pickup_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)

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
				var inventory_update_applied = did_server_inventory_update_apply(data, player_state_applied)
				pickup_remove_payload["_server_inventory_update_applied"] = inventory_update_applied
				pickup_remove_payload["_apply_pickup_inventory"] = should_apply_pickup_inventory_from_payload(data, inventory_update_applied)
				world_node.apply_network_item_drop_remove(pickup_remove_payload)
		"player_state":
			handle_player_state_message(data)
		"world_population", "world_population_update":
			var incoming = data.get("world_counts", {})
			if incoming is Dictionary:
				_apply_world_population_payload(incoming, data.get("clear_unreported", false))
			elif data.has("worlds") and data.get("worlds") is Dictionary:
				_apply_world_population_payload(data.get("worlds"), data.get("clear_unreported", false))

			var raw_guidance = data.get("network_movement_guidance", {})
			if raw_guidance is Dictionary:
				var guidance_map = raw_guidance
				if guidance_map.has("position_heartbeat_interval_ms") or guidance_map.has("position_batch_max_items"):
					var guided_world = safe_world
					if guided_world == "" and incoming is Dictionary and not incoming.is_empty():
						var first_world = incoming.keys()[0]
						guided_world = _safe_world_name(first_world)
					if guided_world == "":
						guided_world = _safe_world_name(current_world_name)
					if guided_world != "":
						apply_server_movement_guidance(guided_world, guidance_map)
				else:
					for raw_guided_world in guidance_map.keys():
						var clean_guided_world = _safe_world_name(str(raw_guided_world))
						if clean_guided_world == "":
							continue
						apply_server_movement_guidance(clean_guided_world, guidance_map.get(raw_guided_world))
		"owned_locked_worlds_result":
			handle_owned_locked_worlds_result(data)
		"landfill_race_state":
			handle_landfill_race_state(data)
		"landfill_race_results":
			handle_landfill_race_results(data)
		"landfill_status":
			handle_landfill_status_result(data)
		"landfill_join_result":
			handle_landfill_join_result(data)
		"landfill_leaderboard":
			handle_landfill_leaderboard_result(data)
		"landfill_claim_result":
			handle_landfill_claim_result(data)
		"world_route_redirect":
			handle_world_route_redirect(data)
		"inventory_transaction_result":
			handle_inventory_transaction_result(data)
		"iap_checkout_session_result":
			handle_iap_checkout_session_result(data)
		"iap_purchase_result":
			handle_iap_purchase_result(data)
		"fishing_reward_fx":
			handle_fishing_reward_fx(data)
		"action_rejected":
			if _route_action_rejected_as_player_state_lookup(data):
				return
			if str(data.get("reason", "")).strip_edges().to_lower() == "world_route_redirect" and handle_world_route_redirect(data):
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
		"player_position_batch":
			handle_player_position_batch(data)
		"player_position", "player_joined":
			if not MovementMode.is_websocket():
				return
			if _safe_string(data.get("player_id", ""), "", MAX_REQUEST_ID_LENGTH) != player_id:
				remember_world_player(str(data.get("world", current_world_name)), str(data.get("player_id", "")))
				world_node = get_world_node()
				if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_position"):
					world_node.handle_network_player_position(data)
		"player_punch_knockback":
			if not MovementMode.is_websocket():
				return
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_punch_knockback"):
				world_node.handle_network_player_punch_knockback(data)
		"player_left":
			var interest_cull := bool(data.get("interest_cull", false)) or str(data.get("reason", "")).strip_edges().to_lower() == "out_of_interest"
			if not interest_cull:
				forget_world_player(str(data.get("world", current_world_name)), str(data.get("player_id", "")))
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_network_player_left"):
				world_node.handle_network_player_left(str(data.get("player_id", "")))
		"developer_command_verified", "developer_command_approved":
			world_node = get_world_node()
			if world_node != null and is_world_node_active() and world_node.has_method("handle_verified_developer_command"):
				world_node.handle_verified_developer_command(str(data.get("command", "")), str(data.get("request_id", "")), str(data.get("message", "")), data)
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


func _is_drop_pickup_result_action(action: String) -> bool:
	var clean_action: String = str(action).strip_edges().to_lower()
	return clean_action == "drop_pickup" or clean_action == "world_item_drop_pickup" or clean_action == "world_drop_pickup"


func _append_unique_pickup_drop_id(target: Array, seen: Dictionary, raw_id) -> void:
	var clean_id: String = _safe_string(raw_id, "", MAX_DROP_ID_LENGTH)
	if clean_id == "" or seen.has(clean_id):
		return
	seen[clean_id] = true
	target.append(clean_id)


func _build_bulk_pickup_world_result_from_transaction(data: Dictionary, inventory_update_applied: bool) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)
	var raw_drop_ids: Variant = data.get("drop_ids", [])
	var raw_removed_ids: Variant = data.get("removed_drop_ids", [])
	var raw_updated_drops: Variant = data.get("updated_drops", [])
	var raw_pickup_results: Variant = data.get("pickup_results", [])
	var drop_ids: Array = []
	var removed_ids: Array = []
	var updated_drops: Array = []
	var seen_drop_ids: Dictionary = {}
	var seen_removed_ids: Dictionary = {}

	if raw_drop_ids is Array:
		for raw_id in raw_drop_ids:
			_append_unique_pickup_drop_id(drop_ids, seen_drop_ids, raw_id)

	var primary_drop_id: String = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	if primary_drop_id != "":
		_append_unique_pickup_drop_id(drop_ids, seen_drop_ids, primary_drop_id)

	if raw_removed_ids is Array:
		for raw_id in raw_removed_ids:
			_append_unique_pickup_drop_id(removed_ids, seen_removed_ids, raw_id)

	if raw_updated_drops is Array:
		for raw_update in raw_updated_drops:
			if not (raw_update is Dictionary):
				continue
			var update_payload: Dictionary = raw_update.duplicate(true)
			var update_drop_id: String = _safe_string(update_payload.get("drop_id", update_payload.get("id", "")), "", MAX_DROP_ID_LENGTH)
			if update_drop_id == "":
				continue
			if not update_payload.has("type"):
				update_payload["type"] = "world_item_drop_update"
			if not update_payload.has("world") and data.has("world"):
				update_payload["world"] = data.get("world")
			updated_drops.append(update_payload)
			_append_unique_pickup_drop_id(drop_ids, seen_drop_ids, update_drop_id)

	if raw_pickup_results is Array:
		for raw_result in raw_pickup_results:
			if not (raw_result is Dictionary):
				continue
			var result: Dictionary = raw_result
			if not bool(result.get("ok", false)):
				continue
			var result_drop_id: String = _safe_string(result.get("drop_id", result.get("id", "")), "", MAX_DROP_ID_LENGTH)
			if result_drop_id == "":
				continue
			_append_unique_pickup_drop_id(drop_ids, seen_drop_ids, result_drop_id)
			var remaining_amount: float = _safe_pickup_remaining_amount(result)
			if bool(result.get("removed", false)) or remaining_amount == 0:
				_append_unique_pickup_drop_id(removed_ids, seen_removed_ids, result_drop_id)
			elif remaining_amount != PICKUP_REMAINING_AMOUNT_UNKNOWN:
				var update_payload: Dictionary = {
					"type": "world_item_drop_update",
					"drop_id": result_drop_id,
					"amount": remaining_amount,
					"remaining": remaining_amount,
					"remaining_amount": remaining_amount
				}
				if data.has("world"):
					update_payload["world"] = data.get("world")
				var result_item_type: String = _safe_string(result.get("item_type", result.get("item_id", "")), "", MAX_ITEM_ID_LENGTH)
				if result_item_type != "":
					update_payload["item_type"] = result_item_type
				var result_category: String = _safe_string(result.get("item_category", result.get("category", "")), "", MAX_ITEM_CATEGORY_LENGTH)
				if result_category != "":
					update_payload["item_category"] = result_category
				updated_drops.append(update_payload)

	if removed_ids.is_empty() and updated_drops.is_empty() and primary_drop_id != "":
		var has_explicit_remaining: bool = false
		for remaining_key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
			if data.has(remaining_key):
				has_explicit_remaining = true
				break
		var single_remaining: float = float(PICKUP_REMAINING_AMOUNT_UNKNOWN)
		if has_explicit_remaining or bool(data.get("removed", false)):
			single_remaining = _safe_pickup_remaining_amount(data)
		if bool(data.get("removed", false)) or single_remaining == 0:
			_append_unique_pickup_drop_id(removed_ids, seen_removed_ids, primary_drop_id)
		elif single_remaining != PICKUP_REMAINING_AMOUNT_UNKNOWN:
			var update_payload: Dictionary = data.duplicate(true)
			update_payload["type"] = "world_item_drop_update"
			update_payload["amount"] = single_remaining
			update_payload["remaining"] = single_remaining
			update_payload["remaining_amount"] = single_remaining
			updated_drops.append(update_payload)

	payload["type"] = "world_item_drop_remove"
	payload["bulk_pickup"] = true
	payload["drop_ids"] = drop_ids
	payload["removed_drop_ids"] = removed_ids
	payload["updated_drops"] = updated_drops
	payload["_server_inventory_update_applied"] = inventory_update_applied
	payload["_apply_pickup_inventory"] = not inventory_update_applied
	return payload


func _append_pickup_inventory_delta_from_payload(delta_entries: Array, raw_payload: Dictionary) -> void:
	var item_type: String = _safe_string(raw_payload.get("item_type", raw_payload.get("item_id", "")), "", MAX_ITEM_ID_LENGTH)
	if item_type == "":
		return
	var item_category: String = _safe_string(raw_payload.get("item_category", raw_payload.get("category", "")), "", MAX_ITEM_CATEGORY_LENGTH)
	var amount: int = _safe_int(raw_payload.get("amount", raw_payload.get("picked_amount", raw_payload.get("picked", raw_payload.get("delta", 0)))), 0, 0, MAX_DROP_TILE_AMOUNT)
	if amount <= 0:
		return
	delta_entries.append({
		"item_type": item_type,
		"item_category": item_category,
		"delta": amount
	})


func apply_pickup_reward_inventory_fallback(data: Dictionary) -> bool:
	var pickup_world_node = get_world_node()
	if pickup_world_node == null or not is_world_node_active():
		return false
	if not pickup_world_node.has_method("apply_network_inventory_delta"):
		return false

	var delta_entries: Array = []
	var raw_rewards: Variant = data.get("rewards", [])
	if raw_rewards is Array:
		for raw_reward in raw_rewards:
			if raw_reward is Dictionary:
				_append_pickup_inventory_delta_from_payload(delta_entries, raw_reward)

	var raw_results: Variant = data.get("pickup_results", [])
	if raw_results is Array:
		for raw_result in raw_results:
			if not (raw_result is Dictionary):
				continue
			var result: Dictionary = raw_result
			if not bool(result.get("ok", false)):
				continue
			_append_pickup_inventory_delta_from_payload(delta_entries, result)

	if delta_entries.is_empty():
		_append_pickup_inventory_delta_from_payload(delta_entries, data)

	var applied_count: int = 0
	for raw_delta in delta_entries:
		if raw_delta is Dictionary and bool(pickup_world_node.apply_network_inventory_delta(raw_delta)):
			applied_count += 1
	if applied_count > 0:
		persist_authoritative_player_state_locally(pickup_world_node)
	return applied_count > 0


func _apply_drop_pickup_transaction_world_result(data: Dictionary, inventory_update_applied: bool) -> bool:
	var pickup_result_world_node = get_world_node()
	if pickup_result_world_node == null or not is_world_node_active():
		return false

	var raw_drop_ids: Variant = data.get("drop_ids", [])
	var raw_removed_ids: Variant = data.get("removed_drop_ids", [])
	var raw_updated_drops: Variant = data.get("updated_drops", [])
	var raw_pickup_results: Variant = data.get("pickup_results", [])
	var is_bulk_pickup_result: bool = bool(data.get("bulk_pickup", false))
	if raw_drop_ids is Array and raw_drop_ids.size() > 1:
		is_bulk_pickup_result = true
	if raw_removed_ids is Array and raw_removed_ids.size() > 0:
		is_bulk_pickup_result = true
	if raw_updated_drops is Array and raw_updated_drops.size() > 0:
		is_bulk_pickup_result = true
	if raw_pickup_results is Array and raw_pickup_results.size() > 0:
		is_bulk_pickup_result = true

	if is_bulk_pickup_result:
		var bulk_payload: Dictionary = _build_bulk_pickup_world_result_from_transaction(data, inventory_update_applied)
		if pickup_result_world_node.has_method("apply_network_item_drop_remove"):
			pickup_result_world_node.apply_network_item_drop_remove(bulk_payload)
			return true
		return false

	var pickup_result_drop_id: String = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
	if pickup_result_drop_id == "":
		return false

	var pickup_payload: Dictionary = data.duplicate(true)
	pickup_payload["type"] = "world_item_drop_pickup"
	pickup_payload["_server_inventory_update_applied"] = inventory_update_applied
	pickup_payload["_apply_pickup_inventory"] = not inventory_update_applied
	var has_explicit_remaining: bool = false
	for remaining_key in ["remaining_amount", "remaining", "drop_amount_remaining", "new_amount", "remaining_amount_after_pickup"]:
		if pickup_payload.has(remaining_key):
			has_explicit_remaining = true
			break
	if not has_explicit_remaining and pickup_payload.has("amount"):
		# inventory_transaction_result.amount is the picked amount, not the remaining world amount.
		pickup_payload.erase("amount")
	var remaining_amount: float = _safe_pickup_remaining_amount(pickup_payload)
	if remaining_amount == PICKUP_REMAINING_AMOUNT_UNKNOWN and not has_explicit_remaining:
		remaining_amount = 0
	if remaining_amount == 0:
		if pickup_result_world_node.has_method("apply_network_item_drop_remove"):
			pickup_result_world_node.apply_network_item_drop_remove(pickup_payload)
			return true
	elif remaining_amount != PICKUP_REMAINING_AMOUNT_UNKNOWN:
		pickup_payload["amount"] = remaining_amount
		if pickup_result_world_node.has_method("apply_network_item_drop_update"):
			pickup_result_world_node.apply_network_item_drop_update(pickup_payload)
			return true
	elif pickup_result_world_node.has_method("cancel_pending_pickup_for_drop"):
		pickup_result_world_node.cancel_pending_pickup_for_drop(pickup_result_drop_id)
		return true
	return false


func handle_account_auth_ok(data: Dictionary) -> void:
	var username = _safe_string(data.get("username", ""), "", MAX_USERNAME_LENGTH)
	var email = _safe_string(data.get("email", ""), "", 256)
	var token = _safe_string(data.get("session_token", session_token), "", 512)
	var refresh_token = _safe_string(data.get("refresh_token", ""), "", 512)
	var role = _safe_string(data.get("role", "player"), "player", MAX_ITEM_ID_LENGTH).to_lower()
	if username != "" and token != "":
		account_id = _safe_string(data.get("account_id", ""), "", MAX_REQUEST_ID_LENGTH)
		profile_id = _safe_string(data.get("profile_id", data.get("postgres_player_id", "")), "", MAX_REQUEST_ID_LENGTH)
		game_player_id = _safe_string(data.get("game_player_id", data.get("websocket_player_id", player_id)), player_id, MAX_REQUEST_ID_LENGTH)
		session_username = username
		session_email = email
		session_token = token
		session_role = role if role != "" else "player"
		session_authenticated = true
		server_session_authenticated = true
		pending_saved_refresh_token = ""
		saved_refresh_login_in_flight = false
		developer_pin_required = bool(data.get("developer_pin_required", false))
		developer_pin_unlocked = bool(data.get("developer_pin_unlocked", not developer_pin_required))
		player_name = username
		_persist_remembered_session_tokens(username, email, token, refresh_token, session_role)
		send_account_state_save(session_username, session_email, session_token)
		var world_node = get_world_node()
		if world_node != null and world_node.has_method("request_network_player_state"):
			world_node.request_network_player_state()
		_seed_netfox_real_launch_pending_join(username)
		if has_pending_join():
			send_join_world_if_needed(pending_join_world_name)
		elif world_node != null and is_world_node_active():
			var active_world_name = current_world_name
			if "current_world_name" in world_node:
				active_world_name = _safe_world_name(world_node.get("current_world_name"))
			if active_world_name == "":
				active_world_name = current_world_name
			send_join_world_if_needed(active_world_name)
	server_auth_finished.emit(data)


func _persist_remembered_session_tokens(username: String, email: String, token: String, refresh_token: String, role: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) != OK:
		return
	var remember_login := bool(cfg.get_value("profile", "remember_login", cfg.get_value("profile", "remember_password", false)))
	if not remember_login:
		return
	cfg.set_value("profile", "username", username)
	cfg.set_value("profile", "email", email)
	cfg.set_value("profile", "session_token", token)
	if refresh_token != "":
		cfg.set_value("profile", "refresh_token", refresh_token)
	cfg.set_value("profile", "role", role)
	cfg.set_value("profile", "remember_login", true)
	cfg.set_value("profile", "remember_password", false)
	cfg.set_value("profile", "saved_password", "")
	cfg.set_value("profile", "password", "")
	cfg.save(profile_path)


func _auth_error_invalidates_saved_login(data: Dictionary) -> bool:
	var reason := _safe_string(data.get("reason", ""), "", MAX_ITEM_ID_LENGTH).to_lower()
	return ["missing_token", "invalid_or_expired", "invalid_refresh_token", "invalid_account_state"].has(reason)


func _seed_netfox_real_launch_pending_join(username: String) -> void:
	if pending_join_enabled:
		return
	if not MovementMode.is_netfox_real():
		return
	if not MovementMode.has_method("is_netfox_real_client_launch") or not MovementMode.is_netfox_real_client_launch():
		return
	if MovementMode.get_launch_arg_value("--world", "").strip_edges() == "":
		return

	var launch_world := MovementMode.get_dev_test_world_name("NETFOX_TEST")
	set_pending_join(launch_world, username)
	current_world_name = _safe_world_name(launch_world)
	print("[NetfoxReal] Queued launch world join after auth: world=%s username=%s" % [current_world_name, username])


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
	# Every other path queues through queue_player_state_payload_if_present(),
	# which stamps this flag. A raw server message has no such key, and
	# save_manager reads it as `data.get("preserve_local_loadout", false)` - so
	# without this the server's copy of the loadout overwrites whatever the player
	# just equipped, and restore_local_transaction_loadout() never runs. That is
	# what made a freshly equipped item flip back to the previous one for the
	# length of a server round trip.
	pending_server_player_state["preserve_local_loadout"] = true
	apply_pending_server_player_state_if_ready()


func handle_iap_checkout_session_result(data: Dictionary) -> void:
	iap_checkout_session_result.emit(data)


func handle_iap_purchase_result(data: Dictionary) -> void:
	iap_purchase_result.emit(data)


func handle_inventory_transaction_result(data: Dictionary) -> void:
	var action = str(data.get("action", "")).strip_edges().to_lower()
	if action == "world_lock_get_key":
		var player_data_debug = data.get("player_data", {})
		print("[WorldLockKey][Network] result ", {
			"ok": bool(data.get("ok", false)),
			"message": str(data.get("message", "")),
			"has_player_data": player_data_debug is Dictionary and not player_data_debug.is_empty(),
			"inventory_delta": data.get("inventory_delta", {}),
			"inventory_deltas": data.get("inventory_deltas", [])
		})
	if _is_drop_pickup_result_action(action):
		var trace_world_node = get_world_node()
		if trace_world_node != null and is_world_node_active() and "drop_manager" in trace_world_node:
			var trace_drop_manager = trace_world_node.drop_manager
			if trace_drop_manager != null and trace_drop_manager.has_method("trace_drop_pickup_event"):
				trace_drop_manager.trace_drop_pickup_event("inventory_transaction_result", data, {})
	if action == "drop_pickup" or action == "world_block_break":
		var player_data_debug = data.get("player_data", null)
		var inventory_delta_debug = data.get("inventory_delta", data.get("inventory_deltas", null))
		debug_action_position_flow("received inventory transaction result", {
			"action": action,
			"ok": bool(data.get("ok", false)),
			"has_player_data": player_data_debug is Dictionary and not player_data_debug.is_empty(),
			"has_inventory_delta": (inventory_delta_debug is Dictionary and not inventory_delta_debug.is_empty()) or (inventory_delta_debug is Array and inventory_delta_debug.size() > 0)
		})
	if bool(data.get("ok", false)):
		var inventory_delta_applied = apply_inventory_delta_payload_if_present(data)
		if not inventory_delta_applied and _is_drop_pickup_result_action(action):
			inventory_delta_applied = apply_pickup_reward_inventory_fallback(data)
		var player_state_applied = false
		if not inventory_delta_applied:
			player_state_applied = apply_player_state_payload_if_present(data)
		if not player_state_applied:
			apply_progression_payload_if_present(data)
		if _is_drop_pickup_result_action(action):
			var inventory_update_applied: bool = player_state_applied or inventory_delta_applied
			_apply_drop_pickup_transaction_world_result(data, inventory_update_applied)
	elif action == "drop_pickup" or action == "world_item_drop_pickup" or action == "world_drop_pickup":
		var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
		var pickup_world_node = get_world_node()
		if pickup_world_node != null and is_world_node_active():
			if pickup_world_node.has_method("handle_rejected_drop_pickup"):
				if bool(pickup_world_node.handle_rejected_drop_pickup(drop_id, str(data.get("message", "")), data)):
					return
			elif pickup_world_node.has_method("cancel_pending_pickup_for_drop"):
				pickup_world_node.cancel_pending_pickup_for_drop(drop_id)
	var world_node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("handle_inventory_transaction_result"):
		world_node.handle_inventory_transaction_result(data)


func _should_suppress_pickup_action_rejection_message(action: String, message: String, details: Dictionary = {}) -> bool:
	var clean_action := str(action).strip_edges().to_lower()
	var clean_message := str(message).strip_edges().to_lower()
	if clean_message.find("slow down") < 0:
		return false
	if clean_action == "pickup_attempt" or clean_action == "world_item_drop_pickup" or clean_action == "world_drop_pickup" or clean_action == "drop_pickup":
		return true

	var clean_source_type := str(details.get("source_type", "")).strip_edges().to_lower()
	if clean_source_type == "item_pickup":
		return true

	var has_drop_id := str(details.get("drop_id", details.get("requested_by", ""))).strip_edges() != ""
	if has_drop_id:
		return true

	var has_pickup_context := clean_action == "" and str(details.get("type", "")).strip_edges().to_lower() in ["rate_limited", "world_item_drop_pickup", "world_drop_pickup", "drop_pickup"]
	return has_pickup_context


func handle_fishing_reward_fx(data: Dictionary) -> void:
	var world_node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("handle_network_fishing_reward_fx"):
		world_node.handle_network_fishing_reward_fx(data)


func handle_action_rejected(data: Dictionary) -> void:
	var message = str(data.get("message", "Server rejected that action."))
	debug_action_position_flow("action rejected", {
		"action": str(data.get("action", "")),
		"message": message
	})
	debug_netfox_identity("backend action rejected", {
		"action": str(data.get("action", "")),
		"message": message,
		"allow_reject_reason": str(data.get("reason", "")),
		"resolved_peer_id": int(data.get("peer_id", 0)),
		"trusted_age_ms": int(data.get("age_ms", -1)),
		"target_tile": Vector2i(int(data.get("target_x", 0)), int(data.get("target_y", 0))),
		"world": str(data.get("world", current_world_name))
	})
	var world_node = get_world_node()
	var normalized_action = str(data.get("action", "")).strip_edges().to_lower()
	if normalized_action == "join_world" and not _is_message_for_active_join_request(data):
		debug_action_position_flow("ignored stale join_world rejection", {
			"incoming_join_request_id": _get_message_join_request_id(data),
			"active_join_request_id": active_join_request_id
		})
		return
	if normalized_action == "join_world" and world_node != null and "save_manager" in world_node:
		var save_manager_value: Variant = world_node.get("save_manager")
		if save_manager_value != null and save_manager_value.has_method("handle_server_world_entry_rejected"):
			if bool(save_manager_value.handle_server_world_entry_rejected(data)):
				return
	# We already confirmed above (via _is_message_for_active_join_request) that this rejection is
	# for the join_world request currently in flight -- not a stale one. Previously nothing told
	# the loading overlay about it: it would just sit at its passive progress cap and keep
	# silently resending the same already-rejected request until its own retry/timeout watchdog
	# gave up minutes later (see world_loading_ui_manager.gd's notify_join_world_rejected doc
	# comment). Fail the overlay immediately instead so the player gets an accurate message and a
	# clean return to the lobby right away.
	if normalized_action == "join_world" and world_node != null and "world_loading_ui_manager" in world_node:
		var loading_ui_value: Variant = world_node.get("world_loading_ui_manager")
		if loading_ui_value != null and is_instance_valid(loading_ui_value) and loading_ui_value.has_method("notify_join_world_rejected"):
			if bool(loading_ui_value.notify_join_world_rejected(message, data)):
				return
	if normalized_action == "world_block_update":
		trace_world_block_event("received_action_rejected", data)
	if normalized_action == "player_position" and not MovementMode.is_websocket():
		debug_netfox_identity("ignored legacy movement rejection in trusted movement mode", {
			"message": message,
			"position_correction": bool(data.get("position_correction", false)),
			"movement_mode": MovementMode.get_mode_name()
		})
		return
	if normalized_action == "player_position" and apply_player_position_correction(data):
		return
	var is_pickup_rejection := normalized_action == "world_item_drop_pickup" or normalized_action == "world_drop_pickup" or normalized_action == "drop_pickup" or normalized_action == "pickup_attempt"
	if is_pickup_rejection:
		var drop_id = _safe_string(data.get("drop_id", data.get("id", "")), "", MAX_DROP_ID_LENGTH)
		if world_node != null and is_world_node_active():
			if world_node.has_method("handle_rejected_drop_pickup"):
				if bool(world_node.handle_rejected_drop_pickup(drop_id, message, data)):
					return
			elif world_node.has_method("cancel_pending_pickup_for_drop"):
				world_node.cancel_pending_pickup_for_drop(drop_id)
		if _should_suppress_pickup_action_rejection_message(normalized_action, message, data):
			return
	elif _should_suppress_pickup_action_rejection_message(normalized_action, message, data):
		return
	if normalized_action == "world_block_update" and world_node != null and is_world_node_active():
		if world_node.block_manager != null and world_node.block_manager.has_method("handle_rejected_block_update"):
			if bool(world_node.block_manager.handle_rejected_block_update(data)):
				return
	if world_node != null and is_world_node_active() and world_node.has_method("show_notification"):
		world_node.show_notification(message)
	else:
		var chat_ui = get_chat_ui_node()
		if chat_ui != null:
			chat_ui.add_chat_message("System", message)
	var action = normalized_action
	if action.begins_with("world_") and has_active_session() and not _is_player_state_lookup_related_action(action):
		send_player_state_request(session_username)


func apply_player_position_correction(data: Dictionary) -> bool:
	if not MovementMode.is_websocket():
		return false

	if not bool(data.get("position_correction", false)):
		return false

	var accepted_sequence := _safe_int(data.get("accepted_sequence", 0), 0, 0, 2147483647)
	var rejected_sequence := _safe_int(data.get("rejected_sequence", 0), 0, 0, 2147483647)

	if accepted_sequence > 0:
		if last_accepted_position_sequence > 0 and accepted_sequence < last_accepted_position_sequence:
			return false
	if rejected_sequence > 0 and last_rejected_position_sequence > 0 and rejected_sequence <= last_rejected_position_sequence:
		return false

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return false
	if not world_node.has_method("apply_server_player_position_correction"):
		return false

	world_node.apply_server_player_position_correction(data)
	if accepted_sequence > 0:
		last_accepted_position_sequence = accepted_sequence
	if rejected_sequence > 0:
		last_rejected_position_sequence = rejected_sequence
	return true


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
	if not MovementMode.is_websocket():
		return

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


func handle_world_event_started(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var world_node: Node = get_world_node()
	if world_node != null and world_node.has_method("handle_world_event_started"):
		world_node.handle_world_event_started(data)


func handle_world_event_ended(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var world_node: Node = get_world_node()
	if world_node != null and world_node.has_method("handle_world_event_ended"):
		world_node.handle_world_event_ended(data)

	var event_type: String = _safe_string(data.get("event_type", data.get("event_name", "")), "", MAX_ITEM_ID_LENGTH).to_lower()
	if event_type == "snow_storm":
		show_system_notification("Snow Storm ended.")


func handle_world_event_system_message(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var message: String = _safe_string(data.get("message", ""), "", MAX_BROADCAST_LENGTH)
	if message == "":
		return

	show_system_notification(message)


func handle_world_event_tile_updates(data: Dictionary) -> void:
	if not is_message_for_active_world(data):
		return

	var updates = data.get("updates", [])
	if not (updates is Array) or updates.is_empty():
		return

	var batch_world: String = _get_message_world_name(data)
	if batch_world == "":
		batch_world = _safe_world_name(current_world_name)

	compact_world_event_tile_update_queue()

	for raw_update in updates:
		if not (raw_update is Dictionary):
			continue
		var update_payload: Dictionary = raw_update.duplicate(true)
		update_payload["type"] = "world_block_update"
		update_payload["_from_world_event"] = true
		if not update_payload.has("world") or _safe_world_name(update_payload.get("world", "")) == "":
			update_payload["world"] = batch_world
		if not update_payload.has("layer"):
			update_payload["layer"] = "foreground"
		world_event_tile_update_queue.append(update_payload)


func queue_world_block_update_behind_pending_event_updates(data: Dictionary) -> bool:
	if world_event_tile_update_queue_read_index >= world_event_tile_update_queue.size():
		return false

	compact_world_event_tile_update_queue()
	world_event_tile_update_queue.append(data.duplicate(true))
	return true


func process_world_event_tile_update_queue() -> void:
	if world_event_tile_update_queue_read_index >= world_event_tile_update_queue.size():
		clear_world_event_tile_update_queue()
		return
	if is_world_state_apply_in_progress():
		return

	var world_node: Node = get_world_node()
	if world_node == null or not is_world_node_active() or not world_node.has_method("apply_network_block_update"):
		clear_world_event_tile_update_queue()
		return

	var processed := 0
	var processed_world_event_update := false
	var started_usec := Time.get_ticks_usec()
	while (
		processed < MAX_WORLD_EVENT_TILE_UPDATES_PER_FRAME
		and world_event_tile_update_queue_read_index < world_event_tile_update_queue.size()
	):
		var update_payload: Dictionary = world_event_tile_update_queue[world_event_tile_update_queue_read_index]
		world_event_tile_update_queue_read_index += 1
		processed_world_event_update = processed_world_event_update or bool(update_payload.get("_from_world_event", false))
		world_node.apply_network_block_update(update_payload)
		processed += 1
		if Time.get_ticks_usec() - started_usec >= MAX_WORLD_EVENT_TILE_UPDATE_PROCESS_USEC:
			break

	if processed_world_event_update:
		if MovementMode.is_netfox_real():
			var netfox_manager: Variant = world_node.get("netfox_real_manager")
			if netfox_manager != null and netfox_manager.has_method("notify_world_collision_changed"):
				netfox_manager.notify_world_collision_changed("world-event-tile-batch")

	if world_event_tile_update_queue_read_index >= world_event_tile_update_queue.size():
		clear_world_event_tile_update_queue()


func compact_world_event_tile_update_queue() -> void:
	if world_event_tile_update_queue_read_index <= 0:
		return
	if world_event_tile_update_queue_read_index < 1024 and world_event_tile_update_queue_read_index < world_event_tile_update_queue.size():
		return

	var pending_updates: Array[Dictionary] = []
	for update_index in range(world_event_tile_update_queue_read_index, world_event_tile_update_queue.size()):
		pending_updates.append(world_event_tile_update_queue[update_index])
	world_event_tile_update_queue = pending_updates
	world_event_tile_update_queue_read_index = 0


func clear_world_event_tile_update_queue() -> void:
	world_event_tile_update_queue.clear()
	world_event_tile_update_queue_read_index = 0


func show_system_notification(message: String) -> void:
	var clean_message: String = _safe_string(message, "", MAX_BROADCAST_LENGTH)
	if clean_message == "":
		return

	var world_node: Node = get_world_node()
	if world_node != null and is_world_node_active() and world_node.has_method("show_notification"):
		world_node.show_notification(clean_message)
		return

	var chat_ui: Node = get_chat_ui_node()
	if chat_ui != null:
		chat_ui.add_chat_message("System", clean_message)


func is_message_for_active_world(data: Dictionary) -> bool:
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world == "":
		return true

	var network_world: String = _safe_world_name(current_world_name)
	var node_world := ""
	var world_node: Node = get_world_node()
	if world_node != null and "current_world_name" in world_node:
		node_world = _safe_world_name(world_node.get("current_world_name"))

	if network_world != "" and node_world != "" and network_world != node_world:
		return incoming_world == network_world
	if network_world != "" and incoming_world == network_world:
		return true
	if node_world != "" and incoming_world == node_world:
		return true

	return network_world == "" and node_world == ""


func _get_message_join_request_id(data: Dictionary) -> String:
	return _safe_string(data.get("join_request_id", ""), "", MAX_REQUEST_ID_LENGTH)


func _get_message_world_entry_session_id(data: Dictionary) -> String:
	return _safe_string(data.get("world_entry_session_id", ""), "", MAX_WORLD_ENTRY_SESSION_ID_LENGTH)


func _queue_pending_world_entry_block_update_if_needed(data: Dictionary) -> bool:
	if not world_entry_requires_ready or world_entry_active or active_world_entry_session_id == "":
		return false
	var packet_world: String = _get_message_world_name(data)
	if packet_world != "" and packet_world != active_join_world_name:
		return false
	pending_world_entry_block_updates.append(data.duplicate(true))
	return true


func _note_pending_world_entry_block_update(data: Dictionary) -> void:
	if not world_entry_requires_ready or world_entry_active:
		return
	var block_revision: int = _safe_int(data.get("block_revision", 0), 0, 0)
	if block_revision > active_world_entry_block_revision:
		active_world_entry_block_revision = block_revision
	var world_revision: int = _safe_int(data.get("world_revision", 0), 0, 0)
	if world_revision > active_world_entry_revision:
		active_world_entry_revision = world_revision


func process_pending_world_entry_block_updates(max_items: int = -1) -> int:
	if pending_world_entry_block_updates.is_empty():
		return 0
	if is_world_state_apply_in_progress() or not pending_server_world_state.is_empty() or not pending_world_state_stream.is_empty():
		return 0
	var world_node: Node = get_world_node()
	if world_node == null or not is_instance_valid(world_node) or not is_world_node_active():
		return 0
	if not world_node.has_method("apply_network_block_update"):
		return 0

	var processed := 0
	while not pending_world_entry_block_updates.is_empty() and (max_items < 0 or processed < max_items):
		var update: Dictionary = pending_world_entry_block_updates.pop_front()
		world_node.apply_network_block_update(update)
		_note_pending_world_entry_block_update(update)
		processed += 1
	if processed > 0 and not pending_world_entry_ready.is_empty():
		pending_world_entry_ready["world_revision"] = active_world_entry_revision
		pending_world_entry_ready["block_revision"] = active_world_entry_block_revision
	return processed


func _reset_world_entry_session() -> void:
	active_world_entry_session_id = ""
	active_world_entry_revision = 0
	active_world_entry_block_revision = 0
	world_entry_requires_ready = false
	world_entry_ready_sent = false
	world_entry_active = false
	pending_world_entry_ready.clear()
	pending_world_entry_block_updates.clear()
	world_entry_ready_retry_at_msec = 0


func _accept_world_entry_session_from_join_ack(data: Dictionary) -> bool:
	var requires_ready: bool = bool(data.get("world_entry_requires_ready", false))
	var incoming_session_id: String = _get_message_world_entry_session_id(data)
	if requires_ready and incoming_session_id == "":
		return false
	if not requires_ready:
		_reset_world_entry_session()
		return true
	active_world_entry_session_id = incoming_session_id
	active_world_entry_revision = 0
	active_world_entry_block_revision = 0
	world_entry_requires_ready = true
	world_entry_ready_sent = false
	world_entry_active = false
	pending_world_entry_ready.clear()
	pending_world_entry_block_updates.clear()
	world_entry_ready_retry_at_msec = 0
	return true


func _is_message_for_active_world_entry_session(data: Dictionary) -> bool:
	var incoming_session_id: String = _get_message_world_entry_session_id(data)
	if incoming_session_id == "":
		if not world_entry_requires_ready and active_world_entry_session_id == "":
			return true
		log_world_entry_drop("entry_session_missing_on_packet", data)
		return false
	if active_world_entry_session_id == "":
		log_world_entry_drop("no_active_entry_session", data)
		return false
	if incoming_session_id == active_world_entry_session_id:
		return true
	log_world_entry_drop("entry_session_mismatch", data)
	return false


func _accept_world_entry_snapshot_metadata(data: Dictionary) -> bool:
	if not _is_message_for_active_world_entry_session(data):
		return false
	if not world_entry_requires_ready:
		return true
	var incoming_revision: int = _safe_int(data.get("world_revision", 0), 0, 0)
	var incoming_block_revision: int = _safe_int(data.get("block_revision", 0), 0, 0)
	var duplicate_active_snapshot: bool = (
		incoming_revision == active_world_entry_revision
		and incoming_block_revision == active_world_entry_block_revision
		and (
			world_entry_ready_sent
			or world_entry_active
			or not pending_world_entry_ready.is_empty()
		)
	)
	if duplicate_active_snapshot:
		return true
	pending_world_entry_block_updates.clear()
	active_world_entry_revision = incoming_revision
	active_world_entry_block_revision = incoming_block_revision
	world_entry_ready_sent = false
	world_entry_active = false
	pending_world_entry_ready.clear()
	world_entry_ready_retry_at_msec = 0
	return true


func notify_world_entry_spawn_ready(data: Dictionary) -> bool:
	if not world_entry_requires_ready:
		return false
	if world_entry_active or active_world_entry_session_id == "":
		return false
	if not _is_message_for_active_join_request(data):
		return false
	if not _is_message_for_active_world_entry_session(data):
		return false
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world == "" or incoming_world != active_join_world_name:
		return false
	var incoming_revision: int = _safe_int(data.get("world_revision", 0), 0, 0)
	var incoming_block_revision: int = _safe_int(data.get("block_revision", 0), 0, 0)
	process_pending_world_entry_block_updates()
	if incoming_revision > active_world_entry_revision or incoming_block_revision > active_world_entry_block_revision:
		return false
	pending_world_entry_ready = attach_session_auth({
		"type": "world_entry_ready",
		"world": incoming_world,
		"join_request_id": active_join_request_id,
		"world_entry_session_id": active_world_entry_session_id,
		"world_revision": active_world_entry_revision,
		"block_revision": active_world_entry_block_revision
	})
	return _send_pending_world_entry_ready()


func _send_pending_world_entry_ready() -> bool:
	if pending_world_entry_ready.is_empty() or world_entry_active:
		return false
	pending_world_entry_ready["world_revision"] = active_world_entry_revision
	pending_world_entry_ready["block_revision"] = active_world_entry_block_revision
	var sent: bool = send_message(pending_world_entry_ready)
	if sent:
		world_entry_ready_sent = true
		world_entry_ready_retry_at_msec = Time.get_ticks_msec() + WORLD_ENTRY_READY_RETRY_MS
		print("[world-entry-client] sent world_entry_ready " + JSON.stringify({
			"world": active_join_world_name,
			"join_request_id": active_join_request_id,
			"world_entry_session_id": active_world_entry_session_id,
			"world_revision": active_world_entry_revision,
			"block_revision": active_world_entry_block_revision
		}))
		record_world_entry_stage("client_spawn_safe_ready_sent", {
			"world_revision": active_world_entry_revision,
			"block_revision": active_world_entry_block_revision
		})
	return sent


func process_pending_world_entry_ready_retry() -> void:
	if pending_world_entry_ready.is_empty() or world_entry_active:
		return
	process_pending_world_entry_block_updates()

	# Do NOT re-send world_entry_ready while a world-state apply is still in flight.
	#
	# The server treats every world_entry_ready whose block_revision has not advanced since the
	# last one as a failed "catchup" attempt, and after
	# WORLD_ENTRY_CATCHUP_MAX_NO_PROGRESS_ATTEMPTS of them it gives up and restarts the entire
	# snapshot (see the catchupStalled branch in handleWorldEntryReady).
	#
	# But while a world-state apply is running, this client CANNOT advance its block revision:
	# process_pending_world_entry_block_updates() above returns 0 on exactly these conditions,
	# and process_server_packets_with_budget() stops dispatching packets for the duration too.
	# So every retry sent during the build carries an identical, unchanged block_revision and is
	# guaranteed to be counted as no-progress.
	#
	# On a large or actively-changing world the build takes seconds, which is long enough to burn
	# the server's entire catchup allowance BEFORE the build has even finished -- the snapshot is
	# then thrown away and rebuilt from scratch, which takes longer still, which makes the next
	# restart more likely. A measured LANDFILL join hit 23.2s this way, versus ~1.5s for a world
	# that never tripped it.
	#
	# Staying quiet until the apply completes costs nothing: the retry below is only useful once
	# there is new information to report, and _send_pending_world_entry_ready() is still called
	# the moment the apply finishes and the queued block updates have been drained.
	if is_world_state_apply_in_progress() or not pending_server_world_state.is_empty() or not pending_world_state_stream.is_empty():
		return

	if Time.get_ticks_msec() < world_entry_ready_retry_at_msec:
		return
	_send_pending_world_entry_ready()


func _request_world_entry_snapshot_restart(reason: String) -> bool:
	if not world_entry_requires_ready or active_world_entry_session_id == "":
		return false
	var restart_payload: Dictionary = attach_session_auth({
		"type": "world_entry_ready",
		"world": active_join_world_name,
		"join_request_id": active_join_request_id,
		"world_entry_session_id": active_world_entry_session_id,
		# Deliberately differ from the accepted snapshot revision. The server keeps
		# the same admission/session and responds with a fresh authoritative stream.
		"world_revision": active_world_entry_revision + 1,
		"block_revision": active_world_entry_block_revision
	})
	debug_action_position_flow("requested current-session world snapshot restart", {
		"world": active_join_world_name,
		"world_entry_session_id": active_world_entry_session_id,
		"reason": reason
	})
	print("[world-entry-client] requested world_entry_snapshot_restart " + JSON.stringify({
		"world": active_join_world_name,
		"join_request_id": active_join_request_id,
		"world_entry_session_id": active_world_entry_session_id,
		"reason": reason,
		"world_revision": active_world_entry_revision + 1,
		"block_revision": active_world_entry_block_revision
	}))
	return send_message(restart_payload)


func request_current_world_entry_snapshot_restart(reason: String = "client_snapshot_restart") -> bool:
	return _request_world_entry_snapshot_restart(reason)


func _handle_world_entry_snapshot_restart(data: Dictionary) -> void:
	if not world_entry_requires_ready or world_entry_active:
		return
	if not _is_message_for_active_join_request(data):
		return
	if not _is_message_for_active_world_entry_session(data):
		return
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world == "" or incoming_world != active_join_world_name:
		return

	pending_world_state_stream.clear()
	pending_server_world_state.clear()
	pending_world_entry_ready.clear()
	pending_world_entry_block_updates.clear()
	world_entry_ready_sent = false
	world_entry_ready_retry_at_msec = 0
	active_world_entry_revision = _safe_int(data.get("world_revision", 0), 0, 0)
	active_world_entry_block_revision = _safe_int(data.get("block_revision", 0), 0, 0)
	record_world_entry_stage("client_snapshot_restart_requested", {
		"reason": str(data.get("reason", "world_revision_advanced_during_load")),
		"world_revision": active_world_entry_revision,
		"block_revision": active_world_entry_block_revision
	})
	var world_node: Node = get_world_node()
	if world_node != null and world_node.has_method("update_smooth_world_load_message"):
		world_node.update_smooth_world_load_message("World changed while loading. Refreshing...")


func _handle_world_entry_catchup_wait(data: Dictionary) -> void:
	if not world_entry_requires_ready or world_entry_active:
		return
	if not _is_message_for_active_join_request(data):
		return
	if not _is_message_for_active_world_entry_session(data):
		return
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world == "" or incoming_world != active_join_world_name:
		return

	process_pending_world_entry_block_updates()
	var target_revision: int = _safe_int(
		data.get("world_revision", active_world_entry_revision),
		active_world_entry_revision,
		0
	)
	var target_block_revision: int = _safe_int(
		data.get("block_revision", active_world_entry_block_revision),
		active_world_entry_block_revision,
		0
	)
	if target_revision > active_world_entry_revision:
		active_world_entry_revision = target_revision
	var retry_delay_msec: int = _safe_int(data.get("retry_after_msec", 100), 100, 25, 1000)
	world_entry_ready_retry_at_msec = Time.get_ticks_msec() + retry_delay_msec
	var world_node: Node = get_world_node()
	if world_node != null and world_node.has_method("update_smooth_world_load_message"):
		world_node.update_smooth_world_load_message("Applying latest world changes...")
	if active_world_entry_block_revision >= target_block_revision:
		_send_pending_world_entry_ready()


func _describe_world_entry_active_packet(data: Dictionary, reason: String) -> Dictionary:
	return {
		"reason": reason,
		"incoming_world": _get_message_world_name(data),
		"incoming_join_request_id": _get_message_join_request_id(data),
		"incoming_session_id": _get_message_world_entry_session_id(data),
		"incoming_world_revision": _safe_int(data.get("world_revision", 0), 0, 0),
		"incoming_block_revision": _safe_int(data.get("block_revision", 0), 0, 0),
		"incoming_controls_unlocked": bool(data.get("controls_unlocked", false)),
		"requires_ready": world_entry_requires_ready,
		"entry_active": world_entry_active,
		"active_join_pending": active_join_request_pending,
		"active_join_request_id": active_join_request_id,
		"active_join_world": active_join_world_name,
		"active_session_id": active_world_entry_session_id,
		"active_world_revision": active_world_entry_revision,
		"active_block_revision": active_world_entry_block_revision,
		"pending_ready": not pending_world_entry_ready.is_empty(),
		"pending_snapshot": not pending_server_world_state.is_empty(),
		"pending_stream": not pending_world_state_stream.is_empty(),
		"current_world": current_world_name,
		"connected": connected,
		"authenticated": server_session_authenticated
	}


func _log_ignored_world_entry_active(data: Dictionary, reason: String) -> void:
	var details := _describe_world_entry_active_packet(data, reason)
	print("[world-entry-client] ignored world_entry_active " + JSON.stringify(details))
	record_world_entry_stage("client_world_entry_active_ignored", details)


func _handle_world_entry_active(data: Dictionary) -> void:
	if not world_entry_requires_ready:
		_log_ignored_world_entry_active(data, "not_waiting_for_ready")
		return
	if not _is_message_for_active_join_request(data):
		_log_ignored_world_entry_active(data, "join_request_mismatch")
		return
	if not _is_message_for_active_world_entry_session(data):
		_log_ignored_world_entry_active(data, "session_mismatch")
		return
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world == "" or incoming_world != active_join_world_name:
		_log_ignored_world_entry_active(data, "world_mismatch")
		return
	if world_entry_active:
		_log_ignored_world_entry_active(data, "already_active")
		return
	process_pending_world_entry_block_updates()
	var incoming_revision: int = _safe_int(data.get("world_revision", 0), 0, 0)
	var incoming_block_revision: int = _safe_int(data.get("block_revision", 0), 0, 0)
	if incoming_revision < active_world_entry_revision or incoming_block_revision != active_world_entry_block_revision:
		_log_ignored_world_entry_active(data, "revision_mismatch")
		_request_world_entry_snapshot_restart("active_revision_mismatch")
		return
	if not bool(data.get("controls_unlocked", false)):
		_log_ignored_world_entry_active(data, "controls_locked")
		return

	print("[world-entry-client] accepted world_entry_active " + JSON.stringify(
		_describe_world_entry_active_packet(data, "accepted")
	))
	active_world_entry_revision = incoming_revision
	active_world_entry_block_revision = incoming_block_revision
	world_entry_active = true
	mark_active_join_request_complete()
	persist_completed_world_join(incoming_world, session_username)
	pending_world_entry_ready.clear()
	pending_world_entry_block_updates.clear()
	world_entry_ready_retry_at_msec = 0
	record_world_entry_stage("client_world_entry_activated", {
		"world_revision": incoming_revision,
		"block_revision": incoming_block_revision
	})
	var world_node: Node = get_world_node()
	if world_node != null and is_instance_valid(world_node):
		var save_manager_value: Variant = world_node.get("save_manager") if "save_manager" in world_node else null
		if save_manager_value != null and save_manager_value.has_method("finish_world_entry_after_load"):
			save_manager_value.finish_world_entry_after_load(false, true, true, true)
		elif world_node.has_method("finish_smooth_world_load"):
			world_node.finish_smooth_world_load()
	# Do NOT complete the profile here. finish_world_entry_after_load only schedules
	# the reveal (call_deferred) and returns immediately, so completing at this point
	# stamped "client_controls_enabled" up to a second before the player could
	# actually move -- and, because completion deactivates the profile, it silently
	# discarded every later stage the loading overlay emits. The overlay completes the
	# profile for real in _finalize_loading_operation; the watchdog below covers the
	# case where the overlay path never runs.
	world_entry_profile["pending_controls_extra"] = {
		"world_revision": incoming_revision,
		"block_revision": incoming_block_revision,
		"entry_session_confirmed": true
	}
	world_entry_profile["activated_at_msec"] = Time.get_ticks_msec()


func _handle_world_entry_rejected_message(data: Dictionary) -> void:
	if not _is_message_for_active_join_request(data):
		return
	var incoming_session_id: String = _get_message_world_entry_session_id(data)
	if incoming_session_id != "" and active_world_entry_session_id != "" and incoming_session_id != active_world_entry_session_id:
		return
	cancel_world_entry_profile(str(data.get("reason", "world_entry_rejected")))
	active_join_request_pending = false
	var world_node: Node = get_world_node()
	if world_node == null or not is_instance_valid(world_node):
		return
	var save_manager_value: Variant = world_node.get("save_manager") if "save_manager" in world_node else null
	if save_manager_value != null and save_manager_value.has_method("handle_server_world_entry_rejected"):
		save_manager_value.handle_server_world_entry_rejected(data)


func log_world_entry_drop(reason: String, data: Dictionary = {}) -> void:
	# Dropped world-entry packets are abnormal by definition, so they always print.
	# Silent drops in this path have historically parked players at 88% loading with
	# no evidence anywhere; never add a silent return to this pipeline again.
	print("[world-entry-drop] ", reason, " ", JSON.stringify({
		"world": str(data.get("world", "")),
		"type": str(data.get("type", "")),
		"incoming_join_request_id": _get_message_join_request_id(data),
		"active_join_request_id": active_join_request_id,
		"incoming_session": _get_message_world_entry_session_id(data),
		"active_session": active_world_entry_session_id,
		"active_join_world": active_join_world_name
	}))


func _is_message_for_active_join_request(data: Dictionary) -> bool:
	var incoming_request_id: String = _get_message_join_request_id(data)
	if incoming_request_id == "" or active_join_request_id == "":
		return true
	if incoming_request_id == active_join_request_id:
		return true
	log_world_entry_drop("join_request_id_mismatch", data)
	return false


func process_pending_world_state_stream_timeout() -> void:
	if pending_world_state_stream.is_empty():
		return
	var started_at_msec: int = int(pending_world_state_stream.get("started_at_msec", 0))
	if started_at_msec <= 0:
		_fail_pending_world_state_stream("missing_start_time")
		return
	if Time.get_ticks_msec() - started_at_msec > WORLD_STATE_STREAM_TIMEOUT_MS:
		_fail_pending_world_state_stream("timeout")


func _handle_world_state_stream_begin(data: Dictionary, wire_bytes: int = 0) -> void:
	if not _is_message_for_active_world_entry_session(data):
		return
	if int(data.get("stream_version", 0)) != WORLD_STATE_STREAM_VERSION:
		_fail_pending_world_state_stream("unsupported_version", data)
		return
	if not _is_message_for_active_join_request(data):
		return
	var stream_world: String = _get_message_world_name(data)
	if stream_world == "":
		_fail_pending_world_state_stream("missing_world", data)
		return
	if not is_message_for_active_world(data):
		return

	var snapshot_id: String = _safe_string(data.get("snapshot_id", ""), "", MAX_REQUEST_ID_LENGTH)
	var chunk_count: int = int(data.get("chunk_count", -1))
	var section_count: int = int(data.get("section_count", -1))
	var snapshot_bytes: int = int(data.get("snapshot_bytes", 0))
	var metadata_value: Variant = data.get("metadata", {})
	var sections_value: Variant = data.get("sections", [])
	if (
		snapshot_id == ""
		or chunk_count < 0
		or chunk_count > MAX_WORLD_STATE_STREAM_CHUNKS
		or section_count < 0
		or section_count > MAX_WORLD_STATE_STREAM_SECTIONS
		or snapshot_bytes <= 0
		or snapshot_bytes > MAX_WORLD_STATE_STREAM_ASSEMBLED_BYTES
		or not (metadata_value is Dictionary)
		or not (sections_value is Array)
		or sections_value.size() != section_count
	):
		_fail_pending_world_state_stream("invalid_begin", data)
		return

	var metadata: Dictionary = metadata_value
	if str(metadata.get("type", "")) != "world_state":
		_fail_pending_world_state_stream("invalid_metadata_type", data)
		return
	var metadata_world: String = _safe_world_name(str(metadata.get("world", "")))
	if metadata_world != stream_world:
		_fail_pending_world_state_stream("metadata_world_mismatch", data)
		return
	if not _is_message_for_active_join_request(metadata):
		return
	if not _accept_world_entry_snapshot_metadata(metadata):
		return

	var section_descriptors: Array = []
	var section_kinds: Dictionary = {}
	for raw_descriptor in sections_value:
		if not (raw_descriptor is Dictionary):
			_fail_pending_world_state_stream("invalid_section_descriptor", data)
			return
		var descriptor: Dictionary = raw_descriptor
		var section_name: String = _safe_string(descriptor.get("name", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH)
		var section_kind: String = _safe_string(descriptor.get("kind", ""), "", 16)
		if (
			section_name == ""
			or (section_kind != "array" and section_kind != "dictionary")
			or section_kinds.has(section_name)
			or metadata.has(section_name)
		):
			_fail_pending_world_state_stream("invalid_section_descriptor", data)
			return
		section_descriptors.append({
			"name": section_name,
			"kind": section_kind
		})
		section_kinds[section_name] = section_kind

	pending_world_state_stream = {
		"snapshot_id": snapshot_id,
		"world": stream_world,
		"join_request_id": _get_message_join_request_id(data),
		"world_entry_session_id": _get_message_world_entry_session_id(data),
		"chunk_count": chunk_count,
		"snapshot_bytes": snapshot_bytes,
		"metadata": metadata,
		"section_descriptors": section_descriptors,
		"section_kinds": section_kinds,
		"chunks": {},
		"received_count": 0,
		"received_wire_bytes": maxi(0, wire_bytes),
		"started_at_msec": Time.get_ticks_msec()
	}
	update_world_entry_loading_progress(0, chunk_count)
	record_world_entry_stage("client_world_stream_begin", {
		"chunk_count": chunk_count,
		"section_count": section_count,
		"snapshot_bytes": snapshot_bytes
	})


func _handle_world_state_stream_chunk(data: Dictionary, wire_bytes: int = 0) -> void:
	if pending_world_state_stream.is_empty():
		return
	var snapshot_id: String = _safe_string(data.get("snapshot_id", ""), "", MAX_REQUEST_ID_LENGTH)
	var chunk_index: int = int(data.get("chunk_index", -1))
	var chunk_count: int = int(data.get("chunk_count", -1))
	var section_name: String = _safe_string(data.get("section", ""), "", MAX_SERVER_MESSAGE_TYPE_LENGTH)
	var section_kind: String = _safe_string(data.get("section_kind", ""), "", 16)
	var expected_snapshot_id: String = str(pending_world_state_stream.get("snapshot_id", ""))
	var expected_world: String = str(pending_world_state_stream.get("world", ""))
	var expected_join_request_id: String = str(pending_world_state_stream.get("join_request_id", ""))
	var expected_world_entry_session_id: String = str(pending_world_state_stream.get("world_entry_session_id", ""))
	var expected_chunk_count: int = int(pending_world_state_stream.get("chunk_count", -1))
	var section_kinds: Dictionary = pending_world_state_stream.get("section_kinds", {})
	if _get_message_world_entry_session_id(data) != expected_world_entry_session_id:
		return
	if (
		int(data.get("stream_version", 0)) != WORLD_STATE_STREAM_VERSION
		or snapshot_id != expected_snapshot_id
		or _get_message_world_name(data) != expected_world
		or _get_message_join_request_id(data) != expected_join_request_id
		or chunk_count != expected_chunk_count
		or chunk_index < 0
		or chunk_index >= expected_chunk_count
		or not section_kinds.has(section_name)
		or str(section_kinds.get(section_name, "")) != section_kind
	):
		_fail_pending_world_state_stream("invalid_chunk", data)
		return

	var chunk_data: Variant = data.get("data")
	if (
		(section_kind == "array" and not (chunk_data is Array))
		or (section_kind == "dictionary" and not (chunk_data is Dictionary))
	):
		_fail_pending_world_state_stream("invalid_chunk_data", data)
		return

	var chunks: Dictionary = pending_world_state_stream.get("chunks", {})
	if chunks.has(chunk_index):
		return
	var next_wire_bytes: int = int(pending_world_state_stream.get("received_wire_bytes", 0)) + maxi(0, wire_bytes)
	if next_wire_bytes > MAX_WORLD_STATE_STREAM_WIRE_BYTES:
		_fail_pending_world_state_stream("stream_too_large", data)
		return
	chunks[chunk_index] = {
		"section": section_name,
		"section_kind": section_kind,
		"data": chunk_data
	}
	pending_world_state_stream["chunks"] = chunks
	pending_world_state_stream["received_count"] = int(pending_world_state_stream.get("received_count", 0)) + 1
	pending_world_state_stream["received_wire_bytes"] = next_wire_bytes
	update_world_entry_loading_progress(int(pending_world_state_stream.get("received_count", 0)), expected_chunk_count)


func _handle_world_state_stream_end(data: Dictionary, wire_bytes: int = 0) -> void:
	if pending_world_state_stream.is_empty():
		return
	var expected_snapshot_id: String = str(pending_world_state_stream.get("snapshot_id", ""))
	var expected_world: String = str(pending_world_state_stream.get("world", ""))
	var expected_join_request_id: String = str(pending_world_state_stream.get("join_request_id", ""))
	var expected_world_entry_session_id: String = str(pending_world_state_stream.get("world_entry_session_id", ""))
	var expected_chunk_count: int = int(pending_world_state_stream.get("chunk_count", -1))
	var expected_snapshot_bytes: int = int(pending_world_state_stream.get("snapshot_bytes", 0))
	var received_wire_bytes: int = int(pending_world_state_stream.get("received_wire_bytes", 0)) + maxi(0, wire_bytes)
	if _get_message_world_entry_session_id(data) != expected_world_entry_session_id:
		return
	if (
		int(data.get("stream_version", 0)) != WORLD_STATE_STREAM_VERSION
		or _safe_string(data.get("snapshot_id", ""), "", MAX_REQUEST_ID_LENGTH) != expected_snapshot_id
		or _get_message_world_name(data) != expected_world
		or _get_message_join_request_id(data) != expected_join_request_id
		or int(data.get("chunk_count", -1)) != expected_chunk_count
		or int(data.get("snapshot_bytes", 0)) != expected_snapshot_bytes
		or int(pending_world_state_stream.get("received_count", 0)) != expected_chunk_count
		or received_wire_bytes > MAX_WORLD_STATE_STREAM_WIRE_BYTES
	):
		_fail_pending_world_state_stream("incomplete_end", data)
		return

	var payload: Dictionary = pending_world_state_stream.get("metadata", {}).duplicate(false)
	var section_descriptors: Array = pending_world_state_stream.get("section_descriptors", [])
	for raw_descriptor in section_descriptors:
		var descriptor: Dictionary = raw_descriptor
		var section_name: String = str(descriptor.get("name", ""))
		if str(descriptor.get("kind", "")) == "array":
			payload[section_name] = []
		else:
			payload[section_name] = {}

	var chunks: Dictionary = pending_world_state_stream.get("chunks", {})
	for chunk_index in range(expected_chunk_count):
		if not chunks.has(chunk_index):
			_fail_pending_world_state_stream("missing_chunk", data)
			return
		var chunk: Dictionary = chunks[chunk_index]
		var section_name: String = str(chunk.get("section", ""))
		var section_kind: String = str(chunk.get("section_kind", ""))
		var chunk_data: Variant = chunk.get("data")
		if section_kind == "array":
			var target_array: Array = payload.get(section_name, [])
			target_array.append_array(chunk_data)
			payload[section_name] = target_array
		else:
			var target_dictionary: Dictionary = payload.get(section_name, {})
			for key in chunk_data.keys():
				target_dictionary[key] = chunk_data[key]
			payload[section_name] = target_dictionary

	pending_world_state_stream.clear()
	if not _is_message_for_active_join_request(payload):
		return
	if not _is_message_for_active_world_entry_session(payload):
		return
	if not is_message_for_active_world(payload):
		return
	debug_action_position_flow("received streamed world_state", {
		"world": expected_world,
		"chunks": expected_chunk_count,
		"snapshot_bytes": expected_snapshot_bytes,
		"world_state_reason": str(payload.get("world_state_reason", ""))
	})
	record_world_entry_stage("client_world_data_received", {
		"chunks": expected_chunk_count,
		"snapshot_bytes": expected_snapshot_bytes,
		"wire_bytes": received_wire_bytes,
		"transfer_ms": _get_world_entry_transfer_ms()
	})
	if not _is_valid_server_world_state_payload(payload):
		record_world_entry_stage("client_world_payload_invalid", {
			"world": _get_message_world_name(payload),
			"has_foreground": payload.has("foreground"),
			"has_background": payload.has("background")
		})
		_retry_invalid_server_world_state(payload)
		return
	var world_node: Node = get_world_node()
	if not _world_node_can_apply_server_world_state(world_node):
		var queued_details: Dictionary = _describe_world_state_apply_target(world_node)
		queued_details["reason"] = "world_scene_not_ready"
		record_world_entry_stage("client_world_apply_queued", queued_details)
		_queue_pending_server_world_state(payload, "world_scene_not_ready")
		return
	_apply_server_world_state_payload(payload, world_node)


func _fail_pending_world_state_stream(reason: String, data: Dictionary = {}) -> void:
	print("[world-entry-drop] stream_failed reason=", reason, " world=", str(data.get("world", pending_world_state_stream.get("world", ""))))
	var retry_payload: Dictionary = data.duplicate(true)
	if not pending_world_state_stream.is_empty():
		var metadata_value: Variant = pending_world_state_stream.get("metadata", {})
		if metadata_value is Dictionary:
			retry_payload = metadata_value.duplicate(true)
		retry_payload["world"] = pending_world_state_stream.get("world", retry_payload.get("world", ""))
		retry_payload["join_request_id"] = pending_world_state_stream.get("join_request_id", retry_payload.get("join_request_id", ""))
		retry_payload["world_entry_session_id"] = pending_world_state_stream.get("world_entry_session_id", retry_payload.get("world_entry_session_id", ""))
	pending_world_state_stream.clear()
	debug_action_position_flow("rejected world_state stream", {
		"reason": reason,
		"world": _get_message_world_name(retry_payload),
		"join_request_id": _get_message_join_request_id(retry_payload)
	})
	_retry_invalid_server_world_state(retry_payload)


func _is_valid_server_world_state_payload(data: Dictionary) -> bool:
	if _get_message_world_name(data) == "":
		return false
	for layer_name in ["foreground", "background"]:
		if not data.has(layer_name):
			return false
		var layer_value: Variant = data.get(layer_name)
		if not (layer_value is Array) and not (layer_value is Dictionary):
			return false
	return true


func _world_node_can_apply_server_world_state(world_node: Node) -> bool:
	if world_node == null or not is_instance_valid(world_node):
		return false
	# The first authoritative snapshot activates a newly-instantiated world. The
	# join request, entry session, and target world are validated by the caller.
	if not world_node.has_method("apply_network_world_state"):
		return false
	if "world_state_sync_manager" in world_node and world_node.get("world_state_sync_manager") == null:
		return false
	if "save_manager" in world_node and world_node.get("save_manager") == null:
		return false
	return true


func _describe_world_state_apply_target(world_node: Node) -> Dictionary:
	var details: Dictionary = {
		"target_valid": world_node != null and is_instance_valid(world_node),
		"current_scene": ""
	}
	var scene_tree: SceneTree = get_tree()
	var current_scene: Node = null
	if scene_tree != null:
		current_scene = scene_tree.current_scene
	if current_scene != null and current_scene.is_inside_tree():
		details["current_scene"] = str(current_scene.get_path())
	if world_node == null or not is_instance_valid(world_node):
		return details

	details["target_name"] = str(world_node.name)
	details["target_class"] = world_node.get_class()
	details["target_path"] = str(world_node.get_path()) if world_node.is_inside_tree() else ""
	if "current_world_name" in world_node:
		details["target_world"] = _safe_world_name(str(world_node.get("current_world_name")))
	else:
		details["target_world"] = ""
	details["target_has_apply"] = world_node.has_method("apply_network_world_state")
	details["target_has_sync_manager"] = (
		"world_state_sync_manager" in world_node
		and world_node.get("world_state_sync_manager") != null
	)
	details["target_has_save_manager"] = (
		"save_manager" in world_node
		and world_node.get("save_manager") != null
	)
	return details


func is_world_state_for_active_entry_target(data: Dictionary) -> bool:
	if not _is_message_for_active_join_request(data):
		return false
	if not _is_message_for_active_world_entry_session(data):
		return false
	var incoming_world: String = _get_message_world_name(data)
	var target_world: String = _safe_world_name(active_join_world_name)
	if target_world == "":
		target_world = _safe_world_name(pending_join_world_name)
	return incoming_world != "" and target_world != "" and incoming_world == target_world


func _queue_pending_server_world_state(data: Dictionary, reason: String) -> void:
	if not _is_message_for_active_join_request(data):
		return
	if not _is_message_for_active_world_entry_session(data):
		return
	# The parsed snapshot is immutable while queued. A shallow container copy avoids
	# cloning every block and interaction when the world scene is one frame late.
	pending_server_world_state = data.duplicate(false)
	debug_action_position_flow("queued pending world_state", {
		"world": _get_message_world_name(data),
		"join_request_id": _get_message_join_request_id(data),
		"reason": reason
	})


func _apply_server_world_state_payload(data: Dictionary, world_node: Node) -> void:
	pending_server_world_state.clear()
	pending_world_state_stream.clear()
	clear_world_event_tile_update_queue()
	var incoming_world: String = _get_message_world_name(data)
	if incoming_world != "":
		sync_active_world_name_from_server(incoming_world, world_node)
	var dispatch_details: Dictionary = _describe_world_state_apply_target(world_node)
	dispatch_details["world"] = incoming_world
	record_world_entry_stage("client_world_apply_dispatch", dispatch_details)
	world_node.apply_network_world_state(data)
	record_world_entry_stage("client_world_apply_returned", {
		"world": incoming_world,
		"target_path": str(world_node.get_path()) if world_node.is_inside_tree() else ""
	})
	if world_node.has_method("apply_world_event_state_from_network"):
		world_node.apply_world_event_state_from_network(data)


func _retry_invalid_server_world_state(data: Dictionary) -> void:
	pending_world_state_stream.clear()
	debug_action_position_flow("rejected invalid world_state payload", {
		"world": _get_message_world_name(data),
		"join_request_id": _get_message_join_request_id(data)
	})
	if _request_world_entry_snapshot_restart("invalid_world_state"):
		var restart_world_node: Node = get_world_node()
		if restart_world_node != null and restart_world_node.has_method("update_smooth_world_load_message"):
			restart_world_node.update_smooth_world_load_message("Refreshing world data...")
		return
	var world_node: Node = get_world_node()
	if world_node == null or not is_instance_valid(world_node):
		return
	var save_manager_value: Variant = world_node.get("save_manager") if "save_manager" in world_node else null
	if save_manager_value != null and save_manager_value.has_method("retry_server_world_entry"):
		save_manager_value.call_deferred("retry_server_world_entry", "invalid_world_state")


func _is_player_state_lookup_related_action(action: String) -> bool:
	var normalized = action.strip_edges().to_lower()
	if normalized == "":
		return false

	if normalized == "player_state_request":
		return true
	if normalized == "world_lock_access_check":
		return true
	if normalized == "area_lock_access_check":
		return true
	if normalized == "remote_player_profile":
		return true
	if normalized == "player_profile_update":
		return true
	if normalized == "admin_inventory_lookup":
		return true
	if normalized == "admin_item_instance_lookup":
		return true
	if normalized == "admin_item_instance_history_lookup":
		return true
	if normalized == "admin_transaction_ledger_lookup":
		return true
	if normalized == "admin_monitoring_dashboard":
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
				elif action == "area_lock_access_check":
					should_pick = request_purpose == "area_lock_access_check"
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
	var display_chat_message: String = chat_message
	var server_filtered_message := _safe_string(data.get("filtered_message", ""), "", message_limit)
	if chat_ui != null:
		if chat_ui.has_method("is_chat_content_filter_enabled") and bool(chat_ui.is_chat_content_filter_enabled()):
			if server_filtered_message != "":
				display_chat_message = server_filtered_message
			elif chat_ui.has_method("get_filtered_chat_text"):
				display_chat_message = str(chat_ui.get_filtered_chat_text(chat_message))
		chat_ui.add_chat_message(sender_name, chat_message, {
			"type": message_type,
			"world": source_world,
			"player_id": sender_id,
			"filtered_message": server_filtered_message
		})

		if is_local_sender and message_type != "broadcast":
			chat_ui.show_chat_bubble(display_chat_message)

	var is_remote_sender = not is_local_sender
	if is_remote_sender and world_node != null and sender_id != "system" and sender_name != "system" and message_type != "broadcast":
		if world_node.has_method("show_remote_chat_bubble"):
			world_node.show_remote_chat_bubble(sender_id, display_chat_message, sender_name)
		elif "player_manager" in world_node and world_node.player_manager != null and world_node.player_manager.has_method("show_remote_chat_bubble"):
			world_node.player_manager.show_remote_chat_bubble(sender_id, display_chat_message, sender_name)


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


func queue_player_state_payload_if_present(data: Dictionary, preserve_local_loadout: bool = true) -> bool:
	if not data.has("player_data"):
		return false
	var player_data = data.get("player_data")
	if not (player_data is Dictionary) or player_data.is_empty():
		return false
	pending_server_player_state = {
		"type": "player_state",
		"found": true,
		"username": str(data.get("username", session_username)),
		"player_data": player_data.duplicate(true),
		"preserve_local_loadout": preserve_local_loadout
	}
	return true


func persist_authoritative_player_state_locally(world_node) -> void:
	if world_node == null:
		return
	if not ("save_manager" in world_node):
		return
	var manager = world_node.get("save_manager")
	if manager != null and manager.has_method("save_player_data"):
		manager.save_player_data(false)


func apply_progression_payload_if_present(data: Dictionary) -> bool:
	if not data.has("progression"):
		return false

	var progression_data = data.get("progression")
	if not (progression_data is Dictionary):
		return false
	if progression_data.is_empty():
		return false

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return false
	if not world_node.has_method("apply_network_progression"):
		return false

	var applied := bool(world_node.apply_network_progression(progression_data))
	if applied:
		persist_authoritative_player_state_locally(world_node)
	return applied


func did_server_inventory_update_apply(data: Dictionary, player_state_applied: bool) -> bool:
	return player_state_applied or bool(data.get("_server_inventory_update_applied", false))


func should_apply_pickup_inventory_from_payload(data: Dictionary, inventory_update_applied: bool) -> bool:
	return bool(data.get("_apply_pickup_inventory", true)) and not inventory_update_applied


func apply_inventory_delta_payload_if_present(data: Dictionary) -> bool:
	var raw_delta = null
	if data.has("inventory_delta"):
		raw_delta = data.get("inventory_delta")
	elif data.has("inventory_deltas"):
		raw_delta = data.get("inventory_deltas")
	else:
		return false

	var delta_entries: Array = []
	if raw_delta is Dictionary:
		delta_entries.append(raw_delta)
	elif raw_delta is Array:
		delta_entries = raw_delta
	else:
		return false

	var world_node = get_world_node()
	if world_node == null or not is_world_node_active():
		return false
	if not world_node.has_method("apply_network_inventory_delta"):
		return false

	var applied_count := 0
	for raw_entry in delta_entries:
		if not (raw_entry is Dictionary):
			continue
		if bool(world_node.apply_network_inventory_delta(raw_entry)):
			applied_count += 1

	if applied_count > 0:
		persist_authoritative_player_state_locally(world_node)
		debug_action_position_flow("applied inventory delta payload", {
			"action": str(data.get("action", "")),
			"count": applied_count
		})
	return applied_count > 0


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
	var area_lock_ui_open = false
	if world_node != null and world_node.has_method("is_area_lock_ui_open"):
		area_lock_ui_open = bool(world_node.is_area_lock_ui_open())
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
			if area_lock_ui_open and request_purpose == "area_lock_access_check":
				fallback_key = key
				fallback_request = request_context.duplicate(true)
				break

		if fallback_key == "" and matching_keys.size() == 1:
			fallback_key = matching_keys[0]
			fallback_request = pending_player_state_requests[fallback_key].duplicate(true)

	if response_is_lookup_shape and (world_lock_ui_open or area_lock_ui_open) and fallback_key == "" and matching_keys.size() > 0:
		for key in matching_keys:
			var request_context = pending_player_state_requests[key]
			var request_purpose = str(request_context.get("purpose", "")).strip_edges().to_lower()
			if request_purpose == "world_lock_access_check":
				fallback_key = key
				fallback_request = request_context.duplicate(true)
				break
			if request_purpose == "area_lock_access_check":
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


func apply_pending_server_world_state_if_ready() -> void:
	if pending_server_world_state.is_empty():
		return
	if is_world_state_apply_in_progress():
		return

	# Keep the outer container owned without duplicating every immutable snapshot
	# entry. Deep-copying a large world here caused a visible pre-build stall.
	var pending_data: Dictionary = pending_server_world_state.duplicate(false)
	if not _is_message_for_active_join_request(pending_data):
		pending_server_world_state.clear()
		return
	if not _is_message_for_active_world_entry_session(pending_data):
		pending_server_world_state.clear()
		return
	if not is_message_for_active_world(pending_data):
		var pending_world: String = _get_message_world_name(pending_data)
		if active_join_world_name == "" or pending_world != active_join_world_name:
			pending_server_world_state.clear()
		return

	var world_node: Node = get_world_node()
	if not _world_node_can_apply_server_world_state(world_node):
		return
	if not _is_valid_server_world_state_payload(pending_data):
		pending_server_world_state.clear()
		_retry_invalid_server_world_state(pending_data)
		return

	debug_action_position_flow("applying queued world_state", {
		"world": _get_message_world_name(pending_data),
		"join_request_id": _get_message_join_request_id(pending_data)
	})
	_apply_server_world_state_payload(pending_data, world_node)


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
		"hat": "equipped_hat_item",
		"hair": "equipped_hair_item",
		"eyewear": "equipped_eyewear_item",
		"beard": "equipped_beard_item",
		"body_accessory": "equipped_body_accessory_item",
		"shirt": "equipped_shirt_item",
		"pants": "equipped_pants_item",
		"shoes": "equipped_shoes_item",
		"ride": "equipped_ride_item"
	}

	for slot_name in future_slot_properties.keys():
		var property_name = str(future_slot_properties[slot_name])
		if property_name in world_node:
			slots[slot_name] = str(world_node.get(property_name))
	return slots


func get_equipment_slots_debug_key(equipment_slots) -> String:
	if not (equipment_slots is Dictionary):
		return ""

	var keys = equipment_slots.keys()
	keys.sort()
	var result = ""
	for key in keys:
		if result != "":
			result += "|"
		result += str(key) + "=" + str(equipment_slots[key])
	return result


func get_world_player_node():
	var world_node = get_world_node()
	if world_node == null:
		return null
	return world_node.get("player")


func get_player_motion_state() -> Dictionary:
	var result = {
		"animation_state": "idle",
		"velocity_x": 0.0,
		"velocity_y": 0.0,
		"on_floor": true,
		"in_water": false,
		"in_lava_fire": false,
		"chat_typing": false
	}
	var used_animation_manager_state := false
	var player_node = get_world_player_node()
	if player_node is CharacterBody2D:
		result["velocity_x"] = float(player_node.velocity.x)
		result["velocity_y"] = float(player_node.velocity.y)
		result["on_floor"] = bool(player_node.is_on_floor())
		if player_node.has_method("is_in_water_for_jump_sound"):
			result["in_water"] = bool(player_node.is_in_water_for_jump_sound())
		if player_node.has_method("is_touching_lava_or_fire_block"):
			result["in_lava_fire"] = bool(player_node.is_touching_lava_or_fire_block())

	var world_node = get_world_node()
	if world_node != null:
		var animation_manager = world_node.get("player_animation_manager")
		if animation_manager != null and animation_manager.has_method("get_player_animation_name"):
			var manager_state = str(animation_manager.get_player_animation_name()).strip_edges().to_lower()
			if ["idle", "walk", "jump", "fall", "punch", "hurt", "dead", "dead_spirit"].has(manager_state):
				result["animation_state"] = manager_state
				used_animation_manager_state = true
	if world_node != null and world_node.has_method("is_chat_input_focused") and bool(world_node.is_chat_input_focused()):
		result["chat_typing"] = true

	if not used_animation_manager_state:
		result["animation_state"] = get_player_animation_state_from_motion(
			float(result.get("velocity_x", 0.0)),
			float(result.get("velocity_y", 0.0)),
			bool(result.get("on_floor", true))
		)
	return result


func get_player_damage_visual_state() -> Dictionary:
	var result = {
		"active": false,
		"remaining_ms": 0,
		"token": 0
	}
	var player_node = get_world_player_node()
	if player_node == null:
		return result

	var hurt_until_msec: int = int(player_node.get_meta("face_hurt_until_msec", 0))
	var remaining_msec: int = maxi(0, hurt_until_msec - Time.get_ticks_msec())
	result["active"] = remaining_msec > 0
	result["remaining_ms"] = clampi(remaining_msec, 0, 2000)
	result["token"] = maxi(0, int(player_node.get_meta("hurt_modulate_sequence_id", 0)))
	return result


func get_player_fishing_state() -> Dictionary:
	var result = {
		"active": false,
		"target_x": -1,
		"target_y": -1,
		"lure_id": "",
		"rod_id": ""
	}
	var world_node = get_world_node()
	if world_node == null:
		return result

	var is_active := false
	if "fishing_active" in world_node:
		is_active = bool(world_node.get("fishing_active"))
	if not is_active:
		return result

	var target_grid = world_node.get("fishing_target_grid") if "fishing_target_grid" in world_node else null
	if not (target_grid is Vector2i):
		return result

	result["active"] = true
	result["target_x"] = int(target_grid.x)
	result["target_y"] = int(target_grid.y)
	if "fishing_lure_id" in world_node:
		result["lure_id"] = _safe_string(world_node.get("fishing_lure_id"), "", MAX_ITEM_ID_LENGTH)

	var fishing_manager = world_node.get("fishing_manager") if "fishing_manager" in world_node else null
	if fishing_manager != null and fishing_manager.has_method("get_fishing_line_rod_id"):
		result["rod_id"] = _safe_string(fishing_manager.get_fishing_line_rod_id(), "", MAX_ITEM_ID_LENGTH)
	else:
		var equipment_slots = get_equipment_slots()
		result["rod_id"] = _safe_string(equipment_slots.get("hand", ""), "", MAX_ITEM_ID_LENGTH)

	return result


func get_player_animation_state_from_motion(velocity_x: float, velocity_y: float, on_floor: bool) -> String:
	if not on_floor:
		if velocity_y > 8.0:
			return "fall"
		return "jump"
	if abs(velocity_x) > 6.0:
		return "walk"
	return "idle"


func get_player_animation_state() -> String:
	return str(get_player_motion_state().get("animation_state", "idle"))


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
	if not bool(world_population_authoritative.get(clean_world, false)):
		world_population_counts[clean_world] = ids.size()
	world_population_changed.emit(world_population_counts.duplicate(true))


func _apply_world_population_payload(raw_counts: Dictionary, clear_unreported: bool = false) -> void:
	if raw_counts.is_empty() and not clear_unreported:
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
		world_population_authoritative[clean_world] = true

	if clear_unreported:
		for existing_world in world_population_players.keys():
			if not incoming_keys.has(existing_world):
				world_population_players.erase(existing_world)
		for existing_world in world_population_counts.keys():
			if not incoming_keys.has(existing_world):
				world_population_counts.erase(existing_world)
		for existing_world in world_population_authoritative.keys():
			if not incoming_keys.has(existing_world):
				world_population_authoritative.erase(existing_world)

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
	if not bool(world_population_authoritative.get(clean_world, false)):
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
		if not bool(world_population_authoritative.get(clean_world, false)):
			world_population_counts[clean_world] = ids.size()
			world_population_changed.emit(world_population_counts.duplicate(true))


func get_world_population_counts() -> Dictionary:
	return world_population_counts.duplicate(true)


func get_owned_locked_worlds_cache() -> Array:
	return owned_locked_worlds_cache.duplicate(true)


func handle_owned_locked_worlds_result(data: Dictionary) -> void:
	var sanitized_worlds: Array = []
	var raw_worlds = data.get("worlds", [])
	if raw_worlds is Array:
		for raw_entry in raw_worlds:
			if not (raw_entry is Dictionary):
				continue

			var world_name := _safe_world_name(raw_entry.get("world_name", ""))
			if world_name == "":
				continue

			var entry := {
				"world_name": world_name,
				"owner_name": _safe_string(raw_entry.get("owner_name", ""), "", MAX_USERNAME_LENGTH).to_upper(),
				"owner_account_id": _safe_string(raw_entry.get("owner_account_id", ""), "", MAX_REQUEST_ID_LENGTH),
				"owner_player_id": _safe_string(raw_entry.get("owner_player_id", raw_entry.get("owner_profile_id", "")), "", MAX_REQUEST_ID_LENGTH),
				"owner_profile_id": _safe_string(raw_entry.get("owner_profile_id", raw_entry.get("owner_player_id", "")), "", MAX_REQUEST_ID_LENGTH),
				"lock_grid_x": _safe_int(raw_entry.get("lock_grid_x", 999999), 999999, -MAX_COORDINATE, MAX_COORDINATE),
				"lock_grid_y": _safe_int(raw_entry.get("lock_grid_y", 999999), 999999, -MAX_COORDINATE, MAX_COORDINATE),
				"lock_block_type": _safe_string(raw_entry.get("lock_block_type", raw_entry.get("lock_type", "world_lock")), "world_lock", MAX_ITEM_ID_LENGTH),
				"lock_type": _safe_string(raw_entry.get("lock_type", raw_entry.get("lock_block_type", "world_lock")), "world_lock", MAX_ITEM_ID_LENGTH),
				"access_count": _safe_int(raw_entry.get("access_count", 0), 0, 0, 500),
				"public_build": _safe_bool(raw_entry.get("public_build", false), false),
				"trusted_builder_slot_limit": _safe_int(raw_entry.get("trusted_builder_slot_limit", 0), 0, 0, 50),
				"source_label": _safe_string(raw_entry.get("source_label", "SERVER"), "SERVER", 24),
				"is_locked": true
			}
			sanitized_worlds.append(entry)

	owned_locked_worlds_cache = sanitized_worlds
	var payload := data.duplicate(true)
	payload["worlds"] = sanitized_worlds
	owned_locked_worlds_received.emit(payload)


func _sanitize_landfill_competitor_list(raw_entries) -> Array:
	# Every field is re-clamped here rather than forwarded raw, matching how every other landfill
	# payload is handled in this file. These values only drive a HUD, but a malformed or hostile
	# packet should produce a harmless panel, never a crash mid-race.
	var sanitized: Array = []
	if not (raw_entries is Array):
		return sanitized
	for entry in raw_entries:
		if not (entry is Dictionary):
			continue
		var username: String = _safe_string(entry.get("username", ""), "", MAX_USERNAME_LENGTH)
		if username == "":
			continue
		sanitized.append({
			"username": username,
			"display_name": _safe_string(entry.get("display_name", username), username, MAX_USERNAME_LENGTH),
			"kilograms": _safe_int(entry.get("kilograms", 0), 0, 0, 2000000000),
			"placement": _safe_int(entry.get("placement", 0), 0, 0, 1000),
			"awarded_kilograms": _safe_int(entry.get("awarded_kilograms", 0), 0, 0, 2000000000),
			"connected": _safe_bool(entry.get("connected", true), true),
		})
	return sanitized


# Server-pushed live race state. There is deliberately no outbound counterpart carrying progress,
# placement or phase -- those are server-authoritative and a client that could report them could
# lie about them. request_landfill_race_state() below only ASKS for the current state.
func handle_landfill_race_state(data: Dictionary) -> void:
	var payload := {
		"session_id": _safe_string(data.get("session_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"world": _safe_world_name(data.get("world", "")),
		"state": _safe_string(data.get("state", ""), "", 32),
		"server_time_ms": _safe_int(data.get("server_time_ms", 0), 0, 0, 9007199254740991),
		"countdown_ends_at_ms": _safe_int(data.get("countdown_ends_at_ms", 0), 0, 0, 9007199254740991),
		"race_started_at_ms": _safe_int(data.get("race_started_at_ms", 0), 0, 0, 9007199254740991),
		"race_ends_at_ms": _safe_int(data.get("race_ends_at_ms", 0), 0, 0, 9007199254740991),
		"min_players_to_start": _safe_int(data.get("min_players_to_start", 2), 2, 0, 50),
		"max_players": _safe_int(data.get("max_players", 0), 0, 0, 50),
		"connected_players": _safe_int(data.get("connected_players", 0), 0, 0, 50),
		"competitors": _sanitize_landfill_competitor_list(data.get("competitors", [])),
	}
	landfill_race_state_received.emit(payload)


func handle_landfill_race_results(data: Dictionary) -> void:
	var payload := {
		"session_id": _safe_string(data.get("session_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"world": _safe_world_name(data.get("world", "")),
		"season_key": _safe_string(data.get("season_key", ""), "", 32),
		"results": _sanitize_landfill_competitor_list(data.get("results", [])),
	}
	landfill_race_results_received.emit(payload)


func handle_landfill_status_result(data: Dictionary) -> void:
	var payload := {
		"request_id": _safe_string(data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"event_active": _safe_bool(data.get("event_active", false), false),
		"season_key": _safe_string(data.get("season_key", ""), "", 32),
		"min_players_to_start": _safe_int(data.get("min_players_to_start", 0), 0, 0, 50),
		"max_players_per_instance": _safe_int(data.get("max_players_per_instance", 0), 0, 0, 50),
	}
	landfill_status_received.emit(payload)


func handle_landfill_join_result(data: Dictionary) -> void:
	var payload := {
		"request_id": _safe_string(data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"ok": _safe_bool(data.get("ok", false), false),
		"reason": _safe_string(data.get("reason", ""), "", 64),
		"world_name": _safe_world_name(data.get("world_name", "")),
	}
	landfill_join_result_received.emit(payload)


func handle_landfill_leaderboard_result(data: Dictionary) -> void:
	var sanitized_entries: Array = []
	var raw_entries = data.get("entries", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not (raw_entry is Dictionary):
				continue
			var entry_username := _safe_string(raw_entry.get("username", ""), "", MAX_USERNAME_LENGTH).to_upper()
			if entry_username == "":
				continue
			sanitized_entries.append({
				"username": entry_username,
				"kilograms": _safe_int(raw_entry.get("kilograms", 0), 0, 0, 2000000000),
				"rank": _safe_int(raw_entry.get("rank", 0), 0, 0, 1000),
			})

	var payload := {
		"request_id": _safe_string(data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"season_key": _safe_string(data.get("season_key", ""), "", 32),
		"entries": sanitized_entries,
		"your_kilograms": _safe_int(data.get("your_kilograms", 0), 0, 0, 2000000000),
		"your_rank": _safe_int(data.get("your_rank", 0), 0, 0, 1000),
	}
	landfill_leaderboard_received.emit(payload)


func handle_landfill_claim_result(data: Dictionary) -> void:
	var payload := {
		"request_id": _safe_string(data.get("request_id", ""), "", MAX_REQUEST_ID_LENGTH),
		"ok": _safe_bool(data.get("ok", false), false),
		"reason": _safe_string(data.get("reason", ""), "", 64),
		"message": _safe_string(data.get("message", ""), "", 256),
	}
	landfill_claim_result_received.emit(payload)


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
