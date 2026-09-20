extends SceneTree
## Offscreen rendering of the real fishing UI in the isolated test project.
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
const FishingManager = preload("res://Scripts/fishing_manager.gd")

func _init() -> void:
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
	world.item_database["pond_fish_large"] = {"display_name": "Pond Fish", "category": "fish", "rarity": "common", "fish_base_price_kg": 2.25}
	world.fish_textures["pond_fish_large"] = load("res://Assets/items/fish/pond_fish_large.png")
	var catch_data: Dictionary = manager._build_catch_result_data("pond_fish_large", true, 5.7)
	assert(catch_data.amount == "5.7 kg")
	assert(catch_data.name == "Pond Fish")
	assert(catch_data.value == 13)
	ui.show_catch_result(catch_data)
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
