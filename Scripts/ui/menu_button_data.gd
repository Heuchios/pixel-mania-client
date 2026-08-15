extends Resource
class_name PixelMenuButtonData

@export var label: String = "BUTTON"
@export var action_id: String = "button"
@export var icon_texture: Texture2D = null
@export_enum("blue", "yellow", "green", "red", "custom") var button_style: String = "blue"
@export var tooltip: String = ""
@export var selected: bool = false
@export var disabled: bool = false
@export var visible: bool = true
@export var custom_fill_color: Color = Color(0.12, 0.28, 0.40, 0.78)
@export var custom_hover_color: Color = Color(0.18, 0.38, 0.52, 0.86)
@export var custom_pressed_color: Color = Color(0.08, 0.20, 0.30, 0.92)
@export var custom_border_color: Color = Color(0.42, 0.78, 1.0, 0.62)
@export var metadata: Dictionary = {}
