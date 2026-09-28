extends SceneTree

const Commands = preload("res://Scripts/command_manager.gd")

class FakeNetwork extends Node:
	var sent: Array[String] = []
	var connected := true
	func send_chat_message(message: String) -> bool:
		if not connected:
			return false
		sent.append(message)
		return true

class FakeChat extends RefCounted:
	var messages: Array[String] = []
	func add_chat_message(_sender: String, message: String) -> void:
		messages.append(message)

class FakeWorld extends Node:
	var chat_ui := FakeChat.new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var existing := root.get_node_or_null("NetworkManager")
	if existing != null:
		root.remove_child(existing)
	var network := FakeNetwork.new()
	network.name = "NetworkManager"
	root.add_child(network)
	var world := FakeWorld.new()
	root.add_child(world)
	var commands := Commands.new()
	world.add_child(commands)
	commands.setup(world)
	for command in ["/honors", "/honors today", "/honors yesterday", "/honors overall", "/top overall", "/TOP yesterday"]:
		commands.handle_command(command)
	if network.sent.size() != 6 or network.sent[3] != "/honors overall" or network.sent[5] != "/TOP yesterday":
		printerr("Honors commands did not reach the server for a regular player: ", network.sent)
		quit(1)
		return
	if not world.chat_ui.messages.is_empty():
		printerr("Honors commands were incorrectly rejected: ", world.chat_ui.messages)
		quit(1)
		return
	network.connected = false
	commands.handle_command("/honors")
	if not world.chat_ui.messages.back().contains("Connect to the server"):
		printerr("Missing disconnected honors feedback")
		quit(1)
		return
	commands.show_player_help()
	if not world.chat_ui.messages.back().contains("/honors"):
		quit(1)
		return
	world.free()
	network.free()
	if existing != null:
		root.add_child(existing)
	print("[world-honors-commands] Player routing, aliases, periods, offline feedback, and help passed")
	quit(0)
