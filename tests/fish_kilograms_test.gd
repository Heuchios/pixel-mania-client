extends SceneTree

const Monger = preload("res://Scripts/fish_monger_manager.gd")
const MongerUI = preload("res://Scripts/ui/fish_monger_ui.gd")
const InventoryUI = preload("res://Scripts/ui/inventory_scene.gd")
const Fishing = preload("res://Scripts/fishing_manager.gd")

var failures: Array[String] = []

func check(condition: bool, message: String):
	if not condition:
		failures.append(message)

func _init():
	call_deferred("run_checks")

func run_checks():
	var monger = Monger.new()
	check(monger.calculate_fish_sale_value(5.7, 2.0) == 12, "5.7 kg at 2 gems/kg rounds up to 12")
	check(monger.calculate_fish_sale_value(2.9, 10.0) == 29, "exact integer payout doesn't over-round")
	check(monger.format_fish_count(0.1) == "0.1 kg", "minimum weight displays")
	var ui = MongerUI.new()
	check(is_equal_approx(ui.parse_amount_text("5.7"), 5.7), "decimal sale input preserved")
	check(is_equal_approx(ui.clamp_sell_amount(0.1, 5.7), 0.1), "minimum sale allowed")
	check(ui.calculate_fish_sale_value(5.7, 2.0) == 12, "UI estimate matches server")
	check(ui.get_total_sellable_fish_value_from_entries([{"count": 0.1, "sell_value": 2}, {"count": 0.1, "sell_value": 2}]) == 1, "sell-all rounds once")
	var inventory = InventoryUI.new()
	check(inventory._slot_count_text({"category": "fish", "count": 57}) == "5.7 kg", "inventory stack shows kg")
	check(inventory._detail_count_text({"category": "fish", "count": 20000}) == "2000.0 / 2000 kg", "maximum stack displays")
	var fishing = Fishing.new()
	var save_script = load("res://Scripts/save_manager.gd")
	var saves = save_script.new()
	var world_script = load("res://Scripts/world.gd")
	var world = world_script.new()
	world.item_database["pond_fish"] = {"category": "fish", "stack_limit": 20000}
	check(world.get_stack_limit_for_item("pond_fish", "fish") == 20000, "real world stack limit supports 2000 kg")
	world.fish_inventory["pond_fish"] = 0
	world.apply_network_inventory_delta({"item_type": "pond_fish", "item_category": "fish", "after_count": 20000})
	check(world.fish_inventory.pond_fish == 20000, "network inventory does not truncate weight")
	check(saves.safe_fish_count_from_save(7, "count") == 70, "legacy counts convert to one kg each")
	check(saves.safe_fish_count_from_save(57, "tenths_kg") == 57, "new saves do not convert twice")
	var legacy := {"fish_inventory": {"pond_fish": 2}, "fish_inventory_unit": "count"}
	saves.merge_legacy_inventory_counts(legacy, {"fish_inventory": {"pond_fish": 3}, "fish_inventory_unit": "count"})
	check(legacy.fish_inventory.pond_fish == 30 and legacy.fish_inventory_unit == "tenths_kg", "legacy merge keeps the new unit marker")
	check(fishing._fish_weight_to_tenths(5.7) == 57, "catch encodes exact units")
	check(is_equal_approx(fishing._fish_tenths_to_weight(57), 5.7), "catch decodes exact units")
	for index in range(1000):
		var weight: float = fishing._roll_catch_weight("pond_fish")
		check(weight >= 0.1 and weight <= 150.0, "catch within bounds")
	for node in [monger, ui, inventory, fishing, saves, world]:
		node.free()
	if failures.is_empty():
		print("Fish kilogram client checks passed")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
