extends Button

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")

func _ready() -> void:
	text = "DAILY REWARDS"
	custom_minimum_size = Vector2(272, 48)
	set_meta(Style.GLOBAL_FONT_ROLE_META, "body")
	Style.apply_global_typography_to_node(self)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := get_theme_stylebox(state).duplicate() as StyleBoxTexture
		box.content_margin_left = 44
		box.content_margin_right = 8
		add_theme_stylebox_override(state, box)

func _draw() -> void:
	# Keep the small pixel gift alongside the label as the whole button scales.
	var origin := Vector2(12, (size.y - 28) * 0.5)
	draw_rect(Rect2(origin + Vector2(2, 9), Vector2(25, 18)), Color("824caa"))
	draw_rect(Rect2(origin + Vector2(0, 6), Vector2(29, 7)), Color("d8abe9"))
	draw_rect(Rect2(origin + Vector2(12, 6), Vector2(5, 21)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(5, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(17, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(7, 2), Vector2(4, 2)), Color("4c295e"))
	draw_rect(Rect2(origin + Vector2(19, 2), Vector2(4, 2)), Color("4c295e"))
