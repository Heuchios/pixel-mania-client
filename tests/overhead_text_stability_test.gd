extends SceneTree
# Run with a renderer; this regression compares the actual rendered glyphs.

const Alignment = preload("res://Scripts/camera_pixel_alignment.gd")
var failures := 0

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(721, 405)
	viewport.size_2d_override = Vector2i(960, 540)
	viewport.size_2d_override_stretch = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://tests/fixtures/overhead_text_world.gd").new()
	viewport.add_child(world)
	world.in_world = true
	world.player = Node2D.new()
	world.player.position = Vector2(128, 160)
	world.add_child(world.player)
	world.add_child(world.camera)
	world.camera.position = Vector2(128, 130)
	world.camera.make_current()
	world.ui_layer = CanvasLayer.new()
	world.add_child(world.ui_layer)
	var names = load("res://Scripts/username_label_manager.gd").new()
	world.add_child(names)
	names.setup(world)
	names.set_process(false)
	names.label.text = "USO"
	var blocks = load("res://Scripts/block_manager.gd").new()
	world.add_child(blocks)
	blocks.set_process(false)
	blocks.world = world
	world.item_database = {
		"tackle_box": {"tackle_box_block":true, "display_name":"Bait Box"},
		"colored_block_maker": {"tackle_box_block":true, "display_name":"Coloured Block Maker"}
	}
	var grid := Vector2i(4, 5)
	world.blocks[grid] = {"type":"tackle_box"}
	blocks.update_tackle_box_timer_hover()
	var remote := Node2D.new()
	remote.position = world.player.position
	world.add_child(remote)
	var remote_label := Label.new()
	remote_label.text = "PINE"
	remote_label.size = Vector2(300, 34)
	remote.add_child(remote_label)
	var players = load("res://Scripts/player_manager.gd").new()
	world.add_child(players)
	players.set_process(false)
	players.world = world
	players.remote_players["remote"] = remote
	players.remote_name_labels["remote"] = remote_label
	players.apply_remote_name_label_font(remote_label)
	remote_label.add_theme_font_size_override("font_size", 32)
	var worst_machine_drift := 0.0
	var changed_shapes := 0
	for size_pair in [[Vector2i(721,405), Vector2i(960,540), false], [Vector2i(637,359), Vector2i(521,294), false], [Vector2i(960,540), Vector2i(960,540), false], [Vector2i(721,405), Vector2i(960,540), true]]:
		viewport.size = size_pair[0]
		viewport.size_2d_override = size_pair[1]
		Alignment.configure_zoom(world.camera, 5.0 if viewport.size.x == 960 else 3.0, 1.5, 7.0)
		for kind in ["username", "remote", "tackle_box", "colored_block_maker"]:
			if size_pair[2]:
				Alignment.configure_zoom(world.camera, 3.0, 1.5, 7.0)
				Alignment.configure_zoom(world.camera, 4.0, 1.5, 7.0, true)
			var kind_changes := 0
			var first_shape := PackedByteArray()
			var first_size := Vector2i.ZERO
			for frame in range(20):
				await process_frame
				if size_pair[2]:
					world.camera.get_node(Alignment.NODE_NAME)._process(1.0 / 60.0)
				world.camera.position = Vector2(128.173 + frame * 0.113, 100.037 + frame * 0.071)
				# Exercise player ascent/descent as well as a slow camera pan.
				world.player.position = Vector2(128, 160)
				if kind in ["username", "remote"]:
					world.player.position += Vector2(frame * 0.037, sin(frame * 0.31) * 4.0)
				remote.position = world.player.position
				world.camera.force_update_scroll()
				world.blocks[grid].type = "tackle_box" if kind in ["username", "remote"] else kind
				names.update_position()
				blocks.update_tackle_box_timer_hover()
				players.update_remote_name_label_world_transform(remote_label, remote)
				names.label.visible = kind == "username"
				names.growth_label.visible = false
				remote_label.visible = kind == "remote"
				blocks.tackle_box_timer_label.visible = kind in ["tackle_box", "colored_block_maker"]
				await RenderingServer.frame_post_draw
				if blocks.tackle_box_timer_label.visible:
					var expected: Vector2 = viewport.canvas_transform * (Vector2(grid) * 32 + Vector2(0,-35)) - Vector2(130,17)
					worst_machine_drift = maxf(worst_machine_drift, blocks.tackle_box_timer_label.position.distance_to(expected))
				var picture := viewport.get_texture().get_image()
				var rect := picture.get_used_rect()
				check(rect.has_area(), "Missing rendered text: " + kind)
				var crop := picture.get_region(rect)
				if frame == 0:
					first_shape = crop.get_data()
					first_size = rect.size
				elif first_shape != crop.get_data() or first_size != rect.size:
					changed_shapes += 1
					kind_changes += 1
			print("OVERHEAD kind=%s width=%s zooming=%s changes=%s" % [kind, viewport.size.x, size_pair[2], kind_changes])
	check(worst_machine_drift < 0.01, "Machine text used an outdated camera transform: %.3f" % worst_machine_drift)
	check(changed_shapes == 0, "Text glyphs vibrated while scrolling: %s changed crops" % changed_shapes)
	var alignment: Node = world.camera.get_node(Alignment.NODE_NAME)
	check(alignment.get_signal_connection_list("canvas_aligned").size() == 3, "Expected one callback per text manager after repeated updates")
	world.in_world = false
	blocks.tackle_box_timer_label.visible = true
	alignment._align_camera()
	check(not blocks.tackle_box_timer_label.visible, "Render callback must hide machine text after world exit")
	names.free()
	blocks.free()
	players.free()
	check(alignment.get_signal_connection_list("canvas_aligned").is_empty(), "Text managers must disconnect their render callbacks on exit")
	viewport.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	print("OVERHEAD_TEXT_STABILITY: machine drift=%.3f, changed shapes=%s, failures=%s" % [worst_machine_drift, changed_shapes, failures])
	quit(1 if failures else 0)
