extends Control

const CHAT_BUBBLE_PANEL_TEXTURE: Texture2D = preload("res://Assets/ui/lobby/inner_panel.png")

const CHAT_BUBBLE_TIME := 4.0
const CHAT_BUBBLE_ANCHOR_OFFSET_WORLD_PX := 96.0
const CHAT_BUBBLE_USERNAME_GAP_SCREEN_PX := 2.0
const CHAT_BUBBLE_MIN_WIDTH := 86.0
const CHAT_BUBBLE_MAX_WIDTH := 360.0
const CHAT_BUBBLE_PAD_X := 14.0
const CHAT_BUBBLE_PAD_Y := 8.0
const CHAT_FONT_PATH := "res://Assets/font/font.ttf"
const CHAT_BUBBLE_FONT_SIZE := 24
const CHAT_BUBBLE_LINE_SPACING := 2
const CHAT_BUBBLE_DEFAULT_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CHAT_BUBBLE_PANEL_PATCH_MARGIN := 4.0
const NOTIFICATION_STACK_MAX_ENTRIES := 5
const NOTIFICATION_STACK_GAP := 2.0
const NOTIFICATION_ENTRY_LIFETIME_MSEC := 4000
const BUBBLE_MODE_NONE := ""
const BUBBLE_MODE_CHAT := "chat"
const BUBBLE_MODE_NOTIFICATION := "notification"

static func world_to_screen_position(viewport, world_position: Vector2) -> Vector2:
	if viewport == null or not is_instance_valid(viewport):
		return Vector2.ZERO
	if not (viewport is Viewport):
		return Vector2.ZERO

	var canvas_transform = viewport.get_canvas_transform()
	return canvas_transform * world_position


static func clamp_screen_position(screen_position: Vector2, bubble_size: Vector2, viewport) -> Vector2:
	if viewport == null or not is_instance_valid(viewport):
		return screen_position
	if not (viewport is Viewport):
		return screen_position

	var viewport_rect = viewport.get_visible_rect()
	var viewport_size = viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return screen_position

	var min_x = viewport_rect.position.x + 2.0
	var min_y = viewport_rect.position.y + 2.0
	var max_x = viewport_rect.position.x + viewport_size.x - bubble_size.x - 2.0
	var max_y = viewport_rect.position.y + viewport_size.y - bubble_size.y - 2.0
	return Vector2(
		clamp(screen_position.x, min_x, max_x),
		clamp(screen_position.y, min_y, max_y)
	)

static func get_anchor_offset_world_px() -> float:
	return CHAT_BUBBLE_ANCHOR_OFFSET_WORLD_PX


static func get_username_gap_screen_px() -> float:
	return CHAT_BUBBLE_USERNAME_GAP_SCREEN_PX


static func measure_text_width(text: String, font, font_size: int) -> float:
	if text == "":
		return 0.0
	if font != null and font.has_method("get_string_size"):
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return float(text.length()) * _fallback_char_width(font_size)


static func wrap_text_to_width(text: String, max_width: float, font, font_size: int) -> String:
	var safe_width = max(1.0, max_width)
	var normalized_text = str(text).replace("\r\n", "\n").replace("\r", "\n")
	var paragraphs = normalized_text.split("\n", true)
	var output := PackedStringArray()

	for paragraph in paragraphs:
		var paragraph_lines = _wrap_paragraph_to_width(str(paragraph), safe_width, font, font_size)
		for line in paragraph_lines:
			output.append(line)

	if output.size() == 0:
		output.append("")
	return "\n".join(output)


static func count_wrapped_lines(text: String) -> int:
	return max(1, text.split("\n", true).size())


static func get_widest_line_width(text: String, font, font_size: int) -> float:
	var widest := 0.0
	for line in text.split("\n", true):
		widest = max(widest, measure_text_width(str(line), font, font_size))
	return widest


static func get_text_line_height(font, font_size: int) -> float:
	if font != null and font.has_method("get_height"):
		return ceilf(float(font.get_height(font_size)))
	return ceilf(float(font_size) * 1.25)


static func measure_text_block_height(text: String, font, font_size: int) -> float:
	var line_count := count_wrapped_lines(text)
	var line_height := get_text_line_height(font, font_size)
	var spacing_height := float(maxi(0, line_count - 1) * CHAT_BUBBLE_LINE_SPACING)
	return maxf(1.0, float(line_count) * line_height + spacing_height)


static func _wrap_paragraph_to_width(paragraph: String, max_width: float, font, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var words = paragraph.split(" ", false)
	var current_line := ""

	if words.size() == 0:
		lines.append("")
		return lines

	for word_value in words:
		var word = str(word_value)
		var pieces = _split_token_to_width(word, max_width, font, font_size)
		for piece_index in range(pieces.size()):
			var piece = str(pieces[piece_index])
			if current_line == "":
				current_line = piece
				continue

			var separator = " " if piece_index == 0 else ""
			var candidate = current_line + separator + piece
			if measure_text_width(candidate, font, font_size) <= max_width:
				current_line = candidate
			else:
				lines.append(current_line)
				current_line = piece

	if current_line != "":
		lines.append(current_line)
	return lines


static func _split_token_to_width(token: String, max_width: float, font, font_size: int) -> PackedStringArray:
	var pieces := PackedStringArray()
	var current_piece := ""

	for i in range(token.length()):
		var character = token.substr(i, 1)
		var candidate = current_piece + character
		if current_piece != "" and measure_text_width(candidate, font, font_size) > max_width:
			pieces.append(current_piece)
			current_piece = character
		else:
			current_piece = candidate

	if current_piece != "":
		pieces.append(current_piece)
	return pieces


static func _fallback_char_width(font_size: int) -> float:
	return max(1.0, float(font_size) * 0.58)


var background: Panel = null
var label: Label = null
var notification_stack: VBoxContainer = null
var hide_timer: Timer = null
var label_settings: LabelSettings = null
var chat_font: Font = null
var current_text_color := CHAT_BUBBLE_DEFAULT_TEXT_COLOR
var notification_entries: Array[Dictionary] = []
var notification_sequence_id := 0
var bubble_mode := BUBBLE_MODE_NONE


func get_chat_font() -> Font:
	if chat_font == null and ResourceLoader.exists(CHAT_FONT_PATH):
		var loaded_font: Resource = load(CHAT_FONT_PATH)
		if loaded_font is Font:
			chat_font = loaded_font
	return chat_font


func apply_chat_font_to_label() -> void:
	if label == null:
		return

	var font := get_chat_font()
	if font == null:
		return

	label.add_theme_font_override("font", font)
	if label_settings != null:
		label_settings.font = font


func _ready():
	_configure_root()
	_build_bubble_ui()
	if label != null and str(label.text).strip_edges() != "":
		label.visible = true
		if background != null:
			background.visible = true
		visible = true
		move_to_front()
		label.move_to_front()
	else:
		visible = false


func _configure_root():
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate = Color.WHITE
	modulate = Color.WHITE
	z_as_relative = false
	z_index = 72


func _build_bubble_ui():
	_configure_root()

	background = get_node_or_null("Background")
	if background == null:
		background = Panel.new()
		background.name = "Background"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.z_as_relative = true
		background.z_index = 0
		add_child(background)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.add_theme_stylebox_override("panel", _create_background_style())

	label = get_node_or_null("Label")
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_as_relative = true
		label.z_index = 1
		label.self_modulate = Color.WHITE
		label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_child(label)
		label.clip_text = false
		label.visible = true
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = true
	label.z_index = 1
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_font_size_override("font_size", CHAT_BUBBLE_FONT_SIZE)
	label.add_theme_constant_override("line_spacing", CHAT_BUBBLE_LINE_SPACING)
	apply_chat_font_to_label()
	label.add_theme_color_override("font_color", current_text_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.modulate = Color.WHITE
	label.self_modulate = Color.WHITE
	label.visible = true
	label.show()
	label.move_to_front()
	_apply_label_settings()

	notification_stack = get_node_or_null("NotificationStack") as VBoxContainer
	if notification_stack == null:
		notification_stack = VBoxContainer.new()
		notification_stack.name = "NotificationStack"
		notification_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notification_stack.z_as_relative = true
		notification_stack.z_index = 1
		notification_stack.add_theme_constant_override("separation", int(NOTIFICATION_STACK_GAP))
		add_child(notification_stack)
	notification_stack.visible = false
	notification_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_stack.z_as_relative = true
	notification_stack.z_index = 1

	if hide_timer == null:
		hide_timer = Timer.new()
		hide_timer.name = "HideTimer"
		hide_timer.one_shot = true
		hide_timer.timeout.connect(_on_hide_timer_timeout)
		add_child(hide_timer)


func _create_background_style() -> StyleBoxTexture:
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = CHAT_BUBBLE_PANEL_TEXTURE
	panel_style.texture_margin_left = CHAT_BUBBLE_PANEL_PATCH_MARGIN
	panel_style.texture_margin_top = CHAT_BUBBLE_PANEL_PATCH_MARGIN
	panel_style.texture_margin_right = CHAT_BUBBLE_PANEL_PATCH_MARGIN
	panel_style.texture_margin_bottom = CHAT_BUBBLE_PANEL_PATCH_MARGIN
	return panel_style


func _apply_label_settings():
	if label == null:
		return

	if label_settings == null:
		label_settings = LabelSettings.new()

	label_settings.font = get_chat_font()
	label_settings.font_size = CHAT_BUBBLE_FONT_SIZE
	label_settings.line_spacing = CHAT_BUBBLE_LINE_SPACING
	label_settings.font_color = current_text_color
	label_settings.outline_size = 3
	label_settings.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	label_settings.shadow_size = 1
	label_settings.shadow_color = Color(0.0, 0.0, 0.0, 1.0)
	label_settings.shadow_offset = Vector2(1.0, 1.0)
	label.label_settings = label_settings
	label.add_theme_color_override("font_color", current_text_color)


func show_chat_message(message: String, text_color: Color = CHAT_BUBBLE_DEFAULT_TEXT_COLOR):
	_configure_root()
	if background == null or label == null:
		_build_bubble_ui()

	var clean_message = str(message).strip_edges()
	if clean_message == "":
		return

	clear_notification_entries()
	bubble_mode = BUBBLE_MODE_CHAT
	current_text_color = text_color
	var wrapped_message = _layout_for_message(clean_message)
	label.text = wrapped_message
	_apply_label_settings()
	label.visible = true
	label.show()
	label.modulate = Color.WHITE
	label.self_modulate = Color.WHITE
	label.visible = true
	background.visible = true
	background.show()
	visible = true
	show()
	move_to_front()
	label.move_to_front()
	label.queue_redraw()
	queue_redraw()

	if hide_timer != null:
		hide_timer.stop()
		hide_timer.wait_time = CHAT_BUBBLE_TIME
		hide_timer.start()


func show_notification_message(message: String, text_color: Color = CHAT_BUBBLE_DEFAULT_TEXT_COLOR) -> bool:
	_configure_root()
	if background == null or label == null or notification_stack == null:
		_build_bubble_ui()
	if notification_stack == null:
		return false

	var clean_message := str(message).strip_edges()
	if clean_message == "":
		return false

	if bubble_mode != BUBBLE_MODE_NOTIFICATION:
		clear_notification_entries()
	bubble_mode = BUBBLE_MODE_NOTIFICATION
	current_text_color = text_color
	label.visible = false

	var now_msec := Time.get_ticks_msec()
	prune_expired_notification_entries(now_msec)
	var dedupe_key := get_notification_dedupe_key(clean_message)
	if has_active_notification_dedupe_key(dedupe_key):
		layout_notification_stack()
		schedule_notification_expiry(now_msec)
		return false

	notification_sequence_id += 1
	var entry_label := create_notification_label(text_color)
	notification_stack.add_child(entry_label)
	notification_entries.append({
		"id": notification_sequence_id,
		"message": clean_message,
		"dedupe_key": dedupe_key,
		"expires_at_msec": now_msec + NOTIFICATION_ENTRY_LIFETIME_MSEC,
		"label": entry_label
	})

	while notification_entries.size() > NOTIFICATION_STACK_MAX_ENTRIES:
		remove_notification_entry_at(0)

	layout_notification_stack()
	notification_stack.visible = true
	background.visible = true
	background.show()
	visible = true
	show()
	move_to_front()
	notification_stack.move_to_front()
	queue_redraw()
	schedule_notification_expiry(now_msec)
	return true


func get_notification_dedupe_key(message: String) -> String:
	var dedupe_key := message.strip_edges().to_lower()
	dedupe_key = dedupe_key.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while dedupe_key.find("  ") != -1:
		dedupe_key = dedupe_key.replace("  ", " ")
	return dedupe_key


func has_active_notification_dedupe_key(dedupe_key: String) -> bool:
	if dedupe_key == "":
		return false
	for entry in notification_entries:
		var entry_key := str(entry.get(
			"dedupe_key",
			get_notification_dedupe_key(str(entry.get("message", "")))
		))
		if entry_key == dedupe_key:
			return true
	return false


func create_notification_label(text_color: Color) -> Label:
	var entry_label := Label.new()
	entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	entry_label.clip_text = false
	entry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	entry_label.add_theme_font_size_override("font_size", CHAT_BUBBLE_FONT_SIZE)
	entry_label.add_theme_constant_override("line_spacing", CHAT_BUBBLE_LINE_SPACING)
	var font := get_chat_font()
	if font != null:
		entry_label.add_theme_font_override("font", font)
	entry_label.add_theme_color_override("font_color", text_color)
	entry_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	entry_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	entry_label.add_theme_constant_override("outline_size", 3)
	entry_label.add_theme_constant_override("shadow_offset_x", 1)
	entry_label.add_theme_constant_override("shadow_offset_y", 1)
	entry_label.modulate = Color.WHITE
	entry_label.self_modulate = Color.WHITE
	return entry_label


func layout_notification_stack() -> void:
	if notification_stack == null or notification_entries.is_empty():
		return

	var label_width_limit := maxf(1.0, CHAT_BUBBLE_MAX_WIDTH - CHAT_BUBBLE_PAD_X * 2.0)
	var font := get_chat_font()
	if font == null and label != null:
		font = label.get_theme_font("font")
	var widest_line := 0.0
	var total_label_height := 0.0

	for entry_index in range(notification_entries.size()):
		var entry: Dictionary = notification_entries[entry_index]
		var wrapped_message := wrap_text_to_width(str(entry.get("message", "")), label_width_limit, font, CHAT_BUBBLE_FONT_SIZE)
		var entry_height := measure_text_block_height(wrapped_message, font, CHAT_BUBBLE_FONT_SIZE)
		entry["wrapped_message"] = wrapped_message
		entry["height"] = entry_height
		notification_entries[entry_index] = entry
		widest_line = maxf(widest_line, get_widest_line_width(wrapped_message, font, CHAT_BUBBLE_FONT_SIZE))
		total_label_height += entry_height

	var stack_gap_height := NOTIFICATION_STACK_GAP * float(maxi(0, notification_entries.size() - 1))
	var clamped_width := clampf(widest_line + CHAT_BUBBLE_PAD_X * 2.0, CHAT_BUBBLE_MIN_WIDTH, CHAT_BUBBLE_MAX_WIDTH)
	var stack_height := total_label_height + stack_gap_height
	var clamped_height := maxf(1.0, stack_height + CHAT_BUBBLE_PAD_Y * 2.0)
	var content_width := maxf(1.0, clamped_width - CHAT_BUBBLE_PAD_X * 2.0)

	size = Vector2(clamped_width, clamped_height)
	background.position = Vector2.ZERO
	background.size = size
	notification_stack.position = Vector2(CHAT_BUBBLE_PAD_X, CHAT_BUBBLE_PAD_Y)
	notification_stack.size = Vector2(content_width, stack_height)

	for entry in notification_entries:
		var entry_label_value: Variant = entry.get("label", null)
		if not (entry_label_value is Label) or not is_instance_valid(entry_label_value):
			continue
		var entry_label := entry_label_value as Label
		var entry_height := float(entry.get("height", get_text_line_height(font, CHAT_BUBBLE_FONT_SIZE)))
		entry_label.text = str(entry.get("wrapped_message", entry.get("message", "")))
		entry_label.custom_minimum_size = Vector2(content_width, entry_height)
		entry_label.size = Vector2(content_width, entry_height)
		entry_label.visible = true

	notification_stack.queue_sort()


func prune_expired_notification_entries(now_msec: int) -> void:
	for entry_index in range(notification_entries.size() - 1, -1, -1):
		var entry: Dictionary = notification_entries[entry_index]
		if int(entry.get("expires_at_msec", 0)) <= now_msec:
			remove_notification_entry_at(entry_index)


func remove_notification_entry_at(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= notification_entries.size():
		return
	var entry: Dictionary = notification_entries[entry_index]
	var entry_label_value: Variant = entry.get("label", null)
	if entry_label_value is Label and is_instance_valid(entry_label_value):
		(entry_label_value as Label).queue_free()
	notification_entries.remove_at(entry_index)


func clear_notification_entries() -> void:
	for entry in notification_entries:
		var entry_label_value: Variant = entry.get("label", null)
		if entry_label_value is Label and is_instance_valid(entry_label_value):
			(entry_label_value as Label).queue_free()
	notification_entries.clear()
	if notification_stack != null:
		notification_stack.visible = false


func schedule_notification_expiry(now_msec: int = -1) -> void:
	if hide_timer == null:
		return
	if notification_entries.is_empty():
		hide_timer.stop()
		return
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	var earliest_expiry := int(notification_entries[0].get("expires_at_msec", now_msec + NOTIFICATION_ENTRY_LIFETIME_MSEC))
	for entry in notification_entries:
		earliest_expiry = mini(earliest_expiry, int(entry.get("expires_at_msec", earliest_expiry)))
	var wait_seconds := maxf(0.01, float(earliest_expiry - now_msec) / 1000.0)
	hide_timer.stop()
	if not is_inside_tree() or not hide_timer.is_inside_tree():
		return
	hide_timer.start(wait_seconds)


func _layout_for_message(clean_message: String) -> String:
	var label_width_limit := maxf(1.0, CHAT_BUBBLE_MAX_WIDTH - CHAT_BUBBLE_PAD_X * 2.0)
	var font := get_chat_font()
	if font == null and label != null:
		font = label.get_theme_font("font")
	var wrapped_message := wrap_text_to_width(clean_message, label_width_limit, font, CHAT_BUBBLE_FONT_SIZE)
	var widest_line := get_widest_line_width(wrapped_message, font, CHAT_BUBBLE_FONT_SIZE)
	var text_height := measure_text_block_height(wrapped_message, font, CHAT_BUBBLE_FONT_SIZE)

	var clamped_width := clampf(widest_line + CHAT_BUBBLE_PAD_X * 2.0, CHAT_BUBBLE_MIN_WIDTH, CHAT_BUBBLE_MAX_WIDTH)
	var clamped_height := maxf(1.0, text_height + CHAT_BUBBLE_PAD_Y * 2.0)

	size = Vector2(clamped_width, clamped_height)
	background.position = Vector2.ZERO
	background.size = size

	label.position = Vector2(CHAT_BUBBLE_PAD_X, CHAT_BUBBLE_PAD_Y)
	var label_width := maxf(1.0, clamped_width - CHAT_BUBBLE_PAD_X * 2.0)
	var label_height := maxf(1.0, clamped_height - CHAT_BUBBLE_PAD_Y * 2.0)
	label.custom_minimum_size = Vector2(label_width, label_height)
	label.size = Vector2(label_width, label_height)
	return wrapped_message


func _on_hide_timer_timeout() -> void:
	if bubble_mode == BUBBLE_MODE_NOTIFICATION:
		var now_msec := Time.get_ticks_msec()
		prune_expired_notification_entries(now_msec)
		if notification_entries.is_empty():
			hide_chat_bubble()
			return
		layout_notification_stack()
		schedule_notification_expiry(now_msec)
		return
	hide_chat_bubble()


func hide_chat_bubble() -> void:
	if hide_timer != null:
		hide_timer.stop()
	clear_notification_entries()
	bubble_mode = BUBBLE_MODE_NONE
	if background != null:
		background.visible = false
	if label != null:
		label.visible = false
	if notification_stack != null:
		notification_stack.visible = false
	visible = false
