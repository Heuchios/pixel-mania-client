extends SceneTree

const FishingUI = preload("res://Scripts/ui/fishing_minigame_ui.gd")

class WorldFixture extends Node:
	var fishing_manager = null
	var ui_layer: CanvasLayer

class ManagerFixture extends Node:
	var fishing_ui = null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(15).timeout.connect(func(): quit(1))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 580)
	viewport.handle_input_locally = true
	root.add_child(viewport)
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var world := WorldFixture.new()
	world.ui_layer = layer
	viewport.add_child(world)
	var ui = FishingUI.new()
	layer.add_child(ui)
	ui.setup(world)
	# A later HUD branch can receive input first despite the journal's high z_index.
	var overlay := Control.new()
	overlay.size = Vector2(1280, 580)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	for dimensions in [Vector2i(1280, 580), Vector2i(640, 360), Vector2i(360, 640)]:
		viewport.size = dimensions
		viewport.size_2d_override = Vector2i(1920, 1080) if dimensions == Vector2i(640, 360) else Vector2i.ZERO
		viewport.size_2d_override_stretch = true
		for touch in [false, true]:
			ui.open_journal()
			await process_frame
			await process_frame
			var journal = ui.journal_ui
			var close := journal.find_child("CloseButton", true, false) as Button
			var transform := close.get_global_transform_with_canvas()
			var point := transform * (close.size * 0.5)
			if touch:
				var canceled_press := InputEventScreenTouch.new()
				canceled_press.index = 1
				canceled_press.position = point
				canceled_press.pressed = true
				viewport.push_input(canceled_press, true)
				var canceled_release := InputEventScreenTouch.new()
				canceled_release.index = 1
				canceled_release.position = point
				canceled_release.canceled = true
				viewport.push_input(canceled_release, true)
				assert(journal.visible, "A canceled touch must not close the journal")
				# Raw multitouch must work without relying on mouse emulation.
				for pressed in [true, false]:
					var event := InputEventScreenTouch.new()
					event.index = 1
					event.position = point
					event.pressed = pressed
					viewport.push_input(event, true)
			else:
				for pressed in [true, false]:
					var event := InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.position = point
					event.pressed = pressed
					viewport.push_input(event, true)
			assert(not journal.visible, "Journal close failed: touch=%s viewport=%s" % [touch, dimensions])
			assert(close.size.x * close.get_screen_transform().x.length() >= 47.9, "Close target shrank on a small viewport")
	# Exercise the real world's modal checks and the Android Back/Escape route.
	var game_world = load("res://Scripts/world.gd").new()
	var manager := ManagerFixture.new()
	manager.fishing_ui = ui
	game_world.fishing_manager = manager
	game_world.in_world = true
	var inputs = load("res://Scripts/input_manager.gd").new()
	inputs.setup(game_world)
	ui.open_journal()
	assert(game_world.is_movement_blocking_ui_open())
	assert(game_world.is_gameplay_hud_blocked())
	assert(inputs.handle_back_request())
	assert(not ui.journal_ui.visible, "Back must close the journal first")
	inputs.free()
	game_world.free()
	manager.free()
	viewport.queue_free()
	await process_frame
	print("FISHING_JOURNAL_INPUT_PASS")
	quit()
