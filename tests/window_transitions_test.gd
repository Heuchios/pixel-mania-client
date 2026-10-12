extends SceneTree

class SelectionWorld extends Node:
	var selecting := true
	var selection_closes := 0
	func is_trade_item_selecting() -> bool:
		return selecting
	func end_trade_item_select(_refresh: bool) -> void:
		selecting = false
		selection_closes += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for script_path in ["res://Scripts/interaction_manager.gd", "res://Scripts/area_lock_ui.gd", "res://Scripts/world_lock_scene_ui.gd"]:
		var script = load(script_path)
		assert(script != null and script.can_instantiate(), "Dialog caller must compile: " + script_path)
	var policy = root.get_node("WindowTransitions")
	var owner_control := Control.new()
	owner_control.hide()
	root.add_child(owner_control)
	var panel := Panel.new()
	panel.size = Vector2(400, 240)
	panel.position = Vector2(120, 80)
	panel.scale = Vector2(0.75, 0.75)
	owner_control.add_child(panel)
	policy.register_window(owner_control, panel)
	var id := panel.get_instance_id()
	owner_control.show()
	assert(policy.active.has(id), "Opening starts the shared animation")
	policy._process(0.10)
	var halfway: Dictionary = policy.active[id].duplicate()
	owner_control.show()
	assert(policy.active[id].time == halfway.time, "Repeated open does not restart motion")
	policy._render()
	assert(panel.scale == Vector2(0.75, 0.75), "Animation must not change mobile layout scale")
	assert(panel.position == Vector2(120, 80))
	owner_control.hide()
	assert(not owner_control.is_visible_in_tree(), "Close takes effect immediately for input and gameplay")
	assert(not policy.active[id].opening)
	policy._process(0.04)
	var before_reopen: Dictionary = policy.active[id].duplicate()
	owner_control.show()
	assert(policy.active[id].scale == before_reopen.scale and policy.active[id].alpha == before_reopen.alpha)
	assert(policy.active[id].scale_velocity == before_reopen.scale_velocity, "Reversal preserves speed")
	assert(policy.active[id].opening, "Rapid reopen reverses exit")
	policy._process(1.0)
	assert(not policy.active.has(id))
	owner_control.hide()
	owner_control.free()
	assert(not policy.windows.has(id), "Freeing a closing window removes its render overrides")
	var temporary := Panel.new()
	temporary.name = "DoorEditorPanel"
	temporary.size = Vector2(200, 100)
	root.add_child(temporary)
	await process_frame
	assert(policy.windows.has(temporary.get_instance_id()))
	policy.dismiss_and_free(temporary)
	assert(not temporary.visible, "Temporary dialogs release input immediately")
	await create_timer(0.3).timeout
	assert(not is_instance_valid(temporary), "Temporary dialogs free after exit")
	var reopening := Panel.new()
	reopening.name = "DoorEditorPanel"
	root.add_child(reopening)
	await process_frame
	policy.dismiss_and_free(reopening)
	reopening.show()
	await create_timer(0.25).timeout
	assert(is_instance_valid(reopening), "An old dismiss callback cannot free a reopened window")
	policy.dismiss_and_free(reopening)
	await create_timer(0.25).timeout
	assert(not is_instance_valid(reopening))
	# A future window with the normal structure needs no script-name registration.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var future_ui := Control.new()
	future_ui.name = "FutureFeatureUI"
	future_ui.hide()
	var future_window := Panel.new()
	future_window.name = "Window"
	future_window.size = Vector2(300, 200)
	future_ui.add_child(future_window)
	var close := Button.new()
	close.name = "CloseButton"
	future_window.add_child(close)
	layer.add_child(future_ui)
	await process_frame
	assert(policy.windows.has(future_window.get_instance_id()), "Future windows inherit the global policy")
	future_ui.show()
	assert(policy.active.has(future_window.get_instance_id()))
	future_ui.hide()
	assert(not policy.active[future_window.get_instance_id()].opening)
	layer.free()
	# Check real scene registration, including nested confirmation/detail windows.
	for path in ["res://Scenes/ui/trade/TradeScene.tscn", "res://Scenes/ui/vending/VendingMachineGUI.tscn", "res://Scenes/ui/shop/ShopSceneRedesign.tscn", "res://Scenes/ui/settings/SettingsPanel.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		var found := false
		for entry in policy.windows.values():
			if entry.owner.get_ref() == scene:
				found = true
		assert(found, "Scene must register: " + path)
		if path.ends_with("SettingsPanel.tscn"):
			assert(scene.get_node_or_null("Window/WindowAnimations") == null, "No player-facing animation toggle")
		scene.free()
	await _check_coordinated_windows(policy)
	await _check_selection_and_confirmation(policy)
	print("window_transitions_test: PASS")
	quit()

func _check_coordinated_windows(policy) -> void:
	var shop = load("res://Scenes/ui/shop/ShopSceneRedesign.tscn").instantiate()
	var settings = load("res://Scenes/ui/settings/SettingsPanel.tscn").instantiate()
	root.add_child(shop)
	root.add_child(settings)
	await process_frame
	shop.hide()
	settings.hide()
	var close_events := [0]
	shop.close_requested.connect(func(): close_events[0] += 1; shop.hide())
	shop.show()
	settings.open_settings()
	assert(not shop.visible and settings.visible, "Opening an unrelated modal closes its predecessor")
	assert(close_events[0] == 1, "Switching windows uses the normal close callback exactly once")
	var second = load("res://Scenes/ui/settings/SettingsPanel.tscn").instantiate()
	root.add_child(second)
	await process_frame
	second.open_settings()
	assert(not settings.visible and second.visible, "Two instances of the same window cannot be open")
	second.close_settings()
	settings.open_settings()
	settings.close_settings()
	settings.open_settings()
	assert(settings.visible)
	# Shop details are intentional children; they retain the parent and use one transition.
	shop.show()
	shop.detail_overlay.show()
	var detail_id: int = shop.detail_card.get_instance_id()
	assert(shop.visible and shop.detail_overlay.visible)
	assert(policy.active.has(detail_id))
	shop.detail_overlay.hide()
	shop.detail_overlay.show()
	assert(policy.active[detail_id].opening)
	shop.free()
	settings.free()
	second.free()

func _check_selection_and_confirmation(policy) -> void:
	var world := SelectionWorld.new()
	root.add_child(world)
	var trade = load("res://Scenes/ui/trade/TradeScene.tscn").instantiate()
	var inventory = load("res://Scenes/ui/inventory/InventoryScene.tscn").instantiate()
	root.add_child(trade)
	root.add_child(inventory)
	trade.world = world
	await process_frame
	trade.show()
	inventory.open_inventory()
	assert(trade.visible and inventory.visible, "Trade item selection intentionally retains both windows")
	var settings = load("res://Scenes/ui/settings/SettingsPanel.tscn").instantiate()
	root.add_child(settings)
	await process_frame
	settings.open_settings()
	assert(not trade.visible and not inventory.visible, "An unrelated modal closes the entire previous flow")
	assert(world.selection_closes == 1, "Closing a trade uses its selection cleanup")
	settings.free()
	inventory.free()
	trade.free()
	world.free()
	var dialog = load("res://Scripts/ui/vending_purchase_confirmation.gd").new()
	root.add_child(dialog)
	await process_frame
	var submitted := [0]
	dialog.confirmed.connect(func(): submitted[0] += 1)
	dialog.popup_centered()
	policy._process(0.30)
	dialog.card.get_node("BuyButton").pressed.emit()
	dialog.card.get_node("BuyButton").pressed.emit()
	assert(submitted[0] == 1 and not dialog.visible, "Repeated confirm cannot submit twice during the exit")
	var card_id: int = dialog.card.get_instance_id()
	assert(policy.active.has(card_id) and not policy.active[card_id].opening)
	policy.dismiss_and_free(dialog)
	await process_frame
	assert(is_instance_valid(dialog), "A modal wrapper survives for its card's exit")
	await create_timer(0.25).timeout
	assert(not is_instance_valid(dialog), "The wrapper frees after its exit")
