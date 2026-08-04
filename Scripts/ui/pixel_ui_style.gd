extends RefCounted

# PixelMania Shared UI Style v2
# Use this file for all future menus so the whole game has one consistent UI language.

const PANEL_DARK := Color(0.050, 0.120, 0.175, 0.50)
const PANEL_DARKER := Color(0.038, 0.082, 0.120, 0.70)
const CARD_BLUE := Color(0.115, 0.230, 0.335, 0.58)
const CARD_BLUE_BRIGHT := Color(0.170, 0.365, 0.540, 0.70)
const BORDER_DARK := Color(0.050, 0.145, 0.245, 0.70)
const BORDER_BLUE := Color(0.180, 0.460, 0.760, 0.76)
const GLASS_PANEL := Color(0.050, 0.120, 0.175, 0.48)
const GLASS_PANEL_STRONG := Color(0.060, 0.135, 0.200, 0.62)
const GLASS_HEADER := Color(0.070, 0.150, 0.235, 0.62)
const GLASS_SECTION := Color(0.820, 0.940, 1.000, 0.105)
const GLASS_INPUT := Color(0.820, 0.940, 1.000, 0.18)
const GLASS_INPUT_FOCUS := Color(0.860, 0.970, 1.000, 0.27)
const GLASS_BORDER := Color(0.180, 0.460, 0.760, 0.72)
const GLASS_BORDER_BRIGHT := Color(0.420, 0.780, 1.000, 0.66)
const ACTION_YELLOW := Color(1.0, 0.84, 0.05, 1.0)
const ACTION_YELLOW_BORDER := Color(0.96, 0.50, 0.02, 1.0)
const ACCENT_CYAN := Color(0.18, 0.84, 1.0, 1.0)
const GOLD_SOFT := Color(1.0, 0.88, 0.25, 1.0)
const OK_GREEN := Color(0.30, 0.95, 0.42, 1.0)
const WARNING_RED := Color(1.0, 0.28, 0.22, 1.0)
const TEXT_LIGHT := Color.WHITE
const TEXT_SOFT := Color(0.86, 0.96, 1.0, 1.0)
const GAME_FONT_PATH := "res://Assets/font/font.ttf"
const DEFAULT_TEXT_FONT_SIZE := 24
const HEADER_FONT_SIZE := 36
const GLOBAL_TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const GLOBAL_TEXT_SHADOW_OFFSET := Vector2(2.0, 2.0)
const GLOBAL_FONT_ROLE_META := &"pixelmania_font_role"
const GLOBAL_FONT_SIZE_META := &"pixelmania_font_size"
const GLOBAL_LABEL_SETTINGS_OWNED_META := &"_pixelmania_global_label_settings_owned"

const HEADER_NAME_MARKERS := [
	"title",
	"header_label",
	"heading",
	"headline",
]

static var game_font: Font = null


static func get_game_font() -> Font:
	if game_font == null and ResourceLoader.exists(GAME_FONT_PATH):
		var loaded_font: Resource = load(GAME_FONT_PATH)
		if loaded_font is Font:
			game_font = loaded_font
	return game_font


static func apply_game_font_to_node(node: Node) -> void:
	if node == null:
		return

	var font := get_game_font()
	if font == null:
		return

	if node.has_method("add_theme_font_override"):
		_add_font_override(node, "font", font)

	if node is RichTextLabel:
		_add_font_override(node, "normal_font", font)
		_add_font_override(node, "bold_font", font)
		_add_font_override(node, "italics_font", font)
		_add_font_override(node, "bold_italics_font", font)
		_add_font_override(node, "mono_font", font)

	if node is Label:
		var label := node as Label
		if label.label_settings != null:
			label.label_settings.font = font

	if node is SpinBox:
		var spin_box := node as SpinBox
		apply_game_font_to_node(spin_box.get_line_edit())

	if node is OptionButton:
		var option_button := node as OptionButton
		apply_game_font_to_node(option_button.get_popup())

	if node is MenuButton:
		var menu_button := node as MenuButton
		apply_game_font_to_node(menu_button.get_popup())


static func apply_global_typography_to_node(node: Node) -> void:
	apply_game_font_to_node(node)
	if not _is_text_control(node):
		return

	var font_size := _resolve_global_font_size(node)
	if font_size > 0:
		_apply_global_font_size(node, font_size)

	_apply_global_text_shadow(node)


static func _is_text_control(node: Node) -> bool:
	return (
		node is Label
		or node is RichTextLabel
		or node is BaseButton
		or node is LineEdit
		or node is TextEdit
		or node is ItemList
		or node is Tree
		or node is PopupMenu
		or node is TabBar
	)


static func _resolve_global_font_size(node: Node) -> int:
	if node.has_meta(GLOBAL_FONT_SIZE_META):
		return maxi(0, int(node.get_meta(GLOBAL_FONT_SIZE_META, DEFAULT_TEXT_FONT_SIZE)))

	var role := str(node.get_meta(GLOBAL_FONT_ROLE_META, "")).strip_edges().to_lower()
	match role:
		"preserve", "custom", "none":
			return 0
		"header", "heading", "headline", "title":
			return HEADER_FONT_SIZE
		"body", "default", "text":
			return DEFAULT_TEXT_FONT_SIZE

	var normalized_name := String(node.name).to_snake_case()
	for marker in HEADER_NAME_MARKERS:
		var marker_text := str(marker)
		if (
			normalized_name == marker_text
			or normalized_name.begins_with(marker_text + "_")
			or normalized_name.ends_with("_" + marker_text)
		):
			return HEADER_FONT_SIZE

	if _get_authored_font_size(node) >= 30:
		return HEADER_FONT_SIZE

	return DEFAULT_TEXT_FONT_SIZE


static func _get_authored_font_size(node: Node) -> int:
	if node is Label:
		var label := node as Label
		if label.label_settings != null and label.label_settings.font_size > 0:
			return label.label_settings.font_size

	if node is RichTextLabel:
		var rich_text := node as RichTextLabel
		if rich_text.has_theme_font_size_override("normal_font_size"):
			return rich_text.get_theme_font_size("normal_font_size")

	if node is Control:
		var control := node as Control
		if control.has_theme_font_size_override("font_size"):
			return control.get_theme_font_size("font_size")

	return 0


static func _apply_global_font_size(node: Node, font_size: int) -> void:
	if node is Control:
		(node as Control).add_theme_font_size_override("font_size", font_size)

	if node is RichTextLabel:
		var rich_text := node as RichTextLabel
		for theme_item in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
			rich_text.add_theme_font_size_override(theme_item, font_size)

	if node is Label:
		var label := node as Label
		if label.label_settings != null:
			var settings := _ensure_owned_label_settings(label)
			if settings != null:
				settings.font_size = font_size


static func _apply_global_text_shadow(node: Node) -> void:
	if node is Control:
		var control := node as Control
		var has_visible_shadow := (
			control.has_theme_color_override("font_shadow_color")
			and control.get_theme_color("font_shadow_color").a > 0.0
		)
		if not has_visible_shadow:
			control.add_theme_color_override("font_shadow_color", GLOBAL_TEXT_SHADOW_COLOR)
			control.add_theme_constant_override("shadow_offset_x", int(GLOBAL_TEXT_SHADOW_OFFSET.x))
			control.add_theme_constant_override("shadow_offset_y", int(GLOBAL_TEXT_SHADOW_OFFSET.y))

	if node is Label:
		var label := node as Label
		if label.label_settings != null:
			var settings := _ensure_owned_label_settings(label)
			if settings != null and settings.shadow_color.a <= 0.0:
				settings.shadow_color = GLOBAL_TEXT_SHADOW_COLOR
				settings.shadow_offset = GLOBAL_TEXT_SHADOW_OFFSET


static func _ensure_owned_label_settings(label: Label) -> LabelSettings:
	if label == null or label.label_settings == null:
		return null

	if not label.has_meta(GLOBAL_LABEL_SETTINGS_OWNED_META):
		label.label_settings = label.label_settings.duplicate() as LabelSettings
		label.set_meta(GLOBAL_LABEL_SETTINGS_OWNED_META, true)
	return label.label_settings


static func _add_font_override(node: Node, theme_item: String, font: Font) -> void:
	if node == null or not node.has_method("add_theme_font_override"):
		return

	node.call("add_theme_font_override", theme_item, font)


static func style_box(fill: Color, border: Color, border_width: int = 4, radius: int = 14, shadow_size: int = 7) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 5)
	return style


static func panel_style() -> StyleBoxFlat:
	return style_box(GLASS_PANEL, GLASS_BORDER, 4, 20, 13)


static func premium_panel_style() -> StyleBoxFlat:
	return style_box(GLASS_PANEL_STRONG, GLASS_BORDER_BRIGHT, 4, 22, 14)


static func header_style() -> StyleBoxFlat:
	return style_box(GLASS_HEADER, GLASS_BORDER, 3, 15, 7)


static func card_style() -> StyleBoxFlat:
	return style_box(CARD_BLUE, GLASS_BORDER, 3, 15, 8)


static func card_style_featured() -> StyleBoxFlat:
	return style_box(CARD_BLUE_BRIGHT, GLASS_BORDER_BRIGHT, 3, 15, 8)


static func section_style() -> StyleBoxFlat:
	return style_box(GLASS_SECTION, GLASS_BORDER, 3, 16, 6)


static func slot_style(rarity: String = "common") -> StyleBoxFlat:
	var color = Color(0.110, 0.225, 0.330, 0.62)
	var border = Color(0.45, 0.82, 0.96, 0.82)

	match rarity:
		"uncommon":
			color = Color(0.060, 0.300, 0.180, 0.62)
			border = Color(0.28, 0.95, 0.45, 0.90)
		"rare":
			color = Color(0.050, 0.185, 0.430, 0.64)
			border = Color(0.22, 0.58, 1.0, 0.92)
		"epic":
			color = Color(0.235, 0.085, 0.405, 0.66)
			border = Color(0.72, 0.35, 1.0, 0.94)
		"legendary":
			color = Color(0.455, 0.270, 0.040, 0.72)
			border = Color(1.0, 0.70, 0.10, 1.0)
		"currency":
			color = Color(0.035, 0.380, 0.450, 0.66)
			border = Color(0.14, 0.95, 1.0, 0.92)
		_:
			color = Color(0.110, 0.225, 0.330, 0.62)
			border = Color(0.45, 0.82, 0.96, 0.82)

	return style_box(color, border, 3, 13, 5)


static func status_badge_style(status: String) -> StyleBoxFlat:
	match status:
		"good":
			return style_box(Color(0.08, 0.42, 0.20, 0.72), Color(0.26, 0.95, 0.42, 0.88), 3, 14, 5)
		"warning":
			return style_box(Color(0.48, 0.28, 0.02, 0.74), Color(1.0, 0.76, 0.12, 0.90), 3, 14, 5)
		"danger":
			return style_box(Color(0.45, 0.07, 0.06, 0.76), Color(1.0, 0.28, 0.22, 0.92), 3, 14, 5)
		_:
			return style_box(Color(0.12, 0.26, 0.36, 0.62), Color(0.42, 0.78, 1.0, 0.82), 3, 14, 5)


static func input_style() -> StyleBoxFlat:
	return style_box(GLASS_INPUT, GLASS_BORDER, 3, 10, 4)


static func input_focus_style() -> StyleBoxFlat:
	return style_box(GLASS_INPUT_FOCUS, Color(0.85, 0.96, 1.0, 0.94), 3, 10, 6)


static func apply_label_shadow(label: Label, font_size: int = DEFAULT_TEXT_FONT_SIZE, color: Color = TEXT_LIGHT) -> void:
	if label == null:
		return

	label.add_theme_font_size_override("font_size", font_size)
	apply_game_font_to_node(label)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func apply_small_label(label: Label, font_size: int = 13) -> void:
	apply_label_shadow(label, font_size, TEXT_SOFT)


static func apply_section_title(label: Label, font_size: int = HEADER_FONT_SIZE) -> void:
	apply_label_shadow(label, font_size, GOLD_SOFT)


static func apply_button_text(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE, color: Color = TEXT_LIGHT) -> void:
	if button == null:
		return

	button.add_theme_font_size_override("font_size", font_size)
	apply_game_font_to_node(button)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_color_override("font_disabled_color", Color(0.68, 0.74, 0.80, 0.70))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.focus_mode = Control.FOCUS_NONE


static func apply_blue_button(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if button == null:
		return

	apply_button_text(button, font_size, TEXT_LIGHT)
	button.add_theme_stylebox_override("normal", style_box(Color(0.10, 0.24, 0.34, 0.58), Color(0.42, 0.78, 1.0, 0.42), 3, 12, 5))
	button.add_theme_stylebox_override("hover", style_box(Color(0.16, 0.34, 0.46, 0.74), Color(0.62, 0.92, 1.0, 0.76), 3, 12, 6))
	button.add_theme_stylebox_override("pressed", style_box(Color(0.07, 0.18, 0.27, 0.78), Color(0.20, 0.52, 0.86, 0.84), 3, 12, 4))
	button.add_theme_stylebox_override("disabled", style_box(Color(0.08, 0.12, 0.17, 0.42), Color(0.18, 0.28, 0.40, 0.26), 3, 12, 3))


static func apply_yellow_button(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if button == null:
		return

	apply_button_text(button, font_size, TEXT_LIGHT)
	button.add_theme_stylebox_override("normal", style_box(ACTION_YELLOW, ACTION_YELLOW_BORDER, 5, 12, 6))
	button.add_theme_stylebox_override("hover", style_box(Color(1.0, 0.94, 0.20, 1.0), ACTION_YELLOW_BORDER, 5, 12, 6))
	button.add_theme_stylebox_override("pressed", style_box(Color(0.90, 0.58, 0.02, 1.0), Color(0.60, 0.28, 0.01, 1.0), 5, 12, 6))
	button.add_theme_stylebox_override("disabled", style_box(Color(0.23, 0.20, 0.14, 0.88), Color(0.11, 0.08, 0.03, 1.0), 4, 12, 4))


static func apply_green_button(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if button == null:
		return

	apply_button_text(button, font_size, TEXT_LIGHT)
	button.add_theme_stylebox_override("normal", style_box(Color(0.18, 0.70, 0.24, 0.98), Color(0.05, 0.30, 0.06, 1.0), 4, 12, 5))
	button.add_theme_stylebox_override("hover", style_box(Color(0.28, 0.88, 0.34, 0.98), Color(0.05, 0.30, 0.06, 1.0), 4, 12, 5))
	button.add_theme_stylebox_override("pressed", style_box(Color(0.10, 0.48, 0.16, 0.98), Color(0.02, 0.16, 0.04, 1.0), 4, 12, 5))
	button.add_theme_stylebox_override("disabled", style_box(Color(0.10, 0.15, 0.12, 0.86), Color(0.03, 0.06, 0.03, 1.0), 4, 12, 4))


static func apply_tab_button(button: Button, selected: bool, font_size: int = 15) -> void:
	if selected:
		apply_yellow_button(button, font_size)
	else:
		apply_blue_button(button, font_size)


static func apply_close_button(button: Button) -> void:
	if button == null:
		return

	apply_button_text(button, 20, TEXT_LIGHT)
	button.text = "X"
	button.add_theme_stylebox_override("normal", style_box(Color(0.64, 0.08, 0.08, 0.98), Color(0.20, 0.01, 0.01, 1.0), 4, 10, 5))
	button.add_theme_stylebox_override("hover", style_box(Color(0.82, 0.12, 0.12, 0.98), Color(0.20, 0.01, 0.01, 1.0), 4, 10, 5))
	button.add_theme_stylebox_override("pressed", style_box(Color(0.45, 0.04, 0.04, 0.98), Color(0.12, 0.0, 0.0, 1.0), 4, 10, 5))


static func play_panel_open(panel: Control, start_scale: Vector2 = Vector2(0.96, 0.96), duration: float = 0.16) -> void:
	if panel == null:
		return

	panel.pivot_offset = panel.size * 0.5
	panel.scale = start_scale
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), min(duration, 0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func apply_input(line_edit: LineEdit, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if line_edit == null:
		return

	line_edit.add_theme_font_size_override("font_size", font_size)
	apply_game_font_to_node(line_edit)
	line_edit.add_theme_stylebox_override("normal", input_style())
	line_edit.add_theme_stylebox_override("focus", input_focus_style())
	line_edit.add_theme_color_override("font_color", TEXT_LIGHT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.76, 0.90, 1.0, 0.74))
	line_edit.add_theme_color_override("caret_color", GOLD_SOFT)
	line_edit.add_theme_color_override("selection_color", Color(0.20, 0.48, 0.82, 0.58))
