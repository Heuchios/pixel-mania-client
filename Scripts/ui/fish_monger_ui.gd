extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
const AtlasTextureFactory = preload("res://Scripts/atlas_texture_factory.gd")

const FISH_MONGER_W := 1040.0
const FISH_MONGER_H := 660.0
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


func _text(parent: Control, node_name: String, text: String, rect: Rect2, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(label, font_size, color)
	_preserve_text(label, font_size)
	parent.add_child(label)
	return label

func _preserve_text(control: Control, font_size: int):
	control.set_meta("pixelmania_font_role", "preserve")
	control.add_theme_font_size_override("font_size", font_size)

func _surface(parent: Control, node_name: String, rect: Rect2, outer: bool = false) -> Panel:
	var surface := Panel.new()
	surface.name = node_name
	surface.position = rect.position
	surface.size = rect.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_theme_stylebox_override("panel", PixelUIStyle.panel_style() if outer else PixelUIStyle.section_style())
	parent.add_child(surface)
	return surface

func _button(parent: Control, node_name: String, text: String, rect: Rect2, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	if primary:
		PixelUIStyle.apply_green_button(button, 16)
	else:
		PixelUIStyle.apply_blue_button(button, 16)
	_preserve_text(button, 16)
	parent.add_child(button)
	return button

func build_ui():
	for child in get_children():
		child.queue_free()
	panel = Control.new()
	panel.name = "FishMongerPanel"
	panel.size = Vector2(FISH_MONGER_W, FISH_MONGER_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_surface(panel, "PanelBack", Rect2(0, 0, 1040, 660), true)
	_surface(panel, "TopBar", Rect2(16, 16, 1008, 72))
	_text(panel, "Title", "FISH MONGER", Rect2(32, 22, 440, 34), 28)
	_text(panel, "Subtitle", "Turn your catch into gems", Rect2(32, 57, 440, 22), 14, PixelUIStyle.TEXT_SOFT)
	_text(panel, "BalanceCaption", "YOUR GEMS", Rect2(680, 26, 240, 20), 12, PixelUIStyle.TEXT_SOFT)
	gem_label = _text(panel, "GemLabel", "", Rect2(680, 46, 240, 28), 20, PixelUIStyle.GOLD_SOFT)
	gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.get_node("BalanceCaption").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_button := _button(panel, "CloseButton", "", Rect2(960, 28, 48, 48))
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_fish_monger)
	build_fish_monger_preview_panel()
	_surface(panel, "InfoCard", Rect2(228, 100, 796, 72))
	_text(panel, "Info", "YOUR CATCH", Rect2(244, 108, 500, 24), 20)
	total_value_label = _text(panel, "TotalValue", "", Rect2(244, 138, 540, 24), 15, PixelUIStyle.GOLD_SOFT)
	sell_all_button = _button(panel, "SellAllButton", "SELL ALL", Rect2(840, 115, 168, 42), true)
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	_surface(panel, "ScrollBack", Rect2(228, 184, 796, 424))
	fish_scroll = ScrollContainer.new()
	fish_scroll.name = "FishScroll"
	fish_scroll.position = Vector2(238, 194)
	fish_scroll.size = Vector2(776, 404)
	fish_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fish_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	fish_scroll.clip_contents = true
	panel.add_child(fish_scroll)
	fish_rows_root = Control.new()
	fish_rows_root.name = "FishRows"
	fish_rows_root.custom_minimum_size = Vector2(get_fish_row_content_width(), 404)
	fish_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_scroll.add_child(fish_rows_root)
	empty_label = _text(panel, "EmptyState", "No fish to sell yet.\nCast a line and bring back your catch!", Rect2(248, 322, 748, 100), 18, PixelUIStyle.TEXT_SOFT)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(panel, "Hint", "Choose a quantity, then sell for the total shown.", Rect2(244, 615, 764, 28), 14, PixelUIStyle.TEXT_SOFT)
	call_deferred("apply_fish_monger_scrollbar_style")
	update_panel_position()


func build_fish_monger_preview_panel():
	if panel == null:
		return

	preview_panel = Panel.new()
	preview_panel.name = "FishMongerPreviewPanel"
	preview_panel.position = Vector2(16, 100)
	preview_panel.size = Vector2(200, 544)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.z_index = 0
	preview_panel.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(preview_panel)

	var tab_glow = ColorRect.new()
	tab_glow.name = "AttachGlow"
	tab_glow.position = Vector2(FISH_MONGER_PREVIEW_W - FISH_MONGER_PREVIEW_OVERLAP - 2.0, 24)
	tab_glow.size = Vector2(5, FISH_MONGER_PREVIEW_H - 48.0)
	tab_glow.color = Color(0.42, 0.78, 1.0, 0.30)
	tab_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(tab_glow)
	tab_glow.hide()

	var title = Label.new()
	title.name = "PreviewTitle"
	title.text = "BUYER"
	title.position = Vector2(18, 14)
	title.size = Vector2(164, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_section_title(title, 21)
	_preserve_text(title, 21)
	preview_panel.add_child(title)

	var preview_back = Panel.new()
	preview_back.name = "PreviewBack"
	preview_back.position = Vector2(20, 50)
	preview_back.size = Vector2(156, 156)
	preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_back.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
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
	_preserve_text(value_caption, 12)
	preview_panel.add_child(value_caption)

	preview_value_label = Label.new()
	preview_value_label.name = "PreviewValue"
	preview_value_label.position = Vector2(20, 250)
	preview_value_label.size = Vector2(156, 28)
	preview_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_value_label, 21, PixelUIStyle.GOLD_SOFT)
	_preserve_text(preview_value_label, 21)
	preview_panel.add_child(preview_value_label)

	var stock_caption = Label.new()
	stock_caption.name = "StockCaption"
	stock_caption.text = "KG"
	stock_caption.position = Vector2(20, 286)
	stock_caption.size = Vector2(72, 20)
	stock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stock_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(stock_caption, 12)
	_preserve_text(stock_caption, 12)
	preview_panel.add_child(stock_caption)

	preview_count_label = Label.new()
	preview_count_label.name = "PreviewFishCount"
	preview_count_label.position = Vector2(20, 306)
	preview_count_label.size = Vector2(72, 24)
	preview_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_count_label, 16)
	_preserve_text(preview_count_label, 16)
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
	_preserve_text(species_caption, 12)
	preview_panel.add_child(species_caption)

	preview_species_label = Label.new()
	preview_species_label.name = "PreviewSpecies"
	preview_species_label.position = Vector2(104, 306)
	preview_species_label.size = Vector2(72, 24)
	preview_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_species_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_species_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_species_label, 16)
	_preserve_text(preview_species_label, 16)
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
	_preserve_text(rate_caption, 12)
	preview_panel.add_child(rate_caption)

	preview_best_rate_label = Label.new()
	preview_best_rate_label.name = "PreviewBestRate"
	preview_best_rate_label.position = Vector2(20, 358)
	preview_best_rate_label.size = Vector2(156, 24)
	preview_best_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_best_rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_best_rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(preview_best_rate_label, 16, PixelUIStyle.ACCENT_CYAN)
	_preserve_text(preview_best_rate_label, 16)
	preview_panel.add_child(preview_best_rate_label)

	_text(preview_panel, "BuyerHint", "All fish welcome.\nPaid in gems.", Rect2(16, 446, 172, 58), 13, PixelUIStyle.TEXT_SOFT)
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
	var total_count := 0.0
	var best_value := 0.0
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
		preview_count_label.text = "%.1f" % total_count

	if preview_species_label != null:
		preview_species_label.text = str(species_count)

	if preview_best_rate_label != null:
		preview_best_rate_label.text = (("%.2f" % best_value) + "/kg") if best_value > 0 else "--"


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
	scrollbar.custom_minimum_size.x = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color("24102e")
	scrollbar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb := StyleBoxFlat.new()
		thumb.bg_color = Color("e7caee") if state == "grabber" else Color.WHITE
		thumb.content_margin_left = 6
		thumb.content_margin_right = 6
		scrollbar.add_theme_stylebox_override(state, thumb)


func get_fish_row_content_width() -> float:
	if fish_scroll == null:
		return max(1.0, FISH_MONGER_W - 104.0)

	return max(1.0, fish_scroll.size.x - FISH_MONGER_SCROLL_GUTTER)


func get_fish_count_from_amount(amount: float) -> float:
	if amount <= 0.0:
		return 0

	return snappedf(maxf(0.0, amount), 0.1)


func get_fish_count_from_entry(entry: Dictionary) -> float:
	return get_fish_count_from_amount(float(entry.get("count", 0.0)))


func get_fish_value_from_entry(entry: Dictionary) -> float:
	return maxf(0.0, float(entry.get("sell_value", entry.get("value_per_fish", 0))))


func format_fish_count(count: float) -> String:
	return "%.1f kg" % maxf(0.0, count)


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
	var fit = min(1.0, min((screen_size.x - 24.0) / FISH_MONGER_W, (screen_size.y - 24.0) / FISH_MONGER_H))
	panel.scale = Vector2.ONE * max(0.1, fit)
	panel.position = (screen_size - panel.size * panel.scale) * 0.5


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
	var selected_weights: Dictionary = {}
	for old_row in fish_rows_root.get_children():
		var old_input = old_row.get_node_or_null("AmountInput")
		if old_input is LineEdit:
			selected_weights[str(old_row.name)] = old_input.text

	update_header()

	for child in fish_rows_root.get_children():
		fish_rows_root.remove_child(child)
		child.queue_free()

	var entries: Array = []
	if world.fish_monger_manager != null and world.fish_monger_manager.has_method("get_sellable_fish_entries"):
		entries = world.fish_monger_manager.get_sellable_fish_entries()
	update_preview_stats(entries)

	var pending = is_sale_pending()
	if sell_all_button != null:
		sell_all_button.disabled = pending or entries.is_empty() or get_total_sellable_fish_value_from_entries(entries) <= 0
		sell_all_button.tooltip_text = "Sell all fish for " + format_gem_amount(get_total_sellable_fish_value_from_entries(entries)) + " gems"

	if empty_label != null:
		empty_label.visible = entries.is_empty()

	if entries.is_empty():
		fish_rows_root.custom_minimum_size = Vector2(get_fish_row_content_width(), fish_scroll.size.y)
		fish_rows_root.size = fish_rows_root.custom_minimum_size
		call_deferred("restore_scroll_position", saved_scroll)
		return

	var row_height = 152.0
	var gap = 12.0
	var content_width = get_fish_row_content_width()
	fish_rows_root.custom_minimum_size = Vector2(
		content_width,
		max(fish_scroll.size.y, entries.size() * (row_height + gap) - gap + 10.0)
	)
	fish_rows_root.size = fish_rows_root.custom_minimum_size

	for i in range(entries.size()):
		create_fish_row(entries[i], Vector2(0, i * (row_height + gap)), row_height, pending)
		var row = fish_rows_root.get_child(i)
		if selected_weights.has(str(row.name)):
			var amount_input: LineEdit = row.get_node("AmountInput")
			var kept_weight := clamp_sell_amount(parse_amount_text(str(selected_weights[str(row.name)])), get_fish_count_from_entry(entries[i]))
			amount_input.text = format_fish_count_number(kept_weight)
			amount_input.text_changed.emit(amount_input.text)

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
	var default_amount = maxf(0.1, owned_count)
	var rarity = str(entry.get("rarity", "common"))
	var row_width = get_fish_row_content_width()
	var accent_color = get_rarity_accent_color(rarity)
	var row := _surface(fish_rows_root, "FishRow_" + item_id, Rect2(row_position, Vector2(row_width, row_height)), true)
	_surface(row, "InnerPanel", Rect2(5, 5, row_width - 10, row_height - 10))
	var icon_back := _surface(row, "IconBack", Rect2(16, 18, 76, 76), true)
	icon_back.self_modulate = Color.WHITE.lerp(accent_color, 0.25)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(24, 26)
	icon.size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _fish_artwork(entry.get("texture", null))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := _text(row, "Name", str(entry.get("display_name", item_id.capitalize())), Rect2(108, 16, 398, 30), 20)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = name_label.text
	_text(row, "RarityBadge", rarity.capitalize(), Rect2(108, 49, 172, 24), 14, accent_color)
	_text(row, "Quantity", "Owned: " + format_fish_count(owned_count), Rect2(282, 49, 224, 24), 14, PixelUIStyle.TEXT_SOFT)
	var price_text: String = ("%.2f gems/kg" % value_per_fish) if value_per_fish > 0.0 else str(entry.get("price_status", "Loading price..."))
	var price := _text(row, "Price", price_text, Rect2(row_width - 232, 18, 212, 26), 16, PixelUIStyle.GOLD_SOFT)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.tooltip_text = "Global market • Range: %.2f–%.2f gems/kg" % [float(entry.get("min_price_kg", 0)), float(entry.get("max_price_kg", 0))]
	if value_per_fish <= 0.0:
		price.tooltip_text = str(entry.get("price_error", "Waiting for the market."))
	var total_label := _text(row, "Total", "", Rect2(row_width - 262, 51, 242, 26), 15)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var selected_label := _text(row, "SelectedAmount", "", Rect2(20, 106, 200, 28), 13, PixelUIStyle.TEXT_SOFT)
	var selected_fill: Panel = null
	var half_button := _button(row, "HalfButton", "HALF", Rect2(232, 102, 66, 34))
	var max_button := _button(row, "MaxButton", "MAX", Rect2(304, 102, 66, 34))
	var minus_button := _button(row, "AmountMinus", "-", Rect2(386, 102, 34, 34))
	var amount_input := LineEdit.new()
	amount_input.name = "AmountInput"
	amount_input.text = format_fish_count_number(default_amount)
	amount_input.position = Vector2(426, 102)
	amount_input.size = Vector2(100, 34)
	amount_input.max_length = 8
	amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUIStyle.apply_input(amount_input, 16)
	_preserve_text(amount_input, 16)
	amount_input.editable = not pending and owned_count > 0
	row.add_child(amount_input)
	var plus_button := _button(row, "AmountPlus", "+", Rect2(532, 102, 34, 34))
	var sell_button := _button(row, "SellButton", "SELL", Rect2(row_width - 166, 96, 146, 42), true)
	half_button.disabled = pending or owned_count <= 0.1
	max_button.disabled = pending or owned_count <= 0
	minus_button.disabled = pending or owned_count <= 0.1
	plus_button.disabled = pending or owned_count <= 0.1
	sell_button.pressed.connect(_on_sell_pressed.bind(item_id, amount_input, owned_count))
	amount_input.text_changed.connect(_on_amount_text_changed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	amount_input.text_submitted.connect(_on_amount_text_submitted.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	amount_input.focus_exited.connect(_on_amount_focus_exited.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill))
	minus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, -1, selected_label, selected_fill))
	plus_button.pressed.connect(_on_amount_step_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 1, selected_label, selected_fill))
	half_button.pressed.connect(_on_amount_quick_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 0.5, selected_label, selected_fill))
	max_button.pressed.connect(_on_amount_quick_pressed.bind(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, 1.0, selected_label, selected_fill))
	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _fish_artwork(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image = texture.get_image()
	if image == null:
		return texture
	var region = image.get_used_rect()
	if not region.has_area():
		return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = region
	return cropped


func parse_amount_text(raw_text: String) -> float:
	var clean_text = raw_text.strip_edges()
	if clean_text == "" or not clean_text.is_valid_float():
		return 0.0

	return snappedf(maxf(0.0, float(clean_text)), 0.1) if is_finite(float(clean_text)) else 0.0


func clamp_sell_amount(amount: float, owned_count: float) -> float:
	return snappedf(clampf(amount, 0.1, maxf(0.1, owned_count)), 0.1)


func update_amount_summary(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	var amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if amount > owned_count:
		amount = owned_count
	var total_gems: int = calculate_fish_sale_value(amount, value_per_fish)

	if total_label != null:
		total_label.text = "Total: " + format_gem_amount(total_gems) + " gems"

	if selected_label != null:
		selected_label.text = "Selected: " + format_fish_count(amount)

	if selected_fill != null:
		var max_width = float(selected_fill.get_meta("max_width", selected_fill.size.x))
		var fill_ratio = 0.0 if owned_count <= 0.0 else clampf(amount / owned_count, 0.0, 1.0)
		selected_fill.size = Vector2(max(1.0, max_width * fill_ratio), selected_fill.size.y)

	if sell_button != null:
		sell_button.disabled = pending or owned_count <= 0.0 or value_per_fish <= 0 or amount <= 0.0 or amount > owned_count or total_gems <= 0


func sanitize_amount_input(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, selected_label: Label = null, selected_fill: Panel = null) -> float:
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
	return "%.1f" % maxf(0.0, count)


func calculate_fish_sale_value(count: float, value_per_fish: float) -> int:
	if count <= 0.0 or value_per_fish <= 0:
		return 0
	return ceili((roundi(count * 10.0) * roundi(value_per_fish * 100.0)) / 1000.0)


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
			total_value += roundi(get_fish_count_from_entry(entry) * 10.0) * roundi(get_fish_value_from_entry(entry) * 100.0)
	return ceili(total_value / 1000.0)


func _on_amount_text_changed(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_text_submitted(_new_text: String, amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_focus_exited(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, selected_label: Label = null, selected_fill: Panel = null):
	sanitize_amount_input(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_step_pressed(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, delta: int, selected_label: Label = null, selected_fill: Panel = null):
	var current_amount = parse_amount_text(amount_input.text if amount_input != null else "")
	if current_amount <= 0.0:
		current_amount = min(0.1, owned_count)

	var next_amount = clamp_sell_amount(current_amount + float(delta) * 0.1, owned_count)
	if amount_input != null:
		amount_input.text = format_fish_count_number(next_amount)

	update_amount_summary(amount_input, total_label, sell_button, owned_count, value_per_fish, pending, selected_label, selected_fill)


func _on_amount_quick_pressed(amount_input: LineEdit, total_label: Label, sell_button: Button, owned_count: float, value_per_fish: float, pending: bool, fraction: float, selected_label: Label = null, selected_fill: Panel = null):
	var next_amount = clamp_sell_amount(max(0.1, owned_count * fraction), owned_count)
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
				world.show_notification("Choose at least 0.1 kg to sell.")
			return
		var amount = clamp_sell_amount(requested_amount, owned_count)
		if amount_input != null:
			amount_input.text = format_fish_count_number(amount)
		world.fish_monger_manager.sell_fish(item_id, amount)


func _on_sell_all_pressed():
	if world != null and world.fish_monger_manager != null:
		world.fish_monger_manager.sell_all_fish()
