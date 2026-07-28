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
	var layer_textures: Array = []
	var layer_speeds: Array = []

	func _process(_delta):
		queue_redraw()

	func _draw():
		if manager != null:
			manager.draw_background(self, layer_textures, layer_speeds)


var world        = null
var canvas_layer: CanvasLayer = null
var drawer:       Node2D      = null
var active_theme := ""
var background_drawers: Array[Node2D] = []
var transition_tween: Tween = null
var transition_generation := 0

# Loaded textures — index 0 = layer 1 (furthest), index 3 = layer 4 (nearest)
var textures: Array = []
var parallax_speeds: Array = []

# Parallax speeds per layer (furthest → nearest)
# Layer 1: sky/background — barely moves
# Layer 2: distant mountains — slow drift
# Layer 3: mid hills — noticeable scroll
# Layer 4: near trees — scrolls fastest
const PARALLAX_SPEEDS = [0.0, 0.06, 0.18, 0.34]

const LAYER_PATH = "res://Assets/background/nature_3/"
const LAYER_COUNT = 4
const THEME_TRANSITION_SECONDS := 0.85
const THEME_CONFIGS = {
	"": {
		"paths": [
			"res://Assets/background/nature_3/1.png",
			"res://Assets/background/nature_3/2.png",
			"res://Assets/background/nature_3/3.png",
			"res://Assets/background/nature_3/4.png"
		],
		"speeds": [0.0, 0.06, 0.18, 0.34]
	},
	"night": {
		"paths": [
			"res://Assets/background/night_theme/night_2.png",
			"res://Assets/background/night_theme/night_1.png",
			"res://Assets/background/night_theme/night_3.png"
		],
		"speeds": [0.0, 0.07, 0.22]
	},
	"snow": {
		"paths": [
			"res://Assets/background/snow_theme/snow_1.png",
			"res://Assets/background/snow_theme/snow_2.png",
			"res://Assets/background/snow_theme/snow_3.png"
		],
		"speeds": [0.0, 0.08, 0.24]
	},
	"city": {
		"paths": [
			"res://Assets/background/city_theme/city_1.png",
			"res://Assets/background/city_theme/city_2.png",
			"res://Assets/background/city_theme/city_3.png",
			"res://Assets/background/city_theme/city_4.png",
			"res://Assets/background/city_theme/city_5.png"
		],
		"speeds": [0.0, 0.05, 0.12, 0.22, 0.34]
	}
}


func setup(world_ref):
	world = world_ref
	if textures.is_empty():
		_load_textures()
	if canvas_layer == null or not is_instance_valid(canvas_layer):
		_build()


func _load_textures():
	textures.clear()
	parallax_speeds.clear()
	var config: Dictionary = THEME_CONFIGS.get(active_theme, THEME_CONFIGS[""])
	var paths: Array = config.get("paths", [])
	parallax_speeds = config.get("speeds", PARALLAX_SPEEDS).duplicate()
	for path_value in paths:
		var path := str(path_value)
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

	_create_background_drawer(textures, parallax_speeds, 1.0)


func _create_background_drawer(layer_textures: Array, layer_speeds: Array, alpha: float) -> Node2D:
	if canvas_layer == null or not is_instance_valid(canvas_layer):
		return null

	var new_drawer := BackgroundDrawer.new()
	new_drawer.name = "BackgroundDrawer" if background_drawers.is_empty() else "BackgroundTransition"
	new_drawer.manager = self
	new_drawer.layer_textures = layer_textures.duplicate()
	new_drawer.layer_speeds = layer_speeds.duplicate()
	new_drawer.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	canvas_layer.add_child(new_drawer)
	background_drawers.append(new_drawer)
	drawer = new_drawer
	return new_drawer


func _remove_background_drawer(background_drawer: Node2D) -> void:
	if background_drawer == null or not is_instance_valid(background_drawer):
		return
	background_drawers.erase(background_drawer)
	var parent := background_drawer.get_parent()
	if parent != null:
		parent.remove_child(background_drawer)
	background_drawer.queue_free()


func _keep_only_background_drawer(keep_drawer: Node2D) -> void:
	for background_drawer in background_drawers.duplicate():
		if background_drawer != keep_drawer:
			_remove_background_drawer(background_drawer)
	background_drawers.clear()
	if keep_drawer != null and is_instance_valid(keep_drawer):
		background_drawers.append(keep_drawer)
		drawer = keep_drawer
	else:
		drawer = null


func set_visible(v: bool):
	if canvas_layer != null:
		canvas_layer.visible = v


func set_theme(theme_name: String, smooth: bool = true, duration: float = THEME_TRANSITION_SECONDS) -> void:
	var clean_theme := theme_name.strip_edges().to_lower()
	if not THEME_CONFIGS.has(clean_theme):
		clean_theme = ""
	if clean_theme == active_theme and not textures.is_empty():
		return

	active_theme = clean_theme
	_load_textures()
	transition_generation += 1
	var generation := transition_generation
	var transition_duration := maxf(0.0, duration)

	if drawer == null or not is_instance_valid(drawer) or not smooth or transition_duration <= 0.0:
		if transition_tween != null and transition_tween.is_valid():
			transition_tween.kill()
		transition_tween = null
		_keep_only_background_drawer(null)
		_create_background_drawer(textures, parallax_speeds, 1.0)
		return

	var next_drawer := _create_background_drawer(textures, parallax_speeds, 0.0)
	if next_drawer == null:
		return

	# Do not tear down an in-flight crossfade. Keeping its visual stack in place
	# means a rapid third theme can fade over the exact image currently on screen.
	transition_tween = create_tween()
	transition_tween.tween_property(next_drawer, "modulate:a", 1.0, transition_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition_tween.tween_callback(Callable(self, "_finish_theme_transition").bind(next_drawer, generation))


func _finish_theme_transition(next_drawer: Node2D, generation: int) -> void:
	if generation != transition_generation:
		return
	if next_drawer == null or not is_instance_valid(next_drawer):
		return
	next_drawer.modulate.a = 1.0
	_keep_only_background_drawer(next_drawer)
	transition_tween = null


func is_theme_transition_active() -> bool:
	return background_drawers.size() > 1


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

func draw_background(ctx: Node2D, layer_textures: Array = [], layer_speeds: Array = []):
	if world == null or not world.in_world:
		return

	var ss    = ctx.get_viewport_rect().size
	if ss == Vector2.ZERO:
		return

	var cam_x = _camera_x()

	var draw_textures := layer_textures if not layer_textures.is_empty() else textures
	var draw_speeds := layer_speeds if not layer_speeds.is_empty() else parallax_speeds
	for i in range(draw_textures.size()):
		var texture = draw_textures[i]
		if texture == null:
			continue

		var speed = draw_speeds[i] if i < draw_speeds.size() else 0.0

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
