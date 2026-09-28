extends SceneTree

## Headless regression test for the water surface.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless ^
##     --path G:\PixelMania\pixel-mania ^
##     --script res://tests/water_surface_selftest.gd
##
## Exercises the SHIPPED Band class in Scripts/water_surface_manager.gd, not a
## copy of it, so the client cannot silently drift from the prototype it came
## from. Exits non-zero on failure.
##
## Caveat: run from the real project this also starts the project's autoloads
## (NetworkManager, netfox), so expect their log noise and give it a moment.
## It does not join a world or send anything.

var failures := 0

func chk(label: String, ok: bool, detail: String = "") -> void:
	print(("OK   " if ok else "FAIL ") + label + ("  " + detail if detail != "" else ""))
	if not ok:
		failures += 1

func _initialize() -> void:
	var script = load("res://Scripts/water_surface_manager.gd")
	chk("manager parses", script != null and script is GDScript and script.can_instantiate())
	if script == null or not script.can_instantiate():
		quit(1)
		return
	_check_water_boundaries(script)

	var shader = load("res://Assets/shaders/water_body.gdshader")
	var names := []
	if shader != null:
		for entry in shader.get_shader_uniform_list():
			names.append(str(entry.get("name", "")))
	chk("shader compiles", shader != null)
	for u in ["body_tex", "surface_tex", "crest_frames_blend", "edge_line_px"]:
		chk("uniform " + u, names.has(u))

	# Exercise the SHIPPED inner Band class directly, not a copy of it.
	var BandClass = script.Band
	chk("Band class reachable", BandClass != null)
	if BandClass != null:
		var band = BandClass.new()
		var count := 121
		band.spacing = 32.0 / 7.0
		band.x_start = 0.0
		band.x_end = band.spacing * float(count - 1)
		band.resize(count)
		for i in count:
			band.base_y[i] = 0.0

		# The reported bug: jump in repeatedly, water level climbs and stays up.
		var worst_mean := 0.0
		for frame in 1800:
			if frame % 30 == 0:
				band.disturb(band.x_end * 0.5, -605.0, 3)
			band.simulate(1.0 / 60.0, 1.0, 0.0, 105.0, 0.12, 2, 10.0, 6.0)
			var mean := 0.0
			for i in count:
				mean += band.offsets[i]
			mean /= float(count)
			worst_mean = maxf(worst_mean, absf(mean))
		chk("30s of repeated jumps never raises the level", worst_mean < 0.5,
			"worst mean %.4f px" % worst_mean)

		var peak := 0.0
		var finite := true
		for i in count:
			if not is_finite(band.offsets[i]):
				finite = false
			peak = maxf(peak, absf(band.offsets[i]))
		chk("surface still rippling", peak > 1.0, "peak %.2f px" % peak)
		chk("no NaN", finite)
		chk("crest stays inside the clamp", peak <= BandClass.MAX_OFFSET, "peak %.2f px" % peak)
		chk("shoreline springs stay on the resting line",
			absf(band.offsets[0]) < 0.001 and absf(band.offsets[count - 1]) < 0.001,
			"ends %.4f / %.4f px" % [band.offsets[0], band.offsets[count - 1]])

		# Pinning must not act as an energy sink: a splash in the middle of a
		# pinned band should retain the same amplitude as an unpinned one.
		var retained := []
		for pinned in [true, false]:
			var b2 = BandClass.new()
			b2.spacing = 32.0 / 7.0
			b2.x_start = 0.0
			b2.x_end = b2.spacing * float(count - 1)
			b2.resize(count)
			for i in count:
				b2.base_y[i] = 0.0
			b2.shore_at_start = pinned
			b2.shore_at_end = pinned
			b2.disturb(b2.x_end * 0.5, -300.0, 3)
			for _f in 30:
				b2.simulate(1.0 / 60.0, 1.0, 0.0, 105.0, 0.12, 2, 10.0, 6.0)
			var p2 := 0.0
			for i in count:
				p2 = maxf(p2, absf(b2.offsets[i]))
			retained.append(p2)
		chk("pinning the shore does not drain the wave",
			retained[0] > retained[1] * 0.8,
			"pinned %.2f px vs free %.2f px" % [retained[0], retained[1]])

	# An all-culled frame must not try to close an empty mesh surface. Bands are
	# built from the view PLUS a margin, so water sitting just off screen makes
	# this happen every frame, and Godot logs "No vertices were added" each time.
	if BandClass != null:
		var node = script.new()
		node._immediate_mesh = ImmediateMesh.new()
		node._view_rect = Rect2(0.0, 0.0, 640.0, 360.0)

		var far = BandClass.new()
		far.spacing = 8.0
		far.x_start = 100000.0
		far.x_end = 100160.0
		far.resize(21)
		for i in 20:
			far.segment_bottom_y[i] = 64.0
		node.bands = [far]
		node._rebuild_mesh()
		chk("all-culled frame leaves the mesh empty and quiet",
			node._immediate_mesh.get_surface_count() == 0)

		var near = BandClass.new()
		near.spacing = 8.0
		near.x_start = 100.0
		near.x_end = 260.0
		near.resize(21)
		for i in 20:
			near.segment_bottom_y[i] = 64.0
		node.bands = [near]
		node._rebuild_mesh()
		chk("a visible band still builds one surface",
			node._immediate_mesh.get_surface_count() == 1)
		node.free()

	print("FAILURES ", failures)
	quit(1 if failures > 0 else 0)


func _check_water_boundaries(script: GDScript) -> void:
	var manager = script.new()
	# A pool with a raised left step, a submerged shelf, and a covered right
	# column. All water is connected below, but only two horizontal tops move.
	var blocks: Dictionary = {}
	for x in range(8):
		for y in range(0 if x < 2 else 1, 5 if x < 5 else 4):
			blocks[Vector2i(x, y)] = {"type": "water"}
	blocks[Vector2i(7, 0)] = {"type": "dirt"}
	var surfaces: Dictionary = {}
	for cell in blocks:
		if manager._is_water_cell(blocks, cell) and not manager._is_water_cell(blocks, cell + Vector2i.UP):
			surfaces[cell] = not blocks.has(cell + Vector2i.UP)
	manager._rebuild_bands(blocks, surfaces)
	chk("steps and covered water form separate bands", manager.bands.size() == 3)
	var covered_count := 0
	for band in manager.bands:
		var flat := true
		for y in band.base_y:
			flat = flat and is_equal_approx(y, band.base_y[0])
		chk("each surface has one resting height", flat)
		if band.exposed_surface:
			chk("terrain corners are anchored", band.shore_at_start and band.shore_at_end)
		if not band.exposed_surface:
			covered_count += 1
		band.disturb((band.x_start + band.x_end) * 0.5, -180.0, 2)
		for frame in 120:
			band.simulate(1.0 / 60.0, manager.stiffness, manager.damping, manager.ripple_speed, manager.smoothing, manager.propagation_passes, manager.calm_amplitude, manager.overdrive_damping)
		chk("corners stay fixed after a splash", is_zero_approx(band.offsets[0]) and is_zero_approx(band.offsets[-1]))
		var mean := 0.0
		var peak := 0.0
		for offset in band.offsets:
			mean += offset
			peak = maxf(peak, absf(offset))
		chk("pool keeps its volume", absf(mean) < 0.001)
		if not band.exposed_surface:
			chk("water beneath the ceiling stays still", is_zero_approx(peak))
		for frame in 600:
			band.simulate(1.0 / 60.0, manager.stiffness, manager.damping, manager.ripple_speed, manager.smoothing, manager.propagation_passes, manager.calm_amplitude, manager.overdrive_damping)
		var settled := 0.0
		for offset in band.offsets:
			settled = maxf(settled, absf(offset))
		chk("splash settles naturally", settled < 0.1)
	chk("covered column is retained as body water", covered_count == 1)
	chk("camera cuts do not create a false shore", not manager._is_shore_end(blocks, Vector2i(3, 1), 1))
	chk("covered water is not a splash surface", manager.surface_y_at(224.0) == INF)
	manager._immediate_mesh = ImmediateMesh.new()
	manager._view_rect = Rect2(-32.0, -32.0, 320.0, 240.0)
	for band in manager.bands:
		if band.exposed_surface:
			band.offsets[2] = -4.0
	manager._rebuild_mesh()
	var arrays: Array = manager._immediate_mesh.surface_get_arrays(0)
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var covered_vertices := 0
	var fixed_depth := true
	for i in vertices.size():
		var resting_y := -16.0 if vertices[i].x < 48.0 else 16.0
		# The step's shared x has vertices belonging to either resting height.
		if not is_equal_approx(vertices[i].x, 48.0):
			fixed_depth = fixed_depth and is_equal_approx(uvs[i].y, (vertices[i].y - resting_y) / 32.0)
		if colours[i].r < 0.5:
			covered_vertices += 1
	chk("ceiling mesh suppresses the underwater crest", covered_vertices > 0)
	chk("body shading uses fixed world depth", fixed_depth)
	manager.free()
