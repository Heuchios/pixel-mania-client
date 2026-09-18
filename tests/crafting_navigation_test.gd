extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	root.size = Vector2i(1280, 800)
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/ItemAtlasDB.gd").merge_item_database(load("res://Scripts/item_database.gd").ITEMS.duplicate(true))
	world.inventory = {"wooden_chair":11, "royal_door":100}
	var ui := Control.new()
	root.add_child(ui)
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
		root.get_texture().get_image().save_png("D:/Pixelmania/crafting-redesign.png")
	print("Crafting search and readiness filters passed")
	world.free()
	quit()
