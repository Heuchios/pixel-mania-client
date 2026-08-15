@tool
extends Node2D

@export var preview_emitting: bool = true:
	set(value):
		preview_emitting = value
		_apply_emitter_state()
		if is_inside_tree():
			set_process(_should_process())

@export var auto_preview_motion: bool = true:
	set(value):
		auto_preview_motion = value
		if is_inside_tree():
			set_process(_should_process())

@export var auto_preview_impact: bool = true
@export var show_preview_path: bool = true:
	set(value):
		show_preview_path = value
		_apply_preview_path_visibility()

@export_range(32.0, 640.0, 1.0) var preview_distance_px: float = 240.0:
	set(value):
		preview_distance_px = value
		_update_preview_path()

@export_range(64.0, 1400.0, 1.0) var projectile_speed_px: float = 520.0
@export_range(0.25, 5.0, 0.05) var projectile_scale: float = 1.15:
	set(value):
		projectile_scale = value
		_apply_projectile_scale()

@export_range(0.2, 2.0, 0.05) var impact_scale_multiplier: float = 0.55:
	set(value):
		impact_scale_multiplier = clampf(value, 0.2, 2.0)
		_apply_projectile_scale()

@export var projectile_direction: Vector2 = Vector2.RIGHT:
	set(value):
		projectile_direction = value
		_apply_direction()

@export var loop_in_game: bool = false:
	set(value):
		loop_in_game = value
		_apply_emitter_state()
		if is_inside_tree():
			set_process(_should_process())

@export_range(0.08, 5.0, 0.01) var one_shot_lifetime: float = 0.55
@export_range(0.05, 2.0, 0.01) var impact_cleanup_delay: float = 0.38
@export var hide_projectile_after_impact: bool = true

const EFFECT_Z_INDEX := 4090
const TRAIL_EMITTER_NAMES := [
	"FlameTrail",
	"EmberTrail",
	"SmokeTrail",
]
const IMPACT_EMITTER_NAMES := [
	"ImpactFlash",
	"ImpactEmbers",
]

var projectile_body: Node2D = null
var impact_burst: Node2D = null
var preview_path: Line2D = null
var fire_head: Sprite2D = null
var fire_head_glow: Sprite2D = null
var trail_emitters: Array[GPUParticles2D] = []
var impact_emitters: Array[GPUParticles2D] = []

var _time: float = 0.0
var _preview_travel: float = 0.0
var _one_shot: bool = false
var _one_shot_age: float = 0.0
var _impact_wait: float = -1.0
var _impact_triggered: bool = false
var _one_shot_end_position := Vector2(INF, INF)


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	_collect_nodes()
	_duplicate_particle_materials()
	_apply_direction()
	_apply_projectile_scale()
	_update_preview_path()
	_apply_preview_path_visibility()
	_apply_emitter_state()
	set_process(_should_process())


func start() -> void:
	_one_shot = false
	_one_shot_age = 0.0
	_impact_wait = -1.0
	_impact_triggered = false
	_one_shot_end_position = Vector2(INF, INF)
	if projectile_body != null:
		projectile_body.visible = true
		projectile_body.position = Vector2.ZERO
	preview_emitting = true
	_apply_emitter_state()
	set_process(true)


func stop() -> void:
	preview_emitting = false
	loop_in_game = false
	_one_shot = false
	_one_shot_age = 0.0
	_impact_wait = -1.0
	_impact_triggered = false
	_one_shot_end_position = Vector2(INF, INF)
	_set_emitters(trail_emitters, false)
	_set_emitters(impact_emitters, false)
	set_process(false)


func play_once(direction: Vector2 = Vector2.RIGHT, speed_px: float = -1.0, lifetime: float = -1.0) -> void:
	projectile_direction = direction
	if speed_px > 0.0:
		projectile_speed_px = speed_px
	if lifetime > 0.0:
		one_shot_lifetime = lifetime
	preview_emitting = false
	loop_in_game = false
	_one_shot = true
	_one_shot_age = 0.0
	_impact_wait = -1.0
	_impact_triggered = false
	_one_shot_end_position = Vector2(INF, INF)
	if projectile_body != null:
		projectile_body.visible = true
		projectile_body.position = Vector2.ZERO
	_apply_emitter_state()
	set_process(true)


func launch_to(start_world_position: Vector2, target_world_position: Vector2, speed_px: float = -1.0, lifetime: float = -1.0) -> void:
	_collect_nodes()
	if not is_finite(start_world_position.x) or not is_finite(start_world_position.y):
		return
	if not is_finite(target_world_position.x) or not is_finite(target_world_position.y):
		return

	global_position = start_world_position
	var travel_delta := target_world_position - start_world_position
	var travel_distance := travel_delta.length()
	var direction := travel_delta.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT

	projectile_direction = direction
	if speed_px > 0.0:
		projectile_speed_px = speed_px
	if lifetime > 0.0:
		one_shot_lifetime = lifetime
	else:
		one_shot_lifetime = clampf(travel_distance / maxf(1.0, projectile_speed_px), 0.08, 5.0)

	preview_emitting = false
	auto_preview_motion = false
	auto_preview_impact = false
	loop_in_game = false
	_one_shot = true
	_one_shot_age = 0.0
	_impact_wait = -1.0
	_impact_triggered = false
	_one_shot_end_position = target_world_position
	if projectile_body != null:
		projectile_body.visible = true
		projectile_body.position = Vector2.ZERO
	_apply_preview_path_visibility()
	_apply_emitter_state()
	set_process(true)


func fire_once(direction: Vector2 = Vector2.RIGHT, speed_px: float = -1.0, lifetime: float = -1.0) -> void:
	play_once(direction, speed_px, lifetime)


func set_direction(direction: Vector2) -> void:
	projectile_direction = direction


func set_projectile_scale(value: float) -> void:
	projectile_scale = clampf(value, 0.25, 5.0)


func trigger_impact_burst() -> void:
	if impact_burst == null:
		return
	if projectile_body != null:
		impact_burst.position = projectile_body.position
		if hide_projectile_after_impact and _one_shot:
			projectile_body.visible = false

	impact_burst.visible = true
	for emitter in impact_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.visible = true
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = true


func _process(delta: float) -> void:
	_time += delta
	_animate_head()

	if _one_shot:
		_process_one_shot(delta)
		return

	if preview_emitting and auto_preview_motion:
		_process_preview_motion(delta)


func _process_preview_motion(delta: float) -> void:
	if projectile_body == null:
		return

	var distance: float = maxf(1.0, preview_distance_px)
	var previous_travel: float = _preview_travel
	_preview_travel = fmod(_preview_travel + projectile_speed_px * delta, distance)
	projectile_body.position = Vector2(_preview_travel, 0.0)
	if auto_preview_impact and _preview_travel < previous_travel:
		impact_burst.position = Vector2(distance, 0.0) if impact_burst != null else Vector2.ZERO
		trigger_impact_burst()


func _process_one_shot(delta: float) -> void:
	var previous_age := _one_shot_age
	_one_shot_age += delta
	if not _impact_triggered:
		var motion_delta := delta
		if _one_shot_age >= one_shot_lifetime:
			motion_delta = maxf(0.0, one_shot_lifetime - previous_age)
		global_position += Vector2.RIGHT.rotated(global_rotation) * projectile_speed_px * motion_delta
		if _one_shot_age >= one_shot_lifetime:
			_impact_triggered = true
			_impact_wait = impact_cleanup_delay
			if is_finite(_one_shot_end_position.x) and is_finite(_one_shot_end_position.y):
				global_position = _one_shot_end_position
			trigger_impact_burst()
			_set_emitters(trail_emitters, false)
		return

	_impact_wait -= delta
	if _impact_wait <= 0.0:
		queue_free()


func _animate_head() -> void:
	if fire_head == null:
		return

	var pulse: float = 1.0 + sin(_time * 18.0) * 0.075
	fire_head.scale = Vector2(pulse, pulse)
	if fire_head_glow != null:
		var glow_pulse: float = 1.0 + sin(_time * 14.0) * 0.12
		fire_head_glow.scale = Vector2(glow_pulse, glow_pulse)
		fire_head_glow.modulate.a = 0.32 + sin(_time * 11.0) * 0.06


func _collect_nodes() -> void:
	projectile_body = get_node_or_null("Projectile") as Node2D
	impact_burst = get_node_or_null("ImpactBurst") as Node2D
	preview_path = get_node_or_null("PreviewPath") as Line2D
	fire_head = get_node_or_null("Projectile/FireHead") as Sprite2D
	fire_head_glow = get_node_or_null("Projectile/FireHeadGlow") as Sprite2D

	trail_emitters.clear()
	for emitter_name in TRAIL_EMITTER_NAMES:
		var emitter := get_node_or_null("Projectile/" + emitter_name) as GPUParticles2D
		if emitter != null:
			trail_emitters.append(emitter)

	impact_emitters.clear()
	if impact_burst != null:
		for emitter_name in IMPACT_EMITTER_NAMES:
			var emitter := impact_burst.get_node_or_null(emitter_name) as GPUParticles2D
			if emitter != null:
				impact_emitters.append(emitter)


func _duplicate_particle_materials() -> void:
	for emitter in trail_emitters + impact_emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		if emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate(true)


func _apply_direction() -> void:
	var direction := projectile_direction
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	rotation = direction.angle()


func _apply_projectile_scale() -> void:
	if projectile_body != null:
		projectile_body.scale = Vector2(projectile_scale, projectile_scale)
	if impact_burst != null:
		var impact_scale := projectile_scale * impact_scale_multiplier
		impact_burst.scale = Vector2(impact_scale, impact_scale)
	_update_preview_path()


func _update_preview_path() -> void:
	if preview_path == null:
		return
	preview_path.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(maxf(1.0, preview_distance_px), 0.0),
	])
	_apply_preview_path_visibility()


func _apply_preview_path_visibility() -> void:
	if preview_path == null:
		return
	preview_path.visible = show_preview_path and Engine.is_editor_hint()


func _apply_emitter_state() -> void:
	if not is_inside_tree():
		return

	var active := preview_emitting or loop_in_game or _one_shot
	_set_emitters(trail_emitters, active)
	if impact_burst != null:
		impact_burst.visible = true
	if not active:
		_set_emitters(impact_emitters, false)


func _set_emitters(emitters: Array[GPUParticles2D], active: bool) -> void:
	for emitter in emitters:
		if emitter == null or not is_instance_valid(emitter):
			continue
		emitter.emitting = active


func _should_process() -> bool:
	return preview_emitting or loop_in_game or _one_shot or Engine.is_editor_hint()
