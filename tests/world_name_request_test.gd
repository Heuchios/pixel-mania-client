extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Compile after autoloads register MovementMode, as in normal game startup.
	var capture := GDScript.new()
	capture.source_code = """
extends "res://Scripts/network_manager.gd"
var sent: Array[Dictionary] = []
var authenticated := true
func _ready() -> void: pass
func is_server_session_authenticated() -> bool: return authenticated
func _can_send_rate_limited(_key: String, _limit: int) -> bool: return true
func send_message(data: Dictionary) -> bool:
	sent.append(data.duplicate(true))
	return true
"""
	assert(capture.reload() == OK)
	var network = capture.new()
	root.add_child(network)
	network.current_world_name = "TEST"
	for action in ["world_name_status", "world_name_search", "world_name_reserve", "world_name_claim"]:
		var payload := {"action":action, "world":"TEST", "name":"SHOP", "price_gems":750000}
		assert(network.send_inventory_transaction_request(payload), "Name action must reach transport: " + action)
		assert(network.sent.back().type == "inventory_transaction_request")
		assert(network.sent.back().action == action)
		assert(network.sent.back().world == "TEST")
		assert(network.sent.back().name == "SHOP")
		assert(network.sent.back().price_gems == 750000)
	assert(not network.send_inventory_transaction_request({"action":"world_name_forged"}))
	network.authenticated = false
	assert(not network.send_inventory_transaction_request({"action":"world_name_claim"}))
	assert(network.sent.size() == 4)
	network.free()
	print("WORLD_NAME_REQUEST_TEST_OK")
	quit()
