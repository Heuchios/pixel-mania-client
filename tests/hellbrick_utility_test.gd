extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world

	var expected = {"metal_gate":Vector2i(8,11),"electrical_box":Vector2i(0,17),"display_box":Vector2i(0,14),"blink_checkpoint":Vector2i(11,14),"battery_assembler":Vector2i(4,17),"yellow_portal":Vector2i(0,15),"gem_driller":Vector2i(5,16),"hellbrick":Vector2i(15,36),"hellbrick_wall":Vector2i(15,37),"magma_stone":Vector2i(15,38),"hell_portal":Vector2i(16,36),"hellbrick_platform":Vector2i(17,36),"hell_entrance":Vector2i(16,37)}
	for id in expected:
		var item = world.item_database[id]
		assert(Vector2i(int(item.texture.cell[0]),int(item.texture.cell[1])) == expected[id],id)
		assert(world.item_database[item.seed].grows_into == id,id)
		assert(item.drop_rules.fixed_drops.size() == 3,id)
	assert(world.item_database.hellbrick.solid)
	assert(world.item_database.magma_stone.solid)
	assert(world.item_database.hellbrick_wall.background_block)
	assert(world.item_database.hell_entrance.no_collision)
	var frames = world.item_database.magma_stone.animation_frames
	assert(frames.size() == 5)
	for i in range(5): assert(int(frames[i].cell[0]) == [15,16,17,16,15][i])
	for width in [1,2,3,5]:
		world.blocks.clear()
		for x in range(width): world.blocks[Vector2i(x,0)] = {"type":"hellbrick_platform"}
		for x in range(width):
			var expected_x = 17 if width == 1 else (18 if x == 0 else (20 if x == width-1 else 19))
			var data = manager.get_stateful_block_atlas_data("hellbrick_platform",Vector2i(x,0),false)
			if width == 1:
				assert(data.is_empty())
				assert(int(world.item_database.hellbrick_platform.texture.cell[0]) == 17)
			else:
				assert(data.atlas_coords == Vector2i(expected_x,36))
	var bin = world.item_database.recycle_bin
	assert(not bin.break_return_to_inventory)
	assert(bin.seed == "recycle_bin_seed")
	assert(bin.drop_rules.fixed_drops.size() == 3)
	assert(world.item_database.display_box.display_block)
	assert(world.item_database.yellow_portal.portal_block)
	print("Hellbrick/utility atlas: icons, seeds, drops, collision, animation and platforms passed")
	manager.free()
	world.free()
	quit()
