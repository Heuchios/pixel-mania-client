extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world

	var item = world.item_database.melter
	assert(item.no_collision and not item.solid)
	assert(not item.animated)
	assert(int(item.inventory_icon.cell[0]) == 19)
	assert(item.visual_states.off.frames.size() == 1)
	assert(item.visual_states.running.loop)
	for i in range(3): assert(int(item.visual_states.running.frames[i].cell[0]) == 20+i)
	assert(int(item.visual_states.ready.frames[0].cell[0]) == 23)
	assert(world.item_database.melter_seed.grows_into == "melter")
	print("Melter: non-solid, idle default, off/running/ready frame definitions and seed passed")
	var maker = world.item_database.colored_block_maker
	assert(maker.no_collision and not maker.solid and not maker.animated)
	assert(int(maker.texture.cell[0]) == 11 and int(maker.texture.cell[1]) == 16)
	assert(maker.visual_states.running.frames.size() == 2)
	assert(int(maker.visual_states.running.frames[0].cell[0]) == 12)
	assert(int(maker.visual_states.running.frames[1].cell[0]) == 13)
	assert(int(maker.visual_states.ready.frames[0].cell[0]) == 14)
	print("Coloured Block Maker state definitions and non-solid idle default passed")
	manager.free()
	world.free()
	quit()
