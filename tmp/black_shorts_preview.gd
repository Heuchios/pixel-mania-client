extends SceneTree
const Equipment = preload("res://Scripts/equipment_manager.gd")
class WorldFixture extends Node:
	var item_database = preload("res://Scripts/item_database.gd").ITEMS
	var pants_textures = {}
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
		var world := WorldFixture.new()
		var manager = Equipment.new()
		manager.player = actor
		manager.world = world
		manager.setup_wearable_animated_parts()
		manager.update_equipped_pants_visual("basic_black_pants", 1)
		manager.get_wearable_part("pants").z_index = 1
		print("SHORTS ", manager.get_wearable_part("pants").position, " ", manager.get_wearable_part("pants").scale, " ", manager.get_wearable_part("pants").sprite_frames.get_frame_texture("idle", 0).region, " ", manager.get_wearable_part("pants").visible)
		manager.get_wearable_part("pants").sprite_frames.get_frame_texture("idle", 0).get_image().save_png("D:/Pixelmania/shorts-loaded-middle.png")
		manager.free()
		world.free()
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
	for actor in root.get_children():
		if actor.has_node("PlayerVisual/Bottom/PantsAnimated"):
			var part = actor.get_node("PlayerVisual/Bottom/PantsAnimated")
			print("DRAW ", part.animation, " ", part.visible, " ", part.is_visible_in_tree(), " ", part.global_position, " ", part.sprite_frames.get_frame_count(part.animation))
	root.get_texture().get_image().save_png("D:/Pixelmania/black-shorts-preview.png")
	print("WALK_PREVIEW_PASS")
	quit()
