extends RefCounted

# PixelMania Recipe Cleanup v1
#
# Keep recipe ownership clean:
# - Crafting Station = tools, stations, equipment, rare/special items
# - Furnace = materials only
# - Seed Splicing = blocks, doors, signs, platforms
# - Shop = stations/special utility items that should be purchased
#
# UI files should keep using:
# StationRecipes.get_recipes("crafting_station")
# StationRecipes.get_recipes("furnace")

const STATION_CRAFTING = "crafting_station"
const STATION_FURNACE = "furnace"

const CATEGORY_BLOCK = "block"
const CATEGORY_SEED = "seed"
const CATEGORY_TOOL = "tool"
const CATEGORY_BACK = "back"
const CATEGORY_MATERIAL = "material"
const CATEGORY_CURRENCY = "currency"

const RECIPES = {
	STATION_CRAFTING: [
		{
			"id": "refined_bamboo_rod",
			"name": "Refined Bamboo Rod",
			"type": "tool",
			"output": {"item_id": "refined_bamboo_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "bamboo_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "seaweed", "category": CATEGORY_MATERIAL, "amount": 12},
				{"item_id": "trash_can", "category": CATEGORY_MATERIAL, "amount": 4},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 100}
			]
		},
		{
			"id": "pristine_bamboo_rod",
			"name": "Pristine Bamboo Rod",
			"type": "tool",
			"output": {"item_id": "pristine_bamboo_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "refined_bamboo_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "seaweed", "category": CATEGORY_MATERIAL, "amount": 20},
				{"item_id": "clam", "category": CATEGORY_MATERIAL, "amount": 8},
				{"item_id": "coral", "category": CATEGORY_MATERIAL, "amount": 6},
				{"item_id": "pearl", "category": CATEGORY_MATERIAL, "amount": 1},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 500}
			]
		},
		{
			"id": "refined_fiberglass_rod",
			"name": "Refined Fiberglass Rod",
			"type": "tool",
			"output": {"item_id": "refined_fiberglass_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "fiberglass_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "refined_glass", "category": CATEGORY_MATERIAL, "amount": 10},
				{"item_id": "coral", "category": CATEGORY_MATERIAL, "amount": 8},
				{"item_id": "compass", "category": CATEGORY_MATERIAL, "amount": 1},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 500}
			]
		},
		{
			"id": "pristine_fiberglass_rod",
			"name": "Pristine Fiberglass Rod",
			"type": "tool",
			"output": {"item_id": "pristine_fiberglass_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "refined_fiberglass_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "refined_glass", "category": CATEGORY_MATERIAL, "amount": 20},
				{"item_id": "pearl", "category": CATEGORY_MATERIAL, "amount": 3},
				{"item_id": "topaz_necklace", "category": CATEGORY_MATERIAL, "amount": 1},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 1500}
			]
		},
		{
			"id": "refined_tungsten_rod",
			"name": "Refined Tungsten Rod",
			"type": "tool",
			"output": {"item_id": "refined_tungsten_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "tungsten_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "metal_scrap", "category": CATEGORY_MATERIAL, "amount": 10},
				{"item_id": "rusty_bicycle", "category": CATEGORY_MATERIAL, "amount": 3},
				{"item_id": "lost_chapter", "category": CATEGORY_MATERIAL, "amount": 1},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 2000}
			]
		},
		{
			"id": "pristine_tungsten_rod",
			"name": "Pristine Tungsten Rod",
			"type": "tool",
			"output": {"item_id": "pristine_tungsten_rod", "category": CATEGORY_TOOL, "amount": 1},
			"cost": [
				{"item_id": "refined_tungsten_rod", "category": CATEGORY_TOOL, "amount": 1},
				{"item_id": "metal_scrap", "category": CATEGORY_MATERIAL, "amount": 25},
				{"item_id": "naval_mines", "category": CATEGORY_MATERIAL, "amount": 2},
				{"item_id": "toxic_waste", "category": CATEGORY_MATERIAL, "amount": 2},
				{"item_id": "topaz_necklace", "category": CATEGORY_MATERIAL, "amount": 2},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 5000}
			]
		}
	],

	STATION_FURNACE: [
		{
			"id": "refined_stone",
			"name": "Refined Stone x5",
			"type": "material",
			"output": {"item_id": "refined_stone", "category": CATEGORY_MATERIAL, "amount": 5},
			"cost": [
				{"item_id": "stone", "category": CATEGORY_BLOCK, "amount": 15},
				{"item_id": "lava", "category": CATEGORY_BLOCK, "amount": 1}
			]
		},
		{
			"id": "refined_glass",
			"name": "Refined Glass x5",
			"type": "material",
			"output": {"item_id": "refined_glass", "category": CATEGORY_MATERIAL, "amount": 5},
			"cost": [
				{"item_id": "glass", "category": CATEGORY_BLOCK, "amount": 10},
				{"item_id": "lava", "category": CATEGORY_BLOCK, "amount": 1}
			]
		},
		{
			"id": "metal_scrap",
			"name": "Metal Scrap x3",
			"type": "material",
			"output": {"item_id": "metal_scrap", "category": CATEGORY_MATERIAL, "amount": 3},
			"cost": [
				{"item_id": "stone", "category": CATEGORY_BLOCK, "amount": 25},
				{"item_id": "lava", "category": CATEGORY_BLOCK, "amount": 2},
				{"item_id": "gem", "category": CATEGORY_CURRENCY, "amount": 2}
			]
		}
	]
}


static func get_recipes(station_id: String) -> Array:
	if RECIPES.has(station_id):
		return RECIPES[station_id].duplicate(true)

	return []


static func get_all_recipes() -> Dictionary:
	return RECIPES.duplicate(true)


static func get_recipe_count(station_id: String) -> int:
	return get_recipes(station_id).size()


static func get_recipe_ids(station_id: String) -> Array:
	var ids = []

	for recipe in get_recipes(station_id):
		ids.append(str(recipe.get("id", "")))

	return ids


static func get_recipe_by_id(station_id: String, recipe_id: String) -> Dictionary:
	for recipe in get_recipes(station_id):
		if str(recipe.get("id", "")) == recipe_id:
			return recipe

	return {}


static func has_duplicate_outputs() -> bool:
	return get_duplicate_outputs().size() > 0


static func get_duplicate_outputs() -> Array:
	var used_outputs = {}
	var duplicates = []

	for station_id in RECIPES.keys():
		for recipe in RECIPES[station_id]:
			var output = recipe.get("output", {})
			var output_key = str(output.get("category", "")) + ":" + str(output.get("item_id", ""))

			if used_outputs.has(output_key):
				duplicates.append({
					"output": output_key,
					"first_station": used_outputs[output_key],
					"duplicate_station": station_id,
					"recipe_id": str(recipe.get("id", ""))
				})
			else:
				used_outputs[output_key] = station_id

	return duplicates


static func is_recipe_output_category_allowed(station_id: String, output_category: String) -> bool:
	if station_id == STATION_CRAFTING:
		return output_category in [CATEGORY_TOOL, CATEGORY_BACK, CATEGORY_BLOCK, CATEGORY_MATERIAL]

	if station_id == STATION_FURNACE:
		return output_category == CATEGORY_MATERIAL

	return true


static func validate_recipes() -> Array:
	var issues = []

	for station_id in RECIPES.keys():
		for recipe in RECIPES[station_id]:
			var recipe_id = str(recipe.get("id", ""))
			var output = recipe.get("output", {})
			var output_item = str(output.get("item_id", ""))
			var output_category = str(output.get("category", ""))

			if recipe_id == "":
				issues.append("Recipe missing id in station: " + station_id)

			if output_item == "":
				issues.append("Recipe " + recipe_id + " missing output item_id.")

			if output_category == "":
				issues.append("Recipe " + recipe_id + " missing output category.")

			if not is_recipe_output_category_allowed(station_id, output_category):
				issues.append("Recipe " + recipe_id + " output category " + output_category + " may not belong in " + station_id + ".")

			var cost = recipe.get("cost", [])

			if not (cost is Array) or cost.size() == 0:
				issues.append("Recipe " + recipe_id + " has no cost.")

	var duplicate_outputs = get_duplicate_outputs()

	for duplicate in duplicate_outputs:
		issues.append("Duplicate output found: " + str(duplicate.get("output", "")))

	return issues
