extends Button

func _draw() -> void:
	# Center a doubled pixel gift inside the square HUD button.
	draw_set_transform(((size - Vector2(58, 56)) * 0.5).floor(), 0, Vector2(2, 2))
	var origin := Vector2.ZERO
	draw_rect(Rect2(origin + Vector2(2, 9), Vector2(25, 18)), Color("824caa"))
	draw_rect(Rect2(origin + Vector2(0, 6), Vector2(29, 7)), Color("d8abe9"))
	draw_rect(Rect2(origin + Vector2(12, 6), Vector2(5, 21)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(5, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(17, 0), Vector2(8, 6)), Color("ffda79"))
	draw_rect(Rect2(origin + Vector2(7, 2), Vector2(4, 2)), Color("4c295e"))
	draw_rect(Rect2(origin + Vector2(19, 2), Vector2(4, 2)), Color("4c295e"))
