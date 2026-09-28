extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")

class WorldFixture extends Node:
	var item_database: Dictionary = DB.ITEMS
	var back_textures: Dictionary = {}

func _initialize() -> void:
	var world := WorldFixture.new()
	var manager := Equipment.new()
	manager.world = world
	var cases := {
		"lucifer_wings": {"row": 16, "idle": [1, 4], "jump": [7, 10, 13, 10, 7]},
		"susanoo_wings": {"row": 19, "idle": [1, 4], "jump": [7]},
		"legendary_wings": {"row": 22, "idle": [1, 4, 7], "jump": [10, 13, 16, 19, 16, 13, 10]},
	}
	for id in cases:
		var data: Dictionary = DB.ITEMS[id]
		var expected: Dictionary = cases[id]
		manager.load_back_item_visual_data(id)
		var frames: SpriteFrames = manager.build_back_item_sprite_frames()
		for animation in ["idle", "walk", "jump", "fall"]:
			var columns: Array = expected.idle if animation in ["idle", "walk"] else expected.jump
			assert(frames.get_frame_count(animation) == columns.size())
			for index in range(columns.size()):
				var texture := frames.get_frame_texture(animation, index) as AtlasTexture
				assert(texture != null)
				assert(texture.atlas.resource_path == "res://Assets/items/back_item.png")
				assert(texture.region == Rect2(columns[index] * 32, expected.row * 32, 96, 96))
				assert(not texture.get_image().is_invisible())
		var icon := Factory.load_texture(data.inventory_icon) as AtlasTexture
		assert(icon.region == Rect2(0, expected.row * 32, 32, 32))
		assert(not icon.get_image().is_invisible())
		assert(not data.auto_scale_back_sprite and data.back_scale == 1.0)
	assert(DB.ITEMS.legendary_wings.jump_type == "infinite")
	assert(DB.ITEMS.lucifer_wings.jump_type == "double")
	assert(DB.ITEMS.susanoo_wings.jump_type == "double")
	manager.free()
	world.free()
	print("WING_ATLAS_OK: three wings, icons, 96x96 canvases, all animation sequences and jump abilities")
	quit()
