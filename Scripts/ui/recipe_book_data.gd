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
# Tiers are derived from splice depth, not from an authored field, because
# item_database.gd has no per-item tier today:
#   tier(result) = 1 + max(tier(ingredient_a), tier(ingredient_b))
#   a seed that is not the output of any recipe is tier 0 (a base seed)
# Add a "recipe_tier" key to an item entry to override the derived value.
# ---------------------------------------------------------------------------

const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

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
	if splice_recipes.is_empty():
		return {}

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

	if parsed.is_empty():
		return {}

	var tier_by_seed: Dictionary = _resolve_seed_tiers(parsed, item_database)
	var consumers: Dictionary = _build_consumer_index(parsed)
	var seed_to_block: Dictionary = _build_seed_to_block_index(item_database)

	var by_tier: Dictionary = {}
	for entry in parsed:
		var recipe: Dictionary = _build_recipe(entry, item_database, splice_balance, consumers, seed_to_block, icon_source)
		var tier: int = maxi(1, int(tier_by_seed.get(entry["seed"], 1)))
		recipe["tier"] = tier
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(recipe)

	for tier_key in by_tier.keys():
		var tier_recipes: Array = by_tier[tier_key]
		tier_recipes.sort_custom(_compare_recipes)
	return by_tier


# --- Tier derivation --------------------------------------------------------

static func _resolve_seed_tiers(parsed: Array, item_database: Dictionary) -> Dictionary:
	var recipe_seeds: Dictionary = {}
	for entry in parsed:
		recipe_seeds[entry["seed"]] = true

	var tiers: Dictionary = {}
	# Honour an authored override before deriving anything.
	for entry in parsed:
		var override: int = int((item_database.get(entry["seed"], {}) as Dictionary).get("recipe_tier", 0))
		if override > 0:
			tiers[entry["seed"]] = override

	var changed: bool = true
	var guard: int = 0
	while changed and guard < TIER_RESOLVE_GUARD:
		changed = false
		guard += 1
		for entry in parsed:
			var result_seed: String = str(entry["seed"])
			if int((item_database.get(result_seed, {}) as Dictionary).get("recipe_tier", 0)) > 0:
				continue
			var a_tier: int = _ingredient_tier(str(entry["a"]), recipe_seeds, tiers)
			var b_tier: int = _ingredient_tier(str(entry["b"]), recipe_seeds, tiers)
			if a_tier < 0 or b_tier < 0:
				# An ingredient is itself a splice output we have not resolved
				# yet; the next pass picks it up.
				continue
			var resolved: int = maxi(a_tier, b_tier) + 1
			if int(tiers.get(result_seed, -1)) != resolved:
				tiers[result_seed] = resolved
				changed = true

	# Anything still unresolved sits in a recipe cycle; keep it visible.
	for entry in parsed:
		if not tiers.has(entry["seed"]):
			tiers[entry["seed"]] = 1
	return tiers


static func _ingredient_tier(seed_id: String, recipe_seeds: Dictionary, tiers: Dictionary) -> int:
	if not recipe_seeds.has(seed_id):
		return 0
	return int(tiers.get(seed_id, -1))


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

	return {
		"id": recipe_id,
		"seed_id": result_seed,
		"block_id": block_id,
		"name": str(display_data.get("display_name", recipe_id)),
		"icon": item_icon(display_data),
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
	var total: int = int(round(maxf(0.0, seconds)))
	if total < 60:
		return "%ds" % total
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var remainder: int = total % 60
	if remainder == 0:
		return "%dm" % minutes
	return "%dm %ds" % [minutes, remainder]


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
		var texture: Texture2D = AtlasTextureFactory.load_texture(item_data[key])
		if texture != null:
			return texture
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
