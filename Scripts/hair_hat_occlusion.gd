extends RefCounted

## Tuck the upper hair under headwear without editing textures or equipped IDs.
## New hats opt in by default; decorative accessories can set tucks_hair=false.
const CLIP_SHADER = preload("res://Assets/shaders/hair_hat_clip.gdshader")
const MATERIAL_META := &"hair_hat_clip_material"
const ORIGINAL_MATERIAL_META := &"hair_hat_original_material"
static var texture_bounds := {}

static func apply(hair: AnimatedSprite2D, hat: AnimatedSprite2D, hat_data: Dictionary) -> void:
	if not is_instance_valid(hair):
		return
	var active := hair.visible and is_instance_valid(hat) and hat.visible and bool(hat_data.get("tucks_hair", true))
	var bottom := get_hat_bottom(hat) if active else -INF
	var material: ShaderMaterial = hair.get_meta(MATERIAL_META) if hair.has_meta(MATERIAL_META) else null
	if not is_finite(bottom):
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
	# Both sprites share the Head parent. Its mirroring/bobbing carries the
	# clipping line with the hair, including differently sized hair textures.
	var brim := hair.transform.affine_inverse() * hat.transform * Vector2(0.0, bottom + hat.offset.y)
	material.set_shader_parameter("brim_y", brim.y)

static func get_hat_bottom(hat: AnimatedSprite2D) -> float:
	var frames := hat.sprite_frames
	if frames == null:
		return -INF
	var key := &"hair_hat_bottom_centered" if hat.centered else &"hair_hat_bottom"
	if frames.has_meta(key):
		return float(frames.get_meta(key))
	var bottom := -INF
	for animation in frames.get_animation_names():
		for frame in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, frame)
			if texture == null:
				continue
			var texture_id := _texture_key(texture)
			if not texture_bounds.has(texture_id):
				var image := texture.get_image()
				texture_bounds[texture_id] = image.get_used_rect() if image != null else Rect2i()
			var bounds: Rect2i = texture_bounds[texture_id]
			if bounds.has_area():
				bottom = maxf(bottom, float(bounds.end.y) - (texture.get_height() * 0.5 if hat.centered else 0.0))
	# Use all animation frames so the visible hairline cannot flicker as a hat
	# animates. Cache per SpriteFrames; steady movement never reads image pixels.
	frames.set_meta(key, bottom)
	return bottom

static func _texture_key(texture: Texture2D) -> String:
	# AtlasTextureFactory may create a new wrapper on each equip. Key its actual
	# atlas region so repeated swaps share the bounds instead of growing a cache.
	if texture is AtlasTexture:
		return "%s:%s:%s" % [_texture_key(texture.atlas), texture.region, texture.margin]
	return str(texture.get_instance_id())
