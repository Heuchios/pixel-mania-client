extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const FISH_MONGER_W := 840.0
const FISH_MONGER_H := 560.0
const FISH_MONGER_HEADER_H := 78.0
const FISH_MONGER_SCROLL_GUTTER := 24.0
const FISH_MONGER_PREVIEW_W := 210.0
const FISH_MONGER_PREVIEW_H := 392.0
const FISH_MONGER_PREVIEW_OVERLAP := 0.0
const FISH_MONGER_PREVIEW_Y := 96.0

var world = null
var ui_layer_ref = null
var current_grid: Vector2i = Vector2i(999999, 999999)
var panel = null
var preview_panel = null
var fish_monger_preview_image: TextureRect = null
var fish_monger_preview_shadow: ColorRect = null
var fish_monger_preview_frames: Array = []
var fish_monger_preview_frame_seconds := 0.5
var fish_monger_preview_frame_index := -1
var preview_value_label = null
var preview_count_label = null
var preview_species_label = null
var preview_best_rate_label = null
var gem_label = null
var total_value_label = null
var fish_scroll = null
var fish_rows_root = null
var sell_all_button = null
var empty_label = null
var last_panel_viewport_size := Vector2.ZERO


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 135
	build_ui()
	close_fish_monger()


func _process(_delta):
	if not visible:
		return

	var viewport_size = get_viewport_rect().size
	if viewport_size != last_panel_viewport_size:
		update_panel_position()
	update_header()
	update_fish_monger_preview_animation()


func build_ui():
	for child in get_children():
		child.queue_free()

	panel = Control.new()
	panel.name = "FishMongerPanel"
	panel.size = Vector2(FISH_MONGER_W, FISH_MONGER_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var shadow = Panel.new()
	shadow.name = "Shadow"
	shadow.position = Vector2(8, 8)
	shadow.size = panel.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.0, 0.0, 0.0, 0.34),
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		22,
		0
	))
	panel.add_child(shadow)

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_PANEL_STRONG,
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		22,
		12
	))
	panel.add_child(panel_back)

	build_fish_monger_preview_panel()

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(FISH_MONGER_W, FISH_MONGER_HEADER_H)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_HEADER,
		PixelUIStyle.GLASS_BORDER,
		0,
		22,
		8
	))
	panel.add_child(top_bar)

	var top_line = ColorRect.new()
	top_line.name = "TopLine"
	top_line.position = Vector2(0, FISH_MONGER_HEADER_H - 5.0)
	top_line.size = Vector2(FISH_MONGER_W, 4)
	top_line.color = Color(0.42, 0.78, 1.0, 0.46)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_line)

	var title = Label.new()
	title.name = "Title"
	title.text = "FISH MONGER"
	title.position = Vector2(34, 8)
	title.size = Vector2(390, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 44)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "SELL FISH"
	subtitle.position = Vector2(40, 58)
	subtitle.size = Vector2(360, 22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(subtitle, 14)
	panel.add_child(subtitle)

	var gem_chip = Panel.new()
	gem_chip.name = "GemChip"
	gem_chip.position = Vector2(FISH_MONGER_W - 346, 17)
	gem_chip.size = Vector2(250, 44)
	gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_chip.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.10, 0.24, 0.34, 0.58),
		PixelUIStyle.GLASS_BORDER_BRIGHT,
		3,
		14,
		7
	))
	panel.add_child(gem_chip)

	var gem_icon = TextureRect.new()
	gem_icon.name = "GemIcon"
	gem_icon.position = Vector2(14, 9)
	gem_icon.size = Vector2(26, 26)
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if world != null and world.currency_textures.has("gem"):
		gem_icon.texture = world.currency_textures["gem"]
	gem_chip.add_child(gem_icon)

	gem_label = Label.new()
	gem_label.name = "GemLabel"
	gem_label.position = Vector2(46, 7)
	gem_label.size = Vector2(192, 30)
	gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(gem_label, 18, PixelUIStyle.GOLD_SOFT)
	gem_chip.add_child(gem_label)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.size = Vector2(52, 48)
	close_button.position = Vector2(FISH_MONGER_W - 84, 14)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_fish_monger_arcade_button_style(close_button, false, true, 24)
	close_button.text = "X"
	close_button.pressed.connect(close_fish_monger)
	panel.add_child(close_button)

	var info_card = Panel.new()
	info_card.name = "InfoCard"
	info_card.position = Vector2(32, 96)
	info_card.size = Vector2(FISH_MONGER_W - 64, 58)
	info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.18, 0.32, 0.43, 0.42),
		Color(0.72, 0.92, 1.0, 0.46),
		3,
		12,
		5
	))
	panel.add_child(info_card)

	var info = Label.new()
	info.name = "Info"
	info.text = "Choose how many fish to sell. Gems are paid per fish"
	info.position = Vector2(52, 103)
	info.size = Vector2(520, 26)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(info, 15)
	panel.add_child(info)

	total_value_label = Label.new()
	total_value_label.name = "TotalValue"
	total_value_label.position = Vector2(52, 128)
	total_value_label.size = Vector2(520, 22)
	total_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_value_label.clip_text = true
	total_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(total_value_label, 15, PixelUIStyle.GOLD_SOFT)
	panel.add_child(total_value_label)

	sell_all_button = Button.new()
	sell_all_button.name = "SellAllButton"
	sell_all_button.text = "SELL ALL"
	sell_all_button.position = Vector2(FISH_MONGER_W - 214, 105)
	sell_all_button.size = Vector2(156, 40)
	sell_all_button.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_fish_monger_arcade_button_style(sell_all_button, true, false, 15)
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	panel.add_child(sell_all_button)

	var scroll_back = Panel.new()
	scroll_back.name = "ScrollBack"
	scroll_back.position = Vector2(32, 168)
	scroll_back.size = Vector2(FISH_MONGER_W - 64, 350)
	scroll_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		PixelUIStyle.GLASS_SECTION,
		PixelUIStyle.GLASS_BORDER,
		3,
		12,
		5
	))
	panel.add_child(scroll_back)

	fish_scroll = ScrollContainer.new()
	fish_scroll.name = "FishScroll"
	fish_scroll.position = Vector2(40, 176)
	fish_scroll.size = Vector2(FISH_MONGER_W - 80, 334)
	fish_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fish_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	fish_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	fish_scroll.clip_contents = true
	panel.add_child(fish_scroll)

	fish_rows_root = Control.new()
	fish_rows_root.name = "FishRows"
	fish_rows_root.position = Vector2.ZERO
	fish_rows_root.size = Vector2(get_fish_row_content_width(), fish_scroll.size.y)
	fish_rows_root.custom_minimum_size = fish_rows_root.size
	fish_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_rows_root.clip_contents = true
	fish_scroll.add_child(fish_rows_root)

	empty_label = Label.new()
	empty_label.name = "EmptyState"
	empty_label.text = "You don't have any fish to sell yet. Go fishing!"
	empty_label.position = Vector2(52, 304)
	empty_label.size = Vector2(FISH_MONGER_W - 104, 42)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(empty_label, 20, PixelUIStyle.TEXT_SOFT)
	panel.add_child(empty_label)

	call_deferred("apply_fish_monger_scrollbar_style")
	update_panel_position()


func build_fish_monger_preview_panel():
	if panel == null:
		return

	preview_panel = Panel.new()
	preview_panel.name = "FishMongerPreviewPanel"
	preview_panel.position = Vector2(-FISH_MONGER_PREVIEW_W + FISH_MONGER_PREVIEW_OVERLAP, FISH_MONGER_PREVIEW_Y)
	preview_panel.size = Vector2(FISH_MONGER_PREVIEW_W, FISH_MONGER_PREVIEW_H)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.z_index = 0
	preview_panel.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.045, 0.115, 0.165, 0.72),
		Color(0.32, 0.68, 0.92, 0.64),
		3,
		18,
		10
	))
	panel.add_child(preview_panel)

	var tab_glow = ColorRect.new()
	tab_glow.name = "AttachGlow"
	tab_glow.position = Vector2(FISH_MONGER_PREVIEW_W - FISH_MONGER_PREVIEW_OVERLAP - 2.0, 24)
	tab_glow.size = Vector2(5, FISH_MONGER_PREVIEW_H - 48.0)
	tab_glow.color = Color(0.42, 0.78, 1.0, 0.30)
	tab_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(tab_glow)

	var title = Label.new()
	title.name = "PreviewTitle"
	title.text = "BUYER"
	title.position = Vector2(18, 14)
	title.size = Vector2(164, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_section_title(title, 21)
	preview_panel.add_child(title)

	var preview_back = Panel.new()
	preview_back.name = "PreviewBack"
	preview_back.position = Vector2(20, 50)
	preview_back.size = Vector2(156, 156)
	preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.13, 0.26, 0.35, 0.48),
		Color(0.68, 0.90, 1.0, 0.36),
		2,
		18,
		4
	))
	preview_panel.add_child(preview_back)

	fish_monger_preview_shadow = ColorRect.new()
	fish_monger_preview_shadow.name = "PreviewShadow"
	fish_monger_preview_shadow.position = Vector2(54, 168)
	fish_monger_preview_shadow.size = Vector2(92, 18)
	fish_monger_preview_shadow.pivot_offset = fish_monger_preview_shadow.size * 0.5
	fish_monger_preview_shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	fish_monger_preview_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(fish_monger_preview_shadow)

	fish_monger_preview_image = TextureRect.new()
	fish_monger_preview_image.name = "PreviewImage"
	fish_monger_preview_image.position = Vector2(32, 58)
	fish_monger_preview_image.size = Vector2(132, 132)
	fish_monger_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish_monger_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fish_monger_preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_monger_preview_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fish_monger_preview_image.flip_h = true
	fish_monger_preview_image.pivot_offset = fish_monger_preview_image.size * 0.5
	preview_panel.add_child(fish_monger_preview_image)

	var divider = ColorRect.new()
	divider.name = "PreviewDivider"
	divider.position = Vector2(20, 218)
	divider.size = Vector2(156, 3)
	divider.color = Color(0.42, 0.78, 1.0, 0.34)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(divider)

	var value_caption = Label.new()
	value_caption.name = "ValueCaption"
	value_caption.text = "MARKET VALUE"
	value_caption.position = Vector2(20, 230)
	value_caption.size = Vector2(156, 20)
	value_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(value_caption, 12)
	preview_panel.add_child(value_caption)

	preview_value_label = Label.new()
	preview_value_label.name = "PreviewValue"
	preview_value_label.position = Vector2(20, 250)
	preview_value_label.size = Vector2(156, 28)
	preview_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_value_label, 21, PixelUIStyle.GOLD_SOFT)
	preview_panel.add_child(preview_value_label)

	var stock_caption = Label.new()
	stock_caption.name = "StockCaption"
	stock_caption.text = "FISH"
	stock_caption.position = Vector2(20, 286)
	stock_caption.size = Vector2(72, 20)
	stock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stock_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(stock_caption, 12)
	preview_panel.add_child(stock_caption)

	preview_count_label = Label.new()
	preview_count_label.name = "PreviewFishCount"
	preview_count_label.position = Vector2(20, 306)
	preview_count_label.size = Vector2(72, 24)
	preview_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_count_label, 16)
	preview_panel.add_child(preview_count_label)

	var species_caption = Label.new()
	species_caption.name = "SpeciesCaption"
	species_caption.text = "KINDS"
	species_caption.position = Vector2(104, 286)
	species_caption.size = Vector2(72, 20)
	species_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	species_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	species_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(species_caption, 12)
	preview_panel.add_child(species_caption)

	preview_species_label = Label.new()
	preview_species_label.name = "PreviewSpecies"
	preview_species_label.position = Vector2(104, 306)
	preview_species_label.size = Vector2(72, 24)
	preview_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_species_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_species_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_species_label, 16)
	preview_panel.add_child(preview_species_label)

	var rate_caption = Label.new()
	rate_caption.name = "RateCaption"
	rate_caption.text = "BEST VALUE"
	rate_caption.position = Vector2(20, 340)
	rate_caption.size = Vector2(156, 20)
	rate_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(rate_caption, 12)
	preview_panel.add_child(rate_caption)

	preview_best_rate_label = Label.new()
	preview_best_rate_label.name = "PreviewBestRate"
	preview_best_rate_label.position = Vector2(20, 358)
	preview_best_rate_label.size = Vector2(156, 24)
	preview_best_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_best_rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_best_rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_best_rate_label, 16, PixelUIStyle.ACCENT_CYAN)
	preview_panel.add_child(preview_best_rate_label)

	load_fish_monger_preview_frames()
	update_fish_monger_preview_animation(true)
	update_preview_stats([])


func load_fish_monger_preview_frames():
	fish_monger_preview_frames.clear()
	fish_monger_preview_frame_index = -1

	var item_data: Dictionary = {}
	if world != null and world.item_database.has("fish_monger") and world.item_database["fish_monger"] is Dictionary:
		item_data = world.item_database["fish_monger"]

	var frame_specs = item_data.get("animation_frames", [])
	if frame_specs is Array:
		for frame_spec in frame_specs:
			var texture: Texture2D = AtlasTextureFactory.load_texture(frame_spec)
			if texture != null:
				fish_monger_preview_frames.append(texture)

	if fish_monger_preview_frames.is_empty():
		var fallback_spec = item_data.get("texture", "res://Assets/items/special items/fish_monger/fish_monger.png")
		var fallback_texture: Texture2D = AtlasTextureFactory.load_texture(fallback_spec)
		if fallback_texture != null:
			fish_monger_preview_frames.append(fallback_texture)

	fish_monger_preview_frame_seconds = max(0.08, float(item_data.get("animation_frame_seconds", 0.5)))


func update_fish_monger_preview_animation(force_update: bool = false):
	if fish_monger_preview_image == null:
		return

	if fish_monger_preview_frames.is_empty():
		load_fish_monger_preview_frames()

	if fish_monger_preview_frames.is_empty():
		return

	var frame_msec = max(1, int(round(fish_monger_preview_frame_seconds * 1000.0)))
	var frame_index = int(floor(float(Time.get_ticks_msec()) / float(frame_msec))) % fish_monger_preview_frames.size()
	if force_update or frame_index != fish_monger_preview_frame_index:
		fish_monger_preview_frame_index = frame_index
		fish_monger_preview_image.texture = fish_monger_preview_frames[frame_index]

	fish_monger_preview_image.position = Vector2(32, 58)

	if fish_monger_preview_shadow != null:
		fish_monger_preview_shadow.scale = Vector2.ONE


func update_preview_stats(entries: Array):
	var total_count := 0
	var best_value := 0
	var species_count := 0

	for entry in entries:
		if not (entry is Dictionary):
			continue
		species_count += 1
		total_count += get_fish_count_from_entry(entry)
		best_value = max(best_value, get_fish_value_from_entry(entry))

	if preview_value_label != null:
		preview_value_label.text = format_gem_amount(get_total_sellable_fish_value_from_entries(entries))

	if preview_count_label != null:
		preview_count_label.text = str(total_count)

	if preview_species_label != null:
		preview_species_label.text = str(species_count)

	if preview_best_rate_label != null:
		preview_best_rate_label.text = (format_gem_amount(best_value) + " each") if best_value > 0 else "--"


func apply_fish_monger_arcade_button_style(button: Button, selected: bool = false, danger: bool = false, font_size: int = 14):
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


func apply_fish_monger_input_style(line_edit: LineEdit, font_size: int = 17):
	if line_edit == null:
		return

	PixelUIStyle.apply_input(line_edit, font_size)


func apply_fish_monger_scrollbar_style():
	if fish_scroll == null:
		return

	var scrollbar = fish_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return

	scrollbar.custom_minimum_size = Vector2(12, scrollbar.custom_minimum_size.y)
	scrollbar.add_theme_stylebox_override("scroll", PixelUIStyle.style_box(Color(0.82, 0.94, 1.0, 0.10), Color(0.38, 0.72, 1.0, 0.24), 2, 8, 0))
	scrollbar.add_theme_stylebox_override("grabber", PixelUIStyle.style_box(Color(0.28, 0.62, 0.92, 0.74), Color(0.72, 0.96, 1.0, 0.56), 2, 8, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", PixelUIStyle.style_box(Color(0.38, 0.76, 1.0, 0.88), Color(0.86, 1.0, 1.0, 0.82), 2, 8, 6))
	scrollbar.add_theme_stylebox_override("grabber_pressed", PixelUIStyle.style_box(Color(1.0, 0.66, 0.12, 0.90), Color(1.0, 0.92, 0.40, 0.84), 2, 8, 6))


func get_fish_row_content_width() -> float:
	if fish_scroll == null:
		return max(1.0, FISH_MONGER_W - 104.0)

	return max(1.0, fish_scroll.size.x - FISH_MONGER_SCROLL_GUTTER)


func get_fish_count_from_amount(amount: float) -> int:
	if amount <= 0.0:
		return 0

	return max(1, int(round(amount)))


func get_fish_count_from_entry(entry: Dictionary) -> int:
	return get_fish_count_from_amount(float(entry.get("count", 0.0)))


func get_fish_value_from_entry(entry: Dictionary) -> int:
	return max(0, int(entry.get("sell_value", entry.get("value_per_fish", 0))))


func format_fish_count(count: int) -> String:
	return str(max(0, count)) + (" fish" if count != 1 else " fish")


func get_rarity_accent_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.32, 0.98, 0.50, 1.0)
		"rare":
			return Color(0.30, 0.64, 1.0, 1.0)
		"epic":
			return Color(0.78, 0.42, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.72, 0.14, 1.0)
		_:
			return Color(0.52, 0.88, 1.0, 1.0)


func get_rarity_row_fill(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.07, 0.24, 0.18, 0.54)
		"rare":
			return Color(0.07, 0.18, 0.34, 0.56)
		"epic":
			return Color(0.16, 0.10, 0.30, 0.58)
		"legendary":
			return Color(0.24, 0.18, 0.08, 0.60)
		_:
			return Color(0.12, 0.25, 0.35, 0.52)


func _on_fish_row_hovered(row: Panel, hovered: bool):
	if row == null or not is_instance_valid(row):
		return

	var base_position = row.get_meta("base_position", row.position)
	var target_position = base_position + (Vector2(4, 0) if hovered else Vector2.ZERO)
	var target_modulate = Color(1.08, 1.08, 1.08, 1.0) if hovered else Color.WHITE
	var tween = row.create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "position", target_position, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate", target_modulate, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func open_fish_monger(grid_pos: Vector2i):
	current_grid = grid_pos
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_panel_position()
	refresh()

	if panel != null:
		PixelUIStyle.play_panel_open(panel)


func close_fish_monger():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_panel_viewport_size = Vector2.ZERO


func is_fish_monger_open() -> bool:
	return visible


func update_panel_position():
	if panel == null:
		return

	var screen_size = get_viewport_rect().size
	last_panel_viewport_size = screen_size
	var left_extension = FISH_MONGER_PREVIEW_W - FISH_MONGER_PREVIEW_OVERLAP
	var combined_width = panel.size.x + left_extension
	var min_x = 12.0 + left_extension
	var max_x = max(min_x, screen_size.x - panel.size.x - 12.0)
	var max_y = max(40.0, screen_size.y - panel.size.y - 24.0)
	panel.position = Vector2(
		clamp(((screen_size.x - combined_width) / 2.0) + left_extension, min_x, max_x),
		clamp((screen_size.y - panel.size.y) / 2.0, 40.0, max_y)
	)


func update_header():
	if world == null:
		return

	if gem_label != null:
		gem_label.text = world.get_currency_display_text("gem")

	if total_value_label != null:
		total_value_label.text = "Total fish value: " + format_gem_amount(get_total_sellable_fish_value()) + " gems"


func refresh():
	if world == null or fish_rows_root == null:
		return

	var saved_scroll = fish_scroll.scroll_vertical if fish_scroll != null else 0

	update_header()

	for child in fish_rows_root.get_children():
		child.queue_free()

	var entries: Array = []
	if world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_sellable_fish_entries"):
		entries = world.fish_monger_manager.get_sellable_fish_entries()
	update_preview_stats(entries)

	var pending = is_sale_pending()
	if sell_all_button != null:
		sell_all_button.disabled = pending or entries.is_empty()
		sell_all_button.tooltip_text = "Sell all fish for " + format_gem_amount(get_total_sellable_fish_value_from_entries(entries)) + " gems"

	if empty_label != null:
		empty_label.visible = entries.is_empty()

	if entries.is_empty():
		fish_rows_root.custom_minimum_size = Vector2(get_fish_row_content_width(), fish_scroll.size.y)
		fish_rows_root.size = fish_rows_root.custom_minimum_size
		call_deferred("restore_scroll_position", saved_scroll)
		return

	var row_height = 112.0
	var gap = 12.0
	var content_width = get_fish_row_content_width()
	fish_rows_root.custom_minimum_size = Vector2(
		content_width,
		max(fish_scroll.size.y, entries.size() * (row_height + gap) - gap + 10.0)
	)
	fish_rows_root.size = fish_rows_root.custom_minimum_size

	for i in range(entries.size()):
		create_fish_row(entries[i], Vector2(0, i * (row_height + gap)), row_height, pending)

	call_deferred("restore_scroll_position", saved_scroll)


func restore_scroll_position(scroll_value: int):
	if fish_scroll == null:
		return

	var scrollbar = fish_scroll.get_v_scroll_bar()
	if scrollbar == null:
		fish_scroll.scroll_vertical = scroll_value
		return

	var max_scroll = int(max(0.0, scrollbar.max_value - scrollbar.page))
	fish_scroll.scroll_vertical = clamp(scroll_value, 0, max_scroll)


func create_fish_row(entry: Dictionary, row_position: Vector2, row_height: float, pending: bool):
	var item_id = str(entry.get("item_id", ""))
	var owned_count = get_fish_count_from_entry(entry)
	var value_per_fish = get_fish_value_from_entry(entry)
	var default_amount = max(1, owned_count)
	var rarity = str(entry.get("rarity", "common"))
	var row_width = max(700.0, get_fish_row_content_width())
	var accent_color = get_rarity_accent_color(rarity)
	var sell_button_w = 92.0
	var sell_button_x = row_width - sell_button_w - 12.0
	var amount_minus_x = sell_button_x - 146.0
	var amount_input_x = amount_minus_x + 34.0
	var amount_plus_x = amount_input_x + 58.0
	var quick_button_x = amount_minus_x
	var price_x = amount_minus_x - 148.0
	var name_width = clamp(price_x - 112.0, 160.0, 248.0)

	var row = Panel.new()
	row.name = "FishRow_" + item_id
	row.position = row_position
	row.size = Vector2(row_width, row_height)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.clip_contents = true
	row.pivot_offset = row.size * 0.5
	row.set_meta("base_position", row_position)
	row.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		get_rarity_row_fill(rarity),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.42),
		3,
		14,
		5
	))
	row.mouse_entered.connect(_on_fish_row_hovered.bind(row, true))
	row.mouse_exited.connect(_on_fish_row_hovered.bind(row, false))
	fish_rows_root.add_child(row)

	var accent_strip = ColorRect.new()
	accent_strip.name = "RarityAccent"
	accent_strip.position = Vector2(0, 0)
	accent_strip.size = Vector2(6, row_height)
	accent_strip.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.72)
	accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent_strip)

	var sheen = ColorRect.new()
	sheen.name = "TopSheen"
	sheen.position = Vector2(6, 0)
	sheen.size = Vector2(row_width - 6, 3)
	sheen.color = Color(1.0, 1.0, 1.0, 0.10)
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sheen)

	var icon_back = Panel.new()
	icon_back.name = "IconBack"
	icon_back.position = Vector2(14, 20)
	icon_back.size = Vector2(68, 68)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_back.add_theme_stylebox_override("panel", PixelUIStyle.slot_style(rarity))
	row.add_child(icon_back)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(22, 28)
	icon.size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = entry.get("texture", null)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = str(entry.get("display_name", item_id.capitalize()))
	name_label.position = Vector2(98, 10)
	name_label.size = Vector2(name_width, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(name_label, 19)
	row.add_child(name_label)

	var rarity_badge = Label.new()
	rarity_badge.name = "RarityBadge"
	rarity_badge.text = rarity.capitalize()
	rarity_badge.position = Vector2(98, 40)
	rarity_badge.size = Vector2(86, 22)
	rarity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_badge.clip_text = true
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(rarity_badge, 13, accent_color)
	row.add_child(rarity_badge)

	var qty_label = Label.new()
	qty_label.name = "Quantity"
	qty_label.text = "Owned: " + format_fish_count(owned_count)
	qty_label.position = Vector2(190, 40)
	qty_label.size = Vector2(138, 22)
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(qty_label, 14)
	row.add_child(qty_label)

	var selected_back = Panel.new()
	selected_back.name = "SelectedBack"
	selected_back.position = Vector2(98, 72)
	selected_back.size = Vector2(232, 12)
	selected_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.02, 0.06, 0.09, 0.56),
		Color(0.34, 0.62, 0.82, 0.28),
		1,
		7,
		0
	))
	row.add_child(selected_back)

	var selected_clip = Control.new()
	selected_clip.name = "SelectedClip"
	selected_clip.position = selected_back.position
	selected_clip.size = selected_back.size
	selected_clip.clip_contents = true
	selected_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(selected_clip)

	var selected_fill = Panel.new()
	selected_fill.name = "SelectedFill"
	selected_fill.position = Vector2.ZERO
	selected_fill.size = selected_back.size
	selected_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_fill.set_meta("max_width", selected_back.size.x)
	selected_fill.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(accent_color.r, accent_color.g, accent_color.b, 0.58),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.0),
		0,
		7,
		0
	))
	selected_clip.add_child(selected_fill)

	var selected_label = Label.new()
	selected_label.name = "SelectedAmount"
	selected_label.position = Vector2(98, 86)
	selected_label.size = Vector2(232, 18)
	selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_label.clip_text = true
	selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(selected_label, 12)
	row.add_child(selected_label)

	var price_back = Panel.new()
	price_back.name = "PriceBack"
	price_back.position = Vector2(price_x, 12)
	price_back.size = Vector2(136, 30)
	price_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.06, 0.18, 0.25, 0.58),
		Color(1.0, 0.82, 0.20, 0.42),
		2,
		10,
		2
	))
	row.add_child(price_back)

	var price_label = Label.new()
	price_label.name = "Price"
	price_label.text = format_gem_amount(value_per_fish) + " gems each"
	price_label.position = Vector2(price_x + 8, 15)
	price_label.size = Vector2(120, 24)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(price_label, 15, PixelUIStyle.GOLD_SOFT)
	row.add_child(price_label)

	var total_back = Panel.new()
	total_back.name = "TotalBack"
	total_back.position = Vector2(price_x, 50)
	total_back.size = Vector2(136, 30)
	total_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total_back.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
		Color(0.08, 0.24, 0.20, 0.48),
		Color(0.36, 0.94, 0.58, 0.36),
		2,
		10,
		2
	))
	row.add_child(total_back)

	var total_label = Label.new()
	total_label.name = "Total"
	total_label.text = "Total: " + format_gem_amount(calculate_fish_sale_value(default_amount, value_per_fish)) + " gems"
	total_label.position = Vector2(price_x + 8, 54)
	total_label.size = Vector2(120, 22)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(total_label, 13)
	row.add_child(total_label)

	var quick_button_y := 13.0
	var quick_button_h := 28.0
	var half_button = Button.new()
	half_button.name = "HalfButton"
	half_button.text = "HALF"
	half_button.position = Vector2(quick_button_x, quick_button_y)
	half_button.size = Vector2(54, quick_button_h)
	half_button.mouse_filter = Control.MOUSE_FILTER_STOP
	half_button.disabled = pending or owned_count <= 1
	apply_fish_monger_arcade_button_style(half_button, false, false, 12)
	row.add_child(half_button)

	var max_button = Button.new()
	max_button.name = "MaxButton"
	max_button.text = "MAX"
	max_button.position = Vector2(quick_button_x + 60.0, quick_button_y)
	max_button.size = Vector2(54, quick_button_h)
	max_button.mouse_filter = Control.MOUSE_FILTER_STOP
	max_button.disabled = pending or owned_count <= 0
	apply_fish_monger_arcade_button_style(max_button, false, false, 12)
	row.add_child(max_button)

	var amount_control_y := 52.0
	var amount_control_height := 36.0

	var minus_button = Button.new()
	minus_button.name = "AmountMinus"
	minus_button.text = "-"
	minus_button.position = Vector2(amount_minus_x, amount_control_y)
	minus_button.size = Vector2(30, amount_control_height)
	minus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	minus_button.disabled = pending or owned_count <= 1
	apply_fish_monger_arcade_button_style(minus_button, false, false, 18)
	row.add_child(minus_button)

	var amount_input = LineEdit.new()
	amount_input.name = "AmountInput"
	amount_input.text = format_fish_count_number(default_amount)
	amount_input.placeholder_text = "1"
	amount_input.position = Vector2(amount_input_x, amount_control_y)
	amount_input.size = Vector2(54, amount_control_height)
	amount_input.max_length = 8
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_input.mouse_filter = Control.MOUSE_FILTER_STOP
	amount_input.editable = not pending and owned_count > 0
	apply_fish_monger_input_style(amount_input, 17)
	row.add_child(amount_input)

	var plus_button = Button.new()
	plus_button.name = "AmountPlus"
	plus_button.text = "+"
	plus_button.position = Vector2(amount_plus_x, amount_control_y)
	plus_button.size = Vector2(30, amount_control_height)
	plus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	plus_button.disabled = pending or owned_count <= 1
	apply_fish_monger_arcade_button_style(plus_button, false, false, 18)
	row.add_child(plus_button)

	var sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.position = Vector2(sell_button_x, 34)
	sell_button.size = Vector2(sell_button_w, 48)
	sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_button.disabled = pending or owned_count <= 0 or value_per_fish <= 0
	apply_fish_monger_arcade_button_style(sell_button, true, false, 17)
	sell_button.pressed.connect(_on_sell_pressed.bind(item_id, amount_input, owned_count))
	row.add_child(sell_button)

	amount_input.text_changed.connect(_on_amount_text_changed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	amount_input.text_submitted.connect(_on_amount_text_submitted.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	amount_input.focus_exited.connect(_on_amount_focus_exited.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	minus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, -1, selected_label, selected_fill))
	plus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 1, selected_label, selected_fill))
	half_button.pressed.connect(_on_amount_quick_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 0.5, selected_label, selected_fill))
	max_button.pressed.connect(_on_amount_quick_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 1.0, selected_label, selected_fill))
	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func parse_amount_text(raw_text: String) -> float:
	var clean_text = raw_text.strip_edges()
	if clean_text == "" or not clean_text.is_valid_float():
		return 0.0

	return max(0.0, floor(float(clean_text)))


func clamp_sell_amount(amount: float, owned_count: float) -> float:
	return float(clampi(int(round(amount)), 1, max(1, int(round(owned_count)))))


func update_amount_summary(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	var amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if amount > owned_count:
		amount = owned_count
	var total_gems: int = calculate_fish_sale_value(amount, value_per_fish)

	if total_label != null:
		total_label.text = "Total: " + format_gem_amount(total_gems) + " gems"

	if selected_label != null:
		selected_label.text = "Selected: " + format_fish_count(int(amount))

	if selected_fill != null:
		var max_width = float(selected_fill.get_meta("max_width", selected_fill.size.x))
		var fill_ratio = 0.0 if owned_count <= 0.0 else clampf(amount / owned_count, 0.0, 1.0)
		selected_fill.size = Vector2(max(1.0, max_width * fill_ratio), selected_fill.size.y)

	if sell_button != null:
		sell_button.disabled = pending or owned_count <= 0.0 or value_per_fish <= 0 or amount <= 0.0 or amount > owned_count or total_gems <= 0


func sanitize_amount_input(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, selected_label: Label = null, selected_fill: Panel = null) -> float:
	var amount = clamp_sell_amount(parse_amount_text(amount_input.text if amount_input != null else ""), owned_count)
	if amount_input != null:
		amount_input.text = format_fish_count_number(amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)
	return amount


func format_gem_amount(amount: int) -> String:
	if world != null and world.has_method("format_currency_amount"):
		return world.format_currency_amount(amount)

	return str(amount)


func format_fish_count_number(count: float) -> String:
	return str(max(0, int(round(count))))


func calculate_fish_sale_value(count: float, value_per_fish: int) -> int:
	if count <= 0.0 or value_per_fish <= 0:
		return 0
	return int(count) * value_per_fish


func get_total_sellable_fish_value() -> int:
	if world != null and world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_sellable_fish_entries"):
		return get_total_sellable_fish_value_from_entries(world.fish_monger_manager.get_sellable_fish_entries())
	if world != null and world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_total_sellable_fish_value"):
		return int(world.fish_monger_manager.get_total_sellable_fish_value())
	return 0


func get_total_sellable_fish_value_from_entries(entries: Array) -> int:
	var total_value := 0
	for entry in entries:
		if entry is Dictionary:
			total_value += get_fish_count_from_entry(entry) * get_fish_value_from_entry(entry)
	return total_value


func _on_amount_text_changed(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_text_submitted(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_focus_exited(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_step_pressed(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, delta: int, selected_label: Label = null, selected_fill: Panel = null):
	var current_amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if current_amount <= 0.0:
		current_amount = min(1.0, owned_count)

	var next_amount = clamp_sell_amount(current_amount + float(delta), owned_count)
	if amount_input != null:
		amount_input.text = format_fish_count_number(next_amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_quick_pressed(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: int, pending: bool, fraction: float, selected_label: Label = null, selected_fill: Panel = null):
	var next_amount = clamp_sell_amount(max(1.0, owned_count * fraction), owned_count)
	if amount_input != null:
		amount_input.text = format_fish_count_number(next_amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func is_sale_pending() -> bool:
	return world != null and world.fish_monger_manager != null and bool(world.fish_monger_manager.pending_transaction)


func _on_sell_pressed(item_id: String, amount_input: LineEdit, owned_count: float):
	if world != null and world.fish_monger_manager != null:
		var requested_amount = parse_amount_text(amount_input.text if amount_input != null else "")
		if requested_amount <= 0.0:
			if world.has_method("show_notification"):
				world.show_notification("Choose at least 1 fish to sell.")
			return
		var amount = clamp_sell_amount(requested_amount, owned_count)
		if amount_input != null:
			amount_input.text = format_fish_count_number(amount)
		world.fish_monger_manager.sell_fish(item_id, amount)


func _on_sell_all_pressed():
	if world != null and world.fish_monger_manager != null:
		world.fish_monger_manager.sell_all_fish()
