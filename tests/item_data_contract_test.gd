extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	var db = load("res://Scripts/item_database.gd")
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(db.ITEMS.duplicate(true))
	world.tier_1_splice_balance = db.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_coloured_block_seed_and_drop_rules()
	world.apply_tier_1_splice_balance()
	world.ensure_seed_item_definitions_from_blocks()
	var patches = JSON.parse_string(FileAccess.get_file_as_string("res://Data/items/item_data_overrides.json"))
	for id in patches:
		assert(world.item_database.has(id), id)
		for field in patches[id]:
			assert(world.item_database[id].get(field) == patches[id][field], id + ": " + field)
	assert(world.item_database.stone.block_health == 5)
	assert(world.item_database.apple.solid and world.item_database.apple.block_health == 3)
	assert(world.item_database.wood_platform.platform_collision)
	assert(world.item_database.metal_gate.instant_death and world.item_database.bomb.instant_death)
	assert(world.item_database.lava.lava_rebound)
	print("ITEM DATA: %s item and seed overrides survive client initialization" % patches.size())
	world.free()
	quit()
