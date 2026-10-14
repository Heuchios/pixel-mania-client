extends SceneTree

const Equipment = preload("res://Scripts/equipment_manager.gd")
const OUTPUT := "D:/Pixelmania/cape-bats-jump-preview"

class WorldFixture extends Node:
	var item_database: Dictionary = {}
	var back_textures: Dictionary = {}
	var equipment_manager: Node

var world: WorldFixture
var source: Node


func _initialize() -> void:
	call_deferred("run")


func strip(node: Node) -> void:
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base")
	for child in node.get_children():
		strip(child)


func make_actor(id: String, at: Vector2, facing: int = 1) -> Dictionary:
	var actor := Node2D.new()
	root.add_child(actor)
	actor.position = at
	actor.scale = Vector2.ONE * 3.5
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
	manager.update_equipped_back_visual(id, facing)
	manager.back_sprite.set_process_internal(false)
	manager.back_item_fx.set_process(false)
	manager.back_item_fx.rng.seed = 55
	return {"actor": actor, "manager": manager, "fx": manager.back_item_fx}


func run() -> void:
	create_timer(25.0).timeout.connect(func(): quit(1))
	world = WorldFixture.new()
	root.add_child(world)
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	source = load("res://Scenes/main.tscn").instantiate()
	for id in ["vampire_cape", "dracula_cape"]:
		for facing in [1, -1]:
			for fps in [30, 60, 120]:
				var fixture := make_actor(id, Vector2(300, 300), facing)
				var fx = fixture.fx
				var manager = fixture.manager
				for animation in ["idle", "walk", "fall", "jump"]:
					manager.set_forced_animation_state(animation)
					for i in range(10):
						manager.update_back_item_animation(1.0 / fps)
						fx._process(1.0 / fps)
					assert(fx.particles.is_empty(), "Pose and movement updates cannot emit bats")
				# Exercise real accepted/rejected jump gates with the existing movement fixture.
				var player = load("res://tests/dev_wings_jumping_player_fixture.gd").new()
				world.equipment_manager = manager
				player.fixture_world = world
				player.allowed_air_jumps = 1
				player.coyote_timer = 0.1
				assert(player.try_jump())
				assert(fx.particles.size() == fx.BURST_COUNT)
				assert(player.try_jump())
				assert(fx.particles.size() == fx.BURST_COUNT * 2)
				assert(not player.try_jump())
				assert(fx.particles.size() == fx.BURST_COUNT * 2, "Rejected jump must not create another flock")
				var bat: Dictionary = fx.particles[0]
				var before: Vector2 = fx.bat_position(bat)
				fixture.actor.position.x += 40
				assert(fx.bat_position(bat).is_equal_approx(before), "Moving the actor must not drag the world-space flock")
				fx._process(1.0 / fps)
				assert(fx.bat_position(bat).is_finite(), "The fast initial blast must retain a finite flight path")
				manager.set_forced_animation_state("fall")
				for frame in range(fps * 2):
					manager.update_back_item_animation(1.0 / fps)
					fx._process(1.0 / fps)
				assert(fx.particles.is_empty() and not fx.is_processing())
				for jump in range(20):
					manager.restart_back_item_jump_animation()
				assert(fx.particles.size() == fx.MAX_BATS)
				fixture.actor.position.x += 5000
				fx._process(1.0 / fps)
				assert(fx.particles.is_empty(), "Teleport clears the old flock")
				manager.restart_back_item_jump_animation()
				manager.back_sprite.hide()
				fx._process(1.0 / fps)
				assert(fx.particles.is_empty())
				player.free()
				fixture.actor.free()
	print("CAPE_BATS_PASS: both capes/facings, 30/60/120 fps, accepted ground/air jumps, rejected jump, no pose-driven emission, world-space motion, cap/expiry/teleport/hide cleanup")
	if "--render-bats" in OS.get_cmdline_user_args():
		await render_preview()
	source.free()
	world.free()
	quit()


func label(text: String, x: float, y: float, width: float, size: int) -> void:
	var node := Label.new()
	node.text = text
	node.position = Vector2(x, y)
	node.size.x = width
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", size)
	root.add_child(node)


func render_preview() -> void:
	root.get_node("GlobalFontManager").free()
	root.size = Vector2i(1280, 640)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("16233c"))
	label("BAT SWARM / JUMP SCARE BLAST", 0, 24, 1280, 25)
	label("VAMPIRE CAPE", 20, 93, 600, 20)
	label("DRACULA CAPE", 660, 93, 600, 20)
	label("Idle  /  jump  /  air jump  /  fade", 0, 585, 1280, 18)
	var fixtures := [make_actor("vampire_cape", Vector2(320, 430)), make_actor("dracula_cape", Vector2(960, 430), -1)]
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for frame in range(150):
		for fixture in fixtures:
			if frame in [24, 40]:
				fixture.manager.set_forced_animation_state("jump")
				fixture.manager.restart_back_item_jump_animation()
			if frame == 55:
				fixture.manager.set_forced_animation_state("fall")
			if frame == 76:
				fixture.manager.set_forced_animation_state("idle")
			var rise := sin(clampf(float(frame - 24) / 52.0, 0, 1) * PI) * 110
			fixture.actor.position.y = 430 - rise
			fixture.manager.update_back_item_animation(1.0 / 30.0)
			fixture.fx._process(1.0 / 30.0)
			fixture.fx.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("frame-%03d.png" % frame))
	for fixture in fixtures:
		fixture.actor.free()
	print("CAPE_BATS_PREVIEW_PASS: ", OUTPUT)
