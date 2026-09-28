extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")

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
	print("[hair-pack-catalog] All 12 rewards have equipped art and icons; Baby Hair is 0.1%")
	quit(0)
