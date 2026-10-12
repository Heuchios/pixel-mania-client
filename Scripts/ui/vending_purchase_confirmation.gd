extends Control
signal confirmed
signal canceled
var dialog_text := ""
var title := "PURCHASE CONFIRMATION"
var ok_button_text := "CONFIRM"
var cancel_button_text := "CANCEL"
var card: Panel
var message: Label
const PixelStyle = preload("res://Scripts/ui/pixel_ui_style.gd")
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.name = "Dimmer"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.65)
	add_child(shade)
	card = Panel.new()
	card.size = Vector2(620, 440)
	card.add_theme_stylebox_override("panel", PixelStyle.panel_style())
	add_child(card)
	var inner := Panel.new()
	inner.position = Vector2(16, 16)
	inner.size = Vector2(588, 328)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", PixelStyle.section_style())
	card.add_child(inner)
	var heading := Label.new()
	heading.name = "Title"
	heading.text = title
	heading.position = Vector2(32, 30)
	heading.size = Vector2(550, 34)
	heading.set_meta("pixelmania_font_size", 24)
	PixelStyle.apply_label_shadow(heading, 24)
	card.add_child(heading)
	message = Label.new()
	message.position = Vector2(32, 88)
	message.size = Vector2(550, 242)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_meta("pixelmania_font_size", 20)
	PixelStyle.apply_small_label(message, 20)
	card.add_child(message)
	for index in range(2):
		var button := Button.new()
		button.name = "CancelButton" if index == 0 else "BuyButton"
		button.text = cancel_button_text if index == 0 else ok_button_text
		button.position = Vector2(32 + index * 284, 370)
		button.size = Vector2(268, 46)
		PixelStyle.apply_atlas_button(button, "blue_button" if index == 0 else "green_button")
		if index == 0: button.pressed.connect(_cancel)
		else: button.pressed.connect(_confirm)
		card.add_child(button)
	hide()
func popup_centered(_requested_size := Vector2i.ZERO):
	message.text = dialog_text
	card.get_node("Title").text = title
	card.get_node("BuyButton").text = ok_button_text
	card.get_node("CancelButton").text = cancel_button_text
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
		_cancel()
		get_viewport().set_input_as_handled()

func _confirm() -> void:
	if not visible: return
	hide()
	confirmed.emit()

func _cancel() -> void:
	if not visible: return
	hide()
	canceled.emit()

