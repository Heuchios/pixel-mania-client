extends Control
signal confirmed
var dialog_text := ""
var card: Panel
var message: Label
const PixelStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.65)
	add_child(shade)
	card = Panel.new()
	card.size = Vector2(620, 320)
	card.add_theme_stylebox_override("panel", PixelStyle.panel_style())
	add_child(card)
	var inner := Panel.new()
	inner.position = Vector2(16, 16)
	inner.size = Vector2(588, 218)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelStyle.section_style())
	card.add_child(inner)
	var title := Label.new()
	title.text = "CONFIRM PURCHASE"
	title.position = Vector2(32, 30)
	title.size = Vector2(550, 34)
	title.set_meta("pixelmania_font_size", 24)
	PixelStyle.apply_label_shadow(title, 24)
	card.add_child(title)
	message = Label.new()
	message.position = Vector2(32, 88)
	message.size = Vector2(550, 126)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_meta("pixelmania_font_size", 20)
	PixelStyle.apply_small_label(message, 20)
	card.add_child(message)
	for index in range(2):
		var button := Button.new()
		button.name = "CancelButton" if index == 0 else "BuyButton"
		button.text = "CANCEL" if index == 0 else "BUY"
		button.position = Vector2(32 + index * 284, 254)
		button.size = Vector2(268, 46)
		PixelStyle.apply_atlas_button(button, "blue_button" if index == 0 else "green_button")
		if index == 0: button.pressed.connect(hide)
		else: button.pressed.connect(func(): hide(); confirmed.emit())
		card.add_child(button)
	hide()
func popup_centered(_requested_size := Vector2i.ZERO):
	message.text = dialog_text
	show()
	_fit()
	card.get_node("CancelButton").grab_focus()
func _process(_delta):
	if visible: _fit()
func _fit():
	var screen := get_viewport_rect().size
	var factor := minf(1.0, minf((screen.x - 24) / card.size.x, (screen.y - 24) / card.size.y))
	card.scale = Vector2.ONE * maxf(0.1, factor)
	card.position = (screen - card.size * card.scale) * 0.5
func _unhandled_key_input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

