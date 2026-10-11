extends Button

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
