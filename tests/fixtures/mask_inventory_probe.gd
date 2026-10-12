extends "res://Scripts/inventory_manager.gd"

var changes := 0

func notify_inventory_item_changed(_item_type: String, _category: String, _source: String = "local") -> void:
	changes += 1
