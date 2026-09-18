extends SceneTree

class ZoomWorld extends Node:
	var in_world := true
	var allowed := true
	var zoom := 3.0
	func can_use_camera_zoom():
		return allowed
	func zoom_camera(amount: float, _feedback: bool = true):
		zoom = clampf(zoom + amount, 1.5, 7.0)

func _initialize():
	call_deferred("run")

func run():
	var controls = load("res://Scripts/mobile_controls.gd").new()
	var world := ZoomWorld.new()
	controls.world = world
	controls._begin_zoom_hold("zoom_in", 4)
	assert(is_equal_approx(world.zoom, 3.3))
	for i in range(60):
		controls._update_zoom_hold(1.0 / 60.0)
	var at_60 := world.zoom
	controls._release_touch_index(2)
	assert(controls.zoom_hold_action == "zoom_in")
	controls._release_touch_index(4)
	controls._update_zoom_hold(1.0)
	assert(is_equal_approx(world.zoom, at_60))
	world.zoom = 3.0
	controls._begin_zoom_hold("zoom_in", 4)
	for i in range(30):
		controls._update_zoom_hold(1.0 / 30.0)
	assert(is_equal_approx(world.zoom, at_60))
	world.allowed = false
	controls._update_zoom_hold(0.1)
	assert(controls.zoom_hold_action == "")
	world.allowed = true
	controls._begin_zoom_hold("zoom_out", 5)
	controls._update_zoom_hold(5.0)
	assert(is_equal_approx(world.zoom, 1.5))
	controls._release_all_actions()
	assert(controls.zoom_hold_action == "")
	controls.free()
	world.free()
	print("MOBILE_ZOOM_OK: tap, hold, frame rates, touch ownership, UI cancellation, limits")
	quit()
