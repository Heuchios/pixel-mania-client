extends "res://Scripts/trade_ui.gd"
func get_local_player_id() -> String: return "local"
func get_item_texture(_id: String, _category: String): return load("res://Assets/items/fish/crystal_fish.png")
