@tool
extends Node2D

@export var preview_emitting := true
@export var light_area := Vector2(96.0, 64.0)
@export var light_offset := Vector2(0.0, 32.0)
@export var light_color := Color(1.0, 0.84, 0.56, 1.0)
@export var light_energy := 1.65
@export var bulb_glow_energy := 0.44
@export var beam_visible := true
@export var beam_alpha := 0.32
@export var show_fixture := true
@export var flicker_strength := 0.035
@export var flicker_speed := 2.4
@export var shadows_enabled := true
@export var auto_create_block_occluders := true
@export var occluder_scan_radius := Vector2i(3, 2)

const EFFECT_Z_INDEX := 4075
const LIGHT_TEXTURE_SIZE := Vector2(96.0, 64.0)
const BLOCK_SIZE := 32.0
const OCCLUDER_REBUILD_SECONDS := 0.35

var particle_layers: Array[GPUParticles2D] = []
var warm_light: PointLight2D = null
var bulb_glow_light: PointLight2D = null
var beam_visual: Sprite2D = null
var fixture_visual: Sprite2D = null
var generated_occluder_root: Node2D = null
var flicker_phase := 0.0
var occluder_rebuild_timer := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = EFFECT_Z_INDEX
	warm_light = get_node_or_null("WarmCeilingLight") as PointLight2D
	bulb_glow_light = get_node_or_null("BulbGlowLight") as PointLight2D
	beam_visual = get_node_or_null("VisibleLightBeam") as Sprite2D
	fixture_visual = get_node_or_null("Fixture") as Sprite2D
	generated_occluder_root = get_node_or_null("GeneratedBlockLightOccluders") as Node2D
	collect_particle_layers()
	apply_light_settings()
	set_process(true)

	if preview_emitting:
		start()
	else:
		stop()


func start() -> void:
	preview_emitting = true
	apply_light_settings()
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = true


func stop() -> void:
	preview_emitting = false
	if warm_light != null and is_instance_valid(warm_light):
		warm_light.enabled = false
	if bulb_glow_light != null and is_instance_valid(bulb_glow_light):
		bulb_glow_light.enabled = false
	if beam_visual != null and is_instance_valid(beam_visual):
		beam_visual.visible = false
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = false


func restart() -> void:
	apply_light_settings()
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.emitting = false
		layer.restart()
		layer.emitting = true


func apply_light_settings() -> void:
	if warm_light == null or not is_instance_valid(warm_light):
		return

	var scale_factor := maxf(light_area.x / LIGHT_TEXTURE_SIZE.x, light_area.y / LIGHT_TEXTURE_SIZE.y)
	warm_light.position = light_offset
	warm_light.enabled = preview_emitting
	warm_light.color = light_color
	warm_light.energy = light_energy
	warm_light.texture_scale = maxf(0.1, scale_factor)
	warm_light.shadow_enabled = shadows_enabled
	warm_light.range_item_cull_mask = 1
	warm_light.shadow_item_cull_mask = 1

	if bulb_glow_light != null and is_instance_valid(bulb_glow_light):
		bulb_glow_light.enabled = preview_emitting
		bulb_glow_light.color = light_color
		bulb_glow_light.energy = bulb_glow_energy
		bulb_glow_light.shadow_enabled = shadows_enabled
		bulb_glow_light.range_item_cull_mask = 1
		bulb_glow_light.shadow_item_cull_mask = 1

	if beam_visual != null and is_instance_valid(beam_visual):
		beam_visual.position = light_offset
		beam_visual.scale = Vector2(scale_factor, scale_factor)
		beam_visual.visible = preview_emitting and beam_visible
		beam_visual.modulate = Color(light_color.r, light_color.g, light_color.b, beam_alpha)

	if fixture_visual != null and is_instance_valid(fixture_visual):
		fixture_visual.visible = show_fixture


func collect_particle_layers() -> void:
	particle_layers.clear()
	_collect_particle_layers_recursive(self)
	for layer in particle_layers:
		if layer == null or not is_instance_valid(layer):
			continue
		if layer.process_material != null:
			layer.process_material = layer.process_material.duplicate(true)


func _collect_particle_layers_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles2D:
			particle_layers.append(child)
		_collect_particle_layers_recursive(child)


func _process(delta: float) -> void:
	if preview_emitting and warm_light != null and is_instance_valid(warm_light):
		flicker_phase = wrapf(flicker_phase + delta * flicker_speed, 0.0, TAU)
		var flicker := 1.0 + sin(flicker_phase) * flicker_strength + sin(flicker_phase * 2.7) * flicker_strength * 0.35
		warm_light.energy = maxf(0.0, light_energy * flicker)
		if bulb_glow_light != null and is_instance_valid(bulb_glow_light):
			bulb_glow_light.energy = maxf(0.0, bulb_glow_energy * flicker)
		if beam_visual != null and is_instance_valid(beam_visual):
			beam_visual.modulate.a = clampf(beam_alpha * flicker, 0.0, 1.0)

	if Engine.is_editor_hint():
		return

	occluder_rebuild_timer -= delta
	if occluder_rebuild_timer <= 0.0:
		occluder_rebuild_timer = OCCLUDER_REBUILD_SECONDS
		rebuild_block_occluders()


func rebuild_block_occluders() -> void:
	if not auto_create_block_occluders or not shadows_enabled:
		clear_generated_occluders()
		return

	var world_node := find_world_node()
	if world_node == null:
		clear_generated_occluders()
		return

	var block_map = world_node.get("blocks")
	if not (block_map is Dictionary):
		clear_generated_occluders()
		return

	ensure_generated_occluder_root()
	clear_generated_occluders()

	var center_world := warm_light.global_position if warm_light != null and is_instance_valid(warm_light) else global_position + light_offset
	var center_grid := Vector2i(roundi(center_world.x / BLOCK_SIZE), roundi(center_world.y / BLOCK_SIZE))
	for gx in range(center_grid.x - occluder_scan_radius.x, center_grid.x + occluder_scan_radius.x + 1):
		for gy in range(center_grid.y - occluder_scan_radius.y, center_grid.y + occluder_scan_radius.y + 1):
			var grid_pos := Vector2i(gx, gy)
			if not block_map.has(grid_pos):
				continue

			var block_data = block_map.get(grid_pos, {})
			if block_data is Dictionary and not should_block_light(world_node, str(block_data.get("type", ""))):
				continue

			create_block_occluder(grid_pos)


func find_world_node() -> Node:
	var candidate := get_parent()
	while candidate != null:
		if "blocks" in candidate:
			return candidate
		candidate = candidate.get_parent()
	return null


func should_block_light(world_node: Node, block_type: String) -> bool:
	var clean_type := block_type.strip_edges().to_lower()
	if clean_type == "" or clean_type == "water":
		return false

	if world_node != null and "item_database" in world_node:
		var item_database = world_node.get("item_database")
		if item_database is Dictionary and item_database.has(clean_type):
			var item_data = item_database.get(clean_type, {})
			if item_data is Dictionary:
				if bool(item_data.get("no_collision", false)):
					return false
				if item_data.has("collidable") and not bool(item_data.get("collidable", true)):
					return false

	return true


func ensure_generated_occluder_root() -> void:
	if generated_occluder_root != null and is_instance_valid(generated_occluder_root):
		return

	generated_occluder_root = Node2D.new()
	generated_occluder_root.name = "GeneratedBlockLightOccluders"
	generated_occluder_root.z_as_relative = false
	generated_occluder_root.z_index = EFFECT_Z_INDEX - 1
	add_child(generated_occluder_root)


func clear_generated_occluders() -> void:
	if generated_occluder_root == null or not is_instance_valid(generated_occluder_root):
		return
	for child in generated_occluder_root.get_children():
		child.queue_free()


func create_block_occluder(grid_pos: Vector2i) -> void:
	if generated_occluder_root == null or not is_instance_valid(generated_occluder_root):
		return

	var occluder_polygon := OccluderPolygon2D.new()
	occluder_polygon.closed = true
	occluder_polygon.polygon = PackedVector2Array([
		Vector2(-BLOCK_SIZE * 0.5, -BLOCK_SIZE * 0.5),
		Vector2(BLOCK_SIZE * 0.5, -BLOCK_SIZE * 0.5),
		Vector2(BLOCK_SIZE * 0.5, BLOCK_SIZE * 0.5),
		Vector2(-BLOCK_SIZE * 0.5, BLOCK_SIZE * 0.5)
	])

	var occluder := LightOccluder2D.new()
	occluder.name = "BlockLightOccluder_%s_%s" % [grid_pos.x, grid_pos.y]
	occluder.occluder = occluder_polygon
	occluder.occluder_light_mask = 1
	occluder.position = generated_occluder_root.to_local(Vector2(grid_pos.x * BLOCK_SIZE, grid_pos.y * BLOCK_SIZE))
	generated_occluder_root.add_child(occluder)
