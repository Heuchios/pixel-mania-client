extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

const PANEL_W := 960.0
const PANEL_H := 704.0
const CARD_W := 432.0
const CARD_H := 202.0
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
var close_target: Control = null
var close_button: Button = null
var close_touch_index := -1


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
	# GUI hit testing follows tree order, not z_index. Raise the UI branch too.
	var branch: Node = self
	while branch.get_parent() is Control:
		branch.get_parent().move_child(branch, -1)
		branch = branch.get_parent()
	if branch.get_parent() is CanvasLayer:
		branch.get_parent().move_child(branch, -1)
	_position_panel()
	# Keep the viewport-fit scale when opening on smaller screens.


func close_journal() -> void:
	close_touch_index = -1
	visible = false


func _on_close_gui_input(event: InputEvent) -> void:
	# Native touch (including a second finger) must not depend on mouse emulation.
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			close_touch_index = event.index
		elif event.index == close_touch_index:
			close_touch_index = -1
			if not event.canceled and Rect2(Vector2.ZERO, close_button.size).has_point(event.position):
				close_journal()
		close_button.accept_event()
	elif event is InputEventScreenDrag and event.index == close_touch_index:
		if not Rect2(Vector2.ZERO, close_button.size).has_point(event.position):
			close_touch_index = -1
		close_button.accept_event()


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
	inner.name = "SummaryPanel"
	inner.position = Vector2(16, 78)
	inner.size = Vector2(PANEL_W - 32, 92)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(inner)

	title_label = Label.new()
	title_label.text = "FISHING JOURNAL"
	title_label.position = Vector2(30, 22)
	title_label.size = Vector2(PANEL_W - 120, 46)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_label_shadow(title_label, 40, Color("321b3d"))
	_preserve_text(title_label, 40)
	title_label.set_meta("pixelmania_font_size", 40)
	title_label.set_meta("pixelmania_text_shadow", false)
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 0)
	title_label.add_theme_constant_override("outline_size", 0)
	title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	panel.add_child(title_label)

	close_target = Control.new()
	close_target.name = "CloseTarget"
	close_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(close_target)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(48, 48)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_journal)
	close_button.gui_input.connect(_on_close_gui_input)
	close_target.add_child(close_button)

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
	cards_root.columns = 2
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
	# Include viewport stretching: phones can display a 1920-wide logical canvas.
	# Keep the target at least 48 screen pixels, not just 48 logical UI units.
	if close_target != null:
		var screen_scale := panel.get_screen_transform().get_scale().abs().max(Vector2(0.01, 0.01))
		close_target.scale = (Vector2.ONE / screen_scale).max(Vector2.ONE)
		close_target.position = Vector2(PANEL_W - 16.0 - 48.0 * close_target.scale.x, 16.0)


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
	var discovered := bool(entry.get("discovered", false))
	var rarity := str(entry.get("rarity", "common")).to_lower()
	var accent := _rarity_color(rarity) if discovered else Color("786480")
	var card := Panel.new()
	card.set_meta("pixelmania_panel_shadow", false)
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", PixelUIStyle.atlas_style("outer_panel", Color.WHITE if discovered else Color("95859d"), 3))
	cards_root.add_child(card)
	_journal_panel(card, "Inner", Rect2(4, 4, CARD_W - 8, CARD_H - 8), PixelUIStyle.section_style())
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("22132e").lerp(accent, 0.13 if discovered else 0.02)
	art_style.border_color = accent
	art_style.border_width_bottom = 3
	_journal_panel(card, "FishDisplay", Rect2(16, 16, 136, 114), art_style)
	var icon := TextureRect.new()
	icon.name = "FishArtwork"
	icon.position = Vector2(28, 30)
	icon.size = Vector2(112, 84)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon_value = entry.get("icon", null)
	icon.texture = icon_value as Texture2D if icon_value is Texture2D else null
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
	icon.modulate = Color.WHITE if discovered else Color(0.05, 0.02, 0.08, 0.9)
	card.add_child(icon)
	if not discovered:
		var mystery := _journal_text(card, "Mystery", "?", Rect2(28, 30, 112, 84), 32, Color("c9b5d2"))
		mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_journal_text(card, "FishName", "UNDISCOVERED", Rect2(168, 20, 246, 42), 26, Color("c9b5d2"))
		_journal_text(card, "DiscoveryHint", "Your next catch could fill this page.", Rect2(168, 64, 244, 60), 16, PixelUIStyle.TEXT_SOFT)
		_journal_text(card, "LockedRecords", "Catch this fish to reveal its records.", Rect2(20, 148, 392, 36), 15, Color("a58cb1"))
		return
	var name_label := _journal_text(card, "FishName", str(entry.get("name", "Fish")), Rect2(168, 12, 246, 64), 28, Color.WHITE)
	name_label.tooltip_text = name_label.text
	_journal_text(card, "Rarity", rarity.to_upper(), Rect2(168, 78, 246, 24), 15, accent)
	_journal_text(card, "Habitat", str(entry.get("location", "Any Water")), Rect2(168, 104, 246, 28), 15, PixelUIStyle.TEXT_SOFT)
	var record_values := [str(int(entry.get("total_caught", 0))), _format_weight(float(entry.get("biggest_weight", 0.0))), str(int(entry.get("best_value", 0))) + " gems"]
	var record_titles := ["CAUGHT", "BIGGEST", "BEST VALUE"]
	for i in range(3):
		var x := 16.0 + i * 136.0
		var record_style := StyleBoxFlat.new()
		record_style.bg_color = Color("24112e")
		_journal_panel(card, "Record%d" % i, Rect2(x, 142, 128, 44), record_style)
		_journal_text(card, "RecordTitle%d" % i, record_titles[i], Rect2(x + 8, 146, 112, 15), 11, Color("b8a3c5"))
		_journal_text(card, "RecordValue%d" % i, record_values[i], Rect2(x + 8, 162, 112, 22), 16, Color.WHITE)


func _journal_panel(parent: Control, node_name: String, bounds: Rect2, style: StyleBox) -> void:
	var section := Panel.new()
	section.name = node_name
	section.position = bounds.position
	section.size = bounds.size
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_stylebox_override("panel", style)
	parent.add_child(section)


func _journal_text(parent: Control, node_name: String, text: String, bounds: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = bounds.position
	label.size = bounds.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("pixelmania_font_size", font_size)
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	parent.add_child(label)
	return label


func _format_weight(weight: float) -> String:
	if weight <= 0.0:
		return "--"
	return "%.1f kg" % snapped(weight, 0.1)


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
