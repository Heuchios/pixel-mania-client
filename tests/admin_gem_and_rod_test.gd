extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var saver = load("res://Scripts/save_manager.gd").new()
	var currency := {"gem": 426}
	saver.apply_saved_inventory_counts(currency, {"gem": 26}, false)
	assert(currency.gem == 26)
	saver.apply_saved_inventory_counts(currency, {}, false)
	assert(currency.gem == 0)
	currency.gem = 426
	saver.apply_saved_inventory_counts(currency, {"gem": 0}, false)
	assert(currency.gem == 0)
	var shop = load("res://Scripts/shop_ui.gd").new()
	var rods := 0
	for item in shop.shop_items:
		if item.item_id == "wooden_fishing_rod":
			assert(item.price == 10 and item.amount == 1)
			rods += 1
	assert(rods == 1)
	shop.free()
	saver.free()
	print("ADMIN_GEM_AND_ROD_TEST_PASS")
	quit()
