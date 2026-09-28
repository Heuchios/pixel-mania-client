extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/item_database.gd").ITEMS.duplicate(true)
	var panel = load("res://Scripts/developer_panel_ui.gd").new()
	panel.world = world
	var matches = panel.collect_item_search_matches("Golden Fishing Rod")
	assert(matches.size() == 1)
	assert(matches[0].item_id == "golden_fishing_rod")
	assert(panel.collect_item_search_matches("platinum_prestige_rod").is_empty())
	assert(world.item_database.platinum_prestige_rod.hidden)
	assert(world.item_database.has("platinum_rod"))
	print("ROD_DUPLICATE_REMOVAL_OK")
	panel.free()
	world.free()
	quit()