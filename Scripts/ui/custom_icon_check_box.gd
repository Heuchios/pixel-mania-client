@tool
extends CheckBox

@export_group("Custom Check Icons")
@export var custom_checked_icon: Texture2D:
	set(value):
		custom_checked_icon = value
		_apply_icon_override(&"checked", value)

@export var custom_unchecked_icon: Texture2D:
	set(value):
		custom_unchecked_icon = value
		_apply_icon_override(&"unchecked", value)


func _ready() -> void:
	if custom_checked_icon != null:
		add_theme_icon_override(&"checked", custom_checked_icon)
	if custom_unchecked_icon != null:
		add_theme_icon_override(&"unchecked", custom_unchecked_icon)


func _apply_icon_override(icon_name: StringName, icon_texture: Texture2D) -> void:
	if icon_texture == null:
		remove_theme_icon_override(icon_name)
		return
	add_theme_icon_override(icon_name, icon_texture)
