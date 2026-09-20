extends SceneTree

func _init():
	call_deferred("run")

func run():
	var ui = load("res://Scenes/ui/vending/VendingMachineGUI.tscn").instantiate()
	root.add_child(ui)
	ui.setup(null, null)
	ui.visible = true
	var listing = {"listing_id": "sale1", "item_id": "dirt", "item_category": "block", "stock": 25, "amount_per_sale": 10, "price_wls": 1}
	ui.apply_vend_state({"listing": listing, "can_manage": false})
	ui.refresh_ui()
	assert(ui.stock_spin.max_value == 20)
	ui.stock_spin.value = 20
	ui.stock_spin.get_line_edit().text = "20"
	assert(ui.buy_button.text == "BUY 20 FOR 2 WL")
	ui._on_buy_pressed()
	assert(ui.purchase_quote.sale_count == 2)
	assert(ui.purchase_quote.expected_price_wls == 1)
	assert(ui.purchase_confirmation.dialog_text.contains("20 Dirt for 2 World Locks"))
	ui.purchase_confirmation.hide()
	listing.stock = 5
	ui.apply_vend_state({"listing": listing, "can_manage": false})
	ui.refresh_ui()
	assert(ui.buy_button.disabled)
	ui.apply_vend_state({"listing": listing, "can_manage": true, "pending_wls": 8})
	ui.refresh_ui()
	assert(not ui.list_button.disabled)
	assert(not ui.collect_button.disabled)
	assert(ui.stock_spin.value == 0)
	assert(ui.price_mode.selected == 1)
	assert(ui.add_inventory_item_to_vend("dirt", "block", 50))
	assert(ui.stock_spin.value == 50)
	assert(not ui.add_inventory_item_to_vend("stone", "block", 50))
	ui.close_vending()
	assert(ui.purchase_quote.is_empty())
	assert(not ui.purchase_confirmation.visible)
	ui.queue_free()
	print("[vending-flow] passed")
	quit()
