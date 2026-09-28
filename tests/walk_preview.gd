extends SceneTree
func _init():
	call_deferred("run")
func strip(node: Node):
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base")
	for child in node.get_children():
		strip(child)
func run():
	root.size = Vector2i(1024, 240)
	root.content_scale_size = Vector2i(1024, 240)
	RenderingServer.set_default_clear_color(Color("334454"))
	var scene = load("res://Scenes/main.tscn").instantiate()
	var source = scene.get_node("Player/PlayerVisual")
	var animation: Animation = scene.get_node("Player/AnimationPlayer").get_animation("walk")
	assert(is_equal_approx(animation.length, 0.8))
	for track in range(animation.get_track_count()):
		assert(animation.track_get_key_value(track, 0) == animation.track_get_key_value(track, animation.track_get_key_count(track)-1))
	for i in range(8):
		var actor := Node2D.new()
		root.add_child(actor)
		actor.position = Vector2(64 + i*128, 125)
		actor.scale = Vector2.ONE * 3.0
		var visual = source.duplicate()
		strip(visual)
		actor.add_child(visual)
		visual.position = Vector2.ZERO
		visual.scale = Vector2.ONE
		var ap := AnimationPlayer.new()
		actor.add_child(ap)
		var library := AnimationLibrary.new()
		library.add_animation("walk", animation)
		ap.add_animation_library("", library)
		ap.play("walk")
		ap.seek(i * 0.1, true)
		ap.pause()
		var label := Label.new()
		label.position = Vector2(32+i*128,200)
		label.text = "%.1fs" % (i*.1)
		root.add_child(label)
	scene.free()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/walk-stride-preview.png")
	print("WALK_PREVIEW_PASS")
	quit()
