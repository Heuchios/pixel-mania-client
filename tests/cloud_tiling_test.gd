extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world

	var offsets = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	for mask in range(16):
		world.blocks = {Vector2i.ZERO:{"type":"cloud_block"}}
		for i in range(4):
			if mask & (1 << i): world.blocks[offsets[i]] = {"type":"cloud_block"}
		var path = manager.get_visual_block_variant("cloud_block",Vector2i.ZERO)
		assert(path == "res://Assets/blocks/cloud_connected/mask_%d.png" % mask)
		assert(load(path) is Texture2D)
		assert(manager.metadata_should_prefer_texture_visual_cell({"block_type":"cloud_block","grid_pos":Vector2i.ZERO},load(path)))
	world.blocks.clear()
	for x in range(6):
		for y in range(3):
			if y < 2 or x >= 2: world.blocks[Vector2i(x,y)] = {"type":"cloud_block"}
	var preview := Image.create(192,96,false,Image.FORMAT_RGBA8)
	preview.fill(Color("465e72"))
	for pos in world.blocks:
		var texture: Texture2D = load(manager.get_visual_block_variant("cloud_block",pos))
		preview.blend_rect(texture.get_image(),Rect2i(0,0,32,32),pos*32)
	preview.save_png("D:/Pixelmania/cloud-joined-preview.png")
	world.blocks = {Vector2i.ZERO:{"type":"cloud_block"},Vector2i.RIGHT:{"type":"barn_block"}}
	assert(manager.get_visual_block_variant("cloud_block",Vector2i.ZERO).ends_with("mask_0.png"))
	print("Cloud: 16 neighbor layouts, renderer texture preference and material isolation passed")
	manager.free()
	world.free()
	quit()
