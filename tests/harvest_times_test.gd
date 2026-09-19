extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	var db = load("res://Scripts/item_database.gd")
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(db.ITEMS.duplicate(true))
	world.tier_1_splice_balance = db.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_tier_1_splice_balance()
	world.ensure_seed_item_definitions_from_blocks()
	var snapshot = JSON.parse_string(FileAccess.get_file_as_string("res://docs/splice-harvest-times.json"))
	var checked := 0
	for row in snapshot.rows:
		if row.seed_id == null:
			continue
		var seed = world.item_database[row.seed_id]
		assert(float(seed.grow_time) == float(row.seconds), row.name)
		assert(float(seed.max_grow_time) == float(row.seconds), row.name)
		assert(world.get_seed_growth_time(row.seed_id) == float(row.seconds), row.name)
		checked += 1
	assert(checked == 197)
	print("Harvest durations: all 197 existing sheet output seeds match after runtime balance and seed initialization")
	world.free()
	quit()
