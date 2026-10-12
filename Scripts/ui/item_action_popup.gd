extends Control
class_name ItemActionPopup

signal closed

const WINDOW_BASE_SIZE := Vector2(430.0, 366.0)
const WINDOW_RENDER_SCALE := 1.35
const VIEWPORT_MARGIN := 12.0
const ANCHOR_GAP := 12.0

var item_data: Dictionary = {}
var amount_limit := 1
var window_base_scale := Vector2(WINDOW_RENDER_SCALE, WINDOW_RENDER_SCALE)
var last_anchor_position := Vector2.ZERO

@onready var window: Control = get_node_or_null("Window") as Control
@onready var dismiss_area: Button = get_node_or_null("DismissArea") as Button
@onready var close_button: Button = get_node_or_null("Window/CloseButton") as Button
@onready var item_name_label: Label = get_node_or_null("Window/ItemName") as Label
@onready var item_count_label: Label = get_node_or_null("Window/ItemCount") as Label
@onready var item_type_label: Label = get_node_or_null("Window/TypeLabel") as Label
@onready var item_rarity_label: Label = get_node_or_null("Window/RarityLabel") as Label
@onready var item_spliceable_label: Label = get_node_or_null("Window/SpliceableLabel") as Label
@onready var item_properties_label: Label = get_node_or_null("Window/PropertiesLabel") as Label
@onready var item_farmable_label: Label = get_node_or_null("Window/FarmableLabel") as Label
@onready var description_label: RichTextLabel = get_node_or_null("Window/DescriptionLabel") as RichTextLabel
@onready var item_icon_shadow: TextureRect = get_node_or_null("Window/PreviewSlot/IconShadow") as TextureRect
@onready var item_icon: TextureRect = get_node_or_null("Window/PreviewSlot/Icon") as TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if window != null:
		window.mouse_filter = Control.MOUSE_FILTER_STOP
		window_base_scale = window.scale
		window.size = WINDOW_BASE_SIZE
		window.pivot_offset = Vector2.ZERO
		if not window.gui_input.is_connected(_on_modal_gui_input):
			window.gui_input.connect(_on_modal_gui_input)
	_set_popup_visible(false)
	if dismiss_area != null:
		dismiss_area.mouse_filter = Control.MOUSE_FILTER_STOP
		dismiss_area.pressed.connect(_on_close_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	if is_open():
		window.modulate.a = 1.0
		_position_window(last_anchor_position)


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
		call_deferred("_hide_invalid_popup")


func _hide_invalid_popup() -> void:
	# A selection can arrive in the same frame that the popup is instantiated.
	# Recheck before hiding so the deferred initial visibility event cannot close it.
	if visible and item_data.is_empty():
		_hide_popup_immediate(false)


func open_popup(item: Dictionary, icon_texture: Texture2D = null, anchor_position: Vector2 = Vector2.ZERO) -> void:
	if not _is_valid_popup_item(item):
		close_popup(false)
		return
	item_data = item.duplicate(true)
	amount_limit = maxi(1, int(item_data.get("count", item_data.get("available_count", 1))))
	_update_item_preview(icon_texture)
	_update_item_facts()
	_position_window(anchor_position)
	_set_popup_visible(true)
	move_to_front()
	get_node("/root/WindowTransitions").present(window)


func close_popup(emit_closed: bool = true) -> void:
	var should_emit_closed := emit_closed and (visible or not item_data.is_empty())
	if not visible:
		_hide_popup_immediate(true)
		return
	_hide_popup_immediate(true)
	if should_emit_closed:
		closed.emit()


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
	_set_popup_visible(false)
	if window != null:
		window.scale = window_base_scale
		window.modulate.a = 1.0
	if clear_item_data:
		item_data.clear()


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
	for control in [close_button, description_label]:
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


func _position_window(anchor_position: Vector2) -> void:
	if window == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	last_anchor_position = anchor_position
	var fit_scale := minf(WINDOW_RENDER_SCALE, minf(
		(viewport_size.x - VIEWPORT_MARGIN * 2.0) / WINDOW_BASE_SIZE.x,
		(viewport_size.y - VIEWPORT_MARGIN * 2.0) / WINDOW_BASE_SIZE.y))
	window_base_scale = Vector2.ONE * maxf(0.1, fit_scale)
	window.scale = window_base_scale
	var rendered_size := WINDOW_BASE_SIZE * window_base_scale
	var target_position: Vector2
	if anchor_position == Vector2.ZERO:
		target_position = (viewport_size - rendered_size) * 0.5
	else:
		target_position = Vector2(anchor_position.x - rendered_size.x * 0.5, anchor_position.y - rendered_size.y - ANCHOR_GAP)
		if target_position.y < VIEWPORT_MARGIN:
			target_position.y = anchor_position.y + ANCHOR_GAP
	target_position.x = clampf(target_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - rendered_size.x - VIEWPORT_MARGIN))
	target_position.y = clampf(target_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - rendered_size.y - VIEWPORT_MARGIN))
	window.position = target_position


func _update_item_preview(icon_texture: Texture2D) -> void:
	var display_name: String = str(item_data.get("display_name", item_data.get("name", item_data.get("id", "Item")))).strip_edges()
	if display_name == "":
		display_name = "Item"
	if item_name_label != null:
		item_name_label.text = display_name
		item_name_label.tooltip_text = display_name
		var title_size: int = 24
		if item_name_label.text.length() > 32:
			title_size = 13
		elif item_name_label.text.length() > 23:
			title_size = 16
		item_name_label.add_theme_font_size_override("font_size", title_size)
		item_name_label.set_meta("pixelmania_font_size", title_size)
	if item_count_label != null:
		item_count_label.text = _quantity_text(amount_limit) + " IN INVENTORY"
		item_count_label.visible = true
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
		description = "A " + category.to_lower() + " item."

	if item_type_label != null:
		item_type_label.text = "Type: " + category
	if item_rarity_label != null:
		item_rarity_label.text = "Rarity: " + rarity
	if item_spliceable_label != null:
		item_spliceable_label.text = "Spliceable: " + ("Yes" if spliceable else "No")
		item_spliceable_label.tooltip_text = "Its seed is used in or produced by a splice recipe."
	if item_properties_label != null:
		item_properties_label.text = "Has Properties: " + ("Yes" if bool(item_data.get("has_properties", false)) else "No")
		item_properties_label.tooltip_text = "Has a special gameplay effect or function."
	if item_farmable_label != null:
		item_farmable_label.text = "Farmable: " + ("Yes" if bool(item_data.get("farmable", false)) else "No")
		item_farmable_label.tooltip_text = "Its seed grows a tree that returns blocks and seeds for replanting."
	if description_label != null:
		description_label.text = description
		description_label.scroll_to_line(0)
		description_label.tooltip_text = description


func _display_case_text(raw_text: String) -> String:
	var clean_text := raw_text.strip_edges().replace("_", " ")
	if clean_text == "":
		return "Item"
	return clean_text.capitalize()


func _is_fish() -> bool:
	return str(item_data.get("item_category", item_data.get("category", ""))) == "fish"


func _quantity_text(units: int) -> String:
	return ("%.1f kg" % (units / 10.0)) if _is_fish() else str(units)


func _on_close_pressed() -> void:
	close_popup()
