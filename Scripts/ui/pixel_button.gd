extends Button

@export var pixel_text: String = "BUTTON"
@export_enum("yellow", "blue", "green", "close", "tab", "custom") var button_style: String = "yellow"

@export var font_size: int = 18
@export var selected: bool = false
@export var auto_apply_style: bool = true
@export var min_size: Vector2 = Vector2(120, 42)

@export_group("Custom Style")
@export var custom_fill_color: Color = Color(1.0, 0.84, 0.05, 1.0)
@export var custom_hover_color: Color = Color(1.0, 0.94, 0.20, 1.0)
@export var custom_pressed_color: Color = Color(0.90, 0.58, 0.02, 1.0)
@export var custom_border_color: Color = Color(0.96, 0.50, 0.02, 1.0)
@export var custom_border_width: int = 5
@export var custom_corner_radius: int = 12
@export var custom_shadow_size: int = 6

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")


func _ready() -> void:
	text = pixel_text
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = min_size
	
	if auto_apply_style:
		apply_pixel_style()


func apply_pixel_style() -> void:
	match button_style:
		"yellow":
			PixelUIStyle.apply_yellow_button(self, font_size)
		"blue":
			PixelUIStyle.apply_blue_button(self, font_size)
		"green":
			PixelUIStyle.apply_green_button(self, font_size)
		"close":
			PixelUIStyle.apply_close_button(self)
		"tab":
			PixelUIStyle.apply_tab_button(self, selected, font_size)
		"custom":
			_apply_custom_style()
		_:
			PixelUIStyle.apply_yellow_button(self, font_size)


func _apply_custom_style() -> void:
	PixelUIStyle.apply_button_text(self, font_size, PixelUIStyle.TEXT_LIGHT)

	add_theme_stylebox_override(
		"normal",
		PixelUIStyle.style_box(custom_fill_color, custom_border_color, custom_border_width, custom_corner_radius, custom_shadow_size)
	)

	add_theme_stylebox_override(
		"hover",
		PixelUIStyle.style_box(custom_hover_color, custom_border_color, custom_border_width, custom_corner_radius, custom_shadow_size)
	)

	add_theme_stylebox_override(
		"pressed",
		PixelUIStyle.style_box(custom_pressed_color, custom_border_color, custom_border_width, custom_corner_radius, custom_shadow_size)
	)
