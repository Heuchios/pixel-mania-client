extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const WINDOW_SIZE := Vector2(620.0, 390.0)
const BATTERY_TEXTURE_PATH := "res://Assets/blocks/electric/battery.png"
const DEFAULT_OUTPUT_CAPACITY := 200
const DEFAULT_MAX_HOURS := 24.0
const PRODUCTION_RATE_TEXT := "3 batteries / h"
const CONSUMPTION_RATE_TEXT := "80 W / h"

signal start_requested(grid_pos: Vector2i)
signal eject_requested(grid_pos: Vector2i)
signal collect_requested(grid_pos: Vector2i)

var world = null
var overlay: ColorRect = null
var panel: Control = null
var title_label: Label = null
var subtitle_label: Label = null
var status_badge: Label = null
var close_button: Button = null
var start_button: Button = null
var eject_button: Button = null
var collect_button: Button = null
var charge_value_label: Label = null
var input_label: Label = null
var output_label: Label = null
var power_label: Label = null
var stored_label: Label = null
var footer_label: Label = null
var input_battery_icon: TextureRect = null
var output_battery_icon: TextureRect = null
var charge_fill: ColorRect = null

var current_grid := Vector2i.ZERO
var battery_charger_open := false
var scene_ui_ready := false
var battery_texture: Texture2D = null
var local_state: Dictionary = {}


func _ready() -> void:
	bind_scene_ui()
	_apply_texture_filter(self)
	_style_scene()
	_fit_window_to_viewport()
	close_battery_charger()


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
	close_battery_charger()


func _process(_delta: float) -> void:
	if battery_charger_open:
		update_position()


func bind_scene_ui() -> bool:
	overlay = get_node_or_null("Dimmer") as ColorRect
	panel = get_node_or_null("Window") as Control
	if panel == null:
		scene_ui_ready = false
		push_error("BatteryChargerUI: missing scene Window node.")
		return false

	title_label = panel.get_node_or_null("HeaderCard/TitleLabel") as Label
	subtitle_label = panel.get_node_or_null("HeaderCard/SubtitleLabel") as Label
	status_badge = panel.get_node_or_null("HeaderCard/StatusBadge") as Label
	close_button = panel.get_node_or_null("CloseButton") as Button
	start_button = panel.get_node_or_null("ActionCard/StartButton") as Button
	eject_button = panel.get_node_or_null("ActionCard/EjectButton") as Button
	collect_button = panel.get_node_or_null("BatteryCard/CollectButton") as Button
	charge_value_label = panel.get_node_or_null("ChargeCard/ChargeValueLabel") as Label
	power_label = panel.get_node_or_null("ChargeCard/PowerLabel") as Label
	stored_label = panel.get_node_or_null("ChargeCard/StoredLabel") as Label
	input_label = panel.get_node_or_null("BatteryCard/InputLabel") as Label
	output_label = panel.get_node_or_null("BatteryCard/OutputLabel") as Label
	footer_label = panel.get_node_or_null("FooterCard/FooterLabel") as Label
	input_battery_icon = panel.get_node_or_null("BatteryCard/InputBatterySlot/InputBatteryIcon") as TextureRect
	output_battery_icon = panel.get_node_or_null("BatteryCard/OutputBatterySlot/OutputBatteryIcon") as TextureRect
	charge_fill = panel.get_node_or_null("ChargeCard/ChargeMeterBack/ChargeFill") as ColorRect

	if overlay != null:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_connect_button(close_button, close_battery_charger)
	_connect_button(start_button, _on_start_pressed)
	_connect_button(eject_button, _on_eject_pressed)
	_connect_button(collect_button, _on_collect_pressed)

	scene_ui_ready = title_label != null and status_badge != null and charge_value_label != null and charge_fill != null
	if not scene_ui_ready:
		push_error("BatteryChargerUI: scene GUI nodes are missing.")
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

	PixelUIStyle.apply_label_shadow(title_label, 27, PixelUIStyle.TEXT_LIGHT)
	PixelUIStyle.apply_small_label(subtitle_label, 14)
	PixelUIStyle.apply_label_shadow(status_badge, 18, PixelUIStyle.TEXT_LIGHT)
	PixelUIStyle.apply_button_text(close_button, 20)
	PixelUIStyle.apply_button_text(start_button, 16)
	PixelUIStyle.apply_button_text(eject_button, 16)
	PixelUIStyle.apply_button_text(collect_button, 15)

	if close_button != null:
		close_button.text = "X"
	if start_button != null:
		start_button.text = "START"
	if eject_button != null:
		eject_button.text = "EJECT"
		eject_button.visible = false
		eject_button.disabled = true
	if collect_button != null:
		collect_button.text = "COLLECT"

	for section_path in [
		"BatteryCard/BatteryTitle",
		"ChargeCard/ChargeTitle",
		"ActionCard/ActionTitle"
	]:
		PixelUIStyle.apply_section_title(panel.get_node_or_null(section_path) as Label, 17)

	for label_path in [
		"BatteryCard/InputLabel",
		"BatteryCard/OutputLabel",
		"ChargeCard/ChargeValueLabel",
		"ChargeCard/PowerLabel",
		"ChargeCard/StoredLabel",
		"FooterCard/FooterLabel"
	]:
		PixelUIStyle.apply_small_label(panel.get_node_or_null(label_path) as Label, 14)

	if status_badge != null:
		status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if charge_value_label != null:
		charge_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if footer_label != null:
		footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		footer_label.clip_text = true

	for slot_path in [
		"BatteryCard/InputBatterySlot/InputBatteryIcon",
		"BatteryCard/OutputBatterySlot/OutputBatteryIcon"
	]:
		var texture_rect := panel.get_node_or_null(slot_path) as TextureRect
		if texture_rect != null:
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.texture = get_battery_texture()

	var meter_back := panel.get_node_or_null("ChargeCard/ChargeMeterBack") as Panel
	if meter_back != null:
		meter_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.020, 0.050, 0.075, 0.70),
			Color(0.20, 0.45, 0.62, 0.70),
			2,
			8,
			0
		))
	if charge_fill != null:
		charge_fill.color = PixelUIStyle.ACTION_YELLOW


func get_battery_texture() -> Texture2D:
	if battery_texture != null:
		return battery_texture
	if ResourceLoader.exists(BATTERY_TEXTURE_PATH):
		var loaded_texture := load(BATTERY_TEXTURE_PATH)
		if loaded_texture is Texture2D:
			battery_texture = loaded_texture
	return battery_texture


func open_battery_charger(grid_pos: Vector2i, data: Dictionary = {}) -> void:
	if not scene_ui_ready and not bind_scene_ui():
		return

	current_grid = grid_pos
	if not data.is_empty():
		local_state = data.duplicate(true)
	battery_charger_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	update_position()
	refresh()
	_send_battery_charger_request("open")
	move_to_front()
	if panel != null:
		PixelUIStyle.play_panel_open(panel)


func close_battery_charger() -> void:
	battery_charger_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false


func is_battery_charger_open() -> bool:
	return battery_charger_open and visible


func update_battery_charger(data: Dictionary) -> void:
	var refresh_grid := current_grid
	if data.has("x") and data.has("y"):
		refresh_grid = Vector2i(int(data.get("x", current_grid.x)), int(data.get("y", current_grid.y)))

	if refresh_grid == current_grid:
		for key in data.keys():
			if key == "x" or key == "y":
				continue
			local_state[key] = data[key]

	_store_world_state(refresh_grid, data)
	if is_battery_charger_open() and refresh_grid == current_grid:
		refresh()


func handle_battery_charger_state(data: Dictionary) -> void:
	update_battery_charger(data)


func get_current_state() -> Dictionary:
	var state := local_state.duplicate(true)
	if world == null or not ("battery_charger_states" in world):
		return state
	var states_value: Variant = world.battery_charger_states
	if not (states_value is Dictionary):
		return state
	var states: Dictionary = states_value
	var state_value: Variant = states.get(current_grid, {})
	if state_value is Dictionary:
		var world_state: Dictionary = state_value
		for key in world_state.keys():
			state[key] = world_state[key]
	return state


func refresh() -> void:
	var state := get_current_state()
	var production_progress := _read_charge_ratio(state)
	var output_capacity := maxi(1, int(state.get("output_capacity", DEFAULT_OUTPUT_CAPACITY)))
	var produced_count := clampi(int(state.get("output_count", state.get("produced_count", 0))), 0, output_capacity)
	var enabled := bool(state.get("enabled", state.get("machine_enabled", state.get("running", false))))
	var running := bool(state.get("running", state.get("is_running", state.get("charging", false))))
	var linked_pole := bool(state.get("linked_pole", false)) or state.has("linked_pole_x") or state.has("pole_x")
	var direct_power := bool(state.get("direct_power", state.get("powered", false)))
	var transformer_watts := maxi(0, int(state.get("transformer_watts", state.get("available_watts", state.get("input_watts", state.get("watts", 0))))))
	var output_full := produced_count >= output_capacity
	var has_output_battery := produced_count > 0
	var has_power := enabled and (running or direct_power)
	if output_full:
		production_progress = 0.0

	if status_badge != null:
		var status_text := "IDLE"
		var status_style := "neutral"
		if output_full:
			status_text = "FULL"
			status_style = "good"
		elif has_power:
			status_text = "RUNNING"
			status_style = "good"
		elif enabled and linked_pole:
			status_text = "WAITING"
			status_style = "warning"
		elif not linked_pole:
			status_text = "UNLINKED"
			status_style = "danger"
		status_badge.text = status_text
		status_badge.add_theme_stylebox_override("normal", PixelUIStyle.status_badge_style(status_style))

	if charge_value_label != null:
		charge_value_label.text = str(int(round(production_progress * 100.0))) + "%"
	if power_label != null:
		power_label.text = "Transformer: " + str(transformer_watts) + " W" if linked_pole else "Pole: none"
	if stored_label != null:
		stored_label.text = "Output: " + str(produced_count) + " / " + str(output_capacity)
	if input_label != null:
		input_label.text = "Consumes: " + CONSUMPTION_RATE_TEXT
	if output_label != null:
		output_label.text = "Output: x" + str(produced_count) if has_output_battery else "Output: empty"
	if footer_label != null:
		if output_full:
			footer_label.text = "Output full"
		elif has_output_battery:
			footer_label.text = "Ready to collect"
		elif has_power:
			footer_label.text = "Producing batteries"
		elif enabled and not linked_pole:
			footer_label.text = "Link an electric pole"
		elif enabled:
			footer_label.text = "Awaiting transformer power"
		else:
			footer_label.text = "Turn on to begin"

	if input_battery_icon != null:
		input_battery_icon.texture = get_battery_texture()
		input_battery_icon.visible = false
	if output_battery_icon != null:
		output_battery_icon.texture = get_battery_texture()
		output_battery_icon.visible = has_output_battery

	if start_button != null:
		start_button.text = "TURN OFF" if enabled else "TURN ON"
		start_button.disabled = output_full and not enabled
	if eject_button != null:
		eject_button.visible = false
		eject_button.disabled = true
	if collect_button != null:
		collect_button.disabled = produced_count <= 0

	set_meter(charge_fill, 1.0 if output_full else production_progress)


func _read_charge_ratio(state: Dictionary) -> float:
	if state.has("battery_progress"):
		return clampf(float(state.get("battery_progress", 0.0)), 0.0, 1.0)
	if state.has("production_progress"):
		return clampf(float(state.get("production_progress", 0.0)), 0.0, 1.0)
	if state.has("charge_ratio"):
		return clampf(float(state.get("charge_ratio", 0.0)), 0.0, 1.0)
	if state.has("charge_percent"):
		return clampf(float(state.get("charge_percent", 0.0)) / 100.0, 0.0, 1.0)
	if state.has("stored_hours") or state.has("capacity_hours") or state.has("max_hours"):
		var stored_hours := float(state.get("stored_hours", state.get("hours", 0.0)))
		var max_hours := maxf(1.0, float(state.get("max_hours", state.get("capacity_hours", DEFAULT_MAX_HOURS))))
		return clampf(stored_hours / max_hours, 0.0, 1.0)
	var current_charge := float(state.get("charge", 0.0))
	var max_charge := maxf(1.0, float(state.get("max_charge", 100.0)))
	return clampf(current_charge / max_charge, 0.0, 1.0)


func set_meter(fill: ColorRect, ratio: float) -> void:
	if fill == null:
		return
	var parent_control := fill.get_parent() as Control
	if parent_control == null:
		return
	var clean_ratio := clampf(ratio, 0.0, 1.0)
	fill.size = Vector2(maxf(0.0, parent_control.size.x - 8.0) * clean_ratio, maxf(0.0, parent_control.size.y - 8.0))


func format_hours(value: float) -> String:
	if value <= 0.0:
		return "0h"
	if value < 1.0:
		return str(int(round(value * 60.0))) + "m"
	var hours := int(floor(value))
	var minutes := int(round((value - float(hours)) * 60.0))
	if minutes <= 0:
		return str(hours) + "h"
	return str(hours) + "h " + str(minutes) + "m"


func update_position() -> void:
	if panel == null:
		return
	var screen_size := get_viewport_rect().size
	panel.position = Vector2(
		floor((screen_size.x - WINDOW_SIZE.x) * 0.5),
		floor(maxf(28.0, (screen_size.y - WINDOW_SIZE.y) * 0.5))
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


func _on_start_pressed() -> void:
	start_requested.emit(current_grid)
	var state := get_current_state()
	var output_capacity := maxi(1, int(state.get("output_capacity", DEFAULT_OUTPUT_CAPACITY)))
	var produced_count := clampi(int(state.get("output_count", state.get("produced_count", 0))), 0, output_capacity)
	var next_enabled := not bool(state.get("enabled", state.get("machine_enabled", state.get("running", false))))
	if next_enabled and produced_count >= output_capacity:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Collect batteries before turning the charger on.")
		return
	if _send_battery_charger_request("toggle", {"enabled": next_enabled}):
		return
	if _call_world_method(["request_battery_charger_toggle", "toggle_battery_charger"], [current_grid, next_enabled]):
		return
	apply_local_state_patch({
		"enabled": next_enabled,
		"machine_enabled": next_enabled,
		"running": false,
		"charging": false
	})


func _on_eject_pressed() -> void:
	eject_requested.emit(current_grid)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Battery chargers only collect produced batteries.")


func _on_collect_pressed() -> void:
	collect_requested.emit(current_grid)
	if _send_battery_charger_request("collect"):
		return
	if _call_world_method(["request_battery_charger_collect", "collect_battery_charger"], [current_grid]):
		return
	apply_local_state_patch({
		"output_count": 0,
		"produced_count": 0,
		"battery_progress": 0.0,
		"production_progress": 0.0
	})


func _send_battery_charger_request(operation: String, extra_data: Dictionary = {}) -> bool:
	var network = world.get_node_or_null("/root/NetworkManager") if world != null and world.has_method("get_node_or_null") else null
	if network == null:
		return false
	if network.has_method("send_battery_charger_request"):
		return bool(network.send_battery_charger_request(current_grid, operation, extra_data, world.current_world_name if "current_world_name" in world else ""))
	return false


func _call_world_method(method_names: Array, args: Array) -> bool:
	if world == null:
		return false
	for method_name in method_names:
		if world.has_method(str(method_name)):
			var result = world.callv(str(method_name), args)
			return result == null or bool(result)
	return false


func apply_local_state_patch(patch: Dictionary) -> void:
	for key in patch.keys():
		local_state[key] = patch[key]
	_store_world_state(current_grid, patch)
	refresh()


func _store_world_state(grid_pos: Vector2i, data: Dictionary) -> void:
	if world == null or not ("battery_charger_states" in world):
		return
	if not (world.battery_charger_states is Dictionary):
		world.battery_charger_states = {}
	var state: Dictionary = {}
	if world.battery_charger_states.has(grid_pos) and world.battery_charger_states[grid_pos] is Dictionary:
		state = world.battery_charger_states[grid_pos].duplicate(true)
	for key in data.keys():
		if key == "x" or key == "y":
			continue
		state[key] = data[key]
	world.battery_charger_states[grid_pos] = state
