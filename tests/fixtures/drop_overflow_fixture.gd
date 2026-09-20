extends "res://Scripts/drop_manager.gd"
var existing_total := 2000.0
var spawned: Array = []
func should_use_server_authoritative_world_actions() -> bool:
	return true
func get_drop_stack_grid(_position: Vector2) -> Vector2i:
	return Vector2i(5, 6)
func get_drop_total_amount_on_tile(_grid: Vector2i) -> float:
	return existing_total
func get_drop_by_id(_id: String) -> Dictionary:
	return {}
func _create_single_drop(item_type: String, item_category: String, id: String, amount: float, _position: Vector2, grid: Vector2i, _delay: float, sync: bool) -> void:
	spawned.append({"id": id, "amount": amount, "type": item_type, "category": item_category, "grid": grid, "sync": sync})
