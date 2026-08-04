extends SceneTree

const TEST_GRID_POS := Vector2i(4, 4)
const PLATFORM_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform.png"
const PLATFORM_LEFT_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_left_end.png"
const PLATFORM_MIDDLE_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_middle.png"
const PLATFORM_RIGHT_TEXTURE_PATH := "res://Assets/blocks/Tier_1/wooden/wood_platform_right_end.png"


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
	OS.set_environment("PIXELMANIA_TILEMAP_CHUNK_STREAMING", "0")

	var world := MockWorld.new()
	root.add_child(world)
	world.item_database["wood_platform"] = {
		"category": "block",
		"texture": PLATFORM_TEXTURE_PATH,
		"platform_collision": true,
		"platform_variant_textures": {
			"left": PLATFORM_LEFT_TEXTURE_PATH
		}
	}

	var renderer = load("res://Scripts/world_tilemap_renderer.gd").new()
	renderer.name = "WorldTileMapRenderer"
	world.add_child(renderer)
	renderer.setup(world)

	var block_manager_script: Script = load("res://Scripts/block_manager.gd")
	assert(block_manager_script != null, "Could not load BlockManager.")
	var block_manager = block_manager_script.new()
	block_manager.world = world
	block_manager.tilemap_renderer = renderer

	var platform_texture := load(PLATFORM_TEXTURE_PATH) as Texture2D
	var platform_left_texture := load(PLATFORM_LEFT_TEXTURE_PATH) as Texture2D
	assert(platform_texture != null and platform_left_texture != null, "Could not load wooden platform textures.")

	var platform_node := Node2D.new()
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = platform_left_texture
	platform_node.add_child(visual)

	# Reproduce the old split ownership: a streamed TileMap cell was visible while
	# the collision node's Sprite2D was hidden. A rejoin clear could remove that
	# cell and leave the still-collidable platform invisible.
	assert(renderer.set_block_cell(TEST_GRID_POS, platform_left_texture))
	assert(renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) >= 0)
	visual.visible = false
	renderer.clear()
	assert(renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) == -1)
	assert(not visual.visible)

	assert(
		not block_manager.is_tilemap_visual_candidate(
			"wood_platform",
			"wood_platform",
			TEST_GRID_POS,
			false,
			visual
		),
		"One-way platforms must keep their node-owned visual."
	)
	assert(
		not block_manager.sync_tilemap_visual_for_block(
			platform_node,
			TEST_GRID_POS,
			"wood_platform",
			"wood_platform",
			false,
			visual
		)
	)
	assert(visual.visible, "Platform recovery must restore the node Sprite2D.")
	assert(
		renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) == -1,
		"Platform recovery must remove stale TileMap visual ownership."
	)

	# Standalone, left, middle, and right variants all follow the same node-owned rule.
	for platform_variant_path in [
		PLATFORM_TEXTURE_PATH,
		PLATFORM_LEFT_TEXTURE_PATH,
		PLATFORM_MIDDLE_TEXTURE_PATH,
		PLATFORM_RIGHT_TEXTURE_PATH
	]:
		var platform_variant_texture := load(str(platform_variant_path)) as Texture2D
		assert(platform_variant_texture != null, "Could not load " + str(platform_variant_path))
		visual.texture = platform_variant_texture
		assert(
			not block_manager.is_tilemap_visual_candidate(
				"wood_platform",
				"wood_platform",
				TEST_GRID_POS,
				false,
				visual
			)
		)

	platform_node.free()
	block_manager.free()
	world.free()
	print("[wood-platform-rejoin-visibility] success")
	quit(0)
