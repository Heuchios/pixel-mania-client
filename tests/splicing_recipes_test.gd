extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")

func _init() -> void:
	var database = DB.new()
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://docs/splicing-recipe-status.json"))
	var seed_to_block: Dictionary = {}
	var items: Dictionary = ATLAS.merge_item_database(DB.ITEMS.duplicate(true))
	for id in items:
		var item: Dictionary = items[id]
		if item.get("category") == "block" and not str(item.get("seed", "")).is_empty():
			seed_to_block[item.seed] = id
	var count := 0
	for row in rows:
		if row.status != "active":
			continue
		var seeds: Array = row.seeds
		assert(database.get_splice_result(seeds[0], seeds[1]) == seeds[2], str(row.names))
		assert(database.get_splice_result(seeds[1], seeds[0]) == seeds[2], str(row.names))
		for i in range(3):
			assert(seed_to_block.get(seeds[i], "") == row.ids[i], str(row.names))
		count += 1
	for key in DB.SPLICE_RECIPES:
		var pair: PackedStringArray = key.split("+")
		assert(database.get_splice_key(pair[0], pair[1]) == key)
		for seed_id in [pair[0], pair[1], DB.SPLICE_RECIPES[key]]:
			assert(seed_to_block.has(seed_id), seed_id)
	assert(database.get_splice_result("unknown_seed", "dirt_seed") == "")
	database.free()
	print("Splicing client OK: %d chart recipes, %d total." % [count, DB.SPLICE_RECIPES.size()])
	quit()
