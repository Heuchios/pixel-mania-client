extends Node2D
## Cached illustrative supply routes, not per-wire current measurements.
## One draw layer, bounded visible marks, and no world/block picking.
const MAX_VISIBLE_WIRES := 64
const MAX_TOPOLOGY_EDGES_PER_STEP := 128
const ANIMATION_HZ := 30.0
const STATE_INTERVAL := 0.4
const VIEW_INTERVAL := 0.2
const SPEED := 48.0
var manager = null
var inspector = null
var scope := ""
var generator_energy: Dictionary = {}
var generation_until: Dictionary = {}
var edges: Dictionary = {}
var pole_neighbors: Dictionary = {}
var outputs: Array[String] = []
var consumers: Array[String] = []
var directions: Dictionary = {}
var visible_edges: Array[Dictionary] = []
var topology_signature: Array = []
var activity_signature: Array = []
var view_signature: Array = []
var state_elapsed := STATE_INTERVAL
var view_elapsed := VIEW_INTERVAL
var frame_elapsed := 0.0
var route_revision := 0
var topology_build_count := 0
var route_build_count := 0
var animated := false
var marks := PackedVector2Array()
var faint_marks := PackedVector2Array()
var topology_keys: Array = []
var topology_cursor := 0
var topology_building := false

func setup(owner_manager, owner_inspector) -> void:
	manager = owner_manager
	inspector = owner_inspector
	z_index = 1

func ensure_scope() -> void:
	var current: String = str(manager.world.current_world_name)
	if scope == current: return
	scope = current
	generator_energy.clear()
	generation_until.clear()
	edges.clear()
	directions.clear()
	outputs.clear()
	consumers.clear()
	pole_neighbors.clear()
	animated = false
	visible_edges.clear()
	topology_signature.clear()
	activity_signature.clear()
	view_signature.clear()
	marks.clear()
	faint_marks.clear()
	topology_keys.clear()
	topology_building = false
	queue_redraw()

func update_generator(data: Dictionary) -> void:
	ensure_scope()
	if data.has("watts"):
		generator_energy[Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))] = maxi(0, int(data.watts))
	state_elapsed = STATE_INTERVAL

func generation(data: Dictionary) -> void:
	update_generator(data)
	if int(data.get("generated_watts", 0)) <= 0: return
	var source := Vector2i(int(data.get("source_x", 0)), int(data.get("source_y", 0)))
	var target := Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	generation_until[manager.make_link_key(target, source, "input")] = Time.get_ticks_msec() + 1600

func _process(delta: float) -> void:
	if manager == null or manager.world == null: return
	ensure_scope()
	if not manager.electrical_visible:
		if visible:
			hide()
			view_signature.clear()
		return
	show()
	state_elapsed += delta
	view_elapsed += delta
	frame_elapsed += delta
	if not topology_is_current() or topology_building or state_elapsed >= STATE_INTERVAL:
		state_elapsed = 0.0
		refresh_routes()
	if view_elapsed >= VIEW_INTERVAL:
		view_elapsed = 0.0
		refresh_visible()
	if animated and frame_elapsed >= 1.0 / ANIMATION_HZ:
		frame_elapsed = fmod(frame_elapsed, 1.0 / ANIMATION_HZ)
		build_marks(float(Time.get_ticks_msec()) / 1000.0)
		queue_redraw()

func refresh_routes() -> void:
	var signature: Array = [manager.link_revision, manager.link_lines.size()]
	if signature != topology_signature:
		topology_signature = signature
		rebuild_topology()
	if topology_building and not step_topology(): return
	var now := Time.get_ticks_msec()
	for key in generation_until.keys():
		if int(generation_until[key]) <= now: generation_until.erase(key)
	var state_key: Array = [topology_signature.duplicate(), generation_until.keys()]
	var live_consumers: Array[String] = []
	var available_generators: Dictionary = {}
	for key in outputs:
		var grid: Vector2i = edges[key].source_grid
		var charged := int(generator_energy.get(grid, 0)) > 0
		state_key.append(charged)
		if charged: available_generators[grid] = true
	for key in consumers:
		var edge: Dictionary = edges[key]
		var state: Dictionary = consumer_state(edge)
		var active := bool(state.get("running", false))
		if edge.kind == "refinery_input":
			active = active and str(state.get("power_source", "none")) in ["transformer", "hybrid"]
		state_key.append(active)
		# A refinery's server payload can identify its supply before the separate
		# generator snapshot arrives. Never infer supply merely from connectivity.
		var fallback := Vector2i(int(state.get("transformer_x", 999999)), int(state.get("transformer_y", 999999)))
		state_key.append(fallback)
		state_key.append(int(state.get("transformer_watts", 0)) > 0)
		if active:
			live_consumers.append(key)
			if not generator_energy.has(fallback) and int(state.get("transformer_watts", 0)) > 0:
				available_generators[fallback] = true
	if state_key == activity_signature: return
	activity_signature = state_key
	route_build_count += 1
	directions.clear()
	for key in generation_until:
		if edges.has(key): directions[key] = -1
	# Search outward from running consumers, then trace EVERY charged output
	# back toward demand. Seeding from generators instead hides distant feeds
	# when a nearer transformer wins the consumer's shortest route.
	# These are supply availability paths, not measured per-wire current.
	var parents: Dictionary = {}
	var queue: Array[Vector2i] = []
	for key in live_consumers:
		var edge: Dictionary = edges[key]
		directions[key] = -1
		if parents.has(edge.target_grid): continue
		parents[edge.target_grid] = {"root": true}
		queue.append(edge.target_grid)
	var cursor := 0
	while cursor < queue.size():
		var pole := queue[cursor]
		cursor += 1
		for neighbor in pole_neighbors.get(pole, []):
			if parents.has(neighbor.grid): continue
			parents[neighbor.grid] = {"key": neighbor.key, "direction": -neighbor.direction, "root": false, "previous": pole}
			queue.append(neighbor.grid)
	var traced: Dictionary = {}
	for key in outputs:
		if not available_generators.has(edges[key].source_grid): continue
		var pole: Vector2i = edges[key].target_grid
		if not parents.has(pole): continue
		directions[key] = 1
		while parents.has(pole) and not traced.has(pole):
			traced[pole] = true
			var parent: Dictionary = parents[pole]
			if parent.root: break
			directions[parent.key] = parent.direction
			pole = parent.previous
	route_revision += 1
	view_elapsed = VIEW_INTERVAL

func consumer_state(edge: Dictionary) -> Dictionary:
	if edge.kind == "refinery_input":
		return manager.world.oil_refinery_states.get(edge.source_grid, {})
	return manager.world.battery_charger_states.get(edge.source_grid, {})

func rebuild_topology() -> void:
	topology_build_count += 1
	edges.clear()
	outputs.clear()
	consumers.clear()
	pole_neighbors.clear()
	topology_keys = manager.link_lines.keys()
	topology_cursor = 0
	topology_building = true
	# Clear old markers while a changed network is rebuilt over several frames.
	clear_flow_marks()

func clear_flow_marks() -> void:
	visible_edges.clear()
	animated = false
	marks.clear()
	faint_marks.clear()
	view_signature.clear()
	queue_redraw()

func topology_is_current() -> bool:
	return topology_signature == [manager.link_revision, manager.link_lines.size()]

func get_live_line(key: String, expected_id: int = 0) -> Line2D:
	# A freed Object can be held in a Variant, but assigning it to a typed
	# Line2D fails before a subsequent validity check can run. Validate first.
	var candidate: Variant = manager.link_lines.get(key)
	if not is_instance_valid(candidate) or not (candidate is Line2D): return null
	if candidate.is_queued_for_deletion(): return null
	if expected_id != 0 and candidate.get_instance_id() != expected_id: return null
	return candidate

func step_topology() -> bool:
	var stop := mini(topology_keys.size(), topology_cursor + MAX_TOPOLOGY_EDGES_PER_STEP)
	while topology_cursor < stop:
		var key = topology_keys[topology_cursor]
		topology_cursor += 1
		if not manager.link_lines.has(key): continue
		var parts: PackedStringArray = str(key).split("|")
		var line := get_live_line(str(key))
		if parts.size() != 3 or line == null or line.get_point_count() < 2: continue
		var a: Vector2i = manager.parse_grid_key(parts[1])
		var b: Vector2i = manager.parse_grid_key(parts[2])
		var start := line.get_point_position(0)
		var end := line.get_point_position(1)
		# Cache values and identity, never a Node reference across network updates.
		edges[key] = {"key": key, "kind": parts[0], "source_grid": a, "target_grid": b, "start": start, "end": end, "line_id": line.get_instance_id()}
		match parts[0]:
			"output": outputs.append(key)
			"refinery_input", "battery_charger_input": consumers.append(key)
			"pole_coupling":
				if not pole_neighbors.has(a): pole_neighbors[a] = []
				if not pole_neighbors.has(b): pole_neighbors[b] = []
				pole_neighbors[a].append({"grid": b, "key": key, "direction": 1})
				pole_neighbors[b].append({"grid": a, "key": key, "direction": -1})
	topology_building = topology_cursor < topology_keys.size()
	return not topology_building

func refresh_visible() -> void:
	if not topology_is_current():
		clear_flow_marks()
		state_elapsed = STATE_INTERVAL
		return
	if topology_building: return
	var canvas_transform := get_global_transform_with_canvas()
	var signature: Array = [route_revision, canvas_transform, get_viewport_rect(), inspector.inspection_signature.duplicate()]
	if signature == view_signature: return
	view_signature = signature
	visible_edges.clear()
	animated = false
	# Three small priority buckets avoid sorting; selected and active wires get
	# the budget before idle hints. Offscreen and dimmed circuits get no marks.
	var active_edges: Array[Dictionary] = []
	var idle_edges: Array[Dictionary] = []
	for key in edges:
		var edge: Dictionary = edges[key]
		var line := get_live_line(str(key), int(edge.line_id))
		if line == null or line.modulate.a < 0.5: continue
		var screen_a: Vector2 = canvas_transform * edge.start
		var screen_b: Vector2 = canvas_transform * edge.end
		if not Rect2(screen_a, screen_b - screen_a).abs().grow(8).intersects(get_viewport_rect()): continue
		var sign_value := int(directions.get(key, 0))
		if sign_value == 0 and edge.kind == "pole_coupling": continue
		if sign_value == 0: sign_value = -1 if edge.kind in ["input", "refinery_input", "battery_charger_input"] else 1
		var from: Vector2 = edge.start if sign_value > 0 else edge.end
		var to: Vector2 = edge.end if sign_value > 0 else edge.start
		var length := from.distance_to(to)
		if length < 10: continue	
		var mark := {"start": from, "end": to, "direction": (to-from)/length, "length": length, "active": directions.has(key)}
		if key == inspector.selected_wire: visible_edges.append(mark)
		elif mark.active and active_edges.size() < MAX_VISIBLE_WIRES: active_edges.append(mark)
		elif not mark.active and idle_edges.size() < MAX_VISIBLE_WIRES: idle_edges.append(mark)
	for bucket in [active_edges, idle_edges]:
		for mark in bucket:
			if visible_edges.size() >= MAX_VISIBLE_WIRES: break
			visible_edges.append(mark)
	for mark in visible_edges:
		if mark.active: animated = true
	build_marks(float(Time.get_ticks_msec()) / 1000.0)
	queue_redraw()

func build_marks(seconds: float) -> void:
	marks.clear()
	faint_marks.clear()
	for edge in visible_edges:
		var direction: Vector2 = edge.direction
		var side := Vector2(-direction.y, direction.x)
		var count := 2 if edge.active and edge.length > 70 else 1
		for index in range(count):
			var fraction := fmod(seconds * SPEED / edge.length + float(index) / count, 1.0) if edge.active else 0.55
			var tip: Vector2 = edge.start.lerp(edge.end, 0.08 + fraction * 0.84)
			if edge.active:
				marks.append(tip - direction * 5 + side * 3)
				marks.append(tip)
				marks.append(tip)
				marks.append(tip - direction * 5 - side * 3)
			else:
				faint_marks.append(tip - direction * 5 + side * 3)
				faint_marks.append(tip)
				faint_marks.append(tip)
				faint_marks.append(tip - direction * 5 - side * 3)

func _draw() -> void:
	if not faint_marks.is_empty(): draw_multiline(faint_marks, Color(1.0, 0.85, 0.25, 0.35), 1.0)
	if not marks.is_empty(): draw_multiline(marks, Color(1.0, 0.98, 0.7, 0.95), 1.5)
