extends "res://Scripts/inventory_manager.gd"

var conversion_requests: Array[String] = []
var selected_gameplay_items: Array[String] = []
var selection_actions: Array[String] = []


func request_server_world_lock_conversion(direction: String) -> bool:
	conversion_requests.append(direction)
	return true


func _select_inventory_scene_item_for_gameplay(item_type: String, _category: String) -> void:
	selected_gameplay_items.append(item_type)


func refresh_inventory_scene_window(_force_rebuild: bool = false) -> void:
	pass


func update_hotbar():
	pass


func notify_inventory_item_changed(_item_type: String, _category: String, _source: String = INVENTORY_UPDATE_SOURCE_LOCAL) -> void:
	pass


func select_inventory_detail_item(_item_type: String, _category: String):
	pass


func add_context_item_to_trade(item_type: String, _category: String, _amount: int):
	selection_actions.append(item_type)


func _can_inventory_scene_select_item(_item_type: String, _category: String) -> bool:
	return true
