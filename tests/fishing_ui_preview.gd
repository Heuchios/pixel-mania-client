extends SceneTree
## Offscreen rendering of the real fishing UI in the isolated test project.
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
const FishingManager = preload("res://Scripts/fishing_manager.gd")

func _init() -> void:
	root.hide()
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://captures"
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = TestWorld.new()
	viewport.add_child(world)
	var manager = FishingManager.new()
	world.add_child(manager)
	world.fishing_manager = manager
	manager.setup(world)
	var ui = manager.fishing_ui
	ui.show_waiting("Worm Lure")
	await capture(viewport, output, "waiting")
	ui.show_bite(3.0)
	await capture(viewport, output, "bite")
	ui.set_reeling_reward(world.fish_textures.pond_fish)
	manager.pull_game.start(false)
	manager.pull_game.rest_left = 0
	manager.pull_game.pulls = 1
	manager.pull_game.cursor = .45
	manager.pull_game.feedback = "Tap REEL in the green zone."
	ui.show_pull_game(manager.pull_game.snapshot())
	await capture(viewport, output, "reeling")
	viewport.size = Vector2i(320, 720)
	await capture(viewport, output, "reeling-narrow")
	viewport.size = Vector2i(1280, 720)
	ui.show_catch_result({"name": "Pond Fish", "rarity": "common", "amount": "x1", "value": "3", "icon": world.fish_textures.pond_fish})
	await capture(viewport, output, "catch")
	viewport.queue_free()
	await process_frame
	quit(0)

func capture(viewport: SubViewport, output: String, state: String) -> void:
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(output.path_join("fishing-" + state + ".png"))
	if error != OK:
		push_error("Could not save " + state)
		quit(1)
	print("[fishing-preview] " + state)
