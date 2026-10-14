extends "res://Scripts/world.gd"

var authoritative := true
var messages: Array[String] = []
var refresh_count := 0


func should_use_server_authoritative_world_actions() -> bool:
	return authoritative


func show_notification(message: String):
	messages.append(message)


func update_all_ui():
	refresh_count += 1


func select_item(item_type: String, category: String):
	selected_item_type = item_type
	selected_item_category = category


func save_player_data():
	pass
