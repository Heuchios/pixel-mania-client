extends RefCounted
## Build a per-player fall entry from the visible jump pose, including early apexes.
static func prepare(actor: Node, animator: AnimationPlayer, from_jump: bool) -> void:
	if not animator.has_animation("fall"):
		return
	if not animator.has_meta("fall_entry_source"):
		animator.set_meta("fall_entry_source", animator.get_animation("fall"))
		var private_library := animator.get_animation_library("").duplicate() as AnimationLibrary
		animator.remove_animation_library("")
		animator.add_animation_library("", private_library)
	var original: Animation = animator.get_meta("fall_entry_source")
	var library := animator.get_animation_library("")
	library.remove_animation("fall")
	if not from_jump:
		library.add_animation("fall", original)
		return
	var entry := original.duplicate() as Animation
	for part in ["LeftArm", "RightArm", "HandItem"]:
		var node := actor.get_node("PlayerVisual/" + part) as Node2D
		var pivot := Vector2(5, 2) if part == "LeftArm" else Vector2(-6, 2)
		var rotation_track := entry.find_track(NodePath("PlayerVisual/" + part + ":rotation"), Animation.TYPE_VALUE)
		var position_track := entry.find_track(NodePath("PlayerVisual/" + part + ":position"), Animation.TYPE_VALUE)
		var final_angle: float = entry.track_get_key_value(rotation_track, entry.track_get_key_count(rotation_track)-1)
		for key in range(entry.track_get_key_count(rotation_track)):
			var progress := entry.track_get_key_time(rotation_track, key) / entry.length
			var weight := 1.0 - pow(1.0 - progress, 2.0)
			var angle := lerpf(node.rotation, final_angle, weight)
			entry.track_set_key_value(rotation_track, key, angle)
			entry.track_set_key_value(position_track, key, pivot - pivot.rotated(angle))
	for part in ["LeftFoot", "RightFoot"]:
		var node := actor.get_node("PlayerVisual/" + part) as Node2D
		var track := entry.add_track(Animation.TYPE_VALUE)
		entry.track_set_path(track, NodePath("PlayerVisual/" + part + ":position"))
		for key in range(17):
			var progress := key / 16.0
			var weight := progress * progress * (3.0 - 2.0 * progress)
			entry.track_insert_key(track, progress * entry.length, node.position.lerp(Vector2.ZERO, weight))
	library.add_animation("fall", entry)
