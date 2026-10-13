extends SceneTree

const Dust = preload("res://Scripts/player_ground_dust.gd")
const Atlas = preload("res://Scripts/atlas_texture_factory.gd")
var actor: Node2D
var effect: Node2D
var shoes: Array[AnimatedSprite2D] = []


func _initialize() -> void:
	call_deferred("run")


func strip(node: Node) -> void:
	node.set_script(null)
	if node is AnimatedSprite2D:
		node.stop()
		node.frame = 0
		node.visible = str(node.name).begins_with("Base")
	elif node is Sprite2D:
		node.hide()
	for child in node.get_children():
		strip(child)


func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame.get_format() in [Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGBF, Image.FORMAT_RGBAF]:
		frame.convert(Image.FORMAT_RGBA8)
		frame.linear_to_srgb()
	return frame


func run() -> void:
	root.size = Vector2i(768, 384)
	root.content_scale_size = Vector2i(256, 128)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background := ColorRect.new()
	background.color = Color("17213a")
	background.size = Vector2(256, 128)
	root.add_child(background)
	var floor_visual := ColorRect.new()
	floor_visual.color = Color("912687")
	floor_visual.position = Vector2(0, 94)
	floor_visual.size = Vector2(256, 34)
	root.add_child(floor_visual)
	# Preserve the real avatar's asymmetric foot layers and equipped shoe layer.
	var source = load("res://Scenes/main.tscn").instantiate()
	actor = Node2D.new()
	actor.position = Vector2(128, 87)
	var visual: Node2D = source.get_node("Player/PlayerVisual").duplicate()
	strip(visual)
	actor.add_child(visual)
	root.add_child(actor)
	source.free()
	var db = load("res://Scripts/item_database.gd").new()
	var item: Dictionary = db.get_item_data("basic_red_shoes")
	for side in ["Left", "Right"]:
		var shoe: AnimatedSprite2D = visual.get_node("%sFoot/%sShoeAnimated" % [side, side])
		var frames := SpriteFrames.new()
		frames.add_frame("default", Atlas.load_texture(item.get("%s_shoe_texture" % side.to_lower())))
		shoe.sprite_frames = frames
		shoe.animation = "default"
		shoe.scale = Vector2.ONE
		shoe.modulate = Color.WHITE
		shoe.z_index = int(item.get("slot_z_index", 2))
		shoe.show()
		shoes.append(shoe)
	db.free()
	effect = Dust.attach(actor)
	effect.set_process(false)
	if "--old-dust-layer" in OS.get_cmdline_user_args():
		effect.z_index = 5
	for facing in [1, -1]:
		for shoe in shoes:
			shoe.flip_h = facing < 0
		for age in [0.075, 0.14]:
			effect.reset_contact()
			effect.rng.seed = 420
			effect.emit_burst(Vector2(128.5, 94), true)
			effect._process(age)
			effect.set_process(false)
			effect.hide()
			var baseline := await capture()
			baseline.save_png("user://landing-dust-baseline.png")
			effect.show()
			var landing := await capture()
			landing.save_png("user://landing-dust-%s-%03d.png" % ["right" if facing > 0 else "left", int(age * 1000)])
			for shoe in shoes:
				if not check_foot_coverage(shoe, baseline, landing):
					quit(1)
					return
	print("GROUND_DUST_RENDER_PASS: landing dust covers both equipped shoes facing left and right")
	quit()


func check_foot_coverage(shoe: AnimatedSprite2D, baseline: Image, landing: Image) -> bool:
	var texture := shoe.sprite_frames.get_frame_texture(shoe.animation, 0).get_image()
	var covered := 0
	var opaque := 0
	for y in range(texture.get_height()):
		for x in range(texture.get_width()):
			if texture.get_pixel(x, y).a < 0.9:
				continue
			var sprite_x := texture.get_width() - 1 - x if shoe.flip_h else x
			var point := shoe.to_global(Vector2(sprite_x + 0.5, y + 0.5) - Vector2(texture.get_size()) * 0.5)
			var screen := Vector2i(point * 3.0)
			var before := baseline.get_pixelv(screen)
			var after := landing.get_pixelv(screen)
			opaque += 1
			if after.r + after.g + after.b > before.r + before.g + before.b + 0.3:
				covered += 1
	if opaque == 0:
		push_error("Equipped shoe must have visible pixels")
		return false
	print(shoe.name, ": dust covers ", covered, "/", opaque, " shoe pixels")
	if covered < opaque / 4:
		push_error("Landing dust must visibly cover both shoes: " + str(shoe.name))
		return false
	return true
