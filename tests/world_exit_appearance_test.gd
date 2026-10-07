extends SceneTree

class Fixture extends Node2D:
	var in_world := false
	var selected_item_type := "dirt"
	var selected_item_category := "block"
	var equipped_tool := "pickaxe"
	var item_database := {"dirt": {}, "stone": {}}
	var player := Node2D.new()
	var received := {}
	func handle_network_player_position(_data):
		pass
	func get_item_count(_id, _category):
		return 1
	func apply_network_player_state(data):
		received = data.duplicate(true)

class Manager extends "res://Scripts/player_manager.gd":
	func get_local_fishing_sync_key() -> String:
		return ""
	func get_local_damage_flash_sync_key() -> String:
		return ""

class Motion extends Node:
	func get_player_animation_state():
		return "idle"
	func get_player_motion_state():
		return {"in_lava_fire": false}

func _initialize():
	call_deferred("run")

func run():
	var world := Fixture.new()
	root.add_child(world)
	current_scene = world
	world.add_child(world.player)
	var network = root.get_node("NetworkManager")
	network.set_process(false)
	network.handle_inventory_transaction_result({"ok":true, "action":"world_exit_items_auto_remove", "username":"owner", "player_data":{"material_inventory":{}, "tool_inventory":{}}, "inventory_deltas":[{"item_type":"world_lock_key", "after_count":0}]})
	assert(not network.pending_server_player_state.is_empty(), "Exit result must survive inactive/freed world scenes")
	world.in_world = true
	network.apply_pending_server_player_state_if_ready()
	assert(world.received.player_data.tool_inventory.is_empty())
	assert(network.pending_server_player_state.is_empty())
	var manager := Manager.new()
	world.add_child(manager)
	manager.set_process(false)
	manager.world = world
	manager.last_sent_network_position = Vector2.ZERO
	manager.last_sent_network_facing = 1
	manager.last_sent_network_animation_state = "idle"
	var motion := Motion.new()
	world.add_child(motion)
	world.player.set_meta("last_sent_action_visual_key", manager.get_local_action_visual_key())
	assert(manager.is_multiplayer_position_flush_redundant(motion, Vector2.ZERO, 1))
	world.equipped_tool = "wrench"
	assert(not manager.is_multiplayer_position_flush_redundant(motion, Vector2.ZERO, 1), "Stationary equipment changes must send")
	world.player.set_meta("last_sent_action_visual_key", manager.get_local_action_visual_key())
	assert(manager.is_multiplayer_position_flush_redundant(motion, Vector2.ZERO, 1))
	world.selected_item_type = "stone"
	assert(not manager.is_multiplayer_position_flush_redundant(motion, Vector2.ZERO, 1), "Stationary hand preview changes must send")
	world.player.set_meta("last_sent_action_visual_key", manager.get_local_action_visual_key())
	world.equipped_tool = ""
	assert(not manager.is_multiplayer_position_flush_redundant(motion, Vector2.ZERO, 1), "Unequipping must send")
	world.free()
	print("WORLD_EXIT_APPEARANCE_OK")
	quit()
