extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const INVENTORY_LOOKUP_PURPOSE: String = "admin_inventory_lookup"
const ITEM_INSTANCE_LOOKUP_PURPOSE: String = "admin_item_instance_lookup"
const INVENTORY_LOOKUP_TIMEOUT: float = 16.0
const PANEL_SIZE := Vector2(1040.0, 680.0)
const PANEL_INSET := 22.0
const BODY_Y := 136.0
const RESULT_Y := 630.0
const BODY_SIZE := Vector2(996.0, 482.0)
const INVENTORY_LIST_SIZE := Vector2(960.0, 314.0)
const INVENTORY_SCROLL_SIZE := Vector2(936.0, 290.0)
const INVENTORY_GRID_WIDTH := 916.0
const INVENTORY_LOOKUP_FIELDS = [
	{"field": "currency_inventory", "category": "currency", "label": "Currency"},
	{"field": "inventory", "category": "block", "label": "Blocks"},
	{"field": "seed_inventory", "category": "seed", "label": "Seeds"},
	{"field": "tool_inventory", "category": "tool", "label": "Tools"},
	{"field": "back_inventory", "category": "back", "label": "Back"},
	{"field": "hair_inventory", "category": "hair", "label": "Hair"},
	{"field": "shirt_inventory", "category": "shirt", "label": "Shirts"},
	{"field": "pants_inventory", "category": "pants", "label": "Pants"},
	{"field": "shoes_inventory", "category": "shoes", "label": "Shoes"},
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
var item_search_result = null
var debug_info_label = null
var inventory_lookup_input = null
var inventory_lookup_status = null
var inventory_lookup_scroll = null
var inventory_lookup_grid = null
var inventory_lookup_request_id: String = ""
var inventory_lookup_requested_username: String = ""
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


func _process(_delta):
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


func build_dev_button():
	if ui_layer_ref == null:
		return

	dev_button = ui_layer_ref.get_node_or_null("DeveloperQuickButton")
	if dev_button == null:
		dev_button = Button.new()
		dev_button.name = "DeveloperQuickButton"
		ui_layer_ref.add_child(dev_button)

	dev_button.text = "Dev"
	dev_button.size = Vector2(108, 42)
	dev_button.z_index = 84
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
		{"id": "moderation", "label": "Moderation"},
		{"id": "world", "label": "World Tools"},
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
		"moderation":
			build_moderation_tab()
		"world":
			build_world_tab()
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
	item_search_result = add_hint("", Vector2(306, 190), Vector2(BODY_SIZE.x - 324.0, 148))
	add_button("Search", Vector2(8, 240), Vector2(130, 38), search_items, false)


func build_inventory_lookup_tab():
	add_section_title("Inventory Lookup", Vector2(6, 0))
	inventory_lookup_input = add_input("Player username", Vector2(8, 48), Vector2(286, 38))
	inventory_lookup_input.text_submitted.connect(func(_text): request_inventory_lookup())
	add_button("Search", Vector2(312, 48), Vector2(130, 38), request_inventory_lookup, true)
	add_button("Instances", Vector2(458, 48), Vector2(150, 38), request_item_instance_lookup, false)
	add_button("Self", Vector2(624, 48), Vector2(110, 38), fill_inventory_lookup_with_self, false)

	inventory_lookup_status = add_hint("Search shows stack counts. Instances shows tracked item instance IDs from PostgreSQL.", Vector2(8, 100), Vector2(BODY_SIZE.x - 36.0, 48))

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
	debug_info_label = add_hint("", Vector2(8, 48), Vector2(BODY_SIZE.x - 36.0, 220))
	add_button("Refresh", Vector2(8, 294), Vector2(130, 42), update_debug_info, true)
	add_button("Where", Vector2(154, 294), Vector2(130, 42), func(): run_command("where"), false)
	add_button("Admin Help", Vector2(300, 294), Vector2(150, 42), func(): run_command("adminhelp"), false)
	update_debug_info()


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
	if item_search_result == null:
		return

	var query = get_input_text(item_search_input, "").to_lower()
	if query == "":
		item_search_result.text = "Type part of an item ID or display name."
		return

	var matches = []
	if world != null and "item_database" in world:
		for item_id in world.item_database.keys():
			var data = world.item_database[item_id]
			if data is Dictionary and bool(data.get("admin_grantable", true)) == false:
				continue
			var display_name = str(data.get("display_name", item_id))
			if str(item_id).to_lower().find(query) != -1 or display_name.to_lower().find(query) != -1:
				matches.append(str(item_id))
				if matches.size() >= 10:
					break

	if matches.size() > 0:
		item_search_result.text = "Matches: " + join_strings(matches, ", ")
	else:
		item_search_result.text = "No matching item IDs."


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
	inventory_lookup_requested_username = username
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
	inventory_lookup_requested_username = username
	set_inventory_lookup_status("Loading item instances for " + username + "...")
	add_inventory_lookup_empty("Waiting for server item instances...")
	set_result("Waiting for item instances...")
	call_deferred("_wait_for_inventory_lookup", request_id, username)


func _wait_for_inventory_lookup(request_id: String, username: String):
	await get_tree().create_timer(INVENTORY_LOOKUP_TIMEOUT).timeout
	if inventory_lookup_request_id != request_id:
		return
	if inventory_lookup_requested_username.to_lower() != username.strip_edges().to_lower():
		return
	inventory_lookup_request_id = ""
	set_inventory_lookup_status("Inventory lookup timed out.")
	add_inventory_lookup_empty("No response from the server.")
	set_result("Inventory lookup timed out.")


func handle_player_state_lookup_result(request_id: String, data: Dictionary, request_context: Dictionary = {}):
	var request_purpose = str(request_context.get("purpose", data.get("purpose", ""))).strip_edges().to_lower()
	if request_purpose == ITEM_INSTANCE_LOOKUP_PURPOSE:
		handle_item_instance_lookup_result(request_id, data, request_context)
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
		if item_id == "" and instance_id == "":
			continue
		var category = str(raw_entry.get("item_category", raw_entry.get("category", ""))).strip_edges()
		entries.append({
			"item_id": item_id,
			"category": category,
			"category_label": category.capitalize() if category != "" else "Item",
			"display_name": get_item_display_name(item_id),
			"rarity": get_item_rarity(item_id, category),
			"item_instance_id": instance_id,
			"short_instance_id": format_item_instance_id(instance_id),
			"state": str(raw_entry.get("state", "active")).strip_edges(),
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
	var columns := 4
	inventory_lookup_grid.columns = columns
	var card_width: float = 224.0
	var card_height: float = 82.0
	for entry in entries:
		add_item_instance_lookup_card(entry, Vector2(card_width, card_height))

	var rows = int(ceil(float(entries.size()) / float(columns)))
	var total_height = max(INVENTORY_SCROLL_SIZE.y, float(rows) * (card_height + 10.0))
	inventory_lookup_grid.custom_minimum_size = Vector2(INVENTORY_GRID_WIDTH, total_height)
	inventory_lookup_grid.size = inventory_lookup_grid.custom_minimum_size


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
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(str(entry.get("rarity", "common"))))
	inventory_lookup_grid.add_child(card)

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

	var state_label = Label.new()
	var state_text = str(entry.get("state", "active"))
	var created_text = str(entry.get("created_at", ""))
	state_label.text = state_text if created_text == "" else state_text + " | " + created_text
	state_label.position = Vector2(8, 64)
	state_label.size = Vector2(card_size.x - 16, 15)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.clip_text = true
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(state_label, 9)
	card.add_child(state_label)


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
		{"label": "hair", "field": "equipped_hair_item"},
		{"label": "shirt", "field": "equipped_shirt_item"},
		{"label": "pants", "field": "equipped_pants_item"},
		{"label": "shoes", "field": "equipped_shoes_item"},
	]:
		var value = str(player_data.get(str(spec["field"]), "")).strip_edges()
		if value != "":
			parts.append(str(spec["label"]) + ": " + value)
	if parts.is_empty():
		return ""
	return "Equipped: " + join_strings(parts, ", ")


func get_item_icon_texture(item_id: String, category: String):
	if world != null and world.has_method("get_inventory_icon_texture"):
		return world.get_inventory_icon_texture(item_id, category)
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


func join_strings(values: Array, separator: String) -> String:
	var output = ""
	for value in values:
		if output != "":
			output += separator
		output += str(value)
	return output


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

	debug_info_label.text = "Account: " + username + "\nRole: " + role + "\nServer: " + ("connected" if connected else "offline") + "\nWorld: " + world_name + "\nLocal time: " + Time.get_datetime_string_from_system()


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
	var hud_clear: bool = world == null or not (world.has_method("is_movement_blocking_ui_open") and bool(world.is_movement_blocking_ui_open()))
	dev_button.visible = is_developer_allowed() and hud_clear


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
	update_debug_info()
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
