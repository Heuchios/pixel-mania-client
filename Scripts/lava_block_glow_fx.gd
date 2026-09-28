@tool
extends Node2D

## Lightweight glow effect for lava blocks. Client-visual only (no server cost):
## a single unshadowed PointLight2D that flickers subtly, plus a handful of
## slow-rising ember particles.
##
## Cost model matters here. Every placed lava block keeps a live Node2D (for rebound physics)
## and instantiates one of these as a child, and a Light2D makes the renderer redraw every
## CanvasItem within its radius -- so overlapping lights on a lava pool multiply fill cost by
## the number of lights covering each tile. Two things keep that bounded:
##   1. block_manager only attaches this to lava tiles with an exposed face (see
##      light_fx_requires_exposed_face), so a pool costs its perimeter and not its area.
##   2. This script idles off screen and steps its flicker at FLICKER_UPDATE_INTERVAL rather
##      than every frame.
## Removing either one brings back the "extreme lag whenever lava is on screen" report.

@export var preview_emitting := true
@export var show_fixture := true  # unused; kept for light_fx_scene API compatibility
@export var light_color := Color(1.0, 0.48, 0.12, 1.0)
@export var light_energy := 0.8
@export var flicker_strength := 0.10
@export var flicker_speed := 3.1
@export var ember_enabled := true

const EFFECT_Z_INDEX := 4070
# The flicker is subtle noise, not an animation anyone tracks frame to frame, and every write
# to light.energy dirties the light for the renderer. A lava pool puts hundreds of these on
# screen at once, so stepping them at 20Hz instead of once per frame removes ~2/3 of that work
# with no visible difference.
const FLICKER_UPDATE_INTERVAL := 0.05
# Generous enough that a light never pops in at the screen edge -- the glow texture reaches
# well past the tile it sits on.
const LIGHT_RADIUS := 80.0
const LIGHT_TEXTURE_SCALE := 0.625

var glow_light: PointLight2D = null
var ember_particles: GPUParticles2D = null
var flicker_phase := 0.0
var flicker_accumulator := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	glow_light = get_node_or_null("LavaGlowLight") as PointLight2D
	ember_particles = get_node_or_null("EmberMotes") as GPUParticles2D

	flicker_phase = randf() * TAU
	apply_light_settings()
	set_process(true)

	if preview_emitting:
		start()
	else:
		stop()


func start() -> void:
	preview_emitting = true
	set_process(true)
	apply_light_settings()


func stop() -> void:
	preview_emitting = false
	set_process(false)
	if glow_light != null and is_instance_valid(glow_light):
		glow_light.enabled = false
	if ember_particles != null and is_instance_valid(ember_particles):
		ember_particles.emitting = false


func restart() -> void:
	if is_instance_valid(ember_particles):
		ember_particles.restart()
	start()


func apply_light_settings() -> void:
	if glow_light == null or not is_instance_valid(glow_light):
		return

	glow_light.enabled = preview_emitting and is_on_screen()
	glow_light.color = light_color
	glow_light.energy = light_energy
	glow_light.texture_scale = LIGHT_TEXTURE_SCALE
	# No shadows: lava tiles can be numerous, so this stays a flat additive
	# glow rather than a per-tile shadow-casting light.
	glow_light.shadow_enabled = false
	if is_instance_valid(ember_particles):
		ember_particles.emitting = glow_light.enabled and ember_enabled


func is_on_screen() -> bool:
	var transform_with_canvas := get_global_transform_with_canvas()
	var screen_radius := LIGHT_RADIUS * maxf(transform_with_canvas.x.length(), transform_with_canvas.y.length())
	return get_viewport_rect().grow(screen_radius + 16.0).has_point(transform_with_canvas.origin)


func _process(delta: float) -> void:
	if not preview_emitting or glow_light == null or not is_instance_valid(glow_light):
		return

	flicker_accumulator += delta
	if flicker_accumulator < FLICKER_UPDATE_INTERVAL:
		return

	var elapsed := flicker_accumulator
	flicker_accumulator = 0.0

	# Match campfire culling, including zoom: stop both lighting and new embers.
	glow_light.enabled = is_on_screen()
	if is_instance_valid(ember_particles):
		ember_particles.emitting = glow_light.enabled and ember_enabled
	if not glow_light.enabled:
		return

	# Keep phase continuous: wrapping a non-integer harmonic makes a visible pop.
	flicker_phase += elapsed * flicker_speed
	var flicker := sin(flicker_phase) * 0.65 + sin(flicker_phase * 2.3 + 1.7) * 0.25 + sin(flicker_phase * 3.7) * 0.10
	glow_light.energy = maxf(0.0, light_energy * (1.0 + flicker * flicker_strength))
	glow_light.texture_scale = LIGHT_TEXTURE_SCALE * (1.0 + flicker * 0.025)
