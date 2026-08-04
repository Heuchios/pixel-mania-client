extends Node2D

const MAX_ACTIVE_PARTICLES = 220
const PARTICLE_Z_INDEX = 3800
const FRONT_PARTICLE_Z_INDEX = 4060
const UI_PARTICLE_Z_INDEX = 4095
const BLOCK_HALF_SIZE = 16.0
const FIRE_PARTICLE_TEXTURE_PATH = "res://Assets/particles/fire.png"
const FIRE_PARTICLE_BASE_SIZE = 16.0
const WATER_SPLASH_PARTICLE_TEXTURE_PATH = "res://Assets/particles/water_splash.png"
const WATER_SPLASH_PARTICLE_BASE_SIZE = 16.0
const PLAYER_WATER_SPLASH_MOTION_SCALE = 0.84
const PLAYER_WATER_SPLASH_LIFETIME_SCALE = 1.10
const OIL_REFINERY_SMOKE_TEXTURE_PATH = "res://Assets/blocks/special_blocks/oil_refinery/smoke.png"
const OIL_REFINERY_SMOKE_BASE_SIZE = 20.0
const OIL_REFINERY_SMOKE_MAX_ACTIVE = 36
const BLUE_HIT_PARTICLES_SCENE_PATH = "res://Scenes/particles/BlueHitParticlesFX.tscn"
const THUNDER_PARTICLES_SCENE_PATH = "res://Scenes/particles/ThunderParticlesFX.tscn"
const WATER_SURGE_BEAM_SCENE_PATH = "res://Scenes/particles/WaterSurgeBeamFX.tscn"
const EPIC_FISHING_REWARD_CONFETTI_SCENE_PATH = "res://Scenes/particles/EpicFishingRewardConfettiFX.tscn"
const LEGENDARY_FISHING_REWARD_CONFETTI_SCENE_PATH = "res://Scenes/particles/LegendaryFishingRewardConfettiFX.tscn"
const PARTICLE_VISIBILITY_MARGIN_SCREEN_PX := 192.0

var world = null
var particles: Array = []
var rng := RandomNumberGenerator.new()
var front_particle_manager = null
var fire_particle_texture: Texture2D = null
var water_splash_particle_texture: Texture2D = null
var oil_refinery_smoke_texture: Texture2D = null
var blue_hit_particles_scene: PackedScene = null
var thunder_particles_scene: PackedScene = null
var water_surge_beam_scene: PackedScene = null
var epic_fishing_reward_confetti_scene: PackedScene = null
var legendary_fishing_reward_confetti_scene: PackedScene = null


func setup(world_ref, create_front_layer: bool = true):
	world = world_ref
	z_as_relative = false
	z_index = PARTICLE_Z_INDEX
	rng.randomize()
	set_process(false)
	if create_front_layer:
		setup_front_particle_manager()


func setup_front_particle_manager():
	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		return

	front_particle_manager = Node2D.new()
	front_particle_manager.name = "FrontParticleManager"
	front_particle_manager.set_script(get_script())
	add_child(front_particle_manager)

	if front_particle_manager.has_method("setup"):
		front_particle_manager.setup(world, false)

	front_particle_manager.z_as_relative = false
	front_particle_manager.z_index = FRONT_PARTICLE_Z_INDEX


func spawn_block_hit(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	_spawn_block_burst(grid_pos, block_type, layer, 7, 34.0, 92.0, 0.22, 0.42, 1.7, 3.4, 190.0, 0.88)


func spawn_block_break(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	var clean_block_type: String = block_type.strip_edges().to_lower()
	if clean_block_type == "bomb":
		_spawn_bomb_fire_break_burst(grid_pos)
		_spawn_block_burst(grid_pos, block_type, layer, 9, 54.0, 132.0, 0.28, 0.58, 1.8, 4.2, 245.0, 0.92)
		return

	_spawn_block_burst(grid_pos, block_type, layer, 20, 68.0, 178.0, 0.36, 0.82, 2.0, 4.8, 260.0, 1.0)


func spawn_block_place(grid_pos: Vector2i, block_type: String = "", layer: String = "foreground"):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	_spawn_block_burst(grid_pos, block_type, layer, 11, 20.0, 78.0, 0.20, 0.46, 1.8, 3.8, 160.0, 0.72)


func spawn_blue_hit_block(grid_pos: Vector2i, _block_type: String = "", _layer: String = "foreground", mirror_direction: bool = false):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	var scene := get_blue_hit_particles_scene()
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	effect.set("preview_emitting", false)
	effect.set("auto_restart_preview", false)
	effect.set("loop_in_game", false)
	effect.set("mirror_direction", mirror_direction)
	effect.position = _get_block_center(grid_pos)
	add_child(effect)

	if effect.has_method("play_once"):
		effect.play_once()
	elif effect.has_method("restart"):
		effect.restart()


func spawn_thunder_arc(start_world_position: Vector2, end_world_position: Vector2, _mirror_direction: bool = false):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(start_world_position) and not _should_emit_at_world_position(end_world_position):
		return

	var scene := get_thunder_particles_scene()
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	var start_local := to_local(start_world_position)
	var end_local := to_local(end_world_position)
	var target_offset := end_local - start_local
	var effect_scale: Vector2 = effect.scale
	if absf(effect_scale.x) > 0.001 and absf(effect_scale.y) > 0.001:
		target_offset = Vector2(target_offset.x / effect_scale.x, target_offset.y / effect_scale.y)
	effect.set("preview_emitting", false)
	effect.set("auto_restart_preview", false)
	effect.set("loop_in_game", false)
	effect.position = start_local
	if effect.has_method("set_target_offset"):
		effect.set_target_offset(target_offset)
	else:
		effect.set("target_offset", target_offset)
	add_child(effect)

	if effect.has_method("play_once"):
		effect.play_once()
	elif effect.has_method("restart"):
		effect.restart()


func spawn_water_surge_beam(start_world_position: Vector2, end_world_position: Vector2, _mirror_direction: bool = false):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(start_world_position) and not _should_emit_at_world_position(end_world_position):
		return

	var scene := get_water_surge_beam_scene()
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	var start_local := to_local(start_world_position)
	var end_local := to_local(end_world_position)
	var target_offset := end_local - start_local
	effect.set("preview_emitting", false)
	effect.set("auto_preview_splash", true)
	effect.set("loop_in_game", false)
	effect.position = start_local
	if effect.has_method("set_target_offset"):
		effect.set_target_offset(target_offset)
	else:
		effect.rotation = target_offset.angle()
		effect.set("beam_length_px", target_offset.length())
	add_child(effect)

	if effect.has_method("play_once"):
		effect.play_once()
	elif effect.has_method("start"):
		effect.start()


func spawn_fishing_reward_confetti(world_position: Vector2, rarity: String):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	var scene := get_fishing_reward_confetti_scene(rarity)
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	_prepare_fishing_reward_confetti_effect(effect)
	effect.position = to_local(world_position)
	add_child(effect)

	_play_fishing_reward_confetti_effect(effect)


func spawn_fishing_reward_confetti_on_canvas(canvas_parent: Node, canvas_position: Vector2, rarity: String):
	if not _can_emit():
		return
	if canvas_parent == null:
		return

	var scene := get_fishing_reward_confetti_scene(rarity)
	if scene == null:
		return

	var effect = scene.instantiate()
	if effect == null:
		return

	_prepare_fishing_reward_confetti_effect(effect)
	effect.position = canvas_position
	canvas_parent.add_child(effect)
	if effect is CanvasItem:
		var canvas_item := effect as CanvasItem
		canvas_item.z_as_relative = false
		canvas_item.z_index = UI_PARTICLE_Z_INDEX
		canvas_parent.move_child(effect, canvas_parent.get_child_count() - 1)

	_play_fishing_reward_confetti_effect(effect)


func _prepare_fishing_reward_confetti_effect(effect: Node) -> void:
	effect.set("preview_emitting", false)
	effect.set("auto_restart_preview", false)
	if effect is CanvasItem:
		var canvas_item := effect as CanvasItem
		canvas_item.z_as_relative = false
		canvas_item.z_index = UI_PARTICLE_Z_INDEX


func _play_fishing_reward_confetti_effect(effect: Node) -> void:
	if effect.has_method("play_once"):
		effect.play_once()
	elif effect.has_method("restart"):
		effect.restart()


func spawn_tree_growth(grid_pos: Vector2i, block_type: String = "", stage: int = 0):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	_spawn_tree_growth_burst(grid_pos, block_type, stage)


func spawn_tree_break(grid_pos: Vector2i, block_type: String = ""):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(_get_block_center(grid_pos)):
		return

	_spawn_tree_break_burst(grid_pos, block_type)


func spawn_water_splash(world_position: Vector2, intensity: float = 1.0):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	_spawn_water_splash_burst(to_local(world_position), intensity)


func spawn_underwater_bubbles(world_position: Vector2, count: int = 1):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		front_particle_manager.spawn_underwater_bubbles(world_position, count)
		return

	_spawn_underwater_bubbles_burst(to_local(world_position), count)


func spawn_player_fire(world_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), intensity: float = 1.0):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		front_particle_manager.spawn_player_fire(world_position, body_half_extents, intensity)
		return

	_spawn_player_fire_burst(to_local(world_position), body_half_extents, intensity)


func spawn_player_water_splash(world_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), water_surface_y: float = INF, intensity: float = 1.0):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		front_particle_manager.spawn_player_water_splash(world_position, body_half_extents, water_surface_y, intensity)
		return

	var local_position := to_local(world_position)
	var local_surface_y := water_surface_y
	if water_surface_y != INF:
		local_surface_y = to_local(Vector2(world_position.x, water_surface_y)).y
	_spawn_player_water_splash_burst(local_position, body_half_extents, local_surface_y, intensity)


func spawn_oil_refinery_smoke(world_position: Vector2, count: int = 5, texture_path: String = OIL_REFINERY_SMOKE_TEXTURE_PATH):
	if not _can_emit():
		return
	if not _should_emit_at_world_position(world_position):
		return

	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		front_particle_manager.spawn_oil_refinery_smoke(world_position, count, texture_path)
		return

	var smoke_texture := get_oil_refinery_smoke_texture(texture_path)
	_spawn_oil_refinery_smoke_burst(to_local(world_position), count, smoke_texture)


func clear_particles():
	particles.clear()
	queue_redraw()
	set_process(false)
	if front_particle_manager != null and is_instance_valid(front_particle_manager):
		front_particle_manager.clear_particles()


func _process(delta: float):
	if not _can_emit():
		clear_particles()
		return

	if particles.is_empty():
		set_process(false)
		return

	for i in range(particles.size() - 1, -1, -1):
		var particle = particles[i]
		var age = float(particle.get("age", 0.0)) + delta
		var lifetime = max(0.01, float(particle.get("lifetime", 0.35)))

		if age >= lifetime:
			particles.remove_at(i)
			continue

		var velocity = particle.get("velocity", Vector2.ZERO)
		var gravity = particle.get("gravity", Vector2.ZERO)
		var damping = float(particle.get("damping", 0.92))
		var particle_position = particle.get("position", Vector2.ZERO)
		var particle_rotation = float(particle.get("rotation", 0.0))
		var angular_velocity = float(particle.get("angular_velocity", 0.0))

		velocity += gravity * delta
		velocity *= pow(damping, delta * 8.0)
		particle_position += velocity * delta

		var wobble_strength = float(particle.get("wobble_strength", 0.0))
		if wobble_strength > 0.0:
			var wobble_phase = float(particle.get("wobble_phase", 0.0)) + float(particle.get("wobble_speed", 6.0)) * delta
			particle_position.x += sin(wobble_phase) * wobble_strength * delta
			particle["wobble_phase"] = wobble_phase

		particle_rotation += angular_velocity * delta

		particle["age"] = age
		particle["velocity"] = velocity
		particle["position"] = particle_position
		particle["rotation"] = particle_rotation
		particles[i] = particle

	queue_redraw()

	if particles.is_empty():
		set_process(false)


func _draw():
	if not _can_emit():
		return

	for particle in particles:
		var age = float(particle.get("age", 0.0))
		var lifetime = max(0.01, float(particle.get("lifetime", 0.35)))
		var progress = clamp(age / lifetime, 0.0, 1.0)
		var color = particle.get("color", Color.WHITE)
		color.a *= 1.0 - progress

		var start_size = float(particle.get("size", 3.0))
		var end_size_scale = float(particle.get("end_size_scale", 0.35))
		var particle_size = max(1.0, lerp(start_size, start_size * end_size_scale, progress))
		var particle_position = particle.get("position", Vector2.ZERO)
		var shape = str(particle.get("shape", "chip"))
		var particle_rotation = float(particle.get("rotation", 0.0))
		var clip_bottom_y = float(particle.get("clip_bottom_y", INF))
		if particle_position.y + particle_size * 0.5 > clip_bottom_y:
			continue

		match shape:
			"sprite":
				var texture = particle.get("texture", null)
				if texture is Texture2D:
					draw_set_transform(particle_position, particle_rotation, Vector2.ONE)
					draw_texture_rect(
						texture,
						Rect2(Vector2(-particle_size * 0.5, -particle_size * 0.5), Vector2(particle_size, particle_size)),
						false,
						color
					)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					var rect = Rect2(particle_position - Vector2(particle_size, particle_size) * 0.5, Vector2(particle_size, particle_size))
					draw_rect(rect, color, true)
			"bubble":
				var bubble_radius = max(1.2, lerp(start_size * 0.62, start_size * 1.22, progress))
				var bubble_width = max(1.0, bubble_radius * 0.22)
				draw_arc(particle_position, bubble_radius, 0.0, TAU, 14, color, bubble_width)
				var highlight_color = color
				highlight_color.a *= 0.75
				draw_circle(particle_position + Vector2(-bubble_radius * 0.32, -bubble_radius * 0.30), max(0.75, bubble_radius * 0.16), highlight_color)
			"ripple":
				var ripple_width = lerp(particle_size, particle_size * float(particle.get("aspect", 3.0)), progress)
				draw_line(
					particle_position + Vector2(-ripple_width * 0.5, 0.0),
					particle_position + Vector2(ripple_width * 0.5, 0.0),
					color,
					max(1.0, particle_size * 0.24)
				)
			"water_drop":
				draw_circle(particle_position, particle_size * 0.5, color)
			"confetti":
				var aspect = float(particle.get("aspect", 1.0))
				var confetti_size = Vector2(particle_size * aspect, particle_size * 0.62)
				draw_set_transform(particle_position, particle_rotation, Vector2.ONE)
				draw_rect(Rect2(confetti_size * -0.5, confetti_size), color, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"streamer":
				var streamer_length = particle_size * float(particle.get("aspect", 2.2))
				draw_set_transform(particle_position, particle_rotation, Vector2.ONE)
				draw_line(Vector2(-streamer_length * 0.5, 0.0), Vector2(streamer_length * 0.5, 0.0), color, max(1.0, particle_size * 0.28))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"puff":
				draw_circle(particle_position, particle_size * 0.5, color)
			"leaf":
				var leaf_size = Vector2(particle_size * 1.35, particle_size * 0.72)
				var leaf_rect = Rect2(particle_position - leaf_size * 0.5, leaf_size)
				draw_rect(leaf_rect, color, true)
			_:
				var rect = Rect2(particle_position - Vector2(particle_size, particle_size) * 0.5, Vector2(particle_size, particle_size))
				draw_rect(rect, color, true)


func _spawn_block_burst(
	grid_pos: Vector2i,
	block_type: String,
	layer: String,
	count: int,
	speed_min: float,
	speed_max: float,
	lifetime_min: float,
	lifetime_max: float,
	size_min: float,
	size_max: float,
	gravity_strength: float,
	alpha_scale: float
):
	var center = _get_block_center(grid_pos)
	var palette = _get_block_palette(block_type, layer)

	for _i in range(count):
		var spawn_position = center + Vector2(
			rng.randf_range(-BLOCK_HALF_SIZE * 0.62, BLOCK_HALF_SIZE * 0.62),
			rng.randf_range(-BLOCK_HALF_SIZE * 0.62, BLOCK_HALF_SIZE * 0.62)
		)
		var direction = spawn_position - center
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		else:
			direction = direction.normalized()

		direction = (direction + Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.80, 0.18))).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.UP.rotated(rng.randf_range(-0.75, 0.75))

		var color = palette[rng.randi_range(0, palette.size() - 1)]
		color.a *= alpha_scale

		particles.append({
			"position": spawn_position,
			"velocity": direction * rng.randf_range(speed_min, speed_max),
			"gravity": Vector2(0.0, gravity_strength),
			"damping": rng.randf_range(0.84, 0.96),
			"lifetime": rng.randf_range(lifetime_min, lifetime_max),
			"age": 0.0,
			"size": rng.randf_range(size_min, size_max),
			"color": color
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_bomb_fire_break_burst(grid_pos: Vector2i) -> void:
	var fire_texture: Texture2D = get_fire_particle_texture()
	if fire_texture == null:
		return

	var center: Vector2 = _get_block_center(grid_pos)
	var flame_palette: Array = [
		Color(1.0, 1.0, 1.0, 0.96),
		Color(1.0, 0.84, 0.28, 0.94),
		Color(1.0, 0.42, 0.12, 0.90)
	]

	for _i in range(17):
		var spawn_position: Vector2 = center + Vector2(
			rng.randf_range(-11.0, 11.0),
			rng.randf_range(-12.0, 10.0)
		)
		var burst_direction: Vector2 = spawn_position - center
		if burst_direction.length_squared() < 0.01:
			burst_direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		else:
			burst_direction = burst_direction.normalized()

		var flame_scale: float = rng.randf_range(0.42, 1.12)
		var color: Color = flame_palette[rng.randi_range(0, flame_palette.size() - 1)]
		particles.append({
			"position": spawn_position,
			"velocity": Vector2(
				burst_direction.x * rng.randf_range(26.0, 74.0),
				rng.randf_range(-118.0, -34.0) + burst_direction.y * rng.randf_range(18.0, 54.0)
			),
			"gravity": Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-34.0, 18.0)),
			"damping": rng.randf_range(0.72, 0.89),
			"lifetime": rng.randf_range(0.30, 0.64),
			"age": 0.0,
			"size": FIRE_PARTICLE_BASE_SIZE * flame_scale,
			"end_size_scale": rng.randf_range(0.28, 0.62),
			"color": color,
			"shape": "sprite",
			"texture": fire_texture,
			"rotation": rng.randf_range(-0.65, 0.65),
			"angular_velocity": rng.randf_range(-3.4, 3.4),
			"wobble_strength": rng.randf_range(3.0, 9.5),
			"wobble_speed": rng.randf_range(8.0, 15.0),
			"wobble_phase": rng.randf_range(0.0, TAU)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_tree_growth_burst(grid_pos: Vector2i, block_type: String, stage: int):
	var clamped_stage: int = clampi(stage, 0, 3)
	var base_position: Vector2 = _get_block_center(grid_pos)
	var burst_height: float = lerp(10.0, 38.0, float(clamped_stage) / 3.0)
	var burst_width: float = lerp(14.0, 30.0, float(clamped_stage) / 3.0)
	var count: int = 12 + clamped_stage * 6
	var palette: Array = _get_tree_growth_palette(block_type, clamped_stage)

	if clamped_stage < 3:
		burst_height *= 0.55
		burst_width *= 0.55

	for _i in range(count):
		var spawn_position: Vector2 = base_position + Vector2(
			rng.randf_range(-burst_width, burst_width),
			rng.randf_range(-burst_height, -4.0)
		)
		var direction: Vector2 = Vector2(
			rng.randf_range(-0.92, 0.92),
			rng.randf_range(-1.35, -0.25)
		).normalized()
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]
		var shape := "confetti"
		if rng.randf() < 0.22:
			shape = "streamer"

		particles.append({
			"position": spawn_position,
			"velocity": direction * rng.randf_range(26.0 + clamped_stage * 8.0, 72.0 + clamped_stage * 14.0),
			"gravity": Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(38.0, 74.0)),
			"damping": rng.randf_range(0.76, 0.90),
			"lifetime": rng.randf_range(0.55, 0.92),
			"age": 0.0,
			"size": rng.randf_range(1.8, 3.5 + clamped_stage * 0.35),
			"color": color,
			"shape": shape,
			"rotation": rng.randf_range(0.0, TAU),
			"angular_velocity": rng.randf_range(-10.0, 10.0),
			"aspect": rng.randf_range(0.75, 1.95)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_tree_break_burst(grid_pos: Vector2i, block_type: String):
	var base_position: Vector2 = _get_block_center(grid_pos)
	var burst_origin: Vector2 = base_position + Vector2(0.0, -28.0)
	var palette: Array = _get_tree_break_palette(block_type)
	var count := 26

	for _i in range(count):
		var spawn_position: Vector2 = base_position + Vector2(
			rng.randf_range(-23.0, 23.0),
			rng.randf_range(-56.0, -4.0)
		)
		var direction: Vector2 = spawn_position - burst_origin
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		else:
			direction = direction.normalized()

		direction = (direction + Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.58, 0.24))).normalized()
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]

		particles.append({
			"position": spawn_position,
			"velocity": direction * rng.randf_range(48.0, 142.0),
			"gravity": Vector2(0.0, rng.randf_range(175.0, 265.0)),
			"damping": rng.randf_range(0.83, 0.95),
			"lifetime": rng.randf_range(0.34, 0.76),
			"age": 0.0,
			"size": rng.randf_range(1.6, 4.4),
			"color": color
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_water_splash_burst(burst_position: Vector2, intensity: float = 1.0):
	var splash_intensity: float = clampf(intensity, 0.35, 2.0)
	var droplet_count: int = int(round(6.0 + splash_intensity * 7.0))
	var palette: Array = [
		Color(0.55, 0.88, 1.0, 0.78),
		Color(0.78, 0.96, 1.0, 0.72),
		Color(0.28, 0.66, 1.0, 0.66)
	]

	for _i in range(droplet_count):
		var direction: Vector2 = Vector2(
			rng.randf_range(-0.95, 0.95),
			rng.randf_range(-1.25, -0.18)
		).normalized()
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]
		var spawn_position: Vector2 = burst_position + Vector2(
			rng.randf_range(-8.0, 8.0) * splash_intensity,
			rng.randf_range(-3.0, 2.0)
		)

		particles.append({
			"position": spawn_position,
			"velocity": direction * rng.randf_range(34.0, 112.0) * splash_intensity,
			"gravity": Vector2(0.0, rng.randf_range(210.0, 330.0)),
			"damping": rng.randf_range(0.78, 0.93),
			"lifetime": rng.randf_range(0.24, 0.50),
			"age": 0.0,
			"size": rng.randf_range(1.2, 2.9) * splash_intensity,
			"color": color,
			"shape": "water_drop"
		})

	for _i in range(2):
		particles.append({
			"position": burst_position + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-1.0, 2.0)),
			"velocity": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 3.0)),
			"gravity": Vector2.ZERO,
			"damping": 0.86,
			"lifetime": rng.randf_range(0.22, 0.38),
			"age": 0.0,
			"size": rng.randf_range(3.0, 5.0) * splash_intensity,
			"aspect": rng.randf_range(2.4, 4.0),
			"color": Color(0.68, 0.92, 1.0, 0.42),
			"shape": "ripple"
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_player_water_splash_burst(burst_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), water_surface_y: float = INF, intensity: float = 1.0):
	var splash_intensity: float = clampf(intensity, 0.55, 2.35)
	var splash_texture := get_water_splash_particle_texture()
	var body_half_width: float = max(6.0, abs(body_half_extents.x) * 1.22)
	var body_half_height: float = max(8.0, abs(body_half_extents.y))
	var exposed_top: float = burst_position.y - body_half_height * 1.02
	var exposed_bottom: float = min(burst_position.y + body_half_height * 0.70, water_surface_y - 2.0)

	if exposed_bottom < exposed_top:
		return

	var splash_count: int = int(round(6.0 + splash_intensity * 7.0))
	var palette: Array = [
		Color(0.90, 1.0, 1.0, 0.96),
		Color(0.58, 0.90, 1.0, 0.92),
		Color(0.24, 0.64, 1.0, 0.86)
	]

	for _i in range(splash_count):
		var side: float = -1.0 if (_i % 2) == 0 else 1.0
		if rng.randf() < 0.25:
			side *= -1.0
		var arbitrary_scale: float = rng.randf_range(0.65, 1.95) * rng.randf_range(0.90, 1.16) * splash_intensity
		var particle_size: float = WATER_SPLASH_PARTICLE_BASE_SIZE * arbitrary_scale
		var center_bottom_limit: float = min(exposed_bottom, water_surface_y - particle_size * 0.5 - 1.0)
		if center_bottom_limit < exposed_top:
			continue

		var spawn_position: Vector2 = Vector2(
			burst_position.x + side * rng.randf_range(body_half_width * 0.18, body_half_width * 1.08),
			rng.randf_range(exposed_top, center_bottom_limit)
		)
		var surface_pull: float = clampf((water_surface_y - spawn_position.y) / max(1.0, body_half_height), 0.0, 1.0)
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]

		particles.append({
			"position": spawn_position,
			"velocity": Vector2(
				side * rng.randf_range(56.0, 132.0) + rng.randf_range(-18.0, 18.0),
				rng.randf_range(-92.0, -24.0) * lerp(1.0, 0.58, surface_pull)
			) * PLAYER_WATER_SPLASH_MOTION_SCALE,
			"gravity": Vector2(0.0, rng.randf_range(120.0, 220.0) * PLAYER_WATER_SPLASH_MOTION_SCALE),
			"damping": rng.randf_range(0.72, 0.88),
			"lifetime": rng.randf_range(0.30, 0.58) * PLAYER_WATER_SPLASH_LIFETIME_SCALE,
			"age": 0.0,
			"size": WATER_SPLASH_PARTICLE_BASE_SIZE * arbitrary_scale,
			"end_size_scale": rng.randf_range(0.45, 0.78),
			"color": color,
			"shape": "sprite",
			"texture": splash_texture,
			"clip_bottom_y": water_surface_y - 1.0,
			"rotation": rng.randf_range(-0.88, 0.88),
			"angular_velocity": rng.randf_range(-3.6, 3.6) * PLAYER_WATER_SPLASH_MOTION_SCALE,
			"wobble_strength": rng.randf_range(2.5, 8.0),
			"wobble_speed": rng.randf_range(7.0, 14.0) * PLAYER_WATER_SPLASH_MOTION_SCALE,
			"wobble_phase": rng.randf_range(0.0, TAU)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_player_fire_burst(burst_position: Vector2, body_half_extents: Vector2 = Vector2(10.0, 16.0), intensity: float = 1.0):
	var fire_intensity: float = clampf(intensity, 0.45, 2.35)
	var fire_texture := get_fire_particle_texture()
	var body_half_width: float = max(5.0, abs(body_half_extents.x))
	var body_half_height: float = max(8.0, abs(body_half_extents.y))
	var flame_count: int = int(round(4.0 + fire_intensity * 4.0))
	var palette: Array = [
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 0.82, 0.36, 0.88),
		Color(1.0, 0.48, 0.18, 0.84)
	]

	for _i in range(flame_count):
		var spawn_position: Vector2 = burst_position + Vector2(
			rng.randf_range(-body_half_width * 0.68, body_half_width * 0.68),
			rng.randf_range(-body_half_height * 0.90, body_half_height * 0.55)
		)
		var outward: Vector2 = spawn_position - burst_position
		if outward.length_squared() < 0.01:
			outward = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		else:
			outward = outward.normalized()

		var arbitrary_scale: float = rng.randf_range(0.55, 1.75) * rng.randf_range(0.85, 1.15) * fire_intensity
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]

		particles.append({
			"position": spawn_position,
			"velocity": Vector2(
				outward.x * rng.randf_range(18.0, 58.0),
				rng.randf_range(-74.0, -24.0) - fire_intensity * 12.0
			),
			"gravity": Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-38.0, -8.0)),
			"damping": rng.randf_range(0.70, 0.88),
			"lifetime": rng.randf_range(0.22, 0.48),
			"age": 0.0,
			"size": FIRE_PARTICLE_BASE_SIZE * arbitrary_scale,
			"end_size_scale": rng.randf_range(0.34, 0.72),
			"color": color,
			"shape": "sprite",
			"texture": fire_texture,
			"rotation": rng.randf_range(-0.55, 0.55),
			"angular_velocity": rng.randf_range(-2.2, 2.2),
			"wobble_strength": rng.randf_range(2.0, 7.0),
			"wobble_speed": rng.randf_range(8.0, 15.0),
			"wobble_phase": rng.randf_range(0.0, TAU)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_underwater_bubbles_burst(burst_position: Vector2, count: int = 1):
	var bubble_count: int = clampi(count, 1, 3)
	var palette: Array = [
		Color(0.80, 0.96, 1.0, 0.58),
		Color(0.62, 0.88, 1.0, 0.50),
		Color(0.92, 1.0, 1.0, 0.46)
	]

	for _i in range(bubble_count):
		var spawn_position: Vector2 = burst_position + Vector2(
			rng.randf_range(-2.4, 2.4),
			rng.randf_range(-2.0, 2.0)
		)
		var color: Color = palette[rng.randi_range(0, palette.size() - 1)]

		particles.append({
			"position": spawn_position,
			"velocity": Vector2(rng.randf_range(-7.0, 8.0), rng.randf_range(-28.0, -46.0)),
			"gravity": Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-4.0, -13.0)),
			"damping": rng.randf_range(0.90, 0.98),
			"lifetime": rng.randf_range(1.05, 1.75),
			"age": 0.0,
			"size": rng.randf_range(2.2, 4.2),
			"color": color,
			"shape": "bubble",
			"wobble_strength": rng.randf_range(8.0, 18.0),
			"wobble_speed": rng.randf_range(4.2, 7.8),
			"wobble_phase": rng.randf_range(0.0, TAU)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func _spawn_oil_refinery_smoke_burst(burst_position: Vector2, count: int, smoke_texture: Texture2D):
	var smoke_count: int = clampi(count, 1, 12)
	var available_smoke_slots := maxi(0, OIL_REFINERY_SMOKE_MAX_ACTIVE - get_active_particle_count_for_source("oil_refinery_smoke"))
	if available_smoke_slots <= 0:
		return
	smoke_count = mini(smoke_count, available_smoke_slots)
	var smoke_palette: Array = [
		Color(0.82, 0.84, 0.82, 0.84),
		Color(0.62, 0.64, 0.62, 0.72),
		Color(0.42, 0.44, 0.42, 0.62)
	]

	for _i in range(smoke_count):
		var smoke_scale: float = rng.randf_range(0.58, 1.08)
		var spawn_position: Vector2 = burst_position + Vector2(
			rng.randf_range(-1.8, 2.2),
			rng.randf_range(-1.6, 1.2)
		)
		var color: Color = smoke_palette[rng.randi_range(0, smoke_palette.size() - 1)]

		particles.append({
			"position": spawn_position,
			"velocity": Vector2(
				rng.randf_range(-18.0, 8.0),
				rng.randf_range(-42.0, -20.0)
			),
			"gravity": Vector2(rng.randf_range(-5.0, 4.0), rng.randf_range(-9.0, -2.0)),
			"damping": rng.randf_range(0.90, 0.98),
			"lifetime": rng.randf_range(1.05, 1.65),
			"age": 0.0,
			"size": OIL_REFINERY_SMOKE_BASE_SIZE * smoke_scale,
			"end_size_scale": rng.randf_range(1.65, 2.35),
			"color": color,
			"shape": "sprite" if smoke_texture != null else "puff",
			"texture": smoke_texture,
			"source": "oil_refinery_smoke",
			"rotation": rng.randf_range(-0.30, 0.30),
			"angular_velocity": rng.randf_range(-1.4, 1.4),
			"wobble_strength": rng.randf_range(5.0, 14.0),
			"wobble_speed": rng.randf_range(2.8, 5.8),
			"wobble_phase": rng.randf_range(0.0, TAU)
		})

	_trim_particles()
	set_process(true)
	queue_redraw()


func get_active_particle_count_for_source(source: String) -> int:
	var active_count := 0
	for particle in particles:
		if str(particle.get("source", "")) == source:
			active_count += 1
	return active_count


func _trim_particles():
	while particles.size() > MAX_ACTIVE_PARTICLES:
		particles.remove_at(0)


func _get_block_center(grid_pos: Vector2i) -> Vector2:
	var block_size = 32.0
	if world != null:
		var world_block_size = world.get("BLOCK_SIZE")
		if world_block_size is int or world_block_size is float:
			block_size = float(world_block_size)

	return Vector2(grid_pos.x * block_size, grid_pos.y * block_size)


func _can_emit() -> bool:
	if world == null:
		return false
	if "in_world" in world and not bool(world.in_world):
		return false
	return true


func _should_emit_at_world_position(world_position: Vector2, margin_screen_px: float = PARTICLE_VISIBILITY_MARGIN_SCREEN_PX) -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return true

	var screen_rect: Rect2 = viewport.get_visible_rect().grow(margin_screen_px)
	var screen_position: Vector2 = viewport.get_canvas_transform() * world_position
	return screen_rect.has_point(screen_position)


func get_fire_particle_texture() -> Texture2D:
	if fire_particle_texture != null:
		return fire_particle_texture

	if ResourceLoader.exists(FIRE_PARTICLE_TEXTURE_PATH):
		var texture = load(FIRE_PARTICLE_TEXTURE_PATH)
		if texture is Texture2D:
			fire_particle_texture = texture

	return fire_particle_texture


func get_water_splash_particle_texture() -> Texture2D:
	if water_splash_particle_texture != null:
		return water_splash_particle_texture

	if ResourceLoader.exists(WATER_SPLASH_PARTICLE_TEXTURE_PATH):
		var texture = load(WATER_SPLASH_PARTICLE_TEXTURE_PATH)
		if texture is Texture2D:
			water_splash_particle_texture = texture

	return water_splash_particle_texture


func get_oil_refinery_smoke_texture(texture_path: String = OIL_REFINERY_SMOKE_TEXTURE_PATH) -> Texture2D:
	var clean_path := texture_path.strip_edges()
	if clean_path == "":
		clean_path = OIL_REFINERY_SMOKE_TEXTURE_PATH

	if clean_path == OIL_REFINERY_SMOKE_TEXTURE_PATH and oil_refinery_smoke_texture != null:
		return oil_refinery_smoke_texture

	if ResourceLoader.exists(clean_path):
		var texture = load(clean_path)
		if texture is Texture2D:
			if clean_path == OIL_REFINERY_SMOKE_TEXTURE_PATH:
				oil_refinery_smoke_texture = texture
			return texture

	return null


func get_blue_hit_particles_scene() -> PackedScene:
	if blue_hit_particles_scene != null:
		return blue_hit_particles_scene

	if ResourceLoader.exists(BLUE_HIT_PARTICLES_SCENE_PATH):
		var scene = load(BLUE_HIT_PARTICLES_SCENE_PATH)
		if scene is PackedScene:
			blue_hit_particles_scene = scene

	return blue_hit_particles_scene


func get_thunder_particles_scene() -> PackedScene:
	if thunder_particles_scene != null:
		return thunder_particles_scene

	if ResourceLoader.exists(THUNDER_PARTICLES_SCENE_PATH):
		var scene = load(THUNDER_PARTICLES_SCENE_PATH)
		if scene is PackedScene:
			thunder_particles_scene = scene

	return thunder_particles_scene


func get_water_surge_beam_scene() -> PackedScene:
	if water_surge_beam_scene != null:
		return water_surge_beam_scene

	if ResourceLoader.exists(WATER_SURGE_BEAM_SCENE_PATH):
		var scene = load(WATER_SURGE_BEAM_SCENE_PATH)
		if scene is PackedScene:
			water_surge_beam_scene = scene

	return water_surge_beam_scene


func get_fishing_reward_confetti_scene(rarity: String) -> PackedScene:
	match rarity.strip_edges().to_lower():
		"legendary":
			return get_legendary_fishing_reward_confetti_scene()
		"epic":
			return get_epic_fishing_reward_confetti_scene()
		_:
			return null


func get_epic_fishing_reward_confetti_scene() -> PackedScene:
	if epic_fishing_reward_confetti_scene != null:
		return epic_fishing_reward_confetti_scene

	if ResourceLoader.exists(EPIC_FISHING_REWARD_CONFETTI_SCENE_PATH):
		var scene = load(EPIC_FISHING_REWARD_CONFETTI_SCENE_PATH)
		if scene is PackedScene:
			epic_fishing_reward_confetti_scene = scene

	return epic_fishing_reward_confetti_scene


func get_legendary_fishing_reward_confetti_scene() -> PackedScene:
	if legendary_fishing_reward_confetti_scene != null:
		return legendary_fishing_reward_confetti_scene

	if ResourceLoader.exists(LEGENDARY_FISHING_REWARD_CONFETTI_SCENE_PATH):
		var scene = load(LEGENDARY_FISHING_REWARD_CONFETTI_SCENE_PATH)
		if scene is PackedScene:
			legendary_fishing_reward_confetti_scene = scene

	return legendary_fishing_reward_confetti_scene


func _get_block_palette(block_type: String, layer: String) -> Array:
	var clean = block_type.strip_edges().to_lower()
	var palette = _palette_for_block_type(clean)

	if layer.strip_edges().to_lower() == "background":
		var background_palette = []
		for color in palette:
			background_palette.append(Color(color.r * 0.82, color.g * 0.82, color.b * 0.88, color.a * 0.78))
		return background_palette

	return palette


func _get_tree_growth_palette(block_type: String, stage: int) -> Array:
	var block_palette: Array = _palette_for_block_type(block_type.strip_edges().to_lower())
	var alpha: float = 0.76 + float(stage) * 0.05
	var palette: Array = [
		Color(1.0, 0.28, 0.32, alpha),
		Color(1.0, 0.78, 0.22, alpha),
		Color(0.38, 0.92, 0.42, alpha),
		Color(0.24, 0.72, 1.0, alpha),
		Color(0.84, 0.42, 1.0, alpha),
		Color(1.0, 0.48, 0.82, alpha)
	]

	if not block_palette.is_empty():
		var block_color: Color = block_palette[0]
		palette.append(Color(block_color.r, block_color.g, block_color.b, min(0.92, block_color.a * 0.82)))

	return palette


func _get_tree_break_palette(block_type: String) -> Array:
	var block_palette: Array = _palette_for_block_type(block_type.strip_edges().to_lower())
	var palette: Array = [
		Color(0.50, 0.28, 0.13, 0.92),
		Color(0.74, 0.46, 0.22, 0.86),
		Color(0.28, 0.66, 0.22, 0.88),
		Color(0.48, 0.86, 0.28, 0.82),
		Color(0.18, 0.42, 0.14, 0.78)
	]

	for block_color in block_palette:
		palette.append(Color(block_color.r, block_color.g, block_color.b, min(0.92, block_color.a * 0.86)))

	return palette


func _palette_for_block_type(clean: String) -> Array:
	if clean.contains("snow") or clean.contains("frozen"):
		return [Color(0.88, 0.97, 1.0, 0.95), Color(0.65, 0.86, 1.0, 0.86), Color(1.0, 1.0, 1.0, 0.90)]
	if clean.contains("ice"):
		return [Color(0.68, 0.92, 1.0, 0.82), Color(0.40, 0.73, 0.96, 0.78), Color(0.95, 1.0, 1.0, 0.85)]
	if clean.contains("lava") or clean.contains("fire"):
		return [Color(1.0, 0.32, 0.12, 0.95), Color(1.0, 0.72, 0.16, 0.90), Color(0.80, 0.08, 0.05, 0.86)]
	if clean.contains("water"):
		return [Color(0.22, 0.68, 1.0, 0.78), Color(0.12, 0.38, 0.92, 0.72), Color(0.70, 0.95, 1.0, 0.75)]
	if clean.contains("gem") or clean.contains("crystal"):
		return [Color(0.28, 1.0, 0.78, 0.95), Color(0.46, 0.78, 1.0, 0.90), Color(0.95, 1.0, 0.84, 0.86)]
	if clean.contains("glass"):
		return [Color(0.72, 0.94, 1.0, 0.68), Color(0.92, 1.0, 1.0, 0.58), Color(0.38, 0.70, 0.90, 0.62)]
	if clean.contains("stone") or clean.contains("bedrock") or clean.contains("steel") or clean.contains("metal") or clean.contains("iron"):
		return [Color(0.50, 0.52, 0.58, 0.92), Color(0.70, 0.72, 0.76, 0.86), Color(0.32, 0.34, 0.40, 0.86)]
	if clean.contains("sand"):
		return [Color(0.92, 0.78, 0.46, 0.90), Color(0.74, 0.56, 0.28, 0.84), Color(1.0, 0.90, 0.60, 0.82)]
	if clean.contains("wood") or clean.contains("tree") or clean.contains("plank") or clean.contains("fence") or clean.contains("ladder"):
		return [Color(0.55, 0.32, 0.17, 0.92), Color(0.74, 0.48, 0.24, 0.86), Color(0.36, 0.20, 0.12, 0.84)]
	if clean.contains("leaf") or clean.contains("vines") or clean.contains("flower") or clean.contains("rose") or clean.contains("tulip"):
		return [Color(0.22, 0.70, 0.28, 0.90), Color(0.52, 0.86, 0.28, 0.84), Color(0.12, 0.44, 0.18, 0.84)]
	if clean.contains("dirt") or clean.contains("mud"):
		return [Color(0.47, 0.26, 0.13, 0.92), Color(0.64, 0.40, 0.22, 0.86), Color(0.30, 0.16, 0.09, 0.84)]

	var color_palette = _palette_for_color_name(clean)
	if not color_palette.is_empty():
		return color_palette

	return [Color(0.76, 0.72, 0.62, 0.88), Color(0.96, 0.90, 0.74, 0.82), Color(0.45, 0.42, 0.36, 0.80)]


func _palette_for_color_name(clean: String) -> Array:
	if clean.contains("aqua"):
		return [Color(0.18, 0.86, 0.92, 0.90), Color(0.10, 0.56, 0.70, 0.84), Color(0.76, 1.0, 1.0, 0.80)]
	if clean.contains("blue"):
		return [Color(0.24, 0.44, 0.96, 0.90), Color(0.12, 0.22, 0.70, 0.84), Color(0.62, 0.78, 1.0, 0.80)]
	if clean.contains("green"):
		return [Color(0.18, 0.72, 0.24, 0.90), Color(0.10, 0.42, 0.18, 0.84), Color(0.56, 0.92, 0.38, 0.80)]
	if clean.contains("yellow"):
		return [Color(0.96, 0.84, 0.20, 0.90), Color(0.74, 0.58, 0.10, 0.84), Color(1.0, 0.96, 0.58, 0.80)]
	if clean.contains("orange"):
		return [Color(1.0, 0.52, 0.14, 0.90), Color(0.76, 0.28, 0.08, 0.84), Color(1.0, 0.76, 0.34, 0.80)]
	if clean.contains("red"):
		return [Color(0.92, 0.18, 0.16, 0.90), Color(0.58, 0.08, 0.10, 0.84), Color(1.0, 0.52, 0.42, 0.80)]
	if clean.contains("pink"):
		return [Color(1.0, 0.42, 0.72, 0.90), Color(0.72, 0.18, 0.46, 0.84), Color(1.0, 0.76, 0.88, 0.80)]
	if clean.contains("purple"):
		return [Color(0.62, 0.34, 0.96, 0.90), Color(0.36, 0.16, 0.62, 0.84), Color(0.84, 0.66, 1.0, 0.80)]
	if clean.contains("brown"):
		return [Color(0.50, 0.30, 0.16, 0.90), Color(0.30, 0.16, 0.08, 0.84), Color(0.72, 0.48, 0.28, 0.80)]
	if clean.contains("black"):
		return [Color(0.08, 0.09, 0.12, 0.90), Color(0.20, 0.22, 0.28, 0.84), Color(0.38, 0.40, 0.48, 0.78)]
	if clean.contains("white"):
		return [Color(0.92, 0.94, 0.96, 0.86), Color(0.72, 0.76, 0.82, 0.78), Color(1.0, 1.0, 1.0, 0.82)]
	if clean.contains("gray") or clean.contains("grey"):
		return [Color(0.48, 0.50, 0.56, 0.90), Color(0.28, 0.30, 0.36, 0.84), Color(0.72, 0.74, 0.80, 0.78)]

	return []
