extends RefCounted

# RecipeBookData
# ---------------------------------------------------------------------------
# Turns the live client item database + ItemDatabase.SPLICE_RECIPES into the
# tiered recipe entries the recipe book UI renders. Pure data: no nodes, no
# network, no mutation. The recipe book is a read-only reference view, so it
# never touches inventory, world state or the server.
#
# A recipe entry is keyed on the BLOCK the spliced seed grows into, because
# that is what players look for ("Wood Plank"), while the two ingredients and
# the used-for links stay in seed space (that is what you actually splice).
#
# Tiers use the spreadsheet's authored recipe_tier values. Recipes without
# a spreadsheet tier are shown under Other, never given an invented tier.
# ---------------------------------------------------------------------------

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ItemDatabase = preload("res://Scripts/item_database.gd")
const StationRecipes = preload("res://Scripts/station_recipes.gd")

const FILTER_BLOCKS := "blocks"
const FILTER_BACKGROUNDS := "backgrounds"
const FILTER_PROPS := "props"
const FILTER_WEARABLES := "wearables"
const FILTER_MISC := "misc"

const WEARABLE_CATEGORIES := {
	"back": true,
	"hat": true,
	"hair": true,
	"eyewear": true,
	"beard": true,
	"shirt": true,
	"pants": true,
	"shoes": true,
	"ride": true,
}

const TIER_RESOLVE_GUARD := 64


## Pull the item database / splice tables straight off the world node.
static func build_from_world(world) -> Dictionary:
	if world == null or not is_instance_valid(world):
		return {}

	var items: Dictionary = _read_dictionary(world, "item_database")
	var recipes: Dictionary = _read_dictionary(world, "splice_recipes")
	var balance: Dictionary = _read_dictionary(world, "tier_1_splice_balance")
	# world composes and caches the seed-box icons the rest of the game uses,
	# so seeds look identical here and in the inventory.
	return build(items, recipes, balance, world)


## Returns {tier_int: Array[recipe Dictionary]}, sorted inside each tier.
## icon_source is optional and only needs get_seed_icon_texture(seed_id).
static func build(item_database: Dictionary, splice_recipes: Dictionary, splice_balance: Dictionary = {}, icon_source = null) -> Dictionary:
	var parsed: Array = []
	for raw_key in splice_recipes.keys():
		var parts: PackedStringArray = str(raw_key).split("+", false)
		if parts.size() != 2:
			continue
		var result_seed: String = str(splice_recipes[raw_key]).strip_edges()
		if result_seed == "":
			continue
		parsed.append({
			"a": str(parts[0]).strip_edges(),
			"b": str(parts[1]).strip_edges(),
			"seed": result_seed,
		})

	var tier_by_seed: Dictionary = _resolve_seed_tiers(parsed, item_database)
	var consumers: Dictionary = _build_consumer_index(parsed)
	var seed_to_block: Dictionary = _build_seed_to_block_index(item_database)

	var by_tier: Dictionary = {}
	for entry in parsed:
		var recipe: Dictionary = _build_recipe(entry, item_database, splice_balance, consumers, seed_to_block, icon_source)
		var tier: int = int(tier_by_seed.get(entry["seed"], 0))
		recipe["tier"] = tier
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(recipe)

	_add_station_recipes(by_tier, item_database)
	_link_recipes(by_tier)
	for tier_key in by_tier.keys():
		var tier_recipes: Array = by_tier[tier_key]
		tier_recipes.sort_custom(_compare_recipes)
	return by_tier


# --- Tier derivation --------------------------------------------------------

static func _resolve_seed_tiers(parsed: Array, item_database: Dictionary) -> Dictionary:
	var tiers: Dictionary = {}
	for entry in parsed:
		var seed_id: String = entry.seed
		tiers[seed_id] = int((item_database.get(seed_id, {}) as Dictionary).get("recipe_tier", ItemDatabase.RECIPE_TIERS.get(seed_id, 0)))
	return tiers

static func _build_consumer_index(parsed: Array) -> Dictionary:
	var consumers: Dictionary = {}
	for entry in parsed:
		for ingredient in [str(entry["a"]), str(entry["b"])]:
			if not consumers.has(ingredient):
				consumers[ingredient] = []
			var outputs: Array = consumers[ingredient]
			if not outputs.has(entry["seed"]):
				outputs.append(entry["seed"])
	return consumers


# --- Recipe assembly --------------------------------------------------------

## seed id -> block id, built from each block's own "seed" field. Several
## spliced seeds (pile_of_sand_seed, apple_seed, ...) have no ITEMS entry of
## their own, so the seed -> "grows_into" -> block path dead-ends for them;
## this reverse index recovers the block from the block's own declaration.
static func _build_seed_to_block_index(items: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for item_id in items.keys():
		var data: Dictionary = items[item_id]
		var seed_id: String = str(data.get("seed", "")).strip_edges()
		if seed_id == "" or index.has(seed_id):
			continue
		index[seed_id] = str(item_id)
	return index


static func _resolve_block_id(seed_id: String, items: Dictionary, seed_to_block: Dictionary) -> String:
	var block_id: String = str((items.get(seed_id, {}) as Dictionary).get("grows_into", ""))
	if block_id != "" and items.has(block_id):
		return block_id
	var mapped: String = str(seed_to_block.get(seed_id, ""))
	return mapped if mapped != "" else block_id


static func _seed_display_name(seed_id: String, items: Dictionary, seed_to_block: Dictionary) -> String:
	var authored: String = str((items.get(seed_id, {}) as Dictionary).get("display_name", ""))
	if authored != "":
		return authored
	var block_data: Dictionary = items.get(_resolve_block_id(seed_id, items, seed_to_block), {})
	if not block_data.is_empty():
		return "%s Seed" % str(block_data.get("display_name", seed_id))
	return seed_id


static func _seed_icon(seed_id: String, items: Dictionary, seed_to_block: Dictionary, icon_source) -> Texture2D:
	# Every seed shares seed_box.png, so the composed box+preview icon world
	# builds (and caches) is the only one that tells two seeds apart.
	if icon_source != null and is_instance_valid(icon_source) and icon_source.has_method("get_seed_icon_texture"):
		var composed = icon_source.call("get_seed_icon_texture", seed_id)
		if composed is Texture2D:
			return composed

	var texture: Texture2D = item_icon(items.get(seed_id, {}))
	if texture != null:
		return texture
	# No seed sprite authored: show what it grows into rather than an empty slot.
	return item_icon(items.get(_resolve_block_id(seed_id, items, seed_to_block), {}))


static func _build_recipe(entry: Dictionary, items: Dictionary, balance: Dictionary, consumers: Dictionary, seed_to_block: Dictionary, icon_source) -> Dictionary:
	var result_seed: String = str(entry["seed"])
	var seed_data: Dictionary = items.get(result_seed, {})
	var block_id: String = _resolve_block_id(result_seed, items, seed_to_block)
	var block_data: Dictionary = items.get(block_id, {})
	var display_data: Dictionary = block_data if not block_data.is_empty() else seed_data
	var recipe_id: String = block_id if block_id != "" else result_seed
	var output_icon: Texture2D = item_icon(display_data)
	if output_icon == null:
		output_icon = _seed_icon(result_seed, items, seed_to_block, icon_source)

	return {
		"id": recipe_id,
		"method": "splicing",
		"seed_id": result_seed,
		"block_id": block_id,
		"name": str(display_data.get("display_name", recipe_id)),
		"icon": output_icon,
		"category": filter_category(display_data),
		"rarity": str(display_data.get("rarity", "common")),
		"description": _describe(entry, items, balance, block_id, seed_data, seed_to_block),
		"ingredients": [
			_ingredient_entry(str(entry["a"]), items, seed_to_block, icon_source),
			_ingredient_entry(str(entry["b"]), items, seed_to_block, icon_source),
		],
		"used_for": _used_for_entries(result_seed, consumers, items, seed_to_block),
		"order": int(display_data.get("order", 0)),
	}


static func _add_station_recipes(by_tier: Dictionary, items: Dictionary) -> void:
	for station in ["crafting_station", "furnace"]:
		for source in StationRecipes.get_recipes(station):
			var output: Dictionary = source.get("output", {})
			var id: String = str(output.get("item_id", ""))
			if not items.has(id):
				continue
			var ingredients: Array = []
			var costs: Array[String] = []
			var valid := true
			for cost in source.get("cost", []):
				var ingredient_id: String = str(cost.item_id)
				if not items.has(ingredient_id):
					valid = false
					break
				var name: String = str(items[ingredient_id].get("display_name", ingredient_id))
				ingredients.append({"id": ingredient_id, "name": name, "icon": item_icon(items[ingredient_id]), "count": int(cost.amount)})
				costs.append("%d × %s" % [int(cost.amount), name])
			if not valid:
				continue
			var item: Dictionary = items[id]
			var tier: int = int(item.get("recipe_tier", ItemDatabase.RECIPE_TIERS.get(id, 0)))
			var method := "crafting" if station == "crafting_station" else "furnace"
			var location := "Crafting Table" if method == "crafting" else "Furnace"
			var recipe := {
				"id": id, "block_id": id, "seed_id": "", "method": method, "tier": tier,
				"name": str(item.get("display_name", id)), "icon": item_icon(item),
				"category": filter_category(item), "ingredients": ingredients, "used_for": [],
				"description": "%s\n%s\nProduces %d × %s." % [location, " + ".join(costs), int(output.amount), str(item.get("display_name", id))],
				"order": int(item.get("order", 0))
			}
			if not by_tier.has(tier):
				by_tier[tier] = []
			by_tier[tier].append(recipe)


static func _link_recipes(by_tier: Dictionary) -> void:
	var all: Array = []
	var producers: Dictionary = {}
	for entries in by_tier.values():
		for recipe in entries:
			all.append(recipe)
			producers[recipe.id] = recipe
			if str(recipe.get("seed_id", "")) != "":
				producers[recipe.seed_id] = recipe
			recipe.used_for = []
	for recipe in all:
		for ingredient in recipe.ingredients:
			var producer: Dictionary = producers.get(ingredient.id, {})
			if producer.is_empty():
				continue
			ingredient["target_id"] = producer.id
			var links: Array = producer.used_for
			if not links.any(func(link): return link.id == recipe.id):
				links.append({"id": recipe.id, "target_id": recipe.id, "name": recipe.name, "icon": recipe.icon})


static func _ingredient_entry(seed_id: String, items: Dictionary, seed_to_block: Dictionary, icon_source) -> Dictionary:
	return {
		"id": seed_id,
		"name": _seed_display_name(seed_id, items, seed_to_block),
		"icon": _seed_icon(seed_id, items, seed_to_block, icon_source),
	}


static func _used_for_entries(result_seed: String, consumers: Dictionary, items: Dictionary, seed_to_block: Dictionary) -> Array:
	var outputs: Array = consumers.get(result_seed, [])
	var entries: Array = []
	for output_seed in outputs:
		var seed_id: String = str(output_seed)
		var block_id: String = _resolve_block_id(seed_id, items, seed_to_block)
		var block_data: Dictionary = items.get(block_id, {})
		var display_data: Dictionary = block_data if not block_data.is_empty() else (items.get(seed_id, {}) as Dictionary)
		entries.append({
			"id": block_id if block_id != "" else seed_id,
			"name": str(display_data.get("display_name", _seed_display_name(seed_id, items, seed_to_block))),
			"icon": item_icon(display_data),
		})
	return entries


static func _describe(entry: Dictionary, items: Dictionary, balance: Dictionary, block_id: String, seed_data: Dictionary, seed_to_block: Dictionary) -> String:
	var name_a: String = _seed_display_name(str(entry["a"]), items, seed_to_block)
	var name_b: String = _seed_display_name(str(entry["b"]), items, seed_to_block)

	var lines: Array[String] = []
	# Splicing is symmetric, so do not imply an order that does not exist.
	lines.append("Splice %s + %s on a growing seed-tree." % [name_a, name_b])

	var grow_time: float = _resolve_grow_time(balance, block_id, seed_data)
	if grow_time > 0.0:
		lines.append("Grow time: %s" % _format_duration(grow_time))

	var block_data: Dictionary = items.get(block_id, {})
	var drop_chance: float = float((balance.get(block_id, {}) as Dictionary).get("block_drop_chance", 0.0))
	if drop_chance > 0.0:
		lines.append("Block drop chance: %d%%" % int(round(drop_chance * 100.0)))
	elif not block_data.is_empty():
		lines.append("Rarity: %s" % str(block_data.get("rarity", "common")).capitalize())

	return "\n".join(lines)


static func _resolve_grow_time(balance: Dictionary, block_id: String, seed_data: Dictionary) -> float:
	var balanced: Dictionary = balance.get(block_id, {})
	var balanced_time: float = float(balanced.get("grow_time", 0.0))
	if balanced_time > 0.0:
		return balanced_time
	return float(seed_data.get("grow_time", 0.0))


static func _format_duration(seconds: float) -> String:
	return preload("res://Scripts/growth_duration.gd").format_seconds(seconds)


static func _compare_recipes(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")) < str(b.get("name", ""))


# --- Shared helpers ---------------------------------------------------------

## Maps an item entry onto one of the recipe book's footer filter categories.
static func filter_category(item_data: Dictionary) -> String:
	if item_data.is_empty():
		return FILTER_MISC

	var category: String = str(item_data.get("category", "")).strip_edges().to_lower()
	if WEARABLE_CATEGORIES.has(category):
		return FILTER_WEARABLES

	if category != "block":
		return FILTER_MISC

	if bool(item_data.get("background_block", false)) or str(item_data.get("place_layer", "")).to_lower() == "background":
		return FILTER_BACKGROUNDS

	if bool(item_data.get("no_collision", false)) or not bool(item_data.get("collidable", true)):
		return FILTER_PROPS

	return FILTER_BLOCKS


## Same icon precedence the inventory uses, so the book matches the slots.
static func item_icon(item_data: Dictionary) -> Texture2D:
	if item_data.is_empty():
		return null
	for key in ["inventory_icon", "icon_texture", "texture", "icon", "icon_path"]:
		if not item_data.has(key):
			continue
		var spec = item_data[key]
		# Legacy block definitions store the full sheet path plus separate coordinates.
		if spec is String and spec == "res://image.png" and item_data.has("atlas_coords"):
			var cell = item_data.atlas_coords
			if cell is Vector2i or cell is Vector2:
				cell = [int(cell.x), int(cell.y)]
			spec = {"atlas": spec, "cell": cell, "cell_size": [32, 32]}
		var texture: Texture2D = AtlasTextureFactory.load_texture(spec)
		if texture != null:
			return texture
	if item_data.has("atlas_coords"):
		var coords = item_data.atlas_coords
		if coords is Vector2i or coords is Vector2:
			coords = [int(coords.x), int(coords.y)]
		return AtlasTextureFactory.load_texture({"atlas": "res://image.png", "cell": coords, "cell_size": [32, 32]})
	return null


static func _read_dictionary(source, property_name: String) -> Dictionary:
	if source == null:
		return {}
	if not (property_name in source):
		return {}
	var value = source.get(property_name)
	if value is Dictionary:
		return value
	return {}
