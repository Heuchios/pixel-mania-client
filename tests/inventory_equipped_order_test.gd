extends SceneTree

const Inventory = preload("res://Scenes/ui/inventory/InventoryScene.tscn")
const CATEGORIES := ["tool", "back", "hat", "hair", "eyewear", "beard", "body_accessory", "shirt", "pants", "shoes", "ride"]

class Source extends RefCounted:
	var inventory := {"dirt": 10, "world_lock": 2, "small_lock": 1}
	var seed_inventory := {"dirt_seed": 10}
	var tool_inventory := {}
	var material_inventory := {"rock": 10}
	var lure_inventory := {}
	var fish_inventory := {}
	var back_inventory := {}
	var hat_inventory := {}
	var hair_inventory := {}
	var eyewear_inventory := {}
	var beard_inventory := {}
	var body_accessory_inventory := {}
	var shirt_inventory := {}
	var pants_inventory := {}
	var shoes_inventory := {}
	var pet_inventory := {"pet":1}
	var ride_inventory := {}
	var equipped_tool := "wear_tool"
	var equipped_back_item := "wear_back"
	var equipped_hat_item := "wear_hat"
	var equipped_hair_item := "wear_hair"
	var equipped_eyewear_item := "wear_eyewear"
	var equipped_beard_item := "wear_beard"
	var equipped_body_accessory_item := "wear_body_accessory"
	var equipped_shirt_item := "wear_shirt"
	var equipped_pants_item := "wear_pants"
	var equipped_shoes_item := "wear_shoes"
	var equipped_ride_item := "wear_ride"
	var equipped_pet_item := "pet"
	var item_database := {"small_lock": {"order": 1}, "world_lock": {"order": 2}}
	func get_inventory_slot_count() -> int:
		return 60


func _initialize() -> void:
	call_deferred("run")


func visible_keys(scene: Control) -> Array:
	var keys := []
	for slot in scene.inventory_grid.get_children():
		if slot is Button and slot.visible:
			var key := str(slot.get_meta("inventory_slot_key", ""))
			if key != "" and not key.begins_with("inventory_capacity:"):
				keys.append(key)
	return keys


func check_priority(scene: Control, equipped_keys: Array) -> void:
	var expected := ["block:small_lock", "block:world_lock"] + equipped_keys
	var actual := visible_keys(scene)
	assert(actual.slice(0, expected.size()) == expected, "Locks, then every equipped item must lead the rendered grid")
	assert(actual.count("block:dirt") == 1, "Reordering must not duplicate slots")


func run() -> void:
	var source := Source.new()
	for category in CATEGORIES:
		var bag: Dictionary = source.get(category + "_inventory")
		bag["spare_" + category] = 1
		bag["wear_" + category] = 1
	var scene: Control = Inventory.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_inventory_from_world(source)
	var equipped_keys := ["tool:wear_tool"]
	for category in CATEGORIES.slice(1):
		equipped_keys.append(category + ":wear_" + category)
	equipped_keys.append("pet:pet")
	check_priority(scene, equipped_keys)
	var node_ids := {}
	for key in scene.slot_nodes:
		node_ids[key] = scene.slot_nodes[key].get_instance_id()
	scene.set_selected_item("wear_hat", "hat")

	# Refreshing only the newly equipped hat must also demote the old hat.
	source.equipped_hat_item = "spare_hat"
	assert(scene.refresh_item_live_from_world(source, "spare_hat", "hat"))
	equipped_keys[equipped_keys.find("hat:wear_hat")] = "hat:spare_hat"
	check_priority(scene, equipped_keys)
	assert(scene.selected_key == "hat:wear_hat", "Reordering preserves selection")
	assert(not scene.slot_nodes["hat:wear_hat"].get_node("Equipped").visible)
	assert(scene.slot_nodes["hat:spare_hat"].get_node("Equipped").visible)

	# Bulk refresh covers unequipping, held tools, accessories and pet equipment.
	source.equipped_tool = ""
	source.equipped_pet_item = ""
	source.equipped_body_accessory_item = ""
	assert(scene.refresh_live_from_world(source))
	for key in ["tool:wear_tool", "pet:pet", "body_accessory:wear_body_accessory"]:
		equipped_keys.erase(key)
	check_priority(scene, equipped_keys)
	var before_counts := visible_keys(scene)
	source.inventory.dirt = 25
	assert(scene.refresh_item_live_from_world(source, "dirt", "block"))
	assert(scene.slot_nodes["block:dirt"].get_node("Count").text == "25")
	assert(visible_keys(scene) == before_counts, "Count-only updates preserve slot order")
	for key in node_ids:
		assert(scene.slot_nodes[key].get_instance_id() == node_ids[key], "Equipment changes reuse existing slots")

	scene.set_current_tab("gear")
	var gear := visible_keys(scene)
	assert(gear.slice(0, equipped_keys.size()) == equipped_keys, "Filtered gear keeps equipped items first")
	scene.set_current_tab("all")
	scene.search_input.text = "hat"
	scene._refresh()
	assert(visible_keys(scene) == ["hat:spare_hat", "hat:wear_hat"], "Search results retain equipped priority")
	scene.free()
	# Payload-driven inventories also support newly added equipment categories.
	var probe: Control = Inventory.instantiate()
	probe.set_inventory_items([
		{"id": "dirt", "category": "block"},
		{"id": "future_item", "category": "future_gear", "equipped": true},
		{"id": "world_lock", "category": "block"}
	])
	var sorted: Array = probe._sort_inventory_items(probe.inventory_items)
	assert(sorted[0].id == "world_lock" and sorted[1].id == "future_item" and sorted[2].id == "dirt")
	probe.free()
	print("INVENTORY_EQUIPPED_ORDER_PASS: all slots, live swaps, unequip, pets, selection, node reuse, search and filters")
	quit()
