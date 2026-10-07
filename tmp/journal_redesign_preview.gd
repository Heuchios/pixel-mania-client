extends SceneTree
const TestWorld = preload("res://tests/fixtures/fishing_test_world.gd")
const Journal = preload("res://Scripts/ui/fishing_journal_ui.gd")
func _init(): call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = TestWorld.new()
	viewport.add_child(world)
	var ui = Journal.new()
	world.add_child(ui)
	ui.setup(world)
	ui.open_journal()
	ui.completion_label.text = 'Completion: 53%  (10/19)'
	ui.stats_label.text = 'Level 8  |  XP 1935  |  Total caught 28'
	ui.rarest_label.text = 'Rarest catch: Crystal Fish  |  Legendary  |  62.8 kg'
	ui._clear_cards()
	ui.empty_label.hide()
	var rarities = ["common", "rare", "uncommon", "legendary", "epic", "common"]
	for i in range(6):
		ui._create_fish_card({"name":"Pond Fish" if i%2==0 else "Crystal Fish", "discovered":i!=2, "rarity":rarities[i], "icon":world.fish_textures.guppy if i%2==0 else world.fish_textures.swordfish, "location":"Any Water", "total_caught":28, "biggest_weight":62.8, "best_value":225})
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/fishing-journal-redesign.png")
	assert(ui.cards_root.columns == 2)
	assert(ui.cards_root.size.x <= ui.cards_scroll.size.x)
	viewport.size = Vector2i(800, 600)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	assert(ui.panel.position.x >= 0 and ui.panel.position.y >= 0)
	viewport.get_texture().get_image().save_png("D:/Pixelmania/fishing-journal-redesign-compact.png")
	ui._on_tab_pressed("rare")
	assert(ui.selected_rarity == "rare")
	ui.close_journal()
	assert(not ui.visible)
	viewport.queue_free()
	print("[journal-redesign] passed")
	quit()
