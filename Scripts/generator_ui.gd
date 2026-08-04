extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const WINDOW_SIZE := Vector2(520, 360)
const DEFAULT_MAX_WATTS := 1000
const MAX_CIRCUITS := 4
const DEFAULT_CIRCUIT_CAPACITY := 5
const TOTAL_LINK_CAPACITY := MAX_CIRCUITS * DEFAULT_CIRCUIT_CAPACITY
const MAX_OUTPUT_GROUPS := 4
const DEFAULT_OUTPUT_CAPACITY := 5
const TOTAL_OUTPUT_CAPACITY := MAX_OUTPUT_GROUPS * DEFAULT_OUTPUT_CAPACITY
const CIRCUIT_LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var world = null
var current_grid := Vector2i.ZERO
var panel: Control = null
var title_label: Label = null
var watts_label: Label = null
var status_label: Label = null
var circuit_scroll: ScrollContainer = null
var circuit_list: VBoxContainer = null
var circuit_row_labels: Array[Label] = []
var total_circuits_label: Label = null
var output_scroll: ScrollContainer = null
var output_list: VBoxContainer = null
var output_row_labels: Array[Label] = []
var total_outputs_label: Label = null
var progress_bar: ProgressBar = null
var close_button: Button = null
var scene_ui_ready := false


func _ready() -> void:
	bind_scene_ui()
	_apply_texture_filter(self)
	_style_scene()
	_fit_window_to_viewport()
	close_generator()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_fit_window_to_viewport()


func setup(world_ref) -> void:
	world = world_ref
	name = "GeneratorUI"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 145
	if is_inside_tree():
		bind_scene_ui()
		_style_scene()
		_fit_window_to_viewport()


func bind_scene_ui() -> bool:
	panel = get_node_or_null("Window") as Control
	if panel == null:
		scene_ui_ready = false
		push_error("GeneratorUI: missing scene Window node.")
		return false

	title_label = panel.get_node_or_null("TitleLabel") as Label
	close_button = panel.get_node_or_null("CloseButton") as Button
	watts_label = panel.get_node_or_null("MeterCard/WattsLabel") as Label
	progress_bar = panel.get_node_or_null("MeterCard/ProgressBar") as ProgressBar
	status_label = panel.get_node_or_null("NetworkCard/StatusLabel") as Label
	circuit_scroll = panel.get_node_or_null("ConnectionsCard/CircuitScroll") as ScrollContainer
	circuit_list = panel.get_node_or_null("ConnectionsCard/CircuitScroll/CircuitList") as VBoxContainer
	total_circuits_label = panel.get_node_or_null("ConnectionsCard/CircuitScroll/CircuitList/TotalCircuitsLabel") as Label
	output_scroll = panel.get_node_or_null("OutputsCard/OutputScroll") as ScrollContainer
	output_list = panel.get_node_or_null("OutputsCard/OutputScroll/OutputList") as VBoxContainer
	total_outputs_label = panel.get_node_or_null("OutputsCard/OutputScroll/OutputList/TotalOutputsLabel") as Label

	var dimmer := get_node_or_null("Dimmer") as Control
	if dimmer != null:
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_connect_button(close_button, close_generator)

	scene_ui_ready = title_label != null and watts_label != null and progress_bar != null and circuit_list != null and output_list != null
	if not scene_ui_ready:
		push_error("GeneratorUI: scene GUI nodes are missing.")
	else:
		_bind_circuit_placeholders()
		_bind_output_placeholders()
		_update_circuit_rows({})
		_update_output_rows({})
	return scene_ui_ready


func _connect_button(button: Button, callback: Callable) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _style_scene() -> void:
	if title_label != null:
		title_label.text = "TRANSFORMER"
		PixelUIStyle.apply_label_shadow(title_label, 32, Color(0.96, 0.99, 1.0, 1.0))
	for label in [watts_label, status_label]:
		PixelUIStyle.apply_small_label(label as Label, 15)

	for node_path in [
		"Window/MeterCard/MeterTitle",
		"Window/NetworkCard/NetworkTitle",
		"Window/ConnectionsCard/ConnectionsTitle",
		"Window/OutputsCard/OutputsTitle"
	]:
		var section_label := get_node_or_null(node_path) as Label
		if section_label != null:
			if node_path == "Window/MeterCard/MeterTitle":
				section_label.text = "INPUT"
			PixelUIStyle.apply_section_title(section_label, 18)

	PixelUIStyle.apply_button_text(close_button, 20)
	if close_button != null:
		close_button.text = "X"

	if status_label != null:
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.clip_text = true

	if progress_bar != null:
		progress_bar.show_percentage = false
		progress_bar.min_value = 0
		progress_bar.max_value = DEFAULT_MAX_WATTS
		progress_bar.value = 0
		progress_bar.add_theme_stylebox_override("background", PixelUIStyle.style_box(
			Color(0.04, 0.10, 0.14, 0.72),
			Color(0.16, 0.34, 0.46, 0.86),
			2,
			8,
			2
		))
		progress_bar.add_theme_stylebox_override("fill", PixelUIStyle.style_box(
			Color(1.0, 0.82, 0.08, 0.96),
			Color(1.0, 0.92, 0.28, 0.92),
			2,
			8,
			0
		))

	_bind_circuit_placeholders()
	_bind_output_placeholders()
	_update_circuit_rows({})
	_update_output_rows({})


func _bind_circuit_placeholders() -> void:
	if circuit_list == null:
		return
	if circuit_row_labels.size() == MAX_CIRCUITS:
		var all_valid := true
		for label in circuit_row_labels:
			if label == null or not is_instance_valid(label):
				all_valid = false
				break
		if all_valid:
			return

	circuit_row_labels.clear()

	for circuit_index in range(MAX_CIRCUITS):
		var label := circuit_list.get_node_or_null("Circuit" + _circuit_suffix(circuit_index) + "Label") as Label
		if label == null:
			label = Label.new()
			label.name = "Circuit" + _circuit_suffix(circuit_index) + "Label"
			label.custom_minimum_size = Vector2(132.0, 20.0)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			circuit_list.add_child(label)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(label, 14)
		circuit_row_labels.append(label)

	if total_circuits_label == null:
		total_circuits_label = circuit_list.get_node_or_null("TotalCircuitsLabel") as Label
	if total_circuits_label != null:
		total_circuits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(total_circuits_label, 14, PixelUIStyle.GOLD_SOFT)


func _update_circuit_rows(data: Dictionary) -> void:
	_bind_circuit_placeholders()
	var circuit_data := _make_circuit_rows(data)
	for circuit_index in range(min(circuit_row_labels.size(), circuit_data.size())):
		var label := circuit_row_labels[circuit_index]
		if label == null or not is_instance_valid(label):
			continue
		var circuit: Dictionary = circuit_data[circuit_index]
		label.text = "%s: %d/%d" % [
			str(circuit.get("label", "Circuit " + _circuit_suffix(circuit_index))),
			int(circuit.get("used", 0)),
			int(circuit.get("capacity", DEFAULT_CIRCUIT_CAPACITY))
		]
	if total_circuits_label != null:
		var total_used := 0
		for circuit in circuit_data:
			if circuit is Dictionary:
				total_used += int(circuit.get("used", 0))
		total_circuits_label.text = "Total: %d/%d" % [clampi(total_used, 0, TOTAL_LINK_CAPACITY), TOTAL_LINK_CAPACITY]


func _bind_output_placeholders() -> void:
	if output_list == null:
		return
	if output_row_labels.size() == MAX_OUTPUT_GROUPS:
		var all_valid := true
		for label in output_row_labels:
			if label == null or not is_instance_valid(label):
				all_valid = false
				break
		if all_valid:
			return

	output_row_labels.clear()

	for output_index in range(MAX_OUTPUT_GROUPS):
		var label := output_list.get_node_or_null("Output" + _circuit_suffix(output_index) + "Label") as Label
		if label == null:
			label = Label.new()
			label.name = "Output" + _circuit_suffix(output_index) + "Label"
			label.custom_minimum_size = Vector2(132.0, 20.0)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			output_list.add_child(label)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(label, 14)
		output_row_labels.append(label)

	if total_outputs_label == null:
		total_outputs_label = output_list.get_node_or_null("TotalOutputsLabel") as Label
	if total_outputs_label != null:
		total_outputs_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(total_outputs_label, 14, PixelUIStyle.GOLD_SOFT)


func _update_output_rows(data: Dictionary) -> void:
	_bind_output_placeholders()
	var output_data := _make_output_rows(data)
	for output_index in range(min(output_row_labels.size(), output_data.size())):
		var label := output_row_labels[output_index]
		if label == null or not is_instance_valid(label):
			continue
		var output: Dictionary = output_data[output_index]
		label.text = "%s: %d/%d" % [
			str(output.get("label", "Output " + _circuit_suffix(output_index))),
			int(output.get("used", 0)),
			int(output.get("capacity", DEFAULT_OUTPUT_CAPACITY))
		]
	if total_outputs_label != null:
		var total_used := 0
		for output in output_data:
			if output is Dictionary:
				total_used += int(output.get("used", 0))
		total_outputs_label.text = "Total: %d/%d" % [clampi(total_used, 0, TOTAL_OUTPUT_CAPACITY), TOTAL_OUTPUT_CAPACITY]


func _make_output_rows(data: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var raw_outputs = data.get("outputs", data.get("output_circuits", []))
	var linked_pole_count := clampi(int(data.get("linked_pole_count", data.get("total_linked_poles", -1))), -1, TOTAL_OUTPUT_CAPACITY)
	for output_index in range(MAX_OUTPUT_GROUPS):
		var used := 0
		var capacity := DEFAULT_OUTPUT_CAPACITY
		var label := "Output " + _circuit_suffix(output_index)

		if raw_outputs is Array and output_index < raw_outputs.size():
			var raw_entry = raw_outputs[output_index]
			if raw_entry is Dictionary:
				used = int(raw_entry.get("used", raw_entry.get("linked", raw_entry.get("count", 0))))
				capacity = int(raw_entry.get("capacity", raw_entry.get("max", DEFAULT_OUTPUT_CAPACITY)))
				label = _normalize_output_label(str(raw_entry.get("label", raw_entry.get("name", label))), output_index)
			elif raw_entry is int or raw_entry is float:
				used = int(raw_entry)
		elif linked_pole_count >= 0:
			used = clampi(linked_pole_count - (output_index * DEFAULT_OUTPUT_CAPACITY), 0, DEFAULT_OUTPUT_CAPACITY)

		capacity = clampi(capacity, 1, DEFAULT_OUTPUT_CAPACITY)
		rows.append({
			"label": label,
			"used": clampi(used, 0, capacity),
			"capacity": capacity
		})
	return rows


func _make_circuit_rows(data: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var raw_circuits = data.get("circuits", data.get("circuit_links", []))
	var linked_pad_count := clampi(int(data.get("linked_pad_count", data.get("total_linked_pads", -1))), -1, TOTAL_LINK_CAPACITY)
	for circuit_index in range(MAX_CIRCUITS):
		var used := 0
		var capacity := DEFAULT_CIRCUIT_CAPACITY
		var label := "Circuit " + _circuit_suffix(circuit_index)

		if raw_circuits is Array and circuit_index < raw_circuits.size():
			var raw_entry = raw_circuits[circuit_index]
			if raw_entry is Dictionary:
				used = int(raw_entry.get("used", raw_entry.get("linked", raw_entry.get("count", 0))))
				capacity = int(raw_entry.get("capacity", raw_entry.get("max", DEFAULT_CIRCUIT_CAPACITY)))
				label = _normalize_circuit_label(str(raw_entry.get("label", raw_entry.get("name", label))), circuit_index)
			elif raw_entry is int or raw_entry is float:
				used = int(raw_entry)
		elif linked_pad_count >= 0:
			used = clampi(linked_pad_count - (circuit_index * DEFAULT_CIRCUIT_CAPACITY), 0, DEFAULT_CIRCUIT_CAPACITY)

		capacity = clampi(capacity, 1, DEFAULT_CIRCUIT_CAPACITY)
		rows.append({
			"label": label,
			"used": clampi(used, 0, capacity),
			"capacity": capacity
		})
	return rows


func _normalize_output_label(raw_label: String, index: int) -> String:
	var clean := raw_label.strip_edges()
	if clean == "":
		return "Output " + _circuit_suffix(index)
	if clean.to_lower().begins_with("output "):
		return clean
	return "Output " + clean


func _normalize_circuit_label(raw_label: String, index: int) -> String:
	var clean := raw_label.strip_edges()
	if clean == "":
		return "Circuit " + _circuit_suffix(index)
	if clean.to_lower().begins_with("circuit "):
		return clean
	return "Circuit " + clean


func _circuit_suffix(index: int) -> String:
	var safe_index: int = max(0, index)
	var suffix: String = ""
	while true:
		var letter_index: int = safe_index % CIRCUIT_LETTERS.length()
		suffix = CIRCUIT_LETTERS.substr(letter_index, 1) + suffix
		safe_index = int(float(safe_index) / float(CIRCUIT_LETTERS.length())) - 1
		if safe_index < 0:
			break
	return suffix


func _fit_window_to_viewport() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var safe_size := Vector2(maxf(1.0, viewport_size.x - 32.0), maxf(1.0, viewport_size.y - 32.0))
	var scale_amount := minf(1.0, minf(safe_size.x / WINDOW_SIZE.x, safe_size.y / WINDOW_SIZE.y))
	panel.pivot_offset = WINDOW_SIZE * 0.5
	panel.scale = Vector2.ONE * clampf(scale_amount, 0.62, 1.0)


func _apply_texture_filter(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_apply_texture_filter(child)


func open_generator(data: Dictionary) -> void:
	current_grid = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	if not scene_ui_ready:
		bind_scene_ui()
	visible = true
	if panel != null:
		panel.modulate = Color.WHITE
	move_to_front()
	update_generator(data)


func update_generator(data: Dictionary) -> void:
	if not scene_ui_ready and not bind_scene_ui():
		return

	var grid_pos := Vector2i(int(data.get("x", current_grid.x)), int(data.get("y", current_grid.y)))
	if visible and grid_pos != current_grid:
		return
	current_grid = grid_pos

	var max_watts := clampi(int(data.get("max_watts", DEFAULT_MAX_WATTS)), 1, DEFAULT_MAX_WATTS)
	var watts := clampi(int(data.get("watts", 0)), 0, max_watts)
	var display_watts := clampf(float(data.get("display_watts", watts)), 0.0, float(max_watts))
	var active_consumption := maxf(0.0, float(data.get("active_consumption_watts_per_hour", 0.0)))
	watts_label.text = _format_watt_value(display_watts) + " / " + str(max_watts) + "W"
	if active_consumption > 0.01:
		watts_label.text += " (-" + _format_watt_value(active_consumption) + " W/h)"
	progress_bar.max_value = max_watts
	progress_bar.value = display_watts

	var status_id := str(data.get("network_status", "idle")).strip_edges().to_lower()
	if status_id == "":
		status_id = "idle"
	var status := _pretty_status(status_id)
	var reason := str(data.get("network_invalid_reason", "")).strip_edges()
	if reason != "":
		status += " - " + _pretty_status(reason)
	if status_label != null:
		status_label.text = status
		_apply_status_color(status_id, reason)

	_update_circuit_rows(data)
	_update_output_rows(data)


func _format_watt_value(value: float) -> String:
	var rounded: float = roundf(value)
	if abs(value - rounded) < 0.05:
		return str(int(rounded))
	return "%0.1f" % value


func _pretty_status(value: String) -> String:
	var clean := str(value).strip_edges().replace("_", " ")
	if clean == "":
		return ""
	clean = clean.replace("generator", "transformer")
	clean = clean.replace("generators", "transformers")
	return clean.capitalize()


func _apply_status_color(status_id: String, reason: String) -> void:
	if status_label == null:
		return

	var color := Color(0.86, 0.96, 1.0, 1.0)
	match status_id:
		"powered", "active", "ready", "valid":
			color = Color(0.48, 1.0, 0.58, 1.0)
		"invalid", "blocked", "missing_generator":
			color = Color(1.0, 0.42, 0.34, 1.0)
		"unpowered", "idle":
			color = Color(1.0, 0.88, 0.25, 1.0)
	if str(reason).strip_edges() != "":
		color = Color(1.0, 0.52, 0.34, 1.0)
	status_label.add_theme_color_override("font_color", color)


func show_generation_pulse(data: Dictionary) -> void:
	update_generator(data)
	if not visible or panel == null:
		return
	var tween := create_tween()
	tween.tween_property(panel, "modulate", Color(1.0, 0.96, 0.55, 1.0), 0.08)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.22)


func close_generator() -> void:
	visible = false
