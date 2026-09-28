extends SceneTree
func _init():
	call_deferred("run")
func run():
	for file in ["res://Scenes/main.tscn", "res://Scenes/player/netfox_player.tscn"]:
		var scene = load(file).instantiate()
		var original = scene.get_node("Player/AnimationPlayer") if file.ends_with("main.tscn") else scene.get_node("AnimationPlayer")
		var walk: Animation = original.get_animation("fall")
		var reset: Animation = original.get_animation("RESET")
		for track in range(walk.get_track_count()):
			assert(walk.track_get_key_value(track,0) == reset.track_get_key_value(reset.find_track(walk.track_get_path(track), Animation.TYPE_VALUE), 0))
			assert(reset.find_track(walk.track_get_path(track), Animation.TYPE_VALUE) >= 0)
		# Check between keys too: interpolated rotation/translation must keep the
		# shoulder within a tenth of a source pixel throughout the raise.
		for arm in ["LeftArm", "RightArm", "HandItem"]:
			var pivot := Vector2(5, 2) if arm == "LeftArm" else Vector2(-6, 2)
			var rotation_track := walk.find_track(NodePath("PlayerVisual/" + arm + ":rotation"), Animation.TYPE_VALUE)
			var position_track := walk.find_track(NodePath("PlayerVisual/" + arm + ":position"), Animation.TYPE_VALUE)
			for sample in range(65):
				var time := walk.length * sample / 64.0
				var angle: float = walk.value_track_interpolate(rotation_track, time)
				var offset: Vector2 = walk.value_track_interpolate(position_track, time)
				assert((pivot.rotated(angle) + offset).distance_to(pivot) < 0.1, "Shoulder detached during fall")
		if file.ends_with("main.tscn"):
			var actor := Node2D.new()
			root.add_child(actor)
			var visual := Node2D.new()
			visual.name = "PlayerVisual"
			actor.add_child(visual)
			for name in ["LeftFoot", "RightFoot", "LeftArm", "RightArm", "HandItem", "Body", "Bottom", "Head"]:
				var part := Node2D.new()
				part.name = name
				visual.add_child(part)
			var line_start := Marker2D.new()
			line_start.name = "FishingLineStart"
			visual.get_node("HandItem").add_child(line_start)
			var ap := AnimationPlayer.new()
			actor.add_child(ap)
			ap.add_animation_library("", original.get_animation_library(""))
			ap.play("fall")
			ap.advance(0.5)
			assert(absf(visual.get_node("LeftArm").rotation) > 2.0)
			var manager = load("res://Scripts/player_animation_manager.gd").new()
			manager.player = actor
			manager.movement_animation_player = ap
			manager.current_movement_animation_player = ap
			manager.current_movement_animation = "fall"
			# Include the real competing idle/jump players, whose RESET tracks
			# used to overwrite the finished fall on subsequent update frames.
			for sibling_name in ["Jump", "idle"]:
				var sibling = scene.get_node("Player/" + sibling_name).duplicate()
				actor.add_child(sibling)
			manager.update_movement_animation_player("jump")
			var jump_player: AnimationPlayer = actor.get_node("Jump")
			for frame in range(180):
				manager.update_movement_animation_player("jump")
				jump_player.advance(1.0 / 60.0)
				if frame > 20:
					assert(visual.get_node("RightFoot").position.is_equal_approx(Vector2(-.5,-2.5)), "Jump must hold its tucked pose")
			assert(not jump_player.is_playing(), "Jump must not restart during ascent")
			var before_rotation: float = visual.get_node("RightArm").rotation
			var before_arm: Vector2 = visual.get_node("RightArm").position
			var before_foot: Vector2 = visual.get_node("RightFoot").position
			manager.update_movement_animation_player("fall")
			assert(is_equal_approx(visual.get_node("RightArm").rotation, before_rotation), "Apex snapped arm rotation")
			assert(visual.get_node("RightArm").position.distance_to(before_arm) < 0.01, "Apex snapped shoulder")
			assert(visual.get_node("RightFoot").position.is_equal_approx(before_foot), "Apex snapped foot")
			ap.advance(.08)
			assert(visual.get_node("RightFoot").position.y > before_foot.y and visual.get_node("RightFoot").position.y < 0, "Feet must ease down over time")
			ap.advance(.5)
			assert(visual.get_node("LeftFoot").position == Vector2.ZERO)
			assert(visual.get_node("RightFoot").position == Vector2.ZERO)
			for frame in range(300):
				manager.update_movement_animation_player("fall")
				ap.advance(1.0 / 60.0)
				assert(absf(visual.get_node("LeftArm").rotation) > 2.0, "Long fall lowered the left arm")
				assert(absf(visual.get_node("RightArm").rotation) > 2.0, "Long fall lowered the right arm")
			manager.update_movement_animation_player("fall")
			assert(not ap.is_playing(), "Long falls must hold the pose without restarting")
			manager.update_movement_animation_player("idle")
			assert(visual.get_node("LeftArm").position == Vector2.ZERO)
			assert(is_zero_approx(visual.get_node("LeftArm").rotation))
			assert(visual.get_node("HandItem").position == Vector2.ZERO)
			manager.free()
			actor.free()
		scene.free()
	print("JUMP_POSE: sustained ascent, fall transition, and landing passed")
	quit()
