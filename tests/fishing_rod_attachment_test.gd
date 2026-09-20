extends SceneTree

const Attachment = preload("res://Scripts/fishing_rod_attachment.gd")
const Factory = preload("res://Scripts/atlas_texture_factory.gd")

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://Scripts/world.gd").new()
	world.item_database = load("res://Scripts/item_database.gd").ITEMS
	var local = load("res://Scripts/fishing_manager.gd").new()
	var remote = load("res://Scripts/player_manager.gd").new()
	local.world = world
	remote.world = world
	var player := Node2D.new()
	root.add_child(player)
	world.player = player
	var visual := Node2D.new()
	visual.name = "PlayerVisual"
	player.add_child(visual)
	var hand := Node2D.new()
	hand.name = "HandItem"
	visual.add_child(hand)
	hand.position = Vector2(17, -4)
	hand.rotation = 0.37
	var sprite := AnimatedSprite2D.new()
	sprite.name = "HandItemAnimated"
	hand.add_child(sprite)
	sprite.offset = Vector2(3, -7)
	sprite.scale = Vector2(1.15, 1.15)
	# Old generic markers must not override the atlas attachment for other players.
	var marker := Marker2D.new()
	marker.name = "FishingLineStart"
	marker.position = Vector2(999, 999)
	hand.add_child(marker)
	var checked := 0
	for rod_id in world.item_database:
		var data: Dictionary = world.item_database[rod_id]
		if not bool(data.get("fishing_rod", false)):
			continue
		world.equipped_tool = rod_id
		player.set_meta("fishing_rod_id", rod_id)
		var animations: Dictionary = data.get("hand_item_animations", {"idle": {"frames": [data.texture]}})
		var frames := SpriteFrames.new()
		for animation in animations:
			frames.add_animation(animation)
			for spec in animations[animation].frames:
				frames.add_frame(animation, Factory.load_texture(spec))
		sprite.sprite_frames = frames
		for animation in animations:
			sprite.animation = animation
			for frame in frames.get_frame_count(animation):
				sprite.frame = frame
				sprite.flip_h = false
				sprite.centered = false
				var size := Attachment.texture_size(sprite)
				var point := Attachment.local_tip(sprite, data, size, false) - sprite.offset
				var texture := frames.get_frame_texture(animation, frame)
				assert(Rect2(Vector2.ZERO, size).has_point(point), str(rod_id))
				assert(texture.get_image().get_pixelv(Vector2i(point)).a > 0.5, "%s %s %d tip must touch rod artwork" % [rod_id, animation, frame])
				for centered in [false, true]:
					sprite.centered = centered
					for facing in [-1, 1]:
						world.player_facing_direction = facing
						player.set_meta("facing", facing)
						sprite.flip_h = facing < 0
						var expected: Vector2 = point
						if facing < 0:
							expected.x = size.x - expected.x
						if centered:
							expected -= size * 0.5
						expected = sprite.to_global(expected + sprite.offset)
						assert(local.get_fishing_line_start_global_position().is_equal_approx(expected))
						assert(remote.get_remote_fishing_line_start_global_position(player).is_equal_approx(expected))
						checked += 1
	print("FISHING_ROD_ATTACHMENTS_OK: ", checked, " frame/facing/centering cases")
	local.free()
	remote.free()
	world.free()
	player.free()
	quit()
