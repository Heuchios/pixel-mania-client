extends Node

const INVENTORY_ICON_PATH = "res://Assets/inventory_icons/"
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")
const ITEM_ATLAS_DB = preload("res://Scripts/ItemAtlasDB.gd")
const DEBUG_LOCAL_EQUIPMENT_FLOW := false
const ELECTRIC_TOOL_ITEM := "electric_tool"

var world = null


func setup(world_ref):
	world = world_ref


func get_inventory_icon_texture(item_type: String, category: String = ""):
	if world == null or item_type == "":
		return null

	var item_data = {}
	if world != null and world.item_database.has(item_type):
		item_data = world.item_database[item_type]

	var item_category: String = category
	if item_category == "" and item_data is Dictionary:
		item_category = str(item_data.get("category", ""))

	if item_category == "seed" or item_type.ends_with("_seed"):
		if world.has_method("get_seed_icon_texture"):
			var seed_icon = world.get_seed_icon_texture(item_type)
			if seed_icon != null:
				return seed_icon

	if item_category == "block":
		var atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_type)))
		if atlas_item_id > 0:
			var atlas_tile_set: TileSet = null
			if world != null and world.has_method("get_item_atlas_tile_set"):
				atlas_tile_set = world.get_item_atlas_tile_set()
			var atlas_icon := ITEM_ATLAS_DB.get_item_icon(atlas_item_id, atlas_tile_set)
			if atlas_icon != null:
				return atlas_icon

	if item_data.has("inventory_icon"):
		var explicit_icon = AtlasTextureFactory.load_texture(item_data.get("inventory_icon"))
		if explicit_icon != null:
			return explicit_icon

	var fallback_atlas_item_id := int(item_data.get("atlas_item_id", ITEM_ATLAS_DB.get_item_id_for_key(item_type)))
	if fallback_atlas_item_id > 0:
		var fallback_atlas_tile_set: TileSet = null
		if world != null and world.has_method("get_item_atlas_tile_set"):
			fallback_atlas_tile_set = world.get_item_atlas_tile_set()
		var fallback_atlas_icon := ITEM_ATLAS_DB.get_item_icon(fallback_atlas_item_id, fallback_atlas_tile_set)
		if fallback_atlas_icon != null:
			return fallback_atlas_icon

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

	if world.selected_item_category == "hat":
		return "HAT: " + display_name

	if world.selected_item_category == "hair":
		return "HAIR: " + display_name

	if world.selected_item_category == "eyewear":
		return "EYEWEAR: " + display_name

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
	if category == "back" or category == "hat" or category == "hair" or category == "eyewear" or category == "shirt" or category == "pants" or category == "shoes" or category == "ride":
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
	elif category == "hat":
		equip_hat_item(item_type)
	elif category == "hair":
		equip_hair_item(item_type)
	elif category == "eyewear":
		equip_eyewear_item(item_type)
	elif category == "shirt":
		equip_shirt_item(item_type)
	elif category == "pants":
		equip_pants_item(item_type)
	elif category == "shoes":
		equip_shoes_item(item_type)
	elif category == "ride":
		equip_ride_item(item_type)
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
	else:
		world.equipped_back_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_back_text() -> String:
	if world.equipped_back_item == "":
		return "None"

	return get_item_display_name(world.equipped_back_item, "back")


func equip_hat_item(item_type: String):
	if not world.hat_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "hat") + ".")
		return

	if int(world.hat_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "hat") + ".")
		return

	if world.equipped_hat_item == item_type:
		world.equipped_hat_item = ""
	else:
		world.equipped_hat_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_hat_text() -> String:
	if world.equipped_hat_item == "":
		return "None"

	return get_item_display_name(world.equipped_hat_item, "hat")


func equip_hair_item(item_type: String):
	if not world.hair_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "hair") + ".")
		return

	if int(world.hair_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "hair") + ".")
		return

	if world.equipped_hair_item == item_type:
		world.equipped_hair_item = ""
	else:
		world.equipped_hair_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_hair_text() -> String:
	if world.equipped_hair_item == "":
		return "None"

	return get_item_display_name(world.equipped_hair_item, "hair")


func equip_eyewear_item(item_type: String):
	if not world.eyewear_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "eyewear") + ".")
		return

	if int(world.eyewear_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "eyewear") + ".")
		return

	if world.equipped_eyewear_item == item_type:
		world.equipped_eyewear_item = ""
	else:
		world.equipped_eyewear_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_eyewear_text() -> String:
	if world.equipped_eyewear_item == "":
		return "None"

	return get_item_display_name(world.equipped_eyewear_item, "eyewear")


func equip_shirt_item(item_type: String):
	if not world.shirt_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "shirt") + ".")
		return

	if int(world.shirt_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "shirt") + ".")
		return

	if world.equipped_shirt_item == item_type:
		world.equipped_shirt_item = ""
	else:
		world.equipped_shirt_item = item_type

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
	else:
		world.equipped_pants_item = item_type

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
	else:
		world.equipped_shoes_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_shoes_text() -> String:
	if world.equipped_shoes_item == "":
		return "None"

	return get_item_display_name(world.equipped_shoes_item, "shoes")


func equip_ride_item(item_type: String):
	if not world.ride_inventory.has(item_type):
		world.show_notification("You do not have " + get_item_display_name(item_type, "ride") + ".")
		return

	if int(world.ride_inventory[item_type]) <= 0:
		world.show_notification("You do not have " + get_item_display_name(item_type, "ride") + ".")
		return

	if world.equipped_ride_item == item_type:
		world.equipped_ride_item = ""
	else:
		world.equipped_ride_item = item_type

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()


func get_equipped_ride_text() -> String:
	if world.equipped_ride_item == "":
		return "None"

	return get_item_display_name(world.equipped_ride_item, "ride")


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
	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()
	hide_electrical_layer_if_tool_not_equipped()
	request_electrical_visibility_if_tool_equipped()


func unequip_tool():
	if world.equipped_tool == "":
		return

	world.equipped_tool = ""

	world.update_equipment_visual()
	world.update_all_ui()
	save_equipment_state()
	hide_electrical_layer_if_tool_not_equipped()


func get_equipped_tool_text() -> String:
	if world.equipped_tool == "":
		return "None"

	return get_item_display_name(world.equipped_tool, "tool")


func hide_electrical_layer_if_tool_not_equipped():
	if world == null:
		return
	if str(world.equipped_tool).strip_edges() == ELECTRIC_TOOL_ITEM:
		return
	if world.has_method("apply_network_wire_visibility_refresh"):
		world.apply_network_wire_visibility_refresh({
			"visible": false,
			"electrical_layer": [],
			"generator_links": [],
			"oil_refinery_links": [],
			"battery_charger_links": [],
			"pole_links": []
		})


func request_electrical_visibility_if_tool_equipped():
	if world == null:
		return
	if str(world.equipped_tool).strip_edges() != ELECTRIC_TOOL_ITEM:
		return
	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_request_wire_visibility_refresh"):
		network.send_request_wire_visibility_refresh(str(world.current_world_name))


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
	if (world.has_method("is_world_lock_block_type") and world.is_world_lock_block_type(block_type)) or block_type == "vend_empty" or block_type == "safe" or block_type == "fish_monger":
		return true
	if world.item_database.has(block_type):
		var block_data: Dictionary = world.item_database[block_type]
		if bool(block_data.get("drops_self", false)):
			return true
		if float(block_data.get("shop_price", 0)) > 0.0:
			return true
	return false


func get_fixed_break_drop_amount(fixed_drop: Dictionary) -> int:
	var amount_range = fixed_drop.get("amount_range", fixed_drop.get("amountRange", []))
	if amount_range is Array and amount_range.size() >= 2:
		var first_amount = int(clamp(int(amount_range[0]), 0, world.MAX_ITEM_STACK_SIZE))
		var second_amount = int(clamp(int(amount_range[1]), 0, world.MAX_ITEM_STACK_SIZE))
		var min_amount = min(first_amount, second_amount)
		var max_amount = max(first_amount, second_amount)
		return randi_range(min_amount, max_amount)

	return int(clamp(int(fixed_drop.get("amount", 1)), 1, world.MAX_ITEM_STACK_SIZE))


func get_fixed_break_drop_category(item_id: String, requested_category: String) -> String:
	var category = requested_category.strip_edges()
	if category != "":
		return category
	if world.item_database.has(item_id):
		return str(world.item_database[item_id].get("category", ""))
	if item_id.ends_with("_seed"):
		return "seed"
	return "block"


func get_break_drop_from_rule_entry(rule_entry: Dictionary) -> Dictionary:
	var item_id: String = str(rule_entry.get("item_id", rule_entry.get("item_type", ""))).strip_edges()
	if item_id == "" or not world.item_database.has(item_id):
		return {}

	var item_category: String = get_fixed_break_drop_category(
		item_id,
		str(rule_entry.get("item_category", rule_entry.get("category", "")))
	)
	if item_category == "":
		return {}

	var amount: int = get_fixed_break_drop_amount(rule_entry)
	if amount <= 0:
		return {}

	return {
		"item_id": item_id,
		"item_category": item_category,
		"amount": amount
	}


func roll_weighted_break_drop(loot_table: Array) -> Dictionary:
	var candidates: Array = []
	var total_weight: float = 0.0

	for raw_entry in loot_table:
		if not (raw_entry is Dictionary):
			continue

		var entry: Dictionary = raw_entry as Dictionary
		var drop: Dictionary = get_break_drop_from_rule_entry(entry)
		if drop.is_empty():
			continue

		var weight: float = max(0.0, float(entry.get("weight", 0.0)))
		if weight <= 0.0:
			continue

		total_weight += weight
		candidates.append({
			"drop": drop,
			"weight": weight
		})

	if total_weight <= 0.0 or candidates.is_empty():
		return {}

	var roll: float = randf() * total_weight
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate as Dictionary
		var candidate_weight: float = float(candidate.get("weight", 0.0))
		roll -= candidate_weight
		if roll < 0.0:
			var selected_drop = candidate.get("drop", {})
			if selected_drop is Dictionary:
				return selected_drop as Dictionary
			return {}

	var final_candidate: Dictionary = candidates[candidates.size() - 1] as Dictionary
	var final_drop = final_candidate.get("drop", {})
	if final_drop is Dictionary:
		return final_drop as Dictionary
	return {}


func try_drop_fixed_break_drops(block_type: String, drop_position: Vector2) -> bool:
	if not world.item_database.has(block_type):
		return false

	var block_data: Dictionary = world.item_database[block_type]
	var rules = block_data.get("drop_rules", {})
	if not (rules is Dictionary):
		return false

	var raw_loot_table = rules.get("loot_table", rules.get("weighted_drops", []))
	if raw_loot_table is Array:
		var loot_table: Array = raw_loot_table as Array
		var weighted_drop: Dictionary = roll_weighted_break_drop(loot_table)
		if not weighted_drop.is_empty():
			world.create_item_drop(
				str(weighted_drop.get("item_id", "")),
				drop_position,
				str(weighted_drop.get("item_category", "")) == "seed",
				str(weighted_drop.get("item_category", "")),
				0.0,
				int(weighted_drop.get("amount", 1))
			)
		return true

	var fixed_drops: Variant = rules.get("fixed_drops", [])
	if not (fixed_drops is Array):
		return false

	for fixed_drop in fixed_drops:
		if not (fixed_drop is Dictionary):
			continue

		var drop_chance: float = clamp(float(fixed_drop.get("chance", 1.0)), 0.0, 1.0)
		if randf() > drop_chance:
			continue

		var item_id: String = str(fixed_drop.get("item_id", fixed_drop.get("item_type", ""))).strip_edges()
		if item_id == "" or not world.item_database.has(item_id):
			continue

		var item_category: String = get_fixed_break_drop_category(
			item_id,
			str(fixed_drop.get("item_category", fixed_drop.get("category", "")))
		)
		if item_category == "":
			continue

		var amount: int = get_fixed_break_drop_amount(fixed_drop)
		if amount <= 0:
			continue

		world.create_item_drop(item_id, drop_position, item_category == "seed", item_category, 0.0, amount)

	return true


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

	if category == "hat" and world.hat_textures.has(item_type):
		return world.hat_textures[item_type]

	if category == "hair" and world.hair_textures.has(item_type):
		return world.hair_textures[item_type]

	if category == "eyewear" and world.eyewear_textures.has(item_type):
		return world.eyewear_textures[item_type]

	if category == "shirt" and world.shirt_textures.has(item_type):
		return world.shirt_textures[item_type]

	if category == "pants" and world.pants_textures.has(item_type):
		return world.pants_textures[item_type]

	if category == "shoes" and world.shoes_textures.has(item_type):
		return world.shoes_textures[item_type]

	if category == "ride" and world.ride_textures.has(item_type):
		return world.ride_textures[item_type]

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

	if category == "hat" and world.hat_inventory.has(item_type):
		return int(world.hat_inventory[item_type])

	if category == "hair" and world.hair_inventory.has(item_type):
		return int(world.hair_inventory[item_type])

	if category == "eyewear" and world.eyewear_inventory.has(item_type):
		return int(world.eyewear_inventory[item_type])

	if category == "shirt" and world.shirt_inventory.has(item_type):
		return int(world.shirt_inventory[item_type])

	if category == "pants" and world.pants_inventory.has(item_type):
		return int(world.pants_inventory[item_type])

	if category == "shoes" and world.shoes_inventory.has(item_type):
		return int(world.shoes_inventory[item_type])

	if category == "ride" and world.ride_inventory.has(item_type):
		return int(world.ride_inventory[item_type])

	if category == "material" and world.material_inventory.has(item_type):
		return int(world.material_inventory[item_type])

	if category == "lure" and world.lure_inventory.has(item_type):
		return int(world.lure_inventory[item_type])

	if category == "fish" and world.fish_inventory.has(item_type):
		return max(0, int(floor(float(world.fish_inventory[item_type]))))

	if category == "currency" and world.currency_inventory.has(item_type):
		return int(world.currency_inventory[item_type])

	return 0


func save_equipment_state():
	if DEBUG_LOCAL_EQUIPMENT_FLOW:
		print("[APPEARANCE][Client] local equipment changed ", get_local_equipment_debug_snapshot())
	if world != null and world.has_method("save_player_data"):
		world.save_player_data()
	if world != null and world.has_method("flush_multiplayer_position"):
		world.flush_multiplayer_position(false, true)


func get_local_equipment_debug_snapshot() -> Dictionary:
	if world == null:
		return {}

	return {
		"hand": str(world.equipped_tool),
		"back": str(world.equipped_back_item),
		"hat": str(world.equipped_hat_item),
		"hair": str(world.equipped_hair_item),
		"eyewear": str(world.equipped_eyewear_item),
		"shirt": str(world.equipped_shirt_item),
		"pants": str(world.equipped_pants_item),
		"shoes": str(world.equipped_shoes_item),
		"ride": str(world.equipped_ride_item)
	}


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
	if world.has_method("save_player_data"):
		world.save_player_data()
