extends SceneTree

## Requires a rendering driver (do not run with --headless).
## Compares actual GPU draws, including AtlasTexture margins and mirroring.
const FACES = preload("res://Assets/player/expressions/face_expressions.tres")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var atlased := make_viewport()
	var legacy := make_viewport()
	var names := ["idle", "blink", "jump", "fall", "punch", "hurt", "dead", "talk", "underwater"]
	for i in names.size():
		var name: String = names[i]
		var old_name: String = {"blink": "idle_blink", "talk": "talk_1"}.get(name, name)
		for mirrored in [false, true]:
			var position := Vector2(20 + i * 36, 20 + (36 if mirrored else 0))
			add_sprite(atlased, FACES.get_frame_texture(name, 0), position, mirrored)
			add_sprite(legacy, load("res://Assets/player/expressions/%s.png" % old_name), position, mirrored)
	await process_frame
	await RenderingServer.frame_post_draw
	var a := atlased.get_texture().get_image()
	var b := legacy.get_texture().get_image()
	var differences := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if not is_equal_approx(ca.a, cb.a) or (cb.a > 0.0 and not ca.is_equal_approx(cb)):
				differences += 1
	if differences > 0:
		push_error("Atlas draw differs from aligned legacy sprites at %d pixels" % differences)
		quit(1)
		return
	print("[face-expression-render] PASS: 9 expressions rendered pixel-identically facing both directions")
	# Save the native preview through Godot's renderer for visual review.
	var preview: Node = load("res://Scenes/debug/emote_atlas_preview.tscn").instantiate()
	var viewport := make_viewport(Vector2i(1920, 1080))
	viewport.add_child(preview)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://previews")
	viewport.get_texture().get_image().save_png("res://previews/emote_atlas_preview.png")
	quit(0)

func make_viewport(size := Vector2i(344, 80)) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport

func add_sprite(parent: Node, texture: Texture2D, position: Vector2, mirrored: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position
	sprite.flip_h = mirrored
	parent.add_child(sprite)
