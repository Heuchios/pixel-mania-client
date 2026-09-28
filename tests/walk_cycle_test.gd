extends SceneTree
func _init():
	call_deferred("run")
func run():
	for file in ["res://Scenes/main.tscn", "res://Scenes/player/netfox_player.tscn"]:
		var scene = load(file).instantiate()
		var original = scene.get_node("Player/AnimationPlayer") if file.ends_with("main.tscn") else scene.get_node("AnimationPlayer")
		var walk: Animation = original.get_animation("walk")
		var reset: Animation = original.get_animation("RESET")
		for track in range(walk.get_track_count()):
			assert(walk.track_get_key_value(track,0) == walk.track_get_key_value(track,walk.track_get_key_count(track)-1))
			assert(reset.find_track(walk.track_get_path(track), Animation.TYPE_VALUE) >= 0)
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
			var ap := AnimationPlayer.new()
			actor.add_child(ap)
			ap.add_animation_library("", original.get_animation_library(""))
			ap.play("walk")
			ap.seek(.2,true)
			assert(visual.get_node("Body").position.y < 0)
			var manager = load("res://Scripts/player_animation_manager.gd").new()
			manager.player = actor
			manager.movement_animation_player = ap
			manager.current_movement_animation_player = ap
			manager.current_movement_animation = "walk"
			manager.update_movement_animation_player("punch")
			assert(visual.get_node("Body").position == Vector2.ZERO)
			assert(visual.get_node("Head").position == Vector2(1,0))
			manager.free()
			actor.free()
		scene.free()
	print("WALK_CYCLE: loop, reset tracks, and action transition passed")
	quit()
