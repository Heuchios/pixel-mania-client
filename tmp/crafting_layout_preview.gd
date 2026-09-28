extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 840)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	world.inventory = {"wooden_chair":11, "royal_door":100}
	var ui := Control.new()
	viewport.add_child(ui)
	var craft = load("res://Scripts/crafting_ui.gd").new()
	ui.add_child(craft)
	craft.setup(world, ui)
	craft.open_crafting(Vector2i.ZERO)
	craft.search_box.text = "fireplace"
	craft._filter_changed()
	assert(craft.get_visible_recipes().size() == 1)
	craft.search_box.text = "unmatchedxyz"
	craft._filter_changed()
	assert(craft.get_visible_recipes().is_empty())
	craft.search_box.text = ""
	craft.ready_filter.button_pressed = true
	assert(craft.get_visible_recipes().size() == 1)
	craft.ready_filter.button_pressed = false
	craft._filter_changed()
	await create_timer(0.5).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("D:/Pixelmania/crafting-updated.png")
	print("Crafting search and readiness filters passed")
	viewport.size = Vector2i(800, 600)
	craft.update_panel_position()
	assert(craft.panel.position.x >= 0 and craft.panel.position.y >= 0)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("D:/Pixelmania/crafting-compact.png")
	world.free()
	quit()
