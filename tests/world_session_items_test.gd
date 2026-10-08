extends SceneTree

const SAVE_PATH := "res://tmp/world_session_items_test.json"
const SAVE_PROBE := """
extends "res://Scripts/save_manager.gd"
var server_saves := 0
func get_current_player_save_path() -> String:
	return "res://tmp/world_session_items_test.json"
func get_player_save_data() -> Dictionary:
	return {"tool_inventory": world.tool_inventory, "material_inventory": world.material_inventory, "inventory": world.inventory}
func notify_network_player_state_save(_data: Dictionary):
	server_saves += 1
"""

class Machine extends Node:
	var remote_state := {"machine_id": "old-world-machine"}

class Fixture extends Node:
	var current_world_name := "FIRST"
	var tool_inventory := {"magnet_machine_remote": 1, "pickaxe": 1}
	var material_inventory := {"world_lock_key": 1, "stick": 7}
	var inventory := {"dirt": 23}
	var seed_inventory := {}
	var lure_inventory := {}
	var item_database := {
		"magnet_machine_remote": {"category": "tool"}, "pickaxe": {"category": "tool"},
		"world_lock_key": {"category": "material"}, "stick": {"category": "material"},
		"dirt": {"category": "block"},
	}
	var selected_item_type := "magnet_machine_remote"
	var selected_item_category := "tool"
	var equipped_tool := "magnet_machine_remote"
	var hotbar_items := ["punch", "magnet_machine_remote", "world_lock_key", "dirt"]
	var hotbar_item_categories := ["tool", "tool", "material", "block"]
	var block_items := ["dirt"]
	var inventory_manager
	var magnet_machine_manager: Machine
	var player_manager = null
	var visual_updates := 0
	func normalize_hotbar(): inventory_manager.normalize_hotbar()
	func update_hotbar(): pass
	func update_equipment_visual(): visual_updates += 1

var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _init(): call_deferred("run")
func run():
	var live_network := root.get_node_or_null("NetworkManager")
	if live_network != null: live_network.set_process(false)
	var probe := GDScript.new()
	probe.source_code = SAVE_PROBE
	check(probe.reload() == OK, "Save probe compiles")
	var saver = probe.new()
	var world := Fixture.new()
	root.add_child(world)
	world.add_child(saver)
	saver.world = world
	world.inventory_manager = load("res://Scripts/inventory_manager.gd").new()
	world.add_child(world.inventory_manager)
	world.inventory_manager.world = world
	world.magnet_machine_manager = Machine.new()
	world.add_child(world.magnet_machine_manager)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp"))

	# Saving during a visit must retain the issued item in memory, but not cache it.
	saver.save_player_data(false)
	var cached: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(not cached.tool_inventory.has("magnet_machine_remote") and not cached.material_inventory.has("world_lock_key"), "Local files cannot restore world-session tools")
	check(world.tool_inventory.magnet_machine_remote == 1 and world.material_inventory.world_lock_key == 1, "Saving must not remove currently issued items")

	# Reproduce a stale local count and a server map omitting zero counts.
	saver.applying_server_player_data = true
	saver.apply_saved_inventory_counts(world.tool_inventory, {"pickaxe": 1}, true)
	saver.apply_saved_inventory_counts(world.material_inventory, {"stick": 7}, true)
	check(world.tool_inventory.magnet_machine_remote == 0 and world.material_inventory.world_lock_key == 0, "Authoritative absent items clear cached counts")
	saver.applying_server_player_data = false
	var legacy_defaults := {"pickaxe": 1, "magnet_machine_remote": 1}
	saver.apply_saved_inventory_counts(legacy_defaults, {}, true)
	check(legacy_defaults.pickaxe == 1 and legacy_defaults.magnet_machine_remote == 0, "Legacy defaults survive without preserving session tools")

	for destination in ["FIRST", "SECOND"]:
		world.tool_inventory.magnet_machine_remote = 1
		world.material_inventory.world_lock_key = 1
		world.selected_item_type = "magnet_machine_remote" if destination == "FIRST" else "world_lock_key"
		world.selected_item_category = "tool" if destination == "FIRST" else "material"
		world.equipped_tool = "magnet_machine_remote"
		world.hotbar_items = ["punch", "magnet_machine_remote", "world_lock_key", "dirt"]
		world.hotbar_item_categories = ["tool", "tool", "material", "block"]
		world.magnet_machine_manager.remote_state = {"machine_id": "old-machine"}
		saver.notify_network_leave_world(world.current_world_name)
		check(world.tool_inventory.magnet_machine_remote == 0 and world.material_inventory.world_lock_key == 0, "Both items clear on exit")
		check(world.magnet_machine_manager.remote_state.is_empty(), "Remote link clears on exit")
		check(not world.hotbar_items.has("magnet_machine_remote") and not world.hotbar_items.has("world_lock_key"), "Temporary hotbar entries clear")
		check(world.selected_item_type == "punch" and world.equipped_tool == "", "Removed remote leaves no hand preview")
		world.current_world_name = destination
		cached = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		saver.apply_saved_inventory_counts(world.tool_inventory, cached.tool_inventory, true)
		saver.apply_saved_inventory_counts(world.material_inventory, cached.material_inventory, true)
		check(world.tool_inventory.magnet_machine_remote == 0 and world.material_inventory.world_lock_key == 0, "Re-entry to " + destination + " cannot restore either item")
		check(world.inventory.dirt == 23 and world.tool_inventory.pickaxe == 1 and world.material_inventory.stick == 7, "Unrelated inventory survives")
	check(saver.server_saves == 0, "Local cleanup must not upload a fabricated inventory transaction")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	world.free()
	print("WORLD_SESSION_ITEMS_PASS" if failures == 0 else "WORLD_SESSION_ITEMS_FAIL")
	quit(0 if failures == 0 else 1)
