extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const StationRecipes = preload("res://Scripts/station_recipes.gd")

const PANEL_SIZE = Vector2(1080, 700)
const RECIPE_ROOT_WIDTH = 960.0
const RECIPE_ROOT_MIN_HEIGHT = 376.0
const RECIPE_CARD_SIZE = Vector2(470, 212)
const RECIPE_CARD_GAP = Vector2(16, 18)

var world = null
var ui_layer_ref = null

var panel = null
var recipe_scroll = null
var recipe_root = null
var station_grid_pos = Vector2i.ZERO
var gem_label = null
var info_label = null

var recipes = []
var search_box: LineEdit
var ready_filter: Button
var all_filter: Button
var result_label: Label


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	recipes = StationRecipes.get_recipes("crafting_station")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	setup_panel()
	close_crafting()


func _process(_delta):
	update_panel_position()
	update_header()


func station_panel_style():
	return PixelUIStyle.panel_style()


func station_header_style():
	return PixelUIStyle.header_style()


func station_section_style():
	return PixelUIStyle.section_style()


func station_chip_style():
	return PixelUIStyle.input_style()


func apply_station_arcade_button_style(button: Button, primary: bool = false, danger: bool = false, font_size: int = 14):
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		return

	if primary:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return

	PixelUIStyle.apply_blue_button(button, font_size)


func apply_station_card_style(card: Panel, can_make: bool):
	if card == null:
		return

	card.add_theme_stylebox_override("panel", PixelUIStyle.card_style_featured() if can_make else PixelUIStyle.card_style())


func apply_station_scrollbar_style():
	if recipe_scroll == null:
		return

	var scrollbar = recipe_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(16, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func setup_panel():
	if ui_layer_ref == null:
		return

	panel = ui_layer_ref.get_node_or_null("CraftingPanel")

	if panel == null:
		panel = Control.new()
		panel.name = "CraftingPanel"
		ui_layer_ref.add_child(panel)

	panel.size = PANEL_SIZE
	panel.z_index = 110
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if panel is ColorRect:
		panel.color = Color(1.0, 1.0, 1.0, 0.0)

	for child in panel.get_children():
		child.queue_free()

	var far_shadow = Panel.new()
	far_shadow.name = "DropShadow"
	far_shadow.position = Vector2(10, 12)
	far_shadow.size = panel.size
	far_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color.BLACK
	far_shadow.add_theme_stylebox_override("panel", shadow_style)
	panel.add_child(far_shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", station_panel_style())
	panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(8, 8)
	top_bar.size = Vector2(panel.size.x - 16.0, 84)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", station_header_style())
	panel.add_child(top_bar)

	var header_gloss = ColorRect.new()
	header_gloss.name = "HeaderGloss"
	header_gloss.position = top_bar.position + Vector2(10, 8)
	header_gloss.size = Vector2(top_bar.size.x - 20.0, 18)
	header_gloss.visible = false
	header_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_gloss)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, 91)
	top_line.size = Vector2(panel.size.x, 4)
	top_line.color = Color(0.30, 0.38, 0.78, 0.55)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "CRAFTING STATION"
	title.position = Vector2(36, 16)
	title.size = Vector2(510, 54)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_meta("pixelmania_font_size", 28)
	PixelUIStyle.apply_label_shadow(title, 28)
	panel.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "Combine materials to create items"
	title_sub.position = Vector2(42, 66)
	title_sub.size = Vector2(560, 20)
	title_sub.set_meta("pixelmania_font_size", 16)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	panel.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(panel.size.x - 76.0, 20)
	close_button.size = Vector2(52, 48)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_crafting)
	panel.add_child(close_button)

	var gem_chip = Panel.new()
	gem_chip.name = "GemChip"
	gem_chip.position = Vector2(close_button.position.x - 252.0, 20)
	gem_chip.size = Vector2(238, 48)
	gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_chip.add_theme_stylebox_override("panel", station_chip_style())
	panel.add_child(gem_chip)

	var gem_icon = TextureRect.new()
	gem_icon.name = "GemIcon"
	gem_icon.position = gem_chip.position + Vector2(12, 6)
	gem_icon.size = Vector2(36, 36)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		gem_icon.texture = world.currency_textures["gem"]
	panel.add_child(gem_icon)

	gem_label = Label.new()
	gem_label.name = "GemLabel"
	gem_label.position = gem_chip.position + Vector2(56, 7)
	gem_label.size = Vector2(170, 34)
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(gem_label, 21)
	panel.add_child(gem_label)

	search_box = LineEdit.new()
	search_box.name = "Search"
	search_box.position = Vector2(48, 112)
	search_box.size = Vector2(570, 44)
	search_box.placeholder_text = "Search recipes or ingredients..."
	search_box.clear_button_enabled = true
	search_box.add_theme_stylebox_override("normal", station_chip_style())
	search_box.add_theme_stylebox_override("focus", PixelUIStyle.input_focus_style())
	search_box.add_theme_font_override("font", PixelUIStyle.get_game_font())
	search_box.add_theme_font_size_override("font_size", 18)
	search_box.text_changed.connect(func(_text): _filter_changed())
	panel.add_child(search_box)
	ready_filter = Button.new()
	ready_filter.toggle_mode = true
	ready_filter.name = "ReadyFilter"
	ready_filter.text = "Ready to craft"
	ready_filter.position = Vector2(806, 112)
	ready_filter.size = Vector2(224, 44)
	PixelUIStyle.apply_tab_button(ready_filter, false, 18)
	ready_filter.toggled.connect(func(_pressed): _filter_changed())
	panel.add_child(ready_filter)
	all_filter = Button.new()
	all_filter.name = "AllRecipes"
	all_filter.text = "All recipes"
	all_filter.position = Vector2(634, 112)
	all_filter.size = Vector2(156, 44)
	PixelUIStyle.apply_tab_button(all_filter, true, 18)
	all_filter.pressed.connect(func(): ready_filter.set_pressed_no_signal(false); _filter_changed())
	panel.add_child(all_filter)
	info_label = _card_label(panel, "Info", "Select a recipe to craft one item.", Vector2(48, panel.size.y - 38), Vector2(740, 26), 14)
	result_label = _card_label(panel, "Results", "", Vector2(800, panel.size.y - 38), Vector2(230, 26), 14)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var recipe_area = Panel.new()
	recipe_area.name = "RecipeArea"
	recipe_area.position = Vector2(32, 178)
	recipe_area.size = Vector2(panel.size.x - 64.0, panel.size.y - 226.0)
	recipe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_area.add_theme_stylebox_override("panel", station_section_style())
	panel.add_child(recipe_area)

	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.position = Vector2(48, 194)
	recipe_scroll.size = Vector2(panel.size.x - 96.0, panel.size.y - 258.0)
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	recipe_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(recipe_scroll)

	recipe_root = Control.new()
	recipe_root.name = "RecipeRoot"
	recipe_root.position = Vector2.ZERO
	recipe_root.size = Vector2(RECIPE_ROOT_WIDTH, RECIPE_ROOT_MIN_HEIGHT)
	recipe_root.custom_minimum_size = Vector2(RECIPE_ROOT_WIDTH, RECIPE_ROOT_MIN_HEIGHT)
	recipe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_scroll.add_child(recipe_root)

	apply_station_scrollbar_style()
	create_recipe_cards()
	update_panel_position()
	update_header()


func create_recipe_cards():
	if recipe_root == null:
		return

	for child in recipe_root.get_children():
		child.queue_free()

	var visible_recipes := get_visible_recipes()
	result_label.text = "%d recipes" % visible_recipes.size()
	if visible_recipes.is_empty():
		_card_label(recipe_root, "Empty", "No matching recipes. Try another search or show all recipes.", Vector2(24, 48), Vector2(880, 80), 20)
	var columns = 2
	var row_height := RECIPE_CARD_SIZE.y
	for recipe in visible_recipes:
		row_height = maxf(row_height, 144 + recipe.cost.size() * 34)
	var rows = int(ceil(float(visible_recipes.size()) / float(columns)))
	var content_height = max(RECIPE_ROOT_MIN_HEIGHT, rows * row_height + max(0, rows - 1) * RECIPE_CARD_GAP.y)

	recipe_root.size = Vector2(RECIPE_ROOT_WIDTH, content_height)
	recipe_root.custom_minimum_size = Vector2(RECIPE_ROOT_WIDTH, content_height)

	for i in range(visible_recipes.size()):
		var recipe = visible_recipes[i]
		var column = i % columns
		var row = int(floor(float(i) / float(columns)))
		create_recipe_card(recipe, Vector2(column * (RECIPE_CARD_SIZE.x + RECIPE_CARD_GAP.x), row * (row_height + RECIPE_CARD_GAP.y)), i)


func get_visible_recipes() -> Array:
	var visible_recipes: Array = []

	for recipe in recipes:
		if should_show_recipe(recipe) and _matches_filters(recipe):
			visible_recipes.append(recipe)

	return visible_recipes


func should_show_recipe(recipe: Dictionary) -> bool:
	if not is_rod_upgrade_recipe(recipe):
		return true

	var previous_rod_cost := get_recipe_previous_rod_cost(recipe)
	if previous_rod_cost.is_empty():
		return true

	return get_crafting_cost_inventory_count(
		str(previous_rod_cost.get("item_id", "")),
		str(previous_rod_cost.get("category", ""))
	) > 0


func is_rod_upgrade_recipe(recipe: Dictionary) -> bool:
	var output = recipe.get("output", {})
	if not (output is Dictionary):
		return false

	var output_id := str(output.get("item_id", ""))
	var output_category := str(output.get("category", ""))
	if output_category != "tool":
		return false

	return is_fishing_rod_item_id(output_id)


func get_recipe_previous_rod_cost(recipe: Dictionary) -> Dictionary:
	var costs = recipe.get("cost", [])
	if not (costs is Array):
		return {}

	for cost in costs:
		if not (cost is Dictionary):
			continue
		if str(cost.get("category", "")) != "tool":
			continue
		if is_fishing_rod_item_id(str(cost.get("item_id", ""))):
			return cost

	return {}


func is_fishing_rod_item_id(item_id: String) -> bool:
	if world != null and world.item_database.has(item_id):
		return bool(world.item_database[item_id].get("fishing_rod", false))

	return item_id in [
		"bamboo_rod",
		"refined_bamboo_rod",
		"pristine_bamboo_rod",
		"fishing_rod",
		"fiberglass_rod",
		"refined_fiberglass_rod",
		"pristine_fiberglass_rod",
		"tungsten_rod",
		"refined_tungsten_rod",
		"pristine_tungsten_rod",
		"platinum_prestige_rod",
		"neptune_rod"
	]


func _filter_changed():
	PixelUIStyle.apply_tab_button(ready_filter, ready_filter.button_pressed, 18)
	PixelUIStyle.apply_tab_button(all_filter, not ready_filter.button_pressed, 18)
	create_recipe_cards()
	recipe_scroll.scroll_vertical = 0


func _matches_filters(recipe: Dictionary) -> bool:
	if ready_filter != null and ready_filter.button_pressed and not can_craft(recipe):
		return false
	var query := search_box.text.strip_edges().to_lower() if search_box != null else ""
	var terms := get_item_display_name(recipe.output.item_id, recipe.output.category)
	for cost in recipe.cost:
		terms += " " + get_item_display_name(cost.item_id, cost.category)
	return query.is_empty() or terms.to_lower().contains(query)


func _card_label(parent: Node, node_name: String, text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.size = dimensions
	label.set_meta("pixelmania_font_size", font_size)
	PixelUIStyle.apply_label_shadow(label, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.tooltip_text = text
	parent.add_child(label)
	return label


func create_recipe_card(recipe: Dictionary, card_position: Vector2, _card_index: int):
	var can_make := can_craft(recipe)
	var output: Dictionary = recipe.output
	var card := Panel.new()
	card.name = "RecipeCard_" + str(output.item_id)
	card.position = card_position
	card.size = Vector2(RECIPE_CARD_SIZE.x, maxf(RECIPE_CARD_SIZE.y, 144 + recipe.cost.size() * 34))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("input_field"))
	recipe_root.add_child(card)
	var icon_frame := Panel.new()
	icon_frame.position = Vector2(14, 14)
	icon_frame.size = Vector2(64, 64)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(get_item_rarity(output.item_id)))
	card.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(22, 22)
	icon.size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = get_item_texture(output.item_id, output.category)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var title := _card_label(card, "Name", get_item_display_name(output.item_id, output.category), Vector2(90, 15), Vector2(360, 44), 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var status := _card_label(card, "Status", "READY TO CRAFT" if can_make else "MATERIALS NEEDED", Vector2(90, 62), Vector2(350, 24), 13)
	status.modulate = Color("99efb0") if can_make else Color("edbcb0")
	for i in range(recipe.cost.size()):
		var cost: Dictionary = recipe.cost[i]
		var owned := get_crafting_cost_inventory_count(cost.item_id, cost.category)
		var row_y := 86.0 + i * 34.0
		var ingredient := TextureRect.new()
		ingredient.position = Vector2(20, row_y)
		ingredient.size = Vector2(28, 28)
		ingredient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ingredient.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ingredient.texture = get_item_texture(cost.item_id, cost.category)
		ingredient.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ingredient)
		_card_label(card, "Ingredient%d" % i, get_item_display_name(cost.item_id, cost.category), Vector2(60, row_y), Vector2(265, 28), 17)
		var count := _card_label(card, "Count%d" % i, "%s / %s" % [format_cost_amount(owned, cost.category), format_cost_amount(cost.amount, cost.category)], Vector2(330, row_y), Vector2(120, 28), 17)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.modulate = Color("99efb0") if owned >= int(cost.amount) else Color("ffab9c")
	var button := Button.new()
	button.name = "CraftButton"
	button.text = "CRAFT ×%d" % int(output.amount) if can_make else "NEED MATERIALS"
	button.position = Vector2(16, card.size.y - 52)
	button.size = Vector2(card.size.x - 32, 38)
	button.disabled = not can_make
	apply_station_arcade_button_style(button, true, false, 17)
	button.pressed.connect(craft_recipe.bind(recipe))
	card.add_child(button)



func get_cost_text(recipe: Dictionary) -> String:
	var parts = []

	for cost in recipe["cost"]:
		var item_id = str(cost["item_id"])
		var category = str(cost["category"])
		var amount = int(cost["amount"])
		var owned = get_crafting_cost_inventory_count(item_id, category)

		parts.append(get_item_display_name(item_id, category) + " " + format_cost_amount(owned, category) + "/" + format_cost_amount(amount, category))

	return "Needs: " + "   ".join(parts)


func format_cost_amount(amount: int, category: String) -> String:
	if category == "currency" and world != null and world.has_method("format_currency_amount"):
		return world.format_currency_amount(amount)

	return str(amount)


func _set_craft_status(message: String):
	if info_label != null:
		info_label.text = message
		info_label.tooltip_text = message


func craft_recipe(recipe: Dictionary):
	if not can_craft(recipe):
		_set_craft_status("Not enough materials.")
		if world != null and world.has_method("show_notification"):
			world.show_notification("Not enough materials.")
		return

	if world != null and world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if request_server_craft(recipe):
			_set_craft_status("Crafting...")
			return
		_set_craft_status("Could not send crafting request. Check your connection and try again.")
		if world.has_method("show_notification"):
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if request_server_craft(recipe):
		_set_craft_status("Crafting...")
		return

	for cost in recipe["cost"]:
		remove_crafting_cost_item(str(cost["item_id"]), str(cost["category"]), int(cost["amount"]))

	var output = recipe["output"]
	add_inventory_item(str(output["item_id"]), str(output["category"]), int(output["amount"]))

	if world != null and world.has_method("update_all_ui"):
		world.update_all_ui()

	create_recipe_cards()
	update_header()

	if world != null and world.has_method("save_player_data"):
		world.save_player_data()

	if world != null and world.has_method("show_notification"):
		world.show_notification("Crafted " + get_item_display_name(str(output["item_id"]), str(output["category"])) + ".")


func request_server_craft(recipe: Dictionary) -> bool:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("has_active_session") and not bool(network.has_active_session()):
		return false

	if not network.has_method("send_inventory_transaction_request"):
		return false

	return bool(network.send_inventory_transaction_request({
		"action": "craft_recipe",
		"station_id": "crafting_station",
		"recipe_id": str(recipe.get("id", "")),
		"station_x": station_grid_pos.x,
		"station_y": station_grid_pos.y,
		"world": world.current_world_name if world != null else ""
	}))


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	if str(data.get("action", "")) != "craft_recipe":
		return false

	if str(data.get("station_id", "crafting_station")) != "crafting_station":
		return false

	create_recipe_cards()
	update_header()
	_set_craft_status(str(data.get("message", "Crafting finished.")))

	if world != null and world.has_method("show_notification"):
		world.show_notification(str(data.get("message", "Crafting finished.")))

	return true


func can_craft(recipe: Dictionary) -> bool:
	for cost in recipe["cost"]:
		if get_crafting_cost_inventory_count(str(cost["item_id"]), str(cost["category"])) < int(cost["amount"]):
			return false

	return true


func get_crafting_cost_item_ids(item_id: String, category: String) -> Array:
	var ids: Array = [item_id]
	if str(category) != "tool":
		return ids

	if item_id == "bamboo_rod":
		ids.append("fishing_rod")
	elif item_id == "pristine_tungsten_rod":
		ids.append("platinum_prestige_rod")

	var unique_ids: Array = []
	for candidate in ids:
		var clean_candidate := str(candidate)
		if clean_candidate != "" and not unique_ids.has(clean_candidate):
			unique_ids.append(clean_candidate)
	return unique_ids


func get_crafting_cost_inventory_count(item_id: String, category: String) -> int:
	var total := 0
	for candidate_id in get_crafting_cost_item_ids(item_id, category):
		total += get_inventory_count(str(candidate_id), category)
	return total


func remove_crafting_cost_item(item_id: String, category: String, amount: int):
	var remaining: int = max(0, amount)
	if remaining <= 0:
		return

	for candidate_id in get_crafting_cost_item_ids(item_id, category):
		var available := get_inventory_count(str(candidate_id), category)
		if available <= 0:
			continue

		var spend_amount: int = min(available, remaining)
		remove_inventory_item(str(candidate_id), category, spend_amount)
		remaining -= spend_amount
		if remaining <= 0:
			return


func get_inventory_count(item_id: String, category: String) -> int:
	if world == null:
		return 0

	if category == "block" and world.inventory.has(item_id):
		return int(world.inventory[item_id])

	if category == "seed" and world.seed_inventory.has(item_id):
		return int(world.seed_inventory[item_id])

	if category == "tool" and world.tool_inventory.has(item_id):
		return int(world.tool_inventory[item_id])

	if category == "currency" and world.currency_inventory.has(item_id):
		return int(world.currency_inventory[item_id])

	if category == "material" and world.material_inventory.has(item_id):
		return int(world.material_inventory[item_id])

	return 0


func remove_inventory_item(item_id: String, category: String, amount: int):
	if category == "block" and world.inventory.has(item_id):
		world.inventory[item_id] -= amount
	elif category == "seed" and world.seed_inventory.has(item_id):
		world.seed_inventory[item_id] -= amount
	elif category == "tool" and world.tool_inventory.has(item_id):
		world.tool_inventory[item_id] -= amount
	elif category == "currency" and world.currency_inventory.has(item_id):
		world.spend_item_from_inventory_stack(world.currency_inventory, item_id, category, amount)
	elif category == "material" and world.material_inventory.has(item_id):
		world.material_inventory[item_id] -= amount


func add_inventory_item(item_id: String, category: String, amount: int):
	if category == "block":
		if not world.inventory.has(item_id):
			world.inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.inventory, item_id, category, amount)
	elif category == "seed":
		if not world.seed_inventory.has(item_id):
			world.seed_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.seed_inventory, item_id, category, amount)
	elif category == "tool":
		if not world.tool_inventory.has(item_id):
			world.tool_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.tool_inventory, item_id, category, amount)
	elif category == "currency":
		if not world.currency_inventory.has(item_id):
			world.currency_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.currency_inventory, item_id, category, amount)
	elif category == "material":
		if not world.material_inventory.has(item_id):
			world.material_inventory[item_id] = 0
		world.add_item_to_inventory_stack(world.material_inventory, item_id, category, amount)


func get_item_texture(item_id: String, category: String):
	if world == null:
		return null

	if world.has_method("get_item_texture"):
		var icon_texture = world.get_item_texture(item_id, category)
		if icon_texture != null:
			return icon_texture

	if category == "block" and world.block_textures.has(item_id):
		return world.block_textures[item_id]

	if category == "seed" and world.seed_textures.has(item_id):
		return world.seed_textures[item_id]

	if category == "tool" and world.tool_textures.has(item_id):
		return world.tool_textures[item_id]

	if category == "currency" and world.currency_textures.has(item_id):
		return world.currency_textures[item_id]

	if category == "material" and world.material_textures.has(item_id):
		return world.material_textures[item_id]

	if world.item_database.has(item_id):
		return preload("res://Scripts/ui/recipe_book_data.gd").item_icon(world.item_database[item_id])
	return null


func get_item_display_name(item_id: String, category: String) -> String:
	if world != null and world.has_method("get_item_display_name"):
		return world.get_item_display_name(item_id, category)

	return item_id.capitalize()


func get_item_rarity(item_id: String) -> String:
	if world != null and world.item_database.has(item_id):
		return str(world.item_database[item_id].get("rarity", "common"))

	return "common"


func open_crafting(grid_pos: Vector2i):
	station_grid_pos = world.get_crafting_station_left_pos(grid_pos) if world != null and world.has_method("get_crafting_station_left_pos") else grid_pos

	if panel != null:
		panel.visible = true
		# Godot GUI hit testing follows sibling order, not visual z_index.
		panel.move_to_front()

	create_recipe_cards()
	update_header()
	PixelUIStyle.play_panel_open(panel)


func close_crafting():
	if panel != null:
		panel.visible = false


func is_crafting_open() -> bool:
	return panel != null and panel.visible


func update_header():
	if gem_label != null and world != null:
		gem_label.text = world.get_currency_display_text("gem")


func update_panel_position():
	if panel == null:
		return

	var screen_size = get_viewport_rect().size
	var fit_scale: float = minf(1.0, minf((screen_size.x - 64.0) / PANEL_SIZE.x, (screen_size.y - 96.0) / PANEL_SIZE.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit_scale)
	panel.position = (screen_size - panel.size * panel.scale) * 0.5


# Compatibility helpers kept so older code can still call them if needed.
func apply_crafting_style():
	pass


func get_slot_texture_name(_rarity: String, _selected: bool = false) -> String:
	return ""
