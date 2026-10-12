extends SceneTree

const Database = preload("res://Scripts/item_database.gd")
const Atlas = preload("res://Scripts/ItemAtlasDB.gd")
const REQUIRED = ["snow_repellent", "vending_machine", "magnet_machine", "world_lock", "anti_gravity", "anti_talk", "anti_punch", "cctv"]

class WorldFixture extends Node:
	var item_database := {}
	var inventory := {}
	var seed_inventory := {"snow_repellent_seed": 3, "cctv_seed": 2}
	var saves := 0
	func get_stack_limit_for_item(_id, _category): return 400
	func add_item_to_inventory_stack(target, id, _category, amount):
		var accepted := mini(amount, 400 - int(target.get(id, 0)))
		target[id] = int(target.get(id, 0)) + accepted
		return accepted
	func save_player_data(): saves += 1
	func get_item_display_name(id, _category): return item_database[id].get("display_name", id)
	func show_notification(_message): pass

func _initialize(): call_deferred("run")

func run():
	var fixture := WorldFixture.new()
	fixture.item_database = Atlas.merge_item_database(Database.ITEMS.duplicate(true))
	root.add_child(fixture)
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = fixture
	fixture.add_child(manager)
	manager.set_process(false)
	create_timer(10.0).timeout.connect(func(): quit(1))
	var ids := REQUIRED.duplicate()
	for id in fixture.item_database:
		if fixture.item_database[id].get("theme_machine_block", false) or str(id).ends_with("_theme_machine"):
			if not ids.has(id): ids.append(id)
	assert(ids.has("city_theme_machine") and ids.has("snow_theme_machine") and ids.has("night_theme_machine"))
	for id in ids:
		var item: Dictionary = fixture.item_database[id]
		assert(item.get("break_return_to_inventory", false), id + " must be recoverable after all overrides")
		assert(item.drop_rules.fixed_drops.is_empty(), id + " must not drop blocks or seeds")
		assert(int(item.drop_rules.seed_chance) == 0 and int(item.drop_rules.gem_range[0]) == 0 and int(item.drop_rules.gem_range[1]) == 0, id + " must not roll seeds or gems")
		assert(manager.get_direct_break_inventory_return_item(id) == id)
		fixture.inventory[id] = 399
		var saves_before := fixture.saves
		assert(manager.return_broken_block_directly_to_inventory(id))
		assert(fixture.inventory[id] == 400 and fixture.saves == saves_before + 1, "Return exactly one item")
		assert(not manager.return_broken_block_directly_to_inventory(id), "Full stack must reject another return")
		assert(fixture.inventory[id] == 400 and fixture.saves == saves_before + 1)
	assert(fixture.seed_inventory == {"snow_repellent_seed": 3, "cctv_seed": 2}, "Recovery cannot award or consume seeds")
	assert(manager.get_direct_break_inventory_return_item("dirt") == "", "Ordinary farming keeps its drop path")
	fixture.free()
	print("MACHINE_BREAK_RETURN_PASS: ", ids.size(), " items, merged catalog, exact recovery and full-stack rejection")
	quit()
