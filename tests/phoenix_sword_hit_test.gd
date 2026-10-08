extends SceneTree

const Effect := preload("res://Scenes/particles/SwordFireHitFX.tscn")
const OUTPUT := "D:/Pixelmania/phoenix-impact-preview"


func _init() -> void:
	call_deferred("run")


func make_effect(at: Vector2 = Vector2.ZERO, size: float = 1.0) -> Node2D:
	var effect := Effect.instantiate()
	effect.preview_emitting = false
	effect.auto_restart_preview = false
	root.add_child(effect)
	effect.position = at
	effect.scale = Vector2.ONE * size
	return effect


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("PHOENIX_HIT_FAIL: " + message)
		quit(1)
	return condition


func run() -> void:
	var right = make_effect()
	var left = make_effect()
	right.play_once(1)
	left.play_once(-1)
	right.set_process(false)
	left.set_process(false)
	var total_particles := 0
	for i in range(right.gpu_emitters.size()):
		var emitter: GPUParticles2D = right.gpu_emitters[i]
		var mirrored: GPUParticles2D = left.gpu_emitters[i]
		if not check(emitter.emitting and emitter.visible and mirrored.scale.x < 0.0, "Both facing directions must start the same impact"):
			return
		if not check(emitter.process_material != mirrored.process_material, "Overlapping hits must have independent materials"):
			return
		var material := emitter.process_material as ParticleProcessMaterial
		if not check(material.color_ramp != null and material.color_ramp.gradient.get_color(material.color_ramp.gradient.get_point_count() - 1).a == 0.0, "Every particle layer must fade to transparent"):
			return
		if not check(right.burst_lifetime > emitter.lifetime * (2.0 - emitter.explosiveness), "Wait for the last emitted particle before cleanup"):
			return
		total_particles += emitter.amount
	if not check(total_particles <= 50, "Rapid impacts must keep a compact particle budget"):
		return
	right._process(0.25)
	if not check(is_zero_approx(right.impact_light.energy), "The hit light must finish before the ember tail"):
		return
	left.stop()
	for emitter in left.gpu_emitters:
		if not check(not emitter.visible and not emitter.emitting, "Stopping must clear the visible burst immediately"):
			return
	left.start()
	if not check(left.gpu_emitters[0].visible and left.gpu_emitters[0].emitting, "Editor preview must restart after stop"):
		return
	left.stop()
	left.free()
	right._process(right.burst_lifetime)
	await process_frame
	if not check(not is_instance_valid(right), "A one-shot hit must free itself after its full fade"):
		return
	print("PHOENIX_HIT_PASS: both facings, independent overlapping hits, transparent particle endings, lifetime cleanup, light fade, preview restart, bounded particles")
	if "--render-phoenix-hit" in OS.get_cmdline_user_args():
		await render_preview()
	quit()


func render_preview() -> void:
	root.size = Vector2i(1000, 490)
	root.content_scale_size = Vector2i(1000, 490)
	RenderingServer.set_default_clear_color(Color("101e32"))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var heading := Label.new()
	heading.text = "PHOENIX SWORD / IMPACT"
	heading.position = Vector2(30, 25)
	heading.add_theme_font_size_override("font_size", 26)
	heading.modulate = Color("ffce83")
	root.add_child(heading)
	var database = load("res://Scripts/item_database.gd").new()
	var item: Dictionary = database.get_item_data("stone")
	var texture := preload("res://Scripts/atlas_texture_factory.gd").load_texture(item.texture)
	database.free()
	for i in range(2):
		var block := Sprite2D.new()
		block.texture = texture
		block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		block.position = Vector2(250 + i * 500, 280)
		block.scale = Vector2.ONE * 3.4
		root.add_child(block)
		var label := Label.new()
		label.text = "SINGLE HIT" if i == 0 else "RAPID HITS"
		label.position = Vector2(150 + i * 500, 420)
		label.size.x = 200
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 19)
		label.modulate = Color("afbed0")
		root.add_child(label)
	# Let GPU particle shaders initialize before recording the burst.
	for i in range(5):
		await process_frame
	for frame in range(78):
		if frame == 9:
			var effect = make_effect(Vector2(250, 280), 3.4)
			effect.play_once(1)
		if frame in [9, 15, 21, 27]:
			var effect = make_effect(Vector2(750, 280), 3.4)
			effect.play_once(-1)
		for substep in range(2):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("frame-%03d.png" % frame))
	print("PHOENIX_HIT_PREVIEW_PASS: ", OUTPUT)
