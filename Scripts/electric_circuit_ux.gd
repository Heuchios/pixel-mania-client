extends Node2D
## Circuit inspection and editing; link mutations remain server authoritative.
var manager = null
var focus_grid := Vector2i(999999, 999999)
var focus_type := ""
var selected_wire := ""
var multi_connect := false
var inspect_mode := false
var pending: Dictionary = {}
var undo_action: Dictionary = {}
var focused_nodes: Dictionary = {}
var elapsed := 0.0
var generation_pulses: Dictionary = {}
var generation_notes: Array[Dictionary] = []
var pad_hint_shown := false
var previous_world := ""
var inspection_signature: Array = []
var graph_signature: Array = []
var adjacency: Dictionary = {}
var graph_rebuild_count := 0
var last_draw_signature: Array = []
var flow_overlay = null

func setup(owner_manager) -> void:
	manager = owner_manager
	z_index = 5
	flow_overlay = preload("res://Scripts/electric_flow_overlay.gd").new()
	add_child(flow_overlay)
	flow_overlay.setup(manager, self)

func set_mode(inspect: bool) -> void:
	finish()
	inspect_mode = inspect
	refresh_inspection()

func finish() -> void:
	manager.cancel_electric_tool_link_mode()
	manager.cancel_generator_link_mode()
	manager.cancel_oil_refinery_link_mode()
	manager.cancel_battery_charger_link_mode()
	focus_grid = manager.INVALID_LINK_GRID
	focus_type = ""
	selected_wire = ""
	inspect_mode = false
	multi_connect = false

func select_device(grid: Vector2i, device_type: String) -> void:
	focus_grid = grid
	focus_type = device_type
	selected_wire = ""
	if device_type == manager.LINK_ENDPOINT_METAL_PAD and not pad_hint_shown:
		pad_hint_shown = true
		manager.world.show_notification("Place a block over this pad, then break it to charge its transformer.")

func pair_key(pair: Dictionary) -> String:
	match str(pair.get("kind", "")):
		"input": return manager.make_link_key(pair.generator_grid, pair.pad_grid, "input")
		"output": return manager.make_link_key(pair.generator_grid, pair.pole_grid, "output")
		"refinery_input": return manager.make_link_key(pair.refinery_grid, pair.pole_grid, "refinery_input")
		"battery_charger_input": return manager.make_link_key(pair.charger_grid, pair.pole_grid, "battery_charger_input")
		"pole_coupling": return manager.make_pole_link_key(pair.pole_a_grid, pair.pole_b_grid)
	return ""

func key_pair(key: String) -> Dictionary:
	var parts := key.split("|")
	if parts.size() != 3: return {}
	var a: Vector2i = manager.parse_grid_key(parts[1])
	var b: Vector2i = manager.parse_grid_key(parts[2])
	match parts[0]:
		"input": return {"kind": parts[0], "generator_grid": a, "pad_grid": b}
		"output": return {"kind": parts[0], "generator_grid": a, "pole_grid": b}
		"refinery_input": return {"kind": parts[0], "refinery_grid": a, "pole_grid": b}
		"battery_charger_input": return {"kind": parts[0], "charger_grid": a, "pole_grid": b}
		"pole_coupling": return {"kind": parts[0], "pole_a_grid": a, "pole_b_grid": b}
	return {}

func select_existing(pair: Dictionary) -> bool:
	var key := pair_key(pair)
	if not manager.link_lines.has(key):
		# Each consumer accepts one incoming wire; cut it before reconnecting.
		var parts := key.split("|")
		if parts.size() == 3 and parts[0] in ["refinery_input", "battery_charger_input"]:
			for existing in manager.link_lines:
				if str(existing).begins_with(parts[0] + "|" + parts[1] + "|"):
					selected_wire = existing
					manager.cancel_electric_tool_link_mode()
					manager.world.show_notification("This machine already has a power wire. Use the Wire Cutter to remove it first.")
					return true
		return false
	selected_wire = key
	manager.cancel_electric_tool_link_mode()
	return true

func try_select_wire() -> bool:
	if not inspect_mode and not manager.has_wire_cutter_equipped(): return false
	var point: Vector2 = manager.get_link_pointer_position()
	var closest := ""
	var distance := 10.0 / maxf(0.1, get_global_transform_with_canvas().get_scale().x)
	for key in manager.link_lines:
		var line: Line2D = manager.link_lines[key]
		if not is_instance_valid(line) or line.get_point_count() < 2: continue
		for index in range(1, line.get_point_count()):
			var candidate := Geometry2D.get_closest_point_to_segment(point, line.get_point_position(index - 1), line.get_point_position(index))
			var d := candidate.distance_to(point)
			if d < distance:
				distance = d
				closest = key
	if closest.is_empty(): return false
	selected_wire = closest
	focus_grid = manager.parse_grid_key(closest.split("|")[1])
	focus_type = endpoint_type(closest.split("|")[0], true)
	return true

func track_request(pair: Dictionary, should_disconnect: bool, is_undo: bool = false) -> void:
	pending = {"pair": pair.duplicate(), "key": pair_key(pair), "disconnect": should_disconnect, "undo": is_undo, "since": Time.get_ticks_msec()}

func disconnect_selected() -> void:
	if not pending.is_empty() or selected_wire.is_empty(): return
	var pair := key_pair(selected_wire)
	if send_mutation(pair, true): track_request(pair, true)

func undo_last() -> void:
	if not pending.is_empty() or undo_action.is_empty(): return
	var pair: Dictionary = undo_action.pair
	var should_disconnect := not bool(undo_action.disconnect)
	# Do not undo someone else's later edit.
	if manager.link_lines.has(pair_key(pair)) != should_disconnect:
		undo_action.clear()
		manager.world.show_notification("Connection changed. Select the current wire.")
		return
	if send_mutation(pair, should_disconnect): track_request(pair, should_disconnect, true)

func send_mutation(pair: Dictionary, should_disconnect: bool) -> bool:
	if pair.is_empty(): return false
	if should_disconnect and not manager.has_wire_cutter_equipped(): return false
	if not should_disconnect and not manager.has_electric_tool_equipped(): return false
	if not should_disconnect and manager.reject_occupied_machine_input(pair): return false
	if not manager.should_use_server_authoritative_actions():
		manager.world.show_notification("Connect to the server to edit saved wiring.")
		return false
	var network = manager.world.get_node_or_null("/root/NetworkManager")
	if network == null: return false
	match str(pair.kind):
		"input": return network.send_request_link_generator_pad(pair.generator_grid, pair.pad_grid, manager.world.current_world_name, should_disconnect)
		"output": return network.send_request_link_generator_pole(pair.generator_grid, pair.pole_grid, manager.world.current_world_name, should_disconnect)
		"pole_coupling": return network.send_request_link_electric_poles(pair.pole_a_grid, pair.pole_b_grid, manager.world.current_world_name, should_disconnect)
		"refinery_input": return network.send_oil_refinery_request(pair.refinery_grid, "link_pole", {"pole_x": pair.pole_grid.x, "pole_y": pair.pole_grid.y, "disconnect": should_disconnect}, manager.world.current_world_name)
		"battery_charger_input": return network.send_battery_charger_request(pair.charger_grid, "link_pole", {"pole_x": pair.pole_grid.x, "pole_y": pair.pole_grid.y, "disconnect": should_disconnect}, manager.world.current_world_name)
	return false

func _process(delta: float) -> void:
	if manager == null or manager.world == null: return
	var world_name := str(manager.world.current_world_name)
	if previous_world != world_name:
		previous_world = world_name
		pending.clear()
		undo_action.clear()
		generation_pulses.clear()
		generation_notes.clear()
		finish()
	if not manager.has_electric_tool_equipped() and manager.electric_tool_link_mode_active: finish()
	elapsed += delta
	if elapsed >= 0.15:
		elapsed = 0.0
		refresh_inspection()

func refresh_inspection() -> void:
	for key in generation_pulses.keys():
		if int(generation_pulses[key]) < Time.get_ticks_msec(): generation_pulses.erase(key)
	if not pending.is_empty():
		var exists: bool = manager.link_lines.has(pending.key)
		if exists == not bool(pending.disconnect):
			if bool(pending.undo): undo_action.clear()
			else: undo_action = pending.duplicate()
			manager.world.show_notification("Wire disconnected." if pending.disconnect else "Wire connected.")
			pending.clear()
		elif Time.get_ticks_msec() - int(pending.since) > 8000:
			pending.clear()
			manager.world.show_notification("Wiring was not confirmed. Inspect the connection and try again.")
	var signature: Array = [manager.link_revision, manager.link_lines.size(), focus_grid, focus_type, selected_wire, manager.electrical_visible]
	if signature != inspection_signature:
		inspection_signature = signature
		rebuild_focus()
		queue_redraw()
	# Drawing is limited to the selected wire / pointed target and short-lived
	# generation notes. No world-device walk and no redraw on idle frames.
	var now := Time.get_ticks_msec()
	generation_notes = generation_notes.filter(func(note: Dictionary): return int(note.until) > now)
	var draw_signature: Array = [manager.preview_target_grid, manager.electrical_visible, manager.electric_tool_link_mode_active, generation_notes.size(), selected_wire]
	if draw_signature != last_draw_signature or not generation_notes.is_empty():
		last_draw_signature = draw_signature
		queue_redraw()

func rebuild_focus() -> void:
	var topology: Array = [manager.link_revision, manager.link_lines.size()]
	if topology != graph_signature:
		graph_signature = topology
		graph_rebuild_count += 1
		adjacency.clear()
		for key in manager.link_lines:
			var parts: PackedStringArray = str(key).split("|")
			if parts.size() != 3: continue
			var a_id := endpoint_type(parts[0], true) + "@" + parts[1]
			var b_id := endpoint_type(parts[0], false) + "@" + parts[2]
			if not adjacency.has(a_id): adjacency[a_id] = []
			if not adjacency.has(b_id): adjacency[b_id] = []
			adjacency[a_id].append(b_id)
			adjacency[b_id].append(a_id)
	focused_nodes.clear()
	if focus_grid != manager.INVALID_LINK_GRID:
		var root_id: String = focus_type + "@" + manager.make_grid_key(focus_grid)
		focused_nodes[root_id] = true
		var queue: Array = [root_id]
		var cursor := 0
		while cursor < queue.size():
			var key = queue[cursor]
			for neighbor in adjacency.get(key, []):
				if focus_type in ["oil_refinery", "battery_charger"] and neighbor != root_id and (str(neighbor).begins_with("oil_refinery@") or str(neighbor).begins_with("battery_charger@")): continue
				if not focused_nodes.has(neighbor):
					focused_nodes[neighbor] = true
					queue.append(neighbor)
			cursor += 1
	for key in manager.link_lines:
		var line: Line2D = manager.link_lines[key]
		line.modulate.a = 1.0
		if line.has_method("set_selected"): line.set_selected(key == selected_wire)

func endpoint_type(kind: String, source: bool) -> String:
	if not source: return "metal_pad" if kind == "input" else "electric_pole"
	match kind:
		"input", "output": return "transformer"
		"refinery_input": return "oil_refinery"
		"battery_charger_input": return "battery_charger"
	return "electric_pole"

func show_generation(data: Dictionary) -> void:
	if flow_overlay != null: flow_overlay.generation(data)
	var source := Vector2i(int(data.get("source_x", 0)), int(data.get("source_y", 0)))
	var target := Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	var amount := int(data.get("generated_watts", 0))
	if amount > 0:
		generation_pulses[manager.make_link_key(target, source, "input")] = Time.get_ticks_msec() + 1200
	if amount > 0 or bool(data.get("full", false)):
		generation_notes.append({"grid": source, "text": "+%d energy" % amount if amount > 0 else "Storage full", "until": Time.get_ticks_msec() + 1800})
		if generation_notes.size() > 12: generation_notes.pop_front()

func _draw() -> void:
	if manager == null or manager.world == null: return
	if manager.electrical_visible:
		if manager.electric_tool_link_mode_active and manager.preview_target_grid != manager.INVALID_LINK_GRID:
			var draw_position: Vector2 = manager.grid_to_world_pos(manager.preview_target_grid)
			draw_rect(Rect2(draw_position - Vector2(12,12), Vector2(24,24)), Color(0.4,1,0.7), false)
		if manager.link_lines.has(selected_wire):
			var line: Line2D = manager.link_lines[selected_wire]
			if is_instance_valid(line) and line.get_point_count() >= 2:
				var a := line.get_point_position(0)
				var b := line.get_point_position(line.get_point_count() - 1)
				draw_circle(a, 3, Color.WHITE, false)
				draw_circle(b, 3, Color.WHITE, false)
	var now := Time.get_ticks_msec()
	for note in generation_notes:
		if int(note.until) <= now: continue
		var draw_position: Vector2 = manager.grid_to_world_pos(note.grid) + Vector2(-20,-28)
		draw_string(ThemeDB.fallback_font, draw_position, note.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,0.9,0.4))
