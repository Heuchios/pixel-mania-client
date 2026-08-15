@tool
extends Node2D

## Lightweight glow effect for lava blocks. Client-visual only (no server cost):
## a single unshadowed PointLight2D that flickers subtly, plus a handful of
## slow-rising ember particles. Kept cheap on purpose since every placed lava
## block already keeps a live Node2D (for rebound physics) and instantiates
## one of these as a child, so cost scales with lava block count on screen.

@export var preview_emitting := true
@export var show_fixture := true  # unused; kept for light_fx_scene API compatibility
@export var light_color := Color(1.0, 0.4, 0.08, 1.0)
@export var light_energy := 1.15
@export var flicker_strength := 0.16
@export var flicker_speed := 3.1
@export var ember_enabled := true

const EFFECT_Z_INDEX := 4070

var glow_light: PointLight2D = null
var ember_particles: GPUParticles2D = null
var flicker_phase := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	glow_light = get_node_or_null("LavaGlowLight") as PointLight2D
	ember_particles = get_node_or_null("EmberMotes") as GPUParticles2D

	if ember_particles != null and ember_particles.process_material != null:
		ember_particles.process_material = ember_particles.process_material.duplicate(true)

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


func _process(delta: float) -> void:
	if not preview_emitting or glow_light == null or not is_instance_valid(glow_light):
		return

	flicker_phase = wrapf(flicker_phase + delta * flicker_speed, 0.0, TAU)
	var flicker := 1.0 + sin(flicker_phase) * flicker_strength + sin(flicker_phase * 2.3 + 1.7) * flicker_strength * 0.4
	glow_light.energy = maxf(0.0, light_energy * flicker)
