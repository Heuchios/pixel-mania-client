extends Control
class_name InventoryUpgradeConfirm

signal confirmed(upgrade_data: Dictionary)
signal cancelled
signal close_requested

var upgrade_data: Dictionary = {}

@onready var title_label: Label = get_node_or_null("Window/TitleLabel") as Label
@onready var slots_label: Label = get_node_or_null("Window/SlotsLabel") as Label
@onready var cost_label: Label = get_node_or_null("Window/CostLabel") as Label
@onready var message_label: Label = get_node_or_null("Window/MessageLabel") as Label
@onready var confirm_button: Button = get_node_or_null("Window/ConfirmButton") as Button
@onready var cancel_button: Button = get_node_or_null("Window/CancelButton") as Button
@onready var close_button: Button = get_node_or_null("Window/CloseButton") as Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	configure(upgrade_data)


func open(data: Dictionary = {}) -> void:
	configure(data)
	visible = true
	if confirm_button != null:
		confirm_button.grab_focus()


func configure(data: Dictionary = {}) -> void:
	upgrade_data = data.duplicate(true) if data is Dictionary else {}
	var current_slots: int = int(upgrade_data.get("current_slots", upgrade_data.get("inventory_slot_count", 20)))
	var next_slots: int = int(upgrade_data.get("next_slots", upgrade_data.get("next_inventory_slot_count", min(current_slots + 20, 300))))
	var cost: int = int(upgrade_data.get("cost", upgrade_data.get("inventory_upgrade_cost", 0)))

	if title_label != null:
		title_label.text = "INVENTORY UPGRADE"
	if slots_label != null:
		slots_label.text = str(current_slots) + " slots  >  " + str(next_slots) + " slots"
	if cost_label != null:
		cost_label.text = _format_gems(cost) + " gems"
	if message_label != null:
		message_label.text = "Buy 20 more inventory slots?"
	if confirm_button != null:
		confirm_button.text = "BUY"
	if cancel_button != null:
		cancel_button.text = "CANCEL"


func close_popup(emit_close: bool = true) -> void:
	visible = false
	if emit_close:
		close_requested.emit()


func _format_gems(value: int) -> String:
	var digits: String = str(max(0, value))
	var result: String = ""
	var group_count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1
	return result


func _on_confirm_pressed() -> void:
	confirmed.emit(upgrade_data.duplicate(true))
	close_popup(false)


func _on_cancel_pressed() -> void:
	cancelled.emit()
	close_popup()


func _on_close_pressed() -> void:
	cancelled.emit()
	close_popup()
