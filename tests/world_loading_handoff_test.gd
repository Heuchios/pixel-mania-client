extends SceneTree

const Handoff = preload("res://Scripts/world_loading_handoff.gd")

class Save extends RefCounted:
	var waiting_for_server_world_state := true

class World extends Node:
	var save_manager := Save.new()
	var input_manager = null
	var ui_layer = null
	var player = null
	var noclip_enabled := false
	var current_world_name := "TEST"
	var applying_network_world_update := false
	var in_world := true
	var blocks := {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var lobby = load("res://Scenes/ui/lobby/LobbyScene.tscn").instantiate()
	lobby.set_script(load("res://tests/lobby_ui_fixture.gd"))
	root.add_child(lobby)
	lobby.set_process(false)
	lobby._show_join_world_loading_overlay("TEST")
	var overlay: Node = root.get_node("WorldLoadingOverlay")
	var overlay_id := overlay.get_instance_id()
	var canvas: CanvasLayer = lobby._find_loading_canvas(overlay)
	var bar: Range = canvas.find_child("ProgressBar", true, false)
	var percent: Label = canvas.find_child("ProgressPercent", true, false)
	var previous := bar.value
	assert(previous == Handoff.INITIAL_PROGRESS)
	for ratio in [0.0, 0.2, 0.75, 0.4, 1.0]:
		lobby._set_join_world_loading_progress(ratio)
		assert(bar.value >= previous, "Lobby progress must never move backwards")
		assert(bar.value < 100, "Scene preparation is not a completed world join")
		previous = bar.value
	assert(percent.text == "30%")
	var backdrop: ColorRect
	var backdrop_pixel := Color.BLACK
	if "--render" in OS.get_cmdline_user_args():
		backdrop = ColorRect.new()
		backdrop.size = root.get_visible_rect().size
		backdrop.color = Color.RED
		root.add_child(backdrop)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		backdrop_pixel = frame.get_pixel(20, 20)
		if frame.get_format() in [Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGBF, Image.FORMAT_RGBAF]:
			frame.convert(Image.FORMAT_RGBA8)
			frame.linear_to_srgb()
		frame.save_png("user://world-loading-preload.png")
	lobby.free()
	assert(canvas.visible, "The lobby-to-world scene change keeps the same overlay visible")

	var world := World.new()
	root.add_child(world)
	var manager = load("res://Scripts/world_loading_ui_manager.gd").new()
	world.add_child(manager)
	manager.set_process(false)
	manager.setup(world)
	if backdrop != null:
		backdrop.color = Color.BLUE
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		assert(frame.get_pixel(20, 20).is_equal_approx(backdrop_pixel), "Scene backgrounds must not bleed through the continuous loading screen")
		backdrop.free()
	assert(manager.world_loading_scene_instance.get_instance_id() == overlay_id)
	assert(bar.value == previous, "Adopting the lobby overlay must not flash 0%")
	manager.begin_smooth_world_load("TEST", true)
	assert(bar.value == previous, "World setup continues the lobby's progress")
	var operation: int = manager.loading_operation_id
	manager.begin_smooth_world_load("TEST", true)
	assert(manager.loading_operation_id == operation, "Repeated begin calls share one loading operation")
	assert(bar.value == previous)
	manager.update_message("Building TEST...")
	manager._update_loading_progress(2.0)
	assert(bar.value >= previous and bar.value < 100)
	previous = bar.value
	Handoff.update_preload(overlay, canvas, 0.0)
	assert(bar.value == previous, "Late lobby progress cannot overwrite the active world loader")
	manager.finish_smooth_world_load()
	assert(canvas.visible and bar.value < 100, "An outstanding server snapshot prevents a completed loading screen")

	# A duplicate begin during the reveal must not restore an opaque screen.
	world.save_manager.waiting_for_server_world_state = false
	manager.waiting_for_server_state = false
	manager._set_loading_progress(100.0, true)
	manager._fade_out_loading_overlay(operation)
	manager.world_loading_root.modulate.a = 0.4
	var fade: Tween = manager.world_loading_fade_tween
	manager.begin_smooth_world_load("TEST", true)
	manager.begin_smooth_world_load("TEST", false)
	assert(manager.world_loading_fade_tween == fade and fade.is_running())
	assert(is_equal_approx(manager.world_loading_root.modulate.a, 0.4))
	assert(not bool(world.get_meta("world_loading_input_blocked")))
	await create_timer(0.2).timeout
	assert(not canvas.visible, "Exactly one reveal finishes this loading operation")

	# The reusable overlay starts a fresh later join without stale 100% or zoom.
	canvas.visible = true
	Handoff.begin(overlay, canvas, "NEXT")
	Handoff.update_preload(overlay, canvas, 1.0)
	manager.begin_smooth_world_load("NEXT", true)
	assert(bar.value == Handoff.PRELOAD_COMPLETE_PROGRESS)
	assert(manager.world_loading_root.scale == Vector2.ONE)
	assert(manager.loading_operation_id > operation)
	operation = manager.loading_operation_id
	manager.waiting_for_server_state = false
	manager._set_loading_progress(100.0, true)
	manager._fade_out_loading_overlay(operation)
	world.set_meta("world_entry_in_progress", true)
	manager.begin_smooth_world_load("NEXT", true)
	await create_timer(0.2).timeout
	assert(canvas.visible and manager.waiting_for_server_state, "A fresh authoritative wait cancels the old reveal callback")
	manager.cancel_smooth_world_load()
	world.free()
	var overlays := 0
	for child in root.get_children():
		if str(child.name).begins_with("WorldLoadingOverlay"):
			overlays += 1
	assert(overlays == 1, "Only one loading overlay may survive scene changes")
	overlay.free()
	print("WORLD_LOADING_HANDOFF_PASS: continuous progress, one overlay, readiness, repeated begins, reveal and later joins")
	quit()
