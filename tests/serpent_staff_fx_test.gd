extends "res://tests/sword_slash_trail_test.gd"

const SerpentFX := preload("res://Scenes/particles/SerpentStaffFX.tscn")
const SERPENT_OUTPUT := "D:/Pixelmania/serpent-staff-preview"

class RemoteActors extends RefCounted:
	var remote_players := {}


func make_cast(start: Vector2, target: Vector2, facing: int = 1, size: float = 1.0, seed_value: int = 712) -> Node2D:
	var effect := SerpentFX.instantiate()
	root.add_child(effect)
	effect.scale = Vector2.ONE * size
	effect.rng.seed = seed_value
	effect.launch_to(start, target, facing)
	effect.set_process(false)
	return effect


func run() -> void:
	for displacement in [Vector2(110, 0), Vector2(-110, 0), Vector2(0, -90), Vector2.ZERO]:
		for size in [1.0, 3.4]:
			var start := Vector2(50, 90)
			var target: Vector2 = start + displacement
			var facing := -1 if displacement.x < 0 else 1
			var effect := make_cast(start, target, facing, size)
			assert(effect.global_position.is_equal_approx(start))
			assert(effect.to_global(effect.destination).is_equal_approx(target), "The venom impact must meet its target at every scale and facing")
			assert(effect.facing == float(facing))
			for i in range(12):
				effect.launch_to(start, target, facing)
				assert(effect.drops.size() == effect.DROP_COUNT, "Restarting must not accumulate venom particles")
			for drop in effect.drops:
				assert(drop.delay + drop.lifetime < effect.IMPACT_TIME, "All droplets must finish before cleanup")
				assert(effect._drop_position(drop, drop.lifetime).is_finite())
			effect._process(effect.duration + effect.IMPACT_TIME + 0.01)
			assert(effect.is_queued_for_deletion())
	await process_frame
	await check_world_routes()
	print("SERPENT_STAFF_PASS: rotating attack selection, both facings, vertical/zero/scaled endpoints, fade/cleanup, local/remote routes")
	if "--render-serpent-staff" in OS.get_cmdline_user_args():
		await render_serpent_preview()
	quit()


func check_world_routes() -> void:
	var game = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(game)
	game.equipped_tool = "serpent_staff"
	game.selected_item_category = "tool"
	game.selected_item_type = "punch"
	var database = load("res://Scripts/item_database.gd").new()
	game.item_database = {"serpent_staff": database.get_item_data("serpent_staff")}
	database.free()
	var player_playback = load("res://Scripts/player_manager.gd").new()
	player_playback.world = game
	assert(player_playback.get_current_player_punch_animation_name() == "punch_sword", "Local staff attacks must select the rotating animation")
	assert(player_playback.get_punch_animation_name_for_item("serpent_staff") == "punch_sword", "Remote equipment must select the same rotation")
	player_playback.free()
	var actor := Node2D.new()
	root.add_child(actor)
	game.player = actor
	var block_manager = load("res://Scripts/block_manager.gd").new()
	block_manager.world = game
	assert(block_manager.get_current_block_hit_source_tool() == "serpent_staff", "Punch selection must preserve the equipped staff hit source")
	block_manager.free()
	assert(not game.is_serpent_staff_source_tool("punch"))
	assert(not game.is_serpent_staff_source_tool("", false))
	assert(game.is_serpent_staff_source_tool())
	assert(not game.spawn_serpent_staff_at(Vector2.INF, Vector2.ZERO))
	assert(not game.spawn_serpent_staff_at(Vector2.ZERO, Vector2.INF))
	game.spawn_neptune_trident_block_hit_particles(Vector2i(2, 3), "stone", "foreground", "serpent_staff")
	assert(game.get_child_count() == 1)
	var effect = game.get_child(0)
	assert(effect.get_script() == preload("res://Scripts/serpent_staff_fx.gd"))
	assert(effect.to_global(effect.destination).is_equal_approx(game.get_block_center_world_position(Vector2i(2, 3))))
	assert(game.spawn_hand_item_swing_particles(Vector2(120, 40), "serpent_staff"))
	assert(game.get_child_count() == 2)
	assert(game.spawn_hand_item_swing_particles(), "Empty attacks must use the equipped staff and default forward target")
	assert(game.get_child_count() == 3)
	game.player_manager = RemoteActors.new()
	game.player_manager.remote_players["serpent-remote"] = actor
	var source_data := {"player_id": "serpent-remote", "actor_facing": -1}
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "serpent_staff", source_data)
	assert(game.get_child_count() == 4 and game.get_child(3).facing == -1.0)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "serpent_staff", source_data)
	assert(game.get_child_count() == 4, "Duplicate deliveries must not double the venom effect")
	actor.set_meta("last_serpent_staff_fx_msec", Time.get_ticks_msec() - 150)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "serpent_staff", source_data)
	assert(game.get_child_count() == 5, "The next rapid strike must still cast")
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-4, 1), "stone", "background", "serpent_staff", source_data)
	assert(game.get_child_count() == 6, "A distinct target must not be suppressed")
	game.spawn_neptune_trident_network_hit_particles(Vector2i(-3, 1), "stone", "background", "punch", source_data)
	assert(game.get_child_count() == 6, "Other remote equipment must not inherit local venom")
	for child in game.get_children():
		child._process(child.duration + child.IMPACT_TIME + 0.01)
	await process_frame
	assert(game.get_child_count() == 0)
	game.player_manager = null
	game.player = null
	game.free()
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


func render_serpent_preview() -> void:
	root.size = Vector2i(1120, 540)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("10172a"))
	DirAccess.make_dir_recursive_absolute(SERPENT_OUTPUT)
	world = TestWorld.new()
	root.add_child(world)
	playback = load("res://Scripts/player_manager.gd").new()
	playback.world = world
	var database = load("res://Scripts/item_database.gd").new()
	world.item_database["serpent_staff"] = database.get_item_data("serpent_staff")
	world.tool_textures["serpent_staff"] = Atlas.load_texture(world.item_database.serpent_staff.texture)
	var block_texture := Atlas.load_texture(database.get_item_data("stone").texture)
	database.free()
	source = load("res://Scenes/main.tscn").instantiate()
	var fixture := make_actor(Vector2(245, 315), 1.0, "serpent_staff")
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
	add_label("SERPENT STAFF", Vector2(30, 25), 1060, Color("c3ed8f"), 29)
	add_label("ROTATING CAST / VENOM", Vector2(20, 92), 500, Color("98be9c"))
	add_label("VENOM IMPACT / SPLASH", Vector2(590, 92), 500, Color("98be9c"))
	add_label("Single cast, then rapid attacks", Vector2(30, 480), 1060, Color("99b7a3"), 19)
	var effects: Array[Node2D] = []
	for frame in range(126):
		if frame in [18, 54, 61, 68, 75]:
			playback.play_animation_on_player(fixture.ap, playback.get_punch_animation_name_for_item("serpent_staff"))
			effects.append(make_cast(Vector2(625, 295), Vector2(895, 295), 1, 3.4, 710 + frame))
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
		root.get_texture().get_image().save_png(SERPENT_OUTPUT.path_join("frame-%03d.png" % frame))
	fixture.actor.queue_free()
	source.free()
	playback.free()
	world.queue_free()
	await process_frame
	print("SERPENT_STAFF_PREVIEW_PASS: ", SERPENT_OUTPUT)
