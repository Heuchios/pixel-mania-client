extends "res://tests/sword_slash_trail_test.gd"

const AngelicHit := preload("res://Scenes/particles/AngelicSwordHitFX.tscn")
const ANGELIC_OUTPUT := "D:/Pixelmania/angelic-sword-preview"

class RemoteActors extends RefCounted:
	var remote_players := {}


func make_hit(at: Vector2, facing: int = 1, size: float = 1.0) -> Node2D:
	var effect := AngelicHit.instantiate()
	effect.preview_emitting = false
	root.add_child(effect)
	effect.position = at
	effect.scale = Vector2.ONE * size
	effect.rng.seed = 720
	effect.play_once(facing)
	effect.set_process(false)
	return effect


func run() -> void:
	var right = make_hit(Vector2.ZERO)
	var left = make_hit(Vector2.ZERO, -1)
	assert(right.particles.size() == 28 and left.particles.size() == 28)
	assert(right.particles.filter(func(p: Dictionary) -> bool: return p.kind == "feather").size() == 4)
	for index in range(right.particles.size()):
		var particle: Dictionary = right.particles[index]
		assert(particle.delay + particle.lifetime < right.LIFETIME, "Cleanup must allow the final sparkle and feather to fade")
		assert(right._particle_position(particle, 0.0).is_zero_approx(), "The burst must originate at the impact")
		var p: Vector2 = right._particle_position(particle, 0.25)
		var mirrored: Vector2 = left._particle_position(left.particles[index], 0.25)
		assert(mirrored.is_equal_approx(Vector2(-p.x, p.y)), "Both facings must mirror the same impact")
	assert(right.facing == 1.0 and left.facing == -1.0)
	for i in range(20):
		right.play_once(1)
		right._process(0.1)
		assert(right.particles.size() == 28, "Restarting must not accumulate particles")
	right.stop()
	assert(right.particles.is_empty() and not right.is_processing())
	right.start()
	assert(right.particles.size() == 28 and right.is_processing())
	right.free()
	left._process(left.LIFETIME + 0.01)
	await process_frame
	assert(not is_instance_valid(left), "One-shot effects must free themselves")
	await check_world_routes()
	print("ANGELIC_SWORD_PASS: mirrored impact, feather/sparkle lifecycle, restart cap, local and remote hit routes, duplicate suppression, unrelated weapon isolation")
	if "--render-angelic-sword" in OS.get_cmdline_user_args():
		await render_angelic_preview()
	quit()


func check_world_routes() -> void:
	# Load after autoloads initialize; world dependencies reference those singletons.
	var game = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(game)
	game.equipped_tool = "angelic_sword"
	game.selected_item_category = "tool"
	game.selected_item_type = "punch"
	var block_manager = load("res://Scripts/block_manager.gd").new()
	block_manager.world = game
	assert(block_manager.get_current_block_hit_source_tool() == "angelic_sword", "Equipped sword must remain the source when punch is selected")
	block_manager.free()
	assert(not game.is_angelic_sword_source_tool("punch"), "An explicit different source must not inherit the equipped VFX")
	assert(not game.is_angelic_sword_source_tool("", false), "Remote actions must not use local equipment as fallback")
	assert(not game.spawn_angelic_sword_hit_at(Vector2(INF, 0)))
	game.spawn_neptune_trident_block_hit_particles(Vector2i(2, 3), "stone", "foreground", "angelic_sword")
	assert(game.get_child_count() == 1)
	assert(game.get_child(0).global_position == game.get_block_center_world_position(Vector2i(2, 3)))
	assert(game.spawn_hand_item_swing_particles(Vector2(120, 40), "angelic_sword"))
	assert(game.get_child_count() == 2)
	var actor := Node2D.new()
	root.add_child(actor)
	game.player_manager = RemoteActors.new()
	game.player_manager.remote_players["test-remote"] = actor
	var source_data := {"player_id": "test-remote", "actor_facing": -1}
	game.spawn_neptune_trident_network_hit_particles(Vector2i(4, 3), "stone", "background", "angelic_sword", source_data)
	assert(game.get_child_count() == 3 and game.get_child(2).facing == -1.0)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(4, 3), "stone", "background", "angelic_sword", source_data)
	assert(game.get_child_count() == 3, "Duplicate network delivery must not double the burst")
	actor.set_meta("last_angelic_sword_hit_msec", Time.get_ticks_msec() - 150)
	game.spawn_neptune_trident_network_hit_particles(Vector2i(4, 3), "stone", "background", "angelic_sword", source_data)
	assert(game.get_child_count() == 4, "The next rapid hit must still be visible")
	game.spawn_neptune_trident_network_hit_particles(Vector2i(5, 3), "stone", "foreground", "punch", source_data)
	assert(game.get_child_count() == 4, "Another remote weapon must not emit a angelic burst")
	for effect in game.get_children():
		effect._process(effect.LIFETIME + 0.01)
	await process_frame
	assert(game.get_child_count() == 0, "Overlapping effects must all clean up")
	game.player_manager = null
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


func render_angelic_preview() -> void:
	root.size = Vector2i(1120, 540)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("10172a"))
	DirAccess.make_dir_recursive_absolute(ANGELIC_OUTPUT)
	world = TestWorld.new()
	root.add_child(world)
	playback = load("res://Scripts/player_manager.gd").new()
	var database = load("res://Scripts/item_database.gd").new()
	world.item_database["angelic_sword"] = database.get_item_data("angelic_sword")
	world.tool_textures["angelic_sword"] = Atlas.load_texture(world.item_database.angelic_sword.texture)
	var block_texture := Atlas.load_texture(database.get_item_data("stone").texture)
	database.free()
	source = load("res://Scenes/main.tscn").instantiate()
	var fixture := make_actor(Vector2(270, 315), 1.0, "angelic_sword")
	fixture.actor.scale = Vector2.ONE * 3.1
	fixture.trail.rng.seed = 177
	fixture.ap.play("RESET")
	fixture.ap.advance(0.0)
	fixture.ap.stop(true)
	var block := Sprite2D.new()
	block.texture = block_texture
	block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	block.position = Vector2(855, 300)
	block.scale = Vector2.ONE * 3.4
	root.add_child(block)
	add_label("ANGELIC SWORD", Vector2(30, 25), 1060, Color("fff0c8"), 29)
	add_label("WHITE SPARKLE / SLASH", Vector2(40, 92), 480, Color("d8e5ff"))
	add_label("ANGELIC IMPACT", Vector2(610, 92), 480, Color("d8e5ff"))
	add_label("Single strike, then rapid attacks", Vector2(30, 480), 1060, Color("b3c3d7"), 19)
	var effects: Array[Node2D] = []
	for frame in range(114):
		if frame in [18, 48, 54, 60, 66]:
			playback.play_animation_on_player(fixture.ap, "punch_sword")
			var effect := make_hit(Vector2(855, 300), -1 if frame >= 48 else 1, 3.4)
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
		root.get_texture().get_image().save_png(ANGELIC_OUTPUT.path_join("frame-%03d.png" % frame))
	fixture.actor.queue_free()
	source.free()
	playback.free()
	world.queue_free()
	await process_frame
	print("ANGELIC_SWORD_PREVIEW_PASS: ", ANGELIC_OUTPUT)
