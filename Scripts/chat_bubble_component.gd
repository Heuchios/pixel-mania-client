extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const CHAT_BUBBLE_TIME := 4.0
const CHAT_BUBBLE_ANCHOR_OFFSET_WORLD_PX := 96.0
const CHAT_BUBBLE_MIN_WIDTH := 86.0
const CHAT_BUBBLE_MAX_WIDTH := 260.0
const CHAT_BUBBLE_PAD_X := 14.0
const CHAT_BUBBLE_PAD_Y := 8.0
const CHAT_BUBBLE_FONT_SIZE := 16
const CHAT_BUBBLE_FONT_HEIGHT := 22.0

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
var hide_timer: Timer = null
var label_settings: LabelSettings = null


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
		background.add_theme_stylebox_override(
			"panel",
			PixelUIStyle.style_box(
				Color(0.04, 0.08, 0.14, 0.62),
				Color(0.55, 0.80, 1.0, 0.78),
				2,
				14,
				0
			)
		)
		add_child(background)

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
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
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

	if hide_timer == null:
		hide_timer = Timer.new()
		hide_timer.name = "HideTimer"
		hide_timer.one_shot = true
		hide_timer.timeout.connect(_on_hide_timer_timeout)
		add_child(hide_timer)


func _apply_label_settings():
	if label == null:
		return

	if label_settings == null:
		label_settings = LabelSettings.new()

	label_settings.font_size = CHAT_BUBBLE_FONT_SIZE
	label_settings.font_color = Color.WHITE
	label_settings.outline_size = 3
	label_settings.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	label_settings.shadow_size = 1
	label_settings.shadow_color = Color(0.0, 0.0, 0.0, 1.0)
	label_settings.shadow_offset = Vector2(1.0, 1.0)
	label.label_settings = label_settings


func show_chat_message(message: String):
	_configure_root()
	if background == null or label == null:
		_build_bubble_ui()

	var clean_message = str(message).strip_edges()
	if clean_message == "":
		return

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


func _layout_for_message(clean_message: String) -> String:
	var label_width_limit = max(1.0, CHAT_BUBBLE_MAX_WIDTH - CHAT_BUBBLE_PAD_X * 2.0)
	var font = label.get_theme_font("font") if label != null else null
	var wrapped_message = wrap_text_to_width(clean_message, label_width_limit, font, CHAT_BUBBLE_FONT_SIZE)
	var line_count = count_wrapped_lines(wrapped_message)
	var widest_line = get_widest_line_width(wrapped_message, font, CHAT_BUBBLE_FONT_SIZE)

	var clamped_width = clamp(widest_line + CHAT_BUBBLE_PAD_X * 2.0, CHAT_BUBBLE_MIN_WIDTH, CHAT_BUBBLE_MAX_WIDTH)
	var clamped_height = max(1.0, float(line_count) * CHAT_BUBBLE_FONT_HEIGHT + CHAT_BUBBLE_PAD_Y * 2.0)

	size = Vector2(clamped_width, clamped_height)
	background.position = Vector2.ZERO
	background.size = size

	label.position = Vector2(CHAT_BUBBLE_PAD_X, CHAT_BUBBLE_PAD_Y)
	var label_width = max(1.0, clamped_width - CHAT_BUBBLE_PAD_X * 2.0)
	var label_height = max(1.0, clamped_height - CHAT_BUBBLE_PAD_Y * 2.0)
	label.size = Vector2(label_width, label_height)
	return wrapped_message


func _on_hide_timer_timeout() -> void:
	hide_chat_bubble()


func hide_chat_bubble():
	background.visible = false
	label.visible = false
	visible = false
