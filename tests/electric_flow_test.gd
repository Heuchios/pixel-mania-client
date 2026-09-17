extends SceneTree
const Fixtures = preload("res://tests/refinery_ux_test.gd")
const Electricity = preload("res://Scripts/electricity_manager.gd")
var manager
var world

func _initialize() -> void: call_deferred("run")

func edge(key: String, start: Vector2 = Vector2.ZERO, end: Vector2 = Vector2(100, 0)) -> void:
	var line: Line2D = manager.make_wire_line("FlowTest", Color.YELLOW)
	line.add_point(start)
	line.add_point(end)
	manager.link_lines[key] = line
	manager.link_revision += 1

func run() -> void:
	world = Fixtures.FakeWorld.new()
	root.add_child(world)
	manager = Electricity.new()
	world.add_child(manager)
	manager.setup(world)
	manager.electrical_visible = true
	var ux = manager.circuit_ux
	ux.selected_only = false
	var flow = ux.flow_overlay
	flow.ensure_scope()
	edge("input|0,0|0,1")
	edge("output|0,0|1,0")
	edge("pole_coupling|1,0|2,0")
	edge("refinery_input|3,0|2,0")
	world.oil_refinery_states[Vector2i(3,0)] = {"enabled": true, "running": true, "power_source": "transformer"}
	flow.update_generator({"x":0,"y":0,"watts":200})
	flow.refresh_routes()
	assert(flow.directions.get("output|0,0|1,0",0) == 1)
	assert(flow.directions.get("pole_coupling|1,0|2,0",0) == 1)
	assert(flow.directions.get("refinery_input|3,0|2,0",0) == -1)
	assert(not flow.directions.has("input|0,0|0,1"), "Pads animate only on generation")
	flow.generation({"x":0,"y":0,"source_x":0,"source_y":1,"watts":210,"generated_watts":10})
	flow.refresh_routes()
	assert(flow.directions["input|0,0|0,1"] == -1)
	flow.generation_until["input|0,0|0,1"] = 0
	world.oil_refinery_states[Vector2i(3,0)].power_source = "battery"
	flow.refresh_routes()
	assert(flow.directions.is_empty(), "Battery-only production must not animate grid wires")
	flow.refresh_visible()
	assert(not flow.animated)
	# Reproduce the debugger stop: a cached wire is actually freed between the
	# slower route refresh and visibility refresh, then replaced under its key.
	var replaced_key := "output|0,0|1,0"
	var removed_wire: Variant = manager.link_lines[replaced_key]
	manager.remove_generator_link_line(replaced_key)
	removed_wire.free()
	flow.refresh_visible()
	assert(flow.marks.is_empty() and flow.faint_marks.is_empty())
	edge(replaced_key, Vector2(50,50), Vector2(250,50))
	flow.state_elapsed = 0.0
	flow._process(0.001)
	assert(flow.edges[replaced_key].start == Vector2(50,50), "Replacement geometry must refresh without waiting for the timer")
	assert(not flow.edges[replaced_key].has("line"), "Caches must never retain wire Nodes")
	# Defend against queued/freed entries even if a caller has not removed the
	# dictionary entry yet; validation must happen before typed assignment.
	var replacement: Variant = manager.link_lines[replaced_key]
	replacement.queue_free()
	assert(flow.get_live_line(replaced_key) == null)
	replacement.free()
	assert(flow.get_live_line(replaced_key) == null)
	flow.view_signature.clear()
	flow.refresh_visible()
	flow.rebuild_topology()
	assert(flow.step_topology())
	assert(not flow.edges.has(replaced_key))
	manager.link_lines.erase(replaced_key)
	manager.link_revision += 1
	# Reverse feed through the same coupling; it must reverse the animation.
	manager.clear_link_line_visuals()
	world.oil_refinery_states.clear()
	edge("output|4,0|2,0")
	edge("pole_coupling|1,0|2,0")
	edge("refinery_input|0,0|1,0")
	world.oil_refinery_states[Vector2i.ZERO] = {"running":true,"power_source":"hybrid"}
	flow.update_generator({"x":4,"y":0,"watts":200})
	flow.refresh_routes()
	assert(flow.directions["pole_coupling|1,0|2,0"] == -1)
	# All three feeds must be shown, even when the closest one could satisfy
	# demand alone. Include a second transformer on the same pole and a loop.
	edge("output|5,0|1,0")
	edge("output|6,0|2,0")
	edge("pole_coupling|2,0|3,0")
	edge("pole_coupling|1,0|3,0")
	edge("output|7,0|9,0") # Charged but disconnected from demand.
	for x in [5,6,7]: flow.update_generator({"x":x,"y":0,"watts":200})
	flow.refresh_routes()
	for key in ["output|4,0|2,0", "output|5,0|1,0", "output|6,0|2,0"]:
		assert(flow.directions.get(key,0) == 1, "Every reachable charged transformer must show its supply")
	assert(flow.directions["pole_coupling|1,0|2,0"] == -1)
	assert(not flow.directions.has("output|7,0|9,0"))
	flow.update_generator({"x":6,"y":0,"watts":0})
	flow.refresh_routes()
	assert(not flow.directions.has("output|6,0|2,0"), "Empty transformers cannot supply energy")
	world.oil_refinery_states[Vector2i.ZERO].running = false
	flow.refresh_routes()
	assert(flow.directions.is_empty(), "Stopped consumers have no animated supply route")
	# Worst-case visible fixture: 1,500 active wires compete for a 64-wire budget.
	manager.clear_link_line_visuals()
	world.oil_refinery_states.clear()
	for i in range(750):
		edge("output|%d,0|%d,1" % [i,i], Vector2(20,20), Vector2(200,20))
		edge("refinery_input|%d,2|%d,1" % [i,i], Vector2(300,20), Vector2(200,20))
		world.oil_refinery_states[Vector2i(i,2)] = {"running":true,"power_source":"transformer"}
		flow.update_generator({"x":i,"y":0,"watts":100})
	var started := Time.get_ticks_usec()
	flow.refresh_routes()
	var max_step := Time.get_ticks_usec()-started
	assert(flow.topology_building and flow.topology_cursor <= 128, "Large topology builds must be split across frames")
	while flow.topology_building:
		var step_start := Time.get_ticks_usec()
		flow.refresh_routes()
		max_step = maxi(max_step, Time.get_ticks_usec()-step_start)
	print("Flow rebuild, 1,500 active wires: %.3f ms maximum step" % (float(max_step)/1000.0))
	flow.refresh_visible()
	assert(flow.visible_edges.size() == flow.MAX_VISIBLE_WIRES)
	assert(flow.animated)
	flow.build_marks(1.0)
	assert(flow.marks.size() <= 64 * 8, "Maximum two chevrons per budgeted wire")
	var first_marks: PackedVector2Array = flow.marks.duplicate()
	flow.build_marks(1.1)
	assert(flow.marks != first_marks, "Active chevrons must move")
	started = Time.get_ticks_usec()
	for i in range(1000): flow.build_marks(float(i)/30.0)
	print("Flow animation, 64 visible wires: %.3f ms/update" % (float(Time.get_ticks_usec()-started)/1000000.0))
	var builds: int = flow.route_build_count
	var topology_builds: int = flow.topology_build_count
	started = Time.get_ticks_usec()
	for i in range(100): flow.refresh_routes()
	print("Flow state check, 1,500 wires: %.3f ms/check (2.5 Hz)" % (float(Time.get_ticks_usec()-started)/100000.0))
	assert(flow.route_build_count == builds and flow.topology_build_count == topology_builds)
	assert(world.area_lookup_calls == 0 and world.reach_calls == 0)
	# A second snapshot arriving during an incremental build must restart it,
	# never complete a mix of old and new edges.
	flow.rebuild_topology()
	assert(not flow.step_topology())
	manager.clear_link_line_visuals()
	edge("input|20,20|21,21")
	flow._process(0.001)
	assert(not flow.topology_building and flow.edges.size() == 1)
	assert(flow.edges.has("input|20,20|21,21"))
	manager.position = Vector2(100000,100000)
	flow.refresh_visible()
	assert(flow.visible_edges.is_empty() and not flow.animated, "Offscreen wires must not spend the animation budget")
	manager.electrical_visible = false
	flow._process(1.0)
	assert(not flow.visible)
	world.current_world_name = "NEXT_WORLD"
	flow.ensure_scope()
	assert(flow.edges.is_empty() and flow.generator_energy.is_empty())
	world.free()
	print("ELECTRIC_FLOW_TEST_OK")
	quit()
