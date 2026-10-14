extends SceneTree

const MANAGER = preload("res://Scripts/player_animation_manager.gd")
const FACES = preload("res://Assets/player/expressions/face_expressions.tres")
const EMOTES = preload("res://Scripts/player_emotes.gd")
var failures := 0

class WorldProbe extends Node:
	var in_world := true
	var player: Node2D
	var blocks := {}
	var typing := false
	func is_chat_typing() -> bool: return typing

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var duration := 0.0
	for frame in FACES.get_frame_count("sleep"):
		duration += FACES.get_frame_duration("sleep", frame) / FACES.get_animation_speed("sleep")
		check(FACES.get_frame_texture("sleep", frame).get_size() == Vector2(32, 32), "Sleep preserves the face canvas")
	check(FACES.get_animation_loop("sleep"), "Sleep face loops")
	check(is_equal_approx(duration, MANAGER.SLEEP_LIBRARY.get_animation("sleep").length), "Mouth cycle keeps its slow period")
	var closed: Image = FACES.get_frame_texture("sleep", 0).get_image()
	var opened: Image = FACES.get_frame_texture("sleep", 1).get_image()
	for y in 13:
		for x in 32:
			var a := closed.get_pixel(x, y)
			var b := opened.get_pixel(x, y)
			check(a.is_equal_approx(b), "Every upper-face pixel stays fixed when the mouth opens")
			if x >= 12 and x <= 24 and y >= 7:
				check(not (a.r > 0.9 and a.g > 0.9 and a.b > 0.9), "Closed-mouth eyes stay shut")
				check(not (b.r > 0.9 and b.g > 0.9 and b.b > 0.9), "Open-mouth eyes stay shut")
	check(closed.get_data() == opened.get_data(), "Sleep keeps a fixed face beneath the mouth overlay")
	check(MANAGER.SLEEP_MOUTH_TEXTURE.get_size() == Vector2(32, 32), "Mouth overlay shares the face canvas")
	check(MANAGER.SLEEP_MOUTH_TEXTURE.margin.position.y >= 13, "Mouth overlay cannot cover the eyes")
	for scene_path in ["res://Scenes/main.tscn", "res://Scenes/player/netfox_player.tscn"]:
		var source: Node = load(scene_path).instantiate()
		var rig: Node = source.get_node("Player") if scene_path.ends_with("main.tscn") else source
		var world := WorldProbe.new()
		root.add_child(world)
		var actor := Node2D.new()
		world.add_child(actor)
		world.player = actor
		for name in ["PlayerVisual", "Sprite2D", "DeadSpiritAnimated", "AnimationPlayer", "Jump", "idle"]:
			var part := rig.get_node_or_null(name)
			if part != null: actor.add_child(part.duplicate())
		var manager := MANAGER.new()
		actor.add_child(manager)
		manager.setup(world, actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		var visual := actor.get_node("PlayerVisual")
		var feet := [visual.get_node("LeftFoot").position, visual.get_node("RightFoot").position]
		var root_position := actor.position
		var original_scale: Vector2 = visual.scale
		actor.set_meta("activity_bubble", "afk")
		manager.update_player_animation(0.0, 1)
		check(manager.current_movement_animation == "sleep", "AFK selects standing sleep on " + scene_path)
		check(manager.face_expression_animated.animation == &"sleep", "AFK selects the closed-eye mouth cycle")
		var sleeper: AnimationPlayer = actor.get_node("SleepAnimationPlayer")
		var standing_pose := {}
		for name in ["Head", "Body", "Bottom", "LeftArm", "RightArm", "HandItem", "BackSlot"]:
			standing_pose[name] = visual.get_node(name).transform
		for sample in 72:
			sleeper.advance(0.05)
			for name in standing_pose:
				check(visual.get_node(name).transform == standing_pose[name], name + " stays completely still throughout sleep")
		sleeper.seek(1.8, true)
		check(visual.get_node("LeftFoot").position == feet[0] and visual.get_node("RightFoot").position == feet[1], "Both feet stay planted")
		check(actor.position == root_position and visual.scale == original_scale, "Sleep never changes physics position or body size")
		var clone := visual.duplicate()
		check(clone.get_node("Head").position == Vector2(1, 0) and clone.get_node("Body").position == Vector2.ZERO, "New remote avatars inherit a standing pose")
		clone.free()
		var mouth: Sprite2D = manager.face_expression_animated.get_node("SleepMouth")
		check(not mouth.visible, "Closed-mouth phase hides the overlay")
		manager.face_expression_animated.set_frame_and_progress(1, 0.4)
		check(mouth.visible, "Opening the mouth updates immediately on the face frame signal")
		manager.update_player_animation(0.1, -1)
		check(is_equal_approx(sleeper.current_animation_position, 1.8), "Repeated presence updates do not restart sleep")
		check(manager.face_expression_animated.frame == 1 and is_equal_approx(manager.face_expression_animated.frame_progress, 0.4), "Mouth cycle is not restarted every frame")
		check(visual.scale.x < 0, "Sleep mirrors with facing")
		manager.face_expression_animated.set_frame_and_progress(2, 0.0)
		check(not mouth.visible, "Mouth closes again without moving the face")
		for state in ["walk", "jump", "fall", "punch", "place_animation", "hurt", "dead", "dead_spirit"]:
			manager.set_forced_animation_state(state)
			manager.update_player_animation(0.0, 1)
			check(manager.current_movement_animation != "sleep", state + " interrupts sleep")
			check(manager.get_face_expression_animation_name(state) != "sleep", state + " interrupts the sleeping face")
			check(not mouth.is_visible_in_tree(), state + " hides the sleeping mouth")
		manager.set_forced_animation_state("idle")
		manager.update_player_animation(0.0, 1)
		sleeper.advance(1.8)
		actor.set_meta("activity_bubble", "")
		manager.update_player_animation(0.0, 1)
		check(visual.get_node("Head").position == Vector2(1, 0) and visual.get_node("Body").position == Vector2.ZERO, "Waking restores neutral torso and head")
		check(not sleeper.is_playing() and manager.current_movement_animation == "idle", "Waking resumes normal idle")
		actor.set_meta("activity_bubble", "afk")
		world.typing = true
		manager.update_player_animation(0.0, 1)
		check(manager.current_movement_animation == "idle", "Typing wakes the actor even before presence refresh")
		world.typing = false
		manager.update_player_animation(0.0, 1)
		sleeper.advance(1.8)
		EMOTES.play(actor, "wave")
		manager.update_player_animation(0.0, 1)
		actor.get_node("PlayerEmotes")._process(0.25)
		EMOTES.cancel(actor)
		check(visual.get_node("Head").position == Vector2(1, 0) and visual.get_node("Body").position == Vector2.ZERO, "A gesture begun mid-breath restores the standing pose")
		EMOTES.play(actor, "dance")
		check(manager.get_face_expression_animation_name("idle") == "wave", "An intentional looping dance takes priority over AFK")
		EMOTES.cancel(actor)
		world.blocks[Vector2i.ZERO] = {"type": "water"}
		check(manager.get_face_expression_animation_name("idle") == "underwater", "Underwater face takes priority")
		world.blocks.clear()
		actor.set_meta("face_hurt_until_msec", Time.get_ticks_msec() + 1000)
		check(manager.get_face_expression_animation_name("idle") == "hurt", "Damage takes priority")
		actor.set_meta("face_hurt_until_msec", 0)
		actor.set_meta("remote_activity_bubble", "afk")
		actor.set_meta("remote_last_receive_msec", Time.get_ticks_msec())
		manager.update_player_animation(0.0, -1)
		check(manager.current_movement_animation == "sleep", "Remote AFK uses the same breathing animation")
		actor.set_meta("remote_last_receive_msec", Time.get_ticks_msec() - 16000)
		manager.update_player_animation(0.0, -1)
		check(manager.current_movement_animation == "idle", "Stale remote presence cannot leave sleep active")
		world.in_world = false
		check(manager.get_face_expression_animation_name("idle") != "sleep", "Leaving a world clears sleep")
		world.free()
		# This detached template never enters the tree, where netfox normally owns
		# its eagerly constructed visibility filter as a child.
		var synchronizer := source.get_node_or_null("RollbackSynchronizer")
		if synchronizer != null:
			var filter: Node = synchronizer.get("visibility_filter")
			if is_instance_valid(filter) and filter.get_parent() == null:
				filter.free()
		source.free()
	await process_frame
	if failures == 0: print("PLAYER_AFK_SLEEP: PASS (both rigs, fixed eyes, static body, mouth cycle, wake-up and remote presence)")
	quit(1 if failures else 0)
