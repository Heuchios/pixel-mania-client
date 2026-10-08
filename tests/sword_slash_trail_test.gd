extends SceneTree

const Equipment = preload("res://Scripts/equipment_manager.gd")
const Atlas = preload("res://Scripts/atlas_texture_factory.gd")
const OUTPUT := "D:/Pixelmania/sword-trails-preview"
const WEAPONS := ["blue_saber", "phoenix_sword", "angelic_sword", "sakura_sword", "red_saber", "green_saber", "void_saber", "void_trident", "blood_battleaxe", "serpent_staff"]

class TestWorld extends Node:
	var tool_textures := {}
	var item_database := {}

var source: Node
var world: TestWorld
var playback: Node


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


func make_actor(at: Vector2, facing: float, weapon: String = "blue_saber") -> Dictionary:
	var actor := Node2D.new()
	root.add_child(actor)
	actor.position = at
	actor.scale = Vector2.ONE * 4.0
	var visual: Node2D = source.get_node("Player/PlayerVisual").duplicate()
	strip(visual)
	actor.add_child(visual)
	visual.scale.x = facing
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.add_child(ap)
	var library := AnimationLibrary.new()
	for name in ["punch_sword", "walk", "RESET"]:
		library.add_animation(name, source.get_node("Player/AnimationPlayer").get_animation(name))
	ap.add_animation_library("", library)
	var equipment = Equipment.new()
	actor.add_child(equipment)
	equipment.set_process(false) # Remote equipment is also manually driven.
	equipment.world = world
	equipment.player = actor
	equipment.setup_wearable_animated_parts()
	equipment.update_equipped_tool_visual(weapon, int(facing))
	var trail = equipment.sword_slash_trail
	trail.set_process(false)
	return {"actor": actor, "visual": visual, "ap": ap, "equipment": equipment, "trail": trail, "weapon": weapon}


func sweep(fixture: Dictionary, fps: int = 60) -> void:
	fixture.trail._process(1.0)
	fixture.trail.clear()
	playback.play_animation_on_player(fixture.ap, "punch_sword")
	for frame in range(1, int(0.29 * fps)):
		fixture.ap.advance(1.0 / fps)
		fixture.trail._process(1.0 / fps)
	assert(fixture.trail.samples.size() > 3, "The rendered sword swing must leave a trail")
	assert(fixture.trail.samples.size() <= fixture.trail.MAX_SAMPLES)
	if fixture.trail.particle_rate > 0.0:
		assert(not fixture.trail.particles.is_empty(), "Themed weapons must emit their particles during a slash")
	var end: Vector2 = fixture.trail.samples.back().tip
	assert(end.distance_to(fixture.trail.blade.to_global(fixture.trail.blade_tip)) < 0.001, "Trail head must meet the blade tip")


func check_rapid_swings(fixture: Dictionary, fps: int) -> void:
	fixture.trail._process(1.0)
	fixture.trail.clear()
	var trail = fixture.trail
	var previous_phase := 0.0
	var next_punch := 0.0
	var dt := 1.0 / fps
	var radius := 0.0
	var manager = load("res://Scripts/player_animation_manager.gd").new()
	manager.player = fixture.actor
	manager.current_movement_animation_player = fixture.ap
	manager.current_movement_animation = "punch_sword"
	# Alternate actual local and remote restart entry points at a rapid cadence.
	for frame in range(fps):
		var time := frame * dt
		if time + 0.00001 >= next_punch:
			var phase_before: float = trail.swing_phase
			if int(round(next_punch / 0.10)) % 2 == 0:
				playback.play_animation_on_player(fixture.ap, "punch_sword")
			else:
				manager.restart_current_action_animation()
			if time > 0.0:
				assert(is_equal_approx(trail.swing_phase, phase_before), "Rapid local/remote punches must preserve the angular phase")
			next_punch += 0.10
		fixture.ap.advance(dt)
		trail._process(dt)
		assert(trail.particles.size() <= trail.MAX_PARTICLES, "Continuous rapid swings must keep a bounded particle count")
		assert(trail.swing_phase >= previous_phase, "The blade must never reverse or rewind")
		assert(trail.swing_phase - previous_phase <= trail.MAX_TURN_SPEED * dt + 0.0001, "No instant angle jumps between rapid punches")
		previous_phase = trail.swing_phase
		var pivot: Vector2 = fixture.visual.to_global(trail.SHOULDER_PIVOT)
		var current_radius: float = trail._blade_point(trail.blade_tip).distance_to(pivot)
		if frame == 0:
			radius = current_radius
		assert(absf(current_radius - radius) < 0.001, "The blade must follow a true circle around the shoulder")
		for sample in trail.samples:
			assert(absf(sample.tip.distance_to(pivot) - radius) < 0.001, "Interpolated trail samples must stay on the circle")
	# Simulate returning to locomotion while the last revolution finishes.
	fixture.ap.play("walk")
	var finishing := false
	var last_speed: float = trail.turn_speed
	var saw_soft_tip := false
	for frame in range(fps):
		fixture.ap.advance(dt)
		trail._process(dt)
		if trail.releasing and trail.swing_active:
			if finishing:
				assert(trail.turn_speed <= last_speed + 0.0001, "Release must decelerate smoothly")
			finishing = true
			last_speed = trail.turn_speed
		if trail.releasing and not trail.samples.is_empty() and trail.samples.back().strength < 0.2:
			saw_soft_tip = true
		if not trail.swing_active:
			assert(is_equal_approx(fposmod(trail.swing_phase, 1.0), 0.0), "Finish a complete circle before settling")
	assert(finishing and saw_soft_tip, "The ending must slow down and taper the light before it disappears")
	assert(not trail.swing_active and trail.samples.is_empty() and trail.particles.is_empty(), "No queued attacks or lingering effects after release")
	manager.free()


func run() -> void:
	world = TestWorld.new()
	root.add_child(world)
	playback = load("res://Scripts/player_manager.gd").new()
	var database = load("res://Scripts/item_database.gd").new()
	for item in WEAPONS + ["stone_pickaxe"]:
		world.item_database[item] = database.get_item_data(item)
		world.tool_textures[item] = Atlas.load_texture(world.item_database[item].texture)
	database.free()
	source = load("res://Scenes/main.tscn").instantiate()
	var fixtures: Array[Dictionary] = []
	for item in WEAPONS:
		for facing in [1.0, -1.0]:
			fixtures.append(make_actor(Vector2(270, 256), facing, item))
	for fixture in fixtures:
		var equipment = fixture.equipment
		var trail = fixture.trail
		equipment.update_equipped_tool_visual(fixture.weapon, 1)
		assert(equipment.sword_slash_trail == trail, "Refreshing equipment must reuse the effect")
		for fps in [30, 60, 120]:
			sweep(fixture, fps)
			fixture.ap.stop()
			for frame in range(fps):
				trail._process(1.0 / fps)
			assert(trail.samples.is_empty(), "The afterimage must expire after the swing")
			check_rapid_swings(fixture, fps)
		fixture.ap.play("walk")
		fixture.ap.advance(0.05)
		trail._process(0.05)
		assert(trail.samples.is_empty(), "Walking must not emit a slash")
		sweep(fixture)
		fixture.visual.scale.x *= -1
		trail._process(1.0 / 60.0)
		assert(trail.samples.size() == 1, "Turning must not connect opposite-facing trails")
		fixture.visual.scale.x *= -1
		sweep(fixture)
		fixture.actor.position.x += 1000
		trail._process(1.0 / 60.0)
		assert(trail.samples.size() == 1, "Teleporting must not draw across the world")
		fixture.actor.position.x -= 1000
		trail.blade.hide()
		trail._process(1.0 / 60.0)
		assert(trail.samples.is_empty() and trail.particles.is_empty(), "Placeable previews and hidden weapons must clear the effect")
		var next_weapon := "phoenix_sword" if fixture.weapon != "phoenix_sword" else "sakura_sword"
		equipment.update_equipped_tool_visual(next_weapon, 1)
		assert(equipment.sword_slash_trail != trail and not trail.visible, "Changing themed weapons must replace the prior effect")
		assert(equipment.sword_slash_trail.weapon_id == next_weapon)
		assert(equipment.sword_slash_trail.samples.is_empty() and equipment.sword_slash_trail.particles.is_empty(), "New weapon must not inherit old colors or particles")
		equipment.update_equipped_tool_visual("stone_pickaxe", 1)
		assert(equipment.sword_slash_trail == null, "Other equipment must not acquire sword effects")
		equipment.update_equipped_tool_visual(fixture.weapon, 1)
		fixture.trail = equipment.sword_slash_trail
		fixture.trail.set_process(false)
		assert(fixture.actor.get_node("PlayerVisual/SwordSlashTrail") == fixture.trail, "Same-frame re-equipping must preserve the animation hook")
	print("SWORD_TRAILS_PASS: ten weapons, both facings, 30/60/120 fps, rapid local/remote punches, circular motion, soft ending, particle emission/caps/expiry, equipment switching")
	for fixture in fixtures:
		fixture.equipment.clear_player_references()
		assert(fixture.equipment.sword_slash_trail == null)
		fixture.actor.queue_free()
	await process_frame
	if "--render-swords" in OS.get_cmdline_user_args():
		await render_preview()
	source.free()
	playback.free()
	world.queue_free()
	await process_frame
	quit()


func render_preview() -> void:
	root.size = Vector2i(1260, 920)
	root.content_scale_size = Vector2i(1260, 920)
	RenderingServer.set_default_clear_color(Color("101e32"))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var heading := Label.new()
	heading.text = "SWORD TRAILS"
	heading.position = Vector2(32, 24)
	heading.add_theme_font_size_override("font_size", 24)
	heading.modulate = Color("91eaff")
	root.add_child(heading)
	var actors: Array[Dictionary] = []
	var preview_weapons := WEAPONS.slice(1, 7)
	for i in range(preview_weapons.size()):
		var fixture := make_actor(Vector2(210 + (i % 3) * 420, 302 + int(i / 3) * 420), 1.0, preview_weapons[i])
		fixture.actor.scale = Vector2.ONE * 2.7
		fixture.trail.rng.seed = 410 + i
		actors.append(fixture)
		var label := Label.new()
		label.text = preview_weapons[i].replace("_", " ").to_upper()
		label.position = Vector2(50 + (i % 3) * 420, 92 + int(i / 3) * 420)
		label.size.x = 320
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.modulate = fixture.trail.palette[2]
		root.add_child(label)
	for frame in range(120):
		var cycle_frame := frame % 120
		for fixture in actors:
			var ap: AnimationPlayer = fixture.ap
			if cycle_frame == 0:
				fixture.trail._process(1.0)
				fixture.trail.clear()
				ap.play("RESET")
				ap.advance(0.0)
				ap.stop(true)
			# Ten punches per second, followed by release and a single slash.
			if (cycle_frame >= 6 and cycle_frame <= 45 and cycle_frame % 3 == 0) or cycle_frame == 84:
				playback.play_animation_on_player(ap, "punch_sword")
				ap.advance(0.0)
			for substep in range(2):
				ap.advance(1.0 / 60.0)
				fixture.trail._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("frame-%03d.png" % frame))
	for fixture in actors:
		fixture.actor.queue_free()
	print("SWORD_TRAILS_PREVIEW_PASS: ", OUTPUT)
