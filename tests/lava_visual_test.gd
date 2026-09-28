extends SceneTree

const LavaVisual = preload("res://Scripts/lava_visual.gd")

class FixtureWorld extends Node2D:
	var BLOCK_SIZE := 32
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}
	var block_textures: Dictionary = {}
	var player: Node2D = null


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := FixtureWorld.new()
	root.add_child(world)
	world.item_database["lava"] = load("res://Scripts/item_database.gd").ITEMS["lava"].duplicate(true)
	var atlas_db = load("res://Scripts/ItemAtlasDB.gd")
	world.item_database.lava.merge(atlas_db.get_item_database_entries().lava, true)
	world.block_textures.lava = atlas_db.get_item_icon(atlas_db.get_item_id_for_key("lava"))
	var block := Node2D.new()
	block.position = Vector2(160, 160)
	world.add_child(block)
	var grid := Vector2i(5, 5)
	world.blocks[grid] = {"type": "lava", "node": block}
	var visual := Sprite2D.new()
	visual.name = "Visual"
	block.add_child(visual)
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	manager.set_block_texture(block, "lava", grid)
	assert(visual.material is ShaderMaterial, "Normal placement/refresh must attach molten animation")
	assert(visual.material.shader == LavaVisual.FLOW_SHADER)
	assert(visual.visible, "Lava must keep its node-owned visual")
	assert(visual.material.get_shader_parameter("atlas_region_px") == Vector4(0, 96, 32, 32), "Animation must be bounded to the actual lava atlas cell")
	var shared_material: Material = visual.material
	manager.set_block_texture(block, "lava", grid)
	assert(visual.material == shared_material, "Refreshing lava must reuse its animation material")
	manager.update_block_light_fx(grid)
	var effect = block.get_node("BlockLightFX")
	assert(effect.glow_light.enabled and effect.ember_particles.emitting)
	assert(effect.glow_light.texture is GradientTexture2D, "Use the campfire's smooth light falloff")
	assert(not effect.glow_light.shadow_enabled)
	var energy_before: float = effect.glow_light.energy
	effect._process(0.15)
	assert(not is_equal_approx(energy_before, effect.glow_light.energy))
	var child_count := block.get_child_count()
	manager.update_block_light_fx(grid)
	assert(block.get_child_count() == child_count and block.get_node("BlockLightFX") == effect, "Refresh must not duplicate effects")
	effect.stop()
	assert(not effect.is_processing() and not effect.glow_light.enabled and not effect.ember_particles.emitting)
	effect.restart()
	assert(effect.is_processing() and effect.glow_light.enabled)
	block.position = Vector2(-100000, -100000)
	effect._process(0.1)
	assert(not effect.glow_light.enabled and not effect.ember_particles.emitting, "Offscreen lava must stop lighting and emitting")
	block.position = Vector2(160, 160)
	effect._process(0.1)
	assert(effect.glow_light.enabled and effect.ember_particles.emitting)
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		world.blocks[grid + offset] = {"type": "lava"}
	manager.refresh_adjacent_block_light_fx(grid + Vector2i.UP)
	assert(block.get_node_or_null("BlockLightFX") == null, "Enclosed lava must not pay for a light")
	assert(visual.material == shared_material, "Enclosed lava still animates")
	world.blocks.erase(grid + Vector2i.UP)
	manager.refresh_adjacent_block_light_fx(grid + Vector2i.UP)
	assert(block.get_node_or_null("BlockLightFX") != null, "Opening the pool must restore glow")
	LavaVisual.apply(visual, false)
	assert(visual.material == null, "Reused non-lava sprites must lose the lava shader")
	var effect_ref: WeakRef = weakref(block.get_node("BlockLightFX"))
	block.queue_free()
	await process_frame
	assert(effect_ref.get_ref() == null)
	manager.free()
	world.free()
	print("[lava-visual] PASS: placement animation, atlas bounds, cache, glow, culling, exposure, cleanup")
	quit()
