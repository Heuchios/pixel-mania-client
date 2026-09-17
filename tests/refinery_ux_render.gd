extends SceneTree
class PreviewWorld extends Node2D:
	var oil_refinery_states := {Vector2i.ZERO: {"enabled": true, "running": true, "linked_pole": true, "power_source": "hybrid", "transformer_watts": 650, "battery_watts": 60, "produced_count": 1, "output_capacity": 200, "crude_progress": 0.7}}
	var material_inventory := {"battery": 12}
	var item_database := {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	var world := PreviewWorld.new()
	root.add_child(world)
	var scene := load("res://Scenes/ui/oil_refinery/OilRefineryGUI.tscn") as PackedScene
	var ui = scene.instantiate()
	root.add_child(ui)
	ui.setup(world)
	ui.visible = true
	ui.panel.visible = true
	ui.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/refinery_ux_preview.png")
	ui.hide()
	var circuit_world = preload("res://tests/refinery_ux_test.gd").FakeWorld.new()
	root.add_child(circuit_world)
	var manager = preload("res://Scripts/electricity_manager.gd").new()
	circuit_world.add_child(manager)
	manager.setup(circuit_world)
	manager.electrical_visible = true
	await process_frame
	manager.circuit_ux.inspect_mode = true
	manager.circuit_ux.select_device(Vector2i(5, 7), "oil_refinery")
	for key in ["refinery_input|5,7|10,7", "refinery_input|5,10|10,7", "output|15,10|10,7", "input|15,10|20,7"]:
		var parts: PackedStringArray = key.split("|")
		var line = manager.make_wire_line("PreviewWire", Color.YELLOW)
		line.add_point(manager.grid_to_world_pos(manager.parse_grid_key(parts[1])))
		line.add_point(manager.grid_to_world_pos(manager.parse_grid_key(parts[2])))
		manager.link_lines[key] = line
	circuit_world.oil_refinery_states[Vector2i(5,7)] = world.oil_refinery_states[Vector2i.ZERO]
	manager.circuit_ux.refresh_inspection()
	manager.circuit_ux.flow_overlay.update_generator({"x":15,"y":10,"watts":650})
	manager.circuit_ux.flow_overlay.generation({"x":15,"y":10,"source_x":20,"source_y":7,"watts":650,"generated_watts":10})
	manager.circuit_ux.flow_overlay.refresh_routes()
	manager.circuit_ux.flow_overlay.refresh_visible()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	assert(manager.circuit_ux.toolbar.size.y < 160, "Wiring toolbar must stay compact")
	root.get_texture().get_image().save_png("res://tmp/wiring_ux_preview.png")
	quit()
