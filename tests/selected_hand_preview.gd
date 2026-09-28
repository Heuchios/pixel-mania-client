extends SceneTree
func _init():
	call_deferred("run")
func strip(node: Node):
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base") or "Sleeve" in str(node.name) or str(node.name) == "ShirtBodyAnimated"
	for child in node.get_children():
		strip(child)
func run():
	root.size = Vector2i(1024, 240)
	root.content_scale_size = Vector2i(1024, 240)
	RenderingServer.set_default_clear_color(Color("334454"))
	var scene = load("res://Scenes/main.tscn").instantiate()
	var source = scene.get_node("Player/PlayerVisual")
	var animation: Animation = scene.get_node("Player/AnimationPlayer").get_animation("place_animation")
	assert(is_equal_approx(animation.length, 0.3))
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
		var preview_world = preload("res://tests/selected_hand_preview_test.gd").TestWorld.new()
		root.add_child(preview_world)
		preview_world.player = actor
		if i < 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://image.png")
			atlas.region = Rect2(0, 0, 32, 32)
			preview_world.icon = atlas
		else:
			preview_world.selected_item_type = "dirt_seed"
			preview_world.selected_item_category = "seed"
			preview_world.icon = load("res://Assets/inventory_icons/dirt_seed.png")
		var equipment = load("res://Scripts/equipment_manager.gd").new()
		root.add_child(equipment)
		equipment.set_process(false)
		equipment.world = preview_world
		equipment.player = actor
		equipment.hand_item_animated = visual.get_node("HandItem/HandItemAnimated")
		equipment.update_selected_hand_preview()
		var ap := AnimationPlayer.new()
		actor.add_child(ap)
		var library := AnimationLibrary.new()
		library.add_animation("walk", animation)
		ap.add_animation_library("", library)
		ap.play("walk")
		ap.seek(float(i % 4) * 0.1, true)
		ap.pause()
		var label := Label.new()
		label.position = Vector2(32+i*128,200)
		label.text = "%.2fs" % (float(i % 4)*.1)
		root.add_child(label)
	scene.free()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Pixelmania/selected-hand-preview.png")
	print("SELECTED_HAND_RENDER_PASS")
	quit()
