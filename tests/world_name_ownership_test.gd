extends SceneTree

class TestWorld extends RefCounted:
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}

class TestManager extends "res://Scripts/world_lock_manager.gd":
	var local_owner := true
	func _is_local_player_session_match() -> bool: return true
	func _is_current_session_server_admin() -> bool: return false
	func is_current_player_owner() -> bool: return local_owner
	func refresh_world_lock_block_visual() -> void: pass
	func request_save(): pass
	func send_network_world_lock_state(): pass

func _initialize() -> void:
	var manager := TestManager.new()
	manager.world = TestWorld.new()
	manager.is_locked = true
	manager.persistent_ownership = true
	manager.owner_name = "ALICE"
	manager.public_build = true
	manager.lock_grid_pos = Vector2i(4, 5)
	assert(not manager.reconcile_world_lock_state_with_blocks())
	assert(manager.is_locked)
	manager.on_world_lock_block_broken(Vector2i(4, 5))
	assert(manager.is_locked and manager.owner_name == "ALICE")
	assert(manager.can_current_player_place_block(manager.WORLD_LOCK_BLOCK_TYPE))
	manager.local_owner = false
	assert(not manager.can_current_player_place_block(manager.WORLD_LOCK_BLOCK_TYPE))
	assert(manager.can_current_player_interact_with_block(manager.WORLD_LOCK_BLOCK_TYPE))
	manager.local_owner = true
	manager.on_world_lock_block_placed(Vector2i(8, 9))
	assert(manager.lock_grid_pos == Vector2i(8, 9))
	assert(manager.public_build and manager.owner_name == "ALICE")
	manager.persistent_ownership = false
	manager.on_world_lock_block_broken(Vector2i(8, 9))
	assert(not manager.is_locked, "Removing an unpaid lock must release the world")
	assert(manager.owner_name == "")
	assert(manager.can_current_player_place_block(manager.WORLD_LOCK_BLOCK_TYPE))
	manager.local_owner = false
	assert(manager.can_current_player_place_block(manager.WORLD_LOCK_BLOCK_TYPE), "Anyone may lock the released world")
	manager.free()
	print("WORLD_NAME_OWNERSHIP_TEST_OK")
	quit()
