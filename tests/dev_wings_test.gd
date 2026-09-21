extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const Equipment = preload("res://Scripts/equipment_manager.gd")
const Gameplay = preload("res://Scripts/item_gameplay_manager.gd")
const ITEM := "legendary_wings" # Preserve ownership of the renamed item.
const FOLDER := "res://Assets/player/back_item/dev_wings/"

class WorldFixture extends Node:
	var item_database: Dictionary = DB.ITEMS
	var back_textures: Dictionary = {}
	var inventory_icon_textures: Dictionary = {}

func _initialize() -> void:
	var data: Dictionary = DB.ITEMS[ITEM]
	assert(data.display_name == "Dev Wings")
	assert(data.jump_type == "infinite")
	assert(data.sprite_folder == FOLDER)
	assert(not DirAccess.dir_exists_absolute("res://Assets/player/back_item/legendary_wings"))
	var world := WorldFixture.new()
	var manager := Equipment.new()
	manager.world = world
	manager.load_back_item_visual_data(ITEM)
	assert(manager.back_idle_frames.size() == 4)
	assert(manager.back_jump_frames.size() == 7)
	assert(manager.back_flap_frames.size() == 7)
	var frames: SpriteFrames = manager.build_back_item_sprite_frames()
	for animation in ["idle", "walk", "jump", "fall"]:
		var pose := "idle" if animation in ["idle", "walk"] else "jump"
		var sequence := [1, 2, 3, 4] if pose == "idle" else [1, 2, 3, 4, 3, 2, 1]
		assert(frames.get_frame_count(animation) == sequence.size())
		for index in range(sequence.size()):
			var texture := frames.get_frame_texture(animation, index)
			assert(texture.resource_path == FOLDER + "dev_wings_%s%d.png" % [pose, sequence[index]])
			assert(texture.get_size() == Vector2(150, 150))
	var gameplay := Gameplay.new()
	gameplay.world = world
	var preview: Texture2D = gameplay.get_inventory_icon_texture(ITEM, "back")
	assert(preview != null and preview.resource_path == FOLDER + "dev_wings_preview.png")
	assert(preview.get_size() == Vector2(384, 384))
	assert(preview != manager.back_idle_texture)
	gameplay.free()
	manager.free()
	world.free()
	print("DEV_WINGS_OK: saved item ID, four idle frames, 1-2-3-4-3-2-1 jump, renamed paths and separate preview")
	quit()
