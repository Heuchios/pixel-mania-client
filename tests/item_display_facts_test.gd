extends SceneTree

const Facts = preload("res://Scripts/item_display_facts.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://Scripts/world.gd").new()
	var source = load("res://Scripts/item_database.gd")
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(source.ITEMS.duplicate(true))
	world.tier_1_splice_balance = source.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_coloured_block_seed_and_drop_rules()
	world.apply_tier_1_splice_balance()
	world.ensure_seed_item_definitions_from_blocks()
	world.splice_recipes = source.SPLICE_RECIPES
	var db: Dictionary = world.item_database
	var bush := Facts.describe("bush", db, world.splice_recipes)
	assert(bush == {"spliceable": true, "has_properties": false, "farmable": true}, "Bush is ordinary, spliceable and farmable")
	for id in ["dirt", "bush_seed", "gold_block", "shifty_block"]:
		assert(Facts.describe(id, db, world.splice_recipes).farmable, id + " is farmable")
	for id in ["water", "world_lock", "bedrock", "water_bucket", "appreciation_wings"]:
		assert(not Facts.describe(id, db, world.splice_recipes).farmable, id + " cannot be farmed as a tree")
	for id in ["lava", "slime", "world_lock", "wooden_door", "water_bucket", "appreciation_wings", "sign", "cctv", "generator", "metal_pad", "electric_pole"]:
		assert(Facts.describe(id, db, world.splice_recipes).has_properties, id + " has gameplay properties")
	assert(not Facts.describe("bush_seed", db, world.splice_recipes).has_properties, "Seeds don't inherit hazards or functions from their grown block")
	assert(not Facts.describe("dirt", db, {}).spliceable, "Seed presence is not proof of a splice recipe")
	var cosmetic := {"hat": {"category": "hat", "equipable": true, "animated": true, "recipe": {"cloth": 1}}}
	assert(Facts.describe("hat", cosmetic, {}) == {"spliceable": false, "has_properties": false, "farmable": false}, "Appearance and crafting alone are not gameplay properties or splicing")
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://docs/farming-balance-report.json"))
	for row in report.rows:
		if row.mode == "variant":
			continue
		assert(Facts.describe(row.id, db, world.splice_recipes).farmable == (row.mode in ["farm", "reclaimable_tree"]), "Farmable flag disagrees with balance: " + row.id)
	print("ITEM_DISPLAY_FACTS_PASS: recipes, farmable catalog, gameplay properties and cosmetic exclusions")
	world.free()
	quit()
