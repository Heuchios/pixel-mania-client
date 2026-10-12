extends Control
## Short-lived, screen-space feedback. Never changes gameplay health.
var anchor: Callable
var ratio := 1.0
var shown_ratio := 1.0
var full_time := 0.0
var active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(160, 18)
	z_index = 72
	set_meta("ignore_mobile_ui_scale", true)
	hide()

func set_health(hp: int, maximum: int = 10) -> void:
	var next := clampf(float(hp) / maximum, 0.0, 1.0)
	if next < ratio:
		active = true
		full_time = 0.0
		modulate.a = 1.0
	ratio = next
	if hp <= 0:
		reset()

func reset() -> void:
	active = false
	full_time = 0.0
	hide()

func _process(delta: float) -> void:
	if not active:
		return
	if ratio >= 1.0:
		full_time += delta
		modulate.a = 1.0 - clampf((full_time - 0.6) / 0.4, 0.0, 1.0)
		if full_time >= 1.0:
			reset()
			return
	shown_ratio = move_toward(shown_ratio, ratio, delta * 3.0)
	if anchor.is_valid():
		var point: Vector2 = anchor.call()
		visible = point.is_finite()
		if visible:
			global_position = (point - Vector2(size.x * 0.5, size.y + 4)).round()
	queue_redraw()

static func health_color(health_ratio: float) -> Color:
	var colors := [Color("dc303a"), Color("ed792e"), Color("e8c443"), Color("63ad35"), Color("176b36")]
	var step := clampf(health_ratio, 0.0, 1.0) * 4.0
	var index := mini(3, int(step))
	return colors[index].lerp(colors[index + 1], step - index)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e7caee"))
	draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Color("24102e"))
	var color := health_color(shown_ratio)
	draw_rect(Rect2(2, 2, roundf((size.x - 4) * shown_ratio), size.y - 4), color)
