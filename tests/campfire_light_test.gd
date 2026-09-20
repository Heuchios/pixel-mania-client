extends SceneTree

class FixtureWorld:
	extends Node2D
	var BLOCK_SIZE := 32
	var blocks: Dictionary = {}
	var item_database: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var world := FixtureWorld.new()
	root.add_child(world)
	world.item_database["campfire"] = load("res://Scripts/item_database.gd").ITEMS["campfire"]
	world.item_database["campfire"] = world.item_database["campfire"].duplicate(true)
	world.item_database["campfire"].merge(load("res://Scripts/ItemAtlasDB.gd").get_item_database_entries()["campfire"], true)
	var block := Node2D.new()
	block.position = Vector2(160, 160)
	world.add_child(block)
	var grid := Vector2i(5, 5)
	world.blocks[grid] = {"type": "campfire", "node": block}
	var manager = load("res://Scripts/block_manager.gd").new()
	manager.world = world
	manager.update_block_light_fx(grid)
	assert(block.get_child_count() == 1, "Placed campfire must receive its light")
	var effect = block.get_child(0)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	block.add_child(visual)
	manager.setup_block_animation(block, "campfire", visual)
	assert(manager.animated_block_visuals.has(visual.get_instance_id()), "Lit atlas campfire must register flame animation")
	var initial_frame: int = visual.get_meta("animation_frame_index")
	var initial_texture: Texture2D = visual.texture
	for tick in range(30):
		await create_timer(0.05).timeout
		manager.update_synced_block_animations()
		if int(visual.get_meta("animation_frame_index")) != initial_frame:
			break
	assert(int(visual.get_meta("animation_frame_index")) != initial_frame, "Flame frame must advance while light is active")
	assert(visual.texture != initial_texture)
	assert(effect.position == Vector2(0, -5))
	assert(effect.warm_light.enabled)
	assert(effect.warm_light.texture != null)
	var energy_before: float = effect.warm_light.energy
	effect._process(0.15)
	assert(not is_equal_approx(energy_before, effect.warm_light.energy), "Light must flicker")
	manager.update_block_light_fx(grid)
	assert(block.get_child_count() == 2, "Refresh must not duplicate light")
	effect.stop()
	assert(not effect.warm_light.enabled and not effect.is_processing())
	effect.start()
	assert(effect.warm_light.enabled)
	block.position = Vector2(-100000, -100000)
	effect._process(0.1)
	assert(not effect.warm_light.enabled, "Offscreen light must be disabled")
	block.position = Vector2(160, 160)
	effect._process(0.1)
	assert(effect.warm_light.enabled, "Returning on screen must restore light")
	var effect_ref: WeakRef = weakref(effect)
	block.queue_free()
	await process_frame
	assert(effect_ref.get_ref() == null, "Removing campfire must remove light")
	manager.free()
	world.free()
	print("[campfire-light] PASS: attach, flicker, deduplication, stop/start, culling, removal")
	quit()
