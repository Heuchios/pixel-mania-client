extends Node

const FISH_MONGER_ID = "fish_monger"
var world = null
var current_grid := Vector2i(999999, 999999)
var pending_transaction := false
var market_prices: Dictionary = {}
var price_request_pending := false
var refresh_seconds := 0.0

func setup(world_ref):
	world = world_ref

func _process(delta: float):
	if world == null or world.fish_monger_ui == null or not world.fish_monger_ui.visible:
		return
	refresh_seconds += delta
	if refresh_seconds >= 15.0 and not pending_transaction:
		refresh_seconds = 0.0
		request_prices()

func is_fish_monger_block(block_type: String) -> bool:
	return block_type == FISH_MONGER_ID

func open_fish_monger(grid_pos: Vector2i):
	if world == null or not world.blocks.has(grid_pos) or not is_fish_monger_block(str(world.blocks[grid_pos].get("type", ""))):
		return
	current_grid = grid_pos
	market_prices.clear()
	price_request_pending = false
	if world.fish_monger_ui != null:
		world.fish_monger_ui.open_fish_monger(grid_pos)
	request_prices()

func get_network_manager():
	return world.get_node_or_null("/root/NetworkManager") if world != null else null

func has_server_inventory_authority() -> bool:
	var network = get_network_manager()
	return network != null and network.is_connected_to_server() and network.has_active_session()

func request_prices():
	if price_request_pending or not has_server_inventory_authority():
		return
	price_request_pending = true
	if not _send({"action": "fish_monger_prices"}):
		price_request_pending = false

func _send(payload: Dictionary) -> bool:
	var network = get_network_manager()
	if network == null:
		return false
	payload.merge({"world": world.current_world_name, "x": current_grid.x, "y": current_grid.y}, true)
	return bool(network.send_inventory_transaction_request(payload))

func is_valid_fish_item(item_id: String) -> bool:
	return world != null and world.item_database.has(item_id) and str(world.item_database[item_id].get("category", "")) == "fish"

func get_fish_sell_value(item_id: String) -> float:
	return float(market_prices.get(item_id, {}).get("price_cents", 0)) / 100.0

func get_fish_inventory_count(item_id: String) -> int:
	return maxi(0, int(world.fish_inventory.get(item_id, 0))) if world != null else 0

func get_fish_count(item_id: String) -> float:
	return get_fish_inventory_count(item_id) / 10.0

func get_fish_weight_kg(item_id: String) -> float:
	return get_fish_count(item_id)

func get_sellable_fish_entries() -> Array:
	var entries: Array = []
	if world == null:
		return entries
	for item_id in world.fish_inventory:
		if not is_valid_fish_item(item_id) or get_fish_inventory_count(item_id) <= 0:
			continue
		var rate: float = get_fish_sell_value(item_id)
		var price: Dictionary = market_prices.get(item_id, {})
		entries.append({"item_id": item_id, "display_name": world.get_item_display_name(item_id, "fish"),
			"rarity": world.item_database[item_id].get("rarity", "common"), "count": get_fish_count(item_id),
			"sell_value": rate, "value_per_fish": rate, "price_per_kg": rate,
			"min_price_kg": float(price.get("min_price_cents", 0)) / 100.0,
			"max_price_kg": float(price.get("max_price_cents", 0)) / 100.0,
			"total_value": calculate_fish_sale_value(get_fish_count(item_id), rate),
			"texture": world.get_item_texture(item_id, "fish")})
	entries.sort_custom(func(a, b): return str(a.item_id) < str(b.item_id))
	return entries

func calculate_fish_sale_value(weight: float, price_per_kg: float) -> int:
	var numerator: int = roundi(weight * 10.0) * roundi(price_per_kg * 100.0)
	return ceili(numerator / 1000.0)

func get_total_sellable_fish_value() -> int:
	var numerator: int = 0
	for item_id in world.fish_inventory:
		numerator += get_fish_inventory_count(item_id) * int(market_prices.get(item_id, {}).get("price_cents", 0))
	return ceili(numerator / 1000.0)

func _expected_prices() -> Dictionary:
	var prices: Dictionary = {}
	for item_id in market_prices:
		prices[item_id] = int(market_prices[item_id].get("price_cents", 0))
	return prices

func sell_fish(item_id: String, weight: float) -> bool:
	if pending_transaction or not is_valid_fish_item(item_id):
		return false
	if not is_finite(weight) or weight < 0.1 or weight > get_fish_count(item_id) or not is_equal_approx(weight * 10.0, round(weight * 10.0)):
		world.show_notification("Choose an owned weight in 0.1 kg steps.")
		return false
	return _request_sale({"action": "fish_monger_sell", "item_id": item_id, "weight_kg": weight})

func sell_all_fish() -> bool:
	return _request_sale({"action": "fish_monger_sell_all"})

func _request_sale(payload: Dictionary) -> bool:
	if pending_transaction:
		return false
	if not has_server_inventory_authority() or market_prices.is_empty():
		world.show_notification("Connect to the fish market and wait for prices.")
		request_prices()
		return false
	pending_transaction = true
	payload.expected_prices = _expected_prices()
	var sent: bool = _send(payload)
	if not sent:
		pending_transaction = false
	refresh_ui()
	return sent

func format_fish_count(weight: float) -> String:
	return "%.1f kg" % weight

func refresh_ui():
	if world != null and world.fish_monger_ui != null:
		world.fish_monger_ui.refresh()

func handle_inventory_transaction_result(data: Dictionary) -> bool:
	var action: String = str(data.get("action", ""))
	if action not in ["fish_monger_prices", "fish_monger_sell", "fish_monger_sell_all"]:
		return false
	if action == "fish_monger_prices":
		price_request_pending = false
	else:
		pending_transaction = false
	if data.get("fish_market") is Dictionary:
		market_prices = data.fish_market
	if action != "fish_monger_prices":
		world.show_notification(str(data.get("message", "Sale finished.")))
		request_prices()
	refresh_ui()
	return true
