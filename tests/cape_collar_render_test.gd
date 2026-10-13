extends SceneTree

const HalfShader = preload("res://Assets/shaders/cape_collar_half.gdshader")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")
var probes: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func half_material(front: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HalfShader
	material.set_shader_parameter("left_half", front)
	return material

func errors_in(image: Image) -> int:
	var errors := 0
	for probe in probes:
		for y in range(32):
			for x in range(32):
				var source_color: Color = probe.image.get_pixel(x, y)
				if source_color.a < 0.999: continue
				var expected := source_color if x < 16 else Color.GREEN
				var pixel: Vector2 = probe.actor.to_global(Vector2(x - 15.5, y - 15.5))
				var actual := image.get_pixel(int(floor(pixel.x)), int(floor(pixel.y)))
				if absf(actual.r - expected.r) > 0.02 or absf(actual.g - expected.g) > 0.02 or absf(actual.b - expected.b) > 0.02:
					errors += 1
	return errors

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	root.size = Vector2i(640, 80)
	root.content_scale_size = root.size
	var face_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	face_image.fill(Color.GREEN)
	var face_texture := ImageTexture.create_from_image(face_image)
	var ids := ["black_hero_cape", "red_hero_cape", "blue_hero_cape", "vampire_cape", "dracula_cape"]
	for index in range(ids.size()):
		var texture: Texture2D = Factory.load_texture(ids[index] + "_neck")
		for facing in [1, -1]:
			var actor := Node2D.new()
			actor.position = Vector2(32 + index * 128 + (64 if facing == -1 else 0), 40)
			actor.scale.x = facing
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			root.add_child(actor)
			var front := Sprite2D.new()
			for layer in [33, 40, 45]:
				var sprite := front if layer == 45 else Sprite2D.new()
				sprite.texture = face_texture if layer == 40 else texture
				sprite.z_index = layer
				if layer != 40: sprite.material = half_material(layer == 45)
				actor.add_child(sprite)
			probes.append({"actor": actor, "front": front, "image": texture.get_image()})
	var correct := errors_in(await capture())
	assert(correct == 0, "Left collar pixels must cover the face; right pixels must stay behind it in both facings")
	# Prove the regression notices the old wrong-side layering.
	for probe in probes: probe.front.material.set_shader_parameter("left_half", false)
	var negative := errors_in(await capture())
	assert(negative > 20, "The opposite split must visibly fail")
	print("CAPE_COLLAR_PIXELS_PASS: five collars, both facings; mismatches=", correct, "; wrong-side control=", negative)
	for probe in probes: probe.actor.free()
	quit()
