extends "res://tests/sword_slash_trail_test.gd"

const AxeFX := preload("res://Scenes/particles/BloodBattleaxeThrowFX.tscn")
const BLOOD_OUTPUT := "D:/Pixelmania/blood-battleaxe-preview"

class RemoteActors extends RefCounted:
	var remote_players := {}


func make_throw(start: Vector2, target: Vector2, facing: int = 1, size: float = 1.0) -> Node2D:
	var effect := AxeFX.instantiate()
	root.add_child(effect)
	effect.scale = Vector2.ONE * size
	effect.rng.seed = 712
	effect.launch_to(start, target, facing)
	effect.set_process(false)
	return effect


func run() -> void:
	for facing in [1, -1]:
		for size in [1.0, 3.4]:
			var start := Vector2(50, 90)
			var target := start + Vector2(108 * facing, -30)
			var effect := make_throw(start, target, facing, size)
			assert(effect.to_global(effect._flight_position(effect._duration)).is_equal_approx(target), "Scaled throws must still meet their target")
			assert(effect._facing == float(facing))
			assert(effect._duration >= 0.17 and effect._duration <= 0.42)
			for i in range(12):
				effect.launch_to(start, target, facing)
				assert(effect.sparks.size() == effect.SPARK_COUNT, "Restarting must replace particles, not accumulate them")
			for spark in effect.sparks:
				assert(spark.delay + spark.lifetime < effect.FADE_TIME, "Every ember must fade before the node is freed")
				assert(effect._spark_position(spark, spark.lifetime).is_finite())
			effect._process(effect._duration + effect.FADE_TIME + 0.01)
			assert(effect.is_queued_for_deletion())
	await process_frame
	await check_world_routes()
	print("BLOOD_BATTLEAXE_PASS: both facings, scaled endpoints, bounded particles, fade/cleanup, actual local/remote routes and duplicate suppression")
	if "--render-blood-battleaxe" in OS.get_cmdline_user_args():
		await render_blood_preview()
	quit()


func check_world_routes() -> void:
	var game = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(game)
	game.equipped_tool = "blood_battleaxe"
	game.selected_item_category = "tool"
	game.selected_item_type = "punch"
	game.item_database = {"blood_battleaxe": {"inventory_icon": "blood_battleaxe_icon", "category": "tool"}}
	var manager = load("res://Scripts/item_gameplay_manager.gd").new()
	manager.setup(game)
	game.item_gameplay_manager = manager
	var actor := Node2D.new()
	root.add_child(actor)
	game.player = actor
	var block_manager = load("res://Scripts/block_manager.gd").new()
	block_manager.world = game
	assert(block_manager.get_current_block_hit_source_tool() == "blood_battleaxe")
	block_manager.free()
	assert(not game.spawn_blood_battleaxe_throw_at(Vector2.INF, Vector2.ZERO))
	game.spawn_neptune_trident_block_hit_particles(Vector2i(2, 3), "stone", "foreground", "blood_battleaxe")
	assert(game.get_child_count() == 1)
	var effect = game.get_child(0)
	assert(effect.get_script() == preload("res://Scripts/blood_battleaxe_throw_fx.gd"), "Actual world routes must use the custom axe effect")
	assert(effect.to_global(effect._flight_position(effect._duration)).is_equal_approx(game.get_block_center_world_position(Vector2i(2, 3))))
	assert(game.spawn_hand_item_swing_particles(Vector2(120, 40), "blood_battleaxe"))
	assert(game.get_child_count() == 2)
	game.player_manager = RemoteActors.new()
	game.player_manager.remote_players["axe-remote"] = actor
	var source_data := {"player_id": "axe-remote", "actor_facing": -1}
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "blood_battleaxe", source_data)
	assert(game.get_child_count() == 3 and game.get_child(2)._facing == -1.0)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "blood_battleaxe", source_data)
	assert(game.get_child_count() == 3, "Duplicate remote deliveries must not double the throw")
	actor.set_meta("last_battleaxe_throw_fx_msec", Time.get_ticks_msec() - 150)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "blood_battleaxe", source_data)
	assert(game.get_child_count() == 4)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "punch", source_data)
	assert(game.get_child_count() == 4, "Other remote weapons must not inherit the local axe effect")
	for child in game.get_children():
		child._process(child._duration + child.FADE_TIME + 0.01)
	await process_frame
	assert(game.get_child_count() == 0)
	game.player_manager = null
	game.player = null
	game.item_gameplay_manager = null
	game.free()
	manager.free()
	actor.free()


func add_label(text: String, at: Vector2, width: float, color: Color, font_size: int = 21) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	root.add_child(label)


func render_blood_preview() -> void:
	root.size = Vector2i(1120, 540)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("10172a"))
	DirAccess.make_dir_recursive_absolute(BLOOD_OUTPUT)
	world = TestWorld.new()
	root.add_child(world)
	playback = load("res://Scripts/player_manager.gd").new()
	var database = load("res://Scripts/item_database.gd").new()
	world.item_database["blood_battleaxe"] = database.get_item_data("blood_battleaxe")
	world.tool_textures["blood_battleaxe"] = Atlas.load_texture(world.item_database.blood_battleaxe.texture)
	var block_texture := Atlas.load_texture(database.get_item_data("stone").texture)
	database.free()
	source = load("res://Scenes/main.tscn").instantiate()
	var fixture := make_actor(Vector2(245, 315), 1.0, "blood_battleaxe")
	fixture.actor.scale = Vector2.ONE * 3.4
	fixture.trail.rng.seed = 177
	fixture.ap.play("RESET")
	fixture.ap.advance(0.0)
	fixture.ap.stop(true)
	var block := Sprite2D.new()
	block.texture = block_texture
	block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	block.position = Vector2(895, 295)
	block.scale = Vector2.ONE * 3.4
	root.add_child(block)
	add_label("BLOOD BATTLEAXE", Vector2(30, 25), 1060, Color("ff9fae"), 29)
	add_label("CRIMSON SWING / EMBERS", Vector2(20, 92), 500, Color("c391a4"))
	add_label("THROW / DOUBLE CLEAVE", Vector2(590, 92), 500, Color("c391a4"))
	add_label("Single strike, then rapid attacks", Vector2(30, 480), 1060, Color("b397a6"), 19)
	var effects: Array[Node2D] = []
	for frame in range(114):
		if frame in [18, 48, 54, 60, 66]:
			playback.play_animation_on_player(fixture.ap, "punch_sword")
			var effect := make_throw(Vector2(625, 295), Vector2(895, 295), 1, 3.4)
			effects.append(effect)
		for substep in range(2):
			fixture.ap.advance(1.0 / 60.0)
			fixture.trail._process(1.0 / 60.0)
			for i in range(effects.size() - 1, -1, -1):
				if not is_instance_valid(effects[i]) or effects[i].is_queued_for_deletion():
					effects.remove_at(i)
					continue
				effects[i]._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(BLOOD_OUTPUT.path_join("frame-%03d.png" % frame))
	fixture.actor.queue_free()
	source.free()
	playback.free()
	world.queue_free()
	await process_frame
	print("BLOOD_BATTLEAXE_PREVIEW_PASS: ", BLOOD_OUTPUT)
