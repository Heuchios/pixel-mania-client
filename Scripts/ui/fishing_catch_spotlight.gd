extends Control
## Subtle rarity-colored rays behind the catch artwork.
var accent := Color.GOLD
var phase := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase += delta
	queue_redraw()
func _draw() -> void:
	var center := size * 0.5
	for i in range(12):
		var angle := float(i) * TAU / 12.0 + sin(phase * 0.3) * 0.04
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal()
		var length := 105.0 + sin(phase * 1.6 + i) * 9.0
		draw_colored_polygon(PackedVector2Array([center + direction * 25 + side * 3, center + direction * length + side * 10, center + direction * length - side * 10, center + direction * 25 - side * 3]), Color(accent, 0.06))
