extends SceneTree
class Fixture extends Node:
	var current_world_name := "HOME"
	var item_database: Dictionary = preload("res://Scripts/item_database.gd").ITEMS
	var blocks := {}
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _init(): call_deferred("run")
func run():
	var world := Fixture.new()
	root.add_child(world)
	var inventory = load("res://tests/fixtures/inventory_rules_probe.gd").new()
	world.add_child(inventory)
	inventory.world = world
	for item in ["magnet_machine_remote", "world_lock_key"]:
		var category := str(world.item_database[item].category)
		check(not inventory.can_select_item_for_safe(item,category), item + " blocked in safe picker")
		check(not inventory.can_select_item_for_donation_box(item,category), item + " blocked in donation picker")
		check(not inventory.can_select_item_for_vend(item,category), item + " blocked in vending picker")
		check(not inventory.can_drop_item_from_inventory(item,category), item + " cannot drop")
		check(inventory.can_select_item_for_trade(item,category) == (item == "world_lock_key"), item + " correct trade rule")
	check(inventory.can_select_item_for_safe("dirt","block"), "Ordinary safe deposits unchanged")
	check(inventory.can_select_item_for_donation_box("dirt","block"), "Ordinary donations unchanged")
	var interaction = load("res://Scripts/interaction_manager.gd").new()
	world.add_child(interaction)
	interaction.world = world
	var grid := Vector2i(3,4)
	for item in ["wooden_door", "blue_portal"]:
		# Use a known door definition even if the fixture item name is only illustrative.
		world.item_database = world.item_database.duplicate()
		world.item_database[item] = {"door_block":true, "portal_block":item == "blue_portal"}
		world.blocks[grid] = {"type":item, "door_destination":"BEACH", "door_target_world":"OLDWORLD", "door_target_id":"STALE"}
		var state: Dictionary = interaction.get_door_state(grid)
		check(state.target_world == "BEACH" and state.target_door_id == "", "World-only destination overrides old cached door link")
		interaction.apply_door_state_to_block(grid,"SOURCE","BEACH",false,"OLDWORLD","STALE")
		check(world.blocks[grid].door_target_world == "BEACH" and world.blocks[grid].door_target_id == "", "Applying world-only settings clears previous door target")
		for entry in [["door:EXIT","HOME","EXIT"],["BEACH:door:EXIT","BEACH","EXIT"],["BEACH:EXIT","BEACH","EXIT"]]:
			world.blocks[grid].door_destination = entry[0]
			state = interaction.get_door_state(grid)
			check(state.target_world == entry[1] and state.target_door_id == entry[2], "Explicit links still resolve: " + entry[0])
	world.free()
	print("WORLD_ITEM_DOOR_RULES_PASS" if failures == 0 else "WORLD_ITEM_DOOR_RULES_FAIL")
	quit(0 if failures == 0 else 1)
