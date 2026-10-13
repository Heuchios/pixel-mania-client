extends SceneTree

const Names = preload("res://Scripts/username_label_manager.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func green_pixels(frame: Image) -> int:
	var count := 0
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			var color := frame.get_pixel(x, y)
			if color.g > 0.5 and color.g > color.r * 2 and color.g > color.b * 2:
				count += 1
	return count


func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://tests/fixtures/overhead_text_world.gd").new()
	viewport.add_child(world)
	world.in_world = true
	world.camera.enabled = false
	world.add_child(world.camera)
	world.player = Node2D.new()
	world.add_child(world.player)
	world.ui_layer = CanvasLayer.new()
	world.add_child(world.ui_layer)
	# Preserve an existing overhead control when setup is repeated.
	var legacy := Control.new()
	legacy.name = "OverheadLayer"
	world.ui_layer.add_child(legacy)
	world.setup_ui_layers()
	check(world.ui_overhead_layer == legacy, "Existing overhead controls must survive canvas migration")
	var names = Names.new()
	world.add_child(names)
	names.setup(world)
	names.set_process(false)
	names.label.text = "USO"
	names.label.position = Vector2(40, 40)
	names.label.add_theme_color_override("font_color", Color.GREEN)
	names.label.show()
	var remote := Label.new()
	remote.text = "PINE"
	remote.position = Vector2(40, 120)
	remote.size = Vector2(300, 34)
	remote.z_as_relative = false
	remote.z_index = 3899
	names.apply_username_font_to_label(remote)
	remote.add_theme_color_override("font_color", Color.GREEN)
	remote.add_theme_font_size_override("font_size", 32)
	world.add_child(remote)
	# Even an avatar at the top of the world z range stays behind overhead text.
	var avatar := ColorRect.new()
	avatar.size = Vector2(512, 256)
	avatar.color = Color("202040")
	avatar.z_index = 4095
	world.add_child(avatar)
	var visible := await capture(viewport)
	check(green_pixels(visible) > 100, "Local overhead name must remain visible above the world")
	avatar.hide()
	visible = await capture(viewport)
	check(green_pixels(visible) > 200, "Both local and remote names must render before occlusion")
	# Cover the canvas z range, including the hotbar (-32) and modal panels.
	for z in [-4095, -32, 0, 175, 240]:
		var panel := ColorRect.new()
		panel.size = Vector2(512, 256)
		panel.color = Color("50305c")
		panel.z_index = z
		world.get_ui_hud_layer().add_child(panel)
		var covered := await capture(viewport)
		check(green_pixels(covered) == 0, "UI at z=%s must cover all username pixels" % z)
		panel.free()
	# Speech background uses the production chat-bubble layer (72).
	var text_box := ColorRect.new()
	text_box.size = Vector2(512, 256)
	text_box.color = Color("eee1ef")
	text_box.z_index = 72
	world.get_ui_overhead_layer().add_child(text_box)
	var speech := await capture(viewport)
	check(green_pixels(speech) == 0, "Speech-box backgrounds must cover local and remote usernames")
	text_box.free()
	var parent_before: Node = names.label.get_parent()
	for repeat in range(3):
		world.setup_ui_layers()
	check(names.label.get_parent() == parent_before, "Repeated setup must keep live name labels")
	check(world.ui_layer.get_node("OverheadCanvasLayer").get_child_count() == 1, "Only one overhead root may exist")
	visible = await capture(viewport)
	check(green_pixels(visible) > 200, "Names must reappear after panels close")
	# A project with a different UI canvas order gets the same relative ordering.
	world.ui_layer.layer = 4
	world.setup_ui_layers()
	check(world.ui_layer.get_node("OverheadCanvasLayer").layer == 3, "Overhead canvas follows the configured UI canvas")
	names.free()
	viewport.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	print("USERNAME_UI_OCCLUSION_PASS: local/remote names, hotbar, panels, speech backgrounds and repeated setup; failures=", failures)
	quit(1 if failures else 0)
