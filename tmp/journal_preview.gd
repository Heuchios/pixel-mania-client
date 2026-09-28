extends SceneTree
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
const Manager = preload("res://Scripts/fishing_manager.gd")
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1440,1000)
	var world = TestWorld.new()
	root.add_child(world)
	var manager = Manager.new()
	world.add_child(manager)
	world.fishing_manager = manager
	manager.setup(world)
	var ui = manager.fishing_ui.journal_ui
	ui.open_journal()
	ui._clear_cards()
	ui.empty_label.hide()
	for i in range(12):
		ui._create_fish_card({"name":"Small Pond Fish" if i%2 else "Medium Pond Fish", "discovered":i%3!=0, "rarity":"common", "icon":world.fish_textures.pond_fish, "location":"Any Water", "total_caught":8, "biggest_weight":25.9, "best_value":12})
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/fishing-journal-updated.png")
	ui._on_tab_pressed("legendary")
	assert(ui.selected_rarity == "legendary")
	root.size=Vector2i(800,600)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/fishing-journal-compact.png")
	ui.close_journal()
	assert(not ui.visible)
	world.free()
	print("[journal-layout] passed")
	quit()
