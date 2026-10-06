extends Line2D
## Static pixel cable geometry. The shared flow overlay animates only live routes.
const IDLE := Color("78838f")
const READY := Color("dfaa51")
const FLOW := Color("69e3b0")
# Fixed world-space dimensions, shared by every cable and its flow marks.
const CORE_WIDTH := 1.0
const OUTLINE_WIDTH := 2.0
var power_state := "idle"
var selected := false

func set_endpoints(a: Vector2, b: Vector2) -> void:
	if points.size() > 1 and points[0] == a.round() and points[-1] == b.round(): return
	var span := a.distance_to(b)
	var steps := clampi(int(ceil(span / 8.0)), 4, 64)
	# Hanging cables sag; nearly vertical runs have a small sideways bow.
	var sag := minf(20.0, absf(b.x - a.x) * 0.11)
	var bow := 4.0 if absf(b.x - a.x) < 16.0 else 0.0
	var curve := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		curve.append((a.lerp(b, t) + Vector2(bow, sag) * (4.0 * t * (1.0 - t))).round())
	points = curve
	default_color = Color.TRANSPARENT
	queue_redraw()

func set_power_state(value: String) -> void:
	if power_state == value: return
	power_state = value
	queue_redraw()

func set_selected(value: bool) -> void:
	if selected == value: return
	selected = value
	queue_redraw()

func _draw() -> void:
	if points.size() < 2: return
	var jacket := FLOW if power_state == "flow" else READY if power_state == "ready" else IDLE
	draw_polyline(points, Color("161b29"), OUTLINE_WIDTH, false)
	draw_polyline(points, jacket, CORE_WIDTH, false)
	for p in [points[0], points[-1]]:
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color("161b29"))
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color("f0dbf5") if selected else jacket)
