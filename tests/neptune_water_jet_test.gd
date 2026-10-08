extends SceneTree

const Manager := preload("res://Scripts/particle_manager.gd")
const Jet := preload("res://Scenes/particles/WaterSurgeBeamFX.tscn")
const OUTPUT := "D:/Pixelmania/neptune-water-preview"

class TestWorld extends Node2D:
	var in_world := true

class RemoteActors extends RefCounted:
	var remote_players := {}


func _init() -> void:
	call_deferred("run")


func origin(actor: Node2D) -> Vector2:
	return actor.global_position + Vector2(16, -2)


func fire(manager, actor: Node2D, target: Vector2):
	manager.spawn_water_surge_beam(origin(actor), target, false, actor, "", origin.bind(actor))
	var jet = manager.active_water_jets[str(actor.get_instance_id())]
	jet.set_process(false)
	return jet


func run() -> void:
	for fps in [30, 60, 120]:
		var world := TestWorld.new()
		root.add_child(world)
		var manager := Manager.new()
		world.add_child(manager)
		manager.setup(world, false)
		var actor := Node2D.new()
		world.add_child(actor)
		actor.position = Vector2(40, 120)
		var target := Vector2(396, 118)
		var jet = fire(manager, actor, target)
		var total_particles := 0
		for emitter in jet.source_layers + jet.stream_layers + jet.impact_layers:
			total_particles += emitter.amount
			assert(emitter.preprocess == 0.0, "Do not prefill particles ahead of the moving water")
			var material: ParticleProcessMaterial = emitter.process_material
			var fade: Gradient = material.color_ramp.gradient
			assert(fade.get_color(fade.get_point_count() - 1).a == 0.0)
		assert(total_particles <= 90)
		for emitter in jet.impact_layers:
			assert(not emitter.emitting and not emitter.one_shot, "Splash starts on arrival and then emits continuously")
		assert(jet._front_distance == 0.0)
		var next_shot := 0.3
		for frame in range(fps * 2):
			var time: float = float(frame) / fps
			actor.position.x += 3.0 / fps
			if time + 0.00001 >= next_shot:
				var phase: float = jet._time
				var front: float = jet._front_distance
				assert(fire(manager, actor, target) == jet, "Held attacks must reuse one jet")
				assert(jet._time == phase and jet._front_distance == front, "Refreshing must not rewind water or particles")
				next_shot += 0.3
			jet._process(1.0 / fps)
			assert(jet.global_position.distance_to(origin(actor)) < 0.001, "Nozzle follows the current hand every frame")
			assert(not jet._draining and manager.get_child_count() == 1)
			if time < 0.35:
				assert(not jet._has_impact(), "No splash before the traveling front reaches the target")
			if time > 0.65:
				assert(jet._has_impact() and jet.impact_layers[0].emitting)
		# A second player firing in the opposite direction must own a separate jet.
		var other := Node2D.new()
		world.add_child(other)
		other.position = Vector2(400, 220)
		var other_jet = fire(manager, other, Vector2(70, 250))
		assert(other_jet != jet and manager.active_water_jets.size() == 2)
		assert(absf(other_jet.rotation) > 2.5)
		assert(other_jet.stream_layers[0].process_material != jet.stream_layers[0].process_material)
		# Retargeting preserves the flow clock and respects very close targets.
		var phase: float = jet._time
		assert(fire(manager, actor, origin(actor) + Vector2(0, -12)) == jet)
		jet._process(1.0 / fps)
		assert(jet.beam_length_px == 12.0 and jet._time > phase)
		assert(jet._make_beam_path(12, 0)[-1].x <= 12.0)
		var saw_draining := false
		for frame in range(fps * 2):
			if not jet.is_queued_for_deletion():
				jet._process(1.0 / fps)
				saw_draining = saw_draining or jet._draining
			if not other_jet.is_queued_for_deletion():
				other_jet._process(1.0 / fps)
		assert(saw_draining and jet.is_queued_for_deletion() and other_jet.is_queued_for_deletion(), "Release must flush the stream and finish its particle fade")
		await process_frame
		assert(manager.active_water_jets.is_empty() and manager.get_child_count() == 0)
		var removed_actor_jet = fire(manager, other, Vector2(70, 250))
		other.free()
		removed_actor_jet._process(1.0 / fps)
		assert(removed_actor_jet._draining, "Disconnected actors must stop emitting")
		manager.clear_particles()
		await process_frame
		assert(manager.get_child_count() == 0 and manager.active_water_jets.is_empty(), "World cleanup must remove active and draining jets")
		world.free()
	await check_world_routes()
	print("NEPTUNE_JET_PASS: 30/60/120 fps, sustained 300ms attacks, travel before impact, live nozzle tracking, independent players, close/left/up targets, complete tail fade and cleanup")
	if "--render-neptune" in OS.get_cmdline_user_args():
		await render_preview()
	quit()


func check_world_routes() -> void:
	var world = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(world)
	world.in_world = true
	world.equipped_tool = "neptune_trident"
	var actor := Node2D.new()
	root.add_child(actor)
	actor.position = Vector2(40, 100)
	world.player = actor
	var manager := Manager.new()
	world.add_child(manager)
	manager.setup(world, false)
	world.particle_manager = manager
	world.spawn_neptune_trident_block_hit_particles(Vector2i(6, 3), "stone", "foreground", "neptune_trident")
	world.spawn_neptune_trident_swing_particles(Vector2(200, 96))
	assert(manager.get_child_count() == 1, "Local block and empty-swing routes must share the same jet")
	var remote := Node2D.new()
	root.add_child(remote)
	remote.position = Vector2(300, 100)
	remote.set_meta("equipment_slots", {"hand": "neptune_trident"})
	world.player_manager = RemoteActors.new()
	world.player_manager.remote_players["remote"] = remote
	var data := {"player_id": "remote", "actor_facing": -1}
	world.spawn_neptune_trident_network_hit_particles(Vector2i(6, 3), "stone", "foreground", "neptune_trident", data)
	world.spawn_neptune_trident_network_hit_particles(Vector2i(6, 3), "stone", "foreground", "neptune_trident", data)
	assert(manager.get_child_count() == 2, "Remote repeats must refresh only that remote actor's stream")
	world.equipped_tool = "void_trident"
	var local_jet = manager.active_water_jets[str(actor.get_instance_id())]
	local_jet._process(0.016)
	assert(local_jet._draining, "Unequipping Neptune must end its stream")
	manager.clear_particles()
	world.player_manager = null
	world.player = null
	world.free()
	actor.free()
	remote.free()
	await process_frame


func render_preview() -> void:
	root.size = Vector2i(1100, 520)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("101e32"))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var world := TestWorld.new()
	root.add_child(world)
	var manager := Manager.new()
	world.add_child(manager)
	manager.setup(world, false)
	var database = load("res://Scripts/item_database.gd").new()
	var atlas = load("res://Scripts/atlas_texture_factory.gd")
	var weapon_texture: Texture2D = atlas.load_texture(database.get_item_data("neptune_trident").texture)
	var block_texture: Texture2D = atlas.load_texture(database.get_item_data("stone").texture)
	database.free()
	var labels := ["NEPTUNE TRIDENT / CONTINUOUS JET", "Held fire", "Release - water finishes traveling"]
	for i in range(3):
		var label := Label.new()
		label.text = labels[i]
		label.position = Vector2(30, 25 if i == 0 else 450 if i == 1 else 480)
		label.size.x = 1040
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24 if i == 0 else 18)
		label.modulate = Color("9aeaff") if i == 0 else Color("9faec9")
		root.add_child(label)
	var actor := Node2D.new()
	world.add_child(actor)
	actor.position = Vector2(185, 265)
	var weapon := Sprite2D.new()
	weapon.texture = weapon_texture
	weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon.scale = Vector2.ONE * 3.0
	actor.add_child(weapon)
	var target := Vector2(915, 265)
	var block := Sprite2D.new()
	block.texture = block_texture
	block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	block.scale = Vector2.ONE * 3.0
	block.position = target
	world.add_child(block)
	# Uniform parent scale keeps preview distances and water width in game units.
	manager.scale = Vector2.ONE * 3.0
	var jet = null
	for frame in range(138):
		actor.position.y = 265 + sin(float(frame) / 30.0 * 1.8) * 18.0
		if frame >= 9 and frame <= 81 and (frame - 9) % 9 == 0:
			var source_callback := func() -> Vector2: return actor.global_position + Vector2(63, -3)
			manager.spawn_water_surge_beam(source_callback.call(), target, false, actor, "", source_callback)
			jet = manager.active_water_jets[str(actor.get_instance_id())]
			jet.set_process(false)
		for substep in range(2):
			if is_instance_valid(jet) and not jet.is_queued_for_deletion():
				jet._process(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("frame-%03d.png" % frame))
	world.free()
	await process_frame
	print("NEPTUNE_PREVIEW_PASS: ", OUTPUT)
