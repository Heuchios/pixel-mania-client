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
	func get_anchor_grid_for_block_area(_grid: Vector2i) -> Vector2i:
		area_lookup_calls += 1
		return Vector2i(999999, 999999)
	func can_reach_grid(_grid: Vector2i) -> bool:
		reach_calls += 1
		return true
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
	assert(live.link_lines["refinery_input|2,2|3,3"].modulate.a < 0.2)
	assert(live.link_lines["input|4,4|5,5"].modulate.a == 1.0)
	assert(live.link_lines["input|9,9|8,8"].modulate.a < 0.2)
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
