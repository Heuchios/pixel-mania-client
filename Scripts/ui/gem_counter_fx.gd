extends Control
## Cosmetic only: the wallet stays authoritative while this display catches up.

var label: Label
var initialized := false
var target := 0
var displayed := 0.0
var start_value := 0.0
var elapsed := 0.0
var duration := 0.65
var shine_clock := 0.0
var burst_age := 1.0
var last_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_meta("ignore_mobile_ui_scale", true)

func set_amount(amount: int) -> void:
	amount = maxi(0, amount)
	if initialized and amount == target:
		return
	var snap := not initialized or amount < target or not is_visible_in_tree()
	initialized = true
	target = amount
	if snap:
		displayed = float(target)
		start_value = displayed
		elapsed = duration
	else:
		start_value = displayed
		elapsed = 0.0
		duration = clampf(0.4 + log(1.0 + target - displayed) * 0.06, 0.4, 1.0)
	_write_count()

func pickup() -> void:
	burst_age = 0.0
	shine_clock = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		displayed = float(target)
		elapsed = duration
		_write_count()
		return
	if elapsed < duration:
		elapsed = minf(duration, elapsed + delta)
		var t := elapsed / duration
		displayed = lerpf(start_value, float(target), 1.0 - pow(1.0 - t, 3.0))
		_write_count()
	shine_clock = fmod(shine_clock + delta, 5.5)
	burst_age = minf(1.0, burst_age + delta)
	if shine_clock < 1.3 or burst_age < 1.0:
		queue_redraw()
	elif shine_clock - delta < 1.3:
		queue_redraw()

func _write_count() -> void:
	if not is_instance_valid(label):
		return
	var digits := str(int(round(displayed)))
	var formatted := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += ","
		formatted += digits[i]
	if formatted != last_text:
		label.text = formatted
		last_text = formatted

func _draw() -> void:
	if shine_clock < 1.2:
		var x := lerpf(-45.0, size.x + 45.0, shine_clock / 1.2)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 18, 0), Vector2(x - 2, size.y), Vector2(x - 20, size.y)]), Color(0.75, 0.94, 1.0, 0.17))
		draw_line(Vector2(x + 21, 0), Vector2(x + 1, size.y), Color(1, 1, 1, 0.25), 2)
	if burst_age < 0.8:
		var t := burst_age / 0.8
		var colors := [Color("ffe66b"), Color("9bffef"), Color("ffa9f0")]
		for i in 9:
			var angle := float(i) * TAU / 9.0
			var center := Vector2(23, size.y * 0.5) + Vector2(cos(angle), sin(angle)) * (8 + 30 * t)
			center = center.round()
			var color: Color = colors[i % 3]
			color.a = 1.0 - t
			var arm := 1.0 + roundf(2.0 * (1.0 - t))
			draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), color, 2)
			draw_line(center - Vector2(0, arm), center + Vector2(0, arm), color, 2)
