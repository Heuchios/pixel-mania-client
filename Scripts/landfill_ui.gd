extends Control

# Landfill seasonal event: leaderboard + prize claim panel. Built entirely in code (no .tscn),
# mirroring Scripts/friends_ui.gd's construction pattern exactly (overlay/panel/shadow/back/
# header/rows built via Panel.new()/Label.new()/Button.new()/VBoxContainer.new(), styled via
# PixelUIStyle).
#
# Unlike friends_ui.gd, this panel is opened from the lobby, before any world node exists --
# so it deliberately does NOT use friends_ui.gd's handle_friend_message(data) in-world
# delegation pattern (that pattern silently no-ops outside an active world, per
# is_world_node_active() gating elsewhere in this codebase). Instead this panel connects
# DIRECTLY to NetworkManager's landfill_leaderboard_received / landfill_claim_result_received
# signals in _connect_network_signals(), and calls
# network.request_landfill_leaderboard()/request_landfill_claim_prize() itself -- fully
# self-contained, same as lobby_menu.gd's existing _request_owned_locked_worlds_refresh()
# request/reply pattern.

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const PANEL_W: float = 640.0
const PANEL_H: float = 560.0
const HEADER_H: float = 86.0
const INFO_H: float = 64.0
const ROW_H: float = 60.0

var overlay: ColorRect = null
var panel: Control = null
var rows_root: VBoxContainer = null
var empty_label: Label = null
var season_label: Label = null
var your_rank_label: Label = null
var status_label: Label = null
var claim_button: Button = null
var refresh_button: Button = null

var is_panel_open: bool = false
var entries: Array = []
var season_key: String = ""
var your_kilograms: int = 0
var your_rank: int = 0

var leaderboard_loading: bool = false
var leaderboard_error: String = ""
var leaderboard_request_id: String = ""

var claim_in_progress: bool = false
var claim_request_id: String = ""


func setup(_host = null) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 189
	_connect_network_signals()
	build_panel()
	close_panel()


func _connect_network_signals() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null:
		return

	var leaderboard_callback := Callable(self, "_on_leaderboard_received")
	if network.has_signal("landfill_leaderboard_received") and not network.is_connected("landfill_leaderboard_received", leaderboard_callback):
		network.connect("landfill_leaderboard_received", leaderboard_callback)

	var claim_callback := Callable(self, "_on_claim_result_received")
	if network.has_signal("landfill_claim_result_received") and not network.is_connected("landfill_claim_result_received", claim_callback):
		network.connect("landfill_claim_result_received", claim_callback)


func build_panel() -> void:
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "LandfillOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(overlay)

	panel = Control.new()
	panel.name = "LandfillPanel"
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	overlay.add_child(panel)

	var far_shadow: Panel = Panel.new()
	far_shadow.name = "FarShadow"
	far_shadow.position = Vector2(14, 18)
	far_shadow.size = panel.size
	far_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.0, 0.0, 0.0, 0.30), Color(0.0, 0.0, 0.0, 0.0), 0, 20, 0))
	panel.add_child(far_shadow)

	var back: Panel = Panel.new()
	back.name = "PanelBack"
	back.position = Vector2.ZERO
	back.size = panel.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_PANEL_STRONG, PixelUIStyle.GLASS_BORDER_BRIGHT, 4, 18, 10))
	panel.add_child(back)

	var header: Panel = Panel.new()
	header.name = "Header"
	header.position = Vector2(8, 8)
	header.size = Vector2(PANEL_W - 16.0, HEADER_H - 8.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_HEADER, PixelUIStyle.GLASS_BORDER, 3, 14, 7))
	panel.add_child(header)

	var header_gloss: ColorRect = ColorRect.new()
	header_gloss.name = "HeaderGloss"
	header_gloss.position = Vector2(20, 18)
	header_gloss.size = Vector2(PANEL_W - 40.0, 16.0)
	header_gloss.color = Color(0.80, 0.96, 1.0, 0.08)
	header_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_gloss)

	var top_line: ColorRect = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(12, HEADER_H - 5.0)
	top_line.size = Vector2(PANEL_W - 24.0, 3.0)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "LANDFILL LEADERBOARD"
	title.position = Vector2(36, 14)
	title.size = Vector2(420, 48)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 30)
	panel.add_child(title)

	season_label = Label.new()
	season_label.name = "SeasonLabel"
	season_label.text = "SEASON --"
	season_label.position = Vector2(41, 60)
	season_label.size = Vector2(300, 22)
	season_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	season_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(season_label, 13)
	panel.add_child(season_label)

	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(PANEL_W - 78.0, 18.0)
	close_button.size = Vector2(50, 46)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_landfill_button_style(close_button, "danger", 22)
	close_button.pressed.connect(close_panel)
	panel.add_child(close_button)

	var info_back: Panel = Panel.new()
	info_back.name = "InfoBack"
	info_back.position = Vector2(34, HEADER_H + 12.0)
	info_back.size = Vector2(PANEL_W - 68.0, INFO_H)
	info_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 12, 6))
	panel.add_child(info_back)

	your_rank_label = Label.new()
	your_rank_label.name = "YourRankLabel"
	your_rank_label.text = "Your rank: -- (0 kg)"
	your_rank_label.position = Vector2(50, HEADER_H + 12.0)
	your_rank_label.size = Vector2(PANEL_W - 100.0, INFO_H)
	your_rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	your_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(your_rank_label, 18)
	panel.add_child(your_rank_label)

	var list_top: float = HEADER_H + INFO_H + 24.0
	var list_back: Panel = Panel.new()
	list_back.name = "ListBack"
	list_back.position = Vector2(34, list_top)
	list_back.size = Vector2(PANEL_W - 68.0, PANEL_H - list_top - 84.0)
	list_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(PixelUIStyle.GLASS_SECTION, PixelUIStyle.GLASS_BORDER, 3, 12, 6))
	panel.add_child(list_back)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "LandfillScroll"
	scroll.position = Vector2(48, list_top + 14.0)
	scroll.size = Vector2(PANEL_W - 96.0, PANEL_H - list_top - 112.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)

	rows_root = VBoxContainer.new()
	rows_root.name = "RowsRoot"
	rows_root.size = scroll.size
	rows_root.custom_minimum_size = scroll.size
	rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_root.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_root)

	empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.position = Vector2(58, list_top + 40.0)
	empty_label.size = Vector2(PANEL_W - 116.0, 40)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(empty_label, 17, PixelUIStyle.TEXT_SOFT)
	panel.add_child(empty_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.position = Vector2(34, PANEL_H - 74.0)
	status_label.size = Vector2(PANEL_W - 260.0, 22)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(status_label, 13)
	panel.add_child(status_label)

	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "REFRESH"
	refresh_button.position = Vector2(PANEL_W - 228.0, PANEL_H - 60.0)
	refresh_button.size = Vector2(96, 40)
	refresh_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_landfill_button_style(refresh_button, "blue", 13)
	refresh_button.pressed.connect(_on_refresh_pressed)
	panel.add_child(refresh_button)

	claim_button = Button.new()
	claim_button.name = "ClaimButton"
	claim_button.text = "CLAIM PRIZE"
	claim_button.position = Vector2(PANEL_W - 124.0, PANEL_H - 60.0)
	claim_button.size = Vector2(96, 40)
	claim_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_landfill_button_style(claim_button, "success", 12)
	claim_button.pressed.connect(_on_claim_pressed)
	panel.add_child(claim_button)

	update_position()
	refresh()


func apply_landfill_button_style(button: Button, kind: String = "blue", font_size: int = 13) -> void:
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	match kind:
		"primary":
			PixelUIStyle.apply_yellow_button(button, font_size)
		"danger":
			button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 10, 6))
			button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 10, 7))
			button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 10, 4))
			button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.56), Color(0.10, 0.0, 0.02, 0.62), 3, 10, 2))
		"success":
			button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.08, 0.48, 0.13, 0.98), Color(0.36, 1.0, 0.42, 0.72), 3, 8, 5))
			button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.10, 0.62, 0.18, 0.98), Color(0.58, 1.0, 0.62, 0.86), 3, 8, 6))
			button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.04, 0.30, 0.08, 0.98), Color(0.06, 0.18, 0.06, 1.0), 3, 8, 3))
			button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.04, 0.22, 0.06, 0.62), Color(0.14, 0.36, 0.16, 0.45), 3, 8, 2))
		_:
			PixelUIStyle.apply_blue_button(button, font_size)


func open_panel() -> void:
	if panel == null:
		build_panel()

	is_panel_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = true
	update_position()
	request_leaderboard_refresh()
	if panel != null:
		PixelUIStyle.play_panel_open(panel, Vector2(0.96, 0.96), 0.16)


func close_panel() -> void:
	is_panel_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false


func is_open() -> bool:
	return is_panel_open and visible


func request_leaderboard_refresh() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_leaderboard"):
		leaderboard_loading = false
		leaderboard_error = "Leaderboard is unavailable."
		refresh()
		return

	leaderboard_request_id = "landfill_lb_" + str(Time.get_ticks_msec())
	leaderboard_loading = true
	leaderboard_error = ""
	status_label_set("")
	refresh()

	if not bool(network.request_landfill_leaderboard(leaderboard_request_id)):
		leaderboard_loading = false
		leaderboard_error = "Sign in to view the leaderboard."
		refresh()


func _on_refresh_pressed() -> void:
	request_leaderboard_refresh()


func _on_leaderboard_received(data: Dictionary) -> void:
	if leaderboard_request_id != "":
		var response_request_id: String = str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != leaderboard_request_id:
			return

	leaderboard_loading = false
	leaderboard_error = ""

	var incoming = data.get("entries", [])
	entries.clear()
	if incoming is Array:
		for raw_entry in incoming:
			if raw_entry is Dictionary:
				entries.append(raw_entry.duplicate(true))

	season_key = str(data.get("season_key", season_key)).strip_edges()
	your_kilograms = int(data.get("your_kilograms", your_kilograms))
	your_rank = int(data.get("your_rank", your_rank))

	refresh()


func _on_claim_pressed() -> void:
	if claim_in_progress:
		return

	var network = get_node_or_null("/root/NetworkManager")
	if network == null or not network.has_method("request_landfill_claim_prize"):
		status_label_set("Claiming is unavailable right now.")
		return

	claim_request_id = "landfill_claim_" + str(Time.get_ticks_msec())
	claim_in_progress = true
	status_label_set("Claiming your prize...")
	refresh()

	if not bool(network.request_landfill_claim_prize(claim_request_id)):
		claim_in_progress = false
		status_label_set("Sign in to claim your prize.")
		refresh()


func _on_claim_result_received(data: Dictionary) -> void:
	if claim_request_id != "":
		var response_request_id: String = str(data.get("request_id", "")).strip_edges()
		if response_request_id != "" and response_request_id != claim_request_id:
			return

	claim_in_progress = false

	var ok: bool = bool(data.get("ok", false))
	var message: String = str(data.get("message", "")).strip_edges()
	if ok:
		status_label_set(message if message != "" else "Prize claimed!")
	else:
		if message == "":
			message = "Could not claim your prize."
		status_label_set(message)

	refresh()


func status_label_set(text: String) -> void:
	if status_label != null:
		status_label.text = text


func refresh() -> void:
	if rows_root == null:
		return

	for child in rows_root.get_children():
		child.queue_free()

	if season_label != null:
		season_label.text = "SEASON " + season_key if season_key != "" else "SEASON --"

	if your_rank_label != null:
		if your_rank > 0:
			your_rank_label.text = "Your rank: #" + str(your_rank) + "  (" + str(your_kilograms) + " kg)"
		else:
			your_rank_label.text = "Your rank: unranked  (" + str(your_kilograms) + " kg)"

	var my_username: String = _get_local_username()
	var width: float = float(max(300.0, rows_root.size.x))
	var row_count: int = 0
	for raw_entry in entries:
		if raw_entry is Dictionary:
			rows_root.add_child(make_leaderboard_row(raw_entry, width, my_username))
			row_count += 1

	rows_root.custom_minimum_size = Vector2(width, max(rows_root.size.y, float(row_count) * (ROW_H + 8.0)))

	if empty_label != null:
		empty_label.visible = row_count == 0
		if leaderboard_loading:
			empty_label.text = "Loading leaderboard..."
		elif leaderboard_error != "":
			empty_label.text = leaderboard_error
		else:
			empty_label.text = "No scores recorded yet this season."

	if claim_button != null:
		claim_button.disabled = claim_in_progress or your_rank <= 0 or your_rank > 10


func make_leaderboard_row(entry: Dictionary, width: float, my_username: String) -> Panel:
	var username: String = str(entry.get("username", "Player")).strip_edges()
	var kilograms: int = int(entry.get("kilograms", 0))
	var rank: int = int(entry.get("rank", 0))
	var is_me: bool = my_username != "" and username.to_upper() == my_username.to_upper()
	var accent: Color = PixelUIStyle.GOLD_SOFT if is_me else Color(0.30, 0.62, 1.0, 1.0)

	var row: Panel = make_base_row(width, accent)

	var rank_label: Label = Label.new()
	rank_label.name = "Rank"
	rank_label.text = "#" + str(rank)
	rank_label.position = Vector2(14, 10)
	rank_label.size = Vector2(56, ROW_H - 20.0)
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(rank_label, 20)
	row.add_child(rank_label)

	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.text = username
	name_label.position = Vector2(78, 10)
	name_label.size = Vector2(max(150.0, width - 260.0), ROW_H - 20.0)
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 18)
	row.add_child(name_label)

	var kg_label: Label = Label.new()
	kg_label.name = "Kilograms"
	kg_label.text = str(kilograms) + " kg"
	kg_label.position = Vector2(width - 156.0, 10)
	kg_label.size = Vector2(140, ROW_H - 20.0)
	kg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kg_label.clip_text = true
	kg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(kg_label, 15)
	row.add_child(kg_label)

	return row


func make_base_row(width: float, accent: Color) -> Panel:
	var row: Panel = Panel.new()
	row.name = "LeaderboardRow"
	row.custom_minimum_size = Vector2(width, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(Color(0.14, 0.27, 0.38, 0.48), Color(accent, 0.58), 2, 9, 4))

	var gloss: ColorRect = ColorRect.new()
	gloss.name = "Gloss"
	gloss.position = Vector2(12, 6)
	gloss.size = Vector2(max(1.0, width - 24.0), 2)
	gloss.color = Color(1.0, 1.0, 1.0, 0.12)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gloss)

	return row


func _get_local_username() -> String:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("get_active_session_username"):
		return str(network.get_active_session_username()).strip_edges()
	return ""


func update_position() -> void:
	if panel == null:
		return
	var screen_size: Vector2 = get_viewport_rect().size
	var panel_scale: float = min(1.0, min((screen_size.x - 32.0) / PANEL_W, (screen_size.y - 32.0) / PANEL_H))
	panel.scale = Vector2(panel_scale, panel_scale)
	panel.position = (screen_size - panel.size * panel_scale) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		update_position()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		close_panel()
		get_viewport().set_input_as_handled()


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
