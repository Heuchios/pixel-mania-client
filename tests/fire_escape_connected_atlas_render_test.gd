extends SceneTree


const FIRE_ESCAPE_ITEM_ID := 54
const VERTICAL_MIDDLE_COORDS := Vector2i(18, 30)
const HORIZONTAL_MIDDLE_COORDS := Vector2i(18, 29)


class MockWorld:
	extends Node2D

	var BLOCK_SIZE := 32
	var player: Node2D = null
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}
	var block_textures: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_database_script: Script = load("res://Scripts/item_database.gd")
	var atlas_database_script: Script = load("res://Scripts/ItemAtlasDB.gd")
	var block_manager_script: Script = load("res://Scripts/block_manager.gd")
	assert(item_database_script != null, "Could not load the item database.")
	assert(atlas_database_script != null, "Could not load the atlas database.")
	assert(block_manager_script != null, "Could not load BlockManager.")

	var world := MockWorld.new()
	root.add_child(world)
	world.item_database = atlas_database_script.merge_item_database(
		item_database_script.ITEMS.duplicate(true)
	)
	world.block_textures["fire_escape"] = atlas_database_script.get_item_icon(
		FIRE_ESCAPE_ITEM_ID,
		null
	)

	var block_manager = block_manager_script.new()
	block_manager.world = world

	var vertical_middle := Vector2i(4, 5)
	world.blocks[vertical_middle + Vector2i.UP] = {"type": "fire_escape"}
	world.blocks[vertical_middle] = {"type": "fire_escape"}
	world.blocks[vertical_middle + Vector2i.DOWN] = {"type": "fire_escape"}
	assert(
		block_manager.get_connected_variant_key("fire_escape", vertical_middle) == "vertical_middle",
		"A vertical Fire Escape run must resolve its center as vertical_middle."
	)
	assert_atlas_cell(
		block_manager.get_stateful_block_atlas_texture(
			"fire_escape",
			"fire_escape",
			vertical_middle,
			false
		),
		VERTICAL_MIDDLE_COORDS,
		"Vertical Fire Escape middle"
	)
	var vertical_node := make_block_node()
	world.add_child(vertical_node)
	world.blocks[vertical_middle]["node"] = vertical_node
	block_manager.set_block_texture(vertical_node, "fire_escape", vertical_middle, false)
	assert_atlas_cell(
		(vertical_node.get_node("Visual") as Sprite2D).texture,
		VERTICAL_MIDDLE_COORDS,
		"Rendered vertical Fire Escape middle"
	)

	world.blocks.clear()
	var horizontal_middle := Vector2i(8, 9)
	world.blocks[horizontal_middle + Vector2i.LEFT] = {"type": "fire_escape"}
	world.blocks[horizontal_middle] = {"type": "fire_escape"}
	world.blocks[horizontal_middle + Vector2i.RIGHT] = {"type": "fire_escape"}
	assert(
		block_manager.get_connected_variant_key("fire_escape", horizontal_middle) == "horizontal_middle",
		"A horizontal Fire Escape run must resolve its center as horizontal_middle."
	)
	assert_atlas_cell(
		block_manager.get_stateful_block_atlas_texture(
			"fire_escape",
			"fire_escape",
			horizontal_middle,
			false
		),
		HORIZONTAL_MIDDLE_COORDS,
		"Horizontal Fire Escape middle"
	)
	var horizontal_node := make_block_node()
	world.add_child(horizontal_node)
	world.blocks[horizontal_middle]["node"] = horizontal_node
	block_manager.set_block_texture(horizontal_node, "fire_escape", horizontal_middle, false)
	assert_atlas_cell(
		(horizontal_node.get_node("Visual") as Sprite2D).texture,
		HORIZONTAL_MIDDLE_COORDS,
		"Rendered horizontal Fire Escape middle"
	)

	block_manager.free()
	world.free()
	print("[fire-escape-connected-atlas-render] success")
	quit(0)


func make_block_node() -> Node2D:
	var block := Node2D.new()
	var visual := Sprite2D.new()
	visual.name = "Visual"
	block.add_child(visual)
	return block


func assert_atlas_cell(texture: Texture2D, expected_coords: Vector2i, label: String) -> void:
	assert(texture is AtlasTexture, label + " must render from an AtlasTexture.")
	var atlas_texture := texture as AtlasTexture
	var expected_region := Rect2(
		Vector2(expected_coords * 32),
		Vector2(32, 32)
	)
	assert(
		atlas_texture.region == expected_region,
		"%s must use atlas cell %s, got region %s." % [
			label,
			str(expected_coords),
			str(atlas_texture.region)
		]
	)
