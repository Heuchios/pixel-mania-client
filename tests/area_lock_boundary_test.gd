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
	assert(overlay.dash_segments.size() == 24, "Even spacing around the external perimeter")
	var points := {}
	for dot in overlay.dash_segments:
		assert(not points.has(dot.position), "Corners must not be double drawn")
		points[dot.position] = true
		assert(dot.position.x != 16 or absf(dot.position.y) == 16, "No internal tile seam")
	overlay._process(0.5)
	for dot in overlay.dash_segments:
		assert(points.has(dot.position), "Animation cannot move the lock boundary")
	assert(overlay.get_child_count() == 0, "Render without a node per dot")
	overlay.free()
	print("AREA_LOCK_BOUNDARY: PASS")
	quit()
