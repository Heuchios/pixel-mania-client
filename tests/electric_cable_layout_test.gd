extends SceneTree
const Fixtures = preload("res://tests/refinery_ux_test.gd")
const Electricity = preload("res://Scripts/electricity_manager.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var world = Fixtures.FakeWorld.new()
	root.add_child(world)
	var manager = Electricity.new()
	world.add_child(manager)
	manager.setup(world)
	manager.electrical_visible = true
	var ux = manager.circuit_ux
	var cable = manager.make_wire_line("LayoutCable", Color.YELLOW)
	manager.set_line_points(cable, Vector2(20,100), Vector2(200,100))
	manager.link_lines["output|0,0|1,0"] = cable
	manager.link_revision += 1
	var original_points: PackedVector2Array = cable.points.duplicate()
	for size in [Vector2i(1280,720), Vector2i(2548,1320), Vector2i(844,390)]:
		root.size = size
		for zoom in [1.0, 2.5, 4.0]:
			world.scale = Vector2.ONE * zoom
			ux.refresh_inspection()
			ux.flow_overlay.refresh_routes()
			ux.flow_overlay.refresh_visible()
			for i in range(10): await process_frame
			assert(ux.find_children("*", "Control", true, false).is_empty(), "Wiring tools must not create a toolbar or legend")
			assert(not cable.has_method("set_view_scale"), "Cables must not automatically resize")
			assert(cable.points == original_points and cable.scale == Vector2.ONE)
			var fresh = manager.make_wire_line("FreshCable", Color.YELLOW)
			manager.set_line_points(fresh, Vector2(20,100), Vector2(200,100))
			assert(fresh.points == cable.points and fresh.width == cable.width, "Old and new cables must match at every zoom")
			fresh.free()
	# Exercise the actual visibility-payload entry point, not injected flow state.
	manager.apply_visibility_payload({"visible":true, "generator_links":[{
		"generator_x":0,"generator_y":0,"pole_x":1,"pole_y":0,"generator_watts":200
	}]})
	assert(ux.flow_overlay.generator_energy[Vector2i.ZERO] == 200)
	manager.apply_visibility_payload({"visible":true, "generator_links":[{
		"generator_x":0,"generator_y":0,"pole_x":1,"pole_y":0,"generator_watts":0
	}]})
	assert(ux.flow_overlay.generator_energy[Vector2i.ZERO] == 0, "Refresh must also report depleted generators")
	world.free()
	print("ELECTRIC_CABLE_LAYOUT_TEST_OK")
	quit()
