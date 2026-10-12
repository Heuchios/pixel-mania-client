extends RefCounted

## Tuck the upper hair under headwear without editing textures or equipped IDs.
## New hats opt in by default; decorative accessories can set tucks_hair=false.
const CLIP_SHADER = preload("res://Assets/shaders/hair_hat_clip.gdshader")
const MATERIAL_META := &"hair_hat_clip_material"
const ORIGINAL_MATERIAL_META := &"hair_hat_original_material"
static var texture_profiles := {}

static func apply(hair: AnimatedSprite2D, hat: AnimatedSprite2D, hat_data: Dictionary) -> void:
	if not is_instance_valid(hair):
		return
	var active := hair.visible and is_instance_valid(hat) and hat.visible and bool(hat_data.get("tucks_hair", true))
	var profile := get_hat_profile(hat) if active else {}
	var material: ShaderMaterial = hair.get_meta(MATERIAL_META) if hair.has_meta(MATERIAL_META) else null
	if profile.is_empty():
		if material != null and hair.material == material:
			hair.material = hair.get_meta(ORIGINAL_MATERIAL_META) if hair.has_meta(ORIGINAL_MATERIAL_META) else null
		return
	if material == null:
		material = ShaderMaterial.new()
		material.shader = CLIP_SHADER
		hair.set_meta(MATERIAL_META, material)
	if hair.material != material:
		hair.set_meta(ORIGINAL_MATERIAL_META, hair.material)
		hair.material = material
	# Work in the hat's local space, independently of the hair's canvas size,
	# sprite offset, and the shared Head parent's facing/movement transforms.
	var to_hat := hat.transform.affine_inverse() * hair.transform
	material.set_shader_parameter("hair_to_hat_x", to_hat.x)
	material.set_shader_parameter("hair_to_hat_y", to_hat.y)
	material.set_shader_parameter("hair_to_hat_origin", to_hat.origin - hat.offset)
	material.set_shader_parameter("brim_profile", profile.texture)
	material.set_shader_parameter("brim_left", profile.left)
	material.set_shader_parameter("brim_width", profile.edge.size())

static func get_hat_profile(hat: AnimatedSprite2D) -> Dictionary:
	var frames := hat.sprite_frames
	if frames == null:
		return {}
	var key := &"hair_hat_profile_centered" if hat.centered else &"hair_hat_profile"
	if frames.has_meta(key):
		return frames.get_meta(key)
	var sources := {}
	var left := INF
	var right := -INF
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, frame)
			if texture == null:
				continue
			var texture_id := _texture_key(texture)
			if sources.has(texture_id):
				continue
			if not texture_profiles.has(texture_id):
				texture_profiles[texture_id] = _read_lower_edge(texture)
			var edge: PackedFloat32Array = texture_profiles[texture_id]
			if edge.is_empty():
				continue
			var offset := -Vector2(texture.get_size()) * 0.5 if hat.centered else Vector2.ZERO
			sources[texture_id] = {"edge": edge, "offset": offset}
			left = minf(left, offset.x)
			right = maxf(right, offset.x + edge.size())
	if sources.is_empty():
		frames.set_meta(key, {})
		return {}
	var outline := PackedFloat32Array()
	outline.resize(ceili(right - left))
	outline.fill(-INF)
	for x in outline.size():
		for source in sources.values():
			var column := floori(left + x + 0.5 - source.offset.x)
			if column >= 0 and column < source.edge.size():
				outline[x] = maxf(outline[x], source.edge[column] + source.offset.y)
	# Extend the closest occupied column through transparent side margins; using
	# the deepest brim everywhere would cut out hair below the raised corners.
	var occupied := []
	for x in outline.size():
		if is_finite(outline[x]): occupied.append(x)
	if occupied.is_empty():
		frames.set_meta(key, {})
		return {}
	for x in outline.size():
		if is_finite(outline[x]): continue
		var nearest: int = occupied[0]
		for column in occupied:
			if absi(column - x) < absi(nearest - x): nearest = column
		outline[x] = outline[nearest]
	var image := Image.create(outline.size(), 1, false, Image.FORMAT_RF)
	for x in outline.size(): image.set_pixel(x, 0, Color(outline[x], 0.0, 0.0))
	# Combine all frames for a stable hairline during animated hats, cached once
	# per SpriteFrames. Source atlas profiles are shared across repeated equips.
	var profile := {"edge": outline, "left": left, "texture": ImageTexture.create_from_image(image)}
	frames.set_meta(key, profile)
	return profile

static func _read_lower_edge(texture: Texture2D) -> PackedFloat32Array:
	var edge := PackedFloat32Array()
	var image := texture.get_image()
	if image == null:
		return edge
	edge.resize(image.get_width())
	edge.fill(-INF)
	for x in image.get_width():
		for y in range(image.get_height() - 1, -1, -1):
			if image.get_pixel(x, y).a > 0.0:
				edge[x] = float(y + 1)
				break
	return edge

static func _texture_key(texture: Texture2D) -> String:
	# AtlasTextureFactory may create a new wrapper on each equip. Key its actual
	# atlas region so repeated swaps share the bounds instead of growing a cache.
	if texture is AtlasTexture:
		return "%s:%s:%s" % [_texture_key(texture.atlas), texture.region, texture.margin]
	return str(texture.get_instance_id())
