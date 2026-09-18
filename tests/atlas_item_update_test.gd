extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")
const FACTORY = preload("res://Scripts/atlas_texture_factory.gd")

class MockWorld:
	extends Node
	var item_database: Dictionary = {}
	var BLOCK_SIZE := 32

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://Scripts/world.gd").new()
	world.item_database = ATLAS.merge_item_database(DB.ITEMS.duplicate(true))
	world.tier_1_splice_balance = DB.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_tier_1_splice_balance()
	world.apply_coloured_block_seed_and_drop_rules()
	world.ensure_seed_item_definitions_from_blocks()
	var rows = FileAccess.get_file_as_string("res://docs/atlas-item-update.tsv").strip_edges().split("\n")
	var count := 0
	for line in rows.slice(1):
		var fields = line.strip_edges().split("\t")
		var id: String = fields[0]
		var item: Dictionary = world.item_database[id]
		assert(item.display_name == fields[1], id)
		var mode: String = fields[4]
		if mode != "keep":
			assert(item.atlas_coords == Vector2i(int(fields[2]), int(fields[3])), id)
			assert(item.collidable == (mode == "solid"), id)
			assert(item.no_collision == (mode != "solid"), id)
			assert(item.place_layer == ("background" if mode == "wall" else "foreground"), id)
			var texture = FACTORY.load_texture(item.texture)
			assert(texture != null, id)
			assert(texture.get_width() == (64 if mode == "wide" else 32), id)
			assert(texture.get_height() == 32, id)
		if mode == "return":
			assert(item.seed == "" and item.break_return_to_inventory, id)
			assert(item.drop_rules.fixed_drops.is_empty(), id)
		else:
			assert(world.item_database[item.seed].grows_into == id, id)
			assert(world.item_database[item.seed].display_name == fields[1] + " Seed", id)
			# Legacy balancing must not replace the requested authored drops.
			assert(JSON.parse_string(JSON.stringify(item.drop_rules)) == JSON.parse_string(JSON.stringify(DB.ITEMS[id].drop_rules)), id)
			assert(JSON.parse_string(JSON.stringify(item.tree_drop_rules)) == JSON.parse_string(JSON.stringify(DB.ITEMS[id].tree_drop_rules)), id)
		count += 1
	var mock := MockWorld.new()
	mock.item_database = world.item_database
	var blocks = load("res://Scripts/block_manager.gd").new()
	blocks.world = mock
	var frames = blocks.get_server_triggered_animation_frames("recycle_bin")
	assert(frames.size() == 2)
	assert(blocks.is_server_triggered_animation_block("recycle_bin"))
	for id in ["lantern", "campfire", "portcullis", "seaweed_block"]:
		assert(blocks.get_tilemap_animation_atlas_frames(id, id).size() == 3, id)
	assert(world.item_database.has("entrance_gate"))
	var verified := {}
	for line in rows.slice(1):
		var id: String = line.strip_edges().split("\t")[0]
		var item: Dictionary = world.item_database[id]
		verified[id] = {"display_name": item.display_name, "seed": item.seed, "drop_rules": item.drop_rules, "tree_drop_rules": item.tree_drop_rules}
	var output = FileAccess.open("res://tmp/atlas_verified_items.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(verified))
	output.close()
	blocks.free()
	mock.free()
	world.free()
	print("Atlas client update OK: %d items; textures, runtime balance, animation frames and collisions verified." % count)
	quit()
