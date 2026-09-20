extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const PANEL_W: float = 820.0
const PANEL_H: float = 600.0
const HEADER_H: float = 86.0
const TAB_H: float = 38.0
const ROW_H: float = 88.0

var world = null
var overlay: ColorRect = null
var panel: Control = null
var rows_root: VBoxContainer = null
var empty_label: Label = null
var friends_tab_button: Button = null
var pending_tab_button: Button = null
var search_input: LineEdit
var summary_label: Label
var list_scroll: ScrollContainer
var current_tab: String = "friends"
var friends: Array = []
var pending_incoming: Array = []
var pending_outgoing: Array = []
var is_panel_open: bool = false


func setup(world_ref, _ui_layer = null) -> void:
	world = world_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 188
	build_panel()
	close_panel()


func build_panel() -> void:
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "FriendsOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(overlay)

	panel = Control.new()
	panel.name = "FriendsPanel"
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_gui_input)
	overlay.add_child(panel)

	var back: Panel = Panel.new()
	back.name = "PanelBack"
	back.position = Vector2.ZERO
	back.size = panel.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	panel.add_child(back)

	var header: Panel = Panel.new()
	header.name = "Header"
	header.position = Vector2(16, 16)
	header.size = Vector2(PANEL_W - 32.0, HEADER_H - 16.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(header)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "FRIENDS"
	title.position = Vector2(32, 20)
	title.size = Vector2(300, 48)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 30)
	_preserve(title, 30)
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "SOCIAL"
	subtitle.position = Vector2(34, 59)
	subtitle.size = Vector2(550, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 13)
	_preserve(subtitle, 13)
	panel.add_child(subtitle)
	summary_label = subtitle

	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(PANEL_W - 78.0, 27.0)
	close_button.size = Vector2(50, 46)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_panel)
	panel.add_child(close_button)

	friends_tab_button = make_tab_button("FRIENDS", Vector2(24, 102))
	friends_tab_button.pressed.connect(_on_friends_tab_pressed)
	panel.add_child(friends_tab_button)

	pending_tab_button = make_tab_button("PENDING", Vector2(218, 102))
	pending_tab_button.pressed.connect(_on_pending_tab_pressed)
	panel.add_child(pending_tab_button)

	search_input = LineEdit.new()
	search_input.name = "SearchFriends"
	search_input.placeholder_text = "Search name or world..."
	search_input.position = Vector2(420, 102)
	search_input.size = Vector2(376, 38)
	PixelUIStyle.apply_input(search_input, 15)
	_preserve(search_input, 15)
	search_input.text_changed.connect(func(_text):
		list_scroll.scroll_vertical = 0
		refresh())
	panel.add_child(search_input)
	var list_back: Panel = Panel.new()
	list_back.name = "ListBack"
	list_back.position = Vector2(16, 154)
	list_back.size = Vector2(PANEL_W - 32.0, PANEL_H - 206.0)
	list_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_back.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(list_back)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "FriendsScroll"
	scroll.position = Vector2(26, 164)
	scroll.size = Vector2(PANEL_W - 52.0, PANEL_H - 226.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)
	list_scroll = scroll

	rows_root = VBoxContainer.new()
	rows_root.name = "RowsRoot"
	rows_root.size = Vector2(PANEL_W - 76.0, 0)
	rows_root.custom_minimum_size = Vector2(PANEL_W - 76.0, 0)
	rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_root.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_root)

	empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.position = Vector2(58, 290)
	empty_label.size = Vector2(PANEL_W - 116.0, 80)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(empty_label, 17, PixelUIStyle.TEXT_SOFT)
	_preserve(empty_label, 17)
	panel.add_child(empty_label)

	var hint := Label.new()
	hint.text = "Add friends from their player profile."
	hint.position = Vector2(28, PANEL_H - 42)
	hint.size = Vector2(PANEL_W - 56, 28)
	PixelUIStyle.apply_small_label(hint, 14)
	_preserve(hint, 14)
	_preserve(hint, 14)
	panel.add_child(hint)
	update_position()
	refresh()


func _preserve(control: Control, font_size: int) -> void:
	control.set_meta("pixelmania_font_role", "preserve")
	control.add_theme_font_size_override("font_size", font_size)


func make_tab_button(button_text: String, button_position: Vector2) -> Button:
	var button: Button = Button.new()
	button.name = "Tab_" + button_text
	button.text = button_text
	button.position = button_position
	button.size = Vector2(182, TAB_H)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_friend_button_style(button, "blue", 13)
	return button


func make_row_button(button_text: String, button_position: Vector2, kind: String = "blue", button_size: Vector2 = Vector2(96, 32)) -> Button:
	var button: Button = Button.new()
	button.name = "Button_" + button_text
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_friend_button_style(button, kind, 12)
	return button


func apply_friend_button_style(button: Button, kind: String = "blue", font_size: int = 13) -> void:
	if button == null:
		return

	match kind:
		"primary", "success": PixelUIStyle.apply_green_button(button, font_size)
		"danger": PixelUIStyle.apply_atlas_button(button, "red_button")
		_: PixelUIStyle.apply_yellow_button(button, font_size)
	_preserve(button, font_size)



func open_panel() -> void:
	if panel == null:
		build_panel()

	is_panel_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = true
	update_position()
	refresh()
	request_friend_state()


func close_panel() -> void:
	is_panel_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null:
		overlay.visible = false


func is_open() -> bool:
	return is_panel_open and visible


func request_friend_state() -> void:
	var network = get_node_or_null("/root/NetworkManager")
	if network != null and network.has_method("send_friend_list_request"):
		network.send_friend_list_request()


func handle_friend_message(data: Dictionary) -> void:
	var message_type: String = str(data.get("type", "")).strip_edges().to_lower()
	if message_type == "friend_state":
		apply_friend_state(data)
	elif data.has("friends") or data.has("pending_incoming") or data.has("pending_outgoing"):
		apply_friend_state(data)


func apply_friend_state(data: Dictionary) -> void:
	var raw_friends: Variant = data.get("friends", friends)
	if raw_friends is Array:
		friends = raw_friends.duplicate(true)

	var raw_incoming: Variant = data.get("pending_incoming", pending_incoming)
	if raw_incoming is Array:
		pending_incoming = raw_incoming.duplicate(true)

	var raw_outgoing: Variant = data.get("pending_outgoing", pending_outgoing)
	if raw_outgoing is Array:
		pending_outgoing = raw_outgoing.duplicate(true)

	refresh()


func get_friend_status_for_username(username: String) -> String:
	var clean_username: String = username.strip_edges()
	if clean_username == "":
		return "none"
	if has_username_in_entries(friends, clean_username):
		return "friends"
	if has_username_in_entries(pending_incoming, clean_username):
		return "incoming"
	if has_username_in_entries(pending_outgoing, clean_username):
		return "outgoing"
	return "none"


func has_username_in_entries(entries: Array, username: String) -> bool:
	var key: String = username.strip_edges().to_lower()
	if key == "":
		return false
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var entry_username: String = str(entry.get("username", entry.get("name", ""))).strip_edges().to_lower()
			if entry_username == key:
				return true
		else:
			var entry_text: String = str(raw_entry).strip_edges().to_lower()
			if entry_text == key:
				return true
	return false


func refresh() -> void:
	if rows_root == null:
		return

	for child in rows_root.get_children():
		rows_root.remove_child(child)
		child.queue_free()

	var pending_count: int = pending_incoming.size() + pending_outgoing.size()
	if friends_tab_button != null:
		friends_tab_button.text = "FRIENDS " + str(friends.size())
		apply_friend_button_style(friends_tab_button, "primary" if current_tab == "friends" else "blue", 13)
	if pending_tab_button != null:
		pending_tab_button.text = "PENDING " + str(pending_count)
		apply_friend_button_style(pending_tab_button, "primary" if current_tab == "pending" else "blue", 13)

	var online_count := 0
	for entry in friends:
		if entry is Dictionary and bool(entry.get("online", false)):
			online_count += 1
	summary_label.text = "%d online  /  %d friends" % [online_count, friends.size()]
	var width: float = PANEL_W - 76.0
	var row_count: int = 0
	if current_tab == "friends":
		var sorted_friends := friends.duplicate()
		sorted_friends.sort_custom(func(a, b):
			if not a is Dictionary or not b is Dictionary: return false
			if bool(a.get("online", false)) != bool(b.get("online", false)): return bool(a.get("online", false))
			return str(a.get("username", a.get("name", ""))).naturalnocasecmp_to(str(b.get("username", b.get("name", "")))) < 0)
		for raw_friend in sorted_friends:
			if raw_friend is Dictionary and _matches_search(raw_friend):
				rows_root.add_child(make_friend_row(raw_friend, width))
				row_count += 1
	else:
		for raw_incoming in pending_incoming:
			if raw_incoming is Dictionary and _matches_search(raw_incoming):
				rows_root.add_child(make_pending_row(raw_incoming, width, true))
				row_count += 1
		for raw_outgoing in pending_outgoing:
			if raw_outgoing is Dictionary and _matches_search(raw_outgoing):
				rows_root.add_child(make_pending_row(raw_outgoing, width, false))
				row_count += 1

	rows_root.custom_minimum_size = Vector2(width, max(0.0, float(row_count) * (ROW_H + 8.0) - 8.0))
	if empty_label != null:
		empty_label.visible = row_count == 0
		empty_label.text = "No matching players." if not search_input.text.strip_edges().is_empty() else ("No friends yet.\nMeet players and add them from their profile." if current_tab == "friends" else "No pending requests.\nNew invitations will appear here.")


func _matches_search(entry: Dictionary) -> bool:
	var query := search_input.text.strip_edges().to_lower()
	return query.is_empty() or (str(entry.get("username", entry.get("name", ""))) + " " + str(entry.get("world", entry.get("current_world", "")))).to_lower().contains(query)


func make_friend_row(entry: Dictionary, width: float) -> Panel:
	var username: String = str(entry.get("username", entry.get("name", "Player"))).strip_edges()
	var is_online: bool = bool(entry.get("online", false))
	var world_name: String = str(entry.get("world", entry.get("current_world", ""))).strip_edges()
	var row: Panel = make_base_row(width, Color(0.30, 0.62, 1.0, 1.0))
	add_avatar(row, username, is_online)
	add_row_text(row, username, "ONLINE IN " + world_name if is_online and world_name != "" else ("ONLINE" if is_online else "OFFLINE"))

	var warp_button: Button = make_row_button("WARP", Vector2(width - 126.0, 24.0), "primary", Vector2(104, 40))
	warp_button.disabled = not is_online or world_name == ""
	warp_button.tooltip_text = "Join " + world_name if not warp_button.disabled else ("This friend is offline." if not is_online else "This friend is not in a world.")
	row.get_node("Status").add_theme_color_override("font_color", PixelUIStyle.OK_GREEN if is_online else PixelUIStyle.TEXT_SOFT)
	warp_button.pressed.connect(_on_warp_pressed.bind(username, world_name))
	row.add_child(warp_button)
	return row


func make_pending_row(entry: Dictionary, width: float, incoming: bool) -> Panel:
	var username: String = str(entry.get("username", entry.get("name", "Player"))).strip_edges()
	var is_online: bool = bool(entry.get("online", false))
	var row: Panel = make_base_row(width, Color(1.0, 0.76, 0.18, 1.0))
	add_avatar(row, username, is_online)
	add_row_text(row, username, "WANTS TO BE FRIENDS" if incoming else "REQUEST SENT")

	if incoming:
		var accept_button: Button = make_row_button("ACCEPT", Vector2(width - 214.0, 24.0), "success", Vector2(92, 40))
		accept_button.pressed.connect(_on_accept_pressed.bind(username))
		row.add_child(accept_button)

		var decline_button: Button = make_row_button("DECLINE", Vector2(width - 112.0, 24.0), "danger", Vector2(92, 40))
		decline_button.pressed.connect(_on_decline_pressed.bind(username))
		row.add_child(decline_button)
	else:
		var pending_button: Button = make_row_button("PENDING", Vector2(width - 126.0, 24.0), "blue", Vector2(104, 40))
		pending_button.disabled = true
		row.add_child(pending_button)

	return row


func make_base_row(width: float, _accent: Color) -> Panel:
	var row: Panel = Panel.new()
	row.name = "FriendRow"
	row.custom_minimum_size = Vector2(width, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	var inner := Panel.new()
	inner.position = Vector2(4,4)
	inner.size = Vector2(width - 8, ROW_H - 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	row.add_child(inner)

	return row


func add_avatar(row: Panel, username: String, is_online: bool) -> void:
	var avatar: Panel = Panel.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(16, 16)
	avatar.size = Vector2(56, 56)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent: Color = Color(0.32, 1.0, 0.42, 1.0) if is_online else Color(0.75, 0.86, 1.0, 1.0)
	avatar.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	row.add_child(avatar)
	avatar.self_modulate = Color.WHITE.lerp(accent, 0.3)

	var initial: Label = Label.new()
	initial.name = "Initial"
	initial.text = username.substr(0, 1).to_upper() if username != "" else "?"
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(initial, 24)
	_preserve(initial, 24)
	avatar.add_child(initial)
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial.add_theme_color_override("font_color", Color("301b3a"))


func add_row_text(row: Panel, username: String, status_text: String) -> void:
	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.text = username
	name_label.position = Vector2(88, 18)
	name_label.size = Vector2(max(150.0, row.custom_minimum_size.x - 320.0), 24)
	name_label.clip_text = true
	name_label.tooltip_text = username
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 20)
	_preserve(name_label, 20)
	row.add_child(name_label)

	var status_label: Label = Label.new()
	status_label.name = "Status"
	status_label.text = status_text
	status_label.position = Vector2(88, 50)
	status_label.size = Vector2(max(150.0, row.custom_minimum_size.x - 320.0), 20)
	status_label.clip_text = true
	status_label.tooltip_text = status_text
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(status_label, 12)
	_preserve(status_label, 12)
	row.add_child(status_label)


func _on_friends_tab_pressed() -> void:
	current_tab = "friends"
	list_scroll.scroll_vertical = 0
	refresh()


func _on_pending_tab_pressed() -> void:
	current_tab = "pending"
	list_scroll.scroll_vertical = 0
	refresh()


func _on_accept_pressed(username: String) -> void:
	if world != null and world.has_method("accept_friend_request_from"):
		world.accept_friend_request_from(username)


func _on_decline_pressed(username: String) -> void:
	if world != null and world.has_method("decline_friend_request_from"):
		world.decline_friend_request_from(username)


func _on_warp_pressed(username: String, world_name: String) -> void:
	var clean_world: String = world_name.strip_edges()
	if clean_world == "":
		return
	close_panel()
	if world != null and world.has_method("enter_world_by_name"):
		world.enter_world_by_name(clean_world)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Warping to " + username + ".")


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
