extends Node

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")
const Database = preload("res://Scripts/item_database.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
const Loot = preload("res://Scripts/ui/shop_pack_loot_data.gd")

var shop: Control
var info_button: Button
var overlay: Control
var panel: Panel
var title: Label
var summary: Label
var rows: VBoxContainer
var scroll: ScrollContainer
var packs: Dictionary = {}
var selected_pack := ""
var icon_spacer: Control
var base_spacer_height := 0.0
var base_icon_bottom := 0.0

func setup(owner_shop: Control) -> void:
	shop = owner_shop
	packs = Loot.PACKS
	info_button = Button.new()
	info_button.name = "DetailInfoButton"
	info_button.text = "INFO"
	info_button.z_index = 1
	info_button.custom_minimum_size.y = 44
	Style.apply_blue_button(info_button, 18)
	var column: VBoxContainer = shop.detail_buy_button.get_parent()
	column.add_child(info_button)
	column.move_child(info_button, shop.detail_buy_button.get_index())
	info_button.hide()
	info_button.pressed.connect(open)
	icon_spacer = column.get_node("DetailIconSpacer")
	base_spacer_height = icon_spacer.custom_minimum_size.y
	base_icon_bottom = shop.detail_icon.offset_bottom
	_build_panel()
	shop.resized.connect(_fit)
	shop.visibility_changed.connect(func():
		if not shop.is_visible_in_tree():
			close())

func show_for_item(item_id: String, is_gem_pack: bool) -> void:
	close()
	selected_pack = item_id if not is_gem_pack and packs.has(item_id) else ""
	info_button.visible = not selected_pack.is_empty()
	var reserved := 0.0 # Detail panel reserves space for the optional INFO action.
	icon_spacer.custom_minimum_size.y = base_spacer_height - reserved
	shop.detail_icon.offset_bottom = base_icon_bottom - reserved

func _label(text: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Style.get_pixel_game_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f6e8fa"))
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("outline_size", 0)
	label.set_meta("pixelmania_text_shadow", false)
	label.set_meta("pixelmania_font_role", "preserve")
	return label

func _build_panel() -> void:
	overlay = Control.new()
	overlay.name = "PackInfoOverlay"
	overlay.set_meta("pixelmania_text_shadow", false)
	overlay.z_index = 280
	shop.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.05, 0.82)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	# Keep temporary wrapped-text minimums from stretching the window on first open.
	# The content lays itself out inside the viewport-sized panel instead.
	panel = Panel.new()
	panel.name = "PackInfoPanel"
	overlay.set_meta("popup_window_path", NodePath("PackInfoPanel"))
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	title = _label("PACK CONTENTS", 40)
	title.add_theme_color_override("font_color", Color("321b3c"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var dismiss := Button.new()
	dismiss.custom_minimum_size = Vector2(44, 44)
	Style.apply_close_button(dismiss)
	dismiss.pressed.connect(close)
	header.add_child(dismiss)
	summary = _label("")
	summary.add_theme_color_override("font_color", Color("321b3c"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var heading := _label("Chances per draw.", 16)
	heading.add_theme_color_override("font_color", Color("321b3c"))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	close()

static func format_chance(chance: float) -> String:
	return ("%.2f" % (chance * 100.0)).trim_suffix("0").trim_suffix("0").trim_suffix(".") + "%"

func open() -> void:
	if not packs.has(selected_pack):
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var pack: Dictionary = packs[selected_pack]
	title.text = str(Database.ITEMS.get(selected_pack, {}).get("display_name", selected_pack))
	var draws := int(pack.get("draws", 1))
	summary.text = "Get 1 random item." if draws == 1 else "Get %d random items." % draws
	for reward in pack.get("rewards", []):
		var definition: Dictionary = Database.ITEMS.get(str(reward.item_id), {})
		var card := PanelContainer.new()
		var background := StyleBoxFlat.new()
		background.bg_color = Color("321b3c")
		background.content_margin_left = 10
		background.content_margin_right = 10
		background.content_margin_top = 6
		background.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", background)
		rows.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = Factory.load_texture(definition.get("inventory_icon", definition.get("texture", "")))
		row.add_child(icon)
		var item_name := _label(str(definition.get("display_name", reward.item_id)))
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(item_name)
		var chance := _label(format_chance(float(reward.chance)))
		chance.custom_minimum_size.x = 76
		chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chance.add_theme_color_override("font_color", Color("ffdf78"))
		row.add_child(chance)
	scroll.scroll_vertical = 0
	overlay.show()
	_fit()

func _fit() -> void:
	if panel == null:
		return
	panel.size = Vector2(minf(580, maxf(260, shop.size.x - 24)), minf(560, maxf(220, shop.size.y - 24)))
	panel.position = (shop.size - panel.size) * 0.5

func close() -> void:
	if overlay != null:
		overlay.hide()

func is_open() -> bool:
	return overlay != null and overlay.visible
