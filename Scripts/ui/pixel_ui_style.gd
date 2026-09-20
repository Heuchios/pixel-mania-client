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
	"title_label",
	"header",
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
	_apply_pink_button_text(node)


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
	if node.has_meta("pixelmania_font_size"):
		return int(node.get_meta("pixelmania_font_size"))
	var role := str(node.get_meta(GLOBAL_FONT_ROLE_META, "")).strip_edges().to_lower()
	match role:
		"icon":
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
	var ancestor := node
	while ancestor != null:
		if ancestor.has_meta("pixelmania_text_shadow"):
			if not bool(ancestor.get_meta("pixelmania_text_shadow")) and node is Control:
				var text_control := node as Control
				text_control.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
				text_control.add_theme_constant_override("shadow_offset_x", 0)
				text_control.add_theme_constant_override("shadow_offset_y", 0)
				text_control.add_theme_constant_override("outline_size", 0)
				return
			break
		ancestor = ancestor.get_parent()
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


static func style_box(fill: Color, border: Color, border_width: int = 4, radius: int = 14, shadow_size: int = 7) -> StyleBox:
	# Compatibility for runtime-built dialogs: visible chrome uses the atlas.
	# Transparent shadows/outlines remain flat effects.
	if fill.a > 0.0:
		var region := "inner_panel"
		if fill.r > fill.g * 1.8 and fill.r > fill.b * 1.8:
			region = "red_button"
		elif fill.g > fill.r * 1.8 and fill.g > fill.b * 1.8:
			region = "green_button"
		return atlas_style(region, Color(1, 1, 1, fill.a), float(border_width))
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 5)
	return style


static func panel_style() -> StyleBoxTexture:
	return atlas_style("outer_panel", Color.WHITE, 4)

static func premium_panel_style() -> StyleBoxTexture:
	return atlas_style("outer_panel", Color.WHITE, 4)

static func header_style() -> StyleBoxTexture:
	return atlas_style("inner_panel", Color.WHITE, 3)

static func card_style() -> StyleBoxTexture:
	return atlas_style("inner_panel", Color.WHITE, 3)

static func card_style_featured() -> StyleBoxTexture:
	return atlas_style("inner_panel", Color.WHITE, 3)

static func section_style() -> StyleBoxTexture:
	return atlas_style("inner_panel", Color.WHITE, 3)

static func slot_style(rarity: String = "common") -> StyleBoxTexture:
	return atlas_style("inv_slot_normal", UIAtlasDB.slot_tint("slot_%s.png" % rarity), 3)

static func status_badge_style(status: String) -> StyleBoxTexture:
	var region := "blue_button"
	match status:
		"good": region = "green_button"
		"warning": region = "pink_button"
		"danger": region = "red_button"
	return atlas_style(region, Color.WHITE, 3)

static func input_style() -> StyleBoxTexture:
	return atlas_style("input_field", Color.WHITE, 3)

static func input_focus_style() -> StyleBoxTexture:
	return atlas_style("input_field", Color(1.3, 1.3, 1.3), 3)

# Legacy size arguments are retained for callers; global typography selects the size.
static func apply_label_shadow(label: Label, _font_size: int = DEFAULT_TEXT_FONT_SIZE, color: Color = TEXT_LIGHT) -> void:
	if label == null:
		return

	label.add_theme_font_size_override("font_size", _resolve_global_font_size(label))
	apply_game_font_to_node(label)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func apply_small_label(label: Label, font_size: int = 13) -> void:
	apply_label_shadow(label, font_size, TEXT_SOFT)


static func apply_section_title(label: Label, font_size: int = HEADER_FONT_SIZE) -> void:
	if label != null:
		label.set_meta(GLOBAL_FONT_ROLE_META, "header")
	apply_label_shadow(label, font_size, GOLD_SOFT)


static func apply_button_text(button: Button, _font_size: int = DEFAULT_TEXT_FONT_SIZE, color: Color = TEXT_LIGHT) -> void:
	if button == null:
		return

	button.add_theme_font_size_override("font_size", DEFAULT_TEXT_FONT_SIZE)
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
	apply_atlas_button(button, "blue_button")

static func apply_yellow_button(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if button == null:
		return
	apply_button_text(button, font_size, TEXT_LIGHT)
	apply_atlas_button(button, "pink_button")

static func apply_green_button(button: Button, font_size: int = DEFAULT_TEXT_FONT_SIZE) -> void:
	if button == null:
		return
	apply_button_text(button, font_size, TEXT_LIGHT)
	apply_atlas_button(button, "green_button")

static func apply_tab_button(button: Button, selected: bool, font_size: int = 15) -> void:
	if button == null:
		return
	apply_yellow_button(button, font_size)
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	_apply_category_selection_style(button)


static func apply_close_button(button: Button) -> void:
	if button == null:
		return
	apply_button_text(button, 20, TEXT_LIGHT)
	button.text = ""
	button.icon = UIAtlasDB.get_texture("close_button")
	button.set_meta("standard_close_button", true)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.expand_icon = true
	apply_atlas_button(button, "red_button")
	button.add_theme_constant_override("icon_max_width", 32)
	button.custom_minimum_size = Vector2(48, 48)
	button.custom_maximum_size = Vector2(48, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if button.get_meta("close_button_align_top", false):
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = "Close"


static func apply_ui_chrome_to_node(node: Node) -> void:
	_apply_window_shadow(node)
	_apply_pink_button_text(node)
	_apply_category_selection_style(node)
	if node is Button and ("close" in String(node.name).to_lower() or node.get_meta("standard_close_button", false) or node.text.strip_edges() in ["X", "×", "✕", "Close", "CLOSE"]):
		apply_close_button(node)
		var parent := node.get_parent() as Control
		if parent != null and not parent is Container and not "close" in String(parent.name).to_lower():
			var bounds := Rect2(Vector2.ZERO, parent.size)
			for child in parent.get_children():
				if child is NinePatchRect and child.texture != null and child.texture.get_meta("atlas_region", "") == "outer_panel":
					bounds = child.get_rect()
					break
			node.set_anchors_preset(Control.PRESET_TOP_LEFT)
			node.size = Vector2(48, 48)
			node.position = Vector2(bounds.end.x - 64, bounds.position.y + 16)
	elif node is VScrollBar:
		node.custom_minimum_size.x = 12
		if not node.get_parent() is Container:
			node.anchor_right = node.anchor_left
			node.offset_right = node.offset_left + 12
		node.add_theme_stylebox_override("scroll", atlas_style("scroll_bar", Color.WHITE, 0))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var thumb := atlas_style("scroll_handle", Color.WHITE, 0)
			thumb.expand_margin_left = -2
			thumb.expand_margin_right = -2
			node.add_theme_stylebox_override(state, thumb)
	elif node is NinePatchRect and node.texture != null:
		var region: String = node.texture.get_meta("atlas_region", "")
		if region in ["scroll_bar", "scroll_handle"]:
			node.anchor_right = node.anchor_left
			node.offset_left = 0 if region == "scroll_bar" else 2
			node.offset_right = 12 if region == "scroll_bar" else 10

static func _apply_category_selection_style(node: Node) -> void:
	if not node is Button or not node.toggle_mode or node is CheckBox or node is CheckButton:
		return
	if node.get_meta("preserve_selected_style", false):
		return
	var normal := node.get_theme_stylebox("normal") as StyleBoxTexture
	if normal == null or normal.get_meta("atlas_region", "") not in ["pink_button", "blue_button", "green_button", "red_button"]:
		return
	# Derive from the unselected skin, never from a previously darkened state.
	var selected := normal.duplicate() as StyleBoxTexture
	selected.modulate_color = normal.modulate_color * Color(0.84, 0.84, 0.84, 1)
	var selected_hover := normal.duplicate() as StyleBoxTexture
	selected_hover.modulate_color = normal.modulate_color * Color(0.88, 0.88, 0.88, 1)
	node.add_theme_stylebox_override("pressed", selected)
	node.add_theme_stylebox_override("hover_pressed", selected_hover)


static func _apply_pink_button_text(node: Node) -> void:
	var button := node as Button
	if node is Label:
		var ancestor := node.get_parent()
		while ancestor != null and not ancestor is Button:
			ancestor = ancestor.get_parent()
		button = ancestor as Button
	if button == null:
		return
	var style := button.get_theme_stylebox("normal")
	if style.get_meta("atlas_region", "") != "pink_button":
		return
	var ink := Color(0.16, 0.06, 0.2)
	node.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	if node is Button:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			if node.get_meta("preserve_selected_style", false) and state in ["font_pressed_color", "font_hover_pressed_color"]:
				continue
			node.add_theme_color_override(state, ink)
	elif node is Label:
		node.add_theme_color_override("font_color", ink)
		if node.label_settings != null:
			var settings := _ensure_owned_label_settings(node as Label)
			settings.font_color = ink
			settings.shadow_color = Color.TRANSPARENT
			settings.shadow_offset = Vector2.ZERO


static func _apply_window_shadow(node: Node) -> void:
	if not node is Control:
		return
	if node.is_queued_for_deletion() or node.get_parent() == null:
		return
	var region := ""
	if node is Panel or node is PanelContainer:
		region = node.get_theme_stylebox("panel").get_meta("atlas_region", "")
	elif node is NinePatchRect or node is TextureRect:
		if node.texture != null:
			region = node.texture.get_meta("atlas_region", "")
	if region != "outer_panel":
		return
	# Authored windows may already have a sibling shadow behind their background.
	var existing := node.get_parent().get_node_or_null("DropShadow")
	if existing is CanvasItem:
		existing.self_modulate = Color(1, 1, 1, 0.4)
		return
	if node.has_node("WindowDropShadow"):
		return
	var shadow = preload("res://Scripts/ui/panel_drop_shadow.gd").new()
	shadow.name = "WindowDropShadow"
	node.add_child(shadow)


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


## Duplicate shared styles before changing state or content padding.
static func atlas_style(region: String, tint: Color = Color.WHITE, padding: float = 3.0) -> StyleBoxTexture:
	var style := UIAtlasDB.get_stylebox(region).duplicate() as StyleBoxTexture
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


static func apply_atlas_button(button: Button, region: String = "blue_button") -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var text_color := Color(0.16, 0.06, 0.2) if region == "pink_button" else TEXT_LIGHT
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_stylebox_override("normal", atlas_style(region))
	button.add_theme_stylebox_override("hover", atlas_style(region, Color(1.15, 1.15, 1.15)))
	button.add_theme_stylebox_override("pressed", atlas_style(region, Color(0.72, 0.72, 0.72)))
	button.add_theme_stylebox_override("disabled", atlas_style(region, Color(0.55, 0.55, 0.55, 0.7)))
	var focus := atlas_style("inner_panel", Color(1.6, 1.6, 1.6))
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
