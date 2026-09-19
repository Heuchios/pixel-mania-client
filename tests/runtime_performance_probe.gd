extends SceneTree

class WorldStub extends Node:
	var in_world := true
	var selected_item_category := "block"
	var selected_item_type := "dirt"
	var inventory_manager = null
	var fishing_manager = null
	var uses := 0
	func use_selected_item_at_mouse(): uses += 1
	func is_movement_locked(): return false
	func is_major_ui_open(): return false
	func can_use_camera_zoom(): return true

class InputProbe extends "res://Scripts/input_manager.gd":
	func _any_ui_blocking(): return false

class MobileProbe extends "res://Scripts/mobile_controls.gd":
	var uses := 0
	func _trigger_punch(_pulse_input_action: bool = true): uses += 1
	func _is_mobile_platform(): return true

func _initialize(): call_deferred("run")

func run():
	var world := WorldStub.new()
	var controls := MobileProbe.new()
	root.add_child(controls)
	controls.world = world
	controls._configure_root()
	controls._build_controls()
	controls.set_process(false)
	var input := InputProbe.new()
	input.world = world
	var place = load("res://tests/runtime_place_fixture.gd").new()
	for fps in [15, 30, 45, 60, 144]:
		world.uses = 0
		controls.uses = 0
		controls.punch_hold_timer = 0.0
		controls.punch_hold_repeat_active = false
		controls.active_action_touches = {"punch": 1}
		input.is_holding = true
		input.active_touch_index = 2
		input.hold_timer = 0.0
		input.hold_repeat_active = false
		place.uses = 0
		place.fast_block_place_hold_active = true
		place.fast_block_place_hold_timer = place.FAST_BLOCK_PLACE_INITIAL_DELAY
		place.fast_block_place_last_grid = Vector2i.ZERO
		for frame in range(fps * 30):
			controls._update_punch_hold(1.0 / fps)
			input._process(1.0 / fps)
			place.update_fast_block_place_hold(1.0 / fps)
		print("PERF_HOLD ", JSON.stringify({"fps": fps, "seconds": 30, "mobile_repeats": controls.uses, "pointer_repeats": world.uses, "place_repeats": place.uses}))
		assert(controls.uses == 100 and world.uses == 100, "Punch cadence differs by FPS")
		assert(place.uses == 187, "Place cadence differs by FPS")
	# A long render stall produces one action, never a catch-up burst.
	var previous_uses := controls.uses
	controls._update_punch_hold(5.0)
	assert(controls.uses == previous_uses + 1)
	controls._update_punch_hold(0.0)
	assert(controls.uses == previous_uses + 1)
	var previous_pointer_uses := world.uses
	input.hold_repeat_active = false
	input.hold_timer = 0.0
	input._process(5.0)
	input._process(0.0)
	assert(world.uses == previous_pointer_uses + 1, "Initial hold stall must not carry a full extra repeat")
	input._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not input.is_holding)
	place._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not place.fast_block_place_hold_active)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 1
	canceled.canceled = true
	controls._input(canceled)
	assert(not controls._is_punch_held())
	# Moving and punching own separate fingers. Canceling one must not release
	# the other, and a canceled touch must never restart through GUI dispatch.
	controls.active_action_touches = {"move_left": 8, "punch": 9}
	Input.action_press("move_left")
	canceled.index = 9
	canceled.pressed = true
	controls._input(canceled)
	controls._on_punch_button_gui_input(canceled)
	assert(not controls._is_punch_held())
	assert(Input.is_action_pressed("move_left"))
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not Input.is_action_pressed("move_left"))
	assert(controls.active_action_touches.is_empty())
	place.fast_block_place_hold_active = true
	place.fast_block_place_hold_touch_index = 12
	place.end_fast_block_place_hold(13)
	assert(place.fast_block_place_hold_active)
	place.end_fast_block_place_hold(12)
	assert(not place.fast_block_place_hold_active)
	var started := Time.get_ticks_usec()
	for frame in range(3000): controls._layout_controls()
	print("PERF_LAYOUT ", JSON.stringify({"frames": 3000, "total_usec": Time.get_ticks_usec() - started}))
	controls.free()
	input.free()
	place.free()
	world.free()
	print("RUNTIME_PERFORMANCE_PROBE_OK")
	quit()
