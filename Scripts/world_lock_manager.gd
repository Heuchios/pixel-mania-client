extends Node

# PixelMania World Lock Manager v1
# Owns world lock state and permission checks.
# Does not change save_manager.gd. If your existing save system already calls
# world.get_world_lock_save_data() / world.load_world_lock_save_data(), this
# manager will plug into those hooks.

var world = null

var is_locked: bool = false
var owner_name: String = ""
var owner_account_id: String = ""
var owner_player_id: String = ""
var lock_grid_pos: Vector2i = Vector2i(999999, 999999)
var lock_block_type: String = "world_lock"
var allowed_players: Array = []
var allowed_account_ids: Array = []
var allowed_player_ids: Array = []
var player_roles: Dictionary = {}
var player_roles_by_account_id: Dictionary = {}
var player_roles_by_player_id: Dictionary = {}
var public_build: bool = false
var trusted_builder_slot_limit: int = 6
var area_locks: Array = []

const WORLD_LOCK_BLOCK_TYPE = "world_lock"
const SUPER_WORLD_LOCK_BLOCK_TYPE = "super_world_lock"
const LOCK_MOVER_ITEM_TYPE = "lock_mover"
const SMALL_LOCK_BLOCK_TYPE = "small_lock"
const MEDIUM_LOCK_BLOCK_TYPE = "medium_lock"
const BIG_LOCK_BLOCK_TYPE = "big_lock"
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
const AREA_LOCK_TILE_LIMITS = {
	SMALL_LOCK_BLOCK_TYPE: 10,
	MEDIUM_LOCK_BLOCK_TYPE: 48,
	BIG_LOCK_BLOCK_TYPE: 80
}


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


func normalize_identity_id(value) -> String:
	return str(value).strip_edges()


func _identity_ids_match(left, right) -> bool:
	var left_id := normalize_identity_id(left).to_lower()
	var right_id := normalize_identity_id(right).to_lower()
	return left_id != "" and left_id == right_id


func _get_network_manager():
	if world == null:
		return null
	return world.get_node_or_null("/root/NetworkManager")


func _get_active_account_id() -> String:
	var network = _get_network_manager()
	if network != null and network.has_method("get_active_account_id"):
		return normalize_identity_id(network.get_active_account_id())
	return ""


func _get_active_player_profile_id() -> String:
	var network = _get_network_manager()
	if network != null and network.has_method("get_active_profile_id"):
		return normalize_identity_id(network.get_active_profile_id())
	return ""


func _apply_current_owner_identity() -> void:
	var account_id := _get_active_account_id()
	var profile_id := _get_active_player_profile_id()
	if account_id != "":
		owner_account_id = account_id
	if profile_id != "":
		owner_player_id = profile_id


func _is_current_session_owner_identity() -> bool:
	var account_id := _get_active_account_id()
	if account_id != "" and _identity_ids_match(owner_account_id, account_id):
		return true
	var profile_id := _get_active_player_profile_id()
	return profile_id != "" and _identity_ids_match(owner_player_id, profile_id)


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


func normalize_world_lock_block_type(block_type: String) -> String:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == SUPER_WORLD_LOCK_BLOCK_TYPE:
		return SUPER_WORLD_LOCK_BLOCK_TYPE
	return WORLD_LOCK_BLOCK_TYPE


func is_world_lock_block_type(block_type: String) -> bool:
	var clean_type := str(block_type).strip_edges().to_lower()
	return clean_type == WORLD_LOCK_BLOCK_TYPE or clean_type == SUPER_WORLD_LOCK_BLOCK_TYPE


func normalize_area_lock_block_type(block_type: String) -> String:
	var clean_type := str(block_type).strip_edges().to_lower()
	if clean_type == BIG_LOCK_BLOCK_TYPE:
		return BIG_LOCK_BLOCK_TYPE
	if clean_type == MEDIUM_LOCK_BLOCK_TYPE:
		return MEDIUM_LOCK_BLOCK_TYPE
	if clean_type == SMALL_LOCK_BLOCK_TYPE:
		return SMALL_LOCK_BLOCK_TYPE
	return ""


func is_area_lock_block_type(block_type: String) -> bool:
	return normalize_area_lock_block_type(block_type) != ""


func get_area_lock_tile_limit(block_type: String) -> int:
	return int(AREA_LOCK_TILE_LIMITS.get(normalize_area_lock_block_type(block_type), 0))


func make_area_lock_id(grid_pos: Vector2i, block_type: String) -> String:
	var clean_type := normalize_area_lock_block_type(block_type)
	if clean_type == "":
		clean_type = SMALL_LOCK_BLOCK_TYPE
	return clean_type + ":" + str(grid_pos.x) + ":" + str(grid_pos.y)


func get_lock_block_type() -> String:
	return normalize_world_lock_block_type(lock_block_type)


func is_super_world_lock_active() -> bool:
	return is_locked and get_lock_block_type() == SUPER_WORLD_LOCK_BLOCK_TYPE


func refresh_world_lock_block_visual() -> void:
	if world == null or world.block_manager == null:
		return
	if not is_locked:
		return
	if lock_grid_pos.x >= WORLD_LOCK_GRID_SENTINEL or lock_grid_pos.y >= WORLD_LOCK_GRID_SENTINEL:
		return
	if not world.blocks.has(lock_grid_pos):
		return
	if world.block_manager.has_method("normalize_block_variant_at"):
		world.block_manager.normalize_block_variant_at(lock_grid_pos, false)


func _reset_world_lock_state() -> void:
	is_locked = false
	owner_name = ""
	owner_account_id = ""
	owner_player_id = ""
	lock_grid_pos = Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL)
	lock_block_type = WORLD_LOCK_BLOCK_TYPE
	allowed_players.clear()
	allowed_account_ids.clear()
	allowed_player_ids.clear()
	player_roles.clear()
	player_roles_by_account_id.clear()
	player_roles_by_player_id.clear()
	public_build = false
	trusted_builder_slot_limit = DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT


func _scan_world_lock_blocks() -> Dictionary:
	var result := {
		"found": false,
		"multiple": false,
		"grid_pos": Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL),
		"block_type": WORLD_LOCK_BLOCK_TYPE
	}
	if world == null:
		return result

	for raw_grid_pos in world.blocks.keys():
		if not (raw_grid_pos is Vector2i):
			continue
		var grid_pos: Vector2i = raw_grid_pos
		var block_data = world.blocks.get(raw_grid_pos, {})
		if not (block_data is Dictionary):
			continue
		var block_type := str(block_data.get("type", ""))
		if not is_world_lock_block_type(block_type):
			continue
		if bool(result.get("found", false)):
			result["multiple"] = true
			return result
		result["found"] = true
		result["grid_pos"] = grid_pos
		result["block_type"] = normalize_world_lock_block_type(block_type)

	return result


func reconcile_world_lock_state_with_blocks() -> bool:
	if world == null or not is_locked:
		return false

	var changed := false
	if world.blocks.has(lock_grid_pos):
		var current_block = world.blocks.get(lock_grid_pos, {})
		if current_block is Dictionary:
			var current_block_type := str(current_block.get("type", ""))
			if is_world_lock_block_type(current_block_type):
				var normalized_type := normalize_world_lock_block_type(current_block_type)
				if lock_block_type != normalized_type:
					lock_block_type = normalized_type
					changed = true
				return changed

	var scan := _scan_world_lock_blocks()
	if not bool(scan.get("found", false)):
		_reset_world_lock_state()
		return true

	if bool(scan.get("multiple", false)):
		return false

	var raw_found_pos = scan.get("grid_pos", Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL))
	var found_pos := Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL)
	if raw_found_pos is Vector2i:
		found_pos = raw_found_pos
	var found_type := normalize_world_lock_block_type(str(scan.get("block_type", WORLD_LOCK_BLOCK_TYPE)))
	if lock_grid_pos != found_pos:
		lock_grid_pos = found_pos
		changed = true
	if lock_block_type != found_type:
		lock_block_type = found_type
		changed = true
	return changed


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

	if _is_current_session_owner_identity():
		return true

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
	var session_name := _get_active_session_username()
	if session_name != "":
		return session_name

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
	if (owner_account_id == "" or owner_player_id == "") and normalize_name(owner_name) == normalize_name(get_current_player_name()):
		_apply_current_owner_identity()


func is_owner(player_name: String) -> bool:
	if not is_locked:
		return false

	ensure_owner_name()
	return normalize_name(player_name) == normalize_name(owner_name)


func is_current_player_owner() -> bool:
	if _is_strict_security_mode() and not _is_local_player_session_match():
		return false

	if _is_current_session_owner_identity():
		return true

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

	if clean_name == normalize_name(get_current_player_name()) and _is_current_session_owner_identity():
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

	reconcile_world_lock_state_with_blocks()
	if not is_locked:
		return true

	var role: String = get_player_access_role(get_current_player_name())

	if _can_build_with_role(role):
		return true

	if public_build:
		return true

	return false


func can_current_player_configure_door() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return _can_build_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_toggle_door_lock() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_place_block(block_type: String) -> bool:
	if not _is_local_player_session_match():
		return false

	reconcile_world_lock_state_with_blocks()
	if is_world_lock_block_type(block_type):
		return not is_locked and not has_world_lock_block()

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	if is_donation_box_block(block_type):
		return is_locked and is_current_player_owner()

	if is_display_block(block_type):
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

	if is_world_lock_block_type(block_type):
		reconcile_world_lock_state_with_blocks()

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	if is_donation_box_block(block_type):
		return is_locked and is_current_player_owner()

	if is_display_block(block_type):
		return is_locked and is_current_player_owner()

	# The World Lock itself can only be broken by the owner.
	if is_world_lock_block_type(block_type):
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

	if world != null and world.has_method("is_wooden_entrance_block") and world.is_wooden_entrance_block(block_type):
		return can_current_player_toggle_wooden_entrance()

	if is_anti_punch_block(block_type):
		return can_current_player_toggle_anti_punch()

	if is_anti_talk_block(block_type):
		return can_current_player_toggle_anti_talk()

	if is_anti_gravity_block(block_type):
		return can_current_player_toggle_anti_gravity()

	if is_snow_repellent_block(block_type):
		return can_current_player_toggle_anti_gravity()

	if is_theme_machine_block(block_type):
		return is_locked and can_current_player_build()

	if is_cctv_block(block_type):
		return can_current_player_view_cctv()

	if is_oil_refinery_block(block_type):
		return can_current_player_use_oil_refinery()

	if is_battery_charger_block(block_type):
		return can_current_player_use_battery_charger()

	if is_generator_block(block_type):
		return can_current_player_build()

	if is_safe_block(block_type):
		return is_locked and is_current_player_owner()

	if is_donation_box_block(block_type):
		return true

	if is_mailbox_block(block_type):
		return true

	if is_bulletin_board_block(block_type):
		return true

	if is_display_block(block_type):
		return is_locked and is_current_player_owner()

	if is_vending_machine_block(block_type):
		return is_locked

	if is_fish_monger_block(block_type):
		return true

	if not is_locked:
		return true

	# Allow visitors to wrench the lock so they can see who owns the world.
	if is_world_lock_block_type(block_type):
		return true

	var role: String = get_player_access_role(get_current_player_name())
	if role == ROLE_NONE:
		return false

	if is_world_lock_block_type(block_type):
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


func can_current_player_toggle_anti_punch() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_toggle_anti_talk() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))

func can_current_player_toggle_anti_gravity() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_view_cctv() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	if is_current_player_owner():
		return true

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))

func can_current_player_manage_bulletin_board() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	if is_current_player_owner():
		return true

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))

func can_current_player_use_oil_refinery() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return false

	if is_current_player_owner():
		return true

	return _can_toggle_wooden_entrance_with_role(get_player_access_role(get_current_player_name()))


func can_current_player_use_battery_charger() -> bool:
	return can_current_player_use_oil_refinery()


func can_current_player_use_theme_machine_at(grid_pos: Vector2i) -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	var area_lock: Dictionary = get_area_lock_covering_position(grid_pos)
	if not area_lock.is_empty() and can_current_player_build_in_area_lock(area_lock):
		return true

	return is_locked and can_current_player_build()


func can_current_player_bypass_anti_talk() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return get_player_access_role(get_current_player_name()) != ROLE_NONE


func can_current_player_pass_wooden_entrance() -> bool:
	if _is_current_session_server_admin():
		return true

	if not _is_local_player_session_match():
		return false

	if not is_locked:
		return true

	return get_player_access_role(get_current_player_name()) != ROLE_NONE


func can_current_player_pass_door() -> bool:
	return can_current_player_pass_wooden_entrance()


func is_vending_machine_block(block_type: String) -> bool:
	return block_type == "vend_empty" or block_type == "vend_pending" or block_type == "vend_sold"


func is_safe_block(block_type: String) -> bool:
	return block_type == "safe"


func is_donation_box_block(block_type: String) -> bool:
	if world != null and world.has_method("is_donation_box_block_type"):
		return bool(world.is_donation_box_block_type(block_type))
	return block_type.strip_edges().to_lower() == "donation_box"


func is_mailbox_block(block_type: String) -> bool:
	if world != null and world.has_method("is_mailbox_block_type"):
		return bool(world.is_mailbox_block_type(block_type))
	return block_type == "mail_box" or block_type == "blue_mail_box"

func is_bulletin_board_block(block_type: String) -> bool:
	if world != null and world.has_method("is_bulletin_board_block_type"):
		return bool(world.is_bulletin_board_block_type(block_type))
	return block_type == "bulletin_board"


func is_display_block(block_type: String) -> bool:
	if world != null and world.has_method("is_display_block_type"):
		return bool(world.is_display_block_type(block_type))
	return block_type == "display_box" or block_type == "display_case"


func is_anti_punch_block(block_type: String) -> bool:
	if world != null and world.has_method("is_anti_punch_block_type"):
		return bool(world.is_anti_punch_block_type(block_type))
	return block_type == "anti_punch"


func is_anti_talk_block(block_type: String) -> bool:
	if world != null and world.has_method("is_anti_talk_block_type"):
		return bool(world.is_anti_talk_block_type(block_type))
	return block_type == "anti_talk"


func is_anti_gravity_block(block_type: String) -> bool:
	if world != null and world.has_method("is_anti_gravity_block_type"):
		return bool(world.is_anti_gravity_block_type(block_type))
	return block_type == "anti_gravity"


func is_snow_repellent_block(block_type: String) -> bool:
	if world != null and world.has_method("is_snow_repellent_block_type"):
		return bool(world.is_snow_repellent_block_type(block_type))
	return block_type == "snow_repellent"


func is_theme_machine_block(block_type: String) -> bool:
	if world != null and world.has_method("is_theme_machine_block_type"):
		return bool(world.is_theme_machine_block_type(block_type))
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("theme_machine_block", false))
	var clean_type := block_type.strip_edges().to_lower()
	return clean_type == "night_theme_machine" or clean_type == "snow_theme_machine" or clean_type == "theme_machine"


func is_cctv_block(block_type: String) -> bool:
	if world != null and world.has_method("is_cctv_block_type"):
		return bool(world.is_cctv_block_type(block_type))
	return block_type == "cctv"

func is_oil_refinery_block(block_type: String) -> bool:
	if world != null and world.has_method("is_oil_refinery_block_type"):
		return bool(world.is_oil_refinery_block_type(block_type))
	return block_type == "oil_refinery"


func is_battery_charger_block(block_type: String) -> bool:
	if world != null and world.has_method("is_battery_charger_block_type"):
		return bool(world.is_battery_charger_block_type(block_type))
	return block_type == "battery_charger"


func is_generator_block(block_type: String) -> bool:
	var clean := str(block_type).strip_edges().to_lower()
	if clean == "generator" or clean == "transformer":
		return true
	if world != null and world.item_database.has(clean):
		return str(world.item_database[clean].get("electrical_device_type", "")).strip_edges().to_lower() == "generator"
	return false


func is_fish_monger_block(block_type: String) -> bool:
	return block_type == "fish_monger"


func has_world_lock_block() -> bool:
	if world == null:
		return false

	for grid_pos in world.blocks.keys():
		var block_data = world.blocks.get(grid_pos, {})
		if not (block_data is Dictionary):
			continue

		if is_world_lock_block_type(str(block_data.get("type", ""))):
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
		if is_safe_block(block_type) or is_vending_machine_block(block_type) or is_fish_monger_block(block_type) or is_display_block(block_type):
			return true

	return false


func on_world_lock_block_placed(grid_pos: Vector2i, block_type: String = WORLD_LOCK_BLOCK_TYPE):
	if not _is_local_player_session_match():
		if world != null and world.has_method("show_notification"):
			world.show_notification("World lock placement blocked: session verification required.")
		return

	reconcile_world_lock_state_with_blocks()
	if is_locked:
		if lock_grid_pos == grid_pos and get_lock_block_type() == normalize_world_lock_block_type(block_type):
			return
		if world != null and world.has_method("show_notification"):
			world.show_notification("This world already has a World Lock.")
		return

	is_locked = true
	owner_name = get_current_player_name()
	_apply_current_owner_identity()
	lock_grid_pos = grid_pos
	lock_block_type = normalize_world_lock_block_type(block_type)
	public_build = false
	trusted_builder_slot_limit = DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT
	allowed_players.clear()
	allowed_account_ids.clear()
	allowed_player_ids.clear()
	player_roles.clear()
	player_roles_by_account_id.clear()
	player_roles_by_player_id.clear()

	if world != null and world.has_method("show_notification"):
		world.show_notification("World locked by " + owner_name + ".")

	refresh_world_lock_block_visual()
	send_network_world_lock_state()
	request_save()


func on_world_lock_block_broken(grid_pos: Vector2i):
	if not _is_local_player_session_match():
		if world != null and world.has_method("show_notification"):
			world.show_notification("World lock break blocked: session verification required.")
		return

	if not is_locked:
		return

	var should_clear_lock := grid_pos == lock_grid_pos
	if not should_clear_lock:
		var scan := _scan_world_lock_blocks()
		should_clear_lock = not bool(scan.get("found", false))

	if not should_clear_lock:
		return

	var old_owner: String = owner_name
	_reset_world_lock_state()

	if world != null and world.has_method("show_notification"):
		world.show_notification("World Lock removed. Previous owner: " + old_owner + ".")

	send_network_world_lock_state()
	request_save()


func use_lock_mover_at_mouse():
	if world == null:
		return

	if not world.tool_inventory.has(LOCK_MOVER_ITEM_TYPE) or int(world.tool_inventory[LOCK_MOVER_ITEM_TYPE]) <= 0:
		if world.has_method("show_notification"):
			world.show_notification("You do not have a Lock Mover.")
		return

	var target_grid: Vector2i = world.get_mouse_grid_position()

	if not world.is_grid_inside_world(target_grid):
		world.show_notification("Outside world bounds.")
		return

	if not world.can_reach_grid(target_grid):
		world.show_notification("Too far away.")
		return

	if should_request_server_world_lock_move():
		if can_move_world_lock_to(target_grid):
			request_server_world_lock_move(target_grid)
		return

	if move_world_lock_to(target_grid):
		world.tool_inventory[LOCK_MOVER_ITEM_TYPE] = max(0, int(world.tool_inventory[LOCK_MOVER_ITEM_TYPE]) - 1)

		if int(world.tool_inventory[LOCK_MOVER_ITEM_TYPE]) <= 0 and world.selected_item_type == LOCK_MOVER_ITEM_TYPE:
			world.selected_item_type = world.primary_hotbar_tool
			world.selected_item_category = "tool"

		world.update_all_ui()


func should_request_server_world_lock_move() -> bool:
	if world == null:
		return false

	if world.has_method("should_use_server_authoritative_world_actions"):
		return bool(world.should_use_server_authoritative_world_actions())

	return false


func request_server_world_lock_move(new_lock_pos: Vector2i) -> bool:
	if lock_grid_pos == Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL):
		world.show_notification("World Lock block missing.")
		return false

	var network = world.get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("send_world_interaction_update"):
		world.show_notification("Connection required.")
		return false

	if not bool(network.send_world_interaction_update({
		"action": "world_lock_move",
		"old_x": lock_grid_pos.x,
		"old_y": lock_grid_pos.y,
		"x": new_lock_pos.x,
		"y": new_lock_pos.y
	}, world.current_world_name)):
		world.show_notification("Almost ready. Try again in a moment.")
		return false

	world.show_notification("Moving World Lock...")
	return true


func can_move_world_lock_to(new_lock_pos: Vector2i) -> bool:
	if world == null:
		return false

	if not is_locked:
		world.show_notification("This world does not have a World Lock.")
		return false

	if not is_current_player_owner():
		world.show_notification("Only the world lock owner can move the lock.")
		return false

	if _is_strict_security_mode() and not _is_local_owner_session_verified():
		world.show_notification("Owner identity could not be verified. Re-sign in as the world owner account.")
		return false

	if new_lock_pos == lock_grid_pos:
		world.show_notification("World Lock is already here.")
		return false

	if lock_grid_pos == Vector2i(WORLD_LOCK_GRID_SENTINEL, WORLD_LOCK_GRID_SENTINEL):
		world.show_notification("World Lock block missing.")
		return false

	if not world.blocks.has(lock_grid_pos) or not is_world_lock_block_type(str(world.blocks[lock_grid_pos].get("type", ""))):
		world.show_notification("World Lock block missing.")
		return false

	if world.blocks.has(new_lock_pos):
		world.show_notification("That spot is already occupied.")
		return false

	if world.has_method("has_planted_seed") and world.has_planted_seed(new_lock_pos):
		world.show_notification("A seed is already planted there.")
		return false

	if world.has_method("is_block_inside_player") and world.is_block_inside_player(new_lock_pos):
		world.show_notification("Move away from that spot first.")
		return false

	if world.block_manager != null and world.block_manager.has_method("get_block_collision_rect_for_grid") and world.block_manager.has_method("does_rect_overlap_reserved_object"):
		var collision_rect: Rect2 = world.block_manager.get_block_collision_rect_for_grid(new_lock_pos, get_lock_block_type())
		if bool(world.block_manager.does_rect_overlap_reserved_object(collision_rect, lock_grid_pos)):
			world.show_notification("Need enough empty space.")
			return false

	return true


func move_world_lock_to(new_lock_pos: Vector2i) -> bool:
	if not can_move_world_lock_to(new_lock_pos):
		return false

	var old_lock_pos: Vector2i = lock_grid_pos
	var moved_lock_type: String = get_lock_block_type()

	world.remove_block_without_drop(old_lock_pos)
	world.create_block(new_lock_pos, moved_lock_type)

	lock_grid_pos = new_lock_pos
	lock_block_type = normalize_world_lock_block_type(moved_lock_type)

	refresh_world_lock_block_visual()
	if world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()
	if world.has_method("show_notification"):
		world.show_notification("World Lock moved.")
	request_save()
	return true


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


func normalize_area_lock_data(raw_data) -> Dictionary:
	if not (raw_data is Dictionary):
		return {}
	var lock_type := normalize_area_lock_block_type(str(raw_data.get("lock_type", raw_data.get("block_type", ""))))
	if lock_type == "":
		return {}
	var grid_pos := Vector2i(
		int(raw_data.get("lock_grid_x", raw_data.get("x", 0))),
		int(raw_data.get("lock_grid_y", raw_data.get("y", 0)))
	)
	var lock_id := str(raw_data.get("lock_id", "")).strip_edges()
	if lock_id == "":
		lock_id = make_area_lock_id(grid_pos, lock_type)
	var normalized_allowed: Array = []
	var normalized_allowed_account_ids: Array = []
	var normalized_allowed_player_ids: Array = []
	var normalized_roles: Dictionary = {}
	var normalized_roles_by_account_id: Dictionary = {}
	var normalized_roles_by_player_id: Dictionary = {}
	var raw_roles = raw_data.get("player_roles", {})
	if raw_roles is Dictionary:
		for raw_name in raw_roles.keys():
			var clean_name := normalize_name(str(raw_name))
			if clean_name == "":
				continue
			normalized_roles[clean_name] = normalize_role(str(raw_roles.get(raw_name, ROLE_BUILDER)))
	var raw_roles_by_account_id = raw_data.get("player_roles_by_account_id", {})
	if raw_roles_by_account_id is Dictionary:
		for raw_id in raw_roles_by_account_id.keys():
			var clean_id := normalize_identity_id(raw_id)
			if clean_id == "":
				continue
			normalized_roles_by_account_id[clean_id] = normalize_role(str(raw_roles_by_account_id.get(raw_id, ROLE_BUILDER)))
	var raw_roles_by_player_id = raw_data.get("player_roles_by_player_id", {})
	if raw_roles_by_player_id is Dictionary:
		for raw_id in raw_roles_by_player_id.keys():
			var clean_id := normalize_identity_id(raw_id)
			if clean_id == "":
				continue
			normalized_roles_by_player_id[clean_id] = normalize_role(str(raw_roles_by_player_id.get(raw_id, ROLE_BUILDER)))
	var raw_allowed = raw_data.get("allowed_players", [])
	if raw_allowed is Array:
		for raw_name in raw_allowed:
			var clean_name := normalize_name(str(raw_name))
			if clean_name == "" or normalized_allowed.has(clean_name):
				continue
			normalized_allowed.append(clean_name)
			if not normalized_roles.has(clean_name):
				normalized_roles[clean_name] = ROLE_BUILDER
	var raw_allowed_account_ids = raw_data.get("allowed_account_ids", [])
	if raw_allowed_account_ids is Array:
		for raw_id in raw_allowed_account_ids:
			var clean_id := normalize_identity_id(raw_id)
			if clean_id == "" or normalized_allowed_account_ids.has(clean_id):
				continue
			normalized_allowed_account_ids.append(clean_id)
			if not normalized_roles_by_account_id.has(clean_id):
				normalized_roles_by_account_id[clean_id] = ROLE_BUILDER
	var raw_allowed_player_ids = raw_data.get("allowed_player_ids", [])
	if raw_allowed_player_ids is Array:
		for raw_id in raw_allowed_player_ids:
			var clean_id := normalize_identity_id(raw_id)
			if clean_id == "" or normalized_allowed_player_ids.has(clean_id):
				continue
			normalized_allowed_player_ids.append(clean_id)
			if not normalized_roles_by_player_id.has(clean_id):
				normalized_roles_by_player_id[clean_id] = ROLE_BUILDER
	normalized_allowed.sort()
	normalized_allowed_account_ids.sort()
	normalized_allowed_player_ids.sort()
	var area_owner_name := normalize_name(str(raw_data.get("owner_name", raw_data.get("owner_username", ""))))
	var area_owner_account_id := normalize_identity_id(raw_data.get("owner_account_id", raw_data.get("account_id", "")))
	var area_owner_player_id := normalize_identity_id(raw_data.get("owner_player_id", raw_data.get("owner_profile_id", raw_data.get("profile_id", ""))))
	var raw_locked_positions = raw_data.get("locked_positions", raw_data.get("protected_positions", raw_data.get("connected_positions", [])))
	return {
		"lock_id": lock_id,
		"lock_type": lock_type,
		"owner_name": area_owner_name,
		"owner_account_id": area_owner_account_id,
		"owner_player_id": area_owner_player_id,
		"owner_profile_id": area_owner_player_id,
		"lock_grid_x": grid_pos.x,
		"lock_grid_y": grid_pos.y,
		"max_tiles": get_area_lock_tile_limit(lock_type),
		"public_build": bool(raw_data.get("public_build", false)),
		"ignore_empty_space": bool(raw_data.get("ignore_empty_space", false)),
		"locked_positions": _normalize_area_lock_positions(raw_locked_positions),
		"allowed_players": normalized_allowed,
		"allowed_account_ids": normalized_allowed_account_ids,
		"allowed_player_ids": normalized_allowed_player_ids,
		"player_roles": normalized_roles,
		"player_roles_by_account_id": normalized_roles_by_account_id,
		"player_roles_by_player_id": normalized_roles_by_player_id
	}


func _normalize_area_lock_positions(raw_positions) -> Array:
	var normalized: Array = []
	var seen := {}
	if not (raw_positions is Array):
		return normalized
	for raw_pos in raw_positions:
		var pos: Vector2i = _coerce_area_lock_position(raw_pos)
		if pos.x == -2147483648 and pos.y == -2147483648:
			continue
		var key := str(pos.x) + ":" + str(pos.y)
		if seen.has(key):
			continue
		seen[key] = true
		normalized.append(pos)
	return normalized


func _coerce_area_lock_position(raw_pos) -> Vector2i:
	if raw_pos is Vector2i:
		return raw_pos
	if raw_pos is Dictionary:
		var raw_x = raw_pos.get("x", raw_pos.get("grid_x", -2147483648))
		var raw_y = raw_pos.get("y", raw_pos.get("grid_y", -2147483648))
		if (raw_x is int or raw_x is float) and (raw_y is int or raw_y is float):
			return Vector2i(int(raw_x), int(raw_y))
		return Vector2i(-2147483648, -2147483648)
	if raw_pos is Array and raw_pos.size() >= 2 and (raw_pos[0] is int or raw_pos[0] is float) and (raw_pos[1] is int or raw_pos[1] is float):
		return Vector2i(int(raw_pos[0]), int(raw_pos[1]))
	return Vector2i(-2147483648, -2147483648)


func _area_lock_snapshot_positions(area_lock: Dictionary) -> Array:
	return _normalize_area_lock_positions(area_lock.get("locked_positions", []))


func get_area_locks_save_data() -> Array:
	var saved: Array = []
	for raw_lock in area_locks:
		var area_lock := normalize_area_lock_data(raw_lock)
		if not area_lock.is_empty():
			saved.append(area_lock)
	return saved


func load_area_locks_save_data(raw_data) -> void:
	area_locks.clear()
	var source: Array = []
	if raw_data is Array:
		source = raw_data
	elif raw_data is Dictionary:
		if raw_data.get("area_locks", []) is Array:
			source = raw_data.get("area_locks", [])
		elif raw_data.get("locks", []) is Array:
			source = raw_data.get("locks", [])
	var seen := {}
	for raw_lock in source:
		var area_lock := normalize_area_lock_data(raw_lock)
		if area_lock.is_empty():
			continue
		var lock_id := str(area_lock.get("lock_id", ""))
		if seen.has(lock_id):
			continue
		seen[lock_id] = true
		area_locks.append(area_lock)
	refresh_area_lock_highlight_overlay()
	refresh_area_lock_block_visuals()


func refresh_area_lock_highlight_overlay() -> void:
	if world != null and world.has_method("refresh_area_lock_highlight_overlay"):
		world.refresh_area_lock_highlight_overlay()


func refresh_area_lock_block_visuals() -> void:
	if world == null or world.block_manager == null:
		return
	if not world.block_manager.has_method("normalize_block_variant_at"):
		return

	for raw_lock in area_locks:
		var area_lock := normalize_area_lock_data(raw_lock)
		if area_lock.is_empty():
			continue
		var grid_pos := Vector2i(
			int(area_lock.get("lock_grid_x", WORLD_LOCK_GRID_SENTINEL)),
			int(area_lock.get("lock_grid_y", WORLD_LOCK_GRID_SENTINEL))
		)
		if grid_pos.x >= WORLD_LOCK_GRID_SENTINEL or grid_pos.y >= WORLD_LOCK_GRID_SENTINEL:
			continue
		if world.blocks.has(grid_pos):
			world.block_manager.normalize_block_variant_at(grid_pos, false)


func get_area_lock_for_lock_id(lock_id: String) -> Dictionary:
	var clean_id := lock_id.strip_edges()
	for raw_lock in area_locks:
		var area_lock := normalize_area_lock_data(raw_lock)
		if str(area_lock.get("lock_id", "")) == clean_id:
			return area_lock
	return {}


func get_area_lock_for_lock_position(grid_pos: Vector2i) -> Dictionary:
	for raw_lock in area_locks:
		var area_lock := normalize_area_lock_data(raw_lock)
		if int(area_lock.get("lock_grid_x", WORLD_LOCK_GRID_SENTINEL)) == grid_pos.x and int(area_lock.get("lock_grid_y", WORLD_LOCK_GRID_SENTINEL)) == grid_pos.y:
			return area_lock
	return {}


func get_area_lock_positions(area_lock: Dictionary) -> Array:
	if bool(area_lock.get("ignore_empty_space", false)):
		var snapshot_positions: Array = _area_lock_snapshot_positions(area_lock)
		if snapshot_positions.size() > 0:
			return snapshot_positions
		return get_area_lock_connected_block_positions(area_lock)

	var center: Vector2i = Vector2i(int(area_lock.get("lock_grid_x", 0)), int(area_lock.get("lock_grid_y", 0)))
	var max_tiles: int = max(1, int(area_lock.get("max_tiles", get_area_lock_tile_limit(str(area_lock.get("lock_type", ""))))))
	var candidates: Array = []
	var radius := 0
	while candidates.size() < max_tiles and radius < 32:
		candidates.clear()
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var pos: Vector2i = Vector2i(x, y)
				var dist: int = abs(pos.x - center.x) + abs(pos.y - center.y)
				if dist <= radius:
					candidates.append({"pos": pos, "dist": dist})
		radius += 1
	candidates.sort_custom(func(a, b):
		if int(a.get("dist", 0)) != int(b.get("dist", 0)):
			return int(a.get("dist", 0)) < int(b.get("dist", 0))
		var apos: Vector2i = a.get("pos", center)
		var bpos: Vector2i = b.get("pos", center)
		if apos.y != bpos.y:
			return apos.y < bpos.y
		return apos.x < bpos.x
	)
	var positions: Array = []
	for candidate in candidates:
		if positions.size() >= max_tiles:
			break
		positions.append(candidate.get("pos", center))
	return positions


func has_area_lock_chain_block_at(grid_pos: Vector2i, center: Vector2i) -> bool:
	if grid_pos == center:
		return true
	if world == null:
		return false
	if world.blocks.has(grid_pos):
		return true
	if world.block_manager != null:
		var background_blocks_value = world.block_manager.get("background_blocks")
		if background_blocks_value is Dictionary and background_blocks_value.has(grid_pos):
			return true
	return false


func get_area_lock_connected_block_positions(area_lock: Dictionary) -> Array:
	var center: Vector2i = Vector2i(int(area_lock.get("lock_grid_x", 0)), int(area_lock.get("lock_grid_y", 0)))
	var max_tiles: int = max(1, int(area_lock.get("max_tiles", get_area_lock_tile_limit(str(area_lock.get("lock_type", ""))))))
	var positions: Array = []
	var queue: Array = [center]
	var visited: Dictionary = {str(center.x) + ":" + str(center.y): true}
	var directions: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty() and positions.size() < max_tiles:
		var current: Vector2i = queue.pop_front()
		if not has_area_lock_chain_block_at(current, center):
			continue
		positions.append(current)
		for raw_direction in directions:
			var direction: Vector2i = raw_direction
			var next_pos: Vector2i = current + direction
			var key: String = str(next_pos.x) + ":" + str(next_pos.y)
			if visited.has(key):
				continue
			visited[key] = true
			if has_area_lock_chain_block_at(next_pos, center):
				queue.append(next_pos)

	return positions


func get_area_lock_covering_position(grid_pos: Vector2i) -> Dictionary:
	for raw_lock in area_locks:
		var area_lock := normalize_area_lock_data(raw_lock)
		if area_lock.is_empty():
			continue
		if get_area_lock_positions(area_lock).has(grid_pos):
			return area_lock
	return {}


func get_area_lock_access_list(area_lock: Dictionary) -> Array:
	var entries: Array = []
	var raw_allowed = area_lock.get("allowed_players", [])
	var raw_roles = area_lock.get("player_roles", {})
	if not (raw_allowed is Array):
		return entries
	for raw_name in raw_allowed:
		var clean_name := normalize_name(str(raw_name))
		if clean_name == "":
			continue
		var role := ROLE_BUILDER
		if raw_roles is Dictionary:
			role = normalize_role(str(raw_roles.get(clean_name, ROLE_BUILDER)))
		entries.append({"name": clean_name, "role": role})
	entries.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return entries


func get_area_lock_player_role(area_lock: Dictionary, player_name: String) -> String:
	var clean_name := normalize_name(player_name)
	if clean_name == "":
		return ROLE_VISITOR
	if clean_name == normalize_name(str(area_lock.get("owner_name", ""))):
		return ROLE_OWNER
	if clean_name == normalize_name(get_current_player_name()):
		if _identity_ids_match(area_lock.get("owner_account_id", ""), _get_active_account_id()):
			return ROLE_OWNER
		if _identity_ids_match(area_lock.get("owner_player_id", area_lock.get("owner_profile_id", "")), _get_active_player_profile_id()):
			return ROLE_OWNER
		var roles_by_account_id = area_lock.get("player_roles_by_account_id", {})
		var active_account_id := _get_active_account_id()
		if active_account_id != "" and roles_by_account_id is Dictionary and roles_by_account_id.has(active_account_id):
			return normalize_role(str(roles_by_account_id.get(active_account_id, ROLE_VISITOR)))
		var roles_by_player_id = area_lock.get("player_roles_by_player_id", {})
		var active_player_id := _get_active_player_profile_id()
		if active_player_id != "" and roles_by_player_id is Dictionary and roles_by_player_id.has(active_player_id):
			return normalize_role(str(roles_by_player_id.get(active_player_id, ROLE_VISITOR)))
	var raw_roles = area_lock.get("player_roles", {})
	if raw_roles is Dictionary:
		return normalize_role(str(raw_roles.get(clean_name, ROLE_VISITOR)))
	return ROLE_VISITOR


func can_current_player_manage_area_lock(area_lock: Dictionary) -> bool:
	if area_lock.is_empty():
		return false
	if _is_current_session_server_admin() or is_current_player_owner():
		return true
	if _identity_ids_match(area_lock.get("owner_account_id", ""), _get_active_account_id()):
		return true
	if _identity_ids_match(area_lock.get("owner_player_id", area_lock.get("owner_profile_id", "")), _get_active_player_profile_id()):
		return true
	return normalize_name(get_current_player_name()) == normalize_name(str(area_lock.get("owner_name", "")))


func can_current_player_build_in_area_lock(area_lock: Dictionary) -> bool:
	if area_lock.is_empty():
		return true
	if can_current_player_manage_area_lock(area_lock):
		return true
	if bool(area_lock.get("public_build", false)):
		return true
	var role := get_area_lock_player_role(area_lock, get_current_player_name())
	return role == ROLE_ADMIN or role == ROLE_BUILDER


func can_current_player_build_at(grid_pos: Vector2i) -> bool:
	if is_locked and not can_current_player_build():
		return false
	var area_lock: Dictionary = get_area_lock_covering_position(grid_pos)
	if area_lock.is_empty():
		return true
	return can_current_player_build_in_area_lock(area_lock)


func can_current_player_place_block_at(block_type: String, grid_pos: Vector2i) -> bool:
	if not can_current_player_place_block(block_type):
		return false
	if is_area_lock_block_type(block_type) and not is_area_lock_area_available(grid_pos, block_type):
		return false
	return can_current_player_build_at(grid_pos)


func can_current_player_break_block_at(block_type: String = "", grid_pos: Vector2i = Vector2i.ZERO) -> bool:
	if is_area_lock_block_type(block_type):
		return can_current_player_manage_area_lock(get_area_lock_for_lock_position(grid_pos))
	if not can_current_player_break_block(block_type):
		return false
	return can_current_player_build_at(grid_pos)


func can_current_player_interact_with_block_at(block_type: String, grid_pos: Vector2i) -> bool:
	if is_area_lock_block_type(block_type):
		return true
	if is_donation_box_block(block_type):
		return can_current_player_interact_with_block(block_type)
	if is_theme_machine_block(block_type):
		return can_current_player_use_theme_machine_at(grid_pos)
	if not can_current_player_interact_with_block(block_type):
		return false
	var area_lock: Dictionary = get_area_lock_covering_position(grid_pos)
	return area_lock.is_empty() or can_current_player_build_in_area_lock(area_lock)


func is_area_lock_area_available(grid_pos: Vector2i, block_type: String) -> bool:
	var preview := {
		"lock_type": normalize_area_lock_block_type(block_type),
		"lock_grid_x": grid_pos.x,
		"lock_grid_y": grid_pos.y,
		"max_tiles": get_area_lock_tile_limit(block_type)
	}
	for pos in get_area_lock_positions(preview):
		if not get_area_lock_covering_position(pos).is_empty():
			return false
	return true


func on_area_lock_block_placed(grid_pos: Vector2i, block_type: String) -> void:
	var lock_type := normalize_area_lock_block_type(block_type)
	if lock_type == "" or not get_area_lock_for_lock_position(grid_pos).is_empty():
		return
	var area_owner_name := _get_active_session_username()
	if area_owner_name == "":
		area_owner_name = get_current_player_name()
	var area_lock := {
		"lock_id": make_area_lock_id(grid_pos, lock_type),
		"lock_type": lock_type,
		"owner_name": normalize_name(area_owner_name),
		"owner_account_id": _get_active_account_id(),
		"owner_player_id": _get_active_player_profile_id(),
		"owner_profile_id": _get_active_player_profile_id(),
		"lock_grid_x": grid_pos.x,
		"lock_grid_y": grid_pos.y,
		"max_tiles": get_area_lock_tile_limit(lock_type),
		"public_build": false,
		"ignore_empty_space": false,
		"locked_positions": [],
		"allowed_players": [],
		"allowed_account_ids": [],
		"allowed_player_ids": [],
		"player_roles_by_account_id": {},
		"player_roles_by_player_id": {},
		"player_roles": {}
	}
	area_locks.append(area_lock)
	send_network_area_lock_state()
	request_save()
	refresh_area_lock_highlight_overlay()
	refresh_area_lock_block_visuals()


func on_area_lock_block_broken(grid_pos: Vector2i) -> void:
	var removed := false
	for i in range(area_locks.size() - 1, -1, -1):
		var area_lock := normalize_area_lock_data(area_locks[i])
		if int(area_lock.get("lock_grid_x", WORLD_LOCK_GRID_SENTINEL)) == grid_pos.x and int(area_lock.get("lock_grid_y", WORLD_LOCK_GRID_SENTINEL)) == grid_pos.y:
			area_locks.remove_at(i)
			removed = true
	if removed:
		send_network_area_lock_state()
		request_save()
		refresh_area_lock_highlight_overlay()


func set_area_lock_public_build(lock_id: String, enabled: bool) -> bool:
	for i in range(area_locks.size()):
		var area_lock := normalize_area_lock_data(area_locks[i])
		if str(area_lock.get("lock_id", "")) == lock_id and can_current_player_manage_area_lock(area_lock):
			area_lock["public_build"] = enabled
			area_locks[i] = area_lock
			send_network_area_lock_state()
			request_save()
			refresh_area_lock_highlight_overlay()
			refresh_area_lock_block_visuals()
			return true
	return false


func set_area_lock_ignore_empty_space(lock_id: String, enabled: bool) -> bool:
	for i in range(area_locks.size()):
		var area_lock: Dictionary = normalize_area_lock_data(area_locks[i])
		if str(area_lock.get("lock_id", "")) == lock_id and can_current_player_manage_area_lock(area_lock):
			area_lock["ignore_empty_space"] = enabled
			if enabled:
				area_lock["locked_positions"] = get_area_lock_connected_block_positions(area_lock)
			else:
				area_lock["locked_positions"] = []
			area_locks[i] = area_lock
			send_network_area_lock_state()
			request_save()
			refresh_area_lock_highlight_overlay()
			refresh_area_lock_block_visuals()
			return true
	return false


func add_area_lock_access_name(lock_id: String, raw_name, raw_role := ROLE_BUILDER, _verified_target := false) -> bool:
	var target_name := normalize_name(str(raw_name))
	if target_name == "":
		return false
	for i in range(area_locks.size()):
		var area_lock := normalize_area_lock_data(area_locks[i])
		if str(area_lock.get("lock_id", "")) != lock_id or not can_current_player_manage_area_lock(area_lock):
			continue
		if target_name == normalize_name(str(area_lock.get("owner_name", ""))):
			return false
		var allowed: Array = area_lock.get("allowed_players", [])
		if not allowed.has(target_name):
			allowed.append(target_name)
			allowed.sort()
		var roles: Dictionary = area_lock.get("player_roles", {})
		roles[target_name] = normalize_role(str(raw_role))
		area_lock["allowed_players"] = allowed
		area_lock["player_roles"] = roles
		area_locks[i] = area_lock
		send_network_area_lock_state()
		request_save()
		refresh_area_lock_highlight_overlay()
		refresh_area_lock_block_visuals()
		return true
	return false


func remove_area_lock_access_name(lock_id: String, raw_name) -> bool:
	var target_name := normalize_name(str(raw_name))
	for i in range(area_locks.size()):
		var area_lock := normalize_area_lock_data(area_locks[i])
		if str(area_lock.get("lock_id", "")) != lock_id or not can_current_player_manage_area_lock(area_lock):
			continue
		var allowed: Array = area_lock.get("allowed_players", [])
		allowed.erase(target_name)
		var roles: Dictionary = area_lock.get("player_roles", {})
		roles.erase(target_name)
		area_lock["allowed_players"] = allowed
		area_lock["player_roles"] = roles
		area_locks[i] = area_lock
		send_network_area_lock_state()
		request_save()
		refresh_area_lock_highlight_overlay()
		refresh_area_lock_block_visuals()
		return true
	return false


func set_area_lock_player_role(lock_id: String, raw_name, raw_role) -> bool:
	var target_name := normalize_name(str(raw_name))
	for i in range(area_locks.size()):
		var area_lock := normalize_area_lock_data(area_locks[i])
		if str(area_lock.get("lock_id", "")) != lock_id or not can_current_player_manage_area_lock(area_lock):
			continue
		var allowed: Array = area_lock.get("allowed_players", [])
		if not allowed.has(target_name):
			return false
		var roles: Dictionary = area_lock.get("player_roles", {})
		roles[target_name] = normalize_role(str(raw_role))
		area_lock["player_roles"] = roles
		area_locks[i] = area_lock
		send_network_area_lock_state()
		request_save()
		refresh_area_lock_highlight_overlay()
		refresh_area_lock_block_visuals()
		return true
	return false


func get_area_lock_info_text(area_lock: Dictionary) -> String:
	if area_lock.is_empty():
		return "This area is not locked."
	var lock_type := str(area_lock.get("lock_type", ""))
	var display_name := "Small Lock"
	if lock_type == MEDIUM_LOCK_BLOCK_TYPE:
		display_name = "Medium Lock"
	elif lock_type == BIG_LOCK_BLOCK_TYPE:
		display_name = "Big Lock"
	var mode: String = "Public build" if bool(area_lock.get("public_build", false)) else "Trusted only"
	var shape: String = "Connected blocks only" if bool(area_lock.get("ignore_empty_space", false)) else "Full area"
	return "%s\nOwner: %s\nProtected tiles: %d\nMode: %s\nShape: %s" % [
		display_name,
		normalize_name(str(area_lock.get("owner_name", ""))),
		int(area_lock.get("max_tiles", 0)),
		mode,
		shape
	]


func get_save_data() -> Dictionary:
	return {
		"is_locked": is_locked,
		"owner_name": owner_name,
		"owner_account_id": owner_account_id,
		"owner_player_id": owner_player_id,
		"owner_profile_id": owner_player_id,
		"lock_block_type": get_lock_block_type(),
		"lock_type": get_lock_block_type(),
		"lock_grid_x": lock_grid_pos.x,
		"lock_grid_y": lock_grid_pos.y,
		"allowed_players": allowed_players.duplicate(true),
		"allowed_account_ids": allowed_account_ids.duplicate(true),
		"allowed_player_ids": allowed_player_ids.duplicate(true),
		"player_roles": player_roles.duplicate(true),
		"player_roles_by_account_id": player_roles_by_account_id.duplicate(true),
		"player_roles_by_player_id": player_roles_by_player_id.duplicate(true),
		"public_build": public_build,
		"trusted_builder_slot_limit": trusted_builder_slot_limit,
		"area_locks": get_area_locks_save_data()
	}


func load_save_data(data: Dictionary):
	is_locked = bool(data.get("is_locked", false))
	owner_name = normalize_name(str(data.get("owner_name", "")))
	owner_account_id = normalize_identity_id(data.get("owner_account_id", data.get("account_id", "")))
	owner_player_id = normalize_identity_id(data.get("owner_player_id", data.get("owner_profile_id", data.get("profile_id", ""))))
	lock_block_type = normalize_world_lock_block_type(str(data.get("lock_block_type", data.get("lock_type", WORLD_LOCK_BLOCK_TYPE))))
	lock_grid_pos = Vector2i(
		_safe_int(data.get("lock_grid_x", WORLD_LOCK_GRID_SENTINEL), WORLD_LOCK_GRID_SENTINEL, 0, WORLD_LOCK_GRID_SENTINEL),
		_safe_int(data.get("lock_grid_y", WORLD_LOCK_GRID_SENTINEL), WORLD_LOCK_GRID_SENTINEL, 0, WORLD_LOCK_GRID_SENTINEL)
	)
	if not is_locked:
		lock_block_type = WORLD_LOCK_BLOCK_TYPE
		owner_account_id = ""
		owner_player_id = ""
	elif not data.has("lock_block_type") and not data.has("lock_type") and world != null and world.blocks.has(lock_grid_pos):
		var saved_block_type := str(world.blocks[lock_grid_pos].get("type", ""))
		if is_world_lock_block_type(saved_block_type):
			lock_block_type = normalize_world_lock_block_type(saved_block_type)
	public_build = bool(data.get("public_build", false))
	trusted_builder_slot_limit = _normalize_trusted_builder_slot_limit(_safe_int(
		data.get("trusted_builder_slot_limit", DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT),
		DEFAULT_TRUSTED_BUILDER_SLOT_LIMIT,
		MIN_TRUSTED_BUILDER_SLOT_LIMIT,
		MAX_TRUSTED_BUILDER_SLOT_LIMIT
	))

	allowed_players.clear()
	allowed_account_ids.clear()
	allowed_player_ids.clear()
	player_roles.clear()
	player_roles_by_account_id.clear()
	player_roles_by_player_id.clear()

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

	var roles_by_account_data = data.get("player_roles_by_account_id", {})
	if roles_by_account_data is Dictionary:
		for raw_id in roles_by_account_data.keys():
			var clean_id := normalize_identity_id(raw_id)
			var role_by_id := normalize_role(str(roles_by_account_data.get(raw_id, ROLE_BUILDER)))
			if clean_id == "":
				continue
			player_roles_by_account_id[clean_id] = role_by_id
			if not allowed_account_ids.has(clean_id):
				allowed_account_ids.append(clean_id)

	var roles_by_player_data = data.get("player_roles_by_player_id", {})
	if roles_by_player_data is Dictionary:
		for raw_id in roles_by_player_data.keys():
			var clean_id := normalize_identity_id(raw_id)
			var role_by_id := normalize_role(str(roles_by_player_data.get(raw_id, ROLE_BUILDER)))
			if clean_id == "":
				continue
			player_roles_by_player_id[clean_id] = role_by_id
			if not allowed_player_ids.has(clean_id):
				allowed_player_ids.append(clean_id)

	var saved_allowed_account_ids = data.get("allowed_account_ids", [])
	if saved_allowed_account_ids is Array:
		for value in saved_allowed_account_ids:
			var clean_id := normalize_identity_id(value)
			if clean_id == "" or allowed_account_ids.has(clean_id):
				continue
			allowed_account_ids.append(clean_id)
			if not player_roles_by_account_id.has(clean_id):
				player_roles_by_account_id[clean_id] = ROLE_BUILDER

	var saved_allowed_player_ids = data.get("allowed_player_ids", [])
	if saved_allowed_player_ids is Array:
		for value in saved_allowed_player_ids:
			var clean_id := normalize_identity_id(value)
			if clean_id == "" or allowed_player_ids.has(clean_id):
				continue
			allowed_player_ids.append(clean_id)
			if not player_roles_by_player_id.has(clean_id):
				player_roles_by_player_id[clean_id] = ROLE_BUILDER

	var cleanup: Array = []
	for raw_name in player_roles.keys():
		if not allowed_players.has(raw_name):
			cleanup.append(raw_name)
	for clean_name in cleanup:
		player_roles.erase(clean_name)

	allowed_players.sort()
	allowed_account_ids.sort()
	allowed_player_ids.sort()
	if data.has("area_locks"):
		load_area_locks_save_data(data.get("area_locks", []))
	ensure_owner_name()

	if world != null and world.block_manager != null and world.block_manager.has_method("refresh_all_wooden_entrance_collisions"):
		world.block_manager.refresh_all_wooden_entrance_collisions()

	refresh_world_lock_block_visual()

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
		if is_current_player_owner():
			_apply_current_owner_identity()
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


func send_network_area_lock_state():
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		var requester: String = _get_active_session_username()
		if requester == "":
			requester = get_current_player_name()

		var payload = {
			"action": "area_lock_state",
			"state": {"area_locks": get_area_locks_save_data()},
			"requested_by": requester,
			"owner_verified": _is_local_owner_session_verified(),
			"strict_mode": _is_strict_security_mode()
		}
		network.send_world_interaction_update(payload, world.current_world_name)


func request_save():
	# No save_manager.gd changes. This only calls the existing world save method
	# if your project already has it.
	if world != null and world.has_method("save_world"):
		world.save_world()
