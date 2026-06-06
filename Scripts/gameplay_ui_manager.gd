extends Node

var world = null
var ui_refresh_queued := false
var ui_refresh_in_progress := false
var sign_hover_label: Label = null

const SIGN_HOVER_LABEL_WIDTH = 380.0
const SIGN_HOVER_LABEL_HEIGHT = 54.0
const SIGN_HOVER_WORLD_OFFSET = Vector2(0.0, -40.0)
const SIGN_HOVER_FONT_SIZE = 24
const SIGN_HOVER_OUTLINE_SIZE = 7

func setup(world_ref):
	world = world_ref
	setup_sign_hover_label()


func setup_sign_hover_label():
	if world == null or world.ui_layer == null:
		return

	var old_label = world.ui_layer.get_node_or_null("SignHoverTextLabel")
	if old_label != null:
		old_label.queue_free()

	sign_hover_label = Label.new()
	sign_hover_label.name = "SignHoverTextLabel"
	sign_hover_label.size = Vector2(SIGN_HOVER_LABEL_WIDTH, SIGN_HOVER_LABEL_HEIGHT)
	sign_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_hover_label.z_index = 72
	sign_hover_label.add_theme_font_size_override("font_size", SIGN_HOVER_FONT_SIZE)
	sign_hover_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	sign_hover_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	sign_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	sign_hover_label.add_theme_constant_override("outline_size", SIGN_HOVER_OUTLINE_SIZE)
	sign_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	sign_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	sign_hover_label.visible = false
	world.ui_layer.add_child(sign_hover_label)

func update_all_ui():
	request_update_all_ui()


func request_update_all_ui():
	if world == null:
		return
	if ui_refresh_queued:
		return

	ui_refresh_queued = true
	call_deferred("_flush_update_all_ui")


func force_update_all_ui():
	if world == null:
		return

	ui_refresh_queued = false
	_perform_update_all_ui()


func _flush_update_all_ui():
	if not ui_refresh_queued:
		return

	ui_refresh_queued = false
	_perform_update_all_ui()


func _perform_update_all_ui():
	if world == null or ui_refresh_in_progress:
		return

	ui_refresh_in_progress = true
	update_inventory_label()
	world.update_hotbar()
	if not world.has_method("is_inventory_open") or world.is_inventory_open():
		world.update_inventory_window()
	update_shop_ui()
	update_crafting_ui()
	update_furnace_ui()
	update_fish_monger_ui()
	ui_refresh_in_progress = false


func setup_chat_ui():
	if world.ui_layer == null:
		return

	world.chat_ui = world.ui_layer.get_node_or_null("ChatUI")

	if world.chat_ui == null:
		var chat_script = preload("res://Scripts/chat_ui.gd")
		world.chat_ui = Control.new()
		world.chat_ui.name = "ChatUI"
		world.chat_ui.set_script(chat_script)
		world.ui_layer.add_child(world.chat_ui)

	if world.chat_ui.has_method("set_player"):
		world.chat_ui.set_player(world.player)

	if world.chat_ui.has_method("set_world"):
		world.chat_ui.set_world(world)

	if world.chat_ui.has_method("setup_chat_ui"):
		world.chat_ui.setup_chat_ui()


func restore_chat_ui_after_world_enter():
	if world.chat_ui == null:
		setup_chat_ui()

	if world.chat_ui != null:
		world.chat_ui.visible = true

		if world.chat_ui.has_method("setup_chat_ui"):
			world.chat_ui.setup_chat_ui()


func open_chat_panel():
	if world.has_method("is_movement_blocking_ui_open") and world.is_movement_blocking_ui_open():
		return
	if world.chat_ui != null and world.chat_ui.has_method("open_chat_panel"):
		world.chat_ui.open_chat_panel()


func close_chat_panel():
	if world.chat_ui != null and world.chat_ui.has_method("close_chat_panel"):
		world.chat_ui.close_chat_panel()


func toggle_chat_panel():
	if world.chat_ui != null and world.chat_ui.has_method("toggle_chat_panel"):
		world.chat_ui.toggle_chat_panel()


func send_chat_message():
	if world.chat_ui != null and world.chat_ui.has_method("send_chat_message"):
		world.chat_ui.send_chat_message()


func focus_chat_input():
	if world.chat_ui != null and world.chat_ui.has_method("focus_chat_input"):
		world.chat_ui.focus_chat_input()


func release_chat_focus():
	if world.chat_ui != null and world.chat_ui.has_method("release_chat_focus"):
		world.chat_ui.release_chat_focus()


func is_chat_open() -> bool:
	if world.chat_ui != null and world.chat_ui.has_method("is_chat_open"):
		return world.chat_ui.is_chat_open()

	return false


func is_chat_input_focused() -> bool:
	if world.chat_ui != null and world.chat_ui.has_method("is_chat_input_focused"):
		return world.chat_ui.is_chat_input_focused()

	return false


func setup_notification_ui():
	if world.ui_layer == null:
		return

	world.notification_ui = world.ui_layer.get_node_or_null("NotificationUI")

	if world.notification_ui == null:
		var notification_script = preload("res://Scripts/notification_ui.gd")
		world.notification_ui = Control.new()
		world.notification_ui.name = "NotificationUI"
		world.notification_ui.set_script(notification_script)
		world.ui_layer.add_child(world.notification_ui)

	if world.notification_ui.has_method("set_world"):
		world.notification_ui.set_world(world)

	if world.notification_ui.has_method("setup"):
		world.notification_ui.setup()


func show_notification(message: String):
	if world.notification_ui != null and world.notification_ui.has_method("show_message"):
		world.notification_ui.show_message(message)


func show_level_up(progression_data: Dictionary):
	if world.notification_ui != null and world.notification_ui.has_method("show_level_up"):
		world.notification_ui.show_level_up(progression_data)


func open_notification_panel():
	close_conflicting_modal_ui("notification")
	if world.notification_ui != null and world.notification_ui.has_method("open_notification_panel"):
		world.notification_ui.open_notification_panel()


func close_notification_panel():
	if world.notification_ui != null and world.notification_ui.has_method("close_notification_panel"):
		world.notification_ui.close_notification_panel()


func toggle_notification_panel():
	if is_notification_panel_open():
		close_notification_panel()
	else:
		open_notification_panel()


func is_notification_panel_open() -> bool:
	if world.notification_ui != null and world.notification_ui.has_method("is_notification_panel_open"):
		return world.notification_ui.is_notification_panel_open()

	return false


func setup_player_menu_ui():
	if world.ui_layer == null:
		return

	world.player_menu_ui = world.ui_layer.get_node_or_null("PlayerMenuUI")

	if world.player_menu_ui == null:
		var menu_script = preload("res://Scripts/player_menu_ui.gd")
		world.player_menu_ui = Control.new()
		world.player_menu_ui.name = "PlayerMenuUI"
		world.player_menu_ui.set_script(menu_script)
		world.ui_layer.add_child(world.player_menu_ui)

	if world.player_menu_ui.has_method("setup"):
		world.player_menu_ui.setup(world)


func setup_game_menu_ui():
	if world.ui_layer == null:
		return

	world.game_menu_ui = world.ui_layer.get_node_or_null("GameMenuUI")

	if world.game_menu_ui == null:
		var menu_script = preload("res://Scripts/game_menu_ui.gd")
		world.game_menu_ui = Control.new()
		world.game_menu_ui.name = "GameMenuUI"
		world.game_menu_ui.set_script(menu_script)
		world.ui_layer.add_child(world.game_menu_ui)

	if world.game_menu_ui.has_method("setup"):
		world.game_menu_ui.setup(world, world.ui_layer)


func setup_friends_ui():
	if world.ui_layer == null:
		return

	world.friends_ui = world.ui_layer.get_node_or_null("FriendsUI")

	if world.friends_ui == null:
		var friends_script = preload("res://Scripts/friends_ui.gd")
		world.friends_ui = Control.new()
		world.friends_ui.name = "FriendsUI"
		world.friends_ui.set_script(friends_script)
		world.ui_layer.add_child(world.friends_ui)

	if world.friends_ui.has_method("setup"):
		world.friends_ui.setup(world, world.ui_layer)


func setup_developer_panel_ui():
	if world.ui_layer == null:
		return

	world.developer_panel_ui = world.ui_layer.get_node_or_null("DeveloperPanelUI")

	if world.developer_panel_ui == null:
		var dev_script = preload("res://Scripts/developer_panel_ui.gd")
		world.developer_panel_ui = Control.new()
		world.developer_panel_ui.name = "DeveloperPanelUI"
		world.developer_panel_ui.set_script(dev_script)
		world.ui_layer.add_child(world.developer_panel_ui)

	if world.developer_panel_ui.has_method("setup"):
		world.developer_panel_ui.setup(world, world.ui_layer)


func setup_trade_ui():
	if world.ui_layer == null:
		return

	world.trade_ui = world.ui_layer.get_node_or_null("TradeUI")

	if world.trade_ui == null:
		var trade_script = preload("res://Scripts/trade_ui.gd")
		world.trade_ui = Control.new()
		world.trade_ui.name = "TradeUI"
		world.trade_ui.set_script(trade_script)
		world.ui_layer.add_child(world.trade_ui)

	if world.trade_ui.has_method("setup"):
		world.trade_ui.setup(world)


func setup_vending_ui():
	if world.ui_layer == null:
		return

	world.vending_ui = world.ui_layer.get_node_or_null("VendingUI")

	if world.vending_ui == null:
		var vending_script = preload("res://Scripts/vending_ui.gd")
		world.vending_ui = Control.new()
		world.vending_ui.name = "VendingUI"
		world.vending_ui.set_script(vending_script)
		world.ui_layer.add_child(world.vending_ui)

	if world.vending_ui.has_method("setup"):
		world.vending_ui.setup(world, world.ui_layer)


func setup_safe_ui():
	if world.ui_layer == null:
		return

	world.safe_ui = world.ui_layer.get_node_or_null("SafeUI")

	if world.safe_ui == null:
		var safe_script = preload("res://Scripts/safe_ui.gd")
		world.safe_ui = Control.new()
		world.safe_ui.name = "SafeUI"
		world.safe_ui.set_script(safe_script)
		world.ui_layer.add_child(world.safe_ui)

	if world.safe_ui.has_method("setup"):
		world.safe_ui.setup(world, world.ui_layer)


func setup_fish_monger_ui():
	if world.ui_layer == null:
		return

	world.fish_monger_ui = world.ui_layer.get_node_or_null("FishMongerUI")

	if world.fish_monger_ui == null:
		var fish_monger_script = preload("res://Scripts/ui/fish_monger_ui.gd")
		world.fish_monger_ui = Control.new()
		world.fish_monger_ui.name = "FishMongerUI"
		world.fish_monger_ui.set_script(fish_monger_script)
		world.ui_layer.add_child(world.fish_monger_ui)

	if world.fish_monger_ui.has_method("setup"):
		world.fish_monger_ui.setup(world, world.ui_layer)


func open_vending_ui(grid_pos: Vector2i):
	close_conflicting_modal_ui("vending")
	close_shop()
	close_crafting()
	close_furnace()
	close_sign()
	close_safe_ui()
	close_fish_monger_ui()
	world.close_inventory_window()

	if world.vending_ui != null and world.vending_ui.has_method("open_vending"):
		world.vending_ui.open_vending(grid_pos)


func close_vending_ui():
	if world.vending_ui != null and world.vending_ui.has_method("close_vending"):
		world.vending_ui.close_vending()


func is_vending_open() -> bool:
	if world.vending_ui != null and world.vending_ui.has_method("is_vending_open"):
		return world.vending_ui.is_vending_open()

	return false


func open_safe_ui(grid_pos: Vector2i):
	close_conflicting_modal_ui("safe")
	close_shop()
	close_crafting()
	close_furnace()
	close_sign()
	close_vending_ui()
	close_fish_monger_ui()
	world.close_inventory_window()

	if world.safe_ui != null and world.safe_ui.has_method("open_safe"):
		world.safe_ui.open_safe(grid_pos)


func close_safe_ui():
	if world.safe_ui != null and world.safe_ui.has_method("close_safe"):
		world.safe_ui.close_safe()


func is_safe_open() -> bool:
	if world.safe_ui != null and world.safe_ui.has_method("is_safe_open"):
		return world.safe_ui.is_safe_open()

	return false


func open_fish_monger_ui(grid_pos: Vector2i):
	close_conflicting_modal_ui("fish_monger")
	close_shop()
	close_crafting()
	close_furnace()
	close_sign()
	close_vending_ui()
	close_safe_ui()
	world.close_inventory_window()

	if world.fish_monger_ui == null:
		setup_fish_monger_ui()

	if world.fish_monger_manager != null and world.fish_monger_manager.has_method("open_fish_monger"):
		world.fish_monger_manager.open_fish_monger(grid_pos)


func close_fish_monger_ui():
	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("close_fish_monger"):
		world.fish_monger_ui.close_fish_monger()


func is_fish_monger_open() -> bool:
	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("is_fish_monger_open"):
		return world.fish_monger_ui.is_fish_monger_open()

	return false


func close_conflicting_modal_ui(skip: String = ""):
	if skip != "chat":
		close_chat_panel()
	if skip != "notification":
		close_notification_panel()
	if skip != "shop":
		close_shop()
	if skip != "crafting":
		close_crafting()
	if skip != "furnace":
		close_furnace()
	if skip != "sign":
		close_sign()
	if skip != "world_lock":
		close_world_lock_ui()
	if skip != "vending":
		close_vending_ui()
	if skip != "safe":
		close_safe_ui()
	if skip != "fish_monger":
		close_fish_monger_ui()
	if skip != "player_menu":
		close_player_menu()
	if skip != "game_menu":
		close_game_menu()
	if skip != "friends":
		close_friends_panel()
	if skip != "developer":
		close_developer_panel()
	if skip != "trade" and is_trade_open():
		cancel_trade_ui()
	if skip != "inventory":
		world.close_inventory_window()


func update_fish_monger_ui():
	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("refresh") and is_fish_monger_open():
		world.fish_monger_ui.refresh()


func open_developer_panel():
	if world.developer_panel_ui == null:
		setup_developer_panel_ui()

	close_conflicting_modal_ui("developer")

	if world.developer_panel_ui != null and world.developer_panel_ui.has_method("open_panel"):
		world.developer_panel_ui.open_panel()


func close_developer_panel():
	if world.developer_panel_ui != null and world.developer_panel_ui.has_method("close_panel"):
		world.developer_panel_ui.close_panel()


func toggle_developer_panel():
	if world.developer_panel_ui == null:
		setup_developer_panel_ui()

	if is_developer_panel_open():
		close_developer_panel()
	else:
		open_developer_panel()


func is_developer_panel_open() -> bool:
	if world.developer_panel_ui != null and world.developer_panel_ui.has_method("is_open"):
		return world.developer_panel_ui.is_open()

	return false


func toggle_player_menu():
	if world.player_menu_ui != null and world.player_menu_ui.has_method("toggle_menu"):
		world.player_menu_ui.toggle_menu()


func open_player_menu():
	close_conflicting_modal_ui("player_menu")
	if world.player_menu_ui != null and world.player_menu_ui.has_method("open_menu"):
		world.player_menu_ui.open_menu()


func close_player_menu():
	if world.player_menu_ui != null and world.player_menu_ui.has_method("close_menu"):
		world.player_menu_ui.close_menu()


func is_player_menu_open() -> bool:
	if world.player_menu_ui != null and world.player_menu_ui.has_method("is_open"):
		return world.player_menu_ui.is_open()

	return false


func toggle_game_menu():
	if world.game_menu_ui != null and world.game_menu_ui.has_method("toggle_menu"):
		world.game_menu_ui.toggle_menu()


func open_game_menu():
	close_conflicting_modal_ui("game_menu")
	if world.game_menu_ui != null and world.game_menu_ui.has_method("open_menu"):
		world.game_menu_ui.open_menu()


func close_game_menu():
	if world.game_menu_ui != null and world.game_menu_ui.has_method("close_menu"):
		world.game_menu_ui.close_menu()


func is_game_menu_open() -> bool:
	if world.game_menu_ui != null and world.game_menu_ui.has_method("is_open"):
		return world.game_menu_ui.is_open()

	return false


func open_friends_panel():
	if world.friends_ui == null:
		setup_friends_ui()

	close_conflicting_modal_ui("friends")
	if world.friends_ui != null and world.friends_ui.has_method("open_panel"):
		world.friends_ui.open_panel()


func close_friends_panel():
	if world.friends_ui != null and world.friends_ui.has_method("close_panel"):
		world.friends_ui.close_panel()


func toggle_friends_panel():
	if is_friends_panel_open():
		close_friends_panel()
	else:
		open_friends_panel()


func is_friends_panel_open() -> bool:
	if world.friends_ui != null and world.friends_ui.has_method("is_open"):
		return world.friends_ui.is_open()

	return false


func handle_trade_message(data: Dictionary):
	if world.trade_ui != null and world.trade_ui.has_method("handle_trade_message"):
		world.trade_ui.handle_trade_message(data)


func close_trade_ui():
	if world.trade_ui != null and world.trade_ui.has_method("close_trade_ui"):
		world.trade_ui.close_trade_ui()


func cancel_trade_ui():
	if world.trade_ui != null and world.trade_ui.has_method("cancel_trade_ui"):
		world.trade_ui.cancel_trade_ui()


func is_trade_open() -> bool:
	if world.trade_ui != null and world.trade_ui.has_method("is_open"):
		return world.trade_ui.is_open()

	return false


func setup_crafting_ui():
	if world.ui_layer == null:
		return

	world.crafting_ui = world.ui_layer.get_node_or_null("CraftingUI")

	if world.crafting_ui == null:
		var crafting_script = preload("res://Scripts/crafting_ui.gd")
		world.crafting_ui = Control.new()
		world.crafting_ui.name = "CraftingUI"
		world.crafting_ui.set_script(crafting_script)
		world.ui_layer.add_child(world.crafting_ui)

	if world.crafting_ui.has_method("setup"):
		world.crafting_ui.setup(world, world.ui_layer)


func open_crafting_station(grid_pos: Vector2i):
	close_conflicting_modal_ui("crafting")
	close_shop()
	close_fish_monger_ui()
	world.close_inventory_window()

	if world.crafting_ui != null and world.crafting_ui.has_method("open_crafting"):
		world.crafting_ui.open_crafting(grid_pos)


func close_crafting():
	if world.crafting_ui != null and world.crafting_ui.has_method("close_crafting"):
		world.crafting_ui.close_crafting()


func is_crafting_open() -> bool:
	if world.crafting_ui != null and world.crafting_ui.has_method("is_crafting_open"):
		return world.crafting_ui.is_crafting_open()

	return false


func update_crafting_ui():
	if not is_crafting_open():
		return
	if world.crafting_ui != null and world.crafting_ui.has_method("update_header"):
		world.crafting_ui.update_header()


func update_sign_text_visual(grid_pos: Vector2i):
	if not world.blocks.has(grid_pos):
		return

	if str(world.blocks[grid_pos]["type"]) != "sign":
		return

	var block_node = world.blocks[grid_pos]["node"]

	if block_node == null:
		return

	var legacy_label = block_node.get_node_or_null("SignHoverText")
	if legacy_label != null:
		legacy_label.queue_free()


func update_sign_hover_visibility():
	if sign_hover_label == null or not is_instance_valid(sign_hover_label):
		setup_sign_hover_label()

	if sign_hover_label == null:
		return

	if world.player == null:
		sign_hover_label.visible = false
		return

	var player_grid = world.get_player_grid_position()
	var active_sign_grid = Vector2i(999999, 999999)
	var active_sign_text = ""

	for grid_pos in world.blocks.keys():
		if str(world.blocks[grid_pos].get("type", "")) != "sign":
			continue

		var sign_text = str(world.blocks[grid_pos].get("sign_text", "")).strip_edges()
		if sign_text != "" and grid_pos == player_grid:
			active_sign_grid = grid_pos
			active_sign_text = sign_text
			break

	if active_sign_text == "":
		sign_hover_label.visible = false
		return

	var canvas_transform = world.get_viewport().get_canvas_transform()
	var world_pos = Vector2(
		active_sign_grid.x * world.BLOCK_SIZE,
		active_sign_grid.y * world.BLOCK_SIZE
	) + SIGN_HOVER_WORLD_OFFSET
	var screen_pos = canvas_transform * world_pos

	sign_hover_label.text = active_sign_text
	sign_hover_label.size = Vector2(SIGN_HOVER_LABEL_WIDTH, SIGN_HOVER_LABEL_HEIGHT)
	sign_hover_label.position = Vector2(
		screen_pos.x - SIGN_HOVER_LABEL_WIDTH / 2.0,
		screen_pos.y - SIGN_HOVER_LABEL_HEIGHT / 2.0
	)
	sign_hover_label.visible = true


func refresh_all_sign_text_visuals():
	for grid_pos in world.blocks.keys():
		if str(world.blocks[grid_pos].get("type", "")) == "sign":
			update_sign_text_visual(grid_pos)


func is_sign_block(block_type: String) -> bool:
	return block_type == "sign"


func setup_sign_ui():
	if world.ui_layer == null:
		return

	world.sign_ui = world.ui_layer.get_node_or_null("SignUI")

	if world.sign_ui == null:
		var sign_script = preload("res://Scripts/sign_ui.gd")
		world.sign_ui = Control.new()
		world.sign_ui.name = "SignUI"
		world.sign_ui.set_script(sign_script)
		world.ui_layer.add_child(world.sign_ui)

	if world.sign_ui.has_method("setup"):
		world.sign_ui.setup(world, world.ui_layer)


func open_sign_editor(grid_pos: Vector2i):
	close_conflicting_modal_ui("sign")
	close_shop()
	close_crafting()
	close_furnace()
	close_fish_monger_ui()
	world.close_inventory_window()

	var current_text = ""

	if world.blocks.has(grid_pos):
		current_text = str(world.blocks[grid_pos].get("sign_text", ""))

	if world.sign_ui != null and world.sign_ui.has_method("open_sign"):
		world.sign_ui.open_sign(grid_pos, current_text)


func set_sign_text(grid_pos: Vector2i, text: String):
	if not world.blocks.has(grid_pos):
		return

	if str(world.blocks[grid_pos]["type"]) != "sign":
		return

	world.blocks[grid_pos]["sign_text"] = text.strip_edges()
	update_sign_text_visual(grid_pos)
	send_network_sign_text(grid_pos, str(world.blocks[grid_pos]["sign_text"]))

	if world.blocks[grid_pos]["sign_text"] == "":
		show_notification("Sign cleared.")
	else:
		show_notification("Sign saved.")


func send_network_sign_text(grid_pos: Vector2i, text: String):
	if world == null:
		return

	var applying_network_update = world.get("applying_network_world_update")
	if applying_network_update != null and bool(applying_network_update):
		return

	var network = world.get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_world_interaction_update"):
		network.send_world_interaction_update({
			"action": "sign_text",
			"x": grid_pos.x,
			"y": grid_pos.y,
			"text": text
		}, world.current_world_name)


func close_sign():
	if world.sign_ui != null and world.sign_ui.has_method("close_sign"):
		world.sign_ui.close_sign()


func is_sign_open() -> bool:
	if world.sign_ui != null and world.sign_ui.has_method("is_sign_open"):
		return world.sign_ui.is_sign_open()

	return false


func is_sign_text_focused() -> bool:
	if world.sign_ui != null and world.sign_ui.has_method("is_sign_text_focused"):
		return world.sign_ui.is_sign_text_focused()

	return false


func setup_furnace_ui():
	if world.ui_layer == null:
		return

	world.furnace_ui = world.ui_layer.get_node_or_null("FurnaceUI")

	if world.furnace_ui == null:
		var furnace_script = preload("res://Scripts/furnace_ui.gd")
		world.furnace_ui = Control.new()
		world.furnace_ui.name = "FurnaceUI"
		world.furnace_ui.set_script(furnace_script)
		world.ui_layer.add_child(world.furnace_ui)

	if world.furnace_ui.has_method("setup"):
		world.furnace_ui.setup(world, world.ui_layer)


func open_furnace_station(grid_pos: Vector2i):
	close_conflicting_modal_ui("furnace")
	close_shop()
	close_crafting()
	close_fish_monger_ui()
	world.close_inventory_window()

	if world.furnace_ui != null and world.furnace_ui.has_method("open_furnace"):
		world.furnace_ui.open_furnace(grid_pos)


func close_furnace():
	if world.furnace_ui != null and world.furnace_ui.has_method("close_furnace"):
		world.furnace_ui.close_furnace()


func is_furnace_open() -> bool:
	if world.furnace_ui != null and world.furnace_ui.has_method("is_furnace_open"):
		return world.furnace_ui.is_furnace_open()

	return false


func update_furnace_ui():
	if not is_furnace_open():
		return
	if world.furnace_ui != null and world.furnace_ui.has_method("update_header"):
		world.furnace_ui.update_header()


func setup_shop_ui():
	if world.ui_layer == null:
		return

	world.shop_ui = world.ui_layer.get_node_or_null("ShopUI")

	if world.shop_ui == null:
		var shop_script = preload("res://Scripts/shop_ui.gd")
		world.shop_ui = Control.new()
		world.shop_ui.name = "ShopUI"
		world.shop_ui.set_script(shop_script)
		world.ui_layer.add_child(world.shop_ui)

	if world.shop_ui.has_method("setup"):
		world.shop_ui.setup(world, world.ui_layer)


func update_shop_ui():
	if not is_shop_open():
		return
	if world.shop_ui != null and world.shop_ui.has_method("update_shop_info"):
		world.shop_ui.update_shop_info()


func open_shop():
	close_conflicting_modal_ui("shop")
	if world.shop_ui != null and world.shop_ui.has_method("open_shop"):
		world.shop_ui.open_shop()


func close_shop():
	if world.shop_ui != null and world.shop_ui.has_method("close_shop"):
		world.shop_ui.close_shop()


func toggle_shop():
	if is_shop_open():
		close_shop()
	else:
		open_shop()


func is_shop_open() -> bool:
	if world.shop_ui != null and world.shop_ui.has_method("is_shop_open"):
		return world.shop_ui.is_shop_open()

	return false


func setup_world_menu_ui():
	if world.ui_layer == null:
		return

	world.world_menu_ui = world.ui_layer.get_node_or_null("WorldMenuUI")

	if world.world_menu_ui == null:
		var menu_script = preload("res://Scripts/world_menu_ui.gd")
		world.world_menu_ui = Control.new()
		world.world_menu_ui.name = "WorldMenuUI"
		world.world_menu_ui.set_script(menu_script)
		world.ui_layer.add_child(world.world_menu_ui)

	if world.world_menu_ui.has_method("setup"):
		world.world_menu_ui.setup(world, world.ui_layer)


func is_world_menu_open() -> bool:
	if world.world_menu_ui != null and world.world_menu_ui.has_method("is_menu_open"):
		return world.world_menu_ui.is_menu_open()

	return false


func is_world_name_input_focused() -> bool:
	if world.world_menu_ui != null and world.world_menu_ui.has_method("is_world_name_input_focused"):
		return world.world_menu_ui.is_world_name_input_focused()

	return false


func update_inventory_label():
	# Top-left text UI removed/hidden.
	# Health, selected item, equipped item, and controls are no longer shown there.
	if world.inventory_label != null:
		world.inventory_label.text = ""
		world.inventory_label.visible = false


# ============================================================
# WORLD LOCK UI
# ============================================================

func setup_world_lock_ui():
	if world.ui_layer == null:
		return

	world.world_lock_ui = world.ui_layer.get_node_or_null("WorldLockUI")

	if world.world_lock_ui == null:
		var wl_script = load("res://Scripts/world_lock_ui.gd")
		if wl_script == null:
			if world.has_method("show_notification"):
				world.show_notification("World Lock UI script failed to load.")
			return
		if not (wl_script is Script):
			if world.has_method("show_notification"):
				world.show_notification("World Lock UI script is not valid.")
			return

		world.world_lock_ui = Control.new()
		world.world_lock_ui.name = "WorldLockUI"
		world.world_lock_ui.set_script(wl_script)
		world.ui_layer.add_child(world.world_lock_ui)

	if world.world_lock_ui.has_method("setup"):
		world.world_lock_ui.setup(world, world.ui_layer)


func open_world_lock_ui(grid_pos: Vector2i):
	close_conflicting_modal_ui("world_lock")
	close_shop()
	close_crafting()
	close_furnace()
	close_sign()
	world.close_inventory_window()

	if world.world_lock_ui != null and world.world_lock_ui.has_method("open_world_lock"):
		world.world_lock_ui.open_world_lock(grid_pos)


func close_world_lock_ui():
	if world.world_lock_ui != null and world.world_lock_ui.has_method("close_world_lock"):
		world.world_lock_ui.close_world_lock()


func is_world_lock_ui_open() -> bool:
	if world.world_lock_ui != null and world.world_lock_ui.has_method("is_world_lock_open"):
		return world.world_lock_ui.is_world_lock_open()
	return false
