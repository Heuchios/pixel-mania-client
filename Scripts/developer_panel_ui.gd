extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const INVENTORY_LOOKUP_PURPOSE: String = "admin_inventory_lookup"
const ITEM_INSTANCE_LOOKUP_PURPOSE: String = "admin_item_instance_lookup"
const ITEM_INSTANCE_HISTORY_LOOKUP_PURPOSE: String = "admin_item_instance_history_lookup"
const TRANSACTION_LEDGER_LOOKUP_PURPOSE: String = "admin_transaction_ledger_lookup"
const MONITORING_DASHBOARD_PURPOSE: String = "admin_monitoring_dashboard"
const INVENTORY_LOOKUP_TIMEOUT: float = 16.0
const MONITORING_DASHBOARD_TIMEOUT: float = 16.0
const DEBUG_INFO_REFRESH_SECONDS: float = 0.5
const PANEL_SIZE := Vector2(1040.0, 680.0)
const PANEL_INSET := 22.0
const BODY_Y := 136.0
const RESULT_Y := 630.0
const BODY_SIZE := Vector2(996.0, 482.0)
const ITEM_SEARCH_LIST_SIZE := Vector2(672.0, 266.0)
const ITEM_SEARCH_SCROLL_SIZE := Vector2(648.0, 242.0)
const ITEM_SEARCH_ROW_HEIGHT := 58.0
const ITEM_SEARCH_RESULT_LIMIT := 60
const INVENTORY_LIST_SIZE := Vector2(960.0, 314.0)
const INVENTORY_SCROLL_SIZE := Vector2(936.0, 290.0)
const INVENTORY_GRID_WIDTH := 916.0
const INVENTORY_LOOKUP_FIELDS = [
	{"field": "currency_inventory", "category": "currency", "label": "Currency"},
	{"field": "inventory", "category": "block", "label": "Blocks"},
	{"field": "seed_inventory", "category": "seed", "label": "Seeds"},
	{"field": "tool_inventory", "category": "tool", "label": "Tools"},
	{"field": "back_inventory", "category": "back", "label": "Back"},
	{"field": "hat_inventory", "category": "hat", "label": "Hats"},
	{"field": "hair_inventory", "category": "hair", "label": "Hair"},
	{"field": "eyewear_inventory", "category": "eyewear", "label": "Eyewear"},
	{"field": "beard_inventory", "category": "beard", "label": "Beard"},
	{"field": "shirt_inventory", "category": "shirt", "label": "Shirts"},
	{"field": "pants_inventory", "category": "pants", "label": "Pants"},
	{"field": "shoes_inventory", "category": "shoes", "label": "Shoes"},
	{"field": "ride_inventory", "category": "ride", "label": "Rides"},
	{"field": "material_inventory", "category": "material", "label": "Materials"},
	{"field": "lure_inventory", "category": "lure", "label": "Lures"},
	{"field": "fish_inventory", "category": "fish", "label": "Fish"},
]

var world = null
var ui_layer_ref = null

var dev_button = null
var overlay = null
var panel = null
var body = null
var status_label = null
var result_label = null
var confirm_panel = null
var pin_gate_panel = null
var pin_input = null
var tab_buttons: Dictionary = {}
var current_tab: String = "player"

var target_input = null
var item_input = null
var amount_input = null
var world_input = null
var x_input = null
var y_input = null
var item_search_input = null
var item_search_scroll = null
var item_search_list = null
var debug_info_label = null
var debug_info_scroll = null
var debug_info_refresh_elapsed: float = 0.0
var tilemap_audit_info_label = null
var tilemap_audit_refresh_elapsed: float = 0.0
var inventory_lookup_input = null
var inventory_lookup_status = null
var inventory_lookup_scroll = null
var inventory_lookup_grid = null
var inventory_lookup_request_id: String = ""
var inventory_lookup_request_purpose: String = ""
var inventory_lookup_requested_username: String = ""
var inventory_lookup_requested_instance_id: String = ""
var monitoring_status = null
var monitoring_scroll = null
var monitoring_grid = null
var monitoring_request_id: String = ""
var punishment_target_input = null
var punishment_duration_input = null
var punishment_world_input = null
var punishment_reason_input = null


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 245
	build_dev_button()
	build_panel()
	close_panel()


func _process(delta: float):
	update_layout()
	update_dev_button()
	if is_open():
		update_status()
		if not is_developer_allowed():
			close_panel()
			return
		if is_developer_pin_ready():
			hide_pin_gate()
		else:
			show_pin_gate()
		if current_tab == "debug":
			debug_info_refresh_elapsed += delta
			if debug_info_refresh_elapsed >= DEBUG_INFO_REFRESH_SECONDS:
				debug_info_refresh_elapsed = 0.0
				update_debug_info()
		elif current_tab == "tilemap_audit":
			tilemap_audit_refresh_elapsed += delta
			if tilemap_audit_refresh_elapsed >= DEBUG_INFO_REFRESH_SECONDS:
				tilemap_audit_refresh_elapsed = 0.0
				update_tilemap_audit_info()


func get_hud_layer() -> Node:
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			return hud_layer

	return ui_layer_ref


func build_dev_button():
	if ui_layer_ref == null:
		return
	var hud_layer = get_hud_layer()
	if hud_layer == null:
		return

	dev_button = hud_layer.get_node_or_null("DeveloperQuickButton")
	if dev_button == null and hud_layer != ui_layer_ref:
		dev_button = ui_layer_ref.get_node_or_null("DeveloperQuickButton")
	if dev_button == null:
		dev_button = Button.new()
		dev_button.name = "DeveloperQuickButton"
		hud_layer.add_child(dev_button)
	elif dev_button.get_parent() != hud_layer:
		var old_parent = dev_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(dev_button)
		hud_layer.add_child(dev_button)

	dev_button.text = "Dev"
	dev_button.size = Vector2(108, 42)
	dev_button.z_index = 187
	dev_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_yellow_button(dev_button, 16)
	if not dev_button.pressed.is_connected(toggle_panel):
		dev_button.pressed.connect(toggle_panel)


func build_panel():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.34)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Control.new()
	panel.name = "DeveloperPanel"
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	add_child(panel)

	var back = Panel.new()
	back.name = "PanelBack"
	back.position = Vector2.ZERO
	back.size = panel.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	panel.add_child(back)

	var header = Panel.new()
	header.name = "Header"
	header.position = Vector2(16, 16)
	header.size = Vector2(PANEL_SIZE.x - 32.0, 58)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.header_style())
	panel.add_child(header)

	var title = Label.new()
	title.name = "Title"
	title.text = "DEVELOPER PANEL"
	title.position = Vector2(34, 27)
	title.size = Vector2(360, 34)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 27)
	panel.add_child(title)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(PANEL_SIZE.x - 500.0, 29)
	status_label.size = Vector2(360, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(status_label, 14)
	panel.add_child(status_label)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.position = Vector2(PANEL_SIZE.x - 74.0, 26)
	close_button.size = Vector2(42, 36)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_panel)
	panel.add_child(close_button)

	build_tabs()

	body = Control.new()
	body.name = "Body"
	body.position = Vector2(PANEL_INSET, BODY_Y)
	body.size = BODY_SIZE
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(body)

	result_label = Label.new()
	result_label.name = "Result"
	result_label.position = Vector2(28, RESULT_Y)
	result_label.size = Vector2(PANEL_SIZE.x - 56.0, 28)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(result_label, 14)
	panel.add_child(result_label)

	build_current_tab()
	build_pin_gate()


func build_tabs():
	var tabs: Array[Dictionary] = [
		{"id": "player", "label": "Player Tools"},
		{"id": "items", "label": "Item/Gem Tools"},
		{"id": "inventory", "label": "Inventory"},
		{"id": "monitor", "label": "Monitor"},
		{"id": "moderation", "label": "Moderation"},
		{"id": "world", "label": "World Tools"},
		{"id": "tilemap_audit", "label": "TileMap Audit"},
		{"id": "debug", "label": "Debug Tools"},
	]

	tab_buttons.clear()
	var tab_gap: float = 10.0
	var tab_width: float = floor((BODY_SIZE.x - tab_gap * float(tabs.size() - 1)) / float(tabs.size()))
	for i in range(tabs.size()):
		var tab: Dictionary = tabs[i]
		var button: Button = Button.new()
		button.name = "Tab_" + str(tab["id"])
		button.text = str(tab["label"])
		button.position = Vector2(PANEL_INSET + float(i) * (tab_width + tab_gap), 88)
		button.size = Vector2(tab_width, 36)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_tab_pressed.bind(str(tab["id"])))
		panel.add_child(button)
		tab_buttons[str(tab["id"])] = button

	update_tab_styles()


func build_pin_gate():
	if panel == null:
		return

	pin_gate_panel = Panel.new()
	pin_gate_panel.name = "DeveloperPinGate"
	pin_gate_panel.position = Vector2((PANEL_SIZE.x - 440.0) * 0.5, 198)
	pin_gate_panel.size = Vector2(440, 240)
	pin_gate_panel.z_index = 60
	pin_gate_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pin_gate_panel.visible = false
	pin_gate_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	panel.add_child(pin_gate_panel)

	var title = Label.new()
	title.text = "DEVELOPER VERIFY"
	title.position = Vector2(22, 18)
	title.size = Vector2(396, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 24)
	pin_gate_panel.add_child(title)

	var message = Label.new()
	message.text = "Enter the server developer PIN before using powerful tools."
	message.position = Vector2(34, 62)
	message.size = Vector2(372, 48)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(message, 15)
	pin_gate_panel.add_child(message)

	pin_input = LineEdit.new()
	pin_input.placeholder_text = "Developer PIN"
	pin_input.secret = true
	pin_input.position = Vector2(62, 122)
	pin_input.size = Vector2(316, 40)
	pin_input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(pin_input, 17)
	pin_input.text_submitted.connect(func(_text): submit_developer_pin())
	pin_gate_panel.add_child(pin_input)

	var unlock = Button.new()
	unlock.text = "UNLOCK"
	unlock.position = Vector2(62, 178)
	unlock.size = Vector2(148, 42)
	PixelUIStyle.apply_yellow_button(unlock, 15)
	unlock.pressed.connect(submit_developer_pin)
	pin_gate_panel.add_child(unlock)

	var cancel = Button.new()
	cancel.text = "CLOSE"
	cancel.position = Vector2(230, 178)
	cancel.size = Vector2(148, 42)
	PixelUIStyle.apply_blue_button(cancel, 15)
	cancel.pressed.connect(close_panel)
	pin_gate_panel.add_child(cancel)


func _on_tab_pressed(tab_id: String):
	current_tab = tab_id
	update_tab_styles()
	build_current_tab()


func update_tab_styles():
	for tab_id in tab_buttons.keys():
		PixelUIStyle.apply_tab_button(tab_buttons[tab_id], str(tab_id) == current_tab, 14)


func build_current_tab():
	if body == null:
		return

	clear_confirm()
	for child in body.get_children():
		child.queue_free()

	match current_tab:
		"player":
			build_player_tab()
		"items":
			build_items_tab()
		"inventory":
			build_inventory_lookup_tab()
		"monitor":
			build_monitoring_tab()
		"moderation":
			build_moderation_tab()
		"world":
			build_world_tab()
		"tilemap_audit":
			build_tilemap_audit_tab()
		"debug":
			build_debug_tab()


func build_player_tab():
	add_section_title("Player Tools", Vector2(6, 0))
	target_input = add_input("Target username", Vector2(8, 48), Vector2(260, 38))
	x_input = add_input("Grid X", Vector2(286, 48), Vector2(120, 38))
	y_input = add_input("Grid Y", Vector2(418, 48), Vector2(120, 38))

	add_button("Teleport Self", Vector2(8, 112), Vector2(180, 42), func(): run_command("tp " + get_input_text(x_input, "0") + " " + get_input_text(y_input, "0")), true)
	add_button("Warp Target World", Vector2(204, 112), Vector2(210, 42), func(): set_result("Use the World Tools tab to warp worlds."), false)
	add_button("Heal Self", Vector2(430, 112), Vector2(150, 42), func(): run_command("heal"), false)
	add_button("Noclip", Vector2(596, 112), Vector2(140, 42), func(): run_command("noc"), true)

	add_hint("Player-to-player teleport, kick, freeze, vanish, and god mode need dedicated server endpoints before they can be safely enabled.", Vector2(8, 184), Vector2(BODY_SIZE.x - 36.0, 54))


func build_items_tab():
	add_section_title("Item And Gems", Vector2(6, 0))
	target_input = add_input("Target username", Vector2(8, 48), Vector2(230, 38))
	item_input = add_input("Item ID or name", Vector2(252, 48), Vector2(260, 38))
	amount_input = add_input("Amount", Vector2(526, 48), Vector2(120, 38))
	amount_input.text = "1"

	add_button("Give Item", Vector2(8, 112), Vector2(156, 42), func(): run_item_command("give"), true)
	add_button("Remove Item", Vector2(180, 112), Vector2(170, 42), func(): run_item_command("remove"), false)
	add_button("Give Gems", Vector2(366, 112), Vector2(156, 42), func(): run_gem_command("give"), true)
	add_button("Remove Gems", Vector2(538, 112), Vector2(170, 42), func(): run_gem_command("remove"), false)

	item_search_input = add_input("Search item IDs", Vector2(8, 190), Vector2(280, 38))
	item_search_input.text_submitted.connect(func(_submitted_text): search_items())
	add_button("Search", Vector2(8, 240), Vector2(130, 38), search_items, false)
	build_item_search_results_panel(Vector2(306, 190), ITEM_SEARCH_LIST_SIZE)
	add_item_search_empty("Search by item ID or display name.")


func build_inventory_lookup_tab():
	add_section_title("Inventory Lookup", Vector2(6, 0))
	inventory_lookup_input = add_input("Player username", Vector2(8, 48), Vector2(286, 38))
	inventory_lookup_input.text_submitted.connect(func(_text): request_inventory_lookup())
	add_button("Search", Vector2(312, 48), Vector2(130, 38), request_inventory_lookup, true)
	add_button("Instances", Vector2(458, 48), Vector2(150, 38), request_item_instance_lookup, false)
	add_button("Ledger", Vector2(624, 48), Vector2(150, 38), request_transaction_ledger_lookup, false)
	add_button("Self", Vector2(790, 48), Vector2(110, 38), fill_inventory_lookup_with_self, false)

	inventory_lookup_status = add_hint("Search shows stack counts. Instances shows PM-ITEM rows. Ledger shows transaction history.", Vector2(8, 100), Vector2(BODY_SIZE.x - 36.0, 48))

	var list_panel = Panel.new()
	list_panel.name = "InventoryLookupList"
	list_panel.position = Vector2(8, 160)
	list_panel.size = INVENTORY_LIST_SIZE
	list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	body.add_child(list_panel)

	inventory_lookup_scroll = ScrollContainer.new()
	inventory_lookup_scroll.position = Vector2(12, 12)
	inventory_lookup_scroll.size = INVENTORY_SCROLL_SIZE
	inventory_lookup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_lookup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_lookup_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_child(inventory_lookup_scroll)

	inventory_lookup_grid = GridContainer.new()
	inventory_lookup_grid.columns = 5
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, INVENTORY_SCROLL_SIZE.y)
	inventory_lookup_grid.add_theme_constant_override("h_separation", 10)
	inventory_lookup_grid.add_theme_constant_override("v_separation", 10)
	inventory_lookup_scroll.add_child(inventory_lookup_grid)

	add_inventory_lookup_empty("No inventory loaded.")


func build_monitoring_tab():
	add_section_title("Monitoring", Vector2(6, 0))
	add_button("Refresh", Vector2(8, 48), Vector2(130, 38), request_monitoring_dashboard, true)
	add_button("24h", Vector2(154, 48), Vector2(86, 38), func(): request_monitoring_dashboard(24), false)
	add_button("7d", Vector2(256, 48), Vector2(86, 38), func(): request_monitoring_dashboard(168), false)
	add_button("14d", Vector2(358, 48), Vector2(86, 38), func(): request_monitoring_dashboard(336), false)

	monitoring_status = add_hint("Refresh shows online players, world count, loop health, dupe warnings, economy gainers, and suspicious accounts.", Vector2(8, 100), Vector2(BODY_SIZE.x - 36.0, 48))

	var list_panel = Panel.new()
	list_panel.name = "MonitoringDashboardList"
	list_panel.position = Vector2(8, 160)
	list_panel.size = INVENTORY_LIST_SIZE
	list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	body.add_child(list_panel)

	monitoring_scroll = ScrollContainer.new()
	monitoring_scroll.position = Vector2(12, 12)
	monitoring_scroll.size = INVENTORY_SCROLL_SIZE
	monitoring_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	monitoring_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	monitoring_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_child(monitoring_scroll)

	monitoring_grid = GridContainer.new()
	monitoring_grid.columns = 2
	monitoring_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, INVENTORY_SCROLL_SIZE.y)
	monitoring_grid.add_theme_constant_override("h_separation", 10)
	monitoring_grid.add_theme_constant_override("v_separation", 10)
	monitoring_scroll.add_child(monitoring_grid)

	add_monitoring_empty("No monitoring data loaded.")
	call_deferred("request_monitoring_dashboard")


func build_moderation_tab():
	add_section_title("Moderation", Vector2(6, 0))
	punishment_target_input = add_input("Target username", Vector2(8, 48), Vector2(230, 38))
	punishment_duration_input = add_input("Duration: 30m, 2h, 7d, perm", Vector2(252, 48), Vector2(226, 38))
	punishment_duration_input.text = "60m"
	punishment_world_input = add_input("World for world ban", Vector2(498, 48), Vector2(210, 38))
	if world != null and "current_world_name" in world:
		punishment_world_input.text = str(world.current_world_name)

	punishment_reason_input = add_input("Reason", Vector2(8, 104), Vector2(700, 38))
	punishment_reason_input.text = "moderation action"

	add_button("Ban", Vector2(8, 168), Vector2(126, 40), func(): run_punishment_command("ban"), true)
	add_button("Mute", Vector2(150, 168), Vector2(126, 40), func(): run_punishment_command("mute"), false)
	add_button("Trade Ban", Vector2(292, 168), Vector2(150, 40), func(): run_punishment_command("tradeban"), false)
	add_button("World Ban", Vector2(458, 168), Vector2(150, 40), func(): run_punishment_command("worldban"), false)
	add_button("List Active", Vector2(624, 168), Vector2(150, 40), func(): run_punishment_command("punishments"), true)

	add_button("Unban", Vector2(8, 232), Vector2(126, 40), func(): run_punishment_command("unban"), true)
	add_button("Unmute", Vector2(150, 232), Vector2(126, 40), func(): run_punishment_command("unmute"), false)
	add_button("Untrade", Vector2(292, 232), Vector2(150, 40), func(): run_punishment_command("untradeban"), false)
	add_button("Unworld", Vector2(458, 232), Vector2(150, 40), func(): run_punishment_command("unworldban"), false)

	add_hint("Bans block login, mutes block chat/broadcast, trade bans block trades, and world bans block world entry and edits.", Vector2(8, 318), Vector2(BODY_SIZE.x - 36.0, 74))


func fill_inventory_lookup_with_self():
	if inventory_lookup_input != null:
		inventory_lookup_input.text = get_current_username()
	request_inventory_lookup()


func build_world_tab():
	add_section_title("World Tools", Vector2(6, 0))
	world_input = add_input("World name", Vector2(8, 48), Vector2(250, 38))
	if world != null and "current_world_name" in world:
		world_input.text = str(world.current_world_name)

	add_button("Warp", Vector2(278, 48), Vector2(120, 38), func(): run_command("warp " + get_input_text(world_input, "START")), true)
	add_button("Save World", Vector2(8, 116), Vector2(160, 42), func(): run_command("save"), false)
	add_button("Reload World", Vector2(184, 116), Vector2(170, 42), func(): run_command("load"), false)
	add_button("Clear Drops", Vector2(370, 116), Vector2(170, 42), func(): run_command("clear_drops"), false)
	add_button("Snapshot", Vector2(556, 116), Vector2(150, 42), func(): run_command("snapshot " + get_input_text(world_input, "START")), true)
	add_button("Clear World", Vector2(8, 188), Vector2(170, 42), func(): show_confirm("Clear blocks/drops in " + get_input_text(world_input, "START") + "?", "clear " + get_input_text(world_input, "START")), true)
	add_button("Reset World", Vector2(194, 188), Vector2(170, 42), func(): show_confirm("Reset " + get_input_text(world_input, "START") + "?", "resetworld " + get_input_text(world_input, "START")), false)

	add_hint("Dangerous world actions are still confirmed by the server and require admin/developer role.", Vector2(8, 270), Vector2(BODY_SIZE.x - 36.0, 54))


func build_debug_tab():
	add_section_title("Debug", Vector2(6, 0))
	debug_info_refresh_elapsed = 0.0
	debug_info_label = add_scroll_hint("", Vector2(8, 48), Vector2(BODY_SIZE.x - 36.0, 300))
	debug_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_button("Refresh", Vector2(8, 366), Vector2(130, 42), update_debug_info, true)
	add_button("Where", Vector2(154, 366), Vector2(130, 42), func(): run_command("where"), false)
	add_button("Admin Help", Vector2(300, 366), Vector2(150, 42), func(): run_command("adminhelp"), false)
	update_debug_info()


func build_tilemap_audit_tab():
	add_section_title("TileMap Audit", Vector2(6, 0))
	tilemap_audit_refresh_elapsed = 0.0
	tilemap_audit_info_label = add_scroll_hint("", Vector2(8, 48), Vector2(BODY_SIZE.x - 36.0, 300))
	tilemap_audit_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_button("Refresh", Vector2(8, 366), Vector2(130, 42), update_tilemap_audit_info, true)
	add_button("Where", Vector2(154, 366), Vector2(130, 42), func(): run_command("where"), false)
	add_button("Open Debug", Vector2(300, 366), Vector2(150, 42), func(): _on_tab_pressed("debug"), false)
	update_tilemap_audit_info()


func add_section_title(text: String, pos: Vector2):
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(460, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_section_title(label, 24)
	body.add_child(label)


func add_input(placeholder: String, pos: Vector2, control_size: Vector2) -> LineEdit:
	var input = LineEdit.new()
	input.placeholder_text = placeholder
	input.position = pos
	input.size = control_size
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_input(input, 17)
	body.add_child(input)
	return input


func add_button(text: String, pos: Vector2, control_size: Vector2, callback: Callable, yellow: bool) -> Button:
	var button = Button.new()
	button.text = text
	button.position = pos
	button.size = control_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if yellow:
		PixelUIStyle.apply_yellow_button(button, 15)
	else:
		PixelUIStyle.apply_blue_button(button, 15)
	button.pressed.connect(callback)
	body.add_child(button)
	return button


func add_hint(text: String, pos: Vector2, control_size: Vector2) -> Label:
	var panel_hint = Panel.new()
	panel_hint.position = pos
	panel_hint.size = control_size
	panel_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_hint.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	body.add_child(panel_hint)

	var label = Label.new()
	label.text = text
	label.position = Vector2(12, 8)
	label.size = Vector2(control_size.x - 24, control_size.y - 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(label, 14)
	panel_hint.add_child(label)
	return label


func add_scroll_hint(text: String, pos: Vector2, control_size: Vector2) -> Label:
	var panel_hint = Panel.new()
	panel_hint.position = pos
	panel_hint.size = control_size
	panel_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_hint.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	body.add_child(panel_hint)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(12, 8)
	scroll.size = Vector2(control_size.x - 24, control_size.y - 16)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_hint.add_child(scroll)

	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(scroll.size.x - 18.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(label, 14)
	scroll.add_child(label)
	debug_info_scroll = scroll
	return label


func build_item_search_results_panel(panel_pos: Vector2, panel_size: Vector2):
	var list_panel = Panel.new()
	list_panel.name = "ItemSearchResults"
	list_panel.position = panel_pos
	list_panel.size = panel_size
	list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	body.add_child(list_panel)

	item_search_scroll = ScrollContainer.new()
	item_search_scroll.position = Vector2(12, 12)
	item_search_scroll.size = Vector2(panel_size.x - 24.0, panel_size.y - 24.0)
	item_search_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_search_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	item_search_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	list_panel.add_child(item_search_scroll)

	item_search_list = VBoxContainer.new()
	item_search_list.custom_minimum_size = Vector2(item_search_scroll.size.x - 18.0, item_search_scroll.size.y)
	item_search_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_search_list.add_theme_constant_override("separation", 6)
	item_search_scroll.add_child(item_search_list)


func run_item_command(command_name: String):
	var target = get_input_text(target_input, get_current_username())
	var item_id = resolve_item_id(get_input_text(item_input, ""))
	var amount = max(1, int(get_input_text(amount_input, "1")))
	if target == "" or item_id == "":
		set_result("Enter a target player and valid item.")
		return
	run_command(command_name + " " + target + " " + item_id + " " + str(amount))


func run_gem_command(command_name: String):
	var target = get_input_text(target_input, get_current_username())
	var amount = max(1, int(get_input_text(amount_input, "1")))
	if target == "":
		set_result("Enter a target player.")
		return
	run_command(command_name + " " + target + " gem " + str(amount))


func run_punishment_command(command_name: String):
	var target = get_input_text(punishment_target_input, "")
	if target == "":
		set_result("Enter a target player.")
		return

	var duration = get_input_text(punishment_duration_input, "perm")
	if duration == "":
		duration = "perm"

	var world_name = get_input_text(punishment_world_input, "")
	if world_name == "":
		world_name = get_current_world_name()

	var reason = get_input_text(punishment_reason_input, "moderation action")
	var command_text = ""
	match command_name:
		"ban", "mute", "tradeban":
			command_text = command_name + " " + target + " " + duration + " " + reason
		"worldban":
			command_text = "worldban " + target + " " + world_name + " " + duration + " " + reason
		"unban", "unmute", "untradeban":
			command_text = command_name + " " + target + " " + reason
		"unworldban":
			command_text = "unworldban " + target + " " + world_name + " " + reason
		"punishments":
			command_text = "punishments " + target
		_:
			set_result("Unknown moderation action.")
			return

	run_command(command_text.strip_edges())


func run_command(command_text: String):
	clear_confirm()
	var clean = command_text.strip_edges()
	if clean == "":
		return
	if not is_developer_allowed():
		set_result("Developer access denied.")
		notify("Developer access denied.")
		return
	if not is_developer_pin_ready():
		show_pin_gate()
		set_result("Developer PIN required.")
		return

	if world != null and world.has_method("handle_chat_command"):
		world.handle_chat_command("/" + clean)
		set_result("Waiting for server confirmation...")
	else:
		set_result("Command system is not ready.")


func show_confirm(message: String, command_text: String):
	clear_confirm()
	confirm_panel = Panel.new()
	confirm_panel.name = "ConfirmPanel"
	confirm_panel.size = Vector2(424, 170)
	confirm_panel.position = Vector2((body.size.x - confirm_panel.size.x) * 0.5, 126)
	confirm_panel.z_index = 20
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.add_theme_stylebox_override("panel", PixelUIStyle.premium_panel_style())
	body.add_child(confirm_panel)

	var label = Label.new()
	label.text = message
	label.position = Vector2(22, 18)
	label.size = Vector2(380, 58)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(label, 18)
	confirm_panel.add_child(label)

	var confirm = Button.new()
	confirm.text = "CONFIRM"
	confirm.position = Vector2(34, 104)
	confirm.size = Vector2(160, 42)
	PixelUIStyle.apply_yellow_button(confirm, 15)
	confirm.pressed.connect(func(): run_command(command_text))
	confirm_panel.add_child(confirm)

	var cancel = Button.new()
	cancel.text = "CANCEL"
	cancel.position = Vector2(230, 104)
	cancel.size = Vector2(160, 42)
	PixelUIStyle.apply_blue_button(cancel, 15)
	cancel.pressed.connect(clear_confirm)
	confirm_panel.add_child(cancel)


func clear_confirm():
	if confirm_panel != null and is_instance_valid(confirm_panel):
		confirm_panel.queue_free()
	confirm_panel = null


func search_items():
	if not is_item_search_ui_ready():
		return

	var query = get_input_text(item_search_input, "").to_lower()
	if query == "":
		add_item_search_empty("Search by item ID or display name.")
		return

	var matches = collect_item_search_matches(query)
	if matches.is_empty():
		add_item_search_empty("No matching items.")
		return

	render_item_search_results(matches)


func collect_item_search_matches(query: String) -> Array:
	var matches: Array = []
	if world == null or not ("item_database" in world):
		return matches

	var query_lower = query.strip_edges().to_lower()
	if query_lower == "":
		return matches

	for raw_item_id in world.item_database.keys():
		var item_id = str(raw_item_id).strip_edges()
		if item_id == "":
			continue

		var raw_item_data: Variant = world.item_database[raw_item_id]
		if not (raw_item_data is Dictionary):
			continue

		var item_data: Dictionary = raw_item_data
		if bool(item_data.get("admin_grantable", true)) == false:
			continue

		var display_name = str(item_data.get("display_name", item_id)).strip_edges()
		if display_name == "":
			display_name = item_id

		var rank = get_item_search_match_rank(query_lower, item_id.to_lower(), display_name.to_lower())
		if rank < 0:
			continue

		var category = str(item_data.get("category", "")).strip_edges()
		if category == "":
			if item_id.ends_with("_seed"):
				category = "seed"
			else:
				category = "block"

		matches.append({
			"item_id": item_id,
			"display_name": display_name,
			"category": category,
			"category_label": format_item_instance_detail_value(category, "Item"),
			"rarity": str(item_data.get("rarity", "common")).strip_edges().to_lower(),
			"order": int(item_data.get("order", 999999)),
			"search_rank": rank,
		})

	matches.sort_custom(func(a: Dictionary, b: Dictionary):
		var rank_a = int(a.get("search_rank", 999))
		var rank_b = int(b.get("search_rank", 999))
		if rank_a != rank_b:
			return rank_a < rank_b

		var order_a = int(a.get("order", 999999))
		var order_b = int(b.get("order", 999999))
		if order_a != order_b:
			return order_a < order_b

		return str(a.get("display_name", a.get("item_id", ""))).to_lower() < str(b.get("display_name", b.get("item_id", ""))).to_lower()
	)
	return matches


func get_item_search_match_rank(query_lower: String, item_id_lower: String, display_name_lower: String) -> int:
	if item_id_lower == query_lower:
		return 0
	if display_name_lower == query_lower:
		return 1
	if item_id_lower.begins_with(query_lower):
		return 2
	if display_name_lower.begins_with(query_lower):
		return 3
	if item_id_lower.find(query_lower) != -1:
		return 4
	if display_name_lower.find(query_lower) != -1:
		return 5
	return -1


func render_item_search_results(entries: Array):
	clear_item_search_results()
	if not is_item_search_ui_ready():
		return

	var row_width = get_item_search_list_width()
	var shown_count = mini(entries.size(), ITEM_SEARCH_RESULT_LIMIT)
	for index in range(shown_count):
		var entry: Dictionary = entries[index]
		add_item_search_row(entry, Vector2(row_width, ITEM_SEARCH_ROW_HEIGHT))

	if entries.size() > shown_count:
		add_item_search_more_row(entries.size(), shown_count)

	var total_rows = shown_count + (1 if entries.size() > shown_count else 0)
	var total_height = max(item_search_scroll.size.y, float(total_rows) * (ITEM_SEARCH_ROW_HEIGHT + 6.0))
	item_search_list.custom_minimum_size = Vector2(row_width, total_height)
	item_search_list.size = item_search_list.custom_minimum_size


func add_item_search_row(entry: Dictionary, row_size: Vector2):
	if not is_item_search_ui_ready():
		return

	var row = Panel.new()
	row.custom_minimum_size = row_size
	row.size = row_size
	row.clip_contents = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = str(entry.get("display_name", entry.get("item_id", ""))) + " | " + str(entry.get("item_id", ""))
	row.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(str(entry.get("rarity", "common"))))
	item_search_list.add_child(row)

	var row_entry = entry.duplicate(true)
	row.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_item_search_result(row_entry)
	)

	var icon_frame = Panel.new()
	icon_frame.position = Vector2(8, 6)
	icon_frame.size = Vector2(46, 46)
	icon_frame.clip_contents = true
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.22),
		Color(0.82, 0.94, 1.0, 0.18),
		1, 7, 0
	))
	row.add_child(icon_frame)

	var icon = TextureRect.new()
	icon.position = Vector2(3, 3)
	icon.size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item_texture = get_item_icon_texture(str(entry.get("item_id", "")), str(entry.get("category", "")))
	if item_texture != null:
		icon.texture = item_texture
	icon_frame.add_child(icon)

	add_item_history_label(row, str(entry.get("display_name", entry.get("item_id", ""))), Vector2(66, 7), Vector2(row_size.x - 226.0, 20), 13, true)
	add_item_history_label(row, str(entry.get("category_label", "Item")) + " | " + str(entry.get("item_id", "")), Vector2(66, 29), Vector2(row_size.x - 226.0, 17), 10)
	add_item_history_label(row, format_item_instance_detail_value(str(entry.get("rarity", "common")), "Common"), Vector2(row_size.x - 148.0, 20), Vector2(132, 17), 10)


func add_item_search_more_row(total_count: int, shown_count: int):
	if not is_item_search_ui_ready():
		return

	var row_width = get_item_search_list_width()
	var more_label = Label.new()
	more_label.text = "Showing " + str(shown_count) + " of " + str(total_count) + " matches."
	more_label.custom_minimum_size = Vector2(row_width, 32.0)
	more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(more_label, 13)
	item_search_list.add_child(more_label)


func select_item_search_result(entry: Dictionary):
	var selected_item_id = str(entry.get("item_id", "")).strip_edges()
	if selected_item_id == "":
		return

	if item_input != null and is_instance_valid(item_input):
		item_input.text = selected_item_id
		item_input.caret_column = selected_item_id.length()

	set_result("Selected " + str(entry.get("display_name", selected_item_id)) + " (" + selected_item_id + ").")


func clear_item_search_results():
	if not is_item_search_ui_ready():
		return
	for child in item_search_list.get_children():
		child.queue_free()


func add_item_search_empty(message: String):
	clear_item_search_results()
	if not is_item_search_ui_ready():
		return

	var list_width = get_item_search_list_width()
	item_search_list.custom_minimum_size = Vector2(list_width, item_search_scroll.size.y)
	item_search_list.size = item_search_list.custom_minimum_size

	var empty_label = Label.new()
	empty_label.text = message
	empty_label.custom_minimum_size = Vector2(list_width, item_search_scroll.size.y)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(empty_label, 15)
	item_search_list.add_child(empty_label)


func get_item_search_list_width() -> float:
	if item_search_scroll != null and is_instance_valid(item_search_scroll):
		return max(0.0, item_search_scroll.size.x - 18.0)
	return ITEM_SEARCH_SCROLL_SIZE.x - 18.0


func is_item_search_ui_ready() -> bool:
	return item_search_list != null and is_instance_valid(item_search_list)


func request_inventory_lookup():
	clear_confirm()
	if not is_inventory_lookup_ui_ready():
		return

	var username = get_input_text(inventory_lookup_input, "")
	if username == "":
		set_inventory_lookup_status("Enter a player username.")
		add_inventory_lookup_empty("No inventory loaded.")
		return

	if not is_developer_allowed():
		set_inventory_lookup_status("Developer access denied.")
		notify("Developer access denied.")
		return

	if not is_developer_pin_ready():
		show_pin_gate()
		set_inventory_lookup_status("Developer PIN required.")
		return

	var network = get_network()
	if network == null or not network.has_method("send_player_state_request_with_context"):
		set_inventory_lookup_status("Inventory lookup is not ready.")
		return

	var request_id = str(network.send_player_state_request_with_context(username, {
		"purpose": INVENTORY_LOOKUP_PURPOSE,
		"username": username,
		"requested_username": username,
	}))

	if request_id == "":
		set_inventory_lookup_status("Could not send inventory lookup.")
		return

	inventory_lookup_request_id = request_id
	inventory_lookup_request_purpose = INVENTORY_LOOKUP_PURPOSE
	inventory_lookup_requested_username = username
	inventory_lookup_requested_instance_id = ""
	set_inventory_lookup_status("Looking up " + username + "...")
	add_inventory_lookup_empty("Waiting for server inventory...")
	set_result("Waiting for server inventory...")
	call_deferred("_wait_for_inventory_lookup", request_id, username)


func request_item_instance_lookup():
	clear_confirm()
	if not is_inventory_lookup_ui_ready():
		return

	var username = get_input_text(inventory_lookup_input, "")
	if username == "":
		set_inventory_lookup_status("Enter a player username.")
		add_inventory_lookup_empty("No player selected.")
		return

	if not is_developer_allowed():
		set_inventory_lookup_status("Developer access denied.")
		notify("Developer access denied.")
		return

	if not is_developer_pin_ready():
		show_pin_gate()
		set_inventory_lookup_status("Developer PIN required.")
		return

	var network = get_network()
	if network == null or not network.has_method("send_player_state_request_with_context"):
		set_inventory_lookup_status("Item instance lookup is not ready.")
		return

	var request_id = str(network.send_player_state_request_with_context(username, {
		"purpose": ITEM_INSTANCE_LOOKUP_PURPOSE,
		"username": username,
		"requested_username": username,
		"limit": 250,
	}))

	if request_id == "":
		set_inventory_lookup_status("Could not send item instance lookup.")
		return

	inventory_lookup_request_id = request_id
	inventory_lookup_request_purpose = ITEM_INSTANCE_LOOKUP_PURPOSE
	inventory_lookup_requested_username = username
	inventory_lookup_requested_instance_id = ""
	set_inventory_lookup_status("Loading item instances for " + username + "...")
	add_inventory_lookup_empty("Waiting for server item instances...")
	set_result("Waiting for item instances...")
	call_deferred("_wait_for_inventory_lookup", request_id, username)


func request_item_instance_history(entry: Dictionary):
	clear_confirm()
	if not is_inventory_lookup_ui_ready():
		return

	if not is_developer_allowed():
		set_inventory_lookup_status("Developer access denied.")
		notify("Developer access denied.")
		return

	if not is_developer_pin_ready():
		show_pin_gate()
		set_inventory_lookup_status("Developer PIN required.")
		return

	var username = inventory_lookup_requested_username
	if username == "":
		username = get_input_text(inventory_lookup_input, "")
	if username == "":
		username = get_current_username()

	var public_instance_id = str(entry.get("public_item_instance_id", "")).strip_edges()
	var item_instance_id = str(entry.get("item_instance_id", "")).strip_edges()
	var display_instance_id = public_instance_id if public_instance_id != "" else item_instance_id
	if display_instance_id == "":
		set_inventory_lookup_status("Item instance ID missing.")
		return

	var network = get_network()
	if network == null or not network.has_method("send_player_state_request_with_context"):
		set_inventory_lookup_status("Item history lookup is not ready.")
		return

	var request_id = str(network.send_player_state_request_with_context(username, {
		"purpose": ITEM_INSTANCE_HISTORY_LOOKUP_PURPOSE,
		"username": username,
		"requested_username": username,
		"public_item_instance_id": public_instance_id,
		"item_instance_id": item_instance_id,
		"limit": 50,
	}))

	if request_id == "":
		set_inventory_lookup_status("Could not send item history lookup.")
		return

	inventory_lookup_request_id = request_id
	inventory_lookup_request_purpose = ITEM_INSTANCE_HISTORY_LOOKUP_PURPOSE
	inventory_lookup_requested_username = username
	inventory_lookup_requested_instance_id = display_instance_id
	set_inventory_lookup_status("Loading history for " + format_item_instance_id(display_instance_id) + "...")
	add_inventory_lookup_empty("Waiting for item history...")
	set_result("Waiting for item history...")
	call_deferred("_wait_for_inventory_lookup", request_id, username)


func request_transaction_ledger_lookup(public_instance_id: String = "", item_type: String = "", transaction_type: String = ""):
	clear_confirm()
	if not is_inventory_lookup_ui_ready():
		return

	var username = get_input_text(inventory_lookup_input, "")
	var clean_public_instance_id = public_instance_id.strip_edges()
	var clean_item_type = item_type.strip_edges()
	var clean_transaction_type = transaction_type.strip_edges()
	if username == "" and clean_public_instance_id == "" and clean_item_type == "" and clean_transaction_type == "":
		set_inventory_lookup_status("Enter a player, item instance ID, item type, or transaction type.")
		add_inventory_lookup_empty("No ledger query selected.")
		return

	if not is_developer_allowed():
		set_inventory_lookup_status("Developer access denied.")
		notify("Developer access denied.")
		return

	if not is_developer_pin_ready():
		show_pin_gate()
		set_inventory_lookup_status("Developer PIN required.")
		return

	var network = get_network()
	if network == null or not network.has_method("send_player_state_request_with_context"):
		set_inventory_lookup_status("Transaction ledger lookup is not ready.")
		return

	var lookup_username = username if username != "" else get_current_username()
	var request_id = str(network.send_player_state_request_with_context(lookup_username, {
		"purpose": TRANSACTION_LEDGER_LOOKUP_PURPOSE,
		"username": lookup_username,
		"requested_username": username,
		"public_item_instance_id": clean_public_instance_id,
		"item_type": clean_item_type,
		"transaction_type": clean_transaction_type,
		"limit": 150,
	}))

	if request_id == "":
		set_inventory_lookup_status("Could not send transaction ledger lookup.")
		return

	inventory_lookup_request_id = request_id
	inventory_lookup_request_purpose = TRANSACTION_LEDGER_LOOKUP_PURPOSE
	inventory_lookup_requested_username = lookup_username
	inventory_lookup_requested_instance_id = clean_public_instance_id
	set_inventory_lookup_status("Loading transaction ledger...")
	add_inventory_lookup_empty("Waiting for transaction ledger...")
	set_result("Waiting for transaction ledger...")
	call_deferred("_wait_for_inventory_lookup", request_id, lookup_username)


func request_monitoring_dashboard(window_hours: int = 24):
	clear_confirm()
	if not is_monitoring_dashboard_ui_ready():
		return

	if not is_developer_allowed():
		set_monitoring_status("Developer access denied.")
		notify("Developer access denied.")
		return

	if not is_developer_pin_ready():
		show_pin_gate()
		set_monitoring_status("Developer PIN required.")
		return

	var network = get_network()
	if network == null or not network.has_method("send_player_state_request_with_context"):
		set_monitoring_status("Monitoring dashboard is not ready.")
		return

	var username = get_current_username()
	if username == "":
		username = "admin"
	var clean_window = clampi(window_hours, 1, 336)
	var request_id = str(network.send_player_state_request_with_context(username, {
		"purpose": MONITORING_DASHBOARD_PURPOSE,
		"username": username,
		"requested_username": username,
		"window_hours": clean_window,
		"limit": 40,
	}))

	if request_id == "":
		set_monitoring_status("Could not send monitoring request.")
		return

	monitoring_request_id = request_id
	set_monitoring_status("Loading monitoring dashboard...")
	add_monitoring_empty("Waiting for server monitoring data...")
	set_result("Waiting for monitoring dashboard...")
	call_deferred("_wait_for_monitoring_dashboard", request_id)


func _wait_for_monitoring_dashboard(request_id: String):
	await get_tree().create_timer(MONITORING_DASHBOARD_TIMEOUT).timeout
	if monitoring_request_id != request_id:
		return
	monitoring_request_id = ""
	set_monitoring_status("Monitoring dashboard timed out.")
	add_monitoring_empty("No response from the server.")
	set_result("Monitoring dashboard timed out.")


func _wait_for_inventory_lookup(request_id: String, username: String):
	await get_tree().create_timer(INVENTORY_LOOKUP_TIMEOUT).timeout
	if inventory_lookup_request_id != request_id:
		return
	if inventory_lookup_requested_username.to_lower() != username.strip_edges().to_lower():
		return
	var timed_out_purpose = inventory_lookup_request_purpose
	inventory_lookup_request_id = ""
	inventory_lookup_request_purpose = ""
	var timeout_label = "Inventory lookup"
	if timed_out_purpose == ITEM_INSTANCE_LOOKUP_PURPOSE:
		timeout_label = "Item instance lookup"
	elif timed_out_purpose == ITEM_INSTANCE_HISTORY_LOOKUP_PURPOSE:
		timeout_label = "Item history lookup"
	elif timed_out_purpose == TRANSACTION_LEDGER_LOOKUP_PURPOSE:
		timeout_label = "Transaction ledger lookup"
	set_inventory_lookup_status(timeout_label + " timed out.")
	add_inventory_lookup_empty("No response from the server.")
	set_result(timeout_label + " timed out.")


func handle_player_state_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	var request_purpose = str(request_context.get("purpose", data.get("purpose", ""))).strip_edges().to_lower()
	if request_purpose == MONITORING_DASHBOARD_PURPOSE:
		handle_monitoring_dashboard_result(request_id, data, request_context)
		return
	if request_purpose == ITEM_INSTANCE_LOOKUP_PURPOSE:
		handle_item_instance_lookup_result(request_id, data, request_context)
		return
	if request_purpose == ITEM_INSTANCE_HISTORY_LOOKUP_PURPOSE:
		handle_item_instance_history_lookup_result(request_id, data, request_context)
		return
	if request_purpose == TRANSACTION_LEDGER_LOOKUP_PURPOSE:
		handle_transaction_ledger_lookup_result(request_id, data, request_context)
		return

	if request_purpose != INVENTORY_LOOKUP_PURPOSE:
		return

	if not is_inventory_lookup_ui_ready() and is_open():
		current_tab = "inventory"
		update_tab_styles()
		build_current_tab()

	if not is_inventory_lookup_ui_ready():
		set_result("Inventory lookup returned, but the panel is not ready.")
		return

	if inventory_lookup_request_id != "" and request_id != "" and request_id != inventory_lookup_request_id:
		return

	var requested_username = str(request_context.get("requested_username", request_context.get("username", inventory_lookup_requested_username))).strip_edges()
	if requested_username == "":
		requested_username = inventory_lookup_requested_username

	var response_username = extract_inventory_lookup_username(data)
	if response_username != "" and requested_username != "" and response_username.to_lower() != requested_username.to_lower():
		set_inventory_lookup_status("Lookup response did not match the requested player.")
		set_result("Inventory lookup mismatch.")
		return

	inventory_lookup_request_id = ""
	inventory_lookup_request_purpose = ""

	if bool(data.get("requires_developer_pin", false)):
		show_pin_gate()

	if not is_inventory_lookup_success(data):
		var message = extract_inventory_lookup_message(data)
		if message == "":
			message = "Player not found."
		set_inventory_lookup_status(message)
		add_inventory_lookup_empty(message)
		set_result(message)
		return

	var player_data_value: Variant = data.get("player_data", {})
	if not (player_data_value is Dictionary):
		set_inventory_lookup_status("Server returned no inventory data.")
		add_inventory_lookup_empty("No inventory data.")
		set_result("Server returned no inventory data.")
		return

	var player_data: Dictionary = player_data_value
	var entries = collect_inventory_lookup_entries(player_data)
	render_inventory_lookup_entries(entries)

	if response_username == "":
		response_username = requested_username

	var online_text = "offline"
	if bool(data.get("online", false)):
		var world_name = str(data.get("current_world", data.get("world", ""))).strip_edges()
		online_text = "online" if world_name == "" else "online in " + world_name

	var equipped = format_inventory_lookup_equipment(player_data)
	var summary = "Inventory for " + response_username + " | " + online_text + " | " + str(entries.size()) + " non-empty stacks"
	if equipped != "":
		summary += "\n" + equipped
	set_inventory_lookup_status(summary)
	set_result("Loaded inventory for " + response_username + ".")


func handle_item_instance_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	if not is_inventory_lookup_ui_ready() and is_open():
		current_tab = "inventory"
		update_tab_styles()
		build_current_tab()

	if not is_inventory_lookup_ui_ready():
		set_result("Item instance lookup returned, but the panel is not ready.")
		return

	if inventory_lookup_request_id != "" and request_id != "" and request_id != inventory_lookup_request_id:
		return

	var requested_username = str(request_context.get("requested_username", request_context.get("username", inventory_lookup_requested_username))).strip_edges()
	if requested_username == "":
		requested_username = inventory_lookup_requested_username

	var response_username = extract_inventory_lookup_username(data)
	if response_username != "" and requested_username != "" and response_username.to_lower() != requested_username.to_lower():
		set_inventory_lookup_status("Item instance response did not match the requested player.")
		set_result("Item instance lookup mismatch.")
		return

	inventory_lookup_request_id = ""
	inventory_lookup_request_purpose = ""

	if bool(data.get("requires_developer_pin", false)):
		show_pin_gate()

	if not is_item_instance_lookup_success(data):
		var message = extract_inventory_lookup_message(data)
		if message == "":
			message = "Item instances unavailable."
		set_inventory_lookup_status(message)
		add_inventory_lookup_empty(message)
		set_result(message)
		return

	var entries = collect_item_instance_lookup_entries(data)
	render_item_instance_lookup_entries(entries)

	if response_username == "":
		response_username = requested_username

	var online_text = "offline"
	if bool(data.get("online", false)):
		var world_name = str(data.get("current_world", data.get("world", ""))).strip_edges()
		online_text = "online" if world_name == "" else "online in " + world_name

	var limit_text = ""
	var limit_value = int(data.get("item_instance_limit", 0))
	if limit_value > 0 and entries.size() >= limit_value:
		limit_text = " | showing first " + str(limit_value)

	set_inventory_lookup_status("Item instances for " + response_username + " | " + online_text + " | " + str(entries.size()) + " active rows" + limit_text)
	set_result("Loaded item instances for " + response_username + ".")


func handle_item_instance_history_lookup_result(request_id: String, data: Dictionary, _request_context: Dictionary = {}):
	if not is_inventory_lookup_ui_ready() and is_open():
		current_tab = "inventory"
		update_tab_styles()
		build_current_tab()

	if not is_inventory_lookup_ui_ready():
		set_result("Item history returned, but the panel is not ready.")
		return

	if inventory_lookup_request_id != "" and request_id != "" and request_id != inventory_lookup_request_id:
		return

	inventory_lookup_request_id = ""
	inventory_lookup_request_purpose = ""

	if bool(data.get("requires_developer_pin", false)):
		show_pin_gate()

	if not is_item_instance_history_lookup_success(data):
		var message = extract_inventory_lookup_message(data)
		if message == "":
			message = "Item history unavailable."
		set_inventory_lookup_status(message)
		add_inventory_lookup_empty(message)
		set_result(message)
		return

	var history_value: Variant = data.get("item_instance_history", {})
	if not (history_value is Dictionary):
		set_inventory_lookup_status("Server returned no item history.")
		add_inventory_lookup_empty("No item history.")
		set_result("Server returned no item history.")
		return

	var history: Dictionary = history_value
	render_item_instance_history(history)

	var item: Dictionary = {}
	var item_value: Variant = history.get("item_instance", {})
	if item_value is Dictionary:
		item = item_value
	var integrity: Dictionary = {}
	var integrity_value: Variant = history.get("integrity", {})
	if integrity_value is Dictionary:
		integrity = integrity_value
	var public_id = str(item.get("public_item_instance_id", inventory_lookup_requested_instance_id)).strip_edges()
	var current_owner_username = str(item.get("current_owner_username", "")).strip_edges()
	var source_confidence = format_item_instance_detail_value(str(item.get("source_confidence", "")).strip_edges(), "Unknown")
	var flags = format_item_history_flags(integrity.get("flags", []))
	var summary = "History for " + format_item_instance_id(public_id)
	if current_owner_username != "":
		summary += " | owner " + current_owner_username
	summary += " | source " + source_confidence
	if flags != "":
		summary += " | flags " + flags
	set_inventory_lookup_status(summary)
	set_result("Loaded item history for " + format_item_instance_id(public_id) + ".")


func handle_transaction_ledger_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	if not is_inventory_lookup_ui_ready() and is_open():
		current_tab = "inventory"
		update_tab_styles()
		build_current_tab()

	if not is_inventory_lookup_ui_ready():
		set_result("Transaction ledger returned, but the panel is not ready.")
		return

	if inventory_lookup_request_id != "" and request_id != "" and request_id != inventory_lookup_request_id:
		return

	var requested_username = str(request_context.get("requested_username", "")).strip_edges()
	var response_username = extract_inventory_lookup_username(data)
	if response_username != "" and requested_username != "" and response_username.to_lower() != requested_username.to_lower():
		set_inventory_lookup_status("Transaction ledger response did not match the requested player.")
		set_result("Transaction ledger lookup mismatch.")
		return

	inventory_lookup_request_id = ""
	inventory_lookup_request_purpose = ""

	if bool(data.get("requires_developer_pin", false)):
		show_pin_gate()

	if not is_transaction_ledger_lookup_success(data):
		var message = extract_inventory_lookup_message(data)
		if message == "":
			message = "Transaction ledger unavailable."
		set_inventory_lookup_status(message)
		add_inventory_lookup_empty(message)
		set_result(message)
		return

	var entries = collect_transaction_ledger_entries(data)
	render_transaction_ledger_entries(entries)

	var query_label = describe_transaction_ledger_query(data, requested_username)
	var limit_value = int(data.get("transaction_ledger_limit", 0))
	var limit_text = ""
	if limit_value > 0 and entries.size() >= limit_value:
		limit_text = " | showing first " + str(limit_value)
	set_inventory_lookup_status("Ledger for " + query_label + " | " + str(entries.size()) + " rows" + limit_text)
	set_result("Loaded transaction ledger.")


func handle_monitoring_dashboard_result(request_id: String, data: Dictionary, _request_context: Dictionary = {}):
	if not is_monitoring_dashboard_ui_ready() and is_open():
		current_tab = "monitor"
		update_tab_styles()
		build_current_tab()

	if not is_monitoring_dashboard_ui_ready():
		set_result("Monitoring dashboard returned, but the panel is not ready.")
		return

	if monitoring_request_id != "" and request_id != "" and request_id != monitoring_request_id:
		return

	monitoring_request_id = ""

	if bool(data.get("requires_developer_pin", false)):
		show_pin_gate()

	if not is_monitoring_dashboard_success(data):
		var message = extract_inventory_lookup_message(data)
		if message == "":
			message = "Monitoring dashboard unavailable."
		set_monitoring_status(message)
		add_monitoring_empty(message)
		set_result(message)
		return

	var dashboard_value: Variant = data.get("dashboard", {})
	if not (dashboard_value is Dictionary):
		set_monitoring_status("Server returned no monitoring dashboard.")
		add_monitoring_empty("No monitoring data.")
		set_result("Server returned no monitoring dashboard.")
		return

	var dashboard: Dictionary = dashboard_value
	render_monitoring_dashboard(dashboard)
	var live: Dictionary = get_monitoring_dict(dashboard, "live")
	var postgres: Dictionary = get_monitoring_dict(dashboard, "postgres")
	var online_count = int(live.get("authenticated_player_count", live.get("online_player_count", 0)))
	var world_count = int(postgres.get("world_count", live.get("loaded_world_count", 0)))
	var dupe_count = int(postgres.get("dupe_warning_count", 0))
	var tick_value = ""
	var tick_data: Variant = live.get("server_tick", {})
	if tick_data is Dictionary:
		tick_value = format_monitor_decimal(float(tick_data.get("event_loop_lag_ms", 0.0)), 2) + "ms lag"
	set_monitoring_status("Online " + str(online_count) + " | Worlds " + str(world_count) + " | Dupe warnings " + str(dupe_count) + (" | " + tick_value if tick_value != "" else ""))
	set_result("Loaded monitoring dashboard.")


func collect_inventory_lookup_entries(player_data: Dictionary) -> Array:
	var entries: Array = []
	for i in range(INVENTORY_LOOKUP_FIELDS.size()):
		var spec: Dictionary = INVENTORY_LOOKUP_FIELDS[i]
		var field_name = str(spec.get("field", ""))
		var category = str(spec.get("category", ""))
		var category_label = str(spec.get("label", category))
		var raw_inventory_value: Variant = player_data.get(field_name, {})
		if not (raw_inventory_value is Dictionary):
			continue
		var raw_inventory: Dictionary = raw_inventory_value

		var item_ids: Array = raw_inventory.keys()
		item_ids.sort()
		for item_key in item_ids:
			var item_id = str(item_key).strip_edges()
			if item_id == "":
				continue
			var amount = max(0, int(raw_inventory.get(item_key, 0)))
			if amount <= 0:
				continue
			entries.append({
				"item_id": item_id,
				"category": category,
				"category_label": category_label,
				"amount": amount,
				"display_name": get_item_display_name(item_id),
				"rarity": get_item_rarity(item_id, category),
				"rank": i,
			})

	entries.sort_custom(func(a: Dictionary, b: Dictionary):
		var rank_a = int(a.get("rank", 999))
		var rank_b = int(b.get("rank", 999))
		if rank_a == rank_b:
			return str(a.get("display_name", a.get("item_id", ""))).to_lower() < str(b.get("display_name", b.get("item_id", ""))).to_lower()
		return rank_a < rank_b
	)
	return entries


func collect_transaction_ledger_entries(data: Dictionary) -> Array:
	var raw_value: Variant = data.get("transaction_ledger", [])
	if not (raw_value is Array):
		return []

	var entries: Array = []
	for raw_entry in raw_value:
		if not (raw_entry is Dictionary):
			continue
		var transaction_type = str(raw_entry.get("transaction_type", "")).strip_edges()
		var item_id = str(raw_entry.get("item_type", raw_entry.get("item_id", ""))).strip_edges()
		var public_instance_id = str(raw_entry.get("public_item_instance_id", raw_entry.get("item_instance_public_id", ""))).strip_edges()
		var instance_id = str(raw_entry.get("item_instance_id", "")).strip_edges()
		var display_instance_id = public_instance_id if public_instance_id != "" else instance_id
		if transaction_type == "" and item_id == "" and display_instance_id == "":
			continue
		var category = str(raw_entry.get("item_category", raw_entry.get("category", ""))).strip_edges()
		entries.append({
			"transaction_id": str(raw_entry.get("transaction_id", "")).strip_edges(),
			"transaction_type": transaction_type,
			"status": str(raw_entry.get("status", "")).strip_edges(),
			"username": str(raw_entry.get("username", "")).strip_edges(),
			"other_username": str(raw_entry.get("other_username", "")).strip_edges(),
			"world_name": str(raw_entry.get("world_name", raw_entry.get("world", ""))).strip_edges(),
			"item_id": item_id,
			"category": category,
			"category_label": category.capitalize() if category != "" else "Item",
			"display_name": get_item_display_name(item_id),
			"rarity": get_item_rarity(item_id, category),
			"public_item_instance_id": public_instance_id,
			"item_instance_id": instance_id,
			"short_instance_id": format_item_instance_id(display_instance_id),
			"quantity": int(raw_entry.get("quantity", 0)),
			"gems_before": raw_entry.get("gems_before", null),
			"gems_after": raw_entry.get("gems_after", null),
			"inventory_before_hash": str(raw_entry.get("inventory_before_hash", "")).strip_edges(),
			"inventory_after_hash": str(raw_entry.get("inventory_after_hash", "")).strip_edges(),
			"request_id": str(raw_entry.get("request_id", "")).strip_edges(),
			"correlation_id": str(raw_entry.get("correlation_id", "")).strip_edges(),
			"source": str(raw_entry.get("source", "")).strip_edges(),
			"action": str(raw_entry.get("action", "")).strip_edges(),
			"metadata": raw_entry.get("metadata", {}),
			"server_time": format_item_instance_time(str(raw_entry.get("server_time", raw_entry.get("created_at", "")))),
		})
	return entries


func render_inventory_lookup_entries(entries: Array):
	clear_inventory_lookup_grid()
	if entries.is_empty():
		add_inventory_lookup_empty("Inventory is empty.")
		return

	if not is_inventory_lookup_ui_ready():
		return
	var columns := 5
	inventory_lookup_grid.columns = columns
	var card_width: float = 174.0
	var card_height: float = 66.0
	for entry in entries:
		add_inventory_lookup_card(entry, Vector2(card_width, card_height))

	var rows = int(ceil(float(entries.size()) / float(columns)))
	var total_height = max(INVENTORY_SCROLL_SIZE.y, float(rows) * (card_height + 10.0))
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, total_height)
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size


func collect_item_instance_lookup_entries(data: Dictionary) -> Array:
	var raw_value: Variant = data.get("item_instances", [])
	if not (raw_value is Array):
		return []

	var entries: Array = []
	for raw_entry in raw_value:
		if not (raw_entry is Dictionary):
			continue
		var item_id = str(raw_entry.get("item_type", raw_entry.get("item_id", ""))).strip_edges()
		var instance_id = str(raw_entry.get("item_instance_id", raw_entry.get("id", ""))).strip_edges()
		var public_instance_id = str(raw_entry.get("public_item_instance_id", raw_entry.get("item_instance_public_id", ""))).strip_edges()
		var display_instance_id = public_instance_id if public_instance_id != "" else instance_id
		if item_id == "" and display_instance_id == "":
			continue
		var category = str(raw_entry.get("item_category", raw_entry.get("category", ""))).strip_edges()
		entries.append({
			"item_id": item_id,
			"category": category,
			"category_label": category.capitalize() if category != "" else "Item",
			"display_name": get_item_display_name(item_id),
			"rarity": get_item_rarity(item_id, category),
			"item_instance_id": instance_id,
			"public_item_instance_id": public_instance_id,
			"short_instance_id": format_item_instance_id(display_instance_id),
			"state": str(raw_entry.get("state", "active")).strip_edges(),
			"created_by_source": str(raw_entry.get("created_by_source", "")).strip_edges(),
			"current_location": str(raw_entry.get("current_location", "")).strip_edges(),
			"created_at": format_item_instance_time(str(raw_entry.get("created_at", ""))),
			"updated_at": format_item_instance_time(str(raw_entry.get("updated_at", ""))),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary):
		var name_a = str(a.get("display_name", a.get("item_id", ""))).to_lower()
		var name_b = str(b.get("display_name", b.get("item_id", ""))).to_lower()
		if name_a == name_b:
			return str(a.get("short_instance_id", "")).to_lower() < str(b.get("short_instance_id", "")).to_lower()
		return name_a < name_b
	)
	return entries


func render_item_instance_lookup_entries(entries: Array):
	clear_inventory_lookup_grid()
	if entries.is_empty():
		add_inventory_lookup_empty("No active unique item instances found. Use Search for stackable inventory counts.")
		return

	if not is_inventory_lookup_ui_ready():
		return
	var columns := 3
	inventory_lookup_grid.columns = columns
	var card_width: float = 296.0
	var card_height: float = 118.0
	for entry in entries:
		add_item_instance_lookup_card(entry, Vector2(card_width, card_height))

	var rows = int(ceil(float(entries.size()) / float(columns)))
	var total_height = max(INVENTORY_SCROLL_SIZE.y, float(rows) * (card_height + 10.0))
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, total_height)
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size


func render_item_instance_history(history: Dictionary):
	clear_inventory_lookup_grid()
	if not is_inventory_lookup_ui_ready():
		return

	inventory_lookup_grid.columns = 1
	var width = INVENTORY_GRID_WIDTH - 8.0
	var total_height = 0.0

	add_item_instance_history_summary_card(history, Vector2(width, 138.0))
	total_height += 148.0

	var events_value: Variant = history.get("events", [])
	var events: Array = events_value if events_value is Array else []
	if events.is_empty():
		add_item_instance_history_empty_card("No timeline events recorded for this item.", Vector2(width, 62.0))
		total_height += 72.0
	else:
		for raw_event in events:
			if raw_event is Dictionary:
				add_item_instance_history_event_card(raw_event, Vector2(width, 72.0))
				total_height += 82.0

	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, max(INVENTORY_SCROLL_SIZE.y, total_height))
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size


func render_transaction_ledger_entries(entries: Array):
	clear_inventory_lookup_grid()
	if entries.is_empty():
		add_inventory_lookup_empty("No transaction ledger rows found.")
		return

	if not is_inventory_lookup_ui_ready():
		return
	var columns := 2
	inventory_lookup_grid.columns = columns
	var card_width: float = 448.0
	var card_height: float = 142.0
	for entry in entries:
		add_transaction_ledger_card(entry, Vector2(card_width, card_height))

	var rows = int(ceil(float(entries.size()) / float(columns)))
	var total_height = max(INVENTORY_SCROLL_SIZE.y, float(rows) * (card_height + 10.0))
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, total_height)
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size


func render_monitoring_dashboard(dashboard: Dictionary):
	clear_monitoring_grid()
	if not is_monitoring_dashboard_ui_ready():
		return

	monitoring_grid.columns = 2
	var card_width: float = 448.0
	var total_height: float = 0.0
	var live: Dictionary = get_monitoring_dict(dashboard, "live")
	var postgres: Dictionary = get_monitoring_dict(dashboard, "postgres")
	var tick: Dictionary = get_monitoring_dict(live, "server_tick")
	var snapshot: Dictionary = get_monitoring_dict(live, "world_snapshot_scheduler")
	var integrity: Dictionary = get_monitoring_dict(postgres, "latest_integrity_audit")

	add_monitoring_card("Server", [
		"Online: " + str(int(live.get("authenticated_player_count", live.get("online_player_count", 0)))) + " / sockets " + str(int(live.get("connected_sockets", 0))),
		"Worlds: " + str(int(postgres.get("world_count", live.get("loaded_world_count", 0)))) + " saved / " + str(int(live.get("loaded_world_count", 0))) + " loaded",
		"Players: " + str(int(postgres.get("player_count", 0))) + " saved",
		"Pending writes: " + str(int(live.get("pending_persistence_writes", 0))),
	], Vector2(card_width, 126.0), "info")
	add_monitoring_card("Loop", [
		"TPS sample: " + format_monitor_decimal(float(tick.get("tps", 0.0)), 2),
		"Tick time: " + format_monitor_decimal(float(tick.get("tick_time_ms", 0.0)), 2) + " ms",
		"Lag: " + format_monitor_decimal(float(tick.get("event_loop_lag_ms", 0.0)), 2) + " ms",
		"Max lag: " + format_monitor_decimal(float(tick.get("max_event_loop_lag_ms", 0.0)), 2) + " ms",
	], Vector2(card_width, 126.0), "info")
	total_height += 136.0

	var dupe_count = int(postgres.get("dupe_warning_count", 0))
	var severity = "ok" if dupe_count <= 0 else "warning"
	add_monitoring_card("Dupe Warnings", [
		"Active item audit issues: " + str(dupe_count),
		"Duplicate IDs: " + str(int(get_monitor_nested_number(postgres, ["dupe_summary", "duplicate_public_ids"], 0))),
		"Impossible states: " + str(int(get_monitor_nested_number(postgres, ["dupe_summary", "impossible_states"], 0))),
		"Inventory mismatches: " + str(int(get_monitor_nested_number(postgres, ["dupe_summary", "inventory_mismatches"], 0))),
	], Vector2(card_width, 126.0), severity)
	var integrity_severity = "ok"
	if int(integrity.get("critical_issues", 0)) > 0 or int(integrity.get("high_issues", 0)) > 0:
		integrity_severity = "danger"
	elif int(integrity.get("warnings", 0)) > 0:
		integrity_severity = "warning"
	add_monitoring_card("Integrity", [
		"Status: " + format_item_instance_detail_value(str(integrity.get("status", "not_run")), "Not run"),
		"Critical/high: " + str(int(integrity.get("critical_issues", 0))) + " / " + str(int(integrity.get("high_issues", 0))),
		"Warnings/notices: " + str(int(integrity.get("warnings", 0))) + " / " + str(int(integrity.get("notices", 0))),
		"Last audit: " + format_item_instance_time(str(integrity.get("created_at", ""))),
	], Vector2(card_width, 126.0), integrity_severity)
	total_height += 136.0

	add_monitoring_card("Snapshots", [
		"Enabled: " + format_monitor_bool(bool(snapshot.get("enabled", false))),
		"Interval: " + str(int(snapshot.get("interval_minutes", 0))) + " min",
		"Max/cycle: " + str(int(snapshot.get("max_worlds_per_cycle", 0))),
		"Last: " + format_item_instance_time(str(snapshot.get("last_run_at", ""))) + " | " + str(int(snapshot.get("last_world_count", 0))) + " worlds",
		"Error: " + format_monitor_blank(str(snapshot.get("last_error", "")), "none"),
	], Vector2(card_width, 144.0), "info")
	var memory: Dictionary = get_monitoring_dict(live, "memory")
	add_monitoring_card("Memory", [
		"RSS: " + format_monitor_decimal(float(memory.get("rss_mb", 0.0)), 1) + " MB",
		"Heap: " + format_monitor_decimal(float(memory.get("heap_used_mb", 0.0)), 1) + " / " + format_monitor_decimal(float(memory.get("heap_total_mb", 0.0)), 1) + " MB",
		"Uptime: " + format_monitor_duration(int(live.get("uptime_seconds", 0))),
		"Redis/Postgres: " + format_monitor_bool(bool(live.get("redis_ready", false))) + " / " + format_monitor_bool(bool(live.get("postgres_ready", false))),
	], Vector2(card_width, 144.0), "info")
	total_height += 154.0

	add_monitoring_list_card("Online Players", live.get("online_players", []), "online_player", Vector2(card_width, 184.0))
	add_monitoring_list_card("Top Gem Gainers", postgres.get("top_gem_gainers", []), "gem_gainer", Vector2(card_width, 184.0))
	total_height += 194.0

	add_monitoring_list_card("Top Item Gainers", postgres.get("top_item_gainers", []), "item_gainer", Vector2(card_width, 184.0))
	add_monitoring_list_card("Suspicious Accounts", postgres.get("suspicious_accounts", []), "suspicious", Vector2(card_width, 184.0))
	total_height += 194.0

	add_monitoring_list_card("Dupe Detail", postgres.get("dupe_warnings", []), "dupe", Vector2(card_width, 184.0))
	add_monitoring_list_card("Loaded Worlds", live.get("loaded_worlds", []), "world", Vector2(card_width, 184.0))
	total_height += 194.0

	monitoring_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, max(INVENTORY_SCROLL_SIZE.y, total_height))
	monitoring_grid.size = monitoring_grid.custom_minimum_size


func add_monitoring_card(title: String, lines: Array, card_size: Vector2, severity: String = "info"):
	if not is_monitoring_dashboard_ui_ready():
		return
	var colors = get_monitoring_severity_colors(severity)
	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(colors["fill"], colors["border"], 2, 8, 0))
	monitoring_grid.add_child(card)

	add_monitoring_label(card, title, Vector2(12, 8), Vector2(card_size.x - 24, 20), 14, true)
	var y := 34.0
	for raw_line in lines:
		var line = str(raw_line)
		if line == "":
			continue
		add_monitoring_label(card, line, Vector2(12, y), Vector2(card_size.x - 24, 17), 10, false)
		y += 18.0


func add_monitoring_list_card(title: String, raw_rows: Variant, row_type: String, card_size: Vector2):
	var rows: Array = []
	if raw_rows is Array:
		rows = raw_rows
	var lines: Array = []
	var max_rows = min(6, rows.size())
	for i in range(max_rows):
		var row_value: Variant = rows[i]
		if row_value is Dictionary:
			lines.append(format_monitoring_row(row_value, row_type))
	if lines.is_empty():
		lines.append("No rows.")
	add_monitoring_card(title, lines, card_size, "warning" if row_type == "dupe" and not rows.is_empty() else "info")


func format_monitoring_row(row: Dictionary, row_type: String) -> String:
	match row_type:
		"online_player":
			var world_name = format_monitor_blank(str(row.get("world", "")), "nowhere")
			return str(row.get("username", "player")) + " | " + world_name + " | " + str(row.get("role", "player"))
		"gem_gainer":
			return str(row.get("username", "player")) + " +" + str(row.get("total_gems_gained", "0")) + " gems | " + str(int(row.get("event_count", 0))) + " rows"
		"item_gainer":
			var item_name = get_item_display_name(str(row.get("item_type", "")))
			return str(row.get("username", "player")) + " +" + str(row.get("total_items_gained", "0")) + " " + item_name + " | " + str(int(row.get("event_count", 0))) + " rows"
		"suspicious":
			return format_monitor_blank(str(row.get("username", "")), "unknown") + " | C/H/M " + str(int(row.get("critical_count", 0))) + "/" + str(int(row.get("high_count", 0))) + "/" + str(int(row.get("medium_count", row.get("warning_count", 0)))) + " | " + str(int(row.get("event_count", 0))) + " events"
		"dupe":
			var item_id = str(row.get("item_type", "")).strip_edges()
			var item_label = get_item_display_name(item_id) if item_id != "" else format_monitor_blank(str(row.get("public_item_instance_id", "")), "item")
			return format_item_instance_detail_value(str(row.get("type", "")), "Issue") + " | " + item_label + " | " + str(row.get("severity", "warning"))
		"world":
			return str(row.get("world_name", "WORLD")) + " | online " + str(int(row.get("online_players", 0))) + " | drops " + str(int(row.get("drop_count", 0)))
		_:
			return str(row)


func add_monitoring_label(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int = 11, highlighted: bool = false):
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if highlighted:
		PixelUIStyle.apply_label_shadow(label, font_size, PixelUIStyle.GOLD_SOFT)
	else:
		PixelUIStyle.apply_small_label(label, font_size)
	parent.add_child(label)


func add_inventory_lookup_card(entry: Dictionary, card_size: Vector2):
	if not is_inventory_lookup_ui_ready():
		return

	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(str(entry.get("rarity", "common"))))
	inventory_lookup_grid.add_child(card)

	var icon_frame = Panel.new()
	icon_frame.name = "IconFrame"
	icon_frame.position = Vector2(8, 8)
	icon_frame.size = Vector2(46, 46)
	icon_frame.clip_contents = true
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.22),
		Color(0.82, 0.94, 1.0, 0.18),
		1, 7, 0
	))
	card.add_child(icon_frame)

	var icon = TextureRect.new()
	icon.position = Vector2(3, 3)
	icon.size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture = get_item_icon_texture(str(entry.get("item_id", "")), str(entry.get("category", "")))
	if texture != null:
		icon.texture = texture
	icon_frame.add_child(icon)

	var name_label = Label.new()
	name_label.text = str(entry.get("display_name", entry.get("item_id", "")))
	name_label.position = Vector2(62, 7)
	name_label.size = Vector2(card_size.x - 70, 20)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(name_label, 13)
	card.add_child(name_label)

	var meta_label = Label.new()
	meta_label.text = str(entry.get("category_label", "")) + " | " + str(entry.get("item_id", ""))
	meta_label.position = Vector2(62, 28)
	meta_label.size = Vector2(card_size.x - 70, 18)
	meta_label.clip_text = true
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(meta_label, 10)
	card.add_child(meta_label)

	var count_label = Label.new()
	count_label.text = "x" + format_inventory_lookup_count(int(entry.get("amount", 0)))
	count_label.position = Vector2(62, 45)
	count_label.size = Vector2(card_size.x - 72, 18)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.clip_text = true
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(count_label, 14, PixelUIStyle.GOLD_SOFT)
	card.add_child(count_label)


func add_item_instance_lookup_card(entry: Dictionary, card_size: Vector2):
	if not is_inventory_lookup_ui_ready():
		return

	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Open item history"
	card.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(str(entry.get("rarity", "common"))))
	inventory_lookup_grid.add_child(card)
	var clickable_entry = entry.duplicate(true)
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			request_item_instance_history(clickable_entry)
	)

	var icon_frame = Panel.new()
	icon_frame.name = "IconFrame"
	icon_frame.position = Vector2(8, 10)
	icon_frame.size = Vector2(50, 50)
	icon_frame.clip_contents = true
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.22),
		Color(0.82, 0.94, 1.0, 0.18),
		1, 7, 0
	))
	card.add_child(icon_frame)

	var icon = TextureRect.new()
	icon.position = Vector2(4, 4)
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture = get_item_icon_texture(str(entry.get("item_id", "")), str(entry.get("category", "")))
	if texture != null:
		icon.texture = texture
	icon_frame.add_child(icon)

	var name_label = Label.new()
	name_label.text = str(entry.get("display_name", entry.get("item_id", "")))
	name_label.position = Vector2(66, 7)
	name_label.size = Vector2(card_size.x - 74, 20)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(name_label, 13)
	card.add_child(name_label)

	var meta_label = Label.new()
	meta_label.text = str(entry.get("category_label", "")) + " | " + str(entry.get("item_id", ""))
	meta_label.position = Vector2(66, 28)
	meta_label.size = Vector2(card_size.x - 74, 16)
	meta_label.clip_text = true
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(meta_label, 10)
	card.add_child(meta_label)

	var id_label = Label.new()
	id_label.text = "ID " + str(entry.get("short_instance_id", ""))
	id_label.position = Vector2(66, 45)
	id_label.size = Vector2(card_size.x - 74, 16)
	id_label.clip_text = true
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(id_label, 11, PixelUIStyle.TEXT_SOFT)
	card.add_child(id_label)

	var location_label = Label.new()
	var state_text = str(entry.get("state", "active"))
	var location_text = str(entry.get("current_location", "")).strip_edges()
	var source_text = str(entry.get("created_by_source", "")).strip_edges()
	var created_text = str(entry.get("created_at", ""))
	location_label.text = "Location: " + format_item_instance_detail_value(location_text, "Unknown") + " | " + format_item_instance_detail_value(state_text, "Unknown")
	location_label.position = Vector2(8, 66)
	location_label.size = Vector2(card_size.x - 16, 15)
	location_label.clip_text = true
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(location_label, 10)
	card.add_child(location_label)

	var source_label = Label.new()
	source_label.text = "Source: " + format_item_instance_detail_value(source_text, "Unknown")
	source_label.position = Vector2(8, 82)
	source_label.size = Vector2(card_size.x - 16, 15)
	source_label.clip_text = true
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(source_label, 10)
	card.add_child(source_label)

	var created_label = Label.new()
	created_label.text = "Created: " + (created_text if created_text != "" else "Unknown")
	created_label.position = Vector2(8, 98)
	created_label.size = Vector2(card_size.x - 16, 15)
	created_label.clip_text = true
	created_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(created_label, 9)
	card.add_child(created_label)


func add_transaction_ledger_card(entry: Dictionary, card_size: Vector2):
	if not is_inventory_lookup_ui_ready():
		return

	var status = str(entry.get("status", "")).strip_edges().to_lower()
	var border = Color(0.20, 0.55, 0.86, 0.80)
	var fill = Color(0.02, 0.08, 0.12, 0.72)
	if status == "success":
		border = Color(0.25, 0.85, 0.42, 0.84)
		fill = Color(0.03, 0.12, 0.08, 0.74)
	elif status == "failed":
		border = Color(0.95, 0.22, 0.25, 0.88)
		fill = Color(0.14, 0.03, 0.04, 0.76)
	elif status == "reversed":
		border = Color(1.00, 0.70, 0.16, 0.90)
		fill = Color(0.14, 0.09, 0.02, 0.76)

	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(fill, border, 2, 8, 0))
	inventory_lookup_grid.add_child(card)

	var icon_frame = Panel.new()
	icon_frame.name = "IconFrame"
	icon_frame.position = Vector2(8, 10)
	icon_frame.size = Vector2(48, 48)
	icon_frame.clip_contents = true
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.22),
		Color(0.82, 0.94, 1.0, 0.18),
		1, 7, 0
	))
	card.add_child(icon_frame)

	var icon = TextureRect.new()
	icon.position = Vector2(4, 4)
	icon.size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture = get_item_icon_texture(str(entry.get("item_id", "")), str(entry.get("category", "")))
	if texture != null:
		icon.texture = texture
	icon_frame.add_child(icon)

	var title = format_transaction_ledger_type(str(entry.get("transaction_type", "")))
	var status_text = format_item_instance_detail_value(str(entry.get("status", "")), "Unknown")
	add_item_history_label(card, title + " | " + status_text, Vector2(66, 7), Vector2(card_size.x - 78, 20), 13, true)

	var item_name = str(entry.get("display_name", entry.get("item_id", "")))
	var quantity_text = format_transaction_quantity(int(entry.get("quantity", 0)))
	var item_line = item_name
	if quantity_text != "":
		item_line += " | " + quantity_text
	add_item_history_label(card, item_line, Vector2(66, 28), Vector2(card_size.x - 78, 17), 10)

	var instance_id = str(entry.get("short_instance_id", "")).strip_edges()
	var actor = format_item_instance_detail_value(str(entry.get("username", "")), "Server")
	var other = str(entry.get("other_username", "")).strip_edges()
	var world_name = str(entry.get("world_name", "")).strip_edges()
	var actor_line = "Actor: " + actor
	if other != "":
		actor_line += " | Other: " + other
	if world_name != "":
		actor_line += " | World: " + world_name
	add_item_history_label(card, actor_line, Vector2(8, 63), Vector2(card_size.x - 16, 16), 10)

	var id_line = "ID: " + (instance_id if instance_id != "" else "none")
	var transaction_id = format_item_instance_id(str(entry.get("transaction_id", "")))
	if transaction_id != "":
		id_line += " | Tx: " + transaction_id
	add_item_history_label(card, id_line, Vector2(8, 80), Vector2(card_size.x - 16, 16), 10)

	var source = format_item_instance_detail_value(str(entry.get("source", "")), "Unknown")
	var action = format_item_instance_detail_value(str(entry.get("action", "")), "None")
	add_item_history_label(card, "Source: " + source + " | Action: " + action, Vector2(8, 97), Vector2(card_size.x - 16, 16), 10)

	var context_parts: Array = []
	var gems = format_transaction_gems(entry.get("gems_before", null), entry.get("gems_after", null))
	if gems != "":
		context_parts.append(gems)
	var metadata = format_transaction_metadata(entry.get("metadata", {}))
	if metadata != "":
		context_parts.append(metadata)
	var context_line = join_strings(context_parts, " | ")
	if context_line == "":
		context_line = "Server time: " + format_item_instance_detail_value(str(entry.get("server_time", "")), "Unknown")
	add_item_history_label(card, context_line, Vector2(8, 114), Vector2(card_size.x - 16, 16), 9)

	var time_text = str(entry.get("server_time", "")).strip_edges()
	if time_text != "":
		add_item_history_label(card, time_text, Vector2(card_size.x - 132, 8), Vector2(120, 16), 8)


func add_item_instance_history_summary_card(history: Dictionary, card_size: Vector2):
	var item: Dictionary = {}
	var item_value: Variant = history.get("item_instance", {})
	if item_value is Dictionary:
		item = item_value
	var integrity: Dictionary = {}
	var integrity_value: Variant = history.get("integrity", {})
	if integrity_value is Dictionary:
		integrity = integrity_value
	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	inventory_lookup_grid.add_child(card)

	var public_id = str(item.get("public_item_instance_id", item.get("item_instance_id", ""))).strip_edges()
	var item_name = get_item_display_name(str(item.get("item_type", "")))
	add_item_history_label(card, item_name + " | " + str(item.get("item_category", "Item")).capitalize(), Vector2(12, 8), Vector2(card_size.x - 24, 22), 15, true)
	add_item_history_label(card, "ID: " + public_id, Vector2(12, 30), Vector2(card_size.x - 24, 18), 11)
	add_item_history_label(card, "Original owner: " + format_item_instance_detail_value(str(item.get("original_owner_username", "")), "Unknown") + " | Current owner: " + format_item_instance_detail_value(str(item.get("current_owner_username", "")), "Unknown"), Vector2(12, 50), Vector2(card_size.x - 24, 18), 11)
	add_item_history_label(card, "Location: " + format_item_instance_detail_value(str(item.get("current_location", "")), "Unknown") + " | State: " + format_item_instance_detail_value(str(item.get("state", "")), "Unknown"), Vector2(12, 70), Vector2(card_size.x - 24, 18), 11)
	add_item_history_label(card, "Origin source: " + format_item_instance_detail_value(str(item.get("origin_source", item.get("created_by_source", ""))), "Unknown") + " | Confidence: " + format_item_instance_detail_value(str(item.get("source_confidence", "")), "Unknown"), Vector2(12, 90), Vector2(card_size.x - 24, 18), 11)
	var flags = format_item_history_flags(integrity.get("flags", []))
	if flags == "":
		flags = "None"
	add_item_history_label(card, "Integrity flags: " + flags + " | Events: " + str(int(integrity.get("event_count", 0))) + " | Public ID rows: " + str(int(integrity.get("public_id_count", 0))), Vector2(12, 110), Vector2(card_size.x - 24, 18), 11)


func add_item_instance_history_event_card(event: Dictionary, card_size: Vector2):
	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.08, 0.12, 0.70),
		Color(0.18, 0.55, 0.85, 0.70),
		1, 8, 0
	))
	inventory_lookup_grid.add_child(card)

	var event_type = format_item_instance_detail_value(str(event.get("event_type", "")), "Updated")
	var created_at = format_item_instance_time(str(event.get("created_at", "")))
	add_item_history_label(card, event_type + (" | " + created_at if created_at != "" else ""), Vector2(12, 7), Vector2(card_size.x - 24, 18), 13, true)

	var from_owner = format_item_instance_detail_value(str(event.get("from_username", "")), "None")
	var to_owner = format_item_instance_detail_value(str(event.get("to_username", "")), "None")
	var from_location = format_item_instance_detail_value(str(event.get("from_location", "")), "Unknown")
	var to_location = format_item_instance_detail_value(str(event.get("to_location", "")), "Unknown")
	add_item_history_label(card, "Owner: " + from_owner + " -> " + to_owner + " | Location: " + from_location + " -> " + to_location, Vector2(12, 28), Vector2(card_size.x - 24, 16), 10)

	var source = format_item_instance_detail_value(str(event.get("source", "")), "Unknown")
	var world_name = str(event.get("world_name", "")).strip_edges()
	var metadata_text = format_item_history_metadata(event.get("metadata", {}))
	var source_line = "Source: " + source
	if world_name != "":
		source_line += " | World: " + world_name
	if metadata_text != "":
		source_line += " | " + metadata_text
	add_item_history_label(card, source_line, Vector2(12, 46), Vector2(card_size.x - 24, 16), 10)


func add_item_instance_history_empty_card(message: String, card_size: Vector2):
	var card = Panel.new()
	card.custom_minimum_size = card_size
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	inventory_lookup_grid.add_child(card)
	add_item_history_label(card, message, Vector2(12, 18), Vector2(card_size.x - 24, 24), 13, true)


func add_item_history_label(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int = 11, highlighted: bool = false):
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if highlighted:
		PixelUIStyle.apply_label_shadow(label, font_size, PixelUIStyle.GOLD_SOFT)
	else:
		PixelUIStyle.apply_small_label(label, font_size)
	parent.add_child(label)


func clear_inventory_lookup_grid():
	if not is_inventory_lookup_ui_ready():
		return
	for child in inventory_lookup_grid.get_children():
		child.queue_free()


func add_inventory_lookup_empty(message: String):
	clear_inventory_lookup_grid()
	if not is_inventory_lookup_ui_ready():
		return
	inventory_lookup_grid.columns = 1
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, INVENTORY_SCROLL_SIZE.y)
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size

	var empty_label = Label.new()
	empty_label.text = message
	empty_label.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH - 16.0, INVENTORY_SCROLL_SIZE.y - 10.0)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(empty_label, 15)
	inventory_lookup_grid.add_child(empty_label)


func clear_monitoring_grid():
	if not is_monitoring_dashboard_ui_ready():
		return
	for child in monitoring_grid.get_children():
		child.queue_free()


func add_monitoring_empty(message: String):
	clear_monitoring_grid()
	if not is_monitoring_dashboard_ui_ready():
		return
	monitoring_grid.columns = 1
	monitoring_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, INVENTORY_SCROLL_SIZE.y)
	monitoring_grid.size = monitoring_grid.custom_minimum_size

	var empty_label = Label.new()
	empty_label.text = message
	empty_label.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH - 16.0, INVENTORY_SCROLL_SIZE.y - 10.0)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(empty_label, 15)
	monitoring_grid.add_child(empty_label)


func set_monitoring_status(message: String):
	if monitoring_status != null and is_instance_valid(monitoring_status):
		monitoring_status.text = message


func is_monitoring_dashboard_ui_ready() -> bool:
	return monitoring_grid != null and is_instance_valid(monitoring_grid)


func is_monitoring_dashboard_success(data: Dictionary) -> bool:
	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	return data.has("dashboard") and data.get("dashboard") is Dictionary


func get_monitoring_severity_colors(severity: String) -> Dictionary:
	var normalized = severity.strip_edges().to_lower()
	if normalized == "ok":
		return {
			"fill": Color(0.03, 0.12, 0.08, 0.74),
			"border": Color(0.25, 0.85, 0.42, 0.84),
		}
	if normalized == "danger":
		return {
			"fill": Color(0.14, 0.03, 0.04, 0.76),
			"border": Color(0.95, 0.22, 0.25, 0.88),
		}
	if normalized == "warning":
		return {
			"fill": Color(0.14, 0.09, 0.02, 0.76),
			"border": Color(1.00, 0.70, 0.16, 0.90),
		}
	return {
		"fill": Color(0.02, 0.08, 0.12, 0.72),
		"border": Color(0.20, 0.55, 0.86, 0.80),
	}


func get_monitoring_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func get_monitor_nested_number(source: Dictionary, path: Array, fallback: float = 0.0) -> float:
	var current: Variant = source
	for key in path:
		if not (current is Dictionary):
			return fallback
		current = current.get(key, null)
	if current == null:
		return fallback
	return float(current)


func format_monitor_decimal(value: float, decimals: int = 1) -> String:
	var places = clampi(decimals, 0, 4)
	var pattern = "%." + str(places) + "f"
	return pattern % value


func format_monitor_bool(value: bool) -> String:
	return "yes" if value else "no"


func format_monitor_blank(value: String, fallback: String = "none") -> String:
	var clean = value.strip_edges()
	return fallback if clean == "" else clean


func format_monitor_duration(seconds: int) -> String:
	var remaining = max(0, seconds)
	var days = int(remaining / 86400)
	remaining = remaining % 86400
	var hours = int(remaining / 3600)
	remaining = remaining % 3600
	var minutes = int(remaining / 60)
	if days > 0:
		return str(days) + "d " + str(hours) + "h"
	if hours > 0:
		return str(hours) + "h " + str(minutes) + "m"
	return str(minutes) + "m"


func set_inventory_lookup_status(message: String):
	if inventory_lookup_status != null and is_instance_valid(inventory_lookup_status):
		inventory_lookup_status.text = message


func is_inventory_lookup_ui_ready() -> bool:
	return inventory_lookup_grid != null and is_instance_valid(inventory_lookup_grid)


func is_inventory_lookup_success(data: Dictionary) -> bool:
	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	var found_value = data.get("found", null)
	if found_value is bool and not bool(found_value):
		return false
	return data.has("player_data") and data.get("player_data") is Dictionary


func is_item_instance_lookup_success(data: Dictionary) -> bool:
	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	var found_value = data.get("found", null)
	if found_value is bool and not bool(found_value):
		return false
	return data.has("item_instances") and data.get("item_instances") is Array


func is_item_instance_history_lookup_success(data: Dictionary) -> bool:
	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	var found_value = data.get("found", null)
	if found_value is bool and not bool(found_value):
		return false
	return data.has("item_instance_history") and data.get("item_instance_history") is Dictionary


func is_transaction_ledger_lookup_success(data: Dictionary) -> bool:
	var ok_value = data.get("ok", null)
	if ok_value is bool and not bool(ok_value):
		return false
	var found_value = data.get("found", null)
	if found_value is bool and not bool(found_value):
		return false
	return data.has("transaction_ledger") and data.get("transaction_ledger") is Array


func extract_inventory_lookup_username(data: Dictionary) -> String:
	var username = str(data.get("username", data.get("account_username", data.get("name", "")))).strip_edges()
	if username != "":
		return username
	var account = data.get("account", {})
	if account is Dictionary:
		username = str(account.get("username", account.get("account_username", account.get("name", "")))).strip_edges()
		if username != "":
			return username
	var player_data = data.get("player_data", {})
	if player_data is Dictionary:
		return str(player_data.get("account_username", player_data.get("username", player_data.get("name", "")))).strip_edges()
	return ""


func extract_inventory_lookup_message(data: Dictionary) -> String:
	var message = str(data.get("message", "")).strip_edges()
	if message != "":
		return message
	var nested = data.get("data", {})
	if nested is Dictionary:
		return extract_inventory_lookup_message(nested)
	return ""


func format_inventory_lookup_equipment(player_data: Dictionary) -> String:
	var parts = []
	for spec in [
		{"label": "tool", "field": "equipped_tool"},
		{"label": "back", "field": "equipped_back_item"},
		{"label": "hat", "field": "equipped_hat_item"},
		{"label": "hair", "field": "equipped_hair_item"},
		{"label": "eyewear", "field": "equipped_eyewear_item"},
		{"label": "beard", "field": "equipped_beard_item"},
		{"label": "shirt", "field": "equipped_shirt_item"},
		{"label": "pants", "field": "equipped_pants_item"},
		{"label": "shoes", "field": "equipped_shoes_item"},
		{"label": "ride", "field": "equipped_ride_item"},
	]:
		var value = str(player_data.get(str(spec["field"]), "")).strip_edges()
		if value != "":
			parts.append(str(spec["label"]) + ": " + value)
	if parts.is_empty():
		return ""
	return "Equipped: " + join_strings(parts, ", ")


func get_item_icon_texture(item_id: String, category: String):
	if world != null and world.has_method("get_inventory_icon_texture"):
		var icon_texture = world.get_inventory_icon_texture(item_id, category)
		if icon_texture != null:
			return icon_texture
	if world != null and world.has_method("get_item_texture"):
		return world.get_item_texture(item_id, category)
	return null


func get_item_display_name(item_id: String) -> String:
	if world != null and "item_database" in world and world.item_database.has(item_id):
		var data = world.item_database[item_id]
		if data is Dictionary:
			return str(data.get("display_name", item_id))
	return item_id.capitalize()


func get_item_rarity(item_id: String, _category: String = "") -> String:
	if world != null and "item_database" in world and world.item_database.has(item_id):
		var data = world.item_database[item_id]
		if data is Dictionary:
			return str(data.get("rarity", "common")).strip_edges().to_lower()
	return "common"


func format_inventory_lookup_count(value: int) -> String:
	var digits = str(max(0, value))
	var output = ""
	var group_count = 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			output = "," + output
			group_count = 0
		output = digits.substr(i, 1) + output
		group_count += 1
	return output


func format_item_instance_id(value: String) -> String:
	var clean = value.strip_edges()
	if clean.length() <= 14:
		return clean
	return clean.substr(0, 8) + "..." + clean.substr(clean.length() - 4, 4)


func format_item_instance_time(value: String) -> String:
	var clean = value.strip_edges()
	if clean == "":
		return ""
	var normalized = clean.replace("T", " ")
	var plus_index = normalized.find("+")
	if plus_index >= 0:
		normalized = normalized.substr(0, plus_index)
	var dot_index = normalized.find(".")
	if dot_index >= 0:
		normalized = normalized.substr(0, dot_index)
	if normalized.length() > 16:
		return normalized.substr(0, 16)
	return normalized


func format_item_instance_detail_value(value: String, fallback: String = "Unknown") -> String:
	var clean = value.strip_edges()
	if clean == "":
		return fallback
	return clean.replace("_", " ").replace("-", " ").capitalize()


func format_item_history_flags(value: Variant) -> String:
	if not (value is Array):
		return ""
	var parts: Array = []
	for raw_flag in value:
		var flag = str(raw_flag).strip_edges()
		if flag == "":
			continue
		parts.append(format_item_instance_detail_value(flag, flag))
	return join_strings(parts, ", ")


func format_item_history_metadata(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var metadata: Dictionary = value
	var parts: Array = []
	for key in ["reason", "action", "actor_username", "request_id", "transaction_id"]:
		var raw = str(metadata.get(key, "")).strip_edges()
		if raw == "":
			continue
		var label = format_item_instance_detail_value(str(key), str(key))
		parts.append(label + ": " + raw)
	if parts.size() > 2:
		parts = parts.slice(0, 2)
	return join_strings(parts, " | ")


func describe_transaction_ledger_query(data: Dictionary, requested_username: String = "") -> String:
	var parts: Array = []
	var response_username = extract_inventory_lookup_username(data)
	if response_username != "":
		parts.append(response_username)
	elif requested_username.strip_edges() != "":
		parts.append(requested_username.strip_edges())

	var query_value: Variant = data.get("transaction_ledger_query", {})
	if query_value is Dictionary:
		var query: Dictionary = query_value
		var public_id = str(query.get("public_item_instance_id", data.get("item_instance_id", inventory_lookup_requested_instance_id))).strip_edges()
		if public_id != "":
			parts.append("item " + format_item_instance_id(public_id))
		var item_type = str(query.get("item_type", "")).strip_edges()
		if item_type != "":
			parts.append(item_type)
		var transaction_type = str(query.get("transaction_type", "")).strip_edges()
		if transaction_type != "":
			parts.append(format_transaction_ledger_type(transaction_type))
		var status = str(query.get("status", "")).strip_edges()
		if status != "":
			parts.append(format_item_instance_detail_value(status, status))

	if parts.is_empty():
		return "transaction ledger"
	return join_strings(parts, " | ")


func format_transaction_ledger_type(value: String) -> String:
	return format_item_instance_detail_value(value, "Ledger")


func format_transaction_quantity(value: int) -> String:
	if value == 0:
		return ""
	return "Qty " + str(value)


func format_transaction_gems(before_value: Variant, after_value: Variant) -> String:
	if before_value == null and after_value == null:
		return ""
	var before_text = "?"
	var after_text = "?"
	if before_value != null:
		before_text = format_inventory_lookup_count(int(before_value))
	if after_value != null:
		after_text = format_inventory_lookup_count(int(after_value))
	return "Gems " + before_text + " -> " + after_text


func format_transaction_metadata(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var metadata: Dictionary = value
	var parts: Array = []
	for key in ["reason", "source", "action", "actor_username", "target_username", "request_id", "correlation_id"]:
		var raw_value: Variant = metadata.get(key, "")
		var raw = ""
		if raw_value is Dictionary or raw_value is Array:
			raw = JSON.stringify(raw_value)
		else:
			raw = str(raw_value).strip_edges()
		if raw == "":
			continue
		var label = format_item_instance_detail_value(str(key), str(key))
		parts.append(label + ": " + raw)
		if parts.size() >= 2:
			break
	return join_strings(parts, " | ")


func join_strings(values: Array, separator: String) -> String:
	var output = ""
	for value in values:
		if output != "":
			output += separator
		output += str(value)
	return output


func format_debug_bool(value: Variant) -> String:
	return "on" if bool(value) else "off"


func get_dictionary_property(target: Variant, property_name: String) -> Dictionary:
	if not (target is Object):
		return {}
	var object: Object = target
	var value: Variant = object.get(property_name)
	if value is Dictionary:
		return value
	return {}


func get_array_property_size(target: Variant, property_name: String) -> int:
	if not (target is Object):
		return 0
	var object: Object = target
	var value: Variant = object.get(property_name)
	if value is Array:
		return value.size()
	return 0


func get_int_property(target: Variant, property_name: String) -> int:
	if not (target is Object):
		return 0
	var object: Object = target
	var value: Variant = object.get(property_name)
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return 0


func count_valid_block_nodes(blocks: Dictionary) -> int:
	var count: int = 0
	for block_data_value in blocks.values():
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		var node_value: Variant = block_data.get("node", null)
		if node_value is Object and is_instance_valid(node_value):
			count += 1
	return count


func count_block_visual_states(blocks: Dictionary) -> Dictionary:
	var states: Dictionary = {
		"visual_nodes": 0,
		"visible_visuals": 0,
		"hidden_visuals": 0,
		"tilemap_visuals": 0,
		"shadow_nodes": 0,
		"visible_shadow_nodes": 0,
	}
	for block_data_value in blocks.values():
		if not (block_data_value is Dictionary):
			continue
		var block_data: Dictionary = block_data_value
		if bool(block_data.get("tilemap_only", false)):
			states["tilemap_visuals"] = int(states["tilemap_visuals"]) + 1
		var node_value: Variant = block_data.get("node", null)
		if not (node_value is Node) or not is_instance_valid(node_value):
			continue
		var block_node: Node = node_value
		var visual: Node = block_node.get_node_or_null("Visual")
		if visual is CanvasItem:
			var visual_item: CanvasItem = visual
			states["visual_nodes"] = int(states["visual_nodes"]) + 1
			if visual_item.visible:
				states["visible_visuals"] = int(states["visible_visuals"]) + 1
			else:
				states["hidden_visuals"] = int(states["hidden_visuals"]) + 1
		if block_node.has_meta("tilemap_visual"):
			states["tilemap_visuals"] = int(states["tilemap_visuals"]) + 1
		var shadow: Node = block_node.get_node_or_null("TextureShadow")
		if shadow is CanvasItem:
			var shadow_item: CanvasItem = shadow
			states["shadow_nodes"] = int(states["shadow_nodes"]) + 1
			if shadow_item.visible:
				states["visible_shadow_nodes"] = int(states["visible_shadow_nodes"]) + 1
	return states


func format_node_backed_reason_breakdown(label: String, reasons: Dictionary, max_items: int = 4) -> String:
	if reasons.is_empty():
		return label + ": none"

	var keys: Array = reasons.keys()
	keys.sort_custom(func(a, b):
		var count_a := int(reasons.get(a, 0))
		var count_b := int(reasons.get(b, 0))
		if count_a == count_b:
			return str(a) < str(b)
		return count_a > count_b
	)

	var parts: Array = []
	var limit: int = mini(max_items, keys.size())
	for index in range(limit):
		var key = keys[index]
		parts.append(str(key) + " " + str(int(reasons.get(key, 0))))
	if keys.size() > limit:
		parts.append("+" + str(keys.size() - limit) + " more")

	return label + ": " + join_strings(parts, ", ")


func get_tilemap_cell_count(layer_property: String) -> int:
	if world == null:
		return 0
	var renderer: Node = world.get_node_or_null("WorldTileMapRenderer")
	if renderer == null:
		return 0
	var layer_value: Variant = renderer.get(layer_property)
	if layer_value is TileMapLayer:
		var tile_layer: TileMapLayer = layer_value
		return tile_layer.get_used_cells().size()
	return 0


func is_tilemap_visuals_enabled() -> bool:
	if world == null:
		return false
	var renderer: Node = world.get_node_or_null("WorldTileMapRenderer")
	if renderer == null:
		return false
	var enabled_value: Variant = renderer.get("enabled")
	return bool(enabled_value) if enabled_value is bool else false


func get_world_child_count(child_name: String) -> int:
	if world == null:
		return 0
	var child: Node = world.get_node_or_null(child_name)
	if child == null:
		return 0
	return child.get_child_count()


func collect_runtime_debug_counters() -> Dictionary:
	var counters: Dictionary = {}

	var foreground_blocks: Dictionary = get_dictionary_property(world, "blocks")
	var background_blocks: Dictionary = {}
	var block_manager: Variant = null
	if world != null:
		block_manager = world.get("block_manager")
	background_blocks = get_dictionary_property(block_manager, "background_blocks")

	var drop_manager: Variant = null
	var player_manager: Variant = null
	if world != null:
		drop_manager = world.get("drop_manager")
		player_manager = world.get("player_manager")

	var drops_by_id: Dictionary = get_dictionary_property(drop_manager, "drops_by_id")
	var drops_by_cell: Dictionary = get_dictionary_property(drop_manager, "drops_by_cell")
	var remote_players: Dictionary = get_dictionary_property(player_manager, "remote_players")
	var foreground_visual_states: Dictionary = count_block_visual_states(foreground_blocks)
	var background_visual_states: Dictionary = count_block_visual_states(background_blocks)
	var foreground_collision_summary: Dictionary = {}
	var tilemap_node_breakdown: Dictionary = {}
	var tilemap_runtime_config: Dictionary = {}
	var drop_pickup_stats: Dictionary = {}
	if block_manager is Object:
		var block_manager_object: Object = block_manager
		if block_manager_object.has_method("get_foreground_collision_optimization_summary"):
			foreground_collision_summary = block_manager_object.get_foreground_collision_optimization_summary()
		if block_manager_object.has_method("get_tilemap_node_backed_breakdown"):
			tilemap_node_breakdown = block_manager_object.get_tilemap_node_backed_breakdown()
		if block_manager_object.has_method("get_tilemap_runtime_config"):
			tilemap_runtime_config = block_manager_object.get_tilemap_runtime_config()
	if drop_manager is Object:
		var drop_manager_object: Object = drop_manager
		if drop_manager_object.has_method("get_drop_pickup_debug_stats"):
			var drop_pickup_stats_value: Variant = drop_manager_object.get_drop_pickup_debug_stats()
			if drop_pickup_stats_value is Dictionary:
				drop_pickup_stats = drop_pickup_stats_value

	var foreground_node_reason_value: Variant = tilemap_node_breakdown.get("foreground", {})
	var background_node_reason_value: Variant = tilemap_node_breakdown.get("background", {})
	var foreground_missing_item_types_value: Variant = tilemap_node_breakdown.get("foreground_missing_item_types", {})
	var foreground_custom_collision_types_value: Variant = tilemap_node_breakdown.get("foreground_custom_collision_types", {})
	var foreground_animated_types_value: Variant = tilemap_node_breakdown.get("foreground_animated_types", {})
	var foreground_node_type_details_value: Variant = tilemap_node_breakdown.get("foreground_node_type_details", {})
	var foreground_optimization_type_details_value: Variant = tilemap_node_breakdown.get("foreground_optimization_type_details", {})
	var foreground_audit_type_details_value: Variant = tilemap_node_breakdown.get("foreground_audit_type_details", {})
	var foreground_intentional_type_details_value: Variant = tilemap_node_breakdown.get("foreground_intentional_type_details", {})
	var background_missing_item_types_value: Variant = tilemap_node_breakdown.get("background_missing_item_types", {})
	var background_custom_collision_types_value: Variant = tilemap_node_breakdown.get("background_custom_collision_types", {})
	var background_animated_types_value: Variant = tilemap_node_breakdown.get("background_animated_types", {})
	var background_node_type_details_value: Variant = tilemap_node_breakdown.get("background_node_type_details", {})
	var background_optimization_type_details_value: Variant = tilemap_node_breakdown.get("background_optimization_type_details", {})
	var background_audit_type_details_value: Variant = tilemap_node_breakdown.get("background_audit_type_details", {})
	var background_intentional_type_details_value: Variant = tilemap_node_breakdown.get("background_intentional_type_details", {})

	counters["foreground_entries"] = foreground_blocks.size()
	counters["foreground_nodes"] = count_valid_block_nodes(foreground_blocks)
	counters["foreground_visible_visuals"] = int(foreground_visual_states.get("visible_visuals", 0))
	counters["foreground_tilemap_visuals"] = int(foreground_visual_states.get("tilemap_visuals", 0))
	counters["foreground_shadow_nodes"] = int(foreground_visual_states.get("shadow_nodes", 0))
	counters["foreground_visible_shadow_nodes"] = int(foreground_visual_states.get("visible_shadow_nodes", 0))
	counters["foreground_node_backed_reasons"] = foreground_node_reason_value if foreground_node_reason_value is Dictionary else {}
	counters["foreground_optimization_candidates"] = int(tilemap_node_breakdown.get("foreground_optimization_candidates", 0))
	counters["foreground_audit_nodes"] = int(tilemap_node_breakdown.get("foreground_audit_nodes", 0))
	counters["foreground_feature_nodes"] = int(tilemap_node_breakdown.get("foreground_feature_nodes", 0))
	counters["foreground_intentional_nodes"] = int(tilemap_node_breakdown.get("foreground_intentional_nodes", tilemap_node_breakdown.get("foreground_feature_nodes", 0)))
	counters["foreground_intentional_tilemap_split_nodes"] = int(tilemap_node_breakdown.get("foreground_intentional_tilemap_split_nodes", 0))
	counters["foreground_intentional_live_visual_nodes"] = int(tilemap_node_breakdown.get("foreground_intentional_live_visual_nodes", 0))
	counters["foreground_intentional_logic_only_nodes"] = int(tilemap_node_breakdown.get("foreground_intentional_logic_only_nodes", 0))
	counters["foreground_missing_item_types"] = foreground_missing_item_types_value if foreground_missing_item_types_value is Dictionary else {}
	counters["foreground_custom_collision_types"] = foreground_custom_collision_types_value if foreground_custom_collision_types_value is Dictionary else {}
	counters["foreground_animated_types"] = foreground_animated_types_value if foreground_animated_types_value is Dictionary else {}
	counters["foreground_node_type_details"] = foreground_node_type_details_value if foreground_node_type_details_value is Dictionary else {}
	counters["foreground_optimization_type_details"] = foreground_optimization_type_details_value if foreground_optimization_type_details_value is Dictionary else {}
	counters["foreground_audit_type_details"] = foreground_audit_type_details_value if foreground_audit_type_details_value is Dictionary else {}
	counters["foreground_intentional_type_details"] = foreground_intentional_type_details_value if foreground_intentional_type_details_value is Dictionary else {}
	counters["foreground_collision_ready"] = int(foreground_collision_summary.get("ready", 0))
	counters["foreground_collision_simple_solid"] = int(foreground_collision_summary.get("simple_solid", 0))
	counters["foreground_collision_platform"] = int(foreground_collision_summary.get("platform", 0))
	counters["foreground_collision_kept"] = int(foreground_collision_summary.get("kept", 0))
	counters["foreground_collision_active"] = int(foreground_collision_summary.get("active", 0))
	counters["foreground_collision_enabled"] = bool(foreground_collision_summary.get("enabled", false))
	counters["foreground_collision_replacing_nodes"] = bool(foreground_collision_summary.get("replacing_nodes", false))
	counters["foreground_collision_replaced_nodes"] = int(foreground_collision_summary.get("replaced_nodes", 0))
	counters["foreground_collision_node_kept"] = int(foreground_collision_summary.get("node_collision_kept", 0))
	counters["background_entries"] = background_blocks.size()
	counters["background_nodes"] = count_valid_block_nodes(background_blocks)
	counters["background_visible_visuals"] = int(background_visual_states.get("visible_visuals", 0))
	counters["background_tilemap_visuals"] = int(background_visual_states.get("tilemap_visuals", 0))
	counters["background_shadow_nodes"] = int(background_visual_states.get("shadow_nodes", 0))
	counters["background_visible_shadow_nodes"] = int(background_visual_states.get("visible_shadow_nodes", 0))
	counters["background_node_backed_reasons"] = background_node_reason_value if background_node_reason_value is Dictionary else {}
	counters["background_optimization_candidates"] = int(tilemap_node_breakdown.get("background_optimization_candidates", 0))
	counters["background_audit_nodes"] = int(tilemap_node_breakdown.get("background_audit_nodes", 0))
	counters["background_feature_nodes"] = int(tilemap_node_breakdown.get("background_feature_nodes", 0))
	counters["background_intentional_nodes"] = int(tilemap_node_breakdown.get("background_intentional_nodes", tilemap_node_breakdown.get("background_feature_nodes", 0)))
	counters["background_intentional_tilemap_split_nodes"] = int(tilemap_node_breakdown.get("background_intentional_tilemap_split_nodes", 0))
	counters["background_intentional_live_visual_nodes"] = int(tilemap_node_breakdown.get("background_intentional_live_visual_nodes", 0))
	counters["background_intentional_logic_only_nodes"] = int(tilemap_node_breakdown.get("background_intentional_logic_only_nodes", 0))
	counters["background_missing_item_types"] = background_missing_item_types_value if background_missing_item_types_value is Dictionary else {}
	counters["background_custom_collision_types"] = background_custom_collision_types_value if background_custom_collision_types_value is Dictionary else {}
	counters["background_animated_types"] = background_animated_types_value if background_animated_types_value is Dictionary else {}
	counters["background_node_type_details"] = background_node_type_details_value if background_node_type_details_value is Dictionary else {}
	counters["background_optimization_type_details"] = background_optimization_type_details_value if background_optimization_type_details_value is Dictionary else {}
	counters["background_audit_type_details"] = background_audit_type_details_value if background_audit_type_details_value is Dictionary else {}
	counters["background_intentional_type_details"] = background_intentional_type_details_value if background_intentional_type_details_value is Dictionary else {}
	counters["foreground_tile_cells"] = get_tilemap_cell_count("foreground_layer")
	counters["foreground_shadow_tile_cells"] = get_tilemap_cell_count("foreground_shadow_layer")
	counters["foreground_collision_tile_cells"] = get_tilemap_cell_count("foreground_collision_layer")
	counters["water_tile_cells"] = get_tilemap_cell_count("water_layer")
	counters["background_tile_cells"] = get_tilemap_cell_count("background_layer")
	counters["background_shadow_tile_cells"] = get_tilemap_cell_count("background_shadow_layer")
	counters["tilemap_enabled"] = is_tilemap_visuals_enabled()
	counters["tilemap_runtime_config"] = tilemap_runtime_config
	counters["world_drops"] = get_array_property_size(world, "dropped_items")
	counters["drops_by_id"] = drops_by_id.size()
	counters["drop_cells"] = drops_by_cell.size()
	counters["visible_drop_nodes"] = get_int_property(drop_manager, "visible_drop_nodes")
	counters["drop_pickup_stats"] = drop_pickup_stats
	counters["remote_players"] = remote_players.size()
	counters["remote_player_nodes"] = get_world_child_count("RemotePlayers")
	counters["visible_remote_player_nodes"] = get_int_property(player_manager, "visible_remote_player_nodes")

	return counters


func update_debug_info():
	if debug_info_label == null:
		return

	var network = get_network()
	var role = "unknown"
	var connected = false
	var username = get_current_username()
	if network != null:
		if network.has_method("get_active_session_role"):
			role = str(network.get_active_session_role())
		if network.has_method("is_connected_to_server"):
			connected = bool(network.is_connected_to_server())

	var world_name = "START"
	if world != null and "current_world_name" in world:
		world_name = str(world.current_world_name)

	var counters: Dictionary = collect_runtime_debug_counters()
	var tilemap_status: String = "on" if bool(counters.get("tilemap_enabled", false)) else "off"
	var collision_status: String = "on" if bool(counters.get("foreground_collision_enabled", false)) else "prep"
	var collision_replace_status: String = "replace" if bool(counters.get("foreground_collision_replacing_nodes", false)) else "node-safe"
	var tilemap_runtime_config_value: Variant = counters.get("tilemap_runtime_config", {})
	var tilemap_runtime_config: Dictionary = tilemap_runtime_config_value if tilemap_runtime_config_value is Dictionary else {}
	var tilemap_streaming_value: Variant = tilemap_runtime_config.get("streaming", {})
	var tilemap_streaming: Dictionary = tilemap_streaming_value if tilemap_streaming_value is Dictionary else {}
	var tilemap_cached_by_layer_value: Variant = tilemap_streaming.get("cached_by_layer", {})
	var tilemap_cached_by_layer: Dictionary = tilemap_cached_by_layer_value if tilemap_cached_by_layer_value is Dictionary else {}
	var tilemap_active_by_layer_value: Variant = tilemap_streaming.get("active_by_layer", {})
	var tilemap_active_by_layer: Dictionary = tilemap_active_by_layer_value if tilemap_active_by_layer_value is Dictionary else {}
	var tilemap_cached_sources_value: Variant = tilemap_streaming.get("cached_cell_sources", {})
	var tilemap_cached_sources: Dictionary = tilemap_cached_sources_value if tilemap_cached_sources_value is Dictionary else {}
	var tilemap_active_sources_value: Variant = tilemap_streaming.get("active_cell_sources", {})
	var tilemap_active_sources: Dictionary = tilemap_active_sources_value if tilemap_active_sources_value is Dictionary else {}
	var drop_pickup_stats_value: Variant = counters.get("drop_pickup_stats", {})
	var drop_pickup_stats: Dictionary = drop_pickup_stats_value if drop_pickup_stats_value is Dictionary else {}
	var pickup_debug_reason := str(drop_pickup_stats.get("debug_reason", ""))
	if pickup_debug_reason == "":
		pickup_debug_reason = "idle"
	var pickup_debug_item := str(drop_pickup_stats.get("debug_item_type", ""))
	if pickup_debug_item == "":
		pickup_debug_item = "-"
	var pickup_debug_distance := int(round(float(drop_pickup_stats.get("debug_distance_px", -1.0))))
	var pickup_debug_distance_text := "-"
	if pickup_debug_distance >= 0:
		pickup_debug_distance_text = str(pickup_debug_distance)
	var pickup_debug_range := int(round(float(drop_pickup_stats.get("debug_range_px", 0.0))))
	var pickup_debug_drop_id := str(drop_pickup_stats.get("debug_drop_id", ""))
	if pickup_debug_drop_id == "":
		pickup_debug_drop_id = "-"
	elif pickup_debug_drop_id.length() > 18:
		pickup_debug_drop_id = pickup_debug_drop_id.substr(0, 18) + "..."
	var lines: Array = [
		"Account: " + username + " | Role: " + role + " | Server: " + ("connected" if connected else "offline"),
		"World: " + world_name + " | FPS: " + str(int(Engine.get_frames_per_second())),
		"Foreground: " + str(int(counters.get("foreground_entries", 0))) + " data / " + str(int(counters.get("foreground_nodes", 0))) + " nodes / " + str(int(counters.get("foreground_tile_cells", 0))) + " tile cells",
		"Foreground sprites: " + str(int(counters.get("foreground_visible_visuals", 0))) + " visible / " + str(int(counters.get("foreground_tilemap_visuals", 0))) + " tilemapped",
		"Foreground shadows: " + str(int(counters.get("foreground_visible_shadow_nodes", 0))) + " node draws / " + str(int(counters.get("foreground_shadow_tile_cells", 0))) + " tile cells",
		format_node_backed_reason_breakdown("FG node reasons", counters.get("foreground_node_backed_reasons", {})),
		"FG audit: " + str(int(counters.get("foreground_optimization_candidates", 0))) + " optimize / " + str(int(counters.get("foreground_audit_nodes", 0))) + " review / " + str(int(counters.get("foreground_intentional_nodes", counters.get("foreground_feature_nodes", 0)))) + " intentional",
		"FG intentional draw: " + str(int(counters.get("foreground_intentional_tilemap_split_nodes", 0))) + " split / " + str(int(counters.get("foreground_intentional_live_visual_nodes", 0))) + " live visual / " + str(int(counters.get("foreground_intentional_logic_only_nodes", 0))) + " logic-only",
		"Collision prep: " + str(int(counters.get("foreground_collision_ready", 0))) + " ready / " + str(int(counters.get("foreground_collision_simple_solid", 0))) + " simple / " + str(int(counters.get("foreground_collision_platform", 0))) + " platform / " + str(int(counters.get("foreground_collision_kept", 0))) + " kept (" + collision_status + ")",
		"Collision TileMap: " + str(int(counters.get("foreground_collision_active", 0))) + " active / " + str(int(counters.get("foreground_collision_tile_cells", 0))) + " tile cells (" + collision_replace_status + ", " + str(int(counters.get("foreground_collision_node_kept", 0))) + " nodes kept)",
		"Background: " + str(int(counters.get("background_entries", 0))) + " data / " + str(int(counters.get("background_nodes", 0))) + " nodes / " + str(int(counters.get("background_tile_cells", 0))) + " tile cells",
		"Background sprites: " + str(int(counters.get("background_visible_visuals", 0))) + " visible / " + str(int(counters.get("background_tilemap_visuals", 0))) + " tilemapped",
		"Background shadows: " + str(int(counters.get("background_visible_shadow_nodes", 0))) + " node draws / " + str(int(counters.get("background_shadow_tile_cells", 0))) + " tile cells",
		format_node_backed_reason_breakdown("BG node reasons", counters.get("background_node_backed_reasons", {})),
		"BG audit: " + str(int(counters.get("background_optimization_candidates", 0))) + " optimize / " + str(int(counters.get("background_audit_nodes", 0))) + " review / " + str(int(counters.get("background_intentional_nodes", counters.get("background_feature_nodes", 0)))) + " intentional",
		"BG intentional draw: " + str(int(counters.get("background_intentional_tilemap_split_nodes", 0))) + " split / " + str(int(counters.get("background_intentional_live_visual_nodes", 0))) + " live visual / " + str(int(counters.get("background_intentional_logic_only_nodes", 0))) + " logic-only",
		"Drops: " + str(int(counters.get("world_drops", 0))) + " world / " + str(int(counters.get("visible_drop_nodes", 0))) + " visible / " + str(int(counters.get("drops_by_id", 0))) + " indexed / " + str(int(counters.get("drop_cells", 0))) + " cells",
		"Drop pickups: " + str(int(drop_pickup_stats.get("queued", 0))) + " queued / " + str(int(drop_pickup_stats.get("in_flight", 0))) + " in-flight / " + str(int(drop_pickup_stats.get("pending_stacks", 0))) + " stacks / tokens " + str(int(floor(float(drop_pickup_stats.get("send_tokens", 0.0))))) + " / queue max " + str(int(drop_pickup_stats.get("max_queue", 0))) + " / rate " + str(int(drop_pickup_stats.get("send_rate", 0))) + "/s",
		"Pickup debug: " + pickup_debug_reason + " item " + pickup_debug_item + " dist " + pickup_debug_distance_text + "/" + str(pickup_debug_range) + " id " + pickup_debug_drop_id,
		"Remote players: " + str(int(counters.get("remote_players", 0))) + " data / " + str(int(counters.get("visible_remote_player_nodes", 0))) + " visible / " + str(int(counters.get("remote_player_nodes", 0))) + " nodes",
		"TileMap runtime: visuals " + tilemap_status + " / fg " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_only_enabled", false)) + " / bg " + format_debug_bool(tilemap_runtime_config.get("background_tilemap_only_enabled", false)) + " / collision " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_collision_enabled", false)) + " / replace " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_collision_replaces_nodes_enabled", false)),
		"TileMap water: " + str(int(tilemap_active_by_layer.get("water", counters.get("water_tile_cells", 0)))) + " active / " + str(int(tilemap_cached_by_layer.get("water", counters.get("water_tile_cells", 0)))) + " cached cells",
		"TileMap vending previews: " + str(int(tilemap_active_by_layer.get("vending_preview", 0))) + " active / " + str(int(tilemap_cached_by_layer.get("vending_preview", 0))) + " cached cells",
		"TileMap feature visuals: " + str(int(tilemap_active_by_layer.get("foreground_feature", 0))) + " active / " + str(int(tilemap_cached_by_layer.get("foreground_feature", 0))) + " cached cells",
		"TileMap chunks: stream " + format_debug_bool(tilemap_streaming.get("streaming_enabled", false)) + " / active chunks " + str(int(tilemap_streaming.get("active_chunks", 0))) + " / active cells " + str(int(tilemap_streaming.get("active_cells", 0))) + " / cached cells " + str(int(tilemap_streaming.get("cached_cells", 0))) + " / size " + str(int(tilemap_streaming.get("chunk_size_cells", 0))),
		"TileMap dirty: pending " + str(int(tilemap_streaming.get("dirty_chunks_pending", 0))) + " / last chunks " + str(int(tilemap_streaming.get("last_dirty_chunks_processed", 0))) + " / cells " + str(int(tilemap_streaming.get("last_dirty_cells_rebuilt", 0))) + " / ms " + str(int(tilemap_streaming.get("last_dirty_rebuild_ms", 0))) + " / budget " + str(int(tilemap_streaming.get("dirty_chunks_per_frame", 0))),
		"TileMap sources: coord " + str(int(tilemap_active_sources.get("coordinate", 0))) + "/" + str(int(tilemap_cached_sources.get("coordinate", 0))) + " active/cached, node-derived " + str(int(tilemap_active_sources.get("node_derived", 0))) + "/" + str(int(tilemap_cached_sources.get("node_derived", 0))) + ", unknown " + str(int(tilemap_active_sources.get("unknown", 0))) + "/" + str(int(tilemap_cached_sources.get("unknown", 0))),
		"Local time: " + Time.get_datetime_string_from_system()
	]
	append_optional_breakdown_line(lines, "Pickup reasons", drop_pickup_stats.get("debug_skip_counts", {}), 6)
	append_node_type_audit_lines(lines, "FG optimize IDs", counters.get("foreground_optimization_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "FG review IDs", counters.get("foreground_audit_type_details", {}), 4, 6)
	append_node_type_audit_lines(lines, "FG intentional IDs", counters.get("foreground_intentional_type_details", {}), 5, 7)
	append_node_type_audit_lines(lines, "BG optimize IDs", counters.get("background_optimization_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "BG review IDs", counters.get("background_audit_type_details", {}), 4, 6)
	append_node_type_audit_lines(lines, "BG intentional IDs", counters.get("background_intentional_type_details", {}), 4, 6)
	debug_info_label.text = join_strings(lines, "\n")
	debug_info_label.custom_minimum_size = Vector2(debug_info_label.custom_minimum_size.x, debug_info_label.get_minimum_size().y)


func update_tilemap_audit_info():
	if tilemap_audit_info_label == null:
		return

	var network = get_network()
	var role = "unknown"
	var connected = false
	var username = get_current_username()
	if network != null:
		if network.has_method("get_active_session_role"):
			role = str(network.get_active_session_role())
		if network.has_method("is_connected_to_server"):
			connected = bool(network.is_connected_to_server())

	var world_name = get_current_world_name()
	var counters: Dictionary = collect_runtime_debug_counters()
	var tilemap_status: String = "on" if bool(counters.get("tilemap_enabled", false)) else "off"
	var tilemap_runtime_config_value: Variant = counters.get("tilemap_runtime_config", {})
	var tilemap_runtime_config: Dictionary = tilemap_runtime_config_value if tilemap_runtime_config_value is Dictionary else {}
	var tilemap_streaming_value: Variant = tilemap_runtime_config.get("streaming", {})
	var tilemap_streaming: Dictionary = tilemap_streaming_value if tilemap_streaming_value is Dictionary else {}
	var tilemap_cached_by_layer_value: Variant = tilemap_streaming.get("cached_by_layer", {})
	var tilemap_cached_by_layer: Dictionary = tilemap_cached_by_layer_value if tilemap_cached_by_layer_value is Dictionary else {}
	var tilemap_active_by_layer_value: Variant = tilemap_streaming.get("active_by_layer", {})
	var tilemap_active_by_layer: Dictionary = tilemap_active_by_layer_value if tilemap_active_by_layer_value is Dictionary else {}
	var tilemap_cached_sources_value: Variant = tilemap_streaming.get("cached_cell_sources", {})
	var tilemap_cached_sources: Dictionary = tilemap_cached_sources_value if tilemap_cached_sources_value is Dictionary else {}
	var tilemap_active_sources_value: Variant = tilemap_streaming.get("active_cell_sources", {})
	var tilemap_active_sources: Dictionary = tilemap_active_sources_value if tilemap_active_sources_value is Dictionary else {}

	var fg_collision_status: String = "enabled" if bool(counters.get("foreground_collision_enabled", false)) else "prep"
	var fg_collision_replace_status: String = "replace" if bool(counters.get("foreground_collision_replacing_nodes", false)) else "node-safe"
	var fg_tile_cells: int = int(counters.get("foreground_tile_cells", 0))
	var bg_tile_cells: int = int(counters.get("background_tile_cells", 0))
	var fg_shadow_tile_cells: int = int(counters.get("foreground_shadow_tile_cells", 0))
	var bg_shadow_tile_cells: int = int(counters.get("background_shadow_tile_cells", 0))
	var fg_collision_tile_cells: int = int(counters.get("foreground_collision_tile_cells", 0))
	var fg_audit_candidates: int = int(counters.get("foreground_optimization_candidates", 0))
	var fg_review_nodes: int = int(counters.get("foreground_audit_nodes", 0))
	var fg_intentional_nodes: int = int(counters.get("foreground_intentional_nodes", counters.get("foreground_feature_nodes", 0)))
	var bg_audit_candidates: int = int(counters.get("background_optimization_candidates", 0))
	var bg_review_nodes: int = int(counters.get("background_audit_nodes", 0))
	var bg_intentional_nodes: int = int(counters.get("background_intentional_nodes", counters.get("background_feature_nodes", 0)))
	var fg_data_entries: int = int(counters.get("foreground_entries", 0))
	var bg_data_entries: int = int(counters.get("background_entries", 0))
	var fg_node_visuals: int = int(counters.get("foreground_nodes", 0))
	var bg_node_visuals: int = int(counters.get("background_nodes", 0))
	var fg_visible_visuals: int = int(counters.get("foreground_visible_visuals", 0))
	var bg_visible_visuals: int = int(counters.get("background_visible_visuals", 0))
	var fg_tilemapped_visuals: int = int(counters.get("foreground_tilemap_visuals", 0))
	var bg_tilemapped_visuals: int = int(counters.get("background_tilemap_visuals", 0))
	var tile_collision_ready: int = int(counters.get("foreground_collision_ready", 0))
	var tile_collision_simple_solid: int = int(counters.get("foreground_collision_simple_solid", 0))
	var tile_collision_platform: int = int(counters.get("foreground_collision_platform", 0))
	var tile_collision_kept_nodes: int = int(counters.get("foreground_collision_node_kept", 0))

	var lines: Array = [
		"TileMap Audit - " + username + " (" + role + ") | Server: " + ("connected" if connected else "offline"),
		"World: " + world_name + " | TileMap visuals: " + tilemap_status,
		"FG data: " + str(fg_data_entries) + " / FG node visuals: " + str(fg_node_visuals) + " (visible " + str(fg_visible_visuals) + ") / FG tilemapped: " + str(fg_tilemapped_visuals) + " / FG tile cells: " + str(fg_tile_cells),
		"BG data: " + str(bg_data_entries) + " / BG node visuals: " + str(bg_node_visuals) + " (visible " + str(bg_visible_visuals) + ") / BG tilemapped: " + str(bg_tilemapped_visuals) + " / BG tile cells: " + str(bg_tile_cells),
		"TileMap conversion targets: FG candidates " + str(fg_audit_candidates) + " / FG review " + str(fg_review_nodes) + " / FG intentional " + str(fg_intentional_nodes),
		"TileMap conversion targets: BG candidates " + str(bg_audit_candidates) + " / BG review " + str(bg_review_nodes) + " / BG intentional " + str(bg_intentional_nodes),
		"FG intent split/live/logic: " + str(int(counters.get("foreground_intentional_tilemap_split_nodes", 0))) + " / " + str(int(counters.get("foreground_intentional_live_visual_nodes", 0))) + " / " + str(int(counters.get("foreground_intentional_logic_only_nodes", 0))),
		"BG intent split/live/logic: " + str(int(counters.get("background_intentional_tilemap_split_nodes", 0))) + " / " + str(int(counters.get("background_intentional_live_visual_nodes", 0))) + " / " + str(int(counters.get("background_intentional_logic_only_nodes", 0))),
		"FG collision: " + str(tile_collision_ready) + " ready / " + str(tile_collision_simple_solid) + " simple / " + str(tile_collision_platform) + " platform / " + str(tile_collision_kept_nodes) + " kept nodes (" + fg_collision_status + ", " + fg_collision_replace_status + ")",
		"FG collision tile cells: " + str(fg_collision_tile_cells) + " | Shadows: FG " + str(fg_shadow_tile_cells) + " BG " + str(bg_shadow_tile_cells),
		"Policy: fg only " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_only_enabled", false)) + " / bg only " + format_debug_bool(tilemap_runtime_config.get("background_tilemap_only_enabled", false)) + " / collision " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_collision_enabled", false)) + " / replace " + format_debug_bool(tilemap_runtime_config.get("foreground_tilemap_collision_replaces_nodes_enabled", false)),
		"Chunking: stream " + format_debug_bool(tilemap_streaming.get("streaming_enabled", false)) + " / active chunks " + str(int(tilemap_streaming.get("active_chunks", 0))) + " / active cells " + str(int(tilemap_streaming.get("active_cells", 0))) + " / chunk size " + str(int(tilemap_streaming.get("chunk_size_cells", 0))),
		"Dirty: pending " + str(int(tilemap_streaming.get("dirty_chunks_pending", 0))) + " / last processed " + str(int(tilemap_streaming.get("last_dirty_chunks_processed", 0))) + " / last cells rebuilt " + str(int(tilemap_streaming.get("last_dirty_cells_rebuilt", 0))) + " / last ms " + str(int(tilemap_streaming.get("last_dirty_rebuild_ms", 0))),
		"Layers active/cached: fg " + str(int(tilemap_active_by_layer.get("foreground", fg_tile_cells))) + "/" + str(int(tilemap_cached_by_layer.get("foreground", fg_tile_cells))) + ", fg shadow " + str(int(tilemap_active_by_layer.get("foreground_shadow", fg_shadow_tile_cells))) + "/" + str(int(tilemap_cached_by_layer.get("foreground_shadow", fg_shadow_tile_cells))) + ", bg " + str(int(tilemap_active_by_layer.get("background", bg_tile_cells))) + "/" + str(int(tilemap_cached_by_layer.get("background", bg_tile_cells))),
		"Sources active/cached: coord " + str(int(tilemap_active_sources.get("coordinate", 0))) + "/" + str(int(tilemap_cached_sources.get("coordinate", 0))) + ", node-derived " + str(int(tilemap_active_sources.get("node_derived", 0))) + "/" + str(int(tilemap_cached_sources.get("node_derived", 0))) + ", unknown " + str(int(tilemap_active_sources.get("unknown", 0))) + "/" + str(int(tilemap_cached_sources.get("unknown", 0))),
		"Water cells: " + str(int(tilemap_active_by_layer.get("water", int(counters.get("water_tile_cells", 0)))) ) + " active / " + str(int(tilemap_cached_by_layer.get("water", int(counters.get("water_tile_cells", 0)))) ) + " cached",
		"Vending cells: " + str(int(tilemap_active_by_layer.get("vending_preview", 0))) + " active / " + str(int(tilemap_cached_by_layer.get("vending_preview", 0))) + " cached",
		"Feature visuals: " + str(int(tilemap_active_by_layer.get("foreground_feature", 0))) + " active / " + str(int(tilemap_cached_by_layer.get("foreground_feature", 0))) + " cached",
		"Local time: " + Time.get_datetime_string_from_system(),
	]

	append_optional_breakdown_line(lines, "FG blocked reasons", counters.get("foreground_node_backed_reasons", {}), 8)
	append_optional_breakdown_line(lines, "BG blocked reasons", counters.get("background_node_backed_reasons", {}), 8)
	append_node_type_audit_lines(lines, "FG optimize IDs", counters.get("foreground_optimization_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "FG review IDs", counters.get("foreground_audit_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "FG intentional IDs", counters.get("foreground_intentional_type_details", {}), 2, 5)
	append_node_type_audit_lines(lines, "BG optimize IDs", counters.get("background_optimization_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "BG review IDs", counters.get("background_audit_type_details", {}), 3, 5)
	append_node_type_audit_lines(lines, "BG intentional IDs", counters.get("background_intentional_type_details", {}), 2, 5)

	tilemap_audit_info_label.text = join_strings(lines, "\n")
	tilemap_audit_info_label.custom_minimum_size = Vector2(tilemap_audit_info_label.custom_minimum_size.x, tilemap_audit_info_label.get_minimum_size().y)


func append_optional_breakdown_line(lines: Array, label: String, values: Variant, max_items: int = 5) -> void:
	if not (values is Dictionary):
		return
	var counts: Dictionary = values
	if counts.is_empty():
		return
	lines.append(format_node_backed_reason_breakdown(label, counts, max_items))


func append_node_type_audit_lines(lines: Array, label: String, values: Variant, max_reasons: int = 6, max_items: int = 7) -> void:
	if not (values is Dictionary):
		return

	var reason_details: Dictionary = values
	if reason_details.is_empty():
		return

	var reasons: Array = reason_details.keys()
	reasons.sort_custom(func(a, b):
		var total_a := get_nested_count_total(reason_details.get(a, {}))
		var total_b := get_nested_count_total(reason_details.get(b, {}))
		if total_a == total_b:
			return str(a) < str(b)
		return total_a > total_b
	)

	var limit: int = mini(max_reasons, reasons.size())
	for index in range(limit):
		var reason = reasons[index]
		var type_counts = reason_details.get(reason, {})
		if type_counts is Dictionary and not type_counts.is_empty():
			lines.append(format_node_backed_reason_breakdown(label + " - " + str(reason), type_counts, max_items))

	if reasons.size() > limit:
		lines.append(label + ": +" + str(reasons.size() - limit) + " more reasons")


func get_nested_count_total(values: Variant) -> int:
	if not (values is Dictionary):
		return 0
	var counts: Dictionary = values
	var total := 0
	for value in counts.values():
		total += int(value)
	return total


func resolve_item_id(value: String) -> String:
	var clean = value.strip_edges()
	if clean == "":
		return ""

	if world != null and "item_database" in world:
		if world.item_database.has(clean):
			return clean
		var query = clean.to_lower()
		for item_id in world.item_database.keys():
			var data = world.item_database[item_id]
			var display_name = str(data.get("display_name", item_id)).to_lower()
			if str(item_id).to_lower() == query or display_name == query:
				return str(item_id)

	return clean


func get_input_text(input, fallback: String = "") -> String:
	if input == null:
		return fallback
	var text = str(input.text).strip_edges()
	return text if text != "" else fallback


func set_result(message: String):
	if result_label != null:
		result_label.text = message


func notify(message: String):
	if message.strip_edges() == "":
		return
	if world != null and world.has_method("show_notification"):
		world.show_notification(message)


func update_status():
	if status_label == null:
		return
	var role = "player"
	var network = get_network()
	if network != null and network.has_method("get_active_session_role"):
		role = str(network.get_active_session_role())
	var pin_status = ""
	if network != null and network.has_method("is_developer_pin_required") and bool(network.is_developer_pin_required()):
		pin_status = "  |  PIN " + ("unlocked" if is_developer_pin_ready() else "locked")
	status_label.text = "Role: " + role + "  |  Server verified" + pin_status


func update_layout():
	if panel == null:
		return
	var screen_size = get_viewport_rect().size
	panel.position = Vector2(
		(screen_size.x - panel.size.x) / 2.0,
		max(34.0, (screen_size.y - panel.size.y) / 2.0)
	)
	if dev_button != null:
		dev_button.position = Vector2(12.0, max(12.0, screen_size.y - dev_button.size.y - 12.0))


func update_dev_button():
	if dev_button == null:
		return
	dev_button.visible = is_developer_allowed()


func get_network():
	if world == null:
		return null
	return world.get_node_or_null("/root/NetworkManager")


func is_developer_allowed() -> bool:
	var network = get_network()
	if network == null or not network.has_method("is_developer_session"):
		return false
	return bool(network.is_developer_session())


func is_developer_pin_ready() -> bool:
	var network = get_network()
	if network == null:
		return true
	if network.has_method("is_developer_pin_required") and network.has_method("is_developer_pin_unlocked"):
		return not bool(network.is_developer_pin_required()) or bool(network.is_developer_pin_unlocked())
	return true


func show_pin_gate():
	if pin_gate_panel == null:
		return
	pin_gate_panel.visible = true
	pin_gate_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if pin_input != null and not pin_input.has_focus():
		pin_input.grab_focus()


func hide_pin_gate():
	if pin_gate_panel == null:
		return
	pin_gate_panel.visible = false
	pin_gate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pin_input != null:
		pin_input.release_focus()


func submit_developer_pin():
	var network = get_network()
	if network == null or not network.has_method("send_developer_pin_unlock"):
		set_result("Developer PIN system is not ready.")
		return

	var pin = get_input_text(pin_input, "")
	if pin == "":
		set_result("Enter the developer PIN.")
		return

	if bool(network.send_developer_pin_unlock(pin)):
		set_result("Checking developer PIN...")
		if pin_input != null:
			pin_input.text = ""
	else:
		set_result("Could not send developer PIN.")


func get_current_world_name() -> String:
	if world != null and "current_world_name" in world:
		var world_name = str(world.current_world_name).strip_edges()
		if world_name != "":
			return world_name
	return "START"


func get_current_username() -> String:
	if world != null and world.has_method("get_current_profile_name"):
		return str(world.get_current_profile_name()).strip_edges()
	return ""


func open_panel():
	if not is_developer_allowed():
		notify("Developer panel requires admin/developer access.")
		return
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	update_status()
	if current_tab == "debug":
		update_debug_info()
	elif current_tab == "tilemap_audit":
		update_tilemap_audit_info()
	if is_developer_pin_ready():
		hide_pin_gate()
	else:
		show_pin_gate()
	PixelUIStyle.play_panel_open(panel)


func close_panel():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false
	clear_confirm()
	hide_pin_gate()


func toggle_panel():
	if is_open():
		close_panel()
	else:
		if world != null and world.has_method("open_developer_panel"):
			world.open_developer_panel()
		else:
			open_panel()


func is_open() -> bool:
	return visible and panel != null and panel.visible


func _on_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
