extends SceneTree

const FACES = preload("res://Assets/player/expressions/face_expressions.tres")
const SPIRIT = preload("res://Assets/player/expressions/dead_spirit.tres")
const MANAGER = preload("res://Scripts/player_animation_manager.gd")
var failures := 0

class WorldStub extends Node2D:
	var player: Node2D
	var blocks: Dictionary = {}
	var BLOCK_SIZE := 32
	var typing := false
	func is_chat_typing() -> bool: return typing

func _init() -> void:
	call_deferred("run")

func run() -> void:
	# Compare the atlas to the original hand-aligned sprites, including the blink
	# padding. This catches cropping mistakes and head movement under equipment.
	var legacy := {"idle": "idle", "blink": "idle_blink", "jump": "jump", "fall": "fall", "punch": "punch", "hurt": "hurt", "dead": "dead", "talk": "talk_1", "underwater": "underwater"}
	for animation in legacy:
		var texture: AtlasTexture = FACES.get_frame_texture(animation, 0)
		check(texture.atlas.resource_path == "res://Assets/player/expressions/emotes.png")
		check(texture.get_size() == Vector2(32, 32), animation + " changed the character canvas")
		var expected: Image = load("res://Assets/player/expressions/%s.png" % legacy[animation]).get_image()
		var actual := texture.get_image()
		# AtlasTexture.get_image() returns the source region, without its margin.
		assert_same_pixels(actual, expected.get_region(Rect2i(Vector2i.ZERO, actual.get_size())), animation)
	var talk_image := FACES.get_frame_texture("talk", 1).get_image()
	assert_same_pixels(talk_image, load("res://Assets/player/expressions/talk_2.png").get_image().get_region(Rect2i(Vector2i.ZERO, talk_image.get_size())), "talk frame 2")
	for i in range(3):
		var frame := SPIRIT.get_frame_texture("dead_spirit", i)
		check(frame.get_size() == Vector2(32, 32), "Spirit frames must not shift by half a pixel")
	check(FACES.get_frame_duration("idle", 1) / FACES.get_animation_speed("idle") < 0.2, "Blink must be brief")
	check(FACES.get_frame_duration("idle", 0) / FACES.get_animation_speed("idle") > 2.0, "Keep eyes open between blinks")
	# Verify both saved scenes use the shared resources without running a world.
	for scene_path in ["res://Scenes/main.tscn", "res://Scenes/player/netfox_player.tscn"]:
		var scene: PackedScene = load(scene_path)
		var state := scene.get_state()
		var found_face := false
		var found_spirit := false
		for n in state.get_node_count():
			for p in state.get_node_property_count(n):
				if state.get_node_property_name(n, p) != &"sprite_frames": continue
				if state.get_node_name(n) == &"FaceExpressionAnimated":
					check(state.get_node_property_value(n, p) == FACES)
					found_face = true
				if state.get_node_name(n) == &"DeadSpiritAnimated":
					check(state.get_node_property_value(n, p) == SPIRIT)
					found_spirit = true
		check(found_face and found_spirit, scene_path)

	var world := WorldStub.new()
	root.add_child(world)
	var player := Node2D.new()
	world.add_child(player)
	world.player = player
	var face := AnimatedSprite2D.new()
	face.sprite_frames = FACES
	player.add_child(face)
	var manager = MANAGER.new()
	player.add_child(manager)
	manager.world = world
	manager.player = player
	manager.face_expression_animated = face
	for state in ["idle", "jump", "fall", "punch", "hurt", "dead"]:
		manager.update_face_expression_animation(state)
		check(face.animation == state, "Wrong face for " + state)
	manager.update_face_expression_animation("idle")
	face.set_frame_and_progress(0, 0.5)
	manager.update_face_expression_animation("idle")
	check(is_equal_approx(face.frame_progress, 0.5), "Repeated updates must not restart blinking")
	world.typing = true
	check(manager.get_face_expression_animation_name("idle") == "idle", "Typing alone must not speak")
	var bubble = load("res://Scripts/chat_bubble_component.gd").new()
	root.add_child(bubble)
	player.set_meta("speech_bubble_ref", weakref(bubble))
	bubble.show_chat_message("Hello there!")
	world.typing = false
	check(manager.get_face_expression_animation_name("idle") == "talk", "Visible sent words must animate the mouth")
	check(manager.get_face_expression_animation_name("hurt") == "hurt", "Hurt must override talking")
	bubble.hide()
	check(manager.get_face_expression_animation_name("idle") == "idle", "Hidden messages must stop talking")
	bubble.show_notification_message("Casting with bait...")
	check(manager.get_face_expression_animation_name("idle") == "idle", "Notifications are not spoken chat")
	bubble.hide()
	world.blocks[Vector2i.ZERO] = {"type": "water"}
	check(manager.get_face_expression_animation_name("fall") == "underwater")
	world.blocks.clear()
	player.set_meta("remote_chat_typing", true)
	check(manager.get_face_expression_animation_name("idle") == "idle", "Remote typing alone must not speak")
	player.set_meta("remote_chat_typing", false)
	bubble.show_chat_message("A remote message")
	check(manager.get_face_expression_animation_name("idle") == "talk", "Remote sent chat must animate without typing")
	bubble.hide()
	player.set_meta("face_expression_override", " Angry ")
	manager.update_face_expression_animation("idle")
	check(face.animation == &"angry")
	check(manager.get_face_expression_animation_name("dead") == "dead")
	check(manager.get_face_expression_animation_name("dead_spirit") == "dead_spirit")
	# Exercise the alternate controller, rather than just checking its resources.
	# Load after autoloads exist; the controller references MovementMode.
	var netfox = load("res://tests/fixtures/face_expression_netfox_probe.gd").new()
	world.add_child(netfox)
	netfox.test_world = world
	world.player = netfox
	netfox.player_visual = Node2D.new()
	netfox.add_child(netfox.player_visual)
	netfox.face_expression_animated = AnimatedSprite2D.new()
	netfox.face_expression_animated.sprite_frames = FACES
	netfox.player_visual.add_child(netfox.face_expression_animated)
	netfox.dead_spirit_animated = AnimatedSprite2D.new()
	netfox.dead_spirit_animated.sprite_frames = SPIRIT
	netfox.add_child(netfox.dead_spirit_animated)
	netfox.is_punching = true
	netfox.update_face_expression()
	check(netfox.face_expression_animated.animation == &"punch", "Netfox punch face")
	netfox.movement_state = "hurt"
	netfox.update_face_expression()
	check(netfox.face_expression_animated.animation == &"hurt", "Netfox hurt overrides punch")
	netfox.is_punching = false
	netfox.movement_state = "idle"
	world.typing = true
	netfox.set_meta("speech_bubble_ref", weakref(bubble))
	bubble.show_chat_message("Hello from the alternate controller")
	netfox.update_face_expression()
	check(netfox.face_expression_animated.animation == &"talk", "Netfox chat face")
	world.typing = false
	bubble.free()
	netfox.update_face_expression()
	check(netfox.face_expression_animated.animation == &"idle", "Freed bubbles stop speaking safely")
	world.blocks[Vector2i.ZERO] = {"type": "water"}
	netfox.update_face_expression()
	check(netfox.face_expression_animated.animation == &"underwater", "Netfox swim face")
	world.blocks.clear()
	netfox.set_meta("face_expression_override", "dead_spirit")
	netfox.update_face_expression()
	check(not netfox.player_visual.visible and netfox.dead_spirit_animated.visible, "Netfox spirit replaces body")
	netfox.set_meta("face_expression_override", "")
	netfox.update_face_expression()
	check(netfox.player_visual.visible and not netfox.dead_spirit_animated.visible, "Netfox restores body after spirit")
	world.free()
	if failures == 0:
		print("[face-expression-atlas] PASS: aligned pixels, shared scenes, blink timing, movement, remote chat, water and state priority")
	quit(1 if failures > 0 else 0)

func assert_same_pixels(actual: Image, expected: Image, label: String) -> void:
	if actual.get_size() != expected.get_size():
		check(false, label + " image size")
		return
	for y in actual.get_height():
		for x in actual.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			check(is_equal_approx(a.a, b.a), "%s alpha at %d,%d" % [label, x, y])
			if b.a > 0.0:
				check(a.is_equal_approx(b), "%s color at %d,%d" % [label, x, y])

func check(condition: bool, message := "Expression assertion failed") -> void:
	if not condition:
		failures += 1
		push_error(message)
