extends Node

const INVENTORY_ICON_PATH = "res://Assets/inventory_icons/"
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

var world = null


func setup(world_ref):
	world = world_ref


func get_inventory_icon_texture(item_type: String, category: String = ""):
	if world == null or item_type == "":
		return null

	var item_data = {}
	if world != null and world.item_database.has(item_type):
		item_data = world.item_database[item_type]

	if item_data.has("inventory_icon"):
		var explicit_icon = AtlasTextureFactory.load_texture(item_data.get("inventory_icon"))
		if explicit_icon != null:
			return explicit_icon

	var icon_paths = get_inventory_icon_candidates(item_type, category)

	for icon_path in icon_paths:
		if ResourceLoader.exists(icon_path):
			return load(icon_path)

	return null


func get_inventory_icon_candidates(item_type: String, category: String = "") -> Array:
	var candidates = []
	var item_data = {}

	if world != null and world.item_database.has(item_type):
		item_data = world.item_database[item_type]

	var explicit_icon_spec = item_data.get("inventory_icon", "")
	var explicit_icon = AtlasTextureFactory.get_source_path(explicit_icon_spec)
	if explicit_icon != "":
		candidates.append(explicit_icon)

	candidates.append(INVENTORY_ICON_PATH + item_type + ".png")

	var animation_frames = item_data.get("animation_frames", [])
	if animation_frames is Array and animation_frames.size() > 0:
		var frame_file = AtlasTextureFactory.get_source_path(animation_frames[0]).get_file()
		if frame_file != "":
			candidates.append(INVENTORY_ICON_PATH + frame_file)

	var texture_path = AtlasTextureFactory.get_source_path(item_data.get("texture", ""))
	if texture_path != "":
		var texture_file = texture_path.get_file()
		if texture_file != "":
			candidates.append(INVENTORY_ICON_PATH + texture_file)

	if category == "block":
		candidates.append(INVENTORY_ICON_PATH + item_type + "_block.png")

	return candidates


func select_item(item_type: String, category: String):
	world.selected_item_type = item_type
	world.selected_item_category = category
	world.update_all_ui()


func get_selected_item_text() -> String:
	if world.selected_item_category == "tool":
		return get_item_display_name(world.selected_item_type, world.selected_item_category).to_upper()

	var display_name = get_item_display_name(world.selected_item_type, world.selected_item_category).to_upper()

	if world.selected_item_category == "seed":
		return "SEED: " + display_name

	if world.selected_item_category == "material":
		return "MATERIAL: " + display_name

	if world.selected_item_category == "back":
		return "BACK: " + display_name

	if world.selected_item_category == "hair":
		return "HAIR: " + display_name

	if world.selected_item_category == "shirt":
		return "SHIRT: " + display_name

	if world.selected_item_category == "pants":
		return "PANTS: " + display_name

	if world.selected_item_category == "lure":
		return "LURE: " + display_name

	if world.selected_item_category == "fish":
		return "FISH: " + display_name

	return "BLOCK: " + display_name


func get_current_break_power(block_type: String = "") -> int:
	if world.equipped_tool != "" and world.item_database.has(world.equipped_tool):
		var tool_data = world.item_database[world.equipped_tool]
		var base_power = int(tool_data.get("break_power", 1))
		var effective_power = int(tool_data.get("effective_break_power", base_power))
		var effective_blocks = tool_data.get("effective_blocks", [])

		if block_type != "" and effective_blocks is Array and effective_blocks.has(block_type):
			return effective_power

		return base_power

	return 1


func get_current_break_hit_reduction() -> int:
	if world == null:
		return 0

	var equipped_tool := str(world.get("equipped_tool")).strip_edges()
	if equipped_tool == "" or not world.item_database.has(equipped_tool):
		return 0

	var tool_data: Variant = world.item_database[equipped_tool]
	if not (tool_data is Dictionary):
		return 0

	return maxi(0, int((tool_data as Dictionary).get("break_hit_reduction", 0)))


func get_required_break_hits(_block_type: String, base_max_hits: int) -> int:
	return maxi(1, base_max_hits - get_current_break_hit_reduction())


func is_item_equipable(item_type: String, category: String) -> bool:
	if item_type == "" or category == "" or category == "empty":
		return false
	if item_type == "punch":
		return false
	if get_item_count(item_type, category) <= 0:
		return false
	if category == "back" or category == "hair" or category == "shirt" or category == "pants" or category == "shoes":
		return true
	if category == "tool":
		if world.item_database.has(item_type):
			return bool(world.item_database[item_type].get("equipable", true))
		return true
	if world.item_database.has(item_type):
		var item_data = world.item_database[item_type]
		return bool(item_data.get("equipable", false)) and str(item_data.get("equipment_slot", "")) != ""
	return false


func toggle_equip_item(item_type: String, category: String):
	if not is_item_equipable(item_type, category):
		world.show_notification(get_item_display_name(item_type, category) + " cannot be equipped.")
		return

	if category == "tool":
		equip_tool(item_type)
	elif category == "back":
		equip_back_item(item_type)
	elif category == "hair":
		equip_hair_item(item_type)
	elif category == "shirt":
		equip_shirt_item(item_type)
	elif category == "pants":
		equip_pants_item(item_type)
	elif category == "shoes":
		equip_shoes_item(item_type)
	else:
		world.show_notification(get_item_display_name(item_type, category) + " cannot be equipped yet.")


func equip_back_item(item_type: String):
	if not world.back_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "back") + ".")
		return

	if int(world.back_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "back") + ".")
		return

	if world.equipped_back_item == item_type:
		world.equipped_back_item = ""
		world.show_notification("Unequipped " + get_item_display_name(item_type, "back") + ".")
	else:
		world.equipped_back_item = item_type
		world.show_notification("Equipped " + get_item_display_name(item_type, "back") + ".")

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_back_text() -> String:
	if world.equipped_back_item == "":
		return "None"

	return get_item_display_name(world.equipped_back_item, "back")


func equip_hair_item(item_type: String):
	if not world.hair_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "hair") + ".")
		return

	if int(world.hair_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "hair") + ".")
		return

	if world.equipped_hair_item == item_type:
		world.equipped_hair_item = ""
		world.show_notification("Unequipped " + get_item_display_name(item_type, "hair") + ".")
	else:
		world.equipped_hair_item = item_type
		world.show_notification("Equipped " + get_item_display_name(item_type, "hair") + ".")

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_hair_text() -> String:
	if world.equipped_hair_item == "":
		return "None"

	return get_item_display_name(world.equipped_hair_item, "hair")


func equip_shirt_item(item_type: String):
	if not world.shirt_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "shirt") + ".")
		return

	if int(world.shirt_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "shirt") + ".")
		return

	if world.equipped_shirt_item == item_type:
		world.equipped_shirt_item = ""
		world.show_notification("Unequipped " + get_item_display_name(item_type, "shirt") + ".")
	else:
		world.equipped_shirt_item = item_type
		world.show_notification("Equipped " + get_item_display_name(item_type, "shirt") + ".")

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_shirt_text() -> String:
	if world.equipped_shirt_item == "":
		return "None"

	return get_item_display_name(world.equipped_shirt_item, "shirt")


func equip_pants_item(item_type: String):
	if not world.pants_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "pants") + ".")
		return

	if int(world.pants_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "pants") + ".")
		return

	if world.equipped_pants_item == item_type:
		world.equipped_pants_item = ""
		world.show_notification("Unequipped " + get_item_display_name(item_type, "pants") + ".")
	else:
		world.equipped_pants_item = item_type
		world.show_notification("Equipped " + get_item_display_name(item_type, "pants") + ".")

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_pants_text() -> String:
	if world.equipped_pants_item == "":
		return "None"

	return get_item_display_name(world.equipped_pants_item, "pants")


func equip_shoes_item(item_type: String):
	if not world.shoes_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "shoes") + ".")
		return

	if int(world.shoes_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "shoes") + ".")
		return

	if world.equipped_shoes_item == item_type:
		world.equipped_shoes_item = ""
		world.show_notification("Unequipped " + get_item_display_name(item_type, "shoes") + ".")
	else:
		world.equipped_shoes_item = item_type
		world.show_notification("Equipped " + get_item_display_name(item_type, "shoes") + ".")

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_shoes_text() -> String:
	if world.equipped_shoes_item == "":
		return "None"

	return get_item_display_name(world.equipped_shoes_item, "shoes")


func equip_tool(item_type: String):
	if not world.tool_inventory.has(item_type):
		return

	if int(world.tool_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "tool") + ".")
		return

	if world.item_database.has(item_type) and not bool(world.item_database[item_type].get("equipable", true)):
		world.show_notification(get_item_display_name(item_type, "tool") + " is used from inventory/hotbar.")
		return

	if world.equipped_tool == item_type:
		unequip_tool()
		return

	world.equipped_tool = item_type
	world.show_notification("Equipped " + get_item_display_name(item_type, "tool") + ".")
	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func unequip_tool():
	if world.equipped_tool == "":
		return

	var old_tool_name = get_item_display_name(world.equipped_tool, "tool")
	world.equipped_tool = ""

	world.show_notification("Unequipped " + old_tool_name + ".")
	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_tool_text() -> String:
	if world.equipped_tool == "":
		return "None"

	return get_item_display_name(world.equipped_tool, "tool")


func get_gem_drop_range_for_rarity(rarity: String) -> Vector2i:
	match rarity.to_lower():
		"common":
			return Vector2i(0, 1)
		"uncommon":
			return Vector2i(1, 3)
		"rare":
			return Vector2i(2, 6)
		"epic":
			return Vector2i(5, 12)
		"legendary":
			return Vector2i(15, 40)
		_:
			return Vector2i(0, 1)


func get_block_drop_chance_for_rarity(rarity: String) -> float:
	match rarity.to_lower():
		"uncommon":
			return 0.8
		"rare":
			return 0.65
		"epic":
			return 0.45
		"legendary":
			return 0.25
		_:
			return 0.9


func get_seed_drop_chance_for_rarity(rarity: String) -> float:
	match rarity.to_lower():
		"uncommon":
			return 0.6
		"rare":
			return 0.4
		"epic":
			return 0.2
		"legendary":
			return 0.1
		_:
			return 0.8


func get_block_rarity(block_type: String) -> String:
	if world.item_database.has(block_type):
		return str(world.item_database[block_type].get("rarity", "common"))

	return "common"


func should_always_return_block_on_break(block_type: String) -> bool:
	if block_type == "crafting_station" or block_type == "furnace":
		return true
	if block_type == "world_lock" or block_type == "vend_empty" or block_type == "safe" or block_type == "fish_monger":
		return true
	if world.item_database.has(block_type):
		var block_data: Dictionary = world.item_database[block_type]
		if float(block_data.get("shop_price", 0)) > 0.0:
			return true
	return false


func try_drop_block(block_type: String, drop_position: Vector2):
	if not world.item_database.has(block_type):
		return

	var block_data: Dictionary = world.item_database[block_type]
	if bool(block_data.get("hidden", false)):
		return
	if not bool(block_data.get("dropable", true)):
		return

	if should_always_return_block_on_break(block_type) or randf() <= get_block_drop_chance_for_rarity(get_block_rarity(block_type)):
		world.spawn_item_drop(block_type, drop_position, false)


func try_drop_gems(block_type: String, drop_position: Vector2):
	if not world.currency_inventory.has("gem"):
		return

	if world.item_database.has(block_type) and world.item_database[block_type].has("drop_gems") and not bool(world.item_database[block_type].get("drop_gems", true)):
		return

	if randf() > world.GEM_DROP_CHANCE:
		return

	var rarity = get_block_rarity(block_type)
	var gem_range = get_gem_drop_range_for_rarity(rarity)
	var gem_amount = randi_range(gem_range.x, gem_range.y)

	if gem_amount <= 0:
		return

	world.create_item_drop("gem", drop_position, false, "currency", 0.0, gem_amount)


func try_drop_seed(block_type: String, drop_position: Vector2):
	var seed_name = world.get_seed_for_block(block_type)

	if not world.seed_inventory.has(seed_name):
		return

	if randf() <= get_seed_drop_chance_for_rarity(get_block_rarity(block_type)):
		world.spawn_item_drop(seed_name, drop_position, true)


func get_front_drop_grid_position() -> Vector2i:
	var player_grid_pos = world.get_player_grid_position()

	return Vector2i(
		player_grid_pos.x + world.player_facing_direction,
		player_grid_pos.y
	)


func get_front_drop_world_position() -> Vector2:
	var drop_grid_pos = get_front_drop_grid_position()

	return Vector2(
		drop_grid_pos.x * world.BLOCK_SIZE,
		drop_grid_pos.y * world.BLOCK_SIZE
	)


func drop_inventory_item_to_world(item_type: String, category: String) -> bool:
	if world.drop_manager != null and world.drop_manager.has_method("drop_inventory_item_to_world"):
		return bool(world.drop_manager.drop_inventory_item_to_world(item_type, category))
	return false


func drop_inventory_item_stack_to_world(item_type: String, category: String, amount: float) -> bool:
	if world.drop_manager != null and world.drop_manager.has_method("drop_inventory_item_stack_to_world"):
		return bool(world.drop_manager.drop_inventory_item_stack_to_world(item_type, category, amount))
	return false


func get_item_texture(item_type: String, category: String):
	var icon_texture = get_inventory_icon_texture(item_type, category)
	if icon_texture != null:
		return icon_texture

	if world.drop_manager != null and world.drop_manager.has_method("get_item_drop_texture"):
		return world.drop_manager.get_item_drop_texture(item_type, category)

	if category == "block" and world.block_textures.has(item_type):
		return world.block_textures[item_type]

	if category == "seed" and world.seed_textures.has(item_type):
		return world.seed_textures[item_type]

	if category == "tool" and world.tool_textures.has(item_type):
		return world.tool_textures[item_type]

	if category == "hair" and world.hair_textures.has(item_type):
		return world.hair_textures[item_type]

	if category == "shirt" and world.shirt_textures.has(item_type):
		return world.shirt_textures[item_type]

	if category == "pants" and world.pants_textures.has(item_type):
		return world.pants_textures[item_type]

	if category == "shoes" and world.shoes_textures.has(item_type):
		return world.shoes_textures[item_type]

	if world.item_database.has(item_type):
		var texture = AtlasTextureFactory.load_texture(world.item_database[item_type].get("texture", null))
		if texture != null:
			return texture

	return null


func get_item_count(item_type: String, category: String) -> int:
	if category == "block" and world.inventory.has(item_type):
		return int(world.inventory[item_type])

	if category == "seed" and world.seed_inventory.has(item_type):
		return int(world.seed_inventory[item_type])

	if category == "tool" and world.tool_inventory.has(item_type):
		return int(world.tool_inventory[item_type])

	if category == "back" and world.back_inventory.has(item_type):
		return int(world.back_inventory[item_type])

	if category == "hair" and world.hair_inventory.has(item_type):
		return int(world.hair_inventory[item_type])

	if category == "shirt" and world.shirt_inventory.has(item_type):
		return int(world.shirt_inventory[item_type])

	if category == "pants" and world.pants_inventory.has(item_type):
		return int(world.pants_inventory[item_type])

	if category == "shoes" and world.shoes_inventory.has(item_type):
		return int(world.shoes_inventory[item_type])

	if category == "material" and world.material_inventory.has(item_type):
		return int(world.material_inventory[item_type])

	if category == "lure" and world.lure_inventory.has(item_type):
		return int(world.lure_inventory[item_type])

	if category == "fish" and world.fish_inventory.has(item_type):
		return int(ceil(max(0.0, float(world.fish_inventory[item_type]))))

	if category == "currency" and world.currency_inventory.has(item_type):
		return int(world.currency_inventory[item_type])

	return 0


func save_equipment_state():
	if world != null and world.has_method("save_player_data"):
		world.save_player_data()


func get_item_display_name(item_type: String, category: String) -> String:
	if category == "tool" and item_type == "punch":
		return "Punch"

	if category == "tool" and item_type == "wrench":
		return "Wrench"

	if world.item_database.has(item_type):
		return str(world.item_database[item_type].get("display_name", item_type.capitalize()))

	if category == "seed":
		return item_type.replace("_seed", "").capitalize() + " Seed"

	return item_type.capitalize()


func get_primary_hotbar_tool() -> String:
	if world.primary_hotbar_tool != "punch" and world.primary_hotbar_tool != "wrench":
		world.primary_hotbar_tool = "punch"

	return world.primary_hotbar_tool


func toggle_primary_hotbar_tool():
	if world.primary_hotbar_tool == "punch":
		world.primary_hotbar_tool = "wrench"
	else:
		world.primary_hotbar_tool = "punch"

	if world.hotbar_items.size() > 0:
		world.hotbar_items[0] = world.primary_hotbar_tool

	if world.hotbar_item_categories.size() > 0:
		world.hotbar_item_categories[0] = "tool"

	# Rebuild hotbar so the first slot icon changes between Punch and Wrench.
	world.setup_hotbar()

	select_item(world.primary_hotbar_tool, "tool")
	world.show_notification("Mode: " + get_item_display_name(world.primary_hotbar_tool, "tool"))
