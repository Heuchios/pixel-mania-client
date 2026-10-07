extends RefCounted

const CATALOG_VERSION = 3
const RETIRED_IDS = ["hook","worm_lure","shiny_lure","golden_lure","bonito_lure","cotton_cordel_lure","void_worm_lure","magnet_lure","pond_fish","pond_fish_small","pond_fish_med","pond_fish_large","golden_carp","crystal_fish","cat_fish_small","cat_fish_med","cat_fish_large","bone_fish_small","bone_fish_med","bone_fish_large","barracuda_small","barracuda_med","barracuda_large","sea_horse_small","sea_horse_med","sea_horse_large","stingray_small","stingray_med","stingray_large","shark_small","shark_med","shark_large","lava_fish_small","lava_fish_med","lava_fish_large","alien_fish_small","alien_fish_med","alien_fish_large","mossy_chest","treasure_chest","sea_eater","tail_of_trident","mermaid","megalodon","kraken"]
const FISH_IDS = ["guppy","goldfish","blue_tang","bass","catfish","red_snapper","minnow","bluegill","mudfish","clownfish","tuna","salmon","swordfish"]

static func canonical_id(item_id: String) -> String:
	return item_id

static func merge_inventory(inventory: Dictionary) -> Dictionary:
	var merged: Dictionary = {}
	for item_id in inventory:
		if FISH_IDS.has(str(item_id)):
			merged[item_id] = maxi(0, int(inventory[item_id]))
	return merged

static func migrate_player(data: Dictionary) -> void:
	var initial := int(data.get("fishing_catalog_version", 0)) < CATALOG_VERSION
	for field in ["fish_inventory", "lure_inventory"]:
		if data.get(field) is Dictionary:
			for item_id in data[field].keys():
				if RETIRED_IDS.has(str(item_id)) or (initial and str(item_id) == "bluegill"):
					data[field].erase(item_id)
	data["fishing_catalog_version"] = CATALOG_VERSION

static func merge_records(records: Dictionary) -> void:
	var initial := int(records.get("catalog_version", 0)) < CATALOG_VERSION
	for key in ["total_caught_per_species", "biggest_fish_per_species", "best_value_per_species", "first_catch_discovered"]:
		if not records.get(key) is Dictionary:
			continue
		for item_id in records[key].keys():
			if not FISH_IDS.has(str(item_id)) or (initial and str(item_id) == "bluegill"):
				records[key].erase(item_id)
	if records.get("rarest_catch") is Dictionary:
		var id := str(records.rarest_catch.get("fish_id", ""))
		if not FISH_IDS.has(id) or (initial and id == "bluegill"):
			records["rarest_catch"] = {}
	records["catalog_version"] = CATALOG_VERSION
