extends Node

# PixelMania World Background Manager v3
#
# Loads real PNG layers from res://Assets/background/nature_3/
# Files: 1.png (furthest) → 4.png (nearest)
#
# Each layer tiles horizontally and scrolls at its own parallax speed,
# creating natural depth as the player moves through the world.

class BackgroundDrawer extends Node2D:
	var manager = null

	func _process(_delta):
		queue_redraw()

	func _draw():
		if manager != null:
			manager.draw_background(self)


var world        = null
var canvas_layer: CanvasLayer = null
var drawer:       Node2D      = null

# Loaded textures — index 0 = layer 1 (furthest), index 3 = layer 4 (nearest)
var textures: Array = []

# Parallax speeds per layer (furthest → nearest)
# Layer 1: sky/background — barely moves
# Layer 2: distant mountains — slow drift
# Layer 3: mid hills — noticeable scroll
# Layer 4: near trees — scrolls fastest
const PARALLAX_SPEEDS = [0.0, 0.08, 0.22, 0.42]

const LAYER_PATH = "res://Assets/background/nature_3/"
const LAYER_COUNT = 4


func setup(world_ref):
	world = world_ref
	_load_textures()
	_build()


func _load_textures():
	textures.clear()
	for i in range(1, LAYER_COUNT + 1):
		var path = LAYER_PATH + str(i) + ".png"
		if ResourceLoader.exists(path):
			textures.append(load(path))
		else:
			push_warning("BackgroundManager: missing layer — " + path)
			textures.append(null)


func _build():
	if world == null:
		return

	canvas_layer               = CanvasLayer.new()
	canvas_layer.name          = "WorldBackground"
	canvas_layer.layer         = -10
	canvas_layer.follow_viewport_enabled = false
	world.add_child(canvas_layer)

	var d     = BackgroundDrawer.new()
	d.name    = "BackgroundDrawer"
	d.manager = self
	canvas_layer.add_child(d)
	drawer = d


func set_visible(v: bool):
	if canvas_layer != null:
		canvas_layer.visible = v


# ── Camera helpers ────────────────────────────────────────────

func _camera_x() -> float:
	if world == null or world.player == null:
		return 0.0
	return world.player.global_position.x


func _depth_blend() -> float:
	if world == null or world.player == null:
		return 0.0
	var surface_world = float(world.SURFACE_Y * world.BLOCK_SIZE)
	var player_y      = world.player.global_position.y
	var range_px      = float(world.BLOCK_SIZE) * 10.0
	return clamp((player_y - surface_world) / range_px, 0.0, 1.0)


# ── Main draw ────────────────────────────────────────────────

func draw_background(ctx: Node2D):
	if world == null or not world.in_world:
		return

	var ss    = ctx.get_viewport_rect().size
	if ss == Vector2.ZERO:
		return

	var cam_x = _camera_x()

	for i in range(textures.size()):
		var texture = textures[i]
		if texture == null:
			continue

		var speed = PARALLAX_SPEEDS[i] if i < PARALLAX_SPEEDS.size() else 0.0

		# Scale each layer to fill the screen height
		var tex_w     = float(texture.get_width())
		var tex_h     = float(texture.get_height())
		var scale     = ss.y / tex_h
		var scaled_w  = tex_w * scale

		# Parallax offset — wraps seamlessly via fmod
		var offset = fmod(cam_x * speed, scaled_w)
		if offset < 0.0:
			offset += scaled_w

		# Tile across the screen
		var x = -offset
		while x < ss.x:
			ctx.draw_texture_rect(texture, Rect2(x, 0.0, scaled_w, ss.y), false)
			x += scaled_w

	# Underground fade removed — can be re-enabled later
