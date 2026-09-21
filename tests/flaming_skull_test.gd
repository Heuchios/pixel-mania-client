extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")

func _initialize() -> void:
	var data: Dictionary = DB.ITEMS.flaming_skull
	assert(data.category == "hat" and data.equipment_slot == "hat")
	assert(data.instance_tracked and data.starting_count == 0)
	var icon := Factory.load_texture(data.inventory_icon) as AtlasTexture
	assert(icon != null and icon.region == Rect2(49 * 32, 4 * 32, 32, 32))
	assert(not icon.get_image().is_invisible())
	var manager = Equipment.new()
	var frames: SpriteFrames = manager.build_wearable_sprite_frames(data, "hat", [data.texture])
	assert(frames != null)
	for animation in frames.get_animation_names():
		assert(frames.get_frame_count(animation) == 4)
		assert(frames.get_animation_loop(animation))
		assert(frames.get_animation_speed(animation) == 5.0)
		for index in range(4):
			var texture := frames.get_frame_texture(animation, index) as AtlasTexture
			assert(texture != null and texture.region == Rect2((50 + index) * 32, 4 * 32, 32, 32))
			assert(not texture.get_image().is_invisible(), "Flaming Skull frames must contain artwork")
	manager.free()
	print("FLAMING_SKULL_OK: separate preview and four-frame animations for every movement state")
	quit()
