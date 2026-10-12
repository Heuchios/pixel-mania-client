extends SceneTree

const Alignment = preload("res://Scripts/camera_pixel_alignment.gd")
var failures := 0

class ZoomWorld extends Node:
	const CAMERA_ZOOM_MIN := 1.5
	const CAMERA_ZOOM_MAX := 7.0
	const CAMERA_ZOOM_DEFAULT := 3.0
	var in_world := true
	var allowed := true
	var current_camera_zoom := CAMERA_ZOOM_DEFAULT
	var camera: Camera2D
	var manager: Node
	func get_player_camera(): return camera
	func can_use_camera_zoom(): return allowed
	func apply_camera_zoom(): manager.apply_camera_zoom()
	func zoom_camera(amount: float, feedback: bool = true): manager.zoom_camera(amount, feedback)
	func show_notification(_message): pass

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func advance(camera: Camera2D, delta: float, frames: int) -> void:
	var alignment: Node = camera.get_node(Alignment.NODE_NAME)
	alignment.set_process(false)
	for frame in range(frames):
		alignment._process(delta)

func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(721, 405)
	viewport.size_2d_override = Vector2i(960, 540)
	viewport.size_2d_override_stretch = true
	root.add_child(viewport)
	var world := ZoomWorld.new()
	viewport.add_child(world)
	world.camera = Camera2D.new()
	world.add_child(world.camera)
	world.camera.make_current()
	world.manager = load("res://Scripts/player_manager.gd").new()
	world.add_child(world.manager)
	world.manager.set_process(false)
	world.manager.world = world
	world.apply_camera_zoom()
	var starting_zoom := world.camera.zoom
	var step := Alignment.screen_pixel_zoom_step(world.camera)

	# Rapid wheel clicks must accumulate from the destination, not an unfinished
	# animation; reversing those clicks must return to the original destination.
	world.zoom_camera(0.12)
	var first_target := Alignment.target_zoom(world.camera)
	check(world.camera.zoom.is_equal_approx(starting_zoom), "Wheel zoom must start without an instant jump")
	advance(world.camera, 0.05, 1)
	check(world.camera.zoom.y > starting_zoom.y and world.camera.zoom.y < first_target.y, "Wheel zoom must render intermediate scales")
	world.zoom_camera(0.12)
	world.zoom_camera(0.12)
	check(is_equal_approx(Alignment.target_zoom(world.camera).y, starting_zoom.y + step * 3.0), "Rapid wheel clicks lost zoom steps")
	for click in range(3): world.zoom_camera(-0.12)
	check(Alignment.target_zoom(world.camera).is_equal_approx(starting_zoom), "Rapid zoom reversal changed the resting destination")
	advance(world.camera, 1.0 / 60.0, 120)
	check(world.camera.zoom.is_equal_approx(starting_zoom), "Zoom reversal did not settle")

	# The same elapsed time must produce the same transition on different devices.
	var reference := -1.0
	for fps in [30, 60, 120]:
		world.manager.set_default_camera_zoom_silent()
		world.zoom_camera(0.12)
		advance(world.camera, 1.0 / fps, fps / 5)
		if reference < 0.0: reference = world.camera.zoom.y
		check(absf(world.camera.zoom.y - reference) < 0.0001, "Zoom timing changed at %s FPS" % fps)
		advance(world.camera, 1.0 / fps, fps)
		check(world.camera.zoom.is_equal_approx(Alignment.target_zoom(world.camera)), "Zoom failed to reach its exact destination")

	# Exercise the real mobile tap/hold/release path against the real camera manager.
	var controls = load("res://Scripts/mobile_controls.gd").new()
	controls.world = world
	world.manager.set_default_camera_zoom_silent()
	controls._begin_zoom_hold("zoom_in", 4)
	check(world.camera.zoom.is_equal_approx(starting_zoom), "Mobile tap must use the same eased zoom")
	advance(world.camera, 1.0 / 60.0, 12)
	controls._update_zoom_hold(0.5)
	var alignment: Node = world.camera.get_node(Alignment.NODE_NAME)
	check(alignment.continuous_zoom, "Held mobile zoom must use continuous scales")
	advance(world.camera, 1.0 / 60.0, 1)
	check(world.camera.zoom.y < Alignment.target_zoom(world.camera).y, "Held zoom jumped directly to its target")
	controls._release_touch_index(2)
	check(controls.zoom_hold_action == "zoom_in", "Another finger cancelled zoom")
	controls._release_touch_index(4)
	check(not alignment.continuous_zoom, "Touch release must finish continuous zoom")
	advance(world.camera, 1.0 / 60.0, 120)
	var output_scale := (viewport.get_stretch_transform() * Transform2D(0.0, world.camera.zoom, 0.0, Vector2.ZERO)).get_scale()
	check(output_scale.is_equal_approx(output_scale.round()), "Released zoom must settle on whole output pixels")
	check(is_equal_approx(output_scale.x, output_scale.y), "Zoom distorted square artwork pixels")
	controls._begin_zoom_hold("zoom_out", 5)
	controls._update_zoom_hold(0.5)
	world.allowed = false
	controls._update_zoom_hold(0.1)
	check(controls.zoom_hold_action == "" and not alignment.continuous_zoom, "UI cancellation must end continuous zoom")
	world.allowed = true
	controls.free()

	# Both bounds, resize during an active transition, and silent world entry.
	for direction in [1.0, -1.0]:
		for click in range(20): world.zoom_camera(direction * 0.12)
		advance(world.camera, 1.0 / 60.0, 120)
		check(world.camera.zoom.y >= world.CAMERA_ZOOM_MIN and world.camera.zoom.y <= world.CAMERA_ZOOM_MAX, "Smooth zoom escaped limits")
	world.manager.set_default_camera_zoom_silent()
	world.zoom_camera(0.12)
	viewport.size = Vector2i(637, 359)
	viewport.size_2d_override = Vector2i(521, 294)
	advance(world.camera, 1.0 / 60.0, 120)
	check(world.camera.zoom.is_equal_approx(Alignment.target_zoom(world.camera)), "Resize left an outdated zoom destination")
	world.zoom_camera(0.12)
	world.manager.set_default_camera_zoom_silent()
	check(not alignment.zoom_transition_active, "World entry must cancel an old zoom transition")
	check(world.camera.zoom.is_equal_approx(Alignment.target_zoom(world.camera)), "World entry must apply its default zoom immediately")
	world.zoom_camera(0.0)
	check(not alignment.zoom_transition_active, "Zero input started a zoom transition")
	viewport.queue_free()
	await process_frame
	print("SMOOTH_CAMERA_ZOOM: wheel, rapid input, reversal, 30/60/120 FPS, mobile tap/hold/release, UI cancellation, limits, resize and world entry; failures=%s" % failures)
	quit(1 if failures else 0)
