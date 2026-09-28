extends SceneTree

var failures := 0

class FakeNetwork extends Node:
	var sent: Array = []
	func send_world_interaction_update(payload: Dictionary, _world: String):
		sent.append(payload.duplicate(true))

class FakeWorld extends Node:
	var current_world_name := "TEST"
	var applying_network_world_update := false
	var save_manager = null
	var input_manager = null
	var item_database := {"test_sword": {"punch_animation": "sword"}}

class AnimationProbe extends Node:
	var forced := ""
	func set_forced_animation_state(value: String): forced = value
	func update_player_animation(_delta: float, _facing: int): pass

class EquipmentProbe extends Node:
	var forced := ""
	var forced_back_animation_state := ""
	func set_forced_animation_state(value: String): forced = value
	func update_wearable_animation_state(_delta: float): pass
	func update_back_item_animation(_delta: float): pass

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	if not value:
		printerr(message)
		failures += 1

func run():
	# Parse the actual edited entry points after autoloads have initialized.
	for file in ["world.gd", "world_loading_ui_manager.gd", "shop_ui.gd", "chat_ui.gd", "save_manager.gd", "world_menu_ui.gd", "network_manager.gd", "world_state_sync_manager.gd", "player.gd"]:
		var script = load("res://Scripts/" + file)
		check(script != null and script.can_instantiate(), "Script must compile: " + file)
	var world := FakeWorld.new()
	root.add_child(world)
	var original_network := root.get_node("NetworkManager")
	original_network.name = "OriginalNetworkManager"
	var network := FakeNetwork.new()
	network.name = "NetworkManager"
	root.add_child(network)
	var locks = load("res://tests/fixtures/area_lock_settings_fixture.gd").new()
	locks.world = world
	locks.area_locks = [
		{"lock_id":"mine", "lock_type":"big_lock", "owner_name":"owner", "lock_grid_x":5, "lock_grid_y":5},
		{"lock_id":"theirs", "lock_type":"small_lock", "owner_name":"other", "lock_grid_x":30, "lock_grid_y":5}
	]
	check(locks.set_area_lock_public_build("mine", true), "Owner can make own lock public")
	check(network.sent.size() == 1 and network.sent[0].state.area_locks.size() == 1, "Only the edited lock is sent")
	check(network.sent[0].state.area_locks[0].public_build, "Public setting reaches server payload")
	check(locks.add_area_lock_access_name("mine", "friend", "builder", true), "Owner can add a builder")
	check(network.sent.back().state.area_locks[0].allowed_players.has("FRIEND"), "Member reaches server payload")
	check(not locks.set_area_lock_public_build("theirs", true), "Other owner's lock remains protected")
	check(locks.remove_area_lock_access_name("mine", "friend"), "Owner can remove builder")
	check(network.sent.back().state.area_locks[0].allowed_players.is_empty(), "Removal reaches server")
	locks.is_locked = true
	locks.test_username = "VISITOR"
	check(locks.can_current_player_build_at(Vector2i(5, 6)), "Public area is usable inside a private world")
	check(not locks.can_current_player_build_at(Vector2i(95, 65)), "Area grant cannot unlock the rest of the world")
	locks.free()
	network.free()
	original_network.name = "NetworkManager"

	var manager = load("res://Scripts/player_manager.gd").new()
	manager.world = world
	var remote := Node.new()
	var animator := AnimationProbe.new()
	animator.name = "RemoteAnimationManager"
	remote.add_child(animator)
	var equipment := EquipmentProbe.new()
	equipment.name = "RemoteEquipmentManager"
	remote.add_child(equipment)
	for key in ["jump_visual_sequence", "punch_visual_sequence"]:
		check(not manager.consume_remote_action_sequence(remote, {key:7}, key, false), "Join snapshot does not replay historical actions")
		check(manager.consume_remote_action_sequence(remote, {key:8}, key, true), "Repeated action gets a new animation")
		check(not manager.consume_remote_action_sequence(remote, {key:8}, key, true), "Duplicate snapshot does not restart animation")
		check(not manager.consume_remote_action_sequence(remote, {}, key, true), "Old clients remain compatible")
	remote.set_meta("animation_state", "punch")
	remote.set_meta("equipment_slots", {"hand":"test_sword"})
	remote.set_meta("network_on_floor", false)
	remote.set_meta("network_velocity_y", -300.0)
	remote.set_meta("remote_action_animation_until_msec", Time.get_ticks_msec() + 500)
	manager.update_remote_shared_player_animation(remote, 0.0)
	check(animator.forced == "punch" and equipment.forced == "punch" and equipment.forced_back_animation_state == "jump", "Wings follow jumping while clothing and body play weapon swings")
	check(remote.get_meta("punch_animation_name") == "sword", "Remote weapon selects its own animation")
	remote.set_meta("remote_action_animation_until_msec", 0)
	manager.update_remote_shared_player_animation(remote, 0.0)
	check(animator.forced == "jump", "Expired swings return to locomotion without another packet")
	remote.free()
	manager.free()

	var animation_manager = load("res://Scripts/player_animation_manager.gd").new()
	var animation_player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var swing := Animation.new()
	swing.length = 1.0
	library.add_animation("sword", swing)
	animation_player.add_animation_library("", library)
	root.add_child(animation_player)
	animation_manager.current_movement_animation_player = animation_player
	animation_manager.current_movement_animation = "sword"
	animation_player.play("sword")
	animation_player.seek(0.7)
	animation_manager.restart_current_action_animation()
	check(is_zero_approx(animation_player.current_animation_position), "Consecutive weapon swings restart at the beginning")
	animation_manager.free()
	animation_player.free()
	var wing_manager = load("res://Scripts/equipment_manager.gd").new()
	wing_manager.equipped_back_item = "dev_wings"
	wing_manager.back_item_data = {"flap_animation":true}
	wing_manager.set_forced_animation_state("punch")
	wing_manager.forced_back_animation_state = "jump"
	check(wing_manager.get_current_wearable_animation_name() == "punch" and wing_manager.get_current_back_item_animation_name() == "jump", "Back and clothing states stay independent")
	var wing := AnimatedSprite2D.new()
	wing.sprite_frames = SpriteFrames.new()
	wing.sprite_frames.add_animation("jump")
	for i in range(4): wing.sprite_frames.add_frame("jump", PlaceholderTexture2D.new())
	wing_manager.wearable_part_nodes = {"back":wing}
	wing.play("jump")
	wing.frame = 3
	wing_manager.restart_back_item_jump_animation()
	check(wing.frame == 0 and wing.is_playing(), "A repeated wing jump restarts the actual wing animation")
	wing_manager.free()
	wing.free()

	var guard = load("res://Scripts/world_transition_ui_guard.gd")
	check(not guard.is_blocked(world), "Normal HUD input is allowed")
	guard.begin(world)
	check(guard.is_blocked(world), "HUD input is blocked during joins and warps")
	var shop = load("res://Scripts/shop_ui.gd").new()
	shop.world = world
	shop.shop_panel = Control.new()
	shop.shop_panel.visible = false
	shop.open_shop()
	check(not shop.shop_panel.visible, "Shop cannot open during world transition")
	guard.finish(world)
	check(guard.is_blocked(world), "Completion event cannot leak into the new HUD")
	world.set_meta("world_transition_ui_resume_msec", Time.get_ticks_msec() - 1)
	check(not guard.is_blocked(world), "Fresh HUD input resumes after transition")
	shop.shop_panel.free()
	shop.free()
	world.free()
	if failures == 0: print("MULTIPLAYER_INTERACTION_REGRESSIONS_OK")
	quit(0 if failures == 0 else 1)
