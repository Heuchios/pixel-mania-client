extends Node

signal canvas_aligned

# Align the world translation at the final render scale, not in world units.
# A fractional camera offset otherwise changes which texels nearest filtering
# samples on every frame, making stationary tiles appear to ripple while scrolling.
# Camera position alignment alone cannot give texels uniform widths when the
# window stretch multiplies the chosen zoom by a fractional scale.
const NODE_NAME := "CameraPixelAlignment"
var requested_zoom := -1.0
var minimum_zoom := 1.5
var maximum_zoom := 7.0

static func install(camera: Camera2D) -> Node:
	if camera.get_node_or_null(NODE_NAME) == null:
		var alignment := new()
		alignment.name = NODE_NAME
		camera.add_child(alignment)
	return camera.get_node(NODE_NAME)

static func configure_zoom(camera: Camera2D, requested: float, minimum: float, maximum: float) -> void:
	var alignment = install(camera)
	alignment.requested_zoom = requested
	alignment.minimum_zoom = minimum
	alignment.maximum_zoom = maximum
	alignment._apply_pixel_zoom(camera)

static func screen_pixel_zoom_step(camera: Camera2D) -> float:
	return 1.0 / maxf(camera.get_viewport().get_stretch_transform().get_scale().y, 0.001)

func _apply_pixel_zoom(camera: Camera2D) -> void:
	if requested_zoom <= 0.0:
		return
	var stretch := camera.get_viewport().get_stretch_transform().get_scale().abs()
	if stretch.x <= 0.0 or stretch.y <= 0.0:
		return
	var smallest := maxi(1, ceili(minimum_zoom * maxf(stretch.x, stretch.y)))
	var largest := maxi(smallest, floori(maximum_zoom * minf(stretch.x, stretch.y)))
	var pixels := clampi(roundi(requested_zoom * stretch.y), smallest, largest)
	# Account for slight X/Y stretch differences caused by viewport rounding.
	# Every artwork pixel must cover the same whole number of output pixels.
	camera.zoom = Vector2(float(pixels) / stretch.x, float(pixels) / stretch.y)

func _ready() -> void:
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
