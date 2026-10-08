extends SceneTree

class TestNetwork extends Node:
	var sent: Array = []
	var developer := true
	func send_player_position(pos: Vector2, facing: int, world_name: String, _allow_join: bool = true, _bypass: bool = false) -> bool:
		sent.append({"position": pos, "facing": facing, "world": world_name})
		return true
	func is_developer_session() -> bool: return developer
	func is_admin_command_session() -> bool: return true

class TestWorld extends Node2D:
	var player = null
	var player_manager = null
	var save_manager = null
	var chat_ui = null
	var noclip_enabled := false
	var chat_typing_movement_locked := false
	var player_physics_enabled_before_noclip := true
	var current_world_name := "DEVTEST"
	var in_world := true
	var player_facing_direction := 1
	var movement_locked := false
	var player_health := 10
	var lava_damage_timer := 0.0
	var notices: Array[String] = []
	const NOCLIP_SPEED := 260.0
	func is_movement_locked() -> bool: return movement_locked
	func show_notification(value: String): notices.append(value)
	func update_all_ui(): pass
	func get_player_camera(): return null
	func set_player_collision_enabled(enabled: bool): player_manager.set_player_collision_enabled(enabled)
	func set_noclip_enabled(enabled: bool): player_manager.set_noclip_enabled(enabled)

class ManagerProbe extends "res://Scripts/player_manager.gd":
	func get_local_action_visual_key() -> String: return ""
	func refresh_local_respawn_animation_visuals(_state: String) -> void: pass
	func get_current_respawn_spawn_position() -> Vector2: return Vector2(128, 128)
	func get_current_entrance_gate_spawn_position() -> Vector2: return Vector2(64, 64)
	func flush_respawn_position_to_server() -> bool: return true

class RenderProbe extends "res://Scripts/player_manager.gd":
	var sampled_position := Vector2(80, 64)
	var collision_checks := 0
	func get_remote_buffered_render_position(_remote): return sampled_position
	func get_safe_remote_render_position(current: Vector2, _proposed: Vector2) -> Vector2:
		collision_checks += 1
		return current
	func get_visible_world_rect(_margin_screen_px: float = 0.0) -> Rect2: return Rect2(0, 0, 1000, 1000)
	func is_remote_player_visual_active(_remote, _rect: Rect2) -> bool: return false
	func update_remote_presentation_offset(_remote, _delta: float) -> void: pass

func _initialize():
	call_deferred("run")

func run():
	var original_network = root.get_node("NetworkManager")
	original_network.name = "OriginalNetworkManager"
	var network := TestNetwork.new()
	network.name = "NetworkManager"
	root.add_child(network)
	var world := TestWorld.new()
	root.add_child(world)
	var manager := ManagerProbe.new()
	world.add_child(manager)
	world.player_manager = manager
	manager.setup(world)
	var player = load("res://tests/fixtures/developer_player_probe.gd").new()
	player.set_physics_process(false)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	player.add_child(shape)
	world.add_child(player)
	world.player = player
	player.global_position = Vector2(200, 200)
	player.set_meta("multiplayer_movement_sync_from_physics", true)
	world.chat_typing_movement_locked = true
	manager.set_noclip_enabled(true)
	assert(shape.disabled and not player.is_physics_processing())
	assert(player.visible, "Noclip never hides the local character")
	manager.update_multiplayer_movement(0.1)
	assert(network.sent.size() == 1, "Noclip sends even after normal physics has claimed network sync")
	player.position.x += 20
	manager.update_multiplayer_movement(0.1)
	assert(network.sent.back().position == player.global_position, "Observer receives noclip movement")
	var before_heartbeats: int = network.sent.size()
	for frame in range(1800):
		manager.update_noclip_movement(1.0 / 60.0)
		manager.update_multiplayer_movement(1.0 / 60.0)
	assert(network.sent.size() > before_heartbeats + 5, "Idle noclip keeps heartbeats running beyond remote timeout")
	var hover_position: Vector2 = player.global_position
	for locked in [false, true]:
		world.movement_locked = locked
		player.set_physics_process(true)
		for frame in range(120):
			player.velocity = Vector2(100, 300)
			player.run_player_movement_step(1.0 / 60.0)
			assert(player.global_position == hover_position and player.velocity == Vector2.ZERO, "Resumed physics cannot produce slow falling")
		manager.update_noclip_movement(0.1)
		assert(not player.is_physics_processing())
	world.movement_locked = false
	Input.action_press("move_right")
	manager.update_noclip_movement(0.5)
	Input.action_release("move_right")
	assert(is_equal_approx(player.position.x, hover_position.x + 130.0))
	assert(is_equal_approx(player.position.y, hover_position.y))
	manager.apply_local_player_punch_knockback(Vector2(120, 200))
	assert(player.velocity == Vector2.ZERO and not player.is_physics_processing())
	manager.complete_respawn_player()
	assert(not player.is_physics_processing() and shape.disabled)
	manager.place_player_at_entrance_immediate()
	assert(not player.is_physics_processing() and shape.disabled)
	manager.set_noclip_enabled(false)
	assert(player.is_physics_processing() and not shape.disabled, "Disabling noclip restores physics even when enabled with chat focused")
	player.set_physics_process(false)
	network.sent.clear()
	manager.reset_multiplayer_sync_state()
	manager.update_multiplayer_movement(0.1)
	assert(network.sent.is_empty(), "Ordinary movement still uses physics-only network sampling")
	manager.update_multiplayer_movement(0.1, true)
	assert(network.sent.size() == 1)

	var commands = load("res://Scripts/command_manager.gd").new()
	world.add_child(commands)
	commands.setup(world)
	for command in ["/inv", "/vis"]:
		assert(commands.requires_server_delivery(command))
		assert(commands.build_developer_command_metadata(command).command_type == "visibility")
		commands.execute_verified_developer_command(command, command, "Visibility updated", {"invisible_enabled": command == "/inv"})
		assert(player.visible and player.modulate.a == 1.0, "Developer always sees their own character")
		assert(world.notices.back() == "Visibility updated")
		network.developer = false
		commands.handle_command(command)
		assert(world.notices.back() == "Visibility commands require developer access.", "Designer access alone is insufficient")
		network.developer = true

	var remote := Node2D.new()
	world.add_child(remote)
	manager.remote_players["REMOTE"] = remote
	var name_label := Label.new()
	world.add_child(name_label)
	manager.remote_name_labels["REMOTE"] = name_label
	var bubble := Label.new()
	world.add_child(bubble)
	manager.remote_chat_bubbles["REMOTE"] = bubble
	manager.remote_pending_position_snapshots["REMOTE"] = {"x": 5}
	manager.handle_network_player_left("REMOTE", false)
	assert(remote.is_queued_for_deletion(), "Invisibility removes the avatar without a fade")
	assert(name_label.is_queued_for_deletion() and bubble.is_queued_for_deletion(), "Invisibility removes name and chat visuals")
	assert(not manager.remote_players.has("REMOTE") and not manager.remote_pending_position_snapshots.has("REMOTE"))
	assert(player.visible, "Hiding a remote player never touches the local character")
	var renderer := RenderProbe.new()
	world.add_child(renderer)
	renderer.setup(world)
	var moving_remote := Node2D.new()
	world.add_child(moving_remote)
	renderer.remote_players["MOVING"] = moving_remote
	moving_remote.global_position = Vector2(40, 64)
	renderer.update_remote_visual_position(moving_remote, 0.1)
	assert(moving_remote.global_position == Vector2(40, 64) and renderer.collision_checks == 1, "Ordinary grounded avatars retain collision smoothing")
	moving_remote.set_meta("network_noclip_enabled", true)
	renderer.update_remote_visual_position(moving_remote, 0.1)
	assert(moving_remote.global_position == renderer.sampled_position and renderer.collision_checks == 1, "Noclip avatars render through walls")
	world.noclip_enabled = true
	renderer.sampled_position = Vector2(96, 64)
	renderer.update_remote_players_visuals(0.1)
	assert(moving_remote.global_position == renderer.sampled_position, "Other players keep moving while local physics is paused for noclip")
	world.free()
	network.free()
	original_network.name = "NetworkManager"
	print("DEVELOPER_MOVEMENT_VISIBILITY_TEST_OK: noclip movement, idle heartbeats, no gravity drift, UI lock, knockback/respawn, collision restore, commands and self visibility")
	quit()
