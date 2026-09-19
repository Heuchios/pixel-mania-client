extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	var ends = {Vector2i.UP: Vector2i(1,24), Vector2i.DOWN: Vector2i(1,26), Vector2i.LEFT: Vector2i(0,25), Vector2i.RIGHT: Vector2i(2,25)}
	for length in [1, 2, 4]:
		world.blocks.clear()
		world.blocks[Vector2i.ZERO] = {"type":"barn_block"}
		for direction in ends:
			for step in range(1,length+1):
				world.blocks[direction*step] = {"type":"barn_block"}
		assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(1,25))
		for direction in ends:
			assert(manager.get_barn_atlas_coords(direction*length) == ends[direction])
			for step in range(1,length):
				assert(manager.get_barn_atlas_coords(direction*step) == (Vector2i(2,24) if direction.x == 0 else Vector2i(0,26)))
			world.blocks.erase(direction*length)
			if length > 1:
				assert(manager.get_barn_atlas_coords(direction*(length-1)) == ends[direction])
	world.blocks = {Vector2i.ZERO:{"type":"barn_block"},Vector2i.RIGHT:{"type":"dirt"}}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(0,24))
	assert(manager.has_connected_variant_atlas_coords("barn_block"))
	world.blocks = {Vector2i.ZERO:{"type":"barn_block"},Vector2i.UP:{"type":"barn_block"},Vector2i.LEFT:{"type":"barn_block"},Vector2i.RIGHT:{"type":"barn_block"}}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(4,28))
	world.blocks[Vector2i.DOWN] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(1,25))
	world.blocks.erase(Vector2i.DOWN)
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(4,28))
	world.blocks.erase(Vector2i.UP)
	world.blocks[Vector2i.DOWN] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(4,27))
	world.blocks[Vector2i.UP] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(1,25))
	world.blocks.erase(Vector2i.UP)
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(4,27))
	world.blocks = {Vector2i.ZERO:{"type":"barn_block"},Vector2i.LEFT:{"type":"barn_block"},Vector2i.DOWN:{"type":"barn_block"}}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(9,24))
	world.blocks[Vector2i.RIGHT] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(4,27))
	world.blocks.erase(Vector2i.RIGHT)
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(9,24))
	world.blocks.erase(Vector2i.DOWN)
	assert(manager.get_barn_atlas_coords(Vector2i.ZERO) == Vector2i(2,25))
	# Two hollow sections with a central vertical divider, matching the reference.
	world.blocks.clear()
	for x in range(5):
		for y in range(3):
			if y != 1 or x in [0, 2, 4]:
				world.blocks[Vector2i(x,y)] = {"type":"barn_block"}
	var corners = {Vector2i(0,0):Vector2i(8,24),Vector2i(4,0):Vector2i(9,24),Vector2i(0,2):Vector2i(8,25),Vector2i(4,2):Vector2i(9,25)}
	for pos in corners:
		assert(manager.get_barn_atlas_coords(pos) == corners[pos])
	assert(manager.get_barn_atlas_coords(Vector2i(2,0)) == Vector2i(4,27))
	assert(manager.get_barn_atlas_coords(Vector2i(2,2)) == Vector2i(4,28))
	assert(manager.get_barn_atlas_coords(Vector2i(2,1)) == Vector2i(2,24))
	world.blocks.erase(Vector2i(0,1))
	assert(manager.get_barn_atlas_coords(Vector2i(0,0)) == Vector2i(0,25))
	assert(manager.get_barn_atlas_coords(Vector2i(0,2)) == Vector2i(0,25))
	world.blocks[Vector2i(0,1)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,0)) == Vector2i(8,24))
	assert(manager.get_barn_atlas_coords(Vector2i(0,2)) == Vector2i(8,25))
	world.blocks.clear()
	for x in range(7):
		for y in range(3):
			if y != 1 or x in [0, 1, 3, 5, 6]:
				world.blocks[Vector2i(x,y)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(3,25))
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(5,25))
	var thick_frame = {Vector2i(5,0):Vector2i(9,26),Vector2i(0,0):Vector2i(3,24),Vector2i(1,0):Vector2i(8,26),Vector2i(0,2):Vector2i(3,26),Vector2i(1,2):Vector2i(8,27),Vector2i(6,0):Vector2i(5,24),Vector2i(6,1):Vector2i(5,25),Vector2i(5,1):Vector2i(3,25),Vector2i(6,2):Vector2i(5,26),Vector2i(5,2):Vector2i(9,27)}
	for pos in thick_frame:
		assert(manager.get_barn_atlas_coords(pos) == thick_frame[pos], str(pos))
	world.blocks.erase(Vector2i(1,1))
	assert(manager.get_barn_atlas_coords(Vector2i(0,0)) == Vector2i(8,24))
	assert(manager.get_barn_atlas_coords(Vector2i(0,2)) == Vector2i(8,25))
	world.blocks[Vector2i(1,1)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,0)) == Vector2i(3,24))
	assert(manager.get_barn_atlas_coords(Vector2i(0,2)) == Vector2i(3,26))
	print("Barn cross: center, four endpoints, extended arms, removal and isolation passed")
	# Filled rectangles use continuous top and bottom edges.
	for width in [3, 5]:
		world.blocks.clear()
		for x in range(width):
			for y in range(3):
				world.blocks[Vector2i(x,y)] = {"type":"barn_block"}
		for x in range(1, width - 1):
			assert(manager.get_barn_atlas_coords(Vector2i(x,0)) == Vector2i(4,24))
			assert(manager.get_barn_atlas_coords(Vector2i(x,2)) == Vector2i(4,26))
	world.blocks.erase(Vector2i(0,1))
	assert(manager.get_barn_atlas_coords(Vector2i(1,0)) == Vector2i(9,26))
	assert(manager.get_barn_atlas_coords(Vector2i(1,2)) == Vector2i(9,27))
	print("Barn filled rectangle edges and removal passed")
	# Right side extends one tile farther in the lower two rows.
	world.blocks.clear()
	for x in range(7):
		for y in range(3):
			if (y == 0 and x < 6) or y == 2 or (y == 1 and x in [0, 1, 3, 5, 6]):
				world.blocks[Vector2i(x,y)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(5,1)) == Vector2i(6,27))
	world.blocks[Vector2i(6,0)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(5,1)) == Vector2i(3,25))
	world.blocks.erase(Vector2i(6,0))
	assert(manager.get_barn_atlas_coords(Vector2i(5,1)) == Vector2i(6,27))
	print("Barn stepped right edge and neighbor changes passed")
	# Two-by-two upper section with a single lower-left extension.
	world.blocks.clear()
	for pos in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,2)]:
		world.blocks[pos] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(6,26))
	world.blocks[Vector2i(1,2)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(3,25))
	world.blocks.erase(Vector2i(1,2))
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(6,26))
	print("Barn left middle step and neighbor changes passed")
	# Mirrored upper section with a single lower-right extension.
	world.blocks.clear()
	for pos in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,2)]:
		world.blocks[pos] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(7,26))
	world.blocks[Vector2i(0,2)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(5,25))
	world.blocks.erase(Vector2i(0,2))
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(7,26))
	print("Barn right middle step and neighbor changes passed")
	# Single upper-left extension above a filled two-by-two section.
	world.blocks.clear()
	for pos in [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,2), Vector2i(1,2)]:
		world.blocks[pos] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(6,27))
	world.blocks[Vector2i(1,0)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(3,25))
	world.blocks.erase(Vector2i(1,0))
	assert(manager.get_barn_atlas_coords(Vector2i(0,1)) == Vector2i(6,27))
	print("Barn upper extension junction and neighbor changes passed")
	# Single upper-right extension above a filled two-by-two section.
	world.blocks.clear()
	for pos in [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,2), Vector2i(1,2)]:
		world.blocks[pos] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(7,27))
	world.blocks[Vector2i(0,0)] = {"type":"barn_block"}
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(5,25))
	world.blocks.erase(Vector2i(0,0))
	assert(manager.get_barn_atlas_coords(Vector2i(1,1)) == Vector2i(7,27))
	print("Barn upper-right junction and neighbor changes passed")
	verify_all_neighborhoods(world, manager)
	render_examples(world, manager)
	manager.free()
	world.free()
	quit()

func verify_all_neighborhoods(world, manager):
	var atlas := Image.load_from_file("res://image.png")
	var offsets = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)]
	var samples = [Vector2i(0,0), Vector2i(28,0), Vector2i(28,28), Vector2i(0,28), Vector2i(14,0), Vector2i(28,14), Vector2i(14,28), Vector2i(0,14)]
	var used := {}
	for mask in range(256):
		world.blocks = {Vector2i.ZERO:{"type":"barn_block"}}
		for i in range(8):
			if mask & (1 << i): world.blocks[offsets[i]] = {"type":"barn_block"}
		var cell: Vector2i = manager.get_barn_atlas_coords(Vector2i.ZERO)
		used[cell] = true
		var occupied = []
		for offset in offsets: occupied.append(world.blocks.has(offset))
		var expected = [not (occupied[0] and occupied[3] and occupied[4]), not (occupied[0] and occupied[1] and occupied[5]), not (occupied[2] and occupied[1] and occupied[6]), not (occupied[2] and occupied[3] and occupied[7]), not occupied[0], not occupied[1], not occupied[2], not occupied[3]]
		for i in range(8):
			var trim_pixels := 0
			for x in range(4):
				for y in range(4):
					var color = atlas.get_pixelv(cell * 32 + samples[i] + Vector2i(x,y))
					if color.a > 0 and color.g * 255 > 100: trim_pixels += 1
			assert((trim_pixels > 2) == expected[i], "Artwork border mismatch: mask %s cell %s sample %s" % [mask, cell, i])
		# Every single-neighbor insertion/removal resolves to a registered tile.
		for offset in offsets:
			var existed = world.blocks.has(offset)
			if existed: world.blocks.erase(offset)
			else: world.blocks[offset] = {"type":"barn_block"}
			var next: Vector2i = manager.get_barn_atlas_coords(Vector2i.ZERO)
			assert(next.x >= 0 and next.x <= 9 and next.y >= 24 and next.y <= 28)
			if existed: world.blocks[offset] = {"type":"barn_block"}
			else: world.blocks.erase(offset)
	assert(used.size() == 47)
	print("All 256 neighborhoods, 47 artwork patterns and 2048 neighbor changes passed")

func render_examples(world, manager):
	var atlas := Image.load_from_file("res://image.png")
	var canvas := Image.create(768, 384, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("465e72"))
	var shapes = [
		["#######", "#..#..#", "#######"],
		["#######", "##.#.##", "#######"],
		["#####", "#####", "#####"],
		["..#..", "..#..", "#####", "..#..", "..#.."],
		["######.", "##.#.##", "#######"],
		[".#.#.", "#####", ".#.#.", "#####", ".#.#."]]
	for index in range(shapes.size()):
		world.blocks.clear()
		var rows = shapes[index]
		for y in range(rows.size()):
			for x in range(rows[y].length()):
				if rows[y][x] == "#": world.blocks[Vector2i(x,y)] = {"type":"barn_block"}
		for pos in world.blocks:
			var cell: Vector2i = manager.get_barn_atlas_coords(pos)
			canvas.blit_rect(atlas, Rect2i(cell * 32, Vector2i(32,32)), Vector2i((index % 3)*256+16, (index / 3)*192+16) + pos * 32)
	canvas.save_png("D:/Pixelmania/barn-configurations-preview.png")
