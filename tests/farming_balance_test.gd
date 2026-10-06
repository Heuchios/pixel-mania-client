extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://Scripts/world.gd").new()
	var source = load("res://Scripts/item_database.gd")
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(source.ITEMS.duplicate(true))
	world.tier_1_splice_balance = source.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_coloured_block_seed_and_drop_rules()
	world.apply_tier_1_splice_balance()
	world.ensure_seed_item_definitions_from_blocks()
	var database: Dictionary = world.item_database
	var overrides = JSON.parse_string(FileAccess.get_file_as_string("res://Data/items/item_data_overrides.json"))
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://docs/farming-balance-report.json"))
	for row in report.rows:
		var id: String = row.id
		assert(database.has(id), "Missing block: " + id)
		assert(database[id].drop_rules == overrides[id].drop_rules, "Break rates differ: " + id)
		assert(database[id].tree_drop_rules == overrides[id].tree_drop_rules, "Harvest rates differ: " + id)
		if row.mode == "farm":
			assert(database[row.seed_id].grow_time == row.grow_seconds, "Tree time differs: " + id)
	print("FARMING_CLIENT_PARITY_PASS: ", report.rows.size(), " block/state definitions")
	world.free()
	quit()
