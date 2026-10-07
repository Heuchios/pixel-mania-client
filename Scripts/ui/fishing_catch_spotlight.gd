extends Control
## Staggered rising glints, confined to the artwork instead of a radial burst.
var accent := Color.GOLD
var phase := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func restart() -> void:
	phase = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	phase += delta
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var reveal := clampf(phase / 0.45, 0.0, 1.0)
	for i in range(12):
		var life := fposmod(phase / (2.2 + (i % 3) * 0.3) + i * 0.618, 1.0)
		var shimmer := sin(life * PI)
		var side := -1.0 if i % 2 == 0 else 1.0
		var point := (center + Vector2(side * (55.0 + (i % 5) * 17.0) + sin(phase + i) * 5.0, 70.0 - life * 140.0)).round()
		var color := Color(accent.lightened(0.7), shimmer * shimmer * 0.85 * reveal)
		# A faint halo, a colored pixel, and an occasional white glint.
		draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color(color, color.a * 0.12))
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), color)
		if i % 3 == 0:
			draw_rect(Rect2(point - Vector2(1, 5), Vector2(2, 10)), Color(color, color.a * 0.65))
			draw_rect(Rect2(point - Vector2(5, 1), Vector2(10, 2)), Color(color, color.a * 0.65))
			draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, color.a))
