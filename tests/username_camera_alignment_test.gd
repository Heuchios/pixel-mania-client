extends SceneTree
# Run with a renderer (for example --rendering-method gl_compatibility), not
# --headless: the regression observes the final frame_pre_draw camera transform.

const Alignment = preload("res://Scripts/camera_pixel_alignment.gd")
const UsernameManager = preload("res://Scripts/username_label_manager.gd")
var failures := 0

class Seeds extends RefCounted:
	func get_seed_hover_info_for_player(_grid, _position):
		return {"tree_name": "Test Tree", "status_text": "Growing"}

class World extends Node2D:
	var in_world := true
	var player := Node2D.new()
	var camera := Camera2D.new()
	var ui_layer := CanvasLayer.new()
	var seed_system := Seeds.new()
	var blocked := false
	func get_player_camera(): return camera
	func get_current_profile_name(): return "USO"
	func is_movement_blocking_ui_open(): return blocked

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(637, 359)
	viewport.size_2d_override = Vector2i(960, 540)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := World.new()
	viewport.add_child(world)
	world.add_child(world.player)
	world.add_child(world.ui_layer)
	world.player.add_child(world.camera)
	world.camera.make_current()
	# A physics camera plus a screen-space name also catches mismatched render ticks.
	world.camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	var manager = UsernameManager.new()
	world.add_child(manager)
	manager.setup(world)
	# Production can install camera alignment after username setup on world entry.
	Alignment.install(world.camera)
	Alignment.install(world.camera)
	var remote := Node2D.new()
	world.add_child(remote)
	var remote_label := Label.new()
	remote_label.size = Vector2(300, 34)
	remote.add_child(remote_label)
	var remote_manager = load("res://Scripts/player_manager.gd").new()
	world.add_child(remote_manager)
	remote_manager.set_process(false)
	remote_manager.world = world
	var worst_error := 0.0
	var remote_error := 0.0
	for zoom in [1.5, 3.0, 5.0]:
		# Resize while in-world, just as a mobile orientation/window change does.
		viewport.size = Vector2i(721, 405) if zoom == 3.0 else Vector2i(637, 359)
		world.camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE if zoom == 3.0 else Camera2D.CAMERA2D_PROCESS_PHYSICS
		Alignment.configure_zoom(world.camera, zoom, 1.5, 7.0)
		for frame in range(36):
			await process_frame
			# Rise, apex, fall, including a fractional physical-pixel camera position.
			var t := float(frame) / 35.0
			world.player.position = Vector2(100.173 + frame * 0.377, 310.037 - 120.0 * sin(t * PI))
			remote.position = world.player.position + Vector2(40.125, 0.0)
			remote_manager.update_remote_name_label_world_transform(remote_label, remote)
			await RenderingServer.frame_post_draw
			var canvas := viewport.canvas_transform
			var expected := canvas * (world.player.global_position + Vector2(0, -66))
			var actual: Vector2 = manager.label.position + Vector2(150, 34)
			worst_error = maxf(worst_error, actual.distance_to(expected))
			check(manager.growth_label.position.is_equal_approx(manager.label.position + Vector2(-30, -45)), "Growth text must stay attached to the username")
			var remote_actual: Vector2 = canvas * remote_label.global_position + Vector2(150, 34)
			var remote_expected := canvas * (remote.global_position + Vector2(0, -66))
			remote_error = maxf(remote_error, remote_actual.distance_to(remote_expected))
	check(worst_error < 0.01, "Local username drifted from rendered player: %.3f px" % worst_error)
	check(remote_error < 0.01, "Remote username drifted from rendered player: %.3f px" % remote_error)
	manager.set_process(false)
	manager.growth_label_alpha = 0.25
	world.camera.get_node(Alignment.NODE_NAME)._align_camera()
	check(is_equal_approx(manager.growth_label_alpha, 0.25), "Render positioning must not advance text fades twice")
	manager.set_process(true)
	# Re-entering a world must leave just one render callback.
	manager.setup(world)
	check(world.camera.get_node(Alignment.NODE_NAME).get_signal_connection_list("canvas_aligned").size() == 1, "Duplicate username render callback after setup")
	world.blocked = true
	await process_frame
	await RenderingServer.frame_post_draw
	check(not manager.label.visible, "Final camera update must not reveal a username behind UI")
	world.blocked = false
	world.in_world = false
	await process_frame
	await RenderingServer.frame_post_draw
	check(not manager.label.visible, "Username must stay hidden after world exit")
	viewport.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	print("[username-camera-alignment] local drift=%.3f remote drift=%.3f: %s" % [worst_error, remote_error, "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
