extends SceneTree

const Equipment := preload("res://Scripts/equipment_manager.gd")
const DB := preload("res://Scripts/item_database.gd")
const DRAGON_OUTPUT := "D:/Pixelmania/dragon-fire-wings-preview"

class WorldFixture extends Node:
	var item_database: Dictionary = DB.ITEMS
	var back_textures: Dictionary = {}

var world: WorldFixture
var source: Node


func _init() -> void:
	call_deferred("run")


func strip(node: Node) -> void:
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base")
	for child in node.get_children():
		strip(child)


func make_actor(at: Vector2, facing: float = 1.0) -> Dictionary:
	var actor := Node2D.new()
	root.add_child(actor)
	actor.position = at
	actor.scale = Vector2.ONE * 3.4
	var visual: Node2D = source.get_node("Player/PlayerVisual").duplicate()
	strip(visual)
	actor.add_child(visual)
	visual.scale.x = facing
	var manager := Equipment.new()
	actor.add_child(manager)
	manager.set_process(false)
	manager.world = world
	manager.player = actor
	manager.setup_back_socket()
	manager.setup_wearable_animated_parts()
	manager.set_forced_animation_state("idle")
	manager.update_equipped_back_visual("dragon_fire_wings", int(facing))
	var wings: AnimatedSprite2D = manager.back_sprite
	wings.set_process_internal(false)
	var fx = manager.back_item_fx
	fx.set_process(false)
	fx.rng.seed = 892
	fx.clock = 0.0
	return {"actor": actor, "manager": manager, "wings": wings, "fx": fx}


func run() -> void:
	world = WorldFixture.new()
	root.add_child(world)
	source = load("res://Scenes/main.tscn").instantiate()
	var data: Dictionary = DB.ITEMS.dragon_fire_wings
	assert(data.jump_type == "double" and data.flap_animation and not data.scan_flap_frames)
	assert(data.flap_frames == ["dragon_fire_wings_1", "dragon_fire_wings_4", "dragon_fire_wings_2"])
	assert(is_equal_approx(data.flap_speed, 0.24) and is_equal_approx(data.input_flap_time, 0.28))
	for other in ["lucifer_wings"]:
		assert(DB.ITEMS[other].back_fx_scene == "res://Scenes/particles/DragonFireWingsFX.tscn", "Other fire wings must retain their shared effect")
	assert(DB.ITEMS.golden_angel_wings.back_fx_scene == "res://Scenes/particles/GoldenAngelWingsFX.tscn")
	for facing in [1.0, -1.0]:
		var fixture := make_actor(Vector2(300, 300), facing)
		var manager = fixture.manager
		var fx = fixture.fx
		var wings: AnimatedSprite2D = fixture.wings
		assert(fx.wings == wings, "Fire must bind to the equipped wing sprite")
		manager.update_equipped_back_visual("dragon_fire_wings", int(facing))
		assert(manager.back_item_fx == fx, "Equipment refresh must reuse the effect")
		var original_poses := {"idle": [1, 2, 3], "jump": [2, 4, 1], "fall": [3, 5, 1]}
		for animation in ["idle", "jump", "fall"]:
			wings.play(animation)
			assert(wings.sprite_frames.get_frame_count(animation) == 3)
			assert(wings.sprite_frames.get_animation_loop(animation), "Original wing animation loops must remain unchanged")
			var expected_fps := 3.0 if animation == "idle" else 1.0 / 0.24
			assert(is_equal_approx(wings.sprite_frames.get_animation_speed(animation), expected_fps))
			for frame in range(3):
				wings.set_frame_and_progress(frame, 0.35)
				wings.set_process_internal(false)
				var texture := wings.sprite_frames.get_frame_texture(animation, frame) as AtlasTexture
				assert(texture.region == Rect2(32 + (original_poses[animation][frame] - 1) * 64, 448, 64, 32), "Fire must preserve the original atlas poses")
				assert(is_equal_approx(wings.sprite_frames.get_frame_duration(animation, frame), 1.0))
				assert(fx._edge_points().size() > 6, "Every pose must provide silhouette anchors")
				var transform_before := wings.transform
				for step in range(30):
					fx._process(1.0 / 60.0)
				assert(wings.animation == animation and wings.frame == frame and is_equal_approx(wings.frame_progress, 0.35), "Particles must never advance or replace wing animations")
				assert(wings.transform == transform_before, "Particles must never transform the wings")
		fx.clear()
		wings.play("idle")
		for frame in range(120):
			fx._process(1.0 / 60.0)
		assert(fx.particles.size() > 0 and fx.particles.size() < fx.MAX_PARTICLES)
		assert(fx.particles.all(func(p: Dictionary) -> bool: return not p.burst), "Idle must not trigger jump ignition")
		var particles_before: int = fx.particles.size()
		wings.set_frame_and_progress(2, 0.5)
		manager.restart_back_item_jump_animation()
		assert(wings.animation == "jump" and wings.frame == 0 and is_zero_approx(wings.frame_progress))
		assert(fx.particles.size() == particles_before + fx.JUMP_PARTICLES and is_zero_approx(fx.flap_age))
		var burst: Array = fx.particles.filter(func(p: Dictionary) -> bool: return p.burst)
		var edges: Array = fx._edge_points()
		var left_tip: Vector2 = fx._wing_point(edges[0])
		var right_tip: Vector2 = fx._wing_point(edges[-1])
		assert(burst.filter(func(p: Dictionary) -> bool: return p.position.is_equal_approx(left_tip)).size() == 12)
		assert(burst.filter(func(p: Dictionary) -> bool: return p.position.is_equal_approx(right_tip)).size() == 12)
		for spark in burst:
			assert(spark.velocity.y > 0.0 and spark.velocity.x * (spark.position.x - wings.global_position.x) > 0.0, "Jump downwash must fan out from both tips, including mirrored actors")
		manager.set_forced_animation_state("jump")
		manager.update_back_item_animation(1.0 / 60.0)
		assert(fx.particles.size() == particles_before + fx.JUMP_PARTICLES, "Looping flaps must not repeat the jump ignition")
		assert(fx.moving)
		var spark: Dictionary = burst[0]
		var old_position: Vector2 = spark.position
		fixture.actor.position.x += 50.0
		fx._process(1.0 / 60.0)
		assert(spark.position.distance_to(old_position) < 8.0, "Existing fire must stay in world space when the player moves")
		manager.set_forced_animation_state("fall")
		for frame in range(120):
			manager.update_back_item_animation(1.0 / 60.0)
			fx._process(1.0 / 60.0)
		assert(fx.particles.all(func(p: Dictionary) -> bool: return not p.burst), "Jump ignition must fade without restarting on falling or looping flaps")
		for jump in range(40):
			manager.restart_back_item_jump_animation()
		assert(fx.particles.size() == fx.MAX_PARTICLES)
		fixture.actor.position.x += 10000.0
		fx._process(1.0 / 60.0)
		assert(fx.particles.size() <= 1, "Teleporting must clear the old fire wake")
		wings.hide()
		fx._process(1.0 / 60.0)
		assert(fx.particles.is_empty())
		wings.show()
		manager.update_equipped_back_visual("lucifer_wings", int(facing))
		assert(manager.back_item_fx != fx and fx.is_queued_for_deletion())
		assert(not manager.back_item_fx.has_method("bind_wings"), "Lucifer wings must keep their original effect")
		manager.update_equipped_back_visual("", int(facing))
		assert(manager.back_item_fx == null)
		fixture.actor.queue_free()
	await process_frame
	print("DRAGON_WINGS_PASS: original poses/speeds/loops/transforms preserved; both facings; jump-only ignition; world-space fire; particle cap; hide/teleport/unequip cleanup; other-wing isolation")
	if "--render-dragon-wings" in OS.get_cmdline_user_args():
		await render_preview()
	source.free()
	world.queue_free()
	await process_frame
	quit()


func advance_wings(wings: AnimatedSprite2D, delta: float) -> void:
	# play() re-enables the internal clock; render at a fixed simulation rate.
	wings.set_process_internal(false)
	if not wings.is_playing():
		return
	var frames := wings.sprite_frames
	var frame := wings.frame
	var duration := frames.get_frame_duration(wings.animation, frame) / frames.get_animation_speed(wings.animation)
	var elapsed := wings.frame_progress * duration + delta
	while elapsed >= duration:
		elapsed -= duration
		frame += 1
		if frame >= frames.get_frame_count(wings.animation):
			if frames.get_animation_loop(wings.animation):
				frame = 0
			else:
				var animation := wings.animation
				wings.stop()
				wings.animation = animation
				wings.set_frame_and_progress(frames.get_frame_count(animation) - 1, 1.0)
				return
		duration = frames.get_frame_duration(wings.animation, frame) / frames.get_animation_speed(wings.animation)
	wings.set_frame_and_progress(frame, elapsed / duration)


func label(text: String, at: Vector2, width: float, size: int, tint: Color) -> void:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size.x = width
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", size)
	node.modulate = tint
	root.add_child(node)


func render_preview() -> void:
	root.size = Vector2i(1120, 540)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("10172a"))
	DirAccess.make_dir_recursive_absolute(DRAGON_OUTPUT)
	var idle := make_actor(Vector2(185, 345))
	var walking := make_actor(Vector2(555, 345), -1.0)
	var airborne := make_actor(Vector2(925, 345))
	walking.manager.set_forced_animation_state("walk")
	label("DRAGON FIRE WINGS", Vector2(20, 26), 1080, 29, Color("ffe0a0"))
	label("SMOLDERING EDGES", Vector2(10, 106), 350, 20, Color("cfb78c"))
	label("EMBER WAKE", Vector2(380, 106), 350, 20, Color("cfb78c"))
	label("JUMP IGNITION", Vector2(750, 106), 350, 20, Color("cfb78c"))
	label("Living flame edges / rising embers / original wing animations", Vector2(20, 482), 1080, 18, Color("bcb09b"))
	# Give idle embers time to populate before recording.
	for frame in range(75):
		for fixture in [idle, walking, airborne]:
			advance_wings(fixture.wings, 1.0 / 60.0)
			fixture.fx._process(1.0 / 60.0)
	var jump_start := -100.0
	for frame in range(150):
		var time := float(frame) / 30.0
		if frame in [15, 36, 95, 112]:
			airborne.manager.set_forced_animation_state("jump")
			airborne.manager.restart_back_item_jump_animation()
			jump_start = time
		var air_age := time - jump_start
		if air_age >= 0.85:
			airborne.manager.set_forced_animation_state("idle")
		elif air_age >= 0.40:
			airborne.manager.set_forced_animation_state("fall")
		airborne.actor.position.y = 345.0 - sin(clampf(air_age / 0.85, 0.0, 1.0) * PI) * 72.0
		walking.actor.position.x = 555.0 + sin(time * 2.0) * 60.0
		for substep in range(2):
			for fixture in [idle, walking, airborne]:
				fixture.manager.update_back_item_animation(1.0 / 60.0)
				advance_wings(fixture.wings, 1.0 / 60.0)
				fixture.fx._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DRAGON_OUTPUT.path_join("frame-%03d.png" % frame))
	for fixture in [idle, walking, airborne]:
		fixture.actor.queue_free()
	await process_frame
	print("DRAGON_WINGS_PREVIEW_PASS: ", DRAGON_OUTPUT)
