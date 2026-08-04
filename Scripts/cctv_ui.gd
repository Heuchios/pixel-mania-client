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


func build_ui():
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	panel = Panel.new()
	panel.size = Vector2(560, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		4, 8, 14
	))
	add_child(panel)

	title_label = Label.new()
	title_label.text = "CCTV"
	title_label.position = Vector2(24, 12)
	title_label.size = Vector2(360, 44)
	PixelUIStyle.apply_label_shadow(title_label, 34)
	panel.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(panel.size.x - 62, 14)
	close_button.size = Vector2(42, 38)
	PixelUIStyle.apply_blue_button(close_button, 18)
	close_button.pressed.connect(close_cctv)
	panel.add_child(close_button)

	status_label = Label.new()
	status_label.position = Vector2(28, 58)
	status_label.size = Vector2(panel.size.x - 56, 26)
	PixelUIStyle.apply_small_label(status_label, 15)
	panel.add_child(status_label)

	entries_scroll = ScrollContainer.new()
	entries_scroll.position = Vector2(24, 92)
	entries_scroll.size = Vector2(panel.size.x - 48, panel.size.y - 120)
	entries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entries_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	entries_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(entries_scroll)

	entries_root = VBoxContainer.new()
	entries_root.custom_minimum_size = Vector2(entries_scroll.size.x - 18, 0)
	entries_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	entries_root.add_theme_constant_override("separation", 8)
	entries_scroll.add_child(entries_root)


func update_position():
	if panel == null:
		return
	var screen_size := get_viewport_rect().size
	panel.position = Vector2(
		floor((screen_size.x - panel.size.x) * 0.5),
		floor(max(28.0, (screen_size.y - panel.size.y) * 0.5))
	)


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
		var row := Label.new()
		var player_name := str(entry.get("player_name", entry.get("display_name", "Player"))).strip_edges()
		if player_name == "":
			player_name = "Player"
		var event_type := str(entry.get("event_type", entry.get("event", "enter"))).strip_edges().to_lower()
		var action_text := "exited" if event_type == "leave" else "entered"
		var time_text := format_timestamp(entry.get("at", ""))
		row.text = time_text + " - " + player_name + " " + action_text
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(entries_root.custom_minimum_size.x, 0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		PixelUIStyle.apply_small_label(row, 17)
		entries_root.add_child(row)

	if entries_scroll != null:
		entries_scroll.scroll_vertical = 0


func add_empty_row(text: String):
	var row := Label.new()
	row.text = text
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entries_root != null:
		row.custom_minimum_size = Vector2(entries_root.custom_minimum_size.x, 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	PixelUIStyle.apply_small_label(row, 17)
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
