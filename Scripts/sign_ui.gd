extends Control

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

var world = null
var ui_layer_ref = null
var panel = null
var sign_text_edit = null
var sign_grid_pos = Vector2i.ZERO
var char_count_label = null


func setup(parent_world, ui_node):
	world = parent_world
	ui_layer_ref = ui_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	setup_panel()
	close_sign()


func _process(_delta):
	if is_sign_open():
		update_panel_position()


func setup_panel():
	if ui_layer_ref == null:
		return

	panel = ui_layer_ref.get_node_or_null("SignPanel")

	if panel == null:
		panel = Control.new()
		panel.name = "SignPanel"
		ui_layer_ref.add_child(panel)

	panel.size = Vector2(680, 468)
	panel.z_index = 130
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if panel is ColorRect:
		panel.color = Color(1, 1, 1, 0)

	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var panel_back = Panel.new()
	panel_back.name = "PanelBack"
	panel_back.position = Vector2.ZERO
	panel_back.size = panel.size
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_back.add_theme_stylebox_override("panel", PixelUIStyle.panel_style())
	panel.add_child(panel_back)

	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(16, 16)
	top_bar.size = Vector2(648, 64)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_stylebox_override("panel", PixelUIStyle.header_style())
	panel.add_child(top_bar)

	var title = Label.new()
	title.name = "Title"
	title.text = "EDIT SIGN"
	title.position = Vector2(34, 30)
	title.size = Vector2(300, 34)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_label_shadow(title, 27)
	panel.add_child(title)

	var close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.position = Vector2(616, 26)
	close_button.size = Vector2(42, 36)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_close_button(close_button)
	close_button.pressed.connect(close_sign)
	panel.add_child(close_button)

	var info_card = Panel.new()
	info_card.name = "InfoCard"
	info_card.position = Vector2(16, 94)
	info_card.size = Vector2(648, 52)
	info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.add_theme_stylebox_override("panel", PixelUIStyle.card_style())
	panel.add_child(info_card)

	var info_label = Label.new()
	info_label.name = "Info"
	info_label.text = "Write a message for players who stand on this sign."
	info_label.position = Vector2(34, 100)
	info_label.size = Vector2(612, 40)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(info_label, 15)
	panel.add_child(info_label)

	var input_back = Panel.new()
	input_back.name = "InputBack"
	input_back.position = Vector2(16, 160)
	input_back.size = Vector2(648, 220)
	input_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_back.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(input_back)

	var message_label := Label.new()
	message_label.name = "MessageLabel"
	message_label.text = "SIGN MESSAGE"
	message_label.position = Vector2(32, 172)
	message_label.size = Vector2(616, 24)
	PixelUIStyle.apply_small_label(message_label, 14)
	message_label.set_meta("pixelmania_font_size", 14)
	panel.add_child(message_label)

	var footer := Panel.new()
	footer.name = "Footer"
	footer.position = Vector2(16, 394)
	footer.size = Vector2(648, 58)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", PixelUIStyle.section_style())
	panel.add_child(footer)

	sign_text_edit = TextEdit.new()
	sign_text_edit.name = "SignText"
	sign_text_edit.position = Vector2(32, 200)
	sign_text_edit.size = Vector2(616, 164)
	sign_text_edit.placeholder_text = "Write sign text..."
	sign_text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	sign_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	sign_text_edit.scroll_fit_content_height = false
	apply_text_edit_style(sign_text_edit)
	sign_text_edit.text_changed.connect(update_char_count)
	panel.add_child(sign_text_edit)

	char_count_label = Label.new()
	char_count_label.name = "CharCount"
	char_count_label.position = Vector2(32, 410)
	char_count_label.size = Vector2(260, 24)
	char_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUIStyle.apply_small_label(char_count_label, 13)
	panel.add_child(char_count_label)

	var cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(380, 402)
	cancel_button.size = Vector2(126, 42)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_blue_button(cancel_button, 16)
	cancel_button.pressed.connect(close_sign)
	panel.add_child(cancel_button)

	var save_button = Button.new()
	save_button.name = "SaveButton"
	save_button.text = "SAVE"
	save_button.position = Vector2(522, 402)
	save_button.size = Vector2(126, 42)
	save_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUIStyle.apply_atlas_button(save_button, "green_button")
	save_button.pressed.connect(save_sign_text)
	panel.add_child(save_button)

	update_panel_position()
	update_char_count()


func apply_text_edit_style(text_edit: TextEdit):
	if text_edit == null:
		return

	text_edit.add_theme_font_size_override("font_size", 17)
	text_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	text_edit.add_theme_color_override("font_placeholder_color", Color(0.74, 0.82, 0.88, 0.78))
	text_edit.add_theme_color_override("caret_color", Color(1.0, 0.84, 0.22, 1.0))
	text_edit.add_theme_color_override("selection_color", Color(0.18, 0.45, 0.85, 0.55))

	text_edit.set_meta("pixelmania_font_size", 17)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("1c0b24")
	normal_style.border_color = Color("92659e")
	normal_style.set_border_width_all(2)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("e7c9ef")
	focus_style.set_border_width_all(2)

	text_edit.add_theme_stylebox_override("normal", normal_style)
	text_edit.add_theme_stylebox_override("focus", focus_style)
	text_edit.add_theme_stylebox_override("read_only", normal_style)


func open_sign(grid_pos: Vector2i, current_text: String):
	sign_grid_pos = grid_pos
	update_panel_position()

	if panel != null:
		panel.visible = true

	if sign_text_edit != null:
		sign_text_edit.text = current_text
		sign_text_edit.grab_focus()

	update_char_count()


func open_sign_editor(grid_pos: Vector2i, current_text: String = ""):
	open_sign(grid_pos, current_text)


func save_sign_text():
	if world != null and world.has_method("set_sign_text"):
		world.set_sign_text(sign_grid_pos, sign_text_edit.text)

	close_sign()


func close_sign():
	if panel != null:
		panel.visible = false

	if sign_text_edit != null:
		sign_text_edit.release_focus()


func is_sign_open() -> bool:
	return panel != null and panel.visible


func update_panel_position():
	if panel == null:
		return

	var screen_size = get_viewport_rect().size
	var fit_scale: float = minf(1.0, minf((screen_size.x - 24.0) / panel.size.x, (screen_size.y - 24.0) / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit_scale)
	panel.position = (screen_size - panel.size * panel.scale) / 2.0


func update_char_count():
	if char_count_label == null or sign_text_edit == null:
		return
	char_count_label.text = "Characters: " + str(sign_text_edit.text.length())


func is_sign_text_focused() -> bool:
	return sign_text_edit != null and sign_text_edit.has_focus()


func get_ui_texture(_file_name: String):
	return null


func add_texture_skin(_parent_node, _skin_name: String, _file_name: String, _skin_position: Vector2, _skin_size: Vector2):
	return null
