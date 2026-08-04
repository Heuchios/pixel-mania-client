extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const MESSAGE_LIFETIME := 2.7
const MAX_MESSAGES := 2
const HISTORY_LIMIT := 30
const TOAST_WIDTH := 410.0
const TOAST_HEIGHT := 78.0
const TOAST_GAP := 9
const TOAST_PROGRESS_INSET := 18.0
const BOTTOM_SAFE_MARGIN := 124.0
const DUPLICATE_WINDOW := 1.8
const TOAST_COOLDOWN := 0.42
const LEVEL_UP_WIDTH := 640.0
const LEVEL_UP_HEIGHT := 236.0
const LEVEL_UP_LIFETIME := 3.2
const LEVEL_UP_SPARK_COUNT := 22
const PANEL_HEADER_HEIGHT := 78.0
const PANEL_BUTTON_Y := 304.0
const NOTIFICATION_ICON_PATH := "res://Assets/ui/icons/notification.png"
const NOTIFICATION_BUTTON_SIZE := Vector2(64, 64)

var message_container: VBoxContainer = null
var messages: Array = []
var notification_button: Button = null
var notification_button_icon: TextureRect = null
var notification_button_icon_shadow: TextureRect = null
var notification_button_tween = null
var notification_button_hovered := false
var unread_badge: PanelContainer = null
var unread_badge_label: Label = null
var notification_panel: Control = null
var history_scroll: ScrollContainer = null
var history_root: VBoxContainer = null
var history_count_label: Label = null
var notification_history: Array = []
var unread_count := 0
var notification_elapsed := 0.0
var last_toast_at := -999.0
var panel_layout_size := Vector2.ZERO
var level_up_overlay: Control = null
var level_up_tween = null
var world = null


func _ready() -> void:
	setup()


func set_world(world_ref) -> void:
	world = world_ref


func get_hud_layer() -> Node:
	if world != null and world.has_method("get_ui_hud_layer"):
		var hud_layer = world.get_ui_hud_layer()
		if hud_layer != null:
			return hud_layer

	return self


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 170

	if message_container == null:
		message_container = VBoxContainer.new()
		message_container.name = "MessageContainer"
		message_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		message_container.add_theme_constant_override("separation", TOAST_GAP)
		message_container.z_index = 171
		add_child(message_container)

	setup_notification_button()
	setup_notification_panel()
	update_position()


func _process(delta: float) -> void:
	notification_elapsed += delta
	update_messages(delta)
	update_position()
	update_level_up_overlay_position()
	update_notification_button_position()
	update_notification_panel_position()
	refresh_notification_panel_for_viewport()


func update_position() -> void:
	if message_container == null:
		return

	var toasts_visible: bool = not is_floating_hud_blocked()
	message_container.visible = toasts_visible
	if not toasts_visible:
		return

	var screen_size: Vector2 = get_viewport_rect().size
	var valid_count := 0
	for data in messages:
		var node = data.get("node", null)
		if is_instance_valid(node):
			valid_count += 1

	var total_height: float = float(max(TOAST_HEIGHT, valid_count * TOAST_HEIGHT + max(0, valid_count - 1) * TOAST_GAP))
	message_container.size = Vector2(TOAST_WIDTH, total_height)
	message_container.position = Vector2(
		24.0,
		clamp(screen_size.y - total_height - BOTTOM_SAFE_MARGIN, 92.0, screen_size.y - BOTTOM_SAFE_MARGIN)
	)


func setup_notification_button() -> void:
	var hud_layer = get_hud_layer()
	notification_button = null
	if hud_layer != null:
		notification_button = hud_layer.get_node_or_null("NotificationButton")
	if notification_button == null and hud_layer != self:
		notification_button = get_node_or_null("NotificationButton")
	if notification_button == null:
		notification_button = Button.new()
		notification_button.name = "NotificationButton"
		if hud_layer != null:
			hud_layer.add_child(notification_button)
		else:
			add_child(notification_button)
	elif hud_layer != null and notification_button.get_parent() != hud_layer:
		var old_parent = notification_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(notification_button)
		hud_layer.add_child(notification_button)

	notification_button.text = ""
	notification_button.size = NOTIFICATION_BUTTON_SIZE
	notification_button.z_index = 185
	notification_button.mouse_filter = Control.MOUSE_FILTER_STOP
	notification_button.focus_mode = Control.FOCUS_NONE
	apply_notification_icon_button_style(notification_button)

	for child in notification_button.get_children():
		child.queue_free()

	setup_notification_button_icon()

	unread_badge = PanelContainer.new()
	unread_badge.name = "UnreadBadge"
	unread_badge.position = Vector2(42, 6)
	unread_badge.size = Vector2(36, 22)
	unread_badge.custom_minimum_size = Vector2(36, 22)
	if notification_button.size.x > 72.0:
		unread_badge.position = Vector2(72, -7)
		unread_badge.size = Vector2(42, 24)
		unread_badge.custom_minimum_size = Vector2(42, 24)
	unread_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unread_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.95, 0.68, 0.08, 0.98),
		Color(1.0, 0.90, 0.22, 0.95),
		2,
		8,
		3
	))
	notification_button.add_child(unread_badge)

	unread_badge_label = Label.new()
	unread_badge_label.name = "Label"
	unread_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unread_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unread_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(unread_badge_label, 12, Color.WHITE)
	unread_badge.add_child(unread_badge_label)

	if not notification_button.pressed.is_connected(toggle_notification_panel):
		notification_button.pressed.connect(toggle_notification_panel)
	if not notification_button.mouse_entered.is_connected(_on_notification_button_mouse_entered):
		notification_button.mouse_entered.connect(_on_notification_button_mouse_entered)
	if not notification_button.mouse_exited.is_connected(_on_notification_button_mouse_exited):
		notification_button.mouse_exited.connect(_on_notification_button_mouse_exited)
	if not notification_button.button_down.is_connected(_on_notification_button_down):
		notification_button.button_down.connect(_on_notification_button_down)
	if not notification_button.button_up.is_connected(_on_notification_button_up):
		notification_button.button_up.connect(_on_notification_button_up)

	update_notification_button_position()
	update_unread_badge()


func setup_notification_button_icon() -> void:
	if notification_button == null:
		return

	notification_button_icon = null
	notification_button_icon_shadow = null
	if notification_button_tween != null:
		notification_button_tween.kill()
		notification_button_tween = null

	if not ResourceLoader.exists(NOTIFICATION_ICON_PATH):
		notification_button.text = "NOTIFY"
		notification_button.size = Vector2(108, 42)
		apply_notification_arcade_button_style(notification_button, false, false, 15)
		return

	var icon_texture: Texture2D = load(NOTIFICATION_ICON_PATH) as Texture2D
	if icon_texture == null:
		notification_button.text = "NOTIFY"
		notification_button.size = Vector2(108, 42)
		apply_notification_arcade_button_style(notification_button, false, false, 15)
		return

	var icon_shadow := TextureRect.new()
	icon_shadow.name = "NotificationIconShadow"
	icon_shadow.texture = icon_texture
	icon_shadow.position = Vector2(5, 7)
	icon_shadow.size = NOTIFICATION_BUTTON_SIZE
	icon_shadow.pivot_offset = NOTIFICATION_BUTTON_SIZE * 0.5
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	notification_button.add_child(icon_shadow)
	notification_button_icon_shadow = icon_shadow

	var icon := TextureRect.new()
	icon.name = "NotificationIcon"
	icon.texture = icon_texture
	icon.position = Vector2.ZERO
	icon.size = NOTIFICATION_BUTTON_SIZE
	icon.pivot_offset = NOTIFICATION_BUTTON_SIZE * 0.5
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	notification_button.add_child(icon)
	notification_button_icon = icon


func update_notification_button_position() -> void:
	if notification_button == null:
		return

	var button_visible: bool = not is_floating_hud_blocked()
	notification_button.visible = button_visible
	if not button_visible:
		return

	var screen_size: Vector2 = get_viewport_rect().size
	var button_y: float = PANEL_BUTTON_Y
	if screen_size.y < PANEL_BUTTON_Y + notification_button.size.y + 14.0:
		button_y = max(108.0, screen_size.y - notification_button.size.y - 14.0)
	var button_x: float = screen_size.x - 124.0
	if notification_button.size.x <= 72.0:
		button_x = screen_size.x - 102.0
	notification_button.position = Vector2(max(8.0, button_x), button_y)


func is_floating_hud_blocked() -> bool:
	return false


func apply_notification_icon_button_style(button: Button) -> void:
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_notification_button_mouse_entered() -> void:
	notification_button_hovered = true
	animate_notification_button_icon(false)


func _on_notification_button_mouse_exited() -> void:
	notification_button_hovered = false
	animate_notification_button_icon(false)


func _on_notification_button_down() -> void:
	animate_notification_button_icon(true)


func _on_notification_button_up() -> void:
	animate_notification_button_icon(false)


func animate_notification_button_icon(pressed: bool) -> void:
	if notification_button_icon == null or notification_button_icon_shadow == null:
		return

	if notification_button_tween != null:
		notification_button_tween.kill()

	var icon_position := Vector2.ZERO
	var shadow_position := Vector2(5, 7)
	var icon_scale := Vector2.ONE
	var shadow_alpha := 0.38
	var icon_alpha := 0.96

	if notification_button_hovered:
		icon_position = Vector2(-2, -3)
		shadow_position = Vector2(7, 10)
		icon_scale = Vector2(1.06, 1.06)
		shadow_alpha = 0.48
		icon_alpha = 1.0

	if pressed:
		icon_position = Vector2(1, 2)
		shadow_position = Vector2(3, 4)
		icon_scale = Vector2(0.96, 0.96)
		shadow_alpha = 0.28

	notification_button_tween = create_tween()
	notification_button_tween.set_parallel(true)
	notification_button_tween.tween_property(notification_button_icon, "position", icon_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	notification_button_tween.tween_property(notification_button_icon, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	notification_button_tween.tween_property(notification_button_icon, "modulate", Color(1.0, 1.0, 1.0, icon_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	notification_button_tween.tween_property(notification_button_icon_shadow, "position", shadow_position, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	notification_button_tween.tween_property(notification_button_icon_shadow, "scale", icon_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	notification_button_tween.tween_property(notification_button_icon_shadow, "modulate", Color(0.0, 0.0, 0.0, shadow_alpha), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func apply_notification_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14) -> void:
	if button == null:
		return

	PixelUIStyle.apply_button_text(button, font_size)
	if danger:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.66, 0.10, 0.16, 0.92), Color(1.0, 0.34, 0.38, 0.54), 3, 12, 6))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.16, 0.24, 0.98), Color(1.0, 0.52, 0.54, 0.82), 3, 12, 7))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.42, 0.04, 0.10, 0.96), Color(0.48, 0.06, 0.10, 0.90), 3, 12, 4))
		button.add_theme_stylebox_override("disabled", PixelUIStyle.style_box(Color(0.30, 0.04, 0.08, 0.56), Color(0.10, 0.0, 0.02, 0.62), 3, 12, 3))
		return

	if selected:
		PixelUIStyle.apply_yellow_button(button, font_size)
		return

	PixelUIStyle.apply_blue_button(button, font_size)


func update_unread_badge() -> void:
	if unread_badge == null or unread_badge_label == null:
		return

	unread_badge.visible = unread_count > 0
	unread_badge_label.text = str(min(unread_count, 99))


func setup_notification_panel() -> void:
	var was_visible: bool = notification_panel != null and notification_panel.visible
	notification_panel = get_node_or_null("NotificationPanel")
	if notification_panel == null:
		notification_panel = Control.new()
		notification_panel.name = "NotificationPanel"
		add_child(notification_panel)

	var screen_size: Vector2 = get_panel_viewport_size()
	panel_layout_size = screen_size
	notification_panel.position = Vector2.ZERO
	notification_panel.size = screen_size
	notification_panel.z_index = 180
	notification_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	notification_panel.visible = was_visible
	if not notification_panel.gui_input.is_connected(_on_notification_panel_gui_input):
		notification_panel.gui_input.connect(_on_notification_panel_gui_input)

	for child in notification_panel.get_children():
		child.queue_free()

	var margin_x: float = float(clamp(screen_size.x * 0.035, 26.0, 76.0))
	var content_width: float = float(max(420.0, screen_size.x - margin_x * 2.0))
	var list_y: float = PANEL_HEADER_HEIGHT + 34.0
	var list_height: float = float(max(190.0, screen_size.y - list_y - 30.0))

	var panel_back := ColorRect.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = notification_panel.size
	panel_back.color = Color(0.055, 0.105, 0.145, 0.40)
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_panel.add_child(panel_back)

	var top_bar := Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(screen_size.x, PANEL_HEADER_HEIGHT)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		0,
		8
	))
	notification_panel.add_child(top_bar)

	var top_line := ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, PANEL_HEADER_HEIGHT - 5.0)
	top_line.size = Vector2(screen_size.x, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_panel.add_child(top_line)

	var title := Label.new()
	title.name = "Title"
	title.text = "NOTIFICATIONS"
	title.position = Vector2(margin_x, 6)
	title.size = Vector2(min(650.0, screen_size.x * 0.60), 66)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 52 if screen_size.x >= 1000.0 else 38)
	notification_panel.add_child(title)

	var title_sub := Label.new()
	title_sub.name = "TitleSub"
	title_sub.text = "HISTORY"
	title_sub.position = Vector2(margin_x + 6.0, 60)
	title_sub.size = Vector2(210, 22)
	title_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(title_sub, 14)
	notification_panel.add_child(title_sub)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(screen_size.x - margin_x - close_button.size.x, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.text = "X"
	apply_notification_arcade_button_style(close_button, false, true, 24)
	close_button.pressed.connect(close_notification_panel)
	notification_panel.add_child(close_button)

	var count_chip_width: float = 154.0
	var count_chip := Panel.new()
	count_chip.name = "CountChip"
	count_chip.position = Vector2(close_button.position.x - count_chip_width - 14.0, 14)
	count_chip.size = Vector2(count_chip_width, 48)
	count_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		14,
		8
	))
	notification_panel.add_child(count_chip)

	history_count_label = Label.new()
	history_count_label.name = "HistoryCount"
	history_count_label.position = count_chip.position
	history_count_label.size = count_chip.size
	history_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	history_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(history_count_label, 20, Color.WHITE)
	notification_panel.add_child(history_count_label)

	var list_back := Panel.new()
	list_back.name = "ListBack"
	list_back.position = Vector2(margin_x, list_y)
	list_back.size = Vector2(content_width, list_height)
	list_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		14,
		2
	))
	notification_panel.add_child(list_back)

	history_scroll = ScrollContainer.new()
	history_scroll.name = "HistoryScroll"
	history_scroll.position = Vector2(margin_x + 12.0, list_y + 12.0)
	history_scroll.size = Vector2(content_width - 24.0, list_height - 24.0)
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	history_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	history_scroll.clip_contents = true
	notification_panel.add_child(history_scroll)

	history_root = VBoxContainer.new()
	history_root.name = "HistoryItems"
	history_root.position = Vector2.ZERO
	history_root.size = Vector2(history_scroll.size.x - 18.0, history_scroll.size.y)
	history_root.custom_minimum_size = history_root.size
	history_root.add_theme_constant_override("separation", 8)
	history_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	history_scroll.add_child(history_root)

	apply_notification_scrollbar_style()
	refresh_notification_panel()


func get_panel_viewport_size() -> Vector2:
	var screen_size: Vector2 = get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return Vector2(1180, 640)
	return screen_size


func refresh_notification_panel_for_viewport() -> void:
	if notification_panel == null:
		return

	var screen_size: Vector2 = get_panel_viewport_size()
	if panel_layout_size == Vector2.ZERO:
		panel_layout_size = screen_size
		return

	if panel_layout_size.distance_to(screen_size) <= 2.0:
		return

	setup_notification_panel()


func update_notification_panel_position() -> void:
	if notification_panel == null:
		return

	notification_panel.position = Vector2.ZERO
	notification_panel.size = get_panel_viewport_size()


func apply_notification_scrollbar_style() -> void:
	if history_scroll == null:
		return

	var scrollbar: VScrollBar = history_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func open_notification_panel() -> void:
	if notification_panel == null:
		setup_notification_panel()
	if notification_panel == null:
		return

	notification_panel.visible = true
	unread_count = 0
	update_unread_badge()
	refresh_notification_panel()
	PixelUIStyle.play_panel_open(notification_panel)


func close_notification_panel() -> void:
	if notification_panel == null:
		return

	notification_panel.visible = false


func toggle_notification_panel() -> void:
	if is_notification_panel_open():
		close_notification_panel()
	else:
		if world != null and world.has_method("open_notification_panel"):
			world.open_notification_panel()
		else:
			open_notification_panel()


func is_notification_panel_open() -> bool:
	return notification_panel != null and notification_panel.visible


func _on_notification_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()


func refresh_notification_panel() -> void:
	if history_root == null:
		return

	for child in history_root.get_children():
		child.queue_free()

	var content_width: float = float(max(300.0, history_root.size.x))
	var total_height := 0.0

	if history_count_label != null:
		history_count_label.text = str(notification_history.size()) + "/" + str(HISTORY_LIMIT)

	if notification_history.is_empty():
		var empty_row: Panel = Panel.new()
		empty_row.name = "EmptyHistory"
		empty_row.custom_minimum_size = Vector2(content_width, 72)
		empty_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.82, 0.94, 1.0, 0.10),
			Color(0.42, 0.78, 1.0, 0.18),
			1,
			8,
			1
		))
		history_root.add_child(empty_row)

		var empty_label: Label = Label.new()
		empty_label.name = "Label"
		empty_label.text = "NO NOTIFICATIONS"
		empty_label.position = Vector2(12, 0)
		empty_label.size = Vector2(content_width - 24.0, 72)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_small_label(empty_label, 16)
		empty_row.add_child(empty_label)

		history_root.custom_minimum_size = Vector2(content_width, max(history_scroll.size.y, 72.0))
		return

	for i in range(notification_history.size() - 1, -1, -1):
		var entry: Dictionary = notification_history[i]
		var row: Panel = make_history_row(entry, content_width)
		history_root.add_child(row)
		total_height += row.custom_minimum_size.y + 8.0

	history_root.custom_minimum_size = Vector2(content_width, max(history_scroll.size.y, total_height))


func estimate_history_row_height(message: String, width: float, has_actions: bool = false) -> float:
	var action_width: float = 188.0 if has_actions else 0.0
	var text_width: float = float(max(180.0, width - 138.0 - action_width))
	var chars_per_line: int = int(max(24, int(text_width / 8.5)))
	var line_count: int = int(max(1, int(ceil(float(message.length()) / float(chars_per_line)))))
	var minimum_height: float = 86.0 if has_actions else 68.0
	return float(max(minimum_height, float(line_count) * 20.0 + 42.0))


func make_history_row(entry: Dictionary, width: float) -> Panel:
	var message: String = str(entry.get("message", ""))
	var details: Dictionary = entry.get("details", {})
	var accent_color: Color = Color(details.get("accent", Color(0.30, 0.62, 1.0, 1.0)), 1.0)
	var is_friend_request: bool = bool(details.get("friend_request", false)) and not bool(details.get("resolved", false))
	var row_height: float = estimate_history_row_height(message, width, is_friend_request)
	var action_width: float = 188.0 if is_friend_request else 0.0
	var text_width: float = max(180.0, width - 132.0 - action_width)

	var row: Panel = Panel.new()
	row.name = "HistoryRow"
	row.custom_minimum_size = Vector2(width, row_height)
	row.mouse_filter = Control.MOUSE_FILTER_PASS if is_friend_request else Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.14, 0.27, 0.38, 0.48),
		Color(accent_color, 0.58),
		2,
		6,
		3
	))

	var accent: ColorRect = ColorRect.new()
	accent.name = "Accent"
	accent.position = Vector2(0, 0)
	accent.size = Vector2(5, row_height)
	accent.color = accent_color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent)

	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.position = Vector2(16, 14)
	icon_frame.size = Vector2(38, 38)
	icon_frame.custom_minimum_size = Vector2(38, 38)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent_color, 0.14),
		Color(accent_color, 0.76),
		2,
		8,
		1
	))
	row.add_child(icon_frame)

	var icon: Label = Label.new()
	icon.name = "Icon"
	icon.text = str(details.get("icon", "i"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(icon, 14, accent_color)
	icon_frame.add_child(icon)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = str(details.get("title", "INFO"))
	title.position = Vector2(68, 9)
	title.size = Vector2(text_width, 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 13, Color(details.get("title_color", Color(0.82, 0.94, 1.0, 1.0))))
	row.add_child(title)

	var body: Label = Label.new()
	body.name = "Body"
	body.text = message
	body.position = Vector2(68, 31)
	body.size = Vector2(text_width, row_height - 36.0)
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	body.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	body.add_theme_constant_override("shadow_offset_x", 1)
	body.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(body)

	if is_friend_request:
		var from_username: String = str(details.get("from_username", "")).strip_edges()
		var accept_button: Button = make_history_action_button("ACCEPT", Vector2(width - 178.0, 15.0), true)
		accept_button.pressed.connect(_on_friend_request_notification_accept.bind(from_username))
		row.add_child(accept_button)

		var decline_button: Button = make_history_action_button("DECLINE", Vector2(width - 178.0, 51.0), false)
		decline_button.pressed.connect(_on_friend_request_notification_decline.bind(from_username))
		row.add_child(decline_button)
		return row

	var count: int = int(entry.get("count", 1))
	if count > 1:
		var badge: PanelContainer = PanelContainer.new()
		badge.name = "CountBadge"
		badge.position = Vector2(width - 58.0, 14)
		badge.size = Vector2(46, 26)
		badge.custom_minimum_size = Vector2(46, 26)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(0.95, 0.68, 0.08, 0.96),
			Color(1.0, 0.90, 0.22, 0.85),
			2,
			8,
			2
		))
		row.add_child(badge)

		var badge_label: Label = Label.new()
		badge_label.name = "Label"
		badge_label.text = "x" + str(count)
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUIStyle.apply_label_shadow(badge_label, 12, Color.WHITE)
		badge.add_child(badge_label)

	return row


func should_ignore_notification(message: String) -> bool:
	var lower := message.to_lower().strip_edges()

	if lower == "":
		return true

	if is_routine_world_action_message(lower):
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


func show_message(message: String, forced_kind: String = "") -> void:
	var clean_message: String = normalize_message(message)
	if should_ignore_notification(clean_message):
		return

	if message_container == null:
		setup()

	var pickup_data: Dictionary = parse_pickup_message(clean_message)
	var display_message: String = clean_message
	var pickup_items: Dictionary = {}
	var kind: String = forced_kind.strip_edges().to_lower()
	if not pickup_data.is_empty():
		var item_name: String = str(pickup_data.get("item", "Item"))
		var amount: int = int(pickup_data.get("amount", 1))
		pickup_items[item_name] = amount
		display_message = build_pickup_message(pickup_items)
		kind = "pickup"
	else:
		kind = get_effective_message_kind(display_message, kind)

	var details: Dictionary = get_message_details(display_message, kind)
	add_history_entry(display_message, kind, details)

	if merge_pickup_message(clean_message):
		return

	if merge_duplicate_message(display_message):
		return

	if not should_show_toast(kind):
		return

	var panel: Panel = make_toast(display_message, details)
	message_container.add_child(panel)
	last_toast_at = notification_elapsed

	messages.append({
		"node": panel,
		"message": display_message,
		"source_message": clean_message,
		"kind": kind,
		"pickup_items": pickup_items,
		"time": MESSAGE_LIFETIME,
		"age": 0.0,
		"count": 1,
		"progress": panel.get_node_or_null("Progress"),
		"body": panel.get_node_or_null("Margin/Row/TextColumn/Body"),
		"count_badge": panel.get_node_or_null("Margin/Row/CountBadge"),
	})

	while messages.size() > MAX_MESSAGES:
		var old_message = messages.pop_front()
		var old_node = old_message.get("node", null)
		if is_instance_valid(old_node):
			old_node.queue_free()

	update_position()


func show_level_up(progression_data: Dictionary) -> void:
	if message_container == null:
		setup()

	var xp_gained: int = int(progression_data.get("xp_gained", 0))
	var levels_gained: int = int(progression_data.get("levels_gained", 0))
	var level_before: int = int(progression_data.get("level_before", 1))
	var level_after: int = int(progression_data.get("level_after", level_before))
	var xp_after: int = int(progression_data.get("xp_after", 0))
	var xp_needed: int = int(progression_data.get("xp_needed", 0))
	var title_text: String = str(progression_data.get("title", "Explorer")).strip_edges()
	if title_text == "":
		title_text = "Explorer"
	if levels_gained <= 0 or level_after <= level_before:
		return

	var body_message: String = "Reached Level " + str(level_after) + " as " + title_text + "."
	if levels_gained > 1:
		body_message = "Jumped " + str(levels_gained) + " levels to Level " + str(level_after) + "."

	var details: Dictionary = {
		"title": "LEVEL UP",
		"icon": "LV",
		"accent": Color(1.0, 0.78, 0.18, 1.0),
		"title_color": Color(1.0, 0.93, 0.46, 1.0),
	}
	add_history_entry(body_message, "level_up", details)

	if is_floating_hud_blocked():
		show_message("Level " + str(level_after) + " reached: " + title_text + "!", "level_up")
		return

	if is_instance_valid(level_up_overlay):
		level_up_overlay.queue_free()
	level_up_overlay = make_level_up_overlay(level_before, level_after, levels_gained, title_text, xp_gained, xp_after, xp_needed)
	add_child(level_up_overlay)
	update_level_up_overlay_position()
	animate_level_up_overlay(level_up_overlay)


func make_level_up_overlay(level_before: int, level_after: int, levels_gained: int, title_text: String, xp_gained: int, xp_after: int, xp_needed: int) -> Control:
	var root := Control.new()
	root.name = "LevelUpOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 190
	var card_width: float = min(LEVEL_UP_WIDTH, max(320.0, root.size.x - 32.0))

	var flash := ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.size = root.size
	flash.color = Color(1.0, 0.80, 0.18, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	var card := Panel.new()
	card.name = "Card"
	card.size = Vector2(card_width, LEVEL_UP_HEIGHT)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.075, 0.145, 0.205, 0.92),
		Color(1.0, 0.78, 0.18, 0.96),
		4,
		18,
		18
	))
	root.add_child(card)

	var top_gloss := ColorRect.new()
	top_gloss.name = "TopGloss"
	top_gloss.position = Vector2(8, 8)
	top_gloss.size = Vector2(card_width - 16.0, 34)
	top_gloss.color = Color(1.0, 1.0, 1.0, 0.085)
	top_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_gloss)

	var left_bar := ColorRect.new()
	left_bar.name = "LeftBar"
	left_bar.position = Vector2(0, 18)
	left_bar.size = Vector2(8, LEVEL_UP_HEIGHT - 36.0)
	left_bar.color = Color(1.0, 0.78, 0.18, 1.0)
	left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(left_bar)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "LEVEL UP"
	kicker.position = Vector2(34, 18)
	kicker.size = Vector2(190, 28)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(kicker, 18, Color(1.0, 0.90, 0.40, 1.0))
	card.add_child(kicker)

	var source := Label.new()
	source.name = "Source"
	source.text = "+" + str(xp_gained) + " XP"
	source.position = Vector2(card_width - 190.0, 20)
	source.size = Vector2(156, 26)
	source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(source, 16)
	card.add_child(source)

	var level_label := Label.new()
	level_label.name = "Level"
	level_label.text = "LEVEL " + str(level_after)
	level_label.position = Vector2(34, 50)
	level_label.size = Vector2(card_width - 68.0, 72)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(level_label, 54, Color.WHITE)
	card.add_child(level_label)

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title_text.to_upper()
	title_label.position = Vector2(34, 118)
	title_label.size = Vector2(card_width - 68.0, 34)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title_label, 24, Color(1.0, 0.89, 0.34, 1.0))
	card.add_child(title_label)

	var detail_label := Label.new()
	detail_label.name = "Detail"
	detail_label.text = "Level " + str(level_before) + " -> " + str(level_after)
	if levels_gained > 1:
		detail_label.text += "  |  +" + str(levels_gained) + " levels"
	detail_label.position = Vector2(34, 154)
	detail_label.size = Vector2(card_width - 68.0, 28)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(detail_label, 16)
	card.add_child(detail_label)

	var track := Panel.new()
	track.name = "XpTrack"
	track.position = Vector2(58, 194)
	track.size = Vector2(card_width - 116.0, 12)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.86, 0.96, 1.0, 0.14),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		6,
		0
	))
	card.add_child(track)

	var fill := Panel.new()
	fill.name = "XpFill"
	fill.position = track.position
	var fill_ratio: float = 1.0 if xp_needed <= 0 else clamp(float(xp_after) / float(max(1, xp_needed)), 0.0, 1.0)
	fill.size = Vector2(track.size.x * fill_ratio, track.size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(1.0, 0.78, 0.18, 0.88),
		Color(1.0, 1.0, 1.0, 0.26),
		0,
		6,
		0
	))
	card.add_child(fill)

	var xp_label := Label.new()
	xp_label.name = "XpLabel"
	xp_label.text = "MAX LEVEL" if xp_needed <= 0 else str(xp_after) + " / " + str(xp_needed) + " XP"
	xp_label.position = Vector2(58, 210)
	xp_label.size = Vector2(card_width - 116.0, 20)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(xp_label, 13)
	card.add_child(xp_label)

	return root


func update_level_up_overlay_position() -> void:
	if not is_instance_valid(level_up_overlay):
		return

	level_up_overlay.size = get_viewport_rect().size
	var flash = level_up_overlay.get_node_or_null("Flash")
	if flash != null and flash is Control:
		(flash as Control).size = level_up_overlay.size

	var card = level_up_overlay.get_node_or_null("Card")
	if card != null and card is Control:
		var card_control: Control = card as Control
		var screen_size: Vector2 = level_up_overlay.size
		card_control.pivot_offset = card_control.size * 0.5
		card_control.position = Vector2(
			(screen_size.x - card_control.size.x) * 0.5,
			clamp(screen_size.y * 0.20, 84.0, max(84.0, screen_size.y - LEVEL_UP_HEIGHT - 120.0))
		)


func animate_level_up_overlay(overlay: Control) -> void:
	if overlay == null:
		return
	if level_up_tween != null:
		level_up_tween.kill()

	var card_node = overlay.get_node_or_null("Card")
	var card_control: Control = null
	if card_node is Control:
		card_control = card_node as Control
	var flash_node = overlay.get_node_or_null("Flash")
	var flash_rect: ColorRect = null
	if flash_node is ColorRect:
		flash_rect = flash_node as ColorRect
	if card_control != null:
		card_control.scale = Vector2(0.82, 0.82)
		card_control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if flash_rect != null:
		flash_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		flash_rect.color = Color(1.0, 0.82, 0.18, 0.0)

	level_up_tween = create_tween()
	level_up_tween.set_parallel(true)
	if card_control != null:
		level_up_tween.tween_property(card_control, "scale", Vector2(1.04, 1.04), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		level_up_tween.tween_property(card_control, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		level_up_tween.tween_property(card_control, "scale", Vector2.ONE, 0.18).set_delay(0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		level_up_tween.tween_property(card_control, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.46).set_delay(LEVEL_UP_LIFETIME - 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if flash_rect != null:
		level_up_tween.tween_property(flash_rect, "color", Color(1.0, 0.82, 0.18, 0.28), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		level_up_tween.tween_property(flash_rect, "color", Color(1.0, 0.82, 0.18, 0.0), 0.42).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	spawn_level_up_sparks(overlay)
	level_up_tween.finished.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		if level_up_overlay == overlay:
			level_up_overlay = null
	)


func spawn_level_up_sparks(overlay: Control) -> void:
	if overlay == null:
		return
	var card = overlay.get_node_or_null("Card")
	if card == null or not (card is Control):
		return

	var card_control: Control = card as Control
	var center: Vector2 = card_control.position + card_control.size * 0.5
	for i in range(LEVEL_UP_SPARK_COUNT):
		var spark := ColorRect.new()
		spark.name = "Spark"
		var spark_size: float = randf_range(4.0, 9.0)
		spark.size = Vector2(spark_size, spark_size)
		spark.pivot_offset = spark.size * 0.5
		spark.position = center + Vector2(randf_range(-110.0, 110.0), randf_range(-34.0, 34.0))
		spark.rotation = randf_range(-0.7, 0.7)
		spark.color = Color(1.0, randf_range(0.62, 0.95), randf_range(0.12, 0.36), 0.98)
		if i % 4 == 0:
			spark.color = Color(0.30, 0.88, 1.0, 0.92)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(spark)

		var angle: float = randf_range(-PI, PI)
		var distance: float = randf_range(90.0, 220.0)
		var target: Vector2 = spark.position + Vector2(cos(angle), sin(angle)) * distance
		var spark_tween = create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", target, randf_range(0.65, 1.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "rotation", spark.rotation + randf_range(-2.8, 2.8), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector2(randf_range(0.3, 0.6), randf_range(0.3, 0.6)), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "modulate", Color(1.0, 1.0, 1.0, 0.0), randf_range(0.55, 0.95)).set_delay(0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		spark_tween.finished.connect(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)


func add_history_entry(message: String, kind: String, details: Dictionary) -> void:
	var clean_message: String = message.strip_edges()
	if clean_message == "":
		return

	var clean_kind: String = kind.strip_edges().to_lower()
	var merged_latest := false
	if not notification_history.is_empty():
		var latest_index: int = notification_history.size() - 1
		var latest: Dictionary = notification_history[latest_index]
		var latest_age: float = notification_elapsed - float(latest.get("time", -999.0))
		if str(latest.get("message", "")) == clean_message and str(latest.get("kind", "")) == clean_kind and latest_age <= DUPLICATE_WINDOW:
			latest["count"] = int(latest.get("count", 1)) + 1
			latest["time"] = notification_elapsed
			latest["details"] = details
			notification_history[latest_index] = latest
			merged_latest = true

	if not merged_latest:
		notification_history.append({
			"message": clean_message,
			"kind": clean_kind,
			"details": details,
			"time": notification_elapsed,
			"count": 1,
		})

	while notification_history.size() > HISTORY_LIMIT:
		notification_history.pop_front()

	if is_notification_panel_open():
		refresh_notification_panel()
	else:
		unread_count = min(HISTORY_LIMIT, unread_count + 1)
		update_unread_badge()


func add_friend_request_notification(from_username: String) -> void:
	var clean_username: String = from_username.strip_edges()
	if clean_username == "":
		return

	var details: Dictionary = {
		"title": "FRIEND REQUEST",
		"icon": "+",
		"accent": Color(1.0, 0.76, 0.18, 1.0),
		"title_color": Color(1.0, 0.90, 0.48, 1.0),
		"friend_request": true,
		"from_username": clean_username,
	}
	add_history_entry(clean_username + " wants to be friends.", "friend_request", details)


func mark_friend_request_notification_resolved(from_username: String, accepted: bool) -> void:
	var clean_username: String = from_username.strip_edges()
	if clean_username == "":
		return

	for i in range(notification_history.size()):
		var entry: Dictionary = notification_history[i]
		var details_value: Variant = entry.get("details", {})
		if not (details_value is Dictionary):
			continue
		var details: Dictionary = details_value
		if not bool(details.get("friend_request", false)):
			continue
		if str(details.get("from_username", "")).strip_edges().to_lower() != clean_username.to_lower():
			continue
		details["resolved"] = true
		details["title"] = "FRIEND REQUEST"
		details["icon"] = "+" if accepted else "x"
		entry["details"] = details
		entry["message"] = ("Accepted " if accepted else "Declined ") + clean_username + "'s friend request."
		notification_history[i] = entry

	if is_notification_panel_open():
		refresh_notification_panel()


func make_history_action_button(button_text: String, button_position: Vector2, positive: bool) -> Button:
	var button: Button = Button.new()
	button.name = "Action_" + button_text
	button.text = button_text
	button.position = button_position
	button.size = Vector2(154, 30)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_button_text(button, 12)
	if positive:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.08, 0.48, 0.13, 0.98), Color(0.36, 1.0, 0.42, 0.72), 3, 8, 5))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.10, 0.62, 0.18, 0.98), Color(0.58, 1.0, 0.62, 0.86), 3, 8, 6))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.04, 0.30, 0.08, 0.98), Color(0.06, 0.18, 0.06, 1.0), 3, 8, 3))
	else:
		button.add_theme_stylebox_override("normal", PixelUIStyle.style_box(Color(0.62, 0.08, 0.15, 0.98), Color(0.18, 0.01, 0.05, 1.0), 3, 8, 5))
		button.add_theme_stylebox_override("hover", PixelUIStyle.style_box(Color(0.86, 0.12, 0.22, 0.98), Color(1.0, 0.38, 0.40, 0.72), 3, 8, 6))
		button.add_theme_stylebox_override("pressed", PixelUIStyle.style_box(Color(0.40, 0.03, 0.09, 0.98), Color(0.12, 0.0, 0.02, 1.0), 3, 8, 3))
	return button


func _on_friend_request_notification_accept(from_username: String) -> void:
	var clean_username: String = from_username.strip_edges()
	if clean_username == "":
		return
	if world != null and world.has_method("accept_friend_request_from"):
		world.accept_friend_request_from(clean_username)


func _on_friend_request_notification_decline(from_username: String) -> void:
	var clean_username: String = from_username.strip_edges()
	if clean_username == "":
		return
	if world != null and world.has_method("decline_friend_request_from"):
		world.decline_friend_request_from(clean_username)


func should_show_toast(kind: String) -> bool:
	if is_notification_panel_open():
		return false

	var clean_kind: String = kind.strip_edges().to_lower()
	if ["error", "warning", "trade", "reward", "level_up"].has(clean_kind):
		return true

	return notification_elapsed - last_toast_at >= TOAST_COOLDOWN


func normalize_message(message: String) -> String:
	var clean_message: String = message.strip_edges()
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
		"server connection required.", "server connection required for trading.":
			return clean_message.replace("Server connection", "Connection")
		"server did not answer. try again.":
			return "Connection timed out. Try again."
		"server rejected that action.":
			return "That action could not be completed."
		"server did not accept safe request.":
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


func parse_pickup_message(message: String) -> Dictionary:
	var clean_message: String = message.strip_edges()
	var lower: String = clean_message.to_lower()
	if not lower.begins_with("picked up "):
		return {}

	var payload: String = clean_message.substr("Picked up ".length()).strip_edges()
	if payload.ends_with("."):
		payload = payload.substr(0, payload.length() - 1)

	var split_index: int = payload.find(" ")
	if split_index <= 0:
		return {}

	var amount_text: String = payload.substr(0, split_index).strip_edges()
	if not amount_text.is_valid_int():
		return {}

	var raw_name: String = payload.substr(split_index + 1).strip_edges()
	if raw_name == "":
		return {}

	return {
		"amount": max(1, int(amount_text)),
		"item": beautify_item_name(raw_name),
	}


func beautify_item_name(raw_name: String) -> String:
	var label: String = raw_name.replace("_", " ").replace("-", " ").strip_edges()
	while label.find("  ") != -1:
		label = label.replace("  ", " ")

	return label.capitalize()


func build_pickup_message(items: Dictionary) -> String:
	var parts := []
	var total := 0
	for item_name in items.keys():
		var amount: int = int(items[item_name])
		total += amount
		parts.append(str(item_name) + " x" + str(amount))

	parts.sort()
	if parts.size() <= 2:
		return ", ".join(parts)

	return str(total) + " items picked up"


func get_pickup_total(items: Dictionary) -> int:
	var total := 0
	for item_name in items.keys():
		total += int(items[item_name])

	return total


func merge_pickup_message(message: String) -> bool:
	var pickup_data: Dictionary = parse_pickup_message(message)
	if pickup_data.is_empty():
		return false

	for i in range(messages.size() - 1, -1, -1):
		var data = messages[i]
		if str(data.get("kind", "")) != "pickup":
			continue

		var node = data.get("node", null)
		if not is_instance_valid(node):
			continue

		var item_name: String = str(pickup_data.get("item", "Item"))
		var amount: int = int(pickup_data.get("amount", 1))
		var items: Dictionary = data.get("pickup_items", {})
		items[item_name] = int(items.get(item_name, 0)) + amount

		var new_message: String = build_pickup_message(items)
		data["pickup_items"] = items
		data["message"] = new_message
		data["time"] = MESSAGE_LIFETIME
		data["age"] = 0.08
		data["count"] = get_pickup_total(items)
		messages[i] = data

		var body = data.get("body", null)
		if is_instance_valid(body):
			body.text = new_message

		var badge = data.get("count_badge", null)
		if is_instance_valid(badge):
			badge.visible = true
			var badge_label = badge.get_node_or_null("Label")
			if badge_label != null:
				badge_label.text = "x" + str(get_pickup_total(items))

		node.scale = Vector2(1.015, 1.015)
		return true

	return false


func merge_duplicate_message(message: String) -> bool:
	for i in range(messages.size() - 1, -1, -1):
		var data = messages[i]
		if str(data.get("message", "")) != message:
			continue

		var age: float = float(data.get("age", 999.0))
		if age > DUPLICATE_WINDOW:
			continue

		var node = data.get("node", null)
		if not is_instance_valid(node):
			continue

		var count: int = int(data.get("count", 1)) + 1
		data["count"] = count
		data["time"] = MESSAGE_LIFETIME
		data["age"] = 0.08
		messages[i] = data

		var badge = data.get("count_badge", null)
		if is_instance_valid(badge):
			badge.visible = true
			var badge_label = badge.get_node_or_null("Label")
			if badge_label != null:
				badge_label.text = "x" + str(count)

		node.scale = Vector2(1.015, 1.015)
		return true

	return false


func make_toast(message: String, details: Dictionary) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "Notification"
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	panel.size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	var accent_color: Color = Color(details.get("accent", Color.WHITE), 1.0)
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = Vector2(TOAST_WIDTH * 0.5, TOAST_HEIGHT * 0.5)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var shadow: Panel = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(7, 8)
	shadow.size = Vector2(TOAST_WIDTH - 10.0, TOAST_HEIGHT - 10.0)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.30),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		18,
		0
	))
	panel.add_child(shadow)

	var card: Panel = Panel.new()
	card.name = "Card"
	card.position = Vector2.ZERO
	card.size = Vector2(TOAST_WIDTH, TOAST_HEIGHT - 4.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.070, 0.155, 0.220, 0.78),
		Color(0.52, 0.86, 1.0, 0.54),
		2,
		16,
		8
	))
	panel.add_child(card)

	var card_gloss: ColorRect = ColorRect.new()
	card_gloss.name = "CardGloss"
	card_gloss.position = Vector2(4, 4)
	card_gloss.size = Vector2(TOAST_WIDTH - 8.0, 19)
	card_gloss.color = Color(1.0, 1.0, 1.0, 0.075)
	card_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(card_gloss)

	var accent_glow: Panel = Panel.new()
	accent_glow.name = "AccentGlow"
	accent_glow.position = Vector2(6, 9)
	accent_glow.size = Vector2(10, TOAST_HEIGHT - 22.0)
	accent_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_glow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent_color, 0.72),
		Color(accent_color, 0.88),
		1,
		8,
		4
	))
	panel.add_child(accent_glow)

	var progress_track: Panel = Panel.new()
	progress_track.name = "ProgressTrack"
	progress_track.anchor_left = 0.0
	progress_track.anchor_top = 1.0
	progress_track.anchor_right = 0.0
	progress_track.anchor_bottom = 1.0
	progress_track.offset_left = TOAST_PROGRESS_INSET
	progress_track.offset_top = -11
	progress_track.offset_right = TOAST_WIDTH - TOAST_PROGRESS_INSET
	progress_track.offset_bottom = -7
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.86, 0.96, 1.0, 0.14),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		5,
		0
	))
	panel.add_child(progress_track)

	var progress: Panel = Panel.new()
	progress.name = "Progress"
	progress.anchor_left = 0.0
	progress.anchor_top = 1.0
	progress.anchor_right = 0.0
	progress.anchor_bottom = 1.0
	progress.offset_left = TOAST_PROGRESS_INSET
	progress.offset_top = -11
	progress.offset_right = TOAST_WIDTH - TOAST_PROGRESS_INSET
	progress.offset_bottom = -7
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent_color, 0.82),
		Color(1.0, 1.0, 1.0, 0.26),
		0,
		5,
		0
	))
	panel.add_child(progress)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.custom_minimum_size = Vector2(46, 46)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent_color, 0.20),
		Color(accent_color, 0.90),
		3,
		13,
		4
	))
	row.add_child(icon_frame)

	var icon: Label = Label.new()
	icon.name = "Icon"
	icon.text = str(details.get("icon", "i"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(icon, 18, Color(1.0, 1.0, 1.0, 1.0))
	icon_frame.add_child(icon)

	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.name = "TextColumn"
	text_column.custom_minimum_size = Vector2(276, 44)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = str(details.get("title", "Notice"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 12, Color(details.get("title_color", Color(0.82, 0.94, 1.0, 1.0))))
	text_column.add_child(title)

	var body: Label = Label.new()
	body.name = "Body"
	body.text = message
	body.custom_minimum_size = Vector2(276, 31)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	body.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	body.add_theme_constant_override("shadow_offset_x", 1)
	body.add_theme_constant_override("shadow_offset_y", 1)
	text_column.add_child(body)

	var count_badge: PanelContainer = PanelContainer.new()
	count_badge.name = "CountBadge"
	count_badge.custom_minimum_size = Vector2(48, 28)
	count_badge.visible = false
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.95, 0.68, 0.08, 0.96),
		Color(1.0, 0.90, 0.22, 0.85),
		2,
		10,
		3
	))
	row.add_child(count_badge)

	var count_label: Label = Label.new()
	count_label.name = "Label"
	count_label.text = "x1"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(count_label, 12, Color.WHITE)
	count_badge.add_child(count_label)

	return panel


func get_message_details(message: String, forced_kind: String = "") -> Dictionary:
	var kind: String = forced_kind.strip_edges().to_lower()
	if kind == "":
		kind = infer_message_kind(message)

	match kind:
		"pickup":
			return {
				"title": "PICKUP",
				"icon": "+",
				"accent": Color(0.35, 1.0, 0.48, 1.0),
				"title_color": Color(0.72, 1.0, 0.78, 1.0),
			}
		"success":
			return {
				"title": "DONE",
				"icon": "+",
				"accent": Color(0.35, 1.0, 0.42, 1.0),
				"title_color": Color(0.72, 1.0, 0.78, 1.0),
			}
		"warning":
			return {
				"title": "HEADS UP",
				"icon": "!",
				"accent": Color(1.0, 0.78, 0.14, 1.0),
				"title_color": Color(1.0, 0.88, 0.45, 1.0),
			}
		"error":
			return {
				"title": "BLOCKED",
				"icon": "!",
				"accent": Color(1.0, 0.26, 0.20, 1.0),
				"title_color": Color(1.0, 0.60, 0.55, 1.0),
			}
		"reward":
			return {
				"title": "REWARD",
				"icon": "$",
				"accent": Color(0.28, 0.96, 1.0, 1.0),
				"title_color": Color(0.70, 0.98, 1.0, 1.0),
			}
		"level_up":
			return {
				"title": "LEVEL UP",
				"icon": "LV",
				"accent": Color(1.0, 0.78, 0.18, 1.0),
				"title_color": Color(1.0, 0.93, 0.46, 1.0),
			}
		"trade":
			return {
				"title": "TRADE",
				"icon": "<>",
				"accent": Color(0.70, 0.56, 1.0, 1.0),
				"title_color": Color(0.82, 0.76, 1.0, 1.0),
			}
		_:
			return {
				"title": "INFO",
				"icon": "i",
				"accent": Color(0.30, 0.62, 1.0, 1.0),
				"title_color": Color(0.76, 0.90, 1.0, 1.0),
			}


func get_effective_message_kind(message: String, forced_kind: String = "") -> String:
	var kind: String = forced_kind.strip_edges().to_lower()
	if kind == "":
		kind = infer_message_kind(message)
	return kind


func infer_message_kind(message: String) -> String:
	var lower := message.to_lower()

	if lower.begins_with("picked up "):
		return "pickup"

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


# Compatibility alias. Some files may call show_notification directly.
func show_notification(message: String) -> void:
	show_message(message)


func update_messages(delta: float) -> void:
	for i in range(messages.size() - 1, -1, -1):
		var data = messages[i]
		var node = data.get("node", null)

		if not is_instance_valid(node):
			messages.remove_at(i)
			continue

		data["time"] = float(data.get("time", 0.0)) - delta
		data["age"] = float(data.get("age", 0.0)) + delta
		messages[i] = data

		var remaining: float = float(data["time"])
		var age: float = float(data["age"])
		var fade_in: float = smoothstep(0.0, 0.22, age)
		var fade_out: float = clamp(remaining / 0.48, 0.0, 1.0)
		var alpha: float = min(fade_in, fade_out)

		node.modulate.a = alpha
		node.position.x = (1.0 - fade_in) * 22.0
		node.scale = node.scale.lerp(Vector2.ONE, clamp(delta * 10.0, 0.0, 1.0))

		var progress_node = data.get("progress", null)
		if is_instance_valid(progress_node) and progress_node is Control:
			var progress: Control = progress_node as Control
			var progress_width: float = (TOAST_WIDTH - TOAST_PROGRESS_INSET * 2.0) * clamp(remaining / MESSAGE_LIFETIME, 0.0, 1.0)
			progress.offset_right = progress.offset_left + progress_width

		if remaining <= 0.0:
			node.queue_free()
			messages.remove_at(i)
