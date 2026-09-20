extends SceneTree

func _init():
	call_deferred("run")

func run():
	var ui = load("res://Scenes/ui/vending/VendingMachineGUI.tscn").instantiate()
	root.add_child(ui)
	ui.setup(null, null)
	# Reopening the vending UI must keep each callback connected exactly once.
	ui.setup(null, null)
	assert(ui.price_mode.item_selected.get_connections().size() == 1)
	assert(ui.purchase_confirmation.confirmed.get_connections().size() == 1)
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
	ui.price_spin.value = 15
	assert(ui.add_inventory_item_to_vend("dirt", "block", 50))
	assert(ui.price_spin.value == 15, "Selecting stock must preserve the draft price")
	assert(ui.stock_spin.value == 50)
	assert(ui.collect_button.text == "COLLECT 8 WL")
	assert(ui.panel.get_node("ItemCard/SelectItem").text == "ADD STOCK")
	ui.mutation_pending = true
	ui.refresh_buttons(ui.get_listing(), 8, true)
	assert(ui.list_button.disabled and ui.collect_button.disabled and ui.cancel_button.disabled)
	ui.mutation_pending = false
	assert(not ui.add_inventory_item_to_vend("stone", "block", 50))
	# The direct removal response is followed by a queued public broadcast.
	# Public state has no recipient and therefore contains can_manage=false.
	ui.mutation_pending = true
	ui.handle_inventory_transaction_result({"action": "vend_cancel", "ok": true, "vend_state": {"x": 0, "y": 0, "listing": {}, "can_manage": true}})
	assert(ui.selected_item.is_empty())
	ui.handle_vend_state({"x": 0, "y": 0, "listing": {}, "can_manage": false})
	assert(ui.can_manage_current_vend(), "Broadcast must not switch the owner to buyer mode")
	assert(ui.panel.get_node("ItemCard/SelectItem").visible)
	assert(not ui.panel.get_node("ItemCard/SelectItem").disabled)
	assert(ui.add_inventory_item_to_vend("stone", "block", 20), "Owner can restock without reopening")
	# Direct access denials must still take effect; broadcasts cannot grant access.
	ui.handle_inventory_transaction_result({"action": "vend_get_state", "ok": true, "vend_state": {"x": 0, "y": 0, "listing": {}, "can_manage": false}})
	ui.handle_vend_state({"x": 0, "y": 0, "listing": {}, "can_manage": true})
	assert(not ui.can_manage_current_vend())
	ui.close_vending()
	assert(ui.purchase_quote.is_empty())
	assert(not ui.purchase_confirmation.visible)
	ui.apply_vend_state({"listing": {}, "can_manage": true})
	ui.refresh_ui()
	assert(ui.item_slot.text == "+")
	assert(ui.list_button.disabled)
	ui.queue_free()
	print("[vending-flow] passed")
	quit()
