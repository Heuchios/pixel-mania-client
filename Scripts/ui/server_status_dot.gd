extends Panel
## A steady status light with two soft signal waves on each online heartbeat.

const CYCLE := 2.6
var _online := false
var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	set_process(_online)


func set_online(value: bool) -> void:
	if _online == value:
		return
	_online = value
	_phase = 0.0
	set_process(_online)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase = fmod(_phase + delta, CYCLE)
	queue_redraw()


func _draw() -> void:
	var center := (size * 0.5).floor()
	var beat := pow(maxf(0.0, sin(_phase / CYCLE * PI)), 4.0) if _online else 0.0
	var core := Color("65f34c") if _online else Color("ff5959")
	var rim := Color("226d36") if _online else Color("812e40")
	if _online:
		# Closely spaced, outward-moving echoes fade fully before the next cycle.
		_draw_wave(center, _phase / CYCLE, 0.46)
		_draw_wave(center, (_phase - 0.32) / CYCLE, 0.24)
		# Concentric low-opacity layers give the light a soft edge, not a box.
		for layer in range(5, 0, -1):
			var radius := 6.0 + float(layer) * 0.85 + beat * 0.7
			draw_circle(center, radius, Color(core, (0.018 + beat * 0.016)), true, -1.0, true)
	var radius := 5.5 + beat * 0.35
	draw_circle(center + Vector2(0, 1), radius + 0.9, Color(0.02, 0.01, 0.05, 0.7), true, -1.0, true)
	draw_circle(center, radius + 0.5, rim, true, -1.0, true)
	draw_circle(center, radius - 0.7, core.lerp(Color("caff9c"), beat * 0.3), true, -1.0, true)
	draw_arc(center, radius - 1.5, 0.25, 2.4, 16, Color(rim, 0.45), 1.0, true)
	draw_circle(center + Vector2(-1.3, -1.6), 1.5, core.lightened(0.72), true, -1.0, true)


func _draw_wave(center: Vector2, progress: float, strength: float) -> void:
	if progress < 0.0 or progress >= 0.8:
		return
	var t := progress / 0.8
	var ease_out := 1.0 - pow(1.0 - t, 2.0)
	var radius := lerpf(6.5, 15.0, ease_out)
	var opacity := sin(t * PI) * pow(1.0 - t, 1.4) * strength
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.40, 1.0, 0.32, opacity), 1.0, true)
