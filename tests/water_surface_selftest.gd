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
		chk("crest stays inside the clamp", peak < BandClass.MAX_OFFSET, "peak %.2f px" % peak)
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
