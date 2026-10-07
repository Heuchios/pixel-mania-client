extends "res://Scripts/shop_ui.gd"
func _process(_delta): pass
func get_item_texture(item_id: String):
	return load("res://Assets/items/lures/" + item_id + ".png")
func get_item_display_name(item_id: String) -> String:
	return {"worm_lure":"Worm Bait", "hook":"Bait", "shiny_lure":"Shiny Bait"}.get(item_id, "Long Reward Item Name")
