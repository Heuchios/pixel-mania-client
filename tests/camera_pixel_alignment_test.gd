extends SceneTree

const Alignment = preload("res://Scripts/camera_pixel_alignment.gd")
var failures := 0

class BackgroundWorld extends Node:
	var in_world := true
	var player := Node2D.new()

class ZoomWorld extends Node:
	const CAMERA_ZOOM_MIN := 1.5
	const CAMERA_ZOOM_MAX := 7.0
	const CAMERA_ZOOM_DEFAULT := 3.0
	var current_camera_zoom := 3.0
	var camera: Camera2D
	var manager: Node
	func get_player_camera(): return camera
	func apply_camera_zoom(): manager.apply_camera_zoom()
	func show_notification(_text): pass

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(637, 330)
	viewport.size_2d_override = Vector2i(521, 270)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var texture_image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(256):
			texture_image.set_pixel(x, y, Color.WHITE if (x + y) % 3 == 0 else Color.BLACK)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(texture_image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sprite)
	var camera := Camera2D.new()
	camera.zoom = Vector2(3.0, 3.0)
	viewport.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	viewport.add_child(ui)
	var marker := ColorRect.new()
	marker.position = Vector2(5, 5)
	marker.size = Vector2(12, 12)
	marker.color = Color.MAGENTA
	ui.add_child(marker)
	await process_frame
	var baseline := await measure_shimmer(viewport, camera)
	check(baseline > 0, "Control must reproduce changing texel widths without alignment")
	Alignment.install(camera)
	Alignment.install(camera)
	check(camera.get_child_count() == 1, "Repeated world entry must not add duplicate alignment nodes")
	var corrected := await measure_shimmer(viewport, camera)
	check(corrected == 0, "Pixel pattern changed during aligned scrolling: %s" % corrected)
	print("[camera-alignment] fractional stretch: before=%s changed pixels; after=%s" % [baseline, corrected])
	# A resize and a fractional user zoom must retain the same stable sampling.
	viewport.size = Vector2i(721, 405)
	viewport.size_2d_override = Vector2i(640, 360)
	camera.zoom = Vector2(2.76, 2.76)
	await process_frame
	corrected = await measure_shimmer(viewport, camera)
	check(corrected == 0, "Pixel pattern changed after resize / zoom: %s" % corrected)
	viewport.size = Vector2i(2548, 1320)
	viewport.size_2d_override = Vector2i(2084, 1080)
	camera.zoom = Vector2(3.0, 3.0)
	await process_frame
	corrected = await measure_shimmer(viewport, camera)
	check(corrected == 0, "Pixel pattern changed at recording's native render size: %s" % corrected)
	# Camera limits and teleport positions still belong to Camera2D/physics.
	camera.limit_left = -50
	camera.limit_right = 50
	camera.position = Vector2(200.25, 0)
	await RenderingServer.frame_post_draw
	check(camera.position == Vector2(200.25, 0), "Alignment must not move the player/camera node")
	check(camera.zoom == Vector2(3.0, 3.0), "Alignment must not change user zoom")
	camera.enabled = false
	viewport.canvas_transform = Transform2D.IDENTITY
	await RenderingServer.frame_post_draw
	check(viewport.canvas_transform == Transform2D.IDENTITY, "Disabled camera must not alter another canvas")
	await check_background(viewport, sprite.texture)
	await process_frame
	await check_uniform_pixel_zoom(viewport, camera, sprite)
	viewport.queue_free()
	await process_frame
	print("[camera-alignment] %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func white_run_widths(picture: Image) -> Array:
	var widths := []
	var y := picture.get_height() / 2
	var start := picture.get_width() / 2 - 150
	var end := start + 300
	var run := 0
	var seen_black := false
	for x in range(start, end):
		if picture.get_pixel(x, y).r > 0.9:
			run += 1
		else:
			if seen_black and run > 0 and not widths.has(run):
				widths.append(run)
			seen_black = true
			run = 0
	widths.sort()
	return widths

func check_uniform_pixel_zoom(viewport: SubViewport, camera: Camera2D, sprite: Sprite2D) -> void:
	var stripes := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(256): stripes.set_pixel(x, y, Color.WHITE if x % 2 == 0 else Color.BLACK)
	sprite.texture = ImageTexture.create_from_image(stripes)
	camera.enabled = true
	camera.limit_left = -100000
	camera.limit_right = 100000
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(3,3)
	await process_frame
	await RenderingServer.frame_post_draw
	var uneven := white_run_widths(viewport.get_texture().get_image())
	check(uneven.size() > 1, "Control must reproduce unequal artwork pixel widths at live window size")
	var world := ZoomWorld.new()
	world.camera = camera
	world.manager = load("res://Scripts/player_manager.gd").new()
	world.manager.world = world
	root.add_child(world)
	world.add_child(world.manager)
	world.apply_camera_zoom()
	await RenderingServer.frame_post_draw
	var uniform := white_run_widths(viewport.get_texture().get_image())
	check(uniform == [4], "Expected uniform 4-screen-pixel texels; got %s" % [uniform])
	print("[camera-alignment] live-size texel widths: before=%s after=%s" % [uneven, uniform])
	var old_zoom := camera.zoom.y
	world.manager.zoom_camera(0.12)
	check(Alignment.target_zoom(camera).y > old_zoom, "One wheel click must request a visible zoom step")
	check(is_equal_approx(camera.zoom.y, old_zoom), "Wheel zoom must ease from the current view")
	world.manager.zoom_camera(-0.12)
	check(is_equal_approx(Alignment.target_zoom(camera).y, old_zoom), "Opposite wheel clicks must return to the same zoom destination")
	world.manager.set_default_camera_zoom_silent()
	for pair in [[Vector2i(1920,1080), Vector2i(1920,1080)], [Vector2i(1280,720), Vector2i(1920,1080)], [Vector2i(1601,901), Vector2i(1920,1080)]]:
		viewport.size = pair[0]
		viewport.size_2d_override = pair[1]
		await process_frame
		await RenderingServer.frame_post_draw
		var scale := (viewport.get_stretch_transform() * viewport.canvas_transform).get_scale()
		check(scale.is_equal_approx(scale.round()), "Resize must retain whole-pixel scale: %s" % scale)
		check(is_equal_approx(scale.x, scale.y), "Resize must preserve square artwork pixels")
		check(white_run_widths(viewport.get_texture().get_image()).size() == 1, "Resizing produced uneven texel widths")
		check(await measure_shimmer(viewport, camera) == 0, "Pixel pattern changed with whole-pixel zoom")
	# Both ends of the zoom range remain reachable and repeated clicks stay bounded.
	for direction in [1.0, -1.0]:
		for i in range(15): world.manager.zoom_camera(direction * 0.12)
		for i in range(120): camera.get_node(Alignment.NODE_NAME)._process(1.0 / 60.0)
		check(camera.zoom.y >= world.CAMERA_ZOOM_MIN and camera.zoom.y <= world.CAMERA_ZOOM_MAX, "Zoom escaped bounds")
	world.queue_free()

func measure_shimmer(viewport: SubViewport, camera: Camera2D) -> int:
	var first_image: Image
	var first_origin := Vector2i.ZERO
	var changed := 0
	for frame in range(24):
		var target := Vector2(frame * 0.073, frame * 0.037)
		camera.position = target
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := viewport.get_texture().get_image()
		var origin := Vector2i((viewport.get_stretch_transform() * viewport.canvas_transform).origin.round())
		check(camera.position == target, "Render alignment changed movement coordinates")
		check(picture.get_pixel(10, 10).is_equal_approx(Color.MAGENTA), "Camera alignment moved CanvasLayer UI")
		if frame == 0:
			first_image = picture
			first_origin = origin
			continue
		var shift := origin - first_origin
		var center := viewport.size / 2
		for y in range(center.y - 15, center.y + 15):
			for x in range(center.x - 100, center.x + 100):
				if picture.get_pixel(x + shift.x, y + shift.y) != first_image.get_pixel(x, y):
					changed += 1
	return changed

func check_background(viewport: SubViewport, texture: Texture2D) -> void:
	var background_script = load("res://Scripts/background_manager.gd")
	var manager = background_script.new()
	var world := BackgroundWorld.new()
	root.add_child(world)
	world.add_child(world.player)
	manager.world = world
	# Exercise the actual production drawing function, without theme/network setup.
	var layer := CanvasLayer.new()
	layer.layer = 10
	viewport.add_child(layer)
	var drawer = background_script.BackgroundDrawer.new()
	drawer.manager = manager
	drawer.layer_textures = [texture]
	drawer.layer_speeds = [0.34]
	drawer.layer_drifts = [0.0]
	drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(drawer)
	var first_image: Image
	var changed := 0
	var stretch := viewport.get_stretch_transform().get_scale().x
	for frame in range(24):
		world.player.position.x = frame * 0.173
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := viewport.get_texture().get_image()
		if frame == 0:
			first_image = picture
			continue
		var shift := roundi(-world.player.position.x * 0.34 * stretch)
		for y in range(120, 150):
			for x in range(180, 380):
				if picture.get_pixel(x + shift, y) != first_image.get_pixel(x, y):
					changed += 1
	check(changed == 0, "Parallax texture changed while scrolling: %s" % changed)
	print("[camera-alignment] parallax: %s changed pixels" % changed)
	manager.free()
	world.queue_free()
	layer.queue_free()
