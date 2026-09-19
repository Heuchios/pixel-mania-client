extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	var offsets = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)]
	var used = {}
	for mask in range(256):
		world.blocks = {Vector2i.ZERO:{"type":"barn_block"}}
		for i in range(8):
			if mask & (1 << i): world.blocks[offsets[i]] = {"type":"barn_block"}
		var expected = manager.get_barn_atlas_coords(Vector2i.ZERO) + Vector2i(0,9)
		for pos in world.blocks: world.blocks[pos].type = "neon_block"
		var actual = manager.get_barn_atlas_coords(Vector2i.ZERO, "neon_block")
		assert(actual == expected, str(mask))
		assert(manager.get_stateful_block_atlas_data("neon_block", Vector2i.ZERO, false).atlas_coords == expected)
		used[actual] = true
	assert(used.size() == 47)
	world.blocks = {Vector2i.ZERO:{"type":"neon_block"}}
	for offset in offsets: world.blocks[offset] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO, "neon_block") == Vector2i(0,33))
	world.blocks = {Vector2i.ZERO:{"type":"barn_block"}}
	for offset in offsets: world.blocks[offset] = {"type":"neon_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(0,24))
	var item = world.item_database.neon_block
	assert(item.solid and item.collidable and item.seed == "neon_block_seed")
	assert(item.connected_variant_atlas_coords.size() == 48)
	assert(int(item.texture.cell[0]) == 0 and int(item.texture.cell[1]) == 33, str(item.texture))
	assert(int(item.inventory_icon.cell[0]) == 0 and int(item.inventory_icon.cell[1]) == 33, str(item.inventory_icon))
	assert(world.item_database.neon_block_seed.grows_into == "neon_block")
	var atlas := Image.load_from_file("res://image.png")
	var canvas := Image.create(224,96,false,Image.FORMAT_RGBA8)
	canvas.fill(Color("465e72"))
	world.blocks.clear()
	for x in range(7):
		for y in range(3):
			if y != 1 or x in [0,3,6]: world.blocks[Vector2i(x,y)] = {"type":"neon_block"}
	for pos in world.blocks:
		canvas.blit_rect(atlas,Rect2i(manager.get_barn_atlas_coords(pos,"neon_block")*32,Vector2i(32,32)),pos*32)
	canvas.save_png("D:/Pixelmania/neon-preview.png")
	print("Neon: 256 neighborhoods, 47 patterns, mixed-material isolation, solid block and seed passed")
	manager.free()
	world.free()
	quit()
