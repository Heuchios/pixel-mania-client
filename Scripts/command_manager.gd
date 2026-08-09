extends Node

const DEVELOPER_USERNAME := "USO"
const SERVER_CONFIRMATION_TIMEOUT := 3.0
const ALLOW_LOCAL_DEVELOPER_FALLBACK := false

var world = null
var developer_command_request_counter := 0
var pending_developer_commands := {}
var completed_developer_command_requests := {}
var recent_local_fallback_commands := {}


func setup(parent_world):
	world = parent_world


func handle_command(raw_command: String, server_verified: bool = false, server_request_id: String = ""):
	if world == null:
		return

	var command_text = raw_command.strip_edges()

	if command_text == "":
		return

	if command_text.begins_with("/"):
		command_text = command_text.substr(1)

	var parts = command_text.split(" ", false)

	if parts.size() == 0:
		return

	var command = str(parts[0]).to_lower()

	if command == "help":
		show_player_help()
		return

	if command == "mhelp":
		if not is_moderator_account_active():
			respond("Moderator commands require moderator access.")
			return
		show_moderator_help()
		return

	if command == "ahelp" or command == "adminhelp":
		if not is_admin_command_account_active():
			respond("Admin commands require admin, developer, or designer access.")
			return
		show_admin_help()
		return

	if command == "dev" or command == "developer":
		if not is_developer_account_active():
			respond("Developer panel requires admin or developer access.")
			return
		if world.has_method("toggle_developer_panel"):
			world.toggle_developer_panel()
		else:
			respond("Developer panel is not ready.")
		return

	if is_player_command(command):
		execute_player_command(command, parts)
		return

	if not server_verified:
		if not is_admin_command_account_active():
			respond("Admin commands require admin, developer, or designer access.")
			return

		if command == "give":
			var give_data = parse_give_arguments(parts)
			if not bool(give_data.get("ok", false)):
				respond(str(give_data.get("message", "Use: /give item amount or /give username item amount")))
				return
			command_text = build_give_command_text(give_data)
			parts = command_text.split(" ", false)

		if command == "remove":
			var remove_data = parse_remove_arguments(parts)
			if not bool(remove_data.get("ok", false)):
				respond(str(remove_data.get("message", "Use: /remove username item amount")))
				return
			command_text = build_remove_command_text(remove_data)
			parts = command_text.split(" ", false)

		if requires_server_delivery(command_text) and not is_server_session_ready_for_commands():
			respond("Wait a moment before using commands.")
			return

		if request_server_developer_confirmation(command_text):
			set_developer_panel_status("Waiting for server confirmation...")
		else:
			respond("Developer command could not be sent.")
		return

	if not is_admin_command_account_active():
		respond("Server command rejected: this account cannot use admin commands.")
		return

	if server_request_id != "":
		completed_developer_command_requests[server_request_id] = true

	match command:
		"give":
			command_give(parts)

		"remove":
			command_remove(parts)

		"heal":
			command_heal()

		"health":
			command_health(parts)

		"tp":
			command_tp(parts)

		"spawn":
			command_spawn(parts)

		"equip":
			command_equip(parts)

		"unequip":
			command_unequip()

		"clear_drops":
			command_clear_drops()

		"save":
			if world.has_method("save_world"):
				world.save_world()
				respond("World saved.")

		"load":
			if world.has_method("load_world"):
				world.load_world()
				respond("World loaded.")

		"where":
			command_where()

		"warp":
			command_warp(parts)

		"noc", "noclip":
			command_noclip()

		"resetworld", "reset_world", "reworld":
			command_reset_world()

		"clear":
			command_clear(parts)

		_:
			respond("Unknown command. Type /help")


func execute_verified_developer_command(raw_command: String, request_id: String = "", server_message: String = "", server_data: Dictionary = {}):
	var command_text = raw_command.strip_edges()
	var command_key = normalize_developer_command_key(command_text)

	if request_id != "":
		if completed_developer_command_requests.has(request_id):
			return

		if pending_developer_commands.has(request_id):
			pending_developer_commands.erase(request_id)
		completed_developer_command_requests[request_id] = true
	else:
		var matching_request_id = find_pending_developer_command_request_id(command_key)
		if matching_request_id != "":
			pending_developer_commands.erase(matching_request_id)
			completed_developer_command_requests[matching_request_id] = true
		elif was_recent_local_fallback(command_key):
			return

	if requires_server_delivery(command_text):
		var applied_local_state = apply_server_delivered_command_state(command_text, server_data)
		if server_message.strip_edges() != "":
			set_developer_panel_status(server_message)
			if not applied_local_state:
				respond(server_message)
		else:
			set_developer_panel_status("Server completed developer command.")
			if not applied_local_state:
				respond("Server completed developer command.")
		return

	handle_command(command_text, true, request_id)


func handle_denied_developer_command(raw_command: String, request_id: String = "", server_message: String = ""):
	var command_text = raw_command.strip_edges()
	var command_key = normalize_developer_command_key(command_text)

	if request_id != "":
		if pending_developer_commands.has(request_id):
			pending_developer_commands.erase(request_id)
		completed_developer_command_requests[request_id] = true
	else:
		var matching_request_id = find_pending_developer_command_request_id(command_key)
		if matching_request_id != "":
			pending_developer_commands.erase(matching_request_id)
			completed_developer_command_requests[matching_request_id] = true

	var message = server_message.strip_edges()
	if message == "":
		message = "Server denied developer command."
	set_developer_panel_status(message)
	respond(message)


func is_developer_account_active() -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network != null and network.has_method("is_developer_session"):
		return bool(network.is_developer_session())

	return false


func is_admin_command_account_active() -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network != null and network.has_method("is_admin_command_session"):
		return bool(network.is_admin_command_session())

	return is_developer_account_active()


func is_moderator_account_active() -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network != null and network.has_method("is_moderator_session"):
		return bool(network.is_moderator_session())

	return is_developer_account_active()


func is_player_command(command: String) -> bool:
	return ["where", "warp", "trade", "bc", "player", "profile", "pull"].has(command)


func execute_player_command(command: String, parts: Array):
	match command:
		"where":
			command_where()

		"warp":
			command_warp(parts)

		"trade":
			command_trade(parts)

		"pull":
			command_pull(parts)

		"bc":
			command_broadcast(parts)

		"player", "profile":
			command_player_profile(parts)

		_:
			respond("Unknown command. Type /help")


func get_current_username() -> String:
	if world != null and world.has_method("get_current_profile_name"):
		return str(world.get_current_profile_name()).strip_edges()

	return ""


func is_local_username(username: String) -> bool:
	return normalize_developer_name(username) == normalize_developer_name(get_current_username())


func normalize_developer_name(value: String) -> String:
	return value.strip_edges().to_upper()


func strip_wrapping_quotes(value: String) -> String:
	var clean = value.strip_edges()
	if clean.length() >= 2:
		var first = clean.substr(0, 1)
		var last = clean.substr(clean.length() - 1, 1)
		if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
			return clean.substr(1, clean.length() - 2).strip_edges()
	return clean


func get_command_tail(parts: Array, start_index: int = 1) -> String:
	var tail_parts = []
	for i in range(start_index, parts.size()):
		tail_parts.append(str(parts[i]))
	return strip_wrapping_quotes(" ".join(tail_parts))


func normalize_developer_command_key(command_text: String) -> String:
	return command_text.strip_edges().to_lower()


func get_developer_command_parts(command_text: String) -> Array:
	var clean_command = command_text.strip_edges()
	if clean_command.begins_with("/"):
		clean_command = clean_command.substr(1)

	return clean_command.split(" ", false)


func get_developer_command_name(command_text: String) -> String:
	var parts = get_developer_command_parts(command_text)
	if parts.size() == 0:
		return ""

	return str(parts[0]).to_lower()


func is_server_world_command(command_name: String) -> bool:
	return ["clear", "resetworld", "reset_world", "reworld", "snapshot", "snapshot_world"].has(command_name)


func is_producer_speedup_command(command_name: String) -> bool:
	return [
		"speedproduce",
		"speed_produce",
		"fastproduce",
		"fast_produce",
		"speedgrow",
		"speed_grow",
		"fastgrow",
		"fast_grow"
	].has(command_name)


func make_developer_command_request_id() -> String:
	developer_command_request_counter += 1
	return str(Time.get_ticks_msec()) + "_" + str(developer_command_request_counter)


func request_server_developer_confirmation(command_text: String) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null

	if network == null or not network.has_method("send_developer_command_request"):
		return false

	var request_id = make_developer_command_request_id()
	var sent = bool(network.send_developer_command_request(command_text, request_id, build_developer_command_metadata(command_text)))

	if not sent:
		return false

	pending_developer_commands[request_id] = command_text
	call_deferred("_wait_for_developer_command_confirmation", request_id)
	return true


func is_server_session_ready_for_commands() -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("is_server_session_authenticated"):
		return bool(network.is_server_session_authenticated())

	if network.has_method("has_active_session"):
		return bool(network.has_active_session())

	return false


func _wait_for_developer_command_confirmation(request_id: String):
	await get_tree().create_timer(SERVER_CONFIRMATION_TIMEOUT).timeout

	if not pending_developer_commands.has(request_id):
		return

	var command_text = str(pending_developer_commands[request_id])
	pending_developer_commands.erase(request_id)

	if requires_server_delivery(command_text):
		respond("Command is still waiting for server confirmation.")
		return

	if not ALLOW_LOCAL_DEVELOPER_FALLBACK:
		respond("Command was not confirmed.")
		return

	var command_key = normalize_developer_command_key(command_text)
	recent_local_fallback_commands[command_key] = Time.get_ticks_msec()
	completed_developer_command_requests[request_id] = true
	respond("Command was not confirmed. Running local fallback for " + DEVELOPER_USERNAME + ".")
	handle_command(command_text, true, request_id)


func was_recent_local_fallback(command_key: String) -> bool:
	if not recent_local_fallback_commands.has(command_key):
		return false

	var elapsed = Time.get_ticks_msec() - int(recent_local_fallback_commands[command_key])
	return elapsed < 5000


func find_pending_developer_command_request_id(command_key: String) -> String:
	for request_id in pending_developer_commands.keys():
		var pending_key = normalize_developer_command_key(str(pending_developer_commands[request_id]))

		if pending_key == command_key:
			return str(request_id)

	return ""


func apply_server_delivered_command_state(command_text: String, server_data: Dictionary) -> bool:
	var command_name = get_developer_command_name(command_text)
	if command_name == "noc" or command_name == "noclip":
		if world == null:
			return false
		if server_data.has("noclip_enabled") and world.has_method("set_noclip_enabled"):
			world.set_noclip_enabled(bool(server_data.get("noclip_enabled", false)))
			return true
		if world.has_method("toggle_noclip"):
			world.toggle_noclip()
			return true
	return false


func requires_server_delivery(command_text: String) -> bool:
	var command_name = get_developer_command_name(command_text)
	if is_server_world_command(command_name):
		return true

	var server_owned_commands = [
		"give", "remove",
		"heal", "health",
		"tp", "teleport",
		"spawn",
		"clear_drops",
		"speedproduce", "speed_produce", "fastproduce", "fast_produce",
		"speedgrow", "speed_grow", "fastgrow", "fast_grow",
		"event", "world_event", "forceevent",
		"save", "load", "reload",
		"noc", "noclip",
		"equip", "unequip",
		"ban", "mute", "tradeban", "worldban",
		"unban", "unmute", "untradeban", "unworldban",
		"trade_ban", "world_ban", "untrade_ban", "unworld_ban",
		"punishments", "punishment", "punish",
		"itemaudit", "audititems", "item_audit", "audit_items",
		"itemcopies", "itemowners", "item_copies", "item_owners", "itemcopy", "item_owner",
		"itemfreeze", "freezeitem", "item_freeze",
		"itemunfreeze", "unfreezeitem", "item_unfreeze",
		"itemretire", "retireitem", "item_retire",
		"itemdelete", "deleteitem", "item_delete",
		"itemtransfer", "transferitem", "item_transfer",
		"itemflag", "flagitem", "item_flag"
	]
	return server_owned_commands.has(command_name)


func build_developer_command_metadata(command_text: String) -> Dictionary:
	var command_name = get_developer_command_name(command_text)
	var target_world = get_developer_command_target_world(command_text)
	if command_name == "clear":
		return {
			"command_type": "clear_world",
			"world": target_world,
			"world_name": target_world,
			"protected_foreground": get_clear_protected_foreground(target_world)
		}

	if command_name == "snapshot" or command_name == "snapshot_world":
		return {
			"command_type": "snapshot_world",
			"world": target_world,
			"world_name": target_world
		}

	if is_server_world_command(command_name):
		return {
			"command_type": "reset_world",
			"world": target_world,
			"world_name": target_world
		}

	var parts = get_developer_command_parts(command_text)
	if parts.size() == 0:
		return {}

	if is_producer_speedup_command(command_name):
		var speedup_data = parse_producer_speedup_arguments(parts)
		var speedup_world = str(speedup_data.get("world", get_current_world_name_for_server_command()))
		return {
			"command_type": "producer_speedup",
			"world": speedup_world,
			"world_name": speedup_world,
			"target_world": speedup_world,
			"remaining_seconds": int(speedup_data.get("remaining_seconds", 0)),
			"mode": str(speedup_data.get("mode", "ready"))
		}

	if command_name == "give":
		var give_data = parse_give_arguments(parts)
		if not bool(give_data.get("ok", false)):
			return {}

		return {
			"command_type": "give",
			"target_username": str(give_data.get("target_username", "")),
			"item_id": str(give_data.get("item_id", "")),
			"item_category": str(give_data.get("item_category", "")),
			"amount": int(give_data.get("amount", 1))
		}

	if command_name == "remove":
		var remove_data = parse_remove_arguments(parts)
		if not bool(remove_data.get("ok", false)):
			return {}

		return {
			"command_type": "remove",
			"target_username": str(remove_data.get("target_username", "")),
			"item_id": str(remove_data.get("item_id", "")),
			"item_category": str(remove_data.get("item_category", "")),
			"amount": int(remove_data.get("amount", 1))
		}

	if command_name == "heal":
		return {
			"command_type": "health",
			"target_username": get_current_username(),
			"amount": 3
		}

	if command_name == "health":
		var amount = 3
		if parts.size() >= 2:
			amount = max(1, int(str(parts[1])))
		return {
			"command_type": "health",
			"target_username": get_current_username(),
			"amount": amount
		}

	if command_name == "tp" or command_name == "teleport":
		if parts.size() < 3:
			return {"command_type": "teleport"}
		var grid_x = int(str(parts[1]))
		var grid_y = int(str(parts[2]))
		return {
			"command_type": "teleport",
			"grid_x": grid_x,
			"grid_y": grid_y,
			"x": grid_x,
			"y": grid_y,
			"world": get_current_world_name_for_server_command()
		}

	if command_name == "noc" or command_name == "noclip":
		return {
			"command_type": "noclip",
			"world": get_current_world_name_for_server_command()
		}

	if command_name == "clear_drops":
		var drop_world = get_current_world_name_for_server_command()
		if parts.size() >= 2:
			drop_world = sanitize_server_world_name(str(parts[1]))
		return {
			"command_type": "clear_drops",
			"world": drop_world,
			"world_name": drop_world
		}

	if command_name == "event" or command_name == "world_event" or command_name == "forceevent":
		var event_world = get_current_world_name_for_server_command()
		return {
			"command_type": "force_event" if command_name == "forceevent" else "world_event",
			"world": event_world,
			"world_name": event_world
		}

	if command_name == "save":
		var save_world = get_current_world_name_for_server_command()
		if parts.size() >= 2:
			save_world = sanitize_server_world_name(str(parts[1]))
		return {
			"command_type": "save_world",
			"world": save_world,
			"world_name": save_world
		}

	if command_name == "load" or command_name == "reload":
		var reload_world = get_current_world_name_for_server_command()
		if parts.size() >= 2:
			reload_world = sanitize_server_world_name(str(parts[1]))
		return {
			"command_type": "reload_world",
			"world": reload_world,
			"world_name": reload_world
		}

	if command_name == "spawn":
		if parts.size() < 4:
			return {"command_type": "spawn"}
		return {
			"command_type": "spawn",
			"item_id": str(parts[1]).strip_edges(),
			"block_type": str(parts[1]).strip_edges(),
			"grid_x": int(str(parts[2])),
			"grid_y": int(str(parts[3])),
			"world": get_current_world_name_for_server_command()
		}

	return {}


func get_current_world_name_for_server_command() -> String:
	if world == null:
		return "START"

	var world_name = str(world.get("current_world_name")).strip_edges()
	if world_name == "":
		world_name = "START"

	return world_name.to_upper()


func get_developer_command_target_world(command_text: String) -> String:
	var parts = get_developer_command_parts(command_text)
	if parts.size() >= 2:
		var raw_world = ""
		for i in range(1, parts.size()):
			if raw_world != "":
				raw_world += " "
			raw_world += str(parts[i])

		var explicit_world = sanitize_server_world_name(raw_world)
		if explicit_world != "":
			return explicit_world

	return get_current_world_name_for_server_command()


func sanitize_server_world_name(raw_name: String) -> String:
	var clean = raw_name.strip_edges()
	if clean == "":
		return ""

	if world != null and world.has_method("sanitize_world_name"):
		return str(world.sanitize_world_name(clean)).to_upper()

	clean = clean.to_upper()
	var allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
	var result = ""

	for i in range(clean.length()):
		var character = clean.substr(i, 1)
		if allowed.find(character) != -1:
			result += character
		elif character == " ":
			result += "_"

	return result


func get_clear_protected_foreground(target_world: String = "") -> Array:
	var protected_entries = []
	if world == null:
		return protected_entries

	var current_world = get_current_world_name_for_server_command()
	if target_world.strip_edges() != "" and target_world.strip_edges().to_upper() != current_world:
		return protected_entries

	if world.has_method("ensure_entrance_gate"):
		world.ensure_entrance_gate()

	var protected_types = ["entrance_gate", "world_lock", "super_world_lock", "bedrock"]
	for grid_pos in world.blocks.keys():
		if not (world.blocks[grid_pos] is Dictionary):
			continue

		var block_type = str(world.blocks[grid_pos].get("type", ""))
		if not protected_types.has(block_type):
			continue

		protected_entries.append({
			"x": int(grid_pos.x),
			"y": int(grid_pos.y),
			"block_type": block_type
		})

	return protected_entries


func parse_producer_speedup_duration_seconds(raw_value: String) -> int:
	var clean = raw_value.strip_edges().to_lower()
	if clean == "":
		return -1

	if ["ready", "now", "instant", "done", "finish", "finished"].has(clean):
		return 0

	var number_text = clean
	var multiplier := 1.0
	var suffixes = [
		["seconds", 1.0],
		["second", 1.0],
		["secs", 1.0],
		["sec", 1.0],
		["s", 1.0],
		["minutes", 60.0],
		["minute", 60.0],
		["mins", 60.0],
		["min", 60.0],
		["m", 60.0],
		["hours", 3600.0],
		["hour", 3600.0],
		["hrs", 3600.0],
		["hr", 3600.0],
		["h", 3600.0]
	]

	for suffix_data in suffixes:
		var suffix = str(suffix_data[0])
		if clean.ends_with(suffix):
			number_text = clean.substr(0, clean.length() - suffix.length()).strip_edges()
			multiplier = float(suffix_data[1])
			break

	if number_text == "" or not number_text.is_valid_float():
		return -1

	return max(0, int(ceil(float(number_text) * multiplier)))


func parse_producer_speedup_arguments(parts: Array) -> Dictionary:
	var remaining_seconds := 0
	var remaining_set := false
	var world_parts := []

	for i in range(1, parts.size()):
		var arg = str(parts[i]).strip_edges()
		if arg == "":
			continue

		var lower_arg = arg.to_lower()
		if lower_arg.begins_with("world="):
			var world_value = arg.substr("world=".length()).strip_edges()
			if world_value != "":
				world_parts.append(world_value)
			continue

		var parsed_seconds = parse_producer_speedup_duration_seconds(arg)
		if parsed_seconds >= 0 and not remaining_set:
			remaining_seconds = parsed_seconds
			remaining_set = true
			continue

		world_parts.append(arg)

	var target_world = get_current_world_name_for_server_command()
	if world_parts.size() > 0:
		var parsed_world = sanitize_server_world_name("_".join(world_parts))
		if parsed_world != "":
			target_world = parsed_world

	return {
		"remaining_seconds": remaining_seconds,
		"mode": "ready" if remaining_seconds <= 0 else "remaining",
		"world": target_world
	}


func parse_give_arguments(parts: Array) -> Dictionary:
	if parts.size() < 2:
		return {"ok": false, "message": "Use: /give item amount or /give username item amount"}

	var target_username = get_current_username()
	var item_arg_index = 1
	var amount_arg_index = 2

	if parts.size() >= 4 and find_item_id(str(parts[1])) == "":
		target_username = str(parts[1]).strip_edges()
		item_arg_index = 2
		amount_arg_index = 3

	if target_username == "":
		target_username = get_current_username()

	if item_arg_index >= parts.size():
		return {"ok": false, "message": "Use: /give item amount or /give username item amount"}

	var item_id = find_item_id(str(parts[item_arg_index]))
	if item_id == "":
		return {"ok": false, "message": "Unknown item: " + str(parts[item_arg_index])}

	var amount = 1
	if parts.size() > amount_arg_index:
		amount = max(1, int(parts[amount_arg_index]))

	return {
		"ok": true,
		"target_username": target_username,
		"item_id": item_id,
		"item_category": get_item_category(item_id),
		"amount": amount
	}


func build_give_command_text(give_data: Dictionary) -> String:
	return "give " + str(give_data.get("target_username", get_current_username())) + " " + str(give_data.get("item_id", "")) + " " + str(int(give_data.get("amount", 1)))


func parse_remove_arguments(parts: Array) -> Dictionary:
	if parts.size() < 4:
		return {"ok": false, "message": "Use: /remove username item amount"}

	var target_username = str(parts[1]).strip_edges()
	if target_username == "":
		return {"ok": false, "message": "Use: /remove username item amount"}

	var item_id = find_item_id(str(parts[2]))
	if item_id == "":
		return {"ok": false, "message": "Unknown item: " + str(parts[2])}

	var amount = max(1, int(parts[3]))

	return {
		"ok": true,
		"target_username": target_username,
		"item_id": item_id,
		"item_category": get_item_category(item_id),
		"amount": amount
	}


func build_remove_command_text(remove_data: Dictionary) -> String:
	return "remove " + str(remove_data.get("target_username", "")) + " " + str(remove_data.get("item_id", "")) + " " + str(int(remove_data.get("amount", 1)))


func show_player_help():
	respond("Player commands: /help, /where, /warp world_name, /player username, /trade player_name, /pull username, /bc message")


func show_moderator_help():
	respond("Moderator commands: none configured yet.")


func show_admin_help():
	var shared_commands = "/give item amount, /give username item amount, /remove username item amount, /ban user [time] reason, /mute user [time] reason, /tradeban user [time] reason, /worldban user world [time] reason, /unban user, /unmute user, /untradeban user, /unworldban user world, /punishments user, /itemaudit, /itemcopies id_or_item, /itemfreeze id reason, /itemunfreeze id reason, /itemretire id reason, /itemtransfer id user reason, /itemflag id reason, /heal, /health amount, /tp x y, /spawn block x y, /clear_drops, /speedproduce [ready|seconds] [world], /forceevent snow_storm, /event snow_storm start|end, /save, /load, /noc, /snapshot [world], /clear [world], /resetworld [world]"
	if is_developer_account_active():
		respond("Admin commands: /dev, " + shared_commands)
	else:
		respond("Designer commands: " + shared_commands)


func show_help():
	show_player_help()


func command_give(parts: Array):
	var give_data = parse_give_arguments(parts)
	if not bool(give_data.get("ok", false)):
		respond(str(give_data.get("message", "Use: /give item amount or /give username item amount")))
		return

	var target_username = str(give_data.get("target_username", get_current_username()))
	var item_id = str(give_data.get("item_id", ""))
	var amount = int(give_data.get("amount", 1))

	if not is_local_username(target_username):
		respond("Targeted give requested for " + target_username + ": " + str(amount) + " " + get_display_name(item_id) + ". Waiting for server delivery.")
		return

	if add_item_to_correct_inventory(item_id, amount):
		if world.has_method("update_all_ui"):
			world.update_all_ui()

		if world.has_method("save_player_data"):
			world.save_player_data()

		respond("Gave " + str(amount) + " " + get_display_name(item_id) + " to " + target_username + ".")
		return

	respond("Item exists, but cannot be stored: " + item_id)


func apply_network_item_grant(data: Dictionary):
	var target_username = str(data.get("username", data.get("target_username", data.get("target", "")))).strip_edges()

	if target_username != "" and not is_local_username(target_username):
		return

	var item_id = find_item_id(str(data.get("item_id", data.get("item", data.get("item_type", "")))))
	var amount = max(1, int(data.get("amount", 1)))

	if item_id == "":
		respond("Server tried to grant an unknown item.")
		return

	var player_data = data.get("player_data", {})
	if player_data is Dictionary and not player_data.is_empty():
		if world.has_method("apply_network_player_state"):
			world.apply_network_player_state({
				"type": "player_state",
				"found": true,
				"username": target_username,
				"player_data": player_data
			})
		respond("Received " + str(amount) + " " + get_display_name(item_id) + " from server.")
		return

	if add_item_to_correct_inventory(item_id, amount):
		if world.has_method("update_all_ui"):
			world.update_all_ui()

		if world.has_method("save_player_data"):
			world.save_player_data()

		respond("Received " + str(amount) + " " + get_display_name(item_id) + " from server.")
	else:
		respond("Server grant failed: item cannot be stored.")


func command_remove(parts: Array):
	if parts.size() < 4:
		respond("Use: /remove username item amount")
		return

	var remove_data = parse_remove_arguments(parts)
	if not bool(remove_data.get("ok", false)):
		respond(str(remove_data.get("message", "Use: /remove username item amount")))
		return

	respond("Server inventory removal completed.")


func command_heal():
	world.player_health = 3
	world.update_all_ui()
	respond("Health restored.")


func command_health(parts: Array):
	if parts.size() < 2:
		respond("Use: /health amount")
		return

	var amount = max(1, int(parts[1]))
	world.player_health = amount
	world.update_all_ui()
	respond("Health set to " + str(amount) + ".")


func command_tp(parts: Array):
	if parts.size() < 3:
		respond("Use: /tp x y")
		return

	if world.player == null:
		respond("Player not found.")
		return

	var grid_x = int(parts[1])
	var grid_y = int(parts[2])
	var grid_pos = Vector2i(grid_x, grid_y)

	if world.has_method("is_grid_inside_world") and not world.is_grid_inside_world(grid_pos):
		respond("Outside world bounds.")
		return

	world.player.global_position = Vector2(grid_x * world.BLOCK_SIZE, grid_y * world.BLOCK_SIZE)
	world.player.velocity = Vector2.ZERO
	respond("Teleported to " + str(grid_x) + ", " + str(grid_y) + ".")


func command_spawn(parts: Array):
	if parts.size() < 4:
		respond("Use: /spawn block x y")
		return

	var block_id = find_item_id(str(parts[1]))
	var grid_x = int(parts[2])
	var grid_y = int(parts[3])
	var grid_pos = Vector2i(grid_x, grid_y)

	if block_id == "" or not world.block_textures.has(block_id):
		respond("Unknown block: " + str(parts[1]))
		return

	if world.blocks.has(grid_pos):
		respond("That position already has a block.")
		return

	if world.has_method("is_grid_inside_world") and not world.is_grid_inside_world(grid_pos):
		respond("Outside world bounds.")
		return

	world.create_block(grid_pos, block_id)
	respond("Spawned " + get_display_name(block_id) + ".")


func command_equip(parts: Array):
	if parts.size() < 2:
		respond("Use: /equip tool")
		return

	var item_id = find_item_id(str(parts[1]))

	if item_id == "":
		respond("Unknown tool.")
		return

	if not world.tool_inventory.has(item_id):
		respond("That item is not a tool.")
		return

	if int(world.tool_inventory[item_id]) <= 0:
		respond("You do not have that tool.")
		return

	if world.has_method("equip_tool"):
		world.equip_tool(item_id)
		respond("Equip command used.")


func command_unequip():
	if world.has_method("unequip_tool"):
		world.unequip_tool()
		respond("Unequipped.")


func command_clear_drops():
	if world.drop_manager != null and world.drop_manager.has_method("clear"):
		world.drop_manager.clear()
		respond("Cleared drops.")
		return

	for drop_data in world.dropped_items:
		var drop_node = drop_data.get("node", null)

		if drop_node != null and is_instance_valid(drop_node):
			drop_node.queue_free()

	world.dropped_items.clear()
	respond("Cleared drops.")


func command_where():
	if world.player == null:
		respond("Player not found.")
		return

	var grid_pos = world.get_player_grid_position()
	respond("You are at " + str(grid_pos.x) + ", " + str(grid_pos.y) + ".")


func command_warp(parts: Array):
	if parts.size() < 2:
		respond("Use: /warp world_name")
		return

	var world_name_parts = []

	for i in range(1, parts.size()):
		world_name_parts.append(str(parts[i]))

	var target_world_name = "_".join(world_name_parts).strip_edges()

	if target_world_name == "":
		respond("Use: /warp world_name")
		return

	if world.has_method("enter_world_by_name"):
		respond("Warping to " + target_world_name.to_upper() + "...")
		world.enter_world_by_name(target_world_name)
	else:
		respond("Warp failed: world system is missing.")


func command_trade(parts: Array):
	if parts.size() < 2:
		respond("Use: /trade player_name")
		return

	var requester_name = get_command_tail(parts)
	if requester_name == "":
		respond("Use: /trade player_name")
		return

	if world != null and world.has_method("accept_trade_from_username"):
		world.accept_trade_from_username(requester_name)
		return

	respond("Trading is not available.")


func command_pull(parts: Array):
	if parts.size() < 2:
		respond("Use: /pull username")
		return

	var target_username: String = get_command_tail(parts)
	if target_username == "":
		respond("Use: /pull username")
		return

	var network: Node = null
	if world != null:
		network = world.get_node_or_null("/root/NetworkManager")

	if network == null or not network.has_method("send_pull_player_request"):
		respond("Pull is not available right now.")
		return

	if not bool(network.send_pull_player_request(target_username)):
		respond("Sign on before pulling players.")


func command_player_profile(parts: Array):
	if parts.size() < 2:
		respond("Use: /player username")
		return

	var username = get_command_tail(parts)
	if username == "":
		respond("Use: /player username")
		return

	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null or not network.has_method("is_server_session_authenticated") or not bool(network.is_server_session_authenticated()):
		respond("Sign on before looking up player profiles.")
		return

	if world != null and world.has_method("open_remote_player_profile"):
		var player_data: Dictionary = {}
		if world.has_method("get_remote_player_profile_by_username"):
			player_data = world.get_remote_player_profile_by_username(username)
		if player_data.is_empty():
			player_data = {
				"username": username,
				"name": username,
				"online": false,
				"lookup_source": "command"
			}
		else:
			player_data["online"] = true
			player_data["lookup_source"] = "command"
		world.open_remote_player_profile(player_data)
		respond("Looking up " + username + "...")
		return

	respond("Player profile UI is not ready.")


func command_broadcast(parts: Array):
	if parts.size() < 2:
		respond("Use: /bc message")
		return

	var message_parts = []
	for i in range(1, parts.size()):
		message_parts.append(str(parts[i]))

	var message = " ".join(message_parts).strip_edges()
	if message == "":
		respond("Use: /bc message")
		return

	var network = world.get_node_or_null("/root/NetworkManager") if world != null else null
	if network == null or not network.has_method("send_broadcast_message"):
		respond("Broadcast system is not ready.")
		return

	if not bool(network.send_broadcast_message(message)):
		respond("Sign on before broadcasting.")


func command_noclip():
	if world != null and world.has_method("toggle_noclip"):
		world.toggle_noclip()
	else:
		respond("Noclip is not available.")


func command_clear(_parts: Array):
	if world == null:
		return

	# /clear removes all blocks except entrance gate, lock blocks, and bedrock.
	# World lock data and permissions are fully preserved.
	var protected = ["entrance_gate", "world_lock", "super_world_lock", "bedrock"]
	var sync_manager: Variant = world.get("world_state_sync_manager")
	if sync_manager != null and sync_manager.has_method("notify_world_collision_snapshot_rebuilding"):
		sync_manager.notify_world_collision_snapshot_rebuilding("local-clear-world-start")

	var to_remove = []
	for grid_pos in world.blocks.keys():
		var block_type = str(world.blocks[grid_pos].get("type", ""))
		if not protected.has(block_type):
			to_remove.append(grid_pos)

	for grid_pos in to_remove:
		world.remove_block_without_drop(grid_pos)

	# Clear background blocks (cave walls, etc.)
	if world.save_manager != null and world.save_manager.has_method("clear_background_blocks"):
		world.save_manager.clear_background_blocks()

	# Clear seeds and dropped items too
	world.clear_planted_seeds()
	if world.drop_manager != null and world.drop_manager.has_method("clear"):
		world.drop_manager.clear()

	# Ensure entrance gate is still intact with its bedrock support
	world.ensure_entrance_gate()
	if sync_manager != null and sync_manager.has_method("mark_world_collision_snapshot_changed"):
		sync_manager.mark_world_collision_snapshot_changed("local-clear-world")

	world.save_world()
	respond("World cleared. " + str(to_remove.size()) + " blocks removed.")


func command_reset_world():
	if world == null:
		return

	respond("Resetting world...")

	# Delete the save file so the world regenerates fresh
	var save_path = world.get_current_save_path()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	# Clear everything in the world
	world.clear_world()

	# Generate a brand new world
	world.generate_world()
	world.ensure_entrance_gate()

	# Respawn player at entrance gate
	if world.player != null:
		var spawn_pos = world.get_entrance_gate_spawn_position()
		world.player.global_position = spawn_pos
		if world.player is CharacterBody2D:
			world.player.velocity = Vector2.ZERO

	# Save the fresh world
	world.save_world()
	respond("World reset.")


func find_item_id(raw_text: String) -> String:
	var item_id = normalize_id(raw_text)

	if world.item_database.has(item_id):
		return item_id

	if not item_id.ends_with("_seed"):
		var seed_id = item_id + "_seed"

		if world.item_database.has(seed_id):
			return seed_id

	var no_underscore = item_id.replace("_", "")

	for database_id in world.item_database.keys():
		if str(database_id).replace("_", "") == no_underscore:
			return str(database_id)

	return ""


func add_item_to_correct_inventory(item_id: String, amount: int) -> bool:
	var category = get_item_category(item_id)

	if category == "block":
		if not world.inventory.has(item_id):
			world.inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.inventory, item_id, category, amount)
		return true

	if category == "seed":
		if not world.seed_inventory.has(item_id):
			world.seed_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.seed_inventory, item_id, category, amount)
		return true

	if category == "tool":
		if not world.tool_inventory.has(item_id):
			world.tool_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.tool_inventory, item_id, category, amount)
		return true

	if category == "currency":
		if not world.currency_inventory.has(item_id):
			world.currency_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.currency_inventory, item_id, category, amount)
		return true

	if category == "material":
		if not world.material_inventory.has(item_id):
			world.material_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.material_inventory, item_id, category, amount)
		return true

	if category == "back":
		if not world.back_inventory.has(item_id):
			world.back_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.back_inventory, item_id, category, amount)
		return true

	if category == "hat":
		if not world.hat_inventory.has(item_id):
			world.hat_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.hat_inventory, item_id, category, amount)
		return true

	if category == "hair":
		if not world.hair_inventory.has(item_id):
			world.hair_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.hair_inventory, item_id, category, amount)
		return true

	if category == "eyewear":
		if not world.eyewear_inventory.has(item_id):
			world.eyewear_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.eyewear_inventory, item_id, category, amount)
		return true

	if category == "beard":
		if not world.beard_inventory.has(item_id):
			world.beard_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.beard_inventory, item_id, category, amount)
		return true

	if category == "body_accessory":
		if not world.body_accessory_inventory.has(item_id):
			world.body_accessory_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.body_accessory_inventory, item_id, category, amount)
		return true

	if category == "shirt":
		if not world.shirt_inventory.has(item_id):
			world.shirt_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.shirt_inventory, item_id, category, amount)
		return true

	if category == "pants":
		if not world.pants_inventory.has(item_id):
			world.pants_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.pants_inventory, item_id, category, amount)
		return true

	if category == "shoes":
		if not world.shoes_inventory.has(item_id):
			world.shoes_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.shoes_inventory, item_id, category, amount)
		return true

	if category == "ride":
		if not world.ride_inventory.has(item_id):
			world.ride_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.ride_inventory, item_id, category, amount)
		return true

	if category == "lure":
		if not world.lure_inventory.has(item_id):
			world.lure_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.lure_inventory, item_id, category, amount)
		return true

	if category == "fish":
		if not world.fish_inventory.has(item_id):
			world.fish_inventory[item_id] = 0
		var current_fish_count: int = max(0, int(floor(float(world.fish_inventory.get(item_id, 0)))))
		world.fish_inventory[item_id] = current_fish_count + max(0, amount)
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(item_id, category)
		return true

	return false


func remove_item_from_correct_inventory(item_id: String, amount: int) -> bool:
	var category = get_item_category(item_id)
	var target_inventory = null

	if category == "block":
		target_inventory = world.inventory
	elif category == "seed":
		target_inventory = world.seed_inventory
	elif category == "tool":
		target_inventory = world.tool_inventory
	elif category == "currency":
		target_inventory = world.currency_inventory
	elif category == "material":
		target_inventory = world.material_inventory
	elif category == "back":
		target_inventory = world.back_inventory
	elif category == "hat":
		target_inventory = world.hat_inventory
	elif category == "hair":
		target_inventory = world.hair_inventory
	elif category == "eyewear":
		target_inventory = world.eyewear_inventory
	elif category == "beard":
		target_inventory = world.beard_inventory
	elif category == "body_accessory":
		target_inventory = world.body_accessory_inventory
	elif category == "shirt":
		target_inventory = world.shirt_inventory
	elif category == "pants":
		target_inventory = world.pants_inventory
	elif category == "shoes":
		target_inventory = world.shoes_inventory
	elif category == "ride":
		target_inventory = world.ride_inventory
	elif category == "lure":
		target_inventory = world.lure_inventory
	elif category == "fish":
		target_inventory = world.fish_inventory

	if target_inventory == null:
		return false

	if not target_inventory.has(item_id):
		return false

	if int(target_inventory[item_id]) <= 0:
		return false

	if category == "fish":
		var remove_count: int = max(0, amount)
		var current_count: int = max(0, int(floor(float(target_inventory[item_id]))))
		if remove_count <= 0 or current_count < remove_count:
			return false
		var remaining_count: int = current_count - remove_count
		if remaining_count <= 0:
			target_inventory.erase(item_id)
		else:
			target_inventory[item_id] = remaining_count
		if world.has_method("refresh_ui_after_item_change"):
			world.refresh_ui_after_item_change(item_id, category)
		return true

	world.spend_item_from_inventory_stack(target_inventory, item_id, category, amount)
	return true


func get_item_category(item_id: String) -> String:
	if world.item_database.has(item_id):
		return str(world.item_database[item_id].get("category", ""))

	return ""


func get_display_name(item_id: String) -> String:
	if world.item_database.has(item_id):
		return str(world.item_database[item_id].get("display_name", item_id.capitalize()))

	return item_id.capitalize()


func normalize_id(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func respond(message: String):
	if world == null:
		return

	if world.has_method("show_notification"):
		world.show_notification(message)

	if world.chat_ui != null and world.chat_ui.has_method("add_chat_message"):
		world.chat_ui.add_chat_message("System", message)


func set_developer_panel_status(message: String):
	if world == null:
		return

	var panel = null
	if "developer_panel_ui" in world:
		panel = world.developer_panel_ui

	if panel != null and panel.has_method("set_result"):
		panel.set_result(message)
