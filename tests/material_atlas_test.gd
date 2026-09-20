extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const FACTORY = preload("res://Scripts/atlas_texture_factory.gd")
const CONTRACT = preload("res://Scripts/item_data_contract.gd")

func _init() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/material-atlas.json"))
	var items := CONTRACT.apply(DB.ITEMS.duplicate(true))
	assert(expected.size() == 25)
	for id in expected:
		var item: Dictionary = items[id]
		assert(item.display_name == expected[id].display_name, id)
		assert(item.category == expected[id].category, id)
		assert(item.consumable == expected[id].consumable, id)
		var icon = FACTORY.load_texture(item.inventory_icon)
		assert(icon is AtlasTexture, id)
		assert(icon.region == Rect2(Vector2(expected[id].texture.cell[0], expected[id].texture.cell[1]) * 32, Vector2(32, 32)), id)
		assert(icon.atlas.resource_path == "res://Assets/items/material.png", id)
	assert(items.fertilizer.growth_reduction_seconds == 3600)
	assert(items.super_fertilizer.growth_reduction_seconds == 14400)
	assert(items.world_lock_key.world_lock_key and items.world_lock_key.instance_tracked)
	print("Material atlas: all 25 icons, names, categories, and consumable flags passed.")
	quit()
