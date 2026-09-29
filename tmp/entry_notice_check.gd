extends SceneTree

class NoticeWorld extends Node:
	var world_lock_manager
	func handle_network_player_position(_data = {}) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := NoticeWorld.new()
	root.add_child(world)
	current_scene = world
	world.world_lock_manager = load("res://Scripts/world_lock_manager.gd").new()
	world.add_child(world.world_lock_manager)
	var network = root.get_node("NetworkManager")
	world.world_lock_manager.is_locked = true
	world.world_lock_manager.owner_name = "Alice"
	print("System: " + network.build_world_presence_message("Uso", "START", true, 0))
	print("System: " + network.build_world_presence_message("Uso", "START", true, 1))
	world.world_lock_manager.is_locked = false
	print("System: " + network.build_world_presence_message("Uso", "START", true, 3))
	print("System: " + network.build_world_presence_message("Uso", "START", false, 0))
	world.free()
	quit()
