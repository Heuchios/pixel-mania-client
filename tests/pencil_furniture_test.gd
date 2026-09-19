extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world

	for id in ["pencil_block", "cozy_chalkboard", "almanac", "wooden_shelf"]:
		var item = world.item_database[id]
		assert(item.solid and item.collidable)
		assert(world.item_database[item.seed].grows_into == id)
		assert(item.texture.cell == item.inventory_icon.cell)
	for height in [1,2,3,5]:
		world.blocks.clear()
		for y in range(height): world.blocks[Vector2i(0,y)] = {"type":"pencil_block"}
		for y in range(height):
			var expected = 29 if height == 1 else (30 if y == 0 else (32 if y == height-1 else 31))
			assert(manager.get_stateful_block_atlas_data("pencil_block",Vector2i(0,y),false).atlas_coords == Vector2i(0,expected))
	world.blocks = {Vector2i.ZERO:{"type":"pencil_block"},Vector2i.UP:{"type":"cozy_chalkboard"},Vector2i.DOWN:{"type":"almanac"}}
	assert(manager.get_stateful_block_atlas_data("pencil_block",Vector2i.ZERO,false).atlas_coords == Vector2i(0,29))
	print("Pencil vertical tiling, material separation, furniture solidity, icons and seeds passed")
	manager.free()
	world.free()
	quit()
