extends SceneTree

const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")
const ITEM_DATABASE_SCRIPT_PATH := "res://Scripts/item_database.gd"
const BLOCK_MANAGER_SCRIPT_PATH := "res://Scripts/block_manager.gd"


class MockWorld:
	extends Node2D

	const BLOCK_SIZE := 32

	var item_database: Dictionary = {}
	var blocks: Dictionary = {}
	var display_states: Dictionary = {}
	var fish_textures: Dictionary = {}
	var player: Node2D = null
	var ui_layer: CanvasLayer = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	ITEM_ATLAS_DB.reload()
	assert(ITEM_ATLAS_DB.get_item_id_for_key("fish_hanger") == 34)
	var atlas_item := ITEM_ATLAS_DB.get_item(34)
	assert(atlas_item.get("item_key", "") == "fish_hanger")
	assert(atlas_item.get("atlas_coords", Vector2i.ZERO) == Vector2i(10, 13))

	var item_database_script = load(ITEM_DATABASE_SCRIPT_PATH)
	assert(item_database_script is GDScript)
	var item_database_node = item_database_script.new()
	var merged_database := ITEM_ATLAS_DB.merge_item_database({
		"fish_hanger": item_database_node.get_item_data("fish_hanger").duplicate(true),
		"pond_fish": item_database_node.get_item_data("pond_fish").duplicate(true)
	})
	var hanger_data: Dictionary = merged_database.get("fish_hanger", {})
	assert(bool(hanger_data.get("display_block", false)))
	assert(bool(hanger_data.get("fish_hanger_block", false)))
	assert(hanger_data.get("atlas_coords", Vector2i.ZERO) == Vector2i(10, 13))
	assert(not bool(hanger_data.get("collidable", true)))
	assert(is_equal_approx(float(hanger_data.get("display_preview_max_size", 0.0)), 18.0))

	var world := MockWorld.new()
	world.item_database = merged_database
	world.fish_textures["pond_fish"] = load("res://Assets/items/fish/pond_fish_large.png")
	root.add_child(world)

	var hanger_grid := Vector2i(4, 3)
	var hanger_node := Node2D.new()
	hanger_node.position = Vector2(hanger_grid.x * MockWorld.BLOCK_SIZE, hanger_grid.y * MockWorld.BLOCK_SIZE)
	world.add_child(hanger_node)
	world.blocks[hanger_grid] = {"type": "fish_hanger", "node": hanger_node}
	world.display_states[hanger_grid] = {
		"state": {
			"slot": {
				"item_id": "pond_fish",
				"item_type": "pond_fish",
				"item_category": "fish",
				"amount": 1
			}
		}
	}

	var block_manager_script = load(BLOCK_MANAGER_SCRIPT_PATH)
	assert(block_manager_script is GDScript)
	var block_manager = block_manager_script.new()
	block_manager.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(block_manager)
	block_manager.world = world
	assert(block_manager.is_fish_hanger_block_type("fish_hanger"))
	block_manager.update_display_visual(hanger_grid)

	var preview = block_manager.display_preview_visuals.get(hanger_grid, null)
	assert(preview is Sprite2D)
	assert(preview.visible)
	assert(preview.texture is Texture2D)
	assert(preview.position == hanger_node.position + Vector2(0, 2))
	var preview_layer := preview.get_parent() as CanvasItem
	assert(preview_layer != null)
	assert(preview_layer.z_index + preview.z_index > hanger_node.z_index)

	print("[fish-hanger-contract] success")
	item_database_node.free()
	world.queue_free()
	await process_frame
	quit(0)
