extends Button

const Style = preload("res://Scripts/ui/pixel_ui_style.gd")

func _ready() -> void:
	set_meta(Style.GLOBAL_FONT_ROLE_META, "body")
	Style.apply_global_typography_to_node(self)
	# Reserve room for the gift and the ready indicator at the shared text size.
	var text_width := get_theme_font("font").get_string_size("DAILY REWARDS  !", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.DEFAULT_TEXT_FONT_SIZE).x
	custom_minimum_size = Vector2(ceilf(text_width + 60), 48)

func _draw() -> void:
	# Small pixel gift, drawn natively so it stays crisp at every HUD scale.
	var origin := Vector2(12, (size.y - 28) * 0.5)
	draw_rect(Rect2(origin + Vector2(2, 9), Vector2(25, 18)), Color("824caa"))
	draw_rect(Rect2(origin + Vector2(0, 6), Vector2(29, 7)), Color("d8abe9"))
	draw_rect(Rect2(origin + Vector2(12, 6), Vector2(5, 21)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(5, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(17, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(7, 2), Vector2(4, 2)), Color("4c295e"))
	draw_rect(Rect2(origin + Vector2(19, 2), Vector2(4, 2)), Color("4c295e"))
