extends Node

const FISH_MONGER_ID = "fish_monger"

var world = null
var current_grid: Vector2i = Vector2i(999999, 999999)
var pending_transaction := false


func setup(world_ref):
	world = world_ref


func is_fish_monger_block(block_type: String) -> bool:
	return block_type == FISH_MONGER_ID


func open_fish_monger(grid_pos: Vector2i):
	if world == null:
		return

	if not world.blocks.has(grid_pos) or not is_fish_monger_block(str(world.blocks[grid_pos].get("type", ""))):
		world.show_notification("Fish Monger is not here.")
		return

	current_grid = grid_pos

	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("open_fish_monger"):
		world.fish_monger_ui.open_fish_monger(grid_pos)


func get_network_manager():
	if world == null:
		return null

	return world.get_node_or_null("/root/NetworkManager")


func has_server_inventory_authority() -> bool:
	var network = get_network_manager()
	if network == null:
		return false

	if network.has_method("is_connected_to_server") and not bool(network.is_connected_to_server()):
		return false

	if network.has_method("has_active_session") and not bool(network.has_active_session()):
		return false

	return network.has_method("send_inventory_transaction_request")


func is_valid_fish_item(item_id: String) -> bool:
	if world == null or item_id == "":
		return false

	if not world.item_database.has(item_id):
		return false

	return str(world.item_database[item_id].get("category", "")) == "fish"


func get_fish_sell_value(item_id: String) -> int:
	if not is_valid_fish_item(item_id):
		return 0

	var item_data = world.item_database[item_id]

	if item_data.has("sell_price_per_lb"):
		return max(0, int(item_data.get("sell_price_per_lb", 0)))

	if item_data.has("price_per_lb"):
		return max(0, int(item_data.get("price_per_lb", 0)))

	if item_data.has("sell_value"):
		return max(0, int(item_data.get("sell_value", 0)))

	if item_data.has("fish_sell_value"):
		return max(0, int(item_data.get("fish_sell_value", 0)))

	if item_data.has("sell_price"):
		return max(0, int(item_data.get("sell_price", 0)))

	match str(item_data.get("rarity", "common")):
		"legendary":
			return 1000
		"epic":
			return 300
		"rare":
			return 125
		"uncommon":
			return 50
		_:
			return 25


func get_fish_weight_lb(item_id: String) -> float:
	if world == null or not world.fish_inventory.has(item_id):
		return 0.0

	return parse_weight_value(world.fish_inventory[item_id], 0.0)


func get_fish_count(item_id: String) -> int:
	return int(ceil(get_fish_weight_lb(item_id)))


func parse_weight_value(value, fallback: float = 0.0) -> float:
	var tenths: int = fish_weight_to_tenths(value)
	if tenths <= 0:
		return fallback
	return float(tenths) / 10.0


func fish_weight_to_tenths(value) -> int:
	var weight_value := 0.0
	if value is int or value is float:
		weight_value = float(value)
	elif value is String:
		var text = value.strip_edges()
		if text.is_valid_float():
			weight_value = float(text)
	if not is_finite(weight_value) or weight_value <= 0.0:
		return 0
	return max(0, int(round(weight_value * 10.0)))


func fish_tenths_to_weight(tenths: int) -> float:
	return float(max(0, tenths)) / 10.0


func get_sellable_fish_entries() -> Array:
	var entries: Array = []

	if world == null:
		return entries

	var fish_ids: Array = []

	for item_id in world.fish_items:
		fish_ids.append(str(item_id))

	for item_id in world.fish_inventory.keys():
		var clean_id = str(item_id)
		if not fish_ids.has(clean_id):
			fish_ids.append(clean_id)

	fish_ids.sort_custom(func(a, b):
		var order_a = int(world.item_database.get(a, {}).get("order", 9999))
		var order_b = int(world.item_database.get(b, {}).get("order", 9999))
		return order_a < order_b
	)

	for item_id in fish_ids:
		if not is_valid_fish_item(item_id):
			continue

		var weight_lb = get_fish_weight_lb(item_id)
		if weight_lb <= 0.0:
			continue

		var price_per_lb = get_fish_sell_value(item_id)
		entries.append({
			"item_id": item_id,
			"display_name": world.get_item_display_name(item_id, "fish"),
			"rarity": str(world.item_database[item_id].get("rarity", "common")),
			"count": snapped(weight_lb, 0.1),
			"weight_lb": snapped(weight_lb, 0.1),
			"sell_value": price_per_lb,
			"price_per_lb": price_per_lb,
			"total_value": calculate_fish_sale_value(weight_lb, price_per_lb),
			"texture": world.get_item_texture(item_id, "fish")
		})

	return entries


func sell_fish(item_id: String, amount: float) -> bool:
	if world == null:
		return false

	if pending_transaction:
		world.show_notification("Sale already in progress.")
		return false

	var safe_amount: float = parse_weight_value(amount, 0.0)
	if safe_amount <= 0.0:
		world.show_notification("Choose at least 0.1 lb to sell.")
		return false

	if not is_valid_fish_item(item_id):
		world.show_notification("That item cannot be sold here.")
		return false

	var owned: float = get_fish_weight_lb(item_id)
	if owned <= 0.0:
		world.show_notification("You do not have that fish.")
		refresh_ui()
		return false

	if fish_weight_to_tenths(safe_amount) > fish_weight_to_tenths(owned):
		world.show_notification("You only have " + format_weight(owned) + ".")
		refresh_ui()
		return false

	if calculate_fish_sale_value(safe_amount, get_fish_sell_value(item_id)) <= 0:
		world.show_notification("That amount is worth less than 1 gem.")
		refresh_ui()
		return false

	if has_server_inventory_authority():
		return request_server_sell(item_id, safe_amount)

	return apply_local_sell(item_id, safe_amount)


func sell_all_fish() -> bool:
	if world == null:
		return false

	if pending_transaction:
		world.show_notification("Sale already in progress.")
		return false

	var entries = get_sellable_fish_entries()
	if entries.is_empty():
		world.show_notification("You don't have any fish to sell.")
		return false

	if has_server_inventory_authority():
		return request_server_sell_all()

	var total_gems = 0
	var total_weight = 0.0

	for entry in entries:
		var item_id = str(entry.get("item_id", ""))
		var weight_lb = float(entry.get("weight_lb", 0.0))
		if weight_lb <= 0.0 or not is_valid_fish_item(item_id):
			continue
		var price_per_lb: int = get_fish_sell_value(item_id)
		if price_per_lb <= 0:
			continue
		var sale_value = calculate_fish_sale_value(weight_lb, price_per_lb)
		if sale_value <= 0:
			continue
		world.fish_inventory[item_id] = 0.0
		total_weight += weight_lb
		total_gems += sale_value

	if total_weight <= 0.0 or total_gems <= 0:
		world.show_notification("You don't have any fish to sell.")
		refresh_ui()
		return false

	add_gems(total_gems)
	finish_local_sale("Sold " + format_weight(total_weight) + " of fish for " + format_gem_amount(total_gems) + " gems.")
	return true


func request_server_sell(item_id: String, amount: float) -> bool:
	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return false

	pending_transaction = true
	refresh_ui()

	var sent = bool(network.send_inventory_transaction_request({
		"action": "fish_monger_sell",
		"world": world.current_world_name,
		"x": current_grid.x,
		"y": current_grid.y,
		"item_id": item_id,
		"item_category": "fish",
		"amount": amount
	}))

	if not sent:
		pending_transaction = false
		refresh_ui()
		world.show_notification("That Fish Monger sale could not be completed.")

	return sent


func request_server_sell_all() -> bool:
	var network = get_network_manager()
	if network == null or not network.has_method("send_inventory_transaction_request"):
		world.show_notification("Connection required.")
		return false

	pending_transaction = true
	refresh_ui()

	var sent = bool(network.send_inventory_transaction_request({
		"action": "fish_monger_sell_all",
		"world": world.current_world_name,
		"x": current_grid.x,
		"y": current_grid.y
	}))

	if not sent:
		pending_transaction = false
		refresh_ui()
		world.show_notification("That Fish Monger sale could not be completed.")

	return sent


func apply_local_sell(item_id: String, amount: float) -> bool:
	var price_per_lb = get_fish_sell_value(item_id)
	if price_per_lb <= 0:
		world.show_notification("That fish has no sell value yet.")
		return false

	var owned: float = get_fish_weight_lb(item_id)
	var safe_amount: float = parse_weight_value(amount, 0.0)
	if safe_amount <= 0.0 or fish_weight_to_tenths(owned) < fish_weight_to_tenths(safe_amount):
		world.show_notification("You only have " + format_weight(owned) + ".")
		refresh_ui()
		return false

	var total_gems = calculate_fish_sale_value(safe_amount, price_per_lb)
	if total_gems <= 0:
		world.show_notification("That amount is worth less than 1 gem.")
		refresh_ui()
		return false

	var remaining_tenths: int = max(0, fish_weight_to_tenths(owned) - fish_weight_to_tenths(safe_amount))
	if remaining_tenths <= 0:
		world.fish_inventory.erase(item_id)
	else:
		world.fish_inventory[item_id] = fish_tenths_to_weight(remaining_tenths)
	add_gems(total_gems)
	finish_local_sale("Sold " + format_weight(safe_amount) + " " + world.get_item_display_name(item_id, "fish") + " for " + format_gem_amount(total_gems) + " gems.")
	return true


func format_weight(weight: float) -> String:
	return "%.1f lb" % parse_weight_value(weight, 0.0)


func calculate_fish_sale_value(weight: float, price_per_lb: int) -> int:
	var tenths: int = fish_weight_to_tenths(weight)
	if tenths <= 0 or price_per_lb <= 0:
		return 0
	return int(floor((float(price_per_lb) * float(tenths)) / 10.0))


func format_gem_amount(amount: int) -> String:
	if world != null and world.has_method("format_currency_amount"):
		return world.format_currency_amount(amount)

	return str(amount)


func add_gems(amount: int):
	if amount <= 0:
		return

	if not world.currency_inventory.has("gem"):
		world.currency_inventory["gem"] = 0

	world.add_item_to_inventory_stack(world.currency_inventory, "gem", "currency", amount)


func finish_local_sale(message: String):
	world.update_all_ui()

	if world.has_method("update_shop_ui"):
		world.update_shop_ui()

	if world.has_method("save_player_data"):
		world.save_player_data()

	refresh_ui()
	world.show_notification(message)


func refresh_ui():
	if world != null and world.fish_monger_ui != null and world.fish_monger_ui.has_method("refresh"):
		world.fish_monger_ui.refresh()


func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action = str(data.get("action", ""))
	if action != "fish_monger_sell" and action != "fish_monger_sell_all":
		return false

	pending_transaction = false

	if bool(data.get("ok", false)) and should_apply_reward_fallback(data):
		apply_sale_inventory_fallback(data)
		apply_reward_fallback(data)

	var message = str(data.get("message", "Fish Monger sale finished.")).strip_edges()
	if message != "" and world != null and world.has_method("show_notification"):
		world.show_notification(message)

	if world != null and world.has_method("update_all_ui"):
		world.update_all_ui()

	refresh_ui()
	return true


func should_apply_reward_fallback(data: Dictionary) -> bool:
	var player_data = data.get("player_data", {})
	return not (player_data is Dictionary) or player_data.is_empty()


func apply_sale_inventory_fallback(data: Dictionary):
	if world == null:
		return

	var action = str(data.get("action", "")).strip_edges().to_lower()
	if action == "fish_monger_sell_all":
		for item_id in world.fish_inventory.keys():
			world.fish_inventory.erase(item_id)
		return

	var item_id = str(data.get("item_id", data.get("item_type", data.get("fish_id", "")))).strip_edges()
	if item_id == "" or not world.fish_inventory.has(item_id):
		return

	var sold_weight := 0.0
	for key in ["amount", "weight_lb", "sold_weight_lb", "total_weight", "total_weight_lb"]:
		if data.has(key):
			sold_weight = parse_weight_value(data.get(key), 0.0)
			if sold_weight > 0.0:
				break

	if sold_weight <= 0.0:
		return

	var owned: float = get_fish_weight_lb(item_id)
	var remaining_tenths: int = max(0, fish_weight_to_tenths(owned) - min(fish_weight_to_tenths(owned), fish_weight_to_tenths(sold_weight)))
	if remaining_tenths <= 0:
		world.fish_inventory.erase(item_id)
	else:
		world.fish_inventory[item_id] = fish_tenths_to_weight(remaining_tenths)


func apply_reward_fallback(data: Dictionary):
	var rewards = data.get("rewards", [])
	if not (rewards is Array):
		return

	for reward in rewards:
		if not (reward is Dictionary):
			continue
		var item_id = str(reward.get("item_id", reward.get("item_type", "")))
		var category = str(reward.get("item_category", reward.get("category", "")))
		var amount = int(reward.get("amount", 0))
		if item_id == "gem" and (category == "" or category == "currency") and amount > 0:
			add_gems(amount)
