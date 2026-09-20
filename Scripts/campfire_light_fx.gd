@tool
extends Node2D
## Local cosmetic light owned by the placed campfire's block node.

@export var preview_emitting := true
@export var show_fixture := false
@export var light_color := Color(1.0, 0.57, 0.23)
@export var light_energy := 1.65
@export var flicker_strength := 0.13

const UPDATE_INTERVAL := 0.05
const LIGHT_RADIUS := 144.0
const LIGHT_TEXTURE_SCALE := 1.125

var warm_light: PointLight2D
var _phase := 0.0
var _accumulator := 0.0


func _ready() -> void:
	warm_light = $WarmLight
	_phase = randf() * 100.0
	if preview_emitting:
		start()
	else:
		stop()


func start() -> void:
	preview_emitting = true
	set_process(true)
	if is_instance_valid(warm_light):
		warm_light.color = light_color
		warm_light.energy = light_energy
		warm_light.texture_scale = LIGHT_TEXTURE_SCALE
		warm_light.enabled = is_on_screen()


func stop() -> void:
	preview_emitting = false
	set_process(false)
	if is_instance_valid(warm_light):
		warm_light.enabled = false


func is_on_screen() -> bool:
	var transform_with_canvas := get_global_transform_with_canvas()
	var screen_radius := LIGHT_RADIUS * maxf(transform_with_canvas.x.length(), transform_with_canvas.y.length())
	return get_viewport_rect().grow(screen_radius + 16.0).has_point(transform_with_canvas.origin)


func _process(delta: float) -> void:
	if not preview_emitting or not is_instance_valid(warm_light):
		return
	_accumulator += delta
	if _accumulator < UPDATE_INTERVAL:
		return
	_phase += _accumulator
	_accumulator = 0.0
	warm_light.enabled = is_on_screen()
	if not warm_light.enabled:
		return
	var flicker := sin(_phase * 7.3) * 0.6 + sin(_phase * 13.1 + 1.7) * 0.3 + sin(_phase * 23.7) * 0.1
	warm_light.energy = light_energy * (1.0 + flicker * flicker_strength)
	warm_light.texture_scale = LIGHT_TEXTURE_SCALE * (1.0 + flicker * 0.025)
