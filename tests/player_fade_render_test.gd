extends SceneTree
func _init():
	call_deferred("run")
func run():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var group := Node2D.new()
	viewport.add_child(group)
	for data in [[Color.RED,-30],[Color.BLUE,30]]:
		var layer := Polygon2D.new()
		layer.polygon = PackedVector2Array([Vector2(20,20),Vector2(100,20),Vector2(100,100),Vector2(20,100)])
		layer.color = data[0]
		layer.z_index = data[1]
		group.add_child(layer)
	var fx = load("res://Scenes/particles/PlayerWorldFadeFX.tscn").instantiate()
	viewport.add_child(fx)
	fx.play_enter(group)
	fx.active_tween.pause()
	fx._set_target_alpha(0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	var pixel := picture.get_pixel(64,64)
	print("Composite pixel: ", pixel)
	if pixel.r > 0.03 or abs(pixel.b - 0.5) > 0.04 or abs(pixel.a-0.5)>0.04:
		push_error("Body shows through clothing during grouped fade")
		quit(1)
		return
	fx.active_tween.custom_step(0.5)
	assert(is_equal_approx(group.modulate.a, 1.0))
	assert(fx.composite == null)
	print("[player-fade-render] PASS: opaque clothing over body stays intact at half opacity, including different layer Z values")
	quit(0)


