extends Node

signal canvas_aligned

# Align the world translation at the final render scale, not in world units.
# A fractional camera offset otherwise changes which texels nearest filtering
# samples on every frame, making stationary tiles appear to ripple while scrolling.
# Camera position alignment alone cannot give texels uniform widths when the
# window stretch multiplies the chosen zoom by a fractional scale.
const NODE_NAME := "CameraPixelAlignment"
const ZOOM_RESPONSE := 14.0
const ZOOM_SETTLE_EPSILON_PIXELS := 0.001
var requested_zoom := -1.0
var minimum_zoom := 1.5
var maximum_zoom := 7.0
var zoom_transition_active := false
var continuous_zoom := false
var displayed_zoom_y := 3.0

static func install(camera: Camera2D) -> Node:
	if camera.get_node_or_null(NODE_NAME) == null:
		var alignment := new()
		alignment.name = NODE_NAME
		camera.add_child(alignment)
	return camera.get_node(NODE_NAME)

static func configure_zoom(camera: Camera2D, requested: float, minimum: float, maximum: float, animate: bool = false, continuous: bool = false) -> void:
	var alignment = install(camera)
	alignment.requested_zoom = requested
	alignment.minimum_zoom = minimum
	alignment.maximum_zoom = maximum
	alignment.continuous_zoom = continuous
	alignment.displayed_zoom_y = camera.zoom.y
	alignment.zoom_transition_active = animate
	alignment.set_process(animate)
	alignment._apply_pixel_zoom(camera)

static func target_zoom(camera: Camera2D) -> Vector2:
	var alignment = camera.get_node_or_null(NODE_NAME)
	if alignment == null or alignment.requested_zoom <= 0.0:
		return camera.zoom
	return alignment._get_target_zoom(camera)

static func finish_zoom(camera: Camera2D) -> void:
	var alignment = camera.get_node_or_null(NODE_NAME)
	if alignment == null or not alignment.continuous_zoom:
		return
	# On touch release/cancellation, ease to a crisp whole-pixel resting scale.
	alignment.continuous_zoom = false
	alignment.displayed_zoom_y = camera.zoom.y
	alignment.zoom_transition_active = true
	alignment.set_process(true)

static func screen_pixel_zoom_step(camera: Camera2D) -> float:
	return 1.0 / maxf(camera.get_viewport().get_stretch_transform().get_scale().y, 0.001)

func _get_target_zoom(camera: Camera2D) -> Vector2:
	var stretch := camera.get_viewport().get_stretch_transform().get_scale().abs()
	if stretch.x <= 0.0 or stretch.y <= 0.0:
		return camera.zoom
	var smallest := maxi(1, ceili(minimum_zoom * maxf(stretch.x, stretch.y)))
	var largest := maxi(smallest, floori(maximum_zoom * minf(stretch.x, stretch.y)))
	var pixels := clampf(requested_zoom * stretch.y, float(smallest), float(largest))
	if not continuous_zoom:
		pixels = roundf(pixels)
	# Account for slight X/Y stretch differences caused by viewport rounding.
	# Resting zoom levels use whole pixels; active transitions can scale smoothly.
	return Vector2(pixels / stretch.x, pixels / stretch.y)

func _apply_pixel_zoom(camera: Camera2D) -> void:
	if requested_zoom <= 0.0:
		return
	if not zoom_transition_active:
		camera.zoom = _get_target_zoom(camera)
		return
	var stretch := camera.get_viewport().get_stretch_transform().get_scale().abs()
	camera.zoom = Vector2(displayed_zoom_y * stretch.y / maxf(stretch.x, 0.001), displayed_zoom_y)

func _process(delta: float) -> void:
	var camera := get_parent() as Camera2D
	if camera == null or not camera.is_current() or not zoom_transition_active:
		return
	var target := _get_target_zoom(camera)
	# Exponential easing is independent of frame rate and supports retargeting
	# every frame during a touch hold, without stacking or restarting tweens.
	displayed_zoom_y = lerpf(displayed_zoom_y, target.y, 1.0 - exp(-ZOOM_RESPONSE * maxf(delta, 0.0)))
	var stretch_y := camera.get_viewport().get_stretch_transform().get_scale().y
	if absf(displayed_zoom_y - target.y) * stretch_y < ZOOM_SETTLE_EPSILON_PIXELS:
		zoom_transition_active = false
		set_process(false)
	_apply_pixel_zoom(camera)

func _ready() -> void:
	set_process(zoom_transition_active)
	RenderingServer.frame_pre_draw.connect(_align_camera)

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_align_camera)

func _align_camera() -> void:
	var camera := get_parent() as Camera2D
	if camera == null or not camera.is_current():
		return
	_apply_pixel_zoom(camera)
	# Run after Camera2D's own idle/physics update, including teleports and resizes.
	camera.force_update_scroll()
	var viewport := camera.get_viewport()
	var canvas := viewport.canvas_transform
	var to_pixels := viewport.get_stretch_transform() * viewport.global_canvas_transform
	var pixel_origin := to_pixels * canvas.origin
	canvas.origin = to_pixels.affine_inverse() * pixel_origin.round()
	viewport.canvas_transform = canvas
	# Screen-space overlays must project through the same final camera transform
	# that renders the player, including pixel alignment and resize/zoom changes.
	canvas_aligned.emit()
