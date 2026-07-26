extends Control
class_name ItemActionPopup

signal use_requested(item: Dictionary)
signal drop_requested(item: Dictionary)
signal info_requested(item: Dictionary)
signal trash_requested(item: Dictionary)
signal closed

const MIN_AMOUNT := 1
const WINDOW_SIZE := Vector2(430.0, 326.0)
const VIEWPORT_MARGIN := 12.0

var item_data: Dictionary = {}
var amount: int = MIN_AMOUNT
var amount_limit: int = MIN_AMOUNT
var syncing_amount: bool = false

@onready var window: Control = get_node_or_null("Window") as Control
@onready var dismiss_area: Button = get_node_or_null("DismissArea") as Button
@onready var close_button: Button = get_node_or_null("Window/CloseButton") as Button
@onready var item_name_label: Label = get_node_or_null("Window/ItemName") as Label
@onready var item_count_label: Label = get_node_or_null("Window/ItemCount") as Label
@onready var item_icon_shadow: TextureRect = get_node_or_null("Window/PreviewSlot/IconShadow") as TextureRect
@onready var item_icon: TextureRect = get_node_or_null("Window/PreviewSlot/Icon") as TextureRect
@onready var amount_label: Label = get_node_or_null("Window/AmountLabel") as Label
@onready var amount_input: LineEdit = get_node_or_null("Window/AmountInput") as LineEdit
@onready var amount_slider: HSlider = get_node_or_null("Window/AmountSlider") as HSlider
@onready var use_button: Button = get_node_or_null("Window/UseButton") as Button
@onready var drop_button: Button = get_node_or_null("Window/DropButton") as Button
@onready var info_button: Button = get_node_or_null("Window/InfoButton") as Button
@onready var trash_button: Button = get_node_or_null("Window/TrashButton") as Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if dismiss_area != null:
		dismiss_area.pressed.connect(_on_close_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	if amount_input != null:
		amount_input.text_changed.connect(_on_amount_text_changed)
		amount_input.text_submitted.connect(_on_amount_text_submitted)
		amount_input.focus_exited.connect(_sync_amount_controls)
	if amount_slider != null:
		amount_slider.value_changed.connect(_on_amount_slider_changed)
	if use_button != null:
		use_button.pressed.connect(_on_use_pressed)
	if drop_button != null:
		drop_button.pressed.connect(_on_drop_pressed)
	if info_button != null:
		info_button.pressed.connect(_on_info_pressed)
	if trash_button != null:
		trash_button.pressed.connect(_on_trash_pressed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func open_popup(item: Dictionary, icon_texture: Texture2D = null, anchor_position: Vector2 = Vector2.ZERO) -> void:
	item_data = item.duplicate(true)
	amount_limit = maxi(MIN_AMOUNT, int(item_data.get("count", item_data.get("available_count", MIN_AMOUNT))))
	amount = MIN_AMOUNT
	_update_item_preview(icon_texture)
	_sync_amount_controls()
	_update_action_state()
	visible = true
	move_to_front()
	call_deferred("_position_window", anchor_position)


func close_popup(emit_closed: bool = true) -> void:
	if not visible and item_data.is_empty():
		return
	visible = false
	if amount_input != null:
		amount_input.release_focus()
	item_data.clear()
	if emit_closed:
		closed.emit()


func is_open() -> bool:
	return visible and not item_data.is_empty()


func _position_window(anchor_position: Vector2) -> void:
	if window == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_position: Vector2
	if anchor_position == Vector2.ZERO:
		target_position = (viewport_size - WINDOW_SIZE) * 0.5
	elif OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		target_position = anchor_position + Vector2(-WINDOW_SIZE.x * 0.5, -WINDOW_SIZE.y - 24.0)
	else:
		target_position = anchor_position + Vector2(18.0, -WINDOW_SIZE.y * 0.42)
	target_position.x = clampf(target_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - WINDOW_SIZE.x - VIEWPORT_MARGIN))
	target_position.y = clampf(target_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - WINDOW_SIZE.y - VIEWPORT_MARGIN))
	window.position = target_position


func _update_item_preview(icon_texture: Texture2D) -> void:
	var display_name: String = str(item_data.get("display_name", item_data.get("name", item_data.get("id", "Item")))).strip_edges()
	if display_name == "":
		display_name = "Item"
	if item_name_label != null:
		item_name_label.text = display_name
		var title_size: int = 19
		if display_name.length() > 32:
			title_size = 13
		elif display_name.length() > 23:
			title_size = 16
		item_name_label.add_theme_font_size_override("font_size", title_size)
	if item_count_label != null:
		item_count_label.text = "AVAILABLE  x" + str(amount_limit)
	if item_icon_shadow != null:
		item_icon_shadow.texture = icon_texture
		item_icon_shadow.visible = icon_texture != null
	if item_icon != null:
		item_icon.texture = icon_texture
		item_icon.visible = icon_texture != null


func _update_action_state() -> void:
	var can_use: bool = bool(item_data.get("can_use", true))
	var can_drop: bool = bool(item_data.get("can_drop", true))
	var can_trash: bool = bool(item_data.get("can_trash", true))
	if use_button != null:
		use_button.disabled = not can_use
	if drop_button != null:
		drop_button.disabled = not can_drop
	if info_button != null:
		info_button.disabled = false
	if trash_button != null:
		trash_button.disabled = not can_trash
	var amount_editable: bool = amount_limit > MIN_AMOUNT and (can_drop or can_trash)
	if amount_input != null:
		amount_input.editable = can_drop or can_trash
	if amount_slider != null:
		amount_slider.editable = amount_editable


func _sync_amount_controls() -> void:
	if syncing_amount:
		return
	amount = clampi(amount, MIN_AMOUNT, amount_limit)
	syncing_amount = true
	if amount_label != null:
		amount_label.text = "AMOUNT  " + str(amount) + " / " + str(amount_limit)
	if amount_input != null:
		amount_input.text = str(amount)
		amount_input.caret_column = amount_input.text.length()
	if amount_slider != null:
		amount_slider.min_value = float(MIN_AMOUNT)
		amount_slider.max_value = float(amount_limit)
		amount_slider.step = 1.0
		amount_slider.rounded = true
		amount_slider.value = float(amount)
	syncing_amount = false


func _on_amount_text_changed(new_text: String) -> void:
	if syncing_amount:
		return
	var clean_text: String = new_text.strip_edges()
	if clean_text == "":
		return
	if not clean_text.is_valid_int():
		_sync_amount_controls()
		return
	amount = clampi(int(clean_text), MIN_AMOUNT, amount_limit)
	_sync_amount_controls()


func _on_amount_text_submitted(_new_text: String) -> void:
	_sync_amount_controls()


func _on_amount_slider_changed(value: float) -> void:
	if syncing_amount:
		return
	amount = clampi(int(round(value)), MIN_AMOUNT, amount_limit)
	_sync_amount_controls()


func _payload_with_amount() -> Dictionary:
	var payload: Dictionary = item_data.duplicate(true)
	payload["amount"] = amount
	payload["drop_amount"] = amount
	return payload


func _emit_action(action_signal: Signal) -> void:
	var payload: Dictionary = _payload_with_amount()
	close_popup()
	action_signal.emit(payload)


func _on_use_pressed() -> void:
	_emit_action(use_requested)


func _on_drop_pressed() -> void:
	_emit_action(drop_requested)


func _on_info_pressed() -> void:
	_emit_action(info_requested)


func _on_trash_pressed() -> void:
	_emit_action(trash_requested)


func _on_close_pressed() -> void:
	close_popup()
