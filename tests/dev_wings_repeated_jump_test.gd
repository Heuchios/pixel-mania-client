extends SceneTree

const Equipment = preload("res://Scripts/equipment_manager.gd")
const DB = preload("res://Scripts/item_database.gd")

class WorldFixture extends Node:
	const BACK_ITEM_JUMP_VELOCITY := -430.0
	var item_database: Dictionary = DB.ITEMS
	var back_textures: Dictionary = {}
	var equipment_manager: Node
	var player: CharacterBody2D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := WorldFixture.new()
	var manager := Equipment.new()
	# Load after autoloads exist: the real player uses MovementMode.
	var player = load("res://tests/dev_wings_jumping_player_fixture.gd").new()
	var wings := AnimatedSprite2D.new()
	world.equipment_manager = manager
	world.player = player
	player.fixture_world = world
	manager.world = world
	manager.player = player
	manager.equipped_back_item = "legendary_wings"
	manager.load_back_item_visual_data("legendary_wings")
	wings.sprite_frames = manager.build_back_item_sprite_frames()
	manager.wearable_part_nodes["back"] = wings
	root.add_child(wings)
	manager.update_back_item_animation(0.0)
	assert(wings.animation == "jump")
	# Extra jumps while still rising must restart even though the state is unchanged.
	for frame in [1, 3, 5]:
		wings.set_frame_and_progress(frame, 0.7)
		assert(player.try_jump())
		assert(wings.frame == 0 and is_zero_approx(wings.frame_progress), "An accepted air jump must restart the flap")
		assert(wings.is_playing())
		manager.update_back_item_animation(0.016)
		assert(wings.frame == 0)
	# A rejected jump and ordinary updates must leave the current flap alone.
	wings.set_frame_and_progress(3, 0.4)
	player.allowed_air_jumps = 0
	assert(not player.try_jump())
	manager.update_back_item_animation(0.016)
	assert(wings.frame == 3 and is_equal_approx(wings.frame_progress, 0.4))
	player.velocity.y = 100.0
	manager.update_back_item_animation(0.016)
	assert(wings.frame == 3, "The apex must not restart the same flap sequence")
	# Let a complete flap finish, then jump again without landing.
	player.allowed_air_jumps = -1
	assert(player.try_jump())
	var visited: Array[int] = [0]
	wings.frame_changed.connect(func(): visited.append(wings.frame))
	create_timer(5.0).timeout.connect(func():
		printerr("DEV_WINGS_REPEAT timeout")
		quit(1))
	await wings.animation_finished
	assert(visited == [0, 1, 2, 3, 4, 5, 6], "A flap must play every frame in order")
	manager.update_back_item_animation(0.016)
	assert(wings.frame == 6 and not wings.is_playing())
	assert(player.try_jump())
	assert(wings.frame == 0 and is_zero_approx(wings.frame_progress) and wings.is_playing(), "A completed flap must restart on the next air jump")
	var player_manager = load("res://Scripts/player_manager.gd").new()
	player_manager.world = world
	player_manager.MovementMode = root.get_node("MovementMode")
	wings.set_frame_and_progress(4, 0.8)
	player_manager.perform_back_item_air_jump()
	assert(wings.frame == 0 and is_zero_approx(wings.frame_progress), "The alternate air-jump path must also restart")
	player_manager.free()
	# The sprite emitted animation_finished; wait until it has finished emitting.
	await process_frame
	wings.free()
	player.free()
	manager.free()
	world.free()
	print("DEV_WINGS_REPEAT_OK: rapid air jumps, full flap, subsequent jump, rejected input and apex")
	quit()
