extends SceneTree

const Equipment := preload("res://Scripts/equipment_manager.gd")
const DB := preload("res://Scripts/item_database.gd")
const GOLD_OUTPUT := "D:/Pixelmania/golden-angel-wings-preview"

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
	manager.update_equipped_back_visual("golden_angel_wings", int(facing))
	var wings: AnimatedSprite2D = manager.back_sprite
	wings.set_process_internal(false)
	var fx = manager.back_item_fx
	fx.set_process(false)
	fx.rng.seed = 892
	return {"actor": actor, "manager": manager, "wings": wings, "fx": fx}


func run() -> void:
	world = WorldFixture.new()
	root.add_child(world)
	source = load("res://Scenes/main.tscn").instantiate()
	assert(DB.ITEMS.golden_angel_wings.jump_type == "double")
	assert(DB.ITEMS.angel_wings.back_fx_scene == "res://Scenes/particles/WingSparkleParticlesFX.tscn", "Standard angel wings must retain their existing effect")
	for facing in [1.0, -1.0]:
		var fixture := make_actor(Vector2(300, 300), facing)
		var manager = fixture.manager
		var fx = fixture.fx
		var wings: AnimatedSprite2D = fixture.wings
		assert(fx.wings == wings, "Particles must bind to the rendered wing sprite")
		manager.update_equipped_back_visual("golden_angel_wings", int(facing))
		assert(manager.back_item_fx == fx, "Equipment refresh must reuse the effect")
		assert(wings.sprite_frames.get_frame_count("idle") == 3)
		assert(wings.sprite_frames.get_frame_count("jump") == 3)
		assert(wings.sprite_frames.get_animation_loop("jump"), "The original looping flap must remain unchanged")
		assert(is_equal_approx(wings.sprite_frames.get_animation_speed("idle"), 3.0))
		assert(is_equal_approx(wings.sprite_frames.get_animation_speed("jump"), 1.0 / 0.30))
		var original_poses := {"idle": [1, 2, 3], "jump": [2, 4, 1], "fall": [3, 5, 1]}
		for animation in ["idle", "jump", "fall"]:
			wings.play(animation)
			for frame in range(wings.sprite_frames.get_frame_count(animation)):
				wings.frame = frame
				var texture := wings.sprite_frames.get_frame_texture(animation, frame) as AtlasTexture
				assert(texture.region == Rect2(32 + (original_poses[animation][frame] - 1) * 64, 224, 64, 32), "Particle work must preserve the original wing poses")
				assert(is_equal_approx(wings.sprite_frames.get_frame_duration(animation, frame), 1.0))
				assert(fx._edge_points().size() > 6, "Every pose must have emission anchors on its feathers")
		wings.play("idle")
		for frame in range(120):
			fx._process(1.0 / 60.0)
		assert(fx.particles.size() > 0 and fx.particles.size() < fx.MAX_PARTICLES)
		assert(fx.particles.all(func(p: Dictionary) -> bool: return p.kind != "feather"), "Idle shimmer must not shed feathers")
		fx.set_moving(true)
		for frame in range(120):
			fx._process(1.0 / 60.0)
		assert(fx.particles.all(func(p: Dictionary) -> bool: return p.kind != "feather"), "Movement alone must not shed feathers")
		var particles_before: int = fx.particles.size()
		wings.set_frame_and_progress(2, 0.5)
		manager.restart_back_item_jump_animation()
		assert(wings.animation == "jump" and wings.frame == 0 and is_zero_approx(wings.frame_progress))
		assert(fx.particles.size() == particles_before + 14 and is_zero_approx(fx.flap_age), "Accepted local/remote jumps must release the stardust flourish")
		var feathers: Array = fx.particles.filter(func(p: Dictionary) -> bool: return p.kind == "feather")
		assert(feathers.size() == 4, "Each jump must shed a small, balanced feather burst")
		var edges: Array = fx._edge_points()
		var left_tip: Vector2 = fx._wing_point(edges[0])
		var right_tip: Vector2 = fx._wing_point(edges[-1])
		assert(feathers.filter(func(p: Dictionary) -> bool: return p.position.is_equal_approx(left_tip)).size() == 2, "Two feathers must originate at the current left wing tip")
		assert(feathers.filter(func(p: Dictionary) -> bool: return p.position.is_equal_approx(right_tip)).size() == 2, "Two feathers must originate at the current right wing tip, including mirrored actors")
		for feather in feathers:
			assert(feather.velocity.y > 0.0 and feather.velocity.x * (feather.position.x - wings.global_position.x) > 0.0, "Feathers must drift down and outward on either facing")
		manager.set_forced_animation_state("jump")
		manager.update_back_item_animation(1.0 / 60.0)
		assert(fx.particles.size() == particles_before + 14, "Ordinary animation updates must not repeat the jump burst")
		assert(fx.moving)
		var particle: Dictionary = fx.particles[0]
		var old_position: Vector2 = particle.position
		fixture.actor.position.x += 50.0
		fx._process(1.0 / 60.0)
		assert(particle.position.distance_to(old_position) < 8.0, "Existing dust must remain behind in world space when the player moves")
		manager.set_forced_animation_state("fall")
		for frame in range(180):
			manager.update_back_item_animation(1.0 / 60.0)
			fx._process(1.0 / 60.0)
		assert(fx.particles.all(func(p: Dictionary) -> bool: return p.kind != "feather"), "Jump feathers must fade without being replenished by falling or looping flaps")
		for jump in range(40):
			manager.restart_back_item_jump_animation()
		assert(fx.particles.size() == fx.MAX_PARTICLES, "Repeated jumps must keep a bounded particle count")
		fixture.actor.position.x += 10000.0
		fx._process(1.0 / 60.0)
		assert(fx.particles.size() <= 1, "A teleport must clear the old particle wake")
		wings.hide()
		fx._process(1.0 / 60.0)
		assert(fx.particles.is_empty())
		wings.show()
		manager.update_equipped_back_visual("angel_wings", int(facing))
		assert(manager.back_item_fx != fx and fx.is_queued_for_deletion(), "Switching wings must remove the golden particles")
		manager.update_equipped_back_visual("", int(facing))
		assert(manager.back_item_fx == null)
		fixture.actor.queue_free()
	await process_frame
	print("GOLDEN_WINGS_PASS: original poses/speeds/loops preserved, jump-only feathers at both tips, idle/movement/fall isolation, both facings, particle cap, world-space wake, hiding/teleport/unequip cleanup, other-wing isolation")
	if "--render-golden-wings" in OS.get_cmdline_user_args():
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
	DirAccess.make_dir_recursive_absolute(GOLD_OUTPUT)
	var idle := make_actor(Vector2(185, 345))
	var walking := make_actor(Vector2(555, 345), -1.0)
	var airborne := make_actor(Vector2(925, 345))
	walking.manager.set_forced_animation_state("walk")
	label("GOLDEN ANGEL WINGS", Vector2(20, 26), 1080, 29, Color("ffe0a0"))
	label("IDLE SHIMMER", Vector2(10, 106), 350, 20, Color("cfb78c"))
	label("GOLDEN STARDUST", Vector2(380, 106), 350, 20, Color("cfb78c"))
	label("JUMP FLOURISH", Vector2(750, 106), 350, 20, Color("cfb78c"))
	label("Slow golden stardust / tip feathers on jumps / original wing animations", Vector2(20, 482), 1080, 18, Color("bcb09b"))
	# Give idle dust time to populate before recording.
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
		root.get_texture().get_image().save_png(GOLD_OUTPUT.path_join("frame-%03d.png" % frame))
	for fixture in [idle, walking, airborne]:
		fixture.actor.queue_free()
	await process_frame
	print("GOLDEN_WINGS_PREVIEW_PASS: ", GOLD_OUTPUT)
