extends SceneTree

const WorldTileMapRenderer = preload("res://Scripts/world_tilemap_renderer.gd")

func _initialize() -> void:
	var root_node := Node2D.new()
	root_node.name = "ProbeWorld"
	root_node.set("BLOCK_SIZE", 32)
	root.add_child(root_node)

	var renderer := WorldTileMapRenderer.new()
	renderer.name = "WorldTileMapRenderer"
	root_node.add_child(renderer)
	renderer.setup(root_node)

	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	var texture := ImageTexture.create_from_image(image)
	var ok := renderer.set_foreground_collision_cell(Vector2i(0, 0), texture)
	renderer.refresh_streaming_now()

	var body := CharacterBody2D.new()
	body.name = "ProbeBody"
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = Vector2(-64, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	root_node.add_child(body)

	await process_frame
	await physics_frame

	var collided := false
	for step in range(30):
		body.velocity = Vector2(240, 0)
		body.move_and_slide()
		if body.get_slide_collision_count() > 0:
			collided = true
			break
		await physics_frame

	var collision_layer = renderer.get_node_or_null("ForegroundCollisionTileMapLayer")
	print("PROBE result tilemap_set=", ok,
		" layer_exists=", collision_layer != null,
		" layer_pos=", collision_layer.position if collision_layer != null else Vector2.INF,
		" body_pos=", body.position,
		" collided=", collided,
		" slide_count=", body.get_slide_collision_count())
	quit(0)
