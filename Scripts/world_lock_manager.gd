extends Node

# PixelMania World Lock Manager v1
# Owns world lock state and permission checks.
# Does not change save_manager.gd. If your existing save system already calls
# world.get_world_lock_save_data() / world.load_world_lock_save_data(), this
# manager will plug into those hooks.

var world = null

var is_locked: bool = false
var owner_name: String = ""
var lock_grid_pos: Vector2i = Vector2i(999999, 999999)
var allowed_players: Array = []
var player_roles: Dictionary = {}
var public_build: bool = false
var trusted_builder_slot_limit: int = 6

const ROLE_OWNER = "owner"
const ROLE_ADMIN = "admin"
const ROLE_BUILDER = "builder"
const ROLE_VISITOR = "visitor"
const ROLE_NONE = "none"

const LEGACY_ACCESS = "access"
const DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT = 6
const MIN_TRUSTED_BUILDER_SLOT_LIMIT = 0
const MAX_TRUSTED_BUILDER_SLOT_LIMIT = 50
const WORLD_LOCK_GRID_SENTINEL := 999999


func setup(world_ref):
	world = world_ref


func get_trusted_builder_slot_limit() -> int:
	return trusted_builder_slot_limit


func get_trusted_builder_slot_count() -> int:
	var builder_count: int = 0

	for raw_name in allowed_players:
		var clean_name = normalize_name(str(raw_name))
		if clean_name == "":
			continue
		var role: String = get_player_access_role(clean_name)
		if _is_trusted_builder_role(role):
			builder_count += 1

	return builder_count


func get_trusted_builder_slot_summary() -> String:
	return str(get_trusted_builder_slot_count()) + "/" + str(trusted_builder_slot_limit)


func normalize_role(raw_role: String) -> String:
	var role = raw_role.strip_edges().to_lower()

	match role:
		ROLE_ADMIN:
			return ROLE_ADMIN
		ROLE_BUILDER:
			return ROLE_BUILDER
		ROLE_VISITOR:
			return ROLE_VISITOR
		ROLE_OWNER:
			return ROLE_OWNER
		ROLE_NONE:
			return ROLE_NONE
		LEGACY_ACCESS:
			return ROLE_BUILDER

	return ROLE_NONE


func _normalize_trusted_builder_slot_limit(value: int) -> int:
	if value < MIN_TRUSTED_BUILDER_SLOT_LIMIT:
		return MIN_TRUSTED_BUILDER_SLOT_LIMIT
	if value > MAX_TRUSTED_BUILDER_SLOT_LIMIT:
		return MAX_TRUSTED_BUILDER_SLOT_LIMIT
	return value


func _is_trusted_builder_role(role: String) -> bool:
	var normalized_role = normalize_role(role)
	return normalized_role == ROLE_ADMIN or normalized_role == ROLE_BUILDER


func _safe_int(value, fallback: int, min_value: int, max_value: int) -> int:
	if value is int or value is float:
		return clamp(int(value), min_value, max_value)
	return fallback


func get_role_title(role: String) -> String:
	match normalize_role(role):
		ROLE_ADMIN:
			return "ADMIN"
		ROLE_VISITOR:
			return "VISITOR"
		ROLE_BUILDER:
			return "BUILDER"
		_:
			return "NONE"


func normalize_name(raw_name: String) -> String:
	return raw_name.strip_edges().to_upper()


func _get_active_session_username() -> String:
	if world == null:
		return ""

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return ""
	if not network.has_method("get_active_session_username"):
		return ""

	var session_name = str(network.get_active_session_username()).strip_edges()
	if session_name == "":
		return ""

	return normalize_name(session_name)


func _is_strict_security_mode() -> bool:
	if world == null:
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null:
		return false
	if not network.has_method("is_connected_to_server") or not bool(network.is_connected_to_server()):
		return false
	if not network.has_method("has_active_session") or not bool(network.has_active_session()):
		return false
	if network.has_method("is_server_session_authenticated") and not bool(network.is_server_session_authenticated()):
		return false

	return true


func _is_current_session_server_admin() -> bool:
	if world == null:
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("is_developer_session"):
		return false

	return bool(network.is_developer_session())


func _is_local_owner_session_verified() -> bool:
	if not _is_strict_security_mode():
		return true
	if not _is_local_player_session_match():
		return false

	return normalize_name(owner_name) == _get_active_session_username()


func _is_local_player_session_match() -> bool:
	if not _is_strict_security_mode():
		return true

	var session_name = _get_active_session_username()
	if session_name == "":
		return false

	var current_player = get_current_player_name()
	if current_player == "":
		return false

	return current_player == session_name


func is_strict_mode_enabled() -> bool:
	return _is_strict_security_mode()


func is_current_player_owner_session_verified() -> bool:
	return _is_local_owner_session_verified()


func _assert_owner_can_modify(action_label: String) -> Dictionary:
	if not is_current_player_owner():
		return {"ok": false, "message": "Only the owner can " + action_label + "."}

	if _is_strict_security_mode() and not _is_local_owner_session_verified():
		return {"ok": false, "message": "Owner identity could not be verified. Re-sign in as the world owner account."}

	return {"ok": true, "message": ""}


func get_current_player_name() -> String:
	if world != null and world.has_method("get_current_profile_name"):
		var profile_name: String = normalize_name(str(world.get_current_profile_name()))

		if profile_name != "":
			return profile_name

	return ""


func ensure_owner_name():
	if not is_locked:
		return

	if normalize_name(owner_name) == "":
		owner_name = get_current_player_name()
	else:
		owner_name = normalize_name(owner_name)


func is_owner(player_name: String) -> bool:
	if not is_locked:
		return false

	ensure_owner_name()
	return normalize_name(player_name) == normalize_name(owner_name)


func is_current_player_owner() -> bool:
	if _is_strict_security_mode() and not _is_local_player_session_match():
		return false

	return is_owner(get_current_player_name())


func get_player_access_state(player_name: String) -> String:
	if not is_locked:
		return ROLE_NONE

	var role: String = get_player_access_role(player_name)

	if role == ROLE_OWNER:
		return ROLE_OWNER

	if role == ROLE_ADMIN or role == ROLE_BUILDER or role == ROLE_VISITOR:
		return "access"

	return ROLE_NONE


func get_player_access_role_for_player(player_name: String) -> String:
	return get_player_access_role(player_name)


func get_player_access_role(player_name: String) -> String:
	if not is_locked:
		return ROLE_NONE

	var clean_name: String = normalize_name(player_name)

	if clean_name == "":
		return ROLE_NONE

	if is_owner(clean_name):
		return ROLE_OWNER

	var clean_owner: String = normalize_name(owner_name)
	if clean_owner != "" and clean_owner == clean_name:
		return ROLE_OWNER

	if player_roles.has(clean_name):
		return normalize_role(str(player_roles.get(clean_name, ROLE_BUILDER)))

	if allowed_players.has(clean_name):
		return ROLE_BUILDER

	return ROLE_NONE


func is_current_player_access() -> bool:
	if _is_strict_security_mode() and not _is_local_player_session_match():
		return false

	return get_player_access_role(get_current_player_name()) != ROLE_NONE


func is_current_player_owner_or_access() -> bool:
	if _is_strict_security_mode() and not _is_local_player_session_match():
		return false

	return get_player_access_state(get_current_player_name()) != ROLE_NONE


func is_player_owner_or_access(player_name: String) -> bool:
	return get_player_access_state(player_name) != ROLE_NONE


func is_player_allowed(player_name: String) -> bool:
	return get_player_access_role(player_name) != ROLE_NONE


func _can_build_with_role(role: String) -> bool:
	role = normalize_role(role)
	if role == ROLE_NONE:
		return false

	return role == ROLE_OWNER or role == ROLE_ADMIN or role == ROLE_BUILDER


func _can_wrench_world_lock(role: String) -> bool:
	role = normalize_role(role)
	return role != ROLE_NONE


func _can_toggle_wooden_entrance_with_role(role: String) -> bool:
	role = normalize_role(role)
	return role == ROLE_OWNER or role == ROLE_ADMIN


func can_current_player_build() -> bool:
	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	var role: String = get_player_access_role(get_current_player_name())

	if _can_build_with_role(role):
		return true

	if public_build:
		return true

	return false


func can_current_player_place_block(block_type: String) -> bool:
	if not _is_local_player_session_match():
		return false

	if block_type == "world_lock":
		return not is_locked and not has_world_lock_block()

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	if is_vending_machine_block(block_type):
		return is_locked and is_current_player_owner()

	if is_fish_monger_block(block_type):
		return is_locked and can_current_player_build()

	if not is_locked:
		return true

	return can_current_player_build()


func can_current_player_break_block(block_type: String) -> bool:
	if not _is_local_player_session_match():
		return false

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	# The World Lock itself can only be broken by the owner.
	if block_type == "world_lock":
		if not is_locked:
			return true
		return is_current_player_owner() and not has_world_lock_break_blockers()

	if is_vending_machine_block(block_type):
		return is_locked and is_current_player_owner()

	if is_fish_monger_block(block_type):
		return is_locked and (is_current_player_owner() or _can_build_with_role(get_player_access_role(get_current_player_name())))

	if not is_locked:
		return true

	return can_current_player_build()


func can_current_player_interact_with_block(block_type: String) -> bool:
	if not _is_local_player_session_match():
		return false

	if block_type == "wooden_entrance":
		return can_current_player_toggle_wooden_entrance()

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	if is_vending_machine_block(block_type):
		return is_locked

	if is_fish_monger_block(block_type):
		return true

	if not is_locked:
		return true

	# Allow visitors to wrench the lock so they can see who owns the world.
	if block_type == "world_lock":
		return true

	var role: String = get_player_access_role(get_current_player_name())
	if role == ROLE_NONE:
		return false

	if block_type == "world_lock":
		return _can_wrench_world_lock(role)

	return _can_build_with_role(role)


func can_current_player_toggle_wooden_entrance() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_pass_wooden_entrance() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return get_player_access_role(get_current_player_name()) != ROLE_NONE


func is_vending_machine_block(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func is_safe_block(block_type: String) -> bool:
	return block_type == "safe"


func is_fish_monger_block(block_type: String) -> bool:
	return block_type == "fish_monger"


func has_world_lock_block() -> bool:
	if world == null:
		return false

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue

		if str(block_data.get("type", "")) == "world_lock":
			return true

	return false


func has_world_lock_break_blockers() -> bool:
	if world == null:
		return false

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue

		var block_type := str(block_data.get("type", ""))
		if is_safe_block(block_type) or is_vending_machine_block(block_type) or is_fish_monger_block(block_type):
			return true

	return false


func on_world_lock_block_placed(grid_pos: Vector2i):
	if not _is_local_player_session_match():
		if world != null and world.has_method("show_notification"):
			world.show_notification("World lock placement blocked: session verification required.")
		return

	if is_locked:
		if world != null and world.has_method("show_notification"):
			world.show_notification("This world already has a World Lock.")
		return

	is_locked = true
	owner_name = get_current_player_name()
	lock_grid_pos = grid_pos
	public_build = false
	trusted_builder_slot_limit = DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT
	allowed_players.clear()
	player_roles.clear()

	if world != null and world.has_method("show_notification"):
		world.show_notification("World locked by " + owner_name + ".")

	send_network_world_lock_state()
	request_save()


func on_world_lock_block_broken(grid_pos: Vector2i):
	if not _is_local_player_session_match():
		if world != null and world.has_method("show_notification"):
			world.show_notification("World lock break blocked: session verification required.")
		return

	if not is_locked:
		return

	if grid_pos != lock_grid_pos:
		return

	var old_owner: String = owner_name
	is_locked = false
	owner_name = ""
	lock_grid_pos = Vector2i(999999, 999999)
	allowed_players.clear()
	player_roles.clear()
	public_build = false
	trusted_builder_slot_limit = DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT

	if world != null and world.has_method("show_notification"):
		world.show_notification("World Lock removed. Previous owner: " + old_owner + ".")

	send_network_world_lock_state()
	request_save()


func add_access_name(raw_name: String, raw_role: String = ROLE_BUILDER, verified_target: bool = false) -> Dictionary:
	var owner_permission = _assert_owner_can_modify("add access")
	if not bool(owner_permission.get("ok", false)):
		return owner_permission

	if _is_strict_security_mode() and not bool(verified_target):
		return {"ok": false, "message": "Player lookup verification is required before granting access."}

	if not is_locked:
		return {"ok": false, "message": "This world is not locked."}

	var clean_name: String = normalize_name(raw_name)

	if clean_name == "":
		return {"ok": false, "message": "Enter a username first."}

	if clean_name == normalize_name(owner_name):
		return {"ok": false, "message": "Owner already has access."}

	var role: String = normalize_role(raw_role)

	if role == ROLE_NONE:
		return {"ok": false, "message": "Invalid role selected."}

	if allowed_players.has(clean_name):
		var existing_role = get_player_access_role(clean_name)
		if existing_role == role:
			return {"ok": false, "message": clean_name + " already has access."}

		if _is_trusted_builder_role(role) and not _is_trusted_builder_role(existing_role):
			var current_count = get_trusted_builder_slot_count()
			if current_count >= trusted_builder_slot_limit:
				return {"ok": false, "message": "Trusted builder slots are full. Increase the limit first."}

		player_roles[clean_name] = role
		send_network_world_lock_state()
		request_save()
		return {"ok": true, "message": "Updated " + clean_name + " role to " + _role_title(role) + "."}

	if _is_trusted_builder_role(role) and get_trusted_builder_slot_count() >= trusted_builder_slot_limit:
		return {"ok": false, "message": "Trusted builder slots are full. Increase the limit first."}

	allowed_players.append(clean_name)
	player_roles[clean_name] = role
	allowed_players.sort()

	send_network_world_lock_state()
	request_save()
	return {"ok": true, "message": "Added access for " + clean_name + " as " + _role_title(role) + "."}


func remove_access_name(raw_name: String) -> Dictionary:
	var owner_permission = _assert_owner_can_modify("remove access")
	if not bool(owner_permission.get("ok", false)):
		return owner_permission

	if not is_locked:
		return {"ok": false, "message": "This world is not locked."}

	var clean_name: String = normalize_name(raw_name)

	if not allowed_players.has(clean_name):
		return {"ok": false, "message": clean_name + " is not on the access list."}

	allowed_players.erase(clean_name)
	player_roles.erase(clean_name)

	send_network_world_lock_state()
	request_save()
	return {"ok": true, "message": "Removed access for " + clean_name + "."}


func set_player_role(raw_name: String, raw_role: String) -> Dictionary:
	var owner_permission = _assert_owner_can_modify("change access roles")
	if not bool(owner_permission.get("ok", false)):
		return owner_permission

	if not is_locked:
		return {"ok": false, "message": "This world is not locked."}

	var clean_name: String = normalize_name(raw_name)
	if clean_name == "":
		return {"ok": false, "message": "Enter a username first."}

	if clean_name == normalize_name(owner_name):
		return {"ok": false, "message": "Owner already has access."}

	if not allowed_players.has(clean_name):
		return {"ok": false, "message": clean_name + " is not on the access list."}

	var role: String = normalize_role(raw_role)
	if role == ROLE_NONE:
		return {"ok": false, "message": "Invalid role selected."}
	var current_role = get_player_access_role(clean_name)
	if current_role == role:
		return {"ok": false, "message": clean_name + " is already set to " + _role_title(role) + "."}

	if _is_trusted_builder_role(role) and not _is_trusted_builder_role(current_role):
		var current_count = get_trusted_builder_slot_count()
		if current_count >= trusted_builder_slot_limit:
			return {"ok": false, "message": "Trusted builder slots are full. Increase the limit first."}

	player_roles[clean_name] = role
	send_network_world_lock_state()
	request_save()
	return {"ok": true, "message": "Updated " + clean_name + " role to " + _role_title(role) + "."}


func set_public_build(enabled: bool) -> Dictionary:
	var owner_permission = _assert_owner_can_modify("change world public build")
	if not bool(owner_permission.get("ok", false)):
		return owner_permission

	if not is_locked:
		return {"ok": false, "message": "This world is not locked."}

	public_build = enabled

	send_network_world_lock_state()
	request_save()

	if public_build:
		return {"ok": true, "message": "Public building is ON."}

	return {"ok": true, "message": "Public building is OFF."}


func set_trusted_builder_slot_limit(raw_limit: int) -> Dictionary:
	var owner_permission = _assert_owner_can_modify("change trusted builder limits")
	if not bool(owner_permission.get("ok", false)):
		return owner_permission

	if not is_locked:
		return {"ok": false, "message": "This world is not locked."}

	var new_limit: int = _normalize_trusted_builder_slot_limit(raw_limit)
	if new_limit == trusted_builder_slot_limit:
		return {"ok": true, "message": "Trusted builder slots already set to " + str(new_limit) + "."}

	var current_count = get_trusted_builder_slot_count()
	if new_limit < current_count:
		return {"ok": false, "message": "Need at least " + str(current_count) + " slots for current trusted builders."}

	trusted_builder_slot_limit = new_limit
	send_network_world_lock_state()
	request_save()
	return {"ok": true, "message": "Trusted builder slots set to " + str(new_limit) + "."}


func get_access_list() -> Array:
	var result: Array = []

	for value in allowed_players:
		result.append(str(value))

	result.sort()
	return result


func get_access_roles() -> Dictionary:
	var result: Dictionary = {}

	for player_name in allowed_players:
		var clean_name = normalize_name(str(player_name))
		if clean_name == "":
			continue
		result[clean_name] = get_player_access_role(clean_name)
	return result


func _role_title(role: String) -> String:
	return get_role_title(role)


func get_lock_position_text() -> String:
	if lock_grid_pos.x >= 999000:
		return "None"

	return str(lock_grid_pos.x) + ", " + str(lock_grid_pos.y)


func get_info_text() -> String:
	if not is_locked:
		return "World is not locked."

	ensure_owner_name()
	var trusted_builder_summary = get_trusted_builder_slot_summary()

	if public_build:
		return "Locked by " + owner_name + " | Public build ON | Trusted builders: " + trusted_builder_summary

	return "Locked by " + owner_name + " | Owner/access only | Trusted builders: " + trusted_builder_summary


func get_save_data() -> Dictionary:
	return {
		"is_locked": is_locked,
		"owner_name": owner_name,
		"lock_grid_x": lock_grid_pos.x,
		"lock_grid_y": lock_grid_pos.y,
		"allowed_players": allowed_players.duplicate(true),
		"player_roles": player_roles.duplicate(true),
		"public_build": public_build,
		"trusted_builder_slot_limit": trusted_builder_slot_limit
	}


func load_save_data(data: Dictionary):
	is_locked = bool(data.get("is_locked", false))
	owner_name = normalize_name(str(data.get("owner_name", "")))
	lock_grid_pos = Vector2i(
		_safe_int(data.get("lock_grid_x", WORLD_LOCK_GRID_SENTINEL), WORLD_LOCK_GRID_SENTINEL, 0, WORLD_LOCK_GRID_SENTINEL),
		_safe_int(data.get("lock_grid_y", WORLD_LOCK_GRID_SENTINEL), WORLD_LOCK_GRID_SENTINEL, 0, WORLD_LOCK_GRID_SENTINEL)
	)
	public_build = bool(data.get("public_build", false))
	trusted_builder_slot_limit = _normalize_trusted_builder_slot_limit(_safe_int(
		data.get("trusted_builder_slot_limit", DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT),
		DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT,
		MIN_TRUSTED_BUILDER_SLOT_LIMIT,
		MAX_TRUSTED_BUILDER_SLOT_LIMIT
	))

	allowed_players.clear()
	player_roles.clear()

	var roles_data = data.get("player_roles", {})
	if roles_data is Dictionary:
		for raw_name in roles_data.keys():
			var clean_name: String = normalize_name(str(raw_name))
			var role: String = normalize_role(str(roles_data.get(raw_name, ROLE_BUILDER)))

			if clean_name == "":
				continue

			if clean_name == normalize_name(owner_name):
				continue

			player_roles[clean_name] = role
			if not allowed_players.has(clean_name):
				allowed_players.append(clean_name)

	var saved_allowed = data.get("allowed_players", [])

	if saved_allowed is Array:
		for value in saved_allowed:
			var clean_name: String = normalize_name(str(value))

			if clean_name == "":
				continue

			if clean_name == normalize_name(owner_name):
				continue

			if not allowed_players.has(clean_name):
				allowed_players.append(clean_name)
			if not player_roles.has(clean_name):
				player_roles[clean_name] = ROLE_BUILDER

	var cleanup: Array = []
	for raw_name in player_roles.keys():
		if not allowed_players.has(raw_name):
			cleanup.append(raw_name)
	for clean_name in cleanup:
		player_roles.erase(clean_name)

	allowed_players.sort()
	ensure_owner_name()

	if world != null and world.block_manager != null and world.block_manager.has_method("refresh_all_wooden_entrance_collisions"):
		world.block_manager.refresh_all_wooden_entrance_collisions()

	if world != null and world.world_lock_ui != null and world.world_lock_ui.has_method("refresh") and world.world_lock_ui.has_method("is_open"):
		if world.world_lock_ui.is_open():
			world.world_lock_ui.refresh()


func send_network_world_lock_state():
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		var owner_verified_name: String = _get_active_session_username()
		if owner_verified_name == "":
			owner_verified_name = owner_name

		var payload = {
			"action": "world_lock_state",
			"state": get_save_data(),
			"requested_by": owner_verified_name,
			"owner_verified": _is_local_owner_session_verified(),
			"strict_mode": _is_strict_security_mode()
		}
		network.send_world_interaction_update(payload, world.current_world_name)


func request_save():
	# No save_manager.gd changes. This only calls the existing world save method
	# if your project already has it.
	if world != null and world.has_method("save_world"):
		world.save_world()
