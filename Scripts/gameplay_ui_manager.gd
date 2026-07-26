extends Node

var world = null
var ui_refresh_queued := false
var ui_refresh_in_progress := false
var sign_hover_label: Label = null

const CHAT_SCENE_PATH = "res://Scenes/ui/chat/ChatScene.tscn"
const DONATION_BOX_SCENE_PATH = "res://Scenes/ui/donation_box/DonationBoxGUI.tscn"
const OIL_REFINERY_SCENE_PATH = "res://Scenes/ui/oil_refinery/OilRefineryGUI.tscn"
const BATTERY_CHARGER_SCENE_PATH = "res://Scenes/ui/battery_charger/BatteryChargerGUI.tscn"
const SETTINGS_PANEL_SCENE_PATH = "res://Scenes/ui/settings/SettingsPanel.tscn"
const WORLD_LOCK_SCENE_PATH = "res://Scenes/ui/locks/WorldLockGUI.tscn"
const PLAYER_PROFILE_SCENE_PATH = "res://Scenes/ui/player_profile/PlayerProfileScene.tscn"
const SIGN_HOVER_LABEL_WIDTH = 380.0
const SIGN_HOVER_LABEL_HEIGHT = 54.0
const SIGN_HOVER_WORLD_OFFSET = Vector2(0.0, -40.0)
const SIGN_HOVER_FONT_SIZE = 24
const SIGN_HOVER_OUTLINE_SIZE = 7
const NOTIFICATION_BUBBLE_COOLDOWN := 0.42
const NOTIFICATION_DUPLICATE_WINDOW := 1.8

var last_notification_bubble_time := -999.0
var last_notification_message := ""
var last_notification_count := 0
var last_notification_time := -999.0

func setup(world_ref):
	world = world_ref
	setup_sign_hover_label()


func get_overhead_layer():
	if world == null:
		return null
	if world.has_method("get_ui_overhead_layer"):
		return world.get_ui_overhead_layer()
	if "ui_layer" in world:
		return world.ui_layer
	return null


func setup_sign_hover_label():
	var layer = get_overhead_layer()
	if world == null or layer == null:
		return

	var old_label = layer.get_node_or_null("SignHoverTextLabel")
	if old_label != null:
		old_label.queue_free()
	if "ui_layer" in world and world.ui_layer != layer:
		var old_root_label = world.ui_layer.get_node_or_null("SignHoverTextLabel")
		if old_root_label != null:
			old_root_label.queue_free()

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
	layer.add_child(sign_hover_label)

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
	if world.has_method("refresh_hotbar_live"):
		world.refresh_hotbar_live()
	else:
		world.update_hotbar()
	if not world.has_method("is_inventory_open") or world.is_inventory_open():
		if world.has_method("refresh_inventory_window_live"):
			world.refresh_inventory_window_live()
		else:
			world.update_inventory_window()
	update_shop_ui()
	update_crafting_ui()
	update_furnace_ui()
	update_fish_monger_ui()
	update_bulletin_board_ui()
	update_cctv_ui()
	update_oil_refinery_ui()
	update_battery_charger_ui()
	if world.display_ui != null and world.display_ui.has_method("refresh") and is_display_open():
		world.display_ui.refresh()
	ui_refresh_in_progress = false


func setup_chat_ui():
	if world.ui_layer == null:
		return

	world.chat_ui = world.ui_layer.get_node_or_null("ChatUI")
	if world.chat_ui != null and (world.chat_ui.scene_file_path != CHAT_SCENE_PATH or world.chat_ui.get_node_or_null("ChatPanel") == null):
		world.ui_layer.remove_child(world.chat_ui)
		world.chat_ui.queue_free()
		world.chat_ui = null

	if world.chat_ui == null:
		var chat_scene = preload("res://Scenes/ui/chat/ChatScene.tscn")
		world.chat_ui = chat_scene.instantiate()
		world.chat_ui.name = "ChatUI"
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
	remove_notification_ui_nodes()


func remove_notification_ui_nodes() -> void:
	if world == null:
		return

	if world.notification_ui != null and is_instance_valid(world.notification_ui):
		world.notification_ui.queue_free()
	world.notification_ui = null

	if world.ui_layer != null:
		remove_notification_child(world.ui_layer, "NotificationUI")
		remove_notification_child(world.ui_layer, "NotificationButton")
		remove_notification_child(world.ui_layer, "NotificationPanel")

	if world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			remove_notification_child(hud_layer, "NotificationButton")


func remove_notification_child(parent: Node, child_name: String) -> void:
	var child = parent.get_node_or_null(child_name)
	if child != null:
		child.queue_free()


func show_notification(message: String):
	return show_notification_bubble(message)


func show_level_up(progression_data: Dictionary):
	var level_before := int(progression_data.get("level_before", 1))
	var level_after := int(progression_data.get("level_after", level_before))
	var levels_gained := int(progression_data.get("levels_gained", 0))
	var title := str(progression_data.get("title", "")).strip_edges()
	if levels_gained <= 0 or level_after <= level_before:
		return

	var message := "Level " + str(level_after) + " reached!"
	if title != "":
		message = "Level " + str(level_after) + " reached: " + title + "!"
	return show_notification_bubble(message, "level_up")


func show_notification_bubble(message: String, forced_kind: String = ""):
	var clean_message: String = normalize_notification_message(message)
	if should_ignore_notification(clean_message):
		return

	var kind := get_effective_notification_kind(clean_message, forced_kind)
	var now := get_notification_time_seconds()
	if not should_show_notification_bubble(kind, now):
		return

	var chat_ui_node = get_notification_chat_ui()
	if chat_ui_node == null or not chat_ui_node.has_method("show_chat_bubble"):
		return
	if chat_ui_node.has_method("can_show_notification_bubble") and not bool(chat_ui_node.can_show_notification_bubble()):
		return

	var bubble_message := build_duplicate_notification_message(clean_message, now)
	var notification_shown := false
	if chat_ui_node.has_method("show_notification_bubble"):
		notification_shown = bool(chat_ui_node.show_notification_bubble(bubble_message))
	else:
		chat_ui_node.show_chat_bubble(bubble_message)
		notification_shown = true

	if notification_shown:
		last_notification_bubble_time = now


func get_notification_chat_ui():
	if world == null:
		return null

	if world.chat_ui == null:
		setup_chat_ui()

	if world.chat_ui != null and world.chat_ui.has_method("set_player") and "player" in world:
		var assigned_player: Variant = world.chat_ui.player if "player" in world.chat_ui else null
		if assigned_player != world.player:
			world.chat_ui.set_player(world.player)

	return world.chat_ui


func get_notification_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func build_duplicate_notification_message(clean_message: String, now: float) -> String:
	if clean_message == last_notification_message and now - last_notification_time <= NOTIFICATION_DUPLICATE_WINDOW:
		last_notification_count += 1
	else:
		last_notification_message = clean_message
		last_notification_count = 1

	last_notification_time = now
	if last_notification_count <= 1:
		return clean_message
	return clean_message + " x" + str(last_notification_count)


func should_show_notification_bubble(kind: String, now: float) -> bool:
	var clean_kind := kind.strip_edges().to_lower()
	if ["error", "warning", "trade", "reward", "level_up"].has(clean_kind):
		return true

	return now - last_notification_bubble_time >= NOTIFICATION_BUBBLE_COOLDOWN


func normalize_notification_message(message: String) -> String:
	var clean_message: String = str(message).strip_edges()
	while clean_message.find("  ") != -1:
		clean_message = clean_message.replace("  ", " ")

	var lower: String = clean_message.to_lower()
	match lower:
		"purchase sent to server.", "craft request sent to server.", "smelt request sent to server.", "developer command sent to server for confirmation.":
			return ""
		"entrance gate move sent to server.":
			return "Moving Entrance Gate..."
		"trade request sent.":
			return "Trade invite sent."
		"too far away.":
			return "I can't reach, that's too far!"
		"checkpoint saved.":
			return "I could respawn here"
		"server connection required.", "server connection required for trading.":
			return clean_message.replace("Server connection", "Connection")
		"server did not answer. try again.":
			return "Connection timed out. Try again."
		"server rejected that action.", "server did not accept safe request.":
			return "That action could not be completed."
		"server did not accept vending request.":
			return "That vending action could not be completed."
		"could not send trade item to server.":
			return "Could not add that item to the trade."
		"finishing server sign-on...":
			return "Almost ready. Try again in a moment."

	if lower.find(" sent to server") != -1 or lower.find(" request sent to server") != -1 or lower.find("server request") != -1:
		return ""

	if lower.begins_with("this pixelmania version is out of date"):
		clean_message = clean_message.replace("This PixelMania version is out of date. ", "")
		clean_message = clean_message.replace("Please update to version ", "Please update to v")
		clean_message = clean_message.replace("https://", "")
		clean_message = clean_message.replace("http://", "")

	return clean_message


func should_ignore_notification(message: String) -> bool:
	var lower := message.to_lower().strip_edges()

	if lower == "":
		return true

	if is_silent_harvest_notification(lower):
		return true

	if is_routine_world_action_message(lower):
		return true

	if is_animal_status_notification(lower):
		return true

	if lower.begins_with("hit "):
		return true

	if lower.begins_with("place ") or lower.begins_with("placed "):
		return true

	if lower.begins_with("break ") or lower.begins_with("broke ") or lower.begins_with("broken "):
		return true

	if lower.find("hit dirt") != -1 or lower.find("hit cave background") != -1:
		return true

	if lower.begins_with("zoom") or lower.find("zoom") != -1:
		return true

	if is_xp_gain_notification(lower):
		return true

	return false


func is_silent_harvest_notification(lower_message: String) -> bool:
	var clean_message := lower_message.strip_edges()
	var mentions_silent_harvest_target := clean_message.find("tackle box") != -1 \
		or clean_message.find("chicken") != -1 \
		or clean_message.find("cow") != -1 \
		or clean_message.find("tree") != -1
	if not mentions_silent_harvest_target:
		return false

	return clean_message.begins_with("harvesting ") \
		or clean_message.begins_with("harvested ") \
		or clean_message.ends_with(" harvested") \
		or clean_message.ends_with(" harvested.") \
		or clean_message.ends_with(" ready to harvest") \
		or clean_message.ends_with(" ready to harvest.") \
		or clean_message.ends_with(" is ready to harvest") \
		or clean_message.ends_with(" is ready to harvest.")


func is_animal_status_notification(lower_message: String) -> bool:
	var clean_message := lower_message.strip_edges()
	for animal_name in ["chicken", "cow", "duck"]:
		if clean_message == "harvesting " + animal_name + "..." \
			or clean_message == animal_name + " harvested." \
			or clean_message == "feeding " + animal_name + "..." \
			or clean_message == animal_name + " fed." \
			or clean_message == animal_name + " is busy..." \
			or clean_message == animal_name + " is ready to harvest." \
			or clean_message == animal_name + " is already producing.":
			return true
	return false


func is_routine_world_action_message(lower_message: String) -> bool:
	if lower_message.begins_with("breaking "):
		return true

	if lower_message.begins_with("placing "):
		return true

	if lower_message.begins_with("planting "):
		return true

	if lower_message.begins_with("splicing "):
		return true

	if lower_message.begins_with("dropping "):
		return true

	if lower_message.begins_with("trashing "):
		return true

	if lower_message.begins_with("keep breaking "):
		return true

	if lower_message == "harvesting seed-tree..." or lower_message == "moving entrance gate...":
		return true

	return false


func is_xp_gain_notification(lower_message: String) -> bool:
	var clean_message = lower_message.strip_edges()
	if not clean_message.begins_with("+"):
		return false

	var first_space = clean_message.find(" ")
	var xp_prefix: String = clean_message
	if first_space > 0:
		xp_prefix = clean_message.substr(0, first_space)

	var amount_text = xp_prefix.substr(1).strip_edges()
	return amount_text.is_valid_int() and clean_message.find("xp") != -1


func get_effective_notification_kind(message: String, forced_kind: String = "") -> String:
	var kind := forced_kind.strip_edges().to_lower()
	if kind != "":
		return kind
	return infer_notification_kind(message)


func infer_notification_kind(message: String) -> String:
	var lower := message.to_lower()

	if lower.find("trade") != -1:
		return "trade"

	if lower.find("gem") != -1 or lower.find("world lock") != -1 or lower.find(" wl") != -1 or lower.find("caught") != -1 or lower.find("opened lure") != -1:
		return "reward"

	if lower.find("cannot") != -1 or lower.find("can't") != -1 or lower.find("not enough") != -1 or lower.find("denied") != -1 or lower.find("failed") != -1 or lower.find("missing") != -1 or lower.find("not ready") != -1:
		return "error"

	if lower.find("locked") != -1 or lower.find("too far") != -1 or lower.find("required") != -1 or lower.find("remove") != -1 or lower.find("wait") != -1 or lower.find("update") != -1 or lower.find("verify") != -1 or lower.find("already") != -1:
		return "warning"

	if lower.find("equipped") != -1 or lower.find("unequipped") != -1 or lower.find("saved") != -1 or lower.find("completed") != -1 or lower.find("crafted") != -1 or lower.find("smelted") != -1 or lower.find("purchased") != -1 or lower.find("moved") != -1 or lower.find("opened") != -1 or lower.find("entered") != -1 or lower.find("planted") != -1 or lower.find("returned") != -1 or lower.find("respawned") != -1 or lower.find("reconnected") != -1:
		return "success"

	return "info"


func open_notification_panel():
	return


func close_notification_panel():
	return


func toggle_notification_panel():
	return


func is_notification_panel_open() -> bool:
	return false


func setup_player_menu_ui():
	if world.ui_layer == null:
		return

	var parent_node: Node = world.ui_layer
	if world.has_method("get_ui_modal_layer"):
		var modal_parent = world.get_ui_modal_layer()
		if modal_parent != null:
			parent_node = modal_parent

	world.player_menu_ui = parent_node.get_node_or_null("PlayerMenuUI")
	if world.player_menu_ui != null and world.player_menu_ui.scene_file_path != PLAYER_PROFILE_SCENE_PATH:
		parent_node.remove_child(world.player_menu_ui)
		world.player_menu_ui.queue_free()
		world.player_menu_ui = null

	if world.player_menu_ui == null:
		var profile_scene = load(PLAYER_PROFILE_SCENE_PATH)
		if profile_scene is PackedScene:
			world.player_menu_ui = profile_scene.instantiate()
		else:
			var menu_script = preload("res://Scripts/player_menu_ui.gd")
			world.player_menu_ui = Control.new()
			world.player_menu_ui.set_script(menu_script)
		world.player_menu_ui.name = "PlayerMenuUI"
		parent_node.add_child(world.player_menu_ui)

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


func setup_settings_panel_ui():
	if world.ui_layer == null:
		return

	var parent_node: Node = world.ui_layer
	if world.has_method("get_ui_modal_layer"):
		parent_node = world.get_ui_modal_layer()

	world.settings_panel_ui = parent_node.get_node_or_null("SettingsPanel")
	if world.settings_panel_ui != null and world.settings_panel_ui.scene_file_path != SETTINGS_PANEL_SCENE_PATH:
		parent_node.remove_child(world.settings_panel_ui)
		world.settings_panel_ui.queue_free()
		world.settings_panel_ui = null

	if world.settings_panel_ui == null:
		var settings_scene = preload("res://Scenes/ui/settings/SettingsPanel.tscn")
		world.settings_panel_ui = settings_scene.instantiate()
		world.settings_panel_ui.name = "SettingsPanel"
		world.settings_panel_ui.z_index = 220
		parent_node.add_child(world.settings_panel_ui)

	if world.settings_panel_ui.has_method("setup"):
		world.settings_panel_ui.setup(world)
	world.settings_panel_ui.visible = false


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
	if world.vending_ui != null and world.vending_ui.get_node_or_null("VendingPanel") == null:
		world.ui_layer.remove_child(world.vending_ui)
		world.vending_ui.queue_free()
		world.vending_ui = null

	if world.vending_ui == null:
		var vending_scene = preload("res://Scenes/ui/vending/VendingMachineGUI.tscn")
		world.vending_ui = vending_scene.instantiate()
		world.vending_ui.name = "VendingUI"
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


func setup_donation_box_ui():
	if world.ui_layer == null:
		return

	world.donation_box_ui = world.ui_layer.get_node_or_null("DonationBoxUI")

	if world.donation_box_ui == null:
		var donation_box_scene: PackedScene = load(DONATION_BOX_SCENE_PATH)
		if donation_box_scene == null:
			return
		world.donation_box_ui = donation_box_scene.instantiate()
		world.donation_box_ui.name = "DonationBoxUI"
		world.ui_layer.add_child(world.donation_box_ui)

	if world.donation_box_ui.has_method("setup"):
		world.donation_box_ui.setup(world, world.ui_layer)


func setup_mailbox_ui():
	if world.ui_layer == null:
		return

	world.mailbox_ui = world.ui_layer.get_node_or_null("MailboxUI")

	if world.mailbox_ui == null:
		var mailbox_script = preload("res://Scripts/mailbox_ui.gd")
		world.mailbox_ui = Control.new()
		world.mailbox_ui.name = "MailboxUI"
		world.mailbox_ui.set_script(mailbox_script)
		world.ui_layer.add_child(world.mailbox_ui)

	if world.mailbox_ui.has_method("setup"):
		world.mailbox_ui.setup(world, world.ui_layer)

func setup_bulletin_board_ui():
	if world.ui_layer == null:
		return

	world.bulletin_board_ui = world.ui_layer.get_node_or_null("BulletinBoardUI")

	if world.bulletin_board_ui == null:
		var board_script: Resource = load("res://Scripts/bulletin_board_ui.gd")
		if board_script == null:
			push_warning("Bulletin Board UI script could not be loaded.")
			return
		world.bulletin_board_ui = Control.new()
		world.bulletin_board_ui.name = "BulletinBoardUI"
		world.bulletin_board_ui.set_script(board_script)
		world.ui_layer.add_child(world.bulletin_board_ui)

	if world.bulletin_board_ui.has_method("setup"):
		world.bulletin_board_ui.setup(world, world.ui_layer)


func setup_display_ui():
	if world.ui_layer == null:
		return

	world.display_ui = world.ui_layer.get_node_or_null("DisplayUI")

	if world.display_ui == null:
		var display_script = preload("res://Scripts/display_ui.gd")
		world.display_ui = Control.new()
		world.display_ui.name = "DisplayUI"
		world.display_ui.set_script(display_script)
		world.ui_layer.add_child(world.display_ui)

	if world.display_ui.has_method("setup"):
		world.display_ui.setup(world, world.ui_layer)


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


func setup_cctv_ui():
	if world.ui_layer == null:
		return

	world.cctv_ui = world.ui_layer.get_node_or_null("CCTVUI")

	if world.cctv_ui == null:
		var cctv_script = preload("res://Scripts/cctv_ui.gd")
		world.cctv_ui = Control.new()
		world.cctv_ui.name = "CCTVUI"
		world.cctv_ui.set_script(cctv_script)
		world.ui_layer.add_child(world.cctv_ui)

	if world.cctv_ui.has_method("setup"):
		world.cctv_ui.setup(world, world.ui_layer)

func setup_oil_refinery_ui():
	if world.ui_layer == null:
		return

	world.oil_refinery_ui = world.ui_layer.get_node_or_null("OilRefineryUI")
	if world.oil_refinery_ui != null and (world.oil_refinery_ui.scene_file_path != OIL_REFINERY_SCENE_PATH or world.oil_refinery_ui.get_node_or_null("Window") == null):
		world.ui_layer.remove_child(world.oil_refinery_ui)
		world.oil_refinery_ui.queue_free()
		world.oil_refinery_ui = null

	if world.oil_refinery_ui == null:
		var oil_refinery_scene = preload("res://Scenes/ui/oil_refinery/OilRefineryGUI.tscn")
		world.oil_refinery_ui = oil_refinery_scene.instantiate()
		world.oil_refinery_ui.name = "OilRefineryUI"
		world.ui_layer.add_child(world.oil_refinery_ui)

	if world.oil_refinery_ui.has_method("setup"):
		world.oil_refinery_ui.setup(world, world.ui_layer)


func setup_battery_charger_ui():
	if world.ui_layer == null:
		return

	world.battery_charger_ui = world.ui_layer.get_node_or_null("BatteryChargerUI")
	if world.battery_charger_ui != null and (world.battery_charger_ui.scene_file_path != BATTERY_CHARGER_SCENE_PATH or world.battery_charger_ui.get_node_or_null("Window") == null):
		world.ui_layer.remove_child(world.battery_charger_ui)
		world.battery_charger_ui.queue_free()
		world.battery_charger_ui = null

	if world.battery_charger_ui == null:
		var battery_charger_scene = preload("res://Scenes/ui/battery_charger/BatteryChargerGUI.tscn")
		world.battery_charger_ui = battery_charger_scene.instantiate()
		world.battery_charger_ui.name = "BatteryChargerUI"
		world.ui_layer.add_child(world.battery_charger_ui)

	if world.battery_charger_ui.has_method("setup"):
		world.battery_charger_ui.setup(world, world.ui_layer)


func open_vending_ui(grid_pos: Vector2i):
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
	if world.safe_ui != null and world.safe_ui.has_method("open_safe"):
		world.safe_ui.open_safe(grid_pos)


func close_safe_ui():
	if world.safe_ui != null and world.safe_ui.has_method("close_safe"):
		world.safe_ui.close_safe()


func is_safe_open() -> bool:
	if world.safe_ui != null and world.safe_ui.has_method("is_safe_open"):
		return world.safe_ui.is_safe_open()

	return false


func open_donation_box_ui(grid_pos: Vector2i):
	if world.donation_box_ui == null:
		setup_donation_box_ui()

	if world.donation_box_ui != null and world.donation_box_ui.has_method("open_donation_box"):
		world.donation_box_ui.open_donation_box(grid_pos)


func close_donation_box_ui():
	if world.donation_box_ui != null and world.donation_box_ui.has_method("close_donation_box"):
		world.donation_box_ui.close_donation_box()


func is_donation_box_open() -> bool:
	if world.donation_box_ui != null and world.donation_box_ui.has_method("is_donation_box_open"):
		return world.donation_box_ui.is_donation_box_open()

	return false


func open_mailbox_ui(grid_pos: Vector2i):
	if world.mailbox_ui == null:
		setup_mailbox_ui()

	if world.mailbox_ui != null and world.mailbox_ui.has_method("open_mailbox"):
		world.mailbox_ui.open_mailbox(grid_pos)


func close_mailbox_ui():
	if world.mailbox_ui != null and world.mailbox_ui.has_method("close_mailbox"):
		world.mailbox_ui.close_mailbox()


func is_mailbox_open() -> bool:
	if world.mailbox_ui != null and world.mailbox_ui.has_method("is_mailbox_open"):
		return world.mailbox_ui.is_mailbox_open()

	return false

func open_bulletin_board_ui(grid_pos: Vector2i):
	if world.bulletin_board_ui == null:
		setup_bulletin_board_ui()

	if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("open_bulletin_board"):
		world.bulletin_board_ui.open_bulletin_board(grid_pos)


func close_bulletin_board_ui():
	if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("close_bulletin_board"):
		world.bulletin_board_ui.close_bulletin_board()


func is_bulletin_board_open() -> bool:
	if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("is_bulletin_board_open"):
		return world.bulletin_board_ui.is_bulletin_board_open()

	return false


func open_display_ui(grid_pos: Vector2i):
	if world.display_ui == null:
		setup_display_ui()

	if world.display_ui != null and world.display_ui.has_method("open_display"):
		world.display_ui.open_display(grid_pos)


func close_display_ui():
	if world.display_ui != null and world.display_ui.has_method("close_display"):
		world.display_ui.close_display()


func is_display_open() -> bool:
	if world.display_ui != null and world.display_ui.has_method("is_display_open"):
		return world.display_ui.is_display_open()

	return false


func open_fish_monger_ui(grid_pos: Vector2i):
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


func open_cctv_ui(grid_pos: Vector2i):
	if world.cctv_ui == null:
		setup_cctv_ui()

	if world.cctv_ui != null and world.cctv_ui.has_method("open_cctv"):
		world.cctv_ui.open_cctv(grid_pos)

func open_oil_refinery_ui(grid_pos: Vector2i):
	if world.oil_refinery_ui == null:
		setup_oil_refinery_ui()

	if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("open_oil_refinery"):
		world.oil_refinery_ui.open_oil_refinery(grid_pos)


func open_battery_charger_ui(grid_pos: Vector2i):
	if world.battery_charger_ui == null:
		setup_battery_charger_ui()

	if world.battery_charger_ui != null and world.battery_charger_ui.has_method("open_battery_charger"):
		world.battery_charger_ui.open_battery_charger(grid_pos)


func close_cctv_ui():
	if world.cctv_ui != null and world.cctv_ui.has_method("close_cctv"):
		world.cctv_ui.close_cctv()


func is_cctv_open() -> bool:
	if world.cctv_ui != null and world.cctv_ui.has_method("is_cctv_open"):
		return world.cctv_ui.is_cctv_open()

	return false

func close_oil_refinery_ui():
	if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("close_oil_refinery"):
		world.oil_refinery_ui.close_oil_refinery()


func close_battery_charger_ui():
	if world.battery_charger_ui != null and world.battery_charger_ui.has_method("close_battery_charger"):
		world.battery_charger_ui.close_battery_charger()


func is_oil_refinery_open() -> bool:
	if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("is_oil_refinery_open"):
		return world.oil_refinery_ui.is_oil_refinery_open()

	return false


func is_battery_charger_open() -> bool:
	if world.battery_charger_ui != null and world.battery_charger_ui.has_method("is_battery_charger_open"):
		return world.battery_charger_ui.is_battery_charger_open()

	return false


func close_conflicting_modal_ui(_skip: String = ""):
	return


func update_fish_monger_ui():
	if world.fish_monger_ui != null and world.fish_monger_ui.has_method("refresh") and is_fish_monger_open():
		world.fish_monger_ui.refresh()

func update_bulletin_board_ui():
	if world.bulletin_board_ui != null and world.bulletin_board_ui.has_method("refresh") and is_bulletin_board_open():
		world.bulletin_board_ui.refresh()


func update_cctv_ui():
	if world.cctv_ui != null and world.cctv_ui.has_method("refresh") and is_cctv_open():
		world.cctv_ui.refresh()

func update_oil_refinery_ui():
	if world.oil_refinery_ui != null and world.oil_refinery_ui.has_method("refresh") and is_oil_refinery_open():
		world.oil_refinery_ui.refresh()


func update_battery_charger_ui():
	if world.battery_charger_ui != null and world.battery_charger_ui.has_method("refresh") and is_battery_charger_open():
		world.battery_charger_ui.refresh()


func open_developer_panel():
	if world.developer_panel_ui == null:
		setup_developer_panel_ui()

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
	if world.game_menu_ui != null and world.game_menu_ui.has_method("open_menu"):
		world.game_menu_ui.open_menu()


func close_game_menu():
	if world.game_menu_ui != null and world.game_menu_ui.has_method("close_menu"):
		world.game_menu_ui.close_menu()


func is_game_menu_open() -> bool:
	if world.game_menu_ui != null and world.game_menu_ui.has_method("is_open"):
		return world.game_menu_ui.is_open()

	return false


func open_settings_panel():
	if world.settings_panel_ui == null:
		setup_settings_panel_ui()

	close_game_menu()
	if world.settings_panel_ui != null and world.settings_panel_ui.has_method("open_settings"):
		world.settings_panel_ui.open_settings()


func close_settings_panel():
	if world.settings_panel_ui != null and world.settings_panel_ui.has_method("close_settings"):
		world.settings_panel_ui.close_settings()


func is_settings_panel_open() -> bool:
	if world.settings_panel_ui != null:
		return world.settings_panel_ui.visible

	return false


func open_friends_panel():
	if world.friends_ui == null:
		setup_friends_ui()

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

	var block_data = world.blocks[grid_pos]
	if not (block_data is Dictionary):
		return

	if not world.is_sign_block(str(block_data.get("type", ""))):
		return

	var block_node = block_data.get("node", null)

	if block_node == null:
		return

	var legacy_label = block_node.get_node_or_null("SignHoverText")
	if legacy_label != null:
		legacy_label.queue_free()


func get_door_hover_text(block_data: Dictionary) -> String:
	var block_type = str(block_data.get("type", ""))
	if not world.has_method("is_door_block") or not world.is_door_block(block_type):
		return ""

	if bool(block_data.get("entrance_locked", false)):
		var can_pass := true
		if world.has_method("can_current_player_pass_door"):
			can_pass = bool(world.can_current_player_pass_door())
		elif world.has_method("can_current_player_pass_wooden_entrance"):
			can_pass = bool(world.can_current_player_pass_wooden_entrance())
		if not can_pass:
			return "Locked"

	return str(block_data.get("door_name", block_data.get("name", ""))).strip_edges()


func update_sign_hover_visibility():
	if sign_hover_label == null or not is_instance_valid(sign_hover_label):
		setup_sign_hover_label()

	if sign_hover_label == null:
		return

	if world.player == null:
		sign_hover_label.visible = false
		return

	var player_grid = world.get_player_grid_position()
	if not world.blocks.has(player_grid):
		sign_hover_label.visible = false
		return

	var block_data = world.blocks[player_grid]
	if not (block_data is Dictionary):
		sign_hover_label.visible = false
		return

	var block_type = str(block_data.get("type", ""))
	var active_sign_text = ""
	if world.is_sign_block(block_type):
		active_sign_text = str(block_data.get("sign_text", "")).strip_edges()
	elif world.has_method("is_door_block") and world.is_door_block(block_type):
		active_sign_text = get_door_hover_text(block_data)
	else:
		sign_hover_label.visible = false
		return

	if active_sign_text == "":
		sign_hover_label.visible = false
		return

	var canvas_transform = world.get_viewport().get_canvas_transform()
	var world_pos = Vector2(
		player_grid.x * world.BLOCK_SIZE,
		player_grid.y * world.BLOCK_SIZE
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
		if world.is_sign_block(str(world.blocks[grid_pos].get("type", ""))):
			update_sign_text_visual(grid_pos)


func is_sign_block(block_type: String) -> bool:
	if world != null and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("sign_block", false))

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
	var current_text = ""

	if world.blocks.has(grid_pos):
		current_text = str(world.blocks[grid_pos].get("sign_text", ""))

	if world.sign_ui != null and world.sign_ui.has_method("open_sign"):
		world.sign_ui.open_sign(grid_pos, current_text)


func set_sign_text(grid_pos: Vector2i, text: String):
	if not world.blocks.has(grid_pos):
		return

	if not world.is_sign_block(str(world.blocks[grid_pos]["type"])):
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
	if world.world_lock_ui != null and (world.world_lock_ui.scene_file_path != WORLD_LOCK_SCENE_PATH or world.world_lock_ui.get_node_or_null("Window") == null):
		world.ui_layer.remove_child(world.world_lock_ui)
		world.world_lock_ui.queue_free()
		world.world_lock_ui = null

	if world.world_lock_ui == null:
		var world_lock_scene = preload("res://Scenes/ui/locks/WorldLockGUI.tscn")
		world.world_lock_ui = world_lock_scene.instantiate()
		world.world_lock_ui.name = "WorldLockUI"
		world.ui_layer.add_child(world.world_lock_ui)

	if world.world_lock_ui.has_method("setup"):
		world.world_lock_ui.setup(world, world.ui_layer)


func open_world_lock_ui(grid_pos: Vector2i):
	if world.world_lock_ui != null and world.world_lock_ui.has_method("open_world_lock"):
		world.world_lock_ui.open_world_lock(grid_pos)


func close_world_lock_ui():
	if world.world_lock_ui != null and world.world_lock_ui.has_method("close_world_lock"):
		world.world_lock_ui.close_world_lock()


func is_world_lock_ui_open() -> bool:
	if world.world_lock_ui != null and world.world_lock_ui.has_method("is_world_lock_open"):
		return world.world_lock_ui.is_world_lock_open()
	return false
