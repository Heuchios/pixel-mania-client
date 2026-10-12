extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const CONTRACT = preload("res://Scripts/item_data_contract.gd")
const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")

class SeedFixture extends "res://Scripts/seed_system.gd":
	func update_seed_tree_visual(_grid_pos: Vector2i):
		pass
	func sync_seed_animation_membership(_grid_pos: Vector2i) -> void:
		pass

func _init() -> void:
	var system := SeedFixture.new()
	system.item_database = CONTRACT.apply(ATLAS.merge_item_database(DB.ITEMS.duplicate(true)))
	system.splice_recipes = DB.SPLICE_RECIPES
	var grid := Vector2i(1, 1)
	system.planted_seeds[grid] = {"seed_type": "checkpoint_seed", "spliced": false, "mature": false}
	var materials := {"star_fragment": 2, "stick": 1}
	assert(system.try_splice_seed_tree(grid, "star_fragment", "material", materials))
	assert(materials.star_fragment == 1)
	assert(system.planted_seeds[grid].seed_type == "blink_checkpoint_seed")
	assert(system.planted_seeds[grid].grow_time == system.item_database.blink_checkpoint_seed.grow_time)
	assert(not system.try_splice_seed_tree(grid, "star_fragment", "material", materials))
	assert(materials.star_fragment == 1)
	system.planted_seeds[grid] = {"seed_type": "checkpoint_seed", "spliced": false, "mature": false}
	assert(not system.try_splice_seed_tree(grid, "stick", "material", materials))
	assert(materials.stick == 1)
	system.planted_seeds[grid].mature = true
	assert(not system.try_splice_seed_tree(grid, "star_fragment", "material", materials))
	assert(materials.star_fragment == 1)
	var icon: Texture2D = preload("res://Scripts/atlas_texture_factory.gd").load_texture(system.item_database.composer.inventory_icon)
	assert(icon is AtlasTexture and icon.region == Rect2(32, 640, 32, 32))
	assert(system.item_database.composer.no_collision)
	assert(system.item_database.composer.composer_fill_atlas_coords == [[1,20],[2,20],[3,20]])
	for planet in ["moon", "earth", "sun"]:
		assert(not system.item_database.has(planet + "_fragment"))
	system.free()
	print("MATERIAL_SPLICING_CLIENT_PASS: consumption, replay, invalid material, maturity, Composer icon and deferred fragments")
	quit()
