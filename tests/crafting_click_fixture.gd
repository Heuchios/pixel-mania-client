extends "res://Scripts/crafting_ui.gd"
var requests := 0
func can_craft(_recipe: Dictionary) -> bool:
	return true
func request_server_craft(_recipe: Dictionary) -> bool:
	requests += 1
	return true
