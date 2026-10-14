extends SceneTree

const Equipment = preload("res://Scripts/equipment_manager.gd")
const AnimationManager = preload("res://Scripts/player_animation_manager.gd")
const PlayerManager = preload("res://Scripts/player_manager.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func rig_from(source: Node, parent: Node) -> Node2D:
	var actor := Node2D.new()
	parent.add_child(actor)
	for name in ["PlayerVisual", "Sprite2D", "DeadSpiritAnimated", "AnimationPlayer", "Jump", "idle"]:
		var part := source.get_node_or_null("Player/" + name)
		if part != null:
			actor.add_child(part.duplicate())
	return actor


func equipment_for(world: Node, actor: Node2D):
	var equipment := Equipment.new()
	actor.add_child(equipment)
	equipment.setup(world, actor, false)
	equipment.set_process(false)
	equipment.set_forced_animation_state("idle")
	return equipment


func face_state(actor: Node2D, manager, activity: String) -> void:
	actor.set_meta("remote_activity_bubble", activity)
	actor.set_meta("remote_last_receive_msec", Time.get_ticks_msec())
	actor.set_meta("animation_state", "idle")
	manager.update_remote_shared_player_animation(actor, 0.0)


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://tests/void_trident_world_fixture.gd").new()
	viewport.add_child(world)
	world.in_world = true
	world.current_world_name = "TEST"
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	# Real artwork with different offsets exercises current and future item definitions.
	for id in ["observer_shirt", "remote_shirt"]:
		world.item_database[id] = world.item_database.basic_white_shirt.duplicate(true)
	world.item_database.observer_shirt.shirt_offset = [3, -2]
	world.item_database.remote_shirt.shirt_offset = [-2, 3]
	var source = load("res://Scenes/main.tscn").instantiate()
	var observer := rig_from(source, world)
	observer.position = Vector2(100, 140)
	observer.scale = Vector2.ONE * 3
	world.player = observer
	var observer_equipment = equipment_for(world, observer)
	world.equipment_manager = observer_equipment
	observer_equipment.update_equipped_shirt_visual("observer_shirt", -1)
	observer_equipment.update_equipped_back_visual("dracula_cape", -1)
	var observer_animation := AnimationManager.new()
	observer.add_child(observer_animation)
	observer_animation.setup(world, observer)
	observer_animation.set_forced_animation_state("idle")
	observer.set_meta("activity_bubble", "afk")
	observer_animation.update_player_animation(0.0, -1)
	observer_animation.face_expression_animated.set_frame_and_progress(1, 0.0)
	observer_animation.face_expression_animated.pause()
	# Copied callbacks and temporary held-block visuals must not enter another rig.
	var held := Sprite2D.new()
	held.name = "SelectedPlaceablePreview"
	observer.get_node("PlayerVisual/HandItem").add_child(held)
	held.show()
	var manager := PlayerManager.new()
	world.add_child(manager)
	manager.world = world
	manager.MovementMode = root.get_node("MovementMode")
	manager.set_process(false)
	world.player_manager = manager
	var reference := rig_from(source, world)
	reference.position = Vector2(500, 140)
	reference.scale = Vector2.ONE * 3
	var reference_equipment = equipment_for(world, reference)
	reference_equipment.update_equipped_shirt_visual("remote_shirt", 1)
	var cape_ids := ["black_hero_cape", "red_hero_cape", "blue_hero_cape", "vampire_cape", "dracula_cape"]
	for id in cape_ids:
		for facing in [1, -1]:
			var remote := Node2D.new()
			remote.position = Vector2(300, 140)
			remote.scale = Vector2.ONE * 3
			remote.set_meta("remote_id", id)
			remote.set_meta("facing", facing)
			remote.set_meta("animation_state", "idle")
			remote.set_meta("equipment_slots", {"back": id, "shirt": "remote_shirt"})
			remote.set_meta("equipment_slots_debug_key", id)
			world.add_child(remote)
			manager.remote_players[id] = remote
			check(manager.ensure_remote_player_shared_visual_pipeline(remote), "Create remote rig")
			manager.update_remote_shared_equipment_visuals(remote)
			var equipment = manager.get_remote_equipment_manager(remote)
			var animation = manager.get_remote_animation_manager(remote)
			check(remote.get_node_or_null("PlayerVisual/HandItem/SelectedPlaceablePreview") == null, "Remote must not inherit the observer's held item")
			check(equipment.shirt_item_animated.position == reference_equipment.shirt_item_animated.position, "Remote shirt offset must be applied once, independent of observer equipment")
			reference_equipment.update_equipped_back_visual(id, facing)
			check(equipment.back_sprite.position == reference_equipment.back_sprite.position, "Remote cape uses authored anchor for " + id)
			check(equipment.get_wearable_part("cape_neck").position == reference_equipment.get_wearable_part("cape_neck").position, "Remote collar uses authored anchor for " + id)
			face_state(remote, manager, "afk")
			check(animation.current_movement_animation == "sleep" and animation.face_expression_animated.animation == &"sleep", "Remote AFK shows the sleeping face")
			var face: AnimatedSprite2D = animation.face_expression_animated
			for connection in face.get_signal_connection_list("frame_changed"):
				check(connection.callable.get_object() != observer_animation, "Remote face signal must not target the observer's manager")
			face.set_frame_and_progress(0, 0.0)
			check(not face.get_node("SleepMouth").visible, "Remote mouth closes independently")
			face.set_frame_and_progress(1, 0.0)
			check(face.get_node("SleepMouth").visible, "Remote mouth opens independently")
			check(observer_animation.face_expression_animated.frame == 1, "Remote sleep must not change the observer's face")
			var sleeper: AnimationPlayer = remote.get_node("SleepAnimationPlayer")
			sleeper.seek(1.8, true)
			manager.update_remote_shared_player_animation(remote, 0.0)
			check(is_equal_approx(sleeper.current_animation_position, 1.8), "Repeated AFK snapshots do not restart sleep")
			face_state(remote, manager, "")
			check(animation.current_movement_animation == "idle" and not face.get_node("SleepMouth").visible, "Wake hides sleep mouth")
			for state in ["idle", "walk", "jump", "fall"]:
				remote.set_meta("animation_state", state)
				remote.set_meta("network_on_floor", state in ["idle", "walk"])
				remote.set_meta("network_velocity_y", 120.0 if state == "fall" else -120.0)
				manager.update_remote_shared_player_animation(remote, 0.0)
				check(equipment.back_sprite.animation == state, "Remote cape pose follows " + state)
			check(equipment.back_sprite.sprite_frames.get_frame_count("idle") == 4, "All cape idle frames reach remote rigs")
			check(equipment.back_sprite.sprite_frames.get_animation_speed("idle") == 3.0, "Remote cape preserves the idle animation speed")
			if id in ["vampire_cape", "dracula_cape"]:
				var effect = equipment.back_item_fx
				check(is_instance_valid(effect) and effect.wings == equipment.back_sprite, "Bats bind to the remote cape")
				check(effect != observer_equipment.back_item_fx, "Remote cape effect belongs to the remote actor")
				effect.clear()
				equipment.restart_back_item_jump_animation()
				check(effect.particles.size() == effect.BURST_COUNT, "An accepted remote jump releases its own bat swarm")
			remote.set_meta("animation_state", "idle")
			manager.update_remote_shared_player_animation(remote, 0.0)
			var first_frame: int = equipment.back_sprite.frame
			await create_timer(0.4).timeout
			check(equipment.back_sprite.frame != first_frame, "Remote cape animation advances between network updates")
			if "--render" in OS.get_cmdline_user_args() and id == "dracula_cape" and facing == 1:
				face_state(remote, manager, "afk")
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				if image.get_format() in [Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGBF, Image.FORMAT_RGBAF]:
					image.convert(Image.FORMAT_RGBA8)
					image.linear_to_srgb()
				image.save_png("user://remote-presence.png")
			manager.remote_players.erase(id)
			remote.free()
	# Drive the actual network receiver, including late-join AFK and jump dedupe.
	var packet := {"player_id": "network-actor", "username": "RemoteActor", "world": "TEST", "x": 300.0, "y": 140.0, "facing": 1, "on_floor": true, "animation_state": "idle", "activity_bubble": "afk", "equipment_slots": {"back": "vampire_cape"}, "jump_visual_sequence": 0, "movement_sequence": 1, "server_time_msec": Time.get_ticks_msec()}
	manager.handle_network_player_position(packet)
	var received = manager.remote_players.get("network-actor")
	check(is_instance_valid(received), "Late join creates the remote actor from a real presence packet")
	if is_instance_valid(received):
		var received_animation = manager.get_remote_animation_manager(received)
		var received_equipment = manager.get_remote_equipment_manager(received)
		check(received_animation.current_movement_animation == "sleep", "Late-joining observer sees AFK without waiting for a change")
		packet.merge({"on_floor": false, "animation_state": "jump", "velocity_y": -200.0, "activity_bubble": "", "jump_visual_sequence": 1, "movement_sequence": 2, "server_time_msec": int(packet.server_time_msec) + 100}, true)
		manager.handle_network_player_position(packet)
		check(received_animation.current_movement_animation == "jump", "Movement wakes a remote AFK actor")
		var effect = received_equipment.back_item_fx
		check(effect.particles.size() == effect.BURST_COUNT, "Network jump sequence emits the remote cape effect")
		var count: int = effect.particles.size()
		packet.merge({"movement_sequence": 3, "server_time_msec": int(packet.server_time_msec) + 100}, true)
		manager.handle_network_player_position(packet)
		check(effect.particles.size() == count, "Repeated jump sequence does not duplicate effects")
	world.free()
	source.free()
	viewport.queue_free()
	await process_frame
	print("REMOTE_PRESENCE_VISUALS_PASS: ", checks, " checks, ", failures, " failures; AFK, cape poses/effects, independent item anchors and observer state")
	quit(1 if failures else 0)
