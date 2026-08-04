extends Node2D

const ELECTRIC_WIRE := "electric_wire"
const METAL_PAD := "metal_pad"
const GENERATOR := "generator"
const TRANSFORMER := "transformer"
const ELECTRIC_POLE := "electric_pole"
const ELECTRIC_TOOL := "electric_tool"
const DEVICE_WIRE := "wire"
const DEVICE_METAL_PAD := "metal_pad"
const DEVICE_GENERATOR := "generator"
const DEVICE_ELECTRIC_POLE := "electric_pole"
const MAX_GENERATOR_WATTS := 1000
const GENERATOR_CIRCUIT_COUNT := 4
const GENERATOR_CIRCUIT_CAPACITY := 5
const MAX_GENERATOR_LINKED_PADS := GENERATOR_CIRCUIT_COUNT * GENERATOR_CIRCUIT_CAPACITY
const GENERATOR_OUTPUT_COUNT := 4
const GENERATOR_OUTPUT_CAPACITY := 5
const MAX_GENERATOR_LINKED_POLES := GENERATOR_OUTPUT_COUNT * GENERATOR_OUTPUT_CAPACITY
const MAX_TRANSFORMER_LINKS_PER_POLE := 10
const MAX_POLE_LINKS_PER_POLE := 10
const LINK_MODE_INPUT := "input"
const LINK_MODE_OUTPUT := "output"
const LINK_MODE_REFINERY_INPUT := "refinery_input"
const LINK_MODE_CHARGER_INPUT := "battery_charger_input"
const LINK_MODE_POLE_COUPLING := "pole_coupling"
const LINK_ENDPOINT_TRANSFORMER := "transformer"
const LINK_ENDPOINT_METAL_PAD := "metal_pad"
const LINK_ENDPOINT_ELECTRIC_POLE := "electric_pole"
const LINK_ENDPOINT_OIL_REFINERY := "oil_refinery"
const LINK_ENDPOINT_BATTERY_CHARGER := "battery_charger"
const INVALID_LINK_GRID := Vector2i(999999, 999999)
const LINK_LINE_WIDTH := 1.0
const LINK_LINE_COLOR := Color(1.0, 0.84, 0.12, 0.92)
const LINK_LINE_PENDING_COLOR := Color(1.0, 0.92, 0.24, 0.72)
const LINK_LINE_VALID_COLOR := Color(0.95, 1.0, 0.28, 0.92)
const LINK_LINE_INVALID_COLOR := Color(1.0, 0.62, 0.18, 0.72)
const ELECTRIC_WIRE_FLOW_PARTICLES_SCENE_PATH := "res://Scenes/particles/ElectricWireFlowParticlesFX.tscn"
const ENABLE_PERSISTENT_WIRE_FLOW_FX := true
const MAX_PERSISTENT_WIRE_FLOW_FX := 8

var world = null
var electrical_tiles: Dictionary = {}
var electrical_visible := false
var tile_sprites: Dictionary = {}
var texture_cache: Dictionary = {}
var wire_flow_particles_scene: PackedScene = null
var generator_link_mode_active := false
var generator_link_mode_kind := LINK_MODE_INPUT
var generator_link_source_grid := Vector2i.ZERO
var oil_refinery_link_mode_active := false
var oil_refinery_link_source_grid := Vector2i.ZERO
var battery_charger_link_mode_active := false
var battery_charger_link_source_grid := Vector2i.ZERO
var electric_tool_link_mode_active := false
var electric_tool_link_source_grid := INVALID_LINK_GRID
var electric_tool_link_source_type := ""
var local_generator_links: Dictionary = {}
var local_generator_output_links: Dictionary = {}
var local_oil_refinery_links: Dictionary = {}
var local_battery_charger_links: Dictionary = {}
var local_pole_links: Dictionary = {}
var link_lines: Dictionary = {}
var link_flow_particles: Dictionary = {}
var link_preview_line: Line2D = null
var last_visibility_snapshot_key := ""


func setup(world_ref) -> void:
	world = world_ref
	name = "ElectricityManager"
	z_as_relative = false
	z_index = 2600
	visible = true
	load_textures()
	set_process(false)
	refresh_all_visuals()


func load_textures() -> void:
	texture_cache.clear()
	# Wires are visual link lines now, not placeable electrical-layer sprites.


func get_texture_path_for_item(item_id: String) -> String:
	match item_id:
		ELECTRIC_WIRE:
			return "res://Assets/blocks/electric/electric_wire.svg"
		METAL_PAD:
			return "res://Assets/blocks/electric/metal_pad.png"
		GENERATOR, TRANSFORMER:
			return "res://Assets/blocks/electric/generator.png"
		ELECTRIC_POLE:
			return "res://Assets/blocks/electric/electric_pole.png"
	return ""


func grid_to_world_pos(grid_pos: Vector2i) -> Vector2:
	if world != null and world.has_method("grid_to_world_center"):
		return world.grid_to_world_center(grid_pos)
	var block_size := 32
	if world != null and "BLOCK_SIZE" in world:
		block_size = int(world.BLOCK_SIZE)
	return Vector2(float(grid_pos.x * block_size), float(grid_pos.y * block_size))


func is_electrical_item(item_id: String) -> bool:
	var clean_item := str(item_id).strip_edges()
	if clean_item == "":
		return false
	if clean_item == ELECTRIC_WIRE:
		return false
	if world != null and "item_database" in world and world.item_database.has(clean_item):
		return bool(world.item_database[clean_item].get("electrical_layer", false))
	return false


func has_electric_tool_equipped() -> bool:
	return world != null and str(world.equipped_tool).strip_edges() == ELECTRIC_TOOL


func make_link_endpoint(endpoint_type: String, grid_pos: Vector2i) -> Dictionary:
	return {
		"type": endpoint_type,
		"grid": grid_pos
	}


func get_link_endpoint_type(endpoint: Dictionary) -> String:
	return str(endpoint.get("type", "")).strip_edges().to_lower()


func get_link_endpoint_grid(endpoint: Dictionary) -> Vector2i:
	var grid_value: Variant = endpoint.get("grid", INVALID_LINK_GRID)
	if grid_value is Vector2i:
		return grid_value
	return INVALID_LINK_GRID


func is_link_endpoint_valid(endpoint: Dictionary) -> bool:
	return get_link_endpoint_type(endpoint) != "" and get_link_endpoint_grid(endpoint) != INVALID_LINK_GRID


func get_anchor_grid_for_link(raw_grid: Vector2i) -> Vector2i:
	if world != null and world.has_method("get_anchor_grid_for_block_area"):
		var anchor_grid: Vector2i = world.get_anchor_grid_for_block_area(raw_grid)
		if anchor_grid != INVALID_LINK_GRID:
			return anchor_grid
	return raw_grid


func resolve_electrical_link_endpoint(raw_grid: Vector2i) -> Dictionary:
	if world == null:
		return {}

	var anchor_grid := get_anchor_grid_for_link(raw_grid)
	if is_visible_generator_at(anchor_grid):
		return make_link_endpoint(LINK_ENDPOINT_TRANSFORMER, anchor_grid)
	if is_oil_refinery_at(anchor_grid):
		return make_link_endpoint(LINK_ENDPOINT_OIL_REFINERY, anchor_grid)
	if is_battery_charger_at(anchor_grid):
		return make_link_endpoint(LINK_ENDPOINT_BATTERY_CHARGER, anchor_grid)

	var pole_grid := resolve_electric_pole_grid(raw_grid)
	if pole_grid != INVALID_LINK_GRID and is_electric_pole_at(pole_grid):
		return make_link_endpoint(LINK_ENDPOINT_ELECTRIC_POLE, pole_grid)

	if is_metal_pad_at(raw_grid):
		return make_link_endpoint(LINK_ENDPOINT_METAL_PAD, raw_grid)
	if anchor_grid != raw_grid and is_metal_pad_at(anchor_grid):
		return make_link_endpoint(LINK_ENDPOINT_METAL_PAD, anchor_grid)

	return {}


func get_link_endpoint_display_name(endpoint_type: String) -> String:
	match str(endpoint_type).strip_edges().to_lower():
		LINK_ENDPOINT_TRANSFORMER:
			return "transformer"
		LINK_ENDPOINT_METAL_PAD:
			return "metal pad"
		LINK_ENDPOINT_ELECTRIC_POLE:
			return "electric pole"
		LINK_ENDPOINT_OIL_REFINERY:
			return "oil refinery"
		LINK_ENDPOINT_BATTERY_CHARGER:
			return "battery charger"
	return "electrical device"


func get_electric_tool_link_target_prompt(endpoint_type: String) -> String:
	match str(endpoint_type).strip_edges().to_lower():
		LINK_ENDPOINT_TRANSFORMER:
			return "Tap a metal pad or electric pole to link this transformer."
		LINK_ENDPOINT_METAL_PAD:
			return "Tap a transformer to link this metal pad."
		LINK_ENDPOINT_ELECTRIC_POLE:
			return "Tap a transformer, oil refinery, battery charger, or another electric pole to link this electric pole."
		LINK_ENDPOINT_OIL_REFINERY:
			return "Tap an electric pole to link this oil refinery."
		LINK_ENDPOINT_BATTERY_CHARGER:
			return "Tap an electric pole to link this battery charger."
	return "Tap a compatible electrical device to link."


func make_grid_key(grid_pos: Vector2i) -> String:
	return str(grid_pos.x) + "," + str(grid_pos.y)


func is_metal_pad_at(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if world.block_manager != null and "background_blocks" in world.block_manager:
		var background_blocks = world.block_manager.get("background_blocks")
		if background_blocks is Dictionary and background_blocks.has(grid_pos):
			var block_data = background_blocks[grid_pos]
			if block_data is Dictionary:
				return str(block_data.get("type", "")).strip_edges() == METAL_PAD
	return false


func is_electric_pole_at(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not ("blocks" in world):
		return false
	if not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks[grid_pos]
	if block_data is Dictionary:
		return str(block_data.get("type", "")).strip_edges() == ELECTRIC_POLE
	return false


func resolve_electric_pole_grid(grid_pos: Vector2i) -> Vector2i:
	if is_electric_pole_at(grid_pos):
		return grid_pos

	if world != null and world.has_method("get_anchor_grid_for_block_area"):
		var anchor_grid: Vector2i = world.get_anchor_grid_for_block_area(grid_pos)
		if is_electric_pole_at(anchor_grid):
			return anchor_grid

	var best_grid := Vector2i(999999, 999999)
	var best_distance := INF
	var pointer_pos := grid_to_world_pos(grid_pos)
	if world != null and world.has_method("get_pointer_global_position"):
		pointer_pos = world.get_pointer_global_position()

	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var candidate := grid_pos + Vector2i(offset_x, offset_y)
			if not is_electric_pole_at(candidate):
				continue
			var distance := pointer_pos.distance_squared_to(grid_to_world_pos(candidate))
			if distance < best_distance:
				best_distance = distance
				best_grid = candidate

	return best_grid


func is_oil_refinery_at(grid_pos: Vector2i) -> bool:
	if world == null or not ("blocks" in world):
		return false
	if not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks[grid_pos]
	var block_type := ""
	if block_data is Dictionary:
		block_type = str(block_data.get("type", "")).strip_edges()
	else:
		block_type = str(block_data).strip_edges()
	if world.has_method("is_oil_refinery_block_type"):
		return bool(world.is_oil_refinery_block_type(block_type))
	if world != null and "item_database" in world and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("oil_refinery_block", false))
	return block_type == "oil_refinery"


func is_battery_charger_at(grid_pos: Vector2i) -> bool:
	if world == null or not ("blocks" in world):
		return false
	if not world.blocks.has(grid_pos):
		return false
	var block_data = world.blocks[grid_pos]
	var block_type := ""
	if block_data is Dictionary:
		block_type = str(block_data.get("type", "")).strip_edges()
	else:
		block_type = str(block_data).strip_edges()
	if world.has_method("is_battery_charger_block_type"):
		return bool(world.is_battery_charger_block_type(block_type))
	if world != null and "item_database" in world and world.item_database.has(block_type):
		return bool(world.item_database[block_type].get("battery_charger_block", false))
	return block_type == "battery_charger"


func is_transformer_item_id(item_id: String) -> bool:
	var clean_item := str(item_id).strip_edges().to_lower()
	return clean_item == GENERATOR or clean_item == TRANSFORMER


func _process(_delta: float) -> void:
	if generator_link_mode_active:
		update_link_preview_line()
	elif oil_refinery_link_mode_active:
		update_oil_refinery_link_preview_line()
	elif battery_charger_link_mode_active:
		update_battery_charger_link_preview_line()
	elif electric_tool_link_mode_active:
		update_electric_tool_link_preview_line()


func parse_grid_key(key: String) -> Vector2i:
	var parts := str(key).split(",", false)
	if parts.size() != 2:
		return Vector2i(999999, 999999)
	return Vector2i(int(parts[0]), int(parts[1]))


func normalize_electrical_link_kind(value: String) -> String:
	var clean := str(value).strip_edges().to_lower()
	if clean == LINK_MODE_OUTPUT or clean == "electric_pole" or clean == "pole":
		return LINK_MODE_OUTPUT
	if clean == LINK_MODE_REFINERY_INPUT or clean == "oil_refinery" or clean == "refinery" or clean == "oil_refinery_input":
		return LINK_MODE_REFINERY_INPUT
	if clean == LINK_MODE_CHARGER_INPUT or clean == "battery_charger" or clean == "charger" or clean == "battery_charger_input":
		return LINK_MODE_CHARGER_INPUT
	if clean == LINK_MODE_POLE_COUPLING or clean == "pole_link" or clean == "electric_pole_link":
		return LINK_MODE_POLE_COUPLING
	return LINK_MODE_INPUT


func make_link_key(source_grid: Vector2i, target_grid: Vector2i, link_kind: String = LINK_MODE_INPUT) -> String:
	var clean_kind := normalize_electrical_link_kind(link_kind)
	return clean_kind + "|" + make_grid_key(source_grid) + "|" + make_grid_key(target_grid)


func make_pole_link_key(pole_a_grid: Vector2i, pole_b_grid: Vector2i) -> String:
	var key_a := make_grid_key(pole_a_grid)
	var key_b := make_grid_key(pole_b_grid)
	if key_b < key_a:
		var swap_key := key_a
		key_a = key_b
		key_b = swap_key
	return LINK_MODE_POLE_COUPLING + "|" + key_a + "|" + key_b


func make_wire_line(line_name: String, color: Color) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.width = LINK_LINE_WIDTH
	line.default_color = color
	line.z_as_relative = true
	line.z_index = 2
	line.top_level = false
	add_child(line)
	return line


func set_line_points(line: Line2D, start_pos: Vector2, end_pos: Vector2) -> void:
	if line == null or not is_instance_valid(line):
		return
	if line.get_point_count() == 2:
		if line.get_point_position(0).is_equal_approx(start_pos) and line.get_point_position(1).is_equal_approx(end_pos):
			return
		line.set_point_position(0, start_pos)
		line.set_point_position(1, end_pos)
		return
	line.clear_points()
	line.add_point(start_pos)
	line.add_point(end_pos)


func get_wire_flow_particles_scene() -> PackedScene:
	if wire_flow_particles_scene != null:
		return wire_flow_particles_scene
	if not ResourceLoader.exists(ELECTRIC_WIRE_FLOW_PARTICLES_SCENE_PATH):
		return null

	var scene = load(ELECTRIC_WIRE_FLOW_PARTICLES_SCENE_PATH)
	if scene is PackedScene:
		wire_flow_particles_scene = scene
	return wire_flow_particles_scene


func get_flow_segment_for_link(source_grid: Vector2i, target_grid: Vector2i, link_kind: String) -> Dictionary:
	var source_position := grid_to_world_pos(source_grid)
	var target_position := grid_to_world_pos(target_grid)
	var clean_kind := normalize_electrical_link_kind(link_kind)
	if clean_kind == LINK_MODE_INPUT or clean_kind == LINK_MODE_REFINERY_INPUT or clean_kind == LINK_MODE_CHARGER_INPUT:
		return {
			"start": target_position,
			"end": source_position
		}
	return {
		"start": source_position,
		"end": target_position
	}


func update_wire_flow_particles(link_key: String, source_grid: Vector2i, target_grid: Vector2i, link_kind: String) -> void:
	if not electrical_visible or not ENABLE_PERSISTENT_WIRE_FLOW_FX:
		remove_wire_flow_particles(link_key)
		return

	var scene := get_wire_flow_particles_scene()
	if scene == null:
		return

	var effect = link_flow_particles.get(link_key, null)
	if effect == null or not is_instance_valid(effect):
		if link_flow_particles.size() >= MAX_PERSISTENT_WIRE_FLOW_FX:
			return
		effect = scene.instantiate()
		if effect == null:
			return
		effect.name = "ElectricWireFlowParticles"
		add_child(effect)
		link_flow_particles[link_key] = effect

	effect.set("preview_emitting", true)
	effect.set("show_wire_preview_line", false)
	effect.set("draw_cpu_pulses", false)
	effect.set("wire_thickness_px", LINK_LINE_WIDTH)
	effect.set("pulse_count", 2)
	effect.set("pulse_length_px", 16.0)
	effect.set("pulse_jitter_px", 1.25)
	effect.set("pulse_core_width_px", 0.65)
	var segment := get_flow_segment_for_link(source_grid, target_grid, link_kind)
	if effect.has_method("set_local_wire_segment"):
		effect.set_local_wire_segment(segment.get("start", Vector2.ZERO), segment.get("end", Vector2.ZERO))
	else:
		var start_position: Vector2 = segment.get("start", Vector2.ZERO)
		var end_position: Vector2 = segment.get("end", Vector2.ZERO)
		var offset := end_position - start_position
		effect.position = start_position
		effect.rotation = offset.angle()
		effect.set("flow_length_px", offset.length())


func remove_wire_flow_particles(link_key: String) -> void:
	if not link_flow_particles.has(link_key):
		return
	var effect = link_flow_particles[link_key]
	link_flow_particles.erase(link_key)
	if effect != null and is_instance_valid(effect):
		effect.queue_free()


func ensure_link_preview_line() -> Line2D:
	if link_preview_line != null and is_instance_valid(link_preview_line):
		return link_preview_line
	link_preview_line = make_wire_line("GeneratorLinkPreview", LINK_LINE_PENDING_COLOR)
	return link_preview_line


func remove_link_preview_line() -> void:
	if link_preview_line != null and is_instance_valid(link_preview_line):
		link_preview_line.queue_free()
	link_preview_line = null


func update_link_preview_line() -> void:
	if not generator_link_mode_active:
		return
	var line := ensure_link_preview_line()
	var start_pos := grid_to_world_pos(generator_link_source_grid)
	var target_grid: Vector2i = generator_link_source_grid
	if world != null and world.has_method("get_mouse_grid_position"):
		target_grid = world.get_mouse_grid_position()
	var resolved_target := resolve_link_target_for_kind(target_grid, generator_link_mode_kind)
	var target_valid := is_valid_generator_link_target(resolved_target)
	var end_pos := grid_to_world_pos(resolved_target) if target_valid else get_link_pointer_position()
	line.default_color = LINK_LINE_VALID_COLOR if target_valid else LINK_LINE_PENDING_COLOR
	set_line_points(line, start_pos, end_pos)


func update_oil_refinery_link_preview_line() -> void:
	if not oil_refinery_link_mode_active:
		return
	var line := ensure_link_preview_line()
	var start_pos := grid_to_world_pos(oil_refinery_link_source_grid)
	var target_grid: Vector2i = oil_refinery_link_source_grid
	if world != null and world.has_method("get_mouse_grid_position"):
		target_grid = world.get_mouse_grid_position()
	var resolved_target := resolve_electric_pole_grid(target_grid)
	var target_valid := is_valid_oil_refinery_link_target(resolved_target)
	var end_pos := grid_to_world_pos(resolved_target) if target_valid else get_link_pointer_position()
	line.default_color = LINK_LINE_VALID_COLOR if target_valid else LINK_LINE_PENDING_COLOR
	set_line_points(line, start_pos, end_pos)


func update_battery_charger_link_preview_line() -> void:
	if not battery_charger_link_mode_active:
		return
	var line := ensure_link_preview_line()
	var start_pos := grid_to_world_pos(battery_charger_link_source_grid)
	var target_grid: Vector2i = battery_charger_link_source_grid
	if world != null and world.has_method("get_mouse_grid_position"):
		target_grid = world.get_mouse_grid_position()
	var resolved_target := resolve_electric_pole_grid(target_grid)
	var target_valid := is_valid_battery_charger_link_target(resolved_target)
	var end_pos := grid_to_world_pos(resolved_target) if target_valid else get_link_pointer_position()
	line.default_color = LINK_LINE_VALID_COLOR if target_valid else LINK_LINE_PENDING_COLOR
	set_line_points(line, start_pos, end_pos)


func make_electric_tool_link_pair(endpoint_a: Dictionary, endpoint_b: Dictionary) -> Dictionary:
	if not is_link_endpoint_valid(endpoint_a) or not is_link_endpoint_valid(endpoint_b):
		return {}

	var type_a := get_link_endpoint_type(endpoint_a)
	var type_b := get_link_endpoint_type(endpoint_b)
	var grid_a := get_link_endpoint_grid(endpoint_a)
	var grid_b := get_link_endpoint_grid(endpoint_b)

	if type_a == LINK_ENDPOINT_ELECTRIC_POLE and type_b == LINK_ENDPOINT_ELECTRIC_POLE and grid_a != grid_b:
		return {
			"kind": LINK_MODE_POLE_COUPLING,
			"pole_a_grid": grid_a,
			"pole_b_grid": grid_b
		}

	if type_a == LINK_ENDPOINT_TRANSFORMER and type_b == LINK_ENDPOINT_METAL_PAD:
		return {
			"kind": LINK_MODE_INPUT,
			"generator_grid": grid_a,
			"pad_grid": grid_b
		}
	if type_b == LINK_ENDPOINT_TRANSFORMER and type_a == LINK_ENDPOINT_METAL_PAD:
		return {
			"kind": LINK_MODE_INPUT,
			"generator_grid": grid_b,
			"pad_grid": grid_a
		}

	if type_a == LINK_ENDPOINT_TRANSFORMER and type_b == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_OUTPUT,
			"generator_grid": grid_a,
			"pole_grid": grid_b
		}
	if type_b == LINK_ENDPOINT_TRANSFORMER and type_a == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_OUTPUT,
			"generator_grid": grid_b,
			"pole_grid": grid_a
		}

	if type_a == LINK_ENDPOINT_OIL_REFINERY and type_b == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_REFINERY_INPUT,
			"refinery_grid": grid_a,
			"pole_grid": grid_b
		}
	if type_b == LINK_ENDPOINT_OIL_REFINERY and type_a == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_REFINERY_INPUT,
			"refinery_grid": grid_b,
			"pole_grid": grid_a
		}

	if type_a == LINK_ENDPOINT_BATTERY_CHARGER and type_b == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_CHARGER_INPUT,
			"charger_grid": grid_a,
			"pole_grid": grid_b
		}
	if type_b == LINK_ENDPOINT_BATTERY_CHARGER and type_a == LINK_ENDPOINT_ELECTRIC_POLE:
		return {
			"kind": LINK_MODE_CHARGER_INPUT,
			"charger_grid": grid_b,
			"pole_grid": grid_a
		}

	return {}


func get_link_pair_grid(pair: Dictionary, key: String) -> Vector2i:
	var grid_value: Variant = pair.get(key, INVALID_LINK_GRID)
	if grid_value is Vector2i:
		return grid_value
	return INVALID_LINK_GRID


func update_electric_tool_link_preview_line() -> void:
	if not electric_tool_link_mode_active:
		return
	var line := ensure_link_preview_line()
	var source_endpoint := make_link_endpoint(electric_tool_link_source_type, electric_tool_link_source_grid)
	var target_grid := electric_tool_link_source_grid
	if world != null and world.has_method("get_mouse_grid_position"):
		target_grid = world.get_mouse_grid_position()
	var target_endpoint := resolve_electrical_link_endpoint(target_grid)
	var pair := make_electric_tool_link_pair(source_endpoint, target_endpoint)
	var has_target_endpoint := is_link_endpoint_valid(target_endpoint)
	var target_valid := not pair.is_empty()
	var end_pos := grid_to_world_pos(get_link_endpoint_grid(target_endpoint)) if has_target_endpoint else get_link_pointer_position()
	line.default_color = LINK_LINE_VALID_COLOR if target_valid else (LINK_LINE_INVALID_COLOR if has_target_endpoint else LINK_LINE_PENDING_COLOR)
	set_line_points(line, grid_to_world_pos(electric_tool_link_source_grid), end_pos)


func get_link_pointer_position() -> Vector2:
	if world != null and "player" in world and world.player != null:
		return world.player.global_position
	if world != null and world.has_method("get_pointer_global_position"):
		return world.get_pointer_global_position()
	return get_global_mouse_position()


func get_generator_link_target_name() -> String:
	return "electric pole" if generator_link_mode_kind == LINK_MODE_OUTPUT else "metal pad"


func get_generator_link_target_prompt() -> String:
	return "an electric pole" if generator_link_mode_kind == LINK_MODE_OUTPUT else "a metal pad"


func is_valid_generator_link_target(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if generator_link_mode_kind == LINK_MODE_OUTPUT:
		if not is_electric_pole_at(grid_pos):
			return false
	else:
		if not is_metal_pad_at(grid_pos):
			return false
	if world.has_method("can_reach_grid") and not bool(world.can_reach_grid(grid_pos)):
		return false
	return is_visible_generator_at(generator_link_source_grid)


func resolve_link_target_for_kind(target_grid: Vector2i, link_kind: String) -> Vector2i:
	var clean_kind := normalize_generator_link_kind(link_kind)
	if clean_kind == LINK_MODE_OUTPUT:
		return resolve_electric_pole_grid(target_grid)
	return target_grid


func is_valid_oil_refinery_link_target(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not is_electric_pole_at(grid_pos):
		return false
	if world.has_method("can_reach_grid") and not bool(world.can_reach_grid(grid_pos)):
		return false
	return is_oil_refinery_at(oil_refinery_link_source_grid)


func is_valid_battery_charger_link_target(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	if not is_electric_pole_at(grid_pos):
		return false
	if world.has_method("can_reach_grid") and not bool(world.can_reach_grid(grid_pos)):
		return false
	return is_battery_charger_at(battery_charger_link_source_grid)


func normalize_generator_link_kind(value: String) -> String:
	var clean := normalize_electrical_link_kind(value)
	if clean == LINK_MODE_OUTPUT:
		return LINK_MODE_OUTPUT
	return LINK_MODE_INPUT


func is_valid_link_target_for_kind(target_grid: Vector2i, link_kind: String) -> bool:
	var clean_kind := normalize_generator_link_kind(link_kind)
	if clean_kind == LINK_MODE_OUTPUT:
		return is_electric_pole_at(resolve_electric_pole_grid(target_grid))
	return is_metal_pad_at(target_grid)


func draw_generator_link_line(generator_grid: Vector2i, target_grid: Vector2i, link_kind: String = LINK_MODE_INPUT, color: Color = LINK_LINE_COLOR) -> void:
	if not electrical_visible:
		return
	if not is_visible_generator_at(generator_grid):
		return
	var clean_kind := normalize_generator_link_kind(link_kind)
	if not is_valid_link_target_for_kind(target_grid, clean_kind):
		return
	var link_key := make_link_key(generator_grid, target_grid, clean_kind)
	var line: Line2D = null
	if link_lines.has(link_key):
		var existing = link_lines[link_key]
		if existing is Line2D and is_instance_valid(existing):
			line = existing
	if line == null:
		line = make_wire_line("GeneratorLinkLine", color)
		link_lines[link_key] = line
	line.default_color = color
	set_line_points(line, grid_to_world_pos(generator_grid), grid_to_world_pos(target_grid))
	update_wire_flow_particles(link_key, generator_grid, target_grid, clean_kind)


func draw_oil_refinery_link_line(refinery_grid: Vector2i, pole_grid: Vector2i, color: Color = LINK_LINE_COLOR) -> void:
	if not electrical_visible:
		return
	if not is_oil_refinery_at(refinery_grid):
		return
	if not is_electric_pole_at(pole_grid):
		return
	var link_key := make_link_key(refinery_grid, pole_grid, LINK_MODE_REFINERY_INPUT)
	var line: Line2D = null
	if link_lines.has(link_key):
		var existing = link_lines[link_key]
		if existing is Line2D and is_instance_valid(existing):
			line = existing
	if line == null:
		line = make_wire_line("OilRefineryLinkLine", color)
		link_lines[link_key] = line
	line.default_color = color
	set_line_points(line, grid_to_world_pos(refinery_grid), grid_to_world_pos(pole_grid))
	update_wire_flow_particles(link_key, refinery_grid, pole_grid, LINK_MODE_REFINERY_INPUT)


func draw_battery_charger_link_line(charger_grid: Vector2i, pole_grid: Vector2i, color: Color = LINK_LINE_COLOR) -> void:
	if not electrical_visible:
		return
	if not is_battery_charger_at(charger_grid):
		return
	if not is_electric_pole_at(pole_grid):
		return
	var link_key := make_link_key(charger_grid, pole_grid, LINK_MODE_CHARGER_INPUT)
	var line: Line2D = null
	if link_lines.has(link_key):
		var existing = link_lines[link_key]
		if existing is Line2D and is_instance_valid(existing):
			line = existing
	if line == null:
		line = make_wire_line("BatteryChargerLinkLine", color)
		link_lines[link_key] = line
	line.default_color = color
	set_line_points(line, grid_to_world_pos(charger_grid), grid_to_world_pos(pole_grid))
	update_wire_flow_particles(link_key, charger_grid, pole_grid, LINK_MODE_CHARGER_INPUT)


func draw_pole_link_line(pole_a_grid: Vector2i, pole_b_grid: Vector2i, color: Color = LINK_LINE_COLOR) -> void:
	if not electrical_visible:
		return
	if pole_a_grid == pole_b_grid:
		return
	if not is_electric_pole_at(pole_a_grid):
		return
	if not is_electric_pole_at(pole_b_grid):
		return
	var link_key := make_pole_link_key(pole_a_grid, pole_b_grid)
	var line: Line2D = null
	if link_lines.has(link_key):
		var existing = link_lines[link_key]
		if existing is Line2D and is_instance_valid(existing):
			line = existing
	if line == null:
		line = make_wire_line("PoleLinkLine", color)
		link_lines[link_key] = line
	line.default_color = color
	set_line_points(line, grid_to_world_pos(pole_a_grid), grid_to_world_pos(pole_b_grid))
	update_wire_flow_particles(link_key, pole_a_grid, pole_b_grid, LINK_MODE_POLE_COUPLING)


func remove_generator_link_line(link_key: String) -> void:
	remove_wire_flow_particles(link_key)
	if not link_lines.has(link_key):
		return
	var line = link_lines[link_key]
	link_lines.erase(link_key)
	if line != null and is_instance_valid(line):
		line.queue_free()


func clear_link_line_visuals() -> void:
	for link_key in link_lines.keys():
		remove_generator_link_line(str(link_key))
	for link_key in link_flow_particles.keys():
		remove_wire_flow_particles(str(link_key))


func apply_generator_links(link_entries, clear_existing: bool = true) -> void:
	if clear_existing:
		clear_link_line_visuals()
	if not electrical_visible:
		return
	if not (link_entries is Array):
		return
	for entry in link_entries:
		if not (entry is Dictionary):
			continue
		var generator_grid := Vector2i(int(entry.get("generator_x", entry.get("x", 0))), int(entry.get("generator_y", entry.get("y", 0))))
		var link_kind := normalize_generator_link_kind(str(entry.get("link_type", entry.get("target_type", LINK_MODE_INPUT))))
		if entry.has("pole_x") or entry.has("pole_y"):
			link_kind = LINK_MODE_OUTPUT
		var target_grid := Vector2i(
			int(entry.get("pole_x", entry.get("pad_x", entry.get("target_x", 0)))),
			int(entry.get("pole_y", entry.get("pad_y", entry.get("target_y", 0))))
		)
		draw_generator_link_line(generator_grid, target_grid, link_kind)


func apply_oil_refinery_links(link_entries) -> void:
	if not electrical_visible:
		return
	if not (link_entries is Array):
		return
	for entry in link_entries:
		if not (entry is Dictionary):
			continue
		var refinery_grid := Vector2i(
			int(entry.get("refinery_x", entry.get("oil_refinery_x", entry.get("x", 0)))),
			int(entry.get("refinery_y", entry.get("oil_refinery_y", entry.get("y", 0))))
		)
		var pole_grid := Vector2i(
			int(entry.get("pole_x", entry.get("target_x", 0))),
			int(entry.get("pole_y", entry.get("target_y", 0)))
		)
		draw_oil_refinery_link_line(refinery_grid, pole_grid)


func apply_battery_charger_links(link_entries) -> void:
	if not electrical_visible:
		return
	if not (link_entries is Array):
		return
	for entry in link_entries:
		if not (entry is Dictionary):
			continue
		var charger_grid := Vector2i(
			int(entry.get("charger_x", entry.get("battery_charger_x", entry.get("x", 0)))),
			int(entry.get("charger_y", entry.get("battery_charger_y", entry.get("y", 0))))
		)
		var pole_grid := Vector2i(
			int(entry.get("pole_x", entry.get("target_x", 0))),
			int(entry.get("pole_y", entry.get("target_y", 0)))
		)
		draw_battery_charger_link_line(charger_grid, pole_grid)


func apply_pole_links(link_entries) -> void:
	if not electrical_visible:
		return
	if not (link_entries is Array):
		return
	for entry in link_entries:
		if not (entry is Dictionary):
			continue
		var pole_a_grid := Vector2i(
			int(entry.get("pole_a_x", entry.get("source_x", entry.get("x", 0)))),
			int(entry.get("pole_a_y", entry.get("source_y", entry.get("y", 0))))
		)
		var pole_b_grid := Vector2i(
			int(entry.get("pole_b_x", entry.get("target_x", 0))),
			int(entry.get("pole_b_y", entry.get("target_y", 0)))
		)
		draw_pole_link_line(pole_a_grid, pole_b_grid)


func apply_generator_links_for_generator(generator_grid: Vector2i, linked_pads: Array[Vector2i], linked_poles: Array[Vector2i] = []) -> void:
	var input_prefix := LINK_MODE_INPUT + "|" + make_grid_key(generator_grid) + "|"
	var output_prefix := LINK_MODE_OUTPUT + "|" + make_grid_key(generator_grid) + "|"
	var wanted_keys: Dictionary = {}
	for pad_grid in linked_pads:
		wanted_keys[make_link_key(generator_grid, pad_grid, LINK_MODE_INPUT)] = true
	for pole_grid in linked_poles:
		wanted_keys[make_link_key(generator_grid, pole_grid, LINK_MODE_OUTPUT)] = true
	for link_key in link_lines.keys():
		var clean_key := str(link_key)
		if (clean_key.begins_with(input_prefix) or clean_key.begins_with(output_prefix)) and not wanted_keys.has(clean_key):
			remove_generator_link_line(str(link_key))
	if not electrical_visible:
		return
	for pad_grid in linked_pads:
		draw_generator_link_line(generator_grid, pad_grid, LINK_MODE_INPUT)
	for pole_grid in linked_poles:
		draw_generator_link_line(generator_grid, pole_grid, LINK_MODE_OUTPUT)


func apply_oil_refinery_link_for_refinery(refinery_grid: Vector2i, pole_grid: Vector2i) -> void:
	var input_prefix := LINK_MODE_REFINERY_INPUT + "|" + make_grid_key(refinery_grid) + "|"
	var wanted_key := ""
	if pole_grid.x != 999999:
		wanted_key = make_link_key(refinery_grid, pole_grid, LINK_MODE_REFINERY_INPUT)
	for link_key in link_lines.keys():
		var clean_key := str(link_key)
		if clean_key.begins_with(input_prefix) and clean_key != wanted_key:
			remove_generator_link_line(str(link_key))
	if not electrical_visible:
		return
	if pole_grid.x == 999999:
		return
	draw_oil_refinery_link_line(refinery_grid, pole_grid)


func apply_battery_charger_link_for_charger(charger_grid: Vector2i, pole_grid: Vector2i) -> void:
	var input_prefix := LINK_MODE_CHARGER_INPUT + "|" + make_grid_key(charger_grid) + "|"
	var wanted_key := ""
	if pole_grid.x != 999999:
		wanted_key = make_link_key(charger_grid, pole_grid, LINK_MODE_CHARGER_INPUT)
	for link_key in link_lines.keys():
		var clean_key := str(link_key)
		if clean_key.begins_with(input_prefix) and clean_key != wanted_key:
			remove_generator_link_line(str(link_key))
	if not electrical_visible:
		return
	if pole_grid.x == 999999:
		return
	draw_battery_charger_link_line(charger_grid, pole_grid)


func extract_linked_pad_positions(data: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw_pads = data.get("linked_pads", data.get("pads", []))
	if not (raw_pads is Array):
		return result
	for raw_pad in raw_pads:
		if raw_pad is Dictionary:
			result.append(Vector2i(
				int(raw_pad.get("x", raw_pad.get("pad_x", 0))),
				int(raw_pad.get("y", raw_pad.get("pad_y", 0)))
			))
		elif raw_pad is String:
			var parsed := parse_grid_key(str(raw_pad))
			if parsed.x != 999999:
				result.append(parsed)
		elif raw_pad is Vector2i:
			result.append(raw_pad)
	return result


func extract_linked_pole_positions(data: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw_poles = data.get("linked_poles", data.get("poles", []))
	if not (raw_poles is Array):
		return result
	for raw_pole in raw_poles:
		if raw_pole is Dictionary:
			result.append(Vector2i(
				int(raw_pole.get("x", raw_pole.get("pole_x", 0))),
				int(raw_pole.get("y", raw_pole.get("pole_y", 0)))
			))
		elif raw_pole is String:
			var parsed := parse_grid_key(str(raw_pole))
			if parsed.x != 999999:
				result.append(parsed)
		elif raw_pole is Vector2i:
			result.append(raw_pole)
	return result


func linked_pad_keys_to_positions(linked_pads: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_pad in linked_pads:
		var parsed := parse_grid_key(str(raw_pad))
		if parsed.x != 999999:
			result.append(parsed)
	return result


func begin_electric_tool_link_mode(endpoint: Dictionary) -> bool:
	if not has_electric_tool_equipped():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Equip the Electric Tool to link circuits.")
		return false
	if not is_link_endpoint_valid(endpoint):
		return false

	cancel_generator_link_mode()
	cancel_oil_refinery_link_mode()
	cancel_battery_charger_link_mode()
	electric_tool_link_source_type = get_link_endpoint_type(endpoint)
	electric_tool_link_source_grid = get_link_endpoint_grid(endpoint)
	electric_tool_link_mode_active = true
	electrical_visible = true
	ensure_link_preview_line()
	update_electric_tool_link_preview_line()
	set_process(true)
	if world != null and world.has_method("show_notification"):
		world.show_notification(get_electric_tool_link_target_prompt(electric_tool_link_source_type))
	return true


func cancel_electric_tool_link_mode(show_message: bool = false) -> void:
	var was_active := electric_tool_link_mode_active
	electric_tool_link_mode_active = false
	electric_tool_link_source_type = ""
	electric_tool_link_source_grid = INVALID_LINK_GRID
	remove_link_preview_line()
	if not generator_link_mode_active and not oil_refinery_link_mode_active and not battery_charger_link_mode_active:
		set_process(false)
	if show_message and was_active and world != null and world.has_method("show_notification"):
		world.show_notification("Electrical link cancelled.")


func has_pending_electric_tool_link() -> bool:
	return electric_tool_link_mode_active


func try_electric_tool_link_at(raw_grid: Vector2i) -> bool:
	if not has_electric_tool_equipped():
		return false
	if world == null:
		cancel_electric_tool_link_mode()
		return true

	var endpoint := resolve_electrical_link_endpoint(raw_grid)
	if not is_link_endpoint_valid(endpoint):
		if electric_tool_link_mode_active:
			world.show_notification(get_electric_tool_link_target_prompt(electric_tool_link_source_type))
			update_electric_tool_link_preview_line()
		else:
			world.show_notification("Tap an electrical device to start a link.")
		return true

	var endpoint_grid := get_link_endpoint_grid(endpoint)
	if world.has_method("can_reach_grid") and not bool(world.can_reach_grid(endpoint_grid)):
		world.show_notification("Too far away.")
		return true

	if not electric_tool_link_mode_active:
		return begin_electric_tool_link_mode(endpoint)

	if endpoint_grid == electric_tool_link_source_grid and get_link_endpoint_type(endpoint) == electric_tool_link_source_type:
		cancel_electric_tool_link_mode(true)
		return true

	var source_endpoint := make_link_endpoint(electric_tool_link_source_type, electric_tool_link_source_grid)
	var pair := make_electric_tool_link_pair(source_endpoint, endpoint)
	if pair.is_empty():
		world.show_notification("Those devices cannot be linked.")
		update_electric_tool_link_preview_line()
		return true

	return complete_electric_tool_link(pair)


func complete_electric_tool_link(pair: Dictionary) -> bool:
	var link_kind := normalize_electrical_link_kind(str(pair.get("kind", "")))
	if link_preview_line != null and is_instance_valid(link_preview_line):
		link_preview_line.default_color = LINK_LINE_VALID_COLOR

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager") if world != null and world.has_method("get_node_or_null") else null
		match link_kind:
			LINK_MODE_INPUT:
				var generator_grid := get_link_pair_grid(pair, "generator_grid")
				var pad_grid := get_link_pair_grid(pair, "pad_grid")
				if network != null and network.has_method("send_request_link_generator_pad"):
					if network.send_request_link_generator_pad(generator_grid, pad_grid, world.current_world_name):
						world.show_notification("Linking metal pad...")
						cancel_electric_tool_link_mode()
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true
			LINK_MODE_OUTPUT:
				var generator_grid := get_link_pair_grid(pair, "generator_grid")
				var pole_grid := get_link_pair_grid(pair, "pole_grid")
				if network != null and network.has_method("send_request_link_generator_pole"):
					if network.send_request_link_generator_pole(generator_grid, pole_grid, world.current_world_name):
						world.show_notification("Linking electric pole...")
						cancel_electric_tool_link_mode()
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true
			LINK_MODE_REFINERY_INPUT:
				var refinery_grid := get_link_pair_grid(pair, "refinery_grid")
				var pole_grid := get_link_pair_grid(pair, "pole_grid")
				if network != null and network.has_method("send_oil_refinery_request"):
					if network.send_oil_refinery_request(refinery_grid, "link_pole", {
						"pole_x": pole_grid.x,
						"pole_y": pole_grid.y
					}, world.current_world_name):
						world.show_notification("Linking oil refinery...")
						cancel_electric_tool_link_mode()
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true
			LINK_MODE_CHARGER_INPUT:
				var charger_grid := get_link_pair_grid(pair, "charger_grid")
				var pole_grid := get_link_pair_grid(pair, "pole_grid")
				if network != null and network.has_method("send_battery_charger_request"):
					if network.send_battery_charger_request(charger_grid, "link_pole", {
						"pole_x": pole_grid.x,
						"pole_y": pole_grid.y
					}, world.current_world_name):
						world.show_notification("Linking battery charger...")
						cancel_electric_tool_link_mode()
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true
			LINK_MODE_POLE_COUPLING:
				var pole_a_grid := get_link_pair_grid(pair, "pole_a_grid")
				var pole_b_grid := get_link_pair_grid(pair, "pole_b_grid")
				if network != null and network.has_method("send_request_link_electric_poles"):
					if network.send_request_link_electric_poles(pole_a_grid, pole_b_grid, world.current_world_name):
						world.show_notification("Linking electric poles...")
						link_electric_poles_locally(pole_a_grid, pole_b_grid, false)
						cancel_electric_tool_link_mode()
					else:
						world.show_notification("Almost ready. Try again in a moment.")
					return true
		world.show_notification("Connection required.")
		return true

	match link_kind:
		LINK_MODE_INPUT:
			link_generator_pad_locally(get_link_pair_grid(pair, "generator_grid"), get_link_pair_grid(pair, "pad_grid"))
		LINK_MODE_OUTPUT:
			link_generator_pole_locally(get_link_pair_grid(pair, "generator_grid"), get_link_pair_grid(pair, "pole_grid"))
		LINK_MODE_REFINERY_INPUT:
			link_oil_refinery_pole_locally(get_link_pair_grid(pair, "refinery_grid"), get_link_pair_grid(pair, "pole_grid"))
		LINK_MODE_CHARGER_INPUT:
			link_battery_charger_pole_locally(get_link_pair_grid(pair, "charger_grid"), get_link_pair_grid(pair, "pole_grid"))
		LINK_MODE_POLE_COUPLING:
			link_electric_poles_locally(get_link_pair_grid(pair, "pole_a_grid"), get_link_pair_grid(pair, "pole_b_grid"))
		_:
			world.show_notification("Those devices cannot be linked.")
			return true
	cancel_electric_tool_link_mode()
	return true


func begin_generator_link_mode(generator_grid: Vector2i) -> bool:
	return begin_generator_link_mode_for_kind(generator_grid, LINK_MODE_INPUT)


func begin_generator_output_link_mode(generator_grid: Vector2i) -> bool:
	return begin_generator_link_mode_for_kind(generator_grid, LINK_MODE_OUTPUT)


func begin_generator_link_mode_for_kind(generator_grid: Vector2i, link_kind: String) -> bool:
	var clean_kind := normalize_generator_link_kind(link_kind)
	cancel_electric_tool_link_mode()
	cancel_oil_refinery_link_mode()
	cancel_battery_charger_link_mode()
	if not has_electric_tool_equipped():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Equip the Electric Tool to link circuits.")
		return false
	if not is_visible_generator_at(generator_grid):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Open a transformer before linking circuits.")
		return false

	generator_link_source_grid = generator_grid
	generator_link_mode_kind = clean_kind
	generator_link_mode_active = true
	electrical_visible = true
	if world != null and world.has_method("close_generator_ui"):
		world.close_generator_ui()
	ensure_link_preview_line()
	update_link_preview_line()
	set_process(true)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Tap " + get_generator_link_target_prompt() + " to link it to this transformer.")
	return true


func cancel_generator_link_mode() -> void:
	generator_link_mode_active = false
	generator_link_mode_kind = LINK_MODE_INPUT
	remove_link_preview_line()
	if not oil_refinery_link_mode_active and not battery_charger_link_mode_active and not electric_tool_link_mode_active:
		set_process(false)


func has_pending_generator_link() -> bool:
	return generator_link_mode_active


func begin_oil_refinery_link_mode(refinery_grid: Vector2i) -> bool:
	cancel_electric_tool_link_mode()
	cancel_generator_link_mode()
	cancel_battery_charger_link_mode()
	if not has_electric_tool_equipped():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Equip the Electric Tool to link oil refineries.")
		return false
	if not is_oil_refinery_at(refinery_grid):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Oil refinery missing.")
		return false

	oil_refinery_link_source_grid = refinery_grid
	oil_refinery_link_mode_active = true
	electrical_visible = true
	if world != null and world.has_method("close_oil_refinery_ui"):
		world.close_oil_refinery_ui()
	ensure_link_preview_line()
	update_oil_refinery_link_preview_line()
	set_process(true)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Tap an electric pole to link it to this oil refinery.")
	return true


func cancel_oil_refinery_link_mode() -> void:
	oil_refinery_link_mode_active = false
	remove_link_preview_line()
	if not generator_link_mode_active and not battery_charger_link_mode_active and not electric_tool_link_mode_active:
		set_process(false)


func has_pending_oil_refinery_link() -> bool:
	return oil_refinery_link_mode_active


func begin_battery_charger_link_mode(charger_grid: Vector2i) -> bool:
	cancel_electric_tool_link_mode()
	cancel_generator_link_mode()
	cancel_oil_refinery_link_mode()
	if not has_electric_tool_equipped():
		if world != null and world.has_method("show_notification"):
			world.show_notification("Equip the Electric Tool to link battery chargers.")
		return false
	if not is_battery_charger_at(charger_grid):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Battery charger missing.")
		return false

	battery_charger_link_source_grid = charger_grid
	battery_charger_link_mode_active = true
	electrical_visible = true
	if world != null and world.has_method("close_battery_charger_ui"):
		world.close_battery_charger_ui()
	ensure_link_preview_line()
	update_battery_charger_link_preview_line()
	set_process(true)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Tap an electric pole to link it to this battery charger.")
	return true


func cancel_battery_charger_link_mode() -> void:
	battery_charger_link_mode_active = false
	remove_link_preview_line()
	if not generator_link_mode_active and not oil_refinery_link_mode_active and not electric_tool_link_mode_active:
		set_process(false)


func has_pending_battery_charger_link() -> bool:
	return battery_charger_link_mode_active


func try_link_generator_pad_at(target_grid: Vector2i) -> bool:
	if not generator_link_mode_active:
		return false
	if world == null:
		cancel_generator_link_mode()
		return true
	if not has_electric_tool_equipped():
		world.show_notification("Equip the Electric Tool to link circuits.")
		cancel_generator_link_mode()
		return true
	if not is_visible_generator_at(generator_link_source_grid):
		world.show_notification("Transformer missing.")
		cancel_generator_link_mode()
		return true
	target_grid = resolve_link_target_for_kind(target_grid, generator_link_mode_kind)
	if not world.can_reach_grid(target_grid):
		world.show_notification("Too far away.")
		return true
	if not is_valid_link_target_for_kind(target_grid, generator_link_mode_kind):
		world.show_notification("Tap " + get_generator_link_target_prompt() + " to link.")
		update_link_preview_line()
		return true

	if link_preview_line != null and is_instance_valid(link_preview_line):
		link_preview_line.default_color = LINK_LINE_VALID_COLOR
		set_line_points(link_preview_line, grid_to_world_pos(generator_link_source_grid), grid_to_world_pos(target_grid))

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if generator_link_mode_kind == LINK_MODE_OUTPUT:
			if network != null and network.has_method("send_request_link_generator_pole"):
				if network.send_request_link_generator_pole(generator_link_source_grid, target_grid, world.current_world_name):
					world.show_notification("Linking electric pole...")
					cancel_generator_link_mode()
				else:
					world.show_notification("Almost ready. Try again in a moment.")
				return true
		else:
			if network != null and network.has_method("send_request_link_generator_pad"):
				if network.send_request_link_generator_pad(generator_link_source_grid, target_grid, world.current_world_name):
					world.show_notification("Linking metal pad...")
					cancel_generator_link_mode()
				else:
					world.show_notification("Almost ready. Try again in a moment.")
				return true
		world.show_notification("Connection required.")
		return true

	if generator_link_mode_kind == LINK_MODE_OUTPUT:
		link_generator_pole_locally(generator_link_source_grid, target_grid)
	else:
		link_generator_pad_locally(generator_link_source_grid, target_grid)
	cancel_generator_link_mode()
	return true


func try_link_oil_refinery_pole_at(target_grid: Vector2i) -> bool:
	if not oil_refinery_link_mode_active:
		return false
	if world == null:
		cancel_oil_refinery_link_mode()
		return true
	if not has_electric_tool_equipped():
		world.show_notification("Equip the Electric Tool to link oil refineries.")
		cancel_oil_refinery_link_mode()
		return true
	if not is_oil_refinery_at(oil_refinery_link_source_grid):
		world.show_notification("Oil refinery missing.")
		cancel_oil_refinery_link_mode()
		return true
	target_grid = resolve_electric_pole_grid(target_grid)
	if not world.can_reach_grid(target_grid):
		world.show_notification("Too far away.")
		return true
	if not is_electric_pole_at(target_grid):
		world.show_notification("Tap an electric pole to link.")
		update_oil_refinery_link_preview_line()
		return true

	if link_preview_line != null and is_instance_valid(link_preview_line):
		link_preview_line.default_color = LINK_LINE_VALID_COLOR
		set_line_points(link_preview_line, grid_to_world_pos(oil_refinery_link_source_grid), grid_to_world_pos(target_grid))

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_oil_refinery_request"):
			if network.send_oil_refinery_request(oil_refinery_link_source_grid, "link_pole", {
				"pole_x": target_grid.x,
				"pole_y": target_grid.y
			}, world.current_world_name):
				world.show_notification("Linking electric pole...")
				cancel_oil_refinery_link_mode()
			else:
				world.show_notification("Almost ready. Try again in a moment.")
			return true
		world.show_notification("Connection required.")
		return true

	link_oil_refinery_pole_locally(oil_refinery_link_source_grid, target_grid)
	cancel_oil_refinery_link_mode()
	return true


func try_link_battery_charger_pole_at(target_grid: Vector2i) -> bool:
	if not battery_charger_link_mode_active:
		return false
	if world == null:
		cancel_battery_charger_link_mode()
		return true
	if not has_electric_tool_equipped():
		world.show_notification("Equip the Electric Tool to link battery chargers.")
		cancel_battery_charger_link_mode()
		return true
	if not is_battery_charger_at(battery_charger_link_source_grid):
		world.show_notification("Battery charger missing.")
		cancel_battery_charger_link_mode()
		return true
	target_grid = resolve_electric_pole_grid(target_grid)
	if not world.can_reach_grid(target_grid):
		world.show_notification("Too far away.")
		return true
	if not is_electric_pole_at(target_grid):
		world.show_notification("Tap an electric pole to link.")
		update_battery_charger_link_preview_line()
		return true

	if link_preview_line != null and is_instance_valid(link_preview_line):
		link_preview_line.default_color = LINK_LINE_VALID_COLOR
		set_line_points(link_preview_line, grid_to_world_pos(battery_charger_link_source_grid), grid_to_world_pos(target_grid))

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_battery_charger_request"):
			if network.send_battery_charger_request(battery_charger_link_source_grid, "link_pole", {
				"pole_x": target_grid.x,
				"pole_y": target_grid.y
			}, world.current_world_name):
				world.show_notification("Linking electric pole...")
				cancel_battery_charger_link_mode()
			else:
				world.show_notification("Almost ready. Try again in a moment.")
			return true
		world.show_notification("Connection required.")
		return true

	link_battery_charger_pole_locally(battery_charger_link_source_grid, target_grid)
	cancel_battery_charger_link_mode()
	return true


func link_generator_pad_locally(generator_grid: Vector2i, pad_grid: Vector2i) -> void:
	var generator_key := make_grid_key(generator_grid)
	var pad_key := make_grid_key(pad_grid)
	var linked_pads: Array = local_generator_links.get(generator_key, [])
	if linked_pads.has(pad_key):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Metal pad already linked.")
	elif linked_pads.size() >= MAX_GENERATOR_LINKED_PADS:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Transformer circuits are full.")
	else:
		linked_pads.append(pad_key)
		local_generator_links[generator_key] = linked_pads
		if world != null and world.has_method("show_notification"):
			world.show_notification("Metal pad linked.")

	handle_generator_data_update(make_local_generator_data(generator_grid))


func link_generator_pole_locally(generator_grid: Vector2i, pole_grid: Vector2i) -> void:
	var generator_key := make_grid_key(generator_grid)
	var pole_key := make_grid_key(pole_grid)
	var linked_poles: Array = local_generator_output_links.get(generator_key, [])
	if linked_poles.has(pole_key):
		if world != null and world.has_method("show_notification"):
			world.show_notification("Electric pole already linked.")
	elif linked_poles.size() >= MAX_GENERATOR_LINKED_POLES:
		if world != null and world.has_method("show_notification"):
			world.show_notification("Transformer outputs are full.")
	elif get_local_transformer_link_count_for_pole(pole_grid) >= MAX_TRANSFORMER_LINKS_PER_POLE:
		if world != null and world.has_method("show_notification"):
			world.show_notification("That electric pole has too many transformer links.")
	else:
		linked_poles.append(pole_key)
		local_generator_output_links[generator_key] = linked_poles
		if world != null and world.has_method("show_notification"):
			world.show_notification("Electric pole linked.")

	handle_generator_data_update(make_local_generator_data(generator_grid))


func link_oil_refinery_pole_locally(refinery_grid: Vector2i, pole_grid: Vector2i) -> void:
	var refinery_key := make_grid_key(refinery_grid)
	var pole_key := make_grid_key(pole_grid)
	local_oil_refinery_links[refinery_key] = pole_key
	apply_oil_refinery_link_for_refinery(refinery_grid, pole_grid)
	if world != null and "oil_refinery_states" in world:
		if not (world.oil_refinery_states is Dictionary):
			world.oil_refinery_states = {}
		var state: Dictionary = {}
		if world.oil_refinery_states.has(refinery_grid) and world.oil_refinery_states[refinery_grid] is Dictionary:
			state = world.oil_refinery_states[refinery_grid].duplicate(true)
		state["linked_pole"] = true
		state["linked_pole_x"] = pole_grid.x
		state["linked_pole_y"] = pole_grid.y
		world.oil_refinery_states[refinery_grid] = state
		if world.has_method("refresh_oil_refinery_visual"):
			world.refresh_oil_refinery_visual(refinery_grid)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Electric pole linked.")


func link_battery_charger_pole_locally(charger_grid: Vector2i, pole_grid: Vector2i) -> void:
	var charger_key := make_grid_key(charger_grid)
	var pole_key := make_grid_key(pole_grid)
	local_battery_charger_links[charger_key] = pole_key
	apply_battery_charger_link_for_charger(charger_grid, pole_grid)
	if world != null and "battery_charger_states" in world:
		if not (world.battery_charger_states is Dictionary):
			world.battery_charger_states = {}
		var state: Dictionary = {}
		if world.battery_charger_states.has(charger_grid) and world.battery_charger_states[charger_grid] is Dictionary:
			state = world.battery_charger_states[charger_grid].duplicate(true)
		state["linked_pole"] = true
		state["linked_pole_x"] = pole_grid.x
		state["linked_pole_y"] = pole_grid.y
		world.battery_charger_states[charger_grid] = state
		if world.has_method("refresh_battery_charger_visual"):
			world.refresh_battery_charger_visual(charger_grid)
	if world != null and world.has_method("show_notification"):
		world.show_notification("Electric pole linked.")


func link_electric_poles_locally(pole_a_grid: Vector2i, pole_b_grid: Vector2i, show_message: bool = true) -> void:
	if pole_a_grid == pole_b_grid:
		if show_message and world != null and world.has_method("show_notification"):
			world.show_notification("Pick another electric pole.")
		return
	if not is_electric_pole_at(pole_a_grid) or not is_electric_pole_at(pole_b_grid):
		if show_message and world != null and world.has_method("show_notification"):
			world.show_notification("Tap another electric pole to link.")
		return
	var link_key := make_pole_link_key(pole_a_grid, pole_b_grid)
	if local_pole_links.has(link_key):
		if show_message and world != null and world.has_method("show_notification"):
			world.show_notification("Electric poles already linked.")
		return
	if get_local_pole_link_count(pole_a_grid) >= MAX_POLE_LINKS_PER_POLE or get_local_pole_link_count(pole_b_grid) >= MAX_POLE_LINKS_PER_POLE:
		if show_message and world != null and world.has_method("show_notification"):
			world.show_notification("That electric pole has too many couplings.")
		return
	local_pole_links[link_key] = {
		"pole_a": pole_a_grid,
		"pole_b": pole_b_grid
	}
	draw_pole_link_line(pole_a_grid, pole_b_grid)
	if show_message and world != null and world.has_method("show_notification"):
		world.show_notification("Electric poles linked.")


func get_local_pole_link_count(pole_grid: Vector2i) -> int:
	var count := 0
	for link_data in local_pole_links.values():
		if not (link_data is Dictionary):
			continue
		var pole_a: Variant = link_data.get("pole_a", INVALID_LINK_GRID)
		var pole_b: Variant = link_data.get("pole_b", INVALID_LINK_GRID)
		if (pole_a is Vector2i and pole_a == pole_grid) or (pole_b is Vector2i and pole_b == pole_grid):
			count += 1
	return count


func get_local_transformer_link_count_for_pole(pole_grid: Vector2i) -> int:
	var pole_key := make_grid_key(pole_grid)
	var count := 0
	for linked_poles_value in local_generator_output_links.values():
		if not (linked_poles_value is Array):
			continue
		if (linked_poles_value as Array).has(pole_key):
			count += 1
	return count


func make_local_generator_data(generator_grid: Vector2i) -> Dictionary:
	var generator_key := make_grid_key(generator_grid)
	var linked_pads: Array = local_generator_links.get(generator_key, [])
	var linked_poles: Array = local_generator_output_links.get(generator_key, [])
	return {
		"x": generator_grid.x,
		"y": generator_grid.y,
		"item_id": GENERATOR,
		"block_type": GENERATOR,
		"device_type": DEVICE_GENERATOR,
		"network_status": "idle",
		"linked_pad_count": clampi(linked_pads.size(), 0, MAX_GENERATOR_LINKED_PADS),
		"linked_pad_capacity": MAX_GENERATOR_LINKED_PADS,
		"linked_pads": linked_pad_keys_to_positions(linked_pads),
		"linked_pole_count": clampi(linked_poles.size(), 0, MAX_GENERATOR_LINKED_POLES),
		"linked_pole_capacity": MAX_GENERATOR_LINKED_POLES,
		"linked_poles": linked_pad_keys_to_positions(linked_poles),
		"watts": 0,
		"max_watts": MAX_GENERATOR_WATTS
	}


func get_device_type_for_item(item_id: String, fallback: String = "") -> String:
	var clean_fallback := str(fallback).strip_edges().to_lower()
	if clean_fallback != "":
		return clean_fallback
	match str(item_id):
		ELECTRIC_WIRE:
			return DEVICE_WIRE
		METAL_PAD:
			return DEVICE_METAL_PAD
		GENERATOR, TRANSFORMER:
			return DEVICE_GENERATOR
		ELECTRIC_POLE:
			return DEVICE_ELECTRIC_POLE
	return ""


func can_replace_existing_tile(existing_tile: Dictionary, next_item_id: String) -> bool:
	if existing_tile.is_empty():
		return true
	var existing_device := str(existing_tile.get("device_type", "")).strip_edges().to_lower()
	if existing_device != DEVICE_WIRE:
		return false
	return next_item_id != ELECTRIC_WIRE


func make_grid_pos(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))


func normalize_tile_data(data: Dictionary) -> Dictionary:
	var item_id := str(data.get("item_id", data.get("item_type", data.get("block_type", data.get("type", ""))))).strip_edges()
	if item_id == "":
		return {}

	var grid_pos := make_grid_pos(data)
	var max_watts := clampi(int(data.get("max_watts", MAX_GENERATOR_WATTS)), 1, MAX_GENERATOR_WATTS)
	var result := {
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": item_id,
		"block_type": item_id,
		"device_type": get_device_type_for_item(item_id, str(data.get("device_type", ""))),
		"signal_mode": str(data.get("signal_mode", "")),
		"network_id": str(data.get("network_id", "")),
		"network_status": str(data.get("network_status", "")),
		"network_invalid_reason": str(data.get("network_invalid_reason", "")),
		"generator_x": int(data.get("generator_x", grid_pos.x)),
		"generator_y": int(data.get("generator_y", grid_pos.y)),
		"pad_count": int(data.get("pad_count", 0)),
		"wire_count": int(data.get("wire_count", 0)),
		"watts": clampi(int(data.get("watts", 0)), 0, max_watts),
		"max_watts": max_watts
	}
	return result


func clear_all() -> void:
	last_visibility_snapshot_key = ""
	for node in tile_sprites.values():
		if node != null and is_instance_valid(node):
			node.queue_free()
	tile_sprites.clear()
	electrical_tiles.clear()
	clear_link_line_visuals()
	remove_link_preview_line()
	generator_link_mode_active = false
	oil_refinery_link_mode_active = false
	battery_charger_link_mode_active = false
	electric_tool_link_mode_active = false
	electric_tool_link_source_type = ""
	electric_tool_link_source_grid = INVALID_LINK_GRID
	set_process(false)


func make_visibility_snapshot_key(entries, visible_state: bool, generator_links, oil_refinery_links, battery_charger_links = [], pole_links = []) -> String:
	return JSON.stringify({
		"visible": visible_state,
		"electrical_layer": entries if entries is Array else [],
		"generator_links": generator_links if generator_links is Array else [],
		"oil_refinery_links": oil_refinery_links if oil_refinery_links is Array else [],
		"battery_charger_links": battery_charger_links if battery_charger_links is Array else [],
		"pole_links": pole_links if pole_links is Array else []
	})


func apply_snapshot(entries, visible_state: bool = true, generator_links = [], oil_refinery_links = [], battery_charger_links = [], pole_links = []) -> void:
	var snapshot_key := make_visibility_snapshot_key(entries, visible_state, generator_links, oil_refinery_links, battery_charger_links, pole_links)
	if snapshot_key == last_visibility_snapshot_key:
		electrical_visible = visible_state
		return
	clear_all()
	last_visibility_snapshot_key = snapshot_key
	electrical_visible = visible_state
	if not visible_state:
		return
	if not (entries is Array):
		entries = []
	for entry in entries:
		if entry is Dictionary:
			var tile := normalize_tile_data(entry)
			if not tile.is_empty():
				electrical_tiles[make_grid_pos(tile)] = tile
	refresh_all_visuals()
	apply_generator_links(generator_links, false)
	apply_oil_refinery_links(oil_refinery_links)
	apply_battery_charger_links(battery_charger_links)
	apply_pole_links(pole_links)


func apply_visibility_payload(data: Dictionary) -> void:
	var visible_state := bool(data.get("visible", data.get("electrical_layer_visible", false)))
	apply_snapshot(data.get("electrical_layer", []), visible_state, data.get("generator_links", []), data.get("oil_refinery_links", []), data.get("battery_charger_links", []), data.get("pole_links", []))


func apply_electrical_layer_update(data: Dictionary) -> void:
	if data.has("visible") or data.has("electrical_layer_visible"):
		if not bool(data.get("visible", data.get("electrical_layer_visible", true))):
			apply_snapshot([], false)
			return

	var action := str(data.get("action", "")).strip_edges().to_lower()
	var grid_pos := make_grid_pos(data)
	if action == "break" or action == "remove":
		last_visibility_snapshot_key = ""
		if electrical_tiles.has(grid_pos) and str(electrical_tiles[grid_pos].get("device_type", "")) == DEVICE_GENERATOR:
			if world != null and "generator_ui" in world and world.generator_ui != null and world.generator_ui.has_method("close_generator"):
				if not ("current_grid" in world.generator_ui) or world.generator_ui.current_grid == grid_pos:
					world.generator_ui.close_generator()
		remove_tile_visual(grid_pos)
		electrical_tiles.erase(grid_pos)
		return

	if action != "place":
		return

	last_visibility_snapshot_key = ""
	var raw_tile = data.get("tile", data)
	if not (raw_tile is Dictionary):
		raw_tile = data
	var tile := normalize_tile_data(raw_tile)
	if tile.is_empty():
		tile = normalize_tile_data(data)
	if tile.is_empty():
		return
	grid_pos = make_grid_pos(tile)
	electrical_tiles[grid_pos] = tile
	refresh_tile_visual(grid_pos)


func refresh_all_visuals() -> void:
	for grid_pos in electrical_tiles.keys():
		refresh_tile_visual(grid_pos)
	for grid_pos in tile_sprites.keys():
		if not electrical_tiles.has(grid_pos):
			remove_tile_visual(grid_pos)


func remove_tile_visual(grid_pos: Vector2i) -> void:
	if not tile_sprites.has(grid_pos):
		return
	var node = tile_sprites[grid_pos]
	tile_sprites.erase(grid_pos)
	if node != null and is_instance_valid(node):
		node.queue_free()


func refresh_tile_visual(grid_pos: Vector2i) -> void:
	if not electrical_visible:
		remove_tile_visual(grid_pos)
		return
	if not electrical_tiles.has(grid_pos):
		remove_tile_visual(grid_pos)
		return

	var tile: Dictionary = electrical_tiles[grid_pos]
	var item_id := str(tile.get("item_id", ""))
	var texture: Texture2D = texture_cache.get(item_id, null)
	if texture == null:
		return

	var sprite: Sprite2D = null
	if tile_sprites.has(grid_pos):
		var existing = tile_sprites[grid_pos]
		if existing is Sprite2D and is_instance_valid(existing):
			sprite = existing
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = true
		sprite.z_as_relative = true
		add_child(sprite)
		tile_sprites[grid_pos] = sprite

	sprite.texture = texture
	sprite.position = grid_to_world_pos(grid_pos)
	sprite.modulate = get_tile_modulate(tile)
	sprite.scale = get_tile_scale(texture)


func get_tile_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var target_size := 32.0
	if world != null and "BLOCK_SIZE" in world:
		target_size = float(world.BLOCK_SIZE)
	var max_size := float(max(texture.get_width(), texture.get_height()))
	if max_size <= 0.0:
		return Vector2.ONE
	var scale_value = min(1.0, target_size / max_size)
	return Vector2(scale_value, scale_value)


func get_tile_modulate(tile: Dictionary) -> Color:
	var status := str(tile.get("network_status", "")).strip_edges().to_lower()
	if status == "invalid" or status == "overloaded":
		return Color(1.0, 0.35, 0.28, 0.82)
	if status == "valid":
		return Color(1.0, 0.95, 0.45, 0.9)
	if str(tile.get("device_type", "")) == DEVICE_GENERATOR:
		return Color(0.82, 0.95, 1.0, 0.9)
	return Color(0.62, 0.86, 1.0, 0.78)


func try_place_selected_electrical_at(grid_pos: Vector2i) -> bool:
	if world == null:
		return false
	var item_id := str(world.selected_item_type)
	if not is_electrical_item(item_id):
		return false
	if not has_electric_tool_equipped():
		world.show_notification("Equip the Electric Tool to link wiring.")
		return true
	if electrical_tiles.has(grid_pos) and not can_replace_existing_tile(electrical_tiles[grid_pos], item_id):
		world.show_notification("That electrical spot is occupied.")
		return true
	if world.inventory.has(item_id) and int(world.inventory[item_id]) <= 0:
		world.show_notification("You don't have any " + world.get_item_display_name(item_id, "block") + ".")
		return true

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_electrical_layer_update"):
			if network.send_electrical_layer_update("place", grid_pos, item_id, world.current_world_name):
				world.show_notification("Placing " + world.get_item_display_name(item_id, "block") + "...")
			else:
				world.show_notification("Almost ready. Try again in a moment.")
			return true
		world.show_notification("Connection required.")
		return true

	var tile := normalize_tile_data({
		"x": grid_pos.x,
		"y": grid_pos.y,
		"item_id": item_id,
		"device_type": get_device_type_for_item(item_id)
	})
	electrical_visible = true
	electrical_tiles[grid_pos] = tile
	refresh_tile_visual(grid_pos)
	if world.inventory.has(item_id):
		world.inventory[item_id] = max(0, int(world.inventory[item_id]) - 1)
	if world.has_method("refresh_ui_after_item_change"):
		world.refresh_ui_after_item_change(item_id, "block")
	return true


func try_break_electrical_at(grid_pos: Vector2i) -> bool:
	if not electrical_visible:
		return false
	if not electrical_tiles.has(grid_pos):
		return false
	if not has_electric_tool_equipped():
		world.show_notification("Equip the Electric Tool to remove wiring.")
		return true

	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_electrical_layer_update"):
			if network.send_electrical_layer_update("break", grid_pos, str(electrical_tiles[grid_pos].get("item_id", "")), world.current_world_name):
				world.show_notification("Removing wiring...")
			else:
				world.show_notification("Almost ready. Try again in a moment.")
			return true
		world.show_notification("Connection required.")
		return true

	remove_tile_visual(grid_pos)
	electrical_tiles.erase(grid_pos)
	return true


func should_use_server_authoritative_actions() -> bool:
	return world != null and world.has_method("should_use_server_authoritative_world_actions") and bool(world.should_use_server_authoritative_world_actions())


func has_visible_electrical_tile_at(grid_pos: Vector2i) -> bool:
	return electrical_visible and electrical_tiles.has(grid_pos)


func is_visible_generator_at(grid_pos: Vector2i) -> bool:
	if world != null and "blocks" in world and world.blocks.has(grid_pos):
		return is_transformer_item_id(str(world.blocks[grid_pos].get("type", "")))
	if not has_visible_electrical_tile_at(grid_pos):
		return false
	return str(electrical_tiles[grid_pos].get("device_type", "")) == DEVICE_GENERATOR


func request_open_generator(grid_pos: Vector2i) -> bool:
	if not is_visible_generator_at(grid_pos):
		return false
	if should_use_server_authoritative_actions():
		var network = world.get_node_or_null("/root/NetworkManager")
		if network != null and network.has_method("send_request_open_generator"):
			return bool(network.send_request_open_generator(grid_pos, world.current_world_name))
		return false
	var local_data: Dictionary = electrical_tiles[grid_pos].duplicate(true) if electrical_tiles.has(grid_pos) else make_local_generator_data(grid_pos)
	local_data["opened"] = true
	handle_generator_data_update(local_data)
	return true


func handle_generator_data_update(data: Dictionary) -> void:
	var grid_pos := make_grid_pos(data)
	update_foreground_generator_power_visual(grid_pos, data)
	if electrical_tiles.has(grid_pos):
		for key in data.keys():
			electrical_tiles[grid_pos][key] = data[key]
		refresh_tile_visual(grid_pos)
	if data.has("linked_pads") or data.has("linked_poles"):
		if has_electric_tool_equipped():
			electrical_visible = true
		apply_generator_links_for_generator(grid_pos, extract_linked_pad_positions(data), extract_linked_pole_positions(data))
	if world != null and "generator_ui" in world and world.generator_ui != null:
		if bool(data.get("opened", false)) and world.generator_ui.has_method("open_generator"):
			world.generator_ui.open_generator(data)
		elif bool(world.generator_ui.visible) and world.generator_ui.has_method("update_generator"):
			world.generator_ui.update_generator(data)


func handle_generator_generation_pulse(data: Dictionary) -> void:
	var grid_pos := make_grid_pos(data)
	update_foreground_generator_power_visual(grid_pos, data)
	if electrical_tiles.has(grid_pos):
		electrical_tiles[grid_pos]["watts"] = int(data.get("watts", electrical_tiles[grid_pos].get("watts", 0)))
		electrical_tiles[grid_pos]["max_watts"] = int(data.get("max_watts", electrical_tiles[grid_pos].get("max_watts", MAX_GENERATOR_WATTS)))
		refresh_tile_visual(grid_pos)
	if tile_sprites.has(grid_pos):
		var sprite = tile_sprites[grid_pos]
		if sprite is Sprite2D and is_instance_valid(sprite):
			var tween := create_tween()
			tween.tween_property(sprite, "scale", sprite.scale * 1.18, 0.08)
			tween.tween_property(sprite, "scale", get_tile_scale(sprite.texture), 0.18)
	if world != null and "generator_ui" in world and world.generator_ui != null and world.generator_ui.has_method("show_generation_pulse"):
		world.generator_ui.show_generation_pulse(data)


func update_foreground_generator_power_visual(grid_pos: Vector2i, data: Dictionary) -> void:
	if world == null or world.block_manager == null:
		return
	if not world.block_manager.has_method("set_transformer_input_power"):
		return
	var watts := int(data.get("watts", 0))
	var max_watts := int(data.get("max_watts", MAX_GENERATOR_WATTS))
	world.block_manager.set_transformer_input_power(grid_pos, watts, max_watts)


func get_save_data() -> Array:
	var entries: Array = []
	for grid_pos in electrical_tiles.keys():
		var tile: Dictionary = electrical_tiles[grid_pos]
		var entry := tile.duplicate(true)
		entry["x"] = grid_pos.x
		entry["y"] = grid_pos.y
		entries.append(entry)
	return entries


func load_save_data(entries) -> void:
	apply_snapshot(entries, true)
