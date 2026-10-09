extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")
const CASES := [
	["black_spiky_hair", "hair", 12, 12, 1],
	["chestnut_curtains", "hair", 12, 13, 1],
	["supernova_hair", "hair", 12, 14, 3],
	["chestnut_bob", "hair", 12, 15, 1],
	["ginger_ponytail", "hair", 12, 16, 1],
	["ginger_pigtails", "hair", 12, 17, 1],
	["police_hat", "hat", 17, 13, 1],
	["scrub_hat", "hat", 17, 14, 1],
	["ruby_bow", "hat", 17, 15, 1],
	["violet_bow", "hat", 17, 16, 1],
	["sunflower_cap", "hat", 17, 17, 1],
	["wizards_hat", "hat", 17, 18, 1],
	["witch_hat", "hat", 17, 19, 4],
	["cone_hat", "hat", 17, 20, 1],
	["pirate_hat", "hat", 17, 22, 1],
	["go_green_hat", "hat", 17, 23, 1],
]
var failures := 0

func _initialize() -> void:
	var manager = Equipment.new()
	for entry in CASES:
		var id: String = entry[0]
		var slot: String = entry[1]
		var item: Dictionary = DB.ITEMS[id]
		_check(item.category == slot and item.equipment_slot == slot, id + " slot")
		_check(item.equipable and item.instance_tracked and item.starting_count == 0, id + " equipment rules")
		var icon := Factory.load_texture(item.inventory_icon) as AtlasTexture
		var base := Factory.load_texture(item.texture) as AtlasTexture
		_check(icon != null and icon.region == Rect2(entry[2] * 32, entry[3] * 32, 32, 32), id + " icon cell")
		_check(base != null and base.region == Rect2((entry[2] + 1) * 32, entry[3] * 32, 32, 32), id + " equipped cell")
		if icon != null:
			_check(not icon.get_image().is_invisible(), id + " visible icon")
		var animations: SpriteFrames = manager.build_wearable_sprite_frames(item, slot, [item.texture])
		_check(animations != null, id + " sprite frames")
		if animations == null:
			continue
		for animation in animations.get_animation_names():
			_check(animations.get_frame_count(animation) == entry[4], id + " frame count " + animation)
			if entry[4] > 1:
				_check(animations.get_animation_loop(animation), id + " looping " + animation)
				_check(animations.get_animation_speed(animation) == 5.0, id + " speed " + animation)
			for index in range(animations.get_frame_count(animation)):
				var texture := animations.get_frame_texture(animation, index) as AtlasTexture
				_check(texture != null and texture.region == Rect2((entry[2] + 1 + index) * 32, entry[3] * 32, 32, 32), id + " frame cell")
				if texture != null:
					_check(not texture.get_image().is_invisible(), id + " visible frame")
		if slot == "hair":
			var present := false
			for reward in DB.HAIR_PACK_REWARDS:
				if reward.item_id == id:
					present = true
			_check(present, id + " Hair Pack reward")
	manager.free()
	if failures == 0:
		print("HAIR_HAT_EXPANSION_OK: all 16 requested items, separate icons and equipped art, movement animations and Hair Pack rewards")
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("HAIR_HAT_EXPANSION_FAIL: ", label)
