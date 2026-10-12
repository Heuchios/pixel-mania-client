extends SceneTree

const EMOTES = preload("res://Scripts/player_emotes.gd")
var failures := 0
var checks := 0

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var world = load("res://tests/void_trident_world_fixture.gd").new()
	root.add_child(world)
	var template = load("res://Scenes/main.tscn").instantiate()
	var actor := Node2D.new()
	world.add_child(actor)
	world.player = actor
	world.in_world = true
	for node_name in ["PlayerVisual", "AnimationPlayer", "Jump", "idle", "EmoteAnimationPlayer", "DeadSpiritAnimated"]:
		actor.add_child(template.get_node("Player/" + node_name).duplicate())
	check(actor.get_node("EmoteAnimationPlayer").has_animation("dance"), "Main player exposes the authored dance in Godot")
	var netfox = load("res://Scenes/player/netfox_player.tscn").instantiate()
	check(netfox.get_node("EmoteAnimationPlayer").has_animation("dance"), "Netfox player exposes the same authored dance")
	netfox.free()
	var database = load("res://Scripts/item_database.gd").new()
	for id in ["basic_blue_shirt", "basic_black_pants", "basic_red_shoes", "red_baseball_cap", "angel_wings", "blue_saber"]:
		world.item_database[id] = database.get_item_data(id)
	world.tool_textures["blue_saber"] = preload("res://Scripts/atlas_texture_factory.gd").load_texture(world.item_database["blue_saber"].texture)
	database.free()
	var equipment = load("res://Scripts/equipment_manager.gd").new()
	actor.add_child(equipment)
	equipment.setup(world, actor, false)
	equipment.set_process(false)
	equipment.update_equipped_shirt_visual("basic_blue_shirt", 1)
	equipment.update_equipped_pants_visual("basic_black_pants", 1)
	equipment.update_equipped_shoes_visual("basic_red_shoes", 1)
	equipment.update_equipped_hat_visual("red_baseball_cap", 1)
	equipment.update_equipped_back_visual("angel_wings", 1)
	equipment.update_equipped_tool_visual("blue_saber", 1)
	var animation = load("res://Scripts/player_animation_manager.gd").new()
	actor.add_child(animation)
	animation.setup(world, actor)
	for ap in animation.get_all_movement_animation_players():
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var attachments := {}
	for path in ["Body/ShirtBodyAnimated", "LeftArm/LeftSleeveAnimated", "RightArm/RightSleeveAnimated", "Bottom/PantsAnimated", "LeftFoot/LeftShoeAnimated", "RightFoot/RightShoeAnimated", "Head/HatAnimated", "BackSlot/BackItemAnimated", "HandItem/HandItemAnimated"]:
		var item: Node2D = actor.get_node("PlayerVisual/" + path)
		check(item.visible, "Equipped item is visible: " + path)
		attachments[path] = item.transform
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 520)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = viewport.size
	background.color = Color("172540")
	viewport.add_child(background)
	for row in 2:
		var facing := 1 if row == 0 else -1
		animation.update_player_animation(0.0, facing)
		EMOTES.play(actor, "dance")
		var controller = actor.get_node("PlayerEmotes")
		var rest: Array = controller.poses.duplicate(true)
		controller.set_process(false)
		for column in 4:
			animation.update_player_animation(0.1, facing)
			actor.get_node("idle").advance(0.1)
			controller.elapsed = 0.2 + column * 0.4
			controller._process(0.0)
			var visual: Node2D = actor.get_node("PlayerVisual")
			check(signf(visual.scale.x) == facing, "Dance respects facing direction")
			check(visual.get_node("Body").transform.is_equal_approx(visual.get_node("Bottom").transform), "Torso stays connected to the hips")
			check(visual.get_node("HandItem").transform.is_equal_approx(visual.get_node("RightArm").transform), "Held item follows the dancing hand")
			for path in attachments:
				check(visual.get_node(path).transform.is_equal_approx(attachments[path]), "Dance preserves clothing attachment: " + path)
			check(actor.position == Vector2.ZERO, "Dance leaves gameplay position unchanged")
			var sample := visual.duplicate()
			sample.position = Vector2(125 + column * 250, 180 + row * 250)
			sample.scale = Vector2(facing * 4, 4)
			viewport.add_child(sample)
			var label := Label.new()
			label.position = Vector2(70 + column * 250, 225 + row * 250)
			label.text = "%s / %.1fs" % ["RIGHT" if facing == 1 else "LEFT", controller.elapsed]
			viewport.add_child(label)
		# Exercise the actual remote-cloning path while the source actor dances.
		var manager = load("res://Scripts/player_manager.gd").new()
		world.add_child(manager)
		manager.world = world
		var remote := Node2D.new()
		world.add_child(remote)
		check(manager.ensure_remote_player_shared_visual_pipeline(remote), "Remote rig can spawn during a local dance")
		for pose in rest:
			var part = remote.get_node("PlayerVisual/" + str(pose.node.name))
			check(part.position.is_equal_approx(pose.position), "Remote spawn restores position: " + str(part.name))
			if part.name != &"RightArm" and part.name != &"HandItem":
				check(is_equal_approx(part.rotation, pose.rotation), "Remote spawn restores rotation: " + str(part.name))
		remote.free()
		manager.free()
		EMOTES.cancel(actor)
		EMOTES.cancel(actor)
		for pose in rest:
			check(pose.node.position.is_equal_approx(pose.position) and is_equal_approx(pose.node.rotation, pose.rotation), "Repeated cancellation restores " + str(pose.node.name))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://previews")
		check(viewport.get_texture().get_image().save_png("res://previews/player_dance_rig.png") == OK, "Dressed dance contact sheet renders")
	template.free()
	world.free()
	viewport.free()
	print("[player-dance-rig] %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
