extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var gameplay = load("res://Scripts/item_gameplay_manager.gd").new()
	gameplay.world = world
	world.item_gameplay_manager = gameplay
	world.seed_inventory.clear()
	for item_id in world.item_database:
		if str(item_id).ends_with("_seed"):
			world.seed_inventory[item_id] = 3
			if world.seed_inventory.size() == 60:
				break
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(inventory)
	var started := Time.get_ticks_usec()
	inventory.set_inventory_from_world(world)
	print("INVENTORY_FIRST_OPEN ", {"seeds": world.seed_inventory.size(), "ms": (Time.get_ticks_usec() - started) / 1000.0, "composite_icons": world.seed_icon_texture_cache.size()})
	assert(world.seed_icon_texture_cache.is_empty(), "Opening the inventory must not composite unused seed icons")
	for seed_id in world.seed_inventory:
		var key: String = "seed:" + str(seed_id)
		assert(inventory.slot_nodes.has(key))
		var icon: TextureRect = inventory.slot_nodes[key].get_node("Icon")
		assert(icon.texture != null, "Seed box must still be visible")
		assert(icon.get_child_count() > 0, "Seed preview must still be visible")
	var first_seed: String = str(world.seed_inventory.keys()[0])
	world.seed_inventory[first_seed] = 8
	assert(inventory.refresh_item_live_from_world(world, first_seed, "seed"))
	assert(world.seed_icon_texture_cache.is_empty(), "Live updates must also avoid CPU compositing")
	inventory.free()
	gameplay.free()
	world.free()
	quit()
