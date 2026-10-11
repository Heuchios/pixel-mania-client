extends Control

var celebration := false
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var center := size * Vector2(0.5, 0.43)
	if celebration:
		for i in range(16):
			var angle := float(i) * TAU / 16.0 + elapsed * 0.12
			var radius := minf(size.x, size.y) * 0.36
			var points := PackedVector2Array([center, center + Vector2.from_angle(angle) * radius, center + Vector2.from_angle(angle + 0.12) * radius])
			draw_colored_polygon(points, Color(1.0, 0.85, 0.48, 0.09))
		for i in range(36):
			var t := fposmod(elapsed * 0.22 + i * 0.029, 1.0)
			var point := Vector2(fposmod(i * 131.0, size.x), t * size.y)
			draw_rect(Rect2(point, Vector2(4, 7)), Color("ffe295") if i % 2 else Color("ba9dff"))
