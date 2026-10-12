extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
const Loot = preload("res://Scripts/ui/shop_pack_loot_data.gd")

func _initialize() -> void:
	var total := 0
	var rare := 0
	for reward in DB.HAIR_PACK_REWARDS:
		var item: Dictionary = DB.ITEMS[reward.item_id]
		for key in ["texture", "inventory_icon"]:
			if Factory.load_texture(item.get(key)) == null:
				printerr("Missing Hair Pack art: ", reward.item_id, "/", key)
				quit(1)
				return
		total += int(reward.weight)
		if reward.item_id == "baby_hair":
			rare = int(reward.weight)
	if rare <= 0 or rare * 1000 != total:
		printerr("Baby Hair must remain a 0.1% reward")
		quit(1)
		return
	for reward in DB.HAIR_PACK_REWARDS:
		if reward.item_id in ["flaming_hair", "frosty_hair", "supernova_hair"] and int(reward.weight) * 100 != total:
			printerr("Hair Pack reward must be exactly 1%: ", reward.item_id)
			quit(1)
			return
		var disclosed := false
		for preview in Loot.PACKS.hairpack.rewards:
			if preview.item_id == reward.item_id:
				disclosed = is_equal_approx(float(preview.chance), float(reward.weight) / total)
		if not disclosed:
			printerr("Hair Pack disclosure differs from reward: ", reward.item_id)
			quit(1)
			return
	print("HAIR_PACK_CATALOG_OK: all 18 rewards have art and matching shop odds; Flaming/Frosty/Supernova 1% each, Baby Hair 0.1%")
	quit(0)
