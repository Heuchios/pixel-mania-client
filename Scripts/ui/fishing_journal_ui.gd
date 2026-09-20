extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const PANEL_W := 960.0
const PANEL_H := 704.0
const CARD_W := 288.0
const CARD_H := 212.0
const RARITY_TABS := ["all", "common", "uncommon", "rare", "epic", "legendary"]

var world = null
var panel: Panel = null
var title_label: Label = null
var completion_label: Label = null
var stats_label: Label = null
var rarest_label: Label = null
var tab_root: HBoxContainer = null
var cards_scroll: ScrollContainer = null
var cards_root: GridContainer = null
var empty_label: Label = null
var selected_rarity := "all"
var tab_buttons: Dictionary = {}


func setup(world_ref) -> void:
	world = world_ref
	name = "FishingJournalUI"
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 260
	visible = false
	size = get_viewport_rect().size
	set_process(true)
	_build_ui()


func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	if visible and panel != null:
		_position_panel()


func open_journal() -> void:
	if panel == null:
		_build_ui()
	refresh()
	visible = true
	_position_panel()
	# Keep the viewport-fit scale when opening on smaller screens.


func close_journal() -> void:
	visible = false


func refresh() -> void:
	if world == null or world.fishing_manager == null:
		return
	if not world.fishing_manager.has_method("get_fishing_journal_summary"):
		return

	var summary_value = world.fishing_manager.get_fishing_journal_summary()
	var entries_value = world.fishing_manager.get_fishing_journal_entries(selected_rarity)
	var summary: Dictionary = (summary_value as Dictionary) if summary_value is Dictionary else {}
	var entries: Array = (entries_value as Array) if entries_value is Array else []

	completion_label.text = "Completion: " + str(int(summary.get("completion_percent", 0))) + "%  (" + str(int(summary.get("discovered_count", 0))) + "/" + str(int(summary.get("total_species", 0))) + ")"
	stats_label.text = "Level " + str(int(summary.get("fishing_level", 1))) + "  |  XP " + str(int(summary.get("total_fishing_xp", 0))) + "  |  Total caught " + str(int(summary.get("total_fish_caught", 0)))

	var rarest_value = summary.get("rarest_catch", {})
	var rarest: Dictionary = (rarest_value as Dictionary) if rarest_value is Dictionary else {}
	if rarest.is_empty():
		rarest_label.text = "Rarest catch: None yet"
	else:
		rarest_label.text = "Rarest catch: " + str(rarest.get("name", "Unknown")) + "  |  " + str(rarest.get("rarity", "common")).capitalize() + "  |  " + _format_weight(float(rarest.get("weight", 0.0)))

	_update_tab_styles()
	_clear_cards()

	empty_label.visible = entries.is_empty()
	for entry_value in entries:
		if entry_value is Dictionary:
			_create_fish_card(entry_value as Dictionary)


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	panel = Panel.new()
	panel.name = "JournalPanel"
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	add_child(panel)
	var inner := Panel.new()
	inner.name = "InnerPanel"
	inner.position = Vector2(16, 78)
	inner.size = Vector2(PANEL_W - 32, PANEL_H - 94)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(inner)

	var header: Panel = Panel.new()
	header.name = "Header"
	header.position = Vector2(16, 16)
	header.size = Vector2(PANEL_W - 32, 54)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", PixelUIStyle.header_style())
	panel.add_child(header)

	title_label = Label.new()
	title_label.text = "FISHING JOURNAL"
	title_label.position = Vector2(30, 22)
	title_label.size = Vector2(430, 42)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(title_label, 32, PixelUIStyle.GOLD_SOFT)
	_preserve_text(title_label, 32)
	panel.add_child(title_label)

	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.position = Vector2(PANEL_W - 62.0, 18)
	close_button.size = Vector2(42, 42)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_journal)
	panel.add_child(close_button)

	completion_label = Label.new()
	completion_label.position = Vector2(30, 88)
	completion_label.size = Vector2(360, 26)
	completion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(completion_label, 18, PixelUIStyle.TEXT_LIGHT)
	_preserve_text(completion_label, 18)
	panel.add_child(completion_label)

	stats_label = Label.new()
	stats_label.position = Vector2(30, 116)
	stats_label.size = Vector2(PANEL_W - 60, 24)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(stats_label, 15)
	_preserve_text(stats_label, 15)
	panel.add_child(stats_label)

	rarest_label = Label.new()
	rarest_label.position = Vector2(30, 142)
	rarest_label.size = Vector2(PANEL_W - 60.0, 24)
	rarest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(rarest_label, 15)
	_preserve_text(rarest_label, 15)
	panel.add_child(rarest_label)

	tab_root = HBoxContainer.new()
	tab_root.name = "RarityTabs"
	tab_root.position = Vector2(30, 178)
	tab_root.size = Vector2(PANEL_W - 60.0, 42)
	tab_root.add_theme_constant_override("separation", 8)
	panel.add_child(tab_root)

	tab_buttons.clear()
	for rarity in RARITY_TABS:
		var button: Button = Button.new()
		button.text = "ALL" if rarity == "all" else rarity.to_upper()
		button.custom_minimum_size = Vector2(142, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_tab_pressed.bind(rarity))
		tab_root.add_child(button)
		tab_buttons[rarity] = button

	cards_scroll = ScrollContainer.new()
	cards_scroll.name = "CardsScroll"
	cards_scroll.position = Vector2(28, 234)
	cards_scroll.size = Vector2(PANEL_W - 56.0, PANEL_H - 262.0)
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(cards_scroll)

	cards_root = GridContainer.new()
	cards_root.name = "CardsRoot"
	cards_root.columns = 3
	cards_root.custom_minimum_size = Vector2(PANEL_W - 84.0, PANEL_H - 284.0)
	cards_root.add_theme_constant_override("h_separation", 12)
	cards_root.add_theme_constant_override("v_separation", 12)
	cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_scroll.add_child(cards_root)

	empty_label = Label.new()
	empty_label.text = "No fish in this tab yet."
	empty_label.position = Vector2(0, 80)
	empty_label.size = Vector2(PANEL_W - 84.0, 36)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(empty_label, 18)
	_preserve_text(empty_label, 18)
	cards_root.add_child(empty_label)

	_update_tab_styles()
	_position_panel()


func _position_panel() -> void:
	var ss := get_viewport_rect().size
	var fit := minf(1.0, minf((ss.x - 24) / PANEL_W, (ss.y - 32) / PANEL_H))
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	panel.position = (ss - panel.size * panel.scale) * 0.5


func _on_tab_pressed(rarity: String) -> void:
	selected_rarity = rarity
	cards_scroll.scroll_vertical = 0
	refresh()


func _update_tab_styles() -> void:
	for rarity in tab_buttons.keys():
		var button: Button = tab_buttons[rarity] as Button
		if button == null:
			continue
		PixelUIStyle.apply_atlas_button(button, "green_button" if str(rarity) == selected_rarity else "pink_button")
		_preserve_text(button, 15)


func _clear_cards() -> void:
	if cards_root == null:
		return
	for child in cards_root.get_children():
		cards_root.remove_child(child)
		child.queue_free()

	empty_label = Label.new()
	empty_label.text = "No fish in this tab yet."
	empty_label.custom_minimum_size = Vector2(PANEL_W - 84.0, 36)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(empty_label, 18)
	_preserve_text(empty_label, 18)
	cards_root.add_child(empty_label)


func _create_fish_card(entry: Dictionary) -> void:
	var discovered: bool = bool(entry.get("discovered", false))
	var rarity: String = str(entry.get("rarity", "common")).to_lower()
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("outer_panel", Color.WHITE if discovered else Color(0.72, 0.72, 0.72, 1), 3))
	cards_root.add_child(card)
	var card_inner := Panel.new()
	card_inner.name = "CardInner"
	card_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_inner)
	card_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_inner.offset_left = 5
	card_inner.offset_top = 5
	card_inner.offset_right = -5
	card_inner.offset_bottom = -5
	card_inner.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("inner_panel", Color.WHITE if discovered else Color(0.78, 0.78, 0.78, 1), 3))

	var icon_back: Panel = Panel.new()
	icon_back.position = Vector2(18, 18)
	icon_back.size = Vector2(64, 64)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.card_style())
	card.add_child(icon_back)

	var icon: TextureRect = TextureRect.new()
	icon.position = Vector2(24, 24)
	icon.size = Vector2(52, 52)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon_value = entry.get("icon", null)
	icon.texture = (icon_value as Texture2D) if icon_value is Texture2D else null
	if icon.texture != null:
		var image := icon.texture.get_image()
		if image != null and image.get_used_rect().has_area():
			var artwork := AtlasTexture.new()
			artwork.atlas = icon.texture
			artwork.region = Rect2(image.get_used_rect())
			artwork.filter_clip = true
			icon.texture = artwork
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if discovered else Color(0.0, 0.0, 0.0, 0.72)
	card.add_child(icon)

	var lock_label: Label = Label.new()
	lock_label.text = "?"
	lock_label.position = Vector2(24, 22)
	lock_label.size = Vector2(52, 52)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.visible = not discovered
	PixelUIStyle.apply_label_shadow(lock_label, 28, PixelUIStyle.TEXT_SOFT)
	_preserve_text(lock_label, 28)
	card.add_child(lock_label)

	var name_label: Label = Label.new()
	name_label.text = str(entry.get("name", "Fish")) if discovered else "Unknown Fish"
	name_label.position = Vector2(92, 20)
	name_label.size = Vector2(CARD_W - 106.0, 48)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.tooltip_text = name_label.text
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	PixelUIStyle.apply_label_shadow(name_label, 16, PixelUIStyle.TEXT_LIGHT)
	_preserve_text(name_label, 16)
	card.add_child(name_label)

	var rarity_label: Label = Label.new()
	rarity_label.text = rarity.capitalize() if discovered else "Locked"
	rarity_label.position = Vector2(92, 70)
	rarity_label.size = Vector2(CARD_W - 106.0, 24)
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(rarity_label, 13)
	_preserve_text(rarity_label, 13)
	rarity_label.add_theme_color_override("font_color", _rarity_color(rarity) if discovered else Color(0.62, 0.72, 0.78, 1.0))
	card.add_child(rarity_label)

	var location_label: Label = Label.new()
	location_label.text = str(entry.get("location", "Any Water")) if discovered else "???"
	location_label.position = Vector2(18, 106)
	location_label.size = Vector2(CARD_W - 36.0, 22)
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_small_label(location_label, 12)
	_preserve_text(location_label, 12)
	card.add_child(location_label)

	var total_label: Label = Label.new()
	total_label.text = "Caught: " + str(int(entry.get("total_caught", 0))) if discovered else "Caught: --"
	total_label.position = Vector2(18, 130)
	total_label.size = Vector2(CARD_W - 36.0, 20)
	PixelUIStyle.apply_small_label(total_label, 12)
	_preserve_text(total_label, 12)
	card.add_child(total_label)

	var weight_label: Label = Label.new()
	weight_label.text = "Biggest: " + _format_weight(float(entry.get("biggest_weight", 0.0))) if discovered else "Biggest: --"
	weight_label.position = Vector2(18, 152)
	weight_label.size = Vector2(CARD_W - 36.0, 20)
	PixelUIStyle.apply_small_label(weight_label, 12)
	_preserve_text(weight_label, 12)
	card.add_child(weight_label)

	var value_label: Label = Label.new()
	value_label.text = "Best value: " + str(int(entry.get("best_value", 0))) + " gems" if discovered else "Best value: --"
	value_label.position = Vector2(18, 174)
	value_label.size = Vector2(CARD_W - 36.0, 20)
	PixelUIStyle.apply_small_label(value_label, 12)
	_preserve_text(value_label, 12)
	card.add_child(value_label)


func _format_weight(weight: float) -> String:
	if weight <= 0.0:
		return "--"
	return str(snapped(weight, 0.1)) + " lb"


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.28, 0.95, 0.45, 1.0)
		"rare":
			return Color(0.28, 0.55, 1.0, 1.0)
		"epic":
			return Color(0.72, 0.30, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.66, 0.12, 1.0)
		_:
			return Color(0.78, 0.90, 0.96, 1.0)


func _preserve_text(control: Control, font_size: int) -> void:
	control.set_meta("pixelmania_font_role", "preserve")
	control.add_theme_font_size_override("font_size", font_size)
