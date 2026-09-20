extends RefCounted

# Points are measured in the current atlas frame, before sprite transforms.
static func local_tip(sprite, data: Dictionary, texture_size: Vector2, facing_left: bool) -> Vector2:
	var left_override := facing_left and data.has("fishing_line_tip_offset_left")
	var value = data.get("fishing_line_tip_offset_left") if left_override else data.get("fishing_line_tip_offset", [0, 0])
	if sprite is AnimatedSprite2D and not left_override:
		var animation_points: Dictionary = data.get("fishing_line_tip_frames", {})
		var points: Array = animation_points.get(str(sprite.animation), [])
		if not points.is_empty():
			value = points[clampi(sprite.frame, 0, points.size() - 1)]
	var point := Vector2.ZERO
	if value is Vector2:
		point = value
	elif value is Array and value.size() >= 2:
		point = Vector2(float(value[0]), float(value[1]))
	if sprite is AnimatedSprite2D or sprite is Sprite2D:
		if sprite.flip_h and not left_override:
			point.x = texture_size.x - point.x
		if sprite.flip_v:
			point.y = texture_size.y - point.y
		if sprite.centered:
			point -= texture_size * 0.5
		point += sprite.offset
	return point

static func texture_size(sprite) -> Vector2:
	if sprite is AnimatedSprite2D:
		var frames: SpriteFrames = sprite.sprite_frames
		if frames != null and frames.has_animation(sprite.animation) and frames.get_frame_count(sprite.animation) > 0:
			var texture := frames.get_frame_texture(sprite.animation, sprite.frame)
			if texture != null:
				return texture.get_size()
	elif sprite is Sprite2D and sprite.texture != null:
		return sprite.get_rect().size
	return Vector2.ZERO
