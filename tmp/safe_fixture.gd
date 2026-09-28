extends "res://Scripts/safe_ui.gd"
var requests := []
func send_safe_request(payload: Dictionary) -> bool:
	requests.append(payload)
	return true
