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
	# Pixels/second of AUTOMATIC horizontal movement per layer, independent of the camera.
	# Signed: positive drifts one way, negative the other. 0 = parallax only, as before.
	var layer_drifts: Array = []
	# Fraction of screen height each layer occupies, and where it sits vertically.
	var layer_scales: Array = []
	var layer_anchors: Array = []
	var layer_offsets: Array = []
	# How far apart repeats of a layer are, as a multiple of its own width. 1.0 = edge-to-edge
	# tiling (the original behaviour); higher values leave gaps so the layer appears fewer times.
	var layer_spacings: Array = []

	func _process(_delta):
		queue_redraw()

	func _draw():
		if manager != null:
			manager.draw_background(self, layer_textures, layer_speeds, layer_drifts, layer_scales, layer_anchors, layer_offsets, layer_spacings)


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
var parallax_drifts: Array = []
var parallax_scales: Array = []
var parallax_anchors: Array = []
var parallax_offsets: Array = []
var parallax_spacings: Array = []
# Wall-clock accumulator driving the self-animating layers. Kept here rather than read from
# Time.get_ticks_msec() at draw time so every drawer in a crossfade shares one clock and the
# banners cannot visibly jump when a theme transition swaps drawers.
var elapsed_seconds := 0.0
var landfill_theme_check_accum := 0.0

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
	},
	# Landfill seasonal event. Applied automatically in any landfill_* world and NOT reachable from
	# a theme machine -- see _resolve_theme_for_world(). bg_1..bg_4 are ordinary parallax scenery;
	# bg_5..bg_7 are the campaign banners, which additionally drift on their own (see "drifts")
	# so they travel left and right across the sky whether or not the player is moving.
	"landfill": {
		# Seven layers, furthest to nearest:
		#   bg_1 sky  bg_2 mountains  bg_3 haze  bg_4 landfill ridge
		#   bg_5..bg_7 campaign banners (the self-animating ones)
		"paths": [
			"res://Assets/background/landfill/bg_1.png",
			"res://Assets/background/landfill/bg_2.png",
			"res://Assets/background/landfill/bg_3.png",
			"res://Assets/background/landfill/bg_4.png",
			"res://Assets/background/landfill/bg_5.png",
			"res://Assets/background/landfill/bg_6.png",
			"res://Assets/background/landfill/bg_7.png"
		],
		# Camera parallax. The sky is pinned at 0 so it never slides, and each nearer layer moves
		# progressively faster, which is what sells the depth.
		"speeds": [0.0, 0.04, 0.09, 0.16, 0.22, 0.29, 0.36],
		# Pixels/second of movement independent of the camera -- only the three banners (bg_5..bg_7). Alternating
		# signs so they visibly cross each other rather than sliding as one sheet, and deliberately
		# slow: this should read as drifting signage, not scrolling scenery.
		"drifts": [0.0, 0.0, 0.0, 0.0, -14.0, -9.0, 20.0],
		# Fraction of SCREEN HEIGHT each layer is drawn at. The four scenery layers fill the screen
		# (1.0, the same as every other theme); the banners are small sprites and would dominate the
		# view if stretched to full height. TUNE THIS to resize the banners.
		"scales": [1.0, 1.0, 1.0, 1.0, 0.085, 0.07, 0.075],
		# Where a shrunken layer sits vertically: 0.0 = top of screen, 1.0 = bottom. Staggered so the
		# three banners occupy different bands of sky. Does nothing for full-height layers, which have
		# no slack to move within -- use "offsets" for those.
		"anchors": [0.0, 0.0, 0.0, 0.0, 0.20, 0.34, 0.48],
		# Extra vertical nudge as a fraction of screen height; NEGATIVE moves a layer UP. This is the
		# only way to reposition a full-height layer.
		"offsets": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		# Repeat distance as a multiple of each layer's own width. The scenery layers stay at 1.0 --
		# they must tile edge-to-edge or the sky would show gaps. The banners were repeating every
		# banner-width, so several copies were on screen at once; spacing them out several widths
		# apart means you see roughly one at a time drifting past. RAISE THESE to see fewer.
		"spacings": [1.0, 1.0, 1.0, 1.0, 5.6, 6.2, 5.8]
	}
}

const LANDFILL_WORLD_PREFIX := "landfill_"
const LANDFILL_THEME := "landfill"


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
	# Themes without a "drifts" entry animate exactly as they always have: parallax only.
	parallax_drifts = config.get("drifts", []).duplicate()
	# Absent for every pre-existing theme, which is exactly why the defaults below reproduce the
	# original full-height stretch: those themes must look identical to before this change.
	parallax_scales = config.get("scales", []).duplicate()
	parallax_anchors = config.get("anchors", []).duplicate()
	parallax_offsets = config.get("offsets", []).duplicate()
	parallax_spacings = config.get("spacings", []).duplicate()
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
	new_drawer.layer_drifts = parallax_drifts.duplicate()
	new_drawer.layer_scales = parallax_scales.duplicate()
	new_drawer.layer_anchors = parallax_anchors.duplicate()
	new_drawer.layer_offsets = parallax_offsets.duplicate()
	new_drawer.layer_spacings = parallax_spacings.duplicate()
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


# Landfill worlds always show the landfill background, and nothing can talk them out of it.
#
# Routed through here rather than at the call sites because world themes are ALSO driven by
# in-world theme machines (see world.gd's refresh_world_background_theme_from_machines): a machine
# left in a race world would otherwise repaint it as snow or city mid-race. Forcing on the way in
# means every path -- world entry, a theme machine, a manual reset -- lands on the same answer.
func _is_landfill_world() -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var world_name := str(world.get("current_world_name")) if "current_world_name" in world else ""
	return world_name.strip_edges().to_lower().begins_with(LANDFILL_WORLD_PREFIX)


func _resolve_theme_for_world(requested_theme: String) -> String:
	if _is_landfill_world():
		return LANDFILL_THEME
	# Outside a Landfill world the landfill theme is not selectable, so a stale request for it
	# (e.g. left over from the previous world) falls back to the default rather than sticking.
	if requested_theme == LANDFILL_THEME:
		return ""
	return requested_theme


func _process(delta: float) -> void:
	elapsed_seconds += delta

	# The world name is not necessarily known when setup() runs, and the player can move between
	# worlds without any theme call being made. A light poll -- twice a second -- is the same
	# self-correcting pattern the Landfill HUD uses, and costs a string compare.
	landfill_theme_check_accum += delta
	if landfill_theme_check_accum < 0.5:
		return
	landfill_theme_check_accum = 0.0
	var wanted := _resolve_theme_for_world(active_theme)
	if wanted != active_theme:
		set_theme(wanted, true)


func set_visible(v: bool):
	if canvas_layer != null:
		canvas_layer.visible = v


func set_theme(theme_name: String, smooth: bool = true, duration: float = THEME_TRANSITION_SECONDS) -> void:
	var clean_theme := theme_name.strip_edges().to_lower()
	if not THEME_CONFIGS.has(clean_theme):
		clean_theme = ""
	clean_theme = _resolve_theme_for_world(clean_theme)
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

func draw_background(ctx: Node2D, layer_textures: Array = [], layer_speeds: Array = [], layer_drifts: Array = [], layer_scales: Array = [], layer_anchors: Array = [], layer_offsets: Array = [], layer_spacings: Array = []):
	if world == null or not world.in_world:
		return

	var ss    = ctx.get_viewport_rect().size
	if ss == Vector2.ZERO:
		return

	var cam_x = _camera_x()

	var draw_textures := layer_textures if not layer_textures.is_empty() else textures
	var draw_speeds := layer_speeds if not layer_speeds.is_empty() else parallax_speeds
	var draw_drifts := layer_drifts if not layer_drifts.is_empty() else parallax_drifts
	var draw_scales := layer_scales if not layer_scales.is_empty() else parallax_scales
	var draw_anchors := layer_anchors if not layer_anchors.is_empty() else parallax_anchors
	var draw_offsets := layer_offsets if not layer_offsets.is_empty() else parallax_offsets
	var draw_spacings := layer_spacings if not layer_spacings.is_empty() else parallax_spacings
	for i in range(draw_textures.size()):
		var texture = draw_textures[i]
		if texture == null:
			continue

		var speed = draw_speeds[i] if i < draw_speeds.size() else 0.0

		# Height this layer is drawn at. Defaulting to 1.0 (full screen height) keeps every theme
		# that predates per-layer sizing pixel-identical to before.
		var tex_w        = float(texture.get_width())
		var tex_h        = float(texture.get_height())
		var scale_ratio  = float(draw_scales[i]) if i < draw_scales.size() else 1.0
		if scale_ratio <= 0.0:
			continue
		var drawn_h      = ss.y * scale_ratio
		var scale        = drawn_h / tex_h
		var scaled_w     = tex_w * scale
		# 0.0 pins the layer to the top of the screen, 1.0 to the bottom. A full-height layer has
		# no slack, so this resolves to 0 for them either way.
		var anchor_ratio = float(draw_anchors[i]) if i < draw_anchors.size() else 0.0
		var offset_ratio = float(draw_offsets[i]) if i < draw_offsets.size() else 0.0
		var draw_y       = (ss.y - drawn_h) * clampf(anchor_ratio, 0.0, 1.0) + ss.y * offset_ratio

		# Camera parallax PLUS this layer's own drift. Both are folded into one offset and wrapped
		# with fmod against the scaled tile width, so a self-animating layer stays as seamless as a
		# static one no matter how long the race runs -- the offset never grows without bound.
		var drift = draw_drifts[i] if i < draw_drifts.size() else 0.0
		# Wrap on the SPACING step rather than the sprite width. At spacing 1.0 the two are equal
		# and this is byte-for-byte the original edge-to-edge tiling; above 1.0 the sprite is drawn
		# once per step with empty space between, so fewer copies share the screen. Wrapping on the
		# step (not the width) is what keeps that seamless -- wrapping on width would make a spaced
		# layer visibly jump back as soon as it travelled one sprite-width.
		var spacing = float(draw_spacings[i]) if i < draw_spacings.size() else 1.0
		var step = scaled_w * maxf(1.0, spacing)
		var offset = fmod(cam_x * speed + elapsed_seconds * drift, step)
		if offset < 0.0:
			offset += step

		# Tile across the screen
		var x = -offset
		while x < ss.x:
			ctx.draw_texture_rect(texture, Rect2(x, draw_y, scaled_w, drawn_h), false)
			x += step

	# Underground fade removed — can be re-enabled later
