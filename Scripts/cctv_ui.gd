extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const MAX_CCTV_EVENTS := 20

var world = null
var overlay: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var status_label: Label = null
var entries_scroll: ScrollContainer = null
var entries_root: VBoxContainer = null
var close_button: Button = null

var current_grid := Vector2i.ZERO
var cctv_open := false


func setup(parent_world, _ui_node = null):
	world = parent_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 147
	build_ui()
	close_cctv()


func _process(_delta):
	if cctv_open:
		update_position()


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("pixelmania_font_role", "preserve")
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func build_ui():
	for child in get_children():
		child.queue_free()
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.01, 0.03, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	panel = Panel.new()
	panel.size = Vector2(760, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	add_child(panel)
	var header := Panel.new()
	header.position = Vector2(20, 20)
	header.size = Vector2(720, 84)
	header.add_theme_stylebox_override("panel", PixelUIStyle.header_style())
	panel.add_child(header)
	title_label = _label("CCTV ACTIVITY", 28)
	title_label.position = Vector2(38, 28)
	title_label.size = Vector2(550, 36)
	panel.add_child(title_label)
	status_label = _label("", 16, Color(0.78, 0.72, 0.85))
	status_label.position = Vector2(40, 69)
	status_label.size = Vector2(580, 24)
	panel.add_child(status_label)
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(674, 36)
	close_button.size = Vector2(48, 48)
	PixelUIStyle.apply_atlas_button(close_button, "red_button")
	close_button.pressed.connect(close_cctv)
	panel.add_child(close_button)
	var list_back := Panel.new()
	list_back.position = Vector2(20, 120)
	list_back.size = Vector2(720, 390)
	list_back.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(list_back)
	for column in [["TIME", 36, 216], ["PLAYER", 258, 300], ["ACTIVITY", 590, 120]]:
		var caption := _label(column[0], 15, Color(0.76, 0.69, 0.83))
		caption.position = Vector2(column[1], 130)
		caption.size = Vector2(column[2], 28)
		panel.add_child(caption)
	entries_scroll = ScrollContainer.new()
	entries_scroll.position = Vector2(32, 170)
	entries_scroll.size = Vector2(696, 328)
	entries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entries_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(entries_scroll)
	entries_root = VBoxContainer.new()
	entries_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	entries_root.add_theme_constant_override("separation", 6)
	entries_scroll.add_child(entries_root)
	var hint := _label("Latest activity first  •  Owner and admin access", 14, Color(0.19, 0.09, 0.24))
	hint.add_theme_constant_override("shadow_offset_x", 0)
	hint.add_theme_constant_override("shadow_offset_y", 0)
	hint.position = Vector2(32, 520)
	hint.size = Vector2(696, 24)
	panel.add_child(hint)


func update_position():
	if panel == null:
		return
	var screen_size := get_viewport_rect().size
	var fit := minf(1.0, minf((screen_size.x - 32) / 760.0, (screen_size.y - 32) / 560.0))
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	panel.position = (screen_size - panel.size * panel.scale) * 0.5


func open_cctv(grid_pos: Vector2i):
	if world != null and world.has_method("can_current_player_view_cctv") and not bool(world.can_current_player_view_cctv()):
		if world.has_method("show_notification"):
			world.show_notification("Only the world owner or world admins can view CCTV.")
		return

	current_grid = grid_pos
	cctv_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay != null:
		overlay.visible = true
	if panel != null:
		panel.visible = true
	update_position()
	refresh()


func close_cctv():
	cctv_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false
	if panel != null:
		panel.visible = false


func is_cctv_open() -> bool:
	return cctv_open and visible


func get_current_state() -> Dictionary:
	if world == null or not ("cctv_state" in world):
		return {}
	var state_value: Variant = world.cctv_state
	if state_value is Dictionary:
		return state_value
	return {}


func get_entries() -> Array:
	var state := get_current_state()
	var entries_value: Variant = state.get("entries", [])
	if entries_value is Array:
		return entries_value
	return []


func refresh():
	if entries_root == null:
		return
	for child in entries_root.get_children():
		entries_root.remove_child(child)
		child.queue_free()

	var state := get_current_state()
	var can_view := bool(state.get("can_view", false))
	var entry_count := int(state.get("entry_count", 0))
	var entries := get_entries()
	entry_count = max(entry_count, entries.size())
	if status_label != null:
		status_label.text = str(min(entry_count, MAX_CCTV_EVENTS)) + "/" + str(MAX_CCTV_EVENTS) + " recent events"

	if not can_view:
		add_empty_row("Access denied.")
		return

	if entries.is_empty():
		add_empty_row("No activity recorded yet.")
		return

	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var player_name := str(entry.get("player_name", entry.get("display_name", "Player"))).strip_edges()
		if player_name == "":
			player_name = "Player"
		var event_type := str(entry.get("event_type", entry.get("event", "enter"))).strip_edges().to_lower()
		var leaving := event_type == "leave"
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.24, 0.13, 0.29) if entries_root.get_child_count() % 2 == 0 else Color(0.20, 0.10, 0.25)
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row.add_theme_stylebox_override("panel", row_style)
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 12)
		row.add_child(columns)
		var timestamp := _label(format_timestamp(entry.get("at", "")), 14, Color(0.76, 0.72, 0.82))
		timestamp.custom_minimum_size.x = 210
		timestamp.clip_text = true
		timestamp.tooltip_text = str(entry.get("at", ""))
		columns.add_child(timestamp)
		var player_label := _label(player_name, 18)
		player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_label.clip_text = true
		player_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		player_label.tooltip_text = player_name
		columns.add_child(player_label)
		var action := _label("EXITED" if leaving else "ENTERED", 15, Color(1.0, 0.69, 0.52) if leaving else Color(0.52, 0.94, 0.65))
		action.custom_minimum_size.x = 120
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.add_child(action)
		entries_root.add_child(row)

	if entries_scroll != null:
		entries_scroll.scroll_vertical = 0


func add_empty_row(text: String):
	var row := _label(text, 18)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entries_root != null:
		row.custom_minimum_size = Vector2(0, 260)
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	entries_root.add_child(row)


func format_timestamp(value) -> String:
	var text := str(value).strip_edges()
	if text == "":
		return "unknown date"
	if text.length() >= 16 and text.find("T") >= 0:
		return text.substr(0, 10) + " " + text.substr(11, 5)
	return text


func handle_cctv_state(_data: Dictionary):
	if is_cctv_open():
		refresh()
