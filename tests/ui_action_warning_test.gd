extends SceneTree

class PanelFixture:
	extends Control
	var world
	var current_trade: Dictionary = {}
	var cancellations := 0
	var selection_active := true
	func close_safe(): hide()
	func close_vending(): hide()
	func close_shop(): hide()
	func close_rewards(): hide()
	func close_inventory_window():
		selection_active = false
		hide()
	func close_trade_ui():
		current_trade.clear()
		hide()
	func cancel_trade_ui(): cancellations += 1
	func set_emotes_panel_open(open: bool): visible = open
	func handle_inventory_transaction_result(data: Dictionary) -> bool:
		if name != "Shop" or str(data.get("action", "")) != "shop_buy": return false
		world.show_notification(str(data.get("message", "")))
		return true

class ChatFixture:
	extends Control
	var panels: Array = []
	var messages: Array[String] = []
	var panels_visible_when_shown: Array[bool] = []
	var blocked := false
	func close_chat_panel(): pass # prepare_action_notification must also clear chat suppression.
	func show_chat_bubble(_message): pass
	func can_show_notification_bubble() -> bool: return not blocked
	func prepare_action_notification(): blocked = false
	func show_notification_bubble(message: String) -> bool:
		messages.append(message)
		var any_open := false
		for panel in panels: any_open = any_open or panel.visible
		panels_visible_when_shown.append(any_open)
		return true

var checks := 0
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, description: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func run():
	# Use the real world, notification manager and global close path without starting a world/session.
	var world = load("res://Scripts/world.gd").new()
	var manager = load("res://Scripts/gameplay_ui_manager.gd").new()
	var saves = load("res://Scripts/save_manager.gd").new()
	world.gameplay_ui_manager = manager
	world.save_manager = saves
	manager.world = world
	saves.world = world
	var chat := ChatFixture.new()
	root.add_child(chat)
	world.chat_ui = chat
	var panels: Array = []
	for entry in [["safe_ui", "Safe"], ["vending_ui", "Vending"], ["shop_ui", "Shop"], ["daily_rewards_ui", "Rewards"], ["inventory_manager", "Inventory"], ["trade_ui", "Trade"], ["emotes_ui", "Emotes"]]:
		var panel := PanelFixture.new()
		panel.name = entry[1]
		panel.world = world
		root.add_child(panel)
		world.set(entry[0], panel)
		panels.append(panel)
	var lock_ui = load("res://Scenes/ui/locks/WorldLockGUI.tscn").instantiate()
	root.add_child(lock_ui)
	lock_ui.world = world
	world.world_lock_ui = lock_ui
	panels.append(lock_ui)
	chat.panels = panels

	for panel in panels: panel.show()
	lock_ui.menu_open = true
	lock_ui._show_confirm_panel("Confirm world trade?", func(): pass)
	chat.blocked = true
	world.trade_ui.current_trade = {"trade_id": "fixture"}
	var warning := 'Remove items from "safe" "vend" "display" "donation box" before trading the world.'
	lock_ui.show_result({"ok": false, "message": warning})
	check(chat.messages.back() == warning, "World trade rejection remains readable even while chat was active")
	for panel in panels: check(not panel.visible, str(panel.name) + " closes on the warning")
	check(not chat.panels_visible_when_shown.back(), "Panels close before the error bubble is shown")
	check(lock_ui.confirm_panel == null and lock_ui.confirm_blocker == null, "Nested world lock confirmation is dismissed")
	check(not world.inventory_manager.selection_active, "Inventory selection cleanup runs")
	check(world.trade_ui.cancellations == 1 and world.trade_ui.current_trade.is_empty(), "Active trade is canceled before local state closes")

	world.shop_ui.show()
	world.handle_inventory_transaction_result({"action": "shop_buy", "ok": false, "message": "Choose a different item."})
	check(not world.shop_ui.visible, "Structured failure closes UI without depending on message wording")
	check(chat.messages.back() == "Choose a different item.", "Structured failure reaches the bubble")
	check(manager.notification_kind_context == "", "Failure severity is restored after result dispatch")
	world.shop_ui.show()
	world.handle_inventory_transaction_result({"action": "shop_buy", "ok": true, "message": "Purchased World Lock."})
	check(world.shop_ui.visible, "Successful shop purchases keep the shop open")

	for message in ["Not enough gems.", "That item cannot be traded.", "World Lock is not available.", "Connection timed out. Try again.", warning]:
		world.shop_ui.show()
		world.show_notification(message)
		check(not world.shop_ui.visible, "Error/warning has priority over trade/reward subject: " + message)
	for message in ["Trade invite sent.", "Updated vending price.", "World Lock Key created.", "Equipped Trident."]:
		world.shop_ui.show()
		world.show_notification(message)
		check(world.shop_ui.visible, "Successful/info feedback keeps panels open: " + message)

	world.shop_ui.show()
	world.show_action_error("Invalid server request.")
	check(not world.shop_ui.visible and chat.messages.back() == "Invalid server request.", "Explicit error is not filtered as routine server progress")
	world.shop_ui.show()
	lock_ui._show_confirm_loading("Trading world...")
	check(world.shop_ui.visible, "Pending world-lock action is not treated as a failure")

	# Exercise actual chat focus and bubble suppression without networking.
	var actual_chat = load("res://Scripts/chat_ui.gd").new()
	actual_chat.quick_chat_active = true
	actual_chat.active_bubble_kind = actual_chat.BUBBLE_KIND_CHAT
	actual_chat.prepare_action_notification()
	check(actual_chat.can_show_notification_bubble(), "Action warning clears typing and prior chat-bubble suppression")
	actual_chat.free()
	for panel in panels: panel.free()
	chat.free()
	manager.free()
	saves.free()
	world.free()
	print("UI_ACTION_WARNING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
