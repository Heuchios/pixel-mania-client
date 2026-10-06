extends RefCounted

# Only gameplay capabilities count here, not art, collision, rarity or seed presence.
const GAMEPLAY_FLAGS := [
	"instant_death", "hazard_instant_death", "lava_rebound", "slippery",
	"slow_surface", "springboard", "pinball_block", "anti_gravity_block",
	"anti_punch_block", "anti_talk_block", "punch_toggle_block", "toggle_block",
	"door_block", "entrance_block", "portal_block", "checkpoint_block", "password_door",
	"sign_block", "mailbox_block", "bulletin_board_block", "donation_box_block",
	"display_block", "tackle_box_block", "fish_hanger_block", "leaderboard_block",
	"chicken_block", "cow_block", "duck_block", "water_well_block", "dice_block",
	"theme_machine_block", "atm_machine_block", "cctv_block", "oil_refinery_block",
	"battery_charger_block", "magnet_machine_block", "snow_repellent_block",
	"water_bucket", "magnet_remote", "world_lock_key", "consumable", "shop_pack",
	"fishing_rod", "fishing_material", "material_fishing_lure", "visual_wire"
]
const GAMEPLAY_ITEMS := [
	"water", "world_lock", "super_world_lock", "small_lock", "big_lock", "huge_lock",
	"safe", "vending_machine", "crafting_station", "quest_board", "toxic_waste",
	"generator", "transformer", "metal_pad", "electric_pole", "electric_wire", "entrance_gate"
]


static func describe(item_id: String, items: Dictionary, splice_recipes: Dictionary) -> Dictionary:
	var entry: Dictionary = items.get(item_id, {})
	var category := str(entry.get("category", ""))
	var seed_id := item_id if category == "seed" else str(entry.get("seed", ""))
	var seed: Dictionary = items.get(seed_id, {})
	var valid_seed := str(seed.get("category", "")) == "seed" and bool(seed.get("plantable", true))
	var spliceable := false
	if valid_seed:
		for recipe_key in splice_recipes:
			if seed_id in str(recipe_key).split("+") or str(splice_recipes[recipe_key]) == seed_id:
				spliceable = true
				break
	var grown_block: Dictionary = items.get(str(seed.get("grows_into", "")), {}) if valid_seed else {}
	var tree_rules: Dictionary = grown_block.get("tree_drop_rules", {})
	var farmable := valid_seed and _has_reward(tree_rules, "block") and _has_reward(tree_rules, "seed")
	return {"spliceable": spliceable, "has_properties": _has_gameplay_properties(item_id, entry), "farmable": farmable}


static func _has_reward(rules: Dictionary, category: String) -> bool:
	for drop in rules.get("fixed_drops", []):
		if not drop is Dictionary or str(drop.get("item_category", "")) != category:
			continue
		var amounts: Array = drop.get("amount_range", [drop.get("amount", 1)])
		if float(drop.get("chance", 1.0)) > 0.0 and not amounts.is_empty() and float(amounts.back()) > 0.0:
			return true
	return false


static func _has_gameplay_properties(item_id: String, entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if entry.has("has_properties"):
		return bool(entry.has_properties)
	if item_id in GAMEPLAY_ITEMS or str(entry.get("category", "")) == "tool":
		return true
	for flag in GAMEPLAY_FLAGS:
		if bool(entry.get(flag, false)):
			return true
	if str(entry.get("jump_type", "")) in ["double", "infinite"]:
		return true
	var interaction: Variant = entry.get("interact_rules", false)
	if interaction is Dictionary:
		if bool(interaction.get("can_interact", false)):
			return true
	elif interaction is bool and interaction:
		return true
	for field in ["damage", "contact_damage", "break_hit_reduction"]:
		if float(entry.get(field, 0.0)) > 0.0:
			return true
	return false
