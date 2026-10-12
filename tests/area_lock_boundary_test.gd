extends SceneTree
class Locks extends RefCounted:
	func get_area_locks_save_data(): return [{"lock_id": "test"}]
	func get_area_lock_positions(_lock): return [Vector2i.ZERO, Vector2i(1, 0)]
	func can_current_player_build_in_area_lock(_lock): return true

func _initialize(): call_deferred("run")
func run():
	var overlay = preload("res://Scripts/area_lock_highlight_overlay.gd").new()
	root.add_child(overlay)
	overlay.setup(null, Locks.new())
	assert(overlay.dash_segments.size() == 6, "Only external tile edges are drawn")
	for phase in [0.0, 3.0, 9.5, 15.99, 16.0]:
		var visible_length := 0.0
		for edge in overlay.dash_segments:
			assert(edge.start.x != 16 or edge.end.x != 16, "No internal tile seam")
			for span in overlay.get_dash_spans(edge, phase):
				visible_length += span[0].distance_to(span[1])
				assert(is_equal_approx(edge.start.distance_to(span[0]) + span[0].distance_to(edge.end), 32.0))
		assert(is_equal_approx(visible_length, 96.0), "No disappearing/bunched dashes at phase wrap")
	var first = overlay.dash_segments[0]
	assert(overlay.get_dash_spans(first, 0.0) != overlay.get_dash_spans(first, 3.0), "Dashes travel along the boundary")
	overlay._process(0.5)
	assert(overlay.get_child_count() == 0, "Render without a node per dash")
	overlay.free()
	print("AREA_LOCK_BOUNDARY: PASS")
	quit()
