extends Control
class_name ItemActionPopup

signal use_requested(item: Dictionary)
signal drop_requested(item: Dictionary)
signal info_requested(item: Dictionary)
signal trash_requested(item: Dictionary)
signal closed

const MIN_AMOUNT := 1
const WINDOW_BASE_SIZE := Vector2(430.0, 300.0)
const WINDOW_RENDER_SCALE := 1.35
const WINDOW_SIZE := WINDOW_BASE_SIZE * WINDOW_RENDER_SCALE
const VIEWPORT_MARGIN := 12.0
const ANCHOR_GAP := 12.0
const OPEN_ANIMATION_SECONDS := 0.14
const CLOSE_ANIMATION_SECONDS := 0.10

var item_data: Dictionary = {}
var amount: int = MIN_AMOUNT
var amount_limit: int = MIN_AMOUNT
var syncing_amount: bool = false
var popup_tween: Tween = null
var window_base_scale := Vector2(WINDOW_RENDER_SCALE, WINDOW_RENDER_SCALE)

@onready var window: Control = get_node_or_null("Window") as Control
@onready var dismiss_area: Button = get_node_or_null("DismissArea") as Button
@onready var close_button: Button = get_node_or_null("Window/CloseButton") as Button
@onready var item_name_label: Label = get_node_or_null("Window/ItemName") as Label
@onready var item_count_label: Label = get_node_or_null("Window/ItemCount") as Label
@onready var item_type_label: Label = get_node_or_null("Window/TypeLabel") as Label
@onready var item_rarity_label: Label = get_node_or_null("Window/RarityLabel") as Label
@onready var item_spliceable_label: Label = get_node_or_null("Window/SpliceableLabel") as Label
@onready var more_details_label: Label = get_node_or_null("Window/MoreDetailsLabel") as Label
@onready var description_label: Label = get_node_or_null("Window/DescriptionLabel") as Label
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
	if window != null:
		window.mouse_filter = Control.MOUSE_FILTER_STOP
		window_base_scale = window.scale
		window.pivot_offset = window.size * Vector2(0.5, 1.0)
		if not window.gui_input.is_connected(_on_modal_gui_input):
			window.gui_input.connect(_on_modal_gui_input)
	_set_popup_visible(false)
	if dismiss_area != null:
		dismiss_area.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if _try_handle_close_pointer_event(event):
		return
	if _try_consume_modal_pointer_event(event):
		return
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and item_data.is_empty():
		call_deferred("_hide_popup_immediate", false)


func open_popup(item: Dictionary, icon_texture: Texture2D = null, anchor_position: Vector2 = Vector2.ZERO) -> void:
	if not _is_valid_popup_item(item):
		close_popup(false)
		return
	item_data = item.duplicate(true)
	amount_limit = maxi(MIN_AMOUNT, int(item_data.get("count", item_data.get("available_count", MIN_AMOUNT))))
	amount = MIN_AMOUNT
	_update_item_preview(icon_texture)
	_update_item_facts()
	_sync_amount_controls()
	_update_action_state()
	_set_popup_visible(true)
	move_to_front()
	call_deferred("_position_window_and_play_open", anchor_position)


func close_popup(emit_closed: bool = true) -> void:
	var should_emit_closed := emit_closed and (visible or not item_data.is_empty())
	if not visible:
		_hide_popup_immediate(true)
		return
	if amount_input != null:
		amount_input.release_focus()
	_play_close_animation(should_emit_closed)


func is_open() -> bool:
	return visible and not item_data.is_empty()


func owns_pointer_position(point: Vector2) -> bool:
	if not visible:
		return false
	var root_rect: Rect2 = get_global_rect()
	if root_rect.size.x <= 0.0 or root_rect.size.y <= 0.0:
		root_rect = Rect2(Vector2.ZERO, get_viewport_rect().size)
	return root_rect.has_point(point)


func owns_pointer_event(event: InputEvent) -> bool:
	var pointer_position: Vector2 = _get_pointer_event_position(event)
	if pointer_position == Vector2.INF:
		return false
	return owns_pointer_position(pointer_position)


func _process(_delta: float) -> void:
	if visible and item_data.is_empty():
		_hide_popup_immediate(false)


func _is_valid_popup_item(item: Dictionary) -> bool:
	var item_type := str(item.get("item_type", item.get("type", item.get("id", "")))).strip_edges()
	var category := str(item.get("item_category", item.get("category", ""))).strip_edges()
	return item_type != "" and category != "" and category != "empty"


func _set_popup_visible(should_show: bool) -> void:
	visible = should_show
	if window != null:
		window.visible = should_show
	if dismiss_area != null:
		dismiss_area.visible = should_show
	var dimmer := get_node_or_null("Dimmer") as CanvasItem
	if dimmer != null:
		dimmer.visible = should_show


func _hide_popup_immediate(clear_item_data: bool = false) -> void:
	_kill_popup_tween()
	_set_popup_visible(false)
	if window != null:
		window.scale = window_base_scale
		window.modulate.a = 1.0
	if amount_input != null:
		amount_input.release_focus()
	if clear_item_data:
		item_data.clear()


func _kill_popup_tween() -> void:
	if popup_tween != null:
		if popup_tween.is_valid():
			popup_tween.kill()
		popup_tween = null


func _try_handle_close_pointer_event(event: InputEvent) -> bool:
	if close_button == null:
		return false
	var pointer_position := Vector2.ZERO
	var should_check := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		should_check = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
		pointer_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		should_check = touch_event.pressed
		pointer_position = touch_event.position
	if not should_check:
		return false
	if not close_button.get_global_rect().has_point(pointer_position):
		return false
	close_popup()
	get_viewport().set_input_as_handled()
	return true


func _try_consume_modal_pointer_event(event: InputEvent) -> bool:
	var pointer_position: Vector2 = _get_pointer_event_position(event)
	if pointer_position == Vector2.INF:
		return false
	if not _get_scaled_window_global_rect().has_point(pointer_position):
		return false
	if _is_pointer_over_interactive_control(pointer_position):
		return false
	get_viewport().set_input_as_handled()
	return true


func _get_pointer_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.INF


func _get_scaled_window_global_rect() -> Rect2:
	if window == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var scaled_size := Vector2(absf(window.size.x * window.scale.x), absf(window.size.y * window.scale.y))
	return Rect2(window.global_position, scaled_size)


func _is_pointer_over_interactive_control(point: Vector2) -> bool:
	for control in [
		close_button,
		amount_input,
		amount_slider,
		use_button,
		drop_button,
		info_button,
		trash_button
	]:
		if _control_contains_screen_point(control as Control, point):
			return true
	return false


func _control_contains_screen_point(control: Control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.has_point(point)


func _on_modal_gui_input(event: InputEvent) -> void:
	if _get_pointer_event_position(event) == Vector2.INF:
		return
	accept_event()
	get_viewport().set_input_as_handled()


func _position_window_and_play_open(anchor_position: Vector2) -> void:
	if not visible or item_data.is_empty():
		return
	_position_window(anchor_position)
	_play_open_animation()


func _position_window(anchor_position: Vector2) -> void:
	if window == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_position: Vector2
	if anchor_position == Vector2.ZERO:
		target_position = (viewport_size - WINDOW_SIZE) * 0.5
	else:
		target_position = Vector2(anchor_position.x - WINDOW_SIZE.x * 0.5, anchor_position.y - WINDOW_SIZE.y - ANCHOR_GAP)
		if target_position.y < VIEWPORT_MARGIN:
			target_position.y = anchor_position.y + ANCHOR_GAP
	target_position.x = clampf(target_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - WINDOW_SIZE.x - VIEWPORT_MARGIN))
	target_position.y = clampf(target_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - WINDOW_SIZE.y - VIEWPORT_MARGIN))
	window.position = target_position


func _play_open_animation() -> void:
	if window == null:
		return
	_kill_popup_tween()
	window.pivot_offset = window.size * Vector2(0.5, 1.0)
	window.scale = window_base_scale * 0.9
	window.modulate.a = 0.0
	popup_tween = create_tween()
	popup_tween.set_parallel(true)
	popup_tween.tween_property(window, "scale", window_base_scale, OPEN_ANIMATION_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(window, "modulate:a", 1.0, OPEN_ANIMATION_SECONDS * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_close_animation(emit_closed: bool) -> void:
	if window == null:
		item_data.clear()
		_set_popup_visible(false)
		if emit_closed:
			closed.emit()
		return
	_kill_popup_tween()
	window.pivot_offset = window.size * Vector2(0.5, 1.0)
	popup_tween = create_tween()
	var closing_tween: Tween = popup_tween
	closing_tween.set_parallel(true)
	closing_tween.tween_property(window, "scale", window_base_scale * 0.92, CLOSE_ANIMATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	closing_tween.tween_property(window, "modulate:a", 0.0, CLOSE_ANIMATION_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	closing_tween.finished.connect(func() -> void:
		if popup_tween != closing_tween:
			return
		popup_tween = null
		item_data.clear()
		_set_popup_visible(false)
		window.scale = window_base_scale
		window.modulate.a = 1.0
		if emit_closed:
			closed.emit()
	)


func _update_item_preview(icon_texture: Texture2D) -> void:
	var display_name: String = str(item_data.get("display_name", item_data.get("name", item_data.get("id", "Item")))).strip_edges()
	if display_name == "":
		display_name = "Item"
	if item_name_label != null:
		item_name_label.text = display_name + " (" + str(amount_limit) + "x)"
		var title_size: int = 19
		if item_name_label.text.length() > 32:
			title_size = 13
		elif item_name_label.text.length() > 23:
			title_size = 16
		item_name_label.add_theme_font_size_override("font_size", title_size)
	if item_count_label != null:
		item_count_label.text = "AVAILABLE  x" + str(amount_limit)
		item_count_label.visible = false
	if item_icon_shadow != null:
		item_icon_shadow.texture = icon_texture
		item_icon_shadow.visible = icon_texture != null
	if item_icon != null:
		item_icon.texture = icon_texture
		item_icon.visible = icon_texture != null


func _update_item_facts() -> void:
	var category := _display_case_text(str(item_data.get("type_label", item_data.get("category", "Item"))))
	var rarity := _display_case_text(str(item_data.get("rarity", "common")))
	var spliceable := bool(item_data.get("spliceable", false))
	var description := str(item_data.get("description", "")).strip_edges()
	if description == "":
		description = category + " item ready for the active inventory action."

	if item_type_label != null:
		item_type_label.text = "Type: " + category
	if item_rarity_label != null:
		item_rarity_label.text = "Rarity: " + rarity
	if item_spliceable_label != null:
		item_spliceable_label.text = "Spliceable: " + ("Yes" if spliceable else "No")
	if more_details_label != null:
		more_details_label.text = "... (More details)"
	if description_label != null:
		description_label.text = description


func _display_case_text(raw_text: String) -> String:
	var clean_text := raw_text.strip_edges().replace("_", " ")
	if clean_text == "":
		return "Item"
	return clean_text.capitalize()


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
