extends SceneTree

const SAVE_PROBE := """
extends "res://Scripts/save_manager.gd"
func get_current_player_profile_name() -> String: return "tester"
func save_player_data(_notify_server: bool = true): pass
func debug_equipment_persist_flow(_message: String, _data: Dictionary = {}): pass
"""

class FishRecords extends RefCounted:
	var records := {"total_caught": 12}
	func get_fishing_records_save_data() -> Dictionary: return records
	func apply_fishing_records(data: Dictionary): records = data.duplicate(true)

class Fixture extends Node:
	var inventory := {"dirt": 23}
	var seed_inventory := {}
	var tool_inventory := {"pickaxe": 1, "magnet_machine_remote": 1}
	var back_inventory := {"wings": 1}
	var hat_inventory := {"crown": 1}
	var hair_inventory := {"crazy_hair": 1}
	var eyewear_inventory := {"sunglasses": 1}
	var beard_inventory := {"beard": 1}
	var body_accessory_inventory := {"accessory": 1}
	var shirt_inventory := {"shirt": 1}
	var pants_inventory := {"pants": 1}
	var shoes_inventory := {"shoes": 2}
	var ride_inventory := {"ride": 1}
	var material_inventory := {"stick": 7, "world_lock_key": 1}
	var currency_inventory := {"gem": 3185}
	var lure_inventory := {}
	var fish_inventory := {"guppy": 15}
	var item_database := {}
	var block_items := []
	var selected_item_type := "pickaxe"
	var selected_item_category := "tool"
	var primary_hotbar_tool := "punch"
	var hotbar_items := ["punch", "pickaxe", "sunglasses", "shoes", "crazy_hair", "dirt"]
	var hotbar_item_categories := ["tool", "tool", "eyewear", "shoes", "hair", "block"]
	var equipped_tool := "pickaxe"
	var equipped_back_item := "wings"
	var equipped_hat_item := "crown"
	var equipped_hair_item := "crazy_hair"
	var equipped_eyewear_item := "sunglasses"
	var equipped_beard_item := "beard"
	var equipped_body_accessory_item := "accessory"
	var equipped_shirt_item := "shirt"
	var equipped_pants_item := "pants"
	var equipped_shoes_item := "shoes"
	var equipped_ride_item := "ride"
	var player_level := 1
	var player_xp := 0
	var player_xp_needed := 300
	var player_total_xp := 0
	var player_title := "Explorer"
	var player_health := 10
	var inventory_slot_count := 300
	var player_data_loaded_from_file := false
	var fishing_manager = null
	var inventory_manager
	func normalize_hotbar(): inventory_manager.normalize_hotbar()
	func get_item_count(item, category): return inventory_manager.get_item_count(item, category)
	func update_hotbar(): pass
	func setup_hotbar(): pass
	func update_equipment_visual(): pass
	func update_all_ui(): pass

var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _init(): call_deferred("run")
func run():
	root.get_node("NetworkManager").set_process(false)
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
	world.fishing_manager = FishRecords.new()
	var before := {}
	for field in saver.PLAYER_INVENTORY_SAVE_KEYS:
		before[field] = world.get(field).duplicate(true)
		var category: String = "block" if field == "inventory" else str(field).trim_suffix("_inventory")
		for item in before[field]: world.item_database[item] = {"category": category}
	var equipment := {}
	for field in saver.PLAYER_LOADOUT_SAVE_KEYS: equipment[field] = world.get(field)
	var hotbar: Array = world.hotbar_items.duplicate()
	world.set_meta("shop_claims", ["appreciation_wings"])

	# Reproduce the production log: a nonempty player update without inventory fields.
	for preserve in [true, false]:
		saver.apply_network_player_state({"username": "tester", "preserve_local_loadout": preserve,
			"player_data": {"account_username": "tester", "player_xp": 17}})
		check(world.player_xp == 17, "Partial progression still applies")
		for field in before: check(world.get(field) == before[field], "Missing map preserves " + field)
		for field in equipment: check(world.get(field) == equipment[field], "Partial state preserves " + field)
		check(world.hotbar_items == hotbar, "Partial state preserves every hotbar slot")
		check(world.get_meta("shop_claims") == ["appreciation_wings"], "Omitted claims are preserved")
		check(world.fishing_manager.records == {"total_caught": 12}, "Omitted fishing records are preserved")

	saver.apply_network_player_state({"username": "tester", "preserve_local_loadout": true,
		"player_data": {"hair_inventory": null, "back_inventory": [], "fish_inventory": "invalid"}})
	check(world.hair_inventory == before.hair_inventory and world.back_inventory == before.back_inventory and world.fish_inventory == before.fish_inventory, "Malformed maps cannot clear owned items")

	# Omitted maps differ from explicit empty maps: depletion must still remove equipment.
	saver.apply_network_player_state({"username": "tester", "preserve_local_loadout": true,
		"player_data": {"hair_inventory": {}, "fish_inventory": {}, "tool_inventory": {"pickaxe": 1}, "material_inventory": {"stick": 7}, "shop_claims": [], "fishing_records": {}}})
	check(world.hair_inventory.crazy_hair == 0 and world.equipped_hair_item == "", "Explicit empty inventory unequips removed hair")
	check(not world.hotbar_items.has("crazy_hair"), "Removed item leaves hotbar")
	check(world.fish_inventory.is_empty(), "Explicit empty fish inventory clears fish")
	check(world.get_meta("shop_claims").is_empty() and world.fishing_manager.records.is_empty(), "Explicit empty records/claims still apply")
	check(world.tool_inventory.magnet_machine_remote == 0 and world.material_inventory.world_lock_key == 0, "Session item removals still apply")
	check(world.equipped_tool == "pickaxe" and world.equipped_back_item == "wings" and world.equipped_shoes_item == "shoes", "Unrelated equipment survives partial inventory replacement")
	world.free()
	print("PARTIAL_PLAYER_STATE: %d failures" % failures)
	quit(1 if failures else 0)
