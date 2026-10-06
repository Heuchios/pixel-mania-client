extends SceneTree
const Status = preload("res://Scripts/refinery_status.gd")
const CircuitUX = preload("res://Scripts/electric_circuit_ux.gd")
const Electricity = preload("res://Scripts/electricity_manager.gd")
class FakeBlocks extends RefCounted:
	var background_blocks := {}
	func get_block_collision_rect_for_grid(grid: Vector2i, _type: String) -> Rect2:
		return Rect2(Vector2(grid) * 32 - Vector2(16,16), Vector2(32,32))
class FakeWorld extends Node2D:
	var current_world_name := "UX_TEST"
	var equipped_tool := "electric_tool"
	var oil_refinery_states := {}
	var battery_charger_states := {}
	var blocks := {}
	var block_manager = FakeBlocks.new()
	var notices: Array[String] = []
	var area_lookup_calls := 0
	var reach_calls := 0
	var reachable := true
	func get_anchor_grid_for_block_area(_grid: Vector2i) -> Vector2i:
		area_lookup_calls += 1
		return Vector2i(999999, 999999)
	func can_reach_grid(_grid: Vector2i) -> bool:
		reach_calls += 1
		return reachable
	func get_pointer_global_position() -> Vector2: return Vector2(320, 320)
	func show_notification(message: String) -> void: notices.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Status.describe({"output_count": 1, "output_capacity": 200}).storage_ratio == 0.005)
	assert(Status.describe({"enabled": true}).badge == "NO LINK")
	assert(Status.describe({"enabled": true, "linked_pole": true}).badge == "EMPTY")
	assert(Status.describe({"enabled": true, "running": true, "power_source": "battery"}).badge == "BACKUP")
	assert(Status.describe({"output_count": 200}).badge == "FULL")
	assert(Status.describe({"enabled": false, "crude_progress": 0.5}).next_text == "Paused")
	assert(Status.describe({"running": true, "crude_progress": 0.5}).next_text == "30m left")
	assert(Status.describe({"running": true, "crude_progress": 0.7}).next_text == "18m left")
	assert(Status.describe({"battery_watts": 60}).reserve_text == "Backup: 36m")
	var manager := Electricity.new()
	var ux := CircuitUX.new()
	ux.manager = manager
	for key in ["input|1,2|3,4", "output|1,2|3,4", "refinery_input|1,2|3,4", "battery_charger_input|1,2|3,4", "pole_coupling|1,2|3,4"]:
		assert(ux.pair_key(ux.key_pair(key)) == key)
	ux.free()
	manager.free()
	var scene := load("res://Scenes/ui/oil_refinery/OilRefineryGUI.tscn") as PackedScene
	var ui = scene.instantiate()
	root.add_child(ui)
	assert(ui.scene_ui_ready)
	assert(ui.footer_label != null and ui.power_value_label != null and ui.subtitle_label != null)
	ui.refresh()
	assert(ui.output_fill.size.x == 0)
	ui.free()
	var world := FakeWorld.new()
	root.add_child(world)
	var live := Electricity.new()
	world.add_child(live)
	live.setup(world)
	live.electrical_visible = true
	await process_frame
	var inspector = live.circuit_ux
	inspector.select_device(Vector2i(1, 1), "oil_refinery")
	for key in ["refinery_input|1,1|3,3", "refinery_input|2,2|3,3", "output|4,4|3,3", "input|4,4|5,5", "input|9,9|8,8"]:
		var line := live.make_wire_line("TestWire", Color.YELLOW)
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(64, 64))
		live.link_lines[key] = line
	inspector.refresh_inspection()
	assert(live.link_lines["refinery_input|1,1|3,3"].modulate.a == 1.0)
	assert(live.link_lines["refinery_input|2,2|3,3"].modulate.a == 1.0, "Other circuits must remain equally visible")
	assert(live.link_lines["input|4,4|5,5"].modulate.a == 1.0)
	assert(live.link_lines["input|9,9|8,8"].modulate.a == 1.0)
	var rebuilds: int = inspector.graph_rebuild_count
	for i in range(100): inspector.refresh_inspection()
	assert(inspector.graph_rebuild_count == rebuilds, "Idle inspection must reuse the graph")
	inspector.multi_connect = true
	live.begin_electric_tool_link_mode(live.make_link_endpoint("transformer", Vector2i(4, 4)))
	live.finish_electric_tool_link({"kind": "input", "generator_grid": Vector2i(4,4), "pad_grid": Vector2i(6,6)})
	assert(live.electric_tool_link_mode_active)
	world.area_lookup_calls = 0
	world.reach_calls = 0
	for i in range(30000): world.blocks[Vector2i(i, 1000)] = {"type": "stone"}
	var started := Time.get_ticks_usec()
	for i in range(1000):
		live.resolve_electrical_link_endpoint(Vector2i(i % 50, 50))
	print("Electrical picking with 30,000 blocks: %0.3f ms/lookup" % (float(Time.get_ticks_usec() - started) / 1000000.0))
	assert(world.area_lookup_calls == 0, "Electrical picking must not scan all blocks")
	for i in range(100): inspector.refresh_inspection()
	assert(world.reach_calls == 0, "Link mode must not enumerate candidate tiles")
	assert(live.get_link_pointer_position() == Vector2(320,320), "Wire picking must use the pointer")
	assert(inspector.undo_action.is_empty(), "Unconfirmed actions cannot be undone")
	live.apply_snapshot([], true)
	assert(live.electric_tool_link_mode_active and live.electric_tool_link_source_grid == Vector2i(4,4))
	assert(live.link_flow_particles.is_empty(), "Connectivity alone must not animate power")
	inspector.finish()
	assert(not live.electric_tool_link_mode_active)
	world.equipped_tool = "wire_cutter"
	assert(live.has_wire_cutter_equipped() and not live.has_electric_tool_equipped())
	assert(not live.try_electric_tool_link_at(Vector2i(4, 4)), "Cutters cannot connect wires")
	var cut_wire := live.make_wire_line("CutTest", Color.YELLOW)
	cut_wire.add_point(Vector2(300, 320))
	cut_wire.add_point(Vector2(340, 320))
	live.link_lines["output|9,10|11,10"] = cut_wire
	assert(inspector.try_select_wire(), "Cutters pick wires without Inspect mode")
	assert(inspector.selected_wire == "output|9,10|11,10")
	assert(not inspector.send_mutation(inspector.key_pair(inspector.selected_wire), false), "Cutters cannot reconnect via Undo")
	world.equipped_tool = "electric_tool"
	assert(not inspector.send_mutation(inspector.key_pair(inspector.selected_wire), true), "Screwdrivers cannot disconnect")
	assert(not live.try_wire_cutter_at(Vector2i(10, 10)))
	inspector.finish()
	inspector.pending.clear()
	test_cancel_link(live, world)
	test_machine_single_input(live, world)
	for i in range(1500):
		var key := "pole_coupling|%d,0|%d,0" % [i, i+1]
		var wire := live.make_wire_line("StressWire", Color.YELLOW)
		wire.add_point(Vector2(i*32,0))
		wire.add_point(Vector2((i+1)*32,0))
		live.link_lines[key] = wire
	live.link_revision += 1
	inspector.select_device(Vector2i.ZERO, "electric_pole")
	inspector.refresh_inspection()
	rebuilds = inspector.graph_rebuild_count
	started = Time.get_ticks_usec()
	for i in range(1000): inspector.refresh_inspection()
	print("Cached inspection with 1,500 wires: %0.3f ms/refresh" % (float(Time.get_ticks_usec() - started) / 1000000.0))
	assert(inspector.graph_rebuild_count == rebuilds, "Large unchanged circuits must not rebuild")
	world.free()
	print("REFINERY_UX_TEST_OK")
	quit()

func test_cancel_link(live, world) -> void:
	var source := Vector2i(4, 4)
	var pole := Vector2i(8, 4)
	world.blocks[source] = {"type": "transformer"}
	world.blocks[pole] = {"type": "electric_pole"}
	world.blocks[Vector2i(12, 4)] = {"type": "oil_refinery"}
	world.blocks[Vector2i(16, 4)] = {"type": "battery_charger"}
	world.blocks[Vector2i(20, 4)] = {"type": "stone"}
	world.blocks[Vector2i(24, 4)] = {"type": "transformer"}
	var original_links: int = live.link_lines.size()
	world.reachable = false
	for target in [Vector2i(100, 100), Vector2i(20, 4), Vector2i(24, 4), source]:
		assert(live.begin_electric_tool_link_mode(live.make_link_endpoint("transformer", source)))
		world.reach_calls = 0
		assert(live.try_electric_tool_link_at(target))
		assert(not live.has_pending_electric_tool_link(), "Clicking away or the source must cancel")
		assert(live.link_preview_line == null, "Cancellation must remove the dangling wire")
		assert(world.reach_calls == 0, "Cancellation must work outside interaction reach")
		assert(live.circuit_ux.pending.is_empty() and live.link_lines.size() == original_links)
	assert(live.begin_electric_tool_link_mode(live.make_link_endpoint("transformer", source)))
	assert(live.try_electric_tool_link_at(pole))
	assert(live.has_pending_electric_tool_link(), "An out-of-reach valid target must not connect")
	live.cancel_electric_tool_link_mode()
	assert(live.begin_generator_link_mode_for_kind(source, live.LINK_MODE_OUTPUT))
	world.reach_calls = 0
	assert(live.try_link_generator_pad_at(Vector2i(100, 100)))
	assert(not live.has_pending_generator_link() and live.link_preview_line == null)
	assert(world.reach_calls == 0)
	assert(live.begin_oil_refinery_link_mode(Vector2i(12, 4)))
	world.reach_calls = 0
	assert(live.try_link_oil_refinery_pole_at(Vector2i(100, 100)))
	assert(not live.has_pending_oil_refinery_link() and live.link_preview_line == null)
	assert(world.reach_calls == 0)
	assert(live.begin_battery_charger_link_mode(Vector2i(16, 4)))
	world.reach_calls = 0
	assert(live.try_link_battery_charger_pole_at(Vector2i(100, 100)))
	assert(not live.has_pending_battery_charger_link() and live.link_preview_line == null)
	assert(world.reach_calls == 0)
	world.reachable = true
	# A valid existing connection still selects normally after cancellation.
	var key: String = live.make_link_key(source, pole, "output")
	live.link_lines[key] = live.make_wire_line("ExistingConnection", Color.YELLOW)
	assert(live.begin_electric_tool_link_mode(live.make_link_endpoint("transformer", source)))
	assert(live.try_electric_tool_link_at(pole))
	assert(live.circuit_ux.selected_wire == key and not live.has_pending_electric_tool_link())
	live.circuit_ux.finish()

func test_machine_single_input(live, world) -> void:
	for entry in [
		{"kind": "refinery_input", "type": "oil_refinery", "field": "refinery_grid", "grid": Vector2i(12, 4)},
		{"kind": "battery_charger_input", "type": "battery_charger", "field": "charger_grid", "grid": Vector2i(16, 4)}
	]:
		var grid: Vector2i = entry.grid
		var states: Dictionary = world.oil_refinery_states if entry.type == "oil_refinery" else world.battery_charger_states
		states[grid] = {"linked_pole": true, "linked_pole_x": 8, "linked_pole_y": 4}
		var pair := {"kind": entry.kind, "pole_grid": Vector2i(28, 4)}
		pair[entry.field] = grid
		# State-only detection covers the interval before visibility draws the wire.
		assert(live.begin_electric_tool_link_mode(live.make_link_endpoint("electric_pole", Vector2i(28, 4))))
		assert(live.complete_electric_tool_link(pair))
		assert(not live.has_pending_electric_tool_link() and live.circuit_ux.pending.is_empty())
		assert(states[grid].linked_pole_x == 8)
		assert(world.notices[-1].contains("already has a power wire"))
		if entry.type == "oil_refinery":
			assert(live.begin_oil_refinery_link_mode(grid))
			assert(live.try_link_oil_refinery_pole_at(Vector2i(8, 4)))
			assert(not live.has_pending_oil_refinery_link())
		else:
			assert(live.begin_battery_charger_link_mode(grid))
			assert(live.try_link_battery_charger_pole_at(Vector2i(8, 4)))
			assert(not live.has_pending_battery_charger_link())
		states.erase(grid)
		assert(not live.reject_occupied_machine_input(pair), "An unconnected machine must accept its first wire")
		var key: String = entry.kind + "|" + live.make_grid_key(grid) + "|8,4"
		live.link_lines[key] = live.make_wire_line("OccupiedInput", Color.YELLOW)
		# Both click orders normalize to the same machine input pair.
		for reverse in [false, true]:
			var machine: Dictionary = live.make_link_endpoint(entry.type, grid)
			var pole: Dictionary = live.make_link_endpoint("electric_pole", Vector2i(28, 4))
			var normalized: Dictionary = live.make_electric_tool_link_pair(pole if reverse else machine, machine if reverse else pole)
			assert(live.circuit_ux.select_existing(normalized))
			assert(live.circuit_ux.selected_wire == key)
			assert(live.reject_occupied_machine_input(normalized), "Drawn wires also reserve the machine input")
		live.link_lines[key].free()
		live.link_lines.erase(key)
		assert(not live.reject_occupied_machine_input(pair), "Cutting the current wire allows reconnection")
	live.circuit_ux.finish()
