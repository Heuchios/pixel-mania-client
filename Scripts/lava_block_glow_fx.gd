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
@export var light_color := Color(1.0, 0.4, 0.08, 1.0)
@export var light_energy := 1.15
@export var flicker_strength := 0.16
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
const OFFSCREEN_MARGIN_PX := 96.0

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
	apply_light_settings()
	if ember_enabled and ember_particles != null and is_instance_valid(ember_particles):
		ember_particles.emitting = true


func stop() -> void:
	preview_emitting = false
	if glow_light != null and is_instance_valid(glow_light):
		glow_light.enabled = false
	if ember_particles != null and is_instance_valid(ember_particles):
		ember_particles.emitting = false


func restart() -> void:
	apply_light_settings()
	if ember_particles != null and is_instance_valid(ember_particles):
		ember_particles.emitting = false
		ember_particles.restart()
		if ember_enabled:
			ember_particles.emitting = true


func apply_light_settings() -> void:
	if glow_light == null or not is_instance_valid(glow_light):
		return

	glow_light.enabled = preview_emitting
	glow_light.color = light_color
	glow_light.energy = light_energy
	# No shadows: lava tiles can be numerous, so this stays a flat additive
	# glow rather than a per-tile shadow-casting light.
	glow_light.shadow_enabled = false


func is_on_screen() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return true
	var visible_rect := viewport.get_visible_rect().grow(OFFSCREEN_MARGIN_PX)
	return visible_rect.has_point(get_global_transform_with_canvas().origin)


func _process(delta: float) -> void:
	if not preview_emitting or glow_light == null or not is_instance_valid(glow_light):
		return

	flicker_accumulator += delta
	if flicker_accumulator < FLICKER_UPDATE_INTERVAL:
		return

	var elapsed := flicker_accumulator
	flicker_accumulator = 0.0

	# Off screen there is nothing to flicker. Skipping the energy write keeps offscreen lava
	# off the renderer's dirty list entirely; the phase resumes where it left off on return,
	# which is invisible because it was never being watched.
	if not is_on_screen():
		return

	flicker_phase = wrapf(flicker_phase + elapsed * flicker_speed, 0.0, TAU)
	var flicker := 1.0 + sin(flicker_phase) * flicker_strength + sin(flicker_phase * 2.3 + 1.7) * flicker_strength * 0.4
	glow_light.energy = maxf(0.0, light_energy * flicker)
