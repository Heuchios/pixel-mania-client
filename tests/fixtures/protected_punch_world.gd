extends "res://tests/void_trident_world_fixture.gd"

var allow_break := false
var near := true
var target := Vector2i(4, 4)
var tree := false
var electrical := false
var swings: Array[String] = []
var notices: Array[String] = []
var animation_count := 0
var sound_count := 0
var public_opened := 0

func can_current_player_break_block_at(_type: String, _grid: Vector2i) -> bool: return allow_break
func can_current_player_build_at(_grid: Vector2i) -> bool: return allow_break
func can_current_player_interact_with_block_at(type: String, _grid: Vector2i) -> bool:
	return allow_break or type in ["fish_monger", "vending_machine"]
func can_reach_grid(_grid: Vector2i) -> bool: return near
func is_grid_inside_world(_grid: Vector2i) -> bool: return true
func get_mouse_grid_position() -> Vector2i: return target
func get_remote_player_at_screen_position(_screen_pos: Vector2) -> Dictionary: return {}
func get_remote_player_in_interaction_range() -> Dictionary: return {}
func get_clicked_planted_seed_grid() -> Vector2i: return target if tree else INVALID_GRID_POS
func has_planted_seed(grid: Vector2i) -> bool: return tree and grid == target
func has_visible_electrical_tile_at(grid: Vector2i) -> bool: return electrical and grid == target
func get_world_locked_message() -> String: return "World locked by RAYAN."
func show_notification(message: String): notices.append(message)
func spawn_hand_item_swing_particles(_position: Vector2 = Vector2(INF, INF), source_tool: String = "") -> bool:
	swings.append(source_tool)
	return true
func play_player_punch_animation(): animation_count += 1
func play_sound_punch(_position: Vector2 = Vector2(INF, INF)): sound_count += 1
func open_fish_monger_ui(_grid: Vector2i): public_opened += 1
func open_vending_ui(_grid: Vector2i): public_opened += 1
