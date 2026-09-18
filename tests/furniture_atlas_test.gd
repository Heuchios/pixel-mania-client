extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")
const FACTORY = preload("res://Scripts/atlas_texture_factory.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/furniture-atlas-update.json"))
	var world = load("res://Scripts/world.gd").new()
	world.item_database = ATLAS.merge_item_database(DB.ITEMS.duplicate(true))
	world.tier_1_splice_balance = DB.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_tier_1_splice_balance()
	world.apply_coloured_block_seed_and_drop_rules()
	world.ensure_seed_item_definitions_from_blocks()
	var blocks = load("res://Scripts/block_manager.gd").new()
	blocks.world = world
	for row in manifest.items:
		var id: String = row.id
		var item: Dictionary = world.item_database[id]
		assert(item.display_name == row.name, id)
		assert(item.atlas_coords == Vector2i(row.x, row.y), id)
		assert(item.place_layer == ("background" if row.mode == "wall" else "foreground"), id)
		assert(item.solid == (row.mode in ["solid", "entrance"]), id)
		assert(item.platform_collision == (row.mode == "platform"), id)
		assert(world.item_database[item.seed].grows_into == id, id)
		assert(world.item_database[item.seed].display_name == row.name + " Seed", id)
		assert(JSON.parse_string(JSON.stringify(item.drop_rules)) == JSON.parse_string(JSON.stringify(DB.ITEMS[id].drop_rules)), id)
		var texture = FACTORY.load_texture(item.texture)
		assert(texture != null, id)
		assert(texture.get_width() == (64 if id == "the_starry_night" else 32), id)
	for id in ["rubber_duck", "fan"]:
		assert(blocks.is_server_triggered_animation_block(id), id)
		assert(blocks.get_server_triggered_animation_frames(id).size() >= 2, id)
	for id in ["royal_entrance", "ventilation"]:
		assert(blocks.get_wooden_entrance_pass_atlas_frames(id).size() == 3, id)
		assert(blocks.get_wooden_entrance_frames(id).size() == 3, id)
	var variants := {}
	for x in range(24):
		var art: Dictionary = blocks.get_stateful_block_atlas_data("white_brick_block", Vector2i(x, 10))
		assert(art.atlas_coords in [Vector2i(16, 24), Vector2i(17, 24)])
		assert(art == blocks.get_stateful_block_atlas_data("white_brick_block", Vector2i(x, 10)))
		variants[art.atlas_coords] = true
	assert(variants.size() == 2)
	for id in ["blue_couch", "green_couch", "park_bench"]:
		world.blocks.clear()
		world.blocks[Vector2i(1, 1)] = {"type": id}
		world.blocks[Vector2i(1, 0)] = {"type": id}
		assert(blocks.get_connected_variant_key(id, Vector2i(1, 1)) == "single")
		world.blocks[Vector2i(2, 1)] = {"type": id}
		assert(blocks.get_connected_variant_key(id, Vector2i(1, 1)) == "left")
		assert(blocks.get_connected_variant_key(id, Vector2i(2, 1)) == "right")
		world.blocks[Vector2i(3, 1)] = {"type": id}
		assert(blocks.get_connected_variant_key(id, Vector2i(2, 1)) == "horizontal_middle")
	print("Furniture atlas OK: ", manifest.items.size(), " items, seeds, collision, textures, drops, entrances and artwork variants")
	blocks.free()
	world.free()
	quit(0)
