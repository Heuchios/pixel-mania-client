extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const StationRecipes = preload("res://Scripts/station_recipes.gd")

const PANEL_SIZE = Vector2(1080, 620)
const RECIPE_ROOT_WIDTH = 960.0
const RECIPE_ROOT_MIN_HEIGHT = 376.0
const RECIPE_CARD_SIZE = Vector2(304, 154)
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
	return PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 4, 18, 13)


func station_header_style():
	return PixelUIStyle.style_box(PixelUIStyle.GLASS_HEADER, PixelUIStyle.GLASS_BORDER, 0, 12, 7)


func station_section_style():
	return PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 13, 6)


func station_chip_style():
	return PixelUIStyle.style_box(Color(0.10, 0.24, 0.34, 0.58), PixelUIStyle.GLASS_BORDER_BRIGHT, 3, 14, 8)


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

	var fill = Color(0.18, 0.32, 0.43, 0.42)
	var border = Color(0.72, 0.92, 1.0, 0.46)
	if can_make:
		fill = Color(0.36, 0.30, 0.10, 0.56)
		border = Color(1.0, 0.82, 0.18, 0.88)

	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(fill, border, 4, 8, 7))


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
	far_shadow.name = "FarShadow"
	far_shadow.position = Vector2(10, 12)
	far_shadow.size = panel.size
	far_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.0, 0.0, 0.0, 0.28), Color(0.0, 0.0, 0.0, 0.0), 0, 18, 0))
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
	header_gloss.color = Color(1.0, 1.0, 1.0, 0.055)
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
	PixelUIStyle.apply_label_shadow(title, 42)
	panel.add_child(title)

	var title_sub = Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "RECIPES"
	title_sub.position = Vector2(42, 66)
	title_sub.size = Vector2(210, 20)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	panel.add_child(title_sub)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(panel.size.x - 76.0, 20)
	close_button.size = Vector2(52, 48)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_station_arcade_button_style(close_button, false, true, 24)
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

	var info_card = Panel.new()
	info_card.name = "InfoCard"
	info_card.position = Vector2(32, 112)
	info_card.size = Vector2(panel.size.x - 64.0, 52)
	info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.add_theme_stylebox_override("panel", station_section_style())
	panel.add_child(info_card)

	var section_label = Label.new()
	section_label.name = "SectionLabel"
	section_label.text = "AVAILABLE RECIPES"
	section_label.position = Vector2(50, 125)
	section_label.size = Vector2(340, 28)
	section_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_section_title(section_label, 22)
	panel.add_child(section_label)

	info_label = Label.new()
	info_label.name = "Info"
	info_label.text = "Craft tools, stations, equipment, and special recipes."
	info_label.position = Vector2(386, 126)
	info_label.size = Vector2(620, 26)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(info_label, 14)
	panel.add_child(info_label)

	var recipe_area = Panel.new()
	recipe_area.name = "RecipeArea"
	recipe_area.position = Vector2(32, 178)
	recipe_area.size = Vector2(panel.size.x - 64.0, panel.size.y - 208.0)
	recipe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_area.add_theme_stylebox_override("panel", station_section_style())
	panel.add_child(recipe_area)

	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.position = Vector2(48, 194)
	recipe_scroll.size = Vector2(panel.size.x - 96.0, panel.size.y - 240.0)
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
	var columns = 3
	var rows = int(ceil(float(visible_recipes.size()) / float(columns)))
	var content_height = max(RECIPE_ROOT_MIN_HEIGHT, rows * RECIPE_CARD_SIZE.y + max(0, rows - 1) * RECIPE_CARD_GAP.y)

	recipe_root.size = Vector2(RECIPE_ROOT_WIDTH, content_height)
	recipe_root.custom_minimum_size = Vector2(RECIPE_ROOT_WIDTH, content_height)

	for i in range(visible_recipes.size()):
		var recipe = visible_recipes[i]
		var column = i % columns
		var row = int(floor(float(i) / float(columns)))
		create_recipe_card(recipe, Vector2(column * (RECIPE_CARD_SIZE.x + RECIPE_CARD_GAP.x), row * (RECIPE_CARD_SIZE.y + RECIPE_CARD_GAP.y)), i)


func get_visible_recipes() -> Array:
	var visible_recipes: Array = []

	for recipe in recipes:
		if should_show_recipe(recipe):
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


func create_recipe_card(recipe: Dictionary, card_position: Vector2, _card_index: int):
	var can_make = can_craft(recipe)

	var output = recipe["output"]
	var output_id = str(output["item_id"])
	var output_category = str(output["category"])
	var output_amount = int(output["amount"])
	var rarity = get_item_rarity(output_id)

	var card = Panel.new()
	card.name = "RecipeCard_" + output_id
	card.position = card_position
	card.size = RECIPE_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_station_card_style(card, can_make)
	recipe_root.add_child(card)

	var ready_strip = ColorRect.new()
	ready_strip.name = "ReadyStrip"
	ready_strip.position = Vector2(8, 8)
	ready_strip.size = Vector2(card.size.x - 16.0, 5)
	ready_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if can_make:
		ready_strip.color = Color(0.28, 1.0, 0.42, 0.76)
	else:
		ready_strip.color = Color(0.80, 0.20, 0.16, 0.65)

	card.add_child(ready_strip)

	var icon_back = Panel.new()
	icon_back.name = "IconBack"
	icon_back.position = Vector2(12, 22)
	icon_back.size = Vector2(78, 78)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	card.add_child(icon_back)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(23, 33)
	icon.size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = get_item_texture(output_id, output_category)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = get_item_display_name(output_id, output_category) + " x" + str(output_amount)
	name_label.position = Vector2(104, 18)
	name_label.size = Vector2(186, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 17)
	card.add_child(name_label)

	var status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(104, 46)
	status_label.size = Vector2(186, 20)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if can_make:
		status_label.text = "READY"
		PixelUIStyle.apply_small_label(status_label, 13)
	else:
		status_label.text = "MISSING MATERIALS"
		PixelUIStyle.apply_label_shadow(status_label, 13, Color(1.0, 0.58, 0.50, 1.0))

	card.add_child(status_label)

	var cost_label = Label.new()
	cost_label.name = "Cost"
	cost_label.text = get_cost_text(recipe)
	cost_label.position = Vector2(104, 68)
	cost_label.size = Vector2(186, 34)
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label.clip_text = true
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(cost_label, 11)
	card.add_child(cost_label)

	var craft_button = Button.new()
	craft_button.name = "CraftButton"
	craft_button.text = "CRAFT" if can_make else "MISSING"
	craft_button.position = Vector2(10, card.size.y - 42.0)
	craft_button.size = Vector2(card.size.x - 20.0, 34)
	craft_button.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_button.disabled = not can_make
	apply_station_arcade_button_style(craft_button, true, false, 16)

	craft_button.pressed.connect(craft_recipe.bind(recipe))
	card.add_child(craft_button)


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


func craft_recipe(recipe: Dictionary):
	if not can_craft(recipe):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Not enough materials.")
		return

	if world != null and world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions()):
		if request_server_craft(recipe):
			return
		if world.has_method("show_notification"):
			world.show_notification("Almost ready. Try again in a moment.")
		return

	if request_server_craft(recipe):
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
	station_grid_pos = grid_pos

	if panel != null:
		panel.visible = true

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
	panel.position = Vector2(
		(screen_size.x - panel.size.x) / 2.0,
		max(40.0, (screen_size.y - panel.size.y) / 2.0)
	)


# Compatibility helpers kept so older code can still call them if needed.
func apply_crafting_style():
	pass


func get_slot_texture_name(_rarity: String, _selected: bool = false) -> String:
	return ""
