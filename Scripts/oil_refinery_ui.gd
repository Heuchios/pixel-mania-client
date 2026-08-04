extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const WINDOW_SIZE := Vector2(640.0, 430.0)
const MAX_RUNTIME_HOURS: float = 24.0
const CONSUMPTION_RATE_TEXT := "100 W / h"
const OUTPUT_CAPACITY := 200
const CRUDE_OIL_ITEM_ID := "crude_oil"
const CRUDE_OIL_TEXTURE_FALLBACK := "res://Assets/blocks/special_blocks/oil_refinery/crude_oil.png"
const BATTERY_ITEM_ID := "battery"
const BATTERY_ITEM_CATEGORY := "material"
const BATTERY_TEXTURE_PATH := "res://Assets/blocks/electric/battery.png"
const BATTERY_WATTS_PER_ITEM := 20
const BATTERY_INPUT_CAPACITY := 400

var world = null
var overlay: ColorRect = null
var panel: Control = null
var title_label: Label = null
var subtitle_label: Label = null
var status_badge: Label = null
var toggle_button: Button = null
var power_value_label: Label = null
var battery_value_label: Label = null
var metal_pad_value_label: Label = null
var runtime_value_label: Label = null
var output_value_label: Label = null
var footer_label: Label = null
var consumption_rate_label: Label = null
var battery_input_icon: TextureRect = null
var battery_input_label: Label = null
var add_battery_button: Button = null
var output_icon: TextureRect = null
var output_slot_label: Label = null
var output_count_label: Label = null
var runtime_fill: ColorRect = null
var output_fill: ColorRect = null
var close_button: Button = null
var collect_button: Button = null

var current_grid: Vector2i = Vector2i.ZERO
var oil_refinery_open: bool = false
var scene_ui_ready: bool = false
var crude_oil_texture: Texture2D = null
var battery_texture: Texture2D = null


func _ready() -> void:
	bind_scene_ui()
	_apply_texture_filter(self)
	_style_scene()
	_fit_window_to_viewport()
	close_oil_refinery()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_fit_window_to_viewport()


func setup(parent_world, _ui_node = null) -> void:
	world = parent_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 148
	if is_inside_tree():
		bind_scene_ui()
		_apply_texture_filter(self)
		_style_scene()
		_fit_window_to_viewport()
	close_oil_refinery()


func _process(_delta: float) -> void:
	if oil_refinery_open:
		update_position()


func bind_scene_ui() -> bool:
	overlay = get_node_or_null("Dimmer") as ColorRect
	panel = get_node_or_null("Window") as Control
	if panel == null:
		scene_ui_ready = false
		push_error("OilRefineryUI: missing scene Window node.")
		return false

	title_label = panel.get_node_or_null("HeaderCard/TitleLabel") as Label
	subtitle_label = panel.get_node_or_null("HeaderCard/SubtitleLabel") as Label
	status_badge = panel.get_node_or_null("HeaderCard/StatusBadge") as Label
	toggle_button = panel.get_node_or_null("HeaderCard/ToggleButton") as Button
	close_button = panel.get_node_or_null("CloseButton") as Button
	consumption_rate_label = panel.get_node_or_null("PowerCoreCard/ConsumptionRateLabel") as Label
	battery_input_icon = panel.get_node_or_null("PowerCoreCard/BatteryInputSlot/BatteryInputIcon") as TextureRect
	battery_input_label = panel.get_node_or_null("PowerCoreCard/BatteryInputSlot/BatteryInputLabel") as Label
	add_battery_button = panel.get_node_or_null("PowerCoreCard/AddBatteryButton") as Button
	runtime_value_label = panel.get_node_or_null("RuntimeCard/RuntimeValueLabel") as Label
	runtime_fill = panel.get_node_or_null("RuntimeCard/RuntimeMeterBack/RuntimeFill") as ColorRect
	power_value_label = panel.get_node_or_null("InputCard/PowerValueLabel") as Label
	battery_value_label = panel.get_node_or_null("InputCard/BatteryValueLabel") as Label
	metal_pad_value_label = panel.get_node_or_null("InputCard/MetalPadValueLabel") as Label
	output_value_label = panel.get_node_or_null("OutputCard/OutputValueLabel") as Label
	output_icon = panel.get_node_or_null("OutputCard/OutputSlot/OutputIcon") as TextureRect
	output_slot_label = panel.get_node_or_null("OutputCard/OutputSlot/OutputSlotLabel") as Label
	output_count_label = panel.get_node_or_null("OutputCard/OutputCountLabel") as Label
	collect_button = panel.get_node_or_null("OutputCard/CollectButton") as Button
	output_fill = panel.get_node_or_null("ProductionCard/OutputMeterBack/OutputFill") as ColorRect
	footer_label = panel.get_node_or_null("ProductionCard/FooterLabel") as Label

	if overlay != null:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_button(close_button, close_oil_refinery)
	_connect_button(toggle_button, _on_toggle_pressed)
	_connect_button(collect_button, _on_collect_pressed)
	_connect_button(add_battery_button, _on_add_battery_pressed)

	scene_ui_ready = title_label != null and status_badge != null and consumption_rate_label != null and runtime_fill != null and output_fill != null
	if not scene_ui_ready:
		push_error("OilRefineryUI: scene GUI nodes are missing.")
	return scene_ui_ready


func _connect_button(button: Button, callback: Callable) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _style_scene() -> void:
	if panel == null:
		return

	panel.size = WINDOW_SIZE

	for meter_path in [
		"RuntimeCard/RuntimeMeterBack",
		"ProductionCard/OutputMeterBack"
	]:
		var meter_back := panel.get_node_or_null(meter_path) as Panel
		if meter_back != null:
			meter_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
				Color(0.020, 0.050, 0.075, 0.70),
				Color(0.20, 0.45, 0.62, 0.70),
				2,
				8,
				0
			))

	if runtime_fill != null:
		runtime_fill.color = PixelUIStyle.OK_GREEN
	if output_fill != null:
		output_fill.color = PixelUIStyle.ACTION_YELLOW

	PixelUIStyle.apply_label_shadow(title_label, 27, PixelUIStyle.TEXT_LIGHT)
	PixelUIStyle.apply_small_label(subtitle_label, 14)
	PixelUIStyle.apply_label_shadow(status_badge, 18, PixelUIStyle.TEXT_LIGHT)
	PixelUIStyle.apply_button_text(close_button, 20)
	PixelUIStyle.apply_button_text(toggle_button, 15)
	PixelUIStyle.apply_button_text(collect_button, 15)
	PixelUIStyle.apply_button_text(add_battery_button, 15)
	if close_button != null:
		close_button.text = "X"
	if add_battery_button != null:
		add_battery_button.text = "ADD"

	for section_path in [
		"PowerCoreCard/PowerCoreTitle",
		"RuntimeCard/RuntimeTitle",
		"InputCard/InputTitle",
		"OutputCard/OutputTitle",
		"ProductionCard/ProductionTitle"
	]:
		PixelUIStyle.apply_section_title(panel.get_node_or_null(section_path) as Label, 17)

	for label_path in [
		"PowerCoreCard/ConsumptionLabel",
		"PowerCoreCard/ConsumptionRateLabel",
		"PowerCoreCard/BatteryInputSlot/BatteryInputLabel",
		"RuntimeCard/RuntimeValueLabel",
		"InputCard/PowerValueLabel",
		"InputCard/BatteryValueLabel",
		"InputCard/MetalPadValueLabel",
		"OutputCard/OutputValueLabel",
		"OutputCard/OutputSlot/OutputSlotLabel",
		"OutputCard/OutputCountLabel",
		"ProductionCard/FooterLabel"
	]:
		PixelUIStyle.apply_small_label(panel.get_node_or_null(label_path) as Label, 14)

	if status_badge != null:
		status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if runtime_value_label != null:
		runtime_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if consumption_rate_label != null:
		consumption_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		consumption_rate_label.text = CONSUMPTION_RATE_TEXT
	if battery_input_icon != null:
		battery_input_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battery_input_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		battery_input_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		battery_input_icon.texture = get_battery_texture()
	if battery_input_label != null:
		battery_input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		battery_input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		battery_input_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if footer_label != null:
		footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if output_icon != null:
		output_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		output_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func get_crude_oil_texture() -> Texture2D:
	if crude_oil_texture != null:
		return crude_oil_texture

	var texture_path := CRUDE_OIL_TEXTURE_FALLBACK
	if world != null and "item_database" in world and world.item_database.has(CRUDE_OIL_ITEM_ID):
		var item_data = world.item_database[CRUDE_OIL_ITEM_ID]
		if item_data is Dictionary:
			texture_path = str(item_data.get("inventory_icon", item_data.get("texture", CRUDE_OIL_TEXTURE_FALLBACK))).strip_edges()
	if texture_path == "":
		texture_path = CRUDE_OIL_TEXTURE_FALLBACK

	if ResourceLoader.exists(texture_path):
		var loaded_texture = load(texture_path)
		if loaded_texture is Texture2D:
			crude_oil_texture = loaded_texture
	return crude_oil_texture


func get_battery_texture() -> Texture2D:
	if battery_texture != null:
		return battery_texture
	if ResourceLoader.exists(BATTERY_TEXTURE_PATH):
		var loaded_texture = load(BATTERY_TEXTURE_PATH)
		if loaded_texture is Texture2D:
			battery_texture = loaded_texture
	return battery_texture


func get_battery_watts_from_state(state: Dictionary) -> int:
	var battery_watts := int(state.get("battery_watts", state.get("input_battery_watts", 0)))
	if battery_watts > 0:
		return clampi(battery_watts, 0, BATTERY_INPUT_CAPACITY * BATTERY_WATTS_PER_ITEM)
	var battery_count := int(state.get("battery_count", state.get("input_battery_count", 0)))
	return clampi(battery_count, 0, BATTERY_INPUT_CAPACITY) * BATTERY_WATTS_PER_ITEM


func get_battery_count_from_watts(battery_watts: int) -> int:
	var clean_watts := clampi(battery_watts, 0, BATTERY_INPUT_CAPACITY * BATTERY_WATTS_PER_ITEM)
	if clean_watts <= 0:
		return 0
	return clampi(int(ceil(float(clean_watts) / float(BATTERY_WATTS_PER_ITEM))), 1, BATTERY_INPUT_CAPACITY)


func get_owned_battery_count() -> int:
	if world == null:
		return 0
	if world.has_method("get_item_count"):
		return maxi(0, int(world.get_item_count(BATTERY_ITEM_ID, BATTERY_ITEM_CATEGORY)))
	if "material_inventory" in world and world.material_inventory is Dictionary:
		return maxi(0, int(world.material_inventory.get(BATTERY_ITEM_ID, 0)))
	return 0


func set_meter(fill: ColorRect, ratio: float) -> void:
	if fill == null:
		return
	var parent_control: Control = fill.get_parent() as Control
	if parent_control == null:
		return
	var clean_ratio: float = clamp(ratio, 0.0, 1.0)
	fill.size = Vector2(max(0.0, parent_control.size.x - 8.0) * clean_ratio, max(0.0, parent_control.size.y - 8.0))


func update_position() -> void:
	if panel == null:
		return
	var screen_size: Vector2 = get_viewport_rect().size
	panel.position = Vector2(
		floor((screen_size.x - WINDOW_SIZE.x) * 0.5),
		floor(max(28.0, (screen_size.y - WINDOW_SIZE.y) * 0.5))
	)


func _fit_window_to_viewport() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var safe_size := Vector2(maxf(1.0, viewport_size.x - 32.0), maxf(1.0, viewport_size.y - 32.0))
	var scale_amount := minf(1.0, minf(safe_size.x / WINDOW_SIZE.x, safe_size.y / WINDOW_SIZE.y))
	panel.pivot_offset = WINDOW_SIZE * 0.5
	panel.scale = Vector2.ONE * clampf(scale_amount, 0.62, 1.0)
	update_position()


func _apply_texture_filter(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_apply_texture_filter(child)


func open_oil_refinery(grid_pos: Vector2i) -> void:
	if world != null and world.has_method("can_current_player_use_oil_refinery") and not bool(world.can_current_player_use_oil_refinery()):
		if world.has_method("show_notification"):
			if "world_lock_manager" in world and world.world_lock_manager != null and not bool(world.world_lock_manager.is_locked):
				world.show_notification("Lock this world before using the oil refinery.")
			else:
				world.show_notification("Only the world owner or world admins can use the oil refinery.")
		return

	if not scene_ui_ready and not bind_scene_ui():
		return

	current_grid = grid_pos
	oil_refinery_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	update_position()
	refresh()
	send_oil_refinery_request("open")
	move_to_front()
	if panel != null:
		PixelUIStyle.play_panel_open(panel)


func close_oil_refinery() -> void:
	if world != null and world.has_method("is_oil_refinery_battery_selecting") and bool(world.is_oil_refinery_battery_selecting()):
		world.end_oil_refinery_battery_select(true)
	oil_refinery_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false


func is_oil_refinery_open() -> bool:
	return oil_refinery_open and visible


func get_current_state() -> Dictionary:
	if world == null or not ("oil_refinery_states" in world):
		return {}
	var states_value: Variant = world.oil_refinery_states
	if not (states_value is Dictionary):
		return {}
	var states: Dictionary = states_value
	var state_value: Variant = states.get(current_grid, {})
	if state_value is Dictionary:
		return state_value
	return {}


func refresh() -> void:
	var state: Dictionary = get_current_state()
	var direct_power: bool = bool(state.get("direct_power", state.get("powered", false)))
	var linked_pole: bool = bool(state.get("linked_pole", false)) or state.has("linked_pole_x") or state.has("pole_x")
	var crude_progress: float = clamp(float(state.get("crude_progress", 0.0)), 0.0, 1.0)
	var enabled: bool = bool(state.get("enabled", state.get("machine_enabled", false)))
	var running: bool = bool(state.get("running", state.get("is_running", state.get("processing", false))))
	var produced_count: int = int(state.get("produced_count", state.get("output_count", 0)))
	var output_capacity: int = maxi(1, int(state.get("output_capacity", OUTPUT_CAPACITY)))
	produced_count = clampi(produced_count, 0, output_capacity)
	if crude_progress >= 1.0:
		produced_count = maxi(1, produced_count)
	var output_full: bool = produced_count >= output_capacity
	var transformer_watts: int = int(state.get("transformer_watts", state.get("available_watts", 0)))
	var battery_watts := get_battery_watts_from_state(state)
	var battery_count := get_battery_count_from_watts(battery_watts)
	var battery_powered := bool(state.get("battery_powered", false))
	var power_source := str(state.get("power_source", "")).strip_edges().to_lower()
	if power_source == "" and battery_powered:
		power_source = "battery"
	var has_power: bool = enabled and (running or direct_power)

	if status_badge != null:
		status_badge.text = "FULL" if output_full else ("POWERED" if has_power else "OFFLINE")
		status_badge.add_theme_stylebox_override("normal", PixelUIStyle.status_badge_style("good" if has_power else "danger"))
	if toggle_button != null:
		toggle_button.text = "TURN OFF" if enabled else "TURN ON"
		toggle_button.disabled = output_full and not enabled

	if power_value_label != null:
		power_value_label.text = "Transformer: " + str(transformer_watts) + " W" if linked_pole else "Transformer: none"
	if battery_value_label != null:
		battery_value_label.visible = true
		battery_value_label.text = "Battery: " + str(battery_watts) + " W (" + str(battery_count) + " / " + str(BATTERY_INPUT_CAPACITY) + ")"
	if metal_pad_value_label != null:
		metal_pad_value_label.visible = true
		if power_source == "hybrid":
			metal_pad_value_label.text = "Source: transformer + battery"
		elif power_source == "battery":
			metal_pad_value_label.text = "Source: battery"
		elif power_source == "transformer":
			metal_pad_value_label.text = "Source: transformer"
		else:
			metal_pad_value_label.text = "Power: online" if direct_power else "Power: offline"
	if runtime_value_label != null:
		runtime_value_label.text = format_hours(crude_progress) + " / 1h"
	if output_value_label != null:
		output_value_label.text = "Crude oil: full" if output_full else ("Crude oil: ready" if produced_count > 0 else ("Crude oil: running" if has_power else "Crude oil: idle"))
	var has_output := produced_count > 0
	var has_output_icon := false
	if output_icon != null:
		output_icon.texture = get_crude_oil_texture() if has_output else null
		has_output_icon = has_output and output_icon.texture != null
		output_icon.visible = has_output_icon
	if output_slot_label != null:
		output_slot_label.text = "CRUDE\nOIL" if has_output else "EMPTY"
		output_slot_label.visible = not has_output_icon
	if output_count_label != null:
		output_count_label.text = "x" + str(produced_count) + " / " + str(output_capacity) if has_output else "Empty"
	if collect_button != null:
		collect_button.disabled = produced_count <= 0
	if battery_input_icon != null:
		battery_input_icon.texture = get_battery_texture()
		battery_input_icon.visible = battery_count > 0
	if battery_input_label != null:
		battery_input_label.text = ("x" + str(battery_count) + "\n" + str(battery_watts) + " W") if battery_count > 0 else "BATTERY\nEMPTY"
	if add_battery_button != null:
		var available_slots: int = maxi(0, BATTERY_INPUT_CAPACITY - battery_count)
		add_battery_button.disabled = available_slots <= 0 or get_owned_battery_count() <= 0
	if footer_label != null:
		if output_full:
			footer_label.text = "Output full"
		elif produced_count > 0:
			footer_label.text = "Ready to collect"
		elif running and power_source == "hybrid":
			footer_label.text = "Producing from transformer + battery"
		elif running and power_source == "battery":
			footer_label.text = "Producing from battery"
		elif running:
			footer_label.text = "Producing crude oil"
		elif enabled and not linked_pole and battery_watts <= 0:
			footer_label.text = "Add batteries or link pole"
		elif enabled:
			footer_label.text = "Awaiting transformer or battery power"
		else:
			footer_label.text = "Turn on to begin"
	if consumption_rate_label != null:
		consumption_rate_label.text = CONSUMPTION_RATE_TEXT

	set_meter(runtime_fill, crude_progress)
	set_meter(output_fill, 1.0 if produced_count > 0 else crude_progress)


func format_hours(value: float) -> String:
	if value <= 0.0:
		return "0h"
	if value < 1.0:
		return str(int(round(value * 60.0))) + "m"
	var hours: int = int(floor(value))
	var minutes: int = int(round((value - float(hours)) * 60.0))
	if minutes <= 0:
		return str(hours) + "h"
	return str(hours) + "h " + str(minutes) + "m"


func handle_oil_refinery_state(data: Dictionary) -> void:
	var refresh_grid := current_grid
	if data.has("x") and data.has("y"):
		refresh_grid = Vector2i(int(data.get("x", current_grid.x)), int(data.get("y", current_grid.y)))
	if world != null and "oil_refinery_states" in world and ((data.has("x") and data.has("y")) or is_oil_refinery_open()):
		if not (world.oil_refinery_states is Dictionary):
			world.oil_refinery_states = {}
		var state: Dictionary = {}
		if world.oil_refinery_states.has(refresh_grid) and world.oil_refinery_states[refresh_grid] is Dictionary:
			state = world.oil_refinery_states[refresh_grid].duplicate(true)
		for key in data.keys():
			if key == "x" or key == "y":
				continue
			state[key] = data[key]
		world.oil_refinery_states[refresh_grid] = state
	if world != null and world.has_method("refresh_oil_refinery_visual"):
		world.refresh_oil_refinery_visual(refresh_grid)
	if is_oil_refinery_open() and refresh_grid == current_grid:
		refresh()


func _on_toggle_pressed() -> void:
	var state := get_current_state()
	var output_capacity: int = maxi(1, int(state.get("output_capacity", OUTPUT_CAPACITY)))
	var produced_count: int = int(state.get("produced_count", state.get("output_count", 0)))
	var next_enabled: bool = not bool(state.get("enabled", state.get("machine_enabled", false)))
	if next_enabled and produced_count >= output_capacity:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Collect crude oil before turning the refinery on.")
		return
	if not send_oil_refinery_request("toggle", {"enabled": next_enabled}):
		apply_local_state_patch({"enabled": next_enabled})


func _on_collect_pressed() -> void:
	var state := get_current_state()
	var produced_count: int = int(state.get("produced_count", state.get("output_count", 0)))
	if produced_count <= 0 and float(state.get("crude_progress", 0.0)) < 1.0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Oil refinery output is empty.")
		return
	if not send_oil_refinery_request("collect"):
		apply_local_state_patch({
			"produced_count": 0,
			"output_count": 0,
			"crude_progress": 0.0
		})
		if world != null and world.has_method("show_notification"):
			world.show_notification("Crude oil collection will be available when the item is added.")


func _on_add_battery_pressed() -> void:
	var state := get_current_state()
	var battery_watts := get_battery_watts_from_state(state)
	var battery_count := get_battery_count_from_watts(battery_watts)
	var available_slots: int = maxi(0, BATTERY_INPUT_CAPACITY - battery_count)
	if available_slots <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Oil refinery battery input is full.")
		return
	var owned_batteries := get_owned_battery_count()
	if owned_batteries <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("You do not have any batteries.")
		return

	if world != null and world.has_method("begin_oil_refinery_battery_select"):
		world.begin_oil_refinery_battery_select()
		return
	if world != null and world.has_method("open_inventory_window"):
		world.open_inventory_window()
		if world.has_method("show_notification"):
			world.show_notification("Select batteries from inventory.")
		return
	if world != null and world.has_method("show_notification"):
		world.show_notification("Inventory is not ready.")


func add_inventory_item_to_oil_refinery(item_type: String, category: String, amount: int) -> bool:
	if not is_oil_refinery_open():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Open an oil refinery first.")
		return false
	if item_type != BATTERY_ITEM_ID or category != BATTERY_ITEM_CATEGORY:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Only batteries can power the oil refinery.")
		return false

	var state := get_current_state()
	var battery_watts := get_battery_watts_from_state(state)
	var battery_count := get_battery_count_from_watts(battery_watts)
	var available_slots: int = maxi(0, BATTERY_INPUT_CAPACITY - battery_count)
	if available_slots <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Oil refinery battery input is full.")
		return false

	var owned_batteries := get_owned_battery_count()
	if owned_batteries <= 0:
		if world != null and world.has_method("show_notification"):
			world.show_notification("You do not have any batteries.")
		return false

	var add_amount: int = clampi(amount, 1, mini(available_slots, owned_batteries))
	if not send_oil_refinery_request("add_battery", {"amount": add_amount}):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Connection required to add batteries.")
		return false
	return true


func send_oil_refinery_request(operation: String, extra_data: Dictionary = {}) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null and world.has_method("get_node_or_null") else null
	if network == null:
		return false
	if network.has_method("send_oil_refinery_request"):
		return bool(network.send_oil_refinery_request(current_grid, operation, extra_data, world.current_world_name if "current_world_name" in world else ""))
	return false


func apply_local_state_patch(patch: Dictionary) -> void:
	if world == null or not ("oil_refinery_states" in world):
		return
	if not (world.oil_refinery_states is Dictionary):
		world.oil_refinery_states = {}
	var state: Dictionary = {}
	if world.oil_refinery_states.has(current_grid) and world.oil_refinery_states[current_grid] is Dictionary:
		state = world.oil_refinery_states[current_grid].duplicate(true)
	for key in patch.keys():
		state[key] = patch[key]
	world.oil_refinery_states[current_grid] = state
	if world.has_method("refresh_oil_refinery_visual"):
		world.refresh_oil_refinery_visual(current_grid)
	refresh()
