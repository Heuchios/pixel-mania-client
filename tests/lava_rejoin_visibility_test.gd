extends SceneTree

const TEST_GRID_POS := Vector2i(4, 4)
const LAVA_TEXTURE_PATH := "res://Assets/blocks/Tier_1/basic blocks/lava_block.png"


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
	world.item_database["lava"] = {
		"category": "block",
		"texture": LAVA_TEXTURE_PATH,
		"atlas_coords": Vector2i(0, 3),
		"lava_rebound": true,
		"light_fx_scene": "res://Scenes/particles/LavaBlockGlowParticlesFX.tscn"
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

	var lava_texture := load(LAVA_TEXTURE_PATH) as Texture2D
	assert(lava_texture != null, "Could not load lava texture.")

	var lava_node := Node2D.new()
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = lava_texture
	lava_node.add_child(visual)

	# Reproduce the old split ownership. The TileMap visual is cleared during
	# rejoin while the live lava node remains present with its Sprite2D hidden.
	assert(renderer.set_block_cell(TEST_GRID_POS, lava_texture))
	assert(renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) >= 0)
	visual.visible = false
	lava_node.set_meta("tilemap_visual", true)
	renderer.clear()
	assert(renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) == -1)
	assert(not visual.visible)

	assert(
		block_manager.is_hybrid_hazard_tilemap_visual_candidate("lava"),
		"Lava must remain recognized as a live hazard."
	)
	assert(
		not block_manager.is_tilemap_visual_candidate(
			"lava",
			"lava",
			TEST_GRID_POS,
			false,
			visual
		),
		"Lava must keep its node-owned visual across world entry."
	)
	assert(
		not block_manager.sync_tilemap_visual_for_block(
			lava_node,
			TEST_GRID_POS,
			"lava",
			"lava",
			false,
			visual
		)
	)
	assert(visual.visible, "Lava recovery must restore the live Sprite2D.")
	assert(
		not lava_node.has_meta("tilemap_visual"),
		"Lava recovery must remove stale TileMap visual ownership."
	)
	assert(
		renderer.foreground_layer.get_cell_source_id(TEST_GRID_POS) == -1,
		"Lava recovery must not recreate split TileMap visual ownership."
	)

	lava_node.free()
	block_manager.free()
	world.free()
	print("[lava-rejoin-visibility] success")
	quit(0)
