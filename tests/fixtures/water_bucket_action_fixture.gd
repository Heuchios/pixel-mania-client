extends "res://Scripts/block_manager.gd"

var requests: Array = []
func is_waiting_for_server_sign_on() -> bool: return false
func should_use_server_authoritative_world_actions() -> bool: return true
func get_anchor_grid_for_block_area(grid: Vector2i) -> Vector2i:
	return grid if world.blocks.has(grid) else world.INVALID_GRID_POS
func face_grid_for_block_punch(_grid: Vector2i) -> bool: return true
func spawn_hand_item_swing_particles_at_grid(_grid: Vector2i, _action: String = "") -> bool: return true
func play_block_break_sound(_grid: Vector2i) -> void: pass
func can_place_water_from_bucket_here(grid: Vector2i) -> bool: return not world.blocks.has(grid)
func send_network_block_update(action: String, layer: String, grid: Vector2i, block_type: String = "", extra: Dictionary = {}) -> bool:
	requests.append({"action": action, "layer": layer, "grid": grid, "block_type": block_type, "extra": extra})
	return true
