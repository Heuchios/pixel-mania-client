extends RefCounted

const FAMILIES = ["pond_fish", "cat_fish", "bone_fish", "barracuda", "sea_horse", "stingray", "shark", "lava_fish", "alien_fish"]

static func canonical_id(item_id: String) -> String:
	for family in FAMILIES:
		if item_id == family + "_small" or item_id == family + "_med" or (family == "pond_fish" and item_id == family):
			return family + "_large"
	return item_id

static func merge_inventory(inventory: Dictionary) -> Dictionary:
	var merged: Dictionary = {}
	for item_id in inventory:
		var target := canonical_id(str(item_id))
		merged[target] = int(merged.get(target, 0)) + maxi(0, int(inventory[item_id]))
	return merged

static func merge_records(records: Dictionary) -> void:
	for key in ["total_caught_per_species", "biggest_fish_per_species", "best_value_per_species", "first_catch_discovered"]:
		if not records.get(key) is Dictionary:
			continue
		var entries: Dictionary = records[key]
		for item_id in entries.keys():
			var target := canonical_id(str(item_id))
			if target == item_id:
				continue
			if key == "total_caught_per_species":
				entries[target] = int(entries.get(target, 0)) + int(entries[item_id])
			elif key == "first_catch_discovered":
				if not entries.has(target) or int(entries[item_id].get("discovered_at", 0)) < int(entries[target].get("discovered_at", 0)):
					entries[target] = entries[item_id]
				entries[target]["fish_id"] = target
			else:
				entries[target] = maxf(float(entries.get(target, 0)), float(entries[item_id]))
			entries.erase(item_id)
	if records.get("rarest_catch") is Dictionary:
		var rare: Dictionary = records.rarest_catch
		rare["fish_id"] = canonical_id(str(rare.get("fish_id", "")))
		rare["name"] = str(rare.get("name", "")).trim_prefix("Small ").trim_prefix("Medium ").trim_prefix("Large ")
