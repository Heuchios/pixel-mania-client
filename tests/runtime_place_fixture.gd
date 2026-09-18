extends "res://Scripts/world.gd"
var uses := 0
func restore_fast_block_place_selection_if_auto_switched(): pass
func is_movement_locked(): return false
func is_fast_block_place_selected_item(): return true
func is_gameplay_ui_at_point(_point: Vector2): return false
func get_pointer_screen_position(): return Vector2.ZERO
func get_mouse_grid_position(): return Vector2i(uses + 1, 0)
func get_fast_block_place_next_grid(_start: Vector2i, target: Vector2i): return target
func is_grid_inside_world(_grid): return true
func can_reach_grid(_grid): return true
func place_block_at_grid_for_fast_hold(_grid: Vector2i): uses += 1
