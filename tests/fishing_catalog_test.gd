extends SceneTree

const Database = preload("res://Scripts/item_database.gd")
const Contract = preload("res://Scripts/item_data_contract.gd")
const Manager = preload("res://Scripts/fishing_manager.gd")
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
const Species = preload("res://Scripts/fish_species.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Data/items/fishing_catalog.json"))
	var items := Contract.apply(Database.ITEMS.duplicate(true))
	var world = TestWorld.new()
	root.add_child(world)
	world.item_database = items
	world.fish_items = catalog.fish_ids.duplicate()
	world.fish_items.append("pond_fish_large")
	var manager = Manager.new()
	world.add_child(manager)
	world.fishing_manager = manager
	manager.setup(world)
	for category in ["fish", "lure"]:
		var ids: Array = catalog.fish_ids if category == "fish" else catalog.bait_ids
		var found := 0
		for id in items:
			if items[id].get("category") == category and not items[id].get("shop_pack", false):
				assert(ids.has(id), "Unexpected fishing item: " + str(id))
				found += 1
		assert(found == ids.size())
		for i in ids.size():
			var texture: Dictionary = items[ids[i]].texture
			assert(texture.atlas == "res://Assets/items/material.png")
			assert(texture.cell == [i, 6 if category == "fish" else 5])
	for bait in catalog.bait_ids:
		for rarity in catalog.bait_weights[bait]:
			assert(manager.get_fishing_rarity_weights(bait)[rarity] == int(catalog.bait_weights[bait][rarity]))
		var total := 0
		var caught: Array = []
		for entry in manager.get_fishing_table_for_lure(bait):
			assert(catalog.fish_ids.has(entry.fish_id))
			caught.append(entry.fish_id)
			total += int(entry.weight)
		assert(total == 10000)
		assert(caught.size() == 13, "Every species must remain catchable with every bait")
	for i in 2000:
		assert(catalog.bait_ids.has(manager.roll_lure_from_pack()))
	manager.apply_fishing_records({"total_fish_caught": 22, "total_fishing_xp": 123, "total_caught_per_species": {"pond_fish_large": 4, "bluegill": 3}, "rarest_catch": {"fish_id": "kraken", "name": "Kraken"}})
	assert(manager.get_fishing_journal_entries().size() == 13)
	assert(manager.get_fishing_journal_summary().total_species == 13)
	assert(manager.get_fishing_journal_summary().discovered_count == 0)
	assert(manager.fishing_records.rarest_catch.is_empty())
	assert(manager.fishing_records.total_fishing_xp == 123)
	manager.record_fish_catch("bluegill", 2.5)
	manager.ensure_fishing_records()
	assert(manager.fishing_records.total_caught_per_species.bluegill == 1)
	var state := {"fish_inventory": {"pond_fish_large": 50, "bluegill": 20}, "lure_inventory": {"hook": 4, "lure_pack": 2}}
	Species.migrate_player(state)
	assert(state.fish_inventory.is_empty() and state.lure_inventory == {"lure_pack": 2})
	state.fish_inventory = {"bluegill": 25, "guppy": 10}
	Species.migrate_player(state)
	assert(state.fish_inventory == {"bluegill": 25, "guppy": 10})
	world.queue_free()
	await process_frame
	print("[fishing-catalog] PASS: atlas, 13 species, 5 baits, catch tables, journal and retirement")
	quit()
