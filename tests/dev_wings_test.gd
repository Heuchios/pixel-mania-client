extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")
const Gameplay = preload("res://Scripts/item_gameplay_manager.gd")
const ITEM := "legendary_wings" # Preserve ownership of the renamed item.
const Factory = preload("res://Scripts/atlas_texture_factory.gd")

class WorldFixture extends Node:
	var item_database: Dictionary = DB.ITEMS
	var back_textures: Dictionary = {}
	var inventory_icon_textures: Dictionary = {}

func _initialize() -> void:
	var data: Dictionary = DB.ITEMS[ITEM]
	assert(data.display_name == "Dev Wings")
	assert(data.jump_type == "infinite")
	assert(not data.has("sprite_folder"))
	var world := WorldFixture.new()
	var manager := Equipment.new()
	manager.world = world
	manager.load_back_item_visual_data(ITEM)
	assert(manager.back_idle_frames.size() == 3)
	assert(manager.back_jump_frames.size() == 7)
	assert(manager.back_flap_frames.size() == 7)
	var frames: SpriteFrames = manager.build_back_item_sprite_frames()
	for animation in ["idle", "walk", "jump", "fall"]:
		var pose := "idle" if animation in ["idle", "walk"] else "jump"
		var sequence := [1, 2, 3] if pose == "idle" else [1, 2, 3, 4, 3, 2, 1]
		assert(frames.get_frame_count(animation) == sequence.size())
		for index in range(sequence.size()):
			var texture := frames.get_frame_texture(animation, index)
			var column: int = (1 if pose == "idle" else 10) + (sequence[index] - 1) * 3
			assert(texture is AtlasTexture and texture.region == Rect2(column * 32, 22 * 32, 96, 96))
			assert(texture.get_size() == Vector2(96, 96))
			assert(not texture.get_image().is_invisible())
	var gameplay := Gameplay.new()
	gameplay.world = world
	var preview: Texture2D = gameplay.get_inventory_icon_texture(ITEM, "back")
	assert(preview is AtlasTexture and preview.region == Rect2(0, 22 * 32, 32, 32))
	assert(preview.get_size() == Vector2(32, 32))
	assert(preview != manager.back_idle_texture)
	gameplay.free()
	manager.free()
	world.free()
	print("DEV_WINGS_OK: saved item ID, three atlas idle frames, 1-2-3-4-3-2-1 jump and separate atlas preview")
	quit()
