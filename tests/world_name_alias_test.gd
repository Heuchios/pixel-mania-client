extends SceneTree

class EntryChat extends Node:
	var messages: Array = []
	func add_chat_message(_sender, message): messages.append(message)

class EntryWorld extends Node:
	var in_world := true
	var current_world_name := "W123456"
	var world_lock_manager = null
	var block_manager = null
	var chat_ui = null
	var notification := ""
	func restore_chat_ui_after_world_enter(): pass
	func update_all_ui(): pass
	func show_notification(message): notification = message

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var network = root.get_node("NetworkManager")
	network.active_join_request_id = "name-join-1"
	network.active_join_world_name = "SHOP"
	assert(network.handle_world_name_redirect({"world":"SHOP","target_world":"W123456","public_name":"SHOP","join_request_id":"name-join-1"}))
	assert(network.current_world_name == "W123456")
	assert(network.active_join_world_name == "W123456")
	assert(network.pending_join_world_name == "SHOP")
	assert(network.pending_join_world_identity == "W123456")
	assert(network.get_public_world_name("W123456") == "SHOP")
	var entry_world := EntryWorld.new()
	root.add_child(entry_world)
	var saver = load("res://Scripts/save_manager.gd").new()
	saver.world = entry_world
	var entry_chat := EntryChat.new()
	entry_world.add_child(entry_chat)
	entry_world.chat_ui = entry_chat
	network.world_entry_active = true
	saver._finish_world_entry_noncritical_work("W123456", false, true)
	assert(entry_world.notification == "Entered world: SHOP", "Entry popup must display the public name")
	assert(entry_chat.messages.is_empty(), "Online entry chat belongs to the network, not save completion")
	network.world_entry_active = false
	saver._send_world_entry_chat_message()
	assert(entry_chat.messages.size() == 1, "Offline entry retains its local notice")
	assert(entry_world.current_world_name == "W123456", "Routing identity must remain unchanged")
	saver.free()
	entry_world.free()
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"SHOP","status":"unowned"}})
	assert(network.get_public_world_name("W123456") == "SHOP", "Creation must retain the entered public name")
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"SHOP","status":"reserved"}})
	assert(network.get_public_world_name("W123456") == "SHOP", "Locking must not generate a public name")
	assert(not network.handle_world_name_redirect({"world":"SHOP","target_world":"BAD","join_request_id":"stale"}))
	network.receive_world_name_status({"world":"W123456","world_name_claim":{"name":"WGENERATED","status":"generated","original_paid_gems":null}})
	assert(network.get_public_world_name("W123456") == "WGENERATED")
	network.world_population_counts = {"W123456": 3}
	assert(network.get_world_population_counts() == {"WGENERATED":3})
	# Typing a released name is a fresh public-name request, never a retry of the old identity.
	network.set_pending_join("SHOP", "alice")
	assert(network.pending_join_world_identity == "")
	assert(network.pending_join_world_name == "SHOP")
	print("WORLD_NAME_ALIAS_TEST_OK")
	quit()
