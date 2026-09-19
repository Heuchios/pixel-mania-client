extends SceneTree

const DB = preload("res://Scripts/item_database.gd")
const ATLAS = preload("res://Scripts/ItemAtlasDB.gd")
const BOOK_DATA = preload("res://Scripts/ui/recipe_book_data.gd")
const BOOK = preload("res://Scenes/ui/recipe_book/RecipeBookScene.tscn")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://Scripts/world.gd").new()
	world.item_database = ATLAS.merge_item_database(DB.ITEMS.duplicate(true))
	world.splice_recipes = DB.SPLICE_RECIPES
	world.tier_1_splice_balance = DB.TIER_1_SPLICE_BALANCE.duplicate(true)
	world.apply_tier_1_splice_balance()
	world.ensure_seed_item_definitions_from_blocks()
	assert(world.item_database.hay.display_name == "Dried Hay")
	assert(world.item_database.hay_seed.display_name == "Dried Hay Seed")
	assert(world.item_database.sugar_cane.display_name == "Sugarcane")
	var hay_frames = world.item_database.hay.animation_atlas_coords
	assert(hay_frames.size() == 5)
	for i in range(5):
		assert(Vector2i(hay_frames[i]) == Vector2i([0, 1, 2, 1, 0][i], 23))
	var cane_variants = world.item_database.sugar_cane.vertical_variant_atlas_coords
	for key in {"single": Vector2i(4, 22), "bottom": Vector2i(4, 23), "middle": Vector2i(5, 23), "top": Vector2i(5, 22)}:
		var expected = {"single": Vector2i(4, 22), "bottom": Vector2i(4, 23), "middle": Vector2i(5, 23), "top": Vector2i(5, 22)}[key]
		var coord = cane_variants[key]
		assert(Vector2i(coord[0], coord[1]) == expected if coord is Array else Vector2i(coord) == expected)
	for item_id in ["hay", "sugar_cane", "slime", "ceiling_lamp", "pillar", "biohazard_barrel", "star_block", "chicken", "checkpoint", "cow", "bomb", "duck", "fire_escape", "fire_hydrant", "dice_block", "blue_portal", "password_door"]:
		assert(world.item_database[item_id + "_seed"].grows_into == item_id)
		for rule_key in ["drop_rules", "tree_drop_rules"]:
			var drops = world.item_database[item_id][rule_key].fixed_drops
			for drop_id in [item_id, item_id + "_seed", "gem"]:
				assert(drops.any(func(drop): return drop.item_id == drop_id), item_id + " " + rule_key + " " + drop_id)
	assert(world.item_database.barn_block.atlas_coords == Vector2i(0, 24))
	assert(world.item_database.barn_block.solid)
	assert(world.item_database.barn_block.connected_variant_atlas_coords.size() == 48)
	assert(not world.item_database.barn_block.hidden)
	var tiers: Dictionary = BOOK_DATA.build_from_world(world)
	for item_id in ["hay", "sugar_cane"]:
		var icon = BOOK_DATA.item_icon(world.item_database[item_id])
		assert(icon is AtlasTexture)
		assert(icon.get_size() == Vector2(32, 32))
		assert(icon.region.position == Vector2(0, 736) if item_id == "hay" else icon.region.position == Vector2(128, 704))
	var by_id := {}
	var counts := {"splicing": 0, "crafting": 0, "furnace": 0}
	for tier in tiers:
		for recipe in tiers[tier]:
			assert(not by_id.has(recipe.id), recipe.id)
			by_id[recipe.id] = recipe
			counts[recipe.method] += 1
			assert(recipe.icon != null or not str(recipe.name).is_empty(), recipe.id)
			for ingredient in recipe.ingredients:
				assert(ingredient.icon != null, recipe.id + ": " + ingredient.id)
	assert(counts == {"splicing": 171, "crafting": 4, "furnace": 3}, str(counts))
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://docs/splicing-recipe-status.json"))
	for row in rows:
		if row.status not in ["active", "crafting_active"]:
			continue
		var recipe: Dictionary = by_id[row.ids[2]]
		assert(recipe.icon != null, str(row.names))
		assert(recipe.tier == int(row.tier), str(row.names))
		assert(recipe.method == row.method, str(row.names))
		assert(world.item_database[row.ids[2]].recipe_tier == int(row.tier))
	var other_splicing := 0
	for recipe in tiers.get(0, []):
		if recipe.method == "splicing":
			other_splicing += 1
	assert(other_splicing == 8)
	assert(by_id.fireplace.method == "crafting")
	assert(by_id.wooden_chair.used_for.any(func(r): return r.id == "fireplace"))
	var book = BOOK.instantiate()
	book.play_open_animation = false
	root.add_child(book)
	book.setup(world)
	book.open()
	assert(book.get_current_tier() == 2)
	assert(not book._available_tiers.has(1))
	book.select_tier(5)
	book.select_recipe("blue_stripe_wall") # corrected Tier 4 recipe
	assert(book.get_selected_recipe_id() == "blue_stripe_wall")
	book._on_search_changed("chandelier")
	assert(book._visible_recipes.any(func(r): return r.id == "chandelier"))
	book._on_method_selected(1)
	assert(book._available_tiers == [5])
	book._on_search_changed("")
	assert(book._visible_recipes.size() == 4)
	book.select_recipe("fireplace")
	assert(book.detail_description.text.contains("Crafting Table"))
	book._on_recipe_link_pressed(book._ingredient_pool[0])
	assert(book.get_selected_recipe_id() == "wooden_chair")
	assert(book._method == "splicing")
	for index in [1, 2, 0, 1, 0]:
		book._on_method_selected(index)
	for button in book._tier_buttons.values():
		assert(button.pressed.get_connections().size() == 1)
	book._on_search_changed("no_such_recipe_9824")
	assert(book._visible_recipes.is_empty())
	assert(book.found_label.text == "Search results: 0")
	book._on_search_changed("")
	book.select_tier(5)
	book.select_recipe("building_brick_block")
	var inventory = load("res://Scripts/inventory_manager.gd").new()
	inventory.world = world
	world.inventory_manager = inventory
	await process_frame
	var seed_slot: TextureRect = book._ingredient_pool[0].get_node("Icon")
	var seed_id: String = by_id.building_brick_block.ingredients[0].id
	book._update_seed_slot_visual(seed_slot, seed_id)
	var overlay = seed_slot.get_node_or_null(inventory.SEED_BOX_PREVIEW_NODE_NAME)
	assert(overlay is TextureRect)
	assert(overlay.texture == world.get_seed_icon_preview_layout(seed_id).preview_texture)
	assert(seed_slot.texture == world.get_seed_drop_icon_texture(seed_id))
	book._update_seed_slot_visual(seed_slot, "building_brick_block")
	assert(seed_slot.get_node_or_null(inventory.SEED_BOX_PREVIEW_NODE_NAME) == null)
	book._update_seed_slot_visual(seed_slot, seed_id)
	if "--capture-book" in OS.get_cmdline_user_args():
		var capture := SubViewport.new()
		capture.size = Vector2i(1280, 800)
		capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(capture)
		book.reparent(capture, false)
		book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		book.show()
		await process_frame
		await process_frame
		book._fit_window_to_screen()
		await RenderingServer.frame_post_draw
		capture.get_texture().get_image().save_png("D:/Pixelmania/recipe-book-preview.png")
		print("Book rendered: ", book.visible, " ", book.size, " ", book.window.get_global_rect())
	print("Recipe book OK: 171 splicing, 4 crafting, 3 furnace; sheet tiers, icons, search, links, filters and reusable tier tabs")
	book.queue_free()
	inventory.free()
	world.free()
	await process_frame
	quit(0)
